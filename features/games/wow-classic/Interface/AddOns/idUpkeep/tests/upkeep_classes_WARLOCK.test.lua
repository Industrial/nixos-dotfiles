local PATHS = {
  "src.modules.automation.upkeep.Rules",
  "src.modules.automation.upkeep.classes.WARLOCK",
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
  IMP = 688,
  VOIDWALKER = 697,
  SUCCUBUS = 712,
  FELHUNTER = 691,
  DEMON_SKIN = 687,
  DEMON_ARMOR = 706,
  HS_MAJOR = 11730,
  HS_GREATER = 11729,
  HS = 5699,
  HS_LESSER = 6202,
  HS_MINOR = 6201,
  SS_MAJOR = 20757,
  SS_GREATER = 20756,
  SS = 20755,
  SS_LESSER = 20752,
  SS_MINOR = 693
}
local ITEM = {
  MAJOR_HEALTHSTONE = 9421,
  GREATER_HEALTHSTONE_IMPROVED = 19011,
  MAJOR_SOULSTONE = 16896
}
local lockSnap
lockSnap = function(over)
  return merge({
    class = "WARLOCK",
    level = 60,
    now = 1000,
    inInstance = false,
    player = {
      healthPct = 100,
      manaPct = 100,
      usesMana = true
    },
    spells = {
      [ID.IMP] = known("Summon Imp"),
      [ID.VOIDWALKER] = known("Summon Voidwalker"),
      [ID.SUCCUBUS] = known("Summon Succubus"),
      [ID.FELHUNTER] = known("Summon Felhunter"),
      [ID.DEMON_SKIN] = known("Demon Skin"),
      [ID.DEMON_ARMOR] = known("Demon Armor"),
      [ID.HS_MAJOR] = known("Create Healthstone (Major)"),
      [ID.HS_GREATER] = known("Create Healthstone (Greater)"),
      [ID.HS] = known("Create Healthstone"),
      [ID.HS_LESSER] = known("Create Healthstone (Lesser)"),
      [ID.HS_MINOR] = known("Create Healthstone (Minor)"),
      [ID.SS_MAJOR] = known("Create Soulstone (Major)"),
      [ID.SS_GREATER] = known("Create Soulstone (Greater)"),
      [ID.SS] = known("Create Soulstone"),
      [ID.SS_LESSER] = known("Create Soulstone (Lesser)"),
      [ID.SS_MINOR] = known("Create Soulstone (Minor)")
    },
    items = {
      [ITEM.MAJOR_HEALTHSTONE] = 1,
      [ITEM.MAJOR_SOULSTONE] = 1
    },
    itemInfo = { },
    units = {
      player = {
        exists = true,
        class = "WARLOCK",
        usesMana = true,
        auras = {
          aura("Demon Armor")
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
end
local noPet
noPet = function(snap)
  snap.pet = {
    exists = false,
    dead = false
  }
  snap.units.pet = {
    exists = false
  }
  return snap
end
return describe("Upkeep WARLOCK", function()
  local Rules, Engine, rules
  before_each(function()
    Rules, Engine = load()
    rules = Rules.forClass("WARLOCK")
  end)
  describe("demon", function()
    it("summons the best known demon (Felhunter)", function()
      local step = Engine.nextStep(noPet(lockSnap()), rules)
      assert.are.equal("Summon Felhunter", step.spell)
      return assert.are.equal("pet", step.phase)
    end)
    it("prefers Succubus, then Voidwalker, when Felhunter is not known", function()
      local snap = noPet(lockSnap())
      snap.spells[ID.FELHUNTER] = unknown("Summon Felhunter")
      assert.are.equal("Summon Succubus", (Engine.nextStep(snap, rules)).spell)
      snap.spells[ID.SUCCUBUS] = unknown("Summon Succubus")
      return assert.are.equal("Summon Voidwalker", (Engine.nextStep(snap, rules)).spell)
    end)
    it("summons the Imp when it is the only demon known", function()
      local snap = noPet(lockSnap())
      local _list_0 = {
        ID.FELHUNTER,
        ID.SUCCUBUS,
        ID.VOIDWALKER
      }
      for _index_0 = 1, #_list_0 do
        local id = _list_0[_index_0]
        snap.spells[id] = unknown("x")
      end
      return assert.are.equal("Summon Imp", (Engine.nextStep(snap, rules)).spell)
    end)
    it("falls back to the Imp when the shard demons are not usable (no Soul Shard)", function()
      local snap = noPet(lockSnap())
      local _list_0 = {
        ID.FELHUNTER,
        ID.SUCCUBUS,
        ID.VOIDWALKER
      }
      for _index_0 = 1, #_list_0 do
        local id = _list_0[_index_0]
        snap.spells[id].usable = false
      end
      return assert.are.equal("Summon Imp", (Engine.nextStep(snap, rules)).spell)
    end)
    return it("does nothing for the pet when a demon is out", function()
      local entries = Engine.explain(lockSnap(), rules)
      for _index_0 = 1, #entries do
        local e = entries[_index_0]
        if e.phase == "pet" then
          assert.are_not.equal("do", e.status)
        end
      end
    end)
  end)
  describe("conjure", function()
    it("creates the best known healthstone when none is in the bags", function()
      local snap = lockSnap()
      snap.items[ITEM.MAJOR_HEALTHSTONE] = nil
      snap.spells[ID.HS_MAJOR] = unknown("Create Healthstone (Major)")
      local step = Engine.nextStep(snap, rules)
      assert.are.equal("Create Healthstone (Greater)", step.spell)
      return assert.are.equal("conjure", step.phase)
    end)
    it("does not create a healthstone while any size is in the bags", function()
      local snap = lockSnap()
      snap.items[ITEM.MAJOR_HEALTHSTONE] = nil
      snap.items[ITEM.GREATER_HEALTHSTONE_IMPROVED] = 1
      return assert.is_nil((Engine.nextStep(snap, rules)))
    end)
    it("creates a soulstone when none is in the bags", function()
      local snap = lockSnap()
      snap.items[ITEM.MAJOR_SOULSTONE] = nil
      local step = Engine.nextStep(snap, rules)
      return assert.are.equal("Create Soulstone (Major)", step.spell)
    end)
    return it("creates the healthstone before the soulstone", function()
      local snap = lockSnap()
      snap.items = { }
      return assert.are.equal("Create Healthstone (Major)", (Engine.nextStep(snap, rules)).spell)
    end)
  end)
  describe("armor", function()
    it("casts Demon Armor when no armor is active", function()
      local snap = lockSnap()
      snap.units.player.auras = { }
      local step = Engine.nextStep(snap, rules)
      assert.are.equal("Demon Armor", step.spell)
      return assert.are.equal("selfLong", step.phase)
    end)
    it("casts Demon Skin before Demon Armor is learned", function()
      local snap = lockSnap()
      snap.spells[ID.DEMON_ARMOR] = unknown("Demon Armor")
      snap.units.player.auras = { }
      return assert.are.equal("Demon Skin", (Engine.nextStep(snap, rules)).spell)
    end)
    it("is satisfied by an active Demon Skin", function()
      local snap = lockSnap()
      snap.units.player.auras = {
        aura("Demon Skin")
      }
      return assert.is_nil((Engine.nextStep(snap, rules)))
    end)
    return it("refreshes an expiring armor", function()
      local snap = lockSnap()
      snap.units.player.auras = {
        aura("Demon Armor", {
          expires = 1030
        })
      }
      local step = Engine.nextStep(snap, rules)
      assert.are.equal("Demon Armor", step.spell)
      return assert.matches("expiring", step.reason)
    end)
  end)
  return describe("complete", function()
    it("has nothing to do with a demon out, both stones and an armor", function()
      local step, reason = Engine.nextStep(lockSnap(), rules)
      assert.is_nil(step)
      return assert.are.equal("nothing to do", reason)
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
