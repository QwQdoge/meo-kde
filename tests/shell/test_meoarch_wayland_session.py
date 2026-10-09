from pathlib import Path
import unittest
import os
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
SESSION = ROOT / "defaults/sessions/meoarch-wayland.desktop"
PKGBUILD = ROOT / "packaging/arch/PKGBUILD"


class MeoArchWaylandSessionTests(unittest.TestCase):
    def test_session_is_a_named_plasma_wayland_entry(self):
        content = SESSION.read_text(encoding="utf-8")
        self.assertIn("Name=Meo Desktop", content)
        self.assertIn("Exec=/usr/bin/start-meo-desktop", content)
        self.assertIn("TryExec=/usr/bin/start-meo-desktop", content)
        self.assertNotIn("DesktopNames=", content)

    def test_profile_is_seeded_without_overwriting_upstream_or_user_preferences(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            upstream = base / "config"
            upstream.mkdir()
            (upstream / "kdeglobals").write_text("upstream preferences")
            defaults = base / "defaults"
            defaults.mkdir()
            (defaults / "kdeglobals").write_text("Meo defaults")
            (defaults / "meo-shellrc").write_text("native shelf")
            env = dict(os.environ, XDG_CONFIG_HOME=str(upstream), MEO_SESSION_DEFAULTS=str(defaults), XDG_DATA_HOME=str(base / "data"), XDG_CACHE_HOME=str(base / "cache"), XDG_STATE_HOME=str(base / "state"))
            env.pop("MEO_SESSION_CONFIG_HOME", None)
            command = [str(ROOT / "tools/session/start-meo-desktop"), "--prepare-only"]
            subprocess.run(command, env=env, check=True)
            profile = upstream / "meo-desktop"
            self.assertEqual((profile / "kdeglobals").read_text(), "Meo defaults")
            self.assertEqual((upstream / "kdeglobals").read_text(), "upstream preferences")
            (profile / "kdeglobals").write_text("custom Meo preferences")
            subprocess.run(command, env=env, check=True)
            self.assertEqual((profile / "kdeglobals").read_text(), "custom Meo preferences")

    def test_incomplete_explicit_runtime_cannot_fall_back_to_another_desktop(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            env = dict(os.environ, MEO_SESSION_RUNTIME=str(base / "missing"),
                       MEO_SESSION_BASE_CONFIG=str(base / "config"), MEO_SESSION_BASE_DATA=str(base / "data"),
                       MEO_SESSION_BASE_CACHE=str(base / "cache"), MEO_SESSION_BASE_STATE=str(base / "state"))
            result = subprocess.run([str(ROOT / "tools/session/start-meo-desktop")], env=env,
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn("runtime is incomplete", result.stderr)
            self.assertIn(str(base / "missing"), result.stderr)

    def test_dbus_service_activation_does_not_nest_the_session_profile(self):
        import json
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            runtime = base / "runtime"
            (runtime / "share").mkdir(parents=True)
            (runtime / "bin").mkdir()
            router = runtime / "bin/meo-ai-router"
            router.write_text("#!/usr/bin/env python3\nimport os,json\nprint(json.dumps({key:os.environ[key] for key in ('XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME')}))\n")
            router.chmod(0o755)
            env = dict(os.environ, MEO_SESSION_RUNTIME=str(runtime),
                       MEO_SESSION_BASE_CONFIG=str(base / "config"),
                       MEO_SESSION_BASE_DATA=str(base / "data"),
                       MEO_SESSION_BASE_CACHE=str(base / "cache"),
                       XDG_CONFIG_HOME=str(base / "config/meo-desktop"),
                       XDG_DATA_HOME=str(base / "data/meo-desktop/data"),
                       XDG_CACHE_HOME=str(base / "cache/meo-desktop"), MEO_DESKTOP_SESSION="1")
            result = subprocess.run([str(ROOT / "tools/session/start-meo-desktop"), "--service", "meo-ai-router"],
                                    env=env, check=True, capture_output=True, text=True)
            values = json.loads(result.stdout)
            self.assertEqual(values["XDG_CONFIG_HOME"], str(base / "config/meo-desktop"))
            self.assertEqual(values["XDG_DATA_HOME"], str(base / "data/meo-desktop/data"))
            self.assertEqual(values["XDG_CACHE_HOME"], str(base / "cache/meo-desktop"))

    def test_background_units_belong_only_to_the_meo_graphical_session(self):
        import json
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            (base / "bin").mkdir()
            (base / "bin/systemd-run").write_text(
                "#!/usr/bin/env python3\nimport os,sys,json\nwith open(os.environ['TEST_CALLS'],'a') as f: f.write(json.dumps(sys.argv[1:])+'\\n')\n")
            (base / "bin/meo-session-colors").write_text("#!/bin/sh\nexit 0\n")
            for command in (base / "bin").iterdir():
                command.chmod(0o755)
            env = dict(os.environ, PATH=f"{base}/bin:{os.environ['PATH']}", TEST_CALLS=str(base / "calls"),
                       MEO_DESKTOP_SESSION="0", MEO_SESSION_RUNTIME=str(base), XDG_CONFIG_HOME=str(base / "config"))
            command = [str(ROOT / "tools/session/start-meo-session-services")]
            subprocess.run(command, env=env, check=True)
            self.assertFalse((base / "calls").exists())
            env["MEO_DESKTOP_SESSION"] = "1"
            subprocess.run(command, env=env, check=True)
            calls = [json.loads(line) for line in (base / "calls").read_text().splitlines()]
            self.assertEqual(len(calls), 2)
            self.assertTrue(all("--property=PartOf=graphical-session.target" in call for call in calls))
            self.assertIn(f"--path-property=PathChanged={base}/config/kdeglobals", calls[0])
            self.assertIn("--on-unit-active=30m", calls[1])

    def test_package_payload_and_source_installer_register_the_same_session(self):
        self.assertIn('tools/session/package-meo-desktop', PKGBUILD.read_text())
        self.assertIn('tools/session/install-meo-session', (ROOT / 'tools/session/package-meo-desktop').read_text())
        self.assertIn('tools/session/install-meo-session', (ROOT / "install.sh").read_text())
        with tempfile.TemporaryDirectory() as temp:
            subprocess.run([str(ROOT / "tools/session/install-meo-session"), str(ROOT), temp], check=True)
            target = Path(temp)
            self.assertTrue(os.access(target / "usr/bin/start-meo-desktop", os.X_OK))
            self.assertEqual((target / "usr/share/wayland-sessions/meoarch-wayland.desktop").read_text(), SESSION.read_text())
            self.assertTrue((target / "usr/share/meo-desktop/runtime/session-defaults/meo-shellrc").is_file())


if __name__ == "__main__":
    unittest.main()
