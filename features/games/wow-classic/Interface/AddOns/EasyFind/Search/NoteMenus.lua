local _, ns = ...
local L = ns.L







local issecret = _G.issecretvalue or function() return false end
local sformat = string.format

local function Realm(realm)
    if type(realm) == "string" and realm ~= "" and not issecret(realm) then return (realm:gsub("%s", "")) end
    local own = GetNormalizedRealmName and GetNormalizedRealmName()
    if not own or own == "" then own = ((GetRealmName and GetRealmName()) or ""):gsub("%s", "") end
    return own
end



function ns.NotesPlayerKey(name, realm)
    if type(name) ~= "string" or name == "" or issecret(name) then return nil end
    local base, inName = name:match("^([^%-]+)%-(.+)$")
    base = (base or name):match("^(%S+)")
    if not base then return nil end
    return base .. "-" .. Realm(inName or realm)
end



function ns.NotesUnitEntry(unit)
    if not (unit and UnitExists(unit)) or UnitIsUnit(unit, "player") then return nil end
    if UnitIsPlayer(unit) then
        local full = GetUnitName(unit, true)
        if type(full) ~= "string" or issecret(full) then return nil end
        local key = ns.NotesPlayerKey(full)
        local _, classFile = UnitClass(unit)
        return key and { type = "player", id = key, name = GetUnitName(unit, false) or full, class = classFile } or nil
    end
    local guid = UnitGUID(unit)
    if type(guid) ~= "string" or issecret(guid) then return nil end
    local npcID = tonumber(guid:match("Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    if not npcID then return nil end
    local name = UnitName(unit)
    if type(name) ~= "string" or issecret(name) then name = nil end
    return { type = "npc", id = npcID, name = name or sformat(L["NOTES_NPC_FMT"], npcID) }
end

local UNIT_MENUS = {
    "PLAYER", "PARTY", "RAID_PLAYER", "RAID", "FRIEND", "FRIEND_OFFLINE", "ENEMY_PLAYER",
    "GUILD", "GUILD_OFFLINE", "COMMUNITIES_GUILD_MEMBER", "COMMUNITIES_WOW_MEMBER",
    "CHAT_ROSTER", "TARGET", "FOCUS", "BOSS", "RECENT_ALLY", "RECENT_ALLY_OFFLINE",
}



local function MenuUnit(contextData)
    if not contextData then return nil end
    local unit = contextData.unit
    if unit and UnitExists(unit) then return ns.NotesUnitEntry(unit) end
    local name = contextData.name
    if type(name) ~= "string" or name == "" or issecret(name) then return nil end
    local key = ns.NotesPlayerKey(name, contextData.server)
    if not key or key == ns.NotesPlayerKey(ns.PlayerName(), GetRealmName()) then return nil end
    return { type = "player", id = key, name = name:match("^([^%-]+)") or name }
end

local function AddMakeNote(_, root, contextData)
    if not (EasyFind.db and EasyFind.db.notesPlayerMenu ~= false) then return end
    if not (ns.IsCompanionLoadable and ns.IsCompanionLoadable("EasyFind_Notes")) then return end
    local entry = MenuUnit(contextData)
    if not entry then return end
    local has = EasyFind.API.HasAction("notes", "findUnitNote") and EasyFind.API.CallAction("notes", "findUnitNote", entry)
    root:CreateDivider()
    root:CreateButton(has and L["NOTES_OPEN_NOTE"] or L["NOTES_MAKE_NOTE"], function()
        EasyFind.API.CallAction("notes", "openUnitNote", entry)
    end)
end

if Menu and Menu.ModifyMenu then
    for i = 1, #UNIT_MENUS do
        Menu.ModifyMenu("MENU_UNIT_" .. UNIT_MENUS[i], AddMakeNote)
    end
end





local function CtrlRightClick()
    return IsControlKeyDown() and not IsShiftKeyDown() and not IsAltKeyDown()
        and GetMouseButtonClicked and GetMouseButtonClicked() == "RightButton"
end


local function OpenObjectNote(entry, bound)
    if not bound and not (EasyFind.db and EasyFind.db.notesPlayerMenu ~= false) then return end
    if not (ns.IsCompanionLoadable and ns.IsCompanionLoadable("EasyFind_Notes")) then return end
    EasyFind.API.CallAction("notes", "openUnitNote", entry)
end

if hooksecurefunc then
    hooksecurefunc("HandleModifiedItemClick", function(link)
        if type(link) ~= "string" or issecret(link) or not CtrlRightClick() then return end
        local id = tonumber(link:match("|Hitem:(%d+)"))
        if id then OpenObjectNote({ type = "item", id = id, name = link:match("%[(.-)%]") or tostring(id) }) end
    end)
end



function EasyFind:OpenObjectNote(kind, id, name)
    if (kind ~= "spell" and kind ~= "item") or type(id) ~= "number" then return end
    OpenObjectNote({ type = kind, id = id, name = name or tostring(id) })
end



function ns.OpenHoveredNote()
    local tip = GameTooltip
    if not (tip and tip:IsShown()) then return end
    local data = tip.GetPrimaryTooltipData and tip:GetPrimaryTooltipData()
    local kinds = Enum and Enum.TooltipDataType or {}
    local id = data and data.id
    if type(id) == "number" and not issecret(id) then
        if data.type == kinds.Spell then
            local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
            return OpenObjectNote({ type = "spell", id = id, name = name or tostring(id) }, true)
        elseif data.type == kinds.Item then
            local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
            return OpenObjectNote({ type = "item", id = id, name = name or tostring(id) }, true)
        end
    end
    local okS, spellName, spellID = pcall(tip.GetSpell, tip)
    if okS and type(spellID) == "number" and not issecret(spellID) then
        return OpenObjectNote({ type = "spell", id = spellID, name = spellName or tostring(spellID) }, true)
    end
    local okI, itemName, link = pcall(tip.GetItem, tip)
    local itemID = okI and type(link) == "string" and not issecret(link) and tonumber(link:match("|Hitem:(%d+)"))
    if itemID then return OpenObjectNote({ type = "item", id = itemID, name = itemName or tostring(itemID) }, true) end
    local okU, _, unit = pcall(tip.GetUnit, tip)
    local entry = okU and type(unit) == "string" and not issecret(unit) and ns.NotesUnitEntry(unit)
    if entry then OpenObjectNote(entry, true) end
end



local spellBookHooked = false
local function HookSpellBook()
    local mixin = _G.SpellBookItemMixin
    if spellBookHooked or not (mixin and mixin.OnModifiedIconClick and hooksecurefunc) then return end
    spellBookHooked = true
    ns.SpellBookNoteHook = mixin
    hooksecurefunc(mixin, "OnModifiedIconClick", function(self, button)
        if button ~= "RightButton" or not CtrlRightClick() then return end
        local info = self.spellBookItemInfo
        local id = info and info.spellID
        if type(id) == "number" then
            OpenObjectNote({ type = "spell", id = id, name = info.name or tostring(id) })
        end
    end)
end
do
    local watch = CreateFrame("Frame")
    watch:RegisterEvent("ADDON_LOADED")
    watch:SetScript("OnEvent", function(self, _, name)
        if name ~= "Blizzard_PlayerSpells" then return end
        HookSpellBook()
        self:UnregisterAllEvents()
    end)
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_PlayerSpells") then
        HookSpellBook()
        watch:UnregisterAllEvents()
    end
end





local function NoteClickOwner(owner)
    if not owner then return false end
    if owner._efNoteClicks then return true end
    local modified = owner.OnModifiedClick
    local bag, bank = _G.ContainerFrameItemButtonMixin, _G.BankPanelItemButtonMixin
    if modified and ((bag and modified == bag.OnModifiedClick) or (bank and modified == bank.OnModifiedClick)) then
        return true
    end
    local name = owner.GetName and owner:GetName()
    if type(name) == "string" and not issecret(name) and name:match("^Character%a+Slot$") then return true end
    local parent = owner.GetParent and owner:GetParent()
    if parent and parent.Item == owner and parent.GetSlotIndex then return true end
    return owner.spellBookItemInfo ~= nil or (parent and parent.spellBookItemInfo ~= nil) or false
end

local function AddNoteClickHint(tooltip, kind, id)
    local db = EasyFind.db
    if not (db and db.notesClickHint ~= false and db.notesPlayerMenu ~= false) then return end
    if tooltip ~= GameTooltip or type(id) ~= "number" or issecret(id) then return end
    if not (ns.IsCompanionLoadable and ns.IsCompanionLoadable("EasyFind_Notes")) then return end
    if not NoteClickOwner(tooltip:GetOwner()) then return end
    local API = EasyFind.API
    local has = API.HasAction("notes", "findUnitNote") and API.CallAction("notes", "findUnitNote", { type = kind, id = id })
    local c = _G.GREEN_FONT_COLOR
    tooltip:AddLine(has and L["NOTES_HINT_OPEN"] or L["NOTES_HINT_MAKE"], c and c.r or 0.1, c and c.g or 1, c and c.b or 0.1)
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        AddNoteClickHint(tooltip, "item", data and data.id)
    end)
    if Enum.TooltipDataType.Spell then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)
            AddNoteClickHint(tooltip, "spell", data and data.id)
        end)
    end
end
