#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_root="${XDG_CONFIG_HOME:-${HOME}/.config}"
data_root="${XDG_DATA_HOME:-${HOME}/.local/share}"
state_root="${XDG_STATE_HOME:-${HOME}/.local/state}/meo-desktop"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_root="${state_root}/icon-backups/${timestamp}"
theme="Meo"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --theme) theme="${2:?--theme requires Meo, Meo-Mono, or Meo-Outline}"; shift ;;
    *) echo "Usage: $0 [--theme Meo|Meo-Mono|Meo-Outline]" >&2; exit 2 ;;
  esac
  shift
done

case "${theme}" in Meo|Meo-Mono|Meo-Outline) ;; *) echo "Unknown icon theme: ${theme}" >&2; exit 2 ;; esac

vendor_root="${repo_root}/assets/icons/vendor/papirus-icon-theme"
for required in "${vendor_root}/Papirus/index.theme" "${repo_root}/icons/${theme}/index.theme"; do
  [ -f "${required}" ] || { echo "Missing icon resource: ${required}" >&2; exit 1; }
done

mkdir -p "${backup_root}" "${data_root}/icons"
[ ! -f "${config_root}/kdeglobals" ] || cp -a "${config_root}/kdeglobals" "${backup_root}/kdeglobals"

# Installs only icon data. No Plasma layout, panel, wallpaper, QML, font, or
# application configuration is touched by this command.
for upstream_theme in Papirus Papirus-Dark Papirus-Light; do
  rm -rf "${data_root}/icons/${upstream_theme}"
  cp -a "${vendor_root}/${upstream_theme}" "${data_root}/icons/${upstream_theme}"
done
for meo_theme in Meo Meo-Mono Meo-Outline; do
  rm -rf "${data_root}/icons/${meo_theme}"
  cp -a "${repo_root}/icons/${meo_theme}" "${data_root}/icons/${meo_theme}"
done

# Give every installed launcher a deterministic themed fallback. Exact Papirus
# artwork wins; settings modules use the Meo Material settings symbol, and
# otherwise the upstream generic application icon is used. This does not edit
# any .desktop file or alter how applications launch.
alias_root="${data_root}/icons/Meo/scalable/apps"
mkdir -p "${alias_root}"
mapfile -t desktop_files < <(find /usr/share/applications "${HOME}/.local/share/applications" -type f -name '*.desktop' 2>/dev/null | sort -u)
for desktop_file in "${desktop_files[@]}"; do
  icon="$(sed -n 's/^Icon=//p' "${desktop_file}" | head -n 1)"
  case "${icon}" in ''|*/*|*' '*|*.png|*.svg|*.xpm) continue ;; esac
  if find "${data_root}/icons/Papirus" \( -type f -o -type l \) -name "${icon}.svg" -print -quit | grep -q .; then
    continue
  fi
  case "${icon}" in
    preferences-*|kcm_*|systemsettings|kdesystemsettings)
      target="../categories/preferences-system-symbolic.svg" ;;
    steam_icon_*) target="../../../Papirus/48x48/apps/steam.svg" ;;
    *) target="../../../Papirus/48x48/apps/application-default-icon.svg" ;;
  esac
  ln -sfn "${target}" "${alias_root}/${icon}.svg"
done

# The monochrome and outline variants deliberately avoid app-brand artwork.
# Each launcher instead receives a readable MD3 category symbol. This keeps
# the alternate themes coherent while still giving every installed launcher a
# deterministic, meaningful icon.
for variant in Meo-Mono Meo-Outline; do
  alias_root="${data_root}/icons/${variant}/scalable/apps"
  for desktop_file in "${desktop_files[@]}"; do
    icon="$(sed -n 's/^Icon=//p' "${desktop_file}" | head -n 1)"
    categories="$(sed -n 's/^Categories=//p' "${desktop_file}" | head -n 1)"
    case "${icon}" in ''|*/*|*' '*|*.png|*.svg|*.xpm) continue ;; esac
    case ";${categories};" in
      *";Development;"*) symbol="code" ;;
      *";Network;"*|*";WebBrowser;"*) symbol="network" ;;
      *";Game;"*) symbol="games" ;;
      *";AudioVideo;"*|*";Audio;"*|*";Video;"*) symbol="media" ;;
      *";Office;"*) symbol="office" ;;
      *";Graphics;"*) symbol="graphics" ;;
      *";Settings;"*|*";System;"*) symbol="settings" ;;
      *";Utility;"*) symbol="utilities" ;;
      *) symbol="apps" ;;
    esac
    ln -sfn "${symbol}.svg" "${alias_root}/${icon}.svg"
  done
done

kwriteconfig6 --file "${config_root}/kdeglobals" --group Icons --key Theme "${theme}"
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  for icon_theme in Papirus Papirus-Dark Papirus-Light; do
    gtk-update-icon-cache -q -t "${data_root}/icons/${icon_theme}" || true
  done
fi
if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi
printf '%s\n' "${backup_root}" > "${state_root}/last-icon-backup"
printf 'Installed icon theme: %s\nBackup: %s\n' "${theme}" "${backup_root}"
