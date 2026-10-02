"""Targeted checks for the new Vantage theme against the unchanged suite."""
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / 'tests/themes'))
import test_theme_contract as contracts
from render_themes import PHASES


class VantageTests(unittest.TestCase):
    def test_existing_suite_behavior_contract(self):
        names = (
            'test_saved_rpm_and_thermal_preferences_reach_live_instruments',
            'test_temperature_units_and_values_match_in_every_phase',
            'test_offline_missing_and_nonfinite_samples_render_placeholders',
            'test_configure_fahrenheit_save_reopen_keeps_canonical_celsius_and_user_bec',
            'test_corrupt_saved_numbers_produce_finite_bounded_fields',
            'test_explicit_eight_volt_bec_warning_is_preserved',
            'test_themes_do_not_modify_cached_suite_palette',
        )
        with patch.object(contracts, 'THEMES', ('vantage',)):
            for name in names:
                with self.subTest(contract=name):
                    getattr(contracts.ThemeContractTests, name)(self)

    def test_each_required_sensor_missing_prevents_ready(self):
        for field in ('voltage', 'fuelPercent', 'becVoltage', 'tempEsc', 'linkQuality'):
            with self.subTest(field=field):
                def missing(radio, widget):
                    widget[field] = None
                    if field == 'linkQuality':
                        radio.lua.execute('''
                            local originalSource = system.getSource
                            system.getSource = function(spec)
                                if type(spec) == "table" and spec.appId == 0xF010 then return nil end
                                return originalSource(spec)
                            end
                        ''')
                radio, _, _ = contracts.render('vantage', 'preflight',
                    preferences=dict(contracts.PREFERENCES, bec_warn=7.0), prepare=missing)
                text = ' '.join(item[2] for item in radio.texts).upper()
                self.assertNotRegex(text, r'\bREADY\b|ALL SYSTEMS NOMINAL|LAUNCH CLEAR')
                self.assertRegex(text, r'PARTIAL|AWAITING|WAITING|INCOMPLETE|MISSING')

    def test_dynamic_model_and_discreet_signature_survive_each_phase(self):
        for phase in PHASES:
            with self.subTest(phase=phase):
                radio, state, widget = contracts.render('vantage', phase,
                    prepare=lambda radio, widget: setattr(widget, 'craftName', 'TEST HELI'))
                self.assertTrue(any(t[2] == 'TEST HELI' for t in radio.texts))
                main = next(t for t in radio.texts if t[2] == 'Rotorflight // Ethos')
                mark = next(t for t in radio.texts if t[2].strip() == '| MWRC')
                self.assertLess(mark[3], main[3])
                definition = radio.load('widgets/dashboard/themes/vantage/init.lua')
                before = len(radio.loads)
                widget.craftName = 'ANOTHER HELI'
                for _ in range(10):
                    radio.context.setWidget(widget)
                    radio.lua.globals().TEST_TIME += 0.25
                    radio.engine.wakeup(widget, state, radio.width, radio.height)
                    radio.texts.clear()
                    radio.engine.paint(widget, definition, state, phase, radio.width, radio.height)
                self.assertTrue(any(t[2] == 'ANOTHER HELI' for t in radio.texts))
                self.assertEqual(len(radio.loads), before, 'stable wakeup/paint repeatedly loaded files')

    def test_postflight_cell_history_is_not_pack_voltage(self):
        def history(radio, widget):
            widget.connected = False
            widget.batteryConfig = None
            widget.dashboardStats.cell_voltage = radio.table({'min': 3.68, 'max': 4.2})
        radio, _, _ = contracts.render('vantage', 'postflight', prepare=history)
        self.assertRegex(' '.join(t[2] for t in radio.texts), r'3\.68\s*V')

    def test_live_and_recorded_link_use_the_same_percentage_source(self):
        for vfr, rssi, expected in ((42, 93, 42), (None, 93, 93), (0, 93, 0), (120, -82, None)):
            for phase in PHASES:
                with self.subTest(vfr=vfr, rssi=rssi, phase=phase):
                    def link_sources(radio, widget):
                        radio.lua.globals().TEST_LINK_VFR = vfr
                        radio.lua.globals().TEST_LINK_RSSI = rssi
                        radio.lua.execute('''
                            local telemetry = package.loaded["rfsuite.widgets.dashboard.context"].tasks.telemetry
                            local original = telemetry.getSensor
                            telemetry.getSensor = function(name, ...)
                                if name == "vfr" then return TEST_LINK_VFR end
                                if name == "rssi" then return TEST_LINK_RSSI end
                                return original(name, ...)
                            end
                        ''')
                        widget.dashboardStats.vfr = None if vfr is None else radio.table(
                            {'min': vfr, 'max': vfr, 'avg': vfr, 'sum': vfr*20, 'count': 20})
                        widget.dashboardStats.rssi = None if rssi is None else radio.table(
                            {'min': rssi, 'max': rssi, 'avg': rssi, 'sum': rssi*20, 'count': 20})
                    radio, _, _ = contracts.render('vantage', phase, prepare=link_sources)
                    text = ' '.join(t[2] for t in radio.texts if t[1] >= 40)
                    if expected is not None:
                        self.assertRegex(text, rf'(?<!\d){expected}%')
                    else:
                        self.assertNotRegex(text, r'-82%|120%')
                        if phase == 'preflight':
                            self.assertNotRegex(text, r'\bREADY\b')


if __name__ == '__main__':
    unittest.main(verbosity=2)
