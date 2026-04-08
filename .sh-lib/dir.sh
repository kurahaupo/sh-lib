
dir() {
    if (($#))
    then gitwarn --suggest 'ls ' --why='is stupid' -- dir "$@"
    else gitwarn --suggest='dirs ' --why='is probably a typo' --  dir
    fi
}

_provides dir
