local _, MEM = ...

MEM.Localization = setmetatable({},{__index=function(self,key)
		geterrorhandler()("Memento (Debug): Missing entry for '" .. tostring(key) .. "'")
		return key
	end})

local L = MEM.Localization

-- Options

L["options.general"] = "General Options"
L["options.general.notification.name"] = "Chat notification"
L["options.general.notification.tooltip"] = "Activate or deactivate the notification in the chat when a screenshot has been taken."
L["options.general.notification.timestamp.name"] = "Chat output with timestamp"
L["options.general.notification.timestamp.tooltip"] = "Activate or deactivate the chat output with timestamp when a screenshot has been taken."
L["options.general.notification.class.name"] = "Chat output of the class"
L["options.general.notification.class.tooltip"] = "Activate or deactivate the chat output of the class when a screenshot has been taken."
L["options.general.notification.time-played.name"] = "Chat output of the total time played"
L["options.general.notification.time-played.tooltip"] = "Activate or deactivate the chat output of the total time played when a screenshot has been taken.\n\nWhen at least one time played output is enabled, WoW requests the time played after login and displays it in the chat."
L["options.general.notification.level-time-played.name"] = "Chat output of the time played on the current level"
L["options.general.notification.level-time-played.tooltip"] = "Activate or deactivate the chat output of the time played on the current level when a screenshot has been taken.\n\nWhen at least one time played output is enabled, WoW requests the time played after login and displays it in the chat."
L["options.general.hide-ui.name"] = "Hide user interface for screenshot"
L["options.general.hide-ui.tooltip"] = "Activate or deactivate the option to hide the user interface for the screenshot. A small success notification is displayed instead.\n\nNote: The user interface cannot be hidden automatically during a combat. In this case, the screenshot is taken with the user interface."
L["options.general.screenshot-sound.name"] = "Screenshot sound effect"
L["options.general.screenshot-sound.tooltip"] = "Activate or deactivate a sound effect after a screenshot has been taken."
L["options.general.screenshot-sound-style.name"] = "Sound effect"
L["options.general.screenshot-sound-style.tooltip"] = "Choose the sound effect that is played after a screenshot. The sound is played once as a preview when selected."
L["options.general.screenshot-sound-style.option.memento-camera"] = "Camera Shutter (Memento)"
L["options.general.screenshot-sound-style.option.notification"] = "Notification (Memento)"
L["options.general.screenshot-sound-style.option.melody"] = "Melody (Memento)"
L["options.general.screenshot-sound-style.option.quest-complete"] = "Quest Complete"
L["options.general.screenshot-sound-style.option.ready-check"] = "Ready Check"
L["options.general.screenshot-sound-style.option.raid-warning"] = "Raid Warning"
L["options.general.minimap-button.name"] = "Minimap Button"
L["options.general.minimap-button.tooltip"] = "When this is enabled, the minimap button is displayed."
L["options.general.debug-mode.name"] = "Debug Mode"
L["options.general.debug-mode.tooltip"] = "Enabling the debug mode displays additional information in the chat."

L["options.event.general.active.tooltip"] = "Activate or deactivate the automatic creation of a screenshot for the event %s."
L["options.event.general.delay.name"] = "Delay"
L["options.event.general.delay.tooltip"] = "The time delay of the screenshot after the event %s was triggered.\n\nDefault: %d second(s)"

L["options.event"] = "Screenshots"

L["options.event.achievement"] = "Achievements"
L["options.event.achievement.personal"] = "Personal Achievement"
L["options.event.achievement.personal.exist.name"] = "Take a screenshot if a personal achievement has already been reached"
L["options.event.achievement.personal.exist.tooltip"] = "Activate or deactivate the creation of a screenshot if a personal achievement has already been reached by another character."
L["options.event.achievement.criteria"] = "Personal Achievement Criteria"
L["options.event.achievement.guild"] = "Guild Achievement"

L["options.event.encounter"] = "Boss Fight"
L["options.event.encounter.victory"] = "Victory"
L["options.event.encounter.wipe"] = "Wipe"
L["options.event.encounter.party"] = "Dungeon Boss"
L["options.event.encounter.raid"] = "Raid Boss"
L["options.event.encounter.scenario"] = "Scenario / Delve Boss"
L["options.event.encounter.victory.first.name"] = "only first victory per difficulty"
L["options.event.encounter.victory.first.tooltip"] = "Controls whether a screenshot is taken only for the first victory per boss and difficulty."

L["options.event.pvp"] = "Player vs. Player"
L["options.event.pvp.duel"] = "Duel finished"
L["options.event.pvp.arena"] = "Arena completed"
L["options.event.pvp.battleground"] = "Battleground completed"
L["options.event.pvp.brawl"] = "Brawl completed"
L["options.event.pvp.victory.name"] = "only in the event of a victory"
L["options.event.pvp.victory.tooltip"] = "Activate or deactivate the automatic creation of a screenshot when you have won the PvP match."

L["options.event.warband-collection"] = "Warband Collections"
L["options.event.warband-collection.new-pet"] = "New Pet"
L["options.event.warband-collection.new-mount"] = "New Mount"
L["options.event.warband-collection.new-toy"] = "New Toy"
L["options.event.warband-collection.new-recipe"] = "New Recipe"
L["options.event.warband-collection.new-housing-item"] = "New Housing Item"

L["options.event.other"] = "Other"
L["options.event.other.login"] = "Player Login"
L["options.event.other.level-up"] = "Level-Up"
L["options.event.other.level-up.time-played.name"] = "Show time played on the previous level"
L["options.event.other.level-up.time-played.tooltip"] = "Adds the time played on the previous level to the chat notification when a level-up screenshot is taken.\n\nWhen at least one time played output is enabled, WoW requests the time played after login and displays it in the chat."
L["options.event.other.death"] = "Player Death"
L["options.event.other.death.instance.name"] = "Screenshot behavior in instances"
L["options.event.other.death.instance.tooltip"] = "Screenshots are only created inside and / or outside an instance, depending on the following settings for player death.\n\nAn instance includes arenas, battlegrounds, raids or dungeons."
L["options.event.other.death.instance.option.0"] = "inside and outside of instances"
L["options.event.other.death.instance.option.1"] = "only inside of instances"
L["options.event.other.death.instance.option.2"] = "only outside of instances"
L["options.event.other.mythic"] = "Mythic+ Dungeon Completion"
L["options.event.other.loot-toast"] = "Special Loot"
L["options.event.other.loot-toast.tooltip"] = "Enable or disable screenshots for loot that WoW displays in a loot toast. Items, money and currencies can be selected separately."
L["options.event.other.loot-toast.item.name"] = "Items"
L["options.event.other.loot-toast.item.tooltip"] = "Take screenshots when WoW displays an item in a loot toast. The configured minimum quality applies."
L["options.event.other.loot-toast.quality.name"] = "Minimum Quality"
L["options.event.other.loot-toast.quality.tooltip"] = "Sets the minimum quality required for an item displayed in a loot toast to trigger a screenshot."
L["options.event.other.loot-toast.money.name"] = "Money"
L["options.event.other.loot-toast.money.tooltip"] = "Take screenshots when WoW displays money in a loot toast."
L["options.event.other.loot-toast.currency.name"] = "Currencies"
L["options.event.other.loot-toast.currency.tooltip"] = "Take screenshots when WoW displays a currency in a loot toast."
L["options.event.other.interval"] = "Regular Interval"
L["options.event.other.interval-timer.name"] = "Interval"
L["options.event.other.interval-timer.tooltip"] = "The time interval at which a screenshot is taken.\n\nDefault: 5 Minutes"

-- General

L["minimap-button.tooltip"] = "|cnLINK_FONT_COLOR:Right-click|r to open the options."

L["general.seconds-short"] = "sec"
L["general.minutes-short"] = "min"

-- Chat

L["chat.notification.class"] = "Class: %s"
L["chat.notification.time-played"] = "Total time played: %d days, %d hours, %d minutes, %d seconds"
L["chat.notification.level-time-played"] = "Time played on current level: %d days, %d hours, %d minutes, %d seconds"

L["chat.event.achievement.personal.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:Personal Achievement|r - %s"
L["chat.event.achievement.personal.exist"] = "Screenshot taken - |cnGOLD_FONT_COLOR:Personal Achievement|r - %s (has already been reached by another character)"
L["chat.event.achievement.personal.no-link.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:Personal Achievement|r"
L["chat.event.achievement.personal.no-link.exist"] = "Screenshot taken - |cnGOLD_FONT_COLOR:Personal Achievement|r (has already been reached by another character)"
L["chat.event.achievement.criteria.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:Personal Achievement Criteria|r - %s - %s"
L["chat.event.achievement.criteria.no-link.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:Personal Achievement Criteria|r"
L["chat.event.achievement.guild.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:Guild achievement|r - %s"

L["chat.event.encounter.victory.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:Boss Fight - Victory|r - %s (%s)"
L["chat.event.encounter.wipe.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:Boss Fight - Wipe|r - %s (%s)"

L["chat.event.pvp.duel.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:PvP - Duel finished|r"
L["chat.event.pvp.arena.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:PvP - Arena completed|r"
L["chat.event.pvp.battleground.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:PvP - Battleground completed|r"
L["chat.event.pvp.brawl.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:PvP - Brawl completed|r"

L["chat.event.warband-collection.new-pet.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:New Pet|r"
L["chat.event.warband-collection.new-mount.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:New Mount|r"
L["chat.event.warband-collection.new-toy.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:New Toy|r"
L["chat.event.warband-collection.new-recipe.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:New Recipe|r"
L["chat.event.warband-collection.new-housing-item.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:New Housing Item|r"

L["chat.event.login.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:Player Login|r"
L["chat.event.level-up.retail.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:Level-Up|r - |cffFF4E00|Hlevelup:%1$s:LEVEL_UP_TYPE_CHARACTER|h[Level %1$s]|h|r"
L["chat.event.level-up.classic.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:Level-Up|r - |cffFF4E00[Level %1$s]|r"
L["chat.event.level-up.time-played"] = "Time played on level %d: %d days, %d hours, %d minutes, %d seconds"
L["chat.event.death.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:Player Death|r"
L["chat.event.mythic.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:Mythic+ Dungeon Completion|r"
L["chat.event.loot-toast.item.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:Special Loot - Item|r - %s"
L["chat.event.loot-toast.money.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:Special Loot - Money|r - %s"
L["chat.event.loot-toast.currency.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:Special Loot - Currency|r - %s x%d"
L["chat.event.interval.new"] = "Screenshot taken - |cnGOLD_FONT_COLOR:Regular Interval|r"

-- Capture

L["capture.message"] = "Screenshot taken"
