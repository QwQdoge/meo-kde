"""Versioned security/presentation contract for Meo session entry.

These tests intentionally validate durable security and data-boundary semantics.
They do not pin one historical locker implementation, animation duration, or
layout constant as architecture.
"""

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
        self.contract_lower = self.contract.lower()

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
        privacy = definitions["privacy"]["properties"]
        output = definitions["displayOverride"]["properties"]["outputKey"]

        self.assertEqual(
            privacy["notificationVisibility"]["enum"],
            ["hidden", "count", "app-name", "full-content"],
        )
        self.assertEqual(privacy["notificationVisibility"]["default"], "count")
        self.assertFalse(privacy["showAlbumArtwork"]["default"])
        self.assertEqual(
            definitions["layout"]["properties"]["activeAuthenticationScreen"]["enum"],
            ["auto", "fixed-primary", "follow-interaction"],
        )
        self.assertEqual(definitions["layout"]["properties"]["displayOverrides"]["maxItems"], 16)
        self.assertIn("Opaque stable output identity", output["description"])
        self.assertIn("never a raw EDID or coordinate", output["description"])
        self.assertEqual(definitions["appearance"]["properties"]["wallpaperMode"]["default"], "follow-desktop")
        self.assertTrue(definitions["modules"]["properties"]["audio"]["default"])
        self.assertEqual(definitions["modules"]["properties"]["weatherCity"]["maxLength"], 96)

    def test_wallpaper_asset_rule_distinguishes_default_from_symbolic_assets(self):
        wallpaper = self.schema["$defs"]["wallpaper"]
        self.assertEqual(wallpaper["properties"]["assetId"]["maxLength"], 256)

        conditional = wallpaper["allOf"][0]
        self.assertEqual(
            conditional["if"]["properties"]["source"],
            {"const": "system-default"},
        )
        self.assertEqual(
            conditional["then"]["properties"]["assetId"],
            {"const": ""},
        )
        non_default = conditional["else"]["properties"]["assetId"]
        self.assertEqual(non_default["minLength"], 1)
        self.assertTrue(non_default["pattern"].startswith("^[A-Za-z0-9]"))

    def test_login_scope_cannot_disclose_session_private_content(self):
        login_rules = self.schema["allOf"][0]["then"]["properties"]
        self.assertFalse(login_rules["modules"]["properties"]["media"]["const"])
        self.assertFalse(login_rules["modules"]["properties"]["weather"]["const"])
        self.assertFalse(login_rules["modules"]["properties"]["audio"]["const"])
        self.assertEqual(login_rules["modules"]["properties"]["weatherCity"]["const"], "")
        self.assertEqual(login_rules["appearance"]["properties"]["wallpaperMode"]["const"], "managed")
        self.assertEqual(login_rules["privacy"]["properties"]["notificationVisibility"]["const"], "hidden")
        self.assertFalse(login_rules["privacy"]["properties"]["showAlbumArtwork"]["const"])
        self.assertEqual(login_rules["privacy"]["properties"]["weatherLocation"]["const"], "hidden")
        self.assertEqual(
            login_rules["appearance"]["properties"]["wallpaper"]["properties"]["source"]["enum"],
            ["system-default", "managed-asset"],
        )

    def test_contract_has_one_authoritative_lock_path_and_separate_login_boundary(self):
        for required in (
            "authoritative normal lock path",
            "`meo-lockscreen`",
            "wayland session lock",
            "pam-backed authentication",
            "not a second normal lock owner",
            "not make those two security boundaries interchangeable",
            "same lifecycle",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.contract_lower)

    def test_contract_keeps_credentials_and_authentication_out_of_presentation_state(self):
        for required in (
            "no presentation surface stores a password",
            "compares credentials in qml",
            "authentication success comes from the backend",
            "persist plaintext credentials",
            "password fallback remains available",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.contract_lower)

    def test_contract_keeps_external_content_optional_and_privacy_bounded(self):
        for required in (
            "never gate authentication",
            "no notifications, media, album artwork",
            "per-user cache",
            "no weather provider in schema v1",
            "read-only and bounded",
            "must not expose arbitrary application actions",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.contract_lower)

    def test_contract_requires_secure_display_coverage(self):
        for required in (
            "every usable output must remain covered",
            "hotplug",
            "suspend/resume",
            "dpms",
            "must not write the live kscreen topology",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.contract_lower)

    def test_editor_is_a_data_preview_not_a_second_security_surface(self):
        for required in (
            "simulated surface",
            "never authenticates",
            "acquires a real session lock",
            "loads arbitrary third-party qml",
            "preview proves layout/configuration behavior only",
            "not security acceptance evidence",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.contract_lower)

    def test_contract_separates_user_and_privileged_writers(self):
        for required in (
            "per-user lock-screen scope",
            "atomically writes",
            "refuses blind rollback",
            "system login scope",
            "separate privileged transaction boundary",
            "must not edit pam policy",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.contract_lower)

    def test_release_gate_requires_real_session_security_evidence(self):
        for required in (
            "manual lock",
            "idle-triggered lock",
            "correct and incorrect password behavior",
            "multiple monitors",
            "monitor hotplug/removal",
            "release blocker",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.contract_lower)


if __name__ == "__main__":
    unittest.main()
