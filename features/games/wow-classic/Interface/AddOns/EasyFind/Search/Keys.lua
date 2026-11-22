local _, ns = ...




local Keys = {}
ns.Keys = Keys

local Utils = ns.Utils
local slower = Utils.slower
local GetSpellName = C_Spell and C_Spell.GetSpellName
local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture
local GetItemName = C_Item and C_Item.GetItemNameByID
local GetItemIcon = C_Item and C_Item.GetItemIconByID


local BARS = {
    { "ACTIONBUTTON", "ActionButton" },
    { "MULTIACTIONBAR1BUTTON", "MultiBarBottomLeftButton" },
    { "MULTIACTIONBAR2BUTTON", "MultiBarBottomRightButton" },
    { "MULTIACTIONBAR3BUTTON", "MultiBarRightButton" },
    { "MULTIACTIONBAR4BUTTON", "MultiBarLeftButton" },
    { "MULTIACTIONBAR5BUTTON", "MultiBar5Button" },
    { "MULTIACTIONBAR6BUTTON", "MultiBar6Button" },
    { "MULTIACTIONBAR7BUTTON", "MultiBar7Button" },
}
local BAR_SIZE = 12
local buttonOf = {}
for _, bar in ipairs(BARS) do buttonOf[bar[1]] = bar[2] end


local function ButtonSlot(button)
    if type(button) ~= "table" then return nil end
    local slot = button.action
    if type(slot) ~= "number" and button.GetAttribute then slot = button:GetAttribute("action") end
    return type(slot) == "number" and slot > 0 and slot or nil
end



local function CommandSlot(command)
    local bar, index = command:match("^(.-BUTTON)(%d+)$")
    local frameName = bar and buttonOf[bar] and (buttonOf[bar] .. index) or command:match("^CLICK ([^:]+)")
    return frameName and ButtonSlot(_G[frameName]) or nil, frameName
end


local function SlotAction(slot)
    local kind, id = GetActionInfo(slot)
    if kind == "spell" and id then
        return GetSpellName and GetSpellName(id), GetSpellTexture and GetSpellTexture(id), id
    elseif kind == "item" and id then
        return GetItemName and GetItemName(id), GetItemIcon and GetItemIcon(id)
    elseif kind == "macro" then
        local spell = id and GetMacroSpell and GetMacroSpell(id)
        return GetActionText and GetActionText(slot), GetActionTexture and GetActionTexture(slot), spell
    end
    return nil
end

local function KeyText(key)
    return GetBindingText and GetBindingText(key) or key
end
Keys.Text = KeyText



local keyBySpell, keyByName, stale = {}, {}, true

local function Rebuild()
    wipe(keyBySpell)
    wipe(keyByName)
    for _, bar in ipairs(BARS) do
        for index = 1, BAR_SIZE do
            local key = GetBindingKey(bar[1] .. index)
            local slot = key and ButtonSlot(_G[bar[2] .. index])
            if slot then
                local name, _, spellID = SlotAction(slot)
                if spellID and not keyBySpell[spellID] then keyBySpell[spellID] = key end
                if spellID and name and not keyByName[name] then keyByName[name] = key end
            end
        end
    end
end



function Keys.SpellKey(spellID, spellName)
    if stale and not InCombatLockdown() then
        stale = false
        Rebuild()
    end
    local key = keyBySpell[spellID] or (spellName and keyByName[spellName])
    return key and KeyText(key) or nil
end

local watcher = CreateFrame("Frame")
for _, event in ipairs({ "UPDATE_BINDINGS", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED",
                         "UPDATE_BONUS_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM", "PLAYER_ENTERING_WORLD" }) do
    Utils.RegisterEventIfValid(watcher, event)
end
watcher:SetScript("OnEvent", function() stale = true end)



local MODIFIER = { shift = "SHIFT", ctrl = "CTRL", control = "CTRL", alt = "ALT" }
local NAMED = {
    space = "SPACE", spacebar = "SPACE", tab = "TAB", esc = "ESCAPE", escape = "ESCAPE", enter = "ENTER",
    backspace = "BACKSPACE", delete = "DELETE", insert = "INSERT", home = "HOME", ["end"] = "END",
    pageup = "PAGEUP", pagedown = "PAGEDOWN", up = "UP", down = "DOWN", left = "LEFT", right = "RIGHT",
    mouse3 = "BUTTON3", mouse4 = "BUTTON4", mouse5 = "BUTTON5", button3 = "BUTTON3", button4 = "BUTTON4",
    button5 = "BUTTON5", wheelup = "MOUSEWHEELUP", wheeldown = "MOUSEWHEELDOWN",
    mwheelup = "MOUSEWHEELUP", mwheeldown = "MOUSEWHEELDOWN",
    mousewheelup = "MOUSEWHEELUP", mousewheeldown = "MOUSEWHEELDOWN",
}

local function KeyName(word)
    if NAMED[word] then return NAMED[word] end
    if #word == 1 and not word:find("%s") then return word:upper() end
    local fn = word:match("^f(%d%d?)$")
    if fn and tonumber(fn) >= 1 and tonumber(fn) <= 12 then return "F" .. fn end
    local pad = word:match("^num(%d)$") or word:match("^numpad(%d)$")
    return pad and ("NUMPAD" .. pad) or nil
end



function Keys.Parse(text)
    local words = {}
    for word in slower(text):gsub("%+", " "):gsub("(%w)%-(.)", "%1 %2"):gmatch("%S+") do words[#words + 1] = word end
    if #words == 0 then return nil end
    local key = KeyName(words[#words])
    if not key then return nil end
    local held = {}
    for i = 1, #words - 1 do
        local mod = MODIFIER[words[i]]
        if not mod or held[mod] then return nil end
        held[mod] = true
    end
    return (held.ALT and "ALT-" or "") .. (held.CTRL and "CTRL-" or "") .. (held.SHIFT and "SHIFT-" or "") .. key
end

local function BindingName(command)
    local name = _G["BINDING_NAME_" .. command]
    if type(name) == "string" and name ~= "" then return name end
    return GetBindingName and GetBindingName(command) or command
end





function Keys.Answer(text)
    local asked = slower(text):match("^key%s+(.+)$")
    local key = Keys.Parse(asked or text)
    if not key or (#key == 1 and not asked) then return nil end
    local command = GetBindingAction and GetBindingAction(key, true)
    if not command or command == "" then return nil end
    local slot, button = CommandSlot(command)
    if button then
        local name, icon
        if slot then name, icon = SlotAction(slot) end
        if not name then return nil end
        return KeyText(key), name .. " (" .. BindingName(command) .. ")", icon
    end
    local kind, what = command:match("^(%u+) (.+)$")
    if kind == "SPELL" or kind == "ITEM" or kind == "MACRO" then return KeyText(key), what end
    return KeyText(key), BindingName(command)
end
