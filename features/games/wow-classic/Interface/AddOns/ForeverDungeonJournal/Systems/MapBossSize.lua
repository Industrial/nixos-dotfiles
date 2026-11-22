-- Boss icon size control on the dungeon maps (journal map and the M map
-- inside a dungeon, which shows the same panel). Sits bottom left in the
-- dark space beside the map art. Size is saved for all characters.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

local MIN, MAX, STEP, DEFAULT = 0, 1, 0.1, 0.9 -- 100% down to 0% (hidden); 90% by default
local LABEL = {
    enUS = "Boss icons", deDE = "Boss-Symbole", frFR = "Icônes des boss", esES = "Iconos de jefes",
    itIT = "Icone dei boss", ptBR = "Ícones de chefes", ruRU = "Значки боссов", koKR = "우두머리 아이콘",
    zhCN = "首领图标", zhTW = "首領圖示",
}

function FDJ.MapBossScale()
    local v = ForeverDungeonJournalDB and tonumber(ForeverDungeonJournalDB.mapBossScale)
    if not v then return DEFAULT end
    return math.max(MIN, math.min(MAX, v))
end

local function SetScale(v)
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    v = math.floor(math.max(MIN, math.min(MAX, v)) * 10 + 0.5) / 10
    -- Always stored (saved variables), so it stays the same after relogging.
    ForeverDungeonJournalDB.mapBossScale = v
    local frame = _G.ForeverDungeonJournalFrame
    local dungeon = FDJ.GetSelectedDungeon and FDJ.GetSelectedDungeon()
    local data = dungeon and FDJ.DUNGEON_MAPS and FDJ.DUNGEON_MAPS[dungeon]
    if data and frame and FDJ.RenderCustomDungeonMap then
        pcall(FDJ.RenderCustomDungeonMap, data, frame.dungeonMapFloor)
    end
end

local function MakeButton(parent, text)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    FDJ.OwnFonts(b) -- ownfonts (2.0.8)
    b:SetSize(24, 22)
    b:SetText(text)
    return b
end

-- Called by the map renderer after the floor buttons are placed.
function FDJ.UpdateMapBossSizer(panel, holder, floorButtons)
    local c = panel.fdjBossSizer
    if not c then
        c = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        panel.fdjBossSizer = c
        c:SetSize(92, 46)
        c:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        c:SetBackdropColor(0, 0, 0, 0.75)
        c:SetBackdropBorderColor(0.45, 0.38, 0.25, 1)
        -- Compact: label on top, [-] value [+] underneath.
        c.label = c:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
        c.label:SetPoint("TOP", 0, -6)
        c.value = c:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
        c.value:SetWidth(36)
        c.value:SetPoint("BOTTOM", 0, 9)
        c.minus = MakeButton(c, "-")
        c.minus:SetSize(22, 20)
        c.minus:SetPoint("RIGHT", c.value, "LEFT", 0, 0)
        c.plus = MakeButton(c, "+")
        c.plus:SetSize(22, 20)
        c.plus:SetPoint("LEFT", c.value, "RIGHT", 0, 0)
        c.minus:SetScript("OnClick", function() SetScale(FDJ.MapBossScale() - STEP) end)
        c.plus:SetScript("OnClick", function() SetScale(FDJ.MapBossScale() + STEP) end)
    end
    local lang = FDJ.GetLanguage and FDJ.GetLanguage() or "enUS"
    c.label:SetText(LABEL[lang] or LABEL.enUS)
    c.value:SetText(math.floor(FDJ.MapBossScale() * 100 + 0.5) .. "%")
    c:SetWidth(math.max(92, (c.label:GetStringWidth() or 60) + 14))
    if FDJ.MapBossScale() <= 0 then c.minus:Disable() else c.minus:Enable() end
    if FDJ.MapBossScale() >= MAX then c.plus:Disable() else c.plus:Enable() end
    -- Bottom left of the panel, in the dark strip beside the map art.
    c:ClearAllPoints()
    c:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 8)
    c:SetFrameLevel(holder:GetFrameLevel() + 30)
    c:Show()
    if FDJ.UpdateMapQuestToggle then pcall(FDJ.UpdateMapQuestToggle, panel, holder, c) end
end

-- BEGIN hidequests (2.0.15)
-- "Hide quests" on the dungeon maps, just above Boss icons: takes the
-- quests' ! and ? off the map (the quest spots and the objective ?).
-- What the player asks for still shows: the quest tracker's ! / ? and a
-- quest's Show on Map (the spot it opens the map on). Saved for all
-- characters (ForeverDungeonJournalDB.mapHideQuests).
local HIDE_LABEL = {
    enUS = "Hide quests", deDE = "Quests ausblenden", frFR = "Masquer les quêtes", esES = "Ocultar misiones",
    itIT = "Nascondi missioni", ptBR = "Ocultar missões", ruRU = "Скрыть задания", koKR = "퀘스트 숨기기",
    zhCN = "隐藏任务", zhTW = "隱藏任務",
}

-- autohidequests (2.0.52): on the map of a dungeon where the character has
-- nothing left to do inside (FDJ.MapQuestsAllDoneInside: every quest with a
-- mark on the map done there, 2.0.53), the box is ticked by itself. The
-- saved choice is not changed; unticking it there shows that dungeon's
-- quests again until the next reload.
local shownAnyway = {}
local function AllDone(name)
    return name ~= nil and FDJ.MapQuestsAllDoneInside ~= nil and FDJ.MapQuestsAllDoneInside(name) == true
end
local function Selected()
    return FDJ.GetSelectedDungeon and (FDJ.GetSelectedDungeon()) or nil
end
function FDJ.MapQuestsHidden(dungeonName)
    if ForeverDungeonJournalDB ~= nil and ForeverDungeonJournalDB.mapHideQuests == true then return true end
    local name = dungeonName or Selected()
    return name ~= nil and not shownAnyway[name] and AllDone(name)
end

local function Redraw()
    local frame = _G.ForeverDungeonJournalFrame
    local dungeon = FDJ.GetSelectedDungeon and FDJ.GetSelectedDungeon()
    local data = dungeon and FDJ.DUNGEON_MAPS and FDJ.DUNGEON_MAPS[dungeon]
    if data and frame and FDJ.RenderCustomDungeonMap then
        pcall(FDJ.RenderCustomDungeonMap, data, frame.dungeonMapFloor)
    end
end

function FDJ.SetMapQuestsHidden(on)
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    local name = Selected()
    if name and AllDone(name) then
        -- autohidequests: only this dungeon's, the saved choice stays as it is
        -- unless it was on (then unticking turns it off, as before).
        shownAnyway[name] = (not on) and true or nil
        if not on then ForeverDungeonJournalDB.mapHideQuests = nil end
    else
        ForeverDungeonJournalDB.mapHideQuests = on and true or nil
    end
    Redraw()
end

function FDJ.UpdateMapQuestToggle(panel, holder, sizer)
    local q = panel.fdjQuestToggle
    if not q then
        q = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        panel.fdjQuestToggle = q
        q:SetHeight(28)
        q:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        q:SetBackdropColor(0, 0, 0, 0.75)
        q:SetBackdropBorderColor(0.45, 0.38, 0.25, 1)
        q.check = CreateFrame("CheckButton", nil, q, "UICheckButtonTemplate")
        FDJ.OwnFonts(q.check)
        q.check:SetSize(22, 22)
        q.check:SetPoint("LEFT", 4, 0)
        q.label = q:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
        q.label:SetPoint("LEFT", q.check, "RIGHT", 0, 1)
        q.label:SetJustifyH("LEFT")
        -- The label is part of the box: clicking it ticks too.
        q.check:SetHitRectInsets(0, -200, 0, 0)
        q.check:SetScript("OnClick", function(self)
            FDJ.SetMapQuestsHidden(self:GetChecked() and true or false)
        end)
    end
    local lang = FDJ.GetLanguage and FDJ.GetLanguage() or "enUS"
    q.label:SetText(HIDE_LABEL[lang] or HIDE_LABEL.enUS)
    q.check:SetChecked(FDJ.MapQuestsHidden())
    local w = math.max(sizer and sizer:GetWidth() or 92, 4 + 22 + (q.label:GetStringWidth() or 60) + 10)
    q:SetWidth(w)
    q.check:SetHitRectInsets(0, -(w - 30), 0, 0)
    if sizer and sizer.GetWidth and sizer:GetWidth() < w then sizer:SetWidth(w) end
    q:ClearAllPoints()
    if sizer then
        q:SetPoint("BOTTOMLEFT", sizer, "TOPLEFT", 0, 4)
    else
        q:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 58)
    end
    q:SetFrameLevel(holder:GetFrameLevel() + 30)
    q:Show()
end
-- END hidequests
