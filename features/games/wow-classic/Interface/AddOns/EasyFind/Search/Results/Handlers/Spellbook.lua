local _, ns = ...

local Handlers = ns.ResultHandlers
local Openers = ns.SearchOpeners
local Utils = ns.Utils

local GetButtonText = Utils.GetButtonText
local select, ipairs = Utils.select, Utils.ipairs
local slower = Utils.slower
local mceil = math.ceil
local mabs = math.abs
local InCombatLockdown = InCombatLockdown

local function ExtractSlot(value)
    return value.slotIndex
        or value.spellBookIndex
        or value.spellBookItemSlotIndex
        or value.spellBookItemIndex
        or value.itemIndex
        or value.slot
        or value.index
end

local function ExtractBank(value)
    return value.spellBank
        or value.spellBookBank
        or value.spellBookItemBank
        or value.bank
end

local function ExtractSpecID(value)
    local specID = value.specID
    if specID ~= nil and specID ~= 0 then return specID end
    if value.spellBookSpecID ~= nil then return value.spellBookSpecID end
    local offSpecID = value.offSpecID
    if offSpecID ~= nil and offSpecID ~= 0 then return offSpecID end
    return specID
end

local function HasSlotMismatch(value, targetSlot, targetBank)
    if not targetSlot then return false end
    local valueSlot = ExtractSlot(value)
    if not valueSlot then return false end
    if valueSlot ~= targetSlot then return true end
    if not targetBank then return false end
    local valueBank = ExtractBank(value)
    if valueBank ~= nil and valueBank ~= targetBank then return true end
    return false
end

local function HasSpecMismatch(value, targetSpecID)
    if targetSpecID == nil then return false end
    local valueSpecID = ExtractSpecID(value)
    return valueSpecID ~= nil and valueSpecID ~= targetSpecID
end

local function SpellRecordMatches(value, target, seen)
    if not value then return false end
    local vt = type(value)
    if vt == "number" then
        if target.spellBookSpecID ~= nil or target.spellBookIndex then return false end
        return value == target.spellID or value == target.spellBookSpellID
    end
    if vt ~= "table" then return false end
    seen = seen or {}
    if seen[value] then return false end
    seen[value] = true

    local targetSpell = target.spellBookSpellID or target.spellID
    local targetSlot = target.spellBookIndex
    local targetBank = target.spellBookBank
    local targetSpecID = target.spellBookSpecID

    if targetSpecID ~= nil then
        local specID = ExtractSpecID(value)
        if specID and specID == targetSpecID then
            local slot = ExtractSlot(value)
            if slot and targetSlot and slot == targetSlot then return true end
            if targetSpell and (value.spellID == targetSpell
                or value.actionID == targetSpell) then return true end
        end
    end

    if targetSlot then
        local bank = ExtractBank(value)
        local slot = ExtractSlot(value)
        if slot == targetSlot
            and (not targetBank or bank == nil or bank == targetBank)
            and not HasSpecMismatch(value, targetSpecID) then
            return true
        end
    end






    local needsDisambig = target.spellBookSpecID ~= nil
        or target.spellBookIndex ~= nil
    local function valueHasMatchingDisambig()
        local valueSpec = ExtractSpecID(value)
        if targetSpecID and valueSpec and valueSpec == targetSpecID then
            return true
        end
        local valueSlot = ExtractSlot(value)
        if targetSlot and valueSlot and valueSlot == targetSlot then
            return true
        end
        return false
    end

    if targetSpell and (value.spellID == targetSpell
        or value.spellId == targetSpell
        or value.actionID == targetSpell
        or value.actionId == targetSpell
        or value.id == targetSpell) then
        if not HasSpecMismatch(value, targetSpecID)
            and not HasSlotMismatch(value, targetSlot, targetBank)
            and (not needsDisambig or valueHasMatchingDisambig()) then
            return true
        end
    end

    local targetName = target.nameLower or (target.spellName and slower(target.spellName))
    if targetName and value.name and slower(value.name) == targetName then
        if not HasSpecMismatch(value, targetSpecID)
            and not HasSlotMismatch(value, targetSlot, targetBank)
            and (not needsDisambig or valueHasMatchingDisambig()) then
            return true
        end
    end

    if value.data and value.data ~= value and SpellRecordMatches(value.data, target, seen) then return true end
    if value.elementData and value.elementData ~= value and SpellRecordMatches(value.elementData, target, seen) then return true end
    if value.spellInfo and value.spellInfo ~= value and SpellRecordMatches(value.spellInfo, target, seen) then return true end
    if value.spellBookItemInfo and value.spellBookItemInfo ~= value and SpellRecordMatches(value.spellBookItemInfo, target, seen) then return true end
    if value.spellBookItemData and value.spellBookItemData ~= value and SpellRecordMatches(value.spellBookItemData, target, seen) then return true end
    if value.itemInfo and value.itemInfo ~= value and SpellRecordMatches(value.itemInfo, target, seen) then return true end
    return false
end

local function SpellFrameMatchesSelf(frame, target)
    if not frame then return false end

    local targetSlot = target.spellBookIndex
    local targetBank = target.spellBookBank
    if targetSlot and frame.GetItemSlotIndex then
        local sok, slot = pcall(frame.GetItemSlotIndex, frame)
        if sok and slot == targetSlot then
            if not targetBank or not frame.GetSpellBookItemBank then
                return true
            end
            local bok, bank = pcall(frame.GetSpellBookItemBank, frame)
            if not bok or bank == nil or bank == targetBank then
                return true
            end
        end
    end

    if frame.GetElementData then
        local ok, data = pcall(frame.GetElementData, frame)
        if ok and SpellRecordMatches(data, target) then return true end
    end
    if frame.GetSpellID then
        local ok, id = pcall(frame.GetSpellID, frame)
        if ok and SpellRecordMatches(id, target) then return true end
    end
    if frame.GetSpellBookItemInfo then
        local ok, info = pcall(frame.GetSpellBookItemInfo, frame)
        if ok and SpellRecordMatches(info, target) then return true end
    end
    if SpellRecordMatches(frame.data, target) then return true end
    if SpellRecordMatches(frame.elementData, target) then return true end
    if SpellRecordMatches(frame.spellInfo, target) then return true end
    if SpellRecordMatches(frame.spellBookItemInfo, target) then return true end
    if SpellRecordMatches(frame.spellBookItemData, target) then return true end
    return false
end

local function SpellFrameMatches(frame, target)
    if SpellFrameMatchesSelf(frame, target) then return true end
    if frame and frame.GetParent then
        local parent = frame:GetParent()
        if parent and SpellFrameMatchesSelf(parent, target) then return true end
        if parent and parent.GetParent then
            local gp = parent:GetParent()
            if gp and SpellFrameMatchesSelf(gp, target) then return true end
        end
    end
    return false
end

local function SpellFrameTextMatches(frame, target)
    local targetName = target and (target.nameLower or (target.spellName and slower(target.spellName)))
    if not targetName then return false end
    local text = GetButtonText(frame)
    return text and slower(text) == targetName
end

local function GetTabSkillLineName(tab)
    if not tab then return nil end
    if type(tab.tabText) == "string" and tab.tabText ~= "" then
        return tab.tabText
    end
    if tab.skillLineInfo and type(tab.skillLineInfo.name) == "string" then
        return tab.skillLineInfo.name
    end
    if type(tab.skillLine) == "table" and type(tab.skillLine.name) == "string" then
        return tab.skillLine.name
    end
    if tab.elementData and type(tab.elementData.name) == "string" then
        return tab.elementData.name
    end
    if tab.GetElementData then
        local ok, ed = pcall(tab.GetElementData, tab)
        if ok and ed and type(ed.name) == "string" then return ed.name end
    end
    if tab.tooltipText and type(tab.tooltipText) == "string" then
        return tab.tooltipText
    end
    if tab.GetText then
        local ok, txt = pcall(tab.GetText, tab)
        if ok and type(txt) == "string" and txt ~= "" then return txt end
    end
    local btnText = GetButtonText(tab)
    if btnText and btnText ~= "" then return btnText end
    return nil
end

local function FindSpellbookCategoryTab(frame, data)
    local book = frame and frame.SpellBookFrame
    local tabSystem = book and book.CategoryTabSystem
    if not tabSystem or not tabSystem.GetChildren then return nil end

    local targetName = data and data.spellBookCategoryName
    local targetLower = targetName and slower(targetName)
    local targetIsGeneral = targetLower == slower(_G.GENERAL or "general")

    local seen = {}
    local candidates = {}
    local function add(tab)
        if tab and not seen[tab] and tab.Click then
            seen[tab] = true
            candidates[#candidates + 1] = tab
        end
    end
    if tabSystem.tabs then
        for _, tab in ipairs(tabSystem.tabs) do add(tab) end
    end
    local children = { tabSystem:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        if child and child:IsShown() then add(child) end
    end

    local generalLower = slower(_G.GENERAL or "general")
    local function isGeneralTab(tab)
        local name = GetTabSkillLineName(tab)
        if name and slower(name) == generalLower then return true end
        local text = GetButtonText(tab)
        if text and slower(text) == generalLower then return true end
        return false
    end

    if targetIsGeneral then
        for i = 1, #candidates do
            if isGeneralTab(candidates[i]) then return candidates[i] end
        end
    else



        if targetLower then
            for i = 1, #candidates do
                local name = GetTabSkillLineName(candidates[i])
                if name and slower(name) == targetLower then
                    return candidates[i]
                end
            end
        end
        local classLower = UnitClass and slower(UnitClass("player") or "") or ""
        for i = 1, #candidates do
            local name = GetTabSkillLineName(candidates[i])
            if name and classLower ~= "" and slower(name) == classLower then
                return candidates[i]
            end
        end
        for i = 1, #candidates do
            if not isGeneralTab(candidates[i]) then return candidates[i] end
        end
    end

    return nil
end

local function IsCategoryTabSelected(frame, tab)
    local book = frame and frame.SpellBookFrame
    local sys = book and book.CategoryTabSystem
    local sel = sys and sys.selectedTabID
    if sel and tab.GetTabID then
        local ok, id = pcall(tab.GetTabID, tab)
        if ok and id then return id == sel end
    end
    if tab.IsSelected then
        local ok, isSel = pcall(tab.IsSelected, tab)
        if ok then return isSel and true or false end
    end
    return false
end

local function GetSpellbookPagedFrame(frame)
    local book = frame and frame.SpellBookFrame
    return book and (book.PagedSpellsFrame or book) or nil
end

local function SpellbookPageButton(frame, key)
    local paged = GetSpellbookPagedFrame(frame)
    local controls = paged and paged.PagingControls
    return controls and controls[key] or nil
end

local function CanClickButton(btn)
    if not btn or not btn:IsShown() then return false end
    if btn.IsEnabled then
        local ok, enabled = pcall(btn.IsEnabled, btn)
        if ok then return enabled end
    end
    return btn.Click ~= nil
end

local function GetSpellbookDataProvider(paged)
    if not paged then return nil, nil end
    local function probe(frame)
        if not frame then return nil end
        if frame.GetDataProvider then
            local ok, dp = pcall(frame.GetDataProvider, frame)
            if ok and dp then return dp end
        end
        return nil
    end
    local dp = probe(paged)
    if dp then return dp, paged end
    if paged.GetChildren then
        for ci = 1, select("#", paged:GetChildren()) do
            local child = select(ci, paged:GetChildren())
            local cdp = probe(child)
            if cdp then return cdp, child end
            if child and child.GetChildren then
                for gi = 1, select("#", child:GetChildren()) do
                    local gc = select(gi, child:GetChildren())
                    local gdp = probe(gc)
                    if gdp then return gdp, gc end
                end
            end
        end
    end
    return nil, nil
end

local function FindSpellElementInSection(paged, data)
    local dp = GetSpellbookDataProvider(paged)
    if not dp then return nil end

    local size = dp.GetSize and dp:GetSize() or 0
    if size == 0 and not dp.Enumerate then return nil end

    local targetSpellID = data.spellBookSpellID or data.spellID
    local targetSlot = data.spellBookIndex
    local targetBank = data.spellBookBank
    local targetSpecID = data.spellBookSpecID
    local targetNameLower = data.nameLower
        or (data.spellName and slower(data.spellName))
        or (data.name and slower(data.name))
    local targetSectionLower = data.spellBookCategoryName
        and slower(data.spellBookCategoryName)

    local currentSection
    local fallback
    local function inspect(elem)
        if elem then
            local info = elem.spellBookItemInfo or elem.spellInfo or elem.spellBookItemData
            local isSpellElement = info or elem.spellID or elem.actionID or ExtractSlot(elem)
            if not isSpellElement then
                local hdr = elem.name or elem.title or elem.text or elem.header
                if type(hdr) == "string" and hdr ~= "" then
                    currentSection = slower(hdr)
                end
            else
                info = info or elem
                local elemSlot = ExtractSlot(elem) or ExtractSlot(info)
                local elemBank = ExtractBank(elem) or ExtractBank(info)
                local elemSpecID = ExtractSpecID(elem) or ExtractSpecID(info)
                local specOK = targetSpecID == nil or elemSpecID == nil
                    or elemSpecID == targetSpecID
                local match = false
                if specOK and targetSlot and elemSlot == targetSlot
                    and (not targetBank or elemBank == nil or elemBank == targetBank) then
                    match = true
                elseif specOK and targetSpellID
                    and not HasSlotMismatch(elem, targetSlot, targetBank)
                    and not HasSlotMismatch(info, targetSlot, targetBank)
                    and (elem.spellID == targetSpellID
                        or elem.actionID == targetSpellID
                        or info.spellID == targetSpellID
                        or info.actionID == targetSpellID) then
                    match = true
                elseif specOK and targetNameLower and info.name
                    and not HasSlotMismatch(elem, targetSlot, targetBank)
                    and not HasSlotMismatch(info, targetSlot, targetBank)
                    and slower(info.name) == targetNameLower then
                    match = true
                end
                if match then
                    if targetSectionLower and currentSection == targetSectionLower then
                        return elem
                    end
                    fallback = fallback or elem
                end
            end
        end
        return nil
    end

    if dp.Enumerate then
        for a, b in dp:Enumerate() do
            local found = inspect(b or a)
            if found then return found end
        end
    else
        for i = 1, size do
            local elem = dp.Find and dp:Find(i)
            local found = inspect(elem)
            if found then return found end
        end
    end
    return fallback
end



function Handlers.ResolveLiveSpellBookSlot(data)
    local spellID = data and (data.spellBookSpellID or data.spellID)
    if not spellID then return nil end
    local SBOOK = C_SpellBook
    if not SBOOK then return nil end
    if SBOOK.FindSpellBookSlotForSpell then
        local ok, slot, bank = pcall(SBOOK.FindSpellBookSlotForSpell, spellID)
        if ok and type(slot) == "number" then return slot, bank end
    end
    if not SBOOK.GetNumSpellBookSkillLines then return nil end
    local bankEnum = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    local numLines = SBOOK.GetNumSpellBookSkillLines() or 0
    for li = 1, numLines do
        local info = SBOOK.GetSpellBookSkillLineInfo(li)
        if info and info.itemIndexOffset and info.numSpellBookItems then
            for si = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local item = SBOOK.GetSpellBookItemInfo(si, bankEnum)
                if item and item.spellID == spellID then
                    return si, bankEnum
                end
            end
        end
    end
    return nil
end
















function Handlers.GetSpellbookNavPlan(data)
    if not (data and data.spellID) then return nil, "no spell data" end
    if InCombatLockdown() then return nil, "in combat" end
    local frame = _G["PlayerSpellsFrame"]
    local root = frame and frame:IsShown() and frame.SpellBookFrame
    if not root or not root:IsShown() then return nil, "spellbook not shown" end

    local paged = GetSpellbookPagedFrame(frame)
    local controls = paged and paged.PagingControls
    local viewDataList = paged and paged.viewDataList
    local pageReason = "no paging state"
    if controls and controls.GetCurrentPage and viewDataList then




        local liveSlot, liveBank = Handlers.ResolveLiveSpellBookSlot(data)
        if not liveSlot then
            pageReason = "no live spellbook slot for spell"
        else
            local viewsPerPage = paged.viewsPerPage or 1
            local targetPage
            for viewIndex = 1, #viewDataList do
                local viewData = viewDataList[viewIndex]
                for i = 1, #viewData do
                    local elementData = viewData[i]
                    if not elementData.isSpacer and not elementData.isHeader
                       and elementData.slotIndex == liveSlot
                       and (liveBank == nil or elementData.spellBank == nil
                            or elementData.spellBank == liveBank) then
                        targetPage = mceil(viewIndex / viewsPerPage)
                        break
                    end
                end
                if targetPage then break end
            end
            if not targetPage then
                pageReason = "slot " .. liveSlot .. " not in view data"
            else
                local ok, currentPage = pcall(controls.GetCurrentPage, controls)
                if not ok or type(currentPage) ~= "number" then
                    return nil, "no current page"
                end
                local delta = targetPage - currentPage
                if delta == 0 then return nil, "already on page " .. targetPage end
                local pageBtn = SpellbookPageButton(frame,
                    delta > 0 and "NextPageButton" or "PrevPageButton")
                if not pageBtn then return nil, "no page button" end
                return {
                    button = pageBtn, step = "page", delta = delta,







                    presses = mabs(delta),
                }
            end
        end
    end

    local categoryTab = FindSpellbookCategoryTab(frame, data)
    if categoryTab and not IsCategoryTabSelected(frame, categoryTab) then
        return { button = categoryTab, alsoRelease = false, step = "category" }
    end
    return nil, pageReason
end

local function FindVisibleButtonForElement(paged, elem)
    if not elem then return nil end
    local _, host = GetSpellbookDataProvider(paged)
    if host and host.EnumerateFrames then
        for _, f in host:EnumerateFrames() do
            if f and f:IsShown() and f.GetElementData then
                local ok, ed = pcall(f.GetElementData, f)
                if ok and ed == elem then return f end
            end
        end
    end
    return nil
end




function Handlers.IsSpellVisibleInSpellbook(data)
    local frame = _G["PlayerSpellsFrame"]
    local root = frame and frame:IsShown() and frame.SpellBookFrame
    if not root or not root:IsShown() then return false end
    local paged = GetSpellbookPagedFrame(frame) or root
    if not paged.EnumerateFrames then return false end
    for _, f in paged:EnumerateFrames() do
        if f and f:IsShown() and SpellFrameMatches(f, data) then
            return true
        end
    end
    return false
end

local function FindSpellbookButton(root, target, scroll, candidate)
    if not root then return nil end
    local nextCandidate = candidate
    if root.Click then
        nextCandidate = root
    elseif root.GetScript then
        local ok, onClick = pcall(root.GetScript, root, "OnClick")
        if ok and onClick then nextCandidate = root end
    end
    if root.EnumerateFrames and root.GetDataProvider then
        if scroll then
            Utils.ScrollBoxScrollTo(root, function(data)
                return SpellRecordMatches(data, target)
            end)
        end
        local hasID = target and (target.spellBookSpellID or target.spellID)
        local btn = Utils.ScrollBoxFindButton(root, function(frame)
            if SpellFrameMatches(frame, target) then return true end
            if not hasID and SpellFrameTextMatches(frame, target) then return true end
            return false
        end)
        if btn then return btn end
    end
    local hasID = target and (target.spellBookSpellID or target.spellID)
    if SpellFrameMatches(root, target) then
        return nextCandidate or root
    end
    if not hasID and SpellFrameTextMatches(root, target) then
        return nextCandidate or root
    end
    if root.GetChildren then
        for i = 1, select("#", root:GetChildren()) do
            local child = select(i, root:GetChildren())
            if child and child:IsShown() then
                local found = FindSpellbookButton(child, target, scroll, nextCandidate)
                if found then return found end
            end
        end
    end
    return nil
end



local function OpenAbilityInReplacement(api, data, stepGuide)
    local highlight = ns.RequestGuide()
    local id = data.spellID
    if not stepGuide then api.Open("spellBook", "spell:" .. id) end
    local tries = 0
    local function find()
        tries = tries + 1
        local book = api.GetFrame("spellBook")
        local btn = book and book:IsVisible() and api.GetFrame("spellBook", "spell:" .. id)
        if btn and btn:IsVisible() and highlight and highlight.HighlightFrame then
            highlight:HighlightFrame(btn, nil, function() return api.SpellOnButton(btn) == id end)
            return
        end
        if stepGuide and not (book and book:IsVisible()) then
            local micro = Openers.MicroButton("PlayerSpellsMicroButton")
            if micro and highlight and highlight.HighlightFrame then highlight:HighlightFrame(micro, nil, nil, true) end
        end
        if tries < 150 then Utils.SafeAfter(0.2, find) end
    end
    find()
end



local function ClassicSpellSlot(name)
    local numTabs, tabInfo, itemName = _G["GetNumSpellTabs"], _G["GetSpellTabInfo"], _G["GetSpellBookItemName"]
    if not (numTabs and tabInfo and itemName and name) then return nil end
    for tab = 1, numTabs() or 0 do
        local _, _, offset, numSlots = tabInfo(tab)
        offset = offset or 0
        for slot = offset + (numSlots or 0), offset + 1, -1 do
            if itemName(slot, "spell") == name then return tab, slot - offset end
        end
    end
    return nil
end




local function ClassicTarget(name)
    local tab, index = ClassicSpellSlot(name)
    if not tab then return nil end
    local book = _G["SpellBookFrame"]
    if book.selectedSkillLine ~= tab then return _G["SpellBookSkillLineTab" .. tab] end
    local perPage = _G["SPELLS_PER_PAGE"] or 12
    local page = math.floor((index - 1) / perPage) + 1
    local current = _G["SpellBook_GetCurrentPage"] and _G["SpellBook_GetCurrentPage"]() or 1
    if page ~= current then
        return _G[page > current and "SpellBookNextPageButton" or "SpellBookPrevPageButton"]
    end
    return _G["SpellButton" .. ((index - 1) % perPage + 1)], true
end



local function OpenAbilityInClassicSpellbook(data, stepGuide)
    local highlight = ns.RequestGuide()
    local book = _G["SpellBookFrame"]
    if not (book and book:IsShown()) then
        if stepGuide then
            if highlight and highlight.HighlightFrame then
                highlight:HighlightFrame(_G["SpellbookMicroButton"], nil, nil, true)
            end
        else
            Openers:OpenButtonFrame("SpellbookMicroButton")
        end
    end
    local name = data.spellName or data.name
    local tries, lit = 0, nil
    local function find()
        tries = tries + 1
        book = _G["SpellBookFrame"]
        if book and book:IsShown() and highlight and highlight.HighlightFrame then
            local target, isSpell = ClassicTarget(name)
            if target and target ~= lit then
                lit = target
                highlight:HighlightFrame(target, nil, nil, true)
            end
            if isSpell then return end
        end
        if tries < 150 then Utils.SafeAfter(0.2, find) end
    end
    find()
end

function Handlers:OpenAbilityInSpellbook(data, stepGuide)
    local replaced = Openers.Replacement and data.spellID and Openers.Replacement("spellBook")
    if replaced then return OpenAbilityInReplacement(replaced, data, stepGuide) end
    if ns.Caps and ns.Caps.classic and _G["SpellbookMicroButton"] then
        return OpenAbilityInClassicSpellbook(data, stepGuide)
    end
    local highlight = ns.RequestGuide()
    local targetElement

    local spellbookTab = ns.SecureOpeners and ns.SecureOpeners.TAB_SPELLBOOK or 3
    local wasShown = false






    local function openState()
        local frame = _G["PlayerSpellsFrame"]
        if frame and frame:IsShown() then
            wasShown = true
            if Openers:EnsurePlayerSpellsTab(spellbookTab) then return nil end
            return "tab"
        end
        if wasShown then return "closed" end
        if stepGuide then


            local micro = _G["PlayerSpellsMicroButton"]
            if micro and micro:IsShown() and highlight and highlight.HighlightFrame then
                highlight:HighlightFrame(micro, nil, nil, true)
            end
            return "menu"
        end
        Openers:OpenPlayerSpellsFrame(spellbookTab)
        return "opening"
    end














    local HUMAN_WAIT_TICKS = 150
    local humanWaits = 0
    local function waitForHardwareClick(reveal, attempt)
        humanWaits = humanWaits + 1
        if humanWaits < HUMAN_WAIT_TICKS then
            Utils.SafeAfter(0.2, function() reveal(attempt) end)
        end
    end





    local pageSweepDir = "next"

    local function reveal(attempt)
        local state = openState()
        if state == "closed" then return end
        if state == "opening" then
            if attempt < 36 then
                Utils.SafeAfter(0.05, function() reveal(attempt + 1) end)
            end
            return
        end
        if state == "menu" or state == "tab" then
            waitForHardwareClick(reveal, attempt)
            return
        end
        local frame = _G["PlayerSpellsFrame"]
        local root = frame and frame.SpellBookFrame
        if not root or not root:IsShown() then
            if attempt < 36 then
                Utils.SafeAfter(0.05, function() reveal(attempt + 1) end)
            end
            return
        end



        local categoryTab = FindSpellbookCategoryTab(frame, data)
        if categoryTab and not IsCategoryTabSelected(frame, categoryTab) then
            if highlight and highlight.HighlightFrame then
                highlight:HighlightFrame(categoryTab, nil, nil, true)
            end
            waitForHardwareClick(reveal, attempt)
            return
        end

        local paged = GetSpellbookPagedFrame(frame) or root



        targetElement = FindSpellElementInSection(paged, data)






        local function stillRepresentsTarget(f)
            return SpellFrameMatchesSelf(f, data)
        end

        if targetElement then
            local elementBtn = FindVisibleButtonForElement(paged, targetElement)
            if elementBtn and highlight then
                if highlight.HighlightSpellbookSpell then
                    highlight:HighlightSpellbookSpell(elementBtn, stillRepresentsTarget)
                else
                    highlight:HighlightFrame(elementBtn, nil, stillRepresentsTarget)
                end
                return
            end
        end

        local btn = FindSpellbookButton(paged, data, false)
        if btn and highlight then
            if highlight.HighlightSpellbookSpell then
                highlight:HighlightSpellbookSpell(btn, stillRepresentsTarget)
            else
                highlight:HighlightFrame(btn, nil, stillRepresentsTarget)
            end
            return
        end






        local nextBtn = SpellbookPageButton(frame, "NextPageButton")
        local prevBtn = SpellbookPageButton(frame, "PrevPageButton")
        if pageSweepDir == "next" and not CanClickButton(nextBtn) then
            pageSweepDir = "prev"
        end
        local pageBtn = pageSweepDir == "next" and nextBtn or prevBtn
        if pageBtn and CanClickButton(pageBtn) then
            if highlight and highlight.HighlightFrame then
                highlight:HighlightFrame(pageBtn, nil, nil, true)
            end
            waitForHardwareClick(reveal, attempt)
            return
        end
        if attempt < 36 then
            Utils.SafeAfter(0.1, function() reveal(attempt + 1) end)
        end
    end

    Utils.SafeAfter(0.05, function() reveal(1) end)
end

function Handlers:ApplySpellBookHidePassives(hide)
    hide = hide and true or false
    if GetCVarBool and GetCVarBool("spellBookHidePassives") == hide then return end
    if SetCVar then pcall(SetCVar, "spellBookHidePassives", hide and "1" or "0") end





end





