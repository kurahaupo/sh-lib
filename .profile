#
# This file ~/.profile is run by standard POSIX sh(1) for interactive login
# sessions; this including Bash when invoked as "sh".
#
# In general this file is not read by bash(1) when ~/.bash_profile or
# ~/.bash_login exists, however the version of .bash_profile that accompanies
# this file DOES read it; Bash-specific enhancements are in that file.
#
# Note shells that are not POSIX compliant are NOT supported. In particular the
# shell must support the $(...) syntax that replaced the older `...`.
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

# Arrange to mount a tmpfs on ~/tmp, but (a) only if it hasn't been done
# already, and (b) only if /etc/fstab includes the appropriate definition.
# (Both of these are indicated by the presence of ~/tmp/.need-tmpfs-mount in
# the to-be-mounted-over directory.)
#
# Also arrange for it to be unmounted when there are no more shells connected
# to it
___home_tmp=$HOME/tmp
if  test ! -d "$___home_tmp"/.
then
    if  test -h "$___home_tmp"
    then
        ___tmp=$( readlink "$___home_tmp" )
    elif test -d /run/user/$UID
    then
        ___tmp=/run/user/$UID/tmp
        ln -sT "$___tmp" "$___home_tmp"
    else
        ___tmp=$___home_tmp
    fi
    mkdir -p -m700 "$___tmp"/.defer-runfs-unlink
fi

if  test -f "$___home_tmp"/.need-bind-mount
then
    ___tmp=/run/user/$UID/tmp
    mkdir -p -m700 "$___tmp"/.defer-tmpfs-umount &&
    mount --bind "$___tmp" "$___home_tmp"
fi

if  test -f "$___home_tmp"/.need-tmpfs-mount
then
    mount "$___home_tmp" &&
    mkdir -p -m700 "$___home_tmp"/.defer-tmpfs-umount
fi

if  test -d "$___home_tmp"/.defer-tmpfs-umount
then
    ___umount_at_exit() {
        exec 9>&-
        umount "$___home_tmp" 2>/dev/null   # will fail silently if more than one process has this open
    }
    trap ___umount_at_exit 0
    exec 9> "$___home_tmp"/.defer-tmpfs-umount/$$
fi

# the default umask is set in /etc/profile
umask 077
#ulimit -c 0    # like nice(2), this is irreversible, so don't set it unless we *have* to

# set PATH so it includes user's private bin if it exists
for _dd in ~/sbin- ~/bin+ /usr/local/bin+ /usr/local/sbin- ${DISPLAY:+/usr/X11R6/bin}
do
    _d=${_dd%[-+]}
    _e=${_dd#"$_d"}
    case :$PATH: in
        *:$_d:*) continue
    esac

    {
        test -d "$_d" &&
      ! test -h "$_d"
    } || continue
    case $e in
        -) PATH="$_d:$PATH" ;;
        *) PATH="$PATH:$_d"
    esac
done

#TZ=Pacific/Auckland
#TZ=Australia/Sydney
#LANG=en_NZ.UTF-8
LANG=C.UTF-8
LC_COLLATE=C
EDITOR=vim
VISUAL=vim
PAGER=less
VERSION_CONTROL=numbered
LS_OPTIONS=-AFC
HTML_TIDY=$HOME/.tidyrc
RSYNC_RSH='ssh -o ClearAllForwardings=yes -x'
PERL5LIB=$HOME/lib/perl

export EDITOR HTML_TIDY LANG LC_COLLATE LS_OPTIONS PAGER PERL5LIB RSYNC_RSH TZ VERSION_CONTROL VISUAL

case $COLORTERM:$TERM in
    :*-256color)
        COLORTERM=truecolor 
        export COLORTERM ;;
esac

: ${HOSTNAME:=$( uname -n )}  # shouldn't be needed, but just in case

# Emulate bash's $HOME/.bash_logout
test -n "$BASH_VERSION" || trap 'test -f "$HOME"/.sh_logout && . "$HOME"/.sh_logout' 0

test -x "$HOME"/bin/ts && "$HOME"/bin/ts --quiet --login >/dev/null 2>&1
export LESSCHARSET=utf-8 LESS=-RS
