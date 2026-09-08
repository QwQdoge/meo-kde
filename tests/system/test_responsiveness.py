import json
import pathlib
import re
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]


class ResponsivenessContractTests(unittest.TestCase):
    def test_default_package_stack_is_bounded_and_has_no_ananicy_daemon(self):
        recipe = (ROOT / "packaging/arch/PKGBUILD").read_text(encoding="utf-8")
        for package in (
            "system76-scheduler", "zram-generator", "dbus-broker-units",
            "power-profiles-daemon", "gamemode",
        ):
            self.assertIn(f"'{package}'", recipe)
        self.assertIn("'meoui-qml>=1.0.3'", recipe)
        self.assertNotIn("'ananicy-cpp'", recipe)
        self.assertIn("disable ananicy-cpp.service", (
            ROOT / "defaults/systemd/50-meo-responsiveness.preset"
        ).read_text(encoding="utf-8"))

    def test_generated_cachyos_rules_are_classification_only(self):
        generated = (ROOT / "defaults/responsiveness/cachyos-ananicy.kdl").read_text(
            encoding="utf-8"
        )
        match = re.search(r"Unique process names: (\d+)", generated)
        self.assertIsNotNone(match)
        self.assertGreater(int(match.group(1)), 15000)
        self.assertIn('"kwin_wayland"', generated)
        self.assertIn('"plasmashell"', generated)
        self.assertIn('"steam"', generated)
        self.assertNotIn("oom_score_adj", generated)
        self.assertNotIn("ananicy-cpp", generated)

    def test_converter_deduplicates_and_prefers_interactive_classification(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = pathlib.Path(temporary) / "rules"
            source.mkdir()
            (source / "sample.rules").write_text(
                "\n".join((
                    json.dumps({"name": "same", "type": "BG_CPUIO"}),
                    json.dumps({"name": "same", "type": "LowLatency_RT"}),
                    json.dumps({"name": "game", "type": "Game"}),
                    json.dumps({"name": "ignored", "type": "OOM_NO_KILL"}),
                )), encoding="utf-8"
            )
            output = pathlib.Path(temporary) / "out.kdl"
            subprocess.run([
                "python3", str(ROOT / "tools/system/compile-ananicy-rules.py"),
                "--source", str(source), "--output", str(output),
                "--revision", "test",
            ], check=True)
            text = output.read_text(encoding="utf-8")
            foreground = text.split("foreground {", 1)[1].split("}", 1)[0]
            batch = text.split("batch {", 1)[1].split("}", 1)[0]
            self.assertIn('"same"', foreground)
            self.assertNotIn('"same"', batch)
            self.assertIn('"game"', text)
            self.assertNotIn("ignored", text)

    def test_optional_profiles_stay_conservative(self):
        preload = (ROOT / "defaults/responsiveness/preload-ng-meo.toml").read_text()
        prelockd = (ROOT / "defaults/responsiveness/prelockd-meo.conf").read_text()
        gamemode = (ROOT / "defaults/responsiveness/gamemode.ini").read_text()
        self.assertIn("prefetch_concurrency = 1", preload)
        self.assertIn("fanotify = false", preload)
        self.assertIn("$MAX_TOTAL_SIZE_MIB=160", prelockd)
        self.assertIn("apply_gpu_optimisations=0", gamemode)
        self.assertNotIn("nv_powermizer_mode", gamemode)

    def test_shell_selects_expressive_motion_and_standalone_dock_is_opt_in(self):
        shell_theme = (ROOT / "qml/MeoKDE/MeoShellTheme.qml").read_text()
        native_cmake = (ROOT / "native/CMakeLists.txt").read_text()
        dock_cmake = (ROOT / "native/dock/CMakeLists.txt").read_text()
        self.assertIn("MeoTheme.isExpressive = true", shell_theme)
        self.assertIn("MeoTheme.isBouncy = !MeoTheme.reduceMotion", shell_theme)
        self.assertIn('MEO_BUILD_STANDALONE_DOCK "Build the retired experimental Layer Shell Dock" OFF', native_cmake)
        self.assertIn("if(MEO_BUILD_STANDALONE_DOCK)", native_cmake)
        self.assertIn("qt_add_qml_module(meo-dock", dock_cmake)
        self.assertNotIn("qt_add_resources(meo-dock", dock_cmake)


if __name__ == "__main__":
    unittest.main()
