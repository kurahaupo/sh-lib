function _del_path_ {
    PATH=:$PATH:
    for _p
    do
        case $PATH in
        (*:$_p:*)
            _p1=${PATH%%:$_p:*}
            _p2=${PATH#$_p1:$_p:}
            PATH=$_p1:$_p2
            ;;
        esac
    done
    PATH=${PATH%:}
    PATH=${PATH#:}
}
_provides _del_path_
