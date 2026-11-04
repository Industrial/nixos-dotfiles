-- Marks the running client as WoW: Forever (codename Camelot) and holds all of its data.
-- Forever is a mainline fork, so WOW_PROJECT_ID == WOW_PROJECT_MAINLINE there.
-- This file is listed ONLY in BetterBags-Teleports_Camelot.toc, which makes
-- load-time the reliable signal. It replaces every other data file on Forever and must load before main.lua.
---@type string, AddonNS
local _, addon = ...

addon.isForever = true

addon.data = {}

addon.data.enablePortalReagents = {
    {17031}, -- Rune of Teleportation
    {17032}, -- Rune of Portals
}

addon.data.forever = {
    {6948}, -- Hearthstone
    {9173}, -- Goblin Transponder (Unlocks a teleport from Booty Bay to Gnomeregan)
    {12585}, -- Stormwind Medallion (Creates a group portal to Stormwind)
    {17191}, -- Scepter of Celebras (Creates a group portal to Earth Song Falls in inner Maraudon)
    {17690}, -- Frostwolf Insignia Rank 1
    {17691}, -- Stormpike Insignia Rank 1
    {17900}, -- Stormpike Insignia Rank 2
    {17901}, -- Stormpike Insignia Rank 3
    {17902}, -- Stormpike Insignia Rank 4
    {17903}, -- Stormpike Insignia Rank 5
    {17904}, -- Stormpike Insignia Rank 6
    {17905}, -- Frostwolf Insignia Rank 2
    {17906}, -- Frostwolf Insignia Rank 3
    {17907}, -- Frostwolf Insignia Rank 4
    {17908}, -- Frostwolf Insignia Rank 5
    {17909}, -- Frostwolf Insignia Rank 6
    {18149}, -- Rune of Recall (Frostwolf Keep)
    {18150}, -- Rune of Recall (Dun Baldar)
    {18984}, -- Dimensional Ripper - Everlook
    {18986}, -- Ultrasafe Transporter - Gadgetzan
    {21711}, -- Lunar Festival Invitation (Teleports from Greater Moonlight)
    {22589}, -- Atiesh, Greatstaff of the Guardian (Mage)
    {22630}, -- Atiesh, Greatstaff of the Guardian (Warlock)
    {22631}, -- Atiesh, Greatstaff of the Guardian (Priest)
    {22632}, -- Atiesh, Greatstaff of the Guardian (Druid)
    {191267}, -- Rune of Teleportation: Antechamber (Naxxramas)
    {191288}, -- Rune of Teleportation: Frostwyrm's Lair (Naxxramas)
    {213548}, -- Scroll of Liminal Passage (Teleport to a party member while resting)
    {260819}, -- EZ-Thro Field Transporter: Gadgetzan
    {260820}, -- SAF-T Emergency Ripper: Everlook
    {260821}, -- EZ and SAF Field Transporter: Mt. Hyjal
    {260823}, -- Dimensional Transporter - Mt. Hyjal
    {282006}, -- Crumbling Hearthstone (Single-use, returns you to Orgrimmar)
}
