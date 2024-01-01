# Smart function for xargs

unalias 2>/dev/null xargs
xargs() {
    local -a setenv=()
    while [[ $1 = [^-]*=* ]]
    do  setenv=( "${setenv[@]}" "$1" )
        shift
    done
    (( ${#setenv[@]} )) &&
        echo >&2 "# transposing ${#setenv[@]} environment settings from subcommand to xargs itself"
    [[ $1 = -*r* ]] || {
        echo >&2 "Please use 'xargs -r', or use '$( type -P xargs )' if you REALLY want the default behaviour"
        return 99
      # echo >&2 "# using shell alias 'xargs -r ...'"
      # set -- -r "$@"
    }
    ( unset -f xargs ; export PATH "${setenv[@]}" ; exec xargs "$@" )
}
_provides xargs

# self-aliasing so that tab-completion defaults to 'complete -c'
builtin alias xargs='xargs '
