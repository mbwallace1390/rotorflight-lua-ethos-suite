# Meridian and Cinder validation

Evidence recorded on 2026-09-30 for RFSuite Ethos 2.3.1 after the latest upstream
merge and both theme registrations.

- Complete theme regression suite: **90 tests passed**.
- Render matrix: **144/144 cases passed**, with no text outside the screen.
- Matrix: two themes × three phases × two sizes × three appearance modes ×
  four data states (connected, offline, missing, warnings).
- **36 connected-screen previews** and a gallery were generated from the
  implemented Lua through the existing Suite engine and context.
- All **16 new Lua files** parsed successfully with Lua 5.2. The actual Suite
  integration checks use the existing Lua 5.4 fixture for current core syntax.
- Lua sources contain no RPM threshold, limit, or redline setting. Inflight
  readings remain unaffected by legacy RPM-limit preferences.
- Independent checks covered fresh preferences, long model names and changes,
  no cross-theme dependencies, stable nested drawing caches, no repeated body
  text measurements or module loads, source-data preservation, and retained
  flight results with cleanup on model changes.
- Desktop visual review covered all phases and both sizes. Compact Meridian
  checklist spacing, short thermal-axis labels, and recorded-result spacing
  were corrected and covered by targeted checks. Cinder retains copper thermal
  bars and grouped RPM/unit text.

The native header starts at the top edge, and its complete branding group is
centered with smaller MWRC text. `MY HELI` in the gallery is fixture data;
runtime model identity comes from the active Suite/radio context.

The gallery's image files and controls were generated locally. Codex queued
the HTML file panel. Browser interaction verification was unavailable because
the in-app browser blocks `file:` URLs; no alternative browser route was used.

These are desktop renders, not radio screenshots. Desktop font metrics differ
from generated concepts and may differ from firmware. Physical-radio visual,
sensor-transition, instruction-budget, and memory acceptance remain unverified.

The approved registrations are now included in the All Themes source changes:
two theme entries in each of the four loader/settings lists, plus two Theme
Bridge metadata entries. These ten additions change registration data, not
Suite functions. The separate theme changes contain their own folder and four
registration entries; their palette metadata is available to a compatible
optional Theme Bridge.

Final verification against upstream `330e5da0` passed all 90 theme tests,
including eight registration/lifecycle tests, and all 144 render cases. The
Suite UI and MSP harnesses passed using the additional native LCD color stub
required by Theme Bridge; the six-request MSP trace was unchanged. All 21
image-cache checks passed.

The upstream CI registry omitted the existing profile-anchor workflow job.
Adding that job to its source registry restored all 26 checks and four negative
self-tests without changing workflow bytes. This small CI repair is included
in the theme branches so their pull requests retain the existing check.

This work leaves `main`/`master` unchanged. Target branches are
`radio-all-themes`, `radio-theme-meridian`, and `radio-theme-cinder`.
Publication is checked separately against GitHub's branch heads. No radio
deployment or physical-radio acceptance is claimed here.
