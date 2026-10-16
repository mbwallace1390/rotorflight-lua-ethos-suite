-- Carbon Pulse: neon-framed instruments over carbon fibre.
-- Registration shape adapted from Studio Stratus 98. GPLv3.
return {
    key = "carbonpulse", name = "Carbon Pulse",
    preflight = "preflight.lua", inflight = "inflight.lua", postflight = "postflight.lua",
    configure = "configure.lua", standalone = false,
    minResolution = {x = 784, y = 294},
}
