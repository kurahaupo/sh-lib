
function die {
    original_status=$?
    (( __DIE_DEBUG )) || set +x

    # Because EX_values and SIG_values are readonly, only attempt to set them
    # if they're unset. (Inability to localize and turn off read-only could be
    # construed as a bug in the shell.)
    if (( ${#EX_values[@]} == 0 )); then
        # copied from exit_status.bash
        # status names may be given as either EX_xx or EXIT_xx
        declare -A EX_values=(
            [SUCCESS]=0 [OK]=0 [PASS]=0
            [FAILURE]=1 [FAIL]=1
            [USAGE]=64 [DATAERR]=65 [NOINPUT]=66 [NOUSER]=67 [NOHOST]=68
            [UNAVAILABLE]=69 [SOFTWARE]=70 [OSERR]=71 [OSFILE]=72 [CANTCREAT]=73
            [IOERR]=74 [TEMPFAIL]=75 [PROTOCOL]=76 [NOPERM]=77 [CONFIG]=78
            [BUG]=96 [INTERNAL]=96
            [NOEXEC]=127
            [BROKEN]=255
        )
    fi

    if (( ${#SIG_values[@]} == 0 )); then
        # Linux-specific version; may not work elsewhere.
        declare -A SIG_values=(
            [HUP]=1 [FPE]=8 [STKFLT]=16 [XCPU]=24 [INT]=2 [KILL]=9 [CHLD]=17
            [XFSZ]=25 [QUIT]=3 [USR1]=10 [CONT]=18 [VTALRM]=26 [ILL]=4
            [SEGV]=11 [STOP]=19 [PROF]=27 [TRAP]=5 [USR2]=12 [TSTP]=20
            [WINCH]=28 [ABRT]=6 [PIPE]=13 [TTIN]=21 [IO]=29 [IOT]=6 [ALRM]=14
            [TTOU]=22 [PWR]=30 [BUS]=7 [TERM]=15 [URG]=23 [SYS]=31
        )
    fi

    { exit_code=10#$1                  ; [[ $1 != *[!0-9]*     ]] ; } ||
    { exit_code="EX_values[${1#EX*_}]" ; [[ ${!exit_code+X}    ]] ; } ||
    { exit_code="SIG_values[${1#SIG}]" ; [[ ${!exit_code+X}    ]] && (( exit_code|= 128 )) ; } ||
    { exit_code=original_status        ; [[ $1 = ?(EX*_)STATUS ]] ; } && shift
    if [[ $* ]] ; then
        [[ $1 != *[%\\]* ]] && { IFS=' ' ; set -- '%s\n' "$*" ; } ||
        [[ $1 = *'\n' || $1 = *$'\n' ]] || set -- "$1\\n" "${@:2}"
        printf >&2 "$@"
    fi

    exit $((exit_code))
}

_provides die
