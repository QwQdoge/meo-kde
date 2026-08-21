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
        self.assertIn('bottomPanel.height = 56', source)
        self.assertNotIn('writeConfig("maxStripes"', source)
        self.assertNotIn('org.meo.shelf', source)

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
        self.assertIn('ListView', notification_center)
        self.assertIn('MeoTheme.surfaceContainerHigh', notification_center)
        self.assertIn('org.kde.notificationmanager', time_main)
        self.assertIn('org.kde.plasma.clock', time_main)
        self.assertIn('NotificationManager.Notifications', time_main)
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
        self.assertIn("tileLayoutChanged", center)
        self.assertIn("Plasmoid.configuration.quickTileOrder", main)

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

    def test_bottom_dock_matches_meoui_shelf_metric_without_custom_task_skin(self):
        profile = (REPO_ROOT / "defaults/plasma/meo-shellrc").read_text(encoding="utf-8")
        helper = (REPO_ROOT / "tools/shell/apply-meo-panel-layout.sh").read_text(encoding="utf-8")
        metrics = (REPO_ROOT / "qml/MeoKDE/ShellMetrics.qml").read_text(encoding="utf-8")

        self.assertIn("DockHeight=56", profile)
        self.assertIn("shelfPanelHeight: 56 * MeoTheme.globalScale", metrics)
        self.assertNotIn('writeConfig("maxStripes"', helper)
        self.assertFalse((REPO_ROOT / "themes/desktoptheme/MeoLight/widgets/tasks.svg").exists())
        self.assertFalse((REPO_ROOT / "themes/desktoptheme/MeoDark/widgets/tasks.svg").exists())

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
            '"${repo_root}/tools/shell/apply-meo-panel-layout.sh"',
            source[source.index("if [ \"${apply_theme}\" -eq 1 ]"):],
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
        self.assertIn('kwin4_effect_shapecorners.so', setup)
        self.assertIn('rm -f "${user_plugin_root}/kwin/effects/plugins/org.meo.windowcorners.so"', setup)
        self.assertNotIn('native_build_root}/bin/kwin/effects/plugins/org.meo.windowcorners.so', setup)
        self.assertIn('"${meoui_build_root}"/libmeoui.so*', setup)

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
        self.assertIn("setup themes tools", workspace_sync)

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
