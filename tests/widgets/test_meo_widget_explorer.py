"""Contracts for the dual-host desktop Widget Explorer."""

import json
import hashlib
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
APPLETS = REPO_ROOT / "plasmoids"
BRIDGE = REPO_ROOT / "native/system/desktopwidgetbridge.cpp"
BRIDGE_HEADER = REPO_ROOT / "native/system/desktopwidgetbridge.h"
LAYOUT = REPO_ROOT / "themes/look-and-feel/org.meo.desktop/contents/layouts/org.kde.plasma.desktop-layout.js"
PACKAGE = REPO_ROOT / "packaging/arch/PKGBUILD"
PLASMA_DESKTOP_PACKAGE = REPO_ROOT / "packaging/arch/meo-plasma-desktop"
PLASMA_DESKTOP_PATCH = PLASMA_DESKTOP_PACKAGE / "0001-meo-widget-presentation.patch"
PLATFORM_DOC = REPO_ROOT / "docs/widget-platform.md"
MEO_WIDGET = REPO_ROOT.parent / "meo-ui/components/MeoWidget.qml"
MEO_KDE_QML = REPO_ROOT / "qml/MeoKDE"
POWER_PAGE = APPLETS / "org.meo.topbar/contents/ui/PowerPage.qml"
QUICK_SETTINGS = APPLETS / "org.meo.topbar/contents/ui/QuickSettingsCenter.qml"
SOURCE_INSTALLER = REPO_ROOT / "setup/apply-meo-desktop.sh"
RESET_INSTALLER = REPO_ROOT / "setup/reset-meo-desktop.sh"
SYSTEM_CMAKE = REPO_ROOT / "native/system/CMakeLists.txt"
SYSTEM_MONITOR_DESKTOP = REPO_ROOT / "data/applications/org.meo.systemmonitor.desktop"


class MeoWidgetExplorerTests(unittest.TestCase):
    def test_first_party_packages_are_desktop_only_and_packaged(self):
        package_source = PACKAGE.read_text(encoding="utf-8")
        for package_id in (
            "org.meo.widgetexplorer",
            "org.meo.widget.clock",
            "org.meo.widget.media",
            "org.meo.widget.performance",
        ):
            metadata = json.loads((APPLETS / package_id / "metadata.json").read_text(encoding="utf-8"))
            self.assertEqual(metadata["KPlugin"]["Id"], package_id)
            self.assertEqual(metadata["KPlugin"]["FormFactors"], ["desktop"])
            self.assertIn(f"plasmoids/{package_id}", package_source)

    def test_explorer_uses_two_real_hosts_without_panel_or_dock_management(self):
        explorer = (APPLETS / "org.meo.widgetexplorer/contents/ui/main.qml").read_text(encoding="utf-8")
        bridge = BRIDGE.read_text(encoding="utf-8")
        header = BRIDGE_HEADER.read_text(encoding="utf-8")

        self.assertIn("DesktopWidgets.catalog", explorer)
        self.assertIn("MeoWidgetSheet", explorer)
        self.assertIn("DesktopWidgets.addMeoWidget(Plasmoid.containment", explorer)
        self.assertIn("DesktopWidgets.addPlasmaWidget(Plasmoid.containment", explorer)
        self.assertIn("MeoContextMenu", explorer)
        self.assertNotIn("filteredMeoCatalog", explorer)
        self.assertNotIn("filteredPlasmaCatalog", explorer)
        self.assertIn("containment->createApplet", bridge)
        self.assertIn("QStandardPaths::standardLocations", bridge)
        self.assertIn("KPackageStructure", bridge)
        self.assertIn("X-Plasma-ContainmentType", bridge)
        self.assertIn("addPlasmaWidget", header)
        self.assertNotIn("addPanel", explorer)
        self.assertNotIn("org.kde.plasma.icontasks", explorer)
        self.assertNotIn("org.meo.dock", explorer)

    def test_meo_widget_contract_uses_dynamic_meoui_tokens(self):
        source = MEO_WIDGET.read_text(encoding="utf-8")
        self.assertIn("enum Size", source)
        self.assertIn("enum Privacy", source)
        self.assertIn("enum RefreshPolicy", source)
        self.assertIn("enum HostSurface", source)
        self.assertIn("enum FrameMode", source)
        self.assertIn("MeoTheme.surfaceContainerLow", source)
        self.assertIn("MeoTheme.cardRadius", source)
        self.assertIn("MeoTheme.space16", source)
        self.assertIn("MeoTheme.motionDurationState", source)
        self.assertNotIn("#", source)

    def test_only_reviewed_meo_adapters_can_cross_to_lockscreen(self):
        bridge = BRIDGE.read_text(encoding="utf-8")
        clock = (APPLETS / "org.meo.widget.clock/contents/ui/main.qml").read_text(encoding="utf-8")
        media = (APPLETS / "org.meo.widget.media/contents/ui/main.qml").read_text(encoding="utf-8")
        performance = (APPLETS / "org.meo.widget.performance/contents/ui/main.qml").read_text(encoding="utf-8")

        self.assertIn('"clock", "org.meo.widget.clock"', bridge)
        self.assertIn('"previewKind"', bridge)
        self.assertIn('"MeoAmbientClock"', bridge)
        self.assertIn('"media", "org.meo.widget.media"', bridge)
        self.assertIn('"MeoMediaController"', bridge)
        self.assertIn('"performance", "org.meo.widget.performance"', bridge)
        self.assertIn('"lockScreenEligible"), false', bridge)
        self.assertIn("MeoWidget.LockScreen", clock)
        self.assertIn("MeoWidget.LockScreen", media)
        self.assertIn("supportedSurfaces: [MeoWidget.Desktop]", performance)
        self.assertNotIn("MeoWidget.LockScreen", performance)
        self.assertIn('existingDesktops[i].addWidget("org.meo.widgetexplorer")', LAYOUT.read_text(encoding="utf-8"))

    def test_performance_manager_is_shared_and_reachable(self):
        qmldir = (MEO_KDE_QML / "qmldir").read_text(encoding="utf-8")
        manager = (MEO_KDE_QML / "PerformanceManager.qml").read_text(encoding="utf-8")
        performance_widget = (APPLETS / "org.meo.widget.performance/contents/ui/main.qml").read_text(encoding="utf-8")
        power_page = POWER_PAGE.read_text(encoding="utf-8")
        quick_settings = QUICK_SETTINGS.read_text(encoding="utf-8")
        installer = SOURCE_INSTALLER.read_text(encoding="utf-8")

        self.assertIn("PerformanceManager 1.0 PerformanceManager.qml", qmldir)
        self.assertIn("MetricCard 1.0 MetricCard.qml", qmldir)
        self.assertIn("PerformanceGraph 1.0 PerformanceGraph.qml", qmldir)
        self.assertIn("ProcessTable 1.0 ProcessTable.qml", qmldir)
        self.assertIn("PerformanceDashboard 1.0 PerformanceDashboard.qml", qmldir)
        self.assertIn("StartupAppsPage 1.0 StartupAppsPage.qml", qmldir)
        self.assertIn("ServicesPage 1.0 ServicesPage.qml", qmldir)
        self.assertIn("UsersPage 1.0 UsersPage.qml", qmldir)
        self.assertIn("ProcessDetailsPage 1.0 ProcessDetailsPage.qml", qmldir)
        self.assertIn("MeoSystem.Performance.subscribe", manager)
        self.assertIn("MeoSystem.Tasks.subscribe", manager)
        self.assertIn("MeoNavigationRail", manager)
        self.assertIn("Processes", manager)
        self.assertIn("PerformanceDashboard", manager)
        self.assertIn("StartupAppsPage", manager)
        self.assertIn("ServicesPage", manager)
        self.assertIn("UsersPage", manager)
        self.assertIn("ProcessDetailsPage", manager)
        self.assertIn("PerformanceManager {", performance_widget)
        self.assertFalse((APPLETS / "org.meo.widget.performance/contents/ui/PerformanceManager.qml").exists())
        self.assertIn("signal performanceRequested()", power_page)
        self.assertIn("System monitor", power_page)
        self.assertIn("performancePageComponent", quick_settings)
        self.assertIn("PerformanceManager { initialPage: 1; onCloseRequested: stack.pop() }", quick_settings)
        self.assertIn("initialPage: 1", performance_widget)
        process_table = (MEO_KDE_QML / "ProcessTable.qml").read_text(encoding="utf-8")
        self.assertIn("MeoDataTable", process_table)
        self.assertIn("Search processes", process_table)
        self.assertIn("MeoSystem.Tasks", process_table)
        self.assertIn("Process tree", process_table)
        self.assertIn("setProcessEfficiency", process_table)
        self.assertIn("terminateProcess", process_table)
        self.assertIn("Force stop", process_table)
        self.assertIn("Group apps", process_table)
        self.assertIn("processGroups", process_table)
        self.assertIn("networkRxBytesPerSecond", process_table)

        details_page = (MEO_KDE_QML / "ProcessDetailsPage.qml").read_text(encoding="utf-8")
        services_page = (MEO_KDE_QML / "ServicesPage.qml").read_text(encoding="utf-8")
        startup_page = (MEO_KDE_QML / "StartupAppsPage.qml").read_text(encoding="utf-8")
        performance_page = (MEO_KDE_QML / "PerformanceDashboard.qml").read_text(encoding="utf-8")
        self.assertIn("Search process details", details_page)
        self.assertIn("diskReadBytesPerSecond", details_page)
        self.assertIn("gpuAvailable", details_page)
        self.assertIn("Network shows real socket count only", details_page)
        self.assertIn("setProcessSuspended", details_page)
        self.assertIn("setProcessCpuAffinity", details_page)
        self.assertIn("terminateProcessTree", details_page)
        self.assertIn("copyProcessCommand", details_page)
        self.assertIn("openProcessLocation", details_page)
        self.assertIn("All scopes", services_page)
        self.assertIn("System services are shown read-only", services_page)
        self.assertIn("setStartupEnabled", startup_page)
        self.assertIn("cpuCores", performance_page)
        self.assertIn("gpu.history", performance_page)
        self.assertIn("wavy: true", performance_page)
        self.assertIn("Performance.disks", performance_page)
        self.assertIn("Performance.networkInterfaces", performance_page)
        self.assertIn("memoryAvailableBytes", performance_page)
        self.assertIn("powerWatts", performance_page)
        self.assertIn("coreClockMHz", performance_page)

        task_backend = (REPO_ROOT / "native/system/taskmanagercontroller.cpp").read_text(encoding="utf-8")
        system_plugin = (REPO_ROOT / "native/system/meosystemplugin.cpp").read_text(encoding="utf-8")
        self.assertIn('"Tasks", tasksProvider', system_plugin)
        self.assertIn("diskReadBytesPerSecond", task_backend)
        self.assertIn("refreshStartupApps", task_backend)
        self.assertIn("refreshServices", task_backend)
        self.assertIn("X-Meo-Override", task_backend)
        self.assertIn("OnlyShowIn", task_backend)
        self.assertIn('QStringLiteral("scope"), QStringLiteral("system")', task_backend)
        self.assertIn("drm-engine-", task_backend)
        self.assertIn("networkThroughputAvailable", task_backend)
        self.assertIn("terminateProcessTree", task_backend)
        self.assertIn("sched_setaffinity", task_backend)
        self.assertIn("m_processStaticInfo", task_backend)
        self.assertIn("cpuTimeSeconds", task_backend)
        self.assertIn("org.meo.widget.performance", installer)

    def test_system_monitor_has_one_shared_standalone_host(self):
        qmldir = (MEO_KDE_QML / "qmldir").read_text(encoding="utf-8")
        window = (MEO_KDE_QML / "SystemMonitorWindow.qml").read_text(encoding="utf-8")
        cmake = SYSTEM_CMAKE.read_text(encoding="utf-8")
        desktop = SYSTEM_MONITOR_DESKTOP.read_text(encoding="utf-8")
        installer = SOURCE_INSTALLER.read_text(encoding="utf-8")
        reset = RESET_INSTALLER.read_text(encoding="utf-8")

        self.assertIn("SystemMonitorWindow 1.0 SystemMonitorWindow.qml", qmldir)
        self.assertIn("PerformanceManager {", window)
        self.assertIn("initialPage: 0", window)
        self.assertIn("meo-system-monitor", cmake)
        self.assertIn("systemmonitor-main.cpp", cmake)
        self.assertIn("Exec=meo-system-monitor", desktop)
        self.assertIn("org.meo.systemmonitor.desktop", installer)
        self.assertIn("meo-system-monitor", installer)
        self.assertIn("org.meo.systemmonitor.desktop", reset)
        self.assertIn("meo-system-monitor", reset)

    def test_document_describes_native_plasma_api_and_honest_frame_boundary(self):
        document = PLATFORM_DOC.read_text(encoding="utf-8")
        self.assertIn("PlasmoidItem", document)
        self.assertIn("Plasma::Containment::createApplet()", document)
        self.assertIn("Meo Framed", document)
        self.assertIn("does not provide a partial fake", document)
        self.assertIn("Generic Plasma packages are desktop-only", document)

    def test_pinned_plasma_desktop_adapter_is_a_verified_thin_patch(self):
        package = (PLASMA_DESKTOP_PACKAGE / "PKGBUILD").read_text(encoding="utf-8")
        srcinfo = (PLASMA_DESKTOP_PACKAGE / ".SRCINFO").read_text(encoding="utf-8")
        patch = PLASMA_DESKTOP_PATCH.read_text(encoding="utf-8")
        patch_hash = hashlib.sha256(PLASMA_DESKTOP_PATCH.read_bytes()).hexdigest()

        self.assertIn("pkgname=meo-plasma-desktop", package)
        self.assertIn("pkgver=6.7.5", package)
        self.assertIn("provides=(\"plasma-desktop=${pkgver}\")", package)
        self.assertIn("conflicts=(plasma-desktop)", package)
        self.assertIn("meoui-qml>=1.0.4beta1", package)
        self.assertIn(patch_hash, package)
        self.assertIn(patch_hash, srcinfo)
        self.assertIn("MeoAppletContainer.qml", patch)
        self.assertIn("ContainmentLayoutManager.BasicAppletContainer", patch)
        self.assertIn("appletContainerComponent: MeoAppletContainer", patch)
        self.assertIn("meoWidgetFrameMode", patch)
        self.assertNotIn("createApplet(", patch)


if __name__ == "__main__":
    unittest.main()
