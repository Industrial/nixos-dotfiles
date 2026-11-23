local FIXTURE_BUILD = "0.0.0.fixture"
return {
  schemaVersion = 1,
  build = FIXTURE_BUILD,
  source = "fixture",
  items = {
    {
      id = 90001,
      name = "FIXTURE Agility Flask",
      class = "Consumable",
      subclass = "Flask",
      quality = 4,
      stackable = 5
    },
    {
      id = 90002,
      name = "FIXTURE Agility Battle Elixir",
      class = "Consumable",
      subclass = "Elixir",
      quality = 3,
      stackable = 5
    },
    {
      id = 90003,
      name = "FIXTURE Armor Guardian Elixir",
      class = "Consumable",
      subclass = "Elixir",
      quality = 3,
      stackable = 5
    },
    {
      id = 90004,
      name = "FIXTURE Well Fed Stamina Food",
      class = "Consumable",
      subclass = "Food",
      quality = 1,
      stackable = 20
    },
    {
      id = 90005,
      name = "FIXTURE Conjured Water",
      class = "Consumable",
      subclass = "Food",
      quality = 1,
      stackable = 20,
      conjured = true
    },
    {
      id = 90006,
      name = "FIXTURE Basic Water",
      class = "Consumable",
      subclass = "Food",
      quality = 1,
      stackable = 20
    },
    {
      id = 90007,
      name = "FIXTURE Sharpening Stone",
      class = "Consumable",
      subclass = "Other",
      quality = 1,
      stackable = 20
    },
    {
      id = 90008,
      name = "FIXTURE Wizard Oil",
      class = "Consumable",
      subclass = "Other",
      quality = 1,
      stackable = 5
    },
    {
      id = 90012,
      name = "FIXTURE Healing Potion",
      class = "Consumable",
      subclass = "Potion",
      quality = 1,
      stackable = 5
    },
    {
      id = 90013,
      name = "FIXTURE Mana Potion",
      class = "Consumable",
      subclass = "Potion",
      quality = 1,
      stackable = 5
    },
    {
      id = 90014,
      name = "FIXTURE Linen Bandage",
      class = "Consumable",
      subclass = "Bandage",
      quality = 1,
      stackable = 20
    },
    {
      id = 90015,
      name = "FIXTURE Healthstone",
      class = "Consumable",
      subclass = "Other",
      quality = 1,
      stackable = 1,
      conjured = true
    },
    {
      id = 90016,
      name = "FIXTURE Mana Jade",
      class = "Consumable",
      subclass = "Other",
      quality = 2,
      stackable = 1,
      conjured = true
    },
    {
      id = 90009,
      name = "FIXTURE Iron Bar",
      class = "Trade Goods",
      subclass = "Metal",
      quality = 1,
      stackable = 20
    },
    {
      id = 90010,
      name = "FIXTURE Linen Cloth",
      class = "Trade Goods",
      subclass = "Cloth",
      quality = 1,
      stackable = 20
    },
    {
      id = 90011,
      name = "FIXTURE Odd Scrap",
      class = "Trade Goods",
      quality = 0,
      stackable = 10
    }
  },
  spells = {
    {
      id = 91001,
      name = "FIXTURE Flask of Agility",
      duration = 7200000
    },
    {
      id = 91002,
      name = "FIXTURE Elixir of Agility",
      duration = 3600000
    },
    {
      id = 91003,
      name = "FIXTURE Elixir of Armor",
      duration = 3600000
    },
    {
      id = 91004,
      name = "FIXTURE Well Fed",
      duration = 900000
    },
    {
      id = 91005,
      name = "FIXTURE Conjured Refreshment",
      duration = 0
    },
    {
      id = 91006,
      name = "FIXTURE Drink Water",
      duration = 0
    },
    {
      id = 91007,
      name = "FIXTURE Sharpen Weapon",
      duration = 1800000
    },
    {
      id = 91008,
      name = "FIXTURE Oil Weapon",
      duration = 1800000
    },
    {
      id = 91012,
      name = "FIXTURE Heal Self",
      duration = 0
    },
    {
      id = 91013,
      name = "FIXTURE Restore Mana",
      duration = 0
    },
    {
      id = 91014,
      name = "FIXTURE Bandage Self",
      duration = 8000
    },
    {
      id = 91015,
      name = "FIXTURE Healthstone",
      duration = 0
    },
    {
      id = 91016,
      name = "FIXTURE Restore Mana",
      duration = 0
    },
    {
      id = 92001,
      name = "FIXTURE Inner Fortitude",
      duration = 1800000
    },
    {
      id = 92002,
      name = "FIXTURE Arcane Brilliance",
      duration = 3600000
    },
    {
      id = 92003,
      name = "FIXTURE Conjure Rations",
      duration = 0
    },
    {
      id = 92004,
      name = "FIXTURE Summon Imp",
      duration = 0
    },
    {
      id = 92005,
      name = "FIXTURE Mend",
      duration = 0
    },
    {
      id = 92006,
      name = "FIXTURE Innervate",
      duration = 0
    },
    {
      id = 92007,
      name = "FIXTURE Shadow Blight",
      duration = 18000
    },
    {
      id = 92008,
      name = "FIXTURE Venom Sting",
      duration = 15000
    },
    {
      id = 92009,
      name = "FIXTURE Slow Burn",
      duration = 12000
    },
    {
      id = 92010,
      name = "FIXTURE Renewing Light",
      duration = 15000
    },
    {
      id = 92011,
      name = "FIXTURE Twin Plague",
      duration = 12000
    }
  },
  itemEffects = {
    {
      itemId = 90001,
      spellId = 91001,
      trigger = "use"
    },
    {
      itemId = 90002,
      spellId = 91002,
      trigger = "use"
    },
    {
      itemId = 90003,
      spellId = 91003,
      trigger = "use"
    },
    {
      itemId = 90004,
      spellId = 91004,
      trigger = "use"
    },
    {
      itemId = 90005,
      spellId = 91005,
      trigger = "use"
    },
    {
      itemId = 90006,
      spellId = 91006,
      trigger = "use"
    },
    {
      itemId = 90007,
      spellId = 91007,
      trigger = "use"
    },
    {
      itemId = 90008,
      spellId = 91008,
      trigger = "use"
    },
    {
      itemId = 90012,
      spellId = 91012,
      trigger = "use"
    },
    {
      itemId = 90013,
      spellId = 91013,
      trigger = "use"
    },
    {
      itemId = 90014,
      spellId = 91014,
      trigger = "use"
    },
    {
      itemId = 90015,
      spellId = 91015,
      trigger = "use"
    },
    {
      itemId = 90016,
      spellId = 91016,
      trigger = "use"
    }
  },
  spellEffects = {
    {
      spellId = 91001,
      index = 1,
      auraType = "APPLY_AURA",
      statType = "AGILITY",
      amount = 25
    },
    {
      spellId = 91002,
      index = 1,
      auraType = "APPLY_AURA",
      statType = "AGILITY",
      amount = 18
    },
    {
      spellId = 91003,
      index = 1,
      auraType = "APPLY_AURA",
      statType = "ARMOR",
      amount = 450
    },
    {
      spellId = 91004,
      index = 1,
      auraType = "APPLY_AURA",
      statType = "STAMINA",
      amount = 6
    },
    -- A stat food restores health too (Forever's Nutritious Food does both),
    -- which is what puts it in two sets: basic food and Food.Buff.Stamina.
    {
      spellId = 91004,
      index = 2,
      auraType = "PERIODIC_HEAL",
      amount = 60
    },
    {
      spellId = 91005,
      index = 1,
      auraType = "PERIODIC_ENERGIZE",
      amount = 1800
    },
    {
      spellId = 91006,
      index = 1,
      auraType = "PERIODIC_ENERGIZE",
      amount = 1200
    },
    {
      spellId = 91007,
      index = 1,
      auraType = "ENCHANT_HELD_ITEM",
      amount = 8,
      enchantKind = "SHARPEN"
    },
    {
      spellId = 91008,
      index = 1,
      auraType = "ENCHANT_HELD_ITEM",
      amount = 24,
      enchantKind = "WIZARD_OIL"
    },
    {
      spellId = 91012,
      index = 1,
      auraType = "HEAL",
      amount = 700
    },
    {
      spellId = 91013,
      index = 1,
      auraType = "ENERGIZE",
      amount = 600
    },
    {
      spellId = 91014,
      index = 1,
      auraType = "PERIODIC_HEAL",
      amount = 400
    },
    {
      spellId = 91015,
      index = 0,
      auraType = "HEAL",
      amount = 500
    },
    {
      spellId = 91016,
      index = 0,
      auraType = "ENERGIZE",
      amount = 400
    },
    {
      spellId = 92001,
      index = 1,
      auraType = "APPLY_AURA",
      statType = "STAMINA",
      amount = 10
    },
    {
      spellId = 92002,
      index = 1,
      auraType = "APPLY_AURA_PARTY",
      statType = "INTELLECT",
      amount = 12
    },
    {
      spellId = 92003,
      index = 1,
      auraType = "CREATE_ITEM",
      amount = 1
    },
    {
      spellId = 92004,
      index = 1,
      auraType = "SUMMON",
      amount = 1
    },
    {
      spellId = 92005,
      index = 1,
      auraType = "HEAL",
      amount = 300
    },
    {
      spellId = 92006,
      index = 1,
      auraType = "ENERGIZE",
      amount = 400
    },
    {
      spellId = 92007,
      index = 1,
      auraType = "PERIODIC_DAMAGE",
      amount = 60
    },
    {
      spellId = 92008,
      index = 1,
      auraType = "PERIODIC_DAMAGE",
      amount = 20
    },
    {
      spellId = 92009,
      index = 1,
      auraType = "PERIODIC_DAMAGE",
      amount = 45
    },
    {
      spellId = 92010,
      index = 1,
      auraType = "PERIODIC_HEAL",
      amount = 80
    },
    {
      spellId = 92011,
      index = 1,
      auraType = "PERIODIC_DAMAGE",
      amount = 30
    },
    {
      spellId = 92011,
      index = 2,
      auraType = "PERIODIC_DAMAGE",
      amount = 12
    }
  },
  spellClass = {
    {
      spellId = 92001,
      classFile = "PRIEST"
    },
    {
      spellId = 92002,
      classFile = "MAGE"
    },
    {
      spellId = 92003,
      classFile = "MAGE"
    },
    {
      spellId = 92004,
      classFile = "WARLOCK"
    },
    {
      spellId = 92005,
      classFile = "PRIEST"
    },
    {
      spellId = 92005,
      classFile = "PALADIN"
    },
    {
      spellId = 92006,
      classFile = "DRUID"
    },
    {
      spellId = 92002,
      classFile = "PRIEST"
    },
    {
      spellId = 92006,
      classFile = "PRIEST",
      specId = 93001
    },
    {
      spellId = 92003,
      classFile = "PRIEST",
      specId = 93001
    },
    {
      spellId = 92004,
      classFile = "PRIEST",
      specId = 93002
    },
    {
      spellId = 92007,
      classFile = "WARLOCK"
    },
    {
      spellId = 92008,
      classFile = "HUNTER"
    },
    {
      spellId = 92009,
      classFile = "MAGE"
    },
    {
      spellId = 92011,
      classFile = "WARLOCK"
    }
  },
  spellLevels = {
    {
      spellId = 92001,
      learnLevel = 1
    },
    {
      spellId = 92002,
      learnLevel = 14
    },
    {
      spellId = 92003,
      learnLevel = 4
    },
    {
      spellId = 92004,
      learnLevel = 10
    },
    {
      spellId = 92005,
      learnLevel = 2
    },
    {
      spellId = 92006,
      learnLevel = 40
    }
  },
  specs = {
    {
      specId = 93001,
      classFile = "PRIEST",
      name = "FIXTURE Devotion",
      role = "HEALER",
      primaryStat = "INTELLECT"
    },
    {
      specId = 93002,
      classFile = "PRIEST",
      name = "FIXTURE Wrath",
      role = "DAMAGER",
      primaryStat = "INTELLECT"
    }
  },
  talentTrees = {
    {
      treeId = 93100,
      classFile = "PRIEST",
      kind = "class"
    },
    {
      treeId = 93101,
      specId = 93001,
      kind = "spec"
    },
    {
      treeId = 93102,
      specId = 93002,
      kind = "spec"
    },
    {
      treeId = 93103,
      specId = 93001,
      kind = "hero"
    }
  },
  talentNodes = {
    {
      nodeId = 93200,
      treeId = 93100,
      type = "single",
      maxRanks = 1
    },
    {
      nodeId = 93201,
      treeId = 93100,
      type = "choice",
      maxRanks = 1
    },
    {
      nodeId = 93202,
      treeId = 93101,
      type = "single",
      maxRanks = 1
    },
    {
      nodeId = 93203,
      treeId = 93102,
      type = "tiered",
      maxRanks = 3
    },
    {
      nodeId = 93204,
      treeId = 93103,
      type = "single",
      maxRanks = 1
    },
    {
      nodeId = 93205,
      treeId = 93100,
      type = "single",
      maxRanks = 2
    }
  },
  talentEntries = {
    {
      entryId = 93300,
      nodeId = 93200,
      spellId = 92001
    },
    {
      entryId = 93301,
      nodeId = 93201,
      spellId = 92002
    },
    {
      entryId = 93302,
      nodeId = 93201,
      spellId = 92005
    },
    {
      entryId = 93303,
      nodeId = 93202,
      spellId = 92006
    },
    {
      entryId = 93304,
      nodeId = 93203,
      spellId = 92004
    },
    {
      entryId = 93305,
      nodeId = 93204,
      spellId = 92003
    },
    {
      entryId = 93306,
      nodeId = 93205,
      definitionId = 7
    }
  },
  spellReagents = {
    {
      spellId = 92003,
      itemId = 90010,
      count = 1
    }
  },
  spellPeriodic = {
    {
      spellId = 92007,
      index = 1,
      period = 3000,
      baseAmount = 60,
      coefficient = 0.156,
      school = "SHADOW"
    },
    {
      spellId = 92008,
      index = 1,
      period = 3000,
      baseAmount = 20,
      apCoefficient = 0.08,
      school = "NATURE"
    },
    {
      spellId = 92009,
      index = 1,
      period = 4000,
      baseAmount = 45,
      coefficient = 0.1,
      school = "FIRE"
    },
    {
      spellId = 92011,
      index = 1,
      period = 3000,
      baseAmount = 30,
      coefficient = 0.08,
      school = "SHADOW"
    },
    {
      spellId = 92011,
      index = 2,
      period = 3000,
      baseAmount = 12,
      coefficient = 0.03,
      school = "FIRE"
    }
  }
}
