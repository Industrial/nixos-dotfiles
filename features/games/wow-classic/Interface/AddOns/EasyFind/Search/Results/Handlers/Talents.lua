local _, ns = ...

local Handlers = ns.ResultHandlers
local Openers = ns.SearchOpeners
local Utils = ns.Utils

local select, ipairs = Utils.select, Utils.ipairs



local function ScrollToTalent(button)
    local scroll = _G["PlayerTalentFrameScrollFrame"]
    local child = scroll and scroll.GetScrollChild and scroll:GetScrollChild()
    local top, at = child and child:GetTop(), button:GetTop()
    if not (top and at) then return end
    local want = top - at - (scroll:GetHeight() - button:GetHeight()) / 2
    scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScrollRange(), want)))
end

local function OpenClassicTalent(data)
    local highlight = ns.RequestGuide()
    local frame = _G["PlayerTalentFrame"]
    if not (frame and frame:IsShown()) then Openers:OpenButtonFrame("TalentMicroButton") end
    local tries, lit = 0, nil
    local function find()
        tries = tries + 1
        frame = _G["PlayerTalentFrame"]
        if frame and frame:IsShown() and highlight and highlight.HighlightFrame then
            local selectedTab = _G["PanelTemplates_GetSelectedTab"]
            local onTab = not selectedTab or selectedTab(frame) == data.talentTab
            local tab = _G["PlayerTalentFrameTab" .. data.talentTab]
            if not onTab and not data.talentTier and tab and tab:IsEnabled() then
                tab:Click()
                onTab = selectedTab(frame) == data.talentTab
            end

            if onTab and not (data.talentTier or data.talentIndex) then return end
            if onTab then
                local button = _G[data.talentTier
                    and ("PlayerTalentFrameTalentsTalentRow" .. data.talentTier .. "Talent" .. data.talentColumn)
                    or ("PlayerTalentFrameTalent" .. tostring(data.talentIndex))]
                if button and button:IsVisible() then
                    if not data.talentTier then ScrollToTalent(button) end
                    highlight:HighlightFrame(button)
                    return
                end
            elseif tab and tab ~= lit then
                lit = tab
                highlight:HighlightFrame(tab, nil, nil, true)
            end
        end
        if tries < 150 then Utils.SafeAfter(0.2, find) end
    end
    find()
end

function Handlers:OpenTalentInTalentsTab(data)
    if data.talentTab then return OpenClassicTalent(data) end
    local TALENTS_TAB = ns.SecureOpeners and ns.SecureOpeners.TAB_TALENTS or 2


    local api = Openers.Replacement and Openers.Replacement("talents")
    if api then


        api.Open("talents", "talent:" .. tostring(data.spellID))
        local highlight = ns.RequestGuide()
        local tries = 0
        local function find()
            tries = tries + 1
            local ok, btn = pcall(api.GetFrame, "talents", "talent:" .. tostring(data.spellID))
            if ok and btn and btn:IsVisible() and highlight and highlight.HighlightFrame then
                highlight:HighlightFrame(btn)
            elseif tries < 25 then
                Utils.SafeAfter(0.2, find)
            end
        end
        find()
        return
    end

    local function ensureFrameOnTab(attempt)
        local frame = _G["PlayerSpellsFrame"]
        if not (frame and frame:IsShown()) then
            Openers:OpenPlayerSpellsFrame(TALENTS_TAB)
            if attempt < 30 then
                Utils.SafeAfter(0.05, function() ensureFrameOnTab(attempt + 1) end)
            end
            return
        end
        if not Openers:EnsurePlayerSpellsTab(TALENTS_TAB) then


            if attempt < 30 then
                Utils.SafeAfter(0.05, function() ensureFrameOnTab(attempt + 1) end)
            end
            return
        end





        local talentsFrame = frame.TalentsFrame
        local targetLower = (data.name or ""):lower()

        local function nameOf(btn)
            if not btn or not btn.GetName then return nil end
            local n = btn:GetName()
            return n and n:lower() or nil
        end





        local function searchTree(frame, depth)
            if not frame or depth > 5 then return nil end
            if frame.SearchIcon and nameOf(frame) == targetLower then
                return frame
            end
            if frame.GetChildren then
                for i = 1, select("#", frame:GetChildren()) do
                    local found = searchTree(select(i, frame:GetChildren()), depth + 1)
                    if found then return found end
                end
            end
            return nil
        end

        local function findMatchingButton()
            if not talentsFrame then return nil end
            local containers = {
                talentsFrame.ButtonsParent,
                talentsFrame.HeroTalentsContainer,
                talentsFrame.SubTreeContainer,
            }
            for _, parent in ipairs(containers) do
                local found = searchTree(parent, 0)
                if found then return found end
            end
            return nil
        end

        local tries = 0
        local function showSpyglass()
            tries = tries + 1
            local btn = findMatchingButton()
            if btn and btn.SearchIcon and btn.SearchIcon.Show then



                if btn.SearchIcon.SetFrameStrata then
                    btn.SearchIcon:SetFrameStrata("HIGH")
                end
                if btn.SearchIcon.SetFrameLevel and btn.GetFrameLevel then
                    btn.SearchIcon:SetFrameLevel(btn:GetFrameLevel() + 10)
                end
                btn.SearchIcon:Show()
                local highlight = ns.RequestGuide()
                if highlight and highlight.RegisterTalentSearchIcon then
                    highlight:RegisterTalentSearchIcon(btn, targetLower, nameOf)
                end
                return
            end
            if tries < 20 then
                Utils.SafeAfter(0.05, showSpyglass)
            end
        end
        Utils.SafeAfter(0, showSpyglass)
    end

    ensureFrameOnTab(1)
end
