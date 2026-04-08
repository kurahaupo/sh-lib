#
# cluck is the core implementation of the whole die/croak/confess/cluck suite;
# the other names simply act as shorthand for options that are provided here.
#
function cluck {
    local _status=$?   # must be first; keep this in case we need it for the default exit code.
    local _backtrace=1
    local _debug=0
    local _depth_limit=${#BASH_LINENO[@]}+1
    local _funcname=
    local _hide_depth=1
    local _i=
    local _lineno=
    local _magic_status=0
    local _message=
    local _only1=0
    local _source=
    local _status_code=_status
    local _suicide=0    # exit (or kill $$) rather than return

    while [[ $1 = -?* ]]
    do
        [[ $1 = --he* && '--help' = $1* ]] && {
            cat <<'EndOfHelp'
cluck [options] [message]
  backtracing:
    -q --quiet
    -w --whence
    -b --backtrace
    -d --depth-limit=NUM    at most NUM lines of backtrace

    -h --hideme  (same as -H1)
    -H --hide=NUM_LEVELS
    -s --showall (same as -S1)
    -S --show=FROM_LEVEL

  fatality:
    -e --exit-code=CODE     exit with explicit status (fatal)
    -E --exit               exit with status of previous command (fatal)
    -r --return-code=CODE   return with explicit status (non-fatal)
    -R --return             return with status of previous command (non-fatal)
    -D --die                fatal taking status from first arg, if it looks
                            like a number or a recognized EX*_* or SIG* symbol

  CODE can be any expression evaluating to a number between 0 and 255; the
  symbolic constants from sysexits.h are also available, plus EX_FAIL (1)
  and EX_STATUS (the value of $? from immediately before cluck is called).
EndOfHelp
            return 0
        }

        case $1 in
        (-[deHrS]?*)    _i=$1 ; shift ; set -- "${_i:0:2}"  "${_i:2}" "$@" ;;
        (-[^-]?*)       _i=$1 ; shift ; set -- "${_i:0:2}" "-${_i:2}" "$@" ;;
        (--*=*)         _i=$1 ; shift ; set -- "${_i%%=*}" "${_i#*=}" "$@" ;;
        esac
        case $1 in
        (-b|--backtrace)    _backtrace=1 _only1=0 ;;
        (-d|--depth-limit)  ((_depth_limit=$2)) ; shift ;;
        (-D|--die)          _suicide=1 _magic_status=1 ;;
        (-e|--exit-code)    _suicide=1 _status_code=$2 _magic_status=0 ; shift ;;
        (-E|--exit)         _suicide=1 ;;
        (-H|--hide)         ((_hide_depth+=$2)) ; shift ;;
        (-h|--hideme)       ((_hide_depth++)) ;;
        (-k|--keep-status)  _status_code=_status _magic_status=0 ;;
        (-q|--quiet)        _backtrace=0 ;;
        (-r|--return-code)  _suicide=0 _status_code=$2 _magic_status=0 ; shift ;;
        (-R|--return)       _suicide=0 ;;
        (-S|--show)         ((_hide_depth=$2)) ; shift ;;
        (-s|--showall)      ((_hide_depth=1)) ;;
        (-w|--whence)       _backtrace=1 _only1=1 ;;
        (-x|--debug)        _debug=1 ;;
        (*)                 _hide_depth=0 ; set -- "Invalid option '$1' in call to shell function 'cluck $*'" ; break ;;
        esac
        shift
    done

    ((_debug)) && {
        printf '\nDEBUG CLUCK\n'
        for _i in _backtrace _only1 _depth_limit _hide_depth _suicide \
                  _magic_status _status_code
        do
            printf '\t%s=%s\n' "${_i#_}" "${!_i}"
        done
        printf '\t%s=%u:(%s)\n' FUNCNAME ${#FUNCNAME[*]} "${FUNCNAME[*]}"
        printf '\t%s=%u:(%s)\n' BASH_SOURCE ${#BASH_SOURCE[*]} "${BASH_SOURCE[*]}"
        printf '\t%s=%u:(%s)\n' LINENO+BASH_LINENO $((1+${#BASH_LINENO[*]})) "$LINENO ${BASH_LINENO[*]}"
    }

    if (( _magic_status )) || [[ -n $_status_code ]]
    then
        # We could use "require exit_status" but that would be slow (it parses
        # the output of 'trap -l').
        #
        # Because EX_values and SIG_values are readonly, only attempt to set
        # them if they're unset. (Inability to localize and turn off read-only
        # could be construed as a bug in the shell.)
        if (( ${#EX_values[@]} == 0 )); then
            # copied from exit_status.bash
            # status names may be given as either EX_xx or EXIT_xx
            declare -A EX_values=(
                [SUCCESS]=0 [OK]=0 [PASS]=0
                [FAILURE]=1 [FAIL]=1
                [USAGE]=64 [DATAERR]=65 [NOINPUT]=66 [NOUSER]=67 [NOHOST]=68
                [UNAVAILABLE]=69 [SOFTWARE]=70 [OSERR]=71 [OSFILE]=72
                [CANTCREAT]=73 [IOERR]=74 [TEMPFAIL]=75 [PROTOCOL]=76
                [NOPERM]=77 [CONFIG]=78
                [BUG]=96 [INTERNAL]=96 [NOEXEC]=127 [BROKEN]=255
            )
        fi
        if (( ${#SIG_values[@]} == 0 )); then
            # Linux-specific version; may not work elsewhere.
            declare -A SIG_values=(
                [HUP]=1 [FPE]=8 [STKFLT]=16 [XCPU]=24 [INT]=2 [KILL]=9
                [CHLD]=17 [XFSZ]=25 [QUIT]=3 [USR1]=10 [CONT]=18 [VTALRM]=26
                [ILL]=4 [SEGV]=11 [STOP]=19 [PROF]=27 [TRAP]=5 [USR2]=12
                [TSTP]=20 [WINCH]=28 [ABRT]=6 [PIPE]=13 [TTIN]=21 [IO]=29
                [IOT]=6 [ALRM]=14 [TTOU]=22 [PWR]=30 [BUS]=7 [TERM]=15 [URG]=23
                [SYS]=31
            )
        fi
        ((_debug)) && {
            printf '\nDEBUG SUICIDE - load arrays\n'
            declare -p EX_values SIG_values
        }
    fi

    if (( _magic_status ))
    then
        ((_debug)) &&
            printf '\nDEBUG SUICIDE - seeking magic status %s\n' "$1"
        {
        { _status_code=10#$1                  ; [[ $1 != *[!0-9]*     ]] ; } ||
        { _status_code="EX_values[${1#EX*_}]" ; [[ ${!_status_code+X} ]] ; } ||
        { _status_code="SIG_values[${1#SIG}]" ; [[ ${!_status_code+X} ]] && (( _status_code |= -128 )) ; } ||
        { _status_code=_status                ; [[ $1 = ?(EX*_)STATUS ]] ; } } && shift
        _i=$?
        ((_debug)) &&
            printf '\nDEBUG SUICIDE - got magic status %u code=%s=%d\n' "$_i" "$_status_code" "$((_status_code))"
    fi

    if [[ $1 = *[%\\]* ]]
    then printf -v _message "$@"
    else _message="$*"
    fi

    if ((_backtrace))
    then
        (( _hide_depth > 0 )) || { ((_hide_depth=1)) ; ((_debug)) && printf 'DEBUG Increase hiding to 1\n' ; }
        (( _depth_limit += _hide_depth ))
        for (( _i=_hide_depth ; _i<_depth_limit ; _i++ ))
        do
            ((_debug)) && printf 'DEBUG showing level %d [%s]\n' "$_i" "$( caller $((_i-1)) )"
            _source=${BASH_SOURCE[_i]}
            ((_i>0)) && _lineno=${BASH_LINENO[_i-1]}
            ((_lineno)) || _lineno=

            printf >&2 '%s\n' "$_message${_lineno:+ at line $_lineno}${_source:+ in $_source}"

            ((_only1)) && break

            _funcname=${FUNCNAME[_i+1]}
            case $_funcname in
            (source|main)   _funcname="" ;;
            ('')            _funcname="[command line]" ;;
            esac
            _message="  called${_funcname:+ from $_funcname}"
        done
    else
        printf '%s\n' >&2 "$_message"
    fi
    if (( _suicide ))
    then
        if (( _status_code < 0 )) ; then
            kill -s $((_status_code & 127)) $$
        fi
        exit "$((_status_code))"
    else
        return "$((_status_code))"
    fi
}
_provides cluck
