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
# Would be nice if all of uname's components were provided, not just
#   HOSTTYPE (same as uname -m)
#   HOSTNAME (same as uname -n)
_=${HOSTKREL=$( uname -r )}

################################################################################
# In case VyOS has already mangled the environment...

unalias set  2> /dev/null
unset -f set 2> /dev/null

################################################################################
# Read other files, including:
#  * utility functions
#  * tab-completion
#  * aliases

__REQUIRE_FAILURE_VERBOSE__=false \
. ~/.sh-lib/autoload.bash --all

__REQUIRE_FAILURE_VERBOSE__=false \
. ~/.sh-lib/alias.bash

[[ $HOSTKREL = *-UBNT ]] && {
    _alias_set_remap_reason 'wherever the VyOS/EdgeOS documentation says to use'
    _alias_add_remap set vset
    _alias_add_remap rename vrename
}

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

[[ $HOSTKREL = *-UBNT ]] && {
bind '"?":self-insert' # vyatta key binding
bind '"C-_":possible-completions' # vyatta key binding
}
