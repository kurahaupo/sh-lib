
function ip2num {
    local i=$1 r=0 j
    local -a q x
    q=( 24 16 8 0 )
    IFS=. read -ra x <<<"$i"
    for ((j=0;j<4;j++)) do
        ((r|=x[j]<<(~j<<3&24)))
    done
    printf '%u\n' $r
}
_provides ip2num

function prefix2netmask {
    local n
    (( n=~0<<(32-$1) ))
    num2ip $n
}
_provides prefix2netmask

function num2ip {
    local n=$1
    printf '%u.%u.%u.%u\n' \
            $((n>>24&255)) \
            $((n>>16&255)) \
            $((n>> 8&255)) \
            $((n    &255))
}
_provides num2ip
