local _, ns = ...






local Gestures = {}
ns.ResultGestures = Gestures

local L = ns.L
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local select = select


local V = {
    select      = _G["LFG_LIST_SELECT"] or "Select",
    summon      = _G["SUMMON"] or "Summon",
    journal     = _G["PROFESSIONS_JOURNAL_TAB_NAME"] or "Journal",
    preview     = _G["PREVIEW"] or "Preview",
    drag        = _G["DRAG_MODEL"] or "Drag",
    use         = _G["USE"] or "Use",
    equip       = _G["EQUIPSET_EQUIP"] or "Equip",
    spellbook   = _G["SPELLBOOK"] or "Spellbook",
    settings    = _G["SETTINGS"] or "Settings",
    edit        = _G["EDIT"] or "Edit",
    bags        = _G["HUD_EDIT_MODE_BAGS_LABEL"] or "Bags",
    toybox      = _G["TOY_BOX"] or "Toy Box",
    appearances = _G["WARDROBE"] or "Appearances",
    dressroom   = _G["DRESSUP_FRAME"] or "Dressing Room",
    encounter   = _G["ENCOUNTER_JOURNAL"] or "Encounter Journal",
    loot        = _G["LOOT"] or "Loot",
    gps         = L["APP_GPS"],
    achievements = _G["ACHIEVEMENTS"] or "Achievements",
    none        = _G["NONE"] or "None",
    click        = L["HINT_CLICK"],
    wear         = L["HINT_WEAR"],
    cast         = L["HINT_CAST"],
    open         = L["HINT_OPEN"],
    run          = L["HINT_RUN"],
    toggle       = L["HINT_TOGGLE"],
    copyResult   = L["HINT_COPY_RESULT"],
    filterResults = L["HINT_FILTER_RESULTS"],
    enterMode    = L["HINT_ENTER_MODE"],
    applyTitle   = L["HINT_APPLY_TITLE"],
    addToBags    = L["HINT_ADD_TO_BAGS"],
    heirloomsTab = L["HINT_HEIRLOOMS_TAB"],
    openTransmog = L["HINT_OPEN_TRANSMOG"],
    equipGearSet = L["HINT_EQUIP_GEAR_SET"],
    openMap      = L["HINT_OPEN_MAP"],
    pinOnMap     = L["HINT_PIN_ON_MAP"],
    clickDrag    = L["HINT_CLICK_DRAG"],
    sendLink     = L["CTX_SEND_LINK"],
    sources      = L["HINT_SOURCES"],
    wares        = L["HINT_WARES"],
    bosses       = _G["RAID_BOSSES"] or "Bosses",
}
Gestures.V = V

local GESTURES = { "click", "alt", "ctrl", "shift" }
Gestures.GESTURES = GESTURES
Gestures.SETTABLE = { "click", "alt", "ctrl" }






local function A(key, word, default, role)
    return { key = key, word = word, default = default, role = role }
end
local KINDS = {
    { key = "mount", actions = { A("summon", "summon", "click", "primary"), A("journal", "journal", "alt", "source"),
        A("preview", "preview", "ctrl", "preview"), A("drag", "drag", "shift") } },
    { key = "pet", actions = { A("summon", "summon", "click", "primary"), A("journal", "journal", "alt", "source"),
        A("drag", "drag", "shift") } },
    { key = "toy", actions = { A("use", "use", "click", "primary"), A("toybox", "toybox", "alt", "source"),
        A("drag", "drag", "shift") } },
    { key = "heirloom", actions = { A("addToBags", "addToBags", "click", "primary"), A("heirloomsTab", "heirloomsTab", "alt", "source") } },
    { key = "outfit", actions = { A("wear", "wear", "click", "primary"), A("transmog", "openTransmog", "alt", "source"),
        A("drag", "drag", "shift") } },
    { key = "transmogSet", actions = { A("appearances", "appearances", "click", "primary"), A("dressroom", "dressroom", "ctrl", "preview") } },
    { key = "ability", actions = { A("cast", "cast", "click", "primary"), A("spellbook", "spellbook", "alt", "source"),
        A("drag", "drag", "shift") } },
    { key = "macro", actions = { A("run", "run", "click", "primary"), A("edit", "edit", "alt", "source"),
        A("drag", "drag", "shift") } },
    { key = "bag", actions = { A("action", "use", "click", "primary"), A("bags", "bags", "alt", "source"),
        A("dressroom", "dressroom", "ctrl", "preview"), A("drag", "drag", "shift") } },


    { key = "catalog", actions = { A("sources", "sources", "click", "primary"), A("dressroom", "dressroom", "ctrl", "preview"),
        A("sendLink", "sendLink", "shift") } },
    { key = "loot", actions = { A("sources", "sources", "click", "primary"), A("encounter", "encounter", "alt", "source"),
        A("dressroom", "dressroom", "ctrl", "preview"), A("sendLink", "sendLink", "shift") } },


    { key = "instance", actions = { A("gps", "gps", "click", "primary"), A("bosses", "bosses", "ctrl"),
        A("openMap", "openMap", "shift", "source") } },
    { key = "title", actions = { A("apply", "applyTitle", "click", "primary"), A("achievements", "achievements", "alt", "source") } },
    { key = "settingToggle", actions = { A("toggle", "toggle", "click", "primary"), A("settings", "settings", "alt", "source") } },
    { key = "settingPress", actions = { A("run", "run", "click", "primary"), A("settings", "settings", "alt", "source") } },
    { key = "quickKeybind", actions = { A("enterMode", "enterMode", "click", "primary"), A("settings", "settings", "alt", "source") } },
}
local byKey = {}
for i = 1, #KINDS do
    local kind = KINDS[i]
    kind.byAction, kind.defaults = {}, {}
    for a = 1, #kind.actions do
        local action = kind.actions[a]
        kind.byAction[action.key] = action
        kind.defaults[action.default] = action.key
        if action.role == "primary" then kind.primary = action.key end
        if action.role == "source" then kind.source = action.key end
        if action.role == "preview" then kind.preview = action.key end
    end
    byKey[kind.key] = kind
end


function Gestures.ShiftFixed(kindKey)
    local kind = byKey[kindKey]
    return kind ~= nil and kind.defaults.shift ~= nil
end

function Gestures.SettableFor(kindKey)
    return Gestures.ShiftFixed(kindKey) and Gestures.SETTABLE or GESTURES
end

function Gestures.Kinds() return KINDS end
function Gestures.Kind(key) return byKey[key] end


function Gestures.KindOf(data)
    if not data then return nil end
    if data.quickKeybindActivate then return "quickKeybind" end
    if data.titleID then return "title" end
    if data.mountID then return "mount" end
    if data.petID or data.speciesID then return "pet" end
    if data.toyItemID then return "toy" end
    if data.heirloomItemID then return "heirloom" end
    if data.outfitID then return "outfit" end
    if data.transmogSetID then return "transmogSet" end
    if data.spellID and data.category == "Ability" then return "ability" end
    if data.macroIndex then return "macro" end
    if data.catalogItem or data.storedRemote then return "catalog" end
    if data.itemID and data.category == "Loot" then return "loot" end
    if data.itemID and data.category == "Bag" then return "bag" end
    if (data.settingType == "checkbox" or data.settingType == "checkboxSlider") and data.settingVariable then
        return "settingToggle"
    end
    if data.settingType == "keybind" and data.bindingAction then return "settingToggle" end
    if data.settingPress then return "settingPress" end
    if data.isDungeonEntrance and data.category ~= "delve" then return "instance" end
    return nil
end

local NON_DRESSABLE_SLOT = { [""] = true, INVTYPE_BAG = true, INVTYPE_QUIVER = true, INVTYPE_AMMO = true }

local function Dressable(data)
    local equipLoc = C_Item and C_Item.GetItemInfoInstant and select(4, C_Item.GetItemInfoInstant(data.itemID))
    return equipLoc ~= nil and not NON_DRESSABLE_SLOT[equipLoc]
end




function Gestures.Available(data, kind, action)
    local Icons, Handlers, Db = ns.ResultIcons, ns.ResultHandlers, ns.Database
    if kind == "mount" and action == "summon" then return Icons:IsMountSummonable(data) end
    if kind == "pet" and action == "summon" then return Icons:IsPetSummonable(data) end
    if kind == "toy" and action == "use" then return not data.isToyboxOnly end
    if kind == "ability" and action == "cast" then return not Icons:IsSpellbookOnlyAbility(data) end
    if kind == "ability" and action == "spellbook" then return not data.professionAbility end
    if kind == "bag" then
        local actionKind = Handlers:GetBagItemActionKind(data)
        if action == "action" then return actionKind ~= nil end
        if action == "dressroom" then return actionKind == "equip" end
    end
    if (kind == "catalog" or kind == "loot") and action == "dressroom" then return Dressable(data) end
    if kind == "title" then
        if action == "apply" then return not data.titleUnearned end
        return Db and Db.GetTitleSourceAchievement and Db:GetTitleSourceAchievement(data.titleID) ~= nil
    end
    if kind == "settingToggle" and action == "toggle" and data.settingType == "keybind" then
        return ns.BlizzOptionsSearch and ns.BlizzOptionsSearch:IsPerformableBinding(data.bindingAction) or false
    end
    if kind == "instance" then
        local api = EasyFind and EasyFind.API
        if action == "gps" then
            return api ~= nil and api.HasAction("gps", "navigate") and api.CallAction("gps", "canNavigate", data) == true
        end
        if action == "bosses" then
            return ns.ItemSources ~= nil and ns.ItemSources.InstanceHasBosses(data.name)
        end
    end
    if action == "sources" then return ns.ItemSources ~= nil and ns.ItemSources.Available(data) end
    return true
end



local function Chosen(kind, gesture)
    local db = EasyFind and EasyFind.db and EasyFind.db.resultClicks
    local own = db and db[kind.key]
    local choice = own and own[gesture]
    if choice == "none" or (choice and kind.byAction[choice]) then return choice end
    return nil
end




function Gestures.ActionFor(data, gesture)
    local kind = byKey[Gestures.KindOf(data)]
    if not kind then return nil end
    local action = (gesture ~= "shift" or not kind.defaults.shift) and Chosen(kind, gesture) or kind.defaults[gesture]
    if action == "none" then return "none" end
    if action and Gestures.Available(data, kind.key, action) then return action end
    if action and action == kind.primary and kind.source and gesture == kind.actions[1].default
       and Gestures.Available(data, kind.key, kind.source) then
        return kind.source
    end
    return nil
end



function Gestures.ShiftChosen(data)
    local kind = byKey[Gestures.KindOf(data)]
    if not kind or kind.defaults.shift then return nil end
    return Chosen(kind, "shift")
end



function Gestures.Held()
    local Handlers, Shortcuts = ns.ResultHandlers, ns.ResultShortcuts
    if Handlers and Handlers._openInPlace then return "alt" end
    if Shortcuts and Shortcuts._resultShortcutActivation then return "click" end
    if IsShiftKeyDown and IsShiftKeyDown() then return "shift" end
    if IsControlKeyDown and IsControlKeyDown() then return "ctrl" end
    if IsAltKeyDown and IsAltKeyDown() then return "alt" end
    return "click"
end

function Gestures.Does(data, action)
    return Gestures.ActionFor(data, Gestures.Held()) == action
end


function Gestures.WantsSource(data)
    local kind = byKey[Gestures.KindOf(data)]
    return kind ~= nil and kind.source ~= nil and Gestures.Does(data, kind.source)
end

function Gestures.WantsPreview(data)
    local kind = byKey[Gestures.KindOf(data)]
    return kind ~= nil and kind.preview ~= nil and Gestures.Does(data, kind.preview)
end

function Gestures.Blocked(data)
    return Gestures.ActionFor(data, Gestures.Held()) == "none"
end

local function Word(data, kind, action, gesture)
    if kind.key == "bag" and action == "action" then
        local actionKind = ns.ResultHandlers:GetBagItemActionKind(data)
        return actionKind == "equip" and V.equip or actionKind == "open" and V.open or V.use
    end


    if action == "encounter" and not (ns.Caps and ns.Caps.journal) then
        local words = ns.Extensions and ns.Extensions.DecoratorHint and ns.Extensions.DecoratorHint(data)
        return words and words[gesture] or V.gps
    end
    return V[kind.byAction[action].word]
end

local MOD_NAME = { alt = "Alt", ctrl = "Ctrl", shift = "Shift" }



function Gestures.Hint(data)
    local kind = byKey[Gestures.KindOf(data)]
    if not kind then return nil end
    local s
    for g = 1, #GESTURES do
        local gesture = GESTURES[g]
        local action = Gestures.ActionFor(data, gesture)
        if action and action ~= "none" then
            local lead = gesture == "click" and (action == "sendLink" and V.clickDrag or V.click) or MOD_NAME[gesture]
            local part = lead .. ": " .. Word(data, kind, action, gesture)
            s = s and (s .. " | " .. part) or part
        end
    end
    return s
end



function Gestures.Choices(kind)
    local list = {}
    for a = 1, #kind.actions do
        local action = kind.actions[a]
        if action.key ~= "drag" then
            list[#list + 1] = { value = action.key, label = V[action.word] }
        end
    end
    list[#list + 1] = { value = "none", label = V.none }
    return list
end

function Gestures.Get(kindKey, gesture)
    local kind = byKey[kindKey]
    return kind and (Chosen(kind, gesture) or kind.defaults[gesture] or "none") or "none"
end

function Gestures.Set(kindKey, gesture, action)
    local kind = byKey[kindKey]
    if not (kind and EasyFind and EasyFind.db) then return end
    local db = EasyFind.db.resultClicks
    if type(db) ~= "table" then db = {} EasyFind.db.resultClicks = db end
    local own = db[kindKey] or {}
    if action == (kind.defaults[gesture] or "none") then own[gesture] = nil else own[gesture] = action end
    db[kindKey] = next(own) and own or nil
end

function Gestures.Reset()
    if EasyFind and EasyFind.db then EasyFind.db.resultClicks = {} end
end
