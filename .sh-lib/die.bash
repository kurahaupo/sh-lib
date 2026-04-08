require cluck

function die  { cluck -Dq "$@" ;}
function dief { cluck -Dq "$@" ;}

_provides die
_provides dief
