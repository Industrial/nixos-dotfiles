-- Dire Maul and Stratholme: which wing a (lower-case) instance, zone or room
-- name belongs to. Used by the journal's dungeon detection.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

local EAST, WEST, NORTH = "Dire Maul: East", "Dire Maul: West", "Dire Maul: North"
local LIVING, UNDEAD = "Stratholme: Living", "Stratholme: Undead"
local LBRS, UBRS = "Lower Blackrock Spire", "Upper Blackrock Spire"

local ROOMS = {
    ["warpwood quarter"] = EAST, ["the hidden reach"] = EAST, ["the conservatory"] = EAST, ["the shrine of eldretharr"] = EAST,
    ["capital gardens"] = WEST, ["court of the highborne"] = WEST, ["prison of immol'thar"] = WEST, ["the athenaeum"] = WEST,
    ["gordok commons"] = NORTH, ["halls of destruction"] = NORTH, ["the gordok commons"] = NORTH,
    ["king's square"] = LIVING, ["market row"] = LIVING, ["crusaders' square"] = LIVING, ["festival lane"] = LIVING,
    ["the scarlet bastion"] = LIVING, ["the hall of lights"] = LIVING, ["the hoard"] = LIVING, ["the crimson throne"] = LIVING,
    ["hordemar city"] = LBRS, ["tazz'alaor"] = LBRS, ["skitterweb tunnels"] = LBRS, ["mok'doom"] = LBRS,
    ["the storehouse"] = LBRS, ["halycon's lair"] = LBRS, ["chamber of battle"] = LBRS, ["the burning shrine"] = LBRS,
    ["hall of binding"] = UBRS, ["the rookery"] = UBRS, ["hall of blackhand"] = UBRS, ["blackrock stadium"] = UBRS,
    ["dragonspire hall"] = UBRS, ["the beast's lair"] = UBRS, ["spire throne"] = UBRS,
    ["elders' square"] = UNDEAD, ["the gauntlet"] = UNDEAD, ["slaughter square"] = UNDEAD, ["the slaughter house"] = UNDEAD,
}

function FDJ.WingFromText(n)
    if type(n) ~= "string" or n == "" then return nil end
    n = n:lower()
    if ROOMS[n] then return ROOMS[n] end
    if n:find("dire maul", 1, true) then
        if n:find("east", 1, true) then return EAST end
        if n:find("west", 1, true) then return WEST end
        if n:find("north", 1, true) then return NORTH end
    end
    if n:find("blackrock spire", 1, true) then
        if n:find("upper", 1, true) then return UBRS end
        if n:find("lower", 1, true) then return LBRS end
    end
    if n:find("stratholme", 1, true) then
        if n:find("undead", 1, true) or n:find("service", 1, true) then return UNDEAD end
        if n:find("living", 1, true) or n:find("main gate", 1, true) then return LIVING end
    end
    return nil
end
