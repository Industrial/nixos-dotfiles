local _, ns = ...
















local Search = ns.Search
local Utils = ns.Utils
local L = ns.L

local CreateFrame = CreateFrame
local IsControlKeyDown = IsControlKeyDown

local RowCopy = {}
ns.RowCopy = RowCopy

local flashHolder, flashFade, flashText
local armedRow



local armedEasy = false
local hoverTarget


local hoverScanners = {}


local keyHandlers = {}





local function RowPayload(row, easy)
    if not row then return nil end
    if row._efCopyText then return row._efCopyText, nil end
    local data = row.data
    if not data or data.calculatorResult or data.calculatorExpression then return nil end
    if easy and ns.ResultLinks and ns.ResultLinks.BuildShareText then
        local text = ns.ResultLinks:BuildShareText(data)
        if text then return text, nil, true end
    end
    if data.copyText then return data.copyText, nil end


    if data.clipText then return Utils.ClipboardSafeText(data.clipText), data.clipLink end
    local link = ns.GetResultLink and ns.GetResultLink(data)
    if link and link ~= "" then return Utils.ClipboardSafeText(link), link end



    local name = data.name
    if name and Utils.StripMarkup then name = Utils.StripMarkup(name) end
    if not name or name == "" then return nil end
    return Utils.ClipboardSafeText(name), nil
end




local function TargetIcon(row)
    if not row then return nil end
    local tex = row.icon or row.tex
    if tex and tex.GetTexture and (not tex.IsShown or tex:IsShown()) then
        local t = tex:GetTexture()
        if t then return t end
    end
    if row._efCopyIcon then return row._efCopyIcon end
    return row.data and row.data.icon or nil
end

local function EnsureFlash()
    if flashHolder then return flashHolder end
    flashHolder = CreateFrame("Frame", nil, UIParent)
    flashHolder:SetFrameStrata("TOOLTIP")
    flashHolder:SetSize(80, 16)
    flashHolder:Hide()
    local text = flashHolder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text._efOwnColor = true
    text:SetPoint("CENTER")
    text:SetText(L["COPIED"])
    text:SetTextColor(Utils.RGB(ns.COPIED_COLOR, 1))
    flashText = text
    flashFade = flashHolder:CreateAnimationGroup()
    local alpha = flashFade:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0)
    alpha:SetStartDelay(0.7)
    alpha:SetDuration(0.6)
    flashFade:SetScript("OnFinished", function() flashHolder:Hide() end)
    return flashHolder
end




local function CopiedText()
    return armedEasy and L["COPIED_EASYFIND_LINK"] or L["COPIED"]
end

local function FlashCopied()
    if not (armedRow and armedRow:IsShown()) then return end



    local hint = armedRow._efCopyHint
    if hint then
        hint:SetText(CopiedText())
        hint:SetTextColor(Utils.RGB(ns.COPIED_COLOR, 1))
        return
    end
    local holder = EnsureFlash()
    flashFade:Stop()
    flashText:SetText(CopiedText())
    holder:SetSize(math.max(80, math.floor(flashText:GetStringWidth() + 0.5) + 12), 16)
    holder:ClearAllPoints()

    if armedRow._efCopyText then
        holder:SetPoint("CENTER", armedRow, "CENTER", 0, 0)
    else
        holder:SetPoint("RIGHT", armedRow, "RIGHT", -6, 0)
    end
    holder:SetAlpha(1)
    holder:Show()
    flashFade:Play()
end





local client = {
    OnCopied = FlashCopied,
    HoldsFocus = function() return armedRow ~= nil and IsControlKeyDown() end,
    OnDisarm = function() armedRow = nil end,


    OnCtrlUp = function() RowCopy:Disarm(true) end,
    OnShift = function(down)
        if armedRow and (down or armedEasy) then RowCopy:ArmFor(armedRow, down) end
    end,
    OnKey = function(key)
        for i = 1, #keyHandlers do
            if keyHandlers[i](key) then return end
        end
        local navFrame = Search.GetNavFrame and Search:GetNavFrame()
        if navFrame and navFrame:IsKeyboardEnabled() then
            local onKeyDown = navFrame:GetScript("OnKeyDown")
            if onKeyDown then onKeyDown(navFrame, key) end
            return
        end


        RowCopy:Disarm(true)
    end,
}

function RowCopy:Disarm(restoreFocus)
    if not armedRow then return end
    Utils.DisarmClipboardBox(restoreFocus, client)
end

function RowCopy:CanCopy(row, easy)
    return RowPayload(row, easy) ~= nil
end

function RowCopy:ArmFor(row, easy)
    local payload, link, isEasy = RowPayload(row, easy)
    if not payload then return false end


    local owner = Utils.ClipboardBoxClient()
    if owner and owner ~= client then return false end
    armedRow, armedEasy = row, isEasy or false
    Utils.ArmClipboardBox(payload, link, client, TargetIcon(row))
    return true
end



function RowCopy:ArmForData(data)
    local buttons = Search.GetResultButtons and Search:GetResultButtons()
    if not buttons then return false end
    for i = 1, #buttons do
        local row = buttons[i]
        if row and row:IsShown() and row.data == data then
            return self:ArmFor(row, IsShiftKeyDown())
        end
    end
    return false
end










function RowCopy:OnRowHover(row)
    hoverTarget = row
    if row then
        if IsControlKeyDown() then
            self:ArmFor(row, IsShiftKeyDown())
        end
    elseif armedRow and not IsControlKeyDown() then
        self:Disarm(true)
    end
end

function RowCopy:RegisterHoverScanner(fn)
    hoverScanners[#hoverScanners + 1] = fn
end

function RowCopy:RegisterKeyHandler(fn)
    keyHandlers[#keyHandlers + 1] = fn
end








local function ResolveHovered(easy)


    if hoverTarget and not hoverTarget._efScanned and hoverTarget:IsShown() and hoverTarget:IsMouseOver() then
        return hoverTarget
    end
    local buttons = Search.GetResultButtons and Search:GetResultButtons()
    if buttons then
        for i = 1, #buttons do
            local row = buttons[i]
            if not row or not row:IsShown() then break end
            if row:IsMouseOver() and RowPayload(row, easy) then return row end
        end
    end
    for i = 1, #hoverScanners do
        local target = hoverScanners[i]()
        if target and RowPayload(target, easy) then
            target._efScanned = true
            return target
        end
    end
    return nil
end

local function ArmHovered()
    local easy = IsShiftKeyDown()
    local target = ResolveHovered(easy)
    if not target then return end
    hoverTarget = target
    RowCopy:ArmFor(target, easy)
end



function RowCopy:ArmHovered()
    ArmHovered()
end

function RowCopy:Initialize()



    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("MODIFIER_STATE_CHANGED")
    watcher:SetScript("OnEvent", function(_, _, key, state)
        if key == "LSHIFT" or key == "RSHIFT" then
            client.OnShift(state == 1)
            return
        end
        if key ~= "LCTRL" and key ~= "RCTRL" then return end
        if state == 1 then
            ArmHovered()
        else
            RowCopy:Disarm(true)
        end
    end)








    local searchFrame = Search.GetSearchFrame and Search:GetSearchFrame()
    if searchFrame and searchFrame.editBox then
        searchFrame.editBox:HookScript("OnKeyDown", function(self, key)
            if not self:HasFocus() then return end
            if key == "LCTRL" or key == "RCTRL" or (key == "C" and IsControlKeyDown()) then
                ArmHovered()
            elseif (key == "LSHIFT" or key == "RSHIFT") and IsControlKeyDown() then


                ArmHovered()
            end
        end)
    end
    local resultsFrame = Search.GetResultsFrame and Search:GetResultsFrame()
    if resultsFrame then
        resultsFrame:HookScript("OnHide", function() RowCopy:Disarm(false) end)
    end
end

return RowCopy
