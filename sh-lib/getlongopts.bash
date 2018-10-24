#!/module/for/bash

require die
require warn
require cluck

# Call this as
#   . getlongopt.bash <<'EOF'
#   --foo           value=true,neg          $foo            Enable Foo
#   --bar           opt                     set_bar
#   --whence        date                    $since
#   --until         time                    $until
#   --count         num                     $when
#   --delay         duration                $delay
#   --go,-g         group                   $action   
#   --stop,-h       group                   $action
#   --status,-s     group                   $action
#   --verbose,-v    num,opt,count,neg       $verbose
#   --quiet,-q      value=false,neg         $verbose
#   EOF

declare -ri true=1 false=0 #yes=1 no=0 YES=1 NO=0
declare -ri UNSPEC=0 FORBIDDEN=1 OPTIONAL=2 REQUIRED=3

declare -r mirror_pairs='()<>[]{}«»'

#
## mirror_token
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

mirror_token() {
    if [[ $1 = *[$mirror_pairs]* ]]; then
        local ee=${!1} i ec ep es
        local -A swap=()
        for ((i=0, l=${#mirror_pairs};i<l;++i)) do
            swap[${mirror_pairs:i:1}]=${mirror_pairs:i^1:1}
        done
        ep=${ee%%[!"$mirror_pairs"#]*}
        ee=${ee#"$ep"}
        es=${ee##*[!"$mirror_pairs"]}
        ee=${ee%"$es"}
        for (( i = ${#ep}-1 ; i >= 0 ; --i )) do ec=${ep:i:1} ee=$ee${swap[$ec]-$ec} ; done
        for (( i = 0 ; i <= ${#es}-1 ; ++i )) do ec=${es:i:1} ee=${swap[$ec]-$ec}$ee ; done
        printf -v $1 %s "$ee"
    fi
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
                        (($_debug)) && cluck " set_or_inc $*"
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
                        (($_debug)) && cluck " set $*"
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
