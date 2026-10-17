"""Registration integration checks using real Suite modules and in-memory radio UI.

Run: python -m unittest discover -s tests/themes -p test_meridian_cinder_registration.py
Requires Lupa (Lua 5.4); no preview renderer or other custom-theme tests are needed.
RFSUITE_TEST_ROOT may point at another checkout. RFSUITE_TEST_THEMES may select
comma-separated installed themes. By default both installed Meridian/Cinder
folders are tested, so this file also works in either standalone theme branch.
Bridge checks explicitly skip when that optional addon is absent.

The LCD, form, disk settings, model preferences, and paint engine are test
doubles. Registry/selection code, settings normalization, pages, configure
modules, metadata, bus, and Bridge lifecycle execute from the selected tree.
Phase painting itself belongs to the separate rendered-theme acceptance tests.
"""
import os
from pathlib import Path
import sys
import unittest

HERE_ROOT = Path(__file__).resolve().parents[2]
ROOT = Path(os.environ.get("RFSUITE_TEST_ROOT", HERE_ROOT)).resolve()
SOURCE = ROOT / "src" / "rfsuite"
sys.path.insert(0, str(HERE_ROOT / "build" / "test-deps"))
from lupa.lua54 import LuaRuntime
from i18n_fixture import resolve_source

THEMES = tuple(filter(None, os.environ.get("RFSUITE_TEST_THEMES", "").split(","))) or tuple(
    name for name in ("meridian", "cinder")
    if (SOURCE / "widgets" / "dashboard" / "themes" / name / "init.lua").is_file()
)
HAS_BRIDGE = (SOURCE / "app" / "theme_bridge.lua").is_file()
HAS_DISCOVERY = (SOURCE / "lib" / "dashboard_themes.lua").is_file()


class RadioUI:
    def __init__(self, width=800, height=480):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.g = self.lua.globals()
        self.g.readSource = self.read
        self.g.listDirectory = self.list_directory
        self.g.hasDiscovery = HAS_DISCOVERY
        self.g.width, self.g.height = width, height
        self.lua.execute(r'''
            now, phaseStubs = 0, false
            loads, settingsFile, modelFiles, choices, booleans, numbers, buttons = {}, {}, {}, {}, {}, {}, {}
            activeSubscriptions = 0
            os.clock = function() return now end
            os.mkdir = function() end
            function loadfile(path)
                loads[path] = (loads[path] or 0) + 1
                local source = readSource(path)
                if not source then return nil, "missing fixture source: " .. path end
                local phase = path:match("/([a-z]+)%.lua$")
                if phaseStubs and path:match("^widgets/dashboard/themes/")
                    and (phase == "preflight" or phase == "inflight" or phase == "postflight") then
                    return function() return {fixturePhase=phase} end
                end
                return load(source, "@" .. path, "t", _G)
            end
            local function noop() end
            CATEGORY_CHANNEL, TEXT_LEFT, CENTERED, FONT_S, FONT_XS = 1, 0, 0, 20, 16
            lcd = {
                RGB = function(r,g,b) return r*65536 + g*256 + b end,
                color=noop, font=noop, drawText=noop, drawRectangle=noop, drawFilledRectangle=noop,
                getWindowSize=function() return width,height end,
                getTextSize=function(text) return #text*6,12 end,
                darkMode=function() return true end, invalidate=noop,
                loadMask=function() return nil end, isVisible=function() return true end,
            }
            system = {
                listFiles=function(path) return listDirectory(path) end,
                getSource=function() return {value=function() return 0 end} end,
                getMemoryUsage=function() return {mainStackAvailable=9000} end,
                registerWidget=function(value) registeredWidget=value end,
            }
            model = {name=function() return "Fixture craft" end}
            local function field(line, getter, setter)
                return {line=line, getter=getter, setter=setter,
                    enable=function(self,value) self.enabled=value end,
                    focus=noop, step=noop, decimals=noop,
                    suffix=function(self,value) self.unit=value end}
            end
            form = {
                clear=function() choices,booleans,numbers,buttons={},{},{},{} end,
                height=function() return 40 end,
                addExpansionPanel=function(label)
                    return {open=noop, addLine=function(self,text) return {panel=label,label=text} end}
                end,
                addChoiceField=function(line,rect,values,getter,setter)
                    local f=field(line,getter,setter); f.choices=values
                    choices[#choices+1]=f; return f
                end,
                addBooleanField=function(line,rect,getter,setter)
                    local f=field(line,getter,setter); booleans[#booleans+1]=f; return f
                end,
                addNumberField=function(line,rect,low,high,getter,setter)
                    local f=field(line,getter,setter); numbers[#numbers+1]=f; return f
                end,
                addButton=function(line,rect,options)
                    options.focus=noop; buttons[#buttons+1]=options; return options
                end,
                addStaticText=noop,
                openDialog=function(options) options.buttons[1].action(); return {} end,
            }
            local activePreferences
            context={session={},preferences={general={temperature_unit=0}},widgets={dashboard={
                setPreferences=function(value) activePreferences=value end,
                preferences=function() return activePreferences end,
                getPreference=function(key) return activePreferences and activePreferences[key] end,
                savePreference=function(key,value) activePreferences[key]=value end,
                clearCaches=noop,
            }}}
            local stubs = {
                ["lib/ini.lua"]={
                    load_ini_file=function() return settingsFile end,
                    save_ini_file=function(path,value) settingsFile=value; return true end,
                },
                ["lib/model_preferences.lua"]={
                    load=function(id) modelFiles[id]=modelFiles[id] or {}; return modelFiles[id],id end,
                    save=function(id,value) modelFiles[id]=value; return true end,
                },
                ["app/close_key.lua"]={shouldHandleClose=function() return false end},
                ["app/header.lua"]={build=function(title,callbacks)
                    headerTitle,headerCallbacks=title,callbacks
                    return {setSaveEnabled=noop,setReloadEnabled=noop,focusSave=noop,focusReload=noop,focusMenu=noop}
                end},
                ["app/tile_grid.lua"]={metrics=function() return 4,180,70,10,FONT_S end,
                    fitLabel=function(text) return text end},
                ["widgets/dashboard/context.lua"]=context,
                ["widgets/dashboard/engine.lua"]={
                    paint=function(widget,definition,state,phase)
                        paintedKey=definition.key or definition.dir:match("/([^/]+)$")
                        paintedPhase,paintedState=phase,state.fixturePhase
                        return true
                    end,
                    wakeup=function() return true end, reset=noop,
                },
                ["lib/stack_probe.lua"]={notePaint=noop},
                ["lib/msp_dataflash_erase.lua"]={}, ["lib/msp_dataflash_summary.lua"]={},
                ["lib/msp_battery_profile.lua"]={}, ["lib/battery_profile_index.lua"]={},
            }
            local cache={}
            function requireModule(path)
                if stubs[path] then return stubs[path] end
                if cache[path] then return cache[path] end
                cache[path]=assert(loadfile(path))()
                return cache[path]
            end
            package.loaded["rfsuite.lib.require"]=requireModule
            bus=requireModule("lib/bus.lua")
            local subscribe,unsubscribe=bus.subscribe,bus.unsubscribe
            bus.subscribe=function(topic,handler)
                activeSubscriptions=activeSubscriptions+1; return subscribe(topic,handler)
            end
            bus.unsubscribe=function(topic,handler)
                activeSubscriptions=activeSubscriptions-1; return unsubscribe(topic,handler)
            end
            store=requireModule("lib/settings_store.lua")
            function openPage(path)
                requireModule(path).open({
                    setWakeupHandler=function(fn) pageWakeup=fn end,
                    setCleanupHandler=function(fn) pageCleanup=fn end,
                    setPaintHandler=noop,setEventHandler=noop,
                })
            end
            function choiceId(field,label)
                for _,choice in ipairs(field.choices) do if choice[1]==label then return choice[2] end end
                error("missing choice: " .. label)
            end
            function findButton(label)
                for _,button in ipairs(buttons) do if button.text==label then return button end end
                error("missing tile: " .. label)
            end
            function flushBridge()
                for i=1,3 do now=now+0.6; bridge.wakeup() end
            end
        ''')

    @staticmethod
    def read(path):
        target = SOURCE / path
        return resolve_source(target.read_text(encoding="utf-8"), SOURCE) if target.is_file() else None

    def list_directory(self, path):
        target = SOURCE / path
        return self.lua.table_from(sorted(p.name for p in target.iterdir()) if target.is_dir() else [])

    def run(self, source):
        return self.lua.execute(source)


class RegistrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not THEMES:
            raise AssertionError("No Meridian/Cinder theme folder found in target checkout")
        for theme in THEMES:
            if theme not in ("meridian", "cinder"):
                raise AssertionError("Unexpected test theme: " + theme)
            if not (SOURCE / f"widgets/dashboard/themes/{theme}/init.lua").is_file():
                raise AssertionError("Missing selected theme: " + theme)

    def test_settings_normalization_retains_ids_aliases_and_distinct_phases(self):
        ui=RadioUI()
        for theme in THEMES:
            with self.subTest(theme=theme):
                ui.g.theme=theme
                ui.run('''
                    for _,value in ipairs({theme,"system/"..theme,"system/@"..theme}) do
                        local settings=store.withDefaults({dashboard={use_same_theme=false,
                            theme_preflight=value,theme_inflight="system/default",theme_postflight=value}})
                        assert(settings.dashboard.theme==theme)
                        assert(settings.dashboard.theme_preflight=="system/"..theme)
                        assert(settings.dashboard.theme_inflight=="system/default")
                        assert(settings.dashboard.theme_postflight=="system/"..theme)
                    end
                    local settings=store.withDefaults({dashboard={theme_preflight=theme,use_same_theme=true}})
                    assert(settings.dashboard.theme_inflight=="system/"..theme)
                    assert(settings.dashboard.theme_postflight=="system/"..theme)
                    local absent=store.withDefaults({dashboard={theme_preflight="system/does-not-exist"}}).dashboard.theme
                    assert(absent==(hasDiscovery and "does-not-exist" or "default"))
                ''')

    def test_picker_and_tiles_apply_names_and_minimum_resolution(self):
        for size,visible in (((800,480),True),((784,294),True),((783,294),False),((784,293),False)):
            with self.subTest(size=size):
                ui=RadioUI(*size)
                ui.run('openPage("app/pages/settings_dashboard_theme.lua")')
                self.assertEqual(len(ui.g.choices),6)
                for field in ui.g.choices.values():
                    labels=[choice[1] for choice in field.choices.values()]
                    for theme in THEMES:
                        self.assertEqual(labels.count(theme.title()),int(visible))
                ui.run('pageCleanup(); openPage("app/pages/settings_dashboard_settings.lua")')
                labels=[button.text for button in ui.g.buttons.values()]
                for theme in THEMES:
                    self.assertEqual(labels.count(theme.title()),int(visible))

    def test_picker_saves_global_and_model_phase_choices_and_same_theme(self):
        for theme in THEMES:
            with self.subTest(theme=theme):
                ui=RadioUI(); ui.g.theme,ui.g.label=theme,theme.title()
                ui.run('''
                    bus.publish("session.update",{connected=true,mcuId="craft"})
                    openPage("app/pages/settings_dashboard_theme.lua")
                    local id=choiceId(choices[1],label)
                    booleans[1].setter(false); booleans[2].setter(false)
                    choices[1].setter(id); choices[3].setter(id)
                    choices[5].setter(id)
                    assert(choices[5].getter()==id and choices[5].enabled)
                    headerCallbacks.onSave()
                    assert(settingsFile.dashboard.theme_preflight=="system/"..theme)
                    assert(settingsFile.dashboard.theme_inflight=="system/default")
                    assert(settingsFile.dashboard.theme_postflight=="system/"..theme)
                    assert(modelFiles.craft.dashboard.theme_preflight=="nil")
                    assert(modelFiles.craft.dashboard.theme_inflight=="system/"..theme)
                    assert(modelFiles.craft.dashboard.theme_postflight=="nil")
                    choices[4].setter(id); booleans[2].setter(true); booleans[1].setter(true)
                    headerCallbacks.onSave()
                    for _,phase in ipairs({"preflight","inflight","postflight"}) do
                        assert(settingsFile.dashboard["theme_"..phase]=="system/"..theme)
                        assert(modelFiles.craft.dashboard["theme_"..phase]=="system/"..theme)
                    end
                    choices[4].setter(0); headerCallbacks.onSave()
                    assert(modelFiles.craft.dashboard==nil,"disabled model override was retained")
                    pageCleanup(); assert(activeSubscriptions==0)
                ''')

    def test_configuration_tiles_save_only_the_active_theme_section(self):
        for theme in THEMES:
            with self.subTest(theme=theme):
                ui=RadioUI(); ui.g.theme,ui.g.label=theme,theme.title()
                ui.run('''
                    settingsFile["dashboard."..theme]={bec_warn=7,marker="keep"}
                    settingsFile["dashboard.unrelated"]={bec_warn=9,marker="untouched"}
                    openPage("app/pages/settings_dashboard_settings.lua")
                    findButton(label).press()
                    local field
                    for _,value in ipairs(numbers) do
                        if value.line.label=="BEC caution below" then field=value end
                    end
                    assert(field and field.getter()==70)
                    field.setter(80)
                    assert(settingsFile["dashboard."..theme].bec_warn==7,"saved before Save")
                    headerCallbacks.onSave()
                    assert(settingsFile["dashboard."..theme].bec_warn==8)
                    assert(settingsFile["dashboard."..theme].marker=="keep")
                    assert(settingsFile["dashboard.unrelated"].bec_warn==9)
                    assert(settingsFile["dashboard.unrelated"].marker=="untouched")
                    headerCallbacks.onBack()
                    assert(context.widgets.dashboard.preferences()==nil,"theme preferences leaked into grid")
                    findButton(label).press()
                    for _,value in ipairs(numbers) do
                        if value.line.label=="BEC caution below" then assert(value.getter()==80) end
                    end
                    pageCleanup()
                    assert(context.widgets.dashboard.preferences()==nil,"cleanup retained active preferences")
                ''')

    def test_dashboard_loader_selects_global_model_and_phase_paths(self):
        for theme in THEMES:
            with self.subTest(theme=theme):
                ui=RadioUI(); ui.g.theme=theme
                ui.run('''
                    phaseStubs=true
                    requireModule("widgets/dashboard.lua").init()
                    local widget=registeredWidget.create()
                    widget.settingsSnapshot=store.withDefaults({dashboard={use_same_theme=false,
                        theme_preflight="system/"..theme,theme_inflight="system/default",theme_postflight="system/"..theme}})
                    widget.settingsSnapshot["dashboard."..theme]={marker=theme}
                    widget.dashboardSettings=store.dashboard(widget.settingsSnapshot)
                    for _,phase in ipairs({"preflight","inflight","postflight"}) do
                        widget.flightmodeState=phase; registeredWidget.paint(widget)
                        local expected=phase=="inflight" and "default" or theme
                        assert(paintedKey==expected and paintedPhase==phase and paintedState==phase)
                        assert(loads["widgets/dashboard/themes/"..expected.."/"..phase..".lua"])
                    end
                    widget.modelDashboard={use_same_theme=true,theme_preflight="system/"..theme}
                    for _,phase in ipairs({"preflight","inflight","postflight"}) do
                        widget.flightmodeState=phase; registeredWidget.paint(widget)
                        assert(paintedKey==theme and paintedPhase==phase)
                        assert(context.widgets.dashboard.getPreference("marker")==theme)
                    end
                    widget.modelDashboard={use_same_theme=false,theme_inflight="nil"}
                    widget.flightmodeState="inflight"; registeredWidget.paint(widget)
                    assert(paintedKey=="default","disabled model phase did not use global choice")
                    registeredWidget.close(widget)
                ''')

    def test_bec_upper_boundary_round_trips_without_silent_value_change(self):
        for theme in THEMES:
            for entered in (149,150):
                with self.subTest(theme=theme, entered=entered):
                    ui=RadioUI(); ui.g.theme,ui.g.label,ui.g.entered=theme,theme.title(),entered
                    ui.run('''
                        settingsFile["dashboard."..theme]={bec_warn=15,bec_min=14.8,marker="keep"}
                        openPage("app/pages/settings_dashboard_settings.lua")
                        findButton(label).press()
                        for _,field in ipairs(numbers) do
                            if field.line.label=="BEC critical" then field.setter(entered) end
                        end
                        headerCallbacks.onSave()
                        assert(settingsFile["dashboard."..theme].bec_min==14.8)
                        assert(settingsFile["dashboard."..theme].bec_warn==15)
                        assert(settingsFile["dashboard."..theme].marker=="keep")
                        headerCallbacks.onBack(); findButton(label).press()
                        local checked=false
                        for _,field in ipairs(numbers) do
                            if field.line.label=="BEC critical" then
                                assert(field.getter()==148,"saved critical value changed after reopening")
                                checked=true
                            end
                        end
                        assert(checked)
                        headerCallbacks.onSave()
                        assert(settingsFile["dashboard."..theme].bec_min==14.8)
                        assert(settingsFile["dashboard."..theme].bec_warn==15)
                    ''')

    @unittest.skipUnless(HAS_BRIDGE,"Standalone theme branch intentionally has no Theme Bridge")
    def test_bridge_uses_metadata_without_phase_loads_and_releases_cache(self):
        for theme in THEMES:
            with self.subTest(theme=theme):
                ui=RadioUI(); ui.g.theme=theme
                ui.run('''
                    bridge=requireModule("app/theme_bridge.lua")
                    local settings=store.withDefaults({dashboard={theme_preflight=theme}})
                    bridge.open(settings)
                    local init="widgets/dashboard/themes/"..theme.."/init.lua"
                    assert(loads[init]==(hasDiscovery and 1 or nil),"unexpected metadata discovery count during open")
                    flushBridge()
                    local expected=assert(load(readSource(init)))().appTheme
                    local palette=bridge.getPalette()
                    assert(palette.path=="system/"..theme and palette.name==expected.name)
                    assert(palette.accent==lcd.RGB(table.unpack(expected.accent)))
                    assert(activeSubscriptions==2)
                    local count=loads[init]
                    for i=1,10 do bridge.paintBackground(); bridge.paintChrome(); flushBridge() end
                    assert(loads[init]==count and bridge.getPalette()==palette)
                    for path in pairs(loads) do
                        assert(not path:match("themes/.+/preflight%.lua$")
                            and not path:match("themes/.+/inflight%.lua$")
                            and not path:match("themes/.+/postflight%.lua$"),"Bridge loaded phase: "..path)
                    end
                    bridge.clearCache(); assert(activeSubscriptions==0 and bridge.getPalette()==nil)
                    bus.publish("session.update",{connected=false}); bus.publish("settings.update",settings)
                    flushBridge(); assert(bridge.getPalette()==nil and loads[init]==count)
                    bridge.open(settings); flushBridge()
                    assert(loads[init]==count+(hasDiscovery and 0 or 1),"unexpected metadata reload on reopen")
                    bridge.clearCache(); assert(activeSubscriptions==0)
                ''')

    @unittest.skipUnless(HAS_BRIDGE,"Standalone theme branch intentionally has no Theme Bridge")
    def test_bridge_follows_phase_and_model_overrides_for_new_themes(self):
        for theme in THEMES:
            with self.subTest(theme=theme):
                ui=RadioUI(); ui.g.theme=theme
                ui.run('''
                    bridge=requireModule("app/theme_bridge.lua")
                    local settings=store.withDefaults({dashboard={use_same_theme=false,
                        theme_preflight="system/default",theme_inflight="system/"..theme,
                        theme_postflight="system/"..theme}})
                    bridge.open(settings); flushBridge()
                    assert(bridge.getPalette().path=="system/default")
                    bus.publish("session.update",{connected=true,isArmed=true,governorState=4,
                        timerSession=30,timerFlightCounted=true,mcuId="craft"})
                    flushBridge()
                    assert(bridge.getPalette().path=="system/"..theme and bridge.getPalette().phase=="inflight")
                    bus.publish("session.update",{connected=false,timerSession=0})
                    flushBridge()
                    assert(bridge.getPalette().path=="system/"..theme and bridge.getPalette().phase=="postflight")
                    modelFiles.other={dashboard={use_same_theme=true,theme_preflight="system/"..theme}}
                    bus.publish("session.update",{connected=true,isArmed=false,mcuId="other"})
                    flushBridge()
                    assert(bridge.getPalette().path=="system/"..theme and bridge.getPalette().phase=="preflight")
                    bridge.clearCache(); assert(activeSubscriptions==0)
                ''')


if __name__=="__main__":
    unittest.main()
