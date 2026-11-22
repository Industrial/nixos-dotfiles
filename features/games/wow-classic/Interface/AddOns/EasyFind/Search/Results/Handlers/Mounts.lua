local _, ns = ...

local Search = ns.Search
local Handlers = ns.ResultHandlers
local Utils = ns.Utils

local GetButtonText = Utils.GetButtonText
local SearchFrameTreeFuzzy = Utils.SearchFrameTreeFuzzy
local ClickButton = Utils.ClickButton
local slower = Utils.slower
local C_MountJournal = C_MountJournal

function Handlers:GetMountJournalFrame()
    local collections = _G["CollectionsJournal"]
    return _G["MountJournal"]
        or (collections and collections.MountJournal)
        or (collections and collections.MountJournalFrame)
end

function Handlers:GetMountJournalScrollBox()
    local mountJournal = self:GetMountJournalFrame()
    if not mountJournal then return nil end
    if mountJournal.ScrollBox then return mountJournal.ScrollBox end
    if mountJournal.MountList and mountJournal.MountList.ScrollBox then return mountJournal.MountList.ScrollBox end
    if mountJournal.List and mountJournal.List.ScrollBox then return mountJournal.List.ScrollBox end
    if mountJournal.ListScrollFrame and mountJournal.ListScrollFrame.ScrollBox then return mountJournal.ListScrollFrame.ScrollBox end
    local oldScroll = _G["MountJournalListScrollFrame"]
    if oldScroll and oldScroll.ScrollBox then return oldScroll.ScrollBox end
    return nil
end

function Handlers:GetMountJournalDisplayFraction(mountID)
    if not mountID or not C_MountJournal then return nil end
    if C_MountJournal.GetNumDisplayedMounts and C_MountJournal.GetDisplayedMountID then
        local total = C_MountJournal.GetNumDisplayedMounts()
        for i = 1, total or 0 do
            if C_MountJournal.GetDisplayedMountID(i) == mountID then
                return (total and total > 1) and ((i - 1) / (total - 1)) or 0
            end
        end
    end
    if C_MountJournal.GetMountIDs then
        local ids = C_MountJournal.GetMountIDs()
        if type(ids) == "table" then
            for i = 1, #ids do
                if ids[i] == mountID then
                    return (#ids > 1) and ((i - 1) / (#ids - 1)) or 0
                end
            end
        end
    end
    return nil
end

local function ResolveMountSpellID(data)
    if not (data and data.mountID) then return nil end
    if data.spellID then return data.spellID end
    if C_MountJournal and C_MountJournal.GetMountInfoByID then
        local ok, _, spellID = pcall(C_MountJournal.GetMountInfoByID, data.mountID)
        if ok then return spellID end
    end
    return nil
end

local function GetSpellLinkCompat(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellLink then
        local ok, link = pcall(C_Spell.GetSpellLink, spellID)
        if ok and link then return link end
    end
    local getSpellLink = _G["GetSpellLink"]
    if getSpellLink then
        local ok, link = pcall(getSpellLink, spellID)
        if ok and link then return link end
    end
    return nil
end

local function GetMountJournalLink(data)
    if data and data.mountID and C_MountJournal and C_MountJournal.GetMountLink then
        local ok, link = pcall(C_MountJournal.GetMountLink, data.mountID)
        if ok and link then return link end
    end
    return nil
end

local DRESSUP_FRAME_NAMES = { "DressUpFrame", "SideDressUpFrame", "TransmogAndMountDressupFrame" }

local function IsAnyDressUpFrameShown()
    for i = 1, #DRESSUP_FRAME_NAMES do
        local frame = _G[DRESSUP_FRAME_NAMES[i]]
        if frame and frame.IsShown and frame:IsShown() then return true end
    end
    return false
end

local function TryDressUp(fn, arg)
    if not fn then return false end
    local ok = pcall(fn, arg)
    return ok and IsAnyDressUpFrameShown()
end

local function TryPreviewMountInDressUp(data)
    if not (data and data.mountID) then return false end
    local spellID = ResolveMountSpellID(data)
    local spellLink = GetSpellLinkCompat(spellID)
    local mountLink = GetMountJournalLink(data)

    Utils.LoadBlizzardAddOn("Blizzard_UIPanels_Game")

    local dressUpMountLink = _G["DressUpMountLink"]
    if dressUpMountLink then
        if spellLink and TryDressUp(dressUpMountLink, spellLink) then return true end
        if mountLink and mountLink ~= spellLink and TryDressUp(dressUpMountLink, mountLink) then return true end
    end

    if spellLink and TryDressUp(_G["DressUpSpellLink"], spellLink) then return true end

    local dressUpMount = _G["DressUpMount"]
    if dressUpMount then
        if TryDressUp(dressUpMount, data.mountID) then return true end
        if spellID and TryDressUp(dressUpMount, spellID) then return true end
    end

    return false
end

function Handlers:PreviewMountInDressUp(data)
    if TryPreviewMountInDressUp(data) then return true end
    if Utils.SafeAfter then
        local function retry(attemptsLeft)
            if TryPreviewMountInDressUp(data) or IsAnyDressUpFrameShown() then return end
            if attemptsLeft > 0 then
                Utils.SafeAfter(0.05, function() retry(attemptsLeft - 1) end)
            else
                Search:OpenMountInJournal(data)
            end
        end
        Utils.SafeAfter(0, function() retry(2) end)
        return true
    end
    return false
end

function Handlers:MountElementMatches(edata, mountID, spellID, mountName)
    if not edata then return false end
    if type(edata) == "number" then return mountID and edata == mountID end
    if type(edata) ~= "table" then return false end
    local edataMountID = edata.mountID or edata.mountId or edata.id
    if mountID and edataMountID == mountID then return true end
    local edataSpellID = edata.spellID or edata.spellId
    if spellID and edataSpellID == spellID then return true end
    local name = edata.name or edata.mountName or edata.displayName
    return mountName and name and slower(name) == mountName
end

function Handlers:MountFrameMatches(frame, mountID, spellID, mountName)
    if not frame then return false end
    local ok, edata = pcall(function()
        return frame.GetElementData and frame:GetElementData()
    end)
    if ok and self:MountElementMatches(edata, mountID, spellID, mountName) then return true end
    if mountID and (frame.mountID == mountID or frame.mountId == mountID or frame.id == mountID) then
        return true
    end
    if spellID and (frame.spellID == spellID or frame.spellId == spellID) then
        return true
    end
    local text = GetButtonText(frame)
    return mountName and text and slower(text) == mountName
end

function Handlers:RevealMountInJournal(data)
    if not (data and data.mountID) then return nil end

    local spellID = ResolveMountSpellID(data)

    if C_MountJournal then
        if C_MountJournal.SetAllSourceFilters then pcall(C_MountJournal.SetAllSourceFilters, true) end
        if C_MountJournal.SetAllTypeFilters then pcall(C_MountJournal.SetAllTypeFilters, true) end
        if C_MountJournal.SetCollectedFilterSetting then
            local collectedFilter = _G["LE_MOUNT_JOURNAL_FILTER_COLLECTED"]
            local uncollectedFilter = _G["LE_MOUNT_JOURNAL_FILTER_NOT_COLLECTED"]
            local unusableFilter = _G["LE_MOUNT_JOURNAL_FILTER_UNUSABLE"]
            if collectedFilter ~= nil then
                pcall(C_MountJournal.SetCollectedFilterSetting, collectedFilter, true)
            end
            if uncollectedFilter ~= nil then
                pcall(C_MountJournal.SetCollectedFilterSetting, uncollectedFilter, true)
            end
            if unusableFilter ~= nil then
                pcall(C_MountJournal.SetCollectedFilterSetting, unusableFilter, true)
            end
        end
        if C_MountJournal.SetSearch then
            pcall(C_MountJournal.SetSearch, "")
        end
    end

    local mountJournal = self:GetMountJournalFrame()
    if mountJournal then
        self:SetEditBoxTextIfPresent(mountJournal.SearchBox or mountJournal.searchBox, "")
    end

    local mountName = data.name and slower(data.name)
    local scrollBox = self:GetMountJournalScrollBox()
    if scrollBox then
        Utils.ScrollBoxScrollTo(scrollBox, function(edata)
            return self:MountElementMatches(edata, data.mountID, spellID, mountName)
        end, self:GetMountJournalDisplayFraction(data.mountID))
        local btn = Utils.ScrollBoxFindButton(scrollBox, function(frame)
            return self:MountFrameMatches(frame, data.mountID, spellID, mountName)
        end)
        if btn then return btn end
    end

    if mountJournal and mountName then
        return SearchFrameTreeFuzzy(mountJournal, mountName)
    end
    return nil
end




function Handlers:BuildMountJournalGuideData(data)
    return {
        name = data.name,
        steps = {
            { buttonFrame = "CollectionsMicroButton" },
            { waitForFrame = "CollectionsJournal", tabIndex = 1 },
            {
                waitForFrame = "CollectionsJournal",
                mountID = data.mountID,
                spellID = data.spellID,
                name = data.name,
            },
        },
    }
end

function Handlers:OpenMountInJournal(data)
    if not (data and data.mountID) then return end
    local highlight = ns.RequestGuide()
    local MOUNT_TAB = 1


    local Openers = ns.SearchOpeners
    if Openers and Openers.ShowCollectionsEntry and Openers.ShowCollectionsEntry("mounts", "mount:" .. data.mountID) then return end

    local function step(attempt)
        local journal = _G["CollectionsJournal"]
        if not (journal and journal:IsShown()) then


            if attempt == 1 then
                local micro = _G["CollectionsMicroButton"]
                if micro then ClickButton(micro) end
            end
            if attempt < 30 then
                Utils.SafeAfter(0.05, function() step(attempt + 1) end)
            end
            return
        end
        if highlight and highlight.IsTabSelected
           and not highlight:IsTabSelected("CollectionsJournal", MOUNT_TAB) then
            local tab = highlight.GetTabButton
                and highlight:GetTabButton("CollectionsJournal", MOUNT_TAB)
            if tab then ClickButton(tab) end
            if attempt < 30 then
                Utils.SafeAfter(0, function() step(attempt + 1) end)
            end
            return
        end

        local row = self:RevealMountInJournal(data)
        if row and self:HighlightRevealedFrame(row) then return end
        if attempt < 30 then
            Utils.SafeAfter(0.05, function() step(attempt + 1) end)
        end
    end

    step(1)
end
