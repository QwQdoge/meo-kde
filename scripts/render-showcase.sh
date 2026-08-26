#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
meoui_import="${MEOUI_IMPORT_ROOT:-/home/shekong/Projects/meo-ui/out/build/release}"
output_root="${MEO_OUTPUT_ROOT:-/home/shekong/Projects/outputs}"
showcase_run_id="${MEO_KDE_SHOWCASE_RUN_ID:-$(date -u +%Y-%m-%dT%H%M%SZ)-showcase}"
output="${1:-${output_root}/meo-kde/validation/${showcase_run_id}/meo-kde-desktop.png}"

if [ ! -f "${meoui_import}/MeoUI/qmldir" ]; then
  echo "MeoUI build not found at ${meoui_import}" >&2
  exit 1
fi

mkdir -p "$(dirname "${output}")"
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" \
  qml6 -I "${meoui_import}" -I "${repo_root}/qml" \
  "${repo_root}/showcase/DesktopShowcase.qml" "--snapshot=${output}"
test -s "${output}"
echo "Rendered ${output}"
