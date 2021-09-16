function _ruler {
    local w=$COLUMNS
    [[ $w ]] ||
        read _ w _ < <( stty size ) ||
        w=80
    local R
    printf -v R '%*s' $w -
    R=${R//?/-}
#   local R=- T= 
#   for ((; w>0 ; w/=2 )) do
#       (( w&1 )) && R="$R$T"
#       T="$T$T"
#   done
    (( $# )) &&
        case $1 in
            -c | --clear)   printf '\ec' ;;
            *)              printf >&2 'Invalid option %s\n' "$1" ; return 1 ;;
        esac
    printf '\e[7m%s\e[m\n' "$R"
}
_provides _ruler
