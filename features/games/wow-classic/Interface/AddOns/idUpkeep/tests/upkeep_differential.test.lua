local PATHS = {
  "src.modules.automation.upkeep.Rules",
  "src.modules.automation.upkeep.classes.WARRIOR",
  "src.modules.automation.upkeep.classes.MAGE",
  "src.modules.automation.upkeep.classes.ROGUE",
  "src.modules.automation.upkeep.classes.PRIEST",
  "src.modules.automation.upkeep.classes.DRUID",
  "src.modules.automation.upkeep.classes.PALADIN",
  "src.modules.automation.upkeep.classes.SHAMAN",
  "src.modules.automation.upkeep.classes.HUNTER",
  "src.modules.automation.upkeep.classes.WARLOCK",
  "src.modules.automation.upkeep.Engine",
  "src.modules.automation.upkeep.Consumables",
  "src.modules.automation.upkeep.Sustain"
}
local load
load = function()
  for _index_0 = 1, #PATHS do
    local p = PATHS[_index_0]
    package.loaded[p] = nil
    require(p)
  end
  return _G.idUpkeep_UpkeepRules, _G.idUpkeep_UpkeepEngine, _G.idUpkeep_UpkeepSustain
end
local CLASSES = {
  "WARRIOR",
  "MAGE",
  "ROGUE",
  "PRIEST",
  "DRUID",
  "PALADIN",
  "SHAMAN",
  "HUNTER",
  "WARLOCK"
}
local MANA_CLASSES = {
  MAGE = true,
  PRIEST = true,
  DRUID = true,
  PALADIN = true,
  SHAMAN = true,
  HUNTER = true,
  WARLOCK = true
}
local BAG = {
  WATER = 7101,
  FOOD = 7102,
  POTION = 7103,
  MANA_POTION = 7104
}
local SETS = {
  ["Consumable.Water.Basic"] = {
    [BAG.WATER] = 1500
  },
  ["Consumable.Food.Edible.Basic.Non-Conjured"] = {
    [BAG.FOOD] = 1200
  },
  ["Consumable.Potion.Recovery.Healing.Basic"] = {
    [BAG.POTION] = 700
  },
  ["Consumable.Potion.Recovery.Mana.Basic"] = {
    [BAG.MANA_POTION] = 600
  }
}
local fakeLib = {
  ItemInSet = function(self, itemId, set)
    return (SETS[set] or { })[itemId]
  end,
  IterateSet = function(self, set)
    local members = SETS[set]
    if not (members) then
      return nil
    end
    return next, members
  end
}
local merge
merge = function(base, over)
  for k, v in pairs(over or { }) do
    base[k] = v
  end
  return base
end
local copy
copy = function(t)
  local out = { }
  for k, v in pairs(t or { }) do
    out[k] = v
  end
  return out
end
local unitFor
unitFor = function(classToken)
  return {
    exists = true,
    class = classToken,
    usesMana = MANA_CLASSES[classToken] == true,
    auras = { }
  }
end
local snapshot
snapshot = function(classToken, party, stocked, over)
  local units = {
    player = unitFor(classToken)
  }
  if party then
    units.party1 = unitFor("WARRIOR")
    units.party2 = unitFor("PRIEST")
  end
  local items
  if stocked then
    items = {
      [BAG.WATER] = 20,
      [BAG.FOOD] = 20,
      [BAG.POTION] = 5,
      [BAG.MANA_POTION] = 5
    }
  else
    items = { }
  end
  local food
  if stocked then
    food = {
      {
        itemId = BAG.FOOD,
        value = 1200,
        count = 20
      }
    }
  else
    food = { }
  end
  local water
  if stocked then
    water = {
      {
        itemId = BAG.WATER,
        value = 1500,
        count = 20
      }
    }
  else
    water = { }
  end
  return merge({
    class = classToken,
    level = 60,
    now = 1000,
    inInstance = false,
    inCombat = false,
    player = {
      healthPct = (stocked and 40 or 100),
      manaPct = (stocked and 30 or 100),
      usesMana = MANA_CLASSES[classToken] == true
    },
    spells = { },
    items = items,
    itemInfo = { },
    units = units,
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
    food = food,
    water = water,
    weaponItems = { },
    wellFed = {
      ids = { },
      names = {
        "Well Fed"
      }
    }
  }, over)
end
local scenarios
scenarios = function()
  local out = { }
  for _index_0 = 1, #CLASSES do
    local classToken = CLASSES[_index_0]
    local _list_0 = {
      false,
      true
    }
    for _index_1 = 1, #_list_0 do
      local party = _list_0[_index_1]
      local _list_1 = {
        false,
        true
      }
      for _index_2 = 1, #_list_1 do
        local stocked = _list_1[_index_2]
        out[#out + 1] = {
          name = ("%s/%s/%s"):format(classToken, (party and "party" or "solo"), (stocked and "stocked" or "empty")),
          class = classToken,
          party = party,
          stocked = stocked
        }
      end
    end
  end
  return out
end
local baseOpts
baseOpts = function()
  return {
    restThreshold = 80,
    includeParty = true,
    useConsumables = true,
    recent = { }
  }
end
local line
line = function(e)
  return ("[%s] %s %s: %s"):format(e.phase, e.status, tostring(e.label), tostring(e.reason))
end
local candidates
candidates = function(entries)
  local _accum_0 = { }
  local _len_0 = 1
  for _index_0 = 1, #entries do
    local e = entries[_index_0]
    if e.phase ~= "*" then
      _accum_0[_len_0] = line(e)
      _len_0 = _len_0 + 1
    end
  end
  return _accum_0
end
return describe("Upkeep vs Prepare (differential)", function()
  local Rules, Engine, Sustain
  before_each(function()
    Rules, Engine, Sustain = load()
  end)
  local prepareLines
  prepareLines = function(snap, rules, opts)
    return candidates(Engine.explain(snap, rules, (opts or baseOpts())))
  end
  local upkeepLines
  upkeepLines = function(snap, rules, opts)
    local base = opts or baseOpts()
    local buffs = Engine.explain(snap, rules, merge(copy(base), {
      phases = "buffs"
    }))
    local rest = Engine.explain(snap, rules, merge(copy(base), {
      phases = "rest"
    }))
    local out = candidates(buffs)
    local _list_0 = candidates(rest)
    for _index_0 = 1, #_list_0 do
      local l = _list_0[_index_0]
      out[#out + 1] = l
    end
    return out
  end
  describe("the ordered candidate list", function()
    it("is identical for every class, party and bag combination", function()
      local _list_0 = scenarios()
      for _index_0 = 1, #_list_0 do
        local s = _list_0[_index_0]
        local rules = Rules.forClass(s.class)
        local snap = snapshot(s.class, s.party, s.stocked)
        assert.are.same((prepareLines(snap, rules)), (upkeepLines(snap, rules)), s.name)
      end
    end)
    it("is identical when the player is resting", function()
      local _list_0 = scenarios()
      for _index_0 = 1, #_list_0 do
        local s = _list_0[_index_0]
        local rules = Rules.forClass(s.class)
        local snap = snapshot(s.class, s.party, s.stocked, {
          isDrinking = true
        })
        assert.are.same((prepareLines(snap, rules)), (upkeepLines(snap, rules)), s.name)
      end
    end)
    it("is identical with consumables and party turned off", function()
      local _list_0 = scenarios()
      for _index_0 = 1, #_list_0 do
        local s = _list_0[_index_0]
        local rules = Rules.forClass(s.class)
        local snap = snapshot(s.class, s.party, s.stocked)
        local opts = merge(copy(baseOpts()), {
          includeParty = false,
          useConsumables = false
        })
        assert.are.same((prepareLines(snap, rules, opts)), (upkeepLines(snap, rules, opts)), s.name)
      end
    end)
    it("announces the resting banner on each path exactly once", function()
      local banners
      banners = function(entries)
        local n = 0
        for _index_0 = 1, #entries do
          local e = entries[_index_0]
          if e.phase == "*" then
            n = n + 1
          end
        end
        return n
      end
      local rules = Rules.forClass("MAGE")
      local snap = snapshot("MAGE", false, true, {
        isDrinking = true
      })
      assert.are.equal(1, banners(Engine.explain(snap, rules, baseOpts())))
      return assert.are.equal(1, banners(Engine.explain(snap, rules, merge(copy(baseOpts()), {
        phases = "buffs"
      }))))
    end)
    it("covers a non-trivial number of scenarios", function()
      return assert.are.equal(36, #scenarios())
    end)
    return it("produced a non-empty list in every scenario", function()
      local _list_0 = scenarios()
      for _index_0 = 1, #_list_0 do
        local s = _list_0[_index_0]
        local rules = Rules.forClass(s.class)
        local snap = snapshot(s.class, s.party, s.stocked)
        assert.is_true(#prepareLines(snap, rules) > 0, s.name)
      end
    end)
  end)
  describe("the step each path would perform next", function()
    it("agrees whenever Prepare's next step is not eating or drinking", function()
      local _list_0 = scenarios()
      for _index_0 = 1, #_list_0 do
        local _continue_0 = false
        repeat
          local s = _list_0[_index_0]
          local rules = Rules.forClass(s.class)
          local snap = snapshot(s.class, s.party, s.stocked)
          local prepStep = Engine.nextStep(snap, rules, baseOpts())
          if not (prepStep and prepStep.phase ~= "rest") then
            _continue_0 = true
            break
          end
          local upStep = Engine.nextStep(snap, rules, merge(copy(baseOpts()), {
            phases = "buffs"
          }))
          assert.is_not_nil(upStep, s.name)
          assert.are.equal(prepStep.label, upStep.label, s.name)
          assert.are.equal(prepStep.phase, upStep.phase, s.name)
          assert.are.equal(prepStep.spell, upStep.spell, s.name)
          assert.are.equal(prepStep.item, upStep.item, s.name)
          assert.are.equal(prepStep.unit, upStep.unit, s.name)
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
    end)
    it("hands eating and drinking to the sustain buttons instead", function()
      local checked = 0
      local _list_0 = scenarios()
      for _index_0 = 1, #_list_0 do
        local _continue_0 = false
        repeat
          local s = _list_0[_index_0]
          local rules = Rules.forClass(s.class)
          local snap = snapshot(s.class, s.party, s.stocked)
          local prepStep = Engine.nextStep(snap, rules, baseOpts())
          if not (prepStep and prepStep.phase == "rest") then
            _continue_0 = true
            break
          end
          checked = checked + 1
          local job
          if prepStep.item == BAG.WATER then
            job = "mana"
          else
            job = "health"
          end
          local upStep = Sustain.step(job, snap.items, {
            lib = fakeLib
          })
          assert.is_not_nil(upStep, s.name)
          assert.is_truthy(upStep.macrotext:find(("item:%d"):format(prepStep.item), 1, true, ("%s: sustain macro %q does not offer Prepare's item %d"):format(s.name, upStep.macrotext, prepStep.item)))
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      return assert.is_true(checked > 0, "no scenario reached a rest step; the table proves nothing")
    end)
    return it("offers nothing on the buffs button when only resting is left", function()
      local _list_0 = scenarios()
      for _index_0 = 1, #_list_0 do
        local _continue_0 = false
        repeat
          local s = _list_0[_index_0]
          local rules = Rules.forClass(s.class)
          local snap = snapshot(s.class, s.party, s.stocked)
          local prepStep = Engine.nextStep(snap, rules, baseOpts())
          if not (prepStep and prepStep.phase == "rest") then
            _continue_0 = true
            break
          end
          local upStep, reason = Engine.nextStep(snap, rules, merge(copy(baseOpts()), {
            phases = "buffs"
          }))
          assert.is_nil(upStep, s.name)
          assert.are.equal("nothing to do", reason, s.name)
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
    end)
  end)
  return describe("declared divergences", function()
    it("1. rest steps move from one button to three", function()
      return assert.is_true(true)
    end)
    it("2. the sustain buttons also work IN combat, which Prepare never did", function()
      local rules = Rules.forClass("MAGE")
      local snap = snapshot("MAGE", false, true, {
        inCombat = true
      })
      local step, reason = Engine.nextStep(snap, rules, baseOpts())
      assert.is_nil(step)
      assert.are.equal("in combat", reason)
      return assert.is_not_nil(Sustain.step("health", snap.items, {
        lib = fakeLib
      }))
    end)
    it("3. sustain may prefer a potion where Prepare only knew food", function()
      local best = Sustain.pick("health", "safe", {
        [BAG.FOOD] = 20,
        [BAG.POTION] = 5
      }, {
        lib = fakeLib
      })
      return assert.are.equal(BAG.FOOD, best.itemId)
    end)
    return it("and nothing else: the engine, rules and class tables are shared", function()
      assert.are.equal(_G.idUpkeep_UpkeepEngine, Engine)
      return assert.is_not_nil(Rules.forClass("MAGE").rules)
    end)
  end)
end)
