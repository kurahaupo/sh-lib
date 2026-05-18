#
# This file ~/.bashrc is run by bash(1) for interactive non-login sessions and
# for remotely invoked (non-interactive) sessions.
#
################################################################################
#
# An interactive POSIX login session runs:
#
#   ~/.profile (this file), OR if that's missing
#   /etc/profile
#
# An interactive Bash login session runs these:
#   /etc/profile, THEN
#       ~/.bash_profile OR if that's missing,
#       ~/.bash_login OR if that's missing,
#       ~/.profile
#
# An interactive non-login session runs these:
#   /etc/bash.bashrc, THEN
#   ~/.bashrc
#
# A remotely initiated non-interactive session runs:
#   ~/.bashrc
#
# On Debian, the system files' inclusion tree expands as:
#   /etc/profile
#       -> /etc/bash.bashrc
#           ?-> /etc/bash_completion
#               -> /usr/share/bash-completion/bash_completion
#                   -> ~/.bash_completion
#                       -> ~/.bash_completion.d/*
#
# These home-dir files' inclusion tree expands as:
#   ~/.bash_profile
#       -> ~/.profile
#           -> ~/.bashrc
#               -> $BASHENV
#               -> ~/.bashrc.d/*
#               -> ~/.bash_prompt
#               -> ~/.sh-lib/*.bash
#               -> ~/.bash_aliases
#                   -> ~/.bash_aliases.d/*
#               -> ~/.bash_completion
#               -> /etc/bash_completion  (unless already processed)
#
################################################################################

################################################################################
# If not running interactively, then we must be coming over a network
# connection; do a very minimal setup.
[[ $PSfake ]] && PS1=$PSfake

if [[ -z "$PS1" ]]
then
    #echo >&2 "Starting non-interactive shell [$$] $0 $*"
    umask 002
    return
fi

shopt -s extglob    # alters parsing of other files
shopt -s extdebug   # find errors?

################################################################################
# This chunk stolen from .bash_completion.d/_zcomp.bash
#
# Check for supported shells
# BASH_VERSION can be avoided, because BASH_VERSINFO was added to Bash v2.0
#

(( __zc_BASH_VERSION = BASH_VERSINFO[0] * 1000000 + BASH_VERSINFO[1] * 1000 + BASH_VERSINFO[2] ))

################################################################################
# having "true" and "false" as numeric variables means that we can write
#
#   fubar=true
#   …
#   if (( fubar ))
#
# rather than the more cumbersome
#
#   if [[ $fubar = true ]]
#

if ((__zc_BASH_VERSINFO < 4002000 ))
then eval '__is_set_var() { declare -p "$1" <>/dev/null 1>&0 2>&0 ; }'
else eval '__is_set_var() { [[ -v $1 ]] ; }'
fi

for c in true=1 false=0
do
    declare -p ${c%%=*} <>/dev/null 1>&0 2>&0
    __is_set_var ${c%%=*} && (( ${c%%=*} == ${c#*=} )) && continue
    declare -i "$c"
    declare -r "${c%%=*}"
done

################################################################################
# Redefine "alias" so that it creates functions instead; also divert attempts
# by VyOS/EdgeOS to override standard commands.

declare -A BASH_FUNCTION_ALIASES
declare -A BASH_REMAPPED_ALIASES
BASH_REMAPPED_ALIASES[set]=vset
BASH_REMAPPED_REASON[set]='use ‘\e[33m%s\e[39m’ where the VyOS documentation says to use ‘\e[33m%s\e[39m’\n'
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
                    printf >&2 "\e[1;41mNOTICE\e[49m: ${BASH_REMAPPED_REASON[$_n]:-'use ‘\e[33m%s\e[39m’ instead of ‘\e[33m%s\e[39m’ alias'}\e[49;22m\n" "$_m" "$_n"
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

################################################################################
# Read other files, including:
#  * utility functions
#  * tab-completion
#  * aliases

__REQUIRE_FAILURE_VERBOSE__=false \
. ~/.sh-lib/autoload.bash --all

for _f in   ~/.bashrc.d/* \
            ~/.bash_aliases \
            ~/.bash_completion \
            ${BASH_ENV:+"$BASH_ENV"}
do
    (( BASHRC_DEBUG )) && printf '%(%F %T)T bashrc: reading %s\n' -1 "$_f"
    [[ -n $_f && -f $_f ]] && . "$_f"
done
unset _f

################################################################################

# In Debian /etc/bash_completion is sourced from /etc/bash.bashrc, but
# sometimes it's commented out or removed by other distributors.
# If so, source it here, but not more than once.

[[ -n $BASH_COMPLETION ||
   -n $BASH_COMPLETION_VERSINFO ||
 ! -f /etc/bash_completion ]] ||
    . /etc/bash_completion

################################################################################
# To override VyOS/EdgeOS key bindings, they must be in ~/.bashrc, unindented,
# with a comment ‘# vyatta key binding’, so that _vyatta_op_do_key_bindings
# will find and use them.

[[ $( uname -r ) = *-UBNT ]] && {
bind '"?":self-insert' # vyatta key binding
bind '"C-_":possible-completions' # vyatta key binding
BASH_REMAPPED_ALIASES[rename]=vrename
}
