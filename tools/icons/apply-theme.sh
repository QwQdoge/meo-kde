#!/usr/bin/env bash
set -euo pipefail

dry_run=0
[ "${1:-}" != "--dry-run" ] || dry_run=1
[ "$#" -eq 0 ] || [ "${1:-}" = "--dry-run" ] || { echo "Usage: $0 [--dry-run]" >&2; exit 2; }
config_root="${XDG_CONFIG_HOME:-${HOME}/.config}"
state_root="${XDG_STATE_HOME:-${HOME}/.local/state}/meo-desktop"
theme_root="${XDG_DATA_HOME:-${HOME}/.local/share}/icons/MeoSymbols"
[ -f "${theme_root}/index.theme" ] || { echo "Install MeoSymbols first." >&2; exit 1; }
if [ "${dry_run}" -eq 1 ]; then
  printf 'kwriteconfig6 --file %q --group Icons --key Theme MeoSymbols\n' "${config_root}/kdeglobals"
  exit 0
fi
backup="${state_root}/icon-backups/MeoSymbols-apply-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "${backup}"
[ ! -f "${config_root}/kdeglobals" ] || cp -a "${config_root}/kdeglobals" "${backup}/kdeglobals"
kwriteconfig6 --file "${config_root}/kdeglobals" --group Icons --key Theme MeoSymbols
kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
