#!/bin/bash

set -eo pipefail  # Exit on error

# ProxySQL daemon wrapper: run in the foreground for snapd supervision.
# Datadir and interfaces come from the config the install hook renders to
# $SNAP_DATA/etc/proxysql.cnf (admin 0.0.0.0:6032, proxy 0.0.0.0:6033).
exec "${SNAP}/usr/bin/setpriv" \
    --clear-groups \
    --reuid snap_daemon \
    --regid snap_daemon \
    -- \
    "${SNAP}/usr/bin/proxysql" -f --idle-threads -c "${SNAP_DATA}/etc/proxysql.cnf"
