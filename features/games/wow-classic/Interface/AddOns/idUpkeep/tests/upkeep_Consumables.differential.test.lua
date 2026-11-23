local Boot = require("src.test_bootstrap")
local LIB_PATH = (_G.IDUPKEEP_ADDONS .. "idLibItemTable/idLibItemTable.lua")
local SETS = {
  ["Consumable.Buff.Agility.Self"] = {
    [13452] = 25,
    [3390] = 8
  },
  ["Consumable.Food.Edible.Basic.Non-Conjured"] = {
    [4540] = 60
  },
  ["Consumable.Water.Basic"] = {
    [1179] = 160
  },
  ["Consumable.Weapon Buff.Stone.Sharpening Stone"] = {
    [2863] = 6
  }
}
local lptStub
lptStub = function()
  return {
    ItemInSet = function(self, itemId, set)
      return (SETS[set] or { })[itemId]
    end,
    IterateSet = function(self, set)
      return next, (SETS[set] or { })
    end
  }
end
local realLib
realLib = function()
  local libs, minors = { }, { }
  local stub = {
    NewLibrary = function(self, major, minor)
      if minors[major] and minors[major] >= minor then
        return nil
      end
      minors[major] = minor
      local _update_0 = major
      libs[_update_0] = libs[_update_0] or { }
      return libs[major]
    end,
    GetLibrary = function(self, major)
      return libs[major]
    end
  }
  _G.LibStub = setmetatable(stub, {
    __call = function(_, major)
      return libs[major]
    end
  })
  dofile((_G.IDUPKEEP_ADDONS .. "idLibSetTable/idLibSetTable.lua"))
  local lib = dofile(LIB_PATH)
  local encoded = { }
  for setName, members in pairs(SETS) do
    local ids
    do
      local _accum_0 = { }
      local _len_0 = 1
      for id in pairs(members) do
        _accum_0[_len_0] = id
        _len_0 = _len_0 + 1
      end
      ids = _accum_0
    end
    table.sort(ids)
    encoded[setName] = table.concat((function()
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #ids do
        local id = ids[_index_0]
        _accum_0[_len_0] = ("%d:%d"):format(id, members[id])
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end)(), ",")
  end
  lib:AddData("Consumable", 1, encoded)
  return lib
end
local BAGS = {
  [13452] = 2,
  [3390] = 5,
  [4540] = 3,
  [1179] = 4,
  [2863] = 1,
  [99999] = 7
}
local SPELLS = {
  [13452] = {
    "Elixir of the Mongoose",
    17538
  },
  [3390] = {
    "Elixir of Lesser Agility",
    11390
  },
  [2863] = {
    "Sharpen Weapon",
    16138
  }
}
local ctxFor
ctxFor = function(lib)
  return {
    lib = lib,
    usable = function()
      return true
    end,
    itemSpell = function(itemId)
      local entry = SPELLS[itemId]
      if not (entry) then
        return nil
      end
      return entry[1], entry[2]
    end
  }
end
describe("Upkeep consumables under either item library", function()
  local Consumables, savedLibStub
  before_each(function()
    savedLibStub = _G.LibStub
    Boot.ensure()
    package.loaded["src.modules.automation.upkeep.Consumables"] = nil
    Consumables = require("src.modules.automation.upkeep.Consumables")
  end)
  after_each(function()
    _G.LibStub = savedLibStub
  end)
  it("produces identical output under both libraries", function()
    local underLpt = Consumables.build(BAGS, ctxFor(lptStub()))
    Consumables._spellCache = { }
    local underNew = Consumables.build(BAGS, ctxFor(realLib()))
    return assert.are.same(underLpt, underNew)
  end)
  it("agrees item by item on membership and value", function()
    local a, b = lptStub(), realLib()
    for setName, members in pairs(SETS) do
      for id, value in pairs(members) do
        assert.are.equal(a:ItemInSet(id, setName), b:ItemInSet(id, setName), ("%s / %d"):format(setName, id))
      end
      assert.is_nil(a:ItemInSet(99999, setName))
      assert.is_nil(b:ItemInSet(99999, setName))
    end
  end)
  return it("agrees on iteration membership", function()
    local a, b = lptStub(), realLib()
    for setName in pairs(SETS) do
      local fromA, fromB = { }, { }
      for id, v in a:IterateSet(setName) do
        fromA[id] = v
      end
      for id, v in b:IterateSet(setName) do
        fromB[id] = v
      end
      assert.are.same(fromA, fromB)
    end
  end)
end)
return describe("Consumables.lib resolution", function()
  local Consumables, savedLibStub
  before_each(function()
    savedLibStub = _G.LibStub
    Boot.ensure()
    package.loaded["src.modules.automation.upkeep.Consumables"] = nil
    Consumables = require("src.modules.automation.upkeep.Consumables")
  end)
  after_each(function()
    _G.LibStub = savedLibStub
  end)
  local stubWith
  stubWith = function(available)
    _G.LibStub = function(major)
      return available[major]
    end
  end
  it("prefers LibItemTable over LPT", function()
    local newLib, oldLib = {
      tag = "new"
    }, {
      tag = "old"
    }
    stubWith({
      ["idLibItemTable-1.0"] = newLib,
      ["LibPeriodicTable-3.1"] = oldLib
    })
    return assert.are.equal(newLib, Consumables.lib())
  end)
  it("falls back to LPT when the new library is absent", function()
    local oldLib = {
      tag = "old"
    }
    stubWith({
      ["LibPeriodicTable-3.1"] = oldLib
    })
    return assert.are.equal(oldLib, Consumables.lib())
  end)
  it("returns nil when neither is loaded", function()
    stubWith({ })
    return assert.is_nil(Consumables.lib())
  end)
  return it("returns nil when LibStub itself is absent", function()
    _G.LibStub = nil
    return assert.is_nil(Consumables.lib())
  end)
end)
