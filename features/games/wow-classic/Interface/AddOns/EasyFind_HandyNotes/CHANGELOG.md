# Changelog

## [1.0.3] - 2026-11-16

- Fixed an error ("attempt to index local 'handler'") when a HandyNotes plugin was turned off or removed itself while its pins were being read.
- Fixed a possible error when the game hides a creature's name.
- With many HandyNotes plugins, finishing reading their pins no longer holds up the game for a moment, and pins sharing a name always list in the same order.

## [1.0.2] - 2026-11-05

- Pins are no longer read during a boss fight, a Mythic+ key or a PvP match, where some HandyNotes plugins raise errors; they are read once it ends.
- An error inside a HandyNotes plugin no longer shows up as an error from this extension.

## [1.0.1] - 2026-11-05

- With many HandyNotes plugins installed, reading their pins no longer stops with a "script ran too long" error; the pins are read a little at a time instead.

## [1.0.0] - 2026-11-03

- Find what your HandyNotes plugins mark on the map from EasyFind's search bar: treasures, rares, vendors and more, by name and with no `@` needed.
- Search by what a pin is, what it drops or where it is: "decor durotar", "ek decor", or an item's name to find the rare that drops it.
- A pin EasyFind already lists shows once, as EasyFind's own result, with the plugin's note and loot in its tooltip.
- Click a pin for directions with the [EasyFind: GPS Navigation Extension](https://www.curseforge.com/wow/addons/easyfind-gps-navigation-extension); without it, retail puts the game's map waypoint on the pin. Shift-click links the spot in chat on retail.
- `@hn` lists the pins on your map; the filter menu can hide done pins or keep only your map's.
- Retail and WoW Forever.
