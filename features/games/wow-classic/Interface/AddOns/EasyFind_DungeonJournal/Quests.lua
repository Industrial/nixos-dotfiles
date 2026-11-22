-- The journal's dungeon quests as rows: level, dungeon and where the
-- player stands with it under the name, the game's quest mark, a click
-- opens the journal on the quest, Shift links it in chat, the GPS goes to
-- the quest giver when the journal places one.
local _, ns = ...
local API, FDJ = ns.API, ns.FDJ
if not API then return end

local L = ns.L
local KEY = ns.KEY .. "-quests"
local C_QuestLog = C_QuestLog
local IsShiftKeyDown = IsShiftKeyDown
local sformat = string.format
-- The game's quest marks: ! to pick up, ? in the log (gray until done), a
-- check once turned in.
local ICON_AVAILABLE, ICON_TURN_IN, ICON_IN_PROGRESS, ICON_DONE = 132049, 132048, 365195, 136814

-- ==== settings ==============================================================

local function Get(field) return ns.SavedVars()[field] == true end
local function Set(field, on)
    ns.SavedVars()[field] = on or nil
    ns.Refresh(KEY)
end
function ns.GetHideDone() return Get("hideDone") end
function ns.SetHideDone(on) Set("hideDone", on) end
function ns.GetOtherFaction() return Get("otherFaction") end
function ns.SetOtherFaction(on) Set("otherFaction", on) end
function ns.GetAllClasses() return Get("allClasses") end
function ns.SetAllClasses(on) Set("allClasses", on) end

-- ==== the quest log =========================================================

-- Retail and Forever answer through C_QuestLog; Era keeps the log-index
-- calls for a quest's completion.
local function LogIndex(id)
    if C_QuestLog.GetLogIndexForQuestID then return C_QuestLog.GetLogIndexForQuestID(id) end
    local index = GetQuestLogIndexByID and GetQuestLogIndexByID(id)
    return index and index > 0 and index or nil
end

local function IsDone(id)
    if C_QuestLog.IsComplete then return C_QuestLog.IsComplete(id) end
    local index = LogIndex(id)
    if not index then return false end
    local isComplete = select(6, GetQuestLogTitle(index))
    return isComplete ~= nil and isComplete > 0
end

local function OnQuest(id)
    return C_QuestLog.IsOnQuest(id) == true
end

local function Finished(id)
    return C_QuestLog.IsQuestFlaggedCompleted(id) == true
end

-- ==== which quests ==========================================================

local function MyFaction()
    local faction = UnitFactionGroup("player")
    return faction == "Alliance" and "Alliance" or faction == "Horde" and "Horde" or nil
end

local function FactionShown(quest, mine)
    local faction = quest.faction
    if faction ~= "Alliance" and faction ~= "Horde" then return true end
    return Get("otherFaction") or faction == mine
end

local function ClassShown(quest, myClass)
    return not quest.classOnly or Get("allClasses") or quest.classOnly == myClass
end

local function StateWord(id, level)
    if OnQuest(id) then return L[IsDone(id) and "STATE_TURN_IN" or "STATE_IN_LOG"] end
    if Finished(id) then return L["STATE_DONE"] end
    local need = tonumber(level)
    if need and need > UnitLevel("player") then return sformat(L["STATE_NEEDS_LEVEL"], need) end
    return L["STATE_AVAILABLE"]
end

local function Subtext(quest, dungeon)
    local parts = {}
    if quest.level then parts[#parts + 1] = sformat(L["LEVEL_FMT"], quest.level) end
    parts[#parts + 1] = ns.DungeonName(dungeon)
    if quest.faction == "Alliance" or quest.faction == "Horde" then
        parts[#parts + 1] = sformat(L["FACTION_ONLY_FMT"], L[quest.faction == "Alliance" and "FACTION_ALLIANCE" or "FACTION_HORDE"])
    end
    return sformat(L["STATE_SUBTEXT_FMT"], StateWord(quest.id, quest.requires), table.concat(parts, ", "))
end

-- The mark for the quest's state, and whether it is drawn gray (a quest
-- the character cannot take yet).
local function QuestIcon(quest)
    local id = quest.id
    if OnQuest(id) then return IsDone(id) and ICON_TURN_IN or ICON_IN_PROGRESS, false end
    if Finished(id) then return ICON_DONE, false end
    local need = tonumber(quest.requires)
    return ICON_AVAILABLE, need ~= nil and need > UnitLevel("player")
end

local function Rows()
    local out = {}
    local mine, myClass = MyFaction(), select(2, UnitClass("player"))
    local hideDone = Get("hideDone")
    ns.EachDungeon(function(name, dungeon)
        for index, quest in ipairs(dungeon.quests or {}) do
            if type(quest) == "table" and quest.id and quest.name and FactionShown(quest, mine) and ClassShown(quest, myClass)
               and not (hideDone and Finished(quest.id)) then
                local shown = ns.QuestField(quest, "name")
                local icon, dim = QuestIcon(quest)
                out[#out + 1] = { name = shown, questID = quest.id, questIndex = index, dungeon = name,
                                  icon = icon, iconDimmed = dim or nil, searchCommandDesc = Subtext(quest, name),
                                  keywords = shown ~= quest.name and { quest.name } or nil, inLog = OnQuest(quest.id) or nil,
                                  mapID = ns.EntranceMap(name) }
            end
        end
    end)
    return out
end

local function Quest(row)
    local dungeon = FDJ.DB[row.dungeon]
    local quest = dungeon and dungeon.quests and dungeon.quests[row.questIndex]
    return quest and quest.id == row.questID and quest or nil
end

-- The game's quest link: the log's own for a quest in it, built for any other.
local function QuestLink(quest, name)
    local link = OnQuest(quest.id) and GetQuestLink and GetQuestLink(quest.id)
    if link then return link end
    return sformat("|cffffff00|Hquest:%d:%d|h[%s]|h|r", quest.id, tonumber(quest.level) or 0, name)
end

local function Select(row)
    local quest = Quest(row)
    if not quest then return end
    if IsShiftKeyDown() then return ns.InsertChatLink(QuestLink(quest, row.name)) end
    ns.OpenResult({ kind = "quest", mode = "quests", dungeonName = row.dungeon, questIndex = row.questIndex,
                    questID = quest.id, questFaction = quest.faction })
end

-- The quest giver the journal places on the map, else the dungeon's entrance.
local function Place(row)
    local quest = Quest(row)
    if not quest then return nil end
    local spots = FDJ.QUEST_START_MAPS
    local spot = spots and spots[quest.id]
    if spot and spot.mapID and spot.x and spot.y and not OnQuest(quest.id) then
        return { name = sformat(L["DEST_GIVER_FMT"], row.name), mapID = spot.mapID, x = spot.x, y = spot.y,
                 step = L["STEP_GIVER"], icon = ICON_AVAILABLE, category = ns.KEY }
    end
    return ns.Entrance(row.dungeon)
end

local function AddWrapped(tt, text, r, g, b)
    for line in tostring(text):gmatch("[^\n]+") do tt:AddLine(line, r, g, b, true) end
end

local function Tooltip(row, tt)
    local quest = Quest(row)
    if not quest then return false end
    local level = tonumber(quest.level) or 0
    local color = GetQuestDifficultyColor and GetQuestDifficultyColor(level)
    tt:SetText(row.name, color and color.r or 1, color and color.g or 1, color and color.b or 1)
    local need = tonumber(quest.requires)
    if level > 0 then
        if need and need ~= level then
            tt:AddLine(sformat(L["LEVEL_REQ_FMT"], level, need), 1, 1, 1)
        else
            tt:AddLine(sformat(L["LEVEL_FMT"], level), 1, 1, 1)
        end
    end
    tt:AddLine(ns.DungeonName(row.dungeon), 1, 1, 1)
    local pickup, turnin = ns.QuestField(quest, "pickup"), ns.QuestField(quest, "turnin")
    if pickup then tt:AddLine(sformat(L["STARTS_AT"], pickup), 1, 1, 1, true) end
    if turnin and turnin ~= pickup then tt:AddLine(sformat(L["ENDS_AT"], turnin), 1, 1, 1, true) end
    local state = StateWord(quest.id, quest.requires)
    local done = OnQuest(quest.id) and IsDone(quest.id)
    tt:AddLine(state, done and 0 or 1, done and 1 or 0.82, 0)
    local objective = ns.QuestField(quest, "objective")
    if objective then
        tt:AddLine(" ")
        tt:AddLine(L["OBJECTIVES"])
        AddWrapped(tt, objective, 0.8, 0.8, 0.8)
    end
    local rewards = ns.QuestField(quest, "rewards")
    if rewards and rewards ~= "" then
        tt:AddLine(" ")
        tt:AddLine(L["REWARDS"])
        AddWrapped(tt, rewards, 0.8, 0.8, 0.8)
    end
    return true
end

-- The log's quests lead what an empty scope lists.
local function LogFirst(a, b)
    if (a.inLog or false) ~= (b.inLog or false) then return a.inLog == true end
    return a.name < b.name
end

-- Registered at login, only without the Questie extension (its rows carry
-- the journal's quests then).
function ns.RegisterQuests()
    API.RegisterSearchProvider({
        key = KEY,
        label = L["PROVIDER_QUESTS"],
        extension = ns.KEY,
        iconWell = true,
        options = ns.QuestOptions(),
        rows = function()
            local rows = Rows()
            table.sort(rows, LogFirst)
            return rows
        end,
        select = Select,
        tooltip = Tooltip,
        hint = { click = L["HINT_OPEN"], shift = L["HINT_LINK"] },
        browse = function(row) return row.inLog == true end,
        place = Place,
    })
    -- A quest's state changes its mark and subtext.
    local events = CreateFrame("Frame")
    events:SetScript("OnEvent", function() ns.Refresh(KEY) end)
    for _, event in ipairs({ "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP", "QUEST_LOG_UPDATE" }) do
        if not C_EventUtils or C_EventUtils.IsEventValid(event) then events:RegisterEvent(event) end
    end
end
