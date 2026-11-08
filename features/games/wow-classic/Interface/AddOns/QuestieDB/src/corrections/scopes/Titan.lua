-- Titan hints follow the same Wrath-plus-season boundary as their providers.
local _, LibQuestieDB = ...
LibQuestieDB.CorrectionCompat.SelectObjectiveFirstScope(
  LibQuestieDB.CorrectionRegister.IsTitanReforgedActive(LibQuestieDB.flavor))
