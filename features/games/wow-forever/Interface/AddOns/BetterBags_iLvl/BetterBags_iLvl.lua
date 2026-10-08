local addonName, root = ...;
local L = root.L;
local _G = _G

---@class BetterBags_Legendary: AceModule
local addon = LibStub("AceAddon-3.0"):NewAddon(root, addonName, 'AceHook-3.0')

--- BetterBags dependencies
-----------------------------
---@class BetterBags: AceAddon
local BetterBags = LibStub('AceAddon-3.0'):GetAddon("BetterBags")
assert(BetterBags, addonName .. " requires BetterBags")
---@class Categories: AceModule
local categories = BetterBags:GetModule('Categories')
---@class Config: AceModule
local config = BetterBags:GetModule('Config')
---@class Context: AceModule
local context = BetterBags:GetModule('Context')
-----------------------------

--- Default config
-----------------------------
addon.context = context:New(L["CATEGORY_NAME"] .. "_Event")

-- Default values, set to current season dungeon ilvl and max MM ilvl
local defaultThreshold = "214"
local maximumThreshold = "344"

if (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE) then
    defaultThreshold = "60"
    maximumThreshold = "100"
elseif (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_CLASSIC) then
    defaultThreshold = "60"
    maximumThreshold = "100"
elseif (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC) then
    defaultThreshold = "120"
    maximumThreshold = "175"
elseif (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_WRATH_CLASSIC) then
    defaultThreshold = "200"
    maximumThreshold = "284"
elseif (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_CATACLYSM_CLASSIC) then
    defaultThreshold = "346"
    maximumThreshold = "416"
elseif (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_MISTS_CLASSIC) then
    defaultThreshold = "410"
    maximumThreshold = "509"
end

-- Dynamic threshold is only supported on the current retail client, since it
-- relies on GetAverageItemLevel and hasn't been verified on Classic clients.
local isRetail = (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE)
local defaultDynamicOffset = "20"

addon.db = {
    threshold = defaultThreshold,
    includeJunk = true,
    useDynamicThreshold = false,
    dynamicOffset = defaultDynamicOffset,
    useMaxItemLevel = false,
}

addon.vars = {
    defaultThreshold = defaultThreshold,
    maximumThreshold = maximumThreshold,
    defaultDynamicOffset = defaultDynamicOffset,
    isRetail = isRetail,
}
-----------------------------

--- Addon core
-----------------------------
addon.eventFrame = CreateFrame("Frame", addonName .. "EventFrame", UIParent)
addon.eventFrame:RegisterEvent("ADDON_LOADED")
addon.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
addon.eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
        local name = ...;
        if name == addonName then
            addon:OnReady()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...;
        if isInitialLogin or isReloadingUi then
            addon:UpdateDynamicThreshold()
        end
    end
end)

-- Pure calculation, no side effects: returns the threshold implied by the
-- player's current average equipped item level, or nil if unavailable.
function addon:CalculateDynamicThreshold()
    if not addon.vars.isRetail then return nil end
    if not _G.GetAverageItemLevel then return nil end

    local _, avgItemLevelEquipped = _G.GetAverageItemLevel()
    if not avgItemLevelEquipped or avgItemLevelEquipped <= 0 then return nil end

    local offset = tonumber(addon.db.dynamicOffset) or tonumber(addon.vars.defaultDynamicOffset)
    return tostring(math.max(1, math.floor(avgItemLevelEquipped - offset)))
end

-- Recompute the iLvl threshold and store it directly into addon.db.threshold
-- (the same variable the manual slider reads/writes), so that disabling the
-- dynamic option leaves the threshold already set to its last dynamic value.
-- Called passively on login/reload (see PLAYER_ENTERING_WORLD handler above)
-- and actively from the options panel whenever the player enables the
-- dynamic option or edits its offset; it never runs on its own mid-session.
function addon:UpdateDynamicThreshold()
    if not addon.db.useDynamicThreshold then return end

    local newThreshold = addon:CalculateDynamicThreshold()
    if not newThreshold or newThreshold == addon.db.threshold then return end

    addon.db.threshold = newThreshold
    if addon.refreshCategory then
        addon.refreshCategory(addon.context:Copy())
    end
    if addon.updateThresholdControls then
        addon.updateThresholdControls()
    end
end

function addon:OnReady()
    if (type(BetterBags_iLvlDB) ~= "table") then BetterBags_iLvlDB = {} end

    -- Update local db with saved variables
    local db = BetterBags_iLvlDB
    for key in pairs(addon.db) do
        --  If our option is not present, set default value
        if (db[key] == nil) then db[key] = addon.db[key] end
    end
    addon.db = db

    -- Clean category on load
    categories:WipeCategory(addon.context:Copy(), L["CATEGORY_NAME"])

    -- Add addon config to BetterBags
    config:AddPluginConfig(L["CATEGORY_NAME"], addon.options)

    -- Create addon category if it doesn't already exist
    local categoryAlreadyExists = categories:GetCategoryByName(L["CATEGORY_NAME"])

    if not categoryAlreadyExists then
        categories:CreateCategory({
            name = L["CATEGORY_NAME"],
            save = true,
            itemList = {},
        })
    end
end
