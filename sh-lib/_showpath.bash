function _showpath {
    if [[ $1 = -a ]]
    then
        local _var=${2:?'Missing param'}[@]
        local -a _path=( "${!_var}" )
    else
        local _var=${1:?'Missing param'}
        IFS=: eval 'local -a _path=( ${!_var} )'
    fi
    local _p _h _u
    for _p in "${_path[@]}"
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

[[ $- = *i* ]] &&
p()  { _setpath --colon PATH -v ; }
