local M = { }
M.SCHEMA_VERSION = 1
M.SCHEMA_MINOR = 4
local field
field = function(kind, required, note)
  return {
    kind = kind,
    required = required == true,
    note = note
  }
end
M.records = {
  items = {
    key = "id",
    fields = {
      id = field("int", true, "item id"),
      name = field("string", true),
      class = field("string", true, "item class, e.g. Consumable"),
      subclass = field("string", false),
      quality = field("int", false, "0=poor .. 5=legendary"),
      ilvl = field("int", false),
      stackable = field("int", false),
      conjured = field("bool", false, "client flag: created by a spell, vanishes on logout"),
      bind = field("string", false, "none|pickup|equip|use|quest")
    }
  },
  itemEffects = {
    key = nil,
    fields = {
      itemId = field("int", true),
      spellId = field("int", true),
      trigger = field("string", true, "use|equip|proc"),
      charges = field("int", false),
      cooldownCategory = field("int", false, "shared cooldown group (SpellCategoryID); 0/nil = none"),
      categoryCooldown = field("int", false, "ms the shared group stays on cooldown")
    }
  },
  spells = {
    key = "id",
    fields = {
      id = field("int", true),
      name = field("string", true),
      duration = field("number", false, "milliseconds; 0 or absent = instant/permanent")
    }
  },
  spellEffects = {
    key = nil,
    fields = {
      spellId = field("int", true),
      index = field("int", true, "effect slot, 1-based"),
      auraType = field("string", false, "e.g. APPLY_AURA"),
      statType = field("string", false, "e.g. AGILITY, STAMINA"),
      amount = field("number", false),
      miscValue = field("int", false),
      enchantKind = field("string", false, "ENCHANT_HELD_ITEM only: SHARPEN, WEIGHT, WIZARD_OIL, MANA_OIL, OTHER")
    }
  },
  spellClass = {
    optional = true,
    key = nil,
    fields = {
      spellId = field("int", true),
      classFile = field("string", true, "PALADIN, MAGE, ... (token, not localized)"),
      specId = field("int", false, "nil = all specs of that class")
    }
  },
  spellLevels = {
    optional = true,
    key = "spellId",
    fields = {
      spellId = field("int", true),
      learnLevel = field("int", true)
    }
  },
  spellReagents = {
    optional = true,
    key = nil,
    fields = {
      spellId = field("int", true),
      itemId = field("int", true),
      count = field("int", false)
    }
  },
  spellPeriodic = {
    optional = true,
    key = nil,
    fields = {
      spellId = field("int", true),
      index = field("int", false, "effect slot the periodic aura sits in, 1-based"),
      period = field("int", true, "milliseconds between ticks"),
      baseAmount = field("number", true, "damage per tick before any scaling"),
      coefficient = field("number", false, "spell power contribution per tick"),
      apCoefficient = field("number", false, "attack power contribution per tick"),
      school = field("string", false, "SHADOW, FIRE, NATURE, PHYSICAL, ... (token, not localized)")
    }
  },
  specs = {
    optional = true,
    key = "specId",
    fields = {
      specId = field("int", true),
      classFile = field("string", true, "PALADIN, MAGE, ... (token, not localized)"),
      name = field("string", true, "Holy, Protection, Retribution, ..."),
      role = field("string", false, "TANK | HEALER | DAMAGER"),
      primaryStat = field("string", false, "STRENGTH | AGILITY | INTELLECT")
    }
  },
  talentTrees = {
    optional = true,
    key = "treeId",
    fields = {
      treeId = field("int", true),
      specId = field("int", false, "nil for a CLASS tree, shared by every spec"),
      classFile = field("string", false, "set on a class tree, where specId is nil"),
      kind = field("string", true, "class | spec | hero")
    }
  },
  talentNodes = {
    optional = true,
    key = "nodeId",
    fields = {
      nodeId = field("int", true),
      treeId = field("int", true),
      type = field("string", false, "single | choice | tiered"),
      maxRanks = field("int", false, "1 for most; higher for a ranked node")
    }
  },
  talentEntries = {
    optional = true,
    key = "entryId",
    fields = {
      entryId = field("int", true),
      nodeId = field("int", true),
      spellId = field("int", false, "nil when an entry grants no castable spell"),
      definitionId = field("int", false)
    }
  }
}
M.document = {
  schemaVersion = field("int", true),
  build = field("string", true, "client build the facts were taken from"),
  source = field("string", true, "dbc|harvest|fixture")
}
return M
