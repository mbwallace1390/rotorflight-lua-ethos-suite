return {
    name = "Zafira",
    preflight = "preflight.lua",
    inflight = "inflight.lua",
    postflight = "postflight.lua",
    configure = "configure.lua",
    appTheme = {
        name = "Zafira", background = {34, 26, 42}, surface = {45, 34, 54}, surfaceAlt = {57, 42, 68},
        text = {246, 239, 255}, muted = {190, 166, 199}, accent = {255, 199, 91},
        focus = {58, 238, 216}, warning = {255, 166, 62}, error = {255, 74, 96}, border = {151, 107, 160},
        rail = {
            start = {255, 199, 91},
            middle = {58, 238, 216},
            finish = {255, 74, 180}
        }
    },
    standalone = false,
    minResolution = {x = 784, y = 294}
}
