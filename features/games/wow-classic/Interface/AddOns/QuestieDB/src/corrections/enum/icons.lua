-- Correction constants. Source origins and extraction history: PROVENANCE.md.

local _, LibQuestieDB = ...
local constants = LibQuestieDB.Enum

constants.iconTypes = {
  -- Objective actions
  ICON_TYPE_SLAY = 1,
  ICON_TYPE_LOOT = 2,
  ICON_TYPE_EVENT = 3,
  ICON_TYPE_OBJECT = 4,
  ICON_TYPE_TALK = 5,
  ICON_TYPE_INTERACT = 17,
  ICON_TYPE_MOUNT_UP = 19,

  -- Quest availability, completion and variants
  ICON_TYPE_AVAILABLE = 6,
  ICON_TYPE_AVAILABLE_GRAY = 7,
  ICON_TYPE_COMPLETE = 8,
  ICON_TYPE_GLOW = 9,
  ICON_TYPE_REPEATABLE = 10,
  ICON_TYPE_REPEATABLE_COMPLETE = 11,
  ICON_TYPE_INCOMPLETE = 12,
  ICON_TYPE_EVENTQUEST = 13,
  ICON_TYPE_EVENTQUEST_COMPLETE = 14,
  ICON_TYPE_PVPQUEST = 15,
  ICON_TYPE_PVPQUEST_COMPLETE = 16,

  -- Gathering nodes and treasure
  ICON_TYPE_NODE_FISH = 20,
  ICON_TYPE_NODE_HERB = 21,
  ICON_TYPE_NODE_ORE = 22,
  ICON_TYPE_CHEST = 23,

  -- Runes and pet battles
  ICON_TYPE_SODRUNE = 18,
  ICON_TYPE_PET_BATTLE = 24,

  -- Forever [add icon types here]
}
