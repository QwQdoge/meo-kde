#!/usr/bin/env bash
set -Eeuo pipefail

state_root="/var/lib/meo-desktop"
marker="${state_root}/last-backup"
dry_run=0

usage() {
  echo "Usage: setup/reset-meo-system.sh [--dry-run]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

if [ "${EUID}" -eq 0 ]; then
  root_cmd=()
elif command -v sudo >/dev/null 2>&1; then
  root_cmd=(sudo)
else
  echo "sudo is required to restore system-wide Meo integration." >&2
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

root_cat() {
  "${root_cmd[@]}" cat "$1"
}

if ! "${root_cmd[@]}" test -s "${marker}"; then
  echo "No Meo system backup marker exists; nothing to restore." >&2
  exit 1
fi

backup_root="$(root_cat "${marker}")"
case "${backup_root}" in
  "${state_root}"/backups/*) ;;
  *) echo "Refusing unsafe backup path: ${backup_root}" >&2; exit 1 ;;
esac

if ! "${root_cmd[@]}" test -d "${backup_root}"; then
  echo "Meo system backup no longer exists: ${backup_root}" >&2
  exit 1
fi

targets=(
  "/etc/systemd/zram-generator.conf.d/50-meo-desktop.conf"
  "/etc/gamemode.ini"
  "/etc/system76-scheduler/process-scheduler/meo-cachyos.kdl"
)

for target in "${targets[@]}"; do
  mirror="${backup_root}/rootfs${target}"
  absent="${backup_root}/absent${target}"
  if "${root_cmd[@]}" test -e "${mirror}" || "${root_cmd[@]}" test -L "${mirror}"; then
    run_root mkdir -p "$(dirname "${target}")"
    run_root cp -a "${mirror}" "${target}"
  elif "${root_cmd[@]}" test -e "${absent}"; then
    run_root rm -f "${target}"
  fi
done

restore_service() {
  local unit="$1"
  local safe_name="${unit//\//_}"
  local enabled_file="${backup_root}/services/${safe_name}.enabled"
  local active_file="${backup_root}/services/${safe_name}.active"
  local enabled="" active=""

  if "${root_cmd[@]}" test -f "${enabled_file}"; then
    enabled="$(root_cat "${enabled_file}")"
  fi
  if "${root_cmd[@]}" test -f "${active_file}"; then
    active="$(root_cat "${active_file}")"
  fi

  if ! systemctl cat "${unit}" >/dev/null 2>&1; then
    return
  fi

  case "${enabled}" in
    enabled|enabled-runtime|linked|linked-runtime)
      run_root systemctl enable "${unit}"
      ;;
    disabled|masked|indirect|static|generated|transient|unknown|"")
      if [ "${enabled}" = masked ]; then
        run_root systemctl mask "${unit}"
      else
        run_root systemctl disable "${unit}" || true
      fi
      ;;
  esac

  if [ "${active}" = active ]; then
    run_root systemctl start "${unit}"
  else
    run_root systemctl stop "${unit}" || true
  fi
}

run_root systemctl daemon-reload
restore_service power-profiles-daemon.service
restore_service com.system76.Scheduler.service

echo
echo "Previous system-wide configuration restored."
