#!/usr/bin/env bash
set -euo pipefail

workspace="${1:-/home/shekong/Projects/meo-arch-os-workspace}"
workspace_sync="${workspace}/scripts/sync-installer-to-airootfs.sh"

if [ ! -d "${workspace}/meoarch-os" ] || [ ! -x "${workspace_sync}" ]; then
  echo "Not a MeoArch ISO workspace: ${workspace}" >&2
  exit 2
fi

# The workspace owns ISO staging and its provenance gate. Keep this compatibility
# entrypoint as a delegation instead of maintaining a second, stale copy path.
exec "${workspace_sync}"
