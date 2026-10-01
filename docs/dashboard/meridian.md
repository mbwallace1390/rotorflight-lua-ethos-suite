# Meridian

A navy-black Rotorflight dashboard with cyan clipped frames, mint fuel and
ice-blue ESC-temperature rails, and a large central headspeed readout.

## Where to find it

Select **System → Settings → Dashboard → Themes → Meridian**. Configure its
warnings under **System → Settings → Dashboard → Settings → Meridian**.
The registered selection and settings tile require an available window of at
least 784 × 294. Global choices and warning settings work offline while the
Suite background task runs. A model-specific theme override requires a
connected controller with a known MCU ID.

## Screens

- Preflight checks pack voltage, fuel, BEC supply, ESC temperature, and link.
  Missing readings prevent telemetry-ready status; warnings remain explicit.
- Inflight shows live headspeed between the fuel and thermal rails. Flight
  time, current, BEC, and link share a continuous lower strip. There is no RPM
  threshold, redline, comparison, or RPM scale.
- Postflight labels recorded results and retained duration. Missing history
  remains unavailable; changing models clears the previous flight summary.

800 × 480 views retain the native 44-pixel header with the current model,
transmitter battery/RSSI, centered Rotorflight // Ethos title, and smaller MWRC
signature. The 784 × 294 compact layout omits the native header.

## Settings

| Setting | Meaning and default |
| --- | --- |
| BEC critical | Flags voltage below the threshold; 2.0–14.8 V, default 6.5 V. |
| BEC caution below | Cautions below the threshold; default 7.0 V, above BEC critical. |
| Fuel warning | Flags remaining fuel at or below the threshold; 1–99%, default 25%. |
| ESC warning | Cautions at or above the threshold; default 110°C / 230°F. |
| ESC maximum | Flags at or above the threshold; default 120°C / 248°F, above ESC warning. |
| Link warning | Cautions below the valid percentage threshold; 1–99%, default 50%. |

Save writes Meridian's theme settings locally on the radio. They apply to
models using Meridian and do not write FC EEPROM or change FC protection
settings. Temperatures display in the chosen units and are stored in Celsius.
Use the theme-selection page's **Use same theme** control to apply the preflight
selection to all three phases, or select each phase separately.

## Package and validation

The theme is self-contained under `widgets/dashboard/themes/meridian/`. Its
individual branch scope includes four existing loader/settings registrations;
`init.lua` also supplies metadata for a compatible optional Theme Bridge.
Meridian does not require Bridge. This theme work leaves `main`/`master` unchanged;
registration in source does not itself establish publication.

Desktop tests use the actual Suite engine with approximate LCD fonts. Real-radio
font fitting, telemetry transitions, and memory/instruction budgets remain
unverified. Preflight status describes telemetry checks, not aircraft safety.

Source: `src/rfsuite/widgets/dashboard/themes/meridian/`.
Related controller documentation: [Rotorflight](https://www.rotorflight.org/docs/).
Documented against RFSuite Ethos 2.3.1 theme source on 2026-09-30.
