local _, ns = ...



local AddOns = {}
ns.AddOns = AddOns

local Database, Utils, L = ns.Database, ns.Utils, ns.L
local slower = Utils.slower
local C_AddOns = C_AddOns

local CATEGORY = "AddOn"
local GLYPH = { tex = ns.EXTENSIONS_ICON_TEX }
local WORDS = { "addon", "addons", "enable", "disable" }

local atStart = {}

local function Character()
    return UnitGUID and UnitGUID("player") or nil
end

function AddOns.IsOn(name)
    local state = C_AddOns.GetAddOnEnableState(name, Character())
    return type(state) == "number" and state > 0
end

function AddOns.Set(name, on)
    if on then C_AddOns.EnableAddOn(name, Character()) else C_AddOns.DisableAddOn(name, Character()) end
    if C_AddOns.SaveAddOns then C_AddOns.SaveAddOns() end
end


function AddOns.Changed(name)
    return atStart[name] ~= nil and AddOns.IsOn(name) ~= atStart[name]
end


function AddOns.Line(row)
    local name = row.addonName
    if AddOns.Changed(name) then return name .. ", " .. L["ADDONS_AFTER_RELOAD"] end
    return name
end

function Database:PopulateDynamicAddOns()
    Database.RemoveEntriesByCategory(CATEGORY)
    if self.ResetSearchCache then self:ResetSearchCache() end
    if not (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetAddOnInfo and C_AddOns.GetAddOnEnableState
            and C_AddOns.EnableAddOn and C_AddOns.DisableAddOn) then
        return true
    end
    local rows, Rows = self.uiSearchData, ns.ResultRows
    local reload = _G["RELOADUI"] or "Reload UI"
    for index = 1, C_AddOns.GetNumAddOns() or 0 do
        local name, title, _, _, _, security = C_AddOns.GetAddOnInfo(index)

        if name and security ~= "SECURE" then
            local shown = Utils.StripMarkup(title and title ~= "" and title or name) or name
            local lower, folder = slower(shown), slower(name)
            local kw = { lower, folder }
            for i = 1, #WORDS do kw[#kw + 1] = WORDS[i] end
            local variable = "addon:" .. name
            if atStart[name] == nil then atStart[name] = AddOns.IsOn(name) end
            if Rows and Rows.RegisterCustomSetting then


                Rows:RegisterCustomSetting(variable, {
                    get = function() return AddOns.IsOn(name) end,
                    set = function(on) AddOns.Set(name, on == true or on == 1 or on == "1") end,
                    pending = function() return AddOns.Changed(name) end,
                    apply = ReloadUI,
                    revert = function() AddOns.Set(name, atStart[name]) end,
                    applyText = reload, revertText = _G["CANCEL"] or "Cancel",
                })
            end
            local icon = C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(name, "IconTexture")
            rows[#rows + 1] = {
                name = shown, nameLower = lower, category = CATEGORY, keywords = kw, keywordsLower = kw,
                glyph = icon and icon ~= "" and { tex = icon } or GLYPH, addonName = name,
                settingVariable = variable, settingType = "checkbox", noPin = true,
            }
        end
    end
    local reloadLower = slower(reload)
    rows[#rows + 1] = {
        name = reload, nameLower = reloadLower, category = CATEGORY, glyph = GLYPH, noPin = true,
        keywords = { reloadLower, "reload", "apply", "addons" }, slashCommand = "/reload",
        searchCommandDesc = L["ADDONS_RELOAD_SUB"],
    }
    return true
end
