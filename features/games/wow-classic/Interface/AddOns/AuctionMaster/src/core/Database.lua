local addonName, AM = ...

-- Access to the saved variables (AuctionMasterDB). Code never touches AuctionMasterDB
-- directly but asks for a named object, either account-wide (GetGlobalObject) or one per
-- faction of the current character (GetFactionObject), as prices differ between the
-- factions' auction houses and merchants.
--
-- An object is stored as { version, data } and the data table is what the caller gets. The
-- version defaults to 1 and is meant to drive migrations once an object's shape changes.
local Database = {}
AM.Database = Database

local DEFAULT_VERSION = 1

local function GetObject(container, name, defaultValue)
  local object = container[name]
  if not object then
    object = { version = DEFAULT_VERSION }
    container[name] = object
  end
  if object.data == nil then
    object.data = defaultValue or {}
  end
  return object.data
end

-- Returns the account-wide table stored under name. defaultValue (a new table, {} if
-- omitted) becomes the object if there is none yet.
function Database.GetGlobalObject(name, defaultValue)
  return GetObject(AuctionMasterDB.global, name, defaultValue)
end

-- Same as GetGlobalObject, but separate for each faction of the current character.
function Database.GetFactionObject(name, defaultValue)
  local faction = UnitFactionGroup("player") or "Neutral"
  local factions = AuctionMasterDB.factions
  factions[faction] = factions[faction] or {}
  return GetObject(factions[faction], name, defaultValue)
end

-- Deletes the account-wide object name, it starts afresh the next time it is requested.
function Database.ResetGlobalObject(name)
  AuctionMasterDB.global[name] = nil
end

-- Before objects existed, the data lay directly in the root of the saved variables. It is
-- adopted as the objects of the current character, the best guess as which faction it
-- came from.
local function AdoptLegacyData(db)
  for _, name in ipairs({ "items", "marketPrices" }) do
    if db[name] then
      Database.GetFactionObject(name, db[name])
      db[name] = nil
    end
  end
  if db.lastScan then
    Database.GetGlobalObject("scan", { lastScan = db.lastScan })
    db.lastScan = nil
  end
end

-- Account-wide objects of features that were removed (the recording of the player's disenchants and its window).
local OBSOLETE_GLOBAL_OBJECTS = { "disenchantStats", "disenchantWindow" }

-- Must be called once the saved variables are loaded, before any object is requested.
function Database.Init()
  AuctionMasterDB = AuctionMasterDB or {}
  local db = AuctionMasterDB
  db.version = db.version or 1
  db.global = db.global or {}
  db.factions = db.factions or {}
  AdoptLegacyData(db)
  for _, name in ipairs(OBSOLETE_GLOBAL_OBJECTS) do
    db.global[name] = nil
  end
end
