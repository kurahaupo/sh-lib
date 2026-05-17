# Want "ip --oneline" by default -- but with a warning, so that we don't forget when scripting

ip() {
    local i warn_about_oneline=1 w _fail
    for (( i=1 ; i<=$# ; i++ )) do
        w=${!i}
        case $w in
          -F) ((++i))
            # skip parameter to '-F' option
            ;;
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
        if ((warn_about_oneline)) && [[ -t 1 ]]
        then
            # have_gitwarn: negative for missing, positive for available, zero for unknown
            if ((! have_gitwarn))
            then
                command -v gitwarn >/dev/null 2>&1
                have_gitwarn=$(( $? ? -1 : 1 ))
            fi

            # have_gitwarn: negative for missing, positive for available, zero for unknown
            if ((! have_ungetc))
            then
                command -v ungetc >/dev/null 2>&1 &&
                ungetc $'\e[H'     # bound to beginning-of-line
                have_ungetc=$(( $? ? -1 : 1 ))
            fi

            if ((have_gitwarn > 0)) && command -v gitwarn >/dev/null 2>&1
            then
                # Not in a pipeline, stop and recommend replacement
                if ((have_ungetc > 0))
                then _fail=()
                else _fail=( --fail )
                fi
                gitwarn --tty "${_fail[@]}" --suggest='ip -o ' --why="You forgot the '-o' flag" -- ip "$@" ||
                    have_gitwarn=0 have_ungetc=0  # something went wrong, re-check next time
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
