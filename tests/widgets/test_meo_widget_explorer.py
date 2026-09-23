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
        self.assertIn("MeoSystem.Performance.subscribe", manager)
        self.assertIn("Processes", manager)
        self.assertIn("PerformanceDashboard", manager)
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
        self.assertIn("terminateProcess", process_table)
        self.assertIn("Force stop", process_table)
        self.assertIn("org.meo.widget.performance", installer)

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
