function fixed-point {
:
}
_provides fixed-point

fp_set_zeroes() {
    [[ $__fp_zeroes != *[^0]* && $__fp_zeroes != '' ]] ||
        __fp_zeroes=00000000000000000000000000000000
    while (( ${#__fp_zeroes} < digits )) ; do
        __fp_zeroes="${__fp_zeroes}${__fp_zeroes}"
    done
}

fp_to_int() {
    local result=$1 val=$2 digits=$3 x=
    [[ -z $val || $val = *.*.* || ${val/.} = *[^0-9]* ]] && { echo >&2 "Bad decimal '$val'" ; return 1 ;}
    fp_set_zeroes
    if [[ $val = *.* ]]
    then
        x=${val#*.}$__fp_zeroes
        x=${x:0:digits+1}
        ((x+=5))
        val=${val%.*}
    fi
    x=$x$__fp_zeroes
    (($result=$val${x:0:digits}))
}

int_to_fp() {
    local result=$1 val=$2 digits=$3 x= l=${#val}
    [[ -z $val || $val = *[^0-9]* || $val = 0?* ]] && { echo >&2 "Bad integer '$val'" ; return 1 ;}
    fp_set_zeroes
    local denom=1${__fp_zeroes:0:digits}
    (( x = val % denom, val = val / denom ))
    x=.$x
    x=${x%${x##*[^0]}}
    eval $result=\$val\${x%.}
}
