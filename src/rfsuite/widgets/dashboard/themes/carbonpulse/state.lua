-- Carbon Pulse data preparation: live readings and recorded samples stay distinct.
-- Adapted from Studio Stratus 98 (from Studio Sector and MWRC Cinder); telemetry
-- semantics preserved. GPLv3.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local context = requireModule("widgets/dashboard/context.lua")
local header = requireModule("widgets/dashboard/themes/carbonpulse/header.lua")
local panels = requireModule("widgets/dashboard/themes/carbonpulse/layout.lua")
local C = requireModule("widgets/dashboard/themes/carbonpulse/common.lua").colors
local floor, min, max = math.floor, math.min, math.max
local format, rawNumber = string.format, tonumber
local M = {}
local DEFAULTS = {bec_min=6.5, bec_warn=7.0, esc_warn=110, esc_max=150, fuel_warn=25, link_warn=50, rpm_max=3000}
local STATES = {[0]="OFF", [1]="IDLE", [2]="SPOOLUP", [3]="RECOVERY", [4]="ACTIVE", [5]="THROTTLE OFF", [6]="LOST HEADSPEED", [7]="AUTOROTATION", [8]="BAILOUT"}
local ARMED = {}
for key, label in pairs(STATES) do ARMED[key] = "ARMED / " .. label end
-- Governor state 0 with gov_mode NONE or LIMIT means no governor, not OFF (Suite #2353).
local PASSTHRU = "ARMED / PASSTHRU"
-- Profile numbers are small integers; their labels are built once.
local PROFILE = {}
for i = 0, 9 do PROFILE[i] = tostring(i) end

local function number(value)
    value = rawNumber(value)
    if value and value == value and value >= -1000000000 and value <= 1000000000 then return value end
end

local function clamp(value, low, high)
    return max(low, min(high, value))
end

local function pref(key)
    return number(context.widgets.dashboard.getPreference(key)) or DEFAULTS[key]
end

local function percent(value)
    value = number(value)
    if value and value >= 0 and value <= 100 then return value end
end

local function sensor(telemetry, name)
    local s = context.session
    if not (s.isConnected and s.telemetryState and telemetry and telemetry.getSensor) then return nil end
    return number((telemetry.getSensor(name)))
end

local function sample(telemetry, name, kind)
    local stats = telemetry and telemetry.sensorStats
    local entry = stats and stats[name]
    return number(entry and entry[kind])
end

local function text(c, key, value, decimals, unit)
    local scale = decimals == 2 and 100 or (decimals == 1 and 10 or 1)
    if value ~= nil then value = floor(value * scale + 0.5) / scale end
    local values, units = c.values, c.units
    if values[key] ~= value or units[key] ~= unit or c[key] == nil then
        -- Text and its key are stored together, after formatting, so a callback
        -- aborted mid-format cannot leave a new key with the old text.
        local s
        if value == nil then s = "--"
        elseif decimals == 2 then s = format("%.2f", value) .. unit
        elseif decimals == 1 then s = format("%.1f", value) .. unit
        else s = tostring(floor(value + 0.5)) .. unit end
        values[key], units[key], c[key] = value, unit, s
    end
end

local function time(c, key, seconds, total)
    seconds = number(seconds)
    if seconds and seconds < 0 then seconds = nil end
    if seconds then seconds = floor(seconds) end
    if c.values[key] ~= seconds or c[key] == nil then
        local s
        if seconds == nil then s = "--:--"
        elseif total then s = format("%02d:%02d:%02d", floor(seconds / 3600), floor(seconds / 60) % 60, seconds % 60)
        else s = format("%02d:%02d", floor(seconds / 60), seconds % 60) end
        c.values[key], c[key] = seconds, s
    end
end

local function thresholds(c)
    c.fuelWarn = clamp(pref("fuel_warn"), 1, 99)
    c.becMin = clamp(pref("bec_min"), 2, 14.8)
    c.becWarn = clamp(pref("bec_warn"), c.becMin + 0.1, 15)
    c.linkWarn = clamp(pref("link_warn"), 1, 99)
    c.escWarn = clamp(pref("esc_warn"), 0, 199)
    c.escMax = clamp(pref("esc_max"), c.escWarn + 1, 200)
    c.rpmMax = clamp(pref("rpm_max"), 500, 6000)
end

local function thermal(c, telemetry, historical)
    local general = context.preferences.general
    local fahrenheit = general and number(general.temperature_unit) == 1
    c.escUnit = fahrenheit and "°F" or "°C"
    if historical then
        -- Raw recorded samples are Celsius; convert once without reading a live source.
        c.esc = sample(telemetry, "temp_esc", "max")
        if c.esc and fahrenheit then c.esc = c.esc * 1.8 + 32 end
    else
        local s = context.session
        c.esc = nil
        if s.isConnected and s.telemetryState and telemetry and telemetry.getSensor then
            local value, _, unit = telemetry.getSensor("temp_esc")
            c.esc, c.escUnit = number(value), unit or c.escUnit
        end
    end
    if fahrenheit then
        c.escWarn, c.escMax = c.escWarn * 1.8 + 32, c.escMax * 1.8 + 32
    end
    if historical then
        c.mcu = sample(telemetry, "temp_mcu", "max")
        if c.mcu and fahrenheit then c.mcu = c.mcu * 1.8 + 32 end
        c.mcuUnit = fahrenheit and "°F" or "°C"
    else
        local s = context.session
        c.mcu, c.mcuUnit = nil, fahrenheit and "°F" or "°C"
        if s.isConnected and s.telemetryState and telemetry and telemetry.getSensor then
            local value, _, unit = telemetry.getSensor("temp_mcu")
            c.mcu, c.mcuUnit = number(value), unit or c.mcuUnit
        end
    end
end

local function colors(c)
    c.fuelColor = c.fuel == nil and C.muted or (c.fuel <= c.fuelWarn and C.red or C.green)
    c.escColor = c.esc == nil and C.muted or (c.esc >= c.escMax and C.red or (c.esc >= c.escWarn and C.amber or C.white))
    c.becColor = c.bec == nil and C.muted or (c.bec < c.becMin and C.red or (c.bec < c.becWarn and C.amber or C.white))
    c.linkColor = c.link == nil and C.muted or (c.link < c.linkWarn and C.amber or C.white)
    -- Readouts are green while normal; warning hues replace them, never the reverse.
    c.fuelValueColor = c.fuel == nil and C.muted or (c.fuelColor == C.red and C.red or C.value)
    c.escValueColor = c.escColor == C.white and C.value or c.escColor
    c.becValueColor = c.becColor == C.white and C.value or c.becColor
    c.linkValueColor = c.linkColor == C.white and C.value or c.linkColor
end

-- Arc fraction and zone, recomputed only when the reading or the scale changes.
local function headspeed(c, rpm)
    if c._rpmValue == rpm and c._rpmScale == c.rpmMax and c.rpmFraction ~= nil then return end
    c._rpmValue, c._rpmScale = rpm, c.rpmMax
    if rpm == nil then
        c.rpmFraction, c.rpmZone = 0, nil
    else
        local fraction = clamp(rpm / c.rpmMax, 0, 1)
        c.rpmFraction = fraction
        -- Zone edges match layout.lua's arc segments.
        c.rpmZone = fraction >= 0.9 and C.red or (fraction >= 0.75 and C.amber or C.green)
    end
end

-- Saved model statistics. The facade substitutes zero when history is absent,
-- so a disconnected zero is shown as unavailable rather than invented.
-- The facade substitutes zero for model statistics it no longer has, as after a
-- disconnect. With `retain` (postflight) the figures last shown stay until
-- another aircraft or flight, as the flight time does; otherwise a disconnected
-- zero is unknown.
local function statistics(c, connected, retain)
    local s = context.session
    local general = s.modelPreferences and s.modelPreferences.general
    local count = number(general and general.flightcount)
    local total = number(general and general.totalflighttime)
    local last = number(general and general.lastflighttime)
    if not connected then
        if retain then
            if count == nil or count == 0 then count = c._lastCount end
            if total == nil or total == 0 then total = c._lastTotal end
            if last == nil or last == 0 then last = c._lastSaved end
        else
            if count == 0 then count = nil end
            if total == 0 then total = nil end
            if last == 0 then last = nil end
        end
    end
    if count and count < 0 then count = nil end
    if retain then c._lastCount, c._lastTotal, c._lastSaved = count, total, last end
    text(c, "flightsText", count, 0, "")
    time(c, "totalText", total, true)
    time(c, "lastText", last)
end

local function flightState(c, telemetry)
    local s = context.session
    if not (s.isConnected and s.telemetryState) then
        c.flightState, c.flightStateColor = "TELEMETRY OFFLINE", C.muted
        return
    end
    -- armflags is 1, 0 or nil (not yet known, as after a reconnect); the
    -- session's isArmed turns nil into false, so it cannot be used here.
    local armflags = sensor(telemetry, "armflags")
    local governor = sensor(telemetry, "governor")
    if armflags == 0 or governor == 101 then
        c.flightState, c.flightStateColor = "DISARMED", C.green
    elseif armflags == 1 or (governor and governor >= 1 and governor <= 8) then
        -- Armed, or arm state unknown while the governor is running.
        local label = ARMED[governor]
        if governor == 0 and s.governorModeKnown == true and (s.governorMode == 0 or s.governorMode == 1) then
            label = PASSTHRU
        end
        c.flightState = label or "ARMED"
        c.flightStateColor = governor == 6 and C.red or C.amber
    else
        c.flightState, c.flightStateColor = "ARM UNKNOWN", C.amber
    end
end

local function checks(c)
    local available, issues = 0, 0
    local issue
    if c.voltage ~= nil then
        available = available + 1
        if c.voltage <= 0 then issues, issue = issues + 1, "CHECK PACK VOLTAGE" end
    end
    if c.fuel ~= nil then
        available = available + 1
        if c.fuel <= c.fuelWarn then issues, issue = issues + 1, issue or "FUEL AT RESERVE" end
    end
    if c.bec ~= nil then
        available = available + 1
        if c.bec < c.becWarn then issues, issue = issues + 1, issue or "BEC BELOW WARNING" end
    end
    if c.esc ~= nil then
        available = available + 1
        if c.esc >= c.escWarn then issues, issue = issues + 1, issue or "ESC ABOVE WARNING" end
    end
    if c.link ~= nil then
        available = available + 1
        if c.link < c.linkWarn then issues, issue = issues + 1, issue or "LINK BELOW WARNING" end
    end
    c.available, c.issues = available, issues
    if available == 0 then c.status, c.statusColor = "WAITING", C.muted
    elseif available < 5 then c.status, c.statusColor = "INCOMPLETE", C.amber
    elseif issues > 0 then c.status, c.statusColor = "REVIEW WARNINGS", C.amber
    else c.status, c.statusColor = "CHECKS COMPLETE", C.green end
    c.issue = issue or (available < 5 and "CHECK MISSING SENSORS" or "NO CHECKED WARNINGS")
    if c._available ~= available or c._issues ~= issues then
        c._available, c._issues = available, issues
        c.coverage = tostring(available) .. " / 5 LIVE CHECKS"
        c.issueCount = tostring(issues) .. (issues == 1 and " WARNING" or " WARNINGS")
    end
end

local function live(c, telemetry)
    thresholds(c)
    c.rpm = sensor(telemetry, "rpm")
    if c.rpm and c.rpm < 0 then c.rpm = nil end
    c.throttle = percent(sensor(telemetry, "throttle_percent"))
    c.altitude = sensor(telemetry, "altitude")
    c.pid = sensor(telemetry, "pid_profile")
    c.rate = sensor(telemetry, "rate_profile")
    c.fuel = percent(sensor(telemetry, "smartfuel"))
    c.current = sensor(telemetry, "current")
    c.voltage = sensor(telemetry, "voltage")
    c.bec = sensor(telemetry, "bec_voltage")
    c.consumed = sensor(telemetry, "smartconsumption")
    c.link = percent(sensor(telemetry, "vfr"))
    thermal(c, telemetry, false)
    flightState(c, telemetry)
    local s = context.session
    local seconds
    if s.isConnected and s.telemetryState then seconds = s.timer and s.timer.live end
    time(c, "timer", seconds)
    text(c, "rpmText", c.rpm, 0, "")
    text(c, "voltageText", c.voltage, 1, " V")
    text(c, "throttleText", c.throttle, 0, "%")
    text(c, "altText", c.altitude, 0, " m")
    c.pidText = c.pid and PROFILE[floor(c.pid)] or "--"
    c.rateText = c.rate and PROFILE[floor(c.rate)] or "--"
    statistics(c, s.isConnected and s.telemetryState)
    headspeed(c, c.rpm)
    checks(c)
end

local function history(c, telemetry)
    thresholds(c)
    c.current = sample(telemetry, "current", "max")
    c.averageCurrent = sample(telemetry, "current", "avg")
    c.fuel = percent(sample(telemetry, "smartfuel", "min"))
    c.bec = sample(telemetry, "bec_voltage", "min")
    c.consumed = sample(telemetry, "consumption", "max")
    c.cell = sample(telemetry, "cell_voltage", "min")
    c.link = percent(sample(telemetry, "vfr", "min"))
    c.rpm = sample(telemetry, "rpm", "max")
    if c.rpm and c.rpm < 0 then c.rpm = nil end
    c.altitude = sample(telemetry, "altitude", "max")
    c.voltage = sample(telemetry, "voltage", "min")
    thermal(c, telemetry, true)
    c.recorded = c.current ~= nil or c.fuel ~= nil or c.bec ~= nil or c.consumed ~= nil
        or c.cell ~= nil or c.link ~= nil or c.esc ~= nil or c.rpm ~= nil
        or c.voltage ~= nil or c.mcu ~= nil or c.altitude ~= nil
    local s = context.session
    -- Retained results belong to one aircraft and one flight. The Suite keeps
    -- mcu_id while a flight is held and clears it on a plain disconnect, when
    -- it may also restore the radio model's name, so only a different reported
    -- id is another aircraft. It replaces its per-sensor sample entries when a
    -- connection or a flight starts, even while the dashboard is hidden, so
    -- other entries mean a later flight. An ETHOS model switch closes the
    -- widget, which discards this cache.
    local id = s.mcu_id
    local stats = telemetry and telemetry.sensorStats
    local samples = stats and (stats.voltage or stats.current or stats.rpm or stats.consumption
        or stats.throttle_percent)
    if (id and id ~= "" and c._model ~= id) or (samples and c._samples ~= samples) then
        if id and id ~= "" then c._model = id end
        if samples then c._samples = samples end
        c._lastSeconds, c._savedSeen = nil, nil
        c._lastCount, c._lastTotal, c._lastSaved = nil, nil, nil
    end
    local general = s.modelPreferences and s.modelPreferences.general
    local saved = number(general and general.lastflighttime)
    if c._savedSeen ~= saved then
        -- A flight saved since the last wakeup supersedes the duration this
        -- phase retained.
        if c._savedSeen ~= nil and saved and saved > 0 then c._lastSeconds = nil end
        c._savedSeen = saved
    end
    local connected = s.isConnected and s.telemetryState
    local seconds = number(s.timer and s.timer.live)
    if not connected and (seconds == nil or seconds == 0) then
        if c._lastSeconds ~= nil then
            seconds = c._lastSeconds
        else
            seconds = saved
            -- Disconnected, the facade substitutes zero for missing statistics;
            -- a zero seen live is retained in c._lastSeconds above instead.
            if seconds == 0 then seconds = nil end
        end
    end
    c._lastSeconds = seconds
    time(c, "timer", seconds)
    text(c, "cellText", c.cell, 2, " V")
    text(c, "averageCurrentText", c.averageCurrent, 1, " A")
    text(c, "rpmText", c.rpm, 0, "")
    text(c, "voltageText", c.voltage, 1, " V")
    text(c, "altText", c.altitude, 0, " m")
    statistics(c, connected, true)
    headspeed(c, c.rpm)
end

local function update(box, telemetry, phase)
    local c = box._cache
    if not c then c = {values={}, units={}}; box._cache = c end
    telemetry = telemetry or context.tasks.telemetry
    if phase == "postflight" then history(c, telemetry) else live(c, telemetry) end
    colors(c)
    text(c, "fuelText", c.fuel, 0, "%")
    text(c, "escText", c.esc, 0, c.escUnit)
    text(c, "currentText", c.current, 1, " A")
    text(c, "consumedText", c.consumed, 0, " mAh")
    text(c, "becText", c.bec, 1, " V")
    text(c, "linkText", c.link, 0, "%")
    text(c, "mcuText", c.mcu, 0, c.mcuUnit)
    return c
end

-- The pacer box keeps the engine's wake pass open while the screen still
-- needs frames (layout.lua M.waiting). A box whose object type cannot load is
-- left unwoken, and the engine then reports its pass not done, so the
-- dashboard schedules another wakeup and repaint (engine.lua wakeOne and
-- wakeObjects, dashboard.lua wakeup). No object file has this name; a failed
-- load is retried at most once a second. The box has no size and draws
-- nothing. It wakes last in each pass, after the theme box has decided: after
-- the header boxes on a full screen, after the theme box otherwise. Placed
-- there, the boxes before it wake in the same groups as without it.
local WAITING = "carbonpulse-waiting"
local isFullScreen = context.widgets.dashboard.utils.isFullScreen

function M.create(phase)
    local headerLayout, headerBoxes = header.create()
    local pacer = {x=0, y=0, w=0, h=0, type="func", subtype="func", bgcolor="transparent"}
    -- One callback pair and one cache per loaded phase; none are created in paint.
    local function wakeup(box, telemetry)
        local c = update(box, telemetry, phase)
        -- The last paint left text waiting, so this pass only continues it.
        c._continuing = c._settled == false
        -- Gaining or losing the link changes many readings at once, more than
        -- one paint may lay out.
        local online = context.session.isConnected == true
        if c._online ~= online then c._online, c._settled = online, false end
        pacer.type = panels.waiting(c, box) and WAITING or "func"
        return c
    end
    local function paint(x, y, w, h, box, c)
        if c then
            -- Engines that hold a pass open for an unwoken box (#2447) mark each
            -- woken box; only there do the frames that complete held text come.
            c._paced = box._dashboardWoken == true
            panels[phase](x, y, w, h, c)
        end
    end
    -- One cell: the engine rounds a box down to whole grid cells, and a finer grid
    -- left an unpainted strip along the screen edges.
    local main = {col=1, row=1, colspan=1, rowspan=1, type="func", subtype="func",
        wakeup=wakeup, paint=paint, bgcolor="transparent"}
    -- The engine adds header boxes, after these, only on a full screen.
    local full, compact, withPacer, headerList = {main}, {main, pacer}, {}, nil
    local function getBoxes()
        return isFullScreen(lcd.getWindowSize()) and full or compact
    end
    local function getHeaderBoxes()
        local list = headerBoxes()
        if list ~= headerList then
            headerList = list
            for i = #withPacer, 1, -1 do withPacer[i] = nil end
            for i = 1, #list do withPacer[i] = list[i] end
            withPacer[#list + 1] = pacer
        end
        return withPacer
    end
    return {
        layout = {cols=1, rows=1, padding=0},
        boxes = getBoxes,
        header_layout=headerLayout, header_boxes=getHeaderBoxes,
        screenBorderStyle={enabled=false},
        -- A pass wakes boxes in order, so the theme box always decides before the
        -- pacer wakes; at this ratio either size wakes every box in one call.
        scheduler={spread_scheduling=true, spread_scheduling_paint=false, spread_ratio=0.85},
    }
end

return M
