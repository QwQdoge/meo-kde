#!/usr/bin/env bash
set -euo pipefail

# Existing-layout migration and explicit profile reconciliation only. The
# canonical new-session layout lives in the org.meo.desktop Look-and-Feel
# package; ordinary theme application must not rebuild a user's panels here.

config_root="${XDG_CONFIG_HOME:-${HOME}/.config}"
config_file="${MEO_SHELL_CONFIG:-${config_root}/meo-shellrc}"
dry_run=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --config)
      config_file="$2"
      shift
      ;;
    --dry-run)
      dry_run=1
      ;;
    *)
      echo "Usage: $0 [--config FILE] [--dry-run]" >&2
      exit 2
      ;;
  esac
  shift
done

for command in kreadconfig6 busctl; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "Required command is unavailable: ${command}" >&2
    exit 1
  fi
done
if [ ! -f "${config_file}" ]; then
  echo "Meo shell profile does not exist: ${config_file}" >&2
  exit 1
fi

read_value() {
  kreadconfig6 --file "${config_file}" --group "$1" --key "$2" --default "$3"
}

panel_mode="$(read_value Panels Mode dual)"
dock_implementation="$(read_value Panels DockImplementation standalone)"
show_system_tray="$(read_value Panels ShowSystemTray true)"
show_global_menu="$(read_value Panels ShowGlobalMenu true)"
show_top_app_tasks="$(read_value Panels ShowTopAppTasks false)"
top_panel_height="$(read_value Panels TopPanelHeight 32)"
dock_height="$(read_value Panels DockHeight 80)"
text_scale_percent="$(read_value StatusBar TextScalePercent 100)"
show_network="$(read_value StatusBar ShowNetwork true)"
show_bluetooth="$(read_value StatusBar ShowBluetooth true)"
show_volume="$(read_value StatusBar ShowVolume true)"
battery_display="$(read_value StatusBar BatteryDisplay 2)"
show_date="$(read_value StatusBar ShowDate true)"
show_notifications="$(read_value StatusBar ShowNotifications true)"
use_24_hour_clock="$(read_value StatusBar Use24HourClock true)"

case "${panel_mode}" in
  single|dual) ;;
  *) echo "Panels/Mode must be single or dual, found: ${panel_mode}" >&2; exit 1 ;;
esac
case "${dock_implementation}" in
  standalone|native) ;;
  *) echo "Panels/DockImplementation must be standalone or native, found: ${dock_implementation}" >&2; exit 1 ;;
esac
for boolean in show_system_tray show_global_menu show_top_app_tasks show_network show_bluetooth show_volume show_date show_notifications use_24_hour_clock; do
  case "${!boolean,,}" in
    true|false) printf -v "${boolean}" '%s' "${!boolean,,}" ;;
    *) echo "${boolean} must be true or false" >&2; exit 1 ;;
  esac
done
for integer in top_panel_height dock_height text_scale_percent battery_display; do
  if ! [[ "${!integer}" =~ ^[0-9]+$ ]]; then
    echo "${integer} must be a non-negative integer" >&2
    exit 1
  fi
done
if [ "${top_panel_height}" -lt 32 ] || [ "${top_panel_height}" -gt 96 ]; then
  echo "TopPanelHeight must be between 32 and 96" >&2
  exit 1
fi
if [ "${dock_height}" -lt 40 ] || [ "${dock_height}" -gt 112 ]; then
  echo "DockHeight must be between 40 and 112" >&2
  exit 1
fi
if [ "${text_scale_percent}" -lt 75 ] || [ "${text_scale_percent}" -gt 150 ]; then
  echo "TextScalePercent must be between 75 and 150" >&2
  exit 1
fi
if [ "${battery_display}" -lt 0 ] || [ "${battery_display}" -gt 3 ]; then
  echo "BatteryDisplay must be between 0 and 3" >&2
  exit 1
fi
read -r -d '' plasma_script <<EOF || true
function firstPanel(location) {
    var candidates = panels();
    for (var i = 0; i < candidates.length; ++i) {
        if (candidates[i].location === location) {
            return candidates[i];
        }
    }
    return null;
}

function oneWidget(panel, type) {
    var widgets = panel.widgets(type);
    // Widget removal is delivered asynchronously by plasmashell.  Iterate over
    // this snapshot instead of repeatedly querying widgets(), otherwise a
    // duplicate panel layout can make evaluateScript() spin forever.
    for (var i = 1; i < widgets.length; ++i) {
        widgets[i].remove();
    }
    if (widgets.length === 0) {
        return panel.addWidget(type);
    }
    return widgets[0];
}

function removeWidgets(panel, type) {
    var widgets = panel.widgets(type);
    for (var i = 0; i < widgets.length; ++i) {
        widgets[i].remove();
    }
}

function stringList(value) {
    if (value === undefined || value === null || String(value).length === 0) {
        return [];
    }
    return String(value).split(",");
}

function uniqueWithout(values, blocked) {
    var output = [];
    for (var i = 0; i < values.length; ++i) {
        var value = String(values[i]).trim();
        if (value.length === 0 || blocked.indexOf(value) !== -1 || output.indexOf(value) !== -1) {
            continue;
        }
        output.push(value);
    }
    return output;
}

function markManaged(panel, role) {
    panel.currentConfigGroup = ["MeoShell"];
    panel.writeConfig("Managed", true);
    panel.writeConfig("Role", role);
}

function configureTopbar(widget) {
    widget.currentConfigGroup = ["Appearance"];
    widget.writeConfig("textScalePercent", ${text_scale_percent});
    widget.writeConfig("showNetwork", ${show_network});
    widget.writeConfig("showBluetooth", ${show_bluetooth});
    widget.writeConfig("showVolume", ${show_volume});
    widget.writeConfig("batteryDisplay", ${battery_display});
    widget.writeConfig("showDate", ${show_date});
    widget.writeConfig("showNotifications", ${show_notifications});
    widget.writeConfig("use24HourClock", ${use_24_hour_clock});
    widget.reloadConfig();
}

function configureTimeCenter(widget) {
    widget.currentConfigGroup = ["Appearance"];
    widget.writeConfig("textScalePercent", ${text_scale_percent});
    widget.writeConfig("showDate", ${show_date});
    widget.writeConfig("showNotifications", ${show_notifications});
    widget.writeConfig("use24HourClock", ${use_24_hour_clock});
    widget.reloadConfig();
}

function configureTray(widget) {
    var blocked = [
        "org.kde.plasma.networkmanagement",
        "org.kde.plasma.bluetooth",
        "org.kde.plasma.volume",
        "org.kde.plasma.battery",
        "org.kde.plasma.brightness",
        "org.kde.plasma.mediacontroller",
        "org.kde.plasma.notifications"
    ];
    var usefulDefaults = [
        "org.kde.kdeconnect",
        "org.kde.plasma.cameraindicator",
        "org.kde.plasma.clipboard",
        "org.kde.plasma.devicenotifier",
        "org.kde.plasma.manage-inputmethod",
        "org.kde.plasma.keyboardindicator",
        "org.kde.plasma.weather",
        "org.kde.kscreen",
        "org.kde.plasma.keyboardlayout",
        "org.kde.plasma.vault",
        "org.kde.plasma.printmanager"
    ];
    widget.currentConfigGroup = ["General"];
    var currentItems = stringList(widget.readConfig("extraItems", ""));
    var items = uniqueWithout(currentItems.length > 0 ? currentItems : usefulDefaults, blocked);
    var hidden = uniqueWithout(stringList(widget.readConfig("hiddenItems", "")), []);
    if (hidden.indexOf("org.kde.plasma.devicenotifier") === -1) {
        hidden.push("org.kde.plasma.devicenotifier");
    }
    for (var i = 0; i < blocked.length; ++i) {
        if (hidden.indexOf(blocked[i]) === -1) {
            hidden.push(blocked[i]);
        }
    }
    widget.writeConfig("extraItems", items.join(","));
    widget.writeConfig("hiddenItems", hidden.join(","));
    widget.reloadConfig();
}

var top = firstPanel("top");
if (!top) {
    top = new Panel;
    top.location = "top";
}
top.height = ${top_panel_height};
if (top.height !== ${top_panel_height}) {
    throw new Error(
        "Meo top panel " + top.id + " height was clamped to " + top.height
        + "; requested ${top_panel_height}. Install a panel background with a compatible minimum drawing height first."
    );
}
top.hiding = "none";
top.floating = false;
markManaged(top, "top");

var kickoff = oneWidget(top, "org.kde.plasma.kickoff");
kickoff.currentConfigGroup = ["Shortcuts"];
kickoff.writeConfig("global", "Meta");
kickoff.reloadConfig();

var topOrder = [kickoff.id];
var globalMenu = null;
if (${show_global_menu}) {
    globalMenu = oneWidget(top, "org.kde.plasma.appmenu");
    topOrder.push(globalMenu.id);
} else {
    removeWidgets(top, "org.kde.plasma.appmenu");
}
var topTasks = null;
if (${show_top_app_tasks}) {
    // This upstream Plasma applet owns Wayland/X11 task context, activation,
    // minimisation and app grouping. Keep it adjacent to the global menu;
    // visual shell controls remain MeoUI components on the right.
    topTasks = oneWidget(top, "org.kde.plasma.icontasks");
    topOrder.push(topTasks.id);
} else {
    removeWidgets(top, "org.kde.plasma.icontasks");
}
var spacer = oneWidget(top, "org.kde.plasma.panelspacer");
topOrder.push(spacer.id);
var tray = null;
if (${show_system_tray}) {
    // Reuse the existing containment. Recreating it would discard manual
    // StatusNotifier visibility and application-icon choices.
    tray = oneWidget(top, "org.kde.plasma.systemtray");
    configureTray(tray);
    topOrder.push(tray.id);
} else {
    removeWidgets(top, "org.kde.plasma.systemtray");
}
var topbar = oneWidget(top, "org.meo.topbar");
configureTopbar(topbar);
topOrder.push(topbar.id);
var timeCenter = oneWidget(top, "org.meo.timecenter");
configureTimeCenter(timeCenter);
topOrder.push(timeCenter.id);
removeWidgets(top, "org.meo.toptasks");
top.currentConfigGroup = ["General"];
top.writeConfig("AppletOrder", topOrder.join(";"));
top.reloadConfig();

var dock = firstPanel("bottom");
if ("${panel_mode}" === "dual" && "${dock_implementation}" === "native") {
    if (!dock) {
        dock = new Panel;
        dock.location = "bottom";
    }
    dock.height = ${dock_height};
    dock.floating = true;
    dock.hiding = "autohide";
    dock.lengthMode = "fit";
    dock.alignment = "center";
    markManaged(dock, "dock");
    var dockTasks = oneWidget(dock, "org.kde.plasma.icontasks");
    dockTasks.index = 0;
    dock.reloadConfig();
} else if (dock) {
    dock.currentConfigGroup = ["MeoShell"];
    if (dock.readConfig("Managed", false) === true || dock.readConfig("Managed", false) === "true") {
        dock.remove();
    }
}
EOF

if [ "${dry_run}" -eq 1 ]; then
  printf 'Would apply Meo panel profile from %s: mode=%s dock-implementation=%s tray=%s global-menu=%s top-app-tasks=%s top=%s dock=%s text=%s battery=%s\n' \
    "${config_file}" "${panel_mode}" "${dock_implementation}" "${show_system_tray}" "${show_global_menu}" "${show_top_app_tasks}" "${top_panel_height}" "${dock_height}" "${text_scale_percent}" "${battery_display}"
  exit 0
fi

busctl --user call \
    org.kde.plasmashell \
    /PlasmaShell \
    org.kde.PlasmaShell \
    evaluateScript \
    s "${plasma_script}" >/dev/null
echo "Applied Meo panel profile: mode=${panel_mode}, dock=${dock_implementation}, system tray=${show_system_tray}."
