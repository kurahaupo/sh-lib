#
# Various sort algorithms applied to a Bash array variable
#
# Each sort function takes the name of the array to be sorted as its 1st
# parameter.
#
# The optional 2nd parameter is a "less than" comparitor (as a shell code
# fragment that will be "evaled"). If it is missing or empty the default
# comparison is "lexicographically precedes". This comparison be transitive.
#
# The list will be sorted so that the "less than" comparitor returns true for
# any two consecutive elements.
#
# The head-sort takes as its 3rd parameter the size of the head required; it
# uses heap-sort underneath.
#

################################################################################
# bubble-sort

bsort_array() {
    local -n ___array=$1
    local ___n=${#___array[@]} ___i ___j ___x
    eval "___lt() { ${2:-[[ \$1 < \$2 ]]}; }"
    for ((___i=0;___i<___n;___i++)) do
        for ((___j=___i+1;___j<___n;___j++)) do
            ___lt "${___array[___i]}" "${___array[___j]}" || {
                ___x="${___array[$___i]}"
                ___array[$___i]="${___array[$___j]}"
                ___array[$___j]="$___x"
            }
        done
    done
    unset -f ___lt
}

################################################################################
# recursive quick-sort
rqsort_array() {
    local -n ___array=$1
    local ___n=${#___array[@]} ___i ___j ___x
    eval "___lt() { ${2:-[[ \$1 < \$2 ]]}; }"
    ___part() {
        local ___l=$1 ___r=$2 ___p=$2
        ((___l==___r)) && return
        ___i=$___l ___j=$___r
        ___p=$___r
        if  ((___l+1<___p)) &&
            ___lt "${___array[___l+1]}" "${___array[___r]}"
        then
            ___p=$((___l+1))
        fi
        while
            while
                ((___i<___p)) &&
                ___lt "${___array[___i]}" "${___array[___p]}"
            do
                ((++___i))
            done
            while
                ((___j>___p)) &&
                ! ___lt "${___array[___j]}" "${___array[___p]}"
            do
                ((--___j))
            done
            ((___i<___j))
        do
            ___x="${___array[$___i]}"
            ___array[$___i]="${___array[$___j]}"
            ___array[$___j]="$___x"
            if ((___i==___p))
            then ___p=$___j
            elif ((___j==___p))
            then ___p=$___i
            fi
        done
        ___part $___l $((___p-1))
        ___part $((___p+1)) $___r
    }
    ___part 0 $___n
    unset -f ___lt ___part
}

################################################################################
# nonrecursive quick-sort
qsort_array() {
    local -n ___array=$1
    eval "___lt() { ${2:-[[ \$1 < \$2 ]]}; }"
    local ___n=${#___array[@]} ___i ___j ___l ___p ___r ___x
    local -a ___pp=( 0,$((___n-1)) )
    while ((${#___pp[@]}))
    do
        ___p=${___pp[-1]}
        unset ___pp[-1]
        ___l=${___p%,*}
        ___r=${___p#*,}
        ((___l < ___r)) || continue
        ___i=$___l ___j=$___r
        ___p=$___r
        if  ((___l+1<___p)) &&
            ___lt "${___array[___l+1]}" "${___array[___r]}"
        then
            ___p=$((___l+1))
        fi
        while
            while
                ((___i<___p)) &&
                ___lt "${___array[___i]}" "${___array[___p]}"
            do
                ((++___i))
            done
            while
                ((___j>___p)) &&
                ! ___lt "${___array[___j]}" "${___array[___p]}"
            do
                ((--___j))
            done
            ((___i<___j))
        do
            ___x="${___array[$___i]}"
            ___array[$___i]="${___array[$___j]}"
            ___array[$___j]="$___x"
            if ((___i==___p))
            then ___p=$___j
            elif ((___j==___p))
            then ___p=$___i
            fi
        done
        ___pp+=( $___l,$((___p-1)) $((___p+1)),$___r )
    done
    unset -f ___lt
}

################################################################################
# heap-sort
# note comparison inversion: keep the "biggest" at the front, so that it will be put at the tail end of the extraction array
hsort_array() {
    local -n ___array=$1
    eval  "___lt() { ${2:-[[ \$1 < \$2 ]]} ; }"
    local ___n=${#___array[@]} ___i ___j ___m ___x
    for ((___m=1;___m<___n;++___m)) do
        ___x="${___array[$___m]}"
        for ((___i=___m;(___j=(___i-1)>>1)>=0;___i=___j)) do
            ___lt "$___x" "${___array[___j]}" && break
            ___array[$___i]="${___array[$___j]}"
        done
        ___array[$___i]="$___x"
    done
    for ((;--___m>0;)) do
        ___x="${___array[___m]}"
        ___array[___m]="${___array[0]}"
        for ((___i=0;(___j=(___i<<1)+1)<___m-1;___i=___j)) do
            ((___j+1<___m)) && ___lt "${___array[___j]}" "${___array[___j+1]}" && ((++___j))
            ___lt "${___array[___j]}" "${___x}" && break
            ___array[$___i]="${___array[$___j]}"
        done
        ___array[___i]="$___x"
    done
    unset -f ___lt ____lt
}

################################################################################
# inverted heap-sort (not yet implemented)
# Keep the root of the heap in the last array position, so that extraction of
# the lowest elements can stop after a limited number of iterations.
#
# The optional 3rd parameteris the number of head elements required.
#
# The array will truncated to the head size after sorting.

#((___hsort_debug=1))

hhsort_array() {
    die 99 UNIMPLEMENTED
#   local -n ___array=$1
# # if ((___hsort_debug))
# # then ___lt() {
# #         printf 'COMPARING "%s" WITH "%s" ... ' "$1" "$2"
# #         if ____lt "$1" "$2"
# #         then
# #             printf 'LESS (%#x)\n' $?
# #             return 0
# #         else
# #             local ___e=$?
# #             if ____lt "$2" "$1"
# #             then printf 'MORE (%#x,%#x)\n' $___e $?
# #             else printf 'SAME (%#x,%#x)\n' $___e $?
# #             fi
# #             return $___e
# #         fi
# #      }
# #      eval "____lt() { ${2:-[[ \$1 < \$2 ]]} ; }"
# # else
#       eval  "___lt() { ${2:-[[ \$1 < \$2 ]]} ; }"
# # fi
#   local ___h=$3
#   local ___n=${#___array[@]} ___i ___j ___m ___x
# # ((___hsort_debug)) && {
# #     printf 'START SORT\n'
# #     declare -p $1
# #     printf '\nSTART BUILDING HEAP\n'
# # }
#   for ((___m=1;___m<___n;++___m)) do
# #     ((___hsort_debug)) && printf 'SINK %u "%s"\n' $___m "${___array[___m]}"
#       ___x="${___array[$___m]}"
#       for ((___i=___m;(___j=(___i-1)>>1)>=0;___i=___j)) do
# #         ((___hsort_debug)) && printf 'COMPARE DOWN %u %u\n' $___i $___j
#           ___lt "$___x" "${___array[___j]}" && break
# #         ((___hsort_debug)) && printf 'MOVE %u "%s" UP TO %u\n' $___j "${___array[___j]}" $___i
#           ___array[$___i]="${___array[$___j]}"
#       done
#       ___array[$___i]="$___x"
# #     ((___hsort_debug)) && printf 'SUNK FROM %u TO %u "%s"\n\n' $___m $___i "$___x"
#   done
# # ((___hsort_debug)) && {
# #     printf 'FINISHED BUILDING HEAP\n'
# #     declare -p $1 ___m
# #     printf '\nSTART EXTRACTING\n'
# # }
#   for ((;--___m>0;)) do
# #     ((___hsort_debug)) && printf 'SWAP %u "%s" WITH ROOT "%s" (AND THEN RAISE)\n' $___m "${___array[___m]}" "${___array[0]}"
#       ___x="${___array[___m]}"
#       ___array[___m]="${___array[0]}"
#       for ((___i=0;(___j=(___i<<1)+1)<___m-1;___i=___j)) do
# #         ((___hsort_debug && ___j+1<___m)) && printf 'COMPARE SIBLINGS %u %u\n' $___j $((___j+1))
#           ((___j+1<___m)) && ___lt "${___array[___j]}" "${___array[___j+1]}" && ((++___j))
# #         ((___hsort_debug)) && printf 'COMPARE %u "%s" AND ROOT "%s"\n' $___j "${___array[___j]}" "$___x"
#           ___lt "${___array[___j]}" "${___x}" && break
# #         ((___hsort_debug)) && printf 'MOVE %u "%s" TO %u\n' $___j "${___array[___j]}" $___i 
#           ___array[$___i]="${___array[$___j]}"
#       done
# #     ((___hsort_debug)) && printf 'MOVE %u VIA ROOT TO %u "%s"\n\n' $___m $___i "$___x"
#       ___array[___i]="$___x"
#   done
# # ((___hsort_debug)) && {
# #     echo FINISHED EXTRACTING
# #     declare -p $1
# #     echo $'\n'FINISHED SORT
# # }
#   unset -f ___lt ____lt
}

################################################################################
# shell sort (not yet implemented)
#
# The optional 3rd parameter is a comma-separated list of gaps.
#
# If the last term is smaller than the array size, it will be assumed to be an
# arithmetic expression parameterized by n, and will be evaluated repeatedly to
# extend the list, until either it does not produce an increasing value, or it
# produces a value larger than the array size. The values will then be used in
# reverse order to perform the sort.
#
# If no sequence is supplied, the string "1,((1<<(2*n))+3*(1<<n)+1)" will be
# used, thus implementing the Sedgewick sequence: 1,8,23,77,281,...
# {1}⋃{4ⁿ+3×2ⁿ+1:∀n∈ℤ>0}

ssort_array() { die 99 UNIMPLEMENTED; }

# Algorithm discription from https://en.wikipedia.org/wiki/Shellsort 20150918
#   # Sort an array a[0...n-1].
#   gaps = [701, 301, 132, 57, 23, 10, 4, 1]
#
#   # Start with the largest gap and work down to a gap of 1
#   foreach (gap in gaps)
#   {
#       # Do a gapped insertion sort for this gap size.
#       # The first gap elements a[0..gap-1] are already in gapped order
#       # keep adding one more element until the entire array is gap sorted
#       for (i = gap; i < n; i += 1)
#       {
#           # add a[i] to the elements that have been gap sorted
#           # save a[i] in temp and make a hole at position i
#           temp = a[i]
#           # shift earlier gap-sorted elements up until the correct location for a[i] is found
#           for (j = i; j >= gap and a[j - gap] > temp; j -= gap)
#           {
#               a[j] = a[j - gap]
#           }
#           # put temp (the original a[i]) in its correct location
#           a[j] = temp
#       }
#   }

################################################################################
# insertion sort (not yet implemented)
#
# The parameters from 3 onwards denote input arrays, each of which will have
# elements successively inserted into the target array, which should already be
# sorted or empty.

isort_array() { die 99 UNIMPLEMENTED; }

################################################################################
# merge sort (not yet implemented)
#
# This differs from the other sorts in that the 1st parameter only specifies an
# output array while the parameters from 3 onwards denote input arrays. If the
# output array is not empty, it will be appended to.

msort_array() { die 99 UNIMPLEMENTED; }


################################################################################
# default to heap-sort
sort_array() { hsort_array "$@"; }

################################################################################
type -t _provides >/dev/null && {
    _provides bsort_array
#   _provides hhsort_array
    _provides hsort_array
#   _provides isort_array
#   _provides msort_array
    _provides qsort_array
    _provides rqsort_array
    _provides sort_array
#   _provides ssort_array
}
