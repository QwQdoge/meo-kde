#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
output_root="${MEO_OUTPUT_ROOT:-${HOME}/Projects/outputs/meo-kde}"
run_id="$(date -u +%Y-%m-%dT%H%M%SZ)-lockscreen-package"
work_dir="${output_root}/tmp/${run_id}"
package_dir="${output_root}/packages"
validation_dir="${output_root}/validation/${run_id}"

mkdir -p "${work_dir}" "${package_dir}" "${validation_dir}"
cp -a "${repo_root}/packaging/arch/meo-lockscreen/." "${work_dir}/"

# The PKGBUILD intentionally reads Meo-owned wrapper/config files from this
# checkout. Point it back at the source tree after copying the recipe.
export MEO_KDE_SOURCE_DIR="${repo_root}"

(
    cd "${work_dir}"
    makepkg --cleanbuild --syncdeps --noconfirm
)

shopt -s nullglob
packages=("${work_dir}"/*.pkg.tar.*)
if (( ${#packages[@]} == 0 )); then
    echo "No Arch package was produced" >&2
    exit 1
fi

for package in "${packages[@]}"; do
    cp -a "${package}" "${package_dir}/"
done

{
    echo "# Meo session-lock package validation"
    echo
    echo "- Run: ${run_id}"
    echo "- Repository: ${repo_root}"
    echo "- Commit: $(git -C "${repo_root}" rev-parse HEAD)"
    echo "- Upstream lock-source pin: 20e625d6bf1a9d0bb7625a4bb814797d187b075d"
    echo "- Meo visual contract: shell.json + Meo light/dark role tables"
    echo "- makepkg: passed"
    echo "- Runtime lock/unlock test: not run by this build script"
    echo
    echo "Artifacts:"
    for package in "${packages[@]}"; do
        basename "${package}"
    done
} > "${validation_dir}/README.md"

printf 'Packages copied to %s\nValidation record: %s\n' "${package_dir}" "${validation_dir}/README.md"
