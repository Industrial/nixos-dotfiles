local SPELL_PATH = (debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../idLibSpellTable/idLibSpellTable.lua")
local makeLibStub
makeLibStub = function()
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
    GetLibrary = function(self, major, silent)
      if not libs[major] and not silent then
        error("No library :" .. major)
      end
      return libs[major]
    end
  }
  return setmetatable(stub, {
    __call = function(_, major)
      return libs[major]
    end
  })
end
local load
load = function(path)
  _G.LibStub = makeLibStub()
  dofile((debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../idLibSetTable/idLibSetTable.lua"))
  return dofile(path)
end
local SAMPLE = {
  ["Spell.Buff.Self"] = "92001:10,92002:12",
  ["Spell.Conjure.Food"] = "92003",
  ["Spell.Heal.Direct"] = "92005:300"
}
return describe("idLibSpellTable-1.0", function()
  local lib, savedLibStub
  before_each(function()
    savedLibStub = _G.LibStub
    lib = load(SPELL_PATH)
    return lib:AddData("Spell", 1, SAMPLE)
  end)
  after_each(function()
    _G.LibStub = savedLibStub
  end)
  describe("registration", function()
    it("registers under its own name", function()
      return assert.are.equal(lib, _G.LibStub:GetLibrary("idLibSpellTable-1.0"))
    end)
    return it("exposes the spell-side read API", function()
      assert.is_function(lib.SpellInSet)
      assert.is_function(lib.IterateSet)
      return assert.is_function(lib.SetsFor)
    end)
  end)
  describe("SpellInSet", function()
    it("returns the explicit value", function()
      return assert.are.equal(10, lib:SpellInSet(92001, "Spell.Buff.Self"))
    end)
    it("returns 1 for a spell listed without a value", function()
      return assert.are.equal(1, lib:SpellInSet(92003, "Spell.Conjure.Food"))
    end)
    return it("returns nil outside the set and for junk", function()
      assert.is_nil(lib:SpellInSet(99999, "Spell.Buff.Self"))
      assert.is_nil(lib:SpellInSet(nil, "Spell.Buff.Self"))
      assert.is_nil(lib:SpellInSet(92001, nil))
      return assert.is_nil(lib:SpellInSet(92001, "No.Such.Set"))
    end)
  end)
  describe("IterateSet", function()
    it("yields every member", function()
      local seen = { }
      for id, v in lib:IterateSet("Spell.Buff.Self") do
        seen[id] = v
      end
      return assert.are.same({
        [92001] = 10,
        [92002] = 12
      }, seen)
    end)
    it("supports the manual iter(state, control) protocol", function()
      local ok, iter, state = pcall(lib.IterateSet, lib, "Spell.Buff.Self")
      assert.is_true(ok)
      local seen, control = { }, nil
      while true do
        local iterOk, id, value = pcall(iter, state, control)
        if not (iterOk and id ~= nil) then
          break
        end
        control = id
        seen[id] = value
      end
      return assert.are.same({
        [92001] = 10,
        [92002] = 12
      }, seen)
    end)
    return it("iterates zero times for an unknown set", function()
      local count = 0
      for _ in lib:IterateSet("No.Such.Set") do
        count = count + 1
      end
      return assert.are.equal(0, count)
    end)
  end)
  describe("introspection and laziness", function()
    it("SetsFor lists the sets holding a spell", function()
      return assert.are.same({
        "Spell.Buff.Self"
      }, lib:SetsFor(92001))
    end)
    it("Sets lists every registered set, sorted", function()
      return assert.are.same({
        "Spell.Buff.Self",
        "Spell.Conjure.Food",
        "Spell.Heal.Direct"
      }, lib:Sets())
    end)
    it("parses each set at most once", function()
      lib:_ResetCache()
      lib:SpellInSet(92001, "Spell.Buff.Self")
      lib:SpellInSet(92002, "Spell.Buff.Self")
      return assert.are.equal(1, lib.parseCount)
    end)
    return it("Manifest reports the domain", function()
      lib:AddManifest({
        build = "1.60.1.70790"
      })
      local m = lib:Manifest()
      assert.are.equal("1.60.1.70790", m.build)
      return assert.are.equal(3, m.domains.Spell.sets)
    end)
  end)
  return describe("AddData revisions", function()
    it("is a no-op at the same revision", function()
      assert.is_false(lib:AddData("Spell", 1, {
        ["Other"] = "1"
      }))
      return assert.is_nil(lib:SpellInSet(1, "Other"))
    end)
    return it("replaces wholesale at a new revision", function()
      lib:AddData("Spell", 2, {
        ["Fresh"] = "7:3"
      })
      assert.are.equal(3, lib:SpellInSet(7, "Fresh"))
      return assert.is_nil(lib:SpellInSet(92001, "Spell.Buff.Self"))
    end)
  end)
end)
