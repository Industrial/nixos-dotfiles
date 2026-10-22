-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local LibStub = _G.LibStub
local ADDON_NAME, private = ...

local LibDialog = LibStub("LibDialog-1.0RS")

local RSCollectionsDB = private.NewLib("RareScannerCollectionsDB")

-- Player class cached once (class never changes during session)
local _, _, playerClassIndex = UnitClass("player")

-- Locales
local AL = LibStub("AceLocale-3.0"):GetLocale("RareScanner");

-- RareScanner database libraries
local RSNpcDB = private.ImportLib("RareScannerNpcDB")
local RSContainerDB = private.ImportLib("RareScannerContainerDB")
local RSConfigDB = private.ImportLib("RareScannerConfigDB")
local RSAchievementDB = private.ImportLib("RareScannerAchievementDB")

-- RareScanner libraries
local RSConstants = private.ImportLib("RareScannerConstants")
local RSLogger = private.ImportLib("RareScannerLogger")
local RSUtils = private.ImportLib("RareScannerUtils")
local RSRoutines = private.ImportLib("RareScannerRoutines")
local RSTooltipScanners = private.ImportLib("RareScannerTooltipScanners")

---============================================================================
-- Transmog locations (added in 9.2.5)
---============================================================================

local TRANSMOG_LOCATIONS = {
	["HEADSLOT"] = { Enum.TransmogCollectionType.Head };
	["SHOULDERSLOT"] = { Enum.TransmogCollectionType.Shoulder };
	["BACKSLOT"] = { Enum.TransmogCollectionType.Back };
	["CHESTSLOT"] = { Enum.TransmogCollectionType.Chest };
	["SHIRTSLOT"] = { Enum.TransmogCollectionType.Shirt };
	["TABARDSLOT"] = { Enum.TransmogCollectionType.Tabard };
	["WRISTSLOT"] = { Enum.TransmogCollectionType.Wrist };
	["HANDSSLOT"] = { Enum.TransmogCollectionType.Hands };
	["WAISTSLOT"] = { Enum.TransmogCollectionType.Waist };
	["LEGSSLOT"] = { Enum.TransmogCollectionType.Legs };
	["FEETSLOT"] = { Enum.TransmogCollectionType.Feet };
	["MAINHANDSLOT"] = { Enum.TransmogCollectionType.Wand, Enum.TransmogCollectionType.OneHAxe, Enum.TransmogCollectionType.OneHSword, Enum.TransmogCollectionType.OneHMace, Enum.TransmogCollectionType.Dagger, Enum.TransmogCollectionType.Fist, Enum.TransmogCollectionType.TwoHAxe, Enum.TransmogCollectionType.TwoHSword, Enum.TransmogCollectionType.TwoHMace, Enum.TransmogCollectionType.Staff, Enum.TransmogCollectionType.Polearm, Enum.TransmogCollectionType.Bow, Enum.TransmogCollectionType.Gun, Enum.TransmogCollectionType.Crossbow, Enum.TransmogCollectionType.Warglaives, Enum.TransmogCollectionType.Paired };
	["SECONDARYHANDSLOT"] = { Enum.TransmogCollectionType.Shield, Enum.TransmogCollectionType.Holdable };
}

local CLASS_MISSING_APPEARNACES = {
	[1] = { --Warrior
		[Enum.ItemClass.Weapon] = {
			[Enum.ItemWeaponSubclass.Axe1H] = true,
			[Enum.ItemWeaponSubclass.Axe2H] = true,
			[Enum.ItemWeaponSubclass.Bows] = true,
			[Enum.ItemWeaponSubclass.Guns] = true,
			[Enum.ItemWeaponSubclass.Mace1H] = true,
			[Enum.ItemWeaponSubclass.Mace2H] = true,
			[Enum.ItemWeaponSubclass.Polearm] = true,
			[Enum.ItemWeaponSubclass.Sword1H] = true,
			[Enum.ItemWeaponSubclass.Sword2H] = true,
			[Enum.ItemWeaponSubclass.Staff] = true,
			[Enum.ItemWeaponSubclass.Bearclaw] = true,
			[Enum.ItemWeaponSubclass.Catclaw] = true,
			[Enum.ItemWeaponSubclass.Unarmed] = true,
			[Enum.ItemWeaponSubclass.Generic] = true,
			[Enum.ItemWeaponSubclass.Dagger] = true,
			[Enum.ItemWeaponSubclass.Thrown] = true,
			[Enum.ItemWeaponSubclass.Crossbow] = true,
			[Enum.ItemWeaponSubclass.Fishingpole] = true,
		},
		[Enum.ItemClass.Armor] = {
			[Enum.ItemArmorSubclass.Plate] = true,
			[Enum.ItemArmorSubclass.Shield] = true,
		}
	};
	[2] = { --Paladin
		[Enum.ItemClass.Weapon] = {
			[Enum.ItemWeaponSubclass.Axe1H] = true,
			[Enum.ItemWeaponSubclass.Axe2H] = true,
			[Enum.ItemWeaponSubclass.Mace1H] = true,
			[Enum.ItemWeaponSubclass.Mace2H] = true,
			[Enum.ItemWeaponSubclass.Polearm] = true,
			[Enum.ItemWeaponSubclass.Sword1H] = true,
			[Enum.ItemWeaponSubclass.Sword2H] = true,
			[Enum.ItemWeaponSubclass.Generic] = true,
			[Enum.ItemWeaponSubclass.Fishingpole] = true,
		},
		[Enum.ItemClass.Armor] = {
			[Enum.ItemArmorSubclass.Plate] = true,
			[Enum.ItemArmorSubclass.Shield] = true,
		}
	};
	[3] = { --Hunter
		[Enum.ItemClass.Weapon] = {
			[Enum.ItemWeaponSubclass.Axe1H] = true,
			[Enum.ItemWeaponSubclass.Axe2H] = true,
			[Enum.ItemWeaponSubclass.Bows] = true,
			[Enum.ItemWeaponSubclass.Guns] = true,
			[Enum.ItemWeaponSubclass.Polearm] = true,
			[Enum.ItemWeaponSubclass.Sword1H] = true,
			[Enum.ItemWeaponSubclass.Sword2H] = true,
			[Enum.ItemWeaponSubclass.Staff] = true,
			[Enum.ItemWeaponSubclass.Bearclaw] = true,
			[Enum.ItemWeaponSubclass.Catclaw] = true,
			[Enum.ItemWeaponSubclass.Unarmed] = true,
			[Enum.ItemWeaponSubclass.Generic] = true,
			[Enum.ItemWeaponSubclass.Dagger] = true,
			[Enum.ItemWeaponSubclass.Crossbow] = true,
			[Enum.ItemWeaponSubclass.Fishingpole] = true,
		},
		[Enum.ItemClass.Armor] = {
			[Enum.ItemArmorSubclass.Mail] = true,
		}
	};
	[4] = { --Rogue
		[Enum.ItemClass.Weapon] = {
			[Enum.ItemWeaponSubclass.Axe1H] = true,
			[Enum.ItemWeaponSubclass.Bows] = true,
			[Enum.ItemWeaponSubclass.Guns] = true,
			[Enum.ItemWeaponSubclass.Mace1H] = true,
			[Enum.ItemWeaponSubclass.Sword1H] = true,
			[Enum.ItemWeaponSubclass.Bearclaw] = true,
			[Enum.ItemWeaponSubclass.Catclaw] = true,
			[Enum.ItemWeaponSubclass.Unarmed] = true,
			[Enum.ItemWeaponSubclass.Generic] = true,
			[Enum.ItemWeaponSubclass.Dagger] = true,
			[Enum.ItemWeaponSubclass.Thrown] = true,
			[Enum.ItemWeaponSubclass.Crossbow] = true,
			[Enum.ItemWeaponSubclass.Fishingpole] = true,
		},
		[Enum.ItemClass.Armor] = {
			[Enum.ItemArmorSubclass.Leather] = true,
		}
	};
	[5] = { --Priest
		[Enum.ItemClass.Weapon] = {
			[Enum.ItemWeaponSubclass.Mace1H] = true,
			[Enum.ItemWeaponSubclass.Staff] = true,
			[Enum.ItemWeaponSubclass.Generic] = true,
			[Enum.ItemWeaponSubclass.Dagger] = true,
			[Enum.ItemWeaponSubclass.Wand] = true,
			[Enum.ItemWeaponSubclass.Fishingpole] = true,
		},
		[Enum.ItemClass.Armor] = {
			[Enum.ItemArmorSubclass.Cloth] = true,
		}
	};
	[6] = { --DeathKnight
		[Enum.ItemClass.Weapon] = {
			[Enum.ItemWeaponSubclass.Axe1H] = true,
			[Enum.ItemWeaponSubclass.Axe2H] = true,
			[Enum.ItemWeaponSubclass.Mace1H] = true,
			[Enum.ItemWeaponSubclass.Mace2H] = true,
			[Enum.ItemWeaponSubclass.Polearm] = true,
			[Enum.ItemWeaponSubclass.Sword1H] = true,
			[Enum.ItemWeaponSubclass.Sword2H] = true,
			[Enum.ItemWeaponSubclass.Generic] = true,
			[Enum.ItemWeaponSubclass.Fishingpole] = true,
		},
		[Enum.ItemClass.Armor] = {
			[Enum.ItemArmorSubclass.Plate] = true,
		}
	};
	[7] = { --Shaman
		[Enum.ItemClass.Weapon] = {
			[Enum.ItemWeaponSubclass.Axe1H] = true,
			[Enum.ItemWeaponSubclass.Axe2H] = true,
			[Enum.ItemWeaponSubclass.Mace1H] = true,
			[Enum.ItemWeaponSubclass.Mace2H] = true,
			[Enum.ItemWeaponSubclass.Staff] = true,
			[Enum.ItemWeaponSubclass.Bearclaw] = true,
			[Enum.ItemWeaponSubclass.Catclaw] = true,
			[Enum.ItemWeaponSubclass.Unarmed] = true,
			[Enum.ItemWeaponSubclass.Generic] = true,
			[Enum.ItemWeaponSubclass.Dagger] = true,
			[Enum.ItemWeaponSubclass.Fishingpole] = true,
		},
		[Enum.ItemClass.Armor] = {
			[Enum.ItemArmorSubclass.Mail] = true,
			[Enum.ItemArmorSubclass.Shield] = true,
		}
	};
	[8] = { --Mage
		[Enum.ItemClass.Weapon] = {
			[Enum.ItemWeaponSubclass.Sword1H] = true,
			[Enum.ItemWeaponSubclass.Staff] = true,
			[Enum.ItemWeaponSubclass.Generic] = true,
			[Enum.ItemWeaponSubclass.Dagger] = true,
			[Enum.ItemWeaponSubclass.Wand] = true,
			[Enum.ItemWeaponSubclass.Fishingpole] = true,
		},
		[Enum.ItemClass.Armor] = {
			[Enum.ItemArmorSubclass.Cloth] = true,
		}
	};
	[9] = { --Warlock
		[Enum.ItemClass.Weapon] = {
			[Enum.ItemWeaponSubclass.Sword1H] = true,
			[Enum.ItemWeaponSubclass.Staff] = true,
			[Enum.ItemWeaponSubclass.Generic] = true,
			[Enum.ItemWeaponSubclass.Dagger] = true,
			[Enum.ItemWeaponSubclass.Wand] = true,
			[Enum.ItemWeaponSubclass.Fishingpole] = true,
		},
		[Enum.ItemClass.Armor] = {
			[Enum.ItemArmorSubclass.Cloth] = true,
		}
	};
	[10] = { --Monk
		[Enum.ItemClass.Weapon] = {
			[Enum.ItemWeaponSubclass.Axe1H] = true,
			[Enum.ItemWeaponSubclass.Mace1H] = true,
			[Enum.ItemWeaponSubclass.Polearm] = true,
			[Enum.ItemWeaponSubclass.Sword1H] = true,
			[Enum.ItemWeaponSubclass.Staff] = true,
			[Enum.ItemWeaponSubclass.Bearclaw] = true,
			[Enum.ItemWeaponSubclass.Catclaw] = true,
			[Enum.ItemWeaponSubclass.Unarmed] = true,
			[Enum.ItemWeaponSubclass.Generic] = true,
			[Enum.ItemWeaponSubclass.Fishingpole] = true,
		},
		[Enum.ItemClass.Armor] = {
			[Enum.ItemArmorSubclass.Leather] = true,
		}
	};
	[11] = { --Druid
		[Enum.ItemClass.Weapon] = {
			[Enum.ItemWeaponSubclass.Mace1H] = true,
			[Enum.ItemWeaponSubclass.Mace2H] = true,
			[Enum.ItemWeaponSubclass.Polearm] = true,
			[Enum.ItemWeaponSubclass.Staff] = true,
			[Enum.ItemWeaponSubclass.Bearclaw] = true,
			[Enum.ItemWeaponSubclass.Catclaw] = true,
			[Enum.ItemWeaponSubclass.Unarmed] = true,
			[Enum.ItemWeaponSubclass.Generic] = true,
			[Enum.ItemWeaponSubclass.Dagger] = true,
			[Enum.ItemWeaponSubclass.Fishingpole] = true,
		},
		[Enum.ItemClass.Armor] = {
			[Enum.ItemArmorSubclass.Leather] = true,
		}
	};
	[12] = { --Demon Hunter
		[Enum.ItemClass.Weapon] = {
			[Enum.ItemWeaponSubclass.Axe1H] = true,
			[Enum.ItemWeaponSubclass.Sword1H] = true,
			[Enum.ItemWeaponSubclass.Warglaive] = true,
			[Enum.ItemWeaponSubclass.Bearclaw] = true,
			[Enum.ItemWeaponSubclass.Catclaw] = true,
			[Enum.ItemWeaponSubclass.Unarmed] = true,
			[Enum.ItemWeaponSubclass.Generic] = true,
			[Enum.ItemWeaponSubclass.Fishingpole] = true,
		},
		[Enum.ItemClass.Armor] = {
			[Enum.ItemArmorSubclass.Leather] = true,
		}
	};
	[13] = { --Evoker
		[Enum.ItemClass.Weapon] = {
			[Enum.ItemWeaponSubclass.Axe1H] = true,
			[Enum.ItemWeaponSubclass.Axe2H] = true,
			[Enum.ItemWeaponSubclass.Mace1H] = true,
			[Enum.ItemWeaponSubclass.Mace2H] = true,
			[Enum.ItemWeaponSubclass.Sword1H] = true,
			[Enum.ItemWeaponSubclass.Sword2H] = true,
			[Enum.ItemWeaponSubclass.Staff] = true,
			[Enum.ItemWeaponSubclass.Bearclaw] = true,
			[Enum.ItemWeaponSubclass.Catclaw] = true,
			[Enum.ItemWeaponSubclass.Unarmed] = true,
			[Enum.ItemWeaponSubclass.Generic] = true,
			[Enum.ItemWeaponSubclass.Dagger] = true,
			[Enum.ItemWeaponSubclass.Thrown] = true,
			[Enum.ItemWeaponSubclass.Fishingpole] = true,
		},
		[Enum.ItemClass.Armor] = {
			[Enum.ItemArmorSubclass.Mail] = true,
		}
	};
}

local CLASS_MASKS = {
	[1]  = 0x1,    -- Warrior
	[2]  = 0x2,    -- Paladin
	[3]  = 0x4,    -- Hunter
	[4]  = 0x8,    -- Rogue
	[5]  = 0x10,   -- Priest
	[6]  = 0x20,   -- DeathKnight
	[7]  = 0x40,   -- Shaman
	[8]  = 0x80,   -- Mage
	[9]  = 0x100,  -- Warlock
	[10] = 0x200,  -- Monk
	[11] = 0x400,  -- Druid
	[12] = 0x800,  -- Demon Hunter
	[13] = 0x1000, -- Evoker
}
local ALL_CLASSES_MASK = 0x1FFF -- Suma de todas las clases bits (8191)

---============================================================================
-- Auxiliar functions
---============================================================================

local function PlayerCanUseItem(itemID)
	local _, _, _, itemEquipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
	
	-- If cloak
	if (itemEquipLoc == Enum.InventoryType.IndexCloakType) then
		return true
	end
	
	-- If weapon or armor
	local classProf = CLASS_MISSING_APPEARNACES[playerClassIndex]
	if (classProf and classProf[classID] and classProf[classID][subclassID]) then
		return true
	end
	
	return false
end

---============================================================================
-- Manage database
---============================================================================

local function ResetEntitiesCollectionsLoot()
	private.dbglobal.entity_collections_loot = {}
end

local function UpdateEntityCollection(itemID, entityID, source, itemType)
	local allLoot = RSCollectionsDB.GetAllEntitiesCollectionsLoot()
	if (not allLoot) then
		ResetEntitiesCollectionsLoot()
		allLoot = RSCollectionsDB.GetAllEntitiesCollectionsLoot()
	end
	
	local sourceLoot = allLoot[source]
	if (not sourceLoot) then
		sourceLoot = {}
		allLoot[source] = sourceLoot
	end
	
	local entityLoot = sourceLoot[entityID]
	if (not entityLoot) then
		entityLoot = {}
		sourceLoot[entityID] = entityLoot
	end
	
	local itemTypeList = entityLoot[itemType]
	if (not itemTypeList) then
		itemTypeList = {}
		entityLoot[itemType] = itemTypeList
	end
	
	if (not RSUtils.Contains(itemTypeList, itemID)) then
		table.insert(itemTypeList, itemID)
	end
end

---============================================================================
-- Toys
---============================================================================

local function UpdateNotCollectedToys(routines, routineTextOutput)
	-- Backup settings
	local collectedShown = C_ToyBox.GetCollectedShown();
	local uncollectedShown = C_ToyBox.GetUncollectedShown();
	local unusableShown = C_ToyBox.GetUnusableShown();
	
	-- Prepare filters
	C_ToyBox.SetCollectedShown(false);
	C_ToyBox.SetUncollectedShown(true);
	C_ToyBox.SetUnusableShown(true);
	C_ToyBox.SetAllExpansionTypeFilters(true);
	C_ToyBox.SetFilterString("");
		
	for i=1,C_PetJournal.GetNumPetSources() do
		if (i == 1) then
			C_ToyBox.SetSourceTypeFilter(i, true) -- Drop source
		else
			C_ToyBox.SetSourceTypeFilter(i, false) -- Other source
		end
	end
	
	private.dbglobal.not_colleted_toys = {}
	
	-- Query
	local notCollectedToyRoutine = RSRoutines.LoopIndexRoutineNew()
	notCollectedToyRoutine:Init(
		C_ToyBox.GetNumFilteredToys,
		function(context, i)
			local toyID = C_ToyBox.GetToyFromIndex(i)
			local itemID, _, _, _, _, _ = C_ToyBox.GetToyInfo(toyID)
			if (itemID) then
				private.dbglobal.not_colleted_toys[itemID] = true
				context.counter = (context.counter or 0) + 1
			end
		end,
		function(context)
			-- Restore settings
			C_ToyBox.SetCollectedShown(collectedShown);
			C_ToyBox.SetUncollectedShown(uncollectedShown);
			C_ToyBox.SetUnusableShown(unusableShown);
			C_ToyBox.SetAllExpansionTypeFilters(true);
			C_ToyBox.SetAllSourceTypeFilters(true);
			
			RSLogger:PrintDebugMessage(string.format("UpdateNotCollectedToys. [%s no conseguidos].", context.counter or 0))
			
			if (routineTextOutput) then
				routineTextOutput:SetText(string.format(AL["EXPLORER_MISSING_TOYS"], context.counter or 0))
			end
		end
	)
	table.insert(routines, notCollectedToyRoutine)
end

local function GetNotCollectedToys()
	return private.dbglobal.not_colleted_toys
end

local function CheckUpdateToy(itemID, entityID, source, checkedItems)
	-- If cached use it
	if (checkedItems[RSConstants.ITEM_TYPE.TOY][itemID]) then
		UpdateEntityCollection(itemID, entityID, source, RSConstants.ITEM_TYPE.TOY)
		return true
	else
		local notCollectedToys = GetNotCollectedToys()
		if (notCollectedToys and notCollectedToys[itemID]) then
			UpdateEntityCollection(itemID, entityID, source, RSConstants.ITEM_TYPE.TOY)
			checkedItems[RSConstants.ITEM_TYPE.TOY][itemID] = true
			return true
		end
	
		return false
	end
end

function RSCollectionsDB.RemoveNotCollectedToy(itemID, callback) --NEW_TOY_ADDED
	local notCollectedToys = GetNotCollectedToys()
	if (itemID and notCollectedToys) then		
		-- Drop missing toy
		if (notCollectedToys[itemID]) then
			notCollectedToys[itemID] = nil
			RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedToy[%s]: Eliminado coleccionable conseguido.", itemID))
		end
		
		-- Update filters
		local allEntitiesCollectionsLoot = RSCollectionsDB.GetAllEntitiesCollectionsLoot()
		if (not allEntitiesCollectionsLoot) then
			return
		end
		
		local refresh = false
		for source, entities in pairs (allEntitiesCollectionsLoot) do
			for entityID, itemTypes in pairs (entities) do
				local lootList = itemTypes[RSConstants.ITEM_TYPE.TOY]
				if (lootList) then
					for i = #lootList, 1, -1 do
						if (lootList[i] == itemID) then
							if (#lootList == 1) then
								RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedToy[%s]: Eliminado coleccionable de la lista de la entidad [%s]. No tiene mas juguetes.", itemID, entityID))
								itemTypes[RSConstants.ITEM_TYPE.TOY] = nil
							else
								RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedToy[%s]: Eliminado coleccionable de la lista de la entidad [%s].", itemID, entityID))
								table.remove(lootList, i)
							end
							
							-- Check if the entity doesn't have more collections
							if (RSUtils.GetTableLength(itemTypes) == 0) then
								entities[entityID] = nil
								
								-- Filter
								if (RSConfigDB.IsAutoFilteringOnCollect()) then
									if (source == RSConstants.ITEM_SOURCE.NPC) then
										RSConfigDB.SetNpcFiltered(entityID)
										RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedToy[%s]: Filtrado NPC [%s] por no disponer de mas coleccionables.", itemID, entityID))
										if (RSNpcDB.GetNpcName(entityID)) then
											RSLogger:PrintMessage(string.format(AL["EXPLORER_AUTOFILTER"], RSNpcDB.GetNpcName(entityID)))
										end
									elseif (source == RSConstants.ITEM_SOURCE.CONTAINER) then
										RSConfigDB.SetContainerFiltered(entityID)
										RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedToy[%s]: Filtrado Contenedor [%s] por no disponer de mas coleccionables.", itemID, entityID))
										if (RSContainerDB.GetContainerName(entityID)) then
											RSLogger:PrintMessage(string.format(AL["EXPLORER_AUTOFILTER"], RSContainerDB.GetContainerName(entityID)))
										end
									end
								end
							end
							
							refresh = true
							break
						end
					end
				end
			end
		end
		
		if (refresh and callback) then
			callback()
		end
    end
end

---============================================================================
-- Pets
---============================================================================

local function UpdateNotCollectedPetIDs(routines, routineTextOutput)
	-- Backup settings
	local filterCollected = C_PetJournal.IsFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED)
	local filterNotCollected = C_PetJournal.IsFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED)
	
	-- Prepare filters
	C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED, false)
	C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED, true)
	C_PetJournal.SetAllPetTypesChecked(true)
	C_PetJournal.ClearSearchFilter()
	
	for i=1,C_PetJournal.GetNumPetSources() do
		if (i == 1 or i == 4) then
			C_PetJournal.SetPetSourceChecked(i, true) -- Drop/Profession source
		else
			C_PetJournal.SetPetSourceChecked(i, false) -- Other source
		end
	end
	
	private.dbglobal.not_colleted_pets_ids = {}
	
	-- Query
	local notCollectedPetIDs = RSRoutines.LoopIndexRoutineNew()
	notCollectedPetIDs:Init(
		C_PetJournal.GetNumPets,
		function(context, i)
			local _, _, _, _, _, _, _, _, _, _, companionID, _, _, _, _, _, _, _ = C_PetJournal.GetPetInfoByIndex(i)
			-- The first parameter is the petID but for some reason it comes nil, so we must use the companionID
			if (companionID) then
				private.dbglobal.not_colleted_pets_ids[companionID] = true
				context.counter = (context.counter or 0) + 1
			end
		end,
		function(context)
			-- Restore settings
			C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED, filterCollected)
			C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED, filterNotCollected)
			C_PetJournal.SetAllPetSourcesChecked(true)
			
			RSLogger:PrintDebugMessage(string.format("UpdateNotCollectedPetIDs. [%s no conseguidas].", context.counter or 0))
			
			if (routineTextOutput) then
				routineTextOutput:SetText(string.format(AL["EXPLORER_MISSING_PETS"], context.counter or 0))
			end
		end
	)
	table.insert(routines, notCollectedPetIDs)	
end

local function GetNotCollectedPetsIDs()
	return private.dbglobal.not_colleted_pets_ids
end

local function GetPetItemIDs(creatureID)
	if (creatureID) then
		return private.DROPPED_PET_IDS[creatureID]
	end
	
	return nil
end

function RSCollectionsDB.GetCreatureID(itemID)
	if (itemID) then
		for creatureID, itemIDs in pairs(private.DROPPED_PET_IDS) do
			if (RSUtils.Contains(itemIDs, itemID)) then
				return creatureID
			end
		end
	end
	
	return nil
end

local function CheckUpdatePet(itemID, entityID, source, checkedItems)
	-- If cached use it
	if (checkedItems[RSConstants.ITEM_TYPE.PET][itemID]) then
		UpdateEntityCollection(itemID, entityID, source, RSConstants.ITEM_TYPE.PET)
		return true
	else
		local creatureID = RSCollectionsDB.GetCreatureID(itemID)
		if (creatureID) then			
			local notCollectedPetsIDs = GetNotCollectedPetsIDs()
			if (notCollectedPetsIDs and notCollectedPetsIDs[creatureID]) then
				UpdateEntityCollection(itemID, entityID, source, RSConstants.ITEM_TYPE.PET)
				checkedItems[RSConstants.ITEM_TYPE.PET][itemID] = true
				return true
			end
		end
		
		return false
	end
end

function RSCollectionsDB.RemoveNotCollectedPet(petGUID, callback) --NEW_PET_ADDED
	local notCollectedPetsIDs = GetNotCollectedPetsIDs()
	if (petGUID and notCollectedPetsIDs) then
		local _, _, _, _, _, _, _, _, _, _, creatureID, _, _, _, _, _, _, _ = C_PetJournal.GetPetInfoByPetID(petGUID)
		if (not creatureID) then
			RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedPet[%s]: No se ha localizado el creatureID asociado.", petGUID))
			return
		end
		
		-- Drop missing pet
		if (notCollectedPetsIDs[creatureID]) then
			notCollectedPetsIDs[creatureID] = nil
			RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedPet[%s]: Eliminado coleccionable conseguido.", petGUID))
		end
		
		-- Update filters
		local allEntitiesCollectionsLoot = RSCollectionsDB.GetAllEntitiesCollectionsLoot()
		if (not allEntitiesCollectionsLoot) then
			return
		end
		
		local refresh = false
		for source, entities in pairs (allEntitiesCollectionsLoot) do
			for entityID, itemTypes in pairs (entities) do
				local lootList = itemTypes[RSConstants.ITEM_TYPE.PET]
				if (lootList) then
					for i = #lootList, 1, -1 do
						if (RSUtils.Contains(GetPetItemIDs(creatureID), lootList[i])) then
							if (#lootList == 1) then
								RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedPet[%s]: Eliminado coleccionable de la lista de la entidad [%s]. No tiene mas mascotas.", petGUID, entityID))
								itemTypes[RSConstants.ITEM_TYPE.PET] = nil
							else
								RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedPet[%s]: Eliminado coleccionable de la lista de la entidad [%s].", petGUID, entityID))
								table.remove(lootList, i)
							end
							
							-- Check if the entity doesn't have more collections
							if (RSUtils.GetTableLength(itemTypes) == 0) then
								entities[entityID] = nil
								
								-- Filter
								if (RSConfigDB.IsAutoFilteringOnCollect()) then
									if (source == RSConstants.ITEM_SOURCE.NPC) then
										RSConfigDB.SetNpcFiltered(entityID)
										RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedPet[%s]: Filtrado NPC [%s] por no disponer de mas coleccionables.", petGUID, entityID))
										if (RSNpcDB.GetNpcName(entityID)) then
											RSLogger:PrintMessage(string.format(AL["EXPLORER_AUTOFILTER"], RSNpcDB.GetNpcName(entityID)))
										end
									elseif (source == RSConstants.ITEM_SOURCE.CONTAINER) then
										RSConfigDB.SetContainerFiltered(entityID)
										RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedPet[%s]: Filtrado Contenedor [%s] por no disponer de mas coleccionables.", petGUID, entityID))
										if (RSContainerDB.GetContainerName(entityID)) then
											RSLogger:PrintMessage(string.format(AL["EXPLORER_AUTOFILTER"], RSContainerDB.GetContainerName(entityID)))
										end
									end
								end
							end
							
							refresh = true
							break
						end
					end
				end
			end
		end
		
		if (refresh and callback) then
			callback()
		end
    end
end

---============================================================================
-- Mounts
---============================================================================

local function UpdateNotCollectedMountIDs(routines, routineTextOutput)
	-- Backup settings
	local colletedFilter = C_MountJournal.GetCollectedFilterSetting(LE_MOUNT_JOURNAL_FILTER_NOT_COLLECTED)
	local notColletedFilter = C_MountJournal.GetCollectedFilterSetting(LE_MOUNT_JOURNAL_FILTER_NOT_COLLECTED)
	local notUnusableFilter = C_MountJournal.GetCollectedFilterSetting(LE_MOUNT_JOURNAL_FILTER_UNUSABLE)
	
	-- Prepare filters
	C_MountJournal.SetCollectedFilterSetting(LE_MOUNT_JOURNAL_FILTER_COLLECTED, false);
	C_MountJournal.SetCollectedFilterSetting(LE_MOUNT_JOURNAL_FILTER_NOT_COLLECTED, true);
	C_MountJournal.SetCollectedFilterSetting(LE_MOUNT_JOURNAL_FILTER_UNUSABLE, true);
	C_MountJournal.SetSearch("");
	C_MountJournal.SetAllSourceFilters(true)
	C_MountJournal.SetAllTypeFilters(true)
	
	private.dbglobal.not_colleted_mounts_ids = {}
		
	-- Query
	local notCollectedMountIDs = RSRoutines.LoopIndexRoutineNew()
	notCollectedMountIDs:Init(
		C_MountJournal.GetNumMounts,
		function(context, i)
			local name, _, _, _, _, _, _, _, _, _, _, mountID = C_MountJournal.GetDisplayedMountInfo(i);
			if (mountID) then
				private.dbglobal.not_colleted_mounts_ids[mountID] = true
				context.counter = (context.counter or 0) + 1
			end
		end,
		function(context)			
			-- Recover settings
			C_MountJournal.SetCollectedFilterSetting(LE_MOUNT_JOURNAL_FILTER_COLLECTED, colletedFilter);
			C_MountJournal.SetCollectedFilterSetting(LE_MOUNT_JOURNAL_FILTER_NOT_COLLECTED, notColletedFilter);
			C_MountJournal.SetCollectedFilterSetting(LE_MOUNT_JOURNAL_FILTER_UNUSABLE, notUnusableFilter);
			
			-- Process hidden mounts
			for _, mountID in ipairs (private.HIDDEN_MOUNT_IDS) do
				local name, _, _, _, _, _, _, _, _, _, isCollected, _ = C_MountJournal.GetMountInfoByID(mountID)
				if (not isCollected) then
					private.dbglobal.not_colleted_mounts_ids[mountID] = true
					context.counter = (context.counter or 0) + 1
				end
			end
			
			RSLogger:PrintDebugMessage(string.format("UpdateNotCollectedMountIDs. [%s no conseguidas].", context.counter or 0))
			
			if (routineTextOutput) then
				routineTextOutput:SetText(string.format(AL["EXPLORER_MISSING_MOUNTS"], context.counter or 0))
			end
		end
	)
	table.insert(routines, notCollectedMountIDs)
end

local function GetNotCollectedMountsIDs()
	return private.dbglobal.not_colleted_mounts_ids
end

local function GetMountItemID(mountID)
	if (mountID) then
		return private.DROPPED_MOUNT_IDS[mountID]
	end
	
	return nil
end

local function GetMountID(itemID)
	if (itemID) then
		for mountID, internalItemID in pairs(private.DROPPED_MOUNT_IDS) do
			if (RSUtils.Contains(internalItemID, itemID)) then
				return mountID
			end
		end
	end
	
	return nil
end

local function CheckUpdateMount(itemID, entityID, source, checkedItems)
	-- If cached use it
	if (checkedItems[RSConstants.ITEM_TYPE.MOUNT][itemID]) then
		UpdateEntityCollection(itemID, entityID, source, RSConstants.ITEM_TYPE.MOUNT)
		return true
	else
		local mountID = GetMountID(itemID)
		if (mountID) then		
			local notCollectedMountsIDs = GetNotCollectedMountsIDs()
			if (notCollectedMountsIDs and notCollectedMountsIDs[mountID]) then
				UpdateEntityCollection(itemID, entityID, source, RSConstants.ITEM_TYPE.MOUNT)
				checkedItems[RSConstants.ITEM_TYPE.MOUNT][itemID] = true
				return true
			end
		end
		
		return false
	end
end

function RSCollectionsDB.RemoveNotCollectedMount(mountID, callback) --NEW_MOUNT_ADDED
	local notCollectedMountsIDs = GetNotCollectedMountsIDs()
	if (mountID and notCollectedMountsIDs) then
		RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedMount[%s]", mountID))
	
		-- Drop missing mount
		if (notCollectedMountsIDs[mountID]) then
			notCollectedMountsIDs[mountID] = nil
			RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedMount[%s]: Eliminado coleccionable conseguido.", mountID))
		end
		
		-- Update filters
		local allEntitiesCollectionsLoot = RSCollectionsDB.GetAllEntitiesCollectionsLoot()
		if (not allEntitiesCollectionsLoot) then
			return
		end
		
		local refresh = false
		for source, entities in pairs (allEntitiesCollectionsLoot) do
			for entityID, itemTypes in pairs (entities) do
				local lootList = itemTypes[RSConstants.ITEM_TYPE.MOUNT]
				if (lootList) then
					for i = #lootList, 1, -1 do
						if (RSUtils.Contains(GetMountItemID(mountID), lootList[i])) then
							if (#lootList == 1) then
								RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedMount[%s]: Eliminado coleccionable de la lista de la entidad [%s]. No tiene mas monturas.", mountID, entityID))
								itemTypes[RSConstants.ITEM_TYPE.MOUNT] = nil
							else
								RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedMount[%s]: Eliminado coleccionable de la lista de la entidad [%s].", mountID, entityID))
								table.remove(lootList, i)
							end
							
							-- Check if the entity doesn't have more collections
							if (RSUtils.GetTableLength(itemTypes) == 0) then
								entities[entityID] = nil
								
								-- Filter
								if (RSConfigDB.IsAutoFilteringOnCollect()) then
									if (source == RSConstants.ITEM_SOURCE.NPC) then
										RSConfigDB.SetNpcFiltered(entityID)
										RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedMount[%s]: Filtrado NPC [%s] por no disponer de mas coleccionables.", mountID, entityID))
										if (RSNpcDB.GetNpcName(entityID)) then
											RSLogger:PrintMessage(string.format(AL["EXPLORER_AUTOFILTER"], RSNpcDB.GetNpcName(entityID)))
										end
									elseif (source == RSConstants.ITEM_SOURCE.CONTAINER) then
										RSConfigDB.SetContainerFiltered(entityID)
										RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedMount[%s]: Filtrado Contenedor [%s] por no disponer de mas coleccionables.", mountID, entityID))
										if (RSContainerDB.GetContainerName(entityID)) then
											RSLogger:PrintMessage(string.format(AL["EXPLORER_AUTOFILTER"], RSContainerDB.GetContainerName(entityID)))
										end
									end
								end
							end
							
							refresh = true
							break
						end
					end
				end
			end
		end
		
		if (refresh and callback) then
			callback()
		end
    end
end

---============================================================================
-- Appearances
---============================================================================

local function AddAppearanceClassItemID(classID, itemID)
	if (not private.dbglobal.classes_appearances_item_id) then
		private.dbglobal.classes_appearances_item_id = {}
	else
		-- Clean if old format
		local _, firstValue = next(private.dbglobal.classes_appearances_item_id)
        if (type(firstValue) == "table") then
            private.dbglobal.classes_appearances_item_id = {}
            RSLogger:PrintDebugMessage("Limpiada tabla classes_appearances_item_id por cambio de formato a Bitmask.")
        end
	end
	
	local currentMask = private.dbglobal.classes_appearances_item_id[itemID] or 0
	local classMask = CLASS_MASKS[classID] or 0
	
	-- Guardamos directamente el bit sumado para la clave del itemID (0 duplicaciones)
	private.dbglobal.classes_appearances_item_id[itemID] = bit.bor(currentMask, classMask)
end

local function DropAppearanceClassItemID(classID, itemID)
	if (private.dbglobal.classes_appearances_item_id and private.dbglobal.classes_appearances_item_id[itemID]) then
		local currentMask = private.dbglobal.classes_appearances_item_id[itemID]
		local classMask = CLASS_MASKS[classID] or 0
		
		local newMask = bit.band(currentMask, bit.bnot(classMask))
		if (newMask == 0) then
			private.dbglobal.classes_appearances_item_id[itemID] = nil
		else
			private.dbglobal.classes_appearances_item_id[itemID] = newMask
		end
	end
end

local function AddAppearanceItemID(appearanceID, itemID, isDrop)
	if (not private.dbglobal.appearances_item_id) then
		private.dbglobal.appearances_item_id = {}
	end
	
	if (not private.dbglobal.appearances_item_id[appearanceID]) then
		private.dbglobal.appearances_item_id[appearanceID] = {}
	end
	
	if (not RSUtils.Contains(private.dbglobal.appearances_item_id[appearanceID], itemID)) then
		table.insert(private.dbglobal.appearances_item_id[appearanceID], itemID)
	end

	if (isDrop) then
		if (not private.dbglobal.item_appearances_drops) then
			private.dbglobal.item_appearances_drops = {}
		end

		if (not private.dbglobal.item_appearances_drops[itemID]) then
			private.dbglobal.item_appearances_drops[itemID] = {}
		end
		
		private.dbglobal.item_appearances_drops[itemID][appearanceID] = true
	end
end

local function DropAppearanceItemID(appearanceID, itemID)
	if (private.dbglobal.appearances_item_id and private.dbglobal.appearances_item_id[appearanceID]) then
		local itemsTable = private.dbglobal.appearances_item_id[appearanceID]
		
		for i = #itemsTable, 1, -1 do
			if (itemsTable[i] == itemID) then
				table.remove(itemsTable, i)
			end
		end
		
		if (#itemsTable == 0) then
			private.dbglobal.appearances_item_id[appearanceID] = nil
		end
	end

	if (private.dbglobal.item_appearances_drops and private.dbglobal.item_appearances_drops[itemID]) then
		private.dbglobal.item_appearances_drops[itemID][appearanceID] = nil

		if (not next(private.dbglobal.item_appearances_drops[itemID])) then
			private.dbglobal.item_appearances_drops[itemID] = nil
		end
	end
end

local function GetNotCollectedAppearanceItemIDs()
	return private.dbglobal.not_colleted_appearances_item_ids
end

local function DropNotCollectedAppearance(appearanceID)
	if (not appearanceID or not private.dbglobal.appearances_item_id) then 
		return false 
	end

	local itemIDs = private.dbglobal.appearances_item_id[appearanceID]
	if (not itemIDs) then 
		return false 
	end

	local notCollectedItems = GetNotCollectedAppearanceItemIDs()
	if (notCollectedItems) then
		local classesAppearances = private.dbglobal.classes_appearances_item_id
		for _, itemID in ipairs(itemIDs) do
			if (notCollectedItems[itemID]) then
				RSLogger:PrintDebugMessage(string.format("DropNotCollectedAppearance[%s]. Eliminado item [%s].", appearanceID, itemID))
				notCollectedItems[itemID] = nil
				
				-- Limpiamos la máscara de clase si existe
				if (classesAppearances) then
					classesAppearances[itemID] = nil
				end
			end

			if (private.dbglobal.item_appearances_drops and private.dbglobal.item_appearances_drops[itemID]) then
				private.dbglobal.item_appearances_drops[itemID][appearanceID] = nil
				if (not next(private.dbglobal.item_appearances_drops[itemID])) then
					private.dbglobal.item_appearances_drops[itemID] = nil
				end
			end
		end
	end

	-- Eliminamos el registro de la apariencia
	private.dbglobal.appearances_item_id[appearanceID] = nil
	RSLogger:PrintDebugMessage(string.format("DropNotCollectedAppearance[%s]. Eliminada apariencia.", appearanceID))

	return true
end

local function GetAppearanceItemIDs(appearanceID)
	if (private.dbglobal.appearances_item_id) then
		return private.dbglobal.appearances_item_id[appearanceID]
	end
	
	return nil
end

local function UpdateNotCollectedAppearanceItemIDs(routines, routineTextOutput)
	private.dbglobal.not_colleted_appearances_item_ids = {}
	private.dbglobal.item_appearances_drops = {}
	
	-- Prepare filters
	C_TransmogCollection.SetUncollectedShown(true);
	C_TransmogCollection.SetAllFactionsShown(true);
	C_TransmogCollection.SetAllRacesShown(true);
	C_TransmogCollection.SetSearch(Enum.TransmogSearchType.Items, "");
	
	-- Query
	local slotGroupInfo = C_TransmogOutfitInfo.GetSlotGroupInfo()
	for _, groupData in pairs(slotGroupInfo) do
		for _, appearanceInfo in ipairs(groupData.appearanceSlotInfo) do
			local transmogLocation = TransmogUtil.GetTransmogLocation(appearanceInfo.slotName, appearanceInfo.type, appearanceInfo.isSecondary);
			
			for _, categoryID in ipairs (TRANSMOG_LOCATIONS[appearanceInfo.slotName]) do
				local visualsList = C_TransmogCollection.GetCategoryAppearances(categoryID, transmogLocation)
				
				-- Appearances hidden in the collections tab
				if (private.MISSING_SOURCES[categoryID]) then
					local notCollectedAppearanceItemIDs = RSRoutines.LoopIndexRoutineNew()
					notCollectedAppearanceItemIDs:Init(
						function() return private.MISSING_SOURCES[categoryID] end,
						function(context, i)
							if (not context.counter) then
								context.counter = 0
							end
							
							local visualItemID = private.MISSING_SOURCES[context.arguments[1]][i]
							local sVisualID, sItemID = strsplit(";",visualItemID)
							
							local visualID = tonumber(sVisualID)
							local itemID = tonumber(sItemID)
								
							if (visualsList) then
								local collected = false
								local inVisualList = false
								for j = 1, #visualsList do
									if (visualsList[j].visualID == visualID and visualsList[j].isCollected) then
										collected = true
										inVisualList = true
										break
									end	
								end
								
								if (not collected and not C_TransmogCollection.PlayerHasTransmog(itemID, visualID)) then	
									context.counter = context.counter + 1
									AddAppearanceItemID(visualID, itemID, true)
								
									if (not private.dbglobal.not_colleted_appearances_item_ids[itemID]) then
										private.dbglobal.not_colleted_appearances_item_ids[itemID] = true
									end
									
									-- Some items show up as not collected but they are, so if it wasnt in the visuallist check the tooltip
									if (not inVisualList) then
										local item = Item:CreateFromItemID(itemID)
										item:ContinueOnItemLoad(function()
											if (not RSTooltipScanners.ScanLoot(item:GetItemLink(), TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN)) then
												DropNotCollectedAppearance(visualID)
											end
										end)
									end
								end
							end
						end,
						function(context)
							local name, _, _, _, _ = C_TransmogCollection.GetCategoryInfo(context.arguments[1])
							if (not name) then
								for categoryName, categoryID in pairs(Enum.TransmogCollectionType) do
									if (categoryID == context.arguments[1]) then
										name = categoryName
										break;
									end
								end
							end
							RSLogger:PrintDebugMessage(string.format("UpdateNotCollectedAppearanceItemIDs. [%s] [%s no conseguidas (ocultas)].", name, context.counter or "0"))
						
							if (routineTextOutput) then
								--routineTextOutput:SetText(string.format(AL["EXPLORER_MISSING_APPEARANCES"], context.counter or "0", name))
							end
						end,
						categoryID
					)
					table.insert(routines, notCollectedAppearanceItemIDs)
				end
				
				-- Appearances shown in the collections tab
				if (visualsList) then
				    local notCollectedAppearanceItemIDs = RSRoutines.LoopIndexRoutineNew()
				    notCollectedAppearanceItemIDs:Init(
				    	C_TransmogCollection.GetCategoryAppearances,
				        function(context, j)
				            if (not context.counter) then
				                context.counter = 0
				            end
				            
				            if (not context.processedCollected) then
				                context.processedCollected = {}
				            end
				            
				            if (visualsList[j]) then
				                local currentVisualID = visualsList[j].visualID
				                local previousVisualID
				                
				                -- Check if globally collected
				                local isCollectedByAnyClass = false
				                for classID = 1, GetNumClasses() do
				                    local sources = C_TransmogCollection.GetValidAppearanceSourcesForClass(currentVisualID, classID, context.arguments[1], context.arguments[2]);
				                    if (sources) then
				                        for k = 1, #sources do
				                            if (sources[k].isCollected) then
				                                isCollectedByAnyClass = true
				                                break
				                            end
				                        end
				                    end
				                    if (isCollectedByAnyClass) then 
				                    	break 
				                    end
				                end
				                
				                -- Process appearance
				                for classID = 1, GetNumClasses() do
				                    local sources = C_TransmogCollection.GetValidAppearanceSourcesForClass(currentVisualID, classID, context.arguments[1], context.arguments[2]);
				                    if (sources) then
				                        if (not isCollectedByAnyClass) then
				                        	-- Not collected
				                            for k = 1, #sources do
				                                local itemID = sources[k].itemID
				                                local sourceType = sources[k].sourceType
				                                
				                                --1#Boss Drop/3#Vendor/4#World drop
			                                    if (sourceType == 1 or sourceType == 3 or sourceType == 4) then
			                                        if (not GetAppearanceItemIDs(sources[k].visualID) or not RSUtils.Contains(GetAppearanceItemIDs(sources[k].visualID), itemID)) then
			                                            local isDrop = (sourceType == 1 or sourceType == 4)
			                                            AddAppearanceItemID(sources[k].visualID, itemID, isDrop)
			                                        end
				                                        
			                                    	local key = itemID .. "_" .. classID
													if (not context.processedCollected[key]) then
														if (not previousVisualID or previousVisualID ~= sources[k].visualID) then
															context.counter = context.counter + 1
															previousVisualID = sources[k].visualID
														end
														
														AddAppearanceClassItemID(classID, itemID)
													
														if (not private.dbglobal.not_colleted_appearances_item_ids[itemID]) then
															private.dbglobal.not_colleted_appearances_item_ids[itemID] = true
														end
													
														context.processedCollected[key] = previousVisualID
													end
			                                    end
				                            end
				                        else
				                            -- Collected
				                            for k = 1, #sources do
										        local itemID = sources[k].itemID
										        local sourceType = sources[k].sourceType
										        
										        if (sourceType == 1 or sourceType == 3 or sourceType == 4) then
													-- Avoids deleting the itemID if the current appearance's source is a vendor and the item has a different appearance with drop source
										            local isDrop = (sourceType == 1 or sourceType == 4)
										            local shouldClean = false

										            if (isDrop) then
										                shouldClean = true
										            elseif (sourceType == 3) then
										                local hasPendingDrop = private.dbglobal.item_appearances_drops 
										                    and private.dbglobal.item_appearances_drops[itemID] 
										                    and next(private.dbglobal.item_appearances_drops[itemID]) ~= nil
										                
										                shouldClean = not hasPendingDrop
										            end

										            if (shouldClean) then
										                if (private.dbglobal.not_colleted_appearances_item_ids[itemID]) then
										                    private.dbglobal.not_colleted_appearances_item_ids[itemID] = nil
										                    DropAppearanceItemID(currentVisualID, itemID)
										                end
										                
										                DropAppearanceClassItemID(classID, itemID)
										            end
										        end
										    end
				                        end
				                    end
				                end
				            end
				        end,
				        function(context)                             
				            local name, _, _, _, _ = C_TransmogCollection.GetCategoryInfo(context.arguments[1])
				            if (not name) then
				                for categoryName, categoryID in pairs(Enum.TransmogCollectionType) do
				                    if (categoryID == context.arguments[1]) then
				                        name = categoryName
				                        break;
				                    end
				                end
				            end
				            RSLogger:PrintDebugMessage(string.format("UpdateNotCollectedAppearanceItemIDs. [%s] [%s no conseguidas].", name, context.counter or "0"))
				            
				            if (routineTextOutput) then
				                routineTextOutput:SetText(string.format(AL["EXPLORER_MISSING_APPEARANCES"], context.counter or "0", name))
				            end
				            
				            context.processedCollected = nil
				        end,
				        categoryID,
				        transmogLocation:GetData()
				    )
				    table.insert(routines, notCollectedAppearanceItemIDs)
				end
			end
		end
	end
end

local function CheckUpdateAppearance(itemID, entityID, source, checkedItems)
	-- If cached use it
	if (checkedItems[RSConstants.ITEM_TYPE.APPEARANCE][itemID]) then
		UpdateEntityCollection(itemID, entityID, source, RSConstants.ITEM_TYPE.APPEARANCE)
		
		return true
	-- Otherwise query
	else				
		local notCollectedAppearanceItemIDs = GetNotCollectedAppearanceItemIDs()
		if (notCollectedAppearanceItemIDs and notCollectedAppearanceItemIDs[itemID]) then
			UpdateEntityCollection(itemID, entityID, source, RSConstants.ITEM_TYPE.APPEARANCE)
			
			if (not checkedItems[RSConstants.ITEM_TYPE.APPEARANCE][itemID]) then
				checkedItems[RSConstants.ITEM_TYPE.APPEARANCE][itemID] = true
			end
			
			return true
		end
		
		return false
	end
end

function RSCollectionsDB.IsNotCollectedClassAppearance(itemID)
	local notCollectedAppearanceItemIDs = GetNotCollectedAppearanceItemIDs()
	if (not notCollectedAppearanceItemIDs) then
		return false
	end
	
	if (not private.dbglobal.classes_appearances_item_id) then
		return false
	end
	
	local itemMask = private.dbglobal.classes_appearances_item_id[itemID]
	
	if (not itemMask) then
		-- If missing item that doesn't show up in the collections tab
		if (notCollectedAppearanceItemIDs[itemID] and PlayerCanUseItem(itemID)) then
			return true
		end
	
		return false
	end
	
	-- Comprobación con operación a nivel de Bit (bitwise bit.band)
	local classMask = CLASS_MASKS[playerClassIndex] or 0
	if (bit.band(itemMask, classMask) ~= 0) then
		return true
	end
	
	return false
end

function RSCollectionsDB.IsNotcollectedAppearance(itemID)
	local notCollectedAppearanceItemIDs = GetNotCollectedAppearanceItemIDs()
	if (not notCollectedAppearanceItemIDs) then
		return false
	end
	
	if (notCollectedAppearanceItemIDs[itemID]) then
		return true
	end
	
	return false
end

local removeAppearanceQueue = {}
local isRemovingAppearance = false
local pendingRemoveApperanceCallback = nil
local hasRemovedAnyApperance = false

local function RemoveNextAppearance()
	if (#removeAppearanceQueue == 0) then
		isRemovingAppearance = false
		
		-- Invoque callback at the end of the queue
		if (hasRemovedAnyApperance and pendingRemoveApperanceCallback) then
			local callback = pendingRemoveApperanceCallback
			callback()
		end
		
		pendingRemoveApperanceCallback = nil
		hasRemovedAnyApperance = false
		
		return
	end

	isRemovingAppearance = true
	local appearanceID = table.remove(removeAppearanceQueue, 1)

	local appearanceItems = GetAppearanceItemIDs(appearanceID)
	if (not appearanceItems or #appearanceItems == 0) then
		RemoveNextAppearance()
		return
	end

	RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedAppearance[%s]", appearanceID))

	local allLoot = RSCollectionsDB.GetAllEntitiesCollectionsLoot()
	if (not allLoot) then
		RemoveNextAppearance()
		return
	end

	local routines = {}

	-- Update missing apperances	
	for source, entities in pairs(allLoot) do
		local entityScanRoutine = RSRoutines.LoopRoutineNew()
		entityScanRoutine:Init(
			entities,
			function(context, entityID, entityLoot)
				local lootList = entityLoot[RSConstants.ITEM_TYPE.APPEARANCE]
				
				if (lootList and #lootList > 0) then
					local lootRoutine = RSRoutines.InvertedLoopIndexRoutineNew()
					lootRoutine:Init(
						lootList,
						function(lootContext, i)
							if (RSUtils.Contains(appearanceItems, lootList[i])) then
								if (#lootList == 1) then
									RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedAppearance[%s]: Eliminado coleccionable [%s] de la lista de la entidad [%s]. No tiene mas apariencias.", appearanceID, lootList[i], entityID))
									entityLoot[RSConstants.ITEM_TYPE.APPEARANCE] = nil
								else
									RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedAppearance[%s]: Eliminado coleccionable [%s] de la lista de la entidad [%s].", appearanceID, lootList[i], entityID))
									table.remove(lootList, i)
								end

								-- Check if the entity doesn't have more collectibles
								if (RSUtils.GetTableLength(entityLoot) == 0) then
									entities[entityID] = nil

									-- Auto-filter
									if (RSConfigDB.IsAutoFilteringOnCollect()) then
										if (source == RSConstants.ITEM_SOURCE.NPC) then
											RSConfigDB.SetNpcFiltered(entityID)
											RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedAppearance[%s]: Filtrado NPC [%s] por no disponer de mas coleccionables.", appearanceID, entityID))
											if (RSNpcDB.GetNpcName(entityID)) then
												RSLogger:PrintMessage(string.format(AL["EXPLORER_AUTOFILTER"], RSNpcDB.GetNpcName(entityID)))
											end
										elseif (source == RSConstants.ITEM_SOURCE.CONTAINER) then
											RSConfigDB.SetContainerFiltered(entityID)
											RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedAppearance[%s]: Filtrado Contenedor [%s] por no disponer de mas coleccionables.", appearanceID, entityID))
											if (RSContainerDB.GetContainerName(entityID)) then
												RSLogger:PrintMessage(string.format(AL["EXPLORER_AUTOFILTER"], RSContainerDB.GetContainerName(entityID)))
											end
										end
									end
								end
							end
						end
					)
					
					tinsert(routines, lootRoutine)
				end
			end
		)
		
		tinsert(routines, entityScanRoutine)
	end

	local chainRoutines = RSRoutines.ChainLoopRoutineNew()
	chainRoutines:Init(routines)
	chainRoutines:Run(function(context)
		-- Drops not collected appearance
		local dropped = DropNotCollectedAppearance(appearanceID)
		if (dropped) then
			hasRemovedAnyApperance = true
		end
		
		-- Process next remove
		RemoveNextAppearance()
	end)
end

function RSCollectionsDB.RemoveNotCollectedAppearance(appearanceID, callback) --TRANSMOG_COLLECTION_UPDATED
	if (not appearanceID) then return end

	-- Queue
	if (not RSUtils.Contains(removeAppearanceQueue, appearanceID)) then
		tinsert(removeAppearanceQueue, appearanceID)
	end

	-- The callback is the same for all the calls, only invoke it once at the end
	if (callback) then
		pendingRemoveApperanceCallback = callback
	end

	-- Only execute if not running
	if (not isRemovingAppearance) then
		RemoveNextAppearance()
	end
end

---============================================================================
-- Drakewatcher manuscripts
---============================================================================

local function UpdateNotCollectedDrakewatchers(routines, routineTextOutput)
	private.dbglobal.not_colleted_drakewatchers = {}
	
	-- Query
	local notCollectedDrakewatcherRoutine = RSRoutines.LoopRoutineNew()
	notCollectedDrakewatcherRoutine:Init(
		function() return private.DRAKEWATCHER_QUESTS end,
		function(context, itemID, questIDs)
			for _, questID in ipairs(questIDs) do
				if (not C_QuestLog.IsQuestFlaggedCompleted(questID)) then
					private.dbglobal.not_colleted_drakewatchers[itemID] = true
					context.counter = (context.counter or 0) + 1
				end
			end
		end, 
		function(context)	
			RSLogger:PrintDebugMessage(string.format("UpdateNotCollectedDrakewatchers. [%s no conseguidos].", context.counter or 0))		
			if (routineTextOutput) then
				routineTextOutput:SetText(string.format(AL["EXPLORER_MISSING_DRAKEWATCHER"], context.counter or 0))
			end
		end
	)
	table.insert(routines, notCollectedDrakewatcherRoutine)
end

local function GetNotCollectedDrakewatchers()
	return private.dbglobal.not_colleted_drakewatchers
end

local function CheckUpdateDrakewatcher(itemID, entityID, source, checkedItems)
	-- If cached use it
	if (checkedItems[RSConstants.ITEM_TYPE.DRAKEWATCHER][itemID]) then
		UpdateEntityCollection(itemID, entityID, source, RSConstants.ITEM_TYPE.DRAKEWATCHER)
		return true
	else
		local notCollectedDrakewatchers = GetNotCollectedDrakewatchers()
		if (notCollectedDrakewatchers and notCollectedDrakewatchers[itemID]) then
			UpdateEntityCollection(itemID, entityID, source, RSConstants.ITEM_TYPE.DRAKEWATCHER)
			checkedItems[RSConstants.ITEM_TYPE.DRAKEWATCHER][itemID] = true
			return true
		end
	
		return false
	end
end

function RSCollectionsDB.RemoveNotCollectedDrakewatcher(spellID, callback) --UNIT_SPELLCAST_SUCCEEDED
	local notCollectedDrakewatchers = GetNotCollectedDrakewatchers()
	if (spellID and notCollectedDrakewatchers and private.DRAKEWATCHER_SPELLS[spellID]) then		
		-- Drop missing drakewatcher manuscript
		local itemID = private.DRAKEWATCHER_SPELLS[spellID]
		if (notCollectedDrakewatchers[itemID]) then
			notCollectedDrakewatchers[itemID] = nil
			RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedDrakewatcher[%s]: Eliminado Manuscrito de dracovigía conseguido.", itemID))
		end
		
		-- Update filters
		local allEntitiesCollectionsLoot = RSCollectionsDB.GetAllEntitiesCollectionsLoot()
		if (not allEntitiesCollectionsLoot) then
			return
		end
		
		local refresh = false
		for source, entities in pairs (allEntitiesCollectionsLoot) do
			for entityID, itemTypes in pairs (entities) do
				local lootList = itemTypes[RSConstants.ITEM_TYPE.DRAKEWATCHER]
				if (lootList) then
					for i = #lootList, 1, -1 do
						if (lootList[i] == itemID) then
							if (#lootList == 1) then
								RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedDrakewatcher[%s]: Eliminado coleccionable de la lista de la entidad [%s]. No tiene mas manuscritos.", itemID, entityID))
								itemTypes[RSConstants.ITEM_TYPE.DRAKEWATCHER] = nil
							else
								RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedDrakewatcher[%s]: Eliminado coleccionable de la lista de la entidad [%s].", itemID, entityID))
								table.remove(lootList, i)
							end
							
							-- Check if the entity doesn't have more collections
							if (RSUtils.GetTableLength(itemTypes) == 0) then
								entities[entityID] = nil
								
								-- Filter
								if (RSConfigDB.IsAutoFilteringOnCollect()) then
									if (source == RSConstants.ITEM_SOURCE.NPC) then
										RSConfigDB.SetNpcFiltered(entityID)
										RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedDrakewatcher[%s]: Filtrado NPC [%s] por no disponer de mas coleccionables.", itemID, entityID))
										if (RSNpcDB.GetNpcName(entityID)) then
											RSLogger:PrintMessage(string.format(AL["EXPLORER_AUTOFILTER"], RSNpcDB.GetNpcName(entityID)))
										end
									elseif (source == RSConstants.ITEM_SOURCE.CONTAINER) then
										RSConfigDB.SetContainerFiltered(entityID)
										RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedDrakewatcher[%s]: Filtrado Contenedor [%s] por no disponer de mas coleccionables.", itemID, entityID))
										if (RSContainerDB.GetContainerName(entityID)) then
											RSLogger:PrintMessage(string.format(AL["EXPLORER_AUTOFILTER"], RSContainerDB.GetContainerName(entityID)))
										end
									end
								end
							end
							
							refresh = true
							break
						end
					end
				end
			end
		end
		
		if (refresh and callback) then
			callback()
		end
    end
end

---============================================================================
-- Decor / Housing
---============================================================================

local function UpdateNotCollectedDecors(routines, routineTextOutput, catalogSearcherCallback)
	-- Searcher
	local searcher = C_HousingCatalog.CreateCatalogSearcher()
	
	-- Prepare filters
	searcher:SetAllowedIndoors(true)
	searcher:SetAllowedOutdoors(true)
	searcher:SetCollected(false)
	searcher:SetCustomizableOnly(false)
	searcher:SetFirstAcquisitionBonusOnly(false)
	searcher:SetOwnedOnly(false)
	searcher:SetSearchText("")
	searcher:SetUncollected(true)
	
	-- Run searcher
	searcher:SetResultsUpdatedCallback(function()
		local catalogSearchResults = searcher:GetCatalogSearchResults()
	    
	    private.dbglobal.not_colleted_decors = {}
	    if (not private.dbglobal.decors_items_ids) then
	    	private.dbglobal.decors_items_ids = {}
	    end
	    
		-- Query
		local notCollectedDecorRoutine = RSRoutines.LoopIndexRoutineNew()
		notCollectedDecorRoutine:Init(
			function() return catalogSearchResults end,
			function(context, i)
				local entryID = catalogSearchResults[i]
				local info = C_HousingCatalog.GetCatalogEntryInfo(entryID)
        		if (info and info.itemID) then
					private.dbglobal.not_colleted_decors[info.itemID] = true
					private.dbglobal.decors_items_ids[entryID.recordID] = info.itemID
					context.counter = (context.counter or 0) + 1
				end
			end,
			function(context)				
				RSLogger:PrintDebugMessage(string.format("UpdateNotCollectedDecors. [%s no conseguidos].", context.counter or 0))
				
				if (routineTextOutput) then
					routineTextOutput:SetText(string.format(AL["EXPLORER_MISSING_DECORS"], context.counter or 0))
				end
			end
		)
		table.insert(routines, notCollectedDecorRoutine)
		
		-- Callback
		catalogSearcherCallback()
	end)
	
	-- With this timer the callback SetResultsUpdatedCallback is actually called, otherwise it isn't after login into the game (only after reloading)
	C_Timer.After(1, function() searcher:RunSearch() end)
end

local function GetNotCollectedDecors()
	return private.dbglobal.not_colleted_decors
end

local function GetDecorItemID(decorID)
	if (decorID and private.dbglobal.decors_items_ids) then
		return private.dbglobal.decors_items_ids[decorID]
	end
	
	return nil
end

local function CheckUpdateDecor(itemID, entityID, source, checkedItems)
	-- If cached use it
	if (checkedItems[RSConstants.ITEM_TYPE.DECOR][itemID]) then
		UpdateEntityCollection(itemID, entityID, source, RSConstants.ITEM_TYPE.DECOR)
		return true
	else
		local notCollectedDecors = GetNotCollectedDecors()
		if (notCollectedDecors and notCollectedDecors[itemID]) then
			UpdateEntityCollection(itemID, entityID, source, RSConstants.ITEM_TYPE.DECOR)
			checkedItems[RSConstants.ITEM_TYPE.DECOR][itemID] = true
			return true
		end
	
		return false
	end
end

function RSCollectionsDB.RemoveNotCollectedDecor(decorID, callback) --HOUSE_DECOR_ADDED_TO_CHEST
	local notCollectedDecors = GetNotCollectedDecors()
	if (decorID and notCollectedDecors) then
		-- Get decor itemID
		local itemID = GetDecorItemID(decorID)
		if (not itemID) then
			return
		end
		
		-- Drop missing decor
		if (notCollectedDecors[itemID]) then
			notCollectedDecors[itemID] = nil
			RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedDecor[%s]: Eliminado coleccionable conseguido.", itemID))
		end
		
		-- Update filters
		local allEntitiesCollectionsLoot = RSCollectionsDB.GetAllEntitiesCollectionsLoot()
		if (not allEntitiesCollectionsLoot) then
			return
		end
		
		local refresh = false
		for source, entities in pairs (allEntitiesCollectionsLoot) do
			for entityID, itemTypes in pairs (entities) do
				local lootList = itemTypes[RSConstants.ITEM_TYPE.DECOR]
				if (lootList) then
					for i = #lootList, 1, -1 do
						if (lootList[i] == itemID) then
							if (#lootList == 1) then
								RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedDecor[%s]: Eliminado coleccionable de la lista de la entidad [%s]. No tiene mas decoraciones.", itemID, entityID))
								itemTypes[RSConstants.ITEM_TYPE.DECOR] = nil
							else
								RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedDecor[%s]: Eliminado coleccionable de la lista de la entidad [%s].", itemID, entityID))
								table.remove(lootList, i)
							end
							
							-- Check if the entity doesn't have more collections
							if (RSUtils.GetTableLength(itemTypes) == 0) then
								entities[entityID] = nil
								
								-- Filter
								if (RSConfigDB.IsAutoFilteringOnCollect()) then
									if (source == RSConstants.ITEM_SOURCE.NPC) then
										RSConfigDB.SetNpcFiltered(entityID)
										RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedDecor[%s]: Filtrado NPC [%s] por no disponer de mas coleccionables.", itemID, entityID))
										if (RSNpcDB.GetNpcName(entityID)) then
											RSLogger:PrintMessage(string.format(AL["EXPLORER_AUTOFILTER"], RSNpcDB.GetNpcName(entityID)))
										end
									elseif (source == RSConstants.ITEM_SOURCE.CONTAINER) then
										RSConfigDB.SetContainerFiltered(entityID)
										RSLogger:PrintDebugMessage(string.format("RemoveNotCollectedDecor[%s]: Filtrado Contenedor [%s] por no disponer de mas coleccionables.", itemID, entityID))
										if (RSContainerDB.GetContainerName(entityID)) then
											RSLogger:PrintMessage(string.format(AL["EXPLORER_AUTOFILTER"], RSContainerDB.GetContainerName(entityID)))
										end
									end
								end
							end
							
							refresh = true
							break
						end
					end
				end
			end
		end
		
		if (refresh and callback) then
			callback()
		end
    end
end

---============================================================================
-- Custom items
---============================================================================

function RSCollectionsDB.GetItemGroups()
	if (not private.dbglobal.explorer_item_groups) then
		private.dbglobal.explorer_item_groups = {}
	end
	
	if (RSUtils.GetTableLength(private.dbglobal.explorer_item_groups) == 0) then
		RSCollectionsDB.AddItemGroup(AL["EXPLORER_CUSTOM_ITEMS_GROUP_DEFAULT"])
	end
	
	return private.dbglobal.explorer_item_groups
end

function RSCollectionsDB.SetGroupName(groupKey, value)
	if (value and strtrim(value) ~= '' and groupKey and private.dbglobal.explorer_item_groups and private.dbglobal.explorer_item_groups[groupKey]) then
		-- Ignore if already exists
		for _, v in pairs (private.dbglobal.explorer_item_groups) do
			if (value == v) then
				return
			end
		end
		
		private.dbglobal.explorer_item_groups[groupKey] = strtrim(value)
	end
end

function RSCollectionsDB.GetGroupKeyByName(groupName)
	if (private.dbglobal.explorer_item_groups) then
		for key, name in pairs (private.dbglobal.explorer_item_groups) do
			if (name == groupName) then
				return key
			end
		end
	end
	
	return nil
end

function RSCollectionsDB.AddItemGroup(value)
	if (value and strtrim(value) ~= '') then
		-- Ignore if already exists
		for _, v in pairs (private.dbglobal.explorer_item_groups) do
			if (value == v) then
				return
			end
		end
		
		local key = 1
		if (RSUtils.GetTableLength(private.dbglobal.explorer_item_groups) > 0) then
			local keys = {}
			for k, _ in pairs (private.dbglobal.explorer_item_groups) do
				tinsert(keys, k)
			end
			
			key = math.max(unpack(keys)) + 1
		end
		
		private.dbglobal.explorer_item_groups[key] = strtrim(value)
		return key
	end
end

function RSCollectionsDB.DeleteItemGroup(key)
	if (key) then
		-- Delete group
		private.dbglobal.explorer_item_groups[key] = nil
		
		-- Delete group's items
		if (private.dbglobal.explorer_item_list) then
			private.dbglobal.explorer_item_list[key] = nil
		end
		
		-- Delete explorer filter settings
		RSConfigDB.SetSearchingCustom(key, nil)
		
		-- Delete loot filter options
		RSConfigDB.SetShowingCustomItems(key, nil)
		
		-- Delete possible scanned items
		local droppedGroupKey = string.format(RSConstants.ITEM_TYPE.CUSTOM, key)
		if (RSCollectionsDB.GetAllEntitiesCollectionsLoot()) then
			local routines = {}
			
			for source, info in pairs (RSCollectionsDB.GetAllEntitiesCollectionsLoot()) do
				local removeDroppedGroupRoutine = RSRoutines.LoopRoutineNew()
				removeDroppedGroupRoutine:Init(
					function() return RSCollectionsDB.GetAllEntitiesCollectionsLoot()[source] end,
					function(context, entityID, _)
						if (RSCollectionsDB.GetAllEntitiesCollectionsLoot()[source][entityID][droppedGroupKey]) then
							RSCollectionsDB.GetAllEntitiesCollectionsLoot()[source][entityID][droppedGroupKey] = nil
						end
										
						-- Check if the entity doesn't have more collections
						if (RSUtils.GetTableLength(RSCollectionsDB.GetAllEntitiesCollectionsLoot()[source][entityID]) == 0) then
							RSCollectionsDB.GetAllEntitiesCollectionsLoot()[source][entityID] = nil
						end
					end,
					function(context) end
				)
				tinsert(routines, removeDroppedGroupRoutine)
			end
		
			local chainRoutines = RSRoutines.ChainLoopRoutineNew()
			chainRoutines:Init(routines)
			chainRoutines:Run(function(context) end)
		end
	end
end

function RSCollectionsDB.AddGroupItem(key, itemID)
	if (key) then
		if (not private.dbglobal.explorer_item_list) then
			private.dbglobal.explorer_item_list = {}
		end
		
		if (not private.dbglobal.explorer_item_list[key]) then
			private.dbglobal.explorer_item_list[key] = {}
		end
		
		-- Skip if duplicated
		for _, itemID_ in ipairs(private.dbglobal.explorer_item_list[key]) do
			if (itemID == itemID_) then
				return
			end
		end
		
		tinsert(private.dbglobal.explorer_item_list[key], itemID)
	end
end

function RSCollectionsDB.DeleteGroupItem(key, itemID)
	if (key and itemID and private.dbglobal.explorer_item_list and private.dbglobal.explorer_item_list[key]) then
		-- Delete the item for this group
		for i, item in ipairs (private.dbglobal.explorer_item_list[key]) do
			if (item == itemID) then
				tremove(private.dbglobal.explorer_item_list[key], i)
				break
			end
		end
	end
end

function RSCollectionsDB.GetGroupItems(key)
	if (key and private.dbglobal.explorer_item_list and private.dbglobal.explorer_item_list[key]) then
		return private.dbglobal.explorer_item_list[key]
	end
end

function RSCollectionsDB.HasGroupItems(key)
	if (key and private.dbglobal.explorer_item_list and private.dbglobal.explorer_item_list[key]) then
		return true
	end
	
	return false
end

local function CheckUpdateCustom(itemID, entityID, source, checkedItems, customGroupKeys)
	-- If cached use it
	for _, customGroupKey in ipairs(customGroupKeys) do
		if (checkedItems[customGroupKey][itemID]) then
			UpdateEntityCollection(itemID, entityID, source, customGroupKey)
			return true
		end
	end
	
	for groupKey, _ in pairs(RSCollectionsDB.GetItemGroups()) do
		local itemIDs = RSCollectionsDB.GetGroupItems(groupKey)
		if (itemIDs and RSUtils.Contains(itemIDs, itemID)) then
			UpdateEntityCollection(itemID, entityID, source, string.format(RSConstants.ITEM_TYPE.CUSTOM, groupKey))
			checkedItems[string.format(RSConstants.ITEM_TYPE.CUSTOM, groupKey)][itemID] = true
			return true
		end
	end

	return false
end

---============================================================================
-- Collections database
---============================================================================

function RSCollectionsDB.UpdateEntityCollectibles(entityID, items, source)
	if (not RSCollectionsDB.GetAllEntitiesCollectionsLoot()) then
		return
	end

	-- Clean previous version
	if (source and RSCollectionsDB.GetAllEntitiesCollectionsLoot()[source]) then
		RSCollectionsDB.GetAllEntitiesCollectionsLoot()[source][entityID] = nil
	end
	
	-- If no loot stop
	if (not items) then
		return
	end
	
	local checkedItems = {}
	checkedItems[RSConstants.ITEM_TYPE.UNKNOWN] = {}
	checkedItems[RSConstants.ITEM_TYPE.APPEARANCE] = {}
	checkedItems[RSConstants.ITEM_TYPE.TOY] = {}
	checkedItems[RSConstants.ITEM_TYPE.PET] = {}
	checkedItems[RSConstants.ITEM_TYPE.MOUNT] = {}
	checkedItems[RSConstants.ITEM_TYPE.DRAKEWATCHER] = {}
	checkedItems[RSConstants.ITEM_TYPE.DECOR] = {}
	
	local customGroupKeys = {}
	for groupKey, _ in pairs(RSCollectionsDB.GetItemGroups()) do
		local itemTypeCustomKey = string.format(RSConstants.ITEM_TYPE.CUSTOM, groupKey)
		tinsert(customGroupKeys, itemTypeCustomKey)
		checkedItems[itemTypeCustomKey] = {}
	end
	
	for _, itemID in ipairs (items) do
		if (not checkedItems[RSConstants.ITEM_TYPE.UNKNOWN][itemID]) then
			local isToy = checkedItems[RSConstants.ITEM_TYPE.TOY][itemID]
			local isPet = checkedItems[RSConstants.ITEM_TYPE.PET][itemID]
			local isMount = checkedItems[RSConstants.ITEM_TYPE.MOUNT][itemID]
			local isDrake = checkedItems[RSConstants.ITEM_TYPE.DRAKEWATCHER][itemID]
			local isDecor = checkedItems[RSConstants.ITEM_TYPE.DECOR][itemID]
			local isAppearance = checkedItems[RSConstants.ITEM_TYPE.APPEARANCE][itemID]

			-- Check if appearance
			if (not isToy and not isPet and not isMount and not isDrake and not isDecor) then
				if (CheckUpdateAppearance(itemID, entityID, source, checkedItems)) then
					isAppearance = true
				end
			end
			
			-- Check if toy
			if (not isAppearance and not isPet and not isMount and not isDrake and not isDecor) then
				if (CheckUpdateToy(itemID, entityID, source, checkedItems)) then
					isToy = true
				end
			end
					
			-- Check if pet
			if (not isAppearance and not isToy and not isMount and not isDrake and not isDecor) then
				if (CheckUpdatePet(itemID, entityID, source, checkedItems)) then
					isPet = true
				end
			end
			
			-- Check if mount
			if (not isAppearance and not isToy and not isPet and not isDrake and not isDecor) then
				if (CheckUpdateMount(itemID, entityID, source, checkedItems)) then
					isMount = true
				end
			end
			
			-- Check if drakewatcher manuscript
			if (not isAppearance and not isToy and not isPet and not isMount and not isDecor) then
				if (CheckUpdateDrakewatcher(itemID, entityID, source, checkedItems)) then
					isDrake = true
				end
			end
			
			-- Check if decor
			if (not isAppearance and not isToy and not isPet and not isMount and not isDrake) then
				if (CheckUpdateDecor(itemID, entityID, source, checkedItems)) then
					isDecor = true
				end
			end
	
			-- Check if custom item
			CheckUpdateCustom(itemID, entityID, source, checkedItems, customGroupKeys)
			
			-- Add to unknown only if it didn't match any collectible category
			if (not isAppearance and 
				not isPet and 
				not isToy and 
				not isMount and 
				not isDrake and 
				not isDecor and 
				not RSUtils.ContainsKeyValue(checkedItems, customGroupKeys, itemID)) then
				
				checkedItems[RSConstants.ITEM_TYPE.UNKNOWN][itemID] = true
			end
		end
	end
end

local function CheckUpdateCollectibles(checkedItems, customGroupKeys, getter, source, routines, routineTextOutput)
	local checkUpdateCollectiblesRoutine = RSRoutines.LoopRoutineNew()
	checkUpdateCollectiblesRoutine:Init(
		getter,
		function(context, entityID, items)
			if (not items) then return end

			for _, itemID in ipairs(items) do
				-- Skip if unknown
				if (not checkedItems[RSConstants.ITEM_TYPE.UNKNOWN][itemID]) then
					local isToy = checkedItems[RSConstants.ITEM_TYPE.TOY][itemID]
					local isPet = checkedItems[RSConstants.ITEM_TYPE.PET][itemID]
					local isMount = checkedItems[RSConstants.ITEM_TYPE.MOUNT][itemID]
					local isDrake = checkedItems[RSConstants.ITEM_TYPE.DRAKEWATCHER][itemID]
					local isDecor = checkedItems[RSConstants.ITEM_TYPE.DECOR][itemID]
					local isAppearance = checkedItems[RSConstants.ITEM_TYPE.APPEARANCE][itemID]

					-- Check if appearance
					if (not isToy and not isPet and not isMount and not isDrake and not isDecor) then
						if (CheckUpdateAppearance(itemID, entityID, source, checkedItems)) then
							isAppearance = true
						end
					end
					
					-- Check if toy
					if (not isAppearance and not isPet and not isMount and not isDrake and not isDecor) then
						if (CheckUpdateToy(itemID, entityID, source, checkedItems)) then
							isToy = true
						end
					end
							
					-- Check if pet
					if (not isAppearance and not isToy and not isMount and not isDrake and not isDecor) then
						if (CheckUpdatePet(itemID, entityID, source, checkedItems)) then
							isPet = true
						end
					end
					
					-- Check if mount
					if (not isAppearance and not isToy and not isPet and not isDrake and not isDecor) then
						if (CheckUpdateMount(itemID, entityID, source, checkedItems)) then
							isMount = true
						end
					end
			
					-- Check if drakewatcher manuscript
					if (not isAppearance and not isToy and not isPet and not isMount and not isDecor) then
						if (CheckUpdateDrakewatcher(itemID, entityID, source, checkedItems)) then
							isDrake = true
						end
					end
			
					-- Check if decor
					if (not isAppearance and not isToy and not isPet and not isMount and not isDrake) then
						if (CheckUpdateDecor(itemID, entityID, source, checkedItems)) then
							isDecor = true
						end
					end
			
					-- Check if custom item
					CheckUpdateCustom(itemID, entityID, source, checkedItems, customGroupKeys)
					
					-- Add to unknown only if it didn't match any collectible category
					if (not isAppearance and 
						not isPet and 
						not isToy and 
						not isMount and 
						not isDrake and 
						not isDecor and 
						not RSUtils.ContainsKeyValue(checkedItems, customGroupKeys, itemID)) then
						
						checkedItems[RSConstants.ITEM_TYPE.UNKNOWN][itemID] = true
					end
				end
			end
		end,
		function(context)
			RSLogger:PrintDebugMessage(string.format("CheckUpdateCollectibles. [%s]. Finalizada rutina.", source == RSConstants.ITEM_SOURCE.NPC and "NPCs" or "Contenedores"))
			
			if (routineTextOutput) then
				local count = RSUtils.GetTableLength(RSCollectionsDB.GetAllEntitiesCollectionsLoot()[source])
				
				if (source == RSConstants.ITEM_SOURCE.NPC) then
					RSLogger:PrintDebugMessage(string.format("CheckUpdateCollectibles. [NPCs]. Detectados [%s] con coleccionables.", count))
					routineTextOutput:SetText(string.format(AL["EXPLORER_FOUND_NPCS"], count))
				else
					RSLogger:PrintDebugMessage(string.format("CheckUpdateCollectibles. [Contenedores]. Detectados [%s] con coleccionables.", count))
					routineTextOutput:SetText(string.format(AL["EXPLORER_FOUND_CONTAINERS"], count))
				end
			end
		end
	)
	table.insert(routines, checkUpdateCollectiblesRoutine)
end

local function UpdateEntitiesCollections(callback, routineTextOutput, manualScan)
	-- Saves current version
	private.dbglobal.lastCollectionsScanVersion = RSConstants.CURRENT_LOOT_DB_VERSION

	-- Reset database
	ResetEntitiesCollectionsLoot()
	
	local checkedItems = {}
	checkedItems[RSConstants.ITEM_TYPE.UNKNOWN] = {}
	checkedItems[RSConstants.ITEM_TYPE.APPEARANCE] = {}
	checkedItems[RSConstants.ITEM_TYPE.TOY] = {}
	checkedItems[RSConstants.ITEM_TYPE.PET] = {}
	checkedItems[RSConstants.ITEM_TYPE.MOUNT] = {}
	checkedItems[RSConstants.ITEM_TYPE.DRAKEWATCHER] = {}
	checkedItems[RSConstants.ITEM_TYPE.DECOR] = {}

	local customGroupKeys = {}
	for groupKey, _ in pairs(RSCollectionsDB.GetItemGroups()) do
		local itemTypeCustomKey = string.format(RSConstants.ITEM_TYPE.CUSTOM, groupKey)
		tinsert(customGroupKeys, itemTypeCustomKey)
		checkedItems[itemTypeCustomKey] = {}
	end
	
	local routines = {}
	
	-- Sync npc loot
	local function ProcessNpcPhase(onNpcsFinished)
		local npcRoutines = {}
		CheckUpdateCollectibles(checkedItems, customGroupKeys, RSNpcDB.GetAllInteralNpcLoot, RSConstants.ITEM_SOURCE.NPC, npcRoutines, routineTextOutput)
		
		local npcChain = RSRoutines.ChainLoopRoutineNew()
		npcChain:Init(npcRoutines)
		npcChain:Run(function()
			RSLogger:PrintDebugMessage("UpdateEntitiesCollections. Actualizada la lista de coleccionables de NPCs no conseguidos.")
			if onNpcsFinished then onNpcsFinished() end
		end)
	end
	
	-- Sync container loot
	local function ProcessContainerPhase(onContainersFinished)
		local containerRoutines = {}
		CheckUpdateCollectibles(checkedItems, customGroupKeys, RSContainerDB.GetAllInteralContainerLoot, RSConstants.ITEM_SOURCE.CONTAINER, containerRoutines, routineTextOutput)
		
		local containerChain = RSRoutines.ChainLoopRoutineNew()
		containerChain:Init(containerRoutines)
		containerChain:Run(function()
			RSLogger:PrintDebugMessage("UpdateEntitiesCollections. Actualizada la lista de coleccionables de contenedores no conseguidos.")
			if onContainersFinished then onContainersFinished() end
		end)
	end
		
	-- Launch all the routines in order
	ProcessNpcPhase(function()
		ProcessContainerPhase(function()
			checkedItems = nil
			RSLogger:PrintMessage(AL["LOG_DONE"])
			RSLogger:PrintDebugMessage("UpdateEntitiesCollections: Finalizado proceso.")
			if callback then callback() end
		end)
	end)
end

local loaded = false
local function LoadNotCollectedItems(callback, routineTextOutput, manualScan)
	RSLogger:PrintMessage(AL["LOG_FETCHING_COLLECTIONS"])
	
	-- Prepare not collected queries routines
	local routines = {}
	UpdateNotCollectedToys(routines, routineTextOutput)
	UpdateNotCollectedPetIDs(routines, routineTextOutput)
	UpdateNotCollectedMountIDs(routines, routineTextOutput)
	UpdateNotCollectedAppearanceItemIDs(routines, routineTextOutput)
	UpdateNotCollectedDrakewatchers(routines, routineTextOutput)
	
	-- Decors API fires a callback when the searcher is ready
	UpdateNotCollectedDecors(routines, routineTextOutput, function()
		-- Launch all the routines in order
		local chainRoutines = RSRoutines.ChainLoopRoutineNew()
		chainRoutines:Init(routines)
		chainRoutines:Run(function(context)
			-- Reset filters
			C_TransmogCollection.SetDefaultFilters()
								
			loaded = true
			routineTextOutput:SetText(AL["LOG_FILTERING_ENTITIES"])
			UpdateEntitiesCollections(callback, routineTextOutput, manualScan)
			RSLogger:PrintMessage(AL["LOG_DONE"])
		end)
	end)
end

local function FindProfile(name)
	local profiles = {}
	for _, v in pairs(private.dbm:GetProfiles(profiles)) do
		if (v == name) then
			return true
		end
	end
	
	return false
end

function RSCollectionsDB.ApplyCollectionsEntitiesFilters(callback, routineTextOutput, manualScan)	
	-- Loads all not collected items if not done in this session --
	if (not loaded) then
		LoadNotCollectedItems(callback, routineTextOutput, manualScan)
	else
		UpdateEntitiesCollections(callback, routineTextOutput, manualScan)
	end
end

function RSCollectionsDB.ApplyFilters(filters, callback)	
	-- Creates profile backup if selected
	if (RSConfigDB.IsCreateProfileBackup()) then
		local name = GetUnitName("player", true)
		local realmName = GetRealmName()
		local currentProfile = private.dbm:GetCurrentProfile()
		if (name) then
			local i = 0
			local backupProfileName = string.format("%s-%s_col_%s", name, realmName, i)
			while (FindProfile(backupProfileName)) do
				i = i + 1
				backupProfileName = string.format("%s-%s_col_%s", name, realmName, i)
			end
			
			private.dbm:SetProfile(backupProfileName)
			private.dbm:CopyProfile(currentProfile, true)
			RSLogger:PrintMessage(string.format(AL["COLLECTION_FILTERS_PROFILE_BACKUP_CREATED"], backupProfileName))
		end
	end
	
	local routines = {}
	
	-- Filter all NPCs
	RSConfigDB.FilterAllNpcs(routines)
	RSConfigDB.FilterAllContainers(routines)
	
	-- Remove filters for NPCs with collections
	if (RSCollectionsDB.GetAllEntitiesCollectionsLoot() and RSCollectionsDB.GetAllEntitiesCollectionsLoot()[RSConstants.ITEM_SOURCE.NPC]) then
		local collectionsLoot = RSCollectionsDB.GetAllEntitiesCollectionsLoot()[RSConstants.ITEM_SOURCE.NPC]
		
		local removeNPCFilterByCollectionRoutine = RSRoutines.LoopRoutineNew()
		removeNPCFilterByCollectionRoutine:Init(
			RSNpcDB.GetAllInternalNpcInfo,
			function(context, npcID, npcInfo)
				local removeFilter = false
				if (not removeFilter and filters[RSConstants.EXPLORER_FILTER_DROP_MOUNTS] and collectionsLoot[npcID] and RSUtils.GetTableLength(collectionsLoot[npcID][RSConstants.ITEM_TYPE.MOUNT]) > 0) then
					removeFilter = true
				end
				if (not removeFilter and filters[RSConstants.EXPLORER_FILTER_DROP_PETS] and collectionsLoot[npcID] and RSUtils.GetTableLength(collectionsLoot[npcID][RSConstants.ITEM_TYPE.PET]) > 0) then
					removeFilter = true
				end
				if (not removeFilter and filters[RSConstants.EXPLORER_FILTER_DROP_TOYS] and collectionsLoot[npcID] and RSUtils.GetTableLength(collectionsLoot[npcID][RSConstants.ITEM_TYPE.TOY]) > 0) then
					removeFilter = true
				end
				if (not removeFilter and filters[RSConstants.EXPLORER_FILTER_DROP_APPEARANCES] and collectionsLoot[npcID] and RSUtils.GetTableLength(collectionsLoot[npcID][RSConstants.ITEM_TYPE.APPEARANCE]) > 0) then
					if (filters[RSConstants.EXPLORER_FILTER_DROP_CLASS_APPEARANCES]) then
						for _, itemID in pairs(collectionsLoot[npcID][RSConstants.ITEM_TYPE.APPEARANCE]) do
							if (RSCollectionsDB.IsNotCollectedClassAppearance(itemID)) then
								removeFilter = true
								break
							end
						end
					else
						removeFilter = true
					end
				end
				if (not removeFilter and filters[RSConstants.EXPLORER_FILTER_DROP_DRAKEWATCHER] and collectionsLoot[npcID] and RSUtils.GetTableLength(collectionsLoot[npcID][RSConstants.ITEM_TYPE.DRAKEWATCHER]) > 0) then
					removeFilter = true
				end
				if (not removeFilter and filters[RSConstants.EXPLORER_FILTER_ACHIEVEMENT_CRITERIA] and npcInfo.achievementID) then			
					if (RSAchievementDB.IsNotCompletedAchievementCriteria(npcID, npcInfo.achievementID, npcInfo.questID, npcInfo.criteria)) then
						removeFilter = true
					end
				end
				if (not removeFilter) then
					for groupKey, _ in pairs(RSCollectionsDB.GetItemGroups()) do
						local droppedGroupKey = string.format(RSConstants.ITEM_TYPE.CUSTOM, groupKey)				
						if (filters[string.format(RSConstants.EXPLORER_FILTER_DROP_CUSTOM, groupKey)] and collectionsLoot[npcID] and RSUtils.GetTableLength(collectionsLoot[npcID][droppedGroupKey]) > 0) then
							removeFilter = true
						end
					end
				end
				
				if (removeFilter) then
					RSConfigDB.DeleteNpcFiltered(npcID)
					
					for npcIDpostEvent, npcIDPpreEvent in pairs (RSConstants.NPCS_WITH_PRE_NPCS) do
						if (npcIDpostEvent == npcID or npcIDPpreEvent == npcID) then
							RSConfigDB.DeleteNpcFiltered(npcIDpostEvent)
							RSConfigDB.DeleteNpcFiltered(npcIDPpreEvent)
							break
						end
					end
				end
			end,
			function(context)
				RSLogger:PrintDebugMessage("ApplyFilters. Eliminados filtros de NPCs con coleccionables aun no conseguidos")
			end
		)
		table.insert(routines, removeNPCFilterByCollectionRoutine)
	end
	
	-- Remove filters for Containers with collections
	if (RSCollectionsDB.GetAllEntitiesCollectionsLoot() and RSCollectionsDB.GetAllEntitiesCollectionsLoot()[RSConstants.ITEM_SOURCE.CONTAINER]) then
		local collectionsLoot = RSCollectionsDB.GetAllEntitiesCollectionsLoot()[RSConstants.ITEM_SOURCE.CONTAINER]
		
		local removeContainerFilterByCollectionRoutine = RSRoutines.LoopRoutineNew()
		removeContainerFilterByCollectionRoutine:Init(
			RSContainerDB.GetAllInternalContainerInfo,
			function(context, containerID, containerInfo)
				local removeFilter = false
				if (not removeFilter and filters[RSConstants.EXPLORER_FILTER_DROP_MOUNTS] and collectionsLoot[containerID] and RSUtils.GetTableLength(collectionsLoot[containerID][RSConstants.ITEM_TYPE.MOUNT]) > 0) then
					removeFilter = true
				end
				if (not removeFilter and filters[RSConstants.EXPLORER_FILTER_DROP_PETS] and collectionsLoot[containerID] and RSUtils.GetTableLength(collectionsLoot[containerID][RSConstants.ITEM_TYPE.PET]) > 0) then
					removeFilter = true
				end
				if (not removeFilter and filters[RSConstants.EXPLORER_FILTER_DROP_TOYS] and collectionsLoot[containerID] and RSUtils.GetTableLength(collectionsLoot[containerID][RSConstants.ITEM_TYPE.TOY]) > 0) then
					removeFilter = true
				end
				if (not removeFilter and filters[RSConstants.EXPLORER_FILTER_DROP_APPEARANCES] and collectionsLoot[containerID] and RSUtils.GetTableLength(collectionsLoot[containerID][RSConstants.ITEM_TYPE.APPEARANCE]) > 0) then
					if (filters[RSConstants.EXPLORER_FILTER_DROP_CLASS_APPEARANCES]) then
						for _, itemID in pairs(collectionsLoot[containerID][RSConstants.ITEM_TYPE.APPEARANCE]) do
							if (RSCollectionsDB.IsNotCollectedClassAppearance(itemID)) then
								removeFilter = true
								break
							end
						end
					else
						removeFilter = true
					end
				end
				if (not removeFilter and filters[RSConstants.EXPLORER_FILTER_DROP_DRAKEWATCHER] and collectionsLoot[containerID] and RSUtils.GetTableLength(collectionsLoot[containerID][RSConstants.ITEM_TYPE.DRAKEWATCHER]) > 0) then
					removeFilter = true
				end
				if (not removeFilter and filters[RSConstants.EXPLORER_FILTER_ACHIEVEMENT_CRITERIA] and containerInfo.achievementID) then			
					-- If quest completed then the achievement criteria is completed too
					if (containerInfo.questID) then
						for _, questID in pairs(containerInfo.questID) do
							if (not C_QuestLog.IsQuestFlaggedCompletedOnAccount(questID)) then
								removeFilter = true
								break
							end
						end
					else
						if (RSAchievementDB.IsNotCompletedAchievementCriteria(containerID, containerInfo.achievementID, containerInfo.questID, containerInfo.criteria, true)) then
							removeFilter = true
						end
					end
				end
				if (not removeFilter) then
					for groupKey, _ in pairs(RSCollectionsDB.GetItemGroups()) do
						local droppedGroupKey = string.format(RSConstants.ITEM_TYPE.CUSTOM, groupKey)				
						if (filters[string.format(RSConstants.EXPLORER_FILTER_DROP_CUSTOM, groupKey)] and collectionsLoot[containerID] and RSUtils.GetTableLength(collectionsLoot[containerID][droppedGroupKey]) > 0) then
							removeFilter = true
						end
					end
				end
				
				if (removeFilter) then
					RSConfigDB.DeleteContainerFiltered(containerID)
				end
			end,
			function(context)
				RSLogger:PrintDebugMessage("ApplyFilters. Eliminados filtros de Contenedores con coleccionables aun no conseguidos")
			end
		)
		table.insert(routines, removeContainerFilterByCollectionRoutine)
	end
			
	-- Launch all the routines in order
	local chainRoutines = RSRoutines.ChainLoopRoutineNew()
	chainRoutines:Init(routines)
	chainRoutines:Run(function(context)	
		RSLogger:PrintDebugMessage("ApplyFilters: Finalizado proceso.")
		
		if (callback) then
			callback()
		end
	end)
end

function RSCollectionsDB.GetAllEntitiesCollectionsLoot()
	return private.dbglobal.entity_collections_loot
end

function RSCollectionsDB.GetEntityCollectionsLoot(entityID, type)
	local items = {}
	local allCollectionsLoot = RSCollectionsDB.GetAllEntitiesCollectionsLoot()
	if (entityID and allCollectionsLoot and allCollectionsLoot[type]) then
		local entityCollectionsLoot = allCollectionsLoot[type][entityID]		
		if (entityCollectionsLoot) then			
			-- If mount
			if (RSConfigDB.IsShowingMissingMounts() and entityCollectionsLoot[RSConstants.ITEM_TYPE.MOUNT]) then
				items = RSUtils.JoinTables(items, entityCollectionsLoot[RSConstants.ITEM_TYPE.MOUNT])
			end
			
			-- If pet
			if (RSConfigDB.IsShowingMissingPets() and entityCollectionsLoot[RSConstants.ITEM_TYPE.PET]) then
				items = RSUtils.JoinTables(items, entityCollectionsLoot[RSConstants.ITEM_TYPE.PET])
			end
			
			-- If toy
			if (RSConfigDB.IsShowingMissingToys() and entityCollectionsLoot[RSConstants.ITEM_TYPE.TOY]) then
				items = RSUtils.JoinTables(items, entityCollectionsLoot[RSConstants.ITEM_TYPE.TOY])
			end
			
			-- If appearance
			if (RSConfigDB.IsShowingMissingAppearances() and entityCollectionsLoot[RSConstants.ITEM_TYPE.APPEARANCE]) then
				-- If class appearance
				if (RSConfigDB.IsShowingMissingClassAppearances()) then
					for _, itemID in pairs (entityCollectionsLoot[RSConstants.ITEM_TYPE.APPEARANCE]) do
						if (RSCollectionsDB.IsNotCollectedClassAppearance(itemID)) then
							tinsert(items, itemID)
						end
					end
				else
					items = RSUtils.JoinTables(items, entityCollectionsLoot[RSConstants.ITEM_TYPE.APPEARANCE])
				end
			end
			
			-- If drakewatcher manuscripts
			if (RSConfigDB.IsShowingMissingDrakewatcher() and entityCollectionsLoot[RSConstants.ITEM_TYPE.DRAKEWATCHER]) then
				items = RSUtils.JoinTables(items, entityCollectionsLoot[RSConstants.ITEM_TYPE.DRAKEWATCHER])
			end
			
			-- If decor
			if (RSConfigDB.IsShowingMissingDecors() and entityCollectionsLoot[RSConstants.ITEM_TYPE.DECOR]) then
				items = RSUtils.JoinTables(items, entityCollectionsLoot[RSConstants.ITEM_TYPE.DECOR])
			end
			
			-- If custom items
			for groupKey, _ in pairs(RSCollectionsDB.GetItemGroups()) do
				local droppedGroupKey = string.format(RSConstants.ITEM_TYPE.CUSTOM, groupKey)
				if (RSConfigDB.IsShowingCustomItems(groupKey) and entityCollectionsLoot[droppedGroupKey]) then
					items = RSUtils.JoinTables(items, entityCollectionsLoot[droppedGroupKey])
				end
			end
		end
	end
	
	return items
end

function RSCollectionsDB.IsCollectionsScanDoneWithCurrentVersion()
	if (private.dbglobal.lastCollectionsScanVersion and private.dbglobal.lastCollectionsScanVersion == RSConstants.CURRENT_LOOT_DB_VERSION) then
		return true
	end
	
	return false
end