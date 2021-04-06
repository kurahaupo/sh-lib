#!/module/for/bash

# This function takes a command as its argument, and runs it with the

# Warn the user if they didn't run the script with `source`
[[ "${BASH_SOURCE[0]}" != "${0}" ]] ||
   echo >&2 'WARNING: You should source this script to ensure the resulting environment variables get set.'

ffcookies() {
    # Extract Google Takeout cookies from Mozilla Firefox and export them as envvars
    #
    # The browser must have visited https://takeout.google.com as an authenticated user.

    # I run Google services in container #6; this may change without notice.
    local moz_user_context_id=6
    local ffh=$HOME/.mozilla/firefox

    # In case the cookie database is locked, copy the database to a temporary file.
    # Edit the $firefox_profile variable below to select a specific Firefox profile.
    firefox_profile=$(
        sed -nr '
            :a
                /^\[Install[[:xdigit:]]*\]/ !d
            :i
                n
                /^\[/ba
                /^Default=/bq
                bi
            :q
                s///
                p
                q
        ' "$ffh/profiles.ini"
    )
    case $firefox_profile in
        /*) ;;
        *)  firefox_profile=$ffh/$firefox_profile ;;
    esac

    # Make a copy of the cookie jar, since Mozilla locks it while running.
    local cookie_jar=/run/user/$UID/ffcookies/cookies.sqlite
    local ff_temp_dir=
    mkdir -vp "${cookie_jar%/*}"
    cp "$firefox_profile/cookies.sqlite" "$cookie_jar"

    # Load the cookie values into environment variables
    local cookie_eval
    cookie_eval=$(
        # Get the cookies from the database
        sqlite3 "$cookie_jar" \
               "select name||'='||value||'   # host='||host||'  originAttributes='||originAttributes
                  from moz_cookies
                 where host like '%.google.com'
                   and name in ('SID', 'HSID', 'OSID', 'SSID')
                   and (host  = 'takeout.google.com'
                     or name != 'OSID')
                   and originAttributes = '^userContextId=$moz_user_context_id'
              order by creationTime asc;"
    ) || return
    rm -rf "$cookie_jar"
    if (($#)) ; then
        local -x SID HSID OSID SSID
        eval "$cookie_eval"
        "$@"
    else
        echo "$cookie_eval"
    fi
}

_provides ffcookies
