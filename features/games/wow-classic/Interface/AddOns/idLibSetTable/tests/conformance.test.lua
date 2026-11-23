local LIBRARIES = {
  {
    major = "idLibItemTable-1.0",
    path = (debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../idLibItemTable/idLibItemTable.lua"),
    member = "ItemInSet"
  },
  {
    major = "idLibSpellTable-1.0",
    path = (debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../idLibSpellTable/idLibSpellTable.lua"),
    member = "SpellInSet"
  },
  {
    major = "idLibTalentTable-1.0",
    path = (debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../idLibTalentTable/idLibTalentTable.lua"),
    member = "TalentInSet"
  }
}
local REQUIRED = {
  "AddData",
  "AddManifest",
  "IterateSet",
  "SetsFor",
  "Sets",
  "Manifest",
  "_ResetCache"
}
local SAMPLE = {
  ["Test.Alpha"] = "1001:10,1002:12",
  ["Test.Beta"] = "1002",
  ["Test.Gamma"] = "1003:300,1001:7"
}
local PRESENT = {
  1001,
  1002,
  1003
}
local ABSENT = 9999
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
load = function(spec, withData)
  if withData == nil then
    withData = true
  end
  _G.LibStub = makeLibStub()
  dofile((debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../idLibSetTable/idLibSetTable.lua"))
  local lib = dofile(spec.path)
  if withData then
    lib:AddData("D", 1, SAMPLE)
  end
  return lib
end
local inSet
inSet = function(lib, spec, id, set)
  return lib[spec.member](lib, id, set)
end
for _index_0 = 1, #LIBRARIES do
  local spec = LIBRARIES[_index_0]
  describe("set-library contract: " .. tostring(spec.major), function()
    local lib, savedLibStub
    before_each(function()
      savedLibStub = _G.LibStub
      lib = load(spec)
    end)
    after_each(function()
      _G.LibStub = savedLibStub
    end)
    describe("registration", function()
      it("registers under its own name", function()
        return assert.are.equal(lib, _G.LibStub:GetLibrary(spec.major))
      end)
      it("exposes every method the contract requires", function()
        assert.is_function(lib[spec.member], spec.member)
        for _index_1 = 1, #REQUIRED do
          local name = REQUIRED[_index_1]
          assert.is_function(lib[name], name)
        end
      end)
      return it("refuses to load over a newer copy of itself", function()
        _G.LibStub = makeLibStub()
        dofile((debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../idLibSetTable/idLibSetTable.lua"))
        local first = dofile(spec.path)
        first:AddData("D", 1, SAMPLE)
        local second = dofile(spec.path)
        assert.is_nil(second)
        return assert.are.equal(10, inSet(first, spec, 1001, "Test.Alpha"))
      end)
    end)
    describe("membership", function()
      it("returns the explicit value", function()
        assert.are.equal(10, inSet(lib, spec, 1001, "Test.Alpha"))
        return assert.are.equal(12, inSet(lib, spec, 1002, "Test.Alpha"))
      end)
      it("returns 1 for a member listed without a value", function()
        return assert.are.equal(1, inSet(lib, spec, 1002, "Test.Beta"))
      end)
      it("returns nil for a non-member", function()
        return assert.is_nil(inSet(lib, spec, ABSENT, "Test.Alpha"))
      end)
      it("returns nil for an unknown set rather than erroring", function()
        return assert.is_nil(inSet(lib, spec, 1001, "Test.Nonexistent"))
      end)
      it("accepts a numeric string id, as LPT does", function()
        return assert.are.equal(10, inSet(lib, spec, "1001", "Test.Alpha"))
      end)
      it("returns nil for junk instead of erroring", function()
        local _list_0 = {
          nil,
          "abc",
          true,
          { }
        }
        for _index_1 = 1, #_list_0 do
          local bad = _list_0[_index_1]
          assert.is_nil(inSet(lib, spec, bad, "Test.Alpha"), tostring(bad))
        end
        local _list_1 = {
          nil,
          42,
          true,
          { }
        }
        for _index_1 = 1, #_list_1 do
          local badSet = _list_1[_index_1]
          assert.is_nil(inSet(lib, spec, 1001, badSet), tostring(badSet))
        end
      end)
      return it("reads the same value from two different sets", function()
        assert.are.equal(10, inSet(lib, spec, 1001, "Test.Alpha"))
        return assert.are.equal(7, inSet(lib, spec, 1001, "Test.Gamma"))
      end)
    end)
    describe("iteration", function()
      it("iterates a set's exact membership", function()
        local seen = { }
        for id, value in lib:IterateSet("Test.Alpha") do
          seen[id] = value
        end
        return assert.are.same({
          [1001] = 10,
          [1002] = 12
        }, seen)
      end)
      it("returns the stateless `next, table` pair", function()
        local iter, state = lib:IterateSet("Test.Alpha")
        assert.is_function(iter)
        assert.is_table(state)
        local seen, control = { }, nil
        while true do
          local id, value = iter(state, control)
          if id == nil then
            break
          end
          seen[id] = value
          control = id
        end
        return assert.are.same({
          [1001] = 10,
          [1002] = 12
        }, seen)
      end)
      it("iterates an unknown set zero times", function()
        local count = 0
        for _ in lib:IterateSet("Test.Nonexistent") do
          count = count + 1
        end
        return assert.are.equal(0, count)
      end)
      return it("iterates junk zero times rather than erroring", function()
        local _list_0 = {
          nil,
          42,
          true,
          { }
        }
        for _index_1 = 1, #_list_0 do
          local bad = _list_0[_index_1]
          local count = 0
          for _ in lib:IterateSet(bad) do
            count = count + 1
          end
          assert.are.equal(0, count, tostring(bad))
        end
      end)
    end)
    describe("introspection", function()
      it("lists every set, sorted", function()
        return assert.are.same({
          "Test.Alpha",
          "Test.Beta",
          "Test.Gamma"
        }, lib:Sets())
      end)
      it("lists the sets an id belongs to, sorted", function()
        assert.are.same({
          "Test.Alpha",
          "Test.Gamma"
        }, lib:SetsFor(1001))
        return assert.are.same({
          "Test.Alpha",
          "Test.Beta"
        }, lib:SetsFor(1002))
      end)
      it("lists nothing for an id in no set", function()
        return assert.are.same({ }, lib:SetsFor(ABSENT))
      end)
      it("lists nothing for junk", function()
        local _list_0 = {
          nil,
          "abc",
          true,
          { }
        }
        for _index_1 = 1, #_list_0 do
          local bad = _list_0[_index_1]
          assert.are.same({ }, lib:SetsFor(bad))
        end
      end)
      it("reports the domains and set counts it holds", function()
        local m = lib:Manifest()
        assert.are.equal(1, m.domains.D.revision)
        return assert.are.equal(3, m.domains.D.sets)
      end)
      it("carries manifest metadata through", function()
        lib:AddManifest({
          build = "1.60.1.70790",
          source = "test"
        })
        local m = lib:Manifest()
        assert.are.equal("1.60.1.70790", m.build)
        return assert.are.equal("test", m.source)
      end)
      return it("ignores a junk manifest rather than erroring", function()
        assert.is_false(lib:AddManifest("nope"))
        return assert.is_false(lib:AddManifest(nil))
      end)
    end)
    describe("laziness", function()
      it("parses nothing until a set is asked for", function()
        local fresh = load(spec)
        return assert.are.equal(0, fresh.parseCount)
      end)
      it("parses a set once, on first use", function()
        lib:_ResetCache()
        inSet(lib, spec, 1001, "Test.Alpha")
        return assert.are.equal(1, lib.parseCount)
      end)
      it("does not re-parse a set it has already parsed", function()
        lib:_ResetCache()
        inSet(lib, spec, 1001, "Test.Alpha")
        inSet(lib, spec, 1002, "Test.Alpha")
        local count = 0
        for _ in lib:IterateSet("Test.Alpha") do
          count = count + 1
        end
        return assert.are.equal(1, lib.parseCount)
      end)
      it("parses each set separately", function()
        lib:_ResetCache()
        inSet(lib, spec, 1001, "Test.Alpha")
        inSet(lib, spec, 1003, "Test.Gamma")
        return assert.are.equal(2, lib.parseCount)
      end)
      return it("parses nothing for an unknown set", function()
        lib:_ResetCache()
        inSet(lib, spec, 1001, "Test.Nonexistent")
        return assert.are.equal(0, lib.parseCount)
      end)
    end)
    return describe("AddData", function()
      it("ignores a re-registration at the same revision", function()
        assert.is_false(lib:AddData("D", 1, {
          ["Test.Delta"] = "1"
        }))
        return assert.is_nil(inSet(lib, spec, 1, "Test.Delta"))
      end)
      it("replaces a domain's sets wholesale at a new revision", function()
        assert.is_true(lib:AddData("D", 2, {
          ["Test.Delta"] = "1:5"
        }))
        assert.are.equal(5, inSet(lib, spec, 1, "Test.Delta"))
        assert.is_nil(inSet(lib, spec, 1001, "Test.Alpha"))
        return assert.are.same({
          "Test.Delta"
        }, lib:Sets())
      end)
      it("keeps other domains when one is replaced", function()
        lib:AddData("Other", 1, {
          ["Test.Omega"] = "77"
        })
        lib:AddData("D", 2, {
          ["Test.Delta"] = "1:5"
        })
        return assert.are.equal(1, inSet(lib, spec, 77, "Test.Omega"))
      end)
      it("drops a stale parse when a domain is replaced", function()
        inSet(lib, spec, 1001, "Test.Alpha")
        lib:AddData("D", 2, {
          ["Test.Alpha"] = "1001:99"
        })
        return assert.are.equal(99, inSet(lib, spec, 1001, "Test.Alpha"))
      end)
      it("skips entries that are not string -> string", function()
        lib:AddData("Junk", 1, {
          ["Test.Bad"] = 42,
          [7] = "1:1",
          ["Test.Ok"] = "5:5"
        })
        assert.are.equal(5, inSet(lib, spec, 5, "Test.Ok"))
        return assert.is_nil(inSet(lib, spec, 42, "Test.Bad"))
      end)
      return it("errors loudly on a missing domain name or data table", function()
        assert.has_error(function()
          return lib:AddData(nil, 1, { })
        end)
        assert.has_error(function()
          return lib:AddData("", 1, { })
        end)
        return assert.has_error(function()
          return lib:AddData("D2", 1, "not a table")
        end)
      end)
    end)
  end)
end
return describe("set-library contract: the registry itself", function()
  it("covers more than one library", function()
    return assert.is_true(#LIBRARIES > 1)
  end)
  it("gives every library a distinct name, path and accessor", function()
    local seen = { }
    for _index_0 = 1, #LIBRARIES do
      local spec = LIBRARIES[_index_0]
      local _list_0 = {
        "major",
        "path",
        "member"
      }
      for _index_1 = 1, #_list_0 do
        local field = _list_0[_index_1]
        local key = tostring(field) .. ":" .. tostring(spec[field])
        assert.is_nil(seen[key], key)
        seen[key] = true
      end
    end
  end)
  it("names a readable file for every library", function()
    for _index_0 = 1, #LIBRARIES do
      local spec = LIBRARIES[_index_0]
      local fh = io.open(spec.path, "r")
      assert.is_not_nil(fh, spec.path)
      fh:close()
    end
  end)
  return it("holds libraries that are genuinely separate objects", function()
    _G.LibStub = makeLibStub()
    dofile((debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../idLibSetTable/idLibSetTable.lua"))
    local loaded
    do
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #LIBRARIES do
        local spec = LIBRARIES[_index_0]
        _accum_0[_len_0] = dofile(spec.path)
        _len_0 = _len_0 + 1
      end
      loaded = _accum_0
    end
    for i = 1, #loaded do
      for j = i + 1, #loaded do
        assert.are_not.equal(loaded[i], loaded[j])
      end
    end
  end)
end)
