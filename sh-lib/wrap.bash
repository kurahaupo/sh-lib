

# Wrap takes the same arguments as echo, and decides whether echo would
# overflow the current output line; if it would, it outputs a newline (and some
# spaces, to keep some indenting).
# (Actually, it takes one extra arg: "-wNUM" to set the wrap-indent.)
# Put everything back into the _ECHO_OPTS and _ECHO_ARGS array variables, so
# the options don't have to be parsed more than once.

_curcol=0
_spaces=" "

function wrap {
    _ECHO_OPTS=()
    local _n=true _e=false _wrap_indent=2 _msg _msg_width
    shopt -q xpg_echo && _e=true
    while (($#)) && [[ $1 = -?* && ( $1 != -*[^neE]* || ( $1 = -*w* && $1 != -*[^neE]*w* && $1 != -*w*[^0-9]* ) ) ]]
    do
        _o="$1" ; shift
        [[ "$_o" = -*w?* ]] && _wrap_indent=${_o#-*w}
        [[ "$_o" = -*w ]] && { _wrap_indent=$1 ; shift ; }
        [[ "$_o" = -*n* ]] && _n=false
        [[ "$_o" = -*e* ]] && _e=true
        [[ "$_o" = -*E* ]] && _e=false
        [[ "$_o" != -w ]] && _ECHO_OPTS+=("${_o%w*}")
    done
    [[ $1 = -- ]] && { _ECHO_OPTS+=("$1") ; shift ; }
    _ECHO_ARGS=("$@")
    local _msg="$*"
    local _msg_width=${#_msg}
    local _need_wrap=false
    if $_e && {
        [[ $_msg = *'\c'* ]] && _n=false
        [[ $_msg = *'\n'* ]]
        }
    then
        _p=${_msg%%'\n'*} _msg=${_msg##*'\n'}
        _msg_width=${#_msg}
        ((_curcol+${#_p} > COLUMNS)) && _need_wrap=true && ((_curcol = 0))
    else
        ((_curcol+_msg_width > COLUMNS)) && _need_wrap=true && ((_curcol = _wrap_indent))
    fi
    if $_need_wrap
    then
        while ((${#_spaces} < _wrap_indent)) ; do _spaces="$_spaces$_spaces$_spaces$_spaces" ; done
        echo -n $'\n'"${_spaces:0:_wrap_indent}"
    fi
    ((_curcol += _msg_width))
    $_n && ((_curcol = 0))
}
_provides wrap
