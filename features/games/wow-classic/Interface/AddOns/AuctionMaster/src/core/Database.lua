local addonName, AM = ...

-- Access to the saved variables (AuctionMasterDB). Code never touches AuctionMasterDB
-- directly but asks for a named object, either account-wide (GetGlobalObject) or one per
-- auction house of the current character (GetFactionObject: its faction, on Forever also its
-- rule set), as prices differ between the auction houses and merchants. Everything about the game world (prices,
-- recipes, characters and their bags, mail, lists) is a faction object; a global object is only for what is the same
-- on every auction house of the account (preferences, window states). In doubt, a faction object (see CLAUDE.md).
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
local function GetFactionContainer()
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
  return factions[key]
end

function Database.GetFactionObject(name, defaultValue)
  return GetObject(GetFactionContainer(), name, defaultValue)
end

-- For an object that used to be account-wide and is now kept per auction house under the same name: moves the
-- entries of the old account-wide object whose key claim(key) accepts into the faction object (an entry it already
-- has wins). The others wait there for their own auction house; the account-wide object is deleted once it is empty.
function Database.AdoptGlobalEntries(name, claim)
  local global = AuctionMasterDB.global[name]
  if not global then
    return
  end
  local old = global.data or {}
  local house = Database.GetFactionObject(name)
  for key, value in pairs(old) do
    if claim(key) then
      if house[key] == nil then
        house[key] = value
      end
      old[key] = nil
    end
  end
  if next(old) == nil then
    AuctionMasterDB.global[name] = nil
  end
end

local function DeepCopy(value)
  if type(value) ~= "table" then
    return value
  end
  local copy = {}
  for key, entry in pairs(value) do
    copy[key] = DeepCopy(entry)
  end
  return copy
end

-- Same as GetFactionObject, for an object that used to be account-wide while nothing tells which auction house its
-- data belongs to (the player's own rules and lists): an auction house that has no such object yet starts with a copy
-- of the account-wide one, which stays for the auction houses still to come.
function Database.GetFactionObjectFromGlobal(name)
  local container = GetFactionContainer()
  local global = AuctionMasterDB.global[name]
  if container[name] == nil and global and global.data then
    return GetObject(container, name, DeepCopy(global.data))
  end
  return GetObject(container, name)
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
