#
# Note the convention to use "function foo" rather than "foo()" so that aliases
# can't mangle these declarations.

: ${FPATH="/usr/lib/sh-lib:/usr/local/lib/sh-lib:$HOME/.sh-lib"}

# Never abort an interactive shell because of failure, but always give diagnostics
[[ $- = *i* ]] && __REQUIRE_FAILURE_ISFATAL__=false __REQUIRE_FAILURE_VERBOSE__=true

function __require_warning {
    "${__REQUIRE_FAILURE_VERBOSE__:-true}" && printf >&2 '# %s\n' "$*"
}

function __require_failed {
    __require_warning "$@"
    "${__REQUIRE_FAILURE_ISFATAL__:-true}" && exit 63
}

if (( 4 <= BASH_VERSINFO[0] ))
then
    # version 4.0α introduced associative arrays, and ;& and ;;&

    declare -A __require_LOADED2

    function _provides {
        local _r _g _f
        _f=$( readlink -e ${BASH_SOURCE[1]} )
        for _r do
            _g=${__require_LOADED2[$_r]}
            __require_LOADED2[$_r]=$_f
            [[ -n $_g && $_g != "$_f" ]] && __require_warning "$_r in $_f was already provided by $_g (v4)"
            :
        done
    }
    _provides _provides

    function __require_is_loaded {
        [[ -n ${__require_LOADED2[$1]:+X} ]]
    }
    _provides __require_is_loaded

    function __require_unloaded {
        unset "__require_LOADED2[$1]"
    }
    _provides __require_unloaded

else

    function _provides {
        local _r _g _f
        _f=$( readlink -e ${BASH_SOURCE[1]} )
        for _r do
            case "$__require_LOADED1;" in
            (*";$_r<$_f;"*) ;;
            (*";$_r<"*)
                _g=${__require_LOADED1#*";$_r<"}
                _g=${_g%%';'*}
                __require_warning "$_r in $_f was already provided by $_g (v3)"
                __require_LOADED1+=";$_r<$_f" ;;
            (*) __require_LOADED1+=";$_r<$_f" ;;
            esac
        done
    }
    _provides _provides

    function __require_is_loaded {
        [[ "$__require_LOADED1" = *";$1<"* ]]
    }
    _provides __require_is_loaded

    function __require_unloaded {
        __require_LOADED1+=';'
        __require_is_loaded "$1" &&
            __require_LOADED1=${__require_LOADED1%%";$1<"*};${__require_LOADED1#*";$1<"*";"}
        __require_LOADED1=${__require_LOADED1%\;}
    }
    _provides __require_unloaded

fi

_provides __require_warning __require_failed

function __require_load_file {
    local _f="$1" _r="$2" ; shift ; shift
    ((!_verbose)) || printf >&2 -e "# loading '%s' ... " "$_r"
    unalias 2>/dev/null "$_r"
    . "$_f" "$@" || {
        __require_failed ". $_f returned status $? while trying to load $_r"
        return 66  # EX_NOINPUT
    }
    __require_is_loaded "$_r" || {
        __require_failed "$_r is not provided by $_f"
        return 63
    }
    ((!_verbose)) || printf >&2 '# loaded "%s"\n' "$_r"
    return 0
}
_provides __require_load_file

function require {
    [[ ${false+_} ]] || local -ri false=0
    [[  ${true+_} ]] || local -ri  true=1
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
        (-*) __require_failed "require[function]: invalid option '$1'" ; return 64 ;;
        (*)  false ;;
        esac
    do
        shift
    done

    local _r="$1"
    shift

    if __require_is_loaded "$_r" && ((_dont_reload))
    then
        ((!_verbose)) || printf >&2 '# "%s" is already loaded\n' "$_r"
        return 0
    fi

    unalias 2>/dev/null "$_r"
    unset -f "$_r"
    __require_unloaded "$_r"

    if [[ -n "$_load_from_path" ]]
    then
        ((!_verbose)) || printf >&2 '# trying to load "%s" from "%s"\n' "$_r" "$_load_from_path"
        __require_load_file "$_load_from_path" "$_r" "$@"
    else
        local _d _f _s

        local -a _fpath
        while IFS= read -r _d ; do _fpath+=( "$_d" ) ; done < <( IFS=: ; set -f ; printf '%s\n' $FPATH )

        for _s in .bash .sh ""
        do
            for _d in "${_fpath[@]}"
            do
                _f="${_d:-.}/$_r$_s"
                ((!_verbose)) || printf >&2 '# trying to load "%s" from "%s"\n' "$_r" "$_f"
                if [[ -f "$_f" && -r "$_f" ]]
                then
                    __require_load_file "$_f" "$_r" "$@"
                    return $?
                fi
            done
        done

        __require_failed "# '$_r' cannot be loaded"
        return 63
    fi
}
_provides require

function autoload {
    local _p _r _h
    [[ "$*" = --all ]] && set -- "$HOME"/.sh-lib/*.*sh
    for _p do
        _r=${_p##*/}
        _r=${_r%.*sh}
        _h=
        __require_is_loaded "$_r" && continue
        case $_r in
        (autoload|--|.*|*~|*[!0-9a-zA-Z_.:-]*) continue ;;
        (carp|cluck|croak|confess) _h=' -h' ;;  # omit the autoloader function from stack trace
        esac
        unalias 2>/dev/null "$_r"
        if [[ $p = "$r" ]]
        then
            # Was given just a function name
            eval "
                function $_r {
                    require --reload $_r &&
                    $_r$_h \"\$@\"
                }
            "
        else
            # Was given a pathname
            printf -v _p %q "$_p"   # undo eval
            eval "
                function $_r {
                    require --reload --path=\"$_p\" $_r &&
                    $_r$_h \"\$@\"
                }
            "
        fi
    done
}
_provides autoload

# Try hard to figure out whether any args are provided after
# « . "$HOME/.sh-lib/require.bash" »
#
# Set extdebug so that BASH_ARG[CV] are enabled, using a subshell to avoid
# contaminating the current setting.
#
# If no args are given, the outer args are left bound to "$@" (modifiable by
# shift & set), 1 is prepended to BASH_ARGC (rather than 0), and
# ${BASH_SOURCE[0]} is prepended to BASH_ARGV.
# (Perhaps in some future version of Bash this might be fixed so that 0 is
# prepended to BASH_ARGC and BASH_ARGV is unchanged.)
if [[ -n "$*" ]] && ! (
    shopt -s extdebug
    (( BASH_ARGC[0] == 1 )) && [[ ${BASH_ARGV[0]} = "${BASH_SOURCE[0]}" ]] ||
    (( BASH_ARGC[0] == 0 && ${#BASH_ARGC[@]} > 0 )) # in case this gets fixed sometime
   )
then
    autoload -- "$@"
fi
