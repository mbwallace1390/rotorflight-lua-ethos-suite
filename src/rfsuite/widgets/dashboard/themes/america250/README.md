# America 250 — Liberty Flight Edition

America 250 is an original commemorative Rotorflight ETHOS dashboard theme celebrating the United States semiquincentennial, **1776–2026**. It combines classic American aerospace instrumentation with Revolutionary-era shield, star, parchment, navy, red, and gold details.

## Screens

- **Liberty Readiness:** preflight readiness shield surrounded by 13 stars, plus Smart Fuel, BEC, ESC temperature, radio link, profiles, pack voltage, and arm/governor state.
- **Freedom Flight:** central headspeed instrument with a 13-star anniversary ring, flight timer, throttle, ESC temperature, Smart Fuel, current, BEC, link quality, consumed capacity, and governor state.
- **Mission Debrief:** automatic mission grade and nine-stat postflight report with a 250 / 1776–2026 anniversary crest.

## Design notes

- Built for the FrSky X20 Pro at 800×480.
- Vector dashboard graphics; the included 70×70 `icon.png` is used only by the theme selector.
- Original commemorative artwork rather than an official America250 campaign logo.
- Includes the **MWRC** author watermark in the common header on every screen.
- Uses the normal Rotorflight dashboard telemetry aliases and configurable warning thresholds.
- Uses drawn separator dots instead of unsupported UTF-8 bullet glyphs on ETHOS fonts.


## Compatible installation

Use a complete All Themes package, or a stock Suite package containing this
theme's registrations. On a compatible All Themes installation, copy the
complete `america250` folder under
`SCRIPTS:/rfsuite/widgets/dashboard/themes/`, then restart the Suite Lua session
or radio. Select **America 250** in **System → Settings → Dashboard → Themes**;
configure it in **Dashboard → Settings → America 250**. Both choices require at least
784 × 294 available pixels. Full-screen rendering is 800 × 480.

All Themes uses `system/america250` and `dashboard.america250`. Settings save
on the radio; they do not write flight-controller EEPROM. Preserve user
settings when updating. [Full theme guide](../../../../../../docs/dashboard/america250.md)
and [submission standard](../../../../../../docs/theme-submissions.md).
