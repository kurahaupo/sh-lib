qdb() {
    if [[ ! $QDB_d7_passfile ]]
    then
        QDB_d7_passfile=/run/user/$UID/qdb_secret
    fi
    if [[ ! -e $QDB_d7_passfile
         || -w $QDB_d7_passfile
         || -z $QDB_d7_dbtype
         || -z $QDB_d7_dbname
         || -z $QDB_d7_port
         || -z $QDB_d7_user
       ]]
    then
        local php='
              require "/srv/www/sites/default/settings.php";
              $d = $databases["default"]["default"];
              printf("QDB_d7_dbtype=%s\n", $d["driver"]);
              printf("QDB_d7_rhost=%s\n",  $d["host"]);
              printf("QDB_d7_port=%s\n",   $d["port"]);
              printf("QDB_d7_dbname=%s\n", $d["database"]);
              printf("QDB_d7_user=%s\n",   $d["username"]);
              printf("QDB_d7_pass=%s\n",   $d["password"]);
        '
        php="$( ssh -T quakers.nz "php -r '$php'" )" &&
         eval "$php" &&
          printf '%s' "$QDB_d7_pass" >| "$QDB_d7_passfile.new~$$~" &&
           chmod 400 "$QDB_d7_passfile.new~$$~" &&
            mv -Tf "$QDB_d7_passfile.new~$$~" "$QDB_d7_passfile" || {
              rm -f "$QDB_d7_passfile" "$QDB_d7_passfile.new~$$~"
              unset QDB_d7_dbtype QDB_d7_dbname QDB_d7_port QDB_d7_user QDB_d7_pass QDB_d7_passfile
              return
             }
        QDB_d7_host=::1
    fi
    unset QDB_d7_pass
    case $* in
     --set) ;;
     --export)
        export QDB_d7_dbtype \
               QDB_d7_dbname \
               QDB_d7_host \
               QDB_d7_port \
               QDB_d7_user \
               QDB_d7_passfile ;;
     -*)
        printf >&2 'qdb: invalid option "%s"\n' "$*"
        return 64 ;;
     *)
        QDB_DBTYPE=$QDB_d7_dbtype \
        QDB_DBNAME=$QDB_d7_dbname \
        QDB_HOST=$QDB_d7_host \
        QDB_PORT=$QDB_d7_port \
        QDB_USER=$QDB_d7_user \
        QDB_PASSFILE=$QDB_d7_passfile \
        "$@"
    esac
}

qdb6() {
    if [[ ! $QDB_d6_passfile ]]
    then
        QDB_d6_passfile=/run/user/$UID/qdb_secret6
    fi
    if [[ ! -e $QDB_d6_passfile
         || -w $QDB_d6_passfile
         || -z $QDB_d6_dbtype
         || -z $QDB_d6_dbname
         || -z $QDB_d6_port
         || -z $QDB_d6_user
       ]]
    then
        # $db_url['default'] = 'mysql://quakers_d6:PASSWORD@' . MARIADB_10G_LB_ADDR . ':' . MARIADB_10G_LB_PORT .'/quakers_d6';
        local php='
              require "/srv/www/sites/default/settings.php";
              $d = $db_url["default"];
              printf("QDB_d6_url=%s\n", $d);
        '
        php="$( ssh -T quaker.org.nz "php -r '$php'" )" &&
         eval "$php" && {
           QDB_d6_dbtype=${QDB_d6_url%%://*}  QDB_d6_url=${QDB_d6_url#*://}
           QDB_d6_dbname=${QDB_d6_url##*/}    QDB_d6_url=${QDB_d6_url%/*}
           QDB_d6_rlink=${QDB_d6_url#*@}      QDB_d6_url=${QDB_d6_url%@*}
           QDB_d6_unpw=$QDB_d6_url
               QDB_d6_rhost=${QDB_d6_rlink%:*}
               QDB_d6_port=${QDB_d6_rlink##*:}
           QDB_d6_user=${QDB_d6_unpw%:*}
           QDB_d6_pass=${QDB_d6_unpw#*:}
           unset QDB_d6_rlink QDB_d6_unpw QDB_d6_url
          } &&
           printf '%s' "$QDB_d6_pass" >| "$QDB_d6_passfile.new~$$~" &&
            chmod 400 "$QDB_d6_passfile.new~$$~" &&
             mv -Tf "$QDB_d6_passfile.new~$$~" "$QDB_d6_passfile" || {
               rm -f "$QDB_d6_passfile" "$QDB_d6_passfile.new~$$~"
               unset QDB_d6_dbtype QDB_d6_dbname QDB_d6_port QDB_d6_user QDB_d6_pass QDB_d6_passfile
               return
              }
        QDB_d6_host=::1
    fi
    unset QDB_d6_pass
    case $* in
     --set) ;;
     --export)
        export QDB_d6_dbtype \
               QDB_d6_dbname \
               QDB_d6_host \
               QDB_d6_port \
               QDB_d6_user \
               QDB_d6_passfile ;;
     -*)
        printf >&2 'qdb6: invalid option "%s"\n' "$*"
        return 64 ;;
     *)
        QDB_DBTYPE=$QDB_d6_dbtype \
        QDB_DBNAME=$QDB_d6_dbname \
        QDB_HOST=$QDB_d6_host \
        QDB_PORT=$QDB_d6_port \
        QDB_USER=$QDB_d6_user \
        QDB_PASSFILE=$QDB_d6_passfile \
        "$@"
    esac
}

_provides qdb qdb6
