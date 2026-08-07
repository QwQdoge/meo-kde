#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
papirus_root="${repo_root}/assets/icons/vendor/papirus-icon-theme/Papirus"
report_root="${repo_root}/validation/reports"
mkdir -p "${report_root}"

mapfile -t desktop_files < <(find /usr/share/applications "${HOME}/.local/share/applications" -type f -name '*.desktop' 2>/dev/null | sort -u)
total=0
matched=0
missing=()
for desktop_file in "${desktop_files[@]}"; do
  icon="$(sed -n 's/^Icon=//p' "${desktop_file}" | head -n 1)"
  [ -n "${icon}" ] || continue
  case "${icon}" in /*|*.png|*.svg|*.xpm) continue ;; esac
  total=$((total + 1))
  if find "${papirus_root}" \( -type f -o -type l \) \( -name "${icon}.svg" -o -name "${icon}.png" -o -name "${icon}.xpm" \) -print -quit | grep -q .; then
    matched=$((matched + 1))
  else
    missing+=("${icon}")
  fi
done

{
  echo "# Meo icon coverage"
  echo
  echo "- Desktop entries with a theme icon: ${total}"
  echo "- Exact Papirus icon matches: ${matched}"
  echo "- Resolver fallback: Papirus -> Breeze -> hicolor -> application-x-executable"
  echo
  echo "## Missing exact Papirus names"
  for icon in "${missing[@]}"; do echo "- ${icon}"; done
} > "${report_root}/icon-coverage.md"

printf 'desktop_entries=%s exact_papirus_matches=%s missing=%s\n' "${total}" "${matched}" "${#missing[@]}"
