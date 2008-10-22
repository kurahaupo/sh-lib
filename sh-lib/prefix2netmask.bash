
function ip2num {
    local i=$1 r=0 j
    local -a q=( 24 16 8 0 ) x=( $(IFS=. ; echo $i) )
    for ((j=0;j<4;j++))
    do
        ((r|=x[j]<<q[j]))
    done
    echo $r
}

function num2ip {
    local n=$1
    echo $((n>>24&255)).$((n>>16&255)).$((n>>8&255)).$((n&255))
}

function prefix2netmask {
    local n
    (( n=~0<<(32-$1) ))
    num2ip $n
}

_provides num2ip
_provides ip2num
_provides prefix2netmask
