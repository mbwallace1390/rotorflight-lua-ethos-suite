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

Rotorflight ETHOS Suite; 800×480 full screen and 784×294 compact widget.
The theme exports the existing `init`, `configure`, and three phase modules.
Configuration uses the current dashboard preference interface, with temperature
limits stored in Celsius and displayed in the radio's selected units.

Vantage is available through automatic discovery in All Themes and through
the supplied registrations in its individual Suite package.

Desktop rendering uses the real suite engine/context with simulated telemetry.
Physical-radio checks remain for final font appearance, phase transitions,
connection changes, and instruction/memory limits.

Original Vantage visual design; telemetry/configuration foundation derived from
the maintained Bastion theme. GPLv3, consistent with the suite.

## Compatible installation

Use a complete All Themes package, or a stock Suite package containing this
theme's registrations. On a compatible All Themes installation, copy the
complete `vantage` folder under
`SCRIPTS:/rfsuite/widgets/dashboard/themes/`, then restart the Suite Lua session
or radio. Select **Vantage** in **System → Settings → Dashboard → Themes**;
configure it in **Dashboard → Settings → Vantage**. Both choices require at least
784 × 294 available pixels. Full-screen rendering is 800 × 480.

All Themes uses `system/vantage` and `dashboard.vantage`. Settings save
on the radio; they do not write flight-controller EEPROM. Preserve user
settings when updating. [Full theme guide](../../../../../../docs/dashboard/vantage.md)
and [submission standard](../../../../../../docs/theme-submissions.md).
