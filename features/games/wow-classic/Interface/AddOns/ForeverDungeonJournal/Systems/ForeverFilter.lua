-- WoW Forever emblem at the top left of the home page: click it to show only the
-- dungeons that are new in WoW Forever, click again to show every dungeon.
-- hometabs (2.0.10, M 17 Nov 2026: "we are also gonna change that icon to just
-- show the dungeon page"): the emblem is now the dungeon list's tab in the row
-- of icons (Systems/TierSets.lua): a click shows the dungeon list, and it is
-- lit while the list is shown. "Forever dungeons only" stays in Options.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

local ICON = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\ForeverIcon"
-- foreverview (2.1.3, M 22 Nov 2026, players confused by the Forever-only
-- list: "whenever you're in the forever dungeon only view, I wanted some kind
-- of indicator ... we change the color of the journal, and we swap the logo,
-- and we add those things"): while "Forever Dungeons Only" is on, the home
-- page takes the blue of the WoW Forever logo, the emblem becomes the logo on
-- its blue background (Media/ForeverOnlyIcon.tga, from M's picture), its
-- tooltip says "Forever Only View" / "Right-click to disable", and a right
-- click on it turns the view off.
local ICON_ONLY = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\ForeverOnlyIcon"
do
    local strings = {
        enUS = { "Forever Only View", "Right-click to disable" },
        deDE = { "Nur-Forever-Ansicht", "Rechtsklick zum Ausschalten" },
        frFR = { "Vue Forever uniquement", "Clic droit pour désactiver" },
        esES = { "Vista solo Forever", "Clic derecho para desactivar" },
        itIT = { "Vista solo Forever", "Clic destro per disattivare" },
        ptBR = { "Visão só Forever", "Clique com o botão direito para desativar" },
        ruRU = { "Только подземелья Forever", "Щелкните правой кнопкой, чтобы отключить" },
        koKR = { "Forever 전용 보기", "우클릭하여 끄기" },
        zhCN = { "仅Forever视图", "右键点击关闭" },
        zhTW = { "僅Forever檢視", "右鍵點擊關閉" },
    }
    strings.esMX = strings.esES
    for locale, pair in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            if t.FOREVER_ONLY_VIEW == nil then t.FOREVER_ONLY_VIEW = pair[1] end
            if t.FOREVER_ONLY_RCLICK == nil then t.FOREVER_ONLY_RCLICK = pair[2] end
        end
    end
end

-- Dungeons added by WoW Forever (not in the original Classic game).
FDJ.FOREVER_DUNGEONS = {
    ["Hall of Thanes"] = true,
    ["Ruins of Lordaeron"] = true,
    ["Excavation Site: Wetlands"] = true,
    ["City of Dalaran"] = true,
    ["The Drowned City"] = true,
    ["Krol'dok Stronghold"] = true,
    ["Alcaz Prison"] = true,
    ["Blackmaw Hold"] = true,
    ["Shaper's Terrace"] = true,
}

local function L(key, ...)
    if FDJ.L then return FDJ.L(key, ...) end
    return key
end

local function Active()
    return ForeverDungeonJournalDB and ForeverDungeonJournalDB.foreverOnly and true or false
end

-- The emblem and the "Forever Dungeons Only" option (Systems/SettingsPanel.lua)
-- are the same switch: either one turns it on and off.
function FDJ.IsForeverOnly()
    return Active()
end

function FDJ.SetForeverOnly(on)
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    ForeverDungeonJournalDB.foreverOnly = on and true or nil
    if FDJ.RefreshSettingsChecks then pcall(FDJ.RefreshSettingsChecks) end
end

-- foreverreset (2.1.3, M 21 Nov 2026, players on the Discord seeing only
-- WoW Forever's dungeons after updating, without having touched anything:
-- "just untick it on the next update for everybody. Since if they have it
-- toggled, they know how to untoggle"): until 2.0.10 a click on the emblem
-- turned "Forever Dungeons Only" on, and it stayed saved; since then the
-- emblem only opens the dungeon list, so it no longer turns it off, and the
-- switch is only in Options. Once, on the first login with this version,
-- it is turned off for everyone (each account once).
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, name)
        if name ~= "ForeverDungeonJournal" then return end
        self:UnregisterEvent("ADDON_LOADED")
        ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
        if not ForeverDungeonJournalDB.foreverOnlyReset then
            ForeverDungeonJournalDB.foreverOnly = nil
            ForeverDungeonJournalDB.foreverOnlyReset = 1
        end
    end)
end

-- Asked by the home list for every dungeon.
function FDJ.HomeFilterHides(dungeonName)
    return Active() and not FDJ.FOREVER_DUNGEONS[dungeonName]
end

-- foreverview: the home page in the logo's blue while the view is on; back to
-- the journal's own brown (Core/Journal.lua ApplyTheme's colours) when off.
local function Tint(frame)
    local home = frame and frame.homePanel
    if not home then return end
    if Active() then
        home:SetBackdropColor(0.02, 0.16, 0.27, 0.96)
        home:SetBackdropBorderColor(0.23, 0.76, 0.96, 1)
        if frame.homeParchment then frame.homeParchment:SetVertexColor(0.70, 0.90, 1.00) end
        frame.fdjForeverTint = true
    elseif frame.fdjForeverTint then
        home:SetBackdropColor(0.16, 0.12, 0.07, 0.96)
        home:SetBackdropBorderColor(0.47, 0.34, 0.16, 1)
        if frame.homeParchment then frame.homeParchment:SetVertexColor(1.00, 0.95, 0.84) end
        frame.fdjForeverTint = nil
    end
end
FDJ.TintForeverView = Tint

local function Paint(btn)
    local on = (FDJ.ActiveHomeTab and FDJ.ActiveHomeTab() or "dungeons") == "dungeons" -- hometabs
    local only = Active() -- foreverview: the logo on its blue background
    if btn.fdjOnly ~= only then
        btn.fdjOnly = only
        btn.icon:SetTexture(only and ICON_ONLY or ICON)
        if btn.hl then btn.hl:SetTexture(only and ICON_ONLY or ICON) end
    end
    Tint(_G.ForeverDungeonJournalFrame)
    btn.icon:SetAlpha(1)
    -- Always a soft golden glow (same as the LFG / Show Location buttons) so
    -- it reads as clickable; brighter with a gold ring while the filter is on.
    btn.halo:SetAlpha(on and 1 or 0.75)
    local w = btn:GetWidth() or 26
    if w < 1 then w = 26 end
    local halo = math.floor(w * (on and 2.15 or 1.92) + 0.5)
    btn.halo:SetSize(halo, halo)
    btn.glow:SetSize(math.floor(w * 1.92 + 0.5), math.floor(w * 1.92 + 0.5))
    btn.glow:SetShown(on)
end

-- The first time ever the emblem is clicked (the list now shows only WoW
-- Forever dungeons), a note with a red arrow, fading in and out like the
-- Group Browser one, points at the emblem from its left: Switch back to full
-- view. It goes away once the full list is back (or the page is left).
local HINT = {
    enUS = "Switch back to full view", deDE = "Zurück zur vollen Ansicht",
    frFR = "Revenir à la vue complète", esES = "Volver a la vista completa", esMX = "Volver a la vista completa",
    itIT = "Torna alla vista completa", ptBR = "Voltar à visão completa",
    ruRU = "Вернуться к полному списку", koKR = "전체 보기로 돌아가기",
    zhCN = "切换回完整视图", zhTW = "切換回完整檢視",
}
local function ShowFullViewHint(btn)
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    if ForeverDungeonJournalDB.foreverHintShown then return end
    ForeverDungeonJournalDB.foreverHintShown = true
    local h = FDJ.foreverHint
    if not h then
        h = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        FDJ.foreverHint = h
        h:SetFrameStrata("FULLSCREEN_DIALOG")
        h:SetSize(240, 32)
        h:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        h:SetBackdropColor(0, 0, 0, 0.92)
        h:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        h.arrow = h:CreateTexture(nil, "OVERLAY")
        h.arrow:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\QuestNextArrow")
        h.arrow:SetVertexColor(1, 0.12, 0.08)
        h.arrow:SetSize(24, 24)
        h.arrow:SetPoint("RIGHT", -6, 0)
        h.text = h:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightLarge")
        h.text:SetPoint("RIGHT", h.arrow, "LEFT", -6, 0)
        h.text:SetTextColor(1, 1, 1)
        h.text:SetShadowColor(0, 0, 0, 1)
        h.text:SetShadowOffset(1, -1)
        h:SetScript("OnUpdate", function(self, elapsed)
            self.t = (self.t or 0) + elapsed
            -- Fade in and out, and nudge the arrow toward the emblem.
            self:SetAlpha(0.55 + 0.45 * math.sin(self.t * 4))
            self.arrow:SetPoint("RIGHT", -6 + 3 * math.abs(math.sin(self.t * 4)), 0)
            if not Active() or not (self.fdjTarget and self.fdjTarget:IsVisible()) then self:Hide() end
        end)
    end
    local lang = FDJ.GetLanguage and FDJ.GetLanguage() or "enUS"
    h.text:SetText(HINT[lang] or HINT.enUS)
    h:SetWidth((h.text:GetStringWidth() or 180) + 50)
    h:ClearAllPoints()
    h:SetPoint("RIGHT", btn, "LEFT", -8, 0)
    h.fdjTarget = btn
    h.t = 0
    h:Show()
end

local function Build(frame)
    local home = frame.homePanel
    local btn = CreateFrame("Button", nil, home)
    btn:SetSize(26, 26)
    btn:SetFrameLevel(home:GetFrameLevel() + 5)

    local halo = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
    halo:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\TickGlow")
    halo:SetBlendMode("ADD")
    halo:SetVertexColor(1, 0.82, 0.35)
    halo:SetPoint("CENTER")
    btn.halo = halo

    local glow = btn:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\TabRing") -- roundtab (2.0.10): round, not square
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.82, 0.3, 0.95)
    glow:SetPoint("CENTER")
    glow:SetSize(50, 50)
    btn.glow = glow

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetAllPoints()
    btn.icon = icon

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(ICON)
    hl:SetAllPoints()
    hl:SetBlendMode("ADD")
    hl:SetAlpha(0.35)
    btn.hl = hl -- (foreverview: swapped with the icon)

    btn:SetScript("OnMouseDown", function() icon:SetPoint("TOPLEFT", 1, -1); icon:SetPoint("BOTTOMRIGHT", 1, -1) end)
    btn:SetScript("OnMouseUp", function() icon:ClearAllPoints(); icon:SetAllPoints() end)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, mouseButton)
        -- foreverview: a right click turns the Forever-only view off
        if mouseButton == "RightButton" then
            if Active() then
                FDJ.SetForeverOnly(false)
                if FDJ.RefreshHomeCards then pcall(FDJ.RefreshHomeCards) end
                Paint(self)
                if self:IsMouseOver() and self:GetScript("OnEnter") then self:GetScript("OnEnter")(self) end
            end
            return
        end
        if PlaySound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.IG_ABILITY_PAGE_TURN) or 836) end -- tabsound (2.0.11): the journal's opening page sound
        if FDJ.ShowDungeonsTab then FDJ.ShowDungeonsTab() end -- hometabs: the dungeon list
        Paint(self)
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if Active() then -- foreverview
            GameTooltip:SetText(L("FOREVER_ONLY_VIEW"), 0.36, 0.82, 1)
            GameTooltip:AddLine(L("FOREVER_ONLY_RCLICK"), 1, 1, 1)
        else
            GameTooltip:SetText(L("DUNGEONS"), 1, 0.82, 0)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.foreverFilterButton = btn
    return btn
end

-- hometabs: lit or not as the shown page changes (Systems/TierSets.lua).
function FDJ.PaintForeverEmblem()
    local frame = _G.ForeverDungeonJournalFrame
    if frame and frame.foreverFilterButton then Paint(frame.foreverFilterButton) end
end

-- Raids medallion next to the Forever emblem: greyed out until raids are added.
local RAID_ICON = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\RaidExpansionIcon"
local function BuildRaid(frame)
    local home = frame.homePanel
    local btn = CreateFrame("Button", nil, home)
    btn:SetSize(40, 40)
    btn:SetFrameLevel(home:GetFrameLevel() + 5)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(RAID_ICON)
    icon:SetAllPoints()
    icon:SetDesaturated(true)
    icon:SetAlpha(0.45)
    btn.icon = icon
    btn:SetScript("OnEnter", function(self)
        icon:SetAlpha(0.6)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L("RAIDS_TITLE"), 1, 0.82, 0)
        GameTooltip:AddLine(L("COMING_SOON"), 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        icon:SetAlpha(0.45)
        GameTooltip:Hide()
    end)
    frame.foreverRaidButton = btn
    return btn
end

local function PlaceRaid(frame, emblem, size)
    local btn = frame.foreverRaidButton or BuildRaid(frame)
    btn:SetSize(size, size)
    btn:ClearAllPoints()
    btn:SetPoint("LEFT", emblem, "RIGHT", size >= 40 and 12 or (size >= 30 and 10 or 8), 0)
    btn:Show()
end

local function Place(frame)
    local home = frame and frame.homePanel
    if not home then return end
    local btn = frame.foreverFilterButton or Build(frame)
    btn:ClearAllPoints()
    local rpg = FDJ.IsRPGMode and FDJ.IsRPGMode()
    local emblemSize = 40
    if rpg and frame.rpgBar and frame.rpgBar:IsShown() then
        -- RPG Mode: sits above the left end of the progress bar. The bar is
        -- under the header's row of buttons (RPG Mode, Favourites...), so the
        -- emblem lines up with them.
        frame.rpgBar:ClearAllPoints()
        frame.rpgBar:SetPoint("TOPLEFT", home, "TOPLEFT", 26, -(FDJ.RPG_BAR_Y or 37))
        -- rpgicons (1.9.8): 32, was 22 (too small).
        btn:SetSize(32, 32)
        emblemSize = 32
        btn:SetPoint("BOTTOMLEFT", frame.rpgBar, "TOPLEFT", 2, 2)
    else
        -- Gamer Mode: no "Browse Dungeons" heading; the emblem sits alone at the
        -- left of the header row, level with the Favourites / Loot Filter buttons
        -- (same layout as the TBC journal's round expansion icons).
        if frame.homeTitle then frame.homeTitle:Hide() end
        if frame.homeSubtitle then frame.homeSubtitle:Hide() end
        btn:SetSize(40, 40)
        btn:SetPoint("TOPLEFT", home, "TOPLEFT", 22, -10)
    end
    Paint(btn)
    btn:Show()
    PlaceRaid(frame, btn, emblemSize)
    -- The Cozy Sleeping Bag's medallion, right of the Raids one (Systems/QuestText.lua).
    if FDJ.PlaceSleepingBagButton and frame.foreverRaidButton then
        pcall(FDJ.PlaceSleepingBagButton, frame, frame.foreverRaidButton, emblemSize)
    end
end

-- The home list calls UpdateRPGHeader after every refresh; place the emblem
-- there too so it follows the title (Gamer Mode) or the bar (RPG Mode).
local orig = FDJ.UpdateRPGHeader
FDJ.UpdateRPGHeader = function(frame, ...)
    if orig then pcall(orig, frame, ...) end
    pcall(Place, frame)
end
