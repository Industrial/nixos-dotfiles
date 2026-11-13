local addonName, AM = ...

-- Access to the saved variables (AuctionMasterDB). Code never touches AuctionMasterDB
-- directly but asks for a named object, either account-wide (GetGlobalObject) or one per
-- auction house of the current character (GetFactionObject: its faction, on Forever also its
-- rule set), as prices differ between the auction houses and merchants.
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

-- The rule set (PvE, RP, ...) of the current character on Forever, nil elsewhere. Forever has one account for all rule
-- sets, each with an auction house of its own. Its id is the game mode record; not the realm id, which is the shard
-- and may change with every login (see .claude/guidelines/multi-version.md).
local function GetForeverRuleSet()
  if AM.Client.IsForever() and C_GameRules and C_GameRules.GetCurrentGameModeRecordID then
    local gameMode = C_GameRules.GetCurrentGameModeRecordID()
    if gameMode and gameMode ~= 0 then
      return gameMode
    end
  end
end

-- Same as GetGlobalObject, but separate for each auction house: the faction of the current character, on Forever
-- also its rule set ("Horde-16"). Forever data from before the rule set was part of the key lies under the faction
-- alone and is taken over by the first rule set that asks for it.
function Database.GetFactionObject(name, defaultValue)
  local faction = UnitFactionGroup("player") or "Neutral"
  local factions = AuctionMasterDB.factions
  local key = faction
  local ruleSet = GetForeverRuleSet()
  if ruleSet then
    key = faction .. "-" .. ruleSet
    if not factions[key] and factions[faction] then
      factions[key], factions[faction] = factions[faction], nil
    end
  end
  factions[key] = factions[key] or {}
  return GetObject(factions[key], name, defaultValue)
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
