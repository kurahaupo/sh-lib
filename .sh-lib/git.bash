#!/module/for/bash

# Git tries to be smart about paginating output.
#
# By default (if PAGER is unset), it will use "less" as a pager when more than
# a screenful is present (by height OR WIDTH), otherwise the output will be
# unpaged (as if PAGER=cat).
#
# Unfortunately this interacts badly with some cases.

git() {
    LESS= \
    PAGER="${gitPAGER-$PAGER}" \
    MANPAGER="${gitMANPAGER-$MANPAGER}" \
    command git "$@"
}

gitcat() {
    PAGER= \
    command git "$@"
}

gitless() {
    LESS= \
    PAGER='less -RS' \
    command git "$@"
}

# Set gitPAGER to 'less -FX', which behaves like 'cat' when the output is less
# than a screenful. (Note that -X avoids Xterm's "alternate screen", so long
# output may fill up your scrollback buffer, but it's necessary so that the
# short output does not immediately vanish.)
#
# Alternatively, set gitPAGER empty, so that output is not paginated at all.
#
# If gitPAGER is unset, just use $PAGER
#
# Set gitMANPAGER to 'less -RS', so that "git help" will always be paginated.

gitPAGER='less -FRX'
gitMANPAGER='less -RS'

_provides git gitcat gitless
