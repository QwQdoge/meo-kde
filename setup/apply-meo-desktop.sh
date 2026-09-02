#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
desktop_root="${repo_root}"
config_root="${XDG_CONFIG_HOME:-${HOME}/.config}"
data_root="${XDG_DATA_HOME:-${HOME}/.local/share}"
qml_root="${MEO_KDE_QML_ROOT:-${HOME}/.local/share/meo-kde/qml}"
user_plugin_root="${MEO_KDE_PLUGIN_ROOT:-${HOME}/.local/lib/qt6/plugins}"
local_bin_root="${XDG_BIN_HOME:-${HOME}/.local/bin}"
# MeoUI stays an independent, dynamically imported Qt QML module.  Build it
# from the sibling project rather than carrying a source snapshot in MeoKDE.
meoui_project_root="${MEOUI_PROJECT_ROOT:-${repo_root}/../meo-ui}"
meoui_build_root="${MEOUI_BUILD_ROOT:-${meoui_project_root}/out/build/release}"
meoui_source="${MEOUI_QML_SOURCE:-${meoui_build_root}/MeoUI}"
native_build_root="${repo_root}/out/build/native"
native_cxx="${MEO_KDE_CXX:-}"
if [ -z "${native_cxx}" ] && command -v clang++ >/dev/null 2>&1 \
  && c++ --version 2>/dev/null | head -1 | grep -q 'GCC) 16\|g++.*16\|GCC 16'; then
  # GCC 16 currently crashes internally while compiling Qt 6.11 headers on
  # this host. Prefer Clang when that compiler combination is detected.
  native_cxx="$(command -v clang++)"
  native_build_root="${repo_root}/out/build/native-clang"
fi
state_root="${XDG_STATE_HOME:-${HOME}/.local/state}/meo-desktop"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_root="${state_root}/backups/${timestamp}"
dry_run=0
reset_layout=0
apply_theme=0
refresh_meoui=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=1 ;;
    --apply) apply_theme=1 ;;
    --reset-layout) reset_layout=1; apply_theme=1 ;;
    --update-meoui) refresh_meoui=1 ;;
    --no-update-meoui) refresh_meoui=0 ;;
    *) echo "Usage: $0 [--dry-run] [--apply] [--reset-layout] [--update-meoui]" >&2; exit 2 ;;
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

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command is unavailable: $1" >&2
    exit 1
  fi
}

qt_install_path() {
  local query="$1"
  if command -v qmake6 >/dev/null 2>&1; then
    qmake6 -query "${query}"
    return
  fi
  if command -v qtpaths6 >/dev/null 2>&1; then
    case "${query}" in
      QT_INSTALL_PLUGINS) qtpaths6 --plugin-dir ;;
      QT_INSTALL_QML) qtpaths6 --qml-dir ;;
      *) return 1 ;;
    esac
    return
  fi
  return 1
}

has_plasma_package() {
  local package_id="$1"
  local data_dirs="${XDG_DATA_HOME:-${HOME}/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
  local data_dir
  IFS=: read -r -a data_dir_list <<< "${data_dirs}"
  for data_dir in "${data_dir_list[@]}"; do
    if [ -f "${data_dir}/plasma/plasmoids/${package_id}/metadata.json" ]; then
      return 0
    fi
  done
  return 1
}

preflight_plasma() {
  require_command plasmashell
  require_command cmake
  require_command qml6
  require_command kreadconfig6
  require_command kwriteconfig6
  require_command plasma-apply-lookandfeel
  require_command busctl

  local plasma_version
  plasma_version="$(plasmashell --version | awk '{print $2}')"
  local plasma_major="${plasma_version%%.*}"
  if ! [[ "${plasma_major}" =~ ^[0-9]+$ ]] || [ "${plasma_major}" -lt 6 ]; then
    echo "Meo Desktop requires KDE Plasma 6 or newer; found: ${plasma_version:-unknown}" >&2
    exit 1
  fi

  local qt_plugin_dir qt_qml_dir
  qt_plugin_dir="$(qt_install_path QT_INSTALL_PLUGINS)" || {
    echo "Could not locate Qt's plugin directory (qmake6 or qtpaths6 is required)." >&2
    exit 1
  }
  qt_qml_dir="$(qt_install_path QT_INSTALL_QML)" || {
    echo "Could not locate Qt's QML directory (qmake6 or qtpaths6 is required)." >&2
    exit 1
  }

  for required in \
    "${qt_plugin_dir}/plasma/applets/org.kde.plasma.kickoff.so" \
    "${qt_plugin_dir}/plasma/applets/org.kde.plasma.appmenu.so" \
    "${qt_plugin_dir}/plasma/applets/org.kde.plasma.systemtray.so" \
    "${qt_plugin_dir}/kwin/effects/plugins/kwin4_effect_shapecorners.so" \
    "${qt_qml_dir}/org/kde/plasma/clock/qmldir" \
    "${qt_qml_dir}/org/kde/notificationmanager/qmldir" \
    "${qt_qml_dir}/org/kde/plasma/workspace/calendar/qmldir"; do
    if [ ! -e "${required}" ]; then
      echo "Required Plasma runtime component is missing: ${required}" >&2
      exit 1
    fi
  done

  if ! has_plasma_package org.kde.plasma.icontasks; then
    echo "Required Plasma widget is missing: org.kde.plasma.icontasks" >&2
    exit 1
  fi
}

prepare_meoui() {
  if [ ! -f "${meoui_project_root}/CMakeLists.txt" ]; then
    echo "MeoUI project is missing: ${meoui_project_root}" >&2
    exit 1
  fi

  if [ "${refresh_meoui}" -eq 1 ]; then
    if ! git -C "${meoui_project_root}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "MeoUI is not a Git worktree, cannot safely update: ${meoui_project_root}" >&2
      exit 1
    fi
    if [ -n "$(git -C "${meoui_project_root}" status --porcelain)" ]; then
      echo "MeoUI has local changes; refusing the requested update. Omit --update-meoui to build the checkout as-is." >&2
      exit 1
    fi
    # Network and sibling-worktree mutation are explicit. A fast-forward-only
    # update never discards a developer's local history.
    run git -C "${meoui_project_root}" fetch --prune origin
    run git -C "${meoui_project_root}" merge --ff-only origin/main
  fi

  run cmake -S "${meoui_project_root}" -B "${meoui_build_root}" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo -DMEOUI_BUILD_SHOWCASE=OFF
  run cmake --build "${meoui_build_root}" --parallel

  if [ "${dry_run}" -eq 0 ] && [ ! -f "${meoui_source}/qmldir" ]; then
    echo "MeoUI build did not produce a loadable QML module: ${meoui_source}" >&2
    exit 1
  fi
}

for required in \
  "${desktop_root}/themes/look-and-feel/org.meo.desktop/metadata.json" \
  "${desktop_root}/themes/desktoptheme/MeoLight/metadata.json" \
  "${desktop_root}/themes/desktoptheme/MeoDark/metadata.json" \
  "${desktop_root}/themes/icons/MeoSymbols/index.theme" \
  "${desktop_root}/themes/icons/MeoSymbolsDark/index.theme" \
  "${repo_root}/qml/MeoKDE/qmldir" \
  "${repo_root}/defaults/plasma/meo-shellrc" \
  "${repo_root}/tools/shell/apply-meo-panel-layout.sh" \
  "${repo_root}/tools/theme/apply-meo-desktop.sh" \
  "${repo_root}/plasmoids/org.meo.timecenter/metadata.json" \
  "${repo_root}/assets/wallpapers/installer_background.png"; do
  if [ ! -f "${required}" ]; then
    echo "Required Meo Desktop asset is missing: ${required}" >&2
    exit 1
  fi
done

preflight_plasma
prepare_meoui

# Build every native artifact before changing user data or configuration. A
# failed compiler or missing KDE development dependency therefore leaves the
# desktop exactly as it was.
if [ -n "${native_cxx}" ]; then
  run cmake -S "${repo_root}/native" -B "${native_build_root}" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_CXX_COMPILER="${native_cxx}"
else
  run cmake -S "${repo_root}/native" -B "${native_build_root}" -DCMAKE_BUILD_TYPE=RelWithDebInfo
fi
run cmake --build "${native_build_root}" --parallel

run mkdir -p "${backup_root}" "${data_root}/color-schemes" "${data_root}/plasma/look-and-feel" "${data_root}/plasma/desktoptheme" "${data_root}/plasma/plasmoids" "${data_root}/icons" "${data_root}/wallpapers/MeoArch" "${data_root}/fonts/meo" "${qml_root}/MeoKDE" "${qml_root}/MeoUI" "${config_root}/fontconfig/conf.d" "${config_root}/environment.d" "${config_root}/systemd/user" "${config_root}/autostart" "${user_plugin_root}/styles" "${user_plugin_root}/org.kde.kdecoration3" "${user_plugin_root}/org.kde.kdecoration3.kcm" "${local_bin_root}"

# Preserve every named runtime path that this installer replaces or retires.
# reset-meo-desktop can then restore an older Meo build instead of leaving a
# half-uninstalled desktop or deleting a pre-existing same-name asset.
runtime_backups=(
  "${data_root}/plasma/look-and-feel/org.meo.desktop|data/plasma/look-and-feel/org.meo.desktop"
  "${data_root}/plasma/desktoptheme/Meo|data/plasma/desktoptheme/Meo"
  "${data_root}/plasma/desktoptheme/MeoLight|data/plasma/desktoptheme/MeoLight"
  "${data_root}/plasma/desktoptheme/MeoDark|data/plasma/desktoptheme/MeoDark"
  "${data_root}/plasma/plasmoids/org.meo.shelf|data/plasma/plasmoids/org.meo.shelf"
  "${data_root}/plasma/plasmoids/org.meo.topbar|data/plasma/plasmoids/org.meo.topbar"
  "${data_root}/plasma/plasmoids/org.meo.timecenter|data/plasma/plasmoids/org.meo.timecenter"
  "${data_root}/plasma/plasmoids/org.meo.toptasks|data/plasma/plasmoids/org.meo.toptasks"
  "${data_root}/plasma/plasmoids/org.meo.launcher|data/plasma/plasmoids/org.meo.launcher"
  "${data_root}/plasma/plasmoids/org.meo.quicksettings|data/plasma/plasmoids/org.meo.quicksettings"
  "${data_root}/icons/Meo|data/icons/Meo"
  "${data_root}/icons/MeoSymbols|data/icons/MeoSymbols"
  "${data_root}/icons/MeoSymbolsDark|data/icons/MeoSymbolsDark"
  "${data_root}/color-schemes/MeoLight.colors|data/color-schemes/MeoLight.colors"
  "${data_root}/color-schemes/MeoDark.colors|data/color-schemes/MeoDark.colors"
  "${data_root}/color-schemes/MeoDynamicLight.colors|data/color-schemes/MeoDynamicLight.colors"
  "${data_root}/color-schemes/MeoDynamicDark.colors|data/color-schemes/MeoDynamicDark.colors"
  "${data_root}/wallpapers/MeoArch|data/wallpapers/MeoArch"
  "${data_root}/fonts/meo|data/fonts/meo"
  "${data_root}/meo-kde|data/meo-kde"
  "${data_root}/fcitx5/themes/MeoInputMethod-Light|data/fcitx5/themes/MeoInputMethod-Light"
  "${data_root}/fcitx5/themes/MeoInputMethod-Dark|data/fcitx5/themes/MeoInputMethod-Dark"
  "${data_root}/fcitx5/themes/MeoInputMethod-Dynamic|data/fcitx5/themes/MeoInputMethod-Dynamic"
  "${data_root}/themes/MeoInputMethod|data/themes/MeoInputMethod"
  "${qml_root}/MeoKDE|qml/MeoKDE"
  "${qml_root}/MeoUI|qml/MeoUI"
  "${qml_root}/Meo/System|qml/Meo/System"
  "${user_plugin_root}/org.kde.kdecoration3/org.meo.decoration.so|plugins/org.kde.kdecoration3/org.meo.decoration.so"
  "${user_plugin_root}/org.kde.kdecoration3.kcm/kcm_meodecoration.so|plugins/org.kde.kdecoration3.kcm/kcm_meodecoration.so"
  "${user_plugin_root}/styles/meostyle.so|plugins/styles/meostyle.so"
  "${user_plugin_root}/org.kde.kdecoration3/org.meo.chromebreeze.so|plugins/org.kde.kdecoration3/org.meo.chromebreeze.so"
  "${user_plugin_root}/kwin/effects/plugins/org.meo.windowcorners.so|plugins/kwin/effects/plugins/org.meo.windowcorners.so"
  "${local_bin_root}/meo-dynamic-colors|bin/meo-dynamic-colors"
  "${local_bin_root}/meo-input-method|bin/meo-input-method"
  "${local_bin_root}/meo-desktop-layout|bin/meo-desktop-layout"
  "${local_bin_root}/meo-desktop-apply|bin/meo-desktop-apply"
  "${local_bin_root}/meo-app-icon-studio|bin/meo-app-icon-studio"
  "${local_bin_root}/meo-dock|bin/meo-dock"
  "${config_root}/autostart/org.meo.dock.desktop|config/autostart/org.meo.dock.desktop"
  "${config_root}/fontconfig/conf.d/50-meo-fonts.conf|config/fontconfig/conf.d/50-meo-fonts.conf"
  "${config_root}/environment.d/90-meo-kde.conf|config/environment.d/90-meo-kde.conf"
  "${config_root}/systemd/user/meo-dynamic-colors.service|config/systemd/user/meo-dynamic-colors.service"
  "${config_root}/systemd/user/meo-dynamic-colors.path|config/systemd/user/meo-dynamic-colors.path"
  "${config_root}/systemd/user/plasma-kwin_wayland.service.d/50-meo-chrome-breeze.conf|config/systemd/user/plasma-kwin_wayland.service.d/50-meo-chrome-breeze.conf"
  "${config_root}/systemd/user/plasma-kwin_wayland.service.d/50-meo-native-plugins.conf|config/systemd/user/plasma-kwin_wayland.service.d/50-meo-native-plugins.conf"
)
for runtime_backup in "${runtime_backups[@]}"; do
  runtime_source="${runtime_backup%%|*}"
  runtime_relative="${runtime_backup#*|}"
  if [ -e "${runtime_source}" ] || [ -L "${runtime_source}" ]; then
    run mkdir -p "${backup_root}/runtime/$(dirname "${runtime_relative}")"
    run cp -a "${runtime_source}" "${backup_root}/runtime/${runtime_relative}"
  fi
done
run touch "${backup_root}/runtime-backup-v1"

if [ "${dry_run}" -eq 0 ] && command -v systemctl >/dev/null 2>&1; then
  systemctl --user is-enabled meo-dynamic-colors.path > "${backup_root}/dynamic-color-path-enabled" 2>/dev/null || true
  systemctl --user is-active meo-dynamic-colors.path > "${backup_root}/dynamic-color-path-active" 2>/dev/null || true
fi

for config in kdeglobals kwinrc plasmarc meo-shellrc plasma-org.kde.plasma.desktop-appletsrc; do
  if [ -e "${config_root}/${config}" ]; then
    run cp -a "${config_root}/${config}" "${backup_root}/${config}"
  fi
done

# Applying the desktop may opt an already-running input framework into Meo's
# presentation. Preserve that framework's actual state separately from KDE
# config so reset never leaves it pointing at a removed theme.
if [ "${apply_theme}" -eq 1 ]; then
  input_state_root="${backup_root}/input-method"
  if command -v fcitx5-remote >/dev/null 2>&1 \
      && fcitx5-remote --check >/dev/null 2>&1; then
    run mkdir -p "${input_state_root}"
    run touch "${input_state_root}/fcitx5-selected"
    if [ -f "${config_root}/fcitx5/conf/classicui.conf" ]; then
      run cp -a "${config_root}/fcitx5/conf/classicui.conf" \
        "${input_state_root}/classicui.conf"
    else
      run touch "${input_state_root}/classicui.conf-absent"
    fi
  elif command -v pgrep >/dev/null 2>&1 && pgrep -x ibus-daemon >/dev/null 2>&1 \
      && command -v gsettings >/dev/null 2>&1; then
    if [ "${dry_run}" -eq 0 ]; then
      mkdir -p "${input_state_root}"
      touch "${input_state_root}/ibus-selected"
      gsettings get org.freedesktop.ibus.panel use-custom-theme \
        > "${input_state_root}/ibus-use-custom-theme"
      gsettings get org.freedesktop.ibus.panel custom-theme \
        > "${input_state_root}/ibus-custom-theme"
    else
      echo "Would preserve IBus panel theme settings in ${input_state_root}"
    fi
  fi
fi

# The profile is deliberately user-editable. Keep an existing profile intact
# across source updates; first install gets the dual-panel MD3 default.
if [ ! -f "${config_root}/meo-shellrc" ]; then
  run install -Dm644 "${repo_root}/defaults/plasma/meo-shellrc" "${config_root}/meo-shellrc"
fi

# Version 1 briefly replaced the useful native tray with a second top task
# manager and enlarged the Dock. Migrate only that exact legacy combination;
# all other user-edited profiles keep their choices untouched.
profile_version=3
if [ -f "${config_root}/meo-shellrc" ]; then
  profile_version="$(kreadconfig6 --file "${config_root}/meo-shellrc" --group General --key ProfileVersion --default 0)"
fi
if ! [[ "${profile_version}" =~ ^[0-9]+$ ]]; then
  profile_version=0
fi
if [ "${profile_version}" -lt 2 ] && [ -f "${config_root}/meo-shellrc" ]; then
  legacy_tray="$(kreadconfig6 --file "${config_root}/meo-shellrc" --group Panels --key ShowSystemTray --default false)"
  legacy_top_tasks="$(kreadconfig6 --file "${config_root}/meo-shellrc" --group Panels --key ShowTopAppTasks --default true)"
  legacy_dock_height="$(kreadconfig6 --file "${config_root}/meo-shellrc" --group Panels --key DockHeight --default 68)"
  if [ "${legacy_tray,,}" = false ] && [ "${legacy_top_tasks,,}" = true ] \
      && [ "${legacy_dock_height}" = 68 ]; then
    run kwriteconfig6 --file "${config_root}/meo-shellrc" --group Panels --key ShowSystemTray --type bool true
    run kwriteconfig6 --file "${config_root}/meo-shellrc" --group Panels --key ShowTopAppTasks --type bool false
    run kwriteconfig6 --file "${config_root}/meo-shellrc" --group Panels --key DockHeight 64
    run kwriteconfig6 --file "${config_root}/meo-shellrc" --group Panels --key TopAppTaskLimit --delete ''
  fi
fi
if [ "${profile_version}" -lt 3 ] && [ -f "${config_root}/meo-shellrc" ]; then
  # Version 3 makes the native tray and the two Meo status applets converge on
  # one deterministic order/config when the user explicitly reapplies the
  # panel profile. Merely installing the update does not rebuild live panels.
  run kwriteconfig6 --file "${config_root}/meo-shellrc" --group General --key ProfileVersion 3
fi

# Install Look-and-Feel package
run rm -rf "${data_root}/plasma/look-and-feel/org.meo.desktop"
run cp -a "${desktop_root}/themes/look-and-feel/org.meo.desktop" "${data_root}/plasma/look-and-feel/org.meo.desktop"
for desktop_theme in MeoLight MeoDark; do
  run rm -rf "${data_root}/plasma/desktoptheme/${desktop_theme}"
  run cp -a "${desktop_root}/themes/desktoptheme/${desktop_theme}" "${data_root}/plasma/desktoptheme/${desktop_theme}"
done
# Meo was an early duplicate desktop theme. Keep the two explicit light/dark
# variants so System Settings presents a single, unambiguous Meo choice.
run rm -rf "${data_root}/plasma/desktoptheme/Meo"
run cp -a "${desktop_root}/themes/color-schemes/." "${data_root}/color-schemes/"
for icon_theme in MeoSymbols MeoSymbolsDark; do
  run rm -rf "${data_root}/icons/${icon_theme}"
  run cp -a "${desktop_root}/themes/icons/${icon_theme}" "${data_root}/icons/${icon_theme}"
done

# Meo owns the quick-settings and time surfaces; KDE owns the native System
# Tray/StatusNotifier application icons and the bottom task manager.
for meo_panel_applet in org.meo.topbar org.meo.timecenter; do
  if [ -e "${data_root}/plasma/plasmoids/${meo_panel_applet}" ]; then
    run mkdir -p "${backup_root}/plasmoids"
    run cp -a "${data_root}/plasma/plasmoids/${meo_panel_applet}" \
      "${backup_root}/plasmoids/${meo_panel_applet}"
  fi
done
for legacy_plasmoid in org.meo.launcher org.meo.quicksettings org.meo.shelf org.meo.toptasks; do
  run rm -rf "${data_root}/plasma/plasmoids/${legacy_plasmoid}"
done
for meo_panel_applet in org.meo.topbar org.meo.timecenter; do
  run rm -rf "${data_root}/plasma/plasmoids/${meo_panel_applet}"
  run cp -a "${repo_root}/plasmoids/${meo_panel_applet}" \
    "${data_root}/plasma/plasmoids/${meo_panel_applet}"
done

run cp -a "${meoui_source}/." "${qml_root}/MeoUI/"
# The QML plugin links against libmeoui.  Keep its runtime next to the module
# as well, so a source-built desktop does not depend on an absolute build-tree
# RUNPATH remaining at the same location after installation or an update.
for meoui_runtime_library in "${meoui_build_root}"/libmeoui.so*; do
  if [ -f "${meoui_runtime_library}" ]; then
    run cp -a "${meoui_runtime_library}" "${qml_root}/MeoUI/"
  fi
done
run cp -a "${repo_root}/qml/MeoKDE/." "${qml_root}/MeoKDE/"
run install -Dm755 "${repo_root}/tools/input-method/meo-input-method.sh" "${local_bin_root}/meo-input-method"
run install -Dm755 "${repo_root}/tools/shell/apply-meo-panel-layout.sh" "${local_bin_root}/meo-desktop-layout"
run install -Dm755 "${repo_root}/tools/theme/apply-meo-desktop.sh" "${local_bin_root}/meo-desktop-apply"
run install -Dm755 "${repo_root}/tools/icons/app_icon_studio.py" "${local_bin_root}/meo-app-icon-studio"
run install -Dm0755 "${native_build_root}/dock/meo-dock" "${local_bin_root}/meo-dock"
run install -Dm0644 "${repo_root}/data/autostart/org.meo.dock.desktop" "${config_root}/autostart/org.meo.dock.desktop"
run install -Dm644 "${repo_root}/defaults/kwin/kwinrc" "${data_root}/meo-kde/defaults/kwinrc"
run mkdir -p "${data_root}/fcitx5/themes"
for input_theme in MeoInputMethod-Light MeoInputMethod-Dark; do
  run rm -rf "${data_root}/fcitx5/themes/${input_theme}"
  run cp -a "${repo_root}/themes/input-method/fcitx5/${input_theme}" "${data_root}/fcitx5/themes/${input_theme}"
done
run install -Dm644 "${repo_root}/themes/input-method/ibus/gtk.css.in" "${data_root}/meo-kde/input-method/ibus/gtk.css.in"
run install -Dm644 "${repo_root}/themes/input-method/ibus/index.theme" "${data_root}/meo-kde/input-method/ibus/index.theme"
run install -Dm0755 "${native_build_root}/dynamic-color/meo-dynamic-colors" "${local_bin_root}/meo-dynamic-colors"
# Install the Qt Widgets style beside the user's other Qt plugins. Selection is
# persisted through kdeglobals/environment.d and takes effect for new processes
# without restarting the current Plasma or KWin session.
run install -Dm0755 "${native_build_root}/qt-plugins/styles/meostyle.so" "${user_plugin_root}/styles/meostyle.so"
# Install the independent native decoration. KWin owns every window action;
# this module supplies only visual geometry and caption-button rendering.
run install -Dm0755 "${native_build_root}/bin/org.kde.kdecoration3/org.meo.decoration.so" "${user_plugin_root}/org.kde.kdecoration3/org.meo.decoration.so"
run install -Dm0755 "${native_build_root}/decoration/kcm_meodecoration.so" "${user_plugin_root}/org.kde.kdecoration3.kcm/kcm_meodecoration.so"
run rm -f "${user_plugin_root}/org.kde.kdecoration3/org.meo.chromebreeze.so"
# Client-surface clipping is delegated to KDE-Rounded-Corners. It uses KWin's
# shader and repaint pipeline and is maintained across KWin releases. Remove
# the retired Meo region-clipping plugin so a stale user copy cannot be loaded.
run rm -f "${user_plugin_root}/kwin/effects/plugins/org.meo.windowcorners.so"
run mkdir -p "${qml_root}/Meo/System"
if [ -d "${native_build_root}/qml/Meo/System" ]; then
  run cp -a "${native_build_root}/qml/Meo/System/." "${qml_root}/Meo/System/"
fi

# Do not ask a live Wayland compositor to reload decoration modules. The
# selected decoration is discovered during the user's next normal login.
run cp -a "${repo_root}/assets/fonts/." "${data_root}/fonts/meo/"
run cp -a "${repo_root}/defaults/fonts/50-meo-fonts.conf" "${config_root}/fontconfig/conf.d/50-meo-fonts.conf"
run cp -a "${repo_root}/defaults/environment/90-meo-kde.conf" "${config_root}/environment.d/90-meo-kde.conf"

if command -v systemctl >/dev/null 2>&1; then
  run systemctl --user set-environment "QML_IMPORT_PATH=${qml_root}" "QML2_IMPORT_PATH=${qml_root}"
  # This is deliberately only a daemon reload. The drop-in takes effect on a
  # future normal login; never restart KWin from a theme installer.
  run mkdir -p "${config_root}/systemd/user/plasma-kwin_wayland.service.d"
  run rm -f "${config_root}/systemd/user/plasma-kwin_wayland.service.d/50-meo-chrome-breeze.conf"
  run cp -a "${repo_root}/defaults/systemd/50-meo-native-plugins.conf" "${config_root}/systemd/user/plasma-kwin_wayland.service.d/50-meo-native-plugins.conf"
  # Installation alone leaves the watcher state unchanged. The explicit
  # --apply action below enables it after taking the backup above.
  run cp -a "${repo_root}/defaults/systemd/meo-dynamic-colors.service" "${config_root}/systemd/user/meo-dynamic-colors.service"
  run cp -a "${repo_root}/defaults/systemd/meo-dynamic-colors.path" "${config_root}/systemd/user/meo-dynamic-colors.path"
  run systemctl --user daemon-reload
fi

run cp -a "${repo_root}/assets/wallpapers/installer_background.png" "${data_root}/wallpapers/MeoArch/installer_background.png"
if command -v fc-cache >/dev/null 2>&1; then
  run fc-cache -f "${data_root}/fonts/meo"
fi

if [ "${dry_run}" -eq 0 ]; then
  printf '%s\n' "${backup_root}" > "${state_root}/last-backup"
fi

if [ "${apply_theme}" -eq 1 ]; then
  apply_arguments=(--no-backup)
  if [ "${reset_layout}" -eq 1 ]; then
    apply_arguments+=(--reset-layout)
  fi
  if [ "${dry_run}" -eq 1 ]; then
    apply_arguments+=(--dry-run)
  fi
  run env MEO_INPUT_METHOD_HELPER="${repo_root}/tools/input-method/meo-input-method.sh" \
    MEO_DYNAMIC_COLORS_HELPER="${native_build_root}/dynamic-color/meo-dynamic-colors" \
    MEO_KWIN_DEFAULTS="${repo_root}/defaults/kwin/kwinrc" \
    "${repo_root}/tools/theme/apply-meo-desktop.sh" "${apply_arguments[@]}"
else
  echo "Meo is installed for selection in System Settings. Run with --apply only to apply it immediately." >&2
fi
