#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
desktop_root="${repo_root}"
config_root="${XDG_CONFIG_HOME:-${HOME}/.config}"
data_root="${XDG_DATA_HOME:-${HOME}/.local/share}"
qml_root="${MEO_KDE_QML_ROOT:-${HOME}/.local/share/meo-kde/qml}"
user_plugin_root="${MEO_KDE_PLUGIN_ROOT:-${HOME}/.local/lib/qt6/plugins}"
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
launcher_action_display="Activate Application Launcher"
legacy_shelf_action_display=""
if [ -f "${config_root}/kglobalshortcutsrc" ]; then
  # KGlobalAccel identifies the display text as part of a foreign action ID;
  # capture the localized text before replacing the legacy shortcut entry.
  launcher_action_display="$(awk -F= '$1 == "activate application launcher" { count = split($2, fields, ","); print fields[count]; exit }' "${config_root}/kglobalshortcutsrc")"
  launcher_action_display="${launcher_action_display:-Activate Application Launcher}"
  legacy_shelf_action_display="$(awk -F= '$1 == "activate widget 20" { count = split($2, fields, ","); print fields[count]; exit }' "${config_root}/kglobalshortcutsrc")"
fi
dry_run=0
reset_layout=0
apply_theme=0
refresh_meoui=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=1 ;;
    --apply) apply_theme=1 ;;
    --reset-layout) reset_layout=1; apply_theme=1 ;;
    --no-update-meoui) refresh_meoui=0 ;;
    *) echo "Usage: $0 [--dry-run] [--apply] [--reset-layout] [--no-update-meoui]" >&2; exit 2 ;;
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
      echo "MeoUI has local changes; refusing to overwrite them. Commit/stash them or use --no-update-meoui." >&2
      exit 1
    fi
    # A fast-forward-only update keeps the project folder authoritative while
    # never discarding a developer's local history.
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

install_rounded_corners_effect() {
  local package_name="kwin-effect-rounded-corners-git"
  if pacman -Q "${package_name}" >/dev/null 2>&1; then
    return
  fi

  # KDE-Rounded-Corners supplies the maintained Plasma 6 shader effect and
  # its KCM. Install only when absent so ordinary theme applies stay fast.
  if command -v paru >/dev/null 2>&1; then
    run paru -S --needed --noconfirm "${package_name}"
  elif command -v yay >/dev/null 2>&1; then
    run yay -S --needed --noconfirm "${package_name}"
  else
    echo "${package_name} requires paru or yay for automatic AUR installation." >&2
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
  "${repo_root}/assets/wallpapers/installer_background.png"; do
  if [ ! -f "${required}" ]; then
    echo "Required Meo Desktop asset is missing: ${required}" >&2
    exit 1
  fi
done

prepare_meoui

run mkdir -p "${backup_root}" "${data_root}/color-schemes" "${data_root}/plasma/look-and-feel" "${data_root}/plasma/desktoptheme" "${data_root}/plasma/plasmoids" "${data_root}/icons" "${data_root}/wallpapers/MeoArch" "${data_root}/fonts/meo" "${qml_root}/MeoKDE" "${qml_root}/MeoUI" "${config_root}/fontconfig/conf.d" "${config_root}/environment.d" "${user_plugin_root}/org.kde.kdecoration3" "${user_plugin_root}/org.kde.kdecoration3.kcm" "${user_plugin_root}/kwin/effects/plugins"

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
# Meo was an early duplicate desktop theme. Keep the two explicit light/dark
# variants so System Settings presents a single, unambiguous Meo choice.
run rm -rf "${data_root}/plasma/desktoptheme/Meo"
run cp -a "${desktop_root}/themes/color-schemes/." "${data_root}/color-schemes/"
for icon_theme in MeoSymbols MeoSymbolsDark; do
  run rm -rf "${data_root}/icons/${icon_theme}"
  run cp -a "${desktop_root}/themes/icons/${icon_theme}" "${data_root}/icons/${icon_theme}"
done

# The panel is composed from Plasma's own AppMenu, Kickoff, Icons-Only Task
# Manager, System Tray and Digital Clock. Remove historical custom panel
# plasmoids so they cannot remain as duplicate choices in System Settings.
for legacy_plasmoid in org.meo.launcher org.meo.quicksettings org.meo.shelf org.meo.topbar; do
  run rm -rf "${data_root}/plasma/plasmoids/${legacy_plasmoid}"
done

run cp -a "${meoui_source}/." "${qml_root}/MeoUI/"
run cp -a "${repo_root}/qml/MeoKDE/." "${qml_root}/MeoKDE/"
if [ -n "${native_cxx}" ]; then
  run cmake -S "${repo_root}/native" -B "${native_build_root}" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_CXX_COMPILER="${native_cxx}"
else
  run cmake -S "${repo_root}/native" -B "${native_build_root}" -DCMAKE_BUILD_TYPE=RelWithDebInfo
fi
run cmake --build "${native_build_root}" --parallel
install_rounded_corners_effect
# Install the independent native decoration. KWin owns every window action;
# this module supplies only visual geometry and caption-button rendering.
run install -Dm0755 "${native_build_root}/bin/org.kde.kdecoration3/org.meo.decoration.so" "${user_plugin_root}/org.kde.kdecoration3/org.meo.decoration.so"
run install -Dm0755 "${native_build_root}/decoration/kcm_meodecoration.so" "${user_plugin_root}/org.kde.kdecoration3.kcm/kcm_meodecoration.so"
run rm -f "${user_plugin_root}/org.kde.kdecoration3/org.meo.chromebreeze.so"
# Do not install the old clipping effect. KWin's normal window rendering and
# resize borders are the desired default for every application.
run rm -f "${user_plugin_root}/kwin/effects/plugins/org.meo.windowcorners.so"
run mkdir -p "${qml_root}/Meo/System"
if [ -d "${native_build_root}/qml/Meo/System" ]; then
  run cp -a "${native_build_root}/qml/Meo/System/." "${qml_root}/Meo/System/"
fi

if command -v kwriteconfig6 >/dev/null 2>&1; then
  # Look-and-feel defaults are applied only when a theme is selected. Persist
  # the KDE-native decoration selection so reboot paths are identical.
  run kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.meo.decoration
  run kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme "Meo Chrome Frame"
  run kwriteconfig6 --file kwinrc --group Plugins --key org.meo.windowcornersEnabled false
  run kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_shapecornersEnabled true
  run kwriteconfig6 --file kwinrc --group org.meo.decoration --key TitleBarHeight 32
  run kwriteconfig6 --file kwinrc --group org.meo.decoration --key CornerRadius 10
  run kwriteconfig6 --file kwinrc --group org.meo.decoration --key ButtonDiameter 22
  run kwriteconfig6 --file kwinrc --group org.meo.decoration --key ButtonHitSize 32
  run kwriteconfig6 --file kwinrc --group org.meo.decoration --key ButtonSpacing 0
  run kwriteconfig6 --file kwinrc --group org.meo.decoration --key ButtonRightMargin 4
  run kwriteconfig6 --file kwinrc --group org.meo.decoration --key ShadowIntensity 0.22
  run kwriteconfig6 --file kwinrc --group org.meo.decoration --key ShadowRadius 24
  run kwriteconfig6 --file kwinrc --group org.meo.decoration --key ShadowOffsetY 6
  run kwriteconfig6 --file kwinrc --group org.meo.decoration --key HoverInDuration 100
  run kwriteconfig6 --file kwinrc --group org.meo.decoration --key HoverOutDuration 80
  run kwriteconfig6 --file kwinrc --group org.meo.decoration --key FocusTransitionDuration 180
  # Match the decoration radius while preserving DecorationShadow and avoid
  # applying rounded corners to edge-to-edge/tiled window states.
  run kwriteconfig6 --file kwinrc --group Round-Corners --key Size 10
  run kwriteconfig6 --file kwinrc --group Round-Corners --key InactiveCornerRadius 10
  run kwriteconfig6 --file kwinrc --group Round-Corners --key UseSquircleShape false
  run kwriteconfig6 --file kwinrc --group Round-Corners --key UseNativeDecorationShadows true
  run kwriteconfig6 --file kwinrc --group Round-Corners --key OutlineThickness 0
  run kwriteconfig6 --file kwinrc --group Round-Corners --key InactiveOutlineThickness 0
  run kwriteconfig6 --file kwinrc --group Round-Corners --key DisableRoundTile true
  run kwriteconfig6 --file kwinrc --group Round-Corners --key DisableRoundMaximize true
  run kwriteconfig6 --file kwinrc --group Round-Corners --key DisableRoundFullScreen true
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
  run cp -a "${repo_root}/defaults/systemd/50-meo-chrome-breeze.conf" "${config_root}/systemd/user/plasma-kwin_wayland.service.d/50-meo-chrome-breeze.conf"
  run systemctl --user daemon-reload
fi

run cp -a "${repo_root}/assets/wallpapers/installer_background.png" "${data_root}/wallpapers/MeoArch/installer_background.png"
if command -v fc-cache >/dev/null 2>&1; then
  run fc-cache -f "${data_root}/fonts/meo"
fi

if [ "${dry_run}" -eq 0 ]; then
  printf '%s\n' "${backup_root}" > "${state_root}/last-backup"
fi

if [ "${apply_theme}" -eq 1 ] && command -v plasma-apply-lookandfeel >/dev/null 2>&1; then
  if [ "${reset_layout}" -eq 1 ]; then
    run plasma-apply-lookandfeel -a org.meo.desktop --resetLayout
  else
    run plasma-apply-lookandfeel -a org.meo.desktop
  fi
elif [ "${apply_theme}" -eq 1 ] && command -v lookandfeeltool >/dev/null 2>&1; then
  run lookandfeeltool -a org.meo.desktop
else
  echo "Meo is installed for selection in System Settings. Run with --apply only to apply it immediately." >&2
fi

# plasma-apply-lookandfeel can rewrite kwinrc from package defaults after the
# earlier install phase. Reassert the selected, installed decoration last.
if [ "${apply_theme}" -eq 1 ] && command -v kwriteconfig6 >/dev/null 2>&1; then
  run kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.meo.decoration
  run kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme "Meo Chrome Frame"
fi

if [ "${apply_theme}" -eq 1 ] && [ "${reset_layout}" -eq 1 ] && command -v systemctl >/dev/null 2>&1; then
  # Remove stale Meo widget bindings and restore KDE's own Kickoff action.
  # The standard Plasma launcher is the sole owner of Meta after the reset.
  if command -v kwriteconfig6 >/dev/null 2>&1; then
    run kwriteconfig6 --file kglobalshortcutsrc --group plasmashell --key "activate application launcher" $'Meta\tAlt+F1,Meta\tAlt+F1,'"${launcher_action_display}"
    if [ -n "${legacy_shelf_action_display}" ]; then
      run kwriteconfig6 --file kglobalshortcutsrc --group plasmashell --key "activate widget 20" "none,none,${legacy_shelf_action_display}"
    fi
    run kwriteconfig6 --file kglobalshortcutsrc --group plasmashell --delete "activate widget 48"
    run kwriteconfig6 --file kglobalshortcutsrc --group plasmashell --delete "activate widget 98"
  fi
  # KGlobalAccel keeps a live copy, so update the real KDE launcher action too.
  if command -v busctl >/dev/null 2>&1; then
    run busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel setForeignShortcut asai 4 plasmashell "activate application launcher" plasmashell "${launcher_action_display}" 2 150994992 16777250
    if [ -n "${legacy_shelf_action_display}" ]; then
      run busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel setForeignShortcut asai 4 plasmashell "activate widget 20" plasmashell "${legacy_shelf_action_display}" 0
    fi
  fi
  echo "Layout reset is written. Plasma will use it at the next normal login; no live shell restart was requested." >&2
fi
