__LOADING_FILE__=$HOME/.sh-lib/require.bash

: ${FPATH="/usr/lib/sh-lib:/usr/local/lib/sh-lib:$HOME/.sh-lib"}

# Never abort an interactive shell because of failure, but always give diagnostics
[[ $- = *i* ]] && __REQUIRE_FAILURE_ISFATAL__=false __REQUIRE_FAILURE_VERBOSE__=true

function _require_warning {
    "${__REQUIRE_FAILURE_VERBOSE__:-true}" && printf >&2 '# %s\n' "$*"
}

function _require_failed {
    _require_warning "$@"
    "${__REQUIRE_FAILURE_ISFATAL__:-true}" && exit 63
}

function _provides {
    local _r
    __LOADED_FUNCS__="${__LOADED_FUNCS__%\;};"
    for _r do
        case "$__LOADED_FUNCS__" in
        (*";$_r<$__LOADING_FILE__;"*) ;;
        (*) __LOADED_FUNCS__+="$_r<$__LOADING_FILE__;" ;;
        esac
    done
}

function _is_loaded {
    __LOADED_FUNCS__="${__LOADED_FUNCS__%\;};"
    [[ "$__LOADED_FUNCS__" = *";$1<"* ]]
}

function _unload_function {
    local _r=$1
    __LOADED_FUNCS__="${__LOADED_FUNCS__%\;};"
    unalias 2>/dev/null "$_r"
    unset -f "$_r"
    _is_loaded "$_r" &&
        __LOADED_FUNCS__="${__LOADED_FUNCS__%%";$_r<"*};${__LOADED_FUNCS__#*";$_r<"*";"}"
}

function _load_file {
    local _f="$1" _r="$2" ; shift ; shift
    local __LOADING_FILE__=$_f
    ((!_verbose)) || printf >&2 -e "# loading '%s' ... " "$_r"
    unalias 2>/dev/null "$_r"
    . "$_f" "$@" || {
        _require_failed ". $_f returned status $? while trying to load $_r"
        return 66  # EX_NOINPUT
    }
    _is_loaded "$_r" || {
        _require_failed "$_r is not provided by $_f"
        return 63
    }
    #_provides "$_r"
    ((!_verbose)) || printf >&2 '# loaded "%s"\n' "$_r"
    return 0
}

function require {
    local true=1 false=0
    local _dont_reload=true
    local _verbose=false
    local _load_from_path
    while
        case $1 in
        (--) shift ; false ;;
        (--help) printf 'require [--verbose|--quiet] [--reload] [--path=FILEPATH] {function-name}\n' ; return 0 ;;
        (-p | --path) _load_from_path="$2" ; shift ;;
        (--path=*) _load_from_path="${1#--*=}" ;;
        (-f | --force-reload \
        |-r | --reload) _dont_reload=false ;;
        (--dont-reload) _dont_reload=true ;;
        (-v | --verbose) _verbose=true ;;
        (-q | --quiet)   _verbose=false ;;
        (-*) _require_failed "require[function]: invalid option '$1'" ; return 64 ;;
        (*)  false ;;
        esac
    do
        shift
    done

    local _r="$1"
    shift

    if _is_loaded "$_r" && ((_dont_reload))
    then
        ((!_verbose)) || printf >&2 '# "%s" is already loaded\n' "$_r"
        return 0
    fi

    _unload_function "$_r"

    if [[ -n "$_load_from_path" ]]
    then
        ((!_verbose)) || printf >&2 '# trying to load "%s" from "%s"\n' "$_r" "$_load_from_path"
        _load_file "$_load_from_path" "$_r" "$@"
    else

        local _d _f _s
        local -a _dd
        mapfile -t _dd < <( IFS=: ; printf '%s\n' $FPATH )

        for _s in .bash .sh ""
        do
            for _d in "${_dd[@]}"
            do
                _f="${_d:-.}/$_r$_s"
                ((!_verbose)) || printf >&2 '# trying to load "%s" from "%s"\n' "$_r" "$_f"
                if [[ -f "$_f" && -r "$_f" ]]
                then
                    _load_file "$_f" "$_r" "$@"
                    return $?
                fi
            done
        done

        _require_failed "# '$_r' cannot be loaded"
        return 63
    fi
}

_provides _is_loaded _load_file _provides _require_failed _unload_function require

if [[ -n "$*" ]]
then
    require autoload
    if [[ "$*" = --all ]]
    then
        for _p in $HOME/.sh-lib/* ; do
            _f=${_p##*/} _f=${_f%.*sh}
            autoload $_f --
        done
    else
        for _f do
            autoload $_f --
        done
    fi
fi

unset __LOADING_FILE__
