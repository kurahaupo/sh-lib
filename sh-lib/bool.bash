_=${true=1}${false=0}

[[ $true:$false != 1:0 ]] || {
    require confess
    confess -e EX_SOFTWARE
    exit 70
}

readonly -i true false

if [[ -n $true$false ]]
then
else
fi

#_provides true
#_provides false
_provides bool
