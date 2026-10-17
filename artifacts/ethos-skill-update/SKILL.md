---
name: ethos-rotorflight-lua
description: Write, review, or migrate FrSky Ethos Lua widgets, Rotorflight Suite dashboard themes, theme bridges, and configuration tools using the target radio API and the checked-out suite architecture.
---

# Ethos and Rotorflight Lua

First identify the host: a standalone Ethos widget, a Rotorflight Suite
dashboard theme, an app page/theme bridge, or a background/configuration task.
These have different state owners and callback contracts. A dashboard theme
is not a script that registers another Ethos widget.

## Match the checked-out version

Read project instructions and the actual entry point before relying on old
paths or bundled examples. For a suite migration, read
[suite-rewrite-and-themes.md](references/suite-rewrite-and-themes.md).
Follow user scope restrictions: a request to adapt themes without changing
the suite core must be solved in those theme folders and any expressly
authorized bridge files.

Record the target radio, Ethos firmware, screen sizes, suite branch/version,
and transport when known. Infer ordinary choices from the checkout; ask only
for missing information that blocks implementation or hardware validation.
Do not infer the Lua language version from generic OpenTX/EdgeTX guidance or
from Doxygen's generator version. If instructions say Lua 5.2 but existing
suite code uses native bitwise operators, document that discrepancy and use a
runtime capable of parsing the actual suite for integration checks. Keep new
standalone examples compatible with their declared target.

## Check only the relevant API references

- [ethos-api/INDEX.md](references/ethos-api/INDEX.md) routes to the bundled API
  snapshot. Check `namespace_system.md`, `class_Source.md`, and the applicable
  `namespace_form.md`/`namespace_lcd.md` sections. The snapshot is a reference,
  not proof that every API exists on the user's firmware. Verify newer or
  uncertain APIs with the target firmware's official FrSky documentation.
- [rotorflight-telemetry-sensors.md](references/rotorflight-telemetry-sensors.md)
  distinguishes suite aliases, radio source names, transport IDs, and stale data.
- [rotorflight-msp.md](references/rotorflight-msp.md) applies to configuration
  work or a task that actually needs MSP. Suite integrations should reuse the
  current bus/queue/codec path.
- Apply [performance-and-style.md](references/performance-and-style.md) to
  wakeup, paint, and scheduler callbacks.

## Standalone widgets

Use [minimal-widget-template.lua](examples/minimal-widget-template.lua) or
[rotorflight-governor-widget.lua](examples/rotorflight-governor-widget.lua) only
for standalone widgets. Both let the user select actual Ethos sources and
use `read`/`write` with `storage` for settings.

The bundled `system.registerWidget` reference documents `key` (up to seven
characters), `name`, `create`, `configure`, `wakeup`, `paint`, `event`, `menu`,
`read`, `write`, `persistent`, and `title`. It does not document a widget
`close` handler. A suite module exposing `close` does not prove Ethos invokes
it; verify dispatch for the target firmware. `registerSystemTool` has a
separate documented close contract. Do not assume `persistent = true` is a
prerequisite for the `read`/`write` hooks or infer its behavior from its name.

Build form rows with `form.addLine(...)`, then pass the returned line to the
field. `form.addNumberField` takes `(line, position, minimum, maximum,
getter, setter)`. A Source field takes `(line, position, getter, setter)`.
Do not pass a widget state table in place of a form line.

`system.getSource` returns a Source object; a suite alias such as `rpm` is not
automatically an Ethos sensor display name. Before treating a cached sensor
reading as live, check `source:state()` and validate its numeric value. Missing
and stale readings should show a placeholder; retained flight statistics
must be explicitly presented as historical. Preserve valid zero readings.

## Review and verification

Check callback argument order, state ownership, source freshness, setting
persistence, and every actual cleanup caller. Exercise disconnected startup,
connection and loss/reconnection, settings changes with steady telemetry,
phase changes, and supported screen sizes. Test changed code with an
appropriate Lua parser/runtime and realistic API stubs; do not describe stub
or generated-image previews as a real-radio or simulator test.

For visuals, preserve each theme's identity while improving information
hierarchy, readable status labels, contrast, and small-screen spacing. Cache
colors, geometry, image assets, and formatted display values. Keep rendering
free of file I/O and preserve bounded background work. State any remaining
device checks explicitly when delivering.
