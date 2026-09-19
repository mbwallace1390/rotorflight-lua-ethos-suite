# Rotorflight telemetry: aliases, sources, and freshness

## Choose the correct access layer

Inside a Suite dashboard theme, use the local dashboard context's existing
telemetry facade and inspect its implementation. Outside the suite, use
Ethos `system.getSource` and Source methods. `getField`, `getValue`, and
`getRSSI` patterns from other transmitter firmware are not interchangeable
with this Ethos API.

Three identifiers must stay distinct:

- **Suite alias**: `rpm`, `voltage`, `smartfuel`, `governor`, etc. A key the
  suite maps to session values, computed data, or protocol-specific sources.
- **Radio display name**: the exact discovered name, which the user can
  rename. `system.getSource("Rpm")` only works if that name really exists.
- **Transport selector**: an Ethos selector table containing `category`,
  `appId`, or CRSF-specific fields. Choose it from the current protocol's
  mappings, not from an unrelated example in the general API manual.

For reusable standalone widgets, `form.addSourceField` lets the user select
an actual sensor and `storage` preserves that selection. This also avoids
guessing a name after the user renames a sensor.

## Current suite mapping evidence

Check `src/rfsuite/lib/telemetry_sensors_{sport,crsf}.lua` for task mappings
and `widgets/dashboard/context.lua` for dashboard mappings and aliases.
They do not necessarily expose the same entire catalog. Some useful entries
in the checkout audited 2026-09-07 are:

| Meaning / suite alias | S.Port appId candidates | CRSF/ELRS appId candidates |
|---|---|---|
| Headspeed / `rpm` | `0x0500` | `0x10C0` |
| Governor enum / `governor` | `0x5125`, `0x5450` | `0x1205` |
| Pack voltage / `voltage` | `0x0210`, `0x0211`, `0x0218`, `0x021A` | `0x1011`, `0x1041`, `0x1051`, `0x1080` |
| Firmware fuel percent / `smartfuel` | `0x0600` | `0x1014` |

`0x5FE1` is the suite's locally synthesized Smart Fuel sensor, not the FC's
native firmware fuel channel. Do not confuse the two when choosing a mirror
source. The generic API example `appId = 0x0F10` is not a universal
Rotorflight RPM/governor selector. `CATEGORY_SYSTEM` / `MAIN_VOLTAGE` refers
to transmitter battery voltage, not the model's pack.

Logical link keys also depend on the mapping: `rssi`, `link`, and `vfr` are
not interchangeable physical units. VFR means valid frame rate. A CRSF
fallback may return antenna RSSI rather than percentage link quality, so
verify the actual candidate, unit, and range before assigning a percent
gauge or warning threshold. Do not fabricate a reading for an unsupported
alias such as `volt` merely because an old guide used it.

## Live values and cached sources

For an actual Ethos sensor Source:

```lua
local function liveNumber(source)
    if not source or not source:state() then return nil end
    local value = source:value()
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge then return nil end
    return value
end
```

A cached Source can still return its last numeric value after telemetry
loss. Checking only `value ~= nil` does not establish freshness. Keep valid
zero separate from unavailable data; show `--` for unavailable live data.
Historical flight statistics can remain visible when explicitly identified.

Cache selected/resolved sources, but provide bounded retry for absent
auto-discovered sources and revalidation/model-change cleanup for cached
automatic lookups. Avoid scanning every wakeup or retaining a failed lookup
forever. Quantize the numeric display before formatting and repaint only
when displayed text, warning color, or status changes.

## Governor decoding

The current suite context maps numeric states as follows: 0 OFF, 1 IDLE,
2 SPOOLUP, 3 RECOVERY, 4 ACTIVE, 5 THR OFF, 6 LOST HS, 7 AUTOROT, 8 BAILOUT,
100 DISABLED, 101 DISARMED. Recheck against the targeted Rotorflight firmware
when it changes. Show UNKNOWN for a valid unrecognized code, and `--` for
missing/stale telemetry; do not label either as OFF or DISARMED.
