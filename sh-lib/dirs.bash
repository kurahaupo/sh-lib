#!/module/for/bash
#
# split a path into logical sections:
# head, user, part 3, interest 1, part 5, interest 2, and tail
#
# Firstly, check whether it's a subdirectory of the current directory, if
# enabled
# - highlight current directory
# - for dirs, skip this when showing first part (which is $PWD)
#
# Then check for any user's home directory:
# - if not under any home, part 1 & user will be empty
# - if under own home, part 1 is empty, and "user" is "~"
# - if under someone else's home, part 1 is the part before the username, "user" is the username
#
# Then the remainder is scanned
# - if under a hosting dir, then interest 1 is the hostname
# - if in a git/svn/rcs repo, then interest 1 is the repo top dir
#     - if inside a .git directory, then that is interest 2
#
# If no match, everything is "tail", which is always printed in "normal" text
#

[[ $1 = --reset-colours ]] &&
    unset \
        __np_cc_dnszone \
        __np_cc_host \
        __np_cc_leadingpath \
        __np_cc_logdir \
        __np_cc_non_home \
        __np_cc_project \
        __np_cc_relative \
        __np_cc_reset \
        __np_cc_root \
        __np_cc_user_home

     _=${__np_cc_dnszone=$'\e[38;5;14m'}
        _=${__np_cc_host=$'\e[38;5;13m'}
 _=${__np_cc_leadingpath=$'\e[38;5;8m'}    # parent of a home directory, a zonefile, a logfile, etc
      _=${__np_cc_logdir=$'\e[38;5;14m'}
#   _=${__np_cc_non_home=$'\e[38;5;129m'}  # anything in /home or /serve/users that is NOT a user's home dir
    _=${__np_cc_relative=$'\e[38;5;10m'}
       _=${__np_cc_reset=$'\e[39m'}
        _=${__np_cc_root=$'\e[38;5;11m'}
   _=${__np_cc_user_home=$'\e[38;5;11m'}

# Print leading matching portion of "$d" as plain or with a specified colour;
# then remove the portion just printed from "d".

__np_p0() {
    local x=${d%"${d##${1:-*}}"} c=$2
    [[ -n $x ]] ||
        return 1
    d=${d#"$x"}
    p=${p#"$x"}
    printf %s%s "${c:-$__np_cc_reset}" "$x"
    (( rc = ${#c} > 0 ))
    (( cc -= ${#x}, cc < 0 && (cc = 0) ))
    return 0
}

# Print the leading matching portion of "$d", using the "cwd" colour up until
# the end of $PWD, then the remainder as plain or with a specified colour; then
# remove the portion just printed from "d".

__np_p1() {
    local x=${d%"${d##${1:-*}}"} c=$2
    [[ -n $x ]] || {
        return 1
    }
    d=${d#"$x"}
    if (( cc < ${#x} )); then
        if (( cc <= 0 )); then
            (( rc )) && [[ -z $c ]] && printf %s "$__np_cc_reset"
            printf %s%s "$c" "$x"
        else
            printf '%s%s%s%s' "$__np_cc_relative" "${x:0:cc}" "${c:-$__np_cc_reset}" "${x:cc}"
        fi
        (( rc = ${#c} > 0 ))
    else
        printf '%s%s' "$__np_cc_relative" "$x"
        (( rc = 1 ))
    fi
    (( cc -= ${#x}, cc < 0 && (cc = 0) ))
    return 0
}

_nice_path() {
    local d=$1 p=$2
    local chroot=

    if [[ ! -t 1 ]]
    then
        printf '%s\n' "$1"
        return 0
    fi

    printf '\t'

    local _ref
    for _ref in p d ; do
        [[ ${!_ref} = */ ]]        || printf -v "$_ref" '%s/' "${!_ref}"
        [[ ${!_ref} = "$HOME/"* && $USER = "$LOGNAME" ]] && printf -v "$_ref" '~%s' "${!_ref#"$HOME"}"
    done

    local -i rc=0 cc=0

    [[ $d = $p* ]] && cc=${#p}

    case $d in
    /)
        #: $'\e[m' M1 special exceptions for whole paths
        printf '%s/%s\n' "$__np_cc_root" "$__np_cc_reset"
        return 0
        ;;
    esac

    if (( __np_relative > 0 ))
    then
        local i r=' ./' s= t
        for ((i=0;i<__np_relative;++i)) do
            t=${p%"$s"}
            # never show home or root as a relative path
            [[ ${t#'~'} = / ]] && break
            if  [[ $d = $t* ]] &&
                # only use relative path if it's shorter than the absolute one
                (( ${#r}+3 < ${#t} ))
            then
                d=$r${d#"$t"}
                p=' ./'
                break
            fi
            s=${p#"${t%/*/}/"}
            r+=../
        done
        [[ $d = $p* ]] && cc=${#p}
    fi

    case $d in
    */backup/*/*)
        #: $'\e[m' M6
        chroot=${d%"${d#/*/backup/*/}"}
        __np_p1 '*/backup/' "$__np_cc_leadingpath" &&
        __np_p0 '!(*/*)' "$__np_cc_host"
        ;;
    esac

    case $d in
    /)
        #: $'\e[m' M1 special exceptions for whole paths
        __np_p1 '*' "$__np_cc_root"
        ((rc)) && printf %s "$__np_cc_reset"
        printf '\n'
        return
        ;;

    "~"/*)
        # My home directory
        #: $'\e[m' M2 \~
        __np_p0 '\~/' "$__np_cc_user_home"
        ;;

    /root/*|\
    */home/*/*|\
    */users/*/*)
        # Potentially somebody else's home directory
        local x=${d%"/${d##@(*/users/!(*/*)|*/home/!(*/*)|/root)/}"}
        # x=/root or /home/$user or /serve/users/$user
        local u=${x##*/}
        if [[ -n $x &&  -r $chroot/etc/passwd ]] &&
            cut -d: -f6 < "$chroot/etc/passwd" | grep -qsxF "${x%/}"
        then
            if (( __np_full_homes )) || [[ $chroot ]]
            then
                __np_p1 "${x%$u}" "$__np_cc_leadingpath"
            else
                u="~$u"
                d="$u${d#"$x"}"
                (( cc += -${#x} + ${#u} ))
                :
            fi &&
            __np_p0 "$u" "$__np_cc_user_home" &&
            __np_p1 /
        fi
        ;;
    esac

    case /$d in
    */hosting/*/*|\
    */serve/hosts/*/*)
        #: $'\e[m' M6
        __np_p1 '?(*/)@(serve/hosts|hosting)/' "$__np_cc_leadingpath" &&
        __np_p0 '!(*/*)' "$__np_cc_host" &&
        __np_p1 /
        ;;

    */serve/*)
        __np_p1 '?(*/)serve/' "$__np_cc_leadingpath"
        ;;
    esac

    case /$d in
    */@(git|svn|rcs)/*/*)
        #: $'\e[m' M6
        __np_p1 '?(*/)@(git|svn|rcs)/' &&
        __np_p0 '!(*/*)' "$__np_cc_host" &&
        __np_p1 /
        ;;

    */log/*)
        __np_p1 '!(?(*/)log/*)/' "$__np_cc_leadingpath" &&
        __np_p1 'log' "$__np_cc_logdir" &&
        __np_p1 /
        ;;

    */dns/*/*)
        __np_p1 '!(?(*/)dns/*)/' "$__np_cc_leadingpath" &&
        __np_p1 'dns' "$__np_cc_dnszone" &&
        __np_p1 /
        ;;
    esac

    d=${d%/}

    __np_p1 '*'
    ((rc)) && printf %s "$__np_cc_reset"
    printf '\n'
}

dirs() {
    local d pp=.
    for d in "${DIRSTACK[@]}"
    do
        _nice_path "$d" "$pp"
        pp=$PWD
    done
}

_with_dirs() {
    local status pid=$$ show_dirs='status==0 && BASHPID==pid' i=1 n=$#
    for ((;i<=n;++i)) do
        case ${!i} in
        (-q | --q?(u?(i?(e?(t)))))          show_dirs=0 ;;
        (-v | --v?(e?(r?(b?(o?(s?(e)))))))  show_dirs=1 ;;
        (*) continue ;;
        esac
        set -- "${@:1:i-1}" "${@:i+1}"
        ((--i))
    done
    "$@" > /dev/null
    status=$?
    ((show_dirs)) && dirs
    return $status
}

cd()    { _with_dirs builtin cd    "$@" ; }
popd()  { _with_dirs builtin popd  "$@" ; }
pushd() { _with_dirs builtin pushd "$@" ; }
pwd()   { _nice_path "$PWD" ; }

_provides _nice_path _with_dirs cd dirs popd pushd
