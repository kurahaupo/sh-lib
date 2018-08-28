function autoload {
    local _p _r _h
    for _p do
        _r=${_p##*/}
        _r=${_r%.*sh}
        _h=
        _is_loaded "$_r" && continue
        case $_r in
        (autoload|--|.*|*~|*[!0-9a-zA-Z_.:-]*) continue ;;
        (carp|cluck|croak|confess) _h=' -h' ;;
        esac
        unalias 2>/dev/null "$_r"
        eval "
            function $_r {
                #require -p $_p $_r &&
                require $_r &&
                $_r$_h \"\$@\"
            }
        "
    done
}
_provides autoload
