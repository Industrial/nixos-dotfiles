local LIB_PATH = (debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../idLibItemTable/idLibItemTable.lua")
local makeLibStub
makeLibStub = function()
  local libs = { }
  local minors = { }
  return {
    libs = libs,
    NewLibrary = function(self, major, minor)
      if minors[major] and minors[major] >= minor then
        return nil
      end
      minors[major] = minor
      local _update_0 = major
      libs[_update_0] = libs[_update_0] or { }
      return libs[major]
    end,
    GetLibrary = function(self, major, silent)
      if not libs[major] and not silent then
        error("No library :" .. major)
      end
      return libs[major]
    end
  }
end
local loadLib
loadLib = function()
  _G.LibStub = makeLibStub()
  dofile((debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../idLibSetTable/idLibSetTable.lua"))
  return dofile(LIB_PATH)
end
local SAMPLE = {
  ["Consumable.Buff.Agility.Flask"] = "13510:25,13512:30",
  ["Consumable.Food.Edible.Basic.Conjured"] = "8076,22895",
  ["Consumable.Water.Basic"] = "159:60,1179:160"
}
return describe("idLibItemTable-1.0", function()
  local lib, savedLibStub
  before_each(function()
    savedLibStub = _G.LibStub
    lib = loadLib()
    return lib:AddData("Consumable", 1, SAMPLE)
  end)
  after_each(function()
    _G.LibStub = savedLibStub
  end)
  describe("registration", function()
    it("registers with LibStub and is returned by the chunk", function()
      assert.is_table(lib)
      return assert.are.equal(lib, _G.LibStub:GetLibrary("idLibItemTable-1.0"))
    end)
    return it("exposes the two methods prepare/ binds to", function()
      assert.is_function(lib.ItemInSet)
      return assert.is_function(lib.IterateSet)
    end)
  end)
  describe("ItemInSet", function()
    it("returns the explicit value", function()
      assert.are.equal(25, lib:ItemInSet(13510, "Consumable.Buff.Agility.Flask"))
      return assert.are.equal(30, lib:ItemInSet(13512, "Consumable.Buff.Agility.Flask"))
    end)
    it("returns 1 for an item listed without a value (LPT semantics)", function()
      return assert.are.equal(1, lib:ItemInSet(8076, "Consumable.Food.Edible.Basic.Conjured"))
    end)
    it("returns nil for an item outside the set", function()
      return assert.is_nil(lib:ItemInSet(99999, "Consumable.Buff.Agility.Flask"))
    end)
    it("accepts a numeric string id, as tonumber coercion implies", function()
      return assert.are.equal(25, lib:ItemInSet("13510", "Consumable.Buff.Agility.Flask"))
    end)
    it("returns nil without erroring for junk input", function()
      local _list_0 = {
        nil,
        0,
        -1,
        "",
        "abc",
        { },
        true
      }
      for _index_0 = 1, #_list_0 do
        local bad = _list_0[_index_0]
        assert.has_no.errors(function()
          return lib:ItemInSet(bad, "Consumable.Buff.Agility.Flask")
        end)
      end
      assert.is_nil(lib:ItemInSet(nil, "Consumable.Buff.Agility.Flask"))
      assert.is_nil(lib:ItemInSet("abc", "Consumable.Buff.Agility.Flask"))
      assert.is_nil(lib:ItemInSet(13510, nil))
      return assert.is_nil(lib:ItemInSet(13510, 42))
    end)
    return it("returns nil for an unknown set", function()
      return assert.is_nil(lib:ItemInSet(13510, "No.Such.Set"))
    end)
  end)
  describe("IterateSet", function()
    it("yields every member as itemId, value in a generic for", function()
      local seen = { }
      for itemId, value in lib:IterateSet("Consumable.Buff.Agility.Flask") do
        seen[itemId] = value
      end
      return assert.are.same({
        [13510] = 25,
        [13512] = 30
      }, seen)
    end)
    it("supports the manual iter(state, control) protocol Consumables uses", function()
      local ok, iter, state = pcall(lib.IterateSet, lib, "Consumable.Water.Basic")
      assert.is_true(ok)
      assert.are.equal("function", type(iter))
      local seen, control = { }, nil
      while true do
        local iterOk, itemId, value = pcall(iter, state, control)
        if not (iterOk and itemId ~= nil) then
          break
        end
        control = itemId
        seen[itemId] = value
      end
      return assert.are.same({
        [159] = 60,
        [1179] = 160
      }, seen)
    end)
    it("iterates zero times for an unknown set instead of erroring", function()
      local count = 0
      assert.has_no.errors(function()
        for _ in lib:IterateSet("No.Such.Set") do
          count = count + 1
        end
      end)
      return assert.are.equal(0, count)
    end)
    return it("iterates zero times for a non-string set", function()
      local count = 0
      for _ in lib:IterateSet(42) do
        count = count + 1
      end
      return assert.are.equal(0, count)
    end)
  end)
  describe("AddData", function()
    it("is a no-op when the same domain+revision is registered again", function()
      assert.is_false(lib:AddData("Consumable", 1, {
        ["Other.Set"] = "1"
      }))
      return assert.is_nil(lib:ItemInSet(1, "Other.Set"))
    end)
    it("replaces the domain's sets wholesale on a new revision", function()
      lib:AddData("Consumable", 2, {
        ["Fresh.Set"] = "7:3"
      })
      assert.are.equal(3, lib:ItemInSet(7, "Fresh.Set"))
      return assert.is_nil(lib:ItemInSet(13510, "Consumable.Buff.Agility.Flask"))
    end)
    it("keeps domains independent", function()
      lib:AddData("Tradeskill", 1, {
        ["Tradeskill.Mat"] = "2770:1"
      })
      assert.are.equal(1, lib:ItemInSet(2770, "Tradeskill.Mat"))
      return assert.are.equal(25, lib:ItemInSet(13510, "Consumable.Buff.Agility.Flask"))
    end)
    return it("rejects a missing domain name or a non-table payload", function()
      assert.has_error(function()
        return lib:AddData("", 1, { })
      end)
      return assert.has_error(function()
        return lib:AddData("X", 1, "not a table")
      end)
    end)
  end)
  describe("laziness", function()
    it("parses each set at most once", function()
      lib:_ResetCache()
      assert.are.equal(0, lib.parseCount)
      lib:ItemInSet(13510, "Consumable.Buff.Agility.Flask")
      lib:ItemInSet(13512, "Consumable.Buff.Agility.Flask")
      for _ in lib:IterateSet("Consumable.Buff.Agility.Flask") do
        local _scrap_0 = nil
      end
      return assert.are.equal(1, lib.parseCount)
    end)
    return it("does not parse a set nobody asked for", function()
      lib:_ResetCache()
      lib:ItemInSet(13510, "Consumable.Buff.Agility.Flask")
      return assert.are.equal(1, lib.parseCount)
    end)
  end)
  describe("introspection", function()
    it("SetsFor lists every set holding the item, sorted", function()
      lib:AddData("Extra", 1, {
        ["A.Set"] = "13510:9",
        ["B.Set"] = "13510:9"
      })
      return assert.are.same({
        "A.Set",
        "B.Set",
        "Consumable.Buff.Agility.Flask"
      }, lib:SetsFor(13510))
    end)
    it("SetsFor is empty for an unknown item and for junk", function()
      assert.are.same({ }, lib:SetsFor(99999))
      return assert.are.same({ }, lib:SetsFor("abc"))
    end)
    it("Sets lists every registered set, sorted", function()
      return assert.are.same({
        "Consumable.Buff.Agility.Flask",
        "Consumable.Food.Edible.Basic.Conjured",
        "Consumable.Water.Basic"
      }, lib:Sets())
    end)
    return it("Manifest reports per-domain revision and set count", function()
      lib:AddManifest({
        build = "1.60.1.70790"
      })
      local m = lib:Manifest()
      assert.are.equal("1.60.1.70790", m.build)
      assert.are.equal(1, m.domains.Consumable.revision)
      return assert.are.equal(3, m.domains.Consumable.sets)
    end)
  end)
  return describe("hygiene", function()
    return it("writes nothing to _G beyond the LibStub registration", function()
      local before
      do
        local _accum_0 = { }
        local _len_0 = 1
        for k in pairs(_G) do
          _accum_0[_len_0] = k
          _len_0 = _len_0 + 1
        end
        before = _accum_0
      end
      local fresh = loadLib()
      fresh:AddData("Consumable", 1, SAMPLE)
      fresh:ItemInSet(13510, "Consumable.Buff.Agility.Flask")
      local added = { }
      local seen
      do
        local _tbl_0 = { }
        for _index_0 = 1, #before do
          local k = before[_index_0]
          _tbl_0[k] = true
        end
        seen = _tbl_0
      end
      for k in pairs(_G) do
        if not (seen[k]) then
          added[#added + 1] = k
        end
      end
      return assert.are.same({ }, (function()
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #added do
          local k = added[_index_0]
          if k ~= "LibStub" then
            _accum_0[_len_0] = k
            _len_0 = _len_0 + 1
          end
        end
        return _accum_0
      end)())
    end)
  end)
end)
