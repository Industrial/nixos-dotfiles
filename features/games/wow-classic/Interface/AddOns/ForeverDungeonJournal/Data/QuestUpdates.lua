local ADDON_NAME, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS

-- Client-cache fallbacks; live rewards always take precedence.
FDJ.FOREVER_QUEST_XP_FALLBACK[1490] = 115
-- Reward observed in the beta quest window.
FDJ.FOREVER_QUEST_XP_FALLBACK[378] = 5750
FDJ.QUEST_PREREQ_CHAINS[98823] = {{
    id = 95664,
    name = "Elder Knowledge",
    -- excavhorde (2.0.7): started by the Titan Relic from inside the dungeon,
    -- so the route hands it in (and takes Earthen Echo) after the run.
    startsInDungeon = true,
}}
FDJ.QUEST_PREREQ_CHAINS[98824] = {{
    id = 95810,
    name = "Lost Relic Carry",
}}
FDJ.QUEST_PREREQ_DETAILS[95664] = {
    objective = "Take the Titan Relic to the Elder Rise in Thunder Bluff and look for someone who can tell you more about it.",
    startItem = {270866, "Titan Relic", 1, "Dropped by: Relic Guardian"},
    pickup = "Titan Relic (dropped by Relic Guardian)",
    level = 31,
    requires = 24,
    turnin = "Bashana Runetotem, Elder Rise, Thunder Bluff",
}
FDJ.FOREVER_QUEST_XP_FALLBACK[95664] = 1400
FDJ.QUEST_PREREQ_DETAILS[95810] = {
    objective = "Deliver the Titan Relic to Prospector Whelgar at the Wetlands excavation site.",
    objectiveInDungeon = false, -- handed in at Whelgar's camp, not inside
    startItem = {270866, "Titan Relic", 1, "Dropped by: Relic Guardian"},
    pickup = "Titan Relic (dropped by Relic Guardian)",
    level = 31,
    requires = 24,
    turnin = "Prospector Whelgar, Whelgar's Excavation Site, Wetlands",
}
FDJ.FOREVER_QUEST_XP_FALLBACK[95810] = 630

-- Paladin (human / dwarf): The Tome of Valor -> The Test of Righteousness.
-- The list is exactly the five-quest series shown on Wowhead and ends on 1806,
-- the step that awards Verigan's Fist.
FDJ.QUEST_PREREQ_CHAINS[1806] = {
    { id = 1651, name = "The Tome of Valor" },
    { id = 1652, name = "The Tome of Valor" },
    { id = 1653, name = "The Test of Righteousness" },
    { id = 1654, name = "The Test of Righteousness" },
}
FDJ.QUEST_PREREQ_DETAILS[1651] = { level = 25, requires = 20, objective = "Defend Daphne Stilwell from the Defias attack.", pickup = "Daphne Stilwell, Westfall", turnin = "Daphne Stilwell, Westfall", map = { mapID = 1436, x = 0.422, y = 0.886, label = "Daphne Stilwell — Westfall", detail = "Daphne Stilwell is in the far south of Westfall" } }
FDJ.QUEST_PREREQ_DETAILS[1652] = { level = 25, requires = 20, objective = "Speak to Duthorian Rall in Stormwind.", pickup = "Daphne Stilwell, Westfall", turnin = "Duthorian Rall, Cathedral Square, Stormwind" }
FDJ.QUEST_PREREQ_DETAILS[1653] = { level = 21, requires = 20, objective = "Speak to Jordan Stilwell in Ironforge.", pickup = "Duthorian Rall, Cathedral Square, Stormwind", turnin = "Jordan Stilwell, Gates of Ironforge, Dun Morogh" }
FDJ.QUEST_PREREQ_DETAILS[1654] = {
    level = 22, requires = 20,
    objective = "Using Jordan's Weapon Notes, find some Whitestone Oak Lumber, Bailor's Refined Ore Shipment, Jordan's Smithing Hammer, and a Kor Gem, and return them to Jordan Stilwell in Ironforge.",
    -- {itemID, name, quality, source line shown at the bottom of the item tooltip}
    requiredItems = {
        {6994, "Whitestone Oak Lumber", 1, "Dropped by: Goblin Woodcarver, The Deadmines"},
        {6993, "Jordan's Refined Ore Shipment", 1, "Reward from the quest Bailor's Ore Shipment: Bailor Stonehand, Thelsamar, Loch Modan"},
        {6895, "Jordan's Smithing Hammer", 1, "Found in: Jordan's Hammer, Shadowfang Keep courtyard"},
        {7083, "Purified Kor Gem", 1, "Reward from the quest Seeking the Kor Gem: Thundris Windweaver, Auberdine, Darkshore. The Corrupted Kor Gem he asks for drops from Blackfathom Tide Priestesses and Oracles at the Blackfathom Deeps entrance and from Blackfathom Sea Witches inside."},
    },
    providedItem = {6996, "Jordan's Weapon Notes", 1, "Given by Jordan Stilwell when you accept the quest"},
    pickup = "Jordan Stilwell, Gates of Ironforge, Dun Morogh",
    turnin = "Jordan Stilwell, Gates of Ironforge, Dun Morogh",
    map = { mapID = 1426, x = 0.526, y = 0.368, label = "Jordan Stilwell — Gates of Ironforge", detail = "Jordan Stilwell stands outside the gates of Ironforge" },
}
FDJ.QUEST_PREREQ_DETAILS[1806] = { level = 22, requires = 20, objective = "Wait for Jordan Stilwell to finish forging a weapon for you.", pickup = "Jordan Stilwell, Gates of Ironforge, Dun Morogh", turnin = "Jordan Stilwell, Gates of Ironforge, Dun Morogh", description = "Final step. Rewards Verigan's Fist." }
FDJ.PREREQ_REWARD_ITEMS_FALLBACK[1806] = { items = { {6953, "Verigan's Fist", 3} }, choice = false }
FDJ.FOREVER_QUEST_XP_FALLBACK[1806] = 5500


-- BEGIN hordepaladin
-- Paladin (undead / tauren, WoW Forever): The Debt -> A Moon-Kissed Blade ->
-- An Underrated Talent -> Ott's Masterwork -> The Moonsilver Blade, then Old
-- Fire-Eye (the journal entry), which awards Wolfsbane. A Moon-Kissed Blade
-- needs Whitestone Oak Lumber (The Deadmines), the Enchanted Silver Ingot
-- (Shadowfang Keep) and the Purified Kor Gem (Blackfathom Deeps naga).
FDJ.QUEST_PREREQ_CHAINS[95140] = {
    { id = 91858, name = "Diplomatic Incident" },
    { id = 91859, name = "A Curious Pair" },
    { id = 91860, name = "A Grim Fate" },
    { id = 91861, name = "Into Fenris Keep" },
    { id = 91862, name = "Lumina Windsinger" },
    { id = 96204, name = "The Windshaper's Wrath" },
    { id = 95034, name = "The Debt" },
    { id = 95036, name = "A Moon-Kissed Blade" },
    { id = 95111, name = "An Underrated Talent" },
    { id = 95125, name = "Ott's Masterwork" },
    { id = 95126, name = "The Moonsilver Blade" },
}
FDJ.QUEST_PREREQ_DETAILS[95034] = {
    level = 24, requires = 18,
    objective = "Speak with Lumina Windsinger in the Sepulcher.",
    pickup = "Lumina Windsinger, The Sepulcher, Silverpine Forest",
    turnin = "Lumina Windsinger, The Sepulcher, Silverpine Forest",
    description = "The questline starts at level 18 with Diplomatic Incident from Danitha Morr at Bandarion Keep, Tirisfal Glades. It takes you to Fenris Isle, where you free Lumina Windsinger from Fenris Keep.",
    map = { mapID = 1421, x = 0.433, y = 0.410, label = "Lumina Windsinger — The Sepulcher", targetName = "Lumina Windsinger" },
}
FDJ.QUEST_PREREQ_DETAILS[95036] = {
    level = 25, requires = 20,
    objective = "Speak with Trevan Rol in the Sepulcher and bring him the materials he requires.",
    -- {itemID, name, quality, source line shown at the bottom of the item tooltip}
    requiredItems = {
        {6994, "Whitestone Oak Lumber", 1, "Dropped by: Goblin Woodcarver, The Deadmines"},
        {267361, "Enchanted Silver Ingot", 1, "Found on a table in Archmage Arugal's room at the end of Shadowfang Keep, after you kill him"},
        {272448, "Purified Kor Gem", 1, "Reward from the quest Seeking the Kor Gem: Ulric Frostveil, Zoram'gar Outpost, Ashenvale. The Corrupted Kor Gem he asks for drops from Blackfathom Tide Priestesses and Oracles at the Blackfathom Deeps entrance and from Blackfathom Sea Witches inside, once you have his quest."},
    },
    providedItem = {267454, "Trevan's Weapon Notes", 1, "Given by Trevan Rol in the Sepulcher"},
    pickup = "Lumina Windsinger, The Sepulcher, Silverpine Forest",
    turnin = "Trevan Rol, The Sepulcher, Silverpine Forest",
    map = { mapID = 1421, x = 0.433, y = 0.410, label = "Lumina Windsinger — The Sepulcher", targetName = "Lumina Windsinger" },
    turninMap = { mapID = 1421, x = 0.434, y = 0.410, label = "Trevan Rol — The Sepulcher", targetName = "Trevan Rol" },
}
FDJ.QUEST_PREREQ_DETAILS[95111] = {
    level = 25, requires = 20,
    objective = "Speak with Ott and ask him to forge your blade.",
    pickup = "Trevan Rol, The Sepulcher, Silverpine Forest",
    turnin = "Ott, Tarren Mill, Hillsbrad Foothills",
    map = { mapID = 1421, x = 0.434, y = 0.410, label = "Trevan Rol — The Sepulcher", targetName = "Trevan Rol" },
    turninMap = { mapID = 1424, x = 0.604, y = 0.262, label = "Ott — Tarren Mill", targetName = "Ott" },
}
FDJ.QUEST_PREREQ_DETAILS[95125] = {
    level = 25, requires = 20,
    objective = "Watch as Ott forges your blade.",
    pickup = "Ott, Tarren Mill, Hillsbrad Foothills",
    turnin = "Ott, Tarren Mill, Hillsbrad Foothills",
    map = { mapID = 1424, x = 0.604, y = 0.262, label = "Ott — Tarren Mill", targetName = "Ott" },
}
FDJ.QUEST_PREREQ_DETAILS[95126] = {
    level = 25, requires = 20,
    objective = "Bring Ott's Masterwork to Trevan Rol in Silverpine Forest.",
    pickup = "Ott, Tarren Mill, Hillsbrad Foothills",
    turnin = "Trevan Rol, The Sepulcher, Silverpine Forest",
    map = { mapID = 1424, x = 0.604, y = 0.262, label = "Ott — Tarren Mill", targetName = "Ott" },
    turninMap = { mapID = 1421, x = 0.434, y = 0.410, label = "Trevan Rol — The Sepulcher", targetName = "Trevan Rol" },
}
FDJ.PREREQ_REWARD_ITEMS_FALLBACK[95126] = { items = { {268484, "Moonsilver Blade", 2} }, choice = false }
FDJ.QUEST_PREREQ_DETAILS[95140] = { level = 26, requires = 20, objective = "Use the Moonsilver Blade to destroy Old-Fire Eye in Silverpine Forest.", pickup = "Lumina Windsinger, The Sepulcher, Silverpine Forest", turnin = "Lumina Windsinger, The Sepulcher, Silverpine Forest", description = "Final step. Old Fire-Eye is at the Greymane Wall in southern Silverpine Forest. Rewards Wolfsbane." }
FDJ.PREREQ_REWARD_ITEMS_FALLBACK[95140] = { items = { {267369, "Wolfsbane", 3} }, choice = false }
FDJ.FOREVER_QUEST_XP_FALLBACK[95140] = 2650
-- The six steps before The Debt (Wowhead Forever series of quest 91858;
-- reported on Discord by belpickle and xperl73): all level 22, from 18.
do
    local DANITHA = { mapID = 1420, x = 0.220, y = 0.446, label = "Danitha Morr — Bandarion Keep, Tirisfal Glades", targetName = "Danitha Morr" }
    local TREVAN = { mapID = 1421, x = 0.434, y = 0.410, label = "Trevan Rol — The Sepulcher", targetName = "Trevan Rol" }
    local BALDREN = { mapID = 1421, x = 0.456, y = 0.418, label = "Deathguard Baldren — The Sepulcher", targetName = "Deathguard Baldren" }
    local REMAINS = { mapID = 1421, x = 0.650, y = 0.342, label = "Charred Remains — Fenris Isle", targetName = "Charred Remains" }
    local LUMINA_KEEP = { mapID = 1421, x = 0.657, y = 0.274, label = "Lumina Windsinger — Fenris Keep", targetName = "Lumina Windsinger" }
    local LUMINA = { mapID = 1421, x = 0.433, y = 0.410, label = "Lumina Windsinger — The Sepulcher", targetName = "Lumina Windsinger" }
    local D = FDJ.QUEST_PREREQ_DETAILS
    D[91858] = {
        level = 22, requires = 18,
        objective = "Travel to The Sepulcher in Silverpine Forest and speak with Trevan Rol about the missing Earthen Ring travelers.",
        pickup = "Danitha Morr, Bandarion Keep, Tirisfal Glades",
        turnin = "Trevan Rol, The Sepulcher, Silverpine Forest",
        map = DANITHA, turninMap = TREVAN,
    }
    D[91859] = {
        level = 22, requires = 18,
        objective = "Speak with Deathguard Baldren about the mysterious Earthen Ring travelers who recently passed through The Sepulcher.",
        pickup = "Trevan Rol, The Sepulcher, Silverpine Forest",
        turnin = "Deathguard Baldren, The Sepulcher, Silverpine Forest",
        map = TREVAN, turninMap = BALDREN,
    }
    D[91860] = {
        level = 22, requires = 18,
        objective = "Investigate Fenris Isle to the east and learn the fate of the Earthen Ring traveling party.",
        pickup = "Deathguard Baldren, The Sepulcher, Silverpine Forest",
        turnin = "Charred Remains, Fenris Isle, Silverpine Forest",
        map = BALDREN, turninMap = REMAINS,
    }
    D[91861] = {
        level = 22, requires = 18,
        objective = "Investigate Fenris Keep to the north and attempt to locate the missing member of the Earthen Ring party.",
        pickup = "Charred Remains, Fenris Isle, Silverpine Forest",
        turnin = "Lumina Windsinger, Fenris Keep, Silverpine Forest",
        map = REMAINS, turninMap = LUMINA_KEEP,
    }
    D[91862] = {
        level = 22, requires = 18,
        objective = "Retrieve the Fenris Isle Key from the Rot Hide Gnolls and use it to free Lumina Windsinger.",
        requiredItems = { {267412, "Fenris Isle Key", 1, "Dropped by the Rot Hide gnolls on Fenris Isle (Rot Hide Savage, Raging Rot Hide, Rot Hide Bruiser, Snarlmane)", map = { mapID = 1421, x = 0.656, y = 0.238, label = "Rot Hide gnolls — Fenris Isle", detail = "Dropped by the Rot Hide gnolls on Fenris Isle (Rot Hide Savage, Raging Rot Hide, Rot Hide Bruiser, Snarlmane)" }} },
        pickup = "Lumina Windsinger, Fenris Keep, Silverpine Forest",
        turnin = "Lumina Windsinger, Fenris Keep, Silverpine Forest",
        map = LUMINA_KEEP,
    }
    D[96204] = {
        level = 22, requires = 18,
        objective = "Accompany Lumina Windsinger and help her escape Fenris Keep.",
        pickup = "Lumina Windsinger, Fenris Keep, Silverpine Forest",
        turnin = "Lumina Windsinger, The Sepulcher, Silverpine Forest",
        map = LUMINA_KEEP, turninMap = LUMINA,
    }
end
-- END hordepaladin

-- BEGIN ritualsofpower
-- Mage, Scarlet Monastery Library: Journey to the Marsh -> Hidden Secrets ->
-- Get the Scoop -> Rituals of Power (the journal entry). Wowhead Forever
-- quests 1947, 1949-1951.
do
    local TABETHA = { mapID = 1445, x = 0.460, y = 0.570, label = "Tabetha — Dustwallow Marsh", targetName = "Tabetha" }
    local TIRTH = { mapID = 1441, x = 0.782, y = 0.758, label = "Magus Tirth — Shimmering Flats", targetName = "Magus Tirth" }
    FDJ.QUEST_PREREQ_CHAINS[1951] = {
        -- marshstep (2.0.13, thanu5987 on Discord, 19 Nov 2026; Wowhead Forever
        -- quest 1947): the chain starts at a mage trainer in a capital city.
        { id = 1947, name = "Journey to the Marsh" },
        { id = 1949, name = "Hidden Secrets" },
        { id = 1950, name = "Get the Scoop" },
    }
    FDJ.QUEST_PREREQ_DETAILS[1947] = {
        level = 38, requires = 30,
        objective = "Speak with Tabetha.",
        pickup = "Your mage trainer in a capital city: Jennea Cannon (Stormwind), Bink (Ironforge), Deino (Orgrimmar), Ursyn Ghull (Thunder Bluff) or Anastasia Hartwell (Undercity)",
        pickupAlliance = "Your mage trainer in a capital city: Jennea Cannon (Stormwind) or Bink (Ironforge)",
        pickupHorde = "Your mage trainer in a capital city: Deino (Orgrimmar), Ursyn Ghull (Thunder Bluff) or Anastasia Hartwell (Undercity)",
        turnin = "Tabetha, Dustwallow Marsh",
        turninMap = TABETHA,
    }
    FDJ.QUEST_PREREQ_DETAILS[1949] = {
        level = 38, requires = 30,
        objective = "Speak with Magus Tirth in the Shimmering Flats.",
        pickup = "Tabetha, Dustwallow Marsh",
        turnin = "Magus Tirth, Shimmering Flats, Thousand Needles",
        map = TABETHA, turninMap = TIRTH,
    }
    FDJ.QUEST_PREREQ_DETAILS[1950] = {
        level = 30, requires = 30,
        objective = "Find the phrase to Tirth's strongbox, then return to Tirth.",
        pickup = "Magus Tirth, Shimmering Flats, Thousand Needles",
        turnin = "Magus Tirth, Shimmering Flats, Thousand Needles",
        map = TIRTH,
    }
end
-- END ritualsofpower

-- BEGIN lessoninliteracy
-- A Lesson in Literacy (mage, Zul'Farrak): one quest ID, a giver per faction
-- (Wowhead Forever quest 82084). The player's own giver once the faction is
-- known; until then the entry names both.
do
    local GIVER = {
        Alliance = { text = "Garion Wendell, Stormwind",
            map = { mapID = 1453, x = 0.488, y = 0.866, label = "Garion Wendell — Stormwind", targetName = "Garion Wendell" } },
        Horde = { text = "Owen Thadd, Undercity",
            map = { mapID = 1458, x = 0.736, y = 0.330, label = "Owen Thadd — Undercity", targetName = "Owen Thadd" } },
    }
    local function Apply()
        if type(UnitFactionGroup) ~= "function" then return end
        local ok, faction = pcall(UnitFactionGroup, "player")
        if not ok or (type(issecretvalue) == "function" and issecretvalue(faction)) then return end
        local giver = GIVER[faction]
        local d = FDJ.DB and FDJ.DB["Zul'Farrak"]
        if not giver or not d then return end
        for _, q in ipairs(d.quests or {}) do
            if q.id == 82084 then
                q.pickup, q.turnin, q.startMap = giver.text, giver.text, giver.map
            end
        end
    end
    Apply()
    if CreateFrame then
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_LOGIN")
        f:SetScript("OnEvent", Apply)
    end
end
-- END lessoninliteracy

-- An Unholy Alliance (Horde): the journal entry is the final step (6521); part 1 starts from the Small Scroll in Razorfen
-- Kraul; the final step is completed in the area outside Razorfen Downs and gives the item reward.
FDJ.QUEST_PREREQ_CHAINS[6521] = {
    { id = 6522, name = "An Unholy Alliance" },
}
FDJ.QUEST_PREREQ_DETAILS[6522] = { level = 36, requires = 28, objective = "Take the Small Scroll to Varimathras in the Undercity.", pickup = "Small Scroll, dropped by Charlga Razorflank", startItem = {17008, "Small Scroll", 1, "Drops from Charlga Razorflank in Razorfen Kraul"}, turnin = "Varimathras, Royal Quarter, Undercity" }
FDJ.QUEST_PREREQ_DETAILS[6521] = { level = 36, requires = 28, objective = "Bring Ambassador Malcin's Head to Varimathras in the Undercity.", pickup = "Varimathras, Royal Quarter, Undercity", turnin = "Varimathras, Royal Quarter, Undercity", description = "Final step. Ambassador Malcin is outside Razorfen Downs." }
FDJ.PREREQ_REWARD_ITEMS_FALLBACK[6521] = { items = { {17039, "Skullbreaker", 2}, {17042, "Nail Spitter", 2}, {17043, "Zealot's Robe", 2}, {270054, "Cultist's Chestguard", 3} }, choice = true }
FDJ.PREREQ_REWARD_MONEY_FALLBACK[6521] = 2000
FDJ.FOREVER_QUEST_XP_FALLBACK[6521] = 3500

-- These are item-start quests. Leave other new quests to the live predicate.
FDJ.QUEST_SHAREABILITY_AUDIT[95809] = false
FDJ.QUEST_SHAREABILITY_AUDIT[95664] = false
FDJ.QUEST_SHAREABILITY_AUDIT[95810] = false

-- Drop superseded translations of corrected fields, retaining localized names.
for _, content in pairs(FDJ.ContentLocales or {}) do
    local quests = content.quests or {}
    if quests[95809] then
        quests[95809].pickup = nil
        quests[95809].objective = nil
    end
end

-- Test of Lore (Horde): earlier steps, all require level 25 (Wowhead Forever series).
-- Ragefire Chasm: Returning the Lost Satchel is the journal entry; Searching for
-- the Lost Satchel is its earlier step.
FDJ.QUEST_PREREQ_CHAINS[5724] = {
    { id = 5722, name = "Searching for the Lost Satchel" },
}
FDJ.QUEST_PREREQ_DETAILS[5722] = { level = 16, requires = 9, objective = "Find Maur Grimtotem's corpse inside Ragefire Chasm and search it for anything of interest.", pickup = "Rahauro, Elder Rise, Thunder Bluff", turnin = "Maur Grimtotem's corpse inside Ragefire Chasm. From the first major three-way junction, take the right-hand tunnel, follow it uphill toward the dead end, then enter the small side room on the left. Interact with Maur's corpse there.", map = { mapID = 1456, x = 0.7040, y = 0.3220, label = "Rahauro" } }
FDJ.FOREVER_QUEST_XP_FALLBACK[5722] = 880
FDJ.QUEST_PREREQ_CHAINS[1394] = {
    { id = 1149, name = "Test of Faith" },
    { id = 1150, name = "Test of Endurance" },
    { id = 1151, name = "Test of Strength" },
    { id = 1152, name = "Test of Lore" },
    { id = 1154, name = "Test of Lore" },
    { id = 6627, name = "Test of Lore" },
    { id = 1159, name = "Test of Lore" },
    { id = 1160, name = "Test of Lore" },
    { id = 6628, name = "Test of Lore" },
}
FDJ.QUEST_PREREQ_DETAILS[1149] = { level = 26, requires = 25, objective = "If you have faith, leap from the planks overlooking Thousand Needles.", pickup = "Dorn Plainstalker, Thousand Needles", turnin = "Dorn Plainstalker, Thousand Needles", map = { mapID = 1441, x = 0.538, y = 0.414, label = "Dorn Plainstalker — Thousand Needles", detail = "Dorn Plainstalker in Thousand Needles" } }
FDJ.FOREVER_QUEST_XP_FALLBACK[1149] = 1050
FDJ.QUEST_PREREQ_DETAILS[1150] = { level = 30, requires = 25, objective = "Bring Grenka's Claw to Dorn Plainstalker in Thousand Needles.", pickup = "Dorn Plainstalker, Thousand Needles", turnin = "Dorn Plainstalker, Thousand Needles", map = { mapID = 1441, x = 0.538, y = 0.414, label = "Dorn Plainstalker — Thousand Needles", detail = "Dorn Plainstalker in Thousand Needles" } }
FDJ.FOREVER_QUEST_XP_FALLBACK[1150] = 2450
FDJ.QUEST_PREREQ_DETAILS[1151] = { level = 30, requires = 25, objective = "Bring Fragments of Rok'Alim to Dorn Plainstalker in Thousand Needles.", pickup = "Dorn Plainstalker, Thousand Needles", turnin = "Dorn Plainstalker, Thousand Needles", map = { mapID = 1441, x = 0.538, y = 0.414, label = "Dorn Plainstalker — Thousand Needles", detail = "Dorn Plainstalker in Thousand Needles" } }
FDJ.FOREVER_QUEST_XP_FALLBACK[1151] = 3050
FDJ.QUEST_PREREQ_DETAILS[1152] = { level = 30, requires = 25, objective = "Find Braug Dimspirit near the entrance to Talondeep Path in Stonetalon Mountains.", pickup = "Dorn Plainstalker, Thousand Needles", turnin = "Braug Dimspirit, Talondeep Path, Stonetalon Mountains", suppressDescription = true, map = { mapID = 1441, x = 0.538, y = 0.414, label = "Dorn Plainstalker — Thousand Needles", detail = "Dorn Plainstalker in Thousand Needles" }, turninMap = { mapID = 1442, x = 0.786, y = 0.454, label = "Braug Dimspirit — Stonetalon Mountains", detail = "Near the entrance to Talondeep Path" } }
FDJ.FOREVER_QUEST_XP_FALLBACK[1152] = 1200
FDJ.QUEST_PREREQ_DETAILS[1154] = { level = 30, requires = 25, objective = "Find the Legacy of the Aspects and return it to Braug Dimspirit near the entrance to Talondeep Path in Stonetalon Mountains.", pickup = "Braug Dimspirit, Talondeep Path, Stonetalon Mountains", turnin = "Braug Dimspirit, Talondeep Path, Stonetalon Mountains", map = { mapID = 1442, x = 0.786, y = 0.454, label = "Braug Dimspirit — Stonetalon Mountains", detail = "Near the entrance to Talondeep Path" } }
FDJ.FOREVER_QUEST_XP_FALLBACK[1154] = 1850
-- loreaspects (2.1.1, M 20 Nov 2026 at Braug Dimspirit, Test of Lore in his
-- log and the arrow on Braug: "for test of lore, I need to get the legacy of
-- the aspects ... it is on Ashenvale ... I have to go through that passage
-- ... through that cave"): the book is at the bottom of the Dor'Danil Barrow
-- Den in southern Ashenvale (the quest's own text), its entrance at (76, 75)
-- (Warcraft Wiki; Questie's mark). While the book is still to find, the
-- arrow goes there (the walking net leads through the Talondeep Path
-- tunnel), then back to Braug. The French name is the game's own (Warcraft
-- Wiki); the arrow's line under it says where the book lies.
-- bookexact (M 20 Nov 2026 in the den's subzone, the arrow gone 230 yards
-- off: "we are still far from the book ... the arrow should not disappear
-- right now"): one thing at one place, not an area to clear (exact), to pick
-- up (pickUp: "Pick it up" and the loot bag at it), where Questie marks the
-- book (75.8, 74.2).
FDJ.QUEST_PREREQ_DETAILS[1154].objectiveMap = { mapID = 1440, x = 0.755, y = 0.745, label = "Dor'Danil Barrow Den \226\128\148 Ashenvale", noteKey = "ARROW_ASPECTS_BOOK",
    markerType = "location", exact = true, pickUp = true }
-- denway (2.1.1, M 20 Nov 2026 in front of the den's door, the arrow pointing
-- left at the book under the hill: "it should tell me to go in"): the book
-- (object 20725) lies at 75.5, 74.45 (Wowhead Forever), at the bottom of the
-- den; its comments: "Go to /way 75.9 75.3, and go down", "go to the bottom,
-- make a left, keep going straight", "the leftmost large circular space".
-- The way in: a walking router on the Forever client's Kalimdor
-- maps (the navigation grid, run offline from the door at 75.9, 75.3 to
-- the den's lowest floor under the book): in at the door, east along the
-- tunnel and down round the east side, then west through the bottom rooms
-- (415 yards). Each point is passed only by walking by it (4 yards), so the
-- ground above the den does not count; keep: led along it even within 60
-- yards of the book. The line under the arrow says which part it is.
do
    FDJ.ARROW_VIAS = FDJ.ARROW_VIAS or {}
    local IN, DOWN, LEFT = "Into the barrow den", "Down to the bottom", "Left at the bottom, to the book in the big room"
    -- (labelNear: the line only near the den, not from Stonetalon)
    local function P(x, y, label) return { mapID = 1440, x = x, y = y, label = label, keep = true, labelNear = 150 } end
    FDJ.ARROW_VIAS[string.format("%s|%.4f|%.4f", "1440", 0.755, 0.745)] = { reach = 4, leg = 3,
        P(0.7590, 0.7530, IN), P(0.7626, 0.7501, IN), P(0.7648, 0.7490, IN), P(0.7699, 0.7490, IN),
        P(0.7706, 0.7480, DOWN), P(0.7756, 0.7480, DOWN), P(0.7793, 0.7523, DOWN), P(0.7822, 0.7534, DOWN),
        P(0.7843, 0.7501, DOWN), P(0.7843, 0.7447, DOWN), P(0.7822, 0.7415, DOWN), P(0.7807, 0.7415, DOWN),
        P(0.7691, 0.7425, LEFT), P(0.7670, 0.7371, LEFT), P(0.7648, 0.7328, LEFT), P(0.7605, 0.7328, LEFT),
        P(0.7590, 0.7339, LEFT), P(0.7576, 0.7371, LEFT), P(0.7569, 0.7436, LEFT), P(0.7554, 0.7458, LEFT),
    }
    local LINES = {
        deDE = { "In den Grabhügel hinein", "Ganz nach unten", "Unten links, zum Buch im großen Raum" },
        frFR = { "Entrez dans le refuge", "Descendez tout en bas", "En bas à gauche, jusqu'au livre dans la grande salle" },
        esES = { "Entra en el túmulo", "Baja hasta el fondo", "Abajo a la izquierda, hasta el libro en la sala grande" },
        itIT = { "Entra nel tumulo", "Scendi fino in fondo", "In fondo a sinistra, fino al libro nella sala grande" },
        ptBR = { "Entre no túmulo", "Desça até o fundo", "Embaixo à esquerda, até o livro na sala grande" },
        ruRU = { "Войдите в курган", "Спуститесь в самый низ", "Внизу налево, к книге в большом зале" },
        koKR = { "굴 안으로 들어가세요", "맨 아래까지 내려가세요", "아래에서 왼쪽, 큰 방의 책으로" },
        zhCN = { "进入巢穴", "下到最底层", "到底后向左，前往大厅里的书" },
        zhTW = { "進入巢穴", "下到最底層", "到底後向左，前往大廳裡的書" },
    }
    FDJ.ContentLocales = FDJ.ContentLocales or {}
    for lang, lines in pairs(LINES) do
        local content = FDJ.ContentLocales[lang] or {}
        FDJ.ContentLocales[lang] = content
        content.places = content.places or {}
        for i, english in ipairs({ IN, DOWN, LEFT }) do
            if content.places[english] == nil then content.places[english] = lines[i] end
        end
    end
end
do
    FDJ.ContentLocales = FDJ.ContentLocales or {}
    local fr = FDJ.ContentLocales.frFR or {}
    FDJ.ContentLocales.frFR = fr
    fr.places = fr.places or {}
    if fr.places["Dor'Danil Barrow Den"] == nil then fr.places["Dor'Danil Barrow Den"] = "Refuge des saisons de Dor'danil" end
    -- (Ashenvale's own name where the zone list has none yet)
    for lang, name in pairs({ koKR = "잿빛 골짜기", zhCN = "灰谷", zhTW = "梣谷" }) do
        local content = FDJ.ContentLocales[lang] or {}
        FDJ.ContentLocales[lang] = content
        content.places = content.places or {}
        if content.places["Ashenvale"] == nil then content.places["Ashenvale"] = name end
    end
    local strings = {
        enUS = "The book is at the bottom of the barrow den, on a stone podium",
        deDE = "Das Buch liegt ganz unten im Grabhügel, auf einem Steinpodest",
        frFR = "Le livre est tout en bas du refuge, sur un petit socle de pierre",
        esES = "El libro está al fondo del túmulo, sobre un pedestal de piedra",
        itIT = "Il libro è in fondo al tumulo, su un piedistallo di pietra",
        ptBR = "O livro fica no fundo do túmulo, sobre um pedestal de pedra",
        ruRU = "Книга в самом низу кургана, на каменном постаменте",
        koKR = "책은 굴 맨 아래쪽 돌 받침대 위에 있습니다",
        zhCN = "书在巢穴最底层的石台上",
        zhTW = "書在巢穴最底層的石台上",
    }
    strings.esMX = strings.esES
    for locale, text in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t and t.ARROW_ASPECTS_BOOK == nil then t.ARROW_ASPECTS_BOOK = text end
    end
end
FDJ.QUEST_PREREQ_DETAILS[6627] = { level = 30, requires = 25, objective = "Answer Braug Dimspirit's question successfully and then speak to him again.", pickup = "Braug Dimspirit, Talondeep Path, Stonetalon Mountains", turnin = "Braug Dimspirit, Talondeep Path, Stonetalon Mountains", warning = "ANSWER: Neltharion", map = { mapID = 1442, x = 0.786, y = 0.454, label = "Braug Dimspirit — Stonetalon Mountains", detail = "Near the entrance to Talondeep Path" } }
FDJ.FOREVER_QUEST_XP_FALLBACK[6627] = 245
-- keyshortcut (2.1.1, M 20 Nov 2026: "it's not true that the key unlocks
-- the upper part of the dungeon, because you can do it even without the
-- key ... the key allows a shortcut to the last boss"): Key Ingredients'
-- warning (Data/Dungeons.lua) in every language
do
    FDJ.ContentLocales = FDJ.ContentLocales or {}
    local KEY = "The key from this quest opens a shortcut to the last boss."
    for lang, text in pairs({
        deDE = "Der Schl\195\188ssel aus dieser Quest \195\182ffnet eine Abk\195\188rzung zum letzten Boss.",
        frFR = "La cl\195\169 de cette qu\195\170te ouvre un raccourci vers le dernier boss.",
        esES = "La llave de esta misi\195\179n abre un atajo hacia el \195\186ltimo jefe.",
        itIT = "La chiave di questa missione apre una scorciatoia verso l'ultimo boss.",
        ptBR = "A chave desta miss\195\163o abre um atalho para o \195\186ltimo chefe.",
        ruRU = "\208\154\208\187\209\142\209\135 \208\184\208\183 \209\141\209\130\208\190\208\179\208\190 \208\183\208\176\208\180\208\176\208\189\208\184\209\143 \208\190\209\130\208\186\209\128\209\139\208\178\208\176\208\181\209\130 \208\186\208\190\209\128\208\190\209\130\208\186\208\184\208\185 \208\191\209\131\209\130\209\140 \208\186 \208\191\208\190\209\129\208\187\208\181\208\180\208\189\208\181\208\188\209\131 \208\177\208\190\209\129\209\129\209\131.",
        koKR = "\236\157\180 \237\128\152\236\138\164\237\138\184\236\157\152 \236\151\180\236\135\160\235\161\156 \235\167\136\236\167\128\235\167\137 \236\154\176\235\145\144\235\168\184\235\166\172\236\151\144\234\178\140 \234\176\128\235\138\148 \236\167\128\235\166\132\234\184\184\236\157\180 \236\151\180\235\166\189\235\139\136\235\139\164.",
        zhCN = "\230\173\164\228\187\187\229\138\161\232\142\183\229\190\151\231\154\132\233\146\165\229\140\153\229\143\175\228\187\165\230\137\147\229\188\128\233\128\154\229\190\128\230\156\128\229\144\142\228\184\128\228\184\170\233\166\150\233\162\134\231\154\132\230\141\183\229\190\132\227\128\130",
        zhTW = "\230\173\164\228\187\187\229\139\153\231\141\178\229\190\151\231\154\132\233\145\176\229\140\153\229\143\175\228\187\165\230\137\147\233\150\139\233\128\154\229\190\128\230\156\128\229\190\140\228\184\128\229\128\139\233\166\150\233\160\152\231\154\132\230\141\183\229\190\145\227\128\130",
    }) do
        local content = FDJ.ContentLocales[lang] or {}
        FDJ.ContentLocales[lang] = content
        content.places = content.places or {}
        if content.places[KEY] == nil then content.places[KEY] = text end
    end
end
-- zalfanpin (2.1.1): Zalfan Moonshadow's own name on the dungeon map, in
-- the game's languages (Wowhead Forever's; German and Italian keep it)
do
    FDJ.ContentLocales = FDJ.ContentLocales or {}
    for lang, name in pairs({ frFR = "Zalfan Lunombre", esES = "Zalfan Umbraluna", ptBR = "Zalfan Umbraluna",
        ruRU = "\208\151\208\176\208\187\209\132\208\176\208\189 \208\162\208\181\208\189\209\140 \208\155\209\131\208\189\209\139",
        koKR = "\236\158\152\237\140\144 \235\172\184\236\132\128\235\143\132",
        zhCN = "\230\137\142\229\176\148\229\135\161\194\183\230\156\136\229\189\177",
        zhTW = "\232\150\169\231\136\190\229\135\161\226\128\167\230\156\136\229\189\177" }) do
        local content = FDJ.ContentLocales[lang] or {}
        FDJ.ContentLocales[lang] = content
        content.places = content.places or {}
        if content.places["Zalfan Moonshadow"] == nil then content.places["Zalfan Moonshadow"] = name end
    end
end
-- loreanswer (2.1.1, M 20 Nov 2026 at Braug Dimspirit, the last Test of Lore
-- in his log: "make sure the arrow says to pick Neltharion as the answer"):
-- while the question is not answered, the arrow leads to Braug with the
-- answer in its orange line; answered, it is the usual hand-in.
FDJ.QUEST_PREREQ_DETAILS[6627].objectiveMap = { mapID = 1442, x = 0.786, y = 0.454, label = "Braug Dimspirit \226\128\148 Stonetalon Mountains", targetName = "Braug Dimspirit", noteKey = "ARROW_LORE_ANSWER", exact = true }
do
    local strings = {
        enUS = "Answer: Neltharion",
        deDE = "Antwort: Neltharion",
        frFR = "R\195\169ponse : Neltharion",
        esES = "Respuesta: Neltharion",
        itIT = "Risposta: Neltharion",
        ptBR = "Resposta: Neltharion",
        ruRU = "\208\158\209\130\208\178\208\181\209\130: \208\157\208\181\208\187\209\130\208\176\209\128\208\184\208\190\208\189",
        koKR = "\236\160\149\235\139\181: \235\132\172\237\131\128\235\166\172\236\152\168",
        zhCN = "\231\173\148\230\161\136\239\188\154\229\165\136\232\144\168\233\135\140\229\165\165",
        zhTW = "\231\173\148\230\161\136\239\188\154\229\165\136\232\150\169\233\135\140\229\165\167",
    }
    strings.esMX = strings.esES
    for locale, text in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t and t.ARROW_LORE_ANSWER == nil then t.ARROW_LORE_ANSWER = text end
    end
end
FDJ.QUEST_PREREQ_DETAILS[1159] = { level = 30, requires = 25, objective = "Find Parqual Fintallas in Undercity.", pickup = "Braug Dimspirit, Talondeep Path, Stonetalon Mountains", turnin = "Parqual Fintallas, Undercity", map = { mapID = 1442, x = 0.786, y = 0.454, label = "Braug Dimspirit — Stonetalon Mountains", detail = "Near the entrance to Talondeep Path" } }
FDJ.FOREVER_QUEST_XP_FALLBACK[1159] = 1200
-- The Library step of the chain: the book is inside Scarlet Monastery: Library.
FDJ.QUEST_PREREQ_DETAILS[1160] = { level = 36, requires = 25, objective = "Find The Beginnings of the Undead Threat and return it to Parqual Fintallas in Undercity.", pickup = "Parqual Fintallas, Undercity", turnin = "Parqual Fintallas, Undercity", description = "The book is inside Scarlet Monastery: Library.", map = { mapID = 1458, x = 0.576, y = 0.652, label = "Parqual Fintallas — Undercity", detail = "Parqual Fintallas in Undercity" } }
-- loreinside (2.1.1, M 20 Nov 2026 on its page: "why is it not saying
-- dungeon step ... the book is inside"): the book is in the Library, so the
-- step is done inside (its text names the dungeon only in its note).
FDJ.QUEST_PREREQ_DETAILS[1160].objectiveInDungeon = true
FDJ.FOREVER_QUEST_XP_FALLBACK[1160] = 2100
FDJ.QUEST_PREREQ_DETAILS[6628] = { level = 30, requires = 25, objective = "Answer Parqual Fintallas' question successfully and then speak to him again.", pickup = "Parqual Fintallas, Undercity", turnin = "Parqual Fintallas, Undercity", warning = "ANSWER: Ner'zhul", map = { mapID = 1458, x = 0.576, y = 0.652, label = "Parqual Fintallas — Undercity", detail = "Parqual Fintallas in Undercity" } }



-- City of Dalaran (Alliance): Heart of Disruption follows the introductory
-- An Alarming Request breadcrumb. Starving Arcane (same Image of Archmage
-- Modera) also needs An Alarming Request first.
FDJ.QUEST_PREREQ_CHAINS[92458] = {
    { id = 92432, name = "An Alarming Request" },
}
FDJ.QUEST_PREREQ_CHAINS[92457] = {
    { id = 92432, name = "An Alarming Request" },
}
FDJ.QUEST_PREREQ_DETAILS[92432] = {
    level = 33,
    requires = 30,
    objective = "Report to the Image of Archmage Modera near the City of Dalaran.",
    pickup = "Emissary Jacques, Southshore, Hillsbrad Foothills",
    turnin = "Image of Archmage Modera, Lordamere Lake near Dalaran",
    -- Start pin read off Wowhead's Hillsbrad Foothills map (approximate).
    map = { mapID = 1424, x = 0.484, y = 0.602, label = "Emissary Jacques — Southshore", detail = "Emissary Jacques in Southshore, Hillsbrad Foothills" },
    description = "Introductory quest leading to Heart of Disruption and Starving Arcane.",
}
FDJ.FOREVER_QUEST_XP_FALLBACK[92457] = 9400
FDJ.FOREVER_QUEST_XP_FALLBACK[92458] = 9400
FDJ.QUEST_SHAREABILITY_AUDIT[92432] = true
FDJ.QUEST_SHAREABILITY_AUDIT[92457] = true
FDJ.QUEST_SHAREABILITY_AUDIT[92458] = false


-- City of Dalaran (Horde): required attunement chain.
-- Prison Break In and Key to the City can both be picked up from Magus Wordeen
-- Voidglare in Tarren Mill. Dalaran Patrols follows Prison Break In. Once the
-- Magus quests are complete, Blood in the Streets leads to Heart of Disruption.
-- Keeper Bel'varil's Stone Tokens -> Bracers of Binding branch is useful to do
-- in the same area but is NOT required for the Dalaran attunement.
FDJ.QUEST_PREREQ_CHAINS[96984] = {
    { id = 544, name = "Prison Break In" },
    { id = 93680, name = "Key to the City", shareNormally = true },
    { id = 545, name = "Dalaran Patrols" },
    { id = 92434, name = "Blood in the Streets" },
}

FDJ.QUEST_PREREQ_DETAILS[544] = {
    level = 34,
    requires = 30,
    objective = "Find the four Forsaken traitors at the Lordamere Internment Camp, recover their Bloodstone artifacts, and return to Magus Wordeen Voidglare.",
    pickup = "Magus Wordeen Voidglare, Tarren Mill, Hillsbrad Foothills",
    turnin = "Magus Wordeen Voidglare, Tarren Mill, Hillsbrad Foothills",
    note = "Pick up Key to the City from Magus Wordeen Voidglare at the same time.",
    map = { mapID = 1424, x = 0.615, y = 0.207, label = "Magus Wordeen Voidglare — Tarren Mill", detail = "Inside the building in Tarren Mill" },
}
FDJ.FOREVER_QUEST_XP_FALLBACK[544] = 3350

FDJ.QUEST_PREREQ_DETAILS[93680] = {
    level = 33,
    requires = 30,
    objective = "Acquire the Grimy Key for Magus Wordeen Voidglare in Tarren Mill.",
    requiredItems = {
        {279469, "Grimy Key", 1, "Found while investigating the Dalaran forces around the Lordamere Internment Camp"},
    },
    pickup = "Magus Wordeen Voidglare, Tarren Mill, Hillsbrad Foothills",
    turnin = "Magus Wordeen Voidglare, Tarren Mill, Hillsbrad Foothills",
    note = "This quest can be accepted alongside Prison Break In.",
    map = { mapID = 1424, x = 0.615, y = 0.207, label = "Magus Wordeen Voidglare — Tarren Mill", detail = "Inside the building in Tarren Mill" },
}

FDJ.QUEST_PREREQ_DETAILS[545] = {
    level = 35,
    requires = 30,
    objective = "Kill 6 Dalaran Summoners and 12 Elemental Slaves, then return to Magus Wordeen Voidglare in Tarren Mill.",
    pickup = "Magus Wordeen Voidglare, Tarren Mill, Hillsbrad Foothills",
    turnin = "Magus Wordeen Voidglare, Tarren Mill, Hillsbrad Foothills",
    description = "Available after completing Prison Break In.",
    map = { mapID = 1424, x = 0.615, y = 0.207, label = "Magus Wordeen Voidglare — Tarren Mill", detail = "Inside the building in Tarren Mill" },
}
FDJ.FOREVER_QUEST_XP_FALLBACK[545] = 2050

FDJ.QUEST_PREREQ_DETAILS[92434] = {
    level = 34,
    requires = 30,
    objective = "Find a way into Dalaran along Lordamere Lake.",
    pickup = "Magus Wordeen Voidglare, Tarren Mill, Hillsbrad Foothills",
    turnin = "Image of Archmage Modera, Lordamere Lake near Dalaran",
    providedItem = {279469, "Grimy Key", 1, "Provided for Blood in the Streets"},
    note = "Requires Magus Wordeen Voidglare's Dalaran quests. Stone Tokens and Bracers of Binding from Keeper Bel'varil are optional and are not required for attunement.",
    map = { mapID = 1424, x = 0.615, y = 0.207, label = "Magus Wordeen Voidglare — Tarren Mill", detail = "Inside the building in Tarren Mill" },
    turninMap = { mapID = 1416, x = 0.077, y = 0.588, label = "Image of Archmage Modera — Lordamere Lake near Dalaran", detail = "Outside Dalaran near Lordamere Lake" },
}
FDJ.FOREVER_QUEST_XP_FALLBACK[92434] = 270
FDJ.FOREVER_QUEST_XP_FALLBACK[96984] = 9400

FDJ.QUEST_SHAREABILITY_AUDIT[544] = true
FDJ.QUEST_SHAREABILITY_AUDIT[93680] = true
FDJ.QUEST_SHAREABILITY_AUDIT[545] = true
FDJ.QUEST_SHAREABILITY_AUDIT[92434] = false
FDJ.QUEST_SHAREABILITY_AUDIT[96984] = false

-- Starter pins from the starter-location guide for steps defined in this file.
for _, id in ipairs({ 1652, 1653 }) do
    local details = FDJ.QUEST_PREREQ_DETAILS and FDJ.QUEST_PREREQ_DETAILS[id]
    if details and not details.map and FDJ.QUEST_START_MAPS and FDJ.QUEST_START_MAPS[id] then
        details.map = FDJ.QUEST_START_MAPS[id]
    end
end

-- Franclorn disclaimer (Dark Iron Legacy step), per language.
do
    local t = {
        deDE = "Ihr müsst tot sein, um mit ihm zu sprechen. Er befindet sich im Schwarzfels, in einem Raum, an dem Ihr auf dem Weg die Kette hinab nach BRD vorbeikommt.",
        frFR = "Vous devez être mort pour lui parler. Il se trouve dans le mont Rochenoire, dans une salle que vous longez en descendant la chaîne vers les Profondeurs de Rochenoire.",
        esES = "Tienes que estar muerto para hablar con él. Está en la Montaña Roca Negra, en una sala junto a la cadena que baja a las Profundidades de Roca Negra.",
        itIT = "Devi essere morto per parlare con lui. Si trova nella Montagna Rocconera, in una stanza lungo la catena che scende verso le Profondità di Rocconera.",
        ptBR = "Você precisa estar morto para falar com ele. Ele fica na Montanha Rocha Negra, numa sala ao longo da corrente que desce até as Profundezas Rocha Negra.",
        ruRU = "Чтобы поговорить с ним, нужно быть мертвым. Он находится в Черной горе, в комнате у цепи, по которой спускаются к Глубинам Черной горы.",
        koKR = "죽은 상태에서만 대화할 수 있습니다. 검은바위 산에서 검은바위 나락으로 내려가는 사슬 길 옆 방에 있습니다.",
        zhCN = "你必须处于死亡状态才能与他交谈。他在黑石山中，位于沿锁链走向黑石深渊途中的一个房间里。",
        zhTW = "你必須處於死亡狀態才能與他交談。他在黑石山中，位於沿鎖鏈走向黑石深淵途中的一個房間裡。",
    }
    FDJ.ContentLocales = FDJ.ContentLocales or {}
    for loc, text in pairs(t) do
        local c = FDJ.ContentLocales[loc] or {}
        FDJ.ContentLocales[loc] = c
        c.quests = c.quests or {}
        c.quests[3801] = c.quests[3801] or {}
        c.quests[3801].warning = text
    end
end
-- BEGIN roguejobs
-- Rogue jobs from C (the Dead Drop beside Pyrewood Village). The journal entries are
-- the payment quests; the dungeon jobs are their chain steps. The Eye of Bhossca is
-- only offered after the whole Horn of Xelthos chain.
do
    local DEAD_DROP = {"Dead Drop", "Interface\\Icons\\INV_Box_02", "A chest in a hut beside Pyrewood Village, Silverpine Forest"}
    local function DropMap() return { mapID = 1421, x = 0.471, y = 0.711, label = "Dead Drop — Pyrewood Village", detail = "A chest in a hut beside Pyrewood Village" } end
    local WHERE = "Dead Drop, Pyrewood Village, Silverpine Forest"
    local SOLO = "Solo job: you must do it alone, outside any group."
    FDJ.QUEST_PREREQ_CHAINS[78307] = {
        { id = 78261, name = "The Horn of Xelthos" },
    }
    FDJ.QUEST_PREREQ_CHAINS[78699] = {
        { id = 78261, name = "The Horn of Xelthos" },
        { id = 78307, name = "The Horn of Xelthos" },
        { id = 78676, name = "The Eye of Bhossca" },
    }
    FDJ.QUEST_PREREQ_DETAILS[78261] = {
        level = 23, requires = 20,
        warning = SOLO,
        objective = "Find The Horn of Xelthos inside of Shadowfang Keep. Then, return it to C's dead drop near Pyrewood Village. You must complete the job alone.",
        requiredItems = {
            {210186, "Breaching Charge", 1, "From Veenix, Stonetalon Mountains, for a Venture Co. Work Order. Blows open the courtyard gate of Shadowfang Keep", map = { mapID = 1442, x = 0.582, y = 0.517, label = "Veenix — Stonetalon Mountains", detail = "From Veenix, Stonetalon Mountains, for a Venture Co. Work Order. Blows open the courtyard gate of Shadowfang Keep" }},
            {210209, "Twin Key", 1, "Combine the Sister's Half-Key and the Brother's Half-Key, picked from the sister (dining hall) and the brother (upstairs) in Shadowfang Keep. Combining them breaks stealth"},
            {210183, "Horn of Xelthos", 1, "Found in: a locked chest in the courtyard stables of Shadowfang Keep. Open it with the Twin Key"},
        },
        startObject = DEAD_DROP, pickup = WHERE, turnin = WHERE, map = DropMap(),
    }
    FDJ.QUEST_PREREQ_DETAILS[78307] = {
        level = 23, requires = 20,
        objective = "Collect C's payment from the Dead Drop near Pyrewood Village.",
        description = "Offered after C's next letter reaches you in a capital city.",
        startObject = DEAD_DROP, pickup = WHERE, turnin = WHERE, map = DropMap(),
    }
    FDJ.QUEST_PREREQ_DETAILS[78676] = {
        level = 35, requires = 25,
        warning = SOLO,
        objective = "Find The Eye of Bhossca inside of the Scarlet Monastery. Then, return it to C's dead drop near Pyrewood Village. You must complete the job alone.",
        requiredItems = {
            {210955, "Scarlet Initiate's Uniform", 1, "Found in: the Supply Locker in the stables behind the Scarlet Monastery. Wear it to pass the Scarlet Crusade"},
            {210963, "Scryer's Key", 1, "Pick pocket a Scarlet Scryer in the first big room of the Scarlet Monastery Graveyard"},
            {210967, "Confidential Message", 1, "Found in: the Personal Letterbox in Arcanist Doan's room, Scarlet Monastery Library. Open it with the Scryer's Key"},
            {210968, "Reliquary Key", 1, "Found in: the Stone Coffer in the mausoleum on the north side of the Scarlet Monastery Graveyard. It opens after you sit on both benches between the two statues"},
            {210953, "Eye of Bhossca", 1, "Found in: the Padlocked Reliquary in the first small room on the left of the Scarlet Monastery Library. Open it with the Reliquary Key"},
        },
        startObject = DEAD_DROP, pickup = WHERE, turnin = WHERE, map = DropMap(),
    }
    FDJ.QUEST_PREREQ_DETAILS[78699] = {
        level = 35, requires = 25,
        objective = "Collect C's payment from the Dead Drop near Pyrewood Village.",
        description = "Offered after C's next letter reaches you in a capital city.",
        startObject = DEAD_DROP, pickup = WHERE, turnin = WHERE, map = DropMap(),
    }
    FDJ.PREREQ_REWARD_ITEMS_FALLBACK[78307] = { items = { {277210, "Pyrewood Signet Ring", 3} }, choice = false }
    FDJ.PREREQ_REWARD_ITEMS_FALLBACK[78699] = { items = { {277246, "Ruby-Adorned Blade", 3} }, choice = false }
    FDJ.PREREQ_REWARD_MONEY_FALLBACK[78307] = 3000
    FDJ.PREREQ_REWARD_MONEY_FALLBACK[78699] = 7500
    FDJ.FOREVER_QUEST_XP_FALLBACK[78261] = 1850
    FDJ.FOREVER_QUEST_XP_FALLBACK[78307] = 6900
    FDJ.FOREVER_QUEST_XP_FALLBACK[78676] = 3450
    FDJ.FOREVER_QUEST_XP_FALLBACK[78699] = 6900
    -- Solo jobs started from a world object: they cannot be shared.
    for _, id in ipairs({ 78261, 78307, 78676, 78699 }) do
        FDJ.QUEST_SHAREABILITY_AUDIT[id] = false
    end
end
-- END roguejobs

-- BEGIN roguetalisman
-- The Talisman of Kazdor (Zul'Farrak, rogues, 2.1.0, M 19 Nov 2026): how to
-- unlock it. The Manor, Ravenholdt, C's jobs (the IDs the journal already
-- has for The Horn of Xelthos and The Eye of Bhossca), then, at level 45,
-- Fahrad's letter in a capital city's mailbox and Fool Me Twice at
-- Ravenholdt Manor. Levels, texts and XP: Wowhead Forever (quests 6681,
-- 80526, 80411) and the Forever database (6681: started by the Elegant
-- Letter, item 17126; Fahrad, NPC 6707, at 84.5, 80.3 in Alterac Mountains).
do
    local function Fahrad() return { mapID = 1416, x = 0.845, y = 0.803, label = "Fahrad — Ravenholdt Manor", targetName = "Fahrad" } end
    local AT_FAHRAD = "Fahrad, Ravenholdt Manor, Alterac Mountains"
    FDJ.QUEST_PREREQ_CHAINS[80411] = {
        { id = 6681, name = "The Manor, Ravenholdt" },
        { id = 78261, name = "The Horn of Xelthos" },
        { id = 78307, name = "The Horn of Xelthos" },
        { id = 78676, name = "The Eye of Bhossca" },
        { id = 78699, name = "The Eye of Bhossca" },
        { id = 80526, name = "Fool Me Twice" },
    }
    FDJ.QUEST_PREREQ_DETAILS[6681] = {
        level = 24, requires = 24,
        objective = "Take the Seal of Ravenholdt to Fahrad at Ravenholdt Manor, hidden away in the hills of Hillsbrad.",
        -- (letterfix, M 19 Nov 2026, "follow the comments": Alliance from
        -- Mathias Shaw only, and Detect Traps for the trap on the way in:
        -- Wowhead Forever's comments, 17 to 19 Nov 2026)
        warning = "Train Detect Traps first: walking past the trapped chest in the cave passage into the manor completes the test (Fahrad teaches it too).",
        description = "Get the letter that starts this quest. Horde: a rogue trainer's option \"May I have it, please.\" Alliance: Mathias Shaw in Stormwind.",
        startItem = {17126, "Elegant Letter", 1, "Horde: from a rogue trainer (\"May I have it, please.\"). Alliance: from Mathias Shaw, Stormwind"},
        pickup = "Elegant Letter, from a rogue trainer",
        turnin = AT_FAHRAD, turninMap = Fahrad(),
    }
    FDJ.QUEST_PREREQ_DETAILS[80526] = {
        level = 50, requires = 45,
        objective = "Speak to Fahrad when you're ready to hear his plan.",
        description = "At level 45, with C's jobs done, go to a capital city: Fahrad's letter in the mailbox sends you to Ravenholdt Manor. Accept the quest, speak to Fahrad again and hand it in to him.",
        pickup = AT_FAHRAD, turnin = AT_FAHRAD, map = Fahrad(), turninMap = Fahrad(),
    }
    FDJ.FOREVER_QUEST_XP_FALLBACK[6681] = 1950
    FDJ.FOREVER_QUEST_XP_FALLBACK[80526] = 470
    FDJ.FOREVER_QUEST_XP_FALLBACK[80411] = 4700
    -- Not sharable (Wowhead Forever).
    for _, id in ipairs({ 6681, 80526, 80411 }) do
        FDJ.QUEST_SHAREABILITY_AUDIT[id] = false
    end
end
-- END roguetalisman

-- BEGIN recipechain
-- The New Plague (Horde, Ruins of Lordaeron): Theodore Griffs now only offers it after
-- the whole A Recipe For Death chain (Apothecary Renferrel, The Sepulcher, and Master
-- Apothecary Faranell, Undercity). The steps live only inside the chain.
FDJ.QUEST_PREREQ_CHAINS[95216] = {
    { id = 447, name = "A Recipe For Death" },
    { id = 450, name = "A Recipe For Death" },
    { id = 451, name = "A Recipe For Death" },
}
FDJ.QUEST_PREREQ_DETAILS[447] = {
    level = 12, requires = 9,
    objective = "Collect 6 Grizzled Bear Hearts and 6 samples of Skittering Blood and deliver them to Master Apothecary Faranell in the Undercity.",
    pickup = "Apothecary Renferrel, The Sepulcher, Silverpine Forest", turnin = "Master Apothecary Faranell, Undercity",
    map = { mapID = 1421, x = 0.428, y = 0.409, label = "Apothecary Renferrel — The Sepulcher", targetName = "Apothecary Renferrel" },
    turninMap = { mapID = 1458, x = 0.488, y = 0.693, label = "Master Apothecary Faranell — Undercity", targetName = "Master Apothecary Faranell" },
    requiredItems = {
        {3253, "Grizzled Bear Heart", 1, "Dropped by Ferocious Grizzled Bears and Giant Grizzled Bears all over Silverpine Forest"},
        {3254, "Skittering Blood", 1, "Dropped by Moss Stalkers and Mist Creepers in the Skittering Dark, north-west of the Sepulcher (around 35, 12)", map = { markerType = "location", mapID = 1421, x = 0.355, y = 0.120, label = "Moss Stalkers and Mist Creepers", detail = "Dropped by Moss Stalkers and Mist Creepers in the Skittering Dark, north-west of the Sepulcher (around 35, 12)" }},
    },
}
FDJ.QUEST_PREREQ_DETAILS[450] = {
    level = 15, requires = 9,
    warning = "Group quest: the inn is in Pyrewood Village, among hostile villagers.",
    objective = "Retrieve Apothecary Berard's journal from Pyrewood Village and take it to Apothecary Renferrel at the Sepulcher.",
    pickup = "Master Apothecary Faranell, Undercity", turnin = "Apothecary Renferrel, The Sepulcher, Silverpine Forest",
    map = { mapID = 1458, x = 0.488, y = 0.693, label = "Master Apothecary Faranell — Undercity", targetName = "Master Apothecary Faranell" },
    turninMap = { mapID = 1421, x = 0.428, y = 0.409, label = "Apothecary Renferrel — The Sepulcher", targetName = "Apothecary Renferrel" },
    requiredItems = {
        {3255, "Berard's Journal", 1, "Found on Berard's Bookshelf in the Pyrewood Village inn (Silverpine Forest 43, 73)", map = { markerType = "location", mapID = 1421, x = 0.430, y = 0.732, label = "Berard's Bookshelf — Pyrewood Village", detail = "Found on Berard's Bookshelf in the Pyrewood Village inn (Silverpine Forest 43, 73)", pickUp = true }},
    },
}
FDJ.QUEST_PREREQ_DETAILS[451] = {
    level = 18, requires = 9,
    objective = "Bring 6 samples of Lake Creeper Moss, 6 samples of Lake Skulker Moss and a Hardened Tumor to Master Apothecary Faranell in the Undercity.",
    pickup = "Apothecary Renferrel, The Sepulcher, Silverpine Forest", turnin = "Master Apothecary Faranell, Undercity",
    map = { mapID = 1421, x = 0.428, y = 0.409, label = "Apothecary Renferrel — The Sepulcher", targetName = "Apothecary Renferrel" },
    turninMap = { mapID = 1458, x = 0.488, y = 0.693, label = "Master Apothecary Faranell — Undercity", targetName = "Master Apothecary Faranell" },
    requiredItems = {
        {3256, "Lake Skulker Moss", 1, "Dropped by Lake Skulkers and Elder Lake Skulkers on the Dawning Isles in Lordamere Lake (around 72, 35)", map = { markerType = "location", mapID = 1421, x = 0.720, y = 0.355, label = "Lake Skulkers — Lordamere Lake", detail = "Dropped by Lake Skulkers and Elder Lake Skulkers on the Dawning Isles in Lordamere Lake (around 72, 35)" }},
        {3257, "Lake Creeper Moss", 1, "Dropped by Lake Creepers and Elder Lake Creepers on the Dawning Isles in Lordamere Lake (around 77, 25)", map = { markerType = "location", mapID = 1421, x = 0.770, y = 0.250, label = "Lake Creepers — Lordamere Lake", detail = "Dropped by Lake Creepers and Elder Lake Creepers on the Dawning Isles in Lordamere Lake (around 77, 25)" }},
        {3258, "Hardened Tumor", 1, "Rare drop from Vile Fin murlocs around Lordamere Lake; the higher-level ones on the Dawning Isles and on the south-west shore behind Ambermill are the best bet", map = { markerType = "location", mapID = 1421, x = 0.785, y = 0.315, label = "Vile Fin murlocs — Lordamere Lake", detail = "Rare drop from Vile Fin murlocs around Lordamere Lake; the higher-level ones on the Dawning Isles and on the south-west shore behind Ambermill are the best bet" }},
    },
}
FDJ.PREREQ_REWARD_ITEMS_FALLBACK[447] = { items = { {3448, "Senggin Root", 1} }, choice = false }
-- 451: choose the concoction or the cloak; the two potions come with either.
FDJ.PREREQ_REWARD_ITEMS_FALLBACK[451] = { items = { {3451, "Nightglow Concoction", 2}, {3582, "Acidproof Cloak", 2} }, choice = true,
    also = { {2458, "Elixir of Minor Fortitude", 1}, {2459, "Swiftness Potion", 1} } }
FDJ.PREREQ_REWARD_MONEY_FALLBACK[447] = 500
FDJ.PREREQ_REWARD_MONEY_FALLBACK[450] = 1400
FDJ.FOREVER_QUEST_XP_FALLBACK[447] = 900
FDJ.FOREVER_QUEST_XP_FALLBACK[450] = 1350
FDJ.FOREVER_QUEST_XP_FALLBACK[451] = 2050
FDJ.QUEST_SHAREABILITY_AUDIT[447] = true
FDJ.QUEST_SHAREABILITY_AUDIT[450] = true
-- END recipechain

-- BEGIN rearguard
-- The Wrath of Rath'mael (Horde, Ruins of Lordaeron): Deathguard Kristof now only offers it
-- after the Rear Guard Patrol chain from Deathguard Linnea (her camp south-east of Brill).
FDJ.QUEST_PREREQ_CHAINS[92422] = {
    { id = 356, name = "Rear Guard Patrol" },
    { id = 99156, name = "Rear Guard Patrol" },
}
FDJ.QUEST_PREREQ_DETAILS[356] = {
    level = 11, requires = 6,
    objective = "Kill 8 Bleeding Horrors and 8 Wandering Spirits, then report back to Linnea at her camp.",
    description = "Both are at the Balnir Farmstead, east of Linnea's camp.",
    pickup = "Deathguard Linnea, camp south-east of Brill, Tirisfal Glades", turnin = "Deathguard Linnea, camp south-east of Brill, Tirisfal Glades",
    map = { mapID = 1420, x = 0.655, y = 0.603, label = "Deathguard Linnea — Tirisfal Glades", targetName = "Deathguard Linnea" },
}
FDJ.QUEST_PREREQ_DETAILS[99156] = {
    level = 13, requires = 6,
    warning = "Group quest: Riptear is a level 13 elite.",
    objective = "Kill Riptear in north-east Tirisfal Glades and bring Riptear's Heart to Deathguard Linnea.",
    pickup = "Deathguard Linnea, camp south-east of Brill, Tirisfal Glades", turnin = "Deathguard Linnea, camp south-east of Brill, Tirisfal Glades",
    map = { mapID = 1420, x = 0.655, y = 0.603, label = "Deathguard Linnea — Tirisfal Glades", targetName = "Deathguard Linnea" },
    requiredItems = {
        {286326, "Riptear's Heart", 1, "Dropped by Riptear (level 13 elite) in Venomweb Vale, north-east Tirisfal Glades (around 84, 44)", map = { mapID = 1420, x = 0.839, y = 0.440, label = "Riptear — Venomweb Vale", detail = "Dropped by Riptear (level 13 elite) in Venomweb Vale, north-east Tirisfal Glades (around 84, 44)" }},
    },
}
FDJ.PREREQ_REWARD_ITEMS_FALLBACK[99156] = { items = { {286742, "Riptear's Cleaver", 2}, {286743, "Riptear's Spare Arm", 2}, {286744, "Thrice-Stitched Flesh", 2} }, choice = true }
FDJ.PREREQ_REWARD_MONEY_FALLBACK[356] = 300
FDJ.FOREVER_QUEST_XP_FALLBACK[356] = 650
FDJ.FOREVER_QUEST_XP_FALLBACK[99156] = 900
FDJ.QUEST_SHAREABILITY_AUDIT[356] = true
FDJ.QUEST_SHAREABILITY_AUDIT[99156] = true
-- END rearguard

-- BEGIN drownedcity
-- The Drowned City (Horde): Kin'weelay's chain to the dungeon quest, and
-- Enemies in the Water before The Only Good Brinescale... Givers, objectives,
-- items, spawns, levels and XP: Forever client tables;
-- names and chain order from ForeverChanges and Hearthside.
do
    local KINWEELAY = { mapID = 1434, x = 0.323, y = 0.277, label = "Kin'weelay — Grom'gol Base Camp", targetName = "Kin'weelay", detail = "Kin'weelay at Grom'gol Base Camp, Stranglethorn Vale" }
    local GROMGOL = "Kin'weelay, Grom'gol Base Camp, Stranglethorn Vale"
    FDJ.QUEST_START_MAPS[95775] = KINWEELAY
    FDJ.QUEST_START_MAPS[96774] = { mapID = 1412, x = 0.325, y = 0.206, label = "Mazu'kon — Mulgore", targetName = "Mazu'kon", detail = "Mazu'kon of the Earthen Ring, north-west Mulgore" }
    FDJ.QUEST_START_MAPS[95789] = { mapID = 1434, x = 0.269, y = 0.772, label = "Krazek — Booty Bay", targetName = "Krazek", detail = "Krazek, upstairs in Booty Bay, Stranglethorn Vale" }
    FDJ.QUEST_START_MAPS[95791] = FDJ.QUEST_START_MAPS[95789]
    FDJ.QUEST_START_MAPS[95787] = { mapID = 1424, x = 0.506, y = 0.571, label = "Loremaster Dibbs — Southshore", targetName = "Loremaster Dibbs", detail = "Loremaster Dibbs in Southshore, Hillsbrad Foothills" }
    -- Magics of the Drowned City and Dibbs' two follow-ups: the same marker.
    FDJ.QUEST_START_MAPS[95788] = FDJ.QUEST_START_MAPS[95787]
    FDJ.QUEST_START_MAPS[95799] = FDJ.QUEST_START_MAPS[95787]
    FDJ.QUEST_START_MAPS[95798] = FDJ.QUEST_START_MAPS[95787]

    FDJ.QUEST_PREREQ_CHAINS[95775] = {
        { id = 629, name = "The Vile Reef" },
        { id = 95748, name = "The Gurubashi Legends of Old" },
        { id = 95770, name = "Locating the Lost City" },
    }
    FDJ.QUEST_PREREQ_DETAILS[629] = {
        level = 37, requires = 30,
        warning = "Group quest: the Saltscale murlocs at the Vile Reef are elite.",
        objective = "Bring a Tablet Shard to Kin'weelay at Grom'gol Base Camp.",
        pickup = GROMGOL, turnin = GROMGOL,
        map = KINWEELAY,
        requiredItems = {
            {4094, "Tablet Shard", 1, "From the tablet Gri'lek the Wanderer, at the bottom of the Vile Reef (around 25, 23)", map = { mapID = 1434, x = 0.248, y = 0.230, label = "Gri'lek the Wanderer — the Vile Reef", detail = "The tablet at the bottom of the Vile Reef (around 25, 23)", pickUp = true, underwater = true }},
        },
    }
    FDJ.QUEST_PREREQ_DETAILS[95748] = {
        level = 40, requires = 30,
        objective = "Use the hide and charcoal to make a rubbing of the Third Troll Legend tablet.",
        pickup = GROMGOL, turnin = GROMGOL,
        map = KINWEELAY,
        requiredItems = {
            {2007, "The Third Troll Legend", 1, "Rubbing of the tablet Fall of Gurubashi, in the troll ruins on the coast north of the Vile Reef (around 23, 12)", map = { mapID = 1434, x = 0.230, y = 0.120, label = "Fall of Gurubashi — troll ruins north of the Vile Reef", detail = "The tablet in the troll ruins on the coast (around 23, 12)", pickUp = true }},
        },
    }
    FDJ.QUEST_PREREQ_DETAILS[95770] = {
        level = 40, requires = 30,
        objective = "Explore just west of the Vile Reef and find the cavern entrance, then report back to Kin'weelay.",
        description = "The cave is in Sunken Hollow, underwater around 21, 28: the entrance to the Drowned City.",
        pickup = GROMGOL, turnin = GROMGOL,
        map = KINWEELAY,
    }

    -- A Tale Spun Around the Fire follows The Drowned City (Wowhead Forever
    -- quest 96078: Kin'weelay sends the etchings to Master Gadrin; a
    -- player, Nov 2026). Like the Alliance side, the follow-up is the
    -- list's entry and The Drowned City a step inside its chain.
    local GADRIN = { mapID = 1411, x = 0.558, y = 0.744, label = "Master Gadrin — Sen'jin Village", targetName = "Master Gadrin", detail = "Master Gadrin in Sen'jin Village, Durotar" }
    local INSIDE = "A rubbing of the tablet inside the Drowned City"
    FDJ.QUEST_START_MAPS[96078] = KINWEELAY
    FDJ.QUEST_PREREQ_CHAINS[96078] = {
        { id = 629, name = "The Vile Reef" },
        { id = 95748, name = "The Gurubashi Legends of Old" },
        { id = 95770, name = "Locating the Lost City" },
        { id = 95775, name = "The Drowned City" },
    }
    FDJ.QUEST_PREREQ_DETAILS[95775] = {
        level = 40, requires = 30,
        objective = "Use the hide and charcoal to make rubbings of the four Tablets of I'lalai in the Drowned City.",
        pickup = GROMGOL, turnin = GROMGOL,
        map = KINWEELAY, turninMap = KINWEELAY,
        requiredItems = {
            {270308, "The First Tablet of I'lalai", 1, INSIDE},
            {270309, "The Second Tablet of I'lalai", 1, INSIDE},
            {270310, "The Third Tablet of I'lalai", 1, INSIDE},
            {270311, "The Fourth Tablet of I'lalai", 1, INSIDE},
        },
    }
    for _, quest in ipairs((FDJ.DB["The Drowned City"] and FDJ.DB["The Drowned City"].quests) or {}) do
        if quest.id == 95775 then quest.hideFromMainList = true end
        if quest.id == 96078 then quest.turninMap = GADRIN end
    end

    -- Commander Aggro'gosh gives and takes both (Wowhead Forever: quests
    -- 95773 and 95776, NPC 2464). Enemies in the Water needs The Gurubashi
    -- Legends of Old handed in; The Only Good Brinescale... needs Enemies in
    -- the Water and Locating the Lost City (a player, Nov 2026; its text
    -- follows both).
    local AGGROGOSH = { mapID = 1434, x = 0.322, y = 0.288, label = "Commander Aggro'gosh — Grom'gol Base Camp", targetName = "Commander Aggro'gosh", detail = "Commander Aggro'gosh at Grom'gol Base Camp, Stranglethorn Vale" }
    local AT_AGGROGOSH = "Commander Aggro'gosh, Grom'gol Base Camp, Stranglethorn Vale"
    FDJ.QUEST_START_MAPS[95773] = AGGROGOSH
    FDJ.QUEST_START_MAPS[95776] = AGGROGOSH
    FDJ.QUEST_PREREQ_CHAINS[95776] = {
        { id = 629, name = "The Vile Reef" },
        { id = 95748, name = "The Gurubashi Legends of Old" },
        { id = 95773, name = "Enemies in the Water" },
        { id = 95770, name = "Locating the Lost City" },
    }
    FDJ.QUEST_PREREQ_DETAILS[95773] = {
        level = 37, requires = 30,
        objective = "Gather 10 Brinescale Tridents from Brinescale Skirmishers.",
        note = "Commander Aggro'gosh offers it once The Gurubashi Legends of Old is handed in.",
        pickup = AT_AGGROGOSH, turnin = AT_AGGROGOSH,
        map = AGGROGOSH, turninMap = AGGROGOSH,
        requiredItems = {
            {270305, "Brinescale Trident", 1, "Dropped by Brinescale Skirmishers around the Vile Reef, west of Grom'gol (around 22, 26)", map = { mapID = 1434, x = 0.225, y = 0.256, label = "Brinescale Skirmishers — around the Vile Reef", detail = "Brinescale Skirmishers on the sea floor west of Grom'gol (around 22, 26)" }},
        },
    }

    FDJ.FOREVER_QUEST_XP_FALLBACK[629] = 2850
    FDJ.FOREVER_QUEST_XP_FALLBACK[95748] = 3150
    FDJ.FOREVER_QUEST_XP_FALLBACK[95770] = 3150
    FDJ.FOREVER_QUEST_XP_FALLBACK[95773] = 2850
    FDJ.FOREVER_QUEST_XP_FALLBACK[95775] = 8450
    FDJ.FOREVER_QUEST_XP_FALLBACK[95776] = 9500
    FDJ.FOREVER_QUEST_XP_FALLBACK[96774] = 8800
    FDJ.FOREVER_QUEST_XP_FALLBACK[97130] = 10450
    FDJ.FOREVER_QUEST_XP_FALLBACK[96078] = 2350
    for _, id in ipairs({ 629, 95748, 95770, 95773, 95775, 95776, 96078, 96774, 97130 }) do
        FDJ.QUEST_SHAREABILITY_AUDIT[id] = true
    end
end
-- END drownedcity
-- BEGIN drownedhorde
-- drownedhorde (2.1.3, M 21 Nov 2026: "build a Drowned City Horde"): what
-- the Route needs for the Horde side (Wowhead Forever quests 95748, 95770,
-- 95773, 95776, 96078, 96774 and their comments).
--  - Locating the Lost City is done at the cavern just west of the Vile Reef
--    (a comment: /way 21.7, 27.1).
--  - Enemies in the Water: 10 Brinescale Tridents from the Brinescale
--    Skirmishers on the sea floor (best by the dungeon's entrance, away from
--    the elite murlocs: a comment); a place to kill at, not a thing to pick
--    up (the trident's own spot is for the journal only: noRouteStop).
--  - The Only Good Brinescale... needs Enemies in the Water and Locating the
--    Lost City, neither waiting for the other (together).
--  - A Tale Spun Around the Fire follows The Drowned City, which needs the
--    run (its tablets are inside); the tale itself is a delivery to Master
--    Gadrin in Sen'jin Village (no run of its own).
--  - Mazu'kon (Ancient Gurubashi Idol) stands on a hill in north-west
--    Mulgore: the path up starts at 40.2, 17.4 (a comment).
do
    local BRINESCALE = { markerType = "location", mapID = 1434, x = 0.225, y = 0.256, label = "Brinescale Skirmishers — Stranglethorn Vale", detail = "Brinescale Skirmishers on the sea floor west of Grom'gol, by the Drowned City's entrance" }
    -- cavernpoint (2.1.3, M 21 Nov 2026 in the Vile Reef, the arrow's
    -- crossed swords over Locating the Lost City: "Why is the arrow here
    -- still a battle sword if I just have to find the location? ... You can
    -- see on the cursor coordinates where it is", 21.8, 27.6; was 21.7, 27.1):
    -- one place to find, not an area (exact): the arrow points at it.
    local CAVERN = { markerType = "location", mapID = 1434, x = 0.218, y = 0.276, exact = true, label = "Cavern west of the Vile Reef — Stranglethorn Vale", detail = "The underwater cavern just west of the Vile Reef: the way into the Drowned City" }
    local D = FDJ.QUEST_PREREQ_DETAILS
    if D[95770] then D[95770].objectiveMap = CAVERN end
    if D[95773] then
        D[95773].objectiveMap = BRINESCALE
        for _, item in ipairs(D[95773].requiredItems or {}) do
            if type(item) == "table" and item[1] == 270305 then item.noRouteStop = true end
        end
    end
    for _, step in ipairs(FDJ.QUEST_PREREQ_CHAINS[95776] or {}) do
        if step.id == 95770 then step.together = true end
    end
    for _, step in ipairs(FDJ.QUEST_PREREQ_CHAINS[96078] or {}) do
        if step.id == 95775 then step.needsDungeon = true end
    end
    for _, quest in ipairs((FDJ.DB["The Drowned City"] and FDJ.DB["The Drowned City"].quests) or {}) do
        if quest.id == 96078 then quest.routeNoRun = true end
    end
    -- Mazu'kon: the arrow to the foot of the path first
    local MAZUKON = FDJ.QUEST_START_MAPS[96774]
    if type(MAZUKON) == "table" then
        FDJ.ARROW_VIAS = FDJ.ARROW_VIAS or {}
        FDJ.ARROW_VIAS[string.format("%s|%.4f|%.4f", tostring(MAZUKON.mapID), MAZUKON.x, MAZUKON.y)] = {
            { mapID = 1412, x = 0.402, y = 0.174, label = "Take the path up the hill", keep = true },
        }
    end
end
-- END drownedhorde
-- BEGIN swimstraight
-- swimstraight (2.1.3, M 21 Nov 2026 on the Savage Coast, the arrow to
-- Enemies in the Water: "it should just point me straight into the
-- water"): the places out in the sea west of Grom'gol are swum to in a
-- straight line (Systems/MapMarkers.lua: Way.SwimStraight), not walked
-- round by the shore: the Brinescale Skirmishers, the cavern of Locating
-- the Lost City, the Drowned City's entrance and the Vile Reef's tablet.
do
    local D = FDJ.QUEST_PREREQ_DETAILS
    local function Swim(spot) if type(spot) == "table" then spot.swim = true end end
    if D[95773] then
        Swim(D[95773].objectiveMap)
        for _, item in ipairs(D[95773].requiredItems or {}) do
            if type(item) == "table" then Swim(item.map) end
        end
    end
    if D[95770] then Swim(D[95770].objectiveMap) end
    if D[629] then
        for _, item in ipairs(D[629].requiredItems or {}) do
            if type(item) == "table" then Swim(item.map) end
        end
    end
    Swim(FDJ.DB and FDJ.DB["The Drowned City"] and FDJ.DB["The Drowned City"].entrance)
    -- swimplace (2.1.3, M 21 Nov 2026 at the cavern: "It should say swim
    -- underwater, by the way"): the cavern and the entrance lie under water:
    -- "Swim underwater" under the arrow's yards near them (MapMarkers.lua)
    local cavern = D[95770] and D[95770].objectiveMap
    if type(cavern) == "table" then cavern.underwater = true end
    local door = FDJ.DB and FDJ.DB["The Drowned City"] and FDJ.DB["The Drowned City"].entrance
    if type(door) == "table" then door.underwater = true end
end
-- END swimstraight


-- BEGIN drownedalliance
-- The Drowned City (Alliance) as chains, the last quest the list's entry and
-- the steps inside it. At the Rebel Camp in northern Stranglethorn, Sergeant
-- Yohwa's The Second Rebellion and Bad Medicine are done together; once both
-- are handed in, Brother Nimetz gives Kurzen's Mystery, then Troll Witchery,
-- then An Acquaintance in Southshore, which takes the player to Loremaster
-- Dibbs. Dibbs gives Take Two With Water and Magics of the Drowned City; each
-- leads to one of his follow-ups. Chain order: a player's notes (Discord,
-- Nov 2026). Quest texts, levels, XP and items: Wowhead Forever (quests 203,
-- 204, 205, 207, 95786-95788, 95798, 95799; the four troll tablets); where
-- the NPCs stand: Forever client tables (spawns of
-- 739, 2277, 2916, 252019) and Wowhead Forever (733).
do
    local DIBBS = FDJ.QUEST_START_MAPS[95787]
    local NIMETZ = { mapID = 1434, x = 0.378, y = 0.036, label = "Brother Nimetz — Rebel Camp", targetName = "Brother Nimetz", detail = "Brother Nimetz at the Rebel Camp, northern Stranglethorn Vale" }
    local KARNIK = { mapID = 1455, x = 0.775, y = 0.118, label = "Historian Karnik — Hall of Explorers", targetName = "Historian Karnik", detail = "Historian Karnik in the Hall of Explorers, Ironforge" }
    local ABRA = { mapID = 1416, x = 0.132, y = 0.696, label = "Abra Cadabra — Dalaran", targetName = "Abra Cadabra", detail = "Abra Cadabra in Dalaran, Alterac Mountains" }
    local YOHWA = { mapID = 1434, x = 0.380, y = 0.034, label = "Sergeant Yohwa — Rebel Camp", targetName = "Sergeant Yohwa", detail = "Sergeant Yohwa at the Rebel Camp, northern Stranglethorn Vale" }
    local AT_DIBBS = "Loremaster Dibbs, Southshore, Hillsbrad Foothills"
    local AT_YOHWA = "Sergeant Yohwa, Rebel Camp, Stranglethorn Vale"
    local AT_NIMETZ = "Brother Nimetz, Rebel Camp, Stranglethorn Vale"
    local INSIDE = "A rubbing of the tablet inside the Drowned City"
    local BOTH = "Done together with the other of Sergeant Yohwa's two quests (The Second Rebellion and Bad Medicine); Brother Nimetz offers Kurzen's Mystery once both are handed in."

    -- Objects, not NPCs: nothing to target from the map.
    local function Tablet(name, x, y, where)
        -- pickUp: a thing to pick up (the arrow stays there and says so);
        -- underwater: on the bottom of the Vile Reef ("Swim underwater")
        return { markerType = "location", mapID = 1434, x = x, y = y, label = name .. " — Stranglethorn Vale", detail = where, pickUp = true,
            underwater = (name == "Gri'lek the Wanderer") or nil }
    end

    local LEAD_IN = {
        { id = 203, name = "The Second Rebellion" },
        { id = 204, name = "Bad Medicine" },
        { id = 207, name = "Kurzen's Mystery" },
        { id = 205, name = "Troll Witchery" },
        { id = 95786, name = "An Acquaintance in Southshore" },
    }
    local function Chain(lastStep)
        local chain = {}
        for i, step in ipairs(LEAD_IN) do chain[i] = { id = step.id, name = step.name } end
        chain[#chain + 1] = lastStep
        return chain
    end
    FDJ.QUEST_PREREQ_CHAINS[95799] = Chain({ id = 95787, name = "Take Two With Water" })
    FDJ.QUEST_PREREQ_CHAINS[95798] = Chain({ id = 95788, name = "Magics of the Drowned City" })

    FDJ.QUEST_PREREQ_DETAILS[203] = {
        level = 33, requires = 30,
        objective = "Kill 15 Kurzen Jungle Fighters.",
        pickup = AT_YOHWA, turnin = AT_YOHWA,
        map = YOHWA, turninMap = YOHWA,
        note = BOTH,
    }
    FDJ.QUEST_PREREQ_DETAILS[204] = {
        level = 34, requires = 30,
        objective = "Bring 7 Jungle Remedies and 1 Venom Fern Extract to Sergeant Yohwa.",
        pickup = AT_YOHWA, turnin = AT_YOHWA,
        map = YOHWA, turninMap = YOHWA,
        requiredItems = {
            {2633, "Jungle Remedy", 1, "Dropped by the Kurzen trolls in and around Kurzen's Compound (7 needed)"},
            {2634, "Venom Fern Extract", 1, "Dropped by the Kurzen trolls in and around Kurzen's Compound"},
        },
        note = BOTH,
    }
    FDJ.QUEST_PREREQ_DETAILS[207] = {
        level = 38, requires = 30,
        objective = "Find the four troll tablets on the coast and in the Vile Reef, and bring back the First, Second, Third and Fourth Troll Legends.",
        pickup = AT_NIMETZ, turnin = AT_NIMETZ,
        map = NIMETZ, turninMap = NIMETZ,
        requiredItems = {
            {2005, "The First Troll Legend", 1, "From the tablet Moon Over the Vale (around 29, 19)", map = Tablet("Moon Over the Vale", 0.294, 0.192, "The tablet Moon Over the Vale (around 29, 19)")},
            {2006, "The Second Troll Legend", 1, "From the tablet Gri'lek the Wanderer, at the bottom of the Vile Reef (around 25, 23)", map = Tablet("Gri'lek the Wanderer", 0.248, 0.228, "The tablet at the bottom of the Vile Reef (around 25, 23)")},
            {2007, "The Third Troll Legend", 1, "From the tablet Fall of Gurubashi, in the troll ruins on the coast north of the Vile Reef (around 23, 12)", map = Tablet("Fall of Gurubashi", 0.230, 0.120, "The tablet in the troll ruins on the coast (around 23, 12)")},
            {2008, "The Fourth Troll Legend", 1, "From the tablet The Emperor's Tomb (around 25, 9)", map = Tablet("The Emperor's Tomb", 0.247, 0.090, "The tablet The Emperor's Tomb (around 25, 9)")},
        },
    }
    FDJ.QUEST_PREREQ_DETAILS[205] = {
        level = 40, requires = 30,
        objective = "Bring 4 Skullsplitter Fetishes to Brother Nimetz.",
        pickup = AT_NIMETZ, turnin = AT_NIMETZ,
        map = NIMETZ, turninMap = NIMETZ,
        requiredItems = {
            {2466, "Skullsplitter Fetish", 1, "Dropped by Skullsplitter Witchdoctors and Mystics in the troll ruins south of the Rebel Camp (4 needed)"},
        },
    }
    FDJ.QUEST_PREREQ_DETAILS[95786] = {
        level = 40, requires = 30,
        objective = "Take the Savage Coast Report Bundle (the fetishes, the troll legends and the scouting report) to Loremaster Dibbs in Southshore.",
        pickup = AT_NIMETZ, turnin = AT_DIBBS,
        map = NIMETZ, turninMap = DIBBS,
        providedItem = {270340, "Savage Coast Report Bundle", 1, "Given by Brother Nimetz when you accept the quest"},
    }
    FDJ.QUEST_PREREQ_DETAILS[95787] = {
        level = 40, requires = 30,
        objective = "Make rubbings of the four Tablets of I'lalai in the Drowned City.",
        pickup = AT_DIBBS, turnin = AT_DIBBS,
        map = DIBBS,
        requiredItems = {
            {270308, "The First Tablet of I'lalai", 1, INSIDE},
            {270309, "The Second Tablet of I'lalai", 1, INSIDE},
            {270310, "The Third Tablet of I'lalai", 1, INSIDE},
            {270311, "The Fourth Tablet of I'lalai", 1, INSIDE},
        },
    }
    FDJ.QUEST_PREREQ_DETAILS[95788] = {
        level = 40, requires = 30,
        objective = "Collect 5 I'lalai Fetishes from the trolls in the Drowned City.",
        pickup = AT_DIBBS, turnin = AT_DIBBS,
        map = DIBBS,
        requiredItems = {
            {270343, "I'lalai Fetish", 1, "Dropped by the trolls in the Drowned City (5 needed)"},
        },
    }
    FDJ.QUEST_START_MAPS[95786] = NIMETZ
    FDJ.QUEST_START_MAPS[203] = YOHWA
    FDJ.QUEST_START_MAPS[204] = YOHWA
    FDJ.QUEST_START_MAPS[207] = NIMETZ
    FDJ.QUEST_START_MAPS[205] = NIMETZ
    FDJ.FOREVER_QUEST_XP_FALLBACK[203] = 1950
    FDJ.FOREVER_QUEST_XP_FALLBACK[204] = 2700
    FDJ.FOREVER_QUEST_XP_FALLBACK[207] = 3550
    FDJ.FOREVER_QUEST_XP_FALLBACK[205] = 3150
    FDJ.FOREVER_QUEST_XP_FALLBACK[95786] = 3150
    FDJ.FOREVER_QUEST_XP_FALLBACK[95787] = 8450
    FDJ.FOREVER_QUEST_XP_FALLBACK[95788] = 8450
    for _, id in ipairs({ 203, 204, 205, 207 }) do
        FDJ.QUEST_SHAREABILITY_AUDIT[id] = true
    end

    -- Ancient Gurubashi Secrets: Archmage Timear, outside where the Violet
    -- Hold stood in Dalaran (a player, Nov 2026; Wowhead Forever's spawn of
    -- 31439).
    FDJ.QUEST_START_MAPS[97130] = { mapID = 1416, x = 0.154, y = 0.740, label = "Archmage Timear — Dalaran", targetName = "Archmage Timear", detail = "Archmage Timear, outside where the Violet Hold stood in Dalaran, Alterac Mountains" }
    -- Confirmed turn-in: Archmage Timear is the same NPC as the quest giver.
    for _, quest in ipairs((FDJ.DB["The Drowned City"] and FDJ.DB["The Drowned City"].quests) or {}) do
        if quest.id == 97130 then
            quest.turninMap = FDJ.QUEST_START_MAPS[97130]
            break
        end
    end

    -- drownedally (2.0.9, M: "the tracking guide, the one with the arrow, for
    -- Alliance Drowned City quests"): what the Route needs to know.
    --  - Sergeant Yohwa's two quests are taken together (the second does not
    --    wait for the first to be handed in).
    --  - Where each lead-in is done: the Kurzen men of both of Yohwa's quests
    --    stand at Kurzen's Compound (Jungle Fighters and Medicine Men, 28
    --    spawns around 44.7, 10.4); the Skullsplitter Mystics south of it (24
    --    spawns around 45.9, 36.4; the Witch Doctors a little further south).
    --    Forever client tables (spawns of 937, 940,
    --    780, 670). Kurzen's Mystery: its four tablets have their places
    --    already (requiredItems' maps).
    --  - Dibbs' two quests are done inside the dungeon: handed in after the
    --    run. His two follow-ups are deliveries: no run of their own.
    do
        local KURZEN = { markerType = "location", mapID = 1434, x = 0.447, y = 0.104, label = "Kurzen's Compound — Stranglethorn Vale", detail = "Kurzen Jungle Fighters and Medicine Men, in and around Kurzen's Compound" } -- (no town named here: the arrow would say "Get to" it)
        local SKULLSPLITTERS = { markerType = "location", mapID = 1434, x = 0.459, y = 0.364, label = "Skullsplitter trolls — Stranglethorn Vale", detail = "Skullsplitter Mystics and Witch Doctors in the troll ruins south of Kurzen's Compound" }
        FDJ.QUEST_PREREQ_DETAILS[203].objectiveMap = KURZEN
        FDJ.QUEST_PREREQ_DETAILS[204].objectiveMap = KURZEN
        FDJ.QUEST_PREREQ_DETAILS[205].objectiveMap = SKULLSPLITTERS
        for _, id in ipairs({ 95799, 95798 }) do
            for _, step in ipairs(FDJ.QUEST_PREREQ_CHAINS[id]) do
                if step.id == 204 then step.together = true end
                if step.id == 95787 or step.id == 95788 then step.needsDungeon = true end
            end
        end
        for _, quest in ipairs((FDJ.DB["The Drowned City"] and FDJ.DB["The Drowned City"].quests) or {}) do
            if quest.id == 95799 or quest.id == 95798 then quest.routeNoRun = true end
        end
    end

    -- The steps are listed inside their chains only (QuestChains.lua's pass
    -- ran before these chains were added), and the follow-ups' hand-in NPCs
    -- get their map spots.
    for _, quest in ipairs((FDJ.DB["The Drowned City"] and FDJ.DB["The Drowned City"].quests) or {}) do
        if quest.id == 95787 or quest.id == 95788 then quest.hideFromMainList = true end
        if quest.id == 95799 then quest.turninMap = KARNIK end
        if quest.id == 95798 then quest.turninMap = ABRA end
    end
end
-- END drownedalliance

-- BEGIN glowingshard
-- The Glowing Shard: first speak with Sputtervalve in Ratchet (the quest's
-- objective; he has no ? over his head), then hand it in to Falla Sagewind on
-- top of the mountain above Wailing Caverns (Forever client tables via
-- the client's tables: end NPC 8418, Sputtervalve 3442 and their spawns). The
-- tracker's ? shows Ratchet until he has been spoken to, then Falla.
do
    local FALLA = { mapID = 1413, x = 0.482, y = 0.328, label = "Falla Sagewind — above Wailing Caverns", targetName = "Falla Sagewind", detail = "In a tent on top of the mountain above Wailing Caverns" }
    for _, quest in ipairs((FDJ.DB["Wailing Caverns"] and FDJ.DB["Wailing Caverns"].quests) or {}) do
        if quest.id == 6981 then
            quest.objective = "Speak with Sputtervalve in Ratchet about the Glowing Shard, then deliver it to Falla Sagewind on top of the mountain above Wailing Caverns."
            quest.turnin = "Falla Sagewind, on top of the mountain above Wailing Caverns, The Barrens (48.2, 32.8)"
            quest.turninMap = FALLA
            quest.objectiveMap = { mapID = 1413, x = 0.630, y = 0.372, label = "Sputtervalve — Ratchet", targetName = "Sputtervalve", detail = "By the flight master in Ratchet; he has no ? over his head" }
            quest.objectiveWhere = "Sputtervalve, by the flight master in Ratchet (63.0, 37.2); he has no ? over his head"
        end
    end
    -- Falla Sagewind was put in Thunder Bluff here by mistake.
    FDJ.QUEST_START_MAPS[6981] = FALLA
    -- The game's objective line, named (Systems/QuestText.lua:
    -- FDJ.ObjectiveLineOverride): 0/1 / 1/1 Speak with Sputtervalve in Ratchet.
    FDJ.OBJECTIVE_LINE_OVERRIDES = FDJ.OBJECTIVE_LINE_OVERRIDES or {}
    FDJ.OBJECTIVE_LINE_OVERRIDES[6981] = { match = "in ratchet", text = "Speak with Sputtervalve in Ratchet" }
end
-- END glowingshard

-- BEGIN malletchain
-- The Mallet of Zul'Farrak, which summons Gahz'rilla at the gong in
-- Zul'Farrak: no quest in the game, two things done by hand (WoW Forever is
-- the same as Classic: Warcraft Tavern's Forever Zul'Farrak guide). Shown as
-- a page of its own (questChainPage, like the Cozy Sleeping Bag), opened from
-- the button on Gahz'rilla's boss page, beside his portrait.
-- malletone (2.1.3, M 21 Nov 2026: "it's not really a pickup ... it's not
-- even a chain quest ... put everything together"): one entry, no chain, no
-- "Pick it up" and no Starts at (noPickUp): the objective is killing Qiaga
-- the Keeper for the Sacred Mallet (Show on Map: Qiaga), then, under it,
-- using the Sacred Mallet at the altar on top of Jintha'Alor (objectiveMore,
-- its own Show on Map). Nothing of it is done inside Zul'Farrak
-- (objectiveInDungeon = false); only the gong is. Done once the character
-- holds the Mallet of Zul'Farrak (FDJ.PSEUDO_QUEST_DONE, made-up ID). The
-- tracker's and the arrow's spot (startMap) is Qiaga until the Sacred Mallet
-- is in the bags, then the altar.
-- Spots: Altar of Zul (48.6, 68.0) and the altar on top of Jintha'Alor
-- (58.5, 77.5), The Hinterlands, from player guides.
do
    local PAGE = "Mallet of Zul'Farrak"
    FDJ.MALLET_PAGE = PAGE
    local MAIN = -97100
    local SACRED, MALLET = 9241, 9240
    FDJ.MALLET_QUEST = MAIN

    local QIAGA = { mapID = 1425, x = 0.486, y = 0.680, label = "Qiaga the Keeper — Altar of Zul, The Hinterlands", targetName = "Qiaga the Keeper", detail = "At the top of the Altar of Zul" }
    local ALTAR = { markerType = "location", mapID = 1425, x = 0.585, y = 0.775, label = "Altar of Jintha'Alor — The Hinterlands", detail = "The altar at the very top of Jintha'Alor" }

    -- Held by the character (bags or bank)?
    local function Has(itemID)
        local count
        if C_Item and C_Item.GetItemCount then
            local ok, n = pcall(C_Item.GetItemCount, itemID, true)
            if ok then count = n end
        end
        if count == nil and GetItemCount then
            local ok, n = pcall(GetItemCount, itemID, true)
            if ok then count = n end
        end
        if type(issecretvalue) == "function" and issecretvalue(count) then return false end
        return type(count) == "number" and count > 0
    end

    local quest = {
        id = MAIN, name = "Mallet of Zul'Farrak", level = 50, requires = 1, faction = "Both",
        noPickUp = true, objectiveInDungeon = false,
        -- malletwarn (2.1.3, M 21 Nov 2026): the red line at the top
        warning = "There is no quest to pick up here. Just kill and loot.",
        objective = "Kill Qiaga the Keeper to loot the Sacred Mallet.",
        objectiveMap = QIAGA,
        -- %s: Jintha'Alor (area 354), the client's own name when the journal speaks its language
        objectiveMore = { text = "Then use the Sacred Mallet at the altar on the very top of %s: it turns into the Mallet of Zul'Farrak.", area = { 354, "Jintha'Alor" }, map = ALTAR },
        pickup = "Qiaga the Keeper, top of the Altar of Zul, The Hinterlands (48.6, 68.0)",
        turnin = "The gong at Gahz'rilla's pool, inside Zul'Farrak: use the Mallet of Zul'Farrak there to summon Gahz'rilla.",
        note = "Qiaga the Keeper and Morta'gya the Keeper are level 50 elites with casters around them, and the way up to the top altar is full of level 45-50 trolls: bring a group, or sneak up. Everyone in the group can loot a Sacred Mallet, and it can be used in combat. One Mallet of Zul'Farrak in the group is enough, and it summons Gahz'rilla in every later run too.",
        rewardSummary = "",
        rewardItems = { { MALLET, "Mallet of Zul'Farrak", 1 } },
    }
    -- startMap: Qiaga, then (Sacred Mallet in the bags) the altar
    setmetatable(quest, { __index = function(_, key)
        if key == "startMap" then return Has(SACRED) and ALTAR or QIAGA end
    end })

    FDJ.DB[PAGE] = {
        questChainPage = true, -- Quests, plus Bosses and Map of Zul'Farrak
        -- Bosses and Map lead back to Zul'Farrak (Bosses at Gahz'rilla).
        parentDungeon = "Zul'Farrak",
        parentBoss = "Gahz'rilla",
        level = "45+",
        location = "The Hinterlands",
        description = "",
        bosses = {},
        quests = { quest },
    }

    FDJ.PSEUDO_QUEST_DONE = FDJ.PSEUDO_QUEST_DONE or {}
    FDJ.PSEUDO_QUEST_DONE[MAIN] = function() return Has(MALLET) end

    -- Gahz'rilla's page: "Summon with: [Mallet of Zul'Farrak]" under his
    -- name (Systems/BossSummon.lua); a click on the mallet opens this page.
    local zf = FDJ.DB["Zul'Farrak"]
    for _, boss in ipairs((zf and zf.bosses) or {}) do
        if boss.name == "Gahz'rilla" then
            boss.summonItem = MALLET
            boss.summonChain = { page = PAGE, quest = MAIN }
        end
    end
    -- summonhelp (2.0.9, M 16 Nov 2026): the quest Gahz'rilla (2770) says he
    -- has to be summoned, above its Objective, with "How to summon
    -- Gahz'rilla" opening this page (Core/Journal.lua, FDJ.PlaceSummonHelp).
    for _, q in ipairs((zf and zf.quests) or {}) do
        if q.id == 2770 then
            q.summonHelp = { boss = "Gahz'rilla", item = MALLET, itemName = "Mallet of Zul'Farrak", page = PAGE, quest = MAIN }
        end
    end
end
-- END malletchain

-- BEGIN sleepingbag
-- The Cozy Sleeping Bag (WoW Forever 1.60.1): its quest chain as a page of
-- its own (questChainPage), opened from the button left of Favourites on the
-- journal's home page. The Alliance start at the Burned-Out Remains in
-- Westfall and follow the note to The Barrens, the Horde the other way round;
-- from Stepping Stones on, the chain is the same for both. Every step starts
-- and ends at an object. Quests, objects, spawns, levels and XP: Forever
-- client tables; rewards and the way to each spot:
-- Wowhead (Forever).
do
    local PAGE = "Cozy Sleeping Bag"
    FDJ.SLEEPING_BAG_PAGE = PAGE
    FDJ.SLEEPING_BAG_ITEM = 211527

    -- Objects, not NPCs: nothing to target from the map.
    local function Spot(mapID, x, y, label, detail)
        return { markerType = "location", mapID = mapID, x = x, y = y, label = label, detail = detail }
    end
    local BARRENS_REMAINS = Spot(1413, 0.463, 0.739, "Burned-Out Remains — The Barrens", "The burnt tower on the road south of Camp Taurajo")
    local WESTFALL_REMAINS = Spot(1436, 0.373, 0.506, "Burned-Out Remains — Westfall", "The cart wreckage at the Alexston Farmstead")
    local BARRENS_PLANK = Spot(1413, 0.464, 0.738, "Nailed Plank — The Barrens", "Beside the Burned-Out Remains, south of Camp Taurajo")
    local WESTFALL_PLANK = Spot(1436, 0.374, 0.509, "Nailed Plank — Westfall", "Beside the Burned-Out Remains at the Alexston Farmstead")
    local POCKET_LITTER = Spot(1442, 0.408, 0.526, "Pocket Litter — Stonetalon Mountains", "On a box at the abandoned camp")
    local MOUND = Spot(1442, 0.396, 0.499, "Mound of Dirt — Stonetalon Mountains", "Below the cliff north of the abandoned camp")
    local FIGURINE = Spot(1432, 0.494, 0.129, "Carved Figurine — Stonewrought Dam", "On the carved heads of the dam, facing the Wetlands")
    local BAG = Spot(1424, 0.857, 0.522, "Messenger Bag — Thoradin's Wall", "Hanging outside the room in Thoradin's Wall")
    local SATCHEL = Spot(1424, 0.857, 0.522, "Hastily Rolled-Up Satchel — Thoradin's Wall", "Right under the Messenger Bag")

    -- arrowvia: the way to a spot the straight line does not reach: points
    -- the waypoint arrow leads to first, in order (a player guide to the
    -- chain: the path into the Stonetalon hills, the fallen cart at
    -- Thoradin's Wall; for the Alliance the way round Honor's Stand).
    FDJ.ARROW_VIAS = FDJ.ARROW_VIAS or {}
    local function Via(spot, list)
        FDJ.ARROW_VIAS[string.format("%s|%.4f|%.4f", tostring(spot.mapID), spot.x, spot.y)] = list
    end
    -- The way to the abandoned camp, worked out on the walking maps
    -- of Kalimdor (1.8.1): the camp sits on a shelf in the hills, reached
    -- only by the path that leaves the main road at 52.2, 53.4 (or, from
    -- the north, by the path off the Charred Vale descent); Sun Rock
    -- Retreat's crater walls are cliffs on every other side.
    Via(POCKET_LITTER, { routes = {
        { -- from Sun Rock Retreat (Horde)
            { mapID = 1442, x = 0.500, y = 0.610, label = "Out of Sun Rock Retreat: its east exit, to the road", faction = "Horde" },
            { mapID = 1442, x = 0.520, y = 0.579, label = "The main road, north", faction = "Horde" },
            { mapID = 1442, x = 0.522, y = 0.560, label = "The main road, north" },
            { mapID = 1442, x = 0.522, y = 0.534, label = "Where the path into the hills leaves the road (left side)" },
            { mapID = 1442, x = 0.510, y = 0.524, label = "Up the path into the hills" },
            { mapID = 1442, x = 0.488, y = 0.542, label = "The hill path, west" },
            { mapID = 1442, x = 0.430, y = 0.541, label = "The hill path, west" },
        },
        { -- from the Barrens road (both factions; the Alliance round Honor's Stand)
            { mapID = 1413, x = 0.402, y = 0.249, label = "The road into Stonetalon (round Honor's Stand)", faction = "Alliance" },
            { mapID = 1442, x = 0.605, y = 0.817, label = "The road west out of the Barrens" },
            { mapID = 1442, x = 0.580, y = 0.672, label = "The road north, past Webwinder Path" },
            { mapID = 1442, x = 0.540, y = 0.614, label = "The road north, past Webwinder Path" },
            { mapID = 1442, x = 0.522, y = 0.560, label = "The main road, north" },
            { mapID = 1442, x = 0.522, y = 0.534, label = "Where the path into the hills leaves the road (left side)" },
            { mapID = 1442, x = 0.510, y = 0.524, label = "Up the path into the hills" },
            { mapID = 1442, x = 0.488, y = 0.542, label = "The hill path, west" },
            { mapID = 1442, x = 0.430, y = 0.541, label = "The hill path, west" },
        },
        { -- from Stonetalon Peak (Alliance)
            { mapID = 1442, x = 0.410, y = 0.157, label = "The road south out of Stonetalon Peak", faction = "Alliance" },
            { mapID = 1442, x = 0.438, y = 0.164, label = "The road south out of Stonetalon Peak", faction = "Alliance" },
            { mapID = 1442, x = 0.467, y = 0.291, label = "The road south", faction = "Alliance" },
            { mapID = 1442, x = 0.467, y = 0.358, label = "The road south", faction = "Alliance" },
            { mapID = 1442, x = 0.455, y = 0.385, label = "West, down towards the Charred Vale", faction = "Alliance" },
            { mapID = 1442, x = 0.426, y = 0.425, label = "West, down towards the Charred Vale", faction = "Alliance" },
            { mapID = 1442, x = 0.390, y = 0.428, label = "Down the path towards the Charred Vale", faction = "Alliance" },
            { mapID = 1442, x = 0.373, y = 0.445, label = "Down the path towards the Charred Vale", faction = "Alliance" },
            { mapID = 1442, x = 0.376, y = 0.527, label = "Halfway down: the path right (east), into the mountains", faction = "Alliance" },
            { mapID = 1442, x = 0.407, y = 0.552, label = "Up the mountain path to the camp", faction = "Alliance" },
        },
    } })
    -- The Mound of Dirt: straight on from the camp, north over the ridge
    -- and down the hillside (no via point).
    -- Thoradin's Wall round the Messenger Bag (1.8.4), from the
    -- walking maps of the Eastern Kingdoms: the fallen cart (its bed about
    -- 6 yards up, centre 88.0, 47.1), a few yards of ground, then rubble that
    -- ramps up south-west onto the wall and along it to the bag. The game
    -- gives no height, so where the player stands on this grid (0.1 % map
    -- steps from 85.0, 46.4) says whether they are up: '#' rubble, ramp and
    -- wall top (only raised ground), '+' the cart and the structure's edges
    -- (on or beside it), '.' plain ground, ' ' nothing to stand on. The
    -- arrow keeps to the cart until the player is on it (within 5 yards of
    -- its centre) or up on the rubble, and goes back to it on plain ground.
    local WALL = { mapID = 1424, x0 = 0.850, y0 = 0.464, step = 0.001, rows = {
            "............................+++++",
            "........................... +++++",
            "........................... +++++",
            "............................+++++",
            "............................+++++",
            "............................+++++",
            "...........................++++++",
            "...........................++++++",
            "...........................++++++",
            "...........................++++++",
            "...........................++++++",
            "...........................++++++",
            "............................+++++",
            "............................+++++",
            ".........................+++++.++",
            ".........................++#++.++",
            ".........................++#++++.",
            ".........................++#++++.",
            ".........................++#+++++",
            ".........................++####++",
            ".......................++++####++",
            ".......................+++######+",
            "......................++++######+",
            "......................++#########",
            ".....................+++#########",
            ".....................++#########+",
            "...................++++#########+",
            "...................+++#########++",
            "...................+++#########++",
            "...................+#########++++",
            "..................++#########+++.",
            "..................+#########++++.",
            ".................++#########++...",
            ".................++########+++...",
            ".............++++++########++....",
            ".............+++++#########++....",
            "...........+++++++#########+.....",
            "...........+++############++.....",
            "...........+############++++.....",
            ".........+++############+++......",
            ".........++############++++......",
            ".........++############++........",
            ".........+############+++........",
            "........++############+++........",
            "........+##############++........",
            "........+##############++........",
            ".......  #############+++........",
            "......+  #############++.........",
            "...... #############++++.........",
            ".....+ #############+++..........",
            ".....+############# +++..........",
            "....++############# .............",
            "....+##############+.............",
            "..+++##############+.............",
            "..+++############# +.............",
            ".++++############# ..............",
            ".++#############  +..............",
            "+++#############  ...............",
            "++############# +................",
            "++############# .................",
            "++############ +.................",
            "++############ ..................",
            "++##########  +..................",
            "++##########  ...................",
            "+###########+....................",
    } }
    local CART = { mapID = 1424, x = 0.8804, y = 0.4708, label = "The fallen cart at Thoradin's Wall: climb it", climb = WALL, reach = 5 }
    Via(BAG, { CART })
    Via(SATCHEL, { CART })

    -- Where each step is picked up and handed in, written out with the
    -- coordinates (shown on the step's page under Starts at / Turn in).
    local AT_BARRENS = "Burned-Out Remains at the burnt tower on the road south of Camp Taurajo, The Barrens (46.3, 73.9)"
    local AT_WESTFALL = "Burned-Out Remains in the cart wreckage at the Alexston Farmstead, Westfall (37.3, 50.6)"
    local AT_LITTER = "Pocket Litter on a box at the abandoned camp, Stonetalon Mountains (40.8, 52.6)"
    local AT_MOUND = "Mound of Dirt below the cliff north of the camp, Stonetalon Mountains (39.6, 49.9)"
    local AT_FIGURINE = "Carved Figurine on the carved heads of the Stonewrought Dam, Loch Modan (49.4, 12.9)"
    local AT_BAG = "Messenger Bag hanging at Thoradin's Wall, Hillsbrad Foothills (85.7, 52.2)"

    FDJ.DB[PAGE] = {
        questChainPage = true, -- Quests is its only tab
        level = "14+",
        location = "",
        description = "",
        bosses = {},
        quests = { {
            id = 79976, name = "This Must Be The Place", level = 32, requires = 14, faction = "Alliance",
            objective = "Search the Hastily Rolled-Up Satchel under the Messenger Bag at Thoradin's Wall.",
            pickup = AT_BAG,
            turnin = "Hastily Rolled-Up Satchel, right under the Messenger Bag",
            startMap = BAG, turninMap = SATCHEL,
            liveXPFallback = 1950,
            rewardItems = { {211527, "Cozy Sleeping Bag", 3}, {216619, "Student Fodder", 2} },
        } },
    }

    -- Step 1 is a quest of its own for each faction (79007 Horde, 79008
    -- Alliance); FDJ.SetSleepingBagFaction picks the character's.
    local NOTE = { id = 79008, name = "... and that note you found" }
    FDJ.QUEST_PREREQ_CHAINS[79976] = {
        NOTE,
        { id = 79192, name = "Stepping Stones" },
        { id = 79980, name = "Scramble" },
        { id = 79974, name = "Wet Job" },
        { id = 79975, name = "Eagle's Fist" },
    }
    FDJ.QUEST_PREREQ_DETAILS[79007] = {
        level = 22, requires = 14,
        objective = "Follow the charred note from The Barrens to its twin place: the Burned-Out Remains at the Alexston Farmstead in Westfall.",
        pickup = AT_BARRENS, turnin = AT_WESTFALL,
        map = BARRENS_REMAINS, turninMap = WESTFALL_REMAINS,
    }
    FDJ.QUEST_PREREQ_DETAILS[79008] = {
        level = 22, requires = 14,
        objective = "Follow the charred note from Westfall to its twin place: the Burned-Out Remains at the burnt tower south of Camp Taurajo in The Barrens.",
        pickup = AT_WESTFALL, turnin = AT_BARRENS,
        map = WESTFALL_REMAINS, turninMap = BARRENS_REMAINS,
    }
    -- Picked up from the Nailed Plank where step 1 ends (pickup and map: set
    -- for the faction below).
    local STEPPING = {
        level = 24, requires = 14,
        objective = "Find the cozy spot in the mountains between The Barrens and Desolace: the Pocket Litter at an abandoned camp in Stonetalon Mountains.",
        turnin = AT_LITTER,
        turninMap = POCKET_LITTER,
        note = "Take the path north-east of Sun Rock Retreat (50.9, 52.3) up to the abandoned camp; the Pocket Litter lies on a box. Optional: light the Firepit in the middle of the camp with the Simple Wood and Flint and Tinder from this quest (Rekindle).",
    }
    FDJ.QUEST_PREREQ_DETAILS[79192] = STEPPING
    FDJ.QUEST_PREREQ_DETAILS[79980] = {
        level = 24, requires = 14,
        objective = "Take a hundred paces due north of the camp and find the Mound of Dirt below the cliff.",
        pickup = AT_LITTER, turnin = AT_MOUND,
        map = POCKET_LITTER, turninMap = MOUND,
        note = "Head straight north from the camp, climb the hill and jump down from its edge to the Mound of Dirt. Watch your step.",
    }
    FDJ.QUEST_PREREQ_DETAILS[79974] = {
        level = 32, requires = 14,
        objective = "Find the eagle's nest on the face of the Stonewrought Dam in Loch Modan: the Carved Figurine.",
        pickup = AT_MOUND, turnin = AT_FIGURINE,
        map = MOUND, turninMap = FIGURINE,
        note = "Jump onto the carved heads of the dam, on the side facing the Wetlands, to reach the figurine. Getting there is tricky for the Horde.",
    }
    FDJ.QUEST_PREREQ_DETAILS[79975] = {
        level = 32, requires = 14,
        objective = "Find the Messenger Bag at Thoradin's Wall, between Hillsbrad Foothills and the Arathi Highlands.",
        pickup = AT_FIGURINE, turnin = AT_BAG,
        map = FIGURINE, turninMap = BAG,
        note = "Climb into Thoradin's Wall from the cart on the Hillsbrad side (87.3, 49.6), go through the room in the wall and look outside to the right: the bag hangs there.",
    }

    local PLANK = {
        Horde = { WESTFALL_PLANK, "Nailed Plank next to the Burned-Out Remains at the Alexston Farmstead, Westfall (37.4, 50.9)" },
        Alliance = { BARRENS_PLANK, "Nailed Plank on the side of the burnt tower south of Camp Taurajo, The Barrens (46.4, 73.8)" },
    }
    -- The page shows the character's faction only: its quest is that
    -- faction's, and the journal hides the Alliance / Horde buttons on it.
    function FDJ.SetSleepingBagFaction(faction)
        local plank = PLANK[faction] or PLANK.Alliance
        NOTE.id = faction == "Horde" and 79007 or 79008
        STEPPING.map, STEPPING.pickup = plank[1], plank[2]
        FDJ.DB[PAGE].quests[1].faction = faction == "Horde" and "Horde" or "Alliance"
    end
    FDJ.SetSleepingBagFaction("Alliance")

    local REWARDS = FDJ.PREREQ_REWARD_ITEMS_FALLBACK
    REWARDS[79007] = { items = { {2459, "Swiftness Potion", 1}, {3388, "Lesser Troll's Blood Elixir", 1} }, choice = false }
    REWARDS[79008] = REWARDS[79007]
    REWARDS[79192] = { items = { {2901, "Mining Pick", 1}, {3334, "Farmer's Shovel", 2} }, choice = true,
        also = { {1652, "Sturdy Lunchbox", 1}, {4470, "Simple Wood", 1}, {4471, "Flint and Tinder", 1}, {221498, "Old Toolbox", 1} } }
    REWARDS[79980] = { items = { {3463, "Silver Star", 2}, {217314, "Moonsight Rifle", 2}, {217315, "Precision Bow", 2} }, choice = true,
        also = { {3464, "Feathered Arrow", 2}, {3465, "Exploding Shot", 2}, {216619, "Student Fodder", 2} } }
    REWARDS[79974] = { items = { {5432, "Hickory Pipe", 0}, {20709, "Rumsey Rum Light", 1} }, choice = false }

    local XP = FDJ.FOREVER_QUEST_XP_FALLBACK
    XP[79007], XP[79008], XP[79192], XP[79980] = 1750, 1750, 1950, 200
    XP[79974], XP[79975], XP[79976] = 2550, 2550, 1950
    for _, id in ipairs({ 79007, 79008, 79192, 79980, 79974, 79975, 79976 }) do
        FDJ.QUEST_SHAREABILITY_AUDIT[id] = false
    end
end
-- END sleepingbag

-- BEGIN lesstext
-- Step pages show the objective, the quest givers and where to go. Notes that only
-- give the step's place in its chain (the chain list already shows it) or story
-- text are hidden, in every language.
for _, id in ipairs({ 65, 132, 135, 141, 153, 155, 275, 276, 277, 303, 373, 389, 463, 545, 865, 870, 877, 880, 1100, 1109, 1198, 1489, 1490, 1806, 2041, 2842, 2926, 2947, 2949, 5726, 92432, 92742, 92744, 92745, 92748, 92750, 92751, 92752, 92819, 95647, 95663, 96391 }) do
    local d = FDJ.QUEST_PREREQ_DETAILS[id]
    if d then d.suppressDescription = true end
end
-- END lesstext

-- BEGIN npcfloors
-- Quest NPCs well below (-) or above (+) the ground around them, in yards:
-- { continent, world x, world y, height }. The waypoint arrow says so near
-- them (a crypt, Undercity under the ruins, a tower top). Generated by
-- floors.py from the client's spawn heights (SOURCES.txt).
FDJ.NPC_FLOORS = {
    ["Apothecary Zamah"] = { { 1, -996, 277, -26 }, { 1, -995.5, 278.5, -26 }, { 1, -995.5, 280.5, -26 } },
    ["Argent Outfitter"] = { { 0, 1580, 245, -122 }, { 0, 1586, 250, -122 } },
    ["Argent Scout"] = { { 0, 1577, 238, -122 } },
    ["Astarii Starseeker"] = { { 1, 9666, 2531.5, 26 }, { 1, 9667, 2532.5, 26 } },
    ["Beetix Ficklespragg"] = { { 1, -6855.5, 740, 11 } },
    ["Cenarion Emissary Blackhoof"] = { { 1, 1658.5, -4349, -32 } },
    ["Clarice Foster"] = { { 1, -1033.5, 214, -25 } },
    ["Dizzy One-Eye"] = { { 0, -14397.5, 396.5, 14 } },
    ["Elder Skychaser"] = { { 0, -10499, 1034, 28 } },
    ["Elenia Haydon"] = { { 0, 1588.5, 231, -112 } },
    ["Fenstad Argyle"] = { { 0, 1591.5, 233.5, -112 } },
    ["Godrick Farsan"] = { { 0, 1783, 60, -16 } },
    ["Harbinger Balthazad"] = { { 0, 1596, 260, -117 } },
    ["High Executor Hadrec"] = { { 0, 522.5, 1626.5, -20 } },
    ["High Sorcerer Andromath"] = { { 0, -9011, 876.5, 119 } },
    ["Innkeeper Norman"] = { { 0, 1635.5, 223.5, -106 } },
    ["Jeremiah Payson"] = { { 0, 1595.5, 224.5, -122 } },
    ["Kwee Q. Peddlefeet"] = { { 1, 9669.5, 2536.5, 28 }, { 1, 9670.5, 2535, 26 } },
    ["Lunar Festival Herald"] = { { 0, 1600.5, 233, -112 } },
    ["Malakai Cross"] = { { 1, -1008, 259, -26 }, { 1, -1007, 260.5, -26 }, { 1, -1006, 260, -26 } },
    ["Nardstrum Copperpinch"] = { { 0, 1629, 218.5, -106 } },
    ["Nissa Firestone"] = { { 0, -4876.5, -1149, 10 } },
    ["Nixxrax Fillamug"] = { { 0, -14451.5, 495.5, -11 } },
    ["Noggle Ficklespragg"] = { { 1, -6852.5, 739, 12 } },
    ["Oglethorpe Obnoticus"] = { { 0, -14417, 411, 14 } },
    ["Priestess Alathea"] = { { 1, 9665.5, 2520, 26 }, { 1, 9666, 2521.5, 26 } },
    ["Sage Truthseeker"] = { { 1, -1177, 157.5, -9 }, { 1, -1176, 157.5, -9 } },
    ["Scooty"] = { { 0, -14465, 459.5, -11 } },
    ["Scout Riell"] = { { 0, -10505, 1033, 28 } },
    ["Sentinel Elissa Starbreeze"] = { { 1, 6431.5, 384, 9 } },
    ["Thurston Xane"] = { { 1, -996, 254, -36 }, { 1, -995.5, 255, -36 } },
    ["Tyrande Whisperwind"] = { { 1, 9662.5, 2524.5, 29 }, { 1, 9662.5, 2526.5, 28 } },
}
-- END npcfloors

-- BEGIN droprare
-- droprare (2.0.8, M 15 Nov 2026): the tooltip line of a loot entry with
-- dropNote = "EXTREMELY_RARE_DROP" (Zul'Farrak: Spellshock Leggings 1/440,
-- Bloodletter Scalpel 1/611).
do
    local texts = {
        enUS = "Extremely rare drop", deDE = "Extrem seltene Beute", frFR = "Butin extrêmement rare",
        esES = "Botín extremadamente raro", esMX = "Botín extremadamente raro", itIT = "Bottino estremamente raro",
        ptBR = "Saque extremamente raro", ruRU = "Чрезвычайно редкая добыча", koKR = "극히 드문 전리품",
        zhCN = "极其稀有的掉落", zhTW = "極其稀有的掉落",
    }
    for locale, text in pairs(texts) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t and t.EXTREMELY_RARE_DROP == nil then t.EXTREMELY_RARE_DROP = text end
    end
end
-- chainglowoff (2.0.8): the Quests page option that removes the glow
-- (glowstep, M 15 Nov 2026: its name says "chain step")
do
    local texts = {
        enUS = { "Remove quest glow on chain step \"Pick it up\"", "A quest whose chain you have finished, and that you can take now, glows gold in the quest list. Tick this to remove the glow (\"Pick it up\" stays)." },
        deDE = { "Questleuchten bei „Annehmen“ (Questreihen-Schritt) entfernen", "Eine Quest, deren Questreihe du abgeschlossen hast und die du jetzt annehmen kannst, leuchtet in der Questliste golden. Anhaken, um das Leuchten zu entfernen („Annehmen“ bleibt)." },
        frFR = { "Retirer la lueur des quêtes « À prendre » (étape de suite)", "Une quête dont vous avez fini la suite, et que vous pouvez prendre, brille en doré dans la liste des quêtes. Cochez pour retirer la lueur (« À prendre » reste)." },
        esES = { "Quitar el brillo de misiones «Recoger» (paso de cadena)", "Una misión cuya cadena has terminado y que ya puedes recoger brilla en dorado en la lista de misiones. Márcalo para quitar el brillo («Recoger» se queda)." },
        itIT = { "Rimuovi il bagliore delle missioni «Da prendere» (passo della catena)", "Una missione di cui hai finito la catena, e che ora puoi prendere, brilla d'oro nell'elenco delle missioni. Spunta per togliere il bagliore («Da prendere» resta)." },
        ptBR = { "Remover o brilho das missões \"Pegar\" (etapa de cadeia)", "Uma missão cuja cadeia você terminou, e que já pode pegar, brilha dourada na lista de missões. Marque para remover o brilho (\"Pegar\" continua)." },
        ruRU = { "Убрать свечение заданий «Взять» (шаг цепочки)", "Задание, цепочку которого вы прошли и которое уже можно взять, светится золотом в списке заданий. Отметьте, чтобы убрать свечение («Взять» останется)." },
        koKR = { "연계 퀘스트 단계 \"수락 가능\" 빛 효과 끄기", "연계 퀘스트를 마쳐 지금 받을 수 있는 퀘스트는 퀘스트 목록에서 금빛으로 빛납니다. 체크하면 빛 효과가 사라집니다(\"수락 가능\"은 남습니다)." },
        zhCN = { "移除任务链步骤“可以接取”的任务光效", "已完成任务链、现在可以接取的任务会在任务列表中发出金光。勾选后移除光效（“可以接取”仍会显示）。" },
        zhTW = { "移除任務鏈步驟「可以接取」的任務光效", "已完成任務鏈、現在可以接取的任務會在任務列表中發出金光。勾選後移除光效（「可以接取」仍會顯示）。" },
    }
    texts.esMX = texts.esES
    for locale, pair in pairs(texts) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            if t.OPT_HIDE_CHAIN_GLOW == nil then t.OPT_HIDE_CHAIN_GLOW = pair[1] end
            if t.OPT_HIDE_CHAIN_GLOW_TIP == nil then t.OPT_HIDE_CHAIN_GLOW_TIP = pair[2] end
        end
    end
end
-- bossquest (2.0.8): the tooltip of the quest beside a boss's name
do
    local tips = {
        enUS = "Click to open the quest", deDE = "Klicken, um die Quest zu öffnen", frFR = "Cliquez pour ouvrir la quête",
        esES = "Haz clic para abrir la misión", esMX = "Haz clic para abrir la misión", itIT = "Clicca per aprire la missione",
        ptBR = "Clique para abrir a missão", ruRU = "Нажмите, чтобы открыть задание", koKR = "클릭하여 퀘스트 열기",
        zhCN = "点击打开任务", zhTW = "點擊打開任務",
    }
    for locale, text in pairs(tips) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t and t.BOSS_QUEST_TIP == nil then t.BOSS_QUEST_TIP = text end
    end
end
-- END droprare

-- BEGIN rarelabels
-- darkreaver (2.0.8, M 15 Nov 2026): a boss's own label in place of "Rare"
-- (rareLabel), in the player's language when it is listed here.
do
    local LABELS = {
        ["Paladin Mount Quest Boss"] = {
            deDE = "Paladin-Reittierquest-Boss", frFR = "Boss quête monture paladin",
            esES = "Jefe misión montura paladín", esMX = "Jefe misión montura paladín",
            itIT = "Boss destriero paladino", ptBR = "Chefe montaria de paladino",
            ruRU = "Босс квеста коня паладина", koKR = "성기사 탈것 퀘스트 보스",
            zhCN = "圣骑士坐骑任务首领", zhTW = "聖騎士坐騎任務首領",
        },
        -- warlockmount (2.1.2): Lord Hel'nurath (Dire Maul: West)
        ["Warlock Mount Quest Boss"] = {
            deDE = "Hexenmeister-Reittierquest-Boss", frFR = "Boss quête monture démoniste",
            esES = "Jefe misión montura brujo", esMX = "Jefe misión montura brujo",
            itIT = "Boss destriero stregone", ptBR = "Chefe montaria de bruxo",
            ruRU = "Босс квеста коня чернокнижника", koKR = "흑마법사 탈것 퀘스트 보스",
            zhCN = "术士坐骑任务首领", zhTW = "術士坐騎任務首領",
        },
        -- isalien (2.1.1): the Dungeon Set 2 (Tier 0.5) bosses' label (Isalien,
        -- Kormok, Mor Grayhoof, Jarien and Sothos, Theldren, Lord Valthalak)
        ["0.5 Quest Event"] = {
            deDE = "0.5-Questereignis", frFR = "Événement de quête 0.5",
            esES = "Evento de misión 0.5", esMX = "Evento de misión 0.5",
            itIT = "Evento missione 0.5", ptBR = "Evento de missão 0.5",
            ruRU = "Событие задания 0.5", koKR = "0.5 퀘스트 이벤트",
            zhCN = "0.5任务事件", zhTW = "0.5任務事件",
        },
    }
    function FDJ.RareLabelText(label)
        if type(label) ~= "string" then return nil end
        local byLang = LABELS[label]
        local lang = FDJ.GetLanguage and FDJ.GetLanguage() or nil
        return (byLang and lang and byLang[lang]) or label
    end
end
-- END rarelabels

-- BEGIN questrowtrial
-- questrowtrial (2.0.8, M 15 Nov 2026, tried on The Deadmines and Scarlet Monastery: Library first): the
-- quest list of these dungeons shows the character's own faction only
-- (unless "Show both factions' quests" is on in the options; the crest at
-- the top is the character's, locked), and its rows have no faction crests:
-- in their place a round ! (as big as the turn-in ?) that shows how to pick
-- the quest up, with "Pick it up" beside it once its quest chain is done.
FDJ.QUESTROW_TRIAL = {
    ["The Deadmines"] = true,
    ["Scarlet Monastery: Library"] = true, -- (M, 15 Nov 2026: "now do the same for scarlet lib quests")
}
-- questrowall (2.0.8, M 15 Nov 2026: "roll this update for every single
-- dungeon"): every dungeon's quest list now (the list above is what was
-- tried first).
FDJ.QUESTROW_ALL = true
do
    local strings = {
        enUS = { "Pick it up", "How to pick it up", "Its quest chain first: %s", "Show both factions' quests",
            "Lets you switch a dungeon's quest list to the other faction's quests (the crests at the top of the list). Off: you only see your own faction's quests.",
            "Your faction's quests. To see the other faction's too: Options, \"Show both factions' quests\".", "Show pickup on map" },
        deDE = { "Annehmen", "So nimmst du sie an", "Erst die Questreihe: %s", "Quests beider Fraktionen anzeigen",
            "Lässt dich die Questliste eines Dungeons auf die Quests der anderen Fraktion umschalten (die Wappen oben in der Liste). Aus: Du siehst nur die Quests deiner Fraktion.",
            "Die Quests deiner Fraktion. Um auch die der anderen zu sehen: Optionen, \"Quests beider Fraktionen anzeigen\".", "Annahmeort auf der Karte zeigen" },
        frFR = { "À prendre", "Comment la prendre", "D'abord sa suite de quêtes : %s", "Afficher les quêtes des deux factions",
            "Permet d'afficher dans la liste des quêtes d'un donjon celles de l'autre faction (les blasons en haut de la liste). Désactivé : vous ne voyez que les quêtes de votre faction.",
            "Les quêtes de votre faction. Pour voir aussi celles de l'autre : Options, « Afficher les quêtes des deux factions ».", "Afficher sur la carte où la prendre" },
        esES = { "Recoger", "Cómo conseguirla", "Primero su cadena de misiones: %s", "Mostrar misiones de ambas facciones",
            "Te deja cambiar la lista de misiones de una mazmorra a las de la otra facción (los blasones de arriba de la lista). Desactivado: solo ves las misiones de tu facción.",
            "Las misiones de tu facción. Para ver también las de la otra: Opciones, «Mostrar misiones de ambas facciones».", "Mostrar en el mapa dónde conseguirla" },
        itIT = { "Da prendere", "Come prenderla", "Prima la sua catena di missioni: %s", "Mostra le missioni di entrambe le fazioni",
            "Ti permette di passare l'elenco delle missioni di un'istanza a quelle dell'altra fazione (gli stemmi in cima all'elenco). Disattivato: vedi solo le missioni della tua fazione.",
            "Le missioni della tua fazione. Per vedere anche quelle dell'altra: Opzioni, «Mostra le missioni di entrambe le fazioni».", "Mostra sulla mappa dove prenderla" },
        ptBR = { "Pegar", "Como pegá-la", "Primeiro a cadeia de missões: %s", "Mostrar missões das duas facções",
            "Permite trocar a lista de missões de uma masmorra para as da outra facção (os brasões no topo da lista). Desligado: você só vê as missões da sua facção.",
            "As missões da sua facção. Para ver também as da outra: Opções, \"Mostrar missões das duas facções\".", "Mostrar no mapa onde pegá-la" },
        ruRU = { "Взять", "Как взять задание", "Сначала цепочка заданий: %s", "Показывать задания обеих фракций",
            "Позволяет переключать список заданий подземелья на задания другой фракции (гербы вверху списка). Выкл.: видны только задания вашей фракции.",
            "Задания вашей фракции. Чтобы видеть и задания другой: Настройки, «Показывать задания обеих фракций».", "Показать на карте, где взять" },
        koKR = { "수락 가능", "퀘스트 받는 방법", "먼저 연계 퀘스트: %s", "양 진영 퀘스트 보기",
            "던전 퀘스트 목록을 다른 진영의 퀘스트로 바꿀 수 있습니다(목록 위의 문장). 끄기: 자신의 진영 퀘스트만 보입니다.",
            "자신의 진영 퀘스트입니다. 다른 진영 퀘스트도 보려면: 설정, \"양 진영 퀘스트 보기\".", "받는 곳을 지도에 표시" },
        zhCN = { "可以接取", "如何接取", "先完成任务链：%s", "显示两个阵营的任务",
            "可以将副本的任务列表切换为另一阵营的任务（列表顶部的徽记）。关闭：只显示你所在阵营的任务。",
            "你所在阵营的任务。要同时查看另一阵营的任务：选项，“显示两个阵营的任务”。", "在地图上显示接取地点" },
        zhTW = { "可以接取", "如何接取", "先完成任務鏈：%s", "顯示兩個陣營的任務",
            "可以將副本的任務列表切換為另一陣營的任務（列表頂部的徽記）。關閉：只顯示你所在陣營的任務。",
            "你所在陣營的任務。要同時查看另一陣營的任務：選項，「顯示兩個陣營的任務」。", "在地圖上顯示接取地點" },
    }
    strings.esMX = strings.esES
    local keys = { "PICK_IT_UP", "PICKUP_HOW", "PICKUP_CHAIN_FIRST", "OPT_BOTH_FACTIONS", "OPT_BOTH_FACTIONS_TIP", "FACTION_LOCKED_TIP", "PICKUP_ON_MAP" }
    for locale, texts in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            for i, key in ipairs(keys) do
                if t[key] == nil then t[key] = texts[i] end
            end
        end
    end
end
-- END questrowtrial

-- BEGIN npcupstairs
-- upstairs (2.0.8, M 15 Nov 2026): quest NPCs up a flight of stairs inside a
-- building (Raleigh the Devout: upstairs in the Southshore inn). Once the
-- arrow shows the NPC's portrait (the NPC is in reach), it says "Go
-- upstairs" under the yards.
FDJ.NPC_UPSTAIRS = {
    ["Raleigh the Devout"] = true,
    ["Ashe Amberhall"] = true, -- upnpc (2.1.1): top floor of Farholde Keep's tower, Riverglades
}
do
    local strings = {
        enUS = "Go upstairs", deDE = "Geh nach oben", frFR = "Montez à l'étage", esES = "Sube al piso de arriba",
        itIT = "Sali al piano di sopra", ptBR = "Suba as escadas", ruRU = "Поднимитесь наверх",
        koKR = "위층으로 올라가세요", zhCN = "上楼", zhTW = "上樓",
    }
    strings.esMX = strings.esES
    for locale, text in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t and t.ARROW_GO_UP == nil then t.ARROW_GO_UP = text end
    end
end
-- END npcupstairs

-- BEGIN questrp
-- questrp (2.0.8, M 15 Nov 2026): a quest whose hand-in starts a little scene
-- before the NPC offers the next quest (Down the Scarlet Path: Raleigh the
-- Devout breaks the seal on Anton's letter, reads it, speaks, throws it on
-- the table; then In the Name of the Light). The arrow stays on the NPC and
-- says "Wait for the RP" until the scene's last line (lines = how many the
-- NPC says or emotes); the time it took is kept, so the next time it counts
-- down. The lines: AzerothCore creature_text, NPC 3980 (SOURCES.txt).
FDJ.QUEST_RP = {
    [1052] = { npc = 3980, name = "Raleigh the Devout", lines = 3 },
}
do
    local strings = {
        enUS = { "Wait for the RP", "Wait for the RP (%ds)" },
        deDE = { "Warte auf die Szene", "Warte auf die Szene (%d s)" },
        frFR = { "Attendez la fin de la scène", "Attendez la fin de la scène (%d s)" },
        esES = { "Espera a que termine la escena", "Espera a que termine la escena (%d s)" },
        itIT = { "Aspetta la fine della scena", "Aspetta la fine della scena (%d s)" },
        ptBR = { "Aguarde o fim da cena", "Aguarde o fim da cena (%d s)" },
        ruRU = { "Дождитесь конца сценки", "Дождитесь конца сценки (%d с)" },
        koKR = { "장면이 끝날 때까지 기다리세요", "장면이 끝날 때까지 기다리세요 (%d초)" },
        zhCN = { "等待剧情结束", "等待剧情结束（%d秒）" },
        zhTW = { "等待劇情結束", "等待劇情結束（%d秒）" },
    }
    strings.esMX = strings.esES
    for locale, pair in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            if t.ARROW_RP_WAIT == nil then t.ARROW_RP_WAIT = pair[1] end
            if t.ARROW_RP_WAIT_TIME == nil then t.ARROW_RP_WAIT_TIME = pair[2] end
        end
    end
end
-- END questrp

-- BEGIN dalaranquests
-- Kirin Tor quests from Archmage Lan'dalock in Dalaran (Alterac Mountains),
-- seen in the game on 2026-11-06. Alliance for now: Dalaran is where the
-- Alliance lands from Zephras Isle (the Horde lands in Mulgore).
-- Their quest IDs are not public yet. Each has a stand-in ID until the game
-- names it: the quest in the log (any language: the quest's own item among
-- its objectives) or at the quest giver (English title). The real ID is then
-- used and remembered (ForeverDungeonJournalDB.learnedQuestIDs).
do
    local LANDALOCK = { mapID = 1416, x = 0.154, y = 0.738, label = "Archmage Lan'dalock — Dalaran", targetName = "Archmage Lan'dalock" }
    local ADDED = {
        -- Blackmaw Hold and Shaper's Terrace (Horde players' quest logs, Nov
        -- 2026): not on Wowhead yet. Ekkal stands at the Ruins of Eldarath
        -- (Wowhead Forever's spawn of NPC 235903).
        { dungeon = "Blackmaw Hold", quest = {
            id = 97327, -- real ID (Wowhead Forever, forever-tool); was stand-in -97201
            learnTitle = "Blackmaw Pouches",
            learnItem = 273050,
            name = "Blackmaw Pouches",
            level = 60,
            requires = 55,
            faction = "Both",
            pickup = "Ekkal, Ruins of Eldarath, Azshara (42.0, 38.9)", -- blackmawaudit (2.0.36)
            objective = "Enter Blackmaw Hold and recover 5 Blackmaw Pouches for Ekkal at the Ruins of Eldarath in Azshara.",
            turnin = "Ekkal, Ruins of Eldarath, Azshara (42.0, 38.9)",
            rewardSummary = "90s  •  Timbermaw Hold +150",
            liveXPFallback = 13200,
            requiredItem = { 273050, "Blackmaw Pouch", 1, 5, "From the Blackmaw furbolgs inside Blackmaw Hold" },
            note = "Afterwards Ekkal takes more pouches as a repeatable quest (Timbermaw Hold +100).",
            startMap = { mapID = 1447, x = 0.420, y = 0.389, label = "Ekkal — Ruins of Eldarath, Azshara", targetName = "Ekkal" },
            turninMap = { mapID = 1447, x = 0.420, y = 0.389, label = "Ekkal — Ruins of Eldarath, Azshara", targetName = "Ekkal" },
        } },
        -- shapersquests (2.0.4): real IDs, XP and reputation from Wowhead
        -- Forever (quest tooltips) and ForeverChanges, cross-checked with the
        -- reported research (Shaper's Terrace Quest Research, 11 Nov 2026).
        -- shapersgivers (2.0.41): four givers from the Shaper's Terrace Quest
        -- Audit (13 Nov 2026, Questie-derived Forever data) and forg.gg's
        -- quest pages, the places matching the NPCs' own spawn pages:
        -- Chemist Fuely and Master Apothecary Faranell (Undercity), Curator
        -- Thorius (Ironforge). Turn-ins are not known yet; Digestible
        -- Research's start is still not known.
        -- 2.0.43: the Alliance three are handed in to Curator Thorius
        -- (Wowhead Forever quest pages, M's screenshots, 13 Nov 2026).
        -- 2.0.44: the Horde two are handed in to their givers (M, in game:
        -- the quest texts ask you to bring the items back to them).
        -- 2.0.45: Digestible Research starts from the Partially Digested
        -- Journal, an object lying on the ground inside the dungeon (the
        -- Verdant Plains); clicking it gives the quest, no item (a player's
        -- screenshot and M, 13 Nov 2026).
        { dungeon = "Shaper's Terrace", quest = {
            id = 97049, -- real ID (Wowhead Forever, ForeverChanges); was stand-in -97202
            learnTitle = "Essence of Seeping Slimes",
            learnItem = 276235,
            name = "Essence of Seeping Slimes",
            level = 60,
            requires = 55,
            faction = "Horde",
            pickup = "Chemist Fuely, The Apothecarium, Undercity (47.5, 73.3)",
            objective = "Gather 8 Seeping Slime Essence in the Shaper's Terrace.",
            turnin = "Chemist Fuely, The Apothecarium, Undercity (47.5, 73.3)",
            turninMap = { mapID = 1458, x = 0.475, y = 0.733, label = "Chemist Fuely — Undercity", targetName = "Chemist Fuely" },
            liveXPFallback = 17650,
            rewardSummary = "90s  •  Undercity +100  •  Orgrimmar +50",
            rewardItems = { {279932, "Slime-Resistant Shroud", 3}, {279902, "Reinforced Muck Protectors", 3} },
            rewardChoice = true,
            requiredItem = { 276235, "Seeping Slime Essence", 1, 8, "From the slimes in the pools inside Shaper's Terrace" },
            startMap = { mapID = 1458, x = 0.475, y = 0.733, label = "Chemist Fuely — Undercity", targetName = "Chemist Fuely" },
        } },
        { dungeon = "Shaper's Terrace", quest = {
            id = 95926, -- real ID (Wowhead Forever, ForeverChanges); was stand-in -97203
            learnTitle = "The Dark Crystal",
            learnItem = 271771,
            name = "The Dark Crystal",
            level = 60,
            requires = 55,
            faction = "Horde",
            pickup = "Master Apothecary Faranell, The Apothecarium, Undercity (48.8, 69.3)",
            objective = "Gather a colorless Drained Crystal Fragment near the Achromatic Crystal in the Shaper's Terrace.",
            turnin = "Master Apothecary Faranell, The Apothecarium, Undercity (48.8, 69.3)",
            turninMap = { mapID = 1458, x = 0.488, y = 0.693, label = "Master Apothecary Faranell — Undercity", targetName = "Master Apothecary Faranell" },
            liveXPFallback = 17650,
            rewardSummary = "Undercity +100  •  Orgrimmar +50",
            rewardItems = { {279908, "Crystal-Infused Cleaver", 3}, {279910, "Beastslayer's Trident", 3}, {279912, "Faintly Glowing Orb", 3} },
            rewardChoice = true,
            requiredItem = { 271771, "Drained Crystal Fragment", 1, 1, "Near the Achromatic Crystal inside Shaper's Terrace" },
            startMap = { mapID = 1458, x = 0.488, y = 0.693, label = "Master Apothecary Faranell — Undercity", targetName = "Master Apothecary Faranell" },
        } },
        -- The Alliance's three (reported, 11 Nov 2026).
        { dungeon = "Shaper's Terrace", quest = {
            id = 95924, -- Wowhead Forever, ForeverChanges
            learnTitle = "Panic at the Digsite",
            name = "Panic at the Digsite",
            level = 60,
            requires = 55,
            faction = "Alliance",
            pickup = "Curator Thorius, Hall of Explorers, Ironforge (71.5, 15.7)",
            objective = "Slay Venomridge, 6 Ravasaur Matriarchs and 8 Ironhide Ravasaurs in Shaper's Terrace.",
            turnin = "Curator Thorius, Hall of Explorers, Ironforge (71.5, 15.7)",
            turninMap = { mapID = 1455, x = 0.715, y = 0.157, label = "Curator Thorius — Hall of Explorers, Ironforge", targetName = "Curator Thorius" },
            liveXPFallback = 17650,
            rewardSummary = "90s  •  Ironforge +100  •  Stormwind +50",
            rewardItems = { {279903, "Diemetradon Scale Spaulders", 3}, {279905, "Ravasaur Hide Footpads", 3} },
            rewardChoice = true,
            note = "The quest text asks for 9 Ironhide Ravasaurs, its objective counts 8.",
            startMap = { mapID = 1455, x = 0.715, y = 0.157, label = "Curator Thorius — Hall of Explorers, Ironforge", targetName = "Curator Thorius" },
        } },
        { dungeon = "Shaper's Terrace", quest = {
            id = 95925, -- Wowhead Forever, ForeverChanges
            learnTitle = "Mapping the Way Forward",
            name = "Mapping the Way Forward",
            level = 60,
            requires = 55,
            faction = "Alliance",
            pickup = "Curator Thorius, Hall of Explorers, Ironforge (71.5, 15.7)",
            objective = "Find Interesting Landmarks in Shaper's Terrace and fill out the explorer's map at each: the Pillar of Assimilation, the Achromatic Crystal, the Western Gates, the Regrowth Vestibule and the Unearthed Stone Watcher.",
            turnin = "Curator Thorius, Hall of Explorers, Ironforge (71.5, 15.7)",
            turninMap = { mapID = 1455, x = 0.715, y = 0.157, label = "Curator Thorius — Hall of Explorers, Ironforge", targetName = "Curator Thorius" },
            liveXPFallback = 17650,
            rewardSummary = "Ironforge +100  •  Stormwind +50",
            rewardItems = { {279908, "Crystal-Infused Cleaver", 3}, {279910, "Beastslayer's Trident", 3}, {279912, "Faintly Glowing Orb", 3} },
            rewardChoice = true,
            note = "You map them with an Explorers' League Cartographer's Kit.",
            startMap = { mapID = 1455, x = 0.715, y = 0.157, label = "Curator Thorius — Hall of Explorers, Ironforge", targetName = "Curator Thorius" },
        } },
        -- Digestible Research: real ID and reward item IDs from Wowhead
        -- Forever (quest 95790; was the stand-in -97204 until 2.0.3).
        { dungeon = "Shaper's Terrace", quest = {
            id = 95790,
            learnTitle = "Digestible Research",
            name = "Digestible Research",
            level = 60,
            requires = 55,
            faction = "Alliance",
            pickup = "The Partially Digested Journal lying on the ground inside Shaper's Terrace (the Verdant Plains): click it to get the quest",
            objective = "Collect 15 Partially Digested Journal Pages in Shaper's Terrace.",
            turnin = "Curator Thorius, Hall of Explorers, Ironforge (71.5, 15.7)",
            turninMap = { mapID = 1455, x = 0.715, y = 0.157, label = "Curator Thorius — Hall of Explorers, Ironforge", targetName = "Curator Thorius" },
            rewardSummary = "Ironforge +100  •  Stormwind +100",
            liveXPFallback = 17650,
            rewardItems = { {279931, "Lost Researcher's Hood", 3}, {279901, "Expeditionary Legplates", 3} },
            rewardChoice = true,
            note = "Starts from the Partially Digested Journal on the ground inside the dungeon.",
        } },
        { dungeon = "Razorfen Downs", quest = {
            id = 96773,
            learnTitle = "The Coldbringer's Eye",
            learnItem = 276916,
            name = "The Coldbringer's Eye",
            level = 41,
            requires = 34,
            faction = "Alliance",
            pickup = "Archmage Lan'dalock, Dalaran, Alterac Mountains",
            objective = "Recover The Coldbringer's Eye from Razorfen Downs.",
            turnin = "Archmage Lan'dalock, Dalaran, Alterac Mountains",
            liveXPFallback = 8600,
            rewardSummary = "55s",
            requiredItem = { 276916, "The Coldbringer's Eye", 1, 1, "From Amnennar the Coldbringer, the last boss of Razorfen Downs" },
            -- Archmage Lan'dalock gives it (a player's screenshot, Nov 2026).
            startMap = LANDALOCK,
            turninMap = LANDALOCK,
        } },
        -- Its real ID is on Wowhead Forever now (96770; level 46, from 39).
        { dungeon = "Zul'Farrak", quest = {
            id = 96770,
            learnTitle = "The Witch Doctor's Head",
            learnItem = 277112,
            name = "The Witch Doctor's Head",
            level = 46,
            requires = 39,
            faction = "Alliance",
            pickup = "Archmage Lan'dalock, Dalaran, Alterac Mountains",
            objective = "Slay Witch Doctor Zum'rah and bring Zum'rah's Head to Archmage Lan'dalock in Dalaran.",
            turnin = "Archmage Lan'dalock, Dalaran, Alterac Mountains",
            liveXPFallback = 10100,
            rewardSummary = "1g 30s  •  Kirin Tor +300",
            requiredItem = { 277112, "Zum'rah's Head", 1, 1, "From Witch Doctor Zum'rah, Zul'Farrak" },
            startMap = LANDALOCK,
            turninMap = LANDALOCK,
        } },
        -- The Horde side: Mazu'kon of the Earthen Ring on the Skywatcher
        -- Plateau in Mulgore (a player, Nov 2026; Wowhead Forever quest
        -- 96775: level 46, from 42, 10,100 XP, 65s, reputation).
        { dungeon = "Zul'Farrak", quest = {
            id = 96775,
            learnTitle = "Zum'rah's Head",
            learnItem = 277112,
            name = "Zum'rah's Head",
            level = 46,
            requires = 42,
            faction = "Horde",
            pickup = "Mazu'kon, Skywatcher Plateau, Mulgore",
            objective = "Slay Witch Doctor Zum'rah and bring Zum'rah's Head to Mazu'kon in Mulgore.",
            turnin = "Mazu'kon, Skywatcher Plateau, Mulgore",
            liveXPFallback = 10100,
            rewardSummary = "65s  •  Earthen Ring +300  •  Darkspear Trolls +150",
            requiredItem = { 277112, "Zum'rah's Head", 1, 1, "From Witch Doctor Zum'rah, Zul'Farrak" },
            startMap = FDJ.QUEST_START_MAPS[96774],
            turninMap = FDJ.QUEST_START_MAPS[96774],
        } },
        -- Alcaz Prison (a stream, 2026-11-07): given inside the prison by
        -- Commander Folkar (NPC 260386), handed in to Thrall. Its level is
        -- not known yet: the dungeon's range is used.
        { dungeon = "Alcaz Prison", quest = {
            id = 95483,
            learnTitle = "Thrall Needs to Know",
            name = "Thrall Needs to Know",
            level = 53,
            requires = 48,
            faction = "Horde",
            pickup = "Commander Folkar, inside Alcaz Prison",
            objective = "Bring word of Varian Wrynn's fate to Thrall in Orgrimmar.",
            turnin = "Thrall, Valley of Wisdom, Orgrimmar (32.0, 37.8)",
            rewardSummary = "",
            rewards = "Choose: Fatebound Buckler, Courier's Clasp or Dustwallow Dirk\n2,400 XP • Orgrimmar +100",
            -- Item IDs: Wowhead Forever (all three rare).
            rewardChoice = true,
            rewardItems = { { 279831, "Fatebound Buckler", 3 }, { 279833, "Courier's Clasp", 3 }, { 279474, "Dustwallow Dirk", 3 } },
            liveXPFallback = 2400,
            turninMap = { mapID = 1454, x = 0.320, y = 0.378, label = "Thrall — Orgrimmar", targetName = "Thrall" },
        } },
        -- alcazquests (1.9.5, players' screenshots): the Kor'kron's masks
        -- quest. Who gives it is not known yet: its text is a Kor'kron's
        -- who fought the Defias there. Level not known yet: the dungeon's.
        { dungeon = "Alcaz Prison", quest = {
            id = 96334,
            learnTitle = "Blood Red Bandanas",
            learnItem = 274028,
            name = "Blood Red Bandanas",
            level = 50,
            requires = 48,
            faction = "Horde",
            pickup = "Sergeant Ulka, outside Alcaz Prison, Alcaz Island, Dustwallow Marsh (70.2, 18.8)",
            objective = "Enter Alcaz Prison and collect 8 Blood Red Bandanas from the human guards there.",
            turnin = "Eitrigg, Grommash Hold, Orgrimmar",
            liveXPFallback = 9700,
            rewardSummary = "",
            rewardChoice = true,
            rewardItems = { { 279448, "Bloodsplattered Bandana", 2 }, { 279473, "Makeshift Belt", 2 } },
            requiredItem = { 274028, "Blood Red Bandana", 1, 8, "From the Defias guards in Alcaz Prison" },
            turninMap = { mapID = 1454, x = 0.344, y = 0.386, label = "Eitrigg — Grommash Hold, Orgrimmar", targetName = "Eitrigg" },
        } },
        -- The naga's quest (a player's quest log, 1.9.6): level 53. Who gives
        -- it and takes it back is not known yet; seen by a Horde player.
        { dungeon = "Alcaz Prison", quest = {
            id = 96332,
            learnTitle = "A Little Payback",
            learnItem = 273883,
            name = "A Little Payback",
            level = 53,
            requires = 48,
            faction = "Horde",
            pickup = "Sergeant Ulka, outside Alcaz Prison, Alcaz Island, Dustwallow Marsh (70.2, 18.8)",
            objective = "Enter the Alcaz Prison and slay 15 Strashaz Soldiers, 8 Strashaz Enchantresses, and bring the head of Tidemistress Ca'zass to Sergeant Ulka.",
            turnin = "Sergeant Ulka, outside Alcaz Prison, Alcaz Island, Dustwallow Marsh (70.2, 18.8)",
            liveXPFallback = 9700,
            rewardSummary = "Orgrimmar +75",
            rewards = "Choose: Kor'kron Battle Gauntlets, Marshdweller's Pants or Naga Scale Spaulders\n9,700 XP • Orgrimmar +75",
            rewardChoice = true,
            rewardItems = { { 279824, "Kor'kron Battle Gauntlets", 2 }, { 279826, "Marshdweller's Pants", 2 }, { 279829, "Naga Scale Spaulders", 2 } },
            requiredItem = { 273883, "Ca'zass's Head", 1, 1, "From Tidemistress Ca'zass in Alcaz Prison" },
        } },
    }

    local pending = {} -- stand-in ID -> quest
    for _, add in ipairs(ADDED) do
        local d = FDJ.DB and FDJ.DB[add.dungeon]
        if d then
            d.quests = d.quests or {}
            local have = false
            for _, q in ipairs(d.quests) do
                if q.name == add.quest.name and q.faction == add.quest.faction then have = true end
            end
            if not have then
                table.insert(d.quests, add.quest)
                if add.quest.id < 0 then pending[add.quest.id] = add.quest end
                if FDJ.QUEST_START_MAPS then FDJ.QUEST_START_MAPS[add.quest.id] = add.quest.startMap end
            end
        end
    end

    -- alcazquests (1.9.5): Thrall Needs to Know comes at the end of a chain
    -- (players' screenshots): Sergeant Ulka, outside the prison, sends you
    -- in after Commander Folkar (No Orc Left Behind); he sends you on to find
    -- King Varian Wrynn (The Honor of the Kor'kron, handed in at the Perfumed
    -- Note after Blazeroar), then back to Thrall. The steps' IDs are not
    -- public either: stand-ins, learnt like the quests'.
    local ULKA = { mapID = 1445, x = 0.702, y = 0.188, label = "Sergeant Ulka — Dustwallow Marsh", targetName = "Sergeant Ulka", detail = "Sergeant Ulka, outside Alcaz Prison on Alcaz Island" }
    FDJ.QUEST_PREREQ_CHAINS[95483] = {
        { id = 95309, name = "No Orc Left Behind" },
        { id = 95454, name = "The Honor of the Kor'kron" },
        { id = 96369, name = "Bad News for Folkar" },
    }
    FDJ.QUEST_PREREQ_DETAILS[95309] = {
        level = 53, requires = 48,
        objective = "Find Commander Folkar inside Alcaz Prison.",
        pickup = "Sergeant Ulka, outside Alcaz Prison, Dustwallow Marsh (70.2, 18.8)",
        turnin = "Commander Folkar, inside Alcaz Prison",
        map = ULKA,
    }
    FDJ.QUEST_PREREQ_DETAILS[95454] = {
        level = 53, requires = 48,
        objective = "Look for King Varian Wrynn in Alcaz Prison.",
        pickup = "Commander Folkar, inside Alcaz Prison",
        turnin = "Perfumed Note, after Blazeroar, inside Alcaz Prison",
    }
    -- 1.9.6: the note sends you back to Folkar, who then gives Thrall Needs
    -- to Know.
    FDJ.QUEST_PREREQ_DETAILS[96369] = {
        level = 53, requires = 48,
        objective = "Tell Commander Folkar what you found.",
        pickup = "Perfumed Note, after Blazeroar, inside Alcaz Prison",
        turnin = "Commander Folkar, inside Alcaz Prison",
    }
    if FDJ.FOREVER_QUEST_XP_FALLBACK then
        FDJ.FOREVER_QUEST_XP_FALLBACK[95309] = 12100
        FDJ.FOREVER_QUEST_XP_FALLBACK[95454] = 12100
        FDJ.FOREVER_QUEST_XP_FALLBACK[96369] = 2400
    end

    local function Plain(v)
        if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
        return v
    end

    local function Saved()
        ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
        if type(ForeverDungeonJournalDB.learnedQuestIDs) ~= "table" then ForeverDungeonJournalDB.learnedQuestIDs = {} end
        return ForeverDungeonJournalDB.learnedQuestIDs
    end

    -- The stand-in ID becomes the real one everywhere the journal keeps it.
    local function Use(standIn, real, quiet)
        local quest = pending[standIn]
        if not quest or type(real) ~= "number" or real <= 0 then return end
        pending[standIn] = nil
        for _, d in pairs(FDJ.DB or {}) do
            for _, q in ipairs((type(d) == "table" and d.quests) or {}) do
                if q.id == standIn then q.id = real end
            end
        end
        local maps = FDJ.QUEST_START_MAPS
        if maps and maps[standIn] ~= nil then
            if maps[real] == nil then maps[real] = maps[standIn] end
            maps[standIn] = nil
        end
        -- alcazquests: the chain it heads or is a step of, its chain page
        -- and its XP go with it.
        local chains = FDJ.QUEST_PREREQ_CHAINS
        if chains then
            if chains[standIn] ~= nil then
                if chains[real] == nil then chains[real] = chains[standIn] end
                chains[standIn] = nil
            end
            for _, chain in pairs(chains) do
                for _, step in ipairs(type(chain) == "table" and chain or {}) do
                    if type(step) == "table" and step.id == standIn then step.id = real end
                end
            end
        end
        for _, t in ipairs({ FDJ.QUEST_PREREQ_DETAILS, FDJ.FOREVER_QUEST_XP_FALLBACK, FDJ.QUEST_SHAREABILITY_AUDIT }) do
            if type(t) == "table" and t[standIn] ~= nil then
                if t[real] == nil then t[real] = t[standIn] end
                t[standIn] = nil
            end
        end
        Saved()[quest.learnTitle] = real
        if not quiet then
            if FDJ.RPGStateChanged then pcall(FDJ.RPGStateChanged) end
            if FDJ.ScheduleQuestRefresh then pcall(FDJ.ScheduleQuestRefresh) end
        end
    end

    local function ItemName(id)
        local name
        if C_Item and C_Item.GetItemNameByID then
            local ok, n = pcall(C_Item.GetItemNameByID, id)
            if ok then name = Plain(n) end
        end
        if not name and GetItemInfo then
            local ok, n = pcall(GetItemInfo, id)
            if ok then name = Plain(n) end
        end
        if not name and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
        return type(name) == "string" and name ~= "" and name or nil
    end

    -- A quest the game names (log or giver window): one of ours?
    function FDJ.LearnQuestID(questID, title)
        questID = tonumber(Plain(questID))
        if not questID or questID <= 0 or not next(pending) then return end
        for _, q in pairs(FDJ.DB or {}) do
            for _, e in ipairs((type(q) == "table" and q.quests) or {}) do
                if e.id == questID then return end -- already known
            end
        end
        title = Plain(title)
        local faction = UnitFactionGroup and Plain(UnitFactionGroup("player"))
        for standIn, quest in pairs(pending) do
            if quest.faction == "Both" or quest.faction == faction then
                local hit = type(title) == "string" and title:lower() == quest.learnTitle:lower()
                if not hit and quest.learnItem and C_QuestLog and C_QuestLog.GetQuestObjectives then
                    local item = ItemName(quest.learnItem)
                    local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
                    if item and ok and type(objectives) == "table" then
                        for _, o in ipairs(objectives) do
                            local text = type(o) == "table" and Plain(o.text)
                            if type(text) == "string" and text:find(item, 1, true) then hit = true break end
                        end
                    end
                end
                if hit then return Use(standIn, questID) end
            end
        end
    end

    -- Learned before (any character of this account), and quests accepted
    -- now: known before the rest of the journal hears of them.
    local learn = CreateFrame("Frame")
    learn:RegisterEvent("PLAYER_LOGIN")
    learn:RegisterEvent("QUEST_ACCEPTED")
    learn:SetScript("OnEvent", function(_, event, a, b)
        if event == "PLAYER_LOGIN" then
            local saved = Saved()
            for standIn, quest in pairs(pending) do
                if type(saved[quest.learnTitle]) == "number" then Use(standIn, saved[quest.learnTitle], true) end
            end
            return
        end
        local id = tonumber(Plain(b)) or tonumber(Plain(a))
        if not id then return end
        local title
        if C_QuestLog and C_QuestLog.GetTitleForQuestID then
            local ok, t = pcall(C_QuestLog.GetTitleForQuestID, id)
            if ok then title = t end
        end
        pcall(FDJ.LearnQuestID, id, title)
    end)
end
-- END dalaranquests

-- BEGIN alcazquests2
-- 2.0.22: every Alcaz Prison quest with its giver and the quests that lead
-- to it. Quest IDs, series, objectives and rewards: Wowhead Forever (Nov
-- 2026); XP: forever-tool / ForeverChanges; the Horde givers and the order
-- of the Kor'kron quests: Ke on the Discord (quest log screenshots); the
-- Alliance givers and the disguise tip: Wowhead comments.
do
    local db = FDJ.DB and FDJ.DB["Alcaz Prison"]
    local EITRIGG = { mapID = 1454, x = 0.344, y = 0.386, label = "Eitrigg — Grommash Hold, Orgrimmar", targetName = "Eitrigg" }
    -- nazeername (2.0.13, KILLDARK on Discord, 18 Nov 2026, "Worng NPC": the
    -- game's name is Nazeer Bloodpike, no s, so the click to target him
    -- missed; his spot: Forever client tables,
    -- spawn of NPC 4791, 35.2, 30.7 - was 36.0, 31.0, some 40 yards off)
    local NAZEER = { mapID = 1445, x = 0.352, y = 0.307, label = "Nazeer Bloodpike — Brackenwall Village, Dustwallow Marsh", targetName = "Nazeer Bloodpike" }
    local ULKA = { mapID = 1445, x = 0.702, y = 0.188, label = "Sergeant Ulka — Alcaz Island, Dustwallow Marsh", targetName = "Sergeant Ulka" }
    -- shawspot (2.0.9, Pekins on Discord, 15 Nov 2026: "more towards the
    -- south of Old Town at 79, 71"): 75.8, 59.8 was his place on the old
    -- Stormwind map; on Forever's map he stands at 78.3, 70.7 (Forever
    -- client tables, spawn of NPC 332; the same
    -- spot the journal already uses for Shaw's Report).
    local SHAW = { mapID = 1453, x = 0.783, y = 0.707, label = "Master Mathias Shaw — SI:7, Old Town, Stormwind", targetName = "Master Mathias Shaw" }
    local SULLY = { mapID = 1445, x = 0.662, y = 0.452, label = "Sully McCleary — inn, Theramore", targetName = "Sully McCleary" }
    local SULLY_OUT = { mapID = 1445, x = 0.634, y = 0.424, label = "Sully McCleary — outside Theramore, across the bridge", targetName = "Sully McCleary" }
    local LANDALOCK = { mapID = 1416, x = 0.154, y = 0.738, label = "Archmage Lan'dalock — Violet Hold entrance, Dalaran", targetName = "Archmage Lan'dalock" }
    local MOONBROOK = { mapID = 1436, x = 0.434, y = 0.678, label = "Mason Connery's treasure — Moonbrook inn, Westfall", targetName = "Loose Floorboard" }
    local AT_ULKA = "Sergeant Ulka, outside Alcaz Prison, Alcaz Island, Dustwallow Marsh (70.2, 18.8)"
    local AT_NAZEER = "Nazeer Bloodpike, Brackenwall Village, Dustwallow Marsh"
    local AT_SULLY = "Sully McCleary, in the inn in Theramore, Dustwallow Marsh (66.2, 45.2)"
    local D, C, XP = FDJ.QUEST_PREREQ_DETAILS, FDJ.QUEST_PREREQ_CHAINS, FDJ.FOREVER_QUEST_XP_FALLBACK

    -- Horde: Eitrigg > Nazeer > Sergeant Ulka, who then gives No Orc Left
    -- Behind (Thrall Needs to Know's chain), A Little Payback and Blood Red
    -- Bandanas.
    local KORKRON = {
        { id = 95283, name = "The Missing Kor'kron" },
        { id = 95284, name = "The Elite of the Elite" },
        { id = 95285, name = "Right Place, Wrong Time" },
    }
    local function With(list, extra)
        local out = {}
        for i, s in ipairs(list) do out[i] = { id = s.id, name = s.name } end
        for _, s in ipairs(extra or {}) do out[#out + 1] = { id = s.id, name = s.name } end
        return out
    end
    C[95483] = With(KORKRON, {
        { id = 95309, name = "No Orc Left Behind" },
        { id = 95454, name = "The Honor of the Kor'kron" },
        { id = 96369, name = "Bad News for Folkar" },
    })
    C[96332] = With(KORKRON)
    C[96334] = With(KORKRON)
    D[95283] = {
        level = 53, requires = 48,
        objective = "Speak with Nazeer Bloodpike in Brackenwall Village.",
        pickup = "Eitrigg, Grommash Hold (Thrall's room), Orgrimmar", turnin = AT_NAZEER,
        map = EITRIGG, turninMap = NAZEER,
    }
    D[95284] = {
        level = 53, requires = 48,
        objective = "Find the missing Kor'kron Elites.",
        pickup = AT_NAZEER, turnin = AT_ULKA, map = NAZEER, turninMap = ULKA,
        note = "Nazeer offers it even before you hand in The Missing Kor'kron.",
    }
    D[95285] = {
        level = 53, requires = 48,
        objective = "Speak with Sergeant Ulka to learn more about the situation on Alcaz Isle.",
        pickup = AT_ULKA, turnin = AT_ULKA, map = ULKA, turninMap = ULKA,
        note = "Sergeant Ulka then offers No Orc Left Behind, A Little Payback and Blood Red Bandanas.",
    }
    if D[95309] then D[95309].turninMap = nil end
    XP[95283] = 1300; XP[95284] = 1300; XP[95285] = 1300

    -- Alliance: Mathias Shaw > Sully McCleary in Theramore > eavesdropping
    -- on Jaina; Sully then gives The Secret Prison and A Bit of Wet Work.
    local SI7 = {
        { id = 95194, name = "Our Man in Theramore" },
        { id = 95196, name = "Watch Yer Back" },
        { id = 95198, name = "The Return of the King?" },
    }
    D[95194] = {
        level = 53, requires = 48,
        objective = "Seek out the SI:7 agent stationed on Theramore Isle.",
        pickup = "Master Mathias Shaw, SI:7, Old Town, Stormwind City (78.3, 70.7)", turnin = AT_SULLY,
        map = SHAW, turninMap = SULLY,
    }
    D[95196] = {
        level = 53, requires = 48,
        objective = "Meet Sully McCleary in Dustwallow Marsh and learn more about your mission.",
        pickup = AT_SULLY, turnin = "Sully McCleary, outside Theramore across the bridge, Dustwallow Marsh (63.4, 42.4)",
        map = SULLY, turninMap = SULLY_OUT,
    }
    D[95198] = {
        level = 53, requires = 48,
        objective = "Use the SI:7 Disguise Kit to eavesdrop on Jaina and her inner circle at the Theramore Mage Tower.",
        pickup = "Sully McCleary, outside Theramore across the bridge, Dustwallow Marsh (63.4, 42.4)", turnin = AT_SULLY,
        map = SULLY_OUT, turninMap = SULLY,
        providedItem = {269000, "SI:7 Disguise Kit", 1, "Given when you accept the quest"},
        note = "Up the tower, talk to the guard next to Archmage Tervosh (he looks like you in the disguise) and relieve him; don't get close to Jaina or she dispels it. You stay stuck a while after it completes: use Exit Vehicle.",
    }
    D[95262] = {
        level = 53, requires = 48,
        objective = "Enter Alcaz Prison and learn what became of the King of Stormwind.",
        pickup = AT_SULLY, turnin = "Inside Alcaz Prison (who takes it is not known yet)",
        map = SULLY,
    }
    XP[95194] = 1300; XP[95196] = 1300; XP[95198] = 1300; XP[95262] = 14400

    -- Both factions: the man in iron chains (Mason Connery, after Blazeroar)
    -- wants the key The Questioner carries; freed, he gives a note to his
    -- treasure in Westfall.
    D[96335] = {
        level = 53, requires = 48, startsInDungeon = true,
        objective = "Recover the Alcaz Shackle Key from The Questioner in Alcaz Prison.",
        pickup = "Mason Connery, the man in iron chains, inside Alcaz Prison",
        turnin = "Mason Connery, inside Alcaz Prison",
        requiredItems = { {274029, "Ornate Shackle Key", 1, "From The Questioner in Alcaz Prison"} },
    }
    XP[96335] = 2850

    local ADD = {
        {
            id = 95263, name = "Somber News", level = 53, requires = 48, faction = "Alliance",
            pickup = "Inside Alcaz Prison, once you learn what became of King Varian Wrynn",
            objective = "Return to Sully McCleary in Dustwallow Marsh.",
            turnin = AT_SULLY, turninMap = SULLY,
            liveXPFallback = 2850,
            rewardSummary = "Stormwind +75",
            rewards = "2,850 XP • Stormwind +75",
            chain = { SI7[1], SI7[2], SI7[3], { id = 95262, name = "The Secret Prison" } },
        },
        {
            id = 96381, name = "A Bit of Wet Work", level = 53, requires = 48, faction = "Alliance",
            pickup = AT_SULLY, startMap = SULLY,
            objective = "Enter the Alcaz Prison and slay 15 Strashaz Soldiers, 8 Strashaz Enchantresses, and bring the head of Tidemistress Ca'zass to Sully McCleary.",
            turnin = AT_SULLY, turninMap = SULLY,
            liveXPFallback = 11550,
            rewardSummary = "Stormwind +100  •  Ironforge +100",
            rewards = "Choose: Theramore Defender's Gauntlets, Marshdweller's Pants or Naga Scale Spaulders\n11,550 XP • Stormwind +100 • Ironforge +100",
            rewardChoice = true,
            rewardItems = { { 279825, "Theramore Defender's Gauntlets", 2 }, { 279826, "Marshdweller's Pants", 2 }, { 279829, "Naga Scale Spaulders", 2 } },
            requiredItem = { 273883, "Ca'zass's Head", 1, 1, "From Tidemistress Ca'zass in Alcaz Prison" },
            chain = SI7,
        },
        {
            id = 96337, name = "More Valuable Than Gold", level = 53, requires = 48, faction = "Both",
            warning = "Don't kill The Questioner before the last boss, or you can't get this quest.",
            pickup = "Mason Connery, inside Alcaz Prison, once you free him",
            objective = "Use the note provided by Mason Connery to find his hidden treasure.",
            turnin = "Mason Connery's treasure: a loose floorboard upstairs in the middle room of the Moonbrook inn, Westfall (43.4, 67.8)",
            turninMap = MOONBROOK,
            providedItem = {274077, "Mason's Note", 1, "Given by Mason Connery when you accept the quest"},
            liveXPFallback = 11550,
            rewardSummary = "",
            rewards = "Document Box\n11,550 XP",
            rewardItems = { { 274041, "Document Box", 1 } },
            note = "The Document Box sells for 25g, and it starts State Secrets (a Horde, an Alliance and a Steamwheedle Cartel version); who takes it is not known yet.",
            chain = { { id = 96335, name = "The Man in the Iron Chains" } },
        },
    }
    if db then
        db.quests = db.quests or {}
        for _, q in ipairs(ADD) do
            local have = false
            for _, e in ipairs(db.quests) do if e.id == q.id then have = true end end
            if not have then
                local chain = q.chain
                q.chain = nil
                C[q.id] = With(chain)
                XP[q.id] = q.liveXPFallback
                table.insert(db.quests, q)
            end
        end
        for _, q in ipairs(db.quests) do
            if q.id == 96772 then q.startMap = LANDALOCK; q.turninMap = LANDALOCK end
            if q.id == 96334 or q.id == 96332 then q.startMap = ULKA end
            if q.id == 96332 then q.turninMap = ULKA end
            if q.id == 96334 then
                q.rewardSummary = "Orgrimmar +75"
                q.rewards = "Choose: Bloodsplattered Bandana or Makeshift Belt\n9,700 XP • Orgrimmar +75"
            end
        end
    end
    FDJ.QUEST_START_MAPS[96772] = LANDALOCK
    FDJ.QUEST_START_MAPS[96332] = ULKA
    FDJ.QUEST_START_MAPS[96334] = ULKA
    FDJ.QUEST_START_MAPS[96381] = SULLY
end
-- END alcazquests2

-- BEGIN maraudonquests
-- 2.0.23: Rot and Regret's real unlock (Wowhead Forever quest pages and
-- comments, Nov 2026): the Shen'dralas pylon chain opens the area's quests;
-- Mithera at the Forlorn Gardens then gives Word of the Woods, which leads
-- to Woodwyrd. Maraudon quest XP: Forever pays about 1.95x the Classic
-- amount (Wowhead's multiplier; the values match forever-tool's).
do
    local db = FDJ.DB and FDJ.DB["Maraudon"]
    local D, C, XP = FDJ.QUEST_PREREQ_DETAILS, FDJ.QUEST_PREREQ_CHAINS, FDJ.FOREVER_QUEST_XP_FALLBACK
    local M = 2652 -- Shen'dralas
    local PYLON = { mapID = M, x = 0.436, y = 0.342, label = "Shen'dralar Pylon — Shen'dralas", targetName = "Shen'dralar Pylon" }
    local MORDENT = { mapID = M, x = 0.350, y = 0.464, label = "Mordent Evenshade — Evenshade's Overlook, Shen'dralas", targetName = "Mordent Evenshade" }
    local KIRANDIS = { mapID = M, x = 0.472, y = 0.758, label = "Magister Kirandis — temple of Shen'dralas", targetName = "Magister Kirandis" }
    local MITHERA = { mapID = M, x = 0.528, y = 0.760, label = "Mithera — by the Forlorn Gardens, Shen'dralas", targetName = "Mithera" }
    -- woodwyrdspot (2.0.13, M 19 Nov 2026, his map's ? for Word of the Woods at 69.9, 72.1; was a guess by Mithera)
    local WOODWYRD = { mapID = M, x = 0.699, y = 0.721, label = "Woodwyrd — Forlorn Gardens, Shen'dralas", targetName = "Woodwyrd" }
    local AT_MORDENT = "Mordent Evenshade, Evenshade's Overlook, Shen'dralas (35.0, 46.4)"
    local AT_WOODWYRD = "Woodwyrd, Forlorn Gardens, Shen'dralas (69.9, 72.1)"

    C[93404] = {
        { id = 92914, name = "Strange Pylons" },
        { id = 96010, name = "Fragments of the Pylons" },
        { id = 96018, name = "Powering the Pylons" },
        { id = 93016, name = "A Brief History Lesson" },
        { id = 93394, name = "Meeting the Magister" },
        { id = 93341, name = "Forlorn Gardens" },
        { id = 93594, name = "Word of the Woods" },
    }
    D[92914] = {
        level = 43, requires = 35,
        objective = "Explore Shen'dralas in an effort to find other pylons like the one you found.",
        pickup = "Shen'dralar Pylon, Shen'dralas (43.6, 34.2)",
        startObject = { "Shen'dralar Pylon", "Interface\\Icons\\INV_Enchant_ShardBrilliantLarge", "A cracked crystal on an old pedestal, guarded by mana elementals, Shen'dralas (43.6, 34.2)" },
        turnin = AT_MORDENT, map = PYLON, turninMap = MORDENT,
        note = "The other pylons: east at 73, 23 (more arcane elementals, you get dismounted there) and south at 47, 78 inside the big Shen'dralas building.",
    }
    -- objspots (2.0.13): the three pylons, one stop each until found (the
    -- places: the quest's note below, from Wowhead Forever's comments)
    D[92914].objectiveSpots = {
        [1] = { mapID = M, x = 0.435, y = 0.342, label = "Western pylon — Shen'dralas" },
        [2] = { mapID = M, x = 0.730, y = 0.233, label = "Eastern pylon — Shen'dralas (arcane elementals, you get dismounted there)" },
        [3] = { mapID = M, x = 0.470, y = 0.780, label = "Temple pylon — inside the big Shen'dralas building", hint = "Inside the big building" },
    }
    D[96010] = {
        level = 41, requires = 35,
        objective = "Recover shards and fragments of the pylons, found guarded at the Magram and Gelkis villages. Return them to Mordent Evenshade.",
        pickup = AT_MORDENT, turnin = AT_MORDENT, map = MORDENT, turninMap = MORDENT,
        requiredItems = {
            -- chainstops (2.0.13, M 18 Nov 2026: "it tells me to turn in the quest when I still have to get ... the fragments"): where each one is (warcraftmaps.com's quest page), a stop each until it is in the bags
            {255656, "Pylon Fragment", 1, "From the Pylon Shard crystal at the Magram village, Desolace (68.1, 79.1)", map = { mapID = 1443, x = 0.681, y = 0.791, label = "Pylon Fragment — the crystal at the Magram village, Desolace", pickUp = true }},
            {255657, "Pylon Shard", 1, "From the Pylon Shard crystal at the Gelkis village, Desolace (36.1, 85.6)", map = { mapID = 1443, x = 0.361, y = 0.856, label = "Pylon Shard — the crystal at the Gelkis village, Desolace", pickUp = true }},
        },
        note = "One crystal at each centaur camp in Desolace.",
    }
    D[96018] = {
        level = 43, requires = 35,
        objective = "Acquire the Mana Sieve from within the temple in Shen'dralas and use it to collect Ancient Mana Crystals, then empower the pylons and return to Mordent Evenshade.",
        pickup = AT_MORDENT, turnin = AT_MORDENT, map = MORDENT, turninMap = MORDENT,
        note = "The Mana Sieve is on the top floor of the big temple. Take 8 mana from the arcane orbs around Shen'dralas, then use the pylon parts with 4 mana on each pylon.",
        -- chainstops (2.0.13): the sieve first (until it is in the bags), then each pylon not repaired yet (warcraftmaps.com's quest page)
        requiredItems = { {255662, "Mana Sieve", 1, "On the top floor of the big temple in Shen'dralas (46.0, 78.1)", map = { mapID = M, x = 0.460, y = 0.781, label = "Mana Sieve — top floor of the big temple, Shen'dralas", pickUp = true, upstairs = true }} },
        objectiveSpots = {
            -- (arrowitem, M 19 Nov 2026: the line he gave, and the Pile of Pylon Parts to click on the arrow; no raid mark: a pylon is no NPC)
            ["Western pylon"] = { mapID = M, x = 0.435, y = 0.342, label = "Western pylon — Shen'dralas", markerType = "location", clickItem = { 271882, "Pile of Pylon Parts" }, hint = "Collect 8 Coalesced Mana Crystals from the Unstable Mana Rifts, then use the Pile of Pylon Parts" },
            ["Eastern pylon"] = { mapID = M, x = 0.730, y = 0.233, label = "Eastern pylon — Shen'dralas", markerType = "location", clickItem = { 271882, "Pile of Pylon Parts" }, hint = "Collect 8 Coalesced Mana Crystals from the Unstable Mana Rifts, then use the Pile of Pylon Parts" },
        },
    }
    -- templeway (2.0.13, M 19 Nov 2026 at 40.7, 74.2 below the temple, the
    -- arrow to the Mana Sieve straight into the cliff: "I needed to be a bit
    -- more precise into understanding how to get into the temple"): the
    -- temple's top floor (the Mana Sieve, the temple pylon) has its door on
    -- its north side (47.1, 73.3), on the upper level that runs round the
    -- temple to the city in the south and to the east. From the low ground
    -- west of the temple the only way up is the long stairway north of it
    -- (foot at 46.3, 60.9). The points: the Kalimdor walking maps.
    -- The arrow takes the route whose first point is nearest.
    do
        FDJ.ARROW_VIAS = FDJ.ARROW_VIAS or {}
        local function P(x, y, label) return { mapID = M, x = x, y = y, label = label } end
        local STAIRS = {
            P(0.463, 0.609, "The foot of the long stairway north of the temple"),
            P(0.465, 0.645, "Up the stairway, south to the temple"),
            P(0.466, 0.709, "Up the stairway, south to the temple"),
            P(0.471, 0.733, "Into the temple's top floor (its north door)"),
        }
        local function Join(head, tail)
            local list = {}
            for _, point in ipairs(head) do list[#list + 1] = point end
            for _, point in ipairs(tail) do list[#list + 1] = point end
            return list
        end
        local routes = {
            STAIRS, -- from the north (Evenshade's Overlook, the road)
            Join({ -- from the low ground west of the temple
                P(0.387, 0.712, "North-west, round the cliffs below the temple"),
                P(0.395, 0.663, "North, round the cliffs below the temple"),
                P(0.436, 0.633, "East, to the stairway north of the temple"),
            }, STAIRS),
            { -- from the city south of the temple (the upper level)
                P(0.440, 0.800, "Along the west side of the temple"),
                P(0.440, 0.758, "Along the west side of the temple"),
                P(0.456, 0.733, "Round to the temple's north side"),
                P(0.471, 0.733, "Into the temple's top floor (its north door)"),
            },
            { -- from the east (the upper level)
                P(0.507, 0.758, "West, to the temple's north side"),
                P(0.487, 0.730, "West, to the temple's north side"),
                P(0.471, 0.733, "Into the temple's top floor (its north door)"),
            },
        }
        -- buildingexit (2.0.13, M 19 Nov 2026, from Magister Kirandis to
        -- Mithera): indoors in the temple, to a place outside it: out by the
        -- north door first (the walking maps: from the top floor every way out goes
        -- through it, 47.5, 73.0).
        FDJ.ARROW_EXITS = FDJ.ARROW_EXITS or {}
        table.insert(FDJ.ARROW_EXITS, { mapID = M, x = 0.470, y = 0.770, radius = 60,
            door = P(0.473, 0.726, "Leave the temple") }) -- (just past the doorway, outside: M 19 Nov 2026)
        for _, spot in ipairs({ { 0.460, 0.781 }, { 0.470, 0.780 } }) do -- the Mana Sieve, the temple pylon
            FDJ.ARROW_VIAS[string.format("%s|%.4f|%.4f", tostring(M), spot[1], spot[2])] = { routes = routes }
        end
    end
    D[93016] = {
        level = 43, requires = 35,
        objective = "Speak with Mordent Evenshade in Shen'dralas for information about the crystals you repaired.",
        pickup = AT_MORDENT, turnin = AT_MORDENT, map = MORDENT, turninMap = MORDENT,
    }
    D[93394] = {
        level = 43, requires = 35,
        objective = "Locate Magister Kirandis inside the temple of Shen'dralas.",
        -- "in", not "inside": "inside" marks a turn-in as in the dungeon (In Dungeon icon).
        pickup = AT_MORDENT, turnin = "Magister Kirandis, in the temple of Shen'dralas (47.2, 75.8)",
        map = MORDENT, turninMap = KIRANDIS,
        note = "This opens the Shen'dralas quests, Mithera's included.",
    }
    -- 2.0.3 (Discord report, h0p3; Wowhead Forever 93341/93594 comments):
    -- Word of the Woods only opens once Mithera's Forlorn Gardens is handed in.
    D[93341] = {
        level = 43, requires = 35,
        objective = "Investigate the Forlorn Gardens near Shen'dralas and then return to Mithera at the nearby temple.",
        pickup = "Mithera, by the Forlorn Gardens, Shen'dralas (52.8, 76.0)",
        turnin = "Mithera, by the Forlorn Gardens, Shen'dralas (52.8, 76.0)",
        map = MITHERA, turninMap = MITHERA,
        -- chainstops (2.0.13): the pedestal first. (pedestalspot, M 19 Nov 2026:
        -- the arrow said "Talk to Forlorn Gardens" at a guessed spot by Mithera;
        -- the game's own objective mark on his map: 71.6, 79.6.)
        objectiveSpots = { [1] = { mapID = M, x = 0.716, y = 0.796, label = "Pedestal — Forlorn Gardens, Shen'dralas", markerType = "location", hint = "Examine the pedestal" } },
    }
    D[93594] = {
        level = 43, requires = 35,
        objective = "Find Woodwyrd in the Forlorn Gardens at Shen'dralas.",
        pickup = "Mithera, by the Forlorn Gardens, Shen'dralas (52.8, 76.0)",
        turnin = AT_WOODWYRD, map = MITHERA, turninMap = WOODWYRD,
        note = "Mithera offers it once Forlorn Gardens is handed in.",
    }
    XP[92914] = 3600; XP[96010] = 2450; XP[96018] = 3600; XP[93016] = 360; XP[93394] = 360; XP[93341] = 1800; XP[93594] = 360

    local FOREVER_XP = {
        [7067] = 10650, [7068] = 6750, [7070] = 6750, [7029] = 10250, [7041] = 10250,
        [7028] = 10250, [7044] = 6650, [7046] = 11100, [7064] = 11900, [7065] = 11900,
        [7066] = 11900, [93404] = 11100, [96776] = 11900,
    }
    for id, xp in pairs(FOREVER_XP) do XP[id] = xp end
    if db and type(db.quests) == "table" then
        for _, q in ipairs(db.quests) do
            if FOREVER_XP[q.id] then q.liveXPFallback = FOREVER_XP[q.id] end
            if q.id == 7068 then q.rewardSummary = "Darkspear Trolls +150" end
            if q.id == 7066 then q.rewardSummary = "1g 50s  •  Cenarion Circle +150" end
            if q.id == 93404 then
                q.pickup = AT_WOODWYRD
                q.turnin = AT_WOODWYRD
                q.startMap = WOODWYRD
                q.turninMap = WOODWYRD
                q.objective = "Venture to Maraudon and recover a Vial of Earth Song Water, then use it to put out Woodwyrd's flame at the Forlorn Gardens."
                q.requiredItem = { 258296, "Vial of Earth Song Water", 1, 1, "From the small geyser in the pools Rotgrip swims around in, Maraudon" }
                q.rewards = "Choose: Overgrown Cuffs or Thornplated Cord\n11,100 XP"
                q.rewardSummary = "" -- rewardline (2.0.13): the buttons and XP box show it; no text line under them
                q.note = "Back at the Forlorn Gardens, use the vial on the burning tree next to Woodwyrd, not on Woodwyrd himself. Afterwards Woodwyrd sends you to the Bristleback Retreat (Passing the Blame), which leads to Agamaggan's Blood in Razorfen Downs."
            end
        end
    end
    FDJ.QUEST_START_MAPS[93404] = WOODWYRD
end
-- END maraudonquests

-- BEGIN rfdquests
-- 2.0.24: Razorfen Downs. Agamaggan's Blood, the end of Rot and Regret's
-- chain (Wowhead Forever 93604, 93601, NPC 253527 Kog'thug the Brave).
-- XP: WoW Forever's values (Wowhead's multipliers, 2.375 or 2.1, matching
-- forever-tool), the Alliance Coldbringer's Eye's real ID 96773, and the
-- full reward lists of Bring the End / Bring the Light / An Unholy Alliance.
do
    local db = FDJ.DB and FDJ.DB["Razorfen Downs"]
    local D, C, XP = FDJ.QUEST_PREREQ_DETAILS, FDJ.QUEST_PREREQ_CHAINS, FDJ.FOREVER_QUEST_XP_FALLBACK
    local M = 2652 -- Shen'dralas
    -- woodwyrdspot (2.0.13, M 19 Nov 2026, his map's ? for Word of the Woods at 69.9, 72.1; was a guess by Mithera)
    local WOODWYRD = { mapID = M, x = 0.699, y = 0.721, label = "Woodwyrd — Forlorn Gardens, Shen'dralas", targetName = "Woodwyrd" }
    local KOGTHUG = { mapID = M, x = 0.726, y = 0.314, label = "Kog'thug the Brave — Bristleback Retreat, Shen'dralas", targetName = "Kog'thug the Brave" }
    local LANDALOCK = { mapID = 1416, x = 0.154, y = 0.738, label = "Archmage Lan'dalock — Violet Hold entrance, Dalaran", targetName = "Archmage Lan'dalock" }
    local AT_WOODWYRD = "Woodwyrd, Forlorn Gardens, Shen'dralas (69.9, 72.1)"
    local AT_KOGTHUG = "Kog'thug the Brave, Bristleback Retreat, Shen'dralas (72.6, 31.4)"

    C[93604] = {
        { id = 92914, name = "Strange Pylons" },
        { id = 96010, name = "Fragments of the Pylons" },
        { id = 96018, name = "Powering the Pylons" },
        { id = 93016, name = "A Brief History Lesson" },
        { id = 93394, name = "Meeting the Magister" },
        { id = 93341, name = "Forlorn Gardens" },
        { id = 93594, name = "Word of the Woods" },
        { id = 93404, name = "Rot and Regret" },
        { id = 93601, name = "Passing the Blame" },
    }
    D[93404] = {
        level = 49, requires = 35,
        objective = "Venture to Maraudon and recover a Vial of Earth Song Water, then use it to put out Woodwyrd's flame at the Forlorn Gardens.",
        pickup = AT_WOODWYRD, turnin = AT_WOODWYRD, map = WOODWYRD, turninMap = WOODWYRD,
        -- chainstops (2.0.13): the vial is from a Maraudon run: Maraudon's entrance is a stop until the vial is in the bags
        requiredItems = { {258296, "Vial of Earth Song Water", 1, "From the small geyser in the pools Rotgrip swims around in, Maraudon", map = { mapID = 1443, x = 0.291, y = 0.625, label = "Maraudon Entrance — the Vial of Earth Song Water is inside (the small geyser in Rotgrip's pools)", markerType = "dungeon" }} },
        note = "A Maraudon dungeon quest (see Maraudon). Use the vial on the burning tree next to Woodwyrd, not on Woodwyrd himself.",
        -- rfdstep (2.0.30): only on this chain's step page (Agamaggan's Blood,
        -- Razorfen Downs); Maraudon's own Rot and Regret page has no such line.
        warning = "Yes, this step is in MARAUDON. It's needed to unlock this Razorfen quest.",
        warningTop = true, -- 2.0.31: above the Objective
    }
    D[93601] = {
        level = 45, requires = 35,
        objective = "Seek out a quilboar of significance at the Bristleback Retreat.",
        pickup = AT_WOODWYRD, turnin = AT_KOGTHUG, map = WOODWYRD, turninMap = KOGTHUG,
    }
    XP[93404] = 11100; XP[93601] = 390

    if db then
        db.quests = db.quests or {}
        local have = false
        for _, q in ipairs(db.quests) do if q.id == 93604 then have = true end end
        if not have then
            table.insert(db.quests, {
                id = 93604,
                name = "Agamaggan's Blood",
                faction = "Both",
                level = 45,
                requires = 35,
                pickup = AT_KOGTHUG,
                objective = "Venture to Razorfen Downs and acquire Virulent Blood of Agamaggan, then return it to Kog'thug the Brave at Bristleback Retreat.",
                turnin = AT_KOGTHUG,
                startMap = KOGTHUG,
                turninMap = KOGTHUG,
                liveXPFallback = 10200,
                rewardSummary = "65s",
                rewards = "10,200 XP • 65s",
                rewardItems = {},
                requiredItem = { 260237, "Virulent Blood of Agamaggan", 1, 1, "From the Virulent Blood of Agamaggan, which a Cauldron of Agamaggan's Blood summons in Razorfen Downs" },
                note = "Click a Cauldron of Agamaggan's Blood to summon the Virulent Blood of Agamaggan and kill it for the blood. One cauldron is in the tent nearest the last boss (it may also be in other tents). Blood from Razorfen Kraul doesn't count.",
            })
        end
        local FOREVER_XP = {
            [3525] = 10100, [6626] = 8200, [3341] = 9050, [3636] = 10200, [6521] = 7350,
            [96773] = 8600, [97196] = 8600, [93604] = 10200,
        }
        for _, q in ipairs(db.quests) do
            if FOREVER_XP[q.id] then q.liveXPFallback = FOREVER_XP[q.id] end
            -- rfdstep (2.0.31): the chain's Rot and Regret step is done in Maraudon.
            -- outsiderfd (2.0.13, M 19 Nov 2026): a disclaimer under it: the blood is got outside the dungeon.
            if q.id == 93604 and not q.warning then q.warning = "WARNING: This chain has a step in Maraudon\nThis quest is completed in the area OUTSIDE Razorfen Downs" end
            if q.id == 3341 or q.id == 3636 then
                -- rfdsword (2.0.10): a choice of the Talisman or the Ring; the
                -- Vanquisher's Sword comes on top (Wowhead Forever)
                q.rewardChoice = true
                q.rewardItems = { {10824, "Amberglow Talisman", 3}, {270081, "Purified Ring", 3} }
                q.additionalRewardItems = { {10823, "Vanquisher's Sword", 3} }
                q.rewardSummary = (q.id == 3341) and "Undercity +150" or "Stormwind +150"
            end
            if q.id == 6521 then
                q.rewardItems = { {17039, "Skullbreaker", 2}, {17042, "Nail Spitter", 2}, {17043, "Zealot's Robe", 2}, {270054, "Cultist's Chestguard", 3} }
            end
            if q.id == 96773 then
                q.rewardSummary = "55s  •  Kirin Tor +300  •  Stormwind +150"
                q.startMap, q.turninMap = LANDALOCK, LANDALOCK
                q.pickup = "Archmage Lan'dalock, at the Violet Hold entrance in Dalaran, Alterac Mountains (15.4, 73.8)"
                q.turnin = q.pickup
            end
        end
        for id, xp in pairs(FOREVER_XP) do XP[id] = xp end
    end
    XP[3523] = 675; XP[6522] = 5900
    FDJ.QUEST_START_MAPS[93604] = KOGTHUG
    FDJ.QUEST_START_MAPS[96773] = LANDALOCK
    if FDJ.QUEST_SHAREABILITY_AUDIT then
        FDJ.QUEST_SHAREABILITY_AUDIT[93604] = true
        FDJ.QUEST_SHAREABILITY_AUDIT[96773] = true
    end
end
-- END rfdquests

-- BEGIN uldamanzfquests
-- 2.0.25: Uldaman and Zul'Farrak checked against Wowhead Forever and
-- forever-tool (Nov 2026). Quest XP: WoW Forever's values (each quest has
-- its own multiplier; forever-tool's official numbers, spot-checked on
-- Wowhead). The necklace chains end one quest later than the journal had
-- them: Restoring the Necklace (2361, Talvash del Kissel) for the Alliance,
-- Deliver the Gems (2340) and Necklace Recovery, Take 3 (2341, Jarkal
-- Mossmeld) for the Horde; the Alliance Platinum Discs end with 2439 at
-- Dinita Stonemantle, who gives the potion / Thawpelt Sack choice.
do
    local D, C, XP = FDJ.QUEST_PREREQ_DETAILS, FDJ.QUEST_PREREQ_CHAINS, FDJ.FOREVER_QUEST_XP_FALLBACK
    local SM = FDJ.QUEST_START_MAPS
    local TALVASH = { mapID = 1455, x = 0.360, y = 0.040, label = "Talvash del Kissel — Mystic Ward, Ironforge", targetName = "Talvash del Kissel" }
    local DRAN = { mapID = 1454, x = 0.594, y = 0.368, label = "Dran Droffers — The Drag, Orgrimmar", targetName = "Dran Droffers" }
    local JARKAL = { mapID = 1418, x = 0.026, y = 0.460, label = "Jarkal Mossmeld — Kargath, Badlands", targetName = "Jarkal Mossmeld" }
    local MAGELLAS = { mapID = 1455, x = 0.696, y = 0.186, label = "High Explorer Magellas — Hall of Explorers, Ironforge", targetName = "High Explorer Magellas" }
    local DINITA = { mapID = 1455, x = 0.338, y = 0.602, label = "Dinita Stonemantle — The Vault, Ironforge", targetName = "Dinita Stonemantle" }
    -- discshorde (2.0.10): Wowhead Forever NPC spots, Thunder Bluff
    local TRUTHSEEKER = { mapID = 1456, x = 0.344, y = 0.472, label = "Sage Truthseeker — Thunder Bluff", targetName = "Sage Truthseeker" }
    local BENA = { mapID = 1456, x = 0.468, y = 0.334, label = "Bena Winterhoof — Thunder Bluff", targetName = "Bena Winterhoof" }

    -- A journal entry that becomes a chain step keeps its page as a step.
    local function AsStep(q)
        if D[q.id] then return end
        local items = q.requiredItems
        if not items and q.requiredItem then
            items = { { q.requiredItem[1], q.requiredItem[2], q.requiredItem[3], q.requiredItem[5] } }
        end
        D[q.id] = {
            level = q.level, requires = q.requires, objective = q.objective,
            pickup = q.pickup, turnin = q.turnin, startsInDungeon = q.startsInDungeon,
            startItem = q.startItem, startObject = q.startObject, providedItem = q.providedItem,
            map = q.startMap or SM[q.id], turninMap = q.turninMap, note = q.note,
            requiredItems = items,
        }
    end
    local function Insert(dungeon, afterID, quest, chain)
        local d = FDJ.DB and FDJ.DB[dungeon]
        if not d or type(d.quests) ~= "table" then return end
        for _, q in ipairs(d.quests) do if q.id == quest.id then return end end
        local at = #d.quests + 1
        for i, q in ipairs(d.quests) do if q.id == afterID then at = i + 1 end end
        table.insert(d.quests, at, quest)
        C[quest.id] = chain
        local stepIDs = {}
        for _, s in ipairs(chain) do stepIDs[s.id] = true end
        for _, q in ipairs(d.quests) do
            if stepIDs[q.id] then AsStep(q); q.hideFromMainList = true end
        end
    end

    -- Alliance: Talvash del Kissel's necklace.
    Insert("Uldaman", 2204, {
        id = 2361, name = "Restoring the Necklace", faction = "Alliance", level = 44, requires = 37,
        pickup = "Talvash del Kissel, Mystic Ward, Ironforge (36.0, 4.0)",
        objective = "Let Talvash del Kissel finish restoring the necklace, then take it from him.",
        turnin = "Talvash del Kissel, Mystic Ward, Ironforge (36.0, 4.0)",
        startMap = TALVASH, turninMap = TALVASH,
        liveXPFallback = 5600,
        rewardSummary = "Gnomeregan Exiles +200",
        rewards = "Talvash's Enhancing Necklace\n5,600 XP • Gnomeregan Exiles +200",
        rewardItems = { { 7673, "Talvash's Enhancing Necklace", 3 } },
    }, {
        { id = 2198, name = "The Shattered Necklace" },
        { id = 2199, name = "Lore for a Price" },
        { id = 2200, name = "Back to Uldaman" },
        { id = 2201, name = "Find the Gems" },
        { id = 2204, name = "Restoring the Necklace" },
    })

    -- Horde: Jarkal Mossmeld's necklace.
    D[2340] = {
        level = 44, requires = 37,
        objective = "Deliver the Necklace and Gem Salvage to Dran Droffers in Orgrimmar.",
        pickup = "Jarkal Mossmeld, Kargath, Badlands (2.6, 46.0)",
        turnin = "Dran Droffers, The Drag, Orgrimmar (59.4, 36.8)",
        map = JARKAL, turninMap = DRAN,
        providedItem = { 0, "Necklace and Gem Salvage", 1, "Given by Jarkal Mossmeld when you accept the quest" },
    }
    Insert("Uldaman", 2339, {
        id = 2341, name = "Necklace Recovery, Take 3", faction = "Horde", level = 44, requires = 37,
        pickup = "Dran Droffers, The Drag, Orgrimmar (59.4, 36.8)",
        objective = "Visit Jarkal Mossmeld in Kargath to see if he was successful.",
        turnin = "Jarkal Mossmeld, Kargath, Badlands (2.6, 46.0)",
        startMap = DRAN, turninMap = JARKAL,
        liveXPFallback = 5600,
        rewardSummary = "Darkspear Trolls +100",
        rewards = "Jarkal's Enhancing Necklace\n5,600 XP • Darkspear Trolls +100",
        rewardItems = { { 7888, "Jarkal's Enhancing Necklace", 3 } },
        -- undeadok (2.0.11, M 18 Nov 2026): Undead CAN do this chain. The
        -- "not available to your race" came from the Shattered Necklace
        -- itself (it starts the Alliance quest), so no Undead warning here.
    }, {
        { id = 2283, name = "Necklace Recovery" },
        { id = 2284, name = "Necklace Recovery, Take 2" },
        { id = 2318, name = "Translating the Journal" },
        { id = 2338, name = "Translating the Journal" },
        { id = 2339, name = "Find the Gems and Power Source" },
        { id = 2340, name = "Deliver the Gems" },
    })
    -- necklacenote (2.0.11, M 18 Nov 2026): on the chain's first step, at
    -- the top: the necklace only starts the quest for the Alliance.
    if D[2283] then
        D[2283].warning = "As Horde you can't start the quest from the necklace, you need to have the quest first."
        D[2283].warningTop = true
    end
    local NECKLACE_NOTE = {
        deDE = "Als Horde könnt Ihr die Quest nicht über die Halskette starten, Ihr müsst die Quest zuerst haben.",
        frFR = "Côté Horde, vous ne pouvez pas commencer la quête avec le collier : vous devez d'abord avoir la quête.",
        esES = "Como Horda no puedes empezar la misión desde el collar; primero necesitas tener la misión.",
        itIT = "Come Orda non puoi iniziare la missione dalla collana: devi prima avere la missione.",
        ptBR = "Como Horda, você não pode iniciar a missão pelo colar; precisa ter a missão primeiro.",
        ruRU = "За Орду нельзя начать задание с ожерелья: сначала нужно взять задание.",
        koKR = "호드는 목걸이로 퀘스트를 시작할 수 없습니다. 먼저 퀘스트를 받아야 합니다.",
        zhCN = "部落无法通过项链开始任务，你需要先接到任务。",
        zhTW = "部落無法透過項鍊開始任務，你需要先接到任務。",
    }
    for lang, text in pairs(NECKLACE_NOTE) do
        local c = FDJ.ContentLocales and FDJ.ContentLocales[lang]
        if c then
            c.quests = c.quests or {}
            c.quests[2283] = c.quests[2283] or {}
            c.quests[2283].warning = text
        end
    end

    -- Alliance Platinum Discs: the reward comes one step later.
    -- discshorde (2.0.10, M 17 Nov 2026: "fix this reward choice for both
    -- factions"): the same for the Horde (2280, then 2440 at Bena
    -- Winterhoof); the reward (Wowhead Forever 2439 / 2440): 5 Superior
    -- Healing Potions or 5 Greater Mana Potions, and the Thawpelt Sack on top.
    local DISC_CHOICE = { { 3928, "Superior Healing Potion", 1, 5 }, { 6149, "Greater Mana Potion", 1, 5 } }
    local DISC_ALSO = { { 9587, "Thawpelt Sack", 1 } }
    for _, q in ipairs((FDJ.DB and FDJ.DB["Uldaman"] and FDJ.DB["Uldaman"].quests) or {}) do
        if q.id == 2279 then
            q.rewardItems = {}
            q.rewardChoice = nil
            q.rewardSummary = "Ironforge +150"
            q.turninMap = q.turninMap or MAGELLAS
        elseif q.id == 2280 then
            q.rewardItems = {}
            q.rewardChoice = nil
            q.additionalRewardItems = nil
            q.rewardSummary = "Thunder Bluff +150"
            q.turninMap = q.turninMap or TRUTHSEEKER
        end
    end
    Insert("Uldaman", 2279, {
        id = 2439, name = "The Platinum Discs", faction = "Alliance", level = 47, requires = 40,
        pickup = "High Explorer Magellas, Hall of Explorers, Ironforge (69.6, 18.6)",
        objective = "Take your reward voucher to Dinita Stonemantle in the Vault of Ironforge.",
        turnin = "Dinita Stonemantle, The Vault, Ironforge (33.8, 60.2)",
        startMap = MAGELLAS, turninMap = DINITA,
        providedItem = { 8070, "Reward Voucher", 1, "Given by High Explorer Magellas when you accept the quest" },
        liveXPFallback = 420,
        rewardSummary = "",
        rewardChoice = true,
        rewardItems = DISC_CHOICE,
        additionalRewardItems = DISC_ALSO,
    }, {
        { id = 2278, name = "The Platinum Discs" },
        { id = 2279, name = "The Platinum Discs" },
    })
    Insert("Uldaman", 2280, {
        id = 2440, name = "The Platinum Discs", faction = "Horde", level = 47, requires = 40,
        pickup = "Sage Truthseeker, Thunder Bluff (34.4, 47.2)",
        objective = "Take the reward voucher to Bena Winterhoof in Thunder Bluff.",
        turnin = "Bena Winterhoof, Thunder Bluff (46.8, 33.4)",
        startMap = TRUTHSEEKER, turninMap = BENA,
        providedItem = { 8070, "Reward Voucher", 1, "Given by Sage Truthseeker when you accept the quest" },
        liveXPFallback = 420,
        rewardSummary = "Thunder Bluff +10",
        rewardChoice = true,
        rewardItems = DISC_CHOICE,
        additionalRewardItems = DISC_ALSO,
    }, {
        { id = 2278, name = "The Platinum Discs" },
        { id = 2280, name = "The Platinum Discs" },
    })

    -- WoW Forever quest XP (forever-tool / Wowhead Forever, Nov 2026).
    local FOREVER_XP = {
        -- Uldaman
        [2398] = 550, [2240] = 6850, [721] = 4800, [722] = 5500, [707] = 710, [704] = 5000,
        [17] = 6050, [2202] = 6750, [709] = 6150, [2418] = 3500, [1360] = 6300, [2342] = 7000,
        [1139] = 10250, [2200] = 4450, [2201] = 6300, [2204] = 1650, [2283] = 4800, [2284] = 4800,
        [2339] = 7300, [2278] = 8200, [2279] = 5250, [2280] = 5250, [1956] = 7800,
        [2198] = 5800, [2199] = 2450, [2318] = 6750, [2338] = 350, [2340] = 1850,
        [2341] = 5600, [2361] = 5600, [2439] = 420, [2440] = 420,
        -- Zul'Farrak
        [2769] = 405, [2770] = 14200, [2861] = 410, [2846] = 12100, [2768] = 12600, [2864] = 390,
        [2865] = 7800, [3042] = 7800, [3527] = 10500, [2991] = 10500, [2936] = 9700,
        [96770] = 10100, [96775] = 10100,
    }
    for id, xp in pairs(FOREVER_XP) do XP[id] = xp end
    for _, name in ipairs({ "Uldaman", "Zul'Farrak" }) do
        for _, q in ipairs((FDJ.DB and FDJ.DB[name] and FDJ.DB[name].quests) or {}) do
            if FOREVER_XP[q.id] then q.liveXPFallback = FOREVER_XP[q.id] end
            if q.id == 2936 and (q.rewardSummary or "") == "" then q.rewardSummary = "Darkspear Trolls +150" end
            if q.id == 2418 and (q.rewardSummary or "") == "" then q.rewardSummary = "Booty Bay +150  •  Bloodsail Buccaneers -750" end
        end
    end
end
-- END uldamanzfquests

-- BEGIN uldamanzfitems
-- 2.0.26: item cards for every Uldaman and Zul'Farrak quest and chain step
-- that asks for items (they had none). Item IDs and sources: Wowhead Forever
-- and ForeverChanges quest pages (Nov 2026). Scarab Shells: Tran'rek is a
-- breadcrumb; with it in your log you can't take (or be shared) Scarab
-- Shells until you hand it in (Ed on the Discord's bug-reports, Nov 2026).
do
    local D = FDJ.QUEST_PREREQ_DETAILS
    -- {itemID, name, count, where}
    local ITEMS = {
        -- Uldaman
        [704]  = { {4610, "Carved Stone Urn", 4, "Outside the instance: urns on both sides of the gate and under the tents before Dig One"} },
        [17]   = { {8047, "Magenta Fungus Cap", 12, "Mushrooms near the fires, mostly outside the instance in the Uldaman excavation"} },
        [2202] = { {8047, "Magenta Fungus Cap", 12, "Mushrooms near the fires, mostly outside the instance in the Uldaman excavation"} },
        [709]  = { {4631, "Tablet of Ryun'eh", 1, "In the middle of the Sealed Hall, before the instance portal"} },
        [2418] = { {8009, "Dentrium Power Stone", 8, "Dropped by the Shadowforge dwarves outside the instance"},
                   {8052, "An'Alleum Power Stone", 8, "Dropped by the Shadowforge dwarves outside the instance"} },
        [1360] = { {8027, "Krom Stoutarm's Treasure", 1, "In his chest in the North Common Hall, outside the instance"} },
        [2342] = { {8026, "Garrett Family Treasure", 1, "In the family chest in the South Common Hall, outside the instance"} },
        [722]  = { {4635, "Hammertoe's Amulet", 1, "Dropped by Magregan Deepshadow in the Uldaman excavation"} },
        [1139] = { {5824, "Tablet of Will", 1, "Inside Uldaman"} },
        [1956] = { {8053, "Obsidian Power Source", 1, "Dropped by the Obsidian Sentinel in Uldaman"} },
        [2283] = { {7666, "Shattered Necklace", 1, "Dropped by the troggs and Shadowforge dwarves of the Uldaman dig site"} },
        [2199] = { {2842, "Silver Bar", 5, "Smelted from Silver Ore: mining, trade or the auction house"} },
        [2201] = { {7669, "Shattered Necklace Ruby", 1, "In the Shadowforge Stash in Galgann Firehammer's room; opening it brings two enemies"},
                   {7670, "Shattered Necklace Sapphire", 1, "Dropped by Grimlok"},
                   {7671, "Shattered Necklace Topaz", 1, "In the Conspicuous Urn in the room with Baelog, Olaf and Eric"} },
        [2204] = { {7672, "Shattered Necklace Power Source", 1, "Dropped by Archaedas, the last boss of Uldaman"} },
        [2339] = { {7669, "Shattered Necklace Ruby", 1, "In the Shadowforge Stash in Galgann Firehammer's room; opening it brings two enemies"},
                   {7670, "Shattered Necklace Sapphire", 1, "Dropped by Grimlok"},
                   {7671, "Shattered Necklace Topaz", 1, "In the Conspicuous Urn in the room with Baelog, Olaf and Eric"},
                   {7672, "Shattered Necklace Power Source", 1, "Dropped by Archaedas, the last boss of Uldaman"} },
        [2258] = { {7847, "Buzzard Gizzard", 5, "Dropped by buzzards in the Badlands, e.g. around the big carcass at 15, 60"},
                   {7846, "Crag Coyote Fang", 10, "Dropped by crag coyotes all over the Badlands"},
                   {7848, "Rock Elemental Shard", 5, "Dropped by rock elementals in the hills by Kargath, around 13, 36"} },
        [2500] = { {7847, "Buzzard Gizzard", 5, "Dropped by buzzards in the Badlands, e.g. around the big carcass at 15, 60"},
                   {7846, "Crag Coyote Fang", 10, "Dropped by crag coyotes all over the Badlands"},
                   {7848, "Rock Elemental Shard", 5, "Dropped by rock elementals in the hills by Kargath, around 13, 36"} },
        [1954] = { {7291, "Infernal Orb", 1, "Dropped by the summoners at Mannoroc Coven, Desolace (around 53, 83)"} },
        -- Zul'Farrak
        [2770] = { {8707, "Gahz'rilla's Electrified Scale", 1, "From Gahz'rilla, summoned with the Mallet of Zul'Farrak at the gong"} },
        [2846] = { {9234, "Tiara of the Deep", 1, "Dropped by Hydromancer Velratha"} },
        [2768] = { {8548, "Divino-matic Rod", 1, "Dropped by Sergeant Bly"} },
        [2865] = { {9238, "Uncracked Scarab Shell", 5, "Dropped by the scarabs in Zul'Farrak (a room full of them on the right-hand path)"} },
        [3042] = { {9523, "Troll Temper", 20, "Dropped by the Sandfury trolls in Zul'Farrak"} },
        [3527] = { {10660, "First Mosh'aru Tablet", 1, "Dropped by Theka the Martyr"},
                   {10661, "Second Mosh'aru Tablet", 1, "Dropped by Hydromancer Velratha"} },
        [2991] = { {9471, "Nekrum's Medallion", 1, "Dropped by Nekrum Gutchewer"} },
        [2934] = { {9322, "Undamaged Venom Sac", 1, "Dropped by spiders in the Hinterlands around 35, 64 (not every one has it; everyone in the group can loot it)"} },
    }
    local function List(entries)
        local out = {}
        for i, e in ipairs(entries) do
            local where = e[4]
            if e[3] > 1 then where = where .. " (" .. e[3] .. " needed)" end
            out[i] = { e[1], e[2], 1, where }
        end
        return out
    end
    for _, name in ipairs({ "Uldaman", "Zul'Farrak" }) do
        for _, q in ipairs((FDJ.DB and FDJ.DB[name] and FDJ.DB[name].quests) or {}) do
            local e = ITEMS[q.id]
            if e and not q.requiredItem and not q.requiredItems then
                if #e == 1 then
                    q.requiredItem = { e[1][1], e[1][2], 1, e[1][3], e[1][4] }
                else
                    q.requiredItems = List(e)
                end
            end
            if q.id == 2865 then
                q.warning = "Have Tran'rek in your quest log? Hand it in to Tran'rek first: until then you can't accept Scarab Shells, not even when someone shares it."
            end
        end
    end
    for id, e in pairs(ITEMS) do
        local d = D[id]
        if d and not d.requiredItems then d.requiredItems = List(e) end
    end
    if D[2990] and not D[2990].providedItem then
        D[2990].providedItem = { 9468, "Sharpbeak's Feather", 1, "Given by Gryphon Master Talonaxe when you accept the quest" }
    end
end
-- END uldamanzfitems

-- BEGIN brdquests
-- 2.0.31: Blackrock Depths. Forever's quest list for the zone (forever-tool,
-- official game data, build 1.60.1.70399) has 43 quests; two were missing:
--   * Fragment of the Firelands (97197), new in Forever, Horde (Alaana
--     Stormwalker, Mulgore). Reported on Discord by Snax (seen at level 49).
--   * The Challenge (9015), the Dungeon Set 2 step that summons Theldren
--     with the Banner of Provocation.
-- XP: WoW Forever's values for every BRD quest and step (most were Classic's).
do
    local db = FDJ.DB and FDJ.DB["Blackrock Depths"]
    local D, C, XP = FDJ.QUEST_PREREQ_DETAILS, FDJ.QUEST_PREREQ_CHAINS, FDJ.FOREVER_QUEST_XP_FALLBACK
    local FALRIN = "Falrin Treeshaper, the Athenaeum, Dire Maul (West)"
    local ANTHION = "Anthion Harmon, outside Stratholme, Eastern Plaguelands"

    C[9015] = {
        { id = 8948, name = "Anthion's Old Friend" },
        { id = 8949, name = "Falrin's Vendetta" },
        { id = 8950, name = "The Instigator's Enchantment" },
    }
    D[8948] = {
        level = 60, requires = 58,
        objective = "Take the incomplete Banner of Provocation to Falrin Treeshaper at the library in Dire Maul.",
        pickup = ANTHION, turnin = FALRIN,
        description = "Part of Anthion Harmon's Dungeon Set 2 quests: the earlier ones unlock this step.",
        providedItem = {21983, "Incomplete Banner of Provocation", 1, "Given by Anthion Harmon"},
    }
    D[8949] = {
        level = 60, requires = 58,
        objective = "Collect 25 Ogre Warbeads from ogres inside Dire Maul or Blackrock Spire.",
        pickup = FALRIN, turnin = FALRIN,
        requiredItems = { {21982, "Ogre Warbeads", 1, "From ogres in Dire Maul or Blackrock Spire (25 needed)"} },
    }
    D[8950] = {
        level = 60, requires = 58,
        objective = "Bring 1 Jeering Spectre's Essence, 4 Dark Runes and 8 Large Brilliant Shards to Falrin Treeshaper inside Dire Maul.",
        pickup = FALRIN, turnin = FALRIN,
        requiredItems = {
            {22224, "Jeering Spectre's Essence", 1, "From Eldreth Phantasms, Spectres, Spirits and Apparitions in Dire Maul (1 needed)"},
            {20520, "Dark Rune", 2, "From undead in the Plaguelands, Scholomance and Stratholme (4 needed)"},
            {14344, "Large Brilliant Shard", 3, "Enchanting: disenchant rare items, or buy one (8 needed)"},
        },
    }

    if db then
        db.quests = db.quests or {}
        local have = {}
        for _, q in ipairs(db.quests) do have[q.id] = true end
        if not have[97197] then
            table.insert(db.quests, {
                id = 97197,
                name = "Fragment of the Firelands",
                faction = "Horde",
                level = 55,
                requires = 49,
                pickup = "Alaana Stormwalker, Skywatcher Plateau, Mulgore (33.4, 22.5)",
                startMap = { mapID = 1412, x = 0.334, y = 0.225, label = "Alaana Stormwalker — Skywatcher Plateau", targetName = "Alaana Stormwalker", detail = "Where the skycutter lands, northwest of Thunder Bluff" },
                objective = "Recover a Fragment of the Firelands from Magmus in Blackrock Depths for Alaana Stormwalker in Mulgore.",
                turnin = "Alaana Stormwalker, Skywatcher Plateau, Mulgore (33.4, 22.5)",
                liveXPFallback = 14800,
                rewardSummary = "85s  •  Cenarion Circle +300",
                rewards = "14,800 XP • 85s • Cenarion Circle +300",
                rewardItems = {},
                -- fragmentmagmus (2.0.7): Wowhead Forever item 277129, "Dropped by:
                -- Magmus" (Vakos on Discord, M, 14 Nov 2026). Wowhead's 20.48% is left out:
                -- for a quest item it should be every kill while on the quest (M).
                requiredItems = {
                    {277129, "Fragment of the Firelands", 1, "Drops from Magmus in Blackrock Depths"},
                },
                note = "The Fragment of the Firelands drops from Magmus, the guardian at the door to the Imperial Seat in Blackrock Depths. Seen picked up at level 49.",
            })
        end
        -- challengeoff (2.0.11, M 18 Nov 2026: "remove this quest from brd for
        -- now, its a long tier 0.5 chain that people wont look for when going
        -- in the dungeon"): left out of the quest list. To bring it back,
        -- drop the "false and".
        if false and not have[9015] then
            table.insert(db.quests, {
                id = 9015,
                name = "The Challenge",
                faction = "Both",
                level = 60,
                requires = 58,
                pickup = FALRIN,
                objective = "Use the Banner of Provocation in the center of the Ring of Law as High Justice Grimstone sentences you, slay Theldren and his gladiators, and bring the Top Piece of Lord Valthalak's Amulet to Anthion Harmon in the Eastern Plaguelands.",
                turnin = ANTHION,
                liveXPFallback = 1450,
                rewardSummary = "",
                rewards = "1,450 XP",
                rewardItems = {},
                requiredItem = { 22047, "Top Piece of Lord Valthalak's Amulet", 1, 1, "Dropped by Theldren in the Ring of Law, Blackrock Depths" },
                note = "Plant the banner before the normal challenger comes out. Theldren and his gladiators then fight you, and an Arena Spoils chest appears afterwards. You keep the banner (10 min cooldown) to summon him again.",
            })
        end
        local FOREVER_XP = {
            [3802] = 9450, [4123] = 10450, [4136] = 5550, [4201] = 10900, [4128] = 550,
            [4126] = 14800, [4133] = 550, [4134] = 11300, [4263] = 10450, [3907] = 13500,
            [7201] = 10100, [4322] = 13950, [3982] = 10100, [4063] = 12400, [4081] = 9950,
            [4082] = 10650, [4132] = 15500, [4024] = 11450, [4362] = 16900, [4003] = 16100,
            [4286] = 10450, [7604] = 725, [4083] = 5650, [97197] = 14800, [9015] = 1450,
        }
        for _, q in ipairs(db.quests) do
            if FOREVER_XP[q.id] then q.liveXPFallback = FOREVER_XP[q.id] end
        end
        for id, xp in pairs(FOREVER_XP) do XP[id] = xp end
    end
    -- Chain steps (forever-tool, official values).
    XP[3801] = 500; XP[4002] = 550; XP[4342] = 2900; XP[4122] = 6200; XP[4361] = 6400
    XP[4121] = 7750; XP[3981] = 9450; XP[4242] = 9800; XP[4264] = 11150; XP[4282] = 11150
    XP[4241] = 11450; XP[4341] = 11500; XP[4001] = 12600; XP[4004] = 2200; XP[4363] = 20250
    XP[8948] = 1450; XP[8949] = 1450; XP[8950] = 1450
    -- Shareability left to the game (C_QuestLog.IsPushableQuest): not audited.
end
-- END brdquests

-- BEGIN blackmawstquests
-- 2.0.32: Blackmaw Hold and Sunken Temple checked against Forever's quest
-- lists (forever-tool, official data, build 1.60.1.70399) and Wowhead
-- Forever's quest tooltips.
-- Blackmaw Hold: Blackmaw Reclamation, The Twin Bears, Feeding Time! and the
-- repeatable Blackmaw Pouches were missing; A Lost Memento had no XP.
-- Sunken Temple: The Sunken Temple (Alliance 3445, Horde 3380) is the first
-- step before The Stone Circle; every XP value is now Forever's.
do
    local D, C, XP = FDJ.QUEST_PREREQ_DETAILS, FDJ.QUEST_PREREQ_CHAINS, FDJ.FOREVER_QUEST_XP_FALLBACK
    local bh = FDJ.DB and FDJ.DB["Blackmaw Hold"]
    local EKKAL = "Ekkal, Ruins of Eldarath, Azshara (42.0, 38.9)" -- blackmawaudit (2.0.36)
    local EKKAL_MAP = { mapID = 1447, x = 0.420, y = 0.389, label = "Ekkal — Ruins of Eldarath, Azshara", targetName = "Ekkal" }
    if bh then
        bh.quests = bh.quests or {}
        local have = {}
        for _, q in ipairs(bh.quests) do have[q.id] = true end
        local function Add(q) if not have[q.id] then table.insert(bh.quests, q) have[q.id] = true end end
        Add({
            id = 92066, name = "The Twin Bears", faction = "Both", level = 55, requires = 47,
            pickup = "Lorekeeper Nok, Ursolan, Azshara (41.4, 20.0)", -- confirmed by M; spot: Wowhead Forever (2.0.39)
            objective = "Find the Totem of Ursoc and the Totem of Ursol inside Blackmaw Hold. Then, return them to Lorekeeper Nok at Ursolan.",
            turnin = "Lorekeeper Nok, Ursolan, Azshara (41.4, 20.0)",
            startMap = { mapID = 1447, x = 0.414, y = 0.200, label = "Lorekeeper Nok — Ursolan, Azshara", targetName = "Lorekeeper Nok" },
            turninMap = { mapID = 1447, x = 0.414, y = 0.200, label = "Lorekeeper Nok — Ursolan, Azshara", targetName = "Lorekeeper Nok" },
            liveXPFallback = 11300,
            rewardSummary = "Timbermaw Hold +150",
            rewards = "11,300 XP • Timbermaw Hold +150",
            rewardChoice = true,
            rewardItems = { {279891, "Guidance of Ursoc", 2}, {279892, "Wisdom of Ursol", 2} },
            -- repneeds (2.0.13, M 19 Nov 2026): the need as a reputation bar above
            -- Objective (was this note: "Needs Timbermaw Hold reputation Neutral
            -- or better.").
            repNeeds = {
                { faction = 576, name = "Timbermaw Hold", standing = 4 },
            },
        })
        Add({
            id = 92065, name = "Blackmaw Reclamation", faction = "Both", level = 60, requires = 47,
            pickup = "Gatekeeper Rageroar, Ursolan, Azshara (42.4, 20.2)", -- blackmawaudit (2.0.36)
            objective = "Bring Varrox Bleakhoof's Head to Gatekeeper Rageroar at Ursolan.",
            turnin = "Gatekeeper Rageroar, Ursolan, Azshara (42.4, 20.2)",
            startMap = { mapID = 1447, x = 0.424, y = 0.202, label = "Gatekeeper Rageroar — Ursolan, Azshara", targetName = "Gatekeeper Rageroar" },
            turninMap = { mapID = 1447, x = 0.424, y = 0.202, label = "Gatekeeper Rageroar — Ursolan, Azshara", targetName = "Gatekeeper Rageroar" },
            liveXPFallback = 13200,
            rewardSummary = "Timbermaw Hold +150",
            rewards = "13,200 XP • Timbermaw Hold +150",
            rewardChoice = true,
            rewardItems = { {260216, "Ouroboros Ring", 3}, {260217, "Eagle's Head Signet", 3}, {260218, "Malefactor's End", 3}, {260219, "Engraved Band", 3} },
            note = "Varrox Bleakhoof, the last boss, has the head. Comes after the Blackmaw Counter-Offensive chain. Players report it needs Timbermaw Hold reputation Friendly.",
            repNeeds = { { faction = 576, name = "Timbermaw Hold", standing = 4 } }, -- repneeds (2.0.13, M 19 Nov 2026: Neutral)
        })
        Add({
            id = 96246, name = "Blackmaw Pouches", faction = "Both", level = 60, requires = 55,
            repeatable = true,
            pickup = EKKAL, turnin = EKKAL, startMap = EKKAL_MAP, turninMap = EKKAL_MAP,
            objective = "Enter Blackmaw Hold and recover 5 Blackmaw Pouches for Ekkal at the Ruins of Eldarath in Azshara.",
            rewardSummary = "Timbermaw Hold +100",
            rewards = "Timbermaw Hold +100",
            rewardItems = {},
            requiredItem = { 273050, "Blackmaw Pouch", 1, 5, "From the Blackmaw furbolgs inside Blackmaw Hold" },
            note = "Repeatable, after the first Blackmaw Pouches.",
        })
        Add({
            id = 92067, name = "Feeding Time!", faction = "Both", level = 55, requires = 45,
            repeatable = true,
            pickup = "Not known yet",
            objective = "Bring Fel-Tainted Flesh.",
            turnin = "Not known yet",
            rewardSummary = "Regurgitated Seed Pod",
            rewards = "Regurgitated Seed Pod",
            rewardItems = { {249900, "Regurgitated Seed Pod", 1} },
            note = "Repeatable. By its completion text you feed the flesh to a hungry lasher, which spits out a seed pod. Where it is isn't known yet; please report it on Discord.", -- blackmawaudit (2.0.36)
        })
        for _, q in ipairs(bh.quests) do
            if q.id == 92070 then q.liveXPFallback = 11300 end
        end
        XP[92070] = 11300; XP[92065] = 13200; XP[92066] = 11300; XP[97327] = 13200
    end

    -- Sunken Temple: The Sunken Temple, before The Stone Circle. Two quests,
    -- one per faction; the step shows the character's (set at login).
    local FERALAS = 1444
    D[3445] = {
        level = 51, requires = 46,
        objective = "Find Marvon Rivetseeker in Tanaris.",
        pickup = "Angelas Moonbreeze, Feathermoon Stronghold, Feralas (31.8, 45.6)",
        turnin = "Marvon Rivetseeker, Broken Pillar, Tanaris (52.6, 45.8)",
        map = { mapID = FERALAS, x = 0.318, y = 0.456, label = "Angelas Moonbreeze — Feathermoon Stronghold", targetName = "Angelas Moonbreeze" },
    }
    D[3380] = {
        level = 51, requires = 46,
        objective = "Find Marvon Rivetseeker in Tanaris.",
        pickup = "Witch Doctor Uzer'i, Camp Mojache, Feralas (74.4, 43.4)",
        turnin = "Marvon Rivetseeker, Broken Pillar, Tanaris (52.6, 45.8)",
        map = { mapID = FERALAS, x = 0.744, y = 0.434, label = "Witch Doctor Uzer'i — Camp Mojache", targetName = "Witch Doctor Uzer'i" },
    }
    local ST_STEP = { id = 3445, name = "The Sunken Temple" }
    C[3446] = { ST_STEP, { id = 3444, name = "The Stone Circle" } }
    C[3447] = { ST_STEP, { id = 3444, name = "The Stone Circle" } }
    function FDJ.SetSunkenTempleFaction(faction)
        ST_STEP.id = (faction == "Horde") and 3380 or 3445
    end
    do
        local ok, faction = pcall(UnitFactionGroup, "player")
        if ok and type(faction) == "string" then FDJ.SetSunkenTempleFaction(faction) end
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_LOGIN")
        f:SetScript("OnEvent", function()
            local ok2, fac = pcall(UnitFactionGroup, "player")
            if ok2 and type(fac) == "string" then FDJ.SetSunkenTempleFaction(fac) end
        end)
    end

    local st = FDJ.DB and FDJ.DB["Sunken Temple"]
    local ST_XP = {
        [3373] = 5450, [3446] = 9550, [1445] = 10600, [3447] = 11900, [1446] = 12750,
        [1475] = 13850, [3528] = 15400, [4143] = 9950, [4146] = 9200,
        [9053] = 12400, [8232] = 12400, [8253] = 12400, [8418] = 12400, [8257] = 12400,
        [8236] = 12400, [8413] = 12400, [8422] = 12400, [8425] = 12400,
        [9063] = 500, [8151] = 500, [8250] = 500, [8415] = 500, [8254] = 500, [8233] = 500, [8417] = 500,
    }
    if st then
        for _, q in ipairs(st.quests or {}) do
            if ST_XP[q.id] then q.liveXPFallback = ST_XP[q.id] end
        end
    end
    for id, xp in pairs(ST_XP) do XP[id] = xp end
    -- Chain steps (forever-tool, official values).
    local STEP_XP = {
        [3445] = 3650, [3380] = 6550, [3444] = 4900,
        [1424] = 4450, [1429] = 3750, [1444] = 3750,
        [1448] = 3600, [1449] = 1800, [1450] = 900, [1451] = 1800, [1452] = 3600, [1469] = 2700,
        [3520] = 3750, [4787] = 5900, [4141] = 5100, [4142] = 3800, [4145] = 5100, [4147] = 2550,
        [9052] = 5100, [8153] = 5100, [8231] = 5100, [8251] = 5100, [8252] = 5100,
        [8414] = 5100, [8416] = 2550, [8255] = 5100, [8256] = 5100, [8234] = 5100, [8235] = 5100,
        [8410] = 3800, [8412] = 5100, [8419] = 3800, [8420] = 3800, [8421] = 5100,
        [8423] = 5100, [8424] = 5100,
    }
    for id, xp in pairs(STEP_XP) do XP[id] = xp end
end
-- END blackmawstquests

-- BEGIN shamanrfk
-- 2.0.36: the Shaman weapon chain (reported on Discord: Elemental Aid missing
-- from Razorfen Kraul). Like the other class chains, the journal entry is the
-- final quest, The Tempest's Weapons; Elemental Aid is the dungeon step
-- (Charlga Razorflank drops the Tattered Note). Call of Air, the Air Totem
-- quest, unlocks it but is left out of the steps: the Horde has a different
-- quest ID per trainer city.
do
    local D, C, XP = FDJ.QUEST_PREREQ_DETAILS, FDJ.QUEST_PREREQ_CHAINS, FDJ.FOREVER_QUEST_XP_FALLBACK
    local rfk = FDJ.DB and FDJ.DB["Razorfen Kraul"]
    local VEYRIC = "Veyric Thunderhame, Arathi Highlands (59.6, 27.6)"
    local VEYRIC_MAP = { mapID = 1417, x = 0.596, y = 0.276, label = "Veyric Thunderhame — Arathi Highlands", targetName = "Veyric Thunderhame" }
    local RAU = "Rau Cliffrunner, Freewind Post, Thousand Needles (46.0, 51.6)"
    local RAU_MAP = { mapID = 1441, x = 0.460, y = 0.516, label = "Rau Cliffrunner — Freewind Post", targetName = "Rau Cliffrunner" }
    local PRATE = "Prate Cloudseer, The Weathered Nook, Thousand Needles (53, 42)"
    local PRATE_MAP = { mapID = 1441, x = 0.530, y = 0.420, label = "Prate Cloudseer — The Weathered Nook", targetName = "Prate Cloudseer", detail = "In the cave up the ledge on the north wall, northeast of Freewind Post" }
    local BATHRAH = "Bath'rah the Windwatcher, Alterac Mountains (80.4, 66.8)"
    local NOTE = {274463, "Tattered Note", 1, "Drops from Charlga Razorflank in Razorfen Kraul, for every Shaman on the quest"}
    local TOTEMS = "Twisted Totems only drop while this quest is in your log. Water: Mirefin murlocs, northeast coast of Dustwallow Marsh. Air: Maraudine centaurs, Desolace. Earth: Lost Ones, Swamp of Sorrows. Fire: Dustbelcher ogres and Stonevault troggs, Badlands."
    local RITUAL = "Elite, level 40: bring a group. At the steam pools in Thousand Needles, stand on the rune circle and use the Corrupted Totems. Waves of elementals come, then an elite quilboar and the Ravaging Tempest, which drops the Eye of the Tempest for every Shaman on the quest."
    local WEAPONS = {{280604, "Rage of the Storm", 3}, {280607, "Lightning's Grasp", 3}, {280605, "Tidebringer's Claw", 3}}
    local DUNGEON_NOTE = "Shaman class quest from level 30, unlocked by Call of Air (the Air Totem quest). In this dungeon: Elemental Aid. Kill Charlga Razorflank and loot the Tattered Note; every Shaman on the quest gets one. After that: 20 Twisted Totems from four zones and the elite Heed My Call ritual in Thousand Needles."

    if rfk then
        rfk.quests = rfk.quests or {}
        local have = {}
        for _, q in ipairs(rfk.quests) do have[q.id] = true end
        local function Add(q) if not have[q.id] then table.insert(rfk.quests, q) have[q.id] = true end end
        Add({
            id = 96016, name = "The Tempest's Weapons", faction = "Alliance", classOnly = "SHAMAN",
            warning = "This is a chain quest with a step in Razorfen Kraul",
            level = 40, requires = 30,
            pickup = VEYRIC,
            objective = "Deliver the Eye of the Tempest to Bath'rah the Windwatcher in Alterac Mountains.",
            turnin = BATHRAH,
            note = DUNGEON_NOTE,
            rewardSummary = "",
            rewardChoice = true,
            rewardItems = WEAPONS,
            additionalRewardItems = {{280696, "Elementalist's Guard", 3}},
            liveXPFallback = 3900,
            startMap = VEYRIC_MAP,
        })
        Add({
            id = 79442, name = "The Tempest's Weapons", faction = "Horde", classOnly = "SHAMAN",
            warning = "This is a chain quest with a step in Razorfen Kraul",
            level = 40, requires = 30,
            pickup = "Prate Cloudseer, Thousand Needles (follow your quest log)",
            objective = "Deliver the Eye of the Tempest to Bath'rah the Windwatcher in Alterac Mountains.",
            turnin = BATHRAH,
            note = DUNGEON_NOTE .. " Horde quest givers after the dungeon aren't confirmed yet (Prate Cloudseer or Rau Cliffrunner): follow your quest log.",
            rewardSummary = "",
            rewardChoice = true,
            rewardItems = WEAPONS,
            -- rewardfix2 (2.0.12, M 18 Nov 2026, RFC-Maraudon audit): the shield as for the Alliance (not the unconfirmed rune)
            additionalRewardItems = {{280696, "Elementalist's Guard", 3}},
            startMap = PRATE_MAP,
        })
    end

    C[96016] = {
        { id = 96264, name = "Elemental Aid" },
        { id = 79358, name = "Storm, Earth, and Fire" },
        { id = 96135, name = "Heed My Call" },
    }
    C[79442] = {
        { id = 79360, name = "Elemental Aid" },
        { id = 79364, name = "Eyes on the Sky" },
        { id = 79361, name = "Storm, Earth, and Fire" },
        { id = 79366, name = "Heed My Call" },
    }

    D[96264] = {
        level = 33, requires = 30,
        objective = "Defeat Charlga Razorflank in Razorfen Kraul and collect information on the quilboar's plans.",
        requiredItems = { NOTE },
        pickup = VEYRIC, turnin = VEYRIC,
        description = "The Razorfen Kraul step. Call of Air (from Eldrun Stormbreaker in Ironforge) sends you to Veyric. Alliance Shamans can share this quest.",
        map = VEYRIC_MAP,
    }
    D[79360] = {
        level = 33, requires = 30,
        objective = "Defeat Charlga Razorflank in Razorfen Kraul and collect information on the quilboar's plans.",
        requiredItems = { NOTE },
        pickup = RAU, turnin = RAU,
        description = "The Razorfen Kraul step. After Call of Air, Prate Cloudseer sends you to Rau Cliffrunner. It can't be shared on the Horde side.",
        map = RAU_MAP,
    }
    D[79364] = {
        requires = 30,
        objective = "Speak with Prate Cloudseer in Thousand Needles.",
        pickup = RAU, turnin = PRATE,
        map = RAU_MAP, turninMap = PRATE_MAP,
    }
    D[79358] = {
        requires = 30,
        objective = "Collect 5 Twisted Fire Totems, 5 Twisted Earth Totems, 5 Twisted Air Totems and 5 Twisted Water Totems for Veyric Thunderhame in Arathi Highlands.",
        pickup = VEYRIC, turnin = VEYRIC,
        description = TOTEMS,
        map = VEYRIC_MAP,
    }
    D[79361] = {
        requires = 30,
        objective = "Collect 5 Twisted Fire Totems, 5 Twisted Earth Totems, 5 Twisted Air Totems and 5 Twisted Water Totems and turn them in to Prate Cloudseer in Thousand Needles.",
        pickup = PRATE, turnin = PRATE,
        description = TOTEMS,
        map = PRATE_MAP,
    }
    D[96135] = {
        level = 40, requires = 30,
        objective = "Use the Twisted Totems to put an end to the quilboar ritual.",
        pickup = VEYRIC, turnin = VEYRIC,
        description = RITUAL,
        map = VEYRIC_MAP,
    }
    D[79366] = {
        level = 40, requires = 30,
        objective = "Use the Twisted Totems to put an end to the quilboar ritual.",
        pickup = PRATE, turnin = PRATE,
        description = RITUAL .. " Horde: givers not confirmed yet, follow your quest log.",
        map = PRATE_MAP,
    }
    D[96016] = { level = 40, requires = 30, objective = "Deliver the Eye of the Tempest to Bath'rah the Windwatcher in Alterac Mountains.", pickup = VEYRIC, turnin = BATHRAH, description = "Final step. Choose Rage of the Storm, Lightning's Grasp or Tidebringer's Claw; Alliance Shamans also get Elementalist's Guard." }
    D[79442] = { level = 40, requires = 30, objective = "Deliver the Eye of the Tempest to Bath'rah the Windwatcher in Alterac Mountains.", pickup = "Prate Cloudseer, Thousand Needles (follow your quest log)", turnin = BATHRAH, description = "Final step. Choose Rage of the Storm, Lightning's Grasp or Tidebringer's Claw." }

    XP[96264] = 6950
    XP[96135] = 3150
    XP[96016] = 3900
    FDJ.PREREQ_REWARD_MONEY_FALLBACK[96264] = 3500
    FDJ.PREREQ_REWARD_MONEY_FALLBACK[96135] = 5000
end
-- END shamanrfk

-- BEGIN warriorrfk
-- 2.0.37: the level 20 Warrior armor chains. The journal entry is the final
-- quest (Furen's Armor / Brutal Hauberk); Fire Hardened Mail / Brutal Armor
-- is the step that needs the Vial of Phlogiston from Roogug. The first quest
-- (Yorus Barleybrew / Speak with Ruga) comes from the warrior trainer and is
-- left out of the steps, like Call of Air for the Shaman chain.
do
    local D, C, XP = FDJ.QUEST_PREREQ_DETAILS, FDJ.QUEST_PREREQ_CHAINS, FDJ.FOREVER_QUEST_XP_FALLBACK
    local rfk = FDJ.DB and FDJ.DB["Razorfen Kraul"]
    local FUREN = "Furen Longbeard, Dwarven District, Stormwind (64.6, 37.2)"
    local FUREN_MAP = { mapID = 1453, x = 0.646, y = 0.372, label = "Furen Longbeard — Stormwind", targetName = "Furen Longbeard" }
    local YORUS = "Yorus Barleybrew, Lakeshire, Redridge Mountains"
    -- rfkroute (2.0.28): where he stands (the Lakeshire inn), for the route.
    local YORUS_MAP = { mapID = 1433, x = 0.215, y = 0.447, label = "Yorus Barleybrew — Lakeshire", targetName = "Yorus Barleybrew" }
    local THUNGRIM = "Thun'grim Firegaze, hills east of the Crossroads, The Barrens (57, 30)"
    local THUNGRIM_MAP = { mapID = 1413, x = 0.570, y = 0.300, label = "Thun'grim Firegaze — east of the Crossroads", targetName = "Thun'grim Firegaze", detail = "On the hilltop east of the Crossroads, just south of Thorn Hill" }
    local RUGA = "Ruga Ragetotem, Camp Taurajo, The Barrens"
    local RUGA_MAP = { mapID = 1413, x = 0.450, y = 0.590, label = "Ruga Ragetotem — Camp Taurajo", targetName = "Ruga Ragetotem" }
    local VIAL = {6841, "Vial of Phlogiston", 1, "Drops from Roogug, the first boss in Razorfen Kraul (take the first left)"}

    if rfk then
        rfk.quests = rfk.quests or {}
        local have = {}
        for _, q in ipairs(rfk.quests) do have[q.id] = true end
        local function Add(q) if not have[q.id] then table.insert(rfk.quests, q) have[q.id] = true end end
        Add({
            id = 1782, name = "Furen's Armor", faction = "Alliance", classOnly = "WARRIOR",
            warning = "This is a chain quest with a step in Razorfen Kraul",
            level = 28, requires = 20,
            pickup = FUREN,
            objective = "Wait for Furen Longbeard to finish your armor.",
            turnin = FUREN,
            note = "Warrior class quest from level 20. In this dungeon: Fire Hardened Mail needs the Vial of Phlogiston from Roogug, the first boss. After Fire Hardened Mail, Grimand Elmore (Stormwind), Klockmort Spannerspan (Ironforge) and Mathiel (Darnassus) each make one more piece:",
            noteRewardItems = {{6971, "Fire Hardened Coif", 2}, {6974, "Fire Hardened Gauntlets", 2}, {6973, "Fire Hardened Leggings", 2}},
            rewardSummary = "",
            rewardItems = {{6972, "Fire Hardened Hauberk", 3}},
            liveXPFallback = 3400,
            startMap = FUREN_MAP,
        })
        Add({
            id = 1848, name = "Brutal Hauberk", faction = "Horde", classOnly = "WARRIOR",
            warning = "This is a chain quest with a step in Razorfen Kraul",
            level = 30, requires = 20,
            pickup = THUNGRIM,
            objective = "Wait for Thun'grim Firegaze to finish your armor.",
            turnin = THUNGRIM,
            note = "Warrior class quest from level 20. In this dungeon: Brutal Armor needs the Vial of Phlogiston from Roogug, the first boss. After Brutal Armor, Ula'elek, Orm Stonehoof (Thunder Bluff) and Velora Nitely each make one more piece:",
            noteRewardItems = {{7129, "Brutal Gauntlets", 2}, {7130, "Brutal Helm", 2}, {7132, "Brutal Legguards", 2}},
            rewardSummary = "",
            rewardItems = {{7133, "Brutal Hauberk", 3}},
            liveXPFallback = 3050,
            startMap = THUNGRIM_MAP,
        })
    end

    C[1782] = {
        { id = 1699, name = "The Rethban Gauntlet" },
        { id = 1702, name = "The Shieldsmith" },
        { id = 1701, name = "Fire Hardened Mail", needsDungeon = true }, -- rfkroute: handed in after the run
    }
    C[1848] = {
        { id = 1824, name = "Trial at the Field of Giants" },
        { id = 1825, name = "Speak with Thun'grim" },
        { id = 1838, name = "Brutal Armor" },
    }

    D[1699] = {
        level = 22, requires = 20,
        objective = "Enter the Rethban Caverns, reach the first fork and return to Yorus Barleybrew in time. You must not die and release your spirit.",
        pickup = YORUS, turnin = YORUS,
        description = "Your warrior trainer (Wu Shen in Stormwind, or the trainers in Ironforge and Darnassus) sends you to Yorus Barleybrew in Lakeshire first. The run is timed.",
        map = YORUS_MAP, turninMap = YORUS_MAP,
    }
    D[1702] = {
        level = 22, requires = 20,
        objective = "Bring the Cask of Scalder to Furen Longbeard.",
        pickup = YORUS, turnin = FUREN,
        description = "Furen rewards you with a shield, Furen's Favor.",
        map = YORUS_MAP,
        turninMap = FUREN_MAP,
    }
    D[1701] = {
        level = 28, requires = 20,
        objective = "Gather the materials Furen Longbeard requires, and bring them to him in Stormwind.",
        requiredItems = {
            {6838, "Scorched Spider Fang", 1, "Leech Stalkers and Cave Stalkers at Thelgen Rock, Wetlands (50 needed)"},
            {6839, "Charred Horn", 1, "Fledgeling and Young Chimaeras, Charred Vale, Stonetalon Mountains (12 needed)"},
            {6840, "Galvanized Horn", 1, "Chimaera Matriarch, Charred Vale, Stonetalon Mountains"},
            VIAL,
        },
        providedItem = {6842, "Furen's Instructions", 1, "Given by Furen Longbeard when you accept the quest"},
        pickup = FUREN, turnin = FUREN,
        description = "The Razorfen Kraul step.",
        map = FUREN_MAP,
    }
    D[1782] = { level = 28, requires = 20, objective = "Wait for Furen Longbeard to finish your armor.", pickup = FUREN, turnin = FUREN, description = "Final step. Rewards Fire Hardened Hauberk.", map = FUREN_MAP }
    D[1824] = {
        level = 20, requires = 20,
        objective = "Deliver 5 Twitching Antennae to Ruga Ragetotem at Camp Taurajo.",
        pickup = RUGA, turnin = RUGA,
        description = "Your warrior trainer (Sorek in Orgrimmar) sends you to Ruga first. Timed: 30 minutes. The antennae come from the silithids at the Field of Giants, south of Camp Taurajo.",
        map = RUGA_MAP,
    }
    D[1825] = {
        level = 20, requires = 20,
        objective = "Speak with Thun'grim Firegaze in the Barrens.",
        pickup = RUGA, turnin = THUNGRIM,
        map = RUGA_MAP, turninMap = THUNGRIM_MAP,
    }
    D[1838] = {
        level = 30, requires = 20,
        objective = "Bring Thun'grim Firegaze 15 Smoky Iron Ingots, 10 Powdered Azurite, 10 Iron Bars and a Vial of Phlogiston.",
        requiredItems = {
            {7126, "Smoky Iron Ingot", 1, "Windshear kobolds, Windshear Crag, Stonetalon Mountains (15 needed)"},
            {7127, "Powdered Azurite", 1, "Hillsbrad Miners, Azurelode Mine, Hillsbrad Foothills (10 needed)"},
            {3575, "Iron Bar", 1, "Mining (smelted) or the Auction House (10 needed)"},
            VIAL,
        },
        pickup = THUNGRIM, turnin = THUNGRIM,
        description = "The Razorfen Kraul step.",
        map = THUNGRIM_MAP,
    }
    D[1848] = { level = 30, requires = 20, objective = "Wait for Thun'grim Firegaze to finish your armor.", pickup = THUNGRIM, turnin = THUNGRIM, description = "Final step. Rewards Brutal Hauberk.", map = THUNGRIM_MAP }

    XP[1701] = 2300
    XP[1838] = 3650
    XP[1848] = 3050
end
-- END warriorrfk

-- BEGIN drownedloot
-- The Drowned City as seen in the game (a stream, 2026-11-06): the bosses'
-- levels and the drops seen so far, item IDs from the game's own item data
-- (its hotfix cache). Primeval Elemental, fought with Deathless Marrow,
-- drops its own loot: it has its own page after him.
do
    local d = FDJ.DB and FDJ.DB["The Drowned City"]
    if d and type(d.bosses) == "table" then
        d.fullItemsTBD = true -- only the drops seen so far
        local LOOT = {
            ["Zul'Alai"] = {
                { 274599, "Oathbound Bracers", "Wrist, Leather", 3 }, -- confirmed (Nov 2026)
                { 274598, "Bloodslash Axe", "One-Hand, Axe", 3 }, -- confirmed (a player, Nov 2026)
                { 274600, "Berserker Shackles", "Wrist, Mail", 3 },
            },
            ["Var'Taka"] = {
                { 274602, "Brinebelly Leggings", "Legs, Leather", 3 },
                { 274601, "Harpoon of Command", "Two-Hand, Polearm", 3 }, -- confirmed (Nov 2026)
                { 274613, "Priestess Cloak", "Back", 3 }, -- confirmed (a player, Nov 2026)
            },
            ["Captain Dreadrise"] = {
                { 274604, "Frosty Blunderbuss", "Ranged, Gun", 3 },
                { 274605, "Briny Sash", "Waist, Cloth", 3 },
                { 274603, "Dreadfrost Saber", "Main Hand, Sword", 3 }, -- confirmed (a player, Nov 2026)
            },
            ["Deathless Marrow"] = {
                { 274606, "Bloodspine Staff", "Two-Hand, Staff", 3 },
                { 274614, "Knucklebone Ring", "Finger", 3 }, -- confirmed (a player, Nov 2026)
                { 274607, "Viscera Spaulders", "Shoulder, Mail", 3 }, -- confirmed (Nov 2026)
            },
            ["Primeval Elemental"] = {
                { 274612, "Waterlogged Burial Shroud", "Back", 3 },
                { 274611, "Robe of the Drowned", "Chest, Cloth", 3 }, -- confirmed (Nov 2026)
                { 274615, "Heart of the Primeval", "Trinket", 3 }, -- confirmed (a player, Nov 2026)
            },
            ["Min'loth the Serpent"] = {
                { 274610, "Ritual-Binder's Gloves", "Hands, Leather", 3 },
                { 274608, "Maw of Min'loth", "Off Hand, Shield", 3 }, -- confirmed (a player, Nov 2026)
                { 274609, "Serpentbane Crown", "Head, Mail", 3 }, -- confirmed (a player, Nov 2026)
            },
        }
        -- The rest of the dungeon's loot (the same batch of item IDs,
        -- 274598-274615, in the game's item data): put with a boss by ID order
        -- and required level, nobody has seen it drop yet. Shown folded under
        -- "Not confirmed, but probable drop" on the boss page.
        local PROBABLE = {
            -- (Viscera Spaulders, Deathless Marrow: confirmed, now in his loot)
        }
        local have = false
        for _, b in ipairs(d.bosses) do
            if b.name == "Primeval Elemental" then have = true end
        end
        if not have then
            for i, b in ipairs(d.bosses) do
                if b.name == "Deathless Marrow" then
                    table.insert(d.bosses, i + 1, {
                        name = "Primeval Elemental",
                        portraitNpcID = 270887, -- the client's "Staging Area" copy, for the picture only
                        aliases = { "Primeval Elemental" },
                        description = "Fought together with Deathless Marrow.",
                        loot = {},
                    })
                    break
                end
            end
        end
        for _, b in ipairs(d.bosses) do
            for _, item in ipairs(LOOT[b.name] or {}) do
                b.loot = b.loot or {}
                local dup = false
                for _, listed in ipairs(b.loot) do
                    if listed[2] == item[2] then dup = true end
                end
                if not dup then table.insert(b.loot, item) end
            end
            if PROBABLE[b.name] and not b.probableLoot then b.probableLoot = PROBABLE[b.name] end
        end
        -- Primeval Elemental's page is made here, after Data/SharedLoot.lua:
        -- his share of the dungeon's shared loot (Linken's Boots of Iron).
        if FDJ.SHARED_BY_BOSS then
            local byBoss = FDJ.SHARED_BY_BOSS["The Drowned City"] or {}
            FDJ.SHARED_BY_BOSS["The Drowned City"] = byBoss
            local list = byBoss["Primeval Elemental"] or {}
            byBoss["Primeval Elemental"] = list
            local have = false
            for _, item in ipairs(list) do if tonumber(item[1]) == 271718 then have = true end end
            if not have then list[#list + 1] = { 271718, "Linken's Boots of Iron", "Feet, Mail", 3 } end
        end
    end
    if FDJ.BOSS_LEVELS then
        FDJ.BOSS_LEVELS["The Drowned City"] = FDJ.BOSS_LEVELS["The Drowned City"] or {}
        local levels = FDJ.BOSS_LEVELS["The Drowned City"]
        levels["Zul'Alai"] = "37"
        levels["Var'Taka"] = "38"
        levels["Captain Dreadrise"] = "38"
        levels["Deathless Marrow"] = "39"
        levels["Primeval Elemental"] = "38"
        levels["Gill"] = "38"
        levels["Umbra"] = "38" -- rare; level from its nameplate (Discord screenshot, Nov 2026)
        levels["\"Pyromancer\" Braxton"] = "38" -- rare elite; level from its nameplate (a stream, Nov 2026)
        levels["Min'loth the Serpent"] = "40"
    end
end
-- END drownedloot

-- BEGIN kroldokquests
-- Krol'dok Stronghold: the Alliance Tome of Twilight follows A Small Favor
-- (Wowhead Forever). Vengeance of the Highborne: Ranath Nightstride in the
-- inn in Dalaran (a player, Nov 2026; Wowhead Forever's spawn of NPC
-- 268425), who also pays for it (the quest text); shareable (Wowhead).
do
    local RANATH = { mapID = 1416, x = 0.178, y = 0.660, label = "Ranath Nightstride — Dalaran", targetName = "Ranath Nightstride", detail = "Ranath Nightstride, in the inn in Dalaran, Alterac Mountains" }
    FDJ.QUEST_START_MAPS[96771] = RANATH
    for _, quest in ipairs((FDJ.DB["Krol'dok Stronghold"] and FDJ.DB["Krol'dok Stronghold"].quests) or {}) do
        if quest.id == 96771 then quest.turninMap = RANATH end
    end
    FDJ.QUEST_SHAREABILITY_AUDIT[96771] = true

    -- Before A Small Favor: Ashe Amberhall's two Sunnyglade quests
    -- (Wowhead Forever 94879, 94881; a reported chain, Nov 2026).
    local ASHE = { mapID = 2548, x = 0.666, y = 0.810, label = "Ashe Amberhall — Farholde Keep, Riverglades", targetName = "Ashe Amberhall" }
    local AT_ASHE = "Ashe Amberhall, Farholde Keep, Riverglades"
    FDJ.QUEST_PREREQ_CHAINS[94984] = {
        { id = 94879, name = "Scraps of Knowledge" },
        { id = 94881, name = "Curious Trinkets" },
        { id = 94907, name = "A Small Favor" },
    }
    FDJ.QUEST_PREREQ_DETAILS[94879] = {
        level = 40, requires = 36,
        objective = "Collect 5 Twilight Pages from within Sunnyglade for Ashe Amberhall in Farholde Keep.",
        pickup = AT_ASHE, turnin = AT_ASHE, map = ASHE, turninMap = ASHE,
        requiredItems = { {266424, "Twilight Page", 1, "From the Twilight's Hammer in Sunnyglade (5 needed)"} },
        note = "Done alongside Curious Trinkets.",
    }
    FDJ.QUEST_PREREQ_DETAILS[94881] = {
        level = 38, requires = 36,
        objective = "Retrieve 25 Twilight Charms from Twilight Shadowmancers and Twilight Neophytes in Sunnyglade for Ashe Amberhall in Farholde Keep.",
        pickup = AT_ASHE, turnin = AT_ASHE, map = ASHE, turninMap = ASHE,
        requiredItems = { {266425, "Twilight Charm", 1, "Dropped by Twilight Shadowmancers and Twilight Neophytes in Sunnyglade (25 needed)"} },
        note = "Done alongside Scraps of Knowledge.",
    }

    -- The key quests: a Krol'dok Moulding looted in the stronghold starts
    -- Krol'dok Moulding (Wowhead Forever 94980 / 94973), then Key
    -- Ingredients (94981 / 94974) gives the Krol'dok Compound Key.
    FDJ.QUEST_PREREQ_CHAINS[94981] = { { id = 94980, name = "Krol'dok Moulding" } }
    FDJ.QUEST_PREREQ_CHAINS[94974] = { { id = 94973, name = "Krol'dok Moulding" } }
    FDJ.QUEST_PREREQ_DETAILS[94980] = {
        level = 41, requires = 38, startsInDungeon = true,
        objective = "Find someone in Farholde Keep who may know about the mould.",
        pickup = "Krol'dok Moulding, dropped by Tunk in Krol'dok Stronghold",
        startItem = {267138, "Krol'dok Moulding", 1, "Dropped by Tunk, at the forge beside War Handler Ashka in Krol'dok Stronghold; everyone in the group can loot it"},
        turnin = "Alphonse Dumas, Farholde Keep, Riverglades (64.4, 82.0)", turninMap = { mapID = 2548, x = 0.644, y = 0.820, label = "Alphonse Dumas — Farholde Keep, Riverglades", targetName = "Alphonse Dumas" },
    }
    FDJ.QUEST_PREREQ_DETAILS[94973] = {
        level = 41, requires = 38, startsInDungeon = true,
        objective = "Find someone in Rog'mar who may know about the mould.",
        pickup = "Krol'dok Moulding, dropped by Tunk in Krol'dok Stronghold",
        startItem = {267137, "Krol'dok Moulding", 1, "Dropped by Tunk, at the forge beside War Handler Ashka in Krol'dok Stronghold; everyone in the group can loot it"},
        turnin = "Kreza Darkthorn, Rog'mar, Riverglades (59.8, 46.0)", turninMap = { mapID = 2548, x = 0.598, y = 0.460, label = "Kreza Darkthorn — Rog'mar, Riverglades", targetName = "Kreza Darkthorn" },
    }

    -- Twilight Mementos > Lingering Essence > Curios of Curiosity (Wowhead
    -- Forever's series, 2.0.20): the last is the list's entry. Sergeant
    -- Riftan gives the first two (Wowhead Forever; a Discord report).
    local KD_RIFTAN = { mapID = 2548, x = 0.306, y = 0.490, label = "Sergeant Riftan — Farholde Lookouts, Twilight's Shroud", targetName = "Sergeant Riftan" }
    -- Twilight Mementos opens once Bring Me His Head is handed in to
    -- Sergeant Riftan (a Wowhead Forever comment on 94983, Nov 2026).
    FDJ.QUEST_PREREQ_CHAINS[94998] = {
        { id = 94890, name = "Bring Me His Head" },
        { id = 94983, name = "Twilight Mementos" },
        { id = 94997, name = "Lingering Essence" },
    }
    FDJ.QUEST_PREREQ_DETAILS[94890] = {
        level = 46, requires = 38,
        objective = "Defeat Overlord Kilgar within the Twilight's Shroud and bring his head to Sergeant Riftan.",
        pickup = "Farholde Keep, Riverglades (giver not known yet)",
        turnin = "Sergeant Riftan, Farholde Keep, Riverglades",
        requiredItems = { {265837, "Kilgar's Head", 1, "From Overlord Kilgar in the Twilight's Shroud, Riverglades"} },
        note = "Handing it in to Sergeant Riftan unlocks Twilight Mementos.",
    }
    FDJ.QUEST_PREREQ_DETAILS[94983] = {
        level = 42, requires = 38,
        note = "Unlocked by handing in Bring Me His Head to Sergeant Riftan.",
        objective = "Collect 8 Twilight Bangles from the Twilight's Hammer in Krol'dok Stronghold.",
        pickup = "Sergeant Riftan, Farholde Lookouts, Twilight's Shroud, Riverglades (30.6, 49.0)",
        turnin = "Sergeant Riftan, Farholde Lookouts, Twilight's Shroud, Riverglades",
        map = KD_RIFTAN, turninMap = KD_RIFTAN,
        requiredItems = { {267234, "Twilight Bangle", 1, "Dropped by the Twilight's Hammer cultists in Krol'dok Stronghold (8 needed)"} },
    }
    FDJ.QUEST_PREREQ_DETAILS[94997] = {
        level = 42, requires = 38,
        objective = "Bring the Satchel of Cursed Mementos to Ashe Amberhall in Farholde Keep.",
        pickup = "Sergeant Riftan, Farholde Lookouts, Twilight's Shroud, Riverglades (30.6, 49.0)", map = KD_RIFTAN,
        turnin = AT_ASHE, turninMap = ASHE,
        providedItem = {268035, "Satchel of Cursed Mementos", 1, "Given when you accept the quest"},
    }
    FDJ.QUEST_START_MAPS[94998] = ASHE

    -- Rewards (Wowhead Forever): XP, money and items of the new steps.
    FDJ.FOREVER_QUEST_XP_FALLBACK[94879] = 3150
    FDJ.FOREVER_QUEST_XP_FALLBACK[94881] = 2850
    FDJ.FOREVER_QUEST_XP_FALLBACK[94980] = 3300
    FDJ.FOREVER_QUEST_XP_FALLBACK[94973] = 3300
    FDJ.FOREVER_QUEST_XP_FALLBACK[94981] = 3300
    FDJ.FOREVER_QUEST_XP_FALLBACK[94974] = 3300
    FDJ.FOREVER_QUEST_XP_FALLBACK[94890] = 5050
    FDJ.FOREVER_QUEST_XP_FALLBACK[94997] = 3450
    FDJ.FOREVER_QUEST_XP_FALLBACK[94998] = 3450
    FDJ.FOREVER_QUEST_XP_FALLBACK[96772] = 14400
    FDJ.PREREQ_REWARD_MONEY_FALLBACK[94980] = 5500
    FDJ.PREREQ_REWARD_MONEY_FALLBACK[94973] = 5500
    FDJ.PREREQ_REWARD_MONEY_FALLBACK[94997] = 5500
    FDJ.PREREQ_REWARD_ITEMS_FALLBACK[94890] = { items = { {275046, "Twilight Overlord Drape", 2}, {275049, "Farholde Bastion", 2} }, choice = true }
    for _, quest in ipairs((FDJ.DB["Krol'dok Stronghold"] and FDJ.DB["Krol'dok Stronghold"].quests) or {}) do
        if quest.id == 94983 then quest.hideFromMainList = true end
    end
    FDJ.QUEST_PREREQ_DETAILS[94907] = {
        objective = "Summon a Twilight's Thrall from a conduit within the Twilight's Shroud and capture it with Amberhall's Soulstone.",
        pickup = AT_ASHE, turnin = AT_ASHE, map = ASHE, turninMap = ASHE,
        providedItem = {0, "Amberhall's Soulstone", 1, "Given by Ashe Amberhall when you accept the quest"},
    }
    FDJ.FOREVER_QUEST_XP_FALLBACK[94968] = 11500
    FDJ.FOREVER_QUEST_XP_FALLBACK[94972] = 11050
    FDJ.FOREVER_QUEST_XP_FALLBACK[94975] = 8200
    FDJ.FOREVER_QUEST_XP_FALLBACK[94982] = 11500
    FDJ.FOREVER_QUEST_XP_FALLBACK[94983] = 10200
    FDJ.FOREVER_QUEST_XP_FALLBACK[94984] = 11050
    FDJ.FOREVER_QUEST_XP_FALLBACK[96771] = 11500
    FDJ.FOREVER_QUEST_XP_FALLBACK[94907] = 3750
end
-- BEGIN kroldokeyeofmugglocations
-- Eye of Mugg uses different faction quest IDs. The two versions of
-- Bring Me His Head are different quests as well; never share one ID.
-- Locations: Krom'rosh at Rog'mar (59.4,45.5); Demar Brant at Farholde
-- Keep (66.6,79.9); Da'grosh at the Shroud (33.4,38.0); Sgt. Riftan
-- with the Farholde Lookouts (30.4,49.0), all on Riverglades map 2548.
do
    local ROGMAR = {
        mapID = 2548, x = 0.594, y = 0.455,
        label = "Krom'rosh — Rog'mar, Riverglades", targetName = "Krom'rosh",
        detail = "Eye of Mugg (Horde): pick up and return to Krom'rosh at Rog'mar."
    }
    local FARHOLDE = {
        mapID = 2548, x = 0.666, y = 0.810,
        label = "Commander Demar Brant — Farholde Keep, Riverglades", targetName = "Demar Brant",
        detail = "Eye of Mugg (Alliance): pick up and return to Commander Demar Brant at Farholde Keep."
    }
    local DAGROSH = {
        mapID = 2548, x = 0.334, y = 0.380,
        label = "Da'grosh — Twilight's Shroud, Riverglades", targetName = "Da'grosh"
    }
    local RIFTAN = {
        mapID = 2548, x = 0.306, y = 0.490,
        label = "Sergeant Riftan — Farholde Lookouts, Twilight's Shroud", targetName = "Sergeant Riftan"
    }
    FDJ.QUEST_START_MAPS[94968] = ROGMAR
    FDJ.QUEST_START_MAPS[94982] = FARHOLDE
    FDJ.QUEST_START_MAPS[94768] = DAGROSH
    FDJ.QUEST_START_MAPS[94890] = RIFTAN

    -- Separate prerequisite records avoid cross-faction completion checks.
    -- The Horde's Twilight's Hammer chain (2.0.20; a Wowhead Forever comment
    -- on 94968, players' quest logs on Discord): The Wayward Warrior, then
    -- Break Their Chains, Carving a Path and Rise Up!, then Bring Me His
    -- Head, which opens A Token of Vengeance (Da'grosh); It Is Time,
    -- Brother... then opens Eye of Mugg (Krom'rosh) and Tome of Twilight
    -- (Tran'gul) at Rog'mar.
    local HORDE_TWILIGHT = {
        { id = 94744, name = "The Wayward Warrior" },
        { id = 94748, name = "Break Their Chains" },
        { id = 94745, name = "Carving a Path" },
        { id = 95432, name = "Rise Up!" },
        { id = 94768, name = "Bring Me His Head" },
    }
    local function hordeChain(withMissive)
        local chain = {}
        for i, step in ipairs(HORDE_TWILIGHT) do chain[i] = { id = step.id, name = step.name } end
        if withMissive then chain[#chain + 1] = { id = 95278, name = "It Is Time, Brother..." } end
        return chain
    end
    local TRANGUL = {
        mapID = 2548, x = 0.594, y = 0.440,
        label = "Tran'gul — Rog'mar, Riverglades", targetName = "Tran'gul"
    }
    FDJ.QUEST_PREREQ_CHAINS[94968] = hordeChain(true)
    FDJ.QUEST_PREREQ_CHAINS[94972] = hordeChain(true)
    FDJ.QUEST_PREREQ_CHAINS[94975] = hordeChain(false)
    FDJ.QUEST_START_MAPS[94972] = TRANGUL
    FDJ.QUEST_START_MAPS[94975] = DAGROSH
    FDJ.QUEST_START_MAPS[94983] = RIFTAN
    FDJ.QUEST_PREREQ_DETAILS[94744] = {
        pickup = "Riverglades (giver not known yet)",
        objective = "The first step of the Horde's fight against the Twilight's Hammer in the Riverglades.",
        turnin = "Riverglades (not known yet)",
    }
    FDJ.QUEST_PREREQ_DETAILS[94748] = {
        objective = "Rescue 5 Rog'mar Scouts within the Twilight's Shroud for Da'grosh.",
        pickup = "Da'grosh, Twilight's Shroud, Riverglades (33.4, 38.0)",
        turnin = "Da'grosh, Twilight's Shroud, Riverglades (33.4, 38.0)",
        map = DAGROSH, turninMap = DAGROSH,
    }
    FDJ.QUEST_PREREQ_DETAILS[94745] = {
        pickup = "Riverglades (giver not known yet)",
        objective = "Done alongside Break Their Chains and Rise Up!.",
        turnin = "Riverglades (not known yet)",
    }
    FDJ.QUEST_PREREQ_DETAILS[95432] = {
        pickup = "Riverglades (giver not known yet)",
        objective = "Done alongside Break Their Chains and Carving a Path.",
        turnin = "Riverglades (not known yet)",
    }
    FDJ.QUEST_PREREQ_DETAILS[95278] = {
        objective = "Deliver the missive to Krom'rosh at Rog'mar.",
        pickup = "Da'grosh, Twilight's Shroud, Riverglades (probably)",
        turnin = "Krom'rosh, Rog'mar, Riverglades (59.4, 45.5)",
        turninMap = ROGMAR,
        note = "Handing it in opens Eye of Mugg (Krom'rosh) and Tome of Twilight (Tran'gul).",
    }
    FDJ.FOREVER_QUEST_XP_FALLBACK[94744] = 360
    FDJ.FOREVER_QUEST_XP_FALLBACK[94748] = 3750
    FDJ.FOREVER_QUEST_XP_FALLBACK[94745] = 3750
    FDJ.FOREVER_QUEST_XP_FALLBACK[95432] = 1800
    FDJ.FOREVER_QUEST_XP_FALLBACK[95278] = 390
    FDJ.QUEST_PREREQ_CHAINS[94982] = { { id = 94890, name = "Bring Me His Head" } }
    FDJ.QUEST_PREREQ_DETAILS[94768] = {
        level = 46, requires = 38,
        objective = "Defeat Overlord Kilgar within the Twilight's Shroud and bring his head to Da'grosh.",
        pickup = "Da'grosh, Twilight's Shroud, Riverglades (33.4, 38.0)",
        turnin = "Da'grosh, Twilight's Shroud, Riverglades (33.4, 38.0)",
        map = DAGROSH, turninMap = DAGROSH,
        requiredItems = { {265837, "Kilgar's Head", 1, "From Overlord Kilgar at Twilight's Shroud"} },
        note = "Horde version. Handing it in to Da'grosh opens A Token of Vengeance."
    }
    -- Preserve the Alliance record already used by Twilight Mementos.
    local ally = FDJ.QUEST_PREREQ_DETAILS[94890] or {}
    ally.pickup = "Sergeant Riftan, Farholde Lookouts, Twilight's Shroud, Riverglades (30.6, 49.0)"
    ally.turnin = "Sergeant Riftan, Farholde Lookouts, Twilight's Shroud, Riverglades (30.6, 49.0)"
    ally.map = RIFTAN
    ally.turninMap = RIFTAN
    ally.note = "Alliance version. Return Kilgar's Head to Sergeant Riftan; completing this step unlocks Eye of Mugg."
    FDJ.QUEST_PREREQ_DETAILS[94890] = ally
    FDJ.FOREVER_QUEST_XP_FALLBACK[94768] = 5050

    for _, quest in ipairs((FDJ.DB["Krol'dok Stronghold"] and FDJ.DB["Krol'dok Stronghold"].quests) or {}) do
        if quest.id == 94968 then
            quest.startMap = ROGMAR
            quest.turninMap = ROGMAR
        elseif quest.id == 94982 then
            quest.startMap = FARHOLDE
            quest.turninMap = FARHOLDE
        elseif quest.id == 94972 then
            quest.startMap = TRANGUL
            quest.turninMap = TRANGUL
        elseif quest.id == 94975 then
            quest.startMap = DAGROSH
            quest.turninMap = DAGROSH
        elseif quest.id == 94983 then
            quest.startMap = RIFTAN
            quest.turninMap = RIFTAN
        elseif quest.id == 94998 then
            quest.turninMap = { mapID = 2548, x = 0.662, y = 0.832, label = "Melanie Sable — Farholde Keep, Riverglades", targetName = "Melanie Sable" }
        elseif quest.id == 94981 then
            quest.startMap = { mapID = 2548, x = 0.644, y = 0.820, label = "Alphonse Dumas — Farholde Keep, Riverglades", targetName = "Alphonse Dumas" }
            quest.turninMap = quest.startMap
        elseif quest.id == 94974 then
            quest.startMap = { mapID = 2548, x = 0.598, y = 0.460, label = "Kreza Darkthorn — Rog'mar, Riverglades", targetName = "Kreza Darkthorn" }
            quest.turninMap = quest.startMap
        elseif quest.id == 94984 then
            quest.startMap = { mapID = 2548, x = 0.666, y = 0.810, label = "Ashe Amberhall — Farholde Keep, Riverglades", targetName = "Ashe Amberhall" }
            quest.turninMap = quest.startMap
        end
    end
end
-- END kroldokeyeofmugglocations

-- BEGIN kroldokchains2
-- 2.0.21: the full unlock chains of Krol'dok Stronghold's dungeon quests.
-- Alliance Eye of Mugg: starts with Scraps of Knowledge (Mobalytics); The
-- Western Front, No Soldier Left Behind, Carving a Path, Bring Me His Head
-- and News to Farholde from Wowhead Forever (Bring Me His Head's series,
-- "available once Kilgar has been killed" on 94982, "this quest area leads
-- to Eye of Mugg and Twilight Mementos" on 94886). Twilight Mementos:
-- starts with Saving Sunnyglade (Mobalytics). Horde: Encroaching Twilight
-- first (Mobalytics), then Clugfist's Decree > The Wayward Warrior
-- (Wowhead series) and the steps of the Wowhead comment on 94968.
do
    local M = 2548
    local BRANT = { mapID = M, x = 0.666, y = 0.810, label = "Demar Brant — Farholde Keep, Riverglades", targetName = "Demar Brant" }
    local ASHE = { mapID = M, x = 0.666, y = 0.810, label = "Ashe Amberhall — Farholde Keep, Riverglades", targetName = "Ashe Amberhall" }
    local RIFTAN = { mapID = M, x = 0.306, y = 0.490, label = "Sergeant Riftan — Farholde Lookouts, Twilight's Shroud", targetName = "Sergeant Riftan" }
    local KROM = { mapID = M, x = 0.594, y = 0.456, label = "Krom'rosh — Rog'mar, Riverglades", targetName = "Krom'rosh" }
    local TRANGUL = { mapID = M, x = 0.594, y = 0.440, label = "Tran'gul — Rog'mar, Riverglades", targetName = "Tran'gul" }
    local DAGROSH = { mapID = M, x = 0.334, y = 0.380, label = "Da'grosh — Twilight's Shroud, Riverglades", targetName = "Da'grosh" }
    local CRAGROG = { mapID = M, x = 0.274, y = 0.370, label = "Crag'rog — Riverglades", targetName = "Crag'rog" }
    local CLUGFIST = { mapID = M, x = 0.644, y = 0.148, label = "Clugfist — Riverglades", targetName = "Clugfist" }
    local AT_BRANT = "Demar Brant, Farholde Keep, Riverglades (66.6, 81.0)"
    local AT_ASHE = "Ashe Amberhall, Farholde Keep, Riverglades (66.6, 81.0)"
    local AT_RIFTAN = "Sergeant Riftan, Farholde Lookouts, Twilight's Shroud, Riverglades (30.6, 49.0)"
    local AT_KROM = "Krom'rosh, Rog'mar, Riverglades (59.4, 45.6)"
    local AT_DAGROSH = "Da'grosh, Twilight's Shroud, Riverglades (33.4, 38.0)"
    local function Copy(list)
        local out = {}
        for i, s in ipairs(list) do out[i] = { id = s.id, name = s.name } end
        return out
    end

    -- Alliance
    local RIFTAN_LINE = {
        { id = 94886, name = "The Western Front" },
        { id = 94888, name = "No Soldier Left Behind" },
        { id = 94889, name = "Carving a Path" },
        { id = 94890, name = "Bring Me His Head" },
    }
    local eye = { { id = 94879, name = "Scraps of Knowledge" } }
    for _, s in ipairs(RIFTAN_LINE) do eye[#eye + 1] = { id = s.id, name = s.name } end
    eye[#eye + 1] = { id = 94891, name = "News to Farholde" }
    FDJ.QUEST_PREREQ_CHAINS[94982] = eye
    local curios = { { id = 94877, name = "Saving Sunnyglade" } }
    for _, s in ipairs(RIFTAN_LINE) do curios[#curios + 1] = { id = s.id, name = s.name } end
    curios[#curios + 1] = { id = 94983, name = "Twilight Mementos" }
    curios[#curios + 1] = { id = 94997, name = "Lingering Essence" }
    FDJ.QUEST_PREREQ_CHAINS[94998] = curios

    local D = FDJ.QUEST_PREREQ_DETAILS
    D[94879] = D[94879] or {}
    D[94879].note = "First step of the Eye of Mugg chain (Mobalytics). Done alongside Curious Trinkets; what leads from Ashe's quests to The Western Front is not confirmed yet."
    D[94877] = {
        level = 40, requires = 36,
        objective = "Defeat 8 Twilight Raiders, 8 Twilight Shadowmancers and 8 Twilight Neophytes within Sunnyglade for Demar Brant.",
        pickup = AT_BRANT, turnin = AT_BRANT, map = BRANT, turninMap = BRANT,
        note = "First step of the Twilight Mementos chain (Mobalytics); what leads from it to The Western Front is not confirmed yet.",
    }
    D[94886] = {
        level = 44, requires = 38,
        objective = "Find Sergeant Riftan near the Twilight's Shroud to the west.",
        pickup = AT_BRANT, turnin = AT_RIFTAN, map = BRANT, turninMap = RIFTAN,
    }
    D[94888] = {
        level = 44, requires = 38,
        objective = "Rescue 5 Farholde Scouts within the Twilight's Shroud for Sergeant Riftan.",
        pickup = AT_RIFTAN, turnin = AT_RIFTAN, map = RIFTAN, turninMap = RIFTAN,
        note = "Done alongside Carving a Path.",
    }
    D[94889] = {
        level = 44, requires = 38,
        objective = "Defeat 8 Twilight Fanatics, 8 Twilight Corrupters and 8 Twilight Champions within the Twilight's Shroud for Sergeant Riftan.",
        pickup = AT_RIFTAN, turnin = AT_RIFTAN, map = RIFTAN, turninMap = RIFTAN,
        note = "Done alongside No Soldier Left Behind.",
    }
    if D[94890] then D[94890].note = "Alliance version. Handing it in to Sergeant Riftan gives News to Farholde and opens Twilight Mementos." end
    D[94891] = {
        level = 46, requires = 38,
        objective = "Return to Ashe Amberhall in Farholde Keep.",
        pickup = "Given when you hand in Bring Me His Head to Sergeant Riftan",
        turnin = AT_ASHE, turninMap = ASHE,
        providedItem = {265837, "Kilgar's Head", 1, "Given when you accept the quest"},
        note = "Handing it in opens Eye of Mugg (Demar Brant).",
    }

    -- Horde
    -- muggchain (2.0.8, M 15 Nov 2026: his "Eye of Mugg: Horde chain audit",
    -- a player's report that the list jumped from Encroaching Twilight to
    -- Clugfist's Decree): the whole way to Clugfist's Decree is listed now.
    -- Krom'rosh's two first quests, then Tran'gul's two Twilight quests,
    -- Clubtoe's quests in the Sunnyglade cave (two quests are called The
    -- Purple Ones: 95417, then 95601), back to Tran'gul, on to Clugfist and
    -- his two quests. Quests done side by side follow each other in the list
    -- (every step is needed). Rise Up! stays (a player's report on Wowhead's
    -- 94968 lists it; the quest databases don't), with the quest that leads
    -- to it, Rumblings of Discontent, before it.
    local horde = {
        { id = 93786, name = "A Message in Blood" },
        { id = 93787, name = "Food for the Taking" },
        { id = 94483, name = "Show Them How It's Done" },
        { id = 94672, name = "Encroaching Twilight" },
        { id = 94680, name = "Twilight Missives" },
        { id = 94727, name = "Digging for Answers" },
        { id = 95417, name = "The Purple Ones" },
        { id = 95601, name = "The Purple Ones" },
        { id = 95602, name = "Sickening Lights" },
        { id = 95427, name = "Twilight No More!" },
        { id = 95418, name = "Spread the Word" },
        { id = 95420, name = "Land of Giants" },
        { id = 95424, name = "Might Makes Right" },
        { id = 95425, name = "Unworthy Champion" },
        { id = 95428, name = "Clugfist's Decree" },
        { id = 94744, name = "The Wayward Warrior" },
        { id = 94748, name = "Break Their Chains" },
        { id = 94745, name = "Carving a Path" },
        { id = 95431, name = "Rumblings of Discontent" },
        { id = 95432, name = "Rise Up!" },
        { id = 94768, name = "Bring Me His Head" },
    }
    local withMissive = Copy(horde)
    withMissive[#withMissive + 1] = { id = 95278, name = "It Is Time, Brother..." }
    FDJ.QUEST_PREREQ_CHAINS[94968] = withMissive
    FDJ.QUEST_PREREQ_CHAINS[94972] = Copy(withMissive)
    FDJ.QUEST_PREREQ_CHAINS[94975] = Copy(horde)
    D[94483] = {
        level = 42, requires = 38,
        objective = "Slay 8 Farholde Priests and 12 Farholde Scouts south of the river.",
        pickup = "Riverglades (giver not known yet)", turnin = "Riverglades (not known yet)",
        note = "Needed before the Twilight's Hammer quests (a player's report on the Discord).",
    }
    FDJ.FOREVER_QUEST_XP_FALLBACK[94483] = 3000
    D[94672] = {
        level = 41, requires = 36,
        objective = "Defeat 8 Twilight Raiders, 8 Twilight Shadowmancers and 8 Twilight Neophytes within Sunnyglade for Tran'gul in Rog'mar.",
        pickup = "Tran'gul, Rog'mar, Riverglades (59.4, 44.0)", turnin = "Tran'gul, Rog'mar, Riverglades",
        map = TRANGUL, turninMap = TRANGUL,
        note = "Start of the Horde chains (Mobalytics); what leads from it to Clugfist's Decree is not confirmed yet.",
    }
    D[95428] = {
        level = 41, requires = 36,
        objective = "Report to Krom'rosh in Rog'mar.",
        pickup = "Clugfist, Riverglades (64.4, 14.8)", turnin = AT_KROM,
        map = CLUGFIST, turninMap = KROM,
    }
    D[94744] = {
        level = 43, requires = 38,
        objective = "Find Da'grosh in the hills west of Rog'mar.",
        pickup = AT_KROM, turnin = AT_DAGROSH, map = KROM, turninMap = DAGROSH,
    }
    D[94748] = D[94748] or {}
    D[94748].level, D[94748].requires = 44, 38
    D[94748].note = "Done alongside Carving a Path and Rise Up!."
    D[94745] = {
        level = 44, requires = 38,
        objective = "Defeat 8 Twilight Fanatics, 8 Twilight Corrupters and 8 Twilight Champions within the Twilight's Shroud for Da'grosh.",
        pickup = AT_DAGROSH, turnin = AT_DAGROSH, map = DAGROSH, turninMap = DAGROSH,
        note = "Done alongside Break Their Chains and Rise Up!.",
    }
    D[95432] = {
        level = 43, requires = 36,
        objective = "Recruit 5 Ogre Miners.",
        pickup = "Crag'rog, Riverglades (27.4, 37.0)", turnin = "Crag'rog, Riverglades (27.4, 37.0)",
        map = CRAGROG, turninMap = CRAGROG,
        note = "Done alongside Break Their Chains and Carving a Path.",
    }
    D[95278] = D[95278] or {}
    D[95278].level, D[95278].requires = 45, 38
    D[95278].pickup = AT_DAGROSH
    D[95278].map = DAGROSH
    D[95278].providedItem = {0, "Blood and Battle", 1, "Given by Da'grosh when you accept the quest"}

    local XP = FDJ.FOREVER_QUEST_XP_FALLBACK
    XP[94877] = 3150; XP[94886] = 380; XP[94888] = 3750; XP[94889] = 3750; XP[94891] = 4050
    XP[94672] = 3300; XP[95428] = 330

    -- muggchain (2.0.8): the steps added to the Horde chain, and what was
    -- not known about the old ones. Givers, hand-ins, levels and XP: Icy
    -- Veins Forever and forever-xp.com (they agree); where they stand:
    -- forever-xp.com.
    local CLUBTOE = { mapID = M, x = 0.500, y = 0.470, label = "Clubtoe — Sunnyglade cave, Riverglades", targetName = "Clubtoe" }
    local BRUTE = { mapID = M, x = 0.492, y = 0.467, label = "Twilight Brute — Sunnyglade cave, Riverglades", targetName = "Twilight Brute" }
    local AT_TRANGUL = "Tran'gul, Rog'mar, Riverglades (59.5, 44.0)"
    local AT_CLUBTOE = "Clubtoe, in the cave under Sunnyglade, Riverglades (50.0, 47.0; the cave's entrance is near 50, 46)"
    local AT_BRUTE = "Twilight Brute, in the cave under Sunnyglade, Riverglades (49.2, 46.7)"
    local AT_CLUGFIST = "Clugfist, Bolder'ok, Riverglades (64.4, 14.8)"
    local AT_CRAGROG = "Crag'rog, Riverglades (27.4, 37.0)"
    D[93786] = {
        level = 36, requires = 35,
        objective = "Slay 12 Meadowsbrook Farmhands, then return to Krom'rosh with news of your success.",
        pickup = AT_KROM, turnin = AT_KROM, map = KROM, turninMap = KROM,
        note = "Done alongside Food for the Taking.",
    }
    D[93787] = {
        level = 36, requires = 36,
        objective = "Steal 6 Feed Satchels from the Alliance farm in Meadowsbrook then return to Krom'rosh.",
        pickup = AT_KROM, turnin = AT_KROM, map = KROM, turninMap = KROM,
        note = "Done alongside A Message in Blood. Krom'rosh offers Show Them How It's Done once this is handed in.",
    }
    D[94483].level, D[94483].requires = 39, 36
    D[94483].pickup, D[94483].turnin = AT_KROM, AT_KROM
    D[94483].map, D[94483].turninMap = KROM, KROM
    D[94672].note = "Done alongside Twilight Missives; Tran'gul gives Digging for Answers once both are handed in."
    D[94680] = {
        level = 41, requires = 36,
        objective = "Retrieve 3 Twilight Missives from Twilight Shadowmancers in Sunnyglade for Tran'gul in Rog'mar.",
        pickup = AT_TRANGUL, turnin = AT_TRANGUL, map = TRANGUL, turninMap = TRANGUL,
        note = "Done alongside Encroaching Twilight; Tran'gul gives Digging for Answers once both are handed in.",
    }
    D[94727] = {
        level = 40, requires = 36,
        objective = "Convince a Twilight's Hammer miner in Sunnyglade to divulge their secrets.",
        pickup = AT_TRANGUL, turnin = AT_CLUBTOE, map = TRANGUL, turninMap = CLUBTOE,
    }
    D[95417] = {
        level = 40, requires = 36,
        objective = "Find missing ogres in the caves beneath Sunnyglade for Clubtoe.",
        pickup = AT_CLUBTOE, turnin = AT_BRUTE, map = CLUBTOE, turninMap = BRUTE,
        note = "The first of two quests called The Purple Ones. Clubtoe gives Sickening Lights at the same time.",
    }
    D[95601] = {
        level = 40, requires = 36,
        objective = "Kill 5 Empowered Brutes and 10 Twilight Ritualists then return to Clubtoe in Sunnyglade.",
        pickup = AT_BRUTE, turnin = AT_CLUBTOE, map = BRUTE, turninMap = CLUBTOE,
        note = "The second of two quests called The Purple Ones. Done alongside Sickening Lights; both are needed for Twilight No More!.",
    }
    D[95602] = {
        level = 40, requires = 36,
        objective = "Destroy 5 Twilight Ritual Circles found throughout the caves underneath Sunnyglade.",
        pickup = AT_CLUBTOE, turnin = AT_CLUBTOE, map = CLUBTOE, turninMap = CLUBTOE,
        note = "Done alongside The Purple Ones; both are needed for Twilight No More!.",
    }
    D[95427] = {
        level = 41, requires = 36,
        objective = "Kill Chogg'Zac in the Sunnyglade cave and collect their heads for Clubtoe.",
        pickup = AT_CLUBTOE, turnin = AT_CLUBTOE, map = CLUBTOE, turninMap = CLUBTOE,
        requiredItems = { {265750, "Chogg's Head", 1, "From Chogg'Zac in the Sunnyglade cave"}, {265751, "Zac's Head", 1, "From Chogg'Zac in the Sunnyglade cave"} },
        note = "Chogg'Zac is an elite.",
    }
    D[95418] = {
        level = 40, requires = 36,
        objective = "Deliver the head of Chogg to Tran'gul in Rog'mar.",
        pickup = AT_CLUBTOE, turnin = AT_TRANGUL, map = CLUBTOE, turninMap = TRANGUL,
    }
    D[95420] = {
        level = 40, requires = 36,
        objective = "Deliver Chogg's head to the ogre city to the north.",
        pickup = AT_TRANGUL, turnin = AT_CLUGFIST, map = TRANGUL, turninMap = CLUGFIST,
    }
    D[95424] = {
        level = 41, requires = 36,
        objective = "Kill 7 Twilight Maulers and 7 Twilight Firecallers for Clugfist in Bolder'ok.",
        pickup = AT_CLUGFIST, turnin = AT_CLUGFIST, map = CLUGFIST, turninMap = CLUGFIST,
        note = "Done alongside Unworthy Champion; both are needed for Clugfist's Decree.",
    }
    D[95425] = {
        level = 42, requires = 36,
        objective = "Collect Skullthumper from Klunk for Clugfist in Bolder'ok.",
        pickup = AT_CLUGFIST, turnin = AT_CLUGFIST, map = CLUGFIST, turninMap = CLUGFIST,
        note = "Done alongside Might Makes Right; both are needed for Clugfist's Decree. Skullthumper is reported to drop near 75, 27.",
    }
    D[94748].note = "Done alongside Carving a Path; both are needed for Bring Me His Head."
    D[94745].note = "Done alongside Break Their Chains; both are needed for Bring Me His Head."
    D[95431] = {
        level = 41, requires = 38,
        objective = "Look for the Bolder'ok ogre in the nearby cave.",
        pickup = AT_DAGROSH, turnin = AT_CRAGROG, map = DAGROSH, turninMap = CRAGROG,
        note = "Leads to Rise Up!. Not confirmed as needed for Bring Me His Head: a player reports it, the quest databases don't list it.",
    }
    D[95432].note = "Comes after Rumblings of Discontent. Not confirmed as needed for Bring Me His Head: a player reports it, the quest databases don't list it."
    D[95278].providedItem = {268705, "Blood and Battle", 1, "Given by Da'grosh when you accept the quest"}
    XP[93786] = 2800; XP[93787] = 2800; XP[94680] = 2450; XP[94727] = 320
    XP[95417] = 320; XP[95601] = 3150; XP[95602] = 3150; XP[95427] = 3300
    XP[95418] = 320; XP[95420] = 320; XP[95424] = 3300; XP[95425] = 3450; XP[95431] = 330
end
-- END kroldokchains2
-- END kroldokquests

-- BEGIN blackmawquests
-- A Lost Memento (92070) begins when a player uses their own
-- Feathered Charm Necklace, not from a shareable NPC quest.
FDJ.QUEST_SHAREABILITY_AUDIT[92070] = false
-- Blackmaw Hold: Beneath Nordrassil leads to Get to the Roots of It (a
-- Blackmaw Hold guide, Nov 2026, with Wowhead Forever quest IDs 92343-92346
-- and 92069). Where the NPCs stand: the reported coordinates.
do
    local NARA = { mapID = 1456, x = 0.756, y = 0.310, label = "Nara Wildmane — Elder Rise, Thunder Bluff", targetName = "Nara Wildmane" }
    local MATHRENGYL = { mapID = 1457, x = 0.354, y = 0.084, label = "Mathrengyl Bearwalker — Cenarion Enclave, Darnassus", targetName = "Mathrengyl Bearwalker" }
    local JEDIGA = { mapID = 1447, x = 0.225, y = 0.514, label = "Jediga — Valormok, Azshara", targetName = "Jediga" }
    local OGTINC = { mapID = 1447, x = 0.424, y = 0.427, label = "Ogtinc — Azshara", targetName = "Ogtinc" } -- 42.7 (blackmawaudit, 2.0.36)
    local TRUESONG = { mapID = 1447, x = 0.118, y = 0.783, label = "Commander Truesong — Azshara", targetName = "Commander Truesong" }
    FDJ.QUEST_START_MAPS[92343] = NARA
    FDJ.QUEST_START_MAPS[92344] = MATHRENGYL
    FDJ.QUEST_START_MAPS[92069] = OGTINC
    FDJ.QUEST_PREREQ_CHAINS[92343] = { { id = 92346, name = "Beneath Nordrassil" } }
    FDJ.QUEST_PREREQ_CHAINS[92344] = { { id = 92345, name = "Beneath Nordrassil" } }
    FDJ.QUEST_PREREQ_DETAILS[92346] = {
        level = 55, requires = 45,
        objective = "Speak with Nara Wildmane on Elder Rise in Thunder Bluff.",
        pickup = "Jediga, Valormok, Azshara (22.5, 51.4)",
        turnin = "Nara Wildmane, Elder Rise, Thunder Bluff",
        map = JEDIGA, turninMap = NARA,
    }
    FDJ.QUEST_PREREQ_DETAILS[92345] = {
        level = 55, requires = 45,
        objective = "Speak with Mathrengyl Bearwalker in the Cenarion Enclave in Darnassus.",
        pickup = "Commander Truesong, Azshara (11.8, 78.3)", -- blackmawaudit (2.0.36)
        turnin = "Mathrengyl Bearwalker, Cenarion Enclave, Darnassus",
        map = TRUESONG, turninMap = MATHRENGYL,
    }
    FDJ.FOREVER_QUEST_XP_FALLBACK[92345] = 560
    FDJ.FOREVER_QUEST_XP_FALLBACK[92346] = 560
    FDJ.FOREVER_QUEST_XP_FALLBACK[92343] = 11300
    FDJ.FOREVER_QUEST_XP_FALLBACK[92344] = 11300
    FDJ.FOREVER_QUEST_XP_FALLBACK[92069] = 12400
    FDJ.FOREVER_QUEST_XP_FALLBACK[97173] = 12800
    FDJ.FOREVER_QUEST_XP_FALLBACK[97198] = 16100
    for _, quest in ipairs((FDJ.DB["Blackmaw Hold"] and FDJ.DB["Blackmaw Hold"].quests) or {}) do
        if quest.id == 92343 then quest.turninMap = NARA end
        if quest.id == 92344 then quest.turninMap = MATHRENGYL end
        if quest.id == 92069 then quest.turninMap = OGTINC end
    end
end
-- END blackmawquests

-- BEGIN blackmawaudit
-- Blackmaw Hold Quest Update Audit (14 Nov 2026), checked against Icy Veins
-- Forever (quests and NPC spawns) and Questie-derived data (pd.zroot.it):
-- the two Blackmaw Magic givers, and the chain before Blackmaw Reclamation.
-- Gatekeeper Rageroar's spot (42.4, 20.2) is from players (the audit); no
-- database has his spawn yet. Unele (A Lost Memento): her spawn is Icy
-- Veins' (NPC 249855). M confirmed Unele and Archmage Timear as the
-- hand-ins, and Muln Earthfury in Mulgore only (2.0.37).
do
    local TIMEAR = { mapID = 1416, x = 0.154, y = 0.740, label = "Archmage Timear — Dalaran", targetName = "Archmage Timear" }
    local MULN = { mapID = 1412, x = 0.334, y = 0.225, label = "Muln Earthfury — Skywatcher Plateau, Mulgore", targetName = "Muln Earthfury" }
    local RAGEROAR = { mapID = 1447, x = 0.424, y = 0.202, label = "Gatekeeper Rageroar — Ursolan, Azshara", targetName = "Gatekeeper Rageroar" }
    local KORSA = { mapID = 1447, x = 0.630, y = 0.233, label = "Korsa — Legashi Stronghold, Azshara", targetName = "Korsa" }
    local UNELE = { mapID = 1447, x = 0.434, y = 0.174, label = "Unele — Ursolan, Azshara", targetName = "Unele" }
    local RAGEROAR_TEXT = "Gatekeeper Rageroar, Ursolan, Azshara (42.4, 20.2)"
    local GORN = "Gorn One Eye, Timbermaw Hold"
    -- Gorn One Eye in the Timbermaw Hold tunnel: Wowhead Forever's spawn of
    -- NPC 11555, Felwood 65.2, 2.6 (2.0.43; the turn-in ? goes there).
    local GORN_MAP = { mapID = 1448, x = 0.652, y = 0.026, label = "Gorn One Eye — Timbermaw Hold, Felwood", targetName = "Gorn One Eye" }
    FDJ.QUEST_START_MAPS[97173] = TIMEAR
    FDJ.QUEST_START_MAPS[97198] = MULN
    FDJ.QUEST_START_MAPS[92065] = RAGEROAR
    FDJ.QUEST_START_MAPS[92066] = { mapID = 1447, x = 0.414, y = 0.200, label = "Lorekeeper Nok — Ursolan, Azshara", targetName = "Lorekeeper Nok" } -- 2.0.39
    for _, quest in ipairs((FDJ.DB["Blackmaw Hold"] and FDJ.DB["Blackmaw Hold"].quests) or {}) do
        if quest.id == 97173 then quest.turninMap = TIMEAR end -- confirmed (2.0.37)
        if quest.id == 97198 then quest.turninMap = MULN end
        if quest.id == 92070 then quest.turninMap = UNELE end -- confirmed (2.0.37)
    end
    -- Blackmaw Reclamation comes after Blackmaw Counter-Offensive (Icy Veins
    -- and Wowhead Forever's quest series). Step 1 is any ONE of Master
    -- Feardred 86777, Thinning Their Forces 86792, Later, Satyr 86796 (the
    -- databases: "one of"; M, 2.0.42): "1. Pick one of the following
    -- quests:", the three below it (pickone).
    -- bmchain (2.1.1, Discord "Blackmaw Hold prequest incomplete", Theladron
    -- 20 Nov 2026, tested in game): the chain starts at Ekkal with The Legashi
    -- Threat, then Report to Rageroar and Missing Blackmaw Scouts (Korsa's
    -- quests can't be taken before it). Return to Rageroar needs Master
    -- Feardred AND Thinning Their Forces (confirmed), so the three are no longer
    -- "pick one"; Later, Satyr is kept as a step (he suspects all three; the
    -- escort alone doesn't open it). Quest IDs: Wowhead Forever's series.
    FDJ.QUEST_PREREQ_CHAINS[92065] = {
        { id = 86746, name = "The Legashi Threat" },
        { id = 86752, name = "Report to Rageroar" },
        { id = 86791, name = "Missing Blackmaw Scouts" },
        { id = 86777, name = "Master Feardred" },
        { id = 86792, name = "Thinning Their Forces" },
        { id = 86796, name = "Later, Satyr" },
        { id = 86797, name = "Return to Rageroar" },
        { id = 86798, name = "Timbermaw Reinforcements" },
        { id = 87346, name = "Chieftain Bloodmaw" },
        { id = 86814, name = "Blackmaw Counter-Offensive" },
    }
    FDJ.QUEST_PREREQ_DETAILS[86797] = {
        level = 53, requires = 47,
        objective = "Return to Gatekeeper Rageroar at Ursolan.",
        pickup = "Korsa, outside Legashi Stronghold, Azshara (63.0, 23.3)",
        turnin = RAGEROAR_TEXT,
        map = KORSA, turninMap = RAGEROAR,
    }
    -- Step 1's quests (2.0.37). Korsa starts and ends Master Feardred (Wowhead
    -- Forever); her spots and Graal's cage: Icy Veins' spawns of 236770, 237007.
    local KORSA_TEXT = "Korsa, outside Legashi Stronghold, Azshara (63.0, 23.3)"
    local GRAAL = { mapID = 1447, x = 0.659, y = 0.144, label = "Graal — Legashi Stronghold, Azshara", targetName = "Graal" }
    FDJ.QUEST_PREREQ_DETAILS[86777] = {
        level = 53, requires = 47,
        objective = "Kill Master Feardred, and bring his amulet to Korsa.",
        pickup = KORSA_TEXT, turnin = KORSA_TEXT,
        map = KORSA, turninMap = KORSA,
        requiredItems = { {235334, "Feardred's Amulet", 1, "From Master Feardred"} },
    }
    FDJ.QUEST_PREREQ_DETAILS[86792] = {
        level = 54, requires = 47,
        objective = "Kill 6 Legashi Hellraisers, 4 Legashi Soulstealers, and 2 Legashi Blackguards for Korsa outside Legashi Stronghold.",
        pickup = KORSA_TEXT, turnin = KORSA_TEXT,
        map = KORSA, turninMap = KORSA,
    }
    FDJ.QUEST_PREREQ_DETAILS[86796] = {
        level = 54, requires = 47,
        objective = "Help Graal break out of Legashi Stronghold, then inform Korsa outside Legashi Stronghold.",
        pickup = "Graal, caged in Legashi Stronghold, Azshara (65.9, 14.4)",
        turnin = KORSA_TEXT,
        map = GRAAL, turninMap = KORSA,
    }
    -- bmchain (2.1.1): no longer "any one of the three" (all are steps now).
    local EKKAL_TEXT = "Ekkal, Ruins of Eldarath, Azshara (42.0, 38.9)"
    local EKKAL_MAP = { mapID = 1447, x = 0.420, y = 0.389, label = "Ekkal — Ruins of Eldarath, Azshara", targetName = "Ekkal" }
    FDJ.QUEST_PREREQ_DETAILS[86746] = {
        level = 53, requires = 47,
        objective = "Kill 5 Legashi Satyrs, 5 Legashi Rogues and 5 Legashi Hellcallers for Ekkal at the Ruins of Eldarath.",
        pickup = EKKAL_TEXT, turnin = EKKAL_TEXT,
        map = EKKAL_MAP, turninMap = EKKAL_MAP,
    }
    FDJ.QUEST_PREREQ_DETAILS[86752] = {
        level = 53, requires = 47,
        objective = "Speak with Gatekeeper Rageroar at Ursolan.",
        pickup = EKKAL_TEXT, turnin = RAGEROAR_TEXT,
        map = EKKAL_MAP, turninMap = RAGEROAR,
        note = "Needs Neutral reputation with Timbermaw Hold.", -- Wowhead Forever comments
    }
    FDJ.QUEST_PREREQ_DETAILS[86791] = {
        level = 53, requires = 47,
        objective = "Find the Blackmaw scouting party near the Legashi camps east of Ursolan.",
        pickup = RAGEROAR_TEXT, turnin = KORSA_TEXT,
        map = RAGEROAR, turninMap = KORSA,
    }
    FDJ.QUEST_PREREQ_DETAILS[86798] = {
        level = 55, requires = 47,
        objective = "Speak to Gorn One Eye in Timbermaw Hold and ask him to provide reinforcements.",
        pickup = RAGEROAR_TEXT,
        turnin = GORN,
        map = RAGEROAR, turninMap = GORN_MAP,
    }
    FDJ.QUEST_PREREQ_DETAILS[87346] = {
        level = 55, requires = 47,
        objective = "Kill Chieftain Bloodmaw and bring his mace to Gorn One Eye in Timbermaw Hold.",
        pickup = GORN,
        turnin = GORN,
        map = GORN_MAP, turninMap = GORN_MAP,
        requiredItems = { {236631, "Bloodmaw's Basher", 1, "From Chieftain Bloodmaw"} },
        note = "Chieftain Bloodmaw is in Felwood, south of Timbermaw Hold.",
    }
    FDJ.QUEST_PREREQ_DETAILS[86814] = {
        level = 55, requires = 47,
        objective = "Plant the Timbermaw War Banner at the Legashi Stronghold in Azshara. Kill Prince Halanox, report your victory to Gatekeeper Rageroar at Ursolan.",
        pickup = GORN,
        turnin = RAGEROAR_TEXT,
        map = GORN_MAP, turninMap = RAGEROAR,
        providedItem = {235518, "Timbermaw War Banner", 1, "Given by Gorn One Eye when you accept the quest"},
        note = "Elite quest: bring a group for Prince Halanox.",
    }
    local XP = FDJ.FOREVER_QUEST_XP_FALLBACK
    XP[86797] = 525; XP[86798] = 550; XP[87346] = 5650; XP[86814] = 7050
    XP[86777] = 5250; XP[86792] = 5450; XP[86796] = 5450
    XP[86746] = 5250; XP[86752] = 530; XP[86791] = 530 -- bmchain (Wowhead Forever)
end
-- END blackmawaudit

-- BEGIN shapersquests
-- Shaper's Terrace: Crystalline Elements' giver, Mayena Earthseeker, in
-- Mulgore (Wowhead Forever's spawn of NPC 263445).
do
    local MAYENA = { mapID = 1412, x = 0.348, y = 0.222, label = "Mayena Earthseeker — Mulgore", targetName = "Mayena Earthseeker" }
    FDJ.QUEST_START_MAPS[95928] = MAYENA
    FDJ.FOREVER_QUEST_XP_FALLBACK[95928] = 17650
    FDJ.FOREVER_QUEST_XP_FALLBACK[95790] = 17650 -- Digestible Research
    -- 2.0.4: the other five (XP: ForeverChanges; sharing: ForeverChanges and
    -- the reported research).
    FDJ.FOREVER_QUEST_XP_FALLBACK[97049] = 17650
    FDJ.FOREVER_QUEST_XP_FALLBACK[95926] = 17650 -- 2.0.42: the game's own reward window (M, 13 Nov 2026); was 6,600 (ForeverChanges)
    FDJ.FOREVER_QUEST_XP_FALLBACK[95924] = 17650
    FDJ.FOREVER_QUEST_XP_FALLBACK[95925] = 17650
    FDJ.QUEST_SHAREABILITY_AUDIT[95928] = true  -- Crystalline Elements
    FDJ.QUEST_SHAREABILITY_AUDIT[97049] = true  -- Essence of Seeping Slimes
    FDJ.QUEST_SHAREABILITY_AUDIT[95926] = true  -- The Dark Crystal
    FDJ.QUEST_SHAREABILITY_AUDIT[95924] = true  -- Panic at the Digsite
    FDJ.QUEST_SHAREABILITY_AUDIT[95925] = false -- Mapping the Way Forward
    FDJ.QUEST_SHAREABILITY_AUDIT[95790] = false -- Digestible Research
end
-- END shapersquests

-- BEGIN leadinlinks
-- Lead-in quests that end inside the dungeon, at the NPC (or corpse) who
-- then gives the next quest, work like In Search of Thaelrid > Blackfathom
-- Villainy: both are journal entries of their own. The lead-in's Notes have
-- "Leads to: <next quest>"; the next quest starts inside the dungeon (In
-- Dungeon icon) and has a button to the lead-in under Starts at. No quest
-- chain for the pair (the lead-in has no earlier steps of its own).
do
    local PAIRS = {
        { dungeon = "Excavation Site: Wetlands", nextID = 95795, lead = { id = 95772 } }, -- Songblade Search > Fallen in the Fen (both already entries)
        { dungeon = "Excavation Site: Wetlands", nextID = 95809, lead = {
            id = 95647,
            name = "Lost in the Thicket Things",
            faction = "Alliance",
            level = 31,
            requires = 24,
            pickup = "Caitlin Grassman, Menethil Harbor, Wetlands",
            objective = "Find Ardin Grassman in the Excavation Sites. Learn what happened to Ardin Grassman.",
            turnin = "Ardin Grassman, inside Excavation Site: Wetlands",
            rewardSummary = "",
            rewardItems = {},
            liveXPFallback = 4900,
        } },
        { dungeon = "Ragefire Chasm", nextID = 5724, lead = {
            id = 5722,
            name = "Searching for the Lost Satchel",
            faction = "Horde",
            level = 16,
            requires = 9,
            pickup = "Rahauro, Elder Rise, Thunder Bluff",
            objective = "Find Maur Grimtotem's corpse inside Ragefire Chasm and search it for anything of interest.",
            turnin = "Maur Grimtotem's corpse, inside Ragefire Chasm",
            note = "From the first major three-way junction, take the right-hand tunnel, follow it uphill toward the dead end, then enter the small side room on the left. Interact with Maur's corpse there.",
            rewardSummary = "",
            rewardItems = {},
            liveXPFallback = 880,
        } },
        { dungeon = "Lower Blackrock Spire", nextID = 4982, lead = {
            id = 4981,
            name = "Operative Bijou",
            faction = "Horde",
            level = 59,
            requires = 55,
            pickup = "Lexlort, Kargath, Badlands",
            objective = "Travel to Blackrock Spire and find out what happened to Bijou.",
            turnin = "Bijou, inside Lower Blackrock Spire",
            rewardSummary = "",
            rewardItems = {},
        } },
        { dungeon = "Maraudon", nextID = 7046, lead = {
            id = 7044,
            name = "Legends of Maraudon",
            faction = "Both",
            level = 49,
            requires = 41,
            pickup = "Cavindra, Maraudon Orange Entrance, Desolace",
            objective = "Recover the two parts of the Scepter of Celebras: the Celebrian Rod and the Celebrian Diamond. Find a way to speak with Celebras.",
            turnin = "Celebras the Redeemed, inside Maraudon",
            rewardSummary = "",
            rewardItems = {},
        } },
    }

    for _, pair in ipairs(PAIRS) do
        local d = FDJ.DB and FDJ.DB[pair.dungeon]
        local quests = d and d.quests
        if quests then
            local nextIndex, nextQuest, leadQuest
            for i, q in ipairs(quests) do
                if q.id == pair.nextID then nextIndex, nextQuest = i, q end
                if q.id == pair.lead.id then leadQuest = q end
            end
            if nextQuest then
                -- The lead-in: its own entry, just before the quest it leads to.
                if not leadQuest then
                    leadQuest = pair.lead
                    local details = FDJ.QUEST_PREREQ_DETAILS and FDJ.QUEST_PREREQ_DETAILS[leadQuest.id]
                    leadQuest.startMap = leadQuest.startMap or (details and details.map)
                        or (FDJ.QUEST_START_MAPS and FDJ.QUEST_START_MAPS[leadQuest.id])
                    if FDJ.QUEST_START_MAPS and leadQuest.startMap and not FDJ.QUEST_START_MAPS[leadQuest.id] then
                        FDJ.QUEST_START_MAPS[leadQuest.id] = leadQuest.startMap
                    end
                    table.insert(quests, nextIndex, leadQuest)
                end
                leadQuest.hideFromMainList = nil
                leadQuest.leadsToQuestLink = { id = nextQuest.id, name = nextQuest.name }
                nextQuest.startQuestLink = { id = leadQuest.id, name = leadQuest.name }
                if FDJ.QUEST_PREREQ_CHAINS then FDJ.QUEST_PREREQ_CHAINS[nextQuest.id] = nil end
            end
        end
    end

    -- Notes that only repeated what the links now say.
    local function Q(dungeon, id)
        for _, q in ipairs((FDJ.DB and FDJ.DB[dungeon] and FDJ.DB[dungeon].quests) or {}) do
            if q.id == id then return q end
        end
    end
    local songblade = Q("Excavation Site: Wetlands", 95772)
    if songblade then songblade.note = nil end
    local heartwoven = Q("Excavation Site: Wetlands", 95809)
    if heartwoven and heartwoven.note == "Follow-up of Lost in the Thicket Things." then heartwoven.note = nil end

    -- Quest spots on the dungeon maps: these lead-ins now open their own page.
    for _, pins in pairs(FDJ.MAP_QUEST_PINS or {}) do
        for _, pin in ipairs(pins) do
            for _, spot in ipairs(pin.spots or {}) do
                for _, q in ipairs(spot.quests or {}) do
                    if q.id == 95647 or q.id == 5722 or q.id == 4981 or q.id == 7044 then q.main = nil end
                end
            end
        end
    end
end
-- END leadinlinks

-- BEGIN toxicsoilfinal
-- The Deadmines: the Toxic Soil storyline's journal entry is the dungeon step,
-- Destruction in Deadmines (92753, plant the explosives beside the forge
-- inside the Deadmines), with the nine quests before it as its chain (2.0.4:
-- the quest you do in the dungeon is the one listed; the second Destruction in
-- Deadmines, 92819, just "use the detonator" at the exit, is not shown).
-- Wowhead Forever: 92753 ends with Alba Fairmoon at the Deadmines exit ("I
-- will wait for you in the hills behind Moonbrook") and gives Stormwind +100.
do
    local ALBA_EXIT = "Alba Fairmoon, in the hills behind Moonbrook (at the Deadmines exit), Westfall"
    local d = FDJ.DB and FDJ.DB["The Deadmines"]
    for _, q in ipairs((d and d.quests) or {}) do
        if q.id == 92753 then
            q.turnin = ALBA_EXIT
            q.rewardSummary = "Stormwind +100"
            break
        end
    end
    local chains = FDJ.QUEST_PREREQ_CHAINS
    if chains and chains[92753] then
        local steps = {}
        for _, step in ipairs(chains[92753]) do
            if step.id ~= 92753 and step.id ~= 92819 then steps[#steps + 1] = step end
        end
        chains[92753] = steps
    end
    local details = FDJ.QUEST_PREREQ_DETAILS
    if details and details[92753] then
        details[92753].turnin = ALBA_EXIT
        details[92753].description = "Plant the explosives beside the forge, then meet Alba Fairmoon at the Deadmines exit."
    end
    -- 92819 is not a step any more: its old step data pointed at the Sentinel Hill inn.
    if details then details[92819] = nil end
    if FDJ.QUEST_START_MAPS then FDJ.QUEST_START_MAPS[92819] = nil end
    -- The translated hand-in still named the Sentinel Hill inn.
    for _, content in pairs(FDJ.ContentLocales or {}) do
        local quests = content.quests or {}
        if quests[92753] then quests[92753].turnin = nil end
    end
end
-- END toxicsoilfinal

-- BEGIN turninall
-- Turn-in places the ? buttons were missing (quest list, quest page, quest
-- tracker): the NPCs' spots on the world map. Wowhead Forever NPC pages
-- (Dawnwatcher Selgorm 4783, High Explorer Magellas 5387, Treshala
-- Fallowbrook 4521, Monika Sengutz 3982, Keeper Remulos 11832, Sanath Lim-yo
-- 8395, Greta Mosshoof 10922, Malyfous Darkhammer 10637, Franclorn Forgewright
-- 8888, Lothos Riftwaker 14387, Krom'rosh 256418, Ashe Amberhall 257591, Muln
-- Earthfury 259118); Demar Brant: Warcraft Wiki (Farholde Keep 66.6, 79.9).
-- Detonation at a Distance ends with Jasper Fel (SI:7), Wowhead quest 92750.
do
    local spots = FDJ.TURNIN_SPOTS or {}
    FDJ.TURNIN_SPOTS = spots
    local function Add(mapID, x, y, label, targetName)
        spots[#spots + 1] = { mapID = mapID, x = x, y = y, label = label, targetName = targetName }
    end
    Add(1457, 0.558, 0.242, "Dawnwatcher Selgorm — Darnassus", "Dawnwatcher Selgorm")
    Add(1455, 0.694, 0.186, "High Explorer Magellas — Hall of Explorers, Ironforge", "High Explorer Magellas")
    Add(1457, 0.693, 0.670, "Treshala Fallowbrook — Tradesmen's Terrace, Darnassus (walks around)", "Treshala Fallowbrook")
    Add(1424, 0.626, 0.190, "Monika Sengutz — Tarren Mill", "Monika Sengutz")
    Add(1450, 0.362, 0.416, "Keeper Remulos — Shrine of Remulos, Moonglade", "Keeper Remulos")
    Add(1447, 0.280, 0.500, "Sanath Lim-yo — Azshara", "Sanath Lim-yo")
    Add(1448, 0.512, 0.822, "Greta Mosshoof — Emerald Sanctuary, Felwood", "Greta Mosshoof")
    Add(1452, 0.610, 0.386, "Malyfous Darkhammer — Everlook, Winterspring", "Malyfous Darkhammer")
    Add(1428, 0.288, 0.284, "Franclorn Forgewright — Blackrock Mountain (a ghost, seen only while dead)", "Franclorn Forgewright")
    Add(1428, 0.264, 0.246, "Lothos Riftwaker — Blackrock Mountain", "Lothos Riftwaker")
    Add(2548, 0.594, 0.454, "Krom'rosh — Riverglades", "Krom'rosh")
    Add(2548, 0.666, 0.810, "Ashe Amberhall — Farholde Keep, Riverglades", "Ashe Amberhall")
    Add(2548, 0.666, 0.799, "Demar Brant — Farholde Keep, Riverglades", "Demar Brant")

    -- Quests whose turn-in NPC shares a name with another, or is not known
    -- yet: the place itself.
    local MULN = { mapID = 1412, x = 0.334, y = 0.224, label = "Muln Earthfury — Skywatcher Plateau, Mulgore", targetName = "Muln Earthfury" }
    local GROMGOL = { mapID = 1434, x = 0.323, y = 0.277, label = "Grom'gol Base Camp — Stranglethorn Vale (who takes it is not known yet)" }
    local FARHOLDE = { mapID = 2548, x = 0.666, y = 0.800, label = "Farholde Keep — Riverglades (who takes it is not known yet)" }
    -- The Grom'gol quests' hand-in, Commander Aggro'gosh, is known now (drownedcity).
    local AGGROGOSH = { mapID = 1434, x = 0.322, y = 0.288, label = "Commander Aggro'gosh — Grom'gol Base Camp", targetName = "Commander Aggro'gosh" }
    local byQuest = { [98823] = MULN, [95776] = AGGROGOSH, [95773] = AGGROGOSH, [94983] = FARHOLDE }
    for _, data in pairs(FDJ.DB or {}) do
        for _, quest in ipairs((type(data) == "table" and data.quests) or {}) do
            local spot = type(quest) == "table" and quest.id and byQuest[quest.id]
            if spot and not quest.turninMap then quest.turninMap = spot end
        end
    end
    local details = FDJ.QUEST_PREREQ_DETAILS or {}
    for id, spot in pairs(byQuest) do
        if details[id] and not details[id].turninMap then details[id].turninMap = spot end
    end
    if details[92750] then
        details[92750].turnin = "Jasper Fel, SI:7, Old Town, Stormwind"
    end
end
-- END turninall

-- BEGIN coldbringerhorde
-- The Coldbringer's Eye, Horde (quest 97196): level 41, from level 34,
-- shareable, 8,600 XP, 55s, Earthen Ring +300 and Thunder Bluff +150
-- (Wowhead Forever). Given and taken back by Sutara Plainstalker
-- <Quartermaster> of the Earthen Ring (NPC 264078), Skywatcher Plateau,
-- Mulgore 34.4, 22.8 (Wowhead Forever).
do
    local SUTARA = { mapID = 1412, x = 0.344, y = 0.228, label = "Sutara Plainstalker — Mulgore", targetName = "Sutara Plainstalker", detail = "Sutara Plainstalker of the Earthen Ring, north-west Mulgore" }
    local d = FDJ.DB and FDJ.DB["Razorfen Downs"]
    if d then
        d.quests = d.quests or {}
        local have, after = false, nil
        for i, q in ipairs(d.quests) do
            if q.id == 97196 then
                have = true
                q.pickup = "Sutara Plainstalker, Skywatcher Plateau, Mulgore"
                q.turnin = "Sutara Plainstalker, Skywatcher Plateau, Mulgore"
                q.startMap, q.turninMap, q.note = SUTARA, SUTARA, nil
            end
            if q.name == "The Coldbringer's Eye" and q.faction == "Alliance" then after = i end
        end
        if not have then
            table.insert(d.quests, (after or #d.quests) + 1, {
                id = 97196,
                name = "The Coldbringer's Eye",
                level = 41,
                requires = 34,
                faction = "Horde",
                pickup = "Sutara Plainstalker, Skywatcher Plateau, Mulgore",
                objective = "Recover The Coldbringer's Eye from Razorfen Downs.",
                turnin = "Sutara Plainstalker, Skywatcher Plateau, Mulgore",
                liveXPFallback = 8600,
                rewardSummary = "55s  •  Earthen Ring +300  •  Thunder Bluff +150",
                requiredItem = { 276916, "The Coldbringer's Eye", 1, 1, "From Amnennar the Coldbringer, the last boss of Razorfen Downs" },
                startMap = SUTARA,
                turninMap = SUTARA,
            })
        end
    end
    if FDJ.QUEST_SHAREABILITY_AUDIT then FDJ.QUEST_SHAREABILITY_AUDIT[97196] = true end
end
-- END coldbringerhorde

-- BEGIN onyxiaattunement
-- 2.0.3: the Onyxia attunement as a quest chain page of its own, opened from
-- the round Onyxia icon on the journal's home page, right of the Cozy
-- Sleeping Bag's (Systems/OnyxiaAttunement.lua). Its quests are Upper
-- Blackrock Spire's Drakefire Amulet (Alliance) and Blood of the Black
-- Dragon Champion (Horde), with their chains (Data/QuestChains.lua); each
-- character sees its own faction's. Every raider needs the Drakefire
-- Amulet in their bags to enter Onyxia's Lair.
-- Horde: Blood and Thunder (98325) is new in WoW Forever and comes before
-- Warlord's Command (M's attunement guide, 12 Nov 2026; Wowhead Forever
-- quest 98325). Chains and steps checked against Wowhead Forever's quest
-- pages (12 Nov 2026).
do
    local PAGE = "Onyxia Attunement"
    FDJ.ONYXIA_PAGE = PAGE
    FDJ.ONYXIA_QUESTS = { Alliance = 6502, Horde = 6602 }
    local C, D, XP = FDJ.QUEST_PREREQ_CHAINS, FDJ.QUEST_PREREQ_DETAILS, FDJ.FOREVER_QUEST_XP_FALLBACK
    local GORETOOTH = { mapID = 1418, x = 0.058, y = 0.474, label = "Warlord Goretooth — Kargath, Badlands", targetName = "Warlord Goretooth" }
    local AT_GORETOOTH = "Warlord Goretooth, Kargath, Badlands (5.8, 47.4)"

    D[98325] = {
        level = 60, requires = 55,
        objective = "Speak to Warlord Goretooth to serve the Kargath Expeditionary Force.",
        pickup = AT_GORETOOTH, turnin = AT_GORETOOTH,
        map = GORETOOTH, turninMap = GORETOOTH,
        note = "New in WoW Forever: it comes before Warlord's Command.",
    }
    XP[98325] = 660
    if FDJ.PREREQ_REWARD_MONEY_FALLBACK then FDJ.PREREQ_REWARD_MONEY_FALLBACK[98325] = 900 end
    -- bloodthunder (2.0.4): Warlord's Command's own page (Lower Blackrock
    -- Spire) shows Blood and Thunder as its pre-quest.
    if C[4903] == nil then C[4903] = { { id = 98325, name = "Blood and Thunder" } } end
    -- First step of every Horde chain that starts with Warlord's Command.
    for _, id in ipairs({ 4974, 6569, 6602 }) do
        local chain = C[id]
        if type(chain) == "table" and type(chain[1]) == "table" and chain[1].id == 4903 then
            table.insert(chain, 1, { id = 98325, name = "Blood and Thunder" })
        end
    end

    -- The page: copies of the two quests (their own note here; the UBRS
    -- page keeps its entries as they are).
    local quests = {}
    local ubrs = FDJ.DB and FDJ.DB["Upper Blackrock Spire"]
    for _, faction in ipairs({ "Alliance", "Horde" }) do
        for _, q in ipairs((ubrs and ubrs.quests) or {}) do
            if type(q) == "table" and q.id == FDJ.ONYXIA_QUESTS[faction] then
                local copy = {}
                for k, v in pairs(q) do copy[k] = v end
                copy.note = "Every raider needs the Drakefire Amulet in their bags to enter Onyxia's Lair; it doesn't need to be worn. The last step is in Upper Blackrock Spire: General Drakkisath's blood."
                quests[#quests + 1] = copy
            end
        end
    end
    FDJ.DB[PAGE] = {
        questChainPage = true, -- Quests is its only tab
        noArrow = true,        -- no waypoint arrow when tracked (the Sleeping Bag's chain only)
        level = "48+",         -- the character's faction: Systems/OnyxiaAttunement.lua
        location = "",
        description = "",
        bosses = {},
        quests = quests,
    }
end
-- END onyxiaattunement



-- BEGIN knightofmourning
-- knightofmourning (2.0.10, M 17 Nov 2026): the Forsaken paladin chain into
-- Blackmaw Hold (Wowhead Forever, quests 93030 and 99187): The Knight of
-- Mourning (listen to his tale), then The Reliquary of Tyr (the journal
-- entry), which awards the Sword of Mourning. The Reliquary of Tyr drops
-- from Elder Shaman Bloodmane (Wowhead Forever item 286415). The Knight of
-- Mourning stands in Tirisfal Glades (17.6, 67.4); players pick up both
-- quests from him.
do
    local D, C, XP = FDJ.QUEST_PREREQ_DETAILS, FDJ.QUEST_PREREQ_CHAINS, FDJ.FOREVER_QUEST_XP_FALLBACK
    local bh = FDJ.DB and FDJ.DB["Blackmaw Hold"]
    local KNIGHT = "Knight of Mourning, Tirisfal Glades (17.6, 67.4)"
    local KNIGHT_MAP = { mapID = 1420, x = 0.176, y = 0.674, label = "Knight of Mourning — Tirisfal Glades", targetName = "Knight of Mourning" }
    C[99187] = {
        { id = 93030, name = "The Knight of Mourning" },
    }
    D[93030] = {
        level = 58, requires = 50,
        objective = "Speak with the Knight of Mourning to learn more about his unfinished quest.",
        pickup = KNIGHT,
        turnin = KNIGHT,
        map = KNIGHT_MAP,
    }
    XP[93030] = 620
    XP[99187] = 13550
    if bh then
        bh.quests = bh.quests or {}
        local have = false
        for _, q in ipairs(bh.quests) do if q.id == 99187 then have = true end end
        if not have then
            table.insert(bh.quests, {
                id = 99187, name = "The Reliquary of Tyr",
                classOnly = "PALADIN", faction = "Horde",
                level = 58, requires = 50,
                pickup = KNIGHT, turnin = KNIGHT,
                startMap = KNIGHT_MAP, turninMap = KNIGHT_MAP,
                objective = "Travel to Blackmaw Hold in Kalimdor, and recover the Reliquary of Tyr.",
                liveXPFallback = 13550,
                rewardSummary = "",
                rewardItems = { {286408, "Sword of Mourning", 3} },
                requiredItem = { 286415, "Reliquary of Tyr", 4, 1, "Dropped by: Elder Shaman Bloodmane, Blackmaw Hold" },
                note = "Forsaken paladin class quest. The Reliquary of Tyr drops from Elder Shaman Bloodmane.",
            })
        end
    end
end
-- END knightofmourning

-- BEGIN tasteofflame
-- tasteofflame (2.0.10, M 17 Nov 2026: "This quest is actually a chain, and
-- we do not show the start"; then: "It starts from Squire, then you get Set
-- Them Ablaze, and then you unlock Trinkets, which gives you as a reward the
-- molt, which then you can bring to the guy"): A Taste of Flame in Blackrock
-- Depths (4024) after Squire Maltrake (3462), Set Them Ablaze! (3463),
-- Trinkets... (3481: the Hoard of the Black Dragonflight, with the Black
-- Dragonflight Molt inside) and A Taste of Flame (4022: show the molt to
-- Cyrus Therepentous). Levels, givers, spots, XP, money and rewards: Wowhead
-- Forever (quests 3462, 3463, 3481, 4022; Velarok Windblade, Squire
-- Maltrake and the hoard at 39, 39 in Searing Gorge; Cyrus at 94.8, 31.6 in
-- Burning Steppes). Cyrus's other A Taste of Flame (4023, elite: the drake
-- he summons drops a molt) also opens 4024: it counts for step 4.
do
    local VELAROK = { mapID = 1427, x = 0.390, y = 0.390, label = "Velarok Windblade — Searing Gorge", targetName = "Velarok Windblade" }
    local MALTRAKE = { mapID = 1427, x = 0.390, y = 0.390, label = "Squire Maltrake — Searing Gorge", targetName = "Squire Maltrake" }
    local HOARD = { mapID = 1427, x = 0.390, y = 0.389, label = "Hoard of the Black Dragonflight — Searing Gorge" }
    local CYRUS = { mapID = 1428, x = 0.948, y = 0.316, label = "Cyrus Therepentous — Burning Steppes", targetName = "Cyrus Therepentous" }
    local VELAROK_TEXT = "Velarok Windblade, Searing Gorge (39.0, 39.0)"
    local MALTRAKE_TEXT = "Squire Maltrake, Searing Gorge (39.0, 39.0)"
    local HOARD_TEXT = "Hoard of the Black Dragonflight, Searing Gorge (39.0, 38.9)"
    local CYRUS_TEXT = "Cyrus Therepentous, Burning Steppes (94.8, 31.6)"
    FDJ.QUEST_PREREQ_CHAINS[4024] = {
        { id = 3462, name = "Squire Maltrake" },
        { id = 3463, name = "Set Them Ablaze!" },
        { id = 3481, name = "Trinkets..." },
        { id = 4022, name = "A Taste of Flame" },
    }
    FDJ.QUEST_PREREQ_DETAILS[3462] = {
        level = 50, requires = 40,
        objective = "Speak with Squire Maltrake.",
        pickup = VELAROK_TEXT, turnin = MALTRAKE_TEXT,
        map = VELAROK, turninMap = MALTRAKE,
    }
    FDJ.QUEST_PREREQ_DETAILS[3463] = {
        level = 52, requires = 40,
        objective = "Set the North, South, East, and West Sentry Towers on fire by using the Torch of Retribution inside each of the buildings.",
        pickup = MALTRAKE_TEXT, turnin = MALTRAKE_TEXT,
        map = MALTRAKE, turninMap = MALTRAKE,
        providedItem = {10515, "Torch of Retribution", 1, "Given by Squire Maltrake when you accept the quest: use it on the Sentry Brazier inside each tower"},
        note = "Elite quest.",
    }
    FDJ.QUEST_PREREQ_DETAILS[3481] = {
        level = 50, requires = 40,
        objective = "Open the chest.",
        pickup = HOARD_TEXT, turnin = HOARD_TEXT,
        startObject = {"Hoard of the Black Dragonflight", "Interface\\Icons\\INV_Box_02", "Beside Squire Maltrake, Searing Gorge (39.0, 38.9)"},
        map = HOARD, turninMap = HOARD,
    }
    FDJ.QUEST_PREREQ_DETAILS[4022] = {
        level = 54, requires = 52,
        objective = "Show Cyrus Therepentous the Black Dragonflight Molt you received from Velarok Windblade.",
        pickup = CYRUS_TEXT, turnin = CYRUS_TEXT,
        map = CYRUS, turninMap = CYRUS,
        requiredItems = { {10575, "Black Dragonflight Molt", 1, "Inside the Hoard of the Black Dragonflight (Trinkets...)"} },
        note = "No molt? Cyrus has another A Taste of Flame (elite): after accepting it, ask him how to prove your worth and kill the Frenzied Black Drake he summons for its molt. It opens the Blackrock Depths quest too.",
    }
    -- rewards and money (Wowhead Forever)
    FDJ.PREREQ_REWARD_ITEMS_FALLBACK[3463] = { items = { {10742, "Dragonflight Leggings", 2}, {10743, "Drakefire Headguard", 2}, {10744, "Axe of the Ebon Drake", 2}, {270114, "Dragonscale Pants", 2} }, choice = true }
    FDJ.PREREQ_REWARD_MONEY_FALLBACK[3463] = 23000
    FDJ.PREREQ_REWARD_ITEMS_FALLBACK[3481] = { items = { {10569, "Hoard of the Black Dragonflight", 1} }, choice = false }
    FDJ.QUEST_DONE_BY = FDJ.QUEST_DONE_BY or {}
    FDJ.QUEST_DONE_BY[4022] = { 4023 }
    local XP = FDJ.FOREVER_QUEST_XP_FALLBACK
    XP[3462] = 470; XP[3463] = 7600; XP[3481] = 470; XP[4022] = 5450
end
-- END tasteofflame

-- BEGIN onyxiaxp
-- onyxiaxp (2.0.10, M 17 Nov 2026, with his Onyxia Attunement XP audit):
-- every quest of both attunement chains with its WoW Forever XP. Wowhead
-- Forever gives each quest a base XP and Forever's multiplier; the game
-- grants base x multiplier rounded to 50 (checked against the game's own
-- reward window: Wild Ancients 6,600 x 2.675 = 17,650). 23 of the 31 steps
-- had no XP of their own, and the two finals showed the bare base (8,300 /
-- 9,950). The same quest IDs on the Blackrock Spire pages get it too.
do
    local XP = FDJ.FOREVER_QUEST_XP_FALLBACK
    -- Alliance: Dragonkin Menace ... Drakefire Amulet
    XP[4182] = 5450; XP[4183] = 4100; XP[4184] = 4100; XP[4185] = 540
    XP[4186] = 5450; XP[4223] = 540; XP[4224] = 540
    XP[4241] = 11450 -- 5,450 x 2.1
    XP[4242] = 9800 -- 5,450 x 1.8
    XP[4264] = 11150; XP[4282] = 11150 -- 6,200 x 1.8
    XP[4322] = 13950 -- 7,750 x 1.8
    XP[6402] = 660; XP[6403] = 9950; XP[99435] = 9950 -- (99435: Forever's other The Great Masquerade)
    XP[6501] = 6600
    XP[6502] = 22200 -- 8,300 x 2.675
    -- Horde: Blood and Thunder ... Blood of the Black Dragon Champion
    XP[98325] = 660
    XP[4903] = 15350 -- 8,300 x 1.85
    XP[4941] = 6600
    XP[4974] = 26600 -- 9,950 x 2.675
    XP[6566] = 660; XP[6567] = 3300; XP[6568] = 4950; XP[6569] = 6600; XP[6570] = 4950
    XP[6582] = 6600; XP[6583] = 6600; XP[6584] = 6600; XP[6585] = 6600
    XP[6601] = 4950
    XP[6602] = 26600 -- 9,950 x 2.675
end
-- END onyxiaxp

-- BEGIN rfkhorde
-- rfkhorde (2.0.10): Show on Map spots for two Horde Razorfen Kraul quests
-- (Wowhead Forever): An Unholy Alliance is handed in to Varimathras
-- (Undercity 56.2, 92.6); Trial at the Field of Giants is done at the
-- silithid mounds south of Camp Taurajo (44.5, 70.5).
do
    local rfk = FDJ.DB and FDJ.DB["Razorfen Kraul"]
    for _, quest in ipairs((rfk and rfk.quests) or {}) do
        if quest.id == 6522 then
            quest.turninMap = { mapID = 1458, x = 0.562, y = 0.926, label = "Varimathras — Royal Quarter, Undercity", targetName = "Varimathras" }
        end
    end
    local D = FDJ.QUEST_PREREQ_DETAILS
    if type(D[1824]) == "table" then
        D[1824].objectiveMap = { markerType = "location", mapID = 1413, x = 0.445, y = 0.705, label = "Field of Giants — The Barrens", detail = "Silithid Creepers, Swarmers and Grubs at the mounds south of Camp Taurajo drop Twitching Antennae" }
    end
end
-- END rfkhorde

-- BEGIN shamanvoodoo
-- 2.0.11 (M 18 Nov 2026: "add this shaman sunken temple quest for alliance
-- shamans ... alliance starts with Mastering the Elements, then goes on to
-- the other 2 quests"). Da Voodoo (8413) is for both factions (Wowhead
-- Forever: Side Both). Its chain's first step is the faction's own:
-- Mastering the Elements (8411, Bath'rah the Windwatcher) for the Alliance,
-- Elemental Mastery (8410, Beram Skychaser) for the Horde; then Spirit
-- Totem (8412). Both first steps list the four elementals they need
-- (Wowhead Forever quests 8410 / 8411, forever-tool 8411: 3,800 XP).
do
    local D, C, XP = FDJ.QUEST_PREREQ_DETAILS, FDJ.QUEST_PREREQ_CHAINS, FDJ.FOREVER_QUEST_XP_FALLBACK
    local AIR, EARTH, FIRE, WATER = { 7069, "Elemental Air", 1 }, { 7067, "Elemental Earth", 1 },
        { 7068, "Elemental Fire", 1 }, { 7070, "Elemental Water", 1 }
    local BATHRAH = { mapID = 1416, x = 0.804, y = 0.668, label = "Bath'rah the Windwatcher — Alterac Mountains", targetName = "Bath'rah the Windwatcher" }
    if D[8410] then
        D[8410].requiredItems = { AIR, FIRE, EARTH, WATER }
        D[8410].showRequiredIcons = true
    end
    D[8411] = {
        level = 52, requires = 50,
        objective = "Bring the elements earth, air, fire and water to Bath'rah the Windwatcher.",
        pickup = "Bath'rah the Windwatcher, Alterac Mountains",
        turnin = "Bath'rah the Windwatcher, Alterac Mountains",
        map = BATHRAH, turninMap = BATHRAH,
        requiredItems = { AIR, EARTH, FIRE, WATER },
        showRequiredIcons = true,
    }
    XP[8411] = 3800
    for _, q in ipairs((FDJ.DB and FDJ.DB["Sunken Temple"] and FDJ.DB["Sunken Temple"].quests) or {}) do
        if q.id == 8413 then q.faction = "Both" end
    end
    local FIRST = { id = 8410, name = "Elemental Mastery" }
    C[8413] = { FIRST, { id = 8412, name = "Spirit Totem" } }
    -- voodooview (M 18 Nov 2026, on the Alliance tab of a Horde character:
    -- "the first step of the alliance shows a pick up in thunder bluff"):
    -- the first step follows the faction tab being looked at
    -- (FDJ.ApplyViewFaction, called by the quest pages); with no tab told,
    -- the character's own faction.
    local function Apply(view)
        local faction = view
        if faction ~= "Alliance" and faction ~= "Horde" then
            if type(UnitFactionGroup) ~= "function" then return end
            local ok, own = pcall(UnitFactionGroup, "player")
            if not ok or (type(issecretvalue) == "function" and issecretvalue(own)) then return end
            faction = own
        end
        if faction == "Alliance" then
            FIRST.id, FIRST.name = 8411, "Mastering the Elements"
        elseif faction == "Horde" then
            FIRST.id, FIRST.name = 8410, "Elemental Mastery"
        end
    end
    Apply()
    if CreateFrame then
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_LOGIN")
        f:SetScript("OnEvent", function() Apply() end)
    end
    function FDJ.ApplyViewFaction(faction) Apply(faction) end
    -- The game's own names and objectives where forever-tool has them
    -- (official Battle.net data); the rest stay English.
    local LOC = {
        deDE = { name = "Die Beherrschung der Elemente", objective = "Bringt Bath'rah dem Windbehüter die Elemente Erde, Luft, Feuer und Wasser." },
        frFR = { name = "Maîtriser les éléments" },
        esES = { name = "Dominar los elementos" },
        ptBR = { name = "Dominando os elementos" },
        ruRU = { name = "Покорение Стихий" },
        koKR = { name = "원소에 대한 깨달음", objective = "바람의감시자 바스라에게 바람, 불, 대지, 물의 원소를 가져가야 합니다." },
        zhTW = { name = "控制元素", objective = "將土元素、風元素、火元素和水元素交給『觀風者』巴斯拉。" },
    }
    for lang, fields in pairs(LOC) do
        local c = FDJ.ContentLocales and FDJ.ContentLocales[lang]
        if c then
            c.quests = c.quests or {}
            c.quests[8411] = c.quests[8411] or {}
            for field, text in pairs(fields) do c.quests[8411][field] = text end
        end
    end
end
-- END shamanvoodoo

-- xpaudit (2.0.12, M 18 Nov 2026: the RFC to Maraudon quest audit, "XP for
-- 67 quests (two sources agree)"): the offline XP (used only until the game
-- has the quest's own reward loaded; the live value always wins) for the
-- quests where forever-tool.com (Battle.net data) and ForeverChanges agree,
-- or where Wowhead Forever's quest page settles it. Left as they were: the
-- six with only one source (97288, 92415, 92753, 1113, 1050, 1049). The
-- quest's own liveXPFallback and the XP in its rewards text change with it.
-- The Wrath of Rath'mael (92422) had 0 XP before; both sources give 4,600.
do
    local XP = {
        [166] = 6200, [214] = 2950, [373] = 2050, [377] = 4400, [386] = 4200, [387] = 5550,
        [388] = 5550, [391] = 4950, [707] = 700, [914] = 4300, [959] = 2650, [962] = 3300,
        [971] = 6550, [1013] = 5600, [1014] = 8850, [1048] = 12250, [1053] = 15300, [1098] = 5350,
        [1101] = 7950, [1102] = 8500, [1109] = 6950, [1142] = 7250, [1144] = 7250, [1198] = 5700,
        [1199] = 6050, [1200] = 7850, [1486] = 3100, [1487] = 4000, [1491] = 2650, [1740] = 5100,
        [1806] = 3850, [2040] = 3700, [2769] = 410, [2841] = 8200, [2904] = 5800, [2922] = 4750,
        [2924] = 5500, [2926] = 3950, [2928] = 4400, [2929] = 6200, [2930] = 6550, [2962] = 4400,
        [5722] = 1800, [5723] = 2150, [5724] = 2950, [5725] = 2950, [5728] = 2350, [5761] = 2350,
        [6561] = 7850, [6562] = 440, [6981] = 5150, [92401] = 4600, [92421] = 4600, [92422] = 4600,
        [92456] = 9400, [92489] = 9400, [95189] = 6200, [95195] = 6200, [95204] = 5450, [95216] = 5450,
        [95250] = 3900, [95795] = 6150, [96986] = 9400, [96987] = 9400, [96988] = 9400, [98823] = 6950,
        [98824] = 6150,
    }
    local fallback = FDJ.FOREVER_QUEST_XP_FALLBACK
    local function Grouped(n)
        local s = tostring(n)
        while true do
            local done
            s, done = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
            if done == 0 then return s end
        end
    end
    if fallback then
        for id, xp in pairs(XP) do fallback[id] = xp end
    end
    for _, dungeon in pairs(FDJ.DB or {}) do
        for _, quest in ipairs(dungeon.quests or {}) do
            local xp = quest.id and XP[quest.id]
            if xp then
                quest.liveXPFallback = xp
                if type(quest.rewards) == "string" then
                    quest.rewards = quest.rewards:gsub("%d[%d,]* XP", Grouped(xp) .. " XP")
                end
            end
        end
    end
end

-- BEGIN audit212
-- audit212 (2.0.12, M 18 Nov 2026: "I have a new quest report. We gotta make
-- sure we get everything fixed"): the 2.0.12 quest rewards, XP and missing
-- quests audit.
-- XP: the offline XP (used only until the game has the quest's own reward
-- loaded; the live value always wins) for 83 quests. Each value is
-- Wowhead Forever's own data (the quest's base XP times Forever's dungeon
-- quest multiplier, from the Forever client) and Icy Veins agrees on every
-- one; the old values were the base XP without the multiplier. Mayara
-- Brightwing and Vivian Lagrave (4766, 4769) had 0 and get Wowhead's 660;
-- Starfall (5250) keeps 580 (Wowhead's own number).
-- New quest: Ever After (82062, the Blackrock Depths secret ledge). Wowhead
-- Forever (quest 82062; items 221315, 221316, 216619). State Secrets (96376 /
-- 96377 / 96379) taken out again (M 18 Nov 2026: "please remove state secret
-- ... It's a double"), and The Broken Glaive (98830, M: "It's not in the game
-- yet ... just data mined"). Left out: The Heart of the Void
-- (78916 / 78917: Wowhead Forever lists it at level 25 with 0 XP, a Season
-- of Discovery leftover), The Challenge (left off on purpose, as before).
do
    local D, C, XP = FDJ.QUEST_PREREQ_DETAILS, FDJ.QUEST_PREREQ_CHAINS, FDJ.FOREVER_QUEST_XP_FALLBACK
    local function Add(dungeonName, quest, afterID)
        local db = FDJ.DB and FDJ.DB[dungeonName]
        if not db then return end
        db.quests = db.quests or {}
        local at
        for i, q in ipairs(db.quests) do
            if q.id == quest.id then return end
            if afterID and q.id == afterID then at = i end
        end
        if XP and quest.liveXPFallback then XP[quest.id] = quest.liveXPFallback end
        table.insert(db.quests, (at or #db.quests) + 1, quest)
    end
    local function Pin(dungeonName, spotName, entry)
        local pins = FDJ.MAP_QUEST_PINS and FDJ.MAP_QUEST_PINS[dungeonName]
        if not pins then return end
        for _, floor in ipairs(pins) do
            for _, spot in ipairs(floor.spots or {}) do
                if spot.name == spotName then
                    spot.quests = spot.quests or {}
                    for _, q in ipairs(spot.quests) do if q.id == entry.id then return end end
                    table.insert(spot.quests, entry)
                    return
                end
            end
        end
    end
    local share = FDJ.QUEST_SHAREABILITY_AUDIT

    -- Ever After: the Rugged Traveler on the hidden ledge. Level 56,
    -- requires 48, not shareable; 8,400 XP and 85s; the door on the ledge
    -- (fixed by the 17 Nov hotfix) takes you to a ledge above Lord
    -- Incendius, with no way back.
    Add("Blackrock Depths", {
        id = 82062, name = "Ever After",
        faction = "Both", level = 56, requires = 48, startsInDungeon = true,
        pickup = "Rugged Traveler, on a hidden ledge above the lava, Blackrock Depths",
        objective = "Speak with the Rugged Traveler.",
        turnin = "Rugged Traveler, Blackrock Depths",
        liveXPFallback = 8400,
        rewardSummary = "85s  •  +300 with your faction's capitals",
        rewardItems = {
            { 221316, "Premo's Poise-Demanding Uniform", 1 },
            { 216619, "Student Fodder", 2, 3 },
            { 221315, "Traveler's Symbols", 3 },
        },
        note = "Take the bridge just east of the Ring of Law that runs north over the lava and clear it. On its left side, by the small brazier, jump from the railing onto the platform against the wall, follow it to the corner and keep your left shoulder on the wall until you drop onto the rock ledge below: the Rugged Traveler is there. The door on the ledge takes you to a ledge above Lord Incendius; there is no way back. Not shareable.",
    })
    if share then share[82062] = false end

    -- The XP.
    local NEW = {
        [1049] = 8450, [1050] = 8900, [1113] = 7850, [4701] = 12500, [4724] = 11850,
        [4729] = 12500, [4742] = 16200, [4764] = 4400, [4766] = 660, [4768] = 22200,
        [4769] = 660, [4771] = 23650, [4788] = 15100, [4862] = 12500, [4866] = 18900,
        [4867] = 18900, [4981] = 11850, [4982] = 11850, [5001] = 12500, [5047] = 17650,
        [5081] = 16200, [5089] = 12850, [5102] = 26600, [5125] = 21900, [5127] = 16600,
        [5160] = 17650, [5212] = 14500, [5214] = 17450, [5243] = 14500, [5251] = 17450,
        [5262] = 17450, [5263] = 18250, [5282] = 17450, [5341] = 15700, [5343] = 15700,
        [5382] = 15700, [5384] = 19700, [5463] = 14500, [5466] = 23650, [5515] = 15700,
        [5518] = 17650, [5525] = 17650, [5526] = 22200, [5529] = 14750, [5848] = 13850,
        [6163] = 9900, [7441] = 20750, [7461] = 23650, [7463] = 13200, [7481] = 19700,
        [7482] = 19700, [7483] = 3300, [7484] = 3300, [7485] = 3300, [7488] = 20200,
        [7489] = 20200, [7492] = 1500, [7494] = 1500, [7498] = 15700, [7499] = 15700,
        [7500] = 15700, [7501] = 15700, [7502] = 15700, [7503] = 15700, [7504] = 15700,
        [7505] = 15700, [7506] = 15700, [7507] = 19900, [7604] = 6600, [7629] = 13200,
        [7631] = 13200, [7647] = 19900, [7668] = 19900, [7703] = 22200, [8945] = 16600,
        [92415] = 6200, [92753] = 2700, [96393] = 3200, [96394] = 2300, [96395] = 2300,
        [96403] = 2950, [97288] = 3450, [98423] = 2550,
    }
    local function Grouped(n)
        local s = tostring(n)
        while true do
            local done
            s, done = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
            if done == 0 then return s end
        end
    end
    if XP then
        for id, xp in pairs(NEW) do XP[id] = xp end
    end
    for _, dungeon in pairs(FDJ.DB or {}) do
        for _, quest in ipairs(dungeon.quests or {}) do
            local xp = quest.id and NEW[quest.id]
            if xp then
                quest.liveXPFallback = xp
                if type(quest.rewards) == "string" then
                    quest.rewards = quest.rewards:gsub("%d[%d,]* XP", Grouped(xp) .. " XP")
                end
            end
        end
    end
end
-- END audit212

-- BEGIN vorrellake
-- vorrellake (2.0.12, M 18 Nov 2026): Vorrel's Revenge's note (the warning
-- above the objective, Data/Dungeons.lua) in the other languages.
do
    local WARN = {
        deDE = "Diese Quest wird außerhalb des Dungeons abgeschlossen, im See unterhalb von Unterstadt.",
        frFR = "Cette quête se termine hors du donjon, dans le lac sous Fossoyeuse.",
        esES = "Esta misión se completa fuera de la mazmorra, en el lago bajo Entrañas.",
        esMX = "Esta misión se completa fuera del calabozo, en el lago bajo Entrañas.",
        itIT = "Questa missione si completa fuori dal dungeon, nel lago sotto Sepulcra.",
        ptBR = "Esta missão é concluída fora da masmorra, no lago abaixo de Cidade Baixa.",
        ruRU = "Это задание выполняется за пределами подземелья, в озере под Подгородом.",
        koKR = "이 퀘스트는 던전 밖, 언더시티 아래의 호수에서 완료합니다.",
        zhCN = "此任务在地下城外完成，位于幽暗城下方的湖中。",
        zhTW = "此任務在地城外完成，位於幽暗城下方的湖中。",
    }
    FDJ.ContentLocales = FDJ.ContentLocales or {}
    for lang, text in pairs(WARN) do
        local c = FDJ.ContentLocales[lang]
        if not c and lang ~= "esMX" then
            c = {}
            FDJ.ContentLocales[lang] = c
        end
        if c then
            c.quests = c.quests or {}
            c.quests[1051] = c.quests[1051] or {}
            c.quests[1051].warning = text
        end
    end
end
-- END vorrellake

-- BEGIN dorncave
-- dorncave (2.0.13, M 19 Nov 2026, Test of Faith: the arrow took him up
-- onto the mesa over Windbreak Canyon, "a place that I've never seen
-- before. And the cave is literally down there ... there is another path
-- that goes up the cave"): Dorn Plainstalker stands in the cave on the
-- canyon's north wall (the client's spawn, z -7); its way in is the
-- path up from the canyon floor at 54.7, 45.1. The walking net reached him
-- from the mesa above. The points: a walking router on the
-- Forever client's maps, run offline to his spawn from the canyon floor
-- (135 yards from 54.6, 45.3), from Freewind Post's side (the canyon west
-- of the cave) and from the east. keep: the last points still lead within
-- 60 yards of him (the cave mouth is that close).
do
    FDJ.ARROW_VIAS = FDJ.ARROW_VIAS or {}
    local function P(x, y, label, keep) return { mapID = 1441, x = x, y = y, label = label, keep = keep or nil } end
    local CAVE = {
        P(0.5469, 0.4510, "The path up to the cave"),
        P(0.5460, 0.4430, "Up the path to the cave"),
        P(0.5365, 0.4283, "Into the cave", true),
        P(0.5374, 0.4197, "Into the cave", true),
    }
    local function Join(head, tail)
        local list = {}
        for _, point in ipairs(head) do list[#list + 1] = point end
        for _, point in ipairs(tail) do list[#list + 1] = point end
        return list
    end
    FDJ.ARROW_VIAS[string.format("%s|%.4f|%.4f", "1441", 0.538, 0.414)] = { routes = {
        CAVE, -- from the canyon east of the cave, or right below it
        Join({ -- from Freewind Post's side: along the canyon west of the cave
            P(0.5137, 0.4964, "Along the canyon, east to the cave"),
            P(0.5213, 0.4822, "Along the canyon, east to the cave"),
            P(0.5308, 0.4766, "Along the canyon, east to the cave"),
        }, CAVE),
    } }
end
-- END dorncave

-- BEGIN plankjump
-- plankjump (2.0.13, M 19 Nov 2026 at 26.4, 31.7, Test of Faith just
-- taken - Dorn sends you up onto the mesa there - and the arrow at its
-- hand-in: "I have to do the objective first ... It should point at this
-- little wooden trampoline and tell the user jump down, and then the quest
-- is going to be complete"): while it is in the log and not done, the
-- arrow leads to the planks (a few yards north of where he stood) and says
-- to jump off them.
-- (M 19 Nov 2026 at 26.4, 31.4 by the rune circle, the arrow there with no
-- pointer: "have the arrow point at the planks ... if they jump at the
-- wrong spot, they die": the spot is out past the planks' end, straight
-- north of the circle - the planks are dead ahead of it, facing north - so
-- from the mesa the arrow points along them; exact: a place, not an area,
-- so it keeps pointing there.)
do
    local d = FDJ.QUEST_PREREQ_DETAILS and FDJ.QUEST_PREREQ_DETAILS[1149]
    if d then
        -- (planksouth, M 19 Nov 2026 at 26.4, 31.4 facing the planks, the arrow
        -- pointing behind him: the planks are south of the circle, not north)
        d.objectiveMap = { mapID = 1441, x = 0.264, y = 0.324, label = "The planks — Test of Faith",
            markerType = "location", hintKey = "ARROW_JUMP_PLANKS", exact = true }
    end
end
-- END plankjump

-- BEGIN eyeclick
-- eyeclick (2.0.13, M 19 Nov 2026, The Coldbringer's Eye: "you have to click
-- on the eye after killing the last boss ... it's not a loot from the boss
-- itself ... some people might forget about it", and a disclaimer under the
-- objective): both factions' quests (96773 Alliance, 97196 Horde).
do
    -- (M 20 Nov 2026: "say doesn't drop the Eye from its body")
    local NOTE = "Amnennar doesn't drop the Eye from his body: after killing him, click the Eye on the floor to pick it up."
    local SOURCE = "Click it after killing Amnennar the Coldbringer, the last boss of Razorfen Downs"
    local d = FDJ.DB and FDJ.DB["Razorfen Downs"]
    for _, q in ipairs((d and d.quests) or {}) do
        if q.id == 96773 or q.id == 97196 then
            q.objectiveNote = NOTE
            if type(q.requiredItem) == "table" then q.requiredItem[5] = SOURCE end
        end
    end
    local LOCAL = {
        deDE = { "Das Auge lässt sich nicht von Amnennars Leiche plündern: Klicke nach seinem Tod auf das Auge am Boden, um es aufzuheben.", "Nach dem Tod von Amnennar, dem letzten Boss, anklicken" },
        frFR = { "L'Œil ne se trouve pas sur le corps d'Amnennar : après l'avoir tué, cliquez sur l'Œil au sol pour le ramasser.", "À cliquer après avoir tué Amnennar, le dernier boss" },
        esES = { "El Ojo no está en el cuerpo de Amnennar: tras matarlo, haz clic en el Ojo del suelo para recogerlo.", "Haz clic en él tras matar a Amnennar, el último jefe" },
        esMX = { "El Ojo no está en el cuerpo de Amnennar: tras matarlo, haz clic en el Ojo del suelo para recogerlo.", "Haz clic en él tras matar a Amnennar, el último jefe" },
        itIT = { "L'Occhio non si trova sul corpo di Amnennar: dopo averlo ucciso, clicca sull'Occhio a terra per raccoglierlo.", "Cliccalo dopo aver ucciso Amnennar, l'ultimo boss" },
        ptBR = { "O Olho não está no corpo de Amnennar: depois de matá-lo, clique no Olho no chão para pegá-lo.", "Clique nele depois de matar Amnennar, o último chefe" },
        ruRU = { "Глаз нельзя забрать с тела Амненнара: после его убийства щёлкните по Глазу на полу, чтобы подобрать его.", "Щёлкните по нему после убийства Амненнара, последнего босса" },
        koKR = { "암네나르의 시체에서는 눈을 얻을 수 없습니다: 처치한 뒤 바닥에 있는 눈을 클릭해 주우세요.", "마지막 우두머리 암네나르를 처치한 뒤 클릭하세요" },
        zhCN = { "亚门纳尔的尸体上不会掉落眼睛：击杀他之后，点击地上的眼睛将其拾取。", "击杀最后一个首领亚门纳尔后点击它" },
        zhTW = { "亞門納爾的屍體上不會掉落眼睛：擊殺他之後，點擊地上的眼睛將其拾取。", "擊殺最後一個首領亞門納爾後點擊它" },
    }
    FDJ.ContentLocales = FDJ.ContentLocales or {}
    for lang, pair in pairs(LOCAL) do
        local c = FDJ.ContentLocales[lang]
        if not c and lang ~= "esMX" then
            c = {}
            FDJ.ContentLocales[lang] = c
        end
        if c then
            c.quests = c.quests or {}
            for _, id in ipairs({ 96773, 97196 }) do
                c.quests[id] = c.quests[id] or {}
                c.quests[id].objectiveNote = pair[1]
            end
            c.places = c.places or {} -- (the free-text lines: FDJ.LocalizeFreeText)
            if c.places[SOURCE] == nil then c.places[SOURCE] = pair[2] end
        end
    end
end
-- END eyeclick

-- BEGIN materials
-- Materials of Significance (2.1.0, M 19 Nov 2026; Nurax on Discord): the
-- Alliance Paladin quest from Gregory in Felwood whose parts come from
-- Maraudon and Blackrock Depths. One quest record in both dungeons' lists:
-- each page marks its own part (item.dungeon, a gold edge). Wowhead Forever
-- (quests 81790, 81766, 96476, 81944; items 220166-220170; NPCs Gregory
-- 221636, Aeonas the Vindicated 221587, the Silver Hand Charger 221832,
-- Brave Stonetorch 214529): level 53, requires 45, 12,750 XP and 1g 67s 52c
-- (the same 12,750 as Nurax's quest log; the 6,550 is A Newly Discovered
-- Purpose...'s, the Symbol of Faith's quest), no item reward. The
-- infernals' spot: their spawns in the Forever client's data.
do
    local function Gregory() return { mapID = 1448, x = 0.446, y = 0.520, label = "Gregory — Bloodvenom Falls, Felwood", targetName = "Gregory" } end
    local function Katherine() return { mapID = 1453, x = 0.486, y = 0.492, label = "Katherine the Pure — Cathedral of Light, Stormwind", targetName = "Katherine the Pure" } end
    local AT_GREGORY = "Gregory, near Bloodvenom Falls, Felwood (44.6, 52.0)"
    local AT_KATHERINE = "Katherine the Pure, Cathedral of Light, Stormwind"
    local quest = {
        classOnly = "PALADIN",
        warning = "Long chain quest: part of the Alliance Paladin storyline that also has A Brother In Need",
        objective = "Use the hints in Gregory's Note to determine where to find the magical components needed for the ritual. You will need help from allies for this.",
        rewardSummary = "1g 67s 52c",
        id = 81790,
        name = "Materials of Significance",
        faction = "Alliance",
        pickup = AT_GREGORY,
        startMap = Gregory(),
        turninMap = Gregory(),
        level = 53,
        requires = 45,
        note = "Alliance Paladin quest. How to unlock it: The Bloody Missive, then In Search of Aeonas (at the Emerald Sanctuary interact with Aeonas's horse first, then follow his trail), then speak with Aeonas and Gregory in Felwood: Gregory offers Materials of Significance. Its parts come from Felwood, Maraudon, Blackrock Depths and Hillsbrad Foothills.",
        turnin = AT_GREGORY,
        liveXPFallback = 12750,
        providedItem = {220170, "Note from Gregory", 1, "Given by Gregory when you accept the quest"},
        requiredItems = {
            {220166, "Fiery Infernal Core", 1, "Dropped by the infernals (Infernal Bodyguards, Infernal Sentries) in Shatter Scar Vale, northern Felwood", count = 3,
                map = { mapID = 1448, x = 0.430, y = 0.405, label = "Infernals — Shatter Scar Vale, Felwood" }},
            {220167, "Shimmering Grave Dust", 1, "From the grave mound in Princess Theradras's area of Maraudon", dungeon = "Maraudon"},
            {220168, "Triple-Brewed Molten Lager", 1, "Bought from Plugger Spazzring in the Grim Guzzler, Blackrock Depths", dungeon = "Blackrock Depths"},
            {220169, "Symbol of Faith", 1, "Reward from the quest A Newly Discovered Purpose...: Brave Stonetorch, Hillsbrad Foothills (67.4, 14.8)",
                map = { mapID = 1424, x = 0.674, y = 0.148, label = "Brave Stonetorch — Hillsbrad Foothills", targetName = "Brave Stonetorch" }},
        },
    }
    for _, name in ipairs({ "Maraudon", "Blackrock Depths" }) do
        local d = FDJ.DB and FDJ.DB[name]
        if d then
            d.quests = d.quests or {}
            local have = false
            for _, q in ipairs(d.quests) do if type(q) == "table" and q.id == quest.id then have = true end end
            if not have then table.insert(d.quests, quest) end
        end
    end
    -- fullchain (2.1.0, M 19 Nov 2026: "show the whole brother need chain ...
    -- we always show the chain"): the whole Alliance Paladin storyline, from
    -- the Strange Orb in Darkshore (A Brother In Need's own chain), through A
    -- Brother In Need, By The Light's Grace and Aeonas the Vindicated
    -- (Scarlet Monastery: Cathedral), then Some Good News, The Mysterious
    -- Merchant and Elrick, Paladin of the Silver Hand (Wowhead Forever's
    -- series 81762 > 81764 > 81765; the missive is Elrick's), to The Bloody
    -- Missive and In Search of Aeonas.
    local full = {}
    for _, step in ipairs(FDJ.QUEST_PREREQ_CHAINS[79946] or {}) do
        full[#full + 1] = { id = step.id, name = step.name }
    end
    for _, step in ipairs({
        { 79946, "A Brother In Need" }, { 79963, "By The Light's Grace" }, { 79970, "Aeonas the Vindicated" },
        { 81762, "Some Good News" }, { 81764, "The Mysterious Merchant" }, { 81765, "Elrick, Paladin of the Silver Hand" },
        { 81766, "The Bloody Missive" }, { 96476, "In Search of Aeonas" },
    }) do
        full[#full + 1] = { id = step[1], name = step[2] }
    end
    FDJ.QUEST_PREREQ_CHAINS[81790] = full
    local AT_CATHEDRAL_AEONAS = "Aeonas, rear chamber of the Cathedral, Scarlet Monastery"
    local function Elrick() return { mapID = 1445, x = 0.664, y = 0.454, label = "Elrick — Theramore Inn, Dustwallow Marsh", targetName = "Elrick" } end
    FDJ.QUEST_PREREQ_DETAILS[79946] = FDJ.QUEST_PREREQ_DETAILS[79946] or {
        level = 40, requires = 35,
        objective = "Find Aeonas in the Scarlet Monastery.",
        pickup = AT_KATHERINE, turnin = AT_CATHEDRAL_AEONAS, map = Katherine(),
    }
    FDJ.QUEST_PREREQ_DETAILS[79963] = FDJ.QUEST_PREREQ_DETAILS[79963] or {
        level = 40, requires = 35,
        objective = "Heal Aeonas (players report: to full health).",
        pickup = AT_CATHEDRAL_AEONAS, turnin = AT_CATHEDRAL_AEONAS,
    }
    FDJ.QUEST_PREREQ_DETAILS[79970] = FDJ.QUEST_PREREQ_DETAILS[79970] or {
        level = 40, requires = 35,
        objective = "Meet Aeonas in the Cathedral of Light in Stormwind.",
        pickup = AT_CATHEDRAL_AEONAS, turnin = "Aeonas, Cathedral of Light, Stormwind",
        turninMap = { mapID = 1453, x = 0.486, y = 0.492, label = "Aeonas the Vindicated — Cathedral of Light, Stormwind", targetName = "Aeonas the Vindicated" },
    }
    FDJ.QUEST_PREREQ_DETAILS[81762] = {
        level = 50, requires = 45,
        objective = "Speak with Katherine the Pure at the Cathedral of Light in Stormwind.",
        pickup = "Aeonas the Vindicated, Cathedral of Light, Stormwind", turnin = AT_KATHERINE,
        map = { mapID = 1453, x = 0.486, y = 0.492, label = "Aeonas the Vindicated — Cathedral of Light, Stormwind", targetName = "Aeonas the Vindicated" },
        turninMap = Katherine(),
    }
    FDJ.QUEST_PREREQ_DETAILS[81764] = {
        level = 50, requires = 45,
        objective = "Travel to Theramore and find the mysterious merchant.",
        pickup = AT_KATHERINE, turnin = "Elrick, Theramore Inn, Dustwallow Marsh (66.4, 45.4)",
        map = Katherine(), turninMap = Elrick(),
    }
    FDJ.QUEST_PREREQ_DETAILS[81765] = {
        level = 50, requires = 45,
        -- (Ennoris, Wowhead Forever's comments, 18 Nov 2026)
        warning = "In a group with other paladins only one of you can pick up the note Elrick drops (the Bloody Missive). If you didn't get it, don't hand this in to the innkeeper: abandon the quest and do it again.",
        objective = "Speak with Elrick to learn more.",
        pickup = "Elrick, Theramore Inn, Dustwallow Marsh (66.4, 45.4)", turnin = "Innkeeper Janene, Theramore Inn, Dustwallow Marsh (66.6, 45.2)",
        map = Elrick(),
        turninMap = { mapID = 1445, x = 0.666, y = 0.452, label = "Innkeeper Janene — Theramore Inn, Dustwallow Marsh", targetName = "Innkeeper Janene" },
    }
    FDJ.FOREVER_QUEST_XP_FALLBACK[79970] = FDJ.FOREVER_QUEST_XP_FALLBACK[79970] or 2350
    FDJ.FOREVER_QUEST_XP_FALLBACK[81762] = 2350
    FDJ.FOREVER_QUEST_XP_FALLBACK[81764] = 4700
    FDJ.FOREVER_QUEST_XP_FALLBACK[81765] = 5900
    FDJ.PREREQ_REWARD_MONEY_FALLBACK[81764] = 8225
    FDJ.PREREQ_REWARD_MONEY_FALLBACK[81765] = 10325
    FDJ.PREREQ_REWARD_ITEMS_FALLBACK[79970] = FDJ.PREREQ_REWARD_ITEMS_FALLBACK[79970] or { items = { {277236, "Pauldrons of Vindication", 3} }, choice = false }
    for _, id in ipairs({ 81762, 81765 }) do FDJ.QUEST_SHAREABILITY_AUDIT[id] = false end
    FDJ.QUEST_PREREQ_DETAILS[81766] = {
        level = 50, requires = 45,
        objective = "Bring the missive to Katherine the Pure at the Cathedral of Light in Stormwind.",
        startItem = {219929, "Bloody Missive", 1, "Found on the body of the \"paladin\": the search for the \"merchant\" was a trap"},
        pickup = "Bloody Missive, found on the body of the \"paladin\"",
        turnin = AT_KATHERINE, turninMap = Katherine(),
    }
    FDJ.QUEST_PREREQ_DETAILS[96476] = {
        level = 53, requires = 45,
        objective = "Search for signs of Aeonas the Vindicated at the Emerald Sanctuary in Felwood.",
        description = "At the Emerald Sanctuary, interact with Aeonas's horse (the Silver Hand Charger, 51.0, 81.8) first, then follow Aeonas's trail in Felwood to him (45.0, 52.0). Then speak with Aeonas and Gregory: Gregory offers Materials of Significance.",
        pickup = AT_KATHERINE, map = Katherine(),
        objectiveMap = { mapID = 1448, x = 0.510, y = 0.818, label = "Aeonas's horse — Emerald Sanctuary, Felwood", targetName = "Silver Hand Charger" },
        turnin = "Aeonas the Vindicated, Felwood (45.0, 52.0)",
        turninMap = { mapID = 1448, x = 0.450, y = 0.520, label = "Aeonas the Vindicated — Felwood", targetName = "Aeonas the Vindicated" },
    }
    FDJ.FOREVER_QUEST_XP_FALLBACK[81766] = 5900
    FDJ.FOREVER_QUEST_XP_FALLBACK[96476] = 2650
    FDJ.FOREVER_QUEST_XP_FALLBACK[81790] = 12750
    FDJ.PREREQ_REWARD_MONEY_FALLBACK[81766] = 10412
    -- Not sharable (Wowhead Forever).
    for _, id in ipairs({ 81766, 96476, 81790 }) do
        FDJ.QUEST_SHAREABILITY_AUDIT[id] = false
    end
end
-- END materials

-- BEGIN repeatonce
-- repeatonce (2.1.0, M 19 Nov 2026; Ziefog on Discord: The Medallion of Faith
-- "is repeatable"): in WoW Forever the quest stays repeatable under its own ID,
-- so the game never marks it done. As with Blackmaw Pouches, the journal lists
-- it twice: the quest itself, ticked once this character has handed it in
-- (remembered at the hand-in, or proven by the quest after it, Aurius'
-- Reckoning), and a repeatable entry (blue ?) that is always there.
-- FDJ.REPEAT_ONCE[id] = { ids that prove it was done }.
FDJ.REPEAT_ONCE = FDJ.REPEAT_ONCE or {}
FDJ.REPEAT_ONCE[5122] = { 5125 }
function FDJ.DoneOnce(questID)
    local proof = FDJ.REPEAT_ONCE[questID]
    if not proof then return false end
    local db = ForeverDungeonJournalCharacterDB
    if type(db) == "table" and type(db.doneOnce) == "table" and db.doneOnce[questID] then return true end
    if C_QuestLog and type(C_QuestLog.IsQuestFlaggedCompleted) == "function" then
        for _, id in ipairs(proof) do
            local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
            if ok and done == true then return true end
        end
    end
    return false
end
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("QUEST_TURNED_IN")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(_, event, questID)
        if event == "PLAYER_LOGIN" then
            -- The repeatable entry's texts: the quest's own, per language.
            for _, content in pairs(FDJ.ContentLocales or {}) do
                local src = type(content) == "table" and content.quests and content.quests[5122]
                if src then
                    local copy = content.quests[-5122] or {}
                    for k, v in pairs(src) do if copy[k] == nil then copy[k] = v end end
                    content.quests[-5122] = copy
                end
            end
            return
        end
        questID = tonumber(questID)
        if not (questID and FDJ.REPEAT_ONCE[questID]) then return end
        ForeverDungeonJournalCharacterDB = ForeverDungeonJournalCharacterDB or {}
        local db = ForeverDungeonJournalCharacterDB
        if type(db.doneOnce) ~= "table" then db.doneOnce = {} end
        db.doneOnce[questID] = true
    end)
    -- The repeatable entry, right after the quest itself (its own stand-in
    -- ID, so the game's state of 5122 ticks only the quest itself).
    local d = FDJ.DB and FDJ.DB["Stratholme: Living"]
    if d and type(d.quests) == "table" then
        local at, have
        for i, q in ipairs(d.quests) do
            if type(q) == "table" and q.id == 5122 then at = i end
            if type(q) == "table" and q.id == -5122 then have = true end
        end
        if at and not have then
            local base = d.quests[at]
            table.insert(d.quests, at + 1, {
                id = -5122, name = base.name, faction = base.faction, level = base.level, requires = base.requires,
                repeatable = true, startsInDungeon = base.startsInDungeon,
                objective = base.objective, pickup = base.pickup, turnin = base.turnin, rewardSummary = "",
                note = "Repeatable, after the first The Medallion of Faith.",
            })
        end
    end
end
-- END repeatonce

-- insideaudit (2.1.1, M 20 Nov 2026, Test of Lore's Library step and Old
-- Fire-Eye's page: "you need to fix every one of them ... understand where
-- the problem is"): every dungeon quest and every step of its chain checked
-- against where it is really done (the quest database's mobs, items and
-- objects, the quests' own texts and notes); here at the end of the file,
-- once every quest and step above is in place. The tint and "Dungeon Step"
-- only where something of the quest itself is done inside a dungeon (this
-- page's or another's): steps the text check missed ("Blackrock Spire" is
-- not the name of either spire's page; "the Rookery"; a dungeon named only
-- in a note) are set by hand; quests done only outside (a breadcrumb, a
-- delivery or a wait in town, mobs outside the instance) lose the tint.
do
    local D = FDJ.QUEST_PREREQ_DETAILS
    -- steps done inside
    for _, id in ipairs({
        4974, 6569, 4903, 4734, 4735, 1109, 93404, 7629, 7642, 5463, 7643, 5382,
        5515, 5384, 4241, 3527, 3528, 78261, 78676, 79946, 79963
    }) do
        if D[id] then D[id].objectiveInDungeon = true end
    end
    -- steps started inside (an item a mob drops in there, an NPC in there)
    for _, id in ipairs({
        5089, 6522, 373, 4264, 79970
    }) do
        if D[id] then D[id].dungeonStep = true end
    end
    -- dungeon quests done entirely outside: no tint
    local outside = {}
    for _, id in ipairs({
        3765, 1806, 6562, 4128, 4133, 4324, 7492, 7494, 5250, 98823, 98824, 2926,
        2843, 2948, 2950, 94998, 6626, 6521, 1848, 1782, 96016, 79442, 6141, 78699,
        78307, 168, 167, 5961, 8233, 8417, 8254, 8415, 8250, 8151, 9063, 96078,
        95799, 95798, 704, 707, 2341, 2418, 2361, 709, 2439, 2440, 4766, 4769,
        2861, 2769, 2864
    }) do
        outside[id] = true
    end
    for _, dungeon in pairs(FDJ.DB or {}) do
        for _, quest in ipairs(type(dungeon) == "table" and dungeon.quests or {}) do
            if type(quest) == "table" and outside[quest.id] then quest.dungeonStep = false end
        end
    end
end

-- BEGIN uldwarn
-- uldwarn (2.1.3, M 21 Nov 2026, the Uldaman pages: "we need a disclaimer
-- that says farm elites outside of Uldaman for the necklace. We also need a
-- disclaimer for the urn quest, saying: This is completed OUTSIDE, in the
-- tunnel leading to the entrance"): the warning line at the top of The
-- Shattered Necklace's step page and of Agmond's Fate's page (translated:
-- Localization/Content_NewDungeons.lua, l10nuldwarn).
do
    local D = FDJ.QUEST_PREREQ_DETAILS
    if D and D[2198] then
        D[2198].warning = "Farm the elites outside Uldaman for the necklace."
        D[2198].warningTop = true
    end
    local ud = FDJ.DB and FDJ.DB["Uldaman"]
    for _, quest in ipairs((ud and ud.quests) or {}) do
        if type(quest) == "table" and quest.id == 704 then
            -- (M 21 Nov 2026: "say this is completed in the area outside the
            -- dungeon. Don't mention the tunnel")
            quest.warning = "This is completed in the area outside the dungeon."
        end
        -- (M 21 Nov 2026, Power Stones' note: "we should just delete it and
        -- basically move it as a disclaimer ... the power stones can also drop
        -- from elite dwarves outside the dungeon"; they drop inside too:
        -- Wowhead Forever, SOURCES.txt)
        if type(quest) == "table" and quest.id == 2418 then
            quest.warning = "The power stones can also drop from elite dwarves outside the dungeon."
        end
    end
end
-- END uldwarn

-- BEGIN outsidesteps
-- outsidesteps (2.1.3, M 21 Nov 2026, A Sign of Hope's page: "It's not a
-- dungeon chain step, it's outside ... Remove the dungeon chain step ... and
-- put a disclaimer outside the instance at the top. And then it's the same
-- thing for the next quest ... the quest after, Prospect of Faith is also not
-- a dungeon chain step"): Hammertoe Grez, Magregan Deepshadow and Prospector
-- Ryedol stand outside the instance (the quest database's spawns; Wowhead,
-- warcraft.wiki.gg, classicdb, warcrafttavern: SOURCES.txt). The text check
-- took "in Uldaman" in their objectives for inside. Necklace Recovery (2283,
-- Horde's Shattered Necklace) the same: the necklace drops at the dig site
-- outside (necklaceout). Every other step with the label was checked against
-- where its NPCs, objects and items really are: done inside a dungeon.
do
    local D = FDJ.QUEST_PREREQ_DETAILS
    for _, id in ipairs({ 721, 722, 723, 2283 }) do
        if D and D[id] then
            D[id].dungeonStep = false
            D[id].objectiveInDungeon = false
            D[id].startsInDungeon = nil
        end
    end
    -- the warning line at the top (translated: Localization/
    -- Content_NewDungeons.lua, l10nuldwarn)
    for _, id in ipairs({ 721, 722 }) do
        if D and D[id] then
            D[id].warning = "This is completed OUTSIDE the instance."
            D[id].warningTop = true
        end
    end
end
-- END outsidesteps
-- BEGIN gemswarn
-- gemswarn (2.1.3, M 21 Nov 2026, Find the Gems' page: "we need to add a
-- disclaimer to this quest, and we say complete this quest before killing
-- the last boss"): the warning line at the top of the Alliance's Find the
-- Gems (the next step, Restoring the Necklace, wants the power source from
-- Archaedas). Translated: Localization/Content_NewDungeons.lua, l10nuldwarn.
do
    local D = FDJ.QUEST_PREREQ_DETAILS
    if D and D[2201] then
        D[2201].warning = "Complete this quest before killing the last boss."
        D[2201].warningTop = true
    end
end
-- END gemswarn

-- BEGIN hammertoecave
-- hammertoecave (2.1.3, M 21 Nov 2026, standing at Hammertoe Grez with the
-- arrow 163 yards back at the cave mouth: "It thinks that this NPC is
-- outside the tunnel, but it's actually inside ... You need to research this
-- NPC position better"): Hammertoe stands at 37.9, 10.6 (the Forever
-- client's spawn; Allakhazam's 37.94, 10.53; M in game beside him at 37.8,
-- 11.1), about 160 yards into the excavation tunnel. His spot was the cave
-- mouth (44.3, 12.0, Data/QuestMaps.lua). From outside, the arrow leads to
-- the cave mouth first, because the straight line goes over the ridge the
-- tunnel runs under. Inside, anywhere nearer to him than the mouth (forward),
-- it points straight at him.
do
    FDJ.ARROW_VIAS = FDJ.ARROW_VIAS or {}
    FDJ.ARROW_VIAS[string.format("%s|%.4f|%.4f", "1418", 0.379, 0.106)] = { forward = true,
        { mapID = 1418, x = 0.443, y = 0.120, label = "Into the excavation cave" },
    }
end
-- END hammertoecave

-- BEGIN fungusout
-- fungusout (2.1.3, M 21 Nov 2026, Uldaman Reagent Run's page after picking
-- three caps in the excavation tunnel by Hammertoe: "let's say these can
-- also be picked up outside the dungeon"): the Magenta Cap Clusters grow in
-- the outer excavation caves too (the Forever client's spawns: 17 between
-- 33.5 and 41.0, 10.4 to 24.4, Badlands) as well as inside. The Alliance's
-- quest (17) and the Horde's (2202) are the same. Translated: l10nuldwarn.
do
    local ud = FDJ.DB and FDJ.DB["Uldaman"]
    for _, quest in ipairs((ud and ud.quests) or {}) do
        if type(quest) == "table" and (quest.id == 17 or quest.id == 2202) then
            quest.warning = "The Magenta Fungus Caps can also be picked up outside the dungeon."
        end
    end
end
-- END fungusout

-- BEGIN ancientchest
-- ancientchest (2.1.3, M 21 Nov 2026, standing at the Ancient Chest in the
-- Sealed Hall with Solution to Doom: "this quest is also outside the
-- instance ... we should put a disclaimer ... If you could somehow put this
-- minimap ... the black dot is where the quest is made, and it's also where
-- Amulet of Secrets is made"): the chest stands at 39.3, 18.8 in the outer
-- caves (the Forever client's spawn; icy-veins Forever: 39.5, 18.6; M in game
-- at 39.4, 19.6). The picture: M's minimap there (21 Nov 2026), his own arrow
-- painted out, the black mark circled (Media/UldamanExcavationMinimap.tga).
-- Translated: l10nuldwarn (the warning), l10nhammertoecave (the captions).
do
    local IMG = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\UldamanExcavationMinimap"
    local ud = FDJ.DB and FDJ.DB["Uldaman"]
    for _, quest in ipairs((ud and ud.quests) or {}) do
        if type(quest) == "table" and quest.id == 709 then
            quest.warning = "The Tablet of Ryun'eh is in the Ancient Chest outside the instance."
            quest.noteImage = { file = IMG, size = 190, marks = { { x = 0.6246, y = 0.7275, item = 4631 } },
                caption = "Minimap, outside Uldaman: the icon marks the Ancient Chest." }
        end
    end
    local D = FDJ.QUEST_PREREQ_DETAILS
    if D and D[722] then
        D[722].noteImage = { file = IMG, size = 190, marks = { { x = 0.6246, y = 0.7275, item = 4635 } },
            caption = "Minimap, outside Uldaman: the icon marks Magregan Deepshadow." }
    end
end
-- END ancientchest

-- BEGIN commonhall
-- commonhall (2.1.3, M 21 Nov 2026, Reclaimed Treasures' page in the North
-- Common Hall with his minimap: "This quest is also outside the instance ...
-- I don't want you to show the black dot ... replace the black dot with the
-- actual icon of the quest"): Krom Stoutarm's Chest stands at 35.6, 23.5 in
-- the outer caves (the Forever client's spawn; icy-veins Forever: 35.7,
-- 23.5), about 70 yards south of where M stood (35.1, 19.3). The picture
-- (Media/UldamanCommonHallMinimap.tga): M's minimap there, his arrow painted
-- out, the chest's place from the minimap's indoor scale (300 yards across):
-- the south end of the hall below him. The black mark on the Sealed Hall
-- picture is painted out too: the quests' own item icons go in the gold rings
-- (marks, Core/Journal.lua noteimage). The Horde's Reclaimed Treasures (2342):
-- the Garrett Family Chest, 34.2, 18.6, outside too (same sources).
do
    local IMG = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\UldamanCommonHallMinimap"
    local ud = FDJ.DB and FDJ.DB["Uldaman"]
    for _, quest in ipairs((ud and ud.quests) or {}) do
        if type(quest) == "table" and quest.id == 1360 then
            quest.warning = "Krom Stoutarm's Treasure is in his chest outside the instance."
            quest.noteImage = { file = IMG, size = 190, marks = { { x = 0.5379, y = 0.7112, item = 8027 } },
                caption = "Minimap, outside Uldaman: the icon marks Krom Stoutarm's Chest." }
        end
        if type(quest) == "table" and quest.id == 2342 then
            quest.warning = "The Garrett Family Treasure is in the family chest outside the instance."
        end
    end
end
-- END commonhall

-- BEGIN restlesssouls
-- The Restless Souls (Stratholme, both pages): Egan's quest (5282) can only
-- be taken after Caretaker Alen's The Restless Souls (5281) in Light's Hope
-- Chapel, so 5281 is a required step, not an optional introduction (kaanu
-- on the Discord, 21 Nov 2026: at level 55 without 5281 done, Egan doesn't
-- offer 5282; Wowhead Forever quest 5281).
FDJ.QUEST_PREREQ_CHAINS[5282] = {
    { id = 5281, name = "The Restless Souls" },
}
FDJ.QUEST_PREREQ_DETAILS[5281] = {
    level = 60,
    requires = 55,
    objective = "Find Egan. You only know that he was last seen around Stratholme.",
    -- Egan is in Terrordale, outside: the objective's "around Stratholme"
    -- made it a step inside the dungeon (teal page, dungeon icon).
    objectiveInDungeon = false,
    pickup = "Caretaker Alen, Light's Hope Chapel, Eastern Plaguelands",
    turnin = "Egan, Terrordale, Eastern Plaguelands",
    map = FDJ.QUEST_START_MAPS and FDJ.QUEST_START_MAPS[5281],
}
FDJ.FOREVER_QUEST_XP_FALLBACK[5281] = FDJ.FOREVER_QUEST_XP_FALLBACK[5281] or 6600
-- END restlesssouls
