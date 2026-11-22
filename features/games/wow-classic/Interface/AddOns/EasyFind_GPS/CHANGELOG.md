# Changelog

All notable changes to EasyFind: GPS Navigation Extension are documented in this file.

---

## [1.9.1] - 2026-11-21

### Fixed
- **Death skips on Zephras Isle**: on a guide's step that says to die and respawn, a ghost is led to the Spirit Healer where the guide's step puts it. It was led back to its corpse wherever the GPS knew no Spirit Healer nearby

---

## [1.9.0] - 2026-11-21

### Added
- **Guides can lead the GPS**: a guide extension, such as the EasyFind: RestedXP Extension, sends its next few stops as one route, puts its step's creatures under the arrow with a Target button each and the items or macros the step says to use beside them, keeps the Hearthstone and flight paths for the steps that call for them, and leads straight to a spot the guide glides or flies to
- **Walks go around danger**: a walk keeps away from ground where creatures are three or more levels above you, further out of the way the higher they are. On by default; Dangerous areas under Route planning > Avoid turns it off
- **The box under the arrow, line by line**: its description, this step's distance and time, and the total time left each have a switch, on the box's right-click menu and in the GPS options. Box under the arrow on that menu hides the box itself; a right-click on the arrow brings the menu back
- **Show on map for a group member**: a party or raid member's right-click menu opens the world map on their zone and marks them as they move
- **A menu on the Target buttons**: a right-click opens a menu with Close
- **Long steps in full**: a step too long for one line of the box under the arrow runs onto more lines. Wrap long steps, among the box's switches, cuts it to one line again, and hovering the box reads the rest

### Changed
- **Shorter walks**: off the roads, down slopes and around hills a walk takes the direct way where it went the long way round
- **Dungeons in caves end at the portal**: a route to Wailing Caverns leads down the cave to the portal, where it ended at the cave's mouth
- **Thunder Bluff is reached by a lift**: a route to the city rides up, where it ended in the canyon below
- **Jumps**: a step down a ledge says to jump and where; "at full health" is gone
- **Zephras Isle** (WoW Forever): its walking paths are rebuilt from the game as it is now, so a spot inside the Bandit Hideout is reached through the cave's mouth, not round the mountain

### Fixed
- **Leaving Undercity through its sewers**: the steps read in the right order and the line no longer crosses the tunnel's walls
- **A quest tracked by a guide or another addon** no longer takes the arrow away from the route
- **Hitches while a route is planned**: long routes are worked out in smaller pieces, and the other ways only while a GPS window or the map's page is open to list them

---

## [1.8.1] - 2026-11-17

### Fixed
- **The Target button leaves when you arrive**: it stayed up after the route ended with no way to close it. It now goes at the arrival message, and a right-click closes it any time

---

## [1.8.0] - 2026-11-17

### Added
- **Target the NPC you came for**: near an NPC a route leads to, a Target button under the arrow targets it and puts a raid mark on it (a skull by default, set in options). It has a key binding too
- **Distances in yards, meters, bananas or football fields**: pick the unit in the GPS options
- **Close the window on arrival**: an option closes the GPS window a few seconds after you arrive
- **Arrive on any floor**: a route to an inn's upper floor or a cellar now stays until you end it, as the game cannot tell its floors apart; this option ends it over or under the spot as before
- **Boats, zeppelins and trams in the search**: find one by its name or by where it leaves from ("zeppelin orgrimmar", "boat auberdine")
- **The sewers on the way**: a walk into Undercity through its sewers says so, with a step into the Sewers that is done as you enter them

### Fixed
- **Upstairs or in a cellar**: a destination on an inn's upper floor or below says so, and the walk ends on its floor
- **Lifts**: riding any lift counts, not only the one the route picked
- **Caves**: a spot inside a cave is walked to through its mouth, not over the hill above
- **A route picked up at login** draws its arrow at once

---

## [1.7.1] - 2026-11-15

### Fixed
- **An error during fights on WoW Forever**: planning a route in a fight, such as quest directions updating, stopped with an error when a teleport spell's cooldown was hidden by the game. A cooldown seen before the fight still counts
- **An error on the world map**: the route line drawn from your position could stop the map's drawing with an error; it also clears now when you leave that leg

---

## [1.7.0] - 2026-11-14

### Changed
- **Hearthstone has its own Avoid switch**: Route planning > Avoid lists Hearthstone and Teleports apart, where one switch covered both. Teleports shows on a character that has one, and a setting that had the old switch on keeps both on

---

## [1.6.0] - 2026-11-11

### Added
- **Right-click a map pin** for its menu: Directions to it, and Add stop while a route is up. Quest marks and quest areas, flight masters, dungeon entrances, the game's waypoint, anything on the map
- **Directions from a portrait**: right-click the target, focus, boss, party or raid frame for Directions. A group member is followed, the route planned again as they move, until another route takes over or they leave the group
- **A quest's end on the map**: a route ending on the game's own icon draws nothing over it, and a quest with no icon of its own wears the game's quest button, ! to take it, ? to turn it in
- **A route to a quest in your log** tracks the quest on its last step, so the game's own marker leads the final stretch

### Changed
- **Needs EasyFind 5.3.0**: the creature catalog, every creature by name, title and what it sells, is part of EasyFind itself now. GPS keeps the directions, the danger warning and the vendors along a route from it. An older EasyFind gets one chat line asking for the update
- **Creature search**: "salt vendor" and "buy salt" find who sells salt, and an English name finds on every client
- **The route's line** runs under the map's own icons
- **EasyFind Directions** is the entry's name in the game's quest, unit and map menus

### Fixed
- **Opening the world map** after a route or a step click no longer raises errors afterwards, and the game's waypoint pin shares with Shift-click again; a turn of the map asked for in a fight comes as the fight ends
- **WoW Forever portals**: routes no longer send you to a Stormwind or Dalaran portal that is not there
- **Zeppelin towers**: the step names the dock's master and side, "Board the zeppelin to Orgrimmar at Zapetta (west side)"
- **A replanned route** keeps the start you set until you reach it
- **Snapped into Questie's tracker**: after a reload the section comes back into the tracker once the tracker shows
- **Lifts**: the walk to a lift's door ends at the door, not 40 yards off
- **Avoid flyout**: the list is drawn on each open, so a click shows its check
- **Walks inside a city**: a walk to the Pools of Vision in Thunder Bluff no longer begins with a three-yard "Exit Thunder Bluff" and draws its line on the city's map; the city's own ground read as the zone around it
- **Another way taken**: told to hearth and fly, you fly straight there instead; the route now notices and goes on from where you land, instead of still asking for the hearth
- **Caves on WoW Forever's Kalimdor**: the Pools of Vision under Thunder Bluff and the cave at the Wailing Caverns' entrance have their floors now. A route to someone inside goes in; from inside, the walk starts in the cave instead of on the ground above it, and standing on that ground no longer counts as being in the cave
- **Kalimdor's walking ground on WoW Forever** is baked afresh with the same fixes Eastern Kingdoms got

---

## [1.5.0] - 2026-11-07

### Added
- **Arrow in the GPS window's menu**: right-click the GPS window for an Arrow at your character row, and Reset arrow position once the arrow has been moved. When a quest takes the tracking and the arrow goes away, checking the row tracks the route again

### Fixed
- **Walking routes**: a step's spot you walk past on your way to the next one no longer sends you back to it
- **GPS window**: bags and other windows opened after it now cover it; it still sits above the action bars
- **Thunder Bluff, Freewind Post and the Great Lift**: walks take their lifts. With no flight path known, a trip to Thunder Bluff walks to a lift instead of drawing a straight line, and ends at the lift's foot, where you are in the city
- **Undercity on WoW Forever**: a trip to the Royal Quarter goes down an elevator and through the city instead of out and round through the sewers
- **Routes from another start**: no line is drawn from where you stand to the first step until you reach the route's start

---

## [1.4.0] - 2026-11-06

### Added
- **Questie's quest tracker**: the GPS window docks under Questie's tracker, drawn in Questie's style, when Questie's tracker stands in for the game's

### Fixed
- **Docking**: the GPS window no longer snaps into the game's quest tracker while that tracker is hidden, such as with no quests yet or with Questie's tracker in its place
- **Docking**: when the tracker it is docked in goes away, the GPS window stands on its own and docks again the next time it opens

---

## [1.3.2] - 2026-11-05

### Fixed
- **Directions on the quest tracker's menu**: no longer errors when a game window that addons can't touch is under the cursor

---

## [1.3.1] - 2026-11-04

### Fixed
- **Creature search**: a creature's name typed without its space ("rothide") no longer errors after quick typing cut a search short

---

## [1.3.0] - 2026-11-04

### Added
- **Avoid in the route menu**: the route planning menu has an Avoid flyout with the same switches as the settings page
- **Minimap sizes**: the minimap's route line has a width setting of its own (thin, normal, thick), apart from the world map's; on Classic Era and TBC Anniversary a Minimap dot setting sizes the step's marker, now smaller by default
- **Map page menu**: right-click the route page in the map's search tab for the window's menu
- **Search along route** sits at the right end of the Add destination row while a way lies ahead

### Changed
- **Undercity routing improved**: routes keep to the city's own floors (the Ruins, the upper ring and the auction house floor) and ride its elevators up or down, and the minimap's way ahead stops at a lift until it is ridden

### Fixed
- **Along route**: a creature EasyFind already lists shows once, not twice
- **An EasyFind older than 4.0.0** gets one chat line asking for an update instead of errors

---

## [1.2.0] - 2026-11-03

### Added
- **Other extensions' words**: words another extension gives a creature (a HandyNotes plugin's "decor") find it in the search, and beside a zone or town they keep to it: "decor durotar", "org decor" (with EasyFind 4.3.0)

---

## [1.1.0] - 2026-11-02

### Added
- **Elevators**: a route can ride a lift; the step reads "Take the elevator to" and is done once you reach the other level (Undercity's three lifts on every classic client)
- **Names typed without their space**: "rothide mystic" finds Rot Hide Mystic
- **Recent searches**: a place picked for a trip's field joins the recent searches
- **Other extensions** can tell which creatures EasyFind already lists, so they mark those rows instead of adding a second one (with EasyFind 4.2.0)

### Changed
- **Undercity**: directions to Undercity no longer lead into Lordamere Lake and the sewers; they end where the road enters the Ruins of Lordaeron, and spots inside are reached by its elevators. The last stretch to the gate is still being worked on
- **The GPS menu**: the list choices and the beacon sit under Show, the step switches under planning
- **The minimap** draws only the way ahead; the map keeps the walk behind as planned
- **Back onto the route**: off the route, the way back is drawn again from where you stand as you move and joins the route well ahead, so the arrow and the minimap line no longer turn back every few yards; the walk behind you stays drawn
- **Drawn walks** cut straight across open ground instead of running along hidden map tile edges

### Fixed
- **A Lua error while planning a long walk** (Nav.lua line 1405) when the map's ground was read twice at once
- **Creature search**: "greater dusk" finds Greater Duskbat instead of reading Duskwood into it
- **Clear route** also removes the pin at the journey's end
- **City maps**: a walk outside a city is no longer drawn on the city's map, and a road past a city's walls no longer counts as a step through the city
- **The arrival line** lines up with the time line
- **Fewer hitches** while you walk off the route

---

## [1.0.0] - 2026-10-29

### Added
- **Its own addon**: GPS came inside EasyFind until now; it installs on its own as an extension, and your settings carry over
- **Directions**: from where you stand, or a trip planned from any start, through flights, boats, zeppelins, the tram, portals, teleports and your hearthstone, then the walk
- **Where the steps show**: a small window, the map's GPS page, or the objective tracker; an arrow at your character, the route on the map and the minimap, and a beacon where each step leads
- **Trips**: several stops, a search along the route, and routes shared as a link in chat
- **Safety**: a red warning where the route crosses creatures far above your level; on WoW Forever, Classic Era and TBC Anniversary, walks follow the ground and go around dangerous ground when you ask
- **Clients**: retail, WoW Forever, Classic Era, TBC Anniversary and Mists Classic
