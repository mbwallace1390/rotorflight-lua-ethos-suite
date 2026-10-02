-- Ink & Halo: Rotorflight dashboard companion to the native ETHOS theme.
-- GPLv3
return {
    key = "inkhalo",
    name = "Ink & Halo",
    preflight = "preflight.lua", inflight = "inflight.lua", postflight = "postflight.lua",
    configure = "configure.lua",
    appTheme = {
        name = "Ink & Halo",
        background = {8, 11, 16}, surface = {13, 16, 23}, surfaceAlt = {23, 29, 40},
        text = {244, 247, 252}, muted = {181, 191, 206}, accent = {189, 215, 255},
        focus = {189, 215, 255}, warning = {230, 199, 134}, error = {242, 147, 156},
        border = {84, 100, 122},
        rail = {start = {189, 215, 255}, middle = {244, 247, 252}, finish = {189, 215, 255}},
    },
    standalone = false,
    minResolution = {x = 784, y = 294},
}
