
function enum {
    local l="$1" h="$2" p="$3" s="$4" i
    for (( i=l ; i<=h ; i++ ))
    do
        echo $p$i$s
    done
    (( l<=h ))
}

_provides enum
