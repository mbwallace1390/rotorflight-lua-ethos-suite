# Vantage

A precision cockpit for rotorcraft pilots. Vantage draws on the instrument detail,
dark surfaces, and strong flight telemetry in MWRC's existing collection, with
an asymmetric layout and a calmer use of color.

## Visual system

- Graphite `#080E14`: uninterrupted screen background.
- Instrument surface `#111B24`: quiet separation of functional groups.
- Ice blue `#89DCF1`: the main rotor instrument and active readings.
- Amber `#F5B95E`: reserve/warning cues and selected report highlights.
- Porcelain `#E7F2F6`: primary values.
- Slate `#829CAA`: secondary labels and the small MWRC signature.

Native Ethos fonts keep the design light and readable: large numeric headspeed
and duration, medium live readings, and small supporting labels. Actual signal
quality and configured limits drive the warning colors.

## Three flight screens

Preflight pairs an explicit telemetry checklist with a large pack/fuel readout.
Inflight uses a sweeping rotor-speed instrument with compact power and fuel
readings alongside it. Postflight prioritizes recorded duration and peak/minimum
statistics in a flight report. No invented horizon, navigation, timeline, or
flight-quality score is shown.

The automatic model-name area, radio battery, and radio signal indicators stay
in the suite's normal header. `Rotorflight // Ethos` is prominent; `MWRC` is a
smaller muted signature. Full-screen 800×480 and compact 784×294 layouts are
the targets. Suite core files remain unchanged.

## Integration constraint

Vantage lives in its own `src/rfsuite/widgets/dashboard/themes/vantage` folder.
This suite branch uses fixed theme lists, so creating that folder alone does not
add a separate theme-picker entry. This work follows the request to create the
folder and leaves those core registrations unchanged.
