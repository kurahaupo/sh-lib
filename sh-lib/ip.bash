# Want "ip --oneline" by default -- but with a warning, so that we don't forget when scripting

ip() {
    local i x=true w
    for (( i=1 ; i<=$# ; i++ )) do
        w=${!i}
        # stop at end of options
        [[ $w = -* ]] || break
        # skip parameter to '--family' option
        [[ $w = -F ||
           ( $w =  -f* &&  -family = "$w"* ) ||
           ( $w = --f* && --family = "$w"* ) ]] && ((++i))
        # don't give warning if '--online' option present on command-line
        [[ ( $w =  -o* &&  -oneline = "$w"* ) ||
           ( $w = --o* && --oneline = "$w"* ) ]] && x=false
    done
    if $x
    then
        echo >&2 "# using 'ip -o ...'"
        set -- -o "$@"
    fi
    command ip "$@"
}
_provides ip
