





local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns then return end








local Snippets = {}
ns.Snippets = Snippets

local Utils = ns.Utils
local L = ns.L

local slower = Utils.slower
local sformat = Utils.sformat
local ssub = Utils.ssub
local mceil = Utils.mceil
local hooksecurefunc = hooksecurefunc
local sbyte = string.byte
local sgsub = string.gsub
local sgmatch = string.gmatch
local smatch = Utils.smatch
local sfind = Utils.sfind
local tconcat = Utils.tconcat
local tremove = Utils.tremove
local type = Utils.type
local wipe = wipe
local strtrim = strtrim
local date = date
local UnitName = UnitName
local CreateFrame = CreateFrame
local C_Map = C_Map
local GameTooltip = GameTooltip
local EditMacro = EditMacro
local GetMacroInfo = GetMacroInfo
local InCombatLockdown = InCombatLockdown

local function SnippetList()
    if type(EasyFindDB) ~= "table" then return nil end
    if type(EasyFindDB.snippets) ~= "table" then EasyFindDB.snippets = {} end
    return EasyFindDB.snippets
end



local keywordLookup = {}
Snippets._keywordLookup = keywordLookup



local editorFrame






local TRIGGER_CHOICES = { "\\", "!", "#", "~", "&", "+", "=" }
Snippets.TRIGGER_CHOICES = TRIGGER_CHOICES
local triggerChar, triggerByte = "\\", 92
local expandCallPattern, expandCallEndPattern, callContextPattern, helpPattern

function Snippets.TriggerChar()
    return triggerChar
end

function Snippets.RefreshTrigger()
    local c = EasyFind and EasyFind.db and EasyFind.db.snippetTriggerChar
    local valid = false
    for i = 1, #TRIGGER_CHOICES do
        if TRIGGER_CHOICES[i] == c then valid = true break end
    end
    if not valid then c = "\\" end
    triggerChar = c
    triggerByte = sbyte(c)
    local esc = "%" .. c
    expandCallPattern = "(" .. esc .. "[^%s" .. esc .. "%(]+)(%b())%s$"
    expandCallEndPattern = "(" .. esc .. "[^%s" .. esc .. "%(]+)(%b())$"
    callContextPattern = esc .. "([^%s" .. esc .. "%(%)%?]+)(%([^%)]*)$"
    helpPattern = esc .. "([^%s" .. esc .. "%(%)%?]+)%?$"
end
Snippets.RefreshTrigger()

local function FormattedKeywordHint()

    return sformat(L["SNIPPET_KEYWORD_HINT"], triggerChar) .. " " .. L["SNIP_HELP_CTRL_ENTER"]
end
Snippets.FormattedKeywordHint = FormattedKeywordHint


function Snippets.RefreshTriggerTexts()
    if editorFrame and editorFrame.hint then
        editorFrame.hint:SetText(FormattedKeywordHint())
    end
end





function Snippets.ToggleTriggerMenu(cogBtn)
    local keywordWord = slower(L["SNIPPET_KEYWORD"] or "keyword")
    local rows = {}
    for i = 1, #TRIGGER_CHOICES do
        local choice = TRIGGER_CHOICES[i]
        rows[#rows + 1] = {
            text = choice .. keywordWord,
            icon = (choice == triggerChar) and "Interface\\Buttons\\UI-CheckBox-Check" or nil,
            onClick = function()
                if EasyFind and EasyFind.db then
                    EasyFind.db.snippetTriggerChar = choice
                end
                Snippets.RefreshTrigger()
                Snippets.RefreshTriggerTexts()
            end,
        }
    end
    return Utils.ToggleCursorMenu("EasyFindSnippetTriggerMenu", rows, {
        anchorFrame = cogBtn,
        toggleOwner = cogBtn,
        point = "TOPRIGHT", relativePoint = "BOTTOMRIGHT", offsetY = -2,
    })
end

function Snippets.RebuildKeywordLookup()
    wipe(keywordLookup)
    local list = SnippetList()
    if not list then return end
    for i = 1, #list do
        local snippet = list[i]
        local keyword = type(snippet) == "table" and snippet.keyword
        if type(keyword) == "string" and keyword ~= "" then
            keywordLookup[slower(keyword)] = snippet
        end
    end
end


local function CollapseLines(text)
    return strtrim(sgsub(text or "", "%s*\n%s*", " "))
end



local function StripTokens(body)
    body = sgsub(body or "", "%*%*", "")
    body = sgsub(body, "__", "")
    body = sgsub(body, "~~", "")
    body = sgsub(body, "%*", "")
    return body
end



function Snippets.Flatten(body)
    return CollapseLines(StripTokens(body))
end






local function PlainText(snippet, keepLines)
    local flat = snippet.flat
    local text = type(flat) == "string" and flat or StripTokens(snippet.body)
    if keepLines then return strtrim(text) end
    return CollapseLines(text)
end

local function ZoneName()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then return "" end
    local mapID = C_Map.GetBestMapForUnit("player")
    local info = mapID and C_Map.GetMapInfo(mapID)
    return info and info.name or ""
end



local PLACEHOLDERS = {
    date = function() return date("%Y-%m-%d") end,
    time = function() return date("%H:%M") end,
    player = function() return ns.PlayerName() or "" end,
    target = function() return UnitName and UnitName("target") or "" end,
    zone = ZoneName,
}



local expansionArgs





local function ReplacePlaceholder(token)
    local key = slower(token)
    if expansionArgs and expansionArgs[key] ~= nil then return expansionArgs[key] end
    local fill = PLACEHOLDERS[key]
    return fill and fill() or nil
end

function Snippets.ResolvePlaceholders(text, args)
    expansionArgs = args


    local resolved = (sgsub(text or "", "{([^{}%s]+)}", ReplacePlaceholder))
    expansionArgs = nil
    return resolved
end




function Snippets.BodyParams(text)
    local params, seen = {}, {}
    for token in sgmatch(text or "", "{([^{}%s]+)}") do
        local key = slower(token)
        if not PLACEHOLDERS[key] and not seen[key] then
            seen[key] = true
            params[#params + 1] = key
        end
    end
    return params
end





function Snippets.ParseCallArgs(argText, params)
    local args, pos = {}, 0
    for part in sgmatch(argText or "", "[^,]+") do
        part = strtrim(part)
        if part ~= "" then
            local name, value = smatch(part, "^([^=%s]+)%s*=%s*(.-)%s*$")
            if name then
                args[slower(name)] = value
            else
                pos = pos + 1
                local param = params[pos]
                if param then args[param] = part end
            end
        end
    end
    return args
end


local function ChatText(snippet, args, keepLines)
    return Snippets.ResolvePlaceholders(PlainText(snippet, keepLines), args)
end



function Snippets.CallContext(slice)
    local keyword, open = smatch(slice, callContextPattern)
    if not keyword then return nil end
    return keyword, ssub(open, 2)
end






function Snippets.SuggestArgRemainder(params, argBefore)
    if #params == 0 then return nil end
    local done, fragment = smatch(argBefore or "", "^(.*),([^,]*)$")
    if not done then
        done, fragment = "", argBefore or ""
    end
    if sfind(fragment, "=", 1, true) then return nil end
    local used, pos = {}, 0
    for part in sgmatch(done, "[^,]+") do
        part = strtrim(part)
        if part ~= "" then
            local name = smatch(part, "^([^=%s]+)%s*=")
            if name then
                used[slower(name)] = true
            else
                pos = pos + 1
                if params[pos] then used[params[pos]] = true end
            end
        end
    end
    fragment = smatch(fragment, "^%s*(.-)%s*$") or fragment
    local fragLower = slower(fragment)
    local fragLen = #fragLower
    for i = 1, #params do
        local param = params[i]
        if not used[param] then
            if fragLen == 0 then
                return param .. "="
            elseif #param > fragLen and ssub(param, 1, fragLen) == fragLower then
                return ssub(param, fragLen + 1) .. "="
            elseif param == fragLower then
                return "="
            end
        end
    end
    return nil
end



local function SnippetArgCandidate(typed)
    if EasyFind and EasyFind.db and EasyFind.db.snippetChatExpansion == false then return nil end
    local from = #typed > 80 and #typed - 80 or 1
    if not sfind(typed, triggerChar, from, true) then return nil end
    local keyword, argBefore = Snippets.CallContext(typed)
    if not keyword then return nil end
    local snippet = keywordLookup[slower(keyword)]
    if not snippet then return nil end
    local remainder = Snippets.SuggestArgRemainder(
        Snippets.BodyParams(PlainText(snippet)), argBefore)
    if not remainder or remainder == "" then return nil end
    return typed .. remainder
end




local function TrimToCharBoundary(s, maxBytes)
    if #s <= maxBytes then return s end
    local cut = maxBytes
    while cut > 1 and sbyte(s, cut + 1) and sbyte(s, cut + 1) >= 128 and sbyte(s, cut + 1) < 192 do
        cut = cut - 1
    end
    return ssub(s, 1, cut) .. "..."
end

local function HideSnippetHelp(editBox)
    if not editBox._efSnipHelp then return end
    editBox._efSnipHelp = nil
    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(editBox) then
        GameTooltip:Hide()
    end
end

local function UpdateSnippetHelp(editBox, text, caret)
    if not GameTooltip then return end
    local slice = ssub(text, 1, caret)
    local keyword = smatch(slice, helpPattern)
    local snippet = keyword and keywordLookup[slower(keyword)]
    if not snippet then
        HideSnippetHelp(editBox)
        return
    end
    local params = Snippets.BodyParams(PlainText(snippet))
    local signature = triggerChar .. slower(keyword)
    if #params > 0 then
        signature = signature .. "(" .. tconcat(params, ", ") .. ")"
    end
    GameTooltip:SetOwner(editBox, "ANCHOR_TOP")
    GameTooltip:AddLine(signature, ns.GOLD_COLOR[1], ns.GOLD_COLOR[2], ns.GOLD_COLOR[3])


    GameTooltip:AddLine(TrimToCharBoundary(Utils.ClipboardSafeText(PlainText(snippet, true)) or "", 220),
        1, 1, 1, true)
    GameTooltip:AddLine(ns.L["SNIP_HELP_CTRL_ENTER"], 0.7, 0.7, 0.7)
    GameTooltip:Show()
    editBox._efSnipHelp = true
end

local function FindByName(name)
    local list = SnippetList()
    if not (list and name) then return nil end
    local nameLower = slower(name)
    for i = 1, #list do
        local snippet = list[i]
        if type(snippet) == "table" and snippet.name
           and slower(snippet.name) == nameLower then
            return snippet, i
        end
    end
    return nil
end




function Snippets:RunByName(name)
    local snippet = FindByName(name)
    if not snippet then return end
    local text = ChatText(snippet)
    if text == "" then return end
    local active = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if active then
        active:Insert(text)
    elseif ChatFrame_OpenChat then
        ChatFrame_OpenChat(text)
    elseif ns.CopyToClipboard then


        ns.CopyToClipboard(Utils.ClipboardSafeText(text), text)
    end
end



function Snippets:GetChatTextByName(name)
    local snippet = FindByName(name)
    if not snippet then return nil end
    local text = ChatText(snippet)
    return text ~= "" and text or nil
end

function Snippets:EditByName(name)
    local _, index = FindByName(name)
    if index then
        self:OpenEditor(index)
    end
end




function Snippets:InsertIntoNote(name)
    local snippet = FindByName(name)
    if not snippet then return end
    if snippet.flat or snippet.decorations then


        EasyFind.API.CallAction("notes", "insertDocument", {
            body = snippet.body,
            decorations = snippet.decorations,
        })
    else
        EasyFind.API.CallAction("notes", "insertText", self.ResolvePlaceholders(snippet.body))
    end
end

local ExpandTokenAt



local function OnChatTextChanged(editBox, userInput)
    if not userInput then return end
    if EasyFind and EasyFind.db and EasyFind.db.snippetChatExpansion == false then return end
    local text = editBox:GetText()
    local textLen = text and #text or 0
    if textLen < 2 then return end



    local caret = editBox:GetCursorPosition() or textLen
    if caret < 2 or caret > textLen then
        HideSnippetHelp(editBox)
        return
    end
    if sbyte(text, caret) ~= 32 then


        UpdateSnippetHelp(editBox, text, caret)
        return
    end
    HideSnippetHelp(editBox)
    local slice = ssub(text, 1, caret)


    local token, argText
    local callWord, parens = smatch(slice, expandCallPattern)
    if callWord then
        token = callWord .. parens
        argText = ssub(parens, 2, -2)
    else
        token = smatch(slice, "(%S+)%s$")
    end
    if not token then return end
    ExpandTokenAt(editBox, text, caret - 1, token, callWord, argText, " ")
end




ExpandTokenAt = function(editBox, text, last, token, callWord, argText, tail)





    if sbyte(token, 1) ~= triggerByte then return end
    local keyword = callWord and ssub(callWord, 2) or ssub(token, 2)
    local snippet = keywordLookup[slower(keyword)]
    if not snippet then return end
    local args
    if argText and argText ~= "" then
        args = Snippets.ParseCallArgs(argText, Snippets.BodyParams(PlainText(snippet)))
    end


    local keepLines = editBox.IsMultiLine and editBox:IsMultiLine() or false
    local expanded = ChatText(snippet, args, keepLines)
    if expanded == "" then return end
    local wordStart = last - #token
    local newText = ssub(text, 1, wordStart) .. expanded .. tail .. ssub(text, last + #tail + 1)










    if editBox._efSnippetMacroBox then
        local macroFrame = _G["MacroFrame"]
        local body = editBox == _G["MacroFrameText"]
            and macroFrame and macroFrame.GetSelectedIndex and macroFrame.GetMacroDataIndex
        if not body then



            editBox:SetText(newText)
            editBox:SetCursorPosition(wordStart + #expanded + #tail)
            return
        end
        if InCombatLockdown and InCombatLockdown() then
            Snippets.ShowMacroHandoff(expanded, snippet.name)
            return
        end
        local selectedIndex = macroFrame:GetSelectedIndex()
        local actualIndex = selectedIndex and macroFrame:GetMacroDataIndex(selectedIndex)
        if actualIndex and EditMacro then


            pcall(EditMacro, actualIndex, nil, nil, newText)
        end
        local savedBody
        if actualIndex and GetMacroInfo then
            local _, _, saved = GetMacroInfo(actualIndex)
            savedBody = saved
        end
        if savedBody ~= newText then
            Snippets.ShowMacroHandoff(expanded, snippet.name)
            return
        end
        editBox:SetText(newText)
        editBox:SetCursorPosition(wordStart + #expanded + #tail)
        macroFrame.textChanged = nil




        Utils.SafeAfter(0, function()
            if editBox:GetText() == newText then
                macroFrame.textChanged = nil
            end
        end)
        return
    end
    editBox:SetText(newText)
    editBox:SetCursorPosition(wordStart + #expanded + #tail)
end





local function OnChatKeyDown(editBox, key)
    if key ~= "ENTER" or not IsControlKeyDown() then return end
    if editBox._efSnippetMacroBox then return end
    if EasyFind and EasyFind.db and EasyFind.db.snippetChatExpansion == false then return end
    local text = editBox:GetText()
    local textLen = text and #text or 0
    if textLen < 2 then return end
    local caret = editBox:GetCursorPosition() or textLen
    if caret < 2 or caret > textLen then return end
    local slice = ssub(text, 1, caret)
    local token, argText
    local callWord, parens = smatch(slice, expandCallEndPattern)
    if callWord then
        token = callWord .. parens
        argText = ssub(parens, 2, -2)
    else
        token = smatch(slice, "(%S+)$")
    end
    if not token then return end
    HideSnippetHelp(editBox)
    ExpandTokenAt(editBox, text, caret, token, callWord, argText, "")
end




function Snippets.AttachExpansion(editBox)
    if not editBox or editBox._efSnippetHooked then return end
    editBox._efSnippetHooked = true
    editBox:HookScript("OnTextChanged", OnChatTextChanged)
    editBox:HookScript("OnEditFocusLost", HideSnippetHelp)
    if not editBox._efSnippetMacroBox then
        Utils.AttachPasteLinkSwap(editBox)
        editBox:HookScript("OnKeyDown", OnChatKeyDown)
    end




    if Utils.AttachAutocomplete and not editBox._efSnippetMacroBox then
        Utils.AttachAutocomplete(editBox, {
            endOfTextOnly = true,
            applyOnType = true,
            findCandidate = SnippetArgCandidate,
        })
    end
end




local function AttachEditBoxesIn(frame, depth)
    if not frame or depth > 6 then return end
    if frame.GetObjectType and frame:GetObjectType() == "EditBox" then


        frame._efSnippetMacroBox = true
        Snippets.AttachExpansion(frame)
        return
    end
    if not frame.GetChildren then return end
    local children = { frame:GetChildren() }
    for i = 1, #children do
        AttachEditBoxesIn(children[i], depth + 1)
    end
end

local function AttachMacroExpansion()
    local legacyBox = _G["MacroFrameText"]
    if legacyBox then legacyBox._efSnippetMacroBox = true end
    Snippets.AttachExpansion(legacyBox)
    local macroFrame = _G["MacroFrame"]
    if not macroFrame then return end
    AttachEditBoxesIn(macroFrame, 1)
    if not macroFrame._efSnippetShowHook then
        macroFrame._efSnippetShowHook = true


        macroFrame:HookScript("OnShow", function(self)
            Snippets.AttachExpansion(_G["MacroFrameText"])
            AttachEditBoxesIn(self, 1)
        end)
    end
end

local function InstallChatExpansion()




    if ChatEdit_OnTextChanged and hooksecurefunc then
        hooksecurefunc("ChatEdit_OnTextChanged", OnChatTextChanged)
        Snippets._expansionMode = "global-hook"
        return
    end
    local windowCount = NUM_CHAT_WINDOWS or 10
    for i = 1, windowCount do
        Snippets.AttachExpansion(_G["ChatFrame" .. i .. "EditBox"])
    end
    Snippets._expansionMode = "per-frame"
end

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:RegisterEvent("ADDON_LOADED")
loginFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" then


        if addonName == "Blizzard_MacroUI" then
            self:UnregisterEvent("ADDON_LOADED")
            AttachMacroExpansion()
        end
        return
    end
    self:UnregisterEvent("PLAYER_LOGIN")

    Snippets.RefreshTrigger()
    Snippets.RebuildKeywordLookup()
    InstallChatExpansion()
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_MacroUI") then
        self:UnregisterEvent("ADDON_LOADED")
        AttachMacroExpansion()
    end
end)



local SNIPPET_KEYWORDS = { "snippet", "snippets" }
local PREVIEW_MAX = 60

local function SnippetSubtext(snippet, flatBody)



    local preview = Utils.StripMarkup(flatBody) or ""
    if #preview > PREVIEW_MAX then
        preview = ssub(preview, 1, PREVIEW_MAX - 3) .. "..."
    end
    local keyword = snippet.keyword
    if type(keyword) == "string" and keyword ~= "" then
        if preview == "" then return keyword end
        return keyword .. " - " .. preview
    end
    return preview
end

local function OpenEditorNew()
    Snippets:OpenEditor(nil)
end

function Snippets:BuildSearchData()
    local entries = {}



    entries[1] = {
        name = L["FILTER_SNIPPETS"],
        nameLower = slower(L["FILTER_SNIPPETS"]),
        category = "Snippet",
        keywords = SNIPPET_KEYWORDS,
        nativeRun = function() EasyFind.API.OpenSettings("snippets") end,
        noPin = true,
        snippetsLauncher = true,
    }
    entries[2] = {
        name = L["SNIPPET_CREATE"],
        nameLower = slower(L["SNIPPET_CREATE"]),
        category = "Snippet",
        keywords = SNIPPET_KEYWORDS,
        searchCommandDesc = L["SNIPPET_CREATE_SUB"],
        nativeRun = OpenEditorNew,
        noPin = true,
        createRow = true,
    }
    local list = SnippetList()
    if list then
        for i = 1, #list do
            local snippet = list[i]
            if type(snippet) == "table" and type(snippet.name) == "string"
               and snippet.name ~= "" then
                local keyword = snippet.keyword
                local flatBody = PlainText(snippet)



                local keywordsLower = { "snippet", "snippets" }
                if type(keyword) == "string" and keyword ~= "" then
                    keywordsLower[#keywordsLower + 1] = slower(keyword)
                end
                if flatBody ~= "" then
                    keywordsLower[#keywordsLower + 1] = slower(flatBody)
                end
                entries[#entries + 1] = {
                    name = snippet.name,
                    nameLower = slower(snippet.name),
                    category = "Snippet",
                    keywordsLower = keywordsLower,
                    searchCommandDesc = SnippetSubtext(snippet, flatBody),
                    snippetIndex = i,



                    snippetKeywordLower = (type(keyword) == "string" and keyword ~= "")
                        and slower(keyword) or nil,
                }
            end
        end
    end
    return entries
end

local function RefreshSnippetRows()
    Snippets.RebuildKeywordLookup()



    EasyFind.API.RefreshSearchProvider("snippets")
    if ns.Options and ns.Options.RefreshSnippetsList then
        ns.Options.RefreshSnippetsList()
    end
end



local DIALOG_W = 440
local DIALOG_PAD = 14
local FIELD_H = 26
local BODY_H = 120


local CHAT_MAX = ns.CHAT_MESSAGE_MAX_CHARS or 255




function Snippets:FindConflict(name, keyword, except)
    local list = SnippetList()
    if not list then return nil end
    local nameLower = type(name) == "string" and slower(strtrim(name)) or ""
    local keyLower = type(keyword) == "string" and slower(strtrim(keyword)) or ""
    for i = 1, #list do
        local s = list[i]
        if i ~= except and type(s) == "table" then
            if nameLower ~= "" and type(s.name) == "string" and slower(s.name) == nameLower then return s, i end
            if keyLower ~= "" and type(s.keyword) == "string" and slower(s.keyword) == keyLower then return s, i end
        end
    end
    return nil
end

function Snippets:ClearAll()
    local list = SnippetList()
    if not list then return end
    for i = #list, 1, -1 do list[i] = nil end
    RefreshSnippetRows()
end



function Snippets:HasSnippet(name)
    return FindByName(name) ~= nil
end



function Snippets:ExportList()
    local out = {}
    local list = SnippetList()
    if not list then return out end
    for i = 1, #list do
        local s = list[i]
        if type(s) == "table" and type(s.name) == "string" and s.name ~= "" then
            out[#out + 1] = { name = s.name, keyword = s.keyword or "", body = PlainText(s, true) }
        end
    end
    return out
end




function Snippets:ImportList(rows, skipExisting)
    local list = SnippetList()
    if not (list and type(rows) == "table") then return 0 end
    local n = 0
    for i = 1, #rows do
        local r = rows[i]
        if type(r) == "table" and type(r.name) == "string" and strtrim(r.name) ~= "" then
            local keyword = sgsub(strtrim(r.keyword or ""), "%s+", "")
            local clash = self:FindConflict(r.name, keyword)
            if not (clash and skipExisting) then
                while clash do
                    local _, index = self:FindConflict(r.name, keyword)
                    table.remove(list, index)
                    clash = self:FindConflict(r.name, keyword)
                end
                list[#list + 1] = {
                    name = strtrim(r.name),
                    keyword = keyword ~= "" and keyword or nil,
                    body = ssub(r.body or "", 1, CHAT_MAX),
                }
                n = n + 1
            end
        end
    end
    if n > 0 then RefreshSnippetRows() end
    return n
end

local function UpdateCharCounter(f)
    f.charCounter:SetText(f.bodyBox:GetNumLetters() .. "/" .. CHAT_MAX)
end

local function LabeledField(parent, labelText, y, height, multiLine)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", DIALOG_PAD, y)
    label:SetText(labelText)

    local field = CreateFrame("Frame", nil, parent)
    field:SetPoint("TOPLEFT", DIALOG_PAD, y - 14)
    field:SetPoint("RIGHT", -DIALOG_PAD, 0)
    field:SetHeight(height)
    local bg = field:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.45)

    local editBox
    if multiLine then
        local scroll = CreateFrame("ScrollFrame", nil, field)
        scroll:SetPoint("TOPLEFT", 8, -5)
        scroll:SetPoint("BOTTOMRIGHT", -8, 5)

        editBox = CreateFrame("EditBox", nil, scroll)
        editBox:SetMultiLine(true)
        editBox:SetWidth(DIALOG_W - DIALOG_PAD * 2 - 16)
        editBox:SetFontObject("GameFontHighlight")
        editBox:SetAutoFocus(false)
        editBox:SetTextInsets(0, 0, 0, 0)
        scroll:SetScrollChild(editBox)
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(self, delta)
            local maxScroll = (editBox:GetHeight() or 0) - self:GetHeight()
            if maxScroll < 0 then maxScroll = 0 end
            local target = self:GetVerticalScroll() - delta * 20
            if target < 0 then target = 0 elseif target > maxScroll then target = maxScroll end
            self:SetVerticalScroll(target)
        end)
        editBox:SetScript("OnCursorChanged", function(self, _, cursorY, _, cursorH)
            local offset = scroll:GetVerticalScroll()
            local top = -cursorY
            local viewH = scroll:GetHeight()
            if top < offset then
                scroll:SetVerticalScroll(top)
            elseif top + cursorH > offset + viewH then
                scroll:SetVerticalScroll(top + cursorH - viewH)
            end
        end)


        field:EnableMouse(true)
        field:SetScript("OnMouseDown", function() editBox:SetFocus() end)
    else
        editBox = CreateFrame("EditBox", nil, field)
        Utils.ReleaseFocusOnOutsideClick(editBox)
        editBox:SetPoint("LEFT", 8, 0)
        editBox:SetPoint("RIGHT", -8, 0)
        editBox:SetHeight(20)
        editBox:SetFontObject("GameFontHighlight")
        editBox:SetAutoFocus(false)
        editBox:SetJustifyH("LEFT")
    end
    return editBox, y - 14 - height, label
end

local function CloseEditor()
    if editorFrame then editorFrame:Hide() end
end


local function UnfocusBox(self)
    self:ClearFocus()
end

local function SaveEditor()
    local f = editorFrame
    if not f then return end
    local list = SnippetList()
    if not list then return end
    local name = strtrim(f.nameBox:GetText() or "")
    if name == "" then
        f.nameBox:SetFocus()
        return
    end
    local keyword = sgsub(strtrim(f.keywordBox:GetText() or ""), "%s+", "")


    if keyword ~= "" then
        local other = Snippets:FindConflict(nil, keyword, f._editIndex)
        if other then
            ns.ShowThemedDialog({
                text = sformat(L["SNIPPET_KEYWORD_TAKEN_FMT"], keyword, other.name or "?"),
                messageColor = ns.GOLD_COLOR,
                acceptText = _G["OKAY"] or "Okay",
            })
            f.keywordBox:SetFocus()
            return
        end
    end
    local snippet = f._editIndex and list[f._editIndex]
    if not snippet then
        snippet = {}
        list[#list + 1] = snippet
    end
    snippet.name = name
    snippet.keyword = keyword ~= "" and keyword or nil
    if f._notesHost then



        local doc = f._notesHost:GetDocument()
        snippet.body = doc.body or ""
        snippet.decorations = doc.decorations and #doc.decorations > 0
            and doc.decorations or nil
        snippet.flat = EasyFind.API.CallAction("notes", "flatten", doc) or snippet.body
    else
        snippet.body = f.bodyBox:GetText() or ""
        snippet.decorations = nil
        snippet.flat = nil
    end
    f:Hide()
    RefreshSnippetRows()
end


function Snippets:DeleteWithConfirm(index)
    local list = SnippetList()
    local snippet = list and list[index]
    if not snippet then return end
    ns.ShowThemedDialog({
        text = sformat(L["SNIPPET_DELETE_CONFIRM"], snippet.name or ""),
        acceptText = _G["DELETE"] or "Delete",
        onAccept = function()
            local liveList = SnippetList()
            if liveList and liveList[index] then
                tremove(liveList, index)
            end
            if editorFrame and editorFrame:IsShown() and editorFrame._editIndex == index then
                editorFrame:Hide()
            end
            RefreshSnippetRows()
        end,
    })
end

local function DeleteFromEditor()
    local f = editorFrame
    if f and f._editIndex then
        Snippets:DeleteWithConfirm(f._editIndex)
    end
end

local function AnnotationHeight(fs)
    local h = fs:GetStringHeight() or 12
    if h < 12 then h = 12 end
    return mceil(h)
end





local handoffFrame

local function EnsureMacroHandoff()
    if handoffFrame then return handoffFrame end
    local f = CreateFrame("Frame", "EasyFindSnippetMacroHandoff", UIParent, "BackdropTemplate")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:SetFrameLevel(1005)
    f:SetWidth(DIALOG_W)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetPoint("CENTER", 0, 160)
    ns.StyleMenuPanel(f)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOPLEFT", DIALOG_PAD, -12)

    local y = -30
    f.copyBox = LabeledField(f, "", y, BODY_H, true)
    y = y - 14 - BODY_H

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.hint:SetPoint("TOPLEFT", DIALOG_PAD, y - 8)
    f.hint:SetWidth(DIALOG_W - DIALOG_PAD * 2)
    f.hint:SetJustifyH("LEFT")
    f.hint:SetWordWrap(true)
    f.hint:SetText(L["SNIPPET_MACRO_COPY_HINT"])

    local flashGap = 6
    local flash = Utils.AttachCopiedFlash(f.copyBox, f, f.hint, -flashGap)
    f:SetHeight(-(y - 8) + AnnotationHeight(f.hint) + flashGap + flash:GetHeight() + DIALOG_PAD)

    local function CloseHandoff() f:Hide() end
    f.copyBox:SetScript("OnEscapePressed", CloseHandoff)
    Utils.AttachEscClose(f, CloseHandoff)


    f:SetScript("OnUpdate", function(self)
        local inside = Utils.IsFrameVisiblyMouseOver(self)
        if not inside and not self._mouseWasInside
           and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) then
            self:Hide()
        end
        self._mouseWasInside = inside
    end)

    f.copyBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    f:Hide()
    handoffFrame = f
    return f
end

function Snippets.ShowMacroHandoff(text, name)
    local f = EnsureMacroHandoff()
    f.title:SetText(name or L["FILTER_SNIPPETS"])
    local r, g, b = ns.TooltipTextColor()
    f.title:SetTextColor(r, g, b)
    f.hint:SetTextColor(r, g, b)



    f.copyBox:SetText(Utils.ClipboardSafeText(text) or "")
    f:Show()
    f.copyBox:SetFocus()
    f.copyBox:HighlightText()
end

local function EnsureEditor()
    if editorFrame then return editorFrame end
    local f = CreateFrame("Frame", "EasyFindSnippetEditor", UIParent, "BackdropTemplate")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)


    f:SetFrameLevel(1000)
    f:SetWidth(DIALOG_W)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetPoint("CENTER", 0, 120)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    ns.StyleMenuPanel(f)

    f._chromeTexts = {}
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOPLEFT", DIALOG_PAD, -12)
    f._chromeTexts[#f._chromeTexts + 1] = f.title

    local y = -34
    local nameLabel, keywordLabel, bodyLabel
    f.nameBox, y, nameLabel = LabeledField(f, L["SNIPPET_NAME"], y, FIELD_H)
    y = y - 10
    f.keywordBox, y, keywordLabel = LabeledField(f, L["SNIPPET_KEYWORD"], y, FIELD_H)




    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.hint:SetPoint("TOPLEFT", DIALOG_PAD, y - 6)
    f.hint:SetWidth(DIALOG_W - DIALOG_PAD * 2)
    f.hint:SetJustifyH("LEFT")
    f.hint:SetWordWrap(true)
    f.hint:SetText(FormattedKeywordHint())
    y = y - 6 - AnnotationHeight(f.hint) - 10





    local trigBtn = ns.CreateCogButton(f)
    trigBtn:SetPoint("LEFT", f.title, "RIGHT", 6, 0)
    trigBtn:SetScript("OnClick", Snippets.ToggleTriggerMenu)
    local closeBtn = ns.CreateCloseX(f)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    f.closeBtn = closeBtn
    Utils.AttachDelayedTooltip(trigBtn, "ANCHOR_RIGHT", function()
        return sformat(L["SNIPPET_TRIGGER"], Snippets.TriggerChar()), L["SNIPPET_TRIGGER_NOTE"]
    end)
    f.trigBtn = trigBtn






    if EasyFind.API.LoadExtension("notes") and EasyFind.API.HasAction("notes", "attachEditor") then
        bodyLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bodyLabel:SetPoint("TOPLEFT", DIALOG_PAD, y)
        bodyLabel:SetText(L["SNIPPET_TEXT"])
        local host = EasyFind.API.CallAction("notes", "attachEditor", f, {
            width = DIALOG_W - DIALOG_PAD * 2,
            height = BODY_H,
            maxLetters = CHAT_MAX,
            onTextChanged = function() UpdateCharCounter(f) end,
        })
        f._notesHost = host
        host.container:ClearAllPoints()
        host.container:SetPoint("TOPLEFT", DIALOG_PAD, y - 14)
        f.bodyBox = host.editor
        y = y - 14 - (host.container:GetHeight() or (BODY_H + 28))
    else
        f.bodyBox, y, bodyLabel = LabeledField(f, L["SNIPPET_TEXT"], y, BODY_H, true)
        f.bodyBox:SetMaxLetters(CHAT_MAX)
        f.bodyBox:HookScript("OnTextChanged", function() UpdateCharCounter(f) end)
    end



    local bodyField = f.bodyBox:GetParent():GetParent()
    local counterHolder = CreateFrame("Frame", nil, f)
    counterHolder:SetSize(1, 1)
    counterHolder:SetPoint("BOTTOM", bodyField, "BOTTOM", 0, 4)
    counterHolder:SetFrameLevel((f.bodyBox:GetFrameLevel() or 1) + 2)
    f.charCounter = counterHolder:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.charCounter:SetPoint("BOTTOM", counterHolder, "BOTTOM", 0, 0)
    f.charCounter:SetTextColor(0.48, 0.48, 0.52, 1)


    f.note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.note:SetPoint("TOPLEFT", DIALOG_PAD, y - 8)
    f.note:SetWidth(DIALOG_W - DIALOG_PAD * 2)
    f.note:SetJustifyH("LEFT")
    f.note:SetWordWrap(true)
    f.note:SetText(L["SNIPPET_FORMAT_NOTE"])
    y = y - 8 - AnnotationHeight(f.note) - 8



    f.advToggle = CreateFrame("Button", nil, f)
    f.advToggle:SetSize(DIALOG_W - DIALOG_PAD * 2, 16)
    f.advToggle:SetPoint("TOPLEFT", DIALOG_PAD, y)
    f.advLabel = f.advToggle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.advLabel:SetPoint("LEFT")
    f.advToggle:SetScript("OnEnter", function() f.advLabel:SetAlpha(1) end)
    f.advToggle:SetScript("OnLeave", function() f.advLabel:SetAlpha(0.75) end)
    f.advLabel:SetAlpha(0.75)
    y = y - 16 - 6

    f.advBody = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.advBody:SetPoint("TOPLEFT", f.advToggle, "BOTTOMLEFT", 0, -2)
    f.advBody:SetWidth(DIALOG_W - DIALOG_PAD * 2)
    f.advBody:SetJustifyH("LEFT")
    f.advBody:SetWordWrap(true)
    f.advBody:SetText(L["SNIPPET_ADVANCED_BODY"])
    f.advBody:Hide()

    f._chromeTexts[#f._chromeTexts + 1] = nameLabel
    f._chromeTexts[#f._chromeTexts + 1] = keywordLabel
    f._chromeTexts[#f._chromeTexts + 1] = bodyLabel
    f._chromeTexts[#f._chromeTexts + 1] = f.hint
    f._chromeTexts[#f._chromeTexts + 1] = f.note
    f._chromeTexts[#f._chromeTexts + 1] = f.advLabel
    f._chromeTexts[#f._chromeTexts + 1] = f.advBody

    f.saveBtn = ns.CreateModernButton(f, _G["SAVE"] or "Save", 100, 22)
    f.cancelBtn = ns.CreateModernButton(f, _G["CANCEL"] or "Cancel", 100, 22)
    f.cancelBtn:SetPoint("RIGHT", f.saveBtn, "LEFT", -8, 0)
    f.deleteBtn = ns.CreateModernButton(f, _G["DELETE"] or "Delete", 100, 22)



    local baseButtonsY = y
    local baseHeight = -(y - 22) + DIALOG_PAD
    local function RelayoutAdvanced()
        local expanded = f.advBody:IsShown()
        f.advLabel:SetText(expanded
            and L["SNIPPET_ADVANCED"] .. " -"
            or L["SNIPPET_ADVANCED"] .. " +")
        local extra = expanded and (AnnotationHeight(f.advBody) + 8) or 0
        f.saveBtn:ClearAllPoints()
        f.saveBtn:SetPoint("TOPRIGHT", -DIALOG_PAD, baseButtonsY - extra)
        f.deleteBtn:ClearAllPoints()
        f.deleteBtn:SetPoint("TOPLEFT", DIALOG_PAD, baseButtonsY - extra)
        f:SetHeight(baseHeight + extra)
    end
    f._relayoutAdvanced = RelayoutAdvanced
    f.advToggle:SetScript("OnClick", function()
        f.advBody:SetShown(not f.advBody:IsShown())
        RelayoutAdvanced()
    end)
    RelayoutAdvanced()

    f.saveBtn:SetScript("OnClick", SaveEditor)
    f.cancelBtn:SetScript("OnClick", CloseEditor)
    f.deleteBtn:SetScript("OnClick", DeleteFromEditor)

    f.nameBox:SetScript("OnEnterPressed", function() f.keywordBox:SetFocus() end)
    f.keywordBox:SetScript("OnEnterPressed", function() f.bodyBox:SetFocus() end)
    f.nameBox:SetScript("OnTabPressed", function() f.keywordBox:SetFocus() end)
    f.keywordBox:SetScript("OnTabPressed", function() f.bodyBox:SetFocus() end)
    f.bodyBox:SetScript("OnTabPressed", function() f.nameBox:SetFocus() end)



    f.nameBox:SetScript("OnEscapePressed", UnfocusBox)
    f.keywordBox:SetScript("OnEscapePressed", UnfocusBox)
    f.bodyBox:SetScript("OnEscapePressed", UnfocusBox)
    Utils.AttachEscClose(f, CloseEditor)













    Utils.HookInsertLink(function(link)
        if not (link and link ~= "" and f:IsShown()) then return end
        local getActive = (ChatFrameUtil and ChatFrameUtil.GetActiveWindow)
            or ChatEdit_GetActiveWindow
        if getActive and getActive() then return end
        f.bodyBox:Insert(link)
    end)

    f:Hide()
    editorFrame = f
    return f
end

function Snippets:OpenEditor(index)
    local f = EnsureEditor()


    if f.advBody and f.advBody:IsShown() then
        f.advBody:Hide()
        if f._relayoutAdvanced then f._relayoutAdvanced() end
    end
    f._editIndex = index
    local list = SnippetList()
    local snippet = index and list and list[index]
    f.title:SetText(snippet and L["SNIPPET_EDIT_TITLE"] or L["SNIPPET_CREATE"])


    local r, g, b = ns.TooltipTextColor()
    for i = 1, #f._chromeTexts do
        f._chromeTexts[i]:SetTextColor(r, g, b)
    end
    f.nameBox:SetText(snippet and snippet.name or "")
    f.keywordBox:SetText(snippet and snippet.keyword or "")
    if f._notesHost then
        local doc
        if snippet and (snippet.flat or snippet.decorations) then
            doc = { body = snippet.body or "", decorations = snippet.decorations }
        elseif snippet and snippet.body and snippet.body ~= ""
           and EasyFind.API.HasAction("notes", "fromMarkdown") then


            doc = EasyFind.API.CallAction("notes", "fromMarkdown", snippet.body)
        else
            doc = { body = snippet and snippet.body or "", decorations = {} }
        end
        f._notesHost:SetDocument(doc)
    else
        f.bodyBox:SetText(snippet and snippet.body or "")
    end
    UpdateCharCounter(f)
    f.deleteBtn:SetShown(snippet ~= nil)
    f:Show()
    f.nameBox:SetFocus()
end




function Snippets:OpenEditorPrefilled(body, name)
    self:OpenEditor(nil)
    local f = EnsureEditor()
    if f._notesHost then
        f._notesHost:SetDocument({ body = body or "", decorations = {} })
    else
        f.bodyBox:SetText(body or "")
    end
    f.nameBox:SetText(name or "")
    UpdateCharCounter(f)
    f.keywordBox:SetFocus()
end



EasyFind.API.RegisterExtension({
    id = "snippets", name = L["FILTER_SNIPPETS"], description = L["APP_DESC_SNIPPETS"],
    icon = ns.SNIPPET_ICON_TEX, iconCoords = ns.SNIPPET_ICON_COORDS,
    hideFromSearch = true,
    open = function() EasyFind.API.OpenSettings("snippets") end,
    isOpen = function() return EasyFind.API.IsSettingsOpen("snippets") end,
    close = EasyFind.API.CloseSettings,
})



EasyFind.API.RegisterAction("snippets", "run", function(name) return Snippets:RunByName(name) end)
EasyFind.API.RegisterAction("snippets", "create", function(body, name) Snippets:OpenEditorPrefilled(body, name) end)

EasyFind.API.RegisterAction("snippets", "attachExpansion", Snippets.AttachExpansion)



local function TriggerText(fmt)
    return function() return Utils.sformat(L[fmt], Snippets.TriggerChar() or "\\") end
end
EasyFind.API.RegisterSearchProvider({
    key = "snippets", category = "Snippet", extension = "snippets",
    label = L["FILTER_SNIPPETS"], icon = ns.SNIPPET_ICON_TEX, iconCoords = ns.SNIPPET_ICON_COORDS,
    words = { "snippet", "snippets", "snip" }, lowResults = true, eager = true,
    aliases = { "snip", "snips", "snippet", "snippets" },
    options = {
        ns.Extensions.DbOption("snippetChatExpansion", TriggerText("SNIPPET_EXPAND_IN_CHAT"),
            TriggerText("SNIPPET_KEYWORD_HINT")),
    },
    rows = function() return Snippets:BuildSearchData() end,
    select = function(row) Snippets:EditByName(row.name) end,
})

return Snippets
