function _autoalias {
    local _h="$1" _c="$2"
    shift
    alias $_c="ssh $_h $_c"
    ssh "$_h" "$@"
}
_provides _autoalias
alias @=_autoalias
