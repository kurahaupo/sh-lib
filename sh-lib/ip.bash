# Want "ip --oneline" by default -- but with a warning, so that we don't forget when scripting

ip() {
    local i warn_about_oneline=1 w
    for (( i=1 ; i<=$# ; i++ )) do
        w=${!i}
        case $w in
          -F) ((++i)) ;; # skip parameter to '-F' option
          -?(-)f* )
            # skip parameter to '--family' option
            [[ "-family" = "$w"* ||
              "--family" = "$w"* ]] &&
                ((++i)) ;;
          -[jo]* | --[jo]* )
            # don't complain if '-o' or '--online' or '-j' or '--json' option present on command-line
            [[  "-oneline" = "$w"* ||
               "--oneline" = "$w"* ]] && warn_about_oneline=0 ;;
          -*) ;;        # more options?
          *) break ;;   # stop at end of options
        esac
    done
    if ((warn_about_oneline)) &&
        [[ addr = "$w"* ||
           link = "$w"* ||
           maddr = "$w"* ]]
    then
        for (( ++i ; i<=$# ; i++ )) do
            w=${!i}
            # don't give warning if setting something
            [[ $w = @(set|add|del|delete|flush|help) ]] && warn_about_oneline=0
        done
        if ((warn_about_oneline))
        then
            if [[ -t 1 ]]
            then
                # Not in a pipeline, stop and recommend replacement
                gitwarn --suggest='ip -o ' --why="You forgot the '-o' flag" -- ip "$@";
                return 99
            else
                # In pipeline, run anyway
                echo >&2 "# using 'ip -o ...'"
                set -- -o "$@"
            fi
        fi
    fi
    command ip "$@"
}
_provides ip
