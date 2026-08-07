#!/usr/bin/env bash
set -euo pipefail

config_root="${XDG_CONFIG_HOME:-${HOME}/.config}"
data_root="${XDG_DATA_HOME:-${HOME}/.local/share}"
qml_root="${MEO_KDE_QML_ROOT:-${HOME}/.local/share/meo-kde/qml}"
state_root="${XDG_STATE_HOME:-${HOME}/.local/state}/meo-desktop"
marker="${state_root}/last-backup"
dry_run=0

if [ "${1:-}" = "--dry-run" ]; then
  dry_run=1
elif [ "$#" -gt 0 ]; then
  echo "Usage: $0 [--dry-run]" >&2
  exit 2
fi

if [ ! -s "${marker}" ]; then
  echo "No Meo Desktop backup marker exists; nothing was changed." >&2
  exit 1
fi
backup_root="$(<"${marker}")"
case "${backup_root}" in
  "${state_root}"/backups/*) ;;
  *) echo "Refusing unsafe backup path: ${backup_root}" >&2; exit 1 ;;
esac
if [ ! -d "${backup_root}" ]; then
  echo "Backup directory no longer exists: ${backup_root}" >&2
  exit 1
fi

run() {
  printf '%q ' "$@"
  printf '\n'
  if [ "${dry_run}" -eq 0 ]; then
    "$@"
  fi
}

for config in kdeglobals kwinrc plasmarc plasma-org.kde.plasma.desktop-appletsrc; do
  if [ -f "${backup_root}/${config}" ]; then
    run cp -a "${backup_root}/${config}" "${config_root}/${config}"
  fi
done
run rm -rf "${data_root}/plasma/look-and-feel/org.meo.desktop"
run rm -rf "${data_root}/plasma/desktoptheme/Meo"
run rm -rf "${data_root}/plasma/plasmoids/org.meo.shelf"
run rm -rf "${data_root}/plasma/plasmoids/org.meo.topbar"
run rm -rf "${data_root}/plasma/plasmoids/org.meo.launcher"
run rm -rf "${data_root}/plasma/plasmoids/org.meo.quicksettings"
run rm -rf "${data_root}/icons/Meo"
run rm -rf "${data_root}/wallpapers/MeoArch"
run rm -rf "${data_root}/fonts/meo"
run rm -rf "${qml_root}/MeoKDE"
run rm -rf "${qml_root}/Meo/System"
run rm -f "${config_root}/fontconfig/conf.d/50-meo-fonts.conf"
run rm -f "${config_root}/environment.d/90-meo-kde.conf"

if command -v systemctl >/dev/null 2>&1; then
  run systemctl --user unset-environment QML_IMPORT_PATH QML2_IMPORT_PATH
fi

if command -v fc-cache >/dev/null 2>&1; then
  run fc-cache -f
fi

if command -v plasma-apply-lookandfeel >/dev/null 2>&1; then
  run plasma-apply-lookandfeel -a org.kde.breeze.desktop
fi
