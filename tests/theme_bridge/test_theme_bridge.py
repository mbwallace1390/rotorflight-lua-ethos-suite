"""Theme Bridge behavior against the suite's unchanged bus and flight tracker.

Run with Python and Lupa available: python -m unittest discover -s tests/theme_bridge
The optional build/test-deps directory supports an isolated local Lupa install.
"""

from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "build" / "test-deps"))
from lupa.lua52 import LuaRuntime


class ThemeBridgeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.globals().suite_root = (ROOT / "src" / "rfsuite").as_posix()
        self.lua.execute(r'''
            now, width, height, sourceReads = 0, 800, 480, 0
            loads, drawCalls, modelPrefs, missingFiles = {}, {}, {}, {}
            local originalLoadfile = loadfile
            function loadfile(path)
                loads[path] = (loads[path] or 0) + 1
                if missingFiles[path] then return nil, "missing fixture" end
                return originalLoadfile(suite_root .. "/" .. path)
            end
            os.clock = function() return now end
            CATEGORY_CHANNEL = 1
            system = {getSource = function()
                sourceReads = sourceReads + 1
                return {value = function() return 0 end}
            end}
            lcd = {
                RGB = function(r, g, b, a)
                    for _, channel in ipairs({r, g, b}) do
                        assert(type(channel) == "number" and channel >= 0 and channel <= 255
                            and channel == math.floor(channel), "invalid LCD RGB channel")
                    end
                    assert(a == nil or (a >= 0 and a <= 1), "invalid LCD opacity")
                    return r * 65536 + g * 256 + b
                end,
                color = function(value)
                    assert(type(value) == "number" and value == value and value > -math.huge
                        and value < math.huge, "invalid color reached drawing")
                end,
                drawFilledRectangle = function(x, y, w, h)
                    drawCalls[#drawCalls + 1] = {x, y, w, h}
                end,
                drawRectangle = function() end,
                getWindowSize = function() return width, height end,
                darkMode = function() return true end,
                invalidate = function() end,
            }
            local cache = {}
            package.loaded["rfsuite.lib.require"] = function(path)
                if cache[path] then return cache[path] end
                local result
                if path == "lib/model_preferences.lua" then
                    result = {load = function(id) return modelPrefs[id] or {} end}
                elseif path == "lib/settings_store.lua" then
                    result = {
                        load = function() return initialSettings end,
                        followDashboardThemeEnabled = function(settings)
                            return not settings.general or settings.general.follow_dashboard_theme ~= false
                        end,
                    }
                else
                    result = assert(loadfile(path))()
                end
                cache[path] = result
                return result
            end
            bus = package.loaded["rfsuite.lib.require"]("lib/bus.lua")
            initialSettings = {general = {}, dashboard = {
                use_same_theme = false,
                theme_preflight = "system/aegis",
                theme_inflight = "system/singularity",
                theme_postflight = "system/zafira",
            }}
            bridge = assert(loadfile("app/theme_bridge.lua"))()
            function tick()
                now = now + 0.6
                bridge.wakeup()
            end
            function flush() tick(); tick() end
            function palettePath() return bridge.getPalette().path end
            function loadCount()
                local count = 0
                for _, value in pairs(loads) do count = count + value end
                return count
            end
        ''')

    def run_lua(self, code):
        self.lua.execute(code)

    def test_all_six_installed_palettes_and_paint_are_cached(self):
        self.run_lua('''
            bridge.open(initialSettings)
            for _, name in ipairs({"aegis", "america250", "libertyops250", "mwrc", "singularity", "zafira"}) do
                initialSettings.dashboard.theme_preflight = "system/" .. name
                bus.publish("settings.update", initialSettings)
                flush()
                assert(palettePath() == "system/" .. name, name)
                local expected = assert(loadfile("widgets/dashboard/themes/" .. name .. "/init.lua"))().appTheme
                local accent = expected.accent
                assert(bridge.getPalette().accent == lcd.RGB(accent[1], accent[2], accent[3]))
                local count = loadCount()
                for i = 1, 20 do bridge.paintBackground(); bridge.paintChrome(); tick() end
                assert(loadCount() == count, "theme reloaded during stable paint/wakeup")
            end
        ''')

    def test_open_midflight_uses_retained_phase_without_false_arm_edge(self):
        self.run_lua('''
            bus.publish("session.update", {connected = true, isArmed = true,
                timerFlightCounted = true, timerSession = 30, mcuId = "craft-a"})
            bridge.open(initialSettings)
            flush()
            assert(palettePath() == "system/singularity", "midflight opened as preflight")
        ''')

    def test_custom_page_title_contrast_on_bridge_canvas(self):
        def luminance(color):
            channels = [(int(color) >> shift & 255) / 255 for shift in (16, 8, 0)]
            linear = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
                      for v in channels]
            return sum(v * weight for v, weight in zip(linear, (0.2126, 0.7152, 0.0722)))

        self.run_lua("bridge.open(initialSettings)")
        for name in ("aegis", "america250", "libertyops250", "mwrc", "singularity", "zafira"):
            with self.subTest(theme=name):
                self.lua.globals().initialSettings.dashboard.theme_preflight = "system/" + name
                self.run_lua('bus.publish("settings.update", initialSettings); flush()')
                palette = self.lua.globals().bridge.getPalette()
                foreground, background = luminance(palette.accent), luminance(palette.background)
                contrast = (max(foreground, background) + 0.05) / (min(foreground, background) + 0.05)
                self.assertGreaterEqual(contrast, 4.5, "small native page title lacks contrast")

    def test_same_aircraft_reconnect_preserves_postflight_but_new_aircraft_resets(self):
        self.run_lua('''
            bridge.open(initialSettings)
            bus.publish("session.update", {connected = true, isArmed = true,
                governorState = 4, timerSession = 30, mcuId = "craft-a"})
            flush(); tick()
            assert(palettePath() == "system/singularity")
            bus.publish("session.update", {connected = false, timerSession = 0})
            flush()
            assert(palettePath() == "system/zafira")
            bus.publish("session.update", {connected = true, isArmed = false,
                timerSession = 0, mcuId = "craft-a"})
            flush()
            assert(palettePath() == "system/zafira", "same craft lost postflight history")
            bus.publish("session.update", {connected = true, isArmed = false,
                timerSession = 0, mcuId = "craft-b"})
            flush()
            assert(palettePath() == "system/aegis", "new craft retained old history")
        ''')

    def test_tracker_does_not_mutate_retained_snapshot_or_resolve_source_each_update(self):
        self.run_lua('''
            bridge.open(initialSettings)
            for i = 1, 5 do
                local snapshot = {connected = true, isArmed = true, governorState = 0,
                    rxMap = {throttle = 2}, mcuId = "craft-a"}
                bus.publish("session.update", snapshot)
                flush()
                assert(snapshot._throttleChannelMember == nil, "mutated retained bus snapshot")
                assert(snapshot._throttleChannelSource == nil, "source leaked into retained snapshot")
            end
            assert(sourceReads == 1, "source cache discarded on every snapshot")
        ''')

    def test_model_override_and_live_disable(self):
        self.run_lua('''
            modelPrefs["craft-a"] = {dashboard = {use_same_theme = true,
                theme_preflight = "system/america250"}}
            bus.publish("session.update", {connected = true, isArmed = false, mcuId = "craft-a"})
            bridge.open(initialSettings)
            flush()
            assert(palettePath() == "system/america250", "model override ignored")
            initialSettings.general.follow_dashboard_theme = false
            bus.publish("settings.update", initialSettings)
            flush()
            assert(bridge.getPalette().native == true)
            drawCalls = {}
            bridge.paintBackground(); bridge.paintChrome()
            assert(#drawCalls == 0, "disabled bridge still paints")
            initialSettings.general.follow_dashboard_theme = true
            bus.publish("settings.update", initialSettings)
            flush()
            assert(palettePath() == "system/america250")
        ''')

    def test_resize_updates_canvas_without_reload(self):
        self.run_lua('''
            bridge.open(initialSettings)
            flush()
            local count = loadCount()
            width, height = 784, 294
            tick()
            drawCalls = {}
            bridge.paintBackground()
            assert(drawCalls[1][3] == 784 and drawCalls[1][4] == 294, "canvas size stayed stale")
            assert(loadCount() == count)
        ''')

    def test_invalid_metadata_colors_fall_back_before_drawing(self):
        self.run_lua('''
            local originalLoadfile = loadfile
            loadfile = function(path)
                if path == "widgets/dashboard/themes/aegis/init.lua" then
                    return function() return {appTheme = {
                        background = {0/0, 20, 30}, text = math.huge,
                        accent = {10, -math.huge, 30},
                        surface = {-20, 300, 127.5, 5},
                        rail = {start = {0/0, 1, 2}, middle = {1, math.huge, 2}, finish = {1, 2, "invalid"}}
                    }} end
                end
                return originalLoadfile(path)
            end
            local function finite(value)
                return type(value) == "number" and value == value and value > -math.huge and value < math.huge
            end
            bridge.open(initialSettings)
            flush()
            local palette = bridge.getPalette()
            for _, key in ipairs({"background", "text", "accent", "surface"}) do
                assert(finite(palette[key]), "invalid metadata color: " .. key)
            end
            assert(palette.background == lcd.RGB(20, 22, 26), "invalid background did not use native fallback")
            assert(palette.accent == lcd.RGB(61, 174, 255), "invalid accent did not use native fallback")
            assert(palette.surface == lcd.RGB(0, 255, 128), "RGB channels escaped integer 0..255")
            for _, channels in ipairs({palette._backgroundRGB, palette._accentRGB,
                palette._railStartRGB, palette._railMiddleRGB, palette._railFinishRGB}) do
                for _, channel in ipairs(channels) do
                    assert(finite(channel) and channel >= 0 and channel <= 255, "invalid gradient channel")
                end
            end
            bridge.paintBackground(); bridge.paintChrome()
        ''')

    def test_invalid_native_colors_do_not_poison_signature_or_palette(self):
        self.run_lua('''
            THEME_PAGE_BGCOLOR, THEME_PRIMARY_COLOR = 1, 2
            lcd.themeColor = function(index) return index == 1 and 0/0 or math.huge end
            initialSettings.dashboard.theme_preflight = "system/helihud"
            bridge.open(initialSettings)
            flush()
            assert(bridge.getPalette().background == lcd.RGB(20, 22, 26))
            assert(bridge.getPalette().accent == lcd.RGB(61, 174, 255))
            local palette = bridge.getPalette()
            for i = 1, 5 do tick() end
            assert(bridge.getPalette() == palette, "invalid native colors broke stable cache identity")
        ''')

    def test_missing_metadata_falls_back_and_close_releases_subscriptions(self):
        self.run_lua('''
            missingFiles["widgets/dashboard/themes/aegis/init.lua"] = true
            bridge.open(initialSettings)
            flush()
            assert(palettePath() == "system/default")
            bridge.clearCache()
            bus.publish("session.update", {connected = true, isArmed = false, mcuId = "craft-a"})
            tick()
            assert(bridge.getPalette() == nil)
            missingFiles["widgets/dashboard/themes/aegis/init.lua"] = nil
            bridge.open(initialSettings)
            flush()
            assert(palettePath() == "system/aegis", "stale missing-theme cache survived reopen")
            bridge.clearCache()
        ''')


if __name__ == "__main__":
    unittest.main()
