-- Cinder data preparation: live readings and recorded samples stay distinct. GPLv3.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local context = requireModule("widgets/dashboard/context.lua")
local header = requireModule("widgets/dashboard/themes/cinder/header.lua")
local panels = requireModule("widgets/dashboard/themes/cinder/layout.lua")
local C = requireModule("widgets/dashboard/themes/cinder/common.lua").colors
local floor, min, max = math.floor, math.min, math.max
local format, rawNumber = string.format, tonumber
local M = {}
local DEFAULTS = {bec_min=6.5, bec_warn=7.0, esc_warn=110, esc_max=150, fuel_warn=25, link_warn=50}
local STATES = {[0]="OFF", [1]="IDLE", [2]="SPOOLUP", [3]="RECOVERY", [4]="ACTIVE", [5]="THROTTLE OFF", [6]="LOST HEADSPEED", [7]="AUTOROTATION", [8]="BAILOUT"}
local ARMED = {}
for key, label in pairs(STATES) do ARMED[key] = "ARMED / " .. label end

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
        values[key], units[key] = value, unit
        if value == nil then c[key] = "--"
        elseif decimals == 2 then c[key] = format("%.2f", value) .. unit
        elseif decimals == 1 then c[key] = format("%.1f", value) .. unit
        else c[key] = tostring(floor(value + 0.5)) .. unit end
    end
end

local function time(c, key, seconds, total)
    seconds = number(seconds)
    if seconds and seconds < 0 then seconds = nil end
    if seconds then seconds = floor(seconds) end
    if c.values[key] ~= seconds or c[key] == nil then
        c.values[key] = seconds
        if seconds == nil then c[key] = "--:--"
        elseif total then c[key] = format("%02d:%02d:%02d", floor(seconds / 3600), floor(seconds / 60) % 60, seconds % 60)
        else c[key] = format("%02d:%02d", floor(seconds / 60), seconds % 60) end
    end
end

local function thresholds(c)
    c.fuelWarn = clamp(pref("fuel_warn"), 1, 99)
    c.becMin = clamp(pref("bec_min"), 2, 14.8)
    c.becWarn = clamp(pref("bec_warn"), c.becMin + 0.1, 15)
    c.linkWarn = clamp(pref("link_warn"), 1, 99)
    c.escWarn = clamp(pref("esc_warn"), 0, 199)
    c.escMax = clamp(pref("esc_max"), c.escWarn + 1, 200)
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
    c.escBar = c.esc
    if c.escBar and fahrenheit then c.escBar = (c.escBar - 32) / 1.8 end
end

local function colors(c)
    c.fuelColor = c.fuel == nil and C.muted or (c.fuel <= c.fuelWarn and C.red or C.green)
    c.escColor = c.esc == nil and C.muted or (c.esc >= c.escMax and C.red or (c.esc >= c.escWarn and C.amber or C.white))
    c.becColor = c.bec == nil and C.muted or (c.bec < c.becMin and C.red or (c.bec < c.becWarn and C.amber or C.white))
    c.linkColor = c.link == nil and C.muted or (c.link < c.linkWarn and C.amber or C.white)
end

local function flightState(c, telemetry)
    local s = context.session
    if not (s.isConnected and s.telemetryState) then
        c.flightState, c.flightStateColor = "TELEMETRY OFFLINE", C.muted
        return
    end
    local governor = sensor(telemetry, "governor")
    if not s.isArmed or governor == 101 then
        c.flightState, c.flightStateColor = "DISARMED", C.green
    else
        c.flightState = ARMED[governor] or "ARMED"
        c.flightStateColor = governor == 6 and C.red or C.copper
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
    c.fuel = percent(sensor(telemetry, "smartfuel"))
    c.current = sensor(telemetry, "current")
    c.voltage = sensor(telemetry, "voltage")
    c.bec = sensor(telemetry, "bec_voltage")
    c.consumed = sensor(telemetry, "smartconsumption")
    c.link = percent(sensor(telemetry, "vfr"))
    if c.link == nil then c.link = percent(sensor(telemetry, "rssi")) end
    thermal(c, telemetry, false)
    flightState(c, telemetry)
    local s = context.session
    local seconds
    if s.isConnected and s.telemetryState then seconds = s.timer and s.timer.live end
    time(c, "timer", seconds)
    text(c, "rpmText", c.rpm, 0, "")
    text(c, "voltageText", c.voltage, 1, " V")
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
    if c.link == nil then c.link = percent(sample(telemetry, "rssi", "min")) end
    thermal(c, telemetry, true)
    c.recorded = c.current ~= nil or c.fuel ~= nil or c.bec ~= nil or c.consumed ~= nil
        or c.cell ~= nil or c.link ~= nil or c.esc ~= nil
    local s = context.session
    local modelName = model and model.name and model.name() or ""
    if c._model ~= modelName then
        -- The last visible summary belongs to one selected radio model only.
        c._model, c._lastSeconds = modelName, nil
    end
    local general = s.modelPreferences and s.modelPreferences.general
    local connected = s.isConnected and s.telemetryState
    local seconds = number(s.timer and s.timer.live)
    if not connected and (seconds == nil or seconds == 0) then
        if c._lastSeconds ~= nil then
            seconds = c._lastSeconds
        else
            seconds = number(general and general.lastflighttime)
            -- The facade synthesizes zero without history; known live zero is retained above.
            if seconds == 0 and not c.recorded then seconds = nil end
        end
    end
    c._lastSeconds = seconds
    time(c, "timer", seconds)
    text(c, "cellText", c.cell, 2, " V")
    text(c, "averageCurrentText", c.averageCurrent, 1, " A")
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
    return c
end

function M.create(phase)
    local headerLayout, headerBoxes = header.create()
    -- One callback pair and one cache per loaded phase; none are created in paint.
    local function wakeup(box, telemetry) return update(box, telemetry, phase) end
    local function paint(x, y, w, h, box, c)
        if c then panels[phase](x, y, w, h, c) end
    end
    local boxes = {{col=1, row=1, colspan=12, rowspan=12, type="func", subtype="func",
        wakeup=wakeup, paint=paint, bgcolor="transparent"}}
    local function getBoxes() return boxes end
    return {
        layout = {cols=12, rows=12, padding=0},
        boxes = getBoxes,
        header_layout=headerLayout, header_boxes=headerBoxes,
        screenBorderStyle={enabled=false},
        scheduler={spread_scheduling=true, spread_scheduling_paint=false, spread_ratio=0.85},
    }
end

return M
