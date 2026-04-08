#!/module/for/bash

# Declare constants using
#
# Use as:
#   eval "$( const foo=1 bar=2 zot=3 )"
# or
#   . < <( const foo=1 bar=2 zot=3 )

iconst() {
    local _v _w _x _y=0 _i=-i
    for _x do
        case $_x in
        -i) _i=-i ;;
        +i) _i= ;;
        *)
            _v=${_x%%=*}
            _w=${_x#"$_v"} _w=${_w#=}
            [[ ${!_v+X} ]] && continue   # same as [[ -v $_v ]] but works for older Bash
            printf 'readonly %s %s=%q\n' "$_i" "$_v" "$_w"
            ;;
        esac
    done
}

_provides iconst
