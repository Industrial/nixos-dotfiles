--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2026 - James N. Whitehead II
-------------------------------------------------------------------]]--

---@class CliqueAddon: AddonCore
local addon = select(2, ...)

local L = addon.L

local strconcat = strconcat
local strsplit = string.split

local inventorySlotNames = {
    ["13"] = L["Primary Trinket"],
    ["14"] = L["Secondary Trinket"],
}

function addon.tcontains(arr, value)
    for _, key in ipairs(arr) do
        if key == value then
            return true
        end
    end
end

-- Returns the prefix string for the current keyboard state.
--
-- Arguments:
--   extended - Whether or not to split the modifier keys into left and right components

function addon:GetPrefixString(extended)
    local shift, lshift, rshift = IsShiftKeyDown(), IsLeftShiftKeyDown(), IsRightShiftKeyDown()
    local ctrl, lctrl, rctrl = IsControlKeyDown(), IsLeftControlKeyDown(), IsRightControlKeyDown()
    local alt, lalt, ralt = IsAltKeyDown(), IsLeftAltKeyDown() IsRightAltKeyDown()
    local meta, lmeta, rmeta = false, false, false

    if self:ProjectIsRetail() then
        meta, lmeta, rmeta = IsMetaKeyDown(), IsLeftMetaKeyDown(), IsRightMetaKeyDown()
    end

    if not extended then
        shift = shift or lshift or rshift
        ctrl = ctrl or lctrl or rctrl
        alt = alt or lalt or ralt
        meta = meta or lmeta or rmeta

        lshift, rshift = false, false
        lctrl, rctrl = false, false
        lalt, ralt = false, false
        lmeta, rmeta = false, false
    end

    local prefix = ""
    if shift then
        prefix = ((lshift and "LSHIFT-") or (rshift and "RSHIFT-") or "SHIFT-") .. prefix
    end
    if ctrl then
        prefix = ((lctrl and "LCTRL-") or (rctrl and "RCTRL-") or "CTRL-") .. prefix
    end
    if alt then
        prefix = ((lalt and "LALT-") or (ralt and "RALT-") or "ALT-") .. prefix
    end
    if meta then
        prefix = ((lmeta and "LMETA-") or (rmeta and "RMETA-") or "META-") .. prefix
    end

    return prefix
end

-- This function can return a substring of a UTF-8 string, properly handling
-- UTF-8 codepoints.  Rather than taking a start index and optionally an end
-- index, it takes the string, the start index and the number of characters
-- to select from the string.
--
-- UTF-8 Reference:
-- 0xxxxxx - ASCII character
-- 110yyyxx - 2 byte UTF codepoint
-- 1110yyyy - 3 byte UTF codepoint
-- 11110zzz - 4 byte UTF codepoint

local function utf8sub(str, start, numChars)
    local currentIndex = start
    while numChars > 0 and currentIndex <= #str do
        local char = string.byte(str, currentIndex)
        if char >= 240 then
            currentIndex = currentIndex + 4
        elseif char >= 225 then
            currentIndex = currentIndex + 3
        elseif char >= 192 then
            currentIndex = currentIndex + 2
        else
            currentIndex = currentIndex + 1
        end
        numChars = numChars - 1
    end
    return str:sub(start, currentIndex - 1)
end

local convertMap = setmetatable({
    LSHIFT = L["LShift"],
    RSHIFT = L["RShift"],
    SHIFT = L["Shift"],
    LCTRL = L["LCtrl"],
    RCTRL = L["RCtrl"],
    CTRL = L["Ctrl"],
    LALT = L["LAlt"],
    RALT = L["RAlt"],
    ALT = L["Alt"],
    META = L["Meta"],
    LMETA = L["LMeta"],
    RMETA = L["RMeta"],
    BUTTON1 = L["LeftButton"],
    BUTTON2 = L["RightButton"],
    BUTTON3 = L["MiddleButton"],
    MOUSEWHEELUP = L["MousewheelUp"],
    MOUSEWHEELDOWN = L["MousewheelDown"],
}, {
    __index = function(t, k)
        if k:match("^BUTTON(%d+)$") then
            return k:gsub("^BUTTON(%d+)$", "Button%1")
        else
            if utf8sub(k, 1, 1) ~= k:sub(1, 1) then
                -- If the first character is a multi-byte UTF-8 character
                return k
            else
                -- Make the first character upper-case, lower the rest
                return tostring(k:sub(1, 1):upper()) .. tostring(k:sub(2, -1):lower())
            end
        end
    end,
})

local function convert(item, ...)
    if not item then
        return ""
    else
        local mapItem = convertMap[item]
        item = mapItem and mapItem or item

        if select("#", ...) > 0 then
            return item, "-", convert(...)
        else
            return item, convert(...)
        end
    end
end

function addon:GetBindingIcon(binding)
    if type(binding) ~= "table" or not binding.type then
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    local btype = binding.type
    if btype == "menu" then
        return 132212
    elseif btype == "target" then
        return 132331
    else
        return binding.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    end
end

function addon:IsGamePadBinding(binding)
    return type(binding) == "table" and binding.key and IsBindingForGamePad(binding.key, 1)
end

function addon:GetBindingKeyComboText(binding)
    if self:IsGamePadBinding(binding) then
        return GetBindingText(binding.key, 1)
    elseif type(binding) == "table" and binding.key then
        return strconcat(convert(strsplit("-", binding.key)))
    elseif type(binding) == "string" then
        return strconcat(convert(strsplit("-", binding)))
    else
        return L["Unknown"]
    end
end

function addon:SpellTextWithSubName(binding)
    if binding.spellSubName then
        return string.format("%s(%s)", binding.spell, binding.spellSubName)
    else
        return binding.spell
    end
end

function addon:SpellTextWithoutSubName(binding)
    return binding.spell
end

function addon:GetBindingActionText(btype, binding, skipSubName)
    if btype == "menu" then
        return L["Show unit menu"]
    elseif btype == "target" then
        return L["Target clicked unit"]
    elseif btype == "spell" and skipSubName then
        return L["Cast %s"]:format(self:SpellTextWithoutSubName(binding))
    elseif btype == "spell" then
        return L["Cast %s"]:format(self:SpellTextWithSubName(binding))
    elseif btype == "macro" and type(binding) == "table" and binding.macro then
        return L["Run macro '%s'"]:format(tostring(binding.macro))
    elseif btype == "macro" and binding.macrotext then
        return L["Run custom macro '%s'"]:format(tostring(binding.macrotext))
    elseif btype == "macro" then
        return L["Run custom macro"]
    elseif btype == "item" then
        local slotName = inventorySlotNames[binding.item]
        return L["Use item: %s"]:format(slotName or tostring(binding.item))
    else
        return L["Unknown binding type '%s'"]:format(tostring(btype))
    end
end

function addon:GetBindingKey(binding)
    if type(binding) ~= "table" or not binding.key then
        return "UNKNOWN"
    end

    local key = binding.key:match("[^%-]+$")
    return key
end

local binMap = {
    ALT = 1,
    LALT = 2,
    RALT = 3,
    CTRL = 4,
    LCTRL = 5,
    RCTRL = 6,
    SHIFT = 7,
    LSHIFT = 8,
    RSHIFT = 9,
    LMETA = 10,
    RMETA = 11,
    META = 12,
}

function addon:GetBinaryBindingKey(binding)
    if type(binding) ~= "table" or not binding.key then
        return "000000000000"
    end

    local ret = {"0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"}
    local splits = {strsplit("-", binding.key)}
    for idx, modifier in ipairs(splits) do
        local bit = binMap[modifier]
        if bit then
            ret[bit] = "1"
        else
            ret[10] = modifier
        end
    end
    return table.concat(ret)
end

local invalidKeys = {
    ["UNKNOWN"] = true,
    ["LSHIFT"] = true,
    ["RSHIFT"] = true,
    ["LCTRL"] = true,
    ["RCTRL"] = true,
    ["LALT"] = true,
    ["RALT"] = true,
    ["ESCAPE"] = true,
    ["LMETA"] = true,
    ["RMETA"] = true,
}

function addon:GetCapturedKey(key)
    -- We can't bind modifiers or invalid keys
    if invalidKeys[key] then
        return
    end

    -- Remap any mouse buttons
    if key == "LeftButton" then
        key = "BUTTON1"
    elseif key == "RightButton" then
        key = "BUTTON2"
    elseif key == "MiddleButton" then
        key = "BUTTON3"
    elseif key == "-" then
        key = "DASH"
    elseif key == "\\" then
        key = "BACKSLASH"
    elseif key == "\"" then
        key = "DOUBLEQUOTE"
    else
        local buttonNum = key:match("Button(%d+)")
        if buttonNum and tonumber(buttonNum) <= 31 then
            key = "BUTTON" .. buttonNum
        end
    end

    -- Splitting modifier keys into left/right has some odd
    -- behaviour at the moment, so let's not enable that.
    local prefix = self:GetPrefixString(false)
    return tostring(prefix) .. tostring(key)
end

function addon:GetBindingInfoText(binding)
    if type(binding) ~= "table" or not binding.sets then
        return L["This binding is invalid, please delete"]
    end

    local sets = binding.sets
    if not sets then
        return ""
    elseif not next(sets) then
        -- No bindings set, so display a message
        return L["This binding is DISABLED"]
    else
        local bits = {}
        for k,v in pairs(sets) do
            table.insert(bits, k)
        end
        table.sort(bits)
        return table.concat(bits, ", ")
    end
end

function addon:ConvertSpecialKeys(binding)
    if type(binding) ~= "table" or not binding.key then
        return "UNKNOWN"
    end

    local mods, key = binding.key:match("^(.-)([^%-]+)$")
    if key == "DASH" then
        key = "-"
    elseif key == "BACKSLASH" then
        key = "\\"
    elseif key == "DOUBLEQUOTE" then
        key = "\""
    end

    return tostring(mods) .. tostring(key)
end

function addon:GetPrefixStringFromBinding(binding)
    return binding.key:match("^(.+%-)[^%-]+$") or ""
end

function addon:GetBindingPrefixSuffix(binding, global)
    if type(binding) ~= "table" or not binding.key then
        return "UNKNOWN", "UNKNOWN"
    end

    local prefix, suffix = binding.key:match("^(.-)([^%-]+)$")
    if prefix:sub(-1, -1) == "-" then
        prefix = prefix:sub(1, -2)
    end

    prefix = prefix:lower()

    local prefixKey = prefix:gsub("[%A]", "")
    local buttonNum = suffix:match("^BUTTON(%d+)$")

    if buttonNum and global then
        suffix = "cliquemouse" .. tostring(prefixKey) .. tostring(buttonNum)
        prefix = ""
    elseif buttonNum then
        suffix = buttonNum
    else
        suffix = "cliquebutton" .. tostring(prefixKey) .. tostring(suffix)
        prefix = ""
    end

    return prefix, suffix
end

-- The mouse button number for a binding (e.g. "2" for SHIFT-BUTTON2), or nil for
-- keyboard bindings.
function addon:GetMouseButtonNumber(binding)
    if type(binding) ~= "table" or not binding.key then
        return nil
    end
    return binding.key:match("BUTTON(%d+)$")
end

-- The frame->proxy transport: "click" or "macrotext" (opt-in). See BUGS.md B12.
function addon:GetDispatchMode()
    return self.settings.dispatchMode
end

-- True when the frame->proxy transport should use type=macro/macrotext (/click)
-- instead of the type=click action.
function addon:IsMacrotextDispatch()
    return self:GetDispatchMode() == "macrotext"
end

-- The raw (non-localized) WoW click-button token for a mouse button number, used
-- to build "/click <proxy> <button>" macrotext. These must be the English tokens
-- SecureActionButton_OnClick resolves, NOT the L[] display names in convertMap.
-- MiddleButton is button 3 (what a physical middle-click resolves to as type3).
function addon:GetMouseButtonName(number)
    number = tonumber(number)
    if number == 1 then
        return "LeftButton"
    elseif number == 2 then
        return "RightButton"
    elseif number == 3 then
        return "MiddleButton"
    else
        return "Button" .. tostring(number)
    end
end

-- Build a (possibly modified) secure attribute name from its parts, e.g.
-- "shift-type2" or "type1". prefix is the modifier prefix ("shift", ""), suffix the
-- button suffix ("2", ""). The separators mirror attributes.lua's snippet builders.
function addon:AttributeName(prefix, attr, suffix)
    local modSep = #prefix > 0 and "-" or ""
    local suffixSep = tonumber(suffix) and "" or "-"
    return prefix .. modSep .. attr .. suffixSep .. suffix
end

-- The modified attribute name a binding resolves to, e.g. "shift-type2" for
-- attribute "type" on SHIFT-BUTTON2.
function addon:AttributeFromEntry(binding, attribute, global)
    local prefix, suffix = self:GetBindingPrefixSuffix(binding, global)
    return self:AttributeName(prefix, attribute, suffix)
end

local buttonSortValues = {
    BUTTON1 = 1,
    BUTTON2 = 2,
    BUTTON3 = 3,
}

local compareFunctions
compareFunctions = {
    name = function(a, b)
        local texta = addon:GetBindingActionText(a.type, a)
        local textb = addon:GetBindingActionText(b.type, b)
        if texta == textb then
            return compareFunctions.key(a, b)
        end
        return texta < textb
    end,
    key = function(a, b)
        local keya = addon:GetBindingKey(a)
        local keyb = addon:GetBindingKey(b)
        if keya == keyb then
            return compareFunctions.binding(a, b)
        elseif not keya or not keyb then
            return false
        elseif buttonSortValues[keya] and not buttonSortValues[keyb] then
            -- Left value is a mouse button, prefer that
            return true
        elseif buttonSortValues[keyb] and not buttonSortValues[keya] then
            -- Right value is a mouse button, prefer that
            return false
        else
            return keya < keyb
        end
    end,
    binding = function(a, b)
        local comboa = addon:GetBindingKeyComboText(a)
        local combob = addon:GetBindingKeyComboText(b)
        if comboa == combob then
            local texta = addon:GetBindingActionText(a.type, a)
            local textb = addon:GetBindingActionText(b.type, b)
            if texta == textb then
                return tostring(a) < tostring(b)
            else
                return texta < textb
            end
        else
            return comboa < combob
        end
    end,
}


function addon:SortBindingsByKey(bindings)
    table.sort(bindings, compareFunctions.key)
end


function addon:SortBindingsByName(bindings)
    table.sort(bindings, compareFunctions.name)
end

-- Detects when Blizzard's in-game click-casting has Target or Open Context Menu
-- moved off Left/Right click, which collides with Clique's routing (retail only).
-- See B6 in BUGS.md.
local function buttonIsOneOf(button, ...)
    for i = 1, select("#", ...) do
        if button == select(i, ...) then
            return true
        end
    end
    return false
end

local function clickBindingsConflict()
    if not C_ClickBindings then
        return false
    end

    local info = C_ClickBindings.GetProfileInfo()
    if not info then
        return false
    end

    local Interaction = Enum.ClickBindingType.Interaction
    local Target = Enum.ClickBindingInteraction.Target
    local OpenContextMenu = Enum.ClickBindingInteraction.OpenContextMenu

    for _, entry in ipairs(info) do
        if entry.type == Interaction then
            if entry.actionID == Target and not buttonIsOneOf(entry.button, "LeftButton", "Button1") then
                return true
            elseif entry.actionID == OpenContextMenu and not buttonIsOneOf(entry.button, "RightButton", "Button2") then
                return true
            end
        end
    end

    return false
end

local function bindingUsesModifier(key, modifier)
    local mods = {}
    local parts = {strsplit("-", key)}
    for i = 1, #parts - 1 do
        mods[parts[i]:upper()] = true
    end
    for _, token in ipairs({strsplit("-", modifier)}) do
        if not mods[token] then
            return false
        end
    end
    return true
end

-- The Self Cast Key (Options > Combat) casts on the player while held, so any
-- binding sharing that modifier never runs its action.
local function conflictingSelfCastModifier(bindings)
    local modifier = GetModifiedClick("SELFCAST")
    if not modifier or modifier == "NONE" then
        return nil
    end
    modifier = modifier:upper()

    for _, binding in pairs(bindings) do
        if binding.key and bindingUsesModifier(binding.key, modifier) then
            return modifier
        end
    end
end

function addon:GetBlizzardClickCastWarning()
    if not clickBindingsConflict() then
        return nil
    end

    return {
        title = L["Non-default Blizzard Clickcast Settings Detected"],
        lines = {
            L["Since 12.0.7 Blizzard has made changes to the default UI that conflict with addons that overwrite actions on unit frames. For things to work properly, the in-game click-casting needs Target Unit Frame set to LeftButton and Open Context Menu set to RightButton."],
        },
        actionText = L["Click to open the in-game Click-Casting settings."],
        onClick = function()
            if ToggleClickBindingFrame then
                ToggleClickBindingFrame()
            end
        end,
    }
end

function addon:GetSelfCastWarning()
    local modifier = conflictingSelfCastModifier(self.bindings)
    if not modifier then
        return nil
    end

    return {
        title = L["Conflict with your 'self cast' key"],
        lines = {
            L["The 'self cast' key is enabled and set to %s, which is also used by one or more of your bindings. This conflict may cause those spells to be cast on you instead of your desired target."]:format(modifier),
            " ",
            L["Change the 'self cast' key under Options > Combat, or edit the binding to use a different modifier."],
        },
    }
end

-- Blizzard no longer provides Target/Show Menu as a fallback on unit frames, so
-- warn when neither action is bound in Clique.
function addon:GetMissingTargetMenuWarning()
    if self.settings.dismissTargetMenuWarning then
        return nil
    end

    local hasTarget, hasMenu = false, false
    for _, binding in pairs(self.bindings) do
        if binding.type == "target" then
            hasTarget = true
        elseif binding.type == "menu" then
            hasMenu = true
        end
    end

    if hasTarget and hasMenu then
        return nil
    end

    local title
    if not hasTarget and not hasMenu then
        title = L["Missing 'Target unit' and 'Show unit menu' bindings"]
    elseif not hasTarget then
        title = L["Missing 'Target unit' binding"]
    else
        title = L["Missing 'Show unit menu' binding"]
    end

    return {
        title = title,
        lines = {
            L["Clique now requires you to explicitly bind 'Target unit' and 'Show unit menu' actions, due to a change made by Blizzard that is breaking unit frames and click-casting addons."],
            " ",
            L["If you want to target or open the unit menu by clicking a frame, add a binding for those actions in Clique with the clicks or keypresses you prefer."],
        },
    }
end

-- Highest-priority active warning wins; nil when nothing needs attention.
function addon:GetActiveBindConfigWarning()
    if not self.bindings then
        return nil
    end

    return self:GetBlizzardClickCastWarning()
        or self:GetMissingTargetMenuWarning()
        or self:GetSelfCastWarning()
end

-- The click-cast profile has no change event, so hook its two mutation points to
-- refresh the warning. BrowsePage also recomputes it on every update.
function addon:SetupBindConfigWarningWatch()
    if not C_ClickBindings or self.bindConfigWarningWatchInstalled then
        return
    end
    self.bindConfigWarningWatchInstalled = true

    local function refresh()
        self:RefreshBindConfigWarning()
    end

    hooksecurefunc(C_ClickBindings, "SetProfileByInfo", refresh)
    hooksecurefunc(C_ClickBindings, "ResetCurrentProfile", refresh)
end

function addon:RefreshBindConfigWarning()
    if not CliqueUIBindingFrame then
        return
    end

    local config = self:GetBindingConfig()
    if config.BrowsePage and config:BrowsePageShown() then
        config:GetBrowsePage():UpdateBindConfigWarning()
    end
end
