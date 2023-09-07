#!/module/for/bash
# Requires Bash 4.0 for negative array indexing from end of array

# adjusted to cope with arbitrarily large numbers

nth() {
    local __eng_num=$1
    case $__eng_num in
    (''|*[!0-9]*) ;;
    (*1[0-9]|*[4-90]) __eng_num+=th ;;
    (*1)              __eng_num+=st ;;
    (*2)              __eng_num+=nd ;;
    (*3)              __eng_num+=rd ;;
    esac
    printf '%s' "$__eng_num"
}
_provides nth

## english_number [-v VAR] [OPTION...] NUMBER ...
#   --prefix TEXT     }
#   --suffix TEXT     } surround each output string
#   --and={english|french|modern|us}
#   --style={english|french|modern|us}|-e|-f|-m|-u
#                   where does the word "and" go?

__eng_shopt_save=$( shopt -p extglob )
shopt -u extglob

english_number() {

    local __eng_conjunction=__eng_conjunction_d __eng_conjunction_d=18
    local __eng_debug=0 __eng_debug2=0
    local __eng_hmin=1000 __eng_hmax=-1
    local __eng_scale=__eng_scale_d __eng_scale_d=0
    local __eng_ordinal=0
    local __eng_output_var= __eng_output_index=0
    local -a __eng_prefix=() __eng_suffix=()
    #local __eng_shopt_save=$( shopt -p extglob )
    #shopt -s extglob
    local __eng_rem __eng_opt
    local -a __eng_T

    for ((; $# > 1 ;)) do
        (( __eng_debug )) && echo "DEBUG ARG: ${*:1:2} ..."
        case $1 in
            -P|--prefix)        __eng_prefix=$2 ; shift ;;
            -S|--suffix)        __eng_suffix=$2 ; shift ;;
            -a?*)               set X -a  "${1#-?}"  "${@:2}" ;;
            --and[-+^=]=*)      set X -a "${1:5:1}${1:7}" "${@:2}" ;;
            --and=*)            set X -a  "${1#-*=}" "${@:2}" ;;
            -a|--and)
                                case $2 in
                                    +*) __eng_rem=0 ;;                         # add
                                    -*) __eng_rem=1 ;;                         # remove
                                    =*) __eng_rem=0 __eng_conjunction=0 ;;     # only
                                    ^*) __eng_rem=1 __eng_conjunction=\~0 ;;   # all but
                                    *)  __eng_rem=0 __eng_conjunction=0 ;;     # only
                                esac
                                __eng_opt=${2#[!0-9]}
                                IFS=' ,' read -ra __eng_T <<<"$__eng_opt"
                                (( __eng_debug )) && echo "DEBUG ARG: --and=$__eng_opt→( ${__eng_T[*]} ):$__eng_rem ..."
                                for __eng_opt in "${__eng_T[@]}"
                                do
                                    case $__eng_opt in
                                        [0-9]*) ;;
                                        n|none)         __eng_opt=0 ;;    # never insert 'and'
                                        o|one)          __eng_opt=1 ;;    # "sixty AND one" in each group
                                        l|last)         __eng_opt=2 ;;    # "AND eleven" in last groups
                                        t|thousand)     __eng_opt=4 ;;    # "thousand AND eleven" in each pair of groups (when using simple long scale)
                                        H|lasthundred)  __eng_opt=8 ;;    # "hundred AND eleven" in last group
                                        h|hundred)      __eng_opt=16 ;;   # "hundred AND eleven" in each group

                                        n|u|none|us)    __eng_opt=0 ;;    # US: never insert 'and'
                                        f|french)       __eng_opt=1 ;;    # French: insert 'and' before 'one' if there are tens
                                        m|modern)       __eng_opt=5 ;;    # Modern/hybrid: insert 'and' before a non-zero mod100 residue when there are hundreds in the same group
                                        e|english)      __eng_opt=23 ;;   # English: insert 'and' before a non-zero mod100 residue when either (a) there are hundreds in the same group, or (b) this is the last of two or more groups

                                        *)              printf >&2 'english_number: invalid conjunction option "%s"\n' "$__eng_opt" ; return 64 ;;
                                    esac
                                    if (( __eng_rem ))
                                    then (( __eng_conjunction &=~ __eng_opt ))
                                        (( __eng_debug )) && echo "DEBUG ARG: --and removed $__eng_opt leaving $__eng_conjunction ..."
                                    else (( __eng_conjunction |=  __eng_opt ))
                                        (( __eng_debug )) && echo "DEBUG ARG: --and added $__eng_opt leaving $__eng_conjunction ..."
                                    fi
                                done
                                shift
                                ;;

            -e|--english)       __eng_conjunction_d=7  __eng_scale_d=1 ;; # English style: long scale with and=NYY
            -f|--french)        __eng_conjunction_d=8  __eng_scale_d=2 ;; # French style: milliard scale with and=YNN
            -m|--modern)        __eng_conjunction_d=16 __eng_scale_d=0 ;; # Modern/hybrid style: short scale with and=NNY
            -u|--us)            __eng_conjunction_d=0  __eng_scale_d=0 ;; # US style: short scale and never insert 'and'
            -j)                 __eng_hmin=1100 __eng_hmax=1999 ;;  # read 1100-1999 as eleven hundred etc
            -k)                 __eng_hmin=1000 __eng_hmax=1999 ;;  # read 1000-1999 as nineteen hundred and ninety nine
            -s?*)               set X -s "${1#-?}"  "${@:2}" ;;
            --scale=*)          set X -s "${1#-*=}" "${@:2}" ;;
            -s|--scale)
                                case $2 in
                                    s|short)    __eng_scale=0 ;;    # 1001001000000 = "one trillion one billion one million"
                                    l|long)     __eng_scale=-1 ;;   # 1001001000000 = "one billion one thousand [and] one million"
                                    m|milliard) __eng_scale=2 ;;    # 1001001000000 = "one billion one milliard one million"
                                    t|thillion) __eng_scale=3 ;;    # 1001001000000 = "one billion one thousand million one million" aka "HHGTTG mode"
                                    [0-9]*)     (( __eng_scale=$2, __eng_scale>3 && (__eng_scale=0) )) ;;
                                    *)          printf >&2 'english_number: invalid scale option "%s"\n' "$2" ; return 64 ;;
                                esac
                                shift
                                ;;
            -o|--ordinal)       __eng_ordinal=1 ;;
            -v|--var)           __eng_output_var=$2 ; shift ; eval "$__eng_output_var=()" ;;
            --var=*)            __eng_output_var=${1#*=}    ; eval "$__eng_output_var=()" ;;
            -x|--debug)         __eng_debug=1 ;;
            -[!0-9]*)           printf >&2 'english_number: invalid option "%s"\n' "$1" ; return 64 ;;
            *)                  break ;;
        esac
        shift
    done

    local -a __eng_digits=( zero one two three four five six seven eight nine
                            ten eleven twelve thirteen fourteen fifteen sixteen
                            seventeen eighteen nineteen twenty
                            [30]=thirty [40]=forty [50]=fifty [60]=sixty
                            [70]=seventy [80]=eighty [90]=ninety
                            # Exceptions to "base+TH" & "base+TIETH"
                            [101]=first second third    # completely oddball
                            [105]=fifth [112]=twelfth   # de-voiced "v"
                            [108]=eighth ninth          # adapt spelling
                          )

    # Prefixes to -illion, based on a little-endian reading of numbers in Latinish
    #
    # In certain combinations of grammatical and phonetic context, Latin
    # pronunciation reduces voiced consonants to unvoiced: g→k→c, d→t, b→p.
    # Similarly "m" and "n" followed by a stop consonant are blended with that
    # consonant, giving "nk", "mp", "nq", "nt", & "mv" (English orthography
    # prefers "nv" but the pronunciation isn't distinguishable.)
    #
    # (1) remove trailing vowel /[ai]/ when adding "illi" or "illion"
    # (2) "centi" becomes "genti" when prefixed by
    #
    # NB: 10^100 (a googol) is ten duotrevintillion
    local -ga __eng_rank=(
                          [1]=m b tr quadr quint sext sept oct non dec
                          [20]=vigint [30]=trigint [40]=quadragint
                          [50]=quinquagint [60]=sexagint [70]=septuagint
                          [80]=octogint [90]=nonagint [100]=cent
                        )
    local -ga __ent_latin=(
                           [1]=un duo tre quattuor quin sex septen octo novem
                           [10]=deci [20]=viginti [30]=triginta
                           [40]=quadraginta [50]=quinquaginta [60]=sexaginta
                           [70]=septuaginta [80]=octoginta [90]=nonaginta
                           [100]=centi [200]=ducenti [300]=trecenti
                           [400]=quadringenti [500]=quingenti [600]=sescenti
                           [700]=septingenti [800]=octingenti [900]=nongenti
                         )
    # Inserted sibilants: "se" gets "x" added before "c" or "o"; otherwise
    # "tre" & "se" get "s" added before "c", "v", "t", "q", & "o".
    # (Adding "x" before "centi" is because English pronounces "c" as /s/ rather
    # than /k/; this rule would not apply were it pronounced /k/ as in Latin.
    # The "m"+"v" pairing disagrees with English orthography but does not
    # affect pronunciation.)
    local -ga __eng_sibilant=(
                              # tres, ses
                              [20]=s [30]=s [40]=s [50]=s [300]=s [400]=s [500]=s
                              # tres, sex
                              [80]=x [100]=x [800]=X
                            )
    # Inserted nasals: "septe" and "nove" get "m" added before "v" or "o";
    # otherwise they get "n" added unless except before "n" (novem).
    local -ga __eng_nasal=(
                           # novem
                           [20]=m [80]=m [800]=m
                           # noven
                           [10]=n [30]=n [40]=n [50]=n [60]=n [70]=n [100]=n
                           [200]=n [300]=n [400]=n [500]=n [600]=n [700]=n
                         )

    local -a __eng_output
    local __eng_num __eng_th __eng_n3 __eng_px __eng_h __eng_t __eng_u __eng_low
    local __eng_r __eng_x

    __eng_x=0
    for __eng_num do
        (( __eng_debug )) && echo "DEBUG: START num=$__eng_num scale=$((__eng_scale)) and=$((__eng_conjunction))"

        __eng_output=()
        #(( __eng_debug )) && __eng_output+=( "from:$__eng_num" )

        (( __eng_th = __eng_ordinal ))

        __eng_output+=( "${__eng_prefix[@]}" )

        if [[ __eng_num = -* ]]
        then
            __eng_output+=( minus )
            __eng_num=${__eng_num#-}
            (( __eng_debug )) && echo "DEBUG: de-neg num=$__eng_num"
        fi
        __eng_num=${__eng_num#"${__eng_num%%[!0]*}"}
        (( __eng_debug )) && echo "DEBUG: trimmed num=$__eng_num"

        if [[ -z $__eng_num ]]
        then
            (( __eng_debug )) && echo "DEBUG: zero num=$__eng_num"
            if (( __eng_th ))
            then __eng_output+=( zeroth ) __eng_th=
            else __eng_output+=( zero )
            fi
        else
            (( __eng_debug )) && echo "DEBUG: nonzero num=$__eng_num"
            (( __eng_n3=(${#__eng_num}+2)/3 ))      # Number of 'thousands' groups

            # Maybe read some of 1000 to 1999 as "XX hundred"?
            if (( __eng_n3 == 2 && __eng_num >= __eng_hmin && __eng_num <= __eng_hmax )) ; then
                __eng_T=( $(( 10#0$__eng_num})) )
            else
                __eng_T=()
                for (( __eng_u = ${#__eng_num} ; ( __eng_u -= 3 ) >= 0 ;)) do
                    __eng_T+=( $((  10#0${__eng_num:__eng_u:3} )) )
                done
                __eng_T+=( $(( 10#0${__eng_num:0:__eng_u+3} )) )
            fi
            (( __eng_debug )) && echo "DEBUG: grouping=( ${__eng_T[*]} )"

            # Find lowest non-zero group
            for (( __eng_r = 0, __eng_low = -1 ; __eng_r < __eng_n3 ; ++__eng_r )) do
                (( __eng_T[__eng_r] )) && {
                    (( __eng_low = __eng_r ))
                    break
                }
            done

            # Tweak the lower limit so that we can print "one thousand millionth" in long scale
            (( __eng_low > 2 && __eng_low % 2 && __eng_scale < 0 && --__eng_low ))

            for (( __eng_r = __eng_n3 ; --__eng_r >= __eng_low ;)) do
                (( __eng_x = __eng_T[__eng_r],
                   __eng_px = __eng_T[__eng_r+1] ))

                (( __eng_debug )) && echo "DEBUG GROUP $__eng_r: x=$__eng_x (x′=$__eng_px)"

                (( __eng_x || __eng_scale < 0 && __eng_px && __eng_r % 2 == 0 && __eng_r > 0 )) || {
                    # Skip the current group when it's zero, unless we're in general long-scale mode and still need to print the
                    # -illion name for the preceeding group (which was left dangling at "thousand").
                    (( __eng_debug )) && echo "DEBUG GROUP $__eng_r: SKIP because ¬ ( x=$__eng_x≠0 ∨ ( scale=$((__eng_scale))=-1 ∧ x′=$((__eng_px))≠0 ∧ r%2=$((__eng_r))%2=$((__eng_r % 2))=0 ) )"
                    continue
                }

                # Split group into hundreds, tens, & units (as __eng_h,
                # __eng_t, & __eng_u)
                # __eng_x is residue (mod 100) of this group
                (( __eng_h = __eng_x/100,
                   __eng_t = __eng_x%100/10,
                   __eng_u = __eng_x%10 ))
                (( __eng_debug )) && echo "DEBUG GROUP $__eng_r: HTU x=$__eng_x → $__eng_h | $__eng_t | $__eng_u"

                (( __eng_debug2 = ${#__eng_output[@]} ))

                # remainder after hundreds within this group
                if (( __eng_x%100 == 0 ))
                then
                    if (( __eng_h ))
                    then
                        __eng_output+=( "${__eng_digits[__eng_h]}" )
                        if (( __eng_th && !__eng_r ))
                        then __eng_output+=( hundredth ) __eng_th=
                        else __eng_output+=( hundred )
                        fi
                    fi
                else
                    if (( __eng_h ))
                    then
                        __eng_output+=( "${__eng_digits[__eng_h]}" hundred )
                        # Include 'and' if there's a mod100 residue in this group,
                        # and either
                        #  (a) there are hundreds in this group, or
                        #  (b) this is the last of several groups, or
                        #  (c) this is the lower half of a long-scale group;
                        # and their respective options are enabled.
                        if (( __eng_conjunction & 16 || __eng_conjunction & 8 && __eng_r == 0 ))
                        then __eng_output+=( and )
                        fi
                    else
                        # Include 'and' if there's a mod100 residue in this group,
                        # and either
                        #  (a) there are hundreds in this group, or
                        #  (b) this is the last of several groups, or
                        #  (c) this is the lower half of a long-scale group;
                        # and their respective options are enabled.
                        if (( __eng_conjunction &&
                            ( __eng_conjunction & 2 && __eng_n3 > 1 && __eng_r == 0
                           || __eng_conjunction & 2 && __eng_n3 > 1 && __eng_r == 0
                           || __eng_conjunction & 4 && __eng_px     && __eng_r % 2 == 0 && __eng_scale < 0 )))
                        then __eng_output+=( and )
                        fi
                    fi
                    #
                    if (( __eng_t>=2 ))
                    then
                        if (( __eng_th && !__eng_u && !__eng_r ))
                        then __eng_output+=( "${__eng_digits[10*__eng_t+100]:=${__eng_digits[10*__eng_t]/ty/tie}th}" ) __eng_th=
                        else __eng_output+=( "${__eng_digits[10*__eng_t]}" )
                            # (French style) include 'and' between tens and
                            # units when both are non-zero (and not 'eleven')
                            if (( __eng_u == 1 && __eng_conjunction & 1 ))
                            then __eng_output+=( and )
                            fi
                        fi
                    else
                        (( __eng_u = __eng_x%100 ))
                    fi
                    if (( __eng_u ))
                    then
                        if (( __eng_th && !__eng_r ))
                        then
                            __eng_output+=( "${__eng_digits[__eng_u+100]:=${__eng_digits[__eng_u]?(missing digit for $__eng_u)}th}" ) __eng_th=
                        else
                            __eng_output+=(                              "${__eng_digits[__eng_u]?(missing digit for $__eng_u)}" )
                        fi
                    fi
                fi

                # __eng_r is log₁₀₀₀
                if (( __eng_r > 0 ))
                then
                    (( __eng_h = __eng_r ))
                    if (( __eng_r == 1 || __eng_scale < 0 && __eng_r % 2 == 1 ))
                    then
                        # Standard long scale:
                        # 1100000000 = one thousand one hundred million
                        __eng_output+=( thousand )
                    else
                        if (( __eng_scale ))
                        then
                            (( __eng_h /= 2 ))
                            # __eng_h is log₁₀₀₀₀₀₀
                        else
                            (( --__eng_h ))
                            # __eng_h is log₁₀₀₀-1
                        fi
                        # Now output __eng_h as a Latin-ish number, followed by
                        # "illion", all squished into one word

                        __eng_t=${__eng_rank[__eng_h]}
                        if [[ -z $__eng_t ]]
                        then
                            if [[ -v __eng_rank[__eng_h/10*10] ]]
                            then
                                __eng_t=${__ent_latin[__eng_h%10]}${__eng_rank[__eng_h/10*10]?(missing rank $((__eng_h/10*10)))}
                            else
                                __eng_t=$__eng_h-    # 123-illion
                            fi
                            __eng_rank[__eng_h]=$__eng_t    # remember for next time
                        fi
                        if (( __eng_scale > 0 && __eng_r % 2 == 1 ))
                        then
                            # The "thillion" (or "HHGTTG") and "milliard" scales have
                            # identical semantics, just with different terms.
                            if (( __eng_scale & 2 ))
                            then
                                # thillion scale: 1100000000 = one thousand million one hundred million
                                # (This feels bogus to me; the only place I've read it was in Life, the Universe and Everything,
                                # from the Hitchhikers' Guide to the Galaxy, but I'm including it for completeness).
                                __eng_output+=( thousand )
                                __eng_t+=illion
                            else
                                # Milliard long scale: 1100000000 = one milliard one hundred million
                                __eng_t+=illiard
                            fi
                        else
                            __eng_t+=illion
                        fi
                        if (( __eng_th && __eng_r == __eng_low ))
                        then __eng_t+=th __eng_th=
                        fi
                        __eng_output+=( "$__eng_t" )
                        (( __eng_debug )) && echo "DEBUG GROUP $__eng_r: rank term=$__eng_t"
                    fi
                fi
                (( __eng_debug )) && echo "DEBUG GROUP $__eng_r: DONE added output=(... ${__eng_output[*]:__eng_debug2})"
            done
        fi

        __eng_output+=( "${__eng_suffix[@]}" )

        (( __eng_debug )) && echo "DEBUG: DONE input=$__eng_num output=( ${__eng_output[*]} )"

        if [[ $__eng_output_var ]]
        then
            printf -v "$__eng_output_var[__eng_output_index++]" \
                    '%s'   "${__eng_output[*]}"
        else
            printf  '%s\n' "${__eng_output[*]}"
        fi
    done
    #eval "$__eng_shopt_save"
}
eval "$__eng_shopt_save" ; unset __eng_shopt_save

_provides english_number
