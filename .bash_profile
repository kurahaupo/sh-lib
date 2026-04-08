#
# This file ~/.bash_profile is run by bash(1) for interactive login sessions.
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

test -r ~/.profile && . ~/.profile
trap '' 0       # run .bash_logout instead of .sh_logout
ENV=~/.bashrc
test -r $ENV && . $ENV

case $TMOUT in
    ''|0) ;;
    *) typeset +r TMOUT=
esac

umask 002
