-- src/corrections/_begin.lua
--
-- Opens the correction block: installs the compat shim for Questie's correction files, which
-- preserve exact source fidelity outside explicitly declared provider/consumer ownership
-- exclusions. Closed by src/corrections/_end.lua.

local _, LibQuestieDB = ...
LibQuestieDB.CorrectionCompat.Install(LibQuestieDB.flavor)
