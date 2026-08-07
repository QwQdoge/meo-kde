#!/usr/bin/env bash
set -euo pipefail

source_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workspace="${1:-/home/shekong/Projects/meo-arch-os-workspace}"
destination="${workspace}/meo-desktop"

if [ ! -d "${workspace}/meoarch-os" ] || [ ! -d "${destination}" ]; then
  echo "Not a MeoArch ISO workspace: ${workspace}" >&2
  exit 2
fi

for directory in assets defaults docs icons native packaging plasmoids qml setup themes; do
  rm -rf "${destination:?}/${directory}"
  cp -a "${source_root}/${directory}" "${destination}/${directory}"
done
# Packaging caches are local build products, never ISO source inputs.
rm -rf "${destination}/packaging/arch/pkg" \
       "${destination}/packaging/arch/src"
find "${destination}/packaging/arch" -maxdepth 1 -type f -name '*.pkg.tar.*' -delete
install -Dm644 "${source_root}/README.md" "${destination}/README.md"
install -Dm644 "${source_root}/MIGRATION.md" "${destination}/MIGRATION.md"

echo "Synced Meo KDE integration snapshot to ${destination}"
