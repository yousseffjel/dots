#!/usr/bin/env bash
# TEMPLATE migration — 0.1.0 -> 0.2.0.
#
# Run once by scripts/migrate.sh when an existing install's manifest
# version is 0.1.0 and the repo's VERSION has moved on to 0.2.0. On
# success, migrate.sh advances the manifest's recorded version to 0.2.0
# for you — do not update the manifest from inside a migration script.
#
# This one is a no-op (nothing has changed between 0.1.0 and 0.2.0 yet).
# Copy this file's shape for the next real migration:
#   1. Name it exactly <from-version>-to-<to-version>.sh, matching
#      whatever the previous VERSION bump actually was.
#   2. Make every step idempotent — migrate.sh may re-run a migration
#      whose manifest-version bump didn't land (e.g. the process was
#      killed mid-run).
#   3. Fail loudly (non-zero exit) on unexpected state instead of
#      guessing — migrate.sh stops the whole chain on the first failure
#      and leaves the manifest pinned at the last version it fully reached.
#   4. Source global_fn.sh if you need confirm()/manifest_*/logging:
#        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#        source "$SCRIPT_DIR/../global_fn.sh"
#   5. Delete this file once a real 0.1.0-to-0.2.0 migration replaces it,
#      or once 0.2.0 ships without ever needing one.

set -euo pipefail

echo "0.1.0 -> 0.2.0: nothing to do (template migration)"
