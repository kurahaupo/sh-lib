: ${FPATH="/usr/lib/sh-lib:/usr/local/lib/sh-lib:$HOME/.sh-lib"}

function autoload {
    local _p _f _h
    for _p
    do
        _f=${_p##*/}
        _f=${_f%.*sh}
        _h=
        case $_f in
        (autoload|*~|.*.sw?) continue ;;
        (carp|cluck|croak|confess) _h=-h ;;
        esac
        _is_loaded "$_f" ||
        eval "
            function $_f {
                #require -p $_p $_f &&
                require $_f &&
                $_f $_h \"\$@\"
            }
        "
    done
}
_provides autoload
