local addonName, MEM = ...

-- Capture
MEM.CAPTURE_DELAY_OFFSET = 0.1

-- Loot Toast
MEM.LOOT_TOAST_ITEM_LOAD_RETRY_DELAY = 0.2
MEM.LOOT_TOAST_ITEM_LOAD_RETRY_COUNT = 5

MEM.LOOT_TOAST_TYPE = {
	ITEM = "item",
	MONEY = "money",
	CURRENCY = "currency"
}

MEM.LOOT_TOAST_SETTING_BY_TYPE = {
	[MEM.LOOT_TOAST_TYPE.ITEM] = "loot-toast-item",
	[MEM.LOOT_TOAST_TYPE.MONEY] = "loot-toast-money",
	[MEM.LOOT_TOAST_TYPE.CURRENCY] = "loot-toast-currency"
}

MEM.LOOT_TOAST_QUALITY_DEFAULT = Enum.ItemQuality.Rare

MEM.LOOT_TOAST_QUALITIES = {
	Enum.ItemQuality.Rare,
	Enum.ItemQuality.Epic,
	Enum.ItemQuality.Legendary
}

-- Screenshot Sounds
local SCREENSHOT_SOUND_PATH = "Interface\\AddOns\\" .. addonName .. "\\assets\\"

MEM.SCREENSHOT_SOUND_CHANNEL = "SFX"
MEM.SCREENSHOT_SOUND_DEFAULT = "memento-camera"

MEM.SCREENSHOT_SOUNDS = {
	{
		key = MEM.SCREENSHOT_SOUND_DEFAULT,
		labelKey = "options.general.screenshot-sound-style.option.memento-camera",
		filePath = SCREENSHOT_SOUND_PATH .. "screenshot-camera.mp3"
	},
	{
		key = "notification",
		labelKey = "options.general.screenshot-sound-style.option.notification",
		filePath = SCREENSHOT_SOUND_PATH .. "screenshot-notification.mp3"
	},
	{
		key = "melody",
		labelKey = "options.general.screenshot-sound-style.option.melody",
		filePath = SCREENSHOT_SOUND_PATH .. "screenshot-melody.mp3"
	},
	{
		key = "quest-complete",
		labelKey = "options.general.screenshot-sound-style.option.quest-complete",
		soundKitNames = {"IG_QUEST_LIST_COMPLETE"}
	},
	{
		key = "ready-check",
		labelKey = "options.general.screenshot-sound-style.option.ready-check",
		soundKitNames = {"READY_CHECK"}
	},
	{
		key = "raid-warning",
		labelKey = "options.general.screenshot-sound-style.option.raid-warning",
		soundKitNames = {"RAID_WARNING", "READY_CHECK"}
	}
}

MEM.SCREENSHOT_SOUND_BY_KEY = {}

for _, soundData in ipairs(MEM.SCREENSHOT_SOUNDS) do
	MEM.SCREENSHOT_SOUND_BY_KEY[soundData.key] = soundData
end
