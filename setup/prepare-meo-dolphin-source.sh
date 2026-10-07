#!/usr/bin/env bash
# Prepare the exact Dolphin source used by the Meo application-chrome pilot.
# This script intentionally stops before a full Dolphin build unless another
# packaging step explicitly consumes the prepared tree.
set -euo pipefail

readonly repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly version="26.08.1"
readonly source_dir="${repo_root}/out/build/application-chrome/dolphin/source"
readonly patch_dir="${repo_root}/native/application-chrome/dolphin/patches"
readonly upstream="https://invent.kde.org/system/dolphin.git"

check_only=false
if [[ "${1:-}" == "--check-only" ]]; then
    check_only=true
elif [[ $# -gt 0 ]]; then
    echo "usage: $0 [--check-only]" >&2
    exit 2
fi

if ! command -v git >/dev/null; then
    echo "git is required." >&2
    exit 1
fi

if [[ ! -d "${source_dir}/.git" ]]; then
    mkdir -p "$(dirname -- "${source_dir}")"
    git clone --depth 1 --branch "v${version}" "${upstream}" "${source_dir}"
fi

git -C "${source_dir}" fetch --depth 1 origin "v${version}"
git -C "${source_dir}" reset --hard "v${version}"
git -C "${source_dir}" clean -fdx

mapfile -t patches < <(find "${patch_dir}" -maxdepth 1 -type f -name '*.patch' -print | sort)
if (( ${#patches[@]} == 0 )); then
    echo "No Dolphin chrome patches found in ${patch_dir}." >&2
    exit 1
fi

for patch in "${patches[@]}"; do
    git -C "${source_dir}" apply --check "${patch}"
done

echo "Validated ${#patches[@]} patch(es) against Dolphin v${version}."

if ${check_only}; then
    exit 0
fi

for patch in "${patches[@]}"; do
    git -C "${source_dir}" apply "${patch}"
done

echo "Prepared patched Dolphin source at ${source_dir}."
