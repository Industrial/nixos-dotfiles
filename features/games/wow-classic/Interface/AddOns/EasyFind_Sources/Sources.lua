

local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns then return end


if ns.BUILD ~= "5.5.0" then select(2, ...).stale = true return end






local SourceData = {}

local Utils = ns.Utils
local L = ns.L
local ipairs, pairs, type, tonumber = Utils.ipairs, Utils.pairs, Utils.type, Utils.tonumber
local sformat, tsort = Utils.sformat, Utils.tsort
local C_Map = C_Map

local NONE = {}

local PROFESSION_SPELLS = {
    [164] = 2018, [165] = 2108, [171] = 2259, [182] = 2366, [186] = 2575, [197] = 3908, [202] = 4036,
    [333] = 7411, [393] = 8613, [755] = 25229, [129] = 3273, [185] = 2550, [356] = 7620, [773] = 45357,
}
local KIND_ICONS = {
    herb = "Interface\\Icons\\Trade_Herbalism", ore = "Interface\\Icons\\Trade_Mining",
    fish = "Interface\\Icons\\Trade_Fishing", chest = "Interface\\Icons\\INV_Box_01",
}
local KIND_SKILL = { herb = 182, ore = 186, fish = 356 }
local QUEST_ICON = "Interface\\GossipFrame\\AvailableQuestIcon"
local WORLD_DROP_ICON = "Interface\\Icons\\INV_Misc_Bag_08"

local D

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id)) or nil
end

local function SpellIcon(id)
    return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id) or nil
end




local function List(s)
    local out = {}
    local body, more = s:match("^(.-)%+(%d+)$")
    if body then
        s = body
        out.more = tonumber(more)
    end
    for id, p in s:gmatch("(%d+):?([%d%.]*)") do out[#out + 1] = { tonumber(id), p ~= "" and p or nil } end
    return out
end

local records = setmetatable({}, { __mode = "v" })

local function Record(itemID)
    local rec = records[itemID]
    if rec then return rec end
    local s = D.items[itemID]
    if not s then return nil end
    rec = {}
    for part in s:gmatch("[^;]+") do
        local code, body = part:sub(1, 1), part:sub(2)
        if code == "w" then
            local lo, hi = body:match("(%d+)%-(%d+)")
            rec.w = { tonumber(lo), tonumber(hi) }
        elseif code == "x" or code == "t" then
            rec[code] = tonumber(body)
        else
            rec[code] = List(body)
        end
    end
    records[itemID] = rec
    return rec
end

local recipes = setmetatable({}, { __mode = "v" })

local function Recipe(spell)
    local r = recipes[spell]
    if r then return r end
    local s = D.recipes[spell]
    if not s then return nil end
    local head, reag, trainers, books = s:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
    local skill, rank, out, count, auto = head:match("(%d+),(%d+),(%d+),(%d+),(%d)")
    r = { spell = spell, skill = tonumber(skill), rank = tonumber(rank), out = tonumber(out), count = tonumber(count),
          auto = auto == "1", reagents = {}, trainers = {}, books = {} }
    for id, n in reag:gmatch("(%d+):(%d+)") do r.reagents[#r.reagents + 1] = { tonumber(id), tonumber(n) } end
    for id in trainers:gmatch("%d+") do r.trainers[#r.trainers + 1] = tonumber(id) end
    for id in books:gmatch("%d+") do r.books[#r.books + 1] = tonumber(id) end
    recipes[spell] = r
    return r
end


local usedIn
local function UsedIn(itemID)
    if not usedIn then
        usedIn = {}
        for spell, s in pairs(D.recipes) do
            local reag = s:match("^[^|]*|([^|]*)")
            for id in reag:gmatch("(%d+):%d+") do
                id = tonumber(id)
                local list = usedIn[id]
                if not list then
                    list = {}
                    usedIn[id] = list
                end
                list[#list + 1] = spell
            end
        end
    end
    return usedIn[itemID]
end

local function Object(k)
    local s = D.objects[k]
    if not s then return nil end
    local name, kind, spots = s:match("^(.-)|(%a+)|(.*)$")
    local list = {}
    for m, x, y in spots:gmatch("(%d+):(%d+):(%d+)") do
        list[#list + 1] = tonumber(m)
        list[#list + 1] = tonumber(x) / 1000
        list[#list + 1] = tonumber(y) / 1000
    end
    return { key = k, name = name, kind = kind, spots = list }
end

local function Side()
    local faction = UnitFactionGroup("player")
    return faction == "Horde" and "H" or faction == "Alliance" and "A" or nil
end



local function Quest(q)
    local s = D.quests[q]
    if not s then return nil end
    local title, level, side, giver = s:match("^(.-)|(%-?%d*)|(%a?)|(.*)$")
    if not title or (side ~= "" and side ~= Side()) then return nil end
    local live = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(q)
    if type(live) == "string" and live ~= "" then title = live end
    return { id = q, title = title, level = tonumber(level), giverKind = giver:sub(1, 1), giver = tonumber(giver:sub(2)) }
end



local professions = {}
local function Profession(skill)
    local name = professions[skill]
    if name == nil then
        local spell = PROFESSION_SPELLS[skill]
        local display = C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName
        name = display and display(skill)
        if type(name) ~= "string" or name == "" then name = spell and SpellName(spell) or false end
        professions[skill] = name
    end
    return name or nil
end

local function RecipeSkill(r)
    local name = Profession(r.skill) or ""
    if r.rank and r.rank > 1 then return sformat("%s %d", name, r.rank) end
    return name
end

local function CreatureName(id)
    local Npcs = ns.Npcs
    return Npcs and Npcs.NameOfID and Npcs.NameOfID(id) or D.npcs[id]
end

local function ZoneName(m)
    local info = C_Map.GetMapInfo(m)
    return info and info.name or nil
end


local function Pct(p, drop)
    return p and sformat(L[drop and "SOURCES_DROP_CHANCE_FMT" or "SOURCES_CHANCE_FMT"], p) or nil
end

local function Join(a, b)
    if a and b then return a .. ", " .. b end
    return a or b
end






local function CreatureRows(list, rows, drop)
    for _, e in ipairs(list or NONE) do
        rows[#rows + 1] = { creature = e[1], name = D.npcs[e[1]], note = Pct(e[2], drop) or "" }
    end
end

local function QuestRow(q, note)
    local quest = Quest(q)
    if not quest then return nil end
    local level = quest.level and quest.level > 0 and sformat(L["SOURCES_LEVEL_FMT"], quest.level) or nil
    if quest.giverKind == "c" and quest.giver then
        local from = sformat(L["SOURCES_FROM_FMT"], CreatureName(quest.giver) or "")
        return { creature = quest.giver, name = quest.title, label = quest.title, note = Join(Join(note, from), level) }
    end
    if quest.giverKind == "o" and quest.giver then
        local o = Object(quest.giver)
        if o and #o.spots > 0 then
            return { spots = o.spots, name = quest.title, kind = "treasure", icon = QUEST_ICON,
                     note = Join(Join(note, sformat(L["SOURCES_FROM_FMT"], o.name)), level) }
        end
    end
    if quest.giverKind == "i" then note = Join(note, L["SOURCES_ITEM_STARTED"]) end
    return { name = quest.title, icon = QUEST_ICON, note = Join(note, level) or "" }
end

local function QuestRows(list, rows)
    for _, e in ipairs(list or NONE) do
        local row = QuestRow(e[1])
        if row then rows[#rows + 1] = row end
    end
end

local function ObjectRow(e)
    local o = Object(e[1])
    if not o then return nil end
    local row = { name = o.name, icon = KIND_ICONS[o.kind], note = Pct(e[2]) or "" }
    if #o.spots > 0 then
        row.spots, row.kind = o.spots, "treasure"
        local skill = KIND_SKILL[o.kind]
        if skill and Profession(skill) then row.note = Join(Profession(skill), Pct(e[2])) end
    end
    return row, o.kind
end

local function RecipeRows(r)
    local rows = {}
    for _, g in ipairs(r.reagents) do rows[#rows + 1] = { item = g[1], note = sformat(L["SOURCES_NEEDS_FMT"], g[2]) } end
    for _, t in ipairs(r.trainers) do rows[#rows + 1] = { creature = t, name = D.npcs[t], note = L["SOURCES_TEACHES_RECIPE"] } end
    for _, b in ipairs(r.books) do rows[#rows + 1] = { item = b, note = L["SOURCES_TEACHES_RECIPE"] } end
    if r.auto and #r.trainers == 0 then
        rows[#rows + 1] = { name = SpellName(r.spell) or "", icon = SpellIcon(r.spell), note = L["SOURCES_LEARNED"] }
    end
    if #rows == 0 then rows[1] = { name = SpellName(r.spell) or "", icon = SpellIcon(r.spell), note = RecipeSkill(r) } end
    return rows
end

local function RankLess(a, b)
    local ra, rb = Recipe(a), Recipe(b)
    if ra.rank ~= rb.rank then return ra.rank < rb.rank end
    return a < b
end

local function Add(out, label, rows, key)
    if #rows > 0 then out[#out + 1] = { label = label, rows = rows, key = key } end
end


function SourceData.Has(itemID)
    D = D or ns.SOURCE_DATA
    return D ~= nil and (D.items[itemID] ~= nil or UsedIn(itemID) ~= nil)
end



function SourceData.Sections(itemID)
    D = D or ns.SOURCE_DATA
    if not D then return nil end
    local rec = Record(itemID)
    local used = UsedIn(itemID)
    if not (rec or used) then return nil end
    rec = rec or NONE
    local out = {}
    for _, e in ipairs(rec.c or NONE) do
        local r = Recipe(e[1])
        if r then Add(out, sformat(L["SOURCES_CRAFTED_FMT"], RecipeSkill(r)), RecipeRows(r)) end
    end
    local gathered, found, fished = {}, {}, {}
    for _, e in ipairs(rec.o or NONE) do
        local row, kind = ObjectRow(e)
        if row then
            local list = (kind == "herb" or kind == "ore") and gathered or kind == "fish" and fished or found
            list[#list + 1] = row
        end
    end
    for _, e in ipairs(rec.f or NONE) do
        local zone = ZoneName(e[1])
        if zone then fished[#fished + 1] = { name = zone, icon = KIND_ICONS.fish, note = Pct(e[2]) or "" } end
    end
    Add(out, L["SOURCES_GATHERED"], gathered)
    local skinned, picked, drops = {}, {}, {}
    CreatureRows(rec.s, skinned)
    Add(out, L["SOURCES_SKINNED"], skinned)
    Add(out, L["SOURCES_FISHED"], fished)
    CreatureRows(rec.d, drops, true)
    if rec.w then
        drops[#drops + 1] = { name = L["SOURCES_WORLD_DROP"], icon = WORLD_DROP_ICON,
                              note = sformat(L["SOURCES_LEVELS_FMT"], rec.w[1], rec.w[2]) }
    end
    Add(out, L["SOURCES_DROPPED_BY"], drops, "dropped")
    CreatureRows(rec.p, picked)
    Add(out, L["SOURCES_PICKPOCKETED"], picked)
    Add(out, L["SOURCES_FOUND_IN"], found)
    local boxes = {}
    for _, e in ipairs(rec.i or NONE) do boxes[#boxes + 1] = { item = e[1], note = Pct(e[2]) or "" } end
    Add(out, L["SOURCES_CONTAINED"], boxes)
    local rewards = {}
    QuestRows(rec.q, rewards)
    Add(out, L["SOURCES_QUEST_REWARD"], rewards)
    if rec.x then
        local row = QuestRow(rec.x)
        if row then Add(out, L["SOURCES_STARTS_QUEST"], { row }) end
    end
    local taught = rec.t and Recipe(rec.t)
    if taught then Add(out, L["SOURCES_TEACHES"], { { item = taught.out, note = RecipeSkill(taught) } }) end
    if used then
        tsort(used, RankLess)
        local rows = {}
        for k = 1, #used do
            local r = Recipe(used[k])
            local n = 0
            for _, g in ipairs(r.reagents) do
                if g[1] == itemID then n = g[2] end
            end
            rows[#rows + 1] = { item = r.out, note = sformat(L["SOURCES_RECIPE_FMT"], RecipeSkill(r), n) }
        end
        Add(out, L["SOURCES_REAGENT_FOR"], rows)
    end
    local needs = {}
    QuestRows(rec.u, needs)
    Add(out, L["SOURCES_NEEDED_FOR"], needs)
    return out
end

ns.SourceData = SourceData
