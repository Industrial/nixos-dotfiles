local _, ns = ...

local Search = ns.Search
local Handlers = ns.ResultHandlers
local Results = ns.Results
local Utils = ns.Utils
local L = ns.L

local GetButtonText = Utils.GetButtonText
local SearchFrameTreeFuzzy = Utils.SearchFrameTreeFuzzy
local slower = Utils.slower
local C_PetJournal = C_PetJournal

local function GetPetJournalFrame()
    return _G["PetJournal"]
        or (CollectionsJournal and CollectionsJournal.PetJournal)
        or (CollectionsJournal and CollectionsJournal.PetJournalFrame)
end

function Handlers:BuildPetJournalGuideData(data)
    return {
        name = data.name,
        petID = data.petID,
        speciesID = data.speciesID,
        steps = {
            { buttonFrame = "CollectionsMicroButton" },
            { waitForFrame = "CollectionsJournal", tabIndex = 2,
              entry = data.speciesID and ("pet:" .. data.speciesID) or nil },
            {
                waitForFrame = "CollectionsJournal",
                petID = data.petID,
                speciesID = data.speciesID,
                petName = data.name,
            },
        },
    }
end

function Handlers:ResolvePetGUID(data)
    if not data then return nil end
    local guid = data.petID
    if not (C_PetJournal and data.speciesID
            and C_PetJournal.GetNumPets and C_PetJournal.GetPetInfoByIndex) then
        return guid
    end

    local total = C_PetJournal.GetNumPets()
    for i = 1, total or 0 do
        local pid, sid, owned = C_PetJournal.GetPetInfoByIndex(i)
        if owned and sid == data.speciesID then
            return pid
        end
    end
    return guid
end

local function PetElementMatches(edata, petID, speciesID, petName)
    if not edata then return false end
    local pid = edata.petID or edata.petGuid or edata.petGUID or edata.guid
    if petID and pid == petID then return true end
    local sid = edata.speciesID or edata.speciesId
    if speciesID and sid == speciesID then return true end
    local name = edata.name or edata.speciesName or edata.displayName
    return petName and name and slower(name) == slower(petName)
end

local function PetFrameMatches(frame, petID, speciesID, petName)
    if not frame then return false end
    local edata = frame.GetElementData and frame:GetElementData()
    if PetElementMatches(edata, petID, speciesID, petName) then return true end
    if petID and (frame.petID == petID or frame.petGuid == petID or frame.petGUID == petID) then
        return true
    end
    if speciesID and frame.speciesID == speciesID then return true end
    local text = GetButtonText(frame)
    return petName and text and slower(text) == slower(petName)
end

local function GetPetJournalScrollBox()
    local petJournal = GetPetJournalFrame()
    if not petJournal then return nil end
    local candidates = {
        petJournal.ScrollBox,
        petJournal.PetList and petJournal.PetList.ScrollBox,
        petJournal.List and petJournal.List.ScrollBox,
        petJournal.listScroll and petJournal.listScroll.ScrollBox,
        _G["PetJournalListScrollFrame"] and _G["PetJournalListScrollFrame"].ScrollBox,
    }
    for i = 1, #candidates do
        if candidates[i] then return candidates[i] end
    end
    return nil
end

function Handlers:RevealPetInJournal(data)
    if not data or not C_PetJournal then return nil end
    local petName = data.petName or data.name








    if C_PetJournal.SetFilterChecked then
        local collectedFilter = _G["LE_PET_JOURNAL_FILTER_COLLECTED"]
        local uncollectedFilter = _G["LE_PET_JOURNAL_FILTER_NOT_COLLECTED"]
        if collectedFilter ~= nil then
            pcall(C_PetJournal.SetFilterChecked, collectedFilter, true)
        end
        if uncollectedFilter ~= nil then
            pcall(C_PetJournal.SetFilterChecked, uncollectedFilter, true)
        end
    end
    if C_PetJournal.SetAllPetSourcesChecked then pcall(C_PetJournal.SetAllPetSourcesChecked, true) end
    if C_PetJournal.SetAllPetTypesChecked then pcall(C_PetJournal.SetAllPetTypesChecked, true) end



    if C_PetJournal.SetSearchFilter then
        local currentSearch = ""
        if C_PetJournal.GetSearchFilter then
            local ok, value = pcall(C_PetJournal.GetSearchFilter)
            if ok and value then currentSearch = value end
        end
        if currentSearch ~= "" then
            pcall(C_PetJournal.SetSearchFilter, "")
        end
    end

    local petID = self:ResolvePetGUID(data)
    if petID and petID ~= data.petID then data.petID = petID end

    local petJournal = GetPetJournalFrame()
    local selectPet = _G["PetJournal_SelectPet"]
    if selectPet and petID then
        pcall(selectPet, petID)
        if petJournal then pcall(selectPet, petJournal, petID) end
    end
    if C_PetJournal.SetSelectedPet and petID then
        pcall(C_PetJournal.SetSelectedPet, petID)
    end

    local scrollBox = GetPetJournalScrollBox()
    if scrollBox then
        Utils.ScrollBoxScrollTo(scrollBox, function(edata)
            return PetElementMatches(edata, petID, data.speciesID, petName)
        end)
        local btn = Utils.ScrollBoxFindButton(scrollBox, function(frame)
            return PetFrameMatches(frame, petID, data.speciesID, petName)
        end)
        if btn then return btn end
    end

    if petJournal and petName then
        return SearchFrameTreeFuzzy(petJournal, slower(petName))
    end
    return nil
end

function Handlers:SummonPet(petID)
    if petID and C_PetJournal and C_PetJournal.SummonPetByGUID then
        pcall(C_PetJournal.SummonPetByGUID, petID)
    end
end

local function NormalizePetFavorite(value)
    return value == true or value == 1
end

local function ReadPetFavoriteFromJournal(petID)
    if not petID or not C_PetJournal then return nil end
    if C_PetJournal.GetPetInfoByPetID then
        local ok, _, _, _, _, _, _, isFavorite = pcall(C_PetJournal.GetPetInfoByPetID, petID)
        if ok and isFavorite ~= nil then return NormalizePetFavorite(isFavorite) end
    end
    if C_PetJournal.GetNumPets and C_PetJournal.GetPetInfoByIndex then
        local total = C_PetJournal.GetNumPets()
        for i = 1, total or 0 do
            local pid, _, _, _, _, isFavorite = C_PetJournal.GetPetInfoByIndex(i)
            if pid == petID then return NormalizePetFavorite(isFavorite) end
        end
    end
    return nil
end

local function ReconcilePetFavoriteOverride(petID, expected, attemptsLeft)
    if not petID or Search:GetPetFavoriteOverrides()[petID] ~= expected then return end
    local actual = ReadPetFavoriteFromJournal(petID)
    if actual == expected then
        Search:GetPetFavoriteOverrides()[petID] = nil
        if Search and Search.RefreshResults then Search:RefreshResults() end
        return
    end
    if attemptsLeft and attemptsLeft > 0 and Utils.SafeAfter then
        Utils.SafeAfter(0.15, function()
            ReconcilePetFavoriteOverride(petID, expected, attemptsLeft - 1)
        end)
    end
end

function Handlers:IsPetFavorite(petID)
    if not petID then return false end
    if Search:GetPetFavoriteOverrides()[petID] ~= nil then
        return Search:GetPetFavoriteOverrides()[petID]
    end
    local favorite = ReadPetFavoriteFromJournal(petID)
    return favorite == true
end

function Handlers:TogglePetFavorite(petID)
    if not petID or not C_PetJournal or not C_PetJournal.SetFavorite then return end
    local fav = self:IsPetFavorite(petID)
    local newFav = not fav
    local ok = pcall(C_PetJournal.SetFavorite, petID, newFav and 1 or 0)
    if ok then
        Search:GetPetFavoriteOverrides()[petID] = newFav
    end
    if self.RefreshResults and Utils.SafeAfter then
        Utils.SafeAfter(0, function()
            if Search and Search.RefreshResults then Search:RefreshResults() end
        end)
        Utils.SafeAfter(0.15, function()
            ReconcilePetFavoriteOverride(petID, newFav, 8)
        end)
    end
end




function Handlers:IsPetCageable(petID)
    if not petID or not C_PetJournal then return false end
    if C_PetJournal.PetIsTradable then
        local ok, val = pcall(C_PetJournal.PetIsTradable, petID)
        if ok then return val and true or false end
    end
    return false
end

function Handlers:CagePet(petID)
    if not petID or not C_PetJournal or not C_PetJournal.CagePetByID then return end
    pcall(C_PetJournal.CagePetByID, petID)
end

function Handlers:ReleasePet(petID)
    if not petID or not C_PetJournal or not C_PetJournal.ReleasePetByID then return end
    StaticPopup_Show("EASYFIND_PET_RELEASE_CONFIRM", nil, nil, petID)
end

StaticPopupDialogs["EASYFIND_PET_RELEASE_CONFIRM"] = {
    text = L["PROMPT_RELEASE_PET"],
    button1 = ACCEPT or "OK",
    button2 = CANCEL or "Cancel",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function(_, petID)
        if petID and C_PetJournal and C_PetJournal.ReleasePetByID then
            pcall(C_PetJournal.ReleasePetByID, petID)
        end
    end,
}

function Handlers:RenamePet(petID)
    if not petID then return end
    local popup = StaticPopup_Show("EASYFIND_PET_RENAME", nil, nil, petID)
    Results:LiftPopupStrata(popup or Results:FindPopupSlot("EASYFIND_PET_RENAME"))
end

StaticPopupDialogs["EASYFIND_PET_RENAME"] = {
    text = L["PROMPT_RENAME_PET"],
    button1 = ACCEPT or "OK",
    button2 = CANCEL or "Cancel",
    hasEditBox = true,
    maxLetters = 16,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    enterClicksFirstButton = true,
    OnShow = function(self, petID)
        local eb = self.editBox or self.EditBox
        if not eb then return end
        local existing = ""
        if petID and C_PetJournal and C_PetJournal.GetPetInfoByPetID then
            local ok, _, customName, _, _, _, _, _, name = pcall(C_PetJournal.GetPetInfoByPetID, petID)
            if ok then existing = customName or name or "" end
        end
        eb:SetText(existing)
        eb:HighlightText()
        eb:SetFocus()
    end,
    OnAccept = function(self, petID)
        local eb = self.editBox or self.EditBox
        local txt = eb and eb:GetText() or ""
        if petID and C_PetJournal and C_PetJournal.SetCustomName then
            pcall(C_PetJournal.SetCustomName, petID, txt)
        end
    end,
}




