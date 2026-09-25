#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
apply_script="${repo_root}/setup/apply-meo-desktop.sh"
official_meoui_repo="https://github.com/QwQdoge/MeoUI.git"

full_mode=0
auto_yes=0
dry_run=0
force_no_color=0

usage() {
  cat <<'EOF'
Meo Desktop Installer

Usage:
  ./install.sh            Interactive guided installation
  ./install.sh --full     Apply the recommended complete Meo desktop
  ./install.sh --dry-run  Preview the guided install without changing files

Options:
  --full       Non-interactive recommended setup: apply Meo and reset the panel layout
  -y, --yes    Accept the recommended answers in the guided installer
  --dry-run    Show the underlying commands without applying changes
  --no-color   Disable ANSI color
  -h, --help   Show this help

Environment:
  MEO_UI_ROOT  Path to a MeoUI source checkout. The installer also discovers
               ../meo-ui, ../MeoUI, and ../meoui automatically.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --full) full_mode=1; auto_yes=1 ;;
    -y|--yes) auto_yes=1 ;;
    --dry-run) dry_run=1 ;;
    --no-color) force_no_color=1 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [ ! -x "${apply_script}" ]; then
  printf 'Meo installer backend is missing or not executable: %s\n' "${apply_script}" >&2
  exit 1
fi

interactive=0
if [ -t 0 ] && [ -t 1 ] && [ "${full_mode}" -eq 0 ]; then
  interactive=1
fi
if [ "${interactive}" -eq 0 ] && [ "${full_mode}" -eq 0 ] && [ "${auto_yes}" -eq 0 ]; then
  printf 'Interactive input is unavailable. Use --full for the recommended setup.\n\n' >&2
  usage >&2
  exit 2
fi

use_color=0
if [ "${force_no_color}" -eq 0 ] && [ -z "${NO_COLOR:-}" ] && [ -t 1 ]; then
  case "${TERM:-dumb}" in
    dumb|"") ;;
    *) use_color=1 ;;
  esac
fi

if [ "${use_color}" -eq 1 ]; then
  reset=$'\033[0m'
  bold=$'\033[1m'
  dim=$'\033[2m'
  accent=$'\033[38;5;111m'
  accent2=$'\033[38;5;147m'
  good=$'\033[38;5;114m'
  warn=$'\033[38;5;221m'
  bad=$'\033[38;5;203m'
  muted=$'\033[38;5;245m'
else
  reset=''; bold=''; dim=''; accent=''; accent2=''; good=''; warn=''; bad=''; muted=''
fi

supports_unicode=0
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
  *UTF-8*|*utf8*|*UTF8*) supports_unicode=1 ;;
esac

if [ "${supports_unicode}" -eq 1 ]; then
  mark_ok="✓"
  mark_warn="!"
  mark_step="◆"
  bar="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
  mark_ok="[ok]"
  mark_warn="[!]"
  mark_step="*"
  bar="----------------------------------------------------"
fi

say() {
  printf '%s\n' "$*"
}

section() {
  printf '\n%s%s %s%s\n' "${accent}" "${mark_step}" "$1" "${reset}"
}

ok() {
  printf '  %s%s%s %s\n' "${good}" "${mark_ok}" "${reset}" "$1"
}

note() {
  printf '  %s%s%s %s\n' "${muted}" "·" "${reset}" "$1"
}

warning() {
  printf '  %s%s%s %s\n' "${warn}" "${mark_warn}" "${reset}" "$1"
}

die() {
  printf '\n%sError:%s %s\n' "${bad}${bold}" "${reset}" "$*" >&2
  exit 1
}

header() {
  printf '\n%s%s%s\n' "${accent}" "${bar}" "${reset}"
  printf '%s%s   Meo Desktop%s\n' "${bold}" "${accent2}" "${reset}"
  printf '%s   Expressive Plasma experience installer%s\n' "${dim}" "${reset}"
  printf '%s%s%s\n\n' "${accent}" "${bar}" "${reset}"
}

prompt_yes_no() {
  local question="$1"
  local default_answer="${2:-yes}"
  local reply suffix

  if [ "${auto_yes}" -eq 1 ]; then
    [ "${default_answer}" = yes ]
    return
  fi

  if [ "${default_answer}" = yes ]; then
    suffix="[Y/n]"
  else
    suffix="[y/N]"
  fi

  while true; do
    printf '  %s%s%s %s %s ' "${bold}" "?" "${reset}" "${question}" "${suffix}"
    IFS= read -r reply || reply=""
    reply="${reply,,}"
    case "${reply}" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      "")
        [ "${default_answer}" = yes ]
        return
        ;;
      *) warning "Please answer yes or no." ;;
    esac
  done
}

git_branch() {
  local root="$1"
  git -C "${root}" branch --show-current 2>/dev/null || true
}

discover_meoui() {
  local candidate

  if [ -n "${MEO_UI_ROOT:-}" ] && [ -f "${MEO_UI_ROOT}/CMakeLists.txt" ]; then
    printf '%s' "${MEO_UI_ROOT}"
    return 0
  fi

  if [ -n "${MEOUI_PROJECT_ROOT:-}" ] && [ -f "${MEOUI_PROJECT_ROOT}/CMakeLists.txt" ]; then
    printf '%s' "${MEOUI_PROJECT_ROOT}"
    return 0
  fi

  for candidate in     "${repo_root}/../meo-ui"     "${repo_root}/../MeoUI"     "${repo_root}/../meoui"; do
    if [ -f "${candidate}/CMakeLists.txt" ]; then
      (cd "${candidate}" && pwd)
      return 0
    fi
  done

  return 1
}

clone_meoui() {
  local target="${repo_root}/../MeoUI"

  command -v git >/dev/null 2>&1 || die "git is required to obtain MeoUI."
  if [ -e "${target}" ]; then
    die "Cannot clone MeoUI because ${target} already exists but is not a usable checkout."
  fi

  section "MeoUI"
  note "Cloning the official MeoUI source beside MeoKDE."
  if [ "${dry_run}" -eq 1 ]; then
    printf '  %s$%s git clone --depth 1 %q %q\n' "${muted}" "${reset}" "${official_meoui_repo}" "${target}"
  else
    git clone --depth 1 "${official_meoui_repo}" "${target}"
  fi
  MEO_UI_ROOT="${target}"
  export MEO_UI_ROOT
}

on_error() {
  local exit_code=$?
  printf '\n%sInstallation stopped%s (exit %d).\n' "${bad}${bold}" "${reset}" "${exit_code}" >&2
  printf '%sNothing after the failed step is reported as installed.%s\n' "${muted}" "${reset}" >&2
  printf 'You can restore the last completed Meo change with:\n  %s./setup/reset-meo-desktop.sh%s\n' "${accent}" "${reset}" >&2
  exit "${exit_code}"
}
trap on_error ERR

header

section "Preflight"
if [ "$(uname -s)" != Linux ]; then
  die "Meo Desktop source installation is supported on Linux."
fi
ok "Linux host detected"

if command -v plasmashell >/dev/null 2>&1; then
  plasma_version="$(plasmashell --version 2>/dev/null | awk '{print $2}' || true)"
  note "Plasma: ${plasma_version:-detected}"
else
  warning "Plasma was not found in PATH. The backend preflight will stop before changing anything."
fi

meoui_root=""
if meoui_root="$(discover_meoui)"; then
  MEO_UI_ROOT="${meoui_root}"
  export MEO_UI_ROOT
  ok "MeoUI source: ${MEO_UI_ROOT}"
else
  warning "No MeoUI source checkout was found."
  if [ "${dry_run}" -eq 1 ]; then
    die "--dry-run cannot validate a missing MeoUI checkout. Clone MeoUI first or set MEO_UI_ROOT."
  elif [ "${full_mode}" -eq 1 ]; then
    clone_meoui
  elif prompt_yes_no "Clone the official MeoUI repository beside MeoKDE?" yes; then
    clone_meoui
  else
    die "MeoUI is required. Set MEO_UI_ROOT or place a checkout beside this repository."
  fi
fi

meokde_branch="$(git_branch "${repo_root}")"
meoui_branch="$(git_branch "${MEO_UI_ROOT}")"
[ -n "${meokde_branch}" ] && note "MeoKDE branch: ${meokde_branch}"
[ -n "${meoui_branch}" ] && note "MeoUI branch: ${meoui_branch}"

apply_now=yes
reset_layout=yes
update_meoui=no

if [ "${full_mode}" -eq 0 ]; then
  section "Choose your experience"
  if prompt_yes_no "Apply the Meo theme, components, dynamic colors and native integration now?" yes; then
    apply_now=yes
  else
    apply_now=no
  fi

  if [ "${apply_now}" = yes ]; then
    if prompt_yes_no "Rebuild the top bar and Dock to the recommended Meo layout?" yes; then
      reset_layout=yes
    else
      reset_layout=no
    fi
  else
    reset_layout=no
  fi

  if [ "${meoui_branch}" = main ]; then
    if prompt_yes_no "Fast-forward the MeoUI main checkout before building?" no; then
      update_meoui=yes
    fi
  elif [ -n "${meoui_branch}" ]; then
    note "MeoUI update is not offered on branch '${meoui_branch}'; your development checkout is preserved."
  fi
fi

section "Plan"
if [ "${apply_now}" = yes ]; then
  ok "Install and apply Meo Desktop"
else
  note "Install Meo Desktop files without switching the current theme"
fi
if [ "${reset_layout}" = yes ]; then
  ok "Apply recommended top bar + native Dock layout"
else
  note "Preserve the current panel layout"
fi
if [ "${update_meoui}" = yes ]; then
  ok "Fast-forward MeoUI main before build"
else
  note "Build the current MeoUI checkout exactly as it is"
fi
if [ "${dry_run}" -eq 1 ]; then
  warning "Preview mode: no filesystem or desktop changes will be made by the backend."
fi
note "A timestamped backup is created before Meo replaces user configuration."

if [ "${full_mode}" -eq 0 ] && [ "${auto_yes}" -eq 0 ]; then
  printf '\n'
  if ! prompt_yes_no "Start with this plan?" yes; then
    say ""
    note "Cancelled. No installer changes were started."
    exit 0
  fi
fi

args=()
if [ "${apply_now}" = yes ]; then
  args+=(--apply)
fi
if [ "${reset_layout}" = yes ]; then
  args+=(--reset-layout)
fi
if [ "${update_meoui}" = yes ]; then
  args+=(--update-meoui)
else
  args+=(--no-update-meoui)
fi
if [ "${dry_run}" -eq 1 ]; then
  args+=(--dry-run)
fi

section "Installing"
note "The backend builds MeoUI and native MeoKDE components before touching user configuration."
printf '\n'
MEO_UI_ROOT="${MEO_UI_ROOT}" "${apply_script}" "${args[@]}"

trap - ERR
printf '\n'
section "Finished"
ok "Meo Desktop installation completed"
if [ "${apply_now}" = yes ]; then
  ok "The live-applicable theme and shell settings were requested"
fi
if [ "${reset_layout}" = yes ]; then
  ok "The recommended Meo panel layout was requested"
fi
printf '\n'
say "  ${bold}One final step${reset}"
say "  Native KWin decoration/plugin and environment changes are discovered on the"
say "  next normal login. Log out and sign in again when convenient."
printf '\n'
say "  ${muted}Restore the previous desktop:${reset}"
say "  ${accent}./setup/reset-meo-desktop.sh${reset}"
printf '\n'
