local ADDON_NAME, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS

local function L(key, ...)
    if FDJ and FDJ.L then return FDJ.L(key, ...) end
    return key
end

local function DungeonName(name)
    return FDJ.LocalizeDungeonName and FDJ.LocalizeDungeonName(name) or name
end

local function DungeonField(name, field, fallback)
    return FDJ.LocalizeDungeonField and FDJ.LocalizeDungeonField(name, field, fallback) or fallback
end

local function QuestField(questID, field, fallback)
    return FDJ.LocalizeQuestField and FDJ.LocalizeQuestField(questID, field, fallback) or fallback
end

local function BossName(name)
    return FDJ.LocalizeBossName and FDJ.LocalizeBossName(name) or name
end

local function ItemSlot(text)
    return FDJ.LocalizeItemSlot and FDJ.LocalizeItemSlot(text) or text
end

local function FreeText(text)
    return FDJ.LocalizeFreeText and FDJ.LocalizeFreeText(text) or text
end

local DB = FDJ.DB
local ORDER = FDJ.ORDER
local BOSS_LEVELS = FDJ.BOSS_LEVELS
local QUEST_START_MAPS = FDJ.QUEST_START_MAPS or {}
local THEMES = FDJ.THEMES
local FOREVER_QUEST_XP_FALLBACK = FDJ.FOREVER_QUEST_XP_FALLBACK
local FOREVER_QUEST_BASE_XP = FDJ.FOREVER_QUEST_BASE_XP
local QUEST_PREREQ_CHAINS = FDJ.QUEST_PREREQ_CHAINS
local QUEST_PREREQ_DETAILS = FDJ.QUEST_PREREQ_DETAILS
local PREREQ_REWARD_ITEMS_FALLBACK = FDJ.PREREQ_REWARD_ITEMS_FALLBACK
local PREREQ_REWARD_MONEY_FALLBACK = FDJ.PREREQ_REWARD_MONEY_FALLBACK
local STATIC_DISPLAY_IDS = FDJ.STATIC_DISPLAY_IDS
local EQUIP_LOC_SLOTS = FDJ.EQUIP_LOC_SLOTS
local STAT_DELTA_ORDER = FDJ.STAT_DELTA_ORDER
local STAT_DELTA_FALLBACK_LABELS = FDJ.STAT_DELTA_FALLBACK_LABELS
local DUNGEON_HOME_ART = FDJ.DUNGEON_HOME_ART
local DUNGEON_HOME_TEXCOORD = FDJ.DUNGEON_HOME_TEXCOORD
local DUNGEON_PAGE_ART = FDJ.DUNGEON_PAGE_ART
local DUNGEON_PAGE_TEXCOORD = FDJ.DUNGEON_PAGE_TEXCOORD

local ShowRecordedLocationOnMap = FDJ.MapMarkers.ShowRecordedLocationOnMap
local ShowRouteOnMap = FDJ.MapMarkers.ShowRouteOnMap
local ShowQuestStartOnMap = FDJ.MapMarkers.ShowQuestStartOnMap

-- Deadmines: beta cache quests and observed loot; see SOURCES.txt.

-- Blackfathom Deeps: Forever beta quest cache + observed/Classic loot assignments.

-- Ragefire Chasm: current Forever beta quest cache + observed loot.

-- v1.0.26: verified boss levels. Values are deliberately static rather than
-- guessed from the dungeon range. Returning-dungeon values use Classic Era
-- creature data (the Forever beta currently retains those boss levels).
-- Forever-exclusive values are only included where current beta reporting or
-- an in-game sighting confirms them. Durgen is confirmed level 16 from an in-game screenshot.
local function BossLevelText(dungeonName, boss)
    local byDungeon = BOSS_LEVELS[(boss and boss.fdjDungeon) or dungeonName]
    if not byDungeon or not boss then return nil end
    return byDungeon[boss.name]
end

-- Fit multi-level ranges (for example 24-25) cleanly inside the circular
-- medallion without shrinking normal two-digit boss levels.
local function FitBossLevelText(fontString, text)
    if not fontString or not text then return end

    if not fontString.fdjBaseFontPath then
        local fontPath, fontSize, fontFlags = fontString:GetFont()
        fontString.fdjBaseFontPath = fontPath
        fontString.fdjBaseFontSize = fontSize
        fontString.fdjBaseFontFlags = fontFlags or ""
    end

    local fontPath = fontString.fdjBaseFontPath
    local baseSize = fontString.fdjBaseFontSize or 10
    local flags = fontString.fdjBaseFontFlags or ""
    if not fontPath then return end

    if tostring(text):find("%-") then
        -- Ranges need substantially less width than the normal two-digit label.
        fontString:SetFont(fontPath, math.max(7, math.floor(baseSize * 0.67 + 0.5)), flags)
    else
        fontString:SetFont(fontPath, baseSize, flags)
    end
end


-- Known quest-start coordinates. Coordinates are normalized (0-1) for the
-- Classic/Forever world-map canvas. Forever uses the Classic UIMapIDs here
-- (Westfall 1436, Stormwind City 1453), not the Retail IDs 52 / 84.
local selectedDungeon = ForeverDungeonJournalDB.lastDungeon or ORDER[1]
local selectedBoss = ForeverDungeonJournalDB.lastBoss or 1
local selectedQuest = ForeverDungeonJournalDB.lastQuest or 1
local allowHiddenQuestSelection = false
local selectedMode = ForeverDungeonJournalDB.lastMode or "bosses"
local selectedQuestFaction = ForeverDungeonJournalDB.questFaction or "Alliance"
local selectedPrereqStep = nil
local selectedPrereqParentQuestName = nil
local selectedPrereqParentQuestID = nil
local sessionLastView = "home"

local frame
local minimapButton
local itemTooltip

-- Reuse native Blizzard UI sounds so the journal feels like part of the client.
-- Numeric fallbacks keep this working on Forever/Classic builds where a SOUNDKIT
-- constant may not be exposed even though the underlying sound kit exists.
local function PlayJournalPaperSound()
    if PlaySound then
        PlaySound((SOUNDKIT and SOUNDKIT.IG_ABILITY_PAGE_TURN) or 836)
    end
end

local function PlayJournalOptionSound()
    if PlaySound then
        PlaySound((SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION) or 852)
    end
end

-- Header language picker. Display names intentionally use each language's own
-- name so the menu is easy to recognize regardless of the active UI locale.
local LANGUAGE_CHOICES = {
    { code = "en", locale = "enUS", label = "English" },
    { code = "de", locale = "deDE", label = "Deutsch" },
    { code = "fr", locale = "frFR", label = "Français" },
    { code = "es", locale = "esES", label = "Español" },
    { code = "it", locale = "itIT", label = "Italiano" },
    { code = "pt", locale = "ptBR", label = "Português" },
    { code = "ru", locale = "ruRU", label = "Русский" },
    { code = "ko", locale = "koKR", label = "한국어" },
    { code = "zh", locale = "zhCN", label = "简体中文" },
    { code = "zhtw", locale = "zhTW", label = "繁體中文" },
}

local RAGEFIRE_MAP = {
    uiMapID = 213,
    bosses = {
        -- Aligned to the four native encounter symbols visible on the Ragefire
        -- parchment (same layout used by established dungeon-map addons).
        -- Coordinates normalized against the native 3:2 Ragefire parchment.
        -- These align with the labeled Classic dungeon map, not the tile grid.
        { name = "Oggleflint", x = 0.885, y = 0.585 },
        { name = "Taragaman the Hungerer", x = 0.435, y = 0.515 },
        { name = "Jergosh the Invoker", x = 0.350, y = 0.825 },
        { name = "Bazzalan", x = 0.485, y = 0.885 },
    },
}

-- Custom dungeon map pages. Only dungeons listed here get the "Map" tab.
-- texture: power-of-two TGA in Media; the art occupies texCoord (right/bottom)
-- of it; aspect is the art's width/height. Boss x/y are normalized to the art.
-- (Stored on FDJ, not as a file local: Journal.lua is at Lua 5.1's
-- 200-locals-per-chunk limit.)
FDJ.DUNGEON_MAPS = {
    -- Custom parchments shipped in Media (art sits in the top part of a
    -- 1024x1024 TGA). Classic dungeons use the client's own map tiles
    -- (Interface\WorldMap\<Name>\<Name><floor>_1..12, a 4x3 grid of 256px
    -- tiles whose visible part is 1002x668).
    -- entrance.angle: direction (degrees, 0 = right, 90 = up) from the
    -- entrance to where the arrow and its "Entrance" label sit.
    ["Hall of Thanes"] = {
        floors = { { texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\HallOfThanesMap", texBottom = 683 / 1024 } },
        entrance = { floor = 1, x = 0.510, y = 0.944, angle = 0 },
        bosses = {
            { name = "Faldrim Anvilmar",   x = 0.509, y = 0.668 },
            { name = "Magmatus",           x = 0.748, y = 0.478 },
            { name = "Plunder",            x = 0.510, y = 0.515 },
            { name = "Durgen Dirgehammer", x = 0.509, y = 0.170 },
        },
    },
    ["Ruins of Lordaeron"] = {
        floors = { { texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\RuinsOfLordaeronMap", texBottom = 683 / 1024 } },
        entrance = { floor = 1, x = 0.612, y = 0.214, angle = 180 },
        -- NPCs who take quests inside the dungeon (quest tracker's ? button):
        -- Captain Truman stands just inside, by the entrance.
        turnins = {
            { npc = "Captain Truman", x = 0.612, y = 0.272 },
        },
        -- Positions follow the published run order: Witherfang in the long
        -- hallway east of the entrance (King's Alley), The Baron in the
        -- indoor courtyard after it, then the U-shaped path, The Abandoned's
        -- statue event, Bjork in the foggy area below Market Street and
        -- Rath'mael on the purple rune in the south-west.
        bosses = {
            { name = "Witherfang",        x = 0.668, y = 0.360 },
            { name = "The Baron",         x = 0.615, y = 0.650 }, -- from the author's minimap screenshot (King's Alley, curved road)
            { name = "Viktor the Vile",   x = 0.437, y = 0.788 }, -- beside Lordaeron Graveyard (author's black dot, 6 Nov 2026)
            { name = "The Abandoned",     x = 0.395, y = 0.665 },
            { name = "Bjork",             x = 0.345, y = 0.220 },
            { name = "Rath'mael",         x = 0.520, y = 0.600 },
            { name = "Lordaeron Captain", x = 0.500, y = 0.300 },
        },
    },

    ["City of Dalaran"] = {
        -- Level 1 is the Underbelly (where the dungeon starts), Level 2 the city.
        floors = {
            { texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\DalaranUnderbellyMap", texBottom = 1365 / 2048 },
            { texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\DalaranCityMap", texBottom = 1365 / 2048 },
        },
        -- The dungeon starts at the portal at the end of the Underbelly pipe.
        entrance = { floor = 1, x = 0.190, y = 0.838, angle = 0 },
        transitions = {
            { floor = 1, to = 2, x = 0.778, y = 0.564 },
        },
        -- Only bosses whose spot is known are placed.
        bosses = {
            { name = "Atrexis the Grave Knight", floor = 1, x = 0.535, y = 0.505 },
            { name = "Lyn the Ignored",          floor = 1, x = 0.680, y = 0.177 },
            { name = "Mana Devourer",            floor = 2, x = 0.416, y = 0.730 },
            { name = "Fel Ancient",              floor = 2, x = 0.513, y = 0.549 },
            { name = "Unstable Sentinel",        floor = 2, x = 0.614, y = 0.413 },
            { name = "Arcanic Enigma",           floor = 2, x = 0.669, y = 0.503 },
            { name = "Arcane Anomaly",           floor = 2, x = 0.527, y = 0.843 },
            { name = "Shade of the Archmage",    floor = 2, x = 0.520, y = 0.240 },
        },
    },

    -- Boss positions: OMGmacros's numbered map on Discord ("Drowned City
    -- Boss locations", 12 Nov 2026), drawn on this same map art.
    ["The Drowned City"] = {
        -- Two distinct published maps; Atal'Byzal is the underground level.
        floors = {
            { texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\DrownedCityMap", texBottom = 683 / 1024, label = "The Drowned City" },
            { texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\DrownedCityAtalByzalMap", texBottom = 683 / 1024, label = "Atal'Byzal" },
        },
        entrance = { floor = 1, x = 0.846, y = 0.521, angle = 0 }, -- the swirl in Sunken Hollow
        -- drownedpins (2.0.9, M 16 Nov 2026, his marked map): where to swim
        -- down to Atal'Byzal (his green dot).
        transitions = {
            { floor = 1, to = 2, x = 0.575, y = 0.599, tipKey = "MAP_SWIM_HERE" }, -- (M: the text on hover only)
            { floor = 1, to = 2, x = 0.590, y = 0.837, tipKey = "MAP_SWIM_HERE" }, -- the other way down, by Umbra (M's black dot): a swim too
            -- drownedexits (2.0.9, M 16 Nov 2026, his marked Atal'Byzal map): the two ways
            -- back up, at the corridor's ends
            { floor = 2, to = 1, x = 0.679, y = 0.113, labelKey = "MAP_SHARK_EXIT", color = { 1.00, 0.25, 0.20 } }, -- red: danger (M)
            { floor = 2, to = 1, x = 0.262, y = 0.792, labelKey = "MAP_SAFE_EXIT" },
        },
        bosses = {
            { name = "Zul'Alai",            floor = 1, x = 0.697, y = 0.572 },
            -- In the round flooded room east of Var'Taka (OMGmacros's update, same
            -- thread): reached by swimming, from the pool to the south or from
            -- the big basin; the 2nd boss for most groups.
            -- drownedpins (2.0.9, M 16 Nov 2026): on the Atal'Byzal page, in
            -- its round chamber (M said the second page; the spot on it is ours)
            { name = "Primeval Elemental",  floor = 2, x = 0.667, y = 0.550 },
            { name = "Umbra",               floor = 1, x = 0.545, y = 0.829 }, -- drownedpins: M's black dot
            { name = "\"Pyromancer\" Braxton", floor = 1, x = 0.495, y = 0.368 }, -- drownedpins: M's orange dot
            { name = "Var'Taka",            floor = 1, x = 0.514, y = 0.689 },
            { name = "Captain Dreadrise",   floor = 1, x = 0.546, y = 0.344 }, -- he paths around there
            { name = "Deathless Marrow",    floor = 1, x = 0.349, y = 0.536 },
            { name = "Min'loth the Serpent", floor = 1, x = 0.196, y = 0.539 },
        },
    },
    -- Blackmaw Hold: six levels from Santiago Reyes' Forever dungeon maps.
    -- Floor names are visible on hover; do not guess boss positions from art.
    ["Blackmaw Hold"] = {
        floors = {
            { texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\BlackmawHoldGroveMap",          texBottom = 683 / 1024, label = "Blackmaw Grove" },
            { texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\BlackmawHoldFesteringGrottoMap", texBottom = 683 / 1024, label = "Festering Grotto" },
            { texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\BlackmawHoldFallenGroveMap",    texBottom = 683 / 1024, label = "Depths of the Fallen Grove" },
            { texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\BlackmawHoldEldersMap",         texBottom = 683 / 1024, label = "Depths of the Elders" },
            { texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\BlackmawHoldBurrowMap",         texBottom = 683 / 1024, label = "Depths of the Burrow" },
            { texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\BlackmawHoldForbiddenMagicMap", texBottom = 683 / 1024, label = "Depths of Forbidden Magic" },
        },
        -- Entrance swirl visible west of Blackmaw Grove on the original map.
        entrance = { floor = 1, x = 0.183, y = 0.740, angle = 90 },
        bosses = {}, -- Locations unverified; no fabricated boss markers.
    },
    -- Boss positions: falling/Ekiroth's numbered map on Discord ("Bastion
    -- Krol'dok", 12 Nov 2026), bosses 1-6 in the order they are fought.
    ["Krol'dok Stronghold"] = {
        floors = { { texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\KroldokMap", texBottom = 683 / 1024 } },
        entrance = { floor = 1, x = 0.205, y = 0.807, angle = 180 }, -- the swirl where the trail comes in (south-west)
        bosses = {
            { name = "Slavecrusher Grox",          floor = 1, x = 0.331, y = 0.703 },
            { name = "Twilight Commander Zarmok",  floor = 1, x = 0.392, y = 0.734 },
            { name = "War Handler Ashka",          floor = 1, x = 0.621, y = 0.527 },
            -- nargurkmove (2.1.1, M 20 Nov 2026, his marked map: "move
            -- Nargorg to the green dot"): was 0.411, 0.579
            { name = "Nar'gurk",                   floor = 1, x = 0.381, y = 0.526 },
            { name = "Bossman Toof",               floor = 1, x = 0.617, y = 0.432 },
            { name = "Overlord Mugg",              floor = 1, x = 0.688, y = 0.242 },
            -- tunkpin (2.1.1, M 20 Nov 2026: "we should add Tunk on the map as
            -- a quest mob, like we do for the mob in excavation site ... it's
            -- here on the orange box"): Tunk (NPC 259256, AllTheThings), the
            -- ogre blacksmith whose Krol'dok Moulding starts Key Ingredients'
            -- chain, at his forge east of War Handler Ashka (where M marked
            -- him; "a small blacksmithing area" after the third boss,
            -- Mobalytics / Icy Veins). One pin for both factions' quests.
            { name = "Tunk",                       floor = 1, x = 0.691, y = 0.493, npcID = 259256, quest = { 94981, 94974 } },
            -- zalfanpin (2.1.1, M 20 Nov 2026 in the stronghold: "I found a
            -- new quest mob Zalfan Moonshadow ... put him on the orange dot"):
            -- Vengeance of the Highborne's target (NPC 268423, Wowhead
            -- Forever), up the ramp toward Nar'gurk ("turn right when going up
            -- the ramp to Nar'gurk, he paths", its comment).
            { name = "Zalfan Moonshadow",          floor = 1, x = 0.430, y = 0.495, npcID = 268423, quest = 96771 },
        },
    },
    ["Alcaz Prison"] = {
        -- Level 1: Main Unit (the entrance); Level 2: Maximum Security Unit.
        floors = {
            { texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\AlcazPrisonMap", texBottom = 683 / 1024 },
            { texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\AlcazPrisonMap2", texBottom = 683 / 1024 },
        },
        -- the swirl at the top of the stairs; its label above it (alcazpins:
        -- The Questioner's room is on its left, "Main Unit" on its right)
        entrance = { floor = 1, x = 0.353, y = 0.160, angle = 180, labelPos = "top" },
        -- alcazstairs (2.0.9, M 16 Nov 2026): the stairs down to level 2, south
        -- of the crossroads, opened with Wrex's Keyring (his marked screenshot)
        transitions = {
            { floor = 1, to = 2, x = 0.330, y = 0.552, tipKey = "MAP_WREX_KEYRING" },
        },
        -- alcazpins (2.0.9): where the bosses are, from a player's marked map
        -- screenshots on Discord (falling/Ekiroth, 15 Nov 2026, "Bosses are
        -- there as shown; order like in game"), each on its room's centre.
        bosses = {
            { name = "Overseer Wrex",          floor = 1, x = 0.642, y = 0.338 }, -- the crescent room by Matarius Cell
            { name = "The Questioner",         floor = 1, x = 0.247, y = 0.173 }, -- the green room left of the entrance
            { name = "Tidemistress Ca'zass",   floor = 1, x = 0.355, y = 0.714 }, -- the purple crescent room, south
            { name = "Katerina the Cleaner",   floor = 2, x = 0.390, y = 0.715 }, -- the crescent room, south-west
            { name = "Blazeroar",              floor = 2, x = 0.661, y = 0.714 }, -- the great room, south-east
        },
    },
    ["Shaper's Terrace"] = {
        floors = { { texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\ShapersTerraceMap", texBottom = 683 / 1024 } },
        -- shaperpins (2.1.2, M 21 Nov 2026): the swirl by the small pond in the
        -- south-west (his screenshot: "the entrance is on this whirlwind, not
        -- the other one" - not the one on the west edge); its label below it
        -- ("if you put it on top, you cover the map").
        entrance = { floor = 1, x = 0.238, y = 0.693, angle = 0, labelPos = "bottom" },
        -- shaperpins: where the bosses are, from Ed's numbered map on Discord
        -- (21 Nov 2026), listed in his order 1-10.
        bosses = {
            { name = "Titanosaur",            floor = 1, x = 0.083, y = 0.404 }, -- 1, the Path of the Shaper
            { name = "Cinder",                floor = 1, x = 0.138, y = 0.629 }, -- 2
            { name = "Vitrix",                floor = 1, x = 0.510, y = 0.300 }, -- 3, Regrowth Vestibule
            { name = "Izha'Rel and Tor'Rel",  floor = 1, x = 0.645, y = 0.387 }, -- 4
            { name = "Direhorn Matriarch",    floor = 1, x = 0.846, y = 0.602 }, -- 5, by Isiz's Pillar
            { name = "Thunderhoof",           floor = 1, x = 0.628, y = 0.736 }, -- 6
            { name = "Bolt",                  floor = 1, x = 0.426, y = 0.702 }, -- 7
            { name = "Venomridge",            floor = 1, x = 0.373, y = 0.624 }, -- 8
            { name = "Snowtalon",             floor = 1, x = 0.107, y = 0.140 }, -- 9, Tribunal of Ages
            { name = "Nanaya",                floor = 1, x = 0.734, y = 0.590 }, -- 10, Pillar of Assimilation
        },
    },

    ["Gnomeregan"] = {
        -- Cataclysm-era client art; its skulls are patched out and our own
        -- portraits mark the Classic/Forever boss rooms instead.
        floors = {
            { uiMapID = 226, tiles = "Interface\\WorldMap\\Gnomeregan\\Gnomeregan1_", patches = { { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\Gnomeregan1_s1", x0 = 0.7595, y0 = 0.6452, x1 = 0.7934, y1 = 0.6961 } } },
            { uiMapID = 227, tiles = "Interface\\WorldMap\\Gnomeregan\\Gnomeregan2_", patches = { { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\Gnomeregan2_s1", x0 = 0.7435, y0 = 0.4431, x1 = 0.7774, y1 = 0.4940 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\Gnomeregan2_s2", x0 = 0.2275, y0 = 0.6587, x1 = 0.2615, y1 = 0.7096 } } },
            { uiMapID = 228, tiles = "Interface\\WorldMap\\Gnomeregan\\Gnomeregan3_", patches = { { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\Gnomeregan3_s1", x0 = 0.4172, y0 = 0.8578, x1 = 0.4511, y1 = 0.9087 } } },
            { uiMapID = 229, tiles = "Interface\\WorldMap\\Gnomeregan\\Gnomeregan4_", patches = { { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\Gnomeregan4_s1", x0 = 0.2984, y0 = 0.2740, x1 = 0.3323, y1 = 0.3249 } } },
        },
        entrance = { floor = 1, x = 0.642, y = 0.278, angle = 0 },
        -- Ladders: where each level continues (shared rooms between maps).
        transitions = {
            { floor = 1, to = 2, x = 0.545, y = 0.409, labelKey = "MAP_JUMP_LEVEL" }, -- Hall of Gears: jump down
            { floor = 1, to = 2, x = 0.487, y = 0.877 }, -- The Dormitory
            { floor = 2, to = 3, x = 0.435, y = 0.813 }, -- end of the corridor below the Launch Bay
            { floor = 3, to = 4, x = 0.370, y = 0.720 }, -- Engineering Labs
            { floor = 4, to = 3, x = 0.440, y = 0.726 }, -- corridor bend between Tinkers' Court and the Engineering Labs
        },
        bosses = {
            { name = "Grubbis",               floor = 1, x = 0.776, y = 0.671 },
            { name = "Viscous Fallout",       floor = 2, x = 0.760, y = 0.469 },
            { name = "Electrocutioner 6000",  floor = 2, x = 0.245, y = 0.684 },
            { name = "Crowd Pummeler 9-60",   floor = 3, x = 0.434, y = 0.883 },
            { name = "Mekgineer Thermaplugg", floor = 4, x = 0.315, y = 0.299 },
        },
    },
    ["Razorfen Kraul"] = {
        floors = { { uiMapID = 301, tiles = "Interface\\WorldMap\\RazorfenKraul\\RazorfenKraul1_", patches = { { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\RazorfenKraul1_s1", x0 = 0.2036, y0 = 0.2874, x1 = 0.2375, y1 = 0.3383 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\RazorfenKraul1_s2", x0 = 0.5589, y0 = 0.2874, x1 = 0.5928, y1 = 0.3383 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\RazorfenKraul1_s3", x0 = 0.8593, y0 = 0.3937, x1 = 0.8932, y1 = 0.4446 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\RazorfenKraul1_s4", x0 = 0.7914, y0 = 0.4955, x1 = 0.8253, y1 = 0.5464 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\RazorfenKraul1_s5", x0 = 0.0649, y0 = 0.6602, x1 = 0.0988, y1 = 0.7111 } } } },
        entrance = { floor = 1, x = 0.714, y = 0.840, angle = 180 },
        -- Ladder note (no level change): how to get across to Roogug. (The wall
        -- jump over the gate was taken out in 2.0.51: it no longer works.)
        transitions = {
            { floor = 1, x = 0.626, y = 0.562, note = true, labelKey = "MAP_RFK_VINE" },
        },
        bosses = {
            -- Roogug: alcove across the vine, first left after the entrance.
            { name = "Roogug",                 x = 0.646, y = 0.430 },
            { name = "Aggem Thorncurse",       x = 0.808, y = 0.521 },
            { name = "Death Speaker Jargba",   x = 0.876, y = 0.419 },
            { name = "Earthcaller Halmgar",    x = 0.498, y = 0.473 }, -- author's green mark
            { name = "Overlord Ramtusk",       x = 0.576, y = 0.313 },
            { name = "Charlga Razorflank",     x = 0.221, y = 0.313 },
            { name = "Agathelos the Raging",  x = 0.082, y = 0.686 },
        },
    },
    -- Loksey from Wowhead (zone 796 floor 2). Arcanist Doan has no published coordinates yet.
    ["Scarlet Monastery: Library"] = {
        floors = { { uiMapID = 303, tiles = "Interface\\WorldMap\\ScarletMonastery\\ScarletMonastery2_" } },
        bosses = {
            { name = "Houndmaster Loksey", x = 0.302, y = 0.846 },
            { name = "Arcanist Doan",      x = 0.835, y = 0.740 },
        },
    },
    -- Boss spots from Wowhead's map data (the same map art and coordinates the
    -- client uses). Whitemane waits in the round room behind the altar.
    ["Scarlet Monastery: Armory"] = {
        floors = { { uiMapID = 304, tiles = "Interface\\WorldMap\\ScarletMonastery\\ScarletMonastery3_" } },
        entrance = { floor = 1, x = 0.610, y = 0.945, angle = 0 },
        bosses = {
            { name = "Herod", x = 0.785, y = 0.118 },
        },
    },
    ["Scarlet Monastery: Cathedral"] = {
        floors = { { uiMapID = 305, tiles = "Interface\\WorldMap\\ScarletMonastery\\ScarletMonastery4_" } },
        entrance = { floor = 1, x = 0.618, y = 0.915, angle = 0 },
        bosses = {
            { name = "High Inquisitor Fairbanks",  x = 0.555, y = 0.250 },
            { name = "Scarlet Commander Mograine", x = 0.490, y = 0.285 },
            { name = "High Inquisitor Whitemane",  x = 0.490, y = 0.165 },
        },
    },
    -- Spots taken from the same encounters on Wowhead's map of this instance
    -- (Tuten'kash by the gong, Mordresh at the Bone Pile, Glutton on the
    -- spiral path, Amnennar on top of the Spiral of Thorns).
    ["Razorfen Downs"] = {
        floors = { { uiMapID = 300, tiles = "Interface\\WorldMap\\RazorfenDowns\\RazorfenDowns1_" } },
        entrance = { floor = 1, x = 0.234, y = 0.185, angle = 90 },
        bosses = {
            { name = "Tuten'kash",               x = 0.589, y = 0.342 },
            { name = "Mordresh Fire Eye",        x = 0.860, y = 0.467 },
            { name = "Glutton",                  x = 0.345, y = 0.664 },
            { name = "Amnennar the Coldbringer", x = 0.455, y = 0.582 },
        },
    },
    -- Uldaman and Zul'Farrak: boss spots from Wowhead's map data (same map art
    -- and coordinates as the client).
    ["Blackrock Depths"] = {
        floors = {
            { uiMapID = 242, tiles = "Interface\\WorldMap\\BlackrockDepths\\BlackrockDepths1_" },
            { uiMapID = 243, tiles = "Interface\\WorldMap\\BlackrockDepths\\BlackrockDepths2_" },
        },
        entrance = { floor = 1, x = 0.329, y = 0.794, angle = 0 }, -- the swirl in the Dark Iron Highway
        bosses = {
            { name = "High Interrogator Gerstahn", floor = 1, x = 0.474, y = 0.922 },
            { name = "Lord Roccor",                floor = 1, x = 0.556, y = 0.670 },
            { name = "Houndmaster Grebmar",        floor = 1, x = 0.535, y = 0.573 },
            { name = "Bael'Gar",                   floor = 1, x = 0.251, y = 0.534 },
            { name = "Lord Incendius",             floor = 1, x = 0.564, y = 0.311 },
            { name = "Fineous Darkvire",           floor = 1, x = 0.635, y = 0.211 },
            { name = "Gorosh the Dervish",         floor = 2, x = 0.530, y = 0.868 },
            { name = "Grizzle",                    floor = 2, x = 0.547, y = 0.883 },
            { name = "Eviscerator",                floor = 2, x = 0.547, y = 0.913 },
            { name = "Ok'thor the Breaker",        floor = 2, x = 0.530, y = 0.928 },
            { name = "Anub'shiah",                 floor = 2, x = 0.513, y = 0.913 },
            { name = "Hedrum the Creeper",         floor = 2, x = 0.513, y = 0.883 },
            { name = "Pyromancer Loregrain",       floor = 2, x = 0.549, y = 0.948 },
            { name = "Warder Stilgiss",            floor = 2, x = 0.602, y = 0.659 },
            { name = "General Angerforge",         floor = 2, x = 0.363, y = 0.823 },
            { name = "Golem Lord Argelmach",       floor = 2, x = 0.364, y = 0.651 },
            { name = "Hurley Blackbreath",         floor = 2, x = 0.505, y = 0.704 },
            { name = "Plugger Spazzring",          floor = 2, x = 0.477, y = 0.657 },
            { name = "Phalanx",                    floor = 2, x = 0.458, y = 0.564 },
            { name = "Ambassador Flamelash",       floor = 2, x = 0.538, y = 0.485 },
            { name = "The Seven",                  floor = 2, x = 0.538, y = 0.247 },
            { name = "Magmus",                     floor = 2, x = 0.796, y = 0.118 },
            { name = "Princess Moira Bronzebeard", floor = 2, x = 0.920, y = 0.110 },
            { name = "Emperor Dagran Thaurissan",  floor = 2, x = 0.909, y = 0.118 },
        },
    },
    ["Uldaman"] = {
        floors = {
            { uiMapID = 230, tiles = "Interface\\WorldMap\\Uldaman\\Uldaman1_" },
            { uiMapID = 231, tiles = "Interface\\WorldMap\\Uldaman\\Uldaman2_" },
        },
        entrance = { floor = 1, x = 0.679, y = 0.725, angle = 0 }, -- the swirl right of the Hall of the Keepers
        bosses = {
            { name = "The Lost Dwarves",     floor = 1, x = 0.584, y = 0.920 },
            { name = "Revelosh",             floor = 1, x = 0.534, y = 0.725 },
            { name = "Ironaya",              floor = 1, x = 0.372, y = 0.739 },
            -- sentinelpin (2.1.3, M 21 Nov 2026 on Level 1 of the map: "You need
            -- to put the obsidian sentinel pin on that skull"): the skull in
            -- Echomok Cavern, above the back entrance's swirl (read off his
            -- screenshot against Ancient Stone Keeper's, Ironaya's and Revelosh's pins)
            { name = "Obsidian Sentinel",    floor = 1, x = 0.287, y = 0.601 },
            { name = "Ancient Stone Keeper", floor = 1, x = 0.475, y = 0.440 },
            { name = "Galgann Firehammer",   floor = 1, x = 0.267, y = 0.327 },
            { name = "Grimlok",              floor = 1, x = 0.219, y = 0.256 },
            { name = "Archaedas",            floor = 2, x = 0.553, y = 0.504 },
        },
    },
    ["Zul'Farrak"] = {
        -- This client has no Zul'Farrak map, so the game's map art is bundled.
        floors = { { texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\ZulFarrakMap", texBottom = 683 / 1024 } },
        entrance = { floor = 1, x = 0.552, y = 0.880, angle = 0 },
        -- zfpins (2.0.13, M 19 Nov 2026, marked on his map): Theka the Martyr
        -- and Hydromancer Velratha added, Sergeant Bly on the spot Dustwraith
        -- had (Dustwraith off the map for now), Ruuzlu beside Chief Ukorz
        -- Sandscalp. pinspread: pins that would cover each other are moved
        -- apart to sit side by side (FDJ.SpreadMapPins).
        spreadPins = true,
        bosses = {
            { name = "Antu'sul",              x = 0.646, y = 0.276 },
            { name = "Witch Doctor Zum'rah",  x = 0.442, y = 0.176 },
            { name = "Shadowpriest Sezz'ziz", x = 0.296, y = 0.174 },
            { name = "Sergeant Bly",          x = 0.310, y = 0.160 },
            { name = "Theka the Martyr",      x = 0.528, y = 0.269 },
            { name = "Hydromancer Velratha",  x = 0.289, y = 0.366 },
            { name = "Gahz'rilla",            x = 0.312, y = 0.414 },
            { name = "Zerillis",              x = 0.548, y = 0.401 },
            { name = "Sandarr Dunereaver",    x = 0.524, y = 0.428 },
            { name = "Chief Ukorz Sandscalp", x = 0.422, y = 0.329 },
            { name = "Ruuzlu",                x = 0.423, y = 0.329 },
        },
    },
    ["Scarlet Monastery: Graveyard"] = {
        floors = { { uiMapID = 302, tiles = "Interface\\WorldMap\\ScarletMonastery\\ScarletMonastery1_", patches = { { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\ScarletMonastery1_s1", x0 = 0.2285, y0 = 0.5404, x1 = 0.2625, y1 = 0.5913 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\ScarletMonastery1_s2", x0 = 0.7066, y0 = 0.5749, x1 = 0.7405, y1 = 0.6257 } } } },
        entrance = { floor = 1, x = 0.841, y = 0.831, angle = 180 },
        bosses = {
            { name = "Interrogator Vishas", x = 0.724, y = 0.600 },
            { name = "Bloodmage Thalnos",   x = 0.246, y = 0.566 },
        },
    },
    ["Excavation Site: Wetlands"] = {
        floors = { { texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\ExcavationSiteMap", texBottom = 683 / 1024 } },
        entrance = { floor = 1, x = 0.888, y = 0.258, angle = 180, labelPos = "top" }, -- the swirl at the right of the map
        -- insidequest: quest NPCs inside (Warcraft Tavern's screenshots):
        -- Ardin Grassman up on the wooden tower by the Relic Guardian (just
        -- beside its portrait), Daewyn Songblade's body in a tent at the Lost
        -- Dig Site, by the dig and the bones.
        turnins = {
            { npc = "Ardin Grassman", x = 0.262, y = 0.668 },
            { npc = "Daewyn Songblade", x = 0.074, y = 0.497 },
        },
        -- Boss spots as marked by Exehn on the map (2026-10-06).
        -- questmob: Highland Horror is not a boss but the quest's target
        -- (Horrors in the Highland): its portrait carries the game's quest
        -- badge (the yellow ! of a quest mob's target portrait). Where
        -- Exehn fought it (2026-11-09): the path north of the Lost Dig Site
        -- (Wowhead has no spot for it).
        bosses = {
            { name = "Saltspine",       x = 0.550, y = 0.361 },
            { name = "Shadetooth",      x = 0.305, y = 0.484 },
            { name = "Relic Guardian",  x = 0.324, y = 0.687 },
            { name = "Highland Horror", x = 0.082, y = 0.405, npcID = 260808, quest = 95646 },
        },
    },
    ["Ragefire Chasm"] = {
        floors = { { uiMapID = 213, tiles = "Interface\\WorldMap\\Ragefire\\Ragefire1_", patches = { { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\Ragefire1_s1", x0 = 0.5259, y0 = 0.2725, x1 = 0.5599, y1 = 0.3234 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\Ragefire1_s2", x0 = 0.3752, y0 = 0.5584, x1 = 0.4092, y1 = 0.6093 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\Ragefire1_s3", x0 = 0.6806, y0 = 0.6213, x1 = 0.7146, y1 = 0.6722 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\Ragefire1_s4", x0 = 0.3253, y0 = 0.7904, x1 = 0.3593, y1 = 0.8413 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\Ragefire1_1", x0 = 0.0150, y0 = 0.0120, x1 = 0.5948, y1 = 0.1497 } } } },
        entrance = { floor = 1, x = 0.610, y = 0.075, angle = 200 },
        bosses = {
            { name = "Oggleflint",             x = 0.561, y = 0.378 },
            { name = "Taragaman the Hungerer", x = 0.405, y = 0.570 },
            { name = "Jergosh the Invoker",    x = 0.340, y = 0.815 },
            { name = "Bazzalan",               x = 0.422, y = 0.842 },
        },
    },
    ["The Deadmines"] = {
        -- Green "go to next level" arrows: where each level continues.
        transitions = {
            { floor = 1, to = 2, x = 0.615, y = 0.610 },
        },
        floors = {
            { uiMapID = 291, tiles = "Interface\\WorldMap\\TheDeadmines\\TheDeadmines1_", patches = { { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\TheDeadmines1_s1", x0 = 0.3313, y0 = 0.5898, x1 = 0.3653, y1 = 0.6407 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\TheDeadmines1_s2", x0 = 0.4721, y0 = 0.8413, x1 = 0.5060, y1 = 0.8922 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\TheDeadmines1_1", x0 = 0.3194, y0 = 0.0150, x1 = 0.6996, y1 = 0.1347 } } },
            { uiMapID = 292, tiles = "Interface\\WorldMap\\TheDeadmines\\TheDeadmines2_", patches = { { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\TheDeadmines2_s1", x0 = 0.1088, y0 = 0.7365, x1 = 0.1427, y1 = 0.7874 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\TheDeadmines2_s2", x0 = 0.5908, y0 = 0.3428, x1 = 0.6248, y1 = 0.3937 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\TheDeadmines2_s3", x0 = 0.5650, y0 = 0.4160, x1 = 0.6110, y1 = 0.4840, alpha = 1.0 } } },
        },
        entrance = { floor = 1, x = 0.295, y = 0.135, angle = -15 },
        bosses = {
            { name = "Rhahk'Zor",         floor = 1, x = 0.365, y = 0.610 },
            { name = "Miner Johnson",     floor = 1, x = 0.535, y = 0.520 },
            { name = "Sneed's Shredder",  floor = 1, x = 0.475, y = 0.865 },
            { name = "Sneed",             floor = 1, x = 0.535, y = 0.865 },
            { name = "Gilnid",            floor = 2, x = 0.122, y = 0.755 },
            { name = "Mr. Smite",         floor = 2, x = 0.515, y = 0.170 },
            { name = "Captain Greenskin", floor = 2, x = 0.575, y = 0.350 },
            { name = "Edwin VanCleef",    floor = 2, x = 0.605, y = 0.452 },
            { name = "Cookie",            floor = 2, x = 0.665, y = 0.430 },
        },
    },
    ["Wailing Caverns"] = {
        -- The game's own map of Wailing Caverns is the one from patch 4.1,
        -- after Blizzard cut the eastern maze out of the dungeon. Forever has
        -- the whole original cave, so the journal shows its own copy of the
        -- full map from before that patch (Media\\Maps\\WailingCavernsFull,
        -- 1002x668 in a 1024x1024 texture). The west half is the same on both,
        -- so its pins did not move.
        floors = { { uiMapID = 279, tiles = "Interface\\WorldMap\\WailingCaverns\\WailingCaverns1_",
            texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\Maps\\WailingCavernsFull", texRight = 1002 / 1024, texBottom = 668 / 1024 } },
        entrance = { floor = 1, x = 0.465, y = 0.590, angle = 200 },
        -- Route: Anacondra on the west side of the first big chamber, drop
        -- into the ravine west to Cobrahn, back through the river (Kresh),
        -- then into the eastern maze: Pythas up in the Winding Chasm, Skum by
        -- the pool in the far south-east, the Faerie Dragon's caves, and the
        -- rooms by the Crag of the Everliving where Serpentis stands right
        -- before Verdan. Mutanus appears at Naralex after the escort.
        -- Pythas and Skum sit on the full map's printed skulls in the east.
        bosses = {
            { name = "Lady Anacondra",        x = 0.310, y = 0.430 },
            { name = "Kresh",                 x = 0.385, y = 0.350 },
            { name = "Lord Cobrahn",          x = 0.155, y = 0.570 },
            { name = "Lord Pythas",           x = 0.856, y = 0.289 },
            { name = "Skum",                  x = 0.927, y = 0.792 },
            { name = "Deviate Faerie Dragon", x = 0.580, y = 0.600 },
            { name = "Lord Serpentis",        x = 0.615, y = 0.535 },
            { name = "Verdan the Everliving", x = 0.545, y = 0.460 },
            { name = "Mutanus the Devourer",  x = 0.345, y = 0.130 },
        },
    },
    ["Shadowfang Keep"] = {
        -- Three levels are shown: The Courtyard, The Wall Walk and Arugal's Chamber
        -- (map tiles 1, 7, 6). The Dining Hall page was removed at the author's request.
        -- Ladder positions are approximate.
        transitions = {
            { floor = 1, to = 2, x = 0.145, y = 0.864, dir = "up" }, -- stairs behind Baron Silverlaine, up to the wall walk
            { floor = 2, to = 3, x = 0.515, y = 0.915, dir = "up" }, -- from the terrace into the tower
        },
        floors = {
            { uiMapID = 310, tiles = "Interface\\WorldMap\\ShadowfangKeep\\ShadowfangKeep1_", patches = { { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\ShadowfangKeep1_s1", x0 = 0.2525, y0 = 0.5554, x1 = 0.2864, y1 = 0.6063 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\ShadowfangKeep1_s2", x0 = 0.6497, y0 = 0.6961, x1 = 0.6836, y1 = 0.7470 } } },
            { uiMapID = 316, tiles = "Interface\\WorldMap\\ShadowfangKeep\\ShadowfangKeep7_", patches = { { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\ShadowfangKeep7_s1", x0 = 0.5659, y0 = 0.8024, x1 = 0.5998, y1 = 0.8533 } } },
            { uiMapID = 315, tiles = "Interface\\WorldMap\\ShadowfangKeep\\ShadowfangKeep6_", patches = { { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\ShadowfangKeep6_s1", x0 = 0.6677, y0 = 0.3084, x1 = 0.7016, y1 = 0.3593 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\ShadowfangKeep6_s2", x0 = 0.5289, y0 = 0.6018, x1 = 0.5629, y1 = 0.6527 } } },
        },
        entrance = { floor = 1, x = 0.705, y = 0.605, angle = 0 },
        -- Deathstalkers in Shadowfang is handed in to Deathstalker Vincent,
        -- lying just inside the courtyard, right of the steps up from
        -- Rethilgore's jail (straight ahead of the entrance, past the gate).
        turnins = {
            { npc = "Deathstalker Vincent", floor = 1, x = 0.558, y = 0.622 },
        },
        -- Pins on a printed map marker sit exactly on it; the rest follow the
        -- boss positions published for the Forever client.
        bosses = {
            { name = "Rethilgore",                 floor = 1, x = 0.670, y = 0.715 },
            { name = "Fel Steed / Shadow Charger", floor = 1, x = 0.345, y = 0.635 },
            { name = "Razorclaw the Butcher",      floor = 1, x = 0.327, y = 0.447 },
            { name = "Baron Silverlaine",          floor = 1, x = 0.162, y = 0.807 },
            { name = "Deathsworn Captain",         floor = 2, x = 0.630, y = 0.525 },
            { name = "Odo the Blindwatcher",       floor = 2, x = 0.583, y = 0.828 },
            { name = "Fenrus the Devourer",        floor = 3, x = 0.546, y = 0.627 },
            { name = "Arugal's Voidwalker",        floor = 3, x = 0.492, y = 0.710 },
            { name = "Wolf Master Nandos",         floor = 3, x = 0.590, y = 0.533 },
            { name = "Archmage Arugal",            floor = 3, x = 0.685, y = 0.334 },
        },
    },
    ["The Stockade"] = {
        floors = { { uiMapID = 225, tiles = "Interface\\WorldMap\\TheStockade\\TheStockade1_", patches = { { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\TheStockade1_s1", x0 = 0.7685, y0 = 0.4311, x1 = 0.8024, y1 = 0.4820 } } } },
        entrance = { floor = 1, x = 0.500, y = 0.815, angle = 0 },
        bosses = {
            -- stockpins (2.0.10, M 16 Nov 2026): the rooms of his marked map,
            -- lined up with ours on the two round rooms; Targorr kept where he
            -- was (he walks several spots).
            { name = "Targorr the Dread",   x = 0.440, y = 0.445 },
            -- altspawn: the other spots he can stand in (his marked map)
            { name = "Targorr the Dread",   x = 0.499, y = 0.205, alt = true },
            { name = "Targorr the Dread",   x = 0.310, y = 0.413, alt = true },
            { name = "Targorr the Dread",   x = 0.569, y = 0.544, alt = true },
            { name = "Kam Deepfury",        x = 0.692, y = 0.288 },
            { name = "Hamhock",             x = 0.780, y = 0.457 },
            { name = "Bazil Thredd",        x = 0.864, y = 0.527 },
            { name = "Dextren Ward",        x = 0.215, y = 0.261 },
            { name = "Bruegal Ironknuckle", x = 0.291, y = 0.444 },
        },
    },
    ["Blackfathom Deeps"] = {
        transitions = {
            { floor = 1, to = 2, x = 0.615, y = 0.700 },
            { floor = 2, to = 3, x = 0.470, y = 0.700, labelKey = "MAP_SWIM_LEVEL" },
        },
        floors = {
            { uiMapID = 221, tiles = "Interface\\WorldMap\\BlackFathomDeeps\\BlackFathomDeeps1_", patches = { { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\BlackFathomDeeps1_s1", x0 = 0.0818, y0 = 0.3728, x1 = 0.1158, y1 = 0.4237 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\BlackFathomDeeps1_s2", x0 = 0.3114, y0 = 0.5793, x1 = 0.3453, y1 = 0.6302 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\BlackFathomDeeps1_s3", x0 = 0.5289, y0 = 0.5479, x1 = 0.5629, y1 = 0.5988 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\BlackFathomDeeps1_1", x0 = 0.2146, y0 = 0.0075, x1 = 0.4391, y1 = 0.1093 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\BlackFathomDeeps1_2", x0 = 0.4691, y0 = 0.0075, x1 = 0.8044, y1 = 0.1093 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\BlackFathomDeeps1_3", x0 = 0.4242, y0 = 0.0075, x1 = 0.4890, y1 = 0.0719 } } },
            { uiMapID = 222, tiles = "Interface\\WorldMap\\BlackFathomDeeps\\BlackFathomDeeps2_", patches = { { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\BlackFathomDeeps2_s1", x0 = 0.5090, y0 = 0.7934, x1 = 0.5429, y1 = 0.8443 }, { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\BlackFathomDeeps2_s2", x0 = 0.8263, y0 = 0.8398, x1 = 0.8603, y1 = 0.8907 } } },
            { uiMapID = 223, tiles = "Interface\\WorldMap\\BlackFathomDeeps\\BlackFathomDeeps3_", patches = { { tex = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapPatches\\BlackFathomDeeps3_s1", x0 = 0.5569, y0 = 0.2799, x1 = 0.5908, y1 = 0.3308 } } },
        },
        entrance = { floor = 1, x = 0.455, y = 0.085, angle = -20 },
        -- Quest objectives you click or loot on the spot (not kills / drops):
        -- now FDJ.MAP_QUEST_PINS (Data/QuestMaps.lua), with the other quests'.
        -- objectives = {
        --     { floor = 1, x = 0.330, y = 0.413, questID = 971, quest = "Knowledge in the Deeps", textKey = "MAP_OBJ_BFD_CHEST" },
        --     { floor = 2, x = 0.414, y = 0.754, questID = 6921, quest = "Amongst the Ruins", textKey = "MAP_OBJ_BFD_FATHOM" },
        -- },
        bosses = {
            { name = "Ghamoo-ra",            floor = 1, x = 0.325, y = 0.605 },
            { name = "Lady Sarevess",        floor = 1, x = 0.110, y = 0.385 },
            { name = "Gelihast",             floor = 1, x = 0.540, y = 0.575 },
            { name = "Lorgus Jett",          floor = 2, x = 0.325, y = 0.700 },
            -- altspawn (2.0.13, M 19 Nov 2026, the two spots he marked on the
            -- Level 2 map, up the northern channel): faded, "Can also spawn here"
            { name = "Lorgus Jett",          floor = 2, x = 0.385, y = 0.194, alt = true },
            { name = "Lorgus Jett",          floor = 2, x = 0.442, y = 0.231, alt = true },
            { name = "Baron Aquanis",        floor = 2, x = 0.420, y = 0.720, npcID = 12876 }, -- not a journal boss: portrait from its NPC ID
            { name = "Twilight Lord Kelris", floor = 2, x = 0.525, y = 0.810 },
            { name = "Aku'mai",              floor = 2, x = 0.855, y = 0.860 },
            { name = "Old Serra'kis",        floor = 3, x = 0.585, y = 0.290 },
        },
    },
    -- Maps added 1.6.5: client map art by UiMapID (floor order and boss spots
    -- from Wowhead's map data and the Classic spawn database, converted with
    -- the client's own UiMapAssignment regions).
    ["Dire Maul: North"] = {
        entrance = { floor = 1, x = 0.717, y = 0.924, angle = 0 },
        floors = { { uiMapID = 235, tiles = "Interface\\WorldMap\\DireMaul\\DireMaul1_" } }, -- Gordok Commons
        bosses = {
            { name = "Guard Mol'dar",          x = 0.695, y = 0.760 },
            { name = "Stomper Kreeg",          x = 0.612, y = 0.692 },
            { name = "Guard Fengus",           x = 0.494, y = 0.780 },
            { name = "Guard Slip'kik",         x = 0.266, y = 0.571 },
            { name = "Captain Kromcrush",      x = 0.318, y = 0.506 },
            { name = "Cho'Rush the Observer",  x = 0.300, y = 0.290 },
            { name = "King Gordok",            x = 0.319, y = 0.229 },
        },
    },
    ["Dire Maul: West"] = {
        entrance = { floor = 1, x = 0.935, y = 0.507, angle = 180, labelPos = "top" },
        floors = {
            { uiMapID = 236, tiles = "Interface\\WorldMap\\DireMaul\\DireMaul2_" }, -- Capital Gardens
            { uiMapID = 237, tiles = "Interface\\WorldMap\\DireMaul\\DireMaul3_" }, -- Court of the Highborne
            { uiMapID = 238, tiles = "Interface\\WorldMap\\DireMaul\\DireMaul4_" }, -- Prison of Immol'thar
        },
        bosses = {
            { name = "Tendris Warpwood",   floor = 1, x = 0.336, y = 0.536 },
            { name = "Illyanna Ravenoak",  floor = 1, x = 0.203, y = 0.776 },
            { name = "Magister Kalendris", floor = 2, x = 0.338, y = 0.450 },
            { name = "Tsu'zee",            floor = 2, x = 0.322, y = 0.143 },
            { name = "Immol'thar",         floor = 3, x = 0.349, y = 0.575 },
            { name = "Prince Tortheldrin", floor = 3, x = 0.622, y = 0.231 },
        },
    },
    ["Dire Maul: East"] = {
        entrance = { floor = 1, x = 0.281, y = 0.554, angle = 180 },
        floors = {
            { uiMapID = 240, tiles = "Interface\\WorldMap\\DireMaul\\DireMaul6_" }, -- The Shrine of Eldretharr
            { uiMapID = 239, tiles = "Interface\\WorldMap\\DireMaul\\DireMaul5_" }, -- Warpwood Quarter
        },
        bosses = {
            { name = "Lethtendris",           floor = 2, x = 0.438, y = 0.481 },
            { name = "Zevrim Thornhoof",      floor = 1, x = 0.575, y = 0.743 },
            { name = "Hydrospawn",            floor = 1, x = 0.536, y = 0.715 },
            { name = "Alzzin the Wildshaper", floor = 1, x = 0.566, y = 0.288 },
        },
    },
    ["Maraudon"] = {
        -- Two entrances (both on level 1), labelled by their portal colour.
        entrance = { floor = 1, x = 0.618, y = 0.281, angle = 0 },
        entrances = {
            { floor = 1, x = 0.618, y = 0.281, angle = 0, labelKey = "MAP_ENTRANCE_ORANGE", color = { 1.00, 0.55, 0.10 } },
            { floor = 1, x = 0.764, y = 0.659, angle = 0, labelKey = "MAP_ENTRANCE_PURPLE", color = { 0.78, 0.45, 1.00 } },
        },
        -- turninall: Celebras the Redeemed stands where Celebras the Cursed
        -- falls (quest tracker's ? button).
        turnins = {
            { npc = "Celebras the Redeemed", floor = 2, x = 0.245, y = 0.143 },
        },
        floors = {
            { uiMapID = 280, tiles = "Interface\\WorldMap\\Maraudon\\Maraudon1_" },
            { uiMapID = 281, tiles = "Interface\\WorldMap\\Maraudon\\Maraudon2_" },
        },
        bosses = {
            { name = "Noxxion",               floor = 1, x = 0.362, y = 0.098 },
            { name = "Razorlash",             floor = 1, x = 0.166, y = 0.344 },
            { name = "Lord Vyletongue",       floor = 1, x = 0.378, y = 0.704 },
            { name = "Meshlok the Harvester", floor = 1, x = 0.246, y = 0.874 },
            { name = "Celebras the Cursed",   floor = 2, x = 0.245, y = 0.143 },
            { name = "Landslide",             floor = 2, x = 0.408, y = 0.487 },
            { name = "Tinkerer Gizlock",      floor = 2, x = 0.484, y = 0.686 },
            { name = "Rotgrip",               floor = 2, x = 0.413, y = 0.817 },
            { name = "Princess Theradras",    floor = 2, x = 0.258, y = 0.788 },
        },
    },
    ["Stratholme: Living"] = {
        entrance = { floor = 1, x = 0.675, y = 0.877, angle = 0 },
        floors = { { uiMapID = 317, tiles = "Interface\\WorldMap\\Stratholme\\Stratholme1_" } },
        bosses = {
            { name = "Skul",                   x = 0.574, y = 0.652 },
            { name = "Hearthsinger Forresten", x = 0.605, y = 0.327 },
            { name = "The Unforgiven",         x = 0.734, y = 0.204 },
            { name = "Timmy the Cruel",        x = 0.495, y = 0.180 },
            { name = "Postmaster Malown",      x = 0.558, y = 0.684 },
            { name = "Cannon Master Willey",   x = 0.042, y = 0.510 },
            { name = "Archivist Galford",      x = 0.272, y = 0.750 },
            { name = "Balnazzar",              x = 0.204, y = 0.818 },
        },
    },
    ["Stratholme: Undead"] = {
        entrance = { floor = 1, x = 0.658, y = 0.902, angle = 0 },
        floors = { { uiMapID = 318, tiles = "Interface\\WorldMap\\Stratholme\\Stratholme2_" } },
        bosses = {
            { name = "Magistrate Barthilas", x = 0.566, y = 0.161 },
            { name = "Stonespine",           x = 0.649, y = 0.489 },
            { name = "Nerub'enkan",          x = 0.572, y = 0.461 },
            { name = "Baroness Anastari",    x = 0.745, y = 0.469 },
            { name = "Maleki the Pallid",    x = 0.674, y = 0.227 },
            { name = "Ramstein the Gorger",  x = 0.456, y = 0.198 },
            { name = "Baron Rivendare",      x = 0.372, y = 0.199 },
        },
    },
    -- scholomap (2.0.13): the game's own four-floor Scholomance map (uiMaps
    -- 306-309, "ScholomanceOLD": the Reliquary, the Chamber of Summoning,
    -- the Upper Study, the Headmaster's Study), drawn from the client like
    -- the other old dungeons. Pins: each boss's spawn in the CMaNGOS classic
    -- database, put on its floor with the client's UiMapAssignment regions
    -- (the same conversion lands the Stratholme pins on theirs). Kirtonos at
    -- the Brazier of the Herald on the porch where he is summoned; Gandling
    -- where the instance script summons him in the Headmaster's Study.
    -- 2.0.14 (M's screenshots of floors 1 and 3): the entrance on the map's
    -- whirlpool; the Upper Study's bosses on the printed skulls of their
    -- rooms (Polkelt: Hall of Secrets, Krastinov: Hall of the Damned,
    -- Malicia: The Coven); Rattlegore on the Great Ossuary's skull, which is
    -- on that floor; Jandice taken off (wrong spot) for now.
    ["Scholomance"] = {
        entrance = { floor = 1, x = 0.390, y = 0.652, angle = 0 },
        floors = {
            { uiMapID = 306, tiles = "Interface\\WorldMap\\ScholomanceOLD\\ScholomanceOLD1_" },
            { uiMapID = 307, tiles = "Interface\\WorldMap\\ScholomanceOLD\\ScholomanceOLD2_" },
            { uiMapID = 308, tiles = "Interface\\WorldMap\\ScholomanceOLD\\ScholomanceOLD3_" },
            { uiMapID = 309, tiles = "Interface\\WorldMap\\ScholomanceOLD\\ScholomanceOLD4_" },
        },
        bosses = {
            { name = "Kirtonos the Herald",      floor = 2, x = 0.495, y = 0.043 },
            { name = "Marduk Blackpool",         floor = 2, x = 0.444, y = 0.639 },
            { name = "Vectus",                   floor = 2, x = 0.482, y = 0.662 },
            { name = "Rattlegore",               floor = 3, x = 0.313, y = 0.646 },
            { name = "Instructor Malicia",       floor = 3, x = 0.721, y = 0.706 },
            { name = "Doctor Theolen Krastinov", floor = 3, x = 0.889, y = 0.462 },
            { name = "Lorekeeper Polkelt",       floor = 3, x = 0.720, y = 0.225 },
            { name = "Ras Frostwhisper",         floor = 4, x = 0.406, y = 0.884 },
            { name = "The Ravenian",             floor = 4, x = 0.675, y = 0.521 },
            { name = "Lord Alexei Barov",        floor = 4, x = 0.844, y = 0.308 },
            { name = "Lady Illucia Barov",       floor = 4, x = 0.670, y = 0.061 },
            { name = "Darkmaster Gandling",      floor = 4, x = 0.682, y = 0.302 },
        },
    },
    ["Upper Blackrock Spire"] = {
        -- ubrsmap (2.0.11, M 18 Nov 2026: "can we add this map without all the
        -- helper text but just with the right boss pins"): the Blackrock Spire
        -- parchment M sent, a guide's copy with its labels, arrows and route
        -- lines painted out (the halls' own names kept). Laid out as M asked:
        -- on the left the Hall of Binding and the Rookery above Dragonspire
        -- Hall (with the entrance); on the right the main spire (Hall of
        -- Blackhand to Spire Throne). Pins where that guide had them; Gyth
        -- just above Rend in the stadium, where Rend rides him in.
        floors = { { texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\UpperBlackrockSpireMap", texBottom = 683 / 1024 } },
        entrance = { floor = 1, x = 0.186, y = 0.855, angle = 0 }, -- the swirl at the foot of Dragonspire Hall
        -- maplinks (2.0.11, M's marked maps): two pairs of arrows; clicking
        -- one flashes the other. Pointing the way M drew them (angle: 0 =
        -- right, 90 = up). Green: up out of Dragonspire Hall (its top left
        -- room), right into the Hall of Binding (at the top). Blue: down out
        -- of the Rookery (its bottom left), up-right into the main spire (its
        -- west side).
        links = {
            { x = 0.104, y = 0.605, to = 2, angle = 90 },
            { x = 0.125, y = 0.160, to = 1, angle = 0 },
            { x = 0.128, y = 0.506, to = 4, angle = 270, color = { 0.30, 0.60, 1.00 } },
            { x = 0.345, y = 0.585, to = 3, angle = 45, color = { 0.30, 0.60, 1.00 } },
        },
        bosses = {
            { name = "Pyroguard Emberseer",     x = 0.131, y = 0.289 },
            { name = "Solakar Flamewreath",     x = 0.226, y = 0.416 },
            { name = "Jed Runewatcher",         x = 0.479, y = 0.438 },
            { name = "Goraluk Anvilcrack",      x = 0.430, y = 0.438 },
            { name = "Gyth",                    x = 0.615, y = 0.394 },
            { name = "Warchief Rend Blackhand", x = 0.615, y = 0.433 },
            { name = "The Beast",               x = 0.794, y = 0.506 },
            { name = "Lord Valthalak",          x = 0.807, y = 0.564 },
            { name = "General Drakkisath",      x = 0.459, y = 0.730 },
        },
    },
    ["Sunken Temple"] = {
        -- stmap (2.0.49): one map, the game's own Temple of Atal'Hakkar map
        -- (M's copy, 13 Nov 2026), in place of the five floors of 2.0.40. The
        -- skulls drawn on it: the four boss rooms and, round the ring, the
        -- six troll guardians (Gasher, Hukku, Loro, Mijan, Zolo, Zul'Lor).
        -- The pins sit on the skulls where there is one; the bosses with no
        -- skull of their own where they appear in the original dungeon:
        -- Atal'alarion in the middle of the pit, Dreamscythe and Weaver in
        -- the central room (after Jammal'an), Ogom beside Jammal'an.
        floors = { { texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\SunkenTempleMap", texBottom = 683 / 1024 } },
        entrance = { floor = 1, x = 0.499, y = 0.130, angle = 0 }, -- the north passage into the ring
        bosses = {
            { name = "Atal'alarion",           x = 0.499, y = 0.455 },
            { name = "Avatar of Hakkar",       x = 0.240, y = 0.453 },
            { name = "Jammal'an the Prophet",  x = 0.760, y = 0.454 },
            { name = "Ogom the Wretched",      x = 0.790, y = 0.395 },
            { name = "Dreamscythe & Weaver",   x = 0.500, y = 0.383 },
            { name = "Morphaz & Hazzas",       x = 0.498, y = 0.865 },
            { name = "Shade of Eranikus",      x = 0.666, y = 0.873 },
        },
        -- ststatues (2.0.6): the six serpent statues on the balconies over the
        -- pit, numbered in the order they must be used to bring Atal'alarion:
        -- South, North, Southwest, Southeast, Northwest, Northeast (Icy Veins,
        -- Warcraft Tavern, Wowhead; SOURCES.txt). Their balconies are a level
        -- below the troll guardians', turned a twelfth of a circle from them
        -- (Atlas' map): round the pit, between the troll guardians' skulls.
        -- ststatueart (2.0.6): drawn as the serpent statue itself (statue =
        -- true) with its number over its head; the west ones mirrored (flip)
        -- so all six face the pit; North a touch higher, clear of the
        -- Dreamscythe & Weaver pin.
        markers = {
            { n = 1, x = 0.4985, y = 0.5908, statue = true, titleKey = "ST_STATUE", dirKey = "ST_DIR_S", tipKey = "ST_STATUE_TIP", tipBoss = "Atal'alarion" },
            { n = 2, x = 0.4985, y = 0.3094, statue = true, titleKey = "ST_STATUE", dirKey = "ST_DIR_N", tipKey = "ST_STATUE_TIP", tipBoss = "Atal'alarion" },
            { n = 3, x = 0.4207, y = 0.5234, statue = true, flip = true, titleKey = "ST_STATUE", dirKey = "ST_DIR_SW", tipKey = "ST_STATUE_TIP", tipBoss = "Atal'alarion" },
            { n = 4, x = 0.5763, y = 0.5234, statue = true, titleKey = "ST_STATUE", dirKey = "ST_DIR_SE", tipKey = "ST_STATUE_TIP", tipBoss = "Atal'alarion" },
            { n = 5, x = 0.4207, y = 0.3887, statue = true, flip = true, titleKey = "ST_STATUE", dirKey = "ST_DIR_NW", tipKey = "ST_STATUE_TIP", tipBoss = "Atal'alarion" },
            { n = 6, x = 0.5763, y = 0.3887, statue = true, titleKey = "ST_STATUE", dirKey = "ST_DIR_NE", tipKey = "ST_STATUE_TIP", tipBoss = "Atal'alarion" },
        },
    },
}

-- maplinks (2.0.11, M 18 Nov 2026, Upper Blackrock Spire: "add arrows that
-- point to the other location, 1 connects to 2, and 2 to the last one, they
-- don't have to switch page, just when clicking on arrow 1 it highlights
-- arrow 2"): data.links = { { x, y, to = n, color }, ... }, n the arrow it
-- leads to. Each arrow (green, like the level arrows, or its own color)
-- points at its angle, else at the one it leads to; clicking it makes that
-- one light up three times.
FDJ.RenderMapLinks = function(holder, data, floorIndex, artW, artH, baseH)
    if not frame then return end
    frame.dungeonMapLinks = frame.dungeonMapLinks or {}
    local arrows, links, shown, byIndex = frame.dungeonMapLinks, (data and data.links) or {}, 0, {}
    local ART = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MapLinkArrow"
    for i, lk in ipairs(links) do
        if (lk.floor or 1) == floorIndex then
            shown = shown + 1
            local a = arrows[shown]
            if not a then
                a = CreateFrame("Button", nil, holder)
                a.icon = a:CreateTexture(nil, "ARTWORK")
                a.icon:SetTexture(ART)
                a.icon:SetAllPoints()
                -- The flash: the arrow itself lit up, its own size (M: "only
                -- the arrow itself highlight, not an extra outside glow").
                a.glow = a:CreateTexture(nil, "OVERLAY")
                a.glow:SetTexture(ART)
                a.glow:SetAllPoints()
                a.glow:SetBlendMode("ADD")
                a.glow:SetVertexColor(1.00, 0.90, 0.45)
                a.icon:SetVertexColor(0.35, 1.00, 0.35)
                a.hl = a:CreateTexture(nil, "HIGHLIGHT")
                a.hl:SetTexture(ART)
                a.hl:SetAllPoints()
                a.hl:SetBlendMode("ADD")
                a.hl:SetAlpha(0.45)
                a:SetScript("OnClick", function(self)
                    local target = self.target and frame.dungeonMapLinkByIndex and frame.dungeonMapLinkByIndex[self.target]
                    if target and FDJ.PulseMapLink then FDJ.PulseMapLink(target) end
                end)
                arrows[shown] = a
            end
            if a:GetParent() ~= holder then a:SetParent(holder) end
            local size = math.max(20, math.floor(baseH * 0.07))
            a:SetSize(size, size)
            local c = type(lk.color) == "table" and lk.color or nil -- green unless the link says
            a.icon:SetVertexColor(c and c[1] or 0.35, c and c[2] or 1.00, c and c[3] or 0.35)
            a:SetFrameLevel(holder:GetFrameLevel() + 16)
            a:ClearAllPoints()
            a:SetPoint("CENTER", holder, "TOPLEFT", lk.x * artW, -(lk.y * artH))
            -- The art points up; turn it to the link's angle (0 = right,
            -- 90 = up), else towards the arrow it leads to.
            local to, rot = links[lk.to], 0
            if lk.angle then
                rot = math.rad(lk.angle) - math.pi / 2
            elseif to then
                rot = math.atan2(-(to.y - lk.y) * artH, (to.x - lk.x) * artW) - math.pi / 2
            end
            for _, t in ipairs({ a.icon, a.glow, a.hl }) do
                if t.SetRotation then t:SetRotation(rot) end
            end
            a.target = lk.to
            a:SetScript("OnUpdate", nil)
            a.glow:SetAlpha(0)
            byIndex[i] = a
            a:Show()
        end
    end
    frame.dungeonMapLinkByIndex = byIndex
    for i = shown + 1, #arrows do arrows[i]:Hide() end
end
-- Three gold flashes over about two and a half seconds.
FDJ.PulseMapLink = function(a)
    a.pulse = 0
    a:SetScript("OnUpdate", function(self, elapsed)
        self.pulse = (self.pulse or 0) + elapsed
        if self.pulse >= 2.4 then
            self.glow:SetAlpha(0)
            self:SetScript("OnUpdate", nil)
            return
        end
        self.glow:SetAlpha(0.5 - 0.5 * math.cos(self.pulse * 7.854))
    end)
end

local function LanguageDisplayName(locale)
    for _, info in ipairs(LANGUAGE_CHOICES) do
        if info.locale == locale then return info.label end
    end
    return "English"
end

local function GetLanguageIndex(locale)
    for i, info in ipairs(LANGUAGE_CHOICES) do
        if info.locale == locale then return i end
    end
    return 1
end

local function UpdateLanguageControl()
    if not frame or not frame.languageSelectorText then return end
    local active = FDJ.GetLanguage and FDJ.GetLanguage() or "enUS"
    frame.languageSelectorText:SetText(LanguageDisplayName(active))
end


local function UpdateQuestActionButtonSizes()
    if not frame then return end

    if frame.questMapButton then
        local mapText = frame.questMapButton.fdjCustomLabel or L(frame.questMapButton.fdjLabelKey or "SHOW_ON_MAP") or ""
        frame.questMapButton:SetText(mapText)
        local fs = frame.questMapButton:GetFontString()
        local textWidth = fs and fs:GetStringWidth() or 0
        local iconPad = (frame.questMapButton.icon and frame.questMapButton.icon:IsShown()) and 20 or 0
        local width = math.max(96, math.min((frame.questMapButton.fdjLabelKey or frame.questMapButton.fdjCustomLabel) and 210 or 150, math.ceil(textWidth + 24 + iconPad)))
        frame.questMapButton:SetWidth(width)
    end

    if frame.questTurninMapButton then
        frame.questTurninMapButton:SetText(L("SHOW_TURN_IN") or "")
        local fs = frame.questTurninMapButton:GetFontString()
        local textWidth = fs and fs:GetStringWidth() or 0
        frame.questTurninMapButton:SetWidth(math.max(96, math.min(210, math.ceil(textWidth + 24 + 20))))
    end

    if frame.questChainButton then
        local chainText = L("SHOW_QUEST_CHAIN") or ""
        frame.questChainButton:SetText(chainText)
        local fs = frame.questChainButton:GetFontString()
        local textWidth = fs and fs:GetStringWidth() or 0
        local width = math.max(112, math.min(170, math.ceil(textWidth + 40)))
        frame.questChainButton:SetWidth(width)
        if frame.questChainButton.icon then
            frame.questChainButton.icon:ClearAllPoints()
            frame.questChainButton.icon:SetPoint("RIGHT", -7, 0)
        end
        if fs then
            fs:ClearAllPoints()
            fs:SetPoint("CENTER", frame.questChainButton, "CENTER", -9, 0)
        end
    end
end

local function ApplyLocaleFontTree(root)
    -- Intentionally left as a no-op. All localized FontStrings now keep their
    -- native Blizzard font objects. Previous runtime font swapping for Chinese
    -- could leak font file/size state into other languages after switching.
    -- With Chinese disabled for this release, mutating fonts at runtime is both
    -- unnecessary and less stable than leaving Blizzard's font objects intact.
    return
end

local compareTooltip1
local compareTooltip2
local dungeonTabs = {}
local bossButtons = {}
local lootRows = {}
local questButtons = {}
local questRewardButtons = {}
local questNoteRewardButtons = {}
local visibleQuestIndexes = {}
local journalCache = {}
-- v0.7.0 could save a previous creature's display under the next NPC's ID.
-- Discard only that derived cache once; keep all user settings.
-- (3, 2.0.13: the arrow could save Magister Kirandis's face as Mithera's: once more)
if ForeverDungeonJournalDB.portraitCacheVersion ~= 4 then
    ForeverDungeonJournalDB.displayIDs = {}
    ForeverDungeonJournalDB.portraitCacheVersion = 4
end
ForeverDungeonJournalDB.displayIDs = ForeverDungeonJournalDB.displayIDs or {}

local displayIDCache = ForeverDungeonJournalDB.displayIDs

-- Exact 2D unit portraits captured from the client, keyed ONLY by numeric NPC ID.
-- This avoids comparing UnitName() values (which can be secret strings in Forever)
-- and cannot accidentally assign one boss portrait to another boss by name.
ForeverDungeonJournalDB.portraitTexturesByNpcID = ForeverDungeonJournalDB.portraitTexturesByNpcID or {}
local portraitTexturesByNpcID = ForeverDungeonJournalDB.portraitTexturesByNpcID
-- v1.0.21 removes live target/mouseover boss learning entirely.
-- Clear the two stale learning tables so an old bad portrait (notably Lordaeron Captain)
-- can never override the deterministic bundled portrait again.
ForeverDungeonJournalDB.learnedNpcIDs = nil
ForeverDungeonJournalDB.portraitFileIDs = nil

local function BossNpcID(boss)
    if not boss then return nil end
    -- Boss identity is deterministic: only IDs bundled in the addon are used.
    -- We no longer learn NPC IDs from target/mouseover/nameplates.
    return boss.npcID
end

-- Portraits are deterministic in v1.0.22. Legacy bosses use bundled
-- CreatureDisplayIDs; Forever bosses use Blizzard Encounter Journal display data
-- when available, plus bundled fallback art where needed. No live unit learning.
local portraitResolver
local portraitResolveQueue = {}
local portraitResolveQueued = {}
local portraitResolveCurrent
local portraitResolveSerial = 0
local portraitModels = {}
local portraitRetryAt = {}
local portraitResolveBlockedUntil = 0

-- Direct 2D boss portraits. These CreatureDisplayIDs are bundled with the
-- addon so legacy dungeon bosses never need PlayerModel:SetCreature() or any
-- hidden 3D model work. Forever-specific bosses use Encounter Journal display
-- data or explicit bundled portrait art.
-- ============================================================
-- BASIC HELPERS
-- ============================================================

local function SetBackdrop(f, bg, border, edge, inset)
    f:SetBackdrop({
        bgFile = bg,
        edgeFile = border,
        tile = true,
        tileSize = 16,
        edgeSize = edge or 12,
        insets = {
            left = inset or 3,
            right = inset or 3,
            top = inset or 3,
            bottom = inset or 3,
        },
    })
end

local function AddClassicParchment(frameObj, alpha, r, g, b)
    local tex = frameObj:CreateTexture(nil, "BACKGROUND", nil, -2)
    tex:SetPoint("TOPLEFT", 3, -3)
    tex:SetPoint("BOTTOMRIGHT", -3, 3)
    tex:SetTexture("Interface\\QuestFrame\\QuestBG")
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetVertexColor(r or 1, g or 0.96, b or 0.84)
    tex:SetAlpha(alpha or 0.16)
    return tex
end

local function ItemInfo(id)
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(id)
    end
end

local function ItemIcon(id)
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, icon = C_Item.GetItemInfoInstant(id)
        if icon then return icon end
    end

    if C_Item and C_Item.GetItemIconByID then
        local icon = C_Item.GetItemIconByID(id)
        if icon then return icon end
    end

    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- qualityfix (2.0.6): the Forever client (Interface 16001) has no global
-- GetItemQualityColor any more (it moved to C_Item.GetItemQualityColor), so
-- every colour asked for here fell through to the blue at the end: green
-- quest items (Frayed Abomination Stitching, Essence of Eranikus) read blue.
-- Ask C_Item first, then the old global, then ITEM_QUALITY_COLORS, then the
-- standard colours below; blue stays the last resort.
FDJ.QUALITY_RGB = FDJ.QUALITY_RGB or {
    [0] = { 0.62, 0.62, 0.62 }, -- poor (grey)
    [1] = { 1.00, 1.00, 1.00 }, -- common (white)
    [2] = { 0.12, 1.00, 0.00 }, -- uncommon (green)
    [3] = { 0.00, 0.44, 0.87 }, -- rare (blue)
    [4] = { 0.64, 0.21, 0.93 }, -- epic (purple)
    [5] = { 1.00, 0.50, 0.00 }, -- legendary (orange)
    [6] = { 0.90, 0.80, 0.50 }, -- artifact
    [7] = { 0.00, 0.80, 1.00 }, -- heirloom
}
local function QualityColor(q)
    q = tonumber(q) or 3
    if C_Item and type(C_Item.GetItemQualityColor) == "function" then
        local ok, r, g, b = pcall(C_Item.GetItemQualityColor, q)
        if ok and type(r) == "number" then return r, g, b end
    end
    if type(GetItemQualityColor) == "function" then
        local ok, r, g, b = pcall(GetItemQualityColor, q)
        if ok and type(r) == "number" then return r, g, b end
    end
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
    local rgb = FDJ.QUALITY_RGB[q]
    if rgb then return rgb[1], rgb[2], rgb[3] end
    return 0, 0.44, 0.87
end

-- redlevel (2.1.1, M 20 Nov 2026: "if a quest is too high level ... and you
-- cannot pick it up, I want the level number to be red"): the level for
-- "Available from Level %s", red while the character is below it (a darker
-- red on the parchment pages).
FDJ.QuestLevelText = function(required, onParchment)
    local need = tonumber(required)
    if not need then return tostring(required or "") end
    local okL, level = pcall(UnitLevel, "player")
    level = okL and tonumber(level) or nil
    if level and level > 0 and level < need then
        return (onParchment and "|cffc41414" or "|cffff3030") .. need .. "|r"
    end
    return tostring(need)
end

-- redlevelbold (2.1.1, M 20 Nov 2026: "it's a little hard to read the level
-- requirement when it's red in the dungeon page. Give it a slight black
-- stroke and make it bold"): on the quest page (the parchment) the red level
-- is drawn again over itself, a size up with a thin black outline (a line's
-- outline is for all of its text, so the number gets its own). It follows
-- the line's text (a hook on its SetText) and is left out when the line
-- wraps.
FDJ.MarkRedLevel = function(meta, text)
    if not meta or not meta.GetParent then return end
    local mark = meta.fdjRedLevel
    local s, e = nil, nil
    if type(text) == "string" then s, e = text:find("|cffc41414", 1, true) end
    local close = e and text:find("|r", e + 1, true)
    if not close then
        if mark then mark:Hide() end
        return
    end
    local parent = meta:GetParent()
    if not mark then
        mark = parent:CreateFontString(nil, "OVERLAY")
        mark:SetDrawLayer("OVERLAY", 7)
        mark:SetJustifyH("LEFT")
        meta.fdjRedLevel = mark
        meta.fdjRedMeasure = parent:CreateFontString(nil, "OVERLAY")
        meta.fdjRedMeasure:Hide()
    end
    local file, size, flags = meta:GetFont()
    if not file then mark:Hide() return end
    local measure = meta.fdjRedMeasure
    measure:SetFont(file, size, flags or "")
    measure:SetText(text:sub(1, s - 1))
    local x = measure:GetStringWidth() or 0
    if (meta.GetNumLines and (meta:GetNumLines() or 1) > 1) then mark:Hide() return end
    pcall(mark.SetFont, mark, file, (tonumber(size) or 12) + 1, "OUTLINE")
    mark:SetShadowOffset(0, 0)
    mark:SetTextColor(0.92, 0.12, 0.10)
    mark:SetText(text:sub(e + 1, close - 1))
    mark:ClearAllPoints()
    mark:SetPoint("LEFT", meta, "LEFT", x, 0)
    mark:Show()
end

FDJ.StartsInsideDungeon = function(pickupText)
    if type(pickupText) ~= "string" then return false end
    local text = string.lower(pickupText)
    return text:find("inside ", 1, true) ~= nil
end

-- insidequest: handed in inside the dungeon: "..., inside Shadowfang Keep",
-- or the place after the last comma is the dungeon itself ("Baelog,
-- Uldaman"); never "just outside".
FDJ.TurnInInsideDungeon = function(turninText, dungeonName)
    if type(turninText) ~= "string" or turninText == "" then return false end
    local text = string.lower(turninText)
    if text:find("outside", 1, true) then return false end
    if text:find("inside", 1, true) then return true end
    if type(dungeonName) ~= "string" then return false end
    local place = text:match(",%s*([^,]-)%s*$")
    if not place or place == "" then return false end
    local name = string.lower(dungeonName)
    return place == name or place == name:match("^(.-):")
end

-- A chain step done inside the dungeon: handed in there, or its objective
-- says inside / within this dungeon (The Horn of Xelthos: "inside of
-- Shadowfang Keep", not on the Scarlet Monastery's pages).
-- A step counts when any part of it is done in this dungeon: its objective
-- names the dungeon ("Find the forge in the Deadmines"), or one of its items
-- comes from there ("Jordan's Hammer, Shadowfang Keep courtyard"; an item
-- one of its bosses drops). Not "outside" / "near" the dungeon.
-- details.objectiveInDungeon = true / false settles it by hand.
FDJ.ObjectiveInsideDungeonIn = function(details, dungeonName)
    if type(details) ~= "table" then return false end
    if details.objectiveInDungeon ~= nil then return details.objectiveInDungeon == true end
    if FDJ.TurnInInsideDungeon(details.turnin, dungeonName) then return true end
    if type(dungeonName) ~= "string" then return false end
    local name = string.lower(dungeonName)
    name = (name:match("^(.-):") or name):gsub("^the ", "")
    local function Names(text)
        if type(text) ~= "string" then return false end
        text = string.lower(text)
        if not text:find(name, 1, true) then return false end
        if text:find("inside", 1, true) or text:find("within", 1, true) then return true end
        return not (text:find("outside", 1, true) or text:find("near ", 1, true)
            or text:find("entrance", 1, true))
    end
    if Names(details.objective) then return true end
    local items = details.requiredItems
    if type(items) ~= "table" then return false end
    local drops
    for _, item in ipairs(items) do
        if type(item) == "table" then
            if Names(item[4]) then return true end
            local id = tonumber(item[1])
            if id and id > 0 then
                if not drops then
                    drops = {}
                    local dungeon = DB[dungeonName]
                    for _, boss in ipairs(type(dungeon) == "table" and dungeon.bosses or {}) do
                        for _, loot in ipairs(type(boss) == "table" and boss.loot or {}) do
                            if type(loot) == "table" and tonumber(loot[1]) then drops[tonumber(loot[1])] = true end
                        end
                    end
                end
                if drops[id] then return true end
            end
        end
    end
    return false
end

-- anydungeon (2.1.1, M 20 Nov 2026 at A Crumpled Up Note on the Onyxia
-- Attunement page: "it starts from the item that drops in dungeons ... if it
-- drops from an item inside, it's obviously a dungeon step"): on a quest
-- chain page of its own (Onyxia Attunement), which is no dungeon, a step
-- done inside any dungeon counts.
FDJ.ObjectiveInsideDungeon = function(details, dungeonName)
    local page = type(dungeonName) == "string" and DB[dungeonName]
    if type(page) == "table" and page.questChainPage and type(details) == "table" and details.objectiveInDungeon == nil then
        if FDJ.TurnInInsideDungeon(details.turnin, dungeonName) then return true end
        for name, dungeon in pairs(DB) do
            if type(dungeon) == "table" and not dungeon.questChainPage and FDJ.ObjectiveInsideDungeonIn(details, name) then return true end
        end
        return false
    end
    return FDJ.ObjectiveInsideDungeonIn(details, dungeonName)
end

-- dungeontint (2.1.1, M 20 Nov 2026: "should we maybe give the teal color to
-- every single main quest? We don't need to type in dungeon step, that's only
-- for the chain steps"): the page tinted with the In Dungeon icon's teal,
-- strongest at the top. On a dungeon's own quests and on its chain steps done
-- inside; not on the other chain steps nor the Onyxia / Sleeping Bag pages.
FDJ.ShowDungeonFade = function(on)
    if not frame then return end
    frame.questDungeonFadeWanted = on and true or false
    -- notint (2.1.1, M 20 Nov 2026: "I really don't want to ship the color to
    -- quests because I feel like people are gonna get confused", then "we
    -- should keep the teal color for the dungeon chain steps"): only a
    -- dungeon chain step's page is tinted (PlaceDungeonStepLabel); a
    -- dungeon's own quests keep the plain page (RefreshQuestDetail).
    -- (Use Standard Quest Colour removed, M 20 Nov 2026: "remove use
    -- standard quest color in the quest tab")
    local fade = frame.questDungeonFade
    if on and not fade and frame.questTextInset then
        -- (over the page's backdrop, which covers the BACKGROUND layer; under
        -- its text and lines)
        fade = frame.questTextInset:CreateTexture(nil, "ARTWORK", nil, -8)
        fade:SetPoint("TOPLEFT", 4, -4)
        fade:SetPoint("BOTTOMRIGHT", -4, 4)
        fade:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.questDungeonFade = fade
    end
    if fade and on then
        -- the In Dungeon icon's teal on every dungeon (M 20 Nov 2026, after
        -- trying each dungeon's own colour: "the teal was way cleaner"):
        -- strong under the title, light at the bottom
        local r, g, b = 0.10, 0.62, 0.66
        local key = string.format("%.3f %.3f %.3f", r, g, b)
        if fade.fdjTint ~= key then
            fade.fdjTint = key
            local okG = type(CreateColor) == "function" and pcall(fade.SetGradient, fade, "VERTICAL", CreateColor(r, g, b, 0.14), CreateColor(r, g, b, 0.62))
            if not okG then
                okG = fade.SetGradientAlpha and pcall(fade.SetGradientAlpha, fade, "VERTICAL", r, g, b, 0.14, r, g, b, 0.62)
            end
            if not okG then fade:SetVertexColor(r, g, b, 0.30) end
        end
    end
    if fade then fade:SetShown(on and true or false) end
end
-- noteimage (2.1.3, M 21 Nov 2026, by the Ancient Chest outside Uldaman,
-- with his minimap: "If you could somehow put this minimap ... below in the
-- notes ... the black dot is where the quest is made"): a picture under a
-- quest's Notes (noteImage = { file = texture, size = pixels, caption =
-- English text, translated as free text }). nil: hidden.
FDJ.PlaceNoteImage = function(image, cursorY)
    cursorY = cursorY or 0
    if not frame or not frame.questDetailContent then return cursorY end
    local box = frame.questNoteImage
    if type(image) ~= "table" or type(image.file) ~= "string" then
        if box then box:Hide() end
        return cursorY
    end
    if not box then
        box = CreateFrame("Frame", nil, frame.questDetailContent)
        box.art = box:CreateTexture(nil, "ARTWORK")
        box.art:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
        box.caption = box:CreateFontString(nil, "OVERLAY")
        box.caption:SetJustifyH("LEFT")
        box.caption:SetJustifyV("TOP")
        box.caption:SetWordWrap(true)
        frame.questNoteImage = box
    end
    local size = tonumber(image.size) or 190
    local width = math.max(120, (frame.questDetailContent:GetWidth() or 360) - 8)
    box.art:SetTexture(image.file)
    box.art:SetSize(size, size)
    -- (M 21 Nov 2026: "I don't want you to show the black dot ... replace the
    -- black dot with the actual icon of the quest"): marks = { { x, y, item } },
    -- the place on the picture (0 to 1 from its top left) where the quest's
    -- item icon goes, inside the gold ring drawn there.
    box.marks = box.marks or {}
    for i, mark in ipairs(type(image.marks) == "table" and image.marks or {}) do
        local icon = box.marks[i]
        if not icon then
            icon = box:CreateTexture(nil, "OVERLAY")
            icon.fdjRound = pcall(icon.SetMask, icon, "Interface\\CharacterFrame\\TempPortraitAlphaMask")
            box.marks[i] = icon
        end
        local file
        local id = tonumber(mark.item)
        if id then
            if C_Item and type(C_Item.GetItemIconByID) == "function" then file = C_Item.GetItemIconByID(id) end
            if not file and type(GetItemIcon) == "function" then file = GetItemIcon(id) end
        end
        icon:SetTexture(file or mark.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        -- (a texture with a mask refuses SetTexCoord: "Cannot set tex coords when
        -- texture has mask", M's error 21 Nov 2026; the round mask crops the
        -- icon's border by itself)
        if not icon.fdjRound then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        local px = math.floor(size * (icon.fdjRound and 22 or 16) / 190 + 0.5)
        icon:SetSize(px, px)
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", box.art, "TOPLEFT", (tonumber(mark.x) or 0.5) * size, -(tonumber(mark.y) or 0.5) * size)
        icon:Show()
    end
    for i = (type(image.marks) == "table" and #image.marks or 0) + 1, #box.marks do box.marks[i]:Hide() end
    local font, height, flags
    if frame.questNotesText and frame.questNotesText.GetFont then font, height, flags = frame.questNotesText:GetFont() end
    if font then box.caption:SetFont(font, math.max(9, (height or 12) - 1), flags) else box.caption:SetFontObject("GameFontHighlightSmall") end
    box.caption:SetTextColor(0.10, 0.065, 0.025)
    box.caption:SetWidth(width)
    box.caption:ClearAllPoints()
    box.caption:SetPoint("TOPLEFT", box.art, "BOTTOMLEFT", 0, -4)
    local caption = image.caption and (FDJ.LocalizeFreeText and FDJ.LocalizeFreeText(image.caption) or image.caption) or ""
    box.caption:SetText(caption)
    local captionHeight = caption ~= "" and ((box.caption:GetStringHeight() or 14) + 4) or 0
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -(cursorY + 6))
    box:SetSize(width, size + captionHeight)
    box.fdjY = cursorY + 6 -- showlocation: where Show Location scrolls to
    box:SetScript("OnUpdate", nil)
    box:SetAlpha(1)
    box:Show()
    return cursorY + 6 + size + captionHeight + 12
end

-- (plainquest) the option switched: the page open now follows it.
FDJ.ReapplyDungeonFade = function()
    if frame then FDJ.ShowDungeonFade(frame.questDungeonFadeWanted) end
end

-- dungeonstep (2.1.1, M 20 Nov 2026: "once we reach the actual step that's
-- in the dungeon, I want it to be a bit clearer that we are there ... a
-- disclaimer above the objective saying dungeon step in blue with black
-- stroke, bold ... and the whole page to have a teal fade, a fade into the
-- in dungeon icon color"): a chain step's page, when the step is done or
-- started inside the dungeon (the same as its In Dungeon icons): "DUNGEON
-- STEP" over its Objective, and the page tinted with the icon's teal,
-- strongest at the top. show false: neither (any other page).
FDJ.PlaceDungeonStepLabel = function(show, cursorY)
    cursorY = cursorY or 0
    if not frame then return cursorY end
    if not FDJ.dungeonStepStrings then
        FDJ.dungeonStepStrings = {
            -- chainstep (2.1.1, M 20 Nov 2026: "change the text to dungeon
            -- chain step"; the chain icon before it)
            enUS = "Dungeon Chain Step", deDE = "Dungeon-Kettenschritt", frFR = "Étape de chaîne de donjon",
            esES = "Paso de cadena de mazmorra", itIT = "Passo della catena nella spedizione",
            ptBR = "Etapa da cadeia na masmorra", ruRU = "Этап цепочки в подземелье",
            koKR = "던전 연계 퀘스트 단계", zhCN = "地下城任务链步骤", zhTW = "地城任務鏈步驟",
        }
        FDJ.dungeonStepStrings.esMX = FDJ.dungeonStepStrings.esES
        for locale, text in pairs(FDJ.dungeonStepStrings) do
            local t = FDJ.Locales and FDJ.Locales[locale]
            if t and t.DUNGEON_STEP == nil then t.DUNGEON_STEP = text end
        end
    end
    FDJ.ShowDungeonFade(show)
    local label = frame.questDungeonStepText
    if not show then
        if label then label:Hide() end
        if frame.questDungeonStepIcon then frame.questDungeonStepIcon:Hide() end
        return cursorY
    end
    if not label and frame.questDetailContent then
        label = frame.questDetailContent:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalLarge")
        label:SetJustifyH("LEFT")
        frame.questDungeonStepText = label
    end
    if not label then return cursorY end
    -- (M: "can we try another font?"): the quest title's own font (Morpheus,
    -- or the language's), a black outline round it; set again each time, so
    -- the journal's language picks its letters.
    -- The size from the font itself, not from the label: read back from the
    -- label, each page shown made it a size bigger (25 is the size M liked).
    local titleFont = _G.ForeverDJ_QuestTitleFont
    local file, size
    if titleFont and titleFont.GetFont then file, size = titleFont:GetFont() end
    if not file then file, size = label:GetFont() end
    if file then pcall(label.SetFont, label, file, (tonumber(size) or 18) + 7, "OUTLINE") end
    label:SetShadowOffset(0, 0) -- (M: "the stroke slightly less": the outline alone, no shadow under it)
    -- chainstep (M 20 Nov 2026: "put the chain before ... the chain icon ...
    -- make sure it's big so that it's like the same size as the text"): the
    -- quest chain icon of the list, as tall as the label's letters' line;
    -- the label after it (a long language wraps beside it).
    -- (M: "the ones that we're using to click on [have] some kind of black
    -- background ... the one you put on the dungeon chain step does not"):
    -- the icon on a dark square with a thin grey edge, as on the list's
    -- dark rows; the square is the icon's frame (its texture is .chain).
    local px = math.floor((tonumber(size) or 18) + 8.5)
    if not frame.questDungeonStepIcon then
        local box = CreateFrame("Frame", nil, frame.questDetailContent)
        box.edge = box:CreateTexture(nil, "BACKGROUND")
        box.edge:SetAllPoints()
        box.edge:SetColorTexture(0.34, 0.31, 0.27, 1)
        box.fill = box:CreateTexture(nil, "BORDER")
        box.fill:SetPoint("TOPLEFT", 1, -1)
        box.fill:SetPoint("BOTTOMRIGHT", -1, 1)
        box.fill:SetColorTexture(0.05, 0.05, 0.05, 0.95)
        box.chain = box:CreateTexture(nil, "ARTWORK")
        box.chain:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\QuestChain.tga")
        frame.questDungeonStepIcon = box
    end
    local box = frame.questDungeonStepIcon
    box:SetSize(px + 6, px + 6)
    box.chain:ClearAllPoints()
    box.chain:SetPoint("CENTER")
    box.chain:SetSize(px, px)
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -(cursorY - 2))
    box:Show()
    px = px + 6
    label:SetText(L("DUNGEON_STEP"))
    label:SetTextColor(0.30, 0.76, 1.00)
    label:SetWidth(math.max(120, (frame.questDetailContent:GetWidth() or 360) - px - 14))
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", px + 6, -cursorY)
    label:Show()
    return cursorY + math.max(px, label:GetStringHeight() or 18) + 6
end

-- Chain step rows in the quest list: the small In Dungeon icon after the
-- step's title (and its tick) when the step is done inside the dungeon.
FDJ.SetStepRowDungeonIcon = function(row, show)
    local icon = row.inDungeonIcon
    if not show then
        if icon then icon:Hide() end
        return
    end
    if not icon then
        icon = row:CreateTexture(nil, "OVERLAY")
        icon:SetSize(20, 20)
        local ok = icon.SetAtlas and pcall(icon.SetAtlas, icon, "Dungeon", false)
        if not ok then
            icon:SetTexture("Interface\\Icons\\INV_Misc_Rune_01")
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        row.inDungeonIcon = icon
    end
    icon:ClearAllPoints()
    local after = (row.statusIcon and row.statusIcon:IsShown()) and row.statusIcon or row.text
    icon:SetPoint("LEFT", after, "RIGHT", 3, 0)
    icon:Show()
end

-- Quests (and chain steps) handed in inside a dungeon, by quest ID.
FDJ.HandedInInsideDungeon = function(questID)
    if not questID then return false end
    if not FDJ.insideTurnInIDs then
        local ids = {}
        for dungeonName, dungeon in pairs(DB) do
            if type(dungeon) == "table" and type(dungeon.quests) == "table" then
                for _, quest in ipairs(dungeon.quests) do
                    if type(quest) == "table" and quest.id then
                        if FDJ.TurnInInsideDungeon(quest.turnin, dungeonName) then ids[quest.id] = true end
                        for _, step in ipairs(QUEST_PREREQ_CHAINS[quest.id] or {}) do
                            local details = type(step) == "table" and step.id and QUEST_PREREQ_DETAILS[step.id]
                            if type(details) == "table" and FDJ.TurnInInsideDungeon(details.turnin, dungeonName) then
                                ids[step.id] = true
                            end
                        end
                    end
                end
            end
        end
        FDJ.insideTurnInIDs = ids
    end
    return FDJ.insideTurnInIDs[questID] == true
end

-- The In Dungeon icon after a quest page's Objective / Turn in header
-- (key: questObjectiveDungeonIcon / questTurninDungeonIcon), as after
-- Starts at. show false: hidden.
FDJ.SetHeaderDungeonIcon = function(key, header, show)
    local icon = frame and frame[key]
    if not show or not header or not frame or not frame.questDetailContent then
        if icon then icon:Hide() end
        return
    end
    if not icon then
        icon = CreateFrame("Button", nil, frame.questDetailContent)
        frame[key] = icon
        icon:SetSize(26, 26)
        icon.icon = icon:CreateTexture(nil, "ARTWORK")
        icon.icon:SetAllPoints()
        local ok = icon.icon.SetAtlas and pcall(icon.icon.SetAtlas, icon.icon, "Dungeon", false)
        if not ok then
            icon.icon:SetTexture("Interface\\Icons\\INV_Misc_Rune_01")
            icon.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        icon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        icon:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L("IN_DUNGEON"))
            GameTooltip:Show()
        end)
        icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    icon:ClearAllPoints()
    icon:SetPoint("LEFT", header, "RIGHT", 6, 0)
    icon:Show()
end

-- A quest started by an item that drops in the dungeon (from one of its
-- bosses or its trash) starts inside too, whatever its text says.
-- anydungeon (2.1.1, M 20 Nov 2026: "if it drops from an item inside, it's
-- obviously a dungeon step"): the item's source naming the dungeon counts
-- too (A Crumpled Up Note: "Drops from Dark Iron dwarves in Blackrock
-- Depths"), and on a quest chain page of its own (Onyxia Attunement) any
-- dungeon does.
FDJ.StartItemDropsIn = function(quest, dungeonName)
    local item = type(quest) == "table" and quest.startItem
    local id = type(item) == "table" and item[1]
    local dungeon = id and dungeonName and DB[dungeonName]
    if type(dungeon) ~= "table" then return false end
    local source = type(item[4]) == "string" and string.lower(item[4]) or ""
    if source:find("outside", 1, true) or source:find("near ", 1, true) or source:find("entrance", 1, true) then source = "" end
    local function DropsIn(name, d)
        if source ~= "" then
            local bare = string.lower(name)
            bare = (bare:match("^(.-):") or bare):gsub("^the ", "")
            if bare ~= "" and source:find(bare, 1, true) then return true end
        end
        for _, boss in ipairs(type(d.bosses) == "table" and d.bosses or {}) do
            for _, loot in ipairs(type(boss) == "table" and boss.loot or {}) do
                if type(loot) == "table" and loot[1] == id then return true end
            end
        end
        return false
    end
    if not dungeon.questChainPage then return DropsIn(dungeonName, dungeon) end
    for name, d in pairs(DB) do
        if type(d) == "table" and not d.questChainPage and DropsIn(name, d) then return true end
    end
    return false
end

-- A quest that needs a chain first is picked up where its chain starts:
-- the chain's first step (pendingOnly, for the tracker: the first step not
-- handed in yet). True/false; nil without a chain, or with every step done.
FDJ.ChainStartsInside = function(quest, dungeonName, pendingOnly)
    local chain = type(quest) == "table" and quest.id and QUEST_PREREQ_CHAINS[quest.id]
    if type(chain) ~= "table" or #chain == 0 then return nil end
    for _, step in ipairs(chain) do
        if type(step) == "table" and step.id ~= quest.id and not (pendingOnly and step.id
            and not step.itemStep and FDJ.QuestTurnedIn and FDJ.QuestTurnedIn(step.id)) then
            local details = (step.id and QUEST_PREREQ_DETAILS[step.id]) or {}
            return details.startsInDungeon == true or FDJ.StartsInsideDungeon(details.pickup)
                or FDJ.StartItemDropsIn(details, dungeonName)
        end
    end
    return nil
end

-- Quest list rows: a small dungeon icon after "Available from Level X" for
-- quests that are picked up inside the dungeon (same icon as the quest page).
-- Where icons go after a quest row's "Available from Level X": its width
-- and, when the text wraps (French, Spanish...: "Disponible à partir du
-- niveau" / "24"), the width of its last line and how far up from the
-- text's bottom that line's middle is (nil when it is one line).
FDJ.MetaIconSpot = function(fs)
    local full = fs:GetStringWidth() or 0
    local box = fs:GetWidth() or 0
    if box <= 0 or full <= box + 1 then return full, nil end
    local m = FDJ.metaMeasure
    if not m then
        m = UIParent:CreateFontString(nil, "OVERLAY")
        m:Hide()
        FDJ.metaMeasure = m
    end
    local font, size, flags = fs:GetFont()
    if font then m:SetFont(font, size or 12, flags) end
    local line = ""
    for word in (fs:GetText() or ""):gmatch("%S+") do
        local try = line == "" and word or (line .. " " .. word)
        m:SetText(try)
        if line ~= "" and (m:GetStringWidth() or 0) > box then line = word else line = try end
    end
    m:SetText(line)
    return (m:GetStringWidth() or 0), math.floor((size or 12) / 2 + 1.5)
end

FDJ.SetRowDungeonIcon = function(button, show, offsetX, wrappedY)
    local icon = button.dungeonStartIcon
    if not show then
        if icon then icon:Hide() end
        return
    end
    if not icon then
        icon = CreateFrame("Frame", nil, button)
        button.dungeonStartIcon = icon
        icon:SetSize(26, 26)
        icon:SetFrameLevel(button:GetFrameLevel() + 6)
        icon:EnableMouse(true)
        icon.tex = icon:CreateTexture(nil, "OVERLAY")
        icon.tex:SetAllPoints()
        local ok = icon.tex.SetAtlas and pcall(icon.tex.SetAtlas, icon.tex, "Dungeon", false)
        if not ok then
            icon.tex:SetTexture("Interface\\Icons\\INV_Misc_Rune_01")
            icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        icon:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L("IN_DUNGEON"))
            GameTooltip:Show()
        end)
        icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    icon:ClearAllPoints()
    if wrappedY then
        icon:SetPoint("LEFT", button.meta, "BOTTOMLEFT", offsetX, wrappedY)
    else
        icon:SetPoint("LEFT", button.meta, "LEFT", offsetX, 0)
    end
    icon:Show()
end

-- chainturnin: a chain step in the quest log that is handed in inside the
-- dungeon says so at the top of its page: YOU HAVE IT (gold, a thin black
-- outline) and a "Turn in: Dungeon" button like Show on Map, with the round
-- quest ? in it (on the left); a click opens the dungeon map where it is handed in (as
-- the ? of a quest ready to hand in does). Returns cursorY.
FDJ.PlaceStepHaveItRow = function(show, questID, details, title, cursorY)
    local row = frame and frame.questStepHaveIt
    if not show or not frame or not frame.questDetailContent then
        if row then row:Hide() end
        return cursorY
    end
    if not row then
        row = CreateFrame("Frame", nil, frame.questDetailContent)
        frame.questStepHaveIt = row
        row:SetHeight(26)
        row.haveIt = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
        row.haveIt:SetPoint("LEFT", row, "LEFT", 0, 0)
        do
            local font, size = row.haveIt:GetFont()
            if font then row.haveIt:SetFont(font, size or 12, "OUTLINE") end
        end
        row.haveIt:SetTextColor(1.00, 0.82, 0.10)
        local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        FDJ.OwnFonts(button) -- ownfonts (2.0.8)
        row.button = button
        button:SetSize(130, 24)
        button:SetPoint("LEFT", row.haveIt, "RIGHT", 10, 0)
        button:RegisterForClicks("LeftButtonUp")
        row.mark = FDJ.CreateTurnInButton and FDJ.CreateTurnInButton(button, 21)
        if row.mark then
            row.mark:SetPoint("LEFT", button, "LEFT", 5, 0)
            row.mark:SetFrameLevel(button:GetFrameLevel() + 2)
        end
        -- The button does what the ? does (the ? itself takes no mouse).
        local function Forward(script)
            return function(_, ...)
                local mark = row.mark
                local fn = mark and mark:GetScript(script)
                if fn then fn(mark, ...) end
            end
        end
        button:SetScript("OnClick", function()
            local mark = row.mark
            if mark and mark.fdjClick then mark.fdjClick(mark) end
        end)
        button:SetScript("OnEnter", Forward("OnEnter"))
        button:SetScript("OnLeave", Forward("OnLeave"))
        button:HookScript("OnMouseDown", Forward("OnMouseDown"))
        button:HookScript("OnMouseUp", Forward("OnMouseUp"))
    end
    local button = row.button
    row.haveIt:SetText(L("YOU_HAVE_IT"))
    button:SetText(L("TURN_IN_DUNGEON"))
    local fs = button:GetFontString()
    local textWidth = fs and fs:GetStringWidth() or 0
    button:SetWidth(math.max(96, math.min(210, math.ceil(textWidth + 24 + 22))))
    if fs then
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", button, "CENTER", row.mark and 10 or 0, 0)
    end
    if row.mark and FDJ.SetTurnInButton then
        FDJ.SetTurnInButton(row.mark, { id = questID, turnin = details.turnin, turninMap = details.turninMap }, title)
        local clickable = row.mark:IsMouseEnabled()
        row.mark:EnableMouse(false)
        button:EnableMouse(clickable)
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
    row:SetWidth(math.max(120, (row.haveIt:GetStringWidth() or 0) + 10 + button:GetWidth()))
    row:Show()
    return cursorY + 26 + 8
end

-- mapfocus: the ? / ! a control opened the dungeon map for pulses a few
-- seconds (FDJ.MAP_FOCUS_SECONDS), told apart from the other markers: by its
-- quest, else by where it is.
do
FDJ.MAP_FOCUS_SECONDS = 3.5
local FOCUS_GLOW = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\TickGlow"
FDJ.FocusDungeonMapQuest = function(questID, floor, x, y)
    FDJ.dungeonMapFocus = { questID = questID, floor = floor or 1, x = x, y = y,
        untilT = ((GetTime and GetTime()) or 0) + FDJ.MAP_FOCUS_SECONDS }
end
local function FocusMatches(questIDs, floor, x, y)
    local f = FDJ.dungeonMapFocus
    if not f or ((GetTime and GetTime()) or 0) > f.untilT then return false end
    if f.questID and questIDs and questIDs[f.questID] then return true end
    if f.x and f.y and x and y and (floor or 1) == (f.floor or 1) then
        return math.abs(f.x - x) < 0.015 and math.abs(f.y - y) < 0.015
    end
    return false
end
-- The pulse on one marker (on = false: off).
FDJ.PulseMarker = function(marker, on)
    if not marker then return end
    local glow = marker.fdjPulse
    if not on then
        if glow then glow:Hide() end
        if marker.fdjPulsing then marker:SetScript("OnUpdate", nil) marker.fdjPulsing = nil end
        return
    end
    if not glow then
        glow = marker:CreateTexture(nil, "BACKGROUND")
        glow:SetTexture(FOCUS_GLOW)
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(1, 0.85, 0.2)
        glow:SetPoint("CENTER")
        marker.fdjPulse = glow
        marker:HookScript("OnHide", function(self) FDJ.PulseMarker(self, false) end)
    end
    local size = (marker:GetWidth() or 24) * 2.2
    glow:SetSize(size, size)
    glow:Show()
    marker.fdjPulsing = true
    local untilT = FDJ.dungeonMapFocus and FDJ.dungeonMapFocus.untilT or 0
    marker:SetScript("OnUpdate", function(self)
        local now = (GetTime and GetTime()) or 0
        if now > untilT then FDJ.PulseMarker(self, false) return end
        glow:SetAlpha(0.35 + 0.65 * (0.5 + 0.5 * math.sin(now * 2 * math.pi * 1.5)))
    end)
end
-- The markers on the map now: the matching ones pulse, the others not.
FDJ.ApplyDungeonMapFocus = function()
    local mark = frame and frame.dungeonMapTurnIn
    if mark and mark:IsShown() and mark.turnIn then
        local t = mark.turnIn
        FDJ.PulseMarker(mark, FocusMatches(t.questID and { [t.questID] = true }, t.floor, t.x, t.y))
    end
    for _, b in ipairs((FDJ.MapQuestPinButtons and FDJ.MapQuestPinButtons()) or {}) do
        if b:IsShown() and b.fdjSpots then
            local ids = {}
            for _, spot in ipairs(b.fdjSpots) do
                for _, q in ipairs(spot.shown or {}) do
                    if q.id then ids[q.id] = true end
                    if q.main then ids[q.main] = true end
                end
            end
            FDJ.PulseMarker(b, FocusMatches(ids, b.fdjFloor, b.fdjX, b.fdjY))
        end
    end
end
end

-- glowingshard: a quest whose objective is done somewhere first (The
-- Glowing Shard: speak with Sputtervalve in Ratchet) gets a Show on Map
-- button under its objective: the world map, the NPC marked (and targeted
-- when near, like Show on Map). Returns cursorY.
FDJ.PlaceObjectiveMapButton = function(quest, cursorY)
    local spot = type(quest) == "table" and quest.objectiveMap or nil
    local b = frame and frame.questObjectiveMapButton
    if type(spot) ~= "table" or not spot.mapID or not frame or not frame.questDetailContent then
        if b then b:Hide() end
        if FDJ.PlaceObjectiveMore then FDJ.PlaceObjectiveMore(nil, cursorY) end -- malletone
        return cursorY
    end
    if not b then
        local ok, made = pcall(CreateFrame, "Button", nil, frame.questDetailContent, "UIPanelButtonTemplate,InsecureActionButtonTemplate")
        if ok and made then
            b = made
            b._fdjCanTarget = true
            b:SetAttribute("useOnKeyDown", false)
        else
            b = CreateFrame("Button", nil, frame.questDetailContent, "UIPanelButtonTemplate")
            b._fdjCanTarget = false
        end
        frame.questObjectiveMapButton = b
        FDJ.OwnFonts(b) -- ownfonts (2.0.8)
        b:SetSize(104, 24)
        b:RegisterForClicks("LeftButtonUp")
        -- PostClick keeps the template's own click (the target macro).
        b:SetScript(b._fdjCanTarget and "PostClick" or "OnClick", function(self)
            local s = self.fdjSpot
            local show = FDJ.MapMarkers and FDJ.MapMarkers.ShowRecordedLocationOnMap
            if not s or not show then return end
            s = (FDJ.LocalizeMapLocation and FDJ.LocalizeMapLocation(s)) or s
            FDJ.pendingMarkerQuestTitle = self.fdjQuestTitle
            FDJ.pendingMarkerQuestID = self.fdjQuestID -- autoclear: gone once the objective is done
            FDJ.pendingMarkerObjective = true
            show(s, s.label)
        end)
        b:SetScript("OnEnter", function(self)
            if FDJ.MapMarkers and FDJ.MapMarkers.ConfigureTargetAndMarkAction then
                FDJ.MapMarkers.ConfigureTargetAndMarkAction(self, self.fdjSpot, true)
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L("SHOW_ON_MAP"))
            if type(self.fdjWhere) == "string" and self.fdjWhere ~= "" then GameTooltip:AddLine(self.fdjWhere, 1, 1, 1, true) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    b.fdjSpot = spot
    b.fdjWhere = quest.objectiveWhere
    b.fdjQuestTitle = QuestField(quest.id, "name", quest.name)
    b.fdjQuestID = quest.id -- autoclear
    b:SetText(L("SHOW_ON_MAP"))
    local fs = b:GetFontString()
    b:SetWidth(math.max(96, math.min(150, math.ceil(((fs and fs:GetStringWidth()) or 0) + 24))))
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -(cursorY - 6))
    b:Show()
    if FDJ.PlaceObjectiveMore then return FDJ.PlaceObjectiveMore(quest, cursorY - 6 + 24 + 12) end -- malletone
    return cursorY - 6 + 24 + 12
end

-- malletone (2.1.3, M 21 Nov 2026, the Mallet of Zul'Farrak: "First ... kill
-- Qiaga to loot the Sacred Mallet, and then we have a little show on map to
-- show where Qiaga is, and then just below that ... use the Sacred Mallet at
-- the top of ... and then show on map"): quest.objectiveMore = { text, map,
-- area }: a second objective line under the first one's Show on Map, with a
-- Show on Map of its own. area = { areaID, English name }: the text's %s, the
-- client's own name of the place when the journal speaks its language.
-- Translated as the quest's field "objectiveMore". Returns cursorY.
FDJ.PlaceObjectiveMore = function(quest, cursorY)
    local more = type(quest) == "table" and type(quest.objectiveMore) == "table" and quest.objectiveMore or nil
    local text, b = frame and frame.questObjectiveMoreText, frame and frame.questObjectiveMoreButton
    if not more or not frame or not frame.questDetailContent then
        if text then text:Hide() end
        if b then b:Hide() end
        return cursorY
    end
    if not text then
        text = frame.questDetailContent:CreateFontString(nil, "OVERLAY")
        text:SetFontObject(frame.questDetailText:GetFontObject() or "ForeverDJ_GameFontNormal")
        text:SetJustifyH("LEFT")
        frame.questObjectiveMoreText = text
    end
    local line = QuestField(quest.id, "objectiveMore", more.text) or more.text or ""
    if type(more.area) == "table" and line:find("%s", 1, true) then
        local place = more.area[2] or ""
        if FDJ.CanUseClientLocalizedText and FDJ.CanUseClientLocalizedText() and C_Map and type(C_Map.GetAreaInfo) == "function" then
            local ok, name = pcall(C_Map.GetAreaInfo, more.area[1])
            if ok and type(name) == "string" and name ~= "" and not (type(issecretvalue) == "function" and issecretvalue(name)) then place = name end
        end
        line = line:gsub("%%s", (place:gsub("%%", "%%%%")))
    end
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
    text:SetWidth(frame.questDetailText:GetWidth() or math.max(120, (frame.questDetailContent:GetWidth() or 360) - 8))
    text:SetText(line)
    text:SetTextColor(0.10, 0.065, 0.025)
    text:Show()
    cursorY = cursorY + (text:GetStringHeight() or 30) + 13
    local spot = more.map
    if type(spot) ~= "table" or not spot.mapID then
        if b then b:Hide() end
        return cursorY
    end
    if not b then
        local ok, made = pcall(CreateFrame, "Button", nil, frame.questDetailContent, "UIPanelButtonTemplate,InsecureActionButtonTemplate")
        if ok and made then
            b = made
            b._fdjCanTarget = true
            b:SetAttribute("useOnKeyDown", false)
        else
            b = CreateFrame("Button", nil, frame.questDetailContent, "UIPanelButtonTemplate")
            b._fdjCanTarget = false
        end
        frame.questObjectiveMoreButton = b
        FDJ.OwnFonts(b)
        b:SetSize(104, 24)
        b:RegisterForClicks("LeftButtonUp")
        b:SetScript(b._fdjCanTarget and "PostClick" or "OnClick", function(self)
            local s = self.fdjSpot
            local show = FDJ.MapMarkers and FDJ.MapMarkers.ShowRecordedLocationOnMap
            if not s or not show then return end
            s = (FDJ.LocalizeMapLocation and FDJ.LocalizeMapLocation(s)) or s
            FDJ.pendingMarkerQuestTitle = self.fdjQuestTitle
            FDJ.pendingMarkerQuestID = self.fdjQuestID
            FDJ.pendingMarkerObjective = true
            show(s, s.label)
        end)
        b:SetScript("OnEnter", function(self)
            if FDJ.MapMarkers and FDJ.MapMarkers.ConfigureTargetAndMarkAction then
                FDJ.MapMarkers.ConfigureTargetAndMarkAction(self, self.fdjSpot, true)
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L("SHOW_ON_MAP"))
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    b.fdjSpot = spot
    b.fdjQuestTitle = QuestField(quest.id, "name", quest.name)
    b.fdjQuestID = quest.id
    b:SetText(L("SHOW_ON_MAP"))
    local fs = b:GetFontString()
    b:SetWidth(math.max(96, math.min(150, math.ceil(((fs and fs:GetStringWidth()) or 0) + 24))))
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -(cursorY - 6))
    b:Show()
    return cursorY - 6 + 24 + 12
end

FDJ.PositionInDungeonIcon = function()
    if not frame or not frame.questStartDungeonIcon or not frame.questStartsHeader then return end
    frame.questStartDungeonIcon:ClearAllPoints()
    frame.questStartDungeonIcon:SetPoint("LEFT", frame.questStartsHeader, "RIGHT", 6, 0)
    frame.questStartDungeonIcon:Show()
end

local function ItemLinkColor(link)
    if type(link) ~= "string" then return nil end
    local hex = link:match("|cff(%x%x%x%x%x%x)")
    if not hex then return nil end
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    if not r or not g or not b then return nil end
    return r / 255, g / 255, b / 255
end

local itemTooltipQualityCache = {}
local qualityScanTooltip

local function ExtractRGB(color)
    if not color then return nil end
    if type(color) == "table" then
        if type(color.GetRGB) == "function" then
            local ok, r, g, b = pcall(color.GetRGB, color)
            if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
                return r, g, b
            end
        end
        if type(color.r) == "number" and type(color.g) == "number" and type(color.b) == "number" then
            return color.r, color.g, color.b
        end
    end
    return nil
end

local function GetTooltipRenderedItemColor(itemID)
    if not itemID then return nil end

    local cached = itemTooltipQualityCache[itemID]
    if cached then return cached[1], cached[2], cached[3] end

    -- Best source: the same tooltip-data pipeline WoW uses to draw the item.
    -- This deliberately avoids trusting stale Forever item-quality metadata.
    if C_TooltipInfo and type(C_TooltipInfo.GetItemByID) == "function" then
        local ok, data = pcall(C_TooltipInfo.GetItemByID, itemID)
        if ok and type(data) == "table" and type(data.lines) == "table" and data.lines[1] then
            local line = data.lines[1]
            local r, g, b = ExtractRGB(line.leftColor or line.color)
            -- Not loaded yet: the title is the red "Retrieving item
            -- information" placeholder. Never cache that colour.
            local text = line.leftText or line.text
            if RETRIEVING_ITEM_INFO and text == RETRIEVING_ITEM_INFO then r = nil end
            if r then
                itemTooltipQualityCache[itemID] = {r, g, b}
                return r, g, b
            end
        end
    end

    -- Fallback for Forever builds where C_TooltipInfo does not expose colors:
    -- render the item into an invisible GameTooltip and read the title color.
    if CreateFrame and UIParent then
        if not qualityScanTooltip then
            qualityScanTooltip = CreateFrame(
                "GameTooltip",
                "ForeverDungeonJournalQualityScanTooltip",
                UIParent,
                "GameTooltipTemplate"
            )
        end

        qualityScanTooltip:Hide()
        qualityScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        if qualityScanTooltip.ClearLines then qualityScanTooltip:ClearLines() end

        local ok = pcall(qualityScanTooltip.SetHyperlink, qualityScanTooltip, "item:" .. tostring(itemID))
        if ok then
            local line = _G["ForeverDungeonJournalQualityScanTooltipTextLeft1"]
            if line and line.GetTextColor and line.GetText and line:GetText() and line:GetText() ~= ""
                and not (RETRIEVING_ITEM_INFO and line:GetText() == RETRIEVING_ITEM_INFO) then
                local r, g, b = line:GetTextColor()
                qualityScanTooltip:Hide()
                if type(r) == "number" and type(g) == "number" and type(b) == "number" then
                    itemTooltipQualityCache[itemID] = {r, g, b}
                    return r, g, b
                end
            end
        end
        qualityScanTooltip:Hide()
    end

    if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
    return nil
end

local function GetAuthoritativeItemQuality(itemID, link, apiQuality, fallbackQuality)
    -- The journal should match the color the actual in-game tooltip renders.
    -- This is authoritative for ALL loot/reward items, including Forever
    -- quality changes that differ from Classic-era databases or item links.
    -- The tooltip color is authoritative (Forever's own shades of green etc.
    -- differ from the stock quality colors), except RED: no item quality is
    -- red, so a red title means something else tinted it (another addon, or a
    -- weapon the character cannot use). Then fall back to the item's quality.
    local tr, tg, tb = GetTooltipRenderedItemColor(itemID)
    if tr then
        local isRed = tr > 0.8 and tg < 0.45 and tb < 0.45
        if not isRed then return tr, tg, tb end
        itemTooltipQualityCache[itemID] = nil
    end

    -- Deviate Hide Pack (918) is Common/white. The Forever tooltip is the
    -- authority above; this is only a safe fallback while item data loads.
    if itemID == 918 then
        return 1.00, 1.00, 1.00
    end

    -- Confirmed in the Forever client: Fel Steed Saddlebags (932) is Uncommon/green.
    -- Force the journal row to match the actual item tooltip instead of stale quality cache data.
    if itemID == 932 then
        return 0.12, 1.00, 0.00
    end

    -- Confirmed Forever override: Small Sack of Gems (280567) is Common/white.
    -- Some Forever beta caches have exposed an incorrect higher-quality color.
    if itemID == 280567 then
        return 1.00, 1.00, 1.00
    end

    -- Confirmed Forever override: Snakeskin Bag (6446) is Uncommon/green.
    -- Some beta caches have reported a stale Rare color for this item.
    if itemID == 6446 then
        -- Do not route this override back through GetItemQualityColor().
        -- The Forever beta has returned inconsistent quality metadata for
        -- this legacy item across sessions.  The item itself is Uncommon,
        -- so force the standard WoW uncommon green for the journal row.
        return 0.12, 1.00, 0.00
    end

    -- Prefer the actual item-quality value returned by the client.  Some
    -- Forever beta item links can carry stale Classic/TBC color codes, so the
    -- link color must not override the numeric quality.
    if type(apiQuality) == "number" then
        return QualityColor(apiQuality)
    end

    if C_Item and type(C_Item.GetItemQualityByID) == "function" then
        local ok, value = pcall(C_Item.GetItemQualityByID, itemID)
        if ok and type(value) == "number" then
            return QualityColor(value)
        end
    end

    local lr, lg, lb = ItemLinkColor(link)
    if lr then return lr, lg, lb end

    return QualityColor(fallbackQuality or 1)
end

-- Reuse the exact same quality-colour logic outside Journal.lua (for example
-- the Favourites popup) so an item cannot be Rare/blue in a boss loot table
-- but Uncommon/green in Favourites because of stale Forever item metadata.
FDJ.GetAuthoritativeItemQuality = GetAuthoritativeItemQuality

local function NormalizeDungeonName(name)
    if type(name) ~= "string" then return nil end

    local n = name:lower()
    if n:find("ragefire chasm", 1, true) then
        return "Ragefire Chasm"
    end
    if n:find("hall of thanes", 1, true) then
        return "Hall of Thanes"
    end
    if n:find("shaper's terrace", 1, true) or n:find("shapers terrace", 1, true) then
        return "Shaper's Terrace"
    end
    if n:find("deadmines", 1, true) then
        return "The Deadmines"
    end
    if n:find("wailing caverns", 1, true) then
        return "Wailing Caverns"
    end
    if n:find("shadowfang keep", 1, true) or n:find("shadowfang", 1, true) then
        return "Shadowfang Keep"
    end
    if n:find("ruins of lordaeron", 1, true) then
        return "Ruins of Lordaeron"
    end
    if n:find("blackfathom deeps", 1, true) or n:find("blackfathom depths", 1, true) then
        return "Blackfathom Deeps"
    end
    if n:find("stockade", 1, true) then
        return "The Stockade"
    end
    if n:find("excavation site", 1, true) and n:find("wetlands", 1, true) then
        return "Excavation Site: Wetlands"
    end
    if n:find("city of dalaran", 1, true) then
        return "City of Dalaran"
    end
    if n:find("gnomeregan", 1, true) then
        return "Gnomeregan"
    end
    if n:find("razorfen kraul", 1, true) then
        return "Razorfen Kraul"
    end
    if n:find("scarlet monastery", 1, true) and n:find("graveyard", 1, true) then
        return "Scarlet Monastery: Graveyard"
    end
    if n:find("scarlet monastery", 1, true) and n:find("library", 1, true) then
        return "Scarlet Monastery: Library"
    end
    if n:find("scarlet monastery", 1, true) and n:find("armory", 1, true) then
        return "Scarlet Monastery: Armory"
    end
    if n:find("scarlet monastery", 1, true) and n:find("cathedral", 1, true) then
        return "Scarlet Monastery: Cathedral"
    end
    if n:find("razorfen downs", 1, true) then
        return "Razorfen Downs"
    end
    if n:find("uldaman", 1, true) then
        return "Uldaman"
    end
    if n:find("zul'farrak", 1, true) or n:find("zulfarrak", 1, true) then
        return "Zul'Farrak"
    end
    if n:find("sunken temple", 1, true) or n:find("atal'hakkar", 1, true) then
        return "Sunken Temple"
    end
    if n:find("scholomance", 1, true) then
        return "Scholomance"
    end
    if n:find("maraudon", 1, true) then
        return "Maraudon"
    end
    if n:find("blackrock depths", 1, true) or n:find("shadowforge city", 1, true) or n:find("detention block", 1, true) then
        return "Blackrock Depths"
    end
    -- Dire Maul and Stratholme wings share one instance each: the wing comes
    -- from the full name ("Dire Maul - East") or from the room (subzone) name.
    if FDJ.WingFromText then
        local wing = FDJ.WingFromText(n)
        if wing then return wing end
    end
end

FDJ.INSTANCE_ID_TO_DUNGEON = {
    [389] = "Ragefire Chasm", [36] = "The Deadmines", [43] = "Wailing Caverns", [33] = "Shadowfang Keep",
    [34] = "The Stockade", [48] = "Blackfathom Deeps", [90] = "Gnomeregan", [47] = "Razorfen Kraul",
    [189] = "Scarlet Monastery", [2999] = "Ruins of Lordaeron", [2959] = "City of Dalaran",
    [3001] = "Shaper's Terrace", -- Forever instance map, shown as "The Shaper's Terrace" in game
    -- 2.0.3: by ID on every client language ("Die Versunkene Stadt" on German).
    -- Forever's Map.db2 / Group Finder activity list (build 1.60.1).
    [2970] = "The Drowned City", [3039] = "Krol'dok Stronghold",
    [2998] = "Excavation Site: Wetlands", [3065] = "Hall of Thanes", [2994] = "Alcaz Prison", [2974] = "Blackmaw Hold", [129] = "Razorfen Downs", [70] = "Uldaman", [209] = "Zul'Farrak", [109] = "Sunken Temple", [289] = "Scholomance", [349] = "Maraudon", [230] = "Blackrock Depths",
}
FDJ.SCARLET_WING_MAPS = { [302] = "Scarlet Monastery: Graveyard", [303] = "Scarlet Monastery: Library",
    [304] = "Scarlet Monastery: Armory", [305] = "Scarlet Monastery: Cathedral" }

local function CurrentDungeon()
    -- Only auto-select a dungeon while the player is actually inside an
    -- instance. This prevents similarly named outdoor zones from hijacking the
    -- journal when it opens.
    if type(IsInInstance) == "function" then
        local inInstance = IsInInstance()
        if not inInstance then return nil end
    end

    -- Language-independent detection first: the numeric instance ID is the same
    -- on every client, so non-English clients are recognised too.
    if GetInstanceInfo then
        local instanceID = select(8, GetInstanceInfo())
        local byID = FDJ.INSTANCE_ID_TO_DUNGEON[tonumber(instanceID) or -1]
        if byID and byID ~= "Scarlet Monastery" and DB[byID] then
            return byID
        end
    end

    -- The Scarlet wings share one instance; see Systems/ScarletWing.lua.
    if FDJ.InScarletMonastery and FDJ.ResolveScarletWing then
        local okIn, inScarlet = pcall(FDJ.InScarletMonastery)
        if okIn and inScarlet then
            local okWing, wing = pcall(FDJ.ResolveScarletWing)
            if okWing and wing and DB[wing] then return wing end
        end
    end

    local instanceName = GetInstanceInfo and GetInstanceInfo()
    local n = NormalizeDungeonName(instanceName)
    if n then return n end
    -- Any journal dungeon by its exact name, "The" or not (The Drowned City,
    -- Krol'dok Stronghold and other newer dungeons with no rule above).
    if FDJ.DungeonFromInstanceName then
        local exact = FDJ.DungeonFromInstanceName(instanceName)
        if exact then return exact end
    end
    -- Localised instance name: compare with the journal's own translations.
    if type(instanceName) == "string" and instanceName ~= "" then
        -- Straight and curly apostrophes count as the same (Zul'Farrak / Zul’Farrak).
        local function Same(text) return (text:lower():gsub("\226\128\153", "'")) end
        local wanted = Same(instanceName)
        for _, content in pairs(FDJ.ContentLocales or {}) do
            for internal, entry in pairs(content.dungeons or {}) do
                if DB[internal] and type(entry.name) == "string" and Same(entry.name) == wanted then return internal end
            end
        end
    end


    local zone = GetRealZoneText and GetRealZoneText()
    n = NormalizeDungeonName(zone)
    if n then return n end

    -- Scarlet Monastery may report the shared instance name rather than the
    -- wing name. Use the subzone only to disambiguate Graveyard; never assume
    -- another Scarlet wing is Graveyard.
    local subZone = GetSubZoneText and GetSubZoneText()
    if type(instanceName) == "string" and instanceName:lower():find("scarlet monastery", 1, true)
        and type(subZone) == "string" and subZone:lower():find("graveyard", 1, true)
    then
        return "Scarlet Monastery: Graveyard"
    end
    if type(instanceName) == "string" and instanceName:lower():find("scarlet monastery", 1, true)
        and type(subZone) == "string" and subZone:lower():find("library", 1, true)
    then
        return "Scarlet Monastery: Library"
    end

    local bySubZone = NormalizeDungeonName(subZone)
    if bySubZone then return bySubZone end
    -- Lower and Upper Blackrock Spire share instance 229; the room decides
    -- above, and you zone in on the Lower side.
    if GetInstanceInfo and tonumber((select(8, GetInstanceInfo()))) == 229 and DB["Lower Blackrock Spire"] then
        return "Lower Blackrock Spire"
    end
    return nil
end
FDJ.CurrentDungeon = CurrentDungeon
function FDJ.DungeonFromInstanceName(name)
    if type(name) ~= "string" or name == "" then return nil end
    if type(issecretvalue) == "function" and issecretvalue(name) then return nil end
    local function Bare(x) return (x:lower():gsub("^the%s+", ""):gsub("[%s%p]", "")) end
    local wanted = Bare(name)
    if DB[name] then return name end
    for key in pairs(DB) do
        if type(key) == "string" and Bare(key) == wanted then return key end
    end
end

-- Profession quests: only for characters with that profession (unless
-- "Show All Profession Quests" is on). The profession names come from the
-- client's own (localized) spell names, compared with the skill list.
FDJ.PROFESSION_SPELLS = {
    BLACKSMITHING = 2018, MINING = 2575, LEATHERWORKING = 2108, TAILORING = 3908,
    ALCHEMY = 2259, ENGINEERING = 4036, ENCHANTING = 7411, SKINNING = 8613, HERBALISM = 2366,
}
-- profskill (2.0.41): the WoW Forever client has no skill list
-- (GetNumSkillLines / GetSkillLineInfo are nil there, and so is
-- GetSpellInfo), so every character was shown every profession quest. The
-- professions are read with GetProfessions / GetProfessionInfo instead, by
-- their skill line number, the same in every client language (Mining 186,
-- Blacksmithing 164...), or by their name. The skill list stays the way
-- for clients that have it.
FDJ.PROFESSION_SKILL_LINES = {
    BLACKSMITHING = 164, MINING = 186, LEATHERWORKING = 165, TAILORING = 197,
    ALCHEMY = 171, ENGINEERING = 202, ENCHANTING = 333, SKINNING = 393, HERBALISM = 182,
}
function FDJ.PlayerHasProfession(token)
    token = tostring(token or ""):upper()
    local wanted = {}
    local spell = FDJ.PROFESSION_SPELLS[token]
    if spell then
        local name
        if type(GetSpellInfo) == "function" then
            local ok, n = pcall(GetSpellInfo, spell)
            if ok then name = n end
        end
        if type(name) ~= "string" and type(C_Spell) == "table" and type(C_Spell.GetSpellName) == "function" then
            local ok, n = pcall(C_Spell.GetSpellName, spell)
            if ok then name = n end
        end
        if type(name) == "string" and not (type(issecretvalue) == "function" and issecretvalue(name)) then
            wanted[name:lower()] = true
        end
    end
    wanted[token:lower()] = true
    if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
        local line = FDJ.PROFESSION_SKILL_LINES[token]
        local okP, p1, p2, p3, p4, p5, p6 = pcall(GetProfessions)
        if okP then
            for _, index in pairs({ p1, p2, p3, p4, p5, p6 }) do
                local ok, name, _, _, _, _, _, skillLine = pcall(GetProfessionInfo, index)
                if ok then
                    if line and tonumber(skillLine) == line then return true end
                    if type(name) == "string" and not (type(issecretvalue) == "function" and issecretvalue(name))
                        and wanted[name:lower()] then return true end
                end
            end
            return false
        end
    end
    if type(GetNumSkillLines) ~= "function" or type(GetSkillLineInfo) ~= "function" then return true end
    local okCount, count = pcall(GetNumSkillLines)
    if not okCount or type(count) ~= "number" or count == 0 then return true end -- not loaded yet
    for i = 1, count do
        local ok, name, isHeader = pcall(GetSkillLineInfo, i)
        if ok and not isHeader and type(name) == "string" and wanted[name:lower()] then return true end
    end
    return false
end

-- twoclasses (2.1.0, M 19 Nov 2026; Ziefog on Discord: Nostro's Compendium
-- is "Warry Pally only"): classOnly is one class ("PALADIN") or a list of
-- them ({ "WARRIOR", "PALADIN" }); true when the class token is one of them.
function FDJ.QuestClassMatches(classOnly, token)
    if not classOnly then return true end
    if type(token) ~= "string" then return false end
    token = token:upper()
    if type(classOnly) == "table" then
        for _, c in ipairs(classOnly) do
            if tostring(c):upper() == token then return true end
        end
        return false
    end
    return tostring(classOnly):upper() == token
end

local function QuestMatchesFaction(quest, faction)
    if not quest then return false end
    local forFaction = quest.faction == "Both"
        or quest.faction == "Neutral"
        or quest.faction == faction
    if not forFaction then return false end
    -- Class quests only show for that class, unless the player turned on
    -- "Show All Class Quests" in the options.
    if quest.classOnly and not ForeverDungeonJournalDB.showAllClassQuests then
        local playerClass
        if UnitClass then
            local ok, _, token = pcall(UnitClass, "player")
            if ok then playerClass = token end
        end
        if type(issecretvalue) == "function" and issecretvalue(playerClass) then playerClass = nil end
        if type(playerClass) == "string" and playerClass ~= ""
            and not FDJ.QuestClassMatches(quest.classOnly, playerClass) then
            return false
        end
    end
    if quest.profession and not ForeverDungeonJournalDB.showAllProfessionQuests
        and not FDJ.PlayerHasProfession(quest.profession) then
        return false
    end
    -- hideunavailable (2.0.11): "Hide unavailable quests" (Options, Quests)
    if ForeverDungeonJournalDB.hideUnavailableQuests and FDJ.IsQuestUnavailable
        and FDJ.IsQuestUnavailable(quest) then
        return false
    end
    return true
end

-- otherclass (2.0.8, Doudou on Discord / M 15 Nov 2026): a quest listed only
-- because "Show all class quests" or "Show all profession quests" is on
-- (another class's quest, or one for a profession the character doesn't
-- have) is there to look at: it doesn't count. Not in the home page's quest
-- count or its tick, the "all quests done" auto-hide, the quest tracker, the
-- Route or the character export's done/total. The dungeon's quest list still
-- shows it. (RPG Mode already counted only the character's own.)
function FDJ.QuestCountsForCharacter(quest)
    if type(quest) ~= "table" then return false end
    if quest.classOnly and type(UnitClass) == "function" then
        local ok, _, token = pcall(UnitClass, "player")
        if ok and type(token) == "string" and not (type(issecretvalue) == "function" and issecretvalue(token))
            and token ~= "" and not FDJ.QuestClassMatches(quest.classOnly, token) then
            return false
        end
    end
    if quest.profession and FDJ.PlayerHasProfession and not FDJ.PlayerHasProfession(quest.profession) then
        return false
    end
    return true
end

local function IsSecret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

local function FormatNumber(value)
    if type(value) ~= "number" then return nil end

    if type(BreakUpLargeNumbers) == "function" then
        local ok, formatted = pcall(BreakUpLargeNumbers, value)
        if ok and type(formatted) == "string" then
            return formatted
        end
    end

    local s = tostring(math.floor(value + 0.5))
    local formatted = s
    while true do
        local changed
        formatted, changed = formatted:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
        if changed == 0 then break end
    end
    return formatted
end

-- Mark BEFORE the API call: cached data may fire its event synchronously.
-- Failed requests can retry after a cooldown, never from inside the event.
local questDataRequests = {}
local function RequestQuestRewardData(questID)
    if type(questID) ~= "number" then return end
    local request = questDataRequests[questID]
    local now = GetTime and GetTime() or 0
    if request and (request.state ~= "failed" or now < request.retryAt) then return end
    if C_QuestLog and type(C_QuestLog.RequestLoadQuestByID) == "function" then
        local pendingRequest = {state = "pending"}
        questDataRequests[questID] = pendingRequest
        local ok = pcall(C_QuestLog.RequestLoadQuestByID, questID)
        if not ok then
            questDataRequests[questID] = {state = "failed", retryAt = now + 30}
        elseif C_Timer and C_Timer.After then
            -- A quest the server never answers for (new Forever quests) would
            -- stay "pending" and show no XP at all: after 3 seconds use the
            -- stored values instead.
            C_Timer.After(3, function()
                if questDataRequests[questID] == pendingRequest and pendingRequest.state == "pending" then
                    questDataRequests[questID] = {state = "failed", retryAt = (GetTime and GetTime() or 0) + 300}
                    if FDJ.ScheduleQuestRefresh then FDJ.ScheduleQuestRefresh() end
                end
            end)
        end
    end
end

-- Current client rewards take precedence over all offline fallbacks.
-- A zero is authoritative only after successful quest-data loading; otherwise
-- it can mean that the client has not cached the quest yet.
local function GetLiveQuestXP(quest)
    if not quest then return nil end
    if not quest.id then return quest.liveXPFallback end
    if type(GetQuestLogRewardXP) == "function" then
        local ok, xp = pcall(GetQuestLogRewardXP, quest.id)
        if ok and not IsSecret(xp) and type(xp) == "number" then
            -- xpfix (2.0.10, M 17 Nov 2026: "we have some wrong experience
            -- values"): the quest log's XP for Allegiance to the Old Gods,
            -- Amongst the Ruins and Baron Aquanis (6,300 / 6,550 / 7,250) is
            -- what Wowhead Forever lists too; it is no longer swapped for the
            -- 3% higher amounts (6,489 / 6,746 / 7,468).
            if xp > 0 then return xp end
            local request = questDataRequests[quest.id]
            if xp == 0 and request and request.state == "loaded" then return 0 end
        end
    end
    local request = questDataRequests[quest.id]
    if request and request.state == "pending" then return nil end
    return FOREVER_QUEST_XP_FALLBACK[quest.id] or quest.liveXPFallback
end

local function GetQuestRewardExtrasText(quest)
    if not quest then return "" end

    local summary = quest.rewardSummary or quest.rewards or ""

    -- Remove the old cached/base XP token. Live/current XP is rendered in the
    -- dedicated XP reward box, matching Blizzard's quest-log layout.
    summary = summary:gsub("^%s*[%d,%.]+%s*XP%s*[•|]*%s*", "")
    summary = summary:gsub("^%s*XP%s*[%d,%.]+%s*[•|]*%s*", "")
    return summary
end

local function ParseQuestRewardExtras(quest)
    local raw = FreeText(GetQuestRewardExtrasText(quest))
    local money = 0
    local kept = {}

    -- Items already shown as reward buttons must not be repeated as text
    -- underneath (e.g. "Nogg's Gold Ring" under the Nogg's Gold Ring button).
    local shownItems = {}
    if type(quest) == "table" then
        for _, list in ipairs({ quest.rewardItems, quest.additionalRewardItems, quest.noteRewardItems }) do
            for _, item in ipairs(type(list) == "table" and list or {}) do
                if type(item[2]) == "string" then shownItems[item[2]:lower()] = true end
                if type(item[1]) == "number" and item[1] > 0 and GetItemInfo then
                    local ok, liveName = pcall(GetItemInfo, item[1])
                    if ok and type(liveName) == "string" and not IsSecret(liveName) then
                        shownItems[liveName:lower()] = true
                    end
                end
            end
        end
    end

    for token in raw:gmatch("[^•|]+") do
        token = token:gsub("^%s+", ""):gsub("%s+$", "")
        -- "Nogg's Gold Ring" or "Nogg's Gold Ring x2": already a button.
        local bare = token:gsub("%s*[xX]%s*%d+$", ""):lower()
        if shownItems[bare] then token = "" end
        if token ~= "" then
            local remainder = token:gsub("%d+%s*[gsc]", ""):gsub("%s+", "")
            if remainder == "" and token:find("%d+%s*[gsc]") then
                for amount, unit in token:gmatch("(%d+)%s*([gsc])") do
                    local value = tonumber(amount) or 0
                    if unit == "g" then
                        money = money + value * 10000
                    elseif unit == "s" then
                        money = money + value * 100
                    else
                        money = money + value
                    end
                end
            else
                -- Reputation rewards are stored as "Faction Name +Amount".
                -- Translate only the faction name, then preserve the numeric
                -- reputation amount exactly as authored.
                local repName, repAmount = token:match("^(.-)%s+([%+%-]%d+)$")
                if repName and repAmount then
                    repName = repName:gsub("^%s+", ""):gsub("%s+$", "")
                    if FDJ.LocalizeReputationName then
                        repName = FDJ.LocalizeReputationName(repName) or repName
                    else
                        repName = FreeText(repName)
                    end
                    token = repName .. " " .. repAmount
                end
                table.insert(kept, token)
            end
        end
    end

    return table.concat(kept, "  •  "), money
end

local function GetQuestRewardMoneyCopper(quest)
    local _, money = ParseQuestRewardExtras(quest)
    return money or 0
end

local function FormatQuestMoney(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local coin = copper % 100
    local parts = {}

    if gold > 0 then
        table.insert(parts, gold .. " |TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t")
    end
    if silver > 0 or gold > 0 then
        table.insert(parts, silver .. " |TInterface\\MoneyFrame\\UI-SilverIcon:14:14:2:0|t")
    end
    if coin > 0 then
        table.insert(parts, coin .. " |TInterface\\MoneyFrame\\UI-CopperIcon:14:14:2:0|t")
    end

    return table.concat(parts, "  ")
end

-- Reputation reward pills: a green "+100" badge followed by the faction name,
-- styled like the XP and money reward pills. Lays the pills out in rows from
-- (0, -y) inside the quest detail content and returns the height used.
FDJ.LayoutRepPills = function(reps, y, maxWidth)
    if not frame or not frame.questDetailContent then return 0 end
    frame.questRepPills = frame.questRepPills or {}
    local pool = frame.questRepPills
    local x, rows = 0, 0
    for i, rep in ipairs(reps) do
        local pill = pool[i]
        if not pill then
            pill = CreateFrame("Frame", nil, frame.questDetailContent, "BackdropTemplate")
            pool[i] = pill
            pill:SetHeight(26)
            pill:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 9,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            pill:SetBackdropColor(0.07, 0.13, 0.06, 0.95)
            pill:SetBackdropBorderColor(0.30, 0.50, 0.24, 1)
            pill.badge = pill:CreateTexture(nil, "ARTWORK")
            pill.badge:SetHeight(18)
            pill.badge:SetPoint("LEFT", 5, 0)
            pill.badge:SetColorTexture(0.16, 0.48, 0.14, 0.95)
            pill.amount = pill:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
            pill.amount:SetPoint("CENTER", pill.badge, "CENTER", 0, 0)
            pill.amount:SetTextColor(0.80, 1.00, 0.70)
            pill.name = pill:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
            pill.name:SetPoint("LEFT", pill.badge, "RIGHT", 7, 0)
            pill.name:SetTextColor(1.00, 0.92, 0.72)
        end
        pill.amount:SetText("+" .. tostring(rep[2]))
        pill.name:SetText(tostring(rep[1]))
        local badgeWidth = math.ceil((pill.amount:GetStringWidth() or 24) + 8)
        pill.badge:SetWidth(badgeWidth)
        local width = 5 + badgeWidth + 7 + math.ceil(pill.name:GetStringWidth() or 60) + 9
        if rows == 0 then rows = 1 end
        if x > 0 and x + width > maxWidth then
            x = 0
            rows = rows + 1
        end
        pill:SetWidth(width)
        pill:ClearAllPoints()
        pill:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", x, -(y + (rows - 1) * 30))
        pill:Show()
        x = x + width + 8
    end
    for i = #reps + 1, #pool do pool[i]:Hide() end
    return rows * 30
end

local function BuildQuestRewardSummary(quest, includeXP)
    if not quest then return "" end

    local summary = ParseQuestRewardExtras(quest)
    local xp = GetLiveQuestXP(quest)
    if includeXP ~= false and xp and xp > 0 then
        local xpText = FormatNumber(xp) .. " XP"
        if summary ~= "" then
            return xpText .. "  •  " .. summary
        end
        return xpText
    end

    return summary
end

-- devlog: /dj fakelog <questID>: quests shown as if in the quest log.
FDJ.DEV_FAKE_LOG = FDJ.DEV_FAKE_LOG or {}
-- devchain (2.0.8): /dj devchain: quests shown as handed in (DONE) or as
-- never taken (OPEN), for this session only; empty unless that command
-- (a test command) is used.
FDJ.DEV_CHAIN_DONE = FDJ.DEV_CHAIN_DONE or {}
FDJ.DEV_CHAIN_OPEN = FDJ.DEV_CHAIN_OPEN or {}

local function IsQuestFinished(questID)
    if not questID then return false end
    if FDJ.DEV_FAKE_LOG[questID] then return false end -- devlog
    if FDJ.DEV_CHAIN_OPEN[questID] then return false end -- devchain
    if FDJ.DEV_CHAIN_DONE[questID] then return true end
    -- malletchain: steps that are not quests, done when the item is held.
    local pseudo = FDJ.PSEUDO_QUEST_DONE and FDJ.PSEUDO_QUEST_DONE[questID]
    if pseudo then
        local ok, done = pcall(pseudo)
        return ok and done == true
    end
    -- choicestep (2.0.37): one of a step's other quests handed in does it.
    if FDJ.DoneByOther and FDJ.DoneByOther(questID) then return true end
    if FDJ.DoneOnce and FDJ.DoneOnce(questID) then return true end -- repeatonce (2.1.0)

    -- A permanently completed quest is always complete.
    if C_QuestLog and type(C_QuestLog.IsQuestFlaggedCompleted) == "function" then
        local ok, value = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
        if ok and value == true then
            return true
        end
    elseif type(IsQuestFlaggedCompleted) == "function" then
        local ok, value = pcall(IsQuestFlaggedCompleted, questID)
        if ok and value == true then
            return true
        end
    end

    -- Do not use ReadyForTurnIn() here. On the Forever client some active
    -- dungeon quests can report ready state before their real objective is done.
    -- Only show the green completion state for an active quest when the quest
    -- log itself reports it complete.
    local inLog = false

    if C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID) == "function" then
        local ok, index = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
        inLog = ok and type(index) == "number" and index > 0
    elseif type(GetQuestLogIndexByID) == "function" then
        local ok, index = pcall(GetQuestLogIndexByID, questID)
        inLog = ok and type(index) == "number" and index > 0
    end

    if not inLog then
        return false
    end

    -- A quest with no objectives (talk to someone / deliver this) is reported
    -- complete by the quest log the moment it is accepted: it is ready to hand
    -- in, as the game itself shows it (the journal draws its ? until it is
    -- handed in, not the green tick).
    local objectiveCount
    if C_QuestLog and type(C_QuestLog.GetQuestObjectives) == "function" then
        local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
        if ok and type(objectives) == "table" then objectiveCount = #objectives end
    end
    if objectiveCount == nil and type(GetQuestLogIndexByID) == "function" and type(GetNumQuestLeaderBoards) == "function" then
        local okIndex, index = pcall(GetQuestLogIndexByID, questID)
        if okIndex and type(index) == "number" and index > 0 then
            local okCount, count = pcall(GetNumQuestLeaderBoards, index)
            if okCount and type(count) == "number" then objectiveCount = count end
        end
    end
    -- insidequest: nothing to do but go and speak to someone inside a
    -- dungeon (Songblade Search, Deathstalkers in Shadowfang): the quest log
    -- calls it complete as soon as it is accepted, but it is not ready before
    -- that talk. YOU HAVE IT (in the quest log) until it is handed in there.
    if objectiveCount == 0 and FDJ.HandedInInsideDungeon and FDJ.HandedInInsideDungeon(questID) then
        return false
    end
    if C_QuestLog and type(C_QuestLog.IsComplete) == "function" then
        local ok, value = pcall(C_QuestLog.IsComplete, questID)
        if ok then
            return value == true
        end
    end

    return false
end

local function IsQuestInLog(questID)
    if not questID then return false end
    if FDJ.DEV_FAKE_LOG[questID] then return true end -- devlog
    if FDJ.DEV_CHAIN_OPEN[questID] or FDJ.DEV_CHAIN_DONE[questID] then return false end -- devchain

    if C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID) == "function" then
        local ok, index = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
        if ok and type(index) == "number" and index > 0 then
            return true
        end
    end

    if type(GetQuestLogIndexByID) == "function" then
        local ok, index = pcall(GetQuestLogIndexByID, questID)
        if ok and type(index) == "number" and index > 0 then
            return true
        end
    end

    -- Classic-style fallback for clients that do not expose the helpers above.
    if type(GetNumQuestLogEntries) == "function" and type(GetQuestLogTitle) == "function" then
        local ok, numEntries = pcall(GetNumQuestLogEntries)
        if ok and type(numEntries) == "number" then
            for i = 1, numEntries do
                local title, _, _, isHeader, _, _, _, id = GetQuestLogTitle(i)
                if not isHeader and id == questID then
                    return true
                end
            end
        end
    end

    return false
end

FDJ.IsQuestShareable = function(questID)
    -- This answers whether the quest itself is designed to be shareable.
    -- Prefer our audited dungeon data so browsing an unaccepted quest gives
    -- stable information. Unknown/new beta quests still use Forever's native
    -- predicate rather than being guessed.
    if type(questID) ~= "number" then
        return false
    end

    local audited = FDJ.QUEST_SHAREABILITY_AUDIT and FDJ.QUEST_SHAREABILITY_AUDIT[questID]
    if audited ~= nil then
        return audited == true
    end

    if C_QuestLog and type(C_QuestLog.IsPushableQuest) == "function" then
        local ok, value = pcall(C_QuestLog.IsPushableQuest, questID)
        return ok and value == true
    end
    return false
end

FDJ.IsQuestShareableNow = function(questID)
    -- Actually pushing a quest still requires it to be in our quest log.
    return IsQuestInLog(questID) and FDJ.IsQuestShareable(questID)
end

FDJ.ShareQuestByID = function(questID)
    if not FDJ.IsQuestShareableNow(questID) then return end

    -- Forever uses the modern quest predicate but still exposes the standard
    -- quest-share action on supported builds. Select the journal quest first
    -- when that API is available, then invoke the share action from this click.
    if C_QuestLog and type(C_QuestLog.SetSelectedQuest) == "function" then
        pcall(C_QuestLog.SetSelectedQuest, questID)
    elseif type(SelectQuestLogEntry) == "function" then
        local logIndex
        if C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID) == "function" then
            local ok, index = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
            if ok and type(index) == "number" and index > 0 then logIndex = index end
        elseif type(GetQuestLogIndexByID) == "function" then
            local ok, index = pcall(GetQuestLogIndexByID, questID)
            if ok and type(index) == "number" and index > 0 then logIndex = index end
        end
        if logIndex then pcall(SelectQuestLogEntry, logIndex) end
    end

    if type(QuestLogPushQuest) == "function" then
        pcall(QuestLogPushQuest)
    elseif QuestFramePushQuestButton and type(QuestFramePushQuestButton.Click) == "function" then
        pcall(QuestFramePushQuestButton.Click, QuestFramePushQuestButton)
    end
end

-- questrowmenu (2.0.11): abandon through the game's own "Abandon <quest>?"
-- confirmation, as the quest log does.
FDJ.AbandonQuestByID = function(questID, name)
    if type(questID) ~= "number" or not IsQuestInLog(questID) then return end
    if C_QuestLog and type(C_QuestLog.SetSelectedQuest) == "function" and type(C_QuestLog.SetAbandonQuest) == "function" then
        pcall(C_QuestLog.SetSelectedQuest, questID)
        pcall(C_QuestLog.SetAbandonQuest)
    elseif type(SelectQuestLogEntry) == "function" and type(SetAbandonQuest) == "function" then
        local index
        if type(GetQuestLogIndexByID) == "function" then
            local ok, i = pcall(GetQuestLogIndexByID, questID)
            if ok and type(i) == "number" and i > 0 then index = i end
        end
        if not index then return end
        pcall(SelectQuestLogEntry, index)
        pcall(SetAbandonQuest)
    else
        return
    end
    local title = name
    if type(GetAbandonQuestName) == "function" then
        local ok, own = pcall(GetAbandonQuestName)
        if ok and type(own) == "string" and own ~= "" then title = own end
    end
    if type(StaticPopup_Show) == "function" then StaticPopup_Show("ABANDON_QUEST", title or "") end
end

FDJ.ShowQuestRowMenu = function(owner, questID, name)
    if type(questID) ~= "number" or not IsQuestInLog(questID) then return end
    local share, abandon = SHARE_QUEST or "Share Quest", ABANDON_QUEST or "Abandon Quest"
    local canShare = FDJ.IsQuestShareableNow(questID) and (type(IsInGroup) ~= "function" or IsInGroup())
    if MenuUtil and type(MenuUtil.CreateContextMenu) == "function" then
        MenuUtil.CreateContextMenu(owner, function(_, root)
            local b = root:CreateButton(share, function() FDJ.ShareQuestByID(questID) end)
            if b and b.SetEnabled then b:SetEnabled(canShare and true or false) end
            root:CreateButton(abandon, function() FDJ.AbandonQuestByID(questID, name) end)
        end)
        return
    end
    if type(EasyMenu) == "function" and CreateFrame then
        FDJ.questRowMenuFrame = FDJ.questRowMenuFrame or CreateFrame("Frame", "ForeverDungeonJournalQuestRowMenu", UIParent, "UIDropDownMenuTemplate")
        EasyMenu({
            { text = share, notCheckable = true, disabled = not canShare, func = function() FDJ.ShareQuestByID(questID) end },
            { text = abandon, notCheckable = true, func = function() FDJ.AbandonQuestByID(questID, name) end },
        }, FDJ.questRowMenuFrame, "cursor", 0, 0, "MENU")
    end
end

FDJ.SetQuestShareButtonVisual = function(button, shareable, canShareNow)
    if not button then return end
    button._fdjShareableQuest = shareable == true
    button._fdjShareEnabled = canShareNow == true

    -- Match the compact gold-bordered selector style used elsewhere in the
    -- journal. Shareable quests use a green fill. Quests that cannot be
    -- shared are visually greyed out but remain mouse-enabled so their
    -- explanatory tooltip still works.
    if button._fdjShareableQuest then
        button:SetBackdropColor(0.10, 0.34, 0.16, 0.98)
        button:SetBackdropBorderColor(0.48, 0.40, 0.27, 1.00)
        if button.text then button.text:SetTextColor(1.00, 0.82, 0.27) end
    else
        button:SetBackdropColor(0.18, 0.18, 0.18, 0.96)
        button:SetBackdropBorderColor(0.34, 0.34, 0.34, 1.00)
        if button.text then button.text:SetTextColor(0.55, 0.55, 0.55) end
    end
end

local function QuestNeedsSameStepShareNote(questID)
    if type(questID) ~= "number" then return false end

    -- The dungeon/final quest itself is a gated chain step.
    if QUEST_PREREQ_CHAINS[questID] ~= nil and not FDJ.IsGuideQuest(questID) then
        return true
    end

    -- The first prerequisite can be picked up normally. Every later step is
    -- only useful to players who have progressed to that same point in the
    -- chain, so flag steps 2+ for the more precise share tooltip.
    for _, chain in pairs(QUEST_PREREQ_CHAINS) do
        if type(chain) == "table" then
            for index, step in ipairs(chain) do
                if step and step.id == questID then
                    return index > 1 and step.shareNormally ~= true
                end
            end
        end
    end

    return false
end

FDJ.UpdateQuestShareButton = function(questID, classLabel)
    if not frame or not frame.questShareButton then return 48 end
    local button = frame.questShareButton

    if type(questID) ~= "number" or questID <= 0 then
        button.questID = nil
        button:Hide()
        return 48
    end

    button.questID = questID
    button._fdjClassLabel = classLabel
    button.text:SetText(L("SHARE"))
    local textWidth = button.text:GetStringWidth() or 0
    local width = math.max(70, math.min(104, math.ceil(textWidth + 24)))
    button:SetWidth(width)
    local shareable = FDJ.IsQuestShareable(questID)
    local canShareNow = IsQuestInLog(questID) and shareable
    -- Final dungeon chain quests and every prerequisite step after step 1
    -- should tell the reader that sharing only helps players on that step.
    button._fdjSameStepOnly = QuestNeedsSameStepShareNote(questID)
    FDJ.SetQuestShareButtonVisual(button, shareable, canShareNow)

    button:ClearAllPoints()
    if classLabel then
        -- Class restriction text occupies the far-right header area. Keep the
        -- share control to its left and leave the completion tick unobstructed.
        button:SetPoint("TOPRIGHT", frame.questTextInset, "TOPRIGHT", -174, -10)
        button:Show()
        return 182 + width
    end

    -- Leave room at the far right for the green completion tick.
    button:SetPoint("TOPRIGHT", frame.questTextInset, "TOPRIGHT", -48, -10)
    button:Show()
    return 56 + width
end


-- Prerequisite quests shown by the expandable chain control in the quest list.
-- Only verified prerequisite relationships are included here.
-- Static details for prerequisite quests. These are used when the client has
-- not cached an older quest's text. The data is intentionally concise and
-- mirrors the actual quest objective/start/turn-in rather than relying on the
-- local quest cache.


local expandedQuestChains = {}

local function GetQuestPrereqChain(quest)
    if not quest or not quest.id then return nil end
    local chain = QUEST_PREREQ_CHAINS[quest.id]
    if chain and #chain > 0 then
        return chain
    end
    return nil
end

-- Profession quests show their profession icon where class quests show the class.
local PROFESSION_QUEST_ICONS = {
    BLACKSMITHING = "Interface\\Icons\\Trade_BlackSmithing",
    MINING = "Interface\\Icons\\Trade_Mining",
    LEATHERWORKING = "Interface\\Icons\\Trade_LeatherWorking",
    TAILORING = "Interface\\Icons\\Trade_Tailoring",
    ALCHEMY = "Interface\\Icons\\Trade_Alchemy",
    ENGINEERING = "Interface\\Icons\\Trade_Engineering",
    ENCHANTING = "Interface\\Icons\\Trade_Engraving",
}
FDJ.PROFESSION_QUEST_ICONS = PROFESSION_QUEST_ICONS
-- Raid attunement quests show the raid's icon in the same spot.
FDJ.ATTUNEMENT_QUEST_ICONS = {
    ONYXIA = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\OnyxiaAttuneIcon",
}
-- Every quest of an attunement chain that has its own journal entry.
FDJ.ATTUNEMENT_QUEST_IDS = {
    [4322] = "ONYXIA", [6502] = "ONYXIA",                                   -- Alliance
    [4903] = "ONYXIA", [4974] = "ONYXIA", [6569] = "ONYXIA", [6602] = "ONYXIA", -- Horde
}
local function SetQuestRestrictionIcon(texture, token)
    local attune = type(token) == "string" and token:match("^ATTUNE:(.+)$")
    if attune then
        texture:SetTexture(FDJ.ATTUNEMENT_QUEST_ICONS[attune] or "Interface\\Icons\\INV_Misc_QuestionMark")
        texture:SetTexCoord(0, 1, 0, 1)
        return
    end
    local prof = type(token) == "string" and token:match("^PROF:(.+)$")
    if prof then
        texture:SetTexture(PROFESSION_QUEST_ICONS[prof] or "Interface\\Icons\\INV_Misc_QuestionMark")
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        return
    end
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[token]
    texture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
    if coords then
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function GetQuestClassRestriction(quest)
    if quest and not quest.classOnly and quest.profession then
        local prof = tostring(quest.profession):upper()
        local name = L("PROF_" .. prof)
        if name == "PROF_" .. prof then name = prof end
        return string.upper(name), 0.96, 0.78, 0.45, "PROF:" .. prof
    end
    local attunement = quest and (quest.attunement or (FDJ.ATTUNEMENT_QUEST_IDS and FDJ.ATTUNEMENT_QUEST_IDS[quest.id]))
    if quest and not quest.classOnly and attunement then
        local raid = tostring(attunement):upper()
        local name = L("ATTUNE_" .. raid)
        if name == "ATTUNE_" .. raid then name = raid end
        return string.upper(name), 0.80, 0.55, 1.00, "ATTUNE:" .. raid
    end
    if not quest or not quest.classOnly then return nil end

    -- twoclasses (2.1.0): several classes: all their names, and the colour
    -- and icon of the player's own class when it is one of them.
    local list = type(quest.classOnly) == "table" and quest.classOnly or { quest.classOnly }
    local player
    if UnitClass then
        local ok, _, t = pcall(UnitClass, "player")
        if ok and type(t) == "string" and not (type(issecretvalue) == "function" and issecretvalue(t)) then player = t:upper() end
    end
    local token = tostring(list[1]):upper()
    local names = {}
    for _, c in ipairs(list) do
        local t = tostring(c):upper()
        if player and t == player then token = t end
        names[#names + 1] = t
    end
    -- (classicons, M 19 Nov 2026: "it's missing the paladin class icon"):
    -- the other classes' icons too, after the first one's.
    local others
    for _, t in ipairs(names) do
        if t ~= token then others = others or {} others[#others + 1] = t end
    end
    local className = table.concat(names, " / ")
    local r, g, b = 1, 1, 1

    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[token] then
        local color = RAID_CLASS_COLORS[token]
        r, g, b = color.r or r, color.g or g, color.b or b
    elseif token == "WARLOCK" then
        r, g, b = 0.53, 0.53, 0.93
    end

    return L("CLASS_ONLY", string.upper(className)), r, g, b, token, others
end

local function GetScrollBar(scrollFrame)
    if not scrollFrame then return nil end
    if scrollFrame.ScrollBar then return scrollFrame.ScrollBar end

    local name = scrollFrame.GetName and scrollFrame:GetName()
    if name then
        return _G[name .. "ScrollBar"]
    end
end

local function SetFrameShownSafe(obj, shown)
    if obj and obj.SetShown then
        obj:SetShown(shown)
    elseif obj then
        if shown and obj.Show then
            obj:Show()
        elseif not shown and obj.Hide then
            obj:Hide()
        end
    end
end

local function UpdateScrollBarVisibility(scrollFrame, contentHeight)
    if not scrollFrame then return end

    local viewportHeight = scrollFrame:GetHeight() or 0
    local needsScroll = viewportHeight > 0 and contentHeight > viewportHeight + 4
    local scrollBar = GetScrollBar(scrollFrame)

    SetFrameShownSafe(scrollBar, needsScroll)

    if scrollBar then
        SetFrameShownSafe(scrollBar.ScrollUpButton, needsScroll)
        SetFrameShownSafe(scrollBar.ScrollDownButton, needsScroll)
        SetFrameShownSafe(scrollBar.ThumbTexture, needsScroll)
    end

    local name = scrollFrame.GetName and scrollFrame:GetName()
    if name then
        SetFrameShownSafe(_G[name .. "ScrollBar"], needsScroll)
        SetFrameShownSafe(_G[name .. "ScrollBarScrollUpButton"], needsScroll)
        SetFrameShownSafe(_G[name .. "ScrollBarScrollDownButton"], needsScroll)
        SetFrameShownSafe(_G[name .. "ScrollBarThumbTexture"], needsScroll)
    end

    if not needsScroll then
        -- Quest detail pages are rebuilt asynchronously as quest/item data arrives.
        -- Do not destroy their remembered scroll position during a transient short
        -- redraw; ApplyQuestDetailScroll handles page changes and restoration.
        if not (frame and scrollFrame == frame.questDetailScroll) then
            scrollFrame:SetVerticalScroll(0)
        end
    end
end

local RefreshAll
local ApplyLocalization
local RefreshHomeDungeonCards
local RefreshBossList
local RefreshLoot
local RefreshQuestList
local RefreshQuestDetail

-- questguide: a quest whose steps are HOW to complete it (Data Rescue's
-- punch cards), not quests needed before it (FDJ.QUEST_GUIDE_CHAINS in
-- Data/QuestChains.lua). Its list row gets a small red Guide button in
-- place of the chain icon, its page a How to complete button at the top in
-- place of "Requires a quest chain first." and Show Quest Chain. Both open
-- the steps under the quest in the list, as the chain icon does.
FDJ.IsGuideQuest = function(questID)
    return questID ~= nil and type(FDJ.QUEST_GUIDE_CHAINS) == "table"
        and FDJ.QUEST_GUIDE_CHAINS[questID] == true and QUEST_PREREQ_CHAINS[questID] ~= nil
end
-- The chain a quest needs FIRST: nil for a guide quest.
FDJ.PrereqChainOf = function(questID)
    if questID == nil or FDJ.IsGuideQuest(questID) then return nil end
    return QUEST_PREREQ_CHAINS[questID]
end
-- itemsteps: an item step (Data Rescue's punch cards) is done once its
-- card is in the bags, or a later step's card is (the card was used for the
-- next one), or the quest it is for is done.
FDJ.ItemStepDone = function(chain, index, parentID)
    if type(chain) ~= "table" or not chain[index] or not chain[index].itemStep then return false end
    if parentID and (FDJ.QuestTurnedIn(parentID) or IsQuestFinished(parentID)) then return true end
    local getCount = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not getCount then return false end
    for i = index, #chain do
        local step = chain[i]
        local details = type(step) == "table" and step.itemStep and step.id and QUEST_PREREQ_DETAILS[step.id]
        local item = type(details) == "table" and type(details.startItem) == "table" and details.startItem[1]
        if type(item) == "number" then
            local ok, has = pcall(function() local n = getCount(item) return type(n) == "number" and n > 0 end)
            if ok and has then return true end
        end
    end
    return false
end

-- chainready (2.0.8, M 15 Nov 2026: "make the main quest glow once its
-- available for pickup cause the chain has been completed"): a quest whose
-- chain is all done and that this character can take now: not taken, not
-- done, the level reached, its faction, class and profession. The steps
-- that count are those before the quest itself (a chain that goes on past
-- it, Destruction in Deadmines', stops there); a choice counts once (one of
-- its quests done); an item step by its item; an accept-only step once it is
-- taken.
FDJ.ChainPrereqEnd = function(quest, chain)
    local last = #chain
    for i, step in ipairs(chain) do
        if type(step) == "table" and step.id == quest.id then last = i - 1 break end
    end
    return last
end
FDJ.ChainStepsDone = function(quest, chain, i, stop)
    for k = i, stop do
        local step = chain[k]
        if type(step) == "table" then
            if step.itemStep then
                if FDJ.ItemStepDone(chain, k, quest.id) or (step.id and FDJ.DEV_CHAIN_DONE[step.id]) then return true end
            elseif step.id and FDJ.QuestTurnedIn(step.id) then
                return true
            elseif step.id and step.acceptOnly and IsQuestInLog(step.id) then
                return true
            end
        end
    end
    return false
end
FDJ.QuestChainUnlocked = function(quest)
    if type(quest) ~= "table" or not quest.id then return false end
    local chain = FDJ.PrereqChainOf(quest.id)
    if type(chain) ~= "table" or #chain == 0 then return false end
    if IsQuestInLog(quest.id) or IsQuestFinished(quest.id) or FDJ.QuestTurnedIn(quest.id) then return false end
    if FDJ.QuestCountsForCharacter and not FDJ.QuestCountsForCharacter(quest) then return false end
    if quest.faction == "Alliance" or quest.faction == "Horde" then
        local ok, mine = pcall(UnitFactionGroup, "player")
        if ok and type(mine) == "string" and mine ~= "" and mine ~= quest.faction then return false end
    end
    local okLevel, level = pcall(UnitLevel, "player")
    level = okLevel and tonumber(level) or nil
    if level and tonumber(quest.requires) and level < tonumber(quest.requires) and not FDJ.devChain then return false end -- (devchain: any level)
    local last = FDJ.ChainPrereqEnd(quest, chain)
    if last < 1 then return false end
    local i = 1
    while i <= last do
        local _, choiceLast = FDJ.ChainInChoice(chain, i)
        local stop = math.min(choiceLast or i, last)
        if not FDJ.ChainStepsDone(quest, chain, i, stop) then return false end
        i = stop + 1
    end
    return true
end

-- questrowtrial (2.0.8): the dungeons trying the new quest rows
-- (FDJ.QUESTROW_TRIAL, Data/QuestUpdates.lua), the character's faction, and
-- whether a dungeon's quest list is locked to it (option "Show both
-- factions' quests" off).
FDJ.QuestRowTrial = function(dungeonName)
    if dungeonName == nil then return false end
    if FDJ.QUESTROW_ALL then return true end -- questrowall: every dungeon
    return type(FDJ.QUESTROW_TRIAL) == "table" and FDJ.QUESTROW_TRIAL[dungeonName] == true
end
FDJ.PlayerFaction = function()
    local ok, f = pcall(UnitFactionGroup, "player")
    if ok and (f == "Alliance" or f == "Horde") then return f end
    return nil
end
FDJ.FactionLocked = function(dungeonName)
    return FDJ.QuestRowTrial(dungeonName) and ForeverDungeonJournalDB.showBothFactions ~= true and FDJ.PlayerFaction() ~= nil
end
-- a quest of the other faction, in a list locked to the character's
FDJ.FactionHiddenFor = function(dungeonName, faction)
    return FDJ.FactionLocked(dungeonName) and (faction == "Alliance" or faction == "Horde") and faction ~= FDJ.PlayerFaction()
end
-- The chain step to do next before a quest can be taken (nil: none left).
FDJ.NextChainStep = function(quest)
    local chain = type(quest) == "table" and FDJ.PrereqChainOf(quest.id)
    if type(chain) ~= "table" then return nil end
    local last, i = FDJ.ChainPrereqEnd(quest, chain), 1
    while i <= last do
        local _, choiceLast = FDJ.ChainInChoice(chain, i)
        local stop = math.min(choiceLast or i, last)
        if not FDJ.ChainStepsDone(quest, chain, i, stop) then return chain[i] end
        i = stop + 1
    end
    return nil
end
-- pickonmap (2.0.8, M 15 Nov 2026: "it should say show pickup on map"):
-- where the quest is picked up on the map (as the quest page's Show on
-- Map), or nil when it has no spot there.
FDJ.PickUpOnMapSpot = function(quest)
    if type(quest) ~= "table" or not quest.id then return nil end
    return quest.startMap or QUEST_START_MAPS[quest.id]
end
-- The round ! clicked: its quest chain not done yet, the chain step to do
-- next (its page, the chain unfolded, as Show Quest Chain does: chainfirst,
-- M 15 Nov 2026: players ran to the quest giver without knowing it needs a
-- chain first); the chain done (or none): where the quest is picked up, on
-- the map (pickonmap); with no spot on the map, its page (an item that
-- starts it, a quest given inside the dungeon).
FDJ.ShowHowToPickUp = function(quest, dungeonName)
    if type(quest) ~= "table" or not quest.id then return end
    local firstStep = FDJ.NextChainStep(quest) -- chainfirst (2.0.8)
    if firstStep and firstStep.id and FDJ.OpenQuestChainStep then
        FDJ.OpenQuestChainStep(dungeonName, quest.id, firstStep.id)
        return
    end
    if FDJ.PickUpOnMapSpot(quest) and FDJ.MapMarkers then
        FDJ.pendingMarkerQuestTitle = QuestField(quest.id, "name", quest.name)
        FDJ.pendingMarkerTurnIn = nil
        FDJ.pendingMarkerQuestID = quest.id
        if quest.startMap and FDJ.MapMarkers.ShowRecordedLocationOnMap then
            FDJ.MapMarkers.ShowRecordedLocationOnMap(quest.startMap, quest.startMap.label)
            return
        elseif FDJ.MapMarkers.ShowQuestStartOnMap then
            FDJ.MapMarkers.ShowQuestStartOnMap(quest)
            return
        end
    end
    local step = FDJ.NextChainStep(quest)
    if step and step.id and FDJ.OpenQuestChainStep then
        FDJ.OpenQuestChainStep(dungeonName, quest.id, step.id)
        return
    end
    local show = (FDJ.MapMarkers and FDJ.MapMarkers.ShowQuestStartOnMap) or ShowQuestStartOnMap
    if QUEST_START_MAPS[quest.id] and show then
        FDJ.pendingMarkerQuestTitle = QuestField(quest.id, "name", quest.name)
        FDJ.pendingMarkerTurnIn = nil
        FDJ.pendingMarkerQuestID = quest.id
        show(quest)
        return
    end
    if FDJ.OpenQuestPage then FDJ.OpenQuestPage(dungeonName, quest.id) end
end

-- The step to open: the one after the last step whose item is in the bags
-- (a Yellow Punch Card in the bags opens step 3), else the first.
FDJ.GuideTargetStep = function(chain)
    if type(chain) ~= "table" or #chain == 0 then return nil end
    local getCount = (C_Item and C_Item.GetItemCount) or GetItemCount
    local last
    for i, step in ipairs(chain) do
        if type(step) == "table" and step.id and not step.itemStep and IsQuestInLog(step.id) then return step end
        local details = type(step) == "table" and step.id and QUEST_PREREQ_DETAILS[step.id]
        local item = type(details) == "table" and type(details.startItem) == "table" and details.startItem[1]
        if type(item) == "number" and getCount then
            local ok, has = pcall(function() local n = getCount(item) return type(n) == "number" and n > 0 end)
            if ok and has == true then last = i end
        end
    end
    return chain[last and math.min(last + 1, #chain) or 1]
end
FDJ.OpenQuestGuide = function(questID, parentName)
    local chain = questID and QUEST_PREREQ_CHAINS[questID]
    if type(chain) ~= "table" then return end
    expandedQuestChains[questID] = true
    local target = FDJ.GuideTargetStep(chain)
    selectedPrereqStep = target
    selectedPrereqParentQuestName = parentName
    selectedPrereqParentQuestID = questID
    if target and target.id and not target.itemStep then RequestQuestRewardData(target.id) end
    RefreshQuestList()
    RefreshQuestDetail()
end
-- The red Guide button of a guide quest's list row, in the chain icon's
-- spot right after "Available from Level X". Created on first use.
FDJ.SetRowGuideButton = function(button, show)
    local guide = button.guideToggle
    if not show then
        if guide then guide:Hide() end
        return nil
    end
    if not guide then
        guide = CreateFrame("Button", nil, button, "UIPanelButtonTemplate")
        FDJ.OwnFonts(guide) -- ownfonts (2.0.8)
        button.guideToggle = guide
        guide:SetHeight(18)
        guide:SetFrameLevel(button:GetFrameLevel() + 6)
        guide:RegisterForClicks("LeftButtonUp")
        guide:SetNormalFontObject("ForeverDJ_GameFontNormalSmall")
        guide:SetHighlightFontObject("ForeverDJ_GameFontHighlightSmall")
        guide:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L("HOW_TO_COMPLETE"), 1, 0.82, 0.25)
            GameTooltip:AddLine(L("GUIDE_TIP"), 0.85, 0.85, 0.85)
            GameTooltip:Show()
        end)
        guide:SetScript("OnLeave", function() GameTooltip:Hide() end)
        guide:SetScript("OnClick", function(self)
            local owner = self:GetParent()
            if not owner or not owner.questID then return end
            expandedQuestChains[owner.questID] = not expandedQuestChains[owner.questID]
            RefreshQuestList()
        end)
    end
    guide:SetText(L("GUIDE"))
    local fs = guide:GetFontString()
    if fs then fs:SetTextColor(1.00, 0.82, 0.27) end -- as the Dungeons button
    guide:SetWidth(math.max(42, math.ceil(((fs and fs:GetStringWidth()) or 28) + 14)))
    guide:ClearAllPoints()
    local metaWidth, wrappedY = FDJ.MetaIconSpot(button.meta)
    if wrappedY then
        guide:SetPoint("LEFT", button.meta, "BOTTOMLEFT", metaWidth + 6, wrappedY)
    else
        guide:SetPoint("LEFT", button.meta, "LEFT", metaWidth + 6, 0)
    end
    guide:Show()
    return guide
end
-- The row control that opens the steps: the Guide button or the chain icon.
FDJ.RowChainControl = function(button)
    if button.guideToggle and button.guideToggle:IsShown() then return button.guideToggle end
    return button.chainToggle
end
-- The How to complete button at the top of a guide quest's page (after a
-- red warning, before Objective). Returns the new cursorY.
FDJ.PlaceGuideButton = function(quest, cursorY)
    local button = frame and frame.questGuideButton
    if not (type(quest) == "table" and FDJ.IsGuideQuest(quest.id)) then
        if button then button.questID = nil; button:Hide() end
        return cursorY
    end
    if not button then
        button = CreateFrame("Button", nil, frame.questDetailContent, "UIPanelButtonTemplate")
        FDJ.OwnFonts(button) -- ownfonts (2.0.8)
        frame.questGuideButton = button
        button:SetHeight(24)
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnClick", function(self)
            if self.questID then FDJ.OpenQuestGuide(self.questID, self.parentQuestName) end
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L("HOW_TO_COMPLETE"), 1, 0.82, 0.25)
            GameTooltip:AddLine(L("GUIDE_TIP"), 0.85, 0.85, 0.85)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    button.questID = quest.id
    button.parentQuestName = quest.name
    button:SetText(L("HOW_TO_COMPLETE"))
    local fs = button:GetFontString()
    button:SetWidth(math.max(112, math.min(220, math.ceil(((fs and fs:GetStringWidth()) or 90) + 24))))
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
    button:Show()
    return cursorY + 33
end
-- summonhelp (2.0.9, M 16 Nov 2026, Gahz'rilla): a quest for a boss that has
-- to be summoned (summonHelp on the quest: { boss, item, page, quest }): a
-- red line saying so above Objective, then "How to summon <boss>", which
-- opens the item's quest chain (the Mallet of Zul'Farrak) at the step not
-- done yet. Returns the new cursorY.
FDJ.PlaceSummonHelp = function(quest, cursorY)
    local help = type(quest) == "table" and type(quest.summonHelp) == "table" and quest.summonHelp or nil
    local note, button = frame and frame.questSummonNote, frame and frame.questSummonButton
    if not help then
        if note then note:Hide() end
        if button then button.help = nil; button:Hide() end
        return cursorY
    end
    if not note then
        note = frame.questDetailContent:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
        note:SetJustifyH("LEFT")
        frame.questSummonNote = note
    end
    if not button then
        button = CreateFrame("Button", nil, frame.questDetailContent, "UIPanelButtonTemplate")
        FDJ.OwnFonts(button) -- ownfonts (2.0.8)
        frame.questSummonButton = button
        button:SetHeight(24)
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnClick", function(self)
            local h = self.help
            if not (h and FDJ.OpenQuestChain) then return end
            local stepID
            for _, step in ipairs(QUEST_PREREQ_CHAINS[h.quest] or {}) do
                if type(step) == "table" and step.id and not FDJ.QuestTurnedIn(step.id) then
                    stepID = step.id
                    break
                end
            end
            GameTooltip:Hide()
            FDJ.OpenQuestChain(h.page, h.quest, stepID)
        end)
    end
    local bossName = BossName(help.boss)
    local itemName = help.itemName
    if help.item and FDJ.CanUseClientLocalizedText and FDJ.CanUseClientLocalizedText() then
        local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        local ok, name = pcall(getInfo, help.item)
        if ok and type(name) == "string" and name ~= "" then itemName = name end
    end
    note:ClearAllPoints()
    note:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
    note:SetWidth(math.max(120, (frame.questDetailContent:GetWidth() or 360) - 8))
    note:SetText(L("SUMMON_QUEST_NOTE", bossName, itemName or ""))
    FDJ.WarningFont(note) -- warnfont: its font and colour (Core/Fonts.lua)
    note:Show()
    cursorY = cursorY + (note:GetStringHeight() or 28) + 8
    button.help = help
    button:SetText(L("HOW_TO_SUMMON", bossName))
    local fs = button:GetFontString()
    button:SetWidth(math.max(112, math.min(240, math.ceil(((fs and fs:GetStringWidth()) or 90) + 24))))
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
    button:Show()
    return cursorY + 33
end
-- A step page's label under its title: "Guide: step 2 of 5" for a guide
-- quest's steps, "Required prerequisite" otherwise.
FDJ.StepMetaLabel = function(step)
    local parentID = selectedPrereqParentQuestID
    if parentID and FDJ.IsGuideQuest(parentID) then
        local chain = QUEST_PREREQ_CHAINS[parentID]
        for i, s in ipairs(chain) do
            if s == step or (type(step) == "table" and s.id and s.id == step.id) then return L("GUIDE_STEP", i, #chain) end
        end
        return L("GUIDE")
    end
    return L("REQUIRED_PREREQUISITE")
end
local SetMode
local SelectBoss
local SelectQuest
local SelectQuestByID
local SetQuestFaction
local ShowDungeonMap
local HideDungeonMap
local SelectDungeon
local ShowHomePage
local ShowDungeonPage
local ShowRouteGuide

local function ApplySelectedLanguage(code)
    local wasRouteOpen = frame and frame.routePanel and frame.routePanel:IsShown()
    local wasMapOpen = frame and frame.dungeonMapPanel and frame.dungeonMapPanel:IsShown()
    local mapFloor = frame and frame.dungeonMapFloor
    if FDJ.SetLanguage then FDJ.SetLanguage(code) end
    UpdateLanguageControl()
    if ApplyLocalization then ApplyLocalization() end
    if frame and frame.RefreshSearchResults and frame.searchEditBox then
        frame.RefreshSearchResults(frame.searchEditBox:GetText() or "")
    end
    if frame then
        if frame.currentView == "home" then
            RefreshHomeDungeonCards()
        else
            FDJ.keepQuestState = true
            local okRefresh, refreshError = pcall(RefreshAll)
            FDJ.keepQuestState = nil
            if not okRefresh then error(refreshError, 0) end
            if wasRouteOpen and ShowRouteGuide then
                ShowRouteGuide()
            end
            -- Stay on the map (and the same floor) when it was open.
            if wasMapOpen and not wasRouteOpen and ShowDungeonMap and FDJ.DUNGEON_MAPS[selectedDungeon] then
                ShowDungeonMap()
                if mapFloor and FDJ.RenderCustomDungeonMap then
                    FDJ.RenderCustomDungeonMap(FDJ.DUNGEON_MAPS[selectedDungeon], mapFloor)
                end
            end
        end
        ApplyLocaleFontTree(frame)
    end
end

-- ============================================================
-- ENCOUNTER JOURNAL PORTRAITS
-- ============================================================
--
-- v0.2.0's portrait scan passed the journal instance ID to
-- EJ_GetEncounterInfoByIndex() before selecting an Encounter Journal
-- instance. Blizzard's API has a quirk where that can return nil.
--
-- v0.7.0 explicitly selects each instance first and THEN enumerates its
-- encounters. We prefer the creature display ID, exactly like Blizzard's
-- portrait utilities do.
-- ============================================================

local function ScanEncounterJournal()
    wipe(journalCache)

    if type(EJ_GetInstanceByIndex) ~= "function"
        or type(EJ_SelectInstance) ~= "function"
        or type(EJ_GetEncounterInfoByIndex) ~= "function"
        or type(EJ_GetCreatureInfo) ~= "function"
    then
        return
    end

    -- Forever adds its new dungeons in a separate Encounter Journal tier.
    -- v1.0.21 only scanned whichever tier Blizzard happened to have selected,
    -- which is why Ruins/Hall portraits could all become question marks.
    -- Scan every available tier, then every dungeon in that tier.
    local tiers = { nil }
    if type(EJ_GetNumTiers) == "function" and type(EJ_SelectTier) == "function" then
        local ok, numTiers = pcall(EJ_GetNumTiers)
        if ok and type(numTiers) == "number" and numTiers > 0 then
            tiers = {}
            for tier = 1, numTiers do
                tiers[#tiers + 1] = tier
            end
        end
    end

    for _, tier in ipairs(tiers) do
        if tier and type(EJ_SelectTier) == "function" then
            pcall(EJ_SelectTier, tier)
        end

        for instanceIndex = 1, 200 do
            local okInstance, instanceID, instanceName = pcall(EJ_GetInstanceByIndex, instanceIndex, false)
            if not okInstance or not instanceID then
                break
            end

            local dungeonName = NormalizeDungeonName(instanceName)

            if dungeonName and DB[dungeonName] then
                pcall(EJ_SelectInstance, instanceID)

                local cache = journalCache[dungeonName] or {
                    instanceID = instanceID,
                    encounters = {},
                }
                journalCache[dungeonName] = cache

                for encounterIndex = 1, 40 do
                    -- Different Classic branches disagree on whether instanceID
                    -- is required here, so try the explicit form first and fall
                    -- back to the selected-instance form.
                    local okEncounter, encounterName, encounterDescription, encounterID =
                        pcall(EJ_GetEncounterInfoByIndex, encounterIndex, instanceID)

                    if (not okEncounter) or not encounterName or not encounterID then
                        okEncounter, encounterName, encounterDescription, encounterID =
                            pcall(EJ_GetEncounterInfoByIndex, encounterIndex)
                    end

                    if (not okEncounter) or not encounterName or not encounterID then
                        break
                    end

                    local okCreature,
                          creatureID,
                          creatureName,
                          creatureDescription,
                          displayInfo,
                          iconImage,
                          uiModelSceneID = pcall(EJ_GetCreatureInfo, 1, encounterID)

                    if okCreature then
                        local data = {
                            encounterID = encounterID,
                            name = encounterName,
                            description = encounterDescription,
                            creatureID = creatureID,
                            creatureName = creatureName,
                            creatureDescription = creatureDescription,
                            displayInfo = displayInfo,
                            iconImage = iconImage,
                            uiModelSceneID = uiModelSceneID,
                        }

                        if type(encounterName) == "string" and encounterName ~= "" then
                            cache.encounters[encounterName:lower()] = data
                        end

                        if type(creatureName) == "string" and creatureName ~= "" then
                            cache.encounters[creatureName:lower()] = data
                        end
                    end
                end
            end
        end
    end
end

local function GetBossJournalData(dungeonName, boss)
    local cache = journalCache[dungeonName]
    if not cache or not boss then return nil end

    local aliases = boss.aliases or { boss.name }

    for _, alias in ipairs(aliases) do
        local data = cache.encounters[alias:lower()]
        if data then return data end
    end
end

local function RefreshPortraitPanels()
    if not frame or not frame:IsShown() then
        return
    end

    if frame.currentView == "home" and ShowHomePage then
        ShowHomePage()
        return
    end

    if RefreshBossList then
        RefreshBossList()
    end

    if RefreshLoot then
        RefreshLoot()
    end
end

-- Legacy bosses and any already-known Forever boss remain purely 2D.  The
-- resolver below is only a one-time bootstrap for a Forever-only NPC whose
-- display ID is otherwise unavailable. It never preloads or runs while zoning.
local function FinishPortraitResolve(request, displayID)
    if portraitResolveCurrent ~= request or request.serial ~= portraitResolveSerial then return end

    if type(displayID) == "number" and displayID > 0 then
        displayIDCache[request.npcID] = displayID
        portraitRetryAt[request.npcID] = nil
        if FDJ.WarmPortraitDisplay then pcall(FDJ.WarmPortraitDisplay, displayID) end
    else
        -- Uncached creatures often need a second request: try again in two
        -- seconds by itself (up to five times), not only on the next click.
        portraitRetryAt[request.npcID] = (GetTime and GetTime() or 0) + 2
        FDJ.portraitResolveTries = FDJ.portraitResolveTries or {}
        local npcID = request.npcID
        local tries = (FDJ.portraitResolveTries[npcID] or 0) + 1
        FDJ.portraitResolveTries[npcID] = tries
        if tries < 5 and C_Timer and C_Timer.After then
            C_Timer.After(2.05, function()
                if FDJ.QueuePortraitResolve then FDJ.QueuePortraitResolve(npcID) end
            end)
        end
    end

    request.model:SetScript("OnModelLoaded", nil)
    if request.model.ClearModel then
        pcall(request.model.ClearModel, request.model)
    end
    request.model:Hide()

    portraitResolveQueued[request.npcID] = nil
    portraitResolveCurrent = nil
    RefreshPortraitPanels()
end

local function StartNextPortraitResolve()
    if portraitResolveCurrent or not portraitResolver then return end
    -- While the journal is open, or in the background once the portrait
    -- warm-up has started; never during a loading screen.
    if not frame or not (frame:IsShown() or FDJ.portraitWarmup) or FDJ.portraitZoning then return end
    if FDJ.LookupsPaused and FDJ.LookupsPaused() then return end -- loadpause (2.0.7)

    local now = GetTime and GetTime() or 0
    if now < (portraitResolveBlockedUntil or 0) then return end

    local npcID = table.remove(portraitResolveQueue, 1)
    if not npcID then return end

    -- rtvcap (2.0.9): one hidden model for every look-up (one at a time),
    -- not one per creature kept for the session.
    local model = portraitModels[1]
    if not model then
        model = CreateFrame("PlayerModel", nil, UIParent)
        model:SetSize(1, 1)
        model:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        model:SetAlpha(0)
        portraitModels[1] = model
    end

    portraitResolveSerial = portraitResolveSerial + 1
    local request = {
        npcID = npcID,
        model = model,
        serial = portraitResolveSerial,
        elapsed = 0,
    }
    portraitResolveCurrent = request

    model:SetScript("OnModelLoaded", nil)
    model:Show()
    if model.ClearModel then pcall(model.ClearModel, model) end

    local ok, previousID = pcall(model.GetDisplayInfo, model)
    request.previousID = ok and previousID or nil

    model:SetScript("OnModelLoaded", function()
        if portraitResolveCurrent == request and request.serial == portraitResolveSerial then
            request.loaded = true
        end
    end)

    local started = pcall(model.SetCreature, model, npcID)
    if not started then request.failed = true end
end

local function QueuePortraitResolve(npcID)
    if not npcID or displayIDCache[npcID] or portraitResolveQueued[npcID] then return end
    if not frame or not (frame:IsShown() or FDJ.portraitWarmup) then return end

    local now = GetTime and GetTime() or 0
    if now < (portraitResolveBlockedUntil or 0) then return end
    if portraitRetryAt[npcID] and now < portraitRetryAt[npcID] then return end

    portraitResolveQueued[npcID] = true
    table.insert(portraitResolveQueue, npcID)
    if portraitResolver then portraitResolver:Show() end
end
FDJ.QueuePortraitResolve = QueuePortraitResolve

local function CreatePortraitResolver()
    portraitResolver = CreateFrame("Frame")
    portraitResolver:SetScript("OnUpdate", function(self, elapsed)
        if not portraitResolveCurrent then
            if #portraitResolveQueue == 0 then
                self:Hide()
                return
            end
            StartNextPortraitResolve()
            return
        end

        local request = portraitResolveCurrent
        request.elapsed = request.elapsed + elapsed

        if request.failed then
            FinishPortraitResolve(request, nil)
            return
        end

        if request.loaded or request.elapsed >= 0.10 then
            local ok, displayID = pcall(request.model.GetDisplayInfo, request.model)
            if ok and type(displayID) == "number" and displayID > 0
                and (request.loaded or displayID ~= request.previousID)
            then
                FinishPortraitResolve(request, displayID)
                return
            end
        end

        if request.elapsed >= 3.0 then
            FinishPortraitResolve(request, nil)
        end
    end)
    portraitResolver:Hide()
end

-- v1.0.24: initialize the resolver. v1.0.23 defined the queue/OnUpdate
-- machinery but never actually created this frame, so Forever-only bosses with
-- numeric NPC IDs were queued forever and stayed as question marks.
CreatePortraitResolver()

local function ResetPortraitResolver()
    portraitResolveSerial = portraitResolveSerial + 1
    for _, model in pairs(portraitModels) do
        model:SetScript("OnModelLoaded", nil)
        if model.ClearModel then pcall(model.ClearModel, model) end
        model:Hide()
    end
    wipe(portraitResolveQueue)
    wipe(portraitResolveQueued)
    wipe(portraitRetryAt)
    portraitResolveCurrent = nil
    if portraitResolver then portraitResolver:Hide() end
end

-- loadpause (2.0.7): the background lookups that ask the server about
-- something (a creature's look through a hidden model: Forever bosses, trash
-- mobs, the arrow's NPC; item IDs) stop for every loading screen and go on a
-- few seconds after arriving. A first login (nothing saved yet) walked
-- straight into a dungeon while they were still running and the loading
-- screen hung at 80%. Going in, the hidden models still loading are put away
-- (cleared and hidden); what they were asking is asked again afterwards.
FDJ.LOOKUP_RESUME_DELAY = 5
FDJ.LookupsPaused = function()
    if FDJ.portraitZoning then return true end
    -- noinstance (2.0.7): never inside a dungeon. 2.0.6 players got a loading
    -- screen flickering for ever going in or out of Wailing Caverns (Discord,
    -- 14 Nov 2026) while these hidden model lookups were running; they wait
    -- until you are back outside.
    if type(IsInInstance) == "function" then
        local ok, inside = pcall(IsInInstance)
        if ok and inside then return true end
    end
    local now = GetTime and GetTime() or 0
    return now < (FDJ.lookupsResumeAt or 0)
end
-- The boss portrait lookup still running: its model put away, its NPC back
-- at the front of the queue.
FDJ.PausePortraitLookup = function()
    local request = portraitResolveCurrent
    if request then
        portraitResolveSerial = portraitResolveSerial + 1
        request.model:SetScript("OnModelLoaded", nil)
        if request.model.ClearModel then pcall(request.model.ClearModel, request.model) end
        request.model:Hide()
        portraitResolveCurrent = nil
        table.insert(portraitResolveQueue, 1, request.npcID)
    end
    if portraitResolver then portraitResolver:Hide() end
end

-- Creature portraits go through Systems/PortraitPool.lua, which renders each
-- one off-screen and only moves it into view once it has loaded.
local function TrySetDisplayPortrait(texture, displayID)
    if not FDJ.AcquirePortrait then return false end
    local ok, shown = pcall(FDJ.AcquirePortrait, texture, displayID)
    return ok and shown == true
end

-- pairportrait (2.0.9, M 16 Nov 2026: Jarien and Sothos, "they are
-- together, so if you could put the portraits together in the boss entry";
-- then "get rid of the silver portrait. Have those portraits be the same
-- size ... close to each other"): a boss entry for two (boss.pairNpcID)
-- has both portraits side by side, the same size (paired), the second
-- just right of the first, overlapping it a little, and no rare frame.
-- normal: the first portrait's size otherwise. Returns the second portrait
-- (the name goes right of it), or nil. holder.fdjPair is made on the
-- first such entry; it stays shown while it waits for its picture (the
-- portrait pool gives one only to a texture on screen). (An FDJ field:
-- this chunk is at Lua's limit of locals.)
FDJ.SetPairPortrait = function(holder, main, boss, normal, paired)
    local pair = boss and type(boss.pairNpcID) == "number" and boss.pairNpcID or nil
    local t = holder.fdjPair
    if not pair then
        main:SetSize(normal, normal)
        if t then
            if FDJ.ReleasePortrait then pcall(FDJ.ReleasePortrait, t) end
            t:SetTexture(nil)
            t:Hide()
        end
        return nil
    end
    if not t then
        t = holder:CreateTexture(nil, "ARTWORK", nil, 3)
        holder.fdjPair = t
    end
    main:SetSize(paired, paired)
    t:SetSize(paired, paired)
    t:ClearAllPoints()
    t:SetPoint("LEFT", main, "RIGHT", -math.floor(paired * 0.18 + 0.5), 0)
    t:SetTexCoord(main:GetTexCoord())
    t:Show()
    if FDJ.ReleasePortrait then pcall(FDJ.ReleasePortrait, t) end
    t:SetTexture(nil)
    TrySetDisplayPortrait(t, STATIC_DISPLAY_IDS[pair])
    return t
end

local function SetBossPortrait(texture, dungeonName, boss)
    if boss and boss.fdjDungeon then dungeonName = boss.fdjDungeon end
    -- Never allow a portrait from the previously selected boss to bleed into
    -- this render while a lookup fails or data is still loading. A portrait
    -- drawn from a display ID is kept until we know the new one differs.
    -- (The pooled portrait is handed back here; asking for the same one again
    -- just below puts it straight back without redrawing it.)
    if FDJ.ReleasePortrait then pcall(FDJ.ReleasePortrait, texture) end
    texture:SetTexture(nil)
    texture:SetAlpha(1)
    texture:SetTexCoord(0, 1, 0, 1)

    -- Trash Drops uses a custom bag-only icon with no background.
    -- Keep this synthetic row on a simple 2D texture so it never touches the
    -- NPC/model portrait resolver.
    if boss and boss.recipeTab then
        texture:SetTexture("Interface\\Icons\\INV_Scroll_05")
        texture:SetTexCoord(0, 1, 0, 1)
        return true
    end
    if boss and boss.lootChest then
        texture:SetTexture("Interface\\Icons\\INV_Box_01")
        texture:SetTexCoord(0, 1, 0, 1)
        return true
    end
    if boss and boss.trash then
        texture:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\TrashDropsIcon")
        texture:SetTexCoord(0, 1, 0, 1)
        return true
    end

    local npcID = BossNpcID(boss)
    local data = GetBossJournalData(dungeonName, boss)

    -- Forever-only records may not have a hand-entered NPC ID yet. The
    -- Encounter Journal creature ID is numeric and safe to use as identity.
    if (not npcID) and data and type(data.creatureID) == "number" and data.creatureID > 0 then
        npcID = data.creatureID
    end
    -- A creature with the boss's look, used for the picture only (The
    -- Drowned City's bosses are known by their test copies so far).
    if (not npcID) and boss and type(boss.portraitNpcID) == "number" then
        npcID = boss.portraitNpcID
    end

    -- 1) Explicit bundled portrait art. Used only when we have a verified clean
    -- asset (currently Lordaeron Captain). Put this before journal/model lookup so
    -- a bad or missing Forever display never overrides the intended portrait.
    if boss.customIcon then
        texture:SetTexture(boss.customIcon)
        texture:SetTexCoord(0, 1, 0, 1)
        return true
    end

    -- 2) Explicit display ID on the boss record.
    if TrySetDisplayPortrait(texture, boss.displayID) then
        return true
    end

    -- 2) Blizzard's current Encounter Journal display is the cleanest source
    -- for Forever bosses and updates automatically when the beta model changes.
    if data and TrySetDisplayPortrait(texture, data.displayInfo) then
        return true
    end

    -- 3) Exact 2D portrait captured from the live unit, keyed by numeric NPC ID.
    -- No UnitName comparisons are involved, so this is safe with secret strings.
    local livePortrait = npcID and portraitTexturesByNpcID[npcID]
    if livePortrait then
        texture:SetTexture(livePortrait)
        texture:SetTexCoord(0.04, 0.96, 0.04, 0.96)
        return true
    end

    -- 4) Verified bundled Classic display IDs. Prefer these to any saved
    -- derived cache so an old bad cache entry can never override known data.
    if npcID and TrySetDisplayPortrait(texture, STATIC_DISPLAY_IDS[npcID]) then
        return true
    end

    -- 5) Reuse a display ID resolved by earlier addon versions for bosses that
    -- do not have a verified bundled Classic display ID.
    if npcID and not STATIC_DISPLAY_IDS[npcID]
        and TrySetDisplayPortrait(texture, displayIDCache[npcID]) then
        return true
    end

    -- 6) Forever bosses often have a numeric NPC ID but no journal portrait.
    -- Resolve the CreatureDisplayID directly from that numeric ID with a tiny
    -- hidden PlayerModel. This never touches UnitGUID(), UnitName(), or any
    -- secret-string value, so it is safe on the Forever client. Once resolved,
    -- the display ID is cached and all future draws are plain 2D portraits.
    if npcID then
        QueuePortraitResolve(npcID)
    end


    if data and data.iconImage and data.iconImage ~= 0 then
        texture:SetTexture(data.iconImage)
        return true
    end

    texture:SetTexture(nil)
    return false
end
-- The Run Log (Systems/RunLogUI.lua) draws the same boss portraits.
FDJ.SetBossPortrait = SetBossPortrait

-- Right-click on any empty part of the journal goes back one page:
-- route guide / map -> the tab it was opened from, quests <-> bosses back to
-- the previously used tab, dungeon page -> dungeon list.
FDJ.GoBackPage = function()
    if not frame or not frame:IsShown() then return end
    if frame.routePanel and frame.routePanel:IsShown() then
        SetMode(selectedMode); return
    end
    if frame.dungeonMapPanel and frame.dungeonMapPanel:IsShown() then
        SetMode(selectedMode); return
    end
    if frame.currentView == "dungeon" then
        local prev = frame.fdjPrevMode
        frame.fdjPrevMode = nil
        if prev and prev ~= selectedMode then
            SetMode(prev)
        else
            ShowHomePage()
        end
    end
end

FDJ.InstallRightClickBack = function()
    if not frame or frame.fdjRightClickBack then return end
    frame.fdjRightClickBack = true
    local skip = { Button = true, CheckButton = true, EditBox = true, Slider = true }
    local function onUp(_, button)
        if button == "RightButton" then FDJ.GoBackPage() end
    end
    local function walk(f)
        local t = f.GetObjectType and f:GetObjectType()
        if not skip[t] then
            if f.IsMouseEnabled and f:IsMouseEnabled() and f.HookScript then
                f:HookScript("OnMouseUp", onUp)
            end
            for _, child in ipairs({ f:GetChildren() }) do walk(child) end
        end
    end
    frame:EnableMouse(true)
    walk(frame)
end

-- Every boss portrait, prepared in the background once per session: it
-- starts 6 s after logging in (or when the journal first opens, if that is
-- sooner), a few bosses per frame, and waits out combat and loading screens.
-- Bundled pictures cost nothing; portraits the game has to draw are rendered
-- off-screen and kept (Systems/PortraitPool.lua), and Forever bosses whose
-- display is not known yet are looked up and saved, so the journal shows
-- them at once.
local prewarmTexture
FDJ.PrewarmBossPortraits = function()
    if not frame or FDJ.portraitsPrewarmed then return end
    FDJ.portraitsPrewarmed = true
    FDJ.portraitWarmup = true
    if not prewarmTexture then
        prewarmTexture = frame:CreateTexture(nil, "BACKGROUND")
        prewarmTexture:SetSize(1, 1)
        prewarmTexture:Hide()
    end
    local work = {}
    -- rtvcap (2.0.9, a player's report: graphics device lost over and over
    -- in Ragefire Chasm, the game's render target slots used up): every
    -- portrait the game draws is a render target, so the warm-up no longer
    -- draws every boss of every dungeon (some 125) and every Trash Drops mob:
    -- only the bosses of the dungeon the journal opens on. The others are
    -- drawn when their page is opened (Systems/PortraitPool.lua keeps at most
    -- PORTRAIT_LIVE_MAX).
    local dungeon = selectedDungeon and DB[selectedDungeon]
    for _, boss in ipairs((dungeon and dungeon.bosses) or {}) do
        if not boss.trash then work[#work + 1] = { selectedDungeon, boss } end
    end
    local index = 0
    -- loginlag (2.0.8, DeadLeaves on Discord, 15 Nov 2026: a few seconds of
    -- lag after every login and /reload): the warm-up drew up to 6 portraits
    -- every 0.05 s (some 250 renders in 5 s, each loading a creature model).
    -- Now at most one new render a step, a step every 0.1 s, a step stopping
    -- after 3 ms; the bundled pictures and ones drawn already still go
    -- several at a time. No spare copies while warming (EnsureSpare).
    local function Step()
        if FDJ.portraitZoning or (type(InCombatLockdown) == "function" and InCombatLockdown()) then
            if C_Timer and C_Timer.After then C_Timer.After(1, Step) end
            return
        end
        local clock = type(debugprofilestop) == "function" and debugprofilestop or nil
        local started, rendersBefore = clock and clock() or nil, FDJ.portraitRenders or 0
        FDJ.portraitNoSpare = true
        for _ = 1, 6 do
            index = index + 1
            local job = work[index]
            if not job then break end
            if job[3] then
                pcall(TrySetDisplayPortrait, prewarmTexture, job[3])
            else
                pcall(SetBossPortrait, prewarmTexture, job[1], job[2])
            end
            if (FDJ.portraitRenders or 0) > rendersBefore then break end
            if started and clock() - started > 3 then break end
        end
        FDJ.portraitNoSpare = nil
        if portraitResolver and #portraitResolveQueue > 0 then portraitResolver:Show() end
        if work[index + 1] and C_Timer and C_Timer.After then C_Timer.After(0.1, Step) end
    end
    Step()
end
-- A display found by the background lookup: render it now.
FDJ.WarmPortraitDisplay = function(displayID)
    if prewarmTexture then TrySetDisplayPortrait(prewarmTexture, displayID) end
end

-- v1.0.23: live unit portrait capture intentionally removed.
-- Forever marks UnitGUID()/UnitName() as secret strings in this build, so
-- parsing or comparing them can taint execution. Portrait resolution now uses
-- only addon-owned numeric NPC IDs and Encounter Journal numeric data.


-- ============================================================
-- TOOLTIP
-- ============================================================

local function CreateItemTooltip()
    -- Item hovers use the game's own GameTooltip, so other tooltip addons
    -- (Pawn upgrade scores, vendor prices, bag counts, ...) add their lines
    -- exactly as on any other item tooltip. A private tooltip frame is not
    -- hooked by them.
    itemTooltip = GameTooltip or CreateFrame(
        "GameTooltip",
        "ForeverDungeonJournalItemTooltip",
        UIParent,
        "GameTooltipTemplate"
    )

    compareTooltip1 = CreateFrame(
        "GameTooltip",
        "ForeverDungeonJournalCompareTooltip1",
        UIParent,
        "GameTooltipTemplate"
    )

    compareTooltip2 = CreateFrame(
        "GameTooltip",
        "ForeverDungeonJournalCompareTooltip2",
        UIParent,
        "GameTooltipTemplate"
    )
    -- Solid backing so journal text underneath does not show through.
    for _, tip in ipairs({ itemTooltip, compareTooltip1, compareTooltip2 }) do
        if tip and tip ~= GameTooltip and tip.CreateTexture and not tip.fdjSolidBackground then
            local bg = tip:CreateTexture(nil, "BACKGROUND", nil, -8)
            bg:SetPoint("TOPLEFT", 3, -3)
            bg:SetPoint("BOTTOMRIGHT", -3, 3)
            bg:SetColorTexture(0.03, 0.03, 0.04, 1)
            tip.fdjSolidBackground = bg
        end
    end
end

local function HideComparisonTooltips()
    if compareTooltip1 then compareTooltip1:Hide() end
    if compareTooltip2 then compareTooltip2:Hide() end
end

local function WantsItemComparison()
    -- autocompare (2.0.6): Options > General > Auto Item Comparison: always.
    if ForeverDungeonJournalDB and ForeverDungeonJournalDB.autoCompare == true then return true end
    -- Compare only while the player is physically holding Shift over the item.
    -- Do not use the COMPAREITEMS modified-click binding here: Shift-click is
    -- reserved for WoW's normal chat-link behavior.
    return IsShiftKeyDown and IsShiftKeyDown() or false
end

local function ClampTooltipTop(top, height)
    local screenTop = (UIParent and UIParent.GetTop and UIParent:GetTop()) or 768
    local minTop = (height or 1) + 12
    local maxTop = screenTop - 12
    if top < minTop then top = minTop end
    if top > maxTop then top = maxTop end
    return top
end

local function PositionPrimaryItemTooltip(owner)
    if not itemTooltip or not owner then return end

    -- Anchor directly to the hovered row. The journal can be scaled independently
    -- from UIParent, so converting owner coordinates into UIParent coordinates
    -- can push the tooltip far away from the item. A relative anchor lets WoW
    -- handle the effective-scale conversion and keeps the tooltip immediately
    -- above the row without covering its text.
    if itemTooltip.SetClampedToScreen then
        itemTooltip:SetClampedToScreen(true)
    end
    itemTooltip:ClearAllPoints()
    local anchor = owner.icon or owner
    -- setstrip (2.0.8): with the item's set row open, the tooltip goes
    -- around the row (never over it)
    local strip = FDJ.setStrip
    if strip and FDJ.setStripOwner == owner and strip:IsShown() and FDJ.PlaceSetStripTooltip then
        FDJ.PlaceSetStripTooltip()
        return
    end
    itemTooltip:SetPoint("BOTTOMLEFT", anchor, "TOPRIGHT", 4, 4)
end

local function GetItemEquipLocation(itemID)
    local _, _, _, _, _, _, _, _, equipLoc = ItemInfo(itemID)
    if type(equipLoc) == "string" and equipLoc ~= "" then
        return equipLoc
    end

    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
        local ok, _, _, _, instantEquipLoc = pcall(C_Item.GetItemInfoInstant, itemID)
        if ok and type(instantEquipLoc) == "string" and instantEquipLoc ~= "" then
            return instantEquipLoc
        end
    end

    return nil
end

local function GetEquippedComparisonEntries(itemID)
    local equipLoc = GetItemEquipLocation(itemID)
    if not equipLoc then return {} end

    local slots = EQUIP_LOC_SLOTS[equipLoc]

    -- A generic one-hand weapon can replace the main hand. If the player is
    -- actually dual-wielding a one-hand/off-hand weapon, also compare against
    -- that real equipped weapon. Never compare it against a shield/holdable.
    if equipLoc == "INVTYPE_WEAPON" then
        slots = {16}
        local offLink = GetInventoryItemLink and GetInventoryItemLink("player", 17)
        if offLink then
            local offEquipLoc
            if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
                local ok, _, _, _, value = pcall(C_Item.GetItemInfoInstant, offLink)
                if ok then offEquipLoc = value end
            end
            if offEquipLoc == "INVTYPE_WEAPON" or offEquipLoc == "INVTYPE_WEAPONOFFHAND" then
                slots = {16, 17}
            end
        end
    end

    -- Bags/quivers deliberately have no mapping. The character has four bag
    -- slots and presenting four comparison tooltips is more noise than value.
    if not slots then return {} end

    local entries = {}
    for _, slot in ipairs(slots) do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        if link then
            table.insert(entries, { slot = slot, link = link })
        end
    end
    return entries
end

local function PositionTooltipGroup(owner, comparisons)
    if not itemTooltip or not owner then return end

    comparisons = comparisons or {}
    local gap = 6

    -- Keep the hovered item tooltip locked directly above its row. Comparison
    -- tooltips extend to the right of it, preserving the same local anchor and
    -- avoiding UIParent/journal scale mismatches.
    if itemTooltip.SetClampedToScreen then
        itemTooltip:SetClampedToScreen(true)
    end
    itemTooltip:ClearAllPoints()
    local anchor = owner.icon or owner
    itemTooltip:SetPoint("BOTTOMLEFT", anchor, "TOPRIGHT", 4, 4)

    local previous = itemTooltip
    for _, tooltip in ipairs(comparisons) do
        if tooltip.SetClampedToScreen then
            tooltip:SetClampedToScreen(true)
        end
        tooltip:ClearAllPoints()
        tooltip:SetPoint("TOPLEFT", previous, "TOPRIGHT", gap, 0)
        previous = tooltip
    end
end

local STAT_DELTA_ORDER_INDEX = {}
for index, key in ipairs(STAT_DELTA_ORDER) do
    STAT_DELTA_ORDER_INDEX[key] = index
end

local function IsUsableStatLabel(text)
    return type(text) == "string"
        and text ~= ""
        and not string.find(text, "%%[%d%$%.]*[dsf]")
end

local function StatDeltaLabel(key)
    if type(key) ~= "string" then return tostring(key or "Stat") end

    local label = _G[key]
    if IsUsableStatLabel(label) then
        return label
    end

    if not string.find(key, "_SHORT$") then
        label = _G[key .. "_SHORT"]
        if IsUsableStatLabel(label) then
            return label
        end
    end

    label = STAT_DELTA_FALLBACK_LABELS[key]
    if label then return label end

    -- Some Forever builds may return an already-localized string as the key.
    if not string.find(key, "^ITEM_MOD_") and not string.find(key, "^RESISTANCE%d_NAME$") then
        return key
    end

    local cleaned = key
    cleaned = string.gsub(cleaned, "^ITEM_MOD_", "")
    cleaned = string.gsub(cleaned, "_SHORT$", "")
    cleaned = string.gsub(cleaned, "_RATING$", "")
    cleaned = string.gsub(cleaned, "_", " ")
    cleaned = string.lower(cleaned)
    cleaned = string.gsub(cleaned, "(%a)([%w']*)", function(a, b)
        return string.upper(a) .. b
    end)
    return cleaned
end

local function FormatStatDeltaValue(key, value)
    local absValue = math.abs(value)
    local precision = 0
    if key == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" then
        precision = 1
    elseif math.abs(absValue - math.floor(absValue + 0.5)) > 0.001 then
        precision = 1
    end

    if precision == 1 then
        return string.format("%+.1f", value)
    end
    local rounded
    if value >= 0 then
        rounded = math.floor(value + 0.5)
    else
        rounded = math.ceil(value - 0.5)
    end
    return string.format("%+d", rounded)
end

local function AddStatDeltaBlock(tooltip, equippedLink, newLink)
    if not tooltip or not equippedLink or not newLink then return end
    if not C_Item or type(C_Item.GetItemStatDelta) ~= "function" then return end

    local ok, deltas = pcall(C_Item.GetItemStatDelta, newLink, equippedLink)
    if not ok or type(deltas) ~= "table" then return end

    local entries = {}
    for key, value in pairs(deltas) do
        if type(value) == "number" and math.abs(value) > 0.0001 then
            table.insert(entries, {
                key = key,
                value = value,
                order = STAT_DELTA_ORDER_INDEX[key] or 10000,
                label = StatDeltaLabel(key),
            })
        end
    end

    if #entries == 0 then return end

    table.sort(entries, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return tostring(a.label) < tostring(b.label)
    end)

    tooltip:AddLine(" ")
    tooltip:AddLine(
        ITEM_DELTA_DESCRIPTION or "If you replace this item, the following stat changes will occur:",
        1, 0.82, 0,
        true
    )

    local seenLabels = {}
    for _, entry in ipairs(entries) do
        -- Forever can return the same resistance/armor stat under both a
        -- canonical token and an already-localized alias. Show it once.
        local labelKey = string.lower(tostring(entry.label or entry.key or ""))
        labelKey = string.gsub(labelKey, "%s+", " ")
        labelKey = string.gsub(labelKey, "^%s+", "")
        labelKey = string.gsub(labelKey, "%s+$", "")
        if not seenLabels[labelKey] then
            seenLabels[labelKey] = true
            local valueText = FormatStatDeltaValue(entry.key, entry.value)
            local text = valueText .. " " .. entry.label
            if entry.value > 0 then
                tooltip:AddLine(text, 0.10, 1.00, 0.10)
            else
                tooltip:AddLine(text, 1.00, 0.15, 0.15)
            end
        end
    end
end

local function FillComparisonTooltip(tooltip, owner, comparison, newLink)
    if not tooltip or not owner or not comparison or not comparison.link then return false end

    local link = comparison.link
    tooltip:Hide()
    tooltip:SetOwner(owner, "ANCHOR_NONE")
    if tooltip.ClearLines then tooltip:ClearLines() end

    -- SetInventoryItem is important here. A plain hyperlink does not carry the
    -- instance's current binding state, so an already-equipped Soulbound item
    -- could incorrectly render its template text (for example "Binds to Account
    -- until equipped"). Reading the actual equipped slot matches the normal
    -- character-sheet tooltip.
    local populated = false
    if comparison.slot and tooltip.SetInventoryItem then
        local ok = pcall(tooltip.SetInventoryItem, tooltip, "player", comparison.slot)
        populated = ok
    end
    if not populated then
        tooltip:SetHyperlink(link)
    end

    -- Replacement delta = hovered/new item minus the currently equipped item.
    AddStatDeltaBlock(tooltip, link, newLink)

    if tooltip.NumLines and tooltip:NumLines() <= 0 then
        tooltip:Hide()
        return false
    end

    tooltip:Show()
    return true
end

local function ShowComparisonTooltips(owner)
    if not itemTooltip or not owner or not owner.item then return end

    HideComparisonTooltips()

    local comparisons = GetEquippedComparisonEntries(owner.item[1])
    if #comparisons == 0 then
        PositionPrimaryItemTooltip(owner)
        return
    end

    local _, newLink = ItemInfo(owner.item[1])
    newLink = newLink or ("item:" .. owner.item[1])

    local shown = {}
    if comparisons[1] and FillComparisonTooltip(compareTooltip1, owner, comparisons[1], newLink) then
        table.insert(shown, compareTooltip1)
    end
    if comparisons[2] and FillComparisonTooltip(compareTooltip2, owner, comparisons[2], newLink) then
        table.insert(shown, compareTooltip2)
    end

    PositionTooltipGroup(owner, shown)
end

local function UpdateItemComparison(owner)
    if not itemTooltip or not owner or not owner.item then return end
    if not itemTooltip.IsOwned or not itemTooltip:IsOwned(owner) then return end

    local compare = WantsItemComparison()
    if owner.fdjComparing == compare then return end
    owner.fdjComparing = compare

    if compare then
        ShowComparisonTooltips(owner)
    else
        HideComparisonTooltips()
        PositionPrimaryItemTooltip(owner)
    end
end

local function InsertTooltipLineBeforeRequiredLevel(tooltip, text, r, g, b)
    if not tooltip or not text or text == "" or not tooltip.GetName or not tooltip.NumLines then return false end
    local tipName = tooltip:GetName()
    if not tipName or tipName == "" then return false end

    local requiredNeedle = tostring(_G.ITEM_MIN_LEVEL or "Requires Level %d")
    requiredNeedle = requiredNeedle:gsub("%%d", ""):gsub("%%s", "")
    requiredNeedle = requiredNeedle:gsub("^%s+", ""):gsub("%s+$", "")

    local lineCount = tooltip:NumLines() or 0
    local requiredIndex
    for i = 1, lineCount do
        local left = _G[tipName .. "TextLeft" .. i]
        local lineText = left and left:GetText()
        if type(lineText) == "string" and requiredNeedle ~= "" and lineText:find(requiredNeedle, 1, true) then
            requiredIndex = i
            break
        end
    end
    if not requiredIndex then return false end

    -- Add one native tooltip row, then shift the existing Required Level line
    -- and everything below it down by one slot. This preserves the tooltip's
    -- normal spacing while placing our custom stat exactly above Required Level.
    tooltip:AddLine(" ")
    for i = lineCount, requiredIndex, -1 do
        local srcL = _G[tipName .. "TextLeft" .. i]
        local srcR = _G[tipName .. "TextRight" .. i]
        local dstL = _G[tipName .. "TextLeft" .. (i + 1)]
        local dstR = _G[tipName .. "TextRight" .. (i + 1)]
        if srcL and dstL then
            dstL:SetText(srcL:GetText() or "")
            local cr, cg, cb, ca = srcL:GetTextColor()
            dstL:SetTextColor(cr or 1, cg or 1, cb or 1, ca or 1)
        end
        if srcR and dstR then
            dstR:SetText(srcR:GetText() or "")
            local cr, cg, cb, ca = srcR:GetTextColor()
            dstR:SetTextColor(cr or 1, cg or 1, cb or 1, ca or 1)
        end
    end

    local targetL = _G[tipName .. "TextLeft" .. requiredIndex]
    local targetR = _G[tipName .. "TextRight" .. requiredIndex]
    if targetL then
        targetL:SetText(text)
        targetL:SetTextColor(r or 0.10, g or 1.00, b or 0.10, 1)
    end
    if targetR then targetR:SetText("") end
    return true
end

-- Items the Forever server has not sent to this client yet show only a red
-- "Retrieving item information" line. Explain why under that line. The game
-- rebuilds the tooltip once the data arrives, which removes the note again.
function FDJ.AddUnseenItemHint(tooltip)
    if not tooltip or not tooltip.GetName or not tooltip:GetName() then return false end
    local first = _G[tooltip:GetName() .. "TextLeft1"]
    local text = first and first:IsShown() and first:GetText()
    if not text then return false end
    if text ~= (RETRIEVING_ITEM_INFO or "Retrieving item information") and text ~= "Retrieving item information" then return false end
    tooltip:AddLine(" ")
    tooltip:AddLine(L("ITEM_UNSEEN_TITLE"), 1.00, 0.82, 0.10)
    tooltip:AddLine(L("ITEM_UNSEEN_TIP"), 0.85, 0.85, 0.85, true)
    return true
end

-- kroldok: the stats the game showed for an item whose ID is not known
-- yet (item.tip: a line, or { left, right }).
function FDJ.AddItemTipLines(tooltip, item)
    local tip = type(item) == "table" and item.tip
    for _, line in ipairs(type(tip) == "table" and tip or {}) do
        if type(line) == "table" then
            tooltip:AddDoubleLine(line[1], line[2], 1, 1, 1, 1, 1, 1)
        else
            tooltip:AddLine(line, 1, 1, 1, true)
        end
    end
end

local function ShowItemTooltip(row)
    if not row.item then return end

    HideComparisonTooltips()
    row.fdjComparing = nil

    -- SetOwner must happen BEFORE SetHyperlink. Re-setting the owner after the
    -- hyperlink is populated clears the tooltip on the Forever client.
    itemTooltip:Hide()
    itemTooltip:SetOwner(row, "ANCHOR_NONE")
    if itemTooltip.ClearLines then itemTooltip:ClearLines() end
    -- owntip (2.0.12, M 18 Nov 2026, Tortheldrin's Broken Glaive: "Just
    -- write your own tooltip. We don't need the real one from the game"):
    -- item.ownTip shows the journal's own tooltip (the name, then where it
    -- comes from) instead of the game's, even with a real item ID.
    if not row.item[1] or row.item[1] <= 0 or row.item.ownTip then
        local r, g, b = QualityColor(tonumber(row.item[4]) or tonumber(row.item[3]) or 1)
        itemTooltip:AddLine(row.item[2] or L("ITEM"), r, g, b)
        for _, line in ipairs(type(row.item.tip) == "table" and row.item.tip or {}) do -- drownedloot
            if type(line) == "table" then
                itemTooltip:AddDoubleLine(line[1], line[2], 1, 1, 1, 1, 1, 1)
            else
                itemTooltip:AddLine(line, 1, 1, 1, true)
            end
        end
        if row.item.ownTip and row.fdjSourceText and row.fdjSourceText ~= "" then
            itemTooltip:AddLine(row.fdjSourceText, 1.00, 0.82, 0.10, true)
        end
        itemTooltip:Show()
        if FDJ.RefreshTooltipBacking then FDJ.RefreshTooltipBacking() end
        PositionPrimaryItemTooltip(row)
        return
    end
    local _, liveLink = ItemInfo(row.item[1])
    itemTooltip:SetHyperlink(liveLink or ("item:" .. row.item[1]))
    FDJ.AddUnseenItemHint(itemTooltip)
    -- Some loot entries need a short Journal-only stat hint that the base item
    -- hyperlink cannot show. Charged Gear, for example, rolls a random enchant
    -- when it drops, while the static item ID has no suffix attached to it.
    if type(row.item[6]) == "string" and row.item[6] ~= "" then
        local statText = L(row.item[6])
        -- The game may print its own "<Random enchantment>" line already.
        local already = false
        if row.item[6] == "RANDOM_ENCHANT" and itemTooltip.GetName and itemTooltip:GetName() then
            for i = 1, itemTooltip:NumLines() or 0 do
                local line = _G[itemTooltip:GetName() .. "TextLeft" .. i]
                local text = line and line:GetText()
                if text and (text == statText or (ITEM_RANDOM_ENCHANT and text == ITEM_RANDOM_ENCHANT)) then
                    already = true
                    break
                end
            end
        end
        if not already and not InsertTooltipLineBeforeRequiredLevel(itemTooltip, statText, 0.10, 1.00, 0.10) then
            itemTooltip:AddLine(statText, 0.10, 1.00, 0.10, true)
        end
    end
    if row.fdjSourceText and row.fdjSourceText ~= "" then
        itemTooltip:AddLine(" ")
        itemTooltip:AddLine(row.fdjSourceText, 1.00, 0.82, 0.10, true)
    end
    -- droprare (2.0.8, M 15 Nov 2026): a loot entry's own note (dropNote, a
    -- string key: "Extremely rare drop"), in its language
    if type(row.item.dropNote) == "string" then
        if not (row.fdjSourceText and row.fdjSourceText ~= "") then itemTooltip:AddLine(" ") end
        itemTooltip:AddLine(L(row.item.dropNote), 1.00, 0.50, 0.25, true)
    end
    -- droprates (2.0.11): how often the boss of this page drops it
    local chance = FDJ.DropChanceText and FDJ.DropChanceText(row.fdjDungeonName, row.fdjBossName, row.item[1])
    if chance then
        if not (row.fdjSourceText and row.fdjSourceText ~= "") and type(row.item.dropNote) ~= "string" then itemTooltip:AddLine(" ") end
        itemTooltip:AddLine(chance, 1.00, 0.82, 0.10, true)
    end
    if row.fdjMapLocation then
        itemTooltip:AddLine(L("ITEM_CLICK_MAP"), 0.35, 1.00, 0.35, true)
    elseif row.fdjBossJump and not row.mapLocation and FDJ.BossDropSource and FDJ.BossDropSource(row.item[1]) then
        itemTooltip:AddLine(L("ITEM_CLICK_BOSS"), 0.35, 1.00, 0.35, true)
    end
    if FDJ.SetStripHint then pcall(FDJ.SetStripHint, itemTooltip, row) end -- setstrip (2.0.8)
    itemTooltip:Show()
    if FDJ.RefreshTooltipBacking then FDJ.RefreshTooltipBacking() end
    PositionPrimaryItemTooltip(row)
    if FDJ.UpdateSetStrip then pcall(FDJ.UpdateSetStrip, row) end -- setstrip (2.0.8)

    -- Handles Shift already being held when the mouse enters the item.
    UpdateItemComparison(row)
end

-- 2.0.4: the Dungeon Tracker's boss loot line shows the same item tooltip.
function FDJ.ShowJournalItemTooltip(owner, item)
    if not (itemTooltip and owner and type(item) == "table") then return false end
    owner.item = item
    local ok = pcall(ShowItemTooltip, owner)
    return ok
end
function FDJ.HideJournalItemTooltip()
    if itemTooltip then itemTooltip:Hide() end
    pcall(HideComparisonTooltips)
end

-- setstrip (2.0.8, M 15 Nov 2026): a piece of an item set (Dungeon Set 1 and
-- 2, Forever's own sets...) shows the whole set when clicked: a row of the
-- set's pieces (icons, in slot order, head to feet) right under its tooltip,
-- the piece hovered framed in gold, the others in their quality's colour.
-- A plain click opens it, another click (or moving off the item) closes it;
-- the tooltip says which ("Click to show the whole set"). The row stays
-- while the mouse moves onto it: each piece shows its own tooltip on hover, Shift-click links it, Ctrl-click tries it on; off the
-- row and the item, it closes. Loot rows and quest
-- rewards (Tier 0.5); Shift-click still links, Ctrl-click still tries on. The
-- sets: FDJ.ITEM_SETS (Data/Dungeons.lua, BEGIN itemsets). The row sits just
-- over the item; the tooltip (the item's, or a piece's) goes over the row when
-- it fits there, else beside it (right, or left at the screen's edge): it is
-- never covered by the row.
do
    local strings = {
        enUS = { SET_CLICK_SHOW = "Click to show the whole set", SET_CLICK_HIDE = "Click to hide the set" },
        deDE = { SET_CLICK_SHOW = "Klicken, um das ganze Set anzuzeigen", SET_CLICK_HIDE = "Klicken, um das Set auszublenden" },
        frFR = { SET_CLICK_SHOW = "Cliquez pour afficher tout l'ensemble", SET_CLICK_HIDE = "Cliquez pour masquer l'ensemble" },
        esES = { SET_CLICK_SHOW = "Haz clic para ver todo el conjunto", SET_CLICK_HIDE = "Haz clic para ocultar el conjunto" },
        itIT = { SET_CLICK_SHOW = "Clicca per mostrare tutto il set", SET_CLICK_HIDE = "Clicca per nascondere il set" },
        ptBR = { SET_CLICK_SHOW = "Clique para mostrar o conjunto inteiro", SET_CLICK_HIDE = "Clique para ocultar o conjunto" },
        ruRU = { SET_CLICK_SHOW = "Щелкните, чтобы показать весь комплект", SET_CLICK_HIDE = "Щелкните, чтобы скрыть комплект" },
        koKR = { SET_CLICK_SHOW = "클릭하여 세트 전체 보기", SET_CLICK_HIDE = "클릭하여 세트 숨기기" },
        zhCN = { SET_CLICK_SHOW = "点击显示整套装备", SET_CLICK_HIDE = "点击隐藏套装" },
        zhTW = { SET_CLICK_SHOW = "點擊顯示整套裝備", SET_CLICK_HIDE = "點擊隱藏套裝" },
    }
    strings.esMX = strings.esES
    for locale, entries in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            for key, value in pairs(entries) do
                if t[key] == nil then t[key] = value end
            end
        end
    end

    local setOf
    function FDJ.ItemSetOf(itemID)
        itemID = tonumber(itemID)
        if not itemID then return nil end
        if not setOf then
            setOf = {}
            for _, set in ipairs(FDJ.ITEM_SETS or {}) do
                for _, id in ipairs(set) do setOf[id] = set end
            end
        end
        return setOf[itemID]
    end

    -- the click is free (not a map spot or a jump to the boss that drops it)
    local function Clickable(owner)
        if not (owner and owner.fdjSetClick and type(owner.item) == "table") then return false end
        if owner.fdjMapLocation then return false end
        if owner.fdjBossJump and FDJ.BossDropSource and FDJ.BossDropSource(owner.item[1]) then return false end
        return FDJ.ItemSetOf(owner.item[1]) ~= nil
    end

    function FDJ.SetStripHint(tip, owner)
        if not Clickable(owner) then return end
        tip:AddLine(L(FDJ.setStripOwner == owner and "SET_CLICK_HIDE" or "SET_CLICK_SHOW"), 0.35, 1.00, 0.35, true)
    end

    local strip
    local SIZE, EDGE, GAP, PAD = 30, 2, 4, 7
    local function Build()
        strip = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        strip:SetFrameStrata("TOOLTIP")
        strip:SetFrameLevel(50)
        strip:EnableMouse(true)
        strip.fdjSolidTooltip = true -- the pieces' tooltips get the journal's dark backing
        SetBackdrop(strip, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 14, 3)
        strip:SetBackdropColor(0.03, 0.03, 0.04, 1)
        strip:SetBackdropBorderColor(0.80, 0.80, 0.80, 1)
        strip.cells = {}
        strip:Hide()
        FDJ.setStrip = strip
        -- setbridge (2.0.8, M 15 Nov 2026: going up from the item to the row
        -- too fast, the mouse crossed the item above it, which took the
        -- tooltip and closed the row): while the row is open, the space
        -- between the item and the top of the row takes the mouse, so the
        -- items under it can't. Resting there a while (not passing through)
        -- closes the row as usual and gives them back.
        strip.fdjShield = CreateFrame("Frame", nil, UIParent)
        strip.fdjShield:SetFrameStrata("TOOLTIP")
        strip.fdjShield:SetFrameLevel(49)
        strip.fdjShield:EnableMouse(true)
        strip.fdjShield:Hide()
        strip:HookScript("OnHide", function(self) if self.fdjShield then self.fdjShield:Hide() end end)
        if itemTooltip and itemTooltip.HookScript then
            itemTooltip:HookScript("OnHide", function() if strip and not strip.fdjPinned then strip:Hide() if strip.fdjShield then strip.fdjShield:Hide() end end end)
            -- a tooltip that grows after it was placed (lines other code and
            -- addons add later, item data arriving: Beaststalker's Cap) is
            -- placed again, so it never ends up pushed down over the row
            itemTooltip:HookScript("OnSizeChanged", function(tip)
                if strip and strip:IsShown() and not strip.fdjPlacing and FDJ.PlaceSetStripTooltip then
                    -- (abovealways: not again for the size it was left at)
                    local h, w = tip:GetHeight() or 0, tip:GetWidth() or 0
                    if strip.fdjPlacedH and math.abs(h - strip.fdjPlacedH) < 0.5 and math.abs(w - (strip.fdjPlacedW or 0)) < 0.5 then return end
                    pcall(FDJ.PlaceSetStripTooltip)
                end
            end)
            -- abovealways: a tooltip made wider for the row is its own width
            -- again for the next item, and once it is gone
            local function Unwiden()
                if strip and strip.fdjUnclamped then -- noclamp: kept on the screen again
                    strip.fdjUnclamped = nil
                    if itemTooltip.SetClampedToScreen then pcall(itemTooltip.SetClampedToScreen, itemTooltip, true) end
                end
                if strip and strip.fdjInsets then -- fulltop: the game's margin back
                    local i = strip.fdjInsets
                    strip.fdjInsets = nil
                    if itemTooltip.SetClampRectInsets then pcall(itemTooltip.SetClampRectInsets, itemTooltip, i[1], i[2], i[3], i[4]) end
                end
                if strip and strip.fdjWidened then
                    strip.fdjWidened, strip.fdjPlacedH, strip.fdjPlacedW = nil, nil, nil
                    if itemTooltip.SetMinimumWidth then pcall(itemTooltip.SetMinimumWidth, itemTooltip, 0) end
                end
            end
            itemTooltip:HookScript("OnHide", Unwiden)
            pcall(itemTooltip.HookScript, itemTooltip, "OnTooltipCleared", Unwiden)
        end
        -- while the mouse is on the row of pieces (or back on the item), it
        -- stays; a moment anywhere else and it closes
        strip:SetScript("OnUpdate", function(self, elapsed)
            if not self.fdjPinned then return end
            local owner = FDJ.setStripOwner
            local over = (self.IsMouseOver and self:IsMouseOver(4, -4, -4, 4))
                or (owner and owner.IsMouseOver and owner:IsMouseOver())
            if over and owner and (not owner.IsVisible or owner:IsVisible()) then
                self.fdjAway, self.fdjBridged = 0, 0
                return
            end
            -- setbridge: on the way between the item and the row (a second at most)
            local shield = self.fdjShield
            if shield and shield:IsShown() and shield:IsMouseOver() and owner and (not owner.IsVisible or owner:IsVisible()) then
                self.fdjBridged = (self.fdjBridged or 0) + (elapsed or 0)
                if self.fdjBridged < 1 then
                    self.fdjAway = 0
                    return
                end
            end
            self.fdjAway = (self.fdjAway or 0) + (elapsed or 0)
            if self.fdjAway > 0.25 then FDJ.CloseSetStrip(nil, true) end
        end)
    end
    -- the tooltip over the row when it fits under the screen's top, else
    -- beside it: to its right, or to its left when that runs off the screen
    -- abovealways (2.0.8, M 15 Nov 2026: "i dont like how they keep moving
    -- positions, try to force it to the top"): the tooltip always goes over
    -- the row. One too tall for the room up to the screen's top is made
    -- wider, a step at a time (its long lines, the set's bonuses, wrap less,
    -- so it gets shorter), until it fits. Only when even the widest (as wide
    -- as the screen allows, MAX_WIDE at most) is too tall (the journal
    -- dragged up near the top) does it go beside the row, its own width.
    local MAX_WIDE, WIDE_STEP = 640, 20
    function FDJ.PlaceSetStripTooltip()
        if not (strip and strip:IsShown() and itemTooltip) then return end
        strip.fdjPlacing = true
        itemTooltip:ClearAllPoints()
        local us = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
        local ss = strip.GetEffectiveScale and strip:GetEffectiveScale() or 1
        local ts = itemTooltip.GetEffectiveScale and itemTooltip:GetEffectiveScale() or 1
        local screenH = ((UIParent and UIParent.GetTop and UIParent:GetTop()) or 0) * us
        local screenW = ((UIParent and UIParent.GetRight and UIParent:GetRight()) or 0) * us
        local top = (strip:GetTop() or 0) * ss
        local right = (strip:GetRight() or 0) * ss
        local left = (strip.GetLeft and strip:GetLeft() or 0) * ss
        -- topmargin (2.0.8, M 15 Nov 2026: Beaststalker's Cap and Belt still
        -- pushed down onto the row): the game keeps tooltips a little under
        -- the screen's top (its clamp insets; about 28 on his screen), so
        -- that much room is left free: the tooltip's own top inset, 32 at
        -- least. And where the game put it is looked at too: a bottom edge
        -- under the row's top is no fit.
        -- fulltop (2.0.8, M 15 Nov 2026: "can we make it a bit taller? the
        -- wide fits but it looks ugly"): over the row the tooltip may go
        -- right up to the screen's top: the game's margin (its clamp insets)
        -- is taken off while the row is open and put back after, so the
        -- Cap and the Belt fit at their own width. Made wider only when
        -- even that is not room enough.
        local margin = 32
        if itemTooltip.GetClampRectInsets and itemTooltip.SetClampRectInsets then
            if not strip.fdjInsets then
                local ok, l, r, t, b = pcall(itemTooltip.GetClampRectInsets, itemTooltip)
                if ok then strip.fdjInsets = { l or 0, r or 0, t or 0, b or 0 } end
            end
            if strip.fdjInsets and pcall(itemTooltip.SetClampRectInsets, itemTooltip, 0, 0, 0, 0) then margin = 3 end
        end
        -- noclamp (2.0.8, M 15 Nov 2026: still pushed down from 28 under
        -- the top with the insets off): over the row the game's keeping it
        -- on the screen is switched off altogether, so it sits exactly where
        -- it is put; the journal itself sees that it stays under the top.
        if itemTooltip.SetClampedToScreen and pcall(itemTooltip.SetClampedToScreen, itemTooltip, false) then
            strip.fdjUnclamped = true
            margin = 3
        elseif itemTooltip.GetClampRectInsets then
            local ok, _, _, t = pcall(itemTooltip.GetClampRectInsets, itemTooltip)
            if ok and type(t) == "number" then margin = math.max(margin, math.abs(t) + 4) end
        end
        local function Fits()
            local tipH = (itemTooltip:GetHeight() or 0) * ts
            if screenH <= 0 or tipH <= 0 then return true end
            if top + tipH + margin * ts > screenH then return false end
            local bottom = itemTooltip.GetBottom and itemTooltip:GetBottom()
            return not (type(bottom) == "number" and bottom * ts < top - 1)
        end
        itemTooltip:SetPoint("BOTTOMLEFT", strip, "TOPLEFT", 0, 2)
        local fits = Fits()
        if not fits and itemTooltip.SetMinimumWidth and ts > 0 then
            local widest = MAX_WIDE
            if screenW > 0 then widest = math.min(widest, math.floor((screenW - left) / ts - 4)) end
            local w = math.floor(itemTooltip:GetWidth() or 0)
            if w < widest then strip.fdjWidened = true end
            while not fits and w < widest do
                w = math.min(widest, w + WIDE_STEP)
                pcall(itemTooltip.SetMinimumWidth, itemTooltip, w)
                itemTooltip:Show() -- (laid out again at that width)
                fits = Fits()
            end
            if not fits and strip.fdjWidened then
                strip.fdjWidened = nil
                pcall(itemTooltip.SetMinimumWidth, itemTooltip, 0)
                itemTooltip:Show()
            end
        end
        if fits then
            strip.fdjTipSide = "above"
        else
            if strip.fdjUnclamped then -- beside the row: kept on the screen again
                strip.fdjUnclamped = nil
                pcall(itemTooltip.SetClampedToScreen, itemTooltip, true)
            end
            itemTooltip:ClearAllPoints()
            local tipW = (itemTooltip:GetWidth() or 0) * ts
            if screenW <= 0 or right + tipW + 6 * ts <= screenW then
                itemTooltip:SetPoint("BOTTOMLEFT", strip, "BOTTOMRIGHT", 4, 0)
                strip.fdjTipSide = "right"
            else
                itemTooltip:SetPoint("BOTTOMRIGHT", strip, "BOTTOMLEFT", -4, 0)
                strip.fdjTipSide = "left"
            end
        end
        strip.fdjPlacedH, strip.fdjPlacedW = itemTooltip:GetHeight() or 0, itemTooltip:GetWidth() or 0
        strip.fdjPlacing = nil
    end

    local function PieceTooltip(cell)
        local owner = FDJ.setStripOwner
        if not (owner and cell.id and itemTooltip) then return end
        strip.fdjAway = 0
        HideComparisonTooltips()
        itemTooltip:SetOwner(cell, "ANCHOR_NONE")
        if itemTooltip.ClearLines then itemTooltip:ClearLines() end
        local _, link = ItemInfo(cell.id)
        itemTooltip:SetHyperlink(link or ("item:" .. cell.id))
        -- (where it drops: the journal's own line on every item tooltip)
        itemTooltip:Show()
        if FDJ.RefreshTooltipBacking then FDJ.RefreshTooltipBacking() end
        FDJ.PlaceSetStripTooltip()
    end
    local function Cell(i)
        local c = strip.cells[i]
        if not c then
            c = CreateFrame("Button", nil, strip)
            c:RegisterForClicks("LeftButtonUp")
            c.edge = c:CreateTexture(nil, "BORDER")
            c.edge:SetAllPoints(c)
            c.icon = c:CreateTexture(nil, "ARTWORK")
            c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            c.icon:SetPoint("TOPLEFT", c, "TOPLEFT", EDGE, -EDGE)
            c.icon:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -EDGE, EDGE)
            if c.SetHighlightTexture then c:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD") end
            c:SetScript("OnEnter", PieceTooltip)
            c:SetScript("OnClick", function(self)
                if not self.id then return end
                local _, link = ItemInfo(self.id)
                if not link then return end
                if IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
                    ChatEdit_InsertLink(link)
                elseif IsModifiedClick and IsModifiedClick("DRESSUP") and DressUpItemLink then
                    DressUpItemLink(link)
                end
            end)
            strip.cells[i] = c
        end
        return c
    end

    function FDJ.UpdateSetStrip(owner)
        -- setforget (2.0.8, M 15 Nov 2026): another item hovered: the set is
        -- forgotten, so going back to the piece doesn't bring the row back
        -- (a new click does)
        if FDJ.setStripOwner and FDJ.setStripOwner ~= owner then FDJ.setStripOwner = nil end
        local set = FDJ.setStripOwner == owner and Clickable(owner) and FDJ.ItemSetOf(owner.item[1]) or nil
        if not set or not (itemTooltip and itemTooltip:IsShown()) then
            if strip then strip:Hide() if strip.fdjShield then strip.fdjShield:Hide() end end -- (setbridge)
            return
        end
        if not strip then Build() end
        local current = tonumber(owner.item[1])
        local fallback = tonumber(owner.item[4]) or 3
        local cellW = SIZE + EDGE * 2
        for i, id in ipairs(set) do
            local c = Cell(i)
            if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then pcall(C_Item.RequestLoadItemDataByID, id) end
            local x = PAD + 2 + (i - 1) * (cellW + GAP)
            c:ClearAllPoints()
            c:SetSize(cellW, cellW)
            c:SetPoint("TOPLEFT", strip, "TOPLEFT", x, -(PAD + 2))
            c.icon:SetTexture(ItemIcon(id))
            local _, link, quality = ItemInfo(id)
            local r, g, b = GetAuthoritativeItemQuality(id, link, quality, fallback)
            if id == current then
                c.edge:SetColorTexture(1.00, 0.82, 0.00, 1)
            else
                c.edge:SetColorTexture(r or 0.6, g or 0.6, b or 0.6, 0.95)
            end
            c.edge:Show()
            c.icon:Show()
            c:Show()
            c.id = id
        end
        for i = #set + 1, #strip.cells do
            strip.cells[i]:Hide()
            strip.cells[i].id = nil
        end
        local n = #set
        local w = (PAD + 2) * 2 + n * cellW + (n - 1) * GAP
        local h = (PAD + 2) * 2 + cellW
        strip:SetSize(w, h)
        strip.fdjPinned, strip.fdjAway = nil, 0
        local tipScale = itemTooltip.GetEffectiveScale and itemTooltip:GetEffectiveScale() or 1
        local uiScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
        if tipScale > 0 and uiScale > 0 then strip:SetScale(tipScale / uiScale) end
        -- the row sits just over the item (not on it); the tooltip around it
        strip:ClearAllPoints()
        strip:SetPoint("BOTTOMLEFT", owner.icon or owner, "TOPRIGHT", 4, 8)
        strip:Show()
        -- setbridge: from the item's top edge to the top of the row, from the
        -- item's left edge to the row's right end
        strip.fdjBridged = 0
        if strip.fdjShield then
            strip.fdjShield:ClearAllPoints()
            strip.fdjShield:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 0)
            strip.fdjShield:SetPoint("TOPRIGHT", strip, "TOPRIGHT", 0, 0)
            strip.fdjShield:Show()
        end
        FDJ.PlaceSetStripTooltip()
    end

    function FDJ.ToggleSetStrip(owner)
        if not Clickable(owner) then return false end
        FDJ.setStripOwner = (FDJ.setStripOwner ~= owner) and owner or nil
        pcall(ShowItemTooltip, owner) -- the hint changes; the row follows
        if not FDJ.setStripOwner and strip then strip:Hide() if strip.fdjShield then strip.fdjShield:Hide() end end -- (setbridge)
        return true
    end

    -- the mouse left the item while its set's row is open: the row stays
    -- (the mouse may be going onto it)
    function FDJ.SetStripKeep(owner)
        if not (strip and strip:IsShown() and owner and FDJ.setStripOwner == owner) then return false end
        strip.fdjPinned, strip.fdjAway = true, 0
        return true
    end

    function FDJ.CloseSetStrip(owner, hideTooltip)
        if owner == nil or FDJ.setStripOwner == owner then FDJ.setStripOwner = nil end
        if strip then
            local pinned = strip.fdjPinned
            strip.fdjPinned = nil
            strip:Hide()
            if strip.fdjShield then strip.fdjShield:Hide() end -- setbridge
            if hideTooltip and pinned and itemTooltip and itemTooltip:IsShown() then
                itemTooltip:Hide()
                HideComparisonTooltips()
            end
        end
    end
end

-- ============================================================
-- UI CREATION
-- ============================================================

-- Temporary emphasis used only when an item was opened from the global search.
-- It deliberately disappears as soon as the player hovers the item, and normal
-- page refreshes clear it as well.
local function HideSearchItemHighlight(button)
    if button and button.fdjSearchGlow then
        button.fdjSearchGlow:Hide()
    end
end

local function ShowSearchItemHighlight(button)
    if not button then return end
    if not button.fdjSearchGlow then
        local glow = CreateFrame("Frame", nil, button, "BackdropTemplate")
        glow:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 3)
        glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -3)
        glow:SetFrameLevel(button:GetFrameLevel() + 6)
        glow:EnableMouse(false)
        SetBackdrop(glow, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 9, 2)
        glow:SetBackdropColor(1.00, 0.78, 0.08, 0.12)
        glow:SetBackdropBorderColor(1.00, 0.82, 0.12, 1.00)

        glow.flash = glow:CreateTexture(nil, "OVERLAY")
        glow.flash:SetAllPoints()
        glow.flash:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        glow.flash:SetBlendMode("ADD")
        glow.flash:SetAlpha(0.28)
        glow:Hide()
        button.fdjSearchGlow = glow
    end
    button.fdjSearchGlow:Show()
end

-- A list refresh (for example when the server sends item data while the
-- mouse is on a row) repaints rows with their normal colour. Keep the hover
-- colour on the row under the mouse.
local function KeepHoverColor(self)
    local c = self.fdjHoverColor
    if not c then return end
    if not self:IsMouseOver() then return end
    local r, g, b = self:GetBackdropColor()
    if r and (math.abs(r - c[1]) > 0.01 or math.abs(g - c[2]) > 0.01 or math.abs(b - c[3]) > 0.01) then
        self:SetBackdropColor(c[1], c[2], c[3], 1)
    end
end

local function MakeLootRow(parent)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetSize(388, 52)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    SetBackdrop(
        row,
        "Interface\\Buttons\\WHITE8X8",
        "Interface\\Tooltips\\UI-Tooltip-Border",
        10,
        2
    )
    row:SetBackdropColor(0.25, 0.16, 0.07, 0.93) -- recolored on refresh
    row:SetBackdropBorderColor(0.46, 0.30, 0.12, 1)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(38, 38)
    row.icon:SetPoint("LEFT", 10, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -4)
    row.name:SetPoint("RIGHT", -10, 0)
    row.name:SetJustifyH("LEFT")
    -- One line only: names too long for the row end in "..." (matters most
    -- in the two-column layout).
    row.name:SetWordWrap(false)

    row.slot = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    row.slot:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -5)
    row.slot:SetPoint("RIGHT", -10, 0)
    row.slot:SetJustifyH("LEFT")
    row.slot:SetWordWrap(false)
    row.slot:SetTextColor(0.27, 0.18, 0.08)

    -- Small right-hand label for shared boss loot, styled like the RARE tag
    -- on rare bosses. Sits left of the favourite star.
    row.sharedText = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
    row.sharedText:SetPoint("RIGHT", row, "RIGHT", -28, 0)
    row.sharedText:SetJustifyH("RIGHT")
    row.sharedText:SetText("Shared Loot, low %")
    row.sharedText:SetTextColor(1.00, 0.82, 0.00)
    row.sharedText:Hide()

    row:SetScript("OnEnter", function(self)
        HideSearchItemHighlight(self)
        local theme = THEMES[selectedDungeon] or THEMES["Hall of Thanes"]
        local c = theme.rowSelected
        self.fdjHoverColor = { c[1], c[2], c[3] }
        self:SetBackdropColor(c[1], c[2], c[3], 1)
        ShowItemTooltip(self)
    end)

    row:SetScript("OnLeave", function(self)
        local theme = THEMES[selectedDungeon] or THEMES["Hall of Thanes"]
        self.fdjHoverColor = nil
        self:SetBackdropColor(unpack(theme.lootRow))
        self.fdjComparing = nil
        -- setstrip: an open set row stays while the mouse goes onto it
        if not (FDJ.SetStripKeep and FDJ.SetStripKeep(self)) then
            if FDJ.CloseSetStrip then FDJ.CloseSetStrip(self) end
            if itemTooltip then itemTooltip:Hide() end
        end
        HideComparisonTooltips()
    end)
    row.fdjSetClick = true -- setstrip (2.0.8): a set piece shows its set when clicked

    -- Poll the modifier while hovered so comparison appears/disappears
    -- immediately when Shift is pressed/released, without moving the mouse.
    row:SetScript("OnUpdate", function(self)
        KeepHoverColor(self)
        UpdateItemComparison(self)
    end)

    row:SetScript("OnClick", function(self, button)
        if not self.item then return end

        if button == "RightButton" and FDJ.ShowItemFavouriteMenu then
            FDJ.ShowItemFavouriteMenu(self, self.item, self.fdjDungeonName, self.fdjBossName)
            return
        end

        -- setstrip (2.0.8): a plain click on a set piece shows / hides its set
        if button == "LeftButton" and not (IsModifiedClick and (IsModifiedClick("CHATLINK") or IsModifiedClick("DRESSUP")))
            and FDJ.ToggleSetStrip and FDJ.ToggleSetStrip(self) then
            return
        end

        local _, link = ItemInfo(self.item[1])

        if link
            and IsModifiedClick
            and IsModifiedClick("CHATLINK")
            and ChatEdit_InsertLink
        then
            -- Preserve normal Shift-click chat linking when an edit box is active.
            local used = ChatEdit_InsertLink(link)
            if used then return end
        end

        if link
            and IsModifiedClick
            and IsModifiedClick("DRESSUP")
            and DressUpItemLink
        then
            DressUpItemLink(link)
        end
    end)

    return row
end

-- lootchildren (2.0.8, M 15 Nov 2026): an item that is combined with another
-- into a third (makes = { id, name, type, quality, from = { {id, name,
-- boss}, ... } } on the loot entry: Jang'thraze the Protector and
-- Sang'thraze the Deflector make Sul'thraze the Lasher) has the item it makes
-- on a smaller row of its own right under it, joined by a line, always open.
-- It works like any loot row (tooltip, Shift-click link, Ctrl-click try on,
-- right-click favourite); its type line says what to combine it with, its
-- tooltip both halves and their bosses. The Loot Filter blacks it out like
-- other rows (with its half, or when the filter rules the item itself out).
do
    local strings = {
        enUS = { LOOT_COMBINE_WITH = "Combine with %s", LOOT_MADE_FROM = "Made by combining %s and %s." },
        deDE = { LOOT_COMBINE_WITH = "Kombinieren mit %s", LOOT_MADE_FROM = "Entsteht durch Kombinieren von %s und %s." },
        frFR = { LOOT_COMBINE_WITH = "À combiner avec %s", LOOT_MADE_FROM = "Obtenu en combinant %s et %s." },
        esES = { LOOT_COMBINE_WITH = "Combinar con %s", LOOT_MADE_FROM = "Se obtiene al combinar %s y %s." },
        itIT = { LOOT_COMBINE_WITH = "Da combinare con %s", LOOT_MADE_FROM = "Si ottiene combinando %s e %s." },
        ptBR = { LOOT_COMBINE_WITH = "Combine com %s", LOOT_MADE_FROM = "Obtido ao combinar %s e %s." },
        ruRU = { LOOT_COMBINE_WITH = "Объединить с: %s", LOOT_MADE_FROM = "Создаётся объединением: %s и %s." },
        koKR = { LOOT_COMBINE_WITH = "%s 아이템과 결합", LOOT_MADE_FROM = "%s 아이템과 %s 아이템을 결합하여 만듭니다." },
        zhCN = { LOOT_COMBINE_WITH = "与%s合成", LOOT_MADE_FROM = "由%s和%s合成。" },
        zhTW = { LOOT_COMBINE_WITH = "與%s合成", LOOT_MADE_FROM = "由%s和%s合成。" },
    }
    strings.esMX = strings.esES
    for locale, entries in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            for key, value in pairs(entries) do
                if t[key] == nil then t[key] = value end
            end
        end
    end
end

function FDJ.ShowLootChild(child, item, boss, x, y, width, theme, parentDimmed)
    local made = type(item) == "table" and item.makes
    if type(made) ~= "table" or not child then return end
    local compact = FDJ.lootCompact
    local indent = FDJ.BOSS_CHILD_INDENT or 22
    local parentHeight = compact and 28 or 52
    local height = (compact and 26 or 44) - 3
    child:ClearAllPoints()
    child:SetWidth(math.max(60, (width or 388) - indent))
    child:SetHeight(height)
    child:SetPoint("TOPLEFT", child:GetParent(), "TOPLEFT", (x or 0) + indent, -((y or 0) + parentHeight + 3))

    -- the line from the half above to this row
    if not child.fdjElbow then
        child.fdjElbow = { child:CreateTexture(nil, "BACKGROUND"), child:CreateTexture(nil, "BACKGROUND") }
    end
    local down, across = child.fdjElbow[1], child.fdjElbow[2]
    local c = (theme and theme.border) or { 0.46, 0.30, 0.12, 1 }
    down:SetColorTexture(c[1], c[2], c[3], 0.9)
    across:SetColorTexture(c[1], c[2], c[3], 0.9)
    down:ClearAllPoints()
    down:SetPoint("TOPLEFT", child, "TOPLEFT", -12, 3)
    down:SetSize(2, 3 + math.floor(height / 2) + 1)
    across:ClearAllPoints()
    across:SetPoint("LEFT", child, "LEFT", -12, 0)
    across:SetSize(12, 2)
    down:Show()
    across:Show()

    child.icon:SetSize(compact and 20 or 30, compact and 20 or 30)
    child.icon:ClearAllPoints()
    child.icon:SetPoint("LEFT", compact and 5 or 8, 0)
    child.name:ClearAllPoints()
    if compact then
        child.name:SetPoint("LEFT", child.icon, "RIGHT", 7, 0)
    else
        child.name:SetPoint("TOPLEFT", child.icon, "TOPRIGHT", 8, -1)
    end
    child.name:SetPoint("RIGHT", -10, 0)
    child.name:SetFontObject(compact and "ForeverDJ_GameFontNormalSmall" or "ForeverDJ_GameFontNormal")
    child.slot:ClearAllPoints()
    child.slot:SetPoint("TOPLEFT", child.name, "BOTTOMLEFT", 0, -3)
    child.slot:SetPoint("RIGHT", -10, 0)
    child.slot:SetShown(not compact)
    if child.sharedText then child.sharedText:Hide() end

    child.item = made
    child.fdjDungeonName = selectedDungeon
    child.fdjBossName = boss and boss.name
    child.icon:SetTexture(ItemIcon(made[1]))
    if FDJ.UpdateFavouriteIndicator then FDJ.UpdateFavouriteIndicator(child, made[1]) end
    if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        pcall(C_Item.RequestLoadItemDataByID, made[1])
    end
    local name, link, quality = ItemInfo(made[1])
    child.name:SetText(name or made[2])
    child.name:SetTextColor(GetAuthoritativeItemQuality(made[1], link, quality, made[4]))

    local other, parts = nil, {}
    for _, half in ipairs(type(made.from) == "table" and made.from or {}) do
        local halfName = ItemInfo(half[1]) or half[2] or ""
        if tonumber(half[1]) ~= tonumber(item[1]) then other = halfName end
        parts[#parts + 1] = half[3] and (halfName .. " (" .. BossName(half[3]) .. ")") or halfName
    end
    child.slot:SetText(ItemSlot(made[3]) .. (other and ("  |  " .. L("LOOT_COMBINE_WITH", other)) or ""))
    child.fdjSourceText = (#parts >= 2) and L("LOOT_MADE_FROM", parts[1], parts[2]) or nil

    if theme then
        child:SetBackdropColor(unpack(theme.lootRow))
        child:SetBackdropBorderColor(unpack(theme.border))
        child.slot:SetTextColor(unpack(theme.muted))
    end
    local dimmed = parentDimmed or (FDJ.LootFilterRulesOut and FDJ.LootFilterRulesOut(made)) or false
    child:SetAlpha(dimmed and 0.28 or 1)
    if child.icon.SetDesaturated then child.icon:SetDesaturated(dimmed and true or false) end
    child:Show()
end

-- altarbosses (2.0.24): child rows in the boss list (bosses with childOf).
FDJ.BOSS_CHILD_INDENT, FDJ.BOSS_CHILD_HEIGHT = 22, 44
-- altarbosses (2.0.25): a group's children are shown or folded away with the
-- +/- on its row; closed until opened, remembered (account-wide).
function FDJ.BossGroupOpen(dungeonName, group)
    local t = type(ForeverDungeonJournalDB) == "table" and ForeverDungeonJournalDB.openBossGroups
    return type(t) == "table" and t[tostring(dungeonName) .. "|" .. tostring(group)] == true or false
end
function FDJ.SetBossGroupOpen(dungeonName, group, open)
    if type(ForeverDungeonJournalDB) ~= "table" then return end
    if type(ForeverDungeonJournalDB.openBossGroups) ~= "table" then ForeverDungeonJournalDB.openBossGroups = {} end
    ForeverDungeonJournalDB.openBossGroups[tostring(dungeonName) .. "|" .. tostring(group)] = open and true or nil
end

local function MakeBossButton(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(315, 55)

    SetBackdrop(
        button,
        "Interface\\Buttons\\WHITE8X8",
        "Interface\\Tooltips\\UI-Tooltip-Border",
        10,
        2
    )

    button.portrait = button:CreateTexture(nil, "ARTWORK")
    button.portrait:SetSize(44, 44)
    button.portrait:SetPoint("LEFT", 7, 0)
    button.portrait:SetTexCoord(0.05, 0.95, 0.05, 0.95)

    button.rareBorder = button:CreateTexture(nil, "OVERLAY")
    button.rareBorder:SetSize(64, 64)
    button.rareBorder:SetPoint("CENTER", button.portrait, "CENTER", 0, 0)
    button.rareBorder:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\RarePortraitDragonFrame.tga")
    button.rareBorder:SetTexCoord(0, 1, 0, 1)
    button.rareBorder:Hide()

    button.question = button:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalHuge")
    button.question:SetPoint("CENTER", button.portrait, "CENTER", 0, 0)
    button.question:SetText("?")
    button.question:SetTextColor(0.92, 0.72, 0.22)
    button.question:Hide()

    -- Level medallion: same visual language as the player/target level badge,
    -- tucked over the lower-left of the portrait.
    button.levelBadge = button:CreateTexture(nil, "OVERLAY", nil, 6)
    button.levelBadge:SetSize(28, 28)
    button.levelBadge:SetPoint("CENTER", button.portrait, "BOTTOMLEFT", 8, 2)
    button.levelBadge:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\BossLevelBadge.tga")
    button.levelBadge:Hide()

    button.levelText = button:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    button.levelText:SetPoint("CENTER", button.levelBadge, "CENTER", 0, 0)
    button.levelText:SetTextColor(1, 1, 1)
    button.levelText:SetShadowColor(0, 0, 0, 1)
    button.levelText:SetShadowOffset(1, -1)
    button.levelText:Hide()

    button.name = button:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    button.name:SetPoint("LEFT", button.portrait, "RIGHT", 11, 1)
    button.name:SetPoint("RIGHT", -10, 0)
    button.name:SetJustifyH("LEFT")

    button.rare = button:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
    button.rare:SetPoint("RIGHT", button, "RIGHT", -20, 1)
    button.rare:SetText(L("RARE"))
    button.rare:SetTextColor(1.00, 0.82, 0.00)
    button.rare:Hide()

    button:SetScript("OnClick", function(self)
        SelectBoss(self.index)
    end)

    return button
end


local function FactionColor(faction)
    if faction == "Alliance" then
        return "|cff5b8ff9"
    elseif faction == "Horde" then
        return "|cffff5a4f"
    end
    return "|cffffd34e"
end

local ALLIANCE_ICON = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\Alliance.tga"
local HORDE_ICON = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\Horde.tga"

local function FactionLabel(faction)
    local alliance = "|T" .. ALLIANCE_ICON .. ":24:24:0:0|t"
    local horde = "|T" .. HORDE_ICON .. ":24:24:0:0|t"

    if faction == "Both" or faction == "Neutral" then
        return alliance .. " " .. horde
    elseif faction == "Alliance" then
        return alliance
    elseif faction == "Horde" then
        return horde
    end
    return ""
end

-- ownfonts (2.0.8): the names passed here are the journal's own copies of the
-- game's quest fonts (Core/Fonts.lua), so an addon that restyles the game's
-- QuestFont (ElvUI's "Replace Blizzard Fonts") no longer changes this text.
local function ApplyQuestFont(fontString, preferred, fallback)
    if not fontString then return end

    local fontObject = _G[preferred]
    if not fontObject and fallback then
        fontObject = _G[fallback]
    end

    if fontObject and fontString.SetFontObject then
        fontString:SetFontObject(fontObject)
    end
end

local function ApplyRewardSummaryFont(fontString)
    if not fontString then return end
    -- Reward summaries can contain localized reputation names. On an English
    -- client the parchment QuestFont can miss individual Cyrillic glyphs even
    -- while larger quest-body text appears fine. Use the standard Blizzard UI
    -- font object here, which is the same family successfully used by the
    -- Russian journal headers/list labels and keeps Cyrillic intact.
    local fontObject = _G.ForeverDJ_GameFontNormalSmall or _G.ForeverDJ_GameFontNormal
    if fontObject and fontString.SetFontObject then
        fontString:SetFontObject(fontObject)
    end
end

-- chainready (2.0.8): the soft golden glow round a quest's row once its
-- chain is done and it can be taken (FDJ.QuestChainUnlocked): a golden
-- edge, gently breathing.
-- chainaura (2.0.8, M 15 Nov 2026: "not a marker... this aura, like clouds
-- going round the borders, the completion glow that gives you dopamine"):
-- the game's own spell-alert glow (the golden proc glow of an action
-- button: its soft outer glow and the swirling "ants" round the edge), cut
-- in nine so it fits a wide row (below). The ants run through their 22 frames
-- (Blizzard's IconAlertAnts sheet: 48 x 48 frames, 5 to a row on 256 x
-- 256). It fades in. Where the game has no such art, the golden edge
-- above, gently breathing, as before.
FDJ.AURA = { -- (FDJ fields: this chunk has no locals to spare)
    art = "Interface\\SpellActivationOverlay\\IconAlert",
    ants = "Interface\\SpellActivationOverlay\\IconAlertAnts",
    glow = { 0.00781250, 0.50781250, 0.27734375, 0.52734375 }, -- its outer glow
    step = 0.04, -- seconds a frame of the ants (auratone: calmer than the game's)
    -- auratone (2.0.8, M 15 Nov 2026: "a little bit too much... tone it
    -- down a little"): the outer glow and the ants a little fainter
    glowAlpha = 0.45, antsAlpha = 0.6,
    -- corners this big and the glow this far out round the row: the
    -- swirl's ring lies 0.14 of a frame in from its edge, so a quarter
    -- frame (corner) of 32 pixels puts it 9 out, on the row's edge
    corner = 32, pad = 9,
    -- auraray (2.0.8, M 15 Nov 2026: "the little squares moving round the
    -- edges look artificial... more linear, like a sun ray, cloudy, natural"):
    -- no more ants. The cloudy outer glow breathes slowly (glowLow to
    -- glowHigh, breath seconds), and a soft slanted beam of light
    -- (Media/ChainSheen.tga) glides across the row, sweep seconds, then rests.
    sheen = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\ChainSheen",
    sheenW = 84, sheenAlpha = 0.5, sweep = 1.5, rest = 2.2,
    glowLow = 0.30, glowHigh = 0.55, breath = 2.6,
    -- sunonce (2.0.8, M 15 Nov 2026: "make the sun ray appear only once on
    -- page load... or its annoying on the eyes"): the beam crosses each
    -- quest's row once per visit to the quest page (journal opened, dungeon
    -- changed, Quests tab), sheenDelay seconds after the glow appears; then
    -- only the breathing glow. (rest: no longer used.)
    sheenDelay = 0.25,
}
-- sunonce: the quests whose beam has played on this visit to the quest page
FDJ.chainSheenSeen = {}
FDJ.chainSheenEpoch = 0
FDJ.ResetChainSheen = function()
    FDJ.chainSheenSeen = {}
    FDJ.chainSheenEpoch = (FDJ.chainSheenEpoch or 0) + 1
end
-- arm a glow's beam: once per quest per visit
FDJ.ChainSheenArm = function(g)
    g.sheenEpoch = FDJ.chainSheenEpoch
    local key, seen = g.sheenKey, FDJ.chainSheenSeen
    if key ~= nil and seen[key] then
        g.sheenClock = nil
        if g.sheen then g.sheen:SetAlpha(0) end
        return
    end
    if key ~= nil then seen[key] = true end
    g.sheenClock = -(FDJ.AURA.sheenDelay or 0)
end
-- Cut in nine (four corners, four sides, the middle), so the swirl keeps
-- its size round a row of any height (a quest with its chain open is a
-- tall one): the corners are the frame's quarters at FDJ.AURA.corner
-- pixels, the sides its middle stretched. Order: TL T TR L C R BL B BR.
FDJ.ChainAuraLayout = function(g)
    local w, h = g:GetWidth() or 0, g:GetHeight() or 0
    if w <= 0 or h <= 0 then return end
    local c = math.min(FDJ.AURA.corner, h / 2, w / 2)
    for _, set in ipairs({ g.glow, g.ants }) do -- (g.ants: none since auraray)
        local TL, T, TR, Lf, C, R, BL, B, BR = unpack(set)
        for _, t in ipairs(set) do t:ClearAllPoints() end
        TL:SetPoint("TOPLEFT") TL:SetSize(c, c)
        TR:SetPoint("TOPRIGHT") TR:SetSize(c, c)
        BL:SetPoint("BOTTOMLEFT") BL:SetSize(c, c)
        BR:SetPoint("BOTTOMRIGHT") BR:SetSize(c, c)
        T:SetPoint("TOPLEFT", TL, "TOPRIGHT") T:SetPoint("BOTTOMRIGHT", TR, "BOTTOMLEFT")
        B:SetPoint("TOPLEFT", BL, "TOPRIGHT") B:SetPoint("BOTTOMRIGHT", BR, "BOTTOMLEFT")
        Lf:SetPoint("TOPLEFT", TL, "BOTTOMLEFT") Lf:SetPoint("BOTTOMRIGHT", BL, "TOPRIGHT")
        R:SetPoint("TOPLEFT", TR, "BOTTOMLEFT") R:SetPoint("BOTTOMRIGHT", BR, "TOPRIGHT")
        C:SetPoint("TOPLEFT", TL, "BOTTOMRIGHT") C:SetPoint("BOTTOMRIGHT", BR, "TOPLEFT")
        T:SetShown(w - 2 * c > 0.5) B:SetShown(w - 2 * c > 0.5)
        Lf:SetShown(h - 2 * c > 0.5) R:SetShown(h - 2 * c > 0.5)
        C:SetShown(set == g.glow and w - 2 * c > 0.5 and h - 2 * c > 0.5)
    end
end
-- one frame (l, r, t, b) cut in nine
FDJ.ChainAuraCoords = function(set, l, r, t, b)
    local mx, my = (l + r) / 2, (t + b) / 2
    local ex, ey = (r - l) * 0.04, (b - t) * 0.04
    set[1]:SetTexCoord(l, mx, t, my)
    set[2]:SetTexCoord(mx - ex, mx + ex, t, my)
    set[3]:SetTexCoord(mx, r, t, my)
    set[4]:SetTexCoord(l, mx, my - ey, my + ey)
    set[5]:SetTexCoord(mx - ex, mx + ex, my - ey, my + ey)
    set[6]:SetTexCoord(mx, r, my - ey, my + ey)
    set[7]:SetTexCoord(l, mx, my, b)
    set[8]:SetTexCoord(mx - ex, mx + ex, my, b)
    set[9]:SetTexCoord(mx, r, my, b)
end
FDJ.ChainAuraFrame = function(g, n)
    local col, row = (n - 1) % 5, math.floor((n - 1) / 5)
    local cw = 48 / 256
    FDJ.ChainAuraCoords(g.ants, col * cw, (col + 1) * cw, row * cw, (row + 1) * cw)
end
-- auraray: each frame, the glow's breath and the beam's place on the row
FDJ.ChainAuraTick = function(g, elapsed)
    local A = FDJ.AURA
    g.clock = (g.clock or 0) + (elapsed or 0)
    local t = g.clock
    local breath = A.glowLow + (A.glowHigh - A.glowLow) * (0.5 + 0.5 * math.sin(t * 2 * math.pi / A.breath))
    for k = 1, 9 do g.glow[k]:SetAlpha(breath) end
    local sheen = g.sheen
    if not sheen then return end
    -- sunonce: the quest page was opened again since this beam was armed
    if g.sheenEpoch ~= FDJ.chainSheenEpoch then FDJ.ChainSheenArm(g) end
    local sc = g.sheenClock
    if not sc then return end -- (played already: only the glow now)
    sc = sc + (elapsed or 0)
    g.sheenClock = sc
    local row = g:GetParent()
    local w, h = row and row:GetWidth() or 0, row and row:GetHeight() or 0
    local p = sc / A.sweep
    if p > 1 then g.sheenClock = nil end -- (once: done)
    if p < 0 or p > 1 or w <= A.sheenW then
        sheen:SetAlpha(0)
        return
    end
    sheen:ClearAllPoints()
    sheen:SetSize(A.sheenW, math.max(8, h - 4))
    sheen:SetPoint("LEFT", row, "LEFT", p * (w - A.sheenW), 0)
    sheen:SetAlpha(A.sheenAlpha * math.sin(p * math.pi))
end
FDJ.SetChainReadyGlow = function(button, on, key)
    local g = button and button.fdjReadyGlow
    -- chainglowoff (2.0.8, M 15 Nov 2026): the option "Remove quest glow on
    -- chain Pick it up" (Quests page) turns it off; "Pick it up" stays
    if on and ForeverDungeonJournalDB and ForeverDungeonJournalDB.hideChainGlow then on = false end
    if not on then
        if g then
            if g.pulse then g.pulse:Stop() end
            if g.fadeIn then g.fadeIn:Stop() end
            g:Hide()
        end
        return
    end
    if not g then
        g = CreateFrame("Frame", nil, button, "BackdropTemplate")
        g:SetFrameLevel(button:GetFrameLevel() + 6)
        g:EnableMouse(false)
        g.glow = {}
        local art = true
        for k = 1, 9 do
            local t = g:CreateTexture(nil, "ARTWORK")
            if t:SetTexture(FDJ.AURA.art) == false then art = false end
            t:SetBlendMode("ADD")
            t:SetAlpha(FDJ.AURA.glowAlpha)
            g.glow[k] = t
        end
        -- auraray: the beam (none until the game is restarted once: a new file)
        g.sheen = g:CreateTexture(nil, "OVERLAY")
        if g.sheen:SetTexture(FDJ.AURA.sheen) == false then
            g.sheen:Hide()
            g.sheen = nil
        else
            g.sheen:SetBlendMode("ADD")
            g.sheen:SetVertexColor(1.00, 0.86, 0.55)
            g.sheen:SetAlpha(0)
        end
        g.art = art
        if art then
            local pad = FDJ.AURA.pad
            g:SetPoint("TOPLEFT", button, "TOPLEFT", -pad, pad)
            g:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", pad, -pad)
            FDJ.ChainAuraCoords(g.glow, FDJ.AURA.glow[1], FDJ.AURA.glow[2], FDJ.AURA.glow[3], FDJ.AURA.glow[4])
            g.clock = 0
            g:SetScript("OnSizeChanged", FDJ.ChainAuraLayout)
            g:SetScript("OnUpdate", FDJ.ChainAuraTick)
            if g.CreateAnimationGroup then
                local fadeIn = g:CreateAnimationGroup()
                local a = fadeIn:CreateAnimation("Alpha")
                a:SetFromAlpha(0)
                a:SetToAlpha(1)
                a:SetDuration(0.35)
                g.fadeIn = fadeIn
            end
        else
            -- (the golden edge, gently breathing)
            for k = 1, 9 do g.glow[k]:Hide() end
            if g.sheen then g.sheen:Hide() g.sheen = nil end -- (auraray)
            g:SetPoint("TOPLEFT", -2, 2)
            g:SetPoint("BOTTOMRIGHT", 2, -2)
            if g.SetBackdrop then SetBackdrop(g, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 12, 2) end
            if g.SetBackdropColor then
                g:SetBackdropColor(1.00, 0.78, 0.08, 0.10)
                g:SetBackdropBorderColor(1.00, 0.82, 0.12, 0.95)
            end
            if g.CreateAnimationGroup then
                local pulse = g:CreateAnimationGroup()
                pulse:SetLooping("BOUNCE")
                local fade = pulse:CreateAnimation("Alpha")
                fade:SetFromAlpha(1)
                fade:SetToAlpha(0.40)
                fade:SetDuration(1.2)
                if fade.SetSmoothing then fade:SetSmoothing("IN_OUT") end
                pulse:SetScript("OnStop", function() g:SetAlpha(1) end)
                g.pulse = pulse
            end
        end
        g:Hide()
        button.fdjReadyGlow = g
    end
    local was = g:IsShown()
    if not was then g.clock = 0 end -- (auraray: the beam starts from the left)
    -- sunonce: the beam plays once per quest per visit to the quest page
    -- (a row taken over by another quest, a glow shown again, a new visit)
    if g.sheen and (not was or key ~= g.sheenKey or g.sheenEpoch ~= FDJ.chainSheenEpoch) then
        g.sheenKey = key
        FDJ.ChainSheenArm(g)
    end
    g:Show()
    if g.art then
        FDJ.ChainAuraLayout(g)
        if not was and g.fadeIn then g.fadeIn:Stop() g.fadeIn:Play() end
    elseif g.pulse and not g.pulse:IsPlaying() then
        g.pulse:Play()
    end
end

local function MakeQuestButton(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(296, 48)

    SetBackdrop(
        button,
        "Interface\\Buttons\\WHITE8X8",
        "Interface\\Tooltips\\UI-Tooltip-Border",
        10,
        2
    )

    button.completeGlow = CreateFrame("Frame", nil, button, "BackdropTemplate")
    button.completeGlow:SetPoint("TOPLEFT", -2, 2)
    button.completeGlow:SetPoint("BOTTOMRIGHT", 2, -2)
    SetBackdrop(
        button.completeGlow,
        "Interface\\Buttons\\WHITE8X8",
        "Interface\\Tooltips\\UI-Tooltip-Border",
        12,
        2
    )
    button.completeGlow:SetBackdropColor(0.05, 0.35, 0.08, 0.16)
    button.completeGlow:SetBackdropBorderColor(0.12, 1.00, 0.25, 0.90)
    button.completeGlow:EnableMouse(false)
    button.completeGlow:Hide()

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(24, 24)
    button.icon:SetPoint("TOPLEFT", 9, -8)
    button.icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")

    button.check = button:CreateTexture(nil, "OVERLAY")
    button.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    button.check:SetSize(22, 22)

    -- Keep the MAIN QUEST completion tick fixed beside the main quest header.
    -- Do not anchor it to the vertical center of the whole button, because the
    -- button becomes taller when prerequisite rows are expanded.
    button.check:SetPoint("TOPRIGHT", button, "TOPRIGHT", -8, -8)
    button.check:Hide()

    -- Ready to hand in: the quest tracker's round ? in place of the tick (a
    -- click shows where to hand the quest in).
    if FDJ.CreateTurnInButton then
        -- bigready: big and on its own (no faction icons) so nobody misses it.
        button.turnIn = FDJ.CreateTurnInButton(button, 44)
        button.turnIn:SetPoint("CENTER", button, "TOPRIGHT", -26, -24)
        button.turnIn:SetFrameLevel(button:GetFrameLevel() + 6)
    end
    -- turninlabel: "Turn in" left of the ?, in the quest tracker's green.
    if button.turnIn then
        button.turnInLabel = button:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
        button.turnInLabel:SetPoint("RIGHT", button.turnIn, "LEFT", 3, 0)
        button.turnInLabel:SetJustifyH("RIGHT")
        button.turnInLabel:SetTextColor(0.30, 1.00, 0.36)
        button.turnInLabel:Hide()
    end

    button.allianceIcon = button:CreateTexture(nil, "OVERLAY")
    button.allianceIcon:SetSize(20, 20)
    button.allianceIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -50, -8)
    button.allianceIcon:SetTexture(ALLIANCE_ICON)
    button.allianceIcon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    button.allianceIcon:Hide()

    button.hordeIcon = button:CreateTexture(nil, "OVERLAY")
    button.hordeIcon:SetSize(20, 20)
    button.hordeIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -28, -8)
    button.hordeIcon:SetTexture(HORDE_ICON)
    button.hordeIcon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    button.hordeIcon:Hide()

    button.classIcon = button:CreateTexture(nil, "OVERLAY")
    button.classIcon:SetSize(20, 20)
    button.classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
    button.classIcon:Hide()

    button.haveIt = button:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
    -- Status sits cleanly between the top border and the faction/class icons.
    -- Keep enough width for longer locales such as German, then shrink the
    -- font slightly only when the translated label still does not fit.
    button.haveIt:SetPoint("TOPRIGHT", -7, -7)
    button.haveIt:SetWidth(92)
    button.haveIt:SetJustifyH("RIGHT")
    button.haveIt:SetText(L("YOU_HAVE_IT"))
    button.haveIt:SetTextColor(1.00, 0.82, 0.10)
    button.haveIt:SetShadowColor(0, 0, 0, 0.72)
    button.haveIt:SetShadowOffset(1, -1)
    button.haveIt:Hide()

    button.UpdateHaveItLabel = function(self)
        local fs = self.haveIt
        if not fs then return end

        -- Always restore the Blizzard font object itself. Re-applying the raw
        -- font file from GetFont() breaks Cyrillic on non-Russian clients.
        -- Scaling the FontString preserves Blizzard's glyph fallback while
        -- still letting longer labels such as German fit in the status area.
        fs:SetFontObject("ForeverDJ_GameFontNormalSmall")
        fs:SetScale(1)
        fs:SetText(L("YOU_HAVE_IT"))

        local width = fs:GetStringWidth() or 0
        if width > 88 and width > 0 then
            local scale = 88 / width
            if scale < 0.80 then scale = 0.80 end
            fs:SetScale(scale)
        end
    end
    button:UpdateHaveItLabel()

    button.name = button:CreateFontString(nil, "OVERLAY")
    ApplyQuestFont(button.name, "ForeverDJ_QuestFont", "ForeverDJ_GameFontNormal")
    button.name:SetPoint("TOPLEFT", button, "TOPLEFT", 42, -9)
    button.name:SetWidth(182)
    button.name:SetWordWrap(true)
    button.name:SetJustifyH("LEFT")

    button.meta = button:CreateFontString(nil, "OVERLAY")
    ApplyQuestFont(button.meta, "ForeverDJ_QuestFontNormalSmall", "ForeverDJ_GameFontHighlightSmall")
    button.meta:SetPoint("TOPLEFT", button.name, "BOTTOMLEFT", 0, -5)
    button.meta:SetWidth(182)
    button.meta:SetWordWrap(true)
    button.meta:SetJustifyH("LEFT")

    button.chainToggle = CreateFrame("Button", nil, button)
    button.chainToggle:SetSize(16, 16)
    -- Keep the chain control inside the visible quest row and away from the title.
    button.chainToggle:SetPoint("RIGHT", button, "RIGHT", -86, -9)
    button.chainToggle:SetFrameLevel(button:GetFrameLevel() + 6)
    button.chainToggle:RegisterForClicks("LeftButtonUp")
    button.chainToggle:Hide()

    button.chainIcon = button.chainToggle:CreateTexture(nil, "OVERLAY")
    button.chainIcon:SetAllPoints()
    button.chainIcon:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\QuestChain.tga")
    button.chainIcon:SetTexCoord(0, 1, 0, 1)
    button.chainIcon:SetVertexColor(1, 1, 1)
    button.chainIcon:SetAlpha(1)

    button.chainToggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L("REQUIRED_QUESTS"), 1, 0.82, 0.25)
        GameTooltip:AddLine(L("SHOW_WHOLE_CHAIN"), 0.85, 0.85, 0.85)
        GameTooltip:Show()
    end)
    button.chainToggle:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button.chainToggle:SetScript("OnClick", function(self)
        local owner = self:GetParent()
        if not owner or not owner.questID then return end
        expandedQuestChains[owner.questID] = not expandedQuestChains[owner.questID]
        RefreshQuestList()
    end)

    button.chainPanel = CreateFrame("Frame", nil, button, "BackdropTemplate")
    button.chainPanel:SetPoint("TOPLEFT", button, "TOPLEFT", 39, -50)
    button.chainPanel:SetPoint("RIGHT", button, "RIGHT", -8, 0)
    SetBackdrop(
        button.chainPanel,
        "Interface\\Buttons\\WHITE8X8",
        "Interface\\Tooltips\\UI-Tooltip-Border",
        8,
        1
    )
    button.chainPanel:SetBackdropColor(0.04, 0.035, 0.03, 0.72)
    button.chainPanel:SetBackdropBorderColor(0.34, 0.27, 0.16, 0.85)
    button.chainPanel:Hide()
    -- choiceline (2.0.40): a wider or narrower journal: the lines again
    button.chainPanel.owner = button
    button.chainPanel:SetScript("OnSizeChanged", function(panel)
        local owner = panel.owner
        if owner and owner.layoutChain and panel:IsShown() and FDJ.LayoutChainRows then
            FDJ.LayoutChainRows(owner, owner.layoutChain, owner.layoutLineHeight or 18)
        end
    end)
    button.chainRows = {}

    -- questrowmenu (2.0.11, M 18 Nov 2026: "if i right click on a quest i
    -- have, i want to have this little blizzard panel that appears, but we
    -- should only have share and abandon"): right-click on a quest that is in
    -- the quest log: the game's own context menu, Share Quest / Abandon Quest.
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            if not self.fdjRPGHidden and FDJ.ShowQuestRowMenu then FDJ.ShowQuestRowMenu(self, self.questID, self.fdjQuestName) end
            return
        end
        -- Shift-click with a chat box open links the quest instead of selecting it.
        if not self.fdjRPGHidden and FDJ.TryLinkQuest and FDJ.TryLinkQuest(self.questID, self.fdjQuestName, self.fdjQuestLevel) then return end
        SelectQuest(self.questIndex)
    end)

    return button
end

local function MakeQuestRewardButton(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(176, 46)

    SetBackdrop(
        button,
        "Interface\\Buttons\\WHITE8X8",
        "Interface\\Tooltips\\UI-Tooltip-Border",
        9,
        2
    )

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(34, 34)
    button.icon:SetPoint("LEFT", 7, 0)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.name = button:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
    button.name:SetPoint("LEFT", button.icon, "RIGHT", 8, 0)
    button.name:SetPoint("RIGHT", -6, 0)
    button.name:SetJustifyH("LEFT")
    button.name:SetWordWrap(true)

    button:SetScript("OnEnter", function(self)
        HideSearchItemHighlight(self)
        if not self.item then return end
        self.fdjHoverColor = { 0.30, 0.22, 0.10 }
        self:SetBackdropColor(0.30, 0.22, 0.10, 1)
        ShowItemTooltip(self)
    end)

    button:SetScript("OnLeave", function(self)
        local theme = THEMES[selectedDungeon] or THEMES["Hall of Thanes"]
        self.fdjHoverColor = nil
        self:SetBackdropColor(unpack(theme.lootRow))
        self.fdjComparing = nil
        -- setstrip: an open set row stays while the mouse goes onto it
        if not (FDJ.SetStripKeep and FDJ.SetStripKeep(self)) then
            if FDJ.CloseSetStrip then FDJ.CloseSetStrip(self) end
            if itemTooltip then itemTooltip:Hide() end
        end
        HideComparisonTooltips()
    end)
    button.fdjSetClick = true -- setstrip (2.0.8): a set piece shows its set when clicked

    button:SetScript("OnUpdate", function(self)
        KeepHoverColor(self)
        UpdateItemComparison(self)
    end)

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, mouseButton)
        if not self.item then return end
        if not self.item[1] or self.item[1] <= 0 then return end

        -- Right-click: add to / remove from Favourites, remembering the quest.
        if mouseButton == "RightButton" then
            if FDJ.ShowItemFavouriteMenu then
                local quests = DB[selectedDungeon] and DB[selectedDungeon].quests or {}
                local quest = quests[selectedQuest]
                local favItem = { self.item[1], self.item[2], nil, tonumber(self.item[3]) }
                FDJ.ShowItemFavouriteMenu(self, favItem, selectedDungeon, nil,
                    quest and { id = quest.id, name = quest.name } or nil)
            end
            return
        end

        -- itemhint (2.1.3): the item the "Click the item to see location"
        -- note points at: a plain click goes down to the quest's minimap
        -- picture (FDJ.PlaceItemLocationHint).
        if self.fdjNoteImageClick and not (IsModifiedClick and (IsModifiedClick("CHATLINK") or IsModifiedClick("DRESSUP"))) then
            if itemTooltip then itemTooltip:Hide() end
            HideComparisonTooltips()
            FDJ.ShowNoteImageLocation()
            return
        end

        -- An item with a recorded place (for example a quest object): a plain
        -- click marks that place on the map, like Show on Map.
        if self.fdjMapLocation and not (IsModifiedClick and (IsModifiedClick("CHATLINK") or IsModifiedClick("DRESSUP"))) then
            if itemTooltip then itemTooltip:Hide() end
            HideComparisonTooltips()
            local src = self.fdjMapLocation
            if src.dungeon and FDJ.ShowQuestSpotOnDungeonMap then -- mapquests: a spot in a dungeon
                FDJ.ShowQuestSpotOnDungeonMap(src)
                return
            end
            local loc = {
                mapID = src.mapID, x = src.x, y = src.y, markerType = src.markerType,
                label = FDJ.LocalizeFreeText and FDJ.LocalizeFreeText(src.label) or src.label,
                detail = FDJ.LocalizeFreeText and FDJ.LocalizeFreeText(src.detail) or src.detail,
            }
            ShowRecordedLocationOnMap(loc, loc.label)
            return
        end

        if self.fdjBossJump and not (IsModifiedClick and (IsModifiedClick("CHATLINK") or IsModifiedClick("DRESSUP")))
            and FDJ.JumpToBossDrop and FDJ.JumpToBossDrop(self.item[1]) then
            if itemTooltip then itemTooltip:Hide() end
            HideComparisonTooltips()
            return
        end
        -- setstrip (2.0.8): a plain click on a set piece shows / hides its set
        if not (IsModifiedClick and (IsModifiedClick("CHATLINK") or IsModifiedClick("DRESSUP")))
            and FDJ.ToggleSetStrip and FDJ.ToggleSetStrip(self) then
            return
        end
        local _, link = ItemInfo(self.item[1])
        if link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
            local used = ChatEdit_InsertLink(link)
            if used then return end
        end
        if link and IsModifiedClick and IsModifiedClick("DRESSUP") and DressUpItemLink then
            DressUpItemLink(link)
        end
    end)

    return button
end


local function MakeQuestNoteRewardButton(parent)
    -- Follow-up rewards use the exact same visual/tooltip behavior as normal
    -- quest rewards: icon + quality-colored name, full item tooltip on hover,
    -- Shift-hover comparison, and normal Shift-click chat linking.
    return MakeQuestRewardButton(parent)
end


local function CreateModeButton(parent, label, x)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    FDJ.OwnFonts(button) -- ownfonts (2.0.8)
    button:SetSize(96, 22)
    button:SetPoint("TOPRIGHT", x, -18)
    button:SetText(label)
    button.text = button.GetFontString and button:GetFontString() or nil
    if button.text then
        button.text:SetTextColor(1.00, 0.82, 0.27)
    end
    return button
end

local function UpdateModeTabs()
    if not frame or not frame.bossesTab or not frame.questsTab then return end
    local theme = THEMES[selectedDungeon] or THEMES["Hall of Thanes"]
    local mapActive = frame.dungeonMapPanel and frame.dungeonMapPanel:IsShown() or false
    local routeActive = frame.routePanel and frame.routePanel:IsShown() or false
    local function style(tab, active)
        if not tab then return end
        if active then
            if tab.Disable then tab:Disable() end
            tab:SetAlpha(1)
            if tab.text then tab.text:SetTextColor(unpack(theme.title)) end
        else
            if tab.Enable then tab:Enable() end
            tab:SetAlpha(0.95)
            if tab.text then tab.text:SetTextColor(1.00, 0.82, 0.27) end
        end
    end
    style(frame.bossesTab, (not mapActive) and (not routeActive) and selectedMode == "bosses")
    style(frame.questsTab, (not mapActive) and (not routeActive) and selectedMode == "quests")
    if frame.mapTab and frame.mapTab:IsShown() then style(frame.mapTab, mapActive) end
    if frame.dungeonRouteButton and frame.dungeonRouteButton:IsShown() then
        style(frame.dungeonRouteButton, routeActive)
    end
    -- A chain page's Map tab is its dungeon's map (the Mallet -> Zul'Farrak).
    local mapOf = DB[selectedDungeon] and DB[selectedDungeon].questChainPage and DB[selectedDungeon].parentDungeon or selectedDungeon
    if FDJ.RPGStyleMapTab then FDJ.RPGStyleMapTab(frame.mapTab, mapOf) end -- rpgpartial: greyed out
end

local function UpdateDungeonHeaderTabs()
    if not frame or not frame.bossesTab or not frame.questsTab then return end

    local currentDungeon = DB[selectedDungeon]
    if currentDungeon and (currentDungeon.recipeSearch or currentDungeon.lootFilterPage) then
        frame.questsTab:Hide()
        frame.bossesTab:Show()
        frame.bossesTab:ClearAllPoints()
        frame.bossesTab:SetSize(108, 30)
        frame.bossesTab:SetPoint("TOPRIGHT", -13, -14)
        if frame.mapTab then frame.mapTab:Hide() end
        if frame.dungeonRouteButton then frame.dungeonRouteButton:Hide() end
        return
    end

    -- sleepingbag: a page that is one quest chain has its Quests tab only;
    -- one that belongs to a dungeon (parentDungeon: the Mallet of
    -- Zul'Farrak) also gets that dungeon's Bosses and Map tabs, laid out
    -- below like any dungeon's (FDJ.OpenParentDungeon opens it).
    local chainParent
    if currentDungeon and currentDungeon.questChainPage then
        frame.bossesTab:Hide()
        frame.questsTab:Show()
        frame.questsTab:ClearAllPoints()
        frame.questsTab:SetSize(108, 30)
        frame.questsTab:SetPoint("TOPRIGHT", -13, -14)
        if frame.mapTab then frame.mapTab:Hide() end
        if frame.dungeonRouteButton then frame.dungeonRouteButton:Hide() end
        if frame.dungeonMapPanel then frame.dungeonMapPanel:Hide() end
        chainParent = currentDungeon.parentDungeon
        if not (chainParent and DB[chainParent]) then return end
    end

    -- Restore both normal tabs after leaving a hidden recipe-source page.
    frame.questsTab:Show()
    frame.bossesTab:Show()

    -- All dungeons now use the same larger two-tab layout.  The experimental
    -- dungeon-map tab is disabled for now until the map presentation is ready.
    frame.questsTab:ClearAllPoints()
    frame.questsTab:SetSize(108, 30)
    frame.questsTab:SetPoint("TOPRIGHT", -13, -14)

    frame.bossesTab:ClearAllPoints()
    frame.bossesTab:SetSize(108, 30)
    frame.bossesTab:SetPoint("TOPRIGHT", -127, -14)

    if frame.dungeonRouteButton and frame.dungeonRouteButton:IsShown() then
        frame.dungeonRouteButton:ClearAllPoints()
        frame.dungeonRouteButton:SetSize(96, 30)
        frame.dungeonRouteButton:SetPoint("LEFT", (frame.lfgButton and frame.lfgButton:IsShown()) and frame.lfgButton or frame.dungeonLocationButton, "RIGHT", 3, 0)
    end

    if frame.dungeonMapPanel then frame.dungeonMapPanel:Hide() end
    if frame.mapTab then
        if FDJ.DUNGEON_MAPS[chainParent or selectedDungeon] then
            frame.mapTab:ClearAllPoints()
            frame.mapTab:SetSize(108, 30)
            -- Keep Map in its original tab slot: immediately left of Bosses.
            -- Route stays by the entrance/location button near the dungeon title.
            frame.mapTab:SetPoint("TOPRIGHT", -241, -14)
            frame.mapTab:SetText(L("MAP"))
            frame.mapTab:Show()
        else
            frame.mapTab:Hide()
        end
    end
    -- Announced dungeons: no boss or quest pages, so Map is the only tab.
    if currentDungeon and currentDungeon.previewOnly and frame.mapTab and FDJ.DUNGEON_MAPS[selectedDungeon] then
        frame.bossesTab:Hide()
        frame.questsTab:Hide()
        frame.mapTab:ClearAllPoints()
        frame.mapTab:SetPoint("TOPRIGHT", -13, -14)
    end
    -- Keep "Items Data TBD" just left of the leftmost visible header button,
    -- clear of the title and its Show Location icon.
    if frame.stockadeItemsTBD then
        -- Sits on the level line under the title ("LV 30-38   Items Data TBD"),
        -- which is always free, so long dungeon names never collide with it.
        frame.stockadeItemsTBD:ClearAllPoints()
        if frame.dungeonMeta then
            frame.stockadeItemsTBD:SetPoint("LEFT", frame.dungeonMeta, "RIGHT", 14, 0)
        else
            frame.stockadeItemsTBD:SetPoint("RIGHT", frame.bossesTab, "LEFT", -12, 0)
        end
    end

    -- UIPanelButtonTemplate normally swaps font objects on hover/disabled.
    -- Force the same object in every state so the labels never resize.
    for _, tab in ipairs({ frame.bossesTab, frame.questsTab, frame.mapTab }) do
        if tab.SetNormalFontObject then tab:SetNormalFontObject("ForeverDJ_GameFontNormal") end
        if tab.SetHighlightFontObject then tab:SetHighlightFontObject("ForeverDJ_GameFontNormal") end
        if tab.SetDisabledFontObject then tab:SetDisabledFontObject("ForeverDJ_GameFontNormal") end
        if tab.text then tab.text:SetFontObject("ForeverDJ_GameFontNormal") end
    end

    -- Boss icon: oversized skull that slightly overflows the button, matching
    -- the Forever quest-tab treatment.
    if not frame.bossesTab.fdjIcon then
        frame.bossesTab.fdjIcon = frame.bossesTab:CreateTexture(nil, "OVERLAY")
    end
    frame.bossesTab.fdjIcon:SetSize(26, 26)
    frame.bossesTab.fdjIcon:ClearAllPoints()
    frame.bossesTab.fdjIcon:SetPoint("LEFT", 3, 0)
    frame.bossesTab.fdjIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
    frame.bossesTab.fdjIcon:Show()
    if frame.bossesTab.text then
        frame.bossesTab.text:ClearAllPoints()
        frame.bossesTab.text:SetPoint("CENTER", frame.bossesTab, "CENTER", 7, 0)
    end

    -- Quest icon: use the current Forever/Blizzard quest atlas when available.
    if not frame.questsTab.fdjIcon then
        frame.questsTab.fdjIcon = frame.questsTab:CreateTexture(nil, "OVERLAY")
    end
    frame.questsTab.fdjIcon:SetSize(27, 27)
    frame.questsTab.fdjIcon:ClearAllPoints()
    frame.questsTab.fdjIcon:SetPoint("LEFT", 3, 0)
    local atlasOK = false
    if frame.questsTab.fdjIcon.SetAtlas then
        atlasOK = pcall(frame.questsTab.fdjIcon.SetAtlas, frame.questsTab.fdjIcon, "QuestNormal", true)
    end
    if not atlasOK then
        frame.questsTab.fdjIcon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    end
    frame.questsTab.fdjIcon:Show()
    if frame.questsTab.text then
        frame.questsTab.text:ClearAllPoints()
        frame.questsTab.text:SetPoint("CENTER", frame.questsTab, "CENTER", 7, 0)
    end

    -- Map icon: use the supplied parchment-map icon in the same oversized
    -- left-side style as the Bosses skull and Quests exclamation mark.
    if frame.mapTab then
        if not frame.mapTab.fdjIcon then
            frame.mapTab.fdjIcon = frame.mapTab:CreateTexture(nil, "OVERLAY")
        end
        -- Same icon as the Bloody Map item (Ability_Spy), edges trimmed.
        frame.mapTab.fdjIcon:SetSize(24, 24)
        frame.mapTab.fdjIcon:ClearAllPoints()
        frame.mapTab.fdjIcon:SetPoint("LEFT", 5, 0)
        frame.mapTab.fdjIcon:SetTexture("Interface\\Icons\\Ability_Spy")
        frame.mapTab.fdjIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        -- Thin black frame around the icon.
        if not frame.mapTab.fdjIconBorder then
            frame.mapTab.fdjIconBorder = frame.mapTab:CreateTexture(nil, "ARTWORK", nil, 7)
            frame.mapTab.fdjIconBorder:SetColorTexture(0, 0, 0, 1)
        end
        frame.mapTab.fdjIconBorder:ClearAllPoints()
        frame.mapTab.fdjIconBorder:SetPoint("TOPLEFT", frame.mapTab.fdjIcon, "TOPLEFT", -1.5, 1.5)
        frame.mapTab.fdjIconBorder:SetPoint("BOTTOMRIGHT", frame.mapTab.fdjIcon, "BOTTOMRIGHT", 1.5, -1.5)
        frame.mapTab.fdjIconBorder:Show()
        frame.mapTab.fdjIcon:Show()
        if frame.mapTab.text then
            frame.mapTab.text:ClearAllPoints()
            frame.mapTab.text:SetPoint("CENTER", frame.mapTab, "CENTER", 7, 0)
        end
    end
    -- A chain page's Map tab is its dungeon's map (the Mallet -> Zul'Farrak).
    local mapOf = DB[selectedDungeon] and DB[selectedDungeon].questChainPage and DB[selectedDungeon].parentDungeon or selectedDungeon
    if FDJ.RPGStyleMapTab then FDJ.RPGStyleMapTab(frame.mapTab, mapOf) end -- rpgpartial: greyed out
end

local function UpdateFactionButtons()
    if not frame or not frame.allianceQuestButton or not frame.hordeQuestButton then
        return
    end

    local theme = THEMES[selectedDungeon] or THEMES["Hall of Thanes"]

    local function Style(button, active, faction)
        if active then
            button:SetBackdropColor(unpack(theme.rowSelected))
            button:SetBackdropBorderColor(unpack(theme.title))
            button.icon:SetAlpha(1)
        else
            button:SetBackdropColor(unpack(theme.row))
            button:SetBackdropBorderColor(unpack(theme.border))
            button.icon:SetAlpha(0.55)
        end
    end

    Style(frame.allianceQuestButton, selectedQuestFaction == "Alliance", "Alliance")
    Style(frame.hordeQuestButton, selectedQuestFaction == "Horde", "Horde")
    -- sleepingbag: a quest chain page shows the character's faction only.
    -- bothFactions: such a page with the Alliance / Horde buttons all the same.
    local single = DB[selectedDungeon] and DB[selectedDungeon].questChainPage and not DB[selectedDungeon].bothFactions
    frame.allianceQuestButton:SetShown(not single)
    frame.hordeQuestButton:SetShown(not single)
    -- questrowtrial: locked to the character's faction: its crest alone,
    -- where the right one sits, lit
    local locked = (not single) and FDJ.FactionLocked(selectedDungeon) and FDJ.PlayerFaction()
    frame.allianceQuestButton:ClearAllPoints()
    frame.allianceQuestButton:SetPoint("TOPRIGHT", (locked == "Alliance") and -10 or -66, -7)
    frame.allianceQuestButton.fdjLocked = locked == "Alliance"
    frame.hordeQuestButton.fdjLocked = locked == "Horde"
    if locked then
        frame.allianceQuestButton:SetShown(locked == "Alliance")
        frame.hordeQuestButton:SetShown(locked == "Horde")
    end
end
FDJ.UpdateQuestFactionButtons = UpdateFactionButtons

local function BuildVisibleQuestIndexes()
    wipe(visibleQuestIndexes)
    if FDJ.FactionLocked(selectedDungeon) then selectedQuestFaction = FDJ.PlayerFaction() end -- questrowtrial
    if FDJ.ApplyViewFaction then FDJ.ApplyViewFaction(selectedQuestFaction) end -- voodooview

    local dungeon = DB[selectedDungeon]
    local quests = dungeon.quests or {}

    -- Repeatable quests (librams...) sit under a folded divider at the end of
    -- the list and never count towards the quest totals.
    local repeatables = {}
    -- hidedone (2.1.3, M 21 Nov 2026: "a quest option ... hide the completed
    -- quests ... The journal main page stays the same ... when you click on
    -- the dungeon, you're just gonna see the quests that you actually need to
    -- complete"; the option is in Options > Quests, Systems/SettingsPanel.lua):
    -- with it on, the quests handed in are left out of the list
    -- (FDJ.QuestHiddenAsDone).
    FDJ.questDoneCount, FDJ.questDoneHidden = 0, 0
    for index, quest in ipairs(quests) do
        if QuestMatchesFaction(quest, selectedQuestFaction) and not quest.hideFromMainList then
            if quest.repeatable then
                repeatables[#repeatables + 1] = index
            elseif FDJ.QuestTurnedIn(quest.id) then
                FDJ.questDoneCount = FDJ.questDoneCount + 1
                if ForeverDungeonJournalDB.hideDoneQuests then
                    FDJ.questDoneHidden = FDJ.questDoneHidden + 1
                else
                    table.insert(visibleQuestIndexes, index)
                end
            else
                table.insert(visibleQuestIndexes, index)
            end
        end
    end
    FDJ.questMainCount = #visibleQuestIndexes
    FDJ.questRepeatCount = #repeatables
    if FDJ.questRepeatExpanded then
        for _, index in ipairs(repeatables) do table.insert(visibleQuestIndexes, index) end
    end

    local selectedVisible = false
    for _, index in ipairs(visibleQuestIndexes) do
        if index == selectedQuest then
            selectedVisible = true
            break
        end
    end

    -- Hidden quests may still be opened deliberately through an in-journal
    -- quest link (for optional/breadcrumb pages). Keep that page selected
    -- without adding it back to the normal quest list.
    if not selectedVisible and allowHiddenQuestSelection then
        local selected = quests[selectedQuest]
        if selected and (selected.hideFromMainList or FDJ.QuestHiddenAsDone(selected)) and QuestMatchesFaction(selected, selectedQuestFaction) then
            selectedVisible = true
        end
    end

    if not selectedVisible then
        allowHiddenQuestSelection = false
        selectedQuest = visibleQuestIndexes[1] or 1
        for _, index in ipairs(visibleQuestIndexes) do -- rpgpartial: an unlocked one first
            if not (FDJ.RPGQuestHidden and FDJ.RPGQuestHidden(selectedDungeon, quests[index])) then
                selectedQuest = index
                break
            end
        end
        ForeverDungeonJournalDB.lastQuest = selectedQuest
    end
end

-- postquests (2.1.3): the quests the list shows and counts (this faction's,
-- not the repeatable ones below it, not the lost ones, not those RPG mode
-- keeps hidden), for the chat bubble (Systems/LFGButton.lua).
FDJ.ShownQuestsForChat = function()
    local out = {}
    local dungeon = DB[selectedDungeon]
    local quests = dungeon and dungeon.quests or {}
    local mainCount = FDJ.questMainCount or #visibleQuestIndexes
    for i = 1, mainCount do
        local quest = quests[visibleQuestIndexes[i]]
        if type(quest) == "table" and type(quest.id) == "number"
            and not (FDJ.IsQuestLost and FDJ.IsQuestLost(quest))
            and not (FDJ.RPGQuestHidden and FDJ.RPGQuestHidden(selectedDungeon, quest)) then
            out[#out + 1] = { id = quest.id, name = QuestField(quest.id, "name", quest.name), level = quest.level }
        end
    end
    return out
end

RefreshQuestList = function()
    if not frame or not frame.questContent then return end

    local dungeon = DB[selectedDungeon]
    local quests = dungeon.quests or {}
    local theme = THEMES[selectedDungeon] or THEMES["Hall of Thanes"]

    BuildVisibleQuestIndexes()
    UpdateFactionButtons()

    do -- lostquest: lost quests aren't counted
        local shownCount = FDJ.questMainCount or #visibleQuestIndexes
        for i = 1, shownCount do
            if quests[visibleQuestIndexes[i]] and FDJ.IsQuestLost(quests[visibleQuestIndexes[i]]) then shownCount = shownCount - 1 end
        end
        frame.questListTitle:SetText(L("QUESTS") .. "  |  " .. (shownCount + (FDJ.questDoneHidden or 0))) -- (hidedone: still every quest)
        if FDJ.UpdateQuestPostButton then FDJ.UpdateQuestPostButton(shownCount) end -- postquests (2.1.3)
    end
    if FDJ.UpdateQuestsTBD then FDJ.UpdateQuestsTBD() end

    local contentHeight = 0
    local mainCount = FDJ.questMainCount or #visibleQuestIndexes
    local repeatCount = FDJ.questRepeatCount or 0
    local repeatLine = frame.questRepeatLine
    if repeatCount > 0 and not repeatLine then
        repeatLine = CreateFrame("Button", nil, frame.questContent)
        frame.questRepeatLine = repeatLine
        repeatLine:SetHeight(24)
        repeatLine.rule = repeatLine:CreateTexture(nil, "BACKGROUND")
        repeatLine.rule:SetHeight(1)
        repeatLine.rule:SetPoint("BOTTOMLEFT", 0, 0)
        repeatLine.rule:SetPoint("BOTTOMRIGHT", 0, 0)
        repeatLine.rule:SetColorTexture(0.48, 0.40, 0.27, 0.6)
        repeatLine.icon = repeatLine:CreateTexture(nil, "ARTWORK")
        repeatLine.icon:SetSize(16, 16)
        repeatLine.icon:SetPoint("LEFT", 4, 0)
        repeatLine.text = repeatLine:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
        repeatLine.text:SetPoint("LEFT", repeatLine.icon, "RIGHT", 6, 0)
        repeatLine.text:SetJustifyH("LEFT")
        repeatLine:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        repeatLine:SetScript("OnClick", function()
            FDJ.questRepeatExpanded = not FDJ.questRepeatExpanded
            RefreshQuestList()
        end)
    end
    for displayIndex = 1, math.max(#questButtons, #visibleQuestIndexes) do
        local button = questButtons[displayIndex]
        local questIndex = visibleQuestIndexes[displayIndex]

        if questIndex then
            if not button then
                button = MakeQuestButton(frame.questContent)
                questButtons[displayIndex] = button
            end
            -- Anchored every refresh: the first repeatable quest hangs under
            -- the "Repeatable Quests" divider instead of the quest above it.
            button:ClearAllPoints()
            if displayIndex == 1 then
                button:SetPoint("TOPLEFT", frame.questContent, "TOPLEFT", 0, 0)
            elseif displayIndex == mainCount + 1 and repeatLine then
                button:SetPoint("TOPLEFT", repeatLine, "BOTTOMLEFT", 0, -3)
            else
                button:SetPoint("TOPLEFT", questButtons[displayIndex - 1], "BOTTOMLEFT", 0, -3)
            end

            local quest = quests[questIndex]
            -- rpgpartial: RPG Mode, a quest not unlocked yet is a ??? row.
            local rpgHidden = FDJ.RPGQuestHidden and FDJ.RPGQuestHidden(selectedDungeon, quest) or false
            button.fdjRPGHidden = rpgHidden
            local complete = IsQuestFinished(quest.id)
            local inLog = IsQuestInLog(quest.id)
            local ready = complete and inLog and not FDJ.QuestTurnedIn(quest.id)

            button.questIndex = questIndex
            -- turninlabel: ready to hand in, "Turn in" beside the ?, the
            -- quest's name kept clear of it.
            if button.turnInLabel then
                button.turnInLabel:SetText(L("TURN_IN_LABEL"))
                button.turnInLabel:SetShown(ready == true)
                button.fdjTextRoom = ready and math.max(120, math.min(182, 203 - (button.turnInLabel:GetStringWidth() or 0))) or 182
                button.name:SetWidth(button.fdjTextRoom)
                button.meta:SetWidth(button.fdjTextRoom)
            end
            -- questrowtrial (2.0.8): its quest chain done and the quest not
            -- taken yet: "Pick it up" left of the round ! (placed with the
            -- icons below), the name kept clear of it.
            -- malletone (2.1.3): not for a quest that is not picked up (quest.noPickUp)
            if FDJ.QuestRowTrial(selectedDungeon) and not rpgHidden and not quest.noPickUp and FDJ.QuestChainUnlocked(quest) then
                if not button.pickUpLabel then
                    button.pickUpLabel = button:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
                    button.pickUpLabel:SetJustifyH("RIGHT")
                    button.pickUpLabel:SetTextColor(1.00, 0.82, 0.10)
                end
                button.pickUpLabel:SetText(L("PICK_IT_UP"))
                button.pickUpLabel:Show()
                local _, _, _, _, classToken = GetQuestClassRestriction(quest)
                button.fdjTextRoom = math.max(120, math.min(182, 203 - (button.pickUpLabel:GetStringWidth() or 0) - (classToken and 22 or 0)))
                button.name:SetWidth(button.fdjTextRoom)
                -- metaroom (2.0.8, M 15 Nov 2026: "why are the quests moving
                -- the chain and in dungeon icon to the bottom left once the
                -- pick up option appears?"): "Pick it up" sits on the title's
                -- line (pickclear), so only the title makes room for it. The
                -- "Available from Level X" line keeps its full width: no
                -- wrapping, its icons stay right after it.
                button.meta:SetWidth(182)
            elseif button.pickUpLabel then
                button.pickUpLabel:Hide()
            end
            button.name:SetText(rpgHidden and "???" or QuestField(quest.id, "name", quest.name))
            button.meta:SetText(rpgHidden and "" or L("AVAILABLE_FROM_LEVEL", FDJ.QuestLevelText(quest.requires))) -- (redlevel)
            local titleHeight = math.max(14, button.name:GetStringHeight() or 14)
            local metaHeight = math.max(12, button.meta:GetStringHeight() or 12)
            local baseRowHeight = math.max(48, 9 + titleHeight + 5 + metaHeight + 10)
            local rowHeight = baseRowHeight

            button.questID = quest.id
            button.fdjQuestName = quest.name
            button.fdjQuestLevel = quest.level
            local rawChain = (not rpgHidden) and GetQuestPrereqChain(quest) or nil
            -- turninclean: ready to hand in, the row shows only the big ?
            -- and "Turn in": no In Dungeon, class or faction icons.
            -- They all come back with the tick once it is handed in.
            -- turninchain (2.0.9, M 16 Nov 2026: "I think we should still
            -- have the possibility to show the list in case somebody wants
            -- to help a friend that's stuck behind"): the chain icon stays,
            -- and the chain list opens from it or from Show Quest Chain.
            local chain = rawChain

            local chainExpanded = chain and expandedQuestChains[quest.id] == true
            -- questguide: a guide quest's steps open from a red Guide
            -- button instead of the chain icon.
            button.fdjGuide = chain ~= nil and FDJ.IsGuideQuest(quest.id)

            if button.chainToggle then
                button.chainToggle:SetShown(chain ~= nil and not button.fdjGuide)
                button.chainToggle:ClearAllPoints()
                -- Keep the chain control directly to the right of the
                -- "Available from Level X" text. This keeps it away from long
                -- quest titles while leaving the faction/class icons on the far right.
                local metaWidth, wrappedY = FDJ.MetaIconSpot(button.meta)
                if wrappedY then
                    button.chainToggle:SetPoint("LEFT", button.meta, "BOTTOMLEFT", metaWidth + 6, wrappedY)
                else
                    button.chainToggle:SetPoint("LEFT", button.meta, "LEFT", metaWidth + 6, 0)
                end
            end
            FDJ.SetRowGuideButton(button, button.fdjGuide)
            -- startsInDungeon = true on a quest forces the icon even when the
            -- quest has a chain (its chain starts inside the dungeon); the icon
            -- then sits to the right of the chain control.
            -- A wrapped "Available from Level X" (French...): the icons go
            -- after its last line, side by side (room enough there).
            local metaLastWidth, metaWrappedY = FDJ.MetaIconSpot(button.meta)
            local rowIconOffset = metaLastWidth + 6
            if chain and button.chainToggle then rowIconOffset = rowIconOffset + (FDJ.RowChainControl(button):GetWidth() or 20) + 4 end
            FDJ.SetRowDungeonIcon(button, (not rpgHidden) and (not ready) and (quest.startsInDungeon or ((not chain or button.fdjGuide) and (FDJ.StartsInsideDungeon(quest.pickup)
                or FDJ.StartItemDropsIn(quest, selectedDungeon)))
                or (chain and not button.fdjGuide and FDJ.ChainStartsInside(quest, selectedDungeon) == true)), rowIconOffset, metaWrappedY)
            -- With a chain control, the faction icons leave no room to its
            -- right: stack the dungeon icon on top of the chain control.
            if not metaWrappedY and chain and button.chainToggle and button.dungeonStartIcon and button.dungeonStartIcon:IsShown() then
                button.dungeonStartIcon:ClearAllPoints()
                -- pickclear (2.0.8): with "Pick it up" on the title's line
                -- the icon goes beside the chain control too, under the text.
                if selectedDungeon == "Alcaz Prison" or (button.pickUpLabel and button.pickUpLabel:IsShown()) then
                    -- alcazicons: its titles are long ("More Valuable Than
                    -- Gold"): the icon goes beside the chain control, on the
                    -- "Available from" line, not on top of it over the title.
                    button.dungeonStartIcon:SetPoint("LEFT", FDJ.RowChainControl(button), "RIGHT", 2, 0)
                else
                    button.dungeonStartIcon:SetPoint("BOTTOM", FDJ.RowChainControl(button), "TOP", 0, -2)
                end
            end

            if chain and chainExpanded and button.chainPanel then
                local lineHeight = 18
                -- pickone (2.0.42): a choice is one line, plus its quests when open
                local panelHeight = 10 + (FDJ.ChainLineCount(quest.id, chain, selectedPrereqStep) * lineHeight) + 7
                for _, h in pairs(button.choiceHeaders or {}) do h:Hide() end
                button.chainPanel:ClearAllPoints()
                button.chainPanel:SetPoint("TOPLEFT", button, "TOPLEFT", 39, -baseRowHeight + 2)
                button.chainPanel:SetPoint("RIGHT", button, "RIGHT", -8, 0)
                button.chainPanel:SetHeight(panelHeight)
                button.chainPanel:Show()

                for chainIndex, step in ipairs(chain) do
                    local row = button.chainRows[chainIndex]
                    if not row then
                        row = CreateFrame("Button", nil, button.chainPanel)
                        row:SetHeight(lineHeight)
                        row:SetPoint("TOPLEFT", button.chainPanel, "TOPLEFT", 8, -5 - ((chainIndex - 1) * lineHeight))
                        row:SetPoint("RIGHT", button.chainPanel, "RIGHT", -6, 0)
                        row:RegisterForClicks("LeftButtonUp")

                        row.text = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
                        row.text:SetPoint("LEFT", 0, 0)
                        row.text:SetJustifyH("LEFT")
                        if row.text.SetWordWrap then row.text:SetWordWrap(false) end

                        -- This is a SEPARATE completion tick for the prerequisite.
                        -- It is anchored directly after the prerequisite title.
                        -- The main quest's original completion tick is untouched.
                        row.statusIcon = row:CreateTexture(nil, "OVERLAY")
                        row.statusIcon:SetSize(12, 12)
                        row.statusIcon:Hide()

                        -- "YOU HAVE IT" when this step is in the quest log.
                        row.haveIt = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
                        row.haveIt:SetPoint("RIGHT", row, "RIGHT", -2, 0)
                        row.haveIt:SetJustifyH("RIGHT")
                        row.haveIt:SetTextColor(1.00, 0.82, 0.10)
                        row.haveIt:SetShadowColor(0, 0, 0, 0.72)
                        row.haveIt:SetShadowOffset(1, -1)
                        row.haveIt:Hide()

                        row.selected = row:CreateTexture(nil, "BACKGROUND")
                        row.selected:SetAllPoints()
                        row.selected:SetTexture("Interface\\Buttons\\WHITE8X8")
                        row.selected:SetColorTexture(1, 0.82, 0.25, 0.18)
                        row.selected:Hide()

                        row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
                        row.highlight:SetAllPoints()
                        row.highlight:SetTexture("Interface\\Buttons\\WHITE8X8")
                        row.highlight:SetColorTexture(1, 0.82, 0.25, 0.10)

                        row:SetScript("OnClick", function(self)
                            if not self.step then return end
                            do
                                local d = self.step.id and QUEST_PREREQ_DETAILS[self.step.id]
                                if FDJ.TryLinkQuest and FDJ.TryLinkQuest(self.step.id, self.step.name, d and d.level) then return end
                            end
                            selectedPrereqStep = self.step
                            selectedPrereqParentQuestName = self.parentQuestName
                            selectedPrereqParentQuestID = self.parentQuestID
                            if self.step.id then RequestQuestRewardData(self.step.id) end
                            RefreshQuestList()
                            RefreshQuestDetail()
                        end)
                        -- choiceline (2.0.40): a name cut short ("...") in full
                        row:SetScript("OnEnter", function(self)
                            if not self.truncated or not self.fullText then return end
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetText(self.fullText, 1, 0.82, 0.25)
                            GameTooltip:Show()
                        end)
                        row:SetScript("OnLeave", function(self)
                            if self.truncated then GameTooltip:Hide() end
                        end)

                        button.chainRows[chainIndex] = row
                    end

                    row.step = step
                    row.parentQuestName = quest.name
                    row.parentQuestID = quest.id
                    -- pickone (2.0.42): the "Pick one of the following
                    -- quests:" line before a choice's quests, and its quests
                    -- drawn each for itself (only the one done gets the tick).
                    local choiceFirst, choiceLast = FDJ.ChainInChoice(chain, chainIndex)
                    if choiceFirst == chainIndex then
                        FDJ.DrawChoiceHeader(button, quest, chain, chainIndex, choiceLast, lineHeight)
                    end
                    FDJ.doneByOff = choiceFirst ~= nil

                    if row.selected then
                        local isSelected = selectedPrereqStep
                            and selectedPrereqStep.id
                            and step.id
                            and selectedPrereqStep.id == step.id
                        row.selected:SetShown(isSelected == true)
                    end

                    if row.statusIcon then
                        row.statusIcon:Hide()
                        row.statusIcon:SetTexture(nil)
                    end

                    local prefix = FDJ.ChainStepLabel(chain, chainIndex) -- choicestep (2.0.37)
                    if step.itemStep and FDJ.ItemStepDone(chain, chainIndex, quest.id) then
                        -- itemsteps: its card is in the bags (or a later one is)
                        if row.statusIcon then
                            row.statusIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
                            row.statusIcon:SetTexCoord(0, 1, 0, 1)
                            row.statusIcon:Show()
                        end
                        row.text:SetTextColor(0.45, 0.95, 0.50)
                    elseif step.id and IsQuestFinished(step.id) then
                        if row.statusIcon then
                            -- Still to hand in: the quest ? instead of the tick.
                            row.statusIcon:SetTexture(FDJ.QuestTurnedIn(step.id) and "Interface\\RaidFrame\\ReadyCheck-Ready"
                                or "Interface\\GossipFrame\\ActiveQuestIcon")
                            row.statusIcon:SetTexCoord(0, 1, 0, 1)
                            row.statusIcon:Show()
                        end
                        if FDJ.QuestTurnedIn(step.id) then
                            row.text:SetTextColor(0.45, 0.95, 0.50)
                        else
                            row.text:SetTextColor(1.00, 0.83, 0.28)
                        end
                    elseif step.id and IsQuestInLog(step.id) then
                        row.text:SetTextColor(1.00, 0.83, 0.28)
                    else
                        row.text:SetTextColor(0.78, 0.74, 0.66)
                    end
                    -- acceptOnly (Rig Wars): a step that only has to be in the
                    -- quest log, not handed in, says so in the list.
                    row.fullText = prefix .. QuestField(step.id, "name", step.name) .. (step.acceptOnly and (" " .. L("STEP_ACCEPT_ONLY")) or "")
                    row.text:SetText(row.fullText)
                    if row.haveIt then
                        row.text:SetWidth(0)
                        if step.id and not IsQuestFinished(step.id) and IsQuestInLog(step.id) then
                            -- Same label as the quest rows; shrink long translations a little.
                            row.haveIt:SetFontObject("ForeverDJ_GameFontNormalSmall")
                            row.haveIt:SetScale(1)
                            row.haveIt:SetText(L("YOU_HAVE_IT"))
                            local labelWidth = row.haveIt:GetStringWidth() or 0
                            if labelWidth > 88 then
                                row.haveIt:SetScale(math.max(0.80, 88 / labelWidth))
                                labelWidth = 88
                            end
                            row.haveIt:Show()
                            -- A long step title is kept clear of the label by
                            -- FDJ.LayoutChainRows (choiceline, 2.0.40).
                        else
                            row.haveIt:Hide()
                        end
                    end

                    -- Put the prerequisite tick literally beside its title.
                    -- Example: "1. Underground Map  ✓"
                    -- Because row.text now has only a LEFT anchor, its RIGHT edge
                    -- tracks the actual rendered text instead of the full row width.
                    if row.statusIcon and row.statusIcon:IsShown() then
                        row.statusIcon:ClearAllPoints()
                        row.statusIcon:SetPoint("LEFT", row.text, "RIGHT", 5, 0)
                    end
                    -- No In Dungeon icon in the chain list: players read it as
                    -- "starts in the dungeon". It shows on the step's page,
                    -- after Objective, only.
                    FDJ.SetStepRowDungeonIcon(row, false)
                    -- A step ready to hand in: our round ? in place of the
                    -- plain one, clickable to show where it is handed in.
                    if FDJ.CreateTurnInButton and FDJ.SetTurnInButton then
                        local ready = step.id and not step.itemStep and IsQuestFinished(step.id)
                            and not FDJ.QuestTurnedIn(step.id)
                        if ready then
                            if not row.turnInMark then
                                row.turnInMark = FDJ.CreateTurnInButton(row, 16)
                                row.turnInMark:SetFrameLevel(row:GetFrameLevel() + 3)
                            end
                            local d = QUEST_PREREQ_DETAILS[step.id] or {}
                            FDJ.SetTurnInButton(row.turnInMark, { id = step.id, turnin = d.turnin, turninMap = d.turninMap },
                                QuestField(step.id, "name", step.name))
                            if FDJ.ResizeTurnInButton then FDJ.ResizeTurnInButton(row.turnInMark, FDJ.StepMarkSize()) end
                            row.turnInMark:ClearAllPoints()
                            row.turnInMark:SetPoint("LEFT", row.text, "RIGHT", 3, 0)
                            if row.statusIcon then row.statusIcon:Hide() end
                        elseif row.turnInMark then
                            FDJ.SetTurnInButton(row.turnInMark, nil)
                        end
                    end

                    FDJ.doneByOff = nil
                    row:Show()
                end

                -- choiceline (2.0.40) / pickone (2.0.42): lines, cut to fit
                FDJ.LayoutChainRows(button, chain, lineHeight)

                for chainIndex = #chain + 1, #button.chainRows do
                    button.chainRows[chainIndex]:Hide()
                end

                rowHeight = baseRowHeight + panelHeight + 4
            else
                button.layoutChain = nil -- choiceline (2.0.40)
                for _, h in pairs(button.choiceHeaders or {}) do h:Hide() end -- pickone (2.0.42)
                if button.chainPanel then button.chainPanel:Hide() end
                if button.chainRows then
                    for _, row in ipairs(button.chainRows) do row:Hide() end
                end
            end

            button:SetHeight(rowHeight)
            contentHeight = contentHeight + rowHeight + 3
            if displayIndex == mainCount and repeatLine and repeatCount > 0 then
                contentHeight = contentHeight + 27 -- the divider line below
            end

            local both = quest.faction == "Both" or quest.faction == "Neutral"
            local iconTopY = (inLog and not complete) and -27 or -8
            local _, _, _, _, questClassToken = GetQuestClassRestriction(quest)
            button.fdjClass2 = select(6, GetQuestClassRestriction(quest)) -- classicons (2.1.0)
            button.fdjClass2 = type(button.fdjClass2) == "table" and button.fdjClass2[1] or nil
            button.allianceIcon:SetShown(both or quest.faction == "Alliance")
            button.hordeIcon:SetShown(both or quest.faction == "Horde")

            if button.classIcon then
                if questClassToken then
                    SetQuestRestrictionIcon(button.classIcon, questClassToken)
                    button.classIcon:Show()
                else
                    button.classIcon:Hide()
                end
            end

            if both then
                button.allianceIcon:ClearAllPoints()
                button.hordeIcon:ClearAllPoints()
                if button.classIcon and button.classIcon:IsShown() then
                    button.allianceIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -72, iconTopY)
                    button.hordeIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -50, iconTopY)
                    button.classIcon:ClearAllPoints()
                    button.classIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -28, iconTopY)
                else
                    button.allianceIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -50, iconTopY)
                    button.hordeIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -28, iconTopY)
                end
            elseif quest.faction == "Alliance" then
                button.allianceIcon:ClearAllPoints()
                if button.classIcon and button.classIcon:IsShown() then
                    button.allianceIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -50, iconTopY)
                    button.classIcon:ClearAllPoints()
                    button.classIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -28, iconTopY)
                else
                    button.allianceIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -31, iconTopY)
                end
            elseif quest.faction == "Horde" then
                button.hordeIcon:ClearAllPoints()
                if button.classIcon and button.classIcon:IsShown() then
                    button.hordeIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -50, iconTopY)
                    button.classIcon:ClearAllPoints()
                    button.classIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -28, iconTopY)
                else
                    button.hordeIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -31, iconTopY)
                end
            else
                if button.classIcon and button.classIcon:IsShown() then
                    button.classIcon:ClearAllPoints()
                    button.classIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -31, iconTopY)
                end
            end
            if rpgHidden then -- rpgpartial: nothing to tell it by
                button.allianceIcon:Hide()
                button.hordeIcon:Hide()
                if button.classIcon then button.classIcon:Hide() end
            end
            -- repeaticon (2.0.44): a repeatable quest's own icon, Blizzard's blue ?
            if button.icon then FDJ.SetQuestIconTexture(button.icon, FDJ.IsRepeatableQuest(quest)) end
            if button.icon and button.icon.SetDesaturated then button.icon:SetDesaturated(rpgHidden) end
            -- bigready: ready to hand in, the big ? alone (turninclean).
            -- Handed in: the tick and faction icons.
            if ready and button.turnIn then
                button.allianceIcon:Hide()
                button.hordeIcon:Hide()
                if button.classIcon then button.classIcon:Hide() end -- turninclean
            end
            -- questrowtrial (2.0.8): no faction crests (the list is the
            -- character's faction, its crest at the top); a quest not taken
            -- yet has the round ! in their place, as big as the turn-in ?:
            -- a click shows how to pick it up. The class icon goes left of it.
            if FDJ.QuestRowTrial(selectedDungeon) then
                button.allianceIcon:Hide()
                button.hordeIcon:Hide()
                local showPick = (not rpgHidden) and (not complete) and (not inLog) and not FDJ.QuestTurnedIn(quest.id)
                if showPick and not button.pickUp and FDJ.CreatePickUpButton then
                    button.pickUp = FDJ.CreatePickUpButton(button, 44)
                    button.pickUp:SetPoint("CENTER", button, "TOPRIGHT", -26, -24)
                    button.pickUp:SetFrameLevel(button:GetFrameLevel() + 7)
                end
                if button.pickUp then
                    FDJ.SetPickUpButton(button.pickUp, showPick and quest or nil, QuestField(quest.id, "name", quest.name), selectedDungeon)
                end
                local pick = showPick and button.pickUp
                if pick and button.classIcon and button.classIcon:IsShown() then
                    button.classIcon:ClearAllPoints()
                    -- classicons (2.1.0, M 19 Nov 2026): two class icons sit a
                    -- little higher, clear of the In Dungeon icon below them.
                    button.classIcon:SetPoint("RIGHT", pick, "LEFT", 0, button.fdjClass2 and 9 or 0)
                end
                if button.pickUpLabel and button.pickUpLabel:IsShown() then
                    button.pickUpLabel:ClearAllPoints()
                    local by = (pick and button.classIcon and button.classIcon:IsShown()) and button.classIcon or pick
                    if by == button.classIcon and button.fdjClass2 then -- classicons: left of the second class icon
                        if not button.classIcon2 then
                            button.classIcon2 = button:CreateTexture(nil, "OVERLAY")
                            button.classIcon2:SetSize(20, 20)
                        end
                        by = button.classIcon2
                    end
                    if by then
                        -- pickclear (2.0.8): on the title's first line, above
                        -- the chain and In Dungeon icons of the line below.
                        button.pickUpLabel:SetPoint("RIGHT", by, "LEFT", by == pick and 3 or -3, 8)
                    else
                        button.pickUpLabel:Hide()
                    end
                end
            elseif button.pickUp then
                FDJ.SetPickUpButton(button.pickUp, nil)
            end

            if selectedQuest == questIndex then
                button:SetBackdropColor(unpack(theme.rowSelected))
                button:SetBackdropBorderColor(unpack(theme.border))
                button.name:SetTextColor(unpack(theme.title))
            else
                button:SetBackdropColor(unpack(theme.row))
                button:SetBackdropBorderColor(unpack(theme.border))
                button.name:SetTextColor(unpack(theme.muted))
            end

            button.meta:SetTextColor(unpack(theme.muted))
            button.completeGlow:SetShown(complete and not ready)
            FDJ.SetChainReadyGlow(button, (not rpgHidden) and (not complete) and (not inLog) and FDJ.QuestChainUnlocked(quest), quest.id) -- chainready (sunonce: keyed by quest)
            button.check:SetShown(complete and not (ready and button.turnIn))
            if button.turnIn then
                FDJ.SetTurnInButton(button.turnIn, ready and quest or nil, QuestField(quest.id, "name", quest.name))
            end
            if button.UpdateHaveItLabel then button:UpdateHaveItLabel() end
            button.haveIt:SetShown(inLog and not complete)
            -- classicons (2.1.0): a quest for two classes shows both icons,
            -- the second left of the first; the faction crests move over.
            if button.fdjClass2 and button.classIcon and button.classIcon:IsShown() then
                if not button.classIcon2 then
                    button.classIcon2 = button:CreateTexture(nil, "OVERLAY")
                    button.classIcon2:SetSize(20, 20)
                end
                SetQuestRestrictionIcon(button.classIcon2, button.fdjClass2)
                button.classIcon2:ClearAllPoints()
                button.classIcon2:SetPoint("RIGHT", button.classIcon, "LEFT", -2, 0)
                button.classIcon2:Show()
                for _, crest in ipairs({ button.allianceIcon, button.hordeIcon }) do
                    if crest:IsShown() and crest:GetNumPoints() > 0 then
                        local point, rel, relPoint, x, y = crest:GetPoint(1)
                        crest:ClearAllPoints()
                        crest:SetPoint(point, rel, relPoint, (x or 0) - 22, y or 0)
                    end
                end
            elseif button.classIcon2 then
                button.classIcon2:Hide()
            end

            if complete and not ready then
                button.name:SetTextColor(0.30, 1.00, 0.36)
            end

            button:Show()
        elseif button then
            button:Hide()
        end
    end

    if repeatLine then
        if repeatCount > 0 then
            local open = FDJ.questRepeatExpanded and true or false
            repeatLine.text:SetText(L(open and "REPEAT_HIDE" or "REPEAT_SHOW", repeatCount))
            repeatLine.icon:SetTexture(open and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
            repeatLine:ClearAllPoints()
            if mainCount > 0 and questButtons[mainCount] then
                repeatLine:SetPoint("TOPLEFT", questButtons[mainCount], "BOTTOMLEFT", 0, -3)
            else
                repeatLine:SetPoint("TOPLEFT", frame.questContent, "TOPLEFT", 0, 0)
                if mainCount == 0 then contentHeight = contentHeight + 27 end
            end
            repeatLine:SetWidth((questButtons[1] and questButtons[1]:GetWidth()) or 296)
            repeatLine:Show()
        else
            repeatLine:Hide()
        end
    end

    contentHeight = math.max(1, contentHeight - 3)
    frame.questContent:SetHeight(contentHeight)
    UpdateScrollBarVisibility(frame.questListScroll, contentHeight)
    if FDJ.UpdateQuestTrackButton then FDJ.UpdateQuestTrackButton(selectedDungeon) end -- questtracker
    FDJ.MarkLostQuestRows(questButtons, quests) -- lostquest
end

local function GetQuestLogIndexForQuestIDSafe(questID)
    if type(questID) ~= "number" then return nil end
    if type(GetQuestLogIndexByID) == "function" then
        local ok, index = pcall(GetQuestLogIndexByID, questID)
        if ok and type(index) == "number" and index > 0 then return index end
    end
    if C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID) == "function" then
        local ok, index = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
        if ok and type(index) == "number" and index > 0 then return index end
    end
    return nil
end

local function GetLoadedQuestTitle(questID, fallback)
    local localizedFallback = QuestField(questID, "name", fallback or "Required quest")
    local canUseClient = not FDJ.CanUseClientLocalizedText or FDJ.CanUseClientLocalizedText()
    if canUseClient and type(questID) == "number" and C_QuestLog then
        local getter = C_QuestLog.GetTitleForQuestID or C_QuestLog.GetQuestInfo
        if type(getter) == "function" then
            local ok, title = pcall(getter, questID)
            if ok and not IsSecret(title) and type(title) == "string" and title ~= "" then
                return title
            end
        end
    end
    return localizedFallback
end

-- Returns the rewards to show first, whether they are a choice, and the fixed
-- rewards that come on top of a choice ("You will also receive").
local function GetPrerequisiteRewardItems(questID)
    local fixed, choices = {}, {}

    local function addRewards(countFunc, infoFunc, list)
        if type(countFunc) ~= "function" or type(infoFunc) ~= "function" then return end
        local okCount, count = pcall(countFunc, questID)
        if not okCount or type(count) ~= "number" then return end

        for i = 1, count do
            local ok, name, texture, numItems, quality, isUsable, itemID = pcall(infoFunc, i, questID)
            if ok and type(itemID) == "number" and itemID > 0 then
                list[#list + 1] = { itemID, name or ("Item " .. itemID), quality or 1 }
            end
        end
    end

    addRewards(GetNumQuestLogRewards, GetQuestLogRewardInfo, fixed)
    addRewards(GetNumQuestLogChoices, GetQuestLogChoiceInfo, choices)

    if #fixed == 0 and #choices == 0 then
        local fallback = PREREQ_REWARD_ITEMS_FALLBACK[questID]
        if fallback and fallback.items then
            local list = fallback.choice and choices or fixed
            for _, item in ipairs(fallback.items) do list[#list + 1] = item end
            for _, item in ipairs(fallback.also or {}) do fixed[#fixed + 1] = item end
        end
    end

    if #choices > 0 then return choices, true, fixed end
    return fixed, false, {}
end

local function GetPrerequisiteRewardXP(questID)
    return GetLiveQuestXP({ id = questID })
end

local function GetPrerequisiteRewardMoney(questID)
    local fallback = PREREQ_REWARD_MONEY_FALLBACK[questID]
    if type(fallback) == "number" and fallback > 0 then
        return fallback
    end
    if type(GetQuestLogRewardMoney) ~= "function" then return 0 end
    local ok, value = pcall(GetQuestLogRewardMoney, questID)
    if ok and not IsSecret(value) and type(value) == "number" and value > 0 then
        return value
    end
    return 0
end

local function SelectPrerequisiteStepByOffset(offset)
    local chain = selectedPrereqParentQuestID and QUEST_PREREQ_CHAINS[selectedPrereqParentQuestID]
    if not chain or not selectedPrereqStep then return end
    local currentIndex
    for i, chainStep in ipairs(chain) do
        if chainStep == selectedPrereqStep or (chainStep.id and selectedPrereqStep.id and chainStep.id == selectedPrereqStep.id) then
            currentIndex = i
            break
        end
    end
    if not currentIndex then return end
    local target = chain[currentIndex + offset]
    if not target then return end
    selectedPrereqStep = target
    if target.id then RequestQuestRewardData(target.id) end
    RefreshQuestList()
    RefreshQuestDetail()
end

local function UpdatePrerequisiteNavButtons()
    if not frame or not frame.questPrevStepButton or not frame.questNextStepButton then return end
    local chain = selectedPrereqParentQuestID and QUEST_PREREQ_CHAINS[selectedPrereqParentQuestID]
    if not chain or not selectedPrereqStep then
        frame.questPrevStepButton:Hide()
        frame.questNextStepButton:Hide()
        return
    end
    local currentIndex
    for i, chainStep in ipairs(chain) do
        if chainStep == selectedPrereqStep or (chainStep.id and selectedPrereqStep.id and chainStep.id == selectedPrereqStep.id) then
            currentIndex = i
            break
        end
    end
    frame.questPrevStepButton:SetShown(currentIndex and currentIndex > 1 or false)
    frame.questNextStepButton:SetShown(currentIndex and currentIndex < #chain or false)
end

-- Keep the reader's scroll position when the SAME quest page is redrawn.
-- The page is rebuilt whenever item or quest data arrives or the quest log
-- changes; resetting to the top on every rebuild made the view jump back up
-- while the player was reading the rewards. Only a different page starts at
-- the top. Stored on FDJ to stay under Lua's 200-locals limit for this file.
FDJ.ApplyQuestDetailScroll = function(pageKey, contentHeight)
    local scroll = frame and frame.questDetailScroll
    if not scroll then return end
    FDJ._questDetailScrollByPage = FDJ._questDetailScrollByPage or {}
    if FDJ._questDetailPageKey ~= pageKey then
        FDJ._questDetailPageKey = pageKey
        FDJ._questDetailScrollByPage[pageKey] = 0
    end
    local desired = FDJ._questDetailScrollByPage[pageKey] or 0
    local maxScroll = math.max(0, (contentHeight or 0) - (scroll:GetHeight() or 0))
    local target = math.max(0, math.min(desired, maxScroll))
    FDJ._restoringQuestDetailScroll = true
    scroll:SetVerticalScroll(target)
    local scrollBar = GetScrollBar(scroll)
    if scrollBar then
        if scrollBar.SetMinMaxValues then scrollBar:SetMinMaxValues(0, maxScroll) end
        if scrollBar.SetValue then scrollBar:SetValue(target) end
    end
    FDJ._restoringQuestDetailScroll = nil
end

-- showlocation (2.1.3, M 21 Nov 2026, Reclaimed Treasures' page): a quest
-- with a minimap picture (noteImage), while the quest is in the log.
-- itemhint (2.1.3, M 21 Nov 2026, Solution to Doom's page: "a little arrow in
-- our pop-up graphic style that points to the left, directly to the tablet
-- item. And it says, click the item to see location. And we get rid of the
-- show location"): no Show Location button any more; a note in the style of
-- the full-view hint (Systems/ForeverFilter.lua: black box, grey border, red
-- arrow), standing still on the page right of the item card, its arrow
-- pointing at the card. A click on that card goes down to the picture, which
-- pulses (FDJ.ShowNoteImageLocation). FDJ.PlaceShowLocation(false): the
-- pages without it hide the note.
-- hintalways (2.1.3, M 21 Nov 2026, Reclaimed Treasures' page, the quest
-- handed in: "of course ... the arrow needs to be for reclaimed treasures as
-- well"): on every quest with a picture, in the log or not.
FDJ.PlaceShowLocation = function(show, cursorY)
    if not show then FDJ.PlaceItemLocationHint(nil, false) end
    return cursorY or 0
end
-- The entrance pin's tooltip (Show Location) keeps the translations the
-- button had brought.
do
    local strings = {
        frFR = "Voir le lieu", esES = "Ver ubicación", esMX = "Ver ubicación",
        itIT = "Mostra posizione", ptBR = "Ver local", ruRU = "Показать место",
        koKR = "위치 보기", zhCN = "显示位置", zhTW = "顯示位置",
    }
    for locale, text in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t and t.SHOW_LOCATION == nil then t.SHOW_LOCATION = text end
    end
end

FDJ.PlaceItemLocationHint = function(img, show)
    local hint = frame and frame.questItemLocationHint
    if hint then hint:Hide() end
    if not frame then return end
    if frame.questRequiredItemButton then frame.questRequiredItemButton.fdjNoteImageClick = nil end
    for _, card in ipairs(frame.questStepItemButtons or {}) do card.fdjNoteImageClick = nil end
    if not show or type(img) ~= "table" or not frame.questDetailContent then return end
    -- The card of the item the picture marks, else the first item card.
    local want = type(img.marks) == "table" and type(img.marks[1]) == "table" and tonumber(img.marks[1].item) or nil
    local cards = {}
    if frame.questRequiredItemButton and frame.questRequiredItemButton:IsShown() and frame.questRequiredItemButton.item then
        cards[#cards + 1] = frame.questRequiredItemButton
    end
    for _, card in ipairs(frame.questStepItemButtons or {}) do
        if card:IsShown() and card.item then cards[#cards + 1] = card end
    end
    local target = cards[1]
    for _, card in ipairs(cards) do
        if want and tonumber(card.item[1]) == want then target = card break end
    end
    if not target then return end
    target.fdjNoteImageClick = true
    if not hint then
        local strings = {
            enUS = "Click the item to see location",
            deDE = "Klickt auf den Gegenstand, um den Ort zu sehen",
            frFR = "Cliquez sur l'objet pour voir l'emplacement",
            esES = "Haz clic en el objeto para ver la ubicación",
            itIT = "Clicca sull'oggetto per vedere la posizione",
            ptBR = "Clique no item para ver o local",
            ruRU = "Нажмите на предмет, чтобы увидеть место",
            koKR = "아이템을 클릭하면 위치를 볼 수 있습니다",
            zhCN = "点击物品查看位置",
            zhTW = "點擊物品查看位置",
        }
        strings.esMX = strings.esES
        for locale, text in pairs(strings) do
            local t = FDJ.Locales and FDJ.Locales[locale]
            if t and t.ITEM_LOCATION_HINT == nil then t.ITEM_LOCATION_HINT = text end
        end
        hint = CreateFrame("Frame", nil, frame.questDetailContent, "BackdropTemplate")
        hint:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        hint:SetBackdropColor(0, 0, 0, 0.92)
        hint:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        hint.arrow = hint:CreateTexture(nil, "OVERLAY")
        hint.arrow:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\QuestNextArrow")
        hint.arrow:SetTexCoord(1, 0, 0, 1) -- the hint's own arrow, turned to point left
        hint.arrow:SetVertexColor(1, 0.12, 0.08)
        hint.arrow:SetSize(20, 20)
        hint.arrow:SetPoint("LEFT", 6, 0)
        hint.text = hint:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
        if FDJ.OwnFonts then FDJ.OwnFonts(hint) end
        hint.text:SetPoint("LEFT", hint.arrow, "RIGHT", 5, 0)
        hint.text:SetJustifyH("LEFT")
        hint.text:SetTextColor(1, 1, 1)
        hint.text:SetShadowColor(0, 0, 0, 1)
        hint.text:SetShadowOffset(1, -1)
        frame.questItemLocationHint = hint
    end
    hint:SetFrameLevel((target:GetFrameLevel() or 1) + 2)
    -- Right of the card, as wide as the page leaves it (two lines at most).
    local full = (frame.questDetailScroll and frame.questDetailScroll:GetWidth() or 350) - 4
    local cardRight = select(4, target:GetPoint(1)) or 0
    local room = math.max(120, full - (tonumber(cardRight) or 0) - (target:GetWidth() or 160) - 8)
    hint.text:SetWidth(0)
    hint.text:SetText(L("ITEM_LOCATION_HINT"))
    local textWidth = math.min(hint.text:GetStringWidth() or 150, room - 39)
    hint.text:SetWidth(math.max(60, textWidth + 2))
    hint:SetSize(math.floor(textWidth + 41), math.max(28, math.floor((hint.text:GetStringHeight() or 14) + 14)))
    hint:ClearAllPoints()
    hint:SetPoint("LEFT", target, "RIGHT", 6, 0)
    hint:Show()
end

FDJ.ShowNoteImageLocation = function()
    local box = frame and frame.questNoteImage
    local scroll = frame and frame.questDetailScroll
    if not (box and box:IsShown() and scroll) then return end
    local maxScroll = math.max(0, (frame.questDetailContent:GetHeight() or 0) - (scroll:GetHeight() or 0))
    local target = math.max(0, math.min((box.fdjY or 0) - 10, maxScroll))
    scroll:SetVerticalScroll(target)
    local scrollBar = GetScrollBar(scroll)
    if type(scrollBar) == "table" and scrollBar.SetValue then scrollBar:SetValue(target) end
    if FDJ._questDetailScrollByPage and FDJ._questDetailPageKey then
        FDJ._questDetailScrollByPage[FDJ._questDetailPageKey] = target
    end
    box.fdjPulse = 0
    box:SetScript("OnUpdate", function(self, elapsed)
        self.fdjPulse = (self.fdjPulse or 0) + (elapsed or 0)
        if self.fdjPulse >= 1.6 then
            self:SetAlpha(1)
            self:SetScript("OnUpdate", nil)
            return
        end
        self:SetAlpha(0.45 + 0.55 * math.abs(math.cos(self.fdjPulse * math.pi * 1.25)))
    end)
end

-- Item rows on a chain-step page: the items the step asks for and the item the
-- quest giver hands over. Each row is a normal item button, so hovering shows the
-- item tooltip followed by where the item comes from.
-- Shift-click quest linking. Returns true when something was put in the chat box.
FDJ.TryLinkQuest = function(questID, name, level)
    if type(questID) ~= "number" or questID <= 0 or not IsModifiedClick or not IsModifiedClick("CHATLINK") then return false end
    if not ChatEdit_InsertLink then return false end
    if type(ChatEdit_GetActiveWindow) == "function" and not ChatEdit_GetActiveWindow() then return false end
    local title = name
    if C_QuestLog and type(C_QuestLog.GetQuestInfo) == "function" then
        local ok, live = pcall(C_QuestLog.GetQuestInfo, questID)
        if ok and type(live) == "string" and live ~= "" then title = live end
    end
    title = title or ("Quest " .. tostring(questID))
    local link
    if type(GetQuestLink) == "function" then
        local ok, live = pcall(GetQuestLink, questID)
        if ok and type(live) == "string" and live ~= "" then link = live end
    end
    if not link then
        local questLevel = tonumber(level) or -1
        link = "|cffffff00|Hquest:" .. tostring(questID) .. ":" .. tostring(questLevel) .. "|h[" .. title .. "]|h|r"
    end
    if ChatEdit_InsertLink(link) then return true end
    -- The client refused the hyperlink: fall back to plain text.
    return ChatEdit_InsertLink("[" .. title .. "]") and true or false
end

-- lostquest: a quest that can no longer be done (lostIf = { questIDs }):
-- one of those was handed in while this one is neither done nor in the log (In Search of Thaelrid once Blackfathom
-- Villainy is accepted). It no longer counts towards the dungeon's
-- quests; its row is greyed out with "Unavailable, read quest warning".
do
    local strings = {
        enUS = "Unavailable, read quest warning", deDE = "Nicht verfügbar, Quest-Warnung lesen",
        frFR = "Indisponible, lisez l'avertissement de la quête", esES = "No disponible, lee el aviso de la misión",
        esMX = "No disponible, lee el aviso de la misión", itIT = "Non disponibile, leggi l'avviso della missione",
        ptBR = "Indisponível, leia o aviso da missão", ruRU = "Недоступно, прочтите предупреждение задания",
        koKR = "이용 불가, 퀘스트 경고를 읽어 보세요", zhCN = "不可用，请阅读任务警告", zhTW = "無法取得，請閱讀任務警告",
    }
    for locale, text in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t and t.QUEST_LOST_TIP == nil then t.QUEST_LOST_TIP = text end
    end
    -- notavailable (2.0.4): a quest that is not in the game for now
    -- (unavailable = true, Attunement to the Core) is shown the same way,
    -- greyed out and not counted, with its own tooltip.
    local notNow = {
        enUS = "Not available as of now", deDE = "Derzeit nicht verfügbar",
        frFR = "Indisponible pour le moment", esES = "No disponible por ahora",
        esMX = "No disponible por ahora", itIT = "Non disponibile al momento",
        ptBR = "Indisponível no momento", ruRU = "Сейчас недоступно",
        koKR = "현재 이용할 수 없음", zhCN = "目前不可用", zhTW = "目前無法取得",
    }
    for locale, text in pairs(notNow) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t and t.QUEST_NOT_AVAILABLE_TIP == nil then t.QUEST_NOT_AVAILABLE_TIP = text end
    end
    -- raceunavailable (2.0.9): %s is the race, as the game names it.
    local notRace = {
        enUS = "Unavailable to %s", deDE = "Für deine Rasse nicht verfügbar (%s)",
        frFR = "Indisponible pour votre race (%s)", esES = "No disponible para tu raza (%s)",
        esMX = "No disponible para tu raza (%s)", itIT = "Non disponibile per la tua razza (%s)",
        ptBR = "Indisponível para a sua raça (%s)", ruRU = "Недоступно для вашей расы (%s)",
        koKR = "%s 종족은 이용할 수 없음", zhCN = "%s无法接取", zhTW = "%s無法接取",
    }
    for locale, text in pairs(notRace) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t and t.QUEST_RACE_UNAVAILABLE_TIP == nil then t.QUEST_RACE_UNAVAILABLE_TIP = text end
    end
    -- ststatueart (2.0.6): the serpent statue picture for the map markers:
    -- 128x256, the statue in the top 198 rows, head on the left (its middle
    -- a third of the way across).
    FDJ.ST_STATUE_ART = FDJ.ST_STATUE_ART or {
        texture = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\SerpentStatue",
        bottom = 198 / 256,
        aspect = 128 / 198,
        headX = 0.33,
    }
    -- ststatuedir (2.0.6): the statue's place round the pit, after its title.
    for locale, d in pairs({
        enUS = { "South", "North", "Southwest", "Southeast", "Northwest", "Northeast" },
        deDE = { "Süden", "Norden", "Südwesten", "Südosten", "Nordwesten", "Nordosten" },
        frFR = { "Sud", "Nord", "Sud-ouest", "Sud-est", "Nord-ouest", "Nord-est" },
        esES = { "Sur", "Norte", "Suroeste", "Sureste", "Noroeste", "Noreste" },
        esMX = { "Sur", "Norte", "Suroeste", "Sureste", "Noroeste", "Noreste" },
        itIT = { "Sud", "Nord", "Sud-ovest", "Sud-est", "Nord-ovest", "Nord-est" },
        ptBR = { "Sul", "Norte", "Sudoeste", "Sudeste", "Noroeste", "Nordeste" },
        ruRU = { "Юг", "Север", "Юго-запад", "Юго-восток", "Северо-запад", "Северо-восток" },
        koKR = { "남쪽", "북쪽", "남서쪽", "남동쪽", "북서쪽", "북동쪽" },
        zhCN = { "南", "北", "西南", "东南", "西北", "东北" },
        zhTW = { "南", "北", "西南", "東南", "西北", "東北" },
    }) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            for i, key in ipairs({ "ST_DIR_S", "ST_DIR_N", "ST_DIR_SW", "ST_DIR_SE", "ST_DIR_NW", "ST_DIR_NE" }) do
                if t[key] == nil then t[key] = d[i] end
            end
        end
    end
    -- ststatues (2.0.6): the Sunken Temple's statue markers on the map.
    for locale, pair in pairs({
        enUS = { "Statue %d of 6", "Use the six statues in this order, 1 to 6: %s then appears in the pit below." },
        deDE = { "Statue %d von 6", "Benutze die sechs Statuen in dieser Reihenfolge, 1 bis 6: Dann erscheint %s in der Grube darunter." },
        frFR = { "Statue %d sur 6", "Utilisez les six statues dans cet ordre, de 1 à 6 : %s apparaît alors dans la fosse en contrebas." },
        esES = { "Estatua %d de 6", "Usa las seis estatuas en este orden, del 1 al 6: %s aparecerá en el foso de abajo." },
        esMX = { "Estatua %d de 6", "Usa las seis estatuas en este orden, del 1 al 6: %s aparecerá en el foso de abajo." },
        itIT = { "Statua %d di 6", "Usa le sei statue in quest'ordine, da 1 a 6: %s apparirà nella fossa sottostante." },
        ptBR = { "Estátua %d de 6", "Use as seis estátuas nesta ordem, de 1 a 6: %s aparecerá no fosso abaixo." },
        ruRU = { "Статуя %d из 6", "Активируйте шесть статуй по порядку, от 1 до 6: тогда в яме внизу появится %s." },
        koKR = { "석상 %d/6", "여섯 석상을 1번부터 6번까지 순서대로 사용하세요. 그러면 아래 구덩이에 %s|1이;가; 나타납니다." },
        zhCN = { "雕像 %d/6", "按1到6的顺序使用六座雕像，随后%s会出现在下方的坑中。" },
        zhTW = { "雕像 %d/6", "按1到6的順序使用六座雕像，隨後%s會出現在下方的坑中。" },
    }) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            if t.ST_STATUE == nil then t.ST_STATUE = pair[1] end
            if t.ST_STATUE_TIP == nil then t.ST_STATUE_TIP = pair[2] end
        end
    end
    -- alltrash (2.0.9): an item every trash mob drops. alltrashtip (2.0.6):
    -- only in its tooltip now, "Drops from: ALL Trash".
    for locale, text in pairs({
        enUS = "ALL Trash", deDE = "ALLE Trashmobs", frFR = "TOUS les mobs",
        esES = "TODOS los mobs", esMX = "TODOS los mobs", itIT = "TUTTI i mob",
        ptBR = "TODOS os mobs", ruRU = "ВСЕ мобы", koKR = "모든 일반 몹",
        zhCN = "所有小怪", zhTW = "所有小怪",
    }) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t and t.ALL_TRASH == nil then t.ALL_TRASH = text end
    end
end
-- bossdone (2.0.8): a dungeon with no quest for this character gets the
-- home card's green tick once its last boss has been killed: a run in the
-- run log that was finished, or that has the last boss's kill. Remembered
-- per character (lastBossKilled), so the tick stays when that run leaves
-- the log. (No new file-level local: see below.)
FDJ.LastBossKilled = function(dungeonName)
    local char = ForeverDungeonJournalCharacterDB
    if type(char) ~= "table" or type(dungeonName) ~= "string" then return false end
    if type(char.lastBossKilled) == "table" and char.lastBossKilled[dungeonName] then return true end
    local runs = FDJ.RunLog and FDJ.RunLog.Runs and FDJ.RunLog.Runs()
    if type(runs) ~= "table" then return false end
    for _, run in ipairs(runs) do
        if type(run) == "table" and run.dungeon == dungeonName then
            local done = run.completed and true or false
            if not done then
                for _, k in ipairs(run.kills or {}) do
                    if type(k) == "table" and k.f then done = true break end
                end
            end
            if done then
                if type(char.lastBossKilled) ~= "table" then char.lastBossKilled = {} end
                char.lastBossKilled[dungeonName] = true
                return true
            end
        end
    end
    return false
end
-- raceunavailable (2.0.9): unavailableRaces = { Scourge = true } on a quest:
-- the character's race can't take it (Compendium of the Fallen, Undead).
-- Keys are the game's race file names (UnitRace's second value).
-- (No new file-level local: this file is at Lua's limit of 200.)
FDJ.IsQuestRaceUnavailable = function(quest)
    if type(quest) ~= "table" or type(quest.unavailableRaces) ~= "table" or not quest.id then return false end
    if type(UnitRace) ~= "function" then return false end
    local ok, _, race = pcall(UnitRace, "player")
    return ok and type(race) == "string" and quest.unavailableRaces[race] == true
end
-- Not in the game for now, or not for this character's race: greyed out,
-- not counted, kept off the quest tracker (unless already handed in).
FDJ.IsQuestUnavailable = function(quest)
    if type(quest) ~= "table" or not quest.id then return false end
    if not (quest.unavailable or FDJ.IsQuestRaceUnavailable(quest)) then return false end
    return not FDJ.QuestTurnedIn(quest.id)
end
FDJ.IsQuestLost = function(quest)
    if type(quest) == "table" and (quest.unavailable or quest.unavailableRaces) and quest.id then -- notavailable
        if FDJ.IsQuestUnavailable(quest) then return true end
        if quest.unavailable then return false end
    end
    if type(quest) ~= "table" or type(quest.lostIf) ~= "table" or not quest.id then return false end
    if FDJ.QuestTurnedIn(quest.id) or (FDJ.IsQuestInLog and FDJ.IsQuestInLog(quest.id)) then return false end
    -- Only once the other quest is handed in: while it is just in the log it
    -- can still be abandoned and this one done first.
    for _, other in ipairs(quest.lostIf) do
        if FDJ.QuestTurnedIn(other) then return true end
    end
    return false
end
FDJ.MarkLostQuestRows = function(buttons, quests)
    for _, button in ipairs(buttons or {}) do
        local quest = button:IsShown() and button.questIndex and quests[button.questIndex]
        local lost = quest and FDJ.IsQuestLost(quest) or false
        button.fdjLost = lost or nil
        button.fdjLostTip = (lost and quest.unavailable) and "QUEST_NOT_AVAILABLE_TIP" or "QUEST_LOST_TIP" -- notavailable
        -- raceunavailable (2.0.9): "Unavailable to Undead" (the race as the game names it)
        button.fdjLostText = nil
        if lost and not quest.unavailable and FDJ.IsQuestRaceUnavailable(quest) then
            local ok, raceName = pcall(UnitRace, "player")
            if ok and type(raceName) == "string" then
                button.fdjLostText = string.format(FDJ.L("QUEST_RACE_UNAVAILABLE_TIP"), raceName)
            end
        end
        button:SetAlpha(lost and 0.45 or 1)
        if not button.fdjLostHooked then
            button.fdjLostHooked = true
            button:HookScript("OnEnter", function(self)
                if not self.fdjLost then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                -- (SetText: text, r, g, b, alpha, wrap)
                GameTooltip:SetText(self.fdjLostText or FDJ.L(self.fdjLostTip or "QUEST_LOST_TIP"), 1, 0.35, 0.3, 1, true)
                GameTooltip:Show()
            end)
            button:HookScript("OnLeave", function(self)
                if self.fdjLost and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
            end)
        end
    end
end

FDJ.QuestTurnedIn = function(questID)
    if not questID then return false end
    if FDJ.DEV_FAKE_LOG[questID] then return false end -- devlog
    if FDJ.DEV_CHAIN_OPEN[questID] then return false end -- devchain
    if FDJ.DEV_CHAIN_DONE[questID] then return true end
    local pseudo = FDJ.PSEUDO_QUEST_DONE and FDJ.PSEUDO_QUEST_DONE[questID] -- malletchain
    if pseudo then
        local ok, done = pcall(pseudo)
        return ok and done == true
    end
    if FDJ.DoneByOther and FDJ.DoneByOther(questID) then return true end -- choicestep (2.0.37)
    if FDJ.DoneOnce and FDJ.DoneOnce(questID) then return true end -- repeatonce (2.1.0)
    if C_QuestLog and type(C_QuestLog.IsQuestFlaggedCompleted) == "function" then
        local ok, value = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
        return ok and value == true
    elseif type(IsQuestFlaggedCompleted) == "function" then
        local ok, value = pcall(IsQuestFlaggedCompleted, questID)
        return ok and value == true
    end
    return false
end

-- repeaticon (2.0.44): repeatable quests have Blizzard's blue ? (the game's
-- own mark for them) wherever the journal shows a quest's icon: the quest
-- list, map pins, the arrow, item sources, favourites. The gossip art, as
-- the journal's yellow ! is; Blizzard's atlas if that file is missing.
FDJ.REPEATABLE_QUEST_TEXTURE = "Interface\\GossipFrame\\DailyActiveQuestIcon"
function FDJ.IsRepeatableQuest(quest)
    if type(quest) == "table" then
        if quest.repeatable then return true end
        quest = quest.id
    end
    if type(quest) ~= "number" then return false end
    if not FDJ.repeatableQuestIDs then
        local set = {}
        for _, d in pairs(FDJ.DB or {}) do
            for _, q in ipairs((type(d) == "table" and d.quests) or {}) do
                if type(q) == "table" and q.repeatable and q.id then set[q.id] = true end
            end
        end
        FDJ.repeatableQuestIDs = set
    end
    return FDJ.repeatableQuestIDs[quest] == true
end
-- A quest icon: the blue ? for a repeatable quest, else normal (the yellow !).
function FDJ.SetQuestIconTexture(tex, repeatable, normal)
    if not tex then return end
    if repeatable then
        if tex:SetTexture(FDJ.REPEATABLE_QUEST_TEXTURE) == false and tex.SetAtlas then
            pcall(tex.SetAtlas, tex, "QuestRepeatableTurnin", false)
            return
        end
    else
        tex:SetTexture(normal or "Interface\\GossipFrame\\AvailableQuestIcon")
    end
    tex:SetTexCoord(0, 1, 0, 1)
end
-- The same in text: "|T...|t " in front of a quest's name.
function FDJ.QuestIconMarkup(questID, size, normal)
    size = size or 14
    local path = FDJ.IsRepeatableQuest(questID) and FDJ.REPEATABLE_QUEST_TEXTURE or (normal or "Interface\\GossipFrame\\AvailableQuestIcon")
    return "|T" .. path .. ":" .. size .. ":" .. size .. ":0:0|t "
end

-- choicestep (2.0.37): a chain step that is a choice of quests (Blackmaw
-- Reclamation's first step: any ONE of Korsa's three quests). Its quests
-- sit next to each other in the chain with the same choice = value; they
-- share one number ("1. Master Feardred", "or Thinning Their Forces") and
-- the steps after count on from it. FDJ.QUEST_DONE_BY[id] = { other IDs }:
-- the quest counts as done once any of those is handed in.
FDJ.QUEST_DONE_BY = FDJ.QUEST_DONE_BY or {}
function FDJ.DoneByOther(questID)
    if FDJ.doneByOff then return false end -- pickone (2.0.42): a choice's own lines
    local others = FDJ.QUEST_DONE_BY[questID]
    if type(others) ~= "table" then return false end
    local check = (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or IsQuestFlaggedCompleted
    if type(check) ~= "function" then return false end
    for _, id in ipairs(others) do
        local ok, value = pcall(check, id)
        if ok and value == true then return true end
    end
    return false
end
-- The number a step shows: steps of one choice count once.
function FDJ.ChainStepNumber(chain, index)
    local n, last = 0, nil
    for i = 1, math.min(index or 0, type(chain) == "table" and #chain or 0) do
        local s = chain[i]
        local c = type(s) == "table" and s.choice or nil
        if c == nil or c ~= last then n = n + 1 end
        last = c
    end
    return n
end
-- "3. " in front of a step's name. A choice's quests (pickone, 2.0.42) are
-- "- name" under their "1. Pick one of the following quests:" line.
function FDJ.ChainStepLabel(chain, index)
    local s = type(chain) == "table" and chain[index]
    if type(s) == "table" and s.choice ~= nil and FDJ.ChainInChoice(chain, index) then
        return "- "
    end
    return tostring(FDJ.ChainStepNumber(chain, index)) .. ". "
end
-- A quest of a choice of two or more (its first index, its last).
function FDJ.ChainInChoice(chain, index)
    local s = type(chain) == "table" and chain[index]
    if type(s) ~= "table" or s.choice == nil then return nil end
    local first = index
    while type(chain[first - 1]) == "table" and chain[first - 1].choice == s.choice do first = first - 1 end
    local last = FDJ.ChainChoiceEnd(chain, first)
    if last > first then return first, last end
    return nil
end
-- The chain's quests from index on that are one choice with it (index itself
-- when it is not a choice): the last index.
function FDJ.ChainChoiceEnd(chain, index)
    local s = type(chain) == "table" and chain[index]
    local last = index
    if type(s) == "table" and s.choice ~= nil then
        while type(chain[last + 1]) == "table" and chain[last + 1].choice == s.choice do last = last + 1 end
    end
    return last
end
-- choiceline (2.0.40): text cut to fit maxWidth, ending in "..." (UTF-8 safe).
function FDJ.FitText(fs, text, maxWidth)
    text = text or ""
    fs:SetText(text)
    if (fs:GetStringWidth() or 0) <= maxWidth then return text, false end
    local chars = {}
    for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = ch end
    local lo, hi, best = 0, #chars - 1, "..."
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        local s = table.concat(chars, "", 1, mid):gsub("[%s,/%.]+$", "") .. "..."
        fs:SetText(s)
        if (fs:GetStringWidth() or 0) <= maxWidth then best, lo = s, mid + 1 else hi = mid - 1 end
    end
    fs:SetText(best)
    return best, true
end
-- pickone (2.0.42): a choice of quests in a chain list is one numbered line,
-- "1. Pick one of the following quests:" with a + (- when open); a click
-- opens its quests below it, one a line ("- Master Feardred"). Open or
-- closed per chain step for the session; opened by itself when one of its
-- quests is the step shown. choiceopen (2.0.53): open to start with (players
-- missed the +); its - still closes it, for the session.
FDJ.CHAIN_CHOICE_OPEN = FDJ.CHAIN_CHOICE_OPEN or {}
function FDJ.ChainChoiceIsOpen(questID, chain, index, selected)
    local v = FDJ.CHAIN_CHOICE_OPEN[tostring(questID) .. ":" .. tostring(index)]
    if v ~= nil then return v end
    do return true end -- choiceopen (2.0.53)
    if type(selected) == "table" and selected.id then
        for k = index, FDJ.ChainChoiceEnd(chain, index) do
            local s = chain[k]
            if type(s) == "table" and s.id == selected.id then return true end
        end
    end
    return false
end
-- How many lines the chain list has (open choices count their quests).
function FDJ.ChainLineCount(questID, chain, selected)
    local n, index = 0, 1
    while index <= #chain do
        local last = FDJ.ChainChoiceEnd(chain, index)
        n = n + 1
        if last > index and FDJ.ChainChoiceIsOpen(questID, chain, index, selected) then n = n + (last - index + 1) end
        index = last + 1
    end
    return n
end
-- The "1. Pick one of the following quests:" line of a choice (pickone,
-- 2.0.42): green with a tick once one of its quests is handed in, gold while
-- one is in the log ("You have it" when closed), the ? when one is ready.
-- choicepulse (2.0.54): Show Quest Chain opens a chain's choices ("You just
-- need 1 of the following quests:", even one closed before) and lights
-- their quests up for about 3 seconds: the gold wash pulsing, as an option's
-- row does in Options when the journal points at it (FDJ.OpenSettingsAt).
FDJ.chainChoiceButtons = FDJ.chainChoiceButtons or {}
function FDJ.OpenChainChoices(questID, chain)
    if not (questID and type(chain) == "table") then return end
    local index = 1
    while index <= #chain do
        local last = FDJ.ChainChoiceEnd(chain, index)
        if last > index then FDJ.CHAIN_CHOICE_OPEN[tostring(questID) .. ":" .. tostring(index)] = true end
        index = last + 1
    end
end
function FDJ.PulseChainRow(r)
    if not r then return end
    if not r.fdjPulse then
        local glow = r:CreateTexture(nil, "BACKGROUND", nil, 2)
        glow:SetAllPoints()
        glow:SetTexture("Interface\\Buttons\\WHITE8X8")
        glow:SetVertexColor(1.00, 0.78, 0.25, 0.35)
        glow:SetAlpha(0)
        local pulse = glow:CreateAnimationGroup()
        pulse:SetLooping("BOUNCE")
        local fade = pulse:CreateAnimation("Alpha")
        fade:SetFromAlpha(0)
        fade:SetToAlpha(1)
        fade:SetDuration(0.375)
        pulse:SetScript("OnLoop", function(self)
            self.loops = (self.loops or 0) + 1
            if self.loops >= 8 then self:Stop() end -- 8 x 0.375 s: 3 seconds
        end)
        pulse:SetScript("OnStop", function() glow:SetAlpha(0) end)
        pulse:SetScript("OnFinished", function() glow:SetAlpha(0) end)
        r.fdjPulse, r.fdjPulseGlow = pulse, glow
    end
    r.fdjPulse.loops = 0
    r.fdjPulse:Stop()
    r.fdjPulse:Play()
end
function FDJ.PulseChainChoices(questID, chain)
    local button = questID and FDJ.chainChoiceButtons[questID]
    if not (button and button.chainRows and type(chain) == "table") then return 0 end
    local n, index = 0, 1
    while index <= #chain do
        local last = FDJ.ChainChoiceEnd(chain, index)
        if last > index then
            for k = index, last do
                local r = button.chainRows[k]
                if r and r.parentQuestID == questID and r:IsShown() then
                    FDJ.PulseChainRow(r)
                    n = n + 1
                end
            end
        end
        index = last + 1
    end
    return n
end

function FDJ.DrawChoiceHeader(button, quest, chain, first, last, lineHeight)
    FDJ.chainChoiceButtons[quest.id] = button -- choicepulse (2.0.54)
    button.choiceHeaders = button.choiceHeaders or {}
    local h = button.choiceHeaders[first]
    if not h then
        h = CreateFrame("Button", nil, button.chainPanel)
        h:SetHeight(lineHeight)
        h:RegisterForClicks("LeftButtonUp")
        h.text = h:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
        h.text:SetPoint("LEFT", 0, 0)
        h.text:SetJustifyH("LEFT")
        if h.text.SetWordWrap then h.text:SetWordWrap(false) end
        h.toggle = h:CreateTexture(nil, "OVERLAY")
        h.toggle:SetSize(16, 16)
        h.statusIcon = h:CreateTexture(nil, "OVERLAY")
        h.statusIcon:SetSize(12, 12)
        h.statusIcon:Hide()
        h.haveIt = h:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
        h.haveIt:SetPoint("RIGHT", h, "RIGHT", -2, 0)
        h.haveIt:SetJustifyH("RIGHT")
        h.haveIt:SetTextColor(1.00, 0.82, 0.10)
        h.haveIt:SetShadowColor(0, 0, 0, 0.72)
        h.haveIt:SetShadowOffset(1, -1)
        h.haveIt:Hide()
        h.highlight = h:CreateTexture(nil, "HIGHLIGHT")
        h.highlight:SetAllPoints()
        h.highlight:SetTexture("Interface\\Buttons\\WHITE8X8")
        h.highlight:SetColorTexture(1, 0.82, 0.25, 0.10)
        h:SetScript("OnClick", function(self)
            FDJ.CHAIN_CHOICE_OPEN[tostring(self.parentQuestID) .. ":" .. tostring(self.choiceIndex)] = not self.open
            PlayJournalOptionSound()
            RefreshQuestList()
        end)
        h:SetScript("OnEnter", function(self)
            if not self.truncated or not self.fullText then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.fullText, 1, 0.82, 0.25)
            GameTooltip:Show()
        end)
        h:SetScript("OnLeave", function(self)
            if self.truncated then GameTooltip:Hide() end
        end)
        button.choiceHeaders[first] = h
    end
    h.parentQuestID, h.choiceIndex = quest.id, first
    h.open = FDJ.ChainChoiceIsOpen(quest.id, chain, first, selectedPrereqStep)
    h.toggle:SetTexture(h.open and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
    h.toggle:Show()
    local done, ready, inLog = false, false, false
    for k = first, last do
        local s = chain[k]
        if type(s) == "table" and s.id then
            if FDJ.QuestTurnedIn(s.id) then done = true
            elseif IsQuestFinished(s.id) then ready = true
            elseif IsQuestInLog(s.id) then inLog = true end
        end
    end
    h.fullText = tostring(FDJ.ChainStepNumber(chain, first)) .. ". " .. L("CHAIN_PICK_ONE")
    h.text:SetWidth(0)
    h.text:SetText(h.fullText)
    if done then
        h.text:SetTextColor(0.45, 0.95, 0.50)
    elseif ready or inLog then
        h.text:SetTextColor(1.00, 0.83, 0.28)
    else
        h.text:SetTextColor(0.78, 0.74, 0.66)
    end
    h.statusIcon:Hide()
    if done then
        h.statusIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        h.statusIcon:Show()
    end
    -- One of its quests ready to hand in while it is closed: the clickable
    -- round ? on this line (2.0.43), as on the quest's own line.
    local readyStep
    if ready and not done and not h.open then
        for k = first, last do
            local s = chain[k]
            if type(s) == "table" and s.id and not FDJ.QuestTurnedIn(s.id) and IsQuestFinished(s.id) then readyStep = s break end
        end
    end
    if readyStep and FDJ.CreateTurnInButton and FDJ.SetTurnInButton then
        if not h.turnInMark then
            h.turnInMark = FDJ.CreateTurnInButton(h, 16)
            h.turnInMark:SetFrameLevel(h:GetFrameLevel() + 3)
        end
        local d = QUEST_PREREQ_DETAILS[readyStep.id] or {}
        FDJ.SetTurnInButton(h.turnInMark, { id = readyStep.id, turnin = d.turnin, turninMap = d.turninMap },
            QuestField(readyStep.id, "name", readyStep.name))
        if FDJ.ResizeTurnInButton then FDJ.ResizeTurnInButton(h.turnInMark, FDJ.StepMarkSize()) end
    elseif h.turnInMark then
        FDJ.SetTurnInButton(h.turnInMark, nil)
    end
    if inLog and not ready and not done and not h.open then
        h.haveIt:SetFontObject("ForeverDJ_GameFontNormalSmall")
        h.haveIt:SetScale(1)
        h.haveIt:SetText(L("YOU_HAVE_IT"))
        local labelWidth = h.haveIt:GetStringWidth() or 0
        if labelWidth > 88 then h.haveIt:SetScale(math.max(0.80, 88 / labelWidth)) end
        h.haveIt:Show()
    else
        h.haveIt:Hide()
    end
    h.toggle:ClearAllPoints()
    h.toggle:SetPoint("LEFT", h.text, "RIGHT", 4, 0)
    h.statusIcon:ClearAllPoints()
    h.statusIcon:SetPoint("LEFT", h.toggle, "RIGHT", 3, 0)
    if h.turnInMark then
        h.turnInMark:ClearAllPoints()
        h.turnInMark:SetPoint("LEFT", h.toggle, "RIGHT", 3, 0)
    end
    h:Show()
end
-- One chain-list line at x, y: nothing runs over the panel's border, a name
-- too long ends in "..." (choiceline, 2.0.40; the whole name on mouse-over).
function FDJ.PlaceChainLine(panel, r, x, y, inner)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
    r:SetPoint("RIGHT", panel, "RIGHT", -6, 0)
    r.fullText = r.fullText or r.text:GetText() or ""
    if r.divider then r.divider:Hide() end
    r.text:ClearAllPoints()
    r.text:SetPoint("LEFT", r, "LEFT", 0, 0)
    local extra = 0
    if r.toggle and r.toggle:IsShown() then extra = extra + 4 + 16 end
    if r.turnInMark and r.turnInMark:IsShown() then
        extra = extra + 3 + (r.turnInMark:GetWidth() or 24)
    elseif r.statusIcon and r.statusIcon:IsShown() then
        extra = extra + 5 + 12
    end
    local haveWidth = 0
    if r.haveIt and r.haveIt:IsShown() then
        r.haveIt:ClearAllPoints()
        r.haveIt:SetPoint("RIGHT", r, "RIGHT", -2, 0)
        haveWidth = math.min(88, (r.haveIt:GetStringWidth() or 0) * (r.haveIt:GetScale() or 1)) + 8
    end
    local room = inner - (x - 8) - haveWidth - extra
    local _, cut = FDJ.FitText(r.text, r.fullText, math.max(0, room))
    r.truncated = cut or nil
end
function FDJ.LayoutChainRows(button, chain, lineHeight)
    local panel, rows = button.chainPanel, button.chainRows
    if not panel or not rows then return end
    button.layoutChain, button.layoutLineHeight = chain, lineHeight
    local inner = (panel:GetWidth() or 0) - 14
    if inner < 80 then
        inner = math.max(80, (button:GetWidth() or 0) - 39 - 8 - 14)
        -- Its size not known yet: once more on the next frame.
        if C_Timer and C_Timer.After and not button.layoutRetry then
            button.layoutRetry = true
            C_Timer.After(0, function()
                button.layoutRetry = nil
                if panel:IsShown() and button.layoutChain and (panel:GetWidth() or 0) - 14 >= 80 then
                    FDJ.LayoutChainRows(button, button.layoutChain, button.layoutLineHeight or 18)
                end
            end)
        end
    end
    local index, line = 1, 0
    while index <= #chain do
        local last = FDJ.ChainChoiceEnd(chain, index)
        if last > index then
            local header = button.choiceHeaders and button.choiceHeaders[index]
            line = line + 1
            if header then FDJ.PlaceChainLine(panel, header, 8, -5 - (line - 1) * lineHeight, inner) end
            local open = header and header.open
            for k = index, last do
                local r = rows[k]
                if r then
                    if open then
                        line = line + 1
                        FDJ.PlaceChainLine(panel, r, 8 + 14, -5 - (line - 1) * lineHeight, inner)
                        r:Show()
                    else
                        r:Hide()
                    end
                end
            end
        else
            line = line + 1
            local r = rows[index]
            if r then FDJ.PlaceChainLine(panel, r, 8, -5 - (line - 1) * lineHeight, inner) end
        end
        index = last + 1
    end
end

FDJ.HideStepItemButtons = function()
    if not frame then return end
    for _, button in ipairs(frame.questStepItemButtons or {}) do
        button.item = nil
        button.fdjSourceText = nil
        button.fdjMapLocation = nil
        button.fdjNoteImageClick = nil -- itemhint
        button:Hide()
    end
    if frame.questProvidedItemHeader then frame.questProvidedItemHeader:Hide() end
    if frame.questChainNotice then frame.questChainNotice:Hide() end
    if frame.questWarningText then frame.questWarningText:Hide() end
end

-- Item cards (required / provided items) two to a row, like the rewards:
-- half the page wide each, filling left then right.
FDJ.PlaceStepItemButtons = function(items, startIndex, cursorY, width)
    frame.questStepItemButtons = frame.questStepItemButtons or {}
    local theme = THEMES[selectedDungeon] or THEMES["Hall of Thanes"]
    local full = math.max(260, (frame.questDetailScroll and frame.questDetailScroll:GetWidth() or 350) - 4)
    width = math.floor((full - 10) / 2)
    local topY = cursorY
    for i, item in ipairs(items) do
        local index = startIndex + i
        local button = frame.questStepItemButtons[index]
        if not button then
            button = MakeQuestRewardButton(frame.questDetailContent)
            frame.questStepItemButtons[index] = button
        end
        button.item = item
        if FDJ.UpdateFavouriteIndicator then FDJ.UpdateFavouriteIndicator(button, item[1]) end
        button.fdjSourceText = item[4] and FreeText(item[4]) or nil
        button.fdjMapLocation = item.map
        button.fdjNoteImageClick = nil -- itemhint: set again by FDJ.PlaceItemLocationHint
        button:SetSize(width, 42)
        button.icon:SetTexture(ItemIcon(item[1]))
        if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
            pcall(C_Item.RequestLoadItemDataByID, item[1])
        end
        local itemName, itemLink, quality = ItemInfo(item[1])
        local r, g, b = GetAuthoritativeItemQuality(item[1], itemLink, quality, item[3] or 1)
        -- How many are needed: item.count, or the "(N needed)" in its
        -- source text; shown after the name inside the card (×4, ×12).
        local needed = tonumber(item.count)
        if not needed and type(item[4]) == "string" then needed = tonumber(item[4]:match("%((%d+) needed%)")) end
        local countText = (needed and needed > 1) and (" ×" .. tostring(needed)) or ""
        button.name:SetText((itemName or item[2] or "") .. countText)
        button.name:SetTextColor(r, g, b)
        button:SetBackdropColor(unpack(theme.lootRow))
        button:SetBackdropBorderColor(unpack(theme.border))
        -- dungeonitem (2.1.0, Materials of Significance): an item that comes
        -- from the dungeon whose page this is (item.dungeon) is marked with a
        -- gold edge, so each dungeon's own part of a quest stands out.
        if item.dungeon and item.dungeon == selectedDungeon then
            if not button.fdjHereGlow then
                local glow = CreateFrame("Frame", nil, button, "BackdropTemplate")
                glow:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 3)
                glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -3)
                glow:SetFrameLevel(button:GetFrameLevel() + 5)
                glow:EnableMouse(false)
                SetBackdrop(glow, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 9, 2)
                glow:SetBackdropColor(1.00, 0.78, 0.08, 0.10)
                glow:SetBackdropBorderColor(1.00, 0.82, 0.12, 1.00)
                button.fdjHereGlow = glow
            end
            button.fdjHereGlow:Show()
        elseif button.fdjHereGlow then
            button.fdjHereGlow:Hide()
        end
        button:ClearAllPoints()
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        button:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", col * (width + 10), -(topY + row * 46))
        button:Show()
        cursorY = topY + (row + 1) * 46
    end
    return cursorY
end

local function RefreshPrerequisiteQuestDetail(step)
    if not frame or not step then return false end
    FDJ.PlaceNoteImage(nil) -- noteimage
    FDJ.PlaceShowLocation(false) -- showlocation

    local questID = step.id
    -- Item steps (e.g. the Data Rescue punch cards) are not real quests:
    -- never query the quest API for their placeholder IDs.
    local isItemStep = step.itemStep
    if questID and not isItemStep then RequestQuestRewardData(questID) end

    local title = isItemStep and QuestField(questID, "name", step.name) or GetLoadedQuestTitle(questID, step.name)
    local complete = (questID and not isItemStep and IsQuestFinished(questID)) or false
    local inLog = (questID and not isItemStep and IsQuestInLog(questID)) or false
    local logIndex = (questID and not isItemStep and GetQuestLogIndexForQuestIDSafe(questID)) or nil
    local details = (questID and QUEST_PREREQ_DETAILS[questID]) or {}
    local hubPlaceholder = details.hubPlaceholder == true
    local level = step.level or details.level
    local requiredLevel = step.requires or details.requires
    local description = QuestField(questID, "description", details.description)
    local objectiveText = hubPlaceholder and details.objective or QuestField(questID, "objective", details.objective)
    if hubPlaceholder or details.suppressDescription then description = nil end
    local canUseClientQuestText = not FDJ.CanUseClientLocalizedText or FDJ.CanUseClientLocalizedText()

    if logIndex and canUseClientQuestText and not hubPlaceholder then
        if C_QuestLog and type(C_QuestLog.GetInfo) == "function" then
            local ok, info = pcall(C_QuestLog.GetInfo, logIndex)
            if ok and type(info) == "table" and type(info.level) == "number" and info.level > 0 then
                level = info.level
            end
        end
        if type(GetQuestLogQuestText) == "function" then
            local ok, desc, obj = pcall(GetQuestLogQuestText, logIndex)
            if ok then
                -- The game's quest description (story text) is left out on purpose.
                if not IsSecret(obj) and type(obj) == "string" and obj ~= "" then objectiveText = obj end
            end
        end
    end

    if inLog and not hubPlaceholder and canUseClientQuestText and questID and C_QuestLog and type(C_QuestLog.GetQuestObjectives) == "function" then
        local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
        if ok and type(objectives) == "table" and #objectives > 0 then
            local parts = {}
            for i, objective in ipairs(objectives) do
                if type(objective) == "table" and not IsSecret(objective.text)
                    and type(objective.text) == "string" and objective.text ~= "" then
                    -- objdone (2.0.13): a done line without a count: "(Complete)"
                    parts[#parts + 1] = FDJ.ObjectiveDoneText and FDJ.ObjectiveDoneText(objective.text, FDJ.ObjectiveDone(questID, i, objective)) or objective.text
                end
            end
            if #parts > 0 then objectiveText = table.concat(parts, "\n") end
        end
    end

    if frame.questDetailScroll then frame.questDetailScroll:Show() end
    if frame.noQuestMessage then frame.noQuestMessage:Hide() end

    frame.selectedQuestName:SetText(title)
    frame.selectedQuestName:SetTextColor(1.00, 0.78, 0.16)
    frame.selectedQuestName:ClearAllPoints()
    frame.selectedQuestName:SetPoint("TOPLEFT", frame.questTextInset, "TOPLEFT", 16, -15)
    frame.selectedQuestName:SetPoint("RIGHT", frame.questTextInset, "RIGHT", -92, 0)

    local meta = FDJ.StepMetaLabel(step) -- questguide
    if requiredLevel then
        meta = meta .. "  |  " .. L("AVAILABLE_FROM_LEVEL", FDJ.QuestLevelText(requiredLevel, true)) -- (redlevel)
    end
    frame.selectedQuestMeta:SetText(meta)
    frame.selectedQuestMeta:SetTextColor(0.25, 0.16, 0.08)
    if frame.selectedQuestClass then frame.selectedQuestClass:Hide() end
    if frame.selectedQuestClassIcon then frame.selectedQuestClassIcon:Hide() end
    if frame.selectedQuestMetaClassIcon then frame.selectedQuestMetaClassIcon:Hide() end
    local stepReady = complete and not FDJ.QuestTurnedIn(questID)
    frame.selectedQuestComplete:SetShown(complete and not (stepReady and frame.selectedQuestTurnIn))
    if frame.selectedQuestTurnIn then
        FDJ.SetTurnInButton(frame.selectedQuestTurnIn, stepReady and { id = questID, turnin = details.turnin, turninMap = details.turninMap } or nil, title)
    end
    UpdatePrerequisiteNavButtons()

    -- Prerequisite/quest-chain steps use the same shareability control as
    -- normal dungeon quests. Keep it to the left of the chain navigation
    -- arrows so neither control overlaps the other.
    local prereqShareInset = 92
    if questID and frame.questShareButton then
        FDJ.UpdateQuestShareButton(questID, nil)
        local shareWidth = frame.questShareButton:GetWidth() or 76
        frame.questShareButton:ClearAllPoints()
        frame.questShareButton:SetPoint("TOPRIGHT", frame.questTextInset, "TOPRIGHT", -82, -10)
        prereqShareInset = 94 + shareWidth
    elseif frame.questShareButton then
        frame.questShareButton.questID = nil
        frame.questShareButton:Hide()
    end

    frame.selectedQuestName:ClearAllPoints()
    frame.selectedQuestName:SetPoint("TOPLEFT", frame.questTextInset, "TOPLEFT", 16, -15)
    frame.selectedQuestName:SetPoint("RIGHT", frame.questTextInset, "RIGHT", -prereqShareInset, 0)
    -- Placed here, after the title got its final width (the Share button narrows it).
    -- Chain step pages: the step arrows sit top right, so the tick goes
    -- directly after the title text instead.
    frame.selectedQuestComplete:ClearAllPoints()
    do
        local title = frame.selectedQuestName
        if not frame.fdjTitleMeasure then
            frame.fdjTitleMeasure = frame:CreateFontString(nil, "BACKGROUND")
            frame.fdjTitleMeasure:Hide()
        end
        do
            local fontFile, fontSize, fontFlags = title:GetFont()
            if fontFile then frame.fdjTitleMeasure:SetFont(fontFile, fontSize, fontFlags) end
            frame.fdjTitleMeasure:SetText(title:GetText() or "")
        end
        local textWidth = frame.fdjTitleMeasure:GetStringWidth() or 0
        local boxWidth = title:GetWidth() or 0
        if boxWidth > 0 and textWidth > boxWidth then
            -- The title wraps: put the tick after the end of its LAST line, so it
            -- never sits under the Share button. The wrap is re-created word by
            -- word with a hidden measuring string in the same font.
            if not frame.fdjTitleMeasure then
                frame.fdjTitleMeasure = frame:CreateFontString(nil, "BACKGROUND")
                frame.fdjTitleMeasure:Hide()
            end
            local measure = frame.fdjTitleMeasure
            local fontFile, fontSize, fontFlags = title:GetFont()
            if fontFile then measure:SetFont(fontFile, fontSize, fontFlags) end
            local line, lastWidth = "", 0
            for word in tostring(title:GetText() or ""):gmatch("%S+") do
                local try = (line == "") and word or (line .. " " .. word)
                measure:SetText(try)
                local w = measure:GetStringWidth() or 0
                if line ~= "" and w > boxWidth then
                    line = word
                    measure:SetText(word)
                    lastWidth = measure:GetStringWidth() or 0
                else
                    line, lastWidth = try, w
                end
            end
            if lastWidth > boxWidth - 22 then lastWidth = boxWidth - 22 end
            frame.selectedQuestComplete:SetPoint("BOTTOMLEFT", title, "BOTTOMLEFT", lastWidth + 6, -2)
        else
            frame.selectedQuestComplete:SetPoint("LEFT", title, "LEFT", textWidth + 6, 0)
        end
    end
    -- stepheader (2.0.5): the header as tall as this step's title and line
    -- need. It used to keep the height of the quest shown before, so after a
    -- quest with a two-line title or a class / attunement tag (Blood of the
    -- Black Dragon Champion) its steps had an empty band under the title.
    frame.fdjStepHeaderHeight = math.max(58, 15 + (frame.selectedQuestName:GetStringHeight() or 0)
        + 5 + math.max(24, frame.selectedQuestMeta:GetStringHeight() or 0) + 8)
    frame.questHeaderSeparator:ClearAllPoints()
    frame.questHeaderSeparator:SetPoint("TOPLEFT", 14, -frame.fdjStepHeaderHeight)
    frame.questHeaderSeparator:SetPoint("TOPRIGHT", -14, -frame.fdjStepHeaderHeight)
    frame.questDetailScroll:ClearAllPoints()
    frame.questDetailScroll:SetPoint("TOPLEFT", 16, -(frame.fdjStepHeaderHeight + 14))
    frame.questDetailScroll:SetPoint("BOTTOMRIGHT", -31, 16)

    local detailWidth = math.max(260, (frame.questDetailScroll:GetWidth() or 350) - 4)
    frame.questDetailContent:SetWidth(detailWidth)
    frame.questDetailText:SetWidth(detailWidth)
    frame.questNotesText:SetWidth(detailWidth)
    if FDJ.HideQuestDescription then FDJ.HideQuestDescription(frame) end

    if frame.questStartsHeader then frame.questStartsHeader:Hide() end
    if frame.questTurninHeader then frame.questTurninHeader:Hide() end
    FDJ.SetHeaderDungeonIcon("questObjectiveDungeonIcon") -- insidequest
    FDJ.SetHeaderDungeonIcon("questTurninDungeonIcon")
    if frame.questMapButton then
        frame.questMapButton.quest = nil
        frame.questMapButton.prereqLocation = nil
        frame.questMapButton.fdjLabelKey = nil
        frame.questMapButton.fdjCustomLabel = nil
        if frame.questMapButton.icon then frame.questMapButton.icon:Hide() end
        frame.questMapButton:Hide()
    end
    if frame.questChainButton then
        frame.questChainButton.questID = nil
        frame.questChainButton.parentQuestName = nil
        frame.questChainButton:Hide()
    end
    FDJ.PlaceGuideButton(nil, 0) -- questguide
    FDJ.PlaceSummonHelp(nil, 0) -- summonhelp
    if FDJ.PlaceRepNeeds then FDJ.PlaceRepNeeds(nil, 0) end -- repneeds
    if frame.questStartLinkButton then
        frame.questStartLinkButton.questID = nil
        frame.questStartLinkButton:Hide()
    end
    if frame.questStartRequiresText then frame.questStartRequiresText:Hide() end
    if frame.questLeadsToButton then
        frame.questLeadsToButton.questID = nil
        frame.questLeadsToButton:Hide()
    end
    if frame.questStartItemButton then frame.questStartItemButton.item = nil; frame.questStartItemButton:Hide() end
    if frame.questRequiredItemsHeader then frame.questRequiredItemsHeader:Hide() end
    if frame.questRequiredItemButton then frame.questRequiredItemButton.item = nil; frame.questRequiredItemButton:Hide() end
    if frame.questNoteItemButton then frame.questNoteItemButton.item = nil; frame.questNoteItemButton:Hide() end
    FDJ.HideStepItemButtons()
    if frame.questStartsText then frame.questStartsText:SetText(""); frame.questStartsText:Hide() end
    if frame.questStartDungeonIcon then frame.questStartDungeonIcon:Hide() end
    if frame.questTurninText then frame.questTurninText:SetText(""); frame.questTurninText:Hide() end

    for _, button in ipairs(questRewardButtons) do button.item = nil; button:Hide() end
    for _, button in ipairs(questNoteRewardButtons) do button.item = nil; button:Hide() end
    if frame.questAdditionalRewardButtons then
        for _, button in ipairs(frame.questAdditionalRewardButtons) do button.item = nil; button:Hide() end
    end
    if frame.questXPReward then frame.questXPReward:Hide() end
    if frame.questMoneyReward then frame.questMoneyReward:Hide() end
    if frame.questAlsoReceiveHeader then frame.questAlsoReceiveHeader:Hide() end
    frame.questRewardHeader:SetText("")
    frame.questRewardSummary:SetText("")
    if FDJ.LayoutRepPills then FDJ.LayoutRepPills({}, 0, 0) end

    local cursorY = 0
    FDJ.PlaceObjectiveMapButton(nil, 0) -- glowingshard: not on a chain step's page
    -- warningtop (2.0.31): a step whose warning must be read first
    -- (details.warningTop) has it above everything, Objective included.
    local topWarning = details.warningTop and QuestField(questID, "warning", details.warning) or nil
    if topWarning and topWarning ~= "" then
        if not frame.questWarningText then
            frame.questWarningText = frame.questDetailContent:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
            frame.questWarningText:SetJustifyH("LEFT")
        end
        frame.questWarningText:ClearAllPoints()
        frame.questWarningText:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
        frame.questWarningText:SetWidth(math.max(120, (frame.questDetailContent:GetWidth() or 360) - 8))
        frame.questWarningText:SetText(topWarning)
        FDJ.WarningFont(frame.questWarningText) -- warnfont: its font and colour (Core/Fonts.lua)
        frame.questWarningText:Show()
        cursorY = cursorY + (frame.questWarningText:GetStringHeight() or 22) + 12
    else
        topWarning = nil
    end
    cursorY = FDJ.PlaceStepHaveItRow(inLog and not FDJ.QuestTurnedIn(questID) -- chainturnin
        and FDJ.TurnInInsideDungeon(details.turnin, selectedDungeon), questID, details, title, cursorY)
    -- dungeonstep (2.1.1): "DUNGEON STEP" over the Objective, the page in teal
    cursorY = FDJ.PlaceDungeonStepLabel((not isItemStep) and details.dungeonStep ~= false and (details.dungeonStep == true or FDJ.ObjectiveInsideDungeon(details, selectedDungeon) -- (insideaudit: true by hand)
        or details.startsInDungeon or FDJ.StartsInsideDungeon(details.pickup)
        or FDJ.StartItemDropsIn(details, selectedDungeon)) and true or false, cursorY)
    frame.questObjectiveHeader:ClearAllPoints()
    frame.questObjectiveHeader:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
    frame.questObjectiveHeader:Show()
    FDJ.SetHeaderDungeonIcon("questObjectiveDungeonIcon", frame.questObjectiveHeader,
        (not isItemStep) and FDJ.ObjectiveInsideDungeon(details, selectedDungeon)) -- insidequest
    cursorY = cursorY + (frame.questObjectiveHeader:GetStringHeight() or 18) + 4

    frame.questDetailText:ClearAllPoints()
    frame.questDetailText:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
    local body = objectiveText or description
    if not body or body == "" then
        if inLog then
            body = L("QUEST_IN_LOG")
        elseif complete then
            body = L("QUEST_COMPLETED")
        else
            body = L("QUEST_NOT_CACHED")
        end
    elseif description and objectiveText and description ~= objectiveText then
        body = objectiveText .. "\n\n" .. description
    end
    frame.questDetailText:SetText(body)
    frame.questDetailText:SetTextColor(0.10, 0.065, 0.025)
    frame.questDetailText:Show()
    cursorY = cursorY + (frame.questDetailText:GetStringHeight() or 40) + 14

    -- Word of the Woods placeholder: no old story, pickup or turn-in text.
    -- Show the short notice and a single hub map button until the chain is known.
    if hubPlaceholder then
        if frame.questNotesHeader then frame.questNotesHeader:Hide() end
        FDJ.PlaceNoteImage(nil) -- noteimage
        FDJ.PlaceShowLocation(false) -- showlocation
        if frame.questNotesText then frame.questNotesText:SetText(""); frame.questNotesText:Hide() end
        local loc = details.hubMap
        if loc and frame.questMapButton then
            local button = frame.questMapButton
            button:ClearAllPoints()
            button.quest = nil
            button.prereqLocation = (FDJ.LocalizeMapLocation and FDJ.LocalizeMapLocation(loc)) or loc
            button.fdjQuestTitle = "Shen'dralas quest hub"
            button.fdjQuestID = nil
            button.fdjLabelKey = nil
            button.fdjCustomLabel = "Show quest hub"
            if button.icon then button.icon:Hide() end
            UpdateQuestActionButtonSizes()
            if FDJ.MapMarkers and FDJ.MapMarkers.ConfigureTargetAndMarkAction then
                FDJ.MapMarkers.ConfigureTargetAndMarkAction(button, button.prereqLocation, true)
            end
            button:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
            button:Show()
            cursorY = cursorY + 34
        end
        frame.questDetailContent:SetHeight(math.max(1, cursorY))
        FDJ.ApplyQuestDetailScroll("step:" .. tostring(selectedDungeon) .. ":" .. tostring(selectedPrereqParentQuestID) .. ":" .. tostring(step.id or step.name), cursorY)
        UpdateScrollBarVisibility(frame.questDetailScroll, cursorY)
        return true
    end

    local stepRequired = details.requiredItems
    -- Required-item cards are only useful when we can tell the player where the
    -- item comes from. Bare item icons duplicate the quest objective and waste
    -- a large amount of vertical space.
    if stepRequired and #stepRequired > 0 and frame.questRequiredItemsHeader then
        local usefulRequired = {}
        for _, requiredItem in ipairs(stepRequired) do
            -- requiredicons (2.0.11): details.showRequiredIcons shows the
            -- items without a source line too (the four elementals).
            if details.showRequiredIcons or (type(requiredItem[4]) == "string" and requiredItem[4] ~= "") then
                usefulRequired[#usefulRequired + 1] = requiredItem
            end
        end
        if #usefulRequired > 0 then
            frame.questRequiredItemsHeader:ClearAllPoints()
            frame.questRequiredItemsHeader:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
            frame.questRequiredItemsHeader:Show()
            cursorY = cursorY + (frame.questRequiredItemsHeader:GetStringHeight() or 18) + 4
            cursorY = FDJ.PlaceStepItemButtons(usefulRequired, 0, cursorY, math.min(300, detailWidth)) + 8
        else
            frame.questRequiredItemsHeader:Hide()
        end
    end
    FDJ.PlaceItemLocationHint(details.noteImage, true) -- itemhint (hintalways)
    if details.providedItem and frame.questProvidedItemHeader then
        frame.questProvidedItemHeader:ClearAllPoints()
        frame.questProvidedItemHeader:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
        frame.questProvidedItemHeader:Show()
        cursorY = cursorY + (frame.questProvidedItemHeader:GetStringHeight() or 18) + 4
        cursorY = FDJ.PlaceStepItemButtons({ details.providedItem }, stepRequired and #stepRequired or 0, cursorY, math.min(300, detailWidth)) + 8
    end


    if details.pickup and details.pickup ~= "" then
        -- Item steps (Data Rescue's punch cards) are cards to get, not
        -- quests to pick up: "Obtain" instead of "Starts at".
        frame.questStartsHeader:SetText(isItemStep and L("OBTAIN") or L("STARTS_AT"))
        frame.questStartsHeader:ClearAllPoints()
        frame.questStartsHeader:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
        frame.questStartsHeader:Show()
        cursorY = cursorY + (frame.questStartsHeader:GetStringHeight() or 18) + 3

        if details.startObject and not details.startItem and frame.questStartItemButton then
            -- Pre-quest started by a world object: same card as a start item.
            local obj = details.startObject
            frame.questStartsText:SetText("")
            frame.questStartsText:Hide()
            frame.questStartItemButton.item = nil
            frame.questStartItemButton.fdjSourceText = nil
            frame.questStartItemButton.fdjObject = { FreeText(obj[1]), FreeText(obj[3]) }
            frame.questStartItemButton.icon:SetTexture(obj[2] or "Interface\\Icons\\INV_Misc_QuestionMark")
            frame.questStartItemButton.name:SetText(FreeText(obj[1]))
            frame.questStartItemButton.name:SetTextColor(1, 1, 1)
            local objTheme = THEMES[selectedDungeon] or THEMES["Hall of Thanes"]
            frame.questStartItemButton:SetBackdropColor(unpack(objTheme.lootRow))
            frame.questStartItemButton:SetBackdropBorderColor(unpack(objTheme.border))
            frame.questStartItemButton:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
            frame.questStartItemButton:Show()
            -- FDJ_START_CARD_DUNGEON_ICON
            if frame.questStartDungeonIcon then
                frame.questStartDungeonIcon:Hide()
                if details.startsInDungeon or FDJ.StartsInsideDungeon(details.pickup) then FDJ.PositionInDungeonIcon() end
            end
            cursorY = cursorY + 48
        elseif details.startItem and frame.questStartItemButton then
            local startItem = details.startItem
            frame.questStartItemButton.fdjObject = nil
            frame.questStartsText:SetText("")
            frame.questStartsText:Hide()

            frame.questStartItemButton.item = startItem
            frame.questStartItemButton.fdjSourceText = FDJ.BossDropText and FDJ.BossDropText(startItem[1]) or FreeText(startItem[4])
            frame.questStartItemButton.icon:SetTexture(ItemIcon(startItem[1]))
            local itemName = ItemInfo(startItem[1])
            frame.questStartItemButton.name:SetText(itemName or startItem[2])
            frame.questStartItemButton.name:SetTextColor(1, 1, 1)
            local itemTheme = THEMES[selectedDungeon] or THEMES["Hall of Thanes"]
            frame.questStartItemButton:SetBackdropColor(unpack(itemTheme.lootRow))
            frame.questStartItemButton:SetBackdropBorderColor(unpack(itemTheme.border))
            frame.questStartItemButton:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
            frame.questStartItemButton:Show()
            if frame.questStartDungeonIcon then
                frame.questStartDungeonIcon:Hide()
                if details.startsInDungeon or FDJ.StartsInsideDungeon(details.pickup)
                    or FDJ.StartItemDropsIn(details, selectedDungeon) then FDJ.PositionInDungeonIcon() end
            end
            cursorY = cursorY + 48
        else
            frame.questStartsText:ClearAllPoints()
            frame.questStartsText:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
            local pickupText = QuestField(questID, "pickup", details.pickup)
            -- sidepickup (2.0.13, M 19 Nov 2026, Journey to the Marsh: on the
            -- Alliance side no Horde cities, and the other way round): a step
            -- with a start per faction (details.pickupAlliance / pickupHorde)
            -- shows the one of the faction the quest list is showing.
            local side = (selectedQuestFaction == "Alliance" or selectedQuestFaction == "Horde") and selectedQuestFaction or nil
            if side and type(details["pickup" .. side]) == "string" then
                pickupText = QuestField(questID, "pickup" .. side, details["pickup" .. side])
            end
            frame.questStartsText:SetText(pickupText)
            frame.questStartsText:SetTextColor(0.10, 0.065, 0.025)
            frame.questStartsText:Show()
            if frame.questStartDungeonIcon then
                frame.questStartDungeonIcon:Hide()
                if details.startsInDungeon or FDJ.StartsInsideDungeon(details.pickup) or FDJ.StartsInsideDungeon(pickupText) then
                    FDJ.PositionInDungeonIcon()
                end
            end
            cursorY = cursorY + (frame.questStartsText:GetStringHeight() or 24) + 7
        end

        if details.map and frame.questMapButton then
            frame.questMapButton:ClearAllPoints()
            frame.questMapButton.quest = nil
            frame.questMapButton.prereqLocation = (FDJ.LocalizeMapLocation and FDJ.LocalizeMapLocation(details.map)) or details.map
            frame.questMapButton.fdjQuestTitle = QuestField(questID, "name", step.name)
            frame.questMapButton.fdjQuestID = questID -- autoclear
            frame.questMapButton.fdjLabelKey = nil
            if frame.questMapButton.icon then frame.questMapButton.icon:Hide() end
            UpdateQuestActionButtonSizes()
            if FDJ.MapMarkers and FDJ.MapMarkers.ConfigureTargetAndMarkAction then
                FDJ.MapMarkers.ConfigureTargetAndMarkAction(frame.questMapButton, frame.questMapButton.prereqLocation, true)
            end
            frame.questMapButton:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
            frame.questMapButton:Show()
            cursorY = cursorY + 31
        end
    end

    if details.turnin and details.turnin ~= "" then
        frame.questTurninHeader:ClearAllPoints()
        frame.questTurninHeader:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
        frame.questTurninHeader:Show()
        FDJ.SetHeaderDungeonIcon("questTurninDungeonIcon", frame.questTurninHeader,
            (not isItemStep) and FDJ.TurnInInsideDungeon(details.turnin, selectedDungeon)) -- insidequest
        cursorY = cursorY + (frame.questTurninHeader:GetStringHeight() or 18) + 3
        frame.questTurninText:ClearAllPoints()
        frame.questTurninText:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
        frame.questTurninText:SetText(QuestField(questID, "turnin", details.turnin))
        frame.questTurninText:SetTextColor(0.10, 0.065, 0.025)
        frame.questTurninText:Show()
        cursorY = cursorY + (frame.questTurninText:GetStringHeight() or 24) + 8

        local startMap, turninMap = details.map, details.turninMap
        -- No spot given with the step: the turn-in NPC's spot by name (the
        -- same lookup as the quest tracker's ?).
        if not turninMap and not isItemStep and FDJ.TurnInSpotFor then
            turninMap = FDJ.TurnInSpotFor({ id = questID, turnin = details.turnin })
        end
        local sameNPC = startMap and turninMap and startMap.mapID == turninMap.mapID
            and math.abs((startMap.x or 0) - (turninMap.x or 0)) < 0.01
            and math.abs((startMap.y or 0) - (turninMap.y or 0)) < 0.01
        local turninButton = frame.questTurninMapButton or (not startMap and frame.questMapButton) or nil
        -- turnready (2.0.13, M 19 Nov 2026: "if the quest has not been
        -- completed yet, don't show the show turn in button"): only while
        -- the step is in the quest log and ready to hand in.
        if turninMap and not sameNPC and turninButton and inLog and complete then
            turninButton:ClearAllPoints()
            turninButton.quest = nil
            turninButton.prereqLocation = (FDJ.LocalizeMapLocation and FDJ.LocalizeMapLocation(turninMap)) or turninMap
            turninButton.fdjQuestTitle = QuestField(questID, "name", step.name)
            turninButton.fdjQuestID = questID -- autoclear
            turninButton.fdjLabelKey = "SHOW_TURN_IN"
            if turninButton.icon then turninButton.icon:Show() end
            if FDJ.MapMarkers and FDJ.MapMarkers.ConfigureTargetAndMarkAction then
                FDJ.MapMarkers.ConfigureTargetAndMarkAction(turninButton, turninButton.prereqLocation, true)
            end
            UpdateQuestActionButtonSizes()
            turninButton:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
            turninButton:Show()
            cursorY = cursorY + 34
        end
    end

    local prereqWarning = (not topWarning) and QuestField(questID, "warning", details.warning) or nil
    if topWarning then
        -- warningtop (2.0.31): already drawn above the Objective
    elseif prereqWarning and prereqWarning ~= "" then
        if not frame.questWarningText then
            frame.questWarningText = frame.questDetailContent:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
            frame.questWarningText:SetJustifyH("LEFT")
        end
        frame.questWarningText:ClearAllPoints()
        frame.questWarningText:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
        frame.questWarningText:SetWidth(math.max(120, (frame.questDetailContent:GetWidth() or 360) - 8))
        frame.questWarningText:SetText(prereqWarning)
        FDJ.WarningFont(frame.questWarningText) -- warnfont: its font and colour (Core/Fonts.lua)
        frame.questWarningText:Show()
        cursorY = cursorY + (frame.questWarningText:GetStringHeight() or 22) + 12
    elseif frame.questWarningText then
        frame.questWarningText:Hide()
    end

    local usefulNote = QuestField(questID, "note", details.note)
    if (usefulNote and usefulNote ~= "") or details.noteImage then -- noteimage: a picture alone opens Notes too
        frame.questNotesHeader:ClearAllPoints()
        frame.questNotesHeader:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
        frame.questNotesHeader:Show()
        cursorY = cursorY + (frame.questNotesHeader:GetStringHeight() or 18) + 4

        if usefulNote and usefulNote ~= "" then
            frame.questNotesText:ClearAllPoints()
            frame.questNotesText:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
            frame.questNotesText:SetText(usefulNote)
            frame.questNotesText:SetTextColor(0.10, 0.065, 0.025)
            frame.questNotesText:Show()
            cursorY = cursorY + (frame.questNotesText:GetStringHeight() or 30) + 18
        else
            frame.questNotesText:SetText("")
            frame.questNotesText:Hide()
        end
        cursorY = FDJ.PlaceNoteImage(details.noteImage, cursorY)
    else
        frame.questNotesHeader:Hide()
        frame.questNotesText:SetText("")
        frame.questNotesText:Hide()
        FDJ.PlaceNoteImage(nil)
    end

    local prereqRewardItems, prereqRewardChoice, prereqAlsoItems = GetPrerequisiteRewardItems(questID)
    prereqAlsoItems = prereqAlsoItems or {}
    local prereqXP = GetPrerequisiteRewardXP(questID)
    local prereqMoney = GetPrerequisiteRewardMoney(questID)
    local hasPrereqRewards = (#prereqRewardItems > 0) or (#prereqAlsoItems > 0) or (prereqXP and prereqXP > 0) or (prereqMoney > 0)
    if frame.questRewardAlsoHeader then frame.questRewardAlsoHeader:Hide() end

    if hasPrereqRewards then
        frame.questRewardHeader:ClearAllPoints()
        frame.questRewardHeader:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
        if #prereqRewardItems > 0 and prereqRewardChoice then
            frame.questRewardHeader:SetText("|cffffd36b" .. L("CHOOSE_ONE_REWARD") .. "|r")
        elseif #prereqRewardItems == 1 then
            frame.questRewardHeader:SetText("|cffffd36b" .. L("REWARD") .. "|r")
        else
            frame.questRewardHeader:SetText("|cffffd36b" .. L("REWARDS") .. "|r")
        end
        cursorY = cursorY + 22

        local rewardWidth = math.floor((detailWidth - 10) / 2)
        local buttonsUsed = 0
        -- Two-column grid of item cards; the fixed rewards of a choice quest
        -- get their own grid under "You will also receive".
        local function PlaceRewardGrid(list)
            local rowsUsed = 0
            for i, item in ipairs(list) do
                buttonsUsed = buttonsUsed + 1
                local button = questRewardButtons[buttonsUsed]
                if not button then
                    button = MakeQuestRewardButton(frame.questDetailContent)
                    questRewardButtons[buttonsUsed] = button
                end

                button:SetWidth(rewardWidth)
                button.item = item
                if FDJ.UpdateFavouriteIndicator then FDJ.UpdateFavouriteIndicator(button, item[1]) end
                button.icon:SetTexture(ItemIcon(item[1]))
                if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
                    pcall(C_Item.RequestLoadItemDataByID, item[1])
                end

                local itemName, itemLink, quality = ItemInfo(item[1])
                local r, g, b = GetAuthoritativeItemQuality(item[1], itemLink, quality, item[3] or 1)
                button.name:SetText((itemName or item[2]) .. ((type(item[4]) == "number" and item[4] > 1) and (" \195\151" .. item[4]) or "")) -- discscount (2.0.10): "×5"
                button.name:SetTextColor(r, g, b)
                local theme = THEMES[selectedDungeon] or THEMES["Hall of Thanes"]
                button:SetBackdropColor(unpack(theme.lootRow))
                button:SetBackdropBorderColor(unpack(theme.border))

                local col = (i - 1) % 2
                local row = math.floor((i - 1) / 2)
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT",
                    col * (rewardWidth + 10), -(cursorY + row * 54))
                button:Show()
                rowsUsed = math.max(rowsUsed, row + 1)
            end
            if rowsUsed > 0 then cursorY = cursorY + rowsUsed * 54 + 4 end
        end
        PlaceRewardGrid(prereqRewardItems)
        if #prereqAlsoItems > 0 and frame.questRewardAlsoHeader then
            frame.questRewardAlsoHeader:SetText(L("ALSO_RECEIVE"))
            frame.questRewardAlsoHeader:ClearAllPoints()
            frame.questRewardAlsoHeader:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
            frame.questRewardAlsoHeader:Show()
            cursorY = cursorY + (frame.questRewardAlsoHeader:GetStringHeight() or 18) + 4
            PlaceRewardGrid(prereqAlsoItems)
        end
        for i = buttonsUsed + 1, #questRewardButtons do
            local button = questRewardButtons[i]
            if button then
                button.item = nil
                button:Hide()
            end
        end

        local hasBar = false
        if frame.questXPReward and prereqXP and prereqXP > 0 then
            frame.questXPReward:ClearAllPoints()
            frame.questXPReward:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
            frame.questXPReward.text:SetText(FormatNumber(prereqXP) .. " XP")
            frame.questXPReward:Show()
            hasBar = true
        elseif frame.questXPReward then
            frame.questXPReward:Hide()
        end

        if frame.questMoneyReward and prereqMoney > 0 then
            frame.questMoneyReward:ClearAllPoints()
            if hasBar and frame.questXPReward then
                frame.questMoneyReward:SetPoint("LEFT", frame.questXPReward, "RIGHT", 8, 0)
            else
                frame.questMoneyReward:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
            end
            frame.questMoneyReward.text:SetText(FormatQuestMoney(prereqMoney))
            local moneyWidth = math.ceil((frame.questMoneyReward.text:GetStringWidth() or 0) + 16)
            frame.questMoneyReward:SetWidth(math.max(40, math.min(120, moneyWidth)))
            frame.questMoneyReward:Show()
            hasBar = true
        elseif frame.questMoneyReward then
            frame.questMoneyReward:Hide()
        end

        if hasBar then cursorY = cursorY + 32 end
    else
        frame.questRewardHeader:SetText("")
        if frame.questXPReward then frame.questXPReward:Hide() end
        if frame.questMoneyReward then frame.questMoneyReward:Hide() end
    end

    frame.questDetailContent:SetHeight(math.max(1, cursorY))
    FDJ.ApplyQuestDetailScroll("step:" .. tostring(selectedDungeon) .. ":" .. tostring(selectedPrereqParentQuestID) .. ":" .. tostring(step.id or step.name), cursorY)
    UpdateScrollBarVisibility(frame.questDetailScroll, cursorY)
    return true
end

RefreshQuestDetail = function()
    if FDJ.PlaceNoteImage then FDJ.PlaceNoteImage(nil) end -- noteimage: no picture left from the page before
    if FDJ.PlaceShowLocation then FDJ.PlaceShowLocation(false) end -- showlocation
    if FDJ.FactionLocked(selectedDungeon) then selectedQuestFaction = FDJ.PlayerFaction() end -- questrowtrial
    if FDJ.ApplyViewFaction then FDJ.ApplyViewFaction(selectedQuestFaction) end -- voodooview
    for _, button in ipairs(questRewardButtons) do HideSearchItemHighlight(button) end
    for _, button in ipairs(questNoteRewardButtons) do HideSearchItemHighlight(button) end
    if frame and frame.questNoteItemButton then HideSearchItemHighlight(frame.questNoteItemButton) end
    if not frame or not frame.questDetailText then return end
    if frame.questTurninMapButton then
        frame.questTurninMapButton.prereqLocation = nil
        frame.questTurninMapButton:Hide()
    end
    if frame.questRewardAlsoHeader then frame.questRewardAlsoHeader:Hide() end
    FDJ.PlaceDungeonStepLabel(false) -- dungeonstep: only a dungeon step's page shows it

    if selectedPrereqStep then
        if RefreshPrerequisiteQuestDetail(selectedPrereqStep) then return end
    end
    FDJ.HideStepItemButtons()
    if frame.questPrevStepButton then frame.questPrevStepButton:Hide() end
    if frame.questNextStepButton then frame.questNextStepButton:Hide() end

    local dungeon = DB[selectedDungeon]
    local quest = dungeon.quests and dungeon.quests[selectedQuest]
    if not quest or not QuestMatchesFaction(quest, selectedQuestFaction) then
        BuildVisibleQuestIndexes()
        quest = dungeon.quests and dungeon.quests[selectedQuest]
    end
    -- rpgpartial: a quest not unlocked yet shows nothing but how to unlock it.
    local rpgHiddenQuest = quest and QuestMatchesFaction(quest, selectedQuestFaction)
        and FDJ.RPGQuestHidden and FDJ.RPGQuestHidden(selectedDungeon, quest) or false
    if not quest or not QuestMatchesFaction(quest, selectedQuestFaction) or rpgHiddenQuest then
        frame.selectedQuestName:SetText(rpgHiddenQuest and "???" or L("NO_QUESTS"))
        frame.selectedQuestMeta:SetText("")
        if frame.selectedQuestClass then frame.selectedQuestClass:Hide() end
        if frame.selectedQuestClassIcon then frame.selectedQuestClassIcon:Hide() end
        if frame.selectedQuestMetaClassIcon then frame.selectedQuestMetaClassIcon:Hide() end
        frame.selectedQuestComplete:Hide()
        if frame.selectedQuestTurnIn then frame.selectedQuestTurnIn:Hide() end
        if frame.questShareButton then frame.questShareButton.questID = nil; frame.questShareButton:Hide() end
        if frame.questDetailScroll then frame.questDetailScroll:Hide() end
        if frame.noQuestMessage then
            frame.noQuestMessage:SetText(rpgHiddenQuest and L("RPG_QUEST_HIDDEN") or L((dungeon and dungeon.fullQuestsTBD) and "NO_FACTION_QUESTS_TBD" or "NO_FACTION_QUESTS", selectedQuestFaction))
            frame.noQuestMessage:Show()
        end
        frame.questDetailText:SetText("")
        if frame.questStartsText then frame.questStartsText:SetText("") end
        if frame.questNotesText then frame.questNotesText:SetText("") end
        if frame.questObjectiveHeader then frame.questObjectiveHeader:Hide() end
        if frame.questStartsHeader then frame.questStartsHeader:Hide() end
        if frame.questTurninHeader then frame.questTurninHeader:Hide() end
        if frame.questNotesHeader then frame.questNotesHeader:Hide() end
        FDJ.PlaceNoteImage(nil) -- noteimage
        FDJ.PlaceShowLocation(false) -- showlocation
        if frame.questMapButton then frame.questMapButton.quest = nil; frame.questMapButton:Hide() end
        if frame.questStartLinkButton then frame.questStartLinkButton.questID = nil; frame.questStartLinkButton:Hide() end
        if frame.questStartRequiresText then frame.questStartRequiresText:Hide() end
        if frame.questLeadsToButton then frame.questLeadsToButton.questID = nil; frame.questLeadsToButton:Hide() end
        if frame.questStartItemButton then frame.questStartItemButton.item = nil; frame.questStartItemButton:Hide() end
        if frame.questRequiredItemsHeader then frame.questRequiredItemsHeader:Hide() end
        if frame.questRequiredItemButton then frame.questRequiredItemButton.item = nil; frame.questRequiredItemButton:Hide() end
        if frame.questNoteItemButton then frame.questNoteItemButton.item = nil; frame.questNoteItemButton:Hide() end
        if frame.questStartDungeonIcon then frame.questStartDungeonIcon:Hide() end
        FDJ.PlaceStepHaveItRow(false) -- chainturnin
        FDJ.PlaceObjectiveMapButton(nil, 0) -- glowingshard
        FDJ.PlaceGuideButton(nil, 0) -- questguide
        FDJ.PlaceSummonHelp(nil, 0) -- summonhelp
        if FDJ.PlaceRepNeeds then FDJ.PlaceRepNeeds(nil, 0) end -- repneeds
        FDJ.SetHeaderDungeonIcon("questObjectiveDungeonIcon") -- insidequest
        FDJ.SetHeaderDungeonIcon("questTurninDungeonIcon")
        if frame.questTurninText then frame.questTurninText:SetText("") end
        frame.questRewardHeader:SetText("")
        if frame.questXPReward then frame.questXPReward:Hide() end
        if frame.questMoneyReward then frame.questMoneyReward:Hide() end
        frame.questRewardSummary:SetText("")
        if FDJ.LayoutRepPills then FDJ.LayoutRepPills({}, 0, 0) end
        for _, button in ipairs(questRewardButtons) do button.item = nil; button:Hide() end
        for _, button in ipairs(questNoteRewardButtons) do button.item = nil; button:Hide() end
        if frame.questAdditionalRewardButtons then
            for _, button in ipairs(frame.questAdditionalRewardButtons) do button.item = nil; button:Hide() end
        end
        frame.questDetailContent:SetHeight(1)
        return
    end

    if frame.questDetailScroll then frame.questDetailScroll:Show() end
    if frame.noQuestMessage then frame.noQuestMessage:Hide() end
    if frame.questStartDungeonIcon then frame.questStartDungeonIcon:Hide() end
    FDJ.PlaceStepHaveItRow(false) -- chainturnin

    local detailWidth = math.max(260, (frame.questDetailScroll:GetWidth() or 350) - 4)
    frame.questDetailContent:SetWidth(detailWidth)
    frame.questDetailText:SetWidth(detailWidth)
    if frame.questStartsText then frame.questStartsText:SetWidth(detailWidth) end
    if frame.questTurninText then frame.questTurninText:SetWidth(detailWidth) end
    if frame.questNotesText then frame.questNotesText:SetWidth(detailWidth) end
    local rewardWidth = math.floor((detailWidth - 10) / 2)
    local theme = THEMES[selectedDungeon] or THEMES["Hall of Thanes"]
    local complete = IsQuestFinished(quest.id)

    frame.selectedQuestName:SetText(QuestField(quest.id, "name", quest.name))
    frame.selectedQuestName:SetTextColor(1.00, 0.78, 0.16)
    -- notint (2.1.1): a dungeon's own quest keeps the plain page (only a
    -- dungeon chain step's page is tinted)
    FDJ.ShowDungeonFade(false)
    frame.selectedQuestName:SetShadowColor(0, 0, 0, 1)
    frame.selectedQuestName:SetShadowOffset(1, -1)

    local classLabel, classR, classG, classB, classToken = GetQuestClassRestriction(quest)
    if classLabel and frame.selectedQuestClass then
        frame.selectedQuestClass:SetText(classLabel)
        frame.selectedQuestClass:SetTextColor(classR, classG, classB)
        -- Light black edge so the class colour reads on the parchment: a
        -- solid one-pixel shadow (a full font outline looked too heavy).
        local font, size = frame.selectedQuestClass:GetFont()
        if font and size then frame.selectedQuestClass:SetFont(font, size, "") end
        frame.selectedQuestClass:SetShadowColor(0, 0, 0, 1)
        frame.selectedQuestClass:SetShadowOffset(1, -1)
        frame.selectedQuestClass:Show()

        if frame.selectedQuestClassIcon then
            SetQuestRestrictionIcon(frame.selectedQuestClassIcon, classToken)
            -- Centre the icon under the words themselves, not under the
            -- (wider, right-aligned) text box.
            local textWidth = math.min(frame.selectedQuestClass:GetStringWidth() or 0,
                frame.selectedQuestClass:GetWidth() or 118)
            frame.selectedQuestClassIcon:ClearAllPoints()
            -- classicons (2.1.0): a second class's icon right of the first,
            -- the pair centred under the words.
            local other = select(6, GetQuestClassRestriction(quest))
            other = type(other) == "table" and other[1] or nil
            if other and not frame.selectedQuestClassIcon2 then
                frame.selectedQuestClassIcon2 = frame.selectedQuestClassIcon:GetParent():CreateTexture(nil, "OVERLAY")
                frame.selectedQuestClassIcon2:SetSize(frame.selectedQuestClassIcon:GetWidth(), frame.selectedQuestClassIcon:GetHeight())
            end
            if other then
                frame.selectedQuestClassIcon:SetPoint("TOP", frame.selectedQuestClass, "BOTTOMRIGHT", -textWidth / 2 - (frame.selectedQuestClassIcon:GetWidth() + 3) / 2, -3)
                SetQuestRestrictionIcon(frame.selectedQuestClassIcon2, other)
                frame.selectedQuestClassIcon2:ClearAllPoints()
                frame.selectedQuestClassIcon2:SetPoint("LEFT", frame.selectedQuestClassIcon, "RIGHT", 3, 0)
                frame.selectedQuestClassIcon2:Show()
            else
                frame.selectedQuestClassIcon:SetPoint("TOP", frame.selectedQuestClass, "BOTTOMRIGHT", -textWidth / 2, -3)
                if frame.selectedQuestClassIcon2 then frame.selectedQuestClassIcon2:Hide() end
            end
            frame.selectedQuestClassIcon:Show()
        end

        frame.selectedQuestComplete:ClearAllPoints()
        frame.selectedQuestComplete:SetPoint("RIGHT", frame.selectedQuestClass, "LEFT", -6, 0)
    else
        if frame.selectedQuestClass then frame.selectedQuestClass:Hide() end
        if frame.selectedQuestClassIcon then frame.selectedQuestClassIcon:Hide() end
        if frame.selectedQuestClassIcon2 then frame.selectedQuestClassIcon2:Hide() end -- classicons
        frame.selectedQuestComplete:ClearAllPoints()
        frame.selectedQuestComplete:SetPoint("TOPRIGHT", frame.questTextInset, "TOPRIGHT", -16, -11)
    end

    local shareTitleInset = FDJ.UpdateQuestShareButton(quest.id, classLabel)
    frame.selectedQuestName:ClearAllPoints()
    frame.selectedQuestName:SetPoint("TOPLEFT", frame.questTextInset, "TOPLEFT", 16, -15)
    frame.selectedQuestName:SetPoint("RIGHT", frame.questTextInset, "RIGHT", -shareTitleInset, 0)

    frame.selectedQuestMeta:SetText(
        L("AVAILABLE_FROM_LEVEL", FDJ.QuestLevelText(quest.requires, true)) -- (redlevel)
        .. "     " .. FactionLabel(quest.faction)

    )
    frame.selectedQuestMeta:SetTextColor(0.25, 0.16, 0.08)

    if frame.selectedQuestMetaClassIcon then
        frame.selectedQuestMetaClassIcon:Hide()
    end

    -- Keep multi-line quest titles and faction icons above the body separator.
    local headerHeight = math.max(classLabel and 78 or 58, 15 + frame.selectedQuestName:GetStringHeight()
        + 5 + math.max(24, frame.selectedQuestMeta:GetStringHeight()) + 8)
    frame.questHeaderSeparator:ClearAllPoints()
    frame.questHeaderSeparator:SetPoint("TOPLEFT", 14, -headerHeight)
    frame.questHeaderSeparator:SetPoint("TOPRIGHT", -14, -headerHeight)
    frame.questDetailScroll:ClearAllPoints()
    frame.questDetailScroll:SetPoint("TOPLEFT", 16, -(headerHeight + 14))
    frame.questDetailScroll:SetPoint("BOTTOMRIGHT", -31, 16)

    if frame.selectedQuestComplete then
        local ready = complete and not FDJ.QuestTurnedIn(quest.id)
        frame.selectedQuestComplete:SetShown(complete and not (ready and frame.selectedQuestTurnIn))
        if frame.selectedQuestTurnIn then
            FDJ.SetTurnInButton(frame.selectedQuestTurnIn, ready and quest or nil, QuestField(quest.id, "name", quest.name))
        end
    end

    -- Keep the body text identical to Blizzard's parchment quest text. Only
    -- the section labels use white outlined text for visibility.
    local cursorY = 0

    local function PlaceHeader(header, y)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -y)
        header:Show()
        return y + math.max(14, header:GetStringHeight() or 14) + 3
    end

    -- Optional red disclaimer shown first, right under the title area.
    if quest.warning and quest.warning ~= "" then
        if not frame.questWarningText then
            frame.questWarningText = frame.questDetailContent:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
            frame.questWarningText:SetJustifyH("LEFT")
        end
        frame.questWarningText:ClearAllPoints()
        frame.questWarningText:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
        frame.questWarningText:SetWidth(math.max(120, (frame.questDetailContent:GetWidth() or 360) - 8))

        -- Quest warnings can have quest-specific localized text (for example
        -- Baron Aquanis). Prefer the localized quest field first, then fall back
        -- to generic free-text localization.
        local warningText = QuestField(quest.id, "warning", quest.warning)
        -- Rig Wars warning contains quest titles. Build it from the localized
        -- client/addon quest names so the titles never remain in English on
        -- non-English clients.
        -- Blackfathom Villainy (Alliance): with In Search of Thaelrid's title.
        if quest.id == 1200 then
            local template = FreeText("Warning: Accept after completing %s, or you will lose that quest.")
            local ok, formatted = pcall(string.format, template, GetLoadedQuestTitle(1198, "In Search of Thaelrid"))
            if ok and type(formatted) == "string" and formatted ~= "" then
                warningText = formatted
            end
        end
        -- In Search of Thaelrid: same, with Blackfathom Villainy's title.
        if quest.id == 1198 then
            local template = FreeText("Warning: if not completed before accepting %s, this quest becomes unavailable.")
            local ok, formatted = pcall(string.format, template, GetLoadedQuestTitle(1200, "Blackfathom Villainy"))
            if ok and type(formatted) == "string" and formatted ~= "" then
                warningText = formatted
            end
        end
        if quest.id == 2841 then
            local template = FreeText("Accept %s before %s. If %s disappears, abandon %s and it will reappear.")
            local rigWarsTitle = GetLoadedQuestTitle(2841, "Rig Wars")
            local scootyTitle = GetLoadedQuestTitle(2842, "Chief Engineer Scooty")
            local ok, formatted = pcall(string.format, template, rigWarsTitle, scootyTitle, rigWarsTitle, scootyTitle)
            if ok and type(formatted) == "string" and formatted ~= "" then
                warningText = formatted
            end
        end
        frame.questWarningText:SetText(warningText)
        FDJ.WarningFont(frame.questWarningText) -- warnfont: its font and colour (Core/Fonts.lua)
        frame.questWarningText:Show()
        cursorY = cursorY + (frame.questWarningText:GetStringHeight() or 28) + 10
    elseif frame.questWarningText then
        frame.questWarningText:Hide()
    end
    cursorY = FDJ.PlaceGuideButton(quest, cursorY) -- questguide: How to complete
    cursorY = FDJ.PlaceSummonHelp(quest, cursorY) -- summonhelp: How to summon
    if FDJ.PlaceRepNeeds then cursorY = FDJ.PlaceRepNeeds(quest, cursorY) end -- repneeds: reputation needed

    cursorY = PlaceHeader(frame.questObjectiveHeader, cursorY)
    -- insidequest: done and handed in inside the dungeon.
    FDJ.SetHeaderDungeonIcon("questObjectiveDungeonIcon", frame.questObjectiveHeader,
        quest.objectiveInDungeon ~= false and FDJ.TurnInInsideDungeon(quest.turnin, selectedDungeon)) -- (malletone: false by hand)
    frame.questDetailText:ClearAllPoints()
    frame.questDetailText:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
    -- Real quest text from the game when known (see Systems/QuestText.lua).
    if FDJ.QuestPageText then
        frame.fdjObjText, frame.fdjDescText = FDJ.QuestPageText(quest.id, QuestField(quest.id, "objective", quest.objective))
    else
        frame.fdjObjText, frame.fdjDescText = QuestField(quest.id, "objective", quest.objective), nil
    end
    frame.questDetailText:SetText(frame.fdjObjText)
    frame.questDetailText:SetTextColor(0.10, 0.065, 0.025)
    cursorY = cursorY + (frame.questDetailText:GetStringHeight() or 30) + 13
    -- objnote (2.0.13, M 19 Nov 2026, The Coldbringer's Eye: "a little
    -- disclaimer text below the objective ... so that we are safe and they
    -- see it"): quest.objectiveNote, in red under the objective and its
    -- progress lines. (No new local: frame fields only.)
    if type(quest.objectiveNote) == "string" and quest.objectiveNote ~= "" then
        if not frame.questObjectiveNoteText then
            frame.questObjectiveNoteText = frame.questDetailContent:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal") -- (the warning's size: Small was too small, M 19 Nov 2026)
            frame.questObjectiveNoteText:SetJustifyH("LEFT")
        end
        frame.questObjectiveNoteText:ClearAllPoints()
        frame.questObjectiveNoteText:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -(cursorY - 6))
        frame.questObjectiveNoteText:SetWidth(math.max(120, (frame.questDetailContent:GetWidth() or 360) - 8))
        frame.questObjectiveNoteText:SetText(QuestField(quest.id, "objectiveNote", quest.objectiveNote))
        FDJ.WarningFont(frame.questObjectiveNoteText) -- warnfont: its font and colour (Core/Fonts.lua)
        frame.questObjectiveNoteText:Show()
        cursorY = cursorY - 6 + (frame.questObjectiveNoteText:GetStringHeight() or 14) + 13
    elseif frame.questObjectiveNoteText then
        frame.questObjectiveNoteText:Hide()
    end
    cursorY = FDJ.PlaceObjectiveMapButton(quest, cursorY) -- glowingshard
    if FDJ.PlaceQuestDescription then cursorY = FDJ.PlaceQuestDescription(frame, frame.fdjDescText, cursorY, PlaceHeader) end

    -- Normal dungeon-quest required items use field 5 for Journal-only source
    -- information (field 4 is the stack count). Only render the large item card
    -- when that source information is actually useful to the player.
    if quest.requiredItem and type(quest.requiredItem[5]) == "string" and quest.requiredItem[5] ~= "" and frame.questRequiredItemButton then
        cursorY = PlaceHeader(frame.questRequiredItemsHeader, cursorY)
        frame.questRequiredItemButton.item = quest.requiredItem
        frame.questRequiredItemButton.fdjMapLocation = FDJ.MapQuestItemSpot and FDJ.MapQuestItemSpot(quest.id, quest.requiredItem[1]) or nil -- mapquests
        frame.questRequiredItemButton.fdjSourceText = FDJ.BossDropText and FDJ.BossDropText(quest.requiredItem[1]) or FreeText(quest.requiredItem[5])
        frame.questRequiredItemButton:SetWidth(math.min(260, rewardWidth))
        frame.questRequiredItemButton.icon:SetTexture(ItemIcon(quest.requiredItem[1]))
        if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
            pcall(C_Item.RequestLoadItemDataByID, quest.requiredItem[1])
        end
        do
            local itemName, itemLink, quality = ItemInfo(quest.requiredItem[1])
            local r, g, b = GetAuthoritativeItemQuality(quest.requiredItem[1], itemLink, quality, quest.requiredItem[3] or 1)
            local countText = quest.requiredItem[4] and quest.requiredItem[4] > 1 and (" ×" .. tostring(quest.requiredItem[4])) or ""
            frame.questRequiredItemButton.name:SetText((itemName or quest.requiredItem[2] or L("ITEM")) .. countText)
            frame.questRequiredItemButton.name:SetTextColor(r, g, b)
        end
        frame.questRequiredItemButton:SetBackdropColor(unpack(theme.lootRow))
        frame.questRequiredItemButton:SetBackdropBorderColor(unpack(theme.border))
        frame.questRequiredItemButton:ClearAllPoints()
        frame.questRequiredItemButton:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
        frame.questRequiredItemButton:Show()
        cursorY = cursorY + 54
    else
        if frame.questRequiredItemsHeader then frame.questRequiredItemsHeader:Hide() end
        if frame.questRequiredItemButton then
            frame.questRequiredItemButton.item = nil
            frame.questRequiredItemButton.fdjSourceText = nil
            frame.questRequiredItemButton.fdjMapLocation = nil -- mapquests
            frame.questRequiredItemButton:Hide()
        end
    end

    -- Several required items, each with where it comes from (for example
    -- the three Seal of Ascension gemstones): same cards as on chain steps.
    local questRequiredList = quest.requiredItems
    if questRequiredList and #questRequiredList > 0 and frame.questRequiredItemsHeader then
        cursorY = PlaceHeader(frame.questRequiredItemsHeader, cursorY)
        cursorY = FDJ.PlaceStepItemButtons(questRequiredList, 0, cursorY, math.min(300, detailWidth)) + 8
    end
    FDJ.PlaceItemLocationHint(quest.noteImage, true) -- itemhint (hintalways)

    -- Some Forever quests provide an item when accepted (for example the
    -- Dalaran Sewer Key for Heart of Disruption). Render it just like a
    -- prerequisite-step provided item so the journal mirrors Blizzard's log.
    if quest.providedItem and frame.questProvidedItemHeader then
        frame.questProvidedItemHeader:ClearAllPoints()
        frame.questProvidedItemHeader:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
        frame.questProvidedItemHeader:Show()
        cursorY = cursorY + (frame.questProvidedItemHeader:GetStringHeight() or 18) + 4
        cursorY = FDJ.PlaceStepItemButtons({ quest.providedItem }, (questRequiredList and #questRequiredList) or 0, cursorY, math.min(300, detailWidth)) + 8
    elseif frame.questProvidedItemHeader then
        frame.questProvidedItemHeader:Hide()
    end

    frame.fdjStartsY = cursorY -- malletone: where Starts at begins
    frame.questStartsHeader:SetText(L("STARTS_AT")) -- a step page may have set "Obtain"
    cursorY = PlaceHeader(frame.questStartsHeader, cursorY)
    frame.questStartsText:ClearAllPoints()
    frame.questStartItemButton:ClearAllPoints()

    if quest.startObject and not quest.startItem then
        -- Quest started by a world object (not an item): same button as a
        -- quest-start item, with a plain tooltip saying where the object is.
        -- startObject = {name, icon texture, where to find it}
        local obj = quest.startObject
        frame.questStartsText:SetText("")
        frame.questStartsText:Hide()
        frame.questStartItemButton.item = nil
        frame.questStartItemButton.fdjSourceText = nil
        frame.questStartItemButton.fdjObject = { FreeText(obj[1]), FreeText(obj[3]) }
        frame.questStartItemButton.icon:SetTexture(obj[2] or "Interface\\Icons\\INV_Misc_QuestionMark")
        frame.questStartItemButton.name:SetText(FreeText(obj[1]))
        frame.questStartItemButton.name:SetTextColor(1.00, 1.00, 1.00)
        frame.questStartItemButton:SetBackdropColor(unpack(theme.lootRow))
        frame.questStartItemButton:SetBackdropBorderColor(unpack(theme.border))
        frame.questStartItemButton:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
        frame.questStartItemButton:Show()
        if frame.questStartDungeonIcon then
            frame.questStartDungeonIcon:Hide()
            if quest.startsInDungeon or ((FDJ.StartsInsideDungeon(quest.pickup) or FDJ.StartItemDropsIn(quest, selectedDungeon))
                and not FDJ.PrereqChainOf(quest.id)) then FDJ.PositionInDungeonIcon() end
        end
        cursorY = cursorY + 44
    elseif quest.startItem then
        frame.questStartsText:SetText("")
        frame.questStartsText:Hide()

        local startItem = quest.startItem
        frame.questStartItemButton.fdjObject = nil
        frame.questStartItemButton.item = startItem
        frame.questStartItemButton.fdjSourceText = FDJ.BossDropText and FDJ.BossDropText(startItem[1]) or FreeText(startItem[4])
        frame.questStartItemButton.icon:SetTexture(ItemIcon(startItem[1]))
        local itemName = ItemInfo(startItem[1])
        frame.questStartItemButton.name:SetText(itemName or startItem[2])
        -- Quest-start items use white text in the journal regardless of item quality.
        frame.questStartItemButton.name:SetTextColor(1.00, 1.00, 1.00)
        frame.questStartItemButton:SetBackdropColor(unpack(theme.lootRow))
        frame.questStartItemButton:SetBackdropBorderColor(unpack(theme.border))
        frame.questStartItemButton:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
        frame.questStartItemButton:Show()
        if frame.questStartDungeonIcon then
            frame.questStartDungeonIcon:Hide()
            if quest.startsInDungeon or ((FDJ.StartsInsideDungeon(quest.pickup) or FDJ.StartItemDropsIn(quest, selectedDungeon))
                and not FDJ.PrereqChainOf(quest.id)) then FDJ.PositionInDungeonIcon() end
        end
        cursorY = cursorY + 44
    else
        frame.questStartItemButton.item = nil
        frame.questStartItemButton.fdjSourceText = nil
        frame.questStartItemButton:Hide()
        frame.questStartsText:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
        local pickupText = QuestField(quest.id, "pickup", quest.pickup)
        frame.questStartsText:SetText(pickupText)
        frame.questStartsText:SetTextColor(0.10, 0.065, 0.025)
        frame.questStartsText:Show()
        if frame.questStartDungeonIcon then
            frame.questStartDungeonIcon:Hide()
            if quest.startsInDungeon or (FDJ.StartsInsideDungeon(pickupText) and not FDJ.PrereqChainOf(quest.id)) then
                FDJ.PositionInDungeonIcon()
            end
        end
        cursorY = cursorY + (frame.questStartsText:GetStringHeight() or 30) + 8
    end

    local loc = quest.startMap or QUEST_START_MAPS[quest.id]
    local hasChain = FDJ.PrereqChainOf(quest.id) ~= nil -- questguide: not for guide quests

    frame.questMapButton:ClearAllPoints()
    frame.questMapButton.fdjCustomLabel = nil
    frame.questMapButton.prereqLocation = quest.startMap
    frame.questMapButton.quest = quest
    if frame.questMapButton.icon then frame.questMapButton.icon:Hide() end

    if frame.questStartLinkButton then
        frame.questStartLinkButton.questID = nil
        frame.questStartLinkButton:Hide()
    end
    if frame.questStartRequiresText then frame.questStartRequiresText:Hide() end
    if frame.questLeadsToButton then
        frame.questLeadsToButton.questID = nil
        frame.questLeadsToButton:Hide()
    end

    -- Render a direct link to the previous quest AFTER reset/cleanup.
    if quest.startQuestLink and frame.questStartLinkButton then
        -- leadinrequires: under Starts at, the lead-in named in a line of
        -- its own ("Requires: In Search of Thaelrid"), then its button.
        if not frame.questStartRequiresText then
            frame.questStartRequiresText = frame.questDetailContent:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
            frame.questStartRequiresText:SetJustifyH("LEFT")
        end
        local requires = frame.questStartRequiresText
        requires:ClearAllPoints()
        requires:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
        requires:SetWidth(math.max(120, (frame.questDetailContent:GetWidth() or 360) - 8))
        requires:SetText(L("REQUIRES_QUEST", QuestField(quest.startQuestLink.id, "name", quest.startQuestLink.name or L("PREVIOUS_QUEST"))))
        FDJ.WarningFont(requires) -- warnfont: its font and colour (Core/Fonts.lua)
        requires:Show()
        cursorY = cursorY + (requires:GetStringHeight() or 14) + 6
        frame.questStartLinkButton:ClearAllPoints()
        frame.questStartLinkButton.questID = quest.startQuestLink.id
        frame.questStartLinkButton:SetText(QuestField(quest.startQuestLink.id, "name", quest.startQuestLink.name or L("PREVIOUS_QUEST")))
        frame.questStartLinkButton:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
        frame.questStartLinkButton:Show()
        cursorY = cursorY + 31
    end

    if frame.questChainButton then
        frame.questChainButton:ClearAllPoints()
        frame.questChainButton.questID = hasChain and quest.id or nil
        frame.questChainButton.parentQuestName = hasChain and quest.name or nil
    end

    -- Chain awareness: while an earlier step of the chain is still open, say so
    -- and lead with the chain button. Show on Map still points at this quest.
    local pendingStep, pendingIndex, chainLength
    if hasChain and not IsQuestInLog(quest.id) and not FDJ.QuestTurnedIn(quest.id) then
        local chain = QUEST_PREREQ_CHAINS[quest.id]
        chainLength = #chain
        for i, step in ipairs(chain) do
            if step.id and not FDJ.QuestTurnedIn(step.id) then
                if step.id ~= quest.id then pendingStep, pendingIndex = step, i end
                break
            end
        end
    end
    if hasChain then
        if not frame.questChainNotice then
            frame.questChainNotice = frame.questDetailContent:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
            frame.questChainNotice:SetJustifyH("LEFT")
        end
        frame.questChainNotice:ClearAllPoints()
        frame.questChainNotice:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
        frame.questChainNotice:SetWidth(math.max(120, (frame.questDetailContent:GetWidth() or 360) - 8))
        -- Only name a step once the chain is under way: an earlier step is
        -- turned in, or the open step is in the quest log.
        local noticeText = L("CHAIN_REQUIRED")
        if pendingStep and (pendingIndex > 1 or IsQuestInLog(pendingStep.id)) then
            -- choicestep (2.0.37): a choice of quests counts as one step.
            local chain = QUEST_PREREQ_CHAINS[quest.id]
            noticeText = noticeText .. " " .. L("CHAIN_STEP", FDJ.ChainStepNumber(chain, pendingIndex), FDJ.ChainStepNumber(chain, chainLength))
        end
        frame.questChainNotice:SetText(noticeText)
        FDJ.WarningFont(frame.questChainNotice) -- warnfont: its font and colour (Core/Fonts.lua)
        frame.questChainNotice:Show()
        cursorY = cursorY + (frame.questChainNotice:GetStringHeight() or 14) + 8
        if not pendingStep then frame.questMapButton.fdjLabelKey = nil end
    else
        frame.questMapButton.fdjLabelKey = nil
        if frame.questChainNotice then frame.questChainNotice:Hide() end
    end

    UpdateQuestActionButtonSizes()

    local showMap = loc and not quest.startItem
    if FDJ.MapMarkers and FDJ.MapMarkers.ConfigureTargetAndMarkAction then
        frame.questMapButton.fdjQuestTitle = QuestField(quest.id, "name", quest.name)
        frame.questMapButton.fdjQuestID = quest.id -- autoclear
        FDJ.MapMarkers.ConfigureTargetAndMarkAction(frame.questMapButton, showMap and loc or nil, true)
    end
    -- Show Quest Chain always comes first, then Show on Map.
    local chainShown = (pendingStep or hasChain) and frame.questChainButton
    if chainShown then
        frame.questChainButton:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
        frame.questChainButton:Show()
    elseif frame.questChainButton then
        frame.questChainButton:Hide()
    end
    if showMap then
        if chainShown then
            frame.questMapButton:SetPoint("LEFT", frame.questChainButton, "RIGHT", 8, 0)
        else
            frame.questMapButton:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
        end
        frame.questMapButton:Show()
    else
        frame.questMapButton:Hide()
    end

    if showMap or hasChain then
        cursorY = cursorY + 31
    end
    -- malletone (2.1.3, M 21 Nov 2026: "it's not really a pickup"): a quest
    -- that is not picked up (quest.noPickUp: the Mallet of Zul'Farrak) has
    -- no Starts at, nor its Show on Map / Show Quest Chain.
    if quest.noPickUp then
        for _, key in ipairs({ "questStartsHeader", "questStartsText", "questStartItemButton", "questStartDungeonIcon", "questMapButton",
            "questChainButton", "questChainNotice", "questStartLinkButton", "questStartRequiresText" }) do
            if frame[key] then frame[key]:Hide() end
        end
        cursorY = frame.fdjStartsY or cursorY
    end

    cursorY = PlaceHeader(frame.questTurninHeader, cursorY)
    FDJ.SetHeaderDungeonIcon("questTurninDungeonIcon", frame.questTurninHeader,
        FDJ.TurnInInsideDungeon(quest.turnin, selectedDungeon)) -- insidequest
    frame.questTurninText:ClearAllPoints()
    frame.questTurninText:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
    frame.questTurninText:SetText(QuestField(quest.id, "turnin", quest.turnin))
    frame.questTurninText:SetTextColor(0.10, 0.065, 0.025)
    frame.questTurninText:Show()
    cursorY = cursorY + (frame.questTurninText:GetStringHeight() or 24)

    for _, button in ipairs(questNoteRewardButtons) do
        button.item = nil
        button:Hide()
    end

    -- FDJ_BREADCRUMB_LINK_FILTER: hide an optional-introduction link whose quest is for the other
    -- faction or another class (e.g. an Alliance-only referral on a quest both factions can take).
    local noteQuestLink = quest.noteQuestLink
    local noteText = quest.note
    if noteQuestLink and noteQuestLink.id then
        local linked
        for _, other in ipairs((DB[selectedDungeon] and DB[selectedDungeon].quests) or {}) do
            if other.id == noteQuestLink.id then linked = other break end
        end
        -- Compare with the faction tab being browsed, not the character's faction.
        local viewFaction = selectedQuestFaction
        if linked and (viewFaction == "Alliance" or viewFaction == "Horde")
            and not QuestMatchesFaction(linked, viewFaction) then
            noteQuestLink = nil
            if type(noteText) == "string" then
                noteText = noteText:gsub("%s*Optional introductory quest:%s*$", "")
            end
        end
    end
    if (noteText and noteText ~= "") or quest.leadsToQuestLink or noteQuestLink or quest.noteImage then -- noteimage
        cursorY = cursorY + 13
        cursorY = PlaceHeader(frame.questNotesHeader, cursorY)

        if noteText and noteText ~= "" then
            frame.questNotesText:ClearAllPoints()
            frame.questNotesText:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
            frame.questNotesText:SetText(noteText == quest.note and QuestField(quest.id, "note", quest.note) or noteText)
            frame.questNotesText:SetTextColor(0.10, 0.065, 0.025)
            frame.questNotesText:Show()
            cursorY = cursorY + (frame.questNotesText:GetStringHeight() or 24)
        else
            frame.questNotesText:SetText("")
            frame.questNotesText:Hide()
        end

        local noteLink = noteQuestLink
        local leadsLink = quest.leadsToQuestLink
        if (noteLink or leadsLink) and frame.questLeadsToButton then
            if noteText and noteText ~= "" then cursorY = cursorY + 7 end
            local link = noteLink or leadsLink
            frame.questLeadsToButton:ClearAllPoints()
            frame.questLeadsToButton.questID = link.id
            frame.questLeadsToButton.questDungeon = link.dungeon -- leadsdungeon (2.0.13): a next step on another dungeon's page
            if noteLink then
                -- Optional/breadcrumb quest links in Notes show the localized
                -- quest title itself instead of implying a required chain.
                frame.questLeadsToButton:SetText(GetLoadedQuestTitle(link.id, link.name or L("QUEST")))
            else
                frame.questLeadsToButton:SetText(L("LEADS_TO", QuestField(link.id, "name", link.name or L("NEXT_QUEST"))))
            end
            frame.questLeadsToButton:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
            frame.questLeadsToButton:Show()
            cursorY = cursorY + 31
        elseif frame.questLeadsToButton then
            frame.questLeadsToButton.questID = nil
            frame.questLeadsToButton:Hide()
        end

        if quest.noteItem then
            cursorY = cursorY + 7
            local noteItem = quest.noteItem
            frame.questNoteItemButton.item = noteItem
            frame.questNoteItemButton.fdjSourceText = FDJ.BossDropText and FDJ.BossDropText(noteItem[1]) or FreeText(noteItem[4])
            frame.questNoteItemButton.mapLocation = quest.noteItemMap
                or (FDJ.MapQuestItemSpot and FDJ.MapQuestItemSpot(quest.id, noteItem[1])) or nil -- mapquests
            frame.questNoteItemButton.icon:SetTexture(ItemIcon(noteItem[1]))
            local itemName = ItemInfo(noteItem[1])
            frame.questNoteItemButton.name:SetText(itemName or noteItem[2])
            -- Quest-related note items use white text in the journal.
            frame.questNoteItemButton.name:SetTextColor(1.00, 1.00, 1.00)
            frame.questNoteItemButton:SetBackdropColor(unpack(theme.lootRow))
            frame.questNoteItemButton:SetBackdropBorderColor(unpack(theme.border))
            frame.questNoteItemButton:ClearAllPoints()
            frame.questNoteItemButton:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -cursorY)
            frame.questNoteItemButton:Show()
            cursorY = cursorY + 38
        else
            frame.questNoteItemButton.item = nil
            frame.questNoteItemButton.fdjSourceText = nil
            frame.questNoteItemButton.mapLocation = nil
            frame.questNoteItemButton:Hide()
        end

        local noteRewardItems = quest.noteRewardItems or {}
        if #noteRewardItems > 0 then
            cursorY = cursorY + 7
            local noteRewardWidth = math.floor((detailWidth - 10) / 2)
            local rowsUsed = 0
            for i, noteRewardItem in ipairs(noteRewardItems) do
                local button = questNoteRewardButtons[i]
                if not button then
                    button = MakeQuestNoteRewardButton(frame.questDetailContent)
                    questNoteRewardButtons[i] = button
                end

                button:SetWidth(noteRewardWidth)
                button.item = noteRewardItem
                button.icon:SetTexture(ItemIcon(noteRewardItem[1]))
                if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
                    pcall(C_Item.RequestLoadItemDataByID, noteRewardItem[1])
                end

                local itemName, itemLink, quality = ItemInfo(noteRewardItem[1])
                local r, g, b = GetAuthoritativeItemQuality(
                    noteRewardItem[1],
                    itemLink,
                    quality,
                    noteRewardItem[3] or 1
                )
                button.name:SetText(itemName or noteRewardItem[2] or "Item")
                button.name:SetTextColor(r, g, b)
                button:SetBackdropColor(unpack(theme.lootRow))
                button:SetBackdropBorderColor(unpack(theme.border))

                local col = (i - 1) % 2
                local row = math.floor((i - 1) / 2)
                button:ClearAllPoints()
                button:SetPoint(
                    "TOPLEFT",
                    frame.questDetailContent,
                    "TOPLEFT",
                    col * (noteRewardWidth + 10),
                    -(cursorY + row * 54)
                )
                button:Show()
                rowsUsed = math.max(rowsUsed, row + 1)
            end
            cursorY = cursorY + rowsUsed * 54
        end
        if quest.noteImage then cursorY = cursorY + 7 end
        cursorY = FDJ.PlaceNoteImage(quest.noteImage, cursorY) -- noteimage
    else
        frame.questNotesHeader:Hide()
        frame.questNotesText:SetText("")
        frame.questNotesText:Hide()
        FDJ.PlaceNoteImage(nil)
        frame.questNoteItemButton.item = nil
        frame.questNoteItemButton.fdjSourceText = nil
        frame.questNoteItemButton.mapLocation = nil
        frame.questNoteItemButton:Hide()
    end

    if frame.questAdditionalRewardButtons then
        for _, button in ipairs(frame.questAdditionalRewardButtons) do
            button.item = nil
            button:Hide()
        end
    end
    if frame.questAlsoReceiveHeader then frame.questAlsoReceiveHeader:Hide() end

    local rewardY = cursorY + 22
    local rewardItems = quest.rewardItems or {}

    frame.questRewardHeader:ClearAllPoints()
    frame.questRewardHeader:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -rewardY)

    if quest.rewardHeader and quest.rewardHeader ~= "" then
        frame.questRewardHeader:SetText("|cffffd36b" .. quest.rewardHeader .. "|r")
    elseif #rewardItems > 0 then
        if quest.rewardChoice and #rewardItems > 1 then
            frame.questRewardHeader:SetText("|cffffd36b" .. L("CHOOSE_ONE_REWARD") .. "|r")
        else
            -- 2.0.47: several items all given: "Rewards".
            frame.questRewardHeader:SetText("|cffffd36b" .. L(#rewardItems > 1 and "REWARDS" or "REWARD") .. "|r")
        end
    else
        frame.questRewardHeader:SetText("|cffffd36b" .. L("REWARDS") .. "|r")
    end

    local firstRewardY = rewardY + 20
    local rowsUsed = 0

    for i = 1, math.max(#questRewardButtons, #rewardItems) do
        local button = questRewardButtons[i]

        if i <= #rewardItems then
            if not button then
                button = MakeQuestRewardButton(frame.questDetailContent)
                questRewardButtons[i] = button
            end

            button:SetWidth(rewardWidth)
            local item = rewardItems[i]
            button.item = item
            if FDJ.UpdateFavouriteIndicator then FDJ.UpdateFavouriteIndicator(button, item[1]) end
            button.icon:SetTexture(item[5] or ItemIcon(item[1]))
            if item[1] and item[1] > 0 and C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
                pcall(C_Item.RequestLoadItemDataByID, item[1])
            end

            local itemName, itemLink, quality
            if item[1] and item[1] > 0 then itemName, itemLink, quality = ItemInfo(item[1]) end
            local r, g, b
            if item[1] and item[1] > 0 then
                r, g, b = GetAuthoritativeItemQuality(item[1], itemLink, quality, item[3] or 3)
            else
                r, g, b = QualityColor(item[3] or 3)
            end
            button.name:SetText((itemName or item[2]) .. ((type(item[4]) == "number" and item[4] > 1) and (" \195\151" .. item[4]) or "")) -- discscount (2.0.10): "×5"
            button.name:SetTextColor(r, g, b)
            button:SetBackdropColor(unpack(theme.lootRow))
            button:SetBackdropBorderColor(unpack(theme.border))

            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            button:ClearAllPoints()
            button:SetPoint(
                "TOPLEFT",
                frame.questDetailContent,
                "TOPLEFT",
                col * (rewardWidth + 10),
                -(firstRewardY + row * 54)
            )
            button:Show()
            rowsUsed = math.max(rowsUsed, row + 1)
        elseif button then
            button.item = nil
            button:Hide()
        end
    end

    local summaryY = firstRewardY
    if #rewardItems > 0 then
        summaryY = firstRewardY + rowsUsed * 54 + 4
    end

    local xp = GetLiveQuestXP(quest)
    local money = GetQuestRewardMoneyCopper(quest)
    local hasRewardBar = false

    -- Same layout as the in-game quest window: "Choose one of these rewards"
    -- for the choice items, then "You will also receive:" above the XP,
    -- money and any items everyone gets.
    local hasExtras = (xp and xp > 0) or (money and money > 0)
        or (quest.additionalRewardItems and #quest.additionalRewardItems > 0)
    -- This header is only meaningful when the quest first offers a choice
    -- reward and then has additional rewards below it. Always hide the reused
    -- font string first so it cannot leak from the previously viewed quest.
    if frame.questAlsoReceiveHeader then
        frame.questAlsoReceiveHeader:Hide()
    end
    if quest.rewardChoice and #rewardItems > 1 and hasExtras then
        if not frame.questAlsoReceiveHeader then
            frame.questAlsoReceiveHeader = frame.questDetailContent:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontBlack")
            frame.questAlsoReceiveHeader:SetJustifyH("LEFT")
        end
        frame.questAlsoReceiveHeader:SetText(L("ALSO_RECEIVE"))
        frame.questAlsoReceiveHeader:ClearAllPoints()
        frame.questAlsoReceiveHeader:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -summaryY)
        frame.questAlsoReceiveHeader:Show()
        summaryY = summaryY + 20
    end

    local showXP = xp and (xp > 0 or (xp == 0 and quest.showZeroXP))
    -- itemsfirst (2.0.10, M 17 Nov 2026: "I wanted the item not to be below
    -- the other usual stuff like XP and reputation"): under "You will also
    -- receive" the items everyone gets come first, then the XP (with the
    -- money beside it), then the reputation, as on every other quest.
    if frame.questXPReward then frame.questXPReward:Hide() end
    if frame.questMoneyReward then frame.questMoneyReward:Hide() end

    if quest.additionalRewardItems and #quest.additionalRewardItems > 0 then
        frame.questAdditionalRewardButtons = frame.questAdditionalRewardButtons or {}
        for i, item in ipairs(quest.additionalRewardItems) do
            if not frame.questAdditionalRewardButtons[i] then
                frame.questAdditionalRewardButtons[i] = MakeQuestRewardButton(frame.questDetailContent)
            end
            frame.questAdditionalRewardButtons[i]:SetWidth(rewardWidth)
            frame.questAdditionalRewardButtons[i].item = item
            frame.questAdditionalRewardButtons[i].icon:SetTexture(item[5] or ItemIcon(item[1]))
            if item[1] and item[1] > 0 and C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
                pcall(C_Item.RequestLoadItemDataByID, item[1])
            end
            do
                local itemName, itemLink, quality
                if item[1] and item[1] > 0 then itemName, itemLink, quality = ItemInfo(item[1]) end
                local r, g, b = GetAuthoritativeItemQuality(item[1], itemLink, quality, item[3] or 1)
                local countText = item[4] and item[4] > 1 and (" ×" .. tostring(item[4])) or ""
                frame.questAdditionalRewardButtons[i].name:SetText((itemName or item[2]) .. countText)
                frame.questAdditionalRewardButtons[i].name:SetTextColor(r, g, b)
            end
            frame.questAdditionalRewardButtons[i]:SetBackdropColor(unpack(theme.lootRow))
            frame.questAdditionalRewardButtons[i]:SetBackdropBorderColor(unpack(theme.border))
            frame.questAdditionalRewardButtons[i]:ClearAllPoints()
            frame.questAdditionalRewardButtons[i]:SetPoint(
                "TOPLEFT",
                frame.questDetailContent,
                "TOPLEFT",
                ((i - 1) % 2) * (rewardWidth + 10),
                -(summaryY + math.floor((i - 1) / 2) * 54)
            )
            frame.questAdditionalRewardButtons[i]:Show()
        end
        summaryY = summaryY + (math.floor((#quest.additionalRewardItems - 1) / 2) + 1) * 54 + 4
    end

    -- itemsfirst: the XP (and money) line, under those items
    if frame.questXPReward and showXP then
        frame.questXPReward:ClearAllPoints()
        frame.questXPReward:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -summaryY)
        frame.questXPReward.text:SetText(FormatNumber(xp) .. " XP")
        frame.questXPReward:Show()
        hasRewardBar = true
    end
    if frame.questMoneyReward and money and money > 0 then
        frame.questMoneyReward:ClearAllPoints()
        if showXP and frame.questXPReward then
            frame.questMoneyReward:SetPoint("LEFT", frame.questXPReward, "RIGHT", 8, 0)
        else
            frame.questMoneyReward:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -summaryY)
        end
        frame.questMoneyReward.text:SetText(FormatQuestMoney(money))
        local moneyWidth = math.ceil((frame.questMoneyReward.text:GetStringWidth() or 0) + 16)
        frame.questMoneyReward:SetWidth(math.max(40, math.min(120, moneyWidth)))
        frame.questMoneyReward:Show()
        hasRewardBar = true
    end
    if hasRewardBar then
        summaryY = summaryY + 34
    end

    frame.questRewardSummary:ClearAllPoints()
    frame.questRewardSummary:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -summaryY)
    frame.questRewardSummary:SetPoint("RIGHT", frame.questDetailContent, "RIGHT", -8, 0)
    ApplyRewardSummaryFont(frame.questRewardSummary)
    -- Reputation gains ("Ironforge +100") are drawn as pills like the XP and
    -- money rewards; anything else in the summary stays as text below them.
    do
        local raw = BuildQuestRewardSummary(quest, false) or ""
        local reps, rest = {}, {}
        for part in (raw .. "\226\128\162"):gmatch("(.-)\226\128\162") do
            part = part:gsub("^%s+", ""):gsub("%s+$", "")
            if part ~= "" then
                local name, amount = part:match("^(.-)%s*%+(%d+)$")
                if name and name ~= "" then
                    reps[#reps + 1] = { name, amount }
                else
                    rest[#rest + 1] = part
                end
            end
        end
        local repHeight = FDJ.LayoutRepPills(reps, summaryY, (frame.questDetailContent:GetWidth() or 350) - 8)
        if repHeight > 0 then
            summaryY = summaryY + repHeight + 4
            frame.questRewardSummary:ClearAllPoints()
            frame.questRewardSummary:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -summaryY)
            frame.questRewardSummary:SetPoint("RIGHT", frame.questDetailContent, "RIGHT", -8, 0)
        end
        frame.questRewardSummary:SetText(table.concat(rest, "  \226\128\162  "))
    end
    frame.questRewardSummary:SetTextColor(0.10, 0.065, 0.025)

    local summaryHeight = 0
    local summaryText = frame.questRewardSummary:GetText() or ""
    if summaryText ~= "" then
        summaryHeight = frame.questRewardSummary:GetStringHeight() or 18
    end
    local totalHeight = summaryY + summaryHeight + 18

    frame.questDetailContent:SetHeight(math.max(1, totalHeight))
    FDJ.ApplyQuestDetailScroll("quest:" .. tostring(selectedDungeon) .. ":" .. tostring(selectedQuestFaction) .. ":" .. tostring(quest.id or quest.name), totalHeight)
    UpdateScrollBarVisibility(frame.questDetailScroll, totalHeight)
end

-- resultquest (2.0.10, M 17 Nov 2026: a quest shown on the Loot Filter page
-- (Show quest rewards too) "should show the whole quest as normal in the
-- right panel"): with such an entry selected there, the quest page on the
-- right is that quest's, drawn as on its own dungeon's Quests tab.
FDJ.PlainQuestDetail = RefreshQuestDetail
RefreshQuestDetail = function(...)
    local page = DB[selectedDungeon]
    local entry = page and page.lootFilterPage and page.bosses and page.bosses[selectedBoss]
    local quest = type(entry) == "table" and rawget(entry, "fdjQuest") or nil
    local realName = quest and rawget(entry, "fdjDungeon")
    local real = realName and DB[realName]
    local index
    for i, q in ipairs((real and real.quests) or {}) do
        if q == quest then index = i break end
    end
    if not index then return FDJ.PlainQuestDetail(...) end
    local pageName, pageQuest = selectedDungeon, selectedQuest
    selectedDungeon, selectedQuest = realName, index
    selectedQuestFaction = FDJ.PlayerFaction() or selectedQuestFaction
    local ok, err = pcall(FDJ.PlainQuestDetail, ...)
    selectedDungeon, selectedQuest = pageName, pageQuest
    if not ok and geterrorhandler then geterrorhandler()(err) end
end
-- The page's right side: the quest for a quest entry, the loot for a boss.
FDJ.ShowResultQuest = function(entry)
    if not frame then return false end
    local page = DB[selectedDungeon]
    local quest = type(entry) == "table" and rawget(entry, "fdjQuest") or nil
    if not (quest and page and page.lootFilterPage and selectedMode == "bosses") then
        if frame.fdjResultQuest then
            frame.fdjResultQuest = nil
            if selectedMode == "bosses" and frame.questRightPanel:IsShown() then
                frame.questRightPanel:Hide()
                frame.rightPanel:Show()
            end
        end
        return false
    end
    if frame.fdjResultQuest ~= quest then selectedPrereqStep = nil end
    frame.fdjResultQuest = quest
    frame.rightPanel:Hide()
    frame.questRightPanel:Show()
    if quest.id then RequestQuestRewardData(quest.id) end
    RefreshQuestDetail()
    return true
end

SetQuestFaction = function(faction)
    if faction ~= "Alliance" and faction ~= "Horde" then return end
    if FDJ.FactionHiddenFor(selectedDungeon, faction) then UpdateFactionButtons() return end -- questrowtrial

    selectedQuestFaction = faction
    selectedPrereqStep = nil
    selectedPrereqParentQuestName = nil
    selectedPrereqParentQuestID = nil
    ForeverDungeonJournalDB.questFaction = faction
    frame.questListScroll:SetVerticalScroll(0)

    BuildVisibleQuestIndexes()
    RefreshQuestList()
    RefreshQuestDetail()
end

-- questrowtrial (2.0.8): the option "Show both factions' quests" changed:
-- the open quest list and its crests again.
FDJ.RefreshQuestFactionLock = function()
    if not (frame and selectedDungeon and DB[selectedDungeon]) then return end
    UpdateFactionButtons()
    BuildVisibleQuestIndexes()
    RefreshQuestList()
    RefreshQuestDetail()
end


local function HideRouteGuide()
    if not frame or not frame.routePanel then return end
    frame.routePanel:Hide()
end

ShowRouteGuide = function()
    if not frame then return end
    local dungeon = DB[selectedDungeon]
    local route = dungeon and dungeon.routeGuide
    if not route or not frame.routePanel then return end

    local lang = FDJ.GetLanguage and FDJ.GetLanguage() or "enUS"
    local localizedRoute = route.locales and (route.locales[lang] or route.locales.enUS) or route

    frame.leftPanel:Hide()
    frame.rightPanel:Hide()
    frame.questLeftPanel:Hide()
    frame.questRightPanel:Hide()

    if frame.routeFactionIcon then
        frame.routeFactionIcon:SetTexture(route.faction == "Horde" and HORDE_ICON or ALLIANCE_ICON)
    end
    local hasRouteMap = route.mapRoute and ShowRouteOnMap
    -- A step flagged `showRoute = true` carries the route button itself (e.g.
    -- "2. Follow the road from Southshore"), so the header button is hidden.
    local routeOnStep = false
    for _, step in ipairs(localizedRoute.steps or route.steps or {}) do
        if step.showRoute then routeOnStep = true break end
    end
    if routeOnStep then hasRouteMap = false end
    if frame.routeMapButton then
        frame.routeMapButton:SetShown(hasRouteMap and true or false)
        frame.routeMapButton:SetText(L("SHOW_ON_MAP"))
        frame.routeMapButton:ClearAllPoints()
    end
    frame.routeTitle:ClearAllPoints()
    frame.routeTitle:SetPoint("TOPLEFT", frame.routeFactionIcon, "TOPRIGHT", 10, -1)
    frame.routeTitle:SetText(localizedRoute.title or L("HOW_TO_GET_THERE"))
    if hasRouteMap and frame.routeMapButton then
        frame.routeMapButton:SetPoint("LEFT", frame.routeTitle, "RIGHT", 10, 0)
    elseif frame.routeMapButton then
        frame.routeMapButton:SetPoint("TOPRIGHT", -34, -20)
    end
    frame.routeSubtitle:SetText(localizedRoute.subtitle or (route.faction == "Horde" and "Horde route" or L("ALLIANCE_ROUTE")))

    frame.routeSteps:SetText("")
    frame.routeShortcutTitle:SetText("")
    frame.routeShortcut:SetText("")
    frame.routeWarning:SetText("")

    if frame.routeStepRows and frame.routeStepContent then
        for _, row in ipairs(frame.routeStepRows) do
            row:Hide()
        end

        local y = 0
        local stepNumber = 0
        for i, step in ipairs(localizedRoute.steps or route.steps or {}) do
            local row = frame.routeStepRows[i]
            if not row then
                row = CreateFrame("Frame", nil, frame.routeStepContent)
                row.title = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalLarge")
                row.title:SetPoint("TOPLEFT", 0, 0)
                row.title:SetJustifyH("LEFT")
                row.title:SetTextColor(1.00, 0.82, 0.27)

                row.body = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
                row.body:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -5)
                row.body:SetJustifyH("LEFT")
                row.body:SetJustifyV("TOP")
                row.body:SetWordWrap(true)
                row.body:SetTextColor(0.96, 0.90, 0.78)

                row.mapButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                FDJ.OwnFonts(row.mapButton) -- ownfonts (2.0.8)
                row.mapButton:SetSize(112, 22)
                row.mapButton:SetText(L("SHOW_ON_MAP"))
                row.mapButton:SetScript("OnClick", function(self)
                    if self.showsRoute then
                        local d = DB[selectedDungeon]
                        local r = d and d.routeGuide
                        if r and r.mapRoute and ShowRouteOnMap then ShowRouteOnMap(r.mapRoute) end
                    elseif self.mapLocation then
                        ShowRecordedLocationOnMap(self.mapLocation, self.mapLocation.label)
                    end
                end)
                row.mapButton:Hide()

                frame.routeStepRows[i] = row
            end

            local contentW = math.max(420, (frame.routeStepScroll:GetWidth() or 560) - 8)
            frame.routeStepContent:SetWidth(contentW)

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetWidth(contentW)

            row.title:ClearAllPoints()
            row.title:SetPoint("TOPLEFT", 0, 0)
            row.body:ClearAllPoints()
            row.body:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -5)

            -- Optional route notes (such as the Orgrimmar zeppelin tip) are
            -- intentionally unnumbered so the numbered travel steps still begin at 1.
            if step.unnumbered then
                row.title:SetText(step.title or "")
                row.title:SetTextColor(0.55, 0.85, 1.00)
            else
                stepNumber = stepNumber + 1
                row.title:SetText(tostring(stepNumber) .. ". " .. (step.title or ""))
                row.title:SetTextColor(1.00, 0.82, 0.27)
            end
            row.body:SetText(step.text or "")

            row.mapButton.mapLocation = step.map
            row.mapButton.showsRoute = (step.showRoute and route.mapRoute and ShowRouteOnMap) and true or false
            if step.map or row.mapButton.showsRoute then
                row.mapButton:ClearAllPoints()
                local titleWidth = math.ceil(row.title:GetStringWidth() or 0)
                row.mapButton:SetPoint("TOPLEFT", row, "TOPLEFT", titleWidth + 10, 2)
                row.mapButton:SetText(L("SHOW_ON_MAP"))
                row.mapButton:Show()
                row.title:SetWidth(math.min(titleWidth + 2, contentW - 130))
            else
                row.mapButton:Hide()
                row.title:SetWidth(contentW - 8)
            end
            row.body:SetWidth(contentW - 8)
            row:Show()

            local titleH = math.max(18, row.title:GetStringHeight() or 18)
            local rowH
            if (step.text or "") == "" then
                rowH = titleH
            else
                local bodyH = math.max(20, row.body:GetStringHeight() or 20)
                rowH = titleH + 7 + bodyH
            end
            row:SetHeight(rowH)
            y = y + rowH + 18
        end

        frame.routeStepContent:SetHeight(math.max(y, 1))
        frame.routeStepScroll:SetVerticalScroll(0)
        if frame.routeStepScroll.ScrollBar then frame.routeStepScroll.ScrollBar:SetValue(0) end
        UpdateScrollBarVisibility(frame.routeStepScroll, y)
    end

    frame.routePanel:Show()
    UpdateModeTabs()
end

local function ClearDungeonMapArt()
    if not frame then return end
    for _, tex in ipairs(frame.dungeonMapArtTiles or {}) do tex:Hide() end
    for _, marker in ipairs(frame.dungeonMapBossMarkers or {}) do marker:Hide() end
    for _, m in ipairs(frame.dungeonMapNumbers or {}) do m:Hide() end -- ststatues (2.0.6)
    for _, a in ipairs(frame.dungeonMapLinks or {}) do a:Hide() end -- maplinks (2.0.11)
end

local function RenderRagefireMap()
    if not frame or not frame.dungeonMapArtHolder then return end
    ClearDungeonMapArt()

    local data = RAGEFIRE_MAP
    local holder = frame.dungeonMapArtHolder

    -- Ragefire Chasm's Classic map art is present in the client under the
    -- historical "Ragefire" WorldMap folder. Unlike newer C_Map-backed maps,
    -- this Classic dungeon uses 12 fixed 256x256 tiles named Ragefire1_1 ...
    -- Ragefire1_12. Loading those files directly is reliable even while the
    -- player is outside the instance.
    -- The visible client parchment is 3:2.  Previous builds forced the 4x3
    -- texture tile grid into a 2:1 rectangle, visibly stretching the map and
    -- making normalized boss coordinates look wrong.  Keep the actual visible
    -- parchment aspect ratio and use almost the entire map page.
    local artW, artH = 480, 320
    local scaleX, scaleY = artW / 1024, artH / 768
    holder:ClearAllPoints()
    holder:SetSize(artW, artH)
    holder:SetPoint("CENTER", frame.dungeonMapPanel, "CENTER", 0, 0)
    if frame.dungeonMapCanvas then
        frame.dungeonMapCanvas:ClearAllPoints()
        frame.dungeonMapCanvas:SetSize(artW, artH)
        frame.dungeonMapCanvas:SetPoint("CENTER", frame.dungeonMapPanel, "CENTER", 0, 0)
        frame.dungeonMapCanvas:SetBackdropColor(0, 0, 0, 0)
        frame.dungeonMapCanvas:SetBackdropBorderColor(0, 0, 0, 0)
    end

    local index = 1
    for row = 1, 3 do
        for col = 1, 4 do
            local tex = frame.dungeonMapArtTiles[index]
            if not tex then
                tex = holder:CreateTexture(nil, "ARTWORK")
                frame.dungeonMapArtTiles[index] = tex
            end
            tex:ClearAllPoints()
            tex:SetSize(256 * scaleX, 256 * scaleY)
            tex:SetPoint("TOPLEFT", holder, "TOPLEFT", (col - 1) * 256 * scaleX, -((row - 1) * 256 * scaleY))
            tex:SetTexture("Interface\\Worldmap\\Ragefire\\Ragefire1_" .. index)
            tex:SetTexCoord(0, 1, 0, 1)
            tex:Show()
            index = index + 1
        end
    end

    local dungeon = DB[selectedDungeon]
    for i, mapBoss in ipairs(data.bosses) do
        local marker = frame.dungeonMapBossMarkers[i]
        if not marker then
            marker = CreateFrame("Button", nil, holder)
            marker:SetSize(22, 22)
            marker.portrait = marker:CreateTexture(nil, "ARTWORK")
            marker.portrait:SetAllPoints()
            marker.portrait:SetTexCoord(0.12, 0.88, 0.12, 0.88)
            marker.border = marker:CreateTexture(nil, "OVERLAY")
            marker.border:SetSize(26, 26)
            marker.border:SetPoint("CENTER")
            marker.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
            marker:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.bossName or "")
                GameTooltip:Show()
            end)
            marker:SetScript("OnLeave", function() GameTooltip:Hide() end)
            frame.dungeonMapBossMarkers[i] = marker
        end
        local bossRecord
        for _, candidate in ipairs((dungeon and dungeon.bosses) or {}) do
            if candidate.name == mapBoss.name then bossRecord = candidate break end
        end
        if bossRecord then
            local hasPortrait = SetBossPortrait(marker.portrait, selectedDungeon, bossRecord)
            if not hasPortrait then
                marker.portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                marker.portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            marker.bossName = BossName(bossRecord.name)
        else
            marker.portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            marker.portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            marker.bossName = mapBoss.name
        end
        marker:ClearAllPoints()
        marker:SetPoint("CENTER", holder, "TOPLEFT", mapBoss.x * artW, -(mapBoss.y * artH))
        marker:Show()
    end
end

-- Zoom (mouse wheel) and pan (left-drag) for the dungeon map page.
FDJ.ResetDungeonMapView = function()
    if not frame then return end
    frame.dungeonMapZoom = 1
    frame.dungeonMapPanX, frame.dungeonMapPanY = 0, 0
end

FDJ.PositionDungeonMapHolder = function()
    local holder, panel = frame and frame.dungeonMapArtHolder, frame and frame.dungeonMapPanel
    if not holder or not panel then return end
    local pw, ph = panel:GetWidth() or 0, panel:GetHeight() or 0
    local hw, hh = holder:GetWidth() or 0, holder:GetHeight() or 0
    -- Zoomed in: the map can be dragged until its edge reaches the middle of
    -- the page, so every corner can be brought into view. Not zoomed: centred.
    local maxX, maxY = 0, 0
    if (frame.dungeonMapZoom or 1) > 1.001 then
        maxX, maxY = hw / 2, hh / 2
    end
    frame.dungeonMapPanX = math.max(-maxX, math.min(maxX, frame.dungeonMapPanX or 0))
    frame.dungeonMapPanY = math.max(-maxY, math.min(maxY, frame.dungeonMapPanY or 0))
    holder:ClearAllPoints()
    holder:SetPoint("CENTER", panel, "CENTER", frame.dungeonMapPanX, frame.dungeonMapPanY)
end

FDJ.SetupDungeonMapZoom = function()
    local panel = frame and frame.dungeonMapPanel
    if not panel or panel.fdjZoomReady then return end
    panel.fdjZoomReady = true
    panel:EnableMouse(true)
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(self, delta)
        local data = FDJ.DUNGEON_MAPS[selectedDungeon]
        if not data then return end
        local old = frame.dungeonMapZoom or 1
        local new = math.max(1, math.min(4, old * (delta > 0 and 1.25 or 0.8)))
        if math.abs(new - old) < 0.001 then return end
        -- Zoom around the cursor: keep the map point under it in place.
        local scale = self:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        local left, bottom = self:GetLeft() or 0, self:GetBottom() or 0
        local mx = cx / scale - left - (self:GetWidth() or 0) / 2
        local my = cy / scale - bottom - (self:GetHeight() or 0) / 2
        local k = new / old
        frame.dungeonMapPanX = mx - (mx - (frame.dungeonMapPanX or 0)) * k
        frame.dungeonMapPanY = my - (my - (frame.dungeonMapPanY or 0)) * k
        if new <= 1.001 then frame.dungeonMapPanX, frame.dungeonMapPanY = 0, 0 end
        frame.dungeonMapZoom = new
        FDJ.RenderCustomDungeonMap(data, frame.dungeonMapFloor)
    end)
    -- Left-click and hold to drag the zoomed map around. The drag ends on
    -- mouse up (also when released outside the map) or when the map hides.
    local function StopDrag(self)
        if not self.fdjDrag then return end
        self.fdjDrag = nil
        if ResetCursor then pcall(ResetCursor) end
    end
    panel:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or (frame.dungeonMapZoom or 1) <= 1.001 then return end
        local scale = self:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        self.fdjDrag = { x = cx / scale, y = cy / scale, px = frame.dungeonMapPanX or 0, py = frame.dungeonMapPanY or 0 }
        if SetCursor then pcall(SetCursor, "Interface\\CURSOR\\UI-Cursor-Move") end
    end)
    panel:HookScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then StopDrag(self) end
    end)
    panel:HookScript("OnHide", StopDrag)
    if panel.RegisterEvent then pcall(panel.RegisterEvent, panel, "GLOBAL_MOUSE_UP") end
    panel:SetScript("OnEvent", function(self, event, button)
        if event == "GLOBAL_MOUSE_UP" and (button == nil or button == "LeftButton") then StopDrag(self) end
    end)
    panel:SetScript("OnUpdate", function(self)
        local d = self.fdjDrag
        if not d then return end
        local scale = self:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        frame.dungeonMapPanX = d.px + (cx / scale - d.x)
        frame.dungeonMapPanY = d.py + (cy / scale - d.y)
        FDJ.PositionDungeonMapHolder()
    end)
end

-- Floor to open a dungeon's map on: the one last looked at, else the entrance floor.
FDJ.SavedMapFloor = function(dungeonName, data)
    local floors = data and data.floors or {}
    local saved = ForeverDungeonJournalDB.mapFloors and ForeverDungeonJournalDB.mapFloors[dungeonName]
    if type(saved) == "number" and saved >= 1 and saved <= #floors then return saved end
    return data and (data.defaultFloor or (data.entrance and data.entrance.floor)) or 1
end

-- pinspread (2.0.13, M 19 Nov 2026: "the portraits overlapping looks kind of
-- bad"): on a map with spreadPins, boss pins that would cover each other are
-- pushed apart, each along the line between them, just far enough for the
-- rings to touch, so they sit side by side near their spots. Pins on the
-- very same spot go left to right in list order. Faded "can also spawn
-- here" pins stay where they are, under the others.
function FDJ.SpreadMapPins(markers, count, size)
    local gap, pins = size * 1.32, {}
    for i = 1, count do
        local m = markers[i]
        if m and m.fdjPX and not m.altSpawn and m:IsShown() then
            m.fdjSX, m.fdjSY = m.fdjPX, m.fdjPY
            pins[#pins + 1] = m
        end
    end
    for _ = 1, 40 do
        local moved = false
        for i = 1, #pins - 1 do
            for j = i + 1, #pins do
                local a, b = pins[i], pins[j]
                local dx, dy = b.fdjSX - a.fdjSX, b.fdjSY - a.fdjSY
                local d = math.sqrt(dx * dx + dy * dy)
                if d < gap - 0.5 then
                    if d < 0.01 then dx, dy, d = 1, 0, 1 end
                    local push = (gap - d) / 2
                    a.fdjSX, a.fdjSY = a.fdjSX - dx / d * push, a.fdjSY - dy / d * push
                    b.fdjSX, b.fdjSY = b.fdjSX + dx / d * push, b.fdjSY + dy / d * push
                    moved = true
                end
            end
        end
        if not moved then break end
    end
    for _, m in ipairs(pins) do
        m:ClearAllPoints()
        m:SetPoint("CENTER", m:GetParent(), "TOPLEFT", m.fdjSX, -m.fdjSY)
    end
end

FDJ.RenderCustomDungeonMap = function(data, floorIndex)
    if not frame or not frame.dungeonMapArtHolder or not data then return end
    ClearDungeonMapArt()
    local holder = frame.dungeonMapArtHolder
    local panel = frame.dungeonMapPanel
    local floors = data.floors or {}
    floorIndex = math.max(1, math.min(#floors, floorIndex or (data.entrance and data.entrance.floor) or 1))
    frame.dungeonMapFloor = floorIndex
    -- Remember the floor per dungeon so the map reopens where it was left.
    if selectedDungeon and DB[selectedDungeon] then
        ForeverDungeonJournalDB.mapFloors = ForeverDungeonJournalDB.mapFloors or {}
        ForeverDungeonJournalDB.mapFloors[selectedDungeon] = floorIndex
    end
    local floorData = floors[floorIndex]
    if not floorData then return end

    -- Fit the 3:2 map art into the page without stretching (centred), then
    -- apply the current zoom (mouse wheel) and pan (drag).
    local aspect = 3 / 2
    local availW = math.max(200, (panel:GetWidth() or 760) - 16)
    local availH = math.max(140, (panel:GetHeight() or 380) - 16)
    local baseW, baseH = availW, availW / aspect
    if baseH > availH then baseH = availH; baseW = availH * aspect end
    baseW, baseH = math.floor(baseW), math.floor(baseH)
    local zoom = frame.dungeonMapZoom or 1
    local artW, artH = math.floor(baseW * zoom), math.floor(baseH * zoom)
    frame.dungeonMapBaseW, frame.dungeonMapBaseH = baseW, baseH

    holder:SetSize(artW, artH)
    FDJ.PositionDungeonMapHolder()
    if holder.SetClipsChildren then holder:SetClipsChildren(true) end
    if frame.dungeonMapCanvas then
        frame.dungeonMapCanvas:ClearAllPoints()
        frame.dungeonMapCanvas:SetAllPoints(panel)
        frame.dungeonMapCanvas:SetBackdropColor(0, 0, 0, 0)
        frame.dungeonMapCanvas:SetBackdropBorderColor(0, 0, 0, 0)
    end

    local tiles = frame.dungeonMapArtTiles
    local function Tile(i)
        local t = tiles[i]
        if not t then t = holder:CreateTexture(nil, "ARTWORK"); tiles[i] = t end
        t:ClearAllPoints()
        return t
    end
    if floorData.texture then
        if FDJ.CheckMapTiles then pcall(FDJ.CheckMapTiles, panel, nil) end
        local t = Tile(1)
        t:SetAllPoints(holder)
        t:SetTexture(floorData.texture)
        t:SetTexCoord(0, floorData.texRight or 1, 0, floorData.texBottom or 1)
        t:Show()
    else
        -- Prefer C_Map's numeric FileDataIDs when a UIMapID is supplied.
        -- FileDataIDs are locale-independent, unlike some legacy Interface\WorldMap
        -- texture aliases which are missing on certain localized Forever clients.
        local apiTextures, apiLayer
        frame.dungeonMapArtMissing = false
        frame.dungeonMapArtCopy = false
        if floorData.uiMapID and C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures then
            -- The stored map ID first; if this client has no art under it, the
            -- map found by the dungeon's name (see Systems/MapArtFinder.lua).
            for attempt = 1, 2 do
                local mapID = floorData.uiMapID
                if attempt == 2 then mapID = FDJ.FindMapArtID and FDJ.FindMapArtID(selectedDungeon, floorData) end
                if not mapID or (attempt == 2 and mapID == floorData.uiMapID) then break end
                local okLayers, layers = pcall(C_Map.GetMapArtLayers, mapID)
                if okLayers and type(layers) == "table" and layers[1] then
                    local okTextures, textures = pcall(C_Map.GetMapArtLayerTextures, mapID, 1)
                    if okTextures and type(textures) == "table" and #textures > 0 then
                        apiLayer, apiTextures = layers[1], textures
                        break
                    end
                end
            end
        end

        if apiTextures and apiLayer then
            local layerW = tonumber(apiLayer.layerWidth) or 1002
            local layerH = tonumber(apiLayer.layerHeight) or 668
            local tileW = tonumber(apiLayer.tileWidth) or 256
            local tileH = tonumber(apiLayer.tileHeight) or 256
            local cols = math.max(1, math.ceil(layerW / tileW))
            local scaleX, scaleY = artW / layerW, artH / layerH
            local unloaded = false
            for i = 1, #apiTextures do
                local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
                local t = Tile(i)
                t:SetSize(tileW * scaleX, tileH * scaleY)
                t:SetPoint("TOPLEFT", holder, "TOPLEFT", col * tileW * scaleX, -row * tileH * scaleY)
                -- If a file ID does not load on this client, try the tile's path.
                local loaded = t:SetTexture(apiTextures[i])
                if loaded == false and floorData.tiles then loaded = t:SetTexture(floorData.tiles .. i) end
                if loaded == false then unloaded = true end
                t:SetTexCoord(0, 1, 0, 1)
                t:SetDrawLayer("ARTWORK", 0)
                t:Show()
            end
            -- The game lists the map's pictures but this client cannot load
            -- them: the journal's own copy of the map instead.
            local copy = unloaded and FDJ.MapArtCopy and FDJ.MapArtCopy(floorData)
            if copy then
                for i = 2, #apiTextures do Tile(i):Hide() end
                local t = Tile(1)
                t:SetAllPoints(holder)
                t:SetTexture(copy)
                t:SetTexCoord(0, 1002 / 1024, 0, 668 / 1024)
                t:Show()
                frame.dungeonMapArtCopy = true
            end
        else
            -- Legacy fallback for clients where the map-art API is unavailable.
            -- Some localized clients (ruRU) do not have these map files at all:
            -- the file name then has no file ID. The journal then shows its own
            -- copy of the map (Media\Maps, the patches already on it); a map
            -- without a copy gets a plain parchment instead of black/green
            -- tiles, so the boss pins stay readable.
            local scale = artW / 1002
            local first = Tile(1)
            first:SetTexture(floorData.tiles .. 1)
            frame.dungeonMapArtMissing = FDJ.forceMissingMapArt
                or (first.GetTextureFileID and not first:GetTextureFileID()) or false
            local copy = frame.dungeonMapArtMissing and FDJ.MapArtCopy and FDJ.MapArtCopy(floorData)
            if copy then
                frame.dungeonMapArtMissing = false
                frame.dungeonMapArtCopy = true
            end
            for i = 1, 12 do
                local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
                local t = Tile(i)
                t:ClearAllPoints()
                if copy or frame.dungeonMapArtMissing then
                    if i == 1 then
                        t:SetAllPoints(holder)
                        if copy then
                            -- 1002x668 map, top-left in a 1024x1024 texture.
                            t:SetTexture(copy)
                            t:SetTexCoord(0, 1002 / 1024, 0, 668 / 1024)
                        else
                            t:SetColorTexture(0.42, 0.33, 0.20, 1)
                        end
                        t:SetDrawLayer("ARTWORK", 0)
                        t:Show()
                    else
                        t:Hide()
                    end
                else
                    t:SetSize(256 * scale, 256 * scale)
                    t:SetPoint("TOPLEFT", holder, "TOPLEFT", col * 256 * scale, -row * 256 * scale)
                    t:SetTexture(floorData.tiles .. i)
                    t:SetTexCoord(0, 1, 0, 1)
                    t:SetDrawLayer("ARTWORK", 0)
                    t:Show()
                end
            end
        end
        if FDJ.CheckMapTiles then
            pcall(FDJ.CheckMapTiles, panel, tiles, apiTextures and #apiTextures or 12, floorData, apiTextures, apiLayer,
                frame.dungeonMapArtMissing and not apiTextures)
        end
        -- Parchment patches that cover the map's printed title banner.
        for p, patch in ipairs((not (frame.dungeonMapArtMissing and not apiTextures)) and not frame.dungeonMapArtCopy
            and floorData.patches or {}) do
            local t = Tile(12 + p)
            t:SetDrawLayer("ARTWORK", 1)
            t:SetPoint("TOPLEFT", holder, "TOPLEFT", patch.x0 * artW, -patch.y0 * artH)
            t:SetPoint("BOTTOMRIGHT", holder, "TOPLEFT", patch.x1 * artW, -patch.y1 * artH)
            t:SetTexture(patch.tex)
            t:SetTexCoord(0, 1, 0, 1)
            t:SetAlpha(patch.alpha or 1)
            t:Show()
        end
    end

    -- Floor selector (only for multi-level dungeons).
    frame.dungeonMapFloorButtons = frame.dungeonMapFloorButtons or {}
    for i = 1, math.max(#floors, #frame.dungeonMapFloorButtons) do
        local btn = frame.dungeonMapFloorButtons[i]
        if i <= #floors and #floors > 1 then
            if not btn then
                btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
                FDJ.OwnFonts(btn) -- ownfonts (2.0.8)
                btn:SetScript("OnClick", function(self)
                    FDJ.ResetDungeonMapView()
                    FDJ.RenderCustomDungeonMap(FDJ.DUNGEON_MAPS[selectedDungeon], self.floorIndex)
                end)
                btn:SetScript("OnEnter", function(self)
                    if not self.floorLabel then return end
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(self.floorLabel, 1, 0.82, 0)
                    GameTooltip:Show()
                end)
                btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                frame.dungeonMapFloorButtons[i] = btn
            end
            btn.floorIndex = i
            btn.floorLabel = floors[i].label
            btn:SetText(L("MAP_FLOOR", i))
            local fs = btn:GetFontString()
            btn:SetSize(math.max(70, math.ceil((fs and fs:GetStringWidth() or 50) + 20)), 22)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10 - (i - 1) * 24)
            btn:SetFrameLevel(holder:GetFrameLevel() + 30)
            if i == floorIndex then btn:Disable() else btn:Enable() end
            btn:Show()
        elseif btn then
            btn:Hide()
        end
    end

    -- floorbuttons: on the world map, clear of other buttons in that corner
    if FDJ.PlaceMapFloorButtons then
        pcall(FDJ.PlaceMapFloorButtons)
        if C_Timer and C_Timer.After then C_Timer.After(0.2, function() pcall(FDJ.PlaceMapFloorButtons) end) end
    end
    if FDJ.UpdateMapBossSizer then pcall(FDJ.UpdateMapBossSizer, panel, holder, frame.dungeonMapFloorButtons) end
    local dungeon = DB[selectedDungeon]
    local size = math.floor(math.max(26, math.floor(baseH * 0.095)) * (FDJ.MapBossScale and FDJ.MapBossScale() or 1))
    local shown = 0
    for _, mapBoss in ipairs(data.bosses or {}) do
        -- questmob: a quest's target shows only with its quest (faction,
        -- RPG Mode).
        -- (tunkpin: quest may list one quest per faction; the one for the
        -- quests shown is used)
        local questEntry, mapQuest
        if mapBoss.quest then
            local ids = type(mapBoss.quest) == "table" and mapBoss.quest or { mapBoss.quest }
            for _, id in ipairs(ids) do
                for _, q in ipairs((dungeon and dungeon.quests) or {}) do
                    if type(q) == "table" and q.id == id then
                        if not questEntry or (FDJ.QuestMatchesFaction and selectedQuestFaction
                            and not FDJ.QuestMatchesFaction(questEntry, selectedQuestFaction)) then
                            questEntry, mapQuest = q, id
                        end
                        break
                    end
                end
            end
        end
        -- (hidequestmobs, M 20 Nov 2026: "the hide quest button should hide
        -- quest bosses as well": Hide quests hides them too)
        local questHidden = mapBoss.quest and (not questEntry
            or (FDJ.MapQuestsHidden and FDJ.MapQuestsHidden(selectedDungeon))
            or (FDJ.QuestMatchesFaction and selectedQuestFaction and not FDJ.QuestMatchesFaction(questEntry, selectedQuestFaction))
            or (FDJ.RPGQuestHidden and FDJ.RPGQuestHidden(selectedDungeon, questEntry)))
        if (mapBoss.floor or 1) == floorIndex and not questHidden then
            shown = shown + 1
            local marker = frame.dungeonMapBossMarkers[shown]
            if not marker then
                marker = CreateFrame("Button", nil, holder)
                marker.portrait = marker:CreateTexture(nil, "ARTWORK")
                marker.portrait:SetAllPoints()
                marker.border = marker:CreateTexture(nil, "OVERLAY")
                marker.border:SetPoint("CENTER")
                marker.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
                marker.border:SetTexCoord(0, 0.6, 0, 0.6)
                marker:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(self.bossName or "")
                    if self.altSpawn then GameTooltip:AddLine(L("MAP_ALT_SPAWN"), 0.85, 0.85, 0.85) end -- altspawn
                    if self.questTitle then -- questmob
                        GameTooltip:AddLine(self.questTitle, 1, 0.82, 0)
                        GameTooltip:AddLine(L("MAP_QUEST_TARGET"), 0.92, 0.92, 0.92)
                    end
                    GameTooltip:Show()
                end)
                marker:SetScript("OnLeave", function() GameTooltip:Hide() end)
                frame.dungeonMapBossMarkers[shown] = marker
            end
            if marker:GetParent() ~= holder then marker:SetParent(holder) end
            marker:SetSize(size, size)
            marker.border:SetSize(size * 1.55, size * 1.55)
            marker:SetFrameLevel(holder:GetFrameLevel() + 10)
            -- questmob: the game's quest badge (the yellow ! a quest mob's
            -- portrait gets on the target frame) on a quest's target, not
            -- the hand-in ?; greyed once the quest is handed in.
            if mapBoss.quest then
                if not marker.questBadge then
                    marker.questBadge = CreateFrame("Frame", nil, marker)
                    marker.questBadge.icon = marker.questBadge:CreateTexture(nil, "OVERLAY", nil, 2)
                    marker.questBadge.icon:SetAllPoints()
                    marker.questBadge.icon:SetTexture("Interface\\TargetingFrame\\PortraitQuestBadge")
                end
                local badge = marker.questBadge
                local bsize = math.max(22, math.floor(size * 0.85))
                badge:SetSize(bsize, bsize)
                badge:ClearAllPoints()
                badge:SetPoint("CENTER", marker, "TOPRIGHT", -bsize * 0.05, -bsize * 0.05)
                badge:SetFrameLevel(marker:GetFrameLevel() + 3)
                local done = FDJ.QuestTurnedIn and FDJ.QuestTurnedIn(mapQuest)
                if badge.icon.SetDesaturated then badge.icon:SetDesaturated(done and true or false) end
                badge:Show()
                marker.questID = mapQuest
                marker.questTitle = QuestField(mapQuest, "name", questEntry and questEntry.name or "")
            else
                if marker.questBadge then marker.questBadge:Hide() end
                marker.questID, marker.questTitle = nil, nil
            end

            local bossRecord, bossIndex
            for idx, candidate in ipairs((dungeon and dungeon.bosses) or {}) do
                if candidate.name == mapBoss.name then bossRecord, bossIndex = candidate, idx break end
            end
            marker.portrait:SetTexCoord(0, 1, 0, 1)
            local rpgHidden = FDJ.RPGMapBossHidden and FDJ.RPGMapBossHidden(selectedDungeon, bossRecord) or false -- rpgpartial
            local portraitRecord = (not rpgHidden) and (bossRecord or (mapBoss.npcID and { name = mapBoss.name, npcID = mapBoss.npcID })) or nil
            if not (portraitRecord and SetBossPortrait(marker.portrait, selectedDungeon, portraitRecord)) then
                marker.portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                marker.portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            marker.bossName = rpgHidden and "???" or (bossRecord and BossName(bossRecord.name) or mapBoss.name)
            if not bossRecord and FDJ.LocalizeFreeText then marker.bossName = FDJ.LocalizeFreeText(marker.bossName) or marker.bossName end
            local markerDungeon = selectedDungeon
            local markerQuest = (not bossRecord) and mapQuest or nil
            marker:SetScript("OnClick", function()
                -- questmob: a quest's target opens its quest.
                if markerQuest then
                    if FDJ.IsWorldMapOverlayAttached and FDJ.IsWorldMapOverlayAttached() and FDJ.OpenQuestFromWorldMap then
                        FDJ.OpenQuestFromWorldMap(markerDungeon, markerQuest)
                    elseif FDJ.OpenQuestPage then
                        FDJ.OpenQuestPage(markerDungeon, markerQuest)
                    end
                    return
                end
                if not bossIndex then return end
                -- On the world map (dungeon map shown over the M map): close
                -- the world map and open the journal on this boss's loot page.
                if FDJ.IsWorldMapOverlayAttached and FDJ.IsWorldMapOverlayAttached() and FDJ.OpenBossFromWorldMap then
                    FDJ.OpenBossFromWorldMap(markerDungeon, bossIndex)
                    return
                end
                if SetMode and SelectBoss then
                    SetMode("bosses")
                    SelectBoss(bossIndex)
                end
            end)
            marker:ClearAllPoints()
            marker:SetPoint("CENTER", holder, "TOPLEFT", mapBoss.x * artW, -(mapBoss.y * artH))
            -- altspawn (2.0.10, M 16 Nov 2026: "an opaque Targorr pin on the other
            -- spots just to show it could spawn there too"): alt = true, faded,
            -- under the boss's own pin, "Can also spawn here" on hover.
            marker.altSpawn = mapBoss.alt and true or nil
            marker:SetAlpha(mapBoss.alt and 0.45 or 1)
            if mapBoss.alt then marker:SetFrameLevel(holder:GetFrameLevel() + 8) end
            marker:SetShown(size > 0) -- boss icon size 0% hides them
            marker.fdjPX, marker.fdjPY = mapBoss.x * artW, mapBoss.y * artH -- pinspread
        end
    end
    for i = shown + 1, #frame.dungeonMapBossMarkers do
        frame.dungeonMapBossMarkers[i]:Hide()
    end
    if data.spreadPins and FDJ.SpreadMapPins then FDJ.SpreadMapPins(frame.dungeonMapBossMarkers, shown, size) end

    -- Entrance: the usual instance-portal icon with a yellow, black-outlined
    -- "Entrance" label next to it.
    -- data.entrances (several, each with its own labelKey / color) replaces
    -- the single data.entrance when present.
    local entList = data.entrances or (data.entrance and { data.entrance }) or {}
    frame.dungeonMapEntrances = frame.dungeonMapEntrances or {}
    local function EntranceFrame(i)
        local e = frame.dungeonMapEntrances[i]
        if e then return e end
        e = CreateFrame("Frame", nil, holder)
        e.icon = e:CreateTexture(nil, "OVERLAY")
        e.icon:SetAllPoints()
        local ok = e.icon.SetAtlas and pcall(e.icon.SetAtlas, e.icon, "Dungeon", false)
        if not ok then
            e.icon:SetTexture("Interface\\Icons\\INV_Misc_Rune_01")
            e.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        -- Font objects only (never SetFont with a raw file): Blizzard's font
        -- families carry the Korean/Cyrillic glyph fallbacks.
        e.label = e:CreateFontString(nil, "OVERLAY", _G.ForeverDJ_SystemFont_Shadow_Large_Outline and "ForeverDJ_SystemFont_Shadow_Large_Outline" or "ForeverDJ_GameFontNormalLarge")
        e.label:SetShadowColor(0, 0, 0, 1)
        e.label:SetShadowOffset(1, -1)
        frame.dungeonMapEntrances[i] = e
        return e
    end
    local entShown = 0
    for _, ent in ipairs(entList) do
        if (ent.floor or 1) == floorIndex then
            entShown = entShown + 1
            local e = EntranceFrame(entShown)
            if e:GetParent() ~= holder then e:SetParent(holder) end
            local iconSize = math.max(22, math.floor(baseH * 0.075))
            e:SetSize(iconSize, iconSize)
            e:SetFrameLevel(holder:GetFrameLevel() + 15)
            e:ClearAllPoints()
            e:SetPoint("CENTER", holder, "TOPLEFT", ent.x * artW, -(ent.y * artH))
            -- Label goes on the side given by the old arrow angle (default right).
            local rad = math.rad(ent.angle or 0)
            e.label:SetText(L(ent.labelKey or "MAP_ENTRANCE"))
            local c = ent.color
            if c then e.label:SetTextColor(c[1], c[2], c[3]) else e.label:SetTextColor(1.00, 0.82, 0.00) end
            e.label:ClearAllPoints()
            if ent.labelPos == "top" then
                e.label:SetPoint("BOTTOM", e, "TOP", 0, 1)
            elseif ent.labelPos == "bottom" then
                -- shaperpins (2.1.2): under the swirl; at the map's edge it
                -- runs inwards instead of off the map.
                if ent.x < 0.08 then
                    e.label:SetPoint("TOPLEFT", e, "BOTTOMLEFT", 0, -1)
                elseif ent.x > 0.92 then
                    e.label:SetPoint("TOPRIGHT", e, "BOTTOMRIGHT", 0, -1)
                else
                    e.label:SetPoint("TOP", e, "BOTTOM", 0, -1)
                end
            elseif math.cos(rad) < -0.3 then
                e.label:SetPoint("RIGHT", e, "LEFT", -3, 0)
            else
                e.label:SetPoint("LEFT", e, "RIGHT", 3, 0)
            end
            e:Show()
        end
    end
    for i = entShown + 1, #frame.dungeonMapEntrances do
        frame.dungeonMapEntrances[i]:Hide()
    end
    frame.dungeonMapEntrance = frame.dungeonMapEntrances[1]

    -- Green arrows showing where to go down/up to the next level. Clicking
    -- one switches the map to that level.
    frame.dungeonMapTransitions = frame.dungeonMapTransitions or {}
    local used = 0
    for _, tr in ipairs(data.transitions or {}) do
        if tr.floor == floorIndex and (floors[tr.to] or tr.note) then
            used = used + 1
            local t = frame.dungeonMapTransitions[used]
            if not t then
                t = CreateFrame("Button", nil, holder)
                -- Ladder icon marking where to change level.
                t.arrow = t:CreateTexture(nil, "OVERLAY")
                t.arrow:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\LevelLadder")
                t.arrow:SetTexCoord(0, 1, 0, 1)
                t.arrow:SetAllPoints()
                t.label = t:CreateFontString(nil, "OVERLAY", _G.ForeverDJ_SystemFont_Outline and "ForeverDJ_SystemFont_Outline" or "ForeverDJ_GameFontNormal")
                t.label:SetShadowColor(0, 0, 0, 1)
                t.label:SetShadowOffset(1, -1)
                t.label:SetTextColor(0.35, 1.00, 0.35)
                t.label:SetPoint("BOTTOM", t, "TOP", 0, 1)
                t:SetScript("OnClick", function(self)
                    if not self.toFloor then return end
                    FDJ.ResetDungeonMapView()
                    FDJ.RenderCustomDungeonMap(FDJ.DUNGEON_MAPS[selectedDungeon], self.toFloor)
                end)
                t:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(self.tipText or (self.toFloor and L("MAP_FLOOR", self.toFloor)) or self.noteText or "", 0.35, 1, 0.35)
                    GameTooltip:Show()
                end)
                t:SetScript("OnLeave", function() GameTooltip:Hide() end)
                frame.dungeonMapTransitions[used] = t
            end
            if t:GetParent() ~= holder then t:SetParent(holder) end
            t.toFloor = tr.to
            local len = math.max(28, math.floor(baseH * 0.10))
            t:SetSize(len, len)
            t:SetFrameLevel(holder:GetFrameLevel() + 14)
            t:ClearAllPoints()
            t:SetPoint("CENTER", holder, "TOPLEFT", tr.x * artW, -(tr.y * artH))
            -- Notes (no level change) only show their text on hover.
            t.noteText = tr.note and L(tr.labelKey) or nil
            -- tipKey (2.0.9, M 16 Nov 2026 at The Drowned City's swim down): the
            -- ladder alone, its text only on hover
            t.tipText = tr.tipKey and L(tr.tipKey, tr.to) or nil
            t.label:SetText((tr.note or tr.tipKey) and "" or L(tr.labelKey or "MAP_FLOOR", tr.to))
            -- (a transition's own colour: The Drowned City's red Shark exit)
            local c = type(tr.color) == "table" and tr.color or nil
            t.label:SetTextColor(c and c[1] or 0.35, c and c[2] or 1.00, c and c[3] or 0.35)
            t:Show()
        end
    end
    for i = used + 1, #frame.dungeonMapTransitions do
        frame.dungeonMapTransitions[i]:Hide()
    end
    -- maplinks (2.0.11): arrows between the parts of one map page.
    if FDJ.RenderMapLinks then FDJ.RenderMapLinks(holder, data, floorIndex, artW, artH, baseH) end

    -- Yellow "?" where a quest objective is picked up or clicked on the spot.
    frame.dungeonMapObjectives = frame.dungeonMapObjectives or {}
    local nObj = 0
    -- hidequests (2.0.15): none of these with Hide quests ticked.
    local hideQuests = FDJ.MapQuestsHidden and FDJ.MapQuestsHidden()
    for _, ob in ipairs(data.objectives or {}) do
        if (ob.floor or 1) == floorIndex and not hideQuests then
            nObj = nObj + 1
            local q = frame.dungeonMapObjectives[nObj]
            if not q then
                q = CreateFrame("Frame", nil, holder)
                q:EnableMouse(true)
                q.icon = q:CreateTexture(nil, "OVERLAY")
                q.icon:SetAllPoints()
                q.icon:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
                q:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(self.title or "", 1, 0.82, 0)
                    if self.body then GameTooltip:AddLine(self.body, 1, 1, 1, true) end
                    GameTooltip:Show()
                end)
                q:SetScript("OnLeave", function() GameTooltip:Hide() end)
                frame.dungeonMapObjectives[nObj] = q
            end
            if q:GetParent() ~= holder then q:SetParent(holder) end
            q.title = QuestField(ob.questID, "name", ob.quest)
            q.body = ob.textKey and L(ob.textKey) or nil
            local size = math.max(22, math.floor(baseH * 0.07))
            q:SetSize(size, size)
            q:SetFrameLevel(holder:GetFrameLevel() + 15)
            q:ClearAllPoints()
            q:SetPoint("CENTER", holder, "TOPLEFT", ob.x * artW, -(ob.y * artH))
            q:Show()
        end
    end
    for i = nObj + 1, #frame.dungeonMapObjectives do
        frame.dungeonMapObjectives[i]:Hide()
    end

    -- ststatues (2.0.6): numbered markers (data.markers): a gold-rimmed dark
    -- disc with its number; mouse-over: its title and what to do.
    -- ststatueart (2.0.6): a marker with statue = true is the serpent statue
    -- (Media\\SerpentStatue, cut from M's in-game shot; facing left, flip
    -- mirrors it) with the number disc on top of its head. The statue sits
    -- under the boss pins, its number over them.
    frame.dungeonMapNumbers = frame.dungeonMapNumbers or {}
    local nNum = 0
    local function numberEnter(self)
        local o = self.owner or self
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(o.title or "", 1, 0.82, 0)
        if o.body then GameTooltip:AddLine(o.body, 1, 1, 1, true) end
        GameTooltip:Show()
    end
    for _, mk in ipairs(data.markers or {}) do
        if (mk.floor or 1) == floorIndex then
            nNum = nNum + 1
            local m = frame.dungeonMapNumbers[nNum]
            if not m then
                m = CreateFrame("Frame", nil, holder)
                m:EnableMouse(true)
                m.statue = m:CreateTexture(nil, "ARTWORK")
                m.statue:SetAllPoints()
                m.statue:Hide()
                m.badge = CreateFrame("Frame", nil, m)
                m.badge:EnableMouse(true)
                m.badge.owner = m
                m.rim = m.badge:CreateTexture(nil, "ARTWORK", nil, 1)
                m.rim:SetAllPoints()
                m.rim:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
                m.rim:SetVertexColor(0.95, 0.74, 0.25, 1)
                m.disc = m.badge:CreateTexture(nil, "ARTWORK", nil, 2)
                m.disc:SetPoint("TOPLEFT", 2, -2)
                m.disc:SetPoint("BOTTOMRIGHT", -2, 2)
                m.disc:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
                m.disc:SetVertexColor(0.10, 0.07, 0.04, 0.95)
                m.text = m.badge:CreateFontString(nil, "OVERLAY", _G.ForeverDJ_SystemFont_Outline and "ForeverDJ_SystemFont_Outline" or "ForeverDJ_GameFontNormal")
                m.text:SetPoint("CENTER", 0, 0)
                m.text:SetTextColor(1.00, 0.84, 0.30)
                m:SetScript("OnEnter", numberEnter)
                m:SetScript("OnLeave", function() GameTooltip:Hide() end)
                m.badge:SetScript("OnEnter", numberEnter)
                m.badge:SetScript("OnLeave", function() GameTooltip:Hide() end)
                frame.dungeonMapNumbers[nNum] = m
            end
            if m:GetParent() ~= holder then m:SetParent(holder) end
            m.text:SetText(tostring(mk.text or mk.n or ""))
            m.title = mk.titleKey and L(mk.titleKey, mk.n) or nil
            -- ststatuedir (2.0.6): where it stands: "Statue 1 of 6 - South".
            if m.title and mk.dirKey then m.title = m.title .. " - " .. L(mk.dirKey) end
            local boss = mk.tipBoss and ((FDJ.LocalizeBossName and FDJ.LocalizeBossName(mk.tipBoss)) or mk.tipBoss) or nil
            m.body = mk.tipKey and L(mk.tipKey, boss or "") or nil
            m:ClearAllPoints()
            m:SetPoint("CENTER", holder, "TOPLEFT", mk.x * artW, -(mk.y * artH))
            m.badge:ClearAllPoints()
            if mk.statue then
                local art = FDJ.ST_STATUE_ART
                local sh = math.max(26, math.floor(baseH * 0.08))
                local sw = math.floor(sh * art.aspect + 0.5)
                local bs = math.max(14, math.floor(baseH * 0.042))
                m:SetSize(sw, sh)
                m.statue:SetTexture(art.texture)
                if mk.flip then
                    m.statue:SetTexCoord(1, 0, 0, art.bottom)
                else
                    m.statue:SetTexCoord(0, 1, 0, art.bottom)
                end
                m.statue:Show()
                m:SetFrameLevel(holder:GetFrameLevel() + 8)
                m.badge:SetSize(bs, bs)
                local hx = mk.flip and (1 - art.headX) or art.headX
                m.badge:SetPoint("CENTER", m, "TOPLEFT", hx * sw, bs * 0.22)
            else
                local size = math.max(18, math.floor(baseH * 0.055))
                m:SetSize(size, size)
                m.statue:Hide()
                m:SetFrameLevel(holder:GetFrameLevel() + 15)
                m.badge:SetAllPoints(m)
            end
            m.badge:SetFrameLevel(holder:GetFrameLevel() + 15)
            m.badge:Show()
            m:Show()
        end
    end
    for i = nNum + 1, #frame.dungeonMapNumbers do
        frame.dungeonMapNumbers[i]:Hide()
    end

    -- Yellow ? on the NPC a quest is handed in to, set by the quest tracker's
    -- ? button; stays until the quest leaves the log or it is right-clicked.
    -- The tracker's ! puts a yellow ! on the giver instead, until the quest
    -- is taken.
    local turnIn = FDJ.dungeonTurnIns and FDJ.dungeonTurnIns[data]
    if turnIn and turnIn.questID then
        local gone
        if turnIn.start then
            gone = IsQuestInLog(turnIn.questID) or FDJ.QuestTurnedIn(turnIn.questID)
        else
            gone = not IsQuestInLog(turnIn.questID)
        end
        if gone then
            FDJ.dungeonTurnIns[data] = nil
            turnIn = nil
        end
    end
    local mark = frame.dungeonMapTurnIn
    if turnIn and turnIn.floor == floorIndex and turnIn.x and turnIn.y then
        if not mark then
            mark = CreateFrame("Button", nil, holder)
            mark:RegisterForClicks("RightButtonUp")
            mark.icon = mark:CreateTexture(nil, "OVERLAY")
            mark.icon:SetAllPoints()
            mark.icon:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
            mark:SetScript("OnEnter", function(self)
                local t = self.turnIn
                if not t then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local text = (FDJ.LocalizeFreeText and FDJ.LocalizeFreeText(t.npc)) or t.npc or ""
                if type(t.title) == "string" and t.title ~= "" then text = text .. " - " .. t.title end -- a short dash
                GameTooltip:SetText(text)
                GameTooltip:AddLine(L(t.start and "QUEST_STARTS_HERE" or "TURN_IN_HERE"), 1, 0.82, 0.05)
                GameTooltip:AddLine(L("MAP_RIGHT_REMOVE"), 1, 1, 1)
                GameTooltip:Show()
            end)
            mark:SetScript("OnLeave", function() GameTooltip:Hide() end)
            mark:SetScript("OnClick", function(self, button)
                if button ~= "RightButton" then return end
                for key, value in pairs(FDJ.dungeonTurnIns or {}) do
                    if value == self.turnIn then FDJ.dungeonTurnIns[key] = nil end
                end
                self.turnIn = nil
                self:Hide()
                GameTooltip:Hide()
                if FDJ.RefreshMapQuestPins then pcall(FDJ.RefreshMapQuestPins) end -- mapquests
            end)
            frame.dungeonMapTurnIn = mark
        end
        if mark:GetParent() ~= holder then mark:SetParent(holder) end
        mark.turnIn = turnIn
        mark.icon:SetTexture(turnIn.start and "Interface\\GossipFrame\\AvailableQuestIcon" or "Interface\\GossipFrame\\ActiveQuestIcon")
        local size = math.max(24, math.floor(baseH * 0.08))
        mark:SetSize(size, size)
        if FDJ.StrokeIcon then FDJ.StrokeIcon(mark, mark.icon, size) end -- mapquests: a black edge
        mark:SetFrameLevel(holder:GetFrameLevel() + 16)
        mark:ClearAllPoints()
        mark:SetPoint("CENTER", holder, "TOPLEFT", turnIn.x * artW, -(turnIn.y * artH))
        mark:Show()
    elseif mark then
        mark.turnIn = nil
        mark:Hide()
    end

    -- mapquests: the quests' spots on this level (Systems/MapMarkers.lua).
    if FDJ.RenderMapQuestPins then
        pcall(FDJ.RenderMapQuestPins, selectedDungeon, floorIndex, holder, artW, artH, baseH, selectedQuestFaction)
    end
    if FDJ.ApplyDungeonMapFocus then pcall(FDJ.ApplyDungeonMapFocus) end -- mapfocus
end

HideDungeonMap = function()
    if frame and frame.dungeonMapPanel then frame.dungeonMapPanel:Hide() end
end

ShowDungeonMap = function()
    if not frame or not FDJ.DUNGEON_MAPS[selectedDungeon] then return end
    if FDJ.IsDungeonMapLocked and FDJ.IsDungeonMapLocked(selectedDungeon) then return end -- rpgpartial
    -- The map panel may be lent to the world map (M): take it back first.
    if FDJ.DetachWorldMapOverlay then pcall(FDJ.DetachWorldMapOverlay) end
    HideRouteGuide()
    frame.leftPanel:Hide()
    frame.rightPanel:Hide()
    frame.questLeftPanel:Hide()
    frame.questRightPanel:Hide()
    frame.dungeonMapTitle:SetText("")
    frame.dungeonMapPanel:Show()
    local mapData = FDJ.DUNGEON_MAPS[selectedDungeon]
    FDJ.SetupDungeonMapZoom()
    FDJ.ResetDungeonMapView()
    FDJ.RenderCustomDungeonMap(mapData, FDJ.SavedMapFloor(selectedDungeon, mapData))
    UpdateModeTabs()
end

SetMode = function(mode)
    if mode ~= "bosses" and mode ~= "quests" then return end
    -- sunonce (2.0.8): opening the quest page plays the glow's beam again
    if mode == "quests" and FDJ.ResetChainSheen then FDJ.ResetChainSheen() end
    HideRouteGuide()
    if HideDungeonMap then HideDungeonMap() end

    if mode ~= "bosses" and ResetPortraitResolver then
        ResetPortraitResolver()
    end

    selectedMode = mode
    ForeverDungeonJournalDB.lastMode = mode

    -- Every time the quest tab is opened, start on the player's own faction.
    -- The faction buttons can still be used manually afterwards.
    if mode == "quests" and FDJ.keepQuestState then
        -- Language change: keep the faction, quest and chain step being viewed.
        BuildVisibleQuestIndexes()
    elseif mode == "quests" and UnitFactionGroup then
        local playerFaction = UnitFactionGroup("player")
        if playerFaction == "Horde" then
            selectedQuestFaction = "Horde"
        elseif playerFaction == "Alliance" then
            selectedQuestFaction = "Alliance"
        end
        ForeverDungeonJournalDB.questFaction = selectedQuestFaction
        selectedPrereqStep = nil
        selectedPrereqParentQuestName = nil
        selectedPrereqParentQuestID = nil
        if frame and frame.questListScroll then
            frame.questListScroll:SetVerticalScroll(0)
        end
        BuildVisibleQuestIndexes()
    end

    local bosses = mode == "bosses"
    frame.leftPanel:SetShown(bosses)
    frame.rightPanel:SetShown(bosses)
    frame.questLeftPanel:SetShown(not bosses)
    frame.questRightPanel:SetShown(not bosses)

    UpdateModeTabs()
    if FDJ.UpdateQuestsTBD then FDJ.UpdateQuestsTBD() end

    if bosses then
        RefreshBossList()
        RefreshLoot()
    else
        local quests = DB[selectedDungeon].quests or {}
        if selectedQuest > #quests then selectedQuest = 1 end

        for _, quest in ipairs(quests) do
            RequestQuestRewardData(quest.id)
        end

        RefreshQuestList()
        RefreshQuestDetail()
    end
end

SelectQuest = function(index, allowHidden)
    local quests = DB[selectedDungeon].quests or {}
    if not quests[index] then return end

    allowHiddenQuestSelection = allowHidden == true
    selectedPrereqStep = nil
    selectedPrereqParentQuestName = nil
    selectedPrereqParentQuestID = nil
    RequestQuestRewardData(quests[index].id)

    selectedQuest = index
    ForeverDungeonJournalDB.lastQuest = index
    RefreshQuestList()
    RefreshQuestDetail()
end

-- hidedone (2.1.3): a quest handed in, left out of the list by the option;
-- opened on purpose (a link, the tracker, a search), its page still shows.
FDJ.QuestHiddenAsDone = function(quest)
    return type(quest) == "table" and ForeverDungeonJournalDB and ForeverDungeonJournalDB.hideDoneQuests == true
        and not quest.repeatable and quest.id ~= nil and FDJ.QuestTurnedIn(quest.id) == true
end

SelectQuestByID = function(questID)
    if not questID then return end
    local quests = DB[selectedDungeon].quests or {}
    for index, quest in ipairs(quests) do
        if quest.id == questID then
            -- questside (2.0.13, M 18 Nov 2026): a quest of the other faction
            -- opened by its id (the round !, a link): its faction's list.
            local side = quest.faction
            if (side == "Alliance" or side == "Horde") and side ~= selectedQuestFaction and not FDJ.FactionHiddenFor(selectedDungeon, side) then
                selectedQuestFaction = side
                ForeverDungeonJournalDB.questFaction = side
                UpdateFactionButtons()
                BuildVisibleQuestIndexes()
            end
            SelectQuest(index, quest.hideFromMainList == true or FDJ.QuestHiddenAsDone(quest)) -- (hidedone)
            return
        end
    end
end

local function MakeDungeonTab(parent, dungeonName, x)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(180, 31)
    button:SetPoint("TOPLEFT", x, -50)

    SetBackdrop(
        button,
        "Interface\\Buttons\\WHITE8X8",
        "Interface\\Tooltips\\UI-Tooltip-Border",
        9,
        2
    )

    button.text = button:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    button.text:SetPoint("CENTER")
    button.text:SetText(DungeonName(dungeonName))

    button:SetScript("OnClick", function()
        local dungeon = DB[dungeonName]
        if dungeon and dungeon.previewOnly and not FDJ.DUNGEON_MAPS[dungeonName] then return end
        SelectDungeon(dungeonName)
    end)

    dungeonTabs[dungeonName] = button
end

local function UpdateTabs()
    for name, tab in pairs(dungeonTabs) do
        if name == selectedDungeon then
            tab:SetBackdropColor(0.43, 0.23, 0.07, 1)
            tab.text:SetTextColor(1, 0.82, 0.27)
        else
            tab:SetBackdropColor(0.07, 0.065, 0.055, 0.98)
            tab.text:SetTextColor(0.77, 0.71, 0.62)
        end
    end
end


-- Loading screens have the World of Warcraft logo baked into the upper area.
-- Crop Deadmines/BFD lower so the home cards show only dungeon artwork.
FDJ.HomeLevelText = function(level)
    local value = tostring(level or "")
    value = value:gsub("%++$", "+")
    return "LV " .. value
end

local homeDungeonCards = {}
local homeEditMode = false
-- Dungeons hidden by hand are stored per character (ForeverDungeonJournalCharacterDB).
-- Older versions kept one account-wide list; the first character to log in
-- after the update takes it over and the account-wide copy is removed.
FDJ.HiddenDungeons = function()
    ForeverDungeonJournalCharacterDB = ForeverDungeonJournalCharacterDB or {}
    local char = ForeverDungeonJournalCharacterDB
    if not char.hiddenDungeons then
        local old = ForeverDungeonJournalDB and ForeverDungeonJournalDB.hiddenDungeons
        char.hiddenDungeons = {}
        if type(old) == "table" then
            for k, v in pairs(old) do char.hiddenDungeons[k] = v end
            ForeverDungeonJournalDB.hiddenDungeons = nil
        end
    end
    return char.hiddenDungeons
end


local function MakeHomeDungeonCard(parent, dungeonName)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button.dungeonName = dungeonName
    button:SetSize(352, 126)

    SetBackdrop(
        button,
        "Interface\\Buttons\\WHITE8X8",
        "Interface\\Tooltips\\UI-Tooltip-Border",
        12,
        3
    )
    button:SetBackdropColor(0.02, 0.02, 0.02, 0.45)
    button:SetBackdropBorderColor(0.34, 0.34, 0.34, 1)

    button.art = button:CreateTexture(nil, "ARTWORK", nil, 1)
    button.art:SetPoint("TOPLEFT", 4, -4)
    button.art:SetPoint("BOTTOMRIGHT", -4, 4)
    button.art:SetTexture(DUNGEON_HOME_ART[dungeonName])
    local crop = DUNGEON_HOME_TEXCOORD[dungeonName] or { 0.03, 0.97, 0.05, 0.95 }
    button.art:SetTexCoord(crop[1], crop[2], crop[3], crop[4])
    button.art:SetVertexColor(1, 1, 1, 1)
    button.art:SetAlpha(1)

    button.topShade = button:CreateTexture(nil, "ARTWORK", nil, 2)
    button.topShade:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.topShade:SetPoint("TOPLEFT", 4, -4)
    button.topShade:SetPoint("TOPRIGHT", -4, -4)
    button.topShade:SetHeight(42)
    button.topShade:SetColorTexture(0, 0, 0, 0.42)

    button.fullShade = button:CreateTexture(nil, "ARTWORK", nil, 0)
    button.fullShade:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.fullShade:SetPoint("TOPLEFT", 4, -4)
    button.fullShade:SetPoint("BOTTOMRIGHT", -4, 4)
    button.fullShade:SetColorTexture(0.02, 0.02, 0.02, 0.10)

    button.previewIcon = button:CreateTexture(nil, "ARTWORK", nil, 2)
    button.previewIcon:SetSize(62, 62)
    button.previewIcon:SetPoint("CENTER", 0, -5)
    button.previewIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.previewIcon:SetAlpha(0.55)
    button.previewIcon:Hide()

    button.innerGlow = button:CreateTexture(nil, "ARTWORK", nil, 3)
    button.innerGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.innerGlow:SetPoint("TOPLEFT", 4, -4)
    button.innerGlow:SetPoint("TOPRIGHT", -4, -4)
    button.innerGlow:SetHeight(1)
    button.innerGlow:SetColorTexture(1.0, 0.84, 0.25, 0.30)

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.highlight:SetPoint("TOPLEFT", 4, -4)
    button.highlight:SetPoint("BOTTOMRIGHT", -4, 4)
    button.highlight:SetColorTexture(1, 1, 1, 0.08)

    button.title = button:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalLarge")
    button.title:SetPoint("TOPLEFT", 16, -14)
    button.title:SetWidth(220)
    button.title:SetJustifyH("LEFT")
    button.title:SetJustifyV("TOP")
    button.title:SetText(DungeonName(dungeonName))
    button.title:SetTextColor(1.00, 0.88, 0.24)
    button.title:SetShadowColor(0, 0, 0, 1)
    button.title:SetShadowOffset(1, -1)

    button.meta = button:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    button.meta:SetPoint("BOTTOMLEFT", 14, 10)
    button.meta:SetPoint("RIGHT", -16, 0)
    button.meta:SetJustifyH("LEFT")
    button.meta:SetTextColor(1.00, 0.95, 0.82)
    button.meta:SetShadowColor(0, 0, 0, 1)
    button.meta:SetShadowOffset(1, -1)

    button.counts = button:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    button.counts:SetPoint("TOPRIGHT", -14, -11)
    button.counts:SetJustifyH("RIGHT")
    button.counts:SetTextColor(0.97, 0.89, 0.54)
    button.counts:SetShadowColor(0, 0, 0, 1)
    button.counts:SetShadowOffset(1, -1)

    button.coverBorder = button:CreateTexture(nil, "OVERLAY", nil, 4)
    button.coverBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.coverBorder:SetPoint("LEFT", 4, 0)
    button.coverBorder:SetPoint("RIGHT", -4, 0)
    button.coverBorder:SetHeight(1)
    button.coverBorder:SetColorTexture(1, 1, 1, 0.04)

    -- Edit-mode treatment. The cyan wash mirrors Blizzard's Edit Mode selection
    -- without replacing the dungeon artwork underneath.
    button.editOverlay = button:CreateTexture(nil, "OVERLAY", nil, 5)
    button.editOverlay:SetPoint("TOPLEFT", 4, -4)
    button.editOverlay:SetPoint("BOTTOMRIGHT", -4, 4)
    button.editOverlay:SetColorTexture(0.20, 0.78, 1.00, 0.18)
    button.editOverlay:Hide()

    button.editBorder = button:CreateTexture(nil, "OVERLAY", nil, 6)
    button.editBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.editBorder:SetPoint("TOPLEFT", 4, -4)
    button.editBorder:SetPoint("BOTTOMRIGHT", -4, 4)
    button.editBorder:SetColorTexture(0.35, 0.86, 1.00, 0.12)
    button.editBorder:Hide()

    button.hiddenShade = button:CreateTexture(nil, "OVERLAY", nil, 7)
    button.hiddenShade:SetPoint("TOPLEFT", 4, -4)
    button.hiddenShade:SetPoint("BOTTOMRIGHT", -4, 4)
    button.hiddenShade:SetColorTexture(0.02, 0.05, 0.08, 0.58)
    button.hiddenShade:Hide()

    button.hiddenText = button:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalHuge")
    button.hiddenText:SetPoint("CENTER", 0, 0)
    button.hiddenText:SetTextColor(1.00, 1.00, 1.00)
    button.hiddenText:SetShadowColor(0, 0, 0, 1)
    button.hiddenText:SetShadowOffset(1, -1)
    button.hiddenText:Hide()

    button:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1.00, 0.76, 0.22, 1)
        self.fullShade:SetColorTexture(1, 0.82, 0.18, 0.08)
        local activeDungeonName = self.dungeonName
        local dungeon = DB[activeDungeonName]
        if not homeEditMode and FDJ.RPGLockedTooltip and FDJ.IsDungeonLocked and FDJ.IsDungeonLocked(activeDungeonName) then
            pcall(FDJ.RPGLockedTooltip, self, activeDungeonName)
            return
        end
        -- Normal cards need no tooltip (the card already shows the name and
        -- clicking it is obvious); only Hide Dungeons mode and preview-only
        -- dungeons still explain themselves.
        if not homeEditMode and not (dungeon and dungeon.previewOnly) then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(DungeonName(activeDungeonName))
        if homeEditMode then
            -- keepshown (2.0.10): hidden by an auto-hide option: says which,
            -- and that a click shows it anyway
            local reason = not FDJ.HiddenDungeons()[activeDungeonName]
                and not (FDJ.ShownDungeons and FDJ.ShownDungeons()[activeDungeonName])
                and FDJ.DungeonAutoHideReason and FDJ.DungeonAutoHideReason(activeDungeonName) or nil
            if reason then
                GameTooltip:AddLine(L("AUTO_HIDDEN_BY", L(reason)), 1, 0.82, 0.27, true)
                GameTooltip:AddLine(L("CLICK_SHOW_ANYWAY"), 1, 1, 1, true)
            elseif FDJ.HiddenDungeons()[activeDungeonName] then
                GameTooltip:AddLine(L("CLICK_RESTORE_DUNGEON"), 1, 1, 1)
            else
                GameTooltip:AddLine(L("CLICK_HIDE_DUNGEON"), 1, 1, 1)
            end
        elseif dungeon and dungeon.previewOnly then
            GameTooltip:AddLine(L("PREVIEW_DATA_SOON"), 0.82, 0.78, 0.68, true)
            if FDJ.DUNGEON_MAPS[activeDungeonName] then GameTooltip:AddLine(L("PREVIEW_MAP_CLICK"), 1, 1, 1) end
        else
            GameTooltip:AddLine(L("CLICK_DUNGEON"), 1, 1, 1)
        end
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.34, 0.34, 0.34, 1)
        self.fullShade:SetColorTexture(0.02, 0.02, 0.02, 0.10)
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function(self)
        local activeDungeonName = self.dungeonName
        if not activeDungeonName then return end
        if homeEditMode then
            -- keepshown (2.0.10): a hidden card is shown again, also when an
            -- auto-hide option hides it (it is then kept shown anyway); a shown
            -- card is hidden by hand.
            local hidden = FDJ.HiddenDungeons()
            local shown = FDJ.ShownDungeons and FDJ.ShownDungeons() or {}
            local autoHidden = FDJ.IsDungeonAutoHidden and FDJ.IsDungeonAutoHidden(activeDungeonName) or false
            if hidden[activeDungeonName] or autoHidden then
                hidden[activeDungeonName] = nil
                if FDJ.IsDungeonAutoHidden and FDJ.IsDungeonAutoHidden(activeDungeonName, nil, true) then
                    shown[activeDungeonName] = true
                end
            else
                hidden[activeDungeonName] = true
                shown[activeDungeonName] = nil
            end
            PlayJournalOptionSound()
            RefreshHomeDungeonCards()
            -- the tooltip says what the next click does
            if GameTooltip:IsOwned(self) then
                local onEnter = self:GetScript("OnEnter")
                if onEnter then pcall(onEnter, self) end
            end
            return
        end
        -- rpgdone (2.0.8): a locked page opens a small box (the locked text
        -- and "I already did this dungeon"), Systems/RPGMode.lua.
        if FDJ.ShowRPGDoneBox and FDJ.IsDungeonLocked and FDJ.IsDungeonLocked(activeDungeonName) then
            FDJ.ShowRPGDoneBox(activeDungeonName)
            return
        end
        SelectDungeon(activeDungeonName)
    end)

    return button
end

-- Used by Systems/SettingsPanel.lua.
FDJ.IsQuestFinished = IsQuestFinished
-- questtracker: the on-screen quest tracker (Systems/QuestText.lua) reads
-- the quest log and the list's faction/class filter through these.
FDJ.IsQuestInLog = IsQuestInLog
FDJ.QuestMatchesFaction = QuestMatchesFaction
FDJ.RefreshHomeCards = function()
    -- turnstutter: only while the home page is on screen. Rebuilding every
    -- card with the journal closed (a second after each quest turn-in, on a
    -- dungeon unlock...) was a ~60 ms hitch for nothing: ShowHomePage
    -- rebuilds them anyway whenever the home page is shown.
    if not frame or not frame:IsShown() or frame.currentView ~= "home" then return end
    if frame.homePanel and not frame.homePanel:IsVisible() then return end
    if RefreshHomeDungeonCards then RefreshHomeDungeonCards() end
end

RefreshHomeDungeonCards = function()
    if not frame or not frame.homeCardsContent or not frame.homeScroll then return end

    local shownDungeons = {}
    for _, dungeonName in ipairs(ORDER) do
        -- RPG Mode: locked dungeons always show (as sketches) and can't be
        -- hidden, so the hide editor only lists unlocked ones.
        local rpgLocked = FDJ.IsDungeonLocked and FDJ.IsDungeonLocked(dungeonName)
        if not homeEditMode and FDJ.HomeFilterHides and FDJ.HomeFilterHides(dungeonName) then
            -- WoW Forever emblem filter: only Forever's new dungeons.
        elseif rpgLocked then
            if not homeEditMode then shownDungeons[#shownDungeons + 1] = dungeonName end
        elseif homeEditMode or not (FDJ.HiddenDungeons()[dungeonName]
            or (FDJ.IsDungeonAutoHidden and FDJ.IsDungeonAutoHidden(dungeonName))) then
            shownDungeons[#shownDungeons + 1] = dungeonName
        end
    end

    -- resizeframe (2.0.10 test): a wider window fits more columns of cards,
    -- each at least as wide as in the normal window (2 columns at least).
    local gap = 12
    local cols = math.max(2, math.floor(((frame.homePanel:GetWidth() or 814) - 51 + gap) / (383 + gap)))
    local rows = math.max(1, math.ceil(#shownDungeons / cols))
    local rowStep = 138
    local contentHeight = (#shownDungeons == 0) and 126 or (rows * rowStep - 12)
    local viewportHeight = frame.homeScroll:GetHeight() or 0
    local needsScroll = viewportHeight > 0 and contentHeight > viewportHeight + 4

    -- Do not reserve a dead scrollbar gutter when every dungeon already fits.
    frame.homeScroll:ClearAllPoints()
    frame.homeScroll:SetPoint("TOPLEFT", frame.homePanel, "TOPLEFT", 18, -72)
    frame.homeScroll:SetPoint("BOTTOMRIGHT", frame.homePanel, "BOTTOMRIGHT", needsScroll and -31 or -15, 15)

    local contentWidth = math.max(700, (frame.homeScroll:GetWidth() or 760) - 2)
    local cardWidth = math.floor((contentWidth - gap * (cols - 1)) / cols)
    frame.homeCardsContent:SetWidth(contentWidth)

    for i, dungeonName in ipairs(shownDungeons) do
        local dungeon = DB[dungeonName]
        local card = homeDungeonCards[i]

        if not card then
            card = MakeHomeDungeonCard(frame.homeCardsContent, dungeonName)
            homeDungeonCards[i] = card
        end

        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        card.dungeonName = dungeonName

        -- Every dungeon tile keeps exactly the same dimensions. If the final
        -- row has an odd number of dungeons, the unused slot simply stays empty.
        card:SetWidth(cardWidth)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", frame.homeCardsContent, "TOPLEFT", col * (cardWidth + gap), -row * rowStep)

        card.title:SetText(DungeonName(dungeonName))
        card.meta:SetText(FDJ.HomeLevelText(dungeon.level))
        local playerFaction = "Alliance"
        if UnitFactionGroup then
            local detectedFaction = UnitFactionGroup("player")
            if detectedFaction == "Horde" then playerFaction = "Horde" end
        end

        local factionQuestCount, finishedCount = 0, 0
        for _, quest in ipairs(dungeon.quests or {}) do
            if QuestMatchesFaction(quest, playerFaction) and not quest.hideFromMainList and not quest.repeatable
                and FDJ.QuestCountsForCharacter(quest) -- otherclass (2.0.8): another class's: not counted
                and not FDJ.IsQuestLost(quest) then -- lostquest
                factionQuestCount = factionQuestCount + 1
                -- questdone: handed in only (ready to turn in is not done yet).
                if quest.id and FDJ.QuestTurnedIn(quest.id) then finishedCount = finishedCount + 1 end
            end
        end

        -- Green tick in front when every quest of this dungeon is done.
        local allDone = factionQuestCount > 0 and finishedCount == factionQuestCount
            and not ForeverDungeonJournalDB.hideDoneTick
        -- bossdone (2.0.8): no quest here for this character: the tick once
        -- the last boss has been killed (its tooltip says so).
        card.fdjTickBoss = nil
        if not allDone and factionQuestCount == 0 and not ForeverDungeonJournalDB.hideDoneTick
            and FDJ.LastBossKilled and FDJ.LastBossKilled(dungeonName) then
            allDone = true
            card.fdjTickBoss = true
        end
        if not card.doneTick then
            card.doneGlow = card:CreateTexture(nil, "OVERLAY", nil, 5)
            card.doneGlow:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\TickGlow")
            card.doneGlow:SetBlendMode("ADD")
            card.doneGlow:SetAlpha(0.55)
            card.doneGlow:SetSize(34, 34)
            -- Open ring around the tick; its long stroke leaves through the gap.
            card.doneRing = card:CreateTexture(nil, "OVERLAY", nil, 6)
            card.doneRing:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\TickRing")
            card.doneRing:SetSize(22, 22)
            card.doneRing:SetPoint("RIGHT", card.counts, "LEFT", -3, 0)

            card.doneTick = card:CreateTexture(nil, "OVERLAY", nil, 7)
            card.doneTick:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
            card.doneTick:SetSize(17, 17)
            card.doneTick:SetPoint("CENTER", card.doneRing, "CENTER", 2, 2)
            card.doneGlow:SetPoint("CENTER", card.doneRing, "CENTER", 0, 0)
            if FDJ.AttachDoneTickTooltip then FDJ.AttachDoneTickTooltip(card) end
        end
        card.doneRing:SetShown(allDone)
        card.doneTick:SetShown(allDone)
        card.doneGlow:SetShown(allDone)
        local factionIcon = playerFaction == "Horde" and HORDE_ICON or ALLIANCE_ICON
        card.counts:SetText(
            "|T" .. factionIcon .. ":22:22:0:0|t "
            -- "2/6 quests" once at least one is done; just "6 quests" before that.
            .. ((finishedCount > 0) and (finishedCount .. "/" .. factionQuestCount) or tostring(factionQuestCount))
            .. " " .. (factionQuestCount == 1 and L("QUEST") or L("QUESTS_LOWER"))
        )
        local art = DUNGEON_HOME_ART[dungeonName]
        if art then
            card.art:SetTexture(art)
            card.art:SetVertexColor(1, 1, 1, 1)
        else
            card.art:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
            card.art:SetVertexColor(0.42, 0.36, 0.28, 1)
        end
        local crop = DUNGEON_HOME_TEXCOORD[dungeonName] or { 0.03, 0.97, 0.05, 0.95 }
        card.art:SetTexCoord(crop[1], crop[2], crop[3], crop[4])
        if FDJ.ApplyHomeBottomBand then pcall(FDJ.ApplyHomeBottomBand, card, dungeonName) end
        if card.previewIcon then card.previewIcon:Hide() end
        -- Announced dungeons: a centred "Coming Soon" instead of art and counts.
        if dungeon.previewOnly and not card.comingSoon then
            card.comingSoon = card:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalHuge")
            card.comingSoon:SetPoint("CENTER", 0, -6)
            card.comingSoon:SetTextColor(1.00, 0.82, 0.20)
            card.comingSoon:SetShadowColor(0, 0, 0, 1)
            card.comingSoon:SetShadowOffset(1, -1)
        end
        if card.comingSoon then
            card.comingSoon:SetText(L("COMING_SOON"))
            card.comingSoon:SetShown(dungeon.previewOnly == true)
        end
        if dungeon.previewOnly then
            card.counts:SetText("")
            if art then card.art:SetVertexColor(0.8, 0.8, 0.8, 1) end
        end

        local isHidden = FDJ.HiddenDungeons()[dungeonName] == true
            or (FDJ.IsDungeonAutoHidden and FDJ.IsDungeonAutoHidden(dungeonName)) or false
        if card.editOverlay then card.editOverlay:SetShown(homeEditMode) end
        if card.editBorder then card.editBorder:SetShown(homeEditMode) end
        if card.hiddenShade then card.hiddenShade:SetShown(homeEditMode and isHidden) end
        if card.hiddenText then
            card.hiddenText:SetText(L("HIDDEN"))
            card.hiddenText:SetShown(homeEditMode and isHidden)
        end
        if homeEditMode then
            card:SetBackdropBorderColor(0.34, 0.82, 1.00, 1)
        else
            card:SetBackdropBorderColor(0.34, 0.34, 0.34, 1)
        end
        if FDJ.ApplyRPGCard then pcall(FDJ.ApplyRPGCard, card, dungeonName, homeEditMode) end
        card:Show()
    end

    for i = #shownDungeons + 1, #homeDungeonCards do
        if homeDungeonCards[i] then homeDungeonCards[i]:Hide() end
    end

    if frame.homeEmptyText then
        local empty = #shownDungeons == 0 and not homeEditMode
        -- levelempty (2.0.9, M 16 Nov 2026): empty only because of "Show only
        -- my level range": say so (too low for any dungeon: the level the
        -- first ones start at), with "Show all dungeons anyway" under it.
        local levelEmpty, lowest = false, nil
        if empty and ForeverDungeonJournalDB.onlyMyLevelRange then
            for _, dungeonName in ipairs(ORDER) do
                if not (FDJ.HomeFilterHides and FDJ.HomeFilterHides(dungeonName))
                    and not FDJ.HiddenDungeons()[dungeonName]
                    and not (FDJ.IsDungeonAutoHidden and FDJ.IsDungeonAutoHidden(dungeonName, true)) then
                    levelEmpty = true
                    local low = FDJ.DungeonLevelRange and FDJ.DungeonLevelRange(DB[dungeonName])
                    if low and (not lowest or low < lowest) then lowest = low end
                end
            end
        end
        local listLevel = FDJ.ListLevel and FDJ.ListLevel()
        if levelEmpty and listLevel and lowest and listLevel < lowest then
            frame.homeEmptyText:SetText(L("LEVEL_TOO_LOW_DUNGEONS", lowest))
        elseif levelEmpty then
            frame.homeEmptyText:SetText(L("NO_DUNGEONS_MY_LEVEL"))
        else
            frame.homeEmptyText:SetText(L("ALL_DUNGEONS_HIDDEN"))
        end
        frame.homeEmptyText:SetShown(empty)
        if frame.homeShowAllButton then
            frame.homeShowAllButton.text:SetText(L("SHOW_ALL_DUNGEONS_ANYWAY"))
            frame.homeShowAllButton:SetWidth(math.max(160, math.ceil((frame.homeShowAllButton.text:GetStringWidth() or 140) + 32)))
            frame.homeShowAllButton:SetShown(levelEmpty)
        end
    end

    frame.homeCardsContent:SetHeight(contentHeight)
    UpdateScrollBarVisibility(frame.homeScroll, contentHeight)
    if FDJ.UpdateRPGHeader then pcall(FDJ.UpdateRPGHeader, frame) end
end

RefreshBossList = function()
    local dungeon = DB[selectedDungeon]
    local listY = 0 -- altarbosses (2.0.24): rows are placed by their heights
    -- altarbosses (2.0.25): the page shown is a child (opened from a
    -- favourite, a tooltip, the last session): its group opens.
    local shownBoss = dungeon.bosses[selectedBoss]
    if type(shownBoss) == "table" and shownBoss.childOf and not FDJ.BossGroupOpen(selectedDungeon, shownBoss.childOf) then
        FDJ.SetBossGroupOpen(selectedDungeon, shownBoss.childOf, true)
    end

    -- bosscompact (2.0.10, M 17 Nov 2026: "add the compact views to bosses
    -- that have many lines and have to scroll to see all"): a boss list that
    -- needs scrolling gets a Compact view / Detailed view button at the top
    -- right of the list, like the loot list's. Compact rows are smaller (small
    -- portrait, level medallion and name), so many more bosses fit. One choice
    -- for every list, kept between sessions (like the loot's compactall); a
    -- list that fits anyway stays detailed and shows no button.
    local bossMany = false
    local stretch = 1 -- fillrows: detailed rows grown to fill the list
    do
        local h, rows, count = 0, 0, 0
        for _, b in ipairs(dungeon.bosses) do
            local child = type(b) == "table" and b.childOf ~= nil
            local hidden = (child and not FDJ.BossGroupOpen(selectedDungeon, b.childOf))
                or (type(b) == "table" and b.listHidden)
            if not hidden then
                h = h + (child and FDJ.BOSS_CHILD_HEIGHT or 55) + 6
                rows = rows + (child and FDJ.BOSS_CHILD_HEIGHT or 55)
                count = count + 1
            end
        end
        local vp = frame.bossListScroll and frame.bossListScroll:GetHeight() or 0
        bossMany = vp > 0 and h > vp + 4
        -- fillrows (M 17 Nov 2026: "can we avoid the dead space even in
        -- detailed view, show them all in one page but make them bigger so
        -- they fit"): a detailed list shorter than the list's height has its
        -- rows (portraits, level medallions) grown to fill it, up to 1.45x.
        if not bossMany and vp > 0 and rows > 0 then
            stretch = math.max(1, math.min(1.45, (vp - (count - 1) * 6) / rows))
        end
    end
    -- nocompactbosses (2.0.10, M 17 Nov 2026: "No compact view for bosses as
    -- of now. I'll think about it later"): the boss list is always detailed
    -- and has no Compact view button; the compact code stays here, unused.
    local compact = false
    FDJ.bossListCompact = compact
    -- textbosses (2.0.10, M 17 Nov 2026: "in the compact view I would like
    -- the bosses to just be without their portrait and in alphabetical order.
    -- Trash and recipes should always stay at the bottom ... just in a text
    -- line"): a dungeon's compact list is names only, A to Z. (The Loot
    -- Filter's and a recipe search's lists keep their portraits and order.)
    local textList = compact and not (dungeon.lootFilterPage or dungeon.recipeSearch)
    local gap = compact and 4 or 6
    -- bosscolumns (M 17 Nov 2026: "in the boss compact view can we avoid
    -- scrolling completely and possibly add another column"): compact rows
    -- in two columns, read down the left one, then the right one, each row as
    -- tall as lets the whole list fit without scrolling (32 down to 20 px;
    -- only a list too long even then still scrolls). The RARE and faction
    -- labels give way to the name (the silver frame and the crest stay).
    local colRows, rowH, colW, visIndex = 0, 32, 315, 0
    if compact then
        local visible = 0
        for _, b in ipairs(dungeon.bosses) do
            local child = type(b) == "table" and b.childOf ~= nil
            local hidden = (child and not FDJ.BossGroupOpen(selectedDungeon, b.childOf))
                or (type(b) == "table" and b.listHidden)
            if not hidden then visible = visible + 1 end
        end
        colRows = math.max(1, math.ceil(visible / 2))
        if colRows > 12 then gap = 2 end
        local vp = frame.bossListScroll and frame.bossListScroll:GetHeight() or 0
        if vp > 0 then
            -- fillrows: up to 64 px, so a short list fills the page too
            -- (textbosses: text rows up to 30 px)
            rowH = math.max(20, math.min(textList and 30 or 64, math.floor((vp - (colRows - 1) * gap) / colRows)))
        end
        colW = math.floor((315 - 6) / 2)
    end
    -- textbosses: the rows' order: the bosses A to Z (a group's bosses A to Z
    -- under it), then Trash Drops, Recipes & Patterns and the chests as they
    -- come in the list.
    local textPos
    if textList then
        textPos = {}
        local tops, kids, bottom = {}, {}, {}
        for i, b in ipairs(dungeon.bosses) do
            if type(b) == "table" then
                local child = b.childOf ~= nil
                local folded = (child and not FDJ.BossGroupOpen(selectedDungeon, b.childOf)) or b.listHidden
                if not folded then
                    local view = FDJ.RPGBossView and FDJ.RPGBossView(selectedDungeon, b) or b
                    local key = string.lower(tostring(BossName(view.name) or ""))
                    if b.trash or b.recipeTab or b.lootChest then
                        bottom[#bottom + 1] = i
                    elseif child then
                        kids[b.childOf] = kids[b.childOf] or {}
                        table.insert(kids[b.childOf], { i = i, key = key })
                    else
                        tops[#tops + 1] = { i = i, key = key, name = b.name }
                    end
                end
            end
        end
        local function AZ(a, c)
            if a.key == c.key then return a.i < c.i end
            return a.key < c.key
        end
        table.sort(tops, AZ)
        local n = 0
        for _, t in ipairs(tops) do
            textPos[t.i] = n
            n = n + 1
            local list = kids[t.name]
            kids[t.name] = nil
            if list then
                table.sort(list, AZ)
                for _, k in ipairs(list) do textPos[k.i] = n n = n + 1 end
            end
        end
        for _, list in pairs(kids) do -- (a group not shown: its bosses anyway)
            for _, k in ipairs(list) do textPos[k.i] = n n = n + 1 end
        end
        for _, i in ipairs(bottom) do textPos[i] = n n = n + 1 end
    end
    if false and bossMany and not frame.bossCompactButton and frame.leftPanel then -- nocompactbosses
        local cb = CreateFrame("Button", nil, frame.leftPanel, "BackdropTemplate")
        frame.bossCompactButton = cb
        cb:SetSize(104, 20)
        SetBackdrop(cb, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 9, 2)
        cb:SetBackdropColor(0.12, 0.10, 0.08, 0.95)
        cb:SetBackdropBorderColor(0.52, 0.33, 0.11, 1)
        cb.text = cb:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
        cb.text:SetPoint("CENTER")
        cb:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        cb:SetPoint("TOPRIGHT", frame.leftPanel, "TOPRIGHT", -14, -11)
        cb:SetScript("OnClick", function()
            if type(ForeverDungeonJournalDB) == "table" then
                ForeverDungeonJournalDB.compactBosses = not (ForeverDungeonJournalDB.compactBosses == true) or nil
            end
            PlayJournalOptionSound()
            RefreshBossList()
        end)
    end
    if frame.bossCompactButton then
        frame.bossCompactButton:SetShown(false) -- nocompactbosses
        frame.bossCompactButton.text:SetText(L(compact and "LOOT_DETAILED" or "LOOT_COMPACT"))
    end

    for i = 1, math.max(#bossButtons, #dungeon.bosses) do
        local button = bossButtons[i]

        if i <= #dungeon.bosses then
            if not button then
                button = MakeBossButton(frame.bossContent)
                bossButtons[i] = button
            end
            -- altarbosses (2.0.24): a boss with childOf (the Sunken Temple's
            -- six troll guardians under "Altar Bosses") is a smaller row, set
            -- in under its parent, with a guide line down to it. Every row
            -- is placed again on each refresh (a dungeon's list can have
            -- children where the last one shown had none).
            local isChild = type(dungeon.bosses[i]) == "table" and dungeon.bosses[i].childOf ~= nil
            -- altarbosses (2.0.25): a folded group's children take no room.
            local folded = isChild and not FDJ.BossGroupOpen(selectedDungeon, dungeon.bosses[i].childOf)
            -- lbrsrecipes (2.0.7): an entry that only feeds the Recipes & Patterns
            -- page (Lower Blackrock Spire's trash recipes) takes no row: its
            -- own page would be empty, the recipes are listed there.
            if type(dungeon.bosses[i]) == "table" and dungeon.bosses[i].listHidden then folded = true end
            local rowHeight = isChild and FDJ.BOSS_CHILD_HEIGHT or 55
            button:ClearAllPoints()
            if compact then
                -- bosscolumns: down the left column, then the right one
                rowHeight = rowH
                local pos = (textPos and textPos[i]) or visIndex -- textbosses: A to Z
                local col = pos < colRows and 0 or 1
                local rowInCol = col == 0 and pos or (pos - colRows)
                local indent = isChild and 8 or 0
                button:SetPoint("TOPLEFT", frame.bossContent, "TOPLEFT", col * (colW + 6) + indent, -rowInCol * (rowH + gap))
                button:SetSize(colW - indent, rowH)
                if not folded then visIndex = visIndex + 1 end
            else
                button:SetPoint("TOPLEFT", frame.bossContent, "TOPLEFT", isChild and FDJ.BOSS_CHILD_INDENT or 0, -listY)
                rowHeight = math.floor(rowHeight * stretch) -- fillrows
                button:SetSize(isChild and (315 - FDJ.BOSS_CHILD_INDENT) or 315, rowHeight)
                if not folded then listY = listY + rowHeight + gap end
            end
            local face = compact and math.max(16, math.min(44, rowH - 6)) or math.floor((isChild and 34 or 44) * stretch + 0.5) -- fillrows
            button.portrait:SetSize(face, face)
            button.rareBorder:SetSize(face * 64 / 44, face * 64 / 44)
            local badge = compact and math.max(14, math.min(20, face - 6)) or math.floor((isChild and 24 or 28) * math.min(stretch, 1.25) + 0.5) -- fillrows
            button.levelBadge:SetSize(badge, badge)
            button.levelBadge:ClearAllPoints()
            button.levelBadge:SetPoint("CENTER", button.portrait, "BOTTOMLEFT", compact and 4 or 8, 2)
            button.name:SetFontObject((compact and rowH < 44) and "ForeverDJ_GameFontNormalSmall" or "ForeverDJ_GameFontNormal") -- fillrows: tall compact rows, the usual size
            -- bosscolumns: two lines of name where the row has room, else one
            if button.name.SetMaxLines then button.name:SetMaxLines(compact and (rowH >= 28 and 2 or 1) or 0) end
            button.question:SetFontObject(compact and "ForeverDJ_GameFontNormalLarge" or "ForeverDJ_GameFontNormalHuge")
            if isChild and not button.childLine then
                button.childLine = button:CreateTexture(nil, "BACKGROUND")
                button.childLine:SetColorTexture(0.52, 0.33, 0.11, 0.9)
                button.childTick = button:CreateTexture(nil, "BACKGROUND")
                button.childTick:SetColorTexture(0.52, 0.33, 0.11, 0.9)
            end
            if button.childLine then
                if isChild then
                    -- the line runs up through the 6px gap to the row above;
                    -- the last child's stops at its middle.
                    local nextBoss = dungeon.bosses[i + 1]
                    local last = not (type(nextBoss) == "table" and nextBoss.childOf ~= nil)
                    button.childLine:ClearAllPoints()
                    button.childLine:SetWidth(2)
                    button.childLine:SetPoint("TOP", button, "TOPLEFT", -FDJ.BOSS_CHILD_INDENT / 2, gap)
                    if last then
                        button.childLine:SetPoint("BOTTOM", button, "LEFT", -FDJ.BOSS_CHILD_INDENT / 2, 0)
                    else
                        button.childLine:SetPoint("BOTTOM", button, "BOTTOMLEFT", -FDJ.BOSS_CHILD_INDENT / 2, 0)
                    end
                    button.childTick:ClearAllPoints()
                    button.childTick:SetHeight(2)
                    button.childTick:SetPoint("LEFT", button, "LEFT", -FDJ.BOSS_CHILD_INDENT / 2, 0)
                    button.childTick:SetPoint("RIGHT", button, "LEFT", 0, 0)
                end
                button.childLine:SetShown(isChild and not compact) -- bosscolumns: no guide lines across columns
                button.childTick:SetShown(isChild and not compact)
            end

            -- rpgpartial: RPG Mode, a boss not killed yet is a ? ("???").
            local boss = FDJ.RPGBossView and FDJ.RPGBossView(selectedDungeon, dungeon.bosses[i]) or dungeon.bosses[i]
            button.index = i
            if boss.fdjDungeon then
                -- Loot Filter page: bosses from every dungeon share one list.
                button.name:SetText(BossName(boss.name) .. "\n|cffb8ab94" .. DungeonName(boss.fdjDungeon) .. "|r")
            else
                button.name:SetText(BossName(boss.name))
            end

            local isRare = boss.rare == true
            button.fdjRareLabel = boss.rareLabel
            button.rare:SetText((button.fdjRareLabel and FDJ.RareLabelText and FDJ.RareLabelText(button.fdjRareLabel)) or button.fdjRareLabel or L("RARE")) -- darkreaver (2.0.8)
            button.rare:SetShown(isRare)
            -- v1.0.29: rares use a dedicated silver-dragon portrait overlay.
            -- Bosses with a fully bundled custom portrait (currently Lordaeron Captain)
            -- already include the dragon frame in the art, so do not overlay a second one.
            button.rareBorder:SetShown(isRare)
            button.name:ClearAllPoints()
            if textList then
                button.name:SetPoint("LEFT", button, "LEFT", 10, 0) -- textbosses
            else
                button.name:SetPoint("LEFT", button.portrait, "RIGHT", compact and 8 or 11, 1)
            end
            if compact then
                button.rare:Hide() -- bosscolumns: the name takes the room
                button.name:SetPoint("RIGHT", -4, 0)
            elseif isRare then
                button.name:SetPoint("RIGHT", button.rare, "LEFT", -8, 0)
            else
                button.name:SetPoint("RIGHT", -10, 0)
            end
            if FDJ.ApplyBossFactionTag then FDJ.ApplyBossFactionTag(button, boss, isRare) end
            if compact and button.fdjFactionTag and button.fdjFactionTag:IsShown() then
                -- bosscolumns: the crest alone at the row's end
                button.fdjFactionTag:Hide()
                button.fdjFactionIcon:ClearAllPoints()
                button.fdjFactionIcon:SetPoint("RIGHT", button, "RIGHT", -4, 0)
                button.name:SetPoint("RIGHT", button.fdjFactionIcon, "LEFT", -4, 0)
            end
            if FDJ.ApplyResultQuestMark then FDJ.ApplyResultQuestMark(button, boss) end -- resultquest

            if textList then
                -- textbosses: no portrait (nor its pair, frame or ?)
                if FDJ.ReleasePortrait then pcall(FDJ.ReleasePortrait, button.portrait) end
                button.portrait:SetTexture(nil)
                button.portrait:Hide()
                button.rareBorder:Hide()
                button.question:Hide()
                local pair = button.fdjPair
                if pair then
                    if FDJ.ReleasePortrait then pcall(FDJ.ReleasePortrait, pair) end
                    pair:SetTexture(nil)
                    pair:Hide()
                end
            else
            button.portrait:Show()
            local hasPortrait = SetBossPortrait(
                button.portrait,
                selectedDungeon,
                boss
            )
            button.question:SetShown(not hasPortrait)
            do -- pairportrait (2.0.9): two portraits side by side, no rare frame
                local second = FDJ.SetPairPortrait(button, button.portrait, boss, face,
                    compact and math.max(14, face - 2) or math.floor((isChild and 30 or 38) * stretch + 0.5)) -- bosscolumns, fillrows
                if second then
                    button.rareBorder:Hide()
                    button.name:SetPoint("LEFT", second, "RIGHT", 9, 1)
                end
            end
            end

            local bossLevel = BossLevelText(selectedDungeon, boss)
            -- nolevel (M 17 Nov 2026: "get rid of the level in compact view"):
            -- compact rows show no level medallion (the boss page still does)
            if bossLevel and not compact then
                button.levelText:SetText(bossLevel)
                FitBossLevelText(button.levelText, bossLevel)
                button.levelBadge:Show()
                button.levelText:Show()
            else
                button.levelBadge:Hide()
                button.levelText:Hide()
            end

            local theme = THEMES[selectedDungeon] or THEMES["Hall of Thanes"]

            if selectedBoss == i then
                button:SetBackdropColor(unpack(theme.rowSelected))
                button:SetBackdropBorderColor(unpack(theme.border))
                button.name:SetTextColor(unpack(theme.title))
            else
                button:SetBackdropColor(unpack(theme.row))
                button:SetBackdropBorderColor(unpack(theme.border))
                button.name:SetTextColor(unpack(theme.muted))
            end

            -- altarbosses (2.0.25): a group's row ("Altar Bosses") has a + at
            -- its right that unfolds its children; a - folds them again.
            local raw = dungeon.bosses[i]
            local isGroup = type(raw) == "table" and type(raw.children) == "table" and not raw.fdjDungeon
            if isGroup and not button.groupToggle then
                local tg = CreateFrame("Button", nil, button)
                tg:SetSize(20, 20)
                tg:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
                tg:SetScript("OnClick", function(self)
                    local d = DB[selectedDungeon]
                    if not d or not self.fdjGroup then return end
                    local open = not FDJ.BossGroupOpen(selectedDungeon, self.fdjGroup)
                    FDJ.SetBossGroupOpen(selectedDungeon, self.fdjGroup, open)
                    PlayJournalOptionSound()
                    -- Folding away the child whose page is shown: the group's
                    -- page instead.
                    local sel = d.bosses[selectedBoss]
                    if not open and type(sel) == "table" and sel.childOf == self.fdjGroup then
                        for j, b in ipairs(d.bosses) do
                            if type(b) == "table" and b.name == self.fdjGroup then SelectBoss(j) return end
                        end
                    end
                    RefreshBossList()
                end)
                button.groupToggle = tg
            end
            if button.groupToggle then
                button.groupToggle:SetShown(isGroup)
                if isGroup then
                    local open = FDJ.BossGroupOpen(selectedDungeon, raw.name)
                    local art = open and "Interface\\Buttons\\UI-MinusButton-" or "Interface\\Buttons\\UI-PlusButton-"
                    button.groupToggle:SetNormalTexture(art .. "Up")
                    button.groupToggle:SetPushedTexture(art .. "Down")
                    button.groupToggle.fdjGroup = raw.name
                    button.groupToggle.fdjOpen = open
                    -- altarbosses (2.0.26): the + right after the name (at the
                    -- row's far end it was easy to miss): the name only as wide
                    -- as its text, the + just past it.
                    button.name:ClearAllPoints()
                    local room
                    if textList then -- textbosses
                        button.name:SetPoint("LEFT", button, "LEFT", 10, 0)
                        room = (button:GetWidth() or 150) - 10 - 6 - 20 - 6
                    else
                        button.name:SetPoint("LEFT", button.portrait, "RIGHT", 11, 1)
                        room = (button:GetWidth() or 315) - 7 - (button.portrait:GetWidth() or 44) - 11 - 6 - 20 - 10
                    end
                    local textWidth = tonumber(button.name:GetStringWidth()) or 0
                    if textWidth < 10 then textWidth = room end -- width not known yet: as far as it can go
                    button.name:SetWidth(math.max(20, math.min(math.ceil(textWidth) + 2, room)))
                    button.groupToggle:ClearAllPoints()
                    button.groupToggle:SetPoint("LEFT", button.name, "RIGHT", 6, 0)
                end
            end

            button:SetShown(not folded)
        elseif button then
            button:Hide()
        end
    end

    if compact then listY = colRows * (rowH + gap) - gap end -- bosscolumns
    local contentHeight = math.max(1, listY) -- altarbosses (2.0.24): was #bosses * 61
    frame.bossContent:SetHeight(contentHeight)
    UpdateScrollBarVisibility(frame.bossListScroll, contentHeight)
    do -- bosscompact: a compact list is shorter, so keep the scroll inside it
        local maxScroll = math.max(0, contentHeight - (frame.bossListScroll:GetHeight() or 0))
        if (frame.bossListScroll:GetVerticalScroll() or 0) > maxScroll then
            frame.bossListScroll:SetVerticalScroll(maxScroll)
        end
    end
end

-- malletchain: on the boss page of a boss with chainButton = { page, quest,
-- label } (Gahz'rilla: How to get the Mallet), a red button in the header
-- beside the portrait, under the boss's name (and its Summoned by line),
-- opening that quest chain page at the step not done yet.
FDJ.SetBossChainButton = function(boss)
    local chain = type(boss) == "table" and not boss.fdjDungeon and boss.chainButton or nil
    local b = frame and frame.bossChainButton
    if not chain then
        if b then b:Hide() end
        return
    end
    if not b then
        b = CreateFrame("Button", nil, frame.selectedBossName:GetParent(), "UIPanelButtonTemplate")
        FDJ.OwnFonts(b) -- ownfonts (2.0.8)
        b:SetSize(230, 24)
        b:SetScript("OnClick", function(self)
            local c = self.chain
            if not (c and FDJ.OpenQuestChain) then return end
            local stepID
            for _, step in ipairs((QUEST_PREREQ_CHAINS and QUEST_PREREQ_CHAINS[c.quest]) or {}) do
                if type(step) == "table" and step.id and not FDJ.QuestTurnedIn(step.id) then stepID = step.id break end
            end
            FDJ.OpenQuestChain(c.page, c.quest, stepID)
        end)
        frame.bossChainButton = b
    end
    b.chain = chain
    b:SetText(L(chain.label))
    b:ClearAllPoints()
    local below = (frame.selectedBossType and frame.selectedBossType:IsShown()) and frame.selectedBossType or frame.selectedBossName
    b:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -6)
    b:Show()
end

-- bossquest (2.0.8, M 15 Nov 2026): on the boss page of a boss with
-- questLink = { id, name } (Ezra Grimm: The Great Fras Siabi), the quest's
-- name right of the boss's name, after a !; a click opens the quest's page.
-- It takes the room left on that line and is cut short to fit.
FDJ.SetBossQuestLink = function(boss)
    local link = type(boss) == "table" and not boss.fdjDungeon and type(boss.questLink) == "table" and boss.questLink or nil
    local b = frame and frame.bossQuestLink
    if not link then
        if b then b:Hide() end
        return
    end
    if not b then
        b = CreateFrame("Button", nil, frame.selectedBossName:GetParent())
        b:SetHeight(22)
        b:SetFrameLevel((frame.selectedBossName:GetParent():GetFrameLevel() or 1) + 5)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(20, 20)
        b.icon:SetPoint("LEFT", b, "LEFT", 0, 0)
        b.icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
        b.text = b:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 2, 0)
        b.text:SetJustifyH("LEFT")
        if b.text.SetWordWrap then b.text:SetWordWrap(false) end
        b.text:SetTextColor(1.00, 0.82, 0.00)
        b:SetScript("OnClick", function(self)
            local l = self.link
            if l and FDJ.OpenQuestPage then FDJ.OpenQuestPage(l.dungeon or selectedDungeon, l.id) end
        end)
        b:SetScript("OnEnter", function(self)
            self.text:SetTextColor(1, 1, 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.text:GetText() or "", 1.00, 0.82, 0.00)
            GameTooltip:AddLine(L("BOSS_QUEST_TIP"), 0.35, 1.00, 0.35)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self)
            self.text:SetTextColor(1.00, 0.82, 0.00)
            GameTooltip:Hide()
        end)
        frame.bossQuestLink = b
    end
    b.link = link
    b.text:SetText(QuestField(link.id, "name", link.name or ""))
    local name = frame.selectedBossName
    local nameW = math.ceil(name:GetStringWidth() or 0)
    local room = math.floor((name:GetWidth() or 300) - nameW - 14 - 22)
    local want = math.ceil(b.text:GetStringWidth() or 0)
    b.text:SetWidth(math.max(40, math.min(want + 2, room)))
    b:SetWidth(22 + b.text:GetWidth())
    b:ClearAllPoints()
    b:SetPoint("LEFT", name, "LEFT", nameW + 14, 0)
    b:Show()
end

-- lootorder: a boss page lists, in each section, the rarer items first
-- (epic, rare, uncommon, common...) and materials (crafting reagents, trade
-- goods) last; items of one group keep the data's order.
FDJ.IsLootMaterial = function(item)
    local slot = type(item) == "table" and type(item[3]) == "string" and string.lower(item[3]) or ""
    return slot:find("reagent", 1, true) ~= nil or slot:find("trade good", 1, true) ~= nil
        or slot:find("material", 1, true) ~= nil
end
-- trashgroups (2.0.27): on a Trash Drops page (byMobs), within each rarity
-- the items from one mob come first, then those from two, three...; items
-- from the same mobs sit together (the mob on the most items first, as the
-- portraits are ordered). Items with no mob named go after them.
-- uniquefirst (2.0.29): on the Recipes & Patterns tab (uniqueFirst), the
-- dungeon's own recipes before the usual Forever sets, whatever their rarity.
-- lootfirst (2.1.3, M 21 Nov 2026, Baron Rivendare: "Since this is kind of a
-- special item, put it on the top left, and then just put the epic sword at
-- the top right"): an item with lootFirst = n comes before all the others,
-- in that order (two columns read left, right: 1 top left, 2 top right).
FDJ.SortLootRange = function(list, first, last, byMobs, uniqueFirst)
    if type(list) ~= "table" or not first or not last or last - first < 1 then return end
    local slice = {}
    local mobCount, mobFirst = {}, {}
    for i = first, last do
        local item = list[i]
        local entry = {
            item = item, pos = i,
            material = FDJ.IsLootMaterial(item) and 1 or 0,
            quality = type(item) == "table" and tonumber(item[4]) or 3,
            unique = (uniqueFirst and type(item) == "table" and FDJ.IsUniqueRecipe and FDJ.IsUniqueRecipe(item[1])) and 0 or 1,
            pin = (type(item) == "table" and tonumber(item.lootFirst)) or 1000, -- lootfirst
        }
        if byMobs then
            local source = type(item) == "table" and type(item[5]) == "string" and item[5] or ""
            local lower = string.lower(source)
            local mobs = {}
            if not lower:find("zone drop", 1, true) and not lower:find(" trash", 1, true) and lower ~= "trash" then
                for name in (source .. " / "):gmatch("(.-) / ") do
                    name = name:gsub("^%s+", ""):gsub("%s+$", "")
                    if name ~= "" then
                        mobs[#mobs + 1] = name
                        if not mobCount[name] then
                            mobCount[name], mobFirst[name] = 0, i * 100 + #mobs
                        end
                        mobCount[name] = mobCount[name] + 1
                    end
                end
            end
            entry.mobs = mobs
        end
        slice[#slice + 1] = entry
    end
    if byMobs then
        local order = {}
        for name in pairs(mobCount) do order[#order + 1] = name end
        table.sort(order, function(a, b)
            if mobCount[a] ~= mobCount[b] then return mobCount[a] > mobCount[b] end
            return mobFirst[a] < mobFirst[b]
        end)
        local rank = {}
        for i, name in ipairs(order) do rank[name] = i end
        for _, entry in ipairs(slice) do
            local ranks = {}
            for _, name in ipairs(entry.mobs) do ranks[#ranks + 1] = rank[name] end
            table.sort(ranks)
            entry.ranks = ranks
            entry.many = #ranks > 0 and #ranks or 999 -- no mob named: last
        end
    end
    table.sort(slice, function(a, b)
        if a.pin ~= b.pin then return a.pin < b.pin end -- lootfirst
        if a.material ~= b.material then return a.material < b.material end
        if a.unique ~= b.unique then return a.unique < b.unique end
        if a.quality ~= b.quality then return a.quality > b.quality end
        if byMobs then
            if a.many ~= b.many then return a.many < b.many end
            for k = 1, #a.ranks do
                if a.ranks[k] ~= b.ranks[k] then return a.ranks[k] < b.ranks[k] end
            end
        end
        return a.pos < b.pos
    end)
    for i, entry in ipairs(slice) do list[first + i - 1] = entry.item end
end

-- "Items Data TBD": dungeons flagged in the data plus every dungeon that has no loot entered
-- yet (the new level-30 dungeons). Stored on FDJ to stay under Lua's
-- 200-locals limit for this file.
FDJ.ShowsItemsTBD = function(name)
    local d = DB[name]
    if not d then return false end
    if d.questChainPage then return false end -- sleepingbag: no loot to list
    if d.itemsTBD or d.fullItemsTBD then return true end -- loot only partly known
    for _, boss in ipairs(d.bosses or {}) do
        if boss.loot and #boss.loot > 0 then return false end
    end
    return true
end

-- Text of the red disclaimer: "Full Items Data TBD" where some loot is listed
-- but the table is not complete yet, otherwise "Items Data TBD".
FDJ.ItemsTBDText = function(name)
    local d = DB[name]
    if d and d.fullItemsTBD then return "Full Items Data TBD" end
    return "Items Data TBD"
end

-- "Full Quests TBD" (dungeons flagged fullQuestsTBD: Alcaz Prison, Blackmaw
-- Hold): on the Quests tab only, on the level line after the items notice,
-- so a faction with few or no quests listed reads as "not found yet".
FDJ.UpdateQuestsTBD = function()
    local label = frame and frame.questsTBD
    if not label then return end
    local d = DB[selectedDungeon]
    label:ClearAllPoints()
    if frame.stockadeItemsTBD and frame.stockadeItemsTBD:IsShown() then
        label:SetPoint("LEFT", frame.stockadeItemsTBD, "RIGHT", 14, 0)
    elseif frame.dungeonMeta then
        label:SetPoint("LEFT", frame.dungeonMeta, "RIGHT", 14, 0)
    end
    label:SetShown((d and d.fullQuestsTBD and selectedMode == "quests") and true or false)
end

-- Compact view: see compactall below (one choice for every page since 2.0.9).
function FDJ.LootCompactKey()
    local d = selectedDungeon and DB[selectedDungeon]
    local b = d and d.bosses and d.bosses[selectedBoss]
    return tostring(selectedDungeon) .. "\001" .. tostring(b and b.name or selectedBoss)
end
function FDJ.LootCompactPages()
    if type(ForeverDungeonJournalDB.compactLootPages) ~= "table" then
        ForeverDungeonJournalDB.compactLootPages = {}
    end
    return ForeverDungeonJournalDB.compactLootPages
end
-- compactall (2.0.9, M 16 Nov 2026: "once somebody switches, it switches
-- for every single page"): the view chosen is one setting for every loot
-- page (detailed until Compact View is pressed), kept between sessions.
-- (compactLootPages, the old per-page choice, is no longer read.)
function FDJ.IsLootCompactPage()
    return type(ForeverDungeonJournalDB) == "table" and ForeverDungeonJournalDB.compactLoot == true or false
end

-- resizeframe (2.0.10 test; at file level: the function that builds the
-- window is at Lua 5.1's limit of 60 upvalues): after the window is resized with its corner
-- grip (Systems/Resize.lua), the page shown is laid out for the new size:
-- the dungeon cards (more columns when wide), the boss list (Compact view
-- only when it still needs scrolling), the loot columns, the quest page,
-- the map (fitted to the page again, zoom and floor kept).
FDJ.RelayoutForSize = function()
    if not frame or not frame:IsShown() then return end
    if frame.homePanel and frame.homePanel:IsShown() then
        if RefreshHomeDungeonCards then pcall(RefreshHomeDungeonCards) end
        return
    end
    if not (selectedDungeon and DB[selectedDungeon]) then return end
    if frame.dungeonMapPanel and frame.dungeonMapPanel:IsShown() and FDJ.DUNGEON_MAPS[selectedDungeon] then
        pcall(FDJ.RenderCustomDungeonMap, FDJ.DUNGEON_MAPS[selectedDungeon], frame.dungeonMapFloor)
        return
    end
    if RefreshBossList then pcall(RefreshBossList) end
    if frame.lootScroll then frame.lootScroll.fdjLastWidth = math.floor(frame.lootScroll:GetWidth() or 0) end
    if RefreshLoot then pcall(RefreshLoot) end
    if frame.questLeftPanel and frame.questLeftPanel:IsShown() then
        if RefreshQuestList then pcall(RefreshQuestList) end
        if RefreshQuestDetail then pcall(RefreshQuestDetail) end
    end
end

RefreshLoot = function()
    for _, row in ipairs(lootRows) do HideSearchItemHighlight(row) end
    for _, row in ipairs(frame.lootChildRows or {}) do HideSearchItemHighlight(row) end -- lootchildren
    local dungeon = DB[selectedDungeon]
    local boss = dungeon.bosses[selectedBoss]
    if FDJ.ShowResultQuest and FDJ.ShowResultQuest(boss) then return end -- resultquest
    if FDJ.FilterBossLoot then
        boss = FDJ.FilterBossLootForPage(boss)
        FDJ.UpdateLootFilterNote(frame)
    end
    -- recipeprof (2.0.7): a Recipes & Patterns page with a profession icon
    -- clicked shows that profession's recipes only. The choice is dropped
    -- on another dungeon's page.
    for _, b in ipairs(frame.recipeProfButtons or {}) do b:Hide() end
    if frame.recipeProfBox then frame.recipeProfBox:Hide() end
    local recipeTabRaw = (type(boss) == "table" and boss.recipeTab) and boss or nil
    local recipeProfs = recipeTabRaw and FDJ.RecipeTabProfessions and FDJ.RecipeTabProfessions(recipeTabRaw) or nil
    if recipeProfs and #recipeProfs.list < 2 then recipeProfs = nil end
    if recipeProfs then
        if FDJ.recipeProfDungeon ~= selectedDungeon then FDJ.recipeProf, FDJ.recipeProfDungeon = nil, selectedDungeon end
        if FDJ.recipeProf and not recipeProfs.has[FDJ.recipeProf] then FDJ.recipeProf = nil end
        if FDJ.recipeProf then
            local keep = {}
            for _, item in ipairs(boss.loot) do
                if FDJ.RecipeProfession(item) == FDJ.recipeProf then keep[#keep + 1] = item end
            end
            boss = setmetatable({ loot = keep }, { __index = boss })
        end
    end

    local isStockade = FDJ.ShowsItemsTBD(selectedDungeon)
    -- "Full Items Data TBD" stays under the dungeon title; the boss loot page
    -- shows its own copy for dungeons with no loot data yet, and for any boss
    -- of a TBD dungeon that has no loot listed (before the loot filter).
    local rawBoss = dungeon.bosses[selectedBoss]
    local bossHasLoot = rawBoss and rawBoss.loot and #rawBoss.loot > 0
    local lootTBD = isStockade and (not (dungeon and dungeon.fullItemsTBD) or not bossHasLoot)
    if frame.stockadeItemsTBD then
        frame.stockadeItemsTBD:SetText(FDJ.ItemsTBDText(selectedDungeon))
        frame.stockadeItemsTBD:SetShown(isStockade)
    end
    if frame.stockadeLootTBD then
        frame.stockadeLootTBD:SetText(FDJ.ItemsTBDText(selectedDungeon))
        frame.stockadeLootTBD:SetShown(lootTBD)
    end
    if FDJ.UpdateQuestsTBD then FDJ.UpdateQuestsTBD() end

    frame.selectedBossName:SetText(BossName(boss.name))
    if frame.selectedBossRareBorder then
        frame.selectedBossRareBorder:SetShown(boss.rare == true)
    end
    if frame.selectedBossType then
        if boss.fdjDungeon then
            frame.selectedBossType:SetText(DungeonName(boss.fdjDungeon))
            frame.selectedBossType:Show()
        elseif boss.recipeTab then
            frame.selectedBossType:SetText("")
            frame.selectedBossType:Hide()
        elseif boss.lootChest then
            frame.selectedBossType:SetText(boss.chestLabel or "Tribute Chest")
            frame.selectedBossType:Show()
        elseif boss.trash then
            frame.selectedBossType:SetText(L("UNIQUE_TRASH"))
            frame.selectedBossType:Show()
        else
            frame.selectedBossType:SetText("")
            frame.selectedBossType:Hide()
        end
    end

    if FDJ.UpdateBossSummon then pcall(FDJ.UpdateBossSummon, frame, boss, THEMES[selectedDungeon] or THEMES["Hall of Thanes"]) end
    if FDJ.SetBossChainButton then pcall(FDJ.SetBossChainButton, DB[selectedDungeon] and DB[selectedDungeon].bosses[selectedBoss]) end
    if FDJ.SetBossQuestLink then pcall(FDJ.SetBossQuestLink, DB[selectedDungeon] and DB[selectedDungeon].bosses[selectedBoss]) end -- bossquest (2.0.8)

    local hasPortrait = SetBossPortrait(
        frame.selectedBossPortrait,
        selectedDungeon,
        boss
    )
    frame.selectedBossQuestion:SetShown(not hasPortrait)
    do -- pairportrait (2.0.9): two portraits side by side, no rare frame
        local second = FDJ.SetPairPortrait(frame.selectedBossPortrait:GetParent(), frame.selectedBossPortrait, boss, 68, 56)
        frame.selectedBossName:ClearAllPoints()
        frame.selectedBossName:SetPoint("LEFT", second or frame.selectedBossPortrait, "RIGHT", second and 12 or 16, 7)
        frame.selectedBossName:SetPoint("RIGHT", -14, 0)
        if second and frame.selectedBossRareBorder then frame.selectedBossRareBorder:Hide() end
    end

    local bossLevel = BossLevelText(selectedDungeon, boss)
    if frame.selectedBossLevelBadge and frame.selectedBossLevelText then
        if bossLevel then
            frame.selectedBossLevelText:SetText(bossLevel)
            FitBossLevelText(frame.selectedBossLevelText, bossLevel)
            frame.selectedBossLevelBadge:Show()
            frame.selectedBossLevelText:Show()
        else
            frame.selectedBossLevelBadge:Hide()
            frame.selectedBossLevelText:Hide()
        end
    end

    frame.selectedBossDescription:SetText("")
    frame.selectedBossDescription:Hide()
    if frame.bossLootNoteText then frame.bossLootNoteText:Hide() end
    if boss.fdjRPGHint then -- rpgpartial: how to reveal this boss
        frame.selectedBossDescription:SetText(boss.fdjRPGHint)
        frame.selectedBossDescription:Show()
    elseif boss.lootNote then -- a red line under the boss name (Titanosaur: Can drop 2 items)
        -- warnfont (2.1.1): in the warning font, on a font string of its own
        -- in the description's place (the description keeps its font for
        -- the RPG hint).
        if not frame.bossLootNoteText then
            frame.bossLootNoteText = frame.selectedBossDescription:GetParent():CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
            frame.bossLootNoteText:SetPoint("TOPLEFT", frame.selectedBossType, "BOTTOMLEFT", 0, -7)
            frame.bossLootNoteText:SetPoint("RIGHT", frame.selectedBossDescription:GetParent(), "RIGHT", -12, 0)
            frame.bossLootNoteText:SetHeight(35)
            frame.bossLootNoteText:SetJustifyH("LEFT")
            frame.bossLootNoteText:SetJustifyV("TOP")
            frame.bossLootNoteText:SetWordWrap(true)
        end
        frame.bossLootNoteText:SetText(L(boss.lootNote))
        FDJ.WarningFont(frame.bossLootNoteText, true) -- warnfont: its font
        -- bossred (2.1.2, M 21 Nov 2026: "leave the disclaimer on bosses red,
        -- because blue here, it's hard to see"): the boss page's line keeps
        -- its old red; the blue stays on the quest pages.
        frame.bossLootNoteText:SetTextColor(0.69, 0.063, 0.063)
        -- lootremoved (2.1.3): a longer line (the Obsidian Sentinel's) keeps
        -- its third line, down to the top of the loot list
        frame.bossLootNoteText:SetHeight(35)
        frame.bossLootNoteText:SetHeight(math.min(44, math.max(35, math.ceil((frame.bossLootNoteText:GetStringHeight() or 0) + 2))))
        frame.bossLootNoteText:Show()
    end
    -- rpgdone (2.0.8): under a hidden boss, "I already did this dungeon".
    if FDJ.RPGDoneButton then pcall(FDJ.RPGDoneButton, frame, boss.fdjRPGHint and selectedDungeon or nil) end
    frame.lootTitle:SetText("")
    frame.lootTitle:Hide()
    frame.lootScroll:ClearAllPoints()
    frame.lootScroll:SetPoint("TOPLEFT", 12, lootTBD and -124 or -102)
    frame.lootScroll:SetPoint("BOTTOMRIGHT", -29, 11)

    -- The rows shown: the boss's (filtered) loot, then - when this boss has
    -- shared loot and the "Show Shared Loot" divider is open - those items.
    local loot = {}
    for _, item in ipairs(boss.loot) do loot[#loot + 1] = item end
    local ownCount = #loot
    -- recipeprof (2.0.7): with a profession icon clicked, the page is laid out
    -- for all its recipes (columns, portraits, Compact view, scroll bar, the
    -- icons' place): only the rows of the other professions go, nothing moves.
    local layoutLoot = (recipeProfs and FDJ.recipeProf and recipeTabRaw and recipeTabRaw.loot) or nil
    local sharedList = FDJ.GetBossSharedLoot and FDJ.GetBossSharedLoot(selectedDungeon, boss) or nil
    local sharedCount = sharedList and #sharedList or 0
    if sharedCount > 0 and FDJ.lootSharedExpanded then
        for _, item in ipairs(sharedList) do loot[#loot + 1] = item end
    end
    -- probableloot: then, under "Not confirmed, but probable drop" (open),
    -- the items very likely from this boss that nobody has seen drop yet.
    local sharedEnd = #loot
    local probableList = type(boss.probableLoot) == "table" and boss.probableLoot or nil
    local probableCount = probableList and #probableList or 0
    if probableCount > 0 and FDJ.lootProbableExpanded then
        for _, item in ipairs(probableList) do loot[#loot + 1] = item end
    end
    -- lootorder: each section grouped by rarity, materials at the bottom
    -- (the list is a copy: the data keeps its order).
    if FDJ.SortLootRange then
        local split = FDJ.lootRecipeSplit
        -- trashgroups (2.0.27): Trash Drops grouped by the mobs that drop them.
        local byMobs = (boss.trash and not boss.recipeTab) and true or nil
        local uniqueFirst = boss.recipeTab and true or nil -- uniquefirst (2.0.29)
        FDJ.SortLootRange(loot, 1, split or ownCount, byMobs, uniqueFirst)
        if split then FDJ.SortLootRange(loot, split + 1, ownCount, byMobs) end
        FDJ.SortLootRange(loot, ownCount + 1, sharedEnd, byMobs)
        FDJ.SortLootRange(loot, sharedEnd + 1, #loot, byMobs)
    end

    -- Sections, top to bottom: gear, "Recipes & Patterns" (when split off),
    -- "Shared Loot" (when the boss has any). Each divider line sits between.
    local ROW_STEP, LINE_STEP, COL_GAP, SINGLE_WIDTH = 59, 31, 8, 388
    local recipeSplit = FDJ.lootRecipeSplit
    local sections = {}
    sections[#sections + 1] = { first = 1, last = recipeSplit or ownCount }
    if recipeSplit then sections[#sections + 1] = { line = "recipe", first = recipeSplit + 1, last = ownCount } end
    if sharedCount > 0 then sections[#sections + 1] = { line = "shared", first = ownCount + 1, last = sharedEnd } end
    if probableCount > 0 then sections[#sections + 1] = { line = "probable", first = sharedEnd + 1, last = #loot } end

    -- One column normally. When the list would need scrolling, use two
    -- columns (items read left, right, next line) so far less scrolling is
    -- needed. Pages whose rows carry trash-mob portraits stay one column,
    -- because the portraits need the full row width.
    -- crowdedrecipes (2.0.7): a crowded Recipes & Patterns page (Systems/
    -- LootFilter.lua) is laid out like a page without portraits (two columns
    -- when long); only its epic recipes get their bosses' faces.
    local crowdedRecipes = FDJ.IsCrowdedRecipePage and FDJ.IsCrowdedRecipePage(recipeTabRaw or boss) or false
    local function HasMobPortraits()
        if crowdedRecipes then return false end
        if not boss.trash or not FDJ.TRASH_MOB_DISPLAY_IDS then return false end
        for _, item in ipairs(layoutLoot or loot) do
            local source = item[5]
            if type(source) == "string" and source ~= "" then
                local all, any = true, false
                for name in (source .. " / "):gmatch("(.-) / ") do
                    name = name:gsub("^%s+", ""):gsub("%s+$", "")
                    if name ~= "" then
                        any = true
                        if not FDJ.TRASH_MOB_DISPLAY_IDS[name]
                            and not (FDJ.TRASH_MOB_NPC_IDS and FDJ.TRASH_MOB_NPC_IDS[name]) then all = false end
                    end
                end
                if any and all then return true end
            end
        end
        return false
    end
    -- Compact view: offered when even the two-column layout would need
    -- scrolling. Smaller rows with the item name only (like AtlasLoot),
    -- toggled with the button on the "N items" line. Pages open detailed;
    -- the choice is remembered for the page it was made on.
    -- Pages with trash-mob portraits (one column, full rows) get it too when
    -- their one column needs scrolling (Krol'dok's trash): compact rows drop
    -- the portraits, the mobs stay in the item's tooltip ("Drops from").
    local mobPortraits = HasMobPortraits()
    -- moborder (2.0.25): the page's mob order (2.0.24: a column per mob).
    if FDJ.PlanMobSlots then FDJ.PlanMobSlots((boss.trash and mobPortraits) and loot or nil) end
    -- wideloot (2.0.10 test, M 17 Nov 2026: "the boss loot page looks kinda
    -- bad resized, way too much dead space"; then "very scuffed, but it works
    -- perfect on Drakkisath"): in a window made bigger than normal (corner
    -- grip), the loot is a grid that always fills the page's width: as many
    -- columns as fit at 360 or more each (like Drakkisath's two), the rows
    -- stretched to share the whole width, filled left to right, even when the
    -- items would fit in one column. The normal-size window is as before.
    local wideLoot = (frame:GetWidth() or 850) > 870
    local wideCols = 1
    if wideLoot then
        wideCols = math.max(1, math.floor((math.floor(frame.lootScroll:GetWidth() or SINGLE_WIDTH) + COL_GAP) / (360 + COL_GAP)))
    end
    do
        local vp = frame.lootScroll:GetHeight() or 0
        local many = false
        if layoutLoot then
            local n = #layoutLoot
            many = vp > 0 and n > 1 and ((wideLoot and math.ceil(n / wideCols)) or (mobPortraits and n) or math.ceil(n / 2)) * ROW_STEP > vp + 4
        elseif vp > 0 and #loot > 1 then
            local h = (#sections - 1) * LINE_STEP
            for _, sec in ipairs(sections) do
                local n = math.max(0, sec.last - sec.first + 1)
                h = h + ((wideLoot and math.ceil(n / wideCols)) or (mobPortraits and n) or math.ceil(n / 2)) * ROW_STEP
            end
            for _, it in ipairs(loot) do -- lootchildren: their rows too
                if type(it) == "table" and type(it.makes) == "table" then h = h + 44 end
            end
            many = h > vp + 4
        end
        FDJ.lootManyItems = many
        FDJ.lootCompact = many and FDJ.IsLootCompactPage() or false
        if FDJ.lootCompact then ROW_STEP = 31 end
    end
    local layoutCount = layoutLoot and #layoutLoot or #loot
    -- lootchildren (2.0.8): an item that makes another (Jang'thraze and
    -- Sang'thraze make Sul'thraze the Lasher: item.makes) has that item on a
    -- row of its own under it, always shown; the grid makes room for it.
    local CHILD_STEP = FDJ.lootCompact and 26 or 44
    local function ChildExtra(index)
        local it = loot[index]
        return (type(it) == "table" and type(it.makes) == "table") and CHILD_STEP or 0
    end
    local singleHeight = layoutCount * ROW_STEP + (#sections - 1) * LINE_STEP
    for index = 1, #loot do singleHeight = singleHeight + ChildExtra(index) end
    local viewport = frame.lootScroll:GetHeight() or 0
    local twoColumns = viewport > 0 and singleHeight > viewport + 4 and layoutCount > 1
        and not (mobPortraits and not FDJ.lootCompact)
    local availableWidth = math.max(SINGLE_WIDTH, math.floor(frame.lootScroll:GetWidth() or SINGLE_WIDTH))
    local rowWidth = twoColumns and math.floor((availableWidth - COL_GAP) / 2) or SINGLE_WIDTH
    frame.lootContent:SetWidth(twoColumns and availableWidth or SINGLE_WIDTH)
    FDJ.lootTwoColumns = twoColumns
    if wideLoot then -- wideloot: the grid below
        twoColumns = false
        rowWidth = math.floor((availableWidth - COL_GAP * (wideCols - 1)) / wideCols)
        frame.lootContent:SetWidth(availableWidth)
        FDJ.lootTwoColumns = true
    end

    local rowPos, lineY = {}, {}
    local cursorY = 0
    for _, section in ipairs(sections) do
        if section.line then
            lineY[section.line] = cursorY
            cursorY = cursorY + LINE_STEP
        end
        local count = math.max(0, section.last - section.first + 1)
        -- (a pair of rows is as tall as the taller of the two, child rows
        -- included: lootchildren)
        if wideLoot then
            -- wideloot: a row of the grid is as tall as its tallest item
            local k = 0
            while k <= count - 1 do
                local h = 0
                for c = 0, wideCols - 1 do
                    if k + c <= count - 1 then
                        local index = section.first + k + c
                        rowPos[index] = { c * (rowWidth + COL_GAP), cursorY }
                        h = math.max(h, ROW_STEP + ChildExtra(index))
                    end
                end
                cursorY = cursorY + h
                k = k + wideCols
            end
        elseif twoColumns then
            local k = 0
            while k <= count - 1 do
                local left, right = section.first + k, section.first + k + 1
                rowPos[left] = { 0, cursorY }
                local h = ROW_STEP + ChildExtra(left)
                local used = 1
                if k + 1 <= count - 1 then
                    rowPos[right] = { rowWidth + COL_GAP, cursorY }
                    h = math.max(h, ROW_STEP + ChildExtra(right))
                    used = 2
                    -- gapfill (2.0.8, M 15 Nov 2026: "move spellshock leggings
                    -- under lifeblood amulet"): when only one of the pair has
                    -- an item row under it (lootchildren), the next item takes
                    -- the empty space under the other one.
                    local nextIndex = section.first + k + 2
                    if k + 2 <= count - 1 and not mobPortraits and ChildExtra(nextIndex) == 0
                        and (ChildExtra(left) == 0) ~= (ChildExtra(right) == 0) then
                        rowPos[nextIndex] = { ChildExtra(left) == 0 and 0 or (rowWidth + COL_GAP), cursorY + ROW_STEP }
                        h = math.max(h, ROW_STEP * 2)
                        used = 3
                    end
                end
                cursorY = cursorY + h
                k = k + used
            end
        else
            for k = 0, count - 1 do
                rowPos[section.first + k] = { 0, cursorY }
                cursorY = cursorY + ROW_STEP + ChildExtra(section.first + k)
            end
        end
    end
    local layoutHeight = cursorY

    frame.lootChildRows = frame.lootChildRows or {}
    local childUsed = 0
    for i = 1, math.max(#lootRows, #loot) do
        local row = lootRows[i]

        if i <= #loot then
            if not row then
                row = MakeLootRow(frame.lootContent)
                lootRows[i] = row

            end
            -- Rows are placed by offset so the recipe divider can sit between
            -- the gear rows and the recipe rows.
            row:ClearAllPoints()
            local rowX, rowY = rowPos[i][1], rowPos[i][2]
            row:SetWidth(rowWidth)
            row:SetPoint("TOPLEFT", frame.lootContent, "TOPLEFT", rowX, -rowY)
            do
                local compact = FDJ.lootCompact
                row:SetHeight(compact and 28 or 52)
                row.icon:SetSize(compact and 22 or 38, compact and 22 or 38)
                row.icon:ClearAllPoints()
                row.icon:SetPoint("LEFT", compact and 5 or 10, 0)
                row.name:ClearAllPoints()
                if compact then
                    row.name:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
                else
                    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -4)
                end
                row.name:SetFontObject(compact and "ForeverDJ_GameFontNormalSmall" or "ForeverDJ_GameFontNormal")
                row.slot:SetShown(not compact)
            end

            local item = loot[i]
            row.item = item
            row.fdjDungeonName = boss.fdjDungeon or selectedDungeon -- (Matching loot: the boss's own dungeon, for the drop chance)
            row.fdjBossName = boss.name
            row.icon:SetTexture(ItemIcon(item[1]))
            if FDJ.UpdateFavouriteIndicator then FDJ.UpdateFavouriteIndicator(row, item[1]) end
            -- Shared loot is marked on the item-type line (see below), so the
            -- old right-hand label is no longer used.
            if row.sharedText then row.sharedText:Hide() end
            if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
                pcall(C_Item.RequestLoadItemDataByID, item[1])
            end

            local itemName, itemLink, quality = ItemInfo(item[1])

            local r, g, b
            -- questgreen (2.0.6): a quest item the journal knows as green or
            -- better (Frayed Abomination Stitching, Essence of Eranikus, the
            -- UBRS Gemstones: green on Wowhead Forever and in the game) takes
            -- that quality's colour from the journal's data (not the item
            -- cache, which the note below distrusts); only plain ones are white.
            if item[3] == "Quest Item" and (tonumber(item[4]) or 1) >= 2 then
                r, g, b = QualityColor(tonumber(item[4]))
            elseif item[3] == "Quest Item" or item[4] == 1 then
                -- Quest objectives should read as normal/white here, even if
                -- the beta's item cache currently flags the object as Rare.
                r, g, b = 1, 1, 1
            else
                r, g, b = GetAuthoritativeItemQuality(item[1], itemLink, quality, item[4])
            end

            row.name:SetText(itemName or item[2])
            row.name:SetTextColor(r, g, b)

            local trashSource = boss.trash and item[5]
            local showTrashSource = false
            if type(trashSource) == "string" and trashSource ~= "" then
                local sourceLower = string.lower(trashSource)
                -- Only surface a source when it gives the player actionable
                -- information (for example "Druid of the Fang" or
                -- "Defias Overseer / Defias Taskmaster"). Generic labels such
                -- as "Shadowfang Keep trash" / "zone drop" are redundant.
                if not string.find(sourceLower, "zone drop", 1, true)
                    and not string.find(sourceLower, " trash", 1, true)
                    and sourceLower ~= "trash" then
                    showTrashSource = true
                end
            end

            if showTrashSource then
                row.slot:SetText(ItemSlot(item[3]) .. "  |  " .. FreeText(trashSource))
                row.fdjSourceText = L("DROPS_FROM", FreeText(trashSource))
            else
                row.slot:SetText(ItemSlot(item[3]))
                row.fdjSourceText = nil
            end
            -- Named trash mobs are shown as hoverable portraits instead of text
            -- (not in the compact view: no room; the tooltip still names them).
            local rowFaces = showTrashSource and not FDJ.lootCompact
            if rowFaces and crowdedRecipes and not (FDJ.RecipeRowKeepsPortrait and FDJ.RecipeRowKeepsPortrait(item)) then
                rowFaces = false -- crowdedrecipes (2.0.7): the sources stay as text
            end
            -- sourcetip (2.0.9): a family's row says the family on its portraits too
            row.fdjMobTip = (type(item) == "table" and type(item.sourceTip) == "string" and item.sourceTip ~= "") and (FDJ.LocalizeSourceTip or FreeText)(item.sourceTip) or nil -- sourcetipl10n (2.0.9)
            if FDJ.SetRowMobs and FDJ.SetRowMobs(row, rowFaces and trashSource or nil) then
                row.slot:SetText(ItemSlot(item[3]))
            end

            -- alltrash (2.0.9): an item every trash mob of the dungeon drops
            -- (allTrash on the item). alltrashtip (2.0.6): its tooltip says
            -- "Drops from: ALL Trash"; no label on the row (was "ALL TRASH" on
            -- its right, off since 2.0.20).
            do
                local everyMob = boss.trash and type(item) == "table" and item.allTrash and true or false
                if everyMob then row.fdjSourceText = L("DROPS_FROM", L("ALL_TRASH")) end
                if row.fdjAllTrash then row.fdjAllTrash:Hide() end
                -- sourcetip (2.0.9, M 16 Nov 2026): a whole family drops it (Dire
                -- Maul's satyrs): one of them on the row, the family in the tooltip
                if type(item) == "table" and type(item.sourceTip) == "string" and item.sourceTip ~= "" then
                    row.fdjSourceText = L("DROPS_FROM", (FDJ.LocalizeSourceTip or FreeText)(item.sourceTip)) -- sourcetipl10n (2.0.9)
                end
            end

            -- Keep the name and type clear of the trash mob portraits.
            do
                local inset = -10
                local mobs = 0
                for _, button in ipairs(row.fdjMobButtons or {}) do
                    if button:IsShown() then mobs = mobs + 1 end
                end
                -- The portraits' width (all of them, packed to the right).
                if (row.fdjMobSpan or 0) > mobs then mobs = row.fdjMobSpan end
                if mobs > 0 then inset = math.min(inset, -(14 + mobs * 38)) end
                -- alltrash (2.0.9): and clear of the ALL TRASH label.
                if row.fdjAllTrash and row.fdjAllTrash:IsShown() then
                    inset = math.min(inset, -(24 + math.floor((tonumber(row.fdjAllTrash:GetStringWidth()) or 60) + 0.5)))
                end
                row.name:SetPoint("RIGHT", inset, 0)
                row.slot:SetPoint("RIGHT", inset, 0)
            end

            local theme = THEMES[selectedDungeon] or THEMES["Hall of Thanes"]
            row:SetBackdropColor(unpack(theme.lootRow))
            row:SetBackdropBorderColor(unpack(theme.border))
            row.slot:SetTextColor(unpack(theme.muted))
            -- Items the Loot Filter rules out stay listed but blacked out.
            local dimmed = FDJ.lootFilterDimmed and FDJ.lootFilterDimmed[item]
            row:SetAlpha(dimmed and 0.28 or 1)
            if row.icon.SetDesaturated then row.icon:SetDesaturated(dimmed and true or false) end
            row:Show()
            -- lootchildren (2.0.8): the item it makes, on its own row under it
            if type(item.makes) == "table" and FDJ.ShowLootChild then
                childUsed = childUsed + 1
                local child = frame.lootChildRows[childUsed]
                if not child then
                    child = MakeLootRow(frame.lootContent)
                    frame.lootChildRows[childUsed] = child
                end
                pcall(FDJ.ShowLootChild, child, item, boss, rowX, rowY, rowWidth, theme, dimmed)
            end
        elseif row then
            row.item = nil
            row.fdjDungeonName = nil
            row.fdjBossName = nil
            row.fdjSourceText = nil
            if row.fdjFavouriteStar then row.fdjFavouriteStar:Hide() end
            row:Hide()
            if FDJ.SetRowMobs then FDJ.SetRowMobs(row, nil) end
        end
    end

    -- lootchildren: child rows not used on this page
    for k = childUsed + 1, #(frame.lootChildRows or {}) do
        local child = frame.lootChildRows[k]
        child.item, child.fdjSourceText = nil, nil
        if child.fdjFavouriteStar then child.fdjFavouriteStar:Hide() end
        child:Hide()
    end

    -- Recipe section divider ("Recipes & Patterns (N)"): sits after the gear
    -- rows; clicking it folds / unfolds the recipe rows below it.
    local recipeLineHeight = 0
    do
        local split = FDJ.lootRecipeSplit
        local line = frame.lootRecipeLine
        if split and not line then
            line = CreateFrame("Button", nil, frame.lootContent)
            frame.lootRecipeLine = line
            line:SetHeight(24)
            line.rule = line:CreateTexture(nil, "BACKGROUND")
            line.rule:SetHeight(1)
            line.rule:SetPoint("BOTTOMLEFT", 0, 0)
            line.rule:SetPoint("BOTTOMRIGHT", 0, 0)
            line.rule:SetColorTexture(0.48, 0.40, 0.27, 0.6)
            line.icon = line:CreateTexture(nil, "ARTWORK")
            line.icon:SetSize(16, 16)
            line.icon:SetPoint("LEFT", 4, 0)
            line.text = line:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
            line.text:SetPoint("LEFT", line.icon, "RIGHT", 6, 0)
            line.text:SetJustifyH("LEFT")
            line:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            line:SetScript("OnClick", function()
                FDJ.lootRecipesExpanded = not FDJ.lootRecipesExpanded
                RefreshLoot()
            end)
        end
        if line then
            if split then
                line.text:SetText(L("RECIPES_SECTION", FDJ.lootRecipeCount or 0))
                line.icon:SetTexture(FDJ.lootRecipesExpanded and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
                line:ClearAllPoints()
                line:SetPoint("TOPLEFT", frame.lootContent, "TOPLEFT", 0, -(lineY.recipe or 0))
                line:SetPoint("RIGHT", frame.lootContent, "RIGHT", 0, 0)
                line:Show()
                recipeLineHeight = 31
            else
                line:Hide()
            end
        end
    end

    -- "Show Shared Loot (N)" divider: only for bosses with shared loot.
    -- Folded by default; clicking it shows / hides those items below.
    do
        local line = frame.lootSharedLine
        if sharedCount > 0 and not line then
            line = CreateFrame("Button", nil, frame.lootContent)
            frame.lootSharedLine = line
            line:SetHeight(24)
            line.rule = line:CreateTexture(nil, "BACKGROUND")
            line.rule:SetHeight(1)
            line.rule:SetPoint("BOTTOMLEFT", 0, 0)
            line.rule:SetPoint("BOTTOMRIGHT", 0, 0)
            line.rule:SetColorTexture(0.48, 0.40, 0.27, 0.6)
            line.icon = line:CreateTexture(nil, "ARTWORK")
            line.icon:SetSize(16, 16)
            line.icon:SetPoint("LEFT", 4, 0)
            line.text = line:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
            line.text:SetPoint("LEFT", line.icon, "RIGHT", 6, 0)
            line.text:SetJustifyH("LEFT")
            line.note = line:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
            line.note:SetPoint("LEFT", line.text, "RIGHT", 8, 0)
            line.note:SetTextColor(0.68, 0.62, 0.52)
            line:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            line:SetScript("OnClick", function()
                FDJ.lootSharedExpanded = not FDJ.lootSharedExpanded
                RefreshLoot()
            end)
        end
        if line then
            if sharedCount > 0 then
                local open = FDJ.lootSharedExpanded and true or false
                line.text:SetText(L(open and "SHARED_HIDE" or "SHARED_SHOW", sharedCount))
                line.note:SetText(L("SHARED_NOTE"))
                line.icon:SetTexture(open and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
                line:ClearAllPoints()
                line:SetPoint("TOPLEFT", frame.lootContent, "TOPLEFT", 0, -(lineY.shared or 0))
                line:SetPoint("RIGHT", frame.lootContent, "RIGHT", 0, 0)
                line:Show()
            else
                line:Hide()
            end
        end
    end

    -- probableloot: the "Not confirmed, but probable drop (N)" divider, as
    -- Shared Loot's: folded by default, a click shows / hides the items.
    do
        local line = frame.lootProbableLine
        if probableCount > 0 and not line then
            line = CreateFrame("Button", nil, frame.lootContent)
            frame.lootProbableLine = line
            line:SetHeight(24)
            line.rule = line:CreateTexture(nil, "BACKGROUND")
            line.rule:SetHeight(1)
            line.rule:SetPoint("BOTTOMLEFT", 0, 0)
            line.rule:SetPoint("BOTTOMRIGHT", 0, 0)
            line.rule:SetColorTexture(0.48, 0.40, 0.27, 0.6)
            line.icon = line:CreateTexture(nil, "ARTWORK")
            line.icon:SetSize(16, 16)
            line.icon:SetPoint("LEFT", 4, 0)
            line.text = line:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
            line.text:SetPoint("LEFT", line.icon, "RIGHT", 6, 0)
            line.text:SetJustifyH("LEFT")
            line:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            line:SetScript("OnClick", function()
                FDJ.lootProbableExpanded = not FDJ.lootProbableExpanded
                RefreshLoot()
            end)
        end
        if line then
            if probableCount > 0 then
                local open = FDJ.lootProbableExpanded and true or false
                line.text:SetText(L("PROBABLE_LOOT", probableCount))
                line.icon:SetTexture(open and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
                line:ClearAllPoints()
                line:SetPoint("TOPLEFT", frame.lootContent, "TOPLEFT", 0, -(lineY.probable or 0))
                line:SetPoint("RIGHT", frame.lootContent, "RIGHT", 0, 0)
                line:Show()
            else
                line:Hide()
            end
        end
    end

    local contentHeight = math.max(1, layoutHeight)
    frame.lootContent:SetHeight(contentHeight)
    local viewportHeight = frame.lootScroll:GetHeight() or 0
    local needsScroll = viewportHeight > 0 and contentHeight > viewportHeight + 4
    -- Compact / detailed toggle on the "N items" line.
    if FDJ.lootManyItems and not frame.lootCompactButton then
        local b = CreateFrame("Button", nil, frame.lootTitle:GetParent(), "BackdropTemplate")
        frame.lootCompactButton = b
        b:SetSize(104, 20)
        SetBackdrop(b, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 9, 2)
        b:SetBackdropColor(0.12, 0.10, 0.08, 0.95)
        b:SetBackdropBorderColor(0.52, 0.33, 0.11, 1)
        b.text = b:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
        b.text:SetPoint("CENTER")
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        b:SetScript("OnClick", function()
            if type(ForeverDungeonJournalDB) == "table" then -- compactall (2.0.9)
                ForeverDungeonJournalDB.compactLoot = not FDJ.IsLootCompactPage() or nil
            end
            PlayJournalOptionSound()
            RefreshLoot()
        end)
        -- notip (2.0.23): no tooltip on hover any more (the button's own
        -- text says what it does); the highlight stays.
    end
    if frame.lootCompactButton then
        frame.lootCompactButton:SetShown(FDJ.lootManyItems and true or false)
        frame.lootCompactButton.text:SetText(L(FDJ.lootCompact and "LOOT_DETAILED" or "LOOT_COMPACT"))
        frame.lootCompactButton:ClearAllPoints()
        frame.lootCompactButton:SetPoint("TOPRIGHT", frame.lootTitle:GetParent(), "TOPRIGHT", -30, lootTBD and -120 or -98)
    end
    if needsScroll or FDJ.lootManyItems or recipeProfs then -- recipeprof: the line carries the icons
        frame.lootTitle:SetText(tostring(#boss.loot) .. " " .. L("ITEMS"))
        frame.lootTitle:ClearAllPoints()
        frame.lootTitle:SetPoint("TOPLEFT", 14, lootTBD and -124 or -102)
        frame.lootTitle:Show()
        frame.lootScroll:ClearAllPoints()
        frame.lootScroll:SetPoint("TOPLEFT", 12, lootTBD and -146 or -124)
        frame.lootScroll:SetPoint("BOTTOMRIGHT", -29, 11)
    else
        frame.lootTitle:SetText("")
        frame.lootTitle:ClearAllPoints()
        frame.lootTitle:SetPoint("TOPLEFT", 14, -102)
        frame.lootTitle:Hide()
    end
    -- recipeprof (2.0.7): the profession icons, small, in the middle of the
    -- line between "N items" and the Compact view button. A soft golden
    -- glow like the journal's other round buttons; the one clicked gets the
    -- brighter glow with the gold ring, like the Forever-only emblem.
    if recipeProfs then
        local parent = frame.lootTitle:GetParent()
        frame.recipeProfButtons = frame.recipeProfButtons or {}
        local SIZE, GAP, PAD = 18, 8, 6
        local count = #recipeProfs.list
        local total = count * SIZE + (count - 1) * GAP
        -- the place is worked out for the full count ("9 items"), so the
        -- icons stay put while one is clicked ("1 items")
        local shownText = frame.lootTitle:GetText()
        frame.lootTitle:SetText(tostring(#recipeTabRaw.loot) .. " " .. L("ITEMS"))
        local left = 14 + (frame.lootTitle:GetStringWidth() or 60)
        frame.lootTitle:SetText(shownText)
        local right = (parent:GetWidth() or 480) - 30
        if frame.lootCompactButton and frame.lootCompactButton:IsShown() then right = right - 104 end
        local startX = math.floor((left + right) / 2 - total / 2 + 0.5)
        if startX < left + 8 + PAD then startX = left + 8 + PAD end
        local top = lootTBD and -121 or -99
        -- a small rounded dark box behind the icons
        local box = frame.recipeProfBox
        if not box then
            box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            frame.recipeProfBox = box
            SetBackdrop(box, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 9, 2)
            box:SetBackdropColor(0.035, 0.03, 0.025, 0.92)
            box:SetBackdropBorderColor(0.30, 0.23, 0.14, 1)
            box:SetFrameLevel((parent:GetFrameLevel() or 1) + 4)
        end
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", parent, "TOPLEFT", startX - PAD, top + 5)
        box:SetSize(total + PAD * 2, SIZE + 10)
        box:Show()
        for i, prof in ipairs(recipeProfs.list) do
            local b = frame.recipeProfButtons[i]
            if not b then
                b = CreateFrame("Button", nil, parent)
                frame.recipeProfButtons[i] = b
                b:SetSize(SIZE, SIZE)
                b:SetFrameLevel((parent:GetFrameLevel() or 1) + 5)
                b.halo = b:CreateTexture(nil, "BACKGROUND", nil, -1)
                b.halo:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\TickGlow")
                b.halo:SetBlendMode("ADD")
                b.halo:SetVertexColor(1, 0.82, 0.35)
                b.halo:SetPoint("CENTER")
                b.glow = b:CreateTexture(nil, "BACKGROUND")
                b.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
                b.glow:SetBlendMode("ADD")
                b.glow:SetVertexColor(1, 0.82, 0.3, 0.95)
                b.glow:SetPoint("CENTER")
                b.icon = b:CreateTexture(nil, "ARTWORK")
                b.icon:SetAllPoints()
                b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                b.hl = b:CreateTexture(nil, "HIGHLIGHT")
                b.hl:SetAllPoints()
                b.hl:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                b.hl:SetBlendMode("ADD")
                b.hl:SetAlpha(0.35)
                b:SetScript("OnClick", function(self)
                    FDJ.recipeProf = (FDJ.recipeProf ~= self.fdjProf) and self.fdjProf or nil
                    FDJ.recipeProfDungeon = selectedDungeon
                    PlayJournalOptionSound()
                    if frame.lootScroll.SetVerticalScroll then frame.lootScroll:SetVerticalScroll(0) end
                    RefreshLoot()
                end)
                b:SetScript("OnEnter", function(self)
                    if not GameTooltip then return end
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(ItemSlot(self.fdjProf) or self.fdjProf, 1, 0.82, 0)
                    GameTooltip:Show()
                end)
                b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            end
            b.fdjProf = prof
            b.icon:SetTexture(FDJ.RECIPE_PROF_ICONS[prof])
            b.hl:SetTexture(FDJ.RECIPE_PROF_ICONS[prof])
            local on = FDJ.recipeProf == prof
            local halo = math.floor(SIZE * (on and 1.85 or 1.6) + 0.5) -- kept mostly inside the box
            b.halo:SetSize(halo, halo)
            b.halo:SetAlpha(on and 1 or 0.75)
            b.glow:SetSize(math.floor(SIZE * 1.92 + 0.5), math.floor(SIZE * 1.92 + 0.5))
            b.glow:SetShown(on)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", parent, "TOPLEFT", startX + (i - 1) * (SIZE + GAP), top)
            b:Show()
        end
    end
    -- recipeprof: a filtered page keeps the full page's scroll bar
    local barHeight = contentHeight
    if layoutLoot then
        barHeight = math.max(contentHeight, (twoColumns and math.ceil(layoutCount / 2) or layoutCount) * ROW_STEP)
    end
    UpdateScrollBarVisibility(frame.lootScroll, barHeight)

    -- Item names/slot text can arrive asynchronously after GET_ITEM_INFO_RECEIVED.
    -- Re-evaluate fonts after the row text is populated so CJK strings never
    -- fall back to the western client font and render as squares.
    ApplyLocaleFontTree(frame.lootContent)
end

local function ApplyTheme()
    if not frame then return end

    local theme = THEMES[selectedDungeon] or THEMES["Hall of Thanes"]

    frame:SetBackdropColor(unpack(theme.frame))
    frame.contentPanel:SetBackdropColor(unpack(theme.content))
    frame.contentPanel:SetBackdropBorderColor(unpack(theme.border))
    frame.headerPanel:SetBackdropColor(unpack(theme.header))
    frame.leftPanel:SetBackdropColor(unpack(theme.left))
    frame.rightPanel:SetBackdropColor(unpack(theme.right))

    if frame.homePanel then
        frame.homePanel:SetBackdropColor(0.16, 0.12, 0.07, 0.96)
        frame.homePanel:SetBackdropBorderColor(0.47, 0.34, 0.16, 1)
    end
    if frame.homeParchment then
        frame.homeParchment:SetVertexColor(1.00, 0.95, 0.84)
        frame.homeParchment:SetAlpha(0.18)
    end
    if FDJ.TintForeverView then FDJ.TintForeverView(frame) end -- foreverview (2.1.3): blue while Forever-only
    if frame.contentParchment then
        frame.contentParchment:SetVertexColor(1.00, 0.95, 0.84)
        frame.contentParchment:SetAlpha(0.18)
    end
    if frame.headerParchment then frame.headerParchment:SetAlpha(0.16) end
    if frame.leftParchment then frame.leftParchment:SetAlpha(0.13) end
    if frame.rightParchment then frame.rightParchment:SetAlpha(0.13) end
    if frame.questLeftParchment then frame.questLeftParchment:SetAlpha(0.13) end
    if frame.questRightParchment then frame.questRightParchment:SetAlpha(0.10) end

    if frame.questLeftPanel then
        frame.questLeftPanel:SetBackdropColor(unpack(theme.left))
        frame.questLeftPanel:SetBackdropBorderColor(unpack(theme.border))
    end
    if frame.questRightPanel then
        frame.questRightPanel:SetBackdropColor(unpack(theme.right))
        frame.questRightPanel:SetBackdropBorderColor(unpack(theme.border))
    end

    frame.dungeonTitle:SetTextColor(unpack(theme.title))
    frame.dungeonMeta:SetTextColor(unpack(theme.muted))

    frame.selectedBossName:SetTextColor(unpack(theme.text))
    frame.selectedBossDescription:SetTextColor(unpack(theme.text))
    frame.lootTitle:SetTextColor(unpack(theme.text))
    if frame.bossListTitle then frame.bossListTitle:SetTextColor(unpack(theme.text)) end
    if frame.questListTitle then frame.questListTitle:SetTextColor(unpack(theme.text)) end

    local ruins = selectedDungeon == "Ruins of Lordaeron"
    local hall = selectedDungeon == "Hall of Thanes"
    local bfd = selectedDungeon == "Blackfathom Deeps"

    if frame.dungeonBackgroundArt then
        local bg = DUNGEON_PAGE_ART[selectedDungeon]
        local crop = DUNGEON_PAGE_TEXCOORD[selectedDungeon] or { 0.03, 0.97, 0.05, 0.95 }
        if bg then
            frame.dungeonBackgroundArt:SetTexture(bg)
            frame.dungeonBackgroundArt:SetTexCoord(crop[1], crop[2], crop[3], crop[4])
            frame.dungeonBackgroundArt:SetAlpha(0.16)
            frame.dungeonBackgroundArt:Show()
        else
            frame.dungeonBackgroundArt:Hide()
        end
    end

    if frame.questInsetEdges then
        for _, edge in ipairs(frame.questInsetEdges) do
            edge:SetColorTexture(0.36, 0.23, 0.09, 0.98)
        end
    end

    if frame.questTextInset then
        frame.questTextInset:SetBackdropColor(0.70, 0.58, 0.39, 1.00)
        frame.questTextInset:SetBackdropBorderColor(0.36, 0.23, 0.09, 1)

        if frame.questParchment then
            frame.questParchment:SetVertexColor(1.00, 0.96, 0.84, 1.00)
            frame.questParchment:SetAlpha(1)
        end

        frame.selectedQuestName:SetTextColor(1.00, 0.78, 0.16)
        frame.selectedQuestMeta:SetTextColor(0.25, 0.16, 0.08)
        frame.questDetailText:SetTextColor(0.10, 0.065, 0.025)
        if frame.questTurninText then frame.questTurninText:SetTextColor(0.10, 0.065, 0.025) end
        frame.questRewardSummary:SetTextColor(0.10, 0.065, 0.025)
    end

    if frame.atmosphere then
        if ruins then
            frame.atmosphere:SetColorTexture(0.06, 0.08, 0.05, 0.05)
        elseif bfd then
            frame.atmosphere:SetColorTexture(0.04, 0.07, 0.08, 0.05)
        else
            frame.atmosphere:SetColorTexture(0.10, 0.07, 0.03, 0.04)
        end
    end

    if frame.mistTop then
        frame.mistTop:SetShown(false)
    end

    for _, tab in pairs(dungeonTabs) do
        if tab then
            tab:SetBackdropBorderColor(unpack(theme.border))
        end
    end

    UpdateModeTabs()
    UpdateFactionButtons()
end

ApplyLocalization = function()
    if not frame then return end

    UpdateLanguageControl()
    if frame.mainTitle then frame.mainTitle:SetText(L("DUNGEON_JOURNAL")) end
    if frame.UpdateSearchPlaceholder then frame.UpdateSearchPlaceholder() end
    if frame.RefreshSearchResults and frame.searchEditBox and (frame.searchEditBox:GetText() or "") ~= "" then
        frame.RefreshSearchResults(frame.searchEditBox:GetText())
    end
    if frame.backButton then frame.backButton:SetText(L("DUNGEONS")) end
    if frame.sourceLabel then frame.sourceLabel:SetText(L("FOREVER_BETA_DATA")) end
    if frame.dungeonRouteButton then frame.dungeonRouteButton:SetText(L("ROUTE")) end
    if frame.routeBackButton then frame.routeBackButton:SetText(L("BACK_TO_DUNGEON")) end
    if frame.routeMapButton then frame.routeMapButton:SetText(L("SHOW_ON_MAP")) end
    if frame.homeTitle then frame.homeTitle:SetText(L("BROWSE_DUNGEONS")) end
    if frame.homeSubtitle then frame.homeSubtitle:SetText(L("HOME_SUBTITLE")) end
    if FDJ.RelocalizeLootFilter then FDJ.RelocalizeLootFilter(frame) end
    if frame.hideDungeonsButton and frame.hideDungeonsButtonText then
        local label = homeEditMode and L("DONE") or L("HIDE_DUNGEONS")
        frame.hideDungeonsButtonText:SetText(label)
        if frame.hideDungeonsButtonText then
            frame.hideDungeonsButtonText:ClearAllPoints()
            frame.hideDungeonsButtonText:SetPoint("CENTER", homeEditMode and -8 or 0, 0)
        end
        if frame.hideDungeonsDoneCheck then
            frame.hideDungeonsDoneCheck:SetShown(homeEditMode)
        end
        local extra = homeEditMode and 44 or 26
        local width = math.max(126, math.min(180, math.ceil((frame.hideDungeonsButtonText:GetStringWidth() or 100) + extra)))
        frame.hideDungeonsButton:SetWidth(width)
    end
    if frame.bossesTab then frame.bossesTab:SetText(L("BOSSES")) end
    if frame.questsTab then frame.questsTab:SetText(L("QUESTS")) end
    if frame.mapTab then frame.mapTab:SetText(L("MAP")) end
    if frame.bossListTitle then frame.bossListTitle:SetText(L("BOSSES")) end
    if frame.questListTitle then frame.questListTitle:SetText(L("QUESTS")) end
    if frame.questObjectiveHeader then frame.questObjectiveHeader:SetText(L("OBJECTIVE")) end
    if frame.questDescHeader then frame.questDescHeader:SetText(L("DESCRIPTION")) end
    if frame.questRequiredItemsHeader then frame.questRequiredItemsHeader:SetText(L("REQUIRED_ITEMS")) end
    if frame.questProvidedItemHeader then frame.questProvidedItemHeader:SetText(L("PROVIDED_ITEM")) end
    if frame.questStartsHeader then frame.questStartsHeader:SetText(L("STARTS_AT")) end
    if frame.questTurninHeader then frame.questTurninHeader:SetText(L("TURN_IN")) end
    if frame.questNotesHeader then frame.questNotesHeader:SetText(L("NOTES")) end
    if frame.questShareButton and frame.questShareButton.questID then
        FDJ.UpdateQuestShareButton(frame.questShareButton.questID, frame.questShareButton._fdjClassLabel)
    end
    UpdateQuestActionButtonSizes()
    if frame.questRewardSummary then ApplyRewardSummaryFont(frame.questRewardSummary) end
    if frame.questRewardHeader and frame.questRewardHeader:GetText() ~= "" then
        frame.questRewardHeader:SetText(L("REWARDS"):upper())
    end

    -- Existing pooled rows/buttons may have been created under the previous
    -- language, so update their static labels as well.
    for _, button in ipairs(questButtons) do
        if button and button.UpdateHaveItLabel then
            button:UpdateHaveItLabel()
        elseif button and button.haveIt then
            button.haveIt:SetText(L("YOU_HAVE_IT"))
        end
    end
    for _, button in ipairs(bossButtons) do
        if button and button.rare then button.rare:SetText((button.fdjRareLabel and FDJ.RareLabelText and FDJ.RareLabelText(button.fdjRareLabel)) or button.fdjRareLabel or L("RARE")) end
    end
end

ShowDungeonPage = function()
    if not frame then return end
    if frame.homePanel then frame.homePanel:Hide() end
    if frame.contentPanel then frame.contentPanel:Show() end
    if frame.backButton then frame.backButton:Show() end
    frame.currentView = "dungeon"
    if FDJ.UpdateDungeonArrows then FDJ.UpdateDungeonArrows() end
    ForeverDungeonJournalDB.lastView = "dungeon"
end

-- dungeonarrows: the dungeons the < > arrows beside the Dungeons button step
-- through, in the home page's order: those shown there that can be opened
-- (not hidden, not locked by RPG Mode, not a preview without a map).
FDJ.DungeonNavList = function()
    local list = {}
    for _, name in ipairs(ORDER) do
        local d = DB[name]
        if d and not (FDJ.HomeFilterHides and FDJ.HomeFilterHides(name))
            and not FDJ.HiddenDungeons()[name]
            and not (FDJ.IsDungeonAutoHidden and FDJ.IsDungeonAutoHidden(name))
            and not (FDJ.IsDungeonLocked and FDJ.IsDungeonLocked(name))
            and not (d.previewOnly and not FDJ.DUNGEON_MAPS[name]) then
            list[#list + 1] = name
        end
    end
    return list
end

-- The next (step 1) or previous (step -1) dungeon; nil past either end
-- (no wrapping round).
FDJ.NeighbourDungeon = function(step)
    local list = FDJ.DungeonNavList()
    if #list == 0 then return nil end
    local at
    for i, name in ipairs(list) do
        if name == selectedDungeon then at = i break end
    end
    if not at then return list[step > 0 and 1 or #list] end
    return list[at + step]
end

-- Grey out the arrow that has nowhere to go (first / last dungeon).
-- The Cozy Sleeping Bag's quest page is not a dungeon: no arrows there.
FDJ.UpdateDungeonArrows = function()
    if not frame then return end
    local noArrows = (FDJ.SLEEPING_BAG_PAGE ~= nil and selectedDungeon == FDJ.SLEEPING_BAG_PAGE)
        or (FDJ.ONYXIA_PAGE ~= nil and selectedDungeon == FDJ.ONYXIA_PAGE) -- the Onyxia Attunement page neither
        or (FDJ.TIER05_PAGE ~= nil and selectedDungeon == FDJ.TIER05_PAGE) -- nor the Tier 0.5 page (2.0.8)
    for _, arrow in ipairs({ frame.prevDungeonButton, frame.nextDungeonButton }) do
        if arrow then
            arrow:SetShown(not noArrows)
            if not noArrows then arrow:SetEnabled(FDJ.NeighbourDungeon(arrow.step) ~= nil) end
        end
    end
end

-- Open the next / previous dungeon on the same page: Bosses and Quests stay
-- as they are (selectedMode); the Map stays open when that dungeon has one.
FDJ.StepDungeon = function(step)
    local target = FDJ.NeighbourDungeon(step)
    if not target or target == selectedDungeon then return end
    local onMap = frame and frame.dungeonMapPanel and frame.dungeonMapPanel:IsShown()
    SelectDungeon(target)
    if onMap and selectedDungeon == target and FDJ.DUNGEON_MAPS[target]
        and not frame.dungeonMapPanel:IsShown() then
        ShowDungeonMap()
    end
end

ShowHomePage = function()
    if not frame then return end
    if frame.contentPanel then frame.contentPanel:Hide() end
    if frame.homePanel then frame.homePanel:Show() end
    if frame.backButton then frame.backButton:Hide() end
    frame.currentView = "home"
    ForeverDungeonJournalDB.lastView = "home"
    RefreshHomeDungeonCards()
end

RefreshAll = function()
    ApplyLocalization()
    local dungeon = DB[selectedDungeon]

    ApplyTheme()

    frame.dungeonTitle:SetText(dungeon.recipeSearchTitle or DungeonName(selectedDungeon))
    -- "Matching loot" has no level line: larger title, centred in the header box.
    do
        local t = frame.dungeonTitle
        if not t.fdjFont then t.fdjFont = { t:GetFont() } end
        local font, size, flags = t.fdjFont[1], t.fdjFont[2], t.fdjFont[3]
        t:ClearAllPoints()
        if dungeon.lootFilterPage and font then
            t:SetFont(font, (size or 20) + 6, flags)
            t:SetPoint("LEFT", t:GetParent(), "LEFT", 18, 0)
        else
            if font then t:SetFont(font, size, flags) end
            t:SetPoint("TOPLEFT", 15, -10)
        end
    end
    if dungeon.recipeSearch or not dungeon.level or dungeon.level == "" then
        frame.dungeonMeta:SetText("")
    else
        frame.dungeonMeta:SetText(FDJ.HomeLevelText(dungeon.level))
    end
    if frame.dungeonLocationButton then
        frame.dungeonLocationButton:SetShown(dungeon.entrance ~= nil)
    end
    if FDJ.UpdateLFGButton then FDJ.UpdateLFGButton(frame, selectedDungeon, dungeon) end
    -- < > arrows: hidden on the Sleeping Bag page, back on any other page.
    if FDJ.UpdateDungeonArrows then FDJ.UpdateDungeonArrows() end
    if frame.dungeonRouteButton then
        local route = dungeon.routeGuide
        local playerFaction = UnitFactionGroup and UnitFactionGroup("player") or nil
        local allowed = route and (not route.faction or route.faction == playerFaction)
        frame.dungeonRouteButton:SetShown(allowed and true or false)
        if frame.dungeonRouteButton.icon then
            -- The Horde crest gets a thin black outline here so it stands out
            -- on the red button.
            local routeIcon = (route and route.faction == "Horde")
                and "Interface\\AddOns\\ForeverDungeonJournal\\Media\\HordeOutlined.tga" or ALLIANCE_ICON
            frame.dungeonRouteButton.icon:SetTexture(routeIcon)
        end
        if allowed then frame.dungeonRouteButton:SetText(L("ROUTE")) end
    end
    if frame.stockadeItemsTBD then
        frame.stockadeItemsTBD:SetText(FDJ.ItemsTBDText(selectedDungeon))
        frame.stockadeItemsTBD:SetShown(FDJ.ShowsItemsTBD(selectedDungeon))
    end
    if FDJ.UpdateQuestsTBD then FDJ.UpdateQuestsTBD() end

    UpdateDungeonHeaderTabs()
    UpdateTabs()

    local quests = dungeon.quests or {}
    if selectedQuest > #quests then selectedQuest = 1 end
    if selectedBoss > #dungeon.bosses then selectedBoss = 1 end

    if dungeon.previewOnly and FDJ.DUNGEON_MAPS[selectedDungeon] and ShowDungeonMap then
        ShowDungeonMap()
        return
    end
    -- sleepingbag: a quest chain page opens on its quests; the next
    -- dungeon opens on the tab used before it.
    if dungeon.questChainPage then
        if selectedMode ~= "quests" then FDJ.modeBeforeQuestChain = selectedMode end
        selectedMode = "quests"
    elseif FDJ.modeBeforeQuestChain then
        selectedMode = FDJ.modeBeforeQuestChain
        FDJ.modeBeforeQuestChain = nil
    end
    SetMode(selectedMode)
end

FDJ.GetSelectedDungeon = function() return selectedDungeon, selectedBoss end
-- Used by the world-map overlay: point the map renderer at a dungeon without
-- touching the journal window.
FDJ.SetMapDungeon = function(name) if DB[name] then selectedDungeon = name end end
FDJ.ReopenDungeonMap = function(dungeonName)
    if dungeonName == selectedDungeon and FDJ.DUNGEON_MAPS[dungeonName] then
        pcall(ShowDungeonMap)
    end
end

SelectBoss = function(index)
    local dungeon = DB[selectedDungeon]
    if not dungeon or not dungeon.bosses[index] then return end

    selectedBoss = index
    ForeverDungeonJournalDB.lastBoss = index

    -- Stay on the SAME page. Only refresh highlight + right-side loot pane.
    RefreshBossList()
    RefreshLoot()
end

-- searchonce (2.1.3, M 21 Nov 2026: "script ran too long" from a search
-- result for Baron Rivendare, in Uldaman with his group): a search result
-- built the page three times in one click (the dungeon's last tab, then the
-- Bosses tab with its first boss, then the boss), long enough for the game
-- to stop the journal in combat. opts = { mode = "bosses" | "quests",
-- boss = index }: the page opens straight on that tab and boss, built once.
SelectDungeon = function(name, opts)
    if not DB[name] then return end
    if DB[name].previewOnly and not FDJ.DUNGEON_MAPS[name] then return end
    -- RPG Mode: a dungeon stays locked until its final boss has been defeated.
    if FDJ.IsDungeonLocked and FDJ.IsDungeonLocked(name) then
        if FDJ.RPGLockedNotice then FDJ.RPGLockedNotice(name) end
        if frame and frame:IsShown() and ShowHomePage and frame.currentView ~= "home" then ShowHomePage() end
        return
    end

    ShowDungeonPage()
    selectedDungeon = name
    selectedBoss = 1
    selectedQuest = 1
    if type(opts) == "table" then -- searchonce
        local wantBoss = tonumber(opts.boss)
        if wantBoss and DB[name].bosses and DB[name].bosses[wantBoss] then selectedBoss = wantBoss end
        if opts.mode == "bosses" or opts.mode == "quests" then
            selectedMode = opts.mode
            FDJ.modeBeforeQuestChain = nil
        end
    end

    local hasCurrentFaction = false
    local fallbackFaction = nil
    for _, q in ipairs(DB[name].quests or {}) do
        if QuestMatchesFaction(q, selectedQuestFaction) then
            hasCurrentFaction = true
            break
        end
        if q.faction == "Alliance" or q.faction == "Horde" then
            fallbackFaction = fallbackFaction or q.faction
        end
    end
    if not hasCurrentFaction and fallbackFaction and not FDJ.FactionLocked(name) then -- questrowtrial: not to the other faction
        selectedQuestFaction = fallbackFaction
        ForeverDungeonJournalDB.questFaction = selectedQuestFaction
    end
    ForeverDungeonJournalDB.lastDungeon = name
    ForeverDungeonJournalDB.lastBoss = selectedBoss -- (searchonce: 1 unless a boss was asked for)
    ForeverDungeonJournalDB.lastQuest = 1
    frame.questListScroll:SetVerticalScroll(0)
    frame.bossListScroll:SetVerticalScroll(0)

    RefreshAll()
    if FDJ.UpdateDungeonArrows then FDJ.UpdateDungeonArrows() end

    if FDJ.DUNGEON_MAPS[name] and #(DB[name].bosses or {}) == 0 and #(DB[name].quests or {}) == 0 then
        ShowDungeonMap()
    end
end


local function CreateGlobalSearchUI()
    -- ============================================================
    -- GLOBAL SEARCH
    -- ============================================================
    -- Search is deliberately available from every journal page. Results include
    -- dungeons and every item already recorded in boss loot or quest data.
    local searchBox = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
    frame.searchEditBox = searchBox
    searchBox:SetSize(265, 26)
    searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -14)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(80)
    searchBox:SetFontObject("ForeverDJ_GameFontHighlightLarge")
    searchBox:SetTextInsets(27, 22, 0, 0)
    searchBox:SetJustifyH("LEFT")
    SetBackdrop(searchBox, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 10, 3)
    searchBox:SetBackdropColor(0.045, 0.043, 0.040, 0.98)
    searchBox:SetBackdropBorderColor(0.34, 0.31, 0.27, 1)

    local searchIcon = searchBox:CreateTexture(nil, "ARTWORK")
    searchIcon:SetSize(14, 14)
    searchIcon:SetPoint("LEFT", 7, 0)
    searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    searchIcon:SetVertexColor(0.72, 0.70, 0.66)

    local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    frame.searchPlaceholder = searchPlaceholder
    searchPlaceholder:SetPoint("LEFT", 28, 0)
    searchPlaceholder:SetTextColor(0.48, 0.47, 0.44)

    local searchClear = CreateFrame("Button", nil, searchBox)
    frame.searchClearButton = searchClear
    searchClear:SetSize(16, 16)
    searchClear:SetPoint("RIGHT", -5, 0)
    searchClear:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    searchClear:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    searchClear:Hide()

    local searchResults = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.searchResultsFrame = searchResults
    searchResults:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -3)
    searchResults:SetSize(340, 40)
    searchResults:SetFrameStrata("TOOLTIP")
    searchResults:SetFrameLevel(frame:GetFrameLevel() + 60)
    SetBackdrop(searchResults, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 10, 3)
    searchResults:SetBackdropColor(0.045, 0.042, 0.037, 0.995)
    searchResults:SetBackdropBorderColor(0.48, 0.40, 0.27, 1)
    searchResults:Hide()

    local searchRows = {}
    local currentSearchResults = {}
    local searchResultOffset = 0
    local MAX_VISIBLE_SEARCH_RESULTS = 6
    local MAX_SEARCH_RESULTS = 80

    -- Common Classic dungeon shorthand plus aliases for the two Forever dungeons.
    -- Deadmines is commonly called both DM and VC; Stockade is commonly "Stocks".
    -- RoL is already in use for Ruins of Lordaeron. Hall of Thanes is new, so
    -- support both natural initialisms players are likely to type (HoT / HT).
    local DUNGEON_SEARCH_ALIASES = FDJ.DUNGEON_SEARCH_ALIASES or {}

    -- Search speed: lower-cased strings, item names and filtered loot lists
    -- are cached, so each keystroke only does plain string matching.
    local searchLowerCache, searchLowerCount = {}, 0
    local searchNameCache = {}
    local searchLootCache = setmetatable({}, { __mode = "k" })
    -- searchlag: an item the client has not loaded yet is asked for once.
    -- Until its data arrives (GET_ITEM_INFO_RECEIVED -> FDJ.SearchItemArrived)
    -- the search uses the stored name and does not ask again: asking for every
    -- unloaded item on every key press made the game send back hundreds of
    -- item answers, and each one ran the whole search again (the lag after
    -- typing "dm w").
    FDJ.searchNamePending = FDJ.searchNamePending or {}
    FDJ.recipeSearchMiss = FDJ.recipeSearchMiss or {}
    FDJ.SearchItemArrived = function(itemID)
        itemID = tonumber(itemID)
        if not itemID then return end
        FDJ.searchNamePending[itemID] = nil
        FDJ.recipeSearchMiss[itemID] = nil
    end
    local function SearchText(value)
        local raw = tostring(value or "")
        local cached = searchLowerCache[raw]
        if cached then return cached end
        local s = raw:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        s = string.lower(s)
        if searchLowerCount > 20000 then searchLowerCache, searchLowerCount = {}, 0 end
        searchLowerCache[raw] = s
        searchLowerCount = searchLowerCount + 1
        return s
    end
    local function SearchableLoot(boss)
        if boss.childOf then return {} end -- altarbosses (2.0.24): found once, under the group
        local list = searchLootCache[boss]
        if not list then
            list = (FDJ.SearchableBossLoot and FDJ.SearchableBossLoot(boss)) or boss.loot or {}
            searchLootCache[boss] = list
        end
        return list
    end
    FDJ.ResetSearchCache = function() searchLootCache = setmetatable({}, { __mode = "k" }) end

    local function SearchMatchScore(query, ...)
        local best
        for i = 1, select("#", ...) do
            local value = select(i, ...)
            if value and value ~= "" then
                local raw = tostring(value)
                local lowered = SearchText(raw)
                local pos = string.find(lowered, query, 1, true)
                -- string.lower is ASCII-only on this client. Also try the raw
                -- UTF-8 string so localized names remain searchable when typed
                -- with their displayed capitalization.
                if not pos then
                    pos = string.find(raw, query, 1, true)
                end
                if pos then
                    local score = (pos == 1 and 0 or (20 + pos)) + math.min(#raw, 80) * 0.001
                    if not best or score < best then best = score end
                end
            end
        end
        return best
    end

    local function SearchItemDisplayName(item)
        if not item then return "" end
        local id, fallback = item[1], item[2]
        local known = id and searchNameCache[id]
        if known then return known end
        local pending = FDJ.searchNamePending
        if id and not pending[id] then
            local liveName = ItemInfo(id)
            if liveName and liveName ~= "" then
                searchNameCache[id] = liveName
                return liveName
            end
            pending[id] = true -- asked; wait for its data (FDJ.SearchItemArrived)
        end
        return FreeText(fallback or "")
    end

    local function AddSearchCandidate(results, candidate, query, baseScore, ...)
        local score = SearchMatchScore(query, ...)
        if not score then return end
        candidate.score = score + (baseScore or 0)
        results[#results + 1] = candidate
    end

    -- Recipe search results show the profession and the profession-skill level
    -- required to learn the recipe (for example: "Tailoring (125)"). The
    -- profession comes from our static loot tuple; the numeric requirement is
    -- read from the live item tooltip so Forever-specific values stay accurate.
    FDJ.recipeSearchRequirementCache = FDJ.recipeSearchRequirementCache or {}
    FDJ.GetRecipeSearchRequirement = FDJ.GetRecipeSearchRequirement or function(itemID, slotText)
        itemID = tonumber(itemID)
        local profession = tostring(slotText or ""):match("[Rr]ecipe,%s*(.+)")
        if not profession or profession == "" then
            profession = tostring(slotText or ""):match("(.+)%s+[Rr]ecipe")
        end
        profession = profession and profession:gsub("^%s+", ""):gsub("%s+$", "") or ""

        if itemID and FDJ.recipeSearchRequirementCache[itemID] then
            local cached = FDJ.recipeSearchRequirementCache[itemID]
            if profession ~= "" and cached.skill then
                return profession .. " (" .. tostring(cached.skill) .. ")"
            end
            return profession ~= "" and profession or (cached.text or "")
        end
        -- searchlag: already read without finding the skill; read it again
        -- only once the item's data has arrived.
        if itemID and FDJ.recipeSearchMiss and FDJ.recipeSearchMiss[itemID] then
            return profession
        end

        local skill
        if itemID and C_TooltipInfo and type(C_TooltipInfo.GetItemByID) == "function" then
            local ok, data = pcall(C_TooltipInfo.GetItemByID, itemID)
            if ok and type(data) == "table" and type(data.lines) == "table" then
                -- Scan from the BOTTOM of the tooltip. Recipe material lines often
                -- contain counts such as "Bolt of Woolen Cloth (8)"; the actual
                -- profession requirement (for example "Requires Tailoring (75)")
                -- appears later in the tooltip, immediately above the sell price.
                -- Reading bottom-up prevents reagent counts from being mistaken
                -- for the profession skill requirement.
                for i = #data.lines, 1, -1 do
                    local line = data.lines[i]
                    local lineText = line and (line.leftText or line.text)
                    if type(lineText) == "string" then
                        local value = lineText:match("%((%d+)%)")
                        if value then
                            skill = tonumber(value)
                            break
                        end
                    end
                end
            end
        end

        -- Fallback for clients where C_TooltipInfo does not expose line text.
        if itemID and not skill and CreateFrame and UIParent then
            if not FDJ.recipeSearchScanTooltip then
                local ok, tip = pcall(CreateFrame, "GameTooltip", "ForeverDungeonJournalRecipeSearchTooltip", UIParent, "GameTooltipTemplate")
                if ok then FDJ.recipeSearchScanTooltip = tip end
            end
            local tip = FDJ.recipeSearchScanTooltip
            if tip then
                tip:Hide()
                tip:SetOwner(UIParent, "ANCHOR_NONE")
                if tip.ClearLines then tip:ClearLines() end
                local ok = pcall(tip.SetHyperlink, tip, "item:" .. tostring(itemID))
                if ok then
                    local count = (tip.NumLines and tip:NumLines()) or 0
                    -- Same bottom-up rule as above: the profession requirement
                    -- is below the recipe's reagent list, so the first parenthesized
                    -- number found from the bottom is the skill requirement rather
                    -- than a material quantity.
                    for i = count, 2, -1 do
                        local fs = _G["ForeverDungeonJournalRecipeSearchTooltipTextLeft" .. i]
                        local lineText = fs and fs.GetText and fs:GetText()
                        if type(lineText) == "string" then
                            local value = lineText:match("%((%d+)%)")
                            if value then
                                skill = tonumber(value)
                                break
                            end
                        end
                    end
                end
                tip:Hide()
            end
        end

        if itemID and skill then
            FDJ.recipeSearchRequirementCache[itemID] = { skill = skill }
        elseif itemID then
            if FDJ.recipeSearchMiss then FDJ.recipeSearchMiss[itemID] = true end
            if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
                pcall(C_Item.RequestLoadItemDataByID, itemID)
            end
        end

        if profession ~= "" and skill then
            return profession .. " (" .. tostring(skill) .. ")"
        end
        return profession
    end

    -- rpgsearch: dungeons the search leaves out - locked pages, and in RPG
    -- Mode the "coming soon" ones too (blank pages there).
    local function SearchSkipsDungeon(dungeonName)
        if FDJ.IsDungeonLocked and FDJ.IsDungeonLocked(dungeonName) then return true end
        local dungeon = DB[dungeonName]
        return (dungeon and dungeon.previewOnly and FDJ.IsRPGMode and FDJ.IsRPGMode()) and true or false
    end

    local function AddQuestSearchItem(list, item)
        if item and type(item[1]) == "number" and item[1] > 0 then list[#list + 1] = item end
    end

    local function BuildSearchResults(queryText)
        local query = SearchText(queryText):gsub("^%s+", ""):gsub("%s+$", "")
        local results = {}
        -- Recipe tabs repeat the same pattern/plan in every dungeon where it
        -- can drop. Search presents each recipe only once; clicking that one
        -- result opens a hidden source page containing every boss that drops it.
        local recipeCandidates = {}

        -- Clicking an empty search box acts as a dungeon browser. Keep the
        -- journal's normal dungeon order and let the dropdown scroll if needed.
        if query == "" then
            for _, dungeonName in ipairs(ORDER or {}) do
                local dungeon = DB[dungeonName]
                if dungeon and not SearchSkipsDungeon(dungeonName) then
                    results[#results + 1] = {
                        kind = "dungeon",
                        dungeonName = dungeonName,
                        displayName = DungeonName(dungeonName),
                        subText = DungeonField(dungeonName, "location", dungeon.location or ""),
                        icon = DUNGEON_HOME_ART[dungeonName] or dungeon.icon,
                        texCoord = DUNGEON_HOME_TEXCOORD[dungeonName],
                        score = 0,
                    }
                end
            end
            return results
        end

        -- One letter only matches dungeon names; items and quests need two.
        for _, dungeonName in ipairs(ORDER or {}) do
            local dungeon = DB[dungeonName]
            if dungeon and not SearchSkipsDungeon(dungeonName) then
                local localizedDungeon = DungeonName(dungeonName)
                local aliases = DUNGEON_SEARCH_ALIASES[dungeonName]
                local aliasText = aliases and table.concat(aliases, " ") or ""
                AddSearchCandidate(results, {
                    kind = "dungeon",
                    dungeonName = dungeonName,
                    displayName = localizedDungeon,
                    subText = DungeonField(dungeonName, "location", dungeon.location or ""),
                    icon = DUNGEON_HOME_ART[dungeonName] or dungeon.icon,
                    texCoord = DUNGEON_HOME_TEXCOORD[dungeonName],
                }, query, -30, localizedDungeon, dungeonName, aliasText)

                -- bosssearch (2.0.8, M 15 Nov 2026): the bosses too (two letters
                -- or more, like items), not the Trash Drops / Recipes pages, not
                -- a boss RPG Mode still hides; ahead of items with the same match
                for bossIndex, boss in ipairs((#query >= 2) and dungeon.bosses or {}) do
                    if type(boss.name) == "string" and not (boss.trash or boss.recipeTab or boss.childOf or boss.lootChest)
                        and not (FDJ.RPGBossHidden and FDJ.RPGBossHidden(dungeonName, boss)) then
                        local shownName = BossName(boss.name)
                        local aliases = type(boss.aliases) == "table" and boss.aliases or {}
                        local bossScore = SearchMatchScore(query, shownName, boss.name, aliases[1], aliases[2], aliases[3])
                        if bossScore then
                            results[#results + 1] = {
                                score = bossScore - 10,
                                kind = "boss",
                                dungeonName = dungeonName,
                                bossIndex = bossIndex,
                                boss = boss,
                                displayName = shownName,
                                subText = localizedDungeon,
                            }
                        end
                    end
                end

                for bossIndex, boss in ipairs((#query >= 2) and dungeon.bosses or {}) do
                    -- Search follows the Loot Filter: hidden items are not offered
                    -- (blueprints are always shown on boss pages, so always offered).
                    for _, item in ipairs(SearchableLoot(boss)) do
                        local itemName = SearchItemDisplayName(item)
                        -- Match first; build the result (icon, tooltip-read
                        -- recipe skill, labels) only for items that match.
                        local matchScore = SearchMatchScore(query, itemName, item[2])
                        if not matchScore then
                            -- no match: nothing to build
                        elseif boss.recipeTab then
                            -- The Recipes & Patterns pseudo-boss exists once per
                            -- dungeon. Collapse those repeated rows into one global
                            -- search result per actual recipe item.
                            local recipeID = tonumber(item[1])
                            if recipeID and not recipeCandidates[recipeID] then
                                recipeCandidates[recipeID] = true
                                results[#results + 1] = {
                                    kind = "item",
                                    mode = "recipe",
                                    dungeonName = dungeonName,
                                    itemID = recipeID,
                                    displayName = itemName,
                                    recipeSlot = item[3], -- (subText when shown)
                                    iconID = recipeID, -- (icon when shown)
                                    score = matchScore,
                                }
                            end
                        else
                            results[#results + 1] = {
                                score = matchScore,
                                kind = "item",
                                mode = "bosses",
                                dungeonName = dungeonName,
                                bossIndex = bossIndex,
                                itemID = item[1],
                                item = item, -- kroldok: no ID yet, its stats on hover
                                displayName = itemName,
                                subText = localizedDungeon .. "  -  " .. BossName(boss.name),
                                -- Boss-loot tuple field 5 is optional source/mob text,
                                -- not an icon path. Always resolve the search icon from
                                -- the actual item ID so trash drops never try to use
                                -- strings such as "Defias Strip Miner" as textures.
                                iconID = item[1], -- (icon when shown)
                            }
                        end
                        -- lootchildren (2.0.8): the item a half makes is found
                        -- too (Sul'thraze: on Antu'sul's and the Chief's pages),
                        -- unless the Loot Filter rules it out (like any item)
                        local made = (not boss.recipeTab) and type(item) == "table" and type(item.makes) == "table" and item.makes or nil
                        local madeName = made and SearchItemDisplayName(made)
                        local madeScore = made and SearchMatchScore(query, madeName, made[2])
                        if madeScore and not (FDJ.LootFilterRulesOut and FDJ.LootFilterRulesOut(made)) then
                            results[#results + 1] = {
                                score = madeScore,
                                kind = "item",
                                mode = "bosses",
                                dungeonName = dungeonName,
                                bossIndex = bossIndex,
                                itemID = made[1],
                                item = made,
                                displayName = madeName,
                                subText = localizedDungeon .. "  -  " .. BossName(boss.name),
                                iconID = made[1],
                            }
                        end
                    end
                end

                for questIndex, quest in ipairs((#query >= 2) and dungeon.quests or {}) do
                    local questName -- searchlag: looked up only for a quest that matched

                    local questItems = {}
                    if not (FDJ.RPGQuestHidden and FDJ.RPGQuestHidden(dungeonName, quest)) then
                        for _, item in ipairs(quest.rewardItems or {}) do AddQuestSearchItem(questItems, item) end
                        for _, item in ipairs(quest.additionalRewardItems or {}) do AddQuestSearchItem(questItems, item) end
                        for _, item in ipairs(quest.noteRewardItems or {}) do AddQuestSearchItem(questItems, item) end
                        AddQuestSearchItem(questItems, quest.requiredItem)
                        AddQuestSearchItem(questItems, quest.startItem)
                        AddQuestSearchItem(questItems, quest.noteItem)
                    end

                    for _, item in ipairs(questItems) do
                        local itemName = SearchItemDisplayName(item)
                        local matchScore = SearchMatchScore(query, itemName, item[2])
                        if matchScore then
                            questName = questName or QuestField(quest.id, "name", quest.name or "")
                            results[#results + 1] = {
                            score = matchScore + 4,
                            kind = "item",
                            mode = "quests",
                            dungeonName = dungeonName,
                            questIndex = questIndex,
                            questFaction = quest.faction,
                            faction = quest.faction,
                            itemID = item[1],
                            displayName = itemName,
                            subText = localizedDungeon .. "  -  " .. questName,
                            iconID = item[1],
                        } end
                    end
                end
            end
        end

        table.sort(results, function(a, b)
            if a.score ~= b.score then return a.score < b.score end
            return tostring(a.displayName or "") < tostring(b.displayName or "")
        end)

        -- The same static item can be referenced more than once by a quest/data
        -- entry. Keep one result per actual source location so the dropdown never
        -- shows duplicate rows such as Gravestone Scepter twice for one quest.
        local unique, seen = {}, {}
        for _, result in ipairs(results) do
            local sourceIndex = result.mode == "bosses" and result.bossIndex or result.questIndex
            local key
            if result.kind == "dungeon" then
                key = "d|" .. tostring(result.dungeonName)
            elseif result.kind == "boss" then
                key = "b|" .. tostring(result.dungeonName) .. "|" .. tostring(result.bossIndex)
            elseif result.kind == "quest" then
                key = "q|" .. tostring(result.dungeonName) .. "|" .. tostring(result.questIndex or "")
            elseif result.mode == "recipe" then
                key = "r|" .. tostring(result.itemID or "")
            else
                key = table.concat({
                    "i",
                    tostring(result.itemID or ""),
                    tostring(result.dungeonName or ""),
                    tostring(result.mode or ""),
                    tostring(sourceIndex or ""),
                }, "|")
            end
            if not seen[key] and not (result.mode == "quests" and FDJ.FactionHiddenFor(result.dungeonName, result.questFaction)) then -- questrowtrial
                seen[key] = true
                unique[#unique + 1] = result
                if #unique >= MAX_SEARCH_RESULTS then break end
            end
        end
        return unique
    end

    local function FindVisibleSearchItemButton(result)
        if not result or not result.itemID then return nil end
        if result.mode == "bosses" then
            for _, row in ipairs(lootRows) do
                if row:IsShown() and row.item and tonumber(row.item[1]) == tonumber(result.itemID) then
                    return row, frame.lootScroll, frame.lootContent
                end
            end
            for _, row in ipairs(frame.lootChildRows or {}) do -- lootchildren
                if row:IsShown() and row.item and tonumber(row.item[1]) == tonumber(result.itemID) then
                    return row, frame.lootScroll, frame.lootContent
                end
            end
        elseif result.mode == "quests" then
            for _, button in ipairs(questRewardButtons) do
                if button:IsShown() and button.item and tonumber(button.item[1]) == tonumber(result.itemID) then
                    return button, frame.questDetailScroll, frame.questDetailContent
                end
            end
            for _, button in ipairs(questNoteRewardButtons) do
                if button:IsShown() and button.item and tonumber(button.item[1]) == tonumber(result.itemID) then
                    return button, frame.questDetailScroll, frame.questDetailContent
                end
            end
            local noteButton = frame.questNoteItemButton
            if noteButton and noteButton:IsShown() and noteButton.item
                and tonumber(noteButton.item[1]) == tonumber(result.itemID) then
                return noteButton, frame.questDetailScroll, frame.questDetailContent
            end
        end
        return nil
    end

    local function FocusSearchItem(result)
        local function ApplyFocus()
            local button, scroll, content = FindVisibleSearchItemButton(result)
            if not button then return end

            if scroll and content then
                local contentTop = content:GetTop()
                local buttonTop = button:GetTop()
                local viewportHeight = scroll:GetHeight() or 0
                local contentHeight = content:GetHeight() or 0
                if contentTop and buttonTop and viewportHeight > 0 then
                    local itemOffset = math.max(0, contentTop - buttonTop)
                    local maxScroll = math.max(0, contentHeight - viewportHeight)
                    -- Put the searched item near the upper third of the visible
                    -- page so the surrounding Reward/Boss context remains clear.
                    local desired = itemOffset - math.max(12, viewportHeight * 0.28)
                    desired = math.max(0, math.min(maxScroll, desired))
                    scroll:SetVerticalScroll(desired)
                    if scroll.ScrollBar then scroll.ScrollBar:SetValue(desired) end
                end
            end
            ShowSearchItemHighlight(button)
            if result.glowFor and C_Timer and C_Timer.After then
                local glow = button.fdjSearchGlow
                C_Timer.After(result.glowFor, function()
                    if button.fdjSearchGlow == glow then HideSearchItemHighlight(button) end
                end)
            end
        end

        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(0.03, ApplyFocus)
        else
            ApplyFocus()
        end
    end

    -- Favourites uses the same focus/highlight path as global search. Export the
    -- helper here, while FocusSearchItem is actually in lexical scope.
    FDJ.FocusBossLootItem = function(itemID)
        itemID = tonumber(itemID)
        if not itemID then return end
        FocusSearchItem({ kind = "item", mode = "bosses", itemID = itemID })
    end

    local function OpenRecipeSearchResult(result)
        local itemID = result and tonumber(result.itemID)
        if not itemID then return false end

        local sourceBosses, seenSources = {}, {}
        for _, sourceDungeonName in ipairs(ORDER or {}) do
            local sourceDungeon = DB[sourceDungeonName]
            if sourceDungeon and not (FDJ.IsDungeonLocked and FDJ.IsDungeonLocked(sourceDungeonName)) then
                for _, sourceBoss in ipairs(sourceDungeon.bosses or {}) do
                    -- Recipe-tab rows are synthetic duplicates. Build this hidden
                    -- page from the real bosses only.
                    if not sourceBoss.recipeTab
                        and not (FDJ.RPGBossHidden and FDJ.RPGBossHidden(sourceDungeonName, sourceBoss)) then
                        for _, sourceItem in ipairs(sourceBoss.loot or {}) do
                            if tonumber(sourceItem[1]) == itemID then
                                local sourceKey = tostring(sourceDungeonName) .. "|" .. tostring(sourceBoss.name)
                                if not seenSources[sourceKey] then
                                    seenSources[sourceKey] = true
                                    sourceBosses[#sourceBosses + 1] = setmetatable({
                                        fdjDungeon = sourceDungeonName,
                                        loot = { sourceItem },
                                    }, { __index = sourceBoss })
                                end
                                break
                            end
                        end
                    end
                end
            end
        end

        if #sourceBosses == 0 then return false end

        local pageKey = "__FDJ_RECIPE_SEARCH__"
        DB[pageKey] = {
            recipeSearch = true,
            recipeSearchTitle = result.displayName or SearchItemDisplayName({ itemID, "Recipe" }),
            bosses = sourceBosses,
            quests = {},
        }

        -- This page intentionally is not added to ORDER and never becomes a
        -- normal dungeon tile. It only exists for the current recipe search.
        ShowDungeonPage()
        selectedDungeon = pageKey
        selectedBoss = 1
        selectedQuest = 1
        selectedMode = "bosses"
        if frame.bossListScroll then frame.bossListScroll:SetVerticalScroll(0) end
        if frame.lootScroll then frame.lootScroll:SetVerticalScroll(0) end
        RefreshAll()
        return true
    end

    local function OpenSearchResult(result)
        if not result or not result.dungeonName then return end
        searchBox:ClearFocus()
        searchBox:SetText("")
        searchResults:Hide()
        if result.kind == "item" and result.mode == "recipe" then
            OpenRecipeSearchResult(result)
            return
        end
        -- searchonce (2.1.3): the page is built once, on the right tab and boss
        if result.kind == "boss" or (result.kind == "item" and result.mode == "bosses") then
            SelectDungeon(result.dungeonName, { mode = "bosses", boss = result.bossIndex })
            if result.kind == "item" then FocusSearchItem(result) end
        elseif (result.kind == "item" or result.kind == "quest") and result.mode == "quests" then
            SelectDungeon(result.dungeonName, { mode = "quests" })
            if (result.questFaction == "Alliance" or result.questFaction == "Horde") and SetQuestFaction
                and result.questFaction ~= selectedQuestFaction then
                SetQuestFaction(result.questFaction)
            end
            if result.questIndex then
                local found = DB[selectedDungeon] and DB[selectedDungeon].quests and DB[selectedDungeon].quests[result.questIndex]
                SelectQuest(result.questIndex, FDJ.QuestHiddenAsDone(found)) -- (hidedone)
            end
            if result.kind == "item" then FocusSearchItem(result) end
        else
            SelectDungeon(result.dungeonName)
        end
    end

    -- Used by Systems/ItemSource.lua to jump to an item from a tooltip.
    FDJ.OpenSearchResult = OpenSearchResult

    local function EnsureSearchRow(index)
        local row = searchRows[index]
        if row then return row end

        row = CreateFrame("Button", nil, searchResults)
        row:SetHeight(39)
        row:SetPoint("LEFT", 5, 0)
        row:SetPoint("RIGHT", -5, 0)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

        row.factionIcon = row:CreateTexture(nil, "OVERLAY")
        row.factionIcon:SetSize(18, 18)
        row.factionIcon:SetPoint("RIGHT", -5, 0)
        row.factionIcon:Hide()

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(28, 28)
        row.icon:SetPoint("LEFT", 7, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        row.name = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 9, -3)
        row.name:SetPoint("RIGHT", row, "RIGHT", -9, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetTextColor(1.00, 0.82, 0.27)

        row.source = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
        row.source:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
        row.source:SetPoint("RIGHT", row, "RIGHT", -9, 0)
        row.source:SetJustifyH("LEFT")
        row.source:SetTextColor(0.68, 0.66, 0.61)

        row:SetScript("OnClick", function(self)
            PlayJournalOptionSound()
            OpenSearchResult(self.searchResult)
        end)

        -- Item tooltip on hover, placed to the RIGHT of the results list so it
        -- never covers the other results.
        row:SetScript("OnEnter", function(self)
            local result = self.searchResult
            if not result or result.kind ~= "item" or not result.itemID or not itemTooltip then return end
            itemTooltip:Hide()
            itemTooltip:SetOwner(self, "ANCHOR_NONE")
            if itemTooltip.ClearLines then itemTooltip:ClearLines() end
            if (tonumber(result.itemID) or 0) <= 0 then -- kroldok: item ID not known yet
                local item = result.item or {}
                local r, g, b = QualityColor(tonumber(item[4]) or 1)
                itemTooltip:AddLine(result.displayName or item[2] or "", r, g, b)
                FDJ.AddItemTipLines(itemTooltip, item)
            else
                local _, liveLink = ItemInfo(result.itemID)
                itemTooltip:SetHyperlink(liveLink or ("item:" .. result.itemID))
                FDJ.AddUnseenItemHint(itemTooltip)
            end
            itemTooltip:Show()
            if FDJ.RefreshTooltipBacking then FDJ.RefreshTooltipBacking() end
            itemTooltip:ClearAllPoints()
            itemTooltip:SetPoint("TOPLEFT", searchResults, "TOPRIGHT", 4, 0)
        end)
        row:SetScript("OnLeave", function()
            if itemTooltip then itemTooltip:Hide() end
        end)

        searchRows[index] = row
        return row
    end

    local lastSearchQuery
    local function RefreshSearchResults(queryText, preserveOffset)
        -- bosssearch: scrolling the list (same text) doesn't search again
        if not (preserveOffset and lastSearchQuery == (queryText or "")) then
            currentSearchResults = BuildSearchResults(queryText or "")
            lastSearchQuery = queryText or ""
        end
        local hasQuery = SearchText(queryText or ""):match("%S") ~= nil
        local browsingDungeons = not hasQuery and searchBox:HasFocus()
        searchClear:SetShown(hasQuery)

        if not preserveOffset then searchResultOffset = 0 end
        local maxOffset = math.max(0, #currentSearchResults - MAX_VISIBLE_SEARCH_RESULTS)
        searchResultOffset = math.max(0, math.min(maxOffset, searchResultOffset))

        for _, row in ipairs(searchRows) do row:Hide() end
        if not hasQuery and not browsingDungeons then
            searchResults:Hide()
            return
        end

        if #currentSearchResults == 0 then
            local row = EnsureSearchRow(1)
            row.factionIcon:Hide()
            row.icon:ClearAllPoints()
            row.icon:SetPoint("LEFT", 7, 0)
            row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            row.icon:SetSize(28, 28)
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.name:SetText(L("SEARCH_NO_RESULTS"))
            row.source:SetText("")
            row.searchResult = nil
            row:EnableMouse(false)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", searchResults, "TOPLEFT", 5, -5)
            row:SetPoint("TOPRIGHT", searchResults, "TOPRIGHT", -5, -5)
            row:Show()
            searchResults:SetHeight(49)
            searchResults:Show()
            return
        end

        local visibleCount = math.min(MAX_VISIBLE_SEARCH_RESULTS, #currentSearchResults - searchResultOffset)
        for visibleIndex = 1, visibleCount do
            local result = currentSearchResults[searchResultOffset + visibleIndex]
            local row = EnsureSearchRow(visibleIndex)
            row:EnableMouse(true)
            row.searchResult = result

            row.factionIcon:Hide()
            row.icon:ClearAllPoints()
            row.icon:SetPoint("LEFT", 7, 0)
            local hasFactionIcon = false
            if result.kind == "item" and result.faction == "Alliance" then
                row.factionIcon:SetTexture(ALLIANCE_ICON)
                row.factionIcon:Show()
                hasFactionIcon = true
            elseif result.kind == "item" and result.faction == "Horde" then
                row.factionIcon:SetTexture(HORDE_ICON)
                row.factionIcon:Show()
                hasFactionIcon = true
            end

            row.name:ClearAllPoints()
            -- All item results, including recipes, use the two-line layout so
            -- recipes can show their profession + required skill underneath.
            row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 9, -3)
            row.name:SetPoint("RIGHT", row, "RIGHT", hasFactionIcon and -30 or -9, 0)
            row.source:ClearAllPoints()
            row.source:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
            row.source:SetPoint("RIGHT", row, "RIGHT", hasFactionIcon and -30 or -9, 0)

            -- bosssearch: icons and a recipe's skill only for the rows shown
            if not result.icon and result.iconID then result.icon = ItemIcon(result.iconID) end
            if result.mode == "recipe" and result.subText == nil then
                result.subText = FDJ.GetRecipeSearchRequirement(result.itemID, result.recipeSlot) or ""
            end
            -- (always handed back, not only when it had one: softhost, 2.0.9:
            -- a row that found no room for its portrait is given it later)
            row.fdjPortrait = nil
            if FDJ.ReleasePortrait then pcall(FDJ.ReleasePortrait, row.icon) end
            row.icon:SetTexture(result.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            if result.kind == "boss" then
                -- the boss's portrait when the journal has its look, else a skull
                row.icon:SetSize(28, 28)
                row.icon:SetTexCoord(0, 1, 0, 1)
                local look = result.boss and (result.boss.displayID or FDJ.STATIC_DISPLAY_IDS and FDJ.STATIC_DISPLAY_IDS[tonumber(result.boss.npcID) or 0])
                if look and FDJ.AcquirePortrait and select(2, pcall(FDJ.AcquirePortrait, row.icon, look)) == true then
                    row.fdjPortrait = true
                else
                    row.icon:SetTexture("Interface\\Icons\\INV_Misc_Bone_HumanSkull_01")
                    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                end
            elseif result.kind == "dungeon" then
                row.icon:SetSize(44, 28)
                local tc = result.texCoord
                if tc then
                    row.icon:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
                else
                    row.icon:SetTexCoord(0.08, 0.92, 0.18, 0.82)
                end
            else
                row.icon:SetSize(28, 28)
                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            row.name:SetText(result.displayName or "")
            row.source:SetText(result.subText or "")
            row:ClearAllPoints()
            local rowY = -5 - ((visibleIndex - 1) * 39)
            row:SetPoint("TOPLEFT", searchResults, "TOPLEFT", 5, rowY)
            row:SetPoint("TOPRIGHT", searchResults, "TOPRIGHT", -5, rowY)
            row:Show()
        end
        searchResults:SetHeight(10 + (visibleCount * 39))
        searchResults:Show()
        ApplyLocaleFontTree(searchResults)
    end

    frame.RefreshSearchResults = RefreshSearchResults
    frame.UpdateSearchPlaceholder = function()
        searchPlaceholder:SetText(L("SEARCH"))
        searchPlaceholder:SetShown((searchBox:GetText() or "") == "" and not searchBox:HasFocus())
    end

    -- Typing waits a moment before searching, so fast typing runs one search
    -- instead of one per letter.
    local searchToken = 0
    searchBox:SetScript("OnTextChanged", function(self, userInput)
        searchPlaceholder:SetShown((self:GetText() or "") == "" and not self:HasFocus())
        searchToken = searchToken + 1
        local token = searchToken
        if userInput and C_Timer and type(C_Timer.After) == "function" and (self:GetText() or "") ~= "" then
            C_Timer.After(0.12, function()
                if token == searchToken then RefreshSearchResults(self:GetText() or "") end
            end)
        else
            RefreshSearchResults(self:GetText() or "")
        end
    end)
    searchBox:SetScript("OnEditFocusGained", function(self)
        searchPlaceholder:Hide()
        -- New search session: re-read the loot lists (the Loot Filter may have changed).
        if FDJ.ResetSearchCache then FDJ.ResetSearchCache() end
        RefreshSearchResults(self:GetText() or "")
    end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        local function ResetIfClickedAway()
            if searchResults:IsMouseOver() or searchBox:IsMouseOver() then
                searchPlaceholder:SetShown((self:GetText() or "") == "")
                return
            end
            self:SetText("")
            searchResultOffset = 0
            searchResults:Hide()
            searchClear:Hide()
            searchPlaceholder:Show()
        end
        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(0, ResetIfClickedAway)
        else
            ResetIfClickedAway()
        end
    end)
    searchResults:EnableMouseWheel(true)
    searchResults:SetScript("OnMouseWheel", function(_, delta)
        local maxOffset = math.max(0, #currentSearchResults - MAX_VISIBLE_SEARCH_RESULTS)
        if maxOffset <= 0 then return end
        if delta < 0 then
            searchResultOffset = math.min(maxOffset, searchResultOffset + 1)
        elseif delta > 0 then
            searchResultOffset = math.max(0, searchResultOffset - 1)
        end
        RefreshSearchResults(searchBox:GetText() or "", true)
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        searchResults:Hide()
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        if currentSearchResults[1] then
            PlayJournalOptionSound()
            OpenSearchResult(currentSearchResults[1])
        else
            self:ClearFocus()
        end
    end)
    searchClear:SetScript("OnClick", function()
        searchBox:SetText("")
        searchBox:SetFocus()
    end)
    frame.UpdateSearchPlaceholder()
end

local function CreateMainFrame()
    frame = CreateFrame(
        "Frame",
        "ForeverDungeonJournalFrame",
        UIParent,
        "BackdropTemplate"
    )

    frame:SetSize(850, 590)
    frame:SetPoint("CENTER", 0, 10)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    SetBackdrop(
        frame,
        "Interface\\FrameGeneral\\UI-Background-Rock",
        "Interface\\DialogFrame\\UI-DialogBox-Border",
        24,
        6
    )
    frame:SetBackdropColor(0.045, 0.042, 0.037, 0.99)

    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    local top = frame:CreateTexture(nil, "BACKGROUND")
    top:SetTexture("Interface\\Buttons\\WHITE8X8")
    top:SetColorTexture(0.14, 0.10, 0.055, 0.96)
    top:SetPoint("TOPLEFT", 12, -10)
    top:SetPoint("TOPRIGHT", -12, -10)
    top:SetHeight(34)
    frame.topStrip = top

    local topLine = frame:CreateTexture(nil, "ARTWORK")
    topLine:SetTexture("Interface\\Buttons\\WHITE8X8")
    topLine:SetPoint("TOPLEFT", top, "TOPLEFT", 0, 0)
    topLine:SetPoint("TOPRIGHT", top, "TOPRIGHT", 0, 0)
    topLine:SetHeight(1)
    topLine:SetColorTexture(0.68, 0.52, 0.20, 0.65)
    frame.topStripLine = topLine

    local bottomLine = frame:CreateTexture(nil, "ARTWORK")
    bottomLine:SetTexture("Interface\\Buttons\\WHITE8X8")
    bottomLine:SetPoint("BOTTOMLEFT", top, "BOTTOMLEFT", 0, 0)
    bottomLine:SetPoint("BOTTOMRIGHT", top, "BOTTOMRIGHT", 0, 0)
    bottomLine:SetHeight(1)
    bottomLine:SetColorTexture(0.68, 0.52, 0.20, 0.45)
    frame.topStripBottomLine = bottomLine

    local title = frame:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalLarge")
    frame.mainTitle = title
    title:SetPoint("TOP", 0, -18)
    title:SetText(L("DUNGEON_JOURNAL"))
    title:SetTextColor(0.96, 0.79, 0.25)

    -- Compact language selector beside the journal title. The selected language
    -- and the familiar page arrows make the control self-explanatory, so the
    -- old "Languages" label is intentionally omitted.
    local function StyleLanguageArrowButton(button, direction)
        local isLeft = direction == "LEFT"
        -- Use Blizzard's native spellbook page buttons. These are the same
        -- clean, gold triangular arrows used by classic-era Blizzard UI.
        local normal = isLeft and "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up" or "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"
        local pushed = isLeft and "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down" or "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down"
        local disabled = isLeft and "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled" or "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled"
        button:SetNormalTexture(normal)
        button:SetPushedTexture(pushed)
        button:SetDisabledTexture(disabled)
        local normalTex = button:GetNormalTexture()
        if normalTex then normalTex:SetAllPoints(button) end
        local pushedTex = button:GetPushedTexture()
        if pushedTex then pushedTex:SetAllPoints(button) end
        local disabledTex = button:GetDisabledTexture()
        if disabledTex then disabledTex:SetAllPoints(button) end
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        highlight:SetBlendMode("ADD")
        highlight:SetAllPoints(button)
    end

    local languageSelector = CreateFrame("Button", nil, frame, "BackdropTemplate")
    frame.languageSelectorButton = languageSelector
    frame.languageSelectorButton = languageSelector
    languageSelector:SetSize(110, 24)
    languageSelector:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -49, -15)
    SetBackdrop(languageSelector, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 12, 4)
    languageSelector:SetBackdropColor(0.12, 0.115, 0.105, 0.98)
    languageSelector:SetBackdropBorderColor(0.48, 0.40, 0.27, 1)
    languageSelector:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    -- Small down arrow: shows the box opens a list of languages.
    local languageCaret = languageSelector:CreateTexture(nil, "OVERLAY")
    languageCaret:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    languageCaret:SetSize(12, 12)
    languageCaret:SetPoint("RIGHT", languageSelector, "RIGHT", -7, -3)

    local languageSelectorText = languageSelector:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    frame.languageSelectorText = languageSelectorText
    languageSelectorText:SetPoint("LEFT", 8, 0)
    languageSelectorText:SetPoint("RIGHT", -20, 0)
    languageSelectorText:SetJustifyH("CENTER")
    languageSelectorText:SetTextColor(1.00, 0.82, 0.27)

    local languageMenu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.languageMenu = languageMenu
    languageMenu:SetSize(158, (#LANGUAGE_CHOICES * 24) + 10)
    languageMenu:SetPoint("TOPLEFT", languageSelector, "BOTTOMLEFT", -4, -4)
    languageMenu:SetFrameStrata("TOOLTIP")
    languageMenu:SetFrameLevel(frame:GetFrameLevel() + 30)
    SetBackdrop(languageMenu, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 12, 4)
    languageMenu:SetBackdropColor(0.055, 0.05, 0.043, 0.99)
    languageMenu:SetBackdropBorderColor(0.57, 0.43, 0.20, 1)
    languageMenu:Hide()

    for i, info in ipairs(LANGUAGE_CHOICES) do
        local option = CreateFrame("Button", nil, languageMenu)
        option:SetPoint("TOPLEFT", 6, -5 - ((i - 1) * 22))
        option:SetPoint("TOPRIGHT", -6, -5 - ((i - 1) * 22))
        option:SetHeight(21)
        option:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        local optionText = option:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
        optionText:SetPoint("LEFT", 10, 0)
        optionText:SetText(info.label)
        optionText:SetTextColor(0.95, 0.83, 0.53)

        option:SetScript("OnClick", function()
            PlayJournalOptionSound()
            languageMenu:Hide()
            ApplySelectedLanguage(info.code)
        end)
    end

    local function ToggleLanguageMenu()
        PlayJournalOptionSound()
        languageMenu:SetShown(not languageMenu:IsShown())
    end

    languageSelector:SetScript("OnClick", ToggleLanguageMenu)
    UpdateLanguageControl()

    CreateGlobalSearchUI()

    ApplyLocaleFontTree(frame)

    -- padfocus (2.0.12, kaanu): named: the game's gamepad B close looks for a button named *CloseButton.
    local close = CreateFrame("Button", "ForeverDungeonJournalFrameCloseButton", frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    frame.closeButton = close

    frame.backButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    FDJ.OwnFonts(frame.backButton) -- ownfonts (2.0.8)
    frame.backButton:SetSize(120, 24)
    frame.backButton:SetPoint("TOPLEFT", 54, -54)
    -- dungeonarrows: < and > either side of it, to the previous / next
    -- dungeon (children of the button: shown and hidden with it).
    for _, spec in ipairs({ { -1, "Prev", "RIGHT", "LEFT", -1 }, { 1, "Next", "LEFT", "RIGHT", 1 } }) do
        local arrow = CreateFrame("Button", nil, frame.backButton)
        arrow:SetSize(28, 28)
        arrow:SetPoint(spec[3], frame.backButton, spec[4], spec[5], 0)
        arrow:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. spec[2] .. "Page-Up")
        arrow:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. spec[2] .. "Page-Down")
        arrow:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. spec[2] .. "Page-Disabled")
        arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        arrow.step = spec[1]
        arrow:SetScript("OnClick", function(self) FDJ.StepDungeon(self.step) end)
        frame[spec[1] < 0 and "prevDungeonButton" or "nextDungeonButton"] = arrow
    end
    frame.backButton:SetText(L("DUNGEONS"))
    frame.backButton.text = frame.backButton.GetFontString and frame.backButton:GetFontString() or nil
    if frame.backButton.text then
        frame.backButton.text:SetTextColor(1.00, 0.82, 0.27)
    end
    frame.backButton:SetScript("OnClick", function()
        ShowHomePage()
    end)
    frame.backButton:Hide()

    frame.sourceLabel = nil

    local home = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.homePanel = home
    home:SetPoint("TOPLEFT", 18, -52)
    home:SetPoint("BOTTOMRIGHT", -18, 18)
    SetBackdrop(
        home,
        "Interface\\Buttons\\WHITE8X8",
        "Interface\\Tooltips\\UI-Tooltip-Border",
        14,
        4
    )
    home:SetBackdropColor(0.16, 0.12, 0.07, 0.96)
    home:SetBackdropBorderColor(0.47, 0.34, 0.16, 1)
    frame.homeParchment = AddClassicParchment(home, 0.18, 1.00, 0.95, 0.84)

    local homeTitle = home:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalHuge")
    frame.homeTitle = homeTitle
    homeTitle:SetPoint("TOPLEFT", 18, -16)
    homeTitle:SetText(L("BROWSE_DUNGEONS"))
    homeTitle:SetTextColor(1.00, 0.78, 0.20)

    local homeSubtitle = home:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    frame.homeSubtitle = homeSubtitle
    homeSubtitle:SetPoint("TOPLEFT", homeTitle, "BOTTOMLEFT", 1, -5)
    homeSubtitle:SetText(L("HOME_SUBTITLE"))
    homeSubtitle:SetTextColor(0.72, 0.67, 0.58)

    local hideDungeonsButton = CreateFrame("Button", nil, home, "BackdropTemplate")
    frame.hideDungeonsButton = hideDungeonsButton
    hideDungeonsButton:SetSize(142, 28)
    hideDungeonsButton:SetPoint("TOP", frame.languageSelectorButton, "BOTTOM", 0, -26)
    SetBackdrop(hideDungeonsButton, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 12, 4)
    hideDungeonsButton:SetBackdropColor(0.12, 0.115, 0.105, 0.98)
    hideDungeonsButton:SetBackdropBorderColor(0.48, 0.40, 0.27, 1)
    hideDungeonsButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    local hideDungeonsButtonText = hideDungeonsButton:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    frame.hideDungeonsButtonText = hideDungeonsButtonText
    hideDungeonsButtonText:SetPoint("CENTER", 0, 0)
    hideDungeonsButtonText:SetTextColor(1.00, 0.82, 0.27)
    hideDungeonsButtonText:SetText(L("HIDE_DUNGEONS"))

    local hideDungeonsDoneCheck = hideDungeonsButton:CreateTexture(nil, "OVERLAY")
    frame.hideDungeonsDoneCheck = hideDungeonsDoneCheck
    hideDungeonsDoneCheck:SetSize(16, 16)
    hideDungeonsDoneCheck:SetPoint("RIGHT", hideDungeonsButton, "RIGHT", -8, 0)
    hideDungeonsDoneCheck:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    hideDungeonsDoneCheck:SetTexCoord(0, 1, 0, 1)
    hideDungeonsDoneCheck:Hide()

    hideDungeonsButton:SetScript("OnClick", function()
        PlayJournalOptionSound()
        homeEditMode = not homeEditMode
        -- Keep the action button in the normal dark/gold journal style in both
        -- modes. Edit mode is communicated by the dungeon-card treatment; the
        -- Done state gets a small green confirmation check instead of a blue button.
        hideDungeonsButton:SetBackdropColor(0.12, 0.115, 0.105, 0.98)
        hideDungeonsButton:SetBackdropBorderColor(0.48, 0.40, 0.27, 1)
        hideDungeonsButtonText:SetTextColor(1.00, 0.82, 0.27)
        hideDungeonsButtonText:SetText(homeEditMode and L("DONE") or L("HIDE_DUNGEONS"))
        hideDungeonsButtonText:ClearAllPoints()
        hideDungeonsButtonText:SetPoint("CENTER", homeEditMode and -8 or 0, 0)
        if hideDungeonsDoneCheck then
            hideDungeonsDoneCheck:SetShown(homeEditMode)
        end
        local extra = homeEditMode and 44 or 26
        local width = math.max(126, math.min(180, math.ceil((hideDungeonsButtonText:GetStringWidth() or 100) + extra)))
        hideDungeonsButton:SetWidth(width)
        RefreshHomeDungeonCards()
    end)

    FDJ.OpenBossPage = function(dungeonName, bossIndex)
        if not DB[dungeonName] then return end
        SelectDungeon(dungeonName, { mode = "bosses", boss = bossIndex }) -- searchonce (2.1.3): built once
    end
    -- Quest tracker: the ? of a quest handed in inside a dungeon opens that
    -- dungeon's map on the NPC's level, with a yellow ? on the NPC (start:
    -- the ! of a quest picked up there, a yellow ! on the giver).
    FDJ.ShowTurnInOnDungeonMap = function(dungeonName, spot, questTitle, questID, start)
        local mapData = FDJ.DUNGEON_MAPS[dungeonName]
        if not DB[dungeonName] or not mapData or type(spot) ~= "table" then return end
        -- rpgpartial: the map still locked: the quest's page instead.
        if FDJ.IsDungeonMapLocked and FDJ.IsDungeonMapLocked(dungeonName) then
            if FDJ.RPGMapLockedNotice then FDJ.RPGMapLockedNotice(dungeonName) end
            if questID and FDJ.OpenQuestPage then FDJ.OpenQuestPage(dungeonName, questID) end
            return
        end
        local floor = spot.floor or 1
        FDJ.dungeonTurnIns = FDJ.dungeonTurnIns or {}
        FDJ.dungeonTurnIns[mapData] = { floor = floor, x = spot.x, y = spot.y, npc = spot.npc, title = questTitle, questID = questID, start = start and true or nil }
        FDJ.FocusDungeonMapQuest(questID, floor, spot.x, spot.y) -- mapfocus
        SelectDungeon(dungeonName)
        if selectedDungeon ~= dungeonName then return end
        ShowDungeonMap()
        if frame.dungeonMapFloor ~= floor then
            FDJ.ResetDungeonMapView()
            FDJ.RenderCustomDungeonMap(mapData, floor)
        end
        FDJ.ApplyDungeonMapFocus() -- mapfocus
    end
    -- mapquests: a quest item lying on one of the map's quest spots (the
    -- item's click on the quest page): that dungeon map, on its level.
    FDJ.ShowQuestSpotOnDungeonMap = function(spot)
        local name = type(spot) == "table" and spot.dungeon or nil
        local mapData = name and FDJ.DUNGEON_MAPS[name]
        if not name or not DB[name] or not mapData then return end
        if FDJ.IsDungeonMapLocked and FDJ.IsDungeonMapLocked(name) then
            if FDJ.RPGMapLockedNotice then FDJ.RPGMapLockedNotice(name) end
            return
        end
        FDJ.FocusDungeonMapQuest(spot.questID, spot.floor or 1, spot.x, spot.y) -- mapfocus
        SelectDungeon(name)
        if selectedDungeon ~= name then return end
        ShowDungeonMap()
        local floor = spot.floor or 1
        if frame.dungeonMapFloor ~= floor then
            FDJ.ResetDungeonMapView()
            FDJ.RenderCustomDungeonMap(mapData, floor)
        end
        FDJ.ApplyDungeonMapFocus() -- mapfocus
    end
    FDJ.OpenQuestPage = function(dungeonName, questID)
        if not DB[dungeonName] then return end
        SelectDungeon(dungeonName, { mode = "quests" }) -- searchonce (2.1.3)
        if selectedDungeon ~= dungeonName then return end
        if SelectQuestByID then SelectQuestByID(questID) end
    end
    -- rpgpartial: the "Dungeon Map Unlocked" popup opens the map.
    FDJ.OpenDungeonMap = function(dungeonName)
        if not DB[dungeonName] then return end
        SelectDungeon(dungeonName)
        if selectedDungeon == dungeonName and ShowDungeonMap then ShowDungeonMap() end
    end
    -- questtracker: a chain step clicked in the quest tracker opens that
    -- step's page, with the quest's chain unfolded in the list (what Show
    -- Quest Chain does, for the given step).
    FDJ.OpenQuestChainStep = function(dungeonName, questID, stepID)
        if not DB[dungeonName] then return end
        SelectDungeon(dungeonName, { mode = "quests" }) -- searchonce (2.1.3)
        if selectedDungeon ~= dungeonName then return end
        if SelectQuestByID then SelectQuestByID(questID) end
        local chain = questID and QUEST_PREREQ_CHAINS[questID]
        if type(chain) ~= "table" then return end
        local target
        for _, step in ipairs(chain) do
            if step.id and step.id == stepID then target = step break end
        end
        if not target then return end
        local parentName
        for _, quest in ipairs(DB[dungeonName].quests or {}) do
            if quest.id == questID then parentName = quest.name break end
        end
        expandedQuestChains[questID] = true
        selectedPrereqStep = target
        selectedPrereqParentQuestName = parentName
        selectedPrereqParentQuestID = questID
        if target.id then RequestQuestRewardData(target.id) end
        RefreshQuestList()
        RefreshQuestDetail()
    end
    -- sleepingbag: a quest with its chain unfolded in the list; with a
    -- step, that step's page.
    FDJ.OpenQuestChain = function(dungeonName, questID, stepID)
        if stepID then return FDJ.OpenQuestChainStep(dungeonName, questID, stepID) end
        FDJ.OpenQuestPage(dungeonName, questID)
        if selectedDungeon ~= dungeonName or not QUEST_PREREQ_CHAINS[questID] then return end
        expandedQuestChains[questID] = true
        RefreshQuestList()
    end
    FDJ.RefreshLootNow = function()
        if selectedDungeon and DB[selectedDungeon] and frame.lootContent then pcall(RefreshLoot) end
    end
    if FDJ.CreateLootFilterButton then FDJ.CreateLootFilterButton(frame, home, hideDungeonsButton) end
    if FDJ.CreateBugReportButton then FDJ.CreateBugReportButton(frame, frame, frame.languageSelectorButton) end
    -- optionscog (2.0.46): the options cogwheel left of Report
    if FDJ.CreateOptionsCogButton then FDJ.CreateOptionsCogButton(frame, frame, frame.bugReportButton) end

    local homeEmptyText = home:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightLarge")
    frame.homeEmptyText = homeEmptyText
    homeEmptyText:SetPoint("CENTER", home, "CENTER", 0, -15)
    homeEmptyText:SetWidth(560)
    homeEmptyText:SetJustifyH("CENTER")
    homeEmptyText:SetTextColor(0.75, 0.72, 0.66)
    homeEmptyText:Hide()
    -- levelempty (2.0.9, M 16 Nov 2026: "I don't want anybody to have trouble
    -- finding dungeons"): under the message when only "Show only my level
    -- range" empties the list: opens Options on that option, its row pulsing,
    -- for the player to untick it.
    frame.homeShowAllButton = CreateFrame("Button", nil, home, "BackdropTemplate")
    frame.homeShowAllButton:SetHeight(28)
    frame.homeShowAllButton:SetPoint("TOP", homeEmptyText, "BOTTOM", 0, -18)
    SetBackdrop(frame.homeShowAllButton, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 12, 4)
    frame.homeShowAllButton:SetBackdropColor(0.12, 0.115, 0.105, 0.98)
    frame.homeShowAllButton:SetBackdropBorderColor(0.48, 0.40, 0.27, 1)
    frame.homeShowAllButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    frame.homeShowAllButton.text = frame.homeShowAllButton:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    frame.homeShowAllButton.text:SetPoint("CENTER", 0, 0)
    frame.homeShowAllButton.text:SetTextColor(1.00, 0.82, 0.27)
    frame.homeShowAllButton:SetScript("OnClick", function()
        PlayJournalOptionSound()
        if FDJ.OpenSettingsAt then FDJ.OpenSettingsAt("OPT_MY_LEVEL_RANGE") end
    end)
    frame.homeShowAllButton:Hide()

    local homeLine = home:CreateTexture(nil, "ARTWORK")
    frame.homeLine = homeLine
    homeLine:SetTexture("Interface\\Buttons\\WHITE8X8")
    homeLine:SetPoint("TOPLEFT", 18, -58)
    homeLine:SetPoint("TOPRIGHT", -31, -58)
    homeLine:SetHeight(1)
    homeLine:SetColorTexture(0.48, 0.34, 0.16, 0.75)

    frame.homeScroll = CreateFrame(
        "ScrollFrame",
        "ForeverDungeonJournalHomeScroll",
        home,
        "UIPanelScrollFrameTemplate"
    )
    frame.homeScroll:SetPoint("TOPLEFT", 18, -72)
    frame.homeScroll:SetPoint("BOTTOMRIGHT", -31, 15)

    frame.homeCardsContent = CreateFrame("Frame", nil, frame.homeScroll)
    frame.homeCardsContent:SetSize(747, 1)
    frame.homeScroll:SetScrollChild(frame.homeCardsContent)

    local content = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.contentPanel = content
    content:SetPoint("TOPLEFT", 18, -90)
    content:SetPoint("BOTTOMRIGHT", -18, 18)

    SetBackdrop(
        content,
        "Interface\\Buttons\\WHITE8X8",
        "Interface\\Tooltips\\UI-Tooltip-Border",
        14,
        4
    )
    content:SetBackdropColor(0.17, 0.12, 0.07, 0.96)
    content:SetBackdropBorderColor(0.47, 0.34, 0.16, 1)
    frame.contentParchment = AddClassicParchment(content, 0.18, 1.00, 0.95, 0.84)

    frame.dungeonBackgroundArt = content:CreateTexture(nil, "BACKGROUND", nil, -4)
    frame.dungeonBackgroundArt:SetAllPoints(content)
    frame.dungeonBackgroundArt:SetTexture(
        "Interface\\AddOns\\ForeverDungeonJournal\\Media\\HallOfThanes.tga"
    )
    frame.dungeonBackgroundArt:SetTexCoord(0, 1, 0, 1)
    frame.dungeonBackgroundArt:SetAlpha(0)

    -- Dungeon-specific atmosphere overlays. These are abstract color/fog
    -- layers, not copies of either loading screen.
    frame.atmosphere = content:CreateTexture(nil, "BACKGROUND", nil, -7)
    frame.atmosphere:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.atmosphere:SetAllPoints(content)
    frame.atmosphere:SetColorTexture(0.08, 0.22, 0.19, 0)

    frame.mistTop = content:CreateTexture(nil, "BACKGROUND", nil, -6)
    frame.mistTop:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.mistTop:SetPoint("TOPLEFT", 4, -4)
    frame.mistTop:SetPoint("TOPRIGHT", -4, -4)
    frame.mistTop:SetHeight(95)
    frame.mistTop:SetColorTexture(0.18, 0.42, 0.36, 0.14)

    -- Header
    local header = CreateFrame("Frame", nil, content, "BackdropTemplate")
    frame.headerPanel = header
    header:SetPoint("TOPLEFT", 14, -12)
    header:SetPoint("TOPRIGHT", -14, -12)
    header:SetHeight(62)

    SetBackdrop(
        header,
        "Interface\\Buttons\\WHITE8X8",
        "Interface\\Tooltips\\UI-Tooltip-Border",
        10,
        2
    )
    header:SetBackdropColor(0.24, 0.17, 0.09, 0.94)
    header:SetBackdropBorderColor(0.52, 0.33, 0.11, 1)
    frame.headerParchment = AddClassicParchment(header, 0.16, 1.00, 0.94, 0.82)

    frame.dungeonTitle = header:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalHuge")
    frame.dungeonTitle:SetPoint("TOPLEFT", 15, -10)
    frame.dungeonTitle:SetTextColor(1, 0.82, 0.27)

    frame.dungeonLocationButton = CreateFrame("Button", nil, header)
    frame.dungeonLocationButton:SetSize(38, 38)
    frame.dungeonLocationButton:SetPoint("LEFT", frame.dungeonTitle, "RIGHT", 5, 1)
    frame.dungeonLocationButton:SetFrameLevel(header:GetFrameLevel() + 4)
    frame.dungeonLocationButton.icon = frame.dungeonLocationButton:CreateTexture(nil, "ARTWORK")
    frame.dungeonLocationButton.icon:SetPoint("CENTER")
    frame.dungeonLocationButton.icon:SetSize(36, 36)
    local dungeonAtlasOK = false
    if frame.dungeonLocationButton.icon.SetAtlas then
        dungeonAtlasOK = pcall(frame.dungeonLocationButton.icon.SetAtlas, frame.dungeonLocationButton.icon, "Dungeon", false)
    end
    if not dungeonAtlasOK then
        frame.dungeonLocationButton.icon:SetTexture("Interface\\Icons\\INV_Misc_Rune_01")
        frame.dungeonLocationButton.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    frame.dungeonLocationButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    frame.dungeonLocationButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L("SHOW_LOCATION"))
        GameTooltip:Show()
    end)
    frame.dungeonLocationButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.dungeonLocationButton:SetScript("OnClick", function()
        local dungeon = DB[selectedDungeon]
        local entrance = dungeon and dungeon.entrance
        if entrance and FDJ.MapMarkers and FDJ.MapMarkers.ShowRecordedLocationOnMap then
            FDJ.MapMarkers.ShowRecordedLocationOnMap(entrance, DungeonName(selectedDungeon))
        end
    end)
    if FDJ.CreateLFGButton then FDJ.CreateLFGButton(frame, header, frame.dungeonLocationButton) end

    frame.dungeonRouteButton = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    FDJ.OwnFonts(frame.dungeonRouteButton) -- ownfonts (2.0.8)
    frame.dungeonRouteButton:SetSize(96, 30)
    frame.dungeonRouteButton:SetPoint("LEFT", frame.lfgButton or frame.dungeonLocationButton, "RIGHT", 3, 0)
    frame.dungeonRouteButton:SetText(L("ROUTE"))
    frame.dungeonRouteButton.text = frame.dungeonRouteButton:GetFontString()
    if frame.dungeonRouteButton.text then
        frame.dungeonRouteButton.text:ClearAllPoints()
        frame.dungeonRouteButton.text:SetPoint("CENTER", 10, 0)
        frame.dungeonRouteButton.text:SetTextColor(1.00, 0.82, 0.27)
    end
    frame.dungeonRouteButton.icon = frame.dungeonRouteButton:CreateTexture(nil, "OVERLAY")
    frame.dungeonRouteButton.icon:SetSize(23, 23)
    frame.dungeonRouteButton.icon:SetPoint("LEFT", 5, 0)
    frame.dungeonRouteButton.icon:SetTexture(ALLIANCE_ICON)
    frame.dungeonRouteButton:SetScript("OnClick", ShowRouteGuide)
    frame.dungeonRouteButton:Hide()

    frame.dungeonMeta = header:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    frame.dungeonMeta:SetPoint("TOPLEFT", frame.dungeonTitle, "BOTTOMLEFT", 0, -4)
    frame.dungeonMeta:SetTextColor(0.88, 0.80, 0.66)

    -- Stockade loot data is still being verified. Keep this notice in the
    -- dungeon header so it clearly applies to both the Bosses and Quests tabs.
    frame.stockadeItemsTBD = header:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalLarge")
    frame.stockadeItemsTBD:SetText("Items Data TBD")
    frame.stockadeItemsTBD:SetTextColor(1.00, 0.10, 0.10)
    frame.stockadeItemsTBD:SetShadowColor(0, 0, 0, 1)
    frame.stockadeItemsTBD:SetShadowOffset(1, -1)
    frame.stockadeItemsTBD:Hide()
    -- "Full Quests TBD": on the Quests tab of a new dungeon whose quests are
    -- still being found (FDJ.UpdateQuestsTBD).
    frame.questsTBD = header:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    frame.questsTBD:SetText("Full Quests TBD")
    frame.questsTBD:SetTextColor(1.00, 0.10, 0.10)
    frame.questsTBD:SetShadowColor(0, 0, 0, 1)
    frame.questsTBD:SetShadowOffset(1, -1)
    frame.questsTBD:Hide()

    -- Sub-tabs live inside the dungeon header, to the right of the dungeon name.
    frame.questsTab = CreateModeButton(header, L("QUESTS"), -13)
    frame.bossesTab = CreateModeButton(header, L("BOSSES"), -127)
    frame.mapTab = CreateModeButton(header, L("MAP"), -241)
    frame.mapTab:Hide()
    -- Keep the Stockade "Items Data TBD" note left of the Map button so it
    -- never overlaps the header buttons.
    frame.stockadeItemsTBD:SetPoint("RIGHT", frame.bossesTab, "LEFT", -12, 0)
    frame.stockadeItemsTBD:SetFontObject("ForeverDJ_GameFontNormal")
    frame.stockadeItemsTBD:SetTextColor(1.00, 0.10, 0.10)
    -- On a chain page of a dungeon (parentDungeon), Bosses and Map open that
    -- dungeon: the Mallet of Zul'Farrak -> Zul'Farrak, at Gahz'rilla.
    FDJ.OpenParentDungeon = function(toMap)
        local page = DB[selectedDungeon]
        local parent = page and page.questChainPage and page.parentDungeon
        if not parent or not DB[parent] then return false end
        SelectDungeon(parent)
        if selectedDungeon ~= parent then return true end -- RPG Mode: still locked
        if toMap then
            if ShowDungeonMap then ShowDungeonMap() end
        else
            SetMode("bosses")
            for i, boss in ipairs(DB[parent].bosses or {}) do
                if page.parentBoss and boss.name == page.parentBoss then
                    SelectBoss(i)
                    break
                end
            end
        end
        return true
    end
    frame.bossesTab:SetScript("OnClick", function()
        if FDJ.OpenParentDungeon(false) then return end
        SetMode("bosses")
    end)
    frame.questsTab:SetScript("OnClick", function() SetMode("quests") end)
    frame.mapTab:SetScript("OnClick", function()
        if FDJ.OpenParentDungeon(true) then return end
        if ShowDungeonMap then ShowDungeonMap() end
    end)

    -- LEFT: boss list remains visible at all times.
    local left = CreateFrame("Frame", nil, content, "BackdropTemplate")
    frame.leftPanel = left
    left:SetPoint("TOPLEFT", 14, -84)
    left:SetPoint("BOTTOMLEFT", 14, 14)
    left:SetWidth(344)

    SetBackdrop(
        left,
        "Interface\\Buttons\\WHITE8X8",
        "Interface\\Tooltips\\UI-Tooltip-Border",
        12,
        3
    )
    left:SetBackdropColor(0.19, 0.13, 0.07, 0.94)
    left:SetBackdropBorderColor(0.39, 0.24, 0.08, 1)
    frame.leftParchment = AddClassicParchment(left, 0.13, 1.00, 0.94, 0.82)

    local encounters = left:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalLarge")
    frame.bossListTitle = encounters
    encounters:SetPoint("TOPLEFT", 12, -10)
    encounters:SetText(L("BOSSES"))
    encounters:SetTextColor(0.25, 0.12, 0.035)

    local bossScroll = CreateFrame(
        "ScrollFrame",
        "ForeverDungeonJournalBossListScroll",
        left,
        "UIPanelScrollFrameTemplate"
    )
    frame.bossListScroll = bossScroll
    bossScroll:SetPoint("TOPLEFT", 10, -40)
    bossScroll:SetPoint("BOTTOMRIGHT", -28, 10)

    frame.bossContent = CreateFrame("Frame", nil, bossScroll)
    frame.bossContent:SetSize(315, 1)
    bossScroll:SetScrollChild(frame.bossContent)

    -- RIGHT: selected boss + loot, while the full boss list stays visible.
    local right = CreateFrame("Frame", nil, content, "BackdropTemplate")
    frame.rightPanel = right
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 12, 0)
    right:SetPoint("BOTTOMRIGHT", -14, 14)

    SetBackdrop(
        right,
        "Interface\\Buttons\\WHITE8X8",
        "Interface\\Tooltips\\UI-Tooltip-Border",
        12,
        3
    )
    right:SetBackdropColor(0.21, 0.15, 0.08, 0.94)
    right:SetBackdropBorderColor(0.42, 0.27, 0.10, 1)
    frame.rightParchment = AddClassicParchment(right, 0.13, 1.00, 0.94, 0.82)

    frame.selectedBossPortrait = right:CreateTexture(nil, "ARTWORK")
    frame.selectedBossPortrait:SetSize(68, 68)
    frame.selectedBossPortrait:SetPoint("TOPLEFT", 16, -16)
    frame.selectedBossPortrait:SetTexCoord(0.04, 0.96, 0.04, 0.96)

    frame.selectedBossRareBorder = right:CreateTexture(nil, "OVERLAY")
    frame.selectedBossRareBorder:SetSize(98, 98)
    frame.selectedBossRareBorder:SetPoint("CENTER", frame.selectedBossPortrait, "CENTER", 0, 0)
    frame.selectedBossRareBorder:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\RarePortraitDragonFrame.tga")
    frame.selectedBossRareBorder:SetTexCoord(0, 1, 0, 1)
    frame.selectedBossRareBorder:Hide()

    frame.selectedBossQuestion = right:CreateFontString(
        nil,
        "OVERLAY",
        "ForeverDJ_GameFontNormalHuge"
    )
    frame.selectedBossQuestion:SetPoint(
        "CENTER",
        frame.selectedBossPortrait,
        "CENTER",
        0,
        0
    )
    frame.selectedBossQuestion:SetText("?")
    frame.selectedBossQuestion:SetTextColor(0.48, 0.25, 0.05)
    frame.selectedBossQuestion:Hide()

    frame.selectedBossLevelBadge = right:CreateTexture(nil, "OVERLAY", nil, 6)
    frame.selectedBossLevelBadge:SetSize(36, 36)
    frame.selectedBossLevelBadge:SetPoint("CENTER", frame.selectedBossPortrait, "BOTTOMLEFT", 8, 3)
    frame.selectedBossLevelBadge:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\BossLevelBadge.tga")
    frame.selectedBossLevelBadge:Hide()

    frame.selectedBossLevelText = right:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    frame.selectedBossLevelText:SetPoint("CENTER", frame.selectedBossLevelBadge, "CENTER", 0, 0)
    frame.selectedBossLevelText:SetTextColor(1, 1, 1)
    frame.selectedBossLevelText:SetShadowColor(0, 0, 0, 1)
    frame.selectedBossLevelText:SetShadowOffset(1, -1)
    frame.selectedBossLevelText:Hide()


    frame.selectedBossName = right:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalLarge")
    frame.selectedBossName:SetPoint(
        "LEFT",
        frame.selectedBossPortrait,
        "RIGHT",
        16,
        7
    )
    frame.selectedBossName:SetPoint("RIGHT", -14, 0)
    frame.selectedBossName:SetJustifyH("LEFT")
    frame.selectedBossName:SetTextColor(0.29, 0.13, 0.035)

    frame.selectedBossType = right:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    frame.selectedBossType:SetPoint(
        "TOPLEFT",
        frame.selectedBossName,
        "BOTTOMLEFT",
        0,
        -4
    )
    frame.selectedBossType:Hide()

    frame.selectedBossDescription = right:CreateFontString(
        nil,
        "OVERLAY",
        "ForeverDJ_GameFontHighlightSmall"
    )
    frame.selectedBossDescription:SetPoint(
        "TOPLEFT",
        frame.selectedBossType,
        "BOTTOMLEFT",
        0,
        -7
    )
    frame.selectedBossDescription:SetPoint("RIGHT", -12, 0)
    frame.selectedBossDescription:SetHeight(35)
    frame.selectedBossDescription:SetJustifyH("LEFT")
    frame.selectedBossDescription:SetJustifyV("TOP")
    frame.selectedBossDescription:SetWordWrap(true)
    frame.selectedBossDescription:SetTextColor(0.22, 0.13, 0.06)
    frame.selectedBossDescription:Hide()

    frame.lootTitle = right:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    frame.lootTitle:SetPoint("TOPLEFT", 14, -102)
    frame.lootTitle:SetTextColor(0.27, 0.13, 0.04)
    frame.lootTitle:Hide()

    -- Repeat the Stockade warning directly above the boss loot list so players
    -- do not mistake the currently incomplete beta item data for final loot.
    frame.stockadeLootTBD = right:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalLarge")
    frame.stockadeLootTBD:SetPoint("TOP", right, "TOP", 0, -91)
    frame.stockadeLootTBD:SetText("Items Data TBD")
    frame.stockadeLootTBD:SetTextColor(1.00, 0.10, 0.10)
    frame.stockadeLootTBD:SetShadowColor(0, 0, 0, 1)
    frame.stockadeLootTBD:SetShadowOffset(1, -1)
    frame.stockadeLootTBD:Hide()

    local lootScroll = CreateFrame(
        "ScrollFrame",
        "ForeverDungeonJournalLootScroll",
        right,
        "UIPanelScrollFrameTemplate"
    )
    frame.lootScroll = lootScroll
    lootScroll:SetPoint("TOPLEFT", 12, -102)
    lootScroll:SetPoint("BOTTOMRIGHT", -29, 11)

    frame.lootContent = CreateFrame("Frame", nil, lootScroll)
    frame.lootContent:SetSize(388, 1)
    lootScroll:SetScrollChild(frame.lootContent)
    -- Resizing the window can change how many loot columns fit. React to
    -- width changes only (the item-count title changes the height).
    lootScroll:HookScript("OnSizeChanged", function(self, width)
        width = math.floor(width or 0)
        if width == self.fdjLastWidth then return end
        if FDJ.journalSizing then return end -- resizeframe: laid out on release
        self.fdjLastWidth = width
        if frame:IsShown() and FDJ.RefreshLootNow then FDJ.RefreshLootNow() end
    end)

    -- QUEST MODE: mirrors the fast boss workflow. All quests remain visible on
    -- the left; clicking one updates the details on the right with no extra page.
    local questLeft = CreateFrame("Frame", nil, content, "BackdropTemplate")
    frame.questLeftPanel = questLeft
    questLeft:SetPoint("TOPLEFT", 14, -84)
    questLeft:SetPoint("BOTTOMLEFT", 14, 14)
    questLeft:SetWidth(344)
    SetBackdrop(
        questLeft,
        "Interface\\Buttons\\WHITE8X8",
        "Interface\\Tooltips\\UI-Tooltip-Border",
        12,
        3
    )
    frame.questLeftParchment = AddClassicParchment(questLeft, 0.13, 1.00, 0.94, 0.82)

    frame.questListTitle = questLeft:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalLarge")
    frame.questListTitle:SetPoint("TOPLEFT", 12, -10)
    frame.questListTitle:SetText(L("QUESTS"))

    local function CreateFactionButton(faction, x, texturePath)
        local b = CreateFrame("Button", nil, questLeft, "BackdropTemplate")
        b:SetSize(50, 38)
        b:SetPoint("TOPRIGHT", x, -7)
        SetBackdrop(
            b,
            "Interface\\Buttons\\WHITE8X8",
            "Interface\\Tooltips\\UI-Tooltip-Border",
            8,
            2
        )

        b.faction = faction
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(31, 31)
        b.icon:SetPoint("CENTER")
        b.icon:SetTexture(texturePath)
        b.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)

        b:SetScript("OnClick", function()
            SetQuestFaction(faction)
        end)

        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L("FACTION_QUESTS", faction))
            if self.fdjLocked then GameTooltip:AddLine(L("FACTION_LOCKED_TIP"), 1, 1, 1, true) end -- questrowtrial
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        return b
    end

    frame.hordeQuestButton = CreateFactionButton("Horde", -10, HORDE_ICON)
    frame.allianceQuestButton = CreateFactionButton("Alliance", -66, ALLIANCE_ICON)
    if FDJ.CreateQuestTrackButton then FDJ.CreateQuestTrackButton(frame, questLeft) end -- questtracker
    if FDJ.CreateQuestPostButton then FDJ.CreateQuestPostButton(frame, questLeft) end -- postquests (2.1.3)

    local questScroll = CreateFrame(
        "ScrollFrame",
        "ForeverDungeonJournalQuestListScroll",
        questLeft,
        "UIPanelScrollFrameTemplate"
    )
    frame.questListScroll = questScroll
    questScroll:SetPoint("TOPLEFT", 10, -56)
    questScroll:SetPoint("BOTTOMRIGHT", -28, 10)

    frame.questContent = CreateFrame("Frame", nil, questScroll)
    frame.questContent:SetSize(296, 1)
    questScroll:SetScrollChild(frame.questContent)

    local questRight = CreateFrame("Frame", nil, content, "BackdropTemplate")
    frame.questRightPanel = questRight
    questRight:SetPoint("TOPLEFT", questLeft, "TOPRIGHT", 12, 0)
    questRight:SetPoint("BOTTOMRIGHT", -14, 14)
    SetBackdrop(
        questRight,
        "Interface\\Buttons\\WHITE8X8",
        "Interface\\Tooltips\\UI-Tooltip-Border",
        12,
        3
    )
    frame.questRightParchment = AddClassicParchment(questRight, 0.10, 1.00, 0.94, 0.82)

    local questInset = CreateFrame("Frame", nil, questRight, "BackdropTemplate")
    frame.questTextInset = questInset
    questInset:SetPoint("TOPLEFT", 8, -8)
    questInset:SetPoint("BOTTOMRIGHT", -14, 8)
    SetBackdrop(
        questInset,
        "Interface\\Buttons\\WHITE8X8",
        "Interface\\Tooltips\\UI-Tooltip-Border",
        10,
        3
    )
    questInset:SetBackdropColor(0.70, 0.58, 0.39, 1)
    questInset:SetBackdropBorderColor(0.36, 0.23, 0.09, 1)

    frame.questParchment = questInset:CreateTexture(nil, "BACKGROUND", nil, -3)
    frame.questParchment:SetPoint("TOPLEFT", 4, -4)
    frame.questParchment:SetPoint("BOTTOMRIGHT", -4, 4)
    frame.questParchment:SetTexture("Interface\\QuestFrame\\QuestBG")
    frame.questParchment:SetTexCoord(0, 1, 0, 1)
    frame.questParchment:SetVertexColor(1.00, 0.96, 0.84, 1.00)

    -- Explicit edge lines guarantee the quest-detail rectangle is closed on
    -- all four sides, even if this beta clips a Backdrop edge.
    frame.questInsetEdges = {}
    local function MakeQuestInsetEdge()
        local edge = questInset:CreateTexture(nil, "OVERLAY", nil, 7)
        edge:SetTexture("Interface\\Buttons\\WHITE8X8")
        edge:SetColorTexture(0.42, 0.29, 0.13, 0.95)
        table.insert(frame.questInsetEdges, edge)
        return edge
    end

    local topEdge = MakeQuestInsetEdge()
    topEdge:SetPoint("TOPLEFT", 3, -3)
    topEdge:SetPoint("TOPRIGHT", -3, -3)
    topEdge:SetHeight(3)

    local bottomEdge = MakeQuestInsetEdge()
    bottomEdge:SetPoint("BOTTOMLEFT", 3, 3)
    bottomEdge:SetPoint("BOTTOMRIGHT", -3, 3)
    bottomEdge:SetHeight(3)

    local leftEdge = MakeQuestInsetEdge()
    leftEdge:SetPoint("TOPLEFT", 3, -3)
    leftEdge:SetPoint("BOTTOMLEFT", 3, 3)
    leftEdge:SetWidth(3)

    local rightEdge = MakeQuestInsetEdge()
    rightEdge:SetPoint("TOPRIGHT", -3, -3)
    rightEdge:SetPoint("BOTTOMRIGHT", -3, 3)
    rightEdge:SetWidth(3)

    frame.selectedQuestName = questInset:CreateFontString(nil, "OVERLAY")
    frame.selectedQuestName:SetPoint("TOPLEFT", 16, -15)
    frame.selectedQuestName:SetPoint("RIGHT", -48, 0)
    frame.selectedQuestName:SetJustifyH("LEFT")
    ApplyQuestFont(frame.selectedQuestName, "ForeverDJ_QuestTitleFont", "ForeverDJ_QuestFont")
    frame.selectedQuestName:SetTextColor(1.00, 0.78, 0.16)
    frame.selectedQuestName:SetShadowColor(0, 0, 0, 0.82)
    frame.selectedQuestName:SetShadowOffset(1, -1)

    frame.selectedQuestComplete = questInset:CreateTexture(nil, "OVERLAY")
    frame.selectedQuestComplete:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    frame.selectedQuestComplete:SetSize(24, 24)
    frame.selectedQuestComplete:SetPoint("TOPRIGHT", -16, -11)
    frame.selectedQuestComplete:Hide()
    -- Ready to hand in: the round ? (shows where) in place of the tick.
    if FDJ.CreateTurnInButton then
        frame.selectedQuestTurnIn = FDJ.CreateTurnInButton(questInset, 34)
        frame.selectedQuestTurnIn:SetPoint("CENTER", frame.selectedQuestComplete, "CENTER", 0, 0)
        frame.selectedQuestTurnIn:SetFrameLevel(questInset:GetFrameLevel() + 8)
    end

    frame.questShareButton = CreateFrame("Button", nil, questInset, "BackdropTemplate")
    frame.questShareButton:SetSize(76, 24)
    SetBackdrop(frame.questShareButton, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 12, 4)
    frame.questShareButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    frame.questShareButton.text = frame.questShareButton:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
    frame.questShareButton.text:SetPoint("CENTER", 0, 0)
    frame.questShareButton.text:SetText(L("SHARE"))
    frame.questShareButton:SetScript("OnClick", function(self)
        if self._fdjShareEnabled and self.questID then
            FDJ.ShareQuestByID(self.questID)
        end
    end)
    frame.questShareButton:SetScript("OnEnter", function(self)
        if not self._fdjShareableQuest then
            -- Keep this button mouse-enabled instead of calling :Disable();
            -- disabled WoW buttons do not reliably receive OnEnter, so the
            -- grey state is visual while the red tooltip remains available.
            self:SetBackdropColor(0.22, 0.22, 0.22, 1.00)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L("NOT_SHAREABLE"), 1.00, 0.15, 0.15)
            GameTooltip:Show()
            return
        end

        self:SetBackdropColor(0.13, 0.40, 0.19, 1.00)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L("SHAREABLE_QUEST"), 0.25, 1.00, 0.25)

        -- Chain-step restrictions describe who can receive the quest, so the
        -- note must remain visible even after the player accepts the quest.
        -- For ordinary shareable quests, only show the pickup reminder while
        -- the quest is not yet in the player's log.
        if self._fdjSameStepOnly then
            GameTooltip:AddLine(L("SHAREABLE_SAME_STEP"), 1.00, 1.00, 1.00, true)
        elseif not self._fdjShareEnabled then
            GameTooltip:AddLine(L("ACCEPT_TO_SHARE"), 1.00, 1.00, 1.00, true)
        end
        GameTooltip:Show()
    end)
    frame.questShareButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        FDJ.SetQuestShareButtonVisual(self, self._fdjShareableQuest, self._fdjShareEnabled)
    end)
    frame.questShareButton:Hide()

    frame.selectedQuestClass = questInset:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
    frame.selectedQuestClass:SetPoint("TOPRIGHT", -16, -18)
    frame.selectedQuestClass:SetWidth(118)
    frame.selectedQuestClass:SetJustifyH("RIGHT")
    frame.selectedQuestClass:SetShadowColor(0, 0, 0, 0.72)
    frame.selectedQuestClass:SetShadowOffset(1, -1)
    frame.selectedQuestClass:Hide()

    frame.selectedQuestClassIcon = questInset:CreateTexture(nil, "OVERLAY")
    frame.selectedQuestClassIcon:SetSize(27, 27)
    frame.selectedQuestClassIcon:SetPoint("TOP", frame.selectedQuestClass, "BOTTOM", 0, -3)
    frame.selectedQuestClassIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
    frame.selectedQuestClassIcon:Hide()

    frame.selectedQuestMeta = questInset:CreateFontString(nil, "OVERLAY")
    frame.selectedQuestMeta:SetPoint("TOPLEFT", frame.selectedQuestName, "BOTTOMLEFT", 0, -5)
    frame.selectedQuestMeta:SetPoint("RIGHT", -16, 0)
    frame.selectedQuestMeta:SetJustifyH("LEFT")
    ApplyQuestFont(frame.selectedQuestMeta, "ForeverDJ_QuestFontNormalSmall", "ForeverDJ_GameFontHighlightSmall")
    -- (redlevelbold: the red level drawn bold with its outline, whatever sets the line)
    if hooksecurefunc then
        hooksecurefunc(frame.selectedQuestMeta, "SetText", function(self, text)
            if FDJ.MarkRedLevel then pcall(FDJ.MarkRedLevel, self, text) end
        end)
    end

    -- Class quests also get the class icon on the metadata row, immediately
    -- after the Alliance/Horde faction icon(s). The existing class marker in
    -- the top-right remains intact.
    frame.selectedQuestMetaClassIcon = questInset:CreateTexture(nil, "OVERLAY")
    frame.selectedQuestMetaClassIcon:SetSize(24, 24)
    frame.selectedQuestMetaClassIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
    frame.selectedQuestMetaClassIcon:Hide()

    local sep = questInset:CreateTexture(nil, "ARTWORK")
    frame.questHeaderSeparator = sep
    sep:SetTexture("Interface\\Buttons\\WHITE8X8")
    sep:SetPoint("TOPLEFT", 14, -58)
    sep:SetPoint("TOPRIGHT", -14, -58)
    sep:SetHeight(1)
    sep:SetColorTexture(0.45, 0.35, 0.20, 0.55)

    frame.questDetailScroll = CreateFrame(
        "ScrollFrame",
        "ForeverDungeonJournalQuestDetailScroll",
        questInset,
        "UIPanelScrollFrameTemplate"
    )
    frame.questDetailScroll:SetPoint("TOPLEFT", 16, -72)
    frame.questDetailScroll:SetPoint("BOTTOMRIGHT", -31, 16)

    frame.questDetailContent = CreateFrame("Frame", nil, frame.questDetailScroll)
    frame.questDetailContent:SetSize(380, 1)
    frame.questDetailScroll:SetScrollChild(frame.questDetailContent)
    frame.questDetailScroll:HookScript("OnVerticalScroll", function(self, offset)
        if FDJ._restoringQuestDetailScroll then return end
        local key = FDJ._questDetailPageKey
        if not key then return end
        local contentHeight = frame.questDetailContent and (frame.questDetailContent:GetHeight() or 0) or 0
        local viewportHeight = self:GetHeight() or 0
        local maxScroll = math.max(0, contentHeight - viewportHeight)
        local requested = offset or self:GetVerticalScroll() or 0
        local clamped = math.max(0, math.min(requested, maxScroll))
        if math.abs(clamped - requested) > 0.5 then
            FDJ._restoringQuestDetailScroll = true
            self:SetVerticalScroll(clamped)
            local scrollBar = GetScrollBar(self)
            if scrollBar then
                if scrollBar.SetMinMaxValues then scrollBar:SetMinMaxValues(0, maxScroll) end
                if scrollBar.SetValue then scrollBar:SetValue(clamped) end
            end
            FDJ._restoringQuestDetailScroll = nil
        end
        FDJ._questDetailScrollByPage = FDJ._questDetailScrollByPage or {}
        FDJ._questDetailScrollByPage[key] = clamped
    end)

    frame.questDetailText = frame.questDetailContent:CreateFontString(
        nil,
        "OVERLAY"
    )
    frame.questDetailText:SetPoint("TOPLEFT", 0, 0)
    frame.questDetailText:SetWidth(365)
    frame.questDetailText:SetJustifyH("LEFT")
    frame.questDetailText:SetJustifyV("TOP")
    frame.questDetailText:SetWordWrap(true)
    ApplyQuestFont(frame.questDetailText, "ForeverDJ_QuestFont", "ForeverDJ_GameFontHighlight")

    local function MakeQuestSectionHeader(label)
        local fs = frame.questDetailContent:CreateFontString(nil, "OVERLAY")

        -- Keep the Blizzard FontObject intact. Converting QuestFont to its raw
        -- font file with GetFont()/SetFont() strips Blizzard's locale glyph
        -- fallback on non-Russian clients, which turns Cyrillic section labels
        -- such as Цель / Начинается у / Сдать into square boxes. The normal
        -- black shadow keeps the header readable on parchment without breaking
        -- Russian (and remains safe when switching languages at runtime).
        ApplyQuestFont(fs, "ForeverDJ_QuestFont", "ForeverDJ_GameFontNormal")
        fs:SetText(label)
        fs:SetTextColor(1, 1, 1)
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
        fs:SetJustifyH("LEFT")
        return fs
    end

    frame.questObjectiveHeader = MakeQuestSectionHeader(L("OBJECTIVE"))
    frame.questRequiredItemsHeader = MakeQuestSectionHeader(L("REQUIRED_ITEMS"))
    frame.questProvidedItemHeader = MakeQuestSectionHeader(L("PROVIDED_ITEM"))
    frame.questStartsHeader = MakeQuestSectionHeader(L("STARTS_AT"))
    frame.questTurninHeader = MakeQuestSectionHeader(L("TURN_IN"))
    frame.questNotesHeader = MakeQuestSectionHeader(L("NOTES"))
    frame.questRewardAlsoHeader = MakeQuestSectionHeader(L("ALSO_RECEIVE"))
    frame.questRewardAlsoHeader:Hide()
    frame.questDescHeader = MakeQuestSectionHeader(L("DESCRIPTION"))
    frame.questDescHeader:Hide()
    frame.questDescText = frame.questDetailContent:CreateFontString(nil, "OVERLAY")
    frame.questDescText:SetWidth(365)
    frame.questDescText:SetJustifyH("LEFT")
    frame.questDescText:SetJustifyV("TOP")
    frame.questDescText:SetWordWrap(true)
    ApplyQuestFont(frame.questDescText, "ForeverDJ_QuestFont", "ForeverDJ_GameFontHighlight")
    frame.questDescText:Hide()

    frame.questStartsText = frame.questDetailContent:CreateFontString(nil, "OVERLAY")
    frame.questStartsText:SetWidth(365)
    frame.questStartsText:SetJustifyH("LEFT")
    frame.questStartsText:SetJustifyV("TOP")
    frame.questStartsText:SetWordWrap(true)
    ApplyQuestFont(frame.questStartsText, "ForeverDJ_QuestFont", "ForeverDJ_GameFontHighlight")

    -- Item-start quests show the actual quest-start item instead of a map
    -- button. Hovering it gives the item tooltip plus the recorded drop source.
    frame.questStartItemButton = CreateFrame("Button", nil, frame.questDetailContent, "BackdropTemplate")
    frame.questStartItemButton:SetSize(230, 38)
    SetBackdrop(frame.questStartItemButton, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 9, 2)
    frame.questStartItemButton.icon = frame.questStartItemButton:CreateTexture(nil, "ARTWORK")
    frame.questStartItemButton.icon:SetSize(28, 28)
    frame.questStartItemButton.icon:SetPoint("LEFT", 6, 0)
    frame.questStartItemButton.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.questStartItemButton.name = frame.questStartItemButton:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
    frame.questStartItemButton.name:SetPoint("LEFT", frame.questStartItemButton.icon, "RIGHT", 8, 0)
    frame.questStartItemButton.name:SetPoint("RIGHT", -6, 0)
    frame.questStartItemButton.name:SetJustifyH("LEFT")
    frame.questStartItemButton:SetScript("OnEnter", function(self)
        if self.item then
            ShowItemTooltip(self)
        elseif self.fdjObject then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.fdjObject[1], 1, 1, 1)
            if self.fdjObject[2] and self.fdjObject[2] ~= "" then
                GameTooltip:AddLine(self.fdjObject[2], 1.00, 0.82, 0.00, true)
            end
            GameTooltip:Show()
        end
    end)
    frame.questStartItemButton:SetScript("OnLeave", function(self)
        self.fdjComparing = nil
        if not self.item and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        if itemTooltip then itemTooltip:Hide() end
        HideComparisonTooltips()
    end)
    frame.questStartItemButton:SetScript("OnClick", function(self)
        if not self.item then return end

        local _, link = ItemInfo(self.item[1])
        if link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
            ChatEdit_InsertLink(link)
            return
        end

        -- A boss drops it: open that boss's loot with the item glowing.
        if FDJ.JumpToBossDrop and FDJ.JumpToBossDrop(self.item[1]) then
            if itemTooltip then itemTooltip:Hide() end
            HideComparisonTooltips()
            return
        end
        -- Normal click keeps the tooltip open and includes the custom source
        -- line (drop NPC/location) for world/dungeon quest-start items.
        ShowItemTooltip(self)
    end)
    frame.questStartItemButton.fdjBossJump = true
    frame.questStartItemButton:Hide()

    frame.questRequiredItemButton = MakeQuestRewardButton(frame.questDetailContent)
    frame.questRequiredItemButton.fdjBossJump = true
    frame.questRequiredItemButton:SetSize(230, 46)
    frame.questRequiredItemButton:Hide()
    frame.questRequiredItemsHeader:Hide()
    frame.questProvidedItemHeader:Hide()

    frame.questStartDungeonIcon = CreateFrame("Button", nil, frame.questDetailContent)
    frame.questStartDungeonIcon:SetSize(26, 26)
    frame.questStartDungeonIcon.icon = frame.questStartDungeonIcon:CreateTexture(nil, "ARTWORK")
    frame.questStartDungeonIcon.icon:SetAllPoints()
    local questDungeonAtlasOK = false
    if frame.questStartDungeonIcon.icon.SetAtlas then
        questDungeonAtlasOK = pcall(frame.questStartDungeonIcon.icon.SetAtlas, frame.questStartDungeonIcon.icon, "Dungeon", false)
    end
    if not questDungeonAtlasOK then
        frame.questStartDungeonIcon.icon:SetTexture("Interface\\Icons\\INV_Misc_Rune_01")
        frame.questStartDungeonIcon.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    frame.questStartDungeonIcon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    frame.questStartDungeonIcon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L("IN_DUNGEON"))
        GameTooltip:Show()
    end)
    frame.questStartDungeonIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.questStartDungeonIcon:Hide()

    frame.questNotesText = frame.questDetailContent:CreateFontString(nil, "OVERLAY")
    frame.questNotesText:SetWidth(365)
    frame.questNotesText:SetJustifyH("LEFT")
    frame.questNotesText:SetJustifyV("TOP")
    frame.questNotesText:SetWordWrap(true)
    ApplyQuestFont(frame.questNotesText, "ForeverDJ_QuestFont", "ForeverDJ_GameFontHighlight")

    frame.questNoteItemButton = CreateFrame("Button", nil, frame.questDetailContent, "BackdropTemplate")
    frame.questNoteItemButton:SetSize(210, 34)
    SetBackdrop(frame.questNoteItemButton, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 9, 2)
    frame.questNoteItemButton.icon = frame.questNoteItemButton:CreateTexture(nil, "ARTWORK")
    frame.questNoteItemButton.icon:SetSize(26, 26)
    frame.questNoteItemButton.icon:SetPoint("LEFT", 5, 0)
    frame.questNoteItemButton.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.questNoteItemButton.name = frame.questNoteItemButton:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
    frame.questNoteItemButton.name:SetPoint("LEFT", frame.questNoteItemButton.icon, "RIGHT", 7, 0)
    frame.questNoteItemButton.name:SetPoint("RIGHT", -6, 0)
    frame.questNoteItemButton.name:SetJustifyH("LEFT")
    frame.questNoteItemButton:SetScript("OnEnter", function(self)
        HideSearchItemHighlight(self)
        if self.item then ShowItemTooltip(self) end
    end)
    frame.questNoteItemButton:SetScript("OnLeave", function(self)
        self.fdjComparing = nil
        if itemTooltip then itemTooltip:Hide() end
        HideComparisonTooltips()
    end)
    frame.questNoteItemButton:SetScript("OnClick", function(self)
        if self.mapLocation then
            if itemTooltip then itemTooltip:Hide() end
            HideComparisonTooltips()
            if self.mapLocation.dungeon and FDJ.ShowQuestSpotOnDungeonMap then -- mapquests
                FDJ.ShowQuestSpotOnDungeonMap(self.mapLocation)
                return
            end
            ShowRecordedLocationOnMap(self.mapLocation, self.mapLocation.label)
            return
        end
        if self.item and FDJ.JumpToBossDrop and FDJ.JumpToBossDrop(self.item[1]) then
            if itemTooltip then itemTooltip:Hide() end
            HideComparisonTooltips()
        end
    end)
    frame.questNoteItemButton.fdjBossJump = true
    frame.questNoteItemButton:Hide()

    frame.noQuestMessage = questInset:CreateFontString(nil, "OVERLAY")
    frame.noQuestMessage:SetPoint("TOPLEFT", 16, -82)
    frame.noQuestMessage:SetPoint("RIGHT", -16, 0)
    frame.noQuestMessage:SetJustifyH("LEFT")
    frame.noQuestMessage:SetJustifyV("TOP")
    frame.noQuestMessage:SetWordWrap(true)
    ApplyQuestFont(frame.noQuestMessage, "ForeverDJ_QuestFont", "ForeverDJ_GameFontHighlight")
    frame.noQuestMessage:SetTextColor(0.10, 0.065, 0.025)
    frame.noQuestMessage:Hide()

    do
        local ok, button = pcall(CreateFrame, "Button", nil, frame.questDetailContent, "UIPanelButtonTemplate,InsecureActionButtonTemplate")
        if ok and button then
            frame.questMapButton = button
            frame.questMapButton._fdjCanTarget = true
        else
            frame.questMapButton = CreateFrame("Button", nil, frame.questDetailContent, "UIPanelButtonTemplate")
            frame.questMapButton._fdjCanTarget = false
        end
    end
    FDJ.OwnFonts(frame.questMapButton) -- ownfonts (2.0.8)
    frame.questMapButton:SetSize(104, 24)
    frame.questMapButton:SetText(L("SHOW_ON_MAP"))
    frame.questMapButton.icon = frame.questMapButton:CreateTexture(nil, "OVERLAY")
    frame.questMapButton.icon:SetSize(17, 17)
    frame.questMapButton.icon:SetPoint("RIGHT", -7, 0)
    frame.questMapButton.icon:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
    frame.questMapButton.icon:Hide()
    frame.questMapButton:RegisterForClicks("LeftButtonUp")
    if frame.questMapButton._fdjCanTarget then
        frame.questMapButton:SetAttribute("useOnKeyDown", false)
    end
    local function QuestMapButtonOpenMap(self)
        local loc = self.prereqLocation or (self.quest and QUEST_START_MAPS[self.quest.id])
        -- Targeting and raid marking, when the quest giver is nearby, are handled
        -- by the secure hardware-click macro configured for this button.
        FDJ.pendingMarkerQuestTitle = self.fdjQuestTitle
        FDJ.pendingMarkerTurnIn = (self == frame.questTurninMapButton or self.fdjLabelKey == "SHOW_TURN_IN") or nil
        FDJ.pendingMarkerQuestID = self.fdjQuestID or (self.quest and self.quest.id) -- autoclear
        if self.prereqLocation then
            ShowRecordedLocationOnMap(self.prereqLocation, self.prereqLocation.label)
        else
            ShowQuestStartOnMap(self.quest)
        end
    end
    -- Keep the protected target/mark action intact, then open the map afterwards.
    if frame.questMapButton._fdjCanTarget then
        frame.questMapButton:SetScript("PostClick", QuestMapButtonOpenMap)
    else
        frame.questMapButton:SetScript("OnClick", QuestMapButtonOpenMap)
    end
    frame.questMapButton:SetScript("OnEnter", function(self)
        local loc = self.prereqLocation or (self.quest and QUEST_START_MAPS[self.quest.id])
        if FDJ.MapMarkers and FDJ.MapMarkers.ConfigureTargetAndMarkAction then
            -- Only auto-target/mark from Show on Map when the player is actually
            -- close to the recorded NPC. This avoids clearing a distant target.
            FDJ.MapMarkers.ConfigureTargetAndMarkAction(self, loc, true)
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.fdjCustomLabel or L("SHOW_GIVER_ON_MAP"))
        if self.fdjCustomLabel then
            GameTooltip:AddLine("Evenshade's Overlook, Shen'dralas (35.0, 46.6)", 1, 1, 1, true)
        else
            GameTooltip:AddLine(L("MAP_TOOLTIP"), 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    frame.questMapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.questMapButton:Hide()

    -- Chain steps: "Show Turn In" under Turn in, next to "Show on Map" under
    -- Starts at, when the turn-in NPC stands somewhere else.
    do
        local ok, button = pcall(CreateFrame, "Button", nil, frame.questDetailContent, "UIPanelButtonTemplate,InsecureActionButtonTemplate")
        if ok and button then
            button._fdjCanTarget = true
        else
            button = CreateFrame("Button", nil, frame.questDetailContent, "UIPanelButtonTemplate")
            button._fdjCanTarget = false
        end
        frame.questTurninMapButton = button
        FDJ.OwnFonts(button) -- ownfonts (2.0.8)
        button:SetSize(120, 24)
        button.fdjLabelKey = "SHOW_TURN_IN"
        button:SetText(L("SHOW_TURN_IN"))
        button.icon = button:CreateTexture(nil, "OVERLAY")
        button.icon:SetSize(17, 17)
        button.icon:SetPoint("RIGHT", -7, 0)
        button.icon:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
        button:RegisterForClicks("LeftButtonUp")
        local openMap = frame.questMapButton:GetScript("PostClick") or frame.questMapButton:GetScript("OnClick")
        if button._fdjCanTarget then
            button:SetAttribute("useOnKeyDown", false)
            button:SetScript("PostClick", openMap)
        else
            button:SetScript("OnClick", openMap)
        end
        button:SetScript("OnEnter", frame.questMapButton:GetScript("OnEnter"))
        button:SetScript("OnLeave", frame.questMapButton:GetScript("OnLeave"))
        button:Hide()
    end

    frame.questChainButton = CreateFrame("Button", nil, frame.questDetailContent, "UIPanelButtonTemplate")
    FDJ.OwnFonts(frame.questChainButton) -- ownfonts (2.0.8)
    frame.questChainButton:SetSize(132, 24)
    frame.questChainButton:SetText(L("SHOW_QUEST_CHAIN"))
    frame.questChainButton.icon = frame.questChainButton:CreateTexture(nil, "OVERLAY")
    frame.questChainButton.icon:SetSize(17, 17)
    frame.questChainButton.icon:SetPoint("RIGHT", -7, 0)
    frame.questChainButton.icon:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\QuestChain.tga")
    frame.questChainButton.icon:SetTexCoord(0, 1, 0, 1)
    do
        local fs = frame.questChainButton:GetFontString()
        if fs then
            fs:ClearAllPoints()
            fs:SetPoint("CENTER", frame.questChainButton, "CENTER", -9, 0)
        end
    end
    frame.questChainButton:SetScript("OnClick", function(self)
        local questID = self.questID
        local chain = questID and QUEST_PREREQ_CHAINS[questID]
        if not chain then return end

        -- The detail-panel "Show Quest Chain" button is OPEN/NAVIGATE only.
        -- It must never collapse an already-open chain. Collapsing is reserved
        -- exclusively for the small chain icon beside the quest in the left list.
        expandedQuestChains[questID] = true
        -- choicepulse (2.0.54): its choices open too, even one closed before
        if FDJ.OpenChainChoices then FDJ.OpenChainChoices(questID, chain) end

        -- Open the step the player is currently on when possible. Otherwise
        -- open the first incomplete prerequisite; if every step is complete,
        -- open the final prerequisite.
        local target = nil
        for _, step in ipairs(chain) do
            if step.id and IsQuestInLog(step.id) then
                target = step
                break
            end
        end
        if not target then
            for _, step in ipairs(chain) do
                if not (step.id and IsQuestFinished(step.id)) then
                    target = step
                    break
                end
            end
        end
        if not target then
            target = chain[#chain] or chain[1]
        end

        selectedPrereqStep = target
        selectedPrereqParentQuestName = self.parentQuestName
        selectedPrereqParentQuestID = questID
        if target and target.id then RequestQuestRewardData(target.id) end

        RefreshQuestList()
        RefreshQuestDetail()
        -- choicepulse (2.0.54): the choice's quests light up for a moment
        if FDJ.PulseChainChoices then FDJ.PulseChainChoices(questID, chain) end
    end)
    frame.questChainButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L("REQUIRED_QUESTS"))
        GameTooltip:AddLine(L("OPEN_REQUIRED_CHAIN"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame.questChainButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.questChainButton:Hide()

    UpdateQuestActionButtonSizes()

    frame.questStartLinkButton = CreateFrame("Button", nil, frame.questDetailContent, "UIPanelButtonTemplate")
    FDJ.OwnFonts(frame.questStartLinkButton) -- ownfonts (2.0.8)
    frame.questStartLinkButton:SetSize(232, 24)
    frame.questStartLinkButton:SetScript("OnClick", function(self)
        if self.questID then SelectQuestByID(self.questID) end
    end)
    frame.questStartLinkButton:Hide()

    frame.questLeadsToButton = CreateFrame("Button", nil, frame.questDetailContent, "UIPanelButtonTemplate")
    FDJ.OwnFonts(frame.questLeadsToButton) -- ownfonts (2.0.8)
    frame.questLeadsToButton:SetSize(270, 24)
    frame.questLeadsToButton:SetScript("OnClick", function(self)
        if not self.questID then return end
        -- leadsdungeon (2.0.13): the next step is on another dungeon's page
        -- (The Medallion of Faith, Stratholme: Living, leads to Aurius'
        -- Reckoning, Stratholme: Undead): open that page on it.
        if self.questDungeon and self.questDungeon ~= selectedDungeon and FDJ.OpenQuestPage then
            FDJ.OpenQuestPage(self.questDungeon, self.questID)
            return
        end
        SelectQuestByID(self.questID)
    end)
    frame.questLeadsToButton:Hide()

    local function StyleQuestNavArrow(button, direction)
        local isLeft = direction == "LEFT"
        button:SetSize(28, 28)

        -- Use the same native Forever/Classic page arrows as the language control.
        local normal = isLeft and "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up" or "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"
        local pushed = isLeft and "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down" or "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down"
        local disabled = isLeft and "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled" or "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled"

        button:SetNormalTexture(normal)
        button:SetPushedTexture(pushed)
        button:SetDisabledTexture(disabled)

        local normalTex = button:GetNormalTexture()
        if normalTex then normalTex:SetAllPoints(button) end
        local pushedTex = button:GetPushedTexture()
        if pushedTex then pushedTex:SetAllPoints(button) end
        local disabledTex = button:GetDisabledTexture()
        if disabledTex then disabledTex:SetAllPoints(button) end

        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        highlight:SetBlendMode("ADD")
        highlight:SetAllPoints(button)
    end

    frame.questNextStepButton = CreateFrame("Button", nil, frame.questTextInset)
    frame.questNextStepButton:SetPoint("TOPRIGHT", frame.questTextInset, "TOPRIGHT", -12, -10)
    StyleQuestNavArrow(frame.questNextStepButton, "RIGHT")
    frame.questNextStepButton:SetScript("OnClick", function() SelectPrerequisiteStepByOffset(1) end)
    frame.questNextStepButton:Hide()

    frame.questPrevStepButton = CreateFrame("Button", nil, frame.questTextInset)
    frame.questPrevStepButton:SetPoint("RIGHT", frame.questNextStepButton, "LEFT", -5, 0)
    StyleQuestNavArrow(frame.questPrevStepButton, "LEFT")
    frame.questPrevStepButton:SetScript("OnClick", function() SelectPrerequisiteStepByOffset(-1) end)
    frame.questPrevStepButton:Hide()

    frame.questTurninText = frame.questDetailContent:CreateFontString(nil, "OVERLAY")
    frame.questTurninText:SetWidth(365)
    frame.questTurninText:SetJustifyH("LEFT")
    frame.questTurninText:SetJustifyV("TOP")
    frame.questTurninText:SetWordWrap(true)
    ApplyQuestFont(frame.questTurninText, "ForeverDJ_QuestFont", "ForeverDJ_GameFontHighlight")

    frame.questRewardHeader = frame.questDetailContent:CreateFontString(
        nil,
        "OVERLAY"
    )
    ApplyQuestFont(frame.questRewardHeader, "ForeverDJ_QuestTitleFont", "ForeverDJ_GameFontNormal")
    frame.questRewardHeader:SetTextColor(0.82, 0.52, 0.10)
    frame.questRewardHeader:SetShadowColor(0, 0, 0, 0.85)
    frame.questRewardHeader:SetShadowOffset(1, -1)
    frame.questRewardHeader:SetText(L("REWARDS"):upper())

    frame.questXPReward = CreateFrame("Frame", nil, frame.questDetailContent, "BackdropTemplate")
    frame.questXPReward:SetSize(116, 28)
    SetBackdrop(
        frame.questXPReward,
        "Interface\\Buttons\\WHITE8X8",
        "Interface\\Tooltips\\UI-Tooltip-Border",
        9,
        2
    )
    frame.questXPReward:SetBackdropColor(0.26, 0.17, 0.42, 0.95)
    frame.questXPReward:SetBackdropBorderColor(0.45, 0.32, 0.62, 1)
    frame.questXPReward.badge = frame.questXPReward:CreateTexture(nil, "ARTWORK")
    frame.questXPReward.badge:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.questXPReward.badge:SetSize(22, 20)
    frame.questXPReward.badge:SetPoint("LEFT", 6, 0)
    frame.questXPReward.badge:SetColorTexture(0.45, 0.20, 0.80, 0.95)
    frame.questXPReward.badgeLabel = frame.questXPReward:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
    frame.questXPReward.badgeLabel:SetPoint("CENTER", frame.questXPReward.badge, "CENTER", 0, 0)
    frame.questXPReward.badgeLabel:SetText("XP")
    frame.questXPReward.badgeLabel:SetTextColor(1.00, 0.93, 0.50)
    frame.questXPReward.text = frame.questXPReward:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    frame.questXPReward.text:SetPoint("LEFT", frame.questXPReward.badge, "RIGHT", 8, 0)
    frame.questXPReward.text:SetPoint("RIGHT", -8, 0)
    frame.questXPReward.text:SetJustifyH("LEFT")
    frame.questXPReward.text:SetTextColor(1, 1, 1)
    frame.questXPReward:Hide()

    -- Money reward, laid out beside XP like Blizzard's quest log.
    frame.questMoneyReward = CreateFrame("Frame", nil, frame.questDetailContent, "BackdropTemplate")
    frame.questMoneyReward:SetSize(72, 26)
    SetBackdrop(
        frame.questMoneyReward,
        "Interface\\Buttons\\WHITE8X8",
        "Interface\\Tooltips\\UI-Tooltip-Border",
        9,
        2
    )
    frame.questMoneyReward:SetBackdropColor(0.10, 0.07, 0.025, 0.94)
    frame.questMoneyReward:SetBackdropBorderColor(0.45, 0.30, 0.11, 1)
    frame.questMoneyReward.text = frame.questMoneyReward:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    frame.questMoneyReward.text:SetPoint("LEFT", 6, 0)
    frame.questMoneyReward.text:SetPoint("RIGHT", -4, 0)
    frame.questMoneyReward.text:SetJustifyH("LEFT")
    frame.questMoneyReward.text:SetTextColor(1.00, 0.92, 0.72)
    frame.questMoneyReward:Hide()

    frame.questRewardSummary = frame.questDetailContent:CreateFontString(
        nil,
        "OVERLAY"
    )
    ApplyRewardSummaryFont(frame.questRewardSummary)
    frame.questRewardSummary:SetJustifyH("LEFT")
    frame.questRewardSummary:SetJustifyV("TOP")
    frame.questRewardSummary:SetWordWrap(true)

    -- Full-width interior dungeon map page. Ragefire Chasm is the first
    -- dungeon using it; other dungeons can opt in later with their own map data.
    frame.dungeonMapPanel = CreateFrame("Frame", nil, content, "BackdropTemplate")
    frame.dungeonMapPanel:SetPoint("TOPLEFT", 14, -84)
    frame.dungeonMapPanel:SetPoint("BOTTOMRIGHT", -14, 14)
    SetBackdrop(frame.dungeonMapPanel, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 12, 3)
    frame.dungeonMapPanel:SetBackdropColor(0.055, 0.04, 0.025, 0.98)
    frame.dungeonMapPanel:SetBackdropBorderColor(0.52, 0.34, 0.13, 1)
    if frame.dungeonMapPanel.SetClipsChildren then frame.dungeonMapPanel:SetClipsChildren(true) end

    frame.dungeonMapTitle = frame.dungeonMapPanel:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalHuge")
    frame.dungeonMapTitle:SetPoint("TOPLEFT", 20, -18)
    frame.dungeonMapTitle:SetTextColor(1.00, 0.82, 0.27)
    frame.dungeonMapTitle:Hide()

    frame.dungeonMapCanvas = CreateFrame("Frame", nil, frame.dungeonMapPanel, "BackdropTemplate")
    frame.dungeonMapCanvas:SetPoint("TOPLEFT", 12, -12)
    frame.dungeonMapCanvas:SetPoint("BOTTOMRIGHT", -12, 12)
    SetBackdrop(frame.dungeonMapCanvas, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 10, 2)
    frame.dungeonMapCanvas:SetBackdropColor(0.035, 0.025, 0.018, 0.96)
    frame.dungeonMapCanvas:SetBackdropBorderColor(0.43, 0.30, 0.14, 1)
    if frame.dungeonMapCanvas.SetClipsChildren then frame.dungeonMapCanvas:SetClipsChildren(true) end

    frame.dungeonMapArtHolder = CreateFrame("Frame", nil, frame.dungeonMapCanvas)
    frame.dungeonMapArtHolder:SetPoint("CENTER")
    frame.dungeonMapArtTiles = {}
    frame.dungeonMapBossMarkers = {}

    frame.dungeonMapPanel:Hide()

    -- Full-width travel guide page for faction-specific approaches.
    frame.routePanel = CreateFrame("Frame", nil, content, "BackdropTemplate")
    frame.routePanel:SetPoint("TOPLEFT", 14, -84)
    frame.routePanel:SetPoint("BOTTOMRIGHT", -14, 14)
    SetBackdrop(frame.routePanel, "Interface\\Buttons\\WHITE8X8", "Interface\\Tooltips\\UI-Tooltip-Border", 12, 3)
    frame.routePanel:SetBackdropColor(0.18, 0.13, 0.075, 0.98)
    frame.routePanel:SetBackdropBorderColor(0.52, 0.34, 0.13, 1)
    AddClassicParchment(frame.routePanel, 0.18, 1.00, 0.94, 0.82)

    frame.routeFactionIcon = frame.routePanel:CreateTexture(nil, "ARTWORK")
    frame.routeFactionIcon:SetSize(34, 34)
    frame.routeFactionIcon:SetPoint("TOPLEFT", 20, -18)
    frame.routeFactionIcon:SetTexture(ALLIANCE_ICON)

    frame.routeTitle = frame.routePanel:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalHuge")
    frame.routeTitle:SetPoint("TOPLEFT", frame.routeFactionIcon, "TOPRIGHT", 10, -1)
    frame.routeTitle:SetPoint("RIGHT", -24, 0)
    frame.routeTitle:SetJustifyH("LEFT")
    frame.routeTitle:SetTextColor(1.00, 0.82, 0.27)

    frame.routeSubtitle = frame.routePanel:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    frame.routeSubtitle:SetPoint("TOPLEFT", frame.routeTitle, "BOTTOMLEFT", 0, -3)
    frame.routeSubtitle:SetTextColor(0.82, 0.82, 0.82)

    frame.routeBackButton = CreateFrame("Button", nil, frame.routePanel, "UIPanelButtonTemplate")
    FDJ.OwnFonts(frame.routeBackButton) -- ownfonts (2.0.8)
    frame.routeBackButton:SetSize(1, 1)
    frame.routeBackButton:Hide()

    frame.routeMapButton = CreateFrame("Button", nil, frame.routePanel, "UIPanelButtonTemplate")
    FDJ.OwnFonts(frame.routeMapButton) -- ownfonts (2.0.8)
    frame.routeMapButton:SetSize(142, 24)
    frame.routeMapButton:SetPoint("TOPRIGHT", -118, -20)
    frame.routeMapButton:SetText(L("SHOW_ON_MAP"))
    frame.routeMapButton:SetScript("OnClick", function()
        local dungeon = DB[selectedDungeon]
        local route = dungeon and dungeon.routeGuide
        if route and route.mapRoute and ShowRouteOnMap then
            ShowRouteOnMap(route.mapRoute)
        end
    end)
    frame.routeMapButton:Hide()

    local divider = frame.routePanel:CreateTexture(nil, "ARTWORK")
    divider:SetTexture("Interface\\Buttons\\WHITE8X8")
    divider:SetPoint("TOPLEFT", 20, -65)
    divider:SetPoint("TOPRIGHT", -20, -65)
    divider:SetHeight(1)
    divider:SetColorTexture(0.62, 0.43, 0.17, 0.65)

    frame.routeSteps = frame.routePanel:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    frame.routeSteps:Hide()

    frame.routeStepScroll = CreateFrame("ScrollFrame", nil, frame.routePanel, "UIPanelScrollFrameTemplate")
    frame.routeStepScroll:SetPoint("TOPLEFT", 24, -80)
    frame.routeStepScroll:SetPoint("BOTTOMRIGHT", -34, 18)
    frame.routeStepContent = CreateFrame("Frame", nil, frame.routeStepScroll)
    frame.routeStepContent:SetSize(560, 1)
    frame.routeStepScroll:SetScrollChild(frame.routeStepContent)
    frame.routeStepContent:SetPoint("TOPLEFT", frame.routeStepScroll, "TOPLEFT", 0, 0)
    frame.routeStepScroll:SetScript("OnSizeChanged", function(self, width)
        if frame.routeStepContent and width and width > 20 then
            frame.routeStepContent:SetWidth(width - 6)
        end
    end)
    frame.routeStepRows = {}

    frame.routeShortcutTitle = frame.routePanel:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    frame.routeShortcutTitle:SetPoint("TOPLEFT", 24, -285)
    frame.routeShortcutTitle:SetTextColor(0.45, 0.72, 1.00)
    frame.routeShortcutTitle:Hide()
    frame.routeShortcut = frame.routePanel:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    frame.routeShortcut:SetPoint("TOPLEFT", frame.routeShortcutTitle, "BOTTOMLEFT", 0, -5)
    frame.routeShortcut:SetPoint("RIGHT", -24, 0)
    frame.routeShortcut:SetJustifyH("LEFT")
    frame.routeShortcut:SetWordWrap(true)
    frame.routeShortcut:SetTextColor(0.88, 0.90, 0.95)
    frame.routeShortcut:Hide()

    frame.routeWarning = frame.routePanel:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    frame.routeWarning:SetPoint("BOTTOMLEFT", 24, 18)
    frame.routeWarning:SetPoint("RIGHT", -24, 0)
    frame.routeWarning:SetJustifyH("LEFT")
    frame.routeWarning:SetWordWrap(true)
    frame.routeWarning:SetTextColor(1.00, 0.62, 0.30)
    frame.routeWarning:Hide()
    frame.routePanel:Hide()

    questLeft:Hide()
    questRight:Hide()

    tinsert(UISpecialFrames, frame:GetName())

    -- Remember the tab the player came from so right-click can return to it.
    frame.bossesTab:SetScript("PreClick", function() frame.fdjPrevMode = selectedMode end)
    frame.questsTab:SetScript("PreClick", function() frame.fdjPrevMode = selectedMode end)

    frame:SetScript("OnShow", function()
        if FDJ.InstallRightClickBack then FDJ.InstallRightClickBack() end
        PlayJournalPaperSound()
        -- Warm the portraits once per session, on a later frame and never in
        -- combat: doing all of it inside OnShow can exceed the client's script
        -- time limit when the journal is opened mid-fight.
        if FDJ.PrewarmBossPortraits and not FDJ.portraitsPrewarmed then
            local function prewarm() pcall(FDJ.PrewarmBossPortraits) end
            if C_Timer and C_Timer.After then C_Timer.After(0.1, prewarm) else prewarm() end
        end

        -- If the player opens the journal while physically inside a dungeon,
        -- always jump straight to that dungeon's page. Outside an instance, keep
        -- the normal session behavior (last open dungeon, otherwise Home).
        local currentDungeon = CurrentDungeon()
        if currentDungeon and DB[currentDungeon] and not DB[currentDungeon].previewOnly then
            SelectDungeon(currentDungeon)
        elseif sessionLastView == "dungeon" and DB[selectedDungeon] then
            ShowDungeonPage()
            RefreshAll()
        else
            ShowHomePage()
        end
        -- Reopen on the map if that is where this dungeon was left.
        if FDJ.mapOpenForDungeon and frame.currentView == "dungeon" and FDJ.ReopenDungeonMap then
            FDJ.ReopenDungeonMap(FDJ.mapOpenForDungeon)
        end
    end)
    frame:SetScript("OnHide", function()
        -- sunonce (2.0.8): the next time the journal opens, the beam plays again
        if FDJ.ResetChainSheen then FDJ.ResetChainSheen() end
        -- rtvcap (2.0.9): closed: its pages' portraits are let go (their
        -- render targets freed; the page draws them again when the journal
        -- opens), keeping only a few, a moment later (not if opened again).
        if FDJ.ReleaseHiddenPortraits and C_Timer and C_Timer.After then
            C_Timer.After(0.5, function()
                if frame and not frame:IsShown() then pcall(FDJ.ReleaseHiddenPortraits, frame, 8) end
            end)
        end
        -- The Favourites window is parented to UIParent so it can stay open
        -- while navigating inside the journal. When the journal itself closes,
        -- explicitly close the popup as well (including during combat).
        if frame and frame.favouritesWindow and frame.favouritesWindow:IsShown() then
            frame.favouritesWindow:Hide()
        end
        if FDJ.HideItemFavouriteMenu then FDJ.HideItemFavouriteMenu() end

        if frame and frame.currentView then
            sessionLastView = frame.currentView
        end
        FDJ.mapOpenForDungeon = nil
        if frame.currentView == "dungeon" and frame.dungeonMapPanel and frame.dungeonMapPanel:IsShown() and FDJ.GetSelectedDungeon then
            FDJ.mapOpenForDungeon = (FDJ.GetSelectedDungeon())
        end
        homeEditMode = false
        if frame.hideDungeonsButton then
            frame.hideDungeonsButton:SetBackdropColor(0.12, 0.115, 0.105, 0.98)
            frame.hideDungeonsButton:SetBackdropBorderColor(0.48, 0.40, 0.27, 1)
        end
        if frame.hideDungeonsButtonText then
            frame.hideDungeonsButtonText:SetText(L("HIDE_DUNGEONS"))
            frame.hideDungeonsButtonText:SetTextColor(1.00, 0.82, 0.27)
        end
        if frame.hideDungeonsDoneCheck then
            frame.hideDungeonsDoneCheck:Hide()
        end
        if ResetPortraitResolver then ResetPortraitResolver() end
    end)

    frame:Hide()
end

-- ============================================================
-- MINIMAP
-- ============================================================

FDJ._minimapUsingLibDBIcon = FDJ._minimapUsingLibDBIcon or false
FDJ._minimapIconLib = FDJ._minimapIconLib or nil
FDJ._minimapDataObject = FDJ._minimapDataObject or nil

local function PositionMinimap()
    if not minimapButton or not Minimap or FDJ._minimapUsingLibDBIcon then return end

    local angle = math.rad(ForeverDungeonJournalDB.minimapAngle or 225)
    local radius = (
        math.max(Minimap:GetWidth() or 140, Minimap:GetHeight() or 140) * 0.5
    ) + 8

    minimapButton:ClearAllPoints()
    minimapButton:SetPoint(
        "CENTER",
        Minimap,
        "CENTER",
        math.cos(angle) * radius,
        math.sin(angle) * radius
    )
end

local function ToggleJournal()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

FDJ.ToggleJournal = ToggleJournal
_G.ForeverDungeonJournal_Toggle = function()
    if FDJ.ToggleJournal then
        FDJ.ToggleJournal()
    end
end

local function HideMinimapButton()
    ForeverDungeonJournalDB.minimapHidden = true
    ForeverDungeonJournalDB.minimap = ForeverDungeonJournalDB.minimap or {}
    ForeverDungeonJournalDB.minimap.hide = true

    if FDJ._minimapUsingLibDBIcon and FDJ._minimapIconLib then
        FDJ._minimapIconLib:Hide("ForeverDungeonJournal")
    elseif minimapButton then
        minimapButton:Hide()
    end

    print("|cffd8a83cDungeonJournal|r " .. L("MINIMAP_HIDDEN"))
end

-- Right-clicking the minimap button asks first: many players hid it by accident.
FDJ.HideMinimapButton = HideMinimapButton
FDJ.ConfirmHideMinimapButton = function()
    if not StaticPopupDialogs or not StaticPopup_Show then
        HideMinimapButton()
        return
    end
    StaticPopupDialogs["FOREVERDUNGEONJOURNAL_HIDE_MINIMAP"] = {
        text = L("MINIMAP_HIDE_CONFIRM"),
        button1 = YES or "Yes",
        button2 = NO or "No",
        OnAccept = function() HideMinimapButton() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("FOREVERDUNGEONJOURNAL_HIDE_MINIMAP")
end

function FDJ.ShowMinimapButton()
    ForeverDungeonJournalDB.minimapHidden = false
    ForeverDungeonJournalDB.minimap = ForeverDungeonJournalDB.minimap or {}
    ForeverDungeonJournalDB.minimap.hide = false

    if FDJ._minimapUsingLibDBIcon and FDJ._minimapIconLib then
        FDJ._minimapIconLib:Show("ForeverDungeonJournal")
        minimapButton = _G["LibDBIcon10_ForeverDungeonJournal"] or minimapButton
    elseif minimapButton then
        minimapButton:Show()
        PositionMinimap()
    end
end

function FDJ.SetupLibDBIconMinimap()
    if not _G.LibStub then return false end

    local ldb = _G.LibStub("LibDataBroker-1.1", true)
    local iconLib = _G.LibStub("LibDBIcon-1.0", true)
    if not ldb or not iconLib then return false end

    ForeverDungeonJournalDB.minimap = ForeverDungeonJournalDB.minimap or {}
    local db = ForeverDungeonJournalDB.minimap

    -- Migrate the old position once. LibDBIcon stores the same angular value in
    -- minimapPos, while the previous FDJ button used minimapAngle.
    if db.minimapPos == nil then
        db.minimapPos = ForeverDungeonJournalDB.minimapAngle or 225
    end
    db.hide = ForeverDungeonJournalDB.minimapHidden and true or false

    local object = ldb:GetDataObjectByName("ForeverDungeonJournal")
    if not object then
        object = ldb:NewDataObject("ForeverDungeonJournal", {
            type = "launcher",
            text = "DungeonJournal",
            icon = "Interface\\Icons\\INV_Misc_Book_09",
            OnClick = function(_, button)
                if button == "LeftButton" then
                    ToggleJournal()
                elseif button == "RightButton" then
                    if FDJ.ToggleSettingsPanel then FDJ.ToggleSettingsPanel() else FDJ.ConfirmHideMinimapButton() end
                end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine("DungeonJournal", 1, 0.82, 0.25)
                tooltip:AddLine(L("MINIMAP_LEFT"), 1, 1, 1)
                tooltip:AddLine(L("MINIMAP_DRAG"), 0.8, 0.8, 0.8)
                tooltip:AddLine(L("MINIMAP_OPTIONS"), 0.8, 0.8, 0.8)
            end,
        })
    end

    FDJ._minimapDataObject = object
    FDJ._minimapIconLib = iconLib

    if not iconLib:IsRegistered("ForeverDungeonJournal") then
        iconLib:Register("ForeverDungeonJournal", object, db)
    end

    minimapButton = _G["LibDBIcon10_ForeverDungeonJournal"]
    if minimapButton then
        -- These fields are present on a normal LibDBIcon button and are also
        -- useful to minimap-button collectors that inspect the frame directly.
        minimapButton.dataObject = object
        minimapButton.db = db
    end

    FDJ._minimapUsingLibDBIcon = true

    if db.hide then
        iconLib:Hide("ForeverDungeonJournal")
    else
        iconLib:Show("ForeverDungeonJournal")
    end

    return true
end

-- While RPG Mode is on the minimap book turns white: the same book icon,
-- desaturated, with a brightening copy added on top (no extra image needed,
-- so it stays a crisp book at minimap size).
FDJ.UpdateMinimapIcon = function()
    local rpg = FDJ.IsRPGMode and FDJ.IsRPGMode() or false
    local book = "Interface\\Icons\\INV_Misc_Book_09"
    if FDJ._minimapDataObject and FDJ._minimapDataObject.icon ~= book then FDJ._minimapDataObject.icon = book end
    local button = _G["LibDBIcon10_ForeverDungeonJournal"]
    local icon = button and button.icon
    if not icon or not icon.SetDesaturated then return end
    icon:SetDesaturated(rpg)
    if not button.fdjWhite then
        local w = button:CreateTexture(nil, "ARTWORK", nil, 7)
        w:SetTexture(book)
        w:SetDesaturated(true)
        w:SetBlendMode("ADD")
        w:SetAlpha(0.6)
        button.fdjWhite = w
    end
    local w = button.fdjWhite
    w:ClearAllPoints()
    w:SetAllPoints(icon)
    if icon.GetTexCoord then w:SetTexCoord(icon:GetTexCoord()) end
    w:SetShown(rpg)
end

function FDJ.CreateFallbackMinimap()
    FDJ._minimapUsingLibDBIcon = false

    minimapButton = _G["LibDBIcon10_ForeverDungeonJournal"]
        or CreateFrame("Button", "LibDBIcon10_ForeverDungeonJournal", Minimap)

    minimapButton:SetParent(Minimap)
    minimapButton:SetSize(31, 31)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")

    -- Match the public shape of a normal LibDBIcon button as closely as possible
    -- for collectors even when no shared LibDBIcon library is available.
    ForeverDungeonJournalDB.minimap = ForeverDungeonJournalDB.minimap or {}
    minimapButton.db = ForeverDungeonJournalDB.minimap
    minimapButton.dataObject = minimapButton.dataObject or {
        type = "launcher",
        text = "DungeonJournal",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
    }

    if not minimapButton.fdjInitialized then
        local bg = minimapButton:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
        bg:SetSize(20, 20)
        bg:SetPoint("CENTER")

        local icon = minimapButton:CreateTexture(nil, "ARTWORK")
        icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
        icon:SetSize(20, 20)
        icon:SetPoint("CENTER")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        minimapButton.icon = icon

        local border = minimapButton:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        border:SetSize(54, 54)
        border:SetPoint("TOPLEFT", -1, 1)
        minimapButton.border = border

        minimapButton:SetScript("OnClick", function(_, button)
            if button == "LeftButton" then
                ToggleJournal()
            elseif button == "RightButton" then
                if FDJ.ToggleSettingsPanel then FDJ.ToggleSettingsPanel() else FDJ.ConfirmHideMinimapButton() end
            end
        end)

        minimapButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("DungeonJournal", 1, 0.82, 0.25)
            GameTooltip:AddLine(L("MINIMAP_LEFT"), 1, 1, 1)
            GameTooltip:AddLine(L("MINIMAP_DRAG"), 0.8, 0.8, 0.8)
            GameTooltip:AddLine(L("MINIMAP_OPTIONS"), 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)

        minimapButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        minimapButton:SetScript("OnDragStart", function(self)
            self:SetScript("OnUpdate", function()
                local mx, my = Minimap:GetCenter()
                if not mx or not my then return end

                local x, y = GetCursorPosition()
                local scale = UIParent:GetEffectiveScale()
                x, y = x / scale, y / scale

                ForeverDungeonJournalDB.minimapAngle =
                    math.deg(math.atan2(y - my, x - mx))

                PositionMinimap()
            end)
        end)

        minimapButton:SetScript("OnDragStop", function(self)
            self:SetScript("OnUpdate", nil)
        end)

        minimapButton.fdjInitialized = true
    end

    PositionMinimap()

    if ForeverDungeonJournalDB.minimapHidden then
        minimapButton:Hide()
    else
        minimapButton:Show()
    end
end

function FDJ.CreateMinimap()
    -- Prefer the real shared LibDataBroker/LibDBIcon libraries when another
    -- enabled addon (including Leatrix Plus) provides them. This makes FDJ a
    -- genuinely registered LibDBIcon launcher instead of only imitating the
    -- frame name, which is required by collectors that use the library registry.
    if FDJ.SetupLibDBIconMinimap() then
        return
    end

    -- Keep a standalone fallback so FDJ still has a minimap button when no
    -- broker/icon library exists in the user's addon set.
    FDJ.CreateFallbackMinimap()
end

-- ============================================================
-- COMMANDS / EVENTS
-- ============================================================

SLASH_FOREVERDUNGEONJOURNAL1 = "/dj"
SLASH_FOREVERDUNGEONJOURNAL2 = nil

SlashCmdList.FOREVERDUNGEONJOURNAL = function(msg)
    msg = strtrim(msg or ""):lower()

    if msg == "lang" or msg == "language" then
        local active = FDJ.GetLanguage and FDJ.GetLanguage() or "enUS"
        local saved = ForeverDungeonJournalDB.language or "auto"
        local display = saved == "auto" and L("LANGUAGE_AUTO", active) or active
        print("|cffd8a83cDungeonJournal|r " .. L("LANGUAGE_CURRENT", display))
        print("|cffd8a83cDungeonJournal|r " .. L("LANGUAGE_HELP"))
        return
    end

    local langArg = msg:match("^lang%s+(%S+)$") or msg:match("^language%s+(%S+)$")
    if langArg then
        ApplySelectedLanguage(langArg)
        local active, saved = FDJ.SetLanguage(langArg)
        local display = saved == "auto" and L("LANGUAGE_AUTO", active) or active
        print("|cffd8a83cDungeonJournal|r " .. L("LANGUAGE_SET", display))
        return
    end

    if msg == "options" or msg == "settings" or msg == "config" then
        if FDJ.ToggleSettingsPanel then FDJ.ToggleSettingsPanel() end
        return
    end
    if msg == "tracker" then
        if not (FDJ.ReopenDungeonTracker and FDJ.ReopenDungeonTracker()) then
            -- 2.0.3: inside a dungeon, say when it will appear.
            local inDungeon = FDJ.RunLog and FDJ.RunLog.IsInside and FDJ.RunLog.IsInside()
            if inDungeon then
                print("|cffd8a83cDungeonJournal|r The tracker starts with the first kill in this dungeon.")
            else
                print("|cffd8a83cDungeonJournal|r No active dungeon run to show.")
            end
        end
        return
    end
    if msg == "reset" then -- 2.0.4: the dungeon was reset, end the run (the tracker's reset button)
        if not (FDJ.ResetTrackedRun and FDJ.ResetTrackedRun()) then
            print("|cffd8a83cDungeonJournal|r No active dungeon run to end.")
        end
        return
    end
    if msg == "log" or msg == "runs" then -- Run Log (Systems/RunLogUI.lua)
        if FDJ.ToggleRunLog then FDJ.ToggleRunLog() end
        return
    end
    if msg == "itemtip" then
        local on = FDJ.ToggleItemSourceStrip and FDJ.ToggleItemSourceStrip()
        print("|cffffd100Dungeon Journal|r item source on tooltips: " .. (on and "ON" or "OFF"))
        return
    end
    if msg == "mode" then
        if FDJ.ShowModeChooser then FDJ.ShowModeChooser(true) end
        return
    end
    if msg == "worldmap" then
        local on = FDJ.ToggleWorldMapOverlay and FDJ.ToggleWorldMapOverlay()
        print("|cffd8a83cDungeonJournal|r " .. L("WM_DUNGEON_MAP") .. " (M): " .. (on and "ON" or "OFF"))
        return
    end

    -- /dj resize (M, 16 Nov 2026: "keep it DJ resize"), was /dj scale; /dj wing removed
    if msg:match("^resize") then
        local value = tonumber(msg:match("^resize%s+([%d%.]+)"))
        local scale = FDJ.SetJournalScale and FDJ.SetJournalScale(value or 1)
        print("|cffd8a83cDungeonJournal|r resize: " .. tostring(scale))
        return
    end

    if msg == "minimap" then
        FDJ.ShowMinimapButton()
        return
    end

    if msg == "rfc" or msg == "ragefire" or msg == "ragefirechasm" then
        frame:Show()
        SelectDungeon("Ragefire Chasm")
        return
    end

    if msg == "hall" or msg == "hot" then
        frame:Show()
        SelectDungeon("Hall of Thanes")
        return
    end

    if msg == "dm" or msg == "vc" or msg == "deadmines" then
        frame:Show()
        SelectDungeon("The Deadmines")
        return
    end

    if msg == "ruins" or msg == "rol" or msg == "lordaeron" then
        frame:Show()
        SelectDungeon("Ruins of Lordaeron")
        return
    end

    if msg == "wc" or msg == "wailing" or msg == "wailingcaverns" then
        frame:Show()
        SelectDungeon("Wailing Caverns")
        return
    end

    if msg == "sfk" or msg == "shadowfang" or msg == "shadowfangkeep" then
        frame:Show()
        SelectDungeon("Shadowfang Keep")
        return
    end

    if msg == "bfd" or msg == "blackfathom" or msg == "blackfathomdeeps" or msg == "blackfathomdepths" then
        frame:Show()
        SelectDungeon("Blackfathom Deeps")
        return
    end

    -- Shortcuts for the dungeons added later (/dj smlib, /dj gnomer, ...).
    do
        local shortcuts = {
            stocks = "The Stockade", stockade = "The Stockade", stockades = "The Stockade",
            gnomer = "Gnomeregan", gnomeregan = "Gnomeregan",
            rfk = "Razorfen Kraul", kraul = "Razorfen Kraul", razorfenkraul = "Razorfen Kraul",
            dala = "City of Dalaran", dal = "City of Dalaran", dalaran = "City of Dalaran", cityofdalaran = "City of Dalaran",
            exca = "Excavation Site: Wetlands", excavation = "Excavation Site: Wetlands", wetlands = "Excavation Site: Wetlands",
            smgy = "Scarlet Monastery: Graveyard", gy = "Scarlet Monastery: Graveyard", graveyard = "Scarlet Monastery: Graveyard",
            smlib = "Scarlet Monastery: Library", lib = "Scarlet Monastery: Library", library = "Scarlet Monastery: Library",
            smarm = "Scarlet Monastery: Armory", arm = "Scarlet Monastery: Armory", armory = "Scarlet Monastery: Armory",
            smcath = "Scarlet Monastery: Cathedral", cath = "Scarlet Monastery: Cathedral", cathedral = "Scarlet Monastery: Cathedral",
            rfd = "Razorfen Downs", downs = "Razorfen Downs", razorfendowns = "Razorfen Downs",
            ulda = "Uldaman", uld = "Uldaman", uldaman = "Uldaman",
            zf = "Zul'Farrak", zulfarrak = "Zul'Farrak",
            st = "Sunken Temple", sunken = "Sunken Temple", sunkentemple = "Sunken Temple",
            scholo = "Scholomance", scholomance = "Scholomance", mara = "Maraudon", maraudon = "Maraudon",
            brd = "Blackrock Depths", depths = "Blackrock Depths", blackrockdepths = "Blackrock Depths",
            ubrs = "Upper Blackrock Spire", upperspire = "Upper Blackrock Spire",
            lbrs = "Lower Blackrock Spire", lowerspire = "Lower Blackrock Spire",
            dme = "Dire Maul: East", dmeast = "Dire Maul: East", dmw = "Dire Maul: West", dmwest = "Dire Maul: West",
            dmn = "Dire Maul: North", dmnorth = "Dire Maul: North", tribute = "Dire Maul: North",
            strat = "Stratholme: Living", stratlive = "Stratholme: Living", stratliving = "Stratholme: Living",
            stratud = "Stratholme: Undead", stratundead = "Stratholme: Undead", baron = "Stratholme: Undead",
            -- 2.0.4: the Forever dungeons that had none (same as /dj testlog)
            alcaz = "Alcaz Prison", alcazprison = "Alcaz Prison", bmh = "Blackmaw Hold", blackmaw = "Blackmaw Hold",
            blackmawhold = "Blackmaw Hold", krol = "Krol'dok Stronghold", kroldok = "Krol'dok Stronghold",
            kroldokstronghold = "Krol'dok Stronghold", shaper = "Shaper's Terrace", shapers = "Shaper's Terrace",
            shapersterrace = "Shaper's Terrace", dc = "The Drowned City", drowned = "The Drowned City",
            drownedcity = "The Drowned City",
        }
        local key = msg:gsub("[%s:%-']", "")
        local target = shortcuts[key]
        if target and DB[target] then
            frame:Show()
            SelectDungeon(target)
            return
        end
    end

    ToggleJournal()
end

FDJ.events = FDJ.events or CreateFrame("Frame")
FDJ.events:RegisterEvent("PLAYER_LOGIN")
FDJ.events:RegisterEvent("PLAYER_LEAVING_WORLD")
FDJ.events:RegisterEvent("PLAYER_ENTERING_WORLD")
FDJ.events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
FDJ.events:RegisterEvent("QUEST_LOG_UPDATE")
FDJ.events:RegisterEvent("QUEST_TURNED_IN")
FDJ.events:RegisterEvent("QUEST_ACCEPTED")
FDJ.events:RegisterEvent("QUEST_REMOVED")
FDJ.events:RegisterEvent("QUEST_DATA_LOAD_RESULT")
FDJ.events:RegisterEvent("PLAYER_LEVEL_UP")
pcall(FDJ.events.RegisterEvent, FDJ.events, "BAG_UPDATE_DELAYED") -- itemsteps: punch card ticks
FDJ.events:RegisterEvent("GET_ITEM_INFO_RECEIVED")

-- Coalesce event bursts and refresh on the next frame, outside API callbacks.
FDJ.questRefreshPending = false
FDJ.questRefreshWorker = FDJ.questRefreshWorker or CreateFrame("Frame")
FDJ.questRefreshWorker:Hide()
function FDJ.ScheduleQuestRefresh()
    if FDJ.questRefreshPending then return end
    FDJ.questRefreshPending = true
    FDJ.questRefreshWorker:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        self:Hide()
        FDJ.questRefreshPending = false
        if frame and frame:IsShown() then
            if frame.currentView == "home" then
                RefreshHomeDungeonCards()
            elseif selectedMode == "quests" then
                RefreshQuestList()
                RefreshQuestDetail()
            end
        end
    end)
    FDJ.questRefreshWorker:Show()
end

-- rpgpartial: something revealed (RPG Mode): redraw the open page.
function FDJ.RefreshRPGPage()
    if not frame or not frame:IsShown() or frame.currentView == "home" then return end
    if not selectedDungeon or not DB[selectedDungeon] then return end
    if FDJ.IsDungeonLocked and FDJ.IsDungeonLocked(selectedDungeon) then return end
    UpdateModeTabs()
    if selectedMode == "quests" then
        RefreshQuestList()
        RefreshQuestDetail()
    else
        RefreshBossList()
        RefreshLoot()
    end
end

FDJ.events:SetScript("OnEvent", function(_, event, arg1, arg2)
    local questID, success = arg1, arg2
    if event == "PLAYER_LOGIN" then
        -- SavedVariables load after this file runs, so the display-ID cache
        -- captured at load time was a throwaway table. Rebind it to the real
        -- saved table so resolved portraits persist between sessions.
        -- portraitwipe (2.0.13, M 19 Nov 2026: Mithera's arrow still with
        -- Magister Kirandis's face): the wipe at the top of this file runs on
        -- the table made before the saved one loads; the saved pictures are
        -- wiped here, once (version 3), and learned again.
        -- (4, 2.0.13: Dorn Plainstalker with an undead face: once more, after
        -- the arrow's lookups were made safe, arrowsafe in Systems/MapMarkers.lua)
        if ForeverDungeonJournalDB.portraitCacheVersion ~= 4 then
            ForeverDungeonJournalDB.displayIDs = {}
            ForeverDungeonJournalDB.portraitCacheVersion = 4
            if FDJ.arrowDisplayIDs then for k in pairs(FDJ.arrowDisplayIDs) do FDJ.arrowDisplayIDs[k] = nil end end
        end
        ForeverDungeonJournalDB.displayIDs = ForeverDungeonJournalDB.displayIDs or {}
        if displayIDCache ~= ForeverDungeonJournalDB.displayIDs then
            for k, v in pairs(displayIDCache) do
                if ForeverDungeonJournalDB.displayIDs[k] == nil then ForeverDungeonJournalDB.displayIDs[k] = v end
            end
            displayIDCache = ForeverDungeonJournalDB.displayIDs
        end
        if UnitFactionGroup then
            local playerFaction = UnitFactionGroup("player")
            if playerFaction == "Horde" then
                selectedQuestFaction = "Horde"
            elseif playerFaction == "Alliance" then
                selectedQuestFaction = "Alliance"
            end
            ForeverDungeonJournalDB.questFaction = selectedQuestFaction
        end

        ScanEncounterJournal()
        CreateItemTooltip()
        CreateMainFrame()
        FDJ.CreateMinimap()

        -- Boss portraits use journal data or numeric NPC-ID display resolution; no live unit-string parsing.

        RefreshAll()

        local addonVersion
        if C_AddOns and C_AddOns.GetAddOnMetadata then
            addonVersion = C_AddOns.GetAddOnMetadata("ForeverDungeonJournal", "Version")
        elseif GetAddOnMetadata then
            addonVersion = GetAddOnMetadata("ForeverDungeonJournal", "Version")
        end
        addonVersion = (addonVersion and tostring(addonVersion)) or "2.0.9"
        print("|cffd8a83cDungeon Journal by Exehn|r |cffffffffv" .. addonVersion .. "|r")
        return
    end

    if event == "PLAYER_LEAVING_WORLD" then
        -- No portrait work during zoning: the warm-up and the lookups wait.
        FDJ.portraitZoning = true
        FDJ.portraitZoneSerial = (FDJ.portraitZoneSerial or 0) + 1
        -- loadpause (2.0.7): every server lookup waits until after arriving.
        FDJ.lookupsResumeAt = math.huge
        for _, pause in ipairs({ FDJ.PausePortraitLookup, FDJ.PauseMobLooks, FDJ.PauseArrowLookup }) do
            if type(pause) == "function" then pcall(pause) end
        end
        return
    end

    if event == "QUEST_DATA_LOAD_RESULT" then
        if not questDataRequests[questID] then return end
        questDataRequests[questID] = success == false
            and {state = "failed", retryAt = (GetTime and GetTime() or 0) + 30}
            or {state = "loaded"}
        FDJ.ScheduleQuestRefresh()
        return
    end

    if event == "GET_ITEM_INFO_RECEIVED" then
        if itemTooltipQualityCache and questID then
            itemTooltipQualityCache[questID] = nil
        end
        -- An item the server does not know: nothing new to show (and asking
        -- again would only bring the same answer back).
        if success == false then return end
        if FDJ.SearchItemArrived then FDJ.SearchItemArrived(questID) end
        -- searchlag: item data arrives in bursts (a search or a loot page can
        -- ask for hundreds of items at once). Redraw once per burst, a moment
        -- after it starts, instead of once per item.
        if not (frame and frame:IsShown()) or FDJ.itemRedrawPending then return end
        FDJ.itemRedrawPending = true
        local function Redraw()
            FDJ.itemRedrawPending = nil
            if not (frame and frame:IsShown()) then return end
            if selectedMode == "bosses" then
                RefreshLoot()
            elseif selectedMode == "quests" then
                RefreshQuestDetail()
                ApplyLocaleFontTree(frame)
            end
            -- Forever custom-item metadata may become available after the
            -- search dropdown was already built. Refresh it in-place so names
            -- and icons update without making the player retype the query.
            if frame.RefreshSearchResults and frame.searchEditBox
                and frame.searchResultsFrame and frame.searchResultsFrame:IsShown() then
                frame.RefreshSearchResults(frame.searchEditBox:GetText() or "", true)
            end
        end
        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(0.25, function() pcall(Redraw) end)
        else
            Redraw()
        end
        return
    end

    if event == "QUEST_LOG_UPDATE"
        or event == "QUEST_TURNED_IN"
        or event == "QUEST_ACCEPTED"
        or event == "QUEST_REMOVED"
        or event == "PLAYER_LEVEL_UP"
        or event == "BAG_UPDATE_DELAYED"
    then
        FDJ.ScheduleQuestRefresh()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        -- loadpause (2.0.7): the server lookups go on a few seconds from now.
        FDJ.lookupsResumeAt = (GetTime and GetTime() or 0) + (FDJ.LOOKUP_RESUME_DELAY or 5)
        -- Keep the loading transition clean: no hidden tooltip scans and no
        -- model work synchronously on PLAYER_ENTERING_WORLD. Select the
        -- current dungeon immediately, but refresh visible UI only after the
        -- world has settled.
        local current = CurrentDungeon()
        if current and DB[current] then
            selectedDungeon = current
            ForeverDungeonJournalDB.lastDungeon = current
            if selectedBoss > #DB[current].bosses then
                selectedBoss = 1
                ForeverDungeonJournalDB.lastBoss = 1
            end
        end

        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(2.25, function()
                if frame and frame:IsShown() then
                    RefreshAll()
                end
            end)
            -- Portrait work resumes once the world has settled; the first
            -- time, the warm-up starts a few seconds later.
            local serial = FDJ.portraitZoneSerial
            C_Timer.After(2, function()
                if FDJ.portraitZoneSerial ~= serial then return end
                FDJ.portraitZoning = false
                if portraitResolver and #portraitResolveQueue > 0 then portraitResolver:Show() end
            end)
            if not FDJ.portraitsPrewarmed then
                C_Timer.After(6, function()
                    if FDJ.PrewarmBossPortraits then pcall(FDJ.PrewarmBossPortraits) end
                end)
            end
        end
        return
    end

    local current = CurrentDungeon()

    if current and DB[current] then
        selectedDungeon = current
        ForeverDungeonJournalDB.lastDungeon = current

        if selectedBoss > #DB[current].bosses then
            selectedBoss = 1
            ForeverDungeonJournalDB.lastBoss = 1
        end

        if frame and frame:IsShown() then
            RefreshAll()
        end
    end
end)
