-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local LibStub = _G.LibStub
local ADDON_NAME, private = ...

-- Locales
local AL = LibStub("AceLocale-3.0"):GetLocale("RareScanner");

local RSNotes = private.NewLib("RareScannerNotes")

-- RareScanner general libraries
local RSConstants = private.ImportLib("RareScannerConstants")
local RSUtils = private.ImportLib("RareScannerUtils")
local RSTextTags = private.ImportLib("RareScannerTextTags")

---============================================================================
-- NPCs notes
---============================================================================

local function GetRawNote(entityID, mapID, minieventID)
	-- Crafting rare NPCs event
	if (RSUtils.Contains(RSConstants.CRAFTING_NPCS, entityID)) then
		return string.format(AL["NOTE_CRAFTING_NPCS"], AL[string.format("NOTE_%s", entityID)])
	-- Containers that require Reshii Wraps upgrade
	elseif (RSUtils.Contains(RSConstants.RESHII_WRAPS_CONTAINERS, entityID)) then
		if (AL[string.format("NOTE_%s", entityID)] ~= string.format("NOTE_%s", entityID)) then
			return string.format(AL["NOTE_RESHII_WRAPS"], "\n"..AL[string.format("NOTE_%s", entityID)])
		else
			return string.format(AL["NOTE_RESHII_WRAPS"], "")
		end
	-- Containers that require the renown 1 with Hara'ti
	elseif (RSUtils.Contains(RSConstants.MOTHS_RENOWN_1, entityID))	then
		if (AL[string.format("NOTE_%s", entityID)] ~= string.format("NOTE_%s", entityID)) then
			return string.format(AL["NOTE_MOTHS_RENOWN1"], "\n"..AL[string.format("NOTE_%s", entityID)])
		else
			return string.format(AL["NOTE_MOTHS_RENOWN1"], "")
		end
	-- Containers that require the renown 4 with Hara'ti
	elseif (RSUtils.Contains(RSConstants.MOTHS_RENOWN_4, entityID))	then
		if (AL[string.format("NOTE_%s", entityID)] ~= string.format("NOTE_%s", entityID)) then
			return string.format(AL["NOTE_MOTHS_RENOWN4"], "\n"..AL[string.format("NOTE_%s", entityID)])
		else
			return string.format(AL["NOTE_MOTHS_RENOWN4"], "")
		end
	-- Containers that require the renown 9 with Hara'ti
	elseif (RSUtils.Contains(RSConstants.MOTHS_RENOWN_9, entityID))	then
		if (AL[string.format("NOTE_%s", entityID)] ~= string.format("NOTE_%s", entityID)) then
			return string.format(AL["NOTE_MOTHS_RENOWN9"], "\n"..AL[string.format("NOTE_%s", entityID)])
		else
			return string.format(AL["NOTE_MOTHS_RENOWN9"], "")
		end
	
	-- Covenants rare NPCs
	elseif (entityID == RSConstants.WINGFLAYER_CRUEL) then
		return string.format(AL["NOTE_ANIMA_CONDUCTOR"], AL["NOTE_KYRIAN"], AL["NOTE_TEMPLE_COURAGE"], AL[string.format("NOTE_%s", entityID)])
	elseif (RSUtils.Contains(RSConstants.CITADEL_LOYALTY_NPCS, entityID)) then
		return string.format(AL["NOTE_ANIMA_CONDUCTOR"], AL["NOTE_KYRIAN"], AL["NOTE_CITADEL_LOYALTY"], AL["NOTE_CITADEL_LOYALTY_NPCS"])
	elseif (entityID == RSConstants.GIEGER) then
		return string.format(AL["NOTE_ANIMA_CONDUCTOR"], AL["NOTE_NECROLORDS"], AL["NOTE_HOUSE_CONSTRICTS"], AL[string.format("NOTE_%s", entityID)])
	elseif (RSUtils.Contains(RSConstants.THEATER_PAIN_NPCS, entityID)) then
		return string.format(AL["NOTE_ANIMA_CONDUCTOR"], AL["NOTE_NECROLORDS"], AL["NOTE_THEATER_PAIN"], AL["NOTE_THEATER_PAIN_NPCS"])
	elseif (entityID == RSConstants.CHOSEN_RUNECOFFER) then
		return string.format(AL["NOTE_ANIMA_CONDUCTOR"], AL["NOTE_NECROLORDS"], AL["NOTE_HOUSE_CHOSEN"], AL[string.format("NOTE_%s", entityID)])
	elseif (entityID == RSConstants.FORGEMASTER_MADALAV) then
		return string.format(AL["NOTE_ANIMA_CONDUCTOR"], AL["NOTE_VENTHYR"], AL["NOTE_DOMINANCE_KEEP"], AL[string.format("NOTE_%s", entityID)])
	elseif (entityID == RSConstants.HARIKA_HORRID) then
		return string.format(AL["NOTE_ANIMA_CONDUCTOR"], AL["NOTE_VENTHYR"], AL["NOTE_WANECRYPT_HILL"], AL[string.format("NOTE_%s", entityID)])
	elseif (entityID == RSConstants.GREEDS_DESIRE) then
		return string.format(AL["NOTE_ANIMA_CONDUCTOR"], AL["NOTE_VENTHYR"], AL["NOTE_CRYPT_FORGOTTEN"], AL[string.format("NOTE_%s", entityID)])
	elseif (entityID == RSConstants.VALFIR_UNRELENTING) then
		return string.format(AL["NOTE_ANIMA_CONDUCTOR"], AL["NOTE_NIGHT_FAE"], AL["NOTE_TIRNA_SCITHE"], AL[string.format("NOTE_%s", entityID)])
	elseif (entityID == RSConstants.LARGE_LUNARLIGHT_POD) then
		return string.format(AL["NOTE_ANIMA_CONDUCTOR"], AL["NOTE_NIGHT_FAE"], AL["NOTE_GLITTERFALL_BASIN"], AL[string.format("NOTE_%s", entityID)])
	
	-- Individual note by entityID
	elseif (AL[string.format("NOTE_%s", entityID)] ~= string.format("NOTE_%s", entityID)) then
		return AL[string.format("NOTE_%s", entityID)]
	-- Individual note by entityID and mapID
	elseif (AL[string.format("NOTE_%s_%s", entityID, mapID)] ~= string.format("NOTE_%s_%s", entityID, mapID)) then
		return AL[string.format("NOTE_%s_%s", entityID, mapID)]
	end
	
	-- Notes for dragon glyphs
	if (AL[string.format("NOTE_GLYPH_%s", entityID)] ~= string.format("NOTE_GLYPH_%s", entityID)) then
		return AL[string.format("NOTE_GLYPH_%s", entityID)]
	end
	
	-- Orator Kloe NPCs
	if (RSUtils.Contains(RSConstants.ORATOR_KLOE_NPCS, entityID)) then
		return AL["NOTE_ORATOR_KLOE_NPCS"]
	-- Daffodil NPCs
	elseif (RSUtils.Contains(RSConstants.DAFFODIL_NPCS, entityID)) then
		return AL["NOTE_DAFFODIL_NPCS"]
	-- Abuse of power NPCs
	elseif (RSUtils.Contains(RSConstants.ABUSE_POWER_GI_NPCS, entityID)) then
		return string.format(AL["NOTE_ABUSE_POWER_NPCS"], AL["NOTE_GRAND_INQUISITOR"])
	elseif (RSUtils.Contains(RSConstants.ABUSE_POWER_I_NPCS, entityID)) then
		return string.format(AL["NOTE_ABUSE_POWER_NPCS"], AL["NOTE_INQUISITOR"])
	elseif (RSUtils.Contains(RSConstants.ABUSE_POWER_HI_NPCS, entityID)) then
		return string.format(AL["NOTE_ABUSE_POWER_NPCS"], AL["NOTE_HIGH_INQUISITOR"])
	-- Swelling tear NPCs
	elseif (RSUtils.Contains(RSConstants.SWELLING_TEAR_NPCS, entityID)) then
		return AL["NOTE_SWELLING_TEAR_NPCS"]
	-- Vesper repair NPCs
	elseif (RSUtils.Contains(RSConstants.VESPER_REPAIR_NPCS, entityID)) then
		return AL["NOTE_VESPER_REPAIR_NPCS"]
	-- Dapperdew NPCs
	elseif (RSUtils.Contains(RSConstants.DAPPERDEW_NPCS, entityID)) then
		return AL["NOTE_DAPPERDEW_NPCS"]
	-- Ascended council NPCs
	elseif (RSUtils.Contains(RSConstants.ASCENDED_COUNCIL_NPCS, entityID)) then
		return AL["NOTE_ASCENDED_COUNCIL_NPCS"]
	-- Requires 4 people to summon NPCs
	elseif (RSUtils.Contains(RSConstants.FOUR_PEOPLE_NPCS, entityID)) then
		return AL["NOTE_FOUR_PEOPLE_NPCS"]
	-- Requires entering the rift
	elseif (RSUtils.Contains(RSConstants.RIFT_NPCS, entityID)) then
		return AL["NOTE_RIFT_NPCS"]
	-- Requires entering the rift in the maw
	elseif (RSUtils.Contains(RSConstants.RIFT_NPCS_MAW, entityID)) then
		return AL["NOTE_RIFT_NPCS_MAW"]
	-- Requires air storm invasion in Dragon Isles
	elseif (minieventID and minieventID == RSConstants.DRAGONFLIGHT_STORM_INVASTION_AIR_MINIEVENT) then
		return AL["NOTE_AIR_STORM_EVENTS"]
	-- Requires fire storm invasion in Dragon Isles
	elseif (minieventID and minieventID == RSConstants.DRAGONFLIGHT_STORM_INVASTION_FIRE_MINIEVENT) then
    	return AL["NOTE_FIRE_STORM_EVENTS"]
  	-- Requires earth storm invasion in Dragon Isles
  	elseif (minieventID and minieventID == RSConstants.DRAGONFLIGHT_STORM_INVASTION_EARTH_MINIEVENT) then
    	return AL["NOTE_EARTH_STORM_EVENTS"]
  	-- Requires water storm invasion in Dragon Isles
  	elseif (minieventID and minieventID == RSConstants.DRAGONFLIGHT_STORM_INVASTION_WATER_MINIEVENT) then
    	return AL["NOTE_WATER_STORM_EVENTS"]
	-- Grand hunting party bosses
	elseif (minieventID and minieventID == RSConstants.DRAGONFLIGHT_HUNTING_PARTY_MINIEVENT) then
		return AL["NOTE_HUNTING_PARTY_NPCS"]
	-- Omnious conchs
	elseif (RSUtils.Contains(RSConstants.OMINOUS_CONCHS_NPCS, entityID)) then
		return AL["NOTE_OMINOUS_CONCHS_NPCS"]
	-- Fyrakk assaults
	elseif (minieventID and minieventID == RSConstants.DRAGONFLIGHT_FYRAKK_MINIEVENT) then
		return AL["NOTE_FYRAKK_ASSAULTS_NPCS"]
	-- Elusive NPCs in Dragon Isles
	elseif (RSUtils.Contains(RSConstants.ELUSIVE_NPCS, entityID)) then
		return AL["NOTE_ELUSIVE_NPCS"]
	-- Requires dreamsurge investigation in Dragon Isles
  	elseif (minieventID and minieventID == RSConstants.DRAGONFLIGHT_DREAMSURGE_MINIEVENT) then
    	return AL["NOTE_DREAMSURGE_EVENTS"]
    -- Requires wordlsoul memory event
	elseif (minieventID and minieventID == RSConstants.WARWITHIN_RARES_WORLDSOUL_MINIEVENT) then
		return AL["NOTE_WORLDSOUL_RARE_NPCS"]
	-- Requires Storm's Brewin quest
	elseif (RSUtils.Contains(RSConstants.STORMS_BREWIN_NPCS, entityID)) then
		return AL["NOTE_STORMS_BREWIN_NPCS"]
	-- Requires Suspicious Document
	elseif (RSUtils.Contains(RSConstants.FLAMES_RADIANCE_INCURSION_NPCS, entityID)) then
		return AL["NOTE_FLAMES_RADIANCE_INCURSION_NPCS"]
	end
	
	-- Rune of constructs Containers
	if (RSUtils.Contains(RSConstants.RUNE_CONSTRUCTS_CONTAINERS, entityID)) then
		return AL["NOTE_RUNE_CONSTRUCTS_CONTAINERS"]
	-- Grappling growth Containers
	elseif (RSUtils.Contains(RSConstants.GRAPPLING_GROWTH_CONTAINERS, entityID)) then
		return AL["NOTE_GRAPPLING_GROWTH_CONTAINERS"]
	-- Greedstone Containers
	elseif (RSUtils.Contains(RSConstants.GREEDSTONE_CONTAINERS, entityID)) then
		return AL["NOTE_GREEDSTONE_CONTAINERS"]
	-- Lunarlight Containers
	elseif (RSUtils.Contains(RSConstants.LUNARLIGHT_CONTAINERS, entityID)) then
		return AL["NOTE_LUNARLIGHT_CONTAINERS"]
	-- Bounding Shroom Containers
	elseif (RSUtils.Contains(RSConstants.BOUNDING_SHRROM_CONTAINERS, entityID)) then
		return AL["NOTE_BOUNDING_SHROOM"]
	-- Ripe purian Containers
	elseif (RSUtils.Contains(RSConstants.RIPE_PURIAN_CONTAINERS, entityID)) then
		return AL["NOTE_RIPE_PURIAN_CONTAINERS"]
	-- Rift hidden containers
	elseif (RSUtils.Contains(RSConstants.RIFT_HIDDEN_ENTITIES, entityID)) then
		return AL["NOTE_RIFT_HIDDEN_CONTAINERS"]
	-- Korthia caches found by Swagsnout gromit
	elseif (RSUtils.Contains(RSConstants.CACHES_SWAGSNOUT_GROMIT, entityID)) then
		return AL["NOTE_CACHES_SWAGSNOUT_GROMIT"]
	-- The maw stolen anima vessels
	elseif (RSUtils.Contains(RSConstants.STOLEN_ANIMA_VESSEL, entityID)) then
		return AL["NOTE_STOLEN_ANIMA_VESSEL"]
	-- The maw stolen anima vessels (in the rift)
	elseif (RSUtils.Contains(RSConstants.STOLEN_ANIMA_VESSEL_RIFT, entityID)) then
		return AL["NOTE_STOLEN_ANIMA_VESSEL_RIFT"]
	-- Disturbed dirt
	elseif (RSUtils.Contains(RSConstants.DISTURBED_DIRT, entityID)) then
		return AL["NOTE_DISTURBED_DIRT"]
	-- Magic-Bound Chest
	elseif (RSUtils.Contains(RSConstants.MAGIC_BOUND_CHEST, entityID)) then
		return AL["NOTE_MAGIC_BOUND_CHEST"]
	-- Not trackable containers
	elseif (RSUtils.Contains(RSConstants.CONTAINERS_WITHOUT_VIGNETTE, entityID)) then
		return AL["NOTE_CONTAINERS_WITHOUT_VIGNETTE"]
	-- Forbidden Reach containers
	elseif (RSUtils.Contains(RSConstants.CONTAINERS_FORBIDDEN_REACH, entityID)) then
		return AL["NOTE_CONTAINERS_FORBIDDEN_REACH"]
	-- Unwaking echo containers
	elseif (RSUtils.Contains(RSConstants.CONTAINERS_UNWAKING_ECHO, entityID)) then
		return AL["NOTE_UNWAKING_ECHO"]
	-- Containers that despawn
	elseif (RSUtils.Contains(RSConstants.CONTAINERS_DESPAWN, entityID)) then
		return AL["NOTE_CONTAINER_DESPAWNS"]
	-- Containers that require the Potion of Polymorphic Translation
	elseif (RSUtils.Contains(RSConstants.CONTAINERS_POTION_POLYMORPHIC_TRANSLATION, entityID)) then
		return AL["NOTE_CONTAINER_POLYMORPHIC_TRANSLATION"]
	-- Containers that require Sparkbug Jar
	elseif (RSUtils.Contains(RSConstants.CONTAINERS_SPARKBUG, entityID)) then
		return AL["NOTE_CONTAINER_SPARKBUG"]
	-- Slimy Cocoons
	elseif (RSUtils.Contains(RSConstants.CONTAINERS_SLIMY_COCOON, entityID)) then
		return AL["NOTE_CONTAINER_SLIMY_COCOON"]
	-- Containers for the achievement Nine tenths of Law
	elseif (RSUtils.Contains(RSConstants.NINE_TENTHS_LAW_CHAPTER_4, entityID)) then
		return AL["NINE_TENTHS_LAW_CHAPTER_4"]
	-- NPCs and containers that require Phase Diving at K'aresh
	elseif (RSUtils.Contains(RSConstants.PHASE_DIVING, entityID)) then
		return AL["PHASE_DIVING"]
	-- Containers in caves that require Light's judgment to open them
	elseif (RSUtils.Contains(RSConstants.CONTAINERS_LIGHTS_JUDGMENT, entityID)) then
		return AL["NOTE_LIGHTS_JUDGMENT"]
	-- Containers that require a goblin glider kit to reach its position
	elseif (RSUtils.Contains(RSConstants.CONTAINERS_GOBLIN_GLIDER_KIT, entityID)) then
		return AL["NOTE_GOBLIN_GLIDER_KIT"]
	-- Containers in caves that require Shroud arcane echoes to open them
	elseif (RSUtils.Contains(RSConstants.CONTAINERS_SHROUD_ARCANE_ECHOES, entityID)) then
		return AL["NOTE_SHROUD_ARCANE_ECHOES"]
	-- Containers in caves that require Light's judgment to open them
	elseif (RSUtils.Contains(RSConstants.CONTAINERS_LIGHTFORGED_WARFRAME, entityID)) then
		return AL["NOTE_LIGHTFORGED_WARFRAME"]
	-- Entities that appear after liberating Atal'Aman
	elseif (RSUtils.Contains(RSConstants.ENTITIES_ATAL_AMAN, entityID))	then
		return AL["NOTE_ATAL_AMAN"]
	-- Containers that require the quest The echoless flame
	elseif (RSUtils.Contains(RSConstants.CONTAINERS_ECHOLESS_FLAME, entityID))	then
		return AL["NOTE_ECHOLESS_FLAME"]
	-- Containers that require the quest Russula's Outreach
	elseif (RSUtils.Contains(RSConstants.CONTAINERS_RUSSULAS_OUTREACH, entityID))	then
		return AL["NOTE_RUSSULAS_OUTREACH"]
	-- Containers that require the quest Aln'Hara's Bloom
	elseif (RSUtils.Contains(RSConstants.CONTAINERS_ALN_HARAS_BLOOM, entityID))	then
		return AL["NOTE_ALN_HARAS_BLOOM"]
	-- Containers that require the quest Cauldron Echoes
	elseif (RSUtils.Contains(RSConstants.CONTAINERS_CAULDRON_ECHOES, entityID))	then
		return AL["NOTE_CAULDRON_ECHOES"]
	-- Containers that require the quest Root of the World
	elseif (RSUtils.Contains(RSConstants.CONTAINERS_ROOT_WORLD, entityID))	then
		return AL["NOTE_ROOT_WORLD"]
	-- Containers that require the quest Sky's hope
	elseif (RSUtils.Contains(RSConstants.CONTAINERS_SKY_HOPE, entityID))	then
		return AL["NOTE_SKY_HOPE"]
	-- Containers that require the quest Wey'nans Ward
	elseif (RSUtils.Contains(RSConstants.CONTAINERS_WEYNAN_WARD, entityID))	then
		return AL["NOTE_WEYNAN_WARD"]
	-- NPCs that require renown with Ritual Sites
	elseif (RSUtils.Contains(RSConstants.RARES_RITUAL_SITES_4, entityID))	then
		return AL["NOTE_RARES_RITUAL_SITES_4"]
	elseif (RSUtils.Contains(RSConstants.RARES_RITUAL_SITES_8, entityID))	then
		return AL["NOTE_RARES_RITUAL_SITES_8"]
	-- Containers that require chapter 2 of the campaign
	elseif (RSUtils.Contains(RSConstants.CONTAINERS_COILED_ISLE_CHAPTER2, entityID))	then
		return AL["NOTE_COILED_ISLE_CHAPTER2"]
	-- NPCs that require a temple incursion
	elseif (RSUtils.Contains(RSConstants.RARES_TEMPLE_INCURSION, entityID))	then
		return AL["NOTE_TEMPLE_INCURSION"]
	end
end

function RSNotes.GetNote(entityID, mapID, minieventID, callback)
	local note = GetRawNote(entityID, mapID, minieventID)
	if (note) then
		return RSTextTags.ParseText(note, callback)
	end

	return nil
end