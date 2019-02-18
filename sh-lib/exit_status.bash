#!/module/for/bash

declare -Air EX_values=(

    # POSIX/C stdlib.h

    [SUCCESS]=0      # Successful exit status.
    [FAILURE]=1      # Failing exit status.

    # BSD's sysexits.h

    [OK]=0             # successful termination
    [_BASE]=64         # base value for error messages
    [USAGE]=64         # command line usage error
    [DATAERR]=65       # data format error
    [NOINPUT]=66       # cannot open input
    [NOUSER]=67        # addressee unknown
    [NOHOST]=68        # host name unknown
    [UNAVAILABLE]=69   # service unavailable
    [SOFTWARE]=70      # internal software error
    [OSERR]=71         # system error (e.g., can't fork)
    [OSFILE]=72        # critical OS file missing
    [CANTCREAT]=73     # can't create (user) output file
    [IOERR]=74         # input/output error
    [TEMPFAIL]=75      # temp failure; user is invited to retry
    [PROTOCOL]=76      # remote error in protocol
    [NOPERM]=77        # permission denied
    [CONFIG]=78        # configuration error
    [_MAX]=78          # maximum listed value

    # Local

    [FAIL]=1           # like EXIT_FAILURE but in sysexits' style
    [BUG]=96           # local
    [BROKEN]=255       # local
    #[STATUS]=$?        # local - NOTE: can't be defined here, must be defined immediately after the relevant command

    # Shell

    [NOEXEC]=127       # common indicator, from shell, sudo, etc

)

declare -a EX_names=( [0]='SUCCESS' [1]='FAILURE' )
for _v in "${!EX_values[@]}"; do
    _=${EX_names[${EX_values[$_v]}]=$v}
done
declare -ar EX_names

declare -Air SIGvalues=(
    # From Linux 'kill -l'
    [SIGHUP]=1
    [SIGINT]=2
    [SIGQUIT]=3
    [SIGILL]=4
    [SIGTRAP]=5
    [SIGABRT]=6
    [SIGIOT]=6
    [SIGBUS]=7
    [SIGFPE]=8
    [SIGKILL]=9
    [SIGUSR1]=10
    [SIGSEGV]=11
    [SIGUSR2]=12
    [SIGPIPE]=13
    [SIGALRM]=14
    [SIGTERM]=15
    [SIGSTKFLT]=16
    [SIGCHLD]=17
    [SIGCONT]=18
    [SIGSTOP]=19
    [SIGTSTP]=20
    [SIGTTIN]=21
    [SIGTTOU]=22
    [SIGURG]=23
    [SIGXCPU]=24
    [SIGXFSZ]=25
    [SIGVTALRM]=26
    [SIGPROF]=27
    [SIGWINCH]=28
    [SIGIO]=29
    [SIGPWR]=30
    [SIGSYS]=31
)

declare -a SIGnames=()
for _v in "${!SIGvalues[@]}"; do
    _=${SIGnames[${SIG_values[$_v]}]=$v}
done
declare -ar SIGnames

exit_status() {
    local __ex=$1 __sig=$((__ex&~128)) end_color=$2 ok_color=$3 failed_color=$4 killed_color=$5
    case $__ex in
    0) echo "exited with ${ok_color}SUCCESS${end_color} (0)" ; return ;;
    1) echo "exited with ${failed_color}FAILURE${end_color} (1)" ; return ;;
    255) echo "exited with ${failed_color}BROKEN${end_color} (255)" ; return ;;
    esac

    if ((__ex != __sig)) && [[ ${SIGnames[__sig]} ]] ; then
        echo "was killed by ${SIGnames[__sig]}"
        return
    fi

    if [[ ${EX_names[__ex]} ]] ; then
        echo "exited with ${failed_color}${EX_names[__ex]}${end_color} ($((__ex)))"
        return
    fi

    echo "exited with ${failed_color}CODE $((__ex))${end_color}"
}

_provides exit_status
