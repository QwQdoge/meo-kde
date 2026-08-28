"""Regression checks for the first-party Plasma shell composition."""

from pathlib import Path
import configparser
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
LAYOUT = REPO_ROOT / "themes/look-and-feel/org.meo.desktop/contents/layouts/org.kde.plasma.desktop-layout.js"
INSTALLER = REPO_ROOT / "setup/apply-meo-desktop.sh"
TOPBAR = REPO_ROOT / "plasmoids/org.meo.topbar/contents/ui"


class DesktopLayoutTests(unittest.TestCase):
    def test_top_panel_uses_kde_launcher_menu_tray_and_two_meo_surfaces(self):
        source = LAYOUT.read_text(encoding="utf-8")

        self.assertIn('topPanel.addWidget("org.kde.plasma.kickoff")', source)
        self.assertIn('launcher.writeConfig("global", "Meta")', source)
        self.assertIn('topPanel.addWidget("org.kde.plasma.appmenu")', source)
        self.assertNotIn('topPanel.addWidget("org.kde.plasma.icontasks")', source)
        self.assertNotIn('topPanel.addWidget("org.meo.toptasks")', source)
        self.assertIn('quickSettings = topPanel.addWidget("org.meo.topbar")', source)
        self.assertIn('timeCenter = topPanel.addWidget("org.meo.timecenter")', source)
        self.assertIn('topPanel.addWidget("org.kde.plasma.systemtray")', source)
        self.assertLess(source.index('topPanel.addWidget("org.kde.plasma.systemtray")'), source.index('topPanel.addWidget("org.meo.topbar")'))
        extra_items_line = next(
            line for line in source.splitlines()
            if 'writeConfig("extraItems"' in line
        )
        self.assertNotIn('org.kde.plasma.notifications', extra_items_line)
        self.assertNotIn('org.kde.plasma.mediacontroller', extra_items_line)
        self.assertIn('org.kde.plasma.notifications', source)
        self.assertIn('org.kde.plasma.mediacontroller', source)
        self.assertIn('quickSettings.writeConfig("batteryDisplay", 2)', source)
        self.assertIn('timeCenter.writeConfig("showDate", true)', source)

    def test_bottom_dock_is_native_and_auto_hides(self):
        source = LAYOUT.read_text(encoding="utf-8")

        self.assertIn('bottomPanel.floating = true', source)
        self.assertIn('bottomPanel.hiding = "autohide"', source)
        self.assertIn('bottomPanel.addWidget("org.kde.plasma.icontasks")', source)
        self.assertIn('bottomPanel.height = 64', source)
        self.assertNotIn('writeConfig("maxStripes"', source)
        self.assertNotIn('org.meo.shelf', source)

    def test_top_panel_uses_the_compact_32px_baseline_everywhere(self):
        layout = LAYOUT.read_text(encoding="utf-8")
        profile = (REPO_ROOT / "defaults/plasma/meo-shellrc").read_text(encoding="utf-8")
        helper = (REPO_ROOT / "tools/shell/apply-meo-panel-layout.sh").read_text(encoding="utf-8")
        metrics = (REPO_ROOT / "qml/MeoKDE/ShellMetrics.qml").read_text(encoding="utf-8")
        documentation = (REPO_ROOT / "docs/shell-configuration.md").read_text(encoding="utf-8")

        self.assertIn("topPanel.height = 32", layout)
        self.assertIn("TopPanelHeight=32", profile)
        self.assertIn("read_value Panels TopPanelHeight 32", helper)
        self.assertIn("Meo top panel", helper)
        self.assertIn("height was clamped", helper)
        self.assertIn("topBarHeight: 32 * MeoTheme.globalScale", metrics)
        self.assertIn("TopPanelHeight=32", documentation)
        self.assertIn("false success", documentation)

    def test_panel_frame_keeps_a_compact_top_and_large_bottom_dock_variant(self):
        assets = (
            REPO_ROOT / "themes/desktoptheme/MeoLight/widgets/panel-background.svg",
            REPO_ROOT / "themes/desktoptheme/MeoDark/widgets/panel-background.svg",
            REPO_ROOT / "themes/desktoptheme/MeoLight/translucent/widgets/panel-background.svg",
            REPO_ROOT / "themes/desktoptheme/MeoDark/translucent/widgets/panel-background.svg",
        )
        generator = (REPO_ROOT / "tools/theme/build_floating_dock_assets.py").read_text(encoding="utf-8")

        self.assertIn('compact_frame = frame_paths("", 16)', generator)
        self.assertIn('north_frame = frame_paths("north", 16)', generator)
        self.assertIn('south_frame = frame_paths("south", 28)', generator)
        for asset in assets:
            source = asset.read_text(encoding="utf-8")
            self.assertIn('id="top" d="M32 16h2v16h-2z"', source)
            self.assertIn('id="north-top" d="M32 16h2v16h-2z"', source)
            self.assertIn('id="south-top" d="M32 4h2v28h-2z"', source)
            self.assertIn('id="north-bottom" d="M32 34h2v16h-2z"', source)
            self.assertIn('id="south-bottom" d="M32 34h2v28h-2z"', source)
            self.assertIn('id="north-hint-top-margin"', source)
            self.assertIn('id="south-hint-top-margin"', source)

    def test_topbar_is_backed_by_real_kde_models(self):
        status_center = (REPO_ROOT / "plasmoids/org.meo.timecenter/contents/ui/TimeNotificationCenter.qml").read_text(encoding="utf-8")
        notification_center = (REPO_ROOT / "qml/MeoKDE/NotificationCenterView.qml").read_text(encoding="utf-8")
        time_main = (REPO_ROOT / "plasmoids/org.meo.timecenter/contents/ui/main.qml").read_text(encoding="utf-8")
        quick_main = (TOPBAR / "main.qml").read_text(encoding="utf-8")
        quick_settings = (TOPBAR / "QuickSettingsHome.qml").read_text(encoding="utf-8")
        quick_center = (TOPBAR / "QuickSettingsCenter.qml").read_text(encoding="utf-8")
        audio_page = (TOPBAR / "AudioPage.qml").read_text(encoding="utf-8")

        self.assertIn('MeoMonthCalendar', status_center)
        self.assertIn('NotificationCenterView', status_center)
        self.assertIn('applications:org.meo.settings.desktop', status_center)
        self.assertIn('ListView', notification_center)
        self.assertIn('MeoTheme.surfaceContainerHigh', notification_center)
        self.assertIn('org.kde.notificationmanager', time_main)
        self.assertIn('org.kde.plasma.clock', time_main)
        self.assertIn('NotificationManager.Notifications', time_main)
        self.assertIn('id: notificationModel', time_main)
        self.assertIn('notifications: notificationModel', time_main)
        self.assertNotIn('notifications: root.notifications', time_main)
        self.assertIn('compactRepresentation: TimeNotificationButton', time_main)
        self.assertIn('Layout.minimumWidth: 0', time_main)
        self.assertIn('QuickSettingsCenter', quick_main)
        self.assertNotIn('TimeNotificationButton', quick_main)
        self.assertIn('SystemState.', quick_settings)
        self.assertIn('Platform.', quick_settings)
        self.assertIn('Media.', quick_settings)
        self.assertIn('Platform.lockScreen()', quick_settings)
        self.assertIn('NotificationManager.Server.inhibited', quick_settings)
        self.assertIn('NotificationManager.Server.inhibited', notification_center)
        self.assertIn('clearClosableNotifications()', notification_center)
        self.assertIn('invokeAction', notification_center)
        self.assertIn('root.notifications.reply', notification_center)
        self.assertIn('suspendJob', notification_center)
        self.assertIn('resumeJob', notification_center)
        self.assertIn('killJob', notification_center)
        self.assertIn('MeoProgressBar', notification_center)
        self.assertIn('add: Transition', notification_center)
        self.assertIn('remove: Transition', notification_center)
        self.assertIn('displaced: Transition', notification_center)
        self.assertIn('ListView.onReused', notification_center)
        self.assertIn('Behavior on implicitHeight', notification_center)
        self.assertIn('pushExit: Transition', quick_center)
        self.assertIn('popEnter: Transition', quick_center)
        self.assertIn('prepareToClose()', quick_center)
        self.assertIn('fullRepresentationItem.prepareToClose()', quick_main)
        self.assertIn('scheduleSaveTiles()', quick_settings)
        self.assertIn('interval: 180', quick_settings)
        self.assertIn('relativeTime', notification_center)
        self.assertIn('use24HourClock', status_center)
        self.assertIn('onBluetoothDetailsRequested: stack.push(bluetoothPageComponent)', quick_center)
        self.assertIn('onAudioDetailsRequested: stack.push(audioPageComponent)', quick_center)
        self.assertIn('SystemState.setDefaultAudioOutput', audio_page)
        self.assertIn('SystemState.setDefaultAudioInput', audio_page)
        self.assertIn('QQC2.ScrollView', audio_page)
        self.assertIn('contentHeight: pageContent.implicitHeight', audio_page)

    def test_quick_settings_grid_is_editable_resizable_and_persistent(self):
        home = (TOPBAR / "QuickSettingsHome.qml").read_text(encoding="utf-8")
        center = (TOPBAR / "QuickSettingsCenter.qml").read_text(encoding="utf-8")
        main = (TOPBAR / "main.qml").read_text(encoding="utf-8")
        config = (REPO_ROOT / "plasmoids/org.meo.topbar/contents/config/main.xml").read_text(encoding="utf-8")

        self.assertIn("MeoQuickSettingsTile", home)
        self.assertIn("MeoQuickControlSlider", home)
        self.assertIn("DropArea", home)
        self.assertIn("tileModel.move", home)
        self.assertIn('"tileSpan"', home)
        self.assertIn("MeoExposedDropdown", home)
        self.assertIn("audioExpanded", home)
        self.assertIn("displayExpanded", home)
        self.assertIn('"audioDevices", "display", "screenshot"', home)
        self.assertIn('Qt.openUrlExternally("systemsettings:kcm_kscreen")', home)
        self.assertIn('Qt.openUrlExternally("applications:org.kde.spectacle.desktop")', home)
        self.assertIn('SystemState.audioDevice', home)
        self.assertIn("quickTileOrder", config)
        self.assertIn("quickTileSizes", config)
        self.assertIn("quickTileVisibility", config)
        self.assertIn("quickTileDensity", config)
        self.assertIn("tileLayoutChanged", center)
        self.assertIn("Plasmoid.configuration.quickTileOrder", main)
        self.assertIn("Plasmoid.configuration.quickTileVisibility", main)
        self.assertIn("Plasmoid.configuration.quickTileDensity", main)
        self.assertIn('applications:org.meo.settings.desktop', home)
        self.assertIn('Qt.openUrlExternally("systemsettings:")', home)
        self.assertIn("root.availableWidth < 320 * MeoTheme.globalScale ? 2 : 4", home)

    def test_control_center_settings_contract_keeps_the_meo_applet_authoritative(self):
        schema = (TOPBAR.parent / "config/main.xml").read_text(encoding="utf-8")
        home = (TOPBAR / "QuickSettingsHome.qml").read_text(encoding="utf-8")
        layout = LAYOUT.read_text(encoding="utf-8")
        documentation = (REPO_ROOT / "docs/shell-configuration.md").read_text(encoding="utf-8")

        self.assertIn('name="quickTileVisibility"', schema)
        self.assertIn('name="quickTileDensity"', schema)
        self.assertIn('quickSettings.writeConfig("quickTileVisibility"', layout)
        self.assertIn('quickSettings.writeConfig("quickTileDensity", "comfortable")', layout)
        self.assertIn("function visibleTileIds()", home)
        self.assertIn("tileDensityScale", home)
        self.assertIn("quickTileVisibility", documentation)
        self.assertIn("org.meo.settings.desktop", documentation)

    def test_status_and_quick_settings_have_compact_width_contracts(self):
        status = (REPO_ROOT / "plasmoids/org.meo.timecenter/contents/ui/TimeNotificationCenter.qml").read_text(encoding="utf-8")
        quick_center = (TOPBAR / "QuickSettingsCenter.qml").read_text(encoding="utf-8")

        self.assertIn("Layout.minimumWidth: 320 * MeoTheme.globalScale", status)
        self.assertIn("root.width >= 620 * MeoTheme.globalScale", status)
        self.assertIn("Layout.minimumWidth: 280 * MeoTheme.globalScale", quick_center)

    def test_quick_control_sliders_expose_real_actions_and_names(self):
        home = (TOPBAR / "QuickSettingsHome.qml").read_text(encoding="utf-8")

        self.assertIn('qsTr("Display brightness")', home)
        self.assertIn("iconActionEnabled: false", home)
        self.assertIn('accessibleName: qsTr("Output volume")', home)
        self.assertIn('qsTr("Mute output")', home)
        self.assertIn('accessibleName: qsTr("Microphone volume")', home)
        self.assertIn('qsTr("Mute microphone")', home)

    def test_bluetooth_quick_settings_uses_meo_for_full_pairing_before_kde_fallback(self):
        bluetooth_page = (TOPBAR / "BluetoothPage.qml").read_text(encoding="utf-8")
        legacy_center = (TOPBAR / "ControlCenter.qml").read_text(encoding="utf-8")
        documentation = (REPO_ROOT / "docs/shell-configuration.md").read_text(encoding="utf-8")

        # Keep immediate controls attached to the live state hub, but never
        # let an unpaired-device tap silently start a pairing conversation in
        # the compact popup.
        self.assertIn('SystemState.bluetoothEnabled = checked', bluetooth_page)
        self.assertIn('SystemState.startBluetoothDiscovery()', bluetooth_page)
        self.assertIn('SystemState.stopBluetoothDiscovery()', bluetooth_page)
        self.assertIn('SystemState.toggleBluetoothDevice(modelData.address)', bluetooth_page)
        self.assertIn('SystemState.forgetBluetoothDevice(modelData.address)', bluetooth_page)
        self.assertIn('if (!modelData.paired)', bluetooth_page)
        self.assertIn('root.openMeoBluetoothSettings()', bluetooth_page)

        # The dedicated deep-link launcher is first choice. The generic Meo
        # launcher remains a package-compatibility fallback, with the KDE KCM
        # reachable only when neither Meo launcher exists.
        dedicated_launcher = 'applications:org.meo.settings.bluetooth.desktop'
        generic_launcher = 'applications:org.meo.settings.desktop'
        kde_fallback = 'systemsettings:kcm_bluetooth'
        self.assertIn(dedicated_launcher, bluetooth_page)
        self.assertIn(generic_launcher, bluetooth_page)
        self.assertIn(kde_fallback, bluetooth_page)
        self.assertLess(bluetooth_page.index(dedicated_launcher), bluetooth_page.index(generic_launcher))
        self.assertLess(bluetooth_page.index(generic_launcher), bluetooth_page.index(kde_fallback))
        self.assertIn('onBluetoothDetailsRequested: root.openMeoBluetoothSettings()', legacy_center)
        self.assertIn('org.meo.settings.bluetooth.desktop', documentation)
        self.assertIn('KDE System Settings is a recovery path', documentation)

    def test_system_state_bluetooth_fast_path_never_pairs_or_auto_trusts(self):
        source = (REPO_ROOT / "native/system/systemstatehub.cpp").read_text(encoding="utf-8")
        start = source.index("void SystemStateHub::toggleBluetoothDevice")
        end = source.index("void SystemStateHub::forgetBluetoothDevice", start)
        toggle = source[start:end]

        # A menu toggle may connect and disconnect an existing pairing, but
        # cannot turn a stale QML call into a security-sensitive pairing or
        # persistent trust change.  Pairing belongs to Meo Settings' agent.
        self.assertIn('Pair new devices in Meo Settings.', toggle)
        self.assertNotIn('device->pair()', toggle)
        self.assertNotIn('setTrusted(true)', toggle)
        self.assertIn('bluezInit->start()', source)

    def test_meoui_update_is_explicit_opt_in(self):
        source = INSTALLER.read_text(encoding="utf-8")

        self.assertIn("refresh_meoui=0", source)
        self.assertIn("--update-meoui) refresh_meoui=1", source)

    def test_validation_instantiates_shared_shell_components(self):
        validator = (REPO_ROOT / "scripts/validate.sh").read_text(encoding="utf-8")
        smoke = (REPO_ROOT / "validation/meoui-shell-components-smoke.qml").read_text(encoding="utf-8")

        self.assertIn("meoui-shell-components-smoke.qml", validator)
        self.assertIn('${output_root}/meo-kde/validation/${validation_run_id}', validator)
        self.assertIn("MeoStatusCenter", smoke)

    def test_reset_removes_every_named_runtime_installed_by_setup(self):
        installer = INSTALLER.read_text(encoding="utf-8")
        reset = (REPO_ROOT / "setup/reset-meo-desktop.sh").read_text(encoding="utf-8")

        for owned_path in (
            '${data_root}/icons/MeoSymbols',
            '${data_root}/icons/MeoSymbolsDark',
            '${qml_root}/MeoUI',
            '${data_root}/fcitx5/themes/MeoInputMethod-Light',
            '${data_root}/fcitx5/themes/MeoInputMethod-Dark',
            '${data_root}/fcitx5/themes/MeoInputMethod-Dynamic',
            '${data_root}/color-schemes/MeoLight.colors',
            '${data_root}/color-schemes/MeoDark.colors',
            '${data_root}/color-schemes/MeoDynamicLight.colors',
            '${data_root}/color-schemes/MeoDynamicDark.colors',
            '${user_plugin_root}/styles/meostyle.so',
            '${local_bin_root}/meo-input-method',
            '${local_bin_root}/meo-desktop-layout',
            '${local_bin_root}/meo-desktop-apply',
        ):
            self.assertIn(owned_path, reset)
        self.assertIn("runtime-backup-v1", installer)
        self.assertIn("runtime-backup-v1", reset)
        self.assertIn('${backup_root}/runtime/${runtime_group}/.', reset)

    def test_native_application_and_dynamic_color_bridges_are_installed(self):
        defaults = configparser.ConfigParser(interpolation=None)
        defaults.optionxform = str
        defaults.read(REPO_ROOT / "defaults/kde/kdeglobals", encoding="utf-8")
        self.assertEqual(defaults["KDE"]["widgetStyle"], "Meo")
        self.assertEqual(defaults["General"]["accentColorFromWallpaper"], "true")

        look_and_feel = (REPO_ROOT / "themes/look-and-feel/org.meo.desktop/contents/defaults").read_text(
            encoding="utf-8"
        )
        self.assertIn("widgetStyle=Meo", look_and_feel)
        self.assertIn("accentColorFromWallpaper=true", look_and_feel)
        self.assertNotIn("AccentColorFromWallpaper", look_and_feel)

        environment = (REPO_ROOT / "defaults/environment/90-meo-applications.conf").read_text(
            encoding="utf-8"
        )
        self.assertIn("QT_STYLE_OVERRIDE=Meo", environment)
        self.assertIn("SAL_USE_VCLPLUGIN=kf6", environment)

        installer = INSTALLER.read_text(encoding="utf-8")
        reset = (REPO_ROOT / "setup/reset-meo-desktop.sh").read_text(encoding="utf-8")
        package = (REPO_ROOT / "packaging/arch/PKGBUILD").read_text(encoding="utf-8")
        apply_helper = (REPO_ROOT / "tools/theme/apply-meo-desktop.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn('qt-plugins/styles/meostyle.so', installer)
        self.assertIn('styles/meostyle.so', reset)
        self.assertIn('MEO_DYNAMIC_COLORS_HELPER', installer)
        self.assertIn('meo-dynamic-colors.path', package)
        self.assertIn('default.target.wants/meo-dynamic-colors.path', package)
        self.assertIn('enable --now meo-dynamic-colors.path', apply_helper)

    def test_reset_reloads_restored_input_method_state(self):
        reset = (REPO_ROOT / "setup/reset-meo-desktop.sh").read_text(encoding="utf-8")

        self.assertIn("ReloadAddonConfig s classicui", reset)
        self.assertIn("GetConfig s fcitx://config/addon/classicui", reset)
        self.assertIn('custom-theme Adwaita', reset)

    def test_top_application_icons_use_the_native_system_tray(self):
        source = (REPO_ROOT / "tools/shell/apply-meo-panel-layout.sh").read_text(encoding="utf-8")

        self.assertIn('oneWidget(top, "org.kde.plasma.systemtray")', source)
        self.assertIn('top.writeConfig("AppletOrder", topOrder.join(";"))', source)
        self.assertIn('widget.readConfig("extraItems", "")', source)
        self.assertIn('"org.kde.plasma.networkmanagement"', source)
        self.assertIn('"org.kde.plasma.notifications"', source)
        self.assertIn('"org.kde.plasma.vault"', source)
        self.assertIn('"org.kde.plasma.printmanager"', source)
        self.assertNotIn('removeWidgets(top, "org.kde.plasma.systemtray");\n    removeWidgets', source)
        self.assertNotIn('oneWidget(top, "org.meo.toptasks")', source)

    def test_bottom_dock_keeps_native_tasks_with_md3_task_frames(self):
        profile = (REPO_ROOT / "defaults/plasma/meo-shellrc").read_text(encoding="utf-8")
        helper = (REPO_ROOT / "tools/shell/apply-meo-panel-layout.sh").read_text(encoding="utf-8")
        metrics = (REPO_ROOT / "qml/MeoKDE/ShellMetrics.qml").read_text(encoding="utf-8")

        self.assertIn("DockHeight=64", profile)
        self.assertIn("shelfPanelHeight: 64 * MeoTheme.globalScale", metrics)
        self.assertNotIn('writeConfig("maxStripes"', helper)
        expected_fallbacks = {
            "MeoLight": ("#1c1b1f", "#6750a4", "#b3261e"),
            "MeoDark": ("#e6e0e9", "#d0bcff", "#ffb4ab"),
        }
        required_frames = (
            "normal", "normal-hover", "focus", "focus-hover",
            "minimized", "minimized-hover", "attention", "attention-hover",
            "progress", "launcher-hover",
        )
        required_parts = (
            "center", "top", "left", "right", "topleft", "topright",
            "bottomleft", "bottomright", "bottom",
        )
        for mode, fallbacks in expected_fallbacks.items():
            task_frame = (REPO_ROOT / f"themes/desktoptheme/{mode}/widgets/tasks.svg").read_text(encoding="utf-8")
            for fallback in fallbacks:
                self.assertIn(fallback, task_frame)
            for frame in required_frames:
                for part in required_parts:
                    self.assertIn(f'id="{frame}-{part}"', task_frame)
            self.assertIn('ColorScheme-ButtonFocus', task_frame)
            self.assertIn('id="group-expander-bottom"', task_frame)

    def test_installer_preflights_rounding_without_package_manager_mutation(self):
        source = INSTALLER.read_text(encoding="utf-8")
        package = (REPO_ROOT / "packaging/arch/PKGBUILD").read_text(
            encoding="utf-8"
        )

        self.assertIn('preflight_plasma()', source)
        self.assertIn('org.kde.plasma.icontasks', source)
        self.assertIn('org.kde.plasma.systemtray', source)
        self.assertIn('org.kde.plasma.kickoff', source)
        self.assertIn('kwin4_effect_shapecorners.so', source)
        self.assertIn("'kwin-effect-rounded-corners'", package)
        self.assertNotIn('kwin-effect-rounded-corners-git', source)
        self.assertNotIn('paru ', source)
        self.assertNotIn('yay ', source)

    def test_look_and_feel_is_the_default_layout_authority(self):
        source = INSTALLER.read_text(encoding="utf-8")
        helper = (REPO_ROOT / "tools/shell/apply-meo-panel-layout.sh").read_text(
            encoding="utf-8"
        )
        apply_helper = (REPO_ROOT / "tools/theme/apply-meo-desktop.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn("canonical new-session layout", helper)
        self.assertNotIn(
            'run "${repo_root}/tools/shell/apply-meo-panel-layout.sh"',
            source,
        )
        self.assertIn("tools/theme/apply-meo-desktop.sh", source)
        self.assertIn("--resetLayout", apply_helper)
        self.assertNotIn("apply-meo-panel-layout.sh", apply_helper)
        self.assertNotIn("--key TitleBarHeight", source)
        self.assertNotIn("--key CornerRadius", source)
        self.assertNotIn("--key TitleBarHeight", apply_helper)
        self.assertNotIn("--key CornerRadius", apply_helper)

    def test_stable_kwin_effect_owns_client_surface_rounding(self):
        native = (REPO_ROOT / "native/CMakeLists.txt").read_text(encoding="utf-8")
        defaults = (REPO_ROOT / "defaults/kwin/kwinrc").read_text(encoding="utf-8")
        setup = INSTALLER.read_text(encoding="utf-8")

        self.assertNotIn('add_subdirectory(effects/windowcorners)', native)
        self.assertIn('org.meo.windowcornersEnabled=false', defaults)
        self.assertIn('kwin4_effect_shapecornersEnabled=true', defaults)
        self.assertIn('EnableCompanionEffect=false', defaults)
        self.assertIn('CornerRadius=16', defaults)
        self.assertIn('ButtonDiameter=24', defaults)
        self.assertIn('ButtonSpacing=2', defaults)
        self.assertIn('Size=16', defaults)
        self.assertIn('InactiveCornerRadius=16', defaults)
        self.assertIn('kwin4_effect_shapecorners.so', setup)
        self.assertIn('rm -f "${user_plugin_root}/kwin/effects/plugins/org.meo.windowcorners.so"', setup)
        self.assertNotIn('native_build_root}/bin/kwin/effects/plugins/org.meo.windowcorners.so', setup)
        self.assertIn('"${meoui_build_root}"/libmeoui.so*', setup)

    def test_shell_geometry_uses_cross_toolkit_semantic_roles(self):
        metrics = (REPO_ROOT / "qml/MeoKDE/ShellMetrics.qml").read_text(encoding="utf-8")
        mapped_roles = {
            "radiusWindow": "MeoTheme.windowRadius",
            "radiusPopup": "MeoTheme.dialogRadius",
            "radiusLarge": "MeoTheme.cardRadius",
            "radiusControl": "MeoTheme.controlRadius",
            "focusRingWidth": "MeoTheme.focusRingWidth",
        }
        for role, token in mapped_roles.items():
            self.assertIn(f"{role}: {token}", metrics)

        surfaces = (
            REPO_ROOT / "qml/MeoKDE/PopupInlineMessage.qml",
            REPO_ROOT / "qml/MeoKDE/NotificationCenterView.qml",
            REPO_ROOT / "plasmoids/org.meo.topbar/contents/ui/ControlCenter.qml",
            REPO_ROOT / "plasmoids/org.meo.topbar/contents/ui/QuickSettingsHome.qml",
            REPO_ROOT / "plasmoids/org.meo.shelf/contents/ui/LauncherPopup.qml",
        )
        for surface in surfaces:
            source = surface.read_text(encoding="utf-8")
            self.assertNotRegex(source, r"radius:\s*MeoTheme\.shape(?:Medium|Large|ExtraLarge)\b")

    def test_every_kwin_profile_matches_the_canonical_defaults(self):
        canonical = configparser.ConfigParser(interpolation=None)
        canonical.optionxform = str
        canonical.read(REPO_ROOT / "defaults/kwin/kwinrc", encoding="utf-8")

        look_and_feel = configparser.ConfigParser(interpolation=None)
        look_and_feel.optionxform = str
        look_and_feel.read(
            REPO_ROOT / "themes/look-and-feel/org.meo.desktop/contents/defaults",
            encoding="utf-8",
        )
        for section in canonical.sections():
            projected = f"kwinrc][{section}"
            self.assertTrue(look_and_feel.has_section(projected), section)
            self.assertEqual(dict(canonical[section]), dict(look_and_feel[projected]))

        apply_helper = (REPO_ROOT / "tools/theme/apply-meo-desktop.sh").read_text(
            encoding="utf-8"
        )
        package = (REPO_ROOT / "packaging/arch/PKGBUILD").read_text(encoding="utf-8")
        workspace_sync = (REPO_ROOT / "scripts/sync-to-workspace.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn('apply_kwin_defaults "${kwin_defaults}"', apply_helper)
        self.assertIn("--kwin-only", apply_helper)
        self.assertIn('/usr/share/meo-desktop/defaults/kwinrc', apply_helper)
        self.assertIn('usr/share/meo-desktop/defaults/kwinrc', package)
        self.assertIn("scripts/sync-installer-to-airootfs.sh", workspace_sync)
        self.assertIn('exec "${workspace_sync}"', workspace_sync)

    def test_profile_and_applet_schema_cover_the_customisation_contract(self):
        profile = (REPO_ROOT / "defaults/plasma/meo-shellrc").read_text(encoding="utf-8")
        schema = (TOPBAR.parent / "config/main.xml").read_text(encoding="utf-8")

        self.assertIn("Mode=dual", profile)
        self.assertIn("ProfileVersion=3", profile)
        self.assertIn("ShowSystemTray=true", profile)
        self.assertIn("ShowGlobalMenu=true", profile)
        self.assertIn("ShowTopAppTasks=false", profile)
        self.assertIn("TextScalePercent=100", profile)
        self.assertIn("BatteryDisplay=2", profile)
        self.assertIn('name="textScalePercent"', schema)
        self.assertIn('name="batteryDisplay"', schema)


if __name__ == "__main__":
    unittest.main()
