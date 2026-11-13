local addonName, AM = ...

-- How much the addon writes to the chat, chosen in the options (global object "settings"). Every message has a level:
--   "quiet"    the answer to something the player did (a click, a command). Shown at every setting: "Quiet" never
--              hides the feedback to an action, and never shows anything that happened by itself.
--   "normal"   what the player should know without asking (the default, stored as nil).
--   "detailed" progress and confirmations.
-- A message is shown when its level is not above the chosen one.
AM.Chat = {}
local Chat = AM.Chat

Chat.LEVELS = { "quiet", "normal", "detailed" }

local RANK = { quiet = 1, normal = 2, detailed = 3 }

function Chat.GetLevel()
  return AM.Database.GetGlobalObject("settings").chatLevel or "normal"
end

function Chat.SetLevel(level)
  AM.Database.GetGlobalObject("settings").chatLevel = level ~= "normal" and RANK[level] and level or nil
end

-- True if a message of this level is shown at the chosen setting.
function Chat.IsShown(level)
  return RANK[level] <= RANK[Chat.GetLevel()]
end

-- Prints to the chat frame with the addon name as prefix, if the chosen level allows it. level defaults to "normal".
function AM.Print(text, level)
  if Chat.IsShown(level or "normal") then
    print("|cff33ff99" .. addonName .. "|r:", text)
  end
end
