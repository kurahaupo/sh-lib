unalias which
which() {
    printf '# WARNING: whichcraft is evil; use "type -a" instead\n'
    type -a "$@"
    return 64
}
_provides which
