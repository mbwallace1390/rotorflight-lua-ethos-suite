"""Behavioral contract tests for the six themes against the unchanged suite.

Run: python -m unittest discover -s tests/themes -p test_theme_contract.py
Uses the same actual Lua engine/context and LCD fixture as render_themes.py.
"""
import math
import re
import unittest

from render_themes import PHASES, THEMES, Radio


PREFERENCES = {
    "rpm_max": 3450, "fuel_warn": 30, "bec_min": 6.5, "bec_warn": 7.8,
    "esc_warn": 100, "esc_max": 140, "esctemp_warn": 100,
    "esctemp_max": 140, "link_warn": 50,
}


class NullDrawing:
    """Retain LCD text metrics/calls while avoiding redundant preview rasterization."""
    def __getattr__(self, name):
        return lambda *args, **kwargs: None


def render(theme, phase, *, fahrenheit=False, scenario="connected", invalid=False,
           preferences=None, prepare=None):
    radio = Radio()
    radio.draw = NullDrawing()
    widget = radio.widget(phase, scenario, fahrenheit)
    if prepare:
        prepare(radio, widget)
    if invalid:
        for i, key in enumerate(("voltage", "current", "consumption", "rpm", "fuelPercent",
                                 "becVoltage", "tempEsc", "tempMcu", "linkQuality", "throttlePercent")):
            widget[key] = (float("nan"), float("inf"), -float("inf"))[i % 3]
        for _, values in widget.dashboardStats.items():
            values["min"], values["max"], values["avg"] = float("nan"), float("inf"), -float("inf")
    radio.context.setWidget(widget)
    radio.context.widgets.dashboard.setPreferences(radio.table(preferences or PREFERENCES))
    definition = radio.load(f"widgets/dashboard/themes/{theme}/init.lua")
    state = radio.load(f"widgets/dashboard/themes/{theme}/{phase}.lua")
    ready = False
    for _ in range(20):
        radio.lua.globals().TEST_TIME += 0.25
        radio.engine.wakeup(widget, state, radio.width, radio.height)
        radio.texts.clear()
        ready = radio.engine.paint(widget, definition, state, phase, radio.width, radio.height)
    if radio.errors:
        raise AssertionError("\n".join(dict.fromkeys(radio.errors)))
    if not ready or len(radio.texts) < 5:
        raise AssertionError("Theme did not finish rendering its instruments")
    return radio, state, widget


def boxes(state):
    result = state.boxes() if callable(state.boxes) else state.boxes
    return [box for _, box in result.items()]


def configure(theme, fahrenheit=False, preferences=None):
    radio = Radio()
    radio.context.setWidget(radio.widget("preflight", fahrenheit=fahrenheit))
    radio.context.widgets.dashboard.setPreferences(radio.table(preferences or PREFERENCES))
    radio.lua.execute('''
        fields = {}
        form = {}
        function form.addExpansionPanel(label)
            return {open = function() end,
                addLine = function(self, text) return {panel = label, label = text} end}
        end
        function form.addNumberField(line, rect, minimum, maximum, getter, setter)
            assert(type(getter) == "function" and type(setter) == "function", "invalid form callback arguments")
            local field = {label = line.panel .. "/" .. line.label,
                minimum = minimum, maximum = maximum, getter = getter, setter = setter,
                step = function() end, decimals = function() end,
                suffix = function(self, value) self.unit = value end}
            fields[#fields + 1] = field
            return field
        end
    ''')
    module = radio.load(f"widgets/dashboard/themes/{theme}/configure.lua")
    module.configure()
    return radio, module, [field for _, field in radio.lua.globals().fields.items()]


class ThemeContractTests(unittest.TestCase):
    def test_saved_rpm_and_thermal_preferences_reach_live_instruments(self):
        for theme in THEMES:
            with self.subTest(theme=theme):
                radio, state, _ = render(theme, "inflight")
                live = boxes(state)
                rpm_limits = [box._cache.rpmMax for box in live if box._cache and box._cache.rpmMax is not None]
                rpm_limits += [box._cache.rangeMax for box in live
                               if box.source == "rpm" and box._cache and box._cache.rangeMax is not None]
                self.assertIn(3450, rpm_limits, "saved maximum headspeed was ignored")
                esc_limits = [box._cache.escMax for box in live if box._cache and box._cache.escMax is not None]
                esc_limits += [box._cache.rangeMax for box in live
                               if box.source == "temp_esc" and box._cache and box._cache.rangeMax is not None]
                self.assertIn(140, esc_limits, "saved thermal maximum was ignored")

    def test_temperature_units_and_values_match_in_every_phase(self):
        for theme in THEMES:
            for phase in PHASES:
                for fahrenheit in (False, True):
                    with self.subTest(theme=theme, phase=phase, fahrenheit=fahrenheit):
                        radio, _, _ = render(theme, phase, fahrenheit=fahrenheit)
                        text = " ".join(item[2] for item in radio.texts)
                        self.assertIn("°F" if fahrenheit else "°C", text)
                        self.assertNotIn("°C" if fahrenheit else "°F", text)
                        raw = 86 if phase == "postflight" else 62
                        converted = raw * 1.8 + 32 if fahrenheit else raw
                        # Existing suite objects truncate; custom numeric displays
                        # round. Either is valid within one displayed degree.
                        expected = f"(?:{math.floor(converted)}|{math.floor(converted + 0.5)})"
                        self.assertRegex(text, rf"(?<!\d){expected}(?!\d)", "temperature value was not converted exactly once")

    def test_offline_missing_and_nonfinite_samples_render_placeholders(self):
        invalid_text = re.compile(r"(^|[^a-z])(nan|[+-]?inf)([^a-z]|$)", re.I)
        for theme in THEMES:
            for phase in PHASES:
                for scenario in ("offline", "missing", "nonfinite"):
                    with self.subTest(theme=theme, phase=phase, scenario=scenario):
                        radio, _, _ = render(theme, phase, scenario="connected" if scenario == "nonfinite" else scenario,
                                             invalid=scenario == "nonfinite")
                        texts = [item[2] for item in radio.texts]
                        self.assertFalse(any(invalid_text.search(text) for text in texts), texts)
                        if phase != "postflight" and scenario in ("offline", "missing"):
                            self.assertFalse(any("48.2" in text for text in texts), "stale live voltage shown without telemetry")

    def test_configure_fahrenheit_save_reopen_keeps_canonical_celsius_and_user_bec(self):
        for theme in THEMES:
            with self.subTest(theme=theme):
                radio, module, fields = configure(theme, fahrenheit=True)
                temperature_fields = [field for field in fields if field.unit == "°F"]
                self.assertEqual(len(temperature_fields), 2)
                self.assertEqual([field.getter() for field in temperature_fields], [212, 284])
                temperature_fields[0].setter(230)  # 110 C
                temperature_fields[1].setter(302)  # 150 C
                module.write()
                saved = dict(radio.context.widgets.dashboard.preferences().items())
                warn = "esctemp_warn" if theme in ("mwrc", "libertyops250") else "esc_warn"
                maximum = "esctemp_max" if theme in ("mwrc", "libertyops250") else "esc_max"
                self.assertAlmostEqual(saved[warn], 110)
                self.assertAlmostEqual(saved[maximum], 150)
                self.assertAlmostEqual(saved["bec_warn"], 7.8)
                _, _, reopened = configure(theme, preferences=saved)
                self.assertEqual([field.getter() for field in reopened if field.unit == "°C"], [110, 150])

    def test_corrupt_saved_numbers_produce_finite_bounded_fields(self):
        for theme in THEMES:
            for bad in (float("nan"), float("inf"), -float("inf")):
                with self.subTest(theme=theme, bad=bad):
                    keys = ("rpm_min", "rpm_max", "bec_min", "bec_warn", "bec_max", "esctemp_warn", "esctemp_max") \
                        if theme in ("mwrc", "libertyops250") else \
                        ("rpm_max", "bec_min", "bec_warn", "esc_warn", "esc_max", "fuel_warn", "link_warn")
                    prefs = {key: bad for key in keys}
                    radio, module, fields = configure(theme, preferences=prefs)
                    for field in fields:
                        value = field.getter()
                        self.assertTrue(math.isfinite(value), field.label)
                        self.assertGreaterEqual(value, field.minimum, field.label)
                        self.assertLessEqual(value, field.maximum, field.label)
                    module.write()
                    for key, value in radio.context.widgets.dashboard.preferences().items():
                        if isinstance(value, (float, int)):
                            self.assertTrue(math.isfinite(value), key)

    def test_explicit_eight_volt_bec_warning_is_preserved(self):
        prefs = dict(PREFERENCES, bec_warn=8.0)
        for theme in THEMES:
            with self.subTest(theme=theme):
                radio, module, _ = configure(theme, preferences=prefs)
                module.write()
                self.assertEqual(radio.context.widgets.dashboard.getPreference("bec_warn"), 8.0)
                if theme in ("aegis", "america250", "singularity", "zafira"):
                    _, state, _ = render(theme, "preflight", preferences=prefs)
                    self.assertTrue(any(box._cache and box._cache.becWarn == 8.0 for box in boxes(state)))

    def test_partial_preflight_data_does_not_claim_ready(self):
        prefs = dict(PREFERENCES, bec_warn=7.0)
        for theme in ("aegis", "america250", "singularity", "zafira"):
            with self.subTest(theme=theme):
                radio, _, _ = render(theme, "preflight", preferences=prefs,
                                     prepare=lambda radio, widget: setattr(widget, "tempEsc", None))
                text = " ".join(item[2] for item in radio.texts).upper()
                self.assertNotRegex(text, r"READY|ALL SYSTEMS NOMINAL|SYSTEMS NOMINAL|LAUNCH CLEAR")
                self.assertRegex(text, r"PARTIAL|AWAITING|WAITING|INCOMPLETE|MISSING")

    def test_themes_do_not_modify_cached_suite_palette(self):
        for modern in (False, True):
            for theme in THEMES:
                with self.subTest(theme=theme, modern=modern):
                    radio = Radio()
                    if modern:
                        for index, name in enumerate(("THEME_DEFAULT_COLOR", "THEME_DEFAULT_BGCOLOR", "THEME_FOCUS_BGCOLOR",
                            "THEME_FOCUS_COLOR", "THEME_PRIMARY_COLOR", "THEME_PRIMARY_BGCOLOR", "THEME_SECONDARY_COLOR",
                            "THEME_SECONDARY_BGCOLOR", "THEME_HIGHLIGHT_COLOR", "THEME_HIGHLIGHT_CONTRASTING_COLOR",
                            "THEME_DISABLE_COLOR", "THEME_ERROR_COLOR", "THEME_WARNING_COLOR", "THEME_ACTIVE_COLOR",
                            "THEME_INACTIVE_COLOR", "THEME_BUTTON_BORDER_ACTIVE_COLOR", "THEME_BUTTON_BORDER_COLOR",
                            "THEME_SAFE_COLOR", "THEME_SAFE_CONTRASTING_COLOR", "THEME_PAGE_BGCOLOR"), 1):
                            radio.lua.globals()[name] = index
                        radio.lua.execute('''
                            system.getVersion = function() return {major = 26, minor = 1, revision = 0} end
                            lcd.themeColor = function(index) return 0x202020 + index * 256 end
                        ''')
                    radio.context.setWidget(radio.widget("preflight"))
                    shared = radio.context.widgets.dashboard.utils.themeColors()
                    before = dict(shared.items())
                    for phase in PHASES:
                        radio.load(f"widgets/dashboard/themes/{theme}/{phase}.lua")
                        self.assertEqual(dict(shared.items()), before, f"{phase} modified shared suite colors")

    def test_postflight_minimum_cell_uses_history_after_disconnect(self):
        def disconnected_history(radio, widget):
            widget.connected = False
            widget.batteryConfig = None
            widget.voltage = None
            widget.dashboardStats.cell_voltage = radio.table({"min": 3.68, "max": 4.2})

        for theme in ("mwrc", "libertyops250"):
            with self.subTest(theme=theme):
                _, state, _ = render(theme, "postflight", prepare=disconnected_history)
                card = next(box for box in boxes(state) if box.title == "Minimum cell")
                self.assertEqual(card._cache.text, "3.68V", "historical per-cell minimum was replaced by pack voltage")

    def test_postflight_minimum_cell_never_relabels_pack_voltage(self):
        for theme in ("mwrc", "libertyops250"):
            for historical_cell in (None, float("nan"), float("inf")):
                with self.subTest(theme=theme, historical_cell=historical_cell):
                    def pack_only(radio, widget):
                        widget.connected = False
                        widget.batteryConfig = None
                        widget.dashboardStats.voltage = radio.table({"min": 44.2, "max": 50.4})
                        widget.dashboardStats.cell_voltage = None if historical_cell is None else \
                            radio.table({"min": historical_cell})
                    _, state, _ = render(theme, "postflight", prepare=pack_only)
                    card = next(box for box in boxes(state) if box.title == "Minimum cell")
                    self.assertEqual(card._cache.text, "--", "unknown cell count must not label pack voltage as per-cell voltage")
                    self.assertEqual(card._cache.percent, 0)

    def test_postflight_link_uses_valid_percentage_history_and_refreshes(self):
        for theme in ("mwrc", "libertyops250"):
            for rssi_min, expected in ((None, "87%"), (float("nan"), "87%"),
                                       (-82, "87%"), (101, "87%"), (93, "93%")):
                with self.subTest(theme=theme, rssi_min=rssi_min):
                    def link_history(radio, widget):
                        widget.dashboardStats.rssi = None if rssi_min is None else radio.table({"min": rssi_min})
                        widget.dashboardStats.vfr = radio.table({"min": 87})
                    radio, state, widget = render(theme, "postflight", prepare=link_history)
                    card = next(box for box in boxes(state) if box.title == "Link Min")
                    self.assertEqual(card._cache.text, expected, "legacy percentage history was lost or dB was labeled percent")
                    widget.dashboardStats.rssi = None
                    widget.dashboardStats.vfr = radio.table({"min": 83})
                    for _ in range(10):
                        radio.lua.globals().TEST_TIME += 0.25
                        radio.engine.wakeup(widget, state, radio.width, radio.height)
                    self.assertEqual(card._cache.text, "83%", "link summary remained cached after its value changed")
                    widget.dashboardStats.vfr = None
                    for _ in range(10):
                        radio.lua.globals().TEST_TIME += 0.25
                        radio.engine.wakeup(widget, state, radio.width, radio.height)
                    self.assertEqual(card._cache.text, "--", "removed history left a stale link summary")
                    self.assertEqual(card._cache.percent, 0)


if __name__ == "__main__":
    unittest.main()
