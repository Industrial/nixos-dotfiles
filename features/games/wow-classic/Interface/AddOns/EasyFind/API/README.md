# EasyFind extension API

EasyFind is a search bar for World of Warcraft. Its extensions menu, search results, filter menu and settings panel are open to other addons through `EasyFind.API`. EasyFind's own extensions (Calculator, Icon Search, Snippets, Clipboard History, Notes, GPS, Quicklists, Chat) are built on the same API, so anything they do, yours can do.

What an extension can add:

- A tile in the extensions menu, with its icon, a description, a count badge and its own right-click rows. Users can drag it onto the screen or the micro menu like any other.
- Search results: its own rows in the search bar, a row under Extensions in the filter menu, an `@scope` that lists only its rows, and what a click on a row does.
- A settings page in Options > Extensions, built with EasyFind's own controls.
- Actions other extensions can call, and events they can listen to.

Most of this guide is reference. Start with [Fitting in](#fitting-in): what EasyFind requires is short, and the rest is how to make an extension feel like part of EasyFind.

## Version

```lua
EasyFind.API.VERSION -- 1
EasyFind.API.MINOR   -- rises when something is added
```

`VERSION` changes only for a change that would break an extension. MINOR 1 added the `choice` option, a row's `iconDimmed`, a place's `icon`, and the GPS button on rows a `place` leads; MINOR 2 the provider's `iconWell`; MINOR 3 the provider's `places` and `ShowPlaces(key, row)`; MINOR 4 a row's `createRow`, a linked checklist category's `window` and `RegisterRowDecorator`; MINOR 5 a decorator's `select` and `hint`; MINOR 6 a decorator's `aliases`, `browse` and `candidates`, and `HasRow` and `HasCreature`; MINOR 7 a row's `scopedName`, a row's place words from its `mapID`, a decorator's `words`, its `name` candidates and its scope shared with your own provider of the same key, a linked checklist's `adopt` and `drop` and its lines' `name`, `RegisterPriceSource`, `RefreshPrices` and `RegisterAuctionSearch`; MINOR 8 a decorator's `modifiers` and `RedrawRowTooltip`; MINOR 9 `RegisterTrackerPiece`; MINOR 10 `RegisterUpgradeJudge`, `UnregisterUpgradeJudge` and `RefreshUpgrades`; MINOR 11 `RegisterItemSources` and `OpenMap`; MINOR 12 `SliceCheckpoint`; MINOR 13 sections and named rows from `RegisterItemSources`, and `CreatureName`. Check it once at load if you use something added later:

```lua
local API = EasyFind and EasyFind.API
if not (API and API.VERSION == 1 and API.MINOR >= 1) then return end
```

## Quick start

A complete extension: a tile that prints a line, found by typing its name.

`EasyFind_Hello.toc`:

```
## Interface: 120105, 16001
## Title: Hello for EasyFind
## Dependencies: EasyFind

Hello.lua
```

`Hello.lua`:

```lua
local API = EasyFind.API

API.RegisterExtension({
    id = "hello",
    name = "Hello",
    description = "Says hello.",
    icon = "Interface\\AddOns\\EasyFind\\textures\\apps-icon", -- EasyFind's own, until you draw yours
    open = function() print("Hello from an EasyFind extension") end,
})
```

Type `hel` in the search bar, or open the extensions menu: the tile is there.

A fuller example, a bookmarks extension with its own search results, scope, settings page, action and event, is in [`API/example/EasyFind_Bookmarks`](example/EasyFind_Bookmarks).

## Supporting EasyFind without requiring it

Most addons that add EasyFind support should keep working without it. List EasyFind as an optional dependency, and register only when it is there:

```
## OptionalDeps: EasyFind
```

```lua
if EasyFind and EasyFind.API then
    EasyFind.API.RegisterSearchProvider({ ... })
end
```

That is the whole cost: users without EasyFind see nothing different.

## Fitting in

Your extension sits right next to EasyFind's own: in the extensions menu, in search results, in the filter menu and in the settings panel. Users notice when something matches, and an extension that looks and behaves like the rest feels like part of EasyFind rather than something bolted on. EasyFind requires very little; the rest of this section is what makes the difference.

### What EasyFind requires

Only a few things, and EasyFind checks them when you register, with an error that names what is missing:

- An extension has an `id`, a `name` and an `icon`.
- A search provider has a `key`, a `label` and the `extension` it belongs to, registered first. With no icon of its own it uses the extension's.
- Each field has the type this guide gives it.

One thing EasyFind does for every extension: it paints the icon in the theme's icon color wherever it shows (the menu tile, buttons on screen, launcher rows, the glyph by your rows, your filter row). That is how every icon follows the user's theme, dark or light, with no work from you. Icons you put on your own rows, such as an item's icon, keep their colors.

### Icons

![EasyFind's icons in three themes, with the example's bookmark at the end](icons/easyfind-icons.png)

EasyFind's icons share one simple style, and an icon drawn the same way looks like it always belonged in the menu. Since EasyFind paints it, it changes with every theme just like the others.

| | |
| --- | --- |
| Size | 64x64 pixels, a TGA file with transparency. |
| Color | White. EasyFind paints it, so any other color is lost. |
| Lines | Outlines about 5 px wide, with rounded ends and corners. Small dots and short bars inside a shape can be filled. |
| Margin | 5 to 10 px clear on each side, the drawing centered. A small detail can come closer, but not touch the edge. |
| Subject | One simple object that says what the extension does. No text, no background square, no shading. |

A game icon (the square pictures in your spellbook) still works, but painted in one color it turns into a solid square, so a drawn one is worth it. You don't need to be an artist; the kit in [`API/icons`](icons) does the fiddly parts:

- [`template.svg`](icons/template.svg): a 64x64 canvas with the margins marked and a sample drawn at the right line width. It opens in Inkscape, Figma, Illustrator or any editor that reads SVG.
- [`make_icon.py`](icons/make_icon.py) (Python 3 with Pillow) turns your drawing into the icon file and tells you how close it is to the style:

```
python make_icon.py convert my-drawing.png icon.tga
python make_icon.py check icon.tga
```

It also draws in code at EasyFind's line width: the example's bookmark is `draw_bookmark()` in that file, ready to copy and change.

Ship the `.tga` in your addon's folder and give its path without the extension:

```lua
icon = "Interface\\AddOns\\MyAddon\\icon",
```

### Colors and windows

- Take colors from `GetThemeColor` instead of fixed values, and repaint in `OnThemeChanged`. Users pick from many themes, light ones included, and your window then changes along with EasyFind's.
- `StylePanel` gives a window EasyFind's border and fill, and keeps them in step with theme and opacity changes for you. `CreateButton` and `ShowDialog` match EasyFind's own. See [Looking like EasyFind](#looking-like-easyfind).
- Build a settings page with the kit `settings` receives: the same checkboxes, flyouts and steppers as the rest of the panel.

### Text

- A name of one or two words reads best on a tile. The description is one short sentence.
- Text should fit at the largest font and in EasyFind's narrowest window: anchor wrapping text to both sides of what holds it rather than giving it a fixed width.
- Translating what users see (names, descriptions, menu rows, settings) makes an extension feel at home for players in every language.

### Staying light

EasyFind loads with every character, so an extension is at its best when it costs nothing until it is used.

- Put a large extension's work in a load-on-demand addon (see [Load on demand](#load-on-demand)).
- Run no per-frame code while your window is closed.
- Mark a provider `eager` only for a small list; a large one waits for its `words`, its filter or its scope (`lazy`).
- In a `rows` that walks a long list, call `SliceCheckpoint()` once per item (MINOR 12): EasyFind builds rows a few milliseconds a frame, and the call lets the frame go when its share is spent. Anywhere else it does nothing.
- Call `NotifyOpenChanged` when your window shows or hides, so buttons users placed on screen show it right.

## Extensions

### RegisterExtension(def)

| Field | Type | |
| --- | --- | --- |
| `id` | string | Required. Letters, digits, `-` and `_`. Keep it the same across versions: menu layouts and buttons on screen save it. |
| `name` | string | Required the first time. Shown on the tile, its tooltip and its launcher row. |
| `description` | string | One line under the name in tooltips. |
| `icon` | texture path or file id | Required the first time. Painted in the theme's icon color wherever it shows. See [Icons](#icons). |
| `iconCoords` | `{ left, right, top, bottom }` | Texture coordinates for `icon`. |
| `open` | function | Opens the extension. |
| `close` | function | Closes it. |
| `isOpen` | function | Returns whether it is open. With `close`, a second click on the tile closes what the first opened. |
| `menu` | function | Returns rows for the tile's right-click menu (below). |
| `settings` | function `(page, kit)` | Builds its settings page. See [Settings pages](#settings-pages). |
| `keywords` | string list | Words that find its launcher row in the search bar. Its name always does. |
| `hideFromSearch` | boolean | No launcher row in the search bar (for an extension whose own rows already stand there). |
| `scope` | string | Its surface is that `@scope`'s list in the search bar: opening shows it, the tile is open while it is up. No `open` needed. |
| `experimental` | string | A line of warning in its tooltip. |
| `addon` | string | A load-on-demand addon holding the rest. See [Load on demand](#load-on-demand). |
| `loadInCombat` | boolean | Its addon may load, and it may open, in combat. Leave it off if your addon creates secure frames at load. |
| `loadAtLogin` | boolean | Its addon loads at login, not on first open: for one that works unopened, such as recording. |

An extension with only `settings` opens its settings page when clicked.

Menu rows, on top of EasyFind's own (its settings, its button on screen):

| Row | |
| --- | --- |
| `{ kind = "action", label = text, onClick = fn, tooltip = text }` | A command. |
| `{ kind = "check", label = text, get = fn, set = fn }` | A switch: `get()` returns it, `set(on)` stores it. |
| `{ kind = "separator" }` | A line between groups. |
| `{ kind = "menu", label, rows }` | A flyout of more rows: a list, or a function returning one. |

Registering an id again adds to it, which is how a load-on-demand extension fills in its tile later.

### Other extension functions

| Function | |
| --- | --- |
| `OpenExtension(id)` | Opens it as a click on its tile would. |
| `CloseExtension(id)` | |
| `ToggleExtension(id)` | |
| `IsExtensionOpen(id)` | |
| `IsExtensionRegistered(id)` | |
| `LoadExtension(id)` | Loads its addon if it loads on demand. True when it is registered and its addon (if any) is loaded. |
| `SetBadge(id, count)` | A count on its icon wherever the icon shows. `0` or `nil` clears it. |
| `NotifyOpenChanged(id)` | Call when your window shows or hides, so its button on the micro menu shows pressed or not. |

## Search results

### RegisterSearchProvider(def)

| Field | Type | |
| --- | --- | --- |
| `key` | string | Required. Its filter key, and its `@scope` key when it has `aliases`. |
| `label` | string | Required the first time. What its rows are ("Shopping Lists"): its scope's pill and quick filter. The filter menu's Extensions flyout has one row per extension, with its name and icon, so a player sees which addon a filter belongs to. An extension with more than one provider gets one row all the same: it turns them all on or off, and its flyout has a switch for each provider, named by its label, then their `options`. |
| `category` | string | The name its rows carry. Defaults to `key`. |
| `icon`, `iconCoords` | | The glyph left of each of its rows, painted like an extension's. Its extension's when not given. |
| `iconWell` | boolean | `true`: a row's icon on the map's pin (a pick in the map search, a route's end) sits in a dark round well ringed in gold. For small glyphs on a clear ground (a quest's "?"), which vanish in the map's art; an older EasyFind ignores it (MINOR 2). |
| `rows` | function | Returns its rows (below). Called when its rows are first needed and after `RefreshSearchProvider`. |
| `select` | function `(row)` | A click or Enter on one of its rows. Gets a copy of the row. |
| `tooltip` | function `(row, tooltip)` | Fills `GameTooltip` for a row. Return `true` to show it. |
| `leave` | function `(row)` | The cursor left one of its rows. |
| `words` | string list | Typing one loads its rows. |
| `eager` | boolean | Its rows are searched from the first keystroke. For small lists only. |
| `lazy` | boolean | Its rows show only through its words, its filter or its scope, never in plain results. |
| `lowResults` | boolean | Also loaded when a search finds little. |
| `aliases` | string list | An `@scope`: `@` and one of these lists only its rows. |
| `browse` | function | `browse(row)` returns whether the row is in the scope's list while nothing is typed (a quest log, not every quest). Without it, every row is. Typing searches all rows either way. |
| `place` | function | `place(row)` returns where the row is right now, `{ name, mapID, x, y, step, icon }` as `navigate` takes, or nil. Its rows are then found from the map search and the GPS window too, and a pick there pins or routes to that spot. A row with no `x` of its own gets the GPS button to that spot, and `icon` marks the route's end on the map. A row's `mapID` names the map it is on, for the map's own list. |
| `places` | function | `places(row)` returns every spot the row stands for, a list of `{ name, mapID, x, y, step, icon }` (MINOR 3). The row stays one entry in the map search, its spots pinned together on the viewed map and ranked by the nearest, as a cluster of same-named places is; the map's own list shows it where one of its spots is. `place(row)` stays the one spot for the GPS. |
| `link` | table | `{ key = function(row), resolve = function(tail) }`. A row's EasyFind link (Send, the Ctrl+Shift+C copy) carries `key(row)`, a short string of yours, such as an id and the sender's progress. On the receiver, whose copy of your extension resolves it, `resolve(tail)` returns the row to show: its tooltip, hint and click are yours as for any row, so the tooltip can show what the sender sent. Without `link`, a row's link finds the receiver's own row by name. Keep the key short: it travels inside a chat message. |
| `menu` | function | `menu(row)` returns rows for the result's right-click menu, in the tile menu's shape (`{ kind = "action", label, onClick, tooltip, closes }`, `{ kind = "check", label, get, set }`, `{ kind = "separator" }`, `{ kind = "menu", label, rows }` for a flyout within). They sit under one row named after your extension, with its glyph. Return nothing for a row with no rows of its own. An action that opens another window sets `closes = true`: the search bar steps aside after it, as it does after a chosen result (MINOR 5); one that stays in the bar (a pin, a list added to) leaves it out. |
| `options` | list | Toggles on its filter row's flyout: `{ label, tooltip, get, set }`, `{ header = text }`, `{ separator = true }`, or one-of-several radio rows `{ choice = { { label, value, tooltip }, ... }, get, set }` (`get` returns the value, `set` takes it; MINOR 1). `label` and `tooltip` may be functions. |
| `hint` | string, table or function | What a row's gestures do, shown under its name on hover: a sentence, or `{ click, alt, ctrl, shift }` with each gesture's target ("Click: Directions \| Alt: Quest log"), or a function of the row returning either. A row's own `hint` wins. |
| `extension` | string | Required the first time: the extension it belongs to, registered first. Its addon loading on demand, `select` loads it first. An extension whose addon is turned off shows no filter row or scope. |
| `loadOnSearch` | boolean or function | Load the extension's addon when its rows are first needed. |

A row is a table:

| Field | |
| --- | --- |
| `name` | Required. What is searched and shown. |
| `icon` | Texture path or file id, shown at the row's right in its own colors. |
| `iconDimmed` | `true`: the icon is drawn gray, for a row out of reach (a quest the character cannot take yet; MINOR 1). |
| `createRow` | `true`: the row makes a new thing (Create shopping list). It wears the green plus badge of EasyFind's own Create snippet and Create note rows, and never travels as a link (MINOR 4). |
| `scopedName` | `true`: the row's name is searched only under your `@scope` (`ShowScope` too); everywhere else only its `keywords` find it. For a row that repeats one of EasyFind's own (an item in your group, which a decorator already marks): `@yours linen` finds it by name, `linen` lists EasyFind's row alone, and your group's words still list it (MINOR 7). |
| `keywords` | More words that find it. |
| `mapID` | The map the row is on. MINOR 7: the row answers to its place too, the map's name and the zones over it up to the continent, the short names players type for them (org) and the continent's initials (ek), so "decor durotar" finds it; leave those out of your `keywords`. |
| `searchCommandDesc` | Its subtext: a dim note shown with the name. |
| `hint` | What its gestures do, as the provider's `hint`, for this row alone. |
| anything else | Kept on the row: `select` and `tooltip` get it back. |

```lua
API.RegisterSearchProvider({
    key = "bookmarks", label = "Bookmarks", icon = "Interface\\AddOns\\MyBookmarks\\icon",
    words = { "bookmark", "bookmarks" }, eager = true, aliases = { "bm" },
    rows = function()
        local out = {}
        for i, b in ipairs(MyBookmarks) do
            out[i] = { name = b.name, bookmarkIndex = i }
        end
        return out
    end,
    select = function(row) GoTo(MyBookmarks[row.bookmarkIndex]) end,
})
```

### RegisterAddTarget(def)

An entry in a result's right-click Add flyout, beside Note and Quicklist: a place the row can be added to.

| Field | Type | |
| --- | --- | --- |
| `key` | string | Required. Registering a key again replaces it. |
| `extension` | string | Required, registered first. Its icon marks the entry, so a player sees which addon it comes from. |
| `label` | string | Required. Its name in the Add flyout ("Shopping list"). |
| `fullLabel` | string | Its name when it is the menu's only Add entry ("Add to shopping list"). Defaults to `label`. |
| `applies` | function `(row)` | True for the rows it takes. Without it, every row. |
| `rows` | function `(row)` | Required. The flyout's rows, in the tile menu's shape (the provider `menu` above). Nothing returned: no entry. |
| `onClick` | function `(row)` | A click on the entry itself, for its most common use (a new list); its flyout still opens on hover. |

```lua
API.RegisterAddTarget({
    key = "wishlist", extension = "mywishlist", label = "Wishlist", fullLabel = "Add to wishlist",
    applies = function(row) return row.itemID ~= nil end,
    rows = function(row)
        return { { kind = "action", label = "Main", onClick = function() AddToWishlist(row.itemID) end } }
    end,
})
```

### RegisterRowDecorator(def)

Your mark on rows another provider owns (MINOR 4): a price at the right of EasyFind's item rows, your entries on the right-click menu of quest, zone or boss rows. No rows of your own, nothing typed to find them: the rows EasyFind already has carry it.

| Field | Type | |
| --- | --- | --- |
| `id` | string | Required. The extension of that id, registered first, lends its icon; `extension` names another. |
| `slot` | string | Where `text` paints. One decorator per slot shows, the first registered; `"price"` is the slot at a row's right. |
| `label` | string | Your entries' name when they fold under one row. |
| `applies` | function `(row)` | True for the rows you take, by their fields (`row.questId`, `row.mapID`, `row.npcID`, `row.itemID`). Without it, rows with an `itemID`, narrowed by `categories`. |
| `categories` | string list | With no `applies`: the item rows' `category` names you take (`"Bag"`, `"Loot"`). |
| `text` | function `(row, link)` | At paint, for shown rows: a string, or copper EasyFind formats as coins, or nil for nothing. A second value is a state word EasyFind paints from the theme: `"good"`, `"warn"`, or `"dim"` (the default). Never a color code. Asked once per row until the rows rebuild or you call `RefreshRowDecorations`. |
| `tooltip` | function `(row, link, tooltip)` | Your lines under the row's own tooltip (`AddLine`, `AddDoubleLine`). |
| `modifiers` | boolean | MINOR 8. `true`: your `tooltip` reads the held keys (`IsControlKeyDown()`), so the row's tooltip is drawn again as Ctrl, Shift or Alt goes down or up while it shows. The row's clicks and Ctrl+C stay as they are. |
| `menu` | function `(row, link)` | Rows for the row's right-click menu in the tile menu's shape (`{ kind = "action", label, onClick, tooltip, disabled, closes }`, `check`, `separator`, `menu`). They land in the menu itself, each wearing your icon; `disabled = true` grays one out, its `tooltip` saying why; `closes = true` on an action that opens another window steps the search bar aside after it (MINOR 5). |
| `submenu` | boolean | `true`: your menu rows fold under one row named `label`, as they do by themselves past four. |
| `subtext` | function `(row)` | A part appended to the row's subtext. |
| `select` | function `(row, link, gesture)` | MINOR 5. On a client without the Adventure Guide (Classic Era, TBC Anniversary, Mists Classic, WoW Forever), a boss row's gestures and a loot row's journal gesture (Alt by default, the row's "source" gesture) ask the first decorator taking the row, `gesture` being `"click"`, `"alt"` or `"ctrl"` (Shift stays EasyFind's link). Return `true` when you handled it; anything else falls through to EasyFind's own action for that gesture (the boss's loot listed, directions to the instance), so a decorator answers the gestures it wants and leaves the rest. Never asked where the client has the Adventure Guide. |
| `hint` | function `(row)` | MINOR 5. With `select`: the words for the row's hint while you take it. A word is the click's (`"DungeonJournal"`); a table `{ click, alt, ctrl }` names each gesture's, and EasyFind's own word stands for any you leave out, so a boss row reads "Click: DungeonJournal | Alt: Loot" from `{ click = "DungeonJournal" }`. EasyFind writes the gesture before the word. |
| `aliases` | string list | MINOR 6. An `@scope` over EasyFind's rows you take: `@att linen` searches them, `@att` alone lists them. The scope's key is your `id` (`ShowScope(id)` opens it); an id a provider's scope already holds keeps the provider's. MINOR 7: a decorator whose `id` is your own provider's key shares that provider's scope, `aliases` or not: it lists your rows and EasyFind's rows you take, each side's `browse` deciding its own rows while nothing is typed; map rows you take (creatures, places) join once text is typed. Its pill reads `label`, else your extension's name. The rows stay EasyFind's, with your subtext, tooltip lines and menu entries. |
| `browse` | function `(row)` | MINOR 6. With `aliases`: whether the row is in the scope's list while nothing is typed (on this map, not yet collected). Without it, every row you take. |
| `candidates` | function | MINOR 6. The rows you take, named by field before `applies` is asked: a table of row fields to sets of their values, `{ itemID = { [13335] = true }, speciesID = { [1234] = true } }`. A row carrying none of the values is never yours; one that does is yours, or is asked `applies` when you have one. Asked once, and again after `RefreshRowDecorations`. Fields rows carry: `itemID` (Item, Loot, Bag, Bank, Warband), `mountID` and `spellID` (Mount), `speciesID` (Pet), `toyItemID` (Toy), `appearanceItemID` (Appearance), `heirloomItemID` (Heirloom), `titleID` (Title), `achievementID` (Achievement), `professionRecipeID` (Profession), `housingRecordID` (Housing), `npcID` (a creature). MINOR 7: `name`, a lowercase name to a set of mapIDs, `{ name = { ["faruza"] = { [1] = true } } }`: a row so named on one of those maps or in the same zone, as `HasRow` matches (place and service rows carry no id). Give it when your `applies` is a lookup in your own data: the scope's list walks every loaded row. |
| `words` | function | MINOR 7. Words EasyFind's rows you take are found by, given when the search builds: `{ npc = { [npcID] = { "decor", "vendor" } }, name = { ["faruza@1"] = { "decor" } } }`, a creature by its id, a place or service row by its lowercase name and a map, matched in that map's zone as `HasRow` matches. "decor durotar" then lists the decor vendors EasyFind has in Durotar. Asked once, and again after `RefreshRowDecorations`. |
| `keep`, `sortKey` | function `(row)` | Held for the filter flyout (a toggle dropping rows, a sort choice); registered now, acted on in a later MINOR. |

`link` is the bag item's link, the loot row's, else `"item:ID"`; nil on a row without an item. `UnregisterRowDecorator(id, slot)` takes it back; `RefreshRowDecorations()` repaints the shown rows (new prices after a scan); `RedrawRowTooltip()` draws the hovered row's tooltip again, for lines that changed while it shows (a spell's text that arrived; MINOR 8). The map tab's own rows have the game's menu, not this one.

```lua
API.RegisterRowDecorator({
    id = "spoken", label = "Spoken",
    applies = function(row) return row.questId ~= nil or row.npcID ~= nil end,
    menu = function(row)
        local voiced = HasVoice(row)
        return {
            { kind = "action", label = "Play", disabled = not voiced, tooltip = voiced and "Hear it" or "No voice for this line yet",
              onClick = function() Play(row) end },
            { kind = "action", label = "Open in Compendium", closes = true, onClick = function() OpenCompendium(row) end },
        }
    end,
})
```

### RefreshSearchProvider(key)

Your rows changed: they are rebuilt now, and an open search shows them.

### RegisterUpgradeJudge(def)

MINOR 10. Your verdict on `@upgrades` for the character played now, where EasyFind compares each dungeon and raid drop with what the character wears. `def.extension` names you; `def.rate(itemID, link)` answers a number (the percent the drop beats the worn piece by, shown on the row), `true` (an upgrade with no number, nothing worn there), `false` (no upgrade: the drop is left out) or nil (not rated: EasyFind's own comparison stands for that drop). Judged drops lead each slot, the biggest gain first; EasyFind still keeps to the armor the class wears and the weapons it uses. Other characters' pages keep EasyFind's comparison. One judge at a time: the last registered judges. `UnregisterUpgradeJudge(extension)` takes it back; `RefreshUpgrades()` has the page built again when your verdicts change (a drop rated, the gear changed).

### RegisterItemSources(id, fn)

MINOR 11. Where an item comes from, as your extension knows it. A click on an item row opens the item's sources page: who sells it (the GPS extension's vendors, nearest first), which bosses drop it, and your rows under a heading of your extension's name. `fn(itemID, name)` returns rows in the shape of a search provider's (the quests that reward the item, the recipes that make it), or nothing. Typing on the page narrows every section by name.

MINOR 13. `fn` may return `{ sections = { { label = text, rows = list, key = word }, ... } }`, a heading each; a section keyed `"sold"` or `"dropped"` joins EasyFind's own Sold by or Dropped by. A row can name what it is and EasyFind draws its own row for it, clicked as it is anywhere:

| Row | |
| --- | --- |
| `{ creature = npcID, note = text }` | EasyFind's creature row at its spot nearest the player, its GPS button included. |
| `{ item = itemID, note = text }` | EasyFind's item row; a click opens that item's own sources page. |
| `{ spots = { mapID, x, y, mapID, x, y, ... }, name = text, kind = category, icon = texture, note = text }` | A place at its spot nearest the player, pinned and led to as a map row is. |

| `{ name = text, note = text }` | A line of text: a world drop's levels, how many more there are. |

`note` is the row's subtext (a drop's chance, how many a recipe needs); `label` renames a row; `name` stands in where EasyFind has nothing for the id (a creature its catalog lacks), else the row is left out. Any other row stands as given.

### The search bar

| Function | |
| --- | --- |
| `OpenSearch(text)` | Shows the search bar focused, with `text` searched when given. |
| `ShowScope(key, text)` | Shows the search bar on that `@scope`'s list. |
| `ShowPlaces(key, row)` | Opens the world map on the map tab searched for the row, its `places` pinned on the viewed map, else the nearest one's map (MINOR 3). `key` is the provider's, `row` the copy `select` got. Returns true when shown. |
| `OpenMap(mapID)` | Opens the world map on `mapID`, or turns the open map to it, the way the game's own open does (MINOR 11). Turn the map only through this: a `WorldMapFrame:SetMapID` from an addon marks the map as that addon's for the session, and the game then refuses its own actions on every later open (its reading emote on each key press, the pins' buttons in a fight, the waypoint pin's share), blamed on whoever turned it first. In a fight the game refuses the open: the call returns false and the turn happens as the fight ends, if the map is still up. |

### What EasyFind lists

An extension acts on EasyFind's rows and never adds a second row for the same thing: a pin or note EasyFind already lists marks EasyFind's row through a decorator, and only the rest become rows of yours. These say which is which (MINOR 6); both are index lookups, so thousands of asks at a load are fine.

| Function | |
| --- | --- |
| `HasRow(name, mapID)` | EasyFind's own row for a name on a map: the creature's id when the loaded creature catalog (the GPS extension's) has a creature so named with a spot on the map or the zone holding it, `true` for a recorded place or service row or a shipped instance entrance there, else `false`. Any case. |
| `HasCreature(npcID)` | Whether the loaded creature catalog has the creature. |
| `CreatureName(npcID)` | The creature's name in the client's language from the loaded catalog, or nil (MINOR 13). |

## Linked checklists

A checklist note your extension keeps in step with a list of its own, both ways (EasyFind's Auctionator extension keeps one per shopping list). The note is found by your extension id and a key; each of its lines holds your `ref` for its entry. Item lines count what the player has (bags, bank, alts) against `target`; other lines are ticked by hand.

| Function | |
| --- | --- |
| `LinkChecklists(id, handlers)` | `handlers.changed(noteID, key, lines)`: the player edited the note (`lines`: every line in order, `{ id, ref, item, link, target, text, name }`; a new line has no `ref`; `name` is an item line's name, the client's or as the player typed it while the client has none yet, MINOR 7). `handlers.shown(noteID, key)`: the note was opened in Notes, sync it. `handlers.category = { key, label, window }`: a note category of your own (listed in Notes' filter, found by search), your notes filed under it; `window` names the game window your notes belong to (`"auctionhouse"`, `"merchant"`, `"bank"`, `"mail"`, `"profession"`, `"trainer"`), and each note gets that window's tag, so it comes up there (MINOR 4). `handlers.search(noteID, key, line)`: the player asked for the line's auction search (Search AH on its menu, or Ctrl+click on the line) with the house open; search it your way and return true, else the house's own bar takes the item's name (MINOR 3). `handlers.adopt(noteID, title, lines)` (with `items`): the player made a note of theirs a shopping list; make a list of yours from its lines and return its key, and the note follows it from then on (nil: none made). `handlers.drop(noteID, key)`: the player made it a checklist again (Notes asks first); delete your list (MINOR 7). |
| `LinkedChecklist(id, key, title, make)` | Your note for `key`, or nil. With `make` it is created (titled `title`) and Notes loaded; without, Notes is never loaded for it. |
| `SyncChecklist(noteID, entries)` | Your list into the note: `entries` in order, each `{ ref, line = { item, link, target, text } }`. Lines matched by `ref` keep their ticks; new refs are added, missing ones dropped. |
| `SetChecklistRefs(noteID, refs)` | After writing the player's edits to your list: `refs[lineID]` is the `ref` that line now stands for. |
| `OpenNote(noteID)` | Opens Notes on it. |
| `RegisterPriceSource(id, def)` | Item prices for Notes' shopping lists. `def.sources`: `{ { key, label } }` (or a function giving them), the kinds of price you offer, your main one first; `def.price(key, itemID, link)`: one item's price in copper, nil for none, and an optional note for its tooltip ("Seen today"); `def.label`: the name the player picks it by, your extension's by default. A line shows the price of what is left to buy, the list its total; the player picks the source on the total or in Notes' settings, and with none picked each item takes the first extension's main price that it has (MINOR 7). |
| `RefreshPrices(id)` | Your prices changed (a scan finished): the lists show them again (MINOR 7). |
| `RegisterAuctionSearch(id, fn)` | `fn(link, name)`: the player asked to search an item at an open auction house (Ctrl+click on a list line); search it your way, as your window shows, and return true when you did. Asked before the house's own search box (MINOR 7). |

## Actions and events

Extensions talk to each other through actions (functions called by name) and events (news others listen for). The caller never needs the other addon loaded: calling an action of a load-on-demand extension loads it first.

| Function | |
| --- | --- |
| `RegisterAction(id, name, fn)` | Offers `fn` as an action of your extension. |
| `CallAction(id, name, ...)` | Runs it and returns what it returns, or nothing when there is no such action. |
| `HasAction(id, name)` | |
| `On(id, event, fn)` | Runs `fn(...)` each time that extension fires the event. |
| `Off(id, event, fn)` | |
| `Fire(id, event, ...)` | Tells every listener of your extension's event. |

```lua
-- Directions to a spot, if the GPS is installed.
API.CallAction("gps", "navigate", { name = "Booty Bay", mapID = 210, x = 0.41, y = 0.73 })

-- Hear when a route ends.
API.On("gps", "arrived", function(dest) print("Arrived at", dest.name) end)
```

What EasyFind's own extensions offer:

| Extension | Action | |
| --- | --- | --- |
| `gps` | `navigate(dest, opts)` | Directions to `dest` = `{ name, mapID, x, y }`, map coordinates 0 to 1. `dest.step` is the last step's own sentence ("Travel to the quest objective") in place of "Travel to name"; `dest.npcName` the creature there, which the Target button targets as you come near; `dest.questMark` (`"offer"` or `"turnin"`) and `dest.questID` the quest it is for; `dest.quietArrival` no arrival sound, for a route another follows on from; `dest.hold` (GPS 1.9) a trip's stop the route never moves past on its own when reached, for a guide that sends the next trip itself. `dest.direct` (GPS 1.9) a place led to in a straight line with no way planned, for a guide's step that glides or flies to its spot. `opts.popout` opens them in the GPS window, `opts.quiet` opens nothing; `opts.avoid` (GPS 1.9) ways of travel left out on top of the player's own, as the GPS's Avoid switches name them (`{ hearth = true, taxi = true }`: a guide keeping the Hearthstone and flight paths for its own steps), kept for the route's replans. Returns true when a route is planned. |
| `gps` | `navigateTrip(list, opts)` | GPS 1.9. One route through several places in order, each a `dest` as `navigate` takes, as the GPS window's own stops: its time is the whole trip's, the Target button follows the stop being walked to, and the end is the last. Places it cannot reach are left out. `opts` as `navigate` takes. Returns true when a route is planned. |
| `gps` | `canNavigate(dest)` | Whether the GPS can find a way there. |
| `gps` | `setTargets(list)` | GPS 1.9. A guide's creatures under the arrow while set, a Target button each that targets the creature and marks it: `list` = `{ { name, kind }, ... }`, `kind` `"kill"` or `"talk"` for its icon. Shown with or without a route, over the route's own NPC when that is one of them. Nil or an empty list takes them away. |
| `gps` | `setUses(list)` | GPS 1.9. A guide's things to use for its step under the arrow while set, below the Target buttons, a button each that uses the item, casts the spell or runs the macro on the player's press: `list` = `{ { kind, id, name, icon, macro }, ... }`, `kind` `"item"` (`id` its item ID), `"spell"` (`name` or `id`) or `"macro"` (`macro` its text); `name` and `icon` are what the button wears. Four at most; unchanged during a fight. Nil or an empty list takes them away. |
| `gps` | `arrowBox([on])` | GPS 1.9. The box under the arrow and the beacon (the GPS setting Arrow text): no argument returns whether it shows; `true` or `false` shows or hides it, and shown again it says what it said before. |
| `gps` | `deathSkip(on)` | GPS 1.9. While `true` (a guide's step says to die and respawn), a ghost is led to the Spirit Healer beside it (the catalog's, within 200 yards), with its Target button, not back to its corpse; set while a ghost, the one way is swapped for the other. GPS 1.9.1: `on` may be the healer's own spot `{ mapID, x, y, name }` as the guide's step gives it, taken however far and where the catalog has none. |
| `gps` | `setStatus(text)` | GPS 1.9. A line under the step in the box under the arrow and the beacon (a guide's grind progress) while set; nil or an empty string takes it away. Shown in every Arrow text mode but Off. |
| `gps` | `setCircuit(list)` | GPS 1.9. A farm circuit drawn as a closed loop on the world map and the minimap while set: `list` = `{ { mapID, x, y }, ... }`, x and y map fractions, at least three spots on one continent. Nil takes it away. |
| `gps` | `setStart(dest)` | Plans the next route from there, not from the player. |
| `gps` | `clear()` | Ends the route. |
| `gps` | `destination()` | Where the route goes, `{ name, mapID, x, y }`, or nil without one. |
| `loot` | `ensure(fn)` | Loads the loot rows and calls `fn()` once they are in (at once when they are). Returns false on a client without loot. |
| `loot` | `entries()` | A fresh list of the cached drops, one table each: `{ itemID, name, icon, slotName, links = { [difficulty] = itemLink }, bossName, encounterID, instanceName, instanceID, isRaid }`. Nil before `ensure`. |
| `loot` | `link(itemID)` | The item link EasyFind's own loot row shows for it (the chosen difficulty, then the best known), or nil when it is not a cached drop. |
| `loot` | `open(itemID)` | What a plain click on that loot row does: its boss's journal page, or directions to the instance on WoW Forever. Returns true when the item is a cached drop. |
| `loot` | event `changed` | Fired after the drops are rebuilt (a scan finished) and when the loot difficulty choice changes. |
| `notes` | `openUnitNote(entry)` | Opens the note on a player or thing: `{ type = "player", id = "Name-Realm", name = "Name" }`. |
| `notes` | `findUnitNote(entry)` | Whether there is one. |
| `notes` | `insertText(text)` | Puts text into the open note at its cursor. |
| `snippets` | `run(name)` | Fires a snippet by name, as typing its keyword would. |
| `snippets` | `create(body, name)` | Opens the snippet editor on a new snippet. |
| `snippets` | `attachExpansion(editBox)` | Snippet keywords typed into that edit box expand, as in the chat box. |
| `chat` | `compose(text, conversation)` | Starts a message in the messenger. |
| `chat` | `conversations()` | The messenger's conversations, newest first: `{ key, label }` each; a key goes to `compose`. |

| Extension | Event | |
| --- | --- | --- |
| `gps` | `routeStarted(dest)` | A route was planned. |
| `gps` | `arrived(dest)` | The player reached the end. |
| `gps` | `routeCleared()` | The route was ended. |

EasyFind's own news, under the id `easyfind`, for an extension that sits in its surfaces:

| Event | |
| --- | --- |
| `trackerChanged()` | The objective tracker was hidden or shown through EasyFind; something docked to it places itself again. |
| `mapFiltersChanged()` | The map search's filters changed; lists drawn from it search again. |
| `mapTextSizeChanged()` | The map tab's text size changed; text beside the map follows it. |

Actions not listed here are EasyFind's own and may change.

## Settings pages

`settings(page, kit)` builds your page in Options > Extensions on its first visit. The page scrolls when it grows taller than the panel. `kit` makes controls in the panel's own look:

| Function | |
| --- | --- |
| `kit.Title(page, title, hint)` | The page's title, and a line under it. Returns what to anchor the next control to. |
| `kit.Checkbox(page, label, get, set, tooltip, width)` | `get()` returns the state, `set(on)` stores it. Without `width` a full row with the switch where the dropdowns start; with one, a row that wide with the switch at its end, for two columns of switches (MINOR 3). |
| `kit.Choice(page, label, choices, get, set, tooltip, default)` | A flyout of `{ { label, value }, ... }`. |
| `kit.Stepper(page, label, min, max, step, get, set, tooltip, width)` | A number with - and + buttons. |
| `kit.ROW_WIDTH`, `kit.BUTTON_WIDTH` | Widths the panel's rows use. |

Anchor each control below the one before it:

```lua
settings = function(page, kit)
    local below = kit.Title(page, "Bookmarks", "Spots you saved, found by name.")
    local box = kit.Checkbox(page, "Show the zone",
        function() return MyDB.showZone end,
        function(on) MyDB.showZone = on end)
    box:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -8)
end,
```

| Function | |
| --- | --- |
| `OpenSettings(id)` | Opens Options > Extensions at your page. |
| `IsSettingsOpen(id)` | |
| `CloseSettings()` | |

### Your settings in the search bar

Settings that live in the game's Settings panel or in an AceConfig options table are found from the search bar as they are, under AddOn Options. Settings in a window of your own are found too once `RegisterSettingsIndex(addon, rows)` hands EasyFind their names:

```lua
EasyFind.API.RegisterSettingsIndex("Hello", function()
    return {
        { name = "Show the zone", path = "Bookmarks", keywords = { "map" },
          open = function() HelloOptions:Open("bookmarks", "showZone") end },
    }
end)
```

`rows()` is read when the search first needs it. Each row names one setting (`name`), where it sits in your window (`path`, a string or a list of names, shown under the row), more words that find it (`keywords`) and `open()`, which shows your window at it. Pass the name the game's AddOns list shows for you: one filter row then covers both. `RefreshSettingsIndex(addon)` reads the rows again after they change.

A row with a `control` is changed where it stands, as the game's own settings are: a check box, a slider with its steppers, a drop-down or a button on the row, Alt-click opening your window through `open()`.

```lua
{ name = "Show the zone", path = "Bookmarks", open = ...,
  control = { kind = "check", tooltip = "Puts the zone under each bookmark.",
              get = function() return MyDB.showZone end,
              set = function(on) MyDB.showZone = on end } },
{ name = "Icon size", path = "Bookmarks", open = ...,
  control = { kind = "slider", min = 8, max = 32, step = 2,
              get = function() return MyDB.iconSize end,
              set = function(n) MyDB.iconSize = n end } },
```

| `kind` | On the row | Fields |
| --- | --- | --- |
| `check` | A check box. | `get()` returns true or false, `set(on)`. |
| `radio` | A check box that only turns on. | `get()`, `set(true)`. |
| `slider` | A slider with minus and plus. | `get()` returns a number, `set(n)`, `min`, `max`, `step`, `format(n)` for the value text. |
| `choice` | A drop-down. | `get()` returns a value, `set(value)`, `choices`: `{ { value, label }, ... }` or a function returning that list. |
| `button` | The row presses it. | `press()`. |

`tooltip` on any control is shown under the name. `get` and `set` run on every draw and click, so route them through what your window uses.

## Beside the chat

A button or opener you place beside the game's chat goes with it when the user hides the chat through EasyFind's "Toggle Chat Frame" entry: `RegisterChatPiece(frame)` hides and shows it along with the chat frames, and hides it right away when the chat is already hidden.

## In place of the quest tracker

A quest tracker of yours that stands in for the game's goes with it when the user hides the tracker through EasyFind's "Toggle Objective Tracker" entry: `RegisterTrackerPiece(frame, show)` hides it while the tracker is hidden, again in the same frame each time you show it, and only out of combat while it holds quest item buttons. The next toggle shows it again through `show()` when you give one, so your own rules (hidden in instances, nothing tracked) still decide; else through `frame:Show()` (MINOR 9).

## Looking like EasyFind

| Function | |
| --- | --- |
| `GetThemeColor(role)` | `r, g, b, a` of the user's theme. Roles: `background`, `panel`, `border`, `line`, `text`, `textDim`, `heading`, `accent`, `selection`, `glyph`. |
| `IsLightTheme()` | A light theme wants dark text and icons. |
| `OnThemeChanged(fn)` | Runs `fn()` after the user picks another theme. |
| `StylePanel(frame)` | EasyFind's panel look for your frame: rounded border and the theme's fill, following theme and opacity changes. |
| `CreateButton(parent, text, width, height)` | A button in EasyFind's look. |
| `ShowDialog(opts)` | A confirm or input dialog: `text`, `acceptText`, `cancelText`, `hasEditBox`, `editBoxDefault`, `onAccept(value)`, `single` (one button). |

## Load on demand

An extension whose addon loads on demand registers its tile from a small part that always loads, and the rest from the load-on-demand addon:

```lua
-- Always loaded:
API.RegisterExtension({ id = "big", name = "Big", icon = "Interface\\AddOns\\MyBig\\icon", addon = "MyBig_LoD" })
API.RegisterSearchProvider({ key = "big", label = "Big", extension = "big", loadOnSearch = true })

-- In MyBig_LoD, loaded on the first click:
API.RegisterExtension({ id = "big", open = OpenBigWindow })
API.RegisterSearchProvider({ key = "big", rows = BigRows, select = OpenBigItem })
```

The tile, its launcher row, the filter row and the scope are there before the addon ever loads. A click loads it, then opens. EasyFind's Notes and Icon Search work this way.

## Rules EasyFind keeps for you

- An error in your code (`open`, `rows`, an action, a listener) reaches the game's error frame, and EasyFind carries on.
- A function you register is called with `select`'s row as a copy: change it freely.
- A misuse of the API (a missing name or icon, a wrong type) raises an error at once, naming the field.

## Editor support

[`API/EasyFind_API.lua`](EasyFind_API.lua) describes every function and field for the Lua language server (VS Code's Lua extension, and others built on it). Put it in your workspace: `EasyFind.API.` then completes with each function, and each field of the tables you pass.
