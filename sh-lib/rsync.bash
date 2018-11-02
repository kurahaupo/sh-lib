
rsync() {
    echo >&2 "# using shell alias 'rsync -aHv --exclude-from=$HOME/.rsync-exclude ...'"
    command rsync -aHv --exclude-from=$HOME/.rsync-exclude "$@"
}

_provides rsync
