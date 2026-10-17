"""Packaged system labels use real locale data without losing add-on metadata."""
import json
from pathlib import Path
import unittest

from test_theme_discovery import DiscoveryRadio, PERSONAL, SOURCE
from i18n_fixture import resolve_source

class ThemeLocalizationTests(unittest.TestCase):
    def test_fixture_handles_packaged_multiline_messages_as_valid_lua_strings(self):
        key = "app.modules.mixer.enable_swash_override_message"
        catalog = json.loads((SOURCE / "i18n/en.json").read_text(encoding="utf-8"))
        original = catalog["app"]["modules"]["mixer"]["enable_swash_override_message"]["translation"]
        compiled = resolve_source('return "@i18n(' + key + ')@"', SOURCE)
        result = DiscoveryRadio().run(compiled)
        self.assertEqual(result, original.replace("\r\n", "\n").replace("\r", "\n"))

    def test_all_theme_names_exist_in_every_source_and_generated_locale(self):
        repo = SOURCE.parents[1]
        sources = sorted((repo / "bin/i18n/json").glob("*.json"))
        self.assertEqual(len(sources), 12)
        for source in sources:
            data = json.loads(source.read_text(encoding="utf-8"))
            generated = json.loads((SOURCE / "i18n" / source.name).read_text(encoding="utf-8"))
            self.assertEqual(data, generated, f"Regenerate locale: {source.name}")
            entries = data["app"]["modules"]["settings"]
            for folder, name in PERSONAL.values():
                with self.subTest(locale=source.stem, theme=folder):
                    entry = entries["dashboard_theme_" + folder]
                    self.assertEqual(entry["english"], name)
                    self.assertTrue(entry["translation"])
                    self.assertFalse(entry["needs_translation"])

    def test_localized_names_preserve_discovery_metadata_and_saved_identity(self):
        radio = DiscoveryRadio()
        entries = radio.descriptors()
        for saved, (folder, name) in PERSONAL.items():
            with self.subTest(theme=folder):
                entry = entries["system/" + saved]
                self.assertEqual(entry.label, name)
                self.assertFalse(entry.builtin, "Localization bypassed the add-on init file")
                self.assertEqual(entry.directory, "widgets/dashboard/themes/" + folder)
                self.assertEqual((entry.minResolution.x, entry.minResolution.y), (784, 294))
                self.assertIsNotNone(entry.appTheme, "Localization discarded the active palette")
                self.assertEqual(entry.appTheme.name, name)
        self.assertIsNone(radio.g.phaseRuns, "Catalog executed a phase while resolving labels")

if __name__ == "__main__":
    unittest.main()
