local addonName, AM = ...

-- The characters of the current auction house, for showing them: the faction object "characters" maps the GUID
-- (which survives a rename) to { name, realm, class }, class being the class file ("MAGE"). Every character records
-- itself at login, so each one the player has played since is known, whatever it does in the game. Features keep
-- their own data by GUID and ask here for the name.
AM.Characters = {}
local Characters = AM.Characters

-- The GUIDs of the characters of the current auction house (guid -> true): the current one and those with recipes,
-- bags or mail recorded for it. Decides which entries of the objects that used to be account-wide belong here.
function Characters.GetHouseGuids()
  local guids = { [UnitGUID("player")] = true }
  for _, recipes in pairs(AM.Database.GetFactionObject("recipes")) do
    for _, recipe in ipairs(recipes) do
      for _, guid in ipairs(recipe.crafters) do
        guids[guid] = true
      end
    end
  end
  for _, name in ipairs({ "inventory", "mail" }) do
    for guid in pairs(AM.Database.GetFactionObject(name)) do
      guids[guid] = true
    end
  end
  return guids
end

-- The object was account-wide once: its old entries of this auction house move over once per session (a change of
-- auction house means a new login).
local adopted = false

-- All characters known here, GUID -> { name, realm, class }. An entry may be a bare name, stored by an earlier version
-- (replaced when that character logs in again); use Characters.Get to show one.
function Characters.GetAll()
  if not adopted then
    adopted = true
    local here = Characters.GetHouseGuids()
    AM.Database.AdoptGlobalEntries("characters", function(guid)
      return here[guid]
    end)
  end
  return AM.Database.GetFactionObject("characters")
end

-- Records the character that is logged in (name, realm and class as the game reports them) and returns its GUID.
function Characters.RecordCurrent()
  local guid = UnitGUID("player")
  local name, realm = UnitFullName("player")
  if not realm or realm == "" then
    realm = GetNormalizedRealmName()
  end
  if guid and name then
    Characters.GetAll()[guid] = { name = name, realm = realm, class = select(2, UnitClass("player")) }
  end
  return guid
end

-- The name to show for a character, with its realm when that is not the current one, and its class file (nil if not
-- known); nil if the character is not known here.
function Characters.Get(guid)
  local character = guid and Characters.GetAll()[guid]
  if type(character) ~= "table" or not character.name then
    return nil
  end
  if character.realm and character.realm ~= GetNormalizedRealmName() then
    return character.name .. "-" .. character.realm, character.class
  end
  return character.name, character.class
end

-- Forgets a character (its other data is up to the features that keep it). It is recorded again at its next login.
function Characters.Forget(guid)
  Characters.GetAll()[guid] = nil
end

-- The faction and the game rules, and with them the auction house, are only known at login.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  Characters.RecordCurrent()
end)
