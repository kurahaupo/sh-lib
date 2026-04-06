#
# Various sort algorithms applied to a Bash array variable
#
# Each sort function takes the name of the array to be sorted as its 1st
# parameter.
#
# The optional 2nd parameter is a "less than" comparator; either
#   --string        [[ $1 < $2 ]]           lexicographically precedes
#   --numeric       (( 10#$1 < 10#$2 ))     numerically less than
#   a shell function name or code fragment
#
# Defaults to "--string" if missing or empty.
#
# The shell function or fragment will be provided with two values from the
# array as arguments.  When finished, the array (or nominated subrange) will be
# sorted so that the comparator returns true for any two consecutive elements.
#
# The comparator must be transitive and stable.
#
# The 3rd & 4th parameters, if present, indicate the subrange to be sorted.
# The 3rd parameter indicates the number of elements to be sorted, and defaults
# to "until the end of the array".
# The 4th parameter indicates the starting position; a negative value may be
# used to indicate a position relative to the end of the array. If missing it
# defaults to the start of the array (unless the 3rd parameter is negative, in
# which case it counts backwards from the end of the array.
#
# The 5th parameter is used to continue an incremental sort; it should be the
# name of an array variable.  Whether that variable is used and what it
# contains depends on which type of sort is used.
# It should either be
#
# Upon return, the nominated range will be correctly sorted, and if this is
# part of an incremental sort, any previously sorted ranges will also remain
# correctly sorted.  The remainder of the array will be in some indeterminate
# order (though it will contain all the remaining values).
#
# If the count parameter is 0, the incremental sort tracking array
# is initialized but the array is in indeterminate order.
#
# This can be used to improve the performance of:
#   bubble sort;
#   selection sort;
#   heap sort; and
#   quicksort (though the remainder will be partially sorted as well)
# Other types of sort may not benefit.
#

################################################################################

# Can't make locals using a function, so need an alias to mangle the parsing
alias ___sort_init='
    local -n ___array="$1" ;
    local ___comparator="$2" ;
    local ___start="$3" ;
    local ___count="$4" ;
    local ___n="${#___array[@]}" ;
    local -n ___sidemap="${5:-${1}___incremental_sort_sidemap___}"
    local ___nearer_tail
    __sort_setup '

__sort_setup() {
    # Force the sidemap array into existence
    ___sidemap+=()

    # Normalize the request range.
    # Initialize the sidemap if both start & count are missing, empty, or ‘-’.
    if [[ -z ${___start#-} ]] ; then
        if [[ -z ${___count#-} ]] ; then
            # Init mode
            ___sidemap=()
            (( ___start = 0, ___count = ___n ))
        elif (( ___count < 0 )) ; then
            (( ___start=___count ))
        else
            (( ___start=0 ))
        fi
    fi

    # Nearer to start/left or end/right of array?
    (( ___nearer_tail = ( ___n-___start < ___start+___count )))

    # Customize the comparator
    case $___comparator in
      -N|--numeric)   ___comparator='(( 10#$1 < 10#$2 ))' ;;
      -S|--string|'') ___comparator='[[ \$1 < \$2 ]]'     ;;
      ___sort*)       ___comparator="$( declare -pf "$___comparator" | tail -n +2 )" ;;
    esac

    # Define the comparison function ___sorts_before
    # (define a verbose debugging version if required)
    if ((___sort_debug))
    then
        ___sorts_before() {
            printf 'COMPARING "%s" WITH "%s" ... ' "$1" "$2"
            if ___sorts_before2 "$1" "$2"
            then
                printf 'LESS (%#x)\n' $?
                return 0
            else
                local ___e=$?
                if ___sorts_before2 "$2" "$1"
                then printf 'MORE (%#x,%#x)\n' $___e $?
                else printf 'SAME (%#x,%#x)\n' $___e $?
                fi
                return $___e
            fi
        }
        eval "___sorts_before2() { $___comparator ; }"
    else
        eval  "___sorts_before() { $___comparator ; }"
    fi

    # Arrange for cleanup once the sort is complete
    ___sort_cleanup() {
        unset -f ___sort'*'
    }
}

################################################################################
# bubble-sort

bsort_array() {
    ___sort_init "$@"
    local ___i ___j ___k ___x
    for ((___i=0;___i<___n;___i++)) do
        for ((___k=___i, ___j=___i+1;___j<___n;___j++)) do
            ___sorts_before "${___array[___k]}" "${___array[___j]}" || (( ___k=___j ))
        done
        if (( ___k != ___i )) ; then
            ___x="${___array[$___i]}"
            ___array[$___i]="${___array[$___k]}"
            ___array[$___k]="$___x"
        fi
    done
    ___sort_cleanup
}

################################################################################
# recursive quick-sort
rqsort_array() {
    ___sort_init "$@"
    local ___i ___j ___x
    #eval "___sorts_before() { ${2:-string}; }"
    ___part() {
        local ___l=$1 ___r=$2 ___p=$2
        ((___l==___r)) && return
        ___i=$___l ___j=$___r
        ___p=$___r
        if  ((___l+1<___p)) &&
            ___sorts_before "${___array[___l+1]}" "${___array[___r]}"
        then
            ___p=$((___l+1))
        fi
        while
            while
                ((___i<___p)) &&
                ___sorts_before "${___array[___i]}" "${___array[___p]}"
            do
                ((++___i))
            done
            while
                ((___j>___p)) &&
                ! ___sorts_before "${___array[___j]}" "${___array[___p]}"
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
    ___sort_cleanup
}

################################################################################
# nonrecursive quick-sort
qsort_array() {
    ___sort_init "$@"
    local ___i ___j ___l ___p ___r ___x
    (( ${#___sidemap[@]} == 0 )) &&
        ___sidemap=( - 0,$((___n-1)) )
    while ((${#___sidemap[@]} > 1 ))
    do
        ___p=${___sidemap[-1]}
        ___l=${___p%,*}
        ___r=${___p#*,}
        # Can stop early when everything in the target range is sorted
        (( ___nearer_tail ? ___r >= ___n-___count : ___l < ___start+___count )) || break
        unset ___sidemap[-1]
        ((___l < ___r)) || continue
        ___i=$___l ___j=$___r
        ___p=$___r
        if  ((___l+1<___p)) &&
            ___sorts_before "${___array[___l+1]}" "${___array[___r]}"
        then
            ___p=$((___l+1))
        fi
        while
            while
                ((___i<___p)) &&
                ___sorts_before "${___array[___i]}" "${___array[___p]}"
            do
                ((++___i))
            done
            while
                ((___j>___p)) &&
                ! ___sorts_before "${___array[___j]}" "${___array[___p]}"
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
        # sub-sort the left or right half next, depending on whether the
        # target subrange is nearer the left or right end of the array.
        if ((___nearer_tail))
        then ___sidemap+=( $___l,$((___p-1)) $((___p+1)),$___r )
        else ___sidemap+=( $((___p+1)),$___r $___l,$((___p-1)) )
        fi
    done
    ___sort_cleanup
}

################################################################################
# heap sort
# note comparison inversion: keep the ‘biggest’ at the front, so that it will
# be put at the tail end of the extraction array
hsort_array() {
    local -n ___array=$1
    local ___n=${#___array[@]} ___i ___j ___m ___x
    ___sort_init "$@"
    for ((___m=1;___m<___n;++___m)) do
        ___x="${___array[$___m]}"
        for ((___i=___m;(___j=(___i-1)>>1)>=0;___i=___j)) do
            ___sorts_before "$___x" "${___array[___j]}" && break
            ___array[$___i]="${___array[$___j]}"
        done
        ___array[$___i]="$___x"
    done
    for ((;--___m>0;)) do
        ___x="${___array[___m]}"
        ___array[___m]="${___array[0]}"
        for ((___i=0;(___j=(___i<<1)+1)<___m-1;___i=___j)) do
            ((___j+1<___m)) && ___sorts_before "${___array[___j]}" "${___array[___j+1]}" && ((++___j))
            ___sorts_before "${___array[___j]}" "${___x}" && break
            ___array[$___i]="${___array[$___j]}"
        done
        ___array[___i]="$___x"
    done
    ___sort_cleanup
}

################################################################################
# inverted heap sort (not yet implemented)
# Keep the root of the heap in the last array position, so that extraction of
# the lowest elements can stop after a limited number of iterations.
#
# The optional 3rd parameter is the number of head elements required.
#
# The array will truncated to the head size after sorting.

#((___sort_debug=1))

hhsort_array() {
    die 99 UNIMPLEMENTED
#   local -n ___array=$1
#   local ___n=${#___array[@]} ___i ___j ___m ___x
#   local ___h=$3
#   ___sort_init "$@"
# # ((___sort_debug)) && {
# #     printf 'START SORT\n'
# #     declare -p $1
# #     printf '\nSTART BUILDING HEAP\n'
# # }
#   for ((___m=1;___m<___n;++___m)) do
# #     ((___sort_debug)) && printf 'SINK %u "%s"\n' $___m "${___array[___m]}"
#       ___x="${___array[$___m]}"
#       for ((___i=___m;(___j=(___i-1)>>1)>=0;___i=___j)) do
# #         ((___sort_debug)) && printf 'COMPARE DOWN %u %u\n' $___i $___j
#           ___sorts_before "$___x" "${___array[___j]}" && break
# #         ((___sort_debug)) && printf 'MOVE %u "%s" UP TO %u\n' $___j "${___array[___j]}" $___i
#           ___array[$___i]="${___array[$___j]}"
#       done
#       ___array[$___i]="$___x"
# #     ((___sort_debug)) && printf 'SUNK FROM %u TO %u "%s"\n\n' $___m $___i "$___x"
#   done
# # ((___sort_debug)) && {
# #     printf 'FINISHED BUILDING HEAP\n'
# #     declare -p $1 ___m
# #     printf '\nSTART EXTRACTING\n'
# # }
#   for ((;--___m>0;)) do
# #     ((___sort_debug)) && printf 'SWAP %u "%s" WITH ROOT "%s" (AND THEN RAISE)\n' $___m "${___array[___m]}" "${___array[0]}"
#       ___x="${___array[___m]}"
#       ___array[___m]="${___array[0]}"
#       for ((___i=0;(___j=(___i<<1)+1)<___m-1;___i=___j)) do
# #         ((___sort_debug && ___j+1<___m)) && printf 'COMPARE SIBLINGS %u %u\n' $___j $((___j+1))
#           ((___j+1<___m)) && ___sorts_before "${___array[___j]}" "${___array[___j+1]}" && ((++___j))
# #         ((___sort_debug)) && printf 'COMPARE %u "%s" AND ROOT "%s"\n' $___j "${___array[___j]}" "$___x"
#           ___sorts_before "${___array[___j]}" "${___x}" && break
# #         ((___sort_debug)) && printf 'MOVE %u "%s" TO %u\n' $___j "${___array[___j]}" $___i
#           ___array[$___i]="${___array[$___j]}"
#       done
# #     ((___sort_debug)) && printf 'MOVE %u VIA ROOT TO %u "%s"\n\n' $___m $___i "$___x"
#       ___array[___i]="$___x"
#   done
# # ((___sort_debug)) && {
# #     echo FINISHED EXTRACTING
# #     declare -p $1
# #     echo $'\n'FINISHED SORT
# # }
#   ___sort_cleanup
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

# Algorithm description from https://en.wikipedia.org/wiki/Shellsort 20150918
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

unalias ___sort_init

if  type -t _provides >/dev/null
then
    _provides bsort_array
#   _provides hhsort_array
    _provides hsort_array
#   _provides isort_array
#   _provides msort_array
    _provides qsort_array
    _provides rqsort_array
    _provides sort_array
#   _provides ssort_array
fi
