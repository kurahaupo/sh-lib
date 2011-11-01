function _ruler {
    local R='' T='-' w=${COLUMNS:-$(set -- $(stty size);echo ${2:-80})}\*2
    while
        let "w/=2"
    do  let "w&1" && R="$R$T"
        T="$T$T"
    done
    let $# && case $1 in -c|--clear) echo -n "c" ;; *) echo >&2 "Invalid option $1" ; return 1 ;; esac
    echo "[7m$R[m"
}
_provides _ruler

#case $SHELL in *bash*) alias l='ls -C' ll='ls -l' ;; esac
