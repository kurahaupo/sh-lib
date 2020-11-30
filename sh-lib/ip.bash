# Want "ip --oneline" by default -- but with a warning, so that we don't forget when scripting

ip() {
    local i warn_about_oneline=1 w
    for (( i=1 ; i<=$# ; i++ )) do
        w=${!i}
        # stop at end of options
        [[ $w = -* ]] || break
        # skip parameter to '--family' option
        [[ $w = -F ]] ||
        [[ $w =  "-f"* &&  "-family" = "$w"* ]] ||
        [[ $w = "--f"* && "--family" = "$w"* ]] &&
        ((++i))
        # don't give warning if '--online' option present on command-line
        [[ ( $w =  "-o"* &&  "-oneline" = "$w"* ) ||
           ( $w = "--o"* && "--oneline" = "$w"* ) ]] && warn_about_oneline=0
    done
    if ((warn_about_oneline)) &&
        [[ addr = "$w"* ||
           link = "$w"* ||
           maddr = "$w"* ]]
    then
        echo >&2 "You forgot the '-o' flag"
        return 99
        echo >&2 "# using 'ip -o ...'"
        set -- -o "$@"
    fi
    command ip "$@"
}
_provides ip
