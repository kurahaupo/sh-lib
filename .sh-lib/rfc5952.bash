
# Terms:
#   N-abbrev: a :: representing N consecutive 0-segments
#   N-candidate: N consecutive 0-segments
#
#   "followed by" does not imply "adjacent"
# 1. rule out:
#    * matching *[!:0-9a-f]* (forbid invalid characters)
#    * matching *:*:*:*:*:*:*:*:*:* (9 colons, too many segments)
#    * matching *:::* (invalid abbreviation)
#    * matching *::*::* (too many abbreviations)
#    * matching *[!:0][!:][!:][!:][!:]* (segment too long)
#    prefer to avoid:
#    * matching 0[!:]* or *:0[!:]* (leading 0 in a non-0-segment)
#    * abbreviation adjacent to 0-segment (abbreviation must be maximal)
#
# 2. a written address with 9 apparent segments (8 colons) is theoretically
#    valid if it starts or ends with "::" representing a single candidate.
#    However there's no practical advantage to allowing this form, since it
#    is no shorter than the "0:" or ":0" that it replaces.
#
#    It should not have any longer candidates, so rule out:
#    * matching ?*::?* (must not contain :: other than at start or end)
#    * matching *:0:0:* (must not contain any 2-candidate)
#    * matching [!:]*[!:] (must not both starting and ending with a digit)
#
# 3. if it has 8 apparent segments, then (other than starting or ending with ::) it
#    must not contain an abbreviation, and must not contain any 2-candidate, so
#    rule out:
#    * matching *:0:0:*
#    * matching ?*::?*
#
#         and either
#         it starts with :: and does not contain :0:0:0: , or
#         it contains neither :: nor :0:0:
#
#   meaning it must have either
#       a leading or trailing abbreviation (2 consecutive empty segments), or
#       8 actual segments (no empty segments);
#    and by the first-abbreviation rule:
#       If it has a leading abbreviation then it may also contain 2, but not 3, consecutive 0-segments
#       If does not have a leading abbreviation, then it must not contain 2 consecutive 0-segments
#
#       ::0:*   forbidden but already ruled out
#       :0:*    forbidden but already ruled out
#       ?*::*?  forbidden (implies too many segments)
#       ::*:0:0:*   allowed
#       ::*:0:0:0:*   forbidden
#       ::*:0:0:0:*   forbidden
#
# 4. otherwise (if it has 7 or fewer apparent segments) it must contain an abbreviation
#
#
# 4. the abbreviation must be maximal, therefore
#       7 apparent segments
#           → in middle position: abbreviation of 2 segments + 5 valid
#               segments; 2-candidate must not precede abbrevation, and
#               3-candidate must not be present
#           → at start or end: abbreviation of 3 segments + 4 valid segments;
#               3-candidate must not precede abbrevation, and 4-candidate must
#               not be present
#       6 apparent segments
#           → in middle position: abbreviation of 3 segments + 4 valid
#               segments; 2-candidate must not precede abbrevation, and
#               3-candidate must not be present
#           → at start or end: abbreviation of 4 segments + 3 valid segments;
#               3-candidate must not precede abbrevation, and 4-candidate must
#               not be present
#

#
#   n means a non-zero segment
#   x means any non-empty segment (may be 0-segment, subject to other checking)
#   ++ means "followed by but not necessarily consecutively"
#
# ord colon IF :$1: MATCHES   non-abr abbrlen max-0-run     ≤   FORBID IF:
#   1   -   *[!:[:xdigit:]]*    -                               always - bad char
#   2   8+  ?*:*:*:*:*:*:*:*:*? -       -       -               always - too many colons
#   3   -   *[!:][!:][!:][!:][!:]*  -   -       -               always - too many digits in a segment
#   3   -   *:0[!:]*            -       -       -               always - segment starts with 0 when not just 0
#   4   -   ?*:::*?             -       -       -               always - invalid abbrev
#   4   -   ?*::*::*?           -       -       -               always - too many abbrev
#   5   -   *:0::*              -       -       -               always - 0-segment adjacent to abbrev
#   5   -   *::0:*              -       -       -               always - 0-segment adjacent to abbrev
#   6   5+  *:0:0:0:0:*         4+      0-3*    4+          <   always - 4-candidate always beats other abbreviations
#
#  10   7   ?::*:*:*:*:*:*?     6       2       3⁺          <   3-candidate     *:0:0:0:*
#  11   7   ?*:*:*:*:*:*::?     6       2       3⁺          <   2-candidate     *:0:0:*
#  12   7   ?*:*:*:*:*:*:*:*?   8       (none)  -           .   2-candidate; OR abbreviation in middle ??*::*??
#
#  19   2+  ?!(*::*)?           -       2+      -           .   always (failed requirement: must have :: if fewer than 7 colons)
#
#  21   6   ?::*:*:*:*:*?       5       3       3⁺          =   succeed! (4-candidate excluded by #6)
#  22   6   ?*:*:*:*:*::?       5       3       3⁺          =   4-candidate (excluded by #6); OR 3-candidate ++ 3-abbrev (trailing) *:0:0:0:*::?
#
#  23   6   ?*:*:*:*:*:*:*?     6       2       3⁺          <   3-candidate; OR 2-candidate ++ 2-abbrev
#  23×1 6   ?n::n:0:0:0:x?      6       2       3⁺          <   2-abbrev ++ 3-candidate
#  23×2 6   ?n::n:x:0:0:0?      6       2       3⁺          <   2-abbrev ++ 3-candidate
#  23×3 6   ?x:n::n:0:0:0?      6       2       3           <   2-abbrev ++ 3-candidate
#  23×4 6   ?0:0:n::n:x:x?      6       2       2           =   2-candidate ++ 2-abbrev
#  23×5 6   ?0:0:x:n::n:x?      6       2       3           <   2-candidate ++ 2-abbrev
#  23×6 6   ?x:0:0:n::n:x?      6       2       3           <   2-candidate ++ 2-abbrev
#  23×7 6   ?0:0:x:x:n::n?      6       2       3⁺          <   2-candidate ++ 2-abbrev
#  23×8 6   ?x:0:0:x:n::n?      6       2       3⁺          <   2-candidate ++ 2-abbrev
#  23×9 6   ?x:x:0:0:n::n?      6       2       3⁺          <   2-candidate ++ 2-abbrev
#  23×a 6   ?0:0:0:n::n:x?      6       2       3           <   3-candidate (already excluded by #23×5 & #23×6)
#  23×b 6   ?0:0:0:x:n::n?      6       2       3⁺          <   3-candidate (already excluded by #23×7 & #23×8)
#  23×c 6   ?x:0:0:0:n::n?      6       2       3⁺          <   3-candidate (already excluded by #23×8 & #23×9)
#  23×d 6   ?0:0:0:0:n::n?      6       2       3⁺          <   3-candidate (already excluded by #6, or by #23×b & #23×c)
#
#  28   5   ?::*:*:*:*?         4       4       3           .   succeed! (not enough segments left to compete)
#  29   5   ?*:*:*:*::?         4       4       3           .   4-candidate ++ 4-abbrev (impossible)
#
#  30   5   ?0:0:0:*::*?        5       3       3           =   3-candidate ++ 3-abbrev
#
#
#  32   5   ?n::n:x:x:x?        5       3       3           =   3-candidate ++ 3-abbrev (impossible)
#  32   5   ?x:n::n:x:x?        5       3       2           .   3-candidate ++ 3-abbrev (impossible)
#  32   5   ?x:x:n::n:x?        5       3       2           .   3-candidate ++ 3-abbrev (impossible)
#
#  40×0     From here down, the abbreviation has taken half (so longer
#  40×1     candidate is already excluded but the maximality rule) or more than
#  40×2     half (so a longer candidate is impossible). Therefore we conclude
#  40×3     that anything with fewer than 5 colons must be valid (as long as it
#  40×4     has ::, checked earlier)
#
#  41   4   ?::n:x:x?           3       5       2           .
#  42   4   ?n::n:x:x?          4       4       2           .
#  42   4   ?x:n::n:x?          4       4       1           .
#  42   4   ?x:x:n::n?          4       4       2           .
#  43   4   ?x:x:n::?           3       5       2           .
#
#  50   3   ?::n:x?             2       6       1           .
#  51   3   ?n::n:x?            3       5       1           .
#  51   3   ?x:n::n?            3       5       1           .
#  52   3   ?x:n::?             2       6       1           .
#
#  60   2   ?::n?               1       7       -           .
#  61   2   ?n::n?              2       6       -           .
#  62   2   ?n::?               1       7       -           .
#
#  70   2   ?::?                0       8       -           .

trap "$( shopt -p extglob ) ; trap - RETURN ; $( trap -p RETURN )" RETURN
shopt -s extglob

rfc4291() {
    case :$1: in
        #1-6 - assertions
        *@([!:[:xdigit:]]|?*:*:*:*:*:*:*:*:*?|[!:][!:][!:][!:][!:]|:0[!:]|?:::?|?::*::?|::0:|:0::|:0:0:0:0:)*) false ;;
        ?*:*:*:*:*:*:*:*?|?*::*?) ;;
        *) false ;;
    esac
}
_provides rfc4291

rfc5952() {
    case :$1: in
        #1-6 - assertions
        *@([!:[:xdigit:]]|?*:*:*:*:*:*:*:*:*?|[!:][!:][!:][!:][!:]|:0[!:]|?:::?|?::*::?|::0:|:0::|:0:0:0:0:)*) false ;;

        #10 - 7 colons, 6 segments, 2-abbrev (leading)
        ?::*:*:*:*:*:*?)    [[ :$1: != *:0:0:0:* ]] ;;  # 2-abbrev ++ 2-candidate is allowed, 3-candidate is not

        #11 - 7 colons, 6 segments, 2-abbrev (trailing)
      # ?*:*:*:*:*:*::?)    [[ :$1: != *:0:0:* ]] ;;    # 2-candidate ++ 2-abbrev is not allowed

        #12 - 7 colons, 8 segments, no abbrev
        ?*:*:*:*:*:*:*:*?)  [[ :$1: != *@(??::??|:0:0:)* ]] ;;  # no room for middle-abbrev; 2-candidate (with or without following abbrev) not allowed

        #19 - assertion (relies on already having checked #7)
        !(?*::*?))          false ;; # If you don't have 7 colons then you must have an abbreviation (match directly)

        #21 - 6 colons, 5 segments, 3-abbrev (leading)
        ?::*:*:*:*:*?)      true ;;  # 6 colons with leading 3-abbrev can't be beaten (4-candidate already covered)

        #22 - 6 colons, 5 segments, 3-abbrev (trailing)
      # ?*:*:*:*:*::?)      [[ :$1: != *:0:0:0:* ]] ;;

        #23 - 6 colons, 6 segments, 2-abbrev
        ?*:*:*:*:*:*:*?)    [[ :$1: != *:0:0:@(0:|*::??)* ]] ;;

        #30 - 5 colons, 5 segments, 3-abbrev (only failing 5-colon case, so match explicitly)
        # Note the trailing '??' to avoid matching case #29
        ?0:0:0:*::*??)      false ;;

        # other 5-colon cases, and all cases with fewer colons, must succeed
        #28, #29 - 5 colons, 4 segments, 4-abbrev [won't match previous pattern because it ends with ??]
    esac
}
_provides rfc5952

((__rfc5952_regression_test)) || return 0

declare -ir good=1 poor=2 fail=3
declare -a ew=( [good]=good [poor]=poor [fail]=fail )

trytest() {
    local expect=$1 address=$2
    # expect is one of good poor or fail

    local fail_this=0

    rfc4291 "$lt" ; (( got_4291 = $?==0 ))
    rfc5952 "$lt" ; (( got_5952 = $?==0 ))

    (( fail5952 = ( got_5952 != ( expect == good ) ),
       fail4291 = ( got_4291 != ( expect != fail ) ),
       fail_this = fail5952|fail4291 )) || return 0

    printf 'Tested %s expecting %s\n' "$address" "${ew[expect]^^}"

    if (( !got_4291 && got_5952 ))
    then
        printf '\tgot conflicting results: 4291 FAIL but 5952 GOOD\n'
    else
        if ((expect == good))
        then
            if ((!got_4291))
            then printf '\tgot FAIL on rfc4291 and BAD on rfc5952\n'
            elif ((!got_5952))
            then printf '\tgot BAD on rfc5952\n'
            fi
        elif ((expect == fail))
            if ((got_5952))
            then printf '\tgot OK on rfc4291 and GOOD rfc5952\n'
            elif ((got_4291))
            then printf '\tgot OK on rfc4291\n'
            fi
        then
        else
            if ((got_5952))
            then printf '\tgot GOOD on rfc5952\n'
            fi
            if ((!got_4291))
            then printf '\tgot FAIL on rfc4291\n'
            fi
        fi
    fi

    then
        got_4291=1
        if (( expect == fail )) ; then
            fail_this=1
            printf '\texpected rfc4291 FAIL got PASS\n'
        fi
    else
        got_4291=0
        if (( expect != fail )) ; then
            fail_this=1
            printf '\texpected rfc4291 PASS got FAIL\n'
        fi
    fi



    then
        got_5952=1
        if (( expect != good )) ; then
            fail_this=1
            if ((!got_4291)) ; then
                printf '\texpected (and got) rfc4291 FAIL\n\tbut then got rfc 5952 PASS - this should not happen\n'
            else
                printf '\texpected rfc5952 FAIL got PASS\n'
            fi
        else
            if ((!got_4291)) ; then
                printf '\tbut then expected (and got) rfc5952 PASS - this should not happen\n'
            fi
        fi
    else
        got_5952=0
        if (( expect == good )) ; then
            fail_this=1
            printf '\texpected rfc5952 PASS got FAIL\n'
        fi
    fi

    (( fail_this && ++errors ))
}

expect=-1
while
    IFS=' ' read -r line
do
    case $line in
    ''|'#'*) continue ;;
    esac

    lt=
    lx=expect

    for word in $line
    do
        case $word in
        *:*)    lt=$word ;;
        *)      lx=${word,,} ;;
        esac
    done

    if [[ $lt ]]
    then

        if rfc4291 "$lt"
        then ((got_4291=ok))
        else ((got_4291=bad))
        fi

        if rfc5952 "$lt"
        then ((got_5952=ok))
        else ((got_5952=bad))
        fi

        case $lx:$got_5952:$got_4291 in
        good:$good:$good) ;;
        poor:$fail:$good) ;;
        fail:$fail:$fail) ;;
        *:$good:$fail)
            printf 'Tested %s\n' "$lt"
            printf '\tCANNOT HAPPEN: got fail on rfc4291 and pass on rfc5952\n'
            ;;
        *)
            printf 'Tested %s\n' "$lt"
            printf '\texpected rfc4291 %s got %s\n' $((lx != fail)) $((got_4291))
            printf '\texpected rfc5952 %s got %s\n' $((lx == good)) $((got_5952))
            ((++errors))
        esac

    else
        # Expect on its own
        ((expect=lx))
    fi
done <<EndOfTests

# Basics

FAIL
:
:::
1::1::1
1:1:1:1:1:1:1:1:1

GOOD
::
::1
1::1
1::1:0
1::1:0:0:0

# passes rfc4291 but fails rfc5952
POOR
1:0::1
1::0:1

EndOfTests

(( errors == 0 ))
