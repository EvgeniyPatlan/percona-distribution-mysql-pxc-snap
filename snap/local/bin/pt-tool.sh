#!/bin/bash
set -euo pipefail

# Shared launcher for the percona-toolkit pt-* apps: each snapcraft app
# entry passes the tool name as the first argument. Tools run as the
# invoking user (client-side utilities; auth_socket needs the real uid).
TOOL="$1"
shift

# core26 ships no perl, so the toolkit's interpreter and modules are
# staged inside the snap. Globs keep this independent of the exact perl
# version directory.
plib=""
for d in "${SNAP}"/usr/lib/*/perl-base \
         "${SNAP}"/usr/lib/*/perl5/* \
         "${SNAP}"/usr/share/perl5 \
         "${SNAP}"/usr/lib/*/perl/* \
         "${SNAP}"/usr/share/perl/*; do
    [ -d "${d}" ] && plib="${plib:+${plib}:}${d}"
done
export PERL5LIB="${plib}${PERL5LIB:+:${PERL5LIB}}"
export PATH="${SNAP}/usr/bin:${SNAP}/usr/sbin:${PATH}"

exec "${SNAP}/usr/bin/${TOOL}" "$@"
