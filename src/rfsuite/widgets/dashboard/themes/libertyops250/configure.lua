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

local THEME_DEFAULTS = {rpm_min = 0, rpm_max = 3000, bec_min = 3.0, bec_warn = 6.0, bec_max = 13.0, esctemp_warn = 90, esctemp_max = 140}

local function clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

local function getPref(key) return rfsuite.widgets.dashboard.getPreference(key) end

local function setPref(key, value) rfsuite.widgets.dashboard.savePreference(key, value) end

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

    local rpm_panel = form.addExpansionPanel("Headspeed")
    rpm_panel:open(false)
    local rpm_min_line = rpm_panel:addLine("Min")
    addNumberField(rpm_min_line, 0, 20000, function() return config.rpm_min end, function(val) config.rpm_min = clamp(tonumber(val) or THEME_DEFAULTS.rpm_min, 0, config.rpm_max - 1) end, 1, "rpm")

    local rpm_max_line = rpm_panel:addLine("Max")
    addNumberField(rpm_max_line, 1, 20000, function() return config.rpm_max end, function(val) config.rpm_max = clamp(tonumber(val) or THEME_DEFAULTS.rpm_max, config.rpm_min + 1, 20000) end, 1, "rpm")

    local bec_panel = form.addExpansionPanel("BEC Voltage")
    bec_panel:open(false)
    local bec_min_line = bec_panel:addLine("Min")
    addNumberField(bec_min_line, 20, 150, function()
        local v = config.bec_min or THEME_DEFAULTS.bec_min
        return floor((v * 10) + 0.5)
    end, function(val)
        local min_val = (tonumber(val) or 20) / 10
        config.bec_min = clamp(min_val, 2, config.bec_max - 0.2)
        config.bec_warn = clamp(config.bec_warn, config.bec_min + 0.1, config.bec_max - 0.1)
    end, nil, "V", 1)

    local bec_warn_line = bec_panel:addLine("Warning")
    addNumberField(bec_warn_line, 20, 150, function()
        local v = config.bec_warn or THEME_DEFAULTS.bec_warn
        return floor((v * 10) + 0.5)
    end, function(val)
        local warn_val = (tonumber(val) or 20) / 10
        config.bec_warn = clamp(warn_val, config.bec_min + 0.1, config.bec_max - 0.1)
    end, nil, "V", 1)

    local bec_max_line = bec_panel:addLine("Max")
    addNumberField(bec_max_line, 20, 150, function()
        local v = config.bec_max or THEME_DEFAULTS.bec_max
        return floor((v * 10) + 0.5)
    end, function(val)
        local max_val = (tonumber(val) or 150) / 10
        config.bec_max = clamp(max_val, config.bec_min + 0.2, 15)
        config.bec_warn = clamp(config.bec_warn, config.bec_min + 0.1, config.bec_max - 0.1)
    end, nil, "V", 1)

    local esc_panel = form.addExpansionPanel("ESC Temp")
    esc_panel:open(false)
    local esc_warn_line = esc_panel:addLine("Warning")
    addNumberField(esc_warn_line, tempMinimum, tempMaximum, function()
        return floor(displayTemperature(config.esctemp_warn) + 0.5)
    end, function(val)
        local value = tonumber(val) or displayTemperature(THEME_DEFAULTS.esctemp_warn)
        config.esctemp_warn = clamp(storeTemperature(value), 0, config.esctemp_max - 1)
    end, 1, tempSuffix)

    local esc_max_line = esc_panel:addLine("Max")
    addNumberField(esc_max_line, tempMinimum, tempMaximum, function()
        return floor(displayTemperature(config.esctemp_max) + 0.5)
    end, function(val)
        local value = tonumber(val) or displayTemperature(THEME_DEFAULTS.esctemp_max)
        config.esctemp_max = clamp(storeTemperature(value), config.esctemp_warn + 1, 200)
    end, 1, tempSuffix)
end

local function write()
    for key in pairs(THEME_DEFAULTS) do setPref(key, config[key]) end
end

return {configure = configure, write = write}
