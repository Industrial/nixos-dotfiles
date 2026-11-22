local _, ns = ...




local PlaceList = {}
ns.PlaceList = PlaceList

local Utils = ns.Utils
local L = ns.L
local MapUtils = ns.MapUtils
local tinsert = Utils.tinsert
local tsort = Utils.tsort
local mmin, mmax = Utils.mmin, Utils.mmax

local GOLD_COLOR = ns.GOLD_COLOR

local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local GetMapChildrenInfo = C_Map and C_Map.GetMapChildrenInfo
local GetMapInfo = C_Map and C_Map.GetMapInfo

local GetTopAncestor = MapUtils.GetTopAncestor
local GetZoneUnderAncestor = MapUtils.GetZoneUnderAncestor

local ROW_HEIGHT       = 22
local ROW_ICON_SIZE    = 17
local SECTION_HEADER_H = 22
local GROUP_HEADER_H   = 28

local HEADER_FONT = _G.Game15Font_Shadow and "Game15Font_Shadow" or "SystemFont_Shadow_Med3"


local PAGE = 25
PlaceList.PAGE = PAGE

local SetPortraitTextureFromCreatureDisplayID = _G.SetPortraitTextureFromCreatureDisplayID
local SHOW_MORE = { isShowMore = true }

local function NameLess(a, b) return a.name < b.name end
local function ZoneMapIDDesc(a, b) return (a.zoneMapID or 0) > (b.zoneMapID or 0) end

local function ScaleFont(fs, template, scale)
    local file, size, flags = _G[template]:GetFont()
    if file then fs:SetFont(file, size * scale, flags) end
end



local worldChildrenCache = {}

function PlaceList.WorldChildren(mapID)
    if not mapID or mapID == 0 then return nil end
    local cached = worldChildrenCache[mapID]
    if cached then return cached end
    local result = {}
    if not GetMapChildrenInfo then
        worldChildrenCache[mapID] = result
        return result
    end




    local children = GetMapChildrenInfo(mapID, nil, false)
    if children then
        for i = 1, #children do
            local child = children[i]
            local mt = child.mapType
            if child.name and mt
               and mt ~= Enum.UIMapType.Micro
               and mt ~= Enum.UIMapType.Orphan
               and not ns.MapUtils.IsWorldCopy(child, children, mapID) then
                result[#result + 1] = {
                    name = child.name,
                    category = "zone",
                    isZone = true,
                    zoneMapID = child.mapID,
                    zoneMapType = mt,
                    icon = ns.ZONE_ICON,
                    synthesized = true,
                }
            end
        end
    end
    tsort(result, NameLess)
    worldChildrenCache[mapID] = result
    return result
end
local GetWorldChildren = PlaceList.WorldChildren

do
    local inv = CreateFrame("Frame")
    inv:RegisterEvent("PLAYER_ENTERING_WORLD")
    inv:SetScript("OnEvent", function() worldChildrenCache = {} end)
end

function PlaceList.GroupBySharedParent(results)
    if not results or #results == 0 then return {} end
    local order, groups = {}, {}
    for i = 1, #results do
        local r = results[i]
        local rMapID = r.mapID or r.zoneMapID or r.entranceMapID or r.parentMapID
        local groupName, groupMapID = GetTopAncestor(rMapID)
        if not groupName or groupName == "" then
            order[#order + 1] = { type = "flat", data = r }
        else
            local g = groups[groupName]
            if not g then
                g = {
                    type = "group", name = groupName, items = {},
                    ancestorMapID = groupMapID, navigateData = nil,
                }
                groups[groupName] = g
                order[#order + 1] = g
            end
            if r.name == groupName then


                g.navigateData = r
            else
                g.items[#g.items + 1] = r
            end
        end
    end


    for _, e in ipairs(order) do
        if e.type == "group" and not e.navigateData and e.ancestorMapID then
            e.navigateData = {
                name = e.name,
                category = "zone",
                isZone = true,
                zoneMapID = e.ancestorMapID,
                synthesized = true,
            }
        end
    end



    for i = 1, #order do
        local e = order[i]
        if e.type == "group" and not e.navigateData and #e.items == 1 then
            order[i] = { type = "flat", data = e.items[1] }
        end
    end




    for _, e in ipairs(order) do
        if e.type == "group" and e.items and #e.items > 0 and e.ancestorMapID then
            local subgroups, subgroupOrder, looseItems = {}, {}, {}
            for _, item in ipairs(e.items) do
                local itemMapID = item.mapID or item.zoneMapID or item.entranceMapID or item.parentMapID
                local zoneName, zoneMapID = GetZoneUnderAncestor(itemMapID, e.ancestorMapID)
                if zoneName then
                    local sub = subgroups[zoneName]
                    if not sub then
                        sub = { name = zoneName, mapID = zoneMapID, items = {}, headerData = nil }
                        subgroups[zoneName] = sub
                        subgroupOrder[#subgroupOrder + 1] = sub
                    end
                    if itemMapID == zoneMapID and item.isZone and item.category == "zone" then
                        sub.headerData = item
                    else
                        sub.items[#sub.items + 1] = item
                    end
                else
                    looseItems[#looseItems + 1] = item
                end
            end
            local keptOrder = {}
            for _, sub in ipairs(subgroupOrder) do
                if #sub.items == 0 and sub.headerData then
                    looseItems[#looseItems + 1] = sub.headerData
                elseif #sub.items >= 1 then
                    if not sub.headerData then
                        sub.headerData = {
                            name = sub.name,
                            category = "zone",
                            isZone = true,
                            zoneMapID = sub.mapID,
                            synthesized = true,
                        }
                    end
                    keptOrder[#keptOrder + 1] = sub
                end
            end
            if #keptOrder > 0 then
                e.subgroups = keptOrder
                e.looseItems = looseItems
            end
        end
    end
    return order
end




function PlaceList.WorldEntries(results)
    local versionGroups
    local byName = {}
    for i = 1, #results do
        local r = results[i]
        if r and r.isZone and r.zoneMapID and r.name then
            local key = r.name:lower()
            local list = byName[key]
            if not list then list = {}; byName[key] = list end
            list[#list + 1] = r
        end
    end
    local removed = {}
    for _, list in pairs(byName) do
        if #list >= 2 then
            tsort(list, ZoneMapIDDesc)
            for j = 1, #list do removed[list[j]] = true end
            versionGroups = versionGroups or {}
            versionGroups[#versionGroups + 1] = {
                type = "version",
                name = list[1].name,
                items = list,
                navigateData = list[1],
            }
        end
    end
    if versionGroups then
        local kept = {}
        for i = 1, #results do
            if not removed[results[i]] then kept[#kept + 1] = results[i] end
        end
        results = kept
    end
    local entries = PlaceList.GroupBySharedParent(results)
    if versionGroups then
        for i = #versionGroups, 1, -1 do tinsert(entries, 1, versionGroups[i]) end
    end
    return entries, results
end


function PlaceList.FlatEntries(results)
    local entries = {}
    for i = 1, #results do entries[i] = { type = "flat", data = results[i] } end
    return entries
end



local List = {}
List.__index = List
















function PlaceList.New(scrollChild, host)
    return setmetatable({
        child = scrollChild, host = host,
        rows = {}, rowAt = 1, headers = {}, headerAt = 1, labels = {}, labelAt = 1,
        navRows = {}, collapsed = {}, limit = PAGE, height = 1, lines = 0,
    }, List)
end

function List:Scale()
    local f = self.host.fontScale
    return f and f() or 1
end

function List:Scaled(h)
    return math.floor(h * self:Scale() + 0.5)
end

local function ClearSearchFocus(list)
    local get = list.host.searchBox
    local box = get and get()
    if box and box.HasFocus and box:HasFocus() then box:ClearFocus() end
end

local function EndPreview(list)
    if list.host.endPreview then list.host.endPreview() end
end

local function RowClick(row, button)
    local list, data = row.list, row.data
    if not data then return end
    if data.isShowMore then
        list.limit = list.limit + PAGE
        list.host.refresh()
        return
    end
    list.host.click(row, button)
end

local function RowEnter(row)
    local data = row.data
    if not data or data.isShowMore then return end
    if data.isRecentSearch and row.deleteBtn then
        row.deleteBtn:Show()
        return
    end
    local host = row.list.host
    if host.preview then host.preview(data) end

    if data.soldName then
        GameTooltip:SetOwner(row, "ANCHOR_LEFT")
        GameTooltip:SetText(data.name or "", 1, 1, 1)
        GameTooltip:AddLine(L["MAP_FOUND_BY_SELLS_FMT"]:format(data.soldName), 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end
end

local function RowLeave(row)
    if row.deleteBtn and not row.deleteBtn:IsMouseOver() then row.deleteBtn:Hide() end
    EndPreview(row.list)
    GameTooltip:Hide()
end

local function CreateResultRow(list)
    local row = CreateFrame("Button", nil, list.child)
    row.list = list
    row:SetHeight(ROW_HEIGHT)



    row:RegisterForClicks("LeftButtonDown", "RightButtonUp")
    row:EnableMouse(true)
    row:HookScript("OnMouseDown", function() ClearSearchFocus(list) end)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ROW_ICON_SIZE, ROW_ICON_SIZE)
    icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.icon = icon

    local deleteBtn = Utils.CreateClearButton(row, nil)
    deleteBtn:ClearAllPoints()
    deleteBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    deleteBtn:Hide()
    deleteBtn:SetScript("OnClick", function()
        local data = row.data
        if data and data.isRecentSearch and data.query and list.host.deleteRecent then
            list.host.deleteRecent(data.query)
        end
    end)
    deleteBtn:SetScript("OnLeave", function(self)
        if not row:IsMouseOver() then self:Hide() end
    end)
    row.deleteBtn = deleteBtn

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    text:SetPoint("RIGHT", deleteBtn, "LEFT", -4, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    row.text = text



    if not (ns.Caps and ns.Caps.questLogAtlas == false) then
        row:SetHighlightAtlas("QuestLog-quest-glow-yellow")
    else

        local art = ns.ART.questlog_glow
        row:SetHighlightTexture(art.tex)
        row:GetHighlightTexture():SetTexCoord(art.coords[1], art.coords[2], art.coords[3], art.coords[4])
    end
    local hl = row:GetHighlightTexture()
    if hl then
        hl:SetBlendMode("ADD")
        hl:SetAllPoints(row)
    end

    row:SetScript("OnClick", RowClick)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    if list.host.decorate then list.host.decorate(row) end
    return row
end

function List:SetRowIcon(row, data)


    local size = self:Scaled(ROW_ICON_SIZE)
    row.icon:SetSize(size, size)
    local icon = data.icon



    if icon == nil and data.category and ns.MapSearch and ns.MapSearch.GetCategoryIcon then
        icon = ns.MapSearch.GetCategoryIcon(data.category)
    end
    Utils.SetIconTexture(row.icon, icon)

    if data.displayID and SetPortraitTextureFromCreatureDisplayID then
        SetPortraitTextureFromCreatureDisplayID(row.icon, data.displayID)
    end

    local gps = self.host.routeButton and EasyFind.API.CallAction("gps", "rowButton", row, data, size)
    row.icon:ClearAllPoints()
    if gps then
        gps:ClearAllPoints()
        gps:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.icon:SetPoint("LEFT", gps, "RIGHT", 4, 0)
    else
        row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    end
end

function List:AcquireRow()
    local row = self.rows[self.rowAt]
    if not row then
        row = CreateResultRow(self)
        self.rows[#self.rows + 1] = row
    end
    self.rowAt = self.rowAt + 1
    local s = self:Scale()
    if row.fontScale ~= s then
        row.fontScale = s
        ScaleFont(row.text, "GameFontNormal", s)
        row:SetHeight(self:Scaled(ROW_HEIGHT))
    end
    row:EnableMouse(true)
    if row.UnlockHighlight then row:UnlockHighlight() end
    if row.deleteBtn then row.deleteBtn:Hide() end
    return row
end

local function CreateSectionLabel(parent)
    local hdr = CreateFrame("Frame", nil, parent)
    hdr:SetHeight(SECTION_HEADER_H)
    local fs = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER", hdr, "CENTER", 0, 0)
    fs:SetTextColor(Utils.RGB(GOLD_COLOR))
    hdr.label = fs
    local lineLeft = hdr:CreateTexture(nil, "ARTWORK")
    lineLeft:SetHeight(1)
    lineLeft:SetPoint("LEFT", hdr, "LEFT", 6, 0)
    lineLeft:SetPoint("RIGHT", fs, "LEFT", -6, 0)
    lineLeft:SetColorTexture(Utils.RGB(GOLD_COLOR, 0.4))
    local lineRight = hdr:CreateTexture(nil, "ARTWORK")
    lineRight:SetHeight(1)
    lineRight:SetPoint("LEFT", fs, "RIGHT", 6, 0)
    lineRight:SetPoint("RIGHT", hdr, "RIGHT", -6, 0)
    lineRight:SetColorTexture(Utils.RGB(GOLD_COLOR, 0.4))
    return hdr
end

function List:AcquireSectionLabel(labelText)
    local hdr = self.labels[self.labelAt]
    if not hdr then
        hdr = CreateSectionLabel(self.child)
        self.labels[#self.labels + 1] = hdr
    end
    self.labelAt = self.labelAt + 1
    hdr.label:SetText(labelText or "")
    local s = self:Scale()
    if hdr.fontScale ~= s then
        hdr.fontScale = s
        ScaleFont(hdr.label, "GameFontNormalSmall", s)
        hdr:SetHeight(self:Scaled(SECTION_HEADER_H))
    end
    return hdr
end











local MAP_SKIN = { toggleBg = true }
PlaceList.MapSkin = MAP_SKIN




local BAND_CAP = 20
local function PlaceBandCaps(hdr)
    local capW = BAND_CAP / 44 * (hdr:GetHeight() or GROUP_HEADER_H)
    for _, t in ipairs({ hdr.bgL, hdr.bgR, hdr.hoverL, hdr.hoverR }) do t:SetWidth(capW) end
end

local function BandCaps(hdr)
    if hdr.bgL then return end
    local function Cap(layer, sub, side)
        local t = hdr:CreateTexture(nil, layer, nil, sub)
        t:SetPoint("TOP" .. side)
        t:SetPoint("BOTTOM" .. side)
        return t
    end
    hdr.bgL, hdr.bgR = Cap("BACKGROUND", 0, "LEFT"), Cap("BACKGROUND", 0, "RIGHT")
    hdr.hoverL, hdr.hoverR = Cap("ARTWORK", -1, "LEFT"), Cap("ARTWORK", -1, "RIGHT")
    hdr.hoverL:SetBlendMode("ADD")
    hdr.hoverR:SetBlendMode("ADD")
    hdr.hoverL:Hide()
    hdr.hoverR:Hide()
    hdr:HookScript("OnSizeChanged", PlaceBandCaps)
end

local function HideBandCaps(hdr)
    if not hdr.bgL then return end
    for _, t in ipairs({ hdr.bgL, hdr.bgR, hdr.hoverL, hdr.hoverR }) do t:Hide() end
end
PlaceList.HideBandCaps = HideBandCaps

function MAP_SKIN.paint(hdr)
    local bg, hover = hdr.bg, hdr.hoverOverlay
    bg:ClearAllPoints()
    bg:SetAllPoints()
    hover:ClearAllPoints()
    hover:SetBlendMode("ADD")
    if not (ns.Caps and ns.Caps.questLogAtlas == false) then
        HideBandCaps(hdr)
        bg:SetAtlas("QuestLog-tab")
        hover:SetAllPoints()
        hover:SetAtlas("QuestLog-tab")
        hover:SetAlpha(0.40)
        hdr.fill:Hide()
    else


        local art, u, v = ns.ART.questlog_tab, BAND_CAP / 128, ns.ART.questlog_tab.coords[4]
        BandCaps(hdr)
        for _, t in ipairs({ bg, hover, hdr.bgL, hdr.bgR, hdr.hoverL, hdr.hoverR }) do t:SetTexture(art.tex) end
        hdr.bgL:SetTexCoord(0, u, 0, v)
        hdr.hoverL:SetTexCoord(0, u, 0, v)
        hdr.bgR:SetTexCoord(1 - u, 1, 0, v)
        hdr.hoverR:SetTexCoord(1 - u, 1, 0, v)
        bg:SetTexCoord(u, 1 - u, 0, v)
        hover:SetTexCoord(u, 1 - u, 0, v)
        bg:ClearAllPoints()
        bg:SetPoint("TOPLEFT", hdr.bgL, "TOPRIGHT")
        bg:SetPoint("BOTTOMRIGHT", hdr.bgR, "BOTTOMLEFT")
        hover:SetPoint("TOPLEFT", hdr.hoverL, "TOPRIGHT")
        hover:SetPoint("BOTTOMRIGHT", hdr.hoverR, "BOTTOMLEFT")
        hover:SetAlpha(0.40)
        hdr.hoverL:SetAlpha(0.40)
        hdr.hoverR:SetAlpha(0.40)
        hdr.bgL:Show()
        hdr.bgR:Show()
        PlaceBandCaps(hdr)
        hdr.fill:Hide()
    end
    bg:Show()
    local t = hdr.toggleBtn
    t:SetSize(26, 25)
    t.icon:SetSize(18, 17)
    t.icon:SetAlpha(1)
    t.btnBg:SetTexture(796424)
    t.btnBg:SetVertexColor(1, 1, 1, 1)
    t:SetHighlightTexture(130757)
end

function MAP_SKIN.toggle(icon, collapsed)
    ns.SetQuestLogToggle(icon, collapsed)
end

function MAP_SKIN.hover(hdr, on)
    hdr.hoverOverlay:SetShown(on)
    if hdr.hoverL and hdr.bgL:IsShown() then
        hdr.hoverL:SetShown(on)
        hdr.hoverR:SetShown(on)
    end
end

function MAP_SKIN.color(hdr, hover)
    if hover then return 0.90, 0.88, 0.85 end
    if hdr._matchColor then return GOLD_COLOR[1], GOLD_COLOR[2], GOLD_COLOR[3] end
    return 0.60, 0.58, 0.55
end

local function Skin(list)
    local get = list.host.headerSkin
    return get and get() or MAP_SKIN
end

local function HeaderHover(hdr, on)
    local skin = hdr.skin
    if skin.hover then skin.hover(hdr, on) else hdr.hoverOverlay:SetShown(on) end
    hdr.label:SetTextColor(skin.color(hdr, on))
end

local function ToggleHover(hdr, on)
    local skin, t = hdr.skin, hdr.toggleBtn
    if skin.toggleHover then
        skin.toggleHover(t, on)
    else
        t.btnBg:SetShown(on and skin.toggleBg or false)
    end
end

local function CreateGroupHeader(list)
    local hdr = CreateFrame("Button", nil, list.child)
    hdr:SetHeight(GROUP_HEADER_H)

    hdr:RegisterForClicks("LeftButtonDown", "RightButtonUp")
    hdr:HookScript("OnMouseDown", function() ClearSearchFocus(list) end)

    hdr.bg = hdr:CreateTexture(nil, "BACKGROUND")
    hdr.fill = hdr:CreateTexture(nil, "BACKGROUND", nil, 1)
    hdr.fill:SetPoint("TOPLEFT", 1, -1)
    hdr.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    hdr.hoverOverlay = hdr:CreateTexture(nil, "ARTWORK", nil, -1)
    hdr.hoverOverlay:Hide()

    local toggleBtn = CreateFrame("Button", nil, hdr)
    toggleBtn:SetPoint("RIGHT", hdr, "RIGHT", -8, 0)
    toggleBtn:SetFrameLevel(hdr:GetFrameLevel() + 2)
    toggleBtn:RegisterForClicks("LeftButtonDown")
    toggleBtn:HookScript("OnMouseDown", function() ClearSearchFocus(list) end)
    toggleBtn:SetHitRectInsets(-10, -10, -6, -6)
    local toggleBtnBg = toggleBtn:CreateTexture(nil, "ARTWORK")
    toggleBtnBg:SetAllPoints()
    toggleBtnBg:SetTexture(796424)
    toggleBtnBg:Hide()
    toggleBtn.btnBg = toggleBtnBg
    local toggleIcon = toggleBtn:CreateTexture(nil, "OVERLAY")
    toggleIcon:SetPoint("CENTER")
    toggleBtn.icon = toggleIcon
    toggleBtn:SetScript("OnEnter", function()
        ToggleHover(hdr, true)
        HeaderHover(hdr, true)
    end)
    toggleBtn:SetScript("OnLeave", function()
        ToggleHover(hdr, false)
        if not hdr:IsMouseOver() then
            HeaderHover(hdr, false)
            EndPreview(list)
        end
    end)
    hdr.toggleBtn = toggleBtn

    local fs = hdr:CreateFontString(nil, "OVERLAY", HEADER_FONT)
    fs:SetPoint("LEFT", hdr, "LEFT", 10, 0)
    fs:SetPoint("RIGHT", toggleBtn, "LEFT", -4, 0)
    fs:SetJustifyH("LEFT")
    fs:SetMaxLines(1)
    hdr.label = fs

    hdr:SetScript("OnEnter", function(self)
        HeaderHover(self, true)
        if self.navigateData and list.host.preview then list.host.preview(self.navigateData) end
    end)
    hdr:SetScript("OnLeave", function(self)
        if not self.toggleBtn:IsMouseOver() then
            HeaderHover(self, false)
            EndPreview(list)
        end
    end)

    return hdr
end



function List:AcquireGroupHeader(labelText, groupKey, collapsed, navigateData, hasChildren, onToggle, onRightClick)
    local hdr = self.headers[self.headerAt]
    if not hdr then
        hdr = CreateGroupHeader(self)
        self.headers[#self.headers + 1] = hdr
    end
    self.headerAt = self.headerAt + 1
    hdr.label:SetText(labelText or "")
    local skin = Skin(self)
    if hdr.skin ~= skin then
        hdr.skin = skin
        if skin ~= MAP_SKIN then HideBandCaps(hdr) end
        skin.paint(hdr)
        hdr.fontScale = nil
    end
    local s = self:Scale()
    if hdr.fontScale ~= s then
        hdr.fontScale = s
        if skin.setFont then skin.setFont(hdr.label, s) else ScaleFont(hdr.label, HEADER_FONT, s) end
        hdr:SetHeight(self:Scaled(GROUP_HEADER_H))
    end
    skin.toggle(hdr.toggleBtn.icon, collapsed)
    hdr.toggleBtn:SetShown(hasChildren and true or false)
    hdr.groupKey = groupKey
    hdr.navigateData = navigateData
    hdr._matchColor = navigateData ~= nil
    hdr.label:SetTextColor(skin.color(hdr, false))
    local list = self
    hdr.toggleBtn:SetScript("OnClick", function()
        if onToggle then
            onToggle()
        elseif hdr.groupKey then
            list.collapsed[hdr.groupKey] = not list.collapsed[hdr.groupKey]
            list.host.refresh()
        end
    end)
    hdr:SetScript("OnClick", function(header, button)
        if header.toggleBtn and header.toggleBtn:IsMouseOver() then return end
        if button == "RightButton" then
            if onRightClick then onRightClick() end
            return
        end
        if header.navigateData and list.host.headerClick then list.host.headerClick(header.navigateData) end
    end)
    return hdr
end


function List:Clear()
    self.rowAt, self.headerAt, self.labelAt = 1, 1, 1
    for i = 1, #self.rows do self.rows[i]:Hide(); self.rows[i].data = nil end
    for i = 1, #self.headers do self.headers[i]:Hide() end
    for i = 1, #self.labels do self.labels[i]:Hide() end
    wipe(self.navRows)
    self.lines = 0
end


function List:Begin(query)
    if query == self.query then return end
    self.query = query
    wipe(self.collapsed)
    self.limit = PAGE
end

local function DetachFrame(frame)
    if frame and frame.SetParent then pcall(frame.SetParent, frame, nil) end
end


function List:Trim(rowsKept, headersKept, labelsKept)
    self:Clear()
    for _, pool in ipairs({ { self.rows, rowsKept }, { self.headers, headersKept }, { self.labels, labelsKept } }) do
        local frames, keep = pool[1], pool[2]
        for i = #frames, keep + 1, -1 do
            local f = frames[i]
            f:Hide()
            f.data, f.navigateData, f.groupKey = nil, nil, nil
            DetachFrame(f)
            frames[i] = nil
        end
    end
end





function List:Render(args)
    self:Begin(args.query)
    self.args = args
    local host = self.host
    local pinned, recentList = args.pinned, args.recent
    local localEntries, globalEntries = args.localEntries, args.globalEntries
    self:Clear()
    if host.beforeRender then
        host.beforeRender((pinned and #pinned > 0) or (localEntries and #localEntries > 0)
            or (globalEntries and #globalEntries > 0) or (recentList and #recentList > 0))
    end
    local scrollChild = self.child
    local navRows = self.navRows
    local pad = host.pad or 4
    local y = pad
    local collapsedDb = self.collapsed
    local limit = self.limit
    local placed = 0
    local list = self
    local autoExpand = not host.autoExpand or host.autoExpand()

    local function placeAt(frame, indent, h)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", pad + (indent or 0), -y)
        frame:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -pad, -y)
        frame:Show()
        y = y + list:Scaled(h)
    end

    local function placeRow(data, indent, groupName)
        local row = list:AcquireRow()
        row.data = data
        navRows[#navRows + 1] = row
        list:SetRowIcon(row, data)
        row.icon:Show()
        if data.isZone then
            row.text:SetTextColor(Utils.RGB(GOLD_COLOR))
        else
            row.text:SetTextColor(1, 1, 1)
        end
        local pathText = data.pathPrefix or ""
        if groupName and pathText ~= "" then
            local prefix = groupName .. " > "
            if pathText:sub(1, #prefix) == prefix then
                pathText = pathText:sub(#prefix + 1)
            elseif pathText == groupName then
                pathText = ""
            end
        end
        if pathText ~= "" then
            local last = pathText:match("[^>]+$")
            if last then pathText = last:gsub("^%s+", ""):gsub("%s+$", "") end
        end

        if pathText == "" and not groupName and not data.isZone and GetMapInfo then
            local id = data.mapID or data.zoneMapID
            local info = id and GetMapInfo(id)
            if info and info.name and info.name ~= data.name then pathText = info.name end
        end

        if data.matchNote then pathText = data.matchNote end
        if pathText ~= "" then
            row.text:SetText((data.name or "") .. "  |cff808080" .. pathText .. "|r")
        else
            row.text:SetText(data.name or "")
        end
        if host.fill then host.fill(row, data) end
        placeAt(row, indent, ROW_HEIGHT)
    end


    local function placePlace(data, indent, groupName)
        placed = placed + 1
        if placed <= limit then placeRow(data, indent, groupName) end
    end


    local function placeLine(data, text, r, g, b)
        local row = list:AcquireRow()
        row.data = data
        if data then navRows[#navRows + 1] = row else row:EnableMouse(false) end
        row.icon:Hide()
        if row.gpsBtn then row.gpsBtn:Hide() end
        row.text:SetTextColor(r, g, b)
        row.text:SetText(text)
        if host.fill then host.fill(row, nil) end
        placeAt(row, 0, ROW_HEIGHT)
    end

    local function placeSectionLabel(text)
        placeAt(list:AcquireSectionLabel(text), 0, SECTION_HEADER_H)
    end

    local function placeGroupHeader(name, groupKey, collapsed, navigateData, hasChildren, onToggle, onRightClick, indent)
        local hdr = list:AcquireGroupHeader(name, groupKey, collapsed, navigateData, hasChildren, onToggle, onRightClick)
        if hdr.hoverOverlay then hdr.hoverOverlay:Hide() end
        navRows[#navRows + 1] = hdr
        placeAt(hdr, indent, GROUP_HEADER_H)
    end


    local function placeCountedHeader(...)
        if placed < limit then placeGroupHeader(...) end
    end

    local function headerMenu(navigateData, capturedCollapsed)
        if host.headerMenu then
            return function() host.headerMenu(navigateData, capturedCollapsed) end
        end
    end

    local function renderEntries(entries, sectionKey)
        for _, e in ipairs(entries) do
            if e.type == "flat" then
                placePlace(e.data, 0, nil)
            elseif e.type == "version" then



                local groupKey = sectionKey .. ":version:" .. e.name
                local collapsed = collapsedDb[groupKey] ~= false
                local capturedCollapsed = collapsed
                local onToggle = function()
                    collapsedDb[groupKey] = not capturedCollapsed and true or false
                    host.refresh()
                end
                local nav = e.navigateData
                placeCountedHeader(e.name, groupKey, collapsed, nav, true, onToggle, nav and headerMenu(nav, capturedCollapsed))
                if not collapsed then
                    for _, item in ipairs(e.items) do placePlace(item, 18, nil) end
                end
            else
                local groupKey = sectionKey .. ":" .. e.name
                local collapsed = collapsedDb[groupKey] == true





                local items
                local usingWorldChildren = false
                local parentMatched = e.navigateData and not e.navigateData.synthesized
                if parentMatched and e.ancestorMapID and autoExpand then
                    local world = GetWorldChildren(e.ancestorMapID)
                    items = world or e.items
                    usingWorldChildren = world and #world > 0
                else
                    items = e.items
                end
                local hasChildren = items and #items > 0
                local nav = e.navigateData
                placeCountedHeader(e.name, groupKey, collapsed, nav, hasChildren, nil, nav and headerMenu(nav, collapsed))
                if hasChildren and not collapsed then
                    if not usingWorldChildren and e.subgroups then
                        for _, sub in ipairs(e.subgroups) do
                            local subKey = groupKey .. ":" .. sub.name
                            local subCollapsed = collapsedDb[subKey] == true
                            local subHasChildren = #sub.items > 0
                            local subNav = sub.headerData
                            placeCountedHeader(sub.name, subKey, subCollapsed, subNav,
                                subHasChildren, nil, subNav and headerMenu(subNav, subCollapsed), 18)
                            if subHasChildren and not subCollapsed then
                                for _, item in ipairs(sub.items) do placePlace(item, 36, sub.name) end
                            end
                        end
                        if e.looseItems then
                            for _, item in ipairs(e.looseItems) do placePlace(item, 18, e.name) end
                        end
                    else





                        local byName, order = {}, {}
                        for _, item in ipairs(items) do
                            local n = item.name or ""
                            local variants = byName[n]
                            if not variants then
                                variants = {}
                                byName[n] = variants
                                order[#order + 1] = n
                            end
                            variants[#variants + 1] = item
                        end
                        for _, n in ipairs(order) do
                            local variants = byName[n]
                            if #variants == 1 then
                                placePlace(variants[1], 18, e.name)
                            else
                                tsort(variants, ZoneMapIDDesc)
                                local subKey = groupKey .. ":var:" .. n
                                local subCollapsed = collapsedDb[subKey] ~= false
                                local subCaptured = subCollapsed
                                local subToggle = function()
                                    collapsedDb[subKey] = not subCaptured and true or false
                                    host.refresh()
                                end
                                local subNav = variants[1]
                                placeCountedHeader(n, subKey, subCollapsed, subNav,
                                    true, subToggle, headerMenu(subNav, subCaptured), 18)
                                if not subCollapsed then
                                    for _, variant in ipairs(variants) do


                                        placePlace({
                                            name = variant.name,
                                            category = variant.category,
                                            isZone = variant.isZone,
                                            zoneMapID = variant.zoneMapID,
                                            zoneMapType = variant.zoneMapType,
                                            icon = variant.icon,
                                            synthesized = variant.synthesized,
                                            pathPrefix = "map #" .. tostring(variant.zoneMapID),
                                        }, 36, n)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if recentList and #recentList > 0 then
        placeSectionLabel(L["MAP_SECTION_RECENT_SEARCHES"])
        for _, query in ipairs(recentList) do
            local row = self:AcquireRow()
            navRows[#navRows + 1] = row
            row.data = {
                isRecentSearch = true,
                query = query,
                name = query,
                icon = { file = ns.SEARCH_ICON_TEX, coords = ns.SEARCH_ICON_COORDS },
            }
            self:SetRowIcon(row, row.data)
            row.icon:Show()
            row.text:SetTextColor(0.85, 0.85, 0.85)
            row.text:SetText(query)
            local textH = row.text:GetStringHeight() or 0
            if textH < 8 then textH = 12 end
            row.icon:SetSize(textH, textH)
            if host.fill then host.fill(row, nil) end
            placeAt(row, 0, ROW_HEIGHT)
        end
    end
    if pinned and #pinned > 0 then
        placeSectionLabel(L["HEADER_PINNED"])
        for _, d in ipairs(pinned) do
            local renderAsParent = d.isZone and d.zoneMapID
            local children = renderAsParent and GetWorldChildren(d.zoneMapID) or nil
            if renderAsParent and children and #children > 0 then
                local pinRef = d
                local collapsed = pinRef.collapsed == true
                local onToggle = function()
                    pinRef.collapsed = not collapsed
                    host.refresh()
                end
                placeGroupHeader(pinRef.name, "pinned:" .. pinRef.zoneMapID,
                    collapsed, pinRef, true, onToggle, headerMenu(pinRef, collapsed))
                if not collapsed then
                    for _, child in ipairs(children) do placeRow(child, 18, pinRef.name) end
                end
            else
                placeRow(d, 0, nil)
            end
        end
    end
    if localEntries and #localEntries > 0 then
        if args.localLabel then placeSectionLabel(args.localLabel) end
        renderEntries(localEntries, "local")
    end
    if globalEntries and #globalEntries > 0 then
        if args.globalLabel then placeSectionLabel(args.globalLabel) end
        renderEntries(globalEntries, "global")
    end
    if placed > limit then
        placeLine(SHOW_MORE, L["MAP_SHOW_MORE_FMT"]:format(mmin(PAGE, placed - limit)), 0.85, 0.85, 0.85)
    elseif placed == 0 and args.emptyText and not (pinned and #pinned > 0) and not (recentList and #recentList > 0) then
        placeLine(nil, args.emptyText, ns.TEXT_DIM[1], ns.TEXT_DIM[2], ns.TEXT_DIM[3])
    end
    self.height = mmax(1, y + pad)
    self.lines = self.rowAt - 1 + self.headerAt - 1
    scrollChild:SetHeight(self.height)
end


function List:Redraw()
    if self.args then self:Render(self.args) end
end


function List:FirstPlaceRow()
    for i = 1, #self.navRows do
        local f = self.navRows[i]
        if f.data and not f.data.isShowMore and not f.data.isRecentSearch then return f end
    end
end
