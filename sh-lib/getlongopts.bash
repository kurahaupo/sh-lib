#!/module/for/bash

require die
require warn
require cluck

# Call this as
#   . getlongopt.bash <<'EOF'
#   --foo           value=true,neg          foo=            Enable Foo
#   --bar           opt                     set_bar
#   --whence        date                    since=
#   --until         time                    until=
#   --count         num                     when=
#   --delay         duration                delay=
#   --go,-g         group                   action=
#   --stop,-h       group                   action=
#   --status,-s     group                   action=
#   --verbose,-v    num,opt,count,neg       verbose=
#   --quiet,-q      value=false,neg         verbose=
#   EOF
#
# Note that because this is intended to operate on "$@" of the main script, it
# does not take any arguments of its own. All configuration is instead conveyed
# through stdin, which will normally be provided as a heredoc.
#
# In this description, "argument" refers to an argument provided to the outer
# script which this script attempts to parse.
#
# As an alternative mode of operation, it can define a function that can be
# called once other set-up has been done. This may be useful if options have to
# be parsed repeatedly.
#
# Reads lines from stdin, and processes sections.
#
#   A line starting with '@' starts a new section; the first word denotes the
#   kind of section, and the remainder of the line is a list of space-separated
#   parameters for the section.
#
#   Lines that do not start with '@' are input for that preceding section.
#
#   The following sections are predefined:
#       @config [key=value ...]
#       @synopsis [text]
#       @options
#       @args
#       @description
#
#   If the first line does not start with '@' then '@options' is assumed.
#
#   The @config section should normally come first, as some settings may
#   affect how other sections are parsed or interpreted. It should be followed
#   by a list of keyword=value pairs; these mimic the parameters available in
#   Perl's Getopt::Long::configure.
#       * permute=[true|false]
#       * bundling=[true|false]
#       * func=[function_name]     define a function that processes the args
#               without the option, an anonymous function will be defined, and immediately invoked.
#
#   The @synopsis section simply contains readable text that is shown. Because
#   it's within a heredoc, the name by which the script was invoked can be
#   given simply as ${0##*/}.
#
#   The @options section defines the available command-line options, where each
#   line starting with '-' starts a new option definition.
#
#   Each subsection starts with 3 space-delimited fields:
#    *  a comma-separated list of option names, each starting with '-' or '--'
#    *  a comma-separated list of controls
#    *  a target;
#
#   The controls include:
#       opt     takes an optional argument
#       flag    takes no argument, and uses "true" as the value
#       neg     also register the inverse option that uses "false" as the
#               value:
#               * for a short option -x, that will be the uppercase version -X
#               * for a long option --xxx, that will be --no-xxx;
#       group   use the option name (minus any leading '-' or '--') as the value
#       single  do not allow the option (or its inverse, or any other option in
#               the same group) to be specified more than once.
#
#
#   If the target starts with '$' then it denotes a variable that is set to the
#   value, otherwise it denotes a callback function which is invoked with the
#   value as the first parameter and the option name as the second parameter.
#
#   The @args section behaves like a subsection of the @options, but is used to
#   treat any argument that does _not_ start with a '-'.
#
#

for c in true=1 false=0 \
         UNSPEC=0 FORBIDDEN=1 OPTIONAL=2 REQUIRED=3 \
       # yes=1 no=0 YES=1 NO=0 \

do
    declare <>/dev/null >&0 2>&1 -p ${c%%=*} &&
     (( ${c%%=*} == ${c#*=} )) &&
      continue

    declare -ri "$c"
done

[[ -v __getlongopts_mirror_pairs ]] || {
    declare -r __getlongopts_mirror_pairs='()<>[]{}«»'
    declare -A __getlongopts_mirror_swap=()
    for ((___mt_i=0, l=${#__getlongopts_mirror_pairs};___mt_i<l;++___mt_i)) do
        __getlongopts_mirror_swap[${__getlongopts_mirror_pairs:___mt_i:1}]=${__getlongopts_mirror_pairs:___mt_i^1:1}
    done
    declare -r __getlongopts_mirror_swap
}

#
## __getlongopts_mirror_token
#
# Given a start-group token, generate its corresponding end-group token,
# which will be used to find the end of the group. Specifically, any
# leading or trailing bracketing characters will be replaced by their
# mirrored counterpart, on the other end of the token, so for example:
#
#   {<Token](>    ⇔    <)[Token>}
#
# Modify in-place the given variable or array expression.
#

__getlongopts_mirror_token() {
    local ___mtoken=${!1} ___mt_i ___mt_char ___mt_ep ___mt_es
    [[ $___mtoken != *[$__getlongopts_mirror_pairs]* ]] && return 0  # nothing to change
    ___mt_ep=${___mtoken%%[!"$__getlongopts_mirror_pairs"#]*}
    ___mtoken=${___mtoken#"$___mt_ep"}
    ___mt_es=${___mtoken##*[!"$__getlongopts_mirror_pairs"]}
    ___mtoken=${___mtoken%"$___mt_es"}
    for (( ___mt_i = ${#___mt_ep}-1 ; ___mt_i >= 0 ; --___mt_i )) do ___mt_char=${___mt_ep:___mt_i:1} ___mtoken=$___mtoken${__getlongopts_mirror_swap[$___mt_char]-$___mt_char} ; done
    for (( ___mt_i = 0 ; ___mt_i <= ${#___mt_es}-1 ; ++___mt_i )) do ___mt_char=${___mt_es:___mt_i:1} ___mtoken=${__getlongopts_mirror_swap[$___mt_char]-$___mt_char}$___mtoken ; done
    printf -v $1 %s "$___mtoken"
}

getlongopts() {
    local -i _debug=false

    [[ $1 = ----test ]] && { shift ; _debug=true ; }

    #local -a actions=()
    local -a names
    local -a flaglist

    local name flags target description

    local -A longnames=()
    local -A shortnames=()
    local -A abbreviations=()

    local -i  opt_num=0  # action number; 0 reserved meaning "none"
    local -a  opt_name=()
    local -ai opt_argmode=()    # required vs optional vs forbidden
    local -ai opt_invertible=() # --no-opt allowed
    local -a  opt_target=()      # function to call when opt is recognized
    local -a  opt_value=()

    if [[ -t 0 ]]
    then
        printf >&2 '\e[1;33;41mWARNING\e[m: getlongopts must be called with a here-doc as its stdin\n'
        return 64
    fi

    while IFS= read -r line
    do
        [[ $line = '#'* || -z $line ]] && continue

        [[ $line = '@'* ]] && {
            eval "${line#?}"
            continue
        }

        IFS=$' \t\n' read -r name flags target description <<< "$line"

        ((++opt_num))

        IFS=, read -r -a names <<<"$name"
        name=${names[0]}

        local -i argmode=UNSPEC
        local -i declmode=UNSPEC
        local -i counting=false
        local -i invertible=false
        local -i store_neg=false
        local use_value=

        IFS=, read -r -a flaglist <<<"$flags"
        for f in "${flaglist[@]}" ; do
            case $f in
            -) ;;       # placeholder

            false)      use_value=false    argmode=FORBIDDEN ;;
            true|bool)  use_value=true     argmode=FORBIDDEN ;;
            group)      use_value=${names[0]#--} argmode=FORBIDDEN ;;

            defvalue=*) use_value=${f#*=}  argmode=OPTIONAL ;;
            value=*)    use_value=${f#*=}  argmode=FORBIDDEN ;;

            no-|inv)    invertible=true ;;
            req)        declmode=REQUIRED ;;
            opt)        declmode=OPTIONAL ;;
            count)      counting=true argmode=OPTIONAL ;;
            neg)        store_neg=true ;;
            num)        argmode=REQUIRED ;;
            int)        argmode=REQUIRED ;;
            str)        argmode=REQUIRED ;;
            *)          die EX_USAGE "Don't understand flag=$f"
            esac
        done
        if (( !argmode || argmode == OPTIONAL && declmode != UNSPEC )) ; then
            (( argmode = declmode ))
        elif (( declmode && argmode && declmode != argmore )) ; then
            warn "Implicit mode does not match explicit mode"
        fi

        if (( argmode == UNSPEC )) ; then
            (( argmode = FORBIDDEN ))
        fi

        if [[ $target = '$'[A-Za-z_]!(*[!0-9A-Za-z_]*) ]]
        then
            local var=${target#?}
            if (( counting ))
            then
                #
                # --debug       increase the debug level
                # --debug=5     set the debug level to 5
                # --no-debug    set the debug level to 0
                #
                target=arg_set_or_increment_${name//+[![0-9A-Za-z]]/_}
                eval "
                    $target() {
                        local v=\$1 n=\$2
                        ((_debug)) && cluck " set_or_inc $*"
                        if (( n != $store_neg ))
                        then (( $var = ! (\${v:-${use_value:-true}}) ))
                        elif [[ -z \$v ]]
                        then (( ++ $var ))
                        else $var=\"\${v:-$(printf %q "$use_value")}\"
                        fi
                    }
                "
            else
                target=arg_set_${name//+[![0-9A-Za-z]]/_}
                eval "
                    $target() {
                        ((_debug)) && cluck " set $*"
                        local v=\$1 n=\$2
                        if (( n != $store_neg ))
                        then (( $var = ! (\${v:-${use_value:-true}}) ))
                        else $var=\${v:-$(printf %q "$use_value")}
                        fi
                    }
                "
            fi
        elif (( counting || store_neg ))
        then die EX_USAGE "Cannot use COUNT or NEG with a callback function"
        fi

        opt_name[opt_num]=${names[0]}
        opt_argmode[opt_num]="$argmode"
        opt_invertible[opt_num]="$invertible"
        opt_target[opt_num]="$target"
        opt_value[opt_num]="$use_value"

        for n in "${names[@]}" ; do
            case $n in
            -?)
                shortnames[$n]=$opt_num
                ;;
            *)
                longnames[$n]=$opt_num
                for (( i=${#n} ; i>=3 ; --i )) do
                    nn=${n:0:i}
                    case ${abbreviations[$nn]:=$opt_num} in
                    '') abbreviations[$nn]=0/0 ;;
                    "$opt_num") ;;
                    (*) abbreviations[$nn]=0 ;;   # set-but-0 means "ambiguous"
                    esac
                done
                ;;
            esac
        done
    done

    for n in "${!abbreviations[@]}" ; do
        if (( abbreviations[$n] )) && [[ -z ${longnames[$n]} ]] ; then
            (( longnames[$n] = abbreviations[$n] ))
        fi
    done

    declare -p abbreviations
    declare -p longnames
    declare -p shortnames

    declare -p opt_name
    declare -p opt_argmode
    declare -p opt_invertible
    declare -p opt_target
    declare -p opt_value

    #((_debug)) && set -x

    local -i neg_this
    local opt_name opt_param

    while (($#)) ; do
        opt_name=$1
        neg_this=false
        opt_param=

        case $1 in
        --) shift ; break ;;
        -) break ;;
        --no-*)
            opt_name="--${1:5}"
            if (( opt_num = longnames[$opt_name] )) &&
               (( opt_invertible[opt_num] ))
            then
                neg_this=true opt_param=
            else
                false
            fi
            ;;
        --*=*)
            opt_name=${1%%=*} opt_param=${1#*=}
            if (( opt_num = longnames[$opt_name] )) ; then
                (( opt_argmode[opt_num] == FORBIDDEN )) &&
                    die EX_USAGE "Option '$opt_name' does not take an argument"
            else
                false
            fi
            ;;
        --*)
            if (( opt_num = longnames[$opt_name] ))
            then
                if ((opt_argmode[opt_num] == REQUIRED)); then
                    (($# > 1)) || die EX_USAGE "Option '$opt_name' requires an argument"
                    opt_param=$2 ; shift
                fi
            else
                false
            fi
            ;;
        -*)
            if [[ $opt_name = -n? ]] &&
               (( opt_num = shortnames[-${opt_name#-n}] )) &&
               (( opt_invertible[opt_num] ))
            then
                neg_this=true opt_name=-${opt_name#-n}
            elif
                (( opt_num = shortnames[${opt_name:0:1}] ))
            then
                if [[ $opt_name = -? ]]
                then
                    if (( opt_argmode[opt_num] == REQUIRED )); then
                        opt_param=$2
                        shift
                    fi
                else
                    if (( opt_argmode[opt_num] == FORBIDDEN )); then
                        set -- "${opt_name:0:2}" "-${opt_name:2}" "${@:2}"
                    fi
                fi
            else
                false
            fi
            ;;
        *)  break ;;
        esac || {
            [[ -n ${abbreviations[$opt_name]} ]] &&
                die EX_USAGE "Ambiguous option '$1'"
            die EX_USAGE "Invalid option '$1'"
        }
        shift
        ((_debug)) &&
        printf 'STORE:\n'
        printf '  %s\n' "${opt_target[opt_num]}" "$opt_param" "$neg_this" "$opt_name" "${opt_value[opt_num]}"
        "${opt_target[opt_num]}" "$opt_param" "$neg_this" "$opt_name" "${opt_value[opt_num]}"
    done
}

_provides getlongopts

[[ $1 = ----test ]] && { getlongopts "$@" ; exit ; }

(($#==0)) || [[ $* = -- ]] || getlongopts "$@" && set --
