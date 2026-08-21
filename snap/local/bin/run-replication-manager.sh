#!/bin/bash
set -euo pipefail

# replication_manager.sh drives the local mysql client; run as the
# invoking user so auth_socket sees the real uid.
export PATH="${SNAP}/usr/bin:${PATH}"
exec "${SNAP}/usr/bin/replication_manager.sh" "$@"
