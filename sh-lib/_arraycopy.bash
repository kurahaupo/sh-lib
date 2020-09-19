
if ( declare -n ___ac_ref=othervar ) 2> /dev/null
then
    _arraycopy() {
        declare -n ___ac_ref=$1
        shift
        ___ac_ref=( "$@" )
    }
elif ( printf -v aa[4] XX ) 2> /dev/null
then
    _arraycopy() {
        declare ___ac_ref=$1 ___ac_i
        shift
        for ((___ac_i=1;___ac_i <= $#; ++___ac_i)) do
            printf -v "$___ac_ref[___ac_i]" %s "${!___ac_i}"
        done
    }
else
    _arraycopy() {
        declare ___ac_ref=$1
        shift
        eval "$___ac_ref"'=("$@")'
    }
fi

_provides _arraycopy
