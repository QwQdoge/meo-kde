#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
data_root="${XDG_DATA_HOME:-${HOME}/.local/share}"
state_root="${XDG_STATE_HOME:-${HOME}/.local/state}/meo-desktop"
themes=(MeoSymbols MeoSymbolsDark)

case "${1:-}" in
  "" ) ;;
  --uninstall)
    quarantine="${state_root}/removed-icons/MeoSymbols-pair-$(date -u +%Y%m%dT%H%M%SZ)"
    mkdir -p "${quarantine}"
    for theme_name in "${themes[@]}"; do
      destination="${data_root}/icons/${theme_name}"
      [ ! -d "${destination}" ] || mv "${destination}" "${quarantine}/${theme_name}"
    done
    exit 0
    ;;
  *) echo "Usage: $0 [--uninstall]" >&2; exit 2 ;;
esac

mkdir -p "${data_root}/icons"
mkdir -p "${state_root}"
install_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
for theme_name in "${themes[@]}"; do
  source_theme="${repo_root}/themes/icons/${theme_name}"
  destination="${data_root}/icons/${theme_name}"
  [ -f "${source_theme}/index.theme" ] || { echo "Build ${theme_name} first." >&2; exit 1; }
  staging="${data_root}/icons/.${theme_name}.staging-$$"
  cp -a "${source_theme}" "${staging}"
  if [ -d "${destination}" ]; then
    previous="${state_root}/icon-backups/MeoSymbols-pair-${install_stamp}"
    mkdir -p "${previous}"
    mv "${destination}" "${previous}/${theme_name}"
  fi
  mv "${staging}" "${destination}"
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t "${destination}" || true
  fi
done
