#
# Create "true" and "false" constants.
#
# Treat inability to set correct values as a fatal error.
#
if [[ $true:$false = 1:0 ]]
then
    # readonly without options is safe (and idempotent)
    readonly true false
else

    # if these are already set and readonly, these will (rightly) provoke an error
    true=1
    false=0

    readonly true false

    if [[ $true:$false != 1:0 ]]
    then
        require cluck
        cluck "Non-standard 'true' and/or 'false'"
        declare -p true false
    fi

    if ! ( (( true )) ) ||
         ( (( false )) )
    then
        # -q warn
        cluck -q "Unusable value for 'true' or 'false'"
        if [[ $- != *[il]* ]] || (( SHLVL > 1 ))
        then
            exit 70
        fi
    fi

fi

_provides true
_provides false
_provides bool
