#!/usr/bin/env bash
# Build a separate KWin decoration from the official Breeze release matching
# the installed Plasma stack.  This never overwrites the system Breeze plugin.
set -euo pipefail

readonly repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly version="6.7.4"
readonly source_dir="${repo_root}/out/build/chrome-breeze/source"
readonly build_dir="${repo_root}/out/build/chrome-breeze/build"
readonly patch_file="${repo_root}/native/chrome-breeze/patches/0001-meo-chrome-breeze.patch"
# The plugin stays per-user.  apply-meo-desktop.sh installs a user service
# drop-in that makes this path available to KWin only after the user's next
# normal login; it never restarts or logs out the current desktop session.
readonly plugin_dir="${MEO_KDE_DECORATION_PLUGIN_DIR:-${HOME}/.local/lib/qt6/plugins/org.kde.kdecoration3}"

if ! command -v cmake >/dev/null || ! command -v git >/dev/null; then
    echo "cmake and git are required." >&2
    exit 1
fi

if [[ ! -d "${source_dir}/.git" ]]; then
    mkdir -p "$(dirname -- "${source_dir}")"
    git clone --depth 1 --branch "v${version}" https://invent.kde.org/plasma/breeze.git "${source_dir}"
fi

git -C "${source_dir}" reset --hard "v${version}"
git -C "${source_dir}" clean -fdx
git -C "${source_dir}" apply --check "${patch_file}"
git -C "${source_dir}" apply "${patch_file}"

cmake -S "${repo_root}/native/chrome-breeze" -B "${build_dir}" \
    -DMEO_BREEZE_SOURCE="${source_dir}" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build "${build_dir}" --parallel

mkdir -p "${plugin_dir}"
install -m 0755 "${build_dir}/liborg.meo.chromebreeze.so" "${plugin_dir}/org.meo.chromebreeze.so"
echo "Installed ${plugin_dir}/org.meo.chromebreeze.so"
