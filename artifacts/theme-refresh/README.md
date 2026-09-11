# User theme refresh — September 7, 2026

This update contains Aegis, America 250, Liberty Ops 250, MWRC, Singularity,
Zafira, and Theme Bridge. It targets the rewritten `radio-all-themes` branch,
verified at `28c5871ef1b126fbe5600fb804a138ba0b92fb02`. Suite core files are unchanged from that branch.

## Install

1. Back up your radio's six theme folders and `scripts/rfsuite/app/theme_bridge.lua`.
2. Close Rotorflight Suite. Merge this ZIP's `scripts` folder into the radio's
   scripts folder, replacing the included theme files and Theme Bridge.
3. Restart the scripts/radio and select your theme in Suite Settings → Dashboard.

This is a manual overlay, not a complete suite installer. It needs the existing
all-themes branch registrations and bridge hooks. Stock upstream `master` does
not include those registrations; installing this overlay onto stock master alone
does not make the themes selectable. No core patch is included.

## Rewrite integration points

- `main.lua` starts separate background tasks, the app tool, and the dashboard.
  Shared updates travel through `lib/bus.lua`; themes cannot depend on the old
  global suite object.
- Theme files load the local `widgets/dashboard/context.lua` facade. The unchanged
  engine consumes phase layouts and boxes; custom drawing uses cached func boxes.
- Theme configuration is hosted by `app/pages/settings_dashboard_settings.lua`.
  It calls `configure()` and `write()`; instruments read active preferences through
  `dashboard.getPreference()`.
- Theme Bridge uses each theme's small `init.lua` / `appTheme` palette and the
  current flight-state tracker. It avoids loading full dashboard pages for app chrome.

## Changes

- Saved instrument limits now use the rewritten suite's active theme preferences.
- User-entered BEC limits are preserved; Celsius/Fahrenheit settings round-trip.
- Missing/nonfinite readings show placeholders; incomplete preflight readings do
  not claim readiness. Liberty Ops no longer crashes on missing telemetry.
- Six visual identities retain their original character with improved headers,
  contrast, fitted text, compact layouts, and clearer instrument/report cards.
- All six themes use `Rotorflight // Ethos | MWRC` in their top header across
  preflight, in-flight, and postflight. MWRC is a smaller, muted builder signature;
  the main title fits narrower windows while retaining this subtle branding.
- The automatic model-name field remains intact: telemetry supplies the craft name,
  with the selected Ethos model name as the suite's existing fallback.
- Theme palettes are private and cannot alter the suite's cached native palette.
- Liberty Ops' old nonfunctional shortcut buttons are replaced with radio Tools
  menu guidance; the current engine does not dispatch those theme callbacks.
- Theme Bridge preserves phase on same-model reconnect, keeps its tracker state
  private, and rebuilds its canvas when the available screen size changes.

## Verified

432 render cases passed using the unchanged real suite engine/context and a
desktop LCD fixture: six themes × three phases × two sizes (800×480, 784×294)
× four data scenarios × three legacy/native dark/light API modes.
Behavioral tests cover theme settings, units, missing/corrupt data, private
palettes, and historical per-cell voltage after connection loss.
Seven bridge tests pass; three reproduce the original bridge defects.
Core source scope and the ZIP file list/hashes are checked by the bundle builder.

Desktop previews use approximate font metrics and simulated data. They are not
radio screenshots. On the radio, check both window sizes, saved limit changes,
flight-phase transitions, connect/loss/reconnect, C/F temperatures, model changes,
and repeated app opens for readability, instruction-budget errors, and RAM use.

Companion Ethos/Rotorflight skill corrections are provided separately in
`artifacts/ethos-skill-update`. Their two standalone examples passed Lua 5.2
regression checks. Apply these corrections to an existing skill installation;
they are separate from the radio theme overlay.

Vantage is supplied separately in `src/rfsuite/widgets/dashboard/themes/vantage`.
It is a new theme folder; its registration in the suite's fixed picker is outside
this update. The six-theme ZIP continues to contain only the original six themes
and Theme Bridge.
