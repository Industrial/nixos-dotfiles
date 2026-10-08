--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2026 - James N. Whitehead II
-------------------------------------------------------------------]]--

---@class CliqueAddon: AddonCore
local addon = select(2, ...)
local L = addon.L

-- Return the currently selected spec (numeric index). For classic
-- variants this will map to Primary & Secondary, whereas for MoP
-- and above we actually use the name of the talent spec.
function addon:GetActiveTalentSpec()
    if addon:ProjectIsRetail() or addon:ProjectIsMists() then
        return C_SpecializationInfo.GetSpecialization()
    elseif C_SpecializationInfo.GetActiveSpecGroup then
        return C_SpecializationInfo.GetActiveSpecGroup()
    end
end

-- Returns an acceptable string for the given talent spec, covering the
-- differences between Retail and Wrath
function addon:GetTalentSpecName(idx)
    if addon:ProjectIsRetail() or addon:ProjectIsMists() then
        local _, specName = C_SpecializationInfo.GetSpecializationInfo(idx)
        return specName
    elseif idx == 1 then
        return L["Primary"]
    elseif idx == 2 then
        return L["Secondary"]
    end
end

function addon:GetNumTalentSpecs()
    -- For mists and retail the number of specs is the number of class
    -- specializations (i.e. Restoration, Guardian, Balance, Feral for Druids)
    if addon:ProjectIsRetail() or addon:ProjectIsMists() then
        return GetNumSpecializations() or 0
    elseif GetNumTalentGroups then
        -- Some other variants support multiple talent loadouts, where the player
        -- can have different configurations (essentially primary/secondary loadouts)
        local ok, numSpecs = pcall(GetNumTalentGroups)
        if ok then return numSpecs or 0 end
    end

    return 0
end

function addon:PlayerHasMultiTalentSpecs()
    return self:GetNumTalentSpecs() > 1
end

-- Handle automatic profile changes based on spec
function addon:TalentGroupChanged()
    local currentSpec = self:GetActiveTalentSpec()
    local specChanged = currentSpec ~= self.currentTalentSpec

    -- Talents may not be available on initial call
    if not currentSpec then
        return
    end

    local profileChanged = false
    if self.settings.specswap then
        local currentProfile = self.db:GetCurrentProfile()
        local newProfile

        -- Check the correct profile for the spec
        local settingsKey = string.format("spec%d_profileKey", currentSpec)
        if self.settings[settingsKey] then
            newProfile = self.settings[settingsKey]
        end

        -- If we need to switch then trigger a switch!
        if newProfile ~= currentProfile and type(newProfile) == "string" then
            self:Printf(L["Switching to profile: '%s'"]:format(newProfile))
            self.db:SetProfile(newProfile)
            profileChanged = true
        end
    end

    if specChanged then
        self.currentTalentSpec = currentSpec
    end

    if specChanged or profileChanged then
        self:FireMessage("BINDINGS_CHANGED")
    end
end

