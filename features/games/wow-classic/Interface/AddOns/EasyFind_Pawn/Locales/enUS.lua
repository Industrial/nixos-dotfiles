local _, ns = ...

-- Every string the player sees. Other locales override keys in files of
-- their own; a missing key falls back to this one.
local L = setmetatable({}, { __index = function(_, k) return k end })
ns.L = L

L["EXT_NAME"] = "Pawn"
L["EXT_DESC"] = "Any item's Pawn upgrade value in EasyFind, with its upgrades ranked by Pawn."

L["MARK_FMT"] = "+%d%% %s"
L["MARK_BIG_FMT"] = "Upgrade for %s"
L["REPLACES_FMT"] = "Replaces %s"
L["ALSO_FMT"] = "Also +%d%% for %s"
L["MENU_COMPARE"] = "Compare in Pawn"
L["MENU_PAWN"] = "Open Pawn"

L["NOT_READY"] = "Pawn's upgrade functions are not available in this version, so its verdicts are off."
L["NEED_EASYFIND"] = "This EasyFind has no loot data for extensions, so Pawn's verdicts are off."
