# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

RFSuite: a Lua-scripted, touch-based GUI suite for the FrSky Ethos transmitter OS, used to configure/tune/diagnose Rotorflight-based helicopter flight controllers over MSP. The runtime code that ships to the radio lives entirely under `src/rfsuite/`; everything else (`bin/`, `.vscode/`) is Python/Node tooling to build, deploy, and localize it.

## Commands

Install Python tooling deps: `python -m pip install -r requirements.txt`

**Menu manifest** (source of truth: `bin/menu/manifest.source.json`, generated: `src/rfsuite/app/modules/manifest.lua`):
```bash
python bin/menu/generate.py          # regenerate after editing manifest.source.json
python bin/menu/generate.py --check  # verify no drift (also run in CI)
```
Never hand-edit `src/rfsuite/app/modules/manifest.lua`; edit the source JSON and regenerate. Keep `docs/menu-structure.md` in sync with structural changes.

**i18n** (source of truth: `bin/i18n/json/<locale>.json`, generated: `src/rfsuite/i18n/<locale>.json`):
```bash
python bin/i18n/update-missing-translations.py [--only <locale...>]
python bin/i18n/update-max-lengths.py [--only <locale...>]
python bin/i18n/build-single-json.py [--only <locale...>]
```
Never hand-edit generated files under `src/rfsuite/i18n/`; edit the source JSON. Keep key structure consistent with `en.json`.

**Lua formatting** (requires `lua-format` on PATH):
```bash
python bin/format_lua.py --help
```

**Packaging / deploy** (used by VS Code tasks, see `.vscode/tasks.json`):
```bash
python .vscode/scripts/deploy.py --lang en --step i18n --step soundpack --step sensors   # deploy to simulator
python .vscode/scripts/deploy.py --radio --lang en --step i18n --step soundpack --step sensors  # deploy to radio
python bin/package/build_package.py --lang en --artifact-version <ver> --artifact-name <name>.zip --output-dir .
python bin/package/validate_ethos_manifest_zip.py <name>.zip
```
VS Code tasks (`Deploy & Launch [SIM]`, `Deploy Radio`, `Deploy Radio [Fast]`, `Deploy Radio + Serial Debug`) wrap these; the `Ethos` VS Code extension is required for the simulator/radio workflow.

There is no Lua unit test suite in this repo. CI (`.github/workflows/pr.yml`, `push.yml`, `release.yml`) only verifies menu manifest freshness (`generate.py --check`), builds per-locale packages, and validates the Ethos manifest inside each zip.

## Architecture

- `src/rfsuite/main.lua` — entry point; sets up `rfsuite.config`, loads/merges `rfsuite.preferences` (from `SCRIPTS:/rfsuite.user/preferences.ini`), initializes `rfsuite.session` runtime state, and starts `rfsuite.tasks` (background) alongside `rfsuite.app` (UI).
- `src/rfsuite/app/` — UI application (`app.lua`), page modules (`modules/`), UI/util libraries (`lib/ui.lua`, `lib/utils.lua`). Each module lives in its own folder under `app/modules/<name>/` with `init.lua` (metadata), `<module>.lua` (a `Page` table implementing `onEnter`/`onDraw`/`onExit`), `help.lua`, and an icon. Modules are listed in the generated `app/modules/manifest.lua` and assembled into menus via `app/modules/sections.lua`.
- `src/rfsuite/tasks/` — background scheduler, MSP protocol handling, telemetry, sensors, logging (`tasks/scheduler/`), and event hooks like connect/disconnect/model-change (`tasks/events/`). Exposed to the rest of the app via `rfsuite.tasks.msp.api` and `rfsuite.tasks.callback`.
- `src/rfsuite/widgets/` — dashboard widgets and toolbox tools (`widgets/dashboard/objects`, `widgets/toolbox`), loaded/configured by modules and pages.
- `src/rfsuite/lib/` — shared utilities (ini parsing, i18n, message bus, ethos event glue).
- `src/rfsuite/i18n/`, `src/rfsuite/audio/` — generated locale JSON and voice packs; not hand-edited (see i18n commands above).
- `bin/menu/`, `bin/i18n/`, `bin/package/`, `bin/sensors/`, `bin/sound-generator/`, `bin/translation-editor/` — build-time tooling; not shipped to the radio.

Reference docs worth reading before non-trivial changes: `docs/system-architecture.md` (module structure, MSP API/apidata system, MSP queue backpressure/tuning), `docs/menu-structure.md`, `docs/i18n-locales.md`, `docs/msp-api.md`, `docs/msp-queue.md`, `docs/dashboard-objects.md`.

### MSP / apidata pattern

Modules don't parse raw MSP data directly — they go through the API loader in `tasks/scheduler/msp/api/`:
```lua
local API = rfsuite.app.Page.apidata.load(apiName)
app.Page.apidata = { api = API, formdata = API.data(), structure = API.data().structure }
```
Read/write via `api.readValue(key)` / `api.setValue(key, newValue)`, then `api.write()` on submit. Async work goes through `rfsuite.tasks.callback.now()` / `api.scheduleWakeup()`. The MSP queue (`tasks/scheduler/msp/mspQueue.lua`) returns `ok, reason, qid, pending` from `add(...)`; on `"duplicate"` or `"busy"` back off rather than retrying immediately, and use stable UUIDs for periodic/retriggerable operations.

## Non-negotiables for changes (from AGENTS.md)

Primary goal: keep behavior correct while minimizing runtime memory churn and CPU load on Ethos radios — these are resource-constrained transmitters, not general-purpose computers.

Treat `wakeup`, `paint`, and scheduler callbacks as hot paths. In hot paths, avoid:
- Allocating new tables/arrays every wakeup, or rebuilding formatted strings when inputs haven't changed.
- Recreating closures/handlers repeatedly for static buttons (reuse per menu/module key).
- Repeated `lcd.loadMask`/image loads without caching, or repeated `field:enable(...)` calls when state is unchanged.
- Replacing a live queue table (`queue = {}`) where clearing it in-place is enough.

Instead: reuse buffers/tables and clear in-place, cache computed/resolved values and update only on change (`if last ~= current then ... end`), and gate UI/state updates behind change detection.

On page/module close: close progress/save dialogs and file handles, clear page-specific and image/mask caches the page owns, and nil out large transient references.

Other rules:
- Don't add logging/diagnostics in hot paths unless guarded by explicit debug preferences.
- Keep changes minimal and scoped to the task; if the repo is already dirty, don't touch unrelated files.
- Before finishing a change: check for menu/i18n generated-file drift if source files were touched, check for new hot-path allocations, and confirm cleanup paths exist for any new dialogs/handles/caches.
