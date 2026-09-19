# Ethos Lua performance and lifecycle

Ethos radios are memory- and CPU-constrained embedded devices. `wakeup()`
runs many times per second and `paint()` runs on every screen refresh — any
sloppiness in those two functions is the single biggest source of stutter,
GC pauses, and "the radio feels laggy" complaints. These rules are distilled
from Rotorflight's own internal contributor guidelines for their Ethos suite
and apply to any Ethos widget/tool/system-tool script, not just Rotorflight
ones.

## 1. Treat `wakeup`, `paint`, and any scheduler/telemetry callback as hot paths

Anything called every loop iteration should minimize **allocating**. Lua's garbage
collector runs more often the more garbage you create, and on an embedded
radio that shows up as visible frame hitches.

**Avoid in hot paths:**
- Allocating new tables/arrays every `wakeup()` (e.g. `local t = {}` inside the function body).
- Rebuilding formatted strings (`string.format(...)`) every wakeup when the underlying value hasn't changed.
- Recreating closures/handler functions repeatedly for buttons or callbacks that don't change.
- Repeated `lcd.loadMask` / bitmap loads without caching the result.
- Repeated `field:enable(...)` or similar state-setting calls when the state hasn't actually changed.
- Replacing a live queue/collection table (`queue = {}`) when clearing it in place is sufficient.

**Prefer instead:**
- Reuse buffers/tables declared once (e.g. as an upvalue or in the widget's persistent `create()` state) and clear them in place: `for k in pairs(t) do t[k] = nil end`.
- Cache computed/formatted values and only recompute when the underlying (rounded/quantized) value actually changes — gate with `if last ~= current then ... end`.
- Cache resolved `Source` objects, color values, mask/image lookups, and anything else derived from stable inputs.
- Reuse handler functions per widget/button instead of building a new closure on every rebuild.
- Prebuild any small animation/state tables (e.g. loading-dots frames) once instead of computing them with `string.rep` every tick.

## 2. Localize hot globals

Lua global lookups are a table lookup every call. In any function that runs
frequently, localize the globals/library functions you use at the top of the
file:

```lua
local floor = math.floor
local format = string.format
local system_getSource = system.getSource
```

Then call the localized upvalue instead of the global inside hot loops.

## 3. Cleanup on close

Trace the actual close/destroy caller for each owner. The bundled Ethos
`registerWidget` API does not document `close`; adding a function with that
name alone does not establish a cleanup path. Use documented host lifecycle
callbacks, explicit suite callers, and model/configuration reset paths as
appropriate. Keep caches bounded even if no destruction callback is available.

When an owner is actually closed/destroyed:
- Unsubscribe bus callbacks and cancel pending owner-specific operations.
- Close any open progress/save dialogs.
- Close any open file handles.
- Clear page-specific / widget-specific caches.
- Clear image/mask caches you own (don't leave them referenced after the owner is gone).
- `nil` out large transient references you no longer need so the GC can reclaim them.

When clearing a collection you intend to reuse, wipe keys in place rather
than replacing the table — only replace the whole table when you specifically
need index-reset semantics (e.g. a numeric array where old numeric gaps would
matter).

## 4. Change detection over recomputation

Gate expensive work (formatting, redraw, MSP writes) behind explicit
comparisons: store the last value you acted on, compare the new value, and
only act if they differ. This is the single highest-leverage pattern in the
whole list — most "wasted work" bugs are a missing `if last ~= current`.

## 5. Don't log/diagnose in hot paths unguarded

Debug prints or diagnostic logging inside `wakeup`/`paint` should be gated
behind an explicit debug flag/preference that defaults off. Unconditional
logging in a hot path is itself a performance bug.

## 6. Scope discipline when editing an existing script

If you're modifying an existing script rather than writing one from scratch:
- Keep the diff focused and minimal — don't reformat or refactor unrelated code while fixing one thing.
- Don't touch files/sections unrelated to the requested change.
- If the script has generated files (e.g. a menu manifest, i18n locale file) driven by a source-of-truth file elsewhere, edit the source and regenerate — don't hand-edit the generated output.

## 7. Validate before calling it done

Before considering a script finished, mentally check:
- Are new allocations bounded and necessary? Move static work out of hot paths and only reformat when displayed values change.
- Is there a cleanup/close path for every new dialog, file handle, or cache you added?
- Does the widget handle absent and stale telemetry, reconnect, valid zero readings, and model changes? A cached numeric `Source:value()` alone does not prove freshness; check `Source:state()`.
- Do settings changes update text/colors even when the telemetry reading stays steady?
- Does `configure()` (if present) validate user input ranges before writing them?
