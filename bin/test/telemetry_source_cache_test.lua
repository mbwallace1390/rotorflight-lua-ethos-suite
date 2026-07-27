--[[
  telemetry.getSensorSource() cache churn while the transport is unknown.

  getSensorSource() resolves the active source mode on every single lookup, and
  it is called constantly by widgets, dashboard objects and app pages. When the
  mode is nil -- no link yet, or the link just dropped -- setActiveSourceMode()
  used to run clearRuntimeCaches() unconditionally, and that function allocates
  five tables plus a weak metatable:

      sensors = setmetatable({}, {__mode = "v"})
      hot_list, hot_index = {}, {}
      lastSensorValues = {}

  So every lookup during a disconnect rebuilt all of them. The teardown must
  still happen once, on the transition into "unknown", or stale sensor handles
  would survive a transport change.

  Reaching that path takes care:
    - detectSourceMode() returns "sim" whenever the radio reports simulation,
      and it captures that at module load, so simulation must be false BEFORE
      the module is required.
    - getSensorSource() returns early for a name absent from sensorTable, so
      the probe must use a key the module actually defines.
  Both are asserted below, so this test cannot go green by silently skipping
  the code it is meant to cover.
]] --

local mock = dofile("bin/test/lib/ethos_mock.lua")
local t = dofile("bin/test/lib/t.lua")

mock.install()

-- Must be in place before the module loads: isSim is captured at load time.
system.getVersion = function()
    return {simulation = false, lcdWidth = 800, lcdHeight = 480, major = 1, minor = 6, revision = 0}
end

-- clearRuntimeCaches() is the only weak-table creator in this module, so
-- setmetatable{__mode="v"} is a reliable fingerprint for "caches were torn down".
local weakTables = 0
local realsetmetatable = setmetatable
local function countingSetmetatable(tbl, mt)
    if type(mt) == "table" and mt.__mode == "v" then weakTables = weakTables + 1 end
    return realsetmetatable(tbl, mt)
end

setmetatable = countingSetmetatable
local ok, telemetry = pcall(function()
    return assert(mock.realloadfile("src/rfsuite/tasks/scheduler/telemetry/telemetry.lua"))()
end)
setmetatable = realsetmetatable

t.group("harness reaches the code under test")

if not ok or type(telemetry) ~= "table" or type(telemetry.getSensorSource) ~= "function" then
    t.check("telemetry module loads under the mock", false,
        "load failed: " .. tostring(telemetry) .. " (extend ethos_mock if this starts mattering)")
    return t.failures()
end
t.check("telemetry module loaded", true)

-- Pick a key the module really defines, so getSensorSource does not bail early.
local probe
for k in pairs(telemetry.sensorTable or {}) do probe = k break end
t.check("found a real sensor key to probe with", probe ~= nil, "sensorTable was empty")
if not probe then return t.failures() end

local session = package.loaded["rfsuite"].session

-- Establish a KNOWN transport first. A cold start has nothing stale to discard,
-- so the case that matters is the link dropping out from under a live mode.
session.telemetryType = "sport"
telemetry.getSensorSource(probe)

setmetatable = countingSetmetatable
weakTables = 0

-- Link drops: detectSourceMode now returns nil.
session.telemetryType = nil
telemetry.getSensorSource(probe)
local onTransition = weakTables

for _ = 1, 50 do telemetry.getSensorSource(probe) end
local afterFifty = weakTables
setmetatable = realsetmetatable

t.group("known -> unknown transition still tears the caches down")
-- If this is 0 the path was never entered and the assertion below is vacuous.
t.check("transition to unknown transport clears the caches exactly once", onTransition == 1,
    "weak-table rebuilds on the transition lookup: " .. onTransition ..
    " (0 means detectSourceMode never returned nil and this test proves nothing)")

t.group("staying unknown is free")
t.check("no further teardowns across 50 more lookups", afterFifty == onTransition,
    string.format("grew from %d to %d -- clearRuntimeCaches is running per lookup",
        onTransition, afterFifty))

return t.failures()
