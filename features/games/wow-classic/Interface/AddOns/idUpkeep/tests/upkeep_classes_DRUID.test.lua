local PATHS = {
  "src.modules.automation.upkeep.Rules",
  "src.modules.automation.upkeep.classes.DRUID",
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
  MARK_OF_THE_WILD = 1126,
  GIFT_OF_THE_WILD = 21849,
  THORNS = 467,
  OMEN_OF_CLARITY = 16864
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
      usesMana = true
    },
    spells = { },
    items = { },
    itemInfo = { },
    units = {
      player = {
        exists = true,
        class = classToken,
        usesMana = true,
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
local druidSnap
druidSnap = function(over)
  local snap = snapFor("DRUID", over)
  local _update_0 = ID.MARK_OF_THE_WILD
  snap.spells[_update_0] = snap.spells[_update_0] or known("Mark of the Wild")
  local _update_1 = ID.GIFT_OF_THE_WILD
  snap.spells[_update_1] = snap.spells[_update_1] or unknown("Gift of the Wild")
  local _update_2 = ID.THORNS
  snap.spells[_update_2] = snap.spells[_update_2] or known("Thorns")
  local _update_3 = ID.OMEN_OF_CLARITY
  snap.spells[_update_3] = snap.spells[_update_3] or unknown("Omen of Clarity")
  return snap
end
local doSteps
doSteps = function(Engine, snap, rules)
  local _accum_0 = { }
  local _len_0 = 1
  local _list_0 = Engine.explain(snap, rules)
  for _index_0 = 1, #_list_0 do
    local e = _list_0[_index_0]
    if e.status == "do" then
      _accum_0[_len_0] = tostring(e.step.spell) .. "@" .. tostring(e.step.unit)
      _len_0 = _len_0 + 1
    end
  end
  return _accum_0
end
return describe("Upkeep DRUID", function()
  local Rules, Engine
  before_each(function()
    Rules, Engine = load()
  end)
  it("registers as a hybrid", function()
    return assert.are.equal("hybrid", Rules.forClass("DRUID").role)
  end)
  it("orders Mark of the Wild -> Thorns -> Omen of Clarity on self, then Mark on party and pet", function()
    local snap = druidSnap()
    snap.spells[ID.OMEN_OF_CLARITY] = known("Omen of Clarity")
    snap.units.party1 = {
      exists = true,
      class = "WARRIOR",
      usesMana = false,
      auras = { }
    }
    snap.units.pet = {
      exists = true,
      usesMana = false,
      auras = { }
    }
    return assert.are.same({
      "Mark of the Wild@player",
      "Thorns@player",
      "Omen of Clarity@player",
      "Mark of the Wild@party1",
      "Mark of the Wild@pet"
    }, doSteps(Engine, snap, Rules.forClass("DRUID")))
  end)
  it("gives Mark of the Wild to non-mana party members too, Thorns stays self only", function()
    local snap = druidSnap()
    snap.units.player.auras = {
      aura("Mark of the Wild"),
      aura("Thorns")
    }
    snap.units.party1 = {
      exists = true,
      class = "ROGUE",
      usesMana = false,
      auras = { }
    }
    return assert.are.same({
      "Mark of the Wild@party1"
    }, doSteps(Engine, snap, Rules.forClass("DRUID")))
  end)
  it("skips buffs already active (Gift of the Wild satisfies Mark)", function()
    local snap = druidSnap()
    snap.units.player.auras = {
      aura("Gift of the Wild"),
      aura("Thorns")
    }
    snap.units.party1 = {
      exists = true,
      class = "MAGE",
      usesMana = true,
      auras = {
        aura("Mark of the Wild")
      }
    }
    local step, reason = Engine.nextStep(snap, Rules.forClass("DRUID"))
    assert.is_nil(step)
    return assert.are.equal("nothing to do", reason)
  end)
  it("skips Omen of Clarity when the talent is not known", function()
    local snap = druidSnap()
    snap.units.player.auras = {
      aura("Mark of the Wild"),
      aura("Thorns")
    }
    local reasons = { }
    local _list_0 = Engine.explain(snap, Rules.forClass("DRUID"))
    for _index_0 = 1, #_list_0 do
      local e = _list_0[_index_0]
      reasons[e.label] = e.reason
    end
    assert.are.equal("spell not known", reasons["Omen of Clarity"])
    return assert.is_nil((Engine.nextStep(snap, Rules.forClass("DRUID"))))
  end)
  describe("shapeshift forms", function()
    it("marks the step cancelForm while shapeshifted", function()
      local snap = druidSnap({
        shapeshiftForm = 1
      })
      local step = Engine.nextStep(snap, Rules.forClass("DRUID"))
      assert.are.equal("Mark of the Wild", step.spell)
      return assert.is_true(step.cancelForm)
    end)
    it("marks every offered step, item steps included", function()
      local snap = druidSnap({
        shapeshiftForm = 3
      })
      snap.units.player.auras = {
        aura("Mark of the Wild"),
        aura("Thorns")
      }
      snap.player = {
        healthPct = 10,
        manaPct = 100,
        usesMana = true
      }
      snap.food = {
        {
          itemId = 8932,
          count = 5,
          value = 1
        }
      }
      local step = Engine.nextStep(snap, Rules.forClass("DRUID"))
      assert.are.equal("item", step.kind)
      assert.is_true(step.cancelForm)
      local _list_0 = Engine.explain(snap, Rules.forClass("DRUID"))
      for _index_0 = 1, #_list_0 do
        local e = _list_0[_index_0]
        if e.step then
          assert.is_true(e.step.cancelForm)
        end
      end
    end)
    it("leaves the step plain in caster form (form 0 or unknown)", function()
      local _list_0 = {
        0,
        false
      }
      for _index_0 = 1, #_list_0 do
        local form = _list_0[_index_0]
        local snap = druidSnap({
          shapeshiftForm = (form or nil)
        })
        local step = Engine.nextStep(snap, Rules.forClass("DRUID"))
        assert.are.equal("Mark of the Wild", step.spell)
        assert.is_nil(step.cancelForm)
      end
    end)
    return it("never marks other classes (warrior stances are forms too)", function()
      local snap = snapFor("WARRIOR", {
        shapeshiftForm = 1
      })
      snap.spells[ID.MARK_OF_THE_WILD] = known("Mark of the Wild")
      local step = Engine.nextStep(snap, Rules.forClass("DRUID"))
      return assert.is_nil(step.cancelForm)
    end)
  end)
  return it("refreshes Thorns when it is about to expire", function()
    local snap = druidSnap()
    snap.units.player.auras = {
      aura("Mark of the Wild"),
      aura("Thorns", {
        expires = 1030
      })
    }
    local step = Engine.nextStep(snap, Rules.forClass("DRUID"))
    assert.are.equal("Thorns", step.spell)
    return assert.matches("expiring", step.reason)
  end)
end)
