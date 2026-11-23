local PATHS = {
  "src.modules.automation.upkeep.Rules",
  "src.modules.automation.upkeep.classes.WARRIOR",
  "src.modules.automation.upkeep.classes.MAGE",
  "src.modules.automation.upkeep.classes.ROGUE",
  "src.modules.automation.upkeep.Engine"
}
local load
load = function()
  for _index_0 = 1, #PATHS do
    local p = PATHS[_index_0]
    package.loaded[p] = nil
    require(p)
  end
  return _G.idUpkeep_UpkeepRules, _G.idUpkeep_UpkeepEngine
end
local merge
merge = function(base, over)
  for k, v in pairs(over or { }) do
    base[k] = v
  end
  return base
end
local known
known = function(name, extra)
  return merge({
    name = name,
    known = true,
    usable = true,
    noMana = false,
    icon = "icon:" .. tostring(name)
  }, extra)
end
local aura
aura = function(name, extra)
  return merge({
    name = name
  }, extra)
end
local ID = {
  BATTLE_SHOUT = 6673,
  ARCANE_INTELLECT = 1459,
  ARCANE_BRILLIANCE = 23028,
  FROST_ARMOR = 168,
  ICE_ARMOR = 7302,
  MAGE_ARMOR = 6117,
  CONJURE_WATER = 5504,
  CONJURE_FOOD = 587
}
local snapFor
snapFor = function(classToken, over)
  return merge({
    class = classToken,
    level = 60,
    now = 1000,
    inInstance = false,
    player = {
      healthPct = 100,
      manaPct = 100,
      usesMana = classToken == "MAGE"
    },
    spells = { },
    items = { },
    itemInfo = { },
    units = {
      player = {
        exists = true,
        class = classToken,
        usesMana = classToken == "MAGE",
        auras = { }
      }
    },
    pet = {
      exists = false
    },
    weapon = {
      mh = {
        isWeapon = false
      },
      oh = {
        isWeapon = false
      }
    },
    consumables = { },
    foodBuffs = { },
    food = { },
    water = { },
    weaponItems = { },
    wellFed = {
      ids = {
        19705
      },
      names = {
        "Well Fed"
      }
    }
  }, over)
end
local mageSnap
mageSnap = function(over)
  local snap = snapFor("MAGE", over)
  local _update_0 = ID.CONJURE_WATER
  snap.spells[_update_0] = snap.spells[_update_0] or known("Conjure Water")
  local _update_1 = ID.CONJURE_FOOD
  snap.spells[_update_1] = snap.spells[_update_1] or known("Conjure Food")
  local _update_2 = ID.FROST_ARMOR
  snap.spells[_update_2] = snap.spells[_update_2] or known("Frost Armor")
  local _update_3 = ID.ICE_ARMOR
  snap.spells[_update_3] = snap.spells[_update_3] or known("Ice Armor")
  local _update_4 = ID.MAGE_ARMOR
  snap.spells[_update_4] = snap.spells[_update_4] or known("Mage Armor")
  local _update_5 = ID.ARCANE_INTELLECT
  snap.spells[_update_5] = snap.spells[_update_5] or known("Arcane Intellect")
  local _update_6 = ID.ARCANE_BRILLIANCE
  snap.spells[_update_6] = snap.spells[_update_6] or {
    name = "Arcane Brilliance",
    known = false
  }
  local _update_7 = 5350
  snap.items[_update_7] = snap.items[_update_7] or 20
  local _update_8 = 5349
  snap.items[_update_8] = snap.items[_update_8] or 10
  return snap
end
return describe("Upkeep Engine", function()
  local Rules, Engine, R
  before_each(function()
    Rules, Engine = load()
    R = Rules
  end)
  describe("guards", function()
    it("returns nil with the reason when auras are unreadable", function()
      local step, reason = Engine.nextStep(snapFor("WARRIOR", {
        unreadable = "player: aura data is secret"
      }), Rules.forClass("WARRIOR"))
      assert.is_nil(step)
      return assert.matches("unreadable", reason)
    end)
    it("does nothing in combat", function()
      local step, reason = Engine.nextStep(snapFor("WARRIOR", {
        inCombat = true
      }), Rules.forClass("WARRIOR"))
      assert.is_nil(step)
      return assert.are.equal("in combat", reason)
    end)
    it("does nothing while casting", function()
      local step, reason = Engine.nextStep(snapFor("MAGE", {
        casting = "Conjure Water"
      }), Rules.forClass("MAGE"))
      assert.is_nil(step)
      return assert.are.equal("casting", reason)
    end)
    it("says nothing to do when every step is done or impossible", function()
      local snap = snapFor("WARRIOR")
      snap.spells[ID.BATTLE_SHOUT] = known("Battle Shout", {
        noMana = true,
        usable = false
      })
      local step, reason = Engine.nextStep(snap, Rules.forClass("WARRIOR"))
      assert.is_nil(step)
      return assert.are.equal("nothing to do", reason)
    end)
    return it("unknown classes still get the generic rest phase", function()
      local snap = snapFor("PRIEST", {
        player = {
          healthPct = 10,
          manaPct = 100,
          usesMana = true
        }
      })
      snap.food = {
        {
          itemId = 4599,
          value = 874,
          count = 3
        }
      }
      local step = Engine.nextStep(snap, Rules.forClass("NOSUCHCLASS"))
      return assert.are.equal(4599, step.item)
    end)
  end)
  describe("WARRIOR", function()
    it("casts Battle Shout on self when missing", function()
      local snap = snapFor("WARRIOR")
      snap.spells[ID.BATTLE_SHOUT] = known("Battle Shout")
      local step = Engine.nextStep(snap, Rules.forClass("WARRIOR"))
      assert.are.equal("spell", step.kind)
      assert.are.equal("Battle Shout", step.spell)
      assert.are.equal("player", step.unit)
      return assert.are.equal("selfShort", step.phase)
    end)
    it("skips an active Battle Shout but refreshes it under 30 seconds", function()
      local snap = snapFor("WARRIOR")
      snap.spells[ID.BATTLE_SHOUT] = known("Battle Shout")
      snap.units.player.auras = {
        aura("Battle Shout", {
          expires = 1100
        })
      }
      assert.is_nil((Engine.nextStep(snap, Rules.forClass("WARRIOR"))))
      snap.units.player.auras = {
        aura("Battle Shout", {
          expires = 1010
        })
      }
      local step = Engine.nextStep(snap, Rules.forClass("WARRIOR"))
      assert.are.equal("Battle Shout", step.spell)
      return assert.matches("expiring", step.reason)
    end)
    it("applies a sharpening stone to a bladed main hand before Battle Shout", function()
      local snap = snapFor("WARRIOR")
      snap.spells[ID.BATTLE_SHOUT] = known("Battle Shout")
      snap.weapon.mh = {
        isWeapon = true,
        blunt = false,
        hasEnchant = false
      }
      snap.weaponItems = {
        sharpening = {
          {
            itemId = 2862,
            value = 2,
            count = 1
          },
          {
            itemId = 12404,
            value = 8,
            count = 2
          }
        },
        weight = {
          {
            itemId = 12643,
            value = 8,
            count = 1
          }
        }
      }
      local step = Engine.nextStep(snap, Rules.forClass("WARRIOR"))
      assert.are.equal("item", step.kind)
      assert.are.equal(12404, step.item)
      assert.are.equal(16, step.targetSlot)
      assert.is_nil(step.unit)
      return assert.are.equal("weapon", step.phase)
    end)
    it("uses a weightstone on a blunt weapon and the off hand slot 17", function()
      local snap = snapFor("WARRIOR")
      snap.weapon.mh = {
        isWeapon = true,
        blunt = true,
        hasEnchant = true,
        remaining = 1200
      }
      snap.weapon.oh = {
        isWeapon = true,
        blunt = true,
        hasEnchant = false
      }
      snap.weaponItems = {
        weight = {
          {
            itemId = 12643,
            value = 8,
            count = 1
          }
        }
      }
      local step = Engine.nextStep(snap, Rules.forClass("WARRIOR"))
      assert.are.equal(12643, step.item)
      return assert.are.equal(17, step.targetSlot)
    end)
    it("skips Battle Shout without rage and falls through to rest", function()
      local snap = snapFor("WARRIOR", {
        player = {
          healthPct = 40,
          usesMana = false
        }
      })
      snap.spells[ID.BATTLE_SHOUT] = known("Battle Shout", {
        noMana = true
      })
      snap.food = {
        {
          itemId = 4599,
          value = 874,
          count = 3
        }
      }
      local step = Engine.nextStep(snap, Rules.forClass("WARRIOR"))
      assert.are.equal(4599, step.item)
      assert.are.equal("rest", step.phase)
      local reasons
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = Engine.explain(snap, Rules.forClass("WARRIOR"))
        for _index_0 = 1, #_list_0 do
          local e = _list_0[_index_0]
          if e.phase == "selfShort" then
            _accum_0[_len_0] = e.reason
            _len_0 = _len_0 + 1
          end
        end
        reasons = _accum_0
      end
      return assert.are.same({
        "insufficient mana/power"
      }, reasons)
    end)
    return it("never offers caster consumables to a melee class", function()
      local snap = snapFor("WARRIOR")
      snap.consumables = {
        ["Consumable.Buff.Intellect.Self"] = {
          items = {
            {
              itemId = 9179,
              value = 25,
              count = 1
            }
          },
          auraNames = { },
          auraIds = { }
        }
      }
      return assert.is_nil((Engine.nextStep(snap, Rules.forClass("WARRIOR"))))
    end)
  end)
  describe("MAGE", function()
    it("conjures water first, then food, then the armor", function()
      local rules = Rules.forClass("MAGE")
      local snap = mageSnap()
      snap.items[5350] = 4
      local step = Engine.nextStep(snap, rules)
      assert.are.equal("Conjure Water", step.spell)
      assert.are.equal("conjure", step.phase)
      assert.matches("4/20", step.reason)
      snap.items[5350] = 20
      snap.items[5349] = 0
      assert.are.equal("Conjure Food", (Engine.nextStep(snap, rules)).spell)
      snap.items[5349] = 10
      step = Engine.nextStep(snap, rules)
      assert.are.equal("Ice Armor", step.spell)
      return assert.are.equal("selfLong", step.phase)
    end)
    it("prefers Mage Armor in instances, and any armor satisfies", function()
      local rules = Rules.forClass("MAGE")
      local snap = mageSnap({
        inInstance = true
      })
      assert.are.equal("Mage Armor", (Engine.nextStep(snap, rules)).spell)
      snap.units.player.auras = {
        aura("Frost Armor")
      }
      local step = Engine.nextStep(snap, rules)
      return assert.are_not.equal("Mage Armor", step.spell)
    end)
    it("falls back to Frost Armor below level 30", function()
      local snap = mageSnap()
      snap.spells[ID.ICE_ARMOR] = {
        name = "Ice Armor",
        known = false
      }
      snap.spells[ID.MAGE_ARMOR] = {
        name = "Mage Armor",
        known = false
      }
      return assert.are.equal("Frost Armor", (Engine.nextStep(snap, Rules.forClass("MAGE"))).spell)
    end)
    it("buffs self, then mana-using party members one per press, skipping warriors", function()
      local rules = Rules.forClass("MAGE")
      local snap = mageSnap()
      snap.units.player.auras = {
        aura("Ice Armor")
      }
      snap.units.party1 = {
        exists = true,
        class = "WARRIOR",
        usesMana = false,
        auras = { }
      }
      snap.units.party2 = {
        exists = true,
        class = "PRIEST",
        usesMana = true,
        auras = { }
      }
      local step = Engine.nextStep(snap, rules)
      assert.are.equal("Arcane Intellect", step.spell)
      assert.are.equal("player", step.unit)
      table.insert(snap.units.player.auras, aura("Arcane Intellect"))
      step = Engine.nextStep(snap, rules)
      assert.are.equal("party2", step.unit)
      return assert.are.equal("group", step.phase)
    end)
    it("skips out-of-range, dead and offline party members with the reason", function()
      local rules = Rules.forClass("MAGE")
      local snap = mageSnap()
      snap.units.player.auras = {
        aura("Ice Armor"),
        aura("Arcane Intellect")
      }
      snap.units.party1 = {
        exists = true,
        class = "PRIEST",
        usesMana = true,
        inRange = false,
        auras = { }
      }
      snap.units.party2 = {
        exists = true,
        class = "DRUID",
        usesMana = true,
        dead = true,
        auras = { }
      }
      snap.units.party3 = {
        exists = true,
        class = "MAGE",
        usesMana = true,
        connected = false,
        auras = { }
      }
      snap.units.party4 = {
        exists = true,
        class = "WARLOCK",
        usesMana = true,
        auras = { }
      }
      local step = Engine.nextStep(snap, rules)
      assert.are.equal("party4", step.unit)
      local byUnit = { }
      local _list_0 = Engine.explain(snap, rules)
      for _index_0 = 1, #_list_0 do
        local e = _list_0[_index_0]
        if e.phase == "group" then
          byUnit[e.label] = e.reason
        end
      end
      assert.are.equal("out of range", byUnit["Arcane Intellect -> party1"])
      assert.are.equal("dead", byUnit["Arcane Intellect -> party2"])
      return assert.are.equal("offline", byUnit["Arcane Intellect -> party3"])
    end)
    it("counts Arcane Brilliance as Arcane Intellect", function()
      local snap = mageSnap()
      snap.units.player.auras = {
        aura("Ice Armor"),
        aura("Arcane Brilliance", {
          spellId = 23028
        })
      }
      snap.units.party1 = {
        exists = true,
        class = "PRIEST",
        usesMana = true,
        auras = {
          aura("Arcane Brilliance")
        }
      }
      return assert.is_nil((Engine.nextStep(snap, Rules.forClass("MAGE"))))
    end)
    it("buffs a mana-using pet, and ignores the party when include_party is off", function()
      local snap = mageSnap()
      snap.units.player.auras = {
        aura("Ice Armor"),
        aura("Arcane Intellect")
      }
      snap.units.party1 = {
        exists = true,
        class = "PRIEST",
        usesMana = true,
        auras = { }
      }
      snap.units.pet = {
        exists = true,
        usesMana = true,
        auras = { }
      }
      local step = Engine.nextStep(snap, Rules.forClass("MAGE"), {
        includeParty = false
      })
      return assert.are.equal("pet", step.unit)
    end)
    it("skips buffs without mana and drinks instead", function()
      local snap = mageSnap({
        player = {
          healthPct = 100,
          manaPct = 5,
          usesMana = true
        }
      })
      snap.spells[ID.ICE_ARMOR] = known("Ice Armor", {
        noMana = true
      })
      snap.spells[ID.ARCANE_INTELLECT] = known("Arcane Intellect", {
        noMana = true
      })
      snap.water = {
        {
          itemId = 8079,
          value = 4200,
          count = 20,
          conjured = true
        }
      }
      local step = Engine.nextStep(snap, Rules.forClass("MAGE"))
      assert.are.equal(8079, step.item)
      return assert.are.equal("Drink", step.label)
    end)
    return it("applies wizard oil to the main hand", function()
      local snap = mageSnap()
      snap.units.player.auras = {
        aura("Ice Armor"),
        aura("Arcane Intellect")
      }
      snap.weapon.mh = {
        isWeapon = true,
        blunt = true,
        hasEnchant = false
      }
      snap.weaponItems = {
        wizardOil = {
          {
            itemId = 20749,
            value = 36,
            count = 1
          }
        }
      }
      local step = Engine.nextStep(snap, Rules.forClass("MAGE"))
      assert.are.equal(20749, step.item)
      return assert.are.equal(16, step.targetSlot)
    end)
  end)
  describe("ROGUE", function()
    local rogueSnap
    rogueSnap = function()
      local snap = snapFor("ROGUE")
      snap.weapon.mh = {
        isWeapon = true,
        blunt = false,
        hasEnchant = false
      }
      snap.weapon.oh = {
        isWeapon = true,
        blunt = false,
        hasEnchant = false
      }
      return snap
    end
    it("puts the best Instant Poison on the main hand", function()
      local snap = rogueSnap()
      snap.items = {
        [6947] = 5,
        [8928] = 5,
        [20844] = 5
      }
      local step = Engine.nextStep(snap, Rules.forClass("ROGUE"))
      assert.are.equal(8928, step.item)
      return assert.are.equal(16, step.targetSlot)
    end)
    it("puts Deadly Poison on the off hand once the main hand is done", function()
      local snap = rogueSnap()
      snap.items = {
        [8928] = 5,
        [20844] = 5
      }
      snap.weapon.mh.hasEnchant = true
      snap.weapon.mh.remaining = 1700
      local step = Engine.nextStep(snap, Rules.forClass("ROGUE"))
      assert.are.equal(20844, step.item)
      return assert.are.equal(17, step.targetSlot)
    end)
    it("falls back to another poison, skipping unusable ones", function()
      local snap = rogueSnap()
      snap.items = {
        [8928] = 5,
        [6947] = 5
      }
      snap.itemInfo = {
        [8928] = {
          usable = false
        }
      }
      local step = Engine.nextStep(snap, Rules.forClass("ROGUE"))
      return assert.are.equal(6947, step.item)
    end)
    it("uses a stone only when no poison is in the bags", function()
      local snap = rogueSnap()
      snap.weaponItems = {
        sharpening = {
          {
            itemId = 12404,
            value = 8,
            count = 1
          }
        }
      }
      local step = Engine.nextStep(snap, Rules.forClass("ROGUE"))
      return assert.are.equal(12404, step.item)
    end)
    return it("never touches a weapon that has no weapon equipped", function()
      local snap = snapFor("ROGUE")
      snap.items = {
        [8928] = 5
      }
      return assert.is_nil((Engine.nextStep(snap, Rules.forClass("ROGUE"))))
    end)
  end)
  describe("consumables", function()
    local AGI = "Consumable.Buff.Agility.Self"
    local STR_FLASK = "Consumable.Buff.Strength.Flask"
    local HP_FLASK = "Consumable.Buff.Health.Flask"
    it("uses the strongest elixir of a category", function()
      local snap = snapFor("ROGUE")
      snap.consumables = {
        [AGI] = {
          items = {
            {
              itemId = 3390,
              value = 8,
              count = 1
            },
            {
              itemId = 13452,
              value = 25,
              count = 1
            }
          },
          auraNames = { },
          auraIds = { }
        }
      }
      local step = Engine.nextStep(snap, Rules.forClass("ROGUE"))
      assert.are.equal(13452, step.item)
      assert.are.equal("player", step.unit)
      return assert.are.equal("consumables", step.phase)
    end)
    it("never overwrites an equal or stronger active effect", function()
      local snap = snapFor("ROGUE")
      snap.consumables = {
        [AGI] = {
          items = {
            {
              itemId = 3390,
              value = 8,
              count = 1
            }
          },
          auraNames = {
            ["Elixir of the Mongoose"] = 25,
            ["Lesser Agility"] = 8
          },
          auraIds = { }
        }
      }
      snap.units.player.auras = {
        aura("Elixir of the Mongoose")
      }
      assert.is_nil((Engine.nextStep(snap, Rules.forClass("ROGUE"))))
      snap.units.player.auras = {
        aura("Lesser Agility")
      }
      return assert.is_nil((Engine.nextStep(snap, Rules.forClass("ROGUE"))))
    end)
    it("upgrades a weaker active effect", function()
      local snap = snapFor("ROGUE")
      snap.consumables = {
        [AGI] = {
          items = {
            {
              itemId = 13452,
              value = 25,
              count = 1
            }
          },
          auraNames = { },
          auraIds = {
            [11328] = 15
          }
        }
      }
      snap.units.player.auras = {
        aura("Agility", {
          spellId = 11328
        })
      }
      local step = Engine.nextStep(snap, Rules.forClass("ROGUE"))
      assert.are.equal(13452, step.item)
      return assert.matches("stronger", step.reason)
    end)
    it("uses at most one flask", function()
      local rules = Rules.forClass("WARRIOR")
      local snap = snapFor("WARRIOR")
      snap.consumables = {
        [HP_FLASK] = {
          items = {
            {
              itemId = 13510,
              value = 1200,
              count = 1,
              flask = true
            }
          },
          auraNames = {
            ["Flask of the Titans"] = 1200
          },
          auraIds = { }
        },
        [STR_FLASK] = {
          items = {
            {
              itemId = 99999,
              value = 20,
              count = 1,
              flask = true
            }
          },
          auraNames = { },
          auraIds = { }
        }
      }
      local step = Engine.nextStep(snap, rules)
      assert.are.equal(13510, step.item)
      local flaskSkips
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = Engine.explain(snap, rules)
        for _index_0 = 1, #_list_0 do
          local e = _list_0[_index_0]
          if e.reason == "another flask is active" then
            _accum_0[_len_0] = e
            _len_0 = _len_0 + 1
          end
        end
        flaskSkips = _accum_0
      end
      assert.are.equal(1, #flaskSkips)
      snap.units.player.auras = {
        aura("Flask of the Titans")
      }
      return assert.is_nil((Engine.nextStep(snap, rules)))
    end)
    it("skips everything consumable when the option is off", function()
      local snap = snapFor("ROGUE")
      snap.consumables = {
        [AGI] = {
          items = {
            {
              itemId = 13452,
              value = 25,
              count = 1
            }
          },
          auraNames = { },
          auraIds = { }
        }
      }
      snap.foodBuffs = {
        ["Consumable.Food.Buff.Agility"] = {
          {
            itemId = 13928,
            value = 10,
            count = 1
          }
        }
      }
      return assert.is_nil((Engine.nextStep(snap, Rules.forClass("ROGUE"), {
        useConsumables = false
      })))
    end)
    return it("ignores unusable or missing items", function()
      local snap = snapFor("ROGUE")
      snap.consumables = {
        [AGI] = {
          items = {
            {
              itemId = 13452,
              value = 25,
              count = 1,
              usable = false
            },
            {
              itemId = 3390,
              value = 8,
              count = 0
            }
          },
          auraNames = { },
          auraIds = { }
        }
      }
      return assert.is_nil((Engine.nextStep(snap, Rules.forClass("ROGUE"))))
    end)
  end)
  describe("Well Fed", function()
    it("eats the role's buff food when Well Fed is missing, and stops once active", function()
      local snap = snapFor("ROGUE")
      snap.foodBuffs = {
        ["Consumable.Food.Buff.Agility"] = {
          {
            itemId = 13928,
            value = 10,
            count = 2
          }
        },
        ["Consumable.Food.Buff.Intellect"] = {
          {
            itemId = 13931,
            value = 10,
            count = 2
          }
        }
      }
      local step = Engine.nextStep(snap, Rules.forClass("ROGUE"))
      assert.are.equal(13928, step.item)
      assert.are.equal("foodBuff", step.phase)
      snap.units.player.auras = {
        aura("Well Fed", {
          spellId = 19709
        })
      }
      return assert.is_nil((Engine.nextStep(snap, Rules.forClass("ROGUE"))))
    end)
    return it("detects Well Fed by spell id too", function()
      local snap = snapFor("ROGUE")
      snap.foodBuffs = {
        ["Consumable.Food.Buff.Agility"] = {
          {
            itemId = 13928,
            value = 10,
            count = 2
          }
        }
      }
      snap.units.player.auras = {
        aura("Gut gesättigt", {
          spellId = 19705
        })
      }
      return assert.is_nil((Engine.nextStep(snap, Rules.forClass("ROGUE"))))
    end)
  end)
  describe("rest", function()
    it("eats below the threshold, picking the best food (conjured on ties)", function()
      local snap = snapFor("WARRIOR", {
        player = {
          healthPct = 50,
          usesMana = false
        }
      })
      snap.food = {
        {
          itemId = 4540,
          value = 61,
          count = 5
        },
        {
          itemId = 8076,
          value = 874,
          count = 5,
          conjured = true
        },
        {
          itemId = 8952,
          value = 874,
          count = 5
        }
      }
      local step = Engine.nextStep(snap, Rules.forClass("WARRIOR"))
      assert.are.equal(8076, step.item)
      return assert.are.equal("Eat", step.label)
    end)
    it("respects the threshold option", function()
      local snap = snapFor("WARRIOR", {
        player = {
          healthPct = 70,
          usesMana = false
        }
      })
      snap.food = {
        {
          itemId = 4540,
          value = 61,
          count = 5
        }
      }
      assert.is_not_nil((Engine.nextStep(snap, Rules.forClass("WARRIOR"))))
      return assert.is_nil((Engine.nextStep(snap, Rules.forClass("WARRIOR"), {
        restThreshold = 60
      })))
    end)
    it("skips food that is not usable (level too high)", function()
      local snap = snapFor("WARRIOR", {
        player = {
          healthPct = 50,
          usesMana = false
        }
      })
      snap.food = {
        {
          itemId = 8952,
          value = 874,
          count = 5,
          usable = false
        },
        {
          itemId = 4540,
          value = 61,
          count = 5
        }
      }
      return assert.are.equal(4540, (Engine.nextStep(snap, Rules.forClass("WARRIOR"))).item)
    end)
    it("drinks while eating, but returns resting once both are running", function()
      local snap = mageSnap({
        player = {
          healthPct = 50,
          manaPct = 50,
          usesMana = true
        },
        isEating = true
      })
      snap.food = {
        {
          itemId = 8076,
          value = 874,
          count = 5
        }
      }
      snap.water = {
        {
          itemId = 8079,
          value = 4200,
          count = 5
        }
      }
      local step = Engine.nextStep(snap, Rules.forClass("MAGE"))
      assert.are.equal(8079, step.item)
      snap.isDrinking = true
      local reason
      step, reason = Engine.nextStep(snap, Rules.forClass("MAGE"))
      assert.is_nil(step)
      return assert.are.equal("resting", reason)
    end)
    return it("does not start other steps while eating (a press would stand you up)", function()
      local snap = snapFor("WARRIOR", {
        isEating = true,
        player = {
          healthPct = 90,
          usesMana = false
        }
      })
      snap.spells[ID.BATTLE_SHOUT] = known("Battle Shout")
      local step, reason = Engine.nextStep(snap, Rules.forClass("WARRIOR"))
      assert.is_nil(step)
      return assert.are.equal("resting", reason)
    end)
  end)
  describe("pet phase", function()
    local petRules
    petRules = function()
      return Rules.classRules({
        role = "caster",
        rules = {
          R.conjure(5504, {
            5350
          }, 20),
          R.petStep({
            summon = {
              691,
              688
            },
            revive = 982
          })
        }
      })
    end
    it("comes before conjuring and summons the first known pet", function()
      local snap = mageSnap()
      snap.items[5350] = 0
      snap.spells[691] = {
        name = "Summon Felhunter",
        known = false
      }
      snap.spells[688] = known("Summon Imp")
      local step = Engine.nextStep(snap, petRules())
      assert.are.equal("Summon Imp", step.spell)
      return assert.are.equal("pet", step.phase)
    end)
    return it("revives a dead pet and is done when the pet is out", function()
      local snap = mageSnap()
      snap.spells[688] = known("Summon Imp")
      snap.spells[982] = known("Revive Pet")
      snap.pet = {
        exists = true,
        dead = true
      }
      assert.are.equal("Revive Pet", (Engine.nextStep(snap, petRules())).spell)
      snap.pet = {
        exists = true,
        dead = false
      }
      return assert.is_nil((Engine.nextStep(snap, petRules())))
    end)
  end)
  return describe("explain", function()
    it("lists candidates in phase order with skip reasons", function()
      local rules = Rules.forClass("MAGE")
      local snap = mageSnap({
        player = {
          healthPct = 50,
          manaPct = 50,
          usesMana = true
        }
      })
      snap.units.party1 = {
        exists = true,
        class = "PRIEST",
        usesMana = true,
        inRange = false,
        auras = { }
      }
      local entries = Engine.explain(snap, rules)
      local index = { }
      for i, p in ipairs(Engine.PHASES) do
        index[p] = i
      end
      local last = 0
      for _index_0 = 1, #entries do
        local e = entries[_index_0]
        assert.is_true(index[e.phase] >= last, tostring(e.phase) .. " out of order")
        last = index[e.phase]
      end
      assert.is_true(#entries > 5)
      for _index_0 = 1, #entries do
        local e = entries[_index_0]
        assert.is_string(Engine.formatEntry(e))
      end
    end)
    it("reports rules whose condition does not hold", function()
      local entries = Engine.explain(mageSnap(), Rules.forClass("MAGE"))
      local conds
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #entries do
          local e = entries[_index_0]
          if e.reason == "condition not met" then
            _accum_0[_len_0] = e
            _len_0 = _len_0 + 1
          end
        end
        conds = _accum_0
      end
      return assert.are.equal(1, #conds)
    end)
    return it("suppresses a just-used step and offers the next one", function()
      local rules = Rules.forClass("MAGE")
      local snap = mageSnap()
      local first = Engine.nextStep(snap, rules)
      local second = Engine.nextStep(snap, rules, {
        recent = {
          [first.key] = true
        }
      })
      return assert.are_not.equal(first.key, second.key)
    end)
  end)
end)
