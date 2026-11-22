local _, chatNS = ...

local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not (ns and ns.Utils) or chatNS.tooOld then return end

-- A chat's pinned messages: a message's menu pins it (msg.pinned, and
-- msg.pinnedAt for the order); the header's pin lists the open chat's
-- pins, newest first, each with Jump. Trims keep pinned messages.
local Pins = {}
chatNS.Pins = Pins

local UI = chatNS.UI
local Utils = ns.Utils
local CreateFrame = CreateFrame
local time = time
local tsort, wipe = table.sort, wipe
local mmax, mmin = Utils.mmax, Utils.mmin
local mceil = math.ceil

local PIN_TEX = "Interface\\AddOns\\EasyFind_Chat\\textures\\chat-pin"
Pins.TEXTURE = PIN_TEX
local PAD, ENTRY_PAD, TITLE_H, BAR_ROOM = 10, 6, 18, 10
local MIN_W, MAX_W, MAX_H = 220, 320, 320
local TEXT_LINES = 3

local popout, scroll, child, bar, title
local entries, list = {}, {}

local function ChatDB()
    EasyFindChatDB = type(EasyFindChatDB) == "table" and EasyFindChatDB or {}
    return EasyFindChatDB
end

function Pins:Enabled() return ChatDB().pins ~= false end

local function Convo(key)
    return key and UI:GetChatConversationStore().byKey[key] or nil
end

local function ByPinTime(a, b) return (a.pinnedAt or 0) > (b.pinnedAt or 0) end

local function Collect(convo)
    wipe(list)
    local messages = convo and convo.messages
    for i = 1, type(messages) == "table" and #messages or 0 do
        if messages[i].pinned then list[#list + 1] = messages[i] end
    end
    tsort(list, ByPinTime)
    return list
end

function Pins:Count(key)
    if not self:Enabled() then return 0 end
    local convo = Convo(key)
    local messages = convo and convo.messages
    local n = 0
    for i = 1, type(messages) == "table" and #messages or 0 do
        if messages[i].pinned then n = n + 1 end
    end
    return n
end

function Pins:TogglePin(msg)
    if not msg then return end
    if msg.pinned then
        msg.pinned, msg.pinnedAt = nil, nil
    else
        msg.pinned, msg.pinnedAt = true, time()
    end
    UI:RefreshChatMessenger()
    if popout and popout:IsShown() then self:Fill() end
end

function Pins:JumpTo(msg)
    if popout then popout:Hide() end
    UI:JumpToChatMessage(msg)
end

local function Entry(i)
    local e = entries[i]
    if e then return e end
    e = CreateFrame("Frame", nil, child)
    e.sep = e:CreateTexture(nil, "ARTWORK")
    e.sep:SetHeight(1)
    e.sep:SetPoint("TOPLEFT")
    e.sep:SetPoint("TOPRIGHT")
    e.sep:SetColorTexture(0.42, 0.42, 0.46, 0.35)
    popout._efThemeSeps[#popout._efThemeSeps + 1] = e.sep
    e.unpin = ns.CreateCloseX(e, 12)
    e.unpin:SetPoint("TOPRIGHT", e, "TOPRIGHT", 0, -ENTRY_PAD - 2)
    e.unpin:SetScript("OnClick", function() Pins:TogglePin(e.message) end)
    e.unpin:HookScript("OnEnter", function(self) ns.ShowHintTooltip(self, "ANCHOR_TOP", "Unpin") end)
    e.unpin:HookScript("OnLeave", function(self) ns.HideHintTooltip(self) end)
    e.jump = ns.CreateModernButton(e, "", 40, 18)
    e.jump:SetText("Jump")
    e.jump:SetWidth(mceil(e.jump._label:GetUnboundedStringWidth()) + 16)
    e.jump:SetPoint("RIGHT", e.unpin, "LEFT", -6, 0)
    e.jump:SetScript("OnClick", function() Pins:JumpTo(e.message) end)
    e.name = e:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    e.name:SetPoint("TOPLEFT", e, "TOPLEFT", 0, -ENTRY_PAD)
    e.name:SetPoint("RIGHT", e.jump, "LEFT", -6, 0)
    e.name:SetJustifyH("LEFT")
    e.name:SetWordWrap(false)
    e.when = e:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    e.when:SetPoint("TOPLEFT", e.name, "BOTTOMLEFT", 0, -1)
    e.when:SetPoint("RIGHT", e.jump, "LEFT", -6, 0)
    e.when:SetJustifyH("LEFT")
    e.when:SetWordWrap(false)
    e.text = e:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    e.text:SetPoint("TOPLEFT", e.when, "BOTTOMLEFT", 0, -3)
    e.text:SetPoint("RIGHT", e, "RIGHT", 0, 0)
    e.text:SetJustifyH("LEFT")
    e.text:SetJustifyV("TOP")
    e.text:SetWordWrap(true)
    if e.text.SetMaxLines then e.text:SetMaxLines(TEXT_LINES) end
    local themed = chatNS.RegisterThemedText
    if themed then
        themed(e.name)
        themed(e.when, 0.6)
        themed(e.text)
    end
    UI:RegisterChatFrameFonts(e)
    ns.ShadeText(e)
    entries[i] = e
    return e
end

local function Build(host)
    popout = CreateFrame("Frame", nil, host)
    -- Built hidden: a new frame starts shown.
    popout:Hide()
    popout:SetFrameLevel(host:GetFrameLevel() + 60)
    popout:EnableMouse(true)
    popout._efThemeSeps = {}
    ns.StyleMenuPanel(popout)

    title = popout:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetHeight(TITLE_H)
    title:SetJustifyH("LEFT")
    title:SetText("Pinned messages")
    local close = ns.CreateCloseX(popout, 16)
    close:SetPoint("TOPRIGHT", -PAD + 2, -PAD + 1)
    close:SetScript("OnClick", function() popout:Hide() end)
    title:SetPoint("RIGHT", close, "LEFT", -6, 0)
    if chatNS.RegisterThemedText then chatNS.RegisterThemedText(title) end

    scroll = CreateFrame("ScrollFrame", nil, popout)
    scroll:SetPoint("TOPLEFT", PAD, -(PAD + TITLE_H + 4))
    scroll:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    bar = Utils.CreateMinimalScrollBar(scroll, popout)
    bar:ClearAllPoints()
    bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 0, 0)

    popout:SetScript("OnHide", function(self)
        -- Hidden with the window: shut, not back on its next show.
        if self:IsShown() then self:Hide() end
        self.key = nil
    end)
    Utils.RegisterClickGuard(popout)
    Utils.AttachOutsideClickClose(popout, host.messengerView and host.messengerView.pinsButton)
    -- After its own scripts: SetScript drops the hooks this adds.
    Utils.AttachEscClose(popout)
end

-- Lays the open chat's pins out; none left, it closes.
function Pins:Fill()
    if not (popout and popout.key) then return end
    local convo = Convo(popout.key)
    local pins = Collect(convo)
    if #pins == 0 then
        popout:Hide()
        return
    end
    local host = popout:GetParent()
    local view = host and host.messengerView
    local detailW = view and view.detail and view.detail:GetWidth() or MAX_W
    local width = mmax(MIN_W, mmin(MAX_W, mceil(detailW * 0.6)))
    popout:SetWidth(width)
    local scrollW = width - PAD * 2
    local y = 0
    for i = 1, #pins do
        local msg, e = pins[i], Entry(i)
        e.message = msg
        e.sep:SetShown(i > 1)
        e.name:SetText(UI:WrapChatClassName(UI:GetChatMessageSenderLabel(convo, msg, popout.key),
            msg.outgoing and UI:GetChatPlayerClass() or msg.senderClass))
        e.when:SetText(UI:FormatChatMessageDay(msg.time) .. ", " .. UI:FormatChatBubbleTime(msg.time))
        local text = UI:GetChatMessageDisplayText(msg)
        e.text:SetText(text)
        local textW = scrollW - BAR_ROOM
        local lines, _, lineH = UI:GetChatWrappedTextMetrics(e.text, text, textW)
        local textH = mceil(mmin(lines or 1, TEXT_LINES) * (lineH or 12))
        local h = ENTRY_PAD + UI:GetChatFontLineHeight(e.name, 12) + 1 + UI:GetChatFontLineHeight(e.when, 10)
            + 3 + textH + ENTRY_PAD
        e:ClearAllPoints()
        e:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
        e:SetPoint("RIGHT", child, "RIGHT", -BAR_ROOM, 0)
        e:SetHeight(h)
        e:Show()
        y = y + h
    end
    for i = #pins + 1, #entries do
        entries[i].message = nil
        entries[i]:Hide()
    end
    ns.RetintMenuSeparators(popout)
    child:SetSize(scrollW, mmax(1, y))
    local viewH = mmin(y, mmax(80, MAX_H - (PAD * 2 + TITLE_H + 4)))
    popout:SetHeight(PAD * 2 + TITLE_H + 4 + viewH)
    if y > viewH + 1 then
        bar:Show()
        bar:UpdateThumb(y, viewH)
    else
        scroll:SetVerticalScroll(0)
        bar:Hide()
    end
end

-- Opens under the header's pin for one chat; the pin pressed again closes it.
function Pins:TogglePopout(key, button)
    local host = UI._chatComposer and UI._chatComposer.frame
    if not (key and host) then return end
    if popout and popout:IsShown() and popout.key == key then
        popout:Hide()
        return
    end
    if not popout then Build(host) end
    popout.key = key
    popout:ClearAllPoints()
    popout:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 4, -4)
    popout:Show()
    self:Fill()
end

-- The chat on screen changed: a popout for another one shuts.
function Pins:Sync(key)
    if popout and popout:IsShown() and popout.key ~= key then popout:Hide() end
end

-- The header's pin, shown while the open chat has pins.
function Pins:CreateHeaderButton(view, detail)
    local button = CreateFrame("Button", nil, detail)
    view.pinsButton = button
    button:SetSize(16, 16)
    button.glyph = button:CreateTexture(nil, "OVERLAY")
    button.glyph:SetTexture(PIN_TEX)
    button.glyph:SetSize(12, 12)
    button.glyph:SetPoint("CENTER")
    if chatNS.RegisterThemedText then chatNS.RegisterThemedText(button.glyph, 0.75) end
    button:SetScript("OnClick", function(self)
        Pins:TogglePopout(UI._chatComposer.selectedConversationKey, self)
    end)
    button:SetScript("OnEnter", function(self)
        local n = Pins:Count(UI._chatComposer.selectedConversationKey)
        ns.ShowHintTooltip(self, "ANCHOR_TOP", n == 1 and "1 pinned message" or (n .. " pinned messages"))
    end)
    button:SetScript("OnLeave", function(self) ns.HideHintTooltip(self) end)
    button:Hide()
    return button
end
