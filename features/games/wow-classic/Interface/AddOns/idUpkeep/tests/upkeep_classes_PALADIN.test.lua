local PATHS = {
  "src.modules.automation.upkeep.Rules",
  "src.modules.automation.upkeep.classes.PALADIN",
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
  DEVOTION_AURA = 465,
  RETRIBUTION_AURA = 7294,
  CONCENTRATION_AURA = 19746,
  SHADOW_RESISTANCE_AURA = 19876,
  FROST_RESISTANCE_AURA = 19888,
  FIRE_RESISTANCE_AURA = 19891,
  SANCTITY_AURA = 20218,
  MIGHT = 19740,
  WISDOM = 19742,
  KINGS = 20217,
  GREATER_MIGHT = 25782,
  GREATER_WISDOM = 25894,
  GREATER_KINGS = 25898
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
local paladinSnap
paladinSnap = function(over)
  local snap = snapFor("PALADIN", over)
  local _update_0 = ID.DEVOTION_AURA
  snap.spells[_update_0] = snap.spells[_update_0] or known("Devotion Aura")
  local _update_1 = ID.RETRIBUTION_AURA
  snap.spells[_update_1] = snap.spells[_update_1] or known("Retribution Aura")
  local _update_2 = ID.CONCENTRATION_AURA
  snap.spells[_update_2] = snap.spells[_update_2] or unknown("Concentration Aura")
  local _update_3 = ID.SHADOW_RESISTANCE_AURA
  snap.spells[_update_3] = snap.spells[_update_3] or unknown("Shadow Resistance Aura")
  local _update_4 = ID.FROST_RESISTANCE_AURA
  snap.spells[_update_4] = snap.spells[_update_4] or unknown("Frost Resistance Aura")
  local _update_5 = ID.FIRE_RESISTANCE_AURA
  snap.spells[_update_5] = snap.spells[_update_5] or unknown("Fire Resistance Aura")
  local _update_6 = ID.SANCTITY_AURA
  snap.spells[_update_6] = snap.spells[_update_6] or unknown("Sanctity Aura")
  local _update_7 = ID.MIGHT
  snap.spells[_update_7] = snap.spells[_update_7] or known("Blessing of Might")
  local _update_8 = ID.WISDOM
  snap.spells[_update_8] = snap.spells[_update_8] or known("Blessing of Wisdom")
  local _update_9 = ID.KINGS
  snap.spells[_update_9] = snap.spells[_update_9] or unknown("Blessing of Kings")
  local _update_10 = ID.GREATER_MIGHT
  snap.spells[_update_10] = snap.spells[_update_10] or unknown("Greater Blessing of Might")
  local _update_11 = ID.GREATER_WISDOM
  snap.spells[_update_11] = snap.spells[_update_11] or unknown("Greater Blessing of Wisdom")
  local _update_12 = ID.GREATER_KINGS
  snap.spells[_update_12] = snap.spells[_update_12] or unknown("Greater Blessing of Kings")
  return snap
end
local party
party = function(classToken, usesMana, auras)
  return {
    exists = true,
    class = classToken,
    usesMana = usesMana,
    auras = auras or { }
  }
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
return describe("Upkeep PALADIN", function()
  local Rules, Engine
  before_each(function()
    Rules, Engine = load()
  end)
  it("registers as a hybrid", function()
    return assert.are.equal("hybrid", Rules.forClass("PALADIN").role)
  end)
  describe("blessingFor", function()
    return it("picks Might for warriors and rogues, Wisdom for mana users", function()
      local blessingFor = _G.idUpkeep_UpkeepClassPALADIN.blessingFor
      assert.are.equal("might", blessingFor("WARRIOR", {
        usesMana = false
      }))
      assert.are.equal("might", blessingFor("ROGUE", {
        usesMana = false
      }))
      local _list_0 = {
        "PRIEST",
        "MAGE",
        "WARLOCK",
        "DRUID",
        "SHAMAN",
        "PALADIN",
        "HUNTER"
      }
      for _index_0 = 1, #_list_0 do
        local cls = _list_0[_index_0]
        assert.are.equal("wisdom", blessingFor(cls, {
          usesMana = true
        }), cls)
      end
      return assert.are.equal("might", blessingFor(nil, {
        usesMana = false
      }))
    end)
  end)
  describe("aura", function()
    it("casts Devotion Aura first when no aura is active", function()
      local step = Engine.nextStep(paladinSnap(), Rules.forClass("PALADIN"))
      assert.are.equal("Devotion Aura", step.spell)
      assert.are.equal("player", step.unit)
      return assert.are.equal("selfLong", step.phase)
    end)
    return it("does not recast when any paladin aura is active", function()
      local _list_0 = {
        "Devotion Aura",
        "Retribution Aura",
        "Concentration Aura",
        "Shadow Resistance Aura",
        "Frost Resistance Aura",
        "Fire Resistance Aura",
        "Sanctity Aura"
      }
      for _index_0 = 1, #_list_0 do
        local name = _list_0[_index_0]
        local snap = paladinSnap()
        snap.units.player.auras = {
          aura(name),
          aura("Blessing of Wisdom")
        }
        local step, reason = Engine.nextStep(snap, Rules.forClass("PALADIN"))
        assert.is_nil(step, name)
        assert.are.equal("nothing to do", reason)
      end
    end)
  end)
  return describe("blessings", function()
    it("orders aura -> own blessing -> party blessings by class", function()
      local snap = paladinSnap()
      snap.units.party1 = party("WARRIOR", false)
      snap.units.party2 = party("MAGE", true)
      snap.units.party3 = party("ROGUE", false)
      snap.units.party4 = party("HUNTER", true)
      return assert.are.same({
        "Devotion Aura@player",
        "Blessing of Wisdom@player",
        "Blessing of Might@party1",
        "Blessing of Might@party3",
        "Blessing of Wisdom@party2",
        "Blessing of Wisdom@party4"
      }, doSteps(Engine, snap, Rules.forClass("PALADIN")))
    end)
    it("uses Blessing of Kings on everyone once known", function()
      local snap = paladinSnap()
      snap.spells[ID.KINGS] = known("Blessing of Kings")
      snap.units.player.auras = {
        aura("Devotion Aura")
      }
      snap.units.party1 = party("WARRIOR", false)
      snap.units.party2 = party("PRIEST", true)
      return assert.are.same({
        "Blessing of Kings@player",
        "Blessing of Kings@party1",
        "Blessing of Kings@party2"
      }, doSteps(Engine, snap, Rules.forClass("PALADIN")))
    end)
    it("skips a unit that already has the intended blessing (or its Greater version)", function()
      local snap = paladinSnap()
      snap.units.player.auras = {
        aura("Devotion Aura"),
        aura("Greater Blessing of Wisdom")
      }
      snap.units.party1 = party("WARRIOR", false, {
        aura("Blessing of Might")
      })
      snap.units.party2 = party("MAGE", true, {
        aura("Blessing of Wisdom")
      })
      local step, reason = Engine.nextStep(snap, Rules.forClass("PALADIN"))
      assert.is_nil(step)
      return assert.are.equal("nothing to do", reason)
    end)
    it("a different blessing does not count as done", function()
      local snap = paladinSnap()
      snap.units.player.auras = {
        aura("Devotion Aura"),
        aura("Blessing of Wisdom")
      }
      snap.units.party1 = party("WARRIOR", false, {
        aura("Blessing of Wisdom")
      })
      return assert.are.same({
        "Blessing of Might@party1"
      }, doSteps(Engine, snap, Rules.forClass("PALADIN")))
    end)
    return it("skips blessings the paladin does not know", function()
      local snap = paladinSnap()
      snap.spells[ID.WISDOM] = unknown("Blessing of Wisdom")
      snap.units.player.auras = {
        aura("Devotion Aura")
      }
      snap.units.party1 = party("MAGE", true)
      snap.units.party2 = party("WARRIOR", false)
      return assert.are.same({
        "Blessing of Might@party2"
      }, doSteps(Engine, snap, Rules.forClass("PALADIN")))
    end)
  end)
end)
