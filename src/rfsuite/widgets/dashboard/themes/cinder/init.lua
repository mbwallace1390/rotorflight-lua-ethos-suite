-- Cinder: matte charcoal instruments with etched copper edges. GPLv3.
return {
    key = "cinder", name = "Cinder",
    preflight = "preflight.lua", inflight = "inflight.lua", postflight = "postflight.lua",
    configure = "configure.lua", standalone = false,
    minResolution = {x = 784, y = 294},
    appTheme = {
        name = "Cinder", background = {12, 12, 11}, surface = {19, 18, 16},
        surfaceAlt = {31, 27, 23}, text = {242, 234, 215}, muted = {177, 164, 148},
        accent = {224, 153, 101}, focus = {224, 153, 101}, border = {121, 85, 61},
        warning = {233, 184, 108}, error = {239, 128, 117},
        rail = {start = {224, 153, 101}, middle = {169, 105, 69}, finish = {224, 153, 101}},
    },
}
