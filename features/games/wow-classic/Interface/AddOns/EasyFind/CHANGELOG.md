# Changelog

All notable changes to EasyFind will be documented in this file.

---

## [5.5.0] - 2026-11-21

### Added
- **Friends and guild members in search**: type a name for a row in their class color with level, class and zone, or that they are offline. A click opens a whisper, Shift-click invites
- **Addons on and off from the bar**: every installed addon is a row with a checkbox, found by its title or folder name and listed under @addons. A click switches it for this character; a switched row gets Cancel and Reload UI under it
- **The mailbox and the guild bank**: both are remembered once opened, like the bank, and searched from anywhere: Mail and Guild Bank under Items in the filter menu, @mail and @guildbank. A mail row says how many are left and for how long
- **Who owns an item**: an item's row names each of your characters holding it, with the count across bags, bank, mail and guild bank ("Owned: Thrall 5, Jaina 12")
- **Where an item comes from**: Sources is on every item's right-click menu, and an item's name with "sources" typed after it ("copper ore sources") lists them under the item. On WoW Forever, Classic Era and TBC the page covers what drops it and how often, the veins, herbs and chests that hold it, what it is skinned, pickpocketed or fished from, the recipe that makes it with its reagents and trainers, and the quests that reward or need it. A long list shows its first rows and a row that shows ten more, a click on a heading folds its section, and a zone, a continent ("ek") or a heading's word ("reagent") typed on the page narrows it
- **Crafted by**: an item's sources name which of your characters can make it
- **Raid and dungeon lockouts**: @alts and each character's page have a Lockouts page (@lockouts), and a dungeon or raid row says who is saved to it and for how long
- **Abilities by what they do**: "stun", "interrupt", "slow" or "dispel" find the abilities that do it, from each spell's own description
- **Keys both ways**: an ability on your bars shows the key that casts it ("Key: SHIFT-3"), and a key typed alone ("shift 3", "mouse4") answers what it is bound to
- **Holidays**: each holiday of the next twelve months is a row with how long until it starts or ends. A click opens it in the calendar, "next holiday" answers the soonest, and @holidays lists them
- **"level 25"**: the word level and a number lists the zones, dungeons and raids that fit it, each with its range
- **Skill-up colors and @skillups**: a learned recipe wears the game's orange, yellow, green or gray, and @skillups lists the recipes that can still raise the profession
- **Quick answers**: "reset" answers the time to the daily and weekly reset, and a stat typed alone ("crit", "armor", "spell power") answers your character's number
- **WoW Forever's own creatures**: 1,954 creatures the classic databases lack, Zephras Isle's vendors, trainers, innkeepers and quest givers among them, with what each vendor sells; and 252 more that share a spawn with another creature

### Changed
- **Wowhead links open your client's section**: on WoW Forever, Classic Era, TBC and Mists a link or search goes to that client's pages, where it opened retail's
- **Creatures nearest first**: creatures that match equally are listed nearest first, however few they are
- **Dungeons in caves carry their portal's spot**: Wailing Caverns, Uldaman, Sunken Temple, Onyxia's Lair, Scholomance and Maraudon, for directions that end at the portal

### Fixed
- **Keys far down a long list**: Enter, Space, Tab and the right arrow on a row past the first screen of a long list (a vendor's wares, a character's items) acted on another row or on none
- **Zephras Isle's services**: "innkeeper", "bank", "auction" and "stable" find the isle's own, and its map shows both inns, the bank, the auction house and the stable master
- **Riding trainers** on WoW Forever, Classic Era and TBC showed a code in place of their name
- **Excavation Site**: its entrance on the map and the route to it are at the door, at the top of the path from Dun Algaz
- **Instances listed twice**: a dungeon in your zone showed once for the zone and once for the continent
- **A place picked before** no longer shows twice when another map lists it too
- **Show on Backpack** on a currency no longer throws errors with some bag addons

---

## [5.4.1] - 2026-11-17

### Fixed
- **Status Text from its row**: picking Numeric, Percentage, Both or None on the Status Text setting's row threw errors on WoW Forever. Your click now sets it through the game itself, without errors; in a fight the row leaves it as it is
- **The map key in a fight**: after you used EasyFind's map tab, opening the map with its key during a fight was refused with an error naming EasyFind. The tab now lays its panel over the quest log instead of switching it
- **Morbin Lightbane**: WoW Forever's Morbin Lightbane in Undercity is found, with his portrait

### Technical Notes
- **Extensions API 1.13**: an extension can add whole sections to an item's sources page, naming creatures, items and places by their ids, and read a creature's name from EasyFind's catalog (`API.CreatureName`)

---

## [5.4.0] - 2026-11-17

### Added
- **Craft from a recipe's row**: hover or select a recipe you know and its row shows Create, Create All with how many you can make, and a count. They craft with the profession window closed. The row shows the item the recipe makes on the right and its profession's icon on the left
- **WoW Forever's own recipes**: every profession's recipes are found on WoW Forever, First Aid too
- **Map search: only the game's waypoint**: a Map option places just the game's waypoint for a map result, without EasyFind's own pin. A right-click on EasyFind's pin now clears the game's waypoint with it, even with the map open
- **A vendor's wares**: hold Shift on a vendor's row to list everything it sells, narrowed by typing
- **Professions onto the action bar**: Shift+drag a profession's row onto your action bar
- **Icon search by ability name**: type an ability's name after `@icons` and its icon comes up, on every client and in the game's language; the macro icon picker's search does the same. An icon's hint lists the abilities that use it
- **Searching...**: while a search's results are still loading, the bottom of the list says so with moving dots, so a slow moment does not look like nothing was found

### Changed
- **Distances in the GPS's unit**: with the GPS extension, a place's distance on its row and in its tooltip follows the GPS's unit setting
- **No more WoW Forever welcome line**: the chat line at each login and its option under General are gone
- **Update reminder**: once a newer EasyFind is out, chat says so in red at each login until you update, and points to CurseForge

### Fixed
- **Show me how for an item in your bags**: it pointed at the bag button and stayed there; once the bags are open it now leads to the item's slot
- **A recipe missing for its exact name**: after you had picked the bag item of the same name for a search, that search left the recipe out
- **A row's tooltip blinked** while your bags changed, at every item made
- **Classic catalogs**: TBC's vendors, flight masters and innkeepers were read as the wrong kinds, and Classic Era and TBC now list the creatures of Molten Core, Blackwing Lair and the Ruins
- **Green squares in icon search**: each client lists only the icons it has. The list was retail's, so WoW Forever showed some green squares and the Classic clients mostly green ones; icons only WoW Forever or a Classic client has are listed too
- **Icon search kept the last search's matches**: after a search of several words, a shorter one could still list the earlier icons
- **@alts showed no gold**: logging out to the character list saved the character's gold as 0 on WoW Forever. Gold is kept at logout now, and characters already showing 0 get their gold back
- **Shift-click on a map pin to share it**: after EasyFind opened the world map, from a search result or the map tab, the game refused the share with an error naming EasyFind

### Technical Notes
- Logging in costs less: search rows, addon settings and extensions' rows are built a little at a time instead of in a few long frames, and addon settings found at the last login come back at once, read again shortly after
- **Extensions API 1.12**: an extension's rows can be built a little at a time, pausing between frames

---

## [5.3.1] - 2026-11-13

### Changed
- **Apostrophes are optional**: "kelthuzad" finds Kel'Thuzad and "jeneu" finds Je'neu Sancrea, in the search bar, the item catalog and the creature rows
- **A dungeon's short name counts wherever its name does**: "bfd quest" lists what "blackfathom deeps quest" lists, for extensions' rows too
- **Creature rows say what the creature is**: one with a title shows it under its name, such as "Journeyman Enchanter: Undercity", in place of "NPC"

### Fixed
- **The first search after looting, a zone change or a gear change** came up late while character and reputation rows were read again under it; they are read again behind the search now
- **Toggle Sound and Toggle Music**: the checkbox shows whether that sound is heard, and with all sound off a click turns it on instead of doing nothing
- **Turn on the full item catalog** answers to a mouse click and closes the search window once it is on; before, only Enter turned it on
- **WoW Forever bosses listed once**: Blackfathom Deeps, Gnomeregan and Sunken Temple no longer list each boss two or three times

### Technical Notes
- AddOn settings are read in smaller pieces after login, so no single frame carries them all

---

## [5.3.0] - 2026-11-11

### Added
- **Creatures in EasyFind itself**: every creature by name, title or what it sells, on every client, with no extension needed. Map Search > NPCs and its options (friendly or hostile, role, type) are EasyFind's own; the GPS extension keeps the directions
- **An item's sources**: click an item row for a page of who sells it, nearest first, and which bosses drop it; extensions add sections of their own, such as the quests that reward it. Typing on the page narrows every section
- **Dungeon rows lead on**: click a dungeon or raid row for directions with the GPS extension, Ctrl for its bosses, Shift to open the map; Shift on a boss row lists its loot where the client has no Adventure Guide
- **WoW Forever's own dungeons**: Ruins of Lordaeron, City of Dalaran, Excavation Site: Wetlands and the Hall of Thanes list their bosses and drops in @bosses, @loot and @upgrades
- **Weapon masters**: each master is a row of its own, at its own spot, with the weapons it teaches in the tooltip
- **Full item catalog by default**: new saves start with every category on; with the catalog off and few items found, a row at the list's end turns it on and runs the search again
- **Extensions API 1.10 and 1.11**: an extension may judge @upgrades and add an item's sources
- **Tab to the GPS button**: on a row with a GPS button, Tab stops on the button first and Enter starts the route; Tab again opens the row's menu as before
- **Outdated extensions say so**: an extension too old for this EasyFind gets a chat line each session with a link to its page. A GPS older than 1.6.0 still carries its own copy of the creature list; EasyFind keeps using its own until GPS is updated

### Changed
- **Creature rows are on by default**, in the search bar and on the map tab; Map Search > NPCs turns them off
- **Pinned rows act as the row**: a pinned quest or extension row keeps its GPS button, tooltip and hint
- **Emote commands** run the way a macro runs them
- **Profession trainers**: "tailoring trainer" finds the craftsmen who teach it on Classic and WoW Forever, and "trainer" lists every trainer, not only class trainers
- **The map tab's tutorial** ends on the GPS extension; its rares slides show on retail alone
- **The tutorial's Extensions page** has a card for every extension, those on CurseForge first with their download links, the ones you have marked installed

### Fixed
- **Opening the world map** after a GPS route or a map search no longer raises errors, in or out of a fight, and the waypoint pin's Shift-click shares again; a turn of the map asked for in a fight comes as the fight ends
- **Map tabs with ClassicUI Forever's map**: the tabs sit beside the quest pane again, not at the map's foot
- **Typing a dungeon's name** under @bosses, or Ctrl on its row, lists its bosses on every client
- **WoW Forever menus**: a menu's edge no longer shows through the menu opened from it
- **WoW Forever items**: the catalog keeps items the client had marked stale, and leaves out deprecated, test and unused rows in every spelling the game's tables use
- **A spell learned mid-session** appears in results on the next search
- **Closing the results in a fight** no longer raises an error; the rows hide as the fight ends
- **Pet rows on WoW Forever** show the companion tooltip the journal shows
- **The Quests tab beside the map on WoW Forever**: after going back to the quest log through it, the map opens on the quest log next time, not on EasyFind's tab

---

## [5.2.0] - 2026-11-05

### Added
- **@upgrades** (Classic Era, TBC Anniversary, WoW Forever): for each gear slot, what you wear and the dungeon and raid drops that beat it and that you can equip at your level: armor of the type your class wears by then, weapons it uses, stats that suit it. Dungeon drops come first, then raid drops, the next step up first; each names its boss and dungeon, and with the GPS extension a click gives directions to the entrance. Words typed after it narrow the list to a dungeon, a boss or a slot
- **Upgrades for every character**: each character's page on `@alts` has its own Upgrades, from the gear that character last wore

### Fixed
- **Searching settings with many addons installed**: no longer stops with a "script ran too long" error

---

## [5.1.1] - 2026-11-05

### Fixed
- **Show Action Bar 2 to 8 from the search bar**: toggling a bar there no longer leaves Edit Mode blocked for the rest of the session
- **Communities on Forever**: clicking in the invite box no longer raises an error

---

## [5.1.0] - 2026-11-04

### Added
- **Every character's gold**: on `@alts`, Money opens a page with each character's gold, the richest first; `@money` typed there opens it too
- **Use items from the grid**: a click on one of your current character's items in the item grid uses, equips or opens it, as its row in the search does; Shift links it, Ctrl tries it on, right-click opens its menu
- **Keep these settings?**: applying display mode, window size, monitor or UI scale from the search bar asks whether to keep them, as the game's own Apply does, and puts the old ones back unless you keep them
- **WoW Forever**: a welcome at login with a link to report bugs, until its own "Hide this message in future?" link or the switch in General & binds turns it off
- **Extensions API 1.9**: an extension's own quest tracker can hide and show with Toggle Objective Tracker

### Changed
- **@bags and @bank**: open the item grid, your current character's bags (or bank) first and every other character's below, the warband bank after the banks; words typed after them narrow the grid
- **Item grid**: your current character's items show their cooldown, and a bag item's tooltip is the bag's own, with cooldown remaining and charges
- **Gold math**: the calculator shows gold, silver and copper coins instead of g, s and c; a copy keeps the letters

### Fixed
- **Graphics settings from the search bar**: Apply now switches display mode and window size and restarts graphics where the game's own Apply does, so those changes take effect; Reset and Apply show as soon as a setting changes, the slider arrows included
- **Classic Era and Season of Discovery graphics**: View Distance, Depth Effects, Compute Effects and Outline Mode are no longer listed there; those clients have no such settings, and their sliders snapped back
- **Toggle Objective Tracker**: no longer sticks on after one round trip, a hidden tracker no longer flickers in world quest zones, and showing it again no longer brings back an empty quest watch on Classic Era
- **Font Size**: the text typed in the search bar grows and shrinks with it
- **Undercity**: the auction house is found at its auctioneers, not at the bank

---

## [5.0.0] - 2026-11-04

### Changed
- **Notes is an extension now**: Notes comes as the EasyFind: Notes Extension on CurseForge; install it to keep using Notes, and every note, checklist, shopping list and setting you had is there. EasyFind says so once in chat with a link to its page, and until it is installed, /notes and the Notes menus say where to get it. A copy of Notes an older EasyFind came with, left behind by an update unpacked by hand, is no longer loaded

### Added
- **Your characters**: type `@alts` for every character's items, gold, time played and professions, with a page listing your characters and one with their professions; type `@` and a character's name for that character: its bags and bank in the order they sit, its gear, gold, level and where you left it, and words typed after it find its items. On a page, `@items` or `@gear` opens them as a grid, the bar's pill shows the way back, and Backspace steps up
- **Character info in the filter menu**: the game's statistics now sit under Character info beside each character's time played, last played, gold and level; search `gold`, `played` or `level` (alone or with a character's name) to see them, and a character's name alone finds that character
- **HandyNotes extension**: listed with EasyFind's other extensions, its page one click from the Extensions menu
- **Extensions API 1.8**: a row decorator's tooltip is drawn again as Ctrl, Shift or Alt goes down or up

### Fixed
- **Bank search on Classic Era, TBC Anniversary and Mists Classic**: the bank is recorded when you open it, so `@bank` and the Bank filter find what is in it
- **Icon Search**: rows from the list before it no longer show over the grid
- **@ words**: one still being typed is no longer searched as plain text when results arrive
- **Searches for a kind of place**: "ah" and other kinds list the nearest first on your continent and the other faction's cities last, with no farther copy of the same row above it (a Horde character in Tirisfal Glades got Ironforge's auction house first)
- **Updates while the game runs**: the settings window and the other parts that load later no longer throw errors after EasyFind was updated with the game open; a chat line says what to do instead
- **Place rows**: a place listed under no zone heading names its zone ("Auction House  Undercity")

---

## [4.3.0] - 2026-11-03

### Added
- **Shopping lists**: any note becomes a shopping list from its list menu: the names you type are items with counts that tick themselves once your bags hold them, and an "Add item" line under the list starts the next one; a checklist with items on it offers to become one (with Never show again), and with the Auctionator extension the list is an Auctionator shopping list too
- **Prices on shopping lists**: with the Auctionator extension each line shows what is left to buy at its price, its tooltip the price of one and where it came from, and a total sits under the list; a click on the total picks where prices come from and whether lines and the total show them; with no source picked, each item takes the first that prices it
- **Auction house searches**: Ctrl+click a shopping list line's words with the auction house open to search it, in Auctionator's or TradeSkillMaster's window when one is showing
- **Search by place**: a zone or continent typed beside other words keeps them to it ("bank undercity")
- **Update notices**: a newer EasyFind or extension seen in your guild or group is said once a session in chat
- **GPS recommendation**: the map tab tells players without the GPS extension that it can lead them to the places it finds; "Hide extension recommendations" in General settings takes such lines away
- **Extensions API 1.7**: an extension's search provider and row decorator share one scope word; a decorator can name the rows it marks by name and map and give EasyFind's own rows words to be found by; an extension's row on a map answers to its zone, the zones over it and its continent; a row's name can keep to its extension's scope; extensions can offer shopping list prices and auction house searches

### Changed
- **Notes lists**: a line with an icon or a count folds to fit its row, its count hidden until you type in the line; a checklist keeps counts as words you tick by hand; right-click on the + button starts any kind of list
- **Notes under the Classic and Forever themes**: the formatting toolbar is the window's bottom row and the wide margins are gone; window frames are half as heavy; note cards wear a thin edge and fill only under the mouse or when picked; under Classic the buttons glow under the mouse and push in while a style is on
- **Notes**: a click outside a note lets go of its text, as Escape does
- **Classic Era item catalog**: Season of Discovery's items are gone from it ("hand of rag" lists Sulfuras once)

### Fixed
- **Clipboard**: a plain search finds your clipboard history again, not only under @clipboard
- **Long menus**: a toggle menu (the shopping list price menu) stops at the menu height and scrolls
- **Notes**: an empty note made a shopping list keeps the box you type into; Up and Down pick a list's names again and Enter takes the pick; undo keeps a list line's place; a list style follows the line the caret is on and the checklist style no longer ticks the line; line styles no longer flash as you type; a linked list waits while you type in its note
- **Result rows**: an extension's part of a row's subtext no longer goes after a hover
- **Classic theme**: no seam of the world shows between a window's metal and its stone

---

## [4.2.0] - 2026-11-02

### Added
- **Hidden extensions**: a tile's right-click menu in the extensions menu offers Hide; the tile leaves the menu while the extension keeps its search row and key; the menu's settings page lists every extension under Shown in the menu, the settings search finds "<name> in the menu", and Reset to default shows them all again
- **Extensions menu**: tiles run down a column, with Rows per column (4 to 12) in place of Columns; an Icon size setting beside Label size; the menu stays open while its settings are changed
- **Row tooltips**: a place or creature's tooltip shows its spot, how far it is and how many spots fold into the row; a boss's tooltip says how many items it drops where the journal has no page for it
- **Extensions API 1.6**: a row decorator may carry a scope word of its own (@name searches the rows it marks, @name alone lists them) and name its rows by field before it is asked; HasRow and HasCreature tell an extension which creatures and places EasyFind already lists, so it marks those rows instead of doubling them; creature rows carry their ids; a decorator's tooltip can open a bare row

### Changed
- **Equipped-item compare**: a row's tooltip shows the equipped item's compare only while Shift is held, as Classic does; item tooltips elsewhere in the game are untouched

### Fixed
- **Results scrolling**: the list no longer jumps back to the top while you read down it (a provider landing or an item's data arriving repainted it from the top); a wheel glide that aimed past the list's end no longer stalls, which left rows with no tooltip and the catalog's names unfilled
- **Row tooltips**: a gear row's tooltip kept its lines but lost its place beside the list from the second hover on; it no longer shrinks a step at every re-hover after a right-click; Shift brings a hidden compare back
- **Result menus**: a row's menu no longer closes under the pointer on the way to one of its flyouts, and a click outside a menu closes the menu only, never the search bar
- **Extension rows**: an extension row's own icon (a quest, a pin, a fishing spot) draws at the row's right again

---

## [4.1.0] - 2026-11-01

### Added
- **Notes windows**: a note opens in its own window beside the list, and the list stays; open as many as you like, one per note that opens by itself; Open in a new window sits on a note's row menu; the window you press comes to the top, a new one steps off the one under it, and Home on a note's window brings the list up
- **Checkbox lines are the list**: one kind of note. A checkbox line in any note is a list line: tick it by hand, or the game ticks it for an item count, a quest, a reputation, gold, a level, a skill, a lockout or a cooldown; a ticked line reads struck and green, a counted line wears its count with an X to drop it, and an item's link or a count typed in the words makes the line that item. The note's menu holds what a line can track, who keeps the ticks, when they clear, the board and the next auction search. Old checklist notes become text with their ticks kept; the separate checklist kind is gone
- **Notes and the game's windows**: a window (Auction House, Merchant, Bank) is a tag; "Open the window when" on a note opens the notes window with it, "Only the next time" for one visit, and "Close it when this ends" keeps or drops the window after; the notes menus stay open while you work in them
- **Shopping lists**: the catalog's names show under the line you type, Tab or a click takes the pick with the count typed; Enter carries a line's bullet, box or number on, and Enter on an empty mark ends the list
- **Every result listed**: the list no longer stops at 15 rows; the first 15 paint at once and the rest join below as you scroll
- **Steering words**: a word naming a kind of row narrows the rest to it: "zone stormwind", "spell frostbolt", "rep darnassus", "item linen cloth", "recipe" for a profession
- **Instances on Classic Era and TBC Anniversary**: Molten Core, Blackwing Lair and the Ruins of Ahn'Qiraj with their bosses and loot
- **Macros**: a Macros row and the /macro command open the macro window on every client; a macro with no name is named by its first command
- **Commands**: rl, reloadui and reload ui find /reload
- **Map places**: found from anywhere, with This zone only per category; a weapon master's weapons are in its words and under its name
- **Extensions API 1.5**: row decorators, an extension's mark on rows another provider owns (a price at the row's right, menu rows, tooltip lines, a part under the subtext); a menu action that opens a window closes the bar; a decorator may stand in for the Adventure Guide on a client without one; a provider's create row wears the green plus

### Changed
- **Search ranking**: a name typed with its words in another order is that name; a loot item's name ranks like any row's name, and a held or dropped item ranks as the catalog's copy would; among equal matches what you own and the places come first, then loot and the catalog, and creatures with them; an instance's shorthand lists the instance first, then its bosses, then its loot; a short abbreviation typed whole ("ah", "rep", "inn") sits above a name that merely starts with it; a row holding every query word in its name comes before one met by a keyword; same-name rows keep a fixed order: talents, what you hold, the game's own, the catalog, recipes, addons, extensions
- **Catalog**: a query's words reach a name in any order ("cloth linen"), and a typo in the first word still finds the name
- **Extensions**: an extension launches on the start of its name or a word, not on letters inside it

### Fixed
- **Boss rows on Classic Era, TBC Anniversary and WoW Forever**: each boss wears its face at the row's right; the rows were blank where the client's journal gives no picture
- **Search**: "potion" no longer lists every setting in the game; a macro's words take no abbreviation; "hs" lists Hearthstone above h-s loot; "cloth" lists the bag's Silk Cloth above the cloth drops; "fishing tr" keeps Fishing Trainer over the catch Training Sword; "fishing" keeps the Fishing Trainer over 250 fishing spots; a settings row with hundreds of choices no longer leads unrelated queries
- **Rows**: a stack's count bounds the name and subtext before the icon; a row's price keeps clear of the GPS button and the Alt hint; the Menu Bar glyph fills its box like the other category icons; an extension's flyout labels keep the theme's text color
- **Notes**: windows no longer draw through each other; the list's rows reach the bottom and the resize grip sits in the corner
- **Map**: an extension's cluster pins keep their glyph; Show me how leaves the menus of spots and creatures that have no window to lead to
- **Chat links**: a plain click on an EasyFind link works on Classic Era, TBC Anniversary and Mists Classic; before, only Shift+click did

---

## [4.0.2] - 2026-10-30

### Changed
- **Chat and GPS are extensions**: both ship as addons of their own on CurseForge (EasyFind: Chat Extension, EasyFind: GPS Navigation Extension) and no longer come inside EasyFind's zip; a line in chat after the update says where they went, with their pages, and settings carry over for anyone who installs them
- **Map tab filter menu**: the cog opens the game's own menu, as the rest of the tab is the game's look; the GPS window keeps EasyFind's

### Added
- **Profession actions**: Fishing, Survey and Cooking Fire cast from their search rows
- **Map tab**: an extension's rows (quests) get their own Show switch in the cog menu
- **Notes**: a Close with Esc setting, off by default; Esc still closes a menu inside the window
- **Checklists**: Ctrl+click an item line with the auction house open to search it, as Search AH on its menu does; a shopping list's note searches with the list's own term, and the menu entry works on the classic auction frame too
- **Extensions API 1.3**: `places(row)` folds a provider row's spots on the map tab and `ShowPlaces` opens them; `iconWell` puts a provider's marks in a round well on map pins; `kit.Checkbox` takes a width for two columns of switches; a linked checklist's `search` handler; one filter row per extension, a provider naming its extension

### Fixed
- **Map**: a folded row pins only its spots on the viewed map; a hovered result pins only on the map it is on; same-named creatures are separate rows, each at its own place; a zone copied into another world is not a place, so routes to Arathi Highlands plan again
- **GPS end pin**: right-clicking it on any map ends the route
- **Scroll bars**: a wheel ease stops once its list is moved by its owner (the chat's list no longer ran away)

### Technical Notes
- **Tests**: every edit box in every EasyFind-family addon drops its focus on an outside click, checked at edit, at commit and in CI

---

## [4.0.1] - 2026-10-29

### Added
- **Loot and bosses on Classic Era and TBC Anniversary**: every dungeon and raid boss and what it drops, found by name and kept to the class chosen in the filter menu; TBC's heroic dungeons list their own loot; a boss row lists its loot on a click and its GPS button leads to the instance's entrance. WoW Forever gets the boss rows too
- **Item search on Classic Era, TBC Anniversary and Mists Classic**: any item in the game found by name
- **Instance shorthands**: "sm", "smgy", "stockades", "sm cloth" or "sm rogue" find the instance, its wing, its bosses and its loot; a plural finds its singular, and an armor type or a class narrows the loot
- **Instance entrances on Classic Era and TBC Anniversary**: the map search finds dungeon and raid entrances, and GPS leads a dungeon's creatures to its door
- **Quest directions**: Directions on the right-click menu of the objective tracker and the quest log (retail, WoW Forever, Mists Classic); the quests in your log show in search with the GPS button
- **Search this page**: a box in the settings window's title narrows the open page to the settings whose names match
- **Reset to default**: a button on every extension's settings page puts its settings back
- **GPS settings**: switches for the pulse on a clicked step, the danger warning and the red on dangerous stretches
- **Chat**: the unread count on its button can be turned off, and its settings reset to default
- **Extensions API**: one-of-several choices in a filter row's options, a grayed row icon, and the GPS button on rows an extension places (API 1.1)

### Changed
- **Boss and loot rows**: the line under the name says Dungeon boss, Raid boss, Dungeon loot or Raid loot, with the instance
- **Search settings**: an X clears the field while it holds text

### Fixed
- **Filters**: a category turned off in the filter menu hides its rows again
- **Loot filter**: the difficulty choice lists only the game's own difficulties (none on Classic Era and WoW Forever, Normal and Heroic on TBC Anniversary, no Mythic on Mists Classic), and WoW Forever's loot follows the class chosen
- **Item search on WoW Forever**: developer test items no longer show
- **Search settings**: drop-down rows, headers and key rows are found again
- **Search fields**: every search and name box lets go of the keyboard on a click anywhere else, instead of taking every key until Esc
- **Item tooltips on results**: stay up when a chat line arrives while the bar is open
- **GPS**: Clear route takes the route's end pin off the map
- **Loot rows on WoW Forever**: the Alt hint names GPS, not the Dungeon Journal the client lacks
- **Professions filter on classic clients**: Herbalism, Skinning and Fishing are no longer listed, as they have no recipes
- **Remembered picks**: a picked extension row is remembered as itself, not as a second copy marked World Map

### Technical Notes
- **Tests**: every test file counts toward the total; a field defined twice in one file, a companion file that does not take EasyFind's namespace, an edit box that neither lets go on an outside click nor says why, a client's catalog data with its switch off, and a developer item in a built catalog each fail the suite

---

## [4.0.0] - 2026-10-28

### Added
- **GPS**: directions to any place EasyFind can find. Plan a route from where you stand, or from any start, and it works out flights, boats, zeppelins, the tram, portals, teleports and the hearthstone, then walks the rest. The steps show in a small window, on the map's GPS page or as a section in the objective tracker; an arrow at your character leads along the walk, the route draws on the map and the minimap, and a beacon marks where the current step leads. A trip can take several stops, you can search along the route, share a route as a link, and a red line warns when the route crosses creatures far above your level. On WoW Forever, Classic Era and TBC Anniversary, walks follow a baked walking grid of the world: around cliffs and water, down the ledges your character can take, and around dangerous ground when you ask
- **Notes**: a companion for notes that know where they apply. Notes for places, activities, classes, targets and players show in tooltips, on names in chat, or open by themselves; checklists the game ticks off; tags, a trash with undo, share codes, and Ctrl+Right-click on any item or spell for its note
- **Chat**: a messenger for whispers and channels, with threads and history, searched from the bar
- **Clipboard History**: what you copied and pasted in game and every link that passed through chat, under @clipboard, with a key to open it and Add to note on any entry
- **Quicklists**: named result lists on a key, pressed or held, and a macro that opens one from an action bar
- **Creatures on the map search**: named creatures found by name, title, service or what they sell, each on its nearest spot and with their portrait; "repair", "food" or "ammo" finds who offers it
- **Classic Era and TBC Anniversary**: EasyFind runs on both: talents, professions and their recipes, reputations, the spellbook, the Skills tab, Looking For Group and the Social window in search, each opened in its own window, skill and talent ranks on a bar, and everything the client lacks kept out of the results
- **MoP Classic**: EasyFind runs on it, with currencies, collections, gear sets, the Group Finder, PvP, talents and the calendar in search, town services on the map search, and GPS routes that fly where your licenses allow
- **Result actions**: what a click, Alt-click and Ctrl-click do on each kind of result, set in the options; a key held with Alt or Ctrl does an action on the row under the mouse; an option makes a click select a row and Enter open it
- **Addon settings in the search bar**: every addon's settings, from the game's settings panel, from AceConfig options tables and from EasyFind's own panel, each changed on its row: a check box, a slider, a drop-down or a button, with Alt-click opening where it lives; other addons feed the settings of their own windows through the API
- **Extensions API**: other addons register search results, extensions, settings pages and actions through EasyFind.API, with a developer guide and an example extension
- **Extensions**: a row says what its click does on hover, carries the extension's data in its EasyFind link, has a menu of its own on right-click, lists only what it chooses when its @scope is empty, and is found from the map search and the GPS window when it knows where it is
- **Extensions menu**: arrange it by drag, and pop an extension out from a right-click
- **Theme Studio**: create your own custom themes, previewed live as you edit, and share them as a code
- **Themes**: new Classic and Forever themes in the 1.x style, with a talent tree of your choice as the background
- **Create macro**: on any result's menu, a macro that does it lands on your cursor for any action bar
- **GPS**: the caption under the arrow in the theme's own fill, with a border in the settings and the caption's menu; creatures as a filter in both map searches, off until picked
- **GPS**: enemy guards count as deadly ground at any level; a ledge to jump says where it is and the map marks it; Stormwind's Wizard's Sanctum is entered up its stairs; the trip fields show your last searches; a switch hides finished steps, and the window takes a text size
- **GPS**: a WIP tag after the time still to go says on hover that the estimates are still being worked on; the journey's end wears the map's own pin from any pick, a stop on the way its own icon, and on the classic clients the step's spot shows on the minimap and the bags' mount counts for riding
- **Notes**: the window's border is a choice, EasyFind's line or the theme's own frame art
- **Notes**: a note in several categories, tag chips in any color, a note shared as a link that opens on a click, and any checklist line can point at a target
- **Indicators**: a Chevrons style, the tutorial pointer's sliding chevrons

### Changed
- Each game client gets its own download, holding only what that client uses
- Per-character settings are keyed by the full name, so WoW Forever surnames stay apart
- Search: typos and abbreviations look words up instead of every entry, and result rows build in slices, so the first search never stalls the game
- Map search: equal matches list nearest first, and every row's subtext names its kind and place
- Options: the tabs sit in the game's settings list under EasyFind, and every companion's settings page uses the panel's own controls
- Travel: flight masters, zeppelins, boats, portals and the tram wear the map's own glyphs on every client, the boat a cargo ship drawn larger on the route
- Map search: the zone headers, their fold glyphs and the row hover glow are retail's on Classic Era and Mists Classic, drawn from a copy of retail's art

### Fixed
- GPS: a portal lands where the world database's portal to that place lands (the Caverns of Time portals landed in Shattrath and Dalaran); a tile at a zone border no longer warns of the neighbour zone's creatures; the danger line goes with its route and starts at the step numbers' edge
- Search bar: a press on the Forever band around the bar no longer closes it; result rows behind an open right-click menu keep still
- Settings rows: the subtext names the addon, then the page
- The Notes and Chat windows close on Escape through EasyFind's own dispatch, and the GPS section writes nothing into the objective tracker: both could taint the game's protected actions for the rest of the session (collapsing the tracker in combat errored)
- Search: Alt-click on a spell no longer opens the game's talents too
- Settings search: Toggle Objective Tracker hides the quest watch on Classic Era (it did nothing there)
- Map guide: a zone's "show me how" stays through a hover on the map, its arrow stands beside the continent on the classic world map and faces the zone, the right-click hint sits over the map's bottom with the mouse glyph, and the search box's X ends a guide
- Search boxes: the GPS, trip and map tab boxes drop their focus on a click anywhere else
- Themes: no bare strip between a window's painting and its square ring
- Map search: a double click no longer starts GPS directions; a row on another map opens that map before it pins
- WoW Forever: item and coin calls go through the replacements the client has, no spec rows where there are no specializations, Titles and the Equipment Manager follow the new sidebar
- Settings rows: the Toggle Sound and Toggle Minimap checkboxes follow a click, and Toggle Auto Self Cast flips self-cast instead of opening the settings
- Alignment: with ClassicUI Forever's world map, EasyFind's side tabs sit flush against the map's edge

---

## [3.4.4] - 2026-10-15

### Fixed
- **Patch 12.1.5**: no more error in chat at login. The patch removed the game's old item and coin functions, and EasyFind now calls their replacements, so loot and bag results show their names and icons again, along with catalog type names, coin text and toy cooldowns
- **Patch 12.1.5**: the map, statistics, reputation and other category icons show the right art again. They are textures of EasyFind's own now, so a patch that rearranges the game's art can no longer swap them
- **Translated labels**: on non-English clients, filter and menu labels that stayed in English now read in the game's language: the mount type and Unusable filters, the profession recipe filters, All Factions and All Races, Warband, Bags, Titles, Flight Paths and the Discovery recipe source
- **Appearances window**: opened from a search result on a non-English client, the Situations tab is hidden as it already was in English

### Changed
- EasyFind is marked up to date for patch 12.1.5
- **Toy filters**: the Expansions row is named Expansion, as in the game's own toy filter

---

## [3.4.3] - 2026-09-18

### Fixed
- **WoW Forever**: the beta no longer shuts down when EasyFind reads the wardrobe. Appearances, appearance sets, appearance items and outfits are not offered on that client at all, because there is no wardrobe behind them there
- **WoW Forever**: dragging an item out of a result row, and clicking one, work again
- **WoW Forever**: the Collections entries lead where they say. Mounts is gone, since the beta has no mount tab, and Appearances opens the tab it names instead of the one retail numbers
- Opening the Options window from the game menu during combat no longer raises a blocked action error. The search bar stays visible for the rest of the fight instead of hiding

---

## [3.4.2] - 2026-09-18

### Fixed
- **WoW Forever**: zones, flight masters and instances are back in search results (the beta's world map lists no continents under its top map, so the catalog now starts from the world the player stands in). The map search tab sits against the map window with a Quests tab above it to return to the quest log. The results dropdown no longer raises a secure-execution error when it closes. The map and reputation icons draw from the beta's own glyph sheet, and the Warband and specialization choices leave the filter menus. Retail is unchanged

---

## [3.4.1] - 2026-09-17

### Added
- **WoW Forever**: EasyFind now loads on the WoW Forever beta from the same download. The addon reads what the client actually has at login, so on Forever the search, filters, menu entries and map places only offer what exists there: no pets, toys, heirlooms, currencies, achievements, journal, group finder, arena, housing or class specializations, and the character panel's Skills, PvP, Currency and Statistics tabs are searchable. Retail is unchanged
- **Tutorial in chat on Forever**: on the beta the setup tutorial is offered as a chat line with a link instead of opening on its own

---

## [3.4.0] - 2026-09-11

### Added
- **Profiles**: everything you customized lives in a profile: settings, aliases, shortkeys, blacklist, snippets, extension buttons, pinned items, learned picks and keybinds. Each character remembers the profile you pick on it, and the picker suggests one for just this character and one for every character of its class. Turn on spec profiles and each specialization keeps its own, switching as you change spec. New, rename, copy from, delete and reset from the new Profiles tab in the options
- **Profile codes**: export a profile as a code, choosing which parts to include, and import one as a new profile with a preview of what it holds. Character-specific shortkeys and pins stay with their characters and never travel
- **Snippet codes**: export your snippets as a code from the Snippets settings page and import a code someone shared with you. A code carries plain text only
- **Import preview**: every code, whether aliases, shortkeys, blacklist or snippets, shows what it holds before anything applies: the rows it adds, how many replace yours, and what was left out, and a click on a row shows its content. A code that puts commands on keys or into macros says so up front, with a reminder to import only from a source you trust. A snippet that clashes with one of yours by name or keyword asks replace or skip, one at a time or for all, as aliases and shortkeys do

### Changed
- **Shared codes leave risky rows at home**: a code never carries a shortkey on a movement or camera key, Escape, Enter or Tab, a target that logs out, reloads or runs code, or an entry over 80 characters. Export says how many it left out and lists which on a click, each a link to the entry, and a code over 300 aliases, 100 shortkeys, 500 blacklist entries or 100 snippets is refused whole. Your own setup is never limited: these rules apply only to codes that travel

---

## [3.3.0] - 2026-09-09

### Added
- **Extension buttons**: drag any extension out of the extensions menu and it becomes a round button on screen. Drop it on the minimap to park it on the ring, where it takes the minimap border, or on the micro menu to make it a micro button with the game's own art. Click the button to open the extension and again to close it; right-click for lock, borders, shortkey and size; drag it to the remove target at the top of the screen to delete it. Escape cancels a drag in progress
- **Show me**: What's New can play a short demonstration of a new feature, with a cursor that does the steps for you. Escape stops it, and the popup comes back when it ends
- **Snippets: Ctrl+Enter**: type `\keyword` and press Ctrl+Enter to send the full expansion at once, no space needed. The snippet editor's hint says so
- **Settings search**: a search box above the options tabs finds any setting by its label, on any tab and any extension page. Enter or a click jumps to it and pulses the control
- **Clear All for snippets**: one button on the Snippets settings page, with a confirm, empties the list

### Changed
- **Hover help reads as help**: the addon's own tooltips wear a notch, a raised surface and a small gap from what you hover, so they no longer look like menus to click, and they never open by repeating the label the cursor is already on
- **One keyword, one snippet**: saving a snippet with a keyword another snippet already uses is refused and names the other, so a keyword never expands to the wrong text

### Fixed
- **Learned picks respect filters**: a result search put on top from a past pick no longer appears when its category is filtered out
- **Tooltips after scrolling**: the row under the cursor shows its tooltip once scrolling stops, without moving the mouse
- **Escape and the game's own windows**: Escape handling for drags and demonstrations no longer goes through the game's special-frame list, which could taint the game's window closing for the rest of the session
- **List scrollbars**: the scrollbar of the aliases, blacklist and snippets tables sits in the table's margin instead of over the remove buttons

---

## [3.2.0] - 2026-09-08

### Added
- **EasyFind links**: send a friend straight to any result, whether a setting buried three menus deep, an achievement, a profession window, or a mount. Press Ctrl+Shift+C on the row and paste it into chat with Ctrl+V, or right-click the row for a channel list. Anyone with EasyFind clicks the link and lands on that exact result, and where a click acts on the row it acts from the link too: it casts the spell, summons the mount, uses or equips their own copy of the item. Ctrl+click shows where the result lives, Shift+click passes the link on, and hovering shows the game's own tooltip with what a click does. Anyone without EasyFind sees plain text

### Changed
- **The right-click menu shows its shortcuts**: Send shows Ctrl+C and EasyFind link shows Ctrl+Shift+C, the same chords that copy from the result row, and both work while that menu row is highlighted. The Wowhead row shows its Ctrl+C prompt only while highlighted, since it has no row shortcut
- **Ctrl+C on any row**: a row with no chat link (a panel, a setting, a zone) copies its name instead of doing nothing

### Fixed
- **Ability icons no longer stay gray**: a row could keep a gray icon from an earlier result it had shown (Cat Form looked unusable while it was not)
- **The first search after login no longer reshuffles**: categories that load in the background are warmed shortly after login, so the first search paints once instead of rearranging a moment later

---

## [3.1.3] - 2026-09-06

### Fixed
- **Reduced stutter right after login**: searching in the first seconds of a session could freeze the game for a moment several times over while your professions finished loading. The profession list now waits for that data to arrive instead of rebuilding the search index on every attempt

---

## [3.1.2] - 2026-09-05

### Added
- **Forget this pick**: right-click a row that search put on top from a past pick to send it back to its natural place

### Changed
- **Snippets can be turned off**: it is listed under EasyFind in the AddOns list as "EasyFind [Snippets]"
- **Several picks per query**: picking different rows for the same query keeps up to three of them on top, ranked by how often and how recently each was chosen, instead of only the last one
- **A swapped first pair counts as a typo**: `ocntrol` finds Control and `ramor` finds Armor; a wrong first letter is still not a match
- **Same-name rows keep a fixed order**: when an ability and a talent share a name (Swipe), the talent lists first every session instead of whichever loaded first
- **Dungeon teleports rank like everything else**: typing a dungeon's nickname such as `bran` no longer lifts its teleport above items and toys whose names start with it. Typing the dungeon name out still ranks the teleport like an exact match, and a query that says teleport, tp, portal, dungeon, keystone, or mythic still puts it first
- **Category words no longer bury name matches**: typing `dungeon` lists Dungeon Finder and the other rows named for it first, then the nearby dungeons, instead of the dungeons above everything

### Fixed
- **Gathering professions are searchable again**: Herbalism, Mining and Skinning had lost nearly every entry (Lush Argentleaf, Mana Lily, Tranquility Bloom) to a data rule meant for world nodes; the rows their windows list are back, regenerated from the current game data
- **Profession recipes no longer go missing after login**: the recipe list could be built before the game had delivered profession data and then never rebuilt, leaving only the profession's own row; it now retries until the data is in and rebuilds when a profession window opens
- **Results no longer rearrange after you stop typing**: when a query pulled in a category that was still loading, the list painted once without it and again with it, so rows jumped around a moment after the last keystroke. The first paint now waits for that load
- **Achievement rows no longer shuffle the list a frame after each keystroke**: the game answers an achievement search one frame later, and the list used to paint without those rows and again with them mixed in; the first paint now waits that frame
- **Punctuation in what you type no longer hides rows**: a colon, hyphen or bracket in the query (`pattern:`, `raids (journal)`) made loot rows and multi-word names drop out the moment it was typed; the query is now cut into words the same way names are
- **Addon settings with colored or iconed names are searchable past the color**: an addon whose settings category name carries a color code or icon inside it (BetterBlizzFrames) matched only up to the color and vanished one letter later; the searchable name is now stripped of that markup
- **Exact and long keyword matches outrank typo matches**: a result that answers to the word you typed, or to five or more letters of it, now ranks above results whose name is merely one letter off (`brack` finds Brackenhide before the Black rows)
- **Escape closes what is on top**: with a setting's dropdown or a right-click menu open, Escape closes that first instead of dismissing the results underneath it
- **A remembered pick no longer appears twice**: the row you picked for a query showed at the top and again in its natural place; the copy is gone, achievements included
- **Learned picks stop following a query they no longer match**: typing past a remembered query keeps its pick on top only while the pick still matches what you typed

---

## [3.1.1] - 2026-09-03

### Fixed
- **Whispers no longer complete a name on their own**: typing `/w` and the first letters of a name filled in the rest of the name as if you had accepted it. The game's own suggestion works as before: the rest of the name stays highlighted and Tab accepts it

---

## [3.1.0] - 2026-09-02

### Added
- **Snippets, a new app**: save reusable text once and use it anywhere. Type `\keyword` in chat and it expands in place as you type, or send a snippet straight from its search result's menu. Placeholders (`{date}`, `{time}`, `{player}`, `{target}`, `{zone}`) fill in at use, and call-form keywords like `\greet(name)` take arguments. Typing a keyword in the macro editor expands and saves the macro in the same keystroke. Manage snippets from their Options tab, reached via the apps menu, searching "Snippets", or the `@snip` quick filter; a snippet shortkey fires the snippet directly
- **Choose the snippet trigger**: the activation character (`\` by default) can be changed to `!`, `#`, `~`, `&`, `+`, or `=` from the cog on the Create snippet button or in the editor's corner; one trigger applies to every snippet
- **Snippet call help**: typing `\keyword(` ghost-suggests the snippet's argument names the way the search bar's autocomplete does (typing narrows to the closest one, used args drop out), and typing `\keyword?` pops a tooltip with the call signature and the snippet text
- **Search inside the macro window**: the game's macro window gains a search bar that filters the macro grid on the current tab by name or body as you type. Clicking a filtered macro selects that macro, tab switches and edits keep the filter live, and clearing it restores the full grid
- **Ctrl+C copies a hovered result**: Ctrl+C on a result row copies a snippet's entire message or a link to the real clipboard, ready to paste wherever you want with Ctrl+V, with a "Copied" flash confirming. The Send menu's Clipboard option likewise now copies the full text instead of showing the shift-click link dialog
- **Ctrl+V pastes a real link into chat**: a copied item, spell, or achievement result pasted into the chat box becomes the live link (a snippet's embedded links come back too), while the same paste outside the game stays the readable name. The game strips link codes from anything pasted, so the copied text is recognized on arrival and swapped for its link in place
- The tutorial's Apps deck gains a Snippets slide, each Apps slide is titled with the app it shows, and updating players get a one-time pointer to the new app on the apps button

### Changed
- The options window and the tutorial are one settings row taller, and the aliases, blacklist, and snippets list cards align flush with the sidebar's bottom edge
- The row context menu's "Send link" entry is now just "Send"
- **The copy window is gone**: copy rows (Send > Clipboard, Wowhead, icon ID/name/path) wear a "Ctrl+C" hint and copy when you press Ctrl+C with the row engaged, by mouse or by keyboard, then read "Copied". Icon grid cells copy their ID with Ctrl+C directly, and either click opens the cell menu. Inline answers and the changelog link copy the same way. Only the `/ef bug` and `/ef feature` commands, which have nothing to hover, keep a small "Ctrl+C to copy" prompt at the cursor
- Searching "snippets" ranks the Snippets menu first and Create snippet second, ahead of whichever snippet was picked last

### Fixed
- Clicking an achievement result teaches the search again: learned picks (and aliases) on achievements were recorded but could never resurface, since achievement rows are built per query rather than stored
- Clicking an unpinnable row (Create snippet, the snippets menu) now teaches the search too; unpinnable had been treated as unlearnable
- Achievement results scroll the achievement window to the target again after a game update removed the function that did it; the guide and direct-open now scroll the list themselves when it is missing
- Snippet results appear on the first search after a reload instead of two seconds later: the snippets provider now loads the moment a query names it

---

## [3.0.1] - 2026-08-31

### Added
- **Find dungeon teleports by dungeon name**: type a dungeon's name or its common nickname (`boralus`, `mots`, `doti`) and your unlocked "Path of ..." teleport surfaces near the top, ready to cast; searching the flavor name is no longer required. Covers every teleport spell in the game across all expansions, with dungeon names localized in every language

---

## [3.0.0] - 2026-08-31

### Added
- **Icon Search, a new app**: type `@icons` (or open it from the apps menu, or search "Icon Search") to browse all game icons in a live-filtered grid. Left click opens a window to copy the icon's FileDataID; right click offers copy ID/name/path and creating a macro with that icon, blank-titled, plain or with a `#showtooltip` first line. Search understands words with plural matching (`swords`), alternatives (`sword/axe`, or comma-separated queries), exclusion (`-inv`), wildcards (`inv_sword_*`), IDs (`135274`, `#135274`), and the game's own link forms (`spell:133`, `item:6948`) including shift-clicked chat links
- **Search inside the macro icon picker**: the game's own icon picker (macro creation, and anywhere else it appears) gains an EasyFind search bar running the same engine. It steps aside automatically if another icon-picker addon is present, and can be turned off in Options > Search
- The entire Icon Search module (data, grid, picker bar) ships as the `EasyFind_Icons` companion addon, loaded on demand: it costs nothing at login and nothing ever until the first time icon search is actually used, and can be disabled entirely from the AddOns list
- **Fully keyboard-driven grid**: Down enters (or Tab from the search box), arrows and Alt+HJKL move, Enter copies, Tab opens the icon's menu, ESC steps back out. Same conventions as the rest of the search bar
- **Menu keyboard flow**: Right on a focused result row opens its context menu (Tab still works); Left or Shift+Tab backs out of any keyboard-opened menu to the row or cell that opened it, one level at a time through submenus. Hovering a menu row moves the keyboard selection to it, so exactly one row is ever highlighted: whichever input you used last wins

### Changed
- **New default look**: fresh installs start on the Midnight theme with window borders off; existing setups keep their saved choices
- **Filter button hover** drops the gold ring; the glow alone is the hover and focus look, matching the apps button
- **Tutorial texts condensed** so slides no longer overflow the wizard window

### Performance
- Typing no longer spikes the CPU: search work runs under a per-frame budget and spreads across frames, so the worst cold-cache keystroke went from several-hundred-millisecond stalls to under 50ms, and the average typing frame now costs the same as standing idle
- Memory comes back when you're done: closing the search bar or the world map sweeps that surface's caches and garbage, a settle pass after login reclaims one-time startup construction, and the icon dataset releases its working memory whenever the grid closes
- Idle CPU is now zero: menu and popup closers are event-driven (no per-frame polling), the scrollbar driver disarms itself when idle, and theme restyling runs only when the theme actually changed
- The searchable database (collections, achievements, currencies, ...) is built on first search-bar focus instead of at login, and the item and icon datasets load on demand: sessions that never search carry none of it
- The search index survives provider updates without rebuilding (removals cost one flag), and its posting lists are compressed to a fraction of their former memory
- Scrolling results no longer recomputes badges per frame, re-renders mid-scroll, or fires tooltip machinery for rows passing under the cursor

### Fixed
- **Catalog items get a real identity**: learned search, aliases, pins and shortkeys now key catalog items by item ID through the one shared identity system. Picking a catalog item after a search teaches the ranking like any other row; pinning one rarity variant no longer also pins its same-named siblings; and pinned catalog items show their proper icons in the pinned view without needing a search first
- A gear set's spec badge (and an outfit's lock overlay) could linger on unrelated rows that recycled the same row frame
- An active quick filter's view (including the icon grid) no longer gets replaced by pinned items when focus bounces off menus or popups
- Keyboard-focused menu rows show the normal themed highlight instead of a gold overlay
- Several tutorial slides and POI labels shipped untranslated in most locales; all translated, and a new CI check now blocks untranslated locale values from ever shipping again

---

## [2.4.5] - 2026-08-24

### Added
- **Calculator money math**: gold/silver/copper amounts work in any expression. `4g / 5` gives `80s`, `4g50s * 2` gives `9g`, and a lone amount like `450s` converts (`4g 50s`). Accepts `g`/`s`/`c` and `gold`/`silver`/`copper`, compounds like `4g 50s`, and decimals like `1.5g`. Gold results group thousands the way the game does (`25,000g`)

### Fixed
- **Keyboard menu navigation**: Tab to the apps button and Enter now opens a keyboard-navigable apps menu (arrows, Enter to launch, ESC back to the button); previously Enter opened a menu you couldn't drive
- **ESC in filter menus** closes one level at a time (submenu, then parent, then the menu) instead of tearing the whole chain down at once; ESC out of a keyboard-opened menu visibly reselects its toolbar button, so Enter reopens it and Tab moves on
- **Apps menu and filter menu** can no longer be open at the same time; opening one closes the other on every open path, including keyboard opens
- **Alt+number result shortcuts** no longer type the digit into the search box while activating the result
- **Tab-completing a filter token** (like `@mo` for Mounts) no longer re-appends the partially typed token to the search text
- **Copy window clicks**: closing the copy/link window no longer also closes the results list; clicks on EasyFind's own floating windows are no longer treated as clicks outside the search UI
- **Calculator icon** brightened to match the rest of the interface icons across all themes

---

## [2.4.4] - 2026-08-23

### Fixed
- **World Map tab compatibility**: switching from EasyFind's map tab to another addon's map tab no longer shows a blank gray panel on the first click, and closing the map from such a tab reopens correctly. EasyFind now only restores Blizzard's sidebar when its own panel closes with no successor tab

---

## [2.4.3] - 2026-08-18

### Added
- **Search learns from your picks**: pick a result after typing a query and it appears at the top the next time you type that search, or a lazier version of it (teach it on "glad mount" and "glad" is enough later). Works for everything searchable. Aliases you set yourself always outrank learned picks
- **Learn from picks toggle and Forget button**: both in Options > Search. The toggle stops learning and boosting; the button permanently forgets everything learned, after a confirmation, without touching aliases, shortkeys or any other setting

### Changed
- **Options panel**: content starts slightly higher in every tab

---

## [2.4.2] - 2026-08-18

### Added
- **Category words show your zone's results first**: typing a category word like "flight", "fm", "fp", "tp", "delve" or "bank" now puts your current zone's results of that category at the top of the list, no setup needed. A "This zone only" checkbox in the filter menu's Map Search flyout narrows category words to just your zone, hiding that category's other-zone results entirely
- **Whole-category aliases**: the Add alias dialog on map results gains a checkbox that binds your trigger to the whole category ("Flight Paths", "Portals") instead of one spot; the dialog title follows the choice. Category aliases always reach their category, even with map filters off

### Fixed
- **Duplicate map rows**: a map result boosted to the top by an alias no longer appears a second time further down the list

---

## [2.4.1] - 2026-08-16

### Fixed
- **Aliases now force their result to the top**: an aliased entry stayed at its natural rank when it also matched the search on its own, and typing past the alias text dropped the boost entirely. An alias now pins its result first for the whole query
- **Aliases match like result names do**: aliases now go through the same matching as every result name, prefixes, word starts, and typo tolerance included. The best alias match ranks first, and junk typed past an alias no longer keeps it pinned on top
- **Alias boosts follow the 2-character minimum**: a single keystroke no longer surfaces every alias containing that letter. A deliberate single-character alias still fires when typed exactly
- **Great Vault icon**: repointed to where patch 12.1 moved it on the sprite sheet

---

## [2.4.0] - 2026-08-15

### Added
- **Apps button**: a new dot-grid button on the search bar opens the apps menu. Calculator is the first app, with more on the way
- **Calculator can be disabled**: the calculator now ships as "EasyFind [Calculator]", its own entry in the AddOns list. Disable it there and every trace of it goes away; while enabled, inline math and searching "calculator" work exactly as before
- **Search options**: new "Show app button" and "Show filter button" toggles. Unchecked, the button stays hidden until you hover over its spot on the bar

### Changed
- **Calculator follows your theme**: the calculator window's keypad, input box, and result box now match the active theme and restyle live when you switch. Its icon wears the same theme color everywhere it appears
- **Search options layout**: the Wowhead language selector now sits with the other selector rows

### Fixed
- **Search results could close when clicking a popup**: clicks on confirmation dialogs and the calculator window no longer count as clicking outside the results

---

## [2.3.0] - 2026-08-14

### Added
- **Switch specialization from search**: your specs appear as Talents results; click one to swap
- **Load talent loadouts from search**: your current spec's saved loadouts load with one click, no talent window needed. The loadout and spec you are on are marked in green
- **Talents filter options**: new Specialization and Loadouts toggles in the Talents filter menu control whether these rows appear

---

## [2.2.1] - 2026-08-10

### Fixed
- **Updated for patch 12.1**: bumped the supported game version and repointed the icons the patch moved

---

## [2.2.0] - 2026-08-04

### Added
- **Professions search**: your recipes are now searchable by name. Enable it under Professions in the filter menu
- **Item catalog**: every item in the game is now searchable, not just the ones you own. Find it under Items in the filter menu, or type `@gen`
- **Bank search**: your bank and the warband bank are searchable from anywhere. `@bank` is yours, `@warband` is the account's. Enable it under Items in the filter menu
- **Items on your other characters**: search what your alts are carrying, bags and banks alike. Choose whose storage feeds your results in the filter menu
- **Inline answers**: type `gold`, `item level`, `durability`, `keystone`, `bag space`, `rating` or `speed` and the answer appears above your results. Click it to copy, gold included, which pastes as `1g 2s 3c`
- **Toy and pet filters**: toys filter by collected state, source and expansion; pets by collected state, source and family
- **Send item links to chat**: click or drag any item result to pick it up, then click a chat channel to link it there. Search results can also be added to a Note
- **Unearned titles**: the Titles filter can now list titles you have *not* earned. Hovering one shows the achievement that awards it, and clicking opens straight to it. Switch Titles to Incomplete or All in the filter menu
- **Statistics filter**: narrow statistics to Recorded or Not Recorded
- **Equipment Manager filters**: gear sets can be narrowed to a single specialization, and a set assigned to a spec shows that spec's icon on its row
- **Tooltips on hover**: achievement results show their full tooltip with progress, criteria and reward, and title results show the tooltip of the achievement that grants them
- **`/clear`** clears the chat window

### Changed
- **Loot results behave like every other item row**: click or drag links the drop, Alt opens the Encounter Journal, Ctrl previews it in the dressing room
- **Uncollected pets** open the Pet Journal when clicked, instead of doing nothing
- **Smaller download**: four textures right-sized to what is actually drawn, 1.8 MB down to 213 KB

### Fixed
- **Wowhead links for titles** pointed at an unrelated page. Titles now link to the achievement that awards them
- **Toys, mounts and outfits could stop working after a search**: revealing one in its journal left the game's own button unusable, so your next click on it did nothing
- **Escape could stop responding**: EasyFind held onto the key while having nothing to close. It now hands the key back the moment it has nothing to dismiss
- **The search bar could sink behind other windows while typing**
- **Multi-word statistic and achievement searches**: "gold per day" now matches "Average gold earned per day"
- **Reagent bag contents were unsearchable**
- **Missing icons**: uncollected pets lost theirs, and currency and reputation rows fell back to a question mark
- **Result names could be cut short** with room to spare
- **Menu hover highlights**: filter menu rows no longer lose their highlight behind the menu, and the filter button keeps its hover look while its menu is open

---

## [2.1.4] - 2026-07-21

### Added
- **Data broker support**: if you use a display bar that hosts data broker objects, EasyFind can now be launched from it instead of the minimap button. Left-click toggles the search bar, right-click opens the options. Every other way in still works, Auto-Hide included, and nothing changes if no such display is installed.

### Fixed
- **Welcome screen**: the version number is no longer cut off in the tutorial's welcome title

---

## [2.1.3] - 2026-07-19

### Fixed
- **IME input**: typing with a composition-based input method (Chinese pinyin, Korean, Japanese, and similar) should no longer corrupt the search text. Inline autocomplete now pauses while a composition is open and resumes the moment it commits or cancels, so completion keeps working in every language, including completing committed CJK text

### Added
- **Autocomplete toggles**: separate options to turn inline autocomplete off for the search bar (Search options) and the map tab search box (Map options)

---

## [2.1.2] - 2026-07-14

### Added
- **Themes**: choose how EasyFind looks from a set of themes, picked during setup and changeable at any time from the options menu
- **Blacklist**: right-click any result and choose Blacklist to keep it out of every search; manage and restore blacklisted results from the new Blacklist tab in the options menu
- **Icon visibility**: choose whether results show all icons, general icons only, or specific icons only
- **Rooms filter**: hide rooms from housing results, since rooms can't be opened from the housing dashboard
- **Shortkey import**: importing shortkeys that clash with existing ones now lets you replace or skip each one (or apply your choice to all), and warns you when an imported shortkey binds a system command

### Changed
- **Search window opacity**: can now be lowered all the way to 50%

### Fixed
- **Window border**: borders no longer reactivate when they aren't enabled
- **Mount and toy guides**: searching for a mount or toy now walks you to it in the Mount Journal or Toy Box
- **Chat frame toggle**: no longer shows an Alt-click settings hint for a menu it doesn't have
- **Achievements**: no longer disappear from search when the game's achievement search stops responding mid-session
- **Adventure Guide bosses**: no longer listed more than once when the same boss appears in several tiers

---

## [2.1.1] - 2026-07-11

### Added
- **Always Show**: a third visibility mode that keeps the search bar permanently on screen, with combat options (hide in combat, or dim it instead) and an optional dim while moving; the tutorial gained a slide for picking how the bar appears
- **Focus Search Bar keybind**: focuses the always-shown bar directly (enabled while Always Show is active)
- **Hide window border**: new option for a borderless search bar and menus
- **Manual resize**: back under the Size menu; dragging the height snaps to whole result rows and stays in sync with the Result Rows setting, and the scale presets stack on top
- **Expansion currency groups**: search an expansion plus "currencies" (like "midnight currencies") to list every currency from that expansion inline
- **Housing filter menu**: the Housing filter now carries the catalog's full Filter menu (sort and tag options), kept in sync with the catalog window in both directions
- **@housing and @commands quick filters**

### Changed
- The search bar now sits behind game windows like other HUD elements; open results and menus rise above the action bars while in use
- Toggle All in the filter menus now only affects its own level, and the Services submenu gained its own Toggle All
- The reset buttons now also reset window sizes and are named "Reset Size & Positions" and "Reset All Sizes & Positions"
- Better result ranking for short and common-word queries
- Download size reduced from 22 MB to under 5 MB and installed size from 82 MB to 14 MB: tutorial images now ship in the game's native compressed texture format, and unused image files were removed. No visual difference.
- The "Gear" filter is now called "Loot", matching the loot results it covers
- Consolidated tutorial slides: gear sets, outfits, and titles share one slide, as do macros with abilities and toys with slash commands, and the inline-settings slide moved to the Actionables walkthrough
- Search data for filtered-off categories is no longer loaded and indexed at all until the category is re-enabled

### Fixed
- Ability results now open the spellbook to the exact page in one click, including abilities not yet learned
- Opening the spellbook or talents from a search result no longer causes "EasyFind has been blocked" action-bar errors and spellbook cooldown errors during combat; both the open and the tab switch now run through the game's own protected input path
- Pressing Escape to close a window no longer risks the same combat errors (EasyFind windows now close via a temporary key binding instead of the game's window list)
- Result clicks now fire their action regardless of the game's cast-on-key-down combat setting (previously, turning that setting off silently broke mount, spell, and macro results)
- Shortkeys now bind immediately at login from saved data instead of waiting for search data to load
- Pressing a shortkey now always triggers the same action as left-clicking its row
- Loot results match their gear-slot keywords correctly again, and stat searches can combine two stats
- Dungeon and raid loot no longer permanently vanishes from search when the game's journal data hadn't finished arriving during a background scan; already-affected installs heal automatically on next login
- Characters without a specialization (below level 10) now get loot results for their whole class instead of none
- Toys, pets, titles, heirlooms, currencies, and reputations no longer stay empty in search for a whole session when the game hadn't finished loading their data at login; each now retries once its data arrives
- Pinned outfits update again when outfits are changed or reordered (an internal rename had disconnected that sync)

---

## [2.1.0] - 2026-07-07

### Added
- **Send link**: Right-click any result to share a clickable link in chat (Say, Yell, Party, Instance, Raid, Guild, a whisper by name, or a link box you can shift-click into any chat message); works for items, spells, mounts, pets, housing decor, achievements, currencies, and bosses, and statistics share as ready-made "name: value" text
- **Housing search**: Search housing decor, with a Housing filter (Collection, Dyeable Only, Collection Bonus, Placeable); clicking a result opens the catalog with that item searched
- **Filter subcategories**: Instances split into Raids/Dungeons/Delves, Travel gathers Flight Paths/Boats/Portals, and Services breaks out Banks, Auction House, Innkeepers, Mailboxes, Trainers, Vendors, and more, on both the map tab and the search bar filter menu
- **Menu keyboard navigation**: Tab from the search box reaches the filter menu, Tab or Right descends into filter flyouts and right-click submenus, Left backs out
- **Shortkeys**: Right-click any result to bind a key that opens it instantly, without typing or opening the search bar; managed from Aliases & shortkeys in the options
- **Wowhead links**: Right-click items, spells, mounts, achievements, currencies, and more for a copy-ready Wowhead URL
- **Account-wide keybinds**: EasyFind's keybinds now apply on every character (including with character-specific key bindings) and are set from EasyFind's options instead of Blizzard's keybinding panel
- **New fonts**: Inter, Lato, and Poppins available in the options
- **Updated tutorial**: New and reworked slides so the tutorial covers everything above

### Changed
- "vsync" now finds the Vertical Sync graphics setting
- Per-button action bar keybindings (such as "Action Bar 3 Button 3") no longer clutter search results; the action bars themselves still appear
- Removed the redundant "Achievements Tab" entry from search results
- Improved the reveal behavior for collection search results
- The hotkey step of the tutorial now shows the recommended keybinds
- Typing in the search bar stays smooth even with large collections and the housing catalog loaded
- During combat the search bar closes and shortkeys are disabled; everything comes back when combat ends

### Fixed
- Search now matches words that follow a hyphen, so "alias" finds "Anti-Aliasing" and "fov" finds "Field of View"
- Search results no longer vanish moments after they appear while an inline suggestion is showing
- Pinning a command now floats it to the pinned section immediately instead of appearing to do nothing
- Pinned macros now run when clicked, and always run the macro's current text even after edits
- Opening a raid or dungeon from search no longer triggers a blocked-action error when the Adventure Guide switches tabs
- The "Transfer" option in a currency's right-click menu highlights the currency, then the Transfer button on its popup
- Options on/off toggles flip the moment you click them, instead of waiting for the next mouse-over
- Several Smart Show fixes: the search bar no longer gets stuck hidden or stuck visible after selecting a result, and a toggled-off bar no longer intercepts clicks in its old spot
- Unchecking the Rares map filter now stops rare auto-tracking, and re-enabling auto-track refreshes the open map immediately
- Clicking options inside the row right-click menu's submenus no longer closes the menu without acting

---

## [2.0.1] - 2026-06-21

### Changed
- Updated for WoW patch 12.0.7

### Fixed
- The Statistics, Map Search, and Options filter icons display correctly after Blizzard reorganized the shared icon sheet in 12.0.7

---

## [2.0.0] - 2026-05-13

EasyFind 2.0 is a full rewrite of the search and map experience. Launch the in-game tutorial to see what's new.

---

## [1.5.0] - 2026-04-07

### Added
- **Loot Search**: Search dungeon and raid loot by item name, slot, stats, boss, or instance. Filter by class, specialization, and difficulty. Click a result to navigate directly to the item in the Encounter Journal
- **Transmog Outfit Search**: Your saved transmog outfits appear in search results. Click to equip, with cooldown tracking and active-outfit indicators
- **Outfit Lock Status**: Locked outfits display a visual overlay on their icon with lock details on hover
- **Transmog Browse Mode**: Opening the transmog window via search hides vendor-only controls and shows guidance messages. All controls restore when the window closes or when visiting a transmogrifier
- **Clear Button for Navigation**: The search bar clear button now appears during active step-by-step guides and dismisses highlights and arrows in addition to clearing text
- **Dynamic Category Ordering**: Search result categories (UI, Mounts, Loot, etc.) sort by best match score instead of a fixed order

---

## [1.4.0] - 2026-03-20

### Added
- **Rare Mob Tracking**: Active rare mobs in your zone appear as searchable pins on the world map. Search "rare" in the zone bar to see all nearby rares, or click individual rare names to track them with Blizzard waypoint tracking
- **Auto-track Rares**: Toggle in the zone search filter dropdown or the Map options tab. When enabled, all active rares are automatically pinned on the map without searching. Pins persist at last known position when rares leave detection range and clear when killed
- **Great Vault (Rewards)**: Great vault rewards panel now searchable in UI search
- **"NEW" Feature Labels**: New or experimental features display a glowing label with a tooltip encouraging feedback

### Fixed
- **Adventure Guide Fast Mode**: Direct open now works for all Adventure Guide tabs (Journeys, Dungeons, Raids, etc.)
- **Combat Lockdown**: Fixed errors that could occur when reloading the UI during combat or by taking portals

### Changed
- **StaticLocations Cleanup**: Standardized bank and guild vault naming across all zones

---

## [1.3.1] - 2026-03-17

### Added
- **Independent Map Navigation Modes**: Local and global map search bars now have separate direct-open toggles instead of a shared setting
- **Expanded POI Coverage**: Added portals in Tirisfal Glades, decor specialists, and additional innkeepers, auction houses, and mailboxes across multiple zones

### Changed
- **Slash Commands**: `/ef` now opens options directly. `/ef toggle` (shorthand `/ef t`) replaces `/ef show`/`/ef hide`. Added `/ef help` for a command overview
- **Options Panel Dropdowns**: Redesigned with WoW-style open/close arrows and indented child options

### Fixed
- **New Map POI Categories**: Decor specialists, crafting order NPCs, rostrum, pet and riding trainers, and training dummies now properly appear in map search results
- **Tooltip Clarity**: Map search bar editbox now shows bar identity (Zone/Global Search) and the current mode. Mode toggle button describes only the toggle action

---

## [1.3.0] - 2026-03-15

### Added
- **New UI Search Categories**: Enable each via the filter dropdown on the search bar
  - **Mounts**: Search your collected mounts by name. Click a result to summon. Icons show combat tint when unavailable
  - **Toys**: Search collected toys with cooldown sweep overlays. Click to use
  - **Battle Pets**: Search your collected battle pets by name. Click to summon a companion
  - **Map Search**: Search map POIs (zones, dungeon entrances, flight masters) directly from the UI search bar. Includes waypoint placement on hover
- **Mode Toggle Button**: Interactive fast/guide mode toggle flush-left in the search bar, replacing the static search icon. Syncs with the options panel checkbox
- **Filter Dropdown Enhancements**: Per-filter icons, "Toggle All" button, and Shift+Up/Down section jump for keyboard navigation
- **Independent Maximized Map Bars**: Zone and instance search bars position independently in full-screen map mode with separate saved positions
- **Hide Bars in Full Screen Map**: New option to hide both map search bars when the map is maximized

### Changed
- **Tab/Shift+Tab Navigation**: Now cycles through all toolbar controls (mode button, editbox, clear button, filter button) in left-to-right order

### Fixed
- **Quest Tracking Coexistence**: User waypoint auto-reclaim no longer overrides active quest tracking
- **Encounter Journal Fast Mode**: Protected tabs in the Encounter Journal now hand off to the guide system instead of failing silently
- **Short Query False Positives**: 2-char abbreviations like "fp" no longer match unrelated items through incidental keyword initials (e.g., "flight paths" in Travel Statistics)
- **Scrollbar Overlap**: Fixed map search results overlapping with scrollbar in certain configurations
- **Breadcrumb Arrow in Full Screen**: Arrow position, animation, and direction now update correctly when switching between maximized and windowed map modes

### Technical Notes
- **Search Performance**: Word-split cache, reusable Damerau-Levenshtein row tables, module-level sort comparator, pre-split query words, and incremental narrowing (extending a query re-scores only previous matches)
- **Memory Reduction**: Search results store `{data, score}` references instead of shallow copies. `__index` prototypes for bulk-injected mount/toy/pet entries. Staggered population across frames to avoid single-frame stutter
- **Keyword Initials Penalty**: Scaled by query length to eliminate noise from short queries while preserving useful matches for longer abbreviations

---

## [1.2.7] - 2026-03-10

### Added
- **Keyboard Navigation**: Full arrow key, Tab, and Enter support for navigating search results without a mouse. Works in both UI search and map search bars. Tab/Shift+Tab toggles between a parent row and its expand/collapse button. Arrow keys in map search preview the pin location before confirming
- **Visual Rescaler**: Drag handles on search bars and results panels to resize width, adjust row count, and change font size interactively. Shift+drag the search bar itself to reposition it along the map edge
- **Smarter Search**: Vowel-stripped abbreviations now match (e.g. "qtr" finds "quartermaster", "windrnr" finds "windrunner"). Multi-word queries match per-word with fuzzy and subsequence support (e.g. "twlght hghlnds" finds "Twilight Highlands")
- **Major POI Expansion**: Added points of interest for Stormwind, Orgrimmar, Ironforge, Thunder Bluff, Darnassus, Undercity, The Exodar, Silvermoon City, and Valdrakken. Includes class trainers, profession trainers, quartermasters, banks, inns, barbers, stable masters, guild services, and more
- **Bug Report and Feature Request**: `/ef bug` and `/ef feature` as well as buttons in the options panel to open pre-filled GitHub issue URLs for easy reporting
- **New options**:
  - Toggle+Focus keybind: combined show+focus in one keypress, targets map search bar when world map is open
  - Clear All keybind: dismiss all highlights, map pins, zone highlights, and breadcrumbs
  - Auto-track new pins and auto-clear on arrival
  - Pin highlight box toggle (show/hide yellow highlight square around map pins)
  - Map Smart Show (auto-hide map search bars until hover)
  - Map search Y-offset slider
  - Results above option for both UI and map search bars
  - Separate max visible row counts for UI search (default 10) and map search (default 6)

### Changed
- **Indicator Arrow**: Arrow always bobs and pulses regardless of the Blinking Pins setting. Blinking Pins now only controls whether pins and highlight boxes pulse in sync
- **Blinking Pins Default**: Changed default to enabled (was disabled)
- **Filter Button Triangle**: Filter buttons show only the dropdown arrow by default; hovering reveals the full button with a blue highlight glow
- **Zone Navigation Arrows**: The arrows that guide you between maps now highlight with a shape that matches the button instead of a generic glow
- **Reputation Search**: Parent factions (e.g. "Horde Expedition") are now searchable in addition to individual reputations
- **Background Opacity**: Opacity slider now controls only the search bar background, keeping text and icons fully visible (default lowered to 0.75)
- **Options Panel**: Reorganized with Speed boxes, two-column keybinds, and tighter section spacing. Theme selector moved to General section
- **Keyword Scoring**: Short abbreviations (2-3 chars) like "bg" now boost exact keyword matches above initials matching so common abbreviations rank higher
- **Keyboard Shortcuts Text**: Reorganized into clearer "From the search box" and "From the results list" sections
- **Map Results Theme**: Map search results dropdown now matches the selected theme (Classic or Retail) and updates live on theme switch
- **Filter Button Highlight**: Keyboard navigation now shows the filter button's own highlight style instead of an overlay rectangle

### Fixed
- **Escape from Results**: Escape now properly deselects without refocusing the search editbox. Results stay visible for re-entry
- **Stale Selection**: Clicking back into the editbox after Escape now resets the selection instead of leaving it stuck
- **Enter on Result**: Pressing Enter on a search result now closes results and unfocuses the editbox, matching click behavior
- **Enter on Toggle**: Pressing Enter on an expand/collapse toggle no longer refocuses the search bar
- **Pinned Items Navigation**: Arrow keys now work on pinned items shown from an empty focused editbox
- **Chromie Detection**: Chromie (timewalking NPC) now properly detected and included in search results with real icon
- **Zone Reguiding**: Clicking the wrong zone during step-by-step navigation now correctly reguides you back to the target instead of stopping
- **Zone Highlighting**: Fixed many zones not highlighting correctly on continent maps, including cities (Stormwind, Ironforge, etc.), remapped zones (Isle of Quel'Danas), and multi-step navigation between continents
- **Unclickable Zones**: Zones with bugged click regions (Uldum, Vale of Eternal Blossoms) now handled with fallback navigation
- **Dalaran and Dungeon-type Zones**: Fixed these zones missing from global search results
- **Instanced Zone Snap**: Fixed Vision of Stormwind/Orgrimmar and similar instanced zones snapping to wrong locations
- **Exodar/Azuremyst**: Fixed navigation trying to go backward instead of highlighting the zone directly
- **Currency/Reputation Navigation**: Fixed navigation sometimes failing when opening currencies and reputations
- **Adjacent Zone Filter**: Fixed filter incorrectly hiding some valid results like Conquest Quartermaster
- **Cross-zone Minimap Glow**: Minimap glow no longer appears for pins outside the player's current zone. Previously showed bogus arrows for pins on other continents or distant zones
- **Trailing Whitespace in Search**: Trailing spaces no longer break search scoring or category matching

### Technical Notes
- **Fuzzy Length Tolerance**: Queries of 6+ characters now allow 2-character length differences when fuzzy matching, reducing missed results for longer words
- **Independent Indicator Animation**: Indicator arrow has its own Alpha animation group so it pulses independently of the parent highlight frame
- **Unified Animation Duration**: All animation durations consolidated into a single ANIM_DURATION constant
- **Atlas Zone Highlights**: Zone highlighting now supports atlas-based textures in addition to fileDataID textures
- **Shared Helpers**: Scroll, click, and frame-search patterns refactored into Utils.lua, reducing code duplication across Highlight and UI modules
- **Shared Constants**: Extracted duplicated constants (colors, sizes, string paths) into ns.* values in Utils.lua
- **Defensive Hardening**: Added pcall protection to flash ticker and all initialization timers. Added SavedVariables type validation to prevent corrupted settings from breaking the addon
- **Results Layout**: Improved pin separator spacing and scroll position preservation when toggling category headers
- **Continent Projection Fallback**: Zones with very small scan areas now fall back to continent-level projection
- **Highlight Hover Timer**: Reduced minimum display time from 1.0s to 0.3s for snappier hover-dismiss behavior
- **GetScript Error**: Fixed error when calling GetScript on non-Button frames

---

## [1.2.6] - 2026-03-05

### Added
- **Map Search Filters**: Filter global and local search results by category - zones, dungeons, raids, travel, services, etc.
- **Minimap Button**: Optional minimap icon to toggle the search bar (left-click) or open options (right-click); draggable to reposition
- **Search Results**: Results list is now scrollable with no hard cutoff

### Changed
- **Waypoint Tracking**: Map pins now place a native WoW waypoint with full supertrack arrow support

### Fixed
- **Player Housing and Scenario Zones**: Clicking these in global search now navigates directly to the zone instead of placing a pin at the screen corner
- **Navigate Button**: Grayed out and blocked when viewing a zone the player is not currently in
- **UI Reload**: Modules now correctly initialize after `/reload`

---

## [1.2.5] - 2026-03-04

### Added
- **Show Login Message Toggle**: Option to hide the "EasyFind loaded!" chat message on login

### Changed
- **Navigate Button**: Waypoint pin icon now only appears on local map search results (removed from zone/instance global search results where it didn't apply)
- **Login Message**: Simplified to just mention `/ef o` for options

### Fixed
- **Results Dropdown Overflow**: Fixed search results spilling past the bottom of the screen; clamping now uses actual measured row heights instead of a fixed estimate
- **Map Close Cleanup**: Fixed bouncing arrow indicator remaining visible after closing the world map
- **Pin Persistence**: Map pins now auto-clear when you leave the zone; pins only restore on map reopen if you're still in the same zone
- **Missing Flight Masters**: Fixed Stormwind, Redridge, and other flight masters not appearing due to overly strict zone-name filtering

---

## [1.2.4] - 2026-02-16

### Added
- **Pinned Paths**: Right-click any UI or map search result to pin it as a bookmark. Pinned items appear at the top of results and persist across sessions. Collapsible header keeps things tidy
- **Click-to-Navigate Map Pins**: Click any local map search pin to place and track a native WoW waypoint
  - Waypoint pin is automatically removed when the game reports "Reached Destination"

### Changed
- **Map Pin**
  - **Default Map Pin Size**: Map pin icons and highlight boxes reduced to ~50% of previous size for less visual clutter on the world map
  - **Map Pin Hover Behavior**: Local search pins now show a waypoint tooltip instead of auto-dismissing on hover; global search pins retain the original hover-to-dismiss behavior
    - Can still remove local search pins by either right clicking them, hitting the clear button on the search bar, or with /ef clear
  - **Blinking Map Pins Option**: Map pins now solid by default, but there is a new toggle in Options panel to enable/disable the map pin pulse animations

### Fixed
- **Missing Icons**: Fixed missing icons for portrait menu items and other UI search results that previously showed blank

---

## [1.2.3] - 2026-02-13

### Added
- **Reputation Search**: Search and navigate to any faction reputation; shows standing progress bar with renown level, friendship rank, or traditional standing (Honored, Exalted, etc.)
- **Currency Amounts in Results**: Currency search results now display your current quantity inline
- **Movement Fade**: Search bar fades to lower opacity while your character is moving (can be disabled with Static Opacity option)
- **Match Highlighting**: Direct search matches are highlighted in gold to distinguish them from parent category context

### Changed
- **Search Abbreviations**: Common shorthand now works more consistently; "tww", "df", "bfa", "mop", "wod", "sl", "cata", "wotlk", "tbc", etc.
- **Smart Result Cap**: Results no longer cut off mid-category. If a header is the last visible row, its children are included automatically
- **`/ef show`**: No longer auto-focuses the search box. Bar appears without stealing your input
- **`/ef` command**: Bare `/ef` now shows usage help instead of toggling the bar; use `/ef show` and `/ef hide` instead
- **Escape in Map Search**: Pressing Escape now just unfocuses the search box instead of clearing your query, so you can click back in to resume
- **Container Browsing**: Category headers in search results can now be expanded to browse all their contents, not just matched items

### Fixed
- **Search Icons**: Fixed icons not displaying correctly in currency search results
- **Reset All Settings**: Properly resets everything to defaults

---

## [1.2.2] - 2026-02-12

### Added
- **Reputation**: Reputation panel of character info window now included in search results
### Changed
- **Default Keybinds**: No keybinds are set by default on new installs (previously `[` and `]`)
  - Users who want keybinds must configure them manually via Options panel
- **Unearned Currency Detection**: Unearned currencies (quantity = 0) now display grayed out in search results with a tooltip
  - Tooltip shows "Not yet earned" on hover using a custom tooltip frame (doesn't interfere with game tooltips)
  - Grayed-out currencies are non-clickable to prevent failed navigation attempts

### Fixed
- **Critical Keybind Bug**: Fixed addon automatically enabling character-specific keybinds and disabling all keybinds on characters without character-specific keybinds
- **Nested Currency Navigation**: Fixed guide failing to highlight nested currency headers (e.g., "Warlords of Draenor" under "Legacy")

---

## [1.2.1] - 2026-02-10

### Fixed
- **`/ef clear` now clears everything**: Previously only dismissed UI search highlights; now also clears map POI highlights, zone highlights, and breadcrumb navigation indicators
- **Breadcrumb arrow glow**: Glow was missing or clipped because the arrow frame was parented inside WorldMapFrame. Reparented to UIParent so the glow renders fully even when the arrow sits at the map edge
- **Breadcrumb arrow brightness**: Arrow and glow were dimmed by the parent highlight's blinking alpha animation; arrow now renders at full brightness
- **Arrow bob animations**: Standardized all arrow bob animations across the addon (UI search, map POI, zone, breadcrumb, multi-pin) to use consistent direction (toward target), offset (10px), and duration (0.4s)
- **Zone arrow directional bob**: Zone highlight arrows now bob in the direction they point (down, up, left, or right) instead of always bobbing upward
- **Breadcrumb arrow animation**: Breadcrumb arrow now bobs like all other arrows instead of being static
- **Glow intensity**: Reduced glow alpha from 0.7 to 0.35 so bright arrow colors (Yellow, Gold, White) don't wash out the arrow shape into a blob, especially against yellow zone highlights
- **Map search tooltip**: Tooltips now only appear when hovering the magnifying glass icon, not the entire search bar border
- **Breadcrumb arrow size**: Increased default from 24px to 48px to match all other arrow indicators

---

## [1.2.0] - 2026-02-10

### Added
- **Arrow Customization**: Full visual customization for all arrows and indicators
  - **Arrow Style**: Choose from 4 arrow textures (EasyFind Arrow, Classic Quest Arrow, Minimap Player Arrow, Cursor Point)
  - **Arrow Color**: Pick from 8 color presets (Yellow, Gold, Orange, Red, Green, Blue, Purple, White)
  - All arrows update in real-time across map search, zone highlights, UI search, and breadcrumb navigation
  - Unified sizing system: one Icon Size slider controls all arrows uniformly
- **Map Search Enhancements**:
  - **Additional Search Bar**: Added a separate search bar for global search instead of having just one with a toggle to make it easier to switch between local and global without additional mouse clicks
  - **Dungeon & Raid Entrance Search**: Find instance portals across the world through global map search bar (still tweaking things here)
  - **Zone Abbreviations**: Type common shortcuts like `sw` (Stormwind), `dal` (Dalaran), `org` (Orgrimmar), `if` (Ironforge), etc.
- **Keybinds**: Added customizable keybinds for quick access
  - Toggle UI Search Bar (default: `[`)
  - Focus Search Bar (default: `]`) (Jump to search input or toggle focus)
  - Configure via Options panel or ESC > Keybinds > EasyFind
- **First-Time Setup Overlay**: New users now get an interactive setup experience with a golden highlight overlay, drag-to-position, and corner resize handle. Setup completes automatically and won't appear again after clicking Done.
- **Smart Show**: Hide the search bar until you hover over it. Keeps your screen clean while staying accessible.
- **Search Bar Opacity Slider**: Adjust transparency of the UI search bar to see through it better.
- **Visual Themes for Results**: Choose between two dropdown themes in Options:
  - **Retail**: Uses retail Quest log style, as well as rounded edges for search bar
  - **Classic**: A more basic, barebones look reminiscent of addons in the Classic WoW days
- **New Slash Commands**:
  - `/ef hide` - Hide the search bar
  - `/ef show` - Show the search bar
  - `/ef clear` - Dismiss active highlights and guides

### Changed
- **Search Bar Visual Improvements**:
  - Removed hide button in favor of new default Smart Show mode and/or keybind toggle
  - Removed clear highlights button in favor of /ef clear command since errors with persistent highlighting should be less common
- **Unified Icon Sizing**: Icons changed to be identical and changing settings for one affects all indicators (map arrows, UI arrows, zone arrows, pins)
- **Search Scoring Refactor**: ScoreName and ScoreKeywords moved to Database.lua for unified fuzzy matching across UI search, map POI search, and zone search
- **Zone Search Scoring**: Minimum score threshold raised from 0 to 50 for cleaner zone results
- **Default Theme**: Changed from Classic to Retail for new installs
- **Default Keybinds**: Set `[` and `]` as defaults on first install
- **Toggle Button Removed**: Deprecated the floating toggle button. Use keybinds or slash commands instead
- **Options Panel Redesign**: Complete 2-column layout redesign
  - Left column: Sliders (Icon Size, UI/Map Search scales, opacity)
  - Right column: Checkboxes, Results Theme, Arrow Style, Arrow Color, keybind configuration
  - Expandable Advanced Options section
  - Integrated keybind capture UI with shared helpers
  - Custom flyout dropdowns for theme/arrow selection (replaces UIDropDownMenu to avoid Blizzard global state pollution)

### Fixed
- **Canvas-to-UI Conversion**: icons now properly maintain consistent screen size across zoom levels
- **Arrow Auto-Refresh**: style/color changes now properly apply instantly when you change settings in options panel without manual refresh
- **Results Dropdown Gap**: Fixed visual gap between search bar and results frame by overlapping frames slightly
- **Shift+Click Behavior**: Holding Shift while clicking the search bar no longer focuses the editbox when you try to move the box around
- **Map Search UX**: Dungeon maps now excluded from zone navigation to prevent dead ends

### Technical Details
- Dungeon entrance caching: `ScanAllDungeonEntrances()` results cached per session to avoid redundant C_Map lookups
- Zone highlight stacking: 4 layers of zone texture with ADD blending for high-visibility continent map highlights

---

## [1.1.0] - 2026-02-08

### Added
- **Dynamic Currency Loading**: All currencies from your character's Currency tab are now automatically searchable, including new seasonal currencies and legacy currencies from past expansions
- **Missing Statistics Categories**: Added 10+ missing statistics categories including Kills, Quests, Skills, Travel, Social, Delves, Pet Battles, Proving Grounds, Legacy, and World Events

### Changed
- **Search Results Sorting**: Results now sort by relevance score first, then alphabetically (previously only alphabetical)
- **Currency Tree Structure**: Reorganized currency database into proper nested tree with multi-level header support

### Fixed
- **Improved DirectOpen Mode**: DirectOpen now executes all navigable steps automatically, only showing highlights for non-clickable UI regions
- **Achievement/Statistics Category Navigation**: Completely rewrote category navigation to use Blizzard's data provider API instead of unreliable text matching
  - Categories now highlight properly in all tabs (Achievements, Guild, Statistics)
  - Nested categories (like "World" under "Player vs. Player") now work correctly
  - Fixed infinite loop bug where guides would re-guide users after reaching subcategories
  - Instruction textboxes no longer appear for categories that exist in the sidebar
- **Prerequisite Validation**: Parent categories now check if they're expanded rather than selected, fixing navigation bugs with multi-level categories

### Technical Details
- Localized all global functions (math, string, table) for faster execution
- Pre-calculated search query lengths and pre-lowercased database entries
- Optimized frame iteration using `select()` instead of table allocations
- Added `Utils.lua` module for shared utilities and localized globals
- Implemented `PopulateDynamicCurrencies()` to scan `C_CurrencyInfo` API at login
- New data-driven category helpers: `FindCategoryElementData()`, `FindVisibleCategoryButton()`, `IsCategoryExpandedOrSelected()`
- Removed deprecated `FindWarModeButton()` in favor of direct frame paths
- Event frame cleanup: one-time events now properly unregister after firing

---

## [1.0.0] - Initial Release

### Added
- UI Search: Find and navigate to any interface element
- Map Search: Locate important places across Azeroth (portals, banks, trainers, etc.)
- Guide Mode: Step-by-step visual guidance with yellow highlights and arrows
- Direct Open Mode: Instantly open to your destination
- Achievement and Statistics navigation
- Draggable search bar with scale options
- Slash command `/ef` to toggle UI search
