local _, ns = ...























local ResultLinks = {}
ns.ResultLinks = ResultLinks

local Utils = ns.Utils
local L = ns.L

local sformat, sgsub, smatch, ssub, sbyte, schar = string.format, string.gsub, string.match, string.sub, string.byte, string.char
local hooksecurefunc = hooksecurefunc
local InCombatLockdown = InCombatLockdown
local GetCursorPosition, GetTime = GetCursorPosition, GetTime
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local IsModifiedClick = _G["IsModifiedClick"]
local ChatEdit_InsertLink = _G["ChatEdit_InsertLink"]
local ChatEdit_GetActiveWindow = _G["ChatEdit_GetActiveWindow"]
local ChatFrame_OpenChat = _G["ChatFrame_OpenChat"]
local AddMessageEventFilter = _G["ChatFrame_AddMessageEventFilter"]
local LinkUtil = _G["LinkUtil"]

local LINK_TYPE = "easyfind"
local LINK_PREFIX = LINK_TYPE .. ":row:"
local MARKER = "EasyFind"
local MAX_NAME = 60
local MAX_MESSAGE = 255


local UNSHAREABLE_CATEGORY = { Snippet = true, Command = true }

local CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_CHANNEL", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
}



local function EncodeKey(key)
    return (sgsub(key, "[^%w:._%-]", function(c)
        return sformat("~%02X", sbyte(c))
    end))
end

local function DecodeKey(blob)
    return (sgsub(blob, "~(%x%x)", function(hex)
        return schar(tonumber(hex, 16))
    end))
end





local function IsUsableItem(itemID)
    if not itemID then return false end
    local Handlers = ns.ResultHandlers
    if Handlers and Handlers.GetItemEquipLoc and Handlers.IsRealEquipLoc
       and Handlers:IsRealEquipLoc(Handlers:GetItemEquipLoc(itemID)) then
        return true
    end
    local spell = C_Item and C_Item.GetItemSpell and C_Item.GetItemSpell(itemID)
    return spell ~= nil
end

local function IsItemRow(data)
    return data and data.itemID and (data.category == "Bag" or data.catalogItem) or false
end

local function EntryKey(data)
    if IsItemRow(data) then return "item:" .. data.itemID end


    local provider = ns.Extensions and ns.Extensions.ProviderOf and ns.Extensions.ProviderOf(data)
    if provider and provider.link then
        local ok, tail = pcall(provider.link.key, data)
        if ok and type(tail) == "string" and tail ~= "" then return provider.key .. ":" .. tail end
    end
    return ns.Aliases and ns.Aliases:GetEntryKey(data) or nil
end






local function ContainerRowFor(itemID)
    local CC = C_Container
    if not (CC and CC.GetContainerNumSlots and CC.GetContainerItemID) then return nil end
    local lastBag = (NUM_BAG_SLOTS or 4) + 1
    for bag = 0, lastBag do
        for slot = 1, (CC.GetContainerNumSlots(bag) or 0) do
            if CC.GetContainerItemID(bag, slot) == itemID then
                local info = CC.GetContainerItemInfo and CC.GetContainerItemInfo(bag, slot)
                local name = (info and info.itemName)
                    or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID))
                if not name then return nil end
                return {
                    category = "Bag", itemID = itemID, name = name, nameLower = name:lower(),
                    bagID = bag, bagSlot = slot, bagItemLink = info and info.hyperlink,
                    icon = info and info.iconFileID,
                }
            end
        end
    end
    return nil
end

local function ResolveItemKey(key)
    local itemID = tonumber(smatch(key, "^item:(%d+)$"))
    if not itemID then return nil end
    local rows = ns.Database and ns.Database.uiSearchData
    for i = 1, (rows and #rows or 0) do
        local d = rows[i]
        if d.category == "Bag" and d.itemID == itemID then return d end
    end
    return ContainerRowFor(itemID)
end
if ns.Aliases and ns.Aliases.RegisterKeyResolver then
    ns.Aliases:RegisterKeyResolver("item", ResolveItemKey)
end

local function PlainName(data)
    local name = Utils.StripMarkup and Utils.StripMarkup(data.name) or data.name
    name = name and Utils.ClipboardSafeText and Utils.ClipboardSafeText(name) or name
    if not name or name == "" then return nil end

    name = sgsub(name, "[%[%]{}]", "")
    if #name > MAX_NAME then name = ssub(name, 1, MAX_NAME) end
    return name
end


local function Shareable(data)
    if not data or data.noPin or UNSHAREABLE_CATEGORY[data.category] then return false end
    return not (data.calculatorResult or data.calculatorExpression or data.calculatorLauncher
        or data.quickFilterDef or data.searchCommand or data.nativeRun
        or data.copyText or data.createRow or data.snippetsLauncher)
end


local function ShareKey(data)
    if not Shareable(data) then return nil end



    if data.appearanceItemID then return nil end
    if IsItemRow(data) and not IsUsableItem(data.itemID) then return nil end
    return PlainName(data) and EntryKey(data) or nil
end

function ResultLinks:CanShare(data)
    return ShareKey(data) ~= nil
end



function ResultLinks:BuildShareText(data)
    local key = ShareKey(data)
    if not key then return nil end
    local name = PlainName(data)
    local text = sformat("[%s: %s]", MARKER, name)
    if key ~= "ui:" .. name then


        text = text .. sformat(" {ef:%s}", key)
    end
    if #text > MAX_MESSAGE then return nil end
    return text
end



function ResultLinks:BuildRouteText(dest)
    if not (dest and dest.mapID and dest.x and dest.y) then return nil end
    local name = PlainName({ name = dest.name }) or "?"
    local label = sformat(L["GPS_TO_FMT"], name)
    local text = sformat("[%s: %s] {ef:route:%d:%.4f:%.4f:%s}", MARKER, label, dest.mapID, dest.x, dest.y, name)
    if #text > MAX_MESSAGE then return nil end
    return text
end


local function OpenRoute(key)
    local m, x, y, name = smatch(key, "^route:(%d+):([%d.]+):([%d.]+):(.*)$")
    if not m then return false end
    EasyFind.API.CallAction("gps", "navigate", { name = name, mapID = tonumber(m), x = tonumber(x), y = tonumber(y) })
    return true
end


function ResultLinks:BuildSendRows(data)
    local text = self:BuildShareText(data)
    if not text or not ns.BuildSendLinkRows then return nil end


    return ns.BuildSendLinkRows(text, "Ctrl+Shift+C", L["EFLINK_ROW_TT_NOTE"]), text
end



local function BlueLink(key, name)
    local LC = ns.LINK_COLOR or { 0.44, 0.84, 1.0 }
    return sformat("|cff%02x%02x%02x|H%s%s|h[%s: %s]|h|r",
        LC[1] * 255, LC[2] * 255, LC[3] * 255, LINK_PREFIX, EncodeKey(key), MARKER, name)
end




local function Linkify(msg)
    if not msg or not smatch(msg, "%[" .. MARKER .. ": ") then return msg end
    msg = sgsub(msg, "%[" .. MARKER .. ": ([^%]]-)%]%s?{ef:([^}]+)}", function(name, key)
        return BlueLink(key, name)
    end)
    msg = sgsub(msg, "%[" .. MARKER .. ": ([^%]]-)%]", function(name)
        return BlueLink("ui:" .. name, name)
    end)
    return msg
end

local function ChatFilter(_, _, msg, ...)
    local out = Linkify(msg)
    if out == msg then return false end
    return false, out, ...
end












local function NeedsPad(data)
    if ns.SecureOpeners and ns.SecureOpeners.OpenKeyForData
       and ns.SecureOpeners.OpenKeyForData(data) then
        return true
    end
    return ns.ResultIcons and ns.ResultIcons.IsSecureActionResult
        and ns.ResultIcons:IsSecureActionResult(data) or false
end



local function Activate(data)
    local Handlers = ns.ResultHandlers
    if ns.ResultRows and ns.ResultRows.ActivateSettingResult
       and ns.ResultRows:ActivateSettingResult(data) then
        return
    end
    if Handlers and Handlers.SelectResult then Handlers:SelectResult(data) end
end

local resolvedCache, requested = {}, {}
local function Resolve(key)
    local hit = resolvedCache[key]
    if hit then return hit end
    local data = ns.Aliases and ns.Aliases:FindEntryByKey(key) or nil
    if not data then return nil end

    if not Shareable(data) then
        requested[key] = true
        return nil
    end
    resolvedCache[key] = data
    return data
end



local RETRY_DELAYS = { 0.5, 1.5, 3 }

local function RequestFor(key)
    if requested[key] then return end
    requested[key] = true
    if ns.Shortkeys and ns.Shortkeys.RequestProviderForRowKey then
        ns.Shortkeys.RequestProviderForRowKey(key)
    end
end





local function RelinkText(key, name)
    if not (key and name and name ~= "") then return nil end
    local text = sformat("[%s: %s]", MARKER, name)
    if key ~= "ui:" .. name then text = text .. sformat(" {ef:%s}", key) end
    if #text > MAX_MESSAGE then return nil end
    return text
end

local function InsertRelink(key, name)
    local text = RelinkText(key, name)
    if not text then return false end
    if ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then
        if ChatEdit_InsertLink and ChatEdit_InsertLink(text) then return true end
    end
    if ChatFrame_OpenChat then ChatFrame_OpenChat(text); return true end
    return false
end














local PAD_SIZE = 24




local PAD_ALIVE = 0.3


local PAD_MARGIN = 4
local pad, padKey





local tipKey, tipRect, tipWatch
local EnsureTipWatch








local function ShowLinkTip(key, data, rect)
    if not (data and GameTooltip) then return end
    tipRect = rect
    GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
    local Tooltips = ns.ResultTooltips
    local own = Tooltips and Tooltips.SetGameTooltipForResult
        and Tooltips:SetGameTooltipForResult(GameTooltip, data)
    if not own then
        GameTooltip:SetText(PlainName(data) or data.name or "", 1, 1, 1)
    end
    local Handlers = ns.ResultHandlers
    local hint = Handlers and Handlers.GetLinkHint and Handlers:GetLinkHint(data)
    if hint then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(hint, 0.5, 0.5, 0.5, true)
    end
    GameTooltip:Show()
    tipKey = key
    if EnsureTipWatch then EnsureTipWatch():Show() end
end

local function HideLinkTip()
    if tipKey == nil then return end
    tipKey, tipRect = nil, nil
    if tipWatch then tipWatch:Hide() end

    if GameTooltip and GameTooltip:IsOwned(UIParent) then GameTooltip:Hide() end
end

local function PadHide()
    if not pad then return end
    if tipKey ~= nil and tipKey == padKey then HideLinkTip() end
    pad._aliveUntil = 0
    pad._link = nil
    pad.data = nil
    padKey = nil
    if InCombatLockdown() then return end
    if ns.ResultSecureAttributes then ns.ResultSecureAttributes.Clear(pad) end
    pad:Hide()
end









local function LinkRect(region, left, bottom, width, height)
    if not (region and region.GetLeft and type(left) == "number"
            and type(bottom) == "number" and type(width) == "number"
            and type(height) == "number" and width > 0 and height > 0) then
        return nil
    end
    local rl, rb = region:GetLeft(), region:GetBottom()
    if not (rl and rb) then return nil end
    local k = region:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return { l = (rl + left) * k, b = (rb + bottom) * k, w = width * k, h = height * k }
end

local function CursorUI()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return x / s, y / s
end



local function PadPlace()
    local r = pad._link
    local w = (r and r.w and r.w > 0) and r.w or PAD_SIZE
    local h = (r and r.h and r.h > 0) and r.h or PAD_SIZE
    if h < 18 then h = 18 end
    local cx, cy = CursorUI()
    pad:SetSize(w + 2 * PAD_MARGIN, h + 2 * PAD_MARGIN)
    pad:ClearAllPoints()
    pad:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
end



local function CursorIn(r)
    if not r then return false end
    local cx, cy = CursorUI()
    return cx >= r.l - PAD_MARGIN and cx <= r.l + r.w + PAD_MARGIN
       and cy >= r.b - 8 and cy <= r.b + r.h + 8
end

local function CursorOnLink()
    return CursorIn(pad._link)
end




EnsureTipWatch = function()
    if tipWatch then return tipWatch end
    tipWatch = CreateFrame("Frame")
    tipWatch:SetScript("OnUpdate", function(self)
        if tipKey == nil then self:Hide(); return end
        if pad and pad:IsShown() and padKey == tipKey then return end
        if tipRect and not CursorIn(tipRect) then HideLinkTip() end
    end)
    tipWatch:Hide()
    return tipWatch
end








local function PadPreClick(self, mouseButton, down)
    if mouseButton ~= "LeftButton" or not down then return end
    if InCombatLockdown() then return end
    local d, SA = self.data, ns.ResultSecureAttributes
    if not (d and SA) then return end


    if IsShiftKeyDown and IsShiftKeyDown() then
        SA.Clear(self)
        self._efRelink = true
        return
    end
    SA.ApplyAtClick(self, d)
    self._efShowWhereItLives = d.macroIndex
        or (not d.professionAbility and IsControlKeyDown and IsControlKeyDown()) or nil
    if not self._efShowWhereItLives then
        self._efBarFlipped = SA.FlipBarAtPress(d) ~= nil or nil
        return
    end
    if ns.SecureOpeners and ns.SecureOpeners.OpenKeyForData(d) then return end
    if d.spellID and d.category == "Ability"
       and ns.ResultIcons and not ns.ResultIcons:IsSpellbookOnlyAbility(d) then
        SA.SwapToPanelOpen(self)
    else
        SA.Clear(self)
    end
end





local function PadPostClick(self, mouseButton, down)
    if mouseButton ~= "LeftButton" then return end
    local d, SA = self.data, ns.ResultSecureAttributes
    if not d then return end
    if self._efRelink then
        self._efRelink = nil
        if not down then return end
        InsertRelink(EntryKey(d), PlainName(d))
        PadHide()
        return
    end
    if SA and SA.ActsOnRelease(self, d) then
        if down then return end
    elseif not down then
        return
    end
    PadHide()

    if self._efBarFlipped then
        self._efBarFlipped = nil
        return
    end
    local Handlers = ns.ResultHandlers
    if not (Handlers and Handlers.SelectResult) then return end
    if self._efShowWhereItLives then Handlers._openInPlace = true end
    self._efShowWhereItLives = nil
    local handler = _G["geterrorhandler"] and _G["geterrorhandler"]() or print
    xpcall(Handlers.SelectResult, handler, Handlers, d)
    Handlers._openInPlace = nil
end

local function EnsurePad()
    if pad then return pad end
    pad = CreateFrame("Button", "EasyFindLinkPad", UIParent, "SecureActionButtonTemplate")
    pad:SetSize(PAD_SIZE, PAD_SIZE)
    pad:SetFrameStrata("TOOLTIP")
    pad:RegisterForClicks("LeftButtonDown", "LeftButtonUp")

    Utils.SafeCallMethod(pad, "SetPassThroughButtons", "RightButton", "MiddleButton")
    pad:SetScript("PreClick", PadPreClick)
    pad:SetScript("PostClick", PadPostClick)

    pad:HookScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and not InCombatLockdown() and ns.ResultSecureAttributes then
            ns.ResultSecureAttributes.ArmSteerLate(self)
        end
    end)
    pad:SetScript("OnUpdate", function(self)






        local hovering
        if self._link then
            hovering = CursorOnLink()
            if hovering then
                self._aliveUntil = GetTime() + PAD_ALIVE
                local cx, cy = CursorUI()
                self:ClearAllPoints()
                self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
            end
        else
            hovering = self:IsMouseOver()
            if hovering then self._aliveUntil = GetTime() + PAD_ALIVE end
        end



        if hovering then
            if tipKey ~= padKey and self.data then ShowLinkTip(padKey, self.data, self._link) end
        elseif tipKey ~= nil and tipKey == padKey then
            HideLinkTip()
        end
        if GetTime() > (self._aliveUntil or 0) then PadHide() end
    end)
    pad:RegisterEvent("PLAYER_REGEN_DISABLED")
    pad:SetScript("OnEvent", function() PadHide() end)
    pad:Hide()
    return pad
end

local function ArmPad(key, data, region, left, bottom, width, height)
    if InCombatLockdown() then return end
    EnsurePad()
    if padKey ~= key then
        if ns.ResultSecureAttributes then ns.ResultSecureAttributes.Clear(pad) end
        pad.data = data
        padKey = key
    end
    pad._link = LinkRect(region, left, bottom, width, height)
    pad._aliveUntil = GetTime() + PAD_ALIVE
    PadPlace()
    pad:Show()
end

local function IsOurLink(link)
    return type(link) == "string" and ssub(link, 1, #LINK_PREFIX) == LINK_PREFIX
end




local function OnLinkEnter(_, link, _, region, left, bottom, width, height)
    if not IsOurLink(link) or InCombatLockdown() then return end
    local key = DecodeKey(ssub(link, #LINK_PREFIX + 1))




    local rect = LinkRect(region, left, bottom, width, height)
    if padKey == key and pad and pad:IsShown() then
        pad._link = rect or pad._link
        pad._aliveUntil = GetTime() + PAD_ALIVE
        return
    end



    if tipKey == key and GameTooltip and GameTooltip:IsShown() and GameTooltip:IsOwned(UIParent) then
        tipRect = rect or tipRect
        return
    end
    local data = Resolve(key)
    if not data then
        RequestFor(key)
        return
    end
    ShowLinkTip(key, data, rect)
    if NeedsPad(data) then
        ArmPad(key, data, region, left, bottom, width, height)
    end
end



local function ShowItemInstead(key)
    local itemID = smatch(key, "^item:(%d+)$")
    if not itemID then return false end
    if _G["SetItemRef"] then _G["SetItemRef"]("item:" .. itemID, "[item]", "LeftButton") end
    return true
end

local function OpenKey(key, attempt)
    if OpenRoute(key) then return end
    attempt = attempt or 0
    local data = Resolve(key)
    if data then




        if NeedsPad(data) then
            ArmPad(key, data)
            return
        end
        Activate(data)
        return
    end


    if ShowItemInstead(key) then return end
    if attempt == 0 then RequestFor(key) end
    local delay = RETRY_DELAYS[attempt + 1]
    if not delay then
        if EasyFind and EasyFind.Print then EasyFind:Print(L["EFLINK_NOT_FOUND"]) end
        return
    end
    Utils.SafeAfter(delay, function() OpenKey(key, attempt + 1) end)
end



local function WrapLinkHover(frame, otherEnter, otherLeave)
    if frame._efLinkHover then return end
    frame._efLinkHover = true
    local prev = frame:GetScript("OnHyperlinkEnter") or otherEnter
    frame:SetScript("OnHyperlinkEnter", function(self, link, ...)
        if IsOurLink(link) then
            OnLinkEnter(self, link, ...)
            return
        end
        if prev then return prev(self, link, ...) end
    end)
    local prevLeave = frame:GetScript("OnHyperlinkLeave") or otherLeave
    frame:SetScript("OnHyperlinkLeave", function(self, link, ...)
        if IsOurLink(link) then



            local key = DecodeKey(ssub(link, #LINK_PREFIX + 1))
            if not (pad and pad:IsShown() and padKey == key) then
                HideLinkTip()
            end
            return
        end
        if prevLeave then return prevLeave(self, link, ...) end
    end)
end

local installed = false
function ResultLinks:Install()
    if installed then return end
    installed = true
    if AddMessageEventFilter then
        for i = 1, #CHAT_EVENTS do
            AddMessageEventFilter(CHAT_EVENTS[i], ChatFilter)
        end
    end


    if LinkUtil and LinkUtil.RegisterLinkHandler
       and not (LinkUtil.IsLinkHandlerRegistered and LinkUtil.IsLinkHandlerRegistered(LINK_TYPE)) then
        LinkUtil.RegisterLinkHandler(LINK_TYPE, function() end)
    end


    if hooksecurefunc then
        hooksecurefunc("SetItemRef", function(link, text, button)
            if not IsOurLink(link) then return end
            local key = DecodeKey(ssub(link, #LINK_PREFIX + 1))


            if (IsModifiedClick and IsModifiedClick("CHATLINK"))
               or (IsShiftKeyDown and IsShiftKeyDown()) then
                local name = text and smatch(text, "%[" .. MARKER .. ": ([^%]]-)%]")
                InsertRelink(key, name)
                return
            end
            if button == "RightButton" then
                ResultLinks:ShowLinkMenu(key, text and smatch(text, "%[" .. MARKER .. ": ([^%]]-)%]"))
                return
            end
            if InCombatLockdown() then
                if EasyFind and EasyFind.Print then EasyFind:Print(L["EFLINK_IN_COMBAT"]) end
                return
            end
            OpenKey(key)
        end)
    end







    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if cf then WrapLinkHover(cf) end
    end
end




function ResultLinks:Linkify(text)
    return Linkify(text)
end

function ResultLinks:OpenKey(key)
    OpenKey(key)
end


function ResultLinks:FirstLink(text)
    if not text then return nil end
    local name, key = smatch(text, "%[" .. MARKER .. ": ([^%]]-)%]%s?{ef:([^}]+)}")
    if name then return key, name end
    name = smatch(text, "%[" .. MARKER .. ": ([^%]]-)%]")
    if name then return "ui:" .. name, name end
    return nil
end


function ResultLinks:CreateMacro(key, name)
    if not (key and ns.Shortkeys and ns.Shortkeys.CreateMacro) then return end
    local data = Resolve(key)

    if not data and not (smatch(key, "^route:") or smatch(key, "^item:%d+$")) then
        RequestFor(key)
        if EasyFind and EasyFind.Print then EasyFind:Print(L["EFLINK_NOT_FOUND"]) end
        return
    end
    ns.Shortkeys:CreateMacro(key, data and data.name or name, data)
end


function ResultLinks:ShowLinkMenu(key, name)
    Utils.ShowCursorMenu("EasyFindLinkMenu", {
        { text = L["CTX_CREATE_MACRO"], tooltip = L["CTX_CREATE_MACRO_TT"],
          onClick = function() ResultLinks:CreateMacro(key, name) end },
    }, { strata = "TOOLTIP", level = 100, rowHeight = 22, offsetX = 4, offsetY = -4 })
end

function ResultLinks:AttachHyperlinks(frame)
    if not (frame and frame.SetHyperlinksEnabled) or frame._efLinkHover then return end
    frame:SetHyperlinksEnabled(true)

    frame._efNoteClicks = true
    WrapLinkHover(frame, function(self, link)
        if not (GameTooltip and link) then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        if pcall(GameTooltip.SetHyperlink, GameTooltip, link) then GameTooltip:Show() else GameTooltip:Hide() end
    end, function(self)


        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    frame:SetScript("OnHyperlinkClick", function(self, link, text, button)
        if IsOurLink(link) and button ~= "LeftButton" then return end


        if button == "RightButton" and IsControlKeyDown() and not IsShiftKeyDown() and not IsAltKeyDown() then
            local kind, id = tostring(link):match("^(%a+):(%d+)")
            if (kind == "item" or kind == "spell") and EasyFind.OpenObjectNote then
                EasyFind:OpenObjectNote(kind, tonumber(id), type(text) == "string" and text:match("%[(.-)%]") or nil)
                return
            end
        end
        if _G["SetItemRef"] then _G["SetItemRef"](link, text, button, self) end
    end)
end

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    ResultLinks:Install()
end)

return ResultLinks
