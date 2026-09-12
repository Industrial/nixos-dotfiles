local addonName, MEM = ...

-- Library
local AWL = ArcaneWizardLibrary
local Addon = AWL:GetAddon(addonName)

-- Localization
local L = MEM.Localization

-- Current module
local Options = MEM.Modules.Options

-- Module imports
local Capture = MEM.Modules.Capture
local Utils = MEM.Modules.Utils

-- Variables
local minimapButtonProxy = setmetatable({}, {
	__index = function(_, key)
		if key == "hide" then
			return not MEM.Settings.general["minimap-button"]["hide"]
		end
	end,
	__newindex = function(_, key, value)
		if key ~= "hide" then
			return
		end

		MEM.Settings.general["minimap-button"]["hide"] = not value

		if value then
			Utils.minimapButton:Show(addonName)
		else
			Utils.minimapButton:Hide(addonName)
		end
	end,
})

local screenshotSoundOptions = {}

for _, soundData in ipairs(MEM.SCREENSHOT_SOUNDS) do
	screenshotSoundOptions[#screenshotSoundOptions + 1] = {
		value = soundData.key,
		label = L[soundData.labelKey]
	}
end

-----------------------
--- Local Functions ---
-----------------------

local function GetVal(setting) return setting:GetValue() end
local function FormatSeconds(value) return value .. " " .. L["general.seconds-short"] end
local function FormatMinutes(value) return value .. " " .. L["general.minutes-short"] end

local function TimePlayedOptionChanged(_, value)
	if value then
		Utils:RequestTimePlayed()
	end
end

------------------------
--- Module Functions ---
------------------------

function Options:Initialize()
	local category, layout = Settings.RegisterVerticalLayoutCategory(addonName)

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["options.general"]))

	-- Notification
	local initializerNotification = AWL.Settings:AddCheckbox(category, {
		variableTable	= MEM.Settings.general,
		settingKey		= addonName .. "_notification",
		variableName	= "notification",
		name			= L["options.general.notification.name"],
		tooltip			= L["options.general.notification.tooltip"],
		default			= true
	})

	local function IsNotificationEnabled()
		return MEM.Settings.general["notification"]
	end

	-- Notification: Show Timestamp
	AWL.Settings:AddCheckbox(category, {
		variableTable	= MEM.Settings.general,
		settingKey		= addonName .. "_notification-timestamp",
		variableName	= "notification-timestamp",
		name			= L["options.general.notification.timestamp.name"],
		tooltip			= L["options.general.notification.timestamp.tooltip"],
		default			= false,
		parentInit		= initializerNotification,
		parentCondition	= IsNotificationEnabled
	})

	-- Notification: Show Class
	AWL.Settings:AddCheckbox(category, {
		variableTable	= MEM.Settings.general,
		settingKey		= addonName .. "_notification-class",
		variableName	= "notification-class",
		name			= L["options.general.notification.class.name"],
		tooltip			= L["options.general.notification.class.tooltip"],
		default			= false,
		parentInit		= initializerNotification,
		parentCondition	= IsNotificationEnabled
	})

	-- Notification: Show Time Played
	AWL.Settings:AddCheckbox(category, {
		variableTable	= MEM.Settings.general,
		settingKey		= addonName .. "_notification-time-played",
		variableName	= "notification-time-played",
		name			= L["options.general.notification.time-played.name"],
		tooltip			= L["options.general.notification.time-played.tooltip"],
		default			= false,
		parentInit		= initializerNotification,
		parentCondition	= IsNotificationEnabled,
		onClick			= TimePlayedOptionChanged
	})

	-- Notification: Show Level Time Played
	AWL.Settings:AddCheckbox(category, {
		variableTable	= MEM.Settings.general,
		settingKey		= addonName .. "_notification-level-time-played",
		variableName	= "notification-level-time-played",
		name			= L["options.general.notification.level-time-played.name"],
		tooltip			= L["options.general.notification.level-time-played.tooltip"],
		default			= false,
		parentInit		= initializerNotification,
		parentCondition	= IsNotificationEnabled,
		onClick			= TimePlayedOptionChanged
	})

	-- Hide UI
	AWL.Settings:AddCheckbox(category, {
		variableTable	= MEM.Settings.general,
		settingKey		= addonName .. "_hide-ui",
		variableName	= "hide-ui",
		name			= L["options.general.hide-ui.name"],
		tooltip			= L["options.general.hide-ui.tooltip"],
		default			= false
	})

	-- Screenshot Sound
	local initializerScreenshotSound, settingScreenshotSound = AWL.Settings:AddCheckbox(category, {
		variableTable	= MEM.Settings.general,
		settingKey		= addonName .. "_screenshot-sound",
		variableName	= "screenshot-sound",
		name			= L["options.general.screenshot-sound.name"],
		tooltip			= L["options.general.screenshot-sound.tooltip"],
		default			= false
	})


	AWL.Settings:AddDropdown(category, {
		variableTable	= MEM.Settings.general,
		settingKey		= addonName .. "_screenshot-sound-style",
		variableName	= "screenshot-sound-style",
		name			= L["options.general.screenshot-sound-style.name"],
		tooltip			= L["options.general.screenshot-sound-style.tooltip"],
		default			= MEM.SCREENSHOT_SOUND_DEFAULT,
		options			= screenshotSoundOptions,
		parentInit		= initializerScreenshotSound,
		parentCondition	= function() return GetVal(settingScreenshotSound) end,
		onClick			= function(_, value) Capture:PreviewScreenshotSound(value) end
	})

	-- Minimap Button Visibility
	AWL.Settings:AddCheckbox(category, {
		variableTable	= minimapButtonProxy,
		settingKey		= addonName .. "_hide",
		variableName	= "hide",
		name			= L["options.general.minimap-button.name"],
		tooltip			= L["options.general.minimap-button.tooltip"],
		default			= true
	})

	-- Debug Mode
	AWL.Settings:AddCheckbox(category, {
		variableTable	= MEM.Settings.general,
		settingKey		= addonName .. "_debug-mode",
		variableName	= "debug-mode",
		name			= L["options.general.debug-mode.name"],
		tooltip			= L["options.general.debug-mode.tooltip"],
		default			= false
	})

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["options.event"]))

	if AWL.GAME_TYPE_MAINLINE or AWL.GAME_TYPE_MISTS then
		local _, isAchievementExpanded = AWL.Settings:AddExpandableHeader(layout, L["options.event.achievement"])

		-- Personal Achievement
		local initializerAchievementPersonal, settingAchievementPersonal = AWL.Settings:AddCheckboxSliderCombo(category, layout, {
			variableTable			= MEM.Settings.event,
			checkboxSettingKey		= addonName .. "_achievement-personal-active",
			checkboxVariableName	= "achievement-personal-active",
			checkboxName			= L["options.event.achievement.personal"],
			checkboxTooltip			= L["options.event.general.active.tooltip"]:format(L["options.event.achievement.personal"]),
			checkboxDefault			= true,

			sliderSettingKey		= addonName .. "_achievement-personal-delay",
			sliderVariableName		= "achievement-personal-delay",
			sliderName				= L["options.event.general.delay.name"],
			sliderTooltip			= L["options.event.general.delay.tooltip"]:format(L["options.event.achievement.personal"], 3),
			sliderDefault			= 3, sliderMin = 1, sliderMax = 10, sliderStep = 1,
			sliderFormatter			= FormatSeconds,

			shownPredicate			= isAchievementExpanded
		})

		-- Personal Achievement: Exist Check
		AWL.Settings:AddCheckbox(category, {
			variableTable	= MEM.Settings.event,
			settingKey		= addonName .. "_achievement-personal-exist",
			variableName	= "achievement-personal-exist",
			name			= L["options.event.achievement.personal.exist.name"],
			tooltip			= L["options.event.achievement.personal.exist.tooltip"],
			default			= false,
			parentInit		= initializerAchievementPersonal,
			parentCondition	= function() return GetVal(settingAchievementPersonal) end,
			shownPredicate	= isAchievementExpanded
		})

		-- Criteria Achievement
		if AWL.GAME_TYPE_MAINLINE then
			AWL.Settings:AddCheckboxSliderCombo(category, layout, {
				variableTable			= MEM.Settings.event,
				checkboxSettingKey		= addonName .. "_achievement-criteria-active",
				checkboxVariableName	= "achievement-criteria-active",
				checkboxName			= L["options.event.achievement.criteria"],
				checkboxTooltip			= L["options.event.general.active.tooltip"]:format(L["options.event.achievement.criteria"]),
				checkboxDefault			= false,

				sliderSettingKey		= addonName .. "_achievement-criteria-delay",
				sliderVariableName		= "achievement-criteria-delay",
				sliderName				= L["options.event.general.delay.name"],
				sliderTooltip			= L["options.event.general.delay.tooltip"]:format(L["options.event.achievement.criteria"], 3),
				sliderDefault			= 3, sliderMin = 1, sliderMax = 10, sliderStep = 1,
				sliderFormatter			= FormatSeconds,

				shownPredicate			= isAchievementExpanded
			})
		end

		-- Guild Achievement
		AWL.Settings:AddCheckboxSliderCombo(category, layout, {
			variableTable			= MEM.Settings.event,
			checkboxSettingKey		= addonName .. "_achievement-guild-active",
			checkboxVariableName	= "achievement-guild-active",
			checkboxName			= L["options.event.achievement.guild"],
			checkboxTooltip			= L["options.event.general.active.tooltip"]:format(L["options.event.achievement.guild"]),
			checkboxDefault			= true,

			sliderSettingKey		= addonName .. "_achievement-guild-delay",
			sliderVariableName		= "achievement-guild-delay",
			sliderName				= L["options.event.general.delay.name"],
			sliderTooltip			= L["options.event.general.delay.tooltip"]:format(L["options.event.achievement.guild"], 3),
			sliderDefault			= 3, sliderMin = 1, sliderMax = 10, sliderStep = 1,
			sliderFormatter			= FormatSeconds,

			shownPredicate			= isAchievementExpanded
		})
	end

	if AWL.GAME_TYPE_MAINLINE then
		local _, isEncounterExpanded = AWL.Settings:AddExpandableHeader(layout, L["options.event.encounter"])
		local eventPartyVictory    = L["options.event.encounter.party"] .. " (" .. L["options.event.encounter.victory"] .. ")"
		local eventPartyWipe       = L["options.event.encounter.party"] .. " (" .. L["options.event.encounter.wipe"] .. ")"
		local eventRaidVictory     = L["options.event.encounter.raid"] .. " (" .. L["options.event.encounter.victory"] .. ")"
		local eventRaidWipe        = L["options.event.encounter.raid"] .. " (" .. L["options.event.encounter.wipe"] .. ")"
		local eventScenarioVictory = L["options.event.encounter.scenario"] .. " (" .. L["options.event.encounter.victory"] .. ")"
		local eventScenarioWipe    = L["options.event.encounter.scenario"] .. " (" .. L["options.event.encounter.wipe"] .. ")"

		-- Dungeon
		local initializerVictoryParty, settingVictoryParty = AWL.Settings:AddCheckboxSliderCombo(category, layout, {
			variableTable			= MEM.Settings.event,
			checkboxSettingKey		= addonName .. "_encounter-victory-party-active",
			checkboxVariableName	= "encounter-victory-party-active",
			checkboxName			= eventPartyVictory,
			checkboxTooltip			= L["options.event.general.active.tooltip"]:format(eventPartyVictory),
			checkboxDefault			= true,

			sliderSettingKey		= addonName .. "_encounter-victory-party-delay",
			sliderVariableName		= "encounter-victory-party-delay",
			sliderName				= L["options.event.general.delay.name"],
			sliderTooltip			= L["options.event.general.delay.tooltip"]:format(eventPartyVictory, 2),
			sliderDefault			= 2, sliderMin = 1, sliderMax = 10, sliderStep = 1,
			sliderFormatter			= FormatSeconds,

			shownPredicate			= isEncounterExpanded
		})

		-- Dungeon: Only First Victory
		AWL.Settings:AddCheckbox(category, {
			variableTable	= MEM.Settings.event,
			settingKey		= addonName .. "_encounter-victory-party-first",
			variableName	= "encounter-victory-party-first",
			name			= L["options.event.encounter.victory.first.name"],
			tooltip			= L["options.event.encounter.victory.first.tooltip"],
			default			= false,
			parentInit		= initializerVictoryParty,
			parentCondition	= function() return GetVal(settingVictoryParty) end,
			shownPredicate	= isEncounterExpanded
		})

		-- Dungeon: Wipe
		AWL.Settings:AddCheckboxSliderCombo(category, layout, {
			variableTable			= MEM.Settings.event,
			checkboxSettingKey		= addonName .. "_encounter-wipe-party-active",
			checkboxVariableName	= "encounter-wipe-party-active",
			checkboxName			= eventPartyWipe,
			checkboxTooltip			= L["options.event.general.active.tooltip"]:format(eventPartyWipe),
			checkboxDefault			= false,

			sliderSettingKey		= addonName .. "_encounter-wipe-party-delay",
			sliderVariableName		= "encounter-wipe-party-delay",
			sliderName				= L["options.event.general.delay.name"],
			sliderTooltip			= L["options.event.general.delay.tooltip"]:format(eventPartyWipe, 2),
			sliderDefault			= 2, sliderMin = 1, sliderMax = 10, sliderStep = 1,
			sliderFormatter			= FormatSeconds,

			shownPredicate			= isEncounterExpanded
		})

		-- Raid
		local initializerVictoryRaid, settingVictoryRaid = AWL.Settings:AddCheckboxSliderCombo(category, layout, {
			variableTable			= MEM.Settings.event,
			checkboxSettingKey		= addonName .. "_encounter-victory-raid-active",
			checkboxVariableName	= "encounter-victory-raid-active",
			checkboxName			= eventRaidVictory,
			checkboxTooltip			= L["options.event.general.active.tooltip"]:format(eventRaidVictory),
			checkboxDefault			= true,

			sliderSettingKey		= addonName .. "_encounter-victory-raid-delay",
			sliderVariableName		= "encounter-victory-raid-delay",
			sliderName				= L["options.event.general.delay.name"],
			sliderTooltip			= L["options.event.general.delay.tooltip"]:format(eventRaidVictory, 2),
			sliderDefault			= 2, sliderMin = 1, sliderMax = 10, sliderStep = 1,
			sliderFormatter			= FormatSeconds,

			shownPredicate			= isEncounterExpanded
		})

		-- Raid: Only First Victory
		AWL.Settings:AddCheckbox(category, {
			variableTable	= MEM.Settings.event,
			settingKey		= addonName .. "_encounter-victory-raid-first",
			variableName	= "encounter-victory-raid-first",
			name			= L["options.event.encounter.victory.first.name"],
			tooltip			= L["options.event.encounter.victory.first.tooltip"],
			default			= false,
			parentInit		= initializerVictoryRaid,
			parentCondition	= function() return GetVal(settingVictoryRaid) end,
			shownPredicate	= isEncounterExpanded
		})

		-- Raid: Wipe
		AWL.Settings:AddCheckboxSliderCombo(category, layout, {
			variableTable			= MEM.Settings.event,
			checkboxSettingKey		= addonName .. "_encounter-wipe-raid-active",
			checkboxVariableName	= "encounter-wipe-raid-active",
			checkboxName			= eventRaidWipe,
			checkboxTooltip			= L["options.event.general.active.tooltip"]:format(eventRaidWipe),
			checkboxDefault			= false,

			sliderSettingKey		= addonName .. "_encounter-wipe-raid-delay",
			sliderVariableName		= "encounter-wipe-raid-delay",
			sliderName				= L["options.event.general.delay.name"],
			sliderTooltip			= L["options.event.general.delay.tooltip"]:format(eventRaidWipe, 2),
			sliderDefault			= 2, sliderMin = 1, sliderMax = 10, sliderStep = 1,
			sliderFormatter			= FormatSeconds,

			shownPredicate			= isEncounterExpanded
		})

		-- Scenario
		local initializerVictoryScenario, settingVictoryScenario = AWL.Settings:AddCheckboxSliderCombo(category, layout, {
			variableTable			= MEM.Settings.event,
			checkboxSettingKey		= addonName .. "_encounter-victory-scenario-active",
			checkboxVariableName	= "encounter-victory-scenario-active",
			checkboxName			= eventScenarioVictory,
			checkboxTooltip			= L["options.event.general.active.tooltip"]:format(eventScenarioVictory),
			checkboxDefault			= true,

			sliderSettingKey		= addonName .. "_encounter-victory-scenario-delay",
			sliderVariableName		= "encounter-victory-scenario-delay",
			sliderName				= L["options.event.general.delay.name"],
			sliderTooltip			= L["options.event.general.delay.tooltip"]:format(eventScenarioVictory, 2),
			sliderDefault			= 2, sliderMin = 1, sliderMax = 10, sliderStep = 1,
			sliderFormatter			= FormatSeconds,

			shownPredicate			= isEncounterExpanded
		})

		-- Scenario: Only First Victory
		AWL.Settings:AddCheckbox(category, {
			variableTable	= MEM.Settings.event,
			settingKey		= addonName .. "_encounter-victory-scenario-first",
			variableName	= "encounter-victory-scenario-first",
			name			= L["options.event.encounter.victory.first.name"],
			tooltip			= L["options.event.encounter.victory.first.tooltip"],
			default			= false,
			parentInit		= initializerVictoryScenario,
			parentCondition	= function() return GetVal(settingVictoryScenario) end,
			shownPredicate	= isEncounterExpanded
		})

		-- Scenario: Wipe
		AWL.Settings:AddCheckboxSliderCombo(category, layout, {
			variableTable			= MEM.Settings.event,
			checkboxSettingKey		= addonName .. "_encounter-wipe-scenario-active",
			checkboxVariableName	= "encounter-wipe-scenario-active",
			checkboxName			= eventScenarioWipe,
			checkboxTooltip			= L["options.event.general.active.tooltip"]:format(eventScenarioWipe),
			checkboxDefault			= false,

			sliderSettingKey		= addonName .. "_encounter-wipe-scenario-delay",
			sliderVariableName		= "encounter-wipe-scenario-delay",
			sliderName				= L["options.event.general.delay.name"],
			sliderTooltip			= L["options.event.general.delay.tooltip"]:format(eventScenarioWipe, 2),
			sliderDefault			= 2, sliderMin = 1, sliderMax = 10, sliderStep = 1,
			sliderFormatter			= FormatSeconds,

			shownPredicate			= isEncounterExpanded
		})
	end

	local _, isPvPExpanded = AWL.Settings:AddExpandableHeader(layout, L["options.event.pvp"])

	-- Duel (Global)
	AWL.Settings:AddCheckboxSliderCombo(category, layout, {
		variableTable			= MEM.Settings.event,
		checkboxSettingKey		= addonName .. "_pvp-duel-active",
		checkboxVariableName	= "pvp-duel-active",
		checkboxName			= L["options.event.pvp.duel"],
		checkboxTooltip			= L["options.event.general.active.tooltip"]:format(L["options.event.pvp.duel"]),
		checkboxDefault			= true,

		sliderSettingKey		= addonName .. "_pvp-duel-delay",
		sliderVariableName		= "pvp-duel-delay",
		sliderName				= L["options.event.general.delay.name"],
		sliderTooltip			= L["options.event.general.delay.tooltip"]:format(L["options.event.pvp.duel"], 1),
		sliderDefault			= 1, sliderMin = 1, sliderMax = 10, sliderStep = 1,
		sliderFormatter			= FormatSeconds,

		shownPredicate			= isPvPExpanded
	})

	if AWL.GAME_TYPE_MAINLINE then
		-- Arena
		AWL.Settings:AddCheckboxSliderCombo(category, layout, {
			variableTable			= MEM.Settings.event,
			checkboxSettingKey		= addonName .. "_pvp-arena-active",
			checkboxVariableName	= "pvp-arena-active",
			checkboxName			= L["options.event.pvp.arena"],
			checkboxTooltip			= L["options.event.general.active.tooltip"]:format(L["options.event.pvp.arena"]),
			checkboxDefault			= true,

			sliderSettingKey		= addonName .. "_pvp-arena-delay",
			sliderVariableName		= "pvp-arena-delay",
			sliderName				= L["options.event.general.delay.name"],
			sliderTooltip			= L["options.event.general.delay.tooltip"]:format(L["options.event.pvp.arena"], 3),
			sliderDefault			= 3, sliderMin = 1, sliderMax = 10, sliderStep = 1,
			sliderFormatter			= FormatSeconds,

			shownPredicate			= isPvPExpanded
		})

		-- Battleground
		local initializerBattleground, settingBattleground = AWL.Settings:AddCheckboxSliderCombo(category, layout, {
			variableTable			= MEM.Settings.event,
			checkboxSettingKey		= addonName .. "_pvp-battleground-active",
			checkboxVariableName	= "pvp-battleground-active",
			checkboxName			= L["options.event.pvp.battleground"],
			checkboxTooltip			= L["options.event.general.active.tooltip"]:format(L["options.event.pvp.battleground"]),
			checkboxDefault			= true,

			sliderSettingKey		= addonName .. "_pvp-battleground-delay",
			sliderVariableName		= "pvp-battleground-delay",
			sliderName				= L["options.event.general.delay.name"],
			sliderTooltip			= L["options.event.general.delay.tooltip"]:format(L["options.event.pvp.battleground"], 3),
			sliderDefault			= 3, sliderMin = 1, sliderMax = 10, sliderStep = 1,
			sliderFormatter			= FormatSeconds,

			shownPredicate			= isPvPExpanded
		})

		-- Battleground: Only Victory
		AWL.Settings:AddCheckbox(category, {
			variableTable	= MEM.Settings.event,
			settingKey		= addonName .. "_pvp-battleground-victory-only",
			variableName	= "pvp-battleground-victory-only",
			name			= L["options.event.pvp.victory.name"],
			tooltip			= L["options.event.pvp.victory.tooltip"],
			default			= false,
			parentInit		= initializerBattleground,
			parentCondition	= function() return GetVal(settingBattleground) end,
			shownPredicate	= isPvPExpanded
		})

		-- Brawl
		local initializerBrawl, settingBrawl = AWL.Settings:AddCheckboxSliderCombo(category, layout, {
			variableTable			= MEM.Settings.event,
			checkboxSettingKey		= addonName .. "_pvp-brawl-active",
			checkboxVariableName	= "pvp-brawl-active",
			checkboxName			= L["options.event.pvp.brawl"],
			checkboxTooltip			= L["options.event.general.active.tooltip"]:format(L["options.event.pvp.brawl"]),
			checkboxDefault			= true,

			sliderSettingKey		= addonName .. "_pvp-brawl-delay",
			sliderVariableName		= "pvp-brawl-delay",
			sliderName				= L["options.event.general.delay.name"],
			sliderTooltip			= L["options.event.general.delay.tooltip"]:format(L["options.event.pvp.brawl"], 3),
			sliderDefault			= 3, sliderMin = 1, sliderMax = 10, sliderStep = 1,
			sliderFormatter			= FormatSeconds,

			shownPredicate			= isPvPExpanded
		})

		-- Brawl: Only Victory
		AWL.Settings:AddCheckbox(category, {
			variableTable	= MEM.Settings.event,
			settingKey		= addonName .. "_pvp-brawl-victory-only",
			variableName	= "pvp-brawl-victory-only",
			name			= L["options.event.pvp.victory.name"],
			tooltip			= L["options.event.pvp.victory.tooltip"],
			default			= false,
			parentInit		= initializerBrawl,
			parentCondition	= function() return GetVal(settingBrawl) end,
			shownPredicate	= isPvPExpanded
		})
	end

	local _, isWarbandCollectionExpanded = AWL.Settings:AddExpandableHeader(layout, L["options.event.warband-collection"])

	local function AddWarbandEntry(key, nameString, condition)
		if condition then
			AWL.Settings:AddCheckboxSliderCombo(category, layout, {
				variableTable			= MEM.Settings.event,
				checkboxSettingKey		= addonName .. "_collection-" .. key .. "-active",
				checkboxVariableName	= "collection-" .. key .. "-active",
				checkboxName			= nameString,
				checkboxTooltip			= L["options.event.general.active.tooltip"]:format(nameString),
				checkboxDefault			= false,

				sliderSettingKey		= addonName .. "_collection-" .. key .. "-delay",
				sliderVariableName		= "collection-" .. key .. "-delay",
				sliderName				= L["options.event.general.delay.name"],
				sliderTooltip			= L["options.event.general.delay.tooltip"]:format(nameString, 1),
				sliderDefault			= 1, sliderMin = 1, sliderMax = 10, sliderStep = 1,
				sliderFormatter			= FormatSeconds,

				shownPredicate			= isWarbandCollectionExpanded
			})
		end
	end

	AddWarbandEntry("pet", L["options.event.warband-collection.new-pet"], AWL.GAME_TYPE_MAINLINE or AWL.GAME_TYPE_MISTS)
	AddWarbandEntry("mount", L["options.event.warband-collection.new-mount"], AWL.GAME_TYPE_MAINLINE or AWL.GAME_TYPE_MISTS)
	AddWarbandEntry("toy", L["options.event.warband-collection.new-toy"], AWL.GAME_TYPE_MAINLINE or AWL.GAME_TYPE_MISTS)
	AddWarbandEntry("recipe", L["options.event.warband-collection.new-recipe"], true)
	AddWarbandEntry("housing", L["options.event.warband-collection.new-housing-item"], AWL.GAME_TYPE_MAINLINE)

	local _, isOtherExpanded = AWL.Settings:AddExpandableHeader(layout, L["options.event.other"])

	-- Login
	AWL.Settings:AddCheckboxSliderCombo(category, layout, {
		variableTable			= MEM.Settings.event,
		checkboxSettingKey		= addonName .. "_login-active",
		checkboxVariableName	= "login-active",
		checkboxName			= L["options.event.other.login"],
		checkboxTooltip			= L["options.event.general.active.tooltip"]:format(L["options.event.other.login"]),
		checkboxDefault			= false,

		sliderSettingKey		= addonName .. "_login-delay",
		sliderVariableName		= "login-delay",
		sliderName				= L["options.event.general.delay.name"],
		sliderTooltip			= L["options.event.general.delay.tooltip"]:format(L["options.event.other.login"], 5),
		sliderDefault			= 5, sliderMin = 1, sliderMax = 10, sliderStep = 1,
		sliderFormatter			= FormatSeconds,

		shownPredicate			= isOtherExpanded
	})

	-- Level-Up
	local initializerLevelUp, settingLevelUp = AWL.Settings:AddCheckboxSliderCombo(category, layout, {
		variableTable			= MEM.Settings.event,
		checkboxSettingKey		= addonName .. "_level-up-active",
		checkboxVariableName	= "level-up-active",
		checkboxName			= L["options.event.other.level-up"],
		checkboxTooltip			= L["options.event.general.active.tooltip"]:format(L["options.event.other.level-up"]),
		checkboxDefault			= true,

		sliderSettingKey		= addonName .. "_level-up-delay",
		sliderVariableName		= "level-up-delay",
		sliderName				= L["options.event.general.delay.name"],
		sliderTooltip			= L["options.event.general.delay.tooltip"]:format(L["options.event.other.level-up"], 5),
		sliderDefault			= 5, sliderMin = 1, sliderMax = 10, sliderStep = 1,
		sliderFormatter			= FormatSeconds,

		shownPredicate			= isOtherExpanded
	})

	-- Level-Up: Show Time Played
	AWL.Settings:AddCheckbox(category, {
		variableTable	= MEM.Settings.event,
		settingKey		= addonName .. "_level-up-time-played",
		variableName	= "level-up-time-played",
		name			= L["options.event.other.level-up.time-played.name"],
		tooltip			= L["options.event.other.level-up.time-played.tooltip"],
		default			= false,
		parentInit		= initializerLevelUp,
		parentCondition	= function() return GetVal(settingLevelUp) end,
		onClick			= TimePlayedOptionChanged,
		shownPredicate	= isOtherExpanded
	})

	-- Death
	local initializerDeath, settingDeath = AWL.Settings:AddCheckboxSliderCombo(category, layout, {
		variableTable			= MEM.Settings.event,
		checkboxSettingKey		= addonName .. "_death-active",
		checkboxVariableName	= "death-active",
		checkboxName			= L["options.event.other.death"],
		checkboxTooltip			= L["options.event.general.active.tooltip"]:format(L["options.event.other.death"]),
		checkboxDefault			= true,

		sliderSettingKey		= addonName .. "_death-delay",
		sliderVariableName		= "death-delay",
		sliderName				= L["options.event.general.delay.name"],
		sliderTooltip			= L["options.event.general.delay.tooltip"]:format(L["options.event.other.death"], 1),
		sliderDefault			= 1, sliderMin = 1, sliderMax = 10, sliderStep = 1,
		sliderFormatter			= FormatSeconds,

		shownPredicate			= isOtherExpanded
	})

	-- Death: Instance
	AWL.Settings:AddDropdown(category, {
		variableTable	= MEM.Settings.event,
		settingKey		= addonName .. "_death-instance",
		variableName	= "death-instance",
		name			= L["options.event.other.death.instance.name"],
		tooltip			= L["options.event.other.death.instance.tooltip"],
		default			= 0,
		options			= {
			{value = 0, label = L["options.event.other.death.instance.option.0"]},
			{value = 1, label = L["options.event.other.death.instance.option.1"]},
			{value = 2, label = L["options.event.other.death.instance.option.2"]}
		},
		parentInit		= initializerDeath,
		parentCondition	= function() return GetVal(settingDeath) end,
		shownPredicate	= isOtherExpanded
	})

	-- Mythic+
	if AWL.GAME_TYPE_MAINLINE then
		AWL.Settings:AddCheckboxSliderCombo(category, layout, {
			variableTable			= MEM.Settings.event,
			checkboxSettingKey		= addonName .. "_mythic-active",
			checkboxVariableName	= "mythic-active",
			checkboxName			= L["options.event.other.mythic"],
			checkboxTooltip			= L["options.event.general.active.tooltip"]:format(L["options.event.other.mythic"]),
			checkboxDefault			= false,

			sliderSettingKey		= addonName .. "_mythic-delay",
			sliderVariableName		= "mythic-delay",
			sliderName				= L["options.event.general.delay.name"],
			sliderTooltip			= L["options.event.general.delay.tooltip"]:format(L["options.event.other.mythic"], 1),
			sliderDefault			= 1, sliderMin = 1, sliderMax = 10, sliderStep = 1,
			sliderFormatter			= FormatSeconds,

			shownPredicate			= isOtherExpanded
		})
	end

	-- Special Loot
	if AWL.GAME_TYPE_MAINLINE then
		local initializerLootToast, settingLootToast = AWL.Settings:AddCheckboxSliderCombo(category, layout, {
			variableTable			= MEM.Settings.event,
			checkboxSettingKey		= addonName .. "_loot-toast-active",
			checkboxVariableName	= "loot-toast-active",
			checkboxName			= L["options.event.other.loot-toast"],
			checkboxTooltip			= L["options.event.other.loot-toast.tooltip"],
			checkboxDefault			= false,

			sliderSettingKey		= addonName .. "_loot-toast-delay",
			sliderVariableName		= "loot-toast-delay",
			sliderName				= L["options.event.general.delay.name"],
			sliderTooltip			= L["options.event.general.delay.tooltip"]:format(L["options.event.other.loot-toast"], 1),
			sliderDefault			= 1, sliderMin = 1, sliderMax = 10, sliderStep = 1,
			sliderFormatter			= FormatSeconds,

			shownPredicate			= isOtherExpanded
		})

		local function IsLootToastEnabled()
			return GetVal(settingLootToast)
		end

		AWL.Settings:AddCheckbox(category, {
			variableTable	= MEM.Settings.event,
			settingKey		= addonName .. "_loot-toast-item",
			variableName	= "loot-toast-item",
			name			= L["options.event.other.loot-toast.item.name"],
			tooltip			= L["options.event.other.loot-toast.item.tooltip"],
			default			= true,
			parentInit		= initializerLootToast,
			parentCondition	= IsLootToastEnabled,
			shownPredicate	= isOtherExpanded
		})

		local lootToastQualityOptions = {}

		for _, quality in ipairs(MEM.LOOT_TOAST_QUALITIES) do
			lootToastQualityOptions[#lootToastQualityOptions + 1] = {
				value = quality,
				label = _G["ITEM_QUALITY" .. quality .. "_DESC"]
			}
		end

		AWL.Settings:AddDropdown(category, {
			variableTable	= MEM.Settings.event,
			settingKey		= addonName .. "_loot-toast-quality",
			variableName	= "loot-toast-quality",
			name			= L["options.event.other.loot-toast.quality.name"],
			tooltip			= L["options.event.other.loot-toast.quality.tooltip"],
			default			= MEM.LOOT_TOAST_QUALITY_DEFAULT,
			options			= lootToastQualityOptions,
			parentInit		= initializerLootToast,
			parentCondition	= IsLootToastEnabled,
			shownPredicate	= isOtherExpanded
		})

		AWL.Settings:AddCheckbox(category, {
			variableTable	= MEM.Settings.event,
			settingKey		= addonName .. "_loot-toast-money",
			variableName	= "loot-toast-money",
			name			= L["options.event.other.loot-toast.money.name"],
			tooltip			= L["options.event.other.loot-toast.money.tooltip"],
			default			= false,
			parentInit		= initializerLootToast,
			parentCondition	= IsLootToastEnabled,
			shownPredicate	= isOtherExpanded
		})

		AWL.Settings:AddCheckbox(category, {
			variableTable	= MEM.Settings.event,
			settingKey		= addonName .. "_loot-toast-currency",
			variableName	= "loot-toast-currency",
			name			= L["options.event.other.loot-toast.currency.name"],
			tooltip			= L["options.event.other.loot-toast.currency.tooltip"],
			default			= false,
			parentInit		= initializerLootToast,
			parentCondition	= IsLootToastEnabled,
			shownPredicate	= isOtherExpanded
		})
	end

	-- Interval
	AWL.Settings:AddCheckboxSliderCombo(category, layout, {
		variableTable			= MEM.Settings.event,
		checkboxSettingKey		= addonName .. "_interval-active",
		checkboxVariableName	= "interval-active",
		checkboxName			= L["options.event.other.interval"],
		checkboxTooltip			= L["options.event.general.active.tooltip"]:format(L["options.event.other.interval"]),
		checkboxDefault			= false,

		sliderSettingKey		= addonName .. "_interval-timer",
		sliderVariableName		= "interval-timer",
		sliderName				= L["options.event.other.interval-timer.name"],
		sliderTooltip			= L["options.event.other.interval-timer.tooltip"],
		sliderDefault			= 5, sliderMin = 1, sliderMax = 60, sliderStep = 1,
		sliderFormatter			= FormatMinutes,

		shownPredicate			= isOtherExpanded
	})

	-- Profiles Section
	AWL.Settings:AddProfilesSection(layout, {
		useAccountProfile			= Utils:IsAccountProfile(),
		onSwitchProfile				= function()
			Utils:ToggleProfileMode()
			ReloadUI()
		end,
		onDeleteCharacterProfiles	= function()
			Utils:ResetAllCharacterProfiles()
			ReloadUI()
		end
	})

	-- About Section
	AWL.Settings:AddAboutSection(layout, addonName, MEM.CHANGELOG)

	Settings.RegisterAddOnCategory(category)

	Addon:SetMainCategoryId(category:GetID())
end
