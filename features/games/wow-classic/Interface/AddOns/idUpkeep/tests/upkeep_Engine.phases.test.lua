local _list_0 = {
  "src.modules.automation.upkeep.Rules",
  "src.modules.automation.upkeep.classes.MAGE",
  "src.modules.automation.upkeep.Engine"
}
for _index_0 = 1, #_list_0 do
  local mod = _list_0[_index_0]
  require(mod)
end
local Engine = _G.idUpkeep_UpkeepEngine
local Rules = _G.idUpkeep_UpkeepRules
local MAGE = _G.idUpkeep_UpkeepClassMAGE
local snapshot
snapshot = function(overrides)
  if overrides == nil then
    overrides = { }
  end
  local spells = { }
  local _list_1 = {
    MAGE.SPELL.FROST_ARMOR,
    MAGE.SPELL.ICE_ARMOR,
    MAGE.SPELL.MAGE_ARMOR,
    MAGE.SPELL.ARCANE_INTELLECT,
    MAGE.SPELL.CONJURE_WATER,
    MAGE.SPELL.CONJURE_FOOD
  }
  for _index_0 = 1, #_list_1 do
    local id = _list_1[_index_0]
    spells[id] = {
      known = true,
      name = "Spell " .. tostring(id),
      usable = true
    }
  end
  local snap = {
    classToken = "MAGE",
    level = 60,
    inCombat = false,
    inInstance = false,
    player = {
      dead = false,
      usesMana = true,
      healthPct = 40,
      manaPct = 20
    },
    units = { },
    auras = {
      player = { }
    },
    spells = spells,
    items = { },
    itemInfo = { },
    consumables = { },
    foodBuffs = { },
    food = { },
    water = { },
    weaponItems = { }
  }
  for k, v in pairs(overrides) do
    snap[k] = v
  end
  return snap
end
local phasesIn
phasesIn = function(entries)
  local seen = { }
  for _index_0 = 1, #entries do
    local e = entries[_index_0]
    seen[e.phase] = true
  end
  return seen
end
local rules
rules = function()
  return Rules.forClass("MAGE")
end
return describe("Engine phase filter", function()
  describe("no filter", function()
    it("considers every phase, which is what Prepare asks for", function()
      local seen = phasesIn(Engine.explain(snapshot(), rules(), { }))
      assert.is_true(seen.selfLong)
      assert.is_true(seen.conjure)
      return assert.is_true(seen.rest)
    end)
    return it("behaves identically whether opts omits phases or sets it to nil", function()
      local a = Engine.explain(snapshot(), rules(), { })
      local b = Engine.explain(snapshot(), rules(), {
        phases = nil
      })
      return assert.are.equal(#a, #b)
    end)
  end)
  describe("a named group", function()
    it("drops the rest phase from the buffs group", function()
      local seen = phasesIn(Engine.explain(snapshot(), rules(), {
        phases = "buffs"
      }))
      assert.is_nil(seen.rest)
      return assert.is_true(seen.selfLong)
    end)
    it("keeps only the rest phase for the rest group", function()
      local seen = phasesIn(Engine.explain(snapshot(), rules(), {
        phases = "rest"
      }))
      assert.is_true(seen.rest)
      assert.is_nil(seen.selfLong)
      return assert.is_nil(seen.conjure)
    end)
    it("covers every phase between the two groups", function()
      local covered = { }
      local _list_1 = {
        "buffs",
        "rest"
      }
      for _index_0 = 1, #_list_1 do
        local group = _list_1[_index_0]
        local _list_2 = Engine.PHASE_GROUPS[group]
        for _index_1 = 1, #_list_2 do
          local name = _list_2[_index_1]
          covered[name] = true
        end
      end
      local _list_2 = Engine.PHASES
      for _index_0 = 1, #_list_2 do
        local phase = _list_2[_index_0]
        assert.is_true(covered[phase], ("phase %q is in no group"):format(phase))
      end
    end)
    return it("puts no phase in both groups", function()
      local buffs = { }
      local _list_1 = Engine.PHASE_GROUPS.buffs
      for _index_0 = 1, #_list_1 do
        local name = _list_1[_index_0]
        buffs[name] = true
      end
      local _list_2 = Engine.PHASE_GROUPS.rest
      for _index_0 = 1, #_list_2 do
        local name = _list_2[_index_0]
        assert.is_nil(buffs[name], ("phase %q is in both groups"):format(name))
      end
    end)
  end)
  describe("an explicit list", function()
    it("accepts phase names directly", function()
      local seen = phasesIn(Engine.explain(snapshot(), rules(), {
        phases = {
          "conjure"
        }
      }))
      assert.is_true(seen.conjure)
      return assert.is_nil(seen.selfLong)
    end)
    return it("ignores an unknown group name rather than filtering everything out", function()
      local seen = phasesIn(Engine.explain(snapshot(), rules(), {
        phases = "nonsense"
      }))
      assert.is_true(seen.selfLong)
      return assert.is_true(seen.rest)
    end)
  end)
  describe("phaseFilter", function()
    it("is nil for no filter", function()
      assert.is_nil(Engine.phaseFilter(nil))
      return assert.is_nil(Engine.phaseFilter(false))
    end)
    it("turns a group name into a set", function()
      local set = Engine.phaseFilter("rest")
      assert.is_true(set.rest)
      return assert.is_nil(set.selfLong)
    end)
    return it("turns a list into a set", function()
      local set = Engine.phaseFilter({
        "weapon",
        "group"
      })
      assert.is_true(set.weapon)
      assert.is_true(set.group)
      return assert.is_nil(set.rest)
    end)
  end)
  return describe("nextStep under a filter", function()
    it("never returns a rest step to the buffs button", function()
      local snap = snapshot({
        items = {
          [7001] = 20
        }
      })
      local step = Engine.nextStep(snap, rules(), {
        phases = "buffs"
      })
      assert.is_truthy(step)
      return assert.are_not.equal("rest", step.phase)
    end)
    it("reports nothing to do rather than erroring when the filter empties", function()
      local step, reason = Engine.nextStep(snapshot(), rules(), {
        phases = {
          "weapon"
        }
      })
      assert.is_nil(step)
      return assert.is_truthy(reason)
    end)
    return it("still refuses everything in combat, filter or not", function()
      local snap = snapshot({
        inCombat = true
      })
      local _list_1 = {
        "buffs",
        "rest"
      }
      for _index_0 = 1, #_list_1 do
        local phases = _list_1[_index_0]
        local step, reason = Engine.nextStep(snap, rules(), {
          phases = phases
        })
        assert.is_nil(step)
        assert.are.equal("in combat", reason)
      end
    end)
  end)
end)
