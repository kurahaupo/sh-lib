
# General-purpose splitter

ip._get_parts() {
    local IFS=
    local -n __gp_res=$1
    local __gp_in=$2 __gp_sep=${3:?'missing separator'} __gp_base=${4:+$4#}
    local -i __gp_lim=${5:?'missing limit'} __gp_nparts=${6:--1}
    local __gp_label=${7:-'unlabelled'}
    local __gp_i __gp_x
    IFS=$__gp_sep read -r -a __gp_res <<< "$__gp_in$__gp_sep" || return
    for __gp_i in "${!__gp_res[@]}" ; do
        (( __gp_x = __gp_res[__gp_i] = $__gp_base${__gp_res[__gp_i]},
           __gp_x >= 0 && __gp_x <= __gp_lim )) ||
            { printf >&2 'Invalid %s address "%s" - %s not between 0 and %s\n' \
                         "$__gp_label" "$__gp_in" "$__gp_x" "$__gp_lim"
              return 65 ; } # EX_DATAERR
    done
    (( ${#__gp_res[@]} == __gp_nparts || __gp_nparts == -1 )) ||
        { printf >&2 'Invalid %s address "%s" - wrong number of parts (expected %s, got %u\n' \
                     "$__gp_label" "$__gp_in" "$__gp_nparts" ${#__gp_res[@]}
          return 65 ; } # EX_DATAERR
}

if ! (
    TEST=( 1 2 3 4 5 6 7 8 9 )
    IFS=-
    ip._get_parts TEST 8:9:a:b:c:d:e:000000000f : 16 0xffff 8 TEST &&
    [[ ${TEST[*]} = 8-9-10-11-12-13-14-15 ]]
   ) 2> /dev/null
then
    require _arraycopy

    ip._get_parts() {
        local IFS=
        local __gp_ref=$1
        local -a __gp_res
        local __gp_in=$2 __gp_sep=${3:?'missing separator'} __gp_base=${4:+$4#}
        local -i __gp_lim=${5:?'missing limit'} __gp_nparts=${6:--1}
        local __gp_label=${7:-'unlabelled'}
        local __gp_i __gp_x
        IFS=$__gp_sep read -r -a __gp_res <<< "$__gp_in$__gp_sep" || return
        for __gp_i in "${!__gp_res[@]}" ; do
            (( __gp_x = __gp_res[__gp_i] = $__gp_base${__gp_res[__gp_i]},
               __gp_x >= 0 && __gp_x <= __gp_lim )) ||
                { printf >&2 'Invalid %s address "%s" - %s not between 0 and %s\n' \
                             "$__gp_label" "$__gp_in" "$__gp_x" "$__gp_lim"
                  return 65 ; } # EX_DATAERR
        done
        (( ${#__gp_res[@]} == __gp_nparts || __gp_nparts == -1 )) ||
            { printf >&2 'Invalid %s address "%s" - wrong number of parts (expected %s, got %u\n' \
                         "$__gp_label" "$__gp_in" "$__gp_nparts" ${#__gp_res[@]}
              return 65 ; } # EX_DATAERR
        _arraycopy "$__gp_ref" "${__gp_res[@]}" ||
            { printf >&2 'ip._get_parts failed to set return array %s=(%s)\n' \
                         "$1" "${__gp_res[*]}"
              return 70 ; } # EX_SOFTWARE
    }
fi

# Split a 48-bit (Ethernet? MAC?) link-layer address into an array of 6 octets
ip.ll_parts() {
    [[ $2 != *[!0-9a-fA-F:]* ]] || { printf >&2 'Invalid link-layer address "%s" (symbol other than colon and hex digits))\n' "$2" ; return 65 ; } # EX_DATAERR
    [[ :$2: != *::* && :$2: != *:?:* && $2 != *[!:][!:][!:]* ]] || { printf >&2 'Invalid MAC address "%s" (part not 2-digit)\n' "$2" return 65 ; } # EX_DATAERR
    ip._get_parts "$1" "$2" : 16 0xff -1 link-layer
}

# Split a 32-bit IPv4 address into an array of 4 octets
ip.v4_parts() {
    [[ $2 != *[!.[:digit:]]* ]] || { printf >&2 'Invalid IPv4 address "%s" (symbol other than dot and digits)\n' "$2" return 65 ; } # EX_DATAERR
    [[ $2 = *.*.*.* && $2 != *.*.*.*.* ]] || { printf >&2 'Invalid IPv4 address "%s" (wrong number of parts\n' "$2" return 65 ; } # EX_DATAERR
    [[ .$2. != *..* ]] || { printf >&2 'Invalid IPv4 address "%s" (empty part)\n' "$2" return 65 ; } # EX_DATAERR
    ip._get_parts "$1" "$2" . 10 255 4 IPv4
}

# Split a 128-bit IPv6 address into an array of 8 16-bit words
# ("hexadecuplets"?), including converting :: to :0:0...:0:
ip.v6_parts() {
    local __v6p_in=$2
    [[ $__v6p_in != *:::* && $__v6p_in != *::*::* ]] ||
        { printf >&2 'Invalid IPv6 address "%s" (invalid or repeated shorthand blocks)\n' "$__v6p_in"
          return 65 ; } # EX_DATAERR
    [[ $__ca6_addr != *[!:0-9a-fA-F]* ]] ||
        { printf >&2 'Invalid IPv6 address "%s" (contains symbol other than colon or hex digit)\n' "$__v6p_in"
          return 65 ; } # EX_DATAERR
    while
        [[ $__v6p_in = *::* && $__v6p_in != *:*:*:*:*:*:*:* ]]
    do
        __v6p_in=${__v6p_in/::/:0::}
    done
    ip._get_parts "$1" "$__v6p_in" : 16 0x0ffff 8 IPv6
}

#
# Canonicalize and compose an IPv4 address from multiple prefixes.
#
# Usage:
#   ip.canon_v4 VAR [ { PREFIX LENGTH } ...] SUFFIX
#
# If VAR is '-' or empty, writes to stdout instead.
#
ip.canon_v4() {
    local __ca4_out=${1#-} __ca4_addr=${2:-${!1}}
    [[ -n "$__ca4_addr" ]] || return    # do nothing if var is unset or empty
  # debug CANON 'Canonicalize v4 ADDR %s' "${*:2}"
    local -ia __ca4_parts __ca4_res
    local -i __ca4_i __ca4_plen=0  # prefix so far
    __ca4_parts=(0 0 0 0)
    __ca4_res=(0 0 0 0)
    while
        ip.v4_parts __ca4_parts "$__ca4_addr"
        (( __ca4_i = __ca4_plen/8,
           __ca4_b = __ca4_plen%8,
           __ca4_res[__ca4_i] ^= (__ca4_parts[__ca4_i] ^ __ca4_res[__ca4_i]) & 0xff >> __ca4_b ))
        for ((; ++__ca4_i < 4 ;)) do (( __ca4_res[__ca4_i]  =  __ca4_parts[__ca4_i] )) ; done
      # debug CANON '                   → %u.%u.%u.%u' "${__ca4_res[@]:0:4}"
        shift &&
        shift &&
        (( $# && ( __ca4_i = ${1:-32} ) < 32 ))
    do
        (( __ca4_i != __ca4_plen )) ||
            #warn 'Empty prefix segment, args remaining %u:[%s]' $# "$*"
            { printf >&2 'Empty prefix segment, args remaining %u:[%s]\n' $# "$*"
            }
        (( __ca4_i >= __ca4_plen )) ||
            #warn 'Prefix segments out of order; was %d now %d, args remaining %u:[%s]\n' $__ca4_plen $__ca4_i $# "$*"
            { printf >&2 'Prefix segments out of order; was %d now %d, args remaining %u:[%s]\n' $__ca4_plen $__ca4_i $# "$*"
            }
        __ca4_plen=${1:-32}
        __ca4_addr=${2:-0.0.0.0}
    done
    printf ${__ca4_out:+-v"$__ca4_out"} %u.%u.%u.%u "${__ca4_res[@]:0:4}"
}

#
# Canonicalize and compose an IPv6 address from multiple prefixes.
#
# Usage:
#   ip.canon_v6 VAR [ { PREFIX LENGTH } ...] SUFFIX
#
# If VAR is '-' or empty, writes to stdout instead.
#
# The canonicalization is actually more general than IPv6 requires, as it
# accepts embedded IPv4 in non-terminal positions, which means it can
# understand and accept things like:
#   2002:202.27.199.119::1:2:3:4
#

ip.canon_v6() {
    local __ca6_out=${1#-} __ca6_addr=${2:-${!1}}
  # [[ -n "$__ca6_addr" ]] || return    # do nothing if var is unset or empty
  # debug CANON 'Canonicalize v6 ADDR %s' "${*:2}"
    local -ia __ca6_parts __ca6_res=(0 0 0 0 0 0 0 0)
    local -i __ca6_i __ca6_plen=0  # prefix so far
    while
        if [[ $__ca6_addr = *.*.*.* ]] ; then
            # embedded IPv4 within IPv6
            local __ca6_pref=${__ca6_addr%%:*([:[:xdigit:]])}
            local __ca6_sufx=${__ca6_addr#"$__ca6_pref"}
            local __ca6_v4embedded=${__ca6_pref##*:}
            __ca6_pref=${__ca6_pref%%"$__ca6_v4embedded"}
            ip.v4_parts __ca6_parts "$__ca6_v4embedded" || return
            printf -v __ca6_addr %s%02x%02x:%02x%02x%s "$__ca6_pref" "${__ca6_parts[@]:0:4}" "$__ca6_sufx"
        elif
            ip.ll_parts __ca6_parts "$__ca6_addr" 2> /dev/null &&
            (( ${#__ca6_parts[@]} == 6 ||
               ${#__ca6_parts[@]} == 8 ))
        then
            # link-layer address instead
            (( __ca6_parts[0] ^= 2 ))
            if (( ${#__ca6_parts[@]} == 6 ))
            then
                __ca6_parts=( "${__ca6_parts[@]:0:3}" 0xff 0xfe "${__ca6_parts[@]:3:3}" )
            fi
            printf -v __ca6_addr fe80::%02x%02x:%02x%02x:%02x%02x:%02x%02x "${__ca6_parts[@]}"
        fi
        ip.v6_parts __ca6_parts "$__ca6_addr" || return
        (( __ca6_i = __ca6_plen/16,
           __ca6_b = __ca6_plen%16,
           __ca6_res[__ca6_i] ^= (__ca6_parts[__ca6_i] ^ __ca6_res[__ca6_i]) & 0xffff >> __ca6_b ))
        for ((; ++__ca6_i < 8 ;)) do (( __ca6_res[__ca6_i]  =  __ca6_parts[__ca6_i] )) ; done
      # debug CANON '                   → %04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x'  "${__ca6_res[@]:0:8}"
        shift 2 &&
        (( $# && ( __ca6_i = $1 ) < 128 ))
    do
        (( __ca6_i != __ca6_plen )) ||
            #warn 'Empty prefix segment, args remaining %u:[%s]\n' $# "$*"
            { printf >&2 'Empty prefix segment, args remaining %u:[%s]\n' \
                         $# "$*"
            }
        (( __ca6_i >= __ca6_plen )) ||
            #warn 'Prefix segments out of order; was %d now %d, args remaining %u:[%s]\n' $__ca6_plen $__ca6_i $# "$*"
            { printf >&2 'Prefix segments out of order; was %d now %d, args remaining %u:[%s]\n' \
                         $__ca6_plen "$__ca6_i" $# "$*"
            }
        __ca6_plen=${1:-128}
        __ca6_addr=${2:-::}
    done
    printf ${__ca6_out:+-v"$__ca6_out"} %04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x  "${__ca6_res[@]:0:8}"
}

ip.canon() {
    local __ca_out=${1#-} __ca_addr=${2:-${!1}}
    case $__ca_addr in
      *:*:* )   ip.canon_v6 "$@" ;;
      *.*.*.* ) ip.canon_v4 "$@" ;;
      *)        printf >&2 'Unknown address type\n' ; return 65 ;;
    esac
}

_provides ip._get_parts ip.ll_parts ip.v4_parts ip.v6_parts ip.canon_v4 ip.canon_v6 ip.canon

return

# :<<\_END

#
# This is a valid POSIX shell function, which does not have general regex, only
# glob matching.
#
check_ipv6_address() {

    local colons=0
    case $1 in
        #
        # Immediately invalid if:
        #   - anything but colons and hex digits
        #   - more than 4 digits per segment (any run of 5 non-colons)
        #   - multiple empty segments
        #   - starts or ends with a single colon
        #   - too many segments (more than 8 colons)
        #

        *[!:0-9a-f]*            | \
        *[!:][!:][!:][!:][!:]*  | \
        *:::*       | *::*::*   | \
        :[!:]*      | *[!:]:    | \
        *:*:*:*:*:*:*:*:*:*     ) return 1 ;;

        #
        # Count how many colons, and validate:
        #    - 3 to 8 - possibly valid
        #    - ≤ 2 (except ::) - invalid
        #
        *:*:*:*:*:*:*:*:*       ) colons=8 ;;
        *:*:*:*:*:*:*:*         ) colons=7 ;;
        *:*:*:*:*:*:*           ) colons=6 ;;
        *:*:*:*:*:*             ) colons=5 ;;
        *:*:*:*:*               ) colons=4 ;;
        *:*:*:*                 ) colons=3 ;;
        *:*:*                   ) colons=2 ;;
        *                       ) return 1
    esac

    #
    # If non-zero, $compression indicates how many segments have been replaced
    # by a single ::
    # If it's at the start or end, include the leading or trailing 0 segment in
    # the compression count (which is why it's arguably permissible to have
    # eight colons when it starts or ends with a compression).
    #
    local lcomp=0 ; case $1 in ::*) lcomp=1 ; esac
    local rcomp=0 ; case $1 in *::) rcomp=1 ; esac
    local compression=0 ; case $1 in *::*) compression=$((8-colons+lcomp+rcomp)) ; esac

    case $colons/$compression in

        #
        # If there's no compression then there must be exactly 7 colons, and if
        # requested there should be no zeroes.
        #
        7/0 )   case :$1: in *:0:0:* | :*:0:*: ) (( IPV6_REQUIRE_MINIMAL )) && return 1 ;;
                             :0:* | *:0:       ) (( IPV6_REQUIRE_MINIMAL_EDGE &&
                                                  ! IPV6_FORBID_MINIMAL_EDGE )) && return 1 ; esac ;;
        ?/0 )   return 1 ;;

        #
        # Valid if using :: to "compress" a single leading trailing zero segment:
        #
        # Many people consider this to be ugly and useless, since it could just
        # as well be written ":0", so if you can treat this case as invalid by
        # setting IPV6_FORBID_MINIMAL_EDGE=1 (or simply deleting the following
        # line).
        #

        8/1 )   (( IPV6_FORBID_MINIMAL_EDGE )) && return 1 ;;

    esac

    #
    # If there's a longer sequence of zero segments than is already
    # compressed, or one of equal length but nearer the start, then that's
    # (optionally) rejected
    #

    (( IPV6_REQUIRE_MINIMAL )) &&
    case $compression in

        1 ) case :$1: in *:0:0:*       )  return 1 ;;
                         *:0:*::*:     ) (( IPV6_ALLOW_DISORDERED_MINIMAL )) || return 1 ; esac ;;
        2 ) case :$1: in *:0:0:0:*     ) return 1 ;;
                         *:0:0:*::*:   ) (( IPV6_ALLOW_DISORDERED_MINIMAL )) || return 1 ; esac ;;
        3 ) case :$1: in *:0:0:0:0:*   ) return 1 ;;
                         *:0:0:0:*::*: ) (( IPV6_ALLOW_DISORDERED_MINIMAL )) || return 1 ; esac ;;

    esac

    case $1 in

        *:*:*:*:*:*:*:*:*:*     ) return 1 ;;
        ?*:?*:?*:?*:?*:?*:?*::  ) (( IPV6_FORBID_MINIMAL_EDGE &&
                                   ! IPV6_REQUIRE_MINIMAL_EDGE )) && return 1 ;;

        #
        # Valid if exactly 8 segments, all non-empty
        #   - re-check for too many colons, but this time invalid if 9 (or more) segments; otherwise
        #   - valid if 8 (or more) segments, all non-empty
        #

        *:*:*:*:*:*:*:*:*       )
    case $1 in
    esac

                                    return 1 ;;
        ?*:?*:?*:?*:?*:?*:?*:?* ) true  ;;

        #
        # Fewer than 8 segments can only be valid if there's an empty segment.
        #
        # But then the fun begins:

        #
        # The following are required by the standard when outputting IPv6
        # addresses, but they're not ambiguous, so there's no harm in accepting
        # them as input. But if you're paranoid, you can set IPV6_REQUIRE_MINIMAL=1
        # to disallow them.
        #
        #   - no leading zeroes within segments;
        #   - maximal compression (can't have :: followed or preceded by a 0 segment);
        #   - optimal compression (must compress the longest run of 0 segments exists, and where
        #       there's a choice, the first one);
        #
        # Detecting suboptimal compression is tricky; we can't just count the
        # colons and subtract from 7, because a leading or trailing ::
        # represents one more segment than an internal ::
        #
        #   0:0 without ::
        #   0 before trailing :: compressing 1 segment (leaving 8 colons)
        #       0:*:*:*:*:*:*::
        #       *:0:*:*:*:*:*::
        #       *:*:0:*:*:*:*::
        #       *:*:*:0:*:*:*::
        #       *:*:*:*:0:*:*::
        #       *:*:*:*:*:0:*::
        #
        #   0:0 before :: compressing 2 segments (leaving 7 segments, 6 colons)
        #       0:0:*:*:*:*:*
        #       ?*:0:0:*:*:*:*
        #       ?*:?*:0:0:*:*:*
        #
        #   0:0:0 before :: compressing 3 segments (leaving 6 segments, 5 colons)
        #       0:0:0:*:*:*:*
        #       ?*:0:0:0:*:*:*
        #
        #   0:0:0:0 anywhere
        #       *:0:0:0:0
        #       *:0:0:0:0:*
        #       0:0:0:0:*
        #
        #  Because we've already excluded 0 adjacent to a ::, we can then consider:
        #
        #

        *::* )
            local colons=${1//[!:]} ; colons=${#colons}
            case $1 in
                ::*

        #
        # Strict mode: forbid suboptimal compression
        #
        0[!:]*      | *:0[!:]*  | \
        0::*        | *:0::*    | \
        *::0        | *::0:*    ) (( IPV6_REQUIRE_MINIMAL )) && return 1 ;;&

        *:0:0:0:0               | \
        *:0:0:0:0:*             | \
        0:0:0:0:*               | \
        0:0:0:*:*:*             | \
        *:0:0:0:*:*             | \
        *:*:0:0:*:*:*           | \
        *:0:0:*:*:*:*           | \
        0:0:*:*:*:*:*           | \
        ) (( IPV6_REQUIRE_MINIMAL )) && return 1 ;;&
                                # If we get past all that, it's valid
                                true  ;;

        *                       ) false

    esac
}

#_END
