# Changelog

## v4.4.1

### Options
  - Fixed: after a search in the Settings panel, a key binding in combat
    failed with "Interface action blocked" (blamed on TomTom). The TomTom
    pages now hold their own list, out of reach of the settings search.
  - Because of this fix, the settings search no longer finds TomTom
    options, and a gamepad cannot move into the TomTom pages. Type
    `/tomtom` to open them.

### Changes and fixes
  - `/way arrow clear` clears the waypoint from the crazy arrow.
    `/way arrow remove` removes the waypoint on the crazy arrow.
  - On retail and Forever, the player and cursor coordinates are in the
    header of the world map, on top of it.

## v4.4.0-beta

This beta changes most of the inner code of TomTom. Your waypoints and
settings stay. Please report problems.

### Options
  - The options are now in the Blizzard Settings panel. Type `/tomtom` to
    open them. The pages are: TomTom (with a list of all features),
    Waypoint Arrow, Minimap, World Map, Coordinate Block, Quest
    Objectives, Paste window, Data Feed Options and Profiles.
  - Each feature turns on and off at once, with no `/reload`.
  - The two unused quest options (click integration and its modifier) are
    gone.

### Changes and fixes
  - The arrow and the coordinate block hide during pet battles on all
    clients that have pet battles, also Mists Classic.
  - "Display waypoints from other zones" works on the minimap. Minimap
    waypoints also show in the caves of their zone.
  - The quest objective waypoints work on retail, Forever and Mists
    Classic. A new "Quest to follow" setting chooses the quest where the
    client allows both options.
  - In gamepad mode, the world map pins and map click are off, to prevent
    errors on the world map.
  - The player and cursor coordinates show on the small and the maximized
    world map of the classic clients.
  - The cursor coordinates show "---" when the mouse is off the map.
  - `/way` with a zone name that has a parenthesis, a percent sign or a dot
    no longer causes an error or matches the wrong zone.
  - "Send to battleground" uses the instance chat channel.
  - The arrow scale sliders stop at 0.05, not 0.
  - Fixes for waypoint sharing, minimap pin updates, the data feeds, the
    themes, the tooltips and the paste export.
  - The quest waypoint no longer loops with WaypointUI.

### For addon authors
  - Public callbacks: `TomTom.RegisterCallback(owner, event, handler)` with
    `WaypointAdded`, `WaypointRemoved`, `WaypointsReloaded`,
    `ArrowTargetChanged`, `ArrowThemeChanged`, `ArrowVisibilityChanged` and
    `ArrowSettingsApplied`.
  - Feature suppression: `TomTom:SuppressFeature(owner, feature)` turns a
    TomTom feature off for one session without a change to the saved
    settings. Features: `"poi"` and `"arrow.setclosest"`.
  - `AddWaypoint` accepts `source` as another name for `from`.
  - `ShowWaypoint` and the arrow hijack API work again.
  - README.md documents the full public API. The methods that addons hook
    today still work.
