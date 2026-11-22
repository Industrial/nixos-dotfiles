local _, ns = ...

-- Every string the player sees. Other locales override keys in files of
-- their own; a missing key falls back to this one.
local L = setmetatable({}, { __index = function(t, k) return k end })
ns.L = L

L["EXT_NAME"] = "Spoken"
L["EXT_DESC"] = "Hear Spoken's lines from EasyFind's results: right-click a quest, place, dungeon, boss or letter."

L["MENU_PLAY"] = "Play in Spoken"
L["MENU_STOP"] = "Stop Spoken"
L["MENU_OPEN"] = "Open in Compendium"
L["STOP_ALL"] = "Stop all Spoken narration"
L["MENU_UNLOCK_QUEST"] = "Unlock unstarted quests"
L["MENU_UNLOCK_PLACE"] = "Unlock undiscovered places"
L["MENU_UNLOCK_BOOK"] = "Unlock unfound readables"
L["MENU_UNLOCK_BOSS"] = "Unlock unfound bosses"
L["TT_UNLOCK"] = "Spoken's own switch, the same one on its page. On, nothing waits to be found first."
L["SETTINGS_HINT"] = "Spoken's Unlock switches, the same ones on Spoken's page. On, EasyFind plays and opens what you have not found yet."

L["NO_VOICE"] = "No installed voice pack has this line yet."
L["NO_NARRATOR"] = "No voice pack has this story and Spoken's narrator is off."
L["LOCK_QUEST"] = "Spoken keeps this quest's words until you start it."
L["LOCK_PLACE"] = "Spoken keeps this story until you discover the place."
L["LOCK_BOOK"] = "Spoken keeps this writing until you find it."
L["LOCK_BOSS"] = "Spoken keeps this story until you meet the boss."

L["NOT_READY_SPOKEN"] = "Spoken is too old for this extension. Update Spoken."
L["NOT_READY_EASYFIND"] = "This extension needs a newer EasyFind. Update EasyFind."
