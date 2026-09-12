local guilds = {
    "Gank Squad", "PvP Masters", "Corpse Campers", "World Slayers", "Honor Farmers",
    "Rank Grinders", "Blood Knights", "Deadly Alliance", "Battleground Heroes", "Warsong Outlaws",
    "Death and Taxes", "Tactical Retreat", "Shadow Dancers", "First Strike", "Elite Few",
    "Kill on Sight", "No Mercy", "Rogues Do It", "Battlefield Legends", "" -- Empty guild possible
}

-- Make guildRanks global so it can be accessed from other files like DebugTools
guildRanks = {
    "Guild Master", "Officer", "Veteran", "Member", "Initiate", "Recruit", "Alt", ""
}

local testPlayers = {
    {
        name = "Testplayer",
        class = "Warrior",
        race = "Human",
        gender = "Male"
    },
    {
        name = "Gankalicious",
        class = "Rogue",
        race = "Night Elf",
        gender = "Female",
    },
    {
        name = "Pwnyou",
        class = "Paladin",
        race = "Dwarf",
        gender = "Male",
    },
    {
        name = "Arrowstorm",
        class = "Hunter",
        race = "Night Elf",
        gender = "Female",
    },
    {
        name = "Holyhealer",
        class = "Priest",
        race = "Human",
        gender = "Female",
    },
    {
        name = "Totemcaller",
        class = "Shaman",
        race = "Tauren",
        gender = "Male",
    },
    {
        name = "Firestarter",
        class = "Mage",
        race = "Gnome",
        gender = "Female",
    },
    {
        name = "Darkcaster",
        class = "Warlock",
        race = "Human",
        gender = "Male",
    },
    {
        name = "Natureguard",
        class = "Druid",
        race = "Night Elf",
        gender = "Male",
    },
    {
        name = "Shieldbearer",
        class = "Warrior",
        race = "Dwarf",
        gender = "Female",
    },
    {
        name = "Lightbringer",
        class = "Paladin",
        race = "Human",
        gender = "Female",
    },
    {
        name = "Beastmaster",
        class = "Hunter",
        race = "Dwarf",
        gender = "Male",
    },
    {
        name = "Shadowpriest",
        class = "Priest",
        race = "Dwarf",
        gender = "Female",
    },
    {
        name = "Stormcaller",
        class = "Shaman",
        race = "Tauren",
        gender = "Female",
    },
    {
        name = "Frostmage",
        class = "Mage",
        race = "Human",
        gender = "Male",
    },
    {
        name = "Soulreaper",
        class = "Warlock",
        race = "Gnome",
        gender = "Female",
    },
    {
        name = "Moonkin",
        class = "Druid",
        race = "Night Elf",
        gender = "Female",
    },
    {
        name = "Berserker",
        class = "Warrior",
        race = "Gnome",
        gender = "Male",
    },
    {
        name = "Divineknight",
        class = "Paladin",
        race = "Human",
        gender = "Male",
    },
    {
        name = "Sniper",
        class = "Hunter",
        race = "Dwarf",
        gender = "Male",
    },
    {
        name = "Mindbender",
        class = "Priest",
        race = "Gnome",
        gender = "Female",
    },
    {
        name = "Earthshaker",
        class = "Shaman",
        race = "Tauren",
        gender = "Male",
    },
    {
        name = "Pyromancer",
        class = "Mage",
        race = "Gnome",
        gender = "Male",
    },
    {
        name = "Demonologist",
        class = "Warlock",
        race = "Human",
        gender = "Female",
    },
    {
        name = "Wildheart",
        class = "Druid",
        race = "Night Elf",
        gender = "Male",
    },
    {
        name = "Silentblade",
        class = "Rogue",
        race = "Human",
        gender = "Male",
    },
    {
        name = "Nightstalker",
        class = "Rogue",
        race = "Dwarf",
        gender = "Female",
    },
    {
        name = "Windrunner",
        class = "Hunter",
        race = "Orc",
        gender = "Female",
    },
    {
        name = "Arcaneweaver",
        class = "Mage",
        race = "Troll",
        gender = "Male",
    },
    {
        name = "Soulbinder",
        class = "Warlock",
        race = "Orc",
        gender = "Female",
    },
    {
        name = "Lifebringer",
        class = "Priest",
        race = "Troll",
        gender = "Male",
    },
    {
        name = "Ironshield",
        class = "Warrior",
        race = "Night Elf",
        gender = "Female",
    },
    {
        name = "Beastcaller",
        class = "Hunter",
        race = "Tauren",
        gender = "Male",
    },
    {
        name = "Shadowblade",
        class = "Rogue",
        race = "Gnome",
        gender = "Female",
    },
    {
        name = "Mystic",
        class = "Warlock",
        race = "Gnome",
        gender = "Male",
    },
    {
        name = "Flamecaster",
        class = "Mage",
        race = "Undead",
        gender = "Female",
    },
    {
        name = "Darkweaver",
        class = "Warlock",
        race = "Undead",
        gender = "Male",
    },
    {
        name = "Moonshadow",
        class = "Druid",
        race = "Tauren",
        gender = "Female",
    },
    {
        name = "Stormbringer",
        class = "Warrior",
        race = "Human",
        gender = "Male",
    },
    {
        name = "Frostweaver",
        class = "Mage",
        race = "Undead",
        gender = "Female",
    },
    {
        name = "Doomcaller",
        class = "Warlock",
        race = "Human",
        gender = "Female",
    },
    {
        name = "Naturewarden",
        class = "Druid",
        race = "Tauren",
        gender = "Male",
    },
    {
        name = "Lightwarden",
        class = "Paladin",
        race = "Dwarf",
        gender = "Female",
    },
    {
        name = "Bladewhisper",
        class = "Rogue",
        race = "Orc",
        gender = "Male",
    },
    {
        name = "Stonefist",
        class = "Warrior",
        race = "Orc",
        gender = "Male",
    },
    {
        name = "Spiritcaller",
        class = "Shaman",
        race = "Orc",
        gender = "Female",
    },
    {
        name = "Shadowhunter",
        class = "Hunter",
        race = "Troll",
        gender = "Male",
    },
    {
        name = "Hexweaver",
        class = "Shaman",
        race = "Troll",
        gender = "Female",
    },
    {
        name = "Deathbringer",
        class = "Warrior",
        race = "Undead",
        gender = "Male",
    },
    {
        name = "Soulstealer",
        class = "Rogue",
        race = "Undead",
        gender = "Female",
    },
    {
        name = "Plaguecaster",
        class = "Mage",
        race = "Undead",
        gender = "Male",
    },
    {
        name = "Bonecrusher",
        class = "Warrior",
        race = "Tauren",
        gender = "Male",
    },
    {
        name = "Earthcaller",
        class = "Shaman",
        race = "Tauren",
        gender = "Female",
    },
    -- TBC Races
    {
        name = "Sunstrider",
        class = "Paladin",
        race = "Blood Elf",
        gender = "Male",
    },
    {
        name = "Felweaver",
        class = "Warlock",
        race = "Blood Elf",
        gender = "Female",
    },
    {
        name = "Phoenixfire",
        class = "Mage",
        race = "Blood Elf",
        gender = "Male",
    },
    {
        name = "Bloodhawk",
        class = "Hunter",
        race = "Blood Elf",
        gender = "Female",
    },
    {
        name = "Shadowstrike",
        class = "Rogue",
        race = "Blood Elf",
        gender = "Male",
    },
    {
        name = "Crystalforge",
        class = "Paladin",
        race = "Draenei",
        gender = "Male",
    },
    {
        name = "Voidcaller",
        class = "Priest",
        race = "Draenei",
        gender = "Female",
    },
    {
        name = "Exodarguard",
        class = "Warrior",
        race = "Draenei",
        gender = "Male",
    },
    {
        name = "Lightseeker",
        class = "Mage",
        race = "Draenei",
        gender = "Female",
    },
    {
        name = "Prophetshand",
        class = "Shaman",
        race = "Draenei",
        gender = "Male",
    }
}


local function GenerateRandomRank()
    -- Generate random rank (0-14)
    -- Higher chance for lower ranks, lower chance for high ranks
    local rankChance = math.random(100)
    local randomRank = 0

    if rankChance <= 40 then
        -- 40% chance for rank 0 (no rank)
        randomRank = 0
    elseif rankChance <= 70 then
        -- 30% chance for ranks 1-4 (Private to Master Sergeant)
        randomRank = math.random(1, 4)
    elseif rankChance <= 90 then
        -- 20% chance for ranks 5-8 (Sergeant Major to Knight-Captain)
        randomRank = math.random(5, 8)
    elseif rankChance <= 98 then
        -- 8% chance for ranks 9-12 (Knight-Champion to Marshal)
        randomRank = math.random(9, 12)
    else
        -- 2% chance for ranks 13-14 (Field Marshal and Grand Marshal)
        randomRank = math.random(13, 14)
    end

    return randomRank
end

function PSC_GetRandomTestPlayer()
    local i = math.random(1, #testPlayers)
    local testPlayer = testPlayers[i]
    testPlayer.level = math.random(1, 70)
    if math.random(100) <= 10 then
        testPlayer.level = -1
    end
    testPlayer.guildName = guilds[math.random(1, #guilds)]
    testPlayer.guildRankName = guildRanks[math.random(1, #guildRanks)]
    testPlayer.rank = GenerateRandomRank()

    return testPlayer
end
