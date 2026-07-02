local rfsuite = require("rfsuite")
local tonumber = tonumber
local pairs = pairs

local config = {}
local DEFAULTS = {
    rpm_max = 2500,
    bec_min = 6.5,
    bec_warn = 7.0,
    esc_warn = 110,
    esc_max = 150,
    fuel_warn = 25,
    link_warn = 50,
    current_warn = 120,
    watts_warn = 3500
}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function loadConfig()
    for key, default in pairs(DEFAULTS) do
        config[key] = tonumber(rfsuite.widgets.dashboard.getPreference(key)) or default
    end
end

local function field(panel, label, key, lo, hi, step, suffix)
    local line = panel:addLine(label)
    local item = form.addNumberField(line, nil, lo, hi,
        function() return config[key] end,
        function(v) config[key] = clamp(tonumber(v) or DEFAULTS[key], lo, hi) end,
        step)
    if suffix then item:suffix(suffix) end
end

local function configure()
    loadConfig()
    local flight = form.addExpansionPanel("Plume instrument")
    flight:open(true)
    field(flight, "Maximum headspeed", "rpm_max", 100, 20000, 10, "rpm")

    local power = form.addExpansionPanel("Jewel power")
    power:open(false)
    field(power, "BEC minimum x10", "bec_min", 20, 150, 1, "")
    field(power, "BEC notice x10", "bec_warn", 20, 150, 1, "")
    field(power, "Current notice", "current_warn", 1, 500, 1, "A")
    field(power, "Power notice", "watts_warn", 100, 15000, 50, "W")

    local thermal = form.addExpansionPanel("Ember limits")
    thermal:open(false)
    field(thermal, "ESC notice", "esc_warn", 0, 199, 1, "C")
    field(thermal, "ESC maximum", "esc_max", 1, 200, 1, "C")

    local reserve = form.addExpansionPanel("Reserve and link")
    reserve:open(false)
    field(reserve, "Fuel reserve", "fuel_warn", 1, 99, 1, "%")
    field(reserve, "Link minimum", "link_warn", 1, 99, 1, "%")
end

local function write()
    for key in pairs(DEFAULTS) do
        rfsuite.widgets.dashboard.savePreference(key, config[key])
    end
end

return {configure = configure, write = write}
