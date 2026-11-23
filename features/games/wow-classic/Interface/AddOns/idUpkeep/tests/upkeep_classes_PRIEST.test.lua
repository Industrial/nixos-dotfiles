local PATHS = {
  "src.modules.automation.upkeep.Rules",
  "src.modules.automation.upkeep.classes.PRIEST",
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
  INNER_FIRE = 588,
  FORTITUDE = 1243,
  PRAYER_OF_FORTITUDE = 21562,
  DIVINE_SPIRIT = 14752,
  PRAYER_OF_SPIRIT = 27681,
  SHADOW_PROTECTION = 976,
  PRAYER_OF_SHADOW_PROTECTION = 27683,
  FEAR_WARD = 6346
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
local priestSnap
priestSnap = function(over)
  local snap = snapFor("PRIEST", over)
  local _update_0 = ID.INNER_FIRE
  snap.spells[_update_0] = snap.spells[_update_0] or known("Inner Fire")
  local _update_1 = ID.FORTITUDE
  snap.spells[_update_1] = snap.spells[_update_1] or known("Power Word: Fortitude")
  local _update_2 = ID.PRAYER_OF_FORTITUDE
  snap.spells[_update_2] = snap.spells[_update_2] or unknown("Prayer of Fortitude")
  local _update_3 = ID.DIVINE_SPIRIT
  snap.spells[_update_3] = snap.spells[_update_3] or known("Divine Spirit")
  local _update_4 = ID.PRAYER_OF_SPIRIT
  snap.spells[_update_4] = snap.spells[_update_4] or unknown("Prayer of Spirit")
  local _update_5 = ID.SHADOW_PROTECTION
  snap.spells[_update_5] = snap.spells[_update_5] or known("Shadow Protection")
  local _update_6 = ID.PRAYER_OF_SHADOW_PROTECTION
  snap.spells[_update_6] = snap.spells[_update_6] or unknown("Prayer of Shadow Protection")
  local _update_7 = ID.FEAR_WARD
  snap.spells[_update_7] = snap.spells[_update_7] or unknown("Fear Ward")
  return snap
end
local ALL_SELF
ALL_SELF = function()
  return {
    aura("Inner Fire"),
    aura("Power Word: Fortitude"),
    aura("Divine Spirit"),
    aura("Shadow Protection")
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
return describe("Upkeep PRIEST", function()
  local Rules, Engine
  before_each(function()
    Rules, Engine = load()
  end)
  it("registers as a caster", function()
    return assert.are.equal("caster", Rules.forClass("PRIEST").role)
  end)
  it("orders self buffs Inner Fire -> Fortitude -> Divine Spirit -> Shadow Protection, then the party", function()
    local snap = priestSnap()
    snap.units.party1 = {
      exists = true,
      class = "MAGE",
      usesMana = true,
      auras = { }
    }
    return assert.are.same({
      "Inner Fire@player",
      "Power Word: Fortitude@player",
      "Divine Spirit@player",
      "Shadow Protection@player",
      "Power Word: Fortitude@party1",
      "Divine Spirit@party1",
      "Shadow Protection@party1"
    }, doSteps(Engine, snap, Rules.forClass("PRIEST")))
  end)
  it("casts Inner Fire first", function()
    local step = Engine.nextStep(priestSnap(), Rules.forClass("PRIEST"))
    assert.are.equal("Inner Fire", step.spell)
    assert.are.equal("player", step.unit)
    return assert.are.equal("selfLong", step.phase)
  end)
  it("skips Divine Spirit on a warrior but gives Fortitude and Shadow Protection", function()
    local snap = priestSnap()
    snap.units.player.auras = ALL_SELF()
    snap.units.party1 = {
      exists = true,
      class = "WARRIOR",
      usesMana = false,
      auras = { }
    }
    return assert.are.same({
      "Power Word: Fortitude@party1",
      "Shadow Protection@party1"
    }, doSteps(Engine, snap, Rules.forClass("PRIEST")))
  end)
  it("skips buffs already active (including the Prayer versions)", function()
    local snap = priestSnap()
    snap.units.player.auras = ALL_SELF()
    snap.units.party1 = {
      exists = true,
      class = "MAGE",
      usesMana = true,
      auras = {
        aura("Prayer of Fortitude"),
        aura("Prayer of Spirit"),
        aura("Prayer of Shadow Protection")
      }
    }
    local step, reason = Engine.nextStep(snap, Rules.forClass("PRIEST"))
    assert.is_nil(step)
    return assert.are.equal("nothing to do", reason)
  end)
  it("skips unknown spells (no Divine Spirit talent, no Shadow Protection yet)", function()
    local snap = priestSnap()
    snap.spells[ID.DIVINE_SPIRIT] = unknown("Divine Spirit")
    snap.spells[ID.SHADOW_PROTECTION] = unknown("Shadow Protection")
    snap.units.player.auras = {
      aura("Inner Fire"),
      aura("Power Word: Fortitude")
    }
    local step, reason = Engine.nextStep(snap, Rules.forClass("PRIEST"))
    assert.is_nil(step)
    return assert.are.equal("nothing to do", reason)
  end)
  it("casts Fear Ward on self only, when known", function()
    local snap = priestSnap()
    snap.spells[ID.FEAR_WARD] = known("Fear Ward")
    snap.units.player.auras = ALL_SELF()
    snap.units.party1 = {
      exists = true,
      class = "WARRIOR",
      usesMana = false,
      auras = {
        aura("Power Word: Fortitude"),
        aura("Shadow Protection")
      }
    }
    return assert.are.same({
      "Fear Ward@player"
    }, doSteps(Engine, snap, Rules.forClass("PRIEST")))
  end)
  return it("buffs a mana-using pet with Divine Spirit", function()
    local snap = priestSnap()
    snap.units.player.auras = ALL_SELF()
    snap.units.pet = {
      exists = true,
      usesMana = true,
      auras = {
        aura("Power Word: Fortitude"),
        aura("Shadow Protection")
      }
    }
    local step = Engine.nextStep(snap, Rules.forClass("PRIEST"))
    assert.are.equal("Divine Spirit", step.spell)
    assert.are.equal("pet", step.unit)
    return assert.are.equal("group", step.phase)
  end)
end)
