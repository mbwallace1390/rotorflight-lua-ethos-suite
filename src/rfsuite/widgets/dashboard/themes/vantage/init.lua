-- Vantage: precision cockpit dashboard for Rotorflight Ethos.
-- Original visual design for MWRC; telemetry integration derived from Aegis.
-- GPLv3
return {
    name = "Vantage",
    preflight = "preflight.lua",
    inflight = "inflight.lua",
    postflight = "postflight.lua",
    configure = "configure.lua",
    standalone = false,
    minResolution = {x = 784, y = 294}
}
