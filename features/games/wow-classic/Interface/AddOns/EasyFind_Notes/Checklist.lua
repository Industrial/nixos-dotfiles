local _, notesNS = ...
local ns = EasyFind and EasyFind._ns
if not (ns and notesNS.Context) then return end

-- A note's checkbox lines: ticked by hand, or linked to something the game
-- answers (an item count, a quest, a reputation, gold, a level, a skill, a
-- lockout, a cooldown). The words of a line are the note's text; what the
-- line is (its id, item, link, count) lives in note.list by its id, and a
-- "line" decoration over the box glyph carries the id through edits. Ticks
-- are account wide or kept per character, and may clear on a schedule.
local CK = {}
notesNS.Checklist = CK

local L = ns.L
local sformat, slower, sfind, smatch, mfloor, mmax = string.format, string.lower, string.find, string.match, math.floor, math.max
local ipairs, pairs, type, tonumber, tostring, time, date = ipairs, pairs, type, tonumber, tostring, time, date
local tremove = table.remove

-- The box glyphs at a line's start, as Notes.lua spells them: the open
-- box, and the ticked one of notes before ticks moved out of the words.
CK.EMPTY, CK.FILLED = "\226\150\161 ", "\226\150\163 "

local function Plain(v)
    return v ~= nil and not (issecretvalue and issecretvalue(v))
end

-- A folded line: its words and count in a link's hidden data (no "|" in
-- it), the label shown cut to fit; the edit box draws the label alone.
-- Lines.lua folds a list line the caret is not on and opens the one it is.
-- EasyFind's own link type (registered, ResultLinks), not a row link.
local FOLD = "|Heasyfind:fold:"
local UNESCAPE = { t = "~", p = "|" }

local function FoldAt(text, from)
    local at = sfind(text, FOLD, from, true)
    if not at then return nil end
    local dataEnd = sfind(text, "|h", at + #FOLD, true)
    local labelEnd = dataEnd and sfind(text, "|h", dataEnd + 2, true)
    if not labelEnd then return nil end
    local s, e = at, labelEnd + 1
    if at > 10 and smatch(text:sub(at - 10, at - 1), "^|c%x%x%x%x%x%x%x%x$") and text:sub(e + 1, e + 2) == "|r" then
        s, e = at - 10, e + 2
    end
    return s, e, (text:sub(at + #FOLD, dataEnd - 1):gsub("~([tp])", UNESCAPE))
end

function CK.Fold(raw, label, color)
    local link = FOLD .. raw:gsub("~", "~t"):gsub("|", "~p") .. "|h" .. label .. "|h"
    return color and (color .. link .. "|r") or link
end

-- The text with every folded line open.
function CK.Unfold(text)
    if not (text and sfind(text, FOLD, 1, true)) then return text end
    local out, pos = {}, 1
    while true do
        local s, e, raw = FoldAt(text, pos)
        if not s then break end
        out[#out + 1] = text:sub(pos, s - 1)
        out[#out + 1] = raw
        pos = e + 1
    end
    out[#out + 1] = text:sub(pos)
    return table.concat(out)
end

-- note.body's bytes s..e become repl: decorations past them move along,
-- any but a line's inside them go. The change in length.
function CK.ReplaceRange(note, s, e, repl)
    local body = note.body or ""
    local delta = #repl - (e - s + 1)
    note.body = body:sub(1, s - 1) .. repl .. body:sub(e + 1)
    local decos = note.decorations or {}
    for i = #decos, 1, -1 do
        local d = decos[i]
        if d.kind ~= "line" and d.startByte >= s and d.startByte <= e + 1 then
            tremove(decos, i)
        else
            if d.startByte > e then d.startByte = d.startByte + delta end
            if d.endByte > e + 1 then d.endByte = d.endByte + delta end
        end
    end
    return delta
end

-- The note as it reads with every folded line open, for what leaves the
-- editor (a copy, markdown, a share code); the note itself when none is.
function CK.Unfolded(note)
    local body = note and note.body
    if not (body and sfind(body, FOLD, 1, true)) then return note end
    local copy = { body = body, decorations = {} }
    for k, v in pairs(note) do if copy[k] == nil then copy[k] = v end end
    for i, d in ipairs(note.decorations or {}) do
        local c = {}
        for k, v in pairs(d) do c[k] = v end
        copy.decorations[i] = c
    end
    local spans, pos = {}, 1
    while true do
        local s, e, raw = FoldAt(body, pos)
        if not s then break end
        spans[#spans + 1] = { s, e, raw }
        pos = e + 1
    end
    for i = #spans, 1, -1 do CK.ReplaceRange(copy, spans[i][1], spans[i][2], spans[i][3]) end
    return copy
end

local function CharName(key)
    return smatch(key or "", "^([^%-]+)") or key or "?"
end
CK.CharName = CharName

-- Lists

function CK.Init(note)
    note.list = note.list or {}
    local list = note.list
    list.scope = list.scope or "account"
    list.reset = list.reset or { every = "never" }
    list.lines = list.lines or {}
    list.ticks = list.ticks or {}
    list.seen = list.seen or {}
    list.resetAt = list.resetAt or {}
    list.nextLine = list.nextLine or 1
    return list
end

-- A note with checkbox lines.
function CK.Is(note)
    return note ~= nil and type(note.list) == "table" and #note.list.lines > 0
end

-- A note that is a list: every line of it a checkbox line.
function CK.IsList(note)
    if not CK.Is(note) then return false end
    for line in (note.body or ""):gmatch("[^\n]+") do
        local head = line:sub(1, #CK.EMPTY)
        if head ~= CK.EMPTY and head ~= CK.FILLED then return false end
    end
    return true
end

-- Whose hand ticks a list keeps: "account" or a character key.
local function Holder(list, charKey)
    return list.scope == "character" and charKey or "account"
end

-- The body's checkbox lines in order: where each box starts, its words.
function CK.BodyLines(body)
    local found, pos = {}, 1
    body = body or ""
    while true do
        local nl = sfind(body, "\n", pos, true)
        local lineEnd = nl and nl - 1 or #body
        local head = body:sub(pos, pos + #CK.EMPTY - 1)
        if head == CK.EMPTY or head == CK.FILLED then
            found[#found + 1] = { start = pos, contentStart = pos + #CK.EMPTY, lineEnd = lineEnd }
        end
        if not nl then break end
        pos = nl + 1
    end
    return found
end

local function ItemName(id)
    return (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or ("item:" .. id)
end

-- A line's fields from its words. A line the game ticks (not an item)
-- keeps what it reads, the words rename it. Else a link in the words makes
-- it that item or quest, with a count written after it (a spell's link is
-- words: a cooldown is tracked on purpose); a plain name is the line's own
-- item while it reads as that item's name, or, in a list of items once
-- the typing settles, the item it names; the rest is text, with its count
-- in a list of items. True when a field changed.
local READ = { "text", "item", "link", "target", "quest", "spell" }
function CK.ReadContent(line, content, items, settle)
    content = CK.Unfold(content)
    local words, count = CK.SplitCount(content)
    local new
    local fromLink = CK.LineFromLink(words)
    if fromLink and fromLink.link == "cooldown" then fromLink = nil end
    if line.link and line.link ~= "item" and not fromLink then
        new = { text = content ~= "" and content or nil }
        for _, k in ipairs(READ) do
            if k ~= "text" then new[k] = line[k] end
        end
    elseif fromLink and fromLink.item then
        -- A count is a shopping list's, ticked from the bags; a checklist
        -- (a reminder, a list for someone) keeps it as words (2026-11-03).
        new = { item = fromLink.item, link = (items and count) and "item" or nil, target = items and count or nil }
    elseif fromLink then
        new = fromLink
    else
        if line.item and slower(words) == slower(ItemName(line.item)) then
            new = { item = line.item, link = (items and count) and "item" or nil, target = items and count or nil }
        elseif items and settle then
            -- A name ending in a number ("Net-o-Matic 5000") is the item.
            local whole = CK.ItemByName(content)
            local id = whole or CK.ItemByName(words)
            if whole then new = { item = whole }
            elseif id then new = { item = id, link = count and "item" or nil, target = count } end
        end
        if not new then
            if items and count then new = { text = words, target = count }
            else new = { text = content ~= "" and content or nil } end
        end
    end
    local changed = false
    for _, k in ipairs(READ) do
        if line[k] ~= new[k] then line[k], changed = new[k], true end
    end
    return changed
end

-- The list brought in step with the body: each checkbox line keeps the id
-- its "line" decoration carries, a new one gets the next; the lines read
-- their words; a line gone takes its ticks. True when anything changed.
function CK.Reconcile(note, settle)
    local found = CK.BodyLines(note.body)
    if #found == 0 and not (note.list and #note.list.lines > 0) then return false end
    local list = CK.Init(note)
    local decos = note.decorations
    local idAt = {}
    for i = 1, #(decos or {}) do
        local d = decos[i]
        if d.kind == "line" then idAt[d.startByte] = d end
    end
    local byId = {}
    for _, line in ipairs(list.lines) do
        if line.id then byId[line.id] = line end
    end
    local items = CK.ItemsList(note)
    local out, kept, changed = {}, {}, false
    for _, f in ipairs(found) do
        local d = idAt[f.start]
        if not d then
            note.decorations = note.decorations or {}
            decos = note.decorations
            d = { kind = "line", startByte = f.start, endByte = f.start + #CK.EMPTY - 1 }
            decos[#decos + 1] = d
        end
        -- A mark an undo brought back without its id (2026-11-02) takes a new one.
        if not d.id then
            d.id = list.nextLine
            list.nextLine = list.nextLine + 1
            changed = true
        end
        kept[d] = true
        local line = byId[d.id]
        if line then byId[d.id] = nil else line, changed = { id = d.id }, true end
        if CK.ReadContent(line, (note.body or ""):sub(f.contentStart, f.lineEnd), items, settle) then changed = true end
        out[#out + 1] = line
    end
    -- A box no longer at a line's start: its mark goes.
    for i = #(decos or {}), 1, -1 do
        if decos[i].kind == "line" and not kept[decos[i]] then tremove(decos, i) end
    end
    for id in pairs(byId) do
        for _, ticks in pairs(list.ticks) do ticks[id] = nil end
        for _, seen in pairs(list.seen) do seen[id] = nil end
        changed = true
    end
    if #out ~= #list.lines then changed = true end
    list.lines = out
    return changed
end

-- The line whose box starts at startByte, by its decoration.
function CK.LineAt(note, startByte)
    local decos, list = note.decorations, note.list
    if not (decos and list) then return nil end
    for i = 1, #decos do
        local d = decos[i]
        if d.kind == "line" and d.startByte == startByte then
            if not d.id then return nil end
            for _, line in ipairs(list.lines) do
                if line.id == d.id then return line end
            end
            return nil
        end
    end
end

-- Where line id's box starts in the body.
function CK.LineStart(note, id)
    for _, d in ipairs(note.decorations or {}) do
        if d.kind == "line" and d.id == id then return d.startByte end
    end
end

-- The body as the lines alone, one a line, each marked with its id.
local function WriteLines(note, lines)
    local parts, decos, pos = {}, {}, 1
    for i, line in ipairs(lines) do
        local text = CK.EMPTY .. CK.EditText(line)
        parts[i] = text
        decos[#decos + 1] = { kind = "line", id = line.id, startByte = pos, endByte = pos + #CK.EMPTY - 1 }
        pos = pos + #text + 1
    end
    note.body = table.concat(parts, "\n")
    note.decorations = decos
    note.list.lines = lines
    note.updated = time()
end

-- A line under the note's last, with the fields given.
function CK.AppendLine(note, line)
    local body = note.body or ""
    if body ~= "" and body:sub(-1) ~= "\n" then body = body .. "\n" end
    local start = #body + 1
    note.body = body .. CK.EMPTY .. CK.EditText(line)
    note.updated = time()
    CK.Reconcile(note)
    local made = CK.LineAt(note, start)
    for k, v in pairs(line) do
        if made and k ~= "id" then made[k] = v end
    end
    return made
end

-- An extension's list into the note linked to it (list.source, by
-- EasyFind.API.LinkedChecklist): entries in its order, each { ref, line }.
-- A line holding an entry's ref keeps its id and ticks and takes the
-- entry's fields; a new ref is a new line; a ref gone takes its line.
-- Lines with no ref (typed here, not in the list yet) stay, after the
-- rest. The body is then the lines. True when anything changed.
local SYNCED = { "item", "link", "target", "text" }
function CK.SyncLinked(note, entries)
    local list = CK.Init(note)
    CK.Reconcile(note)
    local byRef, pending, changed = {}, {}, false
    for _, line in ipairs(list.lines) do
        if line.ref and not byRef[line.ref] then byRef[line.ref] = line
        elseif not line.ref then pending[#pending + 1] = line end
    end
    local out = {}
    for _, e in ipairs(entries) do
        local line = byRef[e.ref]
        if line then
            byRef[e.ref] = nil
        else
            line = { ref = e.ref, id = list.nextLine }
            list.nextLine = list.nextLine + 1
            changed = true
        end
        for _, k in ipairs(SYNCED) do
            if line[k] ~= e.line[k] then line[k], changed = e.line[k], true end
        end
        out[#out + 1] = line
    end
    for _, line in ipairs(pending) do out[#out + 1] = line end
    for _, gone in pairs(byRef) do
        for _, ticks in pairs(list.ticks) do ticks[gone.id] = nil end
        for _, seen in pairs(list.seen) do seen[gone.id] = nil end
    end
    if #out ~= #list.lines then changed = true end
    for i = 1, #out do
        if out[i] ~= list.lines[i] then changed = true end
    end
    if changed then WriteLines(note, out) end
    return changed
end

-- A note of the old checklist kind becomes its lines as text; a ticked box
-- in the words (the old tick) opens, its tick kept on the list for whoever
-- keeps them. True when the note changed.
function CK.Migrate(note, charKey)
    if note.kind == "checklist" and type(note.list) == "table" then
        CK.Init(note)
        WriteLines(note, note.list.lines)
        note.kind = nil
        return true
    end
    local body = note.body or ""
    if not sfind(body, CK.FILLED, 1, true) then return false end
    local filled, pos = {}, 1
    while true do
        local s = sfind(body, CK.FILLED, pos, true)
        if not s then break end
        if s == 1 or body:sub(s - 1, s - 1) == "\n" then filled[#filled + 1] = s end
        pos = s + 1
    end
    -- The same bytes long: nothing else moves.
    note.body = body:gsub(CK.FILLED, CK.EMPTY)
    local decos = note.decorations or {}
    for i = #decos, 1, -1 do
        local d = decos[i]
        if d.kind == "strike" then
            for _, s in ipairs(filled) do
                if d.startByte == s + #CK.EMPTY then tremove(decos, i) break end
            end
        end
    end
    CK.Reconcile(note)
    local list = CK.Init(note)
    for _, s in ipairs(filled) do
        local line = CK.LineAt(note, s)
        if line then
            local key = Holder(list, charKey)
            list.ticks[key] = list.ticks[key] or {}
            list.ticks[key][line.id] = true
        end
    end
    return true
end

function CK.Ticked(note, line, charKey)
    local ticks = note.list.ticks[Holder(note.list, charKey)]
    return ticks and ticks[line.id] == true
end

function CK.SetTicked(note, line, charKey, on)
    local list = note.list
    local key = Holder(list, charKey)
    list.ticks[key] = list.ticks[key] or {}
    list.ticks[key][line.id] = on or nil
    note.updated = time()
end

-- Game links: each answers done, a progress text and a detail line.

local function Span(sec)
    sec = mmax(0, mfloor(sec))
    if sec >= 3600 then return sformat("%dh %dm", mfloor(sec / 3600), mfloor(sec % 3600 / 60)) end
    return sformat("%dm", mmax(1, mfloor(sec / 60)))
end

local function Gold(copper)
    return sformat("%dg", mfloor((copper or 0) / 10000))
end

local LINKS = {}
CK.LINKS = LINKS

LINKS.item = {
    label = L["CHECK_LINK_ITEM"],
    Name = function(line) return ItemName(line.item) end,
    State = function(line, ctx)
        local get = C_Item and C_Item.GetItemCount
        if not get then return false, "" end
        local bags = get(line.item) or 0
        local bank = mmax(0, (get(line.item, true) or bags) - bags)
        local total = bags + bank
        local parts = {}
        if bags > 0 then parts[#parts + 1] = sformat(L["CHECK_BAGS_FMT"], bags) end
        if bank > 0 then parts[#parts + 1] = sformat(L["CHECK_BANK_FMT"], bank) end
        if ctx.account and ns.StoredItemCounts then
            for charKey, c in pairs(ns.StoredItemCounts(line.item) or {}) do
                if charKey ~= ctx.char then
                    local n = (c.bags or 0) + (c.bank or 0)
                    if n > 0 then
                        total = total + n
                        parts[#parts + 1] = sformat("%s %d", CharName(charKey), n)
                    end
                end
            end
        end
        local target = line.target or 1
        return total >= target, sformat("%d/%d", total, target), table.concat(parts, ", "), total, target
    end,
}

LINKS.quest = {
    label = L["CHECK_LINK_QUEST"],
    Name = function(line)
        local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(line.quest)
        return title or line.text or ("quest:" .. line.quest)
    end,
    State = function(line)
        local QL = C_QuestLog
        if not QL then return false, "" end
        if QL.IsQuestFlaggedCompleted and QL.IsQuestFlaggedCompleted(line.quest) then
            return true, L["CHECK_DONE"]
        end
        if QL.GetLogIndexForQuestID and QL.GetLogIndexForQuestID(line.quest) then
            local have, need = 0, 0
            for _, o in ipairs(QL.GetQuestObjectives and QL.GetQuestObjectives(line.quest) or {}) do
                if Plain(o.numFulfilled) and Plain(o.numRequired) then
                    have, need = have + o.numFulfilled, need + o.numRequired
                end
            end
            if need > 0 then return false, sformat("%d/%d", have, need), L["CHECK_IN_LOG"] end
            return false, L["CHECK_IN_LOG"]
        end
        return false, L["CHECK_NOT_STARTED"]
    end,
}

local function Standing(factionID)
    local data = ns.Caps.FactionByID(factionID)
    return data and data.name, data and data.reaction
end

local function StandingLabel(n)
    return _G["FACTION_STANDING_LABEL" .. tostring(n)] or tostring(n)
end
CK.StandingLabel = StandingLabel

LINKS.rep = {
    label = L["CHECK_LINK_REP"],
    Name = function(line) return (Standing(line.faction)) or line.text or ("faction:" .. line.faction) end,
    State = function(line)
        local _, now = Standing(line.faction)
        if not Plain(now) then return false, "" end
        local want = line.standing or 8
        return now >= want, sformat("%s/%s", StandingLabel(now), StandingLabel(want))
    end,
}

LINKS.gold = {
    label = L["CHECK_LINK_GOLD"],
    Name = function(line) return line.text or L["CHECK_LINK_GOLD"] end,
    State = function(line, ctx)
        local have = GetMoney and GetMoney() or 0
        if ctx.account then
            local ledger = type(EasyFindDB) == "table" and type(EasyFindDB.charGold) == "table" and EasyFindDB.charGold
            for charKey, copper in pairs(ledger or {}) do
                if charKey ~= ctx.char and type(copper) == "number" then have = have + copper end
            end
        end
        local want = line.target or 0
        return have >= want, sformat("%s/%s", Gold(have), Gold(want)), nil, have, want
    end,
}

LINKS.level = {
    label = L["CHECK_LINK_LEVEL"],
    Name = function(line) return line.text or sformat(L["CHECK_LEVEL_FMT"], line.target or 0) end,
    State = function(line)
        local have, want = UnitLevel("player") or 0, line.target or 0
        return have >= want, sformat("%d/%d", have, want)
    end,
}

-- A profession by name: its skill against the target.
local function SkillLevel(name)
    if not (GetProfessions and GetProfessionInfo) then return nil end
    local want = slower(name or "")
    for _, prof in ipairs({ GetProfessions() }) do
        if prof then
            local pname, _, level = GetProfessionInfo(prof)
            if pname and slower(pname) == want then return level end
        end
    end
end

LINKS.skill = {
    label = L["CHECK_LINK_SKILL"],
    Name = function(line) return line.skill or "?" end,
    State = function(line)
        local have = SkillLevel(line.skill)
        if not have then return false, L["CHECK_NOT_LEARNED"] end
        local want = line.target or 1
        return have >= want, sformat("%d/%d", have, want)
    end,
}

LINKS.lockout = {
    label = L["CHECK_LINK_LOCKOUT"],
    Name = function(line) return line.instance or "?" end,
    State = function(line)
        if not (GetNumSavedInstances and GetSavedInstanceInfo) then return false, "" end
        local want = slower(line.instance or "")
        for i = 1, GetNumSavedInstances() do
            local name, _, reset, _, locked, _, _, _, _, diff, numBosses, killed = GetSavedInstanceInfo(i)
            if Plain(name) and locked and reset and reset > 0 and sfind(slower(name), want, 1, true) then
                local cleared = Plain(killed) and Plain(numBosses) and numBosses > 0 and killed >= numBosses
                return cleared, sformat("%d/%d", killed or 0, numBosses or 0), diff
            end
        end
        return false, L["CHECK_NOT_SAVED"]
    end,
}

-- A cooldown in use reads as done: "Mooncloth made today".
LINKS.cooldown = {
    label = L["CHECK_LINK_COOLDOWN"],
    Name = function(line)
        if line.item then return ItemName(line.item) end
        return (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(line.spell)) or ("spell:" .. tostring(line.spell))
    end,
    State = function(line, ctx)
        local start, dur
        if line.item then
            local f = (C_Container and C_Container.GetItemCooldown) or (C_Item and C_Item.GetItemCooldown)
            if f then start, dur = f(line.item) end
        else
            local info = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(line.spell)
            if type(info) == "table" then start, dur = info.startTime, info.duration end
        end
        if not (Plain(start) and Plain(dur)) then return false, "" end
        if dur <= 1.5 then return false, L["CHECK_READY"] end
        local left = start + dur - ctx.gnow
        return true, sformat(L["CHECK_READY_IN_FMT"], Span(left))
    end,
}

CK.LINK_ORDER = { "item", "quest", "rep", "gold", "level", "skill", "lockout", "cooldown" }

local ctx = {}
local function Ctx(note)
    ctx.char = ns.CurrentCharacterKey()
    ctx.account = note.list.scope ~= "character"
    ctx.gnow = GetTime()
    return ctx
end

-- done, progress, detail for a line on this character; a linked line also
-- leaves what it read for the alts board.
function CK.LineState(note, line)
    local c = Ctx(note)
    local link = line.link and LINKS[line.link]
    -- An item's count ticks only in a shopping list; elsewhere the hand does.
    local items = CK.ItemsList(note)
    if line.link == "item" and not items then link = nil end
    if not link then
        return CK.Ticked(note, line, c.char), (items and line.target) and sformat(L["CHECK_COUNT_FMT"], line.target) or nil, nil
    end
    local done, progress, detail, have, need = link.State(line, c)
    local seen = note.list.seen
    seen[c.char] = seen[c.char] or {}
    seen[c.char][line.id] = { d = done and true or nil, p = progress, t = time() }
    return done, progress, detail, have, need
end

-- How many of a line's item are left to buy: its count less what is had,
-- one for a line with no count, none once it is done; nil for no item.
function CK.ItemsLeft(note, line)
    if not line.item then return nil end
    local done, _, _, have, need = CK.LineState(note, line)
    if done then return 0 end
    if need and have then return mmax(0, need - have) end
    return 1
end

function CK.LineName(line)
    if line.text and line.text ~= "" then return line.text end
    if line.item and not line.link then return ItemName(line.item) end
    local link = line.link and LINKS[line.link]
    return link and link.Name(line) or ""
end

-- The name as drawn: an item or spell as its game link, colored, in brackets.
function CK.LineLabel(line)
    if line.text and line.text ~= "" then return line.text end
    local link
    if line.item then
        link = C_Item and C_Item.GetItemInfo and select(2, C_Item.GetItemInfo(line.item))
    elseif line.link == "cooldown" and line.spell then
        link = C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(line.spell)
    end
    return link and ns.Utils.HexColorNames(link) or CK.LineName(line)
end

-- How many lines are done on this character.
function CK.Progress(note)
    local done, total = 0, #note.list.lines
    for _, line in ipairs(note.list.lines) do
        if CK.LineState(note, line) then done = done + 1 end
    end
    return done, total
end

-- The alts board: what each character last had for each line.
function CK.Board(note)
    local list = note.list
    local chars = {}
    for charKey in pairs(list.seen) do chars[charKey] = true end
    for charKey in pairs(list.ticks) do
        if charKey ~= "account" then chars[charKey] = true end
    end
    chars[ns.CurrentCharacterKey()] = true
    local out = {}
    for charKey in pairs(chars) do out[#out + 1] = charKey end
    table.sort(out)
    return out
end

function CK.BoardCell(note, line, charKey)
    if line.link then
        local s = note.list.seen[charKey]
        s = s and s[line.id]
        if not s then return nil end
        return s.d == true, s.p
    end
    local ticks = note.list.ticks[charKey]
    return ticks and ticks[line.id] == true or false, nil
end

-- Resets: the last moment the list's schedule passed, or nil for never.

local WEEKDAY = { [1] = 3, [2] = 5, [3] = 4, [4] = 5, [5] = 5 }

-- The game's daily reset that last went by (a moment in time).
local function LastDaily(now)
    local left = GetQuestResetTime and GetQuestResetTime()
    if not (Plain(left) and left and left > 0) then return nil end
    return now + left - 86400
end

-- The region's weekly reset: the last daily reset on its weekday (UTC).
local function LastWeekly(now)
    local daily = LastDaily(now)
    if not daily then return nil end
    local want = WEEKDAY[GetCurrentRegion and GetCurrentRegion() or 1] or 3
    for back = 0, 6 do
        local t = daily - back * 86400
        if date("!*t", t).wday == want then return t end
    end
end

-- Chosen weekdays (1 Sunday ... 7 Saturday) at a local time of day.
local function LastChosen(now, reset)
    local hour, min = reset.hour or 0, reset.min or 0
    local days = reset.days or {}
    for back = 0, 7 do
        local t = date("*t", now - back * 86400)
        t.hour, t.min, t.sec = hour, min, 0
        local at = time(t)
        if days[t.wday] and at <= now then return at end
    end
end

function CK.LastReset(reset, now)
    local every = reset and reset.every
    if every == "daily" then return LastDaily(now) end
    if every == "weekly" then return LastWeekly(now) end
    if every == "days" then return LastChosen(now, reset) end
    return nil
end

-- Clears hand ticks a schedule has passed since they were last cleared.
function CK.ApplyReset(note, now)
    local list = note.list
    local last = CK.LastReset(list.reset, now)
    if not last then return false end
    local cleared = false
    for holder, ticks in pairs(list.ticks) do
        local was = list.resetAt[holder] or 0
        if was < last then
            if next(ticks) then cleared = true end
            list.ticks[holder] = {}
            list.resetAt[holder] = now
        end
    end
    return cleared
end

function CK.Preview(note)
    local done, total = CK.Progress(note)
    return sformat(L["CHECK_PREVIEW_FMT"], done, total)
end

-- A line from a pasted or shift-clicked link: item, quest or spell. An
-- item is one to tick by hand (it came from the bags it would count);
-- Track counts one.
function CK.LineFromLink(link)
    local item = tonumber(smatch(link or "", "|Hitem:(%d+)"))
    if item then return { item = item } end
    local quest = tonumber(smatch(link or "", "|Hquest:(%d+)"))
    if quest then return { link = "quest", quest = quest } end
    local spell = tonumber(smatch(link or "", "|Hspell:(%d+)"))
    if spell then return { link = "cooldown", spell = spell } end
end

-- A list of items (a shopping list): a name typed in it is looked up, and
-- keeps a count written with it. The player made it one (list.shopping),
-- or an extension keeps it as a list of items.
function CK.ItemsList(note)
    local list = note and type(note.list) == "table" and note.list
    if not list then return false end
    if list.shopping then return true end
    local link = list.source and ns.ChecklistLinks and ns.ChecklistLinks[list.source.ext]
    return link ~= nil and link.items == true
end

-- A checklist with an item on it, linked or typed by name ("linen cloth"
-- stays words in a checklist): it offers to become a shopping list, until
-- the player says no for that note (list.shopDeclined). A name's answer is
-- kept: the catalog lookup is too slow for every repaint (2026-11-03).
local namedItems, namedCount = {}, 0
function CK.OffersShopping(note)
    if not CK.Is(note) or CK.ItemsList(note) or note.list.shopDeclined then return false end
    -- "Never show again" on the offer, or off in Notes' settings.
    local db = EasyFind and EasyFind.db
    if db and db.notesShopOffer == false then return false end
    for _, line in ipairs(note.list.lines) do
        if line.item then return true end
        local words = line.text and CK.SplitCount(line.text)
        if words and #words >= 3 then
            local id = namedItems[words]
            if id == nil then
                if namedCount >= 500 then namedItems, namedCount = {}, 0 end
                id = CK.ItemByName(words) or false
                namedItems[words], namedCount = id, namedCount + 1
            end
            if id then return true end
        end
    end
    return false
end

-- A count written with the words: "Linen Cloak x20", "x 20", "*20", "* 20",
-- " 20", "20x Linen Cloak", "20 Linen Cloak". The words, and the count or nil.
local COUNT_AFTER = { "^(.-)%s+[xX%*]%s*(%d+)$", "^(.-|[hr])%s*[xX%*]%s*(%d+)$", "^(.-)%*%s*(%d+)$", "^(.-)%s+(%d+)$" }
local COUNT_BEFORE = { "^(%d+)%s*[xX%*]%s+(.+)$", "^(%d+)%s*%*%s*(.+)$", "^(%d+)%s*[xX]%s*(|.+)$", "^(%d+)%s+(.+)$" }

local function Trim(s) return smatch(s, "^%s*(.-)%s*$") end

function CK.SplitCount(text)
    text = Trim((text or ""):gsub("\195\151", "x"))
    for _, p in ipairs(COUNT_AFTER) do
        local words, n = smatch(text, p)
        n = tonumber(n)
        if words and Trim(words) ~= "" and n and n > 0 then return Trim(words), n end
    end
    for _, p in ipairs(COUNT_BEFORE) do
        local n, words = smatch(text, p)
        n = tonumber(n)
        if words and n and n > 0 then return Trim(words), n end
    end
    return text, nil
end

-- The item a typed name stands for: the client's lookup, else that exact
-- name in the item catalog.
function CK.ItemByName(name)
    if not name or name == "" or sfind(name, "|", 1, true) then return nil end
    local id = C_Item and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(name)
    if id then return id end
    local search, db = ns.ItemSearch, ns.Database
    if not (search and db and db.ScoreName) then return nil end
    local want = slower(name)
    local hits = search:Search(want, function(n, ql, qLen) return db:ScoreName(n, ql, qLen) end)
    for i = 1, hits and #hits or 0 do
        if hits[i].data.nameLower == want then return hits[i].data.itemID end
    end
end

-- A line's words as typed in the body, its count off and a link as its
-- name in brackets: what an item is called before the client has its name.
function CK.LineWords(note, line)
    for _, d in ipairs(note.decorations or {}) do
        if d.kind == "line" and d.id == line.id then
            local body = note.body or ""
            local stop = sfind(body, "\n", d.startByte, true)
            local words = CK.SplitCount(CK.Unfold(body:sub(d.startByte + #CK.EMPTY, (stop or #body + 1) - 1)))
            words = smatch(words, "|h%[(.-)%]|h") or words
            return words ~= "" and words or nil
        end
    end
end

-- The words a line is typed as: its own, or its item or spell as a link,
-- and its count after.
function CK.EditText(line)
    local words = CK.LineLabel(line)
    local count = (line.link == "item" or not line.link) and line.target
    return count and sformat("%s x%d", words, count) or words
end

-- A line with a count of its own to change: an item's, or a name's in a
-- list of items.
function CK.HasCount(line)
    return line.target ~= nil and (line.link == "item" or not line.link)
end

-- n above 0 the line's count; else it has none (an item is ticked by hand).
function CK.SetCount(line, n)
    if n and n > 0 then
        line.target = mfloor(n)
        if line.item then line.link = "item" end
    else
        line.target = nil
        if line.link == "item" then line.link = nil end
    end
end

-- The words of a line picked from the suggestions: the item's link, the
-- count typed kept.
function CK.PickedText(text, pick)
    local _, count = CK.SplitCount(text)
    return CK.EditText({ item = pick, link = count and "item" or nil, target = count })
end
