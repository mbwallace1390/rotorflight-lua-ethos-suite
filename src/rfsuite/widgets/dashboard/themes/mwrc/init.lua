--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local init = {
    name = "mwrc",
    preflight = "preflight.lua",
    inflight = "inflight.lua",
    postflight = "postflight.lua",
    configure = "configure.lua",
    appTheme = {
        name = "MWRC", background = {5, 8, 14}, surface = {12, 18, 28}, surfaceAlt = {30, 45, 60},
        text = {230, 240, 255}, muted = {120, 142, 164}, accent = {0, 240, 255},
        focus = {57, 255, 20}, warning = {255, 170, 0}, error = {255, 0, 60}, border = {64, 86, 110},
        rail = {
            start = {0, 240, 255},
            middle = {57, 255, 20},
            finish = {255, 170, 0}
        }
    },
    standalone = false,
    minResolution = {x = 784, y = 294}
}

return init
