-- src/corrections/_end.lua
--
-- Closes the correction block: registers what the manifest describes, then hands
-- `QuestieLoader` back to whoever owned it. The shim leaves no `Questie` global behind;
-- registered providers borrow their private stand-in only for the duration of invocation.

local _, LibQuestieDB = ...

local compat = LibQuestieDB.CorrectionCompat
local modules = compat.modules or {}

LibQuestieDB.CorrectionRegister.FromManifest(LibQuestieDB.flavor, function(name)
  return modules[name]
end)

-- Objective-ordering hints are consumer information, not entity data, so they are published
-- rather than merged into the database.
LibQuestieDB.ObjectiveFirst = compat.objectiveFirst

compat.Remove()
