"""Focused acceptance checks for the folder-only Ink & Halo theme.

Run: python -m unittest discover -s tests/themes -p test_inkhalo.py
Uses the real Suite Lua engine/context and desktop LCD metrics. These checks do
not register the theme or establish performance/visual acceptance on a radio.
"""
import itertools
import unittest
from unittest.mock import patch

import render_themes as renderer
import test_theme_contract as contract
import test_theme_hardening as hardening


THEME = "inkhalo"


def body(state):
    return next(box for box in contract.boxes(state) if box.paint and box.wakeup)


def plain(value):
    """Snapshot source tables, so drawing cannot silently rewrite session data."""
    if hasattr(value, "items"):
        return {key: plain(item) for key, item in value.items()}
    return value


def advance(radio, state, widget, definition, phase, frames=8):
    for _ in range(frames):
        radio.lua.globals().TEST_TIME += 0.25
        radio.engine.wakeup(widget, state, radio.width, radio.height)
        radio.texts.clear()
        ready = radio.engine.paint(widget, definition, state, phase, radio.width, radio.height)
    if radio.errors:
        raise AssertionError("\n".join(dict.fromkeys(radio.errors)))
    if not ready:
        raise AssertionError("theme did not finish rendering")


class InkHaloTests(unittest.TestCase):
    def test_full_and_compact_all_phases_modes_and_connection_states(self):
        modes = ((True, False), (True, True), (False, True))
        for phase, size, mode, scenario in itertools.product(
                renderer.PHASES, ((800, 480), (784, 294)), modes,
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
                if size == (800, 480):
                    title = next(t for t in radio.texts if t[2] == "Rotorflight // Ethos")
                    mark = next(t for t in radio.texts if t[2].strip() == "| MWRC")
                    self.assertLess(mark[3], title[3], "MWRC signature lost its smaller size")
                    group_center = (title[0] + mark[0] + mark[4]) / 2
                    self.assertLessEqual(abs(group_center - size[0] / 2), 1)

    def test_each_missing_preflight_check_stays_incomplete(self):
        preferences = dict(contract.PREFERENCES, bec_warn=7.0)
        for missing in ("fuelPercent", "becVoltage", "tempEsc", "voltage", "linkQuality"):
            with self.subTest(missing=missing):
                def prepare(radio, widget):
                    widget[missing] = None
                    if missing == "linkQuality":
                        # Also remove the fixture's fallback link Source.
                        radio.lua.execute('''
                            local previous = system.getSource
                            system.getSource = function(spec)
                                if type(spec) == "table" and spec.appId == 0xF010 then return nil end
                                return previous(spec)
                            end
                        ''')
                radio, _, _ = contract.render(THEME, "preflight", preferences=preferences, prepare=prepare)
                text = " ".join(t[2] for t in radio.texts).upper()
                self.assertNotRegex(text, r"READY|SYSTEMS NOMINAL|LAUNCH CLEAR")
                self.assertRegex(text, r"PARTIAL|AWAITING|WAITING|INCOMPLETE|MISSING")

    def test_preflight_warning_and_threshold_changes_update_with_steady_telemetry(self):
        preferences = dict(contract.PREFERENCES, bec_warn=7.0)
        radio, state, widget = contract.render(THEME, "preflight", preferences=preferences)
        self.assertEqual(body(state)._cache.status, "READY")
        radio.context.widgets.dashboard.savePreference("bec_warn", 8.0)
        hardening.repaint(radio, state, widget, THEME, "preflight")
        self.assertEqual(body(state)._cache.becWarn, 8.0)
        self.assertEqual(body(state)._cache.status, "CAUTION")
        widget.becVoltage = 6.0
        hardening.repaint(radio, state, widget, THEME, "preflight")
        self.assertEqual(body(state)._cache.status, "CHECK")
        widget.connected = False
        hardening.repaint(radio, state, widget, THEME, "preflight")
        self.assertEqual(body(state)._cache.status, "WAITING")

    def test_valid_zero_live_and_historical_readings_remain_available(self):
        def zeros(radio, widget):
            for key in ("current", "rpm", "fuelPercent", "tempEsc", "throttlePercent", "consumption", "timerLive"):
                widget[key] = 0
            widget.modelStats = radio.table({"flightcount": 0, "totalflighttime": 0, "lastflighttime": 0})
            for _, entry in widget.dashboardStats.items():
                for key in ("min", "max", "avg", "sum"):
                    entry[key] = 0

        radio, state, _ = contract.render(THEME, "inflight", prepare=zeros)
        cache = body(state)._cache
        self.assertEqual(cache.rpmText, "0")
        self.assertEqual(cache.currentText, "0.0 A")
        self.assertEqual(cache.escText, "0°C")
        self.assertEqual(cache.fuelText, "0%")
        self.assertEqual(cache.timer, "00:00")
        _, state, _ = contract.render(THEME, "postflight", prepare=zeros)
        cache = body(state)._cache
        for _, metric in cache.metrics.items():
            self.assertEqual(metric.value, 0)
            self.assertNotIn("--", metric.text)
        self.assertEqual((cache.time, cache.count, cache.total), ("00:00", "0", "00:00:00"))

    def test_postflight_uses_recorded_cell_and_percentage_values_without_current_pack(self):
        for cell, vfr, rssi, expected_cell, expected_link in (
                (3.68, 87, -82, "3.68 V", "87%"),
                (None, None, -82, "--", "--"),
                (float("nan"), 0, 93, "--", "0%"),
                (float("inf"), 120, 93, "--", "93%")):
            with self.subTest(cell=cell, vfr=vfr, rssi=rssi):
                def history(radio, widget):
                    widget.connected, widget.batteryConfig, widget.voltage = False, None, None
                    widget.dashboardStats.voltage = radio.table({"min": 44.2, "max": 50.4})
                    widget.dashboardStats.cell_voltage = None if cell is None else radio.table({"min": cell})
                    widget.dashboardStats.vfr = None if vfr is None else radio.table({"min": vfr})
                    widget.dashboardStats.rssi = radio.table({"min": rssi})
                _, state, _ = contract.render(THEME, "postflight", prepare=history)
                cache = body(state)._cache
                self.assertEqual(cache.metrics[9].text, expected_cell,
                                 "current pack data must not replace a historical per-cell sample")
                self.assertEqual(cache.metrics[7].text, expected_link,
                                 "only recorded 0..100 percentage samples belong in link history")

    def test_postflight_duration_retains_current_flight_then_resets_for_another_model(self):
        def old_saved_flight(radio, widget):
            widget.modelStats.lastflighttime = 97
        radio, state, widget = contract.render(THEME, "postflight", prepare=old_saved_flight)
        cache = body(state)._cache
        self.assertEqual((cache.time, cache.count, cache.total), ("03:04", "42", "02:37:40"))
        widget.connected, widget.timerLive = False, 0
        hardening.repaint(radio, state, widget, THEME, "postflight")
        self.assertEqual(cache.time, "03:04", "older persisted flight replaced the last known current duration")
        widget.modelStats = None
        hardening.repaint(radio, state, widget, THEME, "postflight")
        self.assertEqual((cache.time, cache.count, cache.total), ("03:04", "42", "02:37:40"))
        radio.lua.execute("model.name = function() return 'A different airframe' end")
        widget.craftName = "A different airframe"
        hardening.repaint(radio, state, widget, THEME, "postflight")
        self.assertNotEqual(cache.time, "03:04", "a different model inherited the prior flight duration")
        self.assertNotEqual(cache.count, "42", "a different model inherited the prior flight count")
        self.assertNotEqual(cache.total, "02:37:40", "a different model inherited the prior total")

        def cold_offline(radio, widget):
            widget.connected, widget.timerLive = False, 0
            widget.modelStats.lastflighttime = 97
        _, state, _ = contract.render(THEME, "postflight", prepare=cold_offline)
        self.assertEqual(body(state)._cache.time, "01:37")

    def test_settings_changes_are_scoped_and_paint_does_not_mutate_source_data(self):
        prefs = dict(contract.PREFERENCES, unrelated_setting=0)
        radio, config, fields = contract.configure(THEME, preferences=prefs)
        self.assertEqual(dict(radio.context.widgets.dashboard.preferences().items()), prefs)
        rpm = next(field for field in fields if field.label.endswith("Maximum headspeed"))
        rpm.setter(3800)
        self.assertEqual(radio.context.widgets.dashboard.getPreference("rpm_max"), 3450,
                         "editing a form should not save before write")
        config.write()
        saved = dict(radio.context.widgets.dashboard.preferences().items())
        self.assertEqual(saved["rpm_max"], 3800)
        self.assertEqual(saved["unrelated_setting"], 0)
        radio.draw = contract.NullDrawing()
        definition = radio.load(f"widgets/dashboard/themes/{THEME}/init.lua")
        for phase in renderer.PHASES:
            with self.subTest(phase=phase):
                widget = radio.widget(phase)
                protected = {key: plain(widget[key]) for key in
                             ("settingsSnapshot", "modelStats", "batteryConfig")}
                radio.context.setWidget(widget)
                state = radio.load(f"widgets/dashboard/themes/{THEME}/{phase}.lua")
                advance(radio, state, widget, definition, phase, frames=20)
                self.assertEqual(dict(radio.context.widgets.dashboard.preferences().items()), saved)
                self.assertEqual({key: plain(widget[key]) for key in protected}, protected)
                # The core legitimately accumulates statistics while sensor
                # getters are read in wakeup. Paint only consumes the prepared
                # display cache and must preserve the recorded source samples.
                recorded = plain(widget.dashboardStats)
                box = body(state)
                for _ in range(3):
                    box.paint(box._dashboardRectX, box._dashboardRectY,
                              box._dashboardRectW, box._dashboardRectH,
                              box, box._cache, radio.context.tasks.telemetry)
                self.assertEqual(plain(widget.dashboardStats), recorded)

    def test_steady_body_paint_reuses_tables_fitted_text_and_loaded_modules(self):
        for phase, size in itertools.product(renderer.PHASES, ((800, 480), (784, 294))):
            with self.subTest(phase=phase, size=size):
                radio, state, _ = contract.render(THEME, phase, width=size[0], height=size[1])
                box = body(state)
                args = (box._dashboardRectX, box._dashboardRectY, box._dashboardRectW, box._dashboardRectH)
                telemetry = radio.context.tasks.telemetry
                box.paint(*args, box, box._cache, telemetry)
                snapshot = radio.lua.eval('''function(root)
                    local refs, seen = {}, {}
                    local function walk(value, path)
                        if seen[value] then return end
                        seen[value], refs[path] = true, value
                        for key, child in pairs(value) do
                            if type(child) == "table" then walk(child, path .. "/" .. tostring(key)) end
                        end
                    end
                    walk(root, "cache")
                    return refs
                end''')
                references = snapshot(box._cache)
                loads = tuple(radio.loads)
                radio.lua.execute('''
                    local previous = lcd.getTextSize
                    INKHALO_MEASUREMENTS = 0
                    lcd.getTextSize = function(text)
                        INKHALO_MEASUREMENTS = INKHALO_MEASUREMENTS + 1
                        return previous(text)
                    end
                ''')
                for _ in range(5):
                    box.wakeup(box, telemetry)
                    box.paint(*args, box, box._cache, telemetry)
                current = snapshot(box._cache)
                self.assertEqual(set(references.keys()), set(current.keys()))
                equal = radio.lua.eval("rawequal")
                for path, reference in references.items():
                    self.assertTrue(equal(reference, current[path]), f"steady rendering replaced {path}")
                self.assertEqual(tuple(radio.loads), loads, "steady rendering performed file I/O")
                self.assertEqual(radio.lua.globals().INKHALO_MEASUREMENTS, 0,
                                 "unchanged body labels were remeasured on every paint")


# Reuse only generic cases; the older suite's remaining methods target the
# specific MWRC/Liberty summary layouts. Module-local patches are undone after
# each case, keeping these focused checks independent of the full theme catalog.
GENERIC_CONTRACT_CASES = (
    "test_saved_rpm_and_thermal_preferences_reach_live_instruments",
    "test_temperature_units_and_values_match_in_every_phase",
    "test_offline_missing_and_nonfinite_samples_render_placeholders",
    "test_configure_fahrenheit_save_reopen_keeps_canonical_celsius_and_user_bec",
    "test_corrupt_saved_numbers_produce_finite_bounded_fields",
    "test_explicit_eight_volt_bec_warning_is_preserved",
    "test_themes_do_not_modify_cached_suite_palette",
)
GENERIC_HARDENING_CASES = (
    "test_stale_source_is_hidden_and_valid_zero_survives_recovery",
    "test_long_model_names_stay_in_the_native_model_slot",
    "test_unrepresentable_timer_and_telemetry_do_not_break_paint",
    "test_connection_loss_clears_live_values_and_reconnection_refreshes",
    "test_corrupt_historical_numbers_are_unavailable",
)


def for_inkhalo(module, test_class, method_name):
    method = getattr(test_class, method_name)

    def run(self):
        with patch.object(module, "THEMES", (THEME,)):
            method(self)

    run.__name__ = method_name
    run.__doc__ = method.__doc__
    return run


for module, test_class, cases in (
        (contract, contract.ThemeContractTests, GENERIC_CONTRACT_CASES),
        (hardening, hardening.ThemeHardeningTests, GENERIC_HARDENING_CASES)):
    for method_name in cases:
        setattr(InkHaloTests, method_name, for_inkhalo(module, test_class, method_name))
del module, test_class, cases, method_name


if __name__ == "__main__":
    unittest.main()
