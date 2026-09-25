#!/usr/bin/env bash
set -Eeuo pipefail

repo_url="${MEO_KDE_REPO_URL:-https://github.com/QwQdoge/meo-kde.git}"
repo_ref="${MEO_KDE_REF:-main}"
install_root="${MEO_INSTALL_ROOT:-${XDG_CACHE_HOME:-${HOME}/.cache}/meo-installer}"
checkout="${install_root}/meo-kde"

usage() {
  cat <<'EOF'
Meo Desktop bootstrap

Usage:
  curl -fsSL <bootstrap-url> | bash
  curl -fsSL <bootstrap-url> | bash -s -- --full
  curl -fsSL <bootstrap-url> | bash -s -- --full --kde-only

Environment:
  MEO_KDE_REPO_URL  Override the MeoKDE Git repository.
  MEO_KDE_REF       Branch/tag/commit to install. Defaults to main.
  MEO_INSTALL_ROOT  Cache directory for the installer checkout.

All remaining arguments are forwarded to ./install.sh.
EOF
}

if [ "${1:-}" = "--help-bootstrap" ]; then
  usage
  exit 0
fi

if [ "$(uname -s)" != Linux ]; then
  echo "Meo Desktop bootstrap requires Linux." >&2
  exit 1
fi

command -v git >/dev/null 2>&1 || {
  echo "git is required before the remote bootstrap can continue." >&2
  echo "On Arch: sudo pacman -S git" >&2
  exit 1
}

mkdir -p "${install_root}"

if [ -d "${checkout}/.git" ]; then
  if [ -n "$(git -C "${checkout}" status --porcelain)" ]; then
    echo "Existing MeoKDE bootstrap checkout has local changes:" >&2
    echo "  ${checkout}" >&2
    echo "Refusing to overwrite it. Set MEO_INSTALL_ROOT to another directory." >&2
    exit 1
  fi
  git -C "${checkout}" fetch --prune origin
  if git -C "${checkout}" show-ref --verify --quiet "refs/remotes/origin/${repo_ref}"; then
    git -C "${checkout}" checkout --detach "origin/${repo_ref}"
  else
    git -C "${checkout}" fetch --depth 1 origin "${repo_ref}"
    git -C "${checkout}" checkout --detach FETCH_HEAD
  fi
else
  rm -rf "${checkout}"
  git clone --filter=blob:none --no-checkout "${repo_url}" "${checkout}"
  git -C "${checkout}" fetch --depth 1 origin "${repo_ref}"
  git -C "${checkout}" checkout --detach FETCH_HEAD
fi

if [ ! -x "${checkout}/install.sh" ]; then
  echo "Selected MeoKDE revision does not contain an executable install.sh." >&2
  exit 1
fi

# curl | bash owns stdin, but the actual installer is intentionally
# interactive. Reattach it to the controlling terminal when available so the
# Yes/No wizard still works from a one-line remote bootstrap.
if [ -r /dev/tty ] && [ -w /dev/tty ]; then
  exec "${checkout}/install.sh" "$@" </dev/tty >/dev/tty
fi

exec "${checkout}/install.sh" "$@"
