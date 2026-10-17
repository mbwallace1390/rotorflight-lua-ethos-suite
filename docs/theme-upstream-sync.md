# Manual All Themes sync

This procedure applies only to `radio-all-themes`. It runs when the owner asks
to **sync All Themes with Rob**. There is no scheduled job or automatic push.

Update source: [Rob Thomson's RFSuite master branch](https://github.com/robthomson/rotorflight-lua-ethos-suite/tree/master).
The destination remains [MWRC All Themes](https://github.com/mbwallace1390/rotorflight-lua-ethos-suite/tree/radio-all-themes).

## Before merging

1. Check the current branch, local changes and live remote commits. Preserve
   unrelated changes; use a separate checkout if the working tree is busy.
2. Record both main/master tips and the destination tip. Do not check out,
   commit to, reset or push main/master or the individual theme branches.
3. Fetch Rob's current master commit. If All Themes already contains it,
   report that no update is needed.
4. Inspect the changes from the shared merge base and the actual three-way
   merge result. A direct comparison with Rob's older tree can show deletions
   that a normal merge would not make. Preserve newer official fixes already
   present in All Themes.

## Preserve the add-ons

Keep the complete personal theme folders: `bastion`, `america250`,
`libertyops250`, `mwrc`, `singularity`, `zafira`, `vantage`, `inkhalo`,
`meridian` and `cinder`. Keep Theme Bridge, its palettes, the shared
`lib/dashboard_themes.lua` catalog, and their app/dashboard integration.

Preserve theme identity, assets, all three phase layouts, saved preferences,
model overrides, minimum sizes, and Bastion's legacy `system/aegis` and
`dashboard.aegis` IDs. Preserve the unbounded RPM displays in Meridian/Cinder.

Merge upstream changes normally without discarding commits or force-pushing.
Suite code may be adapted where Rob's API or structure changes require it;
do not replace the add-ons with stock files. If a conflict cannot be resolved
with those guarantees, leave the published branch unchanged and report the
specific conflict for a decision. Explain significant compatibility edits.

## Verify and publish

- Run the theme and Bridge integration tests, including new-folder discovery,
  settings round trips, disconnected states and broken optional modules.
- Check affected Lua code, translation tags, workflow generation when touched,
  cleanup and stable wakeup/paint file-read counts. Check any unresolved deploy
  translation log and report its keys and paths.
- Review the complete staged change and verify that protected folders/files
  and unrelated local files survived. Update pilot documentation for visible
  behavior changes.
- Commit and push only `radio-all-themes`; verify the remote commit and confirm
  that main/master and the individual branches stayed at their original tips.
- If an installation package is requested, build a complete localized package
  and validate its manifest and contents. Repository tests and package checks
  do not establish physical-radio acceptance.

Never deploy automatically to a plugged-in radio. Radio installation is a
separate explicit request.

Checked against the All Themes discovery integration on 2026-10-02.
