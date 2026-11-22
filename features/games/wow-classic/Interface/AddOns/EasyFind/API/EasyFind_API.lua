---@meta
-- EasyFind.API for the Lua language server: put this file in your
-- workspace and EasyFind.API completes with its functions and fields.
-- Not loaded by the game. The guide: API/README.md.

---@class EasyFindExtension
---@field id string Required. Letters, digits, - and _; keep it stable.
---@field name? string Required the first time: the tile's name.
---@field description? string One line under the name in tooltips.
---@field icon? string|number Required the first time: white line art, painted in the theme's icon color.
---@field iconCoords? number[] { left, right, top, bottom }
---@field open? fun() Opens the extension.
---@field close? fun() Closes it.
---@field isOpen? fun(): boolean
---@field menu? fun(): EasyFindMenuRow[] Rows for the tile's right-click menu.
---@field settings? fun(page: Frame, kit: EasyFindSettingsKit) Builds its settings page.
---@field keywords? string[] Words that find its launcher row.
---@field hideFromSearch? boolean No launcher row in the search bar.
---@field scope? string Its surface is that @scope's list in the search bar.
---@field experimental? string A line of warning in its tooltip.
---@field addon? string A load-on-demand addon holding the rest.
---@field loadInCombat? boolean Its addon may load, and it may open, in combat.
---@field loadAtLogin? boolean Its addon loads at login, not on first open.

---@class EasyFindMenuRow
---@field kind "action"|"check"|"separator"|"menu"
---@field label? string
---@field tooltip? string
---@field onClick? fun() An action row's command.
---@field closes? boolean The action opens another window: on a result's menu the search bar steps aside after it (MINOR 5).
---@field disabled? boolean The action grayed out, its tooltip saying why.
---@field get? fun(): boolean A check row's state.
---@field set? fun(on: boolean) Stores a check row's state.
---@field rows? EasyFindMenuRow[]|fun(): EasyFindMenuRow[] A menu row's flyout.

---@class EasyFindSearchProvider
---@field key string Required: its filter key and @scope key.
---@field label? string Required the first time: what its rows are, on its scope pill and its switch in its extension's filter row.
---@field category? string The name its rows carry; key when not given.
---@field icon? string|number The glyph left of each of its rows; its extension's when not given.
---@field iconCoords? number[]
---@field iconWell? boolean Its rows' icons on a map pin sit in a dark round well, for small glyphs on a clear ground (MINOR 2).
---@field rows? fun(): EasyFindRow[] Its rows.
---@field select? fun(row: EasyFindRow) A click or Enter on a row (a copy).
---@field tooltip? fun(row: EasyFindRow, tooltip: GameTooltip): boolean Fill it; true shows it.
---@field leave? fun(row: EasyFindRow) The cursor left a row.
---@field words? string[] Typing one loads its rows.
---@field eager? boolean Searched from the first keystroke (small lists).
---@field lazy? boolean Only through its words, filter or scope.
---@field lowResults? boolean Also loaded when a search finds little.
---@field aliases? string[] An @scope: @ and one of these lists only its rows.
---@field browse? fun(row: EasyFindRow): boolean Whether the row is in the scope's list while nothing is typed; every row without it.
---@field place? fun(row: EasyFindRow): { name: string, mapID: number, x: number, y: number, step: string? }|nil Where the row is now: its rows are found from the map search and the GPS too.
---@field places? fun(row: EasyFindRow): { name: string, mapID: number, x: number, y: number, step: string?, icon: string|number? }[] Every spot the row stands for (MINOR 3): one map row, its spots pinned together on the viewed map, ranked by the nearest; place stays the GPS's one spot.
---@field link? EasyFindLink A row's EasyFind link carries your key; the receiver's copy resolves it.
---@field menu? fun(row: EasyFindRow): EasyFindMenuRow[]|nil Rows for the result's right-click menu, under your extension's name.

---@class EasyFindAddTarget
---@field key string Required; registering it again replaces it.
---@field extension string Required, registered first: its icon marks the entry.
---@field label string Required: its name in the Add flyout.
---@field fullLabel? string Its name as the menu's only Add entry; label when not given.
---@field applies? fun(row: EasyFindRow): boolean The rows it takes; every row without it.
---@field rows fun(row: EasyFindRow): EasyFindMenuRow[]|nil Required: the flyout's rows.
---@field onClick? fun(row: EasyFindRow) A click on the entry itself; its flyout opens on hover.
---@field new? fun() Makes a new, empty one: Notes' + menu lists it, with newLabel.
---@field newLabel? string Its New entry's name ("New shopping list"); needed with new.

---@class EasyFindLink
---@field key fun(row: EasyFindRow): string|nil A short string the link carries (an id, the sender's progress).
---@field resolve fun(tail: string): EasyFindRow|nil The row the receiver shows for it.
---@field options? EasyFindOption[] Toggles on its filter row's flyout.
---@field extension? string Required the first time: the extension it belongs to, registered first. Its filter row is the extension's one row.
---@field loadOnSearch? boolean|fun(): boolean Load that extension's addon for its rows.
---@field hint? string|EasyFindHint|fun(row: EasyFindRow): string|EasyFindHint What a row's gestures do, under its name on hover.

---@class EasyFindHint
---@field click? string The click's target ("Directions").
---@field alt? string
---@field ctrl? string
---@field shift? string

---@class EasyFindRow
---@field name string What is searched and shown.
---@field icon? string|number Shown at the row's right, in its own colors.
---@field keywords? string[] More words that find it.
---@field searchCommandDesc? string Its subtext.
---@field hint? string|EasyFindHint|fun(row: EasyFindRow): string|EasyFindHint This row's own hint.
---@field mapID? number The map it is on, for the map search's list of that map; it answers to that place's words too (MINOR 7).
---@field createRow? boolean The row makes a new thing: it wears the green plus badge (MINOR 4).
---@field scopedName? boolean Its name is searched only under the provider's @scope; elsewhere only its keywords find it (MINOR 7).

---@class EasyFindRowDecorator
---@field id string The extension of that id lends its icon.
---@field extension? string Another extension's id, when id is not one.
---@field slot? string Where text paints; one shows per slot ("price").
---@field label? string Your entries' name when they fold under one row.
---@field applies? fun(row: EasyFindRow): boolean The rows you take; without it, rows with an itemID.
---@field categories? string[] With no applies: the item rows' category names you take.
---@field text? fun(row: EasyFindRow, link: string|nil): string|number|nil, string|nil A string or copper, and "good", "dim" or "warn".
---@field tooltip? fun(row: EasyFindRow, link: string|nil, tooltip: table) Lines under the row's tooltip.
---@field modifiers? boolean Your tooltip reads the held keys: the row's tooltip is drawn again as Ctrl, Shift or Alt goes down or up (MINOR 8).
---@field menu? fun(row: EasyFindRow, link: string|nil): table Rows for the row's menu, in the tile menu's shape.
---@field submenu? boolean Your menu rows under one row named label.
---@field subtext? fun(row: EasyFindRow): string|nil A part after the row's subtext.
---@field select? fun(row: EasyFindRow, link: string|nil, gesture: string): boolean A boss or loot row's gesture ("click", "alt", "ctrl") where the client has no Adventure Guide; true when you handled it (MINOR 5).
---@field hint? fun(row: EasyFindRow): string|EasyFindHint|nil The gestures' words while select takes the row: the click's, or { click, alt, ctrl } (MINOR 5).
---@field aliases? string[] An @scope over the rows you take: @ and one of these searches or lists them; its key is id (MINOR 6), shared with your own provider of that key (MINOR 7).
---@field browse? fun(row: EasyFindRow): boolean Whether the row is in the scope's list while nothing is typed; every taken row without it (MINOR 6).
---@field candidates? fun(): table<string, table<any, true>> The rows you take by field, { itemID = { [13335] = true } }, before applies is asked (MINOR 6); name = { [lowercase name] = { [mapID] = true } } (MINOR 7).
---@field words? fun(): { npc: table<integer, string[]>?, name: table<string, string[]>? } Words the rows you take are found by: by creature id, or "name@mapID" matched in its zone (MINOR 7).
---@field keep? fun(row: EasyFindRow): boolean Held for the filter flyout.
---@field sortKey? fun(row: EasyFindRow): string|number Held for the filter flyout.

---@class EasyFindOption
---@field label? string|fun(): string
---@field tooltip? string|fun(): string
---@field get? fun(): boolean
---@field set? fun(on: boolean)
---@field header? string A caption over the rows that follow.
---@field separator? boolean A line between groups.

---@class EasyFindSettingsKit
---@field Font fun(name: string): string The settings window's own font for a game font's name (2 pt larger); use it for any text a page makes itself.
---@field ROW_WIDTH number
---@field BUTTON_WIDTH number
local kit = {}
---@return Region below Anchor the next control to it.
function kit.Title(page, title, hint) end
---@param get fun(): boolean
---@param set fun(on: boolean)
---@param width? number The row's width; the switch then sits at its end, for two columns of switches (MINOR 3). Without it, a full row with the switch where the dropdowns start.
---@return CheckButton
function kit.Checkbox(page, label, get, set, tooltip, width) end
---@param choices { label: string, value: any, disabled?: fun(): boolean }[] disabled: grayed, no click.
---@param get fun(): any
---@param set fun(value: any)
---@return Frame
function kit.Choice(page, label, choices, get, set, tooltip, default) end
---@param get fun(): number
---@param set fun(value: number)
---@return Frame
function kit.Stepper(page, label, min, max, step, get, set, tooltip, width) end

---A button in the settings window's own text, as its other buttons.
---@return Button
function kit.Button(page, text, width, height) end

---@class EasyFindSettingsRow
---@field name string The setting's label.
---@field path? string|string[] Where it sits in your window.
---@field keywords? string[] More words that find it.
---@field open fun() Shows your window at it.
---@field control? EasyFindSettingsControl Changed on the row itself.

---@class EasyFindSettingsControl
---@field kind "check"|"radio"|"slider"|"choice"|"button"
---@field get? fun(): any check and radio: boolean; slider: number; choice: a choice's value.
---@field set? fun(value: any)
---@field min? number slider
---@field max? number slider
---@field step? number slider
---@field format? fun(n: number): string slider: the value text.
---@field choices? { value: any, label: string }[]|fun(): { value: any, label: string }[] choice
---@field press? fun() button
---@field tooltip? string Under the name.

---@class EasyFindDialog
---@field text string
---@field acceptText? string
---@field cancelText? string
---@field hasEditBox? boolean
---@field editBoxDefault? string
---@field onAccept? fun(value: string?)
---@field single? boolean One button only.

---@alias EasyFindThemeRole "background"|"panel"|"border"|"line"|"text"|"textDim"|"heading"|"accent"|"selection"|"glyph"

EasyFind = {}

---@class EasyFindAPI
EasyFind.API = {
    ---Rises only for a change that breaks an extension.
    VERSION = 1,
    ---Rises when something is added.
    MINOR = 10,
}
local API = EasyFind.API

-- ==== extensions ==============================================================

---Adds the extension, or adds to one registered with the same id.
---@param def EasyFindExtension
---@return boolean
function API.RegisterExtension(def) end
---@return boolean
function API.IsExtensionRegistered(id) end
---Opens it as a click on its tile would.
---@return boolean
function API.OpenExtension(id) end
function API.CloseExtension(id) end
---@return boolean
function API.ToggleExtension(id) end
---@return boolean
function API.IsExtensionOpen(id) end
---Loads its addon if it loads on demand; true when it is in.
---@return boolean
function API.LoadExtension(id) end
---A count on its icon; 0 or nil clears it.
---@param count integer?
function API.SetBadge(id, count) end
---Your window showed or hid: its micro menu button follows.
function API.NotifyOpenChanged(id) end

-- ==== search ==================================================================

---Adds search results, or adds to a provider registered with the same key.
---@param def EasyFindSearchProvider
---@return boolean
function API.RegisterSearchProvider(def) end
---An entry in a result's right-click Add flyout, wearing its extension's icon.
---@param def EasyFindAddTarget
---@return boolean
function API.RegisterAddTarget(def) end
---Your mark on rows another provider owns (MINOR 4): text at an item row's right, lines under its tooltip, entries on its menu wearing your icon, a part after its subtext.
---@param def EasyFindRowDecorator
---@return boolean
function API.RegisterRowDecorator(def) end
---Takes a decorator back; the next registered for its slot shows.
function API.UnregisterRowDecorator(id, slot) end
---Shown rows paint their decorations again (new prices after a scan).
function API.RefreshRowDecorations() end
---The hovered row's tooltip drawn again: your lines changed while it shows, a spell's text arrived (MINOR 8).
function API.RedrawRowTooltip() end
---Its rows changed: rebuilt now, and an open search shows them.
function API.RefreshSearchProvider(key) end
---Your verdict on @upgrades for the character played now (MINOR 10): rate(itemID, link) answers the percent the drop beats the worn piece by, true for an upgrade with no number, false for no upgrade, nil for not rated (EasyFind's own comparison stands). One judge at a time; the last registered judges.
---@param def { extension: string, rate: fun(itemID: integer, link: string): number|boolean|nil }
---@return boolean
function API.RegisterUpgradeJudge(def) end
---Takes the extension's judge back (MINOR 10).
function API.UnregisterUpgradeJudge(extension) end
---Where an item comes from, as your extension knows it (MINOR 11): fn(itemID, name) returns rows (quests that reward it, who sells it), listed under your extension's name on the item's sources page, which a click on an item row opens. MINOR 13: or { sections = { { label, rows, key }, ... } }; a row { creature = id }, { item = id } or { spots = { mapID, x, y, ... }, name } is drawn as EasyFind's own, its note the subtext; key "sold" or "dropped" joins EasyFind's own section.
---@param id string Your extension's id.
---@param fn fun(itemID: integer, name: string): EasyFindRow[]|table|nil
---@return boolean
function API.RegisterItemSources(id, fn) end
---Your verdicts changed (a drop rated, the gear changed): @upgrades is built again when shown (MINOR 10).
function API.RefreshUpgrades() end
---A provider row's spots on the map tab: the map searched for the row, its spots pinned on the viewed map, else the nearest one's map opened (MINOR 3). key: the provider's; row: the copy select got. True when shown.
---@return boolean
function API.ShowPlaces(key, row) end
---Opens the world map on a map, or turns the open map to it, the way the game's own open does (MINOR 11). Turn the map only through this: an addon's SetMapID marks the map as the addon's for the session, and the game refuses its own actions on every later open. In a fight the game refuses the open: false, and the turn happens as the fight ends if the map is still up.
---@param mapID number
---@return boolean
function API.OpenMap(mapID) end
---Inside a provider's rows: lets the frame go when this frame's share is spent, and goes on next frame (MINOR 12). Call it once per item of a long loop; anywhere else it does nothing.
function API.SliceCheckpoint() end
---Shows the search bar focused, with text searched when given.
---@param text string?
---@return boolean
function API.OpenSearch(text) end
---Shows the search bar on that @scope's list.
---@param text string?
---@return boolean
function API.ShowScope(key, text) end
---EasyFind's own row for a name on a map (MINOR 6): the creature's id when the loaded catalog has one so named with a spot on the map or its zone, true for a place or service row there, else false. Any case.
---@return integer|boolean
function API.HasRow(name, mapID) end
---Whether the loaded creature catalog has the creature (MINOR 6).
---@return boolean
function API.HasCreature(npcID) end
---A creature's name in the client's language from the loaded catalog, or nil (MINOR 13).
---@return string|nil
function API.CreatureName(npcID) end

-- ==== actions and events ======================================================

---@param fn fun(...): any
function API.RegisterAction(id, name, fn) end
---Runs another extension's action (loading it first if needed) and
---returns what it returns; nothing when there is no such action.
---@return any ...
function API.CallAction(id, name, ...) end
---@return boolean
function API.HasAction(id, name) end
---@param fn fun(...)
function API.On(id, event, fn) end
function API.Off(id, event, fn) end
function API.Fire(id, event, ...) end

-- ==== linked checklists ========================================================

---@class EasyFindChecklistEntry
---@field ref string        the extension's own key for the entry
---@field line { item: integer?, link: string?, target: number?, text: string? }

---@class EasyFindChecklistLinks
---@field changed fun(noteID: integer, key: string, lines: table[])? the player's edits, every line in order: { id, ref, item, link, target, text, name }, name an item line's (the client's, or as typed while the client has none; MINOR 7)
---@field shown fun(noteID: integer, key: string)? the note opened in Notes: sync it now
---@field category { key: string, label: string }? a note category of your own, your notes filed under it
---@field items boolean? names typed in your notes are items, each with a count, and the editor suggests them
---@field search fun(noteID: integer, key: string, line: table): boolean? the player asked for the line's auction search (Search AH on its menu, Ctrl+click on it): search it your way and return true; else the house's own bar takes the item's name (MINOR 3)
---@field adopt fun(noteID: integer, title: string, lines: table[]): string? the player made a note of theirs a shopping list (with items): make a list of yours from its lines and return its key, the note following it from then on; nil for none (MINOR 7)
---@field drop fun(noteID: integer, key: string)? the player made that shopping list a checklist again, asked first: delete your list (MINOR 7)

---Hears a linked checklist's edits and openings for this extension.
---@param handlers EasyFindChecklistLinks
function API.LinkChecklists(id, handlers) end
---The extension's checklist note for key; made (titled) when make.
---@return integer? noteID
function API.LinkedChecklist(id, key, title, make) end
---The extension's list into the note, by ref: lines added, updated, dropped.
---@param entries EasyFindChecklistEntry[]
---@return boolean
function API.SyncChecklist(noteID, entries) end
---@param refs table<integer, string> lineID -> ref
function API.SetChecklistRefs(noteID, refs) end
function API.OpenNote(noteID) end

-- ==== prices and auction searches ==============================================

---@class EasyFindPriceSource
---@field sources { key: string, label: string }[]|fun(): { key: string, label: string }[] the kinds of price you offer, your main one first (used when the player picked none)
---@field price fun(key: string, itemID: integer, link: string?): integer?, string? one item's price in copper (nil for none) and a note for its tooltip ("Seen today")
---@field label string? the name the player picks it by; your extension's name by default

---Prices for Notes' shopping lists: a line's price is what is left to buy, the total their sum (MINOR 7).
---@param def EasyFindPriceSource
function API.RegisterPriceSource(id, def) end
---Your prices changed (a scan finished): the lists show them again (MINOR 7).
function API.RefreshPrices(id) end
---fn(link, name): the player asked to search an item at an open auction house; search it your way and return true when you did. Asked before the house's own search box (MINOR 7).
---@param fn fun(link: string?, name: string): boolean?
function API.RegisterAuctionSearch(id, fn) end

-- ==== settings ================================================================

---@return boolean
function API.OpenSettings(id) end
---@return boolean
function API.IsSettingsOpen(id) end
function API.CloseSettings() end
---Settings of your own window, found from the search bar.
---@param addon string Your name as the game's AddOns list shows it.
---@param rows fun(): EasyFindSettingsRow[]
---@return boolean
function API.RegisterSettingsIndex(addon, rows) end
---Its rows changed: read again.
function API.RefreshSettingsIndex(addon) end

-- ==== chat ====================================================================

-- A frame of yours that belongs beside the game's chat (an opener, a
-- button): hidden and shown with the chat frames by "Toggle Chat Frame".
---@param frame Frame
function API.RegisterChatPiece(frame) end

-- ==== quest tracker ===========================================================

-- A quest tracker of yours that stands in for the game's: hidden and shown
-- with it by "Toggle Objective Tracker" (MINOR 9). show, when given, brings
-- it back your way instead of frame:Show().
---@param frame Frame
---@param show? fun()
function API.RegisterTrackerPiece(frame, show) end

-- ==== theme and look ==========================================================

---@param role EasyFindThemeRole
---@return number r, number g, number b, number a
function API.GetThemeColor(role) end
---@return boolean
function API.IsLightTheme() end
---@param fn fun()
function API.OnThemeChanged(fn) end
---@generic F : Frame
---@param frame F
---@return F
function API.StylePanel(frame) end
---@return Button
function API.CreateButton(parent, text, width, height) end
---@param opts EasyFindDialog
function API.ShowDialog(opts) end
