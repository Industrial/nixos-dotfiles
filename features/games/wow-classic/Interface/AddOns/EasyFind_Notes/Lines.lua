local _, notesNS = ...
local ns = EasyFind and EasyFind._ns
if not (ns and notesNS.Checklist and notesNS.UI and notesNS.Windows) then return end

-- A note's checkbox lines in its editor: the box ticks on the list (by
-- hand, or as the game answers), a ticked line reads struck and green, a
-- counted or tracked line wears its count at the right with an X to drop
-- it, and the note's menu holds what the line kinds and the ticks need.
local Lines = {}
notesNS.Lines = Lines

local CK = notesNS.Checklist
local NotesUI = notesNS.UI
local W = notesNS.Windows
local Utils = ns.Utils
local L = ns.L
-- Frames made here belong to the notes window in use (their scripts run as it).
local CreateFrame, time = W.CreateFrame, time
local sformat, mmax, mmin, mfloor, tonumber, tostring = string.format, math.max, math.min, math.floor, tonumber, tostring
local ipairs, smatch, slower, strtrim = ipairs, string.match, string.lower, strtrim
local IsControlKeyDown = IsControlKeyDown

local BOX_GLYPH, TICKED_GLYPH = CK.EMPTY:sub(1, 3), CK.FILLED:sub(1, 3)
local CELL_W, NAME_W, ROW_H = 56, 150, 22
local READY_TEX = "Interface\\RaidFrame\\ReadyCheck-Ready"
local MENU_CHECK_TEX = "Interface\\Buttons\\UI-CheckBox-Check"
local DONE_DARK, DONE_LIGHT = { 0.45, 0.85, 0.45 }, { 0.12, 0.50, 0.18 }

-- Frames and marks in one table, a set per notes window; reads go to the
-- set of the window in use.
Lines.States = setmetatable({}, { __mode = "k" })
local function S()
    local w = W.active
    local s = Lines.States[w]
    if not s then
        s = { tails = {}, cells = {}, heads = {}, rows = {} }
        Lines.States[w] = s
    end
    return s
end

local function Note() return notesNS.SelectedNote and notesNS.SelectedNote() end
local function Frame() return NotesUI._notes and NotesUI._notes.frame end
local function Theme() return ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme() end
local function DoneColor()
    local theme = Theme()
    return (theme and theme.lightTheme) and DONE_LIGHT or DONE_DARK
end
local function OpenColor()
    local theme = Theme()
    if theme and theme.lightTheme and theme.leafColor then return theme.leafColor end
    return { 1, 1, 1 }
end

-- Every window on the note draws it again from its body.
function Lines.Reload(note)
    local w = W.ShowingNote(note.id)
    if w then W.Run(w, function() NotesUI:RefreshEasyNotes() end) end
    notesNS.Refresh()
end

local function Repaint(note)
    local w = W.ShowingNote(note.id)
    if w then W.Run(w, function() NotesUI:QueueEasyNotesOverlayUpdate() end) end
end

-- The player changed the note's lines: a linked one's extension hears of
-- it a beat after the last change, with the lines as they then stand.
local told, edited = {}, {}
local HOLD = 1
local function Told(note)
    if not (note.list and note.list.source) then return end
    local token = (told[note.id] or 0) + 1
    told[note.id] = token
    Utils.SafeAfter(0.5, function()
        if told[note.id] ~= token then return end
        told[note.id] = nil
        if notesNS.LinkedChanged then notesNS.LinkedChanged(note) end
    end)
end

-- Typed in a moment ago, or its change still to go out: a linked list's
-- copy waits (an older copy came back mid-typing and took the caret to
-- the top, Era 2026-11-02, /efd notecaret).
function Lines.Holding(note)
    return told[note.id] ~= nil or (edited[note.id] ~= nil and GetTime() - edited[note.id] < HOLD)
end

-- The body changed under the lines: they follow at once; the words settle
-- (a name looked up as an item) a beat after the typing stops.
local settling = {}
function Lines.BodyChanged(note)
    if not note then return end
    edited[note.id] = GetTime()
    local changed = CK.Reconcile(note)
    if changed then Told(note) end
    if CK.ItemsList(note) and not settling[note.id] then
        settling[note.id] = true
        Utils.SafeAfter(0.7, function()
            settling[note.id] = nil
            if CK.Reconcile(note, true) then
                Told(note)
                Repaint(note)
            end
        end)
    end
end

-- A note coming up in a window: its lines in step, its ticks cleared as
-- its schedule says, a linked list pulled from its extension once.
function Lines.NoteLoaded(note)
    if not note then return end
    CK.Migrate(note, ns.CurrentCharacterKey())
    CK.Reconcile(note, true)
    if not CK.Is(note) then return end
    if CK.ApplyReset(note, time()) then note.updated = time() end
    local s = S()
    if note.list.source and s.pulled ~= note.id and notesNS.LinkedShown then
        s.pulled = note.id
        Utils.SafeAfter(0, function() notesNS.LinkedShown(note) end)
    end
end

-- Ticks

local function Editing(editor)
    local frame = Frame()
    return frame ~= nil and editor == frame.editor
end

-- Whether the box starting at startByte in editor's text is ticked, and its line.
function Lines.TickedAt(editor, startByte)
    if not Editing(editor) then return nil end
    local note = Note()
    local line = note and CK.LineAt(note, startByte)
    if not line then return nil end
    return (CK.LineState(note, line)) and true or false, line
end

-- A press on a box: a hand line's tick flips for whoever keeps them; a
-- line the game ticks stays as the game says.
function Lines.ToggleAt(note, startByte)
    local line = CK.LineAt(note, startByte)
    if not line then
        CK.Reconcile(note)
        line = CK.LineAt(note, startByte)
    end
    if not line or line.link then return false end
    local char = ns.CurrentCharacterKey()
    CK.SetTicked(note, line, char, not CK.Ticked(note, line, char))
    Repaint(note)
    notesNS.Refresh()
    return true
end

-- The decorations with a ticked line's strike and green over its words.
function Lines.WithTicks(editor, text, decos)
    if not Editing(editor) then return decos end
    local note = Note()
    if not (note and CK.Is(note)) then return decos end
    local out = {}
    for i = 1, #decos do out[i] = decos[i] end
    local c = DoneColor()
    for _, f in ipairs(CK.BodyLines(text)) do
        local line = CK.LineAt(note, f.start)
        if line and f.lineEnd >= f.contentStart and CK.LineState(note, line) then
            out[#out + 1] = { kind = "strike", startByte = f.contentStart, endByte = f.lineEnd + 1 }
            out[#out + 1] = { kind = "color", startByte = f.contentStart, endByte = f.lineEnd + 1, r = c[1], g = c[2], b = c[3] }
        end
    end
    return out
end

-- Tails: the count at a line's right, and its X

local function Layer(editor)
    local s = S()
    if s.layer and s.layerOf == editor then return s.layer end
    local scroll = editor:GetParent()
    local layer = CreateFrame("Frame", nil, scroll:GetParent())
    layer:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    layer:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 0, 0)
    layer:SetClipsChildren(true)
    layer:SetFrameLevel(editor:GetFrameLevel() + 5)
    layer:EnableMouse(false)
    layer:SetShown(scroll:IsShown())
    scroll:HookScript("OnShow", function() layer:Show() end)
    scroll:HookScript("OnHide", function() layer:Hide() end)
    s.layer, s.layerOf = layer, editor
    return layer
end

local function AuctionOpen()
    return notesNS.Context.WindowOpen("auctionhouse")
end

-- Shown and not shrunk away: TSM keeps retail's house shown at scale 0.001.
local function InSight(frame)
    return frame ~= nil and frame:IsShown() and frame:GetScale() > 0.01
end

-- The line searched at the auction house: by the extension its list is
-- linked to when that searches (the list's own term), else the item's
-- name in the house's own bar (retail's, or the classic browse box), else
-- its link where linked items go.
local function SearchAH(note, line)
    if notesNS.LinkedSearch and notesNS.LinkedSearch(note, line) then
        S().lastSearched = line.id
        return
    end
    local name = line.item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(line.item)
    -- A name typed in a checklist stays words: they are the search.
    if not name and line.text and not line.link then name = (CK.SplitCount(line.text)) end
    -- An item the client has no name for yet goes by the words typed for it.
    if not name and line.item then name = CK.LineWords(note, line) end
    if not name or name == "" then return end
    -- An extension's own search, where its window is the one up (TSM's
    -- auction window hides the house's own box; API.RegisterAuctionSearch).
    local link = line.item and C_Item.GetItemInfo and select(2, C_Item.GetItemInfo(line.item))
    for _, fn in pairs(ns.AuctionSearches or {}) do
        local ok, took = xpcall(fn, geterrorhandler(), link, name)
        if ok and took == true then
            S().lastSearched = line.id
            return
        end
    end
    local ah, classic = _G["AuctionHouseFrame"], _G["AuctionFrame"]
    local bar = InSight(ah) and ah.SearchBar
    if bar and bar.SetSearchText and bar.StartSearch then
        bar:SetSearchText(name)
        bar:StartSearch()
    elseif InSight(classic) and _G["BrowseName"] and _G["AuctionFrameBrowse_Search"] then
        -- On the Browse tab, where the box is: on another (Bids, an addon's)
        -- the search ran out of sight (2026-11-03).
        local browse, tab = _G["AuctionFrameBrowse"], _G["AuctionFrameTab1"]
        if browse and not browse:IsShown() and tab and _G["AuctionFrameTab_OnClick"] then _G["AuctionFrameTab_OnClick"](tab) end
        _G["BrowseName"]:SetText(name)
        _G["AuctionFrameBrowse_Search"]()
    elseif link and _G["ChatEdit_InsertLink"] and not (ChatFrameUtil and ChatFrameUtil.GetActiveWindow()) then
        -- Another addon's auction window over the house's (TSM's): the item
        -- goes where a linked item goes, never into an open chat box.
        _G["ChatEdit_InsertLink"](link)
    else
        return
    end
    S().lastSearched = line.id
end
Lines.SearchAH = SearchAH

-- The next item line still short of its target, after the last searched.
local function SearchNext(note)
    local lines, start = note.list.lines, 1
    for i, line in ipairs(lines) do
        if line.id == S().lastSearched then start = i + 1 break end
    end
    for n = 0, #lines - 1 do
        local line = lines[(start - 1 + n) % #lines + 1]
        if line.link == "item" and not CK.LineState(note, line) then
            SearchAH(note, line)
            return
        end
    end
end

-- The icon of the item or spell a line names.
local function ItemIcon(line)
    local kind, id = line.item and "item", line.item
    if not kind and line.link == "cooldown" then kind, id = "spell", line.spell end
    if kind == "item" then return C_Item.GetItemIconByID and C_Item.GetItemIconByID(id) end
    if kind == "spell" then return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id) end
end

-- The body's line for line id, its words replaced; decorations past it
-- move along, any inside its words go.
local function ReplaceWords(note, line, words)
    local start = CK.LineStart(note, line.id)
    if not start then return false end
    local body = note.body or ""
    local contentStart = start + #CK.EMPTY
    local nl = body:find("\n", contentStart, true)
    local lineEnd = nl and nl - 1 or #body
    local delta = #words - (lineEnd - contentStart + 1)
    note.body = body:sub(1, contentStart - 1) .. words .. body:sub(lineEnd + 1)
    local decos = note.decorations or {}
    for i = #decos, 1, -1 do
        local d = decos[i]
        if d.kind ~= "line" and d.startByte >= contentStart and d.startByte <= lineEnd + 1 then
            table.remove(decos, i)
        else
            if d.startByte > lineEnd then d.startByte = d.startByte + delta end
            if d.endByte > lineEnd + 1 then d.endByte = d.endByte + delta end
        end
    end
    note.updated = time()
    CK.Reconcile(note)
    return true
end

local function Changed(note)
    Told(note)
    Lines.Reload(note)
    W.ListFollows()
end

-- The line's own count or target changed: its words say so.
local function SetCount(note, line, n)
    CK.SetCount(line, n)
    ReplaceWords(note, line, CK.EditText(line))
    Changed(note)
end

-- Line id dropped from the note, its line of text with it.
function Lines.Remove(note, line)
    local start = CK.LineStart(note, line.id)
    if not start then return end
    local body = note.body or ""
    local nl = body:find("\n", start, true)
    local cutEnd = nl or #body
    local cutStart = start
    if not nl and start > 1 then cutStart = start - 1 end
    local len = cutEnd - cutStart + 1
    note.body = body:sub(1, cutStart - 1) .. body:sub(cutEnd + 1)
    local decos = note.decorations or {}
    for i = #decos, 1, -1 do
        local d = decos[i]
        if d.startByte >= cutStart and d.startByte <= cutEnd then
            table.remove(decos, i)
        else
            if d.startByte > cutEnd then d.startByte = d.startByte - len end
            if d.endByte > cutEnd then d.endByte = d.endByte - len end
        end
    end
    note.updated = time()
    CK.Reconcile(note)
    Changed(note)
end

-- A line under the note's last: the fields given, or words as typed.
function Lines.Add(note, line)
    local made = CK.AppendLine(note, line)
    Changed(note)
    return made
end

function Lines.AddWords(note, words)
    local last = CK.Is(note) and note.list.lines[#note.list.lines]
    -- An empty line waiting at the end takes the words.
    if last and not (last.item or last.link or (last.text or "") ~= "") then
        ReplaceWords(note, last, words)
        Changed(note)
        return last
    end
    return Lines.Add(note, { text = words })
end

local function Ask(text, default, onAccept, numeric)
    ns.ShowThemedDialog({
        text = text, hasEditBox = true, editBoxDefault = default and tostring(default) or "", maxLetters = 60,
        acceptText = _G["OKAY"] or "Okay", cancelText = _G["CANCEL"] or "Cancel",
        onAccept = function(value)
            value = strtrim(value or "")
            if numeric then
                local n = tonumber(value)
                if n then onAccept(n) end
            elseif value ~= "" then
                onAccept(value)
            end
        end,
    })
end

local TARGET_ASK = { item = "CHECK_TARGET_ITEM_ASK", gold = "CHECK_GOLD_ASK", level = "CHECK_LEVEL_ASK", skill = "CHECK_TARGET_SKILL_ASK" }

-- A line's menu: its auction search, its target, its standing, its end.
local function LineMenu(tail)
    local note, line = Note(), tail.line
    if not (note and line) then return end
    local rows = {}
    if AuctionOpen() and (line.item or line.link == "item" or (note.list.source and (line.text or "") ~= "")) then
        rows[#rows + 1] = { text = L["CHECK_SEARCH_AH"], onClick = function() SearchAH(note, line) end }
    end
    local counts = line.link or (line.item and "item")
    -- A checklist's items are ticked by hand: no count to set.
    if counts == "item" and not CK.ItemsList(note) then counts = nil end
    if counts and TARGET_ASK[counts] then
        rows[#rows + 1] = { text = L["CHECK_SET_TARGET"], onClick = function()
            local cur = counts == "gold" and mfloor((line.target or 0) / 10000) or line.target
            Ask(L[TARGET_ASK[counts]], cur, function(n)
                if counts == "item" then
                    SetCount(note, line, mmax(1, mfloor(n)))
                else
                    line.link = counts
                    line.target = counts == "gold" and mfloor(n * 10000) or mmax(1, mfloor(n))
                    Changed(note)
                end
            end, true)
        end }
    end
    if line.link == "rep" then
        local sub = {}
        for standing = 4, 8 do
            sub[#sub + 1] = { text = CK.StandingLabel(standing), onClick = function() line.standing = standing Changed(note) end }
        end
        rows[#rows + 1] = { text = L["CHECK_SET_STANDING"], submenu = sub }
    end
    if #rows > 0 then rows[#rows + 1] = { isSeparator = true } end
    rows[#rows + 1] = { text = _G["REMOVE"] or L["CHECK_REMOVE"], onClick = function() Lines.Remove(note, line) end }
    NotesUI:ShowEasyNotesMenu("EasyNotesLineMenu", rows, { toggleOwner = tail })
end

-- The count typed over itself: Enter or a click away keeps it, emptied or
-- 0 the line has none, Escape leaves it.
local function CountBox()
    local s = S()
    if s.countBox then return s.countBox end
    local box = CreateFrame("EditBox", nil, Frame())
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    ns.RegisterAddonFont(box)
    box:SetNumeric(true)
    box:SetMaxLetters(6)
    box:SetJustifyH("RIGHT")
    box:SetSize(44, 16)
    box:SetFrameLevel(Frame():GetFrameLevel() + 12)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self)
        self.cancel = true
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:Hide()
        local note, line = Note(), self.line
        self.line = nil
        if self.cancel or not (note and line) then return end
        SetCount(note, line, tonumber(self:GetText() or ""))
    end)
    Utils.ReleaseFocusOnOutsideClick(box)
    box:Hide()
    s.countBox = box
    return box
end

local function EditCount(tail)
    local line = tail.line
    if not (line and CK.HasCount(line)) then return end
    local box = CountBox()
    box.line, box.cancel = line, false
    box:ClearAllPoints()
    box:SetPoint("RIGHT", tail.text, "RIGHT", 0, 0)
    box:SetText(tostring(line.target))
    box:Show()
    box:SetFocus()
    box:HighlightText()
end

-- Prices on a shopping list (2026-11-03): from the source the player
-- picked (EasyFind.db.notesPriceSource "id:key"), else each item's first
-- extension with a price, at its main kind; one item's price kept a
-- minute, a line's the price of what is left to buy, the total their sum.
local prices = { cache = {} }
local function MoneyText(copper)
    local fn = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString or GetCoinTextureString
    return fn and copper and copper > 0 and fn(copper) or nil
end
Lines.MoneyText = MoneyText

-- Every source on offer; firsts: each extension's main kind.
local function Choices()
    if not prices.choices then
        local list = ns.PriceChoices and ns.PriceChoices() or {}
        local firsts, seen = {}, {}
        for _, c in ipairs(list) do
            if not seen[c.id] then
                seen[c.id] = true
                firsts[#firsts + 1] = c
            end
        end
        prices.choices, prices.firsts = list, firsts
    end
    return prices.choices
end

-- The player's pick; nil for the first with a price.
local function PickedPrice()
    local want = EasyFind.db and EasyFind.db.notesPriceSource
    for _, c in ipairs(Choices()) do
        if c.value == want then return c end
    end
end

local function SourcePrice(c, itemID)
    local k, now = c.value .. ":" .. itemID, GetTime()
    local hit = prices.cache[k]
    if not (hit and now - hit.at < 60) then
        local link = C_Item.GetItemInfo and select(2, C_Item.GetItemInfo(itemID))
        local ok, copper, note = xpcall(ns.PriceSources[c.id].price, geterrorhandler(), c.key, itemID, link)
        hit = { at = now, copper = ok and type(copper) == "number" and copper > 0 and copper or false, note = ok and note or nil }
        prices.cache[k] = hit
    end
    return hit
end

-- One item's price in copper, its note ("Seen today") and the source.
local function UnitPrice(itemID)
    if not itemID then return nil end
    local c = PickedPrice()
    if c then
        local hit = SourcePrice(c, itemID)
        if hit.copper then return hit.copper, hit.note, c end
        return nil
    end
    Choices()
    for _, first in ipairs(prices.firsts) do
        local hit = SourcePrice(first, itemID)
        if hit.copper then return hit.copper, hit.note, first end
    end
end

local function PriceSwitch(key)
    local db = EasyFind and EasyFind.db
    return not (db and db[key] == false)
end

-- The sources the total came from: the pick, else the extensions used.
local function TotalSource(used)
    local picked = PickedPrice()
    if picked then return picked.label end
    local names = {}
    for _, first in ipairs(prices.firsts or {}) do
        if used[first.id] then names[#names + 1] = first.name end
    end
    return table.concat(names, ", ")
end

-- A source added, a scan done or a setting changed: every list again.
function Lines.PricesChanged()
    prices.choices, prices.cache = nil, {}
    W.Each(function() NotesUI:QueueEasyNotesOverlayUpdate() end)
end
notesNS.PricesChanged = Lines.PricesChanged

-- The total's menu: where prices come from, and what shows.
function Lines.PriceMenu(anchor)
    if not ns.ShowTogglePopup then return end
    local db = EasyFind.db
    local defs = { { kind = "title", label = L["NOTES_PRICES_FROM"] } }
    local function Radio(label, value)
        return { kind = "radio", label = label, value = value,
            get = function()
                local c = PickedPrice()
                return c and c.value or ns.PRICE_ANY
            end,
            set = function(v)
                if v == ns.PRICE_ANY then db.notesPriceSource = nil else db.notesPriceSource = v end
                Lines.PricesChanged()
            end }
    end
    defs[#defs + 1] = Radio(L["NOTES_PRICES_ANY"], ns.PRICE_ANY)
    for _, c in ipairs(Choices()) do defs[#defs + 1] = Radio(c.label, c.value) end
    local function Switch(key, label)
        return { kind = "check", label = label, get = function() return PriceSwitch(key) end,
            set = function(on)
                if on then db[key] = nil else db[key] = false end
                Lines.PricesChanged()
            end }
    end
    defs[#defs + 1] = { kind = "separator" }
    defs[#defs + 1] = { kind = "title", label = _G["SHOW"] or "Show" }
    defs[#defs + 1] = Switch("notesPriceLines", L["NOTES_PRICES_LINES"])
    defs[#defs + 1] = Switch("notesPriceTotal", _G["TOTAL"] or "Total")
    local frame = Frame()
    ns.ShowTogglePopup("EasyNotesPriceMenu", anchor, defs, { scale = frame and frame:GetScale() or 1 })
end

local function Tail(layer, i)
    local s = S()
    local tail = s.tails[i]
    if tail then return tail end
    tail = CreateFrame("Button", nil, layer)
    tail:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    tail.x = ns.CreateCloseX(tail, 10)
    tail.x:SetPoint("RIGHT", tail, "RIGHT", -1, 0)
    tail.x:SetScript("OnClick", function()
        local note = Note()
        if note and tail.line then Lines.Remove(note, tail.line) end
    end)
    tail.x:Hide()
    tail.text = tail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ns.RegisterAddonFont(tail.text)
    tail.text:SetJustifyH("RIGHT")
    tail.text:SetWordWrap(false)
    tail.text:SetPoint("RIGHT", tail, "RIGHT", -14, 0)
    tail.icon = tail:CreateTexture(nil, "ARTWORK")
    tail.icon:SetSize(14, 14)
    tail.icon:SetPoint("RIGHT", tail.text, "LEFT", -3, 0)
    tail.price = tail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ns.RegisterAddonFont(tail.price)
    tail.price:SetJustifyH("RIGHT")
    tail.price:SetWordWrap(false)
    tail:SetScript("OnEnter", function(self)
        self.x:Show()
        local line = self.line
        local tip = line and line.detail
        -- One's price, how many are left, where it came from.
        if self.priceTip then tip = tip and (self.priceTip .. "\n" .. tip) or self.priceTip end
        if line and line.link then tip = tip and (tip .. "\n" .. L["CHECK_AUTO_TT"]) or L["CHECK_AUTO_TT"] end
        if line and CK.HasCount(line) then tip = tip and (tip .. "\n" .. L["CHECK_COUNT_TT"]) or L["CHECK_COUNT_TT"] end
        if tip then NotesUI:ShowNotesTipDelayed(self, "ANCHOR_LEFT", tip) end
    end)
    tail:SetScript("OnLeave", function(self)
        if not self.x:IsMouseOver() then self.x:Hide() end
        NotesUI:HideNotesTip(self)
    end)
    tail.x:HookScript("OnLeave", function() if not tail:IsMouseOver() then tail.x:Hide() end end)
    -- A click opens the line's menu; Ctrl+click searches it at an open
    -- auction house; a double-click types a new count over the count.
    tail:SetScript("OnClick", function(self, button)
        local note = Note()
        if not (note and self.line) then return end
        if button == "LeftButton" and IsControlKeyDown() then
            if AuctionOpen() then SearchAH(note, self.line) end
            return
        end
        LineMenu(self)
    end)
    tail:SetScript("OnDoubleClick", function(self) EditCount(self) end)
    s.tails[i] = tail
    return tail
end

-- Folding: a line with an icon or a count reads its words cut to fit with
-- "..." and its count hidden (the tail shows it), never wrapped under the
-- tail; the line the caret is on opens to be typed (2026-11-02). The words
-- stay in the body, in the folded link's data (CK.Fold).
local ELLIPSIS, FOLD_GAP = "...", 6

local function Meter(layer, editor)
    local s = S()
    if not s.meter then
        s.meter = layer:CreateFontString(nil, "OVERLAY")
        s.meter:Hide()
    end
    local path, size, flags = editor:GetFont()
    if path then s.meter:SetFont(path, size, flags or "") end
    return s.meter
end

local function Width(meter, text)
    meter:SetText(text)
    return meter:GetStringWidth() or 0
end

-- An item link's bracketed name in its color, else the words as drawn.
local function Label(words)
    local color, name = smatch(words, "^(|c%x%x%x%x%x%x%x%x)|H[^|]*|h(%[.-%])|h|r$")
    if name then return name, color end
    return (words:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")), nil
end

-- The label cut to room, "..." inside a bracketed name's brackets.
local function Fit(meter, label, room)
    if Width(meter, label) <= room then return label end
    local open, close, inner = "", "", label
    if label:sub(1, 1) == "[" and label:sub(-1) == "]" then open, close, inner = "[", "]", label:sub(2, -2) end
    local starts = {}
    for i = 1, #inner do
        local b = inner:byte(i)
        if b < 128 or b >= 192 then starts[#starts + 1] = i end
    end
    local function Cut(n) return inner:sub(1, (starts[n + 1] or (#inner + 1)) - 1) end
    local lo, hi = 0, #starts - 1
    while lo < hi do
        local mid = math.ceil((lo + hi) / 2)
        if Width(meter, open .. Cut(mid) .. ELLIPSIS .. close) <= room then lo = mid else hi = mid - 1 end
    end
    return open .. Cut(lo) .. ELLIPSIS .. close
end

-- Styles inside a line's words: an item link's color (a note's colors
-- moved into decorations) goes into the fold as the link's own code; any
-- other style keeps the line open, since a fold drops it.
local function FoldColor(note, s, e, words)
    local color
    for _, d in ipairs(note.decorations or {}) do
        if d.kind ~= "line" and d.startByte <= e and d.endByte > s then
            if d.kind ~= "color" or not smatch(words, "^|H[^|]*|h%[.-%]|h$") then return false end
            color = color or sformat("|cff%02x%02x%02x", mfloor((d.r or 1) * 255 + 0.5),
                mfloor((d.g or 1) * 255 + 0.5), mfloor((d.b or 1) * 255 + 0.5))
        end
    end
    return true, color
end

-- The start of the caret's line while the editor has the keyboard.
local function CaretLineStart(editor, text)
    if not editor:HasFocus() then return nil end
    local nl = text:sub(1, editor:GetCursorPosition() or 0):match(".*()\n")
    return nl and nl + 1 or 1
end

-- The folds and openings into the body and the editor at once; the caret
-- stays put, at the end of a line it opened.
local function ApplyFolds(editor, note, edits)
    local caret = editor:GetCursorPosition() or 0
    local shift, place = 0, nil
    for _, ed in ipairs(edits) do
        if ed.onCaret then
            place = ed.s - 1 + (caret > ed.s - 1 and #ed.repl or 0)
        elseif ed.e <= caret then
            shift = shift + #ed.repl - (ed.e - ed.s + 1)
        end
    end
    for i = #edits, 1, -1 do CK.ReplaceRange(note, edits[i].s, edits[i].e, edits[i].repl) end
    local ui = NotesUI._notes
    ui.loadingNote = true
    editor:SetText(note.body)
    editor:SetCursorPosition((place or caret) + shift)
    ui.loadingNote = nil
    ui.lastEditorText = note.body
    NotesUI:QueueEasyNotesOverlayUpdate()
end

-- A tail on every box line's first row: its count and icon when it has
-- them, the X under the cursor. positions nil: none.
function Lines.PlaceTails(editor, positions, lineYs, lineH)
    if not Editing(editor) then return end
    local s = S()
    local note = Note()
    if not (positions and note and CK.Is(note)) then
        for _, tail in ipairs(s.tails) do tail:Hide() end
        return
    end
    local layer = Layer(editor)
    local done, open = DoneColor(), OpenColor()
    local used = 0
    -- Not while text is selected or dragged: a fold rewrites the text.
    local text, ui = editor:GetText() or "", NotesUI._notes
    local folding = text == (note.body or "") and not (ui.curSelection or ui.inputBusy or ui.applyingFormat
        or editor._notesDragging or (IsShiftKeyDown and IsShiftKeyDown()))
    local byStart, edits, meter, caretAt, editorW, boxW = {}, {}, nil, nil, 0, 0
    local shopping, showPrices = CK.ItemsList(note), PriceSwitch("notesPriceLines")
    if folding then
        for _, f in ipairs(CK.BodyLines(text)) do byStart[f.start] = f end
        meter = Meter(layer, editor)
        caretAt = CaretLineStart(editor, text)
        editorW, boxW = editor:GetWidth() or 0, Width(meter, CK.EMPTY)
    end
    for k = 1, #positions do
        local p = positions[k]
        if p.isPrefix and (p.glyph == BOX_GLYPH or p.glyph == TICKED_GLYPH) then
            local line = CK.LineAt(note, p.byteStart)
            if line then
                used = used + 1
                local tail = Tail(layer, used)
                tail.line = line
                local isDone, progress, detail = CK.LineState(note, line)
                line.detail = (detail and detail ~= "") and detail or nil
                local icon = (line.link or line.item) and ItemIcon(line)
                tail.icon:SetShown(icon ~= nil)
                if icon then tail.icon:SetTexture(icon) end
                tail.text:SetText(progress or "")
                local c = isDone and done or open
                tail.text:SetTextColor(c[1], c[2], c[3], 1)
                -- What is left to buy, at the picked price, a shopping list's.
                local left = shopping and CK.ItemsLeft(note, line)
                local unit, pnote, src
                if left and left > 0 then unit, pnote, src = UnitPrice(line.item) end
                tail.priceTip = unit and (sformat(L["NOTES_PRICE_EACH_FMT"], MoneyText(unit), left)
                    .. "\n|cff999999" .. src.label .. (pnote and (", " .. pnote) or "") .. "|r") or nil
                local cost = unit and showPrices and MoneyText(unit * left)
                tail.price:SetText(cost or "")
                tail.price:SetShown(cost ~= nil)
                tail.price:ClearAllPoints()
                tail.price:SetPoint("RIGHT", icon and tail.icon or tail.text, "LEFT", -4, 0)
                local w = 16 + (progress and progress ~= "" and (tail.text:GetStringWidth() + 2) or 0) + (icon and 18 or 0)
                    + (cost and tail.price:GetStringWidth() + 4 or 0)
                tail:SetSize(mmax(22, w), lineH)
                tail.lineY, tail.lineH = lineYs[p.line] or 0, lineH
                tail:ClearAllPoints()
                tail:SetPoint("TOPRIGHT", editor, "TOPRIGHT", 0, -tail.lineY)
                tail:Show()
                tail:SetAlpha(1)
                tail:EnableMouse(true)
                local f = byStart[p.byteStart]
                if f and (icon or (progress and progress ~= "")) then
                    local room = editorW - mmax(22, w) - boxW - FOLD_GAP
                    local content = text:sub(f.contentStart, f.lineEnd)
                    local raw = CK.Unfold(content)
                    -- A box ticked puts the caret on its line; it opens on a key or a click on its words.
                    local onCaret = p.byteStart == caretAt and editor._efBoxLine ~= p.byteStart
                    local want = raw
                    if onCaret then
                        -- Open to be typed: words past the tail's room put the tail
                        -- out of sight (it stays placed: the names hang under it).
                        if Width(meter, raw) > room then
                            tail:SetAlpha(0)
                            tail:EnableMouse(false)
                        end
                    else
                        local words, count = CK.SplitCount(raw)
                        local foldable, baked = FoldColor(note, f.contentStart, f.lineEnd, words)
                        -- The color goes in front of the link: a count typed first ("2 [x]") stays open.
                        if baked and raw:sub(1, #words) ~= words then foldable = false end
                        -- A count the list does not keep (a checklist's) stays in sight after the name.
                        local typed = ""
                        if count and not CK.HasCount(line) then
                            if raw:sub(1, #words) ~= words then foldable = false end
                            typed, count = raw:sub(#words + 1), nil
                        end
                        if foldable then
                            if baked then
                                local link = words
                                words = baked .. link .. "|r"
                                raw = words .. raw:sub(#link + 1)
                            end
                            local label, color = Label(words)
                            local cut = Fit(meter, label, room - Width(meter, typed))
                            if count or cut ~= label then want = CK.Fold(raw, cut .. typed, color) end
                        end
                    end
                    if want ~= content then
                        edits[#edits + 1] = { s = f.contentStart, e = f.lineEnd, repl = want, onCaret = onCaret }
                    end
                end
            end
        end
    end
    for i = used + 1, #s.tails do s.tails[i]:Hide() end
    if #edits > 0 then ApplyFolds(editor, note, edits) end
end

-- The editor is on a shopping list.
function Lines.Shopping(editor)
    if not Editing(editor) then return false end
    local note = Note()
    return note ~= nil and CK.ItemsList(note)
end

-- A new line at the list's end, the caret on it to type a name.
local function AddItemLine(editor)
    local text = editor:GetText() or ""
    editor:SetFocus()
    editor:SetCursorPosition(#text)
    if text:match("[^\n]*$") ~= CK.EMPTY then editor:Insert((text == "" and "" or "\n") .. CK.EMPTY) end
end

-- The offer under a checklist with items on it: make it a shopping list,
-- or no for this note (prompt A, 2026-11-02).
local function OfferRow(layer)
    local s = S()
    if s.offerRow then return s.offerRow end
    local row = CreateFrame("Frame", nil, layer)
    row:EnableMouse(true)
    if ns.CreateRoundedRectBorder then
        ns.CreateRoundedRectBorder(row)
        ns.SetRoundedRectBarHeight(row, 10)
        ns.SetRoundedRectBorderEdgeShown(row, false)
    end
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(14, 14)
    row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -8)
    row.icon:SetTexture("Interface\\AddOns\\EasyFind_Notes\\Images\\tag")
    -- "Never show again", as the box says, else no for this note alone.
    row.never = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.never:SetSize(18, 18)
    row.never:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 4, 3)
    row.never.text = row.never:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.never.text:SetPoint("LEFT", row.never, "RIGHT", 2, 1)
    row.never.text:SetText(L["NOTES_SHOP_NEVER"])
    row.never:SetHitRectInsets(0, -(math.ceil(row.never.text:GetStringWidth()) + 4), 0, 0)
    local function Settle(note)
        if row.never:GetChecked() and EasyFind and EasyFind.db then EasyFind.db.notesShopOffer = false end
        row.never:SetChecked(false)
        Repaint(note)
    end
    row.x = ns.CreateCloseX(row, 10)
    row.x:SetPoint("TOPRIGHT", row, "TOPRIGHT", -5, -5)
    row.x:SetScript("OnClick", function()
        local note = Note()
        if not note then return end
        note.list.shopDeclined = true
        Settle(note)
    end)
    row.convert = ns.CreateModernButton(row, L["NOTES_SHOP_CONVERT"], 60, 18)
    row.convert:SetWidth(math.ceil(row.convert._label:GetStringWidth()) + 20)
    row.convert:SetPoint("TOPRIGHT", row, "TOPRIGHT", -22, -6)
    row.convert:SetScript("OnClick", function()
        local note = Note()
        if not note then return end
        notesNS.SetShopping(note, true)
        Settle(note)
    end)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 1)
    row.label:SetPoint("RIGHT", row.convert, "LEFT", -6, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(true)
    if row.label.SetMaxLines then row.label:SetMaxLines(2) end
    row.label:SetText(L["NOTES_SHOP_OFFER"])
    -- What a shopping list adds, the Auctionator list where its extension is in.
    local function Tip(self) NotesUI:ShowNotesTipDelayed(self, "ANCHOR_TOP", NotesUI.ShoppingListTip()) end
    local function Untip(self) NotesUI:HideNotesTip(self) end
    row:SetScript("OnEnter", Tip)
    row:SetScript("OnLeave", Untip)
    row.convert:HookScript("OnEnter", Tip)
    row.convert:HookScript("OnLeave", Untip)
    s.offerRow = row
    return row
end

-- The list's total under its add line: the header's divider over it
-- across the whole list, "Total" and the source, the sum of what is left
-- to buy; a click opens where prices come from and what shows.
local function TotalRow(layer)
    local s = S()
    if s.totalRow then return s.totalRow end
    local row = CreateFrame("Button", nil, layer)
    row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
    row:GetHighlightTexture():SetAlpha(0.2)
    row.rule = row:CreateTexture(nil, "ARTWORK")
    row.rule:SetColorTexture(0.18, 0.18, 0.20, 0.7)
    row.rule:SetHeight(1)
    row.rule:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.rule:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetText(_G["TOTAL"] or "Total")
    row.money = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.money:SetJustifyH("RIGHT")
    row.money:SetWordWrap(false)
    row.source = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.source:SetJustifyH("LEFT")
    row.source:SetWordWrap(false)
    row:SetScript("OnClick", function(self) Lines.PriceMenu(self) end)
    s.totalRow = row
    return row
end

local function PlaceTotal(row, editor, note, y, lineH)
    local sum, used = 0, {}
    for _, line in ipairs(note.list.lines) do
        local left = CK.ItemsLeft(note, line)
        if left and left > 0 then
            local unit, _, src = UnitPrice(line.item)
            if unit then
                sum = sum + unit * left
                used[src.id] = true
            end
        end
    end
    local path, size, flags = editor:GetFont()
    if path then
        row.label:SetFont(path, size, flags or "")
        row.money:SetFont(path, size, flags or "")
    end
    row.source:SetText(TotalSource(used))
    row.money:SetText(MoneyText(sum) or "")
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row, "LEFT", Width(Meter(row:GetParent(), editor), CK.EMPTY), -2)
    row.money:ClearAllPoints()
    row.money:SetPoint("RIGHT", row, "RIGHT", -14, -2)
    row.source:ClearAllPoints()
    row.source:SetPoint("LEFT", row.label, "RIGHT", 6, 0)
    row.source:SetPoint("RIGHT", row.money, "LEFT", -6, 0)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", editor, "TOPLEFT", 0, -y)
    row:SetPoint("RIGHT", editor, "RIGHT", 0, 0)
    row:SetHeight(lineH + 6)
    row:Show()
end

-- Its ground as the note cards wear it: the thin edge under the Classic
-- and Forever frames, the card fill elsewhere.
local function PaintOffer(row)
    local frame = Frame()
    local skin = frame ~= nil and frame._efSkin or nil
    local edged = skin == "classic" or skin == "forever"
    NotesUI.PaintNotesCardEdge(row, skin, false, false)
    if not ns.SetRoundedRectFill then return end
    if edged then
        ns.SetRoundedRectFill(row, 0, 0, 0, 0, true)
    else
        local c = ns.ThemeSetOf(row).BTN_FILL_NORMAL or { 0.16, 0.19, 0.25 }
        ns.SetRoundedRectFill(row, c[1], c[2], c[3], 1, true)
    end
end

-- The add line under a shopping list's last line, as the old list view
-- had it: a "+" in the box column, "Add item", a click starts a line; on a
-- checklist with items, the offer to make it one in its place. The editor
-- keeps room under its text for either. positions nil: none.
function Lines.PlaceAddRow(editor, text, positions, lineYs, lineH, advance)
    if not Editing(editor) then return end
    local s = S()
    local note = Note()
    local on = positions ~= nil and Lines.Shopping(editor)
    local offer = positions ~= nil and not on and note ~= nil and CK.OffersShopping(note)
    local layer = offer and Layer(editor)
    local offerRow = offer and OfferRow(layer) or s.offerRow
    local offerH = 0
    if offer then
        PaintOffer(offerRow)
        -- Another note's offer starts with the box clear.
        if s.offerNote ~= note.id then
            s.offerNote = note.id
            offerRow.never:SetChecked(false)
        end
        offerH = mmax(18, offerRow.label:GetStringHeight() or 0) + 14 + 20
    end
    local total = on and PriceSwitch("notesPriceTotal") and #Choices() > 0
    local room = (on and lineH + (total and lineH + 10 or 0)) or (offer and offerH + 6) or 0
    if s.addRoom ~= room and editor.SetTextInsets then
        s.addRoom = room
        editor:SetTextInsets(0, 0, 0, room)
    end
    if offerRow and not offer then offerRow:Hide() end
    local step = advance or lineH
    local y = 0
    if text ~= "" and positions then
        local last = 1
        for k = 1, #positions do
            if positions[k].line > last then last = positions[k].line end
        end
        y = (lineYs[last] or 0) + step
        if text:sub(-1) == "\n" then y = y + step end
    end
    if offer then
        offerRow:ClearAllPoints()
        offerRow:SetPoint("TOPLEFT", editor, "TOPLEFT", 0, -(y + 4))
        offerRow:SetPoint("RIGHT", editor, "RIGHT", 0, 0)
        offerRow:SetHeight(offerH)
        offerRow:Show()
    end
    local row = s.addRow
    if s.totalRow and not total then s.totalRow:Hide() end
    if not on then
        if row then row:Hide() end
        return
    end
    layer = Layer(editor)
    if total then PlaceTotal(TotalRow(layer), editor, note, y + lineH + 4, lineH) end
    if not row then
        row = CreateFrame("Button", nil, layer)
        row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
        row:GetHighlightTexture():SetAlpha(0.2)
        row.plus = row:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        row.plus:SetText("+")
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        row.label:SetText(L["CHECK_ADD_ITEM"])
        row:SetScript("OnClick", function() AddItemLine(editor) end)
        s.addRow = row
    end
    local meter = Meter(layer, editor)
    local path, size, flags = editor:GetFont()
    if path then
        row.plus:SetFont(path, size, flags or "")
        row.label:SetFont(path, size, flags or "")
    end
    row.plus:ClearAllPoints()
    row.plus:SetPoint("CENTER", row, "LEFT", Width(meter, "\226\150\161") / 2, 0)
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row, "LEFT", Width(meter, CK.EMPTY), 0)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", editor, "TOPLEFT", 0, -y)
    row:SetPoint("RIGHT", editor, "RIGHT", 0, 0)
    row:SetHeight(lineH)
    row:Show()
end

-- Tracking: lines the game ticks

local function QuestRows(note)
    local rows = {}
    local QL = C_QuestLog
    for i = 1, (QL and QL.GetNumQuestLogEntries and QL.GetNumQuestLogEntries()) or 0 do
        local info = QL.GetInfo(i)
        if info and not info.isHeader and info.questID then
            rows[#rows + 1] = { text = info.title, onClick = function() Lines.Add(note, { link = "quest", quest = info.questID }) end }
        end
    end
    return rows
end

local function FactionRows(note)
    local rows = {}
    for i = 1, ns.Caps.NumFactions() do
        local data = ns.Caps.FactionAt(i)
        if data and not data.isHeader and data.factionID and data.factionID > 0 then
            rows[#rows + 1] = { text = data.name, onClick = function() Lines.Add(note, { link = "rep", faction = data.factionID, standing = 8 }) end }
        end
    end
    return rows
end

local function SkillRows(note)
    local rows = {}
    for _, prof in ipairs({ GetProfessions and GetProfessions() }) do
        if prof then
            local name, _, _, maxLevel = GetProfessionInfo(prof)
            if name then
                rows[#rows + 1] = { text = name, onClick = function() Lines.Add(note, { link = "skill", skill = name, target = maxLevel or 1 }) end }
            end
        end
    end
    return rows
end

local function LockoutRows(note)
    local rows, seen = {}, {}
    for i = 1, (GetNumSavedInstances and GetNumSavedInstances()) or 0 do
        local name = GetSavedInstanceInfo(i)
        if name and not seen[name] then
            seen[name] = true
            rows[#rows + 1] = { text = name, onClick = function() Lines.Add(note, { link = "lockout", instance = name }) end }
        end
    end
    rows[#rows + 1] = { text = L["CHECK_TYPE_NAME"], onClick = function()
        Ask(L["CHECK_LOCKOUT_ASK"], "", function(v) Lines.Add(note, { link = "lockout", instance = v }) end)
    end }
    return rows
end

local function BagItemRows(note)
    local rows, seen = {}, {}
    local C_Container = C_Container
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, (C_Container and C_Container.GetContainerNumSlots(bag)) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and not seen[id] then
                seen[id] = true
                local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
                if name then rows[#rows + 1] = { text = name, onClick = function() Lines.Add(note, { link = "item", item = id, target = 1 }) end } end
            end
        end
    end
    table.sort(rows, function(a, b) return a.text < b.text end)
    return rows
end

local function Empty(rows)
    if #rows == 0 then rows[1] = { text = L["CHECK_NOTHING_HERE"], disabled = true } end
    return rows
end

-- What a new line can follow; the bags, quest log and factions run long:
-- a search, and a scroll past 14.
function Lines.TrackRows(note)
    local find, cap = L["SEARCH_PLACEHOLDER"], 14
    local rows = {
        { text = L["CHECK_LINK_QUEST"], submenu = Empty(QuestRows(note)), submenuSearch = find, submenuMaxRows = cap },
        { text = L["CHECK_LINK_REP"], submenu = Empty(FactionRows(note)), submenuSearch = find, submenuMaxRows = cap },
        { text = L["CHECK_LINK_GOLD"], onClick = function()
            Ask(L["CHECK_GOLD_ASK"], 100, function(n) Lines.Add(note, { link = "gold", target = mfloor(n * 10000) }) end, true)
        end },
        { text = L["CHECK_LINK_LEVEL"], onClick = function()
            Ask(L["CHECK_LEVEL_ASK"], (UnitLevel("player") or 1) + 1, function(n) Lines.Add(note, { link = "level", target = mfloor(n) }) end, true)
        end },
        { text = L["CHECK_LINK_SKILL"], submenu = Empty(SkillRows(note)) },
        { text = L["CHECK_LINK_LOCKOUT"], submenu = Empty(LockoutRows(note)), submenuMaxRows = cap },
        { text = L["CHECK_LINK_COOLDOWN"], onClick = function()
            Ask(L["CHECK_COOLDOWN_ASK"], "", function(v)
                local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(tonumber(v) or v)
                if info and info.spellID then Lines.Add(note, { link = "cooldown", spell = info.spellID }) end
            end)
        end },
    }
    -- An item's count, ticked from the bags, is a shopping list's alone.
    if CK.ItemsList(note) then
        table.insert(rows, 1, { text = L["CHECK_LINK_ITEM"], submenu = Empty(BagItemRows(note)), tooltip = L["CHECK_SHIFT_CLICK_TT"],
            submenuSearch = find, submenuMaxRows = cap })
    end
    return rows
end

-- The ticks' settings

local SCOPES = {
    { value = "account", label = L["CHECK_SCOPE_ACCOUNT"] },
    { value = "character", label = L["CHECK_SCOPE_CHARACTER"] },
}
local RESETS = {
    { value = "never", label = L["CHECK_RESET_NEVER"] },
    { value = "daily", label = L["CHECK_RESET_DAILY"] },
    { value = "weekly", label = L["CHECK_RESET_WEEKLY"] },
    { value = "days", label = L["CHECK_RESET_DAYS"] },
}

local function OptionLabel(options, value)
    for _, o in ipairs(options) do
        if o.value == value then return o.label end
    end
    return options[1].label
end

local function PickReset(owner, note)
    local reset = note.list.reset
    local defs = {}
    for _, o in ipairs(RESETS) do
        defs[#defs + 1] = { kind = "radio", label = o.label, value = o.value,
            get = function() return reset.every end, set = function(v) reset.every = v Changed(note) end }
    end
    if reset.every == "days" then
        defs[#defs + 1] = { kind = "separator" }
        reset.days = reset.days or {}
        for wday = 1, 7 do
            defs[#defs + 1] = { kind = "check", label = _G["WEEKDAY_" .. ({ "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY" })[wday]] or tostring(wday),
                get = function() return reset.days[wday] == true end,
                set = function(v) reset.days[wday] = v or nil Changed(note) end }
        end
        defs[#defs + 1] = { kind = "action", label = sformat(L["CHECK_RESET_AT_FMT"], reset.hour or 0, reset.min or 0), onClick = function()
            Ask(L["CHECK_RESET_AT_ASK"], sformat("%02d:%02d", reset.hour or 0, reset.min or 0), function(v)
                local h, m = smatch(v, "^(%d%d?):(%d%d)$")
                h, m = tonumber(h), tonumber(m)
                if h and m and h < 24 and m < 60 then reset.hour, reset.min = h, m Changed(note) end
            end)
        end }
    end
    ns.ShowTogglePopup("EasyFindChecklistReset", owner, defs, {})
end

-- The note menu's Checklist entry: what a line can track; with lines, who
-- keeps the ticks, when they clear, the board, the next auction search.
function Lines.MenuRows(note, anchor)
    local rows = { { text = L["CHECK_TRACK"], submenu = Lines.TrackRows(note) } }
    if not CK.Is(note) then return rows end
    local list = CK.Init(note)
    local scopes = {}
    for _, o in ipairs(SCOPES) do
        scopes[#scopes + 1] = { text = o.label, icon = (list.scope or "account") == o.value and MENU_CHECK_TEX or nil,
            onClick = function() list.scope = o.value Changed(note) end }
    end
    rows[#rows + 1] = { isSeparator = true }
    rows[#rows + 1] = { text = sformat(L["CHECK_SCOPE_FMT"], OptionLabel(SCOPES, list.scope)), submenu = scopes }
    rows[#rows + 1] = { text = L["CHECK_RESET_ROW"], onClick = function() PickReset(anchor, note) end }
    rows[#rows + 1] = { text = L["CHECK_BOARD"], icon = S().boardShown and MENU_CHECK_TEX or nil, iconSide = "right",
        onClick = function() Lines.ShowBoard(not S().boardShown) end }
    rows[#rows + 1] = { text = L["CHECK_SEARCH_AH"], disabled = not AuctionOpen(), onClick = function() SearchNext(note) end }
    return rows
end

-- The alts board: one column per character, one row per line, over the words.

local function Text(parent, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template)
    ns.RegisterAddonFont(fs)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function Board()
    local s = S()
    if s.board then return s.board end
    local frame = Frame()
    local board = CreateFrame("Frame", nil, frame)
    board:SetAllPoints(frame.editorScroll)
    board:SetFrameLevel(frame.editor:GetFrameLevel() + 8)
    board:EnableMouse(true)
    board:EnableMouseWheel(true)
    if ns.CreateRoundedRectBorder then
        ns.CreateRoundedRectBorder(board)
        ns.SetRoundedRectBarHeight(board, 8)
        ns.SetRoundedRectBorderEdgeShown(board, false)
        ns.SetRoundedRectRingShown(board, false)
        local c = ns.ThemeSetOf(board).SEARCH_WINDOW_FILL_COLOR or { 0.052, 0.052, 0.060 }
        ns.SetRoundedRectFill(board, c[1], c[2], c[3], 1, true)
    end
    local scroll = CreateFrame("ScrollFrame", nil, board)
    scroll:SetPoint("TOPLEFT", board, "TOPLEFT", 0, -2)
    scroll:SetPoint("BOTTOMRIGHT", board, "BOTTOMRIGHT", -12, 2)
    board.scroll = scroll
    board.list = CreateFrame("Frame", nil, scroll)
    board.list:SetSize(1, 1)
    scroll:SetScrollChild(board.list)
    board.bar = Utils.CreateMinimalScrollBar(scroll, board)
    board:Hide()
    s.board = board
    return board
end

local function Cell(board, i)
    local s = S()
    local cell = s.cells[i]
    if cell then return cell end
    cell = CreateFrame("Frame", nil, board.list)
    cell:SetSize(CELL_W, ROW_H)
    cell.tex = cell:CreateTexture(nil, "ARTWORK")
    cell.tex:SetSize(16, 16)
    cell.tex:SetPoint("CENTER")
    cell.tex:SetTexture(READY_TEX)
    cell.text = Text(cell, "GameFontHighlightSmall")
    cell.text:SetPoint("CENTER")
    cell.text:SetJustifyH("CENTER")
    s.cells[i] = cell
    return cell
end

local function Head(board, i)
    local s = S()
    local head = s.heads[i]
    if head then return head end
    head = Text(board.list, "GameFontNormalSmall")
    head:SetWidth(CELL_W)
    head:SetJustifyH("CENTER")
    s.heads[i] = head
    return head
end

local function Row(board, i)
    local s = S()
    local row = s.rows[i]
    if row then return row end
    row = Text(board.list, "GameFontHighlight")
    row:SetWidth(NAME_W)
    s.rows[i] = row
    return row
end

local function FillBoard(note)
    local s = S()
    local board = Board()
    local chars = CK.Board(note)
    local lines = note.list.lines
    local open = OpenColor()
    for i, charKey in ipairs(chars) do
        local head = Head(board, i)
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", board.list, "TOPLEFT", NAME_W + (i - 1) * CELL_W, 0)
        head:SetText(CK.CharName(charKey))
        head:Show()
    end
    for i = #chars + 1, #s.heads do s.heads[i]:Hide() end
    local n = 0
    for r, line in ipairs(lines) do
        CK.LineState(note, line)
        local y = 18 + (r - 1) * ROW_H
        local row = Row(board, r)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", board.list, "TOPLEFT", 4, -y - 4)
        row:SetText(CK.LineLabel(line))
        row:SetTextColor(open[1], open[2], open[3], 1)
        row:Show()
        for c, charKey in ipairs(chars) do
            n = n + 1
            local cell = Cell(board, n)
            local done, progress = CK.BoardCell(note, line, charKey)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", board.list, "TOPLEFT", NAME_W + (c - 1) * CELL_W, -y)
            cell.tex:SetShown(done == true)
            cell.text:SetShown(done ~= true)
            cell.text:SetText(done == nil and "-" or (progress or ""))
            cell:Show()
        end
    end
    for i = #lines + 1, #s.rows do s.rows[i]:Hide() end
    for i = n + 1, #s.cells do s.cells[i]:Hide() end
    local h = 18 + #lines * ROW_H
    board.list:SetSize(mmax(1, NAME_W + #chars * CELL_W), mmax(1, h))
    local viewH = board.scroll:GetHeight() or 0
    if h > viewH + 1 then
        board.bar:Show()
        board.bar:UpdateThumb(h, viewH)
    else
        board.scroll:SetVerticalScroll(0)
        board.bar:Hide()
    end
    board:Show()
end

function Lines.ShowBoard(on)
    local s = S()
    s.boardShown = on and true or false
    local note = Note()
    if s.boardShown and note and CK.Is(note) and Frame() then
        FillBoard(note)
    elseif s.board then
        s.board:Hide()
    end
end

-- The editor view showing or not (the list of notes replaces it).
function Lines.ViewShown(shown)
    local s = S()
    if not shown then
        s.boardShown = false
        if s.board then s.board:Hide() end
        for _, tail in ipairs(s.tails) do tail:Hide() end
    end
end

-- A note drawn again: the board follows it while it shows.
function Lines.Refresh()
    local s = S()
    if s.boardShown then Lines.ShowBoard(true) end
end

-- Suggestions: in a list of items, the catalog's best names under the
-- line typed, the exact one picked. Tab or a click takes the pick, its
-- link and the count typed; Escape puts the names away.

local SUGGEST_MAX, SUGGEST_H = 6, 20

local function SuggestPanel()
    local s = S()
    if s.suggest then return s.suggest end
    local frame = Frame()
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetFrameLevel(frame:GetFrameLevel() + 60)
    ns.StyleMenuPanel(panel)
    panel.rows, panel.count = {}, 0
    panel:Hide()
    s.suggest = panel
    return panel
end

local function SuggestRow(panel, i)
    local row = panel.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, panel)
    row:SetHeight(SUGGEST_H)
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4 - (i - 1) * SUGGEST_H)
    row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4 - (i - 1) * SUGGEST_H)
    Utils.InstallMenuRowHighlight(row)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.name = Text(row, "GameFontHighlight")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row:SetScript("OnClick", function(self) Lines.TakePick(self.itemID) end)
    panel.rows[i] = row
    return row
end

function Lines.HideSuggest()
    local panel = S().suggest
    if panel then
        panel:Hide()
        panel.pick = nil
    end
end

function Lines.SetPick(i)
    local panel = S().suggest
    if not panel then return end
    panel.pick = i
    for k, row in ipairs(panel.rows) do row:SetMenuHighlightFocused(k == i) end
end

-- Up and Down move the pick while the names show, round the ends; the
-- caret stays where it was typed (the old checklist box did this, lost
-- in the 4.1.0 merge). The editor moves its caret after the key: the
-- cursor hook puts it back.
function Lines.StepPick(editor, key)
    local panel = S().suggest
    if not (panel and panel:IsShown() and (panel.count or 0) > 0) then return false end
    Lines.SetPick(((panel.pick or 0) + (key == "DOWN" and 1 or -1) - 1) % panel.count + 1)
    editor._efHoldCaret = editor:GetCursorPosition()
    Utils.SafeAfter(0, function() editor._efHoldCaret = nil end)
    return true
end

-- The box line the caret is on, its words, and the editor's text.
local function CaretLine(editor)
    local text = editor:GetText() or ""
    local caret = editor:GetCursorPosition() or 0
    for _, f in ipairs(CK.BodyLines(text)) do
        if caret >= f.contentStart - 1 and caret <= f.lineEnd then
            return f, text:sub(f.contentStart, f.lineEnd), text
        end
    end
end

function Lines.Suggest()
    local note, frame = Note(), Frame()
    local editor = frame and frame.editor
    if not (note and editor and editor:HasFocus() and CK.ItemsList(note)) then return Lines.HideSuggest() end
    local f, content = CaretLine(editor)
    local words = f and CK.SplitCount(content)
    if not words or words == "" or words:find("|", 1, true) then return Lines.HideSuggest() end
    local search, db = ns.ItemSearch, ns.Database
    if not (search and db and db.ScoreName) then
        -- The catalog loads on the first words typed, never sooner.
        if ns.RequestItemCatalog then ns.RequestItemCatalog() end
        return Lines.HideSuggest()
    end
    local want = slower(words)
    local hits = search:Search(want, function(n, ql, qLen) return db:ScoreName(n, ql, qLen) end)
    local n = mmin(hits and #hits or 0, SUGGEST_MAX)
    local tail
    for _, t in ipairs(S().tails) do
        if t:IsShown() and t.line and CK.LineStart(note, t.line.id) == f.start then tail = t end
    end
    if n == 0 or not tail then return Lines.HideSuggest() end
    local panel = SuggestPanel()
    local pick = 1
    for i = 1, n do
        local d = hits[i].data
        local row = SuggestRow(panel, i)
        row.itemID = d.itemID
        row.icon:SetTexture(C_Item.GetItemIconByID and C_Item.GetItemIconByID(d.itemID))
        row.name:SetText(C_Item.GetItemNameByID and C_Item.GetItemNameByID(d.itemID) or d.name)
        local q = d.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[d.quality]
        row.name:SetTextColor(q and q.r or 1, q and q.g or 1, q and q.b or 1, 1)
        row:Show()
        if d.nameLower == want and pick == 1 then pick = i end
    end
    for i = n + 1, #panel.rows do panel.rows[i]:Hide() end
    panel.count = n
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", editor, "TOPLEFT", -6, -(tail.lineY + tail.lineH + 2))
    panel:SetPoint("TOPRIGHT", editor, "TOPRIGHT", 6, -(tail.lineY + tail.lineH + 2))
    panel:SetHeight(8 + n * SUGGEST_H)
    panel:Show()
    Lines.SetPick(pick)
end

-- The pick into the line's words: its link, the count typed kept.
function Lines.TakePick(itemID)
    local panel = S().suggest
    local frame = Frame()
    local editor = frame and frame.editor
    if not itemID and panel and panel:IsShown() and panel.pick then
        local row = panel.rows[panel.pick]
        itemID = row and row.itemID
    end
    if not (itemID and editor) then return false end
    local f, content, text = CaretLine(editor)
    if not f then return false end
    local words = CK.PickedText(content, itemID)
    editor:SetText(text:sub(1, f.contentStart - 1) .. words .. text:sub(f.lineEnd + 1))
    editor:SetCursorPosition(f.contentStart - 1 + #words)
    editor:SetFocus()
    Lines.HideSuggest()
    return true
end

-- The editor of each window: typing shows the names, Tab takes the pick,
-- leaving hides them; Escape puts them away ahead of the menus.
function Lines.HookEditor(frame)
    local editor = frame and frame.editor
    if not editor or editor._efLinesHooked then return end
    editor._efLinesHooked = true
    editor:HookScript("OnTextChanged", function(_, userInput)
        if userInput then Utils.SafeAfter(0, W.Bound(Lines.Suggest)) else Lines.HideSuggest() end
    end)
    -- A key after a box was ticked: typing into its line, which opens.
    editor:HookScript("OnKeyDown", function(self)
        if self._efBoxLine then
            self._efBoxLine = nil
            NotesUI:QueueEasyNotesOverlayUpdate()
        end
    end)
    editor:HookScript("OnTabPressed", function() Lines.TakePick() end)
    editor:HookScript("OnCursorChanged", function(self)
        local hold = self._efHoldCaret
        if hold then
            self._efHoldCaret = nil
            if self:GetCursorPosition() ~= hold then self:SetCursorPosition(hold) end
        end
        -- The caret on another line: that one opens, the one left folds.
        local at = CaretLineStart(self, self:GetText() or "")
        if at ~= self._efFoldLine then
            self._efFoldLine = at
            NotesUI:QueueEasyNotesOverlayUpdate()
        end
    end)
    -- A click or drag held the folds back; its release lets them through.
    editor:HookScript("OnMouseUp", function() NotesUI:QueueEasyNotesOverlayUpdate() end)
    -- Ctrl+click on a line's words searches its item at an open auction
    -- house, as on its icon; it did nothing there (2026-11-03).
    editor:HookScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" or not IsControlKeyDown() or not AuctionOpen() then return end
        Utils.SafeAfter(0, W.Bound(function()
            local note = Note()
            local line = note and CK.LineAt(note, CaretLineStart(self, self:GetText() or ""))
            if line and (line.item or (line.text and not line.link)) then SearchAH(note, line) end
        end))
    end)
    editor:HookScript("OnEditFocusLost", function()
        -- A press on a name takes the focus first: the pick still lands.
        Utils.SafeAfter(0, W.Bound(function()
            local panel = S().suggest
            if panel and panel:IsShown() and not panel:IsMouseOver() then Lines.HideSuggest() end
        end))
    end)
end

local ensure = NotesUI.EnsureEasyNotesFrame
function NotesUI.EnsureEasyNotesFrame(self)
    local frame = ensure(self)
    Lines.HookEditor(frame)
    return frame
end

local closeMenus = NotesUI.CloseEasyNotesOpenMenus
function NotesUI.CloseEasyNotesOpenMenus(self)
    local panel = S().suggest
    if panel and panel:IsShown() then
        Lines.HideSuggest()
        return true
    end
    return closeMenus(self)
end

-- Shift-clicked items, quests and spells: into the editor at its caret
-- while it has the keyboard, else a line under the note's last in the
-- window used last, when that note has lines. The chat box comes first.
if Utils.HookInsertLink then Utils.HookInsertLink(function(link)
    local chat = (ChatFrameUtil and ChatFrameUtil.GetActiveWindow and ChatFrameUtil.GetActiveWindow())
        or (ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow())
    if chat then return end
    local w = W.Focused()
    local frame = w.frame
    if not (frame and frame:IsShown() and not w.paletteShown and frame.editor) then return end
    link = Utils.HexColorNames(link)
    W.Run(w, function()
        if frame.editor:HasFocus() then
            frame.editor:Insert(link)
            return
        end
        local note = Note()
        if note and CK.Is(note) then Lines.AddWords(note, link) end
    end)
end) end

-- The game's answers change: every window on a note with lines draws them again.
local EVENTS = { "BAG_UPDATE_DELAYED", "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "UPDATE_FACTION", "PLAYER_MONEY",
    "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED", "UPDATE_INSTANCE_INFO", "SPELL_UPDATE_COOLDOWN",
    "BAG_UPDATE_COOLDOWN", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "GET_ITEM_INFO_RECEIVED" }
local watcher = CreateFrame("Frame")
for _, e in ipairs(EVENTS) do watcher:RegisterEvent(e) end
watcher:SetScript("OnEvent", function()
    if Lines.queued or not W.AnyShown() then return end
    Lines.queued = true
    Utils.SafeAfter(0.3, function()
        Lines.queued = nil
        W.Each(function(w)
            local note = Note()
            if w.frame:IsShown() and not w.paletteShown and note and CK.Is(note) then
                NotesUI:QueueEasyNotesOverlayUpdate()
                Lines.Refresh()
            end
        end)
    end)
end)

-- Each character leaves what its linked lines read, for the board, and
-- schedules clear hand ticks even while no note is open.
function Lines.Sweep()
    local now = time()
    for _, note in ipairs(notesNS.AllNotes and notesNS.AllNotes() or {}) do
        if CK.Is(note) then
            CK.ApplyReset(note, now)
            for _, line in ipairs(note.list.lines) do
                if line.link then CK.LineState(note, line) end
            end
        end
    end
end

local sweeper = CreateFrame("Frame")
sweeper:RegisterEvent("PLAYER_LOGOUT")
sweeper:SetScript("OnEvent", Lines.Sweep)
Utils.SafeAfter(5, Lines.Sweep)

-- A theme change repaints the lines in its colors while they show.
if ns.RegisterThemeCallback then
    ns.RegisterThemeCallback(function()
        W.Each(function(w)
            if w.frame:IsShown() and not w.paletteShown then
                NotesUI:QueueEasyNotesOverlayUpdate()
                Lines.Refresh()
            end
        end)
    end)
end
