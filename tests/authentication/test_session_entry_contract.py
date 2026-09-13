"""Versioned security/presentation contract for Meo session entry."""

import json
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
SCHEMA = REPO_ROOT / "docs/schemas/meo-session-entry-v1.schema.json"
CONTRACT = REPO_ROOT / "docs/SESSION_ENTRY_CONTRACT.md"


class SessionEntryContractTests(unittest.TestCase):
    def setUp(self):
        self.schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
        self.contract = " ".join(CONTRACT.read_text(encoding="utf-8").split())

    def test_schema_is_strict_and_versioned(self):
        self.assertEqual(self.schema["$id"], "https://meoarch.org/schemas/session-entry/v1")
        self.assertFalse(self.schema["additionalProperties"])
        self.assertEqual(self.schema["properties"]["schemaVersion"], {"const": 1})
        self.assertEqual(
            self.schema["properties"]["scope"]["enum"],
            ["lockscreen", "login"],
        )
        self.assertEqual(
            set(self.schema["required"]),
            {"schemaVersion", "scope", "appearance", "modules", "privacy", "layout", "motion"},
        )

    def test_schema_keeps_privacy_and_output_boundaries(self):
        definitions = self.schema["$defs"]
        self.assertEqual(
            definitions["privacy"]["properties"]["notificationVisibility"]["enum"],
            ["hidden", "count", "app-name", "full-content"],
        )
        self.assertEqual(
            definitions["layout"]["properties"]["activeAuthenticationScreen"]["enum"],
            ["auto", "fixed-primary", "follow-interaction"],
        )
        self.assertEqual(definitions["layout"]["properties"]["displayOverrides"]["maxItems"], 16)
        self.assertIn("Opaque stable KScreen output identity", definitions["displayOverride"]["properties"]["outputKey"]["description"])

    def test_login_scope_cannot_disclose_session_private_content(self):
        login_rules = self.schema["allOf"][0]["then"]["properties"]
        self.assertFalse(login_rules["modules"]["properties"]["media"]["const"])
        self.assertEqual(login_rules["privacy"]["properties"]["notificationVisibility"]["const"], "hidden")
        self.assertFalse(login_rules["privacy"]["properties"]["showAlbumArtwork"]["const"])
        self.assertEqual(
            login_rules["appearance"]["properties"]["wallpaper"]["properties"]["source"]["enum"],
            ["system-default", "managed-asset"],
        )

    def test_contract_preserves_the_security_core_and_motion_requirements(self):
        for required in (
            "`kscreenlocker` remains",
            "must not make a second credential model",
            "KScreenLocker falls back",
            "48 dp",
            "250 ms fade-through",
            "MeoTheme",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.contract)

    def test_contract_requires_explicit_authentication_and_a_safe_widget_boundary(self):
        for required in (
            "two presentation states",
            "intentional upward swipe",
            "72 dp travel threshold",
            "does not implement a second authentication path",
            "never opens a camera",
            "upstream session-management authority",
            "function-first",
            "shows no media, weather, notification, album-art",
            "not an actual unlocked KScreenLocker window",
            "does **not** load Plasma applets into the security surface",
            "MeoSecureWidgetRegistry",
            "8 dp grid",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.contract)


if __name__ == "__main__":
    unittest.main()
