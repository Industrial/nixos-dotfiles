local PATHS = {
  "src.modules.automation.upkeep.Rules",
  "src.modules.automation.upkeep.classes.HUNTER",
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
local unknown
unknown = function(name)
  return {
    name = name,
    known = false
  }
end
local aura
aura = function(name, extra)
  return merge({
    name = name
  }, extra)
end
local ID = {
  CALL_PET = 883,
  REVIVE_PET = 982,
  HAWK = 13165,
  MONKEY = 13163,
  CHEETAH = 5118,
  PACK = 13159,
  WILD = 20043,
  BEAST = 13161,
  TRUESHOT = 19506
}
local hunterSnap
hunterSnap = function(over)
  local snap = merge({
    class = "HUNTER",
    level = 60,
    now = 1000,
    inInstance = false,
    player = {
      healthPct = 100,
      manaPct = 100,
      usesMana = true
    },
    spells = {
      [ID.CALL_PET] = known("Call Pet"),
      [ID.REVIVE_PET] = known("Revive Pet"),
      [ID.HAWK] = known("Aspect of the Hawk"),
      [ID.MONKEY] = known("Aspect of the Monkey"),
      [ID.CHEETAH] = known("Aspect of the Cheetah"),
      [ID.PACK] = known("Aspect of the Pack"),
      [ID.WILD] = known("Aspect of the Wild"),
      [ID.BEAST] = known("Aspect of the Beast"),
      [ID.TRUESHOT] = unknown("Trueshot Aura")
    },
    items = { },
    itemInfo = { },
    units = {
      player = {
        exists = true,
        class = "HUNTER",
        usesMana = true,
        auras = {
          aura("Aspect of the Hawk")
        }
      },
      pet = {
        exists = true,
        auras = { }
      }
    },
    pet = {
      exists = true,
      dead = false
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
  return snap
end
return describe("Upkeep HUNTER", function()
  local Rules, Engine, rules
  before_each(function()
    Rules, Engine = load()
    rules = Rules.forClass("HUNTER")
  end)
  describe("pet", function()
    it("calls the pet when there is none", function()
      local snap = hunterSnap({
        pet = {
          exists = false,
          dead = false
        }
      })
      snap.units.pet = {
        exists = false
      }
      local step = Engine.nextStep(snap, rules)
      assert.are.equal("Call Pet", step.spell)
      return assert.are.equal("pet", step.phase)
    end)
    it("revives a dead pet instead of calling it", function()
      local snap = hunterSnap({
        pet = {
          exists = true,
          dead = true
        }
      })
      local step = Engine.nextStep(snap, rules)
      assert.are.equal("Revive Pet", step.spell)
      return assert.are.equal("pet is dead", step.reason)
    end)
    it("revives when the snapshot flags the pet dead even without a pet unit", function()
      local snap = hunterSnap({
        pet = {
          exists = false,
          dead = true
        }
      })
      local step = Engine.nextStep(snap, rules)
      return assert.are.equal("Revive Pet", step.spell)
    end)
    return it("does nothing for the pet when it is out and alive", function()
      local snap = hunterSnap()
      snap.units.player.auras = { }
      local step = Engine.nextStep(snap, rules)
      return assert.are.equal("selfLong", step.phase)
    end)
  end)
  describe("aspect", function()
    it("casts Aspect of the Hawk when no aspect is active", function()
      local snap = hunterSnap()
      snap.units.player.auras = { }
      local step = Engine.nextStep(snap, rules)
      assert.are.equal("Aspect of the Hawk", step.spell)
      return assert.are.equal("player", step.unit)
    end)
    it("falls back to Aspect of the Monkey before Hawk is learned", function()
      local snap = hunterSnap()
      snap.spells[ID.HAWK] = unknown("Aspect of the Hawk")
      snap.units.player.auras = { }
      local step = Engine.nextStep(snap, rules)
      return assert.are.equal("Aspect of the Monkey", step.spell)
    end)
    local _list_0 = {
      "Aspect of the Monkey",
      "Aspect of the Cheetah",
      "Aspect of the Pack",
      "Aspect of the Wild",
      "Aspect of the Beast"
    }
    for _index_0 = 1, #_list_0 do
      local name = _list_0[_index_0]
      it("does not recast while " .. tostring(name) .. " is active", function()
        local snap = hunterSnap()
        snap.units.player.auras = {
          aura(name)
        }
        return assert.is_nil((Engine.nextStep(snap, rules)))
      end)
    end
    return it("accepts another aspect by spell id alone", function()
      local snap = hunterSnap()
      snap.units.player.auras = {
        aura("Something", {
          spellId = ID.CHEETAH
        })
      }
      return assert.is_nil((Engine.nextStep(snap, rules)))
    end)
  end)
  describe("Trueshot Aura", function()
    it("is skipped when the talent is not known", function()
      local snap = hunterSnap()
      local step, reason = Engine.nextStep(snap, rules)
      assert.is_nil(step)
      return assert.are.equal("nothing to do", reason)
    end)
    return it("is cast after the aspect when known", function()
      local snap = hunterSnap()
      snap.spells[ID.TRUESHOT] = known("Trueshot Aura")
      local step = Engine.nextStep(snap, rules)
      return assert.are.equal("Trueshot Aura", step.spell)
    end)
  end)
  describe("complete", function()
    return it("has nothing to do with the pet out, an aspect and Trueshot Aura", function()
      local snap = hunterSnap()
      snap.spells[ID.TRUESHOT] = known("Trueshot Aura")
      snap.units.player.auras = {
        aura("Aspect of the Hawk"),
        aura("Trueshot Aura")
      }
      local step, reason = Engine.nextStep(snap, rules)
      assert.is_nil(step)
      return assert.are.equal("nothing to do", reason)
    end)
  end)
  return describe("consumables", function()
    it("uses agility / attack power but no strength sets", function()
      local sets = { }
      local _list_0 = rules.consumables
      for _index_0 = 1, #_list_0 do
        local c = _list_0[_index_0]
        sets[c.set] = true
      end
      local _list_1 = rules.foodBuffs
      for _index_0 = 1, #_list_1 do
        local c = _list_1[_index_0]
        sets[c.set] = true
      end
      assert.is_true(sets["Consumable.Buff.Agility.Self"])
      assert.is_true(sets["Consumable.Buff.Attack Power.Self"])
      assert.is_true(sets["Consumable.Food.Buff.Agility"])
      assert.is_nil(sets["Consumable.Buff.Strength.Self"])
      assert.is_nil(sets["Consumable.Buff.Strength.Flask"])
      assert.is_nil(sets["Consumable.Buff.Strength.Target"])
      assert.is_nil(sets["Consumable.Food.Buff.Strength"])
      return assert.is_nil(sets["Consumable.Buff.Intellect.Self"])
    end)
    return it("references every rule spell for the snapshot", function()
      local ids = { }
      local _list_0 = Rules.collectSpellIds(rules)
      for _index_0 = 1, #_list_0 do
        local id = _list_0[_index_0]
        ids[id] = true
      end
      for _, id in pairs(ID) do
        assert.is_true(ids[id], "missing spell " .. tostring(id))
      end
    end)
  end)
end)
