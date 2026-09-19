"""Contract checks for the user-scoped weather cache producer."""

from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
REFRESHER = (REPO_ROOT / "native/system/weatherrefresh.cpp").read_text(encoding="utf-8")
SERVICE = (REPO_ROOT / "defaults/systemd/meo-weather-refresh.service").read_text(encoding="utf-8")
TIMER = (REPO_ROOT / "defaults/systemd/meo-weather-refresh.timer").read_text(encoding="utf-8")
PKGBUILD = (REPO_ROOT / "packaging/arch/PKGBUILD").read_text(encoding="utf-8")


class WeatherRefresherContractTests(unittest.TestCase):
    def test_network_producer_is_separate_from_cache_only_locker_reader(self):
        for required in (
            "geocoding-api.open-meteo.com",
            "api.open-meteo.com",
            "kNetworkTimeoutMs = 10 * 1000",
            "kMaximumResponseBytes = 256 * 1024",
            "WeatherCache::cachePath()",
            "QSaveFile",
            "output.commit()",
            "Weather/city",
        ):
            with self.subTest(required=required):
                self.assertIn(required, REFRESHER)

    def test_user_service_is_periodic_and_keeps_private_cache_permissions(self):
        self.assertIn("ExecStart=/usr/bin/meo-weather-refresh", SERVICE)
        self.assertIn("UMask=0077", SERVICE)
        self.assertIn("OnUnitActiveSec=30m", TIMER)
        self.assertIn("RandomizedDelaySec=5m", TIMER)
        self.assertIn("meo-weather-refresh.timer", PKGBUILD)
        self.assertIn("default.target.wants", PKGBUILD)


if __name__ == "__main__":
    unittest.main()
