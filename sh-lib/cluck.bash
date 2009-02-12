require die
function cluck {
    local _o= _i=
    local _backtrace=true _only1=false _hide_depth=1 _depth_limit=${#BASH_LINENO[@]}+1 _debug=false
    local _exitcode= _message= _lineno= _source= _funcname=
    while [[ $1 = -?* ]]
    do
        [[ $1 = --he* && '--help' = $1* ]] && {
            cat <<'EndOfHelp'
cluck [options] [message]
  backtracing:
    -q --quiet
    -w --whence
    -b --backtrace

    -h --hideme  (same as -H1)
    -H --hide=NUM_LEVELS
    -s --showall (same as -S1)
    -S --show=FROM_LEVEL

  fatality:
    -e --exit-code=CODE
    -E --no-exit

  CODE can be any expression evaluating to a number between 0 and 255; the
  symbolic constants from sysexits.h are also available, plus EX_FAIL (1)
  and EX_STATUS (the value of $? from immediately before cluck is called).
EndOfHelp
            return 0
        }

        case $1 in
        (-[deHS]?*)_o=$1 ; shift ; set -- "${_o:0:2}"  "${_o:2}" "$@" ;;
        (-[^-]?*)  _o=$1 ; shift ; set -- "${_o:0:2}" "-${_o:2}" "$@" ;;
        (--*=*)    _o=$1 ; shift ; set -- "${_o%%=*}" "${_o#*=}" "$@" ;;
        esac
        case $1 in
        (-b|--backtrace) _backtrace=true _only1=false ;;
        (-d|--depth-limit) ((_depth_limit=$2)) ; shift ;;
        (-e|--exit-code) _exitcode=$2 ; shift ;;
        (-E|--no-exit)   _exitcode= ;;
        (-h|--hideme)    ((_hide_depth++)) ;;
        (-H|--hide)      ((_hide_depth+=$2)) ; shift ;;
        (-q|--quiet)     _backtrace=false ;;
        (-s|--showall)   ((_hide_depth=1)) ;;
        (-S|--show)      ((_hide_depth=$2)) ; shift ;;
        (-w|--whence)    _backtrace=true _only1=true ;;
        (-x|--debug)     _debug=true ;;
        (-X|--exit-with-status) _exitcode=_status ;;
        (*)              _hide_depth=0 ; set -- "Invalid option '$1' in call to shell function 'cluck $*'" ; break ;;
        esac
        shift
    done
    _message="$*"

    $_debug && echo "
DEBUG CLUCK
    backtrace=$_backtrace only1=$_only1
    depth-limit=$_depth_limit hide-depth=$_hide_depth
    exitcode=$_exitcode
    FUNCNAME=${#FUNCNAME[*]}:(${FUNCNAME[*]})
    BASH_SOURCE=${#BASH_SOURCE[*]}:(${BASH_SOURCE[*]})
    BASH_LINENO=${#BASH_LINENO[*]}:(${BASH_LINENO[*]}) LINENO=$LINENO
"

    if $_backtrace
    then
        (( _hide_depth > 0 )) || { ((_hide_depth=1)) ; $_debug && echo "DEBUG Increase hiding to 1" ; }
        (( _depth_limit > _hide_depth )) || { ((_depth_limit=_hide_depth+1)) ; $_debug && echo "DEBUG Increase limit to $_depth_limit" ; }
        for (( _i=$_hide_depth ; _i<_depth_limit ; _i++ ))
        do
            $_debug && echo "DEBUG showing level $_i"
            _source=${BASH_SOURCE[_i]}
            ((_i>0)) && _lineno=${BASH_LINENO[_i-1]}
            ((_lineno)) || _lineno=

            echo >&2 "$_message${_lineno:+ at line $_lineno}${_source:+ in $_source}"

            $_only1 && break

            _funcname=${FUNCNAME[_i+1]}
            case $_funcname in
            (source|main)   _funcname="" ;;
            ('')            _funcname="[command line]" ;;
            esac
            _message="  called${_funcname:+ from $_funcname}"
        done
    else
        echo >&2 "$_message"
    fi
    ${_exitcode:+:} false && die $_exitcode
}
_provides cluck
