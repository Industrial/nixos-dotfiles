local addonName, PVPSC = ...

PVPSC.AchievementSystem = PVPSC.AchievementSystem or {}
local AchievementSystem = PVPSC.AchievementSystem

AchievementSystem.achievementsClassic = {
    {
        id = "class_paladin_0",
        title = "White Knight Down",
        description = function(a) return ("Slay %d Paladins"):format(a.targetValue) end,
        iconID = 626003,
        achievementPoints = 10,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        progress = function(achievement, stats)
            return stats.classData["Paladin"] or 0
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("They say 'I just want everyone to get along' while reporting half the BG for language. You’ve defeated %d Paladins who unironically post minion memes and call every woman “m’lady” in raid chat.")
                :format(a.targetValue)
        end,
    },
    {
        id = "class_paladin_1",
        title = "Bubble Popper",
        description = function(a) return ("Slay %d Paladins"):format(a.targetValue) end,
        iconID = 135896,
        achievementPoints = 25,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Divine Shield bubbles popped! Turns out, the Light doesn't save them when [YOUR NAME] is around.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Paladin"] or 0
        end,
    },
    {
        id = "class_paladin_2",
        title = "It's on cooldown...",
        description = function(a) return ("Slay %d Paladins"):format(a.targetValue) end,
        iconID = 134414,
        achievementPoints = 50,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Paladins discovered their Hearthstone was on cooldown. The Light abandoned them faster than their guild after a wipe.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Paladin"] or 0
        end,
    },
    {
        id = "class_paladin_3",
        title = "Divine Retirement Plan",
        description = function(a) return ("Slay %d Paladins"):format(a.targetValue) end,
        iconID = 133176,
        achievementPoints = 100,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Paladins judged and executed. Every one of them still lives in their childhood bedroom, gives unsolicited advice about honor, and thinks 'simp' is the ultimate insult. Their Tinder bios all include 'protector of women.'")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Paladin"] or 0
        end,
    },
    {
        id = "class_priest_0",
        title = "Therapy Session Over",
        description = function(a) return ("Defeat %d Priests"):format(a.targetValue) end,
        iconID = 626004,
        achievementPoints = 10,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Priests exorcised—and not just from the battlefield. These armchair therapists are one failed psych degree away from charging guildmates hourly. Every time you crit them, they ask if you're projecting.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Priest"] or 0
        end,
    },
    {
        id = "class_priest_1",
        title = "Holy Word: Death",
        description = function(a) return ("Defeat %d Priests"):format(a.targetValue) end,
        iconID = 135944,
        achievementPoints = 25,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Priests discovered that healing can't fix death! Their last confession? 'I should have rolled a Warlock.'")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Priest"] or 0
        end,
    },
    {
        id = "class_priest_2",
        title = "Scripture Shredder",
        description = function(a) return ("Defeat %d Priests"):format(a.targetValue) end,
        iconID = 135898,
        achievementPoints = 50,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Priests found out prayer cooldowns are longer than death timers! The Light's HR department is swamped with resignation letters.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Priest"] or 0
        end,
    },
    {
        id = "class_priest_3",
        title = "Religious Persecution",
        description = function(a) return ("Defeat %d Priests"):format(a.targetValue) end,
        iconID = 135922,
        achievementPoints = 100,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Priests discovered their Power Word: Shield was just plot armor! Churches now offer combat training instead of Sunday service.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Priest"] or 0
        end,
    },
    {
        id = "class_druid_0",
        title = "I'm VEGAN, bro!",
        description = function(a) return ("Take down %d Druids"):format(a.targetValue) end,
        iconID = 625999,
        achievementPoints = 10,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Druids sent back to their crystal shops! They're 'jack of all trades, master of none' incarnate but will still lecture you about your rotation. Their /yell macro includes the words 'spirit animal,' 'vibes,' and 'energy alignment,' and they've definitely tried to sell essential oils to their guildmates. Each one has explained they're vegan within 30 seconds of joining your party.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Druid"] or 0
        end,
    },
    {
        id = "class_druid_1",
        title = "Roadkill Royale",
        description = function(a) return ("Take down %d Druids"):format(a.targetValue) end,
        iconID = 132117,
        achievementPoints = 25,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Feral Druids brag about their movement speed—until they realize they’ve sprinted straight into %d unavoidable deaths. Some say Travel Form is fast. You know what’s faster? A corpse run.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Druid"] or 0
        end,
    },
    {
        id = "class_druid_2",
        title = "Animal Control",
        description = function(a) return ("Take down %d Druids"):format(a.targetValue) end,
        iconID = 132139,
        achievementPoints = 50,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Druids exterminated! Cat form, bear form, dead form – you've seen them all. PETA has issued a statement.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Druid"] or 0
        end,
    },
    {
        id = "class_druid_3",
        title = "Master of None",
        description = function(a) return ("Take down %d Druids"):format(a.targetValue) end,
        iconID = 132138,
        achievementPoints = 100,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Druids claim they can do it all—tank, heal, DPS. %d of them just proved they can also die in every imaginable way. At this point, even their Innervate couldn't restore their dignity.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Druid"] or 0
        end,
    },
    {
        id = "class_shaman_0",
        title = "Avatar State Deactivated",
        description = function(a) return ("Defeat %d Shamans"):format(a.targetValue) end,
        iconID = 626006,
        achievementPoints = 10,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Shamans eliminated! These wannabe Avatars binge-watched too many cartoons and thought they'd be bending all four elements in-game. Reality hit harder than your weapon when they discovered their totems don't actually shoot fire or create tsunamis. They spend most raids frantically alt-tabbing to YouTube tutorials trying to figure out what their class actually does. When asked about their role, they reply 'Yes' and then fail at all of them.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Shaman"] or 0
        end,
    },
    {
        id = "class_shaman_1",
        title = "Totem Kicker",
        description = function(a) return ("Defeat %d Shamans"):format(a.targetValue) end,
        iconID = 136052,
        achievementPoints = 25,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Shamans flattened — mostly Enhancement mains who picked the spec because someone told them Windfury makes big numbers. They’re now back in retail, crying about how Classic 'isn't fair'.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Shaman"] or 0
        end,
    },
    {
        id = "class_shaman_2",
        title = "Spirit Walking Dead",
        description = function(a) return ("Defeat %d Shamans"):format(a.targetValue) end,
        iconID = 136095,
        achievementPoints = 50,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Shamans deleted their characters after realizing casting Lightning Bolt in melee range isn’t actually a good strategy. Their ancestors are embarrassed.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Shaman"] or 0
        end,
    },
    {
        id = "class_shaman_3",
        title = "Windfury Wipeout",
        description = function(a) return ("Defeat %d Shamans"):format(a.targetValue) end,
        iconID = 136088,
        achievementPoints = 100,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("The world is down %d Shamans, and yet not a single one landed that mythical 3x Windfury crit. Meanwhile, Warriors are still laughing.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Shaman"] or 0
        end,
    },
    {
        id = "class_hunter_0",
        title = "Bear Grylls Roleplayers",
        description = function(a) return ("Take down %d Hunters"):format(a.targetValue) end,
        iconID = 626000,
        achievementPoints = 10,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You’ve taken out %d Hunters who say “trust your instincts” but can’t trust themselves to park straight. They bring up Bear Grylls in Discord like it's a personality trait and probably drink their own piss “ironically.”")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Hunter"] or 0
        end,
    },
    {
        id = "class_hunter_1",
        title = "I'm so special",
        description = function(a) return ("Take down %d Hunters"):format(a.targetValue) end,
        iconID = 132212,
        achievementPoints = 25,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Hunters down. All of them thought naming their pet 'Arthas' made them deep, and that spelling 'Légolâs' with special characters made them original. Congratulations — you just wiped out the world's largest unpaid cosplay convention.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Hunter"] or 0
        end,
    },
    {
        id = "class_hunter_2",
        title = "No More AFK Farmers and Backpedalers",
        description = function(a) return ("Take down %d Hunters"):format(a.targetValue) end,
        iconID = 132208,
        achievementPoints = 50,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Hunters eliminated—most didn’t even notice. Their corpses still have Auto Shot toggled on. And the other half are still backpedaling to the graveyard.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Hunter"] or 0
        end,
    },
    {
        id = "class_hunter_3",
        title = "Click… No Ammo",
        description = function(a) return ("Take down %d Hunters"):format(a.targetValue) end,
        iconID = 135618,
        achievementPoints = 100,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You’ve ended the WoW careers of %d Hunters — that’s %d dudes who think  they’re ‘PvP Gods’ because they once kited Bellygrub 40 yards to the Guards. Their last words? 'I swear I had ammo!'")
                :format(a.targetValue, a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Hunter"] or 0
        end,
    },
    {
        id = "class_warrior_0",
        title = "Protein Power Shortage",
        description = function(a) return ("Eliminate %d Warriors"):format(a.targetValue) end,
        iconID = 626008,
        achievementPoints = 10,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Warriors down! These gym bros spent more time flexing in Ironforge than learning their rotation. Their emotional range is limited to 'mad,' 'hangry,' and 'where heals?' They consider counting to 10 as advanced mathematics and think reading quest text is for roleplayers. They also believe that 'PvP' stands for 'Protein vs. Pre-workout.'")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Warrior"] or 0
        end,
    },
    {
        id = "class_warrior_1",
        title = "Rage Against The Machine",
        description = function(a) return ("Eliminate %d Warriors"):format(a.targetValue) end,
        iconID = 132333,
        achievementPoints = 25,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Warriors deleted! These walking protein shakers with keyboards think smashing random buttons is a 'rotation.' Their Discord profile pics are all gym selfies, and their vocabulary consists exclusively of 'bro,' 'gains,' and 'where heals?' The anger management clinic just closed after losing all %d of their best customers to your weapon. The only thing they rage-quit faster than the battlefield is their cutting diet.")
                :format(a.targetValue, a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Warrior"] or 0
        end,
    },
    {
        id = "class_warrior_2",
        title = "Execute.exe Has Failed",
        description = function(a) return ("Eliminate %d Warriors"):format(a.targetValue) end,
        iconID = 132355,
        achievementPoints = 50,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Warriors deleted! These mouth-breathing keyboard smashers think strategy means hitting whatever isn't on cooldown. Their collective IQ is lower than their average item level, and that's saying something after you've repeatedly ganked them naked. The warrior's guild is hiring anyone with a pulse now—previous candidates eliminated by natural selection and your weapon.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Warrior"] or 0
        end,
    },
    {
        id = "class_warrior_3",
        title = "Big Numbers, Small Brain",
        description = function(a) return ("Eliminate %d Warriors"):format(a.targetValue) end,
        iconID = 132346,
        achievementPoints = 100,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Warriors down! Turns out, rolling the most played class doesn’t guarantee you rolled the smartest players.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Warrior"] or 0
        end,
    },
    {
        id = "class_mage_0",
        title = "Actually, ...",
        description = function(a) return ("Defeat %d Mages"):format(a.targetValue) end,
        iconID = 626001,
        achievementPoints = 10,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,

        subText = function(a)
            return ("%d Mages deleted! Each one was three credits short of a philosophy degree but will lecture you about existentialism anyway. These self-proclaimed intellectuals memorized all their 'actually' rebuttals from Reddit posts and believe their IQ is 'too high to measure.'")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Mage"] or 0
        end,
    },
    {
        id = "class_mage_1",
        title = "Frost Nova'd Forever",
        description = function(a) return ("Defeat %d Mages"):format(a.targetValue) end,
        iconID = 135848,
        achievementPoints = 25,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Local inn reports %d frozen mage corpses! Their Ice Block and your Frostnova melted faster than their hopes of survival. At least they're well preserved.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Mage"] or 0
        end,
    },
    {
        id = "class_mage_2",
        title = "Cast Time Cancelled",
        description = function(a) return ("Defeat %d Mages"):format(a.targetValue) end,
        iconID = 135808,
        achievementPoints = 50,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("These %d mages learned that Pyroblast's cast time is longer than their life expectancy! Their last words were 'Just one more second...'")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Mage"] or 0
        end,
    },
    {
        id = "class_mage_3",
        title = "Arcane Accident",
        description = function(a) return ("Defeat %d Mages"):format(a.targetValue) end,
        iconID = 135736,
        achievementPoints = 100,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d failed Blink escapes, local mages are petitioning to make Blink work properly. So far, no response from their corpses.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Mage"] or 0
        end,
    },
    {
        id = "class_rogue_0",
        title = "Energy Drink Depleted",
        description = function(a) return ("Uncover and defeat %d Rogues"):format(a.targetValue) end,
        iconID = 626005,
        achievementPoints = 10,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Rogues eliminated! You can smell the Monster Energy and Doritos from here. These walking red flags all type 'ez' after winning 5v1s against level 20s. They've got fingerless gloves IRL, a 'Damaged' tattoo somewhere visible, and spend their free time making TikToks about their 'sigma male grindset.' Every one of them has a mechanical keyboard with blue switches specifically to annoy their roommates.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Rogue"] or 0
        end,
    },
    {
        id = "class_rogue_1",
        title = "Cheap Shot Champion",
        description = function(a) return ("Uncover and defeat %d Rogues"):format(a.targetValue) end,
        iconID = 132092,
        achievementPoints = 25,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Found %d rogues the hard way! Their stealth wasn't as good as they thought - maybe they should've spent more time practicing and less time ganking lowbies?")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Rogue"] or 0
        end,
    },
    {
        id = "class_rogue_2",
        title = "Swept Off Their Feet",
        description = function(a) return ("Uncover and defeat %d Rogues"):format(a.targetValue) end,
        iconID = 132292,
        achievementPoints = 50,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Rogues got outplayed so hard, even Vanish couldn’t save them. The poison vendor is now offering a ‘No Refunds’ policy.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Rogue"] or 0
        end,
    },
    {
        id = "class_rogue_3",
        title = "xXShadowLegendXx Slayer",
        description = function(a) return ("Uncover and defeat %d Rogues"):format(a.targetValue) end,
        iconID = 132299,
        achievementPoints = 100,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d rogues with names like 'Stábbyou' and 'Shadowkilla' won't be making any more YouTube 'EPIC 1V5 WORLD PVP' videos! Their Discord status is now permanently set to 'offline'.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Rogue"] or 0
        end,
    },
    {
        id = "class_warlock_0",
        title = "Wand Wielding Weirdo Wipeout",
        description = function(a) return ("Banish %d Warlocks"):format(a.targetValue) end,
        iconID = 626007,
        achievementPoints = 10,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d goths nuked! These misunderstood 'dark intellectuals' have black nail polish, a concerning collection of skeleton merchandise, and definitely own a katana. They've misquoted Nietzsche so many times that even their demons are rolling their eyes. Every guild message begins with 'I'm not trying to be negative, but...' before they proceed to be exactly that. ")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Warlock"] or 0
        end,
    },
    {
        id = "class_warlock_1",
        title = "Demon't",
        description = function(a) return ("Banish %d Warlocks"):format(a.targetValue) end,
        iconID = 136218,
        achievementPoints = 25,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Warlocks sent their demons back to HR! Soul Shards now come with a money-back guarantee.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Warlock"] or 0
        end,
    },
    {
        id = "class_warlock_2",
        title = "Forgot the Stone, Didn’t You?",
        description = function(a) return ("Banish %d Warlocks"):format(a.targetValue) end,
        iconID = 134336,
        achievementPoints = 50,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Warlocks perished, and not a single Soulstone in sight. Their last words? 'Bro, I thought you had one on me.'")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Warlock"] or 0
        end,
    },
    {
        id = "class_warlock_3",
        title = "Curse you!",
        description = function(a) return ("Banish %d Warlocks"):format(a.targetValue) end,
        iconID = 135818,
        achievementPoints = 100,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Warlocks cursed you with everything they had—bad posture, social anxiety, and a Steam library full of games they'll never finish. Joke's on them: you were already cursed with exposure to their forum posts.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.classData["Warlock"] or 0
        end,
    },
    {
        id = "gender_gender_female_1",
        title = "Equal Rights, Equal Fights",
        description = function(a) return ("Defeat %d female characters"):format(a.targetValue) end,
        iconID = 134167,
        achievementPoints = 10,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d female characters slain! Equal opportunity combat at its finest. You've sent these ladies to respawn and didn't even hold the graveyard gate open for them.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.genderData["Female"] or 0
        end,
    },
    {
        id = "gender_gender_female_2",
        title = "Premium Women's Rights Activist",
        description = function(a) return ("Defeat %d female characters"):format(a.targetValue) end,
        iconID = 132356,
        achievementPoints = 25,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d female characters deleted with extreme prejudice. The Ironforge 'Women's Protection Society' has placed a bounty on your head. Prepare for the shitstorm.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.genderData["Female"] or 0
        end,
    },
    {
        id = "gender_gender_female_3",
        title = "She/Her/Dead",
        description = function(a) return ("Defeat %d female characters"):format(a.targetValue) end,
        iconID = 135906,
        achievementPoints = 50,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d female characters obliterated! Your battle cry 'Equal rights means equal fights!' echoes across Azeroth. You've been banned from every tavern in Stormwind.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.genderData["Female"] or 0
        end,
    },
    {
        id = "gender_gender_female_4",
        title = "Wife Beater",
        description = function(a) return ("Defeat %d female characters"):format(a.targetValue) end,
        iconID = 135908,
        achievementPoints = 100,
        targetValue = 5000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d dead girls—yet somehow not a single woman touched grass in the process.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.genderData["Female"] or 0
        end,
    },

    {
        id = "gender_gender_male_1",
        title = "Widowmaker",
        description = function(a) return ("Defeat %d male characters"):format(a.targetValue) end,
        iconID = 134161,
        achievementPoints = 10,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d husbands never made it home for dinner! Their wives are spending the Goblin Life Insurance payouts at the Auction House.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.genderData["Male"] or 0
        end,
    },
    {
        id = "gender_gender_male_2",
        title = "Husband Hunter",
        description = function(a) return ("Defeat %d male characters"):format(a.targetValue) end,
        iconID = 132352,
        achievementPoints = 25,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d male characters destroyed! You're single-handedly responsible for a dating app boom in Azeroth. Lonely hearts everywhere.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.genderData["Male"] or 0
        end,
    },
    {
        id = "gender_gender_male_3",
        title = "Masculinity Challenger",
        description = function(a) return ("Defeat %d male characters"):format(a.targetValue) end,
        iconID = 134166,
        achievementPoints = 50,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d males sent to their maker! The orphanages are overflowing and the wedding ring market has crashed. Economics, baby!")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.genderData["Male"] or 0
        end,
    },
    {
        id = "gender_gender_male_4",
        title = "Professional Man-Slayer",
        description = function(a) return ("Defeat %d male characters"):format(a.targetValue) end,
        iconID = 134006,
        achievementPoints = 100,
        targetValue = 5000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d men deleted — your kill feed looks like a gender reveal gone horribly wrong.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.genderData["Male"] or 0
        end,
    },
    {
        id = "gender_gender_equality",
        title = "Gender Equality",
        description = "Complete both 'Wife Beater' and 'Professional Man-Slayer' achievements",
        iconID = 132113,
        achievementPoints = 50,
        targetValue = 2,
        condition = function(achievement, stats)
            return PSC_IsAchievementUnlocked("gender_gender_female_4") and
                   PSC_IsAchievementUnlocked("gender_gender_male_4")
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return "You've achieved true equality—10,000 kills, perfectly balanced. Thanos would be proud, but probably also a little concerned about your hobbies."
        end,
        progress = function(achievement, stats)
            local female = PSC_IsAchievementUnlocked("gender_gender_female_4") and 1 or 0
            local male = PSC_IsAchievementUnlocked("gender_gender_male_4") and 1 or 0
            return female + male
        end,
    },
    {
        id = "bonus_horde",
        title = "Redridge Renovation",
        description = function(a) return ("Eliminate %d players in Redridge Mountains"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236814",
        achievementPoints = 0,
        targetValue = 10000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Redridge! At this point, the Horde is considering annexing the territory and renaming it 'Corpseridge.' Real estate agents are advertising it as 'Lordaeron South - Now with 100%% more corpses!' The Forsaken already filing paperwork to make it their summer vacation resort.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Redridge Mountains")
        end,
    },
    {
        id = "bonus_next_redridgeguy",
        title = "The next Redridgeguy",
        description = function(a) return ("Eliminate %d level 15-25 players in Redridge Mountains"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236452",
        achievementPoints = 0,
        targetValue = 15000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d leveling Alliance sent back to Lakeshire in tears. Wall-jumps into unreachable ledges, safe spots requiring a physics degree, and a wardrobe of vanity items nobody asked for—all for the stream. Somewhere out there, a dozen streamsnipers are still circling Redridge, and you're still one step ahead of them.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.redridgeLevel15To25Kills or 0
        end,
    },
    {
        id = "bonus_redridge_revenge",
        title = "Every Alt Has a Main",
        description = function(a) return ("Eliminate %d level 60-70 players in Redridge Mountains"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\237555",
        achievementPoints = 0,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d max-level corpses in Redridge. Statistically, at least a few of them are the mains of low-level alts you ganked years ago, finally back to settle the score—and losing again. No proof required, only vibes.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.redridgeLevel60To70Kills or 0
        end,
    },
        {
        id = "bonus_points_2000",
        title = "Point Collector",
        description = function(a) return ("Earn %d achievement points"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236665",
        achievementPoints = 0,
        targetValue = 2000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d achievement points earned! That little *ding* sound is now your favorite song. You're officially addicted to meaningless digital validation.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.totalAchievementPoints or 0
        end,
    },
    {
        id = "bonus_points_4000",
        title = "Achievement Addict",
        description = function(a) return ("Earn %d achievement points"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236665",
        achievementPoints = 0,
        targetValue = 4000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d achievement points collected! You've memorized every achievement icon and their exact pixel positions. Your guild chat is basically just achievement spam.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.totalAchievementPoints or 0
        end,
    },
    {
        id = "bonus_points_8000",
        title = "Digital Hoarder",
        description = function(a) return ("Earn %d achievement points"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236668",
        achievementPoints = 0,
        targetValue = 8000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d achievement points amassed! You print and frame achievement screenshots. Your therapist gave up and started playing WoW instead.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.totalAchievementPoints or 0
        end,
    },
    {
        id = "bonus_points_16000",
        title = "Achievement Overlord",
        description = function(a) return ("Earn %d achievement points"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236670",
        achievementPoints = 0,
        targetValue = 16000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d achievement points conquered! Scientists want to study your brain but you're too busy hunting achievements. Your obituary will just be a list of your unlocks.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.totalAchievementPoints or 0
        end,
    },
    {
        id = "bonus_unlocked_50",
        title = "Trophy Cabinet",
        description = function(a) return ("Unlock %d achievements"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236682",
        achievementPoints = 0,
        targetValue = 50,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d achievements unlocked! Your parents are proud but confused. 'That's nice, dear, but did you eat today?'")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.unlockedAchievements or 0
        end,
    },
    {
        id = "bonus_unlocked_100",
        title = "Completionist's Curse",
        description = function(a) return ("Unlock %d achievements"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236683",
        achievementPoints = 0,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d achievements completed! Every notification sound makes you drool like Pavlov's dog. You've bookmarked 47 achievement guides.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.unlockedAchievements or 0
        end,
    },
    {
        id = "bonus_unlocked_150",
        title = "Achievement Archaeologist",
        description = function(a) return ("Unlock %d achievements"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236685",
        achievementPoints = 0,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d achievements excavated! You check this addon more than your bank account. Indiana Jones called—he wants his obsession back.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.unlockedAchievements or 0
        end,
    },
    {
        id = "bonus_unlocked_200",
        title = "Achievement Immortal",
        description = function(a) return ("Unlock %d achievements"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236686",
        achievementPoints = 0,
        targetValue = 200,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d achievements ascended! Your soul is permanently bound to this addon. When you die, your ghost will still be hunting for missing achievements.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.unlockedAchievements or 0
        end,
    },
    {
        id = "kills_total_0",
        title = "Death Distributor",
        description = function(a) return ("Get %d player kills"):format(a.targetValue) end,
        iconID = 132293, -- spell_shadow_shadowfury
        achievementPoints = 10,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d player kills! The graveyard has a special registration line just for your victims. Spirit healers are filing for overtime pay and considering unionizing. The local coffin maker just bought a second home.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.totalKills or 0
        end,
    },
    {
        id = "kills_total_1",
        title = "Body Count Rising",
        description = function(a) return ("Get %d player kills"):format(a.targetValue) end,
        iconID = 135974, -- spell_shadow_shadowfury
        achievementPoints = 25,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d bodies dropped! Barrens chat has already moved on to debating whether you're a bot, a multiboxer, or just deeply unhinged.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.totalKills or 0
        end,
    },
    {
        id = "kills_total_2",
        title = "Graveyard Entrepreneur",
        description = function(a) return ("Get %d player kills"):format(a.targetValue) end,
        iconID = 237542,
        achievementPoints = 50,
        targetValue = 5000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills! Spirit Healers are now offering you a commission for each body you send their way. The local gravediggers have named their shovels after you.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.totalKills or 0
        end,
    },
    {
        id = "kills_total_3",
        title = "Death Incorporated",
        description = function(a) return ("Get %d player kills"):format(a.targetValue) end,
        iconID = 132205,
        achievementPoints = 100,
        targetValue = 10000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d confirmed kills! Even Mankrik’s wife had better odds of survival."):format(a
                .targetValue)
        end,
        progress = function(achievement, stats)
            return stats.totalKills or 0
        end,
    },
    {
        id = "kills_unique_0",
        title = "Face Collector",
        description = function(a) return ("Kill %d unique players"):format(a.targetValue) end,
        iconID = 133789,
        achievementPoints = 10,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d unique players have felt your wrath! Your kill list is longer than the server queue on launch day. You don't need a friends list—you have a victims catalog organized alphabetically for easy reference.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.uniqueKills or 0
        end,
    },
    {
        id = "kills_unique_1",
        title = "Variety Slayer",
        description = function(a) return ("Kill %d unique players"):format(a.targetValue) end,
        iconID = 133789,
        achievementPoints = 25,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d different players have fallen to you. At this point, you’re less of a PvPer and more of an extinction event. Azeroth is running out of fresh faces, and you’re the reason why.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.uniqueKills or 0
        end,
    },
    {
        id = "kills_unique_2",
        title = "Equal Opportunity Executioner",
        description = function(a) return ("Kill %d unique players"):format(a.targetValue) end,
        iconID = 133787,
        achievementPoints = 50,
        targetValue = 5000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d unique victims and counting! Players are now selling 'I Survived [YOUR NAME]' t-shirts - except none of them actually survived.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.uniqueKills or 0
        end,
    },
    {
        id = "kills_unique_3",
        title = "Celebrity Stalker",
        description = function(a) return ("Kill %d unique players"):format(a.targetValue) end,
        iconID = 133785,
        achievementPoints = 250,
        targetValue = 10000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d unique souls claimed! At this point, it's easier to list who you HAVEN'T killed. How’s that kill addiction treating you? ")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.uniqueKills or 0
        end,
    },
    {
        id = "kills_honorable_0",
        title = "Honor System Initiated",
        description = function(a) return ("Get %d honorable kills"):format(a.targetValue) end,
        iconID = 135024, -- Spell_holy_restoration
        achievementPoints = 25,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d honorable kills earned! You've officially joined the honor grind. The gray kills don't count here—this is about quality, not quantity. Spirit healers are starting to recognize your commitment to actual PvP.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            local honorableKills, dishonorableKills, highestRank = GetPVPLifetimeStats()
            return honorableKills or 0
        end,
    },
    {
        id = "kills_honorable_1",
        title = "Honor Guard",
        description = function(a) return ("Get %d honorable kills"):format(a.targetValue) end,
        iconID = 133440, -- Spell_holy_holyProtection
        achievementPoints = 50,
        targetValue = 2500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d honorable kills achieved! You're building a respectable honor rank. No more gray ganking—these kills actually matter for your standing. The PvP system respects your dedication.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            local honorableKills, dishonorableKills, highestRank = GetPVPLifetimeStats()
            return honorableKills or 0
        end,
    },
    {
        id = "kills_honorable_2",
        title = "Honorable Executioner",
        description = function(a) return ("Get %d honorable kills"):format(a.targetValue) end,
        iconID = 135953, -- Spell_holy_retributionAura
        achievementPoints = 100,
        targetValue = 10000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d honorable kills secured! You've mastered the art of meaningful PvP. Every kill contributes to your honor rank progression. The battlegrounds know your name.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            local honorableKills, dishonorableKills, highestRank = GetPVPLifetimeStats()
            return honorableKills or 0
        end,
    },
    {
        id = "kills_honorable_3",
        title = "Grand Marshal's Nightmare",
        description = function(a) return ("Get %d honorable kills"):format(a.targetValue) end,
        iconID = 135729, -- Spell_holy_weaponMastery
        achievementPoints = 250,
        targetValue = 25000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d honorable kills conquered! You've transcended the honor system entirely. Grand Marshals wake up in cold sweats dreaming about your kill count. The honor system wasn't designed for players like you.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            local honorableKills, dishonorableKills, highestRank = GetPVPLifetimeStats()
            return honorableKills or 0
        end,
    },

    -- Level Range Achievements
    {
        id = "kills_level_range_1_9",
        title = "No Mercy for Newbies",
        description = function(a) return ("Kill at least one player at each level from 1 to 9"):format() end,
        iconID = 236323,
        achievementPoints = 25,
        targetValue = 9,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return "They just finished the tutorial. Their bags are empty, their hearthstone is unset, and their corpse is already on the floor. Before they could even pick a hairstyle, you gave them their first PvP death. Some lessons only the graveyard can teach."
        end,
        progress = function(achievement, stats)
            local count = 0
            for level = 1, 9 do
                if (stats.levelData[tostring(level)] or 0) > 0 then
                    count = count + 1
                end
            end
            return count
        end,
    },
    {
        id = "kills_level_range_10_19",
        title = "Teen Spirit Crusher",
        description = function(a) return ("Kill at least one player at each level from 10 to 19"):format() end,
        iconID = 236324,
        achievementPoints = 25,
        targetValue = 10,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return "Warsong Gulch. A 10-19 bracket that looked like competitive PvP until you showed up. They queued for the flag. They got a funeral procession. Ten levels of players who thought the gulch was a fair fight — you corrected that assumption, one graveyard run at a time."
        end,
        progress = function(achievement, stats)
            local count = 0
            for level = 10, 19 do
                if (stats.levelData[tostring(level)] or 0) > 0 then
                    count = count + 1
                end
            end
            return count
        end,
    },
    {
        id = "kills_level_range_20_29",
        title = "Journeyman Reaper",
        description = function(a) return ("Kill at least one player at each level from 20 to 29"):format() end,
        iconID = 236325,
        achievementPoints = 25,
        targetValue = 10,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return "The Arathi Basin bracket. They fought over the farm, the mine, the stables — you just fought them. Ten levels of players who thought capping a flag made them safe. It didn't. The blacksmith changes hands. Your kill count only goes up."
        end,
        progress = function(achievement, stats)
            local count = 0
            for level = 20, 29 do
                if (stats.levelData[tostring(level)] or 0) > 0 then
                    count = count + 1
                end
            end
            return count
        end,
    },
    {
        id = "kills_level_range_30_39",
        title = "Halfway to Nowhere",
        description = function(a) return ("Kill at least one player at each level from 30 to 39"):format() end,
        iconID = 236326,
        achievementPoints = 25,
        targetValue = 10,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return "Stranglethorn Vale. The most contested jungle on Azeroth, where both factions go to level and neither feels safe doing it. Ten levels of players who thought the dense canopy offered cover. You proved it just makes it harder to see you coming."
        end,
        progress = function(achievement, stats)
            local count = 0
            for level = 30, 39 do
                if (stats.levelData[tostring(level)] or 0) > 0 then
                    count = count + 1
                end
            end
            return count
        end,
    },
    {
        id = "kills_level_range_40_49",
        title = "The Penultimate Predator",
        description = function(a) return ("Kill at least one player at each level from 40 to 49"):format() end,
        iconID = 236327,
        achievementPoints = 50,
        targetValue = 10,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return "Tanaris, Azshara, Feralas — desolate zones where the opposite faction grinds alone and hopes nobody notices. You noticed. Ten levels of players saving up for their epic mount, unaware they'd be funding a graveyard run instead."
        end,
        progress = function(achievement, stats)
            local count = 0
            for level = 40, 49 do
                if (stats.levelData[tostring(level)] or 0) > 0 then
                    count = count + 1
                end
            end
            return count
        end,
    },
    {
        id = "kills_level_range_50_59",
        title = "Pre-Cap Predator",
        description = function(a) return ("Kill at least one player at each level from 50 to 59"):format() end,
        iconID = 236328,
        achievementPoints = 50,
        targetValue = 10,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return "Felwood, the Plaguelands, Silithus — end-game contested zones where the opposite faction shows up fully committed to leveling. Ten levels of players on the final stretch to 60, grinding through corrupted forests and plague-ridden fields. You made the plague look mild by comparison."
        end,
        progress = function(achievement, stats)
            local count = 0
            for level = 50, 59 do
                if (stats.levelData[tostring(level)] or 0) > 0 then
                    count = count + 1
                end
            end
            return count
        end,
    },
    {
        id = "kills_level_range_60_70",
        title = "Peak Season Hunter",
        description = function(a) return ("Kill at least one player at each level from 60 to 70"):format() end,
        iconID = 236329,
        achievementPoints = 75,
        targetValue = 11,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return "Hellfire Peninsula, Zangarmarsh, Nagrand — Outland opened its Dark Portal and the opposite faction flooded through right alongside you. Eleven levels of max-or-near-max players in some of the most brutally contested territory in the game. No safe roads. No neutral guards. Just you, them, and the ever-present smell of fel fire."
        end,
        progress = function(achievement, stats)
            local count = 0
            for level = 60, 70 do
                if (stats.levelData[tostring(level)] or 0) > 0 then
                    count = count + 1
                end
            end
            return count
        end,
    },
    {
        id = "kills_level_full_spectrum",
        title = "The Full Spectrum",
        description = function(a) return ("Kill at least one player at every level range (1-70)"):format() end,
        iconID = 4006481,
        achievementPoints = 500,
        targetValue = 7,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return "Newbies in the starting zones. Warsong Gulch hopefuls. Arathi Basin farmers. Stranglethorn survivors. Tanaris grinders. Plaguelands veterans. Outland pioneers. You ended every single bracket. From the first corpse run outside Northshire to the last kill in the Netherstorm — you covered every step of the enemy's journey. The entire spectrum. No escape, no safe level, no neutral ground."
        end,
        progress = function(achievement, stats)
            local characterKey = PSC_GetCharacterKey()
            local savedAchievements = PSC_DB.CharacterAchievements and PSC_DB.CharacterAchievements[characterKey] or {}
            local rangeIds = {
                "kills_level_range_1_9", "kills_level_range_10_19", "kills_level_range_20_29",
                "kills_level_range_30_39", "kills_level_range_40_49", "kills_level_range_50_59",
                "kills_level_range_60_70"
            }
            local count = 0
            for _, id in ipairs(rangeIds) do
                if savedAchievements[id] and savedAchievements[id].unlocked then
                    count = count + 1
                end
            end
            return count
        end,
    },

    {
        id = "race_human_0",
        title = "Human Error",
        description = function(a) return ("Eliminate %d Humans"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236447",
        achievementPoints = 10,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Humans dispatched! Their racial ability 'Every Man for Himself' should really be called 'Every Man for the Graveyard.' So much for human ingenuity.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Human"] or 0
        end,
    },
    {
        id = "race_human_1",
        title = "Human Resources",
        description = function(a) return ("Eliminate %d Humans"):format(a.targetValue) end,
        iconID = 134167,
        achievementPoints = 25,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Humans deleted! The most basic race in Azeroth, chosen by people who couldn’t be bothered to click twice. They died as they lived—completely unremarkable.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Human"] or 0
        end,
    },
    {
        id = "race_human_2",
        title = "Peak Meta, Peak Failure",
        description = function(a) return ("Eliminate %d Humans"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236448",
        achievementPoints = 50,
        targetValue = 2000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Humans down! They picked the ‘best PvP race’ for the racial bonuses but forgot to read the part about positioning and cooldowns.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Human"] or 0
        end,
    },
    {
        id = "race_human_3",
        title = "Uniqueness",
        description = function(a) return ("Eliminate %d Humans"):format(a.targetValue) end,
        iconID = 133730,
        achievementPoints = 100,
        targetValue = 4000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Humans permanently retired from Azeroth! The most basic, uninspired race choice in gaming history. These generic NPCs rolled Human because the character creation screen was 'too overwhelming' and they couldn't be bothered to scroll down. Half of them are definitely bots farming gold, the other half might as well be with their keyboard-turning skills. They all picked the 'optimal PvE race' based on some min-max guide and they thought they were 'playing the meta' but ended up being the punchline.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Human"] or 0
        end,
    },


    {
        id = "race_nightelf_0",
        title = "Nightlight Off",
        description = function(a) return ("Eliminate %d Night Elves"):format(a.targetValue) end,
        iconID = "236449",
        achievementPoints = 10,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Night Elves slain! Half were dudes with 'Illidan' in their names trying to dual-wield everything, the other half were female characters made by players who just discovered hormones. Their deaths were as dramatic as their /dance animations. Time to let go of that purple dream, boys—Tyrande's not checking your DMs.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Night Elf"] or 0
        end,
    },
    {
        id = "race_nightelf_1",
        title = "Shadowmeld Won't Save You",
        description = function(a) return ("Eliminate %d Night Elves"):format(a.targetValue) end,
        iconID = 134162,
        achievementPoints = 25,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You’ve deleted more Elves than bad Tolkien fanfics.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Night Elf"] or 0
        end,
    },
    {
        id = "race_nightelf_2",
        title = "Recycled by Force",
        description = function(a) return ("Eliminate %d Night Elves"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236450",
        achievementPoints = 50,
        targetValue = 2000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Night Elf eco-warriors tried saving the trees, but couldn't save themselves. Composting at its finest. Your kill count just went carbon neutral.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Night Elf"] or 0
        end,
    },
    {
        id = "race_nightelf_3",
        title = "Plant-Based and Player-Slayed",
        description = function(a) return ("Eliminate %d Night Elves"):format(a.targetValue) end,
        iconID = 134161,
        achievementPoints = 100,
        targetValue = 4000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Vegan diets, spirit guides, and herbal teas couldn't boost their stamina. Turns out positive vibes don't stop crits to the face. Now they're part of the soil — gluten-free, non-GMO, and 100%% biodegradable.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Night Elf"] or 0
        end,
    },


    {
        id = "race_dwarf_0",
        title = "Mumble rap",
        description = function(a) return ("Eliminate %d Dwarves"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236443",
        achievementPoints = 10,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Dwarves hammered down! These walking Scottish stereotypes died mumbling something that might have been a battle cry or just ordering another ale—nobody could understand a word through that accent. Next time they'll think twice before typing 'AYE LADDIE!' in every chat channel.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Dwarf"] or 0
        end,
    },
    {
        id = "race_dwarf_1",
        title = "Short Term Solution",
        description = function(a) return ("Eliminate %d Dwarves"):format(a.targetValue) end,
        iconID = 134160,
        achievementPoints = 25,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Dwarves crushed! Short, stout, and now six feet under. Their ‘legendary resilience’ apparently doesn’t apply when getting farmed for honor.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Dwarf"] or 0
        end,
    },
    {
        id = "race_dwarf_2",
        title = "Beard Trimmer",
        description = function(a) return ("Eliminate %d Dwarves"):format(a.targetValue) end,
        iconID = "236444",
        achievementPoints = 50,
        targetValue = 2000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Snow White and the %d Dead Dwarfs! Not even Disney magic could save this tragic tale. The remaining dwarfs changed their names to 'Corpsey,' 'Deady,' 'Respawny,' 'Campy,' 'Ganky,' 'Ragey,' and 'Doc' (who rerolled a Priest). Mining productivity has dropped 70%%, but beard wax sales plummeted 100%%.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Dwarf"] or 0
        end,
    },
    {
        id = "race_dwarf_3",
        title = "Height Disadvantage",
        description = function(a) return ("Eliminate %d Dwarves"):format(a.targetValue) end,
        iconID = 134159,
        achievementPoints = 100,
        targetValue = 4000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Ironforge engineers are designing smaller coffins after %d 'height-challenged' casualties! Their spirits are now discovering that the Great Forge isn't so great.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Dwarf"] or 0
        end,
    },


    {
        id = "race_gnome_0",
        title = "Lawn Ornament Collector",
        description = function(a) return ("Eliminate %d Gnomes"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236445",
        achievementPoints = 10,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Gnomes stepped on! All their engineering gadgets failed when they needed them most. At least they make cute decorations for your kill count.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Gnome"] or 0
        end,
    },
    {
        id = "race_gnome_1",
        title = "Pest Control",
        description = function(a) return ("Eliminate %d Gnomes"):format(a.targetValue) end,
        iconID = 134165,
        achievementPoints = 25,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Gnomes punted out of existence! Their last words? 'Size doesn’t matter!' Their respawn timer says otherwise. So do their wifes.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Gnome"] or 0
        end,
    },
    {
        id = "race_gnome_2",
        title = "Garden Gnome Collection",
        description = function(a) return ("Eliminate %d Gnomes"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236446",
        achievementPoints = 50,
        targetValue = 2000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Gnomes deleted. You’ve wiped more STEM majors than a Silicon Valley hiring freeze. Their gadgets couldn’t save them, and their last words were all keyboard macros no one understood")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Gnome"] or 0
        end,
    },
    {
        id = "race_gnome_3",
        title = "Small Problems Solved",
        description = function(a) return ("Eliminate %d Gnomes"):format(a.targetValue) end,
        iconID = 134164,
        achievementPoints = 100,
        targetValue = 4000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Gnomes down, and every single one had 'server admin' in their Twitter bio. You didn’t just kill characters—you killed the dream of moderating a Minecraft server empire.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Gnome"] or 0
        end,
    },


    {
        id = "race_orc_0",
        title = "Orc Slayer",
        description = function(a) return ("Eliminate %d Orcs"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236451",
        achievementPoints = 10,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Orcs sent to meet their ancestors! Their blood fury only made your attacks hurt more. So much for orcish resilience when faced with your wrath.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Orc"] or 0
        end,
    },
    {
        id = "race_orc_1",
        title = "Green Peace",
        description = function(a) return ("Eliminate %d Orcs"):format(a.targetValue) end,
        iconID = 134171,
        achievementPoints = 25,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Zug zug? More like zug zugged into the grave. %d Orcs charged in, expecting an easy win—turns out, yelling ‘Lok’tar Ogar!’ doesn’t make you invincible.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Orc"] or 0
        end,
    },
    {
        id = "race_orc_2",
        title = "Anger Management Expert",
        description = function(a) return ("Eliminate %d Orcs"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236452",
        achievementPoints = 50,
        targetValue = 2000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Orcs have rage-quit after meeting you! These keyboard smashers with names like 'Gorégut' and 'Axemastr' spent more time perfecting their /flex macro than learning to dodge. Greenpeace has formally requested you stop this endangered species extinction event. Their Blood Fury racial activated IRL as they typed angry whispers to you from the graveyard.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Orc"] or 0
        end,
    },
    {
        id = "race_orc_3",
        title = "Green Graveyard",
        description = function(a) return ("Eliminate %d Orcs"):format(a.targetValue) end,
        iconID = 134170,
        achievementPoints = 100,
        targetValue = 4000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d min-maxing Orc players just discovered their PvP racial doesn't help when they keyboard turn! These meta-chasers who rolled the 'optimal race' couldn't optimize their way out of a [YOUR NAME] beatdown. All those forum guides didn't prepare them for someone who actually knows how to play. Should've practiced instead of bragging about stun resistance in trade chat!")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Orc"] or 0
        end,
    },


    {
        id = "race_undead_0",
        title = "Re-dead",
        description = function(a) return ("Eliminate %d Undead"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236457",
        achievementPoints = 10,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Undead returned to their graves! Turns out being already dead doesn't make you immune to a second death. Will of the Forsaken? More like Will to Respawn.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Undead"] or 0
        end,
    },
    {
        id = "race_undead_1",
        title = "Double Dead",
        description = function(a) return ("Eliminate %d Undead"):format(a.targetValue) end,
        iconID = 134180,
        achievementPoints = 25,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Forsaken sent back to the character creation screen. Turns out, playing ‘the most hardcore race’ doesn’t make you any less of a free HK. Sylvanas won’t miss them—she doesn’t even miss her own people.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Undead"] or 0
        end,
    },
    {
        id = "race_undead_2",
        title = "Zombies't",
        description = function(a) return ("Eliminate %d Undead"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236458",
        achievementPoints = 50,
        targetValue = 2000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Forsaken ganked! They picked Undead to look cool and ended up looking clueless. No, ‘Will of the Forsaken’ doesn’t make you invincible—if it did, they wouldn’t all be face-down in the dirt")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Undead"] or 0
        end,
    },
    {
        id = "race_undead_3",
        title = "Permanent Death Status",
        description = function(a) return ("Eliminate %d Undead"):format(a.targetValue) end,
        iconID = 136187,
        achievementPoints = 100,
        targetValue = 4000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Forsaken now even more dead than before! The Dark Lady's weekly newsletter now includes a [YOUR NAME] survival guide. These edgelords thought being already-dead made them cool until you showed them what 'dead-dead' feels like. Now Brill is a ghost town (even more than usual), and Tirisfal Glades real estate is free for the taking. Even the Scarlet Crusade thinks you're taking this whole 'purging the undead' thing too far.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Undead"] or 0
        end,
    },


    {
        id = "race_troll_0",
        title = "Troll Hunter",
        description = function(a) return ("Eliminate %d Trolls"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236455",
        achievementPoints = 10,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Trolls made to stay dead! Their regeneration couldn't keep up with your damage output. The Darkspear tribe is sending angry letters about their population decline.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Troll"] or 0
        end,
    },
    {
        id = "race_troll_1",
        title = "Voodoo Venue Closed",
        description = function(a) return ("Eliminate %d Trolls"):format(a.targetValue) end,
        iconID = 134178,
        achievementPoints = 25,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Da spirits be VERY angry wit' you mon, after %d trolls found out their regeneration can't outpace your damage output. Their hunched backs didn't help them dodge your attacks—just made it easier for you to spot them from a distance. Zul'jin is considering therapy after watching your killing spree. Stay away from da voodoo!")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Troll"] or 0
        end,
    },
    {
        id = "race_troll_2",
        title = "Berserking Backfire",
        description = function(a) return ("Eliminate %d Trolls"):format(a.targetValue) end,
        iconID = "236456",
        achievementPoints = 50,
        targetValue = 2000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d trolls slain! Just like the keyboard warriors who play them—they talked big in forums but fell silent in actual combat. These Reddit moderators and Twitter reply-guys picked Trolls because they thought it was their spirit animal. They spammed 'git gud' to newbies while getting absolutely destroyed by you. The irony of trolls getting trolled is not lost on the rest of the server. Their abandoned forum accounts are now collecting dust just like their corpses.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Troll"] or 0
        end,
    },
    {
        id = "race_troll_3",
        title = "Hunched Back, Hunched Over in Defeat",
        description = function(a) return ("Eliminate %d Trolls"):format(a.targetValue) end,
        iconID = 134177,
        achievementPoints = 100,
        targetValue = 4000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Trolls down! Their posture wasn’t the only thing broken today. Maybe they should’ve berserked their way to a real strategy instead of just hoping their racial would carry them.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Troll"] or 0
        end,
    },


    {
        id = "race_tauren_0",
        title = "Sacred Cow",
        description = function(a) return ("Eliminate %d Tauren"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236453",
        achievementPoints = 10,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Tauren sent to the great plains in the sky! Those war stomps were no match for your superior combat skills. The Earth Mother has filed a complaint about your treatment of her children.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Tauren"] or 0
        end,
    },
    {
        id = "race_tauren_1",
        title = "Biggest Hitbox, Biggest Target",
        description = function(a) return ("Eliminate %d Tauren"):format(a.targetValue) end,
        iconID = 134175,
        achievementPoints = 25,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Tauren down! These walking steaks chose the biggest hitbox in the game then complained when your attacks connected. McDonald's just offered you a sponsorship deal after your record-breaking beef production. The 'got milk?' campaign is suing you for destroying their mascots. Next time they'll think twice before picking a race that can be seen from the other continent.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Tauren"] or 0
        end,
    },
    {
        id = "race_tauren_2",
        title = "No More Bull",
        description = function(a) return ("Eliminate %d Tauren"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236454",
        achievementPoints = 50,
        targetValue = 2000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Tauren players got exactly what they deserved for picking the 'gentle giant' stereotype! Their 5%% bonus health just meant they died 3 seconds slower while panic-pressing War Stomp. The real stampede was them rushing to the forums to complain about 'unfair pvp balance.'")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Tauren"] or 0
        end,
    },
    {
        id = "race_tauren_3",
        title = "Cattle Depopulation",
        description = function(a) return ("Eliminate %d Tauren"):format(a.targetValue) end,
        iconID = 134174,
        achievementPoints = 100,
        targetValue = 4000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've slaughtered %d Tauren! Thunder Bluff elevator accidents are now the SECOND leading cause of Tauren death. These gentle giants had 5%% more health than other races, which gave them exactly 3 extra seconds to contemplate their life choices before you ended them. Mulgore's milk industry has collapsed, and the Grimtotem are sending you fan mail. The Earth Mother has filed a restraining order against you.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.raceData["Tauren"] or 0
        end,
    },
    {
        id = "race_alliance_mixed_human_nightelf_dwarf_gnome_100",
        title = function(a)
            if PSC_GameVersion == PSC_GAME_VERSIONS.CLASSIC then
                return "Alliance Sampler Platter"
            else
                return "Alliance Sampler Platter (Classic)"
            end
        end,
        description = function(a) return ("Eliminate %d of each Alliance race (400 total)"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236592",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've achieved perfect Alliance genocide balance! %d Humans, %d Gnomes, %d Dwarves, and %d Night Elves - that's equality in death! Stormwind's diversity committee is impressed by your non-discriminatory killing approach. You're like a serial killer with OCD, but for racial statistics.")
                :format(a.targetValue, a.targetValue, a.targetValue, a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForAllianceRacesClassic(stats)
        end,
    },
    {
        id = "race_alliance_mixed_human_nightelf_dwarf_gnome_250",
        title = function(a)
            if PSC_GameVersion == PSC_GAME_VERSIONS.CLASSIC then
                return "Alliance Census Corrector"
            else
                return "Alliance Census Corrector (Classic)"
            end
        end,
        description = function(a) return ("Eliminate %d of each Alliance race (1000 total)"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236592",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Perfect Alliance extermination ratios achieved! %d kills per race shows your commitment to fair and balanced genocide. The Alliance leadership is considering renaming their faction to 'The Survivors of [YOUR NAME].' Even King Varian is impressed by your mathematical precision in mass murder.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForAllianceRacesClassic(stats)
        end,
    },
    {
        id = "race_alliance_mixed_human_nightelf_dwarf_gnome_500",
        title = function(a)
            if PSC_GameVersion == PSC_GAME_VERSIONS.CLASSIC then
                return "Alliance Demographic Disaster"
            else
                return "Alliance Demographic Disaster (Classic)"
            end
        end,
        description = function(a) return ("Eliminate %d of each Alliance race (2000 total)"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236592",
        achievementPoints = 75,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've single-handedly caused an Alliance population crisis! %d deaths per race means their birth rates can't keep up with your kill rate. Stormwind's Bureau of Statistics has classified you as a 'natural disaster.' The remaining Alliance players are considering a class action lawsuit against Blizzard for allowing you to exist.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForAllianceRacesClassic(stats)
        end,
    },
    {
        id = "race_alliance_mixed_human_nightelf_dwarf_gnome_1000",
        title = function(a)
            if PSC_GameVersion == PSC_GAME_VERSIONS.CLASSIC then
                return "Alliance Extinction Protocol"
            else
                return "Alliance Extinction Protocol (Classic)"
            end
        end,
        description = function(a) return ("Eliminate %d of each Alliance race (4000 total)"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236592",
        achievementPoints = 100,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("LEGENDARY GENOCIDE ACHIEVEMENT! You've eliminated %d of each Alliance race with surgical precision. This level of systematic extermination would make even the Burning Legion jealous. The Alliance has officially petitioned the UN (United NPCs) to classify you as a war criminal. Congratulations, you've achieved what Arthas, Illidan, and Deathwing combined couldn't: perfect racial balance through annihilation!")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForAllianceRacesClassic(stats)
        end,
    },

    -- HORDE MIXED RACE ACHIEVEMENTS
    {
        id = "race_horde_mixed_orc_undead_troll_tauren_100",
        title = function(a)
            if PSC_GameVersion == PSC_GAME_VERSIONS.CLASSIC then
                return "Horde Variety Pack"
            else
                return "Horde Variety Pack (Classic)"
            end
        end,
        description = function(a) return ("Eliminate %d of each Horde race (400 total)"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\255132",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d of each Horde breed deleted. Equal opportunity slaughter across the savage races.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForHordeRacesClassic(stats)
        end,
    },
    {
        id = "race_horde_mixed_orc_undead_troll_tauren_250",
        title = function(a)
            if PSC_GameVersion == PSC_GAME_VERSIONS.CLASSIC then
                return "Horde Population Control"
            else
                return "Horde Population Control (Classic)"
            end
        end,
        description = function(a) return ("Eliminate %d of each Horde race (1000 total)"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\255132",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills per race. Thrall's diversity program is failing spectacularly.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForHordeRacesClassic(stats)
        end,
    },
    {
        id = "race_horde_mixed_orc_undead_troll_tauren_500",
        title = function(a)
            if PSC_GameVersion == PSC_GAME_VERSIONS.CLASSIC then
                return "Horde Demographic Crisis"
            else
                return "Horde Demographic Crisis (Classic)"
            end
        end,
        description = function(a) return ("Eliminate %d of each Horde race (2000 total)"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\255132",
        achievementPoints = 75,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d deaths each. Orgrimmar's census is now just a death toll.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForHordeRacesClassic(stats)
        end,
    },
    {
        id = "race_horde_mixed_orc_undead_troll_tauren_1000",
        title = function(a)
            if PSC_GameVersion == PSC_GAME_VERSIONS.CLASSIC then
                return "Horde Extinction Event"
            else
                return "Horde Extinction Event (Classic)"
            end
        end,
        description = function(a) return ("Eliminate %d of each Horde race (4000 total)"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\255132",
        achievementPoints = 100,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills per race. The Horde is now the Whored - you've made them your playthings.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForHordeRacesClassic(stats)
        end,
    },
    {
        id = "class_mixed_warrior_paladin_hunter_rogue_priest_shaman_mage_warlock_druid_100",
        title = function(a)
            if PSC_GameVersion == PSC_GAME_VERSIONS.CLASSIC then
                return "Class Warfare Initiate"
            else
                return "Class Warfare Initiate (Classic)"
            end
        end,
        description = function(a) return ("Execute %d of each class"):format(a.targetValue) end,
        iconID = 132147,
        achievementPoints = 75,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Perfect class extermination achieved. %d deaths per class - no favorites, no mercy. Equal opportunity murder across all professions.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForAchievementWithAllClasses(stats, PSC_GAME_VERSIONS.CLASSIC)
        end,
    },
    {
        id = "class_mixed_warrior_paladin_hunter_rogue_priest_shaman_mage_warlock_druid_250",
        title = function(a)
            if PSC_GameVersion == PSC_GAME_VERSIONS.CLASSIC then
                return "Professional Exterminator"
            else
                return "Professional Exterminator (Classic)"
            end
        end,
        description = function(a) return ("Execute %d of each class"):format(a.targetValue) end,
        iconID = 132349,
        achievementPoints = 125,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("All classes equally decimated. %d corpses per profession. Your methodical approach to mass murder shows disturbing efficiency.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForAchievementWithAllClasses(stats, PSC_GAME_VERSIONS.CLASSIC)
        end,
    },
    {
        id = "class_mixed_warrior_paladin_hunter_rogue_priest_shaman_mage_warlock_druid_500",
        title = function(a)
            if PSC_GameVersion == PSC_GAME_VERSIONS.CLASSIC then
                return "Class Genocide Specialist"
            else
                return "Class Genocide Specialist (Classic)"
            end
        end,
        description = function(a) return ("Execute %d of each class"):format(a.targetValue) end,
        iconID = 135999,
        achievementPoints = 125,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Systematic class annihilation complete. %d deaths per class. Your kill count reads like a perfectly balanced apocalypse.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForAchievementWithAllClasses(stats, PSC_GAME_VERSIONS.CLASSIC)
        end,
    },
    {
        id = "class_mixed_warrior_paladin_hunter_rogue_priest_shaman_mage_warlock_druid_1000",
        title = function(a)
            if PSC_GameVersion == PSC_GAME_VERSIONS.CLASSIC then
                return "The Great Leveler"
            else
                return "The Great Leveler (Classic)"
            end
        end,
        description = function(a) return ("Execute %d of each class"):format(a.targetValue) end,
        iconID = 136149,
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Ultimate class extinction achieved. %d corpses per class. You've reduced all professions to statistical equality through systematic slaughter.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetProgressForAchievementWithAllClasses(stats, PSC_GAME_VERSIONS.CLASSIC)
        end,
    },
    -- {
    --     id = "kills_guild",
    --     title = "Guild Drama Generator",
    --     description = function(a) return ("Eliminate %d guild members"):format(a.targetValue) end,
    --     iconID = 134473,
    --     achievementPoints = 50,
    --     targetValue = 500,
    --     condition = function(achievement, stats)
    --         return achievement.progress(achievement, stats) >= achievement.targetValue
    --     end,
    --     unlocked = false,
    --     completedDate = nil,
    --     subText = function(a)
    --         return ("%d so-called 'guildmates' slaughtered! Turns out, that guild tag above their heads didn’t make them any less squishy. Maybe they should try a PvE guild—less world PvP, more coping in raid chat.")
    --             :format(a.targetValue)
    --     end,
    --     progress = function(achievement, stats)
    --         return stats.guildStatusData["In Guild"] or 0
    --     end,
    -- },
    {-- Kill Streak Achievements
        id = "streaks_kills_25",
        title = "Serial Killer",
        description = function(a) return ("Achieve a %d-player kill streak"):format(a.targetValue) end,
        iconID = 133728,
        achievementPoints = 10,
        targetValue = 25,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d players deleted in a row! The graveyard is installing a '[YOUR NAME] Express Lane' with a self-checkout option.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.highestKillStreak or 0
        end,
    },
    {
        id = "streaks_kills_50",
        title = "Crime Scene",
        description = function(a) return ("Achieve a %d-player kill streak"):format(a.targetValue) end,
        iconID = 132297,
        achievementPoints = 25,
        targetValue = 50,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d consecutive kills! Azeroth's investigators are gathering evidence, but all the witnesses keep mysteriously disappearing.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.highestKillStreak or 0
        end,
    },
    {
        id = "streaks_kills_75",
        title = "Mass Extinction",
        description = function(a) return ("Achieve a %d-player kill streak"):format(a.targetValue) end,
        iconID = 132151,
        achievementPoints = 50,
        targetValue = 75,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills without dying? Players are filing tickets claiming you're hacking. Blizzard responded: 'No, they're just that good.'")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.highestKillStreak or 0
        end,
    },
    {
        id = "streaks_kills_100",
        title = "TRIPLE D!!!",
        description = function(a) return ("Achieve a %d-player kill streak"):format(a.targetValue) end,
        iconID = 236336,
        achievementPoints = 75,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Triple digits! Damage, Devastation, Depression — the enemy faction unlocked all three achievements at once.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.highestKillStreak or 0
        end,
    },
    {
        id = "streaks_kills_125",
        title = "PvP Plague",
        description = function(a) return ("Achieve a %d-player kill streak"):format(a.targetValue) end,
        iconID = 136123,
        achievementPoints = 75,
        targetValue = 125,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You're not a player anymore—you're a server-wide debuff. Whole zones avoid you like it's patch day. %d kills and not a single scratch? That’s not PvP. That’s population control.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.highestKillStreak or 0
        end,
    },
    {
        id = "streaks_kills_150",
        title = "Fine Wine",
        description = function(a) return ("Achieve a %d-player kill streak"):format(a.targetValue) end,
        iconID = 132789,
        achievementPoints = 100,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d uninterrupted kills! You're not just killing players—you're killing server populations. Like a fine wine, your murder spree only improves with time.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.highestKillStreak or 0
        end,
    },
    {
        id = "streaks_kills_175",
        title = "Unstoppable Force",
        description = function(a) return ("Achieve a %d-player kill streak"):format(a.targetValue) end,
        iconID = 133050,
        achievementPoints = 125,
        targetValue = 175,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d bodies and counting! Like the legendary Alterac Valley weapon, you've become a force of nature—slow, powerful, and absolutely devastating. The Immovable Object has finally met its match, and it's your kill streak. Players have started putting 'killed by [YOUR NAME]' in their forum signatures as a badge of honor.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.highestKillStreak or 0
        end,
    },
    {
        id = "streaks_kills_200",
        title = "Top 0.01%",
        description = function(a) return ("Achieve a %d-player kill streak"):format(a.targetValue) end,
        iconID = 135227,
        achievementPoints = 125,
        targetValue = 200,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("200 players down! If this were Hearthstone, you'd be Top 0.01%%—instead, you're out here making real card backs out of enemy corpses. Stay legendary.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.highestKillStreak or 0
        end,
    },
    {
        id = "streaks_kills_225",
        title = "/flex",
        description = function(a) return ("Achieve a %d-player kill streak"):format(a.targetValue) end,
        iconID = 136101,
        achievementPoints = 250,
        targetValue = 225,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d unbroken kills! Your /flex emote now causes a 10-yard fear. Even raid bosses check their aggro tables when you log in. Blizzard added a new GM macro: /who [YOUR NAME] – for threat assessment.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.highestKillStreak or 0
        end,
    },
    {
        id = "streaks_kills_250",
        title = "Thumbs up!",
        description = function(a) return ("Achieve a %d-player kill streak"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236375",
        achievementPoints = 250,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("https://knowyourmeme.com/memes/brent-rambo")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.highestKillStreak or 0
        end,
    },
    {
        id = "streaks_kills_275",
        title = "Faction Change Approved",
        description = function(a) return ("Achieve a %d-player kill streak"):format(a.targetValue) end,
        iconID = 1126583,
        achievementPoints = 250,
        targetValue = 275,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d victims later, half your enemies swapped factions. The rest swapped hobbies.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.highestKillStreak or 0
        end,
    },
    {
        id = "streaks_kills_300",
        title = "Main Character Syndrome",
        description = function(a) return ("Achieve a %d-player kill streak"):format(a.targetValue) end,
        iconID = 1126585,
        achievementPoints = 500,
        targetValue = 300,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d corpses. They logged onto their 'real' mains... and you killed those too. Dreams crushed.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.highestKillStreak or 0
        end,
    },
    {
        id = "streaks_kills_325",
        title = "Delete or Be Deleted",
        description = function(a) return ("Achieve a %d-player kill streak"):format(a.targetValue) end,
        iconID = 442272,
        achievementPoints = 500,
        targetValue = 325,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You didn't just defeat %d players — you defeated their entire friends list too.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.highestKillStreak or 0
        end,
    },
    {
        id = "streaks_kills_350",
        title = "Unsubbed and Unloved",
        description = function(a) return ("Achieve a %d-player kill streak"):format(a.targetValue) end,
        iconID = 135767,
        achievementPoints = 500,
        targetValue = 350,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d unsubbed. Blizzard sent them a 'we miss you' email — and you a trophy. SICK!")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.highestKillStreak or 0
        end,
    },
    {
        id = "kills_guildless",
        title = "Lone Wolf Hunter",
        description = function(a) return ("Eliminate %d guildless players"):format(a.targetValue) end,
        iconID = 132203,
        achievementPoints = 50,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Sent %d 'social anxiety' players back to retail! Their 'I don't need a guild to play' attitude didn't help against your killing spree. At least they didn't have to explain their deaths in guild chat.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.guildStatusData["No Guild"] or 0
        end,
    },
    {
        id = "kills_guild_25_same",
        title = "Guild Crasher",
        description = function(a) return ("Eliminate %d players from the same guild"):format(a.targetValue) end,
        iconID = 134473,
        achievementPoints = 25,
        targetValue = 25,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d guild members eliminated! Their Discord server now has more 'F' reactions than actual messages. Guild recruitment posts updated to include 'PTSD counseling available.'")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.maxSameGuildKills or 0
        end,
    },
    {
        id = "kills_guild_50_same",
        title = "Guild Extinction Event",
        description = function(a) return ("Eliminate %d players from the same guild"):format(a.targetValue) end,
        iconID = 134471,
        achievementPoints = 50,
        targetValue = 50,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d members of the same guild sent packing! You've caused more guild drama than a ninja-looted rare mount. Their group therapy sessions are booked solid.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.maxSameGuildKills or 0
        end,
    },
    {
        id = "kills_guild_75_same",
        title = "Guild Disbander",
        description = function(a) return ("Eliminate %d players from the same guild"):format(a.targetValue) end,
        iconID = 134472,
        achievementPoints = 75,
        targetValue = 75,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d guild members deleted! The guild bank is now just a memorial to better times. Their Discord renamed to 'Survivors Anonymous' with declining membership.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.maxSameGuildKills or 0
        end,
    },
    {
        id = "kills_guild_100_same",
        title = "Guild Genocide",
        description = function(a) return ("Eliminate %d players from the same guild"):format(a.targetValue) end,
        iconID = 134470,
        achievementPoints = 100,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d members obliterated! You've achieved complete guild annihilation. Their recruitment posts now specify 'emotional stability required' as a hard requirement.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.maxSameGuildKills or 0
        end,
    },
    {
        id = "kills_guild_25_different",
        title = "Guild Hopper",
        description = function(a) return ("Eliminate players from %d different guilds"):format(a.targetValue) end,
        iconID = 134328,
        achievementPoints = 25,
        targetValue = 25,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Killed members from %d different guilds! You're like a traveling door-to-door salesman, except you're selling death and business is booming.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.uniqueGuildsKilled or 0
        end,
    },
    {
        id = "kills_guild_50_different",
        title = "Inter-Guild Warfare",
        description = function(a) return ("Eliminate players from %d different guilds"):format(a.targetValue) end,
        iconID = 134327,
        achievementPoints = 50,
        targetValue = 50,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Assassinated members from %d different guilds! You've united the server in one common goal: avoiding you. Monthly guild meetings now include trauma counseling.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.uniqueGuildsKilled or 0
        end,
    },
    {
        id = "kills_guild_125_same",
        title = "Guild Annihilation Protocol",
        description = function(a) return ("Eliminate %d players from the same guild"):format(a.targetValue) end,
        iconID = 134468,
        achievementPoints = 125,
        targetValue = 125,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d members eliminated! Their guild charter changed to a death certificate. The remaining members hired lawyers, but they keep mysteriously dying too.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.maxSameGuildKills or 0
        end,
    },
    {
        id = "kills_guild_150_same",
        title = "Guild Extinction Protocol",
        description = function(a) return ("Eliminate %d players from the same guild"):format(a.targetValue) end,
        iconID = 134467,
        achievementPoints = 125,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d guild members sent to the afterlife! Their Discord requires therapy credentials to join. Recruitment updated to 'fast respawn times preferred.'")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.maxSameGuildKills or 0
        end,
    },
    {
        id = "kills_guild_200_same",
        title = "Guild Apocalypse",
        description = function(a) return ("Eliminate %d players from the same guild"):format(a.targetValue) end,
        iconID = 134466,
        achievementPoints = 250,
        targetValue = 200,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d members absolutely destroyed! The guild name added to the endangered species list. Archaeological teams studying their guild hall remains.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.maxSameGuildKills or 0
        end,
    },
    {
        id = "kills_guild_75_different",
        title = "Guild Network Destroyer",
        description = function(a) return ("Eliminate players from %d different guilds"):format(a.targetValue) end,
        iconID = 134326,
        achievementPoints = 125,
        targetValue = 75,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Eliminated members from %d different guilds! Guild leaders formed a 'Stop the Madness' coalition. Meeting attendance: 10%% (everyone's too scared to leave town).")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.uniqueGuildsKilled or 0
        end,
    },
    {
        id = "kills_guild_100_different",
        title = "Server-Wide Guild Pandemic",
        description = function(a) return ("Eliminate players from %d different guilds"):format(a.targetValue) end,
        iconID = 134325,
        achievementPoints = 250,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Devastated members from %d different guilds! You've united every guild in shared trauma. The server forums have a support group sticky with more posts than trading.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.uniqueGuildsKilled or 0
        end,
    },
    {
        id = "kills_favorite_target",
        title = "Personal Vendetta",
        description = function(a) return ("Kill the same player %d times"):format(a.targetValue) end,
        iconID = 136168,
        achievementPoints = 100,
        targetValue = 10,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            local charactersToProcess = {}
            local currentCharacterKey = PSC_GetCharacterKey()
            charactersToProcess[currentCharacterKey] = PSC_DB.PlayerKillCounts.Characters[currentCharacterKey]
            local stats = PSC_CalculateSummaryStatistics(charactersToProcess)
            local playerName = stats.mostKilledPlayer or "Unknown"
            local killCount = stats.mostKilledCount or 0

            if playerName == "None" or killCount < 10 then
                return "You have developed an unhealthy obsession with " .. playerName
            end
            return playerName ..
                " has died to you " ..
                killCount ..
                " times! They've added your name to their '/who' macro and log off the moment you appear online. Their guild required them to change their hearthstone to a new continent just to avoid you. Every night, they check under their bed for [YOUR NAME] before going to sleep."
        end,
        progress = function(achievement, stats)
            return stats.mostKilledCount or 0
        end,
    },
    {
        id = "kills_multi_3",
        title = "Triple Kill!",
        description = function(a) return ("Get %d kills in a single combat"):format(a.targetValue) end,
        iconID = 236330,
        achievementPoints = 25,
        targetValue = 3,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("ACE! Three champions... er, players... fell to your blade in quick succession. The enemy team is crying 'nerf [YOUR NAME]' in all chat. Your Summoner Score is rising!")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.highestMultiKill or 0
        end,
    },
    {
        id = "kills_multi_4",
        title = "QUADRA KILL!",
        description = function(a) return ("Get %d kills in a single combat"):format(a.targetValue) end,
        iconID = 236341,
        achievementPoints = 50,
        targetValue = 4,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("The crowd goes wild as you secure your fourth elimination! 'GG [YOUR NAME] diff' echoes across Azeroth. The enemy team is calling for a surrender vote while spamming 'Report jungler no ganks' in chat.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.highestMultiKill or 0
        end,
    },
    {
        id = "kills_multi_5",
        title = "PENTAKILL!!",
        description = function(a) return ("Get %d kills in a single combat"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236383",
        achievementPoints = 100,
        targetValue = 5,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("LEGENDARY! You just went full Faker on these noobs! 'GG EZ' has never been more appropriate. The enemy team pressed Alt + F4 simultaneously and uninstalled the game. Your MVP status is unrivaled, and Riot Games is sending you a cease and desist letter for being too OP.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.highestMultiKill or 0
        end,
    },
    {
        id = "kills_multi_10",
        title = "DECA-STRUCTION!",
        description = function(a) return ("Get %d kills in a single combat"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236381",
        achievementPoints = 250,
        targetValue = 10,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("TEN PLAYERS IN ONE GO! This isn't PvP anymore—it's a mass extinction event! League of Legends players are accusing you of 'killstealing,' Blizzard devs are analyzing your combat logs for exploits, and forum moderators had to create a special thread just for the salt. The enemy faction has officially added 'Avoid [YOUR NAME] at all costs' to their leveling guides. Your name now triggers PTSD in half the server population.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.highestMultiKill or 0
        end,
    },
    {
        id = "kills_grey_level",
        title = "Teach them young",
        description = function(a) return ("Eliminate %d grey-level players"):format(a.targetValue) end,
        iconID = 134435,
        achievementPoints = 100,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a) return ("It ain't much but it's honest work!"):format(a.targetValue) end,
        progress = function(achievement, stats)
            local characterKey = PSC_GetCharacterKey()
            local characterData = PSC_DB.PlayerKillCounts.Characters[characterKey]
            return characterData.GrayKillsCount or 0
        end,
    },
    {
        id = "kills_grey_level_2",
        title = "Teach them even younger",
        description = function(a) return ("Eliminate %d grey-level players"):format(a.targetValue) end,
        iconID = 134436,
        achievementPoints = 250,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a) return ("The playground bully graduated to world PvP. Your dedication to mentoring newbies through respawn timers is truly inspiring!"):format(a.targetValue) end,
        progress = function(achievement, stats)
            local characterKey = PSC_GetCharacterKey()
            local characterData = PSC_DB.PlayerKillCounts.Characters[characterKey]
            return characterData.GrayKillsCount or 0
        end,
    },
    {
        id = "kills_grey_level_3",
        title = "Teach the Whole Kindergarten",
        description = function(a) return ("Eliminate %d grey-level players"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236702",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a) return ("%d grey corpses and counting. You've stopped calling it 'ganking' and started calling it 'curriculum.'"):format(a.targetValue) end,
        progress = function(achievement, stats)
            local characterKey = PSC_GetCharacterKey()
            local characterData = PSC_DB.PlayerKillCounts.Characters[characterKey]
            return characterData.GrayKillsCount or 0
        end,
    },
    {
        id = "kills_grey_level_4",
        title = "This Should Be Illegal",
        description = function(a) return ("Eliminate %d grey-level players"):format(a.targetValue) end,
        iconID = 134326,
        achievementPoints = 500,
        targetValue = 10000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a) return ("%d grey-level players sent to the graveyard. Somewhere, a Blizzard GM is drafting a new EULA clause just for you."):format(a.targetValue) end,
        progress = function(achievement, stats)
            local characterKey = PSC_GetCharacterKey()
            local characterData = PSC_DB.PlayerKillCounts.Characters[characterKey]
            return characterData.GrayKillsCount or 0
        end,
    },
    {
        id = "kills_spawn_camper",
        title = "Spawn Camper",
        description = function(a) return "Slay 10 level 1 players in under 1 minute" end,
        iconID = 132090,
        achievementPoints = 50,
        targetValue = 10,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return "You really showed those level 1s who's boss!"
        end,
        progress = function(achievement, stats)
            local characterKey = PSC_GetCharacterKey()
            local characterData = PSC_DB.PlayerKillCounts.Characters[characterKey]

            -- Return the cached maximum - this represents the best 60-second window ever achieved
            -- It's updated incrementally when level 1 kills happen
            return characterData.SpawnCamperMaxKills or 0
        end,
    },
    {
        id = "bonus_big_game_1",
        title = "High Level, High Cope",
        description = function(a) return ("Eliminate %d level ?? players"):format(a.targetValue) end,
        iconID = 135614,
        achievementPoints = 0,
        targetValue = 50,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("They thought your grey level meant free kill. Their damage numbers were bigger, their egos were even bigger. Too bad your killshot is the only number that mattered.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.levelData["??"] or 0
        end,
    },
    {
        id = "bonus_big_game_2",
        title = "Big Game Hunter",
        description = function(a) return ("Eliminate %d level ?? players"):format(a.targetValue) end,
        iconID = 135614,
        achievementPoints = 0,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("No mains to switch to. No excuses left. Just one sad loading screen and the crushing realization: this was their peak.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return stats.levelData["??"] or 0
        end,
    },
    {
        id = "bonus_anniversary_march_25",
        title = "Happy Death Day",
        description = function(a) return ("Kill %d player(s) on March 25th — PvP Stats (Classic)'s anniversary"):format(a.targetValue) end,
        iconID = 134142,
        achievementPoints = 0,
        targetValue = 1,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return "March 25th. The day PvP Stats (Classic) entered the world — and someone else left it. One year older. One more body on the ledger. Blow out the candles, sharpen the blade, and keep the killcount climbing. Many happy returns."
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsBySpecialCondition("anniversary_march_25_2026plus")
        end,
    },
    {
        id = "bonus_severussnipe_birthday",
        title = "Severussnipe's Birthday Bash",
        description = function(a) return ("Kill %d players on August 26th — Severussnipe's birthday"):format(a.targetValue) end,
        iconID = 133783,
        achievementPoints = 0,
        targetValue = 10,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills on August 26th. No cake was harmed — just %d players who logged in on Severussnipe's birthday and paid for it."):format(a.targetValue, a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsBySpecialDate("severussnipe_birthday")
        end,
    },
    {
        id = "bonus_hkfarmer_birthday",
        title = "Hkfarmer's Birthday Bash",
        description = function(a) return ("Kill %d players on June 12th — Hkfarmer's birthday"):format(a.targetValue) end,
        iconID = 133783,
        achievementPoints = 0,
        targetValue = 10,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills on June 12th. The best birthday present you could give Hkfarmer: a fresh pile of corpses."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsBySpecialDate("hkfarmer_birthday")
        end,
    },
    {
        id = "zone_alliance_durotar",
        title = "Durotar Dominator",
        description = function(a) return ("Eliminate %d players in Durotar"):format(a.targetValue) end,
        iconID = 236756,
        achievementPoints = 50,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You turned Durotar into a no-fly zone for Alliance. Razor Hill guards are asking for YOUR autograph. %d kills and counting!")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Durotar")
        end,
    },
    {
        id = "zone_alliance_barrens",
        title = "Barrens Butcher",
        description = function(a) return ("Eliminate %d players in The Barrens"):format(a.targetValue) end,
        iconID = 236717,
        achievementPoints = 50,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in The Barrens! You made Barrens chat go silent. Even Mankrik’s wife is impressed.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "The Barrens")
        end,
    },
    {
        id = "zone_alliance_barrens_250",
        title = "Barrens Chat Moderator",
        description = function(a) return ("Eliminate %d players in The Barrens"):format(a.targetValue) end,
        iconID = 236718,
        achievementPoints = 100,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in The Barrens! You've permanently banned more Horde from Barrens chat than any GM ever could. Chuck Norris jokes have been replaced with warnings about you.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "The Barrens")
        end,
    },
    {
        id = "zone_alliance_tirisfal",
        title = "Tirisfal Terror",
        description = function(a) return ("Eliminate %d players in Tirisfal Glades"):format(a.targetValue) end,
        iconID = 236849,
        achievementPoints = 50,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d bodies dropped in Tirisfal! Even the Forsaken are considering a second death.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Tirisfal Glades")
        end,
    },
    {
        id = "zone_alliance_stonetalon",
        title = "Stonetalon Slaughterer",
        description = function(a) return ("Eliminate %d players in Stonetalon Mountains"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236831",
        achievementPoints = 50,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Stonetalon! The only thing more toxic than the air here is your kill streak.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Stonetalon Mountains")
        end,
    },

    -- =====================================================
    -- ADDITIONAL ZONE ACHIEVEMENTS - CONTESTED ZONES
    -- =====================================================

    -- REDRIDGE MOUNTAINS (Horde) - Adding missing tiers
    {
        id = "zone_horde_redridge_100",
        title = "Redridge Reaper",
        description = function(a) return ("Eliminate %d players in Redridge Mountains"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236814",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Alliance fell in Redridge! The local guards are asking for hazard pay, and Lakeshire Inn is considering a 'death insurance' policy for guests.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Redridge Mountains")
        end,
    },
    {
        id = "zone_horde_redridge_250",
        title = "Redridge Ravager",
        description = function(a) return ("Eliminate %d players in Redridge Mountains"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236814",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d kills in Redridge, you've made the zone so dangerous that even the gnolls are filing insurance claims. Stormwind is considering declaring it a disaster area.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Redridge Mountains")
        end,
    },
    {
        id = "zone_horde_redridge",
        title = "Redridge Population Control",
        description = function(a) return ("Eliminate %d players in Redridge Mountains"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236814",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Congratulations. You made an entire zone regret installing the game.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Redridge Mountains")
        end,
    },
    {
        id = "zone_horde_redridge_1000",
        title = "The Redridge Apocalypse",
        description = function(a) return ("Eliminate %d players in Redridge Mountains"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236814",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills in Redridge, the zone has been renamed 'Bloodridge Mountains' on official Alliance maps. You've created more orphans than the Third War. Stormwind City Council is considering building a memorial wall just for your victims.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Redridge Mountains")
        end,
    },

    -- STONETALON MOUNTAINS (Alliance)
    {
        id = "zone_alliance_stonetalon_250",
        title = "Stonetalon Executioner",
        description = function(a) return ("Eliminate %d players in Stonetalon Mountains"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236831",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d Horde dead, Stonetalon's toxic air is the least of their problems. Even the Venture Co. goblins are impressed by your efficiency in 'resource extraction.'")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Stonetalon Mountains")
        end,
    },
    {
        id = "zone_alliance_stonetalon_500",
        title = "Stonetalon Annihilator",
        description = function(a) return ("Eliminate %d players in Stonetalon Mountains"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236831",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Stonetalon! The mountains themselves are considering relocating to a safer zone. Your body count is higher than the peak elevation.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Stonetalon Mountains")
        end,
    },
    {
        id = "zone_alliance_stonetalon_1000",
        title = "The Stonetalon Catastrophe",
        description = function(a) return ("Eliminate %d players in Stonetalon Mountains"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236831",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, Stonetalon Mountains has been renamed 'Bonetal on Mountains' by surviving Horde. The Venture Co. has offered you a management position in their 'Hostile Takeover' department.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Stonetalon Mountains")
        end,
    },

    -- ASHENVALE (Contested) - All 4 tiers
    {
        id = "zone_ashenvale_100",
        title = "Ashenvale Assassin",
        description = function(a) return ("Eliminate %d players in Ashenvale"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236713",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Ashenvale! The Sentinels are requesting backup, and the ancient trees are considering an early autumn to avoid witnessing more carnage.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Ashenvale")
        end,
    },
    {
        id = "zone_ashenvale_250",
        title = "Ashenvale Exterminator",
        description = function(a) return ("Eliminate %d players in Ashenvale"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236713",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses fertilizing Ashenvale, the forest is growing at an alarming rate! Druids are filing environmental impact reports about your 'composting' methods.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Ashenvale")
        end,
    },
    {
        id = "zone_ashenvale_500",
        title = "Ashenvale Apocalypse",
        description = function(a) return ("Eliminate %d players in Ashenvale"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236713",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Ashenvale! The wisps are organizing a support group for trauma victims. Even Cenarius is considering a career change to avoid your 'forest management' style.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Ashenvale")
        end,
    },
    {
        id = "zone_ashenvale_1000",
        title = "The Ashenvale Cataclysm",
        description = function(a) return ("Eliminate %d players in Ashenvale"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236713",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, Ashenvale has been declared a 'Natural Disaster Zone' by both factions. The World Tree is considering relocating. Your name is carved into every trunk as a warning to future generations.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Ashenvale")
        end,
    },

    -- DUSKWOOD (Horde) - Adding missing tiers
        {
        id = "zone_horde_duskwood",
        title = "Darkshire Destroyer",
        description = function(a) return ("Eliminate %d players in Duskwood"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236757",
        achievementPoints = 50,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("The Night Watch counted %d fresh corpses and decided to rename Darkshire to 'Deadshire'! Mor'Ladim is feeling professionally threatened, and Stiches filed for unemployment.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Duskwood")
        end,
    },
    {
        id = "zone_horde_duskwood_250",
        title = "Duskwood Devastator",
        description = function(a) return ("Eliminate %d players in Duskwood"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236757",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d kills, Duskwood is now officially darker than its name suggests. The undead residents are filing noise complaints about all the screaming.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Duskwood")
        end,
    },
    {
        id = "zone_horde_duskwood_500",
        title = "Duskwood Doomsday",
        description = function(a) return ("Eliminate %d players in Duskwood"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236757",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d corpses in Duskwood! Even Stitches is asking for your autograph. The Scythe of Elune dims in comparison to your killing streak.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Duskwood")
        end,
    },
    {
        id = "zone_horde_duskwood_1000",
        title = "The Duskwood Eclipse",
        description = function(a) return ("Eliminate %d players in Duskwood"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236757",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, Duskwood has achieved permanent midnight. The Worgen are howling in fear, not rage. Local ghost tours now include your kill locations as premium stops.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Duskwood")
        end,
    },

    -- HILLSBRAD FOOTHILLS (Contested) - All 4 tiers
    {
        id = "zone_hillsbrad_100",
        title = "Hillsbrad Hunter",
        description = function(a) return ("Eliminate %d players in Hillsbrad Foothills"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236779",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Hillsbrad! Tarren Mill and Southshore are considering a peace treaty just to deal with you. The hillsides are littered with more bodies than flowers.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Hillsbrad Foothills")
        end,
    },
    {
        id = "zone_hillsbrad_250",
        title = "Hillsbrad Havoc",
        description = function(a) return ("Eliminate %d players in Hillsbrad Foothills"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236779",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses in Hillsbrad, the farmers are switching to bone meal fertilizer. The ongoing war between Tarren Mill and Southshore seems peaceful compared to your rampage.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Hillsbrad Foothills")
        end,
    },
    {
        id = "zone_hillsbrad_500",
        title = "Hillsbrad Hunter",
        description = function(a) return ("Eliminate %d players in Hillsbrad Foothills"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236779",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Hillsbrad! The zone's famous for PvP battles, but now it's famous for your personal war crimes. Travel brochures have been updated to include survivor testimonies.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Hillsbrad Foothills")
        end,
    },
    {
        id = "zone_hillsbrad_1000",
        title = "The Hillsbrad Hegemon",
        description = function(a) return ("Eliminate %d players in Hillsbrad Foothills"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236779",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, both Tarren Mill and Southshore have erected statues of you as a 'Shared Threat Memorial.' You've achieved what diplomacy never could: unity through terror.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Hillsbrad Foothills")
        end,
    },

    -- THOUSAND NEEDLES (Alliance) - All 4 tiers
    {
        id = "zone_alliance_needles_100",
        title = "Thousand Needles Nightmare",
        description = function(a) return ("Eliminate %d players in Thousand Needles"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236848",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d Horde fell in Thousand Needles! The Centaur are impressed by your hunting skills, and the Shimmering Flats have more bodies than mirages.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Thousand Needles")
        end,
    },
    {
        id = "zone_alliance_needles_250",
        title = "Thousand Needles Terror",
        description = function(a) return ("Eliminate %d players in Thousand Needles"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236848",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d kills, Thousand Needles now has a thousand corpses to match! The racing teams in Shimmering Flats are using your kill locations as course markers.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Thousand Needles")
        end,
    },
    {
        id = "zone_alliance_needles_500",
        title = "Thousand Needles Tyrant",
        description = function(a) return ("Eliminate %d players in Thousand Needles"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236848",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d corpses dot Thousand Needles like deadly cacti! Even the salt flats are seasoned with blood now. The Centaur have nominated you for their 'Hunter of the Century' award.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Thousand Needles")
        end,
    },
    {
        id = "zone_alliance_needles_1000",
        title = "The Thousand Needles Overlord",
        description = function(a) return ("Eliminate %d players in Thousand Needles"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236848",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, Thousand Needles has been renamed 'Thousand Corpses' by the Horde. The zone is now considered a natural wonder - a testament to one player's dedication to mass murder.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Thousand Needles")
        end,
    },

    -- ALTERAC MOUNTAINS (Contested) - All 4 tiers
    {
        id = "zone_alterac_100",
        title = "Alterac Assassin",
        description = function(a) return ("Eliminate %d players in Alterac Mountains"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236711",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Alterac Mountains! The yeti are considering hibernating permanently to avoid witnessing more bloodshed. Even the Syndicate is impressed by your criminal efficiency.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Alterac Mountains")
        end,
    },
    {
        id = "zone_alterac_250",
        title = "Alterac Annihilator",
        description = function(a) return ("Eliminate %d players in Alterac Mountains"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236711",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses frozen in Alterac, you've created a winter wonderland of death! The Frostwolf and Stormpike clans have called a temporary ceasefire to deal with the 'you' problem.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Alterac Mountains")
        end,
    },
    {
        id = "zone_alterac_500",
        title = "Alterac Apocalypse",
        description = function(a) return ("Eliminate %d players in Alterac Mountains"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236711",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Alterac! The mountains are red with blood, and the snow won't melt because it's too busy being a crime scene. Alterac Valley battleground seems peaceful in comparison.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Alterac Mountains")
        end,
    },
    {
        id = "zone_alterac_1000",
        title = "The Alterac Overlord",
        description = function(a) return ("Eliminate %d players in Alterac Mountains"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236711",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, Alterac Mountains has been designated a 'Monument to Malice.' Both factions agree that you make the Scourge look friendly. The mountain peaks are now known as the 'Monuments of [YOUR NAME].'")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Alterac Mountains")
        end,
    },

    -- ARATHI HIGHLANDS (Contested) - All 4 tiers
    {
        id = "zone_arathi_100",
        title = "Arathi Aggressor",
        description = function(a) return ("Eliminate %d players in Arathi Highlands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236712",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Arathi Highlands! The Arathi Basin battleground looks tame compared to your personal war. The ogres in Boulderfist Hall are taking notes on your techniques.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Arathi Highlands")
        end,
    },
    {
        id = "zone_arathi_250",
        title = "Arathi Annihilator",
        description = function(a) return ("Eliminate %d players in Arathi Highlands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236712",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses in Arathi, the Highland has become a lowland of death! The Syndicate and the Boulderfist ogres have formed an alliance just to avoid you.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Arathi Highlands")
        end,
    },
    {
        id = "zone_arathi_500",
        title = "Arathi Apocalypse",
        description = function(a) return ("Eliminate %d players in Arathi Highlands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236712",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Arathi! The ancient ruins are now modern graveyards. Archaeologists are more interested in studying your kill patterns than ancient artifacts.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Arathi Highlands")
        end,
    },
    {
        id = "zone_arathi_1000",
        title = "The Arathi Emperor",
        description = function(a) return ("Eliminate %d players in Arathi Highlands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236712",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, you've claimed dominion over Arathi Highlands. The ancient Arathi Empire pales in comparison to your reign of terror. History books will remember this as the '[YOUR NAME] Era.'")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Arathi Highlands")
        end,
    },

    -- DESOLACE (Contested) - All 4 tiers
    {
        id = "zone_desolace_100",
        title = "Desolace Destroyer",
        description = function(a) return ("Eliminate %d players in Desolace"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236742",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Desolace! You've made a desolate zone even more desolate. The Centaur clans are considering you for honorary membership in their 'Masters of Mayhem' society.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Desolace")
        end,
    },
    {
        id = "zone_desolace_250",
        title = "Desolace Devastator",
        description = function(a) return ("Eliminate %d players in Desolace"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236742",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses scattered across Desolace, you've redecorated the wasteland! Even the demons in the Demon Fall Canyon are impressed by your commitment to chaos.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Desolace")
        end,
    },
    {
        id = "zone_desolace_500",
        title = "Desolace Doomsday",
        description = function(a) return ("Eliminate %d players in Desolace"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236742",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills have made Desolace truly live up to its name! The Burning Legion scouts are taking notes on your efficiency. You've out-desolated desolation itself.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Desolace")
        end,
    },
    {
        id = "zone_desolace_1000",
        title = "The Desolace Despot",
        description = function(a) return ("Eliminate %d players in Desolace"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236742",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, Desolace has been renamed 'The [YOUR NAME] Memorial Wasteland.' Even the demons respect your territory. You've achieved what the Legion couldn't: making Desolace actually scary.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Desolace")
        end,
    },

    -- STRANGLETHORN VALE (Contested) - All 4 tiers
    {
        id = "zone_stranglethorn_100",
        title = "Stranglethorn Stalker",
        description = function(a) return ("Eliminate %d players in Stranglethorn Vale"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236844",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Stranglethorn! The jungle vines are using corpses as fertilizer, and Hemet Nesingwary is asking for hunting tips. The tigers are jealous of your predatory skills.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Stranglethorn Vale")
        end,
    },
    {
        id = "zone_stranglethorn_250",
        title = "Stranglethorn Slaughterer",
        description = function(a) return ("Eliminate %d players in Stranglethorn Vale"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236844",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses feeding the jungle, Stranglethorn has never been more lush! The Bloodsail Buccaneers have offered you a captain's commission in their 'Terror of the Seas' division.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Stranglethorn Vale")
        end,
    },
    {
        id = "zone_stranglethorn_500",
        title = "Stranglethorn Scourge",
        description = function(a) return ("Eliminate %d players in Stranglethorn Vale"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236844",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Stranglethorn! The jungle is so dangerous now that even King Bagoon won't venture out of his cave. You've become the apex predator of the food chain.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Stranglethorn Vale")
        end,
    },
    {
        id = "zone_stranglethorn_1000",
        title = "The Stranglethorn Sovereign",
        description = function(a) return ("Eliminate %d players in Stranglethorn Vale"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236844",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, you rule Stranglethorn Vale absolutely. The jungle bow to your supremacy. Booty Bay has erected a statue in your honor - and also to appease you so you don't sink their port.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Stranglethorn Vale")
        end,
    },

    -- THE HINTERLANDS (Contested) - All 4 tiers
    {
        id = "zone_hinterlands_100",
        title = "Hinterlands Hunter",
        description = function(a) return ("Eliminate %d players in The Hinterlands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236780",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in The Hinterlands! The Wildhammer dwarfs are impressed by your 'aerial superiority' - you drop bodies faster than their gryphons drop altitude.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "The Hinterlands")
        end,
    },
    {
        id = "zone_hinterlands_250",
        title = "Hinterlands Havoc",
        description = function(a) return ("Eliminate %d players in The Hinterlands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236780",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses in The Hinterlands, the trolls of Jintha'Alor are considering you for their pantheon of death gods. Even the forest trolls are scared of your hunting efficiency.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "The Hinterlands")
        end,
    },
    {
        id = "zone_hinterlands_500",
        title = "Hinterlands - 'no-fly zone'",
        description = function(a) return ("Eliminate %d players in The Hinterlands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236780",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills have made The Hinterlands a 'no-fly zone' - literally. Gryphons refuse to land here. The zone's wildlife has formed a support group for trauma survivors.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "The Hinterlands")
        end,
    },
    {
        id = "zone_hinterlands_1000",
        title = "The Hinterlands Hegemon",
        description = function(a) return ("Eliminate %d players in The Hinterlands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236780",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, The Hinterlands has been renamed 'The [YOUR NAME] Lands' on all official maps. You've achieved what no empire could: complete territorial dominance through pure terror.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "The Hinterlands")
        end,
    },

    -- TANARIS (Contested) - All 4 tiers
    {
        id = "zone_tanaris_100",
        title = "Tanaris Terror",
        description = function(a) return ("Eliminate %d players in Tanaris"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236846",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Tanaris! The desert sands are now red with blood instead of just sand. Gadgetzan's insurance rates have skyrocketed since you arrived.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Tanaris")
        end,
    },
    {
        id = "zone_tanaris_250",
        title = "Tanaris Tyrant",
        description = function(a) return ("Eliminate %d players in Tanaris"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236846",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses buried in Tanaris, you've created the largest graveyard in Kalimdor! The Wastewander bandits have disbanded out of professional respect.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Tanaris")
        end,
    },
    {
        id = "zone_tanaris_500",
        title = "Tanaris Tornado",
        description = function(a) return ("Eliminate %d players in Tanaris"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236846",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Tanaris! You've caused more destruction than the Caverns of Time themselves. Nozdormu is considering adding you to the timeline as a 'Temporal Anomaly.'")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Tanaris")
        end,
    },
    {
        id = "zone_tanaris_1000",
        title = "The Tanaris Titan",
        description = function(a) return ("Eliminate %d players in Tanaris"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236846",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, Tanaris has been designated a 'Temporal Hazard Zone.' The Bronze Dragonflight refuses to patrol here. Your legend transcends time itself - mostly because everyone who could tell it is dead.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Tanaris")
        end,
    },

    -- UN'GORO CRATER (Contested) - All 4 tiers
    {
        id = "zone_ungoro_100",
        title = "Un'Goro Undertaker",
        description = function(a) return ("Eliminate %d players in Un'Goro Crater"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236850",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Un'Goro! The dinosaurs are considering you for their 'Apex Predator Hall of Fame.' Even the T-Rex thinks your hunting methods are excessive.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Un'Goro Crater")
        end,
    },
    {
        id = "zone_ungoro_250",
        title = "Un'Goro Extinction Event",
        description = function(a) return ("Eliminate %d players in Un'Goro Crater"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236850",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses in Un'Goro, you've created a fossil record of your own! Paleontologists are naming a new extinction period after you: 'The [YOUR NAME]ocene Era.'")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Un'Goro Crater")
        end,
    },
    {
        id = "zone_ungoro_500",
        title = "Un'Goro Upheaval",
        description = function(a) return ("Eliminate %d players in Un'Goro Crater"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236850",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Un'Goro! You've out-evolved evolution itself. The crater's elemental forces are considering relocating to a safer dimension.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Un'Goro Crater")
        end,
    },
    {
        id = "zone_ungoro_1000",
        title = "The Un'Goro Overlord",
        description = function(a) return ("Eliminate %d players in Un'Goro Crater"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236850",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, Un'Goro Crater has been reclassified as 'The [YOUR NAME] Memorial Impact Site.' You've caused more devastation than the asteroid that killed the dinosaurs - and you did it personally.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Un'Goro Crater")
        end,
    },

    -- FELWOOD (Contested) - All 4 tiers
    {
        id = "zone_felwood_100",
        title = "Felwood Fiend",
        description = function(a) return ("Eliminate %d players in Felwood"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236763",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Felwood! The corruption here has nothing on your moral flexibility. Even the demons are taking notes on your creative torture methods.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Felwood")
        end,
    },
    {
        id = "zone_felwood_250",
        title = "Felwood Firelord",
        description = function(a) return ("Eliminate %d players in Felwood"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236763",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses in Felwood, you've out-corrupted the corruption itself! The Burning Legion scouts are considering you for a leadership position in the 'Department of Atrocities.'")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Felwood")
        end,
    },
    {
        id = "zone_felwood_500",
        title = "Felwood Apocalypse",
        description = function(a) return ("Eliminate %d players in Felwood"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236763",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Felwood! You've made a corrupted forest even more terrifying. The Furbolgs have started worshipping you as a god of war. Archimonde is jealous of your efficiency.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Felwood")
        end,
    },
    {
        id = "zone_felwood_1000",
        title = "The Felwood Overlord",
        description = function(a) return ("Eliminate %d players in Felwood"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236763",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, Felwood has been renamed 'The [YOUR NAME] Dominion.' You've achieved what the Burning Legion couldn't: making a corrupted wasteland actually scary. Sargeras sends his regards... and his resume.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Felwood")
        end,
    },

    -- BADLANDS (Contested) - All 4 tiers
    {
        id = "zone_badlands_100",
        title = "Badlands Brawler",
        description = function(a) return ("Eliminate %d players in Badlands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236716",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Badlands. Even the wasteland thinks you're too much.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Badlands")
        end,
    },
    {
        id = "zone_badlands_250",
        title = "Badlands Butcher",
        description = function(a) return ("Eliminate %d players in Badlands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236716",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses, you've made Badlands worse than its name suggests. The dragons are relocating.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Badlands")
        end,
    },
    {
        id = "zone_badlands_500",
        title = "Badlands Blight",
        description = function(a) return ("Eliminate %d players in Badlands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236716",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills have turned Badlands into 'Deadlands.' You're the reason it's called bad.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Badlands")
        end,
    },
    {
        id = "zone_badlands_1000",
        title = "The Badlands Overlord",
        description = function(a) return ("Eliminate %d players in Badlands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236716",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, Badlands has been renamed '[YOUR NAME]lands.' You've out-badded the Badlands.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Badlands")
        end,
    },

    -- FERALAS (Contested) - All 4 tiers
    {
        id = "zone_feralas_100",
        title = "Feralas Fiend",
        description = function(a) return ("Eliminate %d players in Feralas"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236764",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Feralas. The hippogryphs are afraid to fly here now.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Feralas")
        end,
    },
    {
        id = "zone_feralas_250",
        title = "Feralas Fury",
        description = function(a) return ("Eliminate %d players in Feralas"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236764",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses, Feralas isn't so feral anymore - you are. The druids call you an 'unnatural disaster.'")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Feralas")
        end,
    },
    {
        id = "zone_feralas_500",
        title = "Feralas Firestorm",
        description = function(a) return ("Eliminate %d players in Feralas"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236764",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills have made Feralas less wild, more dead. You've tamed the wilderness with corpses.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Feralas")
        end,
    },
    {
        id = "zone_feralas_1000",
        title = "The Feralas Overlord",
        description = function(a) return ("Eliminate %d players in Feralas"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236764",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, Feralas has been domesticated by death. The only wild thing left is your kill count.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Feralas")
        end,
    },

    -- SEARING GORGE (Contested) - All 4 tiers
    {
        id = "zone_searinggorge_100",
        title = "Searing Gorge Slayer",
        description = function(a) return ("Eliminate %d players in Searing Gorge"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236815",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Searing Gorge. You're hotter than the lava.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Searing Gorge")
        end,
    },
    {
        id = "zone_searinggorge_250",
        title = "Searing Gorge Scorcher",
        description = function(a) return ("Eliminate %d players in Searing Gorge"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236815",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d bodies, you've out-burned the burning. The Dark Iron dwarfs are impressed by your heat.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Searing Gorge")
        end,
    },
    {
        id = "zone_searinggorge_500",
        title = "Searing Gorge Inferno",
        description = function(a) return ("Eliminate %d players in Searing Gorge"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236815",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills have made Searing Gorge actually searing. You're the new fire elemental lord.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Searing Gorge")
        end,
    },
    {
        id = "zone_searinggorge_1000",
        title = "The Searing Gorge Overlord",
        description = function(a) return ("Eliminate %d players in Searing Gorge"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236815",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, you've made Searing Gorge a crematorium. Ragnaros wants your job application.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Searing Gorge")
        end,
    },

    -- BURNING STEPPES (Contested) - All 4 tiers
    {
        id = "zone_burningsteppes_100",
        title = "Burning Steppes Burner",
        description = function(a) return ("Eliminate %d players in Burning Steppes"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236734",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Burning Steppes. You've added fuel to the fire - literally.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Burning Steppes")
        end,
    },
    {
        id = "zone_burningsteppes_250",
        title = "Burning Steppes Blaze",
        description = function(a) return ("Eliminate %d players in Burning Steppes"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236734",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses, you're burning through players faster than the zone burns stone. Step by step, corpse by corpse.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Burning Steppes")
        end,
    },
    {
        id = "zone_burningsteppes_500",
        title = "Burning Steppes Bonfire",
        description = function(a) return ("Eliminate %d players in Burning Steppes"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236734",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills have made you the hottest thing in the Steppes. The dragons are taking notes on your burn rate.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Burning Steppes")
        end,
    },
    {
        id = "zone_burningsteppes_1000",
        title = "The Burning Steppes Overlord",
        description = function(a) return ("Eliminate %d players in Burning Steppes"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236734",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, you've made Burning Steppes your personal furnace. Even Nefarian respects your heat.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Burning Steppes")
        end,
    },

    -- WESTERN PLAGUELANDS (Contested) - All 4 tiers
    {
        id = "zone_westernplaguelands_100",
        title = "Western Plaguelands Plague",
        description = function(a) return ("Eliminate %d players in Western Plaguelands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236851",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Western Plaguelands. You're more infectious than the actual plague.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Western Plaguelands")
        end,
    },
    {
        id = "zone_westernplaguelands_250",
        title = "Western Plaguelands Pandemic",
        description = function(a) return ("Eliminate %d players in Western Plaguelands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236851",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses, you've out-plagues the Plaguelands. The Scourge wants to hire you.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Western Plaguelands")
        end,
    },
    {
        id = "zone_westernplaguelands_500",
        title = "Western Plaguelands Pestilence",
        description = function(a) return ("Eliminate %d players in Western Plaguelands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236851",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills have made you Patient Zero of PvP. The Lich King is jealous of your infection rate.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Western Plaguelands")
        end,
    },
    {
        id = "zone_westernplaguelands_1000",
        title = "The Western Plaguelands Overlord",
        description = function(a) return ("Eliminate %d players in Western Plaguelands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236851",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, you've become the plague the Plaguelands needed. Even the undead are dying again.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Western Plaguelands")
        end,
    },

    -- EASTERN PLAGUELANDS (Contested) - All 4 tiers
    {
        id = "zone_easternplaguelands_100",
        title = "Eastern Plaguelands Executioner",
        description = function(a) return ("Eliminate %d players in Eastern Plaguelands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236760",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Eastern Plaguelands. You're spreading faster than any disease.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Eastern Plaguelands")
        end,
    },
    {
        id = "zone_easternplaguelands_250",
        title = "Eastern Plaguelands Epidemic",
        description = function(a) return ("Eliminate %d players in Eastern Plaguelands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236760",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d bodies, you've made the Eastern Plaguelands properly plagued. The Argent Dawn fears you more than undeath.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Eastern Plaguelands")
        end,
    },
    {
        id = "zone_easternplaguelands_500",
        title = "Eastern Plaguelands Extinction",
        description = function(a) return ("Eliminate %d players in Eastern Plaguelands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236760",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills have made you the final boss of the Plaguelands. Kel'Thuzad wants your resume.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Eastern Plaguelands")
        end,
    },
    {
        id = "zone_easternplaguelands_1000",
        title = "The Eastern Plaguelands Overlord",
        description = function(a) return ("Eliminate %d players in Eastern Plaguelands"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236760",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, you've become the Lich King of PvP. The undead bow to your superior killing skills.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Eastern Plaguelands")
        end,
    },
     -- DEADWIND PASS (Contested) - All 4 tiers
    {
        id = "zone_deadwindpass_100",
        title = "Carrion Caller",
        description = function(a) return ("Eliminate %d players in Deadwind Pass"):format(a.targetValue) end,
        iconID = 135506,
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Karazhan's front yard just got %d bodies messier. Medivh never had to deal with this."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Deadwind Pass")
        end,
    },
    {
        id = "zone_deadwindpass_250",
        title = "Herald of the Dark Tower",
        description = function(a) return ("Eliminate %d players in Deadwind Pass"):format(a.targetValue) end,
        iconID = 135506,
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("The ghosts inside Karazhan are filing noise complaints. Apparently %d deaths outside is disturbing chess night."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Deadwind Pass")
        end,
    },
    {
        id = "zone_deadwindpass_500",
        title = "The Arcane Reaper",
        description = function(a) return ("Eliminate %d players in Deadwind Pass"):format(a.targetValue) end,
        iconID = 135506,
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills on Karazhan's doorstep. The Curator has started logging your massacre as an 'Unauthorized Exhibit.' Moroes is adding %d extra place settings at dinner out of grim respect. The tower's residents haven't seen this much carnage since Medivh went mad - and he was the one causing it last time."):format(a.targetValue, a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Deadwind Pass")
        end,
    },
    {
        id = "zone_deadwindpass_1000",
        title = "Karazhan's Worst Nightmare",
        description = function(a) return ("Eliminate %d players in Deadwind Pass"):format(a.targetValue) end,
        iconID = 135506,
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("One thousand corpses rotting outside the most haunted tower in Azeroth. The Opera House cancelled its show - the audience kept getting killed in the parking lot. Attumen lost his horse again because it refused to step over the bodies. Nightbane lands, sees your handiwork, and quietly flies back to wherever he came from. Even the demons trapped inside Karazhan are petitioning the Dark Portal for asylum. Medivh built his tower to last forever. You're auditioning to replace it."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Deadwind Pass")
        end,
    },

    -- WINTERSPRING (Contested) - All 4 tiers
    {
        id = "zone_winterspring_100",
        title = "Winterspring Warrior",
        description = function(a) return ("Eliminate %d players in Winterspring"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236854",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Winterspring. You're colder than the climate.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Winterspring")
        end,
    },
    {
        id = "zone_winterspring_250",
        title = "Winterspring Wipeout",
        description = function(a) return ("Eliminate %d players in Winterspring"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236854",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d frozen corpses, you've made winter eternal. The yeti are hibernating permanently.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Winterspring")
        end,
    },
    {
        id = "zone_winterspring_500",
        title = "Winterspring Wasteland",
        description = function(a) return ("Eliminate %d players in Winterspring"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236854",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills have frozen Winterspring in fear. You've brought nuclear winter to Azeroth.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Winterspring")
        end,
    },
    {
        id = "zone_winterspring_1000",
        title = "The Winterspring Overlord",
        description = function(a) return ("Eliminate %d players in Winterspring"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236854",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, Winterspring is permanently winter. You've made the Ice Age jealous.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Winterspring")
        end,
    },

    -- SILITHUS (Contested) - All 4 tiers
    {
        id = "zone_silithus_100",
        title = "Silithus Slayer",
        description = function(a) return ("Eliminate %d players in Silithus"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236829",
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills in Silithus. You're buggier than the silithid.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Silithus")
        end,
    },
    {
        id = "zone_silithus_250",
        title = "Silithus Swarm",
        description = function(a) return ("Eliminate %d players in Silithus"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236829",
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses, you've out-swarmed the silithid. C'Thun is impressed by your hive mind mentality.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Silithus")
        end,
    },
    {
        id = "zone_silithus_500",
        title = "Silithus Sandstorm",
        description = function(a) return ("Eliminate %d players in Silithus"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236829",
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d kills have made you the apex predator of the desert. The Old Gods want your autograph.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Silithus")
        end,
    },
    {
        id = "zone_silithus_1000",
        title = "The Silithus Overlord",
        description = function(a) return ("Eliminate %d players in Silithus"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236829",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, you've become the Fifth Old God. C'Thun fears your whispers of death.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Silithus")
        end,
    },

{
        id = "zone_horde_elwynn",
        title = "Elwynn Exterminator",
        description = function(a) return ("Eliminate %d players in Elwynn Forest"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236761",
        achievementPoints = 50,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d deaths in Elwynn, local humans are painting themselves green and practicing their 'zug zug'! Goldshire Inn's new special: 'Reroll Horde, Get Free Hearthstone to Durotar.' Even Marshal Dughan is considering a career in Orgrimmar.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Elwynn Forest")
        end,
    },
    {
        id = "zone_horde_elwynn_250",
        title = "Elwynn Forest Nightmare",
        description = function(a) return ("Eliminate %d players in Elwynn Forest"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236761",
        achievementPoints = 100,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d massacres in Elwynn, Stormwind has declared the forest a restricted zone. New players are being spawned directly in Westfall to avoid you. The local wildlife has organized a support group for trauma survivors. Even the kobolds are saying 'You no take our candle... please, just leave us alone!'")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Elwynn Forest")
        end,
    },
    {
        id = "zone_horde_westfall",
        title = "[YOUR NAME] x Defias Traitor",
        description = function(a) return ("Eliminate %d players in Westfall"):format(a.targetValue) end,
        iconID =  "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236852",
        achievementPoints = 50,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("[YOUR NAME] x Defias Traitor vs. Westfall - the crossover nobody wanted, but %d players paid the price anyway, making Westfall unplayable.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Westfall")
        end,
    },
    {
        id = "zone_horde_westfall_250",
        title = "[YOUR NAME] x Defias Brotherhood - The Sequel",
        description = function(a) return ("Eliminate %d players in Westfall"):format(a.targetValue) end,
        iconID =  "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236852",
        achievementPoints = 100,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("The crossover event continues! After %d kills, even the Defias Brotherhood is impressed by your work. VanCleef is offering you a job interview. The Deadmines tour guides now include your name in the 'Local Dangers' section. Farmers have stopped growing crops and started growing gravestones instead - business is booming!")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Westfall")
        end,
    },
    {
        id = "time_night_shift_half",
        title = "Midnight Marauder",
        description = function(a) return ("Eliminate %d players between 10 PM - 6 AM"):format(a.targetValue) end,
        iconID = 136057,
        achievementPoints = 50,
        targetValue = 1250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Halfway to ruining %d late-night gaming sessions! You're the reason parents everywhere are installing parental controls. These night owls thought darkness was their friend - you taught them it's their enemy.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByTimeRangeName("night_shift") -- 10 PM to 6 AM, optimized
        end,
    },
    {
        id = "time_night_shift",
        title = "Night Shift Nightmare",
        description = function(a) return ("Eliminate %d players between 10 PM - 6 AM"):format(a.targetValue) end,
        iconID = 136057,
        achievementPoints = 100,
        targetValue = 2500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Ruined %d late-night gaming sessions! Parents worldwide grateful for your 'mandatory bedtime enforcement.' Energy drink sales in your region mysteriously plummeted.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByTimeRangeName("night_shift") -- 10 PM to 6 AM, optimized
        end,
    },
    {
        id = "time_lunch_hour_half",
        title = "Quick Bite Killer",
        description = function(a) return ("Eliminate %d players during lunch hour (12 PM - 2 PM, Mon-Fri)"):format(a.targetValue) end,
        iconID = 134062,
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've ruined %d quick lunch breaks! Halfway to becoming the corporate productivity booster. These players thought they could sneak in a quick game during lunch - you served them a knuckle sandwich instead.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByCombination("lunch_weekdays") -- 12-2 PM on weekdays, optimized
        end,
    },
    {
        id = "time_lunch_hour",
        title = "Lunch Break Liquidator",
        description = function(a) return ("Eliminate %d players during lunch hour (12 PM - 2 PM, Mon-Fri)"):format(a.targetValue) end,
        iconID = 134062,
        achievementPoints = 100,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've ruined %d corporate lunch breaks. These players tried to squeeze in a quick gank between spreadsheets and got absolutely deleted. Their bosses are thrilled with the productivity spike, but the local deli is filing for bankruptcy. Hope the cold sandwich was worth the corpse run."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByCombination("lunch_weekdays") -- 12-2 PM on weekdays, optimized
        end,
    },
    {
        id = "time_after_work_half",
        title = "Post-Work Predator",
        description = function(a) return ("Eliminate %d players during after work hours (5 PM - 10 PM, Mon-Fri)"):format(a.targetValue) end,
        iconID = 132303,
        achievementPoints = 50,
        targetValue = 1250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Halfway to %d post-work stress reliefs turned into stress inducers! These players clocked out of work just to get clocked by you. Happy hour? More like crappy hour.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByCombination("afterwork_weekdays") -- 5-10 PM on weekdays, optimized
        end,
    },
    {
        id = "time_after_work",
        title = "After Work Assassin",
        description = function(a) return ("Eliminate %d players during after work hours (5 PM - 10 PM, Mon-Fri)"):format(a.targetValue) end,
        iconID = 132303,
        achievementPoints = 100,
        targetValue = 2500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d players tried to de-stress after a long day at the office and you sent them straight to bed angry. Their spouses thank you for the extra family time, but their therapists are booking extra sessions to deal with the sudden surge in rage-quitting-related trauma."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByCombination("afterwork_weekdays") -- 5-10 PM on weekdays, optimized
        end,
    },
    {
        id = "time_work_hours_half",
        title = "Office Hour Execution",
        description = function(a) return ("Eliminate %d players during work hours (9 AM - 5 PM, Mon-Fri)"):format(a.targetValue) end,
        iconID = 136248,
        achievementPoints = 50,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've terminated %d employees halfway to full productivity enforcement! These 'remote workers' are definitely working from the graveyard now. Their Zoom meetings just got a lot quieter.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByCombination("workhours_weekdays") -- 9 AM-5 PM on weekdays, optimized
        end,
    },
    {
        id = "time_work_hours",
        title = "Work Hours Warrior",
        description = function(a) return ("Eliminate %d players during work hours (9 AM - 5 PM, Mon-Fri)"):format(a.targetValue) end,
        iconID = 136248,
        achievementPoints = 100,
        targetValue = 2000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've terminated %d employees who were definitely not working from home. Their bosses are sending you gift baskets for boosting company-wide productivity. You're not just a player; you're a corporate asset."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByCombination("workhours_weekdays") -- 9 AM-5 PM on weekdays, optimized
        end,
    },
    {
        id = "time_early_bird_half",
        title = "Dawn Patrol",
        description = function(a) return ("Kill %d players between 5 AM - 8 AM"):format(a.targetValue) end,
        iconID = 136245,
        achievementPoints = 125,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Halfway to catching all the early birds! You've woken up %d players permanently. They thought 5 AM was too early for PvP - you proved them dead wrong. Their morning coffee got cold while they waited for resurrection.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByTimeRangeName("early_bird")
        end,
    },
    {
        id = "time_early_bird",
        title = "Early Bird Hunter",
        description = function(a) return ("Kill %d players between 5 AM - 8 AM"):format(a.targetValue) end,
        iconID = 136245,
        achievementPoints = 250,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Sometimes the early bird does not get the worm! You've caught %d early risers who thought they'd get some peaceful morning gaming. They were up with the sunrise, coffee in hand, ready to start their day with some light PvP. Instead, they got a wake-up call they'll never recover from. Their morning routine now includes a mandatory graveyard sprint.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByTimeRangeName("early_bird")
        end,
    },
    {
        id = "time_weekend_ganker_half",
        title = "Saturday Morning Slayer",
        description = function(a) return ("Kill %d players during the weekend (Sat-Sun)"):format(a.targetValue) end,
        iconID = 132162,
        achievementPoints = 50,
        targetValue = 1250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Halfway to %d weekend plans canceled! You're the reason parents schedule family activities around server maintenance. These casual warriors thought weekends were for relaxation - you gave them permanent vacation.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByWeekdayGroup("weekend") -- Saturday and Sunday, optimized
        end,
    },
    {
        id = "time_weekend_ganker",
        title = "Weekend Ganker",
        description = function(a) return ("Kill %d players during the weekend (Sat-Sun)"):format(a.targetValue) end,
        iconID = 132162,
        achievementPoints = 100,
        targetValue = 2500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d players had their weekend plans canceled permanently. You're the definition of a casual weekend warrior - can't play during the week because of 'responsibilities,' so you log in Saturday morning with your coffee, still figuring out your keybinds, and somehow manage to kill people through sheer luck and questionable decision-making. Your victims respect the dedication of someone who ganks between grocery runs and family dinners.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByWeekdayGroup("weekend") -- Saturday and Sunday, optimized
        end,
    },
    {
        id = "time_weekday_killer_half",
        title = "Weekday Wanderer",
        description = function(a) return ("Kill %d players during the week (Mon-Fri)"):format(a.targetValue) end,
        iconID = 132212,
        achievementPoints = 50,
        targetValue = 1250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've caught %d players halfway to their full truancy sentence! These weekday warriors thought Tuesday was safe - you proved them wrong. Their productivity reports are looking suspiciously clean.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByWeekdayGroup("weekdays") -- Monday-Friday, optimized
        end,
    },
    {
        id = "time_weekday_killer",
        title = "Weekday Killer",
        description = function(a) return ("Kill %d players during the week (Mon-Fri)"):format(a.targetValue) end,
        iconID = 132212, -- Achievement_Character_Human_Male
        achievementPoints = 100,
        targetValue = 2500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've caught and executed %d players who were clearly skipping out on their responsibilities. Their managers might not know where they are, but the Spirit Healer has them on speed dial. You're the ultimate truant officer."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByWeekdayGroup("weekdays") -- Monday-Friday, optimized
        end,
    },
        {
        id = "time_monday_massacre_half",
        title = "Monday Blues",
        description = function(a) return ("Kill %d players on a Monday"):format(a.targetValue) end,
        iconID = 132800,
        achievementPoints = 50,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've given %d players a case of the Monday Blues they'll never recover from. Half way to making Mondays truly miserable!"):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            local timeStats = PSC_GetTimeBasedStats()
            return timeStats.weekdays.monday or 0 -- Monday, optimized
        end,
    },
    {
        id = "time_monday_mayhem",
        title = "Monday Mayhem",
        description = function(a) return ("Kill %d players on a Monday"):format(a.targetValue) end,
        iconID = 132800,
        achievementPoints = 100,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've given %d players a case of the Mondays they'll never recover from. They were already dreading the start of the week, and you just sent them straight to the spirit healer. Their boss is probably wondering why they're late for the raid."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            local timeStats = PSC_GetTimeBasedStats()
            return timeStats.weekdays.monday or 0 -- Monday, optimized
        end,
    },
    {
        id = "time_tuesday_terror_half",
        title = "Tuesday Trouble",
        description = function(a) return ("Kill %d players on a Tuesday"):format(a.targetValue) end,
        iconID = 132792,
        achievementPoints = 50,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("For %d players, Tuesday became troublesome. You're halfway to making every Tuesday a terror!"):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            local timeStats = PSC_GetTimeBasedStats()
            return timeStats.weekdays.tuesday or 0 -- Tuesday, optimized
        end,
    },
    {
        id = "time_tuesday_terror",
        title = "Tuesday Terror",
        description = function(a) return ("Kill %d players on a Tuesday"):format(a.targetValue) end,
        iconID = 132792,
        achievementPoints = 100,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("For %d players, Tuesday was just another day. Then you showed up. Now it's the day they learned that the only thing worse than a Monday is a Tuesday spent being repeatedly sent to the graveyard by you."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            local timeStats = PSC_GetTimeBasedStats()
            return timeStats.weekdays.tuesday or 0 -- Tuesday, optimized
        end,
    },
    {
        id = "time_wednesday_woe_half",
        title = "Wednesday Worry",
        description = function(a) return ("Kill %d players on a Wednesday"):format(a.targetValue) end,
        iconID = 132810,
        achievementPoints = 50,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've turned Hump Day into 'Worry Day' for %d players. Halfway through the week, halfway to maximum woe!"):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            local timeStats = PSC_GetTimeBasedStats()
            return timeStats.weekdays.wednesday or 0 -- Wednesday, optimized
        end,
    },
    {
        id = "time_wednesday_woe",
        title = "Wednesday Woe",
        description = function(a) return ("Kill %d players on a Wednesday"):format(a.targetValue) end,
        iconID = 132810,
        achievementPoints = 100,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've turned Hump Day into 'Get Over This Corpse' Day for %d players. They were halfway through the week, dreaming of the weekend, and you just gave them a permanent vacation. To the spirit healer."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            local timeStats = PSC_GetTimeBasedStats()
            return timeStats.weekdays.wednesday or 0 -- Wednesday, optimized
        end,
    },
    {
        id = "time_thursday_thrashing_half",
        title = "Thursday Thumping",
        description = function(a) return ("Kill %d players on a Thursday"):format(a.targetValue) end,
        iconID = 132809,
        achievementPoints = 50,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've given %d players a Thursday thumping! Halfway to a full thrashing!"):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            local timeStats = PSC_GetTimeBasedStats()
            return timeStats.weekdays.thursday or 0 -- Thursday, optimized
        end,
    },
    {
        id = "time_thursday_thrashing",
        title = "Thursday Thrashing",
        description = function(a) return ("Kill %d players on a Thursday"):format(a.targetValue) end,
        iconID = 132809,
        achievementPoints = 100,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("It's Thirsty Thursday, and you've served up %d mugs of whoop-ass. These players were just trying to get a head start on the weekend, but you put them on a permanent timeout."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            local timeStats = PSC_GetTimeBasedStats()
            return timeStats.weekdays.thursday or 0 -- Thursday, optimized
        end,
    },
    {
        id = "time_friday_frenzy_half",
        title = "Friday Fear",
        description = function(a) return ("Kill %d players on a Friday"):format(a.targetValue) end,
        iconID = 132788,
        achievementPoints = 50,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("TGIF? More like 'Thank God I'm... Dead' for %d players. Halfway to a full Friday frenzy!"):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            local timeStats = PSC_GetTimeBasedStats()
            return timeStats.weekdays.friday or 0 -- Friday, optimized
        end,
    },
    {
        id = "time_friday_frenzy",
        title = "Friday Frenzy",
        description = function(a) return ("Kill %d players on a Friday"):format(a.targetValue) end,
        iconID = 132788,
        achievementPoints = 100,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("TGIF? More like 'Thank God It's Over' for the %d players you just slaughtered. Their weekend plans are cancelled. Permanently. You're the reason they'll be spending Saturday morning complaining on the forums."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            local timeStats = PSC_GetTimeBasedStats()
            return timeStats.weekdays.friday or 0 -- Friday, optimized
        end,
    },
    {
        id = "time_saturday_slaughter_half",
        title = "Saturday Scrimmage",
        description = function(a) return ("Kill %d players on a Saturday"):format(a.targetValue) end,
        iconID = 132802,
        achievementPoints = 50,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've turned %d Saturday scrimmages into Saturday scares! Halfway to a complete slaughter!"):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            local timeStats = PSC_GetTimeBasedStats()
            return timeStats.weekdays.saturday or 0 -- Saturday, optimized
        end,
    },
    {
        id = "time_saturday_slaughter",
        title = "Saturday Slaughter",
        description = function(a) return ("Kill %d players on a Saturday"):format(a.targetValue) end,
        iconID = 132802,
        achievementPoints = 100,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("The boys are NOT for the boys. You've ruined %d weekends. They were supposed to be raiding, questing, or just chilling. Instead, they got a front-row seat to their own demise. Repeatedly."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            local timeStats = PSC_GetTimeBasedStats()
            return timeStats.weekdays.saturday or 0 -- Saturday, optimized
        end,
    },
    {
        id = "time_sunday_suffering_half",
        title = "Sunday Sorrow",
        description = function(a) return ("Kill %d players on a Sunday"):format(a.targetValue) end,
        iconID = 132804,
        achievementPoints = 50,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've brought Sunday sorrow to %d players. A day of rest became a day of regret. Halfway to complete suffering!"):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            local timeStats = PSC_GetTimeBasedStats()
            return timeStats.weekdays.sunday or 0 -- Sunday, optimized
        end,
    },
    {
        id = "time_sunday_suffering",
        title = "Sunday Suffering",
        description = function(a) return ("Kill %d players on a Sunday"):format(a.targetValue) end,
        iconID = 132804,
        achievementPoints = 100,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("A day of rest? Not on your watch. You've sent %d players to meet their maker... or at least the spirit healer. They'll be starting their week with repair bills and a deep-seated fear of you."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            local timeStats = PSC_GetTimeBasedStats()
            return timeStats.weekdays.sunday or 0 -- Sunday, optimized
        end,
    },
    {
        id = "seasonal_new_years_day",
        title = "Starting the Year with a Bang",
        description = "Kill 1 player on New Year's Day (Jan 1st)",
        iconID = 134270,
        achievementPoints = 100,
        targetValue = 1,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "New year, new victim. You've already ruined someone's 1st of January. At this rate, you'll be the server's most feared player by February.",
        progress = function(achievement, stats)
            return PSC_CountKillsBySpecialDate("new_years_day") -- New Year's Day, optimized
        end,
    },
    {
        id = "seasonal_valentines_day_lonely_ganker",
        title = "Valentine's Day Massacre",
        description = function(a) return ("Kill %d players on Valentine's Day (February 14th)"):format(a.targetValue) end,
        iconID = 135453,
        achievementPoints = 250,
        targetValue = 50,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("While everyone else was out on romantic dates, you were busy making %d players your 'valentine'... permanently! No girlfriend? No problem! Who needs love when you have a sword and %d fresh corpses to show for it? You've redefined 'lonely hearts' to 'lonely ganker.' Cupid's got nothing on your kill count!")
                :format(a.targetValue, a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsBySpecialDate("valentines_day")
        end,
    },
    {
        id = "seasonal_april_fools",
        title = "April Fool's Punchline",
        description = "Kill a player on April 1st.",
        iconID = 136235,
        achievementPoints = 100,
        targetValue = 1,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "They thought that gank was a joke. It wasn't. You've delivered the punchline to one player's very short-lived comedy routine. April Fools!",
        progress = function(achievement, stats)
            local timeStats = PSC_GetTimeBasedStats()
            return timeStats.specialDates["1_4"] or 0 -- April 1st, optimized
        end,
    },
    {
        id = "seasonal_independence_day",
        title = "Independence Day Executioner",
        description = "Kill 1 player on Independence Day (July 4th)",
        iconID = 134278,
        achievementPoints = 100,
        targetValue = 1,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "You declared independence from their HP bar! While they were celebrating freedom with fireworks, you gave them a one-way ticket to the spirit healer. Red, white, blue, and very, very dead. Happy 4th of July!",
        progress = function(achievement, stats)
            local timeStats = PSC_GetTimeBasedStats()
            return timeStats.specialDates["4_7"] or 0 -- July 4th, optimized
        end,
    },
    {
        id = "seasonal_wow_anniversary",
        title = "World of Warcraft Anniversary",
        description = "Kill 1 player on November 23rd (WoW Vanilla Release Date)",
        iconID = 135724,
        achievementPoints = 100,
        targetValue = 1,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "You celebrated the birth of World of Warcraft by sending someone back to the character creation screen! November 23rd, 2004 - the day millions of lives changed forever. Today, you made sure one player's life ended forever. Happy Anniversary!",
        progress = function(achievement, stats)
            local timeStats = PSC_GetTimeBasedStats()
            return timeStats.specialDates["23_11"] or 0 -- November 23rd, WoW release date
        end,
    },
    {
        id = "seasonal_christmas_eve",
        title = "Holiday Spirit...Crusher",
        description = "Kill 1 player on Christmas Eve (Dec 24th)",
        iconID = 132641,
        achievementPoints = 100,
        targetValue = 1,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "Someone was trying to spread holiday cheer. You spread their entrails on the snow. Bah, humbug.",
        progress = function(achievement, stats)
            local timeStats = PSC_GetTimeBasedStats()
            return timeStats.specialDates["24_12"] or 0 -- Christmas Eve, optimized
        end,
    },
    {
        id = "seasonal_christmas_day",
        title = "A Very Bloody Christmas",
        description = "Kill 1 player on Christmas Day (Dec 25th)",
        iconID = 133202,
        achievementPoints = 100,
        targetValue = 1,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "You gave someone the gift of a corpse run. They'll remember this Christmas forever... with rage.",
        progress = function(achievement, stats)
            return PSC_CountKillsBySpecialDate("christmas") -- Christmas Day, optimized
        end,
    },
    {
        id = "seasonal_new_years_eve",
        title = "Dropping The Ball",
        description = "Kill 1 player on New Year's Eve (Dec 31st)",
        iconID = 134273,
        achievementPoints = 100,
        targetValue = 1,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "While everyone else was counting down, you were counting down some poor soul's health bar. Their new year's resolution is to avoid you.",
        progress = function(achievement, stats)
            return PSC_CountKillsBySpecialDate("new_years_eve") -- New Year's Eve, optimized
        end,
    },
    {
        id = "seasonal_friday_13th",
        title = "Friday the 13th Menace",
        description = "Kill 13 players on any Friday the 13th.",
        iconID = 132299,
        achievementPoints = 100,
        targetValue = 13,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "You're the reason people are superstitious. You've made Friday the 13th a living nightmare for 13 unlucky souls. Jason Voorhees would be proud.",
        progress = function(achievement, stats)
            return PSC_CountKillsBySpecialCondition("friday13th") -- Friday 13th, optimized
        end,
    },
    {
        id = "seasonal_monthly_january",
        title = "January Juggernaut",
        description = "Kill 100 players in January.",
        iconID = 132857,
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "You started the year with a massacre. New Year's resolutions are for mortals.",
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("january") -- January, optimized
        end,
    },
    {
        id = "seasonal_monthly_february",
        title = "February Frenzy",
        description = "Kill 100 players in February.",
        iconID = 132857,
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "Love is in the air, and so are the corpses. You've been busy.",
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("february") -- February, optimized
        end,
    },
    {
        id = "seasonal_monthly_march",
        title = "March Madness",
        description = "Kill 100 players in March.",
        iconID = 132857,
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "The Ides of March were nothing compared to your killing spree.",
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("march") -- March, optimized
        end,
    },
    {
        id = "seasonal_monthly_april",
        title = "April Annihilator",
        description = "Kill 100 players in April.",
        iconID = 132857,
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "April showers bring May flowers, but you just brought pain.",
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("april") -- April, optimized
        end,
    },
    {
        id = "seasonal_monthly_may",
        title = "May Mayhem",
        description = "Kill 100 players in May.",
        iconID = 132857,
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "You turned May into a month of mourning for 100 players.",
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("may") -- May, optimized
        end,
    },
    {
        id = "seasonal_monthly_june",
        title = "June Juggernaut",
        description = "Kill 100 players in June.",
        iconID = 132857,
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "School's out, and you've been schooling the competition.",
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("june") -- June, optimized
        end,
    },
    {
        id = "seasonal_monthly_july",
        title = "July Jubilee",
        description = "Kill 100 players in July.",
        iconID = 132857,
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "You celebrated summer with a hundred funerals.",
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("july") -- July, optimized
        end,
    },
    {
        id = "seasonal_monthly_august",
        title = "August Assault",
        description = "Kill 100 players in August.",
        iconID = 132857,
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "The dog days of summer were deadly for your opponents.",
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("august") -- August, optimized
        end,
    },
    {
        id = "seasonal_monthly_september",
        title = "September Slaughter",
        description = "Kill 100 players in September.",
        iconID = 132857,
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "Back to school, back to the graveyard.",
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("september") -- September, optimized
        end,
    },
    {
        id = "seasonal_monthly_october",
        title = "October Overlord",
        description = "Kill 100 players in October.",
        iconID = 132857,
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "Trick or treat? They got tricked, you got a treat.",
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("october") -- October, optimized
        end,
    },
    {
        id = "seasonal_monthly_november",
        title = "November Nightmare",
        description = "Kill 100 players in November.",
        iconID = 132857,
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "You're the reason they're thankful for spirit healers.",
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("november") -- November, optimized
        end,
    },
    {
        id = "seasonal_monthly_december",
        title = "December Destroyer",
        description = "Kill 100 players in December.",
        iconID = 132857,
        achievementPoints = 25,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "You put 100 names on the naughty list, permanently.",
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("december") -- December, optimized
        end,
    },
    {
        id = "name_letter_a",
        title = "A-Team Annihilator",
        description = function(a) return ("Eliminate %d players whose names start with 'A'"):format(a.targetValue) end,
        iconID = 134939,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've alphabetized %d players starting with 'A' into the graveyard! From Aaron to Ass... these A-listers are now A-corpses.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("A")
        end,
    },
    {
        id = "name_letter_b",
        title = "B-List Butcher",
        description = function(a) return ("Eliminate %d players whose names start with 'B'"):format(a.targetValue) end,
        iconID = 134939,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've brutalized %d B-named players! From Bob to Broly, they all got the same treatment: a brutal beatdown.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("B")
        end,
    },
    {
        id = "name_letter_c",
        title = "C-Grade Crusher",
        description = function(a) return ("Eliminate %d players whose names start with 'C'"):format(a.targetValue) end,
        iconID = 134939,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've crushed %d C-named champions! From Cedric to Cheesewheels, they all learned that C stands for 'Corpse'.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("C")
        end,
    },
    {
        id = "name_letter_d",
        title = "Dust to Dust",
        description = function(a) return ("Eliminate %d players whose names start with 'D'"):format(a.targetValue) end,
        iconID = 134939,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've delivered devastation to %d D-named players! From Dave to Dragonslayer, they all got the same D: Death.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("D")
        end,
    },
    {
        id = "name_letter_e",
        title = "E-List Eliminator",
        description = function(a) return ("Eliminate %d players whose names start with 'E'"):format(a.targetValue) end,
        iconID = 134942,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've exterminated %d E-named enemies! From Eric to Ethereal, they all got an E for 'Eliminated'.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("E")
        end,
    },
    {
        id = "name_letter_f",
        title = "F-Tier Finisher",
        description = function(a) return ("Eliminate %d players whose names start with 'F'"):format(a.targetValue) end,
        iconID = 134942,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've finished %d F-named fools! From Felix to Faggiodriver, they all got an F in staying alive.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("F")
        end,
    },
    {
        id = "name_letter_g",
        title = "G-Force Graveyard",
        description = function(a) return ("Eliminate %d players whose names start with 'G'"):format(a.targetValue) end,
        iconID = 134942,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've graveyarded %d G-named gamers! From Gary to Godslayer, they all got G'd up... in the graveyard.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("G")
        end,
    },
    {
        id = "name_letter_h",
        title = "H-Bomb Handler",
        description = function(a) return ("Eliminate %d players whose names start with 'H'"):format(a.targetValue) end,
        iconID = 134942,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've handled %d H-named heroes! From Howaito to Hkfarmer, they all got H-bombed into oblivion.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("H")
        end,
    },
    {
        id = "name_letter_i",
        title = "I-Con Iceman",
        description = function(a) return ("Eliminate %d players whose names start with 'I'"):format(a.targetValue) end,
        iconID = 134940,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've iced %d I-named individuals! From Ian to Icecrown, they all learned that I stands for 'Instant death'.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("I")
        end,
    },
    {
        id = "name_letter_j",
        title = "J-Walking Judge",
        description = function(a) return ("Eliminate %d players whose names start with 'J'"):format(a.targetValue) end,
        iconID = 134940,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've judged %d J-named jockeys! From Jan to Jokester, they all got J-walked straight to the afterlife.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("J")
        end,
    },
    {
        id = "name_letter_k",
        title = "K-Pop Killer",
        description = function(a) return ("Eliminate %d players whose names start with 'K'"):format(a.targetValue) end,
        iconID = 134940,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've killed %d K-named keyboard warriors! From Kenny to Kingslayer, they all got K.O.'d permanently.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("K")
        end,
    },
    {
        id = "name_letter_l",
        title = "L-Train Liquidator",
        description = function(a) return ("Eliminate %d players whose names start with 'L'"):format(a.targetValue) end,
        iconID = 134940,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've liquidated %d L-named losers! From Larry to Lordmaster, they all took the L train to the graveyard.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("L")
        end,
    },
    {
        id = "name_letter_m",
        title = "M-Class Murderer",
        description = function(a) return ("Eliminate %d players whose names start with 'M'"):format(a.targetValue) end,
        iconID = 134945,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've murdered %d M-named maniacs! From Mike to Mobman, they all got M for 'Murdered'.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("M")
        end,
    },
    {
        id = "name_letter_n",
        title = "N-Word Neutralizer",
        description = function(a) return ("Eliminate %d players whose names start with 'N'"):format(a.targetValue) end,
        iconID = 134945,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've neutralized %d N-named noobs! From Nick to Nightbringer, they all got the big N: 'No more life'.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("N")
        end,
    },
    {
        id = "name_letter_o",
        title = "O-Zone Obliterator",
        description = function(a) return ("Eliminate %d players whose names start with 'O'"):format(a.targetValue) end,
        iconID = 134945,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've obliterated %d O-named opponents! From Oscar to Oathbreaker, they all got O for 'Over and out'.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("O")
        end,
    },
    {
        id = "name_letter_p",
        title = "P-Rated Pulverizer",
        description = function(a) return ("Eliminate %d players whose names start with 'P'"):format(a.targetValue) end,
        iconID = 134945,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've pulverized %d P-named players! From Paul to Phohp, they all got P'd on... permanently.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("P")
        end,
    },
    {
        id = "name_letter_q",
        title = "Q-Anon Queller",
        description = function(a) return ("Eliminate %d players whose names start with 'Q'"):format(a.targetValue) end,
        iconID = 134943,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've quelled %d Q-named questers! From Quinn to Questbreaker, they all got Q'd into the afterlife.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("Q")
        end,
    },
    {
        id = "name_letter_r",
        title = "R-Rated Reaper",
        description = function(a) return ("Eliminate %d players whose names start with 'R'"):format(a.targetValue) end,
        iconID = 134943,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've reaped %d R-named raiders! From Rick to Raidkiller, they all got R.I.P.'d by your blade.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("R")
        end,
    },
    {
        id = "name_letter_s",
        title = "S-Tier Slaughterer",
        description = function(a) return ("Eliminate %d players whose names start with 'S'"):format(a.targetValue) end,
        iconID = 134943,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've slaughtered %d S-named scrubs! From Simon to Severussnipe, they all got S for 'Slain'.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("S")
        end,
    },
    {
        id = "name_letter_t",
        title = "T-Pose Terminator",
        description = function(a) return ("Eliminate %d players whose names start with 'T'"):format(a.targetValue) end,
        iconID = 134943,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've terminated %d T-named targets! From Tametimo to Titanslayer, they all got T-bagged by death itself.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("T")
        end,
    },
    {
        id = "name_letter_u",
        title = "U-Turn Undertaker",
        description = function(a) return ("Eliminate %d players whose names start with 'U'"):format(a.targetValue) end,
        iconID = 134937,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've undertaken %d U-named users! From Ulrich to Uselessidiot, they all took a U-turn straight to the grave.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("U")
        end,
    },
    {
        id = "name_letter_v",
        title = "V-Day Vanquisher",
        description = function(a) return ("Eliminate %d players whose names start with 'V'"):format(a.targetValue) end,
        iconID = 134937,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've vanquished %d V-named villains! From Victoria to Voidbringer, they all got V for 'Vanquished'.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("V")
        end,
    },
    {
        id = "name_letter_w",
        title = "W-Key Warrior",
        description = function(a) return ("Eliminate %d players whose names start with 'W'"):format(a.targetValue) end,
        iconID = 134937,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've wasted %d W-named warriors! From Will to Worldbreaker, they all got W for 'Wrecked'.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("W")
        end,
    },
    {
        id = "name_letter_x",
        title = "X-Factor Executioner",
        description = function(a) return ("Eliminate %d players whose names start with 'X'"):format(a.targetValue) end,
        iconID = 134937,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've X'd out %d X-named xenophobes! From Xavier to Xanathos, they all got marked with an X for 'eXterminated'.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("X")
        end,
    },
    {
        id = "name_letter_y",
        title = "Y-Generation Yielder",
        description = function(a) return ("Eliminate %d players whose names start with 'Y'"):format(a.targetValue) end,
        iconID = 134938,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've yielded %d Y-named youngsters! From Yuri to Yggdrasil, they all got Y for 'Yesterday's news'.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("Y")
        end,
    },
    {
        id = "name_letter_z",
        title = "Z-List Zombie",
        description = function(a) return ("Eliminate %d players whose names start with 'Z'"):format(a.targetValue) end,
        iconID = 134938,
        achievementPoints = 50,
        targetValue = 150,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've zombified %d Z-named zealots! From Zack to Zzzzrakthul, they all got Z for 'Zzzzz... permanently'.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameStartingWith("Z")
        end,
    },
    {
        id = "name_length_2",
        title = "The Ultra Rare Drop",
        description = function(a) return ("Eliminate %d players with exactly 2-letter names"):format(a.targetValue) end,
        iconID = 134938,
        achievementPoints = 100,
        targetValue = 2,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've killed %d players with 2-letter names. Two-tally impressive. These brave souls looked at the character creation screen and thought 'less is more.' Turns out less is just... less. Less name, less health, less time alive. You ended their story before it even got past letter three. Some people are just two good for this world.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameLength(2)
        end,
    },
    {
        id = "name_length_3",
        title = "Tri-Letter Terminator",
        description = function(a) return ("Eliminate %d players with exactly 3-letter names"):format(a.targetValue) end,
        iconID = 134938,
        achievementPoints = 75,
        targetValue = 10,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've terminated %d players with 3-letter names! Bob, Jim, Sue - all gone. Short names, shorter lives. These minimalists took their name philosophy too far and ended up with the shortest lifespan possible.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameLength(3)
        end,
    },
    {
        id = "name_length_12",
        title = "Dozen-Letter Destroyer",
        description = function(a) return ("Eliminate %d players with exactly 12-letter names"):format(a.targetValue) end,
        iconID = 134938,
        achievementPoints = 75,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've destroyed %d players with 12-letter names! These verbose victims thought longer names meant longer lives. Shadowknight, Dragonslayer, Deathbringer - all equally dead. Turns out, character count doesn't count when you're counting corpses.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithNameLength(12)
        end,
    },
    {
        id = "name_special_chars",
        title = "The Weird Ones",
        description = function(a) return ("Eliminate %d players whose names contain ä, ö, ü, ß, ø or æ"):format(a.targetValue) end,
        iconID = 134938,
        achievementPoints = 75,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've killed %d players who thought naming their character Björn, Günther or Søren made them sound tough. It didn't. It just made their corpse harder to pronounce. Nobody at the graveyard could spell your name and nobody cared — you still died like everyone else.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithSpecialCharsInName()
        end,
    },
    {
        id = "name_accent_chars",
        title = "The Copy-Cats",
        description = function(a) return ("Eliminate %d players whose names contain accent characters (é, è, ê, á, à, â, ...)"):format(a.targetValue) end,
        iconID = 134938,
        achievementPoints = 75,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've killed %d players whose favorite name was already taken, so they just slapped some low-effort accents on it and called it creative. Légolàs. Àrthas. Dragonslàyer. Congratulations on your unique snowflake name — it didn't save you from a very ordinary death.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsWithAccentCharsInName()
        end,
    },
    {
        id = "seasonal_month_january",
        title = "January Jester",
        description = function(a) return ("Kill %d players during January"):format(a.targetValue) end,
        iconID = 135385,
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've turned %d New Year's resolutions into permanent resting positions! These players resolved to 'get better at PvP' and 'play more WoW.' Mission accomplished... from the wrong perspective.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("january")
        end,
    },
    {
        id = "seasonal_month_february",
        title = "February Fiend",
        description = function(a) return ("Kill %d players during February"):format(a.targetValue) end,
        iconID = 135385,
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've sent %d players straight to the graveyard this February! While others were celebrating love, you were spreading death. Cupid's got nothing on your kill count. These players thought February was about hearts and flowers - you showed them it's about corpses and tombstones.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("february")
        end,
    },
    {
        id = "seasonal_month_march",
        title = "March Madness",
        description = function(a) return ("Kill %d players during March"):format(a.targetValue) end,
        iconID = 135385,
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("March Madness? More like March Massacre! You've eliminated %d players who came in like lions and went out like... well, corpses. Spring forward? These players sprung backwards to the spirit healer. The only bracket that matters is your kill bracket.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("march")
        end,
    },
    {
        id = "seasonal_month_april",
        title = "April Annihilator",
        description = function(a) return ("Kill %d players during April"):format(a.targetValue) end,
        iconID = 135385,
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("April showers bring May flowers, but your April brought %d corpses! These players thought spring meant renewal and growth. You taught them it means respawn timers and graveyard runs. The only thing blooming this April was your kill count.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("april")
        end,
    },
    {
        id = "seasonal_month_may",
        title = "May Mayhem",
        description = function(a) return ("Kill %d players during May"):format(a.targetValue) end,
        iconID = 135385,
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("May the Fourth be with you? More like 'May the corpse be with the spirit healer!' You've terminated %d players this May. While others celebrated spring festivals, you created a festival of death. These players brought flowers for Mother's Day - you sent them to meet their maker.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("may")
        end,
    },
    {
        id = "seasonal_month_june",
        title = "June Juggernaut",
        description = function(a) return ("Kill %d players during June"):format(a.targetValue) end,
        iconID = 135385,
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("June bugs got nothing on your June kills! You've squashed %d players this month. Summer vacation started early for these players - permanent vacation at the graveyard. They wanted to enjoy the longest days of the year, but you gave them the shortest lives instead.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("june")
        end,
    },
    {
        id = "seasonal_month_july",
        title = "July Jackhammer",
        description = function(a) return ("Kill %d players during July"):format(a.targetValue) end,
        iconID = 135385,
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Fourth of July fireworks? You provided the real fireworks with %d explosive kills! These players wanted to celebrate independence - you gave them independence from the mortal coil. The only red, white, and blue they saw was the colors of their death screen.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("july")
        end,
    },
    {
        id = "seasonal_month_august",
        title = "August Assassin",
        description = function(a) return ("Kill %d players during August"):format(a.targetValue) end,
        iconID = 135385,
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Dog days of summer? More like 'Dead days of summer!' You've put %d players to eternal rest this August. They wanted to enjoy their last weeks of summer vacation - you gave them their last weeks of being alive. The heat wasn't the only thing that was deadly this month.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("august")
        end,
    },
    {
        id = "seasonal_month_september",
        title = "September Slayer",
        description = function(a) return ("Kill %d players during September"):format(a.targetValue) end,
        iconID = 135385,
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Back to school? More like back to the graveyard! You've educated %d players in the art of dying this September. They thought they were learning new skills and meeting new people. Turns out, the only skill they learned was how to quickly release their spirits.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("september")
        end,
    },
    {
        id = "seasonal_month_october",
        title = "October Obliterator",
        description = function(a) return ("Kill %d players during October"):format(a.targetValue) end,
        iconID = 135385,
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Halloween came early with %d spooky kills! These players dressed up for October 31st, but you made sure they looked like corpses all month long. The only trick-or-treating they did was treating the spirit healer to repeat business. You turned October into 'Scare-tober.'")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("october")
        end,
    },
    {
        id = "seasonal_month_november",
        title = "November Nightmare",
        description = function(a) return ("Kill %d players during November"):format(a.targetValue) end,
        iconID = 135385,
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Thanksgiving feast? You provided the main course with %d fresh kills! These players were thankful for many things - until they met you. Now the only thing they're thankful for is the spirit healer's quick service. You carved them up better than any turkey.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("november")
        end,
    },
    {
        id = "seasonal_month_december",
        title = "December Destroyer",
        description = function(a) return ("Kill %d players during December"):format(a.targetValue) end,
        iconID = 135385,
        achievementPoints = 50,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("'Tis the season to be deadly! You've gifted %d players a one-way ticket to the afterlife this December. They hung their stockings by the chimney with care, but you hung their corpses everywhere. Santa's naughty list has nothing on your kill list. The only white Christmas they got was the color of the graveyard snow.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("december")
        end,
    },
    {
        id = "seasonal_january_massacre",
        title = "New Year's Carnage",
        description = function(a) return ("Kill %d players during January"):format(a.targetValue) end,
        iconID = 135614,
        achievementPoints = 100,
        targetValue = 750,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You started the year with %d kills! While everyone else was making resolutions to be better people, you resolved to be a better killer. Mission accomplished. The champagne wasn't the only thing popping - so were their heads.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("january")
        end,
    },
    {
        id = "seasonal_february_bloodbath",
        title = "February Freeze-Out",
        description = function(a) return ("Kill %d players during February"):format(a.targetValue) end,
        iconID = 135843,
        achievementPoints = 100,
        targetValue = 750,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("While everyone else was dealing with the cold weather, you made %d players feel the ultimate chill! February might be the shortest month, but your kill streak was anything but short. Winter is coming? No, winter was here, and so were you.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("february")
        end,
    },
    {
        id = "seasonal_march_slaughter",
        title = "Spring Break Breakdown",
        description = function(a) return ("Kill %d players during March"):format(a.targetValue) end,
        iconID = 135861,
        achievementPoints = 100,
        targetValue = 750,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Spring cleaning took on a whole new meaning with %d bodies to dispose of! These players thought March meant fresh starts and new beginnings. You gave them the freshest possible start - at the graveyard. The only thing sprouting this spring was your kill count.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("march")
        end,
    },
    {
        id = "seasonal_april_carnage",
        title = "Easter Egg Hunt Champion",
        description = function(a) return ("Kill %d players during April"):format(a.targetValue) end,
        iconID = 135617,
        achievementPoints = 100,
        targetValue = 750,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You found %d Easter eggs - all shaped like corpses! While others hunted for chocolate, you hunted for kills. The Easter Bunny is filing a restraining order. These players thought April meant rebirth and renewal - you showed them it means death and funeral.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("april")
        end,
    },
    {
        id = "seasonal_may_genocide",
        title = "Mother's Day Special",
        description = function(a) return ("Kill %d players during May"):format(a.targetValue) end,
        iconID = 135450,
        achievementPoints = 100,
        targetValue = 750,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You sent %d players home to their mommies... permanently! Mother's Day got really awkward when their kids had to explain why daddy won't be coming to dinner. Ever. You've created more orphans than a Disney movie.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("may")
        end,
    },
    {
        id = "seasonal_june_extermination",
        title = "Summer Solstice Slayer",
        description = function(a) return ("Kill %d players during June"):format(a.targetValue) end,
        iconID = 135619,
        achievementPoints = 100,
        targetValue = 750,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("The longest day of the year was also the last day for %d players! Summer vacation plans got permanently cancelled. They wanted to enjoy the sunshine - you gave them eternal darkness. The only thing hot this summer was your killing streak.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("june")
        end,
    },
    {
        id = "seasonal_july_liberation",
        title = "Independence Day Liberator",
        description = function(a) return ("Kill %d players during July"):format(a.targetValue) end,
        iconID = 135620,
        achievementPoints = 100,
        targetValue = 750,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You liberated %d players from the burden of living! While others celebrated freedom with fireworks, you celebrated with firepower. The Declaration of Independence got nothing on your declaration of war. Red, white, and blue? More like red blood, white bones, and blue corpses.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("july")
        end,
    },
    {
        id = "seasonal_august_apocalypse",
        title = "Dog Days Executioner",
        description = function(a) return ("Kill %d players during August"):format(a.targetValue) end,
        iconID = 132190,
        achievementPoints = 100,
        targetValue = 750,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("The dog days of summer turned into the 'dead days' of summer with %d kills! These players thought August heat was unbearable - you showed them what real heat feels like. The only thing lazier than summer afternoons were their corpses.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("august")
        end,
    },
    {
        id = "seasonal_september_genocide",
        title = "Back-to-School Bully",
        description = function(a) return ("Kill %d players during September"):format(a.targetValue) end,
        iconID = 134330,
        achievementPoints = 100,
        targetValue = 750,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("School's in session and you taught %d players the final lesson! They came back from summer vacation relaxed and refreshed - you sent them back to the graveyard stressed and dead. The only homework they're doing now is decomposition.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("september")
        end,
    },
    {
        id = "seasonal_october_butchery",
        title = "Trick-or-Treat Tyrant",
        description = function(a) return ("Kill %d players during October"):format(a.targetValue) end,
        iconID = 133982,
        achievementPoints = 100,
        targetValue = 750,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Trick or treat? They got the ultimate trick - %d permanent treats for the graveyard! You turned Halloween into 'Hell-o-ween.' Their costumes were scary, but not as scary as your kill count. The real horror show was your PvP performance.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("october")
        end,
    },
    {
        id = "seasonal_november_bloodlust",
        title = "Turkey Day Terminator",
        description = function(a) return ("Kill %d players during November"):format(a.targetValue) end,
        iconID = 133971,
        achievementPoints = 100,
        targetValue = 750,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You carved up %d players better than any Thanksgiving turkey! They were thankful for family, friends, and good health - until you showed up. Now their families are thankful for life insurance policies. The only stuffing happening was corpses into graveyards.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("november")
        end,
    },
    {
        id = "seasonal_december_armageddon",
        title = "Christmas Carol Killer",
        description = function(a) return ("Kill %d players during December"):format(a.targetValue) end,
        iconID = 134140,
        achievementPoints = 100,
        targetValue = 750,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Silent night, deadly night! You've composed a Christmas carol with %d death screams. They dreamed of a white Christmas - you gave them red snow. Santa's workshop has nothing on your kill factory. The only thing jingling was the sound of their gear dropping.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_CountKillsByMonthName("december")
        end,
    },
    -- Streak Achievements
    {
        id = "streaks_week_10_7",
        title = "Weekly Warrior",
        description = function(a) return ("Get %d kills per day for %d consecutive days"):format(10, 7) end,
        iconID = 132307,
        achievementPoints = 75,
        targetValue = 7,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Seven days of dedication! You've maintained a 10-kill daily quota for an entire week. Your enemies now check the calendar before logging in.")
        end,
        progress = function(achievement, stats)
            return PSC_CountConsecutiveDaysWithMinKills(10) or 0
        end,
    },
    {
        id = "streaks_week_25_7",
        title = "Weekly Executioner",
        description = function(a) return ("Get %d kills per day for %d consecutive days"):format(25, 7) end,
        iconID = 132349,
        achievementPoints = 125,
        targetValue = 7,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("A week of terror! 25 kills daily for seven straight days. You've turned the weekly reset into the weekly massacre.")
        end,
        progress = function(achievement, stats)
            return PSC_CountConsecutiveDaysWithMinKills(25) or 0
        end,
    },
    {
        id = "streaks_week_50_7",
        title = "Weekly Annihilator",
        description = function(a) return ("Get %d kills per day for %d consecutive days"):format(50, 7) end,
        iconID = 132355,
        achievementPoints = 250,
        targetValue = 7,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Fifty kills a day keeps the enemies away! Seven days of absolute domination. You've redefined what 'having a good week' means.")
        end,
        progress = function(achievement, stats)
            return PSC_CountConsecutiveDaysWithMinKills(50) or 0
        end,
    },
    {
        id = "streaks_week_100_7",
        title = "Weekly Apocalypse",
        description = function(a) return ("Get %d kills per day for %d consecutive days"):format(100, 7) end,
        iconID = 132357,
        achievementPoints = 500,
        targetValue = 7,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("One hundred souls per day for a week straight! You've achieved peak efficiency. The weekly server maintenance couldn't even stop your killing spree.")
        end,
        progress = function(achievement, stats)
            return PSC_CountConsecutiveDaysWithMinKills(100) or 0
        end,
    },
    {
        id = "streaks_biweek_10_14",
        title = "Fortnightly Finisher",
        description = function(a) return ("Get %d kills per day for %d consecutive days"):format(10, 14) end,
        iconID = 132350,
        achievementPoints = 75,
        targetValue = 14,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Two weeks of unwavering dedication! Your daily 10-kill routine has become the stuff of legends. Enemy guilds are scheduling around your playtime.")
        end,
        progress = function(achievement, stats)
            return PSC_CountConsecutiveDaysWithMinKills(10) or 0
        end,
    },
    {
        id = "streaks_biweek_25_14",
        title = "Biweekly Butcher",
        description = function(a) return ("Get %d kills per day for %d consecutive days"):format(25, 14) end,
        iconID = 132352,
        achievementPoints = 125,
        targetValue = 14,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Fourteen days of relentless hunting! Twenty-five kills daily without fail. Your name has become synonymous with 'avoid at all costs.'")
        end,
        progress = function(achievement, stats)
            return PSC_CountConsecutiveDaysWithMinKills(25) or 0
        end,
    },
    {
        id = "streaks_biweek_50_14",
        title = "Biweekly Berserker",
        description = function(a) return ("Get %d kills per day for %d consecutive days"):format(50, 14) end,
        iconID = 132354,
        achievementPoints = 250,
        targetValue = 14,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Two weeks of pure carnage! Fifty daily eliminations without missing a beat. You've turned PvP into a full-time job.")
        end,
        progress = function(achievement, stats)
            return PSC_CountConsecutiveDaysWithMinKills(50) or 0
        end,
    },
    {
        id = "streaks_biweek_100_14",
        title = "Biweekly Cataclysm",
        description = function(a) return ("Get %d kills per day for %d consecutive days"):format(100, 14) end,
        iconID = 132356,
        achievementPoints = 500,
        targetValue = 14,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Fourteen days of absolute destruction! One hundred kills daily for two weeks straight. You've achieved what most consider impossible.")
        end,
        progress = function(achievement, stats)
            return PSC_CountConsecutiveDaysWithMinKills(100) or 0
        end,
    },
    {
        id = "streaks_month_10_30",
        title = "Monthly Menace",
        description = function(a) return ("Get %d kills per day for %d consecutive days"):format(10, 30) end,
        iconID = 132347,
        achievementPoints = 75,
        targetValue = 30,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("A full month of consistent terror! Thirty days of 10+ kills each. You've established a reign of fear that spans an entire month.")
        end,
        progress = function(achievement, stats)
            return PSC_CountConsecutiveDaysWithMinKills(10) or 0
        end,
    },
    {
        id = "streaks_month_25_30",
        title = "Monthly Massacre Master",
        description = function(a) return ("Get %d kills per day for %d consecutive days"):format(25, 30) end,
        iconID = 132348,
        achievementPoints = 125,
        targetValue = 30,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Thirty days of unrelenting violence! Twenty-five kills daily for an entire month. Server populations have noticeably declined in your wake.")
        end,
        progress = function(achievement, stats)
            return PSC_CountConsecutiveDaysWithMinKills(25) or 0
        end,
    },
    {
        id = "streaks_month_50_30",
        title = "Monthly Extinction Event",
        description = function(a) return ("Get %d kills per day for %d consecutive days"):format(50, 30) end,
        iconID = 132351,
        achievementPoints = 250,
        targetValue = 30,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("A month-long killing spree! Fifty eliminations daily for thirty consecutive days. You've single-handedly caused multiple server transfers.")
        end,
        progress = function(achievement, stats)
            return PSC_CountConsecutiveDaysWithMinKills(50) or 0
        end,
    },
    {
        id = "streaks_month_100_30",
        title = "Monthly Armageddon",
        description = function(a) return ("Get %d kills per day for %d consecutive days"):format(100, 30) end,
        iconID = 132353,
        achievementPoints = 500,
        targetValue = 30,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Thirty days of absolute devastation! One hundred kills daily without fail. You've redefined what 'having a bad month' means for everyone else.")
        end,
        progress = function(achievement, stats)
            return PSC_CountConsecutiveDaysWithMinKills(100) or 0
        end,
    },
    {
        id = "streaks_year_10_365",
        title = "Annual Assassin",
        description = function(a) return ("Get %d kills per day for %d consecutive days"):format(10, 365) end,
        iconID = 132284,
        achievementPoints = 125,
        targetValue = 365,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Three hundred sixty-five days of dedication! A full year of 10+ kills daily. You've achieved legendary status that will be remembered forever.")
        end,
        progress = function(achievement, stats)
            return PSC_CountConsecutiveDaysWithMinKills(10) or 0
        end,
    },
    {
        id = "streaks_year_25_365",
        title = "Yearly Yield Reaper",
        description = function(a) return ("Get %d kills per day for %d consecutive days"):format(25, 365) end,
        iconID = 132359,
        achievementPoints = 250,
        targetValue = 365,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("A full year of terror! Twenty-five kills every single day for 365 days. You've become a force of nature, as inevitable as death and taxes.")
        end,
        progress = function(achievement, stats)
            return PSC_CountConsecutiveDaysWithMinKills(25) or 0
        end,
    },
    {
        id = "streaks_year_50_365",
        title = "Annual Apocalypse",
        description = function(a) return ("Get %d kills per day for %d consecutive days"):format(50, 365) end,
        iconID = 132360,
        achievementPoints = 500,
        targetValue = 365,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Three hundred sixty-five days of unmatched brutality! Fifty kills daily for an entire year. You've transcended from player to phenomenon.")
        end,
        progress = function(achievement, stats)
            return PSC_CountConsecutiveDaysWithMinKills(50) or 0
        end,
    },
    {
        id = "streaks_year_100_365",
        title = "Eternal Exterminator",
        description = function(a) return ("Get %d kills per day for %d consecutive days"):format(100, 365) end,
        iconID = 132361,
        achievementPoints = 500,
        targetValue = 365,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("The impossible achieved! One hundred kills every day for a full year. You've reached a level of dedication that borders on divine intervention. Legends will speak of this accomplishment for generations.")
        end,
        progress = function(achievement, stats)
            return PSC_CountConsecutiveDaysWithMinKills(100) or 0
        end
    },
    {
        id = "streaks_10_kills_on_365_days",
        title = "A Year of War",
        description = function(a) return ("Kill at least 10 players on %d different days"):format(a.targetValue) end,
        iconID = 134067,
        achievementPoints = 125,
        targetValue = 365,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return "Consistency is key. You are a true dedicated PvPer."
        end,
        progress = function(achievement, stats)
            return PSC_CountTotalDaysWithMinKills(10) or 0
        end,
    },
    {
        id = "streaks_25_kills_on_365_days",
        title = "Veteran of the Year",
        description = function(a) return ("Kill at least 25 players on %d different days"):format(a.targetValue) end,
        iconID = 134067,
        achievementPoints = 250,
        targetValue = 365,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return "A quarter hundred every day for a year. That's dedication."
        end,
        progress = function(achievement, stats)
            return PSC_CountTotalDaysWithMinKills(25) or 0
        end,
    },
    {
        id = "streaks_50_kills_on_365_days",
        title = "Daily Death Dealer",
        description = function(a) return ("Kill at least 50 players on %d different days"):format(a.targetValue) end,
        iconID = 134067,
        achievementPoints = 500,
        targetValue = 365,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return "Half a hundred souls, day in and day out. You are a machine."
        end,
        progress = function(achievement, stats)
            return PSC_CountTotalDaysWithMinKills(50) or 0
        end,
    },
    {
        id = "streaks_100_kills_on_365_days",
        title = "No Days Off",
        description = function(a) return ("Kill at least 100 players on %d different days"):format(a.targetValue) end,
        iconID = 134067,
        achievementPoints = 500,
        targetValue = 365,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return "Rain or shine, holiday or workday, you were there killing."
        end,
        progress = function(achievement, stats)
            return PSC_CountTotalDaysWithMinKills(100) or 0
        end,
    },
    -- =====================================================
    -- CITY ACHIEVEMENTS - HORDE
    -- =====================================================

    -- STORMWIND (For Horde)
    {
        id = "city_stormwind_50",
        title = "Stormwind Skirmisher",
        description = function(a) return ("Defeat %d players in Stormwind City"):format(a.targetValue) end,
        iconID = 135763,
        achievementPoints = 25,
        targetValue = 50,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've killed %d Alliance in their capital city. The guards barely noticed, but the local merchants are starting to get annoyed at having to clean blood off their storefronts.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Stormwind City")
        end,
    },
    {
        id = "city_stormwind_100",
        title = "Stormwind Slayer",
        description = function(a) return ("Defeat %d players in Stormwind City"):format(a.targetValue) end,
        iconID = 135763,
        achievementPoints = 50,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills in Stormwind, they've started posting 'Wanted' posters with your face at every inn. The bounty is quite flattering, actually.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Stormwind City")
        end,
    },
    {
        id = "city_stormwind_250",
        title = "Stormwind Terrorist",
        description = function(a) return ("Defeat %d players in Stormwind City"):format(a.targetValue) end,
        iconID = 135763,
        achievementPoints = 100,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d Alliance corpses littering the streets of Stormwind, King Varian has personally ordered his royal guard to hunt you down. The city's economy has taken a hit as merchants fear opening their shops.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Stormwind City")
        end,
    },
    {
        id = "city_stormwind_1000",
        title = "The Scourge of Stormwind",
        description = function(a) return ("Defeat %d players in Stormwind City"):format(a.targetValue) end,
        iconID = 135763,
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After slaughtering %d Alliance in Stormwind, your name is whispered in fear throughout the Eastern Kingdoms. Children are told to behave or [YOUR NAME] will come for them. King Varian considers abandoning the city entirely.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Stormwind City")
        end,
    },

    -- IRONFORGE (For Horde)
    {
        id = "city_ironforge_50",
        title = "Ironforge Interloper",
        description = function(a) return ("Defeat %d players in Ironforge"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236805",
        achievementPoints = 25,
        targetValue = 50,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've slain %d dwarves and their allies within their mountain fortress. The locals are starting to take notice of the corpses piling up in the Great Forge.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Ironforge")
        end,
    },
    {
        id = "city_ironforge_100",
        title = "Ironforge Invader",
        description = function(a) return ("Defeat %d players in Ironforge"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236805",
        achievementPoints = 50,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills in Ironforge, the dwarves have started to fortify their positions. The local blacksmiths are working overtime to arm their defenders against your onslaught.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Ironforge")
        end,
    },
    {
        id = "city_ironforge_250",
        title = "Ironforge Assaulter",
        description = function(a) return ("Defeat %d players in Ironforge"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236805",
        achievementPoints = 100,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d Alliance dead at your hands within the mountain city, King Magni Bronzebeard has declared a state of emergency. The once-bustling markets have fallen silent as citizens barricade themselves in their homes.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Ironforge")
        end,
    },
    {
        id = "city_ironforge_1000",
        title = "The Hammer of Ironforge",
        description = function(a) return ("Defeat %d players in Ironforge"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236805",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills in Ironforge, the dwarves have added your likeness to their ancient tablets of sworn enemies. The city's defenses have been entirely reworked because of you. Your name is cursed in Dwarven taverns across Azeroth.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Ironforge")
        end,
    },

    -- DARNASSUS (For Horde)
    {
        id = "city_darnassus_50",
        title = "Darnassus Despoiler",
        description = function(a) return ("Defeat %d players in Darnassus"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236740",
        achievementPoints = 25,
        targetValue = 50,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've slain %d night elves in their sacred city. The Sentinels have begun to increase patrols throughout Teldrassil.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Darnassus")
        end,
    },
    {
        id = "city_darnassus_100",
        title = "Darnassus Destroyer",
        description = function(a) return ("Defeat %d players in Darnassus"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236740",
        achievementPoints = 50,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills in Darnassus, Tyrande Whisperwind has personally blessed the Sentinels with enhanced powers to combat your threat. The druids have begun strengthening the magical defenses of the World Tree.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Darnassus")
        end,
    },
    {
        id = "city_darnassus_250",
        title = "Darnassus Defiler",
        description = function(a) return ("Defeat %d players in Darnassus"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236740",
        achievementPoints = 100,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d night elves fallen to your attacks, the Temple of the Moon has become a hospital for your victims. The Cenarion Circle has convened an emergency council to address your continued assault on their sacred grounds.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Darnassus")
        end,
    },
    {
        id = "city_darnassus_1000",
        title = "The Nightmare of Darnassus",
        description = function(a) return ("Defeat %d players in Darnassus"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236740",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills in Darnassus, your name is etched into the bark of Teldrassil itself as a warning to future generations. The night elves now include you in their ancient prophecies of doom. Tyrande herself has sworn to see your end.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Darnassus")
        end,
    },

    -- =====================================================
    -- CITY ACHIEVEMENTS - ALLIANCE
    -- =====================================================

    -- ORGRIMMAR (For Alliance)
    {
        id = "city_orgrimmar_50",
        title = "Orgrimmar Operative",
        description = function(a) return ("Defeat %d players in Orgrimmar"):format(a.targetValue) end,
        iconID = 135759,
        achievementPoints = 25,
        targetValue = 50,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've slain %d Horde in their capital city. The Kor'kron guards have started taking note of Alliance infiltration.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Orgrimmar")
        end,
    },
    {
        id = "city_orgrimmar_100",
        title = "Orgrimmar Assassin",
        description = function(a) return ("Defeat %d players in Orgrimmar"):format(a.targetValue) end,
        iconID = 135759,
        achievementPoints = 50,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills in Orgrimmar, Thrall has posted additional guards at all city entrances. The warchief has personally put a bounty on your head.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Orgrimmar")
        end,
    },
    {
        id = "city_orgrimmar_250",
        title = "Orgrimmar Saboteur",
        description = function(a) return ("Defeat %d players in Orgrimmar"):format(a.targetValue) end,
        iconID = 135759,
        achievementPoints = 100,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d Horde dead at your hands, the streets of Orgrimmar have become eerily quiet. Citizens rush through the Valley of Strength, fearing to linger in open areas. Thrall has consulted with his advisors about magical barriers for the city.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Orgrimmar")
        end,
    },
    {
        id = "city_orgrimmar_1000",
        title = "The Siege of Orgrimmar",
        description = function(a) return ("Defeat %d players in Orgrimmar"):format(a.targetValue) end,
        iconID = 135759,
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills in Orgrimmar, your exploits are told in hushed whispers in orcish war camps across Azeroth. The Horde has commissioned special forces specifically trained to counter your tactics. Thrall now mentions you by name in his speeches as the embodiment of Alliance aggression.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Orgrimmar")
        end,
    },

    -- THUNDER BLUFF (For Alliance)
    {
        id = "city_thunderbluff_50",
        title = "Thunder Bluff Trespasser",
        description = function(a) return ("Defeat %d players in Thunder Bluff"):format(a.targetValue) end,
        iconID = 135765,
        achievementPoints = 25,
        targetValue = 50,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've killed %d Tauren and their allies atop their sacred mesas. The Bluffwatchers have begun to organize more vigilant patrols.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Thunder Bluff")
        end,
    },
    {
        id = "city_thunderbluff_100",
        title = "Thunder Bluff Tormentor",
        description = function(a) return ("Defeat %d players in Thunder Bluff"):format(a.targetValue) end,
        iconID = 135765,
        achievementPoints = 50,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills in Thunder Bluff, Cairne Bloodhoof has called upon the spirits of the ancestors to watch over the city. The elevators are now guarded day and night.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Thunder Bluff")
        end,
    },
    {
        id = "city_thunderbluff_250",
        title = "Thunder Bluff Terminator",
        description = function(a) return ("Defeat %d players in Thunder Bluff"):format(a.targetValue) end,
        iconID = 135765,
        achievementPoints = 100,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d Tauren dead by your hand, the peaceful city has become a place of fear. The drums beat day and night as shamans perform rituals to protect the people. Cairne has personally vowed to end your rampage.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Thunder Bluff")
        end,
    },
    {
        id = "city_thunderbluff_1000",
        title = "The Cataclysm of Thunder Bluff",
        description = function(a) return ("Defeat %d players in Thunder Bluff"):format(a.targetValue) end,
        iconID = 135765,
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills in Thunder Bluff, the Tauren have added your likeness to their ancestral cave paintings as a dire warning. Mothers scare their calves with stories of [YOUR NAME]. The peace-loving Tauren now have a special exception to their philosophy of harmony - you.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Thunder Bluff")
        end,
    },

    -- UNDERCITY (For Alliance)
    {
        id = "city_undercity_50",
        title = "Undercity Undertaker",
        description = function(a) return ("Defeat %d players in Undercity"):format(a.targetValue) end,
        iconID = 135766,
        achievementPoints = 25,
        targetValue = 50,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("You've slain %d Forsaken in their underground lair. The Deathguards have noted your activity in their logbooks.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Undercity")
        end,
    },
    {
        id = "city_undercity_100",
        title = "Undercity Usurper",
        description = function(a) return ("Defeat %d players in Undercity"):format(a.targetValue) end,
        iconID = 135766,
        achievementPoints = 50,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills in Undercity, Lady Sylvanas has ordered the Royal Apothecary Society to develop special plagues just for you. The sewers are now regularly patrolled by elite Deathstalkers.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Undercity")
        end,
    },
    {
        id = "city_undercity_250",
        title = "Undercity Undertow",
        description = function(a) return ("Defeat %d players in Undercity"):format(a.targetValue) end,
        iconID = 135766,
        achievementPoints = 100,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d Forsaken slain again at your hands, the former halls of Lordaeron have become a fortress. Sylvanas has dispatched her Dark Rangers to hunt you specifically. Your blood samples are being studied intensely by the apothecaries.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Undercity")
        end,
    },
    {
        id = "city_undercity_1000",
        title = "The Plague of Undercity",
        description = function(a) return ("Defeat %d players in Undercity"):format(a.targetValue) end,
        iconID = 135766,
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills in Undercity, Sylvanas has composed a special banshee's wail just for you. The Forsaken now use your name as a curse. In an ironic twist, your victims hope that someday you'll join them in undeath so they can exact their revenge for eternity.")
                :format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Undercity")
        end,
    },
    {
        id = "bg_arathi_250",
        title = "Basin Blade",
        description = function(a) return ("Defeat %d players in Arathi Basin"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236385",
        achievementPoints = 25,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("After %d kills, blood stains every resource node. The Basin remembers your first taste of slaughter."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Arathi Basin")
        end,
    },
    {
        id = "bg_arathi_500",
        title = "Resource Hunter",
        description = function(a) return ("Defeat %d players in Arathi Basin"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236385",
        achievementPoints = 50,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d corpses scattered across the Basin, the highlands weep crimson tears. Your reputation spreads like wildfire among both factions."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Arathi Basin")
        end,
    },
    {
        id = "bg_arathi_750",
        title = "Death's Herald",
        description = function(a) return ("Defeat %d players in Arathi Basin"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236385",
        achievementPoints = 100,
        targetValue = 750,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d souls have made you death's herald in these cursed highlands. The ancient stones whisper your name in dread."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Arathi Basin")
        end,
    },
    {
        id = "bg_arathi_1000",
        title = "The Shadow King",
        description = function(a) return ("Defeat %d players in Arathi Basin"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236385",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("One thousand victims have crowned you the shadow that haunts every flag capture. Both armies flee at your approach."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Arathi Basin")
        end,
    },
    {
        id = "bg_wsg_250",
        title = "Canyon Reaper",
        description = function(a) return ("Defeat %d players in Warsong Gulch"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236396",
        achievementPoints = 25,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d screams now echo through the twisted canyon forever. The rocks themselves remember your brutality."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Warsong Gulch")
        end,
    },
    {
        id = "bg_wsg_500",
        title = "The Flag Slayer",
        description = function(a) return ("Defeat %d players in Warsong Gulch"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236396",
        achievementPoints = 50,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d fallen flag bearers, no one escapes the Reaper's embrace. The banners themselves drip with terror."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Warsong Gulch")
        end,
    },
    {
        id = "bg_wsg_750",
        title = "Forest's Bane",
        description = function(a) return ("Defeat %d players in Warsong Gulch"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236396",
        achievementPoints = 100,
        targetValue = 750,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("Your %d victims have silenced even the ancient forest spirits. They dare not whisper your cursed name."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Warsong Gulch")
        end,
    },
    {
        id = "bg_wsg_1000",
        title = "Eternal Nightmare",
        description = function(a) return ("Defeat %d players in Warsong Gulch"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236396",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("One thousand souls have birthed a legend that transcends death itself. You are Warsong's eternal nightmare."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Warsong Gulch")
        end,
    },
    {
        id = "bg_av_250",
        title = "Winter's Edge",
        description = function(a) return ("Defeat %d players in Alterac Valley"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236388",
        achievementPoints = 25,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d frozen corpses mark your bloodied path through the snow. The valley knows a new predator stalks its peaks."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Alterac Valley")
        end,
    },
    {
        id = "bg_av_500",
        title = "Blood on Snow",
        description = function(a) return ("Defeat %d players in Alterac Valley"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236388",
        achievementPoints = 50,
        targetValue = 500,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("With %d fallen warriors, the white snow drinks deep of crimson blood. Your legend grows with every frozen battlefield."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Alterac Valley")
        end,
    },
    {
        id = "bg_av_750",
        title = "The Frozen Throne",
        description = function(a) return ("Defeat %d players in Alterac Valley"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236388",
        achievementPoints = 100,
        targetValue = 750,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("%d souls have built your throne of ice and death. Winter itself now bows to a colder, darker master."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Alterac Valley")
        end,
    },
    {
        id = "bg_av_1000",
        title = "Soul of Winter",
        description = function(a) return ("Defeat %d players in Alterac Valley"):format(a.targetValue) end,
        iconID = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236388",
        achievementPoints = 250,
        targetValue = 1000,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = function(a)
            return ("One thousand souls have made you the endless winter that devours hope. You are Alterac's eternal frost, consuming all warmth and life."):format(a.targetValue)
        end,
        progress = function(achievement, stats)
            return PSC_GetZoneKills(stats, PSC_ZONE_TRANSLATIONS_CLASSIC, "Alterac Valley")
        end,
    },

    -- NPC Kills: Corporal Keeshan
    {
        id = "npc_horde_keeshan_1",
        title = "Mission Failed",
        description = "Eliminate Corporal Keeshan.",
        iconID = 135726,
        achievementPoints = 10,
        targetValue = 1,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "Keeshan couldn't survive the mountains.",
        progress = function(achievement, stats)
            return stats.npcKills["Corporal Keeshan"] or 0
        end,
    },
    {
        id = "npc_horde_keeshan_25",
        title = "Redridge Stalker",
        description = "Eliminate Corporal Keeshan 25 times.",
        iconID = 135726,
        achievementPoints = 25,
        targetValue = 25,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "He keeps coming back, and you keep sending him away.",
        progress = function(achievement, stats)
            return stats.npcKills["Corporal Keeshan"] or 0
        end,
    },
    {
        id = "npc_horde_keeshan_50",
        title = "Guerrilla Warfare",
        description = "Eliminate Corporal Keeshan 50 times.",
        iconID = 135726,
        achievementPoints = 50,
        targetValue = 50,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "Redridge is your territory now.",
        progress = function(achievement, stats)
            return stats.npcKills["Corporal Keeshan"] or 0
        end,
    },
    {
        id = "npc_horde_keeshan_100",
        title = "One Man Army Destroyer",
        description = "Eliminate Corporal Keeshan 100 times.",
        iconID = 135726,
        achievementPoints = 100,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "You've stopped the Rambo of Redridge permanently.",
        progress = function(achievement, stats)
            return stats.npcKills["Corporal Keeshan"] or 0
        end,
    },

    -- NPC Kills: The Defias Traitor
    {
        id = "npc_horde_defias_traitor_1",
        title = "You Shall Not Pass!",
        description = "Eliminate The Defias Traitor.",
        iconID = 134166,
        achievementPoints = 10,
        targetValue = 1,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "The traitor didn't make it to Moonbrook.",
        progress = function(achievement, stats)
            return stats.npcKills["The Defias Traitor"] or 0
        end,
    },
    {
        id = "npc_horde_defias_traitor_25",
        title = "Escort Disruptor",
        description = "Eliminate The Defias Traitor 25 times.",
        iconID = 134166,
        achievementPoints = 25,
        targetValue = 25,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "Westfall is safer without snitches... or without you?",
        progress = function(achievement, stats)
            return stats.npcKills["The Defias Traitor"] or 0
        end,
    },
    {
        id = "npc_horde_defias_traitor_50",
        title = "Roadblock",
        description = "Eliminate The Defias Traitor 50 times.",
        iconID = 134166,
        achievementPoints = 50,
        targetValue = 50,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "No one walks down the Westfall road on your watch.",
        progress = function(achievement, stats)
            return stats.npcKills["The Defias Traitor"] or 0
        end,
    },
    {
        id = "npc_horde_defias_traitor_100",
        title = "Traitor to the Traitor",
        description = "Eliminate The Defias Traitor 100 times.",
        iconID = 134166,
        achievementPoints = 100,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "You've killed him so many times, he might as well stay at Moonbrook.",
        progress = function(achievement, stats)
            return stats.npcKills["The Defias Traitor"] or 0
        end,
    },
    {
        id = "bonus_npc_horde_defias_traitor_250",
        title = "Who's Your Daddy?",
        description = "Eliminate The Defias Traitor 250 times.",
        iconID = 132308,
        achievementPoints = 0,
        targetValue = 250,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "He spawns. He sees you. He dies. He spawns. He sees you. He dies. Two hundred and fifty times. The real traitor was the hope he felt each time he respawned. The Spirit Healer is charging him rent.",
        progress = function(achievement, stats)
            return stats.npcKills["The Defias Traitor"] or 0
        end,
    },

    -- NPC Kills: Defias Messenger
    {
        id = "npc_horde_defias_messenger_1",
        title = "Message Intercepted",
        description = "Eliminate Defias Messenger.",
        iconID = 133471,
        achievementPoints = 10,
        targetValue = 1,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "The message never arrived.",
        progress = function(achievement, stats)
            return stats.npcKills["Defias Messenger"] or 0
        end,
    },
    {
        id = "npc_horde_defias_messenger_25",
        title = "Postman Down",
        description = "Eliminate Defias Messenger 25 times.",
        iconID = 133471,
        achievementPoints = 25,
        targetValue = 25,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "Neither snow nor rain nor heat... but you stopped him.",
        progress = function(achievement, stats)
            return stats.npcKills["Defias Messenger"] or 0
        end,
    },
    {
        id = "npc_horde_defias_messenger_50",
        title = "Dead Letter Office",
        description = "Eliminate Defias Messenger 50 times.",
        iconID = 133471,
        achievementPoints = 50,
        targetValue = 50,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "He's got a lot of undelivered mail now.",
        progress = function(achievement, stats)
            return stats.npcKills["Defias Messenger"] or 0
        end,
    },
    {
        id = "npc_horde_defias_messenger_100",
        title = "Kill the Messenger",
        description = "Eliminate Defias Messenger 100 times.",
        iconID = 133471,
        achievementPoints = 100,
        targetValue = 100,
        condition = function(achievement, stats)
            return achievement.progress(achievement, stats) >= achievement.targetValue
        end,
        unlocked = false,
        completedDate = nil,
        subText = "They say don't shoot the messenger. You disagree.",
        progress = function(achievement, stats)
            return stats.npcKills["Defias Messenger"] or 0
        end,
    },
}

-- Helper function to generate time-based achievements
local function CreateTimeAchievement(idPrefix, titlePrefix, targetHours, tiers, iconID, subTexts, descriptionFmt)
    for i, tier in ipairs(tiers) do
        local achievement = {
            id = idPrefix .. "_" .. (i - 1),
            title = titlePrefix .. " " .. ({ "I", "II", "III", "IV" })[i],
            killsRequired = tier.kills,
            description = function(a)
                local text = descriptionFmt:format(a.killsRequired)
                if a.killsRequired == 1 then
                    text = text:gsub("kills", "kill")
                end
                return text
            end,
            iconID = iconID,
            achievementPoints = tier.points,
            targetValue = targetHours,
            condition = function(achievement, stats)
                return achievement.progress(achievement, stats) >= achievement.targetValue
            end,
            unlocked = false,
            completedDate = nil,
            subText = subTexts[i],
            progress = function(achievement, stats)
                if not stats.hourlyData then return 0 end
                local hoursCompleted = 0
                for h = 0, 23 do
                    local count = stats.hourlyData[h] or 0
                    if count >= achievement.killsRequired then
                        hoursCompleted = hoursCompleted + 1
                    end
                end
                return hoursCompleted
            end,
        }
        table.insert(AchievementSystem.achievementsClassic, achievement)
    end
end

-- 16h Ganker
local tiers16h = {
    { kills = 1, points = 50 },
    { kills = 10, points = 75 },
    { kills = 100, points = 100 },
    { kills = 250, points = 250 },
}
local subTexts16h = {
    "You've filled the waking hours with violence.",
    "16 hours a day. That's a full-time job plus overtime. Dedication at its finest.",
    "Sleep is for the weak, and you are proving to be quite strong.",
    "The casuals log off, but you remain. The dedicated 16-hour shift of doom.",
}
CreateTimeAchievement("time_16h_ganker", "The 16h Ganker", 16, tiers16h, 134377, subTexts16h, "Get %d kills during 16 different hours of the day")

-- 24h Ganker
local tiers24h = {
    { kills = 1, points = 75 },
    { kills = 10, points = 100 },
    { kills = 100, points = 250 },
    { kills = 250, points = 500 },
}
local subTexts24h = {
    "You have found a victim at every hour of the clock. You exist outside of time.",
    "Around the clock service. No matter when they log in, they are not safe from you.",
    "Your sleep schedule is non-existent. You are the server's eternal nightmare.",
    "The sun rises, you kill. The moon rises, you kill. Do you ever rest?",
}
CreateTimeAchievement("time_24h_ganker", "The 24h Ganker", 24, tiers24h, 134376, subTexts24h, "Get %d kills during every single hour of the day (00:00 - 23:59)")


