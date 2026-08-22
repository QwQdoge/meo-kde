#!/usr/bin/env bash
set -euo pipefail

config_root="${XDG_CONFIG_HOME:-${HOME}/.config}"
data_root="${XDG_DATA_HOME:-${HOME}/.local/share}"
qml_root="${MEO_KDE_QML_ROOT:-${HOME}/.local/share/meo-kde/qml}"
user_plugin_root="${MEO_KDE_PLUGIN_ROOT:-${HOME}/.local/lib/qt6/plugins}"
local_bin_root="${XDG_BIN_HOME:-${HOME}/.local/bin}"
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

strip_meo_fcitx_defaults() {
  local config_file="${config_root}/fcitx5/conf/classicui.conf"
  [ -f "${config_file}" ] || return 0
  if [ "${dry_run}" -eq 1 ]; then
    echo "Would remove only Meo-owned Fcitx theme keys from ${config_file}"
    return 0
  fi
  local temporary theme dark_theme strip_dark_mode=0
  theme="$(awk -F= '/^\[/ { exit } $1 == "Theme" { print substr($0, index($0, "=") + 1); exit }' "${config_file}")"
  dark_theme="$(awk -F= '/^\[/ { exit } $1 == "DarkTheme" { print substr($0, index($0, "=") + 1); exit }' "${config_file}")"
  if [[ "${theme}" =~ ^MeoInputMethod-(Light|Dark|Dynamic)$ ]] \
      && [[ "${dark_theme}" =~ ^MeoInputMethod-(Light|Dark|Dynamic)$ ]]; then
    strip_dark_mode=1
  fi
  temporary="$(mktemp "${config_file}.XXXXXX")"
  awk -v strip_dark_mode="${strip_dark_mode}" '
    BEGIN { in_root = 1 }
    /^\[/ { in_root = 0 }
    in_root && /^Theme=MeoInputMethod-(Light|Dark|Dynamic)$/ { next }
    in_root && /^DarkTheme=MeoInputMethod-(Light|Dark|Dynamic)$/ { next }
    in_root && strip_dark_mode && /^UseDarkTheme=True$/ { next }
    { print }
  ' "${config_file}" > "${temporary}"
  run mv "${temporary}" "${config_file}"
}

# Stop the source-installed watcher before removing its executable or unit.
# This also removes a user-level wants link instead of leaving a failed trigger
# behind. The exact pre-install state is restored after runtime backups below.
if command -v systemctl >/dev/null 2>&1 \
    && systemctl --user cat meo-dynamic-colors.path >/dev/null 2>&1; then
  if systemctl --user is-active meo-dynamic-colors.path >/dev/null 2>&1; then
    run systemctl --user stop meo-dynamic-colors.path
  fi
  if systemctl --user is-enabled meo-dynamic-colors.path >/dev/null 2>&1; then
    run systemctl --user disable meo-dynamic-colors.path
  fi
fi

for config in kdeglobals kwinrc plasmarc meo-shellrc plasma-org.kde.plasma.desktop-appletsrc; do
  if [ -f "${backup_root}/${config}" ]; then
    run cp -a "${backup_root}/${config}" "${config_root}/${config}"
  fi
done
if [ ! -f "${backup_root}/meo-shellrc" ]; then
  run rm -f "${config_root}/meo-shellrc"
fi

input_state_root="${backup_root}/input-method"
if [ -f "${input_state_root}/fcitx5-selected" ]; then
  if [ -f "${input_state_root}/classicui.conf" ]; then
    run mkdir -p "${config_root}/fcitx5/conf"
    run cp -a "${input_state_root}/classicui.conf" \
      "${config_root}/fcitx5/conf/classicui.conf"
  elif [ -f "${input_state_root}/classicui.conf-absent" ]; then
    strip_meo_fcitx_defaults
  fi
fi
if [ -f "${input_state_root}/ibus-selected" ] && command -v gsettings >/dev/null 2>&1; then
  ibus_use_custom_theme="$(<"${input_state_root}/ibus-use-custom-theme")"
  ibus_custom_theme="$(<"${input_state_root}/ibus-custom-theme")"
  run gsettings set org.freedesktop.ibus.panel use-custom-theme "${ibus_use_custom_theme}"
  run gsettings set org.freedesktop.ibus.panel custom-theme "${ibus_custom_theme}"
  if [ "${dry_run}" -eq 0 ]; then
    [ "$(gsettings get org.freedesktop.ibus.panel use-custom-theme)" = "${ibus_use_custom_theme}" ]
    [ "$(gsettings get org.freedesktop.ibus.panel custom-theme)" = "${ibus_custom_theme}" ]
  fi
fi
run rm -rf "${data_root}/plasma/look-and-feel/org.meo.desktop"
run rm -rf "${data_root}/plasma/desktoptheme/Meo"
run rm -rf "${data_root}/plasma/desktoptheme/MeoLight"
run rm -rf "${data_root}/plasma/desktoptheme/MeoDark"
run rm -rf "${data_root}/plasma/plasmoids/org.meo.shelf"
run rm -rf "${data_root}/plasma/plasmoids/org.meo.topbar"
run rm -rf "${data_root}/plasma/plasmoids/org.meo.timecenter"
run rm -rf "${data_root}/plasma/plasmoids/org.meo.toptasks"
run rm -rf "${data_root}/plasma/plasmoids/org.meo.launcher"
run rm -rf "${data_root}/plasma/plasmoids/org.meo.quicksettings"
run rm -rf "${data_root}/icons/Meo"
run rm -rf "${data_root}/icons/MeoSymbols"
run rm -rf "${data_root}/icons/MeoSymbolsDark"
run rm -rf "${data_root}/wallpapers/MeoArch"
run rm -rf "${data_root}/fonts/meo"
run rm -rf "${qml_root}/MeoKDE"
run rm -rf "${qml_root}/MeoUI"
run rm -rf "${qml_root}/Meo/System"
run rm -rf "${data_root}/meo-kde"
run rm -rf "${data_root}/fcitx5/themes/MeoInputMethod-Light"
run rm -rf "${data_root}/fcitx5/themes/MeoInputMethod-Dark"
run rm -rf "${data_root}/fcitx5/themes/MeoInputMethod-Dynamic"
run rm -rf "${data_root}/themes/MeoInputMethod"
run rm -f "${data_root}/color-schemes/MeoLight.colors"
run rm -f "${data_root}/color-schemes/MeoDark.colors"
run rm -f "${data_root}/color-schemes/MeoDynamicLight.colors"
run rm -f "${data_root}/color-schemes/MeoDynamicDark.colors"
run rm -f "${user_plugin_root}/org.kde.kdecoration3/org.meo.decoration.so"
run rm -f "${user_plugin_root}/org.kde.kdecoration3.kcm/kcm_meodecoration.so"
run rm -f "${user_plugin_root}/styles/meostyle.so"
run rm -f "${user_plugin_root}/kwin/effects/plugins/org.meo.windowcorners.so"
run rm -f "${local_bin_root}/meo-dynamic-colors"
run rm -f "${local_bin_root}/meo-input-method"
run rm -f "${local_bin_root}/meo-desktop-layout"
run rm -f "${local_bin_root}/meo-desktop-apply"
run rm -f "${config_root}/fontconfig/conf.d/50-meo-fonts.conf"
run rm -f "${config_root}/environment.d/90-meo-kde.conf"
run rm -f "${config_root}/systemd/user/meo-dynamic-colors.service"
run rm -f "${config_root}/systemd/user/meo-dynamic-colors.path"
run rm -f "${config_root}/systemd/user/plasma-kwin_wayland.service.d/50-meo-chrome-breeze.conf"
run rm -f "${config_root}/systemd/user/plasma-kwin_wayland.service.d/50-meo-native-plugins.conf"

if [ -f "${backup_root}/runtime-backup-v1" ]; then
  for runtime_group in data qml plugins bin config; do
    if [ -d "${backup_root}/runtime/${runtime_group}" ]; then
      case "${runtime_group}" in
        data) restore_root="${data_root}" ;;
        qml) restore_root="${qml_root}" ;;
        plugins) restore_root="${user_plugin_root}" ;;
        bin) restore_root="${local_bin_root}" ;;
        config) restore_root="${config_root}" ;;
      esac
      run mkdir -p "${restore_root}"
      run cp -a "${backup_root}/runtime/${runtime_group}/." "${restore_root}/"
    fi
  done
fi

if [ ! -f "${backup_root}/runtime-backup-v1" ]; then
  for meo_panel_applet in org.meo.topbar org.meo.timecenter; do
    if [ -d "${backup_root}/plasmoids/${meo_panel_applet}" ]; then
      run mkdir -p "${data_root}/plasma/plasmoids"
      run cp -a "${backup_root}/plasmoids/${meo_panel_applet}" \
        "${data_root}/plasma/plasmoids/${meo_panel_applet}"
    fi
  done
fi

# A restored Fcitx configuration is not the running Classic UI state until the
# addon has reloaded it. Use the same reliable D-Bus path as the input-method
# helper, then query the live configuration so reset never silently leaves a
# process pointing at the removed Dynamic theme.
if [ -f "${input_state_root}/fcitx5-selected" ] \
    && command -v fcitx5-remote >/dev/null 2>&1 \
    && fcitx5-remote --check >/dev/null 2>&1; then
  if command -v busctl >/dev/null 2>&1; then
    run busctl --user call org.fcitx.Fcitx5 /controller \
      org.fcitx.Fcitx.Controller1 ReloadAddonConfig s classicui
    if [ "${dry_run}" -eq 0 ]; then
      busctl --user call org.fcitx.Fcitx5 /controller \
        org.fcitx.Fcitx.Controller1 GetConfig s fcitx://config/addon/classicui \
        >/dev/null
    fi
  else
    echo "Restored the Fcitx configuration file, but busctl is unavailable; runtime reload is unverified." >&2
  fi
fi

# If the user's previous IBus theme was itself MeoInputMethod, its restored
# files may differ while the setting string stays unchanged. Toggle only that
# exact presentation value to make the running panel reload the restored CSS.
if [ -f "${input_state_root}/ibus-selected" ] \
    && [ "${ibus_custom_theme:-}" = "'MeoInputMethod'" ] \
    && command -v pgrep >/dev/null 2>&1 \
    && pgrep -x ibus-daemon >/dev/null 2>&1; then
  run gsettings set org.freedesktop.ibus.panel custom-theme Adwaita
  run gsettings set org.freedesktop.ibus.panel custom-theme "${ibus_custom_theme}"
fi

if command -v systemctl >/dev/null 2>&1; then
  run systemctl --user unset-environment QML_IMPORT_PATH QML2_IMPORT_PATH
  run systemctl --user daemon-reload
  prior_enabled=""
  prior_active=""
  if [ -f "${backup_root}/dynamic-color-path-enabled" ]; then
    prior_enabled="$(<"${backup_root}/dynamic-color-path-enabled")"
  fi
  if [ -f "${backup_root}/dynamic-color-path-active" ]; then
    prior_active="$(<"${backup_root}/dynamic-color-path-active")"
  fi
  case "${prior_enabled}" in
    enabled|enabled-runtime|linked|linked-runtime)
      run systemctl --user enable meo-dynamic-colors.path
      ;;
  esac
  if [ "${prior_active}" = active ]; then
    run systemctl --user start meo-dynamic-colors.path
  fi
fi

if command -v fc-cache >/dev/null 2>&1; then
  run fc-cache -f
fi

if [ ! -f "${backup_root}/kdeglobals" ] \
    && command -v plasma-apply-lookandfeel >/dev/null 2>&1; then
  run plasma-apply-lookandfeel -a org.kde.breeze.desktop
fi
