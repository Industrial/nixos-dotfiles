local addonName, MEM = ...

-- Library
local AWL = ArcaneWizardLibrary

-- Module imports
local Capture = MEM.Modules.Capture
local Options = MEM.Modules.Options
local Utils = MEM.Modules.Utils

-- Variables
local minutesPassed = 0
local sessionStartTime = 0

--------------
--- Frames ---
--------------

local MementoFrame = CreateFrame("Frame", "Memento")

-----------------------
--- Local Functions ---
-----------------------

local function TimePlayed()
	local currentTime = GetTime()
	local timeLastCheck = currentTime - sessionStartTime

	MEM.State.totalTimePlayed = MEM.State.totalTimePlayed + timeLastCheck
	MEM.State.timePlayedThisLevel = MEM.State.timePlayedThisLevel + timeLastCheck

	sessionStartTime = currentTime
end

local function ScheduleScreenshot(handler, delay, ...)
	TimePlayed()
	Capture:ScheduleTimer(handler, delay, ...)
end

local function ProcessLootToast(itemLink, minimumQuality, delay, retriesRemaining)
	local itemQuality = C_Item.GetItemQualityByID(itemLink)

	if itemQuality == nil then
		if retriesRemaining > 0 then
			C_Item.RequestLoadItemDataByID(itemLink)

			C_Timer.After(MEM.LOOT_TOAST_ITEM_LOAD_RETRY_DELAY, function()
				ProcessLootToast(itemLink, minimumQuality, delay, retriesRemaining - 1)
			end)
		else
			Utils:PrintDebug(string.format(
				"Item quality for '%s' could not be loaded. No screenshot requested.",
				tostring(itemLink)
			))
		end

		return
	end

	if itemQuality < minimumQuality then
		Utils:PrintDebug(string.format(
			"Item quality %s is below the configured minimum quality %s. No screenshot requested.",
			tostring(itemQuality), tostring(minimumQuality)
		))

		return
	end

	ScheduleScreenshot("LootToastEventHandler", delay + MEM.CAPTURE_DELAY_OFFSET, MEM.LOOT_TOAST_TYPE.ITEM, itemLink, nil)
end

local function CheckInterval()
	Utils:PrintDebug("Timer triggered.")

	minutesPassed = minutesPassed + 1

	if MEM.Settings.event["interval-active"] and minutesPassed >= MEM.Settings.event["interval-timer"] then
		ScheduleScreenshot("IntervalEventHandler", MEM.CAPTURE_DELAY_OFFSET)

		minutesPassed = 0
	end
end

local function IsPlayerWinner(winner)
	local playerFaction = UnitFactionGroup("player")

	return (playerFaction == "Alliance" and winner == 1) or (playerFaction == "Horde" and winner == 0)
end

local function SlashCommand(msg)
	local command = strtrim(msg or "")

	if command == "" then
		Utils:OpenSettings()
	elseif command == "changelog" then
		AWL.Frames:OpenChangelog(addonName, MEM.CHANGELOG)
	else
		Utils:PrintDebug("These arguments are not accepted.")
	end
end

------------------------
--- Public Functions ---
------------------------

function MementoFrame:OnEvent(event, ...)
	self[event](self, event, ...)
end

function MementoFrame:ADDON_LOADED(_, addOnName)
	if addOnName == addonName then
		sessionStartTime = GetTime()

		local dbInit = Utils:InitializeDatabase()
		Utils:InitializeMinimapButton()
		Options:Initialize()

		Utils:RequestTimePlayed()
		Utils:OpenSettingsOnLoading()

		C_Timer.NewTicker(60, CheckInterval)

		Utils:PrintDebug(string.format(
			"InitializeDatabase: key=%s, createdProfile=%s, createdProfileKey=%s, activeProfile=%s",
			tostring(dbInit.characterRealmKey), tostring(dbInit.createdProfile), tostring(dbInit.createdProfileKey), tostring(dbInit.activeProfile)
		))
		Utils:PrintDebug("Addon fully loaded.")
	end
end

function MementoFrame:TIME_PLAYED_MSG(_, totalTimePlayed, timePlayedThisLevel)
	Utils:PrintDebug(string.format(
		"Event 'TIME_PLAYED_MSG' fired. Payload: totalTimePlayed=%s, timePlayedThisLevel=%s",
		tostring(totalTimePlayed), tostring(timePlayedThisLevel)
	))

	MEM.State.totalTimePlayed = totalTimePlayed
	MEM.State.timePlayedThisLevel = timePlayedThisLevel
	MEM.State.timePlayedInitialized = true

	sessionStartTime = GetTime()

	Utils:PrintDebug("Event 'TIME_PLAYED_MSG' completed.")
end

function MementoFrame:SHOW_LOOT_TOAST(_, typeIdentifier, itemLink, quantity, specID, sex, personalLootToast, toastMethod, lessAwesome, upgraded, corrupted)
	Utils:PrintDebug(string.format(
		"Event 'SHOW_LOOT_TOAST' fired. Payload: typeIdentifier=%s, itemLink=%s, quantity=%s, specID=%s, sex=%s, personalLootToast=%s, toastMethod=%s, lessAwesome=%s, upgraded=%s, corrupted=%s",
		tostring(typeIdentifier), tostring(itemLink), tostring(quantity), tostring(specID), tostring(sex), tostring(personalLootToast),
		tostring(toastMethod), tostring(lessAwesome), tostring(upgraded), tostring(corrupted)
	))

	if not MEM.Settings.event["loot-toast-active"] then
		Utils:PrintDebug("Event 'SHOW_LOOT_TOAST' completed. No screenshot requested.")
		return
	end

	local settingKey = MEM.LOOT_TOAST_SETTING_BY_TYPE[typeIdentifier]

	if not settingKey then
		Utils:PrintDebug(string.format(
			"Event 'SHOW_LOOT_TOAST' has unsupported typeIdentifier '%s'. No screenshot requested.",
			tostring(typeIdentifier)
		))

		return
	end

	if not MEM.Settings.event[settingKey] then
		Utils:PrintDebug(string.format(
			"Event 'SHOW_LOOT_TOAST' type '%s' is disabled. No screenshot requested.",
			tostring(typeIdentifier)
		))

		return
	end

	local delay = MEM.Settings.event["loot-toast-delay"] or 1

	if typeIdentifier == MEM.LOOT_TOAST_TYPE.ITEM then
		if not itemLink then
			Utils:PrintDebug("Event 'SHOW_LOOT_TOAST' did not contain an item link. No screenshot requested.")
			return
		end

		local minimumQuality = MEM.Settings.event["loot-toast-quality"] or MEM.LOOT_TOAST_QUALITY_DEFAULT

		ProcessLootToast(itemLink, minimumQuality, delay, MEM.LOOT_TOAST_ITEM_LOAD_RETRY_COUNT)
	else
		ScheduleScreenshot("LootToastEventHandler", delay + MEM.CAPTURE_DELAY_OFFSET, typeIdentifier, itemLink, quantity)
	end
end

function MementoFrame:ACHIEVEMENT_EARNED(_, achievementID, alreadyEarned)
	Utils:PrintDebug(string.format(
		"Event 'ACHIEVEMENT_EARNED' fired. Payload: achievementID=%s, alreadyEarned=%s",
		tostring(achievementID), tostring(alreadyEarned)
	))

	local isGuildAchievement = select(12, GetAchievementInfo(achievementID))

	if not isGuildAchievement then
		if MEM.Settings.event["achievement-personal-active"] then
			ScheduleScreenshot("AchievementPersonalEventHandler", MEM.Settings.event["achievement-personal-delay"] + MEM.CAPTURE_DELAY_OFFSET, achievementID, alreadyEarned)
		else
			Utils:PrintDebug("Event 'ACHIEVEMENT_EARNED' (Personal) completed. No screenshot requested.")
		end
	else
		if MEM.Settings.event["achievement-guild-active"] then
			ScheduleScreenshot("AchievementGuildEventHandler", MEM.Settings.event["achievement-guild-delay"] + MEM.CAPTURE_DELAY_OFFSET, achievementID)
		else
			Utils:PrintDebug("Event 'ACHIEVEMENT_EARNED' (Guild) completed. No screenshot requested.")
		end
	end
end

function MementoFrame:CRITERIA_EARNED(_, achievementID, description)
	Utils:PrintDebug(string.format(
		"Event 'CRITERIA_EARNED' fired. Payload: achievementID=%s, description=%s",
		tostring(achievementID), tostring(description)
	))

	if MEM.Settings.event["achievement-criteria-active"] then
		ScheduleScreenshot("CriteriaEventHandler", MEM.Settings.event["achievement-criteria-delay"] + MEM.CAPTURE_DELAY_OFFSET, achievementID, description)
	else
		Utils:PrintDebug("Event 'CRITERIA_EARNED' completed. No screenshot requested.")
	end
end

function MementoFrame:CHALLENGE_MODE_COMPLETED(_)
	Utils:PrintDebug("Event 'CHALLENGE_MODE_COMPLETED' fired. No payload.")

	if MEM.Settings.event["mythic-active"] then
		ScheduleScreenshot("MythicEventHandler", MEM.Settings.event["mythic-delay"] + MEM.CAPTURE_DELAY_OFFSET)
	else
		Utils:PrintDebug("Event 'CHALLENGE_MODE_COMPLETED' completed. No screenshot requested.")
	end
end

function MementoFrame:PVP_MATCH_COMPLETE(_, winner, duration)
	Utils:PrintDebug(string.format(
		"Event 'PVP_MATCH_COMPLETE' fired. Payload: winner=%s, duration=%s",
		tostring(winner), tostring(duration)
	))

	local isArena = C_PvP.IsArena()
	local isBattleground = C_PvP.IsBattleground()
	local isSoloRBG = C_PvP.IsSoloRBG()
	local isInBrawl = C_PvP.IsInBrawl()

	if isArena then
		if MEM.Settings.event["pvp-arena-active"] then
			ScheduleScreenshot("PvPArenaEventHandler", MEM.Settings.event["pvp-arena-delay"] + MEM.CAPTURE_DELAY_OFFSET)
		else
			Utils:PrintDebug("Event 'PVP_MATCH_COMPLETE' (Arena) completed. No screenshot requested.")
		end
	elseif isInBrawl then
		if MEM.Settings.event["pvp-brawl-active"] then
			if MEM.Settings.event["pvp-brawl-victory-only"] then
				if IsPlayerWinner(winner) then
					ScheduleScreenshot("PvPBrawlEventHandler", MEM.Settings.event["pvp-brawl-delay"] + MEM.CAPTURE_DELAY_OFFSET)
				else
					Utils:PrintDebug("Player faction has lost the brawl. No screenshot requested.")
				end
			else
				ScheduleScreenshot("PvPBrawlEventHandler", MEM.Settings.event["pvp-brawl-delay"] + MEM.CAPTURE_DELAY_OFFSET)
			end
		else
			Utils:PrintDebug("Event 'PVP_MATCH_COMPLETE' (Brawl) completed. No screenshot requested.")
		end
	elseif isBattleground or isSoloRBG then
		if MEM.Settings.event["pvp-battleground-active"] then
			if MEM.Settings.event["pvp-battleground-victory-only"] then
				if IsPlayerWinner(winner) then
					ScheduleScreenshot("PvPBattlegroundEventHandler", MEM.Settings.event["pvp-battleground-delay"] + MEM.CAPTURE_DELAY_OFFSET)
				else
					Utils:PrintDebug("Player faction has lost the battleground. No screenshot requested.")
				end
			else
				ScheduleScreenshot("PvPBattlegroundEventHandler", MEM.Settings.event["pvp-battleground-delay"] + MEM.CAPTURE_DELAY_OFFSET)
			end
		else
			Utils:PrintDebug("Event 'PVP_MATCH_COMPLETE' (Battleground) completed. No screenshot requested.")
		end
	else
		Utils:PrintDebug("Unknown PvP Event. No screenshot requested.")
	end
end

function MementoFrame:NEW_PET_ADDED(_, battlePetGUID)
	Utils:PrintDebug(string.format(
		"Event 'NEW_PET_ADDED' fired. Payload: battlePetGUID=%s",
		tostring(battlePetGUID)
	))

	if MEM.Settings.event["collection-pet-active"] then
		ScheduleScreenshot("NewPetEventHandler", MEM.Settings.event["collection-pet-delay"] + MEM.CAPTURE_DELAY_OFFSET)
	else
		Utils:PrintDebug("Event 'NEW_PET_ADDED' completed. No screenshot requested.")
	end
end

function MementoFrame:NEW_MOUNT_ADDED(_, mountID)
	Utils:PrintDebug(string.format(
		"Event 'NEW_MOUNT_ADDED' fired. Payload: mountID=%s",
		tostring(mountID)
	))

	if MEM.Settings.event["collection-mount-active"] then
		ScheduleScreenshot("NewMountEventHandler", MEM.Settings.event["collection-mount-delay"] + MEM.CAPTURE_DELAY_OFFSET)
	else
		Utils:PrintDebug("Event 'NEW_MOUNT_ADDED' completed. No screenshot requested.")
	end
end

function MementoFrame:NEW_TOY_ADDED(_, itemID)
	Utils:PrintDebug(string.format(
		"Event 'NEW_TOY_ADDED' fired. Payload: itemID=%s",
		tostring(itemID)
	))

	if MEM.Settings.event["collection-toy-active"] then
		ScheduleScreenshot("NewToyEventHandler", MEM.Settings.event["collection-toy-delay"] + MEM.CAPTURE_DELAY_OFFSET)
	else
		Utils:PrintDebug("Event 'NEW_TOY_ADDED' completed. No screenshot requested.")
	end
end

function MementoFrame:NEW_HOUSING_ITEM_ACQUIRED(_, itemType, itemName, icon)
	Utils:PrintDebug(string.format(
		"Event 'NEW_HOUSING_ITEM_ACQUIRED' fired. Payload: itemType=%s, itemName=%s, icon=%s",
		tostring(itemType),	tostring(itemName),	tostring(icon)
	))

	if MEM.Settings.event["collection-housing-active"] then
		ScheduleScreenshot("NewHousingItemEventHandler", MEM.Settings.event["collection-housing-delay"] + MEM.CAPTURE_DELAY_OFFSET)
	else
		Utils:PrintDebug("Event 'NEW_HOUSING_ITEM_ACQUIRED' completed. No screenshot requested.")
	end
end

function MementoFrame:PLAYER_ENTERING_WORLD(_, isInitialLogin, isReloadingUi)
	Utils:PrintDebug(string.format(
		"Event 'PLAYER_ENTERING_WORLD' fired. Payload: isInitialLogin=%s, isReloadingUi=%s",
		tostring(isInitialLogin), tostring(isReloadingUi)
	))

	if MEM.Settings.event["login-active"] and isInitialLogin then
		ScheduleScreenshot("LoginEventHandler", MEM.Settings.event["login-delay"] + MEM.CAPTURE_DELAY_OFFSET)
	else
		Utils:PrintDebug("Event 'PLAYER_ENTERING_WORLD' completed. No screenshot requested.")
	end
end

function MementoFrame:PLAYER_DEAD(_)
	Utils:PrintDebug("Event 'PLAYER_DEAD' fired. No payload.")

	if MEM.Settings.event["death-active"] then
		local inInstance = IsInInstance()

		if MEM.Settings.event["death-instance"] == 0 then
			ScheduleScreenshot("DeathEventHandler", MEM.Settings.event["death-delay"] + MEM.CAPTURE_DELAY_OFFSET)
		elseif inInstance and MEM.Settings.event["death-instance"] == 1 then
			ScheduleScreenshot("DeathEventHandler", MEM.Settings.event["death-delay"] + MEM.CAPTURE_DELAY_OFFSET)
		elseif not inInstance and MEM.Settings.event["death-instance"] == 2 then
			ScheduleScreenshot("DeathEventHandler", MEM.Settings.event["death-delay"] + MEM.CAPTURE_DELAY_OFFSET)
		else
			Utils:PrintDebug("Player died in the wrong area. No screenshot requested.")
		end
	else
		Utils:PrintDebug("Event 'PLAYER_DEAD' completed. No screenshot requested.")
	end
end

function MementoFrame:PLAYER_LEVEL_UP(_, level)
	Utils:PrintDebug(string.format(
		"Event 'PLAYER_LEVEL_UP' fired. Payload: level=%s",
		tostring(level)
	))

	if MEM.Settings.event["level-up-active"] then
		TimePlayed()

		local timePlayedOnPreviousLevel = MEM.State.timePlayedThisLevel
		MEM.State.timePlayedThisLevel = 0

		Capture:ScheduleTimer("LevelUpEventHandler", MEM.Settings.event["level-up-delay"] + MEM.CAPTURE_DELAY_OFFSET, level, timePlayedOnPreviousLevel)
	else
		Utils:PrintDebug("Event 'PLAYER_LEVEL_UP' completed. No screenshot requested.")
	end
end

function MementoFrame:ENCOUNTER_END(_, encounterID, encounterName, difficultyID, groupSize, success)
	Utils:PrintDebug(string.format(
		"Event 'ENCOUNTER_END' fired. Payload: encounterID=%s, encounterName=%s, difficultyID=%s, groupSize=%s, success=%s",
		tostring(encounterID), tostring(encounterName),	tostring(difficultyID),	tostring(groupSize), tostring(success)
	))

	local difficultyName, groupType = GetDifficultyInfo(difficultyID)
	local difficulty = "D" .. tostring(difficultyID)

	if groupType == "party" or groupType == "raid" or groupType == "scenario" then
		if success == 1 then
			local isActive = (groupType == "party" and MEM.Settings.event["encounter-victory-party-active"]) or
								(groupType == "raid" and MEM.Settings.event["encounter-victory-raid-active"]) or
								(groupType == "scenario" and MEM.Settings.event["encounter-victory-scenario-active"])

			local delay = (groupType == "party" and MEM.Settings.event["encounter-victory-party-delay"]) or
							(groupType == "raid" and MEM.Settings.event["encounter-victory-raid-delay"]) or
							(groupType == "scenario" and MEM.Settings.event["encounter-victory-scenario-delay"])

			local firstOnly = (groupType == "party" and MEM.Settings.event["encounter-victory-party-first"]) or
								(groupType == "raid" and MEM.Settings.event["encounter-victory-raid-first"]) or
								(groupType == "scenario" and MEM.Settings.event["encounter-victory-scenario-first"])

			if isActive then
				if not MEM.Data.bossKill[difficulty] then MEM.Data.bossKill[difficulty] = {} end

				if MEM.Data.bossKill[difficulty][encounterID] and firstOnly then
					Utils:PrintDebug("Encounter already killed. No screenshot requested.")
				else
					ScheduleScreenshot("EncounterVictoryEventHandler", delay + MEM.CAPTURE_DELAY_OFFSET, encounterName, difficultyName, difficulty, encounterID)
				end
			else
				Utils:PrintDebug("Event 'ENCOUNTER_END' (Victory) completed. No screenshot requested.")
			end
		else
			local isActive = (groupType == "party" and MEM.Settings.event["encounter-wipe-party-active"]) or
								(groupType == "raid" and MEM.Settings.event["encounter-wipe-raid-active"]) or
								(groupType == "scenario" and MEM.Settings.event["encounter-wipe-scenario-active"])

			local delay = (groupType == "party" and MEM.Settings.event["encounter-wipe-party-delay"]) or
							(groupType == "raid" and MEM.Settings.event["encounter-wipe-raid-delay"]) or
							(groupType == "scenario" and MEM.Settings.event["encounter-wipe-scenario-delay"])

			if isActive then
				ScheduleScreenshot("EncounterWipeEventHandler", delay + MEM.CAPTURE_DELAY_OFFSET, encounterName, difficultyName)
			else
				Utils:PrintDebug("Event 'ENCOUNTER_END' (Wipe) completed. No screenshot requested.")
			end
		end
	else
		Utils:PrintDebug(string.format(
			"Unknown groupType '%s'. No screenshot requested.",
			tostring(groupType)
		))
	end
end

function MementoFrame:DUEL_FINISHED(_)
	Utils:PrintDebug("Event 'DUEL_FINISHED' fired. No payload.")

	if MEM.Settings.event["pvp-duel-active"] then
		ScheduleScreenshot("PvPDuelEventHandler", MEM.Settings.event["pvp-duel-delay"] + MEM.CAPTURE_DELAY_OFFSET)
	else
		Utils:PrintDebug("Event 'DUEL_FINISHED' completed. No screenshot requested.")
	end
end

function MementoFrame:NEW_RECIPE_LEARNED(_, recipeID, recipeLevel, baseRecipeID)
	Utils:PrintDebug(string.format(
		"Event 'NEW_RECIPE_LEARNED' fired. Payload: recipeID=%s, recipeLevel=%s, baseRecipeID=%s",
		tostring(recipeID),	tostring(recipeLevel), tostring(baseRecipeID)
	))

	if MEM.Settings.event["collection-recipe-active"] then
		ScheduleScreenshot("NewRecipeEventHandler", MEM.Settings.event["collection-recipe-delay"] + MEM.CAPTURE_DELAY_OFFSET)
	else
		Utils:PrintDebug("Event 'NEW_RECIPE_LEARNED' completed. No screenshot requested.")
	end
end

--------------------------
--- Event Registration ---
--------------------------

MementoFrame:RegisterEvent("ADDON_LOADED")
MementoFrame:RegisterEvent("TIME_PLAYED_MSG")

if AWL.GAME_TYPE_VANILLA then
elseif AWL.GAME_TYPE_TBC then
elseif AWL.GAME_TYPE_MISTS then
	MementoFrame:RegisterEvent("ACHIEVEMENT_EARNED")
	MementoFrame:RegisterEvent("NEW_PET_ADDED")
	MementoFrame:RegisterEvent("NEW_MOUNT_ADDED")
	MementoFrame:RegisterEvent("NEW_TOY_ADDED")
elseif AWL.GAME_TYPE_MAINLINE then
	MementoFrame:RegisterEvent("ACHIEVEMENT_EARNED")
	MementoFrame:RegisterEvent("CRITERIA_EARNED")
	MementoFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
	MementoFrame:RegisterEvent("PVP_MATCH_COMPLETE")
	MementoFrame:RegisterEvent("ENCOUNTER_END")
	MementoFrame:RegisterEvent("NEW_PET_ADDED")
	MementoFrame:RegisterEvent("NEW_MOUNT_ADDED")
	MementoFrame:RegisterEvent("NEW_TOY_ADDED")
	MementoFrame:RegisterEvent("NEW_HOUSING_ITEM_ACQUIRED")
	MementoFrame:RegisterEvent("SHOW_LOOT_TOAST")
end

MementoFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
MementoFrame:RegisterEvent("PLAYER_DEAD")
MementoFrame:RegisterEvent("PLAYER_LEVEL_UP")
MementoFrame:RegisterEvent("DUEL_FINISHED")
MementoFrame:RegisterEvent("NEW_RECIPE_LEARNED")

MementoFrame:SetScript("OnEvent", MementoFrame.OnEvent)

SLASH_Memento1, SLASH_Memento2 = '/mem', '/memento'
SlashCmdList["Memento"] = SlashCommand
