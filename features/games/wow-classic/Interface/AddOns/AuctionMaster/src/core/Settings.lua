local addonName, AM = ...

-- The player's preferences from the options (global object "settings": the same for every auction house). Each value
-- is the player's choice as is, also when it equals the default; nil means only "never chose" and reads as the
-- default given to Define. So a default can change later without overriding anyone's choice.
AM.Settings = {}
local Settings = AM.Settings

local defaults = {}

-- Declares a setting and its default, once, in the file of the feature it belongs to.
function Settings.Define(key, default)
  defaults[key] = default
end

local function Check(key)
  if defaults[key] == nil then
    error("AuctionMaster: unknown setting " .. tostring(key), 3)
  end
end

function Settings.Get(key)
  Check(key)
  local value = AM.Database.GetGlobalObject("settings")[key]
  if value == nil then
    return defaults[key]
  end
  return value
end

-- A boolean setting is stored as true or false (a checkbox may hand over 1 or nil).
function Settings.Set(key, value)
  Check(key)
  if type(defaults[key]) == "boolean" then
    value = not not value
  end
  AM.Database.GetGlobalObject("settings")[key] = value
end
