-- The journal on the rows EasyFind already has. A boss row's click and a
-- loot row's source gesture open the journal where the client has no
-- Adventure Guide; every matched row, and the Questie extension's quest
-- rows, carry Open in DungeonJournal in their right-click menu.
local _, ns = ...
local API, FDJ = ns.API, ns.FDJ
if not API then return end

local L = ns.L
local sformat = string.format
local MAX_SOURCES = 6

-- What a row stands for in the journal: the kind and the journal's entry.
local function Kind(row)
    if row.category == "Loot" and row.itemID then return "item", ns.ItemFor(row.itemID) end
    if row.category == "Boss" and row.name then return "boss", ns.BossFor(row.name, row.instanceName) end
    if row.isDungeonEntrance and row.name and row.category ~= "delve" then
        local list = ns.DungeonsFor(row.name, row.entranceMapID or row.mapID)
        return "dungeon", list[1] and list or nil
    end
    if row.category == "questie" and row.questId then return "quest", ns.QuestFor(row.questId) end
    return nil
end
ns.RowKind = Kind

local function Applies(row)
    local kind, hit = Kind(row)
    return kind ~= nil and hit ~= nil
end

-- A boss row: the click opens the journal, Alt lists the boss's loot in
-- the bar (EasyFind's own listing). A loot row: its journal gesture opens
-- the item on its boss.
local function Select(row, _, gesture)
    local kind, hit = Kind(row)
    if not hit then return false end
    if kind == "boss" then
        if gesture == "alt" then return API.ShowScope("loot", row.name) == true end
        if gesture == nil or gesture == "click" then return ns.OpenBoss(hit) end
        return false
    end
    if kind == "item" then return ns.OpenItem(hit) end
    return false
end

local function Hint(row)
    local kind, hit = Kind(row)
    if not hit then return nil end
    if kind == "boss" then return { click = L["HINT_WORD"], alt = L["HINT_LOOT"] } end
    if kind == "item" then return L["HINT_WORD"] end
    return nil
end

local function Action(label, fn)
    return { kind = "action", label = label, onClick = fn }
end

local function Menu(row)
    local kind, hit = Kind(row)
    if not hit then return nil end
    if kind == "boss" then return { Action(L["HINT_OPEN"], function() ns.OpenBoss(hit) end) } end
    if kind == "item" then return { Action(L["HINT_OPEN"], function() ns.OpenItem(hit) end) } end
    if kind == "quest" then return { Action(L["HINT_OPEN"], function() ns.OpenQuest(hit) end) } end
    -- A dungeon row: its page, and its journal map when there is one; a name
    -- standing for several wings lists each.
    local rows = {}
    local maps = FDJ.DUNGEON_MAPS
    for _, name in ipairs(hit) do
        local shown = ns.DungeonName(name)
        rows[#rows + 1] = Action(#hit > 1 and sformat(L["OPEN_FMT"], shown) or L["HINT_OPEN"], function() ns.OpenDungeon(name) end)
        if maps and maps[name] and FDJ.ReopenDungeonMap then
            rows[#rows + 1] = Action(#hit > 1 and sformat(L["MAP_FMT"], shown) or L["HINT_MAP"], function()
                if ns.OpenDungeon(name) then FDJ.ReopenDungeonMap(name) end
            end)
        end
    end
    return rows
end

-- Under the row's tooltip: the journal's level for a boss, its range and
-- place for a dungeon, every boss that drops an item.
local function Tooltip(row, _, tt)
    local kind, hit = Kind(row)
    if not hit then return end
    if kind == "boss" then
        local levels = FDJ.BOSS_LEVELS and FDJ.BOSS_LEVELS[hit.dungeon]
        local level = levels and levels[hit.bossName]
        tt:AddLine(" ")
        tt:AddLine(L["EXT_NAME"], 1, 0.82, 0)
        tt:AddLine(level and sformat(L["BOSS_LINE_FMT"], sformat(L["LEVEL_FMT"], level), ns.DungeonName(hit.dungeon)) or ns.DungeonName(hit.dungeon), 1, 1, 1)
    elseif kind == "item" then
        tt:AddLine(" ")
        tt:AddLine(L["DROPS_FROM"], 1, 0.82, 0)
        for i = 1, math.min(#hit.sources, MAX_SOURCES) do
            local s = hit.sources[i]
            tt:AddLine(sformat(L["BOSS_LINE_FMT"], ns.BossName(s.bossName), ns.DungeonName(s.dungeon)), 1, 1, 1)
        end
        if #hit.sources > MAX_SOURCES then tt:AddLine("...", 0.6, 0.6, 0.6) end
    elseif kind == "dungeon" then
        tt:AddLine(" ")
        tt:AddLine(L["EXT_NAME"], 1, 0.82, 0)
        for _, name in ipairs(hit) do
            local level, location = ns.DungeonField(name, "level"), ns.DungeonField(name, "location")
            local parts = {}
            if #hit > 1 then parts[#parts + 1] = ns.DungeonName(name) end
            if level then parts[#parts + 1] = sformat(L["LEVEL_FMT"], level) end
            if location then parts[#parts + 1] = location end
            if parts[1] then tt:AddLine(table.concat(parts, ", "), 1, 1, 1) end
        end
    end
end

API.RegisterRowDecorator({
    id = ns.KEY,
    label = L["EXT_NAME"],
    applies = Applies,
    select = Select,
    hint = Hint,
    menu = Menu,
    tooltip = Tooltip,
})
