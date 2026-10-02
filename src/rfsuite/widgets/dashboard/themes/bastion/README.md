# Bastion

A graphite and cyan Rotorflight dashboard with a restrained technical layout.

The physical folder is `bastion`. All Themes preserves `system/aegis` and
`dashboard.aegis` so existing saved selections and warning settings survive.
The upstream Bastion submission uses the canonical `bastion` identity; those
saved sections are distinct.


## Compatible installation

Use a complete All Themes package, or a stock Suite package containing this
theme's registrations. On a compatible All Themes installation, copy the
complete `bastion` folder under
`SCRIPTS:/rfsuite/widgets/dashboard/themes/`, then restart the Suite Lua session
or radio. Select **Bastion** in **System → Settings → Dashboard → Themes**;
configure it in **Dashboard → Settings → Bastion**. Both choices require at least
784 × 294 available pixels. Full-screen rendering is 800 × 480.

All Themes uses `system/aegis` and `dashboard.aegis`. Settings save
on the radio; they do not write flight-controller EEPROM. Preserve user
settings when updating. [Full theme guide](../../../../../../docs/dashboard/bastion.md)
and [submission standard](../../../../../../docs/theme-submissions.md).
