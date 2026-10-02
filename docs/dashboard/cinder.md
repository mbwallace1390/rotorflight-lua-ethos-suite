# Cinder

A matte charcoal Rotorflight dashboard with etched copper frames, warm cream
readings, and a sage fuel bar. Its asymmetric flight view places headspeed and
time beside stacked fuel, ESC temperature, current, and pack-voltage instruments.

## Where to find it

Select **System → Settings → Dashboard → Themes → Cinder**. Configure its warnings
under **System → Settings → Dashboard → Settings → Cinder**. The registered
selection and settings tile require an available window of at least 784 × 294.
Global choices and warning settings work offline while the Suite background
task runs. A model-specific theme override requires a connected controller
with a known MCU ID.

## Screens

- Preflight distinguishes complete checks, missing signals, connection loss,
  and configured warnings. Missing readings never produce a ready indication.
- Inflight prioritizes live headspeed and operating measurements. There is no
  RPM threshold, redline, comparison, or RPM scale.
- Postflight explicitly presents recorded duration, fuel, temperature, current,
  consumption, cell voltage, BEC, and link. Missing history stays unavailable;
  valid zero history and the current flight summary survive disconnect.
  Changing models clears retained results from the previous aircraft.

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
| ESC maximum | Flags at or above the threshold; default 150°C / 302°F, above ESC warning. |
| Link warning | Cautions below the valid percentage threshold; 1–99%, default 50%. |

Save writes Cinder's theme settings locally on the radio. They apply to models
using Cinder and do not write FC EEPROM or change FC protection settings.
Temperatures display in the chosen units and are stored in Celsius. Use the
theme-selection page's **Use same theme** control to apply the preflight choice
to all three phases, or select each phase separately.

## Package and validation

The theme is self-contained under `widgets/dashboard/themes/cinder/`. The
All Themes package discovers it automatically. Keep its complete folder and
helpers together when updating a compatible installation, then restart the
Suite Lua session or radio. Its palette metadata is retained for the existing
All Themes integration; the dashboard does not require a separate Bridge install.

Desktop tests use the actual Suite engine with approximate LCD fonts. Real-radio
font fitting, telemetry transitions, and memory/instruction budgets remain
unverified. Preflight status describes telemetry checks, not aircraft safety.

Source: `src/rfsuite/widgets/dashboard/themes/cinder/`.
Related controller documentation: [Rotorflight](https://www.rotorflight.org/docs/).
Documented against RFSuite Ethos 2.3.1 theme source on 2026-10-02.
