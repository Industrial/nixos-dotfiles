local addonName, MEM = ...

local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
local buildDate = C_AddOns.GetAddOnMetadata(addonName, "X-BuildDate") or ""

MEM.CHANGELOG = {
	{
		version = version,
		date = buildDate ~= "" and buildDate or nil,
		entries = {
			"Added: TOC version for patch 12.1.5 [retail]"
		}
	},
	{
		version = "v2.25",
		date = "2026-08-30",
		entries = {
			"Minor code adjustments"
		}
	},
	{
		version = "v2.24",
		date = "2026-08-18",
		entries = {
			"Added: Changelog window available from the options menu",
			"Added: Changelog window available through the 'changelog' slash command",
			"Removed: Version notice chat messages",
			"Adapted to the latest version of Arcane Wizard: Library to ensure full compatibility"
		}
	},
	{
		version = "v2.23",
		date = "2026-08-14",
		entries = {
			"Removed: TOC version for patch 12.0.7 [retail]"
		}
	},
	{
		version = "v2.22",
		date = "2026-08-04",
		entries = {
			"Minor code adjustments"
		}
	},
	{
		version = "v2.21",
		date = "2026-07-31",
		entries = {
			"Changed: Playtime data is now requested only when at least one playtime output is enabled",
			"Updated: deDE, enUS localizations",
			"Minor code adjustments"
		}
	},
	{
		version = "v2.20",
		date = "2026-07-28",
		entries = {
			"Added: TOC version for patch 1.15.9 [classic]",
			"Added: New event 'Special Loot' - A screenshot can now be taken automatically when selected types of special loot are received",
			"Removed: TOC version for patch 1.15.8 [classic]",
			"Minor code adjustments",
			"Adapted to the latest version of Arcane Wizard: Library to ensure full compatibility"
		}
	},
	{
		version = "v2.19",
		date = "2026-07-26",
		entries = {
			"Added: Configurable sound effects can now be played after a screenshot has been taken"
		}
	},
	{
		version = "v2.18",
		date = "2026-07-21",
		entries = {
			"Updated: deDE, enUS localizations"
		}
	},
	{
		version = "v2.17",
		date = "2026-07-18",
		entries = {
			"Minor code adjustments"
		}
	}
}
