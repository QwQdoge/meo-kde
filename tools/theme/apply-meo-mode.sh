#!/usr/bin/env bash
set -euo pipefail

# Switch the matched Meo color, Plasma and icon variants. Window decoration and
# panel layout are intentionally outside this operation.
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
theme_available() {
  [ -d "${data_root}/plasma/desktoptheme/${desktop_theme}" ] || [ -d "/usr/share/plasma/desktoptheme/${desktop_theme}" ]
}
scheme_available() {
  [ -f "${data_root}/color-schemes/${color_scheme}.colors" ] || [ -f "/usr/share/color-schemes/${color_scheme}.colors" ]
}
icon_theme_available() {
  [ -f "${data_root}/icons/${icon_theme}/index.theme" ] || [ -f "/usr/share/icons/${icon_theme}/index.theme" ]
}
if [ "$dry_run" -eq 1 ]; then
  printf 'plasma-apply-colorscheme %q\n' "$color_scheme"
  printf 'plasma-apply-desktoptheme %q\n' "$desktop_theme"
  printf 'kwriteconfig6 --file %q --group Icons --key Theme %q\n' "${XDG_CONFIG_HOME:-${HOME}/.config}/kdeglobals" "$icon_theme"
  exit 0
fi

theme_available || { echo "Missing Plasma theme: ${desktop_theme}" >&2; exit 1; }
scheme_available || { echo "Missing color scheme: ${color_scheme}" >&2; exit 1; }
icon_theme_available || { echo "Missing icon theme: ${icon_theme}" >&2; exit 1; }

plasma-apply-colorscheme "$color_scheme"
plasma-apply-desktoptheme "$desktop_theme"
kwriteconfig6 --file "${XDG_CONFIG_HOME:-${HOME}/.config}/kdeglobals" --group Icons --key Theme "$icon_theme"
kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
