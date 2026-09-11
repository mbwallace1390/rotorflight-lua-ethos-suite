--[[
  America 250 dashboard theme for Rotorflight ETHOS Suite
  Liberty Flight Edition - 1776 to 2026
  Designed for the FrSky X20 Pro (800x480)
  GPLv3
]] --

return {
    name = "America 250",
    preflight = "preflight.lua",
    inflight = "inflight.lua",
    postflight = "postflight.lua",
    configure = "configure.lua",
    appTheme = {
        name = "America 250",
        background = {4, 14, 31}, surface = {8, 24, 47}, surfaceAlt = {12, 34, 61},
        text = {240, 231, 207}, muted = {160, 174, 187}, accent = {240, 231, 207},
        focus = {49, 120, 198}, warning = {216, 170, 78}, error = {184, 48, 49}, border = {68, 91, 116},
        rail = {start = {184, 48, 49}, middle = {240, 231, 207}, finish = {49, 120, 198}}
    },
    standalone = false,
    minResolution = {x = 784, y = 294}
}
