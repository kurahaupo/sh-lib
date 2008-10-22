function _qcd {
    local _d=$(ucd -p "$1") || return $?
    cd $_d
}
_provides _qcd
alias qcd=_qcd
