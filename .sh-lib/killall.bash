#
# re-implement killall without any external commands, so that it can be used
# when the system is "stuck"
#
# Arguably I should have implemented pkill instead, which is less fraught when
# talking to non-Linux systems. Maybe I can make a function that combines both?
#
# The way that process groups are managed is awkward: if we knew the pgid
# before scanning /proc, we could then extract the list of pids & names.
#

killall() {
  ( # fix for syntax highlighting ) # (
    # If lifting out of the subshell, (1) change this value; (2) change the
    # "exits" to "returns"; (3) check that every variable is declare'd.
    declare -r already_in_subshell=1

    declare verbose=${KILLALL_verbose:-3}               # NUMBER; a bitwise combination of:
        declare -ri   v_ERROR=0x00f #   errors
        declare -ri    v_WARN=0x00e #   warnings
        declare -ri    v_INFO=0x004 #   progress
        declare -ri   v_TRACE=0x008 #   detailed progress
        declare -ri v_KILLING=0x020 #   killing
        declare -ri v_WAITING=0x040 #   waiting
        declare -ri v_INVOKED=0x100 #   invocation-summary
        declare -ri v_SCALING=0x200 #   time-scaling
        declare -ri v_DUMPALL=0x400 #   dump-vars
        declare -ri  v_SIGNAL=0x800 #   signal-names

    dprintf() {
        local r=$?
        (( verbose & $1 )) || return $r
        printf >&2 "${@:2}"
        return $r
    }

    d2printf() {
        local r=$?
        (( verbose & $1 )) || return $r
        if ((r==0))
        then printf >&2 '\e[36m%-8s' "$2"
        else printf >&2 '\e[33m%-8s' "$3"
        fi
        printf >&2 "$4\e[39m" "${@:5}"
        return $r
    }

    printf -v SECONDS '%(%s)T' -1 # Make sure $SECONDS is time NOW

    ############################################################################
    # PHASE 1
    # Parse parameters
    ############################################################################

    dprintf v_TRACE 'Start parsing options and targets\n'

    declare do_kill=1

    declare context=                # CONTEXT - only kill processes matching the SELinux context
    declare dry_run=                # BOOL - do everything except actually killing & waiting for death
    declare ignore_case=            # BOOL
    declare interactive=            # BOOL
    declare kill_whole_pgrp=        # BOOL
    declare owned_by=               # USER
    declare require_exact=          # BOOL - do not kill processes whose full names are unavailable because they are swapped out
    declare signal=                 # SIGNAL (any name or number accepted by kill -s)
    declare start_after=            # TIME
    declare start_before=           # TIME
    declare use_regex=              # BOOL

    declare show_help=              # BOOL
    declare show_version=           # BOOL
    declare wait_until_dead=        # BOOL

    declare -A target_names=()

    for ((;$#;)) do
        case $1 in

        ( -- )                      # Absorb the rest of the args
                                    while shift && (($#)) ; do target_names["$1"]=1 ; done
                                    ;;

        # ( --s[!-itabec]* ) printf >&2 'Option "%s" is ambigous or invalid\n' "$1" ; exit 64 ;;

        # Options according to "man killall" on Linux
        # try hard to allow unambiguous abbreviations

        ( -e | --e?(x?(a?(ct)))                                       ) require_exact=1 ;;
        ( -g | --p?(r?(o?(c?(ess))))?(-)g?(r?(ou)p)                   ) kill_whole_pgrp=1 ;;
        ( -I | --ig?(n?(ore))?(?(-)c?(a?(se))) | --i?(-)c?(a?(se))    ) ignore_case=1 ;;
        ( -i | --in?(t?(e?(r?(a?(c?(t?(ive)))))))                     ) interactive=1 ;;
        ( -l | --l?(i)?(s?(t))                                        ) kill -l ; exit ;;
        ( -o | --o?(l?(d?(e?(r?))))?(?(-)t?(h?(a?(n))))               ) start_before=$2 ; shift ;;
        ( -q | --q?(u?(i?(e?(t))))                                    ) verbose=0 ;;
        ( -r | --r?(e?(g?(e?(x?(p)))))                                ) use_regex=1 ;;
        ( -s | --s?(i?(g?(n?(a?(l)))))                                ) signal=$2 ; shift ;;
        ( -u | --u?(s?(e?(r)))                                        ) owned_by=$2 ; shift ;;
        ( -V | --vers?(i?(o?(n)))                                     ) show_version=1 ;;
        ( -v | --v?(e?(r?(b?(ose))))                                  ) verbose=7 ;;
        ( -w | --w?(a?(i?(t)))                                        ) wait_until_dead=1 ;;
        ( -y | --y?(o?(u?(n?(g?(er)))))?(?(-)t?(h?(an)))              ) start_after=$2 ; shift ;;
        ( -Z | --con?(text) | --se?(l?(inux)?(?(-)con?(text)))        ) context=$2 ; shift ;;

        #  Additional options and names
        ( -A | --?(s?(t?(a?(r?(t))))?(-))a?(f?(t?(e?(r))))            ) start_after=$2 ; shift ;;       # aka --younger-than
        ( -B | --?(s?(t?(a?(r?(t))))?(-))b?(e?(f?(o?(r?(e)))))        ) start_before=$2 ; shift ;;      # aka --older-than
        ( -  | --n?(a?(m?(e))) \
             | --c@(om?(m?(a?(n?(d))))|m?(d))?(?(-)n?(a?(m?(e))))     ) target_names["$2"]=1 ; shift ;;
        ( -h | --h?(e?(l?(p)))                                        ) show_help=1 ;;
        ( -n | --dr?(y?(?(-)r?(u?(n)))) | --ch?(?(e?(c))k)            ) dry_run=1 ;;
        ( -x | --de?(b?(u?(g)))                                       ) (( verbose  =  ~0 )) ;;
        ( -x=* | --de?(b?(u?(g)))=*                                   ) (( verbose  = (16#${1#*=}  ) )) ;;
        ( -x-=?* | --de?(b?(u?(g)))-=?*                               ) (( verbose &=~(16#(${1#*=})) )) ;;
        ( -x+=?* | --de?(b?(u?(g)))+=?*                               ) (( verbose |= (16#(${1#*=})) )) ;;

        # Cleave args from long options
        (--*=*)                     set -- "${1%%=*}" "${1#*=}" "${@:2}" ; continue ;;

        # Cleave args from short options
        (-[osuyZ]?*)                set -- "${1:0:2}"  "${1:2}"  "${@:2}" ; continue ;;

        # Unbundle other short options
        (-[!-]?*)                   set -- "${1:0:2}" "-${1:2}"  "${@:2}" ; continue ;;

        ([!-]*)                     target_names["$1"]=1 ;;

        (*)                         printf >&2 'Option "%s" is invalid, ambiguous, or unsupported\n' "$1"
                                    exit 64 ;;  # cf exit(EX_USAGE)
        esac
        shift
    done

    if (( show_version ))
    then
        printf >&2 'This version of killall is a shell function; type "declare -pf killall __pinfo" to see its definition\n'
        exit 0
    fi

    if (( show_help ))
    then
        help='
            killall { -V | --version | -h | --help | -l | --list }

            killall [ -e | --exact] [ -g | --process-group ]
                    [ -I | --ignore-case | -r | --regexp ]
                    [ -i | --interactive ]
                    [ -q | --quiet | -v | --verbose ]
                    [ -s SIGNAL | --signal=SIGNAL ] [ -u USER | --user=USER ]
                    [ -w | --wait ]
                    [ -o | --older-than=AGE ] [ -y | --younger-than=AGE ]
                    [ -Z CONTEXT | --context=CONTEXT ]
                    [ {-x|--debug}[[OP]=HEX] ] [NAME ...]

            AGE is a decimal number with an optional suffix { s m h d w M y }.
            CONTEXT is an SELinux context string
            SIGNAL is a signal number or name (as recognized by "kill")
            OP is "+" or "-", to add or remove debug options
            HEX is a hexadecimal number'
        # remove indent to match
        indent=${help%%[! ]*} indent=${indent#$'\n'}
        printf '%s\n' "${help//$'\n'$indent/$'\n'}"
        exit 0
    fi

    if (( interactive || ${#context} ))
    then
        printf '--interactive and --context are not implemented\n'
        exit 70 # cf EX_UNAVAILABLE
    fi

    unset show_version show_help
    __pinfo

  )
}

__pinfo() {

    # Report options & targets if debugging
    (( verbose & v_INVOKED )) && (
        set +x
        declare c0
        printf 'TARGETS'
        printf '\t%s\n' "${!target_names[@]}"
        (( ${#target_names[@]} )) || printf '(none)\n'
        printf 'OPTIONS'
        for c0 in dry_run ignore_case interactive kill_whole_pgrp require_exact use_regex verbose wait_until_dead
        do
            printf '\t%s=%x\n' "$c0" $((c0))
        done
        for c0 in context owned_by signal start_after start_before
        do
            printf '\t%s=%q\n' "$c0" "${!c0}"
        done
    ) >&2

    ############################################################################
    # PHASE 2
    # Validate and normalize parameters
    ############################################################################

    [[ $context || $start_before || $start_after || $owned_by ]] || (( ${#target_names[@]} )) || {
        printf 'Need at least one constraint\n'
        return 65   # cf EX_DATAERR
    }

    dprintf v_TRACE 'Sorting %u targets into regex, names, & paths\n' ${#target_names[@]}

    # Split targets into paths and names, unless --regexp
    declare -A target_paths=()
    declare target_regex=
    if (( use_regex ))
    then
        printf -v target_regex '|%s' "${!target_names[@]}"
        target_regex=${target_regex#'|'}
        target_names=()
    else
        for p in "${!target_names[@]}"
        do
            if [[ $p = */* ]]
            then
                target_paths["$p"]=1
                unset 'target_names[$p]'
            fi
        done
    fi

    # Report options & targets if debugging
    (( verbose & v_INVOKED )) && (
        set +x
        declare c3
        printf 'NAMES'
        printf '\t%s\n' "${!target_names[@]-(none)}"
        #(( ${#target_names[@]} )) || printf '\t(none)\n'
        printf 'PATHS'
        printf '\t%s\n' "${!target_paths[@]-(none)}"
        #(( ${#target_paths[@]} )) || printf '\t(none)\n'
        printf 'REGEX %q\n' "$target_regex"
        for c3 in owned_by signal start_after start_before #context
        do
            printf '\t%s=%q\n' "$c3" "${!c3}"
        done
    ) >&2

    # Check the validity of, and scale the values of, each of the -y & -o options' values, #'

    dprintf v_TRACE 'Scaling --younger-than=%s & --older-than=%s\n' "$start_after" "$start_before"

    declare -Ai t_scale=( [s]=1 [m]=60 [h]=3600 [d]=86400 [w]=604800 [M]=5184000 [y]=31536000 )
    declare p q r x ticks_since_boot
    declare unit_scale
    declare clock_hz=100    # clock ticks per second.

    if [[ $start_after || $start_before ]]
    then
        # We've been given at least one of --younger-than or --older-than,
        # which need to be converted from seconds-ago to ticks-since-boot.
        #
        # For that we need a recent value of time_since_boot. which we obtain
        # by recording the start-time of a recent subshell; if the whole of
        # killall is a subshell then use that, otherwise start one now.

        if (( already_in_subshell ))
        then      read -r x < /proc/self/stat                       # already in a subshell
        else x=$( read -r x < /proc/self/stat && printf %s "$x" )   # make a new subshell
        fi &&
        IFS=' ' \
        <<<"${x##*') '}" \
        read -r _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ ticks_since_boot _
      # An alternative approach is to read "btime" from /proc/stat, and then
      # subtract that from "now", however both of those are seconds rather than
      # ticks and so it loses precision.
    fi

    # Make $start_before/$start_after relative to boot_time, in ticks.
    # These may be decimal fractions, and can take an optional multiplier
    # suffix.

    for r in start_after start_before
    do
        numer=${!r}

        # $numer is value of the respective command-line option
        [[ $numer ]] || continue    # not specified, skip

        # Apply scale suffix, if any
        suffix=${numer:${#numer}-1}
        unit_scale=${t_scale[$suffix]}
        if (( unit_scale ))
        then numer=${numer%"$suffix"}
        else unit_scale=1
        fi

        # FP emulation by scaling
        if [[ $numer = *.* ]]
        then
            if shopt -q extglob
            then numer=${numer%+(0)}
            else while [[ $numer = *0 ]] ; do numer=${numer%0} ; done
            fi
            fraction_part=${numer##*.}
            numer=${numer//.}
        else
            fraction_part=
        fi
        (( denom = 10 ** ${#fraction_part} ))
        (( unit_scale *= clock_hz ))

        case $numer in
        (*[!0-9] | *[!0-9.]*? | *.*.*)
            printf 'Invalid time value %s for %s\n' "${!r}" "$r"
            return 65 ;; # cf EX_DATAERR
        esac

        # reduce risk of numeric overflow by factoring out lcm(numer*unit_scale,denom)
        for (( i=numer,      j=denom ; k=i%j ; i=j, j=k )) do :;done ; (( numer      /= j, denom /= j ))
        for (( i=unit_scale, j=denom ; k=i%j ; i=j, j=k )) do :;done ; (( unit_scale /= j, denom /= j ))

        (( after_boot = ticks_since_boot - ( 2 * numer * unit_scale + 1 ) / ( 2 * denom ) ))

        dprintf v_SCALING '"%s" was %s ago, computed %d ticks since boot\n' "$r" "${!r}" "$after_boot"

        printf -v "$r" %u "$after_boot"
    done

    if [[ $start_before ]] && (( start_before < 0 ))
    then
        dprintf v_WARN 'WARNING: --start-before is before last boot, so all possible processes are excluded\n'
        return 0
    fi

    if [[ $start_before ]] && (( start_after <= 0 ))
    then
        dprintf v_WARN 'WARNING: --start-after is before last boot, so all possible processes are included\n'
        start_after=
    fi

    # Check the validity of the -u option's value

    if [[ $owned_by && $owned_by = *[!0-9]* ]]
    then
        dprintf v_TRACE 'Obtaining numeric UID from --user=%s\n' "$owned_by"
        # non-numeric, look up in /etc/passwd
        local -a pwent
        while IFS=: read -ra pwent ; do
            if [[ ${pwent[0]} = "$owned_by" ]] ;
            then
                dprintf v_TRACE 'Converted --user=%s to %d\n' "$owned_by" "${pwent[2]}"
                owned_by=${pwent[2]}
                break
            fi
            false
        done < /etc/passwd || {
            printf 'No such user "%s"\n' "$owned_by"
            return 67   # cf EX_NOUSER
        }
    fi

    # Check the validity of the -Z option's value

    if [[ $context ]]
    then
        dprintf v_TRACE 'Obtaining UUID from --context=%s\n' "$context"
        printf '-Z not implemented\n'
        return 69   # cf EX_UNAVAILABLE
    fi

    [[ ${signal#SIG} = TEST ]] && signal=0  # name not always supported


    ############################################################################
    # PHASE 3
    # Scan for matching processes
    ############################################################################

    declare old_ignore_case=$( shopt -q nocasematch )$(( $? == 0 ))
    if (( old_ignore_case != ignore_case ))
    then
        dprintf v_TRACE 'Adjusting « shopt nocasematch » from %s to %s\n' $(( old_ignore_case )) $(( ignore_case ))
        if (( ignore_case ))
        then
            (( ! already_in_subshell )) &&
              # ! shopt -q nocasematch &&
                trap ' shopt -u nocasematch ; trap RETURN ' RETURN
            shopt -s nocasematch
        else
            (( ! already_in_subshell )) &&
              # shopt -q nocasematch &&
                trap ' shopt -s nocasematch ; trap RETURN ' RETURN
            shopt -u nocasematch
        fi
    fi

    # These fields in */status are lists with separators
    declare -Ar status_list_separator=(
        [Gid]=$'\t'     # populate Pstatus_gid=(...)
        [Uid]=$'\t'     # populate Pstatus_uid=(...)
        [Groups]=' '    # populate Pstatus_groups=(...)
    )

    declare Pcomm
    declare -a Pcmdline
    declare -A Pstatus
    declare -a Pstatus_uid Pstatus_gid Pstatus_groups
    declare Pstat_comm Pstat_pgrp Pstat_session Pstat_starttime
    #declare -a Pstatm

    # transform target name(s) into target pids and pgrps
    declare -A Targets=()

    declare pid c4

    for pid_path in /proc/[1-9]*
    do
        ####################################################
        # Step 1: validate that the proc dir is accessible
        ####################################################

        dprintf v_TRACE '\nCHECK %s\n' "$pid_path"

        [[ -x $pid_path ]] || continue

        ####################################################
        # Step 2: extract PID from $pid_path itself
        ####################################################

        pid=${pid_path#/proc/}

        if [[ $kDEBUGPID ]]
        then
            if (( pid == kDEBUGPID ))
            then set -x ; (( verbose |=  v_DUMPALL ))
            else set +x ; (( verbose &=~ v_DUMPALL ))
            fi
        fi

        (( verbose & v_DUMPALL )) && declare -p pid

        ####################################################
        # Step 3: restrict processses based on name
        ####################################################

        # {{{ START OF CHECKING PROCESS NAME
        for ((; ${#target_names[@]} || ${#target_paths[@]} || ${#target_regex} ;)) do
            # NB: this is a nonce loop, so that "break" and "continue" make sense

            ####################################################
            #   (3a) extract argv from */cmdline
            ####################################################

            # Read array Pcmdline as null-terminated strings from $pid_path/cmdline
            # (AFTER any redirection to an interpreter)
            #       [0]=cmdname

            dprintf v_TRACE 'READ %s\n' "$pid_path/cmdline"

            Pcmdline=()
            [[ -r $pid_path/cmdline ]] &&
            while IFS= read -r -d '' c4 ; do Pcmdline+=( "$c4" ) ; done <"$pid_path/cmdline"

            (( verbose & v_DUMPALL )) && declare -p Pcmdline

            ####################################################
            #   (3b) extract program name from */comm
            ####################################################
            # Strictly we don't need this because it's duplicate of Pstat_comm
            # (see below), however we don't yet know whether we need to read
            # */comm, and it's cheaper just to read this for now.

            IFS= read -r Pcomm < "$pid_path/comm"

            (( verbose & v_DUMPALL )) &&
            declare -p Pcomm

            ####################################################
            # (3a) check for names & paths
            #   (i) argv[0] or argv[1] in paths or names or regex
            #
            # choose argv[0] or argv[1] based on the first one
            # that matches Pcomm.
            ####################################################

            for (( argi = 0 ; argi < 2 ; ++argi )) do

                (( ${#Pcmdline[@]} > argi )) || ! break

                p="${Pcmdline[argi]}"

                dprintf v_TRACE 'Checking argv[%u]=%q\n' $argi "$p"

                if [[ "${p##*/}" = "$Pcomm"* ]]
                then
                    # argi=0 -> it's a binary executable
                    # argi=1 -> it's an interpreted script
                    if [[ $target_regex ]]
                    then
                        if [[ $p =~ $target_regex ]]
                            d2printf v_TRACE MATCHED Pass 'regex-match argv[%u]=%q =~ %s\n' "$argi" "$p" "$target_regex"
                        then
                            break 2 # MATCHED
                        fi
                    fi

                    # check for exact match with argv[argi]
                    if (( target_paths["$p"] ))
                        d2printf v_TRACE MATCHED Pass 'path-match argv[%u]=%q (among %u)\n' "$argi" "$p" "${#target_paths[@]}"
                    then
                        break 2 # MATCHED
                    fi

                    # check for partial match with argv[0]
                    if (( target_names["${p##*/}"] ))
                        d2printf v_TRACE MATCHED Pass 'name-match argv[%u]=%q (among %u)\n' "$argi" "$p" "${#target_names[@]}"
                    then
                        break 2 # MATCHED
                    fi

                    dprintf v_TRACE 'No Match argv[%u]=%q\n' $argi "$p"

                    ! break     # skip, stop after matching Pcomm
                fi

                dprintf v_TRACE 'Ignore   argv[%u]=%q\n' $argi "$p"
                false           # skip, after last iteration
            done

            ####################################################
            #   (ii) */comm in names or regex
            #
            # Skip this if cmdline was available
            ####################################################

            if (( ${#Pcmdline[@]} == 0 && ${#Pcomm} > 0 && !require_exact || ${#Pcomm} < 15 ))
            then
                if
                    (( target_names["$Pcomm"] )) ||
                    [[ $target_regex && $Pcomm =~ $target_regex ]]
                    d2printf v_TRACE MATCHED skipping 'comm=%q\n' "$Pcomm"
                then
                    break   # MATCHED
                fi
            fi

            ####################################################
            #   (iii) */exe in paths
            ####################################################
            if (( ${#target_paths[@]} ))
            then
                for p in "${target_paths[@]}"
                do
                    if  [[ $pid_path/exe -ef $p ]]
                        d2printf v_TRACE MATCHED skipping 'exe?=%s\n' "$p"
                    then
                        break 2 # MATCHED
                    fi
                done
                dprintf v_TRACE 'Did not match exe\n'
            fi

            ####################################################
            # name match required but missed; skip this process
            ####################################################
            dprintf v_TRACE 'NoMatch  name/path/regex requested but no match\n'

            continue 2
            # reminder: this is a nonce-loop that's only supposed to run through once
        done
        # }}} END OF CHECKING PROCESS NAME

        dprintf v_TRACE 'CONTINUE\n'

        ####################################################
        #   (2d) extract the command name, process state, process group, and
        #   start time from */stat
        ####################################################
        # + the command name lacks a path and is truncated to 15 bytes
        # + the start time is in clock ticks (centiseconds) since boot
        #
        # Read Pstat_* as line with space-delimited fields from $pid_path/stat
        #
        #       [0]=pid [1]=comm [2]=state [3]=ppid [4]=pgrp [5]=session
        #       [6]=tty_nr [7]=tpgid [8]=flags [9]=minflt [10]=cminflt
        #       [11]=majflt [12]=cmajflt [13]=utime [14]=stime [15]=cutime
        #       [16]=cstime [17]=priority [18]=nice [19]=num_threads
        #       [20]=itrealvalue [21]=starttime [22]=vsize [23]=rss [24]=rsslim
        #       [25]=startcode [26]=endcode [27]=startstack [28]=kstkesp
        #       [29]=kstkeip [30]=signal(obsolete) [31]=blocked(obsolete)
        #       [32]=sigignore(obsolete) [33]=sigcatch(obsolete) [34]=wchan
        #       [35]=nswap [36]=cnswap [37]=exit_signal [38]=processor
        #       [39]=rt_priority [40]=policy [41]=delayacct_blkio_ticks
        #       [42]=guest_time [43]=cguest_time
        #       [44...]= (not specified in manual)
        #
        # (Note: comm is the name BEFORE any redirection to an interpreter,
        # which may have embedded spaces; it has to be extracted separately by
        # looking for the surrounding parentheses.)

        dprintf v_TRACE 'READ %s\n' "$pid_path/stat"

        Pstat_comm= Pstat_pgrp= Pstat_session= Pstat_starttime=

        [[ -r $pid_path/stat ]] &&
        IFS='' read -r <"$pid_path/stat" r && {
            #((
            Pstat_comm=${r%') '*} r=${r#"$Pstat_comm"} r=${r#') '}
            IFS=' ' read -r <<<"$r" \
                _ _ Pstat_pgrp Pstat_session _ _ _ _ _ _ \
                _ _ _ _ _ _ _ _ _ Pstat_starttime \
                _
            Pstat_comm=${Pstat_comm#"$pid ("}
        }

        if [[ $Pstat_comm != "$Pcomm" && $Pcomm ]]
        then
            dprintf v_ERROR \
                'WARNING: process %u has name %q in */comm\n\t\t    but name %q in */stat\n\t\t and argv[0]=%q in */cmdline\n\e[33;41;1mSKIPPING\e[39;49;22m\n' \
                "$pid" "$Pcomm" "$Pstat_comm" "${Pcmdline[0]}"
            continue
        fi

        (( verbose & v_DUMPALL )) && declare -p Pstat_comm Pstat_pgrp Pstat_session Pstat_starttime

        ####################################################
        # Step 3b - check that the start time is in range
        ####################################################
        if [[ $start_before ]] ; then
            if (( Pstat_starttime <= start_before ))
                d2printf v_TRACE MATCHED skipping 'starttime=%d ≤ start_before=%d\n' "$Pstat_starttime" "$start_before"
            then :
            else continue
            fi
        fi

        if [[ $start_after  ]] ; then
            if (( start_after <= Pstat_starttime ))
                d2printf v_TRACE MATCHED skipping 'start_after=%d ≤ starttime=%d\n' "$start_after" "$Pstat_starttime"
            then :
            else continue
            fi
        fi

        ####################################################
        #   (2f) extract map Pstatus as "key: value" lines from $pid_path/status
        ####################################################

        dprintf v_TRACE 'READ %s\n' "$pid_path/status"

        Pstatus=() Pstatus_uid=() Pstatus_gid=() Pstatus_groups=()
        while IFS=$': \t\n' read -r k v
        do Pstatus[$k]=$v
        done < "$pid_path/status"
        for k in "${!status_list_separator[@]}"
        do
            IFS="${status_list_separator[$k]}" read -ra Pstatus_${k,,} <<<"${Pstatus[$k]}"
        done

        (( verbose & v_DUMPALL )) && declare -p Pstatus Pstatus_uid Pstatus_gid Pstatus_groups

        ####################################################
        # Step 3c - check for matching UID
        ####################################################
        if [[ $owned_by ]] ; then
            if
                for uid in "${Pstatus_uid[@]}" ; do
                    (( owned_by == uid )) && break
                    false
                done
                d2printf v_TRACE MATCHED skipping 'Owned-by=%u uids=(%s)\n' "$owned_by" "${Pstatus_uid[*]}"
            then :
            else continue
            fi
        fi

        ####################################################
        #   (2e) SKIPPED extract memory info from */statm
        ####################################################

        # Read Pstatm from $pid_path/statm
        #       [0]=total (same as VmSize in $pid_path/status)
        #       [1]=rss (same as VmRSS in $pid_path/status)
        #       [2]=mmap+shared [3]=text [4]=lib(unused)
        #       [5]=data(initdata+bss+stack) [6]=dirty(unused)

        #(( verbose & v_DUMPALL )) &&
        #declare -p pid Pstatm

        ####################################################
        # Step 3d - check for matching SELinux Context
        ####################################################
        if [[ $context ]] ; then : ___ || continue; fi   # TODO: fetch the info from somewhere, and check for matches on each factor

        ####################################################
        # Step 4 - record PID or PGRP as requested
        ####################################################
        dprintf v_TRACE 'FOUND   pid=%d pgrp=%d\n' $((pid)) $((-Pstat_pgrp))
        if (( kill_whole_pgrp ))
        then Targets[-$Pstat_pgrp]=${Pcmdline[0]:-${Pstat_comm}}
        else Targets[$pid]=${Pcmdline[0]:-${Pstat_comm}}
        fi

    done

    (( ${#Targets[@]} )) || {
        printf 'No matching processes\n'
        return 66   # cf EX_NOINPUT
    }

    declare -a sig_opts=()
    [[ $signal ]] && sig_opts+=( -s "$signal" )

    (( do_kill )) || return 0

    if (( dry_run ))
    then
        if [[ $signal && $signal = *[!0-9]* ]]
        then
            # For dry-run, try to warn when the selected signal name is invalid
            # avoid $(...) subshell unless needed
            declare sigs=$( kill -l ) #(
            sigs=${sigs%$'\t'} sigs='signames['${sigs//[$'\t\n']/$'\n['} sigs=${sigs// /} sigs=${sigs//)/']='}
            declare -a signames="($sigs)"
            declare -A signals=( [TEST]=0 )
            for p in ${!signames[@]}
            do
                signals[${signames[$p]#SIG}]=$p
            done
            (( verbose & v_SIGNAL )) && declare -p signals signames
            [[ ${signals[${signal#SIG}]} ]] || {
                printf >&2 'Invalid signal %s\n' "${signal#*:}"
                return 65   # cf EX_DATAERR
            }
        fi

        printf 'WOULD kill %s %s\n' "${sig_opts[*]}" "${!Targets[*]}"
        kill -s 0 "${!Targets[@]}"
        if (( wait_until_dead ))
        then printf 'WOULD wait for them to die\n'
        fi
        return
    fi

    dprintf v_KILLING 'kill %s\n' "${sig_opts[*]} ${!Targets[*]}"
    kill "${sig_opts[@]}" "${!Targets[@]}"

    if (( wait_until_dead ))
    then
        while
            for p in "${!Targets[@]}"
            do
                # 'kill -s 0' works for both individual processes and process groups
                kill -s 0 "$p" >&3 2>&3 &&
              # if (( p <= 0 ))
              # then kill -s 0 "$p" >/dev/null 2>&1 # test process group
              # else [[ -d /proc/$p ]]              # test individual process
              # fi &&
                    continue
                dprintf v_WAITING '%-6d %s has died\n' "$p" "${Targets[p]}"
                unset 'Targets[$p]'
            done
            (( ${#Targets[@]} ))
        do
            sleep 1
        done 3>/dev/null
    fi
}

_provides killall
