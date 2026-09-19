# Vantage

A graphite and ice-blue cockpit theme created for MWRC's Rotorflight Ethos collection.

- **Preflight:** a five-signal launch checklist with prominent pack/fuel readings.
- **Inflight:** a sweeping headspeed instrument with compact fuel, thermal, power,
  and radio-health readings.
- **Postflight:** recorded flight duration and peak/minimum telemetry in a flight report.

The header retains the automatic craft/model name, transmitter battery, and radio
signal. `Rotorflight // Ethos` is followed by a smaller, muted `MWRC` signature.
Native Ethos fonts and LCD drawing keep the theme independent of large bitmap assets.

## Target

Rewritten `radio-all-themes` suite; 800×480 full screen and 784×294 compact widget.
The theme exports the existing `init`, `configure`, and three phase modules.
Configuration uses the current dashboard preference interface, with temperature
limits stored in Celsius and displayed in the radio's selected units.

This is a new theme folder only. The suite's fixed theme-picker registrations
have not been changed, so Vantage is not yet a separate menu selection.

Desktop rendering uses the real suite engine/context with simulated telemetry.
Physical-radio checks remain for final font appearance, phase transitions,
connection changes, and instruction/memory limits.

Original Vantage visual design; telemetry/configuration foundation derived from
the maintained Aegis theme. GPLv3, consistent with the suite.
