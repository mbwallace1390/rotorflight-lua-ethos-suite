# Ink & Halo

Rotorflight dashboard companion to the native Ink & Halo ETHOS radio theme.
Ink-black surfaces, pale-blue elliptical halo, soft-white telemetry, and restrained outlined panels.

- Preflight shows five required telemetry checks. Missing readings prevent READY.
- Inflight places headspeed beneath the halo, with fuel, ESC temperature, current, and pack voltage below.
- Postflight presents recorded peaks and minima; it does not calculate a health score.
- Full 800 x 480 views reserve the native 44-pixel header, including the dynamic model name. Compact 784 x 294 views omit that header.
- Threshold settings use the Suite's active `inkhalo` dashboard preference scope. Temperature settings respect Celsius/Fahrenheit display units.

This folder contains the theme only. The Suite's explicit theme picker must register `inkhalo` before normal radio selection is available; no Suite core or picker changes are included here. Theme Bridge palette metadata is supplied in `init.lua`.

Desktop Lua-rendered previews approximate the radio's fonts. Physical-radio visual and instruction-budget acceptance is still required.
