#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
meoui_root="${MEO_UI_ROOT:?Set MEO_UI_ROOT to the MeoUI checkout}"
output_root="${MEO_OUTPUT_ROOT:-${HOME}/Projects/outputs}"
meoui_build="${MEOUI_BUILD_ROOT:-${output_root}/meo-ui/build/desktop-session}"
native_build="${MEO_KDE_NATIVE_BUILD_ROOT:-${output_root}/meo-kde/build/desktop-session}"
runtime="${MEO_SESSION_RUNTIME:-${XDG_DATA_HOME:-${HOME}/.local/share}/meo-desktop/runtime}"
native_cxx="${MEO_KDE_CXX:-}"
if [ -z "$native_cxx" ] && command -v clang++ >/dev/null 2>&1 && c++ --version 2>/dev/null | head -n 1 | grep -q ' 16\.'; then
  native_cxx=clang++
fi
native_options=()
if [ -n "$native_cxx" ]; then native_options+=("-DCMAKE_CXX_COMPILER=$native_cxx"); fi
dry_run=0
update_meoui=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    --update-meoui) update_meoui=1 ;;
    --no-update-meoui) ;;
    *) echo "Unsupported session install option: $arg" >&2; exit 2 ;;
  esac
done
run() {
  printf '+ '; printf '%q ' "$@"; printf '\n'
  if [ "$dry_run" -eq 0 ]; then "$@"; fi
}
if [ "$update_meoui" -eq 1 ]; then
  [ -z "$(git -C "$meoui_root" status --porcelain)" ] || { echo 'MeoUI has local changes.' >&2; exit 1; }
  run git -C "$meoui_root" fetch origin
  run git -C "$meoui_root" merge --ff-only origin/main
fi
run cmake -S "$meoui_root" -B "$meoui_build" -DCMAKE_BUILD_TYPE=Release -DMEOUI_BUILD_SHOWCASE=OFF
run cmake --build "$meoui_build" --target meoui_moduleplugin --parallel "${MEO_BUILD_JOBS:-4}"
run cmake -S "${repo_root}/native" -B "$native_build" -DCMAKE_BUILD_TYPE=Release -DMEOUI_SOURCE_DIR="$meoui_root" -DMEO_BUILD_STANDALONE_DOCK=OFF "${native_options[@]}"
run cmake --build "$native_build" --parallel "${MEO_BUILD_JOBS:-4}"
run "${repo_root}/tools/session/deploy-meo-runtime" "$repo_root" "$native_build" "$runtime" "$meoui_build"
printf 'Meo Desktop runtime installed at %s. Current KDE configuration was not modified.\n' "$runtime"
