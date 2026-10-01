-- Meridian: twin-rail Rotorflight telemetry dashboard.
-- GPLv3
return {
    key = "meridian",
    name = "Meridian",
    preflight = "preflight.lua", inflight = "inflight.lua", postflight = "postflight.lua",
    configure = "configure.lua",
    appTheme = {
        name = "Meridian",
        background = {3, 12, 18}, surface = {5, 17, 24}, surfaceAlt = {12, 29, 39},
        text = {232, 245, 255}, muted = {170, 197, 217}, accent = {127, 222, 240},
        focus = {127, 222, 240}, warning = {244, 185, 94}, error = {255, 115, 125},
        border = {55, 106, 127},
        rail = {start = {132, 224, 182}, middle = {232, 245, 255}, finish = {127, 222, 240}},
    },
    standalone = false,
    minResolution = {x = 784, y = 294},
}
