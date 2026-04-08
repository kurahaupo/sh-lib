# Remove horrible bogus aliases from /etc/bash.bashrc ...
builtin unalias 2>/dev/null cd.. cp d l. la ls lsd md mv rd rm
# Remove previous aliases from this file; a temporary measure...
#builtin unalias 2>/dev/null ll more mtr p r sp vi which

# Shopt noglob/nullglob/globstar wrapper.
# These need to be aliases so that noglob, nullglob, & globstar options are set
# or unset before any arguments are expanded.
#
# We then need a wrapper function that can invoke the command and revert the
# settings afterwards.
#
# Maybe a future version of Bash will have a way to set controlling options on
# a per-command basis; this would affect:
#   IFS=                (don't word-split)
#   set -f              (don't glob)
#   shopt -s extglob    (tricky, since it affects parsing)
#   shopt -s globstar   (enable '**')
#   shopt -s nullglob   (remove the word when no matches)

__glob_stash() {
    local -i c=$1
    declare -g __saved_glob=$(
        shopt -p globstar nullglob
        shopt -op noglob
        declare -p IFS
    )
    case $1 in
     -*)    shopt -os noglob ; IFS= ;;
     0)     shopt -os noglob ;;
     *)
    esac
    if (( c&4 )) ; then
        shopt -ou noglob
        if (( c&2 )) ; then shopt -s globstar ; else shopt -u globstar ; fi
        if (( c&1 )) ; then shopt -s nullglob ; else shopt -u nullglob ; fi
    else
        shopt -os noglob
    fi
    if (( c&8 )) ; then IFS= ; fi
}
__glob_wrapper() {
    "$@"
    local r=$?
    eval "$__saved_glob"
    unset __saved_glob
    return $r
}

builtin alias --  '-'='__glob_stash 0 ; __glob_wrapper ' # noglob
builtin alias     '+'='__glob_stash 4 ; __glob_wrapper ' # normal       (regex '+' matches 1 or more)
builtin alias     '*'='__glob_stash 5 ; __glob_wrapper ' # nullglob     (regex '*' matches 0 or more)
builtin alias    '++'='__glob_stash 6 ; __glob_wrapper ' # globstar
builtin alias    '**'='__glob_stash 7 ; __glob_wrapper ' # globstar+nullglob
builtin alias -- '--'='__glob_stash 8 ; __glob_wrapper ' # noglob + no wordsplitting
