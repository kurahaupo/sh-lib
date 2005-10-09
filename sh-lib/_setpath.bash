function _setpath {
    local   pathvar='' path='' mode=end clear=false arg='' dir='' xdir='' \
            sep=: prefix='' suffix='' realpath=false verbose=false \
            if_dir=false if_file=false if_exist=false xp_before='' xp_after='' \
            reset_xp=false xpart='' use_hosttype=false move=all allowdot=false \
            forcedot=false quotenext=false quoteall=false
    for arg in "$@"
    do
        if ${quoteall} || ${quotenext}
        then
            quotenext=false
        else
            case $arg in
            (-- | --quote-all) quoteall=true ; continue ;;
            (--always) if_dir=false if_file=false if_exist=false ; continue ;;
            (--colon) sep=':' ; continue ;;
            (--dont-move) move=none ; continue ;;
            (--dont-use-hosttype) use_hosttype=false reset_xp=false ; continue ;;
            (--dot=allow | --allow-dot) allowdot=true forcedot=false ; continue ;;
            (--dot=force | --force-dot) allowdot=true forcedot=true ; continue ;;
            (--dot=no | --no-dot) allowdot=false forcedot=false ; continue ;;
            (--if-dir) if_dir=true ; continue ;;
            (--if-exists) if_exist=true ; continue ;;
            (--if-file) if_file=true ; continue ;;
            (--move) move=all ; continue ;;
            (--move-if-abs) move=abs ; continue ;;
            (--move-if-rel) move=rel ; continue ;;
            (--part-prefix=*) prefix=${arg#-*=} ; continue ;;
            (--part-separator=*) sep=${arg#-*=} ; continue ;;
            (--part-suffix=*) suffix=${arg#-*=} ; continue ;;
            (--real-path) realpath=true ; continue ;;
            (--space) sep=' ' ; continue ;;
            (--use-hosttype) use_hosttype=true reset_xp=true ; continue ;;
            (-[A-Z]) sep=' ' prefix=$arg ; continue ;;
            (-a | --append) mode=end reset_xp=true ; continue ;;
            (-c | --clear) clear=true reset_xp=true ; continue ;;
            (-d | --delete) mode=delete reset_xp=true ; continue ;;
            (-h | --help)
                echo "Usage: $FUNCNAME [--verbose] {variable-name} [--append|--prefix|--delete|--clear] {path}..."
                return 0
                ;;
            (-p | --prefix) mode=begin reset_xp=true ; continue ;;
            (-q | --quote-next) quotenext=true ; continue ;;
            (-v | --verbose) verbose=true ; continue ;;
            (-*)
                echo "# $FUNCNAME: Invalid option '$arg'; try '$FUNCNAME --help'" 1>&2
                return 1
                ;;
            esac
        fi
        case $pathvar in
        ('')
            pathvar=$arg
            continue
            ;;
        esac
        case $arg in
        (.)
            $forcedot || $allowdot || arg=
            ;;
        ('')
            $forcedot && $allowdot && arg=.
            ;;
        esac
        if $reset_xp
        then
            reset_xp=false
            xp_before='' xp_after=''
            $use_hosttype && xp_before=" $HOSTTYPE$xp_before"
            case $mode:$xp_before in
            (begin:?*)
                xp_before=" $xp_before"
                while test -n "$xp_before"
                do
                    xpart=${xp_before##*\ }
                    xp_before=${xp_before%\ *}
                    xp_after="$xpart $xp_after"
                done
                xp_before=''
                ;;
            esac
        fi
        for xpart in $xp_before '' $xp_after
        do
            dir=$arg${arg:+${xpart:+/}}$xpart
            case $path in
            ('')
                eval path=\"\${$pathvar+\${sep}\${$pathvar:-.}}\${sep}\"
                case $path in
                (*$sep.$sep*)
                    $allowdot || path="${path%%$sep.$sep*}$sep$sep${path#*$sep.$sep}"
                    ;;
                esac
                ;;
            esac
            xdir="$prefix$dir$suffix"
            case $path in
            (*$sep$xdir$sep*)
                case $mode in
                (delete)
                    path="${path%%$sep$xdir$sep*}$sep${path#*$sep$xdir$sep}"
                    continue
                    ;;
                esac
                case $move:$dir in
                (all:*)  ;;
                (rel:/*) continue ;;
                (rel:*)  ;;
                (abs:/*) ;;
                (abs:*)  continue ;;
                (none:*) continue ;;
                esac
                path="${path%%$sep$xdir$sep*}$sep${path#*$sep$xdir$sep}"
                ;;
            esac
            case $dir in
            (/*)
                if $if_dir && $if_file
                then
                    test ! -d "$dir" -a ! -f "$dir"
                else
                    if $if_dir
                    then
                        test ! -d "$dir"
                    else
                        if $if_file
                        then
                            test ! -f "$dir"
                        else
                            if $if_exist
                            then
                                test ! -e "$dir"
                            else
                                false
                            fi
                        fi
                    fi
                fi && continue
                $realpath && {
                    require _realpath
                    dir=$( _realpath $dir )
                }
                ;;
            esac
            if $clear
            then
                path="$sep"
                clear=false
            fi
            case $mode in
            (begin)
                path="$sep$xdir$path"
                ;;
            (delete)
                ;;
            (*)
                path="$path$xdir$sep"
                ;;
            esac
        done
    done
    case $path in
    ('')
        $clear || {
            eval path=\"\${$pathvar+\${sep}\${$pathvar:-.}}\${sep}\"
            case $path in
            (*$sep.$sep*)
                $allowdot || path="${path%%$sep.$sep*}$sep$sep${path#*$sep.$sep}"
                ;;
            esac
        }
        ;;
    esac
    path="${path#$sep}"
    path="${path%$sep}"
    eval $pathvar=\"\$path\"
    export $pathvar
    $verbose && {
        require _showpath
        _showpath $pathvar 1>&2
        #echo "# $FUNCNAME $pathvar $path"
    }
}
_provides _setpath
