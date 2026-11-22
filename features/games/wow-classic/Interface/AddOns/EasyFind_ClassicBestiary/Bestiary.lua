-- Classic Bestiary's creature abilities on EasyFind's rows: hovering an NPC
-- or boss row lists what it casts, read through the Bestiary's API at the
-- moment of the hover; none of its data is copied.
local _, ns = ...
local API = EasyFind and EasyFind.API
if not (API and API.VERSION == 1) then return end

local L = ns.L
-- Loaded beside Classic Bestiary (OptionalDeps), nothing without it.
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
if not (IsAddOnLoaded and IsAddOnLoaded("ClassicBestiary")) then return end
local KEY = "classicbestiary"
local ICON = "Interface\\AddOns\\EasyFind_ClassicBestiary\\bestiary"
ns.KEY = KEY

local sformat = string.format
local SpellName = C_Spell and C_Spell.GetSpellName
    or (GetSpellInfo and function(id) return (GetSpellInfo(id)) end)
local SpellIcon = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
local SpellText = C_Spell and C_Spell.GetSpellDescription or GetSpellDescription
local SpellCached = C_Spell and C_Spell.IsSpellDataCached
local SpellExists = C_Spell and C_Spell.DoesSpellExist
local IsControlKeyDown, IsShiftKeyDown, IsAltKeyDown = IsControlKeyDown, IsShiftKeyDown, IsAltKeyDown
local DEFAULT_LINES = 8

function ns.Print(text)
    print(sformat("|cff66ccff%s:|r %s", L["EXT_NAME"], text))
end

local function Bestiary() return _G.ClassicBestiary end

-- The player's switches, in EasyFind's own saved data.
local function Store()
    local db = EasyFind.db
    db.classicBestiary = db.classicBestiary or {}
    return db.classicBestiary
end
local function Enabled() return Store().off ~= true end
local function MaxLines() return Store().lines or DEFAULT_LINES end

-- The creature a row stands for: an NPC on the map or a boss, by creature id.
local function NpcOf(row)
    local id = row.npcID
    return type(id) == "number" and id > 0 and id or nil
end

-- A row with a creature the Bestiary lists abilities for.
local function Applies(row)
    if not Enabled() then return false end
    local id = NpcOf(row)
    local CB = Bestiary()
    if not (id and CB and CB.IterateAbilities) then return false end
    local nextAbility = CB.IterateAbilities(id)
    return nextAbility() ~= nil
end

-- Classic Bestiary's own details key (its options): Ctrl unless the
-- player chose Shift, Alt, always or never there.
local KEY_DOWN = { ctrl = IsControlKeyDown, shift = IsShiftKeyDown, alt = IsAltKeyDown }
local function BestiaryOption(name)
    local saved = _G.ClassicBestiaryCfg
    if type(saved) ~= "table" then return nil end
    return saved[name]
end
local function DetailsKey()
    local key = BestiaryOption("expansion")
    if key == "always" or key == "never" or KEY_DOWN[key] then return key end
    return "ctrl"
end
local function Detailed(key)
    if key == "always" then return true end
    local down = KEY_DOWN[key]
    return down ~= nil and down() == true
end

-- A spell's name or text not loaded yet: asked for once, and the hovered
-- row's tooltip drawn again when it arrives.
local requested, redrawSoon = {}, false
local function Redraw()
    redrawSoon = false
    if API.RedrawRowTooltip then API.RedrawRowTooltip() end
end
local function Request(spellID)
    if requested[spellID] or not (Spell and SpellCached and SpellExists) then return end
    if SpellCached(spellID) or not SpellExists(spellID) then return end
    requested[spellID] = true
    Spell:CreateFromSpellID(spellID):ContinueOnSpellLoad(function()
        if redrawSoon then return end
        redrawSoon = true
        C_Timer.After(0.05, Redraw)
    end)
end

local function Name(spellID)
    local name = SpellName and SpellName(spellID)
    if name and name ~= "" then return name end
    Request(spellID)
end
local function Description(spellID)
    local text = SpellText and SpellText(spellID)
    if text and text ~= "" then return text end
    Request(spellID)
end
local function Labeled(spellID, name)
    local icon = SpellIcon and SpellIcon(spellID)
    return icon and sformat("|T%s:14:14:0:0|t %s", icon, name) or name
end

-- Details: an ability's own text, then the spells it sets off, each with
-- theirs; one of the same name lends its text when the ability has none.
local function AddDetails(tooltip, CB, spellID, name, listed)
    local text = Description(spellID)
    local related = CB.GetRelationships and CB.GetRelationships(spellID)
    local others = {}
    for _, link in ipairs(type(related) == "table" and related or {}) do
        local childID = type(link) == "table" and link.s
        local childName = childID and not listed[childID] and Name(childID)
        if childName == name then
            text = text or Description(childID)
        elseif childName then
            others[#others + 1] = childID
            listed[childID] = true
        end
    end
    if text then tooltip:AddLine("    " .. text, 1, 0.82, 0, true) end
    for _, childID in ipairs(others) do
        tooltip:AddLine("    " .. Labeled(childID, Name(childID)), 0.9, 0.9, 0.9)
        local childText = Description(childID)
        if childText then tooltip:AddLine("        " .. childText, 0.8, 0.8, 0.8, true) end
    end
end

local function Tooltip(row, _, tooltip)
    local id = NpcOf(row)
    local CB = Bestiary()
    if not (id and CB and CB.IterateAbilities) then return end
    local key = DetailsKey()
    local detailed = Detailed(key)
    local max = detailed and 0 or MaxLines()
    local abilities = {}
    for spellID in CB.IterateAbilities(id) do abilities[#abilities + 1] = spellID end
    local listed = {}
    for _, spellID in ipairs(abilities) do listed[spellID] = true end
    local shown, more = 0, 0
    for _, spellID in ipairs(abilities) do
        local name = Name(spellID)
        if name then
            if max > 0 and shown >= max then
                more = more + 1
            else
                if shown == 0 then
                    tooltip:AddLine(" ")
                    tooltip:AddLine(L["TT_HEADER"], 1, 0.82, 0)
                end
                tooltip:AddLine(Labeled(spellID, name), 1, 1, 1)
                if detailed then AddDetails(tooltip, CB, spellID, name, listed) end
                shown = shown + 1
            end
        end
    end
    if more > 0 then tooltip:AddLine(sformat(L["TT_MORE_FMT"], more), 0.6, 0.6, 0.6) end
    if shown > 0 and not detailed and KEY_DOWN[key] and BestiaryOption("reminder") ~= false then
        tooltip:AddLine(sformat(L["TT_DETAILS_HINT_FMT"], L["KEY_" .. key:upper()]), 0.5, 0.5, 0.5)
    end
end
ns.Applies, ns.Tooltip = Applies, Tooltip

-- The Extensions tab's page: the switch and how many lines a tooltip lists.
local LINE_CHOICES = { { label = "4", value = 4 }, { label = "8", value = 8 }, { label = "12", value = 12 },
                       { label = L["OPT_LINES_ALL"], value = 0 } }
local function Settings(page, kit)
    local below = kit.Title(page, L["EXT_NAME"], L["SETTINGS_HINT"])
    local box = kit.Checkbox(page, L["OPT_SHOW"], Enabled, function(on)
        if on then Store().off = nil else Store().off = true end
    end)
    box:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -8)
    local lines = kit.Choice(page, L["OPT_LINES"], LINE_CHOICES, MaxLines, function(v) Store().lines = v end,
        nil, DEFAULT_LINES)
    lines:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -8)
end
ns.Settings = Settings

API.RegisterExtension({
    id = KEY,
    name = L["EXT_NAME"],
    description = L["EXT_DESC"],
    icon = ICON,
    keywords = { "bestiary", "abilities", "creature", "mob" },
    settings = Settings,
})

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    local CB = Bestiary()
    if not (CB and CB.API_VERSION == 1 and CB.IterateAbilities) then
        ns.Print(L["NOT_READY_BESTIARY"])
        return
    end
    -- Creature ids on rows and a bare row's tooltip came with API 1.6.
    if not (API.RegisterRowDecorator and (API.MINOR or 0) >= 6) then
        ns.Print(L["NOT_READY_EASYFIND"])
        return
    end
    -- modifiers: drawn again as the details key goes down or up (API 1.8).
    API.RegisterRowDecorator({ id = KEY, label = L["EXT_NAME"], applies = Applies, tooltip = Tooltip,
        modifiers = true })
    ns.ready = true
end)
