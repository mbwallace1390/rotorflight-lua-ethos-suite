# Rotorflight Suite rewrite and theme integration

These pointers were checked against the `radio-all-themes` checkout on 2026-09-07.
Recheck the actual code when the branch changes; old architecture comments
and theme guides may outlive the APIs they describe.

## Ownership and load paths

- `src/rfsuite/main.lua` initializes independent `tasks/background.lua`,
  `app/tool.lua`, and `widgets/dashboard.lua` subsystems. There is no global
  `rfsuite` runtime table. `lib/bus.lua` carries cross-subsystem messages.
- `lib/require.lua` handles module caching. Copy the existing local loader
  pattern instead of installing a new global or loading another subsystem's
  private state.
- App pages are `app/pages/*.lua`. Inspect the live `MENUS` table and page
  loader before applying old `app/modules/manifest.lua` generator guidance.
- MSP transport/queue lives in `tasks/msp/`; neutral encoders and decoders are
  `lib/msp_*.lua`. Do not resurrect `tasks/scheduler/...` paths from old skills.
- Respect `docs/memory-and-module-lifecycle.md` and existing unsubscribe /
  owner cleanup paths. Forced GC does not repair retained references.

## Dashboard themes

Current theme modules obtain a local compatibility facade:

```lua
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")
```

That `rfsuite` is a dashboard-owned facade, not the old suite singleton.
Read `widgets/dashboard/context.lua` to verify each requested field/helper.
Do not write arbitrary shared state into the facade or retain its mutable
current-widget/session data as though it belongs to one permanent instance.

Trace these callers together:

1. `widgets/dashboard.lua` resolves theme keys, loads `init.lua`, and selects
   `preflight`, `inflight`, or `postflight` files.
2. `widgets/dashboard/engine.lua` consumes phase tables containing `layout`,
   `boxes`, and optional `header_layout`/`header_boxes`.
3. `widgets/dashboard/objects/` implements the actual box types and their
   callbacks. Verify a property's reader before assuming an old theme field
   still works.
4. `app/pages/settings_dashboard_settings.lua` hosts the configuration module;
   the current contract dispatches `configure()` and `write()`. Use existing
   `dashboard.getPreference`/`savePreference` calls and the correct theme key.

`standalone` in theme metadata does not establish a standalone-widget
lifecycle. The current dashboard does not dispatch arbitrary theme `init`,
`event`, or `close` hooks. In particular, a `func` box wakeup receives
`(box, telemetry)` and returns its cache. Its paint function has positional
geometry plus box/cache parameters, but the current wrapper can pass nil as
the final telemetry argument. Use the wakeup cache or the local context's
telemetry facade; do not assume `telemetry["voltage"]` is a numeric reading.

The current suite uses explicit theme registration lists. Merely dropping a
folder in `rfsuite.user/dashboard` does not prove it is discoverable. Inspect
the live loader and settings choices. When core edits are prohibited, adapt
already registered theme folders and report any limitation that cannot be
resolved within the authorized files.

## Theme Bridge

On a checkout containing `app/theme_bridge.lua`, inspect its callers in
`app/tool.lua`, its small theme metadata (`init.lua` / `appTheme`), and the
settings source together. The bridge adapts dashboard identity to app chrome;
it should not load complete dashboard phase layouts to draw the app.

Keep metadata reads and palette compilation out of paint, and preserve the
bridge's throttled wakeup. Test all theme IDs, global and per-model choices,
flight phases, disabled/unknown themes, and missing background-task data.
Check `open()` subscription setup and that the actual tool close path calls
`clearCache()` to unsubscribe. Clearing a color table alone does not release
bus-held callback closures.

## Integration evidence

Use the checkout's live examples and facade instead of copying old guides
verbatim. Validate phase tables and custom callbacks at each supported size;
check no-telemetry placeholders, visible warning thresholds, theme switches,
reopening the app, and state-specific choices. A mock renderer can verify
layout geometry and callback compatibility; hardware still establishes
Ethos font metrics, instruction budgets, real sensor freshness, and memory
behavior during repeated app/phase/theme transitions.
