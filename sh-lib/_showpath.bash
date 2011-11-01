function _showpath {
    local _var=${1:?'Missing param'}
    eval local _path=\"\$$_var\"
    local IFS=:
    for _p in $_path
    do
        case $_p/ in
        $HOME/*) _p='~'${_p#$HOME} ;;
        /)       _p=. ;;
        esac
        echo "    $_p"
    done
    [[ "$_path" = *?: ]] && echo "    ."
}
_provides _showpath
