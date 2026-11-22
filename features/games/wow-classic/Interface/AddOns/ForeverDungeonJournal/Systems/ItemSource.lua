-- Item source line.
-- When an item tooltip is shown (hovering gear while inspecting, bags, loot
-- rolls, or the window that opens when an item link in chat is clicked) and
-- the item is in the journal, one line is added at the bottom of the tooltip:
--   [journal icon] Boss name - Dungeon      (or  ! Quest name - Dungeon)
-- On the chat-link window that line can be clicked to open the journal there.
-- Hover tooltips vanish when the mouse leaves the item, so those are opened
-- with the "Open hovered item in Dungeon Journal" key binding instead.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

BINDING_NAME_FOREVERDUNGEONJOURNAL_OPENITEM = "Open hovered item in Dungeon Journal"

local JOURNAL_ICON = "Interface\\Icons\\INV_Misc_Book_09"
local QUEST_ICON = "|TInterface\\GossipFrame\\AvailableQuestIcon:14:14:0:0|t "
local JOURNAL_ICON_TEXT = "|T" .. JOURNAL_ICON .. ":14:14:0:0:64:64:5:59:5:59|t "

local function Enabled()
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    return ForeverDungeonJournalDB.itemSourceStrip ~= false
end

local function Plain(v)
    if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
    return v
end

-- ---------------------------------------------------------------------------
-- Index: item ID -> where the journal lists it
-- ---------------------------------------------------------------------------
local index

local function PlayerFaction()
    if type(UnitFactionGroup) ~= "function" then return nil end
    local ok, faction = pcall(UnitFactionGroup, "player")
    return ok and Plain(faction) or nil
end

local function BuildIndex()
    index = {}
    local DB = FDJ.DB or {}
    local faction = PlayerFaction()

    -- rank: lower wins when an item is listed in several places
    local function offer(itemID, source, rank)
        itemID = tonumber(itemID)
        if not itemID or itemID <= 0 then return end
        local current = index[itemID]
        if not current or rank < current.rank then
            source.rank = rank
            source.itemID = itemID
            source.kind = "item"
            index[itemID] = source
        end
    end

    for _, dungeonName in ipairs(FDJ.ORDER or {}) do
        local dungeon = DB[dungeonName]
        if dungeon then
            for bossIndex, boss in ipairs(dungeon.bosses or {}) do
                -- The "Recipes & Patterns" row only repeats items that are
                -- already listed under the boss or trash that drops them.
                -- altarbosses (2.0.24): children's loot is told under their group.
                if type(boss) == "table" and not boss.recipeTab and not boss.childOf then
                    local items = {}
                    for _, item in ipairs(boss.loot or {}) do items[#items + 1] = item end
                    local shared = FDJ.GetBossSharedLoot and FDJ.GetBossSharedLoot(dungeonName, boss)
                    for _, item in ipairs(shared or {}) do items[#items + 1] = item end
                    for _, item in ipairs(items) do
                        offer(item[1], {
                            mode = "bosses",
                            dungeonName = dungeonName,
                            bossIndex = bossIndex,
                            bossName = boss.name,
                            trash = boss.trash and true or nil,
                        }, boss.trash and 2 or 1)
                    end
                end
            end

            for questIndex, quest in ipairs(dungeon.quests or {}) do
                local items = {}
                local function add(item)
                    if type(item) == "table" and item[1] then items[#items + 1] = item end
                end
                for _, item in ipairs(quest.rewardItems or {}) do add(item) end
                for _, item in ipairs(quest.additionalRewardItems or {}) do add(item) end
                for _, item in ipairs(quest.noteRewardItems or {}) do add(item) end
                add(quest.requiredItem) add(quest.startItem) add(quest.noteItem)

                -- Prefer the player's own faction when both sides have the quest.
                local rank = 4
                if quest.faction and faction and quest.faction == faction then rank = 3 end
                if not quest.faction or quest.faction == "Both" or quest.faction == "Neutral" then rank = 3 end
                for _, item in ipairs(items) do
                    offer(item[1], {
                        mode = "quests",
                        dungeonName = dungeonName,
                        questIndex = questIndex,
                        questID = quest.id,
                        questName = quest.name,
                        questFaction = quest.faction,
                    }, rank)
                end
            end
        end
    end
end

function FDJ.ResetItemSourceIndex() index = nil end

function FDJ.GetItemSource(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end
    if not index then
        local ok = pcall(BuildIndex)
        if not ok then index = {} end
    end
    return index[itemID]
end

-- Titles for a source: line 1 (boss or quest), line 2 (dungeon).
local function SourceText(source)
    local dungeon = source.dungeonName
    if FDJ.LocalizeDungeonName then
        local ok, name = pcall(FDJ.LocalizeDungeonName, dungeon)
        if ok and type(name) == "string" and name ~= "" then dungeon = name end
    end

    if source.mode == "quests" then
        local name = source.questName or ""
        if FDJ.LocalizeQuestField and source.questID then
            local ok, localized = pcall(FDJ.LocalizeQuestField, source.questID, "name", name)
            if ok and type(localized) == "string" and localized ~= "" then name = localized end
        end
        -- repeaticon (2.0.44): the blue ? for a repeatable quest
        return ((FDJ.QuestIconMarkup and source.questID) and FDJ.QuestIconMarkup(source.questID, 14) or QUEST_ICON) .. name, dungeon
    end

    -- Shared boss loot drops from many bosses; naming one would mislead.
    if FDJ.SHARED_LOOT_IDS and FDJ.SHARED_LOOT_IDS[source.itemID] then
        local L = FDJ.L or function(key) return key end
        return L("SHARED_LOOT"), L("SEVERAL_DUNGEONS")
    end

    local boss = source.bossName or ""
    if FDJ.LocalizeBossName then
        local ok, name = pcall(FDJ.LocalizeBossName, boss)
        if ok and type(name) == "string" and name ~= "" then boss = name end
    end
    return boss, dungeon
end

-- Quest items a boss drops (An Unsent Letter from Edwin VanCleef): the quest
-- page's item says "Looted from <boss>, <dungeon>", and clicking it opens
-- that boss's loot with the item glowing (3 seconds, or until hovered).
do
    local strings = {
        enUS = { LOOTED_FROM = "Looted from %s, %s", ITEM_CLICK_BOSS = "Click to show" },
        deDE = { LOOTED_FROM = "Erbeutet von %s, %s", ITEM_CLICK_BOSS = "Klicken zum Anzeigen" },
        frFR = { LOOTED_FROM = "Butin de %s, %s", ITEM_CLICK_BOSS = "Cliquer pour afficher" },
        esES = { LOOTED_FROM = "Botín de %s, %s", ITEM_CLICK_BOSS = "Clic para mostrar" },
        esMX = { LOOTED_FROM = "Botín de %s, %s", ITEM_CLICK_BOSS = "Clic para mostrar" },
        itIT = { LOOTED_FROM = "Bottino di %s, %s", ITEM_CLICK_BOSS = "Clicca per mostrare" },
        ptBR = { LOOTED_FROM = "Saque de %s, %s", ITEM_CLICK_BOSS = "Clique para mostrar" },
        ruRU = { LOOTED_FROM = "Добыча: %s, %s", ITEM_CLICK_BOSS = "Нажмите, чтобы показать" },
        koKR = { LOOTED_FROM = "획득처: %s, %s", ITEM_CLICK_BOSS = "클릭하여 보기" },
        zhCN = { LOOTED_FROM = "拾取自%s，%s", ITEM_CLICK_BOSS = "点击显示" },
        zhTW = { LOOTED_FROM = "拾取自%s，%s", ITEM_CLICK_BOSS = "點擊顯示" },
    }
    for locale, entries in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            for key, value in pairs(entries) do
                if t[key] == nil then t[key] = value end
            end
        end
    end
end

function FDJ.BossDropSource(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return nil end
    if FDJ.SHARED_LOOT_IDS and FDJ.SHARED_LOOT_IDS[itemID] then return nil end
    local source = FDJ.GetItemSource(itemID)
    if source and source.mode == "bosses" and not source.trash and source.bossIndex then return source end
    return nil
end

function FDJ.BossDropText(itemID)
    local source = FDJ.BossDropSource(itemID)
    if not source then return nil end
    local boss, dungeon = SourceText(source)
    local L = FDJ.L or function(key) return key end
    return L("LOOTED_FROM", boss, dungeon)
end

function FDJ.JumpToBossDrop(itemID)
    local source = FDJ.BossDropSource(itemID)
    if not source or not FDJ.OpenSearchResult then return false end
    local result = {}
    for k, v in pairs(source) do result[k] = v end
    result.glowFor = 3
    return pcall(FDJ.OpenSearchResult, result)
end

function FDJ.OpenItemSource(itemID)
    local source = FDJ.GetItemSource(itemID)
    if not source or not FDJ.OpenSearchResult then return false end
    local journal = _G.ForeverDungeonJournalFrame
    if not journal then return false end
    if not journal:IsShown() then
        if FDJ.ToggleJournal then FDJ.ToggleJournal() else journal:Show() end
    end
    local ok = pcall(FDJ.OpenSearchResult, source)
    return ok
end

-- ---------------------------------------------------------------------------
-- Reading the item out of a tooltip
-- ---------------------------------------------------------------------------
local function TooltipItemID(tooltip, data)
    if type(data) == "table" then
        local id = Plain(data.id)
        if type(id) == "number" then return id end
    end
    if tooltip and tooltip.GetItem then
        local ok, _, link = pcall(tooltip.GetItem, tooltip)
        link = ok and Plain(link) or nil
        if type(link) == "string" then
            local id = link:match("item:(%d+)")
            if id then return tonumber(id) end
        end
    end
    return nil
end

-- Tooltips raised by the journal's own windows already show the source.
local function OwnedByJournal(tooltip)
    if not tooltip or not tooltip.GetOwner then return false end
    local ok, owner = pcall(tooltip.GetOwner, tooltip)
    if not ok then return false end
    local journal, favourites = _G.ForeverDungeonJournalFrame, _G.ForeverDungeonJournalFavourites
    for _ = 1, 20 do
        if not owner or type(owner) ~= "table" or not owner.GetParent then return false end
        if owner == journal or owner == favourites then return true end
        owner = owner:GetParent()
    end
    return false
end

-- ---------------------------------------------------------------------------
-- The line
-- ---------------------------------------------------------------------------
local shownItem = {}   -- tooltip -> item ID whose source line is on it
local clickers = {}    -- tooltip -> invisible button over that line

local function ClearTooltip(tooltip)
    shownItem[tooltip] = nil
    local clicker = clickers[tooltip]
    if clicker then clicker:Hide() end
end

-- Chat-link window only: make the added line clickable.
local function PlaceClicker(tooltip, itemID)
    if tooltip ~= ItemRefTooltip then return end
    local name = tooltip.GetName and tooltip:GetName()
    local count = tooltip.NumLines and tooltip:NumLines()
    local line = name and count and _G[name .. "TextLeft" .. count]
    if not line then return end

    local clicker = clickers[tooltip]
    if not clicker then
        clicker = CreateFrame("Button", nil, tooltip)
        clickers[tooltip] = clicker
        clicker:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        clicker:RegisterForClicks("LeftButtonUp")
        clicker:SetScript("OnClick", function(self)
            if self.itemID then FDJ.OpenItemSource(self.itemID) end
        end)
    end
    clicker.itemID = itemID
    clicker:ClearAllPoints()
    clicker:SetPoint("TOPLEFT", line, "TOPLEFT", -2, 2)
    clicker:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", -2, -2)
    clicker:SetPoint("RIGHT", tooltip, "RIGHT", -8, 0)
    clicker:SetFrameLevel((tooltip:GetFrameLevel() or 1) + 5)
    clicker:Show()
end

local function UpdateTooltip(tooltip, data)
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
    if not Enabled() or OwnedByJournal(tooltip) then return end

    local itemID = TooltipItemID(tooltip, data)
    local source = itemID and FDJ.GetItemSource(itemID)
    if not source then return end
    -- The client can announce the same item twice for one tooltip.
    if shownItem[tooltip] == itemID then return end
    shownItem[tooltip] = itemID

    local title, dungeon = SourceText(source)
    tooltip:AddLine(JOURNAL_ICON_TEXT .. title .. "  |cffaa9f85- " .. tostring(dungeon or "") .. "|r", 1, 0.82, 0)
    PlaceClicker(tooltip, itemID)
end

local function SafeUpdate(tooltip, data)
    pcall(UpdateTooltip, tooltip, data)
end

local hooked = false
local function InstallHooks()
    if hooked then return end
    hooked = true

    -- Newer clients announce tooltip items through TooltipDataProcessor;
    -- classic-style clients fire OnTooltipSetItem. Use whichever exists.
    local viaProcessor = false
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        viaProcessor = pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, SafeUpdate)
    end

    for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
        if tooltip and tooltip.HookScript then
            if not viaProcessor then
                pcall(tooltip.HookScript, tooltip, "OnTooltipSetItem", function(self) SafeUpdate(self) end)
            end
            pcall(tooltip.HookScript, tooltip, "OnTooltipCleared", function(self) pcall(ClearTooltip, self) end)
            pcall(tooltip.HookScript, tooltip, "OnHide", function(self) pcall(ClearTooltip, self) end)
        end
    end
end

-- Key binding: open the journal for the item under the mouse.
function ForeverDungeonJournal_OpenHoveredItem()
    local itemID
    if GameTooltip and GameTooltip:IsShown() then
        itemID = shownItem[GameTooltip] or TooltipItemID(GameTooltip)
    end
    if not itemID and ItemRefTooltip and ItemRefTooltip:IsShown() then
        itemID = shownItem[ItemRefTooltip] or TooltipItemID(ItemRefTooltip)
    end
    if itemID then FDJ.OpenItemSource(itemID) end
end

-- /dj itemtip turns the line on or off.
function FDJ.ToggleItemSourceStrip()
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    ForeverDungeonJournalDB.itemSourceStrip = not Enabled()
    return Enabled()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function() pcall(InstallHooks) end)
