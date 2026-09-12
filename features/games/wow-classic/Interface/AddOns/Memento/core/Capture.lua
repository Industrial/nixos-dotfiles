local _, MEM = ...

-- Library
local AWL = ArcaneWizardLibrary

-- Localization
local L = MEM.Localization

-- Current module
local Capture = MEM.Modules.Capture

-- Module imports
local Utils = MEM.Modules.Utils

--------------
--- Frames ---
--------------

local MessageFrame

-----------------------
--- Local Functions ---
-----------------------

local function CreateMessageFrame()
	local frame = CreateFrame("Frame")
	frame:ClearAllPoints()
	frame:SetPoint("BOTTOM", 0, 100)
	frame:SetSize(164, 41)

	frame.background = frame:CreateTexture(nil, "BACKGROUND")
	frame.background:ClearAllPoints()
	frame.background:SetAllPoints(frame)
	frame.background:SetTexture(612384)

	frame.textTop = frame:CreateFontString(nil, "OVERLAY", "GameFontBlackTiny")
	frame.textTop:ClearAllPoints()
	frame.textTop:SetPoint("CENTER", 0, 5)
	frame.textTop:SetFont(tostring(frame.textTop:GetFont()), 7)
	frame.textTop:SetText(L["capture.message"])

	frame.textBottom = frame:CreateFontString(nil, "OVERLAY", "GameFontWhiteTiny")
	frame.textBottom:ClearAllPoints()
	frame.textBottom:SetPoint("CENTER", 0, -6)
	frame.textBottom:SetFont(tostring(frame.textBottom:GetFont()), 7)
	frame.textBottom:SetText(tostring(date("%d.%m.%y - %H:%M:%S", GetServerTime())))

	return frame
end

local function UpdateMessageFrame()
	if not MessageFrame then
		MessageFrame = CreateMessageFrame()
	end

	MessageFrame.textBottom:SetText(tostring(date("%d.%m.%y - %H:%M:%S", GetServerTime())))

	return MessageFrame
end

local function GetSoundKitID(sound)
	return SOUNDKIT and SOUNDKIT[sound] or nil
end

local function PlayScreenshotSound(ignoreSetting, soundKey)
	if not ignoreSetting and not MEM.Settings.general["screenshot-sound"] then return end

	soundKey = soundKey or MEM.Settings.general["screenshot-sound-style"] or MEM.SCREENSHOT_SOUND_DEFAULT
	local soundData = MEM.SCREENSHOT_SOUND_BY_KEY[soundKey]

	if not soundData then return end

	if soundData.filePath then
		local status, willPlay = pcall(PlaySoundFile, soundData.filePath, MEM.SCREENSHOT_SOUND_CHANNEL)

		if status and willPlay ~= false then
			return
		end
	end

	local soundKitNames = soundData.soundKitNames

	if not soundKitNames then return end

	for _, soundKitName in ipairs(soundKitNames) do
		local soundKitID = GetSoundKitID(soundKitName)

		if soundKitID then
			local status, willPlay = pcall(PlaySound, soundKitID, MEM.SCREENSHOT_SOUND_CHANNEL)

			if status and willPlay then
				return
			end
		end
	end
end

local function TakeScreenshot()
	if MEM.Settings.general["hide-ui"] then
		if not InCombatLockdown() then
			local frame

			local status, err = pcall(function ()
				UIParent:Hide()

				frame = UpdateMessageFrame()
				frame:Show()

				C_Timer.After(0.1, function()
					Screenshot()
					PlayScreenshotSound()
					Utils:PrintDebug("Screenshot without UI taken.")
				end)

				C_Timer.After(0.2, function()
					UIParent:Show()

					if frame then
						frame:Hide()
					end
				end)

			end)

			if not status then
				UIParent:Show()

				if frame then
					frame:Hide()
				end

				Utils:PrintDebug(string.format(
					"Method TakeScreenshot() (without UI) aborted with exception: %s",
					tostring(err)
				))

				Screenshot()
				PlayScreenshotSound()

				Utils:PrintDebug("Screenshot taken.")
			end
		else
			Utils:PrintDebug("No screenshot is possible in combat without ui.")

			Screenshot()
			PlayScreenshotSound()

			Utils:PrintDebug("Screenshot taken.")
		end
	else
		Screenshot()
		PlayScreenshotSound()

		Utils:PrintDebug("Screenshot taken.")
	end
end

local function AchievementPersonalEventHandler(achievementID, alreadyEarned)
	local achievementLink = GetAchievementLink(achievementID)

	if achievementLink then
		if not alreadyEarned then
			Utils:PrintMessage(L["chat.event.achievement.personal.new"]:format(achievementLink))
			TakeScreenshot()
		elseif MEM.Settings.event["achievement-personal-exist"] then
			Utils:PrintMessage(L["chat.event.achievement.personal.exist"]:format(achievementLink))
			TakeScreenshot()
		else
			Utils:PrintDebug(string.format(
				"The achievement %s has already been reached by another character. No screenshot requested.",
				tostring(achievementLink)
			))
		end
	else
		Utils:PrintDebug("Unknown AchievementLink. (nil value / unknown ID)")

		if not alreadyEarned then
			Utils:PrintMessage(L["chat.event.achievement.personal.no-link.new"])
			TakeScreenshot()
		elseif MEM.Settings.event["achievement-personal-exist"] then
			Utils:PrintMessage(L["chat.event.achievement.personal.no-link.exist"])
			TakeScreenshot()
		else
			Utils:PrintDebug("The achievement has already been reached by another character. No screenshot requested.")
		end
	end
end

local function AchievementGuildEventHandler(achievementID)
	local name = select(2, GetAchievementInfo(achievementID))

	Utils:PrintMessage(L["chat.event.achievement.guild.new"]:format(name))
	TakeScreenshot()
end

local function CriteriaEventHandler(achievementID, description)
	local achievementLink = GetAchievementLink(achievementID)

	if achievementLink then
		Utils:PrintMessage(L["chat.event.achievement.criteria.new"]:format(achievementLink, description))
	else
		Utils:PrintDebug("Unknown AchievementLink. (nil value / unknown ID)")
		Utils:PrintMessage(L["chat.event.achievement.criteria.no-link.new"])
	end

	TakeScreenshot()
end

local function EncounterVictoryEventHandler(encounterName, difficultyName, difficulty, encounterID)
	Utils:PrintMessage(L["chat.event.encounter.victory.new"]:format(encounterName, difficultyName))
	TakeScreenshot()

	if not MEM.Data.bossKill[difficulty] then MEM.Data.bossKill[difficulty] = {} end

	MEM.Data.bossKill[difficulty][encounterID] = true
end

local function EncounterWipeEventHandler(encounterName, difficultyName)
	Utils:PrintMessage(L["chat.event.encounter.wipe.new"]:format(encounterName, difficultyName))
	TakeScreenshot()
end

local function PvPDuelEventHandler()
	Utils:PrintMessage(L["chat.event.pvp.duel.new"])
	TakeScreenshot()
end

local function PvPArenaEventHandler()
	Utils:PrintMessage(L["chat.event.pvp.arena.new"])
	TakeScreenshot()
end

local function PvPBattlegroundEventHandler()
	Utils:PrintMessage(L["chat.event.pvp.battleground.new"])
	TakeScreenshot()
end

local function PvPBrawlEventHandler()
	Utils:PrintMessage(L["chat.event.pvp.brawl.new"])
	TakeScreenshot()
end

local function NewPetEventHandler()
	Utils:PrintMessage(L["chat.event.warband-collection.new-pet.new"])
	TakeScreenshot()
end

local function NewMountEventHandler()
	Utils:PrintMessage(L["chat.event.warband-collection.new-mount.new"])
	TakeScreenshot()
end

local function NewToyEventHandler()
	Utils:PrintMessage(L["chat.event.warband-collection.new-toy.new"])
	TakeScreenshot()
end

local function NewRecipeEventHandler()
	Utils:PrintMessage(L["chat.event.warband-collection.new-recipe.new"])
	TakeScreenshot()
end

local function NewHousingItemEventHandler()
	Utils:PrintMessage(L["chat.event.warband-collection.new-housing-item.new"])
	TakeScreenshot()
end

local function LoginEventHandler()
	Utils:PrintMessage(L["chat.event.login.new"])
	TakeScreenshot()
end

local function LevelUpEventHandler(level, timePlayedOnPreviousLevel)
	local message

	if AWL.GAME_TYPE_VANILLA or AWL.GAME_TYPE_TBC then
		message = L["chat.event.level-up.classic.new"]:format(tostring(level))
	elseif AWL.GAME_TYPE_MISTS or AWL.GAME_TYPE_MAINLINE then
		message = L["chat.event.level-up.retail.new"]:format(tostring(level))
	end

	if message and MEM.Settings.event["level-up-time-played"] and timePlayedOnPreviousLevel then
		local days, hours, minutes, seconds = Utils:GetDurationParts(timePlayedOnPreviousLevel)
		message = message .. " - " .. L["chat.event.level-up.time-played"]:format(level - 1, days, hours, minutes, seconds)
	end

	if message then
		Utils:PrintMessage(message)
	end

	TakeScreenshot()
end

local function DeathEventHandler()
	Utils:PrintMessage(L["chat.event.death.new"])
	TakeScreenshot()
end

local function MythicEventHandler()
	Utils:PrintMessage(L["chat.event.mythic.new"])
	TakeScreenshot()
end

local function LootToastEventHandler(typeIdentifier, itemLink, quantity)
	if typeIdentifier == MEM.LOOT_TOAST_TYPE.ITEM then
		Utils:PrintMessage(L["chat.event.loot-toast.item.new"]:format(itemLink or UNKNOWN))
	elseif typeIdentifier == MEM.LOOT_TOAST_TYPE.MONEY then
		Utils:PrintMessage(L["chat.event.loot-toast.money.new"]:format(GetMoneyString(quantity or 0, true)))
	elseif typeIdentifier == MEM.LOOT_TOAST_TYPE.CURRENCY then
		Utils:PrintMessage(L["chat.event.loot-toast.currency.new"]:format(itemLink or UNKNOWN, quantity or 0))
	end

	TakeScreenshot()
end

local function IntervalEventHandler()
	Utils:PrintMessage(L["chat.event.interval.new"])
	TakeScreenshot()
end

local HandlerTable = {
	["AchievementPersonalEventHandler"] = AchievementPersonalEventHandler,
	["AchievementGuildEventHandler"]    = AchievementGuildEventHandler,
	["CriteriaEventHandler"]            = CriteriaEventHandler,
	["EncounterVictoryEventHandler"]    = EncounterVictoryEventHandler,
	["EncounterWipeEventHandler"]       = EncounterWipeEventHandler,
	["PvPDuelEventHandler"]             = PvPDuelEventHandler,
	["PvPArenaEventHandler"]            = PvPArenaEventHandler,
	["PvPBattlegroundEventHandler"]     = PvPBattlegroundEventHandler,
	["PvPBrawlEventHandler"]            = PvPBrawlEventHandler,
	["NewPetEventHandler"]              = NewPetEventHandler,
	["NewMountEventHandler"]            = NewMountEventHandler,
	["NewToyEventHandler"]              = NewToyEventHandler,
	["NewRecipeEventHandler"]           = NewRecipeEventHandler,
	["NewHousingItemEventHandler"]      = NewHousingItemEventHandler,
	["LoginEventHandler"]               = LoginEventHandler,
	["LevelUpEventHandler"]             = LevelUpEventHandler,
	["DeathEventHandler"]               = DeathEventHandler,
	["MythicEventHandler"]              = MythicEventHandler,
	["LootToastEventHandler"]           = LootToastEventHandler,
	["IntervalEventHandler"]            = IntervalEventHandler
}

------------------------
--- Module Functions ---
------------------------

function Capture:PreviewScreenshotSound(soundKey)
	PlayScreenshotSound(true, soundKey)
end

function Capture:ScheduleTimer(handler, delay, ...)
	local args = {...}

	C_Timer.After(delay, function()
		if HandlerTable[handler] then
			HandlerTable[handler](unpack(args))
		else
			Utils:PrintDebug(string.format(
				"Handler '%s' not found.",
				tostring(handler)
			))
		end
	end)
end
