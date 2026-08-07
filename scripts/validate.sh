#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
meoui_import="${MEOUI_IMPORT_ROOT:-/home/shekong/Projects/meo-ui/out/build/release}"
system_import="${repo_root}/out/build/system/qml"
evidence_root="${MEO_KDE_EVIDENCE_ROOT:-/home/shekong/Projects/outputs/evidence/meo-kde}"
log_root="${evidence_root}/logs"
mkdir -p "${log_root}"
log_file="${log_root}/validate.log"
: > "${log_file}"

run() {
  printf '+ ' | tee -a "${log_file}"
  printf '%q ' "$@" | tee -a "${log_file}"
  printf '\n' | tee -a "${log_file}"
  "$@" 2>&1 | tee -a "${log_file}"
}

run bash -n "${repo_root}/setup/apply-meo-desktop.sh"
run bash -n "${repo_root}/setup/reset-meo-desktop.sh"
run bash -n "${repo_root}/scripts/sync-to-workspace.sh"
run python -m configparser "${repo_root}/themes/icons/MeoSymbols/index.theme"
run python "${repo_root}/tools/icons/build_icon_theme.py" --check
run python -m unittest "${repo_root}/tests/icons/test_theme.py"
run python "${repo_root}/tools/icons/audit_icon_coverage.py"
run python -m unittest "${repo_root}/tests/theme/test_color_schemes.py"
run cmake -S "${repo_root}/native/system" -B "${repo_root}/out/build/system" -DCMAKE_BUILD_TYPE=RelWithDebInfo
run cmake --build "${repo_root}/out/build/system" --parallel
run "${repo_root}/out/build/system/meo-system-state-smoke"

while IFS= read -r metadata; do
  run python -m json.tool "${metadata}"
done < <(find "${repo_root}/plasmoids" "${repo_root}/themes" -name metadata.json -type f | sort)

while IFS= read -r qml_file; do
  run qmllint -I "${meoui_import}" -I "${repo_root}/qml" -I "${system_import}" -I /usr/lib/qt6/qml "${qml_file}"
done < <(find "${repo_root}/plasmoids" "${repo_root}/qml" -name '*.qml' -type f | sort)

while IFS= read -r svg_file; do
  run xmllint --noout "${svg_file}"
done < <(find "${repo_root}/icons" "${repo_root}/themes/desktoptheme" -name '*.svg' -type f | sort)

if rg -n 'property bool isOn:|onClicked: parent\.isOn = !parent\.isOn' "${repo_root}/plasmoids"; then
  echo "Fake local system toggle detected" | tee -a "${log_file}" >&2
  exit 1
fi

echo "Meo KDE static validation passed" | tee -a "${log_file}"
