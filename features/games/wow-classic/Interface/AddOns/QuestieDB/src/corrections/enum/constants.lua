-- Correction constants, maintained in the subject files listed by config.enumFiles.
--
-- Initially extracted by tools/questie-sync/port-corrections.lua.
-- Last migration reference: Questie/Questie@454b9d072965ee8f1a881429260fcf1fac8d60f7.
-- Source modules and extraction history are recorded in PROVENANCE.md.
--
-- raceMaskById encoding is expansion-invariant; IDs need not be playable in every flavor.
-- Named race/class sets and NPC flags live under constants.byExpansion. The runtime API
-- additionally publishes factionRaceMasks, classKeys and npcFlags for the active flavor; standalone enum loading does not.

local _, LibQuestieDB = ...

local constants = {}

if LibQuestieDB then
  -- The TOC loads this initializer before the subject files populate the shared table.
  LibQuestieDB.Enum = constants
else
  -- Preserve the standalone dofile entry point for offline callers. WoW never does file I/O.
  local namespace = { Enum = constants }
  local files = dofile("src/config.lua").enumFiles
  for index = 2, #files do
    assert(loadfile(files[index]))("QuestieDB", namespace)
  end
end

return constants
