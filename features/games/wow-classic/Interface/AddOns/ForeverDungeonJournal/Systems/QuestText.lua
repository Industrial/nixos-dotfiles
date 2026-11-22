-- Real quest text from the game. WoW only hands addons a quest's text while
-- it is in the quest log or while its quest-giver window is open, so the
-- journal remembers it then (per client language, shared by all characters)
-- and shows it on the quest page from then on:
--   * the game's own objective text instead of the journal's short summary
--   * the quest description ("Description" section)
--   * live progress lines (5/7 Deviate Dreadfang slain) while it is in the log
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

local NAME_TOKEN = "\001N" -- the player's name is stored as a token

local function Secret(v) return type(issecretvalue) == "function" and issecretvalue(v) end
local function Str(v) return type(v) == "string" and not Secret(v) and v ~= "" and v or nil end

-- glowingshard: a quest objective line the game words vaguely ("Speak with
-- someone in Ratchet") named and counted like a WoW objective: "0/1 Speak
-- with Sputtervalve in Ratchet", "1/1 ..." once done (or the quest is ready
-- to hand in). FDJ.OBJECTIVE_LINE_OVERRIDES[questID] = { match = text found
-- in the game's line (lower case), text = the line }. Returns text, finished.
function FDJ.ObjectiveLineOverride(questID, text, finished)
    local o = questID and FDJ.OBJECTIVE_LINE_OVERRIDES and FDJ.OBJECTIVE_LINE_OVERRIDES[questID]
    if type(o) ~= "table" or type(text) ~= "string" then return text, finished end
    if not string.lower(text):find(o.match, 1, true) then return text, finished end
    local done = finished == true or (FDJ.IsQuestFinished and FDJ.IsQuestFinished(questID)) or false
    return (done and "1/1 " or "0/1 ") .. o.text, done
end
-- The same line for a quest in the log whose objective the game does not list.
function FDJ.ObjectiveLineMissing(questID)
    local o = questID and FDJ.OBJECTIVE_LINE_OVERRIDES and FDJ.OBJECTIVE_LINE_OVERRIDES[questID]
    if type(o) ~= "table" then return nil end
    return FDJ.ObjectiveLineOverride(questID, o.match, false)
end

local function Locale() return (GetLocale and GetLocale()) or "enUS" end

local function Store()
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    local all = ForeverDungeonJournalDB.questText
    if type(all) ~= "table" then all = {}; ForeverDungeonJournalDB.questText = all end
    local loc = Locale()
    all[loc] = all[loc] or {}
    return all[loc]
end

local function PlayerName()
    local ok, name = pcall(UnitName, "player")
    return ok and Str(name) or nil
end

local function Tokenize(text)
    local name = PlayerName()
    if not text or not name then return text end
    return (text:gsub(name:gsub("(%W)", "%%%1"), NAME_TOKEN))
end

local function Detokenize(text)
    if not text then return nil end
    local name = PlayerName() or ""
    return (text:gsub(NAME_TOKEN, (name:gsub("%%", "%%%%"))))
end

local function Save(questID, objective, description)
    questID = tonumber(questID)
    if not questID or questID <= 0 then return end
    objective, description = Str(objective), Str(description)
    if not objective and not description then return end
    local entry = Store()[questID] or {}
    if objective then entry.o = Tokenize(objective) end
    if description then entry.d = Tokenize(description) end
    Store()[questID] = entry
end

-- ------------------------------------------------------------- learning
local function ScanLog()
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return end
    if type(GetQuestLogQuestText) ~= "function" then return end
    local okN, n = pcall(C_QuestLog.GetNumQuestLogEntries)
    if not okN or type(n) ~= "number" then return end
    for i = 1, n do
        local ok, info = pcall(C_QuestLog.GetInfo, i)
        if ok and type(info) == "table" and not info.isHeader and type(info.questID) == "number" and info.questID > 0 then
            local ok2, desc, obj = pcall(GetQuestLogQuestText, i)
            if ok2 then Save(info.questID, obj, desc) end
            if FDJ.LearnQuestID then pcall(FDJ.LearnQuestID, info.questID, info.title) end -- dalaranquests
        end
    end
end

local pending = false
local function ScanSoon()
    if pending then return end
    pending = true
    local function run() pending = false; pcall(ScanLog) end
    if C_Timer and C_Timer.After then C_Timer.After(1, run) else run() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("QUEST_DETAIL")
events:RegisterEvent("QUEST_ACCEPTED")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:SetScript("OnEvent", function(_, event)
    if event == "QUEST_DETAIL" then
        pcall(function()
            local id = GetQuestID and GetQuestID()
            Save(id, GetObjectiveText and GetObjectiveText(), GetQuestText and GetQuestText())
            if FDJ.LearnQuestID then FDJ.LearnQuestID(id, GetTitleText and GetTitleText()) end -- dalaranquests
        end)
    else
        ScanSoon()
    end
end)

-- -------------------------------------------------------------- display
local function Learned(questID)
    if not questID then return nil end
    -- Text is stored in the client language: only use it when the journal
    -- shows that language too.
    if FDJ.CanUseClientLocalizedText and not FDJ.CanUseClientLocalizedText() then return nil end
    local entry = Store()[tonumber(questID)]
    if not entry then return nil end
    return Detokenize(entry.o), Detokenize(entry.d)
end
FDJ.LearnedQuestText = Learned

-- objdone (2.0.13, M 18 Nov 2026, Strange Pylons with the western pylon
-- found: "my quest log says I found the Western pylon, but our quest log in
-- the journal does not"): whether a quest's objective i is done: the
-- game's list, and its quest log's own line when the list does not say so.
-- A done line without a count ("Western pylon found") gets the game's
-- "(Complete)" after it (FDJ.ObjectiveDoneText), as in the quest log.
function FDJ.ObjectiveDone(questID, i, objective)
    if type(objective) == "table" and objective.finished == true then return true end
    if not (questID and i and C_QuestLog and C_QuestLog.GetLogIndexForQuestID) then return false end
    if type(GetQuestLogLeaderBoard) ~= "function" then return false end
    local okI, index = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
    if not okI or type(index) ~= "number" or index <= 0 then return false end
    local ok, _, _, finished = pcall(GetQuestLogLeaderBoard, i, index)
    return ok and (finished == true or finished == 1)
end
function FDJ.ObjectiveDoneText(text, done)
    if not done or type(text) ~= "string" or text:find("%d+%s*/%s*%d+") then return text end
    local word = type(COMPLETE) == "string" and COMPLETE or "Complete"
    if text:find(word, 1, true) then return text end
    return text .. " (" .. word .. ")"
end

local function ProgressLines(questID)
    if not (questID and C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetQuestObjectives) then return nil end
    local okI, index = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
    if not okI or type(index) ~= "number" or index <= 0 then return nil end
    local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
    if ok and type(objectives) == "table" and #objectives == 0 then
        -- glowingshard: the line the game leaves out, named.
        local text, done = FDJ.ObjectiveLineMissing(questID)
        if text then return done and ("|cff6e5c40" .. text .. "|r") or text end
    end
    if not ok or type(objectives) ~= "table" or #objectives == 0 then return nil end
    -- objectivetext: in the journal's language when that is not the game's.
    local own = FDJ.LocalizeObjectives and FDJ.LocalizeObjectives(questID, objectives, nil, true)
    if own then
        local translated = {}
        for _, line in ipairs(own) do
            translated[#translated + 1] = line[2] and ("|cff6e5c40" .. line[1] .. "|r") or line[1]
        end
        return #translated > 0 and table.concat(translated, "\n") or nil
    end
    local lines = {}
    for i, o in ipairs(objectives) do
        local text = type(o) == "table" and Str(o.text)
        if text then
            local finished = FDJ.ObjectiveDone(questID, i, o) -- objdone
            text, finished = FDJ.ObjectiveLineOverride(questID, text, finished) -- glowingshard
            text = FDJ.ObjectiveDoneText(text, finished)
            -- Finished objectives are muted, like the game's quest log.
            lines[#lines + 1] = finished and ("|cff6e5c40" .. text .. "|r") or text
        end
    end
    return #lines > 0 and table.concat(lines, "\n") or nil
end

-- Objective block for the quest page: the game's objective (or the
-- journal's fallback) plus live progress; second value is the description.
function FDJ.QuestPageText(questID, fallbackObjective)
    local obj, desc = Learned(questID)
    local text = obj or fallbackObjective or ""
    local progress = ProgressLines(questID)
    if progress then text = (text ~= "" and (text .. "\n\n") or "") .. progress end
    return text, desc
end

-- Places the Description section; returns the new y offset.
function FDJ.PlaceQuestDescription(frame, desc, y, placeHeader)
    local header, body = frame.questDescHeader, frame.questDescText
    if not header or not body then return y end
    -- The description is not shown (too long for the quest page); only the
    -- game's objective text and live progress are used.
    if true or not desc or desc == "" then
        header:Hide(); body:Hide()
        return y
    end
    y = placeHeader(header, y)
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -y)
    body:SetWidth(frame.questDetailText:GetWidth() or 360)
    body:SetText(desc)
    body:SetTextColor(0.10, 0.065, 0.025)
    body:Show()
    return y + (body:GetStringHeight() or 30) + 13
end

function FDJ.HideQuestDescription(frame)
    if frame and frame.questDescHeader then frame.questDescHeader:Hide() end
    if frame and frame.questDescText then frame.questDescText:Hide() end
end

-- BEGIN objectivetext
-- The game hands over quest objective lines in its own language. When the
-- journal speaks another one, the counted lines (12/20 Deviate Hide, 3/15
-- Defias Pillager slain) are rebuilt with the item's or creature's name in the
-- journal's language (FDJ.OBJECTIVE_NAMES, Localization/Content_NewDungeons.lua).
-- Lines with the quest's own wording (speak with someone in Ratchet, explore
-- a place) give way to the journal's translated objective; on the quest page,
-- which shows that objective already, they are left out.
do
    local column = {}
    for i, loc in ipairs(FDJ.OBJECTIVE_NAME_LOCALES or {}) do column[loc] = i end
    -- How a creature to kill reads in each language's Forever quest log,
    -- count first like the tracker (the others: just the name).
    local SLAIN = { enUS = "%s slain", deDE = "%s getötet", koKR = "%s 처치", ruRU = "%s – убито", zhCN = "消灭%s", zhTW = "殺死%s" }

    -- The game's own line format ("%2$d/%3$d %1$s slain") as a pattern that
    -- finds the name and both counts in a line.
    local patterns = {}
    local function Pattern(key)
        if patterns[key] ~= nil then return patterns[key] or nil end
        local fmt = _G[key]
        if type(fmt) ~= "string" or Secret(fmt) then patterns[key] = false return nil end
        fmt = fmt:gsub("|4[^;]*;", "\001")
        local out, order, auto, i = { "^" }, {}, 0, 1
        while i <= #fmt do
            local c = fmt:sub(i, i)
            if c == "%" then
                local pos, kind, len = fmt:match("^%%(%d)%$([sd])()", i)
                if not pos then
                    kind = fmt:match("^%%([sd])", i)
                    if kind then auto, pos, len = auto + 1, auto + 1, i + 2 end
                else
                    pos = tonumber(pos)
                end
                if kind then
                    out[#out + 1] = kind == "s" and "(.-)" or "(%d+)"
                    order[#order + 1] = pos
                    i = len
                else
                    out[#out + 1] = "%%"
                    i = i + 1
                end
            elseif c == "\001" then
                out[#out + 1] = ".-"
                i = i + 1
            else
                out[#out + 1] = c:find("[%^%$%(%)%%%.%[%]%*%+%-%?]") and ("%" .. c) or c
                i = i + 1
            end
        end
        out[#out + 1] = "$"
        local p = { table.concat(out), order }
        patterns[key] = p
        return p
    end
    local KEYS = { monster = "QUEST_MONSTERS_KILLED", item = "QUEST_ITEMS_NEEDED", object = "QUEST_OBJECTS_FOUND" }
    -- name, done, needed (nil: not a counted line)
    local function Split(text, kind)
        local order = { KEYS[kind], "QUEST_MONSTERS_KILLED", "QUEST_ITEMS_NEEDED", "QUEST_OBJECTS_FOUND" }
        for _, key in ipairs(order) do
            local p = key and Pattern(key)
            if p then
                local got = { text:match(p[1]) }
                if #got == #p[2] and #got > 0 then
                    local args = {}
                    for n, pos in ipairs(p[2]) do args[pos] = got[n] end
                    if args[1] and tonumber(args[2]) and tonumber(args[3]) then
                        return args[1], tonumber(args[2]), tonumber(args[3]), key == "QUEST_MONSTERS_KILLED"
                    end
                end
            end
        end
        local done, needed, name = text:match("^(%d+)%s*/%s*(%d+)%s+(.+)$")
        if name then return name, tonumber(done), tonumber(needed), false end
        name, done, needed = text:match("^(.-)%s*[:：]%s*(%d+)%s*/%s*(%d+)$")
        if name and name ~= "" then return name, tonumber(done), tonumber(needed), false end
        return nil
    end

    -- A name in the game's language -> English (the table's key).
    local reverse = {}
    local function English(name, client)
        if client == "enUS" then return FDJ.OBJECTIVE_NAMES and FDJ.OBJECTIVE_NAMES[name] and name or nil end
        local col = column[client]
        if not col or not FDJ.OBJECTIVE_NAMES then return nil end
        local index = reverse[client]
        if not index then
            index = {}
            for english, row in pairs(FDJ.OBJECTIVE_NAMES) do
                if row[col] then index[row[col]] = english end
            end
            reverse[client] = index
        end
        -- Not known in the game's language: the same name as in English.
        return index[name] or (FDJ.OBJECTIVE_NAMES[name] and name) or nil
    end
    -- "Faldrim Anvilmar slain" -> "Faldrim Anvilmar" (a line the game's own
    -- format did not split, the kill word still on the name).
    local function Unslain(name, client)
        local before, after = (SLAIN[client] or ""):match("^(.-)%%s(.*)$")
        if not before then return nil end
        local function Esc(s) return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end
        local bare = name:match("^" .. Esc(before) .. "%s*(.-)%s*" .. Esc(after) .. "$")
        return bare and bare ~= "" and bare ~= name and bare or nil
    end
    local function Localized(english, target)
        if target == "enUS" then return english end
        local row = FDJ.OBJECTIVE_NAMES and FDJ.OBJECTIVE_NAMES[english]
        local col = column[target]
        if not row or not col then return nil end
        -- Not known in that language: the name as it is in English.
        return row[col] or english
    end

    -- objectives: the game's list for a quest (C_QuestLog.GetQuestObjectives).
    -- Returns the lines in the journal's language as { {text, finished}, ... },
    -- or nil when the journal speaks the game's language. goal: the quest's
    -- English objective (for an English journal on another game language);
    -- onPage: the quest page, which shows the translated objective already.
    function FDJ.LocalizeObjectives(questID, objectives, goal, onPage)
        if not FDJ.CanUseClientLocalizedText or FDJ.CanUseClientLocalizedText() then return nil end
        if type(objectives) ~= "table" then return nil end
        local target = (FDJ.GetLanguage and FDJ.GetLanguage()) or "enUS"
        local client = (FDJ.GetClientLanguage and FDJ.GetClientLanguage()) or "enUS"
        local out, worded, wordedDone = {}, false, true
        for _, o in ipairs(objectives) do
            local text = type(o) == "table" and Str(o.text) or nil
            if text then
                local finished = o.finished == true
                local name, done, needed, slain = Split(text, o.type)
                if name then
                    local english = English(name, client)
                    if not english then
                        local bare = Unslain(name, client)
                        english = bare and English(bare, client)
                        slain = slain or english ~= nil
                    end
                    local localized = english and Localized(english, target)
                    if localized then
                        done = (type(o.numFulfilled) == "number" and not Secret(o.numFulfilled)) and o.numFulfilled or done
                        needed = (type(o.numRequired) == "number" and not Secret(o.numRequired)) and o.numRequired or needed
                        if o.type == "monster" or slain then localized = (SLAIN[target] or "%s"):format(localized) end
                        text = done .. "/" .. needed .. " " .. localized
                    end
                    out[#out + 1] = { text, finished }
                else
                    worded = true
                    wordedDone = wordedDone and finished
                    out[#out + 1] = { text, finished, worded = true }
                end
            end
        end
        if not worded then return out end
        local translated
        if target == "enUS" then
            translated = goal
        elseif FDJ.LocalizeQuestField then
            translated = FDJ.LocalizeQuestField(questID, "objective", nil)
        end
        if type(translated) ~= "string" or translated == "" then return out end
        local kept, placed = {}, false
        for _, line in ipairs(out) do
            if not line.worded then
                kept[#kept + 1] = line
            elseif not placed and not onPage then
                placed = true
                kept[#kept + 1] = { translated, wordedDone }
            end
        end
        return kept
    end
end
-- END objectivetext

-- BEGIN sleepingbagui
-- The Cozy Sleeping Bag page (data: Data/QuestUpdates.lua). The bag's own
-- icon from the game, round with the WoW Forever emblem's soft glow, on the
-- journal's home page in the row of that emblem and the Raids medallion, opens the bag's quest
-- chain, unfolded at the step the character is on; right-click: Hide (also in
-- Options). The
-- page's title is the bag's name in the journal's language; Track on its
-- quest list works as on a dungeon's (a tracked chain keeps its arrow).
do
    local PAGE = FDJ.SLEEPING_BAG_PAGE
    local ITEM = FDJ.SLEEPING_BAG_ITEM or 211527
    local QUEST = 79976
    local ICON = "Interface\\Icons\\INV_Misc_Bag_BigBagofEnchantments" -- only if the client doesn't know the bag
    local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
    local GLOW = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\TickGlow"
    if PAGE and FDJ.DB and FDJ.DB[PAGE] then
        local strings = {
            enUS = { SLEEPING_BAG = "Sleeping Bag", SLEEPING_BAG_TITLE = "Cozy Sleeping Bag",
                SLEEPING_BAG_HOW = "How to get Sleeping Bag", SLEEPING_BAG_HIDE_TIP = "Right-click to hide", SLEEPING_BAG_HIDE = "Hide" },
            deDE = { SLEEPING_BAG = "Schlafsack", SLEEPING_BAG_TITLE = "Gemütlicher Schlafsack",
                SLEEPING_BAG_HOW = "So bekommst du den Schlafsack", SLEEPING_BAG_HIDE_TIP = "Rechtsklick zum Ausblenden", SLEEPING_BAG_HIDE = "Ausblenden" },
            frFR = { SLEEPING_BAG = "Sac de couchage", SLEEPING_BAG_TITLE = "Sac de couchage douillet",
                SLEEPING_BAG_HOW = "Comment obtenir le sac de couchage", SLEEPING_BAG_HIDE_TIP = "Clic droit pour masquer", SLEEPING_BAG_HIDE = "Masquer" },
            esES = { SLEEPING_BAG = "Saco de dormir", SLEEPING_BAG_TITLE = "Saco de dormir acogedor",
                SLEEPING_BAG_HOW = "Cómo conseguir el saco de dormir", SLEEPING_BAG_HIDE_TIP = "Clic derecho para ocultar", SLEEPING_BAG_HIDE = "Ocultar" },
            itIT = { SLEEPING_BAG = "Sacco a pelo", SLEEPING_BAG_TITLE = "Sacco a pelo accogliente",
                SLEEPING_BAG_HOW = "Come ottenere il sacco a pelo", SLEEPING_BAG_HIDE_TIP = "Clic destro per nascondere", SLEEPING_BAG_HIDE = "Nascondi" },
            ptBR = { SLEEPING_BAG = "Saco de dormir", SLEEPING_BAG_TITLE = "Saco de dormir aconchegante",
                SLEEPING_BAG_HOW = "Como conseguir o saco de dormir", SLEEPING_BAG_HIDE_TIP = "Clique com o botão direito para ocultar", SLEEPING_BAG_HIDE = "Ocultar" },
            ruRU = { SLEEPING_BAG = "Спальный мешок", SLEEPING_BAG_TITLE = "Уютный спальный мешок",
                SLEEPING_BAG_HOW = "Как получить спальный мешок", SLEEPING_BAG_HIDE_TIP = "Правый клик — скрыть", SLEEPING_BAG_HIDE = "Скрыть" },
            koKR = { SLEEPING_BAG = "침낭", SLEEPING_BAG_TITLE = "아늑한 침낭",
                SLEEPING_BAG_HOW = "침낭 얻는 방법", SLEEPING_BAG_HIDE_TIP = "우클릭하여 숨기기", SLEEPING_BAG_HIDE = "숨기기" },
            zhCN = { SLEEPING_BAG = "睡袋", SLEEPING_BAG_TITLE = "舒适的睡袋",
                SLEEPING_BAG_HOW = "如何获得睡袋", SLEEPING_BAG_HIDE_TIP = "右键点击隐藏", SLEEPING_BAG_HIDE = "隐藏" },
            zhTW = { SLEEPING_BAG = "睡袋", SLEEPING_BAG_TITLE = "舒適的睡袋",
                SLEEPING_BAG_HOW = "如何獲得睡袋", SLEEPING_BAG_HIDE_TIP = "右鍵點擊隱藏", SLEEPING_BAG_HIDE = "隱藏" },
        }
        for locale, entries in pairs(strings) do
            local t = FDJ.Locales and FDJ.Locales[locale]
            if t then
                for key, value in pairs(entries) do
                    if t[key] == nil then t[key] = value end
                end
            end
        end

        local function L(key)
            return FDJ.L and FDJ.L(key) or key
        end
        local function Plain(v)
            if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
            return v
        end

        -- The game's own name of the bag when the journal speaks the game's
        -- language, else the journal's translation.
        local function Title()
            if FDJ.CanUseClientLocalizedText and FDJ.CanUseClientLocalizedText() then
                local get = (C_Item and C_Item.GetItemNameByID) or GetItemInfo
                if type(get) == "function" then
                    local ok, name = pcall(get, ITEM)
                    name = ok and Plain(name) or nil
                    if type(name) == "string" and name ~= "" then return name end
                end
            end
            return L("SLEEPING_BAG_TITLE")
        end
        local baseName = FDJ.LocalizeDungeonName
        FDJ.LocalizeDungeonName = function(name, ...)
            if name == PAGE then return Title() end
            if baseName then return baseName(name, ...) end
            return name
        end

        -- Step 1 and where Stepping Stones is picked up: the character's faction.
        local function Resolve()
            if not FDJ.SetSleepingBagFaction or type(UnitFactionGroup) ~= "function" then return end
            local ok, faction = pcall(UnitFactionGroup, "player")
            faction = ok and Plain(faction) or nil
            if faction == "Horde" or faction == "Alliance" then FDJ.SetSleepingBagFaction(faction) end
        end
        Resolve()
        local events = CreateFrame("Frame")
        events:RegisterEvent("PLAYER_LOGIN")
        events:SetScript("OnEvent", function()
            Resolve()
            if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, ITEM) end
        end)

        -- The chain at the step the character is on (the first one not handed
        -- in); the whole chain done: the last quest.
        function FDJ.OpenSleepingBagChain()
            if not FDJ.OpenQuestChain then return end
            local stepID
            for _, step in ipairs((FDJ.QUEST_PREREQ_CHAINS and FDJ.QUEST_PREREQ_CHAINS[QUEST]) or {}) do
                if type(step) == "table" and type(step.id) == "number"
                    and not (FDJ.QuestTurnedIn and FDJ.QuestTurnedIn(step.id)) then
                    stepID = step.id
                    break
                end
            end
            FDJ.OpenQuestChain(PAGE, QUEST, stepID)
        end

        -- The bag is the chain's reward: once the character has it (in the bags
        -- or the bank, or the chain's last quest handed in), the icon goes by itself.
        local function HasBag()
            if FDJ.QuestTurnedIn and FDJ.QuestTurnedIn(QUEST) then return true end
            local count
            if C_Item and C_Item.GetItemCount then
                local ok, n = pcall(C_Item.GetItemCount, ITEM, true)
                if ok then count = Plain(n) end
            end
            if count == nil and GetItemCount then
                local ok, n = pcall(GetItemCount, ITEM, true)
                if ok then count = Plain(n) end
            end
            return type(count) == "number" and count > 0
        end
        FDJ.HasSleepingBag = HasBag

        -- The bag's medallion on the home page: placed by Systems/ForeverFilter.lua
        -- right of the Raids medallion, a little smaller. Click: the chain; hover:
        -- How to get Sleeping Bag; right-click: Hide (Options: Hide Sleeping Bag
        -- quest). Hidden, a tracked chain still shows its arrow.
        -- hideSleepingBag: true = hidden (ticked, or Hide); false = shown, even
        -- with the bag (unticked while the character has it); nil = shown until
        -- the character has the bag.
        function FDJ.IsSleepingBagHidden()
            local v = ForeverDungeonJournalDB and ForeverDungeonJournalDB.hideSleepingBag
            if v == true then return true end
            if v == false then return false end
            return HasBag() and true or false
        end

        local function Wanted(b)
            return b and b.fdjPlaced == true and not FDJ.IsSleepingBagHidden()
        end

        local menu
        local lastHidden
        -- Keep the Options checkbox in step (right-click Hide, the bag looted).
        local function RefreshOptions()
            lastHidden = FDJ.IsSleepingBagHidden()
            local settings = _G.ForeverDungeonJournalSettings
            if settings and settings:IsShown() then
                local onShow = settings:GetScript("OnShow")
                if onShow then pcall(onShow, settings) end
            end
        end
        function FDJ.SetSleepingBagHidden(hidden)
            ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
            -- Unticked always brings it back, the bag or not.
            if hidden then
                ForeverDungeonJournalDB.hideSleepingBag = true
            elseif HasBag() then
                ForeverDungeonJournalDB.hideSleepingBag = false
            else
                ForeverDungeonJournalDB.hideSleepingBag = nil
            end
            local frame = _G.ForeverDungeonJournalFrame
            local b = frame and frame.sleepingBagButton
            if b then b:SetShown(Wanted(b)) end
            if menu then menu:Hide() end
            RefreshOptions()
        end

        -- The chain's own spots (where each step is picked up and handed in):
        -- Show on Map there brings the waypoint arrow up too (Systems/MapMarkers.lua).
        local function Same(a, spot)
            return type(a) == "table" and a.mapID == spot.mapID
                and math.abs((tonumber(a.x) or -1) - spot.x) < 0.0005
                and math.abs((tonumber(a.y) or -1) - spot.y) < 0.0005
        end
        local function OnPage(loc, spot)
            return Same(loc.map, spot) or Same(loc.startMap, spot) or Same(loc.turninMap, spot)
        end
        function FDJ.IsSleepingBagSpot(spot)
            if type(spot) ~= "table" or not spot.mapID then return false end
            local x, y = tonumber(spot.x), tonumber(spot.y)
            if not x or not y then return false end
            spot = { mapID = spot.mapID, x = x, y = y }
            for _, quest in ipairs((FDJ.DB[PAGE] and FDJ.DB[PAGE].quests) or {}) do
                if type(quest) == "table" and OnPage(quest, spot) then return true end
            end
            local details = FDJ.QUEST_PREREQ_DETAILS or {}
            local ids = { 79007, 79008 } -- step 1, both factions
            for _, step in ipairs((FDJ.QUEST_PREREQ_CHAINS and FDJ.QUEST_PREREQ_CHAINS[QUEST]) or {}) do
                if type(step) == "table" then ids[#ids + 1] = step.id end
            end
            for _, id in ipairs(ids) do
                if type(details[id]) == "table" and OnPage(details[id], spot) then return true end
            end
            return false
        end

        -- Right-click: a small menu with Hide (as the LFG eye's Disable).
        local function ShowMenu(anchor)
            if not menu then
                menu = CreateFrame("Frame", "ForeverDungeonJournalSleepingBagMenu", UIParent, "BackdropTemplate")
                menu:SetFrameStrata("FULLSCREEN_DIALOG")
                menu:EnableMouse(true)
                menu:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    edgeSize = 12,
                    insets = { left = 3, right = 3, top = 3, bottom = 3 },
                })
                menu:SetBackdropColor(0.055, 0.05, 0.043, 0.98)
                menu:SetBackdropBorderColor(0.57, 0.43, 0.20, 1)
                local item = CreateFrame("Button", nil, menu)
                item:SetPoint("TOPLEFT", 5, -5)
                item:SetPoint("RIGHT", -5, 0)
                item:SetHeight(20)
                item:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                item.text = item:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
                item.text:SetPoint("LEFT", 6, 0)
                item:SetScript("OnClick", function()
                    menu:Hide()
                    -- 2.0.4: Hide opens Options at its line (highlighted); the
                    -- player ticks it there, so they know where to undo it.
                    if FDJ.OpenSettingsAt then FDJ.OpenSettingsAt("OPT_HIDE_SLEEPING_BAG") else FDJ.SetSleepingBagHidden(true) end
                end)
                menu.hide = item
                -- Closes on its own once the mouse has been away for a moment.
                menu:SetScript("OnUpdate", function(self, elapsed)
                    if self:IsMouseOver() or (self.fdjAnchor and self.fdjAnchor:IsMouseOver()) then
                        self.fdjAway = 0
                    else
                        self.fdjAway = (self.fdjAway or 0) + elapsed
                        if self.fdjAway > 0.6 then self:Hide() end
                    end
                end)
            end
            menu.hide.text:SetText(L("SLEEPING_BAG_HIDE"))
            menu:SetSize(math.max(110, (menu.hide.text:GetStringWidth() or 0) + 24), 30)
            menu.fdjAnchor = anchor
            menu.fdjAway = 0
            menu:ClearAllPoints()
            menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, -2)
            menu:Show()
            if GameTooltip then GameTooltip:Hide() end
        end

        -- The bag's own icon, as the game shows it.
        local function BagIcon()
            local icon
            if C_Item and C_Item.GetItemIconByID then
                local ok, v = pcall(C_Item.GetItemIconByID, ITEM)
                if ok then icon = Plain(v) end
            end
            if not icon and GetItemIcon then
                local ok, v = pcall(GetItemIcon, ITEM)
                if ok then icon = Plain(v) end
            end
            return icon or ICON
        end

        local function Build(frame)
            local home = frame.homePanel
            local b = CreateFrame("Button", nil, home)
            frame.sleepingBagButton = b
            b:SetSize(40, 40)
            b:SetFrameLevel(home:GetFrameLevel() + 5)
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            -- Round like the emblems next to it, with the WoW Forever emblem's
            -- soft golden glow behind it.
            b.halo = b:CreateTexture(nil, "BACKGROUND", nil, -1)
            b.halo:SetTexture(GLOW)
            b.halo:SetBlendMode("ADD")
            b.halo:SetVertexColor(1, 0.82, 0.35)
            b.halo:SetAlpha(0.75)
            b.halo:SetPoint("CENTER")
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetPoint("CENTER")
            b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            if b.CreateMaskTexture then
                local mask = b:CreateMaskTexture()
                mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                mask:SetAllPoints(b.icon)
                b.icon:AddMaskTexture(mask)
                b.mask = mask
            end
            b.hl = b:CreateTexture(nil, "HIGHLIGHT")
            b.hl:SetTexture(MASK)
            b.hl:SetBlendMode("ADD")
            b.hl:SetAlpha(0.25)
            b.hl:SetPoint("CENTER")
            b:SetScript("OnMouseDown", function(self, button)
                if button ~= "LeftButton" then return end
                self.icon:ClearAllPoints()
                self.icon:SetPoint("CENTER", 1, -1)
            end)
            b:SetScript("OnMouseUp", function(self)
                self.icon:ClearAllPoints()
                self.icon:SetPoint("CENTER")
            end)
            b:SetScript("OnClick", function(self, button)
                if button == "RightButton" then
                    ShowMenu(self)
                    return
                end
                if GameTooltip then GameTooltip:Hide() end
                if PlaySound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.IG_ABILITY_PAGE_TURN) or 836) end -- tabsound (2.0.11): the journal's opening page sound
                FDJ.OpenSleepingBagChain()
            end)
            b:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L("SLEEPING_BAG_HOW"), 1, 0.82, 0)
                GameTooltip:AddLine(L("SLEEPING_BAG_HIDE_TIP"), 0.6, 0.6, 0.6)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            return b
        end

        function FDJ.PlaceSleepingBagButton(frame, anchor, size)
            if not frame or not frame.homePanel or not anchor then return end
            local b = frame.sleepingBagButton or Build(frame)
            size = size or 40
            -- A little smaller than the medallions next to it (1.9.7).
            local inner = math.floor(size * 0.9 + 0.5)
            b:SetSize(inner, inner)
            b.icon:SetTexture(BagIcon())
            b.icon:SetSize(inner, inner)
            b.hl:SetSize(inner, inner)
            local glow = math.floor(inner * 1.92 + 0.5) -- as the WoW Forever emblem's, to scale
            b.halo:SetSize(glow, glow)
            b:ClearAllPoints()
            b:SetPoint("LEFT", anchor, "RIGHT", size >= 40 and 12 or (size >= 30 and 10 or 8), 0)
            b.fdjPlaced = true
            b:SetShown(Wanted(b))
        end

        -- The bag looted or the last quest handed in while the journal is open.
        local watch = CreateFrame("Frame")
        watch:RegisterEvent("BAG_UPDATE_DELAYED")
        watch:RegisterEvent("QUEST_TURNED_IN")
        watch:SetScript("OnEvent", function()
            local frame = _G.ForeverDungeonJournalFrame
            local b = frame and frame.sleepingBagButton
            if b then b:SetShown(Wanted(b)) end
            if FDJ.IsSleepingBagHidden() ~= lastHidden then RefreshOptions() end
        end)
    end
end
-- END sleepingbagui

-- BEGIN questtracker
-- ------------------------------------------------------------ quest tracker
-- Track, on a dungeon's quest list, pops that list out of the journal into a
-- small window on the screen: the quests this character can do there (own
-- faction and class, like the list), with live progress from the quest log.
-- The window is dressed like the journal's Options panel (the game's own
-- Options window frame). Every tracked dungeon gets its own window; each can
-- be dragged anywhere, scaled from its bottom-right corner and folded to its
-- title bar, and stays as it is left (for every character). Clicking a quest
-- opens it in the journal, clicking a chain step opens that step, and the
-- round ? of a finished quest (the game's own quest button) shows on the map
-- where to hand it in, the ! of a quest to pick up where to pick it up (when
-- the journal knows the spot). A quest that needs a chain first shows the
-- chain icon after its !: a click lists the chain's steps, the one the
-- player is on with its own ! (or ?). A quest whose start item is in the bags shows that
-- item instead of its !; clicking it takes the quest. Rows are grouped: to
-- hand in, in the log, to pick up, done. The X stops tracking that dungeon.
-- The dungeons tracked are chosen per character.
do
    local WIDTH = 250
    local TITLE_H = 22      -- title bar of the game's frame art
    local SIDE = 12         -- border + padding left and right of the rows
    local ROWS_TOP = 31     -- first row, below the title bar
    local BOTTOM_PAD = 14
    local COLLAPSED_H = 34
    local FOLDED_H = 24     -- folded: the title bar box of the game's frame art, down to its bronze line
    local ROW_GAP = 7
    local ICON_SIZE = 20    -- tick, ! and ? in front of each quest
    local ICON_X = 8        -- their middle, from the row's left
    local TEXT_X = 23
    -- "In Dungeon" icon after the ! of a quest still to pick up inside the
    -- dungeon (its art fills about 2/3 of the square). A window showing it
    -- moves every quest name over to make room.
    local DOOR_SIZE = 26
    local DOOR_X = 23       -- its middle
    local DOOR_TEXT_X = 34
    -- The item that starts a quest, once it is in the bags: its icon in place
    -- of the ! (and the In Dungeon icon); a click uses it and takes the quest.
    local ITEM_SIZE = 22
    -- A quest that needs a chain first: the chain icon after its ! (before
    -- the In Dungeon icon); a click lists the chain's steps under the quest,
    -- each with its tick, ! or ? (STEP_ICON) and its name.
    local CHAIN_SIZE = 16
    local ICON_STEP = 18    -- from one icon after the ! to the next
    local STEP_ICON = 14
    local STEP_TEXT_X = 17
    local WINDOW_GAP = 6    -- a new window opens this far under the last one
    local MIN_SCALE, MAX_SCALE = 0.6, 1.6
    local WHITE = "Interface\\Buttons\\WHITE8X8"
    local BOOK = "Interface\\Icons\\INV_Misc_Book_09"
    local CHAIN = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\QuestChain"
    local GLOW = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"
    local ICON_TODO = "Interface\\GossipFrame\\AvailableQuestIcon"
    local ICON_LOG = "Interface\\GossipFrame\\ActiveQuestIcon"
    local ICON_DONE = "Interface\\RaidFrame\\ReadyCheck-Ready"
    -- The game's own quest button for a quest to hand in (objective tracker,
    -- world map): round dark button with a gold ring and the yellow ?, lit
    -- up on mouse-over. Its 32-unit art is drawn at 30 to fit between the
    -- window's edge and the quest's name.
    local POI_SIZE = 30
    local POI_RING = "UI-QuestPoi-QuestNumber"
    local POI_RING_DOWN = "UI-QuestPoi-QuestNumber-Pressed"
    local POI_LIT = "UI-QuestPoi-InnerGlow"
    local POI_TURN_IN = "UI-QuestIcon-TurnIn-Normal"
    -- The same button drawn big (Media/TurnInMark.tga), sharp where the
    -- game's small art goes soft: the quest list's and quest page's ?.
    local TURN_IN_ART = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\TurnInMark"

    local GOLD = { 1.00, 0.82, 0.00 }
    local GREEN = { 0.30, 1.00, 0.36 }
    local DONE = { 0.45, 0.78, 0.47 }
    local TODO = { 0.86, 0.82, 0.72 }
    local GREY = { 0.55, 0.55, 0.55 }

    local windows = {}      -- window frames by slot, one per shown dungeon
    local dragEndedAt = 0

    local function T(key, ...)
        if FDJ.L then return FDJ.L(key, ...) end
        return key
    end

    local function Plain(v)
        if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
        return v
    end

    -- Whether this game has that quest button art (WoW Forever does; a game
    -- without it keeps the plain yellow ? with a soft glow).
    local hasQuestButton
    local function HasQuestButton()
        if hasQuestButton == nil then
            local get = C_Texture and C_Texture.GetAtlasInfo
            hasQuestButton = type(get) == "function"
            for _, atlas in ipairs({ POI_RING, POI_RING_DOWN, POI_LIT, POI_TURN_IN }) do
                if hasQuestButton then
                    local ok, info = pcall(get, atlas)
                    hasQuestButton = ok and info ~= nil
                end
            end
        end
        return hasQuestButton
    end

    local function Hex(c)
        return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255 + 0.5),
            math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
    end

    local function CharDB()
        if type(ForeverDungeonJournalCharacterDB) ~= "table" then ForeverDungeonJournalCharacterDB = {} end
        return ForeverDungeonJournalCharacterDB
    end

    -- Where the windows sit and how big they are: the same for every
    -- character. One entry per window slot (first window, second, ...).
    local function Saved()
        if type(ForeverDungeonJournalDB) ~= "table" then ForeverDungeonJournalDB = {} end
        local saved = ForeverDungeonJournalDB.questTracker
        if type(saved) ~= "table" then
            saved = {}
            ForeverDungeonJournalDB.questTracker = saved
        end
        if type(saved.slots) ~= "table" then
            saved.slots = {}
            -- Test builds 1.6.11 - 1.6.14 kept one window's place and size.
            if type(saved.left) == "number" and type(saved.top) == "number" then
                saved.slots[1] = { left = saved.left, top = saved.top, scale = saved.scale }
            end
            saved.left, saved.top, saved.scale, saved.collapsed = nil, nil, nil, nil
        end
        return saved
    end

    local function Slot(index)
        local slots = Saved().slots
        if type(slots[index]) ~= "table" then slots[index] = {} end
        return slots[index]
    end

    -- The tracked dungeons of this character, in the order they were added.
    local function TrackedList()
        local db = CharDB()
        local list = db.trackedDungeons
        if type(list) ~= "table" then
            list = {}
            db.trackedDungeons = list
        end
        -- Test builds 1.6.11 - 1.6.13 kept a single dungeon.
        if type(db.trackedDungeon) == "string" then
            local old = db.trackedDungeon
            db.trackedDungeon = nil
            local have = false
            for _, name in ipairs(list) do if name == old then have = true end end
            if not have then table.insert(list, old) end
        end
        for i = #list, 1, -1 do
            if type(list[i]) ~= "string" or not (FDJ.DB and FDJ.DB[list[i]]) then table.remove(list, i) end
        end
        return list
    end

    -- trackpull (2.0.50) took Track (these windows) off the dungeons; that
    -- was a misunderstanding. trackback (2.0.6): Track is on every dungeon's
    -- quest list again, as in 2.0.5. What stays out of the release is only
    -- the dungeon route, the arrow guide (vault "route"); the waypoint arrow
    -- still follows only the chain pages (FollowChains).
    local function Trackable(name)
        local d = name and FDJ.DB and FDJ.DB[name]
        if not d then return false end
        return true
    end

    local function IsTracked(name)
        if not Trackable(name) then return false end
        for _, tracked in ipairs(TrackedList()) do
            if tracked == name then return true end
        end
        return false
    end

    -- The tracked ones that can be shown (trackpull, 2.0.50).
    local function ShownTracked()
        local list = {}
        for _, name in ipairs(TrackedList()) do
            if Trackable(name) then list[#list + 1] = name end
        end
        return list
    end

    -- Windows folded down to their title bar, by dungeon.
    local function Folded()
        local db = CharDB()
        if type(db.trackerFolded) ~= "table" then db.trackerFolded = {} end
        return db.trackerFolded
    end

    -- The window each tracked dungeon is shown in (per character).
    local function WindowSlots()
        local db = CharDB()
        if type(db.trackerSlots) ~= "table" then db.trackerSlots = {} end
        return db.trackerSlots
    end

    local function Faction()
        local ok, faction = pcall(UnitFactionGroup, "player")
        faction = ok and Plain(faction) or nil
        if faction == "Alliance" or faction == "Horde" then return faction end
        local saved = ForeverDungeonJournalDB and ForeverDungeonJournalDB.questFaction
        return saved == "Horde" and "Horde" or "Alliance"
    end

    local function Matches(quest, faction)
        if FDJ.QuestMatchesFaction then return FDJ.QuestMatchesFaction(quest, faction) end
        return quest.faction == "Both" or quest.faction == "Neutral" or quest.faction == faction
    end

    -- The quests the journal lists for this character, in the list's order
    -- (repeatable quests stay out, as they do under the list's fold).
    local function QuestsOf(name)
        local list = {}
        local dungeon = name and FDJ.DB and FDJ.DB[name]
        if type(dungeon) ~= "table" or dungeon.previewOnly then return list end
        local faction = Faction()
        for _, quest in ipairs(dungeon.quests or {}) do
            if type(quest) == "table" and type(quest.id) == "number" and quest.name
                and not quest.repeatable and not quest.hideFromMainList and Matches(quest, faction)
                and (not FDJ.QuestCountsForCharacter or FDJ.QuestCountsForCharacter(quest)) -- otherclass (2.0.8)
                and not (FDJ.IsQuestUnavailable and FDJ.IsQuestUnavailable(quest)) -- notavailable (2.0.4), raceunavailable (2.0.9)
                and not (FDJ.RPGQuestHidden and FDJ.RPGQuestHidden(name, quest)) then -- RPG Mode: unlocked ones only
                list[#list + 1] = quest
            end
        end
        return list
    end

    local function Locked(name)
        if not FDJ.IsDungeonLocked then return false end
        local ok, locked = pcall(FDJ.IsDungeonLocked, name)
        return ok and locked == true
    end

    local function Field(id, field, fallback)
        if FDJ.LocalizeQuestField then
            local value = FDJ.LocalizeQuestField(id, field, fallback)
            if type(value) == "string" and value ~= "" then return value end
        end
        return fallback
    end

    -- ----------------------------------------------------------- quest state
    local function TurnedIn(id)
        if FDJ.QuestTurnedIn then return FDJ.QuestTurnedIn(id) == true end
        local check = (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or IsQuestFlaggedCompleted
        if type(check) ~= "function" then return false end
        local ok, value = pcall(check, id)
        return ok and value == true
    end

    local function LogIndex(id)
        if C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID) == "function" then
            local ok, index = pcall(C_QuestLog.GetLogIndexForQuestID, id)
            if ok and type(index) == "number" and index > 0 then return index end
        end
        if type(GetQuestLogIndexByID) == "function" then
            local ok, index = pcall(GetQuestLogIndexByID, id)
            if ok and type(index) == "number" and index > 0 then return index end
        end
        return nil
    end

    local function InLog(id)
        if FDJ.IsQuestInLog then return FDJ.IsQuestInLog(id) == true end
        return LogIndex(id) ~= nil
    end

    -- done: turned in. ready: every objective done. log: being worked on.
    -- todo: not picked up yet.
    local function State(id)
        if TurnedIn(id) then return "done" end
        if InLog(id) then
            if FDJ.IsQuestFinished and FDJ.IsQuestFinished(id) then return "ready" end
            return "log"
        end
        return "todo"
    end

    -- "Grell Earring: 1/8" reads as "1/8 Grell Earring", like the game's tracker.
    local function CountFirst(text)
        local what, count = text:match("^(.-)%s*:%s*(%d+%s*/%s*%d+)%s*$")
        if what and what ~= "" then return count .. " " .. what end
        return text
    end

    local function Objectives(id, goal)
        local lines = {}
        if C_QuestLog and type(C_QuestLog.GetQuestObjectives) == "function" then
            local ok, list = pcall(C_QuestLog.GetQuestObjectives, id)
            if ok and type(list) == "table" then
                -- In the journal's language when that is not the game's.
                local own = FDJ.LocalizeObjectives and FDJ.LocalizeObjectives(id, list, goal)
                if own then
                    for _, line in ipairs(own) do lines[#lines + 1] = { CountFirst(line[1]), line[2] } end
                    return lines
                end
                for i, objective in ipairs(list) do
                    local text = type(objective) == "table" and Plain(objective.text) or nil
                    if type(text) == "string" and text ~= "" then
                        local named, done = FDJ.ObjectiveLineOverride(id, text, FDJ.ObjectiveDone(id, i, objective)) -- glowingshard (objdone)
                        lines[#lines + 1] = { FDJ.ObjectiveDoneText(named ~= text and named or CountFirst(text), done), done }
                    end
                end
                if #lines == 0 and #list == 0 and LogIndex(id) then
                    local named, done = FDJ.ObjectiveLineMissing(id) -- glowingshard
                    if named then lines[1] = { named, done } end
                end
                return lines
            end
        end
        local index = LogIndex(id)
        if index and type(GetNumQuestLeaderBoards) == "function" and type(GetQuestLogLeaderBoard) == "function" then
            local okCount, count = pcall(GetNumQuestLeaderBoards, index)
            for i = 1, (okCount and type(count) == "number") and count or 0 do
                local ok, text, _, finished = pcall(GetQuestLogLeaderBoard, i, index)
                text = ok and Plain(text) or nil
                if type(text) == "string" and text ~= "" then
                    local named, done = FDJ.ObjectiveLineOverride(id, text, finished == true or finished == 1) -- glowingshard
                    lines[#lines + 1] = { named ~= text and named or CountFirst(text), done }
                end
            end
        end
        return lines
    end

    -- Done counts ("8/8 Dwarven Heirloom") grey out; a line without a count
    -- is a "take this to / talk to" one, done the moment the quest is taken:
    -- it stays white, it says where to go.
    local function ObjectiveText(id, indent, goal)
        local parts = {}
        for _, line in ipairs(Objectives(id, goal)) do
            local text, finished = line[1], line[2]
            local color = "|cffe8e8e8"
            if finished then
                color = text:find("%d+%s*/%s*%d+") and Hex(GREY) or "|cffffffff"
            end
            parts[#parts + 1] = (indent or "") .. color .. text .. "|r"
        end
        return parts
    end

    -- Picked up inside the dungeon, as the journal's quest list marks it: a
    -- quest whose chain starts outside does not count unless the journal
    -- says its chain starts inside (startsInDungeon).
    local function StartsInDungeon(quest, dungeonName)
        if quest.startsInDungeon then return true end
        -- A quest that needs a chain first: the step the chain is at (the
        -- first one not handed in yet); every step done: the quest itself.
        local fromChain = FDJ.ChainStartsInside and FDJ.ChainStartsInside(quest, dungeonName, true)
        if fromChain ~= nil then return fromChain == true end
        if FDJ.StartsInsideDungeon ~= nil and FDJ.StartsInsideDungeon(quest.pickup) == true then return true end
        -- Started by an item that drops in this dungeon (The Glowing Shard).
        return FDJ.StartItemDropsIn ~= nil and FDJ.StartItemDropsIn(quest, dungeonName) == true
    end

    -- Chains unfolded in the tracker (per character, by quest).
    local function ChainsOpen()
        local db = CharDB()
        if type(db.trackerChains) ~= "table" then db.trackerChains = {} end
        return db.trackerChains
    end

    -- Whether this game has the action button template that uses an item on
    -- a click (without it the ! stays).
    local canUseItems
    local function CanUseItems()
        if canUseItems == nil then
            local ok, b = pcall(CreateFrame, "Button", nil, nil, "InsecureActionButtonTemplate")
            canUseItems = ok and b ~= nil
            if ok and b then b:Hide() end
        end
        return canUseItems
    end

    -- The item that starts the quest (startItem), when it is in the bags.
    local function StartItemInBags(quest)
        if not CanUseItems() then return nil end
        local item = quest.startItem
        local id = type(item) == "table" and tonumber(item[1]) or nil
        if not id or id <= 0 then return nil end
        local count = (C_Item and C_Item.GetItemCount) or GetItemCount
        if type(count) ~= "function" then return nil end
        local ok, n = pcall(count, id)
        n = ok and Plain(n) or nil
        if type(n) == "number" and n > 0 then return id end
        return nil
    end

    -- A quest that needs a chain first: the chain step in the quest log, if any.
    local function ChainStep(quest)
        local chain = FDJ.QUEST_PREREQ_CHAINS and FDJ.QUEST_PREREQ_CHAINS[quest.id]
        if type(chain) ~= "table" then return nil end
        for _, step in ipairs(chain) do
            if type(step) == "table" and type(step.id) == "number" and InLog(step.id) and not TurnedIn(step.id) then
                return step
            end
        end
        return nil
    end

    -- Where a quest is handed in, on the world map. The journal keeps map
    -- spots for quest givers and turn-in NPCs (FDJ.TURNIN_SPOTS); the turn-in
    -- NPC is looked up among them by name ("Rahauro, Elder Rise, Thunder
    -- Bluff" -> Rahauro's spot).
    local npcSpots, dungeonNpcs
    local function NpcOf(loc)
        if type(loc) ~= "table" or not loc.mapID then return nil end
        local name = loc.targetName
        if type(name) ~= "string" or name == "" then
            local label = loc.label
            if type(label) ~= "string" then return nil end
            name = label:match("^(.-)%s+\226\128\148") or label:match("^([^,]+)") or label
        end
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        return name ~= "" and name:lower() or nil
    end
    -- "Rahauro, Elder Rise, Thunder Bluff" -> "rahauro"
    local function NpcName(text)
        if type(text) ~= "string" then return nil end
        local name = text:match("^([^,(]+)")
        name = name and name:gsub("^%s+", ""):gsub("%s+$", ""):lower()
        if not name or name == "" then return nil end
        return name
    end
    local function NpcSpot(name)
        if not npcSpots then
            npcSpots = {}
            local function Add(loc)
                local npc = NpcOf(loc)
                if npc and not npcSpots[npc] then npcSpots[npc] = loc end
            end
            for _, loc in ipairs(FDJ.TURNIN_SPOTS or {}) do Add(loc) end
            for _, loc in pairs(FDJ.QUEST_START_MAPS or {}) do Add(loc) end
            for _, details in pairs(FDJ.QUEST_PREREQ_DETAILS or {}) do
                if type(details) == "table" then Add(details.map); Add(details.turninMap) end
            end
        end
        if npcSpots[name] or type(name) ~= "string" then return npcSpots[name] end
        -- The same NPC with or without a title in front: a quest says
        -- "Hamuul Runetotem", the map knows "Arch Druid Hamuul Runetotem".
        -- Only when exactly one NPC fits. Remembered (false: none fits).
        npcSpots.titled = npcSpots.titled or {}
        local known = npcSpots.titled[name]
        if known ~= nil then return known or nil end
        local hit, count = nil, 0
        for key, loc in pairs(npcSpots) do
            if key ~= "titled" and ((#key > #name and key:sub(-(#name + 1)) == " " .. name)
                or (#name > #key and name:sub(-(#key + 1)) == " " .. key)) then
                hit, count = loc, count + 1
            end
        end
        hit = count == 1 and hit or nil
        npcSpots.titled[name] = hit or false
        return hit
    end
    -- NPCs inside a dungeon: their spot on the journal's map of that dungeon
    -- (DUNGEON_MAPS[name].turnins).
    local function DungeonNpc(name)
        if not dungeonNpcs then
            dungeonNpcs = {}
            for dungeon, data in pairs(FDJ.DUNGEON_MAPS or {}) do
                for _, spot in ipairs(type(data) == "table" and data.turnins or {}) do
                    if type(spot) == "table" and type(spot.npc) == "string" then
                        dungeonNpcs[spot.npc:lower()] = { dungeon = dungeon, spot = spot }
                    end
                end
            end
            -- turninall: a boss who takes quests once beaten or won over
            -- (Captain Kromcrush): his spot on the map.
            for dungeon, data in pairs(FDJ.DUNGEON_MAPS or {}) do
                for _, boss in ipairs(type(data) == "table" and data.bosses or {}) do
                    local key = type(boss) == "table" and type(boss.name) == "string" and boss.name:lower()
                    if key and boss.x and boss.y and not dungeonNpcs[key] then
                        dungeonNpcs[key] = { dungeon = dungeon, spot = { floor = boss.floor or 1, x = boss.x, y = boss.y, npc = boss.name } }
                    end
                end
            end
        end
        return dungeonNpcs[name]
    end
    -- The dungeon page that lists a quest (a chain step: its quest's page).
    local questDungeons
    local function QuestDungeon(id)
        if not questDungeons then
            questDungeons = {}
            for dungeon, data in pairs(FDJ.DB or {}) do
                for _, listed in ipairs(type(data) == "table" and data.quests or {}) do
                    if type(listed) == "table" and listed.id and not questDungeons[listed.id] then questDungeons[listed.id] = dungeon end
                end
            end
            for mainID, chain in pairs(FDJ.QUEST_PREREQ_CHAINS or {}) do
                local dungeon = questDungeons[mainID]
                for _, step in ipairs((dungeon and type(chain) == "table") and chain or {}) do
                    if type(step) == "table" and step.id and not questDungeons[step.id] then questDungeons[step.id] = dungeon end
                end
            end
        end
        return id and questDungeons[id] or nil
    end
    -- turninall: the dungeon a turn-in names in its last part ("Bijou, Lower
    -- Blackrock Spire", "Lorekeeper Lydros, Athenaeum, Dire Maul", "...,
    -- inside Shadowfang Keep"). A name shared by several pages (Dire Maul,
    -- Stratholme): the page that lists the quest, else one with a map.
    local dungeonNames
    local function NamedDungeon(quest)
        local where = type(quest) == "table" and quest.turnin
        if type(where) ~= "string" then return nil end
        local last = where:gsub("%b()", ""):match("([^,]*)$") or ""
        last = last:lower():gsub("^%s+", ""):gsub("%s+$", "")
        last = last:gsub("^just ", ""):gsub("^inside ", "")
        if last == "" then return nil end
        if not dungeonNames then
            dungeonNames = {}
            local function Add(key, dungeon)
                dungeonNames[key] = dungeonNames[key] or {}
                table.insert(dungeonNames[key], dungeon)
            end
            for dungeon in pairs(FDJ.DB or {}) do
                local full = dungeon:lower()
                Add(full, dungeon)
                local base = full:match("^(.-):")
                if base and base ~= "" then Add(base, dungeon) end
            end
            for _, list in pairs(dungeonNames) do table.sort(list) end
        end
        local list = dungeonNames[last]
        if not list then return nil end
        local own = QuestDungeon(quest.id)
        for _, dungeon in ipairs(list) do
            if dungeon == own then return dungeon end
        end
        for _, dungeon in ipairs(list) do
            if FDJ.DUNGEON_MAPS and FDJ.DUNGEON_MAPS[dungeon] then return dungeon end
        end
        return list[1]
    end
    -- Handed in inside a dungeon with a map page: the one it names, else
    -- ("..., inside the dungeon") the one that lists it.
    local function InsideDungeon(quest)
        local maps = FDJ.DUNGEON_MAPS or {}
        local named = NamedDungeon(quest)
        if named then return maps[named] and named or nil end
        local where = type(quest) == "table" and quest.turnin
        if type(where) ~= "string" or not where:lower():find("inside", 1, true) then return nil end
        local dungeon = QuestDungeon(quest.id)
        return dungeon and maps[dungeon] and dungeon or nil
    end
    -- turninall: where on a dungeon map a quest is handed in, from the map's
    -- own quest spots (FDJ.MAP_QUEST_PINS, act "end"): the NPC or object its
    -- turn-in names first (Belnistrasz's Brazier, not Belnistrasz).
    local questPins
    local function QuestPin(quest)
        local id = type(quest) == "table" and quest.id
        if not id then return nil end
        if not questPins then
            questPins = {}
            for dungeon, pins in pairs(FDJ.MAP_QUEST_PINS or {}) do
                for _, pin in ipairs(type(pins) == "table" and pins or {}) do
                    for _, spot in ipairs(type(pin) == "table" and pin.spots or {}) do
                        for _, q in ipairs(type(spot) == "table" and spot.quests or {}) do
                            local ends = false
                            for _, act in ipairs(type(q) == "table" and q.acts or {}) do
                                if act == "end" then ends = true end
                            end
                            if ends and q.id and pin.x and pin.y then
                                local list = questPins[q.id] or {}
                                questPins[q.id] = list
                                list[#list + 1] = { dungeon = dungeon, spot = { floor = pin.floor or 1, x = pin.x, y = pin.y, npc = spot.name } }
                            end
                        end
                    end
                end
            end
        end
        local list = questPins[id]
        if not list then return nil end
        local name = NpcName(quest.turnin)
        for _, hit in ipairs(list) do
            if name and type(hit.spot.npc) == "string" and hit.spot.npc:lower() == name then return hit end
        end
        return list[1]
    end
    -- Handed in inside a dungeon: the spot on its map (the map's quest spot,
    -- else the NPC's), else just its map.
    local function DungeonTurnIn(quest)
        local pinned = QuestPin(quest)
        if pinned then return pinned end
        local name = NpcName(quest.turnin)
        local known = name and DungeonNpc(name)
        if known then return known end
        local dungeon = InsideDungeon(quest)
        return dungeon and { dungeon = dungeon, spot = {} } or nil
    end
    -- turninall: inside a dungeon with no map page here (Lower Blackrock
    -- Spire, Scholomance): its entrance on the world map.
    local function EntranceSpot(quest)
        local dungeon = NamedDungeon(quest)
        if not dungeon and type(quest.turnin) == "string" and quest.turnin:lower():find("inside", 1, true) then
            dungeon = QuestDungeon(quest.id)
        end
        local data = dungeon and FDJ.DB and FDJ.DB[dungeon]
        local entrance = type(data) == "table" and data.entrance
        if type(entrance) ~= "table" or not entrance.mapID or not entrance.x or not entrance.y then return nil end
        return { mapID = entrance.mapID, x = entrance.x, y = entrance.y, label = entrance.label, detail = entrance.detail }
    end
    local function TurnInSpot(quest)
        -- The spot given with the quest first: two places can share a name
        -- (the Burned-Out Remains in The Barrens and in Westfall).
        local given = quest.turninMap
        if type(given) == "table" and given.mapID then return given end
        -- turninall: a quest handed in at one of a dungeon map's quest spots
        -- goes there (Dark Iron Legacy: Franclorn's monument in the Depths,
        -- not his ghost outside).
        if QuestPin(quest) then return nil end
        local name = NpcName(quest.turnin)
        if not name then return nil end
        local own = FDJ.QUEST_START_MAPS and FDJ.QUEST_START_MAPS[quest.id]
        if own and NpcOf(own) == name then return own end
        local spot = NpcSpot(name)
        if spot then return spot end
        if DungeonTurnIn(quest) then return nil end
        return EntranceSpot(quest)
    end
    -- Where a quest is picked up: the journal's Show on Map spot, else the
    -- giver's spot by name. A quest started by an item has none.
    local function StartSpot(quest)
        if quest.startItem then return nil end
        local loc = quest.startMap or (FDJ.QUEST_START_MAPS and FDJ.QUEST_START_MAPS[quest.id])
        if type(loc) == "table" and loc.mapID then return loc end
        local name = NpcName(quest.pickup)
        return name and NpcSpot(name) or nil
    end
    -- Picked up inside a dungeon.
    local function DungeonStart(quest)
        if quest.startItem then return nil end
        local name = NpcName(quest.pickup)
        return name and DungeonNpc(name) or nil
    end

    local function PlayerLevel()
        if type(UnitLevel) ~= "function" then return nil end
        local ok, level = pcall(UnitLevel, "player")
        level = ok and Plain(level) or nil
        return type(level) == "number" and level or nil
    end

    -- What one row shows: icon, title colour, the lines under the title and
    -- the chain step (its own clickable line).
    local function RowInfo(quest, level)
        local id = quest.id
        local info = { quest = quest, state = State(id), name = Field(id, "name", quest.name) }
        if info.state == "done" then
            info.icon, info.grey, info.color = ICON_DONE, false, DONE
        elseif info.state == "ready" then
            info.icon, info.grey, info.color = ICON_LOG, false, GOLD
            info.sub = Hex(GREEN) .. T("TRACK_READY") .. "|r"
            info.turnin = TurnInSpot(quest)
            if not info.turnin then info.dungeonTurnin = DungeonTurnIn(quest) end
        elseif info.state == "log" then
            info.icon, info.grey, info.color = ICON_LOG, true, GOLD
            -- Its grey ? shows where it is handed in too (a "talk to" quest
            -- is never counted as finished before it is handed in). A quest
            -- whose objective is done somewhere else first (The Glowing Shard:
            -- talk to Sputtervalve in Ratchet) shows that place until it is.
            local goTo = quest.objectiveMap
            if type(goTo) == "table" and goTo.mapID then
                info.turnin, info.goTo = goTo, true
            else
                info.turnin = TurnInSpot(quest)
            end
            if not info.turnin then info.dungeonTurnin = DungeonTurnIn(quest) end
            local parts = ObjectiveText(id, nil, quest.objective)
            if #parts == 0 then
                -- Nothing to count (go somewhere, talk to someone): the goal.
                local goal = Field(id, "objective", quest.objective)
                if type(goal) == "string" and goal ~= "" then
                    parts[1] = "|cffcfcfcf" .. goal .. "|r"
                    info.short = true
                end
            end
            info.sub = #parts > 0 and table.concat(parts, "\n") or nil
        else
            info.low = type(quest.requires) == "number" and level ~= nil and level < quest.requires
            info.icon, info.grey, info.color = ICON_TODO, info.low, info.low and GREY or TODO
            -- The ! shows where to pick the quest up: a chain's next step
            -- first, while none of its steps is in the log.
            info.start = StartSpot(quest)
            local chain = FDJ.QUEST_PREREQ_CHAINS and FDJ.QUEST_PREREQ_CHAINS[quest.id]
            if type(chain) == "table" and not ChainStep(quest) then
                for _, s in ipairs(chain) do
                    if type(s) == "table" and type(s.id) == "number" and not s.itemStep and not TurnedIn(s.id) then
                        local d = (FDJ.QUEST_PREREQ_DETAILS and FDJ.QUEST_PREREQ_DETAILS[s.id]) or {}
                        info.start = StartSpot({ id = s.id, pickup = d.pickup, startMap = d.map, startItem = d.startItem }) or info.start
                        break
                    end
                end
            end
            if not info.start then info.dungeonStart = DungeonStart(quest) end
            local step = ChainStep(quest)
            if step then
                info.step = step
                info.stepName = Field(step.id, "name", step.name or "")
                -- Its number in the chain first ("1. The Greenwarden"), as in
                -- the journal's chain list and the opened chain here.
                local stepIndex
                for i, s in ipairs(FDJ.QUEST_PREREQ_CHAINS[quest.id] or {}) do
                    if s == step then stepIndex = i break end
                end
                -- choicestep (2.0.37): a choice of quests is one number.
                if stepIndex and FDJ.ChainStepNumber then stepIndex = FDJ.ChainStepNumber(FDJ.QUEST_PREREQ_CHAINS[quest.id], stepIndex) end
                info.stepLabel = stepIndex and (stepIndex .. ". " .. info.stepName) or info.stepName
                -- No chain glyph of its own: the quest's chain icon says it.
                local parts = { Hex(GOLD) .. info.stepLabel .. "|r" }
                local stepDetails = FDJ.QUEST_PREREQ_DETAILS and FDJ.QUEST_PREREQ_DETAILS[step.id]
                for _, line in ipairs(ObjectiveText(step.id, "   ", stepDetails and stepDetails.objective)) do parts[#parts + 1] = line end
                info.stepText = table.concat(parts, "\n")
                -- Ready to hand in: the round ? after its name shows where.
                if FDJ.IsQuestFinished and FDJ.IsQuestFinished(step.id) then
                    info.stepTurnIn = { id = step.id, turnin = stepDetails and stepDetails.turnin, turninMap = stepDetails and stepDetails.turninMap }
                end
            end
            local chain = FDJ.QUEST_PREREQ_CHAINS and FDJ.QUEST_PREREQ_CHAINS[quest.id]
            if type(chain) == "table" and #chain > 0 then
                info.chain = chain
                info.chainOpen = ChainsOpen()[quest.id] == true
            end
        end
        return info
    end

    -- The chain's steps as the tracker lists them: handed in (tick), the one
    -- the player is on (! where to pick it up, ? in the log), the ones after.
    local function ChainSteps(info)
        local out, current = {}, false
        local chain = info.chain or {}
        local index = 1
        while index <= #chain do
            local step = chain[index]
            -- pickone (2.0.42): a choice of quests (choicestep, 2.0.37) is
            -- "1. Pick one of the following quests:" with its quests under
            -- it ("- Master Feardred"); once one of them is in the log, that
            -- one alone; once one is handed in, the line alone (ticked).
            local last, combined = index, nil
            if type(step) == "table" and step.choice ~= nil and FDJ.ChainChoiceEnd then
                last = FDJ.ChainChoiceEnd(chain, index)
                if last > index then
                    local pick
                    for k = index, last do
                        local s = chain[k]
                        if type(s) == "table" and type(s.id) == "number" and InLog(s.id) and not TurnedIn(s.id) then pick = s break end
                    end
                    if pick then
                        step = pick
                    else
                        local names = {}
                        for k = index, last do
                            local s = chain[k]
                            if type(s) == "table" then names[#names + 1] = Field(s.id, "name", s.name or "") end
                        end
                        combined = names
                    end
                end
            end
            if type(step) == "table" then
                local id = step.id
                local details = (id and FDJ.QUEST_PREREQ_DETAILS and FDJ.QUEST_PREREQ_DETAILS[id]) or {}
                local entry = { step = step, index = index, details = details, name = combined and T("CHAIN_PICK_ONE") or Field(id, "name", step.name or ""), combined = combined ~= nil }
                if combined then entry.arrowName = combined[1] end -- the arrow: the quest's own name
                entry.label = ((FDJ.ChainStepNumber and FDJ.ChainStepNumber(chain, index)) or index) .. ". "
                if step.itemStep or type(id) ~= "number" then
                    entry.state = "item"
                elseif TurnedIn(id) then
                    entry.state = "done"
                elseif InLog(id) then
                    current = true
                    entry.parts = ObjectiveText(id, "   ", details.objective)
                    entry.turnin = TurnInSpot({ id = id, turnin = details.turnin, turninMap = details.turninMap })
                    if FDJ.IsQuestFinished and FDJ.IsQuestFinished(id) then
                        entry.state = "ready"
                    else
                        entry.state = "log"
                        -- stepgoto (2.1.1, M 20 Nov 2026, Test of Lore: "it's
                        -- not sending me to the objective"): a step done
                        -- somewhere else first (details.objectiveMap: the
                        -- book in Ashenvale) shows that place until it is
                        -- done, as a quest of the list does (The Glowing Shard).
                        local goTo = details.objectiveMap
                        if type(goTo) == "table" and goTo.mapID then entry.turnin, entry.goTo = goTo, true end
                    end
                elseif not current then
                    current = true
                    entry.state = "next"
                    entry.start = StartSpot({ id = id, pickup = details.pickup, startMap = details.map, startItem = details.startItem })
                else
                    entry.state = "later"
                end
                -- the choice's quests under its line, while it is to do
                if combined and entry.state ~= "done" then
                    entry.parts = {}
                    for _, name in ipairs(combined) do entry.parts[#entry.parts + 1] = "   " .. Hex(entry.state == "next" and TODO or GREY) .. "- " .. name .. "|r" end
                end
                out[#out + 1] = entry
            end
            index = last + 1
        end
        return out
    end

    -- dungeonroute: the dungeon Route (arrow guide) is not in the release
    -- (kept in the private vault).
    local function RouteOn() return false end
    local function RouteSkips() return {} end
    local function Routes() return {} end
    local function RoutePlan() return {} end

    -- ------------------------------------------------------- the frame art
    -- The game's own Options window frame (metal edges, corners and title
    -- bar), borrowed piece by piece the way the Options panel does it. Its
    -- corners are cut down to fit when the window is short.
    local NINE = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
        "TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }
    local TOP_CORNERS = { "TopLeftCorner", "TopRightCorner" }
    local BOTTOM_CORNERS = { "BottomLeftCorner", "BottomRightCorner" }

    local function GameArt(f)
        local nine = _G.SettingsPanel and _G.SettingsPanel.NineSlice
        if not nine or not nine.TopLeftCorner or not nine.BottomLeftCorner then return false end
        -- The pieces are drawn inside a frame that cuts off anything reaching
        -- past the window's outline (the long top and bottom edge pieces on a
        -- short window).
        local clip = CreateFrame("Frame", nil, f)
        clip:SetFrameLevel(f:GetFrameLevel() + 1)
        local holder = CreateFrame("Frame", nil, clip)
        holder:SetAllPoints(f)
        holder:SetFrameLevel(f:GetFrameLevel() + 1)
        local made, keyOf = {}, {}
        for _, key in ipairs(NINE) do
            if nine[key] then keyOf[nine[key]] = key end
        end
        for _, key in ipairs(NINE) do
            local src = nine[key]
            local atlas = src and src.GetAtlas and src:GetAtlas()
            if atlas then
                local layer, sub = src:GetDrawLayer()
                local t = holder:CreateTexture(nil, layer or "BORDER", nil, sub or 0)
                t:SetAtlas(atlas, false)
                if src.GetHorizTile and t.SetHorizTile then t:SetHorizTile(src:GetHorizTile()) end
                if src.GetVertTile and t.SetVertTile then t:SetVertTile(src:GetVertTile()) end
                if src.GetVertexColor then t:SetVertexColor(src:GetVertexColor()) end
                t:SetSize(src:GetWidth(), src:GetHeight())
                made[key] = t
            end
        end
        for _, key in ipairs(NINE) do
            if not made[key] then clip:Hide() return false end
        end
        for key, t in pairs(made) do
            local src = nine[key]
            for i = 1, src:GetNumPoints() do
                local point, rel, relPoint, x, y = src:GetPoint(i)
                local target = holder
                if rel and keyOf[rel] and made[keyOf[rel]] then target = made[keyOf[rel]] end
                t:SetPoint(point, target, relPoint, x, y)
            end
        end
        local reach = {}
        for _, key in ipairs({ "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner" }) do
            local t, src = made[key], nine[key]
            local _, _, _, x, y = src:GetPoint(1)
            t.fdjFullH = src:GetHeight()
            t.fdjOffsetY = y or 0
            t.fdjCoords = { t:GetTexCoord() }
            reach[key] = { x or 0, y or 0 }
            if not (t.fdjFullH and t.fdjFullH > 0 and #t.fdjCoords >= 8) then clip:Hide() return false end
        end
        local clipRight = math.max(0, reach.TopRightCorner[1], reach.BottomRightCorner[1])
        local clipBottom = math.min(0, reach.BottomLeftCorner[2], reach.BottomRightCorner[2])
        clip:SetPoint("TOPLEFT", f, "TOPLEFT", math.min(0, reach.TopLeftCorner[1], reach.BottomLeftCorner[1]),
            math.max(0, reach.TopLeftCorner[2], reach.TopRightCorner[2]))
        clip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", clipRight, clipBottom)
        if clip.SetClipsChildren then clip:SetClipsChildren(true) end
        f.art = made
        f.artHolder = holder
        f.artClip = clip
        f.artClipRight, f.artClipBottom = clipRight, clipBottom
        return true
    end

    -- Short window: show only the top part of the top corners (title bar,
    -- chamfer) and the bottom part of the bottom corners, so the metal edges
    -- meet instead of running past each other. Folded: only the title bar
    -- box, nothing under its bronze line.
    local UNDER_TITLE = { "BottomLeftCorner", "BottomRightCorner", "BottomEdge", "LeftEdge", "RightEdge" }

    local function FitArt(f, height, folded)
        local art = f.art
        if not art then return end
        local tl, bl = art.TopLeftCorner, art.BottomLeftCorner
        local above, below = math.max(0, tl.fdjOffsetY), math.max(0, -bl.fdjOffsetY)
        local function Crop(t, keep, fromTop)
            local c = t.fdjCoords
            local left, top, bottom, right = c[1], c[2], c[4], c[5]
            local part = (bottom - top) * keep / t.fdjFullH
            if fromTop then
                t:SetTexCoord(left, right, top, top + part)
            else
                t:SetTexCoord(left, right, bottom - part, bottom)
            end
            t:SetHeight(keep)
        end
        if folded then
            local keep = math.max(1, math.min(tl.fdjFullH, above + height))
            for _, key in ipairs(TOP_CORNERS) do Crop(art[key], keep, true) end
            for _, key in ipairs(UNDER_TITLE) do art[key]:Hide() end
            f.artClip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", f.artClipRight, 0)
            return
        end
        f.artClip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", f.artClipRight, f.artClipBottom)
        art.BottomLeftCorner:Show()
        art.BottomRightCorner:Show()
        art.BottomEdge:Show()
        local space = height + above + below
        local keepTop, keepBottom = tl.fdjFullH, bl.fdjFullH
        if keepTop + keepBottom > space then
            local minBottom = math.min(bl.fdjFullH, below + 10)
            keepTop = math.max(math.min(tl.fdjFullH, above + TITLE_H + 2), math.min(tl.fdjFullH, space - minBottom))
            keepBottom = math.max(1, math.min(bl.fdjFullH, space - keepTop))
        end
        for _, key in ipairs(TOP_CORNERS) do Crop(art[key], keepTop, true) end
        for _, key in ipairs(BOTTOM_CORNERS) do Crop(art[key], keepBottom, false) end
        local gap = space - keepTop - keepBottom
        art.LeftEdge:SetShown(gap > 0.5)
        art.RightEdge:SetShown(gap > 0.5)
    end

    -- Without the game's frame: the Options panel's own stand-in, thin lines
    -- in the game frame's colours, a slim title bar and corner glints.
    local WINDOW_EDGE = {
        { 51, 31, 14 }, { 182, 150, 104 }, { 177, 150, 109 }, { 49, 31, 16 },
        { 112, 76, 38 }, { 59, 41, 25 }, { 10, 7, 6 },
    }
    local TITLE_RULE = { { 26, 17, 12 }, { 58, 39, 18 }, { 107, 74, 34 }, { 93, 67, 37 }, { 40, 16, 4 } }
    local function LinedArt(f)
        for i, c in ipairs(WINDOW_EDGE) do
            local d = i - 1
            local function Line()
                local t = f:CreateTexture(nil, "BORDER")
                t:SetTexture(WHITE)
                t:SetVertexColor(c[1] / 255, c[2] / 255, c[3] / 255, 1)
                return t
            end
            local top = Line(); top:SetPoint("TOPLEFT", d, -d); top:SetPoint("TOPRIGHT", -d, -d); top:SetHeight(1)
            local left = Line(); left:SetPoint("TOPLEFT", d, -d); left:SetPoint("BOTTOMLEFT", d, d); left:SetWidth(1)
            local right = Line(); right:SetPoint("TOPRIGHT", -d, -d); right:SetPoint("BOTTOMRIGHT", -d, d); right:SetWidth(1)
            local bottom = Line(); bottom:SetPoint("BOTTOMLEFT", d, d); bottom:SetPoint("BOTTOMRIGHT", -d, d); bottom:SetHeight(1)
        end
        local bar = f:CreateTexture(nil, "BACKGROUND", nil, 2)
        bar:SetPoint("TOPLEFT", 7, -7)
        bar:SetPoint("TOPRIGHT", -7, -7)
        bar:SetHeight(TITLE_H - 10)
        bar:SetTexture(WHITE)
        bar:SetVertexColor(0.15, 0.095, 0.06, 1)
        for i, c in ipairs(TITLE_RULE) do
            local t = f:CreateTexture(nil, "BORDER")
            t:SetTexture(WHITE)
            t:SetVertexColor(c[1] / 255, c[2] / 255, c[3] / 255, 1)
            t:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -(i - 1))
            t:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -(i - 1))
            t:SetHeight(1)
        end
        for _, p in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
            local glint = f:CreateTexture(nil, "ARTWORK")
            glint:SetTexture(WHITE)
            glint:SetVertexColor(0.85, 0.77, 0.62, 1)
            glint:SetSize(3, 3)
            glint:SetPoint(p, (p:find("LEFT") and 1 or -1), (p:find("TOP") and -1 or 1))
        end
    end

    -- ------------------------------------------------------ moving, scaling
    -- Each window's place is kept by its top-left corner (so a longer list
    -- grows downwards), in its own scale's units, on the screen.
    local function OnScreen(f, left, top)
        local s = f:GetEffectiveScale() or 1
        local u = ((UIParent and UIParent:GetEffectiveScale()) or 1) / s
        local sw = ((UIParent and UIParent:GetWidth()) or 0) * u
        local sh = ((UIParent and UIParent:GetHeight()) or 0) * u
        local w, h = f:GetWidth() or 0, f:GetHeight() or 0
        if sw > w then left = math.max(0, math.min(left, sw - w)) end
        if sh > h then top = math.max(h, math.min(top, sh)) end
        return left, top
    end

    local function SavePosition(f)
        local left, top = f:GetLeft(), f:GetTop()
        if not left or not top then return end
        left, top = OnScreen(f, left, top)
        local slot = Slot(f.slot)
        slot.left, slot.top = math.floor(left + 0.5), math.floor(top + 0.5)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", slot.left, slot.top)
    end

    -- A window without a place of its own opens under the window before it
    -- (or, for the first, top right of the screen).
    local function Place(f)
        local slot = Slot(f.slot)
        f:ClearAllPoints()
        if type(slot.left) == "number" and type(slot.top) == "number" then
            f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", slot.left, slot.top)
            return
        end
        local prev = windows[f.slot - 1]
        local left, bottom = prev and prev:IsShown() and prev:GetLeft(), prev and prev:IsShown() and prev:GetBottom()
        if left and bottom then
            local ratio = (prev:GetEffectiveScale() or 1) / (f:GetEffectiveScale() or 1)
            f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * ratio, bottom * ratio - WINDOW_GAP)
            SavePosition(f)
        else
            f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -330, -230)
        end
    end

    local function WindowOf(region)
        while region and not region.fdjTracker do region = region:GetParent() end
        return region
    end

    -- Moving follows the cursor's travel from where the drag began, in the
    -- window's own units. The game's own moving (StartMoving) re-anchors the
    -- window to the screen when it is picked up and to the nearest screen
    -- corner when it is let go, which made it jump sideways now and then.
    local mover = CreateFrame("Frame")
    mover:Hide()
    local function MoveTo(f)
        local x, y = GetCursorPosition()
        local s = f:GetEffectiveScale() or 1
        local left, top = OnScreen(f, mover.left + (x - mover.x) / s, mover.top + (y - mover.y) / s)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
    local function MoveEnd()
        local f = mover.window
        mover.window = nil
        mover:Hide()
        if not f then return end
        dragEndedAt = (GetTime and GetTime()) or 0
        SavePosition(f)
    end
    mover:SetScript("OnUpdate", function(self)
        local f = self.window
        if not f or not f:IsShown() then
            MoveEnd()
            return
        end
        MoveTo(f)
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then MoveEnd() end
    end)

    local function MoveStart(self)
        local f = WindowOf(self)
        if not f then return end
        local left, top = f:GetLeft(), f:GetTop()
        if not left or not top then return end
        mover.window, mover.left, mover.top = f, left, top
        mover.x, mover.y = GetCursorPosition()
        mover:Show()
    end

    local function MoveStop(self)
        local f = mover.window
        if not f or f ~= WindowOf(self) then return end
        MoveTo(f)
        MoveEnd()
    end

    -- A drag ends with the mouse button going up over a row: not a click.
    local function JustDragged()
        return GetTime and (GetTime() - dragEndedAt) < 0.25
    end

    -- New scale, keeping the top-left corner where it is.
    local function ScaleTo(f, scale)
        scale = math.max(MIN_SCALE, math.min(MAX_SCALE, scale))
        local eff = f:GetEffectiveScale()
        local left, top = f:GetLeft(), f:GetTop()
        f:SetScale(scale)
        if left and top then
            local now = f:GetEffectiveScale()
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * eff / now, top * eff / now)
        end
    end

    local function ShowJournal()
        local journal = _G.ForeverDungeonJournalFrame
        if not journal then return nil end
        if not journal:IsShown() then journal:Show() end
        return journal
    end

    local function OpenInJournal(name, questID)
        if not name or not FDJ.OpenQuestPage or not ShowJournal() then return end
        FDJ.OpenQuestPage(name, questID)
    end

    local function OpenChainStep(name, questID, stepID)
        if not name or not ShowJournal() then return end
        if FDJ.OpenQuestChainStep then
            FDJ.OpenQuestChainStep(name, questID, stepID)
        elseif FDJ.OpenQuestPage then
            FDJ.OpenQuestPage(name, questID)
        end
    end

    -- ------------------------------------------------------------- tooltips
    local function TooltipBeside(owner, gap)
        GameTooltip:SetOwner(owner, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        local f = WindowOf(owner)
        local x = f and f:GetCenter()
        local onRight = false
        if x and UIParent then
            local ratio = (f:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
            onRight = x * ratio > (UIParent:GetWidth() or 0) / 2
        end
        if onRight then
            GameTooltip:SetPoint("TOPRIGHT", owner, "TOPLEFT", -gap, 4)
        else
            GameTooltip:SetPoint("TOPLEFT", owner, "TOPRIGHT", gap, 4)
        end
    end

    local function ShowRowTooltip(row)
        local info = row.info
        if not info then return end
        local quest = info.quest
        TooltipBeside(row, SIDE + 6)
        GameTooltip:SetText(info.name or "", 1, 0.82, 0, 1, true)
        if info.state == "done" then
            GameTooltip:AddLine(T("TRACK_DONE"), GREEN[1], GREEN[2], GREEN[3])
        elseif info.state == "ready" then
            GameTooltip:AddLine(T("TRACK_READY"), GREEN[1], GREEN[2], GREEN[3])
        elseif info.state == "log" then
            GameTooltip:AddLine(T("TRACK_IN_LOG"), 1.00, 0.82, 0.10)
        elseif quest.requires then
            if info.low then
                GameTooltip:AddLine(T("AVAILABLE_FROM_LEVEL", quest.requires), 1.00, 0.30, 0.30)
            else
                GameTooltip:AddLine(T("AVAILABLE_FROM_LEVEL", quest.requires), 0.80, 0.80, 0.80)
            end
        end
        local goal = Field(quest.id, "objective", quest.objective)
        if type(goal) == "string" and goal ~= "" and info.state ~= "done" then
            GameTooltip:AddLine(goal, 1, 1, 1, true)
        end
        if info.state == "todo" and quest.pickup then
            GameTooltip:AddLine(Hex(GOLD) .. T("STARTS_AT") .. ":|r " .. (Field(quest.id, "pickup", quest.pickup) or ""), 0.90, 0.90, 0.90, true)
        elseif (info.state == "log" or info.state == "ready") and quest.turnin then
            GameTooltip:AddLine(Hex(GOLD) .. T("TURN_IN") .. ":|r " .. (Field(quest.id, "turnin", quest.turnin) or ""), 0.90, 0.90, 0.90, true)
        end
        GameTooltip:AddLine(T("TRACK_CLICK"), 0.55, 0.55, 0.55)
        GameTooltip:Show()
    end

    -- The chain step under a quest: its own page in the journal.
    local function ShowStepTooltip(button)
        local row = button:GetParent()
        local info = row and row.info
        local step = info and info.step
        if not step then return end
        local details = FDJ.QUEST_PREREQ_DETAILS and FDJ.QUEST_PREREQ_DETAILS[step.id] or {}
        TooltipBeside(button, SIDE + TEXT_X + 6)
        GameTooltip:SetText(info.stepName or "", 1, 0.82, 0, 1, true)
        GameTooltip:AddLine(T("TRACK_IN_LOG"), 1.00, 0.82, 0.10)
        local goal = Field(step.id, "objective", details.objective)
        if type(goal) == "string" and goal ~= "" then GameTooltip:AddLine(goal, 1, 1, 1, true) end
        local turnin = Field(step.id, "turnin", details.turnin)
        if type(turnin) == "string" and turnin ~= "" then
            GameTooltip:AddLine(Hex(GOLD) .. T("TURN_IN") .. ":|r " .. turnin, 0.90, 0.90, 0.90, true)
        end
        GameTooltip:AddLine(T("TRACK_CLICK"), 0.55, 0.55, 0.55)
        GameTooltip:Show()
    end

    -- ----------------------------------------------------------------- rows
    local function Highlight(button, x1, y1, x2, y2)
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetPoint("TOPLEFT", button, "TOPLEFT", x1, y1)
        highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", x2, y2)
        highlight:SetColorTexture(1, 0.82, 0.25, 0.08)
        return highlight
    end

    -- One step of an unfolded chain: its tick, ! or ? (the ! and a ready ?
    -- show on the map where to pick it up / hand it in), "1. Name" and, in
    -- the log, its progress. A click on the line opens the step in the journal.
    local function ShowChainLineTooltip(line)
        local entry = line.entry
        if not entry then return end
        local id, details = entry.step.id, entry.details
        TooltipBeside(line, SIDE + TEXT_X + 6)
        GameTooltip:SetText(entry.name or "", 1, 0.82, 0, 1, true)
        if entry.state == "done" then
            GameTooltip:AddLine(T("TRACK_DONE"), GREEN[1], GREEN[2], GREEN[3])
        elseif entry.state == "ready" then
            GameTooltip:AddLine(T("TRACK_READY"), GREEN[1], GREEN[2], GREEN[3])
        elseif entry.state == "log" then
            GameTooltip:AddLine(T("TRACK_IN_LOG"), 1.00, 0.82, 0.10)
        end
        -- choiceline (2.0.40): a choice's line has no one objective
        local goal = (not entry.combined) and Field(id, "objective", details.objective) or nil
        if type(goal) == "string" and goal ~= "" and entry.state ~= "done" then GameTooltip:AddLine(goal, 1, 1, 1, true) end
        local turnin = Field(id, "turnin", details.turnin)
        if type(turnin) == "string" and turnin ~= "" and entry.state ~= "done" then
            GameTooltip:AddLine(Hex(GOLD) .. T("TURN_IN") .. ":|r " .. turnin, 0.90, 0.90, 0.90, true)
        end
        GameTooltip:AddLine(T("TRACK_CLICK"), 0.55, 0.55, 0.55)
        GameTooltip:Show()
    end

    local function MakeChainLine(row)
        local line = CreateFrame("Button", nil, row)
        line:RegisterForClicks("LeftButtonUp")
        line:RegisterForDrag("LeftButton")
        line.text = line:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
        line.text:SetPoint("TOPLEFT", line, "TOPLEFT", STEP_TEXT_X, 0)
        line.text:SetJustifyH("LEFT")
        line.text:SetWordWrap(true)
        if line.text.SetSpacing then line.text:SetSpacing(2) end
        Highlight(line, -3, 2, 3, -2):SetColorTexture(1, 0.82, 0.25, 0.14)
        local mark = CreateFrame("Button", nil, line)
        line.mark = mark
        mark:SetSize(STEP_ICON, STEP_ICON)
        mark:SetPoint("CENTER", line, "TOPLEFT", STEP_ICON / 2, -6)
        mark:SetFrameLevel(line:GetFrameLevel() + 2)
        mark:RegisterForClicks("LeftButtonUp")
        mark:RegisterForDrag("LeftButton")
        mark.icon = mark:CreateTexture(nil, "ARTWORK")
        mark.icon:SetAllPoints()
        mark.glow = mark:CreateTexture(nil, "HIGHLIGHT")
        mark.glow:SetAllPoints()
        mark.glow:SetBlendMode("ADD")
        mark:SetScript("OnClick", function(self)
            local entry = self:GetParent().entry
            if JustDragged() or not entry then return end
            local spot, turnIn = entry.start, nil
            if entry.state == "ready" or entry.state == "log" then spot, turnIn = entry.turnin, not entry.goTo end -- (stepgoto)
            local show = FDJ.MapMarkers and FDJ.MapMarkers.ShowRecordedLocationOnMap
            if not spot or not show then return end
            spot = (FDJ.LocalizeMapLocation and FDJ.LocalizeMapLocation(spot)) or spot
            FDJ.pendingMarkerQuestTitle = (entry.arrowName or entry.name)
            FDJ.pendingMarkerTurnIn = turnIn
            FDJ.pendingMarkerQuestID = entry.step and entry.step.id -- autoclear
            FDJ.pendingMarkerObjective = entry.goTo and true or nil -- (stepgoto)
            show(spot, spot.label)
        end)
        mark:SetScript("OnEnter", function(self)
            local entry = self:GetParent().entry
            if not entry then return end
            local id, details = entry.step.id, entry.details
            TooltipBeside(self, SIDE + 4)
            local where
            if entry.goTo and entry.state == "log" then -- (stepgoto)
                GameTooltip:SetText(T("SHOW_ON_MAP"), 1, 0.82, 0)
                where = FDJ.LocalizeFreeText and FDJ.LocalizeFreeText(entry.turnin.label) or entry.turnin.label
            elseif entry.state == "ready" or entry.state == "log" then
                GameTooltip:SetText(T("SHOW_TURN_IN"), 1, 0.82, 0)
                where = Field(id, "turnin", details.turnin)
            else
                GameTooltip:SetText(T("SHOW_GIVER_ON_MAP"), 1, 0.82, 0)
                where = Field(id, "pickup", details.pickup)
            end
            if type(where) == "string" and where ~= "" then GameTooltip:AddLine(where, 1, 1, 1, true) end
            GameTooltip:Show()
        end)
        mark:SetScript("OnLeave", function() GameTooltip:Hide() end)
        mark:SetScript("OnDragStart", MoveStart)
        mark:SetScript("OnDragStop", MoveStop)
        line:SetScript("OnClick", function(self)
            local entry = self.entry
            local info = self:GetParent().info
            if JustDragged() or not entry or not info then return end
            if entry.step.id and FDJ.TryLinkQuest and FDJ.TryLinkQuest(entry.step.id, entry.name, nil) then return end
            local f = WindowOf(self)
            OpenChainStep(f and f.dungeon, info.quest.id, entry.step.id)
        end)
        line:SetScript("OnDragStart", MoveStart)
        line:SetScript("OnDragStop", MoveStop)
        line:SetScript("OnEnter", ShowChainLineTooltip)
        line:SetScript("OnLeave", function() GameTooltip:Hide() end)
        line:Hide()
        return line
    end

    -- Fills one chain line; returns its height.
    local function SetChainLine(line, entry, width)
        line.entry = entry
        local mark, state = line.mark, entry.state
        local icon, grey, clickable
        if state == "done" then
            icon = ICON_DONE
        elseif state == "ready" then
            icon, clickable = ICON_LOG, entry.turnin ~= nil
        elseif state == "log" then
            icon, grey, clickable = ICON_LOG, true, entry.turnin ~= nil
        elseif state == "next" then
            icon, clickable = ICON_TODO, entry.start ~= nil
        end
        -- chainready: a step ready to hand in gets the round ? right after
        -- its name, as in the one-step view (not the small icon in front):
        -- a click shows where it is handed in and targets the NPC when near.
        local roundMark = state == "ready" and entry.turnin ~= nil and FDJ.CreateTurnInButton ~= nil
        if roundMark then icon = nil end
        mark.icon:SetTexture(icon)
        mark.icon:SetDesaturated(grey == true)
        mark.icon:SetAlpha(grey and 0.75 or 1)
        mark.glow:SetTexture(icon)
        mark.glow:SetShown(clickable == true)
        mark:EnableMouse(clickable == true)
        mark:SetShown(icon ~= nil)
        local color = (state == "done" and DONE) or ((state == "ready" or state == "log") and GOLD)
            or (state == "next" and TODO) or GREY
        local label = (entry.label or (entry.index .. ". ")) .. (entry.name or "")
        local parts = { Hex(color) .. label .. "|r" }
        for _, text in ipairs(entry.parts or {}) do parts[#parts + 1] = text end
        local textW = math.max(40, width - STEP_TEXT_X)
        line.text:SetWidth(textW)
        line.text:SetText(table.concat(parts, "\n"))
        local height = math.max(12, line.text:GetStringHeight() or 12)
        line:SetSize(width, height)
        if roundMark then
            if not line.turnInMark then
                line.turnInMark = FDJ.CreateTurnInButton(line, 16)
                line.turnInMark:SetFrameLevel(line:GetFrameLevel() + 3)
                line.measure = line:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
                line.measure:Hide()
            end
            line.measure:SetText(label)
            local nameW = line.measure:GetStringWidth() or 0
            local size = FDJ.StepMarkSize()
            FDJ.ResizeTurnInButton(line.turnInMark, size)
            line.turnInMark:ClearAllPoints()
            line.turnInMark:SetPoint("LEFT", line, "TOPLEFT", STEP_TEXT_X + math.min(nameW + 4, math.max(0, textW - size)), -6)
            local details = entry.details or {}
            FDJ.SetTurnInButton(line.turnInMark,
                { id = entry.step and entry.step.id, turnin = details.turnin, turninMap = details.turninMap }, entry.name)
        elseif line.turnInMark then
            FDJ.SetTurnInButton(line.turnInMark, nil)
        end
        line:Show()
        return height
    end

    -- The quest button pressed in: the darker ring and the ? one step down
    -- and right, as in the game.
    local function PressMark(mark, down)
        local button = mark.button
        if not button then return end
        button.ring:SetAtlas(down and POI_RING_DOWN or POI_RING)
        button.display:ClearAllPoints()
        button.display:SetPoint("CENTER", button, "CENTER", down and 1 or 0, down and -1 or 0)
        if mark.sharp then
            local shade = down and 0.8 or 1
            mark.sharp:SetVertexColor(shade, shade, shade)
            mark.sharp:ClearAllPoints()
            mark.sharp:SetPoint("CENTER", button, "CENTER", down and 1 or 0, down and -1 or 0)
        end
    end

    local function MakeRow(parent)
        local row = CreateFrame("Button", nil, parent)
        row:RegisterForClicks("LeftButtonUp")
        row:RegisterForDrag("LeftButton")

        -- The icon is a button: the ? of a quest ready to turn in is the
        -- game's own quest button and shows on the map where to hand the
        -- quest in (like Show Turn In).
        -- The insecure action template lets a click target the NPC when
        -- near (FDJ.MapMarkers.ConfigureTargetAndMarkAction, set on mouse-over).
        local okMark, made = pcall(CreateFrame, "Button", nil, row, "InsecureActionButtonTemplate")
        local mark = okMark and made or CreateFrame("Button", nil, row)
        mark._fdjCanTarget = (okMark and made) and true or false
        if mark._fdjCanTarget then mark:SetAttribute("useOnKeyDown", false) end
        row.mark = mark
        mark:SetSize(ICON_SIZE, ICON_SIZE)
        mark:SetPoint("CENTER", row, "TOPLEFT", ICON_X, -7)
        mark:RegisterForClicks("LeftButtonUp")
        mark:RegisterForDrag("LeftButton")
        row.icon = mark:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(ICON_SIZE, ICON_SIZE)
        row.icon:SetPoint("CENTER", mark, "CENTER", 0, 0)
        if HasQuestButton() then
            -- Built like the game's: ring, glow over the ring on mouse-over,
            -- the ? on top.
            local button = CreateFrame("Frame", nil, mark)
            mark.button = button
            button:SetSize(POI_SIZE, POI_SIZE)
            button:SetPoint("CENTER", mark, "CENTER", 0, 0)
            button.ring = button:CreateTexture(nil, "ARTWORK")
            button.ring:SetAtlas(POI_RING)
            button.ring:SetSize(POI_SIZE, POI_SIZE)
            button.ring:SetPoint("CENTER")
            button.lit = button:CreateTexture(nil, "OVERLAY")
            button.lit:SetAtlas(POI_LIT)
            button.lit:SetBlendMode("ADD")
            button.lit:SetSize(POI_SIZE, POI_SIZE)
            button.lit:SetPoint("CENTER")
            button.lit:Hide()
            button.display = CreateFrame("Frame", nil, button)
            button.display:SetSize(POI_SIZE, POI_SIZE)
            button.display:SetFrameLevel(button:GetFrameLevel() + 1)
            button.icon = button.display:CreateTexture(nil, "ARTWORK")
            button.icon:SetAtlas(POI_TURN_IN)
            button.icon:SetSize(POI_SIZE, POI_SIZE)
            button.icon:SetPoint("CENTER")
            PressMark(mark, false)
            button:Hide()
        else
            mark.halo = mark:CreateTexture(nil, "BACKGROUND")
            mark.halo:SetSize(ICON_SIZE + 10, ICON_SIZE + 10)
            mark.halo:SetPoint("CENTER")
            mark.halo:SetTexture(GLOW)
            mark.halo:SetBlendMode("ADD")
            mark.halo:SetAlpha(0.55)
        end
        -- Mouse-over light on a clickable plain icon (the ! of a quest to
        -- pick up; the ? too when the game's button art is missing).
        mark.glow = mark:CreateTexture(nil, "HIGHLIGHT")
        mark.glow:SetAllPoints(row.icon)
        mark.glow:SetTexture(ICON_LOG)
        mark.glow:SetBlendMode("ADD")
        -- PostClick keeps the template's own click (the target macro).
        mark:SetScript(mark._fdjCanTarget and "PostClick" or "OnClick", function(self)
            local info = self:GetParent().info
            if JustDragged() or not info then return end
            if info.state == "todo" then
                -- Where to pick it up: the giver on the world map, or inside
                -- the dungeon on the journal's map.
                if info.start then
                    local spot = (FDJ.LocalizeMapLocation and FDJ.LocalizeMapLocation(info.start)) or info.start
                    local show = FDJ.MapMarkers and FDJ.MapMarkers.ShowRecordedLocationOnMap
                    if not show then return end
                    FDJ.pendingMarkerQuestTitle = info.name
                    FDJ.pendingMarkerQuestID = info.quest and info.quest.id -- autoclear
                    show(spot, spot.label or info.quest.pickup)
                elseif info.dungeonStart and FDJ.ShowTurnInOnDungeonMap and ShowJournal() then
                    FDJ.ShowTurnInOnDungeonMap(info.dungeonStart.dungeon, info.dungeonStart.spot, info.name, info.quest.id, true)
                end
                return
            end
            local inside = info.dungeonTurnin
            if inside then
                -- Handed in inside a dungeon: its map in the journal, NPC marked.
                if FDJ.ShowTurnInOnDungeonMap and ShowJournal() then
                    FDJ.ShowTurnInOnDungeonMap(inside.dungeon, inside.spot, info.name, info.quest.id)
                end
                return
            end
            if not info.turnin then return end
            local spot = (FDJ.LocalizeMapLocation and FDJ.LocalizeMapLocation(info.turnin)) or info.turnin
            local show = FDJ.MapMarkers and FDJ.MapMarkers.ShowRecordedLocationOnMap
            if not show then return end
            FDJ.pendingMarkerQuestTitle = info.name
            FDJ.pendingMarkerTurnIn = not info.goTo
            FDJ.pendingMarkerQuestID = info.quest and info.quest.id -- autoclear
            FDJ.pendingMarkerObjective = info.goTo and true or nil
            show(spot, spot.label)
        end)
        mark:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then PressMark(self, true) end
        end)
        mark:SetScript("OnMouseUp", function(self)
            PressMark(self, false)
        end)
        mark:SetScript("OnEnter", function(self)
            local info = self:GetParent().info
            if not info then return end
            -- The NPC this ? / ! leads to: targeted by the click when near.
            local configure = FDJ.MapMarkers and FDJ.MapMarkers.ConfigureTargetAndMarkAction
            if configure then configure(self, (info.state == "todo" and info.start) or info.turnin or nil, true) end
            if info.state == "todo" then
                if not (info.start or info.dungeonStart) then return end
                TooltipBeside(self, SIDE + 4)
                GameTooltip:SetText(T("SHOW_GIVER_ON_MAP"), 1, 0.82, 0)
                local where = Field(info.quest.id, "pickup", info.quest.pickup)
                if type(where) == "string" and where ~= "" then GameTooltip:AddLine(where, 1, 1, 1, true) end
                GameTooltip:Show()
                return
            end
            if not (info.turnin or info.dungeonTurnin) then return end
            if self.button then self.button.lit:Show() end
            if self.halo then self.halo:SetAlpha(1) end
            TooltipBeside(self, SIDE + 4)
            local where
            if info.goTo then
                GameTooltip:SetText(T("SHOW_ON_MAP"), 1, 0.82, 0)
                where = info.quest.objectiveWhere
            else
                GameTooltip:SetText(T("SHOW_TURN_IN"), 1, 0.82, 0)
                where = Field(info.quest.id, "turnin", info.quest.turnin)
            end
            if type(where) == "string" and where ~= "" then GameTooltip:AddLine(where, 1, 1, 1, true) end
            GameTooltip:Show()
        end)
        mark:SetScript("OnLeave", function(self)
            if self.button then self.button.lit:Hide() end
            if self.halo then self.halo:SetAlpha(0.55) end
            GameTooltip:Hide()
        end)
        mark:SetScript("OnDragStart", function(self)
            PressMark(self, false)
            MoveStart(self)
        end)
        mark:SetScript("OnDragStop", function(self)
            PressMark(self, false)
            MoveStop(self)
        end)
        mark:EnableMouse(false)

        -- "In Dungeon" icon (the journal's quest list one) beside the ! of a
        -- quest still to pick up inside the dungeon. Clicks go to the row.
        local door = CreateFrame("Frame", nil, row)
        row.door = door
        door:SetSize(DOOR_SIZE, DOOR_SIZE)
        door:SetPoint("CENTER", row, "TOPLEFT", DOOR_X, -7)
        local inset = math.floor(DOOR_SIZE / 5)
        door:SetHitRectInsets(inset, inset, inset, inset)
        door.tex = door:CreateTexture(nil, "ARTWORK")
        door.tex:SetAllPoints()
        local atlas = C_Texture and type(C_Texture.GetAtlasInfo) == "function" and C_Texture.GetAtlasInfo("Dungeon")
        if atlas and door.tex.SetAtlas then
            door.tex:SetAtlas("Dungeon")
        else
            -- A square icon fills its square: drawn smaller to match.
            door.tex:ClearAllPoints()
            door.tex:SetPoint("CENTER")
            door.tex:SetSize(DOOR_SIZE * 0.66, DOOR_SIZE * 0.66)
            door.tex:SetTexture("Interface\\Icons\\INV_Misc_Rune_01")
            door.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        if door.SetMouseClickEnabled and door.SetMouseMotionEnabled then
            door:SetMouseMotionEnabled(true)
            door:SetMouseClickEnabled(false)
        else
            door:EnableMouse(true)
        end
        door:SetScript("OnEnter", function(self)
            TooltipBeside(self, SIDE + 4)
            GameTooltip:SetText(T("IN_DUNGEON"), 1, 0.82, 0)
            GameTooltip:Show()
        end)
        door:SetScript("OnLeave", function() GameTooltip:Hide() end)
        door:Hide()

        -- Chain icon after the ! of a quest that needs a chain first: a click
        -- lists the chain's steps under the quest (and folds them again).
        local chainIcon = CreateFrame("Button", nil, row)
        row.chainIcon = chainIcon
        chainIcon:SetSize(CHAIN_SIZE, CHAIN_SIZE)
        chainIcon:RegisterForClicks("LeftButtonUp")
        chainIcon:RegisterForDrag("LeftButton")
        chainIcon.tex = chainIcon:CreateTexture(nil, "ARTWORK")
        chainIcon.tex:SetAllPoints()
        chainIcon.tex:SetTexture(CHAIN)
        local chainLit = chainIcon:CreateTexture(nil, "HIGHLIGHT")
        chainLit:SetAllPoints()
        chainLit:SetTexture(CHAIN)
        chainLit:SetBlendMode("ADD")
        chainIcon:SetScript("OnClick", function(self)
            local info = self:GetParent().info
            if JustDragged() or not info or not info.chain then return end
            local open = ChainsOpen()
            open[info.quest.id] = not open[info.quest.id] or nil
            if FDJ.RefreshQuestTracker then FDJ.RefreshQuestTracker() end
        end)
        chainIcon:SetScript("OnEnter", function(self)
            TooltipBeside(self, SIDE + 4)
            GameTooltip:SetText(T("REQUIRED_QUESTS"), 1, 0.82, 0.25)
            GameTooltip:AddLine(T("SHOW_WHOLE_CHAIN"), 0.85, 0.85, 0.85)
            GameTooltip:Show()
        end)
        chainIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
        chainIcon:SetScript("OnDragStart", MoveStart)
        chainIcon:SetScript("OnDragStop", MoveStop)
        chainIcon:Hide()
        row.chainLines = {}
        -- dungeonroute (2.0.5): on the route or left out (shown while the
        -- dungeon's route is on).
        local okBox, box = pcall(CreateFrame, "CheckButton", nil, row, "UICheckButtonTemplate")
        if okBox and box then
            row.routeBox = box
            box:SetSize(20, 20)
            box:SetPoint("TOPRIGHT", row, "TOPRIGHT", 4, 3)
            box:SetScript("OnClick", function(self)
                local owner = self:GetParent()
                local info, window = owner.info, owner:GetParent()
                local name = window and window.dungeon
                if not (info and info.quest and info.quest.id and name) then return end
                RouteSkips(name)[info.quest.id] = (not self:GetChecked()) and true or nil
                if PlaySound and SOUNDKIT then
                    local sound = self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
                    if sound then pcall(PlaySound, sound) end
                end
                if FDJ.RefreshQuestTracker then FDJ.RefreshQuestTracker() end
            end)
            box:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(T(self:GetChecked() and "ROUTE_BOX_ON" or "ROUTE_BOX_OFF"), 1, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            box:SetScript("OnLeave", function() GameTooltip:Hide() end)
            box:Hide()
        end

        -- The quest's start item, once looted: its icon in place of the !.
        -- The game's action button template uses the item on a click (out of
        -- combat) and the quest it opens is accepted.
        local ok, use = pcall(CreateFrame, "Button", nil, row, "InsecureActionButtonTemplate")
        if not ok or not use then use = nil end
        if use then
            row.use = use
            use:SetSize(ITEM_SIZE, ITEM_SIZE)
            use:SetPoint("CENTER", row, "TOPLEFT", ICON_X, -7)
            use:SetFrameLevel(mark:GetFrameLevel() + 2)
            use:RegisterForClicks("LeftButtonUp")
            use:SetAttribute("useOnKeyDown", false)
            use:SetAttribute("type", "item")
            use.icon = use:CreateTexture(nil, "ARTWORK")
            use.icon:SetAllPoints()
            use.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            local lit = use:CreateTexture(nil, "HIGHLIGHT")
            lit:SetAllPoints()
            lit:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
            lit:SetBlendMode("ADD")
            use:SetScript("PreClick", function(self)
                local info = self:GetParent().info
                if InCombatLockdown and InCombatLockdown() then
                    if UIErrorsFrame and ERR_NOT_IN_COMBAT then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1) end
                    return
                end
                if info and info.quest then
                    FDJ.trackerAcceptQuest = { id = info.quest.id, at = GetTime and GetTime() or 0 }
                end
            end)
            use:SetScript("OnEnter", function(self)
                TooltipBeside(self, SIDE + 4)
                if self.itemID and GameTooltip.SetItemByID then
                    GameTooltip:SetItemByID(self.itemID)
                else
                    local info = self:GetParent().info
                    GameTooltip:SetText(info and info.name or "", 1, 0.82, 0)
                end
                GameTooltip:AddLine(T("TRACK_ACCEPT"), GREEN[1], GREEN[2], GREEN[3])
                GameTooltip:Show()
            end)
            use:SetScript("OnLeave", function() GameTooltip:Hide() end)
            use:Hide()
        end

        row.title = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
        row.title:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_X, 0)
        row.title:SetJustifyH("LEFT")
        row.title:SetWordWrap(true)

        row.sub = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
        row.sub:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
        row.sub:SetJustifyH("LEFT")
        row.sub:SetWordWrap(true)
        if row.sub.SetSpacing then row.sub:SetSpacing(2) end

        Highlight(row, -5, 3, 5, -3)

        -- Chain step line: a button of its own on top of the row.
        local step = CreateFrame("Button", nil, row)
        row.step = step
        step:RegisterForClicks("LeftButtonUp")
        step:RegisterForDrag("LeftButton")
        step.text = step:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
        step.text:SetPoint("TOPLEFT", step, "TOPLEFT", 0, 0)
        step.text:SetJustifyH("LEFT")
        step.text:SetWordWrap(true)
        if step.text.SetSpacing then step.text:SetSpacing(2) end
        Highlight(step, -3, 2, 3, -2):SetColorTexture(1, 0.82, 0.25, 0.14)
        step:SetScript("OnClick", function(self)
            local info = self:GetParent().info
            if JustDragged() or not info or not info.step then return end
            if FDJ.TryLinkQuest and FDJ.TryLinkQuest(info.step.id, info.stepName, nil) then return end
            local f = WindowOf(self)
            OpenChainStep(f and f.dungeon, info.quest.id, info.step.id)
        end)
        step:SetScript("OnDragStart", MoveStart)
        step:SetScript("OnDragStop", MoveStop)
        step:SetScript("OnEnter", ShowStepTooltip)
        step:SetScript("OnLeave", function() GameTooltip:Hide() end)
        step:Hide()

        row:SetScript("OnClick", function(self)
            if JustDragged() or not self.info then return end
            local quest = self.info.quest
            if FDJ.TryLinkQuest and FDJ.TryLinkQuest(quest.id, self.info.name, quest.level) then return end
            local f = WindowOf(self)
            OpenInJournal(f and f.dungeon, quest.id)
        end)
        row:SetScript("OnDragStart", MoveStart)
        row:SetScript("OnDragStop", MoveStop)
        row:SetScript("OnEnter", ShowRowTooltip)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return row
    end

    local Refresh, Layout

    -- --------------------------------------------------------------- window
    local function Build(index)
        if windows[index] then return windows[index] end
        local name = "ForeverDungeonJournalQuestTracker" .. (index > 1 and index or "")
        local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
        windows[index] = f
        f.fdjTracker = true
        f.slot = index
        f:SetSize(WIDTH, COLLAPSED_H)
        -- trackerover (2.0.51): above the game's own quest list (it drew its
        -- lines over the window where the two met), still under the journal
        -- (DIALOG). Was LOW.
        f:SetFrameStrata("MEDIUM")
        f:SetFrameLevel(20)
        f:SetClampedToScreen(true)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        if f.SetDontSavePosition then pcall(f.SetDontSavePosition, f, true) end
        f:SetScript("OnDragStart", MoveStart)
        f:SetScript("OnDragStop", MoveStop)
        -- Same window colour as the Options panel.
        f:SetBackdrop({ bgFile = WHITE, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
        f:SetBackdropColor(0.176, 0.13, 0.15, 0.90)
        local ok, copied = pcall(GameArt, f)
        if not (ok and copied) then
            f.art = nil
            LinedArt(f)
        end

        -- Title bar, as on the Options panel: count on the left, the journal
        -- book and the dungeon in the middle, fold and close on the right.
        local over = CreateFrame("Button", nil, f)
        f.header = over
        over:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        over:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
        over:SetHeight(TITLE_H + 2)
        over:SetFrameLevel(f:GetFrameLevel() + 4)
        over:RegisterForClicks("LeftButtonUp")
        over:RegisterForDrag("LeftButton")
        over:SetScript("OnDragStart", MoveStart)
        over:SetScript("OnDragStop", MoveStop)
        over:SetScript("OnClick", function()
            if JustDragged() then return end
            OpenInJournal(f.dungeon, nil)
        end)

        over.count = over:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontDisableSmall")
        over.count:SetPoint("LEFT", f, "TOPLEFT", 12, -12)

        local close = CreateFrame("Button", nil, over, "UIPanelCloseButton")
        f.close = close
        close:SetPoint("CENTER", f, "TOPRIGHT", -13, -13) -- on the frame corner, like the Options panel
        close:SetFrameLevel(over:GetFrameLevel() + 2)
        close:SetScript("OnClick", function()
            if f.dungeon and FDJ.ToggleQuestTracking then FDJ.ToggleQuestTracking(f.dungeon) end
        end)
        close:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(T("TRACK_STOP"), 1, 1, 1)
            GameTooltip:Show()
        end)
        close:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local fold = CreateFrame("Button", nil, over)
        f.fold = fold
        fold:SetSize(14, 14)
        -- foldleft (2.1.1, M 20 Nov 2026: "move the little minimize icon to the
        -- left of the Dungeon Journal icon"): placed by Layout, just before the book.
        fold:SetPoint("LEFT", f, "TOPLEFT", 46, -12)
        fold:SetFrameLevel(over:GetFrameLevel() + 2)
        fold:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
        fold:SetScript("OnClick", function()
            if not f.dungeon then return end
            local folded = Folded()
            folded[f.dungeon] = not folded[f.dungeon] or nil
            if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
                pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            end
            Layout(f)
        end)

        over.icon = over:CreateTexture(nil, "OVERLAY")
        over.icon:SetSize(15, 15)
        over.icon:SetTexture(BOOK)
        over.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        over.title = over:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
        over.title:SetPoint("LEFT", over.icon, "RIGHT", 4, 0)
        over.title:SetJustifyH("LEFT")
        over.title:SetWordWrap(false)

        -- Bottom-right corner: drag to make the window bigger or smaller
        -- (like the journal's corner), right-click for its normal size.
        local grip = CreateFrame("Button", nil, f)
        f.grip = grip
        grip:SetSize(14, 14)
        grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
        grip:SetFrameLevel(f:GetFrameLevel() + 20)
        grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        grip:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local function FinishScaling(self)
            self.dragging = false
            Slot(f.slot).scale = f:GetScale()
            SavePosition(f)
        end
        grip:SetScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" then return end
            self.startX = GetCursorPosition()
            self.startScale = f:GetScale() or 1
            self.unit = WIDTH * ((UIParent and UIParent:GetEffectiveScale()) or 1)
            self.dragging = true
        end)
        grip:SetScript("OnMouseUp", function(self, button)
            if button == "RightButton" then
                ScaleTo(f, 1)
                FinishScaling(self)
            elseif self.dragging then
                FinishScaling(self)
            end
        end)
        grip:SetScript("OnUpdate", function(self)
            if not self.dragging then return end
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                FinishScaling(self)
                return
            end
            -- Pinned by the top-left corner: the corner moves as far as the
            -- window grows.
            local x = GetCursorPosition()
            local scale = self.startScale + (x - self.startX) / self.unit
            if math.abs(scale - (f:GetScale() or 1)) > 0.004 then ScaleTo(f, scale) end
        end)
        grip:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
            GameTooltip:SetText(T("RESIZE_TIP_TITLE"), 1, 0.82, 0.27)
            GameTooltip:AddLine(T("RESIZE_TIP"), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        grip:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- hoverbits (2.0.13, M 19 Nov 2026: "if I'm not hovering over the
        -- tracking window, the X doesn't show, and not even the rescale mark
        -- in the bottom right. Just have it so they appear on hover"): the
        -- close button and the corner grip are only seen with the mouse over
        -- the window (or while the corner is being dragged).
        close:SetAlpha(0)
        grip:SetAlpha(0)
        f:HookScript("OnUpdate", function(self)
            local over = (self:IsMouseOver(4, -4, -4, 4) or grip.dragging) and true or false
            if over ~= self.fdjHoverBits then
                self.fdjHoverBits = over
                close:SetAlpha(over and 1 or 0)
                grip:SetAlpha(over and 1 or 0)
            end
        end)

        f.rows = {}
        f:SetScale(math.max(MIN_SCALE, math.min(MAX_SCALE, tonumber(Slot(index).scale) or 1)))
        f:Hide()
        return f
    end

    Layout = function(f)
        local name = f and f.dungeon
        if not name then return end
        local quests = QuestsOf(name)
        local over = f.header

        -- Title: the book and the dungeon name, centred together between the
        -- count and the buttons (a very long name is cut short).
        local title = over.title
        title:SetWidth(0)
        title:SetText(FDJ.LocalizeDungeonName and FDJ.LocalizeDungeonName(name) or name)
        local full = (title.GetUnboundedStringWidth and title:GetUnboundedStringWidth()) or title:GetStringWidth() or 0
        -- foldleft (2.1.1): the fold button, the book and the name, centred
        -- together between the count (46 from the left) and the X (25 from
        -- the right); a very long name is cut short.
        local textWidth = math.min(full, WIDTH - 46 - 29 - 18 - 19)
        title:SetWidth(math.ceil(textWidth))
        local blockWidth = 18 + 19 + textWidth
        local left = math.max(46, math.min(math.floor((WIDTH - blockWidth) / 2), WIDTH - 29 - blockWidth))
        f.fold:ClearAllPoints()
        f.fold:SetPoint("LEFT", f, "TOPLEFT", left, -12)
        over.icon:ClearAllPoints()
        over.icon:SetPoint("LEFT", f, "TOPLEFT", left + 18, -12)

        local collapsed = Folded()[name] == true
        f.fold:SetNormalTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
        f.fold:SetPushedTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-Down" or "Interface\\Buttons\\UI-MinusButton-Down")

        local level = PlayerLevel()
        local rowWidth = WIDTH - SIDE * 2
        -- Still to pick up inside the dungeon: "In Dungeon" icon after the !
        -- (gone once the quest or a step of its chain is taken); while any
        -- quest shows it, the names make room for it.
        local infos, extra = {}, 0
        for i, quest in ipairs(quests) do
            local info = RowInfo(quest, level)
            -- Start item looted: its icon replaces the ! and the In Dungeon icon.
            if info.state == "todo" and not info.step then info.startItem = StartItemInBags(quest) end
            info.inside = info.state == "todo" and not info.step and not info.startItem and StartsInDungeon(quest, name)
            -- Icons after the !: the chain's, then the In Dungeon one.
            local icons = (info.chain and 1 or 0) + (info.inside and 1 or 0)
            if icons > extra then extra = icons end
            infos[i] = info
        end
        -- Rows in groups: to hand in, in the log, to pick up (start item in
        -- the bags first, then a chain under way), too low a level, done.
        local function Rank(info)
            if info.state == "ready" then return 1 end
            if info.state == "log" then return 2 end
            if info.state == "done" then return 7 end
            if info.low then return 6 end
            if info.startItem then return 3 end
            if info.step then return 4 end
            return 5
        end
        local order = {}
        for i = 1, #quests do order[i] = i end
        table.sort(order, function(a, b)
            local ra, rb = Rank(infos[a]), Rank(infos[b])
            if ra ~= rb then return ra < rb end
            return a < b
        end)
        local textX = (extra == 0 and TEXT_X) or DOOR_TEXT_X + (extra - 1) * ICON_STEP
        local routed = RouteOn(name) -- dungeonroute (2.0.5): tick boxes at the rows' right
        local routeSkip = routed and RouteSkips(name) or nil
        local textW = rowWidth - textX - (routed and 18 or 0)
        local y = ROWS_TOP
        local done = 0
        for n, i in ipairs(order) do
            local info = infos[i]
            -- Ready to turn in counts as done.
            if info.state == "done" or info.state == "ready" then done = done + 1 end
            local row = f.rows[n]
            if not row then
                row = MakeRow(f)
                f.rows[n] = row
            end
            row.info = info
            row:SetWidth(rowWidth)
            -- Ready to turn in: the game's quest button (clickable when the
            -- journal knows where to hand it in); the rest: plain icons.
            local mark = row.mark
            local clickable = info.turnin ~= nil or info.dungeonTurnin ~= nil
                or info.start ~= nil or info.dungeonStart ~= nil
            local questButton = mark.button ~= nil and info.state == "ready"
            -- A quest ready to hand in has no icons after its ?, so the ? sits
            -- in the middle of the space before the quest's name, not in line
            -- with the ! of the other quests.
            mark:ClearAllPoints()
            mark:SetPoint("CENTER", row, "TOPLEFT",
                info.state == "ready" and math.max(ICON_X, (textX - 3) / 2) or ICON_X, -7)
            local item = row.use ~= nil and info.startItem or nil
            if row.use then
                if item then
                    row.use.itemID = item
                    row.use:SetAttribute("item", "item:" .. item)
                    local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(item))
                        or (GetItemIcon and GetItemIcon(item)) or "Interface\\Icons\\INV_Misc_QuestionMark"
                    row.use.icon:SetTexture(icon)
                    row.use.icon:SetDesaturated(info.low == true)
                end
                row.use:SetShown(item ~= nil)
            end
            row.icon:SetShown(not questButton and not item)
            row.icon:SetTexture(info.icon)
            row.icon:SetDesaturated(info.grey == true)
            row.icon:SetAlpha(info.grey and 0.75 or 1)
            local iconX = DOOR_X
            row.chainIcon:ClearAllPoints()
            row.chainIcon:SetPoint("CENTER", row, "TOPLEFT", iconX, -7)
            row.chainIcon:SetShown(info.chain ~= nil)
            if info.chain then
                row.chainIcon.tex:SetDesaturated(info.low == true)
                row.chainIcon.tex:SetAlpha(info.low and 0.75 or 1)
                iconX = iconX + ICON_STEP
            end
            row.door:ClearAllPoints()
            row.door:SetPoint("CENTER", row, "TOPLEFT", iconX, -7)
            row.door:SetShown(info.inside)
            if info.inside then
                row.door.tex:SetDesaturated(info.low == true)
                row.door.tex:SetAlpha(info.low and 0.75 or 1)
            end
            mark:EnableMouse(clickable and not item)
            if mark.button then
                mark.button:SetShown(questButton)
                PressMark(mark, false)
                if not clickable then mark.button.lit:Hide() end
            else
                mark.halo:SetShown(clickable and info.state == "ready")
            end
            mark.glow:SetTexture(info.icon)
            mark.glow:SetShown(clickable and not questButton and not item)
            if row.routeBox then -- dungeonroute (2.0.5)
                local boxed = routed and info.state ~= "done" and info.quest and info.quest.id ~= nil
                row.routeBox:SetShown(boxed and true or false)
                if boxed then row.routeBox:SetChecked(not routeSkip[info.quest.id]) end
            end
            row.title:ClearAllPoints()
            row.title:SetPoint("TOPLEFT", row, "TOPLEFT", textX, 0)
            row.title:SetWidth(textW)
            row.title:SetText(info.name or "")
            row.title:SetTextColor(info.color[1], info.color[2], info.color[3])
            local height = math.max(14, row.title:GetStringHeight() or 14)
            row.sub:SetWidth(textW)
            if row.sub.SetMaxLines then row.sub:SetMaxLines(info.short and 2 or 0) end
            if info.sub then
                row.sub:SetText(info.sub)
                row.sub:Show()
                height = height + 3 + math.max(10, row.sub:GetStringHeight() or 10)
            else
                row.sub:SetText("")
                row.sub:Hide()
            end
            local lines = 0
            if info.chain and info.chainOpen then
                -- The whole chain, step by step (the step in the log with
                -- its progress).
                row.step:Hide()
                for _, entry in ipairs(ChainSteps(info)) do
                    lines = lines + 1
                    local line = row.chainLines[lines]
                    if not line then
                        line = MakeChainLine(row)
                        row.chainLines[lines] = line
                    end
                    line:ClearAllPoints()
                    line:SetPoint("TOPLEFT", row, "TOPLEFT", textX, -(height + 3))
                    height = height + 3 + SetChainLine(line, entry, textW)
                end
            elseif info.stepText then
                local step = row.step
                step.text:SetWidth(textW)
                step.text:SetText(info.stepText)
                local stepHeight = math.max(12, step.text:GetStringHeight() or 12)
                step:ClearAllPoints()
                step:SetPoint("TOPLEFT", row, "TOPLEFT", textX, -(height + 3))
                step:SetSize(textW, stepHeight)
                step:Show()
                height = height + 3 + stepHeight
                -- The step ready to hand in: the round ? right after its
                -- name; a click shows where it is handed in.
                if info.stepTurnIn and FDJ.CreateTurnInButton then
                    if not step.mark then
                        step.mark = FDJ.CreateTurnInButton(step, 16)
                        step.mark:SetFrameLevel(step:GetFrameLevel() + 3)
                        step.measure = step:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
                        step.measure:Hide()
                    end
                    step.measure:SetText(info.stepLabel or info.stepName or "")
                    local nameW = step.measure:GetStringWidth() or 0
                    local size = FDJ.StepMarkSize()
                    FDJ.ResizeTurnInButton(step.mark, size)
                    step.mark:ClearAllPoints()
                    step.mark:SetPoint("LEFT", step, "TOPLEFT", math.min(nameW + 4, math.max(0, textW - size)), -6)
                    FDJ.SetTurnInButton(step.mark, info.stepTurnIn, info.stepName)
                elseif step.mark then
                    FDJ.SetTurnInButton(step.mark, nil)
                end
            else
                row.step:Hide()
            end
            for k = lines + 1, #row.chainLines do
                row.chainLines[k].entry = nil
                row.chainLines[k]:Hide()
            end
            row:SetHeight(height)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", f, "TOPLEFT", SIDE, -y)
            row:SetShown(not collapsed)
            y = y + height + ROW_GAP
        end
        for i = #quests + 1, #f.rows do
            f.rows[i].info = nil
            f.rows[i]:Hide()
        end

        over.count:SetText(done .. "/" .. #quests)
        -- Folded: just the title bar box (the drawn stand-in frame keeps a
        -- strip under it, its edges need the room).
        local height
        if not collapsed then
            height = math.max(COLLAPSED_H, y - ROW_GAP + BOTTOM_PAD)
        elseif f.art then
            height = FOLDED_H
        else
            height = COLLAPSED_H
        end
        f:SetHeight(height)
        f.grip:SetShown(not collapsed)
        FitArt(f, height, collapsed)
    end

    -- The waypoint arrow (Systems/MapMarkers.lua) follows a tracked quest
    -- chain page (the Cozy Sleeping Bag): to where its next step is picked
    -- up, then to where that step is handed in, and so on to the end.
    -- 1.9.9: also, tracked or not, once Show on Map has shown one of its
    -- spots, until the arrow is right-clicked away (kept over reloads).
    local followed = {}
    local function ArrowChains()
        local db = CharDB()
        if type(db.arrowChains) ~= "table" then db.arrowChains = {} end
        return db.arrowChains
    end
    local function FollowChains()
        if not FDJ.FollowWaypoint then return end
        local level = PlayerLevel()
        local now = {}
        local names = {}
        for _, name in ipairs(ShownTracked()) do names[#names + 1] = name end
        for name, on in pairs(ArrowChains()) do
            if on and FDJ.DB and FDJ.DB[name] and not IsTracked(name) then names[#names + 1] = name end
        end
        for _, name in ipairs(names) do
            local dungeon = FDJ.DB[name]
            -- noArrow: a chain page without the waypoint arrow (Onyxia Attunement).
            if dungeon and dungeon.questChainPage and not dungeon.noArrow and not Locked(name) then
                now[name] = true
                local spot, title, turnIn
                for _, quest in ipairs(QuestsOf(name)) do
                    local info = RowInfo(quest, level)
                    if info.state == "ready" or info.state == "log" then
                        spot, title, turnIn = info.turnin, info.name, true
                    elseif info.state == "todo" then
                        local pending = false
                        for _, entry in ipairs(ChainSteps(info)) do
                            if entry.state == "next" then
                                pending, spot, title = true, entry.start, (entry.arrowName or entry.name)
                                break
                            elseif entry.state == "log" or entry.state == "ready" then
                                pending, spot, title, turnIn = true, entry.turnin, (entry.arrowName or entry.name), not entry.goTo -- (stepgoto)
                                break
                            end
                        end
                        if not pending then spot, title = info.start, info.name end
                    end
                    if spot then break end
                end
                FDJ.FollowWaypoint(name, spot, title, turnIn)
            end
        end
        -- dungeonroute (2.0.5): a dungeon's route, stop by stop.
        for _, name in ipairs(ShownTracked()) do
            local dungeon = FDJ.DB[name]
            if dungeon and not dungeon.questChainPage and RouteOn(name) and not Locked(name) then
                now[name] = true
                local plan = RoutePlan(name)
                local stop = plan[1]
                -- routeready (2.0.8): all errands done, the entrance is next:
                -- no arrow, the "You're ready to go in!" box, until its Show
                -- location button is clicked.
                if stop and stop.entrance and FDJ.RouteReady and not FDJ.RouteReady(name) then
                    FDJ.FollowWaypoint(name, nil)
                elseif stop and FDJ.RouteGoalHere and FDJ.RouteGoalHere(stop) then
                    -- killzone (2.0.8): at the place to kill / collect: no arrow
                    -- goalhere (2.0.9, M 16 Nov 2026): the arrow stays (it going
                    -- away looked like it broke): what to kill / collect there in
                    -- place of the yards (FDJ.RouteGoalLines).
                    if FDJ.RouteNotReady then FDJ.RouteNotReady(name) end
                    FDJ.FollowWaypoint(name, stop.spot, stop.title, stop.turnIn, FDJ.RouteGoalLines(plan, stop), type(stop.id) == "string" and stop.id:find("^goto:") ~= nil, stop.skipQuest)
                elseif stop then
                    if not stop.entrance and FDJ.RouteNotReady then FDJ.RouteNotReady(name) end
                    FDJ.FollowWaypoint(name, stop.spot, stop.title, stop.turnIn, nil, type(stop.id) == "string" and stop.id:find("^goto:") ~= nil, stop.skipQuest) -- (skipnow)
                else
                    if FDJ.RouteNotReady then FDJ.RouteNotReady(name) end
                    FDJ.FollowWaypoint(name, nil)
                end
            elseif dungeon and FDJ.RouteNotReady then
                FDJ.RouteNotReady(name) -- Route off
            end
        end
        for name in pairs(followed) do
            if not now[name] then FDJ.FollowWaypoint(name, nil) end
        end
        followed = now
    end
    FDJ.FollowRoutes = FollowChains
    -- killzone (2.0.8, M 15 Nov 2026): a stop that is a place to kill or
    -- collect things (a goto: stop, no person named: Down the Scarlet Path's
    -- Valley of Bones, the motes in Demon Fall Canyon) needs no arrow once you
    -- are there: within 250 yards of the spot, or anywhere in its subzone.
    -- The subzone is learned the first time you are within 100 yards (so it
    -- is surely the right one) and kept (ForeverDungeonJournalDB.goalAreas,
    -- per client language): after a /reload anywhere in the valley, still no
    -- arrow. It stays away while you are within 400 yards; leave the area and
    -- it comes back. A person to talk to (Sputtervalve) keeps it.
    function FDJ.RouteGoalHere(stop)
        if type(stop) ~= "table" or type(stop.id) ~= "string" or not stop.id:find("^goto:") then return false end
        if stop.exact then return false end -- drownedally (2.0.9): one thing at one place (a tablet), not an area
        if type(stop.spot) == "table" and stop.spot.exact then return false end -- (plankjump: a spot of one place, the arrow pointing at it)
        local spot = stop.spot
        if type(spot) ~= "table" or spot.targetName or not spot.mapID then return false end
        FDJ.routeGoalsHere = FDJ.routeGoalsHere or {}
        local here = FDJ.routeGoalsHere
        local areas = {}
        if type(ForeverDungeonJournalDB) == "table" then
            if type(ForeverDungeonJournalDB.goalAreas) ~= "table" then ForeverDungeonJournalDB.goalAreas = {} end
            areas = ForeverDungeonJournalDB.goalAreas
        end
        local key = string.format("%s|%.3f|%.3f", tostring(spot.mapID), tonumber(spot.x) or 0, tonumber(spot.y) or 0)
        local yards = FDJ.YardsToSpot and FDJ.YardsToSpot(spot)
        local sub = type(GetSubZoneText) == "function" and GetSubZoneText() or ""
        if type(sub) ~= "string" then sub = "" end
        local locale = type(GetLocale) == "function" and GetLocale() or ""
        -- goalnear (2.0.13): a small place (spot.goalNear yards: the Lordamere
        -- Internment Camp, 40): the arrow leads right into it
        local reach = tonumber(spot.goalNear)
        if yards and yards <= (reach or 100) and sub ~= "" then areas[key] = { sub = sub, locale = locale } end
        local learned = areas[key]
        local inArea = sub ~= "" and type(learned) == "table" and learned.sub == sub and learned.locale == locale
        if reach then inArea = inArea and yards ~= nil and yards <= reach + 150 end
        if (yards and yards <= (reach or 250)) or inArea or (here[stop.id] and yards and yards <= (reach and reach + 110 or 400)) then
            here[stop.id] = true
            return true
        end
        here[stop.id] = nil
        return false
    end
    -- goalhere (2.0.9, M 16 Nov 2026): what the arrow says at the place to
    -- kill / collect (FDJ.RouteGoalHere): the objectives of every quest done
    -- there, as the tracker shows them ("0/15 Kurzen Jungle Fighter slain",
    -- Bad Medicine's two lines under it: same place), done ones in grey.
    function FDJ.RouteGoalLines(plan, stop)
        local lines, seen = {}, {}
        for _, task in ipairs(type(plan) == "table" and plan or {}) do
            local id = type(task) == "table" and type(task.id) == "string" and tonumber(task.id:match("^goto:(%d+)$")) or nil
            if id and not seen[id] and (task == stop or (task.key ~= nil and task.key == stop.key)) then
                seen[id] = true
                for _, line in ipairs(ObjectiveText(id)) do lines[#lines + 1] = line end
            end
        end
        return lines
    end
    -- Show on Map on a chain page's spot (FDJ.SetWaypointArrow): follow it.
    function FDJ.FollowChainArrow(name)
        local dungeon = name and FDJ.DB and FDJ.DB[name]
        if not (dungeon and dungeon.questChainPage) then return end
        ArrowChains()[name] = true
        FollowChains()
    end
    -- The arrow right-clicked away (or its pin removed): stop following it
    -- from Show on Map. True when it isn't tracked either (the arrow goes).
    function FDJ.StopChainArrow(name)
        if name == nil then return false end
        ArrowChains()[name] = nil
        return not IsTracked(name)
    end

    Refresh = function()
        local shown = {}
        for _, name in ipairs(ShownTracked()) do
            if not Locked(name) and #QuestsOf(name) > 0 then shown[#shown + 1] = name end
        end
        -- Each dungeon keeps its own window, and so its place, while other
        -- windows open and close; a newly shown one takes the first free one.
        local slots, used, slotFor = WindowSlots(), {}, {}
        for name in pairs(slots) do
            if not IsTracked(name) then slots[name] = nil end
        end
        for _, name in ipairs(shown) do
            local index = slots[name]
            if type(index) == "number" and index >= 1 and not used[index] then
                used[index], slotFor[name] = true, index
            end
        end
        for _, name in ipairs(shown) do
            if not slotFor[name] then
                local index = 1
                while used[index] do index = index + 1 end
                used[index], slotFor[name], slots[name] = true, index, index
            end
        end
        for _, name in ipairs(shown) do
            local f = Build(slotFor[name])
            local fresh = not f:IsShown() or f.dungeon ~= name
            f.dungeon = name
            Layout(f)
            if fresh then Place(f) end
            f:Show()
        end
        for index, f in pairs(windows) do
            if not used[index] then
                f.dungeon = nil
                f:Hide()
            end
        end
        FollowChains()
    end
    FDJ.RefreshQuestTracker = Refresh

    -- Quest log events come in bursts: redraw once, on the next frame.
    local worker = CreateFrame("Frame")
    worker:Hide()
    worker:SetScript("OnUpdate", function(self)
        self:Hide()
        Refresh()
    end)
    local function Schedule()
        worker:Show()
    end

    -- --------------------------------------------- Track button on the list
    -- A red game button like Dungeons / Map / Bosses / Quests. Long
    -- translations shrink a little instead of running into "Quests | 12".
    local TRACK_MAX = 112

    -- "Tracking" and its tick sit together, centred on the button.
    local function SizeTrackButton(b)
        local text = b.text
        text:SetScale(1)
        local check = b.check:IsShown() and 17 or 0 -- 3 gap + 14 tick
        local width = (text:GetStringWidth() or 40) + 28 + check
        local scale = 1
        if width > TRACK_MAX then
            scale = math.max(0.8, (TRACK_MAX - 28 - check) / math.max(1, text:GetStringWidth() or 1))
            text:SetScale(scale)
            width = TRACK_MAX
        end
        b:SetWidth(math.max(78, math.ceil(width)))
        text:ClearAllPoints()
        text:SetPoint("CENTER", b, "CENTER", -check / 2 / scale, 0)
        b.check:ClearAllPoints()
        b.check:SetPoint("LEFT", text, "RIGHT", 3, 0)
    end

    function FDJ.UpdateQuestTrackButton(name)
        local journal = _G.ForeverDungeonJournalFrame
        local b = journal and journal.questTrackButton
        if not b then return end
        if not name or #QuestsOf(name) == 0 or not Trackable(name) then -- trackpull (2.0.50)
            b.dungeon = nil
            b:Hide()
            Schedule()
            return
        end
        b.dungeon = name
        -- buttonsrow (2.0.7): right of Route when Route shows, else first.
        b:ClearAllPoints()
        local route = journal.questRouteButton
        if route and route:IsShown() then
            b:SetPoint("LEFT", route, "RIGHT", 4, 0)
        else
            b:SetPoint("TOPLEFT", journal.questLeftPanel or b:GetParent(), "TOPLEFT", 10, -30)
        end
        local on = IsTracked(name)
        b:SetText(T(on and "TRACKING" or "TRACK"))
        b.text = b:GetFontString() or b.text
        if b.text then b.text:SetTextColor(1.00, 0.82, 0.27) end
        b.check:SetShown(on)
        if on then b:LockHighlight() else b:UnlockHighlight() end
        SizeTrackButton(b)
        b:Show()
        if b:IsMouseOver() and GameTooltip:IsOwned(b) and b:GetScript("OnEnter") then
            b:GetScript("OnEnter")(b)
        end
        Schedule()
    end

    -- The first window, the first time, pops out right beside the journal
    -- (left of it when there is no room on the right), so it is seen at once
    -- and not hidden behind the journal.
    local function PopOutBeside(f, journal)
        if not f or not journal or not journal:IsShown() then return end
        local js, ts = journal:GetEffectiveScale() or 1, f:GetEffectiveScale() or 1
        local left, right, top = journal:GetLeft(), journal:GetRight(), journal:GetTop()
        if not left or not right or not top or ts == 0 then return end
        left, right, top = left * js / ts, right * js / ts, top * js / ts
        local screen = (UIParent:GetWidth() or 0) * (UIParent:GetEffectiveScale() or 1) / ts
        local x
        if right + 4 + WIDTH <= screen then
            x = right + 4
        elseif left - 4 - WIDTH >= 0 then
            x = left - 4 - WIDTH
        else
            -- No room on either side (narrow screen, big journal): the right
            -- edge of the screen, where most of it still shows.
            x = screen - WIDTH - 4
        end
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, top - 84 * js / ts)
        SavePosition(f)
    end

    -- Track / stop tracking one dungeon; a newly tracked one opens last.
    function FDJ.ToggleQuestTracking(name)
        if not name or not (FDJ.DB and FDJ.DB[name]) then return end
        if not Trackable(name) then return end -- trackpull (2.0.50)
        local list = TrackedList()
        local on = not IsTracked(name)
        if on then
            list[#list + 1] = name
            -- A page that is one quest chain (the Cozy Sleeping Bag): its
            -- chain unfolded from the start.
            if FDJ.DB[name].questChainPage then
                for _, quest in ipairs(QuestsOf(name)) do
                    if FDJ.QUEST_PREREQ_CHAINS and FDJ.QUEST_PREREQ_CHAINS[quest.id] then ChainsOpen()[quest.id] = true end
                end
            end
        else
            for i = #list, 1, -1 do
                if list[i] == name then table.remove(list, i) end
            end
            WindowSlots()[name] = nil
            -- Not tracked any more: its arrow stops, Show on Map's too (1.9.9).
            ArrowChains()[name] = nil
            Routes()[name] = nil -- dungeonroute (2.0.5)
        end
        Folded()[name] = nil
        if PlaySound and SOUNDKIT then
            local sound = on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
            if sound then pcall(PlaySound, sound) end
        end
        Refresh()
        -- The first window, never moved yet: right beside the journal.
        local index = on and #ShownTracked() == 1 and WindowSlots()[name]
        if index and windows[index] and type(Slot(index).left) ~= "number" then
            PopOutBeside(windows[index], _G.ForeverDungeonJournalFrame)
        end
        local journal = _G.ForeverDungeonJournalFrame
        local b = journal and journal.questTrackButton
        if b and b.dungeon then FDJ.UpdateQuestTrackButton(b.dungeon) end
    end


    -- Called by the journal while it builds the quest list: the button sits
    -- left of the Alliance/Horde buttons.
    function FDJ.CreateQuestTrackButton(journal, questLeft)
        if not journal or not questLeft or journal.questTrackButton then return end
        local b = CreateFrame("Button", nil, questLeft, "UIPanelButtonTemplate")
        FDJ.OwnFonts(b) -- ownfonts (2.0.8)
        journal.questTrackButton = b
        -- buttonsrow (2.0.7): Route and Track sit in a row under the "Quests"
        -- title (Route first), not beside it: with Route they ran over it.
        b:SetSize(80, 22)
        b:SetText(T("TRACK"))
        -- Same font in every state, like the Map / Bosses / Quests buttons.
        if b.SetNormalFontObject then b:SetNormalFontObject("ForeverDJ_GameFontNormal") end
        if b.SetHighlightFontObject then b:SetHighlightFontObject("ForeverDJ_GameFontNormal") end
        if b.SetDisabledFontObject then b:SetDisabledFontObject("ForeverDJ_GameFontNormal") end
        b.text = b:GetFontString()
        if b.text then b.text:SetTextColor(1.00, 0.82, 0.27) end
        b.check = b:CreateTexture(nil, "OVERLAY")
        b.check:SetSize(14, 14)
        b.check:SetTexture(ICON_DONE)
        b.check:Hide()
        b:SetPoint("TOPLEFT", questLeft, "TOPLEFT", 10, -30)
        b:SetScript("OnClick", function(self)
            if self.dungeon then FDJ.ToggleQuestTracking(self.dungeon) end
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if self.dungeon and IsTracked(self.dungeon) then
                GameTooltip:SetText(T("TRACK_STOP"), 1, 1, 1)
            else
                GameTooltip:SetText(T("TRACK"), 1, 0.82, 0)
                GameTooltip:AddLine(T("TRACK_TIP"), 1, 1, 1, true)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
    end

    -- --------------------------------------------- the round ? in the journal
    -- The journal's quest list and quest page show the same round ? as the
    -- tracker for a quest ready to hand in (in place of the tick); a click
    -- shows where to hand it in.
    local function ShowTurnIn(quest, title)
        local spot = TurnInSpot(quest)
        if spot then
            local show = FDJ.MapMarkers and FDJ.MapMarkers.ShowRecordedLocationOnMap
            if not show then return end
            spot = (FDJ.LocalizeMapLocation and FDJ.LocalizeMapLocation(spot)) or spot
            FDJ.pendingMarkerQuestTitle = title
            FDJ.pendingMarkerTurnIn = true
            FDJ.pendingMarkerQuestID = type(quest) == "table" and quest.id or nil -- autoclear
            show(spot, spot.label)
            return
        end
        local inside = DungeonTurnIn(quest)
        if inside and FDJ.ShowTurnInOnDungeonMap and ShowJournal() then
            FDJ.ShowTurnInOnDungeonMap(inside.dungeon, inside.spot, title, quest.id)
        end
    end

    function FDJ.CreateTurnInButton(parent, size)
        -- The insecure action template lets the click target and mark the
        -- NPC when near, like Show on Map (set up on mouse-over).
        local okB, made = pcall(CreateFrame, "Button", nil, parent, "InsecureActionButtonTemplate")
        local b = okB and made or CreateFrame("Button", nil, parent)
        b._fdjCanTarget = (okB and made) and true or false
        if b._fdjCanTarget then b:SetAttribute("useOnKeyDown", false) end
        b:SetSize(size, size)
        b:RegisterForClicks("LeftButtonUp")
        if HasQuestButton() then
            local button = CreateFrame("Frame", nil, b)
            b.button = button
            button:SetSize(size, size)
            button:SetPoint("CENTER", b, "CENTER", 0, 0)
            button.ring = button:CreateTexture(nil, "ARTWORK")
            button.ring:SetAtlas(POI_RING)
            button.ring:SetSize(size, size)
            button.ring:SetPoint("CENTER")
            button.lit = button:CreateTexture(nil, "OVERLAY")
            button.lit:SetAtlas(POI_LIT)
            button.lit:SetBlendMode("ADD")
            button.lit:SetSize(size, size)
            button.lit:SetPoint("CENTER")
            button.lit:Hide()
            button.display = CreateFrame("Frame", nil, button)
            button.display:SetSize(size, size)
            button.display:SetFrameLevel(button:GetFrameLevel() + 1)
            button.icon = button.display:CreateTexture(nil, "ARTWORK")
            button.icon:SetAtlas(POI_TURN_IN)
            button.icon:SetSize(size, size)
            button.icon:SetPoint("CENTER")
            -- Our own ring and ?, sharp at this size (under the hover glow).
            -- A new file only loads after a game restart: until then, the
            -- game's art.
            local sharp = button:CreateTexture(nil, "ARTWORK", nil, 1)
            if sharp:SetTexture(TURN_IN_ART, nil, nil, "TRILINEAR") ~= false then
                sharp:SetSize(size, size)
                b.sharp = sharp
                button.ring:Hide()
                button.icon:Hide()
            else
                sharp:Hide()
            end
            PressMark(b, false)
        else
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetAllPoints()
            b.icon:SetTexture(ICON_LOG)
            local glow = b:CreateTexture(nil, "HIGHLIGHT")
            glow:SetAllPoints()
            glow:SetTexture(ICON_LOG)
            glow:SetBlendMode("ADD")
        end
        b:SetScript("OnMouseDown", function(self, mouse)
            if mouse == "LeftButton" then PressMark(self, true) end
        end)
        b:SetScript("OnMouseUp", function(self) PressMark(self, false) end)
        b:SetScript("OnEnter", function(self)
            if not self.quest then return end
            local configure = FDJ.MapMarkers and FDJ.MapMarkers.ConfigureTargetAndMarkAction
            if configure then configure(self, TurnInSpot(self.quest), true) end
            if self.button then self.button.lit:Show() end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(T("SHOW_TURN_IN"), 1, 0.82, 0)
            local where = Field(self.quest.id, "turnin", self.quest.turnin)
            if type(where) == "string" and where ~= "" then GameTooltip:AddLine(where, 1, 1, 1, true) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self)
            if self.button then self.button.lit:Hide() end
            GameTooltip:Hide()
        end)
        -- PostClick keeps the template's own click (the target macro).
        b.fdjClick = function(self)
            if self.quest then ShowTurnIn(self.quest, self.title) end
        end
        b:SetScript(b._fdjCanTarget and "PostClick" or "OnClick", b.fdjClick)
        b:Hide()
        return b
    end

    -- questrowtrial (2.0.8, M 15 Nov 2026): the quest list's round ! for a
    -- quest not taken yet (dungeons in FDJ.QUESTROW_TRIAL): the turn-in
    -- button with a ! (Media/PickUpMark.tga) in place of the ?; until the
    -- game is restarted (a new file loads only then) the gossip ! on its
    -- ring. A click shows how to pick the quest up (FDJ.ShowHowToPickUp:
    -- where it is picked up, on the map; with no spot on the map, the chain
    -- step to do next, else its page).
    function FDJ.CreatePickUpButton(parent, size)
        local b = FDJ.CreateTurnInButton(parent, size)
        local art = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\PickUpMark"
        if b.sharp then
            if b.sharp:SetTexture(art, nil, nil, "TRILINEAR") == false then
                b.sharp:SetTexture(ICON_TODO)
                b.sharp:SetSize(size * 0.62, size * 0.62)
                if b.button and b.button.ring then b.button.ring:Show() end
                b.fdjSmallMark = true
            end
        elseif b.button and b.button.icon then
            local t = b.button.icon
            if t:SetTexture(art, nil, nil, "TRILINEAR") == false then t:SetTexture(ICON_TODO) end
        elseif b.icon then
            b.icon:SetTexture(ICON_TODO)
        end
        b:SetScript("OnEnter", function(self)
            if not self.quest then return end
            if self.button then self.button.lit:Show() end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            -- pickonmap (2.0.8): "Show pickup on map", the place under it
            -- (and its chain, when not done yet).
            local onMap = FDJ.PickUpOnMapSpot and FDJ.PickUpOnMapSpot(self.quest)
            local step = FDJ.NextChainStep and FDJ.NextChainStep(self.quest)
            -- chainfirst (2.0.8): its chain not done yet: the click shows the chain
            GameTooltip:SetText(T(step and "SHOW_QUEST_CHAIN" or (onMap and "PICKUP_ON_MAP" or "PICKUP_HOW")), 1, 0.82, 0)
            if onMap then
                local where = Field(self.quest.id, "pickup", self.quest.pickup)
                if type(where) == "string" and where ~= "" then GameTooltip:AddLine(where, 1, 1, 1, true) end
                if step then
                    GameTooltip:AddLine(T("PICKUP_CHAIN_FIRST", Field(step.id, "name", step.name) or "?"), 1, 1, 1, true)
                end
            elseif step then
                GameTooltip:AddLine(T("PICKUP_CHAIN_FIRST", Field(step.id, "name", step.name) or "?"), 1, 1, 1, true)
            else
                local where = Field(self.quest.id, "pickup", self.quest.pickup)
                if type(where) == "string" and where ~= "" then GameTooltip:AddLine(where, 1, 1, 1, true) end
            end
            GameTooltip:Show()
        end)
        b.fdjClick = function(self)
            if self.quest and FDJ.ShowHowToPickUp then FDJ.ShowHowToPickUp(self.quest, self.dungeon) end
        end
        b:SetScript(b._fdjCanTarget and "PostClick" or "OnClick", b.fdjClick)
        return b
    end
    -- quest: the quest not taken yet, or nil to hide the button.
    function FDJ.SetPickUpButton(b, quest, title, dungeon)
        if not b then return end
        b.quest, b.title, b.dungeon = quest or nil, title, dungeon
        if not quest then
            b:Hide()
            return
        end
        b:EnableMouse(true)
        if b.button then
            PressMark(b, false)
            b.button.lit:Hide()
        end
        if b.fdjSmallMark and b.sharp then b.sharp:SetSize(b:GetWidth() * 0.62, b:GetHeight() * 0.62) end
        b:Show()
    end

    -- The chain steps' round ? (journal chain list, tracker step line): 24,
    -- the size picked with the 1.7.4 test slider.
    function FDJ.StepMarkSize()
        return 24
    end
    function FDJ.ResizeTurnInButton(b, size)
        if not b or not size then return end
        b:SetSize(size, size)
        local button = b.button
        if button then
            button:SetSize(size, size)
            if button.ring then button.ring:SetSize(size, size) end
            if button.lit then button.lit:SetSize(size, size) end
            if button.display then button.display:SetSize(size, size) end
            if button.icon then button.icon:SetSize(size, size) end
        end
        if b.sharp then b.sharp:SetSize(size, size) end
    end

    -- Where a quest or chain step ({ id, turnin, turninMap }) is handed in on
    -- the world map, found the same way as the tracker's ? (its turninMap,
    -- else the turn-in NPC's spot by name). nil when not known.
    function FDJ.TurnInSpotFor(quest)
        if type(quest) ~= "table" then return nil end
        return TurnInSpot(quest)
    end

    -- quest: the quest (or chain step: id + turnin text) ready to hand in, or
    -- nil to hide the button. Clickable when the hand-in place is known.
    function FDJ.SetTurnInButton(b, quest, title)
        if not b then return end
        b.quest, b.title = quest or nil, title
        if not quest then
            b:Hide()
            return
        end
        b:EnableMouse(TurnInSpot(quest) ~= nil or DungeonTurnIn(quest) ~= nil)
        if b.button then
            PressMark(b, false)
            b.button.lit:Hide()
        end
        b:Show()
    end

    -- ---------------------------------------------------------------- events
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE",
        "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "UNIT_QUEST_LOG_CHANGED",
        "PLAYER_LEVEL_UP", "QUEST_DATA_LOAD_RESULT", "BAG_UPDATE_DELAYED", "QUEST_DETAIL" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_QUEST_LOG_CHANGED" and unit ~= "player" then return end
        if event == "QUEST_DETAIL" then
            -- The quest opened by a start item clicked here: accept it.
            local want = FDJ.trackerAcceptQuest
            FDJ.trackerAcceptQuest = nil
            if want and GetTime and GetTime() - want.at < 5 and type(GetQuestID) == "function"
                and GetQuestID() == want.id and type(AcceptQuest) == "function" then
                AcceptQuest()
            end
            return
        end
        Schedule()
    end)

    -- Language or journal mode changes redraw it in the new language / lock.
    for _, key in ipairs({ "SetLanguage", "SetJournalMode" }) do
        local original = FDJ[key]
        if type(original) == "function" then
            FDJ[key] = function(...)
                local a, b, c = original(...)
                Schedule()
                return a, b, c
            end
        end
    end
end
-- END questtracker

-- malletchain: the Mallet of Zul'Farrak page's title is the mallet's own name
-- when the journal speaks the game's language (data: Data/QuestUpdates.lua).
do
    local PAGE = FDJ.MALLET_PAGE
    if PAGE and FDJ.DB and FDJ.DB[PAGE] then
        local baseName = FDJ.LocalizeDungeonName
        FDJ.LocalizeDungeonName = function(name, ...)
            if name == PAGE and FDJ.CanUseClientLocalizedText and FDJ.CanUseClientLocalizedText() then
                local get = (C_Item and C_Item.GetItemNameByID) or GetItemInfo
                if type(get) == "function" then
                    local ok, itemName = pcall(get, 9240)
                    if ok and type(itemName) == "string" and itemName ~= ""
                        and not (type(issecretvalue) == "function" and issecretvalue(itemName)) then
                        return itemName
                    end
                end
            end
            if baseName then return baseName(name, ...) end
            return name
        end
    end
end

-- repneeds (2.0.13, M 19 Nov 2026, The Twin Bears: "we need a neutral
-- reputation with the Timbermaw Hold ... display it a bit better instead of
-- having it hidden in the notes ... the official reputation bar from your
-- character ... at the top above objective. And it says requires neutral.
-- And then it shows what you have"): a quest's reputation needs
-- (quest.repNeeds = { { faction = factionID, name = "...", standing = 1-8 } }):
-- per faction a line "Requires <standing> with <faction>" (green when you
-- have it, red when not) and a bar like the game's reputation bar with your
-- standing and its progress. Placed above Objective; returns the new cursorY.
;(function()
    local STANDING_EN = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
    local COLORS = {
        { 0.80, 0.30, 0.22 }, { 0.80, 0.30, 0.22 }, { 0.75, 0.27, 0.00 }, { 0.90, 0.70, 0.00 },
        { 0.00, 0.60, 0.10 }, { 0.00, 0.60, 0.10 }, { 0.00, 0.60, 0.10 }, { 0.00, 0.60, 0.10 },
    }
    local function Secret(v) return type(issecretvalue) == "function" and issecretvalue(v) end
    local function Label(n)
        local sex = 2
        if type(UnitSex) == "function" then local ok, v = pcall(UnitSex, "player") if ok and tonumber(v) then sex = v end end
        if type(GetText) == "function" then
            local ok, text = pcall(GetText, "FACTION_STANDING_LABEL" .. n, sex)
            if ok and type(text) == "string" and text ~= "" and not text:find("^FACTION_STANDING") then return text end
        end
        local g = _G["FACTION_STANDING_LABEL" .. n]
        return (type(g) == "string" and g ~= "") and g or STANDING_EN[n] or "?"
    end
    local function Color(n)
        local c = type(FACTION_BAR_COLORS) == "table" and FACTION_BAR_COLORS[n]
        if type(c) == "table" and tonumber(c.r) then return c.r, c.g, c.b end
        c = COLORS[n] or COLORS[4]
        return c[1], c[2], c[3]
    end
    -- The player's standing with a faction: name, standing (1-8), value in
    -- the standing, its size; nil when the game does not say.
    local function Standing(factionID)
        if C_Reputation and type(C_Reputation.GetFactionDataByID) == "function" then
            local ok, d = pcall(C_Reputation.GetFactionDataByID, factionID)
            if ok and type(d) == "table" and tonumber(d.reaction) and not Secret(d.reaction) then
                local low, high, cur = tonumber(d.currentReactionThreshold) or 0, tonumber(d.nextReactionThreshold) or 0, tonumber(d.currentStanding) or 0
                return d.name, d.reaction, cur - low, high - low
            end
        end
        if type(GetFactionInfoByID) == "function" then
            local ok, name, _, standing, low, high, value = pcall(GetFactionInfoByID, factionID)
            if ok and tonumber(standing) and not Secret(standing) then
                return name, standing, (tonumber(value) or 0) - (tonumber(low) or 0), (tonumber(high) or 0) - (tonumber(low) or 0)
            end
        end
        return nil
    end
    local function Row(journal, i)
        journal.fdjRepRows = journal.fdjRepRows or {}
        local row = journal.fdjRepRows[i]
        if row then return row end
        local parent = journal.questDetailContent
        row = {}
        row.text = parent:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
        row.text:SetJustifyH("LEFT")
        local bar = CreateFrame("StatusBar", nil, parent)
        bar:SetSize(230, 16)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetMinMaxValues(0, 1)
        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints()
        bar.bg:SetColorTexture(0, 0, 0, 0.55)
        -- a thin dark edge round it
        for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, -1 } }) do
            local line = bar:CreateTexture(nil, "BORDER")
            line:SetColorTexture(0.12, 0.08, 0.03, 1)
            line:SetPoint(side[1], bar, side[1], -1, side[4])
            line:SetPoint(side[2], bar, side[2], 1, side[4])
            line:SetHeight(1)
        end
        for _, side in ipairs({ { "TOPLEFT", "BOTTOMLEFT", -1 }, { "TOPRIGHT", "BOTTOMRIGHT", 1 } }) do
            local line = bar:CreateTexture(nil, "BORDER")
            line:SetColorTexture(0.12, 0.08, 0.03, 1)
            line:SetPoint(side[1], bar, side[1], side[3], 1)
            line:SetPoint(side[2], bar, side[2], side[3], -1)
            line:SetWidth(1)
        end
        bar.label = bar:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
        bar.label:SetPoint("CENTER", bar, "CENTER", 0, 0)
        row.bar = bar
        journal.fdjRepRows[i] = row
        return row
    end
    function FDJ.PlaceRepNeeds(quest, cursorY)
        local journal = _G.ForeverDungeonJournalFrame
        if not (journal and journal.questDetailContent) then return cursorY end
        local needs = type(quest) == "table" and type(quest.repNeeds) == "table" and quest.repNeeds or {}
        local shown = 0
        for i, need in ipairs(needs) do
            local factionID, want = tonumber(need.faction), tonumber(need.standing) or 4
            if factionID then
                shown = i
                local row = Row(journal, i)
                local name, have, value, size = Standing(factionID)
                if type(name) ~= "string" or name == "" or Secret(name) then name = need.name or "?" end
                local met = have and have >= want
                row.text:ClearAllPoints()
                row.text:SetPoint("TOPLEFT", journal.questDetailContent, "TOPLEFT", 0, -cursorY)
                row.text:SetText(FDJ.L("REP_REQUIRES", Label(want), name))
                -- warnfont (2.1.1): red (not met) in the warning font.
                if met then
                    row.text:SetFontObject("ForeverDJ_GameFontNormal")
                    row.text:SetTextColor(0.05, 0.42, 0.05)
                else
                    if FDJ.WarningFont then FDJ.WarningFont(row.text) else row.text:SetTextColor(0.62, 0.10, 0.05) end
                end
                row.text:Show()
                cursorY = cursorY + (row.text:GetStringHeight() or 14) + 4
                local bar = row.bar
                bar:ClearAllPoints()
                bar:SetPoint("TOPLEFT", journal.questDetailContent, "TOPLEFT", 1, -cursorY)
                if have then
                    bar:SetStatusBarColor(Color(have))
                    if size and size > 0 then
                        bar:SetValue(math.max(0, math.min(1, value / size)))
                        bar.label:SetText(Label(have) .. "  " .. math.floor(value) .. " / " .. math.floor(size))
                    else
                        bar:SetValue(1)
                        bar.label:SetText(Label(have))
                    end
                else
                    bar:SetStatusBarColor(0.4, 0.4, 0.4)
                    bar:SetValue(0)
                    bar.label:SetText(type(UNKNOWN) == "string" and UNKNOWN or "Unknown")
                end
                bar:Show()
                cursorY = cursorY + 16 + 10
            end
        end
        for i, row in ipairs(journal.fdjRepRows or {}) do
            if i > shown then row.text:Hide() row.bar:Hide() end
        end
        return cursorY
    end
end)()

