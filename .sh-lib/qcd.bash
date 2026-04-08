function qcd {
    local _d=$(ucd -p "$1") || return $?
    cd $_d
}
_provides qcd
