---@class MopNpcFixes
local MopNpcFixes = QuestieLoader:CreateModule("MopNpcFixes")

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type Phasing
local Phasing = QuestieLoader:ImportModule("Phasing")

function MopNpcFixes.Load()
  -- Static body stripped at package time (tools/distribution/strip-static.lua): this correction is
  -- already folded into the TOC metadata store. The repository copy keeps the full body.
  return {}
end

function MopNpcFixes:LoadFactionFixes()
    local npcKeys = QuestieDB.npcKeys
    local zoneIDs = ZoneDB.zoneIDs

    local npcFixesHorde = {
        [15898] = { -- Lunar Festival Vendor
            [npcKeys.spawns] = {
                [zoneIDs.THUNDER_BLUFF] = {{70.56,27.83}},
                [zoneIDs.UNDERCITY] = {{66.45,36.02}},
                [zoneIDs.MOONGLADE] = {{36.58,58.1},{36.3,58.53}},
                [zoneIDs.SHATTRATH_CITY] = {{52.63,33.25},{48.64,36.29}},
                [zoneIDs.SILVERMOON_CITY] = {{73.41,82.17}},
                [zoneIDs.DALARAN] = {{47.93,43.32}},
                [zoneIDs.VALE_OF_ETERNAL_BLOSSOMS] = {{63.34,19.37}},
            },
        },
        [59151] = { -- Zhu's Watch Courier
            [npcKeys.spawns] = {[zoneIDs.KRASARANG_WILDS] = {{62.56, 25.46}}},
        },
        [65716] = { -- Mishi
            [npcKeys.spawns] = {[zoneIDs.VALE_OF_ETERNAL_BLOSSOMS] = {{62.02, 24.15}}},
        },
        [67438] = { -- Krasari Elder
            [npcKeys.spawns] = {[zoneIDs.KRASARANG_WILDS] = {{12.64, 62.37}}},
            [npcKeys.zoneID] = zoneIDs.KRASARANG_WILDS,
            [npcKeys.questStarts] = {32168},
        },
        [70297] = { -- Taoshi
            [npcKeys.spawns] = {[zoneIDs.ISLE_OF_THUNDER] = {{32.8, 32.6}}},
        },
        [70616] = { -- Mingus Diggs
            [npcKeys.spawns] = {[zoneIDs.BRAWLGAR_ARENA] = {{51.7,49.8},{-1,-1}}},
        },
        [70647] = { -- Dippy
            [npcKeys.spawns] = {[zoneIDs.BRAWLGAR_ARENA] = {{51.7,49.8},{-1,-1}}},
        },
        [70648] = { -- Doopy
            [npcKeys.spawns] = {[zoneIDs.BRAWLGAR_ARENA] = {{51.7,49.8},{-1,-1}}},
        },
        [70666] = { -- Ty'thar
            [npcKeys.spawns] = {[zoneIDs.BRAWLGAR_ARENA] = {{51.7,49.8},{-1,-1}}},
        },
        [70677] = { -- Master Boom Boom
            [npcKeys.spawns] = {[zoneIDs.BRAWLGAR_ARENA] = {{51.7,49.8},{-1,-1}}},
        },
        [70678] = { -- Grandpa Grumplefloot
            [npcKeys.spawns] = {[zoneIDs.BRAWLGAR_ARENA] = {{51.7,49.8},{-1,-1}}},
        },
        [70736] = { -- Splat
            [npcKeys.spawns] = {[zoneIDs.BRAWLGAR_ARENA] = {{51.7,49.8},{-1,-1}}},
        },
        [70737] = { -- Splat
            [npcKeys.spawns] = {[zoneIDs.BRAWLGAR_ARENA] = {{51.7,49.8},{-1,-1}}},
        },
        [70740] = { -- Blingtron 3000
            [npcKeys.spawns] = {[zoneIDs.BRAWLGAR_ARENA] = {{51.7,49.8},{-1,-1}}},
        },
        [70748] = { -- Argh
            [npcKeys.spawns] = {[zoneIDs.BRAWLGAR_ARENA] = {{51.7,49.8},{-1,-1}}},
        },
        [70749] = { -- Ro-Shambo
            [npcKeys.spawns] = {[zoneIDs.BRAWLGAR_ARENA] = {{51.7,49.8},{-1,-1}}},
        },
        [70794] = { -- Blind Hero
            [npcKeys.spawns] = {[zoneIDs.BRAWLGAR_ARENA] = {{51.7,49.8},{-1,-1}}},
        },
        [71081] = { -- Mecha-Bruce
            [npcKeys.spawns] = {[zoneIDs.BRAWLGAR_ARENA] = {{51.7,49.8},{-1,-1}}},
        },
        [71085] = { -- Razorgrin
            [npcKeys.spawns] = {[zoneIDs.BRAWLGAR_ARENA] = {{51.7,49.8},{-1,-1}}},
        },
    }

    local npcFixesAlliance = {
        [15898] = { -- Lunar Festival Vendor
            [npcKeys.spawns] = {
                [zoneIDs.ELWYNN_FOREST] = {{34.81,50.33}},
                [zoneIDs.IRONFORGE] = {{29.92,14.21}},
                [zoneIDs.DARNASSUS] = {{39.93,30.82}},
                [zoneIDs.MOONGLADE] = {{36.58,58.1},{36.3,58.53}},
                [zoneIDs.SHATTRATH_CITY] = {{52.63,33.25},{48.64,36.29}},
                [zoneIDs.THE_EXODAR] = {{74.02,58.23}},
                [zoneIDs.DALARAN] = {{47.93,43.32}},
                [zoneIDs.VALE_OF_ETERNAL_BLOSSOMS] = {{84.91,65.09}},
            },
        },
        [59151] = { -- Zhu's Watch Courier
            [npcKeys.spawns] = {[zoneIDs.KRASARANG_WILDS] = {{66.2, 30.8}}},
        },
        [65716] = { -- Mishi
            [npcKeys.spawns] = {[zoneIDs.VALE_OF_ETERNAL_BLOSSOMS] = {{84.93, 59.95}}},
        },
        [67438] = { -- Krasari Elder
            [npcKeys.spawns] = {[zoneIDs.KRASARANG_WILDS] = {{13.94, 41.19}}},
            [npcKeys.zoneID] = zoneIDs.KRASARANG_WILDS,
            [npcKeys.questStarts] = {32185},
        },
        [70297] = { -- Taoshi
            [npcKeys.spawns] = {[zoneIDs.ISLE_OF_THUNDER] = {{63.2, 73.8}}},
        },
        [70616] = { -- Mingus Diggs
            [npcKeys.spawns] = {[zoneIDs.BIZMOS_BRAWLPUB] = {{50.7,57.2},{-1,-1}}},
        },
        [70647] = { -- Dippy
            [npcKeys.spawns] = {[zoneIDs.BIZMOS_BRAWLPUB] = {{50.7,57.2},{-1,-1}}},
        },
        [70648] = { -- Doopy
            [npcKeys.spawns] = {[zoneIDs.BIZMOS_BRAWLPUB] = {{50.7,57.2},{-1,-1}}},
        },
        [70666] = { -- Ty'thar
            [npcKeys.spawns] = {[zoneIDs.BIZMOS_BRAWLPUB] = {{50.7,57.2},{-1,-1}}},
        },
        [70677] = { -- Master Boom Boom
            [npcKeys.spawns] = {[zoneIDs.BIZMOS_BRAWLPUB] = {{50.7,57.2},{-1,-1}}},
        },
        [70678] = { -- Grandpa Grumplefloot
            [npcKeys.spawns] = {[zoneIDs.BIZMOS_BRAWLPUB] = {{50.7,57.2},{-1,-1}}},
        },
        [70736] = { -- Splat
            [npcKeys.spawns] = {[zoneIDs.BIZMOS_BRAWLPUB] = {{50.7,57.2},{-1,-1}}},
        },
        [70737] = { -- Splat
            [npcKeys.spawns] = {[zoneIDs.BIZMOS_BRAWLPUB] = {{50.7,57.2},{-1,-1}}},
        },
        [70740] = { -- Blingtron 3000
            [npcKeys.spawns] = {[zoneIDs.BIZMOS_BRAWLPUB] = {{50.7,57.2},{-1,-1}}},
        },
        [70748] = { -- Argh
            [npcKeys.spawns] = {[zoneIDs.BIZMOS_BRAWLPUB] = {{50.7,57.2},{-1,-1}}},
        },
        [70749] = { -- Ro-Shambo
            [npcKeys.spawns] = {[zoneIDs.BIZMOS_BRAWLPUB] = {{50.7,57.2},{-1,-1}}},
        },
        [70794] = { -- Blind Hero
            [npcKeys.spawns] = {[zoneIDs.BIZMOS_BRAWLPUB] = {{50.7,57.2},{-1,-1}}},
        },
        [71081] = { -- Mecha-Bruce
            [npcKeys.spawns] = {[zoneIDs.BIZMOS_BRAWLPUB] = {{50.7,57.2},{-1,-1}}},
        },
        [71085] = { -- Razorgrin
            [npcKeys.spawns] = {[zoneIDs.BIZMOS_BRAWLPUB] = {{50.7,57.2},{-1,-1}}},
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return npcFixesHorde
    else
        return npcFixesAlliance
    end
end
