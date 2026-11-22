local _, ns = ...
local L = ns.L




local SettingsRows = {}
ns.SettingsRows = SettingsRows

local sformat = string.format

local function DefaultTag(label)
    return label .. " (" .. (_G["DEFAULT"] or "Default") .. ")"
end

local function Soon(fn)
    ns.Utils.SafeAfter(0, fn)
end

local function Search(method)
    local search = ns.Search
    if search and search[method] then search[method](search) end
end


local function Changed()
    local options = ns.Options
    if options and options.SyncControls then options:SyncControls() end
end



SettingsRows.extensionPage = "menu"
SettingsRows.resultKind = nil

local INDICATOR_STYLES = { "EasyFind Arrow", "Chevrons", "Classic Quest Arrow", "Minimap Player Arrow",
    "Low-res Gauntlet", "HD Gauntlet" }
local STYLE_LABEL_KEY = {
    ["EasyFind Arrow"] = "OPT_INDICATOR_STYLE_EASYFIND", ["Chevrons"] = "OPT_INDICATOR_STYLE_CHEVRONS",
    ["Classic Quest Arrow"] = "OPT_INDICATOR_STYLE_CLASSIC", ["Minimap Player Arrow"] = "OPT_INDICATOR_STYLE_MINIMAP",
    ["Low-res Gauntlet"] = "OPT_INDICATOR_STYLE_LOWRES", ["HD Gauntlet"] = "OPT_INDICATOR_STYLE_HD",
}
local INDICATOR_COLORS = { "Yellow", "Gold", "Orange", "Red", "Green", "Blue", "Purple", "White" }
local COLOR_LABEL_KEY = {
    Yellow = "OPT_COLOR_YELLOW", Gold = "OPT_COLOR_GOLD", Orange = "OPT_COLOR_ORANGE", Red = "OPT_COLOR_RED",
    Green = "OPT_COLOR_GREEN", Blue = "OPT_COLOR_BLUE", Purple = "OPT_COLOR_PURPLE", White = "OPT_COLOR_WHITE",
}
SettingsRows.STYLE_LABEL_KEY = STYLE_LABEL_KEY
SettingsRows.COLOR_LABEL_KEY = COLOR_LABEL_KEY

function SettingsRows.IndicatorStyles()
    local list = {}
    for i = 1, #INDICATOR_STYLES do list[i] = INDICATOR_STYLES[i] end
    if ns.Caps and ns.Caps.classic then table.remove(list) end
    return list
end

local function StyleLabel(value)
    local key = value and STYLE_LABEL_KEY[value]
    return (key and L[key]) or value
end

local function ColorLabel(value)
    local key = value and COLOR_LABEL_KEY[value]
    return (key and L[key]) or value
end

local function FontLabel(name)
    if name == "Default" then return _G["DEFAULT"] or "Default" end
    return name
end


function SettingsRows.BorderChoices()
    local t = { { label = _G["OFF"] or "Off", value = "off" }, { label = L["GPS_BORDER_LINE"], value = "line" } }
    if ns.ThemeHasChrome() then t[#t + 1] = { label = L["GPS_BORDER_IRON"], value = "iron" } end
    return t
end

function SettingsRows.BorderValue()
    if EasyFind.db.windowBorder == false then return "off" end
    if ns.ThemeHasChrome() and EasyFind.db.themeFrameArt ~= false then return "iron" end
    return "line"
end

function SettingsRows.SetBorder(v)
    EasyFind.db.windowBorder = v ~= "off"
    if v ~= "off" then EasyFind.db.themeFrameArt = v == "iron" end
    Soon(function()
        Search("UpdateWindowBorders")
        Changed()
        if ns.RepaintWizardTheme then ns.RepaintWizardTheme() end
    end)
end

function SettingsRows.ClassicBgChoices()
    local choices = { { label = L["CLASSIC_BG_MARBLE"], value = "marble" } }
    local classNames = _G["LOCALIZED_CLASS_NAMES_MALE"] or {}
    for _, tree in ipairs(ns.CLASSIC_TREES or {}) do
        local class = tree:match("^%u%l+")
        choices[#choices + 1] = { label = (classNames[class:upper()] or class) .. ": " .. L["TREE_" .. tree], value = tree }
    end
    return choices
end





function SettingsRows.RedressClassic()
    local db = EasyFind.db
    local theme = db and db.uiTheme or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.uiTheme)
    if ns.ApplyUITheme and theme then ns.ApplyUITheme(theme) end
    Search("UpdateWindowBorders")
    if ns.RestyleCardFills then ns.RestyleCardFills() end
    if ns.RepaintWizardTheme then ns.RepaintWizardTheme() end
end

function SettingsRows.VisibilityLabel(value)
    if value == ns.VISIBILITY_SMART then return L["OPT_VISIBILITY_SMARTSHOW"] end
    if value == ns.VISIBILITY_ALWAYS then return L["OPT_VISIBILITY_ALWAYS"] end
    return L["OPT_VISIBILITY_AUTOHIDE"]
end


function SettingsRows.SetVisibility(value)
    ns.SetVisibilityMode(value)
    Soon(function()
        local search = ns.Search
        if not search then return end
        if value == ns.VISIBILITY_SMART then
            if search.Show then search:Show(false) end
            if search.UpdateSmartShow then search:UpdateSmartShow() end
        elseif value == ns.VISIBILITY_ALWAYS then
            if search.UpdateSmartShow then search:UpdateSmartShow() end
            if search.Show then search:Show(false) end
        else
            if search.UpdateSmartShow then search:UpdateSmartShow() end
            if search.Hide then search:Hide() end
        end
        if ns.Utils.RefreshEscArm then ns.Utils.RefreshEscArm() end
        Changed()
    end)
end

function SettingsRows.WowheadLabel(v)
    if v == "auto" then return L["WOWHEAD_LOCALE_AUTO"] end
    for _, entry in ipairs(ns.WOWHEAD_LOCALES) do
        if entry.value == v then return entry.label end
    end
    return v
end


function SettingsRows.ResultKind()
    local Gestures = ns.ResultGestures
    local key = SettingsRows.resultKind
    local kind = key and Gestures.Kind(key)
    return kind or Gestures.Kinds()[1]
end

function SettingsRows.ResultKindLabels()
    return {
        mount = _G["MOUNTS"] or "Mounts", pet = _G["PETS"] or "Pets", toy = _G["TOYS"] or _G["TOY_BOX"] or "Toys",
        heirloom = _G["HEIRLOOMS"] or "Heirlooms", outfit = L["FILTER_OUTFITS"], transmogSet = L["FILTER_APPEARANCE_SETS"],
        ability = _G["ABILITIES"] or "Abilities", macro = _G["MACROS"] or "Macros", bag = _G["BAGSLOT"] or "Bags",
        catalog = _G["ITEMS"] or "Items", loot = _G["LOOT"] or "Loot", title = _G["PAPERDOLL_SIDEBAR_TITLES"] or "Titles",
        instance = _G["DUNGEONS"] or "Dungeons",
        settingToggle = L["OPT_RESULT_KIND_TOGGLES"], settingPress = L["OPT_RESULT_KIND_BUTTONS"],
        quickKeybind = L["OPT_RESULT_KIND_KEYBINDS"],
    }
end

function SettingsRows.GestureLabel(gesture)
    if gesture == "click" then return L["HINT_CLICK"] end
    return ({ alt = "Alt", ctrl = "Ctrl", shift = "Shift" })[gesture] or gesture
end


function SettingsRows.ExtensionPages()
    local pages = {}
    local function Loadable(companion)
        return not (companion and ns.IsCompanionLoadable and not ns.IsCompanionLoadable(companion))
    end
    if ns.AppsMenu then pages[#pages + 1] = { id = "menu", name = L["OPT_EXT_MENU_PAGE"] } end
    if Loadable("EasyFind_Snippets") then pages[#pages + 1] = { id = "snippets", name = L["FILTER_SNIPPETS"] } end
    if Loadable("EasyFind_Quicklists") then pages[#pages + 1] = { id = "quicklists", name = L["FILTER_QUICKLISTS"] } end
    for _, def in ipairs(ns.ExtensionPages or {}) do
        if Loadable(def.companion) then pages[#pages + 1] = { id = def.id, name = def.name or def.id } end
    end
    return pages
end

local function Check(name, tooltip, get, set)
    return { name = name, control = { kind = "check", tooltip = tooltip, get = get, set = set } }
end

local function Choice(name, tooltip, choices, get, set)
    return { name = name, control = { kind = "choice", tooltip = tooltip, choices = choices, get = get, set = set } }
end

local function Slider(name, tooltip, min, max, step, get, set)
    return { name = name, control = { kind = "slider", tooltip = tooltip, min = min, max = max, step = step, get = get, set = set } }
end

local function Keybind(name, action)
    return { name = name, control = { kind = "keybind", action = action } }
end

local function Button(name, tooltip, press)
    return { name = name, control = { kind = "button", tooltip = tooltip, press = press } }
end



local function Action(name, tooltip, key)
    local row = Button(name, tooltip)
    row.action = key
    return row
end

local function Confirm(text, onAccept, acceptText)
    ns.ShowThemedDialog({ text = text, acceptText = acceptText or _G["RESET"] or "Reset", onAccept = onAccept })
end


local function WithOptions(fn)
    return function()
        if ns.RequestOptionsPanel and ns.RequestOptionsPanel() and ns.Options then fn(ns.Options) end
    end
end


local function MapPopups()
    if StaticPopupDialogs["EASYFIND_DISABLE_MAP_SEARCH"] then return end
    local function Lift(self)
        self:SetFrameStrata("TOOLTIP")
        self:SetFrameLevel(1000)
    end
    StaticPopupDialogs["EASYFIND_DISABLE_MAP_SEARCH"] = {
        text = L["POPUP_DISABLE_MAP_SEARCH"] .. "\n\n" .. L["POPUP_DISABLE_MAP_SEARCH_DETAIL"],
        button1 = _G["DISABLE"] or "Disable", button2 = _G["CANCEL"] or "Cancel",
        OnAccept = function()
            EasyFind.db.enableMapSearch = false
            Changed()
            if ns.MapSearch then
                pcall(ns.MapSearch.ClearAll, ns.MapSearch)
                pcall(ns.MapSearch.ClearZoneHighlight, ns.MapSearch)
            end
            StaticPopup_Show("EASYFIND_RELOAD_PROMPT")
        end,
        OnShow = Lift, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs["EASYFIND_RELOAD_PROMPT"] = {
        text = L["POPUP_RELOAD_UI"],
        button1 = _G["RELOADUI"] or "Reload Now", button2 = L["POPUP_BTN_LATER"],
        OnAccept = function() ReloadUI() end,
        OnShow = Lift, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
end

function SettingsRows.ShowReloadPrompt()
    MapPopups()
    StaticPopup_Show("EASYFIND_RELOAD_PROMPT")
end

function SettingsRows.SetMapEnabled(on)
    MapPopups()
    if on then
        EasyFind.db.enableMapSearch = true
        Changed()
        StaticPopup_Show("EASYFIND_RELOAD_PROMPT")
    else
        StaticPopup_Show("EASYFIND_DISABLE_MAP_SEARCH")
    end
end


SettingsRows.PROFILE_SECTION_LABEL_KEY = {
    settings = "PROFILE_SECTION_SETTINGS", aliases = "PROFILE_SECTION_ALIASES",
    shortkeys = "PROFILE_SECTION_SHORTKEYS", blacklist = "PROFILE_SECTION_BLACKLIST",
    snippets = "PROFILE_SECTION_SNIPPETS", extbuttons = "PROFILE_SECTION_EXTBUTTONS",
    pins = "PROFILE_SECTION_PINS", learned = "PROFILE_SECTION_LEARNED",
    keybinds = "PROFILE_SECTION_KEYBINDS", quicklists = "PROFILE_SECTION_QUICKLISTS",
}


local function Under(heading, name)
    return sformat("%s: %s", (heading:gsub(":%s*$", "")), name)
end
SettingsRows.Under = Under

local function Labeled(values, labelFn)
    local list = {}
    for i, v in ipairs(values) do list[i] = { value = v, label = labelFn(v) } end
    return list
end


local function WithSync(rows)
    for _, row in ipairs(rows) do
        local control = row.control
        local set = control.set
        if set then
            control.set = function(...)
                set(...)
                Changed()
            end
        end
    end
    return rows
end

local function GeneralRows()
    local db = EasyFind.db
    local defaultTheme = (ns.DB_DEFAULTS and ns.DB_DEFAULTS.uiTheme) or "Midnight"
    local defaultStyle = (ns.DB_DEFAULTS and ns.DB_DEFAULTS.indicatorStyle) or "EasyFind Arrow"
    local defaultColor = (ns.DB_DEFAULTS and ns.DB_DEFAULTS.indicatorColor) or "Yellow"
    local rows = {
        Check(L["OPT_UPDATE_NOTIFY"], L["OPT_UPDATE_NOTIFY_TT"],
            function() return db.updateNotify ~= false end,
            function(on)
                db.updateNotify = on and true or false
                if ns.VersionCheck then ns.VersionCheck:RefreshSurfaces() end
            end),
        Check(L["OPT_SHOW_MINIMAP_BUTTON"], L["OPT_MINIMAP_BTN_TT"],
            function() return db.showMinimapButton ~= false end,
            function(on)
                db.showMinimapButton = on and true or false
                EasyFind:UpdateMinimapButton()
            end),
        Check(L["OPT_HIDE_EXT_TIPS"], nil,
            function() return db.hideExtensionTips == true end,
            function(on)
                db.hideExtensionTips = on or nil
                if ns.MapTab and ns.MapTab.RefreshExtensionTip then ns.MapTab.RefreshExtensionTip() end
            end),
        Choice(L["OPT_UI_THEME"], nil,
            Labeled(ns.UI_THEME_ORDER or { "Midnight" }, function(name)
                return name == defaultTheme and DefaultTag(name) or name
            end),
            function() return db.uiTheme or defaultTheme end,
            function(name)
                db.uiTheme = name
                if ns.ApplyUITheme then ns.ApplyUITheme(name) end
                if ns.RepaintWizardTheme then pcall(ns.RepaintWizardTheme) end
            end),
        Choice(L["OPT_CLASSIC_BG"], L["OPT_CLASSIC_BG_TT"], SettingsRows.ClassicBgChoices(),
            function() return db.classicArt or "marble" end,
            function(value)
                db.classicArt = value ~= "marble" and value or nil
                SettingsRows.RedressClassic()
            end),
        Choice(L["OPT_INDICATOR_STYLE"], nil,
            Labeled(SettingsRows.IndicatorStyles(), function(name)
                local label = StyleLabel(name)
                return name == defaultStyle and DefaultTag(label) or label
            end),
            function() return db.indicatorStyle or "EasyFind Arrow" end,
            function(name)
                db.indicatorStyle = name
                if ns.MapSearch then ns.MapSearch:RefreshIndicators() end
            end),
        Choice(L["OPT_INDICATOR_COLOR"], nil, Labeled(INDICATOR_COLORS, ColorLabel),
            function() return db.indicatorColor or defaultColor end,
            function(name)
                db.indicatorColor = name
                if ns.MapSearch then ns.MapSearch:RefreshIndicators() end
            end),
        Choice(L["OPT_FONT"], nil, Labeled(ns.FONT_CHOICES, FontLabel),
            function() return db.font or "Default" end,
            function(name)
                db.font = name
                if ns.RefreshAddonFont then ns.RefreshAddonFont() end
                Search("UpdateFontSize")
                Search("RefreshResults")
            end),
        Keybind(L["OPT_KEYBIND_TOGGLE_SEARCH"], "EASYFIND_TOGGLE_FOCUS"),
        Keybind(L["OPT_KEYBIND_FOCUS_BAR"], "EASYFIND_FOCUS_BAR"),
        Keybind(L["OPT_KEYBIND_OPEN_MAP_TAB"], "EASYFIND_MAP_FOCUS"),
        Keybind(L["OPT_KEYBIND_CLEAR_ALL"], "EASYFIND_CLEAR"),
        Button(L["OPT_RESET_ALL_SETTINGS"], L["OPT_RESET_ALL_TT_DESC"],
            WithOptions(function(options) options:ConfirmResetAll() end)),
        Button(L["OPT_RESET_ALL_POSITIONS"], L["OPT_RESET_POS_TT_DESC"], function()
            Confirm(L["POPUP_RESET_ALL_POSITIONS"], WithOptions(function(options) options:DoResetPositions() end))
        end),
    }
    return rows
end

local function SearchRows()
    local db = EasyFind.db
    local fontSizes = {
        { label = L["OPT_FONT_SMALL"], value = 0.80 }, { label = L["OPT_FONT_MED"], value = 0.90 },
        { label = L["OPT_FONT_LARGE"], value = 1.15 }, { label = L["OPT_FONT_XL"], value = 1.35 },
    }
    local scales = {
        { label = "50%", value = 0.5 }, { label = "75%", value = 0.75 }, { label = "100%", value = 1.0 },
        { label = "125%", value = 1.25 }, { label = "150%", value = 1.5 },
    }
    local resultRows = {}
    for i = ns.RESULT_ROWS_MIN, ns.RESULT_ROWS_MAX do resultRows[#resultRows + 1] = { label = tostring(i), value = i } end
    local wowhead = {}
    for _, entry in ipairs(ns.WOWHEAD_LOCALES) do
        local label = SettingsRows.WowheadLabel(entry.value)
        wowhead[#wowhead + 1] = { value = entry.value, label = entry.value == "auto" and DefaultTag(label) or label }
    end


    local function CombatLine(name, tooltip, get, set, needsShown)
        return Check(name, tooltip, get, function(on)
            if needsShown and db.combatHide ~= false and ns.GetVisibilityMode() == ns.VISIBILITY_ALWAYS then return end
            set(on)
            SettingsRows.SetVisibility(ns.VISIBILITY_ALWAYS)
        end)
    end
    local function Toggle(name, tooltip, key, after, onByDefault)
        return Check(name, tooltip,
            function()
                if onByDefault then return db[key] ~= false end
                return db[key] == true
            end,
            function(on)
                db[key] = on and true or false
                if after then after(on) end
            end)
    end
    local function RevealBarControls() Soon(function() Search("RefreshBarControlReveal") end) end
    local rows = {
        Choice(L["OPT_VISIBILITY"], nil,
            Labeled({ ns.VISIBILITY_AUTO, ns.VISIBILITY_SMART, ns.VISIBILITY_ALWAYS }, function(value)
                local label = SettingsRows.VisibilityLabel(value)
                return value == ns.VISIBILITY_AUTO and DefaultTag(label) or label
            end),
            function() return ns.GetVisibilityMode() end, SettingsRows.SetVisibility),
        CombatLine(Under(L["OPT_VISIBILITY_ALWAYS"], L["OPT_COMBAT_HIDE_SHORT"]), L["OPT_COMBAT_HIDE_TT"],
            function() return db.combatHide ~= false end,
            function(on) db.combatHide = on and true or false end),
        CombatLine(Under(L["OPT_VISIBILITY_ALWAYS"], L["OPT_COMBAT_DIM"]), L["OPT_COMBAT_DIM_TT"],
            function() return db.combatDim == true end,
            function(on) db.combatDim = on and true or false end, true),
        CombatLine(Under(L["OPT_VISIBILITY_ALWAYS"], L["OPT_MOVE_DIM"]), L["OPT_MOVE_DIM_TT"],
            function() return db.moveDim == true end,
            function(on)
                db.moveDim = on and true or false
                Search("UpdateMoveDim")
            end),
        Toggle(L["OPT_LOCK_POSITION"], L["OPT_LOCK_POSITION_TT"], "lockPosition"),
        Toggle(L["OPT_SHOW_ALT_HINTS"], L["OPT_ALT_HINTS_TT"], "showResultShortcutHints", function()
            Soon(function()
                Search("RefreshResults")
                local shortcuts = ns.ResultShortcuts
                if shortcuts and shortcuts.UpdateVisibleResultShortcuts then shortcuts:UpdateVisibleResultShortcuts() end
            end)
        end, true),
        Toggle(L["OPT_INLINE_AUTOCOMPLETE"], L["OPT_INLINE_AUTOCOMPLETE_TT"], "searchAutocomplete", function(on)
            if on then return end
            local frame = ns.Search and ns.Search.GetSearchFrame and ns.Search:GetSearchFrame()
            local box = frame and frame.editBox
            if box and box.StripAutocomplete then box:StripAutocomplete() end
        end, true),
        Toggle(L["OPT_SHOW_APPS_BUTTON"], L["OPT_SHOW_APPS_BUTTON_TT"], "showAppsButton", RevealBarControls, true),
        Toggle(L["OPT_SHOW_FILTER_BUTTON"], L["OPT_SHOW_FILTER_BUTTON_TT"], "showFilterButton", RevealBarControls, true),
        Toggle(L["OPT_LEARN_PICKS"], L["OPT_LEARN_PICKS_TT"], "learnFromPicks", nil, true),
    }
    if ns.Caps and ns.Caps.iconSearch then
        rows[#rows + 1] = Toggle(L["OPT_MACRO_PICKER_SEARCH"], L["OPT_MACRO_PICKER_SEARCH_TT"], "macroPickerSearch", function()
            if not ns.IconPickerSearch and db.macroPickerSearch and ns.RequestIconSearch then ns.RequestIconSearch() end
            if ns.IconPickerSearch and ns.IconPickerSearch.Refresh then ns.IconPickerSearch:Refresh() end
        end, true)
    end
    rows[#rows + 1] = Toggle(L["OPT_CLICK_SELECTS"], L["OPT_CLICK_SELECTS_TT"], "clickSelectsRow")
    for _, row in ipairs({
        Choice(L["OPT_RESULTS_DIRECTION"], nil, {
                { label = L["OPT_RESULTS_BELOW"], value = 0, tooltip = L["OPT_RESULTS_BELOW_TT"] },
                { label = L["OPT_RESULTS_ABOVE"], value = 1, tooltip = L["OPT_RESULTS_ABOVE_TT"] },
            },
            function() return db.uiResultsAbove and 1 or 0 end,
            function(value)
                db.uiResultsAbove = value == 1
                Soon(function() Search("RefreshResults") end)
            end),
        Choice(L["GPS_SIZE_BORDER"], L["OPT_WINDOW_BORDER_TT"], SettingsRows.BorderChoices(),
            SettingsRows.BorderValue, SettingsRows.SetBorder),
        Choice(L["OPT_ICON_VISIBILITY"], nil, {
                { label = L["OPT_ICONS_ALL"], value = "all" }, { label = L["OPT_ICONS_GENERAL"], value = "general" },
                { label = L["OPT_ICONS_SPECIFIC"], value = "specific" },
            },
            function() return db.iconVisibility or "all" end,
            function(value)
                db.iconVisibility = value
                Search("RefreshResults")
            end),
        Choice(L["OPT_FONT_SIZE"], L["OPT_FONT_SIZE_TT"], fontSizes,
            function() return db.fontSize or ns.DEFAULT_FONT_SIZE end,
            function(value)
                db.fontSize = value
                Search("UpdateFontSize")
            end),
        Choice(L["OPT_SEARCH_SCALE"], L["OPT_SEARCH_SCALE_TT"], scales,
            function() return db.uiSearchScale or 1.0 end,
            function(value)
                db.uiSearchScale = value
                db.uiResultsScale = 1.0
                Search("UpdateScale")
            end),
        Choice(L["OPT_RESULT_ROWS"], L["OPT_RESULT_ROWS_TT"], resultRows,
            function() return db.uiResultsRows or 6 end,
            function(value)
                db.uiResultsRows = value
                Soon(function() Search("RefreshResults") end)
            end),
        Slider(L["OPT_SEARCH_OPACITY"], L["OPT_SEARCH_OPACITY_TT"], 50, 100, 1,
            function() return math.floor((db.searchWindowOpacity or ns.SEARCH_WINDOW_ALPHA) * 100 + 0.5) end,
            function(value)
                db.searchWindowOpacity = value / 100
                Soon(function() Search("UpdateOpacity") end)
            end),
        Choice(L["OPT_WOWHEAD_LOCALE"], nil, wowhead,
            function() return db.wowheadLocale or "auto" end,
            function(value) db.wowheadLocale = value end),
        Button(L["OPT_RESIZE_UI_SEARCH"], L["OPT_RESIZE_UI_TT"], function()
            if ns.Rescaler then ns.Rescaler:Enter("ui") end
        end),
        Button(L["OPT_RESET_SETTINGS"], nil, function()
            Confirm(L["POPUP_RESET_UI_SEARCH_SETTINGS"], WithOptions(function(options) options:DoResetUI() end))
        end),
        Button(L["OPT_RESET_POSITIONS"], nil, function()
            Confirm(L["POPUP_RESET_UI_SEARCH_POSITIONS"], WithOptions(function(options) options:DoResetUIPositions() end))
        end),
        Button(L["OPT_FORGET_LEARNED"], L["OPT_FORGET_LEARNED_TT"], function()
            ns.ShowThemedDialog({
                text = L["POPUP_FORGET_LEARNED"], messageColor = ns.GOLD_COLOR, acceptText = _G["DELETE"] or "Delete",
                onAccept = function() if ns.Learned then ns.Learned:ClearAll() end end,
            })
        end),
    }) do rows[#rows + 1] = row end
    return rows
end

local function MapRows()
    local db = EasyFind.db
    local function Refresh(method)
        return function() Soon(function() if ns.MapSearch and ns.MapSearch[method] then ns.MapSearch[method](ns.MapSearch) end end) end
    end
    local rows = {
        Check(L["OPT_ENABLE_MAP_MODULE"], L["OPT_ENABLE_MAP_TT"],
            function() return db.enableMapSearch ~= false end, SettingsRows.SetMapEnabled),
        Check(L["OPT_SHOW_RECENT_SEARCHES"], L["OPT_SHOW_RECENT_TT"],
            function() return db.mapTabShowRecent ~= false end,
            function(on)
                db.mapTabShowRecent = on and true or false
                Soon(function() if ns.MapTab and ns.MapTab.RefreshIfOpen then ns.MapTab:RefreshIfOpen() end end)
            end),
        Check(L["MAP_SHOW_PARENTS"], L["MAP_SHOW_PARENTS_TT"],
            function() return db.mapTabShowParents ~= false end,
            function(on)
                db.mapTabShowParents = on and true or false
                Soon(function() if ns.MapTab and ns.MapTab.RefreshIfOpen then ns.MapTab:RefreshIfOpen() end end)
            end),
        Check(L["OPT_INLINE_AUTOCOMPLETE"], L["OPT_INLINE_AUTOCOMPLETE_TT"],
            function() return db.mapTabAutocomplete ~= false end,
            function(on)
                db.mapTabAutocomplete = on and true or false
                local box = ns.MapTab and ns.MapTab.searchBox
                if not on and box and box.StripAutocomplete then box:StripAutocomplete() end
            end),
        Check(L["OPT_BLINKING"], L["OPT_BLINKING_TT"],
            function() return db.blinkingPins == true end,
            function(on)
                db.blinkingPins = on and true or false
                Refresh("UpdateBlinkingPins")()
            end),
        Check(L["OPT_AUTO_TRACK_RARES"], L["OPT_AUTO_TRACK_RARES_TT"],
            function() return db.alwaysShowRares == true end,
            function(on)
                db.alwaysShowRares = on and true or false
                Soon(function()
                    local map = ns.MapSearch
                    if not map then return end
                    map:UpdateRareTracking()
                    if map.UpdateAutoTrackLabel then map:UpdateAutoTrackLabel() end
                end)
            end),
        Check(L["OPT_AUTO_TRACK_MAP_PINS"], L["OPT_AUTO_TRACK_PINS_TT"],
            function() return db.autoTrackPins ~= false end,
            function(on) db.autoTrackPins = on and true or false end),
        Check(L["OPT_AUTO_CLEAR_MAP_PINS"], L["OPT_AUTO_PIN_CLEAR_TT"],
            function() return db.autoPinClear ~= false end,
            function(on) db.autoPinClear = on and true or false end),
        Button(L["OPT_RESET_SETTINGS"], nil, function()
            Confirm(L["POPUP_RESET_MAP_SEARCH_SETTINGS"], WithOptions(function(options) options:DoResetMap() end))
        end),
        Slider(L["OPT_RECENT_COUNT"], L["OPT_RECENT_COUNT_TT"], 1, 10, 1,
            function() return db.mapTabRecentCount or 3 end,
            function(value)
                db.mapTabRecentCount = value
                local list = db.mapTabRecentSearches
                if list then
                    while #list > value do table.remove(list) end
                end
                if ns.MapTab and ns.MapTab.RefreshIfOpen then ns.MapTab:RefreshIfOpen() end
            end),
        Choice(L["OPT_PIN_HIGHLIGHT"], L["OPT_PIN_HIGHLIGHT_TT"], {
                { label = L["OPT_PIN_GLOW"], value = "glow" }, { label = L["OPT_PIN_BOX"], value = "box" },
                { label = _G["NONE"] or "None", value = "off" },
            },
            function() return db.mapPinStyle or "glow" end,
            function(value)
                db.mapPinStyle = value
                if ns.MapSearch and ns.MapSearch.UpdatePinHighlight then ns.MapSearch:UpdatePinHighlight() end
            end),
        Choice(L["OPT_ICON_SIZE"], L["OPT_ICON_SIZE_TT"], {
                { label = L["OPT_FONT_SMALL"], value = 0.65 }, { label = L["OPT_FONT_MED"], value = 0.80 },
                { label = L["OPT_FONT_LARGE"], value = 1.05 }, { label = L["OPT_FONT_XL"], value = 1.30 },
            },
            function() return db.iconScale or 0.8 end,
            function(value)
                db.iconScale = value
                if ns.MapSearch and ns.MapSearch.UpdateIconScales then ns.MapSearch:UpdateIconScales() end
                local indicator = _G["EasyFindIndicatorFrame"]
                if indicator then indicator:SetScale(db.iconScale or 0.8) end
            end),
    }

    if not (ns.MapSearch and ns.MapSearch.HasGameWaypoint == false) then
        for i, row in ipairs(rows) do
            if row.name == L["OPT_AUTO_CLEAR_MAP_PINS"] then
                table.insert(rows, i + 1, Check(L["OPT_MAP_WAYPOINT_ONLY"], L["OPT_MAP_WAYPOINT_ONLY_TT"],
                    function() return db.mapWaypointOnly == true end,
                    function(on) db.mapWaypointOnly = on or nil end))
                break
            end
        end
    end
    return rows
end


local function ListTools(prefix)
    return {
        Action(L["OPT_CLEAR_ALL_BTN"], nil, prefix .. "Clear"),
        Action(L["SHORTKEY_EXPORT"], nil, prefix .. "Export"),
        Action(L["SHORTKEY_IMPORT"], nil, prefix .. "Import"),
    }
end

local function ExtensionsRows()
    local rows = {}
    local pages = SettingsRows.ExtensionPages()
    if #pages > 0 then
        local choices = {}
        for i, page in ipairs(pages) do choices[i] = { value = page.id, label = page.name } end
        rows[#rows + 1] = Choice(L["FILTER_EXTENSIONS"], nil, choices,
            function() return SettingsRows.extensionPage end,
            function(id)
                SettingsRows.extensionPage = id
                local options = ns.Options
                if options and options.SelectExtensionPage then options:SelectExtensionPage(id) end
            end)
    end
    local AppsMenu = ns.AppsMenu
    if AppsMenu then
        local function S() return AppsMenu.Settings() end
        local function Rebuilt() if AppsMenu.Rebuild then AppsMenu:Rebuild() end end
        local rowsPer, labels, sizes, iconSizes = {}, {}, {}, {}
        for i, n in ipairs(AppsMenu.ROWS_CHOICES) do rowsPer[i] = { label = tostring(n), value = n } end
        for _, pos in ipairs(AppsMenu.LABEL_POSITIONS) do
            labels[#labels + 1] = { label = L["OPT_EXT_LABEL_" .. pos:upper()], value = pos }
        end
        for _, size in ipairs(AppsMenu.LABEL_SIZES) do sizes[#sizes + 1] = { label = L[size[1]], value = size[2] } end
        for _, size in ipairs(AppsMenu.ICON_SIZES) do iconSizes[#iconSizes + 1] = { label = L[size[1]], value = size[2] } end
        for _, row in ipairs({
            Choice(L["OPT_EXT_ROWS"], nil, rowsPer, function() return S().rows end,
                function(v) S().rows = v Rebuilt() end),
            Choice(L["OPT_EXT_LABELS"], nil, labels, function() return S().labels end,
                function(v) S().labels = v Rebuilt() end),
            Choice(L["OPT_EXT_LABEL_SIZE"], nil, sizes, function() return S().labelSize end,
                function(v) S().labelSize = v Rebuilt() end),
            Choice(L["OPT_EXT_ICON_SIZE"], nil, iconSizes, function() return S().iconSize end,
                function(v) S().iconSize = v Rebuilt() end),
            Button(L["OPT_EXT_SORT_NAME"], L["OPT_EXT_SORT_NAME_TT"], function()
                S().order = nil
                Rebuilt()
            end),
        }) do
            row.page = { id = "menu", name = L["OPT_EXT_MENU_PAGE"] }
            rows[#rows + 1] = row
        end

        local apps = ns.BuildApplicationEntries and ns.BuildApplicationEntries() or {}
        table.sort(apps, function(a, b) return (a.name or "") < (b.name or "") end)
        for _, app in ipairs(apps) do
            local id = ns.ApplicationEntryID and ns.ApplicationEntryID(app)
            if id and AppsMenu.IsHidden then
                local row = Check(sformat(L["OPT_EXT_SHOW_FMT"], app.name or id), L["OPT_EXT_SHOWN_HINT"],
                    function() return not AppsMenu:IsHidden(id) end,
                    function(on) AppsMenu:SetHidden(id, not on) end)
                row.page = { id = "menu", name = L["OPT_EXT_MENU_PAGE"] }
                rows[#rows + 1] = row
            end
        end
    end
    if not (ns.IsCompanionLoadable and not ns.IsCompanionLoadable("EasyFind_Snippets")) then
        local trigger = ns.Snippets and ns.Snippets.TriggerChar and ns.Snippets.TriggerChar() or "\\"
        local row = Check(sformat(L["SNIPPET_EXPAND_IN_CHAT"], trigger), sformat(L["SNIPPET_KEYWORD_HINT"], trigger),
            function() return EasyFind.db.snippetChatExpansion ~= false end,
            function(on) EasyFind.db.snippetChatExpansion = on and true or false end)
        local page = { id = "snippets", name = L["FILTER_SNIPPETS"] }
        row.page = page
        rows[#rows + 1] = row
        local tools = ListTools("snippets")
        table.insert(tools, 1, Action(L["SNIPPET_CREATE"], nil, "snippetsCreate"))
        for _, tool in ipairs(tools) do
            tool.page = page
            rows[#rows + 1] = tool
        end
    end
    if not (ns.IsCompanionLoadable and not ns.IsCompanionLoadable("EasyFind_Quicklists")) then
        local page = { id = "quicklists", name = L["FILTER_QUICKLISTS"] }
        local tools = ListTools("quicklists")
        table.insert(tools, 1, Action(L["QUICKLIST_NEW"], nil, "quicklistsNew"))
        for _, tool in ipairs(tools) do
            tool.page = page
            rows[#rows + 1] = tool
        end
    end
    return rows
end

local function ResultClickRows()
    local Gestures = ns.ResultGestures
    local kindLabels = SettingsRows.ResultKindLabels()
    local kindChoices = {}
    for i, kind in ipairs(Gestures.Kinds()) do kindChoices[i] = { value = kind.key, label = kindLabels[kind.key] } end
    local rows = {
        Choice(L["OPT_RESULT_KIND"], nil, kindChoices,
            function() return SettingsRows.ResultKind().key end,
            function(v)
                SettingsRows.resultKind = v
                local options = ns.Options
                if options and options.ShowResultKind then options:ShowResultKind(v) end
            end),
    }
    local kind = SettingsRows.ResultKind()
    for _, gesture in ipairs(Gestures.GESTURES) do
        rows[#rows + 1] = Choice(SettingsRows.GestureLabel(gesture), nil, Gestures.Choices(kind),
            function() return Gestures.Get(SettingsRows.ResultKind().key, gesture) end,
            function(v) Gestures.Set(SettingsRows.ResultKind().key, gesture, v) end)
    end
    rows[#rows + 1] = Button(L["OPT_RESET_SETTINGS"], nil, function()
        Gestures.Reset()
        local options = ns.Options
        if options and options.ShowResultKind then options:ShowResultKind(SettingsRows.ResultKind().key) end
    end)
    return rows
end

local function FeedbackRows()
    return {
        Button(L["OPT_REPORT_BUG"], L["OPT_REPORT_BUG_TT_DESC"], function() EasyFind:OpenBugReport() end),
        Button(L["OPT_REQUEST_FEATURE"], L["OPT_REQUEST_FEATURE_TT_DESC"], function() EasyFind:OpenFeatureRequest() end),
    }
end

local function ProfileRows()
    local Profiles = ns.Profiles
    if not Profiles then return {} end
    local function Refresh()
        local options = ns.Options
        if options and options.RefreshProfilesTab then options:RefreshProfilesTab() end
    end
    local function Named(names)
        local list = {}
        for _, name in ipairs(names) do list[#list + 1] = { value = name, label = Profiles:DisplayName(name) } end
        return list
    end
    local picks = {}
    for _, name in ipairs(Profiles:Names()) do picks[#picks + 1] = name end
    for _, name in ipairs(Profiles:Suggestions()) do picks[#picks + 1] = name end
    local rows = {
        Choice(L["PROFILE_CURRENT"], L["PROFILE_CURRENT_TT"], Named(picks),
            function() return Profiles:Active() end, function(name) Profiles:Pick(name) end),
        Action(L["PROFILE_NEW"], nil, "profileNew"),
        Action(L["PROFILE_RENAME"], nil, "profileRename"),
        Button(L["PROFILE_RESET"], nil, function()
            ns.ShowThemedDialog({
                text = (L["PROFILE_RESET_CONFIRM_FMT"]):format(Profiles:DisplayName(Profiles:Active())),
                messageColor = ns.GOLD_COLOR, acceptText = _G["RESET"] or L["PROFILE_RESET"],
                onAccept = function() Profiles:ResetActive() end, cancelText = _G["CANCEL"] or "Cancel",
            })
        end),
        Action(L["PROFILE_COPY_FROM"], nil, "profileCopyFrom"),
        Action(L["PROFILE_DELETE"], nil, "profileDelete"),
        Check(L["PROFILE_SPEC_ENABLE"], L["PROFILE_SPEC_ENABLE_TT"],
            function() return Profiles:SpecProfilesEnabled() and true or false end,
            function(on) Profiles:SetSpecProfilesEnabled(on and true or false) end),
    }
    for _, spec in ipairs(Profiles:ClassSpecs()) do
        rows[#rows + 1] = Choice(Under(L["PROFILE_SPEC_TITLE"], spec.name), nil, Named(Profiles:Names()),
            function() return Profiles:SpecProfile(spec.id) end,
            function(name)
                Profiles:SetSpecProfile(spec.id, name)
                Refresh()
            end)
    end
    for _, sec in ipairs(Profiles.SECTIONS) do
        local key = SettingsRows.PROFILE_SECTION_LABEL_KEY[sec.id] or "PROFILE_SECTION_SETTINGS"
        rows[#rows + 1] = Check(Under(L["PROFILE_EXPORT_INCLUDE"], L[key]), nil,
            function() return Profiles:ExportIncluded(sec.id) and true or false end,
            function(on)
                Profiles:SetExportIncluded(sec.id, on)
                Refresh()
            end)
    end
    rows[#rows + 1] = Action(L["PROFILE_EXPORT"], L["PROFILE_EXPORT_TT"], "profileExport")
    rows[#rows + 1] = Action(L["PROFILE_IMPORT"], nil, "profileImport")
    return rows
end



local extensionRows = {}
function SettingsRows.AddExtension(id, name, rowsFn)
    local known
    for _, ext in ipairs(extensionRows) do
        if ext.id == id then
            ext.name, ext.rows, known = name, rowsFn, true
        end
    end
    if not known then extensionRows[#extensionRows + 1] = { id = id, name = name, rows = rowsFn } end
    if EasyFind.API and EasyFind.API.RefreshSettingsIndex then EasyFind.API.RefreshSettingsIndex("EasyFind") end
end


local function Opener(tab, pageID, name)
    return function()
        if not (ns.RequestOptionsPanel and ns.RequestOptionsPanel() and ns.Options) then return end
        ns.Options:OpenAtSetting(tab, pageID, name)
    end
end

local function AddTab(out, tab, rows)
    for _, row in ipairs(WithSync(rows)) do
        local page = row.page
        local pageID = page and page.id
        row.page = nil
        row.path = page and { tab, page.name } or { tab }
        row.open = Opener(tab, pageID, row.name)
        if row.action then
            local key = row.action
            row.action = nil
            row.control.actionKey = key
            row.control.press = function()
                if not (ns.RequestOptionsPanel and ns.RequestOptionsPanel() and ns.Options) then return end
                ns.Options:RunAction(key, tab, pageID)
            end
        end
        out[#out + 1] = row
    end
end


function SettingsRows.Rows()
    if not (EasyFind and EasyFind.db) then return nil end
    local out = {}
    AddTab(out, L["OPT_TAB_GENERAL_BINDS"], GeneralRows())
    AddTab(out, L["OPT_TAB_SEARCH"], SearchRows())
    AddTab(out, L["OPT_TAB_MAP"], MapRows())
    AddTab(out, L["OPT_TAB_ALIASES"], ListTools("aliases"))
    AddTab(out, L["OPT_TAB_BLACKLIST"], ListTools("blacklist"))
    local extTab = L["FILTER_EXTENSIONS"]
    AddTab(out, extTab, ExtensionsRows())
    for _, ext in ipairs(extensionRows) do
        local ok, rows = xpcall(ext.rows, ns.Utils.ErrorHandler)
        if ok and type(rows) == "table" then
            for _, row in ipairs(rows) do row.page = { id = ext.id, name = ext.name } end
            AddTab(out, extTab, rows)
        end
    end
    AddTab(out, L["OPT_TAB_RESULT_CLICKS"], ResultClickRows())
    AddTab(out, L["OPT_TAB_FEEDBACK"], FeedbackRows())
    AddTab(out, L["OPT_TAB_PROFILES"], ProfileRows())
    return out
end
