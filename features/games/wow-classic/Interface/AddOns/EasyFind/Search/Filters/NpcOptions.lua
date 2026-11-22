local _, ns = ...

local Filters = ns.Filters
local Utils = ns.Utils
local L = ns.L

local ipairs = Utils.ipairs
local CreateFrame = CreateFrame
local UIParent = UIParent






local function Facet(name)
    local db = EasyFind.db
    db.npcFilters = db.npcFilters or {}
    db.npcFilters[name] = db.npcFilters[name] or {}
    return db.npcFilters[name]
end

local function ReactionDefs()
    return {
        { key = 0, label = _G["FACTION_STANDING_LABEL5"] or "Friendly" },
        { key = 1, label = _G["FACTION_STANDING_LABEL4"] or "Neutral" },
        { key = 2, label = _G["FACTION_STANDING_LABEL2"] or "Hostile" },
    }
end

local function RoleDefs()
    return {
        { key = "quest", label = L["NPC_ROLE_QUEST"] },
        { key = "vendor", label = L["MAP_FILTER_VENDORS"] },
        { key = "trainer", label = L["MAP_FILTER_TRAINERS"] },
        { key = "flight", label = L["NPC_ROLE_FLIGHT"] },
        { key = "services", label = L["FILTER_SERVICES"] },
        { key = "other", label = _G["OTHER"] or "Other" },
    }
end

local function Choices()
    local Npcs = ns.Npcs
    return Npcs and Npcs.FilterChoices and Npcs.FilterChoices() or nil
end

local function TypeDefs()
    local c = Choices()
    local defs = {}
    for _, t in ipairs(c and c.types or {}) do defs[#defs + 1] = { key = t.id, label = t.name } end
    return defs
end

local function ExpansionDefs()
    local c = Choices()
    local defs = {}
    for _, e in ipairs(c and c.expansions or {}) do
        local name = e >= 0 and _G["EXPANSION_NAME" .. e] or _G["UNKNOWN"] or "Unknown"
        defs[#defs + 1] = { key = e, label = name }
    end
    return defs
end



function Filters:NpcFacets()
    return {
        { name = "reaction", label = L["NPC_FILTER_REACTION"], defs = ReactionDefs },
        { name = "role", label = _G["ROLE"] or "Role", defs = RoleDefs },
        { name = "type", label = _G["TYPE"] or "Type", defs = TypeDefs },
        { name = "expansion", label = _G["EXPANSION_FILTER_TEXT"] or "Expansion", defs = ExpansionDefs },
    }
end
Filters.NpcFacet = Facet

function Filters:BuildNpcOptionsPopup(StylePopup, CHECK_SIZE, dropdownGuardFrames)
    local OPTIONS_WIDTH = 160
    local FLYOUT_WIDTH = 180
    local ROW_H = 22
    local PAD = 6

    local function ChainEnabled()
        return EasyFind.db.uiSearchFilters.map ~= false and EasyFind.db.uiMapFilters.npcs ~= false
    end

    local optionsPopup = CreateFrame("Frame", "EasyFindNpcOptionsPopup", UIParent, "BackdropTemplate")
    optionsPopup:SetFrameStrata("TOOLTIP")
    StylePopup(optionsPopup)
    optionsPopup:EnableMouse(true)
    optionsPopup:Hide()

    local function CreateFlyoutRow(labelText)
        local row = CreateFrame("Button", nil, optionsPopup)
        row:SetSize(OPTIONS_WIDTH - PAD * 2, ROW_H)
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", 14, 0)
        text:SetText(labelText)
        local chev = row:CreateTexture(nil, "OVERLAY")
        Utils.SetChevronTexture(chev)
        chev:SetSize(CHECK_SIZE, CHECK_SIZE)
        chev:SetPoint("RIGHT", -4, 0)
        row._label = text
        row._chev = chev
        Utils.InstallMenuRowHighlight(row)
        return row
    end

    local facets = Filters:NpcFacets()
    local flyouts = {}
    for i, facet in ipairs(facets) do
        facet.row = CreateFlyoutRow(facet.label)
        facet.flyout = Filters:BuildSourceFlyout({
            name = "EasyFindNpc" .. facet.name .. "Popup",
            stylePopup = StylePopup,
            checkSize = CHECK_SIZE,
            width = FLYOUT_WIDTH,
            frameLevel = optionsPopup:GetFrameLevel() + 2 * Utils.MENU_LEVEL_STEP,
            getShowLevel = function() return optionsPopup:GetFrameLevel() + Utils.MENU_LEVEL_STEP end,
            getScale = function() return optionsPopup:GetScale() end,
            guardFrames = dropdownGuardFrames,
            sourcesRow = facet.row,
            collectDefs = facet.defs,
            defField = "key",
            getFilters = function() return Facet(facet.name) end,
            chainEnabled = ChainEnabled,
            applyKey = "npcs",
        })
        flyouts[i] = facet.flyout
    end


    for _, facet in ipairs(facets) do
        facet.row:HookScript("OnEnter", function()
            for _, other in ipairs(facets) do
                if other ~= facet then other.flyout:Hide() end
            end
        end)
    end



    local function Layout()
        local shown, contentW = {}, 0
        for _, facet in ipairs(facets) do
            local n = #facet.defs()
            local show = n > 1
            facet.row:SetShown(show)
            if show then
                shown[#shown + 1] = facet.row
                local w = Utils.FlyoutRowContentWidth(facet.row, 14, nil, CHECK_SIZE)
                if w > contentW then contentW = w end
            else
                facet.flyout:Hide()
            end
        end
        local popupW = Utils.FlyoutWidthFor(contentW, PAD)
        for i, row in ipairs(shown) do
            row:SetWidth(popupW - PAD * 2)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", optionsPopup, "TOPLEFT", PAD, -PAD - (i - 1) * ROW_H)
        end
        optionsPopup:SetSize(popupW, PAD * 2 + #shown * ROW_H)
    end

    local function SyncOptions()
        Layout()
        local enabled = ChainEnabled()
        for _, facet in ipairs(facets) do Utils.SetFlyoutRowEnabled(facet.row, enabled) end
    end

    optionsPopup:HookScript("OnHide", function()
        for _, facet in ipairs(facets) do facet.flyout:Hide() end
    end)
    return optionsPopup, SyncOptions, flyouts
end
