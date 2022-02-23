qdb() {
    QDB_DBTYPE='mysql' \
    QDB_DBNAME='quakers' \
    QDB_HOST='::1' \
    QDB_PORT=33020 \
    QDB_USER='quakers' \
    QDB_PASSFILE=/run/user/$UID/qdb_secret \
    "$@"
}

qdb6() {
    QDB_DBTYPE='mysql' \
    QDB_DBNAME='quakers_d6' \
    QDB_HOST='::1' \
    QDB_PORT=34021 \
    QDB_USER='quakers_d6' \
    QDB_PASSFILE=/run/user/$UID/qdb_secret \
    "$@"
}

(
    QDB_PASSFILE=/run/user/$UID/qdb_secret
    QDB_PASS='XVcWY9Syrg6qnFLu' 
    [[ -s "$QDB_PASSFILE" ]] || {
        mkdir -p "${QDB_PASSFILE%/*}"
        printf '%s\n' "$QDB_PASS" > "$QDB_PASSFILE"
        chmod 400 "$QDB_PASSFILE"
    }
)

_provides qdb qdb6
