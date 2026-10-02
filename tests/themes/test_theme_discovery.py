"""Automatic theme discovery through actual Suite registry and UI modules.

Run: python -m unittest discover -s tests/themes -p test_theme_discovery.py
Requires the existing Lupa test dependency. The shared RadioUI supplies the
in-memory form, settings, bus and engine fixture; this file adds an ETHOS-style
filesystem overlay. No fixture theme files are written into the repository.
These are desktop integration checks, not physical-radio acceptance.
"""
import unittest

from test_meridian_cinder_registration import RadioUI, SOURCE


SYSTEM_ROOT = "widgets/dashboard/themes"
USER_ROOT = "SCRIPTS:/rfsuite.user/dashboard"
PERSONAL = {
    "aegis": ("bastion", "Bastion"),
    "america250": ("america250", "America 250"),
    "libertyops250": ("libertyops250", "Liberty Ops 250"),
    "mwrc": ("mwrc", "MWRC"),
    "singularity": ("singularity", "Singularity"),
    "zafira": ("zafira", "Zafira"),
    "vantage": ("vantage", "Vantage"),
    "inkhalo": ("inkhalo", "Ink & Halo"),
    "meridian": ("meridian", "Meridian"),
    "cinder": ("cinder", "Cinder"),
}
PHASES = ("preflight", "inflight", "postflight")


class DiscoveryRadio(RadioUI):
    def __init__(self, width=800, height=480):
        self.sources = {}
        self.hidden = set()
        self.listings = {}
        self.scans = []
        self.reads = []
        super().__init__(width, height)
        self.g.listDirectory = self.list_directory
        self.run('''
            system.listFiles = function(path) return listDirectory(path) end
            registry = requireModule("lib/dashboard_themes.lua")
        ''')

    def read(self, path):
        self.reads.append(path)
        if path in self.hidden:
            return None
        if path in self.sources:
            return self.sources[path]
        if path.startswith("SCRIPTS:"):
            return None
        target = SOURCE / path
        return target.read_text(encoding="utf-8") if target.is_file() else None

    def list_directory(self, path):
        path = path.rstrip("/")
        self.scans.append(path)
        if path in self.listings:
            value = self.listings[path]
            if isinstance(value, Exception):
                raise value
            return self.lua.table_from(value) if isinstance(value, list) else value
        entries = set()
        if not path.startswith("SCRIPTS:"):
            target = SOURCE / path
            if target.is_dir():
                entries.update(p.name for p in target.iterdir() if (path + "/" + p.name) not in self.hidden)
        prefix = path + "/"
        entries.update(name[len(prefix):].split("/", 1)[0] for name in self.sources if name.startswith(prefix))
        return self.lua.table_from(sorted(entries))

    def add_theme(self, source, folder, label="Fixture Theme", *, configure=True,
                  palette=True, phase_files=None, minimum=(320, 200), compiled=False):
        directory = (USER_ROOT if source == "user" else SYSTEM_ROOT) + "/" + folder
        phase_files = phase_files or {phase: phase + ".lua" for phase in PHASES}
        fields = [f'name="{label}"', f'minResolution={{x={minimum[0]},y={minimum[1]}}}']
        fields += [f'{phase}="{filename}"' for phase, filename in phase_files.items()]
        if configure:
            fields.append('configure="configure.lua"')
        if palette:
            fields.append(f'appTheme={{name="{label}",accent={{17,81,149}},background={{8,14,20}}}}')
        init = "metadataRuns=(metadataRuns or 0)+1; return {" + ",".join(fields) + "}"
        self.sources[directory + ("/init.luac" if compiled else "/init.lua")] = init
        for phase, filename in phase_files.items():
            suffix = filename + "c" if compiled and filename.endswith(".lua") else filename
            self.sources[directory + "/" + suffix] = (
                'phaseRuns=(phaseRuns or 0)+1; return {fixturePhase="' + phase + '"}'
            )
        if configure:
            self.sources[directory + ("/configure.luac" if compiled else "/configure.lua")] = '''
                local dashboard=requireModule("widgets/dashboard/context.lua").widgets.dashboard
                local value
                return {configure=function()
                    value=dashboard.getPreference("fixture_value") or 7
                    local panel=form.addExpansionPanel("Fixture")
                    form.addNumberField(panel:addLine("Fixture value"),nil,0,100,
                        function() return value end,function(v) value=v end)
                end,write=function() dashboard.savePreference("fixture_value",value) end}
            '''
        return directory

    def descriptors(self):
        return {item.path: item for item in self.run("return registry.list()").values()}

    def activity(self):
        return tuple(self.scans), tuple(self.reads)


class ThemeDiscoveryTests(unittest.TestCase):
    def test_new_system_and_user_folders_are_discovered_without_registration(self):
        radio = DiscoveryRadio()
        system_dir = radio.add_theme("system", "fieldnote", "Field Note")
        user_dir = radio.add_theme("user", "fieldnote", "Field Note")
        themes = radio.descriptors()
        for path, directory, label in (("system/fieldnote", system_dir, "Field Note"),
                                       ("user/fieldnote", user_dir, "Field Note (User)")):
            with self.subTest(path=path):
                theme = themes[path]
                self.assertEqual((theme.directory, theme.label), (directory, label))
                self.assertEqual(theme.configure, directory + "/configure.lua")
                self.assertEqual(theme.icon, directory + "/icon.png")
                self.assertFalse(theme.builtin)
        self.assertIsNone(radio.g.phaseRuns, "discovery executed flight phase files")
        self.assertFalse(any(path.endswith("/preflight.lua") for path in radio.reads))
        radio.run('''
            assert(registry.get("system/fieldnote") ~= registry.get("user/fieldnote"))
            openPage("app/pages/settings_dashboard_theme.lua")
            assert(choiceId(choices[1],"Field Note") ~= choiceId(choices[1],"Field Note (User)"))
            pageCleanup(); openPage("app/pages/settings_dashboard_settings.lua")
            assert(findButton("Field Note") and findButton("Field Note (User)"))
        ''')

    def test_invalid_init_unsafe_paths_and_missing_phases_are_skipped(self):
        radio = DiscoveryRadio()
        for folder, source in (("badsyntax", "return {"), ("badreturn", "return 19"),
                               ("raises", 'error("broken metadata")')):
            directory = radio.add_theme("user", folder)
            radio.sources[directory + "/init.lua"] = source
        radio.sources[USER_ROOT + "/noinit/preflight.lua"] = "return {}"
        directory = radio.add_theme("user", "missingphase")
        del radio.sources[directory + "/postflight.lua"]
        directory = radio.add_theme("user", "escapingphase")
        radio.sources[directory + "/init.lua"] = 'return {name="Unsafe",preflight="../outside.lua",inflight="inflight.lua",postflight="postflight.lua"}'
        radio.add_theme("user", "valid")
        radio.add_theme("user", "nil", "Reserved name")
        radio.listings[USER_ROOT] = ["valid", "valid", "nil", ".", "..", "../outside", "a/b", "C:\\outside",
                                    "badsyntax", "badreturn", "raises", "noinit", "missingphase", "escapingphase"]
        themes = radio.descriptors()
        self.assertEqual([path for path in themes if path.startswith("user/")], ["user/valid"])
        self.assertIsNone(radio.g.phaseRuns)
        self.assertFalse(any("../" in path or "C:\\outside" in path for path in radio.reads))
        self.assertNotIn(USER_ROOT + "/nil/init.lua", radio.reads)

    def test_compiled_only_listing_and_optional_configuration(self):
        radio = DiscoveryRadio()
        compiled_dir = radio.add_theme("user", "compiled", "Compiled", compiled=True)
        radio.add_theme("user", "displayonly", "Display Only", configure=False, palette=False)
        themes = radio.descriptors()
        self.assertIn("user/compiled", themes)
        self.assertIsNotNone(themes["user/compiled"].configure)
        self.assertIsNone(themes["user/displayonly"].configure)
        self.assertIsNone(themes["user/displayonly"].appTheme)
        radio.run('''
            openPage("app/pages/settings_dashboard_theme.lua")
            assert(choiceId(choices[1],"Display Only (User)"))
            pageCleanup(); openPage("app/pages/settings_dashboard_settings.lua")
            assert(findButton("Compiled (User)"))
            for _,button in ipairs(buttons) do assert(button.text~="Display Only (User)") end
            findButton("Compiled (User)").press()
            numbers[1].setter(19); headerCallbacks.onSave(); headerCallbacks.onBack()
            findButton("Compiled (User)").press(); assert(numbers[1].getter()==19)
            pageCleanup()
            requireModule("widgets/dashboard.lua").init()
            local widget=registeredWidget.create()
            widget.settingsSnapshot=store.withDefaults({dashboard={use_same_theme=true,theme_preflight="user/compiled"}})
            widget.dashboardSettings=store.dashboard(widget.settingsSnapshot)
            for _,phase in ipairs({"preflight","inflight","postflight"}) do
                widget.flightmodeState=phase; registeredWidget.paint(widget)
                assert(paintedPhase==phase and paintedState==phase)
            end
            registeredWidget.close(widget)
        ''')
        # The fixture stores Lua text at .luac paths to exercise path selection,
        # not the transmitter's bytecode ABI or its Lua compiler.
        for filename in ("init.luac", "configure.luac", "preflight.luac", "inflight.luac", "postflight.luac"):
            self.assertIn(compiled_dir + "/" + filename, radio.reads)
        self.assertNotIn(compiled_dir + "/init.lua", radio.reads)

    def test_normalization_is_syntax_only_and_keeps_saved_absent_selection(self):
        radio = DiscoveryRadio()
        before = radio.activity()
        radio.run('''
            for _,value in ipairs({"newtheme","@newtheme","system/newtheme","system/@newtheme"}) do
                assert(registry.normalize(value)=="system/newtheme")
                assert(registry.key(value)=="newtheme")
            end
            assert(registry.normalize("user/newtheme")=="user/newtheme")
            assert(registry.key("user/newtheme")=="user/newtheme")
            for _,value in ipairs({"bastion","aegis","system/bastion","system/@aegis"}) do
                assert(registry.normalize(value)=="system/aegis")
                assert(registry.key(value)=="aegis")
            end
            assert(registry.normalize("user/bastion")=="user/bastion")
            for _,value in ipairs({"", "nil", "user/nil", "../outside", "system/../outside", "user/a/b", "other/theme", "system/", "a"..string.char(92).."b"}) do
                assert(registry.normalize(value)==nil,value)
            end
            assert(registry.normalize(false)==nil and registry.normalize(42)==nil)
            local settings=store.withDefaults({dashboard={use_same_theme=false,
                theme_preflight="system/not-installed",theme_inflight="user/not-installed",theme_postflight="system/bastion"}})
            assert(settings.dashboard.theme_preflight=="system/not-installed")
            assert(settings.dashboard.theme_inflight=="user/not-installed")
            assert(settings.dashboard.theme_postflight=="system/aegis")
            store.save(settings)
            local reopened=store.load()
            assert(reopened.dashboard.theme_preflight=="system/not-installed")
            assert(reopened.dashboard.theme_inflight=="user/not-installed")
        ''')
        self.assertEqual(radio.activity(), before, "normalizing settings touched theme files")

    def test_saving_model_override_keeps_absent_global_theme_selection(self):
        radio = DiscoveryRadio()
        radio.run('''
            settingsFile.dashboard={use_same_theme=true,theme_preflight="user/temporarily-absent"}
            bus.publish("session.update",{connected=true,mcuId="craft"})
            openPage("app/pages/settings_dashboard_theme.lua")
            choices[4].setter(choiceId(choices[4],"Bastion"))
            headerCallbacks.onSave()
            for _,phase in ipairs({"preflight","inflight","postflight"}) do
                assert(settingsFile.dashboard["theme_"..phase]=="user/temporarily-absent",
                    "saving model override replaced an unavailable global selection")
            end
            assert(modelFiles.craft.dashboard.theme_preflight=="system/aegis")
            pageCleanup()
        ''')

    def test_valid_legacy_aegis_folder_is_used_when_bastion_metadata_is_broken(self):
        radio = DiscoveryRadio()
        legacy_dir = radio.add_theme("system", "aegis", "Legacy fixture")
        radio.sources[SYSTEM_ROOT + "/bastion/init.lua"] = 'error("incomplete rename installation")'
        themes = radio.descriptors()
        self.assertEqual(themes["system/aegis"].directory, legacy_dir)
        self.assertNotIn("system/bastion", themes)
        radio.run('''
            bridge=requireModule("app/theme_bridge.lua")
            settingsFile.dashboard={use_same_theme=true,theme_preflight="system/bastion"}
            bridge.open(store.load()); flushBridge()
            assert(bridge.getPalette().path=="system/aegis")
            assert(bridge.getPalette().name=="Legacy fixture")
        ''')

    def test_all_ten_personal_themes_are_selectable_and_load_every_phase(self):
        radio = DiscoveryRadio()
        themes = radio.descriptors()
        radio.run('openPage("app/pages/settings_dashboard_theme.lua")')
        labels = [value[1] for value in radio.g.choices[1].choices.values()]
        for key, (directory, label) in PERSONAL.items():
            with self.subTest(theme=key):
                self.assertEqual(labels.count(label), 1)
                self.assertEqual(themes["system/" + key].directory, SYSTEM_ROOT + "/" + directory)
                radio.g.selected, radio.g.physical = key, directory
                radio.run('''
                    phaseStubs=true
                    requireModule("widgets/dashboard.lua").init()
                    local widget=registeredWidget.create()
                    widget.settingsSnapshot=store.withDefaults({dashboard={use_same_theme=true,theme_preflight="system/"..selected}})
                    widget.dashboardSettings=store.dashboard(widget.settingsSnapshot)
                    for _,phase in ipairs({"preflight","inflight","postflight"}) do
                        widget.flightmodeState=phase; registeredWidget.paint(widget)
                        assert(paintedPhase==phase and paintedState==phase)
                        assert(loads["widgets/dashboard/themes/"..physical.."/"..phase..".lua"])
                    end
                    registeredWidget.close(widget)
                ''')
        radio.run('pageCleanup(); openPage("app/pages/settings_dashboard_settings.lua")')
        tile_labels = [button.text for button in radio.g.buttons.values()]
        for _, label in PERSONAL.values():
            self.assertEqual(tile_labels.count(label), 1)

    def test_resolution_filter_changes_without_restarting_discovery(self):
        radio = DiscoveryRadio(800, 480)
        radio.add_theme("user", "largeonly", "Large Only", minimum=(784, 294))
        for width, height, visible in ((800, 480, True), (783, 294, False), (784, 293, False), (784, 294, True)):
            with self.subTest(size=(width, height)):
                radio.g.width, radio.g.height = width, height
                radio.run('openPage("app/pages/settings_dashboard_theme.lua")')
                labels = [value[1] for value in radio.g.choices[1].choices.values()]
                self.assertEqual("Large Only (User)" in labels, visible)
                radio.run('pageCleanup(); openPage("app/pages/settings_dashboard_settings.lua")')
                labels = [button.text for button in radio.g.buttons.values()]
                self.assertEqual("Large Only (User)" in labels, visible)
                radio.run('pageCleanup()')

    def test_picker_saves_system_user_and_model_phase_choices(self):
        radio = DiscoveryRadio()
        radio.add_theme("system", "fieldnote", "Field Note")
        radio.add_theme("user", "fieldnote", "Field Note")
        radio.run('''
            bus.publish("session.update",{connected=true,mcuId="craft"})
            openPage("app/pages/settings_dashboard_theme.lua")
            booleans[1].setter(false); booleans[2].setter(false)
            local systemId=choiceId(choices[1],"Field Note")
            local userId=choiceId(choices[1],"Field Note (User)")
            choices[1].setter(systemId); choices[2].setter(userId); choices[3].setter(systemId)
            choices[5].setter(userId)
            headerCallbacks.onSave()
            assert(settingsFile.dashboard.theme_preflight=="system/fieldnote")
            assert(settingsFile.dashboard.theme_inflight=="user/fieldnote")
            assert(settingsFile.dashboard.theme_postflight=="system/fieldnote")
            assert(modelFiles.craft.dashboard.theme_inflight=="user/fieldnote")
            pageCleanup(); openPage("app/pages/settings_dashboard_theme.lua")
            assert(choices[1].getter()==choiceId(choices[1],"Field Note"))
            assert(choices[2].getter()==choiceId(choices[2],"Field Note (User)"))
            assert(choices[5].getter()==choiceId(choices[5],"Field Note (User)"))
            choices[4].setter(choiceId(choices[4],"Field Note (User)")); booleans[2].setter(true)
            headerCallbacks.onSave()
            for _,phase in ipairs({"preflight","inflight","postflight"}) do
                assert(modelFiles.craft.dashboard["theme_"..phase]=="user/fieldnote")
            end
            choices[4].setter(0); headerCallbacks.onSave()
            assert(modelFiles.craft.dashboard==nil)
            pageCleanup(); assert(activeSubscriptions==0)
        ''')

    def test_configuration_round_trip_keeps_user_system_and_bastion_preferences_separate(self):
        radio = DiscoveryRadio()
        radio.add_theme("system", "fieldnote", "Field Note")
        radio.add_theme("user", "fieldnote", "Field Note")
        radio.run('''
            settingsFile["dashboard.fieldnote"]={fixture_value=11,marker="system"}
            settingsFile["dashboard.user/fieldnote"]={fixture_value=22,marker="user"}
            settingsFile["dashboard.aegis"]={rpm_max=3450,bec_warn=7.8,marker="legacy"}
            openPage("app/pages/settings_dashboard_settings.lua")
            findButton("Field Note (User)").press()
            assert(numbers[1].getter()==22); numbers[1].setter(33)
            assert(settingsFile["dashboard.user/fieldnote"].fixture_value==22)
            headerCallbacks.onSave(); headerCallbacks.onBack()
            findButton("Field Note (User)").press(); assert(numbers[1].getter()==33)
            headerCallbacks.onBack(); findButton("Field Note").press()
            assert(numbers[1].getter()==11); headerCallbacks.onBack()
            findButton("Bastion").press()
            for _,field in ipairs(numbers) do
                if field.line.label=="Maximum headspeed" then assert(field.getter()==3450); field.setter(3800) end
            end
            headerCallbacks.onSave()
            assert(settingsFile["dashboard.aegis"].rpm_max==3800)
            assert(settingsFile["dashboard.aegis"].marker=="legacy")
            assert(settingsFile["dashboard.bastion"]==nil)
            assert(settingsFile["dashboard.fieldnote"].fixture_value==11)
            assert(settingsFile["dashboard.user/fieldnote"].fixture_value==33)
            assert(settingsFile["dashboard.user/fieldnote"].marker=="user")
            pageCleanup(); assert(context.widgets.dashboard.preferences()==nil)
        ''')

    def test_loader_resolves_custom_phase_names_namespaces_and_missing_fallback(self):
        radio = DiscoveryRadio()
        radio.add_theme("system", "fieldnote", "Field Note")
        user_dir = radio.add_theme("user", "fieldnote", "Field Note",
                                   phase_files=dict(zip(PHASES, ("launch.lua", "flight.lua", "report.lua"))))
        radio.g.expected_user = user_dir
        radio.run('''
            requireModule("widgets/dashboard.lua").init()
            local widget=registeredWidget.create()
            widget.settingsSnapshot=store.withDefaults({dashboard={use_same_theme=true,theme_preflight="system/fieldnote"}})
            widget.settingsSnapshot["dashboard.fieldnote"]={marker="system"}
            widget.settingsSnapshot["dashboard.user/fieldnote"]={marker="user"}
            widget.dashboardSettings=store.dashboard(widget.settingsSnapshot)
            for _,phase in ipairs({"preflight","inflight","postflight"}) do
                widget.flightmodeState=phase; registeredWidget.paint(widget)
                assert(paintedPhase==phase and paintedState==phase)
                assert(context.widgets.dashboard.getPreference("marker")=="system")
            end
            widget.modelDashboard={use_same_theme=true,theme_preflight="user/fieldnote"}
            for _,phase in ipairs({"preflight","inflight","postflight"}) do
                widget.flightmodeState=phase; registeredWidget.paint(widget)
                assert(paintedPhase==phase and paintedState==phase)
                assert(context.widgets.dashboard.getPreference("marker")=="user")
            end
            assert(loads[expected_user.."/launch.lua"] and loads[expected_user.."/flight.lua"] and loads[expected_user.."/report.lua"])
            phaseStubs=true
            widget.modelDashboard={use_same_theme=true,theme_preflight="user/not-installed"}
            registeredWidget.paint(widget); assert(paintedKey=="default")
            assert(widget.modelDashboard.theme_preflight=="user/not-installed")
            registeredWidget.close(widget)
        ''')

    def test_bridge_uses_arbitrary_metadata_and_does_not_execute_phases(self):
        radio = DiscoveryRadio()
        radio.add_theme("system", "fieldnote", "Field Note")
        radio.add_theme("user", "fieldnote", "Field Note")
        radio.run('''
            bridge=requireModule("app/theme_bridge.lua")
            settingsFile.dashboard={use_same_theme=true,theme_preflight="user/fieldnote"}
            bridge.open(store.load()); flushBridge()
            local palette=bridge.getPalette()
            assert(palette.path=="user/fieldnote")
            assert(palette.name=="Field Note" and palette.accent==lcd.RGB(17,81,149))
            settingsFile.dashboard.theme_preflight="system/fieldnote"
            bus.publish("settings.update",store.load()); flushBridge()
            assert(bridge.getPalette().path=="system/fieldnote")
            assert(bridge.getPalette().accent==lcd.RGB(17,81,149))
            assert(phaseRuns==nil)
        ''')
        before = radio.activity()
        radio.run('''
            for i=1,8 do flushBridge(); bridge.paintBackground(); bridge.paintChrome() end
            bridge.clearCache(); bridge.open(store.load()); flushBridge()
            assert(bridge.getPalette().path=="system/fieldnote")
            bridge.clearCache(); assert(activeSubscriptions==0)
        ''')
        self.assertEqual(radio.activity(), before, "Bridge reopened or repainted by rescanning metadata")

    def test_discovery_and_stable_widget_paths_do_not_repeat_io(self):
        radio = DiscoveryRadio()
        radio.add_theme("user", "fieldnote", "Field Note")
        radio.run('''
            firstList=registry.list(); firstTheme=registry.get("user/fieldnote")
            requireModule("widgets/dashboard.lua").init()
            widget=registeredWidget.create()
            widget.settingsSnapshot=store.withDefaults({dashboard={use_same_theme=true,theme_preflight="user/fieldnote"}})
            widget.dashboardSettings=store.dashboard(widget.settingsSnapshot)
            widget.flightmodeState="inflight"; registeredWidget.wakeup(widget); registeredWidget.paint(widget)
            openPage("app/pages/settings_dashboard_theme.lua"); pageCleanup()
            openPage("app/pages/settings_dashboard_settings.lua"); pageCleanup()
        ''')
        before = radio.activity()
        radio.run('''
            for i=1,20 do
                assert(registry.list()==firstList and registry.get("user/fieldnote")==firstTheme)
                assert(registry.get("user/absent")==nil)
                now=now+0.25; registeredWidget.wakeup(widget)
                registeredWidget.paint(widget)
                openPage("app/pages/settings_dashboard_theme.lua"); pageCleanup()
                openPage("app/pages/settings_dashboard_settings.lua"); pageCleanup()
            end
        ''')
        self.assertEqual(radio.activity(), before)
        radio.add_theme("user", "installedlater", "Installed Later")
        self.assertIsNone(radio.run('return registry.get("user/installedlater")'), "cached registry unexpectedly rescanned")
        restarted = DiscoveryRadio()
        restarted.add_theme("user", "installedlater", "Installed Later")
        self.assertIsNotNone(restarted.run('return registry.get("user/installedlater")'))

    def test_builtin_discovery_avoids_executing_full_dashboard_metadata(self):
        radio = DiscoveryRadio()
        radio.descriptors()
        for folder in ("default", "aerc", "claude", "helihud"):
            self.assertNotIn(SYSTEM_ROOT + "/" + folder + "/init.lua", radio.reads)
        self.assertTrue(radio.run('return registry.get("system/default").builtin'))

    def test_failed_filesystem_listing_is_bounded_and_keeps_default(self):
        for failure in (None, RuntimeError("radio volume unavailable")):
            with self.subTest(failure=type(failure).__name__):
                radio = DiscoveryRadio()
                radio.listings[USER_ROOT] = failure
                themes = radio.descriptors()
                self.assertIn("system/default", themes)
                before = radio.activity()
                radio.run('for i=1,10 do assert(registry.get("user/absent")==nil); registry.list() end')
                self.assertEqual(radio.activity(), before)

    def test_broken_phase_falls_back_without_repeated_loads_or_uncaught_callbacks(self):
        for phase in PHASES:
            for broken in ("return {", 'error("broken phase")', "return 19"):
                with self.subTest(phase=phase, source=broken):
                    radio = DiscoveryRadio()
                    directory = radio.add_theme("user", "brokenphase", "Broken Phase")
                    radio.sources[directory + "/" + phase + ".lua"] = broken
                    radio.g.requested_phase = phase
                    radio.run('''
                        phaseStubs=true
                        requireModule("widgets/dashboard.lua").init()
                        widget=registeredWidget.create()
                        widget.settingsSnapshot=store.withDefaults({dashboard={use_same_theme=true,
                            theme_preflight="user/brokenphase"}})
                        widget.dashboardSettings=store.dashboard(widget.settingsSnapshot)
                        widget.flightmodeState=requested_phase
                        registeredWidget.wakeup(widget); registeredWidget.paint(widget)
                        assert(paintedKey=="default" and paintedPhase==requested_phase,
                            "broken optional phase did not select Default")
                        assert(widget.dashboardSettings.theme_preflight=="user/brokenphase")
                    ''')
                    before = radio.activity()
                    radio.run('''
                        for i=1,12 do
                            now=now+0.25; registeredWidget.wakeup(widget); registeredWidget.paint(widget)
                            assert(paintedKey=="default" and paintedPhase==requested_phase)
                        end
                        registeredWidget.close(widget)
                    ''')
                    self.assertEqual(radio.activity(), before, "failed phase was retried every frame")

    def test_metadata_corrupted_after_discovery_uses_cached_runtime_fallback(self):
        for broken in ("return {", 'error("metadata changed after discovery")', "return false"):
            with self.subTest(source=broken):
                radio = DiscoveryRadio()
                directory = radio.add_theme("user", "brokeninit", "Broken Init")
                self.assertIn("user/brokeninit", radio.descriptors())
                radio.sources[directory + "/init.lua"] = broken
                radio.run('''
                    phaseStubs=true
                    requireModule("widgets/dashboard.lua").init()
                    widget=registeredWidget.create()
                    widget.settingsSnapshot=store.withDefaults({dashboard={use_same_theme=true,
                        theme_preflight="user/brokeninit"}})
                    widget.dashboardSettings=store.dashboard(widget.settingsSnapshot)
                    widget.flightmodeState="inflight"
                    registeredWidget.wakeup(widget); registeredWidget.paint(widget)
                    assert(paintedKey=="default")
                ''')
                before = radio.activity()
                radio.run('''
                    for i=1,12 do
                        now=now+0.25; registeredWidget.wakeup(widget); registeredWidget.paint(widget)
                        assert(paintedKey=="default")
                    end
                    registeredWidget.close(widget)
                ''')
                self.assertEqual(radio.activity(), before, "bad optional init was reread after fallback")

    def test_configuration_failures_restore_grid_and_clear_theme_state(self):
        for broken in ("return {", 'error("broken configure load")', "return 19",
                       'return {configure=function() form.clear(); error("broken configure callback") end}'):
            with self.subTest(source=broken):
                radio = DiscoveryRadio()
                directory = radio.add_theme("user", "brokenconfig", "Broken Config")
                radio.add_theme("user", "workingconfig", "Working Config")
                radio.sources[directory + "/configure.lua"] = broken
                radio.run('''
                    messages={}
                    form.addStaticText=function(line,rect,text) messages[#messages+1]=text end
                    settingsFile["dashboard.user/brokenconfig"]={fixture_value=41,marker="untouched"}
                    requireModule("app/pages/settings_dashboard_settings.lua").open({
                        setWakeupHandler=function(fn) pageWakeup=fn end,
                        setPaintHandler=function(fn) pagePaint=fn end,
                        setEventHandler=function(fn) pageEvent=fn end,
                        setCleanupHandler=function(fn) pageCleanup=fn end,
                    })
                    local gridCleanup=pageCleanup
                    findButton("Broken Config (User)").press()
                    assert(findButton("Working Config (User)"),"configuration error discarded the grid")
                    assert(context.widgets.dashboard.preferences()==nil,"failed page retained theme preferences")
                    assert(pageWakeup==nil and pagePaint==nil,"failed page retained runtime handlers")
                    assert(type(pageEvent)=="function" and type(pageCleanup)=="function")
                    assert(pageCleanup==gridCleanup,"failed configuration cleanup replaced grid ownership")
                    assert(headerCallbacks.onSave==nil,"failed page retained its Save action")
                    local reported=false
                    for _,text in ipairs(messages) do
                        if text=="@i18n(app.msg_load_failed_title)@" then reported=true end
                    end
                    assert(reported,"configuration failure was hidden without a message")
                    assert(settingsFile["dashboard.user/brokenconfig"].fixture_value==41)
                    assert(settingsFile["dashboard.user/brokenconfig"].marker=="untouched")
                    findButton("Working Config (User)").press()
                    assert(numbers[1].getter()==7); numbers[1].setter(27); headerCallbacks.onSave()
                    assert(settingsFile["dashboard.user/workingconfig"].fixture_value==27)
                    pageCleanup(); assert(context.widgets.dashboard.preferences()==nil)
                ''')

    def test_phase_load_receives_selected_or_fallback_preferences(self):
        for state in ("valid", "badinit", "badphase"):
            with self.subTest(state=state):
                radio = DiscoveryRadio()
                directory = radio.add_theme("user", "loadprefs", "Load Preferences")
                for phase in PHASES:
                    body = ('phasePreference=requireModule("widgets/dashboard/context.lua").widgets.dashboard.getPreference("marker"); '
                            'return {fixturePhase="' + phase + '"}')
                    radio.sources[directory + "/" + phase + ".lua"] = body
                    radio.sources[SYSTEM_ROOT + "/default/" + phase + ".lua"] = body
                radio.descriptors()
                if state == "badinit":
                    radio.sources[directory + "/init.lua"] = 'error("broken optional init")'
                elif state == "badphase":
                    radio.sources[directory + "/preflight.lua"] = 'error("broken optional phase")'
                radio.g.expected_preference = "user" if state == "valid" else "default"
                radio.run('''
                    requireModule("widgets/dashboard.lua").init()
                    widget=registeredWidget.create()
                    widget.settingsSnapshot=store.withDefaults({dashboard={use_same_theme=true,
                        theme_preflight="user/loadprefs"}})
                    widget.settingsSnapshot["dashboard.user/loadprefs"]={marker="user"}
                    widget.settingsSnapshot["dashboard.default"]={marker="default"}
                    widget.dashboardSettings=store.dashboard(widget.settingsSnapshot)
                    for _,phase in ipairs({"preflight","inflight","postflight"}) do
                        widget.flightmodeState=phase
                        registeredWidget.wakeup(widget); registeredWidget.paint(widget)
                        assert(phasePreference==expected_preference,
                            "phase module executed before its theme preferences were active")
                        assert(context.widgets.dashboard.getPreference("marker")==expected_preference)
                    end
                    registeredWidget.close(widget)
                ''')


if __name__ == "__main__":
    unittest.main()
