#!/usr/bin/env bash
set -euo pipefail

# Configure only the presentation layer of an already chosen input-method
# framework.  KWin/Plasma remains responsible for launching a Wayland virtual
# keyboard, and neither this tool nor Meo's shell invents IME state.

usage() {
  cat <<'EOF'
Usage: meo-input-method [--status] [--enable {fcitx5|ibus}] [--sync] [--dry-run] [--quiet]

  --status           Show detected frameworks and Meo styling status.
  --enable fcitx5    Generate and select the dynamic Meo MD3 Classic UI theme.
  --enable ibus      Generate and select an MD3 GTK candidate-panel theme.
  --sync             Refresh already-selected Meo Fcitx 5 and IBus themes after
                     a color-scheme change; it never enables another theme.
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

warn() {
  printf '%s\n' "$*" >&2
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

read_fcitx_root_value() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 0
  awk -v key="$key" '
    BEGIN { in_root = 1 }
    /^\[/ { in_root = 0 }
    in_root && index($0, key "=") == 1 {
      print substr($0, length(key) + 2)
      exit
    }
  ' "$file"
}

find_fcitx_config() {
  local user_file="${config_home}/fcitx5/conf/classicui.conf" config_dir
  if [ -f "$user_file" ]; then
    printf '%s\n' "$user_file"
    return
  fi
  IFS=: read -r -a config_dirs <<< "${XDG_CONFIG_DIRS:-/etc/xdg}"
  for config_dir in "${config_dirs[@]}"; do
    if [ -f "${config_dir}/fcitx5/conf/classicui.conf" ]; then
      printf '%s\n' "${config_dir}/fcitx5/conf/classicui.conf"
      return
    fi
  done
  return 1
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

load_material_roles() {
  local scheme_file="$1"
  meo_surface_container="$(color_role "$scheme_file" MeoMaterial surfaceContainer)" || return 1
  meo_on_surface="$(color_role "$scheme_file" MeoMaterial onSurface)" || return 1
  meo_primary="$(color_role "$scheme_file" MeoMaterial primary)" || return 1
  meo_on_primary="$(color_role "$scheme_file" MeoMaterial onPrimary)" || return 1
  meo_primary_container="$(color_role "$scheme_file" MeoMaterial primaryContainer)" || return 1
  meo_on_primary_container="$(color_role "$scheme_file" MeoMaterial onPrimaryContainer)" || return 1
  meo_secondary_container="$(color_role "$scheme_file" MeoMaterial secondaryContainer)" || return 1
  meo_on_secondary_container="$(color_role "$scheme_file" MeoMaterial onSecondaryContainer)" || return 1
  meo_on_surface_variant="$(color_role "$scheme_file" MeoMaterial onSurfaceVariant)" || return 1
  meo_outline="$(color_role "$scheme_file" MeoMaterial outline)" || return 1
}

atomic_write() {
  local target="$1" directory temporary
  directory="$(dirname "$target")"
  mkdir -p "$directory" || return 1
  temporary="$(mktemp "${directory}/.$(basename "$target").XXXXXX")" || return 1
  cat > "$temporary" || return 1
  chmod 0644 "$temporary" || return 1
  if [ -f "$target" ] && cmp -s "$temporary" "$target"; then
    rm -f -- "$temporary"
    return 0
  fi
  mv "$temporary" "$target" || return 1
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

render_fcitx_theme() {
  local scheme_name scheme_file target

  scheme_name="$(active_color_scheme)"
  scheme_file="$(find_color_scheme "$scheme_name")" || {
    echo "Cannot find active KDE color scheme: ${scheme_name}" >&2
    return 1
  }
  load_material_roles "$scheme_file" || return 1
  target="${data_home}/fcitx5/themes/MeoInputMethod-Dynamic"
  if [ "$dry_run" -eq 1 ]; then
    info "Would render Fcitx 5 dynamic theme from ${scheme_name}: ${target}"
    return
  fi

  mkdir -p "$target" || return 1
  atomic_write "${target}/panel.svg" <<EOF || return 1
<svg xmlns="http://www.w3.org/2000/svg" width="50" height="50" viewBox="0 0 50 50">
  <rect x="1" y="1" width="48" height="48" rx="24" fill="${meo_surface_container}" stroke="${meo_outline}" stroke-width="2"/>
</svg>
EOF
  atomic_write "${target}/highlight.svg" <<EOF || return 1
<svg xmlns="http://www.w3.org/2000/svg" width="36" height="36" viewBox="0 0 36 36">
  <rect width="36" height="36" rx="17" fill="${meo_secondary_container}"/>
</svg>
EOF
  atomic_write "${target}/menu-highlight.svg" <<EOF || return 1
<svg xmlns="http://www.w3.org/2000/svg" width="36" height="36" viewBox="0 0 36 36">
  <rect width="36" height="36" rx="17" fill="${meo_primary_container}"/>
</svg>
EOF
  atomic_write "${target}/prev.svg" <<EOF || return 1
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="24" viewBox="0 0 16 24">
  <path d="M10.5 5.5 4 12l6.5 6.5" fill="none" stroke="${meo_on_surface_variant}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
EOF
  atomic_write "${target}/next.svg" <<EOF || return 1
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="24" viewBox="0 0 16 24">
  <path d="M5.5 5.5 12 12l-6.5 6.5" fill="none" stroke="${meo_on_surface_variant}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
EOF
  atomic_write "${target}/check.svg" <<EOF || return 1
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
  <path d="m5 12.5 4 4 10-10" fill="none" stroke="${meo_on_surface_variant}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
EOF
  atomic_write "${target}/submenu.svg" <<EOF || return 1
<svg xmlns="http://www.w3.org/2000/svg" width="10" height="16" viewBox="0 0 10 16">
  <path d="m3 2.5 5 5.5-5 5.5" fill="none" stroke="${meo_on_surface_variant}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
EOF
  # Write the manifest last so Fcitx never observes a new configuration before
  # all referenced SVG assets have been atomically installed.
  atomic_write "${target}/theme.conf" <<EOF || return 1
[Metadata]
Name=Meo Input Method Dynamic
Version=1
Author=Meo
Description=Material 3 dynamic tonal candidate panel
ScaleWithDPI=True

[InputPanel]
NormalColor=${meo_on_surface}
HighlightColor=${meo_on_primary}
HighlightBackgroundColor=${meo_primary}
HighlightCandidateColor=${meo_on_secondary_container}
CandidateLabelColor=${meo_on_surface_variant}
HighlightCandidateLabelColor=${meo_on_secondary_container}
CandidateCommentColor=${meo_on_surface_variant}
HighlightCandidateCommentColor=${meo_on_secondary_container}
PageButtonAlignment=Last Candidate

[InputPanel/TextMargin]
Left=8
Right=8
Top=8
Bottom=8

[InputPanel/ContentMargin]
Left=7
Right=7
Top=7
Bottom=7

[InputPanel/Background]
Image=panel.svg

[InputPanel/Background/Margin]
Left=24
Right=24
Top=24
Bottom=24

[InputPanel/Highlight]
Image=highlight.svg

[InputPanel/Highlight/Margin]
Left=8
Right=8
Top=8
Bottom=8

[InputPanel/PrevPage]
Image=prev.svg

[InputPanel/PrevPage/ClickMargin]
Left=5
Right=5
Top=4
Bottom=4

[InputPanel/NextPage]
Image=next.svg

[InputPanel/NextPage/ClickMargin]
Left=5
Right=5
Top=4
Bottom=4

[Menu]
NormalColor=${meo_on_surface}
HighlightCandidateColor=${meo_on_primary_container}

[Menu/Background]
Image=panel.svg

[Menu/Background/Margin]
Left=24
Right=24
Top=24
Bottom=24

[Menu/ContentMargin]
Left=7
Right=7
Top=7
Bottom=7

[Menu/Highlight]
Image=menu-highlight.svg

[Menu/Highlight/Margin]
Left=8
Right=8
Top=8
Bottom=8

[Menu/Separator]
Color=${meo_outline}

[Menu/CheckBox]
Image=check.svg

[Menu/SubMenu]
Image=submenu.svg

[Menu/TextMargin]
Left=8
Right=8
Top=8
Bottom=8
EOF
  info "Rendered Fcitx 5 dynamic theme from ${scheme_name}."
}

render_ibus_theme() {
  local scheme_name scheme_file template index_source target index_target temporary

  scheme_name="$(active_color_scheme)"
  scheme_file="$(find_color_scheme "$scheme_name")" || {
    echo "Cannot find active KDE color scheme: ${scheme_name}" >&2
    return 1
  }
  template="$(find_resource "ibus/gtk.css.in")" || return 1
  index_source="$(find_resource "ibus/index.theme")" || return 1
  load_material_roles "$scheme_file" || return 1

  target="${data_home}/themes/MeoInputMethod/gtk-3.0/gtk.css"
  index_target="${data_home}/themes/MeoInputMethod/index.theme"
  if [ "$dry_run" -eq 1 ]; then
    info "Would render IBus MD3 theme from ${scheme_name}: ${target}"
    return
  fi

  mkdir -p "$(dirname "$target")" || return 1
  temporary="$(mktemp "${target}.XXXXXX")" || return 1
  sed \
    -e "s/@MEO_SURFACE_CONTAINER@/${meo_surface_container}/g" \
    -e "s/@MEO_ON_SURFACE@/${meo_on_surface}/g" \
    -e "s/@MEO_PRIMARY@/${meo_primary}/g" \
    -e "s/@MEO_ON_PRIMARY@/${meo_on_primary}/g" \
    -e "s/@MEO_PRIMARY_CONTAINER@/${meo_primary_container}/g" \
    -e "s/@MEO_ON_PRIMARY_CONTAINER@/${meo_on_primary_container}/g" \
    -e "s/@MEO_SECONDARY_CONTAINER@/${meo_secondary_container}/g" \
    -e "s/@MEO_ON_SECONDARY_CONTAINER@/${meo_on_secondary_container}/g" \
    -e "s/@MEO_OUTLINE@/${meo_outline}/g" \
    -e "s/@MEO_ON_SURFACE_VARIANT@/${meo_on_surface_variant}/g" \
    "$template" > "$temporary" || return 1
  chmod 0644 "$temporary" || return 1
  mv "$temporary" "$target" || return 1
  install -Dm644 "$index_source" "$index_target" || return 1
  info "Rendered IBus MD3 candidate theme from ${scheme_name}."
}

fcitx_set() {
  local file="$1" key="$2" value="$3" directory temporary
  if [ "$dry_run" -eq 1 ]; then
    info "Would set ${file} ${key}=${value}"
    return
  fi
  directory="$(dirname "$file")"
  mkdir -p "$directory" || return 1
  temporary="$(mktemp "${directory}/.${key// /_}.XXXXXX")" || return 1
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
    ' "$file" > "$temporary" || return 1
  else
    printf '%s=%s\n' "$key" "$value" > "$temporary" || return 1
  fi
  mv "$temporary" "$file" || return 1
}

fcitx_is_running() {
  command -v fcitx5-remote >/dev/null 2>&1 && fcitx5-remote --check >/dev/null 2>&1
}

ibus_is_running() {
  pgrep -x ibus-daemon >/dev/null 2>&1
}

is_meo_fcitx_theme() {
  case "$1" in
    MeoInputMethod-Light|MeoInputMethod-Dark|MeoInputMethod-Dynamic) return 0 ;;
    *) return 1 ;;
  esac
}

fcitx_runtime_string_matches() {
  local output="$1" key="$2" value="$3" pattern
  pattern="\"${key}\"[[:space:]]+(v[[:space:]]+)?s[[:space:]]+\"${value}\""
  [[ $output =~ $pattern ]]
}

fcitx_runtime_bool_matches() {
  local output="$1" key="$2" value="$3" bool_pattern string_pattern string_value
  case "$value" in
    true) string_value=True ;;
    false) string_value=False ;;
    *) return 1 ;;
  esac
  bool_pattern="\"${key}\"[[:space:]]+(v[[:space:]]+)?b[[:space:]]+${value}"
  string_pattern="\"${key}\"[[:space:]]+(v[[:space:]]+)?s[[:space:]]+\"${string_value}\""
  [[ $output =~ $bool_pattern ]] || [[ $output =~ $string_pattern ]]
}

reload_fcitx5_classicui() {
  local expected_theme="$1" expected_dark_theme="$2" expected_use_dark_theme="$3"
  local runtime mismatch=0

  if [ "$dry_run" -eq 1 ]; then
    info "Would reload Fcitx 5 Classic UI through D-Bus and verify GetConfig."
    return
  fi
  if ! command -v busctl >/dev/null 2>&1; then
    warn "Fcitx configuration files were updated, but busctl is unavailable; runtime was not reloaded or verified."
    return
  fi
  if ! busctl --user call org.fcitx.Fcitx5 /controller \
      org.fcitx.Fcitx.Controller1 ReloadAddonConfig s classicui >/dev/null 2>&1; then
    warn "Fcitx configuration files were updated, but Classic UI D-Bus reload failed; runtime was not verified."
    return
  fi
  if ! runtime="$(busctl --user call org.fcitx.Fcitx5 /controller \
      org.fcitx.Fcitx.Controller1 GetConfig s fcitx://config/addon/classicui 2>/dev/null)"; then
    warn "Fcitx Classic UI reloaded, but GetConfig failed; runtime selection was not verified."
    return
  fi

  if [ -n "$expected_theme" ] \
      && ! fcitx_runtime_string_matches "$runtime" Theme "$expected_theme"; then
    warn "Fcitx runtime verification failed: Theme is not ${expected_theme}."
    mismatch=1
  fi
  if [ -n "$expected_dark_theme" ] \
      && ! fcitx_runtime_string_matches "$runtime" DarkTheme "$expected_dark_theme"; then
    warn "Fcitx runtime verification failed: DarkTheme is not ${expected_dark_theme}."
    mismatch=1
  fi
  if [ -n "$expected_use_dark_theme" ] \
      && ! fcitx_runtime_bool_matches "$runtime" UseDarkTheme "$expected_use_dark_theme"; then
    warn "Fcitx runtime verification failed: UseDarkTheme is not ${expected_use_dark_theme}."
    mismatch=1
  fi
  [ "$mismatch" -eq 0 ] || return 1
  info "Fcitx 5 Classic UI reload and runtime theme selection verified through D-Bus."
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
  render_fcitx_theme || return 1
  fcitx_set "$config_file" Theme MeoInputMethod-Dynamic || return 1
  fcitx_set "$config_file" DarkTheme MeoInputMethod-Dynamic || return 1
  fcitx_set "$config_file" UseDarkTheme True || return 1
  if fcitx_is_running; then
    reload_fcitx5_classicui MeoInputMethod-Dynamic MeoInputMethod-Dynamic true
  elif [ "$dry_run" -eq 0 ]; then
    info "Configured the Fcitx 5 dynamic Meo theme; Fcitx is not running, so runtime activation remains pending."
    return
  fi
  info "Configured the Fcitx 5 dynamic Meo capsule presentation."
}

sync_fcitx_theme() {
  local source_file config_file theme dark_theme expected_theme="" expected_dark_theme=""
  source_file="$(find_fcitx_config 2>/dev/null || true)"
  [ -n "$source_file" ] || return 0
  theme="$(read_fcitx_root_value "$source_file" Theme)"
  dark_theme="$(read_fcitx_root_value "$source_file" DarkTheme)"
  if ! is_meo_fcitx_theme "$theme" && ! is_meo_fcitx_theme "$dark_theme"; then
    return 0
  fi

  render_fcitx_theme || return 1
  config_file="${config_home}/fcitx5/conf/classicui.conf"
  if is_meo_fcitx_theme "$theme"; then
    expected_theme=MeoInputMethod-Dynamic
    if [ "$theme" != "$expected_theme" ] || [ "$source_file" != "$config_file" ]; then
      fcitx_set "$config_file" Theme "$expected_theme" || return 1
    fi
  fi
  if is_meo_fcitx_theme "$dark_theme"; then
    expected_dark_theme=MeoInputMethod-Dynamic
    if [ "$dark_theme" != "$expected_dark_theme" ] || [ "$source_file" != "$config_file" ]; then
      fcitx_set "$config_file" DarkTheme "$expected_dark_theme" || return 1
    fi
  fi

  if fcitx_is_running; then
    reload_fcitx5_classicui "$expected_theme" "$expected_dark_theme" "" || return 1
  elif [ "$dry_run" -eq 0 ]; then
    info "Refreshed the selected Fcitx 5 Meo theme files; Fcitx is not running, so runtime activation remains pending."
    return
  fi
  info "Refreshed the selected Fcitx 5 Meo theme for the active color scheme."
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
  render_ibus_theme || return 1
  run gsettings set org.freedesktop.ibus.panel use-custom-theme true
  run gsettings set org.freedesktop.ibus.panel custom-theme MeoInputMethod
  if [ "$dry_run" -eq 1 ]; then
    info "Would configure the IBus Meo MD3 candidate-panel theme."
  else
    info "Configured the IBus Meo MD3 candidate-panel theme."
  fi
}

sync_ibus_theme() {
  command -v gsettings >/dev/null 2>&1 || return 0
  local selected
  selected="$(gsettings get org.freedesktop.ibus.panel custom-theme 2>/dev/null || true)"
  [ "$selected" = "'MeoInputMethod'" ] || return 0
  render_ibus_theme || return 1
  if ibus_is_running; then
    # IBus watches this setting. Toggle only an already-selected Meo theme,
    # without changing use-custom-theme or touching the selected engine.
    if ! run gsettings set org.freedesktop.ibus.panel custom-theme Adwaita; then
      warn "Rendered the IBus Meo theme, but the live panel reload could not begin."
      return 1
    fi
    if ! run gsettings set org.freedesktop.ibus.panel custom-theme MeoInputMethod; then
      warn "Rendered the IBus Meo theme, but restoring its live selection failed."
      return 1
    fi
    info "Refreshed the selected IBus Meo theme and requested a live panel reload."
  else
    info "Refreshed the selected IBus Meo theme files; IBus is not running, so runtime activation remains pending."
  fi
}

sync_selected_themes() {
  local result=0
  sync_fcitx_theme || result=1
  sync_ibus_theme || result=1
  return "$result"
}

show_status() {
  local scheme selected use_custom source_file theme dark_theme use_dark_theme
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
  source_file="$(find_fcitx_config 2>/dev/null || true)"
  if [ -n "$source_file" ]; then
    theme="$(read_fcitx_root_value "$source_file" Theme)"
    dark_theme="$(read_fcitx_root_value "$source_file" DarkTheme)"
    use_dark_theme="$(read_fcitx_root_value "$source_file" UseDarkTheme)"
    printf 'Fcitx config source: %s\n' "$source_file"
    printf 'Fcitx Theme (file): %s\n' "${theme:-unset}"
    printf 'Fcitx DarkTheme (file): %s\n' "${dark_theme:-unset}"
    printf 'Fcitx UseDarkTheme (file): %s\n' "${use_dark_theme:-unset}"
  else
    printf 'Fcitx config source: none\n'
    printf 'Fcitx Theme (file): unset\n'
    printf 'Fcitx DarkTheme (file): unset\n'
    printf 'Fcitx UseDarkTheme (file): unset\n'
  fi
  if [ -f "${data_home}/fcitx5/themes/MeoInputMethod-Dynamic/theme.conf" ]; then
    printf 'Fcitx dynamic theme files: generated\n'
  else
    printf 'Fcitx dynamic theme files: absent\n'
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
    use_custom="$(gsettings get org.freedesktop.ibus.panel use-custom-theme 2>/dev/null || true)"
    printf 'IBus candidate theme: %s\n' "${selected:-unknown}"
    printf 'IBus custom theme enabled: %s\n' "${use_custom:-unknown}"
  fi
}

case "$action" in
  status) show_status ;;
  sync) sync_selected_themes ;;
  enable)
    case "$framework" in
      fcitx5) enable_fcitx5 ;;
      ibus) enable_ibus ;;
    esac
    ;;
esac
