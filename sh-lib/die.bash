function die {
    local _e EX_OK=0 \
             EX_USAGE=64 EX_DATAERR=65 EX_NOINPUT=66 EX_NOUSER=67 EX_NOHOST=68 \
             EX_UNAVAILABLE=69 EX_SOFTWARE=70 EX_OSERR=71 EX_OSFILE=72 EX_CANTCREAT=73 \
             EX_IOERR=74 EX_TEMPFAIL=75 EX_PROTOCOL=76 EX_NOPERM=77 EX_CONFIG=78 \
             EX_NOEXEC=127
    let _e=$1
    shift
    echo >&2 "$@"
    exit $_e
}
_provides die
