function _ruler {
    local R='' T='-' w=$COLUMNS
    [[ $w ]] || {
        read _ w _ < <( stty size ) || w=40
        (( w *= 2 ))
    }
    while
        let "w/=2"
    do  let "w&1" && R="$R$T"
        T="$T$T"
    done
    (( $# )) &&
        case $1 in
            -c | --clear)   printf '\ec' ;;
            *)              echo >&2 "Invalid option $1" ; return 1 ;;
        esac
    printf '\e[7m%s\e[m' "$R"
}
_provides _ruler

#case $SHELL in *bash*) alias l='ls -C' ll='ls -l' ;; esac
