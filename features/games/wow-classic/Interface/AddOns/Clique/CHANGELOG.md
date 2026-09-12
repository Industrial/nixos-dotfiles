# Changelog

The authoritative, user-facing changelog now lives **in-game**.

Open the Clique config window, click the **Options** button, and choose
**What's New**. It is shown automatically the first time you log in after an
update, and is kept up to date there.

The changelog content is maintained in [`core/changelog.lua`](core/changelog.lua)
as a structured Lua table (version, date, and Added/Fixed/Changed sections).
Add new entries to the top of that table when cutting a release.
