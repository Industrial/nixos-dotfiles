local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns then return end
local Store = ns.ClipboardStore
local Clipboard = ns.Clipboard
if not (Store and Clipboard) then return end










local Pane = {}
Clipboard.Pane = Pane

local Utils = ns.Utils
local L = ns.L
local Search = ns.Search
local sformat = Utils.sformat
local smatch = Utils.smatch
local sgsub = string.gsub
local sgmatch = string.gmatch
local mmax = Utils.mmax or math.max
local mmin = Utils.mmin or math.min
local mfloor = Utils.mfloor or math.floor
local date = date
local time = time
local CreateFrame = CreateFrame
local strlenutf8 = strlenutf8
local GameTooltip = GameTooltip
local UIParent = UIParent
local C_Map = C_Map

local PANE_W = 300
local PANE_MIN_H = 260
local GAP = 6
local PAD = 12
local BODY_MAX = 4000
local CONTENT_MAX_H = 220
local INFO_ROW_H = 20
local SECTION_GAP = 12

local pane
local currentID

local function Theme()
    return ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
end

local function Paint(self)
    local theme = Theme()
    local light = theme and theme.lightTheme
    self.title:SetTextColor(ns.TooltipTextColor())
    local body = light and theme.leafColor or ns.TEXT_PRIMARY
    local dim = light and (theme.textFaint or theme.leafColor) or ns.TEXT_DIM
    self.body:SetTextColor(body[1], body[2], body[3], 1)
    self.hint:SetTextColor(dim[1], dim[2], dim[3], 1)
    for i = 1, #self.rows do
        self.rows[i].label:SetTextColor(dim[1], dim[2], dim[3], 1)
        self.rows[i].value:SetTextColor(body[1], body[2], body[3], 1)
    end
    local shadow = light and 0 or 1
    self.title:SetShadowColor(0, 0, 0, shadow)
    self.body:SetShadowColor(0, 0, 0, shadow)
    local rule = light and 0.15 or 0.45
    self.rule:SetColorTexture(1, 1, 1, rule * 0.35)
    for i = 1, #self.rows do
        self.rows[i].rule:SetColorTexture(1, 1, 1, rule * 0.18)
    end
end

local function EnsurePane()
    if pane then return pane end
    local parent = Search and Search.GetSearchFrame and Search:GetSearchFrame() or UIParent
    pane = CreateFrame("Frame", "EasyFindClipboardPane", parent, "BackdropTemplate")
    pane._efEmbedsTooltip = true
    pane:SetFrameStrata("LOW")
    pane:SetClampedToScreen(true)
    pane:SetSize(PANE_W, PANE_MIN_H)
    ns.StyleMenuPanel(pane)


    Utils.RegisterClickGuard(pane)


    pane:HookScript("OnHide", function(self)
        if GameTooltip and GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
            GameTooltip:SetScale(1)
        end
    end)

    local function Text(fontObject, justifyV)
        local fs = pane:CreateFontString(nil, "OVERLAY", fontObject)
        fs._efOwnColor = true
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV(justifyV or "TOP")
        fs:SetWordWrap(true)
        fs:SetNonSpaceWrap(false)
        return fs
    end

    pane.title = Text("GameFontNormal")
    pane.title:SetPoint("TOPLEFT", pane, "TOPLEFT", PAD, -PAD)
    pane.title:SetPoint("RIGHT", pane, "RIGHT", -PAD, 0)
    pane.title:SetWordWrap(false)



    local scroll = CreateFrame("ScrollFrame", nil, pane)
    scroll:SetPoint("TOPLEFT", pane.title, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("RIGHT", pane, "RIGHT", -PAD, 0)
    scroll:SetHeight(CONTENT_MAX_H)
    scroll:EnableMouseWheel(true)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(PANE_W - PAD * 2, 1)
    scroll:SetScrollChild(child)
    pane.scroll, pane.scrollChild = scroll, child
    pane.body = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pane.body._efOwnColor = true
    pane.body:SetJustifyH("LEFT")
    pane.body:SetJustifyV("TOP")
    pane.body:SetWordWrap(true)
    pane.body:SetNonSpaceWrap(true)
    pane.body:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    pane.body:SetWidth(PANE_W - PAD * 2)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = mmax(0, child:GetHeight() - self:GetHeight())
        local cur = self:GetVerticalScroll()
        self:SetVerticalScroll(mmin(range, mmax(0, cur - delta * 40)))
    end)

    pane.rule = pane:CreateTexture(nil, "ARTWORK")
    pane.rule:SetHeight(1)


    pane.rows = {}
    for i = 1, 8 do
        local row = {}
        row.label = Text("GameFontHighlightSmall", "MIDDLE")
        row.label:SetHeight(INFO_ROW_H)
        row.value = Text("GameFontHighlightSmall", "MIDDLE")
        row.value:SetJustifyH("RIGHT")
        row.value:SetWordWrap(false)
        row.value:SetHeight(INFO_ROW_H)
        row.rule = pane:CreateTexture(nil, "ARTWORK")
        row.rule:SetHeight(1)
        pane.rows[i] = row
    end

    pane.hint = Text("GameFontHighlightSmall")

    pane._efOnThemeRestyle = Paint
    Paint(pane)
    pane:Hide()
    return pane
end

local KIND_KEY = {
    link = "CLIP_KIND_LINK", eflink = "CLIP_KIND_EFLINK", mappin = "CLIP_KIND_MAPPIN",
    url = "CLIP_KIND_URL", number = "CLIP_KIND_NUMBER", command = "CLIP_KIND_COMMAND",
    text = "CLIP_KIND_TEXT",
}

local function SourceText(entry)
    if entry.source == Store.SOURCE.CHAT then
        local who = entry.sender or ""
        if entry.channel and entry.channel ~= "" then
            return who ~= "" and sformat(L["CLIP_PANE_FROM_IN"], who, entry.channel) or entry.channel
        end
        return who ~= "" and who or L["CLIP_PANE_CHAT"]
    elseif entry.source == Store.SOURCE.PASTED then
        return L["CLIP_PASTED"]
    end
    return L["CLIP_COPIED"]
end

local function CountWords(s)
    local n = 0
    for _ in sgmatch(s, "%S+") do n = n + 1 end
    return n
end


local function MapPinText(link)
    local mapID, x, y = smatch(link, "|Hworldmap:(%d+):(%d+):(%d+)")
    if not mapID then return nil end
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(tonumber(mapID))
    local name = info and info.name or ("#" .. mapID)
    return sformat("%s  %.1f, %.1f", name, tonumber(x) / 100, tonumber(y) / 100)
end

local function BodyText(entry)
    if entry.kind == Store.KIND.MAPPIN and entry.link then
        return MapPinText(entry.link) or entry.link
    end
    if entry.link then return entry.link end
    local text = Utils.ClipboardSafeText(entry.text) or entry.text
    if #text > BODY_MAX then text = Store.CutBytes(text, BODY_MAX) .. "..." end
    return text
end





local function HideEmbeddedTooltip()
    if pane and GameTooltip and GameTooltip:IsOwned(pane) then
        GameTooltip:Hide()
        GameTooltip:SetScale(1)
    end
end





local compareGuarded = false
local function GuardCompare()
    if compareGuarded then return end
    compareGuarded = true
    for _, name in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2" }) do
        local tip = _G[name]
        if tip then
            tip:HookScript("OnShow", function(self)
                if pane and GameTooltip and GameTooltip:IsOwned(pane) then self:Hide() end
            end)
        end
    end
end

local function ShowEmbeddedTooltip(link)
    if not GameTooltip then return nil end
    GuardCompare()
    GameTooltip:SetOwner(pane, "ANCHOR_NONE")
    GameTooltip:SetScale(pane:GetEffectiveScale() / UIParent:GetEffectiveScale())
    GameTooltip:ClearAllPoints()


    GameTooltip:SetPoint("TOPLEFT", pane.scroll, "TOPLEFT", -8, 0)
    GameTooltip:SetMinimumWidth(PANE_W - PAD * 2 + 16)
    GameTooltip:SetHyperlink(link)
    GameTooltip:Show()
    for _, name in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2" }) do
        local tip = _G[name]
        if tip and tip:IsShown() then tip:Hide() end
    end
    if not GameTooltip:IsShown() then return nil end
    return GameTooltip:GetWidth(), GameTooltip:GetHeight()
end

function Pane:IsActive()
    return pane ~= nil and pane:IsShown()
end

local function SetRows(list)
    local rows = pane.rows
    for i = 1, #rows do
        local item = list[i]
        if item then
            rows[i].label:SetText(item[1])
            rows[i].value:SetText(item[2])
            rows[i].label:Show(); rows[i].value:Show(); rows[i].rule:Show()
        else
            rows[i].label:Hide(); rows[i].value:Hide(); rows[i].rule:Hide()
        end
    end
end



local function Layout(contentW, contentH)
    local resultsFrame = Search:GetResultsFrame()
    local width = mmax(PANE_W, contentW and (contentW + PAD * 2 - 16) or 0)
    pane:SetWidth(width)
    local innerW = width - PAD * 2
    pane.body:SetWidth(innerW)
    pane.scrollChild:SetWidth(innerW)
    if contentH then


        pane.scroll:SetHeight(mmax(1, contentH - 4))
        pane.scroll:Hide()
        pane.scroll:Show()
    else
        local textH = pane.body:GetStringHeight() + 2
        pane.scrollChild:SetHeight(mmax(1, textH))
        pane.scroll:SetHeight(mmin(CONTENT_MAX_H, mmax(18, textH)))
    end
    pane.scroll:SetVerticalScroll(0)



    pane.rule:ClearAllPoints()
    pane.rule:SetPoint("TOPLEFT", pane.scroll, "BOTTOMLEFT", 0, -SECTION_GAP)
    pane.rule:SetPoint("RIGHT", pane, "RIGHT", -PAD, 0)

    local anchor = pane.rule
    local lastRule
    for i = 1, #pane.rows do
        local row = pane.rows[i]
        if row.label:IsShown() then
            row.label:ClearAllPoints()
            row.label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, (anchor == pane.rule) and -6 or -3)
            row.value:ClearAllPoints()
            row.value:SetPoint("RIGHT", pane, "RIGHT", -PAD, 0)
            row.value:SetPoint("TOP", row.label, "TOP", 0, 0)
            row.value:SetPoint("LEFT", row.label, "RIGHT", 8, 0)
            row.rule:ClearAllPoints()
            row.rule:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
            row.rule:SetPoint("RIGHT", pane, "RIGHT", -PAD, 0)
            anchor = row.rule
            lastRule = row.rule
        end
    end

    pane.hint:ClearAllPoints()
    pane.hint:SetPoint("TOPLEFT", lastRule or pane.rule, "BOTTOMLEFT", 0, -SECTION_GAP)
    pane.hint:SetPoint("RIGHT", pane, "RIGHT", -PAD, 0)
    pane.hint:SetText(L["CLIP_PANE_HINT"])


    local top = pane:GetTop()
    local bottom = pane.hint:GetBottom()
    local needed = (top and bottom) and (top - bottom + PAD) or PANE_MIN_H
    local listH = resultsFrame and resultsFrame:GetHeight() or 0
    pane:SetHeight(mfloor(mmax(PANE_MIN_H, needed, listH) + 0.5))
end

function Pane:ShowEntry(id)
    local entry = Store:Get(id)
    if not entry then return end
    EnsurePane()
    currentID = id
    local name = entry.link and (smatch(entry.text, "^%[(.-)%]$") or entry.text) or Store.FirstLine(entry.text)
    pane.title:SetText(name or "")
    HideEmbeddedTooltip()
    local tipW, tipH
    if entry.link and entry.kind ~= Store.KIND.MAPPIN then
        tipW, tipH = ShowEmbeddedTooltip(entry.link)
    end
    if tipW then
        pane.body:SetText("")
    else
        pane.body:SetText(BodyText(entry))
    end
    local plain = Utils.ClipboardSafeText(entry.text) or entry.text or ""
    local chars = strlenutf8 and strlenutf8(plain) or #plain
    local info = {
        { L["CLIP_PANE_SOURCE"], SourceText(entry) },
        { L["CLIP_PANE_TYPE"], L[KIND_KEY[entry.kind] or "CLIP_KIND_TEXT"] },
        { L["CLIP_PANE_CHARS"], tostring(chars) },
        { L["CLIP_PANE_WORDS"], tostring(CountWords(plain)) },
    }



    local function Stamp(t) return date("%Y-%m-%d %H:%M", t) end
    if entry.copiedAt then info[#info + 1] = { L["CLIP_COPIED"], Stamp(entry.copiedAt) } end
    if entry.pastedAt then info[#info + 1] = { L["CLIP_PASTED"], Stamp(entry.pastedAt) } end
    if not (entry.copiedAt or entry.pastedAt) then
        info[#info + 1] = { L["CLIP_PANE_WHEN"], Stamp(entry.at or time()) }
    end
    if (entry.count or 1) > 1 then
        info[#info + 1] = { L["CLIP_PANE_TIMES"], tostring(entry.count) }
    end
    if entry.char then
        info[#info + 1] = { L["CLIP_PANE_CHARACTER"], (sgsub(entry.char, "%-.*$", "")) }
    end
    SetRows(info)
    Layout(tipW, tipH)
end

local function Active()
    local Filters = ns.Filters
    local qf = Filters and Filters.GetQuickFilter and Filters:GetQuickFilter()
    local resultsFrame = Search and Search.GetResultsFrame and Search:GetResultsFrame()
    return qf and qf.key == "clipboard" and resultsFrame and resultsFrame:IsShown()
end








local function KeyboardNav()
    local nav = Search.GetNavFrame and Search:GetNavFrame()
    return nav ~= nil and nav:IsKeyboardEnabled() or false
end

local function Selected()
    if not KeyboardNav() then return nil end
    local sel = Search.GetSelectedIndex and Search:GetSelectedIndex() or 0
    if sel > 0 then
        local row = ns.Results:RowFrame(sel)
        if row and row:IsShown() and row.data and row.data.clipID then return row.data.clipID end
    end
    return nil
end

local function Place()
    local resultsFrame = Search:GetResultsFrame()


    pane:SetFrameStrata(resultsFrame:GetFrameStrata())
    pane:SetFrameLevel(resultsFrame:GetFrameLevel() + 1)
    pane:ClearAllPoints()


    local k = resultsFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local paneW = pane:GetWidth() * (pane:GetEffectiveScale() / UIParent:GetEffectiveScale())
    local right = (resultsFrame:GetRight() or 0) * k
    local left = (resultsFrame:GetLeft() or 0) * k
    if right + GAP + paneW <= UIParent:GetWidth() or left - GAP - paneW < 0 then
        pane:SetPoint("TOPLEFT", resultsFrame, "TOPRIGHT", GAP, 0)
    else
        pane:SetPoint("TOPRIGHT", resultsFrame, "TOPLEFT", -GAP, 0)
    end
end



function Pane:Sync()
    if not Active() then
        if pane then HideEmbeddedTooltip(); pane:Hide() end
        return
    end
    EnsurePane()
    if not (currentID and Store:Get(currentID)) then currentID = nil end
    local id = currentID or Selected()


    Place()
    if id then
        self:ShowEntry(id)
        pane:Show()
        Place()
    else
        HideEmbeddedTooltip()
        pane:Hide()
    end
end

local function Hide()
    HideEmbeddedTooltip()
    if pane then pane:Hide() end
    currentID = nil
end




function Pane:OnRowLeave()
    if not Active() then return end
    local id = Selected()
    if not id then
        Hide()
    elseif id ~= currentID then
        Pane:ShowEntry(id)
    end
end



if ns.ResultRender and ns.ResultRender.ApplyResultsFrameLayout then
    Utils.PostHook(ns.ResultRender, "ApplyResultsFrameLayout", function() Pane:Sync() end)
end
if ns.Results and ns.Results.HideResults then
    Utils.PostHook(ns.Results, "HideResults", Hide)
end
if ns.Filters and ns.Filters.ClearQuickFilter then
    Utils.PostHook(ns.Filters, "ClearQuickFilter", Hide)
end
if ns.ResultHandlers and ns.ResultHandlers.ApplyActionHint then
    Utils.PostHook(ns.ResultHandlers, "ApplyActionHint", function(_, row)
        if row and row.data and row.data.clipID and Active() then
            Place()
            Pane:ShowEntry(row.data.clipID)
            pane:Show()
            Place()
        end
    end)
end
if ns.ResultHandlers and ns.ResultHandlers.ClearActionHint then


    Utils.PostHook(ns.ResultHandlers, "ClearActionHint", function()
        if not Active() then return end
        local id = Selected()
        if not id then
            Hide()
        elseif id ~= currentID then
            Pane:ShowEntry(id)
        end
    end)
end
