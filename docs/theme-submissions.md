# Custom theme submission standard

Use this checklist for each new MWRC dashboard theme and each individual theme
pull request. Theme Studio runs the corresponding authoring checks before a
theme is ready for submission.

1. Target the current Suite contract. Keep the theme inside its own folder, with
   its own helpers, assets, `init.lua`, three phase modules and configuration.
   Use Suite APIs without copying another theme's drawing implementation.
2. Verify registration in the target build. Stock individual submissions need
   entries in the dashboard loader, settings normalization, theme picker and
   configuration grid. All Themes already discovers complete installed folders;
   do not add the discovery feature to an individual upstream theme PR.
3. Keep folder, selection and settings IDs stable. An established rename needs
   explicit compatibility handling. All Themes keeps Bastion's `system/aegis`
   and `dashboard.aegis`; the upstream Bastion submission uses `system/bastion`
   and `dashboard.bastion`. Do not interchange these without a migration.
4. Add `app.modules.settings.dashboard_theme_<folder>` to all source locale
   files, including unchanged proper names. Regenerate runtime locales with
   `python bin/i18n/build-single-json.py`, then run the tag check for each locale.
   Individual picker and settings entries use that key. All Themes localizes
   system names in `lib/dashboard_themes.lua`, preserving plain theme metadata
   for compatible folder copying.
5. Declare and test the minimum available window. Current MWRC themes require
   784 × 294 and also render at 800 × 480. Hide their selector and settings tile
   below the declared minimum. Preserve the dynamic model area and native header.
6. Keep only metadata consumed by the target build. Individual stock submissions
   omit the inactive `appTheme` block. All Themes and Studio retain their active
   palette metadata; a dashboard theme does not require Bridge implementation.
7. Update the affected `docs/pages/settings/dashboard/` pages and add the theme
   guide under `docs/dashboard/`. Explain selection, configuration, installation,
   screen restrictions and saved IDs. Dashboard warnings save on the radio in
   `SCRIPTS:/rfsuite.user/settings.ini`; model choices use the model's local INI.
   These operations do not write flight-controller EEPROM or FC protection limits.
8. Include preflight, inflight and postflight previews in the theme gallery.
   Label desktop renders as desktop previews, not radio captures. Keep design
   identity and existing warning limits; Meridian/Cinder have no RPM threshold,
   redline or comparison scale.
9. Run theme-scoped integration tests for global/per-model selections, all three
   phases, saved settings, reload/reopen, cleanup and minimum-size hiding. Run
   behavior/render checks for missing/stale/nonfinite telemetry, valid zero,
   disconnect/reconnect, units and long model names. Test the complete packaged
   output for resolved tags and correct file paths.
10. Keep each PR focused on one theme, required registration/locale entries,
    truthful docs, previews and relevant tests. Exclude private Studio files,
    transient review artifacts and Bridge implementation. Desktop checks do not
    establish radio font fitting, real telemetry or memory/instruction acceptance.

Main/master and existing public themes are not changed as part of authoring a
new theme. Upstream synchronization remains manual and separate from theme work.
