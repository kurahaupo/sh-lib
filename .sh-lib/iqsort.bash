
#
# iqsort takes 5 parameters: A U C R L
#   - A is the name of the array to be sorted
#   - U is the name of the array holding the list of parts of A that yet to be sorted
#   - C is a comparison function
#   - R is an open upper bound
#   - L is a closed lower bound
#
# C should name a function that returns:
#   0 when $1 < $2 (correctly sorted if $1 is earlier than $2 in the array)
#   1 when $1 ≥ $2
#   2 when $1 = $2
#   3 when $1 > $2
#   4 when $1 and $2 are not comparable
# A simple comparison that only returns 0 or 1 is sufficient, such as
#   compare_string() {
#       [[ $1 < $2 ]]
#   }
# however it's beneficial to distinguish the = and > results if that
# information is already available, such as:
#   compare_decimal() {
#       (( 10#${1%.*} < 10#${2%.*} )) && return 0
#       (( 10#${1%.*} > 10#${2%.*} )) && return 3
#       [[ $1 < $2 ]]
#   }
#
# If either L or R is blank or unset, they will be taken as the lower and upper
# boundaries of the whole array respectively.
# Ranges are always half-open; that is [L..R) or [L..R-1].
#
# U must be initially set empty by the caller.
# It always has an odd number of elements, being a sentinel (to indicate that
# it has been initialized) followed by a list of pairs of indeces representing
# semi-open sub-ranges of A. This representation means it can also be viewed
# as a list of sort sub-ranges, simply by looking at pairs on even rather than
# odd indeces into U.
#
# If the whole of A is sorted, U will contain only the sentinel.
#
# iqsort returns once A[L..R-1] contains the correct elements in the correct
# order; the rest of A may still be in arbitrary order, as indicated by the
# contents of U.
#

if (( IQSORT_DEBUG ))
then ___iq_v=1 ;___iq_debug() { printf '%(%F,%T)T [%u] %s\n' -1 $$ "$*" ; }
else ___iq_v=0 ;___iq_debug() { :; }
fi

___iq_swap() {
    ___iq_debug "SWAP was A[${1##*_}=$(($1))]=${___iq__A[$1]-UNBOUND} A[${2##*_}=$(($2))]=${___iq__A[$2]-UNBOUND}"
    local ___iq__t
    ___iq__t=${___iq__A[$1]} ___iq__A[$1]=${___iq__A[$2]} ___iq__A[$2]=$___iq__t
    ___iq_debug " becomes A[${1##*_}=$(($1))]=${___iq__A[$1]-UNBOUND} A[${2##*_}=$(($2))]=${___iq__A[$2]-UNBOUND}"
}

___iq_cmp_result_description=( '<' '≥' '=' '>' )
___iq_cmp() {
    declare -gi ___iq_cmp_A=$1
    declare -gi ___iq_cmp_B=$2
    ___iq_debug "$___iq__C" "A[${1##*_}=$(($1))]=${___iq__A[$1]-UNBOUND}" "A[${2##*_}=$(($2))]=${___iq__A[$2]-UNBOUND}"
    "$___iq__C" "${___iq__A[$1]}" "${___iq__A[$2]}"
    declare -gi ___iq_cmp_R=$?
    ___iq_debug "RESULT=${___iq_cmp_result_description[___iq_cmp_R]-X($___iq_cmp_R)}"
    return $___iq_cmp_R
}

# Reverse comparison test;
#
# MUST ONLY be used in an "elif" clause immediately after ___iq_cmp.

___iq_rcmp() {
    #local ___iq_cmp_R=$?

    # DEBUG: make sure that we're testing the same values, or that none are
    # provided. If not, re-do "other" test.
    (( $# == 0 )) ||
    (( $1 == ___iq_cmp_A &&
       $2 == ___iq_cmp_B )) || {
        cluck "rcmp has different parameters ($1,$2) from preceding cmp ($___iq_cmp_A,$___iq_cmp_B)"
        ___iq_cmp_R=1
        ___iq_cmp "$1" "$2"
    }

    # Recall $? from previous ___iq_cmp, where:
    #   0 meant '<', so return 3 (false)
    #   1 meant '≥', so re-test with the parameters swapped
    #   2 meant '=', so return 2 (false)
    #   3 meant '>', so return 0 (true)
    #   4 meant un-orderable, so return 4 (false)
    #   any other status is returned as-is without re-testing.
    #
    # So 1 causes a re-test; 0 & 3 are inversely paired; and everything else is
    # returned unchanged.

    (( ___iq_cmp_R != 1 )) && return $(( ___iq_cmp_R == 0 ? 3 :
                                         ___iq_cmp_R == 3 ? 0 :
                                         ___iq_cmp_R ))
    ___iq_cmp "$___iq_cmp_B" "$___iq_cmp_A"
}

# Equality test;
#
# MUST ONLY be used in an "elif" clause immediately after ___iq_cmp.
#
# The invoking code may assume:
#   A≮B & A≠B ⇐⇒ A>B
#
#   A≠B & A≯B ⇐⇒ A<B
#   A≮B & A≯B ⇐⇒ A=B

___iq_eq() {
    #local ___iq_cmp_R=$?

    # DEBUG: make sure that we're testing the same values, or that none are provided
    (( $# == 0 )) ||
    (( $1 == ___iq_cmp_A &&
       $2 == ___iq_cmp_B )) || {
        cluck "eq has different parameters ($1,$2) from preceding cmp ($___iq_cmp_A,$___iq_cmp_B)"
        ___iq_cmp "$1" "$2"
    }

    # Recall $? from previous ___iq_cmp, where:
    #   0 meant '<', so return 1 (false)
    #   1 meant '≥', so re-test with the parameters swapped
    #   2 meant '=', so return 0 (true)
    #   3 meant '>', so return 1 (false)
    #
    # Any other status is returned as 0 (true) so that the result is consistent
    # with !cmp && !rcmp, even though it's less informative.

    (( ___iq_cmp_R != 1 )) && return $(( ___iq_cmp_R == 0 || ___iq_cmp_R == 3 ))
    ! ___iq_cmp "$___iq_cmp_B" "$___iq_cmp_A"
}

___iq_find_pivot() { : "
    ####  This function is private to, and should only be called by, iqsort.    ####
    ####  It uses and depends on the local variables of invoking iqsort.        ####"

    ___iq_debug "finding pivot in l=$___iq__l ... r=$___iq__r"
    ___iq_debug "A[l=$___iq__l ... r=$___iq__r] = ${___iq__A[@]:___iq__l:___iq__r-___iq__l}"

    (( ___iq__p=___iq__r-1 ))

    # Estimate the median from 4 samples

    if (( ___iq__r-___iq__l >= 8 ))
    then
        local -i ___iq__i ___iq__j=___iq__r-___iq__l

        # Take 4 "random" indeces within [l..r) and pick the one whose element
        # sorts second-latest, provided that there least 3 do not sort as "equal"
        local -ai ___iq__I=(
            ___iq__l
            ___iq__l+___iq__j/4
            ___iq__l+___iq__j/2
            ___iq__p
        )

        if

            # Sort so that I[3] ≤ I[2] ≤ I[1] ≤ I[0]
            # Since there are only 4 elements, use a bubble sort (instead of
            # the 60+ comparisons that would be necessary if this were
            # unrolled).
            for (( ___iq__i=${#___iq__I[@]} ; --___iq__i >= 1 ;)) do
                for (( ___iq__j=___iq__i ; --___iq__j >= 0 ;)) do
                    if ___iq_cmp ___iq__I[___iq__j] ___iq__I[___iq__i]
                    then
                        (( ___iq__t = ___iq__I[___iq__i],
                                      ___iq__I[___iq__i] = ___iq__I[___iq__j],
                                                           ___iq__I[___iq__j] = ___iq__t ))
                    fi
                done
            done
            (( ___iq__o=___iq__I[1] ))

            # Need 3 out of 4 sortable
            if ___iq_cmp ___iq__I[1] ___iq__I[0]
            then
                ___iq_cmp ___iq__I[2] ___iq__I[1] ||
                ___iq_cmp ___iq__I[3] ___iq__I[2]
            else
                (( ___iq__o = ___iq__I[2] ))
                ___iq_cmp ___iq__I[2] ___iq__I[1] &&
                ___iq_cmp ___iq__I[3] ___iq__I[2]
            fi

        then
            for ___iq__i in "${!___iq__I[@]}"; do (( ___iq__I[___iq__i] += 0 )) ; done
            ___iq_debug "chosen pivot $___iq__o from [${___iq__I[*]}]"
            for ___iq__i in "${!___iq__I[@]}"; do
                ___iq_debug "    A[I[$___iq__i]=${___iq__I[___iq__i]}]=${___iq__A[___iq__I[___iq__i]]} $( ((___iq__I[___iq__i] == ___iq__o)) && echo '***' )"
            done

            ___iq_swap ___iq__o ___iq__p
            return 0
        fi

        for ___iq__i in "${!___iq__I[@]}"; do (( ___iq__I[___iq__i] += 0 )) ; done
        ___iq_debug "NOT chosen pivot from [${___iq__I[*]}]"
        for ___iq__i in "${!___iq__I[@]}"; do
            ___iq_debug "    A[I[$___iq__i]=${___iq__I[___iq__i]}]=${___iq__A[___iq__I[___iq__i]]}"
        done

    fi

    # Didn't find
    # Since the pivot value will be in the
    # upper half of the split, start scanning for one at the upper boundary.

    for (( ___iq__k=___iq__p-1 ; ___iq__k>=___iq__l ; --___iq__k )) do
        ___iq_debug "scanning pivot k=$___iq__k p=$___iq__p"
        if ___iq_cmp ___iq__k ___iq__p
        then
            # range looks like this:
            #   ? ... A  B ... B
            #   ↑     ↑        ↑
            #   l     k        p,r
            # where A < B
            ((___iq__p=___iq__k+1))
            # now:
            #   ? ... A  B ... B
            #   ↑     ↑  ↑     ↑
            #   l     k  p     r
            #
            # p is a valid pivot
            ___iq_debug "found pivot↓ l=$___iq__l p=$___iq__p r=$___iq__r"
            return 0
        elif ___iq_rcmp ___iq__k ___iq__p
        then
            # range looks like this:
            #   ? ... B  A ... A
            #   ↑     ↑        ↑
            #   l     k        p,r
            # where A < B
            # reverse order; after swapping p can be a pivot
            ___iq_swap ___iq__k ___iq__p
            # now:
            #   ? ... A ... A  B
            #   ↑     ↑        ↑
            #   l     k        p,r
            #
            # p is a valid pivot
            ___iq_debug "found pivot↑ l=$___iq__l p=$___iq__p r=$___iq__r"
            return 0
        fi
        # any order, keep scanning
    done

    # If we get here, there's no pivot because all of the values in the
    # sub-range compare as "equal".
    ___iq_debug "no pivot found"
    return 1
}

iqsort() {
    local ___iq__C=$3 ___iq__L=${4:-} ___iq__R=${5:-}

    local -i ___iq__nameref=0
    # Try using nameref
    eval 2> /dev/null "
        local -n ___iq__A=\$1
        local -n ___iq__U=\$2
        ___iq__nameref=1
        true
    " || {
        # Nameref didn't work, so make copies instead
        local ___iq__aa="$1" ___iq__aa_="$1[@]"
        local -a ___iq__A=( "${!___iq__aa_}" )
        local ___iq__au="$2" ___iq__au_="$2[@]"
        local -a ___iq__U=( "${!___iq__au_}" )
    }

    local ___iq__na=${#A[@]}

    if ((!${#___iq__U[@]}))
    then
        # first time
        ___iq__U=( - 0 $((___iq__na)) )
    fi

    if [[ $___iq__L = ?(-) ]] ; then ___iq__L=0          ; fi
    if [[ $___iq__R = ?(-) ]] ; then ___iq__R=$___iq__na ; fi
    if (( ___iq__L < 0 )) ; then ___iq__L=0          ; fi ; if (( ___iq__L < 0 )) ; then (( ___iq__L += ___iq__na )) ; fi
    if (( ___iq__R < 0 )) ; then ___iq__R=$___iq__na ; fi ; if (( ___iq__R < 0 )) ; then (( ___iq__R += ___iq__na )) ; fi
    if (( ___iq__L < 0 )) ; then (( ___iq__L = 0 )) ; elif (( ___iq__L > ___iq__na )) ; then (( ___iq__L = ___iq__na )) ; fi
    if (( ___iq__R < 0 )) ; then (( ___iq__R = 0 )) ; elif (( ___iq__R > ___iq__na )) ; then (( ___iq__R = ___iq__na )) ; fi
    # As a last resort, swap
    if (( ___iq__L > ___iq__R )) ; then (( ___iq__t = ___iq__L, ___iq__L = ___iq__R, ___iq__R = ___iq__t )) ; fi

    local -i ___iq__l ___iq__r ___iq__o ___iq__p ___iq__q=1
    #local ___iq__t

    while
        # Firstly, set q to the first index pair in U that intersect with the
        # desired range [L...R)
        for ((;; ___iq__q+=2 )) do
            ___iq_debug "SCANNING for overlap [L=$___iq__L,R=$___iq__R] at q=$___iq__q/${#___iq__U[@]}"

            (( ___iq__q < ${#___iq__U[@]} )) || break 2                         # no more unsorted space
            (( ___iq__l=___iq__U[___iq__q], ___iq__r=___iq__U[___iq__q+1] ))    # l & r are endpoints of sub-range
            ___iq_debug "   check for overlap [L=$___iq__L,R=$___iq__R] vs [l=$___iq__l,r=$___iq__r]"
            (( ___iq__R > ___iq__l && ___iq__L < ___iq__r )) && break           # found one
        done
        #___iq_debug "FOUND OVERLAP: q=$___iq__q/${#___iq__U[@]} : l=$___iq__l r=$___iq__r"

        if   (( ___iq__r - ___iq__l < 2 ))
        then
            # Range is empty or contains a single element, which by definition must be sorted
           ___iq_debug "FOUND TRIVIAL OVERLAP: l=$___iq__l r=$___iq__r"
            true    # remove pair from U

        elif (( ___iq__r - ___iq__l == 2 ))
        then
            # Range contains just two elements. Compare & swap if necessary, and then we're done.

            ___iq_debug "FOUND SMALL OVERLAP: l=$___iq__l r=$___iq__r"

            if ___iq_cmp ___iq__r-1 ___iq__l
            then
                ___iq_swap ___iq__l ___iq__r-1
            fi
            true    # remove pair from U

        else
            # Range contains 3 or more elements, so split it into 2 sub-ranges

            ___iq_debug "FOUND LARGE OVERLAP: l=$___iq__l r=$___iq__r"

            # Firstly, find a pivot.
            if ___iq_find_pivot
            then
                # p is a valid pivot in [l+1..r), meaning there's at least one
                # value in A[l..p-1] that sorts earlier than A[p].

                # Now swap items either side of the pivot that are out of
                # order.  The pivot moves during this process, so that when
                # finished, it establishes a partition such that for any i in
                # [ l .. r-1 ]
                #   (( i < p ))
                # gives the same result as
                #   "$C" "${A[i]}" "${A[p]}"

                for ((___iq__o=___iq__l;___iq__o<___iq__p;)) do
                    while
                        ___iq_debug "step in from left  A[o=$___iq__o]=${___iq__A[___iq__o]} A[p=$___iq__p]=${___iq__A[___iq__p]}"
                        ((___iq__o<___iq__p)) || break 2
                        ! ___iq_cmp ___iq__p ___iq__o
                    do
                        ((++___iq__o))
                    done
                    ___iq_swap ___iq__o ___iq__p
                    while
                        ___iq_debug "step in from right A[o=$___iq__o]=${___iq__A[___iq__o]} A[p=$___iq__p]=${___iq__A[___iq__p]}"
                        ((___iq__o<___iq__p)) || break 2
                        ! ___iq_cmp ___iq__p ___iq__o
                    do
                        ((--___iq__p))
                    done
                    ___iq_swap ___iq__o ___iq__p
                done

                # (The pivot position is now both o == p)

                (( ++___iq__o ))
                # (o is now "one past the pivot", so that the pivot value
                # itself is excluded from any split)

                ___iq_debug "PARTITION: q=$___iq__q : l=$___iq__l p=$___iq__p o=$___iq__o r=$___iq__r"
            (( ___iq__l < ___iq__p )) &&
                ___iq_debug "     A[l=$___iq__l .. p=$___iq__p]=( ${___iq__A[*]:___iq__l:___iq__p-___iq__l} )"
                ___iq_debug "     A[p=$___iq__p]=${___iq__A[___iq__p]}"
            (( ___iq__o < ___iq__r )) &&
                ___iq_debug "     A[o=$___iq__o .. r=$___iq__r]=( ${___iq__A[*]:___iq__o:___iq__r-___iq__o} )"
                ___iq_debug " U was ${___iq__U[@]}"

                # Thirdly, either add the new split to U, or replace
                # the existing split.

                if (( ___iq__o < ___iq__r ))
                then
                    if (( ___iq__l < ___iq__p ))
                    then

                        # Insert new split into U
                        ___iq_debug ' SPLIT'
                        ___iq__U=( "${___iq__U[@]:0:___iq__q+1}" $((___iq__p)) $((___iq__o)) "${___iq__U[@]:___iq__q+1}" )
                        ___iq_debug " U now ${___iq__U[@]}"

                        continue

                    fi

                        # Everything in [l .. p] is equal, so just move current
                        # subrange left boundary
                        ___iq_debug ' SHIFT left boundary'
                        (( ___iq__U[___iq__q]=___iq__o ))
                        ___iq_debug " U now ${___iq__U[@]}"

                        continue

                elif (( ___iq__l < ___iq__p ))
                then

                        # Only managed to trim from tail, so just move current
                        # subrange right boundary
                        ___iq_debug ' SHIFT right boundary'
                        (( ___iq__U[___iq__q+1]=___iq__p ))
                        ___iq_debug " U now ${___iq__U[@]}"

                        continue

                fi

                # FALLTHRU: entire subrange is equal, so remove it
                # however this is the same condition that ___iq_find_pivot
                # returns, so this point should never be reached
            fi

            true    # remove pair from U
        fi

    do
        # sub-range has been dealt with; remove pair from U
        ___iq_debug "REMOVE range: U[q=$___iq__q]=${___iq__U[___iq__q]} U[q+1=$((___iq__q+1))]=${___iq__U[___iq__q+1]}"
        ___iq_debug " U was ${___iq__U[@]}"
        ___iq__U=( "${___iq__U[@]:0:___iq__q}" "${___iq__U[@]:___iq__q+2}" )
        ___iq_debug " U now ${___iq__U[@]}"
    done

    (( ___iq__nameref )) || eval "
        $___iq__aa=( \"\${___iq__A[@]}\" )
        $___iq__au=( \"\${___iq__U[@]}\" )
    "
}

_provides iqsort
