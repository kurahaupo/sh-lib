function _showpath {
    local _var=${1:?'Missing param'}
    eval local _path=\"\$$_var\"
    local IFS=: _p _h _u
    for _p in $_path
    do
        case $_p/ in
        $HOME/*) _p='~'${_p#$HOME} ;;
        /home/*/)
                _h=$_p/
                _h=${_h%%"${_h#/home/*/}"}
                _h=${_h%/}
                _u=${_h##/home/}
                IFS=: read _u _ _ _ _ _h _ < <(getent passwd "$_u") &&
                _p='~'$_u${_p#"$_h"}
                ;;
        /)      _p=. ;;
        esac
        echo "    $_p"
    done
    [[ "$_path" = *?: ]] && echo "    ."
}
_provides _showpath
