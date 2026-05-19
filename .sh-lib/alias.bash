################################################################################
# Redefine "alias" so that it creates functions instead; also divert attempts
# by VyOS/EdgeOS to override standard commands.

declare -A BASH_FUNCTION_ALIASES
declare -A BASH_REMAPPED_ALIASES
BASH_REMAPPED_ALIASES[set]=vset
BASH_REMAPPED_REASON=
alias() {
    local _a _b _m _n _p=0 _t=0 _v=0
    for _a do
        case $_a in
          -p)   _p=1 ;;
          -t)   _t=1 ;;
          -v)   _v=1 ;;
          -x)   ;;
          *=*)  _p=0
                _n=${_a%%=*} _b=${_a#*=}
                _m=${BASH_REMAPPED_ALIASES[$_n]:-$_n}
                [[ $_n != $_m && -t 2 ]] &&
                    printf >&2 "\e[1;41mNOTICE\e[49m: use ‘\e[33m%s\e[39m’ ${BASH_REMAPPED_REASON:-instead of} ‘\e[33m%s\e[39m’\e[49;22m\n" "$_m" "$_n"
                unalias "$_n" 2> /dev/null
                eval "
                  $_m () {
                    : '$_n ${_m#$_n} aliased at $( caller )' ;
                    $_b \"\$@\";
                  }"
                BASH_FUNCTION_ALIASES[$_n]=$_m
                ;;
          *)    _p=0
                ((!_t)) && type "$_a"
                ;;
        esac
    done
    if ((!_t && (_p || $#==0))) ; then
        printf 'Real aliases:\n'
        #builtin alias -p
        printf '\t%s\n' "${!BASH_ALIASES[@]}"
        printf 'Functions defined using the "alias" command:\n'
        printf '\t%s\n' "${!BASH_FUNCTION_ALIASES[@]}"
    fi
}
_provides alias

_alias_add_remap () {
    BASH_REMAPPED_ALIASES[$1]=$2
}
_provides _alias_add_remap

_alias_set_remap_reason () {
    BASH_REMAPPED_REASON=$1
}
_provides _alias_set_remap_reason
