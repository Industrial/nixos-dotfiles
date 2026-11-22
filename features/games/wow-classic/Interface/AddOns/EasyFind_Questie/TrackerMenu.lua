-- Directions in Questie's own tracker menu: on a client where Questie's
-- tracker stands in for the game's, the game's quest menus never show, so
-- the GPS's entry on them never reaches a Questie quest. Questie's menu is a
-- list its TrackerMenu module builds and returns; the builder is wrapped
-- here, at run time, to add our entry before Cancel, only with the GPS
-- installed. Nothing of Questie's is edited.
local _, ns = ...
local API = EasyFind and EasyFind.API
if not (API and ns.Directions) then return end
local L = ns.L

local tinsert = table.insert
local installed

function ns.InstallTrackerMenu()
    if installed then return end
    local Loader = QuestieLoader
    local Menu = Loader and Loader.ImportModule and Loader:ImportModule("TrackerMenu")
    local build = Menu and Menu.GetMenuForQuest
    if type(build) ~= "function" then return end
    installed = true
    Menu.GetMenuForQuest = function(self, quest, ...)
        local menu = build(self, quest, ...)
        local id = type(quest) == "table" and quest.Id
        if type(menu) == "table" and id and API.HasAction("gps", "navigate") then
            -- Before Cancel, the list's last entry.
            local at = #menu
            if at == 0 or menu[at].text ~= CANCEL then at = at + 1 end
            tinsert(menu, at, { text = L["MENU_DIRECTIONS"], func = function() ns.Directions(id) end })
        end
        return menu
    end
end

ns.InstallTrackerMenu()
