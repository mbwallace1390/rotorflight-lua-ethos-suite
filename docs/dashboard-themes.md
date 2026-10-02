# Dashboard Themes Developer Guide — Comprehensive Reference

This document describes installing and creating dashboard themes in Rotorflight. The folder-discovery behavior below applies to the `radio-all-themes` build; older releases and individual theme branches may still use fixed theme lists. Object examples must be checked against the `widgets/dashboard/objects/` implementation in the Suite version being targeted.

---

## 1. Directory & File Structure

Rotorflight dashboard themes and objects are organized under:

```
<SCRIPTS>/rfsuite/widgets/dashboard/
├── objects/           # Reusable widget implementations (dial, gauge, image, etc.)
│   ├── dial.lua
│   ├── dial/
│   │   ├── image.lua
│   │   └── rainbow.lua
│   ├── func.lua
│   ├── func/func.lua
│   ├── gauge.lua
│   ├── gauge/
│   │   ├── arc.lua
│   │   ├── bar.lua
│   │   ├── ring.lua
│   │   └── step.lua
│   ├── image.lua
│   ├── image/
│   │   ├── image.lua
│   │   └── model.lua
│   ├── navigation.lua
│   ├── navigation/ah.lua
│   ├── text.lua
│   ├── text/
│   │   ├── apiversion.lua
│   │   ├── armflags.lua
│   │   ├── blackbox.lua
│   │   ├── clock.lua
│   │   ├── craftname.lua
│   │   ├── governor.lua
│   │   ├── pidrates.lua
│   │   ├── session.lua
│   │   ├── stats.lua
│   │   ├── telemetry.lua
│   │   ├── text.lua
│   │   └── watts.lua
│   ├── time.lua
│   └── time/
│       ├── count.lua
│       ├── flight.lua
│       └── total.lua
└── themes/            # Installed themes
    ├── default/
    │   ├── icon.png
    │   ├── init.lua       # Theme metadata (name, state scripts, configure)
    │   ├── preflight.lua  # Preflight layout
    │   ├── inflight.lua   # In-flight layout
    │   └── postflight.lua # Post-flight layout
    ├── aerc/
    ├── rt-rc/
    ├── rfstatus/
    ├── timer/
    └── ...
```

**System vs User Themes**

* **System**: `SCRIPTS:/rfsuite/widgets/dashboard/themes/<themename>/`
* **User**:   `SCRIPTS:/rfsuite.user/dashboard/<themename>/`

The All Themes build discovers installed folders through `lib/dashboard_themes.lua`.
System and user themes are separate choices: `system/<folder>` and
`user/<folder>`. User choices have **(User)** added to their display name. A user
theme does not automatically override a system theme with the same folder name;
their selections and saved instrument settings remain independent. The user
root is outside the Suite package's `rfsuite` installation folder.

### Installing another theme

1. Install a complete, properly localized All Themes package containing folder
   discovery once. Keep the package's Suite and Theme Bridge dependencies
   together; copying just the discovery module into an older release is not a
   supported installation.
2. Copy the theme's complete folder, including `init.lua`, phase modules,
   configuration module, helper modules and assets, into its documented system
   or user location. For example, a system theme's metadata would be at
   `SCRIPTS:/rfsuite/widgets/dashboard/themes/example/init.lua`.
3. Fully restart the radio or restart the Suite's Lua session. Opening and
   closing a settings page does not refresh the cached catalog. A full restart
   is also required after updating or removing a theme folder.
4. Open **System → Settings → Dashboard → Themes**, choose the theme and Save.
   Use **Dashboard → Settings** for its optional instrument controls.

Do not rename or move a supplied theme without checking its module paths.
Several bundled themes load helpers from a fixed
`widgets/dashboard/themes/<folder>/` path. Installing one solely in the user
root requires code that supports that location.

A missing selected theme renders Default while preserving the saved selection
until it is changed. A theme hidden by its minimum resolution will not appear
in the choices for that window. Missing or invalid metadata is skipped; folder
discovery is not a full execution test of the phase scripts. An optional theme whose initialization or phase module fails during loading uses Default for the rest of that theme-cache session, avoiding repeated file reads. A settings update or script restart clears that failure cache. A configuration-load or form-build failure returns to its tile grid with **Loading failed**.
If the radio cannot list theme folders, the Suite retains its stock choices;
additional folders require working directory listing support.

### Packaging and verification

New system theme folders under `src/rfsuite/widgets/dashboard/themes/` are
included recursively by the normal Suite package builder. They need no theme
allowlist or package file-list edit in this All Themes build. The package's
manifest selects `rfsuite/**`; it does not include the sibling
`rfsuite.user/dashboard/` directory.

```text
python bin/package/build_package.py --lang en --artifact-version theme-check --output-dir build/theme-package
python bin/package/validate_ethos_manifest_zip.py build/theme-package/rotorflight-lua-ethos-suite-theme-check-en.zip
```

The builder resolves `@i18n(...)@` tokens for the selected language. A separately
distributed theme must also have its tokens resolved before it is copied to the
radio; discovery does not translate raw source tokens. Keep helpers and assets
at the paths the theme actually loads.

Desktop Lua tests, layout previews and package validation can check discovery,
saved choices and module loading. They do not establish physical-radio font,
key-dispatch, memory or instruction-budget acceptance.

---

## 2. Theme Lifecycle Hooks

Each theme may implement the following Lua modules:

* **`init.lua`** (required): returns a metadata table with a display `name`, phase filenames, optional `configure`, `minResolution` and `appTheme`.
* **`preflight.lua`**: returns a layout table for preflight.
* **`inflight.lua`**: returns a layout table for inflight.
* **`postflight.lua`**: returns a layout table for postflight.
* **`configure.lua`** (optional): exposes a configuration UI and saves preferences.

Compiled `.luac` files can be supplied in place of matching `.lua` files,
including `init.luac`; use bytecode compatible with the target radio firmware.

Keep `init.lua` lightweight and free of display or telemetry side effects: it
can execute during discovery. Its load and execution are protected with
`pcall`; missing, invalid or failing metadata is skipped. Phase and
configuration filenames must be safe local basenames ending in `.lua` or
`.luac`, not arbitrary paths. Omitted phase filenames use the corresponding
`preflight.lua`, `inflight.lua` and `postflight.lua` names. All three phase files
must be present. Discovery does not execute them, so a valid catalog entry can
still contain runtime errors that require testing. Configuration files are
also checked for presence, not executed during the scan.

`minResolution = {x = 784, y = 294}` restricts the choices to a sufficiently
large window. Optional `appTheme` supplies the Theme Bridge palette; without
it, the Bridge uses the native radio colors. Existing built-in labels and
compatibility aliases are retained: Bastion's `bastion` folder still uses the
saved `system/aegis` choice and `dashboard.aegis` settings, and
`system/bastion` resolves to that same choice.

Example **`init.lua`**:

```lua
return {
  name = "Example Theme",
  preflight = "preflight.lua",
  inflight = "inflight.lua",
  postflight = "postflight.lua",
  configure = "configure.lua",
  minResolution = {x = 784, y = 294},
  standalone = false
}
```

Example **`preflight.lua`**:

```lua
local function themeColor(constName, fallback)
  if type(lcd.themeColor) == "function" then
    local key = _G[constName]
    if type(key) == "number" then return lcd.themeColor(key) end
  end
  return fallback
end

return {
  layout = {
    selectcolor  = themeColor("THEME_FOCUS_COLOR", lcd.RGB(255,128,0)),
    selectborder = 3,
    defaultbg    = themeColor("THEME_PRIMARY_BGCOLOR", lcd.RGB(0,0,0)),
  },
  boxes = {
    { col = 1, row = 1, type = "text", subtype = "telemetry", source = "altitude", title = "ALT", unit = "m" },
    { x_pct = 0.5, y_pct = 0.1, w_pct = 0.4, h_pct = 0.2,
      type = "gauge", subtype = "bar", source = "smartfuel", gaugemin = 0, gaugemax = 100,
      title = "Fuel", unit = "%"
    },
  }
}
```

For custom rendering in theme examples, prefer `lcd.themeColor(...)` with a fallback like the helper above instead of branching directly on `lcd.darkMode()`. That keeps examples compatible with both newer themed radios and older dark/light-only radios.

---

## 3. Box Definition: Common Fields

Each entry in the `boxes` array is a table with the following core fields:

| Field                             | Type                   | Description                                                               |
| --------------------------------- | ---------------------- | ------------------------------------------------------------------------- |
| `type`                            | string                 | Object type (see Section 4).                                              |
| `subtype`                         | string                 | Variant of the object (defaults vary per type).                           |
| **Positioning**                   |                        | *One of:*                                                                 |
| ├ `x_pct`,`y_pct`,`w_pct`,`h_pct` | number (0–1 or 0–100)  | Percentage of dashboard area (responsive).                                |
| ├ `x`,`y`,`w`,`h`                 | integer                | Pixels from top-left (absolute).                                          |
| └ `col`,`row`,`colspan`,`rowspan` | integer                | Grid cell coordinates (classic).                                          |
| **Styling**                       |                        |                                                                           |
| `color`,`bgcolor`,`titlecolor`    | color                  | Value, background, and title colors (fallback to theme defaults).         |
| `font`,`titlefont`                | font                   | Fonts for value and title.                                                |
| `padding`,`titlepadding`          | number                 | Padding around content.                                                   |
| **Labeling**                      |                        |                                                                           |
| `title`                           | string                 | Label text (if omitted, some subtypes auto-generate).                     |
| `unit`                            | string                 | Unit text appended to values.                                             |
| **Data**                          |                        |                                                                           |
| `source`                          | string                 | Telemetry field name or other data key.                                   |
| `value`                           | any                    | Static value (overrides `source`).                                        |
| `transform`                       | string/function/number | Built-in math transform or custom function for value adjustments.         |
| `novalue`                         | string                 | Text to display when data is missing (default "-").                       |
| **Interactivity**                 |                        |                                                                           |
| `onpress`                         | function               | Callback `(widget, box, x, y, cat, val)` when the box is pressed/focused. |

> **Priority:** Percent-based > Pixel-based > Grid-based. Whichever mode is detected first is used.

---

## 4. Object Types & Subtypes

The `type` field selects an object wrapper under `objects/`. Use `subtype` to choose specific implementations.

### 4.1 Text (`type = "text")`

Outputs static or telemetry-based text. Subtypes located in `objects/text/`:

| `subtype`    | Description                            | Default source    |
| ------------ | -------------------------------------- | ----------------- |
| `text`       | Static text string defined in `value`. | –                 |
| `telemetry`  | Telemetry value (`source` required).   | –                 |
| `apiversion` | Shows Rotorflight API version (auto).  | –                 |
| `craftname`  | Shows current model name (auto).       | –                 |
| `blackbox`   | Used/total Blackbox storage (auto).    | –                 |
| `governor`   | Governor state (auto).                 | –                 |
| `armflags`   | Armed status flags (auto).             | –                 |
| `session`    | Any session key (`source` required).   | e.g., `"rx_rssi"` |
| `stats`      | Session summary stats (auto).          | –                 |
| `clock`      | Clock display (auto).                  | –                 |
| `pidrates`   | PID/Rates profile display (auto).      | –                 |
| `watts`      | Voltage/Current => Power (auto).       | –                 |

**Common Parameters:**

* `value` (for `text` subtype)
* `source`, `decimals`, `unit`, `font`, `textcolor`, `title`, `titlefont`, `titlecolor`, `align`, `padding`, `novalue`, `transform`.

**Example:**

```lua
{ type = "text", subtype = "telemetry", source = "volt", title = "VOLTAGE", unit = "V" }
```

### 4.2 Gauge (`type = "gauge")`

Bar, ring, and arc gauges under `objects/gauge/`:

| `subtype` | Widget     | Key Parameters                                                                         |
| --------- | ---------- | -------------------------------------------------------------------------------------- |
| `bar`     | Bar gauge  | `gaugemin`, `gaugemax`, `gaugeorientation`, `thresholds`, `battery`, `batterysegments` |
| `ring`    | Ring gauge | Circular ring with fill `%`                                                            |
| `arc`     | Arc gauge  | `startAngle`, `sweep`, `arcThickness`, `arcColor`, `arcBgColor`, `thresholds`          |

**Shared Gauge Parameters:**

* `source` / `value`, `unit`, `transform`, `decimals`, `font`.
* `bgcolor`, `fillcolor`, `gaugecolor`, `gaugebgcolor`.
* `title`, `titlepos`, `titlealign`, `titlecolor`, `padding`.
* `thresholds`: array of `{ value, fillcolor, textcolor }`.

**Simple Shortcuts:**

* `type = "fuelgauge"` ⇒ preconfigured fuel bar.
* `type = "voltagegauge"` ⇒ preconfigured voltage bar.
* `type = "arcgauge"` ⇒ alias for `{ type = "gauge", subtype = "arc" }`.

**Example:**

```lua
{ type = "gauge", subtype = "arc", source = "volt",
  gaugemin = 9, gaugemax = 12.6,
  arcThickness = 14, startAngle = 225, sweep = 270,
  title = "VOLTAGE", unit = "V", titlepos = "bottom" }
```

### 4.3 Image (`type = "image")`

Displays images or model icons (`objects/image/`):

| `subtype` | Description                       | Key Params                                                     |
| --------- | --------------------------------- | -------------------------------------------------------------- |
| `image`   | Custom image from `value`/`path`. | `value` (path), `aspect`, `align`, `imagewidth`, `imageheight` |
| `model`   | Shows current model’s icon.       | `imagewidth`, `imageheight`                                    |

**Example:**

```lua
{ type = "image", subtype = "image", value = "icons/altitude.png", x=10, y=10, w=32, h=32 }
```

### 4.4 Dial (`type = "dial")`

Analog dial widgets (`objects/dial/`):

| `subtype` | Description                    | Key Params                                                                  |
| --------- | ------------------------------ | --------------------------------------------------------------------------- |
| `image`   | Dial with custom image assets. | `dial`, `min`, `max`, `needlecolor`, `needlestartangle`, `needlesweepangle` |
| `rainbow` | Color-gradient dial.           | `min`, `max`, `rainbow` color stops, etc.                                   |

**Example:**

```lua
{ type = "dial", subtype = "image", source = "rpm", dial = "assets/dial1",
  min = 0, max = 8000, needlecolor = "red" }
```

### 4.5 Time (`type = "time")`

Displays flight timer or clock (`objects/time/`):

| `subtype` | Description                       | Key Params                          |
| --------- | --------------------------------- | ----------------------------------- |
| `flight`  | Elapsed flight time (mm\:ss).      | `font`, `title`                     |
| `count`   | Flight count (from model prefs).  | `font`, `title`                     |
| `total`   | Total flight time.                | `font`, `title`                     |

**Example:**

```lua
{ type = "time", subtype = "flight", x_pct=0.8, y_pct=0.05,
  title = "TIMER" }
```

### 4.6 Navigation (`type = "navigation")`

Navigation-style widgets under `objects/navigation/`:

| `subtype` | Description                 |
| --------- | --------------------------- |
| `ah`      | Attitude horizon display.   |

### 4.7 Function (`type = "func")`

Custom drawing logic (`objects/func/func.lua`):

* **`box.wakeup(box, telemetry)`**: return a cache table.
* **`box.paint(x, y, w, h, box, cache, telemetry)`**: full custom rendering.

**Example:**

```lua
{ type = "func", paint = function(x,y,w,h,box,cache,t)
    lcd.drawText(x,y, string.format("%.1fV", t["volt"]))
end }
```

---

## 5. Interactivity & Navigation

* **Selectable Boxes:** any box with `onpress` becomes focusable.
* **Navigation Controls:**

  * Rotary/keyboard: left/right to move focus; Enter to activate.
  * Touch: tap to focus and activate.
* **Custom Highlight:** in `layout`:

  ```lua
  layout.selectcolor  = lcd.RGB(0,200,255)
  layout.selectborder = 2
  ```

---

## 6. Tips & Best Practices

* **Responsive Layout:** prefer percent-based (`*_pct`) for cross-resolution.
* **Performance:** minimize heavy custom `func` paint logic.
* **Modularity:** reuse objects in `objects/`; contribute new subtypes by adding `.lua` in the appropriate folder.
* **Defaults:** omit fields to pick theme or object defaults.

---

*Folder discovery and installation documented against RFSuite Ethos 2.3.1,
All Themes source, 2026-10-02. Check object properties and callbacks against the
target Suite source before using the older object examples above.*
