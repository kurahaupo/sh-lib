#!/module/for/bash

################################################################################

(( ${#EX_names[@]} == 0 )) && {
    declare -a EX_names=(

        # POSIX/C stdlib.h

        [0]=SUCCESS         # Successful exit status.
        [1]=FAILURE         # Failing exit status.

        # GNU libc

        [127]=NOEXEC        # from system(), and thus used by shell, sudo, etc

        # BSD sysexits.h

        [0]=OK             # successful termination
    #   [64]=_BASE         # base value for error messages
        [64]=USAGE         # command line usage error
        [65]=DATAERR       # data format error
        [66]=NOINPUT       # cannot open input
        [67]=NOUSER        # addressee unknown
        [68]=NOHOST        # host name unknown
        [69]=UNAVAILABLE   # service unavailable
        [70]=SOFTWARE      # internal software error
        [71]=OSERR         # system error (e.g., cannot fork)
        [72]=OSFILE        # critical OS file missing
        [73]=CANTCREAT     # cannot create (user) output file
        [74]=IOERR         # input/output error
        [75]=TEMPFAIL      # temp failure; user is invited to retry
        [76]=PROTOCOL      # remote error in protocol
        [77]=NOPERM        # permission denied
        [78]=CONFIG        # configuration error
    #   [78]=_MAX          # maximum listed value

        # Local conventions

    #   [0]=PASS
    #   [1]=FAIL
        [96]=BUG
        [255]=BROKEN

    #   [STATUS]=$?        # NOTE: must not be defined here, but rather immediately after the relevant command

    )
    declare -r EX_names
}

(( BASH_VERSINFO[0] >= 4 && ${#EX_values[@]} == 0 )) && {
    declare -A EX_values=(

        # POSIX/C stdlib.h
        [EXIT_SUCCESS]=0
        [EXIT_FAILURE]=1

        # Local conventions
        [EX_OK]=0
        [PASS]=0
        [OK]=0
        [EX_FAIL]=1
        [FAIL]=1
    )
    for ___ex_num in "${!EX_names[@]}"
    do
        ___ex_symbol="${EX_names[___ex_num]}"
        EX_values[$___ex_symbol]=$___ex_num
        EX_values[EX_$___ex_symbol]=$___ex_num
    done
    unset ___ex_num ___ex_symbol
    declare -r EX_values
}

################################################################################

# Get signal names from 'trap -l'
(( ${#SIG_names[@]} == 0 )) && {
    declare -a SIG_names=()
    (( BASH_VERSINFO[0] >= 4 )) &&
        declare -Ai SIG_values=()
    IFS=$'\t\n' read -d '' -a ___sig_list < <( trap -l )
    for ___sig_item in "${___sig_list[@]}"
    do
        ___sig_item=${___sig_item#' '}
        [[ -n $___sig_item ]] || continue
        ___sig_num=${___sig_item%%') '*}
        ___sig_symbol=${___sig_item#*') SIG'}
        [[ $___sig_symbol != *[-+]* ]] &&
        (( BASH_VERSINFO[0] >= 4 )) &&
            SIG_values[SIG$___sig_symbol]=$___sig_num \
            SIG_values[$___sig_symbol]=$___sig_num
        _=${SIG_names[$___sig_num]=SIG$___sig_symbol}  # conditional assignment
    done
    unset ___sig_item ___sig_list ___sig_num ___sig_symbol
    declare -r SIG_names SIG_values
}

################################################################################

exit_status() {
    local ret=$? status=${1-$ret} end_color=$2 ok_color=$3 failed_color=$4 killed_color=$5
    local desc
    [[ -t 1 ]] &&
        _=${end_color=$'[39;0m'}${ok_color=$'[32;1m'}${failed_color=$'[31;1m'}${killed_color=$'[34;1m'}
    case $status in
        0)  printf "exited with ${ok_color}SUCCESS${end_color} (0)\n" ;;
        1)  printf "exited with ${failed_color}FAILURE${end_color} (1)\n" ;;
      255)  printf "exited with ${failed_color}CODE 255${end_color} (BROKEN attempt to exit with -1)\n" ;;
        *)  if  desc=${SIG_names[status & 127]}
                (( status & 128 )) && [[ $desc ]]
            then
                printf 'was killed by ${killed_color}%s${end_color}\n' "$desc"
            elif desc=${EX_names[status]}
                [[ $desc ]]
            then
                printf "exited with ${failed_color}%s${end_color} (%d)\n" "$desc" $((status))
            else
                printf "exited with ${failed_color}CODE %d${end_color}\n" $((status))
            fi ;;
    esac
    return $ret
}

################################################################################

_provides exit_status
