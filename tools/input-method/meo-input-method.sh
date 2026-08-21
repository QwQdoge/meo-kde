#!/usr/bin/env bash
set -euo pipefail

# Configure only the presentation layer of an already chosen input-method
# framework.  KWin/Plasma remains responsible for launching a Wayland virtual
# keyboard, and neither this tool nor Meo's shell invents IME state.

usage() {
  cat <<'EOF'
Usage: meo-input-method [--status] [--enable {fcitx5|ibus}] [--sync] [--dry-run] [--quiet]

  --status           Show detected frameworks and Meo styling status.
  --enable fcitx5    Select the Meo MD3 capsule themes for Classic UI.
  --enable ibus      Generate and select an MD3 GTK candidate-panel theme.
  --sync             Refresh an already-selected Meo IBus theme after a color
                     scheme change; it never enables a framework.
  --dry-run          Print changes without writing configuration or reloading.
  --quiet            Suppress informational output (useful for theme hooks).

This tool does not start, stop, select, or configure input engines. On Plasma
Wayland, choose Fcitx 5 in System Settings > Keyboard > Virtual Keyboard so
KWin owns the input-method process.
EOF
}

dry_run=0
quiet=0
action=status
framework=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --status) action=status ;;
    --sync) action=sync ;;
    --enable)
      [ "$#" -ge 2 ] || { echo "--enable requires fcitx5 or ibus" >&2; exit 2; }
      action=enable
      framework="$2"
      shift
      ;;
    --dry-run) dry_run=1 ;;
    --quiet) quiet=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

case "$framework" in
  ""|fcitx5|ibus) ;;
  *) echo "Unsupported input-method framework: ${framework}" >&2; exit 2 ;;
esac

config_home="${XDG_CONFIG_HOME:-${HOME}/.config}"
data_home="${XDG_DATA_HOME:-${HOME}/.local/share}"
color_scheme_override="${MEO_INPUT_METHOD_COLOR_SCHEME:-}"
color_scheme_root_override="${MEO_INPUT_METHOD_COLOR_SCHEME_ROOT:-}"
resource_root_override="${MEO_INPUT_METHOD_RESOURCE_ROOT:-}"

info() {
  [ "$quiet" -eq 1 ] || printf '%s\n' "$*"
}

run() {
  if [ "$quiet" -eq 0 ]; then
    printf '+ '
    printf '%q ' "$@"
    printf '\n'
  fi
  if [ "$dry_run" -eq 0 ]; then
    "$@"
  fi
}

read_ini_value() {
  local file="$1" section="$2" key="$3"
  [ -f "$file" ] || return 0
  awk -v section="[$section]" -v key="$key" '
    $0 == section { in_section = 1; next }
    /^\[/ { in_section = 0 }
    in_section && index($0, key "=") == 1 {
      print substr($0, length(key) + 2)
      exit
    }
  ' "$file"
}

active_color_scheme() {
  if [ -n "$color_scheme_override" ]; then
    printf '%s\n' "$color_scheme_override"
    return
  fi

  local value="" config_dir
  value="$(read_ini_value "${config_home}/kdeglobals" General ColorScheme)"
  if [ -n "$value" ]; then
    printf '%s\n' "$value"
    return
  fi

  IFS=: read -r -a config_dirs <<< "${XDG_CONFIG_DIRS:-/etc/xdg}"
  for config_dir in "${config_dirs[@]}"; do
    value="$(read_ini_value "${config_dir}/kdeglobals" General ColorScheme)"
    if [ -n "$value" ]; then
      printf '%s\n' "$value"
      return
    fi
  done
  printf '%s\n' "MeoLight"
}

find_color_scheme() {
  local name="$1" root
  case "$name" in
    ""|*/*|*'..'*) return 1 ;;
  esac

  if [ -n "$color_scheme_root_override" ] && [ -f "${color_scheme_root_override}/${name}.colors" ]; then
    printf '%s\n' "${color_scheme_root_override}/${name}.colors"
    return
  fi
  if [ -f "${data_home}/color-schemes/${name}.colors" ]; then
    printf '%s\n' "${data_home}/color-schemes/${name}.colors"
    return
  fi
  IFS=: read -r -a data_dirs <<< "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
  for root in "${data_dirs[@]}"; do
    if [ -f "${root}/color-schemes/${name}.colors" ]; then
      printf '%s\n' "${root}/color-schemes/${name}.colors"
      return
    fi
  done
  return 1
}

rgb_to_hex() {
  local value="$1" red green blue
  case "$value" in
    \#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])
      printf '%s\n' "$value"
      return
      ;;
  esac
  IFS=, read -r red green blue <<< "$value"
  [[ "$red" =~ ^[0-9]+$ && "$green" =~ ^[0-9]+$ && "$blue" =~ ^[0-9]+$ ]] || return 1
  [ "$red" -le 255 ] && [ "$green" -le 255 ] && [ "$blue" -le 255 ] || return 1
  printf '#%02x%02x%02x\n' "$red" "$green" "$blue"
}

color_role() {
  local scheme_file="$1" group="$2" key="$3" raw
  raw="$(read_ini_value "$scheme_file" "$group" "$key")"
  [ -n "$raw" ] || { echo "Missing ${group}/${key} in ${scheme_file}" >&2; return 1; }
  rgb_to_hex "$raw"
}

find_resource() {
  local relative="$1" root
  if [ -n "$resource_root_override" ] && [ -f "${resource_root_override}/${relative}" ]; then
    printf '%s\n' "${resource_root_override}/${relative}"
    return
  fi
  for root in "${data_home}/meo-kde/input-method" "/usr/share/meo-desktop/input-method"; do
    if [ -f "${root}/${relative}" ]; then
      printf '%s\n' "${root}/${relative}"
      return
    fi
  done
  echo "Missing Meo input-method resource: ${relative}" >&2
  return 1
}

render_ibus_theme() {
  local scheme_name scheme_file template index_source target index_target temporary
  local surface surface_container on_surface primary secondary_container outline on_surface_variant

  scheme_name="$(active_color_scheme)"
  scheme_file="$(find_color_scheme "$scheme_name")" || {
    echo "Cannot find active KDE color scheme: ${scheme_name}" >&2
    return 1
  }
  template="$(find_resource "ibus/gtk.css.in")"
  index_source="$(find_resource "ibus/index.theme")"
  surface="$(color_role "$scheme_file" "Colors:Window" BackgroundNormal)"
  surface_container="$(color_role "$scheme_file" "Colors:Window" BackgroundAlternate)"
  on_surface="$(color_role "$scheme_file" "Colors:Window" ForegroundNormal)"
  primary="$(color_role "$scheme_file" "Colors:Selection" BackgroundNormal)"
  secondary_container="$(color_role "$scheme_file" "Colors:Selection" BackgroundAlternate)"
  outline="$(color_role "$scheme_file" "Colors:Window" ForegroundInactive)"
  on_surface_variant="$(color_role "$scheme_file" "Colors:Window" ForegroundInactive)"

  target="${data_home}/themes/MeoInputMethod/gtk-3.0/gtk.css"
  index_target="${data_home}/themes/MeoInputMethod/index.theme"
  if [ "$dry_run" -eq 1 ]; then
    info "Would render IBus MD3 theme from ${scheme_name}: ${target}"
    return
  fi

  mkdir -p "$(dirname "$target")"
  temporary="$(mktemp "${target}.XXXXXX")"
  sed \
    -e "s/@MEO_SURFACE@/${surface}/g" \
    -e "s/@MEO_SURFACE_CONTAINER@/${surface_container}/g" \
    -e "s/@MEO_ON_SURFACE@/${on_surface}/g" \
    -e "s/@MEO_PRIMARY@/${primary}/g" \
    -e "s/@MEO_SECONDARY_CONTAINER@/${secondary_container}/g" \
    -e "s/@MEO_ON_SECONDARY_CONTAINER@/${on_surface}/g" \
    -e "s/@MEO_OUTLINE@/${outline}/g" \
    -e "s/@MEO_ON_SURFACE_VARIANT@/${on_surface_variant}/g" \
    "$template" > "$temporary"
  mv "$temporary" "$target"
  install -Dm644 "$index_source" "$index_target"
  info "Rendered IBus MD3 candidate theme from ${scheme_name}."
}

fcitx_set() {
  local file="$1" key="$2" value="$3" directory temporary
  if [ "$dry_run" -eq 1 ]; then
    info "Would set ${file} ${key}=${value}"
    return
  fi
  directory="$(dirname "$file")"
  mkdir -p "$directory"
  temporary="$(mktemp "${directory}/.${key// /_}.XXXXXX")"
  if [ -f "$file" ]; then
    awk -v key="$key" -v value="$value" '
      BEGIN { in_root = 1 }
      /^\[/ {
        if (in_root && !wrote) { print key "=" value; wrote = 1 }
        in_root = 0
        print
        next
      }
      in_root && index($0, key "=") == 1 {
        if (!wrote) { print key "=" value; wrote = 1 }
        next
      }
      { print }
      END {
        if (!wrote) { print key "=" value }
      }
    ' "$file" > "$temporary"
  else
    printf '%s=%s\n' "$key" "$value" > "$temporary"
  fi
  mv "$temporary" "$file"
}

fcitx_is_running() {
  command -v fcitx5-remote >/dev/null 2>&1 && fcitx5-remote --check >/dev/null 2>&1
}

ibus_is_running() {
  pgrep -x ibus-daemon >/dev/null 2>&1
}

reload_fcitx5_classicui() {
  if command -v busctl >/dev/null 2>&1; then
    if run busctl --user call org.fcitx.Fcitx5 /controller \
      org.fcitx.Fcitx.Controller1 ReloadAddonConfig s classicui; then
      return
    fi
  fi
  run fcitx5-remote -r
}

enable_fcitx5() {
  local config_file="${config_home}/fcitx5/conf/classicui.conf"
  command -v fcitx5 >/dev/null 2>&1 || {
    echo "Fcitx 5 is not installed; install fcitx5 first." >&2
    return 1
  }
  if ibus_is_running; then
    info "IBus is running too; use only one input-method framework per session."
  fi
  fcitx_set "$config_file" Theme MeoInputMethod-Light
  fcitx_set "$config_file" DarkTheme MeoInputMethod-Dark
  fcitx_set "$config_file" UseDarkTheme True
  if fcitx_is_running; then
    reload_fcitx5_classicui
  fi
  info "Fcitx 5 now uses the Meo MD3 capsule presentation."
}

enable_ibus() {
  command -v gsettings >/dev/null 2>&1 || {
    echo "gsettings is required to configure the IBus panel." >&2
    return 1
  }
  if ! command -v ibus-daemon >/dev/null 2>&1; then
    echo "IBus is not installed; install ibus first." >&2
    return 1
  fi
  if fcitx_is_running; then
    info "Fcitx 5 is running too; use only one input-method framework per session."
  fi
  render_ibus_theme
  run gsettings set org.freedesktop.ibus.panel use-custom-theme true
  run gsettings set org.freedesktop.ibus.panel custom-theme MeoInputMethod
  info "IBus now uses the Meo MD3 candidate-panel theme."
}

sync_ibus_theme() {
  command -v gsettings >/dev/null 2>&1 || return 0
  local selected
  selected="$(gsettings get org.freedesktop.ibus.panel custom-theme 2>/dev/null || true)"
  [ "$selected" = "'MeoInputMethod'" ] || return 0
  render_ibus_theme
  # IBus watches this setting. Toggle it without restarting its daemon or
  # touching the selected engine so the newly rendered CSS is reloaded.
  run gsettings set org.freedesktop.ibus.panel custom-theme Adwaita
  run gsettings set org.freedesktop.ibus.panel custom-theme MeoInputMethod
  info "Refreshed the IBus MD3 theme for the active color scheme."
}

show_status() {
  local scheme selected
  scheme="$(active_color_scheme)"
  printf 'Session type: %s\n' "${XDG_SESSION_TYPE:-unknown}"
  printf 'Active KDE color scheme: %s\n' "$scheme"
  if fcitx_is_running; then
    printf 'Fcitx 5: running\n'
  elif command -v fcitx5 >/dev/null 2>&1; then
    printf 'Fcitx 5: installed, not running\n'
  else
    printf 'Fcitx 5: unavailable\n'
  fi
  if ibus_is_running; then
    printf 'IBus: running\n'
  elif command -v ibus-daemon >/dev/null 2>&1; then
    printf 'IBus: installed, not running\n'
  else
    printf 'IBus: unavailable\n'
  fi
  if command -v gsettings >/dev/null 2>&1; then
    selected="$(gsettings get org.freedesktop.ibus.panel custom-theme 2>/dev/null || true)"
    printf 'IBus candidate theme: %s\n' "${selected:-unknown}"
  fi
}

case "$action" in
  status) show_status ;;
  sync) sync_ibus_theme ;;
  enable)
    case "$framework" in
      fcitx5) enable_fcitx5 ;;
      ibus) enable_ibus ;;
    esac
    ;;
esac
