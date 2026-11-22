local _, ns = ...

local MapTab = {}
ns.MapTab = MapTab

local Utils = ns.Utils
local L = ns.L
local MapUtils = ns.MapUtils
local ResultHandlers = ns.ResultHandlers
local SafeAfter = Utils.SafeAfter
local tinsert = Utils.tinsert
local tremove = Utils.tremove
local mmin, mmax = Utils.mmin, Utils.mmax

local GOLD_COLOR = ns.GOLD_COLOR

local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local GameTooltip_Hide = GameTooltip_Hide
local IsAltKeyDown = IsAltKeyDown
local GetMapInfo = C_Map and C_Map.GetMapInfo

local TAB_W, TAB_H       = 43, 55



local FOREVER_TABS = ns.Caps and ns.Caps.forever
local SIDE_TAB = FOREVER_TABS and "QuestLog-tab-side" or "common-sidetab"
local SIDE_TAB_SELECT = FOREVER_TABS and "QuestLog-Tab-side-Glow-Select" or "common-sidetab-selected"
local SIDE_TAB_HOVER = FOREVER_TABS and "QuestLog-Tab-side-Glow-hover" or "common-sidetab-hover"
local SIDE_TAB_ICON_X = FOREVER_TABS and 0 or -2
local TAB_ICON_SIZE      = 20
local TAB_ICON_GOLD      = {1.00, 0.82, 0.00}
local TAB_ICON_DIM       = {0.55, 0.45, 0.10}
local TAB_STACK_GAP      = -3

local GetAncestorNames = MapUtils.GetAncestorNames
local ExpandZoneAbbrev = MapUtils.ExpandZoneAbbrev


local FONT_SIZES = { { "OPT_FONT_SMALL", 0.85 }, { "OPT_FONT_MED", 1 }, { "OPT_FONT_LARGE", 1.15 }, { "OPT_FONT_XL", 1.3 } }
local function FontScale() return EasyFind.db and EasyFind.db.mapTabFontSize or 1 end
local function Scaled(h) return math.floor(h * FontScale() + 0.5) end
local function ScaleFont(fs, template, scale)
    local file, size, flags = _G[template]:GetFont()
    if file then fs:SetFont(file, size * scale, flags) end
end
local ROW_POOL_RETAIN  = 80

local COVER_LEVEL = 110
local function SwallowWheel() end
local HEADER_POOL_RETAIN = 40
local SECTION_POOL_RETAIN = 12


local SEARCH_SCRATCH = {
    tokens = {},
    seen = {},
    seenKeys = {},
    candidates = {},
    multiTokenCandidates = {},
    versionByName = {},
    candidateNames = {},
}

local initialized = false
local tabFrame
local backTab

local RefreshCurrentSearch
local ReleaseMapTabMemory

local function MapShownForSweep()
    return WorldMapFrame and WorldMapFrame:IsShown() or false
end

local function TrimAfterMapSearch()
    if ns.MapSearch and ns.MapSearch.TrimSearchMemory then
        ns.MapSearch:TrimSearchMemory()
    end
end
local panel


local SidePanel = {}

local function Host() return SidePanel.frame or _G["QuestMapFrame"] end
local selectedIsOurs = false
local lastSelectedWasOurs = false


local activePage
local pages = {}
local pageOrder = {}
local extraTabs = {}
local PlaceTab
local function IsMapSearchEnabled()
    return not (EasyFind and EasyFind.db and EasyFind.db.enableMapSearch == false)
end
function MapTab:IsEnabled()
    return IsMapSearchEnabled()
end



local function CoverClientPanel(qmf, covered)
    for _, content in ipairs(qmf.ContentFrames) do content:SetAlpha(covered and 0 or 1) end
    for _, tab in ipairs(qmf.TabButtons or {}) do
        if tab.SetChecked then tab:SetChecked(not covered and tab.displayMode == qmf.displayMode) end
    end
end
local lastQueryGen = 0
local pendingSearchTimer
local pendingSearchFrame
local pendingSearchText
local pendingSearchGrew
local pendingSearchEditBox
local CancelPendingSearch
local function RunPendingSearchNow()
    if not pendingSearchTimer then return false end
    local box = pendingSearchEditBox
    local text = pendingSearchText or ""
    local shouldAutocomplete = pendingSearchGrew
    CancelPendingSearch()
    MapTab:RunSearch(text)
    if shouldAutocomplete and box and box.UpdateAutocomplete then
        box:UpdateAutocomplete()
    end
    return true
end
CancelPendingSearch = function()
    if pendingSearchFrame then pendingSearchFrame:Hide() end
    pendingSearchTimer = nil
    pendingSearchText = nil
    pendingSearchGrew = nil
    pendingSearchEditBox = nil
end
local function SchedulePendingSearch(editBox, typed, grew)
    if not pendingSearchFrame then
        pendingSearchFrame = CreateFrame("Frame")
        pendingSearchFrame:Hide()
        Utils.SafeOnUpdate(pendingSearchFrame, function(self)
            self:Hide()
            local box = pendingSearchEditBox
            local text = pendingSearchText or ""
            local shouldAutocomplete = pendingSearchGrew
            pendingSearchTimer = nil
            pendingSearchText = nil
            pendingSearchGrew = nil
            pendingSearchEditBox = nil
            MapTab:RunSearch(text)
            if shouldAutocomplete and box and box.UpdateAutocomplete then
                box:UpdateAutocomplete()
            end
        end)
    end
    pendingSearchTimer = true
    pendingSearchText = typed
    pendingSearchGrew = grew
    pendingSearchEditBox = editBox
    pendingSearchFrame:Show()
end



local currentQuery = ""
local lastRenderedQuery
local navRowIndex = 0
local visibleNavRows = {}
local navFrame



local navKeyRepeat

local function FindAtlasTexture(frame, atlas)
    if not frame or not frame.GetRegions then return nil end
    for i = 1, frame:GetNumRegions() do
        local region = select(i, frame:GetRegions())
        if region and region.GetAtlas and region.GetObjectType and region:GetObjectType() == "Texture"
           and region:GetAtlas() == atlas then
            return region
        end
    end
    return nil
end

local function RefreshSelectGlows()
    local qmf = Host()
    if not qmf then return end
    local function setGlow(tab, shown)
        if not tab then return end
        local glow = tab._efSelectGlow or tab.SelectedTexture or FindAtlasTexture(tab, SIDE_TAB_SELECT)
        if glow then
            tab._efSelectGlow = glow
            glow:SetShown(shown)
        end
    end

    local searchSelected = selectedIsOurs and (activePage == nil or (pages[activePage] and pages[activePage].noTab) == true)
    if selectedIsOurs then
        setGlow(qmf.QuestsTab, false)
        setGlow(qmf.MapLegendTab, false)
        setGlow(qmf.EventsTab, false)
    end
    setGlow(tabFrame, searchSelected)
    if backTab then
        setGlow(backTab, not selectedIsOurs)
        if backTab._efIcon then backTab._efIcon:SetVertexColor(Utils.RGB(selectedIsOurs and TAB_ICON_DIM or TAB_ICON_GOLD)) end
    end
    if tabFrame and tabFrame._efIcon then
        local c = searchSelected and TAB_ICON_GOLD or TAB_ICON_DIM
        tabFrame._efIcon:SetVertexColor(Utils.RGB(c))
    end
    for id, tab in pairs(extraTabs) do
        local on = selectedIsOurs and activePage == id
        setGlow(tab, on)
        if tab._efIcon then tab._efIcon:SetVertexColor(Utils.RGB(on and TAB_ICON_GOLD or TAB_ICON_DIM)) end
    end
end



local SEARCH_WIDGETS = { "searchBox", "cog", "scrollFrame", "scrollBar", "emptyMsg", "recentCheck", "expandCheck" }



local function UpdatePageBar()
    if not (panel and panel.pageBar) then return end
    local bar = panel.pageBar
    local def, back
    if activePage == nil then
        for i = 1, #pageOrder do
            local d = pages[pageOrder[i]]
            if d and d.keepSearch and d.hasContent and d.hasContent() then def = d break end
        end
    elseif pages[activePage] and pages[activePage].keepSearch then

        back = true
    end
    local scrollFrame = panel.scrollFrame

    local label = bar._label
    if label then
        local file, _, flags = label:GetFont()
        if file then label:SetFont(file, Scaled(13), flags) end
    end
    if def then
        bar.pageID = def.id
        bar:SetText((def.barText and def.barText()) or def.title or def.id)
        bar:Show()
        if scrollFrame then
            scrollFrame:ClearAllPoints()
            scrollFrame:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -4)
            scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, panel.footH or 28)
        end
    elseif back then
        bar.pageID = false
        bar:SetText(L["MAP_RETURN_SEARCH"])
        bar:Show()
    else
        bar:Hide()
        if scrollFrame then
            scrollFrame:ClearAllPoints()
            scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
            scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, panel.footH or 28)
        end
    end
    if panel.emptyMsg then
        panel.emptyMsg:ClearAllPoints()
        panel.emptyMsg:SetPoint("TOPLEFT", scrollFrame or panel, "TOPLEFT", 20, -24)
        panel.emptyMsg:SetPoint("TOPRIGHT", scrollFrame or panel, "TOPRIGHT", -20, -24)
    end
end

local function SelectPage(id)
    if not panel then return end
    if id == false then id = nil elseif id == nil then id = activePage end
    if id and not pages[id] then id = nil end
    activePage = id


    for i = 1, #SEARCH_WIDGETS do
        local w = panel[SEARCH_WIDGETS[i]]
        if w then w:SetShown(id == nil) end
    end
    if panel.anchor then panel:SetPoint("TOPLEFT", panel.anchor, "TOPLEFT", 0, id and 0 or -29) end
    if id then ns.HideTogglePopup("EasyFindMapTabOptions") end
    UpdatePageBar()
    for pid, def in pairs(pages) do
        if pid == id then
            if not def.frame then
                local f = CreateFrame("Frame", nil, panel)
                f:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
                f:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)
                def.frame = f
                if def.build then def.build(f) end
            end

            if panel.pageBar and panel.pageBar:IsShown() then
                def.frame:SetPoint("TOPLEFT", panel.pageBar, "BOTTOMLEFT", 0, -4)
            else
                def.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
            end
            def.frame:Show()
            if def.onShow then def.onShow(def.frame) end
        elseif def.frame then
            def.frame:Hide()
        end
    end
end

local function ShowOurPanel(pageID)
    if not IsMapSearchEnabled() then return end
    local qmf = Host()
    if not qmf or not panel then return end
    if SidePanel.frame and not SidePanel.Expand() then return end
    selectedIsOurs = true
    lastSelectedWasOurs = true
    if panel.MeasureBlizzardSearch then panel.MeasureBlizzardSearch() end
    if qmf.ContentFrames then
        CoverClientPanel(qmf, true)
    else
        if qmf.QuestsFrame then qmf.QuestsFrame:Hide() end
        if qmf.EventsFrame then qmf.EventsFrame:Hide() end
        if qmf.MapLegend   then qmf.MapLegend:Hide()   end
    end




    if LibStub then
        local ok, lwmt = pcall(LibStub, "LibWorldMapTabs", true)
        if ok and lwmt and lwmt.SetDisplayMode then
            pcall(lwmt.SetDisplayMode, lwmt, nil)
        end
    end
    if panel.outer then panel.outer:Show() else panel:Show() end
    if panel.AlignToBlizzardSearch then panel.AlignToBlizzardSearch() end
    SelectPage(pageID)
    RefreshSelectGlows()
    if activePage == nil then
        local sb = panel.searchBox
        MapTab:RunSearch(sb and (sb.GetTypedText and sb:GetTypedText() or sb:GetText()) or "")
    end
end

local function HideOurPanel()
    if not selectedIsOurs then return end
    selectedIsOurs = false
    if panel then
        if panel.outer then panel.outer:Hide() else panel:Hide() end
        if panel.searchBox then panel.searchBox:ClearFocus() end
    end
    if SidePanel.frame then SidePanel.Collapse() end
    local qmf = Host()
    if qmf and qmf.ContentFrames then CoverClientPanel(qmf, false) end
    if ns.MapSearch and ns.MapSearch._previewing then
        if ns.MapSearch.EndHoverPreview then
            ns.MapSearch:EndHoverPreview()
        else
            ns.MapSearch._previewing = nil
            if ns.MapSearch.ClearHighlight then ns.MapSearch:ClearHighlight() end
        end
    end
    if ReleaseMapTabMemory then ReleaseMapTabMemory(true) end
    RefreshSelectGlows()
end

local function PromptAlias(data)
    if ResultHandlers and ResultHandlers.PromptForAlias then
        ResultHandlers:PromptForAlias(data)
    end
end


local function CopyBox(title, text)
    if not ns.ShowThemedDialog then return end
    ns.ShowThemedDialog({
        text = title,
        messageColor = ns.GOLD_COLOR,
        hasEditBox = true,
        editBoxDefault = text,
        acceptText = _G["OKAY"] or "OK",
        onAccept = function() end,
    })
end





local currentRelease
local function ShowGameMenu(row, isPinned, onPin, onGuide, onAddAlias, data, extra)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return false end
    local name = data and data.name
    if row and row.LockHighlight then row:LockHighlight() end
    local released = false
    local function Release()
        if released then return end
        released = true
        if row and row.UnlockHighlight then row:UnlockHighlight() end
    end
    local ok, menu = pcall(MenuUtil.CreateContextMenu, row or panel or UIParent, function(_, root)
        if name and name ~= "" then root:CreateTitle(name) end
        if extra.onGPS and extra.onGPSFrom then
            local gps = root:CreateButton(L["APP_GPS"])
            gps:CreateButton(L["CTX_GPS_TO"], extra.onGPS)
            gps:CreateButton(L["CTX_GPS_FROM"], extra.onGPSFrom)
        elseif extra.onGPS then
            root:CreateButton(L["CTX_GPS"], extra.onGPS)
        elseif extra.onGPSFrom then
            root:CreateButton(L["CTX_GPS_FROM"], extra.onGPSFrom)
        end
        if onGuide then root:CreateButton(L["CTX_GUIDE"], onGuide) end
        root:CreateButton(isPinned and (_G["RECENT_ALLIES_MENU_BUTTON_LABEL_UNPIN"] or "Unpin")
            or (_G["RECENT_ALLIES_MENU_BUTTON_LABEL_PIN"] or "Pin"), onPin)
        if onAddAlias then root:CreateButton(L["CTX_ADD_ALIAS"], onAddAlias) end
        if extra.sendLink and ns.BuildSendLinkRows then
            local rows = ns.BuildSendLinkRows(extra.sendLink.link)
            if rows then
                local sub = root:CreateButton(L["CTX_SEND_LINK"])
                for i = 1, #rows do
                    local r = rows[i]
                    if r.isSeparator then
                        sub:CreateDivider()
                    elseif r.copy then
                        sub:CreateButton(r.text, function() CopyBox(r.text, r.copy) end)
                    else
                        local b = sub:CreateButton(r.text, r.onClick or function() end)
                        if r.disabled and b.SetEnabled then b:SetEnabled(false) end
                    end
                end
            end
        end
        if extra.wowheadUrl then
            root:CreateButton(L["CTX_WOWHEAD"], function() CopyBox(L["CTX_WOWHEAD"], extra.wowheadUrl) end)
        end
        if root.AddMenuReleasedCallback then root:AddMenuReleasedCallback(Release) end
    end)
    if not ok then
        Release()
        return false
    end


    currentRelease = Release
    if menu and menu.HookScript and not menu._efReleaseHooked then
        menu._efReleaseHooked = true
        menu:HookScript("OnHide", function() if currentRelease then currentRelease() end end)
    end
    return true
end

local function ShowPopup(isPinned, onPin, onGuide, onAddAlias, data, row)
    local extra
    local wowheadUrl = data and ns.GetWowheadLink and ns.GetWowheadLink(data)
    if wowheadUrl then
        extra = { wowheadUrl = wowheadUrl }
    end



    local mapPinLink = data and ns.GetMapPinLink and ns.GetMapPinLink(data)
    if mapPinLink then
        extra = extra or {}
        extra.sendLink = { link = mapPinLink }
    end
    if data and EasyFind.API.CallAction("gps", "canNavigate", data) then
        extra = extra or {}
        extra.onGPS = function() EasyFind.API.CallAction("gps", "navigate", data) end
        extra.onGPSFrom = function() EasyFind.API.CallAction("gps", "setStart", data) end
    end
    if ShowGameMenu(row, isPinned, onPin, onGuide, onAddAlias, data, extra or {}) then return end
    Utils.ShowPinMenu("EasyFindPinPopup", isPinned, onPin, onGuide, onAddAlias, {
        strata = "TOOLTIP",
        level = 100,
        width = 96,
        rowHeight = 22,
    }, extra)
end




local lastTypeTime = 0
local HOVER_PREVIEW_TYPING_GUARD = 0.3




local function HoverPreview(data, fromKeyboard)
    if not fromKeyboard and GetTime() - lastTypeTime < HOVER_PREVIEW_TYPING_GUARD then return end
    local MapSearch = ns.MapSearch
    if MapSearch and MapSearch.RunHoverPreview then
        MapSearch:RunHoverPreview(data)
    end
end

local function ClearHoverPreview()
    local MapSearch = ns.MapSearch
    if MapSearch and MapSearch.EndHoverPreview then
        MapSearch:EndHoverPreview()
    end
end

RefreshCurrentSearch = function()
    if not panel or not panel.searchBox then return end
    local sb = panel.searchBox
    MapTab:RunSearch(sb.GetTypedText and sb:GetTypedText() or sb:GetText() or "")
end




local function TriggerResultSelect(data, directOverride)
    local MapSearch = ns.MapSearch
    if MapSearch and MapSearch.SelectResult then MapSearch:SelectResult(data, directOverride) end



end

local function RowOnClick(row, button)
    local data = row.data
    if not data then return end
    local MapSearch = ns.MapSearch

    if data.isRecentSearch then
        if data.query and panel and panel.searchBox then
            panel.searchBox:SetText(data.query)
            panel.searchBox:ClearFocus()
        end
        return
    end

    if button == "RightButton" then
        local isPinned = MapSearch and MapSearch:IsMapItemPinned(data)
        ShowPopup(isPinned, function()
            if isPinned then MapSearch:UnpinMapItem(data) else MapSearch:PinMapItem(data) end
            RefreshCurrentSearch()
        end, MapSearch.GuideAllowed(data) and function() TriggerResultSelect(data, false) end or nil,
        function() PromptAlias(data) end, data, row)
        return
    end

    MapTab:PushRecentSearch(currentQuery)
    TriggerResultSelect(data)
end




local function HeaderRightClick(navigateData, capturedCollapsed)
    if not navigateData then return end
    local MapSearch = ns.MapSearch
    if not MapSearch then return end
    local isPinned = MapSearch:IsMapItemPinned(navigateData)
    ShowPopup(isPinned, function()
        if isPinned then
            MapSearch:UnpinMapItem(navigateData)
        else
            navigateData.collapsed = capturedCollapsed or nil
            MapSearch:PinMapItem(navigateData)
            navigateData.collapsed = nil
        end
        RefreshCurrentSearch()
    end, MapSearch.GuideAllowed(navigateData) and function() TriggerResultSelect(navigateData, false) end or nil,
    function() PromptAlias(navigateData) end, navigateData)
end

local mapList
local function MapList()
    if mapList then return mapList end
    mapList = ns.PlaceList.New(panel.scrollChild, {
        click = RowOnClick,
        headerClick = function(data) TriggerResultSelect(data) end,
        headerMenu = HeaderRightClick,
        refresh = function() RefreshCurrentSearch() end,
        searchBox = function() return panel and panel.searchBox end,
        fontScale = FontScale,
        preview = function(data) HoverPreview(data) end,
        endPreview = ClearHoverPreview,
        deleteRecent = function(query) MapTab:ForgetRecentSearch(query) end,
        autoExpand = function() return EasyFind.db.mapTabAutoExpand ~= false end,


        beforeRender = function(hasContent)
            if hasContent and panel and panel.emptyMsg then panel.emptyMsg:Hide() end
            navRowIndex = 0
            if navFrame then Utils.SafeCallMethod(navFrame, "EnableKeyboard", false) end
            if navKeyRepeat then navKeyRepeat.Stop() end
        end,
        routeButton = true,
    })
    visibleNavRows = mapList.navRows
    return mapList
end

ReleaseMapTabMemory = function(trimFrames)
    if pendingSearchTimer then CancelPendingSearch() end
    if mapList then
        if trimFrames then
            mapList:Trim(ROW_POOL_RETAIN, HEADER_POOL_RETAIN, SECTION_POOL_RETAIN)
        else
            mapList:Clear()
        end
    end
    if panel and panel.scrollChild then panel.scrollChild:SetHeight(1) end
    if panel and panel.emptyMsg then panel.emptyMsg:Hide() end
    if panel then
        panel.topResultName = nil
        panel.topResultCandidates = nil
    end
    navRowIndex = 0
    if visibleNavRows then wipe(visibleNavRows) end
    if navFrame then Utils.SafeCallMethod(navFrame, "EnableKeyboard", false) end
    if navKeyRepeat then navKeyRepeat.Stop() end
    if ns.MapSearch and ns.MapSearch.ReleaseIdleSearchMemory then
        ns.MapSearch:ReleaseIdleSearchMemory()
    end
end



local function BuildPinnedSection()
    local pins = EasyFind.db.pinnedMapItems
    if not pins or #pins == 0 then return nil end
    return pins
end




local EXCLUDE_FROM_LOCAL_MAPTYPES = {}
if Enum and Enum.UIMapType then
    EXCLUDE_FROM_LOCAL_MAPTYPES[Enum.UIMapType.Cosmic] = true
    EXCLUDE_FROM_LOCAL_MAPTYPES[Enum.UIMapType.World] = true
    EXCLUDE_FROM_LOCAL_MAPTYPES[Enum.UIMapType.Continent] = true
end

local function ResultDedupeKey(r)
    if not r then return "" end
    local name = r.name or ""
    if r.category == "flightmaster" then
        return "fm:" .. name
    end
    if r.isDungeonEntrance then
        return "instance:" .. tostring(r.entranceMapID or r.mapID or r.coordMapID or 0)
            .. ":" .. name
    end
    if r.isZone and r.zoneMapID then
        return "zone:" .. tostring(r.zoneMapID)
    end
    local mapID = r.mapID or r.coordMapID or r.entranceMapID
        or r.zoneMapID or r.parentMapID or 0
    local x = r.x or r.entranceX or 0
    local y = r.y or r.entranceY or 0
    return tostring(r.category or "location") .. ":" .. tostring(mapID)
        .. ":" .. name .. ":" .. tostring(x) .. ":" .. tostring(y)
end

local function IsMapTabAliasData(data)
    return data and (data.mapSearchResult or data.isZone or data.isDungeonEntrance
        or data.zoneMapID or data.entranceMapID
        or (data.category and (data.x or data.entranceX or data.mapID or data.coordMapID)))
end

local function ResultIsOnViewedMap(data, viewedMapID)
    if not data or not viewedMapID then return false end
    return data.mapID == viewedMapID
        or data.coordMapID == viewedMapID
        or data.entranceMapID == viewedMapID
        or data.zoneMapID == viewedMapID
        or data.parentMapID == viewedMapID
end



local function FilterAndDedupe(results, seen, isLocal)
    local filters = EasyFind.db.mapTabFilters or {}


    local viewedMapID = isLocal and WorldMapFrame and WorldMapFrame.GetMapID
        and WorldMapFrame:GetMapID() or nil
    local out = {}
    if not results then return out end
    for i = 1, #results do
        local r = results[i]
        if r and not r.isPinHeader then





            local zoneType = r.zoneMapType
            if isLocal and r.isZone and zoneType == nil and r.zoneMapID and GetMapInfo then
                local info = GetMapInfo(r.zoneMapID)
                zoneType = info and info.mapType
            end
            local excludeLocal = isLocal and r.isZone and zoneType
                and EXCLUDE_FROM_LOCAL_MAPTYPES[zoneType]
                and r.zoneMapID ~= viewedMapID
            if not excludeLocal then



                local key = ResultDedupeKey(r)
                if not seen[key] then
                    seen[key] = true
                    if ns.MapSearch.PassesFilter(r, filters) then
                        out[#out + 1] = r
                    end
                end
            end
        end
    end
    return out
end




local function POIMatchesToken(poi, t)
    if poi.name and poi.name:lower():find(t, 1, true) then return true end
    if poi.keywords then
        for i = 1, #poi.keywords do
            if poi.keywords[i]:lower():find(t, 1, true) then return true end
        end
    end
    if poi.category then
        local c = poi.category:lower()
        if c == t or c == t .. "s" then return true end
        if #t > 1 and t:sub(-1) == "s" and c == t:sub(1, -2) then return true end
    end
    if poi.pathPrefix and poi.pathPrefix:lower():find(t, 1, true) then return true end
    local mapID = poi.mapID or poi.zoneMapID or poi.entranceMapID
    local names = GetAncestorNames(mapID)
    for i = 1, #names do
        if names[i]:find(t, 1, true) then return true end
    end
    local expanded = ExpandZoneAbbrev(t)
    if expanded then
        if poi.name and poi.name:lower():find(expanded, 1, true) then return true end
        for i = 1, #names do
            if names[i]:find(expanded, 1, true) then return true end
        end
    end
    return false
end




local function BuildMultiTokenResults(tokens, isGlobal)
    local MapSearch = ns.MapSearch
    if not MapSearch or not MapSearch.BuildResults then return {} end
    local seenKeys = SEARCH_SCRATCH.seenKeys
    local candidates = SEARCH_SCRATCH.multiTokenCandidates
    wipe(seenKeys)
    wipe(candidates)
    for _, tok in ipairs(tokens) do
        local perRef = MapSearch:BuildResults(tok, isGlobal, true)
        for i = 1, #perRef do
            local r = perRef[i]
            local k = (r.mapID or 0) .. ":" .. (r.name or "")
                   .. ":" .. (r.x or 0) .. ":" .. (r.y or 0)
                   .. ":" .. (r.category or "")
            if not seenKeys[k] then
                seenKeys[k] = true
                candidates[#candidates + 1] = r
            end
        end
    end
    local tokensLower = {}
    for i, tok in ipairs(tokens) do tokensLower[i] = tok:lower() end
    local out = {}
    for _, r in ipairs(candidates) do
        local matches = true
        for i = 1, #tokensLower do
            if not POIMatchesToken(r, tokensLower[i]) then
                matches = false
                break
            end
        end
        if matches then out[#out + 1] = r end
    end
    return out
end

function MapTab:RunSearch(text)
    if not panel then return end
    text = text or ""
    if activePage and pages[activePage] and pages[activePage].keepSearch and text ~= currentQuery then
        SelectPage(false)
        RefreshSelectGlows()
    end
    currentQuery = text
    lastQueryGen = lastQueryGen + 1
    local myGen = lastQueryGen
    local scrollChild = panel.scrollChild
    local scrollFrame = panel.scrollFrame
    local MapSearch = ns.MapSearch
    local pinned = BuildPinnedSection()
    local aliasMatches
    if ns.Aliases and text ~= "" then
        aliasMatches = ns.Aliases:GetMatches(text:lower())
    end



    local preserveScroll = scrollFrame and text == lastRenderedQuery
    local savedScroll = preserveScroll and scrollFrame:GetVerticalScroll() or 0
    lastRenderedQuery = text
    local function restoreScroll()
        if not scrollFrame then return end
        local maxScroll = mmax(0, (scrollChild:GetHeight() or 0) - (scrollFrame:GetHeight() or 0))
        scrollFrame:SetVerticalScroll(mmin(savedScroll, maxScroll))
    end



    local list = MapList()
    list:Begin(text)

    if #text < 2 and not aliasMatches then
        local showRecent = EasyFind.db.mapTabShowRecent
        local recentList = showRecent and EasyFind.db.mapTabRecentSearches
        local limit = MapTab.GetRecentLimit and MapTab.GetRecentLimit() or 3
        if recentList and #recentList > limit then
            local trimmed = {}
            for i = 1, limit do trimmed[i] = recentList[i] end
            recentList = trimmed
        end
        local hasRecent = recentList and #recentList > 0
        if pinned or hasRecent then
            list:Render({ query = text, pinned = pinned, recent = hasRecent and recentList or nil })
        else
            list:Clear()
            scrollChild:SetHeight(1)
        end
        panel.emptyMsg:Hide()
        panel.topResultName = nil
        panel.topResultCandidates = nil
        restoreScroll()
        return
    end
    panel.emptyMsg:Hide()
    if not MapSearch or not MapSearch.BuildResults then
        list:Clear(); return
    end



    local tokens = SEARCH_SCRATCH.tokens
    wipe(tokens)
    for tok in text:gmatch("%S+") do tokens[#tokens + 1] = tok end
    local multiToken = #tokens > 1



    local seen = SEARCH_SCRATCH.seen
    wipe(seen)
    local localRaw
    if multiToken then
        localRaw = BuildMultiTokenResults(tokens, false)
    else
        local localRawRef = MapSearch:BuildResults(text, false, true)
        localRaw = {}
        for i = 1, #localRawRef do localRaw[i] = localRawRef[i] end
    end
    if myGen ~= lastQueryGen then return end

    local localFiltered = FilterAndDedupe(localRaw, seen, true)
    local localEntries
    local globalRaw
    if multiToken then
        globalRaw = BuildMultiTokenResults(tokens, true)
    else
        globalRaw = MapSearch:BuildResults(text, true, true)
    end
    if myGen ~= lastQueryGen then return end
    local globalFiltered = FilterAndDedupe(globalRaw, seen, false)

    if aliasMatches then
        local viewedMapID = WorldMapFrame and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
        for i = #aliasMatches, 1, -1 do
            local data = aliasMatches[i] and aliasMatches[i].data
            if IsMapTabAliasData(data) then
                local key = ResultDedupeKey(data)
                if not seen[key] then
                    seen[key] = true
                    if ResultIsOnViewedMap(data, viewedMapID) then
                        tinsert(localFiltered, 1, data)
                    else
                        tinsert(globalFiltered, 1, data)
                    end
                end
            end
        end
    end






    local grouped = EasyFind.db.mapTabShowParents ~= false
    local viewedMapID = WorldMapFrame and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    local viewedInfo = viewedMapID and GetMapInfo and GetMapInfo(viewedMapID)
    if grouped and viewedInfo and EXCLUDE_FROM_LOCAL_MAPTYPES[viewedInfo.mapType] then
        localEntries = ns.PlaceList.GroupBySharedParent(localFiltered)




        for i = 1, #localRaw do
            local r = localRaw[i]
            if r and r.isZone and r.zoneMapID then
                for j = 1, #localEntries do
                    local e = localEntries[j]
                    if e.type == "group" and e.ancestorMapID == r.zoneMapID
                       and e.navigateData and e.navigateData.synthesized then
                        e.navigateData = r
                    end
                end
            end
        end
    else

        localEntries = ns.PlaceList.FlatEntries(localFiltered)
    end

    local globalEntries
    if grouped then
        globalEntries, globalFiltered = ns.PlaceList.WorldEntries(globalFiltered)
    else
        globalEntries = ns.PlaceList.FlatEntries(globalFiltered)
    end



    if grouped and viewedMapID then
        for i = #globalEntries, 1, -1 do
            local e = globalEntries[i]
            if e.type == "group" and e.ancestorMapID == viewedMapID then
                tremove(globalEntries, i)
            end
        end
    end




    local CANDIDATE_CAP = 12
    local candidates = SEARCH_SCRATCH.candidateNames
    wipe(candidates)
    if localFiltered then
        for i = 1, mmin(#localFiltered, CANDIDATE_CAP) do
            if localFiltered[i] and localFiltered[i].name then
                candidates[#candidates + 1] = localFiltered[i].name
            end
        end
    end
    for i = 1, mmin(#globalFiltered, CANDIDATE_CAP) do
        if globalFiltered[i] and globalFiltered[i].name then
            candidates[#candidates + 1] = globalFiltered[i].name
        end
    end
    panel.topResultCandidates = candidates
    panel.topResultName = candidates[1]

    list:Render({
        query = text, pinned = pinned,
        localEntries = localEntries,
        localLabel = viewedInfo and L["MAP_SECTION_THIS_ZONE_NAMED"]:format(viewedInfo.name) or L["MAP_SECTION_THIS_ZONE"],
        globalEntries = globalEntries, globalLabel = L["MAP_SECTION_ACROSS_WORLD"],
    })




    if activePage == nil and (not pinned or #pinned == 0)
       and #localEntries == 0 and #globalEntries == 0 then
        panel.emptyMsg:SetText("|cff999999" .. L["MAP_NO_MATCHES"] .. "|r")
        panel.emptyMsg:Show()
    end
    restoreScroll()
end


function MapTab:RefreshSearch()
    if panel and panel:IsShown() and currentQuery ~= "" then MapTab:RunSearch(currentQuery) end
end






local HandleNavKey
local RefocusSearchBox
local RefocusSearchBoxAfterAltNav

local function StopNavRepeatAndRefocus(key)
    local navKey = Utils.NormalizeKey(key)
    if not (navKeyRepeat and navKeyRepeat.IsKey(navKey)) then return end
    navKeyRepeat.Stop(navKey)
    if navRowIndex ~= 0 then return end
    if navKey == "J" or navKey == "K" then
        RefocusSearchBoxAfterAltNav(navKey)
    else
        RefocusSearchBox()
    end
end

local function EnsureNavFrame()
    if navFrame then return navFrame end
    if not panel then return nil end
    navFrame = CreateFrame("Frame", nil, panel)
    Utils.SafeCallMethod(navFrame, "EnableKeyboard", false)
    Utils.SafeCallMethod(navFrame, "SetPropagateKeyboardInput", true)
    navFrame:SetScript("OnKeyDown", function(self, key)
        Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", not HandleNavKey(key, false))
    end)
    navFrame:SetScript("OnKeyUp", function(_, key)
        StopNavRepeatAndRefocus(key)
    end)
    navKeyRepeat = Utils.CreateKeyRepeat(navFrame)
    return navFrame
end

local function UpdateNavHighlight()
    for i = 1, #visibleNavRows do
        local f = visibleNavRows[i]
        if f then
            local selected = (i == navRowIndex)
            if f.hoverOverlay then
                f.hoverOverlay:SetShown(selected)
                if f.label then
                    if selected then
                        f.label:SetTextColor(0.90, 0.88, 0.85, 1.0)
                    elseif not f:IsMouseOver()
                       and not (f.toggleBtn and f.toggleBtn:IsMouseOver()) then
                        local g = f._matchColor
                        f.label:SetTextColor(
                            g and GOLD_COLOR[1] or 0.60,
                            g and GOLD_COLOR[2] or 0.58,
                            g and GOLD_COLOR[3] or 0.55, 1.0)
                    end
                end
            elseif f.LockHighlight then
                if selected then f:LockHighlight() else f:UnlockHighlight() end
            end
        end
    end
    if navRowIndex > 0 and panel and panel.scrollFrame then
        local f = visibleNavRows[navRowIndex]
        if f then Utils.ScrollToButton(panel.scrollFrame, f) end
    end
    if navRowIndex > 0 then
        local f = visibleNavRows[navRowIndex]
        local data = f and (f.data or f.navigateData)
        if data then
            HoverPreview(data, true)
        else
            ClearHoverPreview()
        end
    else
        ClearHoverPreview()
    end
end

local function SetNavFrameCapture(on)
    local nf = EnsureNavFrame()
    if not nf then return end
    Utils.SafeCallMethod(nf, "EnableKeyboard", on and true or false)


    if not on and navKeyRepeat then navKeyRepeat.Stop() end
end

RefocusSearchBox = function()
    if navRowIndex ~= 0 then return end
    if not (panel and panel.searchBox) then return end
    panel.searchBox._blockAutoFocus = nil
    panel.searchBox:SetFocus()
end

RefocusSearchBoxAfterAltNav = function(key)
    Utils.ScheduleAfterAltNavRelease(key, RefocusSearchBox)
end

local function SetNavRowIndex(i)
    if i < 0 then i = 0 end
    if i > #visibleNavRows then i = #visibleNavRows end
    navRowIndex = i
    UpdateNavHighlight()
end

local function MoveNavSelection(delta)
    if #visibleNavRows == 0 then return false end
    local newIdx = navRowIndex + delta
    if newIdx < 1 then newIdx = 1 end
    if newIdx > #visibleNavRows then newIdx = #visibleNavRows end
    if newIdx == navRowIndex then return false end
    SetNavRowIndex(newIdx)
    return true
end

local function MoveNavSelectionUpOrExit()
    if #visibleNavRows == 0 then return false end
    if navRowIndex <= 1 then
        SetNavRowIndex(0)
        SetNavFrameCapture(false)
        return false
    end
    return MoveNavSelection(-1)
end

local function FindFirstNavRowIndex()
    local fallback
    for i = 1, #visibleNavRows do
        local row = visibleNavRows[i]
        local data = row and (row.data or row.navigateData)
        if data then
            if not fallback then fallback = i end
            if not data.isRecentSearch and not data.isPinned then return i end
        end
    end
    return fallback
end

local function SelectFirstNavRow()
    local idx = FindFirstNavRowIndex()
    if not idx then return false end
    if panel and panel.searchBox then panel.searchBox:ClearFocus() end
    SetNavFrameCapture(true)
    SetNavRowIndex(idx)
    return true
end

local function ActivateNavSelection()
    if navRowIndex == 0 then return false end
    local f = visibleNavRows[navRowIndex]
    if not f then return false end
    local handler = f:GetScript("OnClick")
    if handler then
        handler(f, "LeftButton")
        return true
    end
    return false
end


HandleNavKey = function(key, keepSearchFocus)
    local delta, altNav, navKey = Utils.GetVerticalNavIntent(key)
    if delta == 1 then
        if #visibleNavRows == 0 then return false end
        if keepSearchFocus and panel and panel.searchBox then
            panel.searchBox:ClearFocus()
        end
        SetNavFrameCapture(true)
        if altNav then
            Utils.StartAltNavRepeat(navKeyRepeat, navKey, panel and panel.searchBox,
                function() return MoveNavSelection(1) end)
        else
            Utils.StartKeyRepeatOnce(navKeyRepeat, navKey, function()
                return MoveNavSelection(1)
            end)
        end
        return true
    elseif delta == -1 then
        if #visibleNavRows == 0 then return false end

        if navRowIndex <= 1 then
            SetNavRowIndex(0)
            SetNavFrameCapture(false)
            if keepSearchFocus then
                if altNav then Utils.SuppressNextAltNavChar(panel and panel.searchBox, navKey) end
            elseif altNav then
                RefocusSearchBoxAfterAltNav(navKey)
            else
                RefocusSearchBox()
            end
            return true
        end
        if keepSearchFocus and panel and panel.searchBox then
            panel.searchBox:ClearFocus()
        end
        SetNavFrameCapture(true)
        if altNav then
            Utils.StartAltNavRepeat(navKeyRepeat, navKey, panel and panel.searchBox,
                MoveNavSelectionUpOrExit,
                RefocusSearchBox)
        else
            Utils.StartKeyRepeatOnce(navKeyRepeat, navKey, function()
                local moved = MoveNavSelectionUpOrExit()
                if not moved and navRowIndex == 0 then RefocusSearchBox() end
                return moved
            end)
        end
        return true
    elseif key == "SPACE" then


        if keepSearchFocus then return false end
        if navRowIndex > 0 then
            local f = visibleNavRows[navRowIndex]
            if f and f.toggleBtn and f.toggleBtn:IsShown() then



                local savedGroupKey = f.groupKey
                local handler = f.toggleBtn:GetScript("OnClick")
                if handler then handler(f.toggleBtn) end
                if savedGroupKey then
                    for i = 1, #visibleNavRows do
                        if visibleNavRows[i].groupKey == savedGroupKey then
                            SetNavRowIndex(i)
                            SetNavFrameCapture(true)
                            break
                        end
                    end
                end
            end
            return true
        end
        return false
    elseif key == "ENTER" then
        if navRowIndex > 0 then
            ActivateNavSelection()



            SetNavRowIndex(0)
            SetNavFrameCapture(false)
            if panel and panel.searchBox then panel.searchBox:ClearFocus() end
            return true
        end
        return SelectFirstNavRow()
    elseif key == "ESCAPE" then
        if not keepSearchFocus then


            if navRowIndex > 0 then
                SetNavRowIndex(0)
                SetNavFrameCapture(false)
                if panel and panel.searchBox then panel.searchBox:SetFocus() end
                return true
            end
            return false
        else
            if panel and panel.searchBox then panel.searchBox:ClearFocus() end
            return true
        end
    end
    return false
end

local function CreateSearchBox(parent)
    local editBox = CreateFrame("EditBox", nil, parent, "SearchBoxTemplate")
    editBox:SetSize(301, 20)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(60)
    Utils.ReleaseFocusOnOutsideClick(editBox)
    if editBox.Instructions then



        local function FitPlaceholder()
            local instructions = editBox.Instructions
            instructions:SetText(L["MAP_SEARCH_PLACEHOLDER"])
            local avail = instructions:GetWidth() or 0
            local getter = instructions.GetUnboundedStringWidth or instructions.GetStringWidth
            if avail > 0 and getter(instructions) > avail then
                instructions:SetText(_G["SEARCH"] or "Search")
            end
        end
        FitPlaceholder()
        editBox:HookScript("OnSizeChanged", FitPlaceholder)
        Utils.SafeAfter(0, FitPlaceholder)
        editBox.FitPlaceholder = FitPlaceholder
    end






    editBox._blockAutoFocus = true
    editBox:HookScript("OnEditFocusGained", function(self)
        if self._blockAutoFocus then self:ClearFocus() end
    end)
    editBox:HookScript("OnMouseDown", function(self) self._blockAutoFocus = nil end)
    editBox:ClearFocus()
    SafeAfter(0, function()
        SafeAfter(0, function()
            if editBox then editBox._blockAutoFocus = nil; editBox:ClearFocus() end
        end)
    end)

    local function UpdateClear(self)
        if self.clearButton then
            self.clearButton:SetShown(self:HasFocus() or self:GetText() ~= "")
        end
    end




    if editBox.clearButton then
        editBox.clearButton:HookScript("OnClick", function()
            if ReleaseMapTabMemory then ReleaseMapTabMemory(false) end

            if ns.MapSearch and ns.MapSearch.ClearZoneHighlight then ns.MapSearch:ClearZoneHighlight() end
        end)
    end

    local function FindPrefixCandidate(q)
        if not panel or q == "" then return nil end
        local qLower = q:lower()
        local list = panel.topResultCandidates
        if not list then return nil end
        for i = 1, #list do
            local name = list[i]
            if name and #name >= #q
               and name:sub(1, #q):lower() == qLower
               and name:lower() ~= qLower then
                return name
            end
        end
        return nil
    end
    editBox.FindPrefixCandidate = FindPrefixCandidate

    Utils.AttachAltNavCharSuppressor(editBox, function(self, restoredText)
        UpdateClear(self)
        if pendingSearchTimer then CancelPendingSearch() end
        if currentQuery ~= restoredText then MapTab:RunSearch(restoredText or "") end
    end)

    Utils.AttachAutocomplete(editBox, {
        enabled = function() return EasyFind.db.mapTabAutocomplete ~= false end,
        findCandidate = FindPrefixCandidate,
        onTypedChanged = function(self, typed, _, grew)
            lastTypeTime = GetTime()
            UpdateClear(self)
            SchedulePendingSearch(self, typed, grew)
        end,
        onAccepted = function(text, source)
            if text and text ~= "" then MapTab:RunSearch(text) end
            if source ~= "right" and source ~= "alt-l" and source ~= "click" then
                MapTab:PushRecentSearch(text)
            end
        end,
    })
    editBox:HookScript("OnEditFocusGained", UpdateClear)
    editBox:HookScript("OnEditFocusLost", function(self)
        UpdateClear(self)
    end)




    editBox:HookScript("OnKeyDown", function(self, key)
        local navKey = Utils.NormalizeKey(key)
        if IsAltKeyDown() and navKey and navKey:match("^[A-Z]$") then
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
        end
        if IsAltKeyDown() and (navKey == "J" or navKey == "K") then
            Utils.SuppressNextAltNavChar(self, navKey)
        end
        if self.HasAutocomplete and self:HasAutocomplete() and self.AcceptAutocomplete then
            if navKey == "RIGHT" or navKey == "ARROWRIGHT" then
                self:AcceptAutocomplete("right")
                Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
                return
            elseif navKey == "L" and IsAltKeyDown() then
                self:AcceptAutocomplete("alt-l")
                Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
                return
            end
        end
        if pendingSearchTimer
           and (navKey == "DOWN" or navKey == "UP" or navKey == "ENTER"
                or (IsAltKeyDown() and (navKey == "J" or navKey == "K"))) then
            RunPendingSearchNow()
        end
        HandleNavKey(navKey, true)
        Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
    end)


    editBox:HookScript("OnKeyUp", function(_, key)
        StopNavRepeatAndRefocus(key)
    end)




    editBox:HookScript("OnMouseDown", function(self)
        self:SetFocus()
        if navFrame then
            Utils.SafeCallMethod(navFrame, "EnableKeyboard", false)
        end
        if navKeyRepeat then navKeyRepeat.Stop() end
        navRowIndex = 0
    end)
    editBox:HookScript("OnEditFocusGained", function()
        if navFrame then
            Utils.SafeCallMethod(navFrame, "EnableKeyboard", false)
        end
        if navKeyRepeat then navKeyRepeat.Stop() end
    end)

    editBox:HookScript("OnEnterPressed", function(self)
        if navRowIndex > 0 then return end
        RunPendingSearchNow()
        local current = self:GetText() or ""
        local typed = self.GetTypedText and self:GetTypedText() or current
        local accepted = false
        if self.HasAutocomplete and self:HasAutocomplete() and self.AcceptAutocomplete then
            accepted = self:AcceptAutocomplete()
            current = self:GetText() or ""
        elseif current ~= "" and current ~= typed and self.AcceptAutocomplete then
            accepted = self:AcceptAutocomplete()
            current = self:GetText() or ""
        end
        if not accepted then MapTab:PushRecentSearch(current) end
        if current ~= currentQuery then MapTab:RunSearch(current) end
        SelectFirstNavRow()
    end)
    return editBox
end

local RECENT_ABSOLUTE_MAX = 20
local function GetRecentLimit()
    local n = EasyFind.db and EasyFind.db.mapTabRecentCount
    if type(n) ~= "number" or n < 1 then n = 3 end
    if n > RECENT_ABSOLUTE_MAX then n = RECENT_ABSOLUTE_MAX end
    return n
end
MapTab.GetRecentLimit = GetRecentLimit

function MapTab:RefreshIfOpen()
    if panel and panel:IsShown() and RefreshCurrentSearch then
        RefreshCurrentSearch()
    end
end

function MapTab:PushRecentSearch(text)
    if type(text) ~= "string" then return end
    text = text:match("^%s*(.-)%s*$") or ""
    if #text < 2 then return end
    local db = EasyFind.db
    if not db then return end
    db.mapTabRecentSearches = db.mapTabRecentSearches or {}
    local list = db.mapTabRecentSearches
    local lowerNew = text:lower()
    for i = #list, 1, -1 do
        if type(list[i]) == "string" and list[i]:lower() == lowerNew then
            tremove(list, i)
        end
    end
    tinsert(list, 1, text)
    local limit = GetRecentLimit()
    while #list > limit do tremove(list) end
end


function MapTab:ForgetRecentSearch(query)
    local list = EasyFind.db and EasyFind.db.mapTabRecentSearches
    if not (list and query) then return end
    local lowerQ = query:lower()
    for i = #list, 1, -1 do
        if type(list[i]) == "string" and list[i]:lower() == lowerQ then
            tremove(list, i)
        end
    end
    MapTab:RefreshIfOpen()
end

local FILTER_OPTIONS = {
    { key = "zones",      label = _G["ZONES"] or "Zones" },
    { key = "instances",  label = L["MAP_FILTER_INSTANCES"] },
    { key = "raid",       label = _G["RAIDS"] or "Raids",                   parentKey = "instances" },
    { key = "dungeon",    label = _G["DUNGEONS"] or "Dungeons",             parentKey = "instances" },
    { key = "delve",      label = _G["DELVES_LABEL"] or "Delves",           parentKey = "instances", caps = "delves" },
    { key = "travel",     label = L["MAP_FILTER_TRAVEL"],   tooltip = L["MAP_FILTER_TRAVEL_TT"] },
    { key = "flights",    label = L["MAP_FILTER_FLIGHTS"],                  parentKey = "travel" },
    { key = "boats",      label = L["MAP_FILTER_BOATS"],                    parentKey = "travel" },
    { key = "portals",    label = L["MAP_FILTER_PORTALS"],                  parentKey = "travel" },
    { key = "services",   label = L["MAP_FILTER_SERVICES"], tooltip = L["MAP_FILTER_SERVICES_TT"] },
    { key = "banks",      label = L["MAP_FILTER_BANKS"],           parentKey = "services" },
    { key = "auction",    label = L["MAP_FILTER_AUCTION"],         parentKey = "services" },
    { key = "inns",       label = L["MAP_FILTER_INNS"],            parentKey = "services" },
    { key = "mail",       label = L["MAP_FILTER_MAIL"],            parentKey = "services" },
    { key = "trainers",   label = L["MAP_FILTER_TRAINERS"],        parentKey = "services" },
    { key = "vendors",    label = L["MAP_FILTER_VENDORS"],         parentKey = "services" },
    { key = "appearance", label = L["MAP_FILTER_APPEARANCE"],      parentKey = "services" },
    { key = "otherservices", label = L["MAP_FILTER_OTHER_SERVICES"], parentKey = "services" },
    { key = "rares",      label = L["MAP_FILTER_RARES"] },
    { key = "npcs",       label = L["FILTER_NPCS"],         tooltip = L["MAP_FILTER_NPCS_TT"] },
}


if ns.Caps then
    for i = #FILTER_OPTIONS, 1, -1 do
        local row = FILTER_OPTIONS[i]
        if row.caps and ns.Caps[row.caps] == false then tremove(FILTER_OPTIONS, i) end
    end
end





local MENU_CHECK = "Interface\\Buttons\\UI-CheckBox-Check"

local function Filters()
    EasyFind.db.mapTabFilters = EasyFind.db.mapTabFilters or {}
    return EasyFind.db.mapTabFilters
end

local function SetAutoTrack(on)
    EasyFind.db.alwaysShowRares = on and true or false
    local MapSearch = ns.MapSearch

    if MapSearch and MapSearch.UpdateRareTracking then
        SafeAfter(0, function() MapSearch:UpdateRareTracking() end)
    end
    if ns.optionsFrame and ns.optionsFrame.rareTrackCheckbox then
        ns.optionsFrame.rareTrackCheckbox:SetChecked(EasyFind.db.alwaysShowRares)
    end
end


local function BucketRows(parent, onChanged)
    return function()
        local filters = Filters()
        local off = filters[parent.key] == false
        local rows = {}
        for _, opt in ipairs(FILTER_OPTIONS) do
            if opt.parentKey == parent.key then
                rows[#rows + 1] = { text = opt.label, keepOpen = true, disabled = off,
                    icon = filters[opt.key] ~= false and MENU_CHECK or nil,
                    get = function() return Filters()[opt.key] ~= false end,
                    onClick = function()
                        filters[opt.key] = filters[opt.key] == false
                        onChanged(opt.key, filters[opt.key])
                    end }
            end
        end
        if parent.key == "rares" then
            rows[#rows + 1] = { text = L["MAP_AUTO_TRACK"], tooltip = L["MAP_AUTO_TRACK_RARES_TT"], keepOpen = true,
                disabled = off, icon = EasyFind.db.alwaysShowRares and MENU_CHECK or nil,
                get = function() return EasyFind.db.alwaysShowRares == true end,
                onClick = function() SetAutoTrack(not EasyFind.db.alwaysShowRares) end }
        end
        return rows
    end
end




local function NpcFacetRows(onChanged)
    return function()
        local off = Filters().npcs == false
        local rows = {}
        local Flt = ns.Filters
        for _, facet in ipairs(Flt and Flt.NpcFacets and Flt:NpcFacets() or {}) do
            local defs = facet.defs()
            if #defs > 1 then
                rows[#rows + 1] = { text = facet.label, keepOpen = true, disabled = off, submenu = function()
                    local picks = Flt.NpcFacet(facet.name)
                    local out = {}
                    for _, d in ipairs(facet.defs()) do
                        out[#out + 1] = { text = d.label, keepOpen = true, disabled = off,
                            icon = picks[d.key] ~= false and MENU_CHECK or nil,
                            get = function() return Flt.NpcFacet(facet.name)[d.key] ~= false end,
                            onClick = function()
                                if picks[d.key] == false then picks[d.key] = nil else picks[d.key] = false end
                                onChanged("npcs", Filters().npcs ~= false)
                            end }
                    end
                    return out
                end }
            end
        end
        return rows
    end
end



function MapTab.ScaleChrome(p)
    local s = FontScale()
    local box = p.searchBox
    if box then
        ScaleFont(box, "ChatFontNormal", s)
        if box.FitHeight then box.FitHeight() end
        if box.Instructions then ScaleFont(box.Instructions, "GameFontDisableSmall", s) end
        if box.FitPlaceholder then box.FitPlaceholder() end
    end
    if p.emptyMsg then ScaleFont(p.emptyMsg, "GameFontHighlight", s) end
    if p.recentLabel then ScaleFont(p.recentLabel, "GameFontHighlightSmall", s) end
    if p.expandLabel then ScaleFont(p.expandLabel, "GameFontHighlightSmall", s) end
    if p.extTip then ScaleFont(p.extTip.text, "GameFontHighlightSmall", s) end
    if p.LayoutChecks then p.LayoutChecks() end
end


function MapTab.RefreshExtensionTip()
    if panel and panel.LayoutChecks then panel.LayoutChecks() end
end


local function FontRows(onPick)
    return function()

        local cur, near = FontScale(), nil
        for _, choice in ipairs(FONT_SIZES) do
            if not near or math.abs(choice[2] - cur) < math.abs(near - cur) then near = choice[2] end
        end
        local rows = {}
        for _, choice in ipairs(FONT_SIZES) do
            rows[#rows + 1] = { text = L[choice[1]], keepOpen = true, radio = true,
                icon = choice[2] == near and MENU_CHECK or nil,
                get = function() return choice[2] == near end,
                onClick = function()
                    EasyFind.db.mapTabFontSize = choice[2]
                    onPick()
                end }
        end
        return rows
    end
end



function MapTab.StepFontSize(delta)
    local cur = FontScale()
    local s = delta == 0 and 1 or math.floor((cur + delta * 0.05) * 100 + 0.5) / 100
    s = math.max(FONT_SIZES[1][2], math.min(FONT_SIZES[#FONT_SIZES][2], s))
    if s == cur or not (panel and panel.OnFontPicked) then return end
    EasyFind.db.mapTabFontSize = s
    panel.OnFontPicked()
end



local function ShowDefs(onChanged)
    local filters = Filters()
    local defs = { { kind = "title", label = (_G["SHOW"] or "Show") .. ":" } }
    for _, opt in ipairs(FILTER_OPTIONS) do
        if not opt.parentKey then
            local kinds = opt.key == "rares"
            for _, o in ipairs(FILTER_OPTIONS) do
                if o.parentKey == opt.key then kinds = true end
            end
            defs[#defs + 1] = { kind = "check", label = opt.label, tooltip = opt.tooltip,
                rows = (kinds and BucketRows(opt, onChanged)) or (opt.key == "npcs" and NpcFacetRows(onChanged)) or nil,
                get = function() return filters[opt.key] ~= false end,
                set = function(v)
                    filters[opt.key] = v and true or false
                    onChanged(opt.key, v)
                end }
        end
    end
    return defs
end



local function PlacedDefs(defs, onChanged)
    local filters, placed = Filters(), {}
    for _, p in pairs(ns.Extensions.Providers.byKey) do
        if p.place then placed[#placed + 1] = p end
    end
    table.sort(placed, function(a, b) return a.label < b.label end)
    for _, p in ipairs(placed) do
        local key = p.category
        defs[#defs + 1] = { kind = "check", label = p.label,
            get = function() return filters[key] ~= false end,
            set = function(v)
                filters[key] = v and true or false
                onChanged(key, v)
            end }
    end
end

local function MapOptionsDefs(onChanged, onFontPick)
    local defs = ShowDefs(onChanged)
    PlacedDefs(defs, onChanged)
    defs[#defs + 1] = { kind = "separator" }
    defs[#defs + 1] = { kind = "check", label = L["MAP_SHOW_PARENTS"], tooltip = L["MAP_SHOW_PARENTS_TT"],
        get = function() return EasyFind.db.mapTabShowParents ~= false end,
        set = function(v)
            EasyFind.db.mapTabShowParents = v and true or false
            RefreshCurrentSearch()
        end }
    defs[#defs + 1] = { kind = "submenu", label = L["OPT_FONT_SIZE"], rows = FontRows(onFontPick) }
    return defs
end

local function NativeTip(elem, title, text)
    elem:SetTooltip(function(tooltip)
        GameTooltip_SetTitle(tooltip, title)
        GameTooltip_AddNormalLine(tooltip, text)
    end)
end




local function AddNativeRows(elem, rows)
    for _, r in ipairs(type(rows) == "function" and rows() or rows) do
        local sub
        if r.separator then
            elem:CreateDivider()
        elseif r.get then
            sub = (r.radio and elem.CreateRadio or elem.CreateCheckbox)(elem, r.text, r.get, r.onClick)
        else
            sub = elem:CreateButton(r.text, r.onClick)
        end
        if sub then
            if r.disabled then sub:SetEnabled(false) end
            if r.tooltip then NativeTip(sub, r.text, r.tooltip) end
            if r.submenu then AddNativeRows(sub, r.submenu) end
        end
    end
end




local function ShowNativeMapOptions(owner, defs)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return false end
    local ok = pcall(MenuUtil.CreateContextMenu, owner, function(_, root)
        for _, d in ipairs(defs) do
            if d.kind == "title" then
                root:CreateTitle(d.label)
            elseif d.kind == "separator" then
                root:CreateDivider()
            elseif d.kind == "check" then
                local box = root:CreateCheckbox(d.label, d.get, function() d.set(not d.get()) end)
                if d.tooltip then NativeTip(box, d.label, d.tooltip) end
                if d.rows then AddNativeRows(box, d.rows) end
            elseif d.kind == "submenu" then
                AddNativeRows(root:CreateButton(d.label), d.rows)
            end
        end
    end)
    return ok
end



function MapTab.FilterChanged(key)
    if key == "flights" and ns.MapSearch and ns.MapSearch.ReleaseIdleSearchMemory then
        ns.MapSearch:ReleaseIdleSearchMemory()
    end
    RefreshCurrentSearch()


    if key == "rares" and ns.MapSearch and ns.MapSearch.UpdateRareTracking then
        SafeAfter(0, function() ns.MapSearch:UpdateRareTracking() end)
    end
    local uiMod = ns.Search
    local uiSb = uiMod and uiMod.searchFrame and uiMod.searchFrame.editBox
    if uiMod and uiMod.OnSearchTextChanged and uiSb and uiSb:IsShown() then
        local txt = uiSb:GetText() or ""
        if txt ~= "" then uiMod:OnSearchTextChanged(txt) end
    end
    EasyFind.API.Fire("easyfind", "mapFiltersChanged")
end


function MapTab.ShowDefs() return ShowDefs(MapTab.FilterChanged) end



function MapTab.FilterRows(onChanged)
    return function()
        local filters = Filters()
        local rows = {}
        for _, opt in ipairs(FILTER_OPTIONS) do
            if not opt.parentKey then
                local kinds = opt.key == "rares"
                for _, o in ipairs(FILTER_OPTIONS) do
                    if o.parentKey == opt.key then kinds = true end
                end
                rows[#rows + 1] = { text = opt.label, tooltip = opt.tooltip, keepOpen = true,
                    icon = filters[opt.key] ~= false and MENU_CHECK or nil,
                    get = function() return Filters()[opt.key] ~= false end,
                    submenu = (kinds and BucketRows(opt, onChanged)) or (opt.key == "npcs" and NpcFacetRows(onChanged)) or nil,
                    onClick = function()
                        filters[opt.key] = filters[opt.key] == false
                        onChanged(opt.key, filters[opt.key])
                    end }
            end
        end
        return rows
    end
end

local function CreateFilterCog(parent)
    local cog = CreateFrame("Button", nil, parent)
    cog:SetSize(14, 16)
    local function CogArt(tex)
        if ns.SETTING_ICON.atlas then
            tex:SetAtlas(ns.SETTING_ICON.atlas, false)
        else
            tex:SetTexture(ns.SETTING_ICON.tex)
            tex:SetDesaturated(true)
        end
        tex:SetAllPoints()
    end
    local iconTex = cog:CreateTexture(nil, "ARTWORK")
    CogArt(iconTex)

    local hoverTex = cog:CreateTexture(nil, "HIGHLIGHT")
    CogArt(hoverTex)
    hoverTex:SetBlendMode("ADD")
    hoverTex:SetAlpha(0.7)
    return cog
end
MapTab.CreateFilterCog = CreateFilterCog

local function CreateTabFrame(qmf)
    local tab = CreateFrame("Frame", "EasyFindMapSearchTab", qmf)



    local refW, refH = qmf.MapLegendTab:GetSize()
    if not refW or refW == 0 then refW, refH = TAB_W, TAB_H end
    tab:SetSize(refW, refH)
    tab:SetFrameStrata("HIGH")
    tab:SetFrameLevel(qmf.MapLegendTab:GetFrameLevel())
    tab.displayMode = "EasyFindMapSearch"
    tab:EnableMouse(true)

    local bg = tab:CreateTexture(nil, "BACKGROUND")
    bg:SetAtlas(SIDE_TAB, true)
    bg:SetPoint("CENTER", tab, "CENTER", 0, 0)

    local icon = tab:CreateTexture(nil, "ARTWORK")


    icon:SetTexture(ns.GPS_ICON_TEX)
    icon:SetTexCoord(0, 1, 0, 1)
    icon:SetSize(TAB_ICON_SIZE + 2, TAB_ICON_SIZE + 2)


    icon:SetPoint("CENTER", tab, "CENTER", SIDE_TAB_ICON_X, 0)
    icon:SetVertexColor(Utils.RGB(TAB_ICON_DIM))
    tab._efIcon = icon

    local selectGlow = tab:CreateTexture(nil, "OVERLAY")
    selectGlow:SetAtlas(SIDE_TAB_SELECT, true)
    selectGlow:SetPoint("CENTER", bg, "CENTER", 0, 0)
    selectGlow:Hide()
    tab._efSelectGlow = selectGlow

    local hoverGlow = tab:CreateTexture(nil, "HIGHLIGHT")
    hoverGlow:SetAtlas(SIDE_TAB_HOVER, true)
    hoverGlow:SetPoint("CENTER", bg, "CENTER", 0, 0)

    tab:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then ShowOurPanel(false) end
    end)
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L["MAP_SEARCH_TITLE"])
        GameTooltip:AddLine(L["MAP_SEARCH_TT"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", GameTooltip_Hide)

    return tab
end




local function CreateBackTab(qmf)
    local tab = CreateFrame("Frame", "EasyFindMapQuestsTab", qmf)
    local refW, refH = qmf.QuestsTab:GetSize()
    if not refW or refW == 0 then refW, refH = TAB_W, TAB_H end
    tab:SetSize(refW, refH)
    tab:SetFrameStrata("HIGH")
    tab:SetFrameLevel(qmf.QuestsTab:GetFrameLevel())
    tab:EnableMouse(true)

    local bg = tab:CreateTexture(nil, "BACKGROUND")
    bg:SetAtlas("QuestLog-tab-side", true)
    bg:SetPoint("CENTER", tab, "CENTER", 0, 0)
    tab.art = bg



    local icon = tab:CreateTexture(nil, "ARTWORK")
    local copied = false



    local src = qmf.QuestsTab.Icon
    if not src then
        for i = 1, qmf.QuestsTab:GetNumRegions() do
            local r = select(i, qmf.QuestsTab:GetRegions())
            if r and r.GetObjectType and r:GetObjectType() == "Texture" then
                local atlas = r.GetAtlas and r:GetAtlas()
                local low = atlas and atlas:lower() or ""
                if atlas and not low:find("tab") and not low:find("glow") then src = r break end
            end
        end
    end
    if src then
        local atlas = src.GetAtlas and src:GetAtlas()
        if atlas then
            icon:SetAtlas(atlas, false)
            copied = true
        elseif src.GetTexture and src:GetTexture() then
            icon:SetTexture(src:GetTexture())
            if src.GetTexCoord then icon:SetTexCoord(src:GetTexCoord()) end
            copied = true
        end
    end
    if not copied then icon:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon") end
    icon:SetSize(TAB_ICON_SIZE + 4, TAB_ICON_SIZE + 4)
    icon:SetPoint("CENTER", tab, "CENTER", 0, 0)
    icon:SetVertexColor(Utils.RGB(TAB_ICON_GOLD))
    tab._efIcon = icon

    local selectGlow = tab:CreateTexture(nil, "OVERLAY")
    selectGlow:SetAtlas("QuestLog-Tab-side-Glow-Select", true)
    selectGlow:SetPoint("CENTER", bg, "CENTER", 0, 0)
    selectGlow:Show()
    tab._efSelectGlow = selectGlow

    local hoverGlow = tab:CreateTexture(nil, "HIGHLIGHT")
    hoverGlow:SetAtlas("QuestLog-Tab-side-Glow-hover", true)
    hoverGlow:SetPoint("CENTER", bg, "CENTER", 0, 0)

    tab:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then return end


        lastSelectedWasOurs = false
        HideOurPanel()
        RefreshSelectGlows()
    end)
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(_G["QUESTLOG_BUTTON"] or _G["QUESTS_LABEL"] or "Quests")
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", GameTooltip_Hide)
    return tab
end



local function CreateExtraTab(qmf, def)
    local tab = CreateFrame("Frame", "EasyFindMapTab_" .. def.id, qmf)
    local refW, refH = qmf.MapLegendTab:GetSize()
    if not refW or refW == 0 then refW, refH = TAB_W, TAB_H end
    tab:SetSize(refW, refH)
    tab:SetFrameStrata("HIGH")
    tab:SetFrameLevel(qmf.MapLegendTab:GetFrameLevel())
    tab.displayMode = "EasyFindPage_" .. def.id
    tab._efExtraTab = true
    tab:EnableMouse(true)

    local bg = tab:CreateTexture(nil, "BACKGROUND")
    bg:SetAtlas(SIDE_TAB, true)
    bg:SetPoint("CENTER", tab, "CENTER", 0, 0)

    local icon = tab:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(def.icon)
    if def.coords then icon:SetTexCoord(unpack(def.coords)) end
    local size = def.iconSize or TAB_ICON_SIZE
    icon:SetSize(size, size)


    icon:SetPoint("CENTER", tab, "CENTER", SIDE_TAB_ICON_X, 0)
    icon:SetVertexColor(Utils.RGB(TAB_ICON_DIM))
    tab._efIcon = icon

    local selectGlow = tab:CreateTexture(nil, "OVERLAY")
    selectGlow:SetAtlas(SIDE_TAB_SELECT, true)
    selectGlow:SetPoint("CENTER", bg, "CENTER", 0, 0)
    selectGlow:Hide()
    tab._efSelectGlow = selectGlow

    local hoverGlow = tab:CreateTexture(nil, "HIGHLIGHT")
    hoverGlow:SetAtlas(SIDE_TAB_HOVER, true)
    hoverGlow:SetPoint("CENTER", bg, "CENTER", 0, 0)

    tab:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then ShowOurPanel(def.id) end
    end)
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(def.title or def.id)
        if def.tooltip then GameTooltip:AddLine(def.tooltip, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", GameTooltip_Hide)
    return tab
end

local function EnsureExtraTab(id)
    local def = pages[id]
    if not def or def.noTab or extraTabs[id] then return end
    local qmf = _G["QuestMapFrame"]
    if not qmf or not qmf.MapLegendTab then return end
    extraTabs[id] = CreateExtraTab(qmf, def)
end



function SidePanel.Build()
    local wmf = WorldMapFrame
    local right = _G["MiniBorderRight"]
    if not (wmf and wmf.MiniBorderFrame and wmf.ScrollContainer and right) then return nil end


    local W, BARS_U, EDGE_U, CAP_U = 287, 199, 71, 24
    local TOP, BOTTOM, RIM = 24, 407, 73
    local LEFT_ART = "Interface\\WorldMap\\UI-WorldMapSmall-Left"
    local RIGHT_ART = "Interface\\WorldMap\\UI-WorldMapSmall-Right"
    SidePanel.W = W
    local f = CreateFrame("Frame", "EasyFindMapSidePanel", wmf)
    f:SetAllPoints(wmf)
    f:SetFrameLevel(wmf.MiniBorderFrame:GetFrameLevel())
    f:Hide()
    local function Piece(file, u0, u1, v0, v1, x, y)
        local t = f:CreateTexture(nil, "ARTWORK")
        local w = file == LEFT_ART and 512 or 128
        t:SetTexture(file)
        t:SetTexCoord(u0 / w, u1 / w, v0 / 512, v1 / 512)
        t:SetSize(u1 - u0, v1 - v0)
        t:SetPoint("TOPLEFT", right, "TOPLEFT", x, y)
    end

    local barsEnd, mapEnd = BARS_U + CAP_U + W, BARS_U + EDGE_U
    Piece(LEFT_ART, BARS_U, mapEnd, 0, 512, 0, 0)
    Piece(LEFT_ART, mapEnd, barsEnd, 0, TOP, EDGE_U, 0)
    Piece(LEFT_ART, mapEnd, barsEnd, BOTTOM, 512, EDGE_U, -BOTTOM)
    Piece(RIGHT_ART, EDGE_U, EDGE_U + 8, TOP, BOTTOM, EDGE_U, -TOP)
    Piece(RIGHT_ART, CAP_U, 128, 0, TOP, CAP_U + W, 0)
    Piece(RIGHT_ART, CAP_U, 128, BOTTOM, 512, CAP_U + W, -BOTTOM)
    Piece(RIGHT_ART, RIM, 128, TOP, BOTTOM, RIM + W, -TOP)

    local rock = f:CreateTexture(nil, "BACKGROUND")
    rock:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
    rock:SetHorizTile(true)
    rock:SetVertTile(true)
    rock:SetPoint("TOPLEFT", right, "TOPLEFT", EDGE_U + 7, 2 - TOP)
    rock:SetPoint("BOTTOMRIGHT", right, "TOPLEFT", RIM + W + 1, -BOTTOM - 1)


    local RIGHT_X = 12 + 512
    local contents = CreateFrame("Frame", nil, f)
    contents:SetPoint("TOPLEFT", f, "TOPLEFT", RIGHT_X + EDGE_U + 12, -TOP - 8)
    contents:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", RIGHT_X + RIM + W - 4, 7 - BOTTOM)
    contents:EnableMouse(true)
    f.ContentsAnchor = contents
    SidePanel.frame = f



    local toggle = CreateFrame("Button", "EasyFindMapSidePanelToggle", wmf)
    toggle:SetSize(32, 32)

    local levels = wmf.GetPinFrameLevelsManager and wmf:GetPinFrameLevelsManager()
    toggle:SetFrameLevel(((levels and levels.maxLevel) or 2000) + 1)
    toggle:SetPoint("BOTTOMRIGHT", right, "TOPLEFT", RIM - 1, 1 - BOTTOM)
    toggle:SetNormalTexture("Interface\\Buttons\\UI-SquareButton-Up")
    toggle:SetPushedTexture("Interface\\Buttons\\UI-SquareButton-Down")
    toggle:GetNormalTexture():SetTexCoord(2 / 32, 29 / 32, 3 / 32, 29 / 32)
    toggle:GetPushedTexture():SetTexCoord(2 / 32, 29 / 32, 3 / 32, 29 / 32)
    toggle:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local arrow = toggle:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\Buttons\\SquareButtonTextures")
    arrow:SetSize(11, 11)
    local pin = toggle:CreateTexture(nil, "OVERLAY")
    pin:SetTexture(ns.GPS_ICON_TEX)
    pin:SetSize(18, 18)
    pin:SetVertexColor(Utils.RGB(TAB_ICON_GOLD))
    local function PlaceGlyphs(dx, dy)
        arrow:SetPoint("LEFT", toggle, "LEFT", 5 + dx, dy)
        pin:SetPoint("CENTER", toggle, "CENTER", 4 + dx, dy)
    end
    PlaceGlyphs(0, 0)
    toggle:SetScript("OnMouseDown", function() PlaceGlyphs(1, -1) end)
    toggle:SetScript("OnMouseUp", function() PlaceGlyphs(0, 0) end)
    toggle:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        if selectedIsOurs then
            lastSelectedWasOurs = false
            EasyFind.db.mapSidePanelOpen = false
            HideOurPanel()
        else
            ShowOurPanel()
        end
    end)
    toggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L["MAP_SEARCH_TITLE"])
        GameTooltip:AddLine(L["MAP_SEARCH_TT"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave", GameTooltip_Hide)
    toggle:Hide()
    SidePanel.toggle, SidePanel.arrow = toggle, arrow
    SidePanel.RefreshToggle()
    if wmf.SynchronizeDisplayState then hooksecurefunc(wmf, "SynchronizeDisplayState", SidePanel.ClientPlacedClose) end
    return f
end



function SidePanel.Paper(p)
    local RIM_TEX = "Interface\\AddOns\\EasyFind\\textures\\QuestRim"
    local paper = p:CreateTexture(nil, "BACKGROUND", nil, -1)
    paper:SetTexture("Interface\\AddOns\\EasyFind\\textures\\QuestPaper")
    paper:SetTexCoord(0, 307 / 512, 0, 510 / 512)
    paper:SetAllPoints(p)
    local rim = CreateFrame("Frame", nil, p)
    rim:SetPoint("TOPLEFT", p, "TOPLEFT", -3, 7)
    rim:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 3, -6)
    rim:SetFrameLevel(p:GetFrameLevel() + 2)


    local cuts = { 0, 106 / 256, 108 / 256, 214 / 256 }
    local C = 53


    for _, c in ipairs({
        { 1, 1, C, C, { "TOPLEFT", 0, 0 } },
        { 3, 1, C, C, { "TOPRIGHT", 0, 0 } },
        { 1, 3, C, C, { "BOTTOMLEFT", 0, 0 } },
        { 3, 3, C, C, { "BOTTOMRIGHT", 0, 0 } },
        { 2, 1, 0, C, { "TOPLEFT", C, 0 }, { "TOPRIGHT", -C, 0 } },
        { 2, 3, 0, C, { "BOTTOMLEFT", C, 0 }, { "BOTTOMRIGHT", -C, 0 } },
        { 1, 2, C, 0, { "TOPLEFT", 0, -C }, { "BOTTOMLEFT", 0, C } },
        { 3, 2, C, 0, { "TOPRIGHT", 0, -C }, { "BOTTOMRIGHT", 0, C } },
        { 2, 2, 0, 0, { "TOPLEFT", C, -C }, { "BOTTOMRIGHT", -C, C } },
    }) do
        local t = rim:CreateTexture(nil, "BORDER")
        t:SetTexture(RIM_TEX)
        t:SetTexCoord(cuts[c[1]], cuts[c[1] + 1], cuts[c[2]], cuts[c[2] + 1])
        if c[3] > 0 then t:SetWidth(c[3]) end
        if c[4] > 0 then t:SetHeight(c[4]) end
        for i = 5, #c do t:SetPoint(c[i][1], rim, c[i][1], c[i][2], c[i][3]) end
    end
    local filigree = rim:CreateTexture(nil, "ARTWORK")
    filigree:SetTexture(RIM_TEX)
    filigree:SetTexCoord(0, 96 / 256, 216 / 256, 254 / 256)
    filigree:SetSize(48, 19)
    filigree:SetPoint("TOP", rim, "TOP", 0, 1)
end

function SidePanel.RefreshToggle()
    local c = _G.SQUARE_BUTTON_TEXCOORDS and _G.SQUARE_BUTTON_TEXCOORDS[SidePanel.frame:IsShown() and "LEFT" or "RIGHT"]
    if c then SidePanel.arrow:SetTexCoord(c[1], c[2], c[3], c[4]) end
end



function SidePanel.PlaceClose()
    local close = _G["WorldMapFrameCloseButton"]
    if not close then return end
    if not SidePanel.closeMoved then SidePanel.closeAt = { close:GetPoint(1) } end
    local at = SidePanel.closeAt
    if SidePanel.frame:IsShown() and at[2] == _G["MiniBorderRight"] then
        close:SetPoint(at[1], at[2], at[3], at[4] + SidePanel.W, at[5])
        SidePanel.closeMoved = true
    end
end

function SidePanel.ClientPlacedClose()
    SidePanel.closeMoved = false
    SidePanel.PlaceClose()
end


function SidePanel.Expand()
    local wmf = WorldMapFrame
    if not wmf:IsShown() or wmf:IsMaximized() then return false end
    local f = SidePanel.frame
    if not f:IsShown() then
        f:Show()
        _G["MiniBorderRight"]:Hide()
        SidePanel.PlaceClose()
    end
    EasyFind.db.mapSidePanelOpen = true
    SidePanel.RefreshToggle()
    return true
end

function SidePanel.Collapse()
    local f = SidePanel.frame
    if f:IsShown() then
        f:Hide()
        _G["MiniBorderRight"]:Show()
        local close = _G["WorldMapFrameCloseButton"]
        if close and SidePanel.closeMoved then close:SetPoint(unpack(SidePanel.closeAt)) end
        SidePanel.closeMoved = false
    end
    SidePanel.RefreshToggle()
end


function SidePanel.Sync()
    local wmf = WorldMapFrame
    local windowed = IsMapSearchEnabled() and not wmf:IsMaximized()
    SidePanel.toggle:SetShown(windowed)
    if not windowed then
        HideOurPanel()
        SidePanel.Collapse()
    elseif lastSelectedWasOurs and wmf:IsShown() and not selectedIsOurs then
        ShowOurPanel()
    end
end



local function CreatePanel(qmf)
    local anchor = qmf.ContentsAnchor or qmf.QuestsFrame or qmf

    local outer = CreateFrame("Frame", "EasyFindMapSearchOuter", qmf)
    outer:SetAllPoints(anchor)
    if qmf.ContentFrames then


        outer:SetFrameLevel(qmf:GetFrameLevel() + COVER_LEVEL)
        outer:EnableMouse(true)
        outer:EnableMouseWheel(true)
        outer:SetScript("OnMouseWheel", SwallowWheel)
    else
        outer:EnableMouse(false)
    end

    local p = CreateFrame("Frame", "EasyFindMapSearchPanel", outer)
    p:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -29)


    local strip = SidePanel.frame and 16 or 22
    p.barGap = SidePanel.frame and 5 or 8
    p:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -strip, 0)
    p:EnableMouse(true)
    p.outer, p.anchor = outer, anchor
    outer:Hide()


    if not SidePanel.frame then
        local paper = p:CreateTexture(nil, "BACKGROUND", nil, -1)
        paper:SetAtlas("QuestLog-main-background", true)
        paper:SetAllPoints(p)
        p.paper = paper




        local border = CreateFrame("Frame", nil, p, "QuestLogBorderFrameTemplate")
        border:SetFrameLevel(p:GetFrameLevel() + 2)


        border:EnableMouse(false)
        p.border = border
    else
        SidePanel.Paper(p)
    end

    local cog = CreateFilterCog(outer)
    cog:SetSize(15, 16)
    cog:SetPoint("TOPRIGHT", p, "TOPRIGHT", 19, 25)
    p.cog = cog



    local searchBox = CreateSearchBox(outer)
    searchBox:ClearAllPoints()


    searchBox.minHeight = 20
    searchBox.FitHeight = function()
        local _, size = searchBox:GetFont()
        local h = mmax(searchBox.minHeight, math.floor((size or 14) + 8 + 0.5))
        searchBox:SetHeight(h)
        for _, key in ipairs({ "Left", "Middle", "Right" }) do
            if searchBox[key] then searchBox[key]:SetHeight(h) end
        end
    end
    searchBox.FitHeight()

    searchBox:SetPoint("TOPLEFT", outer, "TOPLEFT", 4, SidePanel.frame and -2 or -5)
    searchBox:SetPoint("RIGHT", cog, "LEFT", -6, 0)
    p.searchBox = searchBox

    local OnFilterChanged = MapTab.FilterChanged
    local function OnFontPicked()
        MapTab.ScaleChrome(p)
        RefreshCurrentSearch()
        EasyFind.API.Fire("easyfind", "mapTextSizeChanged")
    end
    p.OnFontPicked = OnFontPicked
    cog:SetScript("OnClick", function()
        local defs = MapOptionsDefs(OnFilterChanged, OnFontPicked)
        if not ShowNativeMapOptions(cog, defs) then ns.ShowTogglePopup("EasyFindMapTabOptions", cog, defs, {}) end
    end)

    p.AlignToBlizzardSearch = function()
        local qsb = not SidePanel.frame and _G["QuestScrollFrame"] and QuestScrollFrame.SearchBox
        if not qsb then return end
        local n = qsb:GetNumPoints() or 0
        if n == 0 then return end


        searchBox:ClearAllPoints()
        for i = 1, n do
            local point, relTo, relPoint, x, y = qsb:GetPoint(i)
            if point and not point:find("RIGHT") then
                searchBox:SetPoint(point, relTo, relPoint, x, y)
            end
        end
        local w, h = qsb:GetSize()
        if h and h > 0 then searchBox.minHeight = h end
        if p.cog then
            searchBox:SetPoint("RIGHT", p.cog, "LEFT", -6, 0)
        elseif w and w > 0 then
            searchBox:SetWidth(w)
        end
        searchBox.FitHeight()
    end
    p.MeasureBlizzardSearch = p.AlignToBlizzardSearch

    local scrollFrame = CreateFrame("ScrollFrame", nil, p)
    scrollFrame:SetPoint("TOPLEFT", p, "TOPLEFT", 4, -4)

    scrollFrame:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -4, 28)
    scrollFrame:EnableMouseWheel(true)
    p.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)
    scrollFrame:HookScript("OnSizeChanged", function(_, w) scrollChild:SetWidth(w) end)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = mmax(0, scrollChild:GetHeight() - self:GetHeight())
        local cur = self:GetVerticalScroll() or 0
        local target = cur - delta * 24
        if target < 0 then target = 0 end
        if target > maxScroll then target = maxScroll end
        self:SetVerticalScroll(target)
    end)
    p.scrollChild = scrollChild

    local scrollBar = CreateFrame("EventFrame", nil, p, "MinimalScrollBar")
    scrollBar:SetFrameStrata("HIGH")
    scrollBar:SetPoint("TOPLEFT", p, "TOPRIGHT", p.barGap, 2)
    scrollBar:SetPoint("BOTTOMLEFT", p, "BOTTOMRIGHT", p.barGap, -4)
    p.scrollBar = scrollBar

    local function SyncScrollBar()
        local contentH = scrollChild:GetHeight() or 0
        local viewH = scrollFrame:GetHeight() or 0
        if scrollBar.SetVisibleExtentPercentage then
            local extent = contentH > 0 and mmin(1, viewH / contentH) or 1
            scrollBar:SetVisibleExtentPercentage(extent)
        end
        if scrollBar.SetScrollPercentage then
            local maxScroll = mmax(1, contentH - viewH)
            scrollBar:SetScrollPercentage((scrollFrame:GetVerticalScroll() or 0) / maxScroll)
        end
    end
    if scrollBar.RegisterCallback and scrollBar.Event and scrollBar.Event.OnScroll then
        scrollBar:RegisterCallback(scrollBar.Event.OnScroll, function(_, pct)
            local maxScroll = mmax(0, (scrollChild:GetHeight() or 0) - (scrollFrame:GetHeight() or 0))
            scrollFrame:SetVerticalScroll(pct * maxScroll)
        end, p)
    end
    scrollFrame:HookScript("OnSizeChanged", SyncScrollBar)
    scrollFrame:HookScript("OnVerticalScroll", SyncScrollBar)
    hooksecurefunc(scrollChild, "SetHeight", SyncScrollBar)
    p.SyncScrollBar = SyncScrollBar


    local pageBar = ns.CreateModernButton(p, "", 100, 20)
    pageBar:ClearAllPoints()
    pageBar:SetPoint("TOPLEFT", p, "TOPLEFT", 4, -4)
    pageBar:SetPoint("TOPRIGHT", p, "TOPRIGHT", -4, -4)
    pageBar:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pageBar:SetScript("OnClick", function(self, button)

        if self.pageID == false then
            if button == "LeftButton" then ShowOurPanel(false) end
            return
        end
        local def = self.pageID and pages[self.pageID]
        if not def then return end
        if button == "RightButton" then
            if def.onBarMenu then def.onBarMenu(self) end
            return
        end
        ShowOurPanel(self.pageID)
    end)


    local clearX = ns.CreateCloseX(pageBar, 12)
    clearX:SetPoint("RIGHT", pageBar, "RIGHT", -6, 0)
    clearX:Hide()
    clearX:SetScript("OnClick", function()
        local def = pageBar.pageID and pages[pageBar.pageID]
        if def and def.clear then def.clear() end
    end)
    local function HoverX()
        local def = pageBar.pageID and pages[pageBar.pageID]
        clearX:SetShown(def and def.clear and (pageBar:IsMouseOver() or clearX:IsMouseOver()) or false)
    end
    pageBar:HookScript("OnEnter", HoverX)
    pageBar:HookScript("OnLeave", function() Utils.SafeAfter(0.05, HoverX) end)
    clearX:HookScript("OnLeave", function() Utils.SafeAfter(0.05, HoverX) end)
    pageBar:Hide()
    p.pageBar = pageBar

    local emptyMsg = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyMsg:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 20, -24)
    emptyMsg:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -20, -24)
    emptyMsg:SetJustifyH("CENTER")
    emptyMsg:SetText("|cff999999" .. L["MAP_EMPTY_HINT"] .. "|r")
    p.emptyMsg = emptyMsg

    local recentCheck = CreateFrame("CheckButton", "EasyFindMapTabRecentCheck", p, "UICheckButtonTemplate")
    recentCheck:SetSize(20, 20)
    recentCheck:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 4, 4)
    recentCheck:SetHitRectInsets(0, -120, 0, 0)
    local recentLabel = recentCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    recentLabel:SetPoint("LEFT", recentCheck, "RIGHT", 2, 1)
    recentLabel:SetText(L["MAP_SHOW_RECENT"])
    recentCheck:SetScript("OnShow", function(self)
        self:SetChecked(EasyFind.db.mapTabShowRecent ~= false)
    end)
    recentCheck:SetScript("OnClick", function(self)
        EasyFind.db.mapTabShowRecent = self:GetChecked() and true or false
        RefreshCurrentSearch()
    end)
    p.recentCheck = recentCheck

    local expandCheck = CreateFrame("CheckButton", "EasyFindMapTabAutoExpandCheck", p, "UICheckButtonTemplate")
    expandCheck:SetSize(20, 20)
    expandCheck:SetPoint("LEFT", recentLabel, "RIGHT", 12, -1)
    expandCheck:SetHitRectInsets(0, -120, 0, 0)
    local expandLabel = expandCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    expandLabel:SetPoint("LEFT", expandCheck, "RIGHT", 2, 1)
    expandLabel:SetText(L["MAP_AUTO_EXPAND"])
    expandCheck:SetScript("OnShow", function(self)
        self:SetChecked(EasyFind.db.mapTabAutoExpand ~= false)
    end)
    p.recentLabel, p.expandLabel = recentLabel, expandLabel
    expandCheck:SetScript("OnClick", function(self)
        EasyFind.db.mapTabAutoExpand = self:GetChecked() and true or false
        RefreshCurrentSearch()
    end)
    expandCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText(L["MAP_AUTO_EXPAND"])
        GameTooltip:AddLine(L["MAP_AUTO_EXPAND_TT"], 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["MAP_AUTO_EXPAND_EXAMPLE"], 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    expandCheck:SetScript("OnLeave", GameTooltip_Hide)
    p.expandCheck = expandCheck


    local tip = CreateFrame("Frame", nil, p)
    tip:Hide()
    tip:SetHyperlinksEnabled(true)
    tip.text = tip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tip.text:SetPoint("TOPLEFT", tip, "TOPLEFT", 0, 0)
    tip.text:SetPoint("TOPRIGHT", tip, "TOPRIGHT", 0, 0)
    tip.text:SetJustifyH("LEFT")
    tip.text:SetWordWrap(true)
    tip:SetScript("OnHyperlinkClick", function(_, link) ns.ExtensionTipClick(link) end)
    tip:SetScript("OnHyperlinkEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["EXT_PAGE_TT"], 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    tip:SetScript("OnHyperlinkLeave", GameTooltip_Hide)
    p.extTip = tip


    function p.LayoutChecks()
        local need = 64 + recentLabel:GetUnboundedStringWidth() + expandLabel:GetUnboundedStringWidth()
        local stacked = need > p:GetWidth()
        expandCheck:ClearAllPoints()
        if stacked then
            expandCheck:SetPoint("BOTTOMLEFT", recentCheck, "TOPLEFT", 0, 2)
        else
            expandCheck:SetPoint("LEFT", recentLabel, "RIGHT", 12, -1)
        end
        local foot = stacked and 50 or 28
        local link = ns.ExtensionTipLink and ns.ExtensionTipLink("EasyFind_GPS", L["MAP_GPS_TIP_LINK"])
        tip:SetShown(link ~= nil)
        if link then
            tip.text:SetText(L["MAP_GPS_TIP_FMT"]:format(link))
            tip:ClearAllPoints()
            tip:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 8, foot)
            tip:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -8, foot)
            local h = tip.text:GetStringHeight() or 12
            tip:SetHeight(h)
            foot = foot + h + 6
        end
        p.footH = foot
        if panel == p then UpdatePageBar() end
    end
    p:HookScript("OnSizeChanged", p.LayoutChecks)
    MapTab.ScaleChrome(p)

    return p
end




function MapTab:RegisterPage(def)
    if not (def and def.id) then return end
    if not pages[def.id] then pageOrder[#pageOrder + 1] = def.id end
    pages[def.id] = def
    if initialized then
        EnsureExtraTab(def.id)
        PlaceTab()
    end
end


function MapTab:RefreshPageBar()
    UpdatePageBar()
end


function MapTab:ShowSearchView()
    if not (panel and selectedIsOurs) then return end
    SelectPage(false)
    RefreshSelectGlows()
    local sb = panel.searchBox
    self:RunSearch(sb and (sb.GetTypedText and sb:GetTypedText() or sb:GetText()) or "")
end

function MapTab:GetPageFrame(id)
    local def = pages[id]
    return def and def.frame
end

function MapTab:IsPageShowing(id)
    return selectedIsOurs and activePage == id and panel ~= nil and (panel.outer or panel):IsShown()
end


function MapTab:ShowPage(id)
    if not IsMapSearchEnabled() or not pages[id] then return false end
    if not initialized then self:Initialize() end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        ns.MapSearch.OpenMap()
        if not initialized then self:Initialize() end
    end
    if not panel then return false end
    ShowOurPanel(id)
    if not selectedIsOurs then return false end
    SafeAfter(0, function()
        if panel and not (panel.outer or panel):IsVisible() and WorldMapFrame and WorldMapFrame:IsShown() then
            ShowOurPanel(id)
        end
    end)
    return true
end

function MapTab:Focus()
    if not IsMapSearchEnabled() then return false end
    if not initialized then self:Initialize() end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        ns.MapSearch.OpenMap()
        if not initialized then self:Initialize() end
    end


    if not panel then
        MapTab._pendingFocus = true
        return false
    end
    ShowOurPanel(false)
    if not selectedIsOurs then return false end


    SafeAfter(0, function()
        if not panel then return end
        if not panel:IsShown() then ShowOurPanel(false) end
        if panel.searchBox and selectedIsOurs and panel:IsShown() then
            panel.searchBox:SetFocus()
        end
    end)
    return true
end

function MapTab:OpenWithQuery(query)
    if not IsMapSearchEnabled() then return false end
    if not initialized then self:Initialize() end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        ns.MapSearch.OpenMap()
        if not initialized then self:Initialize() end
    end

    if not panel then
        MapTab._pendingQuery = query
        return false
    end



    if panel.searchBox then
        panel.searchBox:SetText(query or "")
        panel.searchBox:ClearFocus()
    end
    ShowOurPanel(false)
    if not selectedIsOurs then return false end
    SafeAfter(0, function()
        if not panel then return end
        if not panel:IsShown() then ShowOurPanel(false) end
        if panel.searchBox and panel:IsShown() then
            if panel.searchBox:GetText() ~= (query or "") then
                panel.searchBox:SetText(query or "")
            end
            panel.searchBox:ClearFocus()
        end
    end)
    return true
end






local function TabArtInset(tab)
    local w = tab.art and tab.art:GetWidth()
    if not (w and w > 0) then return 3 end
    return (tab:GetWidth() - w) / 2 + w * 3 / 51
end

function PlaceTab()
    if not tabFrame then return end
    local qmf = _G["QuestMapFrame"]
    if not qmf then return end
    local lowest, lowestBottom
    for _, child in ipairs({ qmf:GetChildren() }) do
        if child ~= tabFrame and not child._efExtraTab and child.displayMode and child.OnEnter and child:IsShown() then
            local b = child:GetBottom()
            if b and (not lowestBottom or b < lowestBottom) then
                lowest, lowestBottom = child, b
            end
        end
    end
    tabFrame:ClearAllPoints()
    if backTab and lowest then backTab:Hide() end
    if lowest then
        tabFrame:SetPoint("TOPLEFT", lowest, "BOTTOMLEFT", 0, TAB_STACK_GAP)
    elseif qmf.QuestsTab and not qmf.QuestsTab:IsShown() then




        if not backTab then backTab = CreateBackTab(qmf) end
        backTab:ClearAllPoints()




        local wmf = _G["WorldMapFrame"]
        local nine = wmf and wmf.BorderFrame and wmf.BorderFrame.NineSlice
        local inset = (nine and nine:GetAlpha() < 0.01) and -4 or -12

        local openers = ns.SearchOpeners
        local replaced = openers and openers.Replacement and openers.Replacement("worldMap")
        local own = replaced and replaced.GetFrame("worldMap")
        if own and own:IsVisible() then



            local row = own:GetHeight() / 768 * own:GetEffectiveScale() / backTab:GetEffectiveScale()
            wmf, inset = own, -(TabArtInset(backTab) + 2 * row)
        end


        local qTop, wTop = qmf:GetTop(), wmf and wmf:GetTop()
        if qTop and wTop then
            local drop = (qTop * qmf:GetEffectiveScale() - wTop * wmf:GetEffectiveScale()) / backTab:GetEffectiveScale()
            backTab:SetPoint("TOPLEFT", wmf, "TOPRIGHT", inset, drop - 28)
        else
            backTab:SetPoint("TOPLEFT", qmf, "TOPRIGHT", -9, -28)
        end
        backTab:Show()
        tabFrame:SetPoint("TOPLEFT", backTab, "BOTTOMLEFT", 0, TAB_STACK_GAP)
    elseif qmf.MapLegendTab then
        tabFrame:SetPoint("TOPLEFT", qmf.MapLegendTab, "BOTTOMLEFT", 0, TAB_STACK_GAP)
    else
        tabFrame:SetPoint("LEFT", qmf, "RIGHT", 0, 0)
    end

    local above = tabFrame
    for i = 1, #pageOrder do
        local tab = extraTabs[pageOrder[i]]
        if tab then
            tab:ClearAllPoints()
            tab:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, TAB_STACK_GAP)
            tab:SetShown(tabFrame:IsShown())
            above = tab
        end
    end
end

function MapTab:Initialize()
    if not IsMapSearchEnabled() then
        lastSelectedWasOurs = false
        if initialized and tabFrame then tabFrame:Hide() end
        for _, extraTab in pairs(extraTabs) do extraTab:Hide() end
        if initialized and panel then
            if panel.outer then panel.outer:Hide() else panel:Hide() end
        end
        if SidePanel.frame then
            HideOurPanel()
            SidePanel.Collapse()
            SidePanel.toggle:Hide()
        end
        return
    end
    if initialized then return end
    local qmf = _G["QuestMapFrame"]
    if not (qmf and qmf.MapLegendTab) then

        qmf = SidePanel.Build()
        if not qmf then return end
    end
    initialized = true

    if SidePanel.frame then
        panel = CreatePanel(qmf)
        lastSelectedWasOurs = EasyFind.db.mapSidePanelOpen == true
    else
        tabFrame = CreateTabFrame(qmf)
        panel = CreatePanel(qmf)
        for i = 1, #pageOrder do EnsureExtraTab(pageOrder[i]) end
        PlaceTab()
    end




    local function OtherTabPicked(_, displayMode)
        if displayMode then
            lastSelectedWasOurs = false
            if selectedIsOurs then HideOurPanel() end
        end
    end
    if qmf.SetDisplayMode then hooksecurefunc(qmf, "SetDisplayMode", OtherTabPicked) end
    if LibStub then
        local ok, lwmt = pcall(LibStub, "LibWorldMapTabs", true)
        if ok and lwmt and type(lwmt.SetDisplayMode) == "function" then
            hooksecurefunc(lwmt, "SetDisplayMode", OtherTabPicked)
        end
    end




    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function()
            PlaceTab()
            SafeAfter(0, PlaceTab)
            SafeAfter(0, function()
                if panel and panel.MeasureBlizzardSearch then
                    panel.MeasureBlizzardSearch()
                end
            end)
            local function shouldRestoreEasyFindTab()
                return lastSelectedWasOurs
                    and not MapTab._pendingFocus
                    and MapTab._pendingQuery == nil
                    and IsMapSearchEnabled()
                    and not (WorldMapFrame.IsMaximized and WorldMapFrame:IsMaximized())
            end
            local function restoreEasyFindTab()
                if shouldRestoreEasyFindTab()
                   and panel
                   and WorldMapFrame and WorldMapFrame:IsShown() then
                    ShowOurPanel()
                end
            end


            if MapTab._pendingFocus then
                MapTab._pendingFocus = nil
                if panel then
                    ShowOurPanel()
                    if panel.searchBox and selectedIsOurs and panel:IsShown() then
                        panel.searchBox:SetFocus()
                    end
                end
                SafeAfter(0, function()
                    if panel then
                        ShowOurPanel()
                        if panel.searchBox and selectedIsOurs and panel:IsShown() then
                            panel.searchBox:SetFocus()
                        end
                    end
                end)
            end
            if MapTab._pendingQuery ~= nil and not MapTab._pendingFocus then
                local q = MapTab._pendingQuery
                MapTab._pendingQuery = nil
                if panel then
                    ShowOurPanel()
                    if panel.searchBox and panel:IsShown() then
                        panel.searchBox:SetText(q or "")
                        panel.searchBox:ClearFocus()
                    end
                end
                SafeAfter(0, function()
                    if panel then
                        ShowOurPanel()
                        if panel.searchBox and panel:IsShown() then
                            panel.searchBox:SetText(q or "")
                            panel.searchBox:ClearFocus()
                        end
                    end
                end)
            end
            if shouldRestoreEasyFindTab() then
                restoreEasyFindTab()
                SafeAfter(0, restoreEasyFindTab)
            end
        end)
        WorldMapFrame:HookScript("OnHide", function()
            if selectedIsOurs then
                lastSelectedWasOurs = true
                HideOurPanel()
            elseif ReleaseMapTabMemory then
                ReleaseMapTabMemory(true)
            end




            Utils.NoteSurfaceClosed("mapSearch", MapShownForSweep, TrimAfterMapSearch)
        end)
    end

    if WorldMapFrame and WorldMapFrame.IsMaximized then
        local function UpdateTabVisibility()
            if SidePanel.frame then SidePanel.Sync() return end
            if not tabFrame then return end
            if not IsMapSearchEnabled() then
                HideOurPanel()
                tabFrame:Hide()
                return
            end
            if WorldMapFrame:IsMaximized() then
                HideOurPanel()
                tabFrame:Hide()
            else
                tabFrame:Show()
                PlaceTab()
            end
        end
        hooksecurefunc(WorldMapFrame, "Maximize", UpdateTabVisibility)
        hooksecurefunc(WorldMapFrame, "Minimize", UpdateTabVisibility)
        WorldMapFrame:HookScript("OnShow", UpdateTabVisibility)
        UpdateTabVisibility()
    end



    hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
        if selectedIsOurs and panel and panel:IsShown() then
            RefreshCurrentSearch()
        end
    end)


    if MapTab._pendingFocus then
        MapTab._pendingFocus = nil
        SafeAfter(0, function() MapTab:Focus() end)
    end
    if MapTab._pendingQuery ~= nil then
        local q = MapTab._pendingQuery
        MapTab._pendingQuery = nil
        SafeAfter(0, function() MapTab:OpenWithQuery(q) end)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, addonName)
    if not IsMapSearchEnabled() then return end
    if event == "ADDON_LOADED" and addonName == "Blizzard_WorldMap" then
        SafeAfter(0, function() MapTab:Initialize() end)
    elseif event == "PLAYER_LOGIN" then
        local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_WorldMap")
        if isLoaded then SafeAfter(0, function() MapTab:Initialize() end) end
    end
end)
