# TomTom
Acts as your portable navigation assistant for World of Warcraft

## Supported Console Commands

### /way /tway /tomtomway

This command sets waypoints and lets you perform simple operations.
In case /way is used by some other addon, /tway and /tomtomway are aliases.
Subcommands are:

#### /tomtomway local
List all the waypoints in the local zone.

#### /tomtomway list
List all the waypoints everywhere.

#### /tomtomway arrow \[clear|remove]
Print the status of the crazy arrow.
* `clear` clears the waypoint from the crazy arrow. The waypoint stays.
* `remove` removes the waypoint on the crazy arrow.

#### /tomtomway block
Print the status of the coordinate block.

#### /tomtomway reset all|away|\[not] \[zone]
Remove waypoints.
* `all` removes all waypoints.
* `away` removes all waypoints that are not in the current zone.
* `<zone>` removes the waypoints in that zone.
* `not <zone>` removes the waypoints in all other zones.

#### /tomtomway  <x-coords> <y-coords> <description>
Create a waypoint in the current zone.
Coordinates are numbers from 0 to 100. A '.' or a ',' works as the decimal separator.
The description is whatever is after the y coordinate.

#### /tomtomway <zone> <x-coords> <y-coords> <description>
Create a waypoint in the specified zone.
Coordinates are numbers from 0 to 100. A '.' or a ',' works as the decimal separator.
The description is whatever is after the y coordinate.

The zone is matched against the names of zone, continent and micro maps.  A
zone of the form `#1234` instead targets that map ID directly, which works for
any map — including dungeons, raids and other maps that are not matched by
name.

### /cway /closestway
Set the active waypoint to be the closest one.

### /wayb /wayback \[description]
Drop a waypoint at your current location with an optional description.

### /tomtom
Open the TomTom Interface options.

### /tomtom help
Print the list of TomTom commands in the chat window.

### /ttpaste /tomtompaste /ttp
Open a window where you can paste many `/way` commands and run them together.

## Zone Naming Conventions

TBD


## Supported Addon API

TomTom adds one global table, `TomTom`.
All API functions are methods on this table.
Call them with a colon, for example `TomTom:AddWaypoint(...)`.

Use these definitions:

* **map**: a map ID (uiMapID). It is an integer.
* **x, y**: the coordinates on the map.
  They are numbers from 0 to 1. They are **not** 0 to 100.
  `TomTom:AddWaypointToCurrentZone` is the one exception. It takes 0 to 100.
* **uid**: a table that represents one waypoint. See "The uid" below.
* **callbacks**: a table of functions that TomTom calls for a waypoint.
  See "Callbacks table" below.

To find out if the real TomTom is loaded, test for a function.
Use `TomTom and TomTom.IsCrazyArrowEmpty`.
Other addons can create a fake `TomTom` table that has only `AddWaypoint`.

### Waypoints

#### uid = TomTom:AddWaypoint(map, x, y, options)
Create a waypoint. Return its uid.
The `options` table is optional.
TomTom does not keep the `options` table.
It writes the default values into it.
Make a new table for each waypoint.

The options are:

| Option | Type | Default | Meaning |
|--------|------|---------|---------|
| `title` | string | none | The description of the waypoint. |
| `from` | string | `"?"` | The name of the addon that sets the waypoint. The tooltip shows it. The old name `source` also works. |
| `persistent` | boolean | the "Save new waypoints" setting | Save the waypoint across logins. |
| `minimap` | boolean | `true` | Ask for a minimap pin. |
| `world` | boolean | `true` | Ask for a world map pin. |
| `crazy` | boolean | the "Automatically set the arrow" setting | Make the waypoint the target of the arrow. |
| `cleardistance` | number | the "Clear waypoint distance" setting | Remove the waypoint at this distance (yards). Use 0 for no removal. |
| `arrivaldistance` | number | the arrow arrival setting | The arrow shows the arrival image at this distance (yards). |
| `callbacks` | table | `TomTom:DefaultCallbacks(options)` | Your own callbacks. They replace the defaults. |
| `silent` | boolean | `false` | Do not announce the new waypoint in the chat window. |
| `minimap_icon`, `worldmap_icon` | texture path | the icon of the theme | The pin icon. |
| `minimap_icon_size`, `worldmap_icon_size` | number | the icon size setting | The pin size in pixels. |
| `minimap_displayID`, `worldmap_displayID` | number | none | Show the portrait of this creature display ID as the pin icon. |

The pins also need the Minimap and World Map settings to be on in the options.
A waypoint with `minimap = false` and `world = false` has no pins.
It still works as the arrow target.
Its distance callbacks still run.

##### The uid
The uid is a table.
It holds these values:

```lua
uid[1]       -- map
uid[2]       -- x
uid[3]       -- y
uid.title    -- the title
uid.from     -- the name of the addon that set the waypoint
```

TomTom also copies every key of `options` to the uid.
You can store your own keys in `options`, and read them from the uid later.
Use `uid.arrivaldistance` to read the arrival distance.

Two waypoints are the same when they have the same map, x, y and title.
When you add a waypoint that exists, `AddWaypoint` returns the old uid.
It does not apply any new option.
To change a waypoint, remove it and add it again.

```lua
local uid = TomTom:AddWaypoint(37, 0.512, 0.348, {
    title = "Elwynn Forest herb",
    from = "MyAddon",
    persistent = false,
    silent = true,
    arrivaldistance = 15,
})
```

#### TomTom:RemoveWaypoint(uid)
Remove the waypoint.
This clears it from the pins and the arrow.
It also removes it from the saved waypoints.
`uid` must be a table. `nil` does nothing.

#### TomTom:ClearWaypoint(uid)
Make the waypoint inactive.
The pins and the distance callbacks stop.
The waypoint stays in the list of waypoints.
`RemoveWaypoint` calls this function.

#### TomTom:SetWaypoint(uid, callbacks, showMinimap, showWorld)
Make a waypoint active, with the given callbacks and pins.
`AddWaypoint` calls this function.
Most addons do not need it.

#### TomTom:HideWaypoint(uid, minimap, worldmap)
Hide the pin of an active waypoint.
Pass `true` for each pin you want to hide.
The pin stays hidden until you call `ShowWaypoint`.

#### TomTom:ShowWaypoint(uid)
Show again the pins that `HideWaypoint` hid.

#### uid = TomTom:SetCustomWaypoint(map, x, y, options)
The same as `AddWaypoint`, but the waypoint is never saved.
It sets `options.persistent` to `false`.

#### uid = TomTom:AddWaypointToCurrentZone(x, y, title)
Add a waypoint in the zone where the player is.
Here `x` and `y` are numbers from **0 to 100**.
All options have their default values.
It returns nothing when the zone is not known.

#### valid = TomTom:IsValidWaypoint(uid)
Return `true` when the waypoint is in the list of waypoints.
It raises an error when `uid` is not a table.

#### exists = TomTom:WaypointExists(map, x, y, title)
Return `true` when a waypoint with this map, x, y and title is in the list.

#### saved = TomTom:UIDIsSaved(uid)
Return `true` when the waypoint is in the saved waypoints.
It raises an error when `uid` is not a table.

#### uid = TomTom:GetClosestWaypoint()
Return the uid of the waypoint that is closest to the player.
By default, it looks in the current zone.
If the "closest waypoint" setting uses the continent, it looks in the continent.
It returns nothing when no waypoint has a distance.

#### uid = TomTom:SetClosestWaypoint(verbose)
Make the closest waypoint the target of the arrow.
Return its uid.
If no waypoint is found and `verbose` is true, it prints a message in the chat window.

### Callbacks table

`TomTom:AddWaypoint` accepts a `callbacks` table in the options.
This table replaces the default callbacks completely.
Without it, TomTom uses the table from `TomTom:DefaultCallbacks(options)`.

The table has this shape:

```lua
callbacks = {
    minimap = {
        onclick = function(event, uid, self, button) end,
        tooltip_show = function(event, tooltip, uid, distance) end,
        tooltip_update = function(event, tooltip, uid, distance) end,
    },
    world = {
        -- the same three functions
    },
    distance = {
        [yards] = function(event, uid, range, distance, lastdistance) end,
    },
}
```

Every part is optional.

* `onclick` runs when the player clicks the pin. `self` is the pin frame.
* `tooltip_show` runs when the tooltip opens.
  Fill the tooltip and call `tooltip:Show()`, or return nothing and let TomTom show it.
  Return `false` to keep the tooltip hidden.
* `tooltip_update` runs while the tooltip shows.
  `distance` is `nil` when the distance is not known.
* `distance` has a function for each distance in yards.
  The function runs when the player enters that distance.
  It uses the smallest distance that holds the player.
  When the player moves out to a larger distance, the function for that larger distance runs.
  `lastdistance` is the last distance that TomTom measured.
  It is `nil` on the first check.
  If the player is already inside the distance, the function runs once on the first check.

Distance callbacks do not need a pin.
They run also for a waypoint with `minimap = false` and `world = false`.

#### callbacks = TomTom:DefaultCallbacks(options)
Return a new table with the default callbacks.
The defaults give the pins a menu and a tooltip.
They also remove the waypoint at `options.cleardistance`.
They play the arrival ping at `options.arrivaldistance` if the player enabled it.
Change this table to add your own functions and keep the defaults.

```lua
local callbacks = TomTom:DefaultCallbacks({cleardistance = 20})
callbacks.distance[100] = function(event, uid, range, distance, lastdistance)
    print("Within 100 yards of", uid.title)
end
TomTom:AddWaypoint(37, 0.5, 0.5, {title = "Target", callbacks = callbacks})
```

#### Example: a route
A distance callback can remove its own waypoint and add the next one.
This is the pattern that route addons use.

```lua
local route = {{37, 0.50, 0.50}, {37, 0.52, 0.55}, {37, 0.55, 0.60}}
local step = 0
local AddNext

local function OnHit(event, uid)
    TomTom:RemoveWaypoint(uid)
    AddNext()
end

AddNext = function()
    step = step + 1
    local point = route[step]
    if not point then return end
    TomTom:SetCustomWaypoint(point[1], point[2], point[3], {
        title = "Route point " .. step,
        from = "MyRoute",
        minimap = false,
        world = false,
        crazy = true,
        silent = true,
        arrivaldistance = 0,
        callbacks = {distance = {[10] = OnHit}},
    })
end

AddNext()
```

TomTom runs the new waypoint on the next check, not in the same one.

### Distance and direction

These functions return nothing when the waypoint is not active.
They also return nothing when the waypoint is on another continent or in another instance.

#### angle, yards = TomTom:GetVectorToWaypoint(uid)
Return the direction and the distance to the waypoint.

#### yards = TomTom:GetDistanceToWaypoint(uid)
Return the distance in yards.

#### angle = TomTom:GetDirectionToWaypoint(uid)
Return the direction in radians.
The angle does not include the way the player faces.
Subtract `GetPlayerFacing()` to get the angle for an arrow on the screen.

#### text = TomTom:GetFormattedDistance(yards)
Return the distance as text, in the unit that the player chose in the options.

#### map, x, y = TomTom:GetCurrentPlayerPosition()
Return the map and the coordinates of the player (0 to 1).
It returns nothing when the position is not known.

#### x, y = TomTom:GetCurrentCoords()
Return only the coordinates of the player.

### The waypoint arrow

The arrow points to one waypoint at a time.
The arrow shows only when the player turned it on in the options.

#### TomTom:SetCrazyArrow(uid, arrivalDistance, title)
Make the waypoint the target of the arrow.
The arrow shows the arrival image inside `arrivalDistance` yards.
The `title` shows below the arrow.
The call does nothing when the arrow points to the player corpse and the "sticky corpse" setting is on.

#### TomTom:ClearCrazyArrowPoint(remove)
Clear the target of the arrow.
When `remove` is true, it also removes the waypoint.
When `remove` is false, the arrow can move to the closest waypoint.
This depends on the "set closest" setting.

#### empty = TomTom:IsCrazyArrowEmpty()
Return `true` when the arrow has no target.

#### texture = TomTom:GetCrazyArrowTexture()
Return the arrow texture of the active theme.
Use the `ArrowThemeChanged` callback to learn when the theme changes.

#### TomTom:ShowHideCrazyArrow()
Apply the arrow settings. Show or hide the arrow.
Use the `ArrowSettingsApplied` callback to learn when it runs.

#### Control of the arrow (hijack)
An addon can take control of the arrow.
TomTom then stops its own updates, and your function does the work.

* `TomTom:HijackCrazyArrow(onupdate)` replaces the `OnUpdate` script of the arrow.
  It is called with `(frame, elapsed)`.
  It shows the arrow.
* `TomTom:ReleaseCrazyArrow()` gives the arrow back to TomTom.
* `TomTom:CrazyArrowIsHijacked()` returns a true value when an addon controls the arrow.
* `TomTom:SetCrazyArrowDirection(angle)` turns the arrow to `angle` (radians).
  The angle does not include the way the player faces.
* `TomTom:SetCrazyArrowColor(r, g, b, a)` sets the color of the arrow.
* `TomTom:SetCrazyArrowTitle(title, status, tta)` sets the three lines of text.
  They are the title, the distance line and the time-to-arrival line.

```lua
if not TomTom:CrazyArrowIsHijacked() then
    TomTom:HijackCrazyArrow(function(self, elapsed)
        TomTom:SetCrazyArrowDirection(math.random() * math.pi * 2)
        TomTom:SetCrazyArrowColor(math.random(), math.random(), math.random())
        TomTom:SetCrazyArrowTitle("Hijacked arrow", "Hijacked", "You will never arrive")
    end)
end

-- Later
TomTom:ReleaseCrazyArrow()
```

### Public callbacks (events)

Use these callbacks to learn about changes.
They use CallbackHandler, the same way as AceDB.
These are the supported way to learn about changes.

```lua
TomTom.RegisterCallback(owner, event, handler)
TomTom.UnregisterCallback(owner, event)
TomTom.UnregisterAllCallbacks(owner)
```

`owner` is a table or a string that identifies your addon.
`handler` is a function.
It receives the event name first, then the arguments of the event.

| Event | Arguments | When it fires |
|-------|-----------|---------------|
| `WaypointAdded` | `uid` | `AddWaypoint` added a new waypoint. The waypoint is active. It is saved if `persistent` is true. It is the arrow target if `crazy` is true. It does not fire for a duplicate. |
| `WaypointRemoved` | `uid` | `RemoveWaypoint` removed the waypoint. It also fires for each waypoint that a reload of the saved waypoints drops. |
| `WaypointsReloaded` | none | The saved waypoints were loaded again, for example after a profile change. The `WaypointRemoved` events come first. The `WaypointAdded` events for the new waypoints follow. This event comes last. |
| `ArrowTargetChanged` | `uid` | The target of the arrow changed. `uid` is `nil` when the arrow has no target. |
| `ArrowThemeChanged` | `themeKey` | The arrow theme changed. |
| `ArrowVisibilityChanged` | `shown` | The arrow came into view or went out of view. `shown` is true when the arrow frame is visible and has a target or is hijacked. The frame with no target does not count. It fires only on a change. It also fires when the whole UI hides (for example Alt+Z). |
| `ArrowSettingsApplied` | `shown` | `ShowHideCrazyArrow` ran: an arrow setting changed, the profile changed, or a pet battle started or ended. `shown` has the same meaning as above. It can fire when nothing changed. A handler can call `ShowHideCrazyArrow`; that call does not fire the event again. |

```lua
local owner = {}
TomTom.RegisterCallback(owner, "ArrowTargetChanged", function(event, uid)
    if uid then
        print("The arrow points to", uid.title)
    else
        print("The arrow has no target")
    end
end)
```

Some addons hook TomTom methods with `hooksecurefunc` instead.
This still works.
These methods stay real methods on the `TomTom` table, and TomTom calls them through the table:
`ClearWaypoint`, `SetCrazyArrow`, `ClearCrazyArrowPoint`, `ShowHideCrazyArrow` and `EnableDisablePOIIntegration`.
`ClearWaypoint` runs for every waypoint that goes away.
`SetCrazyArrow` runs for every change of the arrow target.
Use the callbacks for new code.
A callback does not break when TomTom changes its inner code.

### Feature suppression

An addon can tell TomTom to stand down for one feature.
Use this when your addon does the same job.
It does not change the saved settings of the player.

#### TomTom:SuppressFeature(owner, feature)
Turn off the feature.
`owner` is a non-empty string that names your addon.

#### TomTom:ReleaseFeature(owner, feature)
Remove the claim of `owner`.
TomTom uses the setting of the player again when no owner is left.

#### suppressed, owners = TomTom:IsFeatureSuppressed(feature)
Return `true` and a sorted list of owners when someone suppresses the feature.
Return `false` and an empty list if not.

The features are:

| Feature | Effect while suppressed |
|---------|-------------------------|
| `"poi"` | The quest objective (POI) module acts as off. It removes its waypoint and stops its scan. |
| `"arrow.setclosest"` | The arrow does not move to the closest waypoint when its target clears. |

The rules are:

* Suppression lasts for one session. TomTom does not save it.
  Call `SuppressFeature` in each session.
* The saved settings do not change.
* Many owners can suppress the same feature.
  The feature stays off until all owners release it.
* An unknown feature name, or an owner that is not a string, raises an error.
* The settings rows of a suppressed feature show "Controlled by <owner>".

```lua
if TomTom and TomTom.SuppressFeature then
    TomTom:SuppressFeature("MyAddon", "poi")
end

-- When your addon no longer does this job
TomTom:ReleaseFeature("MyAddon", "poi")
```

### Other functions

#### TomTom:EnableDisablePOIIntegration()
Apply the quest objective settings now.
TomTom starts or stops the module and its waypoint.
TomTom calls this function itself after a settings change.

#### TomTom:ReparentMinimap(frame)
Move all minimap pins to `frame`.
Minimap addons call this function when they replace the minimap.

### Internal, do not use

These parts are not API. They can change in any release.

* `TomTom.private` and everything in it.
* The `TOMTOM_*` messages. Use the public callbacks.
* `TomTom.CrazyArrowThemeHandler` and the theme tables.
  Old code that reads `TomTom.CrazyArrowThemeHandler.active.tbl.arrowTexture` still works.
  New code must use `TomTom:GetCrazyArrowTexture()`.
* The global frame `TomTomCrazyArrow` and the `TomTom.waypoints` table.
