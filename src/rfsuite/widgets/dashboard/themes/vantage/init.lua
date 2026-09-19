-- Vantage: precision cockpit dashboard for Rotorflight Ethos.
-- Original visual design for MWRC; telemetry integration derived from Aegis.
-- GPLv3
return {
    name = "Vantage",
    preflight = "preflight.lua",
    inflight = "inflight.lua",
    postflight = "postflight.lua",
    configure = "configure.lua",
    appTheme = {
        name = "Vantage",
        background = {8, 14, 20}, surface = {17, 27, 36}, surfaceAlt = {22, 35, 46},
        text = {231, 242, 246}, muted = {130, 156, 170}, accent = {137, 220, 241},
        focus = {98, 215, 159}, warning = {245, 185, 94}, error = {255, 105, 112},
        border = {71, 97, 113},
        rail = {start = {137, 220, 241}, middle = {124, 156, 207}, finish = {245, 185, 94}}
    },
    standalone = false,
    minResolution = {x = 784, y = 294}
}
