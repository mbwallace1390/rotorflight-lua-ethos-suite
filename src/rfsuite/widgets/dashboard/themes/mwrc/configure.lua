--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")

local floor = math.floor
local pairs = pairs
local tonumber = tonumber

local config = {}

-- Keep these values aligned with preflight.lua, inflight.lua and postflight.lua.
local THEME_DEFAULTS = {
    rpm_min = 0,
    rpm_max = 3000,
    bec_min = 6.5,
    bec_warn = 8.0,
    bec_max = 12.0,
    esctemp_warn = 110,
    esctemp_max = 150
}

local function clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function getPref(key)
    return rfsuite.widgets.dashboard.getPreference(key)
end

local function setPref(key, value)
    rfsuite.widgets.dashboard.savePreference(key, value)
end

-- Preferences stay in canonical Celsius; the form converts at its boundary.
local function temperatureUnit()
    local general = rfsuite.preferences and rfsuite.preferences.general
    return tonumber(general and general.temperature_unit) == 1 and 1 or 0
end

local function displayTemperature(value)
    if temperatureUnit() == 1 then return value * 1.8 + 32 end
    return value
end

local function storeTemperature(value)
    if temperatureUnit() == 1 then return (value - 32) / 1.8 end
    return value
end

local function loadPreferences()
    for key, default in pairs(THEME_DEFAULTS) do
        config[key] = tonumber(getPref(key)) or default
    end

    config.rpm_min = clamp(config.rpm_min, 0, 19999)
    config.rpm_max = clamp(config.rpm_max, config.rpm_min + 1, 20000)

    config.bec_min = clamp(config.bec_min, 2.0, 14.8)
    config.bec_max = clamp(config.bec_max, config.bec_min + 0.2, 15.0)
    config.bec_warn = clamp(config.bec_warn, config.bec_min + 0.1, config.bec_max - 0.1)

    config.esctemp_warn = clamp(config.esctemp_warn, 0, 199)
    config.esctemp_max = clamp(config.esctemp_max, config.esctemp_warn + 1, 200)
end

local function addNumberField(line, minimum, maximum, getter, setter, step, suffix, decimals)
    local field = form.addNumberField(line, nil, minimum, maximum, getter, setter)
    if step then field:step(step) end
    if decimals then field:decimals(decimals) end
    if suffix then field:suffix(suffix) end
    return field
end

local function configure()
    loadPreferences()
    local tempUnit = temperatureUnit()
    local tempSuffix = tempUnit == 1 and "°F" or "°C"
    local tempMinimum = tempUnit == 1 and 32 or 0
    local tempMaximum = tempUnit == 1 and 392 or 200

    local rpmPanel = form.addExpansionPanel("Headspeed")
    rpmPanel:open(false)

    addNumberField(
        rpmPanel:addLine("Min"),
        0,
        20000,
        function() return config.rpm_min end,
        function(value)
            config.rpm_min = clamp(tonumber(value) or THEME_DEFAULTS.rpm_min, 0, config.rpm_max - 1)
        end,
        1,
        "rpm"
    )

    addNumberField(
        rpmPanel:addLine("Max"),
        1,
        20000,
        function() return config.rpm_max end,
        function(value)
            config.rpm_max = clamp(tonumber(value) or THEME_DEFAULTS.rpm_max, config.rpm_min + 1, 20000)
        end,
        1,
        "rpm"
    )

    local becPanel = form.addExpansionPanel("BEC Voltage")
    becPanel:open(false)

    addNumberField(
        becPanel:addLine("Min"),
        20,
        150,
        function() return floor(config.bec_min * 10 + 0.5) end,
        function(value)
            config.bec_min = clamp((tonumber(value) or 20) / 10, 2.0, config.bec_max - 0.2)
            config.bec_warn = clamp(config.bec_warn, config.bec_min + 0.1, config.bec_max - 0.1)
        end,
        nil,
        "V",
        1
    )

    addNumberField(
        becPanel:addLine("Warning"),
        20,
        150,
        function() return floor(config.bec_warn * 10 + 0.5) end,
        function(value)
            config.bec_warn = clamp((tonumber(value) or 20) / 10, config.bec_min + 0.1, config.bec_max - 0.1)
        end,
        nil,
        "V",
        1
    )

    addNumberField(
        becPanel:addLine("Max"),
        20,
        150,
        function() return floor(config.bec_max * 10 + 0.5) end,
        function(value)
            config.bec_max = clamp((tonumber(value) or 150) / 10, config.bec_min + 0.2, 15.0)
            config.bec_warn = clamp(config.bec_warn, config.bec_min + 0.1, config.bec_max - 0.1)
        end,
        nil,
        "V",
        1
    )

    local escPanel = form.addExpansionPanel("ESC Temperature")
    escPanel:open(false)

    addNumberField(
        escPanel:addLine("Warning"),
        tempMinimum,
        tempMaximum,
        function() return floor(displayTemperature(config.esctemp_warn) + 0.5) end,
        function(value)
            local displayedValue = tonumber(value) or displayTemperature(THEME_DEFAULTS.esctemp_warn)
            config.esctemp_warn = clamp(storeTemperature(displayedValue), 0, config.esctemp_max - 1)
        end,
        1,
        tempSuffix
    )

    addNumberField(
        escPanel:addLine("Max"),
        tempMinimum,
        tempMaximum,
        function() return floor(displayTemperature(config.esctemp_max) + 0.5) end,
        function(value)
            local displayedValue = tonumber(value) or displayTemperature(THEME_DEFAULTS.esctemp_max)
            config.esctemp_max = clamp(storeTemperature(displayedValue), config.esctemp_warn + 1, 200)
        end,
        1,
        tempSuffix
    )
end

local function write()
    for key in pairs(THEME_DEFAULTS) do
        setPref(key, config[key])
    end
end

return {configure = configure, write = write}
