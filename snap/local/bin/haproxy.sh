#!/bin/bash
set -euo pipefail

# HAProxy runs fully unprivileged; -W keeps the master in the foreground
# for snapd, and the config lives in the writable data dir so operators
# can edit it.
exec "${SNAP}/usr/bin/setpriv" --clear-groups --reuid snap_daemon --regid snap_daemon -- \
    "${SNAP}/usr/sbin/haproxy" -W -f "${SNAP_DATA}/etc/haproxy/haproxy.cfg"
