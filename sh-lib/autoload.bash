function autoload {
    local _p _f
    for _p
    do
        _f=${_p##*/}
        _f=${_f%.*sh}
        case $_f in (autoload) continue ;; esac
        _is_loaded "$_f" ||
        eval "
            function $_f {
                #require -p $_p $_f &&
                require $_f &&
                $_f \"\$@\"
            }
        "
    done
}
_provides autoload
