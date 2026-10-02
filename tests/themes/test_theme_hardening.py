"""Edge regressions for user themes, executed against the unchanged Suite engine.

These are desktop LCD checks, not hardware font or instruction-budget acceptance.
"""
import unittest

from render_themes import PHASES, THEMES
from test_theme_contract import boxes, render


def repaint(radio, state, widget, theme, phase):
    definition = radio.load(f"widgets/dashboard/themes/{theme}/init.lua")
    for _ in range(8):
        radio.lua.globals().TEST_TIME += 0.25
        radio.engine.wakeup(widget, state, radio.width, radio.height)
        radio.texts.clear()
        radio.engine.paint(widget, definition, state, phase, radio.width, radio.height)
    if radio.errors:
        raise AssertionError("\n".join(dict.fromkeys(radio.errors)))


class ThemeHardeningTests(unittest.TestCase):
    def test_preflight_flight_count_distinguishes_missing_history_from_zero(self):
        radio, state, widget = render("mwrc", "preflight", scenario="offline",
                                     prepare=lambda r, w: setattr(w, "modelStats", None))
        card = next(box for box in boxes(state) if box.summaryKind == "count")
        self.assertEqual(card._cache.text, "--", "offline absence was presented as zero flights")
        widget.connected = True
        widget.modelStats = radio.table({"flightcount": 0, "totalflighttime": 0, "lastflighttime": 0})
        repaint(radio, state, widget, "mwrc", "preflight")
        self.assertEqual(card._cache.text, "0", "valid connected zero became missing")
        widget.modelStats.flightcount = 42
        repaint(radio, state, widget, "mwrc", "preflight")
        self.assertEqual(card._cache.text, "42")
        widget.connected = False
        repaint(radio, state, widget, "mwrc", "preflight")
        self.assertEqual(card._cache.text, "--", "offline preflight retained an available count")

    def test_flight_summaries_keep_normal_sources_units_and_disconnect_history(self):
        def normal_history(radio, widget):
            widget.modelStats.lastflighttime = 97  # Live184 must win while connected.

        def summaries(state):
            return {box.summaryKind: box._cache.text for box in boxes(state) if box.summaryKind}

        for theme in ("mwrc", "libertyops250"):
            with self.subTest(theme=theme):
                radio, state, widget = render(theme, "postflight", prepare=normal_history)
                self.assertEqual(summaries(state), {"flight": "03:04", "total": "02:37:40", "count": "42"})
                radio.lua.execute('''
                    local original = lcd.getTextSize
                    SUMMARY_MEASUREMENTS = 0
                    lcd.getTextSize = function(text)
                        SUMMARY_MEASUREMENTS = SUMMARY_MEASUREMENTS + 1
                        return original(text)
                    end
                ''')
                summary_boxes = [box for box in boxes(state) if box.summaryKind]
                for box in summary_boxes:
                    box.paint(0, 0, 250, 100, box, box._cache)
                radio.lua.globals().SUMMARY_MEASUREMENTS = 0
                for box in summary_boxes:
                    for _ in range(3):
                        box.paint(0, 0, 250, 100, box, box._cache)
                self.assertEqual(radio.lua.globals().SUMMARY_MEASUREMENTS, 0,
                                 "unchanged summaries remeasure text in every paint")
                widget.connected, widget.timerLive = False, 0
                repaint(radio, state, widget, theme, "postflight")
                self.assertEqual(summaries(state)["flight"], "03:04",
                                 "older saved flight replaced the last known current duration")
                widget.connected, widget.timerLive, widget.modelStats = False, 0, None
                repaint(radio, state, widget, theme, "postflight")
                self.assertEqual(summaries(state), {"flight": "03:04", "total": "02:37:40", "count": "42"},
                                 "postflight lost known summary when live session cleared")
                widget.connected, widget.timerLive = True, 61
                widget.modelStats = radio.table({"lastflighttime": 61, "totalflighttime": 9521, "flightcount": 43})
                repaint(radio, state, widget, theme, "postflight")
                self.assertEqual(summaries(state), {"flight": "01:01", "total": "02:38:41", "count": "43"})

                def zero_history(radio, widget):
                    widget.timerLive = 0
                    widget.modelStats = radio.table({"lastflighttime": 0, "totalflighttime": 0, "flightcount": 0})
                _, zero_state, _ = render(theme, "postflight", prepare=zero_history)
                self.assertEqual(summaries(zero_state), {"flight": "00:00", "total": "00:00:00", "count": "0"})

                def recorded_history(radio, widget):
                    widget.connected, widget.timerLive = False, 0
                    widget.modelStats.lastflighttime = 97
                _, recorded_state, _ = render(theme, "postflight", prepare=recorded_history)
                self.assertEqual(summaries(recorded_state), {"flight": "01:37", "total": "02:37:40", "count": "42"})

    def test_stale_source_is_hidden_and_valid_zero_survives_recovery(self):
        def source_fixture(radio, widget):
            widget.tempEsc = None
            radio.lua.execute('''
                TEMPERATURE_LIVE, TEMPERATURE_VALUE = true, 47
                local nativeSource = system.getSource
                local temperatureSource = {
                    state = function() return TEMPERATURE_LIVE end,
                    value = function() return TEMPERATURE_VALUE end,
                    unit = function() return 0 end,
                }
                system.getSource = function(spec)
                    if type(spec) == "table" and spec.appId == 0x0401 then return temperatureSource end
                    return nativeSource(spec)
                end
            ''')

        for theme in THEMES:
            for phase in ("preflight", "inflight"):
                with self.subTest(theme=theme, phase=phase):
                    radio, state, widget = render(theme, phase, prepare=source_fixture)
                    self.assertRegex(" ".join(t[2] for t in radio.texts), r"(?<!\d)47\s*°C")
                    radio.lua.globals().TEMPERATURE_LIVE = False
                    repaint(radio, state, widget, theme, phase)
                    self.assertNotRegex(" ".join(t[2] for t in radio.texts), r"(?<!\d)47\s*°C")
                    radio.lua.globals().TEMPERATURE_LIVE = True
                    radio.lua.globals().TEMPERATURE_VALUE = 0
                    repaint(radio, state, widget, theme, phase)
                    text = " ".join(t[2] for t in radio.texts)
                    self.assertRegex(text, r"(?<!\d)0(?:\.0+)?\s*°C", "valid zero temperature became missing")

    def test_long_model_names_stay_in_the_native_model_slot(self):
        for theme in THEMES:
            for phase in PHASES:
                for width, height, name in ((800, 480, "W" * 32),
                                             (480, 320, "Échelle測試" * 8)):
                    with self.subTest(theme=theme, phase=phase, width=width):
                        radio, state, widget = render(theme, phase, width=width, height=height,
                            prepare=lambda r, w: setattr(w, "craftName", name))
                        model_text = [t for t in radio.texts if t[1] < 44 and t[2].startswith(name[:2])]
                        self.assertTrue(model_text, "dynamic model name disappeared")
                        for x, y, text, font, text_width in model_text:
                            self.assertGreaterEqual(x, 0)
                            self.assertGreaterEqual(y, 0, "model name escaped above header")
                            self.assertLessEqual(x + text_width, (width // 7) * 2,
                                                 "model name overlaps branding")
                            self.assertLessEqual(y + font, 44)
                        self.assertTrue(any(t[2] == "Rotorflight // Ethos" for t in radio.texts))
                        widget.craftName = "New Model"
                        repaint(radio, state, widget, theme, phase)
                        self.assertTrue(any(t[2] == "New Model" for t in radio.texts),
                                        "cached model name did not update")

    def test_unrepresentable_timer_and_telemetry_do_not_break_paint(self):
        def corrupt(radio, widget):
            for key in ("voltage", "current", "consumption", "rpm", "fuelPercent",
                        "becVoltage", "tempEsc", "tempMcu", "linkQuality",
                        "throttlePercent", "timerLive"):
                widget[key] = 1e100

        for theme in THEMES:
            for phase in PHASES:
                with self.subTest(theme=theme, phase=phase):
                    radio, _, _ = render(theme, phase, prepare=corrupt)
                    text = " ".join(t[2] for t in radio.texts)
                    self.assertNotRegex(text, r"\d{10,}", "unbounded corrupt telemetry rendered")
                    self.assertNotRegex(text.lower(), r"(?<![a-z])(nan|[+-]?inf)(?![a-z])")
                    self.assertTrue(any("--" in t[2] for t in radio.texts),
                                    "invalid telemetry needs an unavailable indication")

    def test_connection_loss_clears_live_values_and_reconnection_refreshes(self):
        for theme in THEMES:
            for phase in ("preflight", "inflight"):
                with self.subTest(theme=theme, phase=phase):
                    radio, state, widget = render(theme, phase)
                    self.assertRegex(" ".join(t[2] for t in radio.texts), r"(?<!\d)62\s*°C")
                    widget.connected = False
                    repaint(radio, state, widget, theme, phase)
                    self.assertNotRegex(" ".join(t[2] for t in radio.texts), r"(?<!\d)62\s*°C",
                                     "retained telemetry appeared live after loss")
                    widget.connected, widget.tempEsc = True, 63
                    repaint(radio, state, widget, theme, phase)
                    self.assertRegex(" ".join(t[2] for t in radio.texts), r"(?<!\d)63\s*°C",
                                    "new telemetry was not shown on reconnect")

    def test_corrupt_historical_numbers_are_unavailable(self):
        def corrupt(radio, widget):
            widget.connected = False
            widget.timerLive = 1e100
            for _, entry in widget.dashboardStats.items():
                for key in ("min", "max", "avg", "sum"):
                    entry[key] = 1e100
            widget.modelStats.lastflighttime = 1e100
            widget.modelStats.totalflighttime = 1e100

        for theme in THEMES:
            with self.subTest(theme=theme):
                radio, _, _ = render(theme, "postflight", prepare=corrupt)
                text = " ".join(t[2] for t in radio.texts)
                self.assertNotRegex(text, r"\d{10,}")
                self.assertNotRegex(text.lower(), r"(?<![a-z])(nan|[+-]?inf)(?![a-z])")
                self.assertIn("--", text)


if __name__ == "__main__":
    unittest.main()
