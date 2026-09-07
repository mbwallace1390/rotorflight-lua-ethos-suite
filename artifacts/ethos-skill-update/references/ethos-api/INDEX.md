# Ethos Lua API Reference — Index

These files are converted from an official Ethos Lua Doxygen reference snapshot.
The footer's 1.9.4 is the Doxygen generator version, not the Ethos firmware version.
The captured firmware version is unspecified; check target-firmware support for
newer or uncertain APIs rather than treating this snapshot as current.
Load only the files you need for the task at hand — don't read all of them.

## Namespaces (global tables you call functions on, e.g. `lcd.color(...)`)

| File | Covers |
|---|---|
| `namespace_system.md` | `system.*` — widget/tool/task registration, version info, memory, audio, sources, exit/emergency |
| `namespace_lcd.md` | `lcd.*` — all drawing primitives: color, font, drawText, drawLine, drawRectangle, drawGauge, drawPoint, bitmaps, window size |
| `namespace_form.md` | `form.*` — building configuration/edit UI (fields, panels, buttons) for widget `configure()` screens |
| `namespace_model.md` | `model.*` — model name, getSensor/setSensor on the active model, timers |
| `namespace_base.md` | Global constants: `CATEGORY_*`, `UNIT_*`, `EVT_*`, `FONT_*`, color/font/event enums. **Large file** — grep for the constant name you need rather than reading it all |
| `namespace_crsf.md` | `crsf.getSensor()` — raw CRSF sensor for `pushFrame`/`popFrame` (MSP-over-CRSF, VTX, etc.) |
| `namespace_multimodule.md` | `multimodule.getSensor()` — equivalent for Multimodule-connected radios |
| `namespace_sport.md` | S.Port sensor access (for radios/receivers using FrSky S.Port telemetry) |
| `namespace_serial.md` | `serial.open()` — raw serial connections (TANDEM radios only) |
| `namespace_storage.md` | File/data persistence helpers |
| `namespace_simulator.md` | Ethos Suite/Companion simulator-specific behavior |

## Classes (objects returned by the above, call methods with `:`)

| File | Covers |
|---|---|
| `class_Source.md` | Object returned by `system.getSource()` — `:value()`, `:state()`, etc. Central to reading any telemetry value |
| `class_CrsfSensor.md` | `:pushFrame()` / `:popFrame()` — send/receive raw CRSF frames, including MSP request/response (commands `0x7A`/`0x7B`) |
| `class_MultimoduleSensor.md`, `class_LuaMultimoduleSensor.md` | Multimodule sensor push/pop equivalents |
| `class_LuaSportFrame.md`, `class_LuaSportSensor.md`, `class_LuaSportSerial.md` | S.Port-level sensor/frame access |
| `class_Bitmap.md`, `class_LuaBitmapBase.md` | Image loading/drawing |
| `class_Button.md`, `class_Slider.md`, `class_NumberEdit.md`, `class_BooleanEdit.md`, `class_TextEdit.md`, `class_Choice.md`, `class_SourceChoice.md`, `class_Curve.md`, `class_FormLine.md` | Form field widgets used inside `configure()` |
| `class_Dialog.md`, `class_ProgressDialog.md`, `class_ExpansionPanel.md` | Dialogs and progress UI, e.g. for firmware flashing or long MSP operations |
| `class_Channel.md`, `class_Timer.md` | Model channel/timer objects |
| `class_Module.md` | RF module (internal/external) state: `:enable()`, `:protocol()`, `:option()` |
| `class_FrSkyStaticText.md` | Legacy static text sensor type |

## Quick pointers

- To register any widget or tool: see `registerWidget()` / `registerSystemTool()` in `namespace_system.md`.
- To read any telemetry value (including Rotorflight sensors): `system.getSource(...)` in `namespace_system.md`, then `.value()` on the returned `class_Source.md` object.
- To draw anything: `namespace_lcd.md`.
- To build a settings/config screen: `namespace_form.md` plus the form field classes above.
- To talk raw MSP (read/write flight controller config directly instead of using pre-decoded telemetry): `class_CrsfSensor.md` (`pushFrame`/`popFrame` with commands `0x7A`=request, `0x7B`=response) via `crsf.getSensor()`, or `class_MultimoduleSensor.md` for Multimodule-connected radios. See `references/rotorflight-msp.md` for how Rotorflight structures these payloads.
