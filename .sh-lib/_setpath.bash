_setpath ()
{
    [[ -n ${true+_}  ]] || local -ri true=1  || { echo >&2 ERROR cannot set true=1 in _setpath  ; return 2 ; }
    [[ -n ${false+_} ]] || local -ri false=0 || { echo >&2 ERROR cannot set false=0 in _setpath ; return 2 ; }
    (( true == 1 && false == 0 )) || { echo >&2 ERROR: true=$true false=$false ; return 2 ; }
    local -ri ALLOW=0 PERMIT=0
    local -ri ALWAYS=1 DO=1 FORCE=1 NEED=1 REQUIRE=1
    local -ri AVOID=-1 DONT=-1 FORBID=-1 NEVER=-1 NO=-1 NOT=-1 PROHIBIT=-1
    local -ri UNEQUAL=2

    local   pathvar= mode=end clear=false \
            sep=: prefix= suffix= realpath=false verbose=false \
            if_exist=false if_dir=false if_file=false if_link=false \
            if_notlink=false \
            use_hosttype=false move=all xrel= dot=ALLOW \
            quotenext=false quoteall=false
    local   arg elem orig_arg pi xdir xpart
    local -a path=() xparts=()

    if [[ $* = "-h" || "--help" = "$*"* && $* = "--h"* ]]
    then
        cat <<EOM
Usage: $FUNCNAME [options...] {variable-name} [[--append|--preface|--delete|--clear] path]...
Options include:
   --allow-dot, --allow-empty                   Take "." or "" as given but synonymous
   --avoid-dot, --force-empty                   Convert "." to ""
   --force-dot, --avoid-empty                   Convert "" to "."
   --no-merge-[dot-empty|empty-dot]             Treat "." and "" as distinct
   --if-exists, --if-dir, --if-file, --always   Test path before adding it?
   --move, --move-if-rel, --move-if-abs         What if a path is already there
   --use-host-type                              Include architecture-specific suffices on paths
   --separator=:, --colon                       Default separator is colon; also recognizes semicolon, comma & space
   --prefix="", --suffix=""                     Default prefix & suffix are empty

   --verbose                                    Print final result
   --help                                       This message

        These defaults are useful for PATH, LD_LIBRARY_PATH and many others, but
        it can also be used to set directories in CCFLAGS by using --space -I
EOM

        return 0
    fi

    orig_arg=$1
    while (($#))
    do
        arg="$1"
        shift

        (( quoteall || quotenext)) || {
            case $arg in
                (-- | --quote-all)          quoteall=true ;;
                (- | -q | --quote-next)     quotenext=true ;;
                (--always)                  if_dir=false if_file=false if_link=false if_notlink=false if_exist=false realpath=false ;;
                (--dot=[A-Z]*)              dot=${arg#*=} ;;
                (--empty=[A-Z]*)            dot=-${arg#*=} ;;
                (--if-dir | -d)             if_dir=true if_exist=false ;;
                (--if-exists | -e)          if_exist=true ;;
                (--if-file | -f)            if_file=true if_exist=false ;;
                (--if-link | -l)            if_link=true if_exist=false if_notlink=false ;;
                (--if-not-link | -h)        if_notlink=true if_link=false ;;
                (--move | --move=FORCE)     move=all ;;
                (--move-if-@(abs|rel))      move=${arg##*[=-]} ;;
                (--move=NEVER)              move=none ;;
                (--prefix=*)                prefix=${arg#-*=} ;;
                (--real-path | --follow)    require realpath && realpath=true ;;
                (--real-path=NEVER | --follow=NEVER)            realpath=false ;;
                (--?(separator=)colon)      sep=':' ;;
                (--?(separator=)comma)      sep=',' ;;
                (--?(separator=)semicolon)  sep=';' ;;
                (--?(separator=)space)      sep=' ' ;;
                (--separator=*)
                                            printf -v sep %b "${arg#-*=}"
                                            (( ${#sep} == 1 )) || {
                                                echo >&2 "# $FUNCNAME: Invalid separator '$sep' (not a single character)"
                                                return 1
                                            }
                                            ;;
                (--no-merge-@(dot-empty|empty-dot))
                                            dot=UNEQUAL ;;
                (--suffix=*)                suffix=${arg#-*=} ;;
                (--use-host?(-)type)        use_hosttype=true xparts=() ;;
                (--use-host?(-)type=[A-Z]*)
                                            use_hosttype=${arg#*=}
                                            (( use_hosttype = use_hosttype > 0 ))
                                            xparts=()
                                            ;;

                (-[A-Z])                    sep=' ' prefix=$arg ;;
                (-[#%^+:,/\;])              sep=${arg:1} ;;

                (-a | --append)             mode=end xparts=() ;;
                (-c | --clear)              clear=true xparts=() ;;
                (-k | --delete)             mode=delete xparts=() ;;
                (-p | --preface | --prepend | --prefix)
                                            mode=begin xparts=() ;;
                (-v | --verbose)            verbose=true ;;

                ( --@(allow|always|avoid|do|dont|forbid|force|need|never|no|not|permit|prohibit|require)-* )
                                            pi=${arg#--*-} arg=${arg%-"$pid"} arg=${arg#--}
                                            set -- "--$pi=${arg^^}" "$@"
                                            continue ;;

                ( --*=DO )                  set "${arg%%=*}" "$@" ; continue ;;
                ( --*=PERMIT )              set -- "${arg%%=*}=ALLOW" "$@" ; continue ;;
                ( --*=@(ALWAYS|NEED|REQUIRE) )
                                            set -- "${arg%%=*}=FORCE" "$@" ; continue ;;
                ( --*=@(DONT|NO|NOT|PROHIBIT) )
                                            set -- "${arg%%=*}=NEVER" "$@" ; continue ;;

                (-[^-][^-]*)                set -- "${arg:0:2}" "-${arg:2}" "$@" ;;

                (-*)
                    echo "# $FUNCNAME: Invalid option '$arg'; try '$FUNCNAME --help'" 1>&2
                    return 1
                    ;;
                (*) false ;;
            esac && {
                orig_arg=$2
                continue
            }
        }

        quotenext=false
        if [[ -z $pathvar ]]
        then
            pathvar=$arg
            # First time: initialize path from ${!pathvar}
            IFS="$sep" read -r -a path <<< "${!pathvar}$sep" || path=()
            continue
        fi

        case $arg in
            ( . )   (( dot == PROHIBIT )) && arg=  ;;
            ( '' )  (( dot == FORCE    )) && arg=. ;;
        esac

        if (( ${#xparts[@]} == 0 ))
        then
            # Initialize xparts array
            # Assemble list of trial suffices, in the order they should appear
            # in the path.
            if (( use_hosttype ))
            then
                # For Intel host types, just append "32" or "64" to the
                # prospective directory name; for everyone else, just use the
                # $HOSTTYPE (for now).
                case $HOSTTYPE in
                  # (i*86)          xparts+=( $(( 32 << ( ${HOSTTYPE:0-3} > 600 ) )) ) ;;
                    (i[3-5]86 | ia32)
                                    xparts+=( 32 ) ;;
                    (i686*)         xparts+=( 64 ) ;;
                    (x86_+([0-9]))  xparts+=( "${HOSTTYPE#*_}" ) ;;
                    (*)             xparts+=( "$HOSTTYPE" ) ;;
                esac
            fi

            # Always need an empty suffix as a last resort.
            xparts+=('')

            # If moving to beginning of path, reverse the list so they still
            # wind up in the path in the right order.
            if [[ $mode = begin ]]
            then
                local -i _n _m=${#xparts[@]}-1
                for (( _n=0 ; _n<_m-_n ; ++_n )) do
                    _t=${xparts[_n]}
                    xparts[_n]=${xparts[_m-_n]}
                    xparts[_m-_n]=$_t
                done
            fi
        fi

        for xpart in "${xparts[@]}"
        do
            elem=$arg$xpart
            if [[ $elem = /* ]]
            then xrel=abs
            else xrel=rel
            fi
            # Resolve symlinks, if requested
            if (( realpath ))
            then
                elem=$( realpath "$elem" ) || {
                    echo >&2 ERROR: could not resolve symlink
                    return 2
                }
            fi
            xdir="$prefix$elem$suffix"
            if (( ${#path[@]} )) &&
                for pi in "${!path[@]}"
                do
                    # Either: an exact match
                    [[ "${path[$pi]}" = "$xdir" ]] &&
                        break
                    # or: one is "." and the other is "", but treating them as equivalent
                    [[ "${path[$pi]}$xdir" = . ]] &&
                        (( !( dot & UNEQUAL ) )) &&
                        break
                done
            then
                [[ $mode = delete || ( $move = all || $move = $xrel ) ]] || continue
                unset "path[$pi]"
            fi
            if [[ $xrel = abs ]]
            then
                if (( if_notlink ))
                then
                    [[ ! -h "$elem" ]]
                fi &&
                if (( if_exist ))
                then
                    [[ -e "$elem" ]]
                elif (( if_dir || if_file || if_link ))
                then
                    { (( if_dir   )) && [[ -d "$elem" ]] ; } ||
                    { (( if_file  )) && [[ -f "$elem" ]] ; } ||
                    { (( if_link  )) && [[ -h "$elem" ]] ; }
                fi ||
                continue
            fi

            if ((clear))
            then
                path=()
                clear=false
            fi

            case $mode in
                (begin)
                    path=( "$xdir" "${path[@]}" )
                    ;;
                (delete)
                    ;;
                (*)
                    path=( "${path[@]}" "$xdir" )
                    ;;
            esac
        done
        orig_arg=$1
    done
    printf -v "$pathvar" "%s$sep" "${path[@]}"
    printf -v "$pathvar" "%s" "${!pathvar%"$sep"}"
    (( verbose )) && {
        require _showpath
        _showpath $pathvar 1>&2
    }
}
_provides _setpath

if [[ $- = *i* ]]
then
    sp() { _setpath --colon PATH --if-dir --use-hosttype "$@" ; }
    _provides sp
fi
