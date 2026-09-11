-- Standalone Ethos widget; choose numeric headspeed and governor sensors.
-- For Suite dashboard themes use its context facade and phase-table contract.
local WIDGET_KEY = "rfgov"
local floor = math.floor
local format = string.format
local huge = math.huge
local GOV_STATES = {
    [0] = "OFF", [1] = "IDLE", [2] = "SPOOLUP", [3] = "RECOVERY",
    [4] = "ACTIVE", [5] = "THR OFF", [6] = "LOST HS", [7] = "AUTOROT",
    [8] = "BAILOUT", [100] = "DISABLED", [101] = "DISARMED",
}
local GOV_COLOR = lcd.RGB(180, 180, 180)
local RPM_COLOR = lcd.RGB(255, 255, 255)
local WARN_COLOR = lcd.RGB(255, 60, 60)

local function liveNumber(source)
    if not source or not source:state() then return nil end
    local value = source:value()
    if type(value) ~= "number" or value ~= value or value == huge or value == -huge then return nil end
    return value
end

local function threshold(value, fallback)
    if type(value) ~= "number" or value ~= value or value == huge or value == -huge then return fallback end
    return math.max(0, math.min(5000, floor(value)))
end

local function create()
    return {rpmSource = nil, govSource = nil, rpmLowThreshold = 1200,
        rpmHighThreshold = 2200, displayRpm = nil, displayGov = nil,
        rpmText = "--", govText = "--", rpmColor = RPM_COLOR}
end

local function configure(widget)
    local line = form.addLine("Headspeed source")
    form.addSourceField(line, nil, function() return widget.rpmSource end,
        function(value) widget.rpmSource = value end)
    line = form.addLine("Governor source")
    form.addSourceField(line, nil, function() return widget.govSource end,
        function(value) widget.govSource = value end)
    line = form.addLine("Low RPM warning")
    form.addNumberField(line, nil, 0, 5000, function() return widget.rpmLowThreshold end,
        function(value)
            -- Maintain an ordered warning band when either limit is edited.
            widget.rpmLowThreshold = threshold(value, widget.rpmLowThreshold)
            if widget.rpmHighThreshold < widget.rpmLowThreshold then widget.rpmHighThreshold = widget.rpmLowThreshold end
        end)
    line = form.addLine("High RPM warning")
    form.addNumberField(line, nil, 0, 5000, function() return widget.rpmHighThreshold end,
        function(value)
            widget.rpmHighThreshold = threshold(value, widget.rpmHighThreshold)
            if widget.rpmLowThreshold > widget.rpmHighThreshold then widget.rpmLowThreshold = widget.rpmHighThreshold end
        end)
end

local function read(widget)
    -- Restore settings before the next display update; validate stored bounds.
    widget.rpmSource = storage.read("rpmSource")
    widget.govSource = storage.read("govSource")
    widget.rpmLowThreshold = threshold(storage.read("rpmLow"), 1200)
    widget.rpmHighThreshold = math.max(widget.rpmLowThreshold, threshold(storage.read("rpmHigh"), 2200))
end

local function write(widget)
    storage.write("rpmSource", widget.rpmSource)
    storage.write("govSource", widget.govSource)
    storage.write("rpmLow", widget.rpmLowThreshold)
    storage.write("rpmHigh", widget.rpmHighThreshold)
end

local function wakeup(widget)
    local rawRpm = liveNumber(widget.rpmSource)
    local gov = liveNumber(widget.govSource)
    -- Round RPM to ten-RPM steps; negative headspeed is unavailable.
    local rpm = rawRpm and rawRpm >= 0 and floor(rawRpm / 10 + 0.5) * 10 or nil
    local color = RPM_COLOR
    if rpm ~= nil and (rpm < widget.rpmLowThreshold or rpm > widget.rpmHighThreshold) then color = WARN_COLOR end
    local changed = false
    if rpm ~= widget.displayRpm then
        widget.displayRpm = rpm
        widget.rpmText = rpm ~= nil and format("%.0f RPM", rpm) or "--"
        changed = true
    end
    -- Settings can change the warning color while RPM remains steady.
    if color ~= widget.rpmColor then
        widget.rpmColor = color
        changed = true
    end
    if gov ~= widget.displayGov then
        widget.displayGov = gov
        widget.govText = gov ~= nil and (GOV_STATES[gov] or "UNKNOWN") or "--"
        changed = true
    end
    if changed then lcd.invalidate() end
end

local function paint(widget)
    local w, h = lcd.getWindowSize()
    lcd.font(FONT_L)
    lcd.color(GOV_COLOR)
    lcd.drawText(w / 2, h * 0.25, widget.govText, CENTERED + VCENTERED)
    lcd.font(FONT_XL)
    lcd.color(widget.rpmColor)
    lcd.drawText(w / 2, h * 0.65, widget.rpmText, CENTERED + VCENTERED)
end

local function init()
    system.registerWidget({key = WIDGET_KEY, name = "RF Governor", create = create,
        configure = configure, read = read, write = write, wakeup = wakeup, paint = paint})
end

return {init = init}
