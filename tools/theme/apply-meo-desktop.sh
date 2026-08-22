#!/usr/bin/env bash
set -euo pipefail

# Apply the installed Meo Look-and-Feel, then bridge only the activation gaps
# that Plasma themes cannot own. This script never rebuilds the default panel
# layout unless --reset-layout is explicitly requested.

config_root="${XDG_CONFIG_HOME:-${HOME}/.config}"
state_root="${XDG_STATE_HOME:-${HOME}/.local/state}/meo-desktop"
script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dry_run=0
quiet=0
reset_layout=0
make_backup=1
kwin_only=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --reset-layout) reset_layout=1 ;;
    --dry-run) dry_run=1 ;;
    --quiet) quiet=1 ;;
    --no-backup) make_backup=0 ;;
    --kwin-only) kwin_only=1 ;;
    *)
      echo "Usage: meo-desktop-apply [--reset-layout] [--kwin-only] [--dry-run] [--quiet]" >&2
      exit 2
      ;;
  esac
  shift
done

info() {
  [ "${quiet}" -eq 1 ] || printf '%s\n' "$*"
}

run() {
  if [ "${quiet}" -eq 0 ]; then
    printf '+ '
    printf '%q ' "$@"
    printf '\n'
  fi
  if [ "${dry_run}" -eq 0 ]; then
    "$@"
  fi
}

required_commands=(kwriteconfig6)
if [ "${kwin_only}" -eq 0 ]; then
  required_commands+=(plasma-apply-lookandfeel)
fi
for command in "${required_commands[@]}"; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "Required command is unavailable: ${command}" >&2
    exit 1
  fi
done

input_helper="${MEO_INPUT_METHOD_HELPER:-}"
if [ -z "${input_helper}" ] && command -v meo-input-method >/dev/null 2>&1; then
  input_helper="$(command -v meo-input-method)"
fi
dynamic_color_helper="${MEO_DYNAMIC_COLORS_HELPER:-}"
if [ -z "${dynamic_color_helper}" ] && command -v meo-dynamic-colors >/dev/null 2>&1; then
  dynamic_color_helper="$(command -v meo-dynamic-colors)"
fi
enable_dynamic_watcher="${MEO_ENABLE_DYNAMIC_COLOR_WATCHER:-1}"

resolve_kwin_defaults() {
  local candidate
  for candidate in \
    "${MEO_KWIN_DEFAULTS:-}" \
    "${script_root}/../../defaults/kwin/kwinrc" \
    "${XDG_DATA_HOME:-${HOME}/.local/share}/meo-kde/defaults/kwinrc" \
    "/usr/share/meo-desktop/defaults/kwinrc"; do
    if [ -n "${candidate}" ] && [ -f "${candidate}" ]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  echo "Could not locate the canonical Meo KWin defaults." >&2
  return 1
}

apply_kwin_defaults() {
  local defaults_file="$1"
  local section="" line key value

  # defaults/kwin/kwinrc is the sole authority for Meo-owned KWin values.
  # Write explicit user values because plasma-apply-lookandfeel only projects
  # a subset of custom KWin groups into kdedefaults.
  while IFS= read -r line || [ -n "${line}" ]; do
    case "${line}" in
      ''|'#'*|';'*) continue ;;
      '['*']') section="${line:1:${#line}-2}"; continue ;;
      *=*) ;;
      *) continue ;;
    esac
    if [ -z "${section}" ]; then
      echo "Invalid canonical KWin defaults: key outside a section" >&2
      return 1
    fi
    key="${line%%=*}"
    value="${line#*=}"
    run kwriteconfig6 --file "${config_root}/kwinrc" --group "${section}" --key "${key}" "${value}"
  done < "${defaults_file}"
}

kwin_defaults="$(resolve_kwin_defaults)"
if [ -z "${input_helper}" ] && [ -x "${script_root}/../input-method/meo-input-method.sh" ]; then
  input_helper="${script_root}/../input-method/meo-input-method.sh"
fi

if [ "${make_backup}" -eq 1 ] && [ "${dry_run}" -eq 0 ]; then
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  backup_root="${state_root}/backups/${timestamp}-theme-apply"
  run mkdir -p "${backup_root}"
  backup_configs=(kwinrc)
  if [ "${kwin_only}" -eq 0 ]; then
    backup_configs=(kdeglobals kwinrc plasmarc kglobalshortcutsrc plasma-org.kde.plasma.desktop-appletsrc)
  fi
  for config in "${backup_configs[@]}"; do
    if [ -e "${config_root}/${config}" ]; then
      run cp -a "${config_root}/${config}" "${backup_root}/${config}"
    fi
  done
  printf '%s\n' "${backup_root}" > "${state_root}/last-backup"
  info "Backup: ${backup_root}"
fi

if [ "${kwin_only}" -eq 1 ]; then
  apply_kwin_defaults "${kwin_defaults}"
  info "Meo KWin defaults synchronized. They take effect at the next normal login; no compositor restart was requested."
  exit 0
fi

if [ "${reset_layout}" -eq 1 ]; then
  run plasma-apply-lookandfeel -a org.meo.desktop --resetLayout
else
  run plasma-apply-lookandfeel -a org.meo.desktop
fi

# Look-and-Feel establishes the canonical light mode. Derive and select the
# complete Material HCT scheme immediately so native KDE controls, the Dock,
# window decoration and MeoUI start from the same accent source.
if [ -n "${dynamic_color_helper}" ]; then
  run "${dynamic_color_helper}" --apply
fi

# `meo-desktop-apply` is the user's explicit activation action. Keep subsequent
# wallpaper/accent changes synchronized without restarting Plasma or KWin.
if [ "${enable_dynamic_watcher}" = 1 ] && command -v systemctl >/dev/null 2>&1 \
    && systemctl --user cat meo-dynamic-colors.path >/dev/null 2>&1; then
  run systemctl --user enable --now meo-dynamic-colors.path
fi

# Persist the complete canonical KWin profile after Look-and-Feel activation.
# Plasma only copies recognized keys to kdedefaults; explicit values prevent a
# later login from reviving stale decoration/effect settings.
apply_kwin_defaults "${kwin_defaults}"

# Input frameworks own their candidate-window theming. Apply only to an
# already running framework, after Look-and-Feel changed KDE color roles.
if command -v fcitx5-remote >/dev/null 2>&1 \
    && fcitx5-remote --check >/dev/null 2>&1; then
  if [ -z "${input_helper}" ]; then
    echo "Fcitx 5 is running but meo-input-method is unavailable." >&2
    exit 1
  fi
  run "${input_helper}" --enable fcitx5 --quiet
elif command -v pgrep >/dev/null 2>&1 \
    && pgrep -x ibus-daemon >/dev/null 2>&1; then
  if [ -z "${input_helper}" ]; then
    echo "IBus is running but meo-input-method is unavailable." >&2
    exit 1
  fi
  run "${input_helper}" --enable ibus --quiet
fi

if [ "${reset_layout}" -eq 1 ]; then
  launcher_action_display="Activate Application Launcher"
  legacy_shelf_action_display=""
  if [ -f "${config_root}/kglobalshortcutsrc" ]; then
    launcher_action_display="$(awk -F= '$1 == "activate application launcher" { count = split($2, fields, ","); print fields[count]; exit }' "${config_root}/kglobalshortcutsrc")"
    launcher_action_display="${launcher_action_display:-Activate Application Launcher}"
    legacy_shelf_action_display="$(awk -F= '$1 == "activate widget 20" { count = split($2, fields, ","); print fields[count]; exit }' "${config_root}/kglobalshortcutsrc")"
  fi

  run kwriteconfig6 --file kglobalshortcutsrc --group plasmashell --key "activate application launcher" $'Meta\tAlt+F1,Meta\tAlt+F1,'"${launcher_action_display}"
  if [ -n "${legacy_shelf_action_display}" ]; then
    run kwriteconfig6 --file kglobalshortcutsrc --group plasmashell --key "activate widget 20" "none,none,${legacy_shelf_action_display}"
  fi
  run kwriteconfig6 --file kglobalshortcutsrc --group plasmashell --key "activate widget 48" --delete ''
  run kwriteconfig6 --file kglobalshortcutsrc --group plasmashell --key "activate widget 98" --delete ''

  if [ "${dry_run}" -eq 0 ] && command -v busctl >/dev/null 2>&1 \
      && busctl --user status org.kde.kglobalaccel >/dev/null 2>&1; then
    run busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel setForeignShortcut asai 4 plasmashell "activate application launcher" plasmashell "${launcher_action_display}" 2 150994992 16777250
    if [ -n "${legacy_shelf_action_display}" ]; then
      run busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel setForeignShortcut asai 4 plasmashell "activate widget 20" plasmashell "${legacy_shelf_action_display}" 0
    fi
  fi
  info "The packaged layout will be used at the next normal Plasma login; no shell or compositor restart was requested."
fi

info "Meo Desktop theme applied."
