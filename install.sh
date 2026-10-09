#!/usr/bin/env bash
set -Eeuo pipefail

# Public installer entry point for an existing Arch system.
#
# Installing Meo Desktop must be equivalent to installing another desktop
# environment: add the package-owned Wayland session and shared runtime, but do
# not rewrite the currently logged-in Plasma profile, panels, theme, display
# manager choice, or default session. Developer source deployment remains in
# setup/apply-meo-desktop.sh and is intentionally not called from here.

minimum_safe_version="0.4.0-14"
dry_run=0
auto_yes=0

usage() {
  cat <<'EOF'
Meo Desktop Installer

Usage:
  ./install.sh
  ./install.sh -y
  ./install.sh --dry-run

This installs the signed `meo-desktop` package from the configured MeoArch
repository. It adds a separate "Meo Desktop" Wayland login option and leaves
normal KDE Plasma configuration untouched.

Options:
  -y, --yes    Run pacman non-interactively.
  --dry-run    Validate repository/package readiness without installing.
  -h, --help   Show this help.

The Meo repository must already be configured through the official MeoArch
keyring/channel packages. This script never downloads or trusts a key itself.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -y|--yes) auto_yes=1 ;;
    --dry-run) dry_run=1 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

fail() {
  printf 'Meo Desktop installer: %s\n' "$*" >&2
  exit 1
}

command -v pacman >/dev/null 2>&1 || fail "pacman is required; this installer supports Arch/MeoArch systems."
command -v pacman-conf >/dev/null 2>&1 || fail "pacman-conf is required."
command -v vercmp >/dev/null 2>&1 || fail "vercmp is required (provided by pacman)."
[ -e /etc/arch-release ] || fail "this does not look like an Arch-compatible system."

repo_list="$(pacman-conf --repo-list 2>/dev/null || true)"
if ! grep -Eq '^(meo|meo-beta)$' <<<"${repo_list}"; then
  fail "the signed MeoArch repository is not configured. Install the official meo-keyring, meo-mirrorlist and meo-channel package first."
fi

package_info="$(pacman -Si meo-desktop 2>/dev/null)" || \
  fail "meo-desktop is not available from the configured repositories. Do not fall back to the old source installer."
available_version="$(awk -F ': *' '$1 == "Version" {print $2; exit}' <<<"${package_info}")"
[ -n "${available_version}" ] || fail "could not determine the repository meo-desktop version."
if [ "$(vercmp "${available_version}" "${minimum_safe_version}")" -lt 0 ]; then
  fail "repository meo-desktop ${available_version} is too old; ${minimum_safe_version} or newer is required for the isolated session."
fi

printf 'Meo Desktop %s is available.\n' "${available_version}"
printf 'Install effect: add the Meo Desktop login session; preserve the normal KDE profile.\n'

if [ "${dry_run}" -eq 1 ]; then
  printf 'Dry run passed. Would execute: sudo pacman -Syu --needed %smeo-desktop\n' \
    "$([ "${auto_yes}" -eq 1 ] && printf '%s' '--noconfirm ' || true)"
  exit 0
fi

command -v sudo >/dev/null 2>&1 || fail "sudo is required for package installation."
sudo -v
pacman_args=(-Syu --needed)
[ "${auto_yes}" -eq 0 ] || pacman_args+=(--noconfirm)
sudo pacman "${pacman_args[@]}" meo-desktop

required_paths=(
  /usr/bin/startmeo-wayland
  /usr/share/wayland-sessions/meo.desktop
  /usr/share/meo-desktop/session-defaults/kdeglobals
  /usr/share/meo-desktop/session-defaults/kwinrc
  /usr/share/meo-desktop/session-defaults/plasmarc
  /usr/share/meo-desktop/session-defaults/meo-shellrc
)
for path in "${required_paths[@]}"; do
  [ -s "${path}" ] || fail "installed package is missing ${path}."
done
[ -x /usr/bin/startmeo-wayland ] || fail "installed Meo session launcher is not executable."
grep -Fq 'Exec=/usr/bin/startmeo-wayland' /usr/share/wayland-sessions/meo.desktop || \
  fail "installed Meo session entry does not use the isolated launcher."

# Package ownership is part of the contract: a manual source copy must not
# masquerade as a successfully installed desktop environment.
for path in /usr/bin/startmeo-wayland /usr/share/wayland-sessions/meo.desktop; do
  owner="$(LC_ALL=C pacman -Qo "${path}" 2>/dev/null || true)"
  case "${owner}" in
    "${path} is owned by meo-desktop "*) ;;
    *) fail "${path} is not owned by meo-desktop." ;;
  esac
done

# These paths belonged to the old global-overlay design. The package must no
# longer own them; existing user/system files from another package are left
# untouched rather than deleted.
for path in \
  /etc/xdg/kdeglobals \
  /etc/xdg/kwinrc \
  /etc/xdg/plasmarc \
  /etc/xdg/meo-shellrc \
  /etc/environment.d/90-meo-applications.conf \
  /etc/xdg/fcitx5/conf/classicui.conf; do
  owner="$(LC_ALL=C pacman -Qo "${path}" 2>/dev/null || true)"
  case "${owner}" in
    *" is owned by meo-desktop "*) fail "meo-desktop still owns global Plasma configuration: ${path}." ;;
    *) ;;
  esac
done

printf '\nMeo Desktop is installed. Log out normally and choose "Meo Desktop" from the login session list.\n'
printf 'Your existing KDE Plasma session and configuration were not rewritten by this installer.\n'
