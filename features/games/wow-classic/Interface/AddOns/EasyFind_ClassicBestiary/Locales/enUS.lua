local _, ns = ...

-- Every string the player sees. Other locales override keys in files of
-- their own; a missing key falls back to this one.
local L = setmetatable({}, { __index = function(t, k) return k end })
ns.L = L

L["EXT_NAME"] = "Classic Bestiary"
L["EXT_DESC"] = "Classic Bestiary's creature abilities on EasyFind's results: hover a creature's row to see what it casts."

L["TT_HEADER"] = "Abilities, from Classic Bestiary"
L["TT_MORE_FMT"] = "and %d more"
L["TT_DETAILS_HINT_FMT"] = "Hold %s for details"
L["KEY_CTRL"] = "Ctrl"
L["KEY_SHIFT"] = "Shift"
L["KEY_ALT"] = "Alt"
L["SETTINGS_HINT"] = "What a creature casts, under its row's tooltip."
L["OPT_SHOW"] = "Abilities on creature rows"
L["OPT_LINES"] = "Lines listed"
L["OPT_LINES_ALL"] = "All"
L["NOT_READY_EASYFIND"] = "EasyFind needs an update before Classic Bestiary's abilities can show on its rows."
L["NOT_READY_BESTIARY"] = "This Classic Bestiary is not one the extension knows: update Classic Bestiary and EasyFind [Classic Bestiary]."
