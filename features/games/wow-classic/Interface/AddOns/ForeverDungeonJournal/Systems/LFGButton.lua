-- "Looking For Group" eye on the dungeon page header, next to the Show
-- Location button. Click opens the game's Looking For Group window and tries
-- to pick this dungeon in it. The eye is the game's own animated LFG eye.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

local EYE = "Interface\\LFGFrame\\LFG-Eye" -- 512x256 sheet, 64x64 frames, 29 frames

local TIP = {
    enUS = "Find a group for %s", deDE = "Gruppe suchen für %s",
    frFR = "Trouver un groupe pour %s", esES = "Buscar grupo para %s",
    itIT = "Cerca un gruppo per %s", ptBR = "Procurar grupo para %s",
    ruRU = "Найти группу: %s", koKR = "%s 파티 찾기",
    zhCN = "为%s寻找队伍", zhTW = "為%s尋找隊伍",
}
local TITLE = {
    enUS = "Looking For Group", deDE = "Gruppensuche", frFR = "Recherche de groupe",
    esES = "Buscar grupo", itIT = "Ricerca gruppo", ptBR = "Procurar grupo",
    ruRU = "Поиск группы", koKR = "파티 찾기", zhCN = "寻找队伍", zhTW = "尋找隊伍",
}
local function Lang() return FDJ.GetLanguage and FDJ.GetLanguage() or "enUS" end

-- ---------------------------------------------------------------- opening
-- Forever's Looking For Group window (LFGParentFrame, with the Browse tab
-- LFGBrowseFrame) is opened with LFGVanilla_ToggleFrame / ToggleGroupFinderFrame.
local function IsLFGShown()
    local f = _G.LFGParentFrame
    return f and f.IsVisible and f:IsVisible() or false
end

local function OpenLFG()
    if IsLFGShown() then return true end
    local tries = {}
    if GroupFinderVanillaStyle_LoadUI then tries[#tries + 1] = function() GroupFinderVanillaStyle_LoadUI() end end
    if LFGVanilla_ToggleFrame then tries[#tries + 1] = function() LFGVanilla_ToggleFrame() end end
    if ToggleGroupFinderFrame then tries[#tries + 1] = function() ToggleGroupFinderFrame() end end
    if ToggleLFGParentFrame then tries[#tries + 1] = function() ToggleLFGParentFrame() end end
    if LFGParentFrame then tries[#tries + 1] = function() ShowUIPanel(LFGParentFrame) end end
    if LFGParentFrame then tries[#tries + 1] = function() LFGParentFrame:Show() end end
    for _, try in ipairs(tries) do
        local ok, err = pcall(try)
        if not ok then FDJ.lfgLastError = tostring(err) end
        -- Stop as soon as it is open, so a later toggle can't close it again.
        if IsLFGShown() then return true end
    end
    return IsLFGShown()
end

-- ------------------------------------------------- picking the dungeon
-- Activity IDs in Forever's list (category 2 = Dungeons). Journal names that
-- differ from the list are mapped here; the rest are matched by name.
local ACTIVITY_IDS = {
    ["Ragefire Chasm"] = 798, ["Wailing Caverns"] = 796, ["The Deadmines"] = 799,
    ["Shadowfang Keep"] = 800, ["Blackfathom Deeps"] = 801, ["Gnomeregan"] = 803,
    ["Razorfen Kraul"] = 804, ["Scarlet Monastery: Graveyard"] = 805,
    ["Scarlet Monastery: Library"] = 829, ["Scarlet Monastery: Armory"] = 827,
    ["Scarlet Monastery: Cathedral"] = 828, ["Razorfen Downs"] = 806,
    ["Hall of Thanes"] = 1984, ["City of Dalaran"] = 1983, ["Ruins of Lordaeron"] = 1982,
    ["Excavation Site: Wetlands"] = 1981,
}

local function Norm(s)
    if type(s) ~= "string" then return "" end
    return (s:lower():gsub("^the ", ""):gsub("[^%w]", ""))
end

local function FindActivity(dungeonName)
    local id = ACTIVITY_IDS[dungeonName]
    local info
    if C_LFGList and C_LFGList.GetActivityInfoTable then
        if id then
            local ok, i = pcall(C_LFGList.GetActivityInfoTable, id)
            if ok and type(i) == "table" then return id, i end
        end
        local ok, ids = pcall(C_LFGList.GetAvailableActivities)
        if ok and type(ids) == "table" then
            local wanted = Norm(dungeonName)
            for _, aid in ipairs(ids) do
                local ok2, i = pcall(C_LFGList.GetActivityInfoTable, aid)
                if ok2 and type(i) == "table" and (Norm(i.fullName) == wanted or Norm(i.shortName) == wanted) then
                    return aid, i
                end
            end
            -- Names that differ a little ("The Stockade" / "Stormwind
            -- Stockades"): one contains the other, plural "s" ignored.
            local stem = wanted:gsub("s$", "")
            if #stem >= 5 then
                for _, aid in ipairs(ids) do
                    local ok2, i = pcall(C_LFGList.GetActivityInfoTable, aid)
                    if ok2 and type(i) == "table" then
                        for _, n in ipairs({ Norm(i.fullName), Norm(i.shortName) }) do
                            local ns = n:gsub("s$", "")
                            if ns ~= "" and (ns:find(stem, 1, true) or stem:find(ns, 1, true)) then return aid, i end
                        end
                    end
                end
            end
        end
    end
    return id, info
end

-- Forever: LFGBrowseFrame:ShowSearchForActivities(activityIDs) selects the
-- activities and starts the search itself. It must run straight from the
-- click (searching needs a real key/mouse press), never from a timer.
local function SelectActivity(activityID)
    local browse = _G.LFGBrowseFrame
    if not browse or not activityID or not browse.ShowSearchForActivities then return false end
    local ok, err = pcall(browse.ShowSearchForActivities, browse, { activityID })
    if not ok then FDJ.lfgLastError = tostring(err) end
    return ok
end

local function OpenFor(dungeonName)
    FDJ.lfgLastError = nil
    local opened = OpenLFG()
    if ForeverDungeonJournalDB then
        ForeverDungeonJournalDB.lfgClick = { shown = opened, err = FDJ.lfgLastError }
    end
    if not opened then
        print("|cffffd200Dungeon Journal:|r couldn't open the Looking For Group window"
            .. (FDJ.lfgLastError and (" (" .. FDJ.lfgLastError .. ")") or "") .. ".")
        return
    end
    -- The journal sits above normal game windows: close it so the Looking
    -- For Group window isn't hidden behind it.
    local journal = _G.ForeverDungeonJournalFrame
    if journal and journal:IsShown() then journal:Hide() end
    -- Picking the dungeon from addon code taints the window (see the overlay
    -- below), so the window is only opened.
    do return end
    local id = FindActivity(dungeonName)
    if not id then return end
    local ok = SelectActivity(id)
    if ForeverDungeonJournalDB and ForeverDungeonJournalDB.lfgClick then
        ForeverDungeonJournalDB.lfgClick.selected = ok
        ForeverDungeonJournalDB.lfgClick.activity = id
        ForeverDungeonJournalDB.lfgClick.err = FDJ.lfgLastError
    end
end

-- ------------------------------------------------------ direct search
-- Asks the server for this dungeon's groups ourselves (C_LFGList.Search, the
-- same call the window's own search makes) instead of calling the window's
-- code. The results arrive as a game event that the window handles with its
-- own untouched code, so nothing in it gets tainted. Only the drop-down
-- labels are relabelled (plain text on the font strings) to match.
local function SetLabel(dropdown, text)
    if not dropdown or not text then return end
    local fs = dropdown.Text
    if not (fs and fs.SetText) and dropdown.GetRegions then
        for _, region in ipairs({ dropdown:GetRegions() }) do
            if region.GetObjectType and region:GetObjectType() == "FontString" then fs = region; break end
        end
    end
    if fs and fs.SetText then fs:SetText(text) end
end

function FDJ.SearchDungeonDirect(dungeonName)
    local log = { mode = "direct", dungeon = dungeonName }
    if ForeverDungeonJournalDB then ForeverDungeonJournalDB.lfgClick = log end
    local id, info = FindActivity(dungeonName)
    log.activity = id
    if not id or not (C_LFGList and C_LFGList.Search) then return end
    local categoryID = (info and info.categoryID) or 2
    local ok, err = pcall(C_LFGList.Search, categoryID, 0, 0, nil, false, nil, { id })
    log.ok = ok
    log.err = not ok and tostring(err) or nil
    if not ok then return end
    pcall(function()
        local browse = LFGBrowseFrame
        SetLabel(browse.ActivityDropdown, (info and (info.fullName or info.shortName)) or dungeonName)
        local okCat, catInfo = pcall(C_LFGList.GetLfgCategoryInfo, categoryID)
        if okCat and type(catInfo) == "table" and catInfo.name then SetLabel(browse.CategoryDropdown, catInfo.name) end
    end)
end

-- ---------------------------------------------------------- browse hint
-- The Browse tab only reacts to a real mouse click, so when the window
-- opened on another page a note with a red arrow, fading in and out, points
-- at the Group Browser tab until you switch (or close the window).
local HINT = {
    enUS = "Switch to Group Browser", deDE = "Zum Gruppenbrowser wechseln",
    frFR = "Passer au navigateur de groupes", esES = "Cambiar al buscador de grupos",
    itIT = "Passa al browser dei gruppi", ptBR = "Mudar para o navegador de grupos",
    ruRU = "Перейти к обзору групп", koKR = "파티 찾아보기로 전환",
    zhCN = "切换到队伍浏览器", zhTW = "切換到隊伍瀏覽器",
}
function FDJ.ShowBrowseHint()
    local tab = LFGParentFrame and LFGParentFrame.BrowsingTab
    if not tab or not IsLFGShown() then return end
    if LFGBrowseFrame and LFGBrowseFrame:IsVisible() then return end
    local h = FDJ.browseHint
    if not h then
        h = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        FDJ.browseHint = h
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
        h.arrow:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\QuestPrevArrow")
        h.arrow:SetVertexColor(1, 0.12, 0.08)
        h.arrow:SetSize(24, 24)
        h.arrow:SetPoint("LEFT", 6, 0)
        h.text = h:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightLarge")
        h.text:SetPoint("LEFT", h.arrow, "RIGHT", 6, 0)
        h.text:SetTextColor(1, 1, 1)
        h.text:SetShadowColor(0, 0, 0, 1)
        h.text:SetShadowOffset(1, -1)
        h:SetScript("OnUpdate", function(self, elapsed)
            self.t = (self.t or 0) + elapsed
            -- Fade in and out, and nudge the arrow toward the tab.
            self:SetAlpha(0.55 + 0.45 * math.sin(self.t * 4))
            self.arrow:SetPoint("LEFT", 6 - 3 * math.abs(math.sin(self.t * 4)), 0)
            if (LFGBrowseFrame and LFGBrowseFrame:IsVisible()) or not IsLFGShown() then self:Hide() end
        end)
    end
    local lang = FDJ.GetLanguage and FDJ.GetLanguage() or "enUS"
    h.text:SetText(HINT[lang] or HINT.enUS)
    h:SetWidth((h.text:GetStringWidth() or 180) + 50)
    h:ClearAllPoints()
    h:SetPoint("LEFT", tab, "RIGHT", 6, 0)
    h.t = 0
    h:Show()
end

-- ------------------------------------------------------- secure overlay
-- Searching for groups is locked to the game's own code: if addon code opens
-- the window or picks a dungeon, every search afterwards fails ("Searching..."
-- forever, until /reload). So an invisible secure button lies on top of the
-- eye and simply presses the game's own Group Finder micro button. It sits
-- on UIParent (not inside the journal), so the journal can still open and
-- close in combat; in combat the overlay is hidden and the eye does nothing.
function FDJ.CreateLFGOverlay(eye)
    local micro = _G.LFDMicroButton or _G.LFGMicroButton
    if not micro or eye.fdjOverlay then return end
    local o = CreateFrame("Button", "ForeverDungeonJournalLFGOverlay", UIParent, "SecureActionButtonTemplate")
    eye.fdjOverlay = o
    o:SetFrameStrata("FULLSCREEN")
    o:RegisterForClicks("AnyUp", "AnyDown")
    -- Everything here goes through secure clicks only. Addon code must never
    -- call into the Looking For Group window: that "taints" it, and the game
    -- then refuses to show the group list (secret values) until /reload.
    -- Step 1: press the game's Group Finder button. Step 2: press the Browse
    -- (magnifying glass) tab through a second secure button.
    -- The Browse tab may not exist yet at login (the game loads its LFG
    -- window on first use), so the proxy is always created and pointed at
    -- the tab as soon as the tab exists (before each click, out of combat).
    local proxy = CreateFrame("Button", "ForeverDungeonJournalLFGBrowseTab", UIParent, "SecureActionButtonTemplate")
    proxy:SetAttribute("type", "click")
    proxy:RegisterForClicks("AnyUp", "AnyDown")
    local function PointProxy()
        if InCombatLockdown and InCombatLockdown() then return end
        local tab = LFGParentFrame and LFGParentFrame.BrowsingTab
        if tab and proxy:GetAttribute("clickbutton") ~= tab then proxy:SetAttribute("clickbutton", tab) end
    end
    PointProxy()
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:RegisterEvent("PLAYER_ENTERING_WORLD")
    loader:SetScript("OnEvent", function() PointProxy() end)
    o.fdjPointProxy = PointProxy
    -- (The Browse tab is a plain frame that only reacts to a real mouse
    -- click, so it can't be pressed from here; the window opens on the page
    -- it was last left on.)
    local macro = "/click " .. micro:GetName()
    o:SetAttribute("type", "macro")
    o:SetAttribute("macrotext", macro)
    -- Right-click: no game action, just the small Disable menu (PostClick).
    o:SetAttribute("type2", "fdjmenu")
    o:Hide()
    o:SetScript("OnEnter", function() local f = eye:GetScript("OnEnter"); if f then f(eye) end; eye:LockHighlight() end)
    o:SetScript("OnLeave", function() GameTooltip:Hide(); eye:UnlockHighlight() end)
    o:SetScript("PreClick", function(_, button)
        PointProxy()
        -- Window already open: don't press the game's button again (it would
        -- toggle the window shut); the click then only searches the dungeon.
        if button ~= "RightButton" and not (InCombatLockdown and InCombatLockdown()) then
            o:SetAttribute("type", IsLFGShown() and "fdjnone" or "macro")
        end
    end)
    o:SetScript("PostClick", function(_, button, down)
        PointProxy() -- first ever click: the window was only just loaded
        if button == "RightButton" then
            if not down then FDJ.ShowLFGMenu(eye) end
            return
        end
        -- (Down and up both arrive here; act once per press.)
        local now = GetTime and GetTime() or 0
        if o.fdjLast and now - o.fdjLast < 0.5 then return end
        o.fdjLast = now
        if IsLFGShown() and eye.fdjDungeon then
            FDJ.SearchDungeonDirect(eye.fdjDungeon)
            if C_Timer and C_Timer.After then C_Timer.After(0.15, FDJ.ShowBrowseHint) end
        end
        if ForeverDungeonJournalDB and ForeverDungeonJournalDB.lfgClick then
            local log = ForeverDungeonJournalDB.lfgClick
            log.proxyTarget = proxy:GetAttribute("clickbutton") and true or false
            log.shownAtClick = IsLFGShown()
            if C_Timer and C_Timer.After then
                C_Timer.After(1, function()
                    log.browseVisibleLater = LFGBrowseFrame and LFGBrowseFrame:IsVisible() or false
                    log.listingVisibleLater = LFGListingFrame and LFGListingFrame:IsVisible() or false
                    log.tabLater = LFGParentFrame and LFGParentFrame.selectedTab
                end)
            end
        end
        -- The journal stays open; lift the Looking For Group window above it.
        -- (Only frame layering is changed, none of the window's code is run.)
        if IsLFGShown() and not (InCombatLockdown and InCombatLockdown()) then
            pcall(function()
                local journal = _G.ForeverDungeonJournalFrame
                LFGParentFrame:SetFrameStrata(journal and journal:GetFrameStrata() or "DIALOG")
                if journal then LFGParentFrame:SetFrameLevel(journal:GetFrameLevel() + 50) end
            end)
        end
    end)

    local function Place()
        if InCombatLockdown and InCombatLockdown() then return end
        if not eye:IsVisible() then
            if o:IsShown() then o:Hide() end
            return
        end
        local l, btm, w, h = eye:GetLeft(), eye:GetBottom(), eye:GetWidth(), eye:GetHeight()
        if not l then return end
        local scale = eye:GetEffectiveScale() / UIParent:GetEffectiveScale()
        o:ClearAllPoints()
        o:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * scale, btm * scale)
        o:SetSize(w * scale, h * scale)
        if not o:IsShown() then o:Show() end
    end
    eye:HookScript("OnUpdate", Place)
    eye:HookScript("OnHide", function()
        if not (InCombatLockdown and InCombatLockdown()) then o:Hide() end
    end)
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:SetScript("OnEvent", function() o:Hide() end) -- fires just before combat lockdown
end

-- ------------------------------------------------------------ portrait
local function PortraitSource()
    local candidates = {
        LFGBrowseFrame and LFGBrowseFrame.PortraitContainer and LFGBrowseFrame.PortraitContainer.portrait,
        LFGParentFrame and LFGParentFrame.PortraitContainer and LFGParentFrame.PortraitContainer.portrait,
        LFGListingFrame and LFGListingFrame.PortraitContainer and LFGListingFrame.PortraitContainer.portrait,
        _G.LFGParentFramePortraitTexture,
    }
    for _, tex in pairs(candidates) do
        if tex and tex.GetTexture then
            local atlas = tex.GetAtlas and tex:GetAtlas()
            local file = tex:GetTexture()
            if (atlas and atlas ~= "") or file then return tex, atlas, file end
        end
    end
    return nil
end

local RING = "Interface\\Common\\GoldRing"
function FDJ.ApplyLFGPortrait(b)
    if not b or b.fdjPortraitDone then return end
    pcall(function()
        local src, atlas, file = PortraitSource()
        if not src then return end
        if ForeverDungeonJournalDB then
            ForeverDungeonJournalDB.lfgPortrait = { atlas = atlas, file = file and tostring(file), coords = { src:GetTexCoord() } }
        end
        b.icon:ClearAllPoints()
        b.icon:SetPoint("CENTER")
        b.icon:SetSize(30, 30)
        if atlas and atlas ~= "" then
            b.icon:SetAtlas(atlas)
        else
            b.icon:SetTexture(file)
            b.icon:SetTexCoord(src:GetTexCoord())
        end
        -- Round it off like the window's portrait.
        if not b.fdjMask and b.CreateMaskTexture then
            local mask = b:CreateMaskTexture()
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(b.icon)
            b.icon:AddMaskTexture(mask)
            b.fdjMask = mask
        end
        local hasRing = true
        if GetFileIDFromPath then
            local ok, id = pcall(GetFileIDFromPath, RING)
            hasRing = ok and id ~= nil
        end
        if hasRing and not b.fdjRing then
            local ring = b:CreateTexture(nil, "OVERLAY")
            ring:SetTexture(RING)
            ring:SetPoint("CENTER")
            ring:SetSize(37, 37)
            b.fdjRing = ring
        end
        b.fdjPortraitDone = true
    end)
end

-- ------------------------------------------------- hide / show option
local DISABLE = {
    enUS = "Disable", deDE = "Deaktivieren", frFR = "Désactiver", esES = "Desactivar",
    itIT = "Disattiva", ptBR = "Desativar", ruRU = "Отключить", koKR = "비활성화",
    zhCN = "禁用", zhTW = "停用",
}
local SHOW_PANEL = {
    enUS = "Show LFG Panel", deDE = "LFG-Button anzeigen", frFR = "Afficher le bouton RdG",
    esES = "Mostrar botón de BdG", itIT = "Mostra pulsante Cerca gruppo", ptBR = "Mostrar botão de PdG",
    ruRU = "Показать кнопку поиска группы", koKR = "파티 찾기 버튼 표시", zhCN = "显示寻找队伍按钮", zhTW = "顯示尋找隊伍按鈕",
}
local HIDE_PANEL = {
    enUS = "Hide LFG Panel", deDE = "LFG-Button ausblenden", frFR = "Masquer le bouton RdG",
    esES = "Ocultar botón de BdG", itIT = "Nascondi pulsante Cerca gruppo", ptBR = "Ocultar botão de PdG",
    ruRU = "Скрыть кнопку поиска группы", koKR = "파티 찾기 버튼 숨기기", zhCN = "隐藏寻找队伍按钮", zhTW = "隱藏尋找隊伍按鈕",
}
local PANEL_TIP = {
    enUS = "The eye button next to Show Location on dungeon pages, which opens Looking For Group on that dungeon.",
    deDE = "Der Augen-Button neben „Ort anzeigen“ auf Dungeonseiten, der die Gruppensuche für diesen Dungeon öffnet.",
}

function FDJ.IsLFGButtonHidden()
    return ForeverDungeonJournalDB and ForeverDungeonJournalDB.hideLFGButton == true or false
end

function FDJ.SetLFGButtonHidden(hidden)
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    ForeverDungeonJournalDB.hideLFGButton = hidden and true or nil
    local frame = _G.ForeverDungeonJournalFrame
    local b = frame and frame.lfgButton
    if b then
        if hidden then b:Hide() elseif b.fdjDungeon then b:Show() end
        -- Without the eye the Route button moves next to Show Location.
        if frame.dungeonRouteButton then
            frame.dungeonRouteButton:ClearAllPoints()
            frame.dungeonRouteButton:SetPoint("LEFT", hidden and frame.dungeonLocationButton or b, "RIGHT", 3, 0)
        end
    end
    if FDJ.lfgMenu then FDJ.lfgMenu:Hide() end
    -- Keep the Options checkbox in step when this was changed by right-click.
    local settings = _G.ForeverDungeonJournalSettings
    if settings and settings:IsShown() then
        local onShow = settings:GetScript("OnShow")
        if onShow then pcall(onShow, settings) end
    end
end

function FDJ.LFGToggleLabel()
    local lang = Lang()
    local t = FDJ.IsLFGButtonHidden() and SHOW_PANEL or HIDE_PANEL
    return t[lang] or t.enUS
end

function FDJ.LFGToggleTip()
    return PANEL_TIP[Lang()] or PANEL_TIP.enUS
end

-- Small right-click menu with a single "Disable" entry.
-- ------------------------------------------------------- quick listing
-- Lists you straight away for this dungeon (C_LFGList.CreateListing, the
-- same call the window's "List Self" button makes), with the roles you last
-- picked in the Looking For Group window. Run from a real click on the menu.
local LIST_ME = {
    enUS = "List me for this dungeon", deDE = "Mich für diesen Dungeon eintragen",
    frFR = "M'inscrire pour ce donjon", esES = "Apuntarme para esta mazmorra",
    itIT = "Iscrivimi per questa spedizione", ptBR = "Me listar para esta masmorra",
    ruRU = "Записаться в это подземелье", koKR = "이 던전에 등록하기",
    zhCN = "为此地下城登记", zhTW = "為此地城登記",
}
local MSG = {
    listed = "listed for %s.",
    updated = "listing changed to %s.",
    noRoles = "pick your role(s) in the Looking For Group window once, then try again.",
    noActivity = "this dungeon isn't in the Looking For Group list.",
    blocked = "the game doesn't allow addons to list you. Use the Looking For Group window instead.",
    failed = "couldn't list you (%s).",
}
local function Say(text) print("|cffffd200Dungeon Journal:|r " .. text) end

local pendingList
local listWatch = CreateFrame("Frame")
listWatch:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
listWatch:RegisterEvent("ADDON_ACTION_BLOCKED")
listWatch:RegisterEvent("ADDON_ACTION_FORBIDDEN")
listWatch:SetScript("OnEvent", function(_, event, addon)
    if not pendingList then return end
    if event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
        Say(string.format(pendingList.update and MSG.updated or MSG.listed, pendingList.name))
        pendingList = nil
    elseif addon == "ForeverDungeonJournal" then
        Say(MSG.blocked)
        pendingList = nil
    end
end)

function FDJ.ListForDungeon(dungeonName)
    if not dungeonName then return end
    local id = FindActivity(dungeonName)
    if not id then Say(MSG.noActivity) return end
    if C_LFGListRoles and C_LFGListRoles.GetRoles then
        local ok, roles = pcall(C_LFGListRoles.GetRoles)
        if ok and type(roles) == "table" and not (roles.tank or roles.healer or roles.dps) then
            Say(MSG.noRoles)
            return
        end
    end
    if not (C_LFGList and C_LFGList.CreateListing) then Say(MSG.blocked) return end
    local name = (FDJ.LocalizeDungeonName and FDJ.LocalizeDungeonName(dungeonName)) or dungeonName
    local update = C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo() or false
    pendingList = { name = name, update = update }
    local ok, err = pcall(function()
        if update then
            C_LFGList.UpdateListing({ activityIDs = { id }, newPlayerFriendly = false })
        else
            C_LFGList.CreateListing({ activityIDs = { id }, newPlayerFriendly = false })
        end
    end)
    if ForeverDungeonJournalDB then
        ForeverDungeonJournalDB.lfgList = { dungeon = dungeonName, activity = id, ok = ok, err = not ok and tostring(err) or nil, update = update }
    end
    if not ok then
        pendingList = nil
        Say(string.format(MSG.failed, tostring(err)))
    end
end

-- Small right-click menu: "List me for this dungeon" and "Disable".
function FDJ.ShowLFGMenu(anchor)
    local m = FDJ.lfgMenu
    if not m then
        m = CreateFrame("Frame", "ForeverDungeonJournalLFGMenu", UIParent, "BackdropTemplate")
        FDJ.lfgMenu = m
        m:SetFrameStrata("FULLSCREEN_DIALOG")
        m:EnableMouse(true)
        m:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        m:SetBackdropColor(0.055, 0.05, 0.043, 0.98)
        m:SetBackdropBorderColor(0.57, 0.43, 0.20, 1)
        local function Item(index, onClick)
            local item = CreateFrame("Button", nil, m)
            item:SetPoint("TOPLEFT", 5, -5 - (index - 1) * 20)
            item:SetPoint("RIGHT", -5, 0)
            item:SetHeight(20)
            item:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            item.text = item:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
            item.text:SetPoint("LEFT", 6, 0)
            item:SetScript("OnClick", function()
                m:Hide()
                onClick()
            end)
            return item
        end
        -- (A "List me for this dungeon" entry was tried: the game does not
        -- let addons create listings, so it was removed.)
        -- 2.0.4: Disable opens Options at its line (highlighted); the player
        -- ticks it there, so they know where to undo it.
        m.disable = Item(1, function()
            if FDJ.OpenSettingsAt then FDJ.OpenSettingsAt("OPT_HIDE_LFG") else FDJ.SetLFGButtonHidden(true) end
        end)
        -- Closes on its own once the mouse has been away for a moment.
        m:SetScript("OnUpdate", function(self, elapsed)
            if self:IsMouseOver() or (self.fdjAnchor and self.fdjAnchor:IsMouseOver()) then
                self.fdjAway = 0
            else
                self.fdjAway = (self.fdjAway or 0) + elapsed
                if self.fdjAway > 0.6 then self:Hide() end
            end
        end)
    end
    local lang = Lang()
    m.disable.text:SetText(DISABLE[lang] or DISABLE.enUS)
    m:SetSize(math.max(110, (m.disable.text:GetStringWidth() or 0) + 24), 30)
    m.fdjAnchor = anchor
    m.fdjAway = 0
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, -2)
    m:Show()
    if GameTooltip then GameTooltip:Hide() end
end

-- ---------------------------------------------------------------- button
function FDJ.CreateLFGButton(frame, header, anchor)
    local b = CreateFrame("Button", nil, header)
    frame.lfgButton = b
    b:SetSize(38, 38)
    b:SetPoint("LEFT", anchor, "RIGHT", 2, 0)
    b:SetFrameLevel(header:GetFrameLevel() + 4)
    -- Soft golden glow behind the eye, like the Show Location icon has.
    b.glow = b:CreateTexture(nil, "BACKGROUND")
    b.glow:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\TickGlow")
    b.glow:SetBlendMode("ADD")
    b.glow:SetVertexColor(1, 0.82, 0.35)
    b.glow:SetAlpha(0.75)
    b.glow:SetSize(52, 52)
    b.glow:SetPoint("CENTER")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    local hasEye = true
    if GetFileIDFromPath then
        local ok, id = pcall(GetFileIDFromPath, EYE)
        hasEye = ok and id ~= nil
    end
    if hasEye then
        b.icon:SetTexture(EYE)
        b.icon:SetTexCoord(0, 0.125, 0, 0.25)
    else
        b.icon:SetTexture("Interface\\Icons\\INV_Misc_Eye_01")
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local hl = b:GetHighlightTexture()
    if hl then hl:ClearAllPoints(); hl:SetPoint("TOPLEFT", 5, -5); hl:SetPoint("BOTTOMRIGHT", -5, 5) end

    -- Static icon: the same picture as the game's Group Finder menu button.
    pcall(function()
        local micro = _G.LFDMicroButton or _G.LFGMicroButton
        local nt = micro and micro.GetNormalTexture and micro:GetNormalTexture()
        if not nt then return end
        local atlas = nt.GetAtlas and nt:GetAtlas()
        -- Drawn larger than the button (the menu art has empty space around
        -- the eye), keeping the menu button's proportions.
        local mw, mh = nt:GetSize()
        local w = 42
        local h = (mw and mw > 0 and mh and mh > 0) and (w * mh / mw) or w
        b.icon:ClearAllPoints()
        b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.icon:SetSize(w, h)
        if atlas and atlas ~= "" then
            b.icon:SetTexCoord(0, 1, 0, 1)
            b.icon:SetAtlas(atlas)
        elseif nt:GetTexture() then
            b.icon:SetTexture(nt:GetTexture())
            b.icon:SetTexCoord(nt:GetTexCoord())
        end
    end)

    -- Preferred look: the eye portrait from the Looking For Group window
    -- itself (round green eye), with a thin gold ring. Copied from the
    -- game's frame once it has one; until then the menu-button eye stays.
    FDJ.ApplyLFGPortrait(b)
    b:HookScript("OnShow", function(self) FDJ.ApplyLFGPortrait(self) end)
    if LFGParentFrame and LFGParentFrame.HookScript then
        LFGParentFrame:HookScript("OnShow", function() FDJ.ApplyLFGPortrait(b) end)
    end

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local lang = Lang()
        GameTooltip:SetText(TITLE[lang] or TITLE.enUS, 1, 0.82, 0)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(self, button)
        if button == "RightButton" then FDJ.ShowLFGMenu(self) return end
        -- Normally the secure overlay on top takes the click. The eye itself
        -- only gets it in combat (overlay hidden) or without a micro button.
        if self.fdjOverlay then
            if UIErrorsFrame then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT or "Can't do that while in combat", 1, 0.1, 0.1) end
            return
        end
        if self.fdjDungeon then OpenFor(self.fdjDungeon) end
    end)
    FDJ.CreateLFGOverlay(b)
    return b
end

function FDJ.UpdateLFGButton(frame, dungeonName, dungeon)
    local b = frame and frame.lfgButton
    if not b then return end
    local valid = dungeon and not dungeon.recipeSearch and not dungeon.fdjItemCount and not dungeon.previewOnly
        and not dungeon.questChainPage
    b.fdjDungeon = valid and dungeonName or nil
    local show = valid and not FDJ.IsLFGButtonHidden()
    b:SetShown(show and true or false)
    if frame.dungeonRouteButton then
        frame.dungeonRouteButton:ClearAllPoints()
        frame.dungeonRouteButton:SetPoint("LEFT", show and b or frame.dungeonLocationButton, "RIGHT", 3, 0)
    end
end

-- /dj lfgdebug: records what the Looking For Group window offers on this
-- client into the saved variables (ForeverDungeonJournalDB.lfgDebug), so the
-- dungeon pre-selection can be matched to it.
local function Describe(obj, depth)
    local out = {}
    if type(obj) ~= "table" then return out end
    for k, v in pairs(obj) do
        if type(k) == "string" and k ~= "__index" then
            local t = type(v)
            local line = k .. "=" .. t
            if t == "table" and depth > 0 then
                local sub = {}
                for k2, v2 in pairs(v) do
                    if type(k2) == "string" then sub[#sub + 1] = k2 .. ":" .. type(v2) end
                    if #sub > 60 then break end
                end
                table.sort(sub)
                line = line .. " {" .. table.concat(sub, " ") .. "}"
            elseif t == "string" or t == "number" or t == "boolean" then
                line = line .. " " .. tostring(v)
            end
            out[#out + 1] = line
        end
    end
    table.sort(out)
    return out
end

local function FrameInfo(f)
    if type(f) ~= "table" or not f.GetObjectType then return nil end
    local info = {}
    pcall(function()
        info.type = f:GetObjectType()
        info.shown = f:IsShown()
        info.strata = f:GetFrameStrata()
        info.protected = f.IsProtected and f:IsProtected() or false
        info.fields = Describe(f, 1)
        local kids = {}
        for _, child in ipairs({ f:GetChildren() }) do
            local name = child.GetName and child:GetName() or "?"
            kids[#kids + 1] = tostring(name) .. ":" .. child:GetObjectType() .. (child:IsShown() and "" or "(hidden)")
        end
        info.children = kids
        if f.GetAttribute then
            info.layout = {}
            for _, a in ipairs({ "UIPanelLayout-defined", "UIPanelLayout-enabled", "UIPanelLayout-area", "UIPanelLayout-pushable" }) do
                info.layout[a] = tostring(f:GetAttribute(a))
            end
        end
    end)
    return info
end

function FDJ.LFGDebug()
    local dump = { time = date and date() or "" }
    local globals = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and (k:find("LFG") or k:find("MicroButton") or k:find("GroupFinder") or k:find("LookingFor")) then
            globals[#globals + 1] = k .. "=" .. type(v)
        end
    end
    table.sort(globals)
    dump.globals = globals
    dump.parent = FrameInfo(_G.LFGParentFrame)
    dump.browse = FrameInfo(_G.LFGBrowseFrame)
    dump.listing = FrameInfo(_G.LFGListingFrame)
    local api = {}
    if C_LFGList then for k in pairs(C_LFGList) do api[#api + 1] = k end end
    table.sort(api)
    dump.api = api
    local binds = {}
    if GetNumBindings and GetBinding then
        for i = 1, GetNumBindings() do
            local ok, cmd = pcall(GetBinding, i)
            if ok and type(cmd) == "string" and (cmd:find("LFG") or cmd:find("GROUP") or cmd:find("PVE")) then
                binds[#binds + 1] = cmd
            end
        end
    end
    dump.bindings = binds
    local acts = {}
    if C_LFGList and C_LFGList.GetAvailableActivities then
        local ok, ids = pcall(C_LFGList.GetAvailableActivities)
        if ok and type(ids) == "table" then
            for _, id in ipairs(ids) do
                local ok2, info = pcall(C_LFGList.GetActivityInfoTable, id)
                if ok2 and info then acts[#acts + 1] = id .. ":" .. tostring(info.fullName) .. ":cat" .. tostring(info.categoryID) end
            end
        end
    end
    dump.activities = acts
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    ForeverDungeonJournalDB.lfgDebug = dump
    FDJ.ShowCopyBox(FDJ.SerializeDebug(dump))
end

-- Turns the debug table into plain text.
function FDJ.SerializeDebug(t, indent)
    indent = indent or ""
    local lines = {}
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
        local v = t[k]
        if type(v) == "table" then
            lines[#lines + 1] = indent .. tostring(k) .. ":"
            lines[#lines + 1] = FDJ.SerializeDebug(v, indent .. "  ")
        else
            lines[#lines + 1] = indent .. tostring(k) .. " = " .. tostring(v)
        end
    end
    return table.concat(lines, "\n")
end

-- A popup with a text box: the text is selected, so Ctrl+C copies it all.
function FDJ.ShowCopyBox(text)
    local box = FDJ.copyBox
    if not box then
        box = CreateFrame("Frame", "ForeverDungeonJournalCopyBox", UIParent, "BackdropTemplate")
        FDJ.copyBox = box
        box:SetSize(560, 400)
        box:SetPoint("CENTER")
        box:SetFrameStrata("FULLSCREEN_DIALOG")
        box:EnableMouse(true)
        box:SetMovable(true)
        box:RegisterForDrag("LeftButton")
        box:SetScript("OnDragStart", box.StartMoving)
        box:SetScript("OnDragStop", box.StopMovingOrSizing)
        box:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        box:SetBackdropColor(0.06, 0.05, 0.04, 0.97)
        box:SetBackdropBorderColor(0.62, 0.50, 0.30, 1)
        local title = box:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
        title:SetPoint("TOPLEFT", 14, -12)
        title:SetText("Dungeon Journal debug: press Ctrl+C to copy, then paste it to the author")
        local close = CreateFrame("Button", nil, box, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
        local scroll = CreateFrame("ScrollFrame", "ForeverDungeonJournalCopyScroll", box, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -34)
        scroll:SetPoint("BOTTOMRIGHT", -32, 12)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(true)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(500)
        edit:SetScript("OnEscapePressed", function() box:Hide() end)
        edit:SetScript("OnTextChanged", function(self, user)
            -- Read-only: typing puts the original text back.
            if user then self:SetText(box.fdjText or ""); self:HighlightText() end
        end)
        scroll:SetScrollChild(edit)
        box.edit = edit
        tinsert(UISpecialFrames, "ForeverDungeonJournalCopyBox")
    end
    box.fdjText = text
    box.edit:SetText(text)
    box:Show()
    box.edit:SetFocus()
    box.edit:HighlightText()
end
