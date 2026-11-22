local _, chatNS = ...

local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not (ns and ns.Utils) or chatNS.tooOld then return end

-- With the takeover the game's own chat line, whatever opens it, sits on
-- our message line painted to match: its Enter is the game's, so /cast
-- runs. Only its anchors and paint change; both go back as it closes.
local GameLine = {}
chatNS.GameLine = GameLine

local UI = chatNS.UI
local CreateFrame = CreateFrame
local GetTime = GetTime
local wipe = wipe
local issecretvalue = _G.issecretvalue

-- How long after a command its output still counts as its own.
local CAPTURE_SECONDS = 3
local CAPTURE_TICK = 0.25

local function TakeoverOn()
    return type(EasyFindChatDB) == "table" and EasyFindChatDB.takeover == true
end

local function LineView()
    local frame = UI._chatComposer.frame
    return frame and frame.messengerView
end

local taken, anchoredTo, lastOpen, lastText, typePending, cameFrom, headerOpen
-- Opened as a bare "/" in a chat of ours, no chat turned since.
local bare
-- A message sent from the line comes back from the server a moment later.
local SENT_GRACE = 2
local points, art, texts, headers, shadows, insets = {}, {}, {}, {}, {}, {}
local driver = CreateFrame("Frame")
driver:Hide()

-- Its header hidden and its insets ours (none): the text starts where
-- ours does.
local function Anchor(box, target)
    box:ClearAllPoints()
    box:SetPoint("LEFT", target, "LEFT", 0, 0)
    box:SetPoint("RIGHT", target, "RIGHT", 0, 0)
    anchoredTo = target
end

local function Collect(box)
    wipe(art)
    wipe(texts)
    local name = box:GetName()
    if not name then return end
    for _, part in ipairs({ "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }) do
        local tex = _G[name .. part]
        if tex then art[#art + 1] = tex end
    end
    texts[1] = box
    wipe(headers)
    for _, part in ipairs({ "Header", "HeaderSuffix" }) do
        local fs = _G[name .. part]
        if fs then headers[#headers + 1] = fs end
    end
    if box.languageHeader then headers[#headers + 1] = box.languageHeader end
end

-- Every shadow ns.ShadeText reaches in the box, to hand back as it was.
local function SaveShadows(f)
    if f.GetShadowColor then
        local r, g, b, a = f:GetShadowColor()
        local x, y = f:GetShadowOffset()
        shadows[#shadows + 1] = { f, r, g, b, a, x, y }
    end
    if f.GetRegions then
        for i = 1, select("#", f:GetRegions()) do
            local region = select(i, f:GetRegions())
            if region and region.GetShadowColor then SaveShadows(region) end
        end
    end
    if f.GetChildren then
        for i = 1, select("#", f:GetChildren()) do SaveShadows((select(i, f:GetChildren()))) end
    end
end

-- All and System have no chat type of their own: there the header stays
-- and says where the line goes.
local function OnView()
    local views = chatNS.Views
    return views ~= nil and views:IsView(UI._chatComposer.selectedConversationKey)
end

-- The game redraws its frame art, header, insets and colors on each
-- header change: kept off while the box is ours. Light themes take our
-- text color.
local function Paint()
    for i = 1, #art do
        if art[i]:GetAlpha() > 0 then art[i]:SetAlpha(0) end
    end
    local open = OnView()
    local alpha = open and 1 or 0
    for i = 1, #headers do
        if headers[i]:GetAlpha() ~= alpha then headers[i]:SetAlpha(alpha) end
    end
    local box = taken
    if box and open ~= headerOpen then
        headerOpen = open
        -- Its own insets back, past the header.
        if open and box.UpdateHeader then box:UpdateHeader() end
    end
    if box and not open then
        local l, r = box:GetTextInsets()
        if (l or 0) ~= 0 or (r or 0) ~= 0 then box:SetTextInsets(0, 0, 0, 0) end
    end
    if not (EasyFind.API and EasyFind.API.IsLightTheme and EasyFind.API.IsLightTheme()) then return end
    local r, g, b = chatNS.TextColor()
    for i = 1, #texts do
        local cr, cg, cb = texts[i]:GetTextColor()
        if math.abs(cr - r) + math.abs(cg - g) + math.abs(cb - b) > 0.01 then texts[i]:SetTextColor(r, g, b) end
    end
end

-- The output a command leaves in the game's hidden chat window: its system
-- lines, and what prints straight into the window (help text, print()).
local capture = { frames = {}, heard = {}, seen = setmetatable({}, { __mode = "k" }) }
local captureEvents = CreateFrame("Frame")

local function Note(text)
    if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return end
    text = UI:GetPlainChatLabel(text)
    if text ~= "" then UI:AddChatNote(capture.key, text) end
end

local function SystemID()
    local info = ChatTypeInfo and ChatTypeInfo["SYSTEM"]
    return info and info.id
end

local function ReadHistory()
    local systemID = SystemID()
    local found = {}
    for frame in pairs(capture.frames) do
        if type(frame.ForEachMessage) == "function" then
            frame:ForEachMessage(function(entry)
                local when = entry.timestamp
                if not when or when <= capture.from then return true end
                local id = entry.extraData and entry.extraData[1]
                local text = entry.message
                if not capture.seen[entry] and (id == nil or id == systemID) and type(text) == "string"
                    and not (issecretvalue and issecretvalue(text)) then
                    capture.seen[entry] = true
                    found[#found + 1] = text
                end
            end)
        end
    end
    -- Newest first in the window: added oldest first.
    for i = #found, 1, -1 do
        local text = found[i]
        local plain = UI:GetPlainChatLabel(text)
        local dupe = false
        for heard in pairs(capture.heard) do
            if plain:find(heard, 1, true) then dupe = true break end
        end
        if not dupe then Note(text) end
    end
end

local function StopCapture()
    if capture.ticker then capture.ticker:Cancel() end
    capture.ticker = nil
    captureEvents:UnregisterAllEvents()
end

local function CaptureTick()
    ReadHistory()
    if GetTime() >= capture.untilTime then StopCapture() end
end

captureEvents:SetScript("OnEvent", function(_, _, text)
    if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return end
    capture.heard[UI:GetPlainChatLabel(text)] = true
    Note(text)
end)

local function StartCapture(box)
    StopCapture()
    capture.key = UI._chatComposer.selectedConversationKey
    if not capture.key then return end
    wipe(capture.frames)
    wipe(capture.heard)
    local chatFrame = box.chatFrame
    if chatFrame then capture.frames[chatFrame] = true end
    if DEFAULT_CHAT_FRAME then capture.frames[DEFAULT_CHAT_FRAME] = true end
    capture.from = lastOpen or GetTime()
    capture.untilTime = GetTime() + CAPTURE_SECONDS
    captureEvents:RegisterEvent("CHAT_MSG_SYSTEM")
    ReadHistory()
    capture.ticker = C_Timer.NewTicker(CAPTURE_TICK, CaptureTick)
end

-- A line opened as a bare "/" takes the chat open in our window, as the
-- game's own keeps the chat last used; the "/" erased, ours takes over.
local function TakeChatType(box)
    local chatType, target = UI:GetChatConversationChatType(UI._chatComposer.selectedConversationKey)
    if not chatType then return false end
    local function Set(key, value)
        if box.SetAttribute then box:SetAttribute(key, value) end
    end
    Set("chatType", chatType)
    if chatType == "CHANNEL" then Set("channelTarget", target) elseif target then Set("tellTarget", target) end
    if box.UpdateHeader then
        box:UpdateHeader()
    elseif _G.ChatEdit_UpdateHeader then
        _G.ChatEdit_UpdateHeader(box)
    end
    return true
end

-- The line's chat as the game holds it, last seen.
local seen = {}
local function Attrs(box)
    if not box.GetAttribute then return nil end
    return box:GetAttribute("chatType"), box:GetAttribute("tellTarget"), box:GetAttribute("channelTarget")
end
local function Remember(box)
    seen[1], seen[2], seen[3] = Attrs(box)
end

-- "/s ", "/w Name ", "/2 " and the rest turn the game's line on the space:
-- our window follows to that chat, the line still ours.
local function FollowChatType(box)
    local chatType, tell, channel = Attrs(box)
    if chatType == seen[1] and tell == seen[2] and channel == seen[3] then return end
    seen[1], seen[2], seen[3] = chatType, tell, channel
    bare = nil
    -- All shows every chat: the line turns, the window stays.
    if chatNS.Views and UI._chatComposer.selectedConversationKey == chatNS.Views.ALL then return end
    local key = UI:TouchChatConversationForChatType(chatType, chatType == "CHANNEL" and channel or tell)
    if key and key ~= UI._chatComposer.selectedConversationKey then UI:SelectChatConversation(key) end
end

-- The type waits for the text the opener gave: a bare "/" (its key, or a
-- "/" typed in our box) takes ours. A line opened for someone (Send
-- Message, a reply, Whisper on a player, a Battle.net tell) opens their chat.
local function SettleChatType(box)
    if box.setText == 1 then return end
    typePending = nil
    if box:GetText() == "/" then
        bare = TakeChatType(box)
        -- Our own write is the chat already open: not a turn to follow.
        Remember(box)
        return
    end
    local chatType, tell = Attrs(box)
    if (chatType == "WHISPER" or chatType == "BN_WHISPER") and tell then
        local key = UI:TouchChatConversationForChatType(chatType, tell)
        if key and key ~= UI._chatComposer.selectedConversationKey then UI:SelectChatConversation(key) end
    end
    Remember(box)
end

function GameLine:Take(box)
    if taken or not TakeoverOn() then return end
    if not chatNS:IsOpen() then UI:OpenChatComposer() end
    local frame = UI._chatComposer.frame
    if not frame then return end
    if frame.chatMode ~= "messenger" then UI:ShowChatMessengerView() end
    local view = LineView()
    if not (view and view.replyEditBox) then return end
    taken, headerOpen, bare = box, nil, nil
    UI._chatComposer.gameLine = true
    if UI:GetChatInputStyle() == "enter" then UI._chatComposer.lineOpen = true end
    UI:SyncChatReplyLine(view)
    wipe(points)
    for i = 1, box:GetNumPoints() do points[i] = { box:GetPoint(i) } end
    insets[1], insets[2], insets[3], insets[4] = box:GetTextInsets()
    typePending = true
    cameFrom = UI._chatComposer.selectedConversationKey
    Remember(box)
    Anchor(box, view.replyEditBox)
    Collect(box)
    wipe(shadows)
    SaveShadows(box)
    ns.ShadeText(box)
    Paint()
    lastOpen = GetTime()
    driver:Show()
end

function GameLine:Release(hideBox)
    driver:Hide()
    local box = taken
    if not box then return end
    taken, anchoredTo, headerOpen, bare = nil, nil, nil, nil
    box:ClearAllPoints()
    for i = 1, #points do box:SetPoint(unpack(points[i])) end
    for i = 1, #art do art[i]:SetAlpha(1) end
    for i = 1, #headers do headers[i]:SetAlpha(1) end
    if insets[1] then box:SetTextInsets(insets[1], insets[2] or 0, insets[3] or 0, insets[4] or 0) end
    typePending = nil
    for i = 1, #shadows do
        local s = shadows[i]
        s[1]:SetShadowColor(s[2], s[3], s[4], s[5])
        s[1]:SetShadowOffset(s[6], s[7])
    end
    wipe(shadows)
    -- The game's chat is hidden: a box it keeps up (its IM style) goes too.
    if box:IsShown() and (hideBox or not box:HasFocus()) then box:Hide() end
    UI._chatComposer.gameLine = nil
    -- Output only after a command: not after a line left empty.
    if not hideBox and lastText and lastText:sub(1, 1) == "/" and #lastText > 1 then StartCapture(box) end
    local typed = lastText ~= nil and lastText ~= "" and lastText:sub(1, 1) ~= "/"
    lastText = nil
    -- One layout of the line: closing it lays it out.
    local view = LineView()
    if UI:GetChatInputStyle() == "enter" and UI._chatComposer.lineOpen then
        UI:CloseChatLine()
    elseif view then
        UI:SyncChatReplyLine(view)
    end
    GameLine:LeaveTurn(cameFrom, typed)
    cameFrom = nil
end

-- The line let go on a chat it made, still empty: back to the chat it came
-- from. Typed words may be a message on its way: it waits for them.
function GameLine:LeaveTurn(from, typed)
    local key = UI._chatComposer.selectedConversationKey
    if not UI:IsChatConversationFlipEmpty(key) then return end
    local function Leave()
        if not UI:IsChatConversationFlipEmpty(key) then return end
        if UI._chatComposer.selectedConversationKey == key and from and from ~= key
            and UI:GetChatConversationStore().byKey[from] then
            UI:SelectChatConversation(from)
        else
            UI:DropEmptyFlipConversation(key)
        end
    end
    if typed then C_Timer.After(SENT_GRACE, Leave) else Leave() end
end

-- Enter with the game's line in ours: back into it.
function GameLine:Focus()
    if not taken then return false end
    taken:SetFocus()
    return true
end

-- The bare "/" erased or typed over: no command after all, so the words
-- go on in our line, in our look.
local function HandBack(box, text)
    lastText = nil
    box:SetText("")
    GameLine:Release(true)
    UI:OpenChatLine()
    local view = LineView()
    local edit = view and view.replyEditBox
    if edit and text ~= "" then
        edit:SetText(text)
        edit:SetCursorPosition(#text)
    end
end

driver:SetScript("OnUpdate", function()
    local box = taken
    local view = LineView()
    if not (box and TakeoverOn() and view and view.replyShell:IsVisible()) then
        return GameLine:Release(true)
    end
    if not box:IsShown() or (not box:HasFocus() and (box:GetText() or "") == "") then
        return GameLine:Release()
    end
    lastOpen = GetTime()
    if typePending then SettleChatType(box) end
    if not typePending then FollowChatType(box) end
    lastText = box:GetText()
    if bare and (lastText or ""):sub(1, 1) ~= "/" then return HandBack(box, lastText or "") end
    if anchoredTo ~= view.replyEditBox or select(2, box:GetPoint(1)) ~= view.replyEditBox then
        Anchor(box, view.replyEditBox)
    end
    Paint()
end)

-- A child of each of the game's chat boxes hears it show: watched, nothing
-- of the game's hooked.
local watchers = {}
function GameLine:Apply(on)
    if not on then
        if taken then self:Release(true) end
        return
    end
    for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
        local box = _G["ChatFrame" .. i .. "EditBox"]
        if box and not watchers[box] then
            -- starts shown: it shows and hides with its box
            local watcher = CreateFrame("Frame", nil, box)
            watcher:SetScript("OnShow", function() GameLine:Take(box) end)
            watchers[box] = watcher
        end
    end
end
