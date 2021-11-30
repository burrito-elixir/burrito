ROOTDIR="$ERL_ROOTDIR"

if [ -z "$RELDIR" ]
then
  RELDIR=$ROOTDIR/releases
fi

START_ERL_DATA=${1:-$RELDIR/start_erl.data}

$ROOTDIR/bin/run_erl -daemon /tmp/ $ROOTDIR/log "exec $ROOTDIR/bin/start_erl $ROOTDIR $RELDIR $START_ERL_DATA"