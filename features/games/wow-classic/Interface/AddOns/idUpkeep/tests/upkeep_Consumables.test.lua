local load
load = function()
  local _list_0 = {
    "src.modules.automation.upkeep.Rules",
    "src.modules.automation.upkeep.Consumables",
    "src.modules.automation.upkeep.Snapshot"
  }
  for _index_0 = 1, #_list_0 do
    local p = _list_0[_index_0]
    package.loaded[p] = nil
    require(p)
  end
  return _G.idUpkeep_UpkeepConsumables, _G.idUpkeep_UpkeepSnapshot
end
local fakeLib
fakeLib = function(sets)
  return {
    ItemInSet = function(self, item, set)
      local t = sets[set]
      return t and t[item]
    end,
    IterateSet = function(self, set)
      local t = sets[set] or { }
      return next, t
    end
  }
end
describe("Upkeep Consumables", function()
  local Consumables
  before_each(function()
    Consumables = load()
  end)
  it("returns empty lists without LibPeriodicTable", function()
    local out = Consumables.build({
      [13452] = 1
    }, { })
    assert.are.same({ }, out.food)
    return assert.are.same({ }, out.consumables)
  end)
  it("lists bag candidates with LPT values, usability and the flask flag", function()
    local lib = fakeLib({
      ["Consumable.Buff.Agility.Self"] = {
        [13452] = "25",
        [3390] = "8"
      },
      ["Consumable.Buff.Health.Flask"] = {
        [13510] = "1200"
      }
    })
    local out = Consumables.build({
      [13452] = 2,
      [13510] = 1,
      [999] = 5
    }, {
      lib = lib,
      usable = function(id)
        return id ~= 13510
      end
    })
    local agi = out.consumables["Consumable.Buff.Agility.Self"].items
    assert.are.equal(1, #agi)
    assert.are.same({
      itemId = 13452,
      value = 25,
      count = 2,
      usable = true,
      flask = false
    }, agi[1])
    local flask = out.consumables["Consumable.Buff.Health.Flask"].items[1]
    assert.is_true(flask.flask)
    return assert.is_false(flask.usable)
  end)
  it("maps every set item's use spell to its value, even items not carried", function()
    local lib = fakeLib({
      ["Consumable.Buff.Agility.Self"] = {
        [13452] = "25",
        [3390] = "8"
      }
    })
    local spells = {
      [13452] = {
        "Elixir of the Mongoose",
        17538
      },
      [3390] = {
        "Lesser Agility",
        3160
      }
    }
    local out = Consumables.build({ }, {
      lib = lib,
      itemSpell = function(id)
        local s = spells[id]
        if not (s) then
          return nil
        end
        return s[1], s[2]
      end
    })
    local data = out.consumables["Consumable.Buff.Agility.Self"]
    assert.are.equal(25, data.auraNames["Elixir of the Mongoose"])
    return assert.are.equal(8, data.auraIds[3160])
  end)
  return it("splits rest food from buff food and water, flags conjured and defaults missing values to 1", function()
    local lib = fakeLib({
      ["Consumable.Food.Edible.Basic.Non-Conjured"] = {
        [4540] = "61",
        [13928] = "874"
      },
      ["Consumable.Food.Edible.Basic.Conjured"] = {
        [8076] = "874"
      },
      ["Consumable.Food.Buff.Agility"] = {
        [13928] = "10"
      },
      ["Consumable.Water.Conjured"] = {
        [8079] = "4200"
      },
      ["Consumable.Weapon Buff.Stone.Sharpening Stone"] = {
        [23122] = true,
        [12404] = "8"
      }
    })
    local out = Consumables.build({
      [4540] = 3,
      [13928] = 2,
      [8076] = 5,
      [8079] = 10,
      [23122] = 1,
      [12404] = 1
    }, {
      lib = lib
    })
    local foodIds
    do
      local _accum_0 = { }
      local _len_0 = 1
      local _list_0 = out.food
      for _index_0 = 1, #_list_0 do
        local c = _list_0[_index_0]
        _accum_0[_len_0] = c.itemId
        _len_0 = _len_0 + 1
      end
      foodIds = _accum_0
    end
    assert.are.same({
      4540,
      8076
    }, foodIds)
    assert.is_true(out.food[2].conjured)
    assert.are.equal(13928, out.foodBuffs["Consumable.Food.Buff.Agility"][1].itemId)
    assert.are.equal(4200, out.water[1].value)
    local stones = { }
    local _list_0 = out.weaponItems.sharpening
    for _index_0 = 1, #_list_0 do
      local c = _list_0[_index_0]
      stones[c.itemId] = c.value
    end
    return assert.are.same({
      [23122] = 1,
      [12404] = 8
    }, stones)
  end)
end)
describe("Upkeep Snapshot", function()
  local Snapshot
  local saved = { }
  local GLOBALS = {
    "C_UnitAuras",
    "UnitBuff",
    "UnitAura",
    "issecretvalue",
    "C_Spell",
    "GetSpellInfo",
    "IsPlayerSpell",
    "IsSpellKnown",
    "IsUsableSpell",
    "C_Container",
    "GetContainerNumSlots",
    "GetWeaponEnchantInfo",
    "GetInventoryItemID",
    "UnitExists",
    "UnitInRange",
    "InCombatLockdown",
    "LibStub",
    "C_Item"
  }
  before_each(function()
    saved = { }
    for _index_0 = 1, #GLOBALS do
      local k = GLOBALS[_index_0]
      saved[k] = {
        v = _G[k]
      }
    end
    local _
    _, Snapshot = load()
  end)
  after_each(function()
    for k, box in pairs(saved) do
      _G[k] = box.v
    end
  end)
  it("reports unreadable auras when the aura API throws", function()
    _G.C_UnitAuras = {
      GetAuraDataByIndex = function()
        return error("Auras cannot be accessed when secret while tainted")
      end
    }
    local auras, err = Snapshot.readAuras("player")
    assert.is_nil(auras)
    return assert.matches("secret while tainted", err)
  end)
  it("reports unreadable auras when names are secret values", function()
    local secret = { }
    _G.issecretvalue = function(v)
      return v == secret
    end
    _G.C_UnitAuras = {
      GetAuraDataByIndex = function(_, i)
        if i == 1 then
          return {
            name = secret,
            spellId = 1
          }
        else
          return nil
        end
      end
    }
    local auras, err = Snapshot.readAuras("player")
    assert.is_nil(auras)
    return assert.matches("secret", err)
  end)
  it("falls back to UnitBuff on older clients", function()
    _G.C_UnitAuras = nil
    _G.UnitBuff = function(_, i)
      if not (i == 1) then
        return nil
      end
      return "Ice Armor", "icon", 0, nil, 1800, 2800, "player", false, false, 7302
    end
    local auras = Snapshot.readAuras("player")
    return assert.are.same({
      {
        name = "Ice Armor",
        spellId = 7302,
        expires = 2800,
        fromPlayer = true
      }
    }, auras)
  end)
  it("builds a snapshot that is unreadable when auras throw, without raising", function()
    _G.C_UnitAuras = {
      GetAuraDataByIndex = function()
        return error("secret")
      end
    }
    _G.InCombatLockdown = function()
      return false
    end
    local snap = Snapshot.build({
      rules = { }
    })
    return assert.matches("player", snap.unreadable)
  end)
  it("reads spell knowledge by id and usability by name", function()
    _G.C_Spell = nil
    _G.GetSpellInfo = function(id)
      if not (id == 1459) then
        return nil
      end
      return "Arcane Intellect", nil, "icon"
    end
    _G.IsPlayerSpell = function(id)
      return id == 1459
    end
    _G.IsSpellKnown = nil
    _G.IsUsableSpell = function(name)
      return false, true
    end
    local s = Snapshot.readSpell(1459)
    assert.are.same({
      name = "Arcane Intellect",
      icon = "icon",
      known = true,
      usable = false,
      noMana = true
    }, s)
    return assert.is_false(Snapshot.readSpell(9999).known)
  end)
  it("reads weapons: blade vs blunt, ranged is not a weapon, enchant time in seconds", function()
    _G.GetInventoryItemID = function(_, slot)
      if slot == 16 then
        return 100
      else
        return 200
      end
    end
    local instant
    instant = function(id)
      if id == 100 then
        return id, "Weapon", "Mace", "", "icon", 2, 4
      end
      return id, "Weapon", "Bow", "", "icon", 2, 2
    end
    _G.C_Item = {
      GetItemInfoInstant = instant
    }
    _G.GetWeaponEnchantInfo = function()
      return true, 90000, 0, 1, false
    end
    local w = Snapshot.readWeapons()
    assert.is_true(w.mh.isWeapon)
    assert.is_true(w.mh.blunt)
    assert.is_true(w.mh.hasEnchant)
    assert.are.equal(90, w.mh.remaining)
    assert.is_false(w.oh.isWeapon)
    _G.C_Item = nil
  end)
  return it("treats an unchecked UnitInRange as unknown (not out of range)", function()
    _G.UnitExists = function()
      return true
    end
    _G.UnitInRange = function()
      return false, false
    end
    local ud = Snapshot.readUnit("party1")
    assert.is_nil(ud.inRange)
    _G.UnitInRange = function()
      return false, true
    end
    return assert.is_false(Snapshot.readUnit("party1").inRange)
  end)
end)
return describe("Upkeep Consumables library preference (empty-data shadowing)", function()
  local saved
  local withLibs
  withLibs = function(libs)
    _G.LibStub = setmetatable({
      GetLibrary = function(self, major)
        return libs[major]
      end
    }, {
      __call = function(_, major)
        return libs[major]
      end
    })
  end
  local withData
  withData = function(sets)
    return {
      Sets = function(self)
        return sets
      end,
      ItemInSet = function(self, itemId, set)
        return 1
      end,
      IterateSet = function(self, set)
        return next, { }
      end
    }
  end
  before_each(function()
    saved = _G.LibStub
    package.loaded["src.modules.automation.upkeep.Rules"] = nil
    package.loaded["src.modules.automation.upkeep.Consumables"] = nil
    require("src.modules.automation.upkeep.Rules")
    return require("src.modules.automation.upkeep.Consumables")
  end)
  after_each(function()
    _G.LibStub = saved
  end)
  it("prefers LibItemTable when it HAS data", function()
    local C = _G.idUpkeep_UpkeepConsumables
    local wanted = withData({
      "Consumable.Water.Basic"
    })
    withLibs({
      ["idLibItemTable-1.0"] = wanted,
      ["LibPeriodicTable-3.1"] = withData({ })
    })
    return assert.are.equal(wanted, C.lib())
  end)
  it("falls through to LPT when LibItemTable is EMPTY", function()
    local C = _G.idUpkeep_UpkeepConsumables
    local lpt = {
      ItemInSet = function()
        return 1
      end,
      IterateSet = function()
        return next, { }
      end
    }
    withLibs({
      ["idLibItemTable-1.0"] = withData({ }),
      ["LibPeriodicTable-3.1"] = lpt
    })
    return assert.are.equal(lpt, C.lib())
  end)
  it("never judges a library without a Sets method to be empty", function()
    local C = _G.idUpkeep_UpkeepConsumables
    assert.is_false(C.isEmpty({
      ItemInSet = function()
        return 1
      end
    }))
    assert.is_false(C.isEmpty({
      Sets = function()
        return error("boom")
      end
    }))
    assert.is_true(C.isEmpty(withData({ })))
    return assert.is_false(C.isEmpty(withData({
      "Consumable.Water.Basic"
    })))
  end)
  it("still returns the empty library when NOTHING has data", function()
    local C = _G.idUpkeep_UpkeepConsumables
    local empty = withData({ })
    withLibs({
      ["idLibItemTable-1.0"] = empty
    })
    return assert.are.equal(empty, C.lib())
  end)
  return it("returns nil when no library is present at all", function()
    local C = _G.idUpkeep_UpkeepConsumables
    withLibs({ })
    assert.is_nil(C.lib())
    _G.LibStub = nil
    return assert.is_nil(C.lib())
  end)
end)
