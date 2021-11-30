#!/bin/sh
SELF=$(readlink "$0" || true)
if [ -z "$SELF" ]; then SELF="$0"; fi
BINDIR="$(cd "$(dirname "$SELF")" && pwd -P)"
ROOTDIR="${ERL_ROOTDIR:-"$(dirname "$(dirname "$BINDIR")")"}"
EMU=beam
export EMU
export ROOTDIR
export BINDIR
exec "$BINDIR/erlexec" ${1+"$@"}