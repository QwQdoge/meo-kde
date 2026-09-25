#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
apply_script="${repo_root}/setup/apply-meo-desktop.sh"
system_apply_script="${repo_root}/setup/apply-meo-system.sh"
official_meoui_repo="https://github.com/QwQdoge/MeoUI.git"

full_mode=0
kde_only=0
auto_yes=0
dry_run=0
force_no_color=0
desktop_started=0
system_started=0

required_packages=(
  base-devel
  cmake
  extra-cmake-modules
  git
  plasma-desktop
  plasma-workspace
  plasma-nm
  plasma-pa
  powerdevil
  bluedevil
  systemsettings
  breeze
  qt6-base
  qt6-declarative
  polkit-qt6
  kwindowsystem
  kconfig
  ki18n
  kirigami
  libplasma
  networkmanager-qt
  bluez-qt
  solid
  pulseaudio-qt
)

recommended_kde_packages=(
  dolphin
  konsole
)

performance_packages=(
  zram-generator
  power-profiles-daemon
  gamemode
  system76-scheduler
)

visual_integration_packages=(
  kwin-effect-rounded-corners
)

usage() {
  cat <<'EOF'
Meo Desktop Installer

Usage:
  ./install.sh
      Interactive guided installation.

  ./install.sh --full
      Recommended complete Meo desktop plus system-wide responsiveness tuning.

  ./install.sh --full --kde-only
      Complete Meo KDE experience without system-wide tuning.

Options:
  --full       Accept the recommended complete setup.
  --kde-only   Never apply system-wide zram, scheduler, power-profile or
               GameMode configuration. Display-manager/session defaults are
               never changed by either mode.
  -y, --yes    Accept recommended answers in the guided installer.
  --dry-run    Print planned package/configuration commands without applying them.
  --no-color   Disable ANSI color.
  -h, --help   Show this help.

Environment:
  MEO_UI_ROOT  Path to a MeoUI source checkout. The installer also discovers
               ../meo-ui, ../MeoUI, and ../meoui automatically.

Safety:
  System packages are installed only after an explicit choice. On Arch, package
  installation uses one 'sudo pacman -Syu --needed ...' transaction to avoid a
  partial upgrade. System-wide tuning has its own reversible backup.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --full) full_mode=1; auto_yes=1 ;;
    --kde-only|--no-system) kde_only=1 ;;
    -y|--yes) auto_yes=1 ;;
    --dry-run) dry_run=1 ;;
    --no-color) force_no_color=1 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

for backend in "${apply_script}" "${system_apply_script}"; do
  if [ ! -x "${backend}" ]; then
    printf 'Meo installer backend is missing or not executable: %s\n' "${backend}" >&2
    exit 1
  fi
done

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

  for candidate in \
    "${repo_root}/../meo-ui" \
    "${repo_root}/../MeoUI" \
    "${repo_root}/../meoui"; do
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
  git clone --depth 1 "${official_meoui_repo}" "${target}"
  MEO_UI_ROOT="${target}"
  export MEO_UI_ROOT
}

package_installed() {
  pacman -Q "$1" >/dev/null 2>&1
}

package_available() {
  pacman -Si "$1" >/dev/null 2>&1
}

collect_missing_packages() {
  local destination_name="$1"
  shift
  local -n destination="${destination_name}"
  local package

  destination=()
  for package in "$@"; do
    if ! package_installed "${package}"; then
      destination+=("${package}")
    fi
  done
}

split_repository_packages() {
  local available_name="$1"
  local unavailable_name="$2"
  shift 2
  local -n available_ref="${available_name}"
  local -n unavailable_ref="${unavailable_name}"
  local package

  available_ref=()
  unavailable_ref=()
  for package in "$@"; do
    if package_available "${package}"; then
      available_ref+=("${package}")
    else
      unavailable_ref+=("${package}")
    fi
  done
}

print_packages() {
  local package
  for package in "$@"; do
    printf '    %s\n' "${package}"
  done
}

append_unique_packages() {
  local destination_name="$1"
  shift
  local -n destination="${destination_name}"
  local package existing found

  for package in "$@"; do
    found=0
    for existing in "${destination[@]}"; do
      if [ "${existing}" = "${package}" ]; then
        found=1
        break
      fi
    done
    if [ "${found}" -eq 0 ]; then
      destination+=("${package}")
    fi
  done
}

run_pacman_transaction() {
  local -a packages=("$@")
  [ "${#packages[@]}" -gt 0 ] || return 0

  section "Package transaction"
  note "Arch package installation performs a full sync/upgrade to avoid partial upgrades."
  print_packages "${packages[@]}"

  if [ "${dry_run}" -eq 1 ]; then
    printf '  %s$%s sudo pacman -Syu --needed' "${muted}" "${reset}"
    printf ' %q' "${packages[@]}"
    printf '\n'
    return 0
  fi

  command -v sudo >/dev/null 2>&1 || die "sudo is required to install missing system packages."
  sudo -v
  sudo pacman -Syu --needed "${packages[@]}"
}

on_error() {
  local exit_code=$?
  printf '\n%sInstallation stopped%s (exit %d).\n' "${bad}${bold}" "${reset}" "${exit_code}" >&2
  if [ "${system_started}" -eq 1 ]; then
    printf 'System-wide changes can be restored with:\n  %s./setup/reset-meo-system.sh%s\n' "${accent}" "${reset}" >&2
  fi
  if [ "${desktop_started}" -eq 1 ]; then
    printf 'Desktop changes can be restored with:\n  %s./setup/reset-meo-desktop.sh%s\n' "${accent}" "${reset}" >&2
  fi
  printf '%sPackages installed by pacman are intentionally not auto-removed.%s\n' "${muted}" "${reset}" >&2
  exit "${exit_code}"
}
trap on_error ERR

header

section "Platform"
if [ "$(uname -s)" != Linux ]; then
  die "Meo Desktop installation requires Linux."
fi
ok "Linux host detected"

arch_host=0
if command -v pacman >/dev/null 2>&1 && [ -e /etc/arch-release ]; then
  arch_host=1
  ok "Arch-compatible pacman host detected"
else
  warning "pacman/Arch was not detected. Package installation will be skipped."
  warning "The source backend can continue only if all required KDE/Qt build dependencies already exist."
fi

apply_system_tuning=no
selected_packages=()

if [ "${arch_host}" -eq 1 ]; then
  collect_missing_packages missing_required "${required_packages[@]}"
  collect_missing_packages missing_recommended "${recommended_kde_packages[@]}"
  collect_missing_packages missing_performance "${performance_packages[@]}"
  collect_missing_packages missing_visual "${visual_integration_packages[@]}"

  split_repository_packages available_required unavailable_required "${missing_required[@]}"
  split_repository_packages available_recommended unavailable_recommended "${missing_recommended[@]}"
  split_repository_packages available_performance unavailable_performance "${missing_performance[@]}"
  split_repository_packages available_visual unavailable_visual "${missing_visual[@]}"

  section "System dependencies"

  if [ "${#missing_required[@]}" -eq 0 ]; then
    ok "Required Plasma/Qt/build dependencies are installed"
  else
    warning "Missing required dependencies:"
    print_packages "${missing_required[@]}"
    if [ "${#unavailable_required[@]}" -gt 0 ]; then
      warning "Not found in your configured pacman repositories:"
      print_packages "${unavailable_required[@]}"
    fi
    if [ "${#available_required[@]}" -gt 0 ] && prompt_yes_no "Install available required dependencies with pacman?" yes; then
      append_unique_packages selected_packages "${available_required[@]}"
    fi
  fi

  if [ "${#missing_recommended[@]}" -gt 0 ]; then
    note "Recommended KDE applications:"
    print_packages "${missing_recommended[@]}"
    if [ "${#unavailable_recommended[@]}" -gt 0 ]; then
      warning "Not available from your configured repositories:"
      print_packages "${unavailable_recommended[@]}"
    fi
    if [ "${#available_recommended[@]}" -gt 0 ] && prompt_yes_no "Install recommended KDE applications?" yes; then
      append_unique_packages selected_packages "${available_recommended[@]}"
    fi
  else
    ok "Recommended KDE applications are installed"
  fi

  if [ "${#missing_visual[@]}" -gt 0 ]; then
    if [ "${#available_visual[@]}" -gt 0 ]; then
      note "Optional KWin visual integration:"
      print_packages "${available_visual[@]}"
      if prompt_yes_no "Install rounded-corner KWin integration?" yes; then
        append_unique_packages selected_packages "${available_visual[@]}"
      fi
    else
      warning "Rounded-corner integration is not available from your configured pacman repositories."
      note "Meo will continue without blocking installation."
    fi
  else
    ok "Rounded-corner KWin integration is installed"
  fi

  if [ "${kde_only}" -eq 0 ]; then
    section "System-wide responsiveness"
    note "These packages and services affect the whole machine, not only Plasma."
    if [ "${#missing_performance[@]}" -gt 0 ]; then
      print_packages "${missing_performance[@]}"
      if [ "${#unavailable_performance[@]}" -gt 0 ]; then
        warning "Unavailable from configured repositories:"
        print_packages "${unavailable_performance[@]}"
      fi
      if [ "${#available_performance[@]}" -gt 0 ] && prompt_yes_no "Install recommended responsiveness packages?" yes; then
        append_unique_packages selected_packages "${available_performance[@]}"
      fi
    else
      ok "Recommended responsiveness packages are installed"
    fi

    if prompt_yes_no "Apply Meo zram/GameMode/scheduler policy and enable supported system services?" yes; then
      apply_system_tuning=yes
    fi
  else
    section "System-wide responsiveness"
    note "--kde-only selected: system-wide performance services and policies remain untouched."
  fi

  if [ "${#selected_packages[@]}" -gt 0 ]; then
    run_pacman_transaction "${selected_packages[@]}"
  else
    note "No pacman transaction is needed."
  fi
fi

if ! command -v git >/dev/null 2>&1; then
  die "git is required. Install it before continuing."
fi

section "Desktop preflight"
if command -v plasmashell >/dev/null 2>&1; then
  plasma_version="$(plasmashell --version 2>/dev/null | awk '{print $2}' || true)"
  ok "Plasma ${plasma_version:-detected}"
else
  die "Plasma is unavailable after dependency setup."
fi

meoui_root=""
if meoui_root="$(discover_meoui)"; then
  MEO_UI_ROOT="${meoui_root}"
  export MEO_UI_ROOT
  ok "MeoUI source: ${MEO_UI_ROOT}"
else
  warning "No MeoUI source checkout was found."
  if [ "${dry_run}" -eq 1 ]; then
    die "--dry-run cannot build a missing MeoUI checkout. Clone MeoUI first or set MEO_UI_ROOT."
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
  section "Choose your Meo experience"
  if prompt_yes_no "Apply Meo theme, components, dynamic colors and native KDE integration now?" yes; then
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
  note "Preserve the current Plasma panel layout"
fi
if [ "${update_meoui}" = yes ]; then
  ok "Fast-forward MeoUI main before build"
else
  note "Build the current MeoUI checkout exactly as it is"
fi
if [ "${apply_system_tuning}" = yes ]; then
  warning "Apply system-wide responsiveness configuration"
else
  note "Leave system-wide responsiveness configuration untouched"
fi
note "Display manager and default login session are never changed."
note "A timestamped desktop backup is created before Meo replaces user configuration."
if [ "${apply_system_tuning}" = yes ]; then
  note "System-wide configuration gets a separate root-owned rollback backup."
fi
if [ "${dry_run}" -eq 1 ]; then
  warning "Preview mode: no filesystem, package or service changes will be made."
fi

if [ "${full_mode}" -eq 0 ] && [ "${auto_yes}" -eq 0 ]; then
  printf '\n'
  if ! prompt_yes_no "Start with this plan?" yes; then
    say ""
    note "Cancelled. No Meo desktop configuration was started."
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

section "Installing Meo Desktop"
note "MeoUI and native MeoKDE components are built before user configuration is changed."
printf '\n'
desktop_started=1
MEO_UI_ROOT="${MEO_UI_ROOT}" "${apply_script}" "${args[@]}"

if [ "${apply_system_tuning}" = yes ]; then
  section "Applying system responsiveness"
  system_args=()
  if [ "${dry_run}" -eq 1 ]; then
    system_args+=(--dry-run)
  fi
  system_started=1
  "${system_apply_script}" "${system_args[@]}"
fi

trap - ERR
printf '\n'
section "Finished"
ok "Meo Desktop installation completed"
if [ "${apply_now}" = yes ]; then
  ok "Meo theme and shell integration were requested"
fi
if [ "${reset_layout}" = yes ]; then
  ok "Recommended Meo panel layout was requested"
fi
if [ "${apply_system_tuning}" = yes ]; then
  ok "Selected system-wide responsiveness integration was requested"
fi
printf '\n'
say "  ${bold}One final step${reset}"
say "  Native KWin decoration/plugin and environment changes are discovered on the"
say "  next normal Plasma login. The installer never forces a logout or reboot."
printf '\n'
say "  ${muted}Restore desktop configuration:${reset}"
say "  ${accent}./setup/reset-meo-desktop.sh${reset}"
if [ "${apply_system_tuning}" = yes ]; then
  say "  ${muted}Restore system-wide responsiveness configuration:${reset}"
  say "  ${accent}./setup/reset-meo-system.sh${reset}"
fi
printf '\n'
