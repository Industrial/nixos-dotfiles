local addonName, PVPSC = ...

PVPSC.AchievementSystem = PVPSC.AchievementSystem or {}
local AchievementSystem = PVPSC.AchievementSystem

AchievementSystem.achievementsTbc = {
    -- =====================================================
    -- HELLFIRE PENINSULA ACHIEVEMENTS
    -- =====================================================
    {
        id = "zone_hellfire_100",
        title = "Hellfire Initiate",
        description = function(a) return ("Eliminate %d players in Hellfire Peninsula"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236778",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Hellfire Peninsula! You've turned the gateway to Outland into a proper slaughterhouse. The Dark Portal's loading screen should include a warning about you.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Hellfire Peninsula")
        end,
    },
    {
        id = "zone_hellfire_250",
        title = "Hellfire Harbinger",
        description = function(a) return ("Eliminate %d players in Hellfire Peninsula"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236778",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses littering the shattered landscape, Hellfire Peninsula lives up to its name. Both Honor Hold and Thrallmar are considering hiring you as their new defense system.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Hellfire Peninsula")
        end,
    },
    {
        id = "zone_hellfire_500",
        title = "Hellfire Devastator",
        description = function(a) return ("Eliminate %d players in Hellfire Peninsula"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236778",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d players learned the hard way that Hellfire Peninsula wasn't the worst thing about Outland—you were. The fel reavers are taking notes on your hunting techniques.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Hellfire Peninsula")
        end,
    },
    {
        id = "zone_hellfire_1000",
        title = "Hellfire Legend",
        description = function(a) return ("Eliminate %d players in Hellfire Peninsula"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236778",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Hellfire Peninsula! You are the true terror of Outland's gateway. Freshly arrived players see your name and consider unsubscribing. Even Illidan is impressed.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Hellfire Peninsula")
        end,
    },

    -- =====================================================
    -- ZANGARMARSH ACHIEVEMENTS
    -- =====================================================
    {
        id = "zone_zangarmarsh_100",
        title = "Marsh Menace",
        description = function(a) return ("Eliminate %d players in Zangarmarsh"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236855",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Zangarmarsh! The sporelings are starting a support group for traumatized players. The mushrooms have seen things they can't unsee.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Zangarmarsh")
        end,
    },
    {
        id = "zone_zangarmarsh_250",
        title = "Swamp Slayer",
        description = function(a) return ("Eliminate %d players in Zangarmarsh"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236855",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d bodies sinking into the marsh, the Cenarion Expedition is concerned about the local ecosystem. Turns out, corpses make terrible compost.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Zangarmarsh")
        end,
    },
    {
        id = "zone_zangarmarsh_500",
        title = "Fungal Fury",
        description = function(a) return ("Eliminate %d players in Zangarmarsh"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236855",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d players discovered that Zangarmarsh's biggest threat isn't the naga—it's you. The marsh gas has nothing on your toxic presence.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Zangarmarsh")
        end,
    },
    {
        id = "zone_zangarmarsh_1000",
        title = "Lord of the Marsh",
        description = function(a) return ("Eliminate %d players in Zangarmarsh"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236855",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Zangarmarsh! You've claimed this swamp as your personal hunting ground. Lady Vashj watches your kill count with professional jealousy.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Zangarmarsh")
        end,
    },

    -- =====================================================
    -- TEROKKAR FOREST ACHIEVEMENTS
    -- =====================================================
    {
        id = "zone_terokkar_100",
        title = "Terokkar Terror",
        description = function(a) return ("Eliminate %d players in Terokkar Forest"):format(a.targetValue) end,
        iconID = 464820,
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Terokkar Forest! The arakkoa consider you more dangerous than the Shadow Council. Shattrath is putting up wanted posters.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Terokkar Forest")
        end,
    },
    {
        id = "zone_terokkar_250",
        title = "Forest Fiend",
        description = function(a) return ("Eliminate %d players in Terokkar Forest"):format(a.targetValue) end,
        iconID = 464820,
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses beneath the bone wastes, Terokkar Forest has a new apex predator. Auchindoun's death toll is now split between the undead and you.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Terokkar Forest")
        end,
    },
    {
        id = "zone_terokkar_500",
        title = "Shadow Sovereign",
        description = function(a) return ("Eliminate %d players in Terokkar Forest"):format(a.targetValue) end,
        iconID = 464820,
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d players fell in Terokkar Forest. The bone wastes are living up to their name, and you're the reason why. Even the spirits of Auchindoun fear you.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Terokkar Forest")
        end,
    },
    {
        id = "zone_terokkar_1000",
        title = "Terokkar Tyrant",
        description = function(a) return ("Eliminate %d players in Terokkar Forest"):format(a.targetValue) end,
        iconID = 464820,
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Terokkar Forest! You've made this zone your personal killing field. Players avoid Terokkar like the plague—because you ARE the plague.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Terokkar Forest")
        end,
    },

    -- =====================================================
    -- NAGRAND ACHIEVEMENTS
    -- =====================================================
    {
        id = "zone_nagrand_100",
        title = "Nagrand Nomad",
        description = function(a) return ("Eliminate %d players in Nagrand"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236810",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Nagrand! The floating islands aren't the only thing that's breathtaking—so is your body count. Halaa has declared you persona non grata.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Nagrand")
        end,
    },
    {
        id = "zone_nagrand_250",
        title = "Plains Predator",
        description = function(a) return ("Eliminate %d players in Nagrand"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236810",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses scattered across the pristine plains, Nagrand's beauty is marred only by your kill count. The local wildlife considers you competition.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Nagrand")
        end,
    },
    {
        id = "zone_nagrand_500",
        title = "Warlord of Nagrand",
        description = function(a) return ("Eliminate %d players in Nagrand"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236810",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d players discovered that Nagrand's Ring of Blood is child's play compared to facing you. Even the clefthoofs are impressed by your brutality.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Nagrand")
        end,
    },
    {
        id = "zone_nagrand_1000",
        title = "Scourge of Nagrand",
        description = function(a) return ("Eliminate %d players in Nagrand"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236810",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Nagrand! You've turned paradise into a personal warzone. The Mag'har are considering adding you to their ancestral legends—as a cautionary tale.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Nagrand")
        end,
    },

    -- =====================================================
    -- BLADE'S EDGE MOUNTAINS ACHIEVEMENTS
    -- =====================================================
    {
        id = "zone_bladesedge_100",
        title = "Mountain Marauder",
        description = function(a) return ("Eliminate %d players in Blade's Edge Mountains"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236719",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Blade's Edge Mountains! The ogres are taking notes on your combat techniques. Gruul's sons think you'd make a great addition to the family.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Blade's Edge Mountains")
        end,
    },
    {
        id = "zone_bladesedge_250",
        title = "Craggy Killer",
        description = function(a) return ("Eliminate %d players in Blade's Edge Mountains"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236719",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses tumbling down the cliffs, Blade's Edge Mountains lives up to its name. Players are more afraid of you than falling off the edge.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Blade's Edge Mountains")
        end,
    },
    {
        id = "zone_bladesedge_500",
        title = "Peak Predator",
        description = function(a) return ("Eliminate %d players in Blade's Edge Mountains"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236719",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d players learned that the mountains aren't the deadliest thing with an edge—you are. The Fel Reavers are jealous of your kill efficiency.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Blade's Edge Mountains")
        end,
    },
    {
        id = "zone_bladesedge_1000",
        title = "King of the Crags",
        description = function(a) return ("Eliminate %d players in Blade's Edge Mountains"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236719",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Blade's Edge Mountains! You've conquered the peaks with blood and bodies. Even Gruul bows to your supremacy. Players whisper your name in fear.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Blade's Edge Mountains")
        end,
    },

    -- =====================================================
    -- NETHERSTORM ACHIEVEMENTS
    -- =====================================================
    {
        id = "zone_netherstorm_100",
        title = "Storm Stalker",
        description = function(a) return ("Eliminate %d players in Netherstorm"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236811",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Netherstorm! The ethereals are fascinated by your efficiency. Kael'thas is taking notes on your world-domination techniques.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Netherstorm")
        end,
    },
    {
        id = "zone_netherstorm_250",
        title = "Mana Forge Menace",
        description = function(a) return ("Eliminate %d players in Netherstorm"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236811",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses floating in the Nether, Netherstorm's energy crisis pales compared to your killing spree. Area 52's goblins want to weaponize you.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Netherstorm")
        end,
    },
    {
        id = "zone_netherstorm_500",
        title = "Tempest Tyrant",
        description = function(a) return ("Eliminate %d players in Netherstorm"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236811",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d players discovered that Netherstorm's arcane anomalies are nothing compared to the anomaly that is your kill count. Even the voidwalkers are impressed.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Netherstorm")
        end,
    },
    {
        id = "zone_netherstorm_1000",
        title = "Ethereal Executioner",
        description = function(a) return ("Eliminate %d players in Netherstorm"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236811",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Netherstorm! You've become the zone's greatest threat. The Burning Legion wants to recruit you. Tempest Keep was merely a setback—you're the real endgame.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Netherstorm")
        end,
    },

    -- =====================================================
    -- SHADOWMOON VALLEY ACHIEVEMENTS
    -- =====================================================
    {
        id = "zone_shadowmoon_100",
        title = "Shadowmoon Slayer",
        description = function(a) return ("Eliminate %d players in Shadowmoon Valley"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236816",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Shadowmoon Valley! Even the Black Temple's demons are impressed. Illidan looks out from his throne and nods in approval.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Shadowmoon Valley")
        end,
    },
    {
        id = "zone_shadowmoon_250",
        title = "Dark Reaper",
        description = function(a) return ("Eliminate %d players in Shadowmoon Valley"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236816",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses in the shadow of the Black Temple, you've become the valley's true terror. Illidan's forces offer you a job application.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Shadowmoon Valley")
        end,
    },
    {
        id = "zone_shadowmoon_500",
        title = "Valley Vanquisher",
        description = function(a) return ("Eliminate %d players in Shadowmoon Valley"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236816",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d players fell in Shadowmoon Valley. The Burning Legion considers you an honorary member. You are NOT prepared—but they certainly weren't either.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Shadowmoon Valley")
        end,
    },
    {
        id = "zone_shadowmoon_1000",
        title = "Betrayer's Heir",
        description = function(a) return ("Eliminate %d players in Shadowmoon Valley"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236816",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Shadowmoon Valley! Illidan himself is jealous of your body count. You've proven that you ARE prepared—prepared to slaughter everyone. The Black Temple should be renamed after you.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Shadowmoon Valley")
        end,
    },

    -- =====================================================
    -- EVERSONG WOODS (Blood Elf Starting Zone)
    -- =====================================================
    {
        id = "zone_alliance_eversong_100",
        title = "Eversong Eliminator",
        description = function(a) return ("Eliminate %d Blood Elves in Eversong Woods"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236762",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Blood Elves discovered that their pristine forests aren't so safe. Silvermoon's recruitment office is working overtime replacing the losses you've caused.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Eversong Woods")
        end,
    },
    {
        id = "zone_alliance_eversong_250",
        title = "Springtime Slaughter",
        description = function(a) return ("Eliminate %d Blood Elves in Eversong Woods"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236762",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses among the golden leaves, Eversong Woods is losing its luster. The Sunwell might have been restored, but Blood Elf morale is at an all-time low.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Eversong Woods")
        end,
    },

    -- =====================================================
    -- GHOSTLANDS (Blood Elf Zone)
    -- =====================================================
    {
        id = "zone_alliance_ghostlands_100",
        title = "Ghostlands Ghoul",
        description = function(a) return ("Eliminate %d Blood Elves in Ghostlands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236762",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Ghostlands! The undead Scourge have competition. Players are starting to think YOU'RE the real threat to Tranquillien.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Ghostlands")
        end,
    },
    {
        id = "zone_alliance_ghostlands_250",
        title = "Phantom Menace",
        description = function(a) return ("Eliminate %d Blood Elves in Ghostlands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236762",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses in Ghostlands, you're adding to the zone's undead population. Dar'Khan Drathir is taking notes on your killing techniques.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Ghostlands")
        end,
    },

    -- =====================================================
    -- AZUREMYST ISLE (Draenei Starting Zone)
    -- =====================================================
    {
        id = "zone_horde_azuremyst_100",
        title = "Azure Assassin",
        description = function(a) return ("Eliminate %d Draenei in Azuremyst Isle"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236715",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Draenei discovered that crashing their ship was only the beginning of their problems. You've made them regret ever finding Azeroth.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Azuremyst Isle")
        end,
    },
    {
        id = "zone_horde_azuremyst_250",
        title = "Crashed Party",
        description = function(a) return ("Eliminate %d Draenei in Azuremyst Isle"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236715",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses among the wreckage, Azuremyst Isle's recovery efforts are hampered more by you than the actual crash. The Exodar's priests work overtime on resurrections.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Azuremyst Isle")
        end,
    },

    -- =====================================================
    -- BLOODMYST ISLE (Draenei Zone)
    -- =====================================================
    {
        id = "zone_horde_bloodmyst_100",
        title = "Bloodmyst Butcher",
        description = function(a) return ("Eliminate %d Draenei in Bloodmyst Isle"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236715",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Bloodmyst Isle! The zone's name was prophetic. The Draenei thought the blood myst was bad—then they met you.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Bloodmyst Isle")
        end,
    },
    {
        id = "zone_horde_bloodmyst_250",
        title = "Crimson Killer",
        description = function(a) return ("Eliminate %d Draenei in Bloodmyst Isle"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236715",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses on Bloodmyst Isle, you're living up to the zone's name better than the pollution. The satyr and naga are taking notes on your efficiency.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Bloodmyst Isle")
        end,
    },

    -- =====================================================
    -- TBC ALL CLASSES ACHIEVEMENTS
    -- =====================================================
    {
        id = "class_mixed_all_nine_100_tbc",
        title = "Class Warfare Initiate (TBC)",
        description = function(a) return ("Execute %d of each class (incl. Paladin and Shaman)"):format(a.targetValue) end,
        iconID = 464820,
        achievementPoints = 75,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Perfect class extermination achieved. %d deaths per class - including both Paladins and Shamans. The Burning Crusade brought class balance... you brought class extinction.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForAchievementWithAllClasses(stats, PSC_GAME_VERSIONS.TBC)
        end,
    },
    {
        id = "class_mixed_all_nine_250_tbc",
        title = "Professional Exterminator (TBC)",
        description = function(a) return ("Execute %d of each class (incl. Paladin and Shaman)"):format(a.targetValue) end,
        iconID = 464820,
        achievementPoints = 125,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("All nine classes equally decimated. %d corpses per profession. Your methodical approach covers every class in the game - no exceptions, no mercy.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForAchievementWithAllClasses(stats, PSC_GAME_VERSIONS.TBC)
        end,
    },
    {
        id = "class_mixed_all_nine_500_tbc",
        title = "Class Genocide Specialist (TBC)",
        description = function(a) return ("Execute %d of each class (incl. Paladin and Shaman)"):format(a.targetValue) end,
        iconID = 464820,
        achievementPoints = 125,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Systematic class annihilation complete. %d deaths per class. Warriors, Paladins, Shamans, and every other class - all reduced to perfect statistical equality in death.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForAchievementWithAllClasses(stats, PSC_GAME_VERSIONS.TBC)
        end,
    },
    {
        id = "class_mixed_all_nine_1000_tbc",
        title = "The Great Leveler (TBC)",
        description = function(a) return ("Execute %d of each class (incl. Paladin and Shaman)"):format(a.targetValue) end,
        iconID = 464820,
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Ultimate class extinction achieved. %d corpses per class. You've mastered the art of killing all nine classes with equal proficiency. Paladins and Shamans learned they're not special.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForAchievementWithAllClasses(stats, PSC_GAME_VERSIONS.TBC)
        end,
    },

    -- =====================================================
    -- BLOOD ELF RACE ACHIEVEMENTS (For Alliance)
    -- =====================================================
    {
        id = "race_bloodelf_0",
        title = "Elf Extinction Enthusiast",
        description = function(a) return ("Eliminate %d Blood Elves"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236439",
        achievementPoints = 10,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Blood Elves down! These fashion-obsessed pretty boys joined the Horde thinking it would make them look 'edgy.' Turns out corpses all look the same regardless of how many hours they spent in character creation.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Blood Elf"] or 0
        end,
    },
    {
        id = "race_bloodelf_1",
        title = "No More Mana Tap",
        description = function(a) return ("Eliminate %d Blood Elves"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236439",
        achievementPoints = 25,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Blood Elves eliminated! Half rolled female characters with names like 'Legolàs' or 'Séphiroth,' the other half were actual females who wanted to play the 'hot race.' Their Mana Tap racial couldn't save them from your beatdown.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Blood Elf"] or 0
        end,
    },
    {
        id = "race_bloodelf_2",
        title = "Silvermoon Sanitation Service",
        description = function(a) return ("Eliminate %d Blood Elves"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236440",
        achievementPoints = 50,
        targetValue = 2000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Blood Elves permanently deleted! These addiction-riddled magic junkies thought joining the Horde would help them kick their mana habit. The only thing they kicked was the bucket. Kael'thas would be disappointed, but he's too busy being a raid boss to care.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Blood Elf"] or 0
        end,
    },
    {
        id = "race_bloodelf_3",
        title = "The Beautiful Corpse Collector",
        description = function(a) return ("Eliminate %d Blood Elves"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236440",
        achievementPoints = 100,
        targetValue = 4000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Blood Elves sent to the graveyard! These pompous, narcissistic elves spent more time adjusting their hair than their keybinds. They betrayed the Alliance, abandoned their heritage, and became mana-addicted traitors - and you've made them pay for every single mistake. Their perfect cheekbones look a lot less impressive when they're six feet under. The Sunwell burned once - you're the inferno that keeps on giving.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Blood Elf"] or 0
        end,
    },

    -- =====================================================
    -- DRAENEI RACE ACHIEVEMENTS (For Horde)
    -- =====================================================
    {
        id = "race_draenei_0",
        title = "Space Goat Butcher",
        description = function(a) return ("Eliminate %d Draenei"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236441",
        achievementPoints = 10,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Draenei eliminated! These sparkly space goats traveled across dimensions just to die to you. Their Gift of the Naaru couldn't heal them from your righteous beatdown. Prophet Velen saw this coming but didn't warn them.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Draenei"] or 0
        end,
    },
    {
        id = "race_draenei_1",
        title = "Dimensional Disaster",
        description = function(a) return ("Eliminate %d Draenei"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236441",
        achievementPoints = 25,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Draenei sent back to the nether! These holier-than-thou space hippies joined the Alliance thinking the Light would protect them. Turns out, the Light takes coffee breaks. Their tentacle beards couldn't save them from getting ganked.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Draenei"] or 0
        end,
    },
    {
        id = "race_draenei_2",
        title = "Prophet's Nightmare",
        description = function(a) return ("Eliminate %d Draenei"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236441",
        achievementPoints = 50,
        targetValue = 2000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Draenei permanently grounded! They crashed their spaceship on Azeroth, and now you're crashing their hopes and dreams. The Burning Legion chased them across the universe - you finished the job. Velen's visions of the future now exclusively feature your face.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Draenei"] or 0
        end,
    },
    {
        id = "race_draenei_3",
        title = "Exodar Express to the Graveyard",
        description = function(a) return ("Eliminate %d Draenei"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236441",
        achievementPoints = 100,
        targetValue = 4000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Draenei deleted from existence! These interdimensional refugees fled the Burning Legion, survived the destruction of Draenor, crash-landed on Azeroth, and joined the Alliance - only to become your personal farming simulator. Their Gift of the Naaru is now the Gift of the Corpse Run. The Light has abandoned them, the Naaru are in therapy, and Prophet Velen is updating his resume. They should have stayed in the Nether - at least demons kill you quickly.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Draenei"] or 0
        end,
    },

    -- =====================================================
    -- TBC ALLIANCE RACE ACHIEVEMENTS (5 races: Human, Gnome, Dwarf, Night Elf, Draenei)
    -- =====================================================
    {
        id = "race_alliance_mixed_tbc_100",
        title = "Alliance Sampler Platter (TBC)",
        description = function(a) return ("Eliminate %d of each Alliance race (500 total)"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236610",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Perfect TBC Alliance genocide balance! %d Humans, %d Gnomes, %d Dwarves, %d Night Elves, and %d Draenei - truly equal opportunity slaughter! The Draenei thought fleeing across dimensions would save them. Spoiler: it didn't.")
                :format(a.targetValue, a.targetValue, a.targetValue, a.targetValue, a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForAllianceRacesTBC(stats)
        end,
    },
    {
        id = "race_alliance_mixed_tbc_250",
        title = "Alliance Census Corrector (TBC)",
        description = function(a) return ("Eliminate %d of each Alliance race (1250 total)"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236610",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("TBC Alliance extermination ratios perfected! %d kills per race including those sparkly space goats. The Draenei's dimensional ship should have kept flying - Azeroth wasn't ready for them, but you certainly were.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForAllianceRacesTBC(stats)
        end,
    },
    {
        id = "race_alliance_mixed_tbc_500",
        title = "Alliance Demographic Disaster (TBC)",
        description = function(a) return ("Eliminate %d of each Alliance race (2500 total)"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236610",
        achievementPoints = 75,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Complete TBC Alliance demographic collapse! %d deaths per race. The Draenei survived the Legion, Orcs, and interdimensional travel, only to become another statistic in your body count. Prophet Velen should have seen this coming.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForAllianceRacesTBC(stats)
        end,
    },
    {
        id = "race_alliance_mixed_tbc_1000",
        title = "Alliance Extinction Protocol (TBC)",
        description = function(a) return ("Eliminate %d of each Alliance race (5000 total)"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236610",
        achievementPoints = 100,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("LEGENDARY TBC GENOCIDE! You've eliminated %d of each Alliance race with mathematical precision. The Draenei's gift of the Light to the Alliance means nothing when you're this good at turning off their lights permanently. Five races, perfect balance, absolute devastation.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForAllianceRacesTBC(stats)
        end,
    },

    -- =====================================================
    -- TBC HORDE RACE ACHIEVEMENTS (5 races: Orc, Undead, Troll, Tauren, Blood Elf)
    -- =====================================================
    {
        id = "race_horde_mixed_tbc_100",
        title = "Horde Variety Pack (TBC)",
        description = function(a) return ("Eliminate %d of each Horde race incl. Blood Elves (500 total)"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236611",
        achievementPoints = 30,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d of each TBC Horde race eliminated. Even the pretty boy Blood Elves weren't pretty enough to escape your wrath. Equal opportunity murder across all five savage (and fabulous) races.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForHordeRacesTBC(stats)
        end,
    },
    {
        id = "race_horde_mixed_tbc_250",
        title = "Horde Population Control (TBC)",
        description = function(a) return ("Eliminate %d of each Horde race incl. Blood Elves (1250 total)"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236611",
        achievementPoints = 60,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills per TBC Horde race. The Blood Elves joined the Horde for protection - ironic how that worked out. Silvermoon's beauty is now matched by its death toll.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForHordeRacesTBC(stats)
        end,
    },
    {
        id = "race_horde_mixed_tbc_500",
        title = "Horde Demographic Crisis (TBC)",
        description = function(a) return ("Eliminate %d of each Horde race incl. Blood Elves (2500 total)"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236611",
        achievementPoints = 90,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d deaths per race. Blood Elves, Orcs, Undead, Trolls, and Tauren - all equally dead. The Horde's diversity initiative is now just a diverse collection of corpses. Thrall is reconsidering his recruitment strategy.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForHordeRacesTBC(stats)
        end,
    },
    {
        id = "race_horde_mixed_tbc_1000",
        title = "Horde Extinction Event (TBC)",
        description = function(a) return ("Eliminate %d of each Horde race incl. Blood Elves (5000 total)"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236611",
        achievementPoints = 120,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("ULTIMATE TBC HORDE ANNIHILATION! %d of each race, including those magnificent Blood Elves. Kael'thas was merely setback - you're the real catastrophe. Five Horde races, perfect kill ratios, absolute devastation. For the Alliance... or Horde... honestly, you're just in it for the body count at this point.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForHordeRacesTBC(stats)
        end,
    },

    -- =====================================================
    -- EYE OF THE STORM ACHIEVEMENTS
    -- =====================================================
    {
        id = "bg_eots_250",
        title = "Storm Chaser",
        description = function(a) return ("Defeat %d players in Eye of the Storm"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236392",
        achievementPoints = 25,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d victims caught in your storm. The floating ruins have tasted their first blood, and the Netherstorm winds carry their screams eternally."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Eye of the Storm")
        end,
    },
    {
        id = "bg_eots_500",
        title = "Tempest Incarnate",
        description = function(a) return ("Defeat %d players in Eye of the Storm"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236392",
        achievementPoints = 50,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d souls claimed amidst the ruins, you've become the tempest itself. Flag bearers flee at your approach, knowing the storm has a name: yours."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Eye of the Storm")
        end,
    },
    {
        id = "bg_eots_750",
        title = "Maelstrom's Heart",
        description = function(a) return ("Defeat %d players in Eye of the Storm"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236392",
        achievementPoints = 100,
        targetValue = 750,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d warriors have fallen from the floating platforms, their bodies lost to the Netherstorm below. You stand at the maelstrom's heart, where chaos bends to your will."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Eye of the Storm")
        end,
    },
    {
        id = "bg_eots_1000",
        title = "Eye of Annihilation",
        description = function(a) return ("Defeat %d players in Eye of the Storm"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236392",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("One thousand souls have been consumed by your endless fury. You are the Eye's true master - where others see opportunity, they now see only death. The storm itself trembles at your name."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Eye of the Storm")
        end,
    },

    -- =====================================================
    -- TBC CITY ACHIEVEMENTS - SILVERMOON CITY (For Alliance)
    -- =====================================================
    {
        id = "city_silvermoon_50",
        title = "Silvermoon Saboteur",
        description = function(a) return ("Defeat %d players in Silvermoon City"):format(a.targetValue) end,
        iconID = 135761,
        achievementPoints = 25,
        targetValue = 50,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've killed %d Blood Elves in their pristine capital. The golden streets now have a few red stains the magisters can't seem to clean away.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Silvermoon City")
        end,
    },
    {
        id = "city_silvermoon_100",
        title = "Silvermoon Desecrator",
        description = function(a) return ("Defeat %d players in Silvermoon City"):format(a.targetValue) end,
        iconID = 135761,
        achievementPoints = 50,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills in Silvermoon, Lor'themar Theron has ordered extra guards at every corner. The city's famous beauty is marred by constant bloodshed.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Silvermoon City")
        end,
    },
    {
        id = "city_silvermoon_250",
        title = "Silvermoon's Nightmare",
        description = function(a) return ("Defeat %d players in Silvermoon City"):format(a.targetValue) end,
        iconID = 135761,
        achievementPoints = 100,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d Blood Elf corpses decorating the Royal Exchange, the city's elegance has turned to paranoia. Citizens whisper that Kael'thas should have stayed in Outland - at least it's safer there.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Silvermoon City")
        end,
    },
    {
        id = "city_silvermoon_1000",
        title = "The Sunwell's Shadow",
        description = function(a) return ("Defeat %d players in Silvermoon City"):format(a.targetValue) end,
        iconID = 135761,
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After massacring %d Blood Elves in their sacred city, you are the shadow that haunts Silvermoon. The Sunwell's restoration means nothing when death walks their golden streets. Lor'themar considers evacuation plans.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Silvermoon City")
        end,
    },

    -- =====================================================
    -- TBC CITY ACHIEVEMENTS - EXODAR (For Horde)
    -- =====================================================
    {
        id = "city_exodar_50",
        title = "Exodar Invader",
        description = function(a) return ("Defeat %d players in Exodar"):format(a.targetValue) end,
        iconID = 135756,
        achievementPoints = 25,
        targetValue = 50,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've killed %d Draenei in their crashed ship. Velen's visions didn't warn him about you. The Prophet might want to recalibrate his foresight.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Exodar")
        end,
    },
    {
        id = "city_exodar_100",
        title = "Exodar Executioner",
        description = function(a) return ("Defeat %d players in Exodar"):format(a.targetValue) end,
        iconID = 135756,
        achievementPoints = 50,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills in the Exodar, the Draenei are questioning whether crashing on Azeroth was really the Light's plan. Their dimensional ship survived the Legion, but not you.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Exodar")
        end,
    },
    {
        id = "city_exodar_250",
        title = "Dimensional Destroyer",
        description = function(a) return ("Defeat %d players in Exodar"):format(a.targetValue) end,
        iconID = 135756,
        achievementPoints = 100,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d Draenei corpses cluttering their crystalline halls, the Exodar's repair efforts have been replaced with funeral services. The Light has grown dim in the face of your darkness.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Exodar")
        end,
    },
    {
        id = "city_exodar_1000",
        title = "Exodar Exterminator",
        description = function(a) return ("Defeat %d players in Exodar"):format(a.targetValue) end,
        iconID = 135756,
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After slaughtering %d Draenei in the Exodar, you've accomplished what the Burning Legion couldn't - making them regret coming to Azeroth. Prophet Velen's visions now show only your face. They fled across dimensions to escape death, only to find it waiting in you.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, "Exodar")
        end,
    },

    -- =====================================================
    -- ARENA ACHIEVEMENTS
    -- =====================================================

    -- RUINS OF LORDAERON
    {
        id = "arena_ruins_25",
        title = "Welcome to the Ruins",
        description = function(a) return ("Defeat %d players in Ruins of Lordaeron"):format(a.targetValue) end,
        iconID = 135900,
        achievementPoints = 10,
        targetValue = 25,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Ruins of Lordaeron — historic landmark, beloved tourist trap, your personal murder playground. %d down. The ghosts filed a noise complaint."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Ruins of Lordaeron")
        end,
    },
    {
        id = "arena_ruins_100",
        title = "King of the Rubble",
        description = function(a) return ("Defeat %d players in Ruins of Lordaeron"):format(a.targetValue) end,
        iconID = 135974,
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Lordaeron collapsed under the Scourge. Then it had to absorb %d of your kills on top of that. Historians are NOT okay."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Ruins of Lordaeron")
        end,
    },
    {
        id = "arena_ruins_250",
        title = "The Lich's Understudy",
        description = function(a) return ("Defeat %d players in Ruins of Lordaeron"):format(a.targetValue) end,
        iconID = 136143,
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Arthas annihilated an entire kingdom here and got a cool cutscene for it. You've racked up %d kills and don't even have a dramatic monologue. Somehow more terrifying."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Ruins of Lordaeron")
        end,
    },
    {
        id = "arena_ruins_500",
        title = "Crowned in Colleague Skulls",
        description = function(a) return ("Defeat %d players in Ruins of Lordaeron"):format(a.targetValue) end,
        iconID = 136131,
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d corpses. At this point the word 'Ruins' stopped referring to the architecture and started referring to the enemy team's rating, mental health, and desire to ever queue again."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Ruins of Lordaeron")
        end,
    },

    -- NAGRAND ARENA
    {
        id = "arena_nagrand_25",
        title = "Grassland Murderer",
        description = function(a) return ("Defeat %d players in Nagrand Arena"):format(a.targetValue) end,
        iconID = 134061,
        achievementPoints = 10,
        targetValue = 25,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Nothing but open sky, floating islands, and %d people who deeply regret queueing. Nagrand slaps. So do you, apparently."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Nagrand Arena")
        end,
    },
    {
        id = "arena_nagrand_100",
        title = "Fury of the Plains",
        description = function(a) return ("Defeat %d players in Nagrand Arena"):format(a.targetValue) end,
        iconID = 132243,
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("The spirits of Nagrand watch over this land with great wisdom. They watched you get %d kills and are now reconsidering the whole 'watching' thing."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Nagrand Arena")
        end,
    },
    {
        id = "arena_nagrand_250",
        title = "Spirits? Gone.",
        description = function(a) return ("Defeat %d players in Nagrand Arena"):format(a.targetValue) end,
        iconID = 132245,
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Sky's blue. Grass is green. %d enemies are dead. You've turned the most scenic arena in Outland into your personal crime scene. No notes. Genuinely no notes."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Nagrand Arena")
        end,
    },
    {
        id = "arena_nagrand_500",
        title = "Nagrand's Finest Export",
        description = function(a) return ("Defeat %d players in Nagrand Arena"):format(a.targetValue) end,
        iconID = 132244,
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Somewhere, a 2400-rated arena team with matching gear sets and a shared macro spreadsheet queued into Nagrand and met you. They have a Discord server now. It is called 'Coping'. %d kills and counting."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Nagrand Arena")
        end,
    },

    -- BLADE'S EDGE ARENA
    {
        id = "arena_bladesedge_25",
        title = "Spine Introductory Course",
        description = function(a) return ("Defeat %d players in Blade's Edge Arena"):format(a.targetValue) end,
        iconID = 236337,
        achievementPoints = 10,
        targetValue = 25,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Your first %d kills in the spikiest arena in Outland. Your opponents arrived nervous. They left horizontal. The spikes were just there for atmosphere — you handled the rest."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Blade's Edge Arena")
        end,
    },
    {
        id = "arena_bladesedge_100",
        title = "Edge Lord (Literal)",
        description = function(a) return ("Defeat %d players in Blade's Edge Arena"):format(a.targetValue) end,
        iconID = 236340,
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Blade's Edge: where the zone name is a warning and you are the reason. %d kills deep and the arena staff have started calling you 'sir' with the voices of people who are very scared."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Blade's Edge Arena")
        end,
    },
    {
        id = "arena_bladesedge_250",
        title = "Porcupine Energy",
        description = function(a) return ("Defeat %d players in Blade's Edge Arena"):format(a.targetValue) end,
        iconID = 236341,
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Blizzard named it Blade's Edge as a design choice. You took it as a personal challenge. %d kills later, it's less of an arena and more of a receipt."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Blade's Edge Arena")
        end,
    },
    {
        id = "arena_bladesedge_500",
        title = "Carved into the Scenery",
        description = function(a) return ("Defeat %d players in Blade's Edge Arena"):format(a.targetValue) end,
        iconID = 236343,
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in an arena named after sharp things used to hurt people. Every sweaty two-healer team that queued in here thinking they had a gameplan now logs off mid-match, stares at the ceiling, and quietly questions their build choices. You did that."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Blade's Edge Arena")
        end,
    },

    -- =====================================================
    -- BONUS ACHIEVEMENTS
    -- =====================================================
    {
        id = "bonus_outland_first_kill",
        title = "First Step into Outland",
        description = "Get your first kill in any Outland zone.",
        iconID = 255348,
        achievementPoints = 0,
        targetValue = 1,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "Welcome to Outland, champion. The legion awaits.",
        progress = function(achievement, stats)
            local outlandZones = {
                "Hellfire Peninsula",
                "Zangarmarsh",
                "Terokkar Forest",
                "Nagrand",
                "Blade's Edge Mountains",
                "Netherstorm",
                "Shadowmoon Valley"
            }

            for _, zoneName in ipairs(outlandZones) do
                if PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_TBC, zoneName) > 0 then
                    return 1
                end
            end

            return 0
        end,
    },

}

