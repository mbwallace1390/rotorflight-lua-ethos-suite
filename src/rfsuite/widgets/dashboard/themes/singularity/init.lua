return {
    name = "Singularity",
    preflight = "preflight.lua",
    inflight = "inflight.lua",
    postflight = "postflight.lua",
    configure = "configure.lua",
    appTheme = {
        name = "Singularity", background = {3, 5, 12}, surface = {13, 17, 34}, surfaceAlt = {13, 18, 34},
        text = {228, 240, 255}, muted = {157, 178, 208}, accent = {170, 97, 255},
        focus = {58, 236, 255}, warning = {255, 190, 70}, error = {255, 72, 110}, border = {75, 101, 140},
        rail = {
            start = {58, 236, 255},
            middle = {170, 97, 255},
            finish = {255, 72, 160}
        }
    },
    standalone = false,
    minResolution = {x = 784, y = 294}
}
