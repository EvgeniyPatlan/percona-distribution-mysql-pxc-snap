#!/bin/bash

set -eo pipefail  # Exit on error

# ProxySQL daemon wrapper: run in the foreground for snapd supervision.
# Datadir and interfaces come from the config the install hook renders to
# $SNAP_DATA/etc/proxysql/proxysql.cnf (admin 0.0.0.0:6032, proxy
# 0.0.0.0:6033). It lives in its own subdirectory, not directly in
# $SNAP_DATA/etc, because mysqld's "!includedir $SNAP_DATA/etc" would
# otherwise try (and fail) to parse it as a mysqld ini-style config.
exec "${SNAP}/usr/bin/setpriv" \
    --clear-groups \
    --reuid snap_daemon \
    --regid snap_daemon \
    -- \
    "${SNAP}/usr/bin/proxysql" -f --idle-threads -c "${SNAP_DATA}/etc/proxysql/proxysql.cnf"
