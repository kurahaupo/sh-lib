function _ruler {
    local w=$COLUMNS
    [[ $w ]] ||
        read _ w _ < <( stty size ) ||
        w=80
    local R
    printf -v R '%*s' $w -
    R=${R//?/-}
    (( $# )) &&
        case $1 in
            -c | --clear)   printf '\ec' ;;
            *)              printf >&2 'Invalid option %s\n' "$1" ; return 1 ;;
        esac
    printf '\e[7m%s\e[m\n' "$R"
}
_provides _ruler
