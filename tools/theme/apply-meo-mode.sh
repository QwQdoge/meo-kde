#!/usr/bin/env bash
set -euo pipefail

# Switch the matched Meo color, Plasma and icon variants as one bounded
# presentation transaction. Window decoration, wallpaper and panel layout are
# intentionally outside this operation.
mode="${1:-}"
dry_run=0
if [ "${2:-}" = "--dry-run" ]; then
  dry_run=1
fi
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ] || { [ "$mode" != "light" ] && [ "$mode" != "dark" ]; }; then
  echo "Usage: $0 {light|dark} [--dry-run]" >&2
  exit 2
fi

if [ "$mode" = "light" ]; then
  color_scheme=MeoLight
  desktop_theme=MeoLight
  icon_theme=MeoSymbols
else
  color_scheme=MeoDark
  desktop_theme=MeoDark
  icon_theme=MeoSymbolsDark
fi

data_root="${XDG_DATA_HOME:-${HOME}/.local/share}"
config_root="${XDG_CONFIG_HOME:-${HOME}/.config}"
dynamic_color_helper="${MEO_DYNAMIC_COLORS_HELPER:-}"
if [ -z "${dynamic_color_helper}" ] && command -v meo-dynamic-colors >/dev/null 2>&1; then
  dynamic_color_helper="$(command -v meo-dynamic-colors)"
fi

theme_available() {
  [ -d "${data_root}/plasma/desktoptheme/${desktop_theme}" ] || [ -d "/usr/share/plasma/desktoptheme/${desktop_theme}" ]
}

scheme_available() {
  [ -f "${data_root}/color-schemes/${color_scheme}.colors" ] || [ -f "/usr/share/color-schemes/${color_scheme}.colors" ]
}

icon_theme_available() {
  [ -f "${data_root}/icons/${icon_theme}/index.theme" ] || [ -f "/usr/share/icons/${icon_theme}/index.theme" ]
}

read_ini_value() {
  local file="$1" group="$2" key="$3"
  [ -f "${file}" ] || return 0
  awk -v wanted_group="${group}" -v wanted_key="${key}" '
    $0 == "[" wanted_group "]" { in_group=1; next }
    /^\[/ { in_group=0 }
    in_group && index($0, wanted_key "=") == 1 {
      value=$0
      sub("^[^=]*=", "", value)
      print value
      exit
    }
  ' "${file}"
}

# App identity overlays are active KDE icon themes, not passive directories.
# Preserve their light/dark counterpart when the user intentionally switches
# Meo mode; otherwise this script would silently replace MeoUser with only its
# system-semantic parent and make the selected application pack disappear.
current_icon_theme="$(read_ini_value "${config_root}/kdeglobals" Icons Theme)"
if [ "${current_icon_theme}" = "MeoUser" ] || [ "${current_icon_theme}" = "MeoUserDark" ]; then
  if [ "${mode}" = "light" ]; then
    overlay_icon_theme="MeoUser"
  else
    overlay_icon_theme="MeoUserDark"
  fi
  if [ -f "${data_root}/icons/${overlay_icon_theme}/index.theme" ] || [ -f "/usr/share/icons/${overlay_icon_theme}/index.theme" ]; then
    icon_theme="${overlay_icon_theme}"
  else
    echo "Meo application icon overlay is active but ${overlay_icon_theme} is unavailable; retaining the system icon theme." >&2
  fi
fi

if [ "$dry_run" -eq 1 ]; then
  printf 'plasma-apply-colorscheme %q\n' "$color_scheme"
  if [ -n "${dynamic_color_helper}" ]; then
    printf '%q --apply\n' "${dynamic_color_helper}"
  fi
  printf 'plasma-apply-desktoptheme %q\n' "$desktop_theme"
  printf 'kwriteconfig6 --file %q --group Icons --key Theme %q\n' "${config_root}/kdeglobals" "$icon_theme"
  exit 0
fi

theme_available || { echo "Missing Plasma theme: ${desktop_theme}" >&2; exit 1; }
scheme_available || { echo "Missing color scheme: ${color_scheme}" >&2; exit 1; }
icon_theme_available || { echo "Missing icon theme: ${icon_theme}" >&2; exit 1; }

for command in plasma-apply-colorscheme plasma-apply-desktoptheme kwriteconfig6; do
  command -v "${command}" >/dev/null 2>&1 || {
    echo "Required command is unavailable: ${command}" >&2
    exit 1
  }
done

prior_color_scheme="$(read_ini_value "${config_root}/kdeglobals" General ColorScheme)"
prior_desktop_theme="$(read_ini_value "${config_root}/plasmarc" Theme name)"
prior_icon_theme="${current_icon_theme}"
transaction_active=1
rollback_in_progress=0

restore_key() {
  local file="$1" group="$2" key="$3" value="$4"
  if [ -n "${value}" ]; then
    kwriteconfig6 --file "${file}" --group "${group}" --key "${key}" "${value}" >/dev/null 2>&1 || true
  else
    kwriteconfig6 --file "${file}" --group "${group}" --key "${key}" --delete '' >/dev/null 2>&1 || true
  fi
}

rollback_mode_transaction() {
  [ "${transaction_active}" -eq 1 ] || return 0
  [ "${rollback_in_progress}" -eq 0 ] || return 0
  rollback_in_progress=1
  set +e

  echo "Meo appearance switch failed; restoring the previous presentation state." >&2

  if [ -n "${prior_color_scheme}" ]; then
    plasma-apply-colorscheme "${prior_color_scheme}" >/dev/null 2>&1 || true
  fi
  if [ -n "${prior_desktop_theme}" ]; then
    plasma-apply-desktoptheme "${prior_desktop_theme}" >/dev/null 2>&1 || true
  fi
  restore_key "${config_root}/kdeglobals" General ColorScheme "${prior_color_scheme}"
  restore_key "${config_root}/plasmarc" Theme name "${prior_desktop_theme}"
  restore_key "${config_root}/kdeglobals" Icons Theme "${prior_icon_theme}"

  if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
  fi
  transaction_active=0
}

on_error() {
  local status=$?
  trap - ERR INT TERM HUP
  rollback_mode_transaction
  exit "${status}"
}

on_signal() {
  trap - ERR INT TERM HUP
  rollback_mode_transaction
  exit 130
}

trap on_error ERR
trap on_signal INT TERM HUP

plasma-apply-colorscheme "$color_scheme"
# Establish light/dark with the shipped scheme first, then derive the complete
# HCT scheme from the active accent. This also makes dark -> light transitions
# deterministic because the generator observes the mode just selected above.
if [ -n "${dynamic_color_helper}" ]; then
  "${dynamic_color_helper}" --apply
fi
plasma-apply-desktoptheme "$desktop_theme"
kwriteconfig6 --file "${config_root}/kdeglobals" --group Icons --key Theme "$icon_theme"

# A successful command sequence is not enough: verify the two state values that
# this script owns directly before committing the transaction. Dynamic colour
# generation may intentionally replace General/ColorScheme with a derived Meo
# scheme, so that key is restored on failure but is not constrained here.
applied_desktop_theme="$(read_ini_value "${config_root}/plasmarc" Theme name)"
applied_icon_theme="$(read_ini_value "${config_root}/kdeglobals" Icons Theme)"
if [ "${applied_desktop_theme}" != "${desktop_theme}" ]; then
  echo "Plasma theme verification failed: expected ${desktop_theme}, got ${applied_desktop_theme:-<unset>}." >&2
  false
fi
if [ "${applied_icon_theme}" != "${icon_theme}" ]; then
  echo "Icon theme verification failed: expected ${icon_theme}, got ${applied_icon_theme:-<unset>}." >&2
  false
fi

transaction_active=0
trap - ERR INT TERM HUP

if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi

# Refresh only input frameworks already using a Meo presentation. The helper
# never enables or starts an input method as part of a color-mode switch.
if command -v meo-input-method >/dev/null 2>&1; then
  meo-input-method --sync --quiet || true
fi
