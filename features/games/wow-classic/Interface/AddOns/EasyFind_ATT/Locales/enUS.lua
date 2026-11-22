local _, ns = ...

-- Every string the player sees. Other locales override keys in files of
-- their own; a missing key falls back to this one.
local L = setmetatable({}, { __index = function(_, k) return k end })
ns.L = L

L["EXT_NAME"] = "All The Things"
L["EXT_DESC"] = "Where things come from, whether you have them, and directions there."

L["FROM_FMT"] = "ATT: from %s"
L["COLLECTED"] = "Collected"
L["NOT_COLLECTED"] = "Not collected"
L["COMPLETED"] = "Completed"
L["NOT_COMPLETED"] = "Not completed"
L["SOURCES"] = "Sources"

L["QUESTS"] = "Quests"
L["QUEST"] = "Quest"
L["QUEST_FMT"] = "Quest: %s"
L["OPT_INFO_HEADER"] = "Show its info on"
L["OPT_QUESTS_HEADER"] = "Its quests"
L["KIND_QUESTS"] = "Quests"
L["KIND_MOUNTS"] = "Mounts"
L["KIND_PETS"] = "Pets"
L["KIND_TOYS"] = "Toys"
L["KIND_APPEARANCES"] = "Appearances"
L["KIND_HEIRLOOMS"] = "Heirlooms"
L["KIND_TITLES"] = "Titles"
L["KIND_ACHIEVEMENTS"] = "Achievements"
L["KIND_DECOR"] = "Decor"
L["KIND_RECIPES"] = "Recipes"
L["KIND_ITEMS"] = "Items"
L["OPT_HIDE_COMPLETED"] = "Hide completed"
L["OPT_NEAR_ME"] = "Near me"

L["HINT_DIRECTIONS"] = "Directions"
L["HINT_OPEN"] = "Open in All The Things"
L["MENU_OPEN"] = "Open in All The Things"
L["STEP_FMT"] = "Travel to %s"

L["NO_PLACE"] = "No known place for %s."
L["NOT_READY"] = "Can't read All The Things in this version, so nothing is added to EasyFind's results."
L["NEEDS_EASYFIND"] = "Needs a newer EasyFind: update EasyFind."
