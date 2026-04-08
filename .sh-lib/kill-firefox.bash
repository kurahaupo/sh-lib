#! /module/for/bash

kill-firefox() {
    local sig=0
    local main=0 tabs=1
    local show=1

    while (($#)) ; do
        case $1 in
         --*=*)             set -- "${1%%=*}" "${1#*=}" "${@:2}" ; continue ;;
         -[s]?*)            set -- "${1::2}"  "${1:2}"  "${@:2}" ; continue ;;
         -[qv]?*)           set -- "${1::2}" -"${1:2}"  "${@:2}" ; continue ;;
         -[no]??*)          set -- "${1::3}" "${1::2}${1:3}" "${@:2}" ; continue ;;

         -s|--sig?(nal))    sig=$2 ; shift ;;
         --reload)          sig=HUP ;;       #  1

         --test   | --hup  | --int    | --quit | --ill   | --trap | --abrt | --bus  | \
         --fpe    | --kill | --usr1   | --segv | --usr2  | --pipe | --alrm | --term | \
         --stkflt | --chld | --cont   | --stop | --tstp  | --ttin | --ttou | --urg  | \
         --xcpu   | --xfsz | --vtalrm | --prof | --winch | --io   | --pwr  | --sys  )
                             sig=${1#--} sig=${sig^^} ;;

         --rt+!(*[!0-9]*))  sig=RTMIN${1#--rt} ;;
         --rt-!(*[!0-9]*))  sig=RTMAX${1#--rt}+1 ;;
         -[0-9]!(*[!0-9]*)) sig=${1#-} ;;
         -SIG*)             sig=${1#-} ;;

         -t|--tabs)                tabs=1 ;;
        -nt|--no-tabs)             tabs=0 ;;
        -ot|--only-tabs)    main=0 tabs=1 ;;

         -m|--main)         main=1 ;;
        -nm|--no-main)      main=0 ;;
        -om|--only-main)    main=1 tabs=0 ;;
        --all)              main=1 tabs=1 ;;

         -q|--quiet  |-nv)  show=0 ;;
         -v|--verbose|-nq)  show=1 ;;

         -*)                printf >&2 "Invalid option '%s'\n" "$1" ; return 64 ;;
         *)                 printf >&2 "Non-option args not allowed ('%s')\n" "$1" ; return 64 ;;
        esac
        shift
    done

    [[ $sig = TEST ]] && sig=0  # not supported by 'killall'
    local -a t=() v=()
    (( tabs ))  && t+=( 'WebExtensions' 'Web Content' )
    (( main ))  && t+=( firefox firefox-bin MainThread )
    (( show ))  && v+=( -v )
    [[ $sig ]]  && v+=( -s "$sig" )
    killall "${v[@]}" "${t[@]}"
}

kf() { kill-firefox "$@"; }

_provides kill-firefox
_provides kf
