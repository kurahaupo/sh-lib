# ‘readlink’ has been a required standard command since POSIX 2024 (IEEE Std
# 1003.1-2024). POSIX does not require ‘readlink -e’, but requires ‘realpath’
# instead.
#
# In practice all common systems released since 2004 have included the
# ‘readlink’ command, but POSIX still does not require ‘readlink -e’ so that
# ‘realpath’ must be used instead, and THAT was often not available until much
# later; see .sh-lib/readlink.bash for timeline details.
#
# Also note that it is missing from:
# - AIX without the “Toolbox for Open Source”
# - HP-UX without the “Internet Express” module
#
# If ‘readlink’ is already available, do nothing, otherwise try various ways to
# emulate it.

_provides readlink

if ! command -v readlink > /dev/null 2>&1
then
    if find . -maxdepth 0 -type l -printf %l\\n > /dev/null 2>&1
    then
        # If we have ‘find’ with ‘-printf %l’, then use that.
        # TODO: figure out how to handle paths that start with ‘-’.
        readlink () {
            local E='\n'
            while [[ $1 = -* ]]
            do
                case $1 in
                    -0) E='\0' ;;
                    --|-) shift ; break ;;
                    -*)
                        printf >&2 'readlink(bashfunc): option "%s" not supported\n' "$1"
                        return 2
                esac
                shift
            done
#           for p do
#               [[ -h $p ]] && continue
#               printf >&2 'readlink(bashfunc): "%s" is not a symlink\n' "$p"
#               return 1
#           done
            find "$@" -maxdepth 0 -type l -printf "%l$E"
        }
    else
        # Assume we have ‘ls’ that reports symlinks by appending ‘ -> TARGET’
        readlink () {
            local d o p s E=0
            while [[ $1 = -* ]]
            do
                case $1 in
                    -0) E=1 ;;
                    --|-) shift ; break ;;
                    -*)
                        printf >&2 'readlink(bashfunc): option "%s" not supported\n' "$1"
                        return 2
                esac
                shift
            done
#           for p do
#               [[ -h $p ]] && continue
#               printf >&2 'readlink(bashfunc): "%s" is not a symlink\n' "$p"
#               return 1
#           done
            (
                exec  > >( sed -e '/ -> /!d; s/.* -> //' )
                ((E)) && exec > >( tr '\n' '\0' )
                exec ls -ld -- "$@"
            )
        }
    fi
fi
