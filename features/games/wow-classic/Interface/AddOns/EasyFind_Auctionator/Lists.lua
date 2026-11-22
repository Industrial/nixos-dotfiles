-- Auctionator's shopping lists as EasyFind rows: a Create shopping list
-- row, then each list and each of its items, found by name. At the
-- auction house a click searches; away from it a list opens as a
-- checklist note in EasyFind's Notes, kept in step both ways, and an item
-- is looked up. Writes go through Auctionator's API only, on the player's
-- own pick or edit.
local ADDON, ns = ...
local API = EasyFind and EasyFind.API
if not (API and API.VERSION == 1) then return end

local L = ns.L
local KEY = ns.KEY
if not KEY then return end   -- Auctionator absent: Prices.lua set nothing up
local MAX_TOOLTIP_ITEMS = 12

local C_Item = C_Item
local IsShiftKeyDown = IsShiftKeyDown
local sformat, tconcat, mmin = string.format, table.concat, math.min

-- Auctionator's list functions and manager, bound at login.
local S = { ready = false }

local NEED = { items = "GetShoppingListItems", create = "CreateShoppingList", delete = "DeleteShoppingListItem",
               toString = "ConvertToSearchString", fromString = "ConvertFromSearchString", search = "MultiSearchAdvanced" }
local MANAGER = { "GetCount", "GetByIndex", "GetIndexForName" }

-- The API names no way to list the lists: their names come from the manager.
local function Bind()
    local v1 = Auctionator and Auctionator.API and Auctionator.API.v1
    local manager = Auctionator and Auctionator.Shopping and Auctionator.Shopping.ListManager
    if not (v1 and manager) then return false end
    for k, name in pairs(NEED) do
        if type(v1[name]) ~= "function" then return false end
        S[k] = v1[name]
    end
    for i = 1, #MANAGER do
        if type(manager[MANAGER[i]]) ~= "function" then return false end
    end
    S.manager = manager
    S.alter = type(v1.AlterShoppingListItem) == "function" and v1.AlterShoppingListItem or nil
    return true
end

function ns.ListsReady() return S.ready end

-- The player's lists in Auctionator's order; temporary search lists left out.
local function EachList(fn)
    local m = S.manager
    for i = 1, m:GetCount() do
        local list = m:GetByIndex(i)
        if not (list.IsTemporary and list:IsTemporary()) then fn(list:GetName()) end
    end
end

local function HasList(name) return S.manager:GetIndexForName(name) ~= nil end

local function Items(name) return S.items(ADDON, name) end

-- ==== terms =================================================================

local function Range(min, max)
    if min and max then return sformat(L["RANGE_FMT"], min, max) end
    if min then return sformat(L["RANGE_MIN_FMT"], min) end
    return sformat(L["RANGE_MAX_FMT"], max)
end

-- What a term asks for beyond the name, as short parts.
local function TermParts(term, out)
    if term.quantity then out[#out + 1] = sformat(L["TERM_QTY_FMT"], term.quantity) end
    if term.tier then out[#out + 1] = sformat(L["TERM_TIER_FMT"], term.tier) end
    if term.minItemLevel or term.maxItemLevel then
        out[#out + 1] = sformat(L["TERM_ILVL_FMT"], Range(term.minItemLevel, term.maxItemLevel))
    end
    if term.minLevel or term.maxLevel then out[#out + 1] = sformat(L["TERM_LEVEL_FMT"], Range(term.minLevel, term.maxLevel)) end
    if term.minCraftedLevel or term.maxCraftedLevel then
        out[#out + 1] = sformat(L["TERM_CRAFTED_FMT"], Range(term.minCraftedLevel, term.maxCraftedLevel))
    end
    if term.minPrice or term.maxPrice then
        out[#out + 1] = sformat(L["TERM_PRICE_FMT"], Range(term.minPrice and ns.Coins(term.minPrice), term.maxPrice and ns.Coins(term.maxPrice)))
    end
    local quality = term.quality and _G["ITEM_QUALITY" .. term.quality .. "_DESC"]
    if quality then
        local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[term.quality]
        out[#out + 1] = color and color.color and color.color:WrapTextInColorCode(quality) or quality
    end
    local expansion = term.expansion and _G["EXPANSION_NAME" .. term.expansion]
    if expansion then out[#out + 1] = expansion end
    return out
end

-- Item ids by name, kept when EasyFind adds an item to a list: the client
-- finds a name only once the item is in its cache.
local function KnownIDs()
    local db = ns.DB()
    db.itemIDs = db.itemIDs or {}
    return db.itemIDs
end

-- The item behind a term's name: its id, icon and link; nil for a name
-- neither the client nor an earlier add knows.
local function ItemOf(name)
    local id, _, _, _, icon = C_Item.GetItemInfoInstant(name)
    id = id or KnownIDs()[name]
    if not id then return nil end
    icon = icon or (C_Item.GetItemIconByID and C_Item.GetItemIconByID(id))
    local link = select(2, C_Item.GetItemInfo(id))
    return id, icon, link or ("item:" .. id)
end

local function ListTerms(listName)
    local items = Items(listName)
    for i = 1, #items do items[i] = S.fromString(ADDON, items[i]) end
    return items
end

-- A search at the auction house; a line when it is closed.
function ns.SearchTerms(terms)
    if not S.ready then return end
    if not ns.AtAuctionHouse() then return ns.Print(L["NEED_AH"]) end
    S.search(ADDON, terms)
end

-- ==== writes ================================================================

-- A term onto a list through Auctionator's API: the list is written back
-- whole with the term appended (the API has no append of its own).
local function AddToList(listName, raw, shownName, itemID)
    if itemID and shownName then KnownIDs()[shownName] = itemID end
    local items = HasList(listName) and Items(listName) or {}
    for i = 1, #items do
        if items[i] == raw then return ns.Print(sformat(L["ALREADY_FMT"], shownName, listName)) end
    end
    items[#items + 1] = raw
    S.create(ADDON, listName, items)
    ns.Print(sformat(L["ADDED_FMT"], shownName, listName))
end

-- Without a raw term the item's exact name is the term.
local function TermOf(name, raw)
    return raw or S.toString(ADDON, { searchString = name, isExact = true })
end

-- Asks for a list name and makes the list with the item on it.
function ns.NewListWith(name, raw, itemID)
    if not S.ready then return end
    raw = TermOf(name, raw)
    API.ShowDialog({
        text = L["DIALOG_NEW_LIST"], acceptText = L["DIALOG_CREATE"], hasEditBox = true,
        onAccept = function(value)
            value = value and strtrim(value) or ""
            if value ~= "" then AddToList(value, raw, name, itemID) end
        end,
    })
end

-- Asks for a name and makes an empty list, opened as its note.
function ns.NewList()
    if not S.ready then return end
    API.ShowDialog({
        text = L["DIALOG_NEW_LIST"], acceptText = L["DIALOG_CREATE"], hasEditBox = true,
        onAccept = function(value)
            value = value and strtrim(value) or ""
            if value == "" then return end
            if not HasList(value) then S.create(ADDON, value, {}) end
            ns.OpenList(value)
        end,
    })
end

-- The flyout: each list the term is not on, then a new one.
function ns.AddToListRows(name, exceptList, raw, itemID)
    if not S.ready then return nil end
    raw = TermOf(name, raw)
    local rows = {}
    EachList(function(listName)
        if listName ~= exceptList then
            rows[#rows + 1] = { kind = "action", label = listName, onClick = function() AddToList(listName, raw, name, itemID) end }
        end
    end)
    if #rows > 0 then rows[#rows + 1] = { kind = "separator" } end
    rows[#rows + 1] = { kind = "action", label = L["MENU_NEW_LIST"], onClick = function() ns.NewListWith(name, raw, itemID) end }
    return rows
end

-- ==== the list as a note ====================================================

-- Each list opens as a checklist note in EasyFind's Notes: the note follows
-- the list, and the player's edits there are written to it. An entry is an
-- item line counted toward its quantity when the client knows its name,
-- else a line ticked by hand; a note's quest, gold or level lines stay its own.
local LINKS = API.LinkChecklists ~= nil

local function EntryOf(raw)
    local term = S.fromString(ADDON, raw)
    local id = ItemOf(term.searchString)
    local line
    if id and term.quantity then
        line = { link = "item", item = id, target = term.quantity }
    elseif id then
        line = { item = id }
    else
        line = { text = term.searchString, target = term.quantity }
    end
    return { ref = raw, line = line }
end

local function Entries(listName)
    local out, items = {}, Items(listName)
    for i = 1, #items do out[i] = EntryOf(items[i]) end
    return out
end

-- A note line as the entry it stands for: the old entry's other asks kept
-- (tier, item level, price), its name and quantity the line's.
local function RawOf(line)
    if line.link and line.link ~= "item" then return nil end
    local name = line.text
    if (name or "") == "" and line.item then name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(line.item) end
    -- The client has no name yet: EasyFind's, as the player typed it.
    if (name or "") == "" then name = line.name end
    if (name or "") == "" then return line.ref end
    -- The list comes back by name: the name keeps its item.
    if line.item then KnownIDs()[name] = line.item end
    local term = line.ref and S.fromString(ADDON, line.ref) or { isExact = true }
    term.searchString = name
    term.quantity = line.target
    return S.toString(ADDON, term)
end

local function SetOf(list)
    local set = {}
    for i = 1, #list do set[list[i]] = true end
    return set
end

local function Same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

-- The player's edits to a list's note, written to the list: a changed
-- entry altered in place, a removed one deleted, and the list written
-- whole when an entry is new or the order moved.
function ns.PushNote(noteID, listName, lines)
    if not S.ready then return end
    local want, refs = {}, {}
    for _, line in ipairs(lines) do
        local raw = RawOf(line)
        if raw then
            want[#want + 1] = raw
            -- A line from a note saved before lines had ids: in the list, no ref.
            if line.id then refs[line.id] = raw end
        end
    end
    if HasList(listName) then
        local have = SetOf(Items(listName))
        for _, line in ipairs(lines) do
            local raw = refs[line.id]
            if S.alter and line.ref and raw and line.ref ~= raw and have[line.ref] and not have[raw] then
                S.alter(ADDON, listName, line.ref, raw)
                have[line.ref], have[raw] = nil, true
            end
        end
        local wanted = SetOf(want)
        for raw in pairs(have) do
            if not wanted[raw] then S.delete(ADDON, listName, raw) end
        end
    end
    if not (HasList(listName) and Same(Items(listName), want)) then S.create(ADDON, listName, want) end
    API.SetChecklistRefs(noteID, refs)
end

-- A note the player made a shopping list: a new list of its lines, under
-- its title or the next free name, which the note follows from then on.
local function Adopt(noteID, title, lines)
    if not S.ready then return nil end
    local name = strtrim(title or "")
    if name == "" then name = L["NOTE_CATEGORY"] end
    if S.manager.GetUnusedName then
        name = S.manager:GetUnusedName(name)
    else
        local base, n = name, 1
        while HasList(name) do n = n + 1; name = base .. " " .. n end
    end
    S.create(ADDON, name, {})
    ns.PushNote(noteID, name, lines)
    return name
end

-- The note made a checklist again (EasyFind asked first): its list goes.
-- Auctionator's own delete where it has one, else the list is emptied.
local function Drop(_, listName)
    if not (S.ready and HasList(listName)) then return end
    if S.manager.Delete then
        S.manager:Delete(listName)
        return
    end
    for _, raw in ipairs(Items(listName)) do S.delete(ADDON, listName, raw) end
end

-- A list into its note, when it has one (made when make).
local function SyncNote(listName, make)
    local id = LINKS and API.LinkedChecklist(KEY, listName, listName, make)
    if id then API.SyncChecklist(id, Entries(listName)) end
    return id
end

function ns.OpenList(listName)
    local id = S.ready and SyncNote(listName, true)
    if id then return API.OpenNote(id) end
    API.ShowScope(KEY, listName)
end

if LINKS then
    API.LinkChecklists(KEY, {
        -- Filed under their own category, each with the Auction House tag.
        category = { key = "ShoppingLists", label = L["NOTE_CATEGORY"], window = "auctionhouse" },
        -- Names typed in the note are items, with a count each.
        items = true,
        changed = ns.PushNote,
        -- A note made a shopping list becomes a list; made a checklist again, it goes.
        adopt = Adopt,
        drop = Drop,
        -- A line's auction search (Search AH on its menu, Ctrl+click on
        -- it): the list's own term, exact match and all.
        search = function(_, _, line)
            if not (S.ready and ns.AtAuctionHouse()) then return false end
            local raw = RawOf(line)
            if not raw then return false end
            ns.SearchTerms({ S.fromString(ADDON, raw) })
            return true
        end,
        shown = function(noteID, listName)
            if S.ready and HasList(listName) then API.SyncChecklist(noteID, Entries(listName)) end
        end,
    })
end

-- ==== rows ==================================================================

local function ListSubtext(n)
    if n == 0 then return L["LIST_SUBTEXT_EMPTY"] end
    if n == 1 then return L["LIST_SUBTEXT_ONE"] end
    return sformat(L["LIST_SUBTEXT_FMT"], n)
end

-- The create row first: EasyFind's green plus badge (createRow), a click
-- asks the new list's name.
local function Rows()
    if not S.ready then return {} end
    local out = { { name = L["CREATE_LIST"], isCreate = true, createRow = true,
                    searchCommandDesc = L["CREATE_LIST_SUB"], keywords = { "shopping", "list", "new" } } }
    EachList(function(listName)
        local items = Items(listName)
        out[#out + 1] = { name = listName, listName = listName, isList = true,
                          searchCommandDesc = ListSubtext(#items), keywords = { "shopping", "list" } }
        for i = 1, #items do
            local term = S.fromString(ADDON, items[i])
            local parts = TermParts(term, {})
            local id, icon = ItemOf(term.searchString)
            local desc = sformat(L["ITEM_SUBTEXT_FMT"], listName)
            if #parts > 0 then desc = desc .. ", " .. tconcat(parts, ", ") end
            out[#out + 1] = { name = term.searchString, listName = listName, raw = items[i], term = term,
                              searchCommandDesc = desc, icon = icon, itemID = id, keywords = { listName } }
        end
    end)
    return out
end

local function InsertChatLink(link)
    local active = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if active and active:IsShown() then
        active:Insert(link)
    elseif not (ChatEdit_InsertLink and ChatEdit_InsertLink(link)) and ChatFrame_OpenChat then
        ChatFrame_OpenChat(link)
    end
end

-- At the auction house a click searches the list or the term; elsewhere
-- a list shows its items in the bar and an item is looked up. Shift
-- links a known item in chat.
local function Select(row)
    if not S.ready then return end
    if row.isCreate then return ns.NewList() end
    if row.isList then
        if ns.AtAuctionHouse() then return ns.SearchTerms(ListTerms(row.listName)) end
        return ns.OpenList(row.listName)
    end
    if IsShiftKeyDown() and row.itemID then
        local _, _, link = ItemOf(row.name)
        return InsertChatLink(link)
    end
    if ns.AtAuctionHouse() then return ns.SearchTerms({ row.term }) end
    ns.OpenList(row.listName)
end

local function Hint(row)
    if not S.ready then return nil end
    if row.isCreate then return { click = L["HINT_CREATE"] } end
    local at = ns.AtAuctionHouse()
    if row.isList then return { click = at and L["HINT_SEARCH"] or L["HINT_SHOW_LIST"] } end
    return { click = at and L["HINT_SEARCH"] or L["HINT_SHOW_LIST"], shift = row.itemID and L["HINT_LINK"] or nil }
end

-- A list: its items with their last prices. An item: the item's own
-- tooltip, then its list and what the term asks for.
local function Tooltip(row, tt)
    if not S.ready or row.isCreate then return false end
    if row.isList then
        tt:SetText(row.name, 1, 1, 1)
        local items = Items(row.listName)
        for i = 1, mmin(#items, MAX_TOOLTIP_ITEMS) do
            local term = S.fromString(ADDON, items[i])
            local id, _, link = ItemOf(term.searchString)
            local price = id and ns.AuctionPrice(link, id)
            tt:AddDoubleLine(term.searchString, price and ns.Coins(price) or "", 1, 1, 1, 1, 1, 1)
        end
        if #items > MAX_TOOLTIP_ITEMS then tt:AddLine(sformat(L["TT_MORE_FMT"], #items - MAX_TOOLTIP_ITEMS), 0.7, 0.7, 0.7) end
        return true
    end
    local id = ItemOf(row.name)
    if id then tt:SetItemByID(id) else tt:SetText(row.name, 1, 1, 1) end
    tt:AddLine(" ")
    tt:AddLine(sformat(L["TT_ON_LIST_FMT"], row.listName), 1, 0.82, 0)
    local parts = TermParts(row.term, {})
    if #parts > 0 then tt:AddLine(tconcat(parts, ", "), 1, 1, 1) end
    return true
end

local function Menu(row)
    if not S.ready or row.isCreate then return nil end
    local rows = {}
    if ns.AtAuctionHouse() then
        rows[#rows + 1] = { kind = "action", label = L["MENU_SEARCH"], onClick = function()
            if row.isList then ns.SearchTerms(ListTerms(row.listName)) else ns.SearchTerms({ row.term }) end
        end }
    end
    if row.isList then
        rows[#rows + 1] = { kind = "action", label = L["MENU_OPEN_LIST"], onClick = function() ns.OpenList(row.listName) end }
        return rows
    end
    rows[#rows + 1] = { kind = "action", label = L["MENU_FIND"], onClick = function() API.OpenSearch(row.name) end }
    if not API.RegisterAddTarget then
        rows[#rows + 1] = { kind = "menu", label = L["MENU_ADD"], rows = function() return ns.AddToListRows(row.name, row.listName, row.raw) end }
    end
    rows[#rows + 1] = { kind = "action", label = sformat(L["MENU_REMOVE_FMT"], row.listName), onClick = function()
        S.delete(ADDON, row.listName, row.raw)
        ns.Print(sformat(L["REMOVED_FMT"], row.name, row.listName))
    end }
    return rows
end

-- ==== registration ==========================================================

API.RegisterSearchProvider({
    key = KEY,
    label = L["PROVIDER_LABEL"],
    category = L["CATEGORY"],
    extension = KEY,
    eager = true,
    words = { "shopping", "list", "lists" },
    aliases = { "shopping", "shoppinglist", "shoppinglists" },
    rows = Rows,
    select = Select,
    tooltip = Tooltip,
    hint = Hint,
    menu = Menu,
    -- Nothing typed: the create row and the lists; a list's name finds its items.
    browse = function(row) return row.isList == true or row.isCreate == true end,
})

-- An item row's name as the client shows it; a list item's own term name.
local function RowName(row)
    if row.raw and row.listName then return row.name end
    return C_Item.GetItemNameByID and C_Item.GetItemNameByID(row.itemID) or row.name
end

-- Shopping lists sit in the result menu's Add flyout, beside EasyFind's
-- own, for an item row and for an item on a list (the other lists).
if API.RegisterAddTarget then
    API.RegisterAddTarget({
        key = KEY, extension = KEY, label = L["ADD_TARGET"], fullLabel = L["MENU_ADD"],
        applies = function(row)
            return S.ready and (row.itemID ~= nil or (row.raw ~= nil and row.listName ~= nil and not row.isList))
        end,
        rows = function(row)
            if row.raw and row.listName then return ns.AddToListRows(row.name, row.listName, row.raw) end
            return ns.AddToListRows(RowName(row), nil, nil, row.itemID)
        end,
        -- The entry's own click: a new list (the lists open on hover).
        onClick = function(row) ns.NewListWith(RowName(row), row.listName and row.raw or nil, row.itemID) end,
        -- An empty one, from Notes' + menu.
        new = ns.NewList, newLabel = L["MENU_NEW_SHOPPING_LIST"],
    })
end

local pending = false
function ns.RefreshLists()
    if pending or not S.ready then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        API.RefreshSearchProvider(KEY)
        EachList(function(listName) SyncNote(listName, false) end)
    end)
end

-- Auctionator's own list events, when its bus and their names are there.
local listener = { ReceiveEvent = function() ns.RefreshLists() end }
local function WatchLists()
    local bus = Auctionator.EventBus
    local events = Auctionator.Shopping and Auctionator.Shopping.Events
    if not (bus and type(bus.Register) == "function" and type(events) == "table") then return end
    local names = {}
    for _, k in ipairs({ "ListMetaChange", "ListItemChange", "ListImportFinished" }) do
        if events[k] then names[#names + 1] = events[k] end
    end
    if #names > 0 then bus:Register(listener, names) end
end

function ns.StartLists()
    if not Bind() then return ns.Print(L["NOT_READY_LISTS"]) end
    S.ready = true
    WatchLists()
    API.RefreshSearchProvider(KEY)
end

-- EasyFind 5.0.0 made Notes an addon of its own: with no Notes Extension
-- the lists' Notes side is gone, so each version of this one says so
-- once, with the extension's page (EasyFind opens the link).
local NOTES_PROJECT = "1782460"
local NOTES_PAGE = "|cff70d6ff|Heasyfind:page:easyfind-notes-extension|h[EasyFind: Notes Extension]|h|r"

function ns.TellNotesMissing()
    local GetMeta = C_AddOns and C_AddOns.GetAddOnMetadata
    local Exists = C_AddOns and C_AddOns.DoesAddOnExist
    if not (GetMeta and Exists) or InCombatLockdown() then return end
    local core = tonumber((GetMeta("EasyFind", "Version") or ""):match("^(%d+)"))
    if not core or core < 5 then return end
    -- An older EasyFind's own copy of Notes is no extension: no project ID.
    if Exists("EasyFind_Notes") and GetMeta("EasyFind_Notes", "X-Curse-Project-ID") == NOTES_PROJECT then return end
    local version = GetMeta(ADDON, "Version")
    local db = ns.DB()
    if db.notesToldFor == version then return end
    db.notesToldFor = version
    ns.Print(L["NEED_NOTES_FMT"]:format(NOTES_PAGE))
end
