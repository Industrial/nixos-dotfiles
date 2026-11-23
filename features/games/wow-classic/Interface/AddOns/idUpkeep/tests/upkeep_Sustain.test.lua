local _list_0 = {
  "src.modules.automation.upkeep.Rules",
  "src.modules.automation.upkeep.Consumables",
  "src.modules.automation.upkeep.Sustain"
}
for _index_0 = 1, #_list_0 do
  local mod = _list_0[_index_0]
  require(mod)
end
local Sustain = _G.idUpkeep_UpkeepSustain
local ITEM = {
  CONJURED_WATER = 7001,
  SPRING_WATER = 7002,
  BREAD = 7003,
  CONJURED_BREAD = 7004,
  BANDAGE = 7005,
  HEALTHSTONE = 7006,
  HEALING_POTION = 7007,
  MANA_POTION = 7008,
  MANA_GEM = 7009
}
local SETS = {
  ["Consumable.Water.Conjured"] = {
    [ITEM.CONJURED_WATER] = 1800
  },
  ["Consumable.Water.Basic"] = {
    [ITEM.SPRING_WATER] = 1500
  },
  ["Consumable.Food.Edible.Basic.Conjured"] = {
    [ITEM.CONJURED_BREAD] = 1200
  },
  ["Consumable.Food.Edible.Basic.Non-Conjured"] = {
    [ITEM.BREAD] = 800
  },
  ["Consumable.Bandage.Basic"] = {
    [ITEM.BANDAGE] = 400
  },
  ["Consumable.Cooldown.Stone.Health.Warlock"] = {
    [ITEM.HEALTHSTONE] = 500
  },
  ["Consumable.Potion.Recovery.Healing.Basic"] = {
    [ITEM.HEALING_POTION] = 700
  },
  ["Consumable.Cooldown.Stone.Mana.Mana Stone"] = {
    [ITEM.MANA_GEM] = 900
  },
  ["Consumable.Potion.Recovery.Mana.Basic"] = {
    [ITEM.MANA_POTION] = 600
  }
}
local fakeLib
fakeLib = function(sets)
  if sets == nil then
    sets = SETS
  end
  return {
    ItemInSet = function(self, itemId, set)
      return (sets[set] or { })[itemId]
    end,
    IterateSet = function(self, set)
      local members = sets[set]
      if not (members) then
        return nil
      end
      return next, members
    end
  }
end
local ctx
ctx = function(overrides)
  if overrides == nil then
    overrides = { }
  end
  local c = {
    lib = fakeLib()
  }
  for k, v in pairs(overrides) do
    c[k] = v
  end
  return c
end
return describe("Upkeep.Sustain", function()
  describe("the two-branch macro", function()
    it("carries BOTH branches when both exist", function()
      local counts = {
        [ITEM.HEALING_POTION] = 5,
        [ITEM.BREAD] = 20
      }
      local text = Sustain.macroFor("health", counts, ctx())
      assert.is_truthy(text:find("[combat]", 1, true))
      assert.is_truthy(text:find(("item:%d"):format(ITEM.HEALING_POTION), 1, true))
      return assert.is_truthy(text:find(("item:%d"):format(ITEM.BREAD), 1, true))
    end)
    it("puts the combat item FIRST, which is what [combat] selects", function()
      local counts = {
        [ITEM.HEALING_POTION] = 5,
        [ITEM.BREAD] = 20
      }
      local text = Sustain.macroFor("health", counts, ctx())
      return assert.are.equal(("/use [combat] item:%d; item:%d"):format(ITEM.HEALING_POTION, ITEM.BREAD), text)
    end)
    it("does the same for mana", function()
      local counts = {
        [ITEM.MANA_POTION] = 5,
        [ITEM.SPRING_WATER] = 20
      }
      local text = Sustain.macroFor("mana", counts, ctx())
      return assert.are.equal(("/use [combat] item:%d; item:%d"):format(ITEM.MANA_POTION, ITEM.SPRING_WATER), text)
    end)
    it("guards a bags-only-potion case so it cannot eat out of combat", function()
      local text = Sustain.macroFor("health", {
        [ITEM.HEALING_POTION] = 1
      }, ctx())
      return assert.are.equal(("/use [combat] item:%d"):format(ITEM.HEALING_POTION), text)
    end)
    it("guards a bags-only-food case so it cannot sit down in combat", function()
      local text = Sustain.macroFor("health", {
        [ITEM.BREAD] = 20
      }, ctx())
      return assert.are.equal(("/use [nocombat] item:%d"):format(ITEM.BREAD), text)
    end)
    it("is nil with nothing usable in the bags", function()
      assert.is_nil(Sustain.macroFor("health", { }, ctx()))
      return assert.is_nil(Sustain.macroFor("health", {
        [99999] = 5
      }, ctx()))
    end)
    return it("is nil for a job that does not exist", function()
      return assert.is_nil(Sustain.macroFor("stamina", {
        [ITEM.BREAD] = 5
      }, ctx()))
    end)
  end)
  describe("what it picks out of combat", function()
    it("prefers food over a bandage", function()
      local best = Sustain.pick("health", "safe", {
        [ITEM.BREAD] = 20,
        [ITEM.BANDAGE] = 10
      }, ctx())
      return assert.are.equal(ITEM.BREAD, best.itemId)
    end)
    it("falls back to a bandage with no food", function()
      local best = Sustain.pick("health", "safe", {
        [ITEM.BANDAGE] = 10
      }, ctx())
      assert.are.equal(ITEM.BANDAGE, best.itemId)
      return assert.is_true(best.bandage)
    end)
    it("prefers conjured water, which costs nothing to replace", function()
      local best = Sustain.pick("mana", "safe", {
        [ITEM.CONJURED_WATER] = 20,
        [ITEM.SPRING_WATER] = 20
      }, ctx())
      return assert.are.equal(ITEM.CONJURED_WATER, best.itemId)
    end)
    return it("never offers a bandage in combat", function()
      local best = Sustain.pick("health", "combat", {
        [ITEM.BANDAGE] = 10
      }, ctx())
      return assert.is_nil(best)
    end)
  end)
  describe("conjured first, always", function()
    local STRONG_REAL, WEAK_CONJURED = 7301, 7302
    local conjuredSets = {
      ["Consumable.Water.Conjured"] = {
        [WEAK_CONJURED] = 900
      },
      ["Consumable.Water.Basic"] = {
        [STRONG_REAL] = 1800
      }
    }
    it("uses the conjured one even though the real one restores twice as much", function()
      local best = Sustain.pick("mana", "safe", {
        [WEAK_CONJURED] = 5,
        [STRONG_REAL] = 20
      }, {
        lib = fakeLib(conjuredSets)
      })
      assert.are.equal(WEAK_CONJURED, best.itemId)
      return assert.is_true(best.conjured)
    end)
    it("falls through to the real one once the conjured is gone", function()
      local best = Sustain.pick("mana", "safe", {
        [STRONG_REAL] = 20
      }, {
        lib = fakeLib(conjuredSets)
      })
      return assert.are.equal(STRONG_REAL, best.itemId)
    end)
    it("recognises a conjured item the SET DATA calls plain water", function()
      local flat = {
        ["Consumable.Water.Basic"] = {
          [WEAK_CONJURED] = 900,
          [STRONG_REAL] = 1800
        }
      }
      local names = {
        [WEAK_CONJURED] = "Conjured Crystal Water",
        [STRONG_REAL] = "Sweet Nectar"
      }
      local best = Sustain.pick("mana", "safe", {
        [WEAK_CONJURED] = 5,
        [STRONG_REAL] = 20
      }, {
        lib = fakeLib(flat),
        itemName = function(id)
          return names[id]
        end
      })
      assert.are.equal(WEAK_CONJURED, best.itemId)
      return assert.is_true(best.conjured)
    end)
    it("is not fooled by a name that merely mentions conjuring", function()
      assert.is_true(Sustain.isConjuredName("Conjured Croissant"))
      assert.is_true(Sustain.isConjuredName("conjured water"))
      assert.is_false(Sustain.isConjuredName("Sweet Nectar"))
      assert.is_false(Sustain.isConjuredName(nil))
      return assert.is_false(Sustain.isConjuredName(42))
    end)
    it("does the same for food", function()
      local sets = {
        ["Consumable.Food.Edible.Basic.Conjured"] = {
          [8701] = 800
        },
        ["Consumable.Food.Edible.Basic.Non-Conjured"] = {
          [8702] = 2000
        }
      }
      local best = Sustain.pick("health", "safe", {
        [8701] = 5,
        [8702] = 20
      }, {
        lib = fakeLib(sets)
      })
      return assert.are.equal(8701, best.itemId)
    end)
    it("still keeps food ahead of a bandage that heals more", function()
      local sets = {
        ["Consumable.Food.Edible.Basic.Non-Conjured"] = {
          [8801] = 500
        },
        ["Consumable.Bandage.Basic"] = {
          [8802] = 2000
        }
      }
      local best = Sustain.pick("health", "safe", {
        [8801] = 5,
        [8802] = 5
      }, {
        lib = fakeLib(sets)
      })
      return assert.are.equal(8801, best.itemId)
    end)
    it("still keeps a healthstone ahead of a stronger potion", function()
      local sets = {
        ["Consumable.Cooldown.Stone.Health.Warlock"] = {
          [8901] = 500
        },
        ["Consumable.Potion.Recovery.Healing.Basic"] = {
          [8902] = 2000
        }
      }
      local best = Sustain.pick("health", "combat", {
        [8901] = 1,
        [8902] = 5
      }, {
        lib = fakeLib(sets)
      })
      return assert.are.equal(8901, best.itemId)
    end)
    it("puts the conjured item in the macro's safe branch", function()
      local step = Sustain.step("mana", {
        [WEAK_CONJURED] = 5,
        [STRONG_REAL] = 20
      }, {
        lib = fakeLib(conjuredSets)
      })
      return assert.are.equal(WEAK_CONJURED, step.chosen.safe.itemId)
    end)
    return it("ranks two conjured items among themselves by restore amount", function()
      local sets = {
        ["Consumable.Water.Conjured"] = {
          [9001] = 900,
          [9002] = 1800
        }
      }
      local best = Sustain.pick("mana", "safe", {
        [9001] = 5,
        [9002] = 5
      }, {
        lib = fakeLib(sets)
      })
      return assert.are.equal(9002, best.itemId)
    end)
  end)
  describe("what it picks in combat", function()
    it("prefers a healthstone over a potion", function()
      local best = Sustain.pick("health", "combat", {
        [ITEM.HEALTHSTONE] = 1,
        [ITEM.HEALING_POTION] = 5
      }, ctx())
      return assert.are.equal(ITEM.HEALTHSTONE, best.itemId)
    end)
    it("prefers a mana gem over a mana potion", function()
      local best = Sustain.pick("mana", "combat", {
        [ITEM.MANA_GEM] = 1,
        [ITEM.MANA_POTION] = 5
      }, ctx())
      return assert.are.equal(ITEM.MANA_GEM, best.itemId)
    end)
    return it("takes the potion when there is no stone", function()
      local best = Sustain.pick("health", "combat", {
        [ITEM.HEALING_POTION] = 5
      }, ctx())
      return assert.are.equal(ITEM.HEALING_POTION, best.itemId)
    end)
  end)
  describe("choosing between equals", function()
    it("prefers the item that restores more", function()
      local sets = {
        ["Consumable.Water.Basic"] = {
          [101] = 1000,
          [102] = 1500
        }
      }
      local best = Sustain.pick("mana", "safe", {
        [101] = 20,
        [102] = 20
      }, {
        lib = fakeLib(sets)
      })
      return assert.are.equal(102, best.itemId)
    end)
    it("breaks a tie by the SMALLER stack (Buffet's behaviour)", function()
      local sets = {
        ["Consumable.Water.Basic"] = {
          [101] = 1500,
          [102] = 1500
        }
      }
      local best = Sustain.pick("mana", "safe", {
        [101] = 20,
        [102] = 3
      }, {
        lib = fakeLib(sets)
      })
      return assert.are.equal(102, best.itemId)
    end)
    it("breaks a remaining tie by the lower id, so sessions agree", function()
      local sets = {
        ["Consumable.Water.Basic"] = {
          [101] = 1500,
          [102] = 1500
        }
      }
      local best = Sustain.pick("mana", "safe", {
        [101] = 5,
        [102] = 5
      }, {
        lib = fakeLib(sets)
      })
      return assert.are.equal(101, best.itemId)
    end)
    return it("still prefers more restored over a smaller stack", function()
      local sets = {
        ["Consumable.Water.Basic"] = {
          [101] = 1500,
          [102] = 800
        }
      }
      local best = Sustain.pick("mana", "safe", {
        [101] = 20,
        [102] = 1
      }, {
        lib = fakeLib(sets)
      })
      return assert.are.equal(101, best.itemId)
    end)
  end)
  describe("usability", function()
    it("skips an item the client says is not usable yet", function()
      local c = ctx({
        usable = function(id)
          return id ~= ITEM.HEALING_POTION
        end
      })
      local best = Sustain.pick("health", "combat", {
        [ITEM.HEALING_POTION] = 5,
        [ITEM.HEALTHSTONE] = 1
      }, c)
      return assert.are.equal(ITEM.HEALTHSTONE, best.itemId)
    end)
    it("treats unknown usability as usable, since the cache fills in late", function()
      local c = ctx({
        usable = function()
          return nil
        end
      })
      local best = Sustain.pick("health", "combat", {
        [ITEM.HEALING_POTION] = 5
      }, c)
      return assert.are.equal(ITEM.HEALING_POTION, best.itemId)
    end)
    return it("survives a usable callback that errors", function()
      local c = ctx({
        usable = function()
          return error("boom")
        end
      })
      local best = Sustain.pick("health", "combat", {
        [ITEM.HEALING_POTION] = 5
      }, c)
      return assert.are.equal(ITEM.HEALING_POTION, best.itemId)
    end)
  end)
  describe("no library", function()
    return it("picks nothing rather than erroring", function()
      assert.is_nil(Sustain.pick("health", "safe", {
        [ITEM.BREAD] = 5
      }, { }))
      return assert.is_nil(Sustain.macroFor("health", {
        [ITEM.BREAD] = 5
      }, { }))
    end)
  end)
  describe("the step it hands the button", function()
    it("is a macro step, because a conditional cannot be an item attribute", function()
      local step = Sustain.step("health", {
        [ITEM.HEALING_POTION] = 5,
        [ITEM.BREAD] = 20
      }, ctx())
      assert.are.equal("macro", step.kind)
      return assert.is_truthy(step.macrotext:find("[combat]", 1, true))
    end)
    it("says which branches it found", function()
      local step = Sustain.step("health", {
        [ITEM.HEALING_POTION] = 5,
        [ITEM.BREAD] = 20
      }, ctx())
      assert.are.equal("health: combat + safe", step.label)
      assert.are.equal(ITEM.HEALING_POTION, step.chosen.combat.itemId)
      return assert.are.equal(ITEM.BREAD, step.chosen.safe.itemId)
    end)
    it("labels a one-branch macro honestly", function()
      assert.are.equal("health: combat only", (Sustain.step("health", {
        [ITEM.HEALING_POTION] = 5
      }, ctx())).label)
      return assert.are.equal("health: out of combat only", (Sustain.step("health", {
        [ITEM.BREAD] = 5
      }, ctx())).label)
    end)
    it("keys the step by its macro, so a changed choice is not `recent`", function()
      local a = Sustain.step("health", {
        [ITEM.BREAD] = 20
      }, ctx())
      local b = Sustain.step("health", {
        [ITEM.HEALING_POTION] = 5
      }, ctx())
      return assert.are_not.equal(a.key, b.key)
    end)
    it("returns nil and a reason with empty bags", function()
      local step, reason = Sustain.step("health", { }, ctx())
      assert.is_nil(step)
      return assert.is_truthy(reason:find("nothing for health", 1, true))
    end)
    return it("round-trips through Button into a macro attribute", function()
      local Button = require("src.modules.automation.upkeep.Button")
      local step = Sustain.step("mana", {
        [ITEM.MANA_POTION] = 5,
        [ITEM.SPRING_WATER] = 20
      }, ctx())
      local attrs = Button.attrsFor(step)
      assert.are.equal("macro", attrs.type)
      assert.are.equal(step.macrotext, attrs.macrotext)
      return assert.is_nil(attrs.item)
    end)
  end)
  describe("explaining itself", function()
    it("names both branches and the macro", function()
      local lines = Sustain.explain("health", {
        [ITEM.HEALING_POTION] = 5,
        [ITEM.BREAD] = 20
      }, ctx())
      local joined = table.concat(lines, "\n")
      assert.is_truthy(joined:find("combat", 1, true))
      assert.is_truthy(joined:find("safe", 1, true))
      return assert.is_truthy(joined:find("macro", 1, true))
    end)
    it("says a branch is empty rather than omitting it", function()
      local lines = Sustain.explain("health", {
        [ITEM.BREAD] = 20
      }, ctx())
      return assert.is_truthy((table.concat(lines, "\n")):find("nothing in the bags", 1, true))
    end)
    return it("explains having nothing at all", function()
      local lines = Sustain.explain("health", { }, ctx())
      assert.are.equal(1, #lines)
      return assert.is_truthy(lines[1]:find("nothing", 1, true))
    end)
  end)
  return describe("set names, not item ids", function()
    it("names only sets both libraries define", function()
      for job, spec in pairs(Sustain.SETS) do
        local _list_1 = {
          "safe",
          "combat"
        }
        for _index_0 = 1, #_list_1 do
          local branch = _list_1[_index_0]
          local _list_2 = spec[branch]
          for _index_1 = 1, #_list_2 do
            local def = _list_2[_index_1]
            assert.is_string(def.set)
            assert.is_truthy((def.set:match("^Consumable%.")), ("%s/%s has a non-consumable set name %q"):format(job, branch, def.set))
          end
        end
      end
    end)
    return it("covers both jobs in both branches", function()
      local _list_1 = {
        "health",
        "mana"
      }
      for _index_0 = 1, #_list_1 do
        local job = _list_1[_index_0]
        assert.is_true(#Sustain.SETS[job].safe > 0)
        assert.is_true(#Sustain.SETS[job].combat > 0)
      end
    end)
  end)
end)
