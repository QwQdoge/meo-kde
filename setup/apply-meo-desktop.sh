#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
desktop_root="${repo_root}"
config_root="${XDG_CONFIG_HOME:-${HOME}/.config}"
data_root="${XDG_DATA_HOME:-${HOME}/.local/share}"
qml_root="${MEO_KDE_QML_ROOT:-${HOME}/.local/share/meo-kde/qml}"
meoui_source="${MEOUI_QML_SOURCE:-${repo_root}/../meo-ui/out/build/release/MeoUI}"
native_build_root="${repo_root}/out/build/native"
state_root="${XDG_STATE_HOME:-${HOME}/.local/state}/meo-desktop"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_root="${state_root}/backups/${timestamp}"
dry_run=0
reset_layout=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=1 ;;
    --reset-layout) reset_layout=1 ;;
    *) echo "Usage: $0 [--dry-run] [--reset-layout]" >&2; exit 2 ;;
  esac
  shift
done

run() {
  printf '%q ' "$@"
  printf '\n'
  if [ "${dry_run}" -eq 0 ]; then
    "$@"
  fi
}

for required in \
  "${desktop_root}/themes/look-and-feel/org.meo.desktop/metadata.json" \
  "${desktop_root}/themes/desktoptheme/MeoLight/metadata.json" \
  "${desktop_root}/themes/desktoptheme/MeoDark/metadata.json" \
  "${desktop_root}/themes/icons/MeoSymbols/index.theme" \
  "${desktop_root}/themes/icons/MeoSymbolsDark/index.theme" \
  "${repo_root}/qml/MeoKDE/qmldir" \
  "${meoui_source}/qmldir" \
  "${repo_root}/assets/wallpapers/installer_background.png"; do
  if [ ! -f "${required}" ]; then
    echo "Required Meo Desktop asset is missing: ${required}" >&2
    exit 1
  fi
done

run mkdir -p "${backup_root}" "${data_root}/color-schemes" "${data_root}/plasma/look-and-feel" "${data_root}/plasma/desktoptheme" "${data_root}/plasma/plasmoids" "${data_root}/icons" "${data_root}/wallpapers/MeoArch" "${data_root}/fonts/meo" "${qml_root}/MeoKDE" "${qml_root}/MeoUI" "${config_root}/fontconfig/conf.d" "${config_root}/environment.d"

for config in kdeglobals kwinrc plasmarc plasma-org.kde.plasma.desktop-appletsrc; do
  if [ -e "${config_root}/${config}" ]; then
    run cp -a "${config_root}/${config}" "${backup_root}/${config}"
  fi
done

# Install Look-and-Feel package
run rm -rf "${data_root}/plasma/look-and-feel/org.meo.desktop"
run cp -a "${desktop_root}/themes/look-and-feel/org.meo.desktop" "${data_root}/plasma/look-and-feel/org.meo.desktop"
for desktop_theme in MeoLight MeoDark; do
  run rm -rf "${data_root}/plasma/desktoptheme/${desktop_theme}"
  run cp -a "${desktop_root}/themes/desktoptheme/${desktop_theme}" "${data_root}/plasma/desktoptheme/${desktop_theme}"
done
run cp -a "${desktop_root}/themes/color-schemes/." "${data_root}/color-schemes/"
for icon_theme in MeoSymbols MeoSymbolsDark; do
  run rm -rf "${data_root}/icons/${icon_theme}"
  run cp -a "${desktop_root}/themes/icons/${icon_theme}" "${data_root}/icons/${icon_theme}"
done

# Install Meo Plasmoids (Shelf, TopBar, Launcher, QuickSettings)
for legacy_plasmoid in org.meo.launcher org.meo.quicksettings; do
  run rm -rf "${data_root}/plasma/plasmoids/${legacy_plasmoid}"
done
for plasmoid in org.meo.shelf org.meo.topbar; do
  if [ -d "${desktop_root}/plasmoids/${plasmoid}" ]; then
    run rm -rf "${data_root}/plasma/plasmoids/${plasmoid}"
    run cp -a "${desktop_root}/plasmoids/${plasmoid}" "${data_root}/plasma/plasmoids/${plasmoid}"
  fi
done

run cp -a "${meoui_source}/." "${qml_root}/MeoUI/"
run cp -a "${repo_root}/qml/MeoKDE/." "${qml_root}/MeoKDE/"
run cmake -S "${repo_root}/native" -B "${native_build_root}" -DCMAKE_BUILD_TYPE=RelWithDebInfo
run cmake --build "${native_build_root}" --parallel
if [ "${dry_run}" -eq 0 ]; then
  if [ "$(id -u)" -eq 0 ]; then
    cmake --install "${native_build_root}"
  elif command -v pkexec >/dev/null 2>&1; then
    pkexec cmake --install "${native_build_root}"
  else
    echo "Native KWin plugins need a privileged install. Re-run this script as root or install ${native_build_root} with cmake --install." >&2
    exit 1
  fi
fi
run mkdir -p "${qml_root}/Meo/System"
if [ -d "${native_build_root}/qml/Meo/System" ]; then
  run cp -a "${native_build_root}/qml/Meo/System/." "${qml_root}/Meo/System/"
fi
if command -v kwriteconfig6 >/dev/null 2>&1; then
  run kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library "org.meo.decoration"
  run kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme "org.meo.decoration"
  run kwriteconfig6 --file kwinrc --group Plugins --key org.meo.windowcornersEnabled true
  run kwriteconfig6 --file kwinrc --group "org.meo.decoration" --key TitleBarHeight 36
  run kwriteconfig6 --file kwinrc --group "org.meo.decoration" --key CornerRadius 14
  run kwriteconfig6 --file kwinrc --group "org.meo.decoration" --key ButtonDiameter 13
  run kwriteconfig6 --file kwinrc --group "org.meo.decoration" --key ButtonHitSize 26
  run kwriteconfig6 --file kwinrc --group "org.meo.decoration" --key ButtonSpacing 7
  run kwriteconfig6 --file kwinrc --group "org.meo.decoration" --key AlignTitleCenter true
  run kwriteconfig6 --file kwinrc --group "org.meo.decoration" --key EnableAccentTint true
  run kwriteconfig6 --file kwinrc --group "org.meo.decoration" --key EnableCompanionEffect true
fi

if [ "${dry_run}" -eq 0 ] && command -v qdbus6 >/dev/null 2>&1; then
  qdbus6 org.kde.KWin /KWin reconfigure
fi
run cp -a "${repo_root}/assets/fonts/." "${data_root}/fonts/meo/"
run cp -a "${repo_root}/defaults/fonts/50-meo-fonts.conf" "${config_root}/fontconfig/conf.d/50-meo-fonts.conf"
run cp -a "${repo_root}/defaults/environment/90-meo-kde.conf" "${config_root}/environment.d/90-meo-kde.conf"

if command -v systemctl >/dev/null 2>&1; then
  run systemctl --user set-environment "QML_IMPORT_PATH=${qml_root}" "QML2_IMPORT_PATH=${qml_root}"
fi

run cp -a "${repo_root}/assets/wallpapers/installer_background.png" "${data_root}/wallpapers/MeoArch/installer_background.png"
if command -v fc-cache >/dev/null 2>&1; then
  run fc-cache -f "${data_root}/fonts/meo"
fi

if [ "${dry_run}" -eq 0 ]; then
  printf '%s\n' "${backup_root}" > "${state_root}/last-backup"
fi

if command -v plasma-apply-lookandfeel >/dev/null 2>&1; then
  if [ "${reset_layout}" -eq 1 ]; then
    run plasma-apply-lookandfeel -a org.meo.desktop --resetLayout
  else
    run plasma-apply-lookandfeel -a org.meo.desktop
  fi
elif command -v lookandfeeltool >/dev/null 2>&1; then
  run lookandfeeltool -a org.meo.desktop
else
  echo "Plasma look-and-feel tool is unavailable; files were staged for the next Plasma login." >&2
fi

if [ "${reset_layout}" -eq 1 ] && command -v systemctl >/dev/null 2>&1; then
  run systemctl --user restart plasma-plasmashell.service
fi
