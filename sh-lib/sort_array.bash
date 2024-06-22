#
# Various sort algorithms applied to a Bash array variable
#
# Each sort function takes the same parameters in the same order:
#
# The first parameter is the name of the array to be sorted; the remaining
# parameters are optional.
#
# The 2nd parameter is a "less than" comparator; either
#   -S or --string      [[ $1 < $2 ]]           lexicographically precedes
# or
#   -N or --numeric     (( 10#$1 < 10#$2 ))     numerically less than
# or
#   a shell function name
# or
#   a code fragment that takes the two comparison args at the end (not recommended).
#
# The comparator defaults to "--string" if missing or empty.
#
# The shell function or fragment will be provided with two values from the
# array as arguments.  When finished, the array (or nominated subrange) will be
# sorted so that the comparator returns true for any two consecutive elements.
#
# The comparator must be transitive and stable.
#
# The 3rd & 4th parameters, if present, indicate the subrange to be sorted.
#   * The 3rd parameter indicates the number of elements to be sorted, and
#     defaults to "until the end of the array".
#   * The 4th parameter indicates the starting position; a negative value may
#     be used to indicate a position relative to the end of the array. If
#     missing it defaults to the start of the array (unless the 3rd parameter
#     is negative, in which case it counts backwards from the end of the array.
#
# The 5th parameter is used to continue an incremental sort; it should be the
# name of an array variable.  Whether that variable is used and what it
# contains depends on which type of sort is used. (If omitted it will use an
# obfuscated name based on the name of the array to be sorted.)
#   * for incremental quick-sort, it contains the partition boundary positions
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
#   quick-sort (though the remainder will be partially sorted as well)
# Other types of sort may not benefit.
#

################################################################################

# Can't make locals using a function, so need an alias to mangle the parsing
builtin alias _sort_init='
    local -n _sort_array="$1" ;
    local _sort_comparator="$2" ;
    local _sort_count="$3" ;
    local _sort_start="$4" ;
    local _sort_n="${#_sort_array[@]}" ;
    local -n _sort_sidemap="${5:-${1}_sort_incremental_sidemap___}"
    local _sort_nearer_tail
    __sort_init2 '  # ⇐⇐⇐ expects "$@" to be here

__sort_init2() {    # double-underscore because it must persist
    # Force the sidemap array into existence
    _sort_sidemap+=()

    # Normalize the request range.
    # Initialize the sidemap if both start & count are missing, empty, or ‘-’.
    if [[ -z ${_sort_start#-} ]] ; then
        if [[ -z ${_sort_count#-} ]] ; then
            # Init mode
            _sort_sidemap=()
            (( _sort_start = 0, _sort_count = _sort_n ))
        elif (( _sort_count < 0 )) ; then
            (( _sort_start=_sort_count ))
        else
            (( _sort_start=0 ))
        fi
    fi

    # Nearer to start/left or end/right of array?
    (( _sort_nearer_tail = ( _sort_n-_sort_start < _sort_start+_sort_count )))

    # Customize the comparator
    case $_sort_comparator in
      -N|--numeric)   _sort_comparator='(( 10#$1 < 10#$2 ))' ;;
      -S|--string|'') _sort_comparator='[[ $1 < $2 ]]'       ;;
      __sort*)        _sort_comparator="$( declare -pf "$_sort_comparator" | tail -n +2 )" ;;
    esac

    # Define the comparison function _sort_before
    # (define a verbose debugging version if required)
    if ((_sort_debug))
    then
        _sort_before() {
            printf 'COMPARING "%s" WITH "%s" ... ' "$1" "$2"
            if _sort_before2 "$1" "$2"
            then
                printf 'LESS (%#x)\n' $?
                return 0
            else
                local _sort_e=$?
                if _sort_before2 "$2" "$1"
                then printf 'MORE (%#x,%#x)\n' $_sort_e $?
                else printf 'SAME (%#x,%#x)\n' $_sort_e $?
                fi
                return $_sort_e
            fi
        }
        eval "_sort_before2() { $_sort_comparator ; }"
    else
        eval  "_sort_before() { $_sort_comparator ; }"
    fi

    # Arrange for cleanup once the sort is complete
    _sort_cleanup() {
        unset -f _sort_before \
                 _sort_before2 \
                 _sort_part \
                 _sort_cleanup 2> /dev/null
    }
}

################################################################################
# bubble-sort

bsort_array() {
    _sort_init "$@"
    local _sort_i _sort_j _sort_k _sort_x
    for ((_sort_i=0;_sort_i<_sort_n;_sort_i++)) do
        for ((_sort_k=_sort_i, _sort_j=_sort_i+1;_sort_j<_sort_n;_sort_j++)) do
            _sort_before "${_sort_array[_sort_k]}" "${_sort_array[_sort_j]}" || (( _sort_k=_sort_j ))
        done
        if (( _sort_k != _sort_i )) ; then
            _sort_x="${_sort_array[_sort_i]}"
            _sort_array[_sort_i]="${_sort_array[_sort_k]}"
            _sort_array[_sort_k]="$_sort_x"
        fi
    done
    _sort_cleanup
}

################################################################################
# recursive quick-sort
rqsort_array() {
    _sort_init "$@"
    local _sort_i _sort_j _sort_x
    #eval "_sort_before() { ${2:-string}; }"
    _sort_part() {
        local _sort_l=$1 _sort_r=$2 _sort_p=$2
        ((_sort_l==_sort_r)) && return
        _sort_i=$_sort_l _sort_j=$_sort_r
        _sort_p=$_sort_r
        if  ((_sort_l+1<_sort_p)) &&
            _sort_before "${_sort_array[_sort_l+1]}" "${_sort_array[_sort_r]}"
        then
            _sort_p=$((_sort_l+1))
        fi
        while
            while
                ((_sort_i<_sort_p)) &&
                _sort_before "${_sort_array[_sort_i]}" "${_sort_array[_sort_p]}"
            do
                ((++_sort_i))
            done
            while
                ((_sort_j>_sort_p)) &&
                ! _sort_before "${_sort_array[_sort_j]}" "${_sort_array[_sort_p]}"
            do
                ((--_sort_j))
            done
            ((_sort_i<_sort_j))
        do
            _sort_x="${_sort_array[_sort_i]}"
            _sort_array[_sort_i]="${_sort_array[_sort_j]}"
            _sort_array[_sort_j]="$_sort_x"
            if ((_sort_i==_sort_p))
            then _sort_p=$_sort_j
            elif ((_sort_j==_sort_p))
            then _sort_p=$_sort_i
            fi
        done
        _sort_part $_sort_l $((_sort_p-1))
        _sort_part $((_sort_p+1)) $_sort_r
    }
    _sort_part 0 $_sort_n
    _sort_cleanup
}

################################################################################
# nonrecursive quick-sort
qsort_array() {
    _sort_init "$@"
    local _sort_i _sort_j _sort_l _sort_p _sort_r _sort_x
    (( ${#_sort_sidemap[@]} == 0 )) &&
        _sort_sidemap=( - 0,$((_sort_n-1)) )
    while ((${#_sort_sidemap[@]} > 1 ))
    do
        _sort_p=${_sort_sidemap[-1]}
        _sort_l=${_sort_p%,*}
        _sort_r=${_sort_p#*,}
        # Can stop early when everything in the target range is sorted
        (( _sort_nearer_tail ? _sort_r >= _sort_n-_sort_count : _sort_l < _sort_start+_sort_count )) || break
        unset _sort_sidemap[-1]
        ((_sort_l < _sort_r)) || continue
        _sort_i=$_sort_l _sort_j=$_sort_r
        _sort_p=$_sort_r
        if  ((_sort_l+1<_sort_p)) &&
            _sort_before "${_sort_array[_sort_l+1]}" "${_sort_array[_sort_r]}"
        then
            _sort_p=$((_sort_l+1))
        fi
        while
            while
                ((_sort_i<_sort_p)) &&
                _sort_before "${_sort_array[_sort_i]}" "${_sort_array[_sort_p]}"
            do
                ((++_sort_i))
            done
            while
                ((_sort_j>_sort_p)) &&
                ! _sort_before "${_sort_array[_sort_j]}" "${_sort_array[_sort_p]}"
            do
                ((--_sort_j))
            done
            ((_sort_i<_sort_j))
        do
            _sort_x="${_sort_array[_sort_i]}"
            _sort_array[_sort_i]="${_sort_array[_sort_j]}"
            _sort_array[_sort_j]="$_sort_x"
            if ((_sort_i==_sort_p))
            then _sort_p=$_sort_j
            elif ((_sort_j==_sort_p))
            then _sort_p=$_sort_i
            fi
        done
        # sub-sort the left or right half next, depending on whether the
        # target subrange is nearer the left or right end of the array.
        if ((_sort_nearer_tail))
        then _sort_sidemap+=( $_sort_l,$((_sort_p-1)) $((_sort_p+1)),$_sort_r )
        else _sort_sidemap+=( $((_sort_p+1)),$_sort_r $_sort_l,$((_sort_p-1)) )
        fi
    done
    _sort_cleanup
}

################################################################################
# heap sort
# note comparison inversion: keep the ‘biggest’ at the front, so that it will
# be put at the tail end of the extraction array
hsort_array() {
    local -n _sort_array=$1
    local _sort_n=${#_sort_array[@]} _sort_i _sort_j _sort_m _sort_x
    _sort_init "$@"
    for ((_sort_m=1;_sort_m<_sort_n;++_sort_m)) do
        _sort_x="${_sort_array[_sort_m]}"
        for ((_sort_i=_sort_m;(_sort_j=(_sort_i-1)>>1)>=0;_sort_i=_sort_j)) do
            _sort_before "$_sort_x" "${_sort_array[_sort_j]}" && break
            _sort_array[_sort_i]="${_sort_array[_sort_j]}"
        done
        _sort_array[_sort_i]="$_sort_x"
    done
    for ((;--_sort_m>0;)) do
        _sort_x="${_sort_array[_sort_m]}"
        _sort_array[_sort_m]="${_sort_array[0]}"
        for ((_sort_i=0;(_sort_j=(_sort_i<<1)+1)<_sort_m-1;_sort_i=_sort_j)) do
            ((_sort_j+1<_sort_m)) && _sort_before "${_sort_array[_sort_j]}" "${_sort_array[_sort_j+1]}" && ((++_sort_j))
            _sort_before "${_sort_array[_sort_j]}" "${_sort_x}" && break
            _sort_array[_sort_i]="${_sort_array[_sort_j]}"
        done
        _sort_array[_sort_i]="$_sort_x"
    done
    _sort_cleanup
}

################################################################################
# inverted heap sort (not yet implemented)
# Keep the root of the heap in the last array position, so that extraction of
# the lowest elements can stop after a limited number of iterations.
#
# The optional 3rd parameter is the number of head elements required.
#
# The array will truncated to the head size after sorting.

#((_sort_debug=1))

hhsort_array() {
#   die 99 UNIMPLEMENTED
    local -n _sort_array=$1
    local _sort_n=${#_sort_array[@]} _sort_i _sort_j _sort_m _sort_x
    local _sort_h=$3
    _sort_init "$@"
  # ((_sort_debug)) && {
  #     printf 'START SORT\n'
  #     declare -p $1
  #     printf '\nSTART BUILDING HEAP\n'
  # }
    for ((_sort_m=1;_sort_m<_sort_n;++_sort_m)) do
  #     ((_sort_debug)) && printf 'SINK %u "%s"\n' $_sort_m "${_sort_array[_sort_m]}"
        _sort_x="${_sort_array[_sort_m]}"
        for ((_sort_i=_sort_m;(_sort_j=(_sort_i-1)>>1)>=0;_sort_i=_sort_j)) do
  #         ((_sort_debug)) && printf 'COMPARE DOWN %u %u\n' $_sort_i $_sort_j
            _sort_before "$_sort_x" "${_sort_array[_sort_j]}" && break
  #         ((_sort_debug)) && printf 'MOVE %u "%s" UP TO %u\n' $_sort_j "${_sort_array[_sort_j]}" $_sort_i
            _sort_array[_sort_i]="${_sort_array[_sort_j]}"
        done
        _sort_array[_sort_i]="$_sort_x"
  #     ((_sort_debug)) && printf 'SUNK FROM %u TO %u "%s"\n\n' $_sort_m $_sort_i "$_sort_x"
    done
  # ((_sort_debug)) && {
  #     printf 'FINISHED BUILDING HEAP\n'
  #     declare -p $1 _sort_m
  #     printf '\nSTART EXTRACTING\n'
  # }
    for ((;--_sort_m>0;)) do
  #     ((_sort_debug)) && printf 'SWAP %u "%s" WITH ROOT "%s" (AND THEN RAISE)\n' $_sort_m "${_sort_array[_sort_m]}" "${_sort_array[0]}"
        _sort_x="${_sort_array[_sort_m]}"
        _sort_array[_sort_m]="${_sort_array[0]}"
        for ((_sort_i=0;(_sort_j=(_sort_i<<1)+1)<_sort_m-1;_sort_i=_sort_j)) do
  #         ((_sort_debug && _sort_j+1<_sort_m)) && printf 'COMPARE SIBLINGS %u %u\n' $_sort_j $((_sort_j+1))
            ((_sort_j+1<_sort_m)) && _sort_before "${_sort_array[_sort_j]}" "${_sort_array[_sort_j+1]}" && ((++_sort_j))
  #         ((_sort_debug)) && printf 'COMPARE %u "%s" AND ROOT "%s"\n' $_sort_j "${_sort_array[_sort_j]}" "$_sort_x"
            _sort_before "${_sort_array[_sort_j]}" "${_sort_x}" && break
  #         ((_sort_debug)) && printf 'MOVE %u "%s" TO %u\n' $_sort_j "${_sort_array[_sort_j]}" $_sort_i
            _sort_array[_sort_i]="${_sort_array[_sort_j]}"
        done
  #     ((_sort_debug)) && printf 'MOVE %u VIA ROOT TO %u "%s"\n\n' $_sort_m $_sort_i "$_sort_x"
        _sort_array[_sort_i]="$_sort_x"
    done
  # ((_sort_debug)) && {
  #     echo FINISHED EXTRACTING
  #     declare -p $1
  #     echo $'\n'FINISHED SORT
  # }
    _sort_cleanup
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

builtin unalias _sort_init

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
