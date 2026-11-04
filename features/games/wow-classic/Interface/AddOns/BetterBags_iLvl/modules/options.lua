local addonName, root = ...;
local L = root.L;

---@class BetterBags_iLvl: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

--- BetterBags dependencies
-----------------------------
---@class BetterBags: AceAddon
local BetterBags = LibStub('AceAddon-3.0'):GetAddon("BetterBags")
---@class Categories: AceModule
local categories = BetterBags:GetModule('Categories')
---@class Config: AceModule
local config = BetterBags:GetModule('Config')
---@class Events: AceModule
local events = BetterBags:GetModule('Events')
-----------------------------

local thresholdError = false
local debounceTimer

local updateSavedVariables = function()
    BetterBags_iLvlDB = addon.db
end

local function refreshCategory(context)
    if debounceTimer then
        debounceTimer:Cancel()
    end

    -- We wait for the value not to be changed for 1 second before refreshing the categories
    debounceTimer = C_Timer.NewTimer(1, function()
        updateSavedVariables()
        categories:WipeCategory(L["CATEGORY_NAME"])
        events:SendMessage(context, 'bags/FullRefreshAll')
    end)
end
-- Exposed so BetterBags_iLvl.lua can trigger a refresh after recomputing the
-- dynamic threshold on login/reload (PLAYER_ENTERING_WORLD fires well after
-- this file has loaded, so addon.refreshCategory is guaranteed to be set).
addon.refreshCategory = refreshCategory

-- Finds the form container BetterBags created for a given opts table, by
-- reference (BetterBags' layout keeps container -> opts maps but never hands
-- the container back to the caller). Only needs to run once per widget; the
-- result is cached by the caller.
local function findContainer(map, opts)
    for container, storedOpts in pairs(map) do
        if storedOpts == opts then
            return container
        end
    end
end

-- The manual slider and the dynamic-offset box are both built up front; only
-- one is ever relevant at a time, so we just show/hide them live instead of
-- rebuilding the panel (BetterBags' form layout has no such rebuild API).
-- Note: BetterBags parents each widget's frame to the PREVIOUS widget's
-- frame (that's how the stacked layout positions them), so hiding a whole
-- container would also hide everything chained after it (the offset box is
-- parented to the slider, and the next option is parented to the offset
-- box). We hide the inner title/description/control elements instead, so
-- the wrapper frame -- and anything anchored to it -- stays shown.
local toggleContainer, sliderContainer, offsetContainer

local function setControlShown(container, shown)
    if not container then return end
    if container.title then container.title:SetShown(shown) end
    if container.description then container.description:SetShown(shown) end
    if container.slider then container.slider:SetShown(shown) end
    if container.input then container.input:SetShown(shown) end
end

local function updateThresholdControls()
    setControlShown(sliderContainer, not addon.db.useDynamicThreshold)
    setControlShown(offsetContainer, addon.db.useDynamicThreshold)
    if toggleContainer then
        local title = L["OPTIONS_DYNAMIC_TOGGLE"]
        if addon.db.useDynamicThreshold then
            title = L["OPTIONS_DYNAMIC_TOGGLE_ACTIVE"]:gsub("_value_", addon.db.threshold)
        end
        toggleContainer.title:SetText(title)
    end
end
-- Exposed so BetterBags_iLvl.lua can refresh the checkbox label after
-- recomputing the dynamic threshold on login/reload.
addon.updateThresholdControls = updateThresholdControls

--- Options panel
-----------------------------
addon.options = {
    a = {
        name = function()
            config.configFrame.layout:AddInlineSubSection({
                title = L["CATEGORY_NAME"],
                description = L["OPTIONS_DESC"],
            })
        end
    },
    b = {
        name = function()
            if addon.vars.isRetail then
                local toggleOpts = {
                    title = L["OPTIONS_DYNAMIC_TOGGLE"],
                    description = L["OPTIONS_DYNAMIC_TOGGLE_DESC"],
                    getValue = function(_)
                        return addon.db.useDynamicThreshold
                    end,
                    setValue = function(_, value)
                        addon.db.useDynamicThreshold = value
                        if value then
                            addon.db.dynamicOffset = addon.vars.defaultDynamicOffset
                            addon:UpdateDynamicThreshold()
                        end
                        updateThresholdControls()
                    end,
                }
                config.configFrame.layout:AddCheckbox(toggleOpts)
                toggleContainer = findContainer(config.configFrame.layout.checkboxes, toggleOpts)
            end

            if addon.vars.isRetail then
                local offsetOpts = {
                    title = L["OPTIONS_DYNAMIC_OFFSET"]:gsub("_default_", addon.vars.defaultDynamicOffset),
                    description = L["OPTIONS_DYNAMIC_OFFSET_DESC"],
                    getValue = function(_)
                        return addon.db.dynamicOffset
                    end,
                    setValue = function(_, value)
                        local offset = tonumber(value)
                        if offset and offset > 0 then
                            offset = math.min(offset, tonumber(addon.vars.maximumThreshold))
                            addon.db.dynamicOffset = tostring(math.floor(offset))
                            addon:UpdateDynamicThreshold()
                            updateThresholdControls()
                        end
                    end,
                }
                config.configFrame.layout:AddInputBox(offsetOpts)
                offsetContainer = findContainer(config.configFrame.layout.inputBoxes, offsetOpts)
            end

            local sliderOpts = {
                title = L["OPTIONS_THRESHOLD"]:gsub("_default_", addon.vars.defaultThreshold),
                min = 1,
                max = tonumber(addon.vars.maximumThreshold),
                step = 1,
                id = "ilvl_threshold",
                getValue = function(_)
                    return addon.db.threshold
                end,
                setValue = function(ctx, value)
                    if (tonumber(value)) then
                        thresholdError = false
                        addon.db.threshold = tostring(value)
                        refreshCategory(ctx)
                    else
                        thresholdError = true
                    end
                end,
            }
            config.configFrame.layout:AddSlider(sliderOpts)
            sliderContainer = findContainer(config.configFrame.layout.sliders, sliderOpts)

            updateThresholdControls()
        end
    },
    c = {
        type = "toggle",
        name = L["OPTIONS_INCLUDE_JUNK"],
        get = function() return addon.db.includeJunk end,
        set = function(ctx, value)
            addon.db.includeJunk = value
            refreshCategory(ctx)
        end
    },
}

if addon.vars.isRetail then
    addon.options.d = {
        type = "toggle",
        name = L["OPTIONS_USE_MAX_ILVL"],
        desc = L["OPTIONS_USE_MAX_ILVL_DESC"],
        get = function() return addon.db.useMaxItemLevel end,
        set = function(ctx, value)
            addon.db.useMaxItemLevel = value
            refreshCategory(ctx)
        end
    }
end
