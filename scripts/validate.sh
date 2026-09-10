#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
meoui_import="${MEOUI_IMPORT_ROOT:-/home/shekong/Projects/meo-ui/out/build/release}"
meoui_source="${MEOUI_SOURCE_DIR:-/home/shekong/Projects/meo-ui}"
validation_run_id="${MEO_KDE_VALIDATION_RUN_ID:-$(date -u +%Y-%m-%dT%H%M%SZ)-validate}"
output_root="${MEO_OUTPUT_ROOT:-/home/shekong/Projects/outputs}"
evidence_root="${MEO_KDE_EVIDENCE_ROOT:-${output_root}/meo-kde/validation/${validation_run_id}}"
build_root="${MEO_KDE_BUILD_ROOT:-${output_root}/meo-kde/build/${validation_run_id}}"
system_build="${build_root}/system"
application_style_build="${build_root}/application-style"
system_import="${system_build}/qml"
log_root="${evidence_root}/logs"
screenshot_root="${evidence_root}/screenshots"
mkdir -p "${log_root}" "${screenshot_root}"
log_file="${log_root}/validate.log"
: > "${log_file}"
printf 'Validation evidence: %s\n' "${evidence_root}" | tee -a "${log_file}"

run() {
  printf '+ ' | tee -a "${log_file}"
  printf '%q ' "$@" | tee -a "${log_file}"
  printf '\n' | tee -a "${log_file}"
  "$@" 2>&1 | tee -a "${log_file}"
}

run bash -n "${repo_root}/setup/apply-meo-desktop.sh"
run bash -n "${repo_root}/setup/reset-meo-desktop.sh"
run bash -n "${repo_root}/scripts/sync-to-workspace.sh"
run bash -n "${repo_root}/tools/input-method/meo-input-method.sh"
run bash -n "${repo_root}/tools/theme/apply-meo-mode.sh"
run bash -n "${repo_root}/tools/theme/apply-meo-desktop.sh"
run bash -n "${repo_root}/tools/shell/apply-meo-panel-layout.sh"
run python -m configparser "${repo_root}/themes/icons/MeoSymbols/index.theme"
run python "${repo_root}/tools/icons/build_icon_theme.py" --check
run python -m unittest discover -s "${repo_root}/tests/icons" -p 'test_*.py'
run python "${repo_root}/tools/icons/audit_icon_coverage.py" \
  --output "${evidence_root}/metrics/icon-usage-audit.json"
run python -m unittest discover -s "${repo_root}/tests/theme" -p 'test_*.py'
run python -m unittest discover -s "${repo_root}/tests/input_method" -p 'test_*.py'
run python -m unittest discover -s "${repo_root}/tests/system" -p 'test_*.py'
run python -m unittest discover -s "${repo_root}/tests/shell" -p 'test_*.py'
run python -m unittest discover -s "${repo_root}/tests/widgets" -p 'test_*.py'
run python -m unittest discover -s "${repo_root}/tests/authentication" -p 'test_*.py'
run python "${meoui_source}/tools/verify-design-system-usage.py" --mode consumer \
  "${repo_root}/qml" "${repo_root}/plasmoids" \
  "${repo_root}/native/dock/qml" "${repo_root}/native/authentication/qml" \
  "${repo_root}/themes/look-and-feel"
run cmake -S "${repo_root}/native/system" -B "${system_build}" -DCMAKE_BUILD_TYPE=RelWithDebInfo
run cmake --build "${system_build}" --parallel
run test -s "${system_import}/Meo/System/plugins.qmltypes"
run "${system_build}/meo-system-state-smoke"
run cmake -S "${repo_root}/native" -B "${application_style_build}" \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo -DMEOUI_SOURCE_DIR="${meoui_source}" \
  -DMEOUI_IMPORT_ROOT_PATH="${meoui_import}" -DMEO_BUILD_STANDALONE_DOCK=OFF
run cmake --build "${application_style_build}" --parallel
run ctest --test-dir "${application_style_build}" --output-on-failure
run env -u QML_IMPORT_PATH -u QML2_IMPORT_PATH QT_QPA_PLATFORM=offscreen QT_STYLE_OVERRIDE=Fusion QT_QUICK_CONTROLS_STYLE=Basic \
  qmlscene6 -I "${meoui_import}" -I "${repo_root}/qml" -I "${system_import}" \
  "${repo_root}/validation/theme-runtime-smoke.qml"
run env -u QML_IMPORT_PATH -u QML2_IMPORT_PATH QT_QPA_PLATFORM=offscreen QT_STYLE_OVERRIDE=Fusion QT_QUICK_CONTROLS_STYLE=Basic \
  qmlscene6 -I "${meoui_import}" -I "${repo_root}/qml" -I "${system_import}" \
  "${repo_root}/validation/meoui-shell-components-smoke.qml"
run env -u QML_IMPORT_PATH -u QML2_IMPORT_PATH QT_QPA_PLATFORM=offscreen QT_STYLE_OVERRIDE=Fusion QT_QUICK_CONTROLS_STYLE=Basic \
  qmlscene6 -I "${meoui_import}" -I "${repo_root}/qml" -I "${system_import}" \
  "${repo_root}/validation/notification-center-smoke.qml" \
  "--snapshot=${screenshot_root}/notification-center.png"
run env -u QML_IMPORT_PATH -u QML2_IMPORT_PATH QT_QPA_PLATFORM=offscreen QT_STYLE_OVERRIDE=Fusion QT_QUICK_CONTROLS_STYLE=Basic \
  qmlscene6 -I "${meoui_import}" -I "${repo_root}/qml" -I "${system_import}" \
  "${repo_root}/validation/notification-disclosure-smoke.qml" \
  "--expand" "--snapshot=${screenshot_root}/notification-disclosure-expanded.png"
run env -u QML_IMPORT_PATH -u QML2_IMPORT_PATH QT_QPA_PLATFORM=offscreen QT_STYLE_OVERRIDE=Fusion QT_QUICK_CONTROLS_STYLE=Basic \
  qmlscene6 -I "${meoui_import}" -I "${repo_root}/qml" -I "${system_import}" \
  "${repo_root}/validation/status-center-smoke.qml" \
  "--snapshot=${screenshot_root}/status-center.png"
run env -u QML_IMPORT_PATH -u QML2_IMPORT_PATH QT_QPA_PLATFORM=offscreen QT_STYLE_OVERRIDE=Fusion QT_QUICK_CONTROLS_STYLE=Basic \
  qmlscene6 -I "${meoui_import}" -I "${repo_root}/qml" -I "${system_import}" \
  "${repo_root}/validation/quick-settings-smoke.qml" \
  "--snapshot=${screenshot_root}/quick-settings.png"
run env -u QML_IMPORT_PATH -u QML2_IMPORT_PATH QT_QPA_PLATFORM=offscreen QT_STYLE_OVERRIDE=Fusion QT_QUICK_CONTROLS_STYLE=Basic \
  qmlscene6 -I "${meoui_import}" -I "${repo_root}/qml" -I "${system_import}" \
  "${repo_root}/validation/quick-settings-page-smoke.qml" \
  "--snapshot=${screenshot_root}/quick-settings-page.png"
run env -u QML_IMPORT_PATH -u QML2_IMPORT_PATH QT_QPA_PLATFORM=offscreen QT_STYLE_OVERRIDE=Fusion QT_QUICK_CONTROLS_STYLE=Basic \
  qmlscene6 -I "${meoui_import}" -I "${repo_root}/qml" -I "${system_import}" \
  "${repo_root}/validation/quick-settings-customization-smoke.qml" \
  "--snapshot=${screenshot_root}/quick-settings-customization.png"
run env -u QML_IMPORT_PATH -u QML2_IMPORT_PATH QT_QPA_PLATFORM=offscreen QT_STYLE_OVERRIDE=Fusion QT_QUICK_CONTROLS_STYLE=Basic \
  qmlscene6 -I "${meoui_import}" -I "${repo_root}/qml" \
  "${repo_root}/validation/authentication-dialog-smoke.qml"
for desktop_theme in MeoLight MeoDark; do
  run env -u QML_IMPORT_PATH -u QML2_IMPORT_PATH QT_QPA_PLATFORM=offscreen QT_STYLE_OVERRIDE=Fusion QT_QUICK_CONTROLS_STYLE=Basic \
    qmlscene6 "${repo_root}/validation/native-dock-frame-smoke.qml" \
    "--theme-root=${repo_root}/themes/desktoptheme/${desktop_theme}"
done

while IFS= read -r metadata; do
  run python -m json.tool "${metadata}"
done < <(find "${repo_root}/plasmoids" "${repo_root}/themes" -name metadata.json -type f | sort)

qt6_qmllint="${QT6_QMLLINT:-/usr/lib/qt6/bin/qmllint}"
[ -x "${qt6_qmllint}" ] || {
  echo "Qt 6 qmllint is required for QML validation: ${qt6_qmllint}" | tee -a "${log_file}" >&2
  exit 1
}

while IFS= read -r qml_file; do
  run "${qt6_qmllint}" -i "${system_import}/Meo/System/qmldir" \
    -I "${meoui_import}" -I "${repo_root}/qml" -I "${system_import}" "${qml_file}"
done < <(find "${repo_root}/plasmoids" "${repo_root}/qml" \
  "${repo_root}/native/authentication/qml" \
  -name '*.qml' -type f | sort)

while IFS= read -r svg_file; do
  run xmllint --noout "${svg_file}"
done < <(find "${repo_root}/icons" "${repo_root}/themes/desktoptheme" -name '*.svg' -type f | sort)

if rg -n 'property bool isOn:|onClicked: parent\.isOn = !parent\.isOn' "${repo_root}/plasmoids"; then
  echo "Fake local system toggle detected" | tee -a "${log_file}" >&2
  exit 1
fi

echo "Meo KDE static validation passed" | tee -a "${log_file}"
