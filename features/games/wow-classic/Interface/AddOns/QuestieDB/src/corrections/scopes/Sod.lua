-- Vanilla ships SoD providers, but ordinary Era must not receive their load-time hints.
local _, LibQuestieDB = ...
LibQuestieDB.CorrectionCompat.SelectObjectiveFirstScope(
  LibQuestieDB.flavor.expansion == "Classic" and LibQuestieDB.CorrectionRegister.IsSodActive())
