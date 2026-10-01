"""Cinder acceptance checks against the real Suite context and paint engine."""
import itertools
import math
import unittest
from unittest.mock import patch

import render_themes as renderer
import test_theme_contract as contract
import test_theme_hardening as hardening

THEME = "cinder"


def body(state):
    return next(box for box in contract.boxes(state) if box.paint and box.wakeup)


class CinderTests(unittest.TestCase):
    def test_all_phases_sizes_modes_and_states_fit(self):
        for phase, size, mode, scenario in itertools.product(
                renderer.PHASES, ((800, 480), (784, 294)),
                ((True, False), (True, True), (False, True)),
                ("connected", "offline", "missing", "warnings")):
            with self.subTest(phase=phase, size=size, mode=mode, scenario=scenario):
                radio = renderer.Radio(*size, dark=mode[0], themed=mode[1])
                radio.draw = contract.NullDrawing()
                radio.render(THEME, phase, scenario)
                for x, y, text, font, width in radio.texts:
                    self.assertGreaterEqual(x, -1, text)
                    self.assertGreaterEqual(y, -1, text)
                    self.assertLessEqual(x + width, size[0] + 2, text)
                    self.assertLessEqual(y + font, size[1] + 2, text)
                titles = [t for t in radio.texts if t[2] == "Rotorflight // Ethos"]
                if size == (800, 480):
                    title = titles[0]
                    mark = next(t for t in radio.texts if t[2] == "| MWRC")
                    self.assertLess(mark[3], title[3])
                    self.assertEqual(mark[3], renderer.SIZES["FONT_XS"])
                    self.assertLessEqual(abs((title[0] + mark[0] + mark[4]) / 2 - 400), 1)
                    self.assertLess(title[1], 44)
                    self.assertTrue(any(t[2] == "ROTORFLIGHT 700" for t in radio.texts))
                    self.assertTrue(all(t[1] >= 44 for t in radio.texts if t[2] == "CINDER"))
                else:
                    self.assertFalse(titles, "compact layout duplicated native header")

    def test_live_headspeed_has_no_limit_comparison_or_setting(self):
        radio, state, widget = contract.render(THEME, "inflight")
        cache = body(state)._cache
        self.assertEqual(cache.rpmText, "2150")
        self.assertEqual(cache.currentText, "52.4 A")
        self.assertEqual(cache.timer, "03:04")
        for t in radio.texts:
            self.assertNotRegex(t[2].upper(), r"REDLINE|RPM LIMIT|MAX|LIMIT")
        radio.context.widgets.dashboard.savePreference("rpm_max", 100)
        hardening.repaint(radio, state, widget, THEME, "inflight")
        self.assertEqual(cache.rpmText, "2150")
        self.assertIsNone(cache.rpmMax)
        _, _, fields = contract.configure(THEME)
        self.assertFalse(any("headspeed" in f.label.lower() or f.unit == "rpm" for f in fields))

    def test_missing_checks_and_live_threshold_changes(self):
        prefs = dict(contract.PREFERENCES, bec_warn=7.0)
        radio, state, widget = contract.render(THEME, "preflight", preferences=prefs)
        self.assertEqual(body(state)._cache.status, "CHECKS COMPLETE")
        radio.context.widgets.dashboard.savePreference("bec_warn", 8)
        hardening.repaint(radio, state, widget, THEME, "preflight")
        self.assertEqual(body(state)._cache.status, "REVIEW WARNINGS")
        for key in ("fuelPercent", "becVoltage", "tempEsc", "voltage", "linkQuality"):
            def missing(radio, widget):
                widget[key] = None
                if key == "linkQuality":
                    radio.lua.execute('''
                        local previous = system.getSource
                        system.getSource = function(spec)
                            if type(spec)=="table" and spec.appId==0xF010 then return nil end
                            return previous(spec)
                        end
                    ''')
            radio, state, _ = contract.render(THEME, "preflight", preferences=prefs, prepare=missing)
            self.assertEqual(body(state)._cache.status, "INCOMPLETE", key)

    def test_zero_and_historical_cell_and_link_are_not_fabricated(self):
        def history(radio, widget):
            widget.connected = False
            widget.batteryConfig = None
            widget.dashboardStats.cell_voltage = radio.table({"min":3.68})
            widget.dashboardStats.vfr = radio.table({"min":87})
            widget.dashboardStats.rssi = None
            widget.dashboardStats.minLink = 65
            widget.modelStats.lastflighttime = 97
            widget.timerLive = 0
        radio, state, _ = contract.render(THEME, "postflight", prepare=history)
        c = body(state)._cache
        self.assertEqual(c.cellText, "3.68 V")
        self.assertEqual(c.linkText, "87%")
        self.assertEqual(c.timer, "01:37")
        def zeros(radio, widget):
            for key in ("rpm", "tempEsc", "current", "fuelPercent", "consumption", "timerLive"):
                widget[key] = 0
        _, state, _ = contract.render(THEME, "inflight", prepare=zeros)
        c = body(state)._cache
        self.assertEqual(c.rpmText, "0")
        self.assertEqual(c.escText, "0°C")
        self.assertEqual(c.currentText, "0.0 A")
        self.assertEqual(c.timer, "00:00")

    def test_steady_paint_reuses_text_measurements_and_performs_no_loads(self):
        for phase in renderer.PHASES:
            radio, state, widget = contract.render(THEME, phase)
            box = body(state)
            radio.lua.execute('''
                local previous = lcd.getTextSize
                CINDER_MEASUREMENTS = 0
                lcd.getTextSize = function(text)
                    CINDER_MEASUREMENTS = CINDER_MEASUREMENTS + 1
                    return previous(text)
                end
            ''')
            loads = tuple(radio.loads)
            cache = box._cache
            for _ in range(8):
                box.wakeup(box, radio.context.tasks.telemetry)
                box.paint(box._dashboardRectX, box._dashboardRectY,
                          box._dashboardRectW, box._dashboardRectH, box, box._cache)
            self.assertTrue(radio.lua.eval("rawequal")(cache, box._cache))
            self.assertEqual(tuple(radio.loads), loads)
            self.assertEqual(radio.lua.globals().CINDER_MEASUREMENTS, 0)

    def test_postflight_retains_known_zero_duration_but_does_not_invent_history(self):
        def empty(radio, widget):
            widget.dashboardStats = radio.table({})
            widget.timerLive = 0
            widget.modelStats = None
        radio, state, widget = contract.render(THEME, "postflight", prepare=empty)
        self.assertEqual(body(state)._cache.timer, "00:00")
        widget.connected = False
        hardening.repaint(radio, state, widget, THEME, "postflight")
        self.assertEqual(body(state)._cache.timer, "00:00")
        _, cold, _ = contract.render(THEME, "postflight", scenario="offline", prepare=empty)
        self.assertEqual(body(cold)._cache.timer, "--:--")

    def test_corrupt_owned_preferences_are_bounded_and_other_preferences_unchanged(self):
        owned = ("bec_min", "bec_warn", "esc_warn", "esc_max", "fuel_warn", "link_warn")
        for bad in (float("nan"), float("inf"), -float("inf"), 1e100, -1e100):
            with self.subTest(bad=bad):
                prefs = {key: bad for key in owned}
                prefs["rpm_max"] = 3450
                prefs["unrelated"] = 17
                radio, config, fields = contract.configure(THEME, preferences=prefs)
                for field in fields:
                    value = field.getter()
                    self.assertTrue(math.isfinite(value))
                    self.assertGreaterEqual(value, field.minimum)
                    self.assertLessEqual(value, field.maximum)
                config.write()
                saved = dict(radio.context.widgets.dashboard.preferences().items())
                self.assertEqual(saved["rpm_max"], 3450)
                self.assertEqual(saved["unrelated"], 17)
                self.assertTrue(all(math.isfinite(saved[key]) for key in owned))


GENERIC = (
    (contract, contract.ThemeContractTests, (
        "test_temperature_units_and_values_match_in_every_phase",
        "test_offline_missing_and_nonfinite_samples_render_placeholders",
        "test_configure_fahrenheit_save_reopen_keeps_canonical_celsius_and_user_bec",
        "test_themes_do_not_modify_cached_suite_palette")),
    (hardening, hardening.ThemeHardeningTests, (
        "test_stale_source_is_hidden_and_valid_zero_survives_recovery",
        "test_unrepresentable_timer_and_telemetry_do_not_break_paint",
        "test_connection_loss_clears_live_values_and_reconnection_refreshes",
        "test_corrupt_historical_numbers_are_unavailable")),
)


def generic_case(module, cls, method):
    def run(self):
        with patch.object(module, "THEMES", (THEME,)):
            getattr(cls, method)(self)
    return run


for module, cls, methods in GENERIC:
    for method in methods:
        setattr(CinderTests, method, generic_case(module, cls, method))
del module, cls, methods, method


if __name__ == "__main__":
    unittest.main()
