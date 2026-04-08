function _add_path_ {
    for _p
    do
        case :$PATH: in
        (*:$_p:*) ;;
        (*) PATH=$PATH:$_p ;;
        esac
    done
}
_provides _add_path_
