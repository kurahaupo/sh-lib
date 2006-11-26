__LOADING_FILE__=$HOME/.sh-lib/require.bash

: ${FPATH="/usr/lib/sh-lib:/usr/local/lib/sh-lib:$HOME/.sh-lib"}
: ${__REQUIRE_FAILURE_VERBOSE__=true}

case $- in
(*i*) : ${__REQUIRE_FAILURE_FATAL__=false} ;;
(*)   : ${__REQUIRE_FAILURE_FATAL__=true}  ;;
esac

function _provides {
    eval __LOADED__$1=true \
         __LOADED_FILE__$1=\"\$__LOADING_FILE__\"
}
_provides _provides

function _is_loaded {
    case "$1" in
    (*[!a-zA-Z0-9_]*) return 64 ;;
    esac
    #eval "\${__LOADED__$1:+:}" false
    eval "\${__LOADED__$1:-false}"
}
_provides _is_loaded

function _require_failed {
    "${__REQUIRE_FAILURE_VERBOSE__:-true}" && echo >&2 "# $@"
    "${__REQUIRE_FAILURE_FATAL__:-false}"  && exit 63
}
_provides _require_failed

function _load_file {
    local _f="$1" _r="$2" ; shift ; shift
    local __LOADING_FILE__=$_f
    $_verbose && echo >&2 -e "loading '$_r' ... \c"
    . "$_f" "$@" &&
    _is_loaded "$_r" || {
        #_require_failed "$_r is not provided by $_f"
        "${__REQUIRE_FAILURE_VERBOSE__:-true}" && echo >&2 "# $_r is not provided by $_f"
        return 70
    }
    _provides "$_r"
    $_verbose && echo >&2 "loaded '$_r'"
    return 0
}
_provides _load_file

function require {
    local _dont_reload=true
    local _verbose=false
    local _load_from_path
    while
        case $1 in
        (--) shift ; false ;;
        (--help) echo "require [--force-reload] {function-name}" ; return 0 ;;
        (-p | --path) _load_from_path="$2" ; shift ;;
        (--path=*) _load_from_path="${1#--*=}" ;;
        (-f | --force-reload \
        |-r | --reload) _dont_reload=false ;;
        (--dont-reload) _dont_reload=true ;;
        (-v | --verbose) _verbose=true ;;
        (-*) echo >&2 "$FUNCNAME: invalid option '$1'; try '$FUNCNAME --help'" ; return 64 ;;
        (*)  false ;;
        esac
    do
        shift
    done

    local _r="$1"
    shift

    if $_dont_reload && _is_loaded "$_r"
    then
        $_verbose && echo >&2 "'$_r' is already loaded"
        return 0
    fi

    if test -n "$_load_from_path"
    then
        "${_verbose:-false}" && echo >&2 "# trying to load $_r from $_load_from_path"
        _load_file "$_load_from_path" "$_r" "$@"
        return $?
    fi

    local _d _f _s
    for _s in .bash .sh ""
    do
        for _d in $( IFS=: ; echo $FPATH )
        do
            : ${_d:=.}
            _f="$_d/$_r$_s"
            ${_verbose:-false} && echo >&2 "# trying to load $_r from $_f"
            if test -f "$_f" -a -r "$_f"
            then
                _load_file "$_f" "$_r" "$@"
                return $?
            fi
        done
    done

    _require_failed "# '$_r' cannot be loaded"
    return 63
}
_provides require

case $1 in
(--all)
    require autoload
    autoload $(
                shopt -s nullglob   # remove any wildcards that match nothing
                for _d in $( IFS=: ; echo $FPATH )
                do echo $_d/*.bash
                done
            )
    ;;
esac

unset __LOADING_FILE__
