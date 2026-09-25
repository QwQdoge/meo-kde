#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
state_root="/var/lib/meo-desktop"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_root="${state_root}/backups/${timestamp}"
dry_run=0

usage() {
  cat <<'EOF'
Usage: setup/apply-meo-system.sh [--dry-run]

Installs Meo's optional system-wide responsiveness configuration:
  - zram-generator policy
  - GameMode policy
  - System76 Scheduler process classifications
  - power-profiles-daemon and System76 Scheduler service enablement

This script never installs packages. The root installer handles packages first.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

if [ "$(uname -s)" != Linux ]; then
  echo "Meo system integration requires Linux." >&2
  exit 1
fi

if [ "${EUID}" -eq 0 ]; then
  root_cmd=()
elif command -v sudo >/dev/null 2>&1; then
  root_cmd=(sudo)
else
  echo "sudo is required for system-wide Meo integration." >&2
  exit 1
fi

run_root() {
  printf '+'
  printf ' %q' "${root_cmd[@]}" "$@"
  printf '\n'
  if [ "${dry_run}" -eq 0 ]; then
    "${root_cmd[@]}" "$@"
  fi
}

write_root_text() {
  local target="$1"
  local value="$2"
  if [ "${dry_run}" -eq 1 ]; then
    printf '+ write %q\n' "${target}"
    return
  fi
  printf '%s\n' "${value}" | "${root_cmd[@]}" tee "${target}" >/dev/null
}

backup_target() {
  local target="$1"
  local mirror="${backup_root}/rootfs${target}"
  local absent="${backup_root}/absent${target}"

  if [ -e "${target}" ] || [ -L "${target}" ]; then
    run_root mkdir -p "$(dirname "${mirror}")"
    run_root cp -a "${target}" "${mirror}"
  else
    run_root mkdir -p "$(dirname "${absent}")"
    run_root touch "${absent}"
  fi
}

record_service_state() {
  local unit="$1"
  local safe_name="${unit//\//_}"
  local enabled active

  enabled="$(systemctl is-enabled "${unit}" 2>/dev/null || true)"
  active="$(systemctl is-active "${unit}" 2>/dev/null || true)"
  write_root_text "${backup_root}/services/${safe_name}.enabled" "${enabled:-unknown}"
  write_root_text "${backup_root}/services/${safe_name}.active" "${active:-unknown}"
}

unit_exists() {
  systemctl cat "$1" >/dev/null 2>&1
}

targets=(
  "/etc/systemd/zram-generator.conf.d/50-meo-desktop.conf"
  "/etc/gamemode.ini"
  "/etc/system76-scheduler/process-scheduler/meo-cachyos.kdl"
)

run_root mkdir -p "${backup_root}/services"
for target in "${targets[@]}"; do
  backup_target "${target}"
done

for unit in power-profiles-daemon.service com.system76.Scheduler.service; do
  record_service_state "${unit}"
done

run_root install -Dm644   "${repo_root}/defaults/responsiveness/zram-generator.conf"   "/etc/systemd/zram-generator.conf.d/50-meo-desktop.conf"

run_root install -Dm644   "${repo_root}/defaults/responsiveness/gamemode.ini"   "/etc/gamemode.ini"

run_root install -Dm644   "${repo_root}/defaults/responsiveness/cachyos-ananicy.kdl"   "/etc/system76-scheduler/process-scheduler/meo-cachyos.kdl"

run_root systemctl daemon-reload

for unit in power-profiles-daemon.service com.system76.Scheduler.service; do
  if unit_exists "${unit}"; then
    run_root systemctl enable --now "${unit}"
  else
    echo "Warning: ${unit} is unavailable; leaving it disabled." >&2
  fi
done

if [ "${dry_run}" -eq 0 ]; then
  write_root_text "${state_root}/last-backup" "${backup_root}"
fi

echo
echo "Meo system responsiveness configuration applied."
echo "zram-generator uses the new policy on the next boot (no forced reboot is performed)."
echo "Restore with: ./setup/reset-meo-system.sh"
