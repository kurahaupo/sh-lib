# ‘realpath’ has been a required standard command since POSIX 2024 (IEEE Std
# 1003.1-2024), as an alternative to ‘readlink -e’, which it does not require.
#
# Most systems released since 2006 have included the ‘realpath’ command;
# exceptions include:
# - AIX prior to 2015, or without the “Toolbox for Open Source”
# - HP-UX prior to 2012, or without the “Internet Express” module
# - NetBSD prior to 2024 (due to minimalist philosophy)
#
# If ‘realpath’ is already available, do nothing, otherwise try various ways to
# emulate it.

_provides realpath

if ! command -v realpath > /dev/null 2>&1
then
    # If we don't have a realpath command, try various ways to emulate it.

    if  command -v readlink > /dev/null 2>&1 &&
        d=$( readlink -e . 2> /dev/null ) &&
        [[ $d = "$( pwd -P )" ]]
    then
        # Between March 2004 & 2012 GNU had ‘readlink -e’ but not ‘realpath’.
        unset d
        realpath () {
            readlink -e "$@"
        }
    else
        require readlink
        # Since 1994 Bash has had
        unset d
        realpath () {
            local d n o p r=0 s
            while [[ $1 = -* ]]
            do
                case $1 in
                    --|-) shift ; break ;;
                    -*)
                        printf >&2 'realpath(bashfunc): option "%s" not supported\n' "$1"
                        return 2
                esac
                shift
            done
            for o do
                [[ -n $o ]] || {
                    r=1
                    printf >&2 'realpath(bashfunc): empty name not allowed\n'
                    continue
                }

                n=0 p=$o
                while
                    s=${p##*/}
                    d=${p%"$s"}
                    [[ -h $p ]] &&
                    s=$( readlink "$p" )
                do
                    ((++n > 99)) || {
                        r=1
                        printf >&2 'realpath(bashfunc): "%s" symlink loop (followed %d symlinks)\n' "$o" "$n"
                        continue 2
                    }
                    case $s in
                      /* )  p=$s ;;
                      */ | '')
                            p=$d$s ;;
                      *)    p=$d/$s ;;
                    esac
                done

                if [[ -d $p ]]
                then
                    d=$p s=
                fi
                d=$( CDPATH=. cd -P "$d" &&
                     pwd -P ) || {
                    r=1
                    printf >&2 'realpath(bashfunc): "%s" is not a reachable directory\n' "$o"
                    continue
                }
                printf '%s\n' "$d$s"
            done
            return "$r"
        }
    fi
else
    # Even when the OS supplies realpath, we can still do better,
    # by using ‘pwd -P’ which is built into Bash.
    realpath () {
        if [[ $1 != -* ]] && (($# < 2)) && [[ -d $1 ]]
        then ( CDPATH=. builtin cd -P -- "$1" && builtin pwd -P )
        else command realpath "$@"
        fi
    }
fi
