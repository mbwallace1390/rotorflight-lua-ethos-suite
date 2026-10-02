"""Exercise real deferred tool UI and Bridge together with unchanged upstream checks.

Only missing ETHOS SDK methods are added to each upstream harness. No suite
modules or verifier source are replaced. These are desktop lifecycle checks.
"""
from pathlib import Path
import importlib
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "build/test-deps"))

SDK_ADAPTER = r'''
    adapterDraws, adapterLoads, adapterTime = {}, {}, 100
    os.clock = function() return adapterTime end
    os.exit = function(code) error("upstream verifier exit " .. tostring(code)) end
    local realLoadfile, realDofile = loadfile, dofile
    loadfile = function(path, ...)
        adapterLoads[path] = (adapterLoads[path] or 0) + 1
        return realLoadfile(path, ...)
    end
    dofile = function(path)
        if path:match("/app/tool%.lua$") then
            -- The upstream stubs predate Bridge's canvas. Extend just the SDK.
            lcd.RGB = function(r, g, b)
                assert(r == r and g == g and b == b, "nonfinite color")
                return r * 65536 + g * 256 + b
            end
            lcd.darkMode = function() return true end
            lcd.drawFilledRectangle = function(x, y, w, h)
                assert(w >= 0 and h >= 0, "invalid filled rectangle")
                adapterDraws[#adapterDraws + 1] = {x, y, w, h, adapterColor}
            end
            lcd.drawRectangle = function(x, y, w, h)
                assert(w >= 0 and h >= 0, "invalid rectangle")
                adapterDraws[#adapterDraws + 1] = {x, y, w, h, adapterColor}
            end
            lcd.color = function(color) adapterColor = color end
            local register = system.registerSystemTool
            system.registerSystemTool = function(tool)
                adapterTool = tool
                adapterColdBridgeAbsent = package.loaded["rfsuite.app.theme_bridge"] == nil
                return register(tool)
            end
        end
        return realDofile(path)
    end
'''

BRIDGE_LIFECYCLE = r'''
    assert(adapterColdBridgeAbsent, "Bridge loaded before the tool was created")
    local bridge = assert(package.loaded["rfsuite.app.theme_bridge"])
    local bus = assert(package.loaded["rfsuite.bus"])
    local subscriptions
    for index = 1, 20 do
        local name, value = debug.getupvalue(bus.subscribe, index)
        if name == "subscribers" then subscriptions = value; break end
    end
    assert(subscriptions, "subscriber table unavailable for leak assertion")
    local function subscriberCount()
        local count = 0
        for _, handlers in pairs(subscriptions) do count = count + #handlers end
        return count
    end
    local function bridgeLoadCount()
        local count = 0
        for path, loads in pairs(adapterLoads) do
            if path:match("/app/theme_bridge%.lua$") then count = count + loads end
        end
        return count
    end
    local function checkCleared()
        assert(bridge.getPalette() == nil, "closed Bridge retains palette")
        adapterDraws = {}
        adapterTool.paint({})
        adapterTool.wakeup({})
        assert(#adapterDraws == 0, "closed tool still paints Bridge chrome")
    end
    adapterTool.close()
    checkCleared()
    local baseline = subscriberCount()
    local originalPublish, requests = bus.publish, 0
    bus.publish = function(topic, payload)
        if topic == "msp.request" then requests = requests + 1 end
        return originalPublish(topic, payload)
    end
    bus.publish("task.status", {running=true, updatedAt=adapterTime})
    bus.publish("session.update", {connected=true, apiVersionSupported=true})
    local loaded = bridgeLoadCount()
    assert(loaded == 1, "Bridge must be loaded only once")
    local openCount
    for cycle = 1, 5 do
        adapterTool.create()
        assert(bridge.getPalette(), "create did not open Bridge")
        bus.publish("settings.update", {
            general={follow_dashboard_theme=true},
            dashboard={use_same_theme=true, theme_preflight="system/kevd"}
        })
        adapterTime = adapterTime + 1
        adapterTool.wakeup({})
        local palette = assert(bridge.getPalette())
        assert(palette.path == "system/kevd", "theme settings were not applied")
        adapterDraws = {}
        adapterTool.paint({})
        assert(#adapterDraws > 2, "tool paint did not draw canvas and chrome")
        local canvas = adapterDraws[1]
        assert(canvas[1] == 0 and canvas[2] == 0 and canvas[3] == 480 and canvas[4] == 320,
               "Bridge canvas does not match native dimensions")
        assert(canvas[5] == palette.background, "Bridge background palette was not used")
        if openCount then assert(subscriberCount() == openCount, "open subscriptions accumulated")
        else openCount = subscriberCount() end
        for tick = 1, 100 do
            adapterTime = adapterTime + 0.1
            -- Match a running task's heartbeat while simulated time advances.
            bus.publish("task.status", {running=true, updatedAt=adapterTime})
            adapterTool.wakeup({})
        end
        adapterTool.close()
        checkCleared()
        assert(subscriberCount() == baseline, "close leaked bus subscribers")
        assert(bridgeLoadCount() == loaded, "Bridge was reloaded")
    end
    assert(requests == 0, "Bridge/root lifecycle emitted MSP requests")
    adapterLifecyclePassed = true
'''


class ToolBridgeLifecycleTests(unittest.TestCase):
    def run_harness(self, version, name, lifecycle=False):
        runtime = importlib.import_module(f"lupa.{version}").LuaRuntime
        lua = runtime(unpack_returned_tuples=True)
        output = []
        lua.globals().print = lambda *args: output.append(" ".join(map(str, args)))
        lua.execute(SDK_ADAPTER)
        path = ROOT / "bin/tool_ui" / name
        # Preserve original file/debug paths; don't modify the upstream harness.
        lua.execute(path.read_text(encoding="utf-8"), name="@" + path.as_posix())
        self.assertIn("ALL CHECKS PASSED", output)
        self.assertFalse(any("  FAIL " in line for line in output), "\n".join(output))
        if lifecycle:
            lua.execute(BRIDGE_LIFECYCLE)
            self.assertTrue(lua.globals().adapterLifecyclePassed)
        return output

    def test_upstream_lazy_ui_with_bridge_lifecycle(self):
        for version in ("lua53", "lua54"):
            with self.subTest(version=version):
                self.run_harness(version, "verify_tool_ui_lazy.lua", lifecycle=True)

    def test_upstream_guarded_menus_do_not_add_msp(self):
        for version in ("lua53", "lua54"):
            with self.subTest(version=version):
                self.run_harness(version, "verify_no_extra_msp.lua")


if __name__ == "__main__":
    unittest.main()
