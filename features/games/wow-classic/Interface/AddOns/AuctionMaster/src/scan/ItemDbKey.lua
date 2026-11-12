local addonName, AM = ...

-- The key under which the market data of an item is stored and looked up (AM.ItemStore). It is a string and tells
-- apart what a buyer does not treat as the same item: the itemID alone is enough for most items, equipment also needs
-- its item level (a level 6 and a level 74 bow share an itemID), battle pets their species. Parts are only
-- written where they apply, in this order, after the itemID:
--
--   2589            an item that needs nothing more (linen cloth)
--   4576:l74        equipment: item level
--   82800:p1234     battle pet species (all pets share the itemID of the cage)
--
-- The itemID is always the leading number (GetItemId). A new part, or a part for more item classes, can be added
-- later without touching the keys of the other items: Matches tells the stored keys that no longer fit the rules,
-- and ItemStore removes just those (RULES_REVISION makes it look again after a change).
--
-- The parts come from different sources (a bag location, a link, the auction house's own item key, the arguments of a
-- tooltip), which all end in Build. A key that cannot be built yet (the item data is not loaded, the level is unknown) is
-- nil with a reason; it is never replaced by a coarser one, as that would put items into one bucket that do not belong
-- together.
AM.ItemDbKey = {}
local ItemDbKey = AM.ItemDbKey

-- Raise when the rules below change, so the stored keys are checked against them once more.
ItemDbKey.RULES_REVISION = 2

-- The itemID the auction house gives every battle pet (the pet cage).
ItemDbKey.PET_CAGE = 82800

-- The item classes whose item level belongs to the key: the ones the auction house lists several levels of
-- one item for (checked in the Retail browse lists: weapons, armor, profession equipment).
local LEVEL_CLASSES = {}
for _, name in ipairs({ "Weapon", "Armor", "Profession" }) do
  if Enum.ItemClass[name] then
    LEVEL_CLASSES[Enum.ItemClass[name]] = true
  end
end

local function ClassOf(itemId)
  return select(6, C_Item.GetItemInfoInstant(itemId))
end

-- True if the item needs its item level in the key. Items the client does not know (no class) are taken not to.
function ItemDbKey.NeedsLevel(itemId)
  return LEVEL_CLASSES[ClassOf(itemId)] == true
end

-- The key from its parts, nil and the reason if it cannot be built. species is only for battle pets, level only for
-- equipment. A random suffix ("of the Bear") is deliberately no part of the key: it stands for dozens of enchantments and
-- bonus IDs, mostly on items of little value, and would multiply the stored data.
function ItemDbKey.Build(itemId, level, species)
  if not itemId or itemId == 0 then
    return nil, "no item"
  end
  if species and species ~= 0 then
    return itemId .. ":p" .. species
  end
  if not ItemDbKey.NeedsLevel(itemId) then
    return tostring(itemId)
  end
  if not level or level <= 0 then
    return nil, "no item level yet"
  end
  return itemId .. ":l" .. level
end

-- The key of an item that needs nothing but its itemID (reagents, recipe results of trade goods, ...), nil and the
-- reason for equipment and pets, whose key depends on the single item.
function ItemDbKey.ForItem(itemId)
  if ItemDbKey.NeedsLevel(itemId) or itemId == ItemDbKey.PET_CAGE then
    return nil, "depends on the single item"
  end
  return ItemDbKey.Build(itemId)
end

-- The key of what a recipe makes: ForItem, and for equipment the item level the game lists for it (its link without
-- bonus IDs; the item level line of the recipe's tooltip says the same). Nil and the reason while the item data is not
-- loaded. Equipment that scales with the crafter may then be made at another level, which the key does not know: its
-- auctions are looked up under the listed level.
function ItemDbKey.ForCrafted(itemId)
  if ItemDbKey.NeedsLevel(itemId) then
    return ItemDbKey.Build(itemId, C_Item.GetDetailedItemLevelInfo("item:" .. itemId))
  end
  return ItemDbKey.ForItem(itemId)
end

-- The itemID a key stands for.
function ItemDbKey.GetItemId(key)
  return tonumber(key:match("^(%d+)"))
end

-- True if the key has the shape the rules give its item. Keys of items whose class is not known are kept.
function ItemDbKey.Matches(key)
  local itemId = ItemDbKey.GetItemId(key)
  if not itemId then
    return false
  end
  if key:find(":p%d") then
    return itemId == ItemDbKey.PET_CAGE
  end
  if itemId == ItemDbKey.PET_CAGE then
    return false
  end
  local class = ClassOf(itemId)
  if class == nil then
    return true
  end
  if LEVEL_CLASSES[class] then
    return key:find("^%d+:l%d+$") ~= nil
  end
  return key == tostring(itemId)
end

-- The key from the auction house's own item key (search results, browse rows, bag items via GetItemKeyFromItem).
function ItemDbKey.FromAhItemKey(ahItemKey)
  return ItemDbKey.Build(ahItemKey.itemID, ahItemKey.itemLevel, ahItemKey.battlePetSpeciesID)
end

-- The key of an item in a bag or bank slot. Item data that is not loaded yet gives nil and the reason.
function ItemDbKey.FromLocation(location)
  local ahItemKey = C_AuctionHouse.GetItemKeyFromItem(location)
  if not ahItemKey then
    return nil, "no item key"
  end
  return ItemDbKey.FromAhItemKey(ahItemKey)
end

-- The key of an item link (or a battle pet link), or of the item string that is its core ("item:2589::::",
-- "battlepet:1234"). The item level is worked out by the game from the link, so the item data has to be loaded: nil and
-- the reason otherwise.
function ItemDbKey.FromLink(link)
  if not link then
    return nil, "no link"
  end
  local species = link:match("|Hbattlepet:(%d+)") or link:match("^battlepet:(%d+)")
  if species then
    return ItemDbKey.Build(ItemDbKey.PET_CAGE, nil, tonumber(species))
  end
  local fields = { strsplit(":", link:match("|Hitem:([^|]*)") or link:match("^item:([^|]*)") or "") }
  local itemId = tonumber(fields[1])
  if not itemId then
    return nil, "no item link"
  end
  if not ItemDbKey.NeedsLevel(itemId) then
    return ItemDbKey.Build(itemId)
  end
  return ItemDbKey.Build(itemId, C_Item.GetDetailedItemLevelInfo(link))
end
