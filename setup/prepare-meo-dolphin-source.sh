#!/usr/bin/env bash
# Prepare the pinned Dolphin presentation patch series without discarding work.
set -euo pipefail

readonly repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly version="26.08.1"
readonly output_root="${MEO_OUTPUT_ROOT:-${repo_root}/../outputs}"
readonly patch_dir="${repo_root}/native/application-chrome/dolphin/patches"
readonly upstream="https://invent.kde.org/system/dolphin.git"
source_dir="${output_root}/meo-kde/build/application-chrome/dolphin/${version}/source"
check_only=false

while (( $# )); do
    case "$1" in
        --check-only) check_only=true; shift ;;
        --source-dir)
            if (( $# < 2 )) || [[ -z "$2" ]]; then
                echo "--source-dir requires a path." >&2; exit 2
            fi
            source_dir="$2"; shift 2 ;;
        *) echo "usage: $0 [--check-only] [--source-dir PATH]" >&2; exit 2 ;;
    esac
done

command -v git >/dev/null || { echo "git is required." >&2; exit 1; }
if [[ ! -e "${source_dir}" ]]; then
    mkdir -p -- "$(dirname -- "${source_dir}")"
    git clone --depth 1 --branch "v${version}" -- "${upstream}" "${source_dir}"
fi
# Never reset, clean or checkout an existing source tree. Also reject paths
# inside another repository (git -C alone would silently discover its parent).
if [[ ! -e "${source_dir}/.git" ]]; then
    echo "Existing source is not a Git checkout; choose a new --source-dir. Nothing was changed." >&2
    exit 1
fi
if ! baseline="$(git -C "${source_dir}" rev-parse --verify "refs/tags/v${version}^{commit}")"; then
    echo "Source checkout lacks the pinned Dolphin tag; choose a new --source-dir." >&2; exit 1
fi
if [[ "$(git -C "${source_dir}" rev-parse HEAD)" != "${baseline}" ]]; then
    echo "Source HEAD differs from Dolphin v${version}; existing work was preserved." >&2; exit 1
fi
mapfile -t patches < <(find "${patch_dir}" -maxdepth 1 -type f -name '*.patch' -print | sort)
if (( ${#patches[@]} == 0 )); then
    echo "No Dolphin chrome patches found in ${patch_dir}." >&2; exit 1
fi
if [[ -n "$(git -C "${source_dir}" status --porcelain)" ]]; then
    if git -C "${source_dir}" apply --reverse --check "${patches[@]}" 2>/dev/null; then
        echo "All ${#patches[@]} Meo patches are already present; existing source was preserved."
        exit 0
    fi
    echo "Source has existing changes or a partial patch series. Nothing was changed; use a new --source-dir." >&2
    exit 1
fi
# Validate the complete series together before making a single atomic apply.
git -C "${source_dir}" apply --check "${patches[@]}"
echo "Validated ${#patches[@]} patch(es) against Dolphin v${version}."
if ${check_only}; then exit 0; fi
git -C "${source_dir}" apply "${patches[@]}"
echo "Prepared patched Dolphin source at ${source_dir}."
