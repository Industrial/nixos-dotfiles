-- NPC correction constants.

local _, LibQuestieDB = ...
local constants = LibQuestieDB.Enum

-- Values of npcKeys.rank: cmangos creature_template ranks, the same in every flavor.
-- See https://github.com/cmangos/issues/wiki/creature_template#rank
constants.npcRanks = {
  NORMAL = 0,
  ELITE = 1,
  RARE_ELITE = 2,
  BOSS = 3,
  RARE = 4,
}
