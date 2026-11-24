local emit = dofile("tools/itemtable/emit.lua")
local classify = dofile("tools/itemtable/classify.lua")
local rules = dofile("tools/itemtable/rules/consumable.lua")
local fixtures
fixtures = function()
  return dofile("tools/itemtable/fixtures.lua")
end
local result
result = function()
  return classify.run(fixtures(), rules)
end
local loadIntoLib
loadIntoLib = function(chunks)
  local saved = _G.LibStub
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
  dofile("../../../Interface/AddOns/idLibSetTable/idLibSetTable.lua")
  local lib = dofile("../../../Interface/AddOns/idLibItemTable/idLibItemTable.lua")
  for _index_0 = 1, #chunks do
    local chunk = chunks[_index_0]
    assert(load or loadstring)(chunk)()
  end
  _G.LibStub = saved
  return lib
end
return describe("itemtable emit", function()
  describe("reproducibility", function()
    it("produces identical bytes for identical inputs", function()
      local a = emit.domainChunk("Consumable", 1, result())
      local b = emit.domainChunk("Consumable", 1, result())
      return assert.are.equal(a, b)
    end)
    it("orders set names deterministically regardless of table order", function()
      local chunk = emit.domainChunk("Consumable", 1, result())
      local names
      do
        local _accum_0 = { }
        local _len_0 = 1
        for n in chunk:gmatch('%[("[^"]+")%] =') do
          _accum_0[_len_0] = n
          _len_0 = _len_0 + 1
        end
        names = _accum_0
      end
      local sorted
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #names do
          local n = names[_index_0]
          _accum_0[_len_0] = n
          _len_0 = _len_0 + 1
        end
        sorted = _accum_0
      end
      table.sort(sorted)
      return assert.are.same(sorted, names)
    end)
    return it("records no wall-clock timestamp, which would break reproducibility", function()
      local chunk = emit.manifestChunk({
        build = "1.60.1.70790"
      })
      assert.is_nil(chunk:find("generatedAt", 1, true))
      return assert.are.equal(chunk, emit.manifestChunk({
        build = "1.60.1.70790"
      }))
    end)
  end)
  describe("the emitted chunk", function()
    it("declares itself generated and warns against hand-editing", function()
      local chunk = emit.domainChunk("Consumable", 1, result())
      assert.is_truthy(chunk:find("GENERATED", 1, true))
      return assert.is_truthy(chunk:find("Do not edit", 1, true))
    end)
    it("no-ops when the library is absent rather than erroring", function()
      local chunk = emit.domainChunk("Consumable", 1, result())
      assert.is_truthy(chunk:find("if not lib then return end", 1, true))
      local saved = _G.LibStub
      _G.LibStub = nil
      assert.has_no.errors(function()
        return assert(load or loadstring)(chunk)()
      end)
      _G.LibStub = saved
    end)
    return it("escapes set names containing spaces and punctuation", function()
      local chunk = emit.domainChunk("Consumable", 1, result())
      return assert.is_truthy(chunk:find('"Consumable.Weapon Buff.Oil.Wizard"', 1, true))
    end)
  end)
  describe("round-trip through the runtime library", function()
    it("answers ItemInSet exactly as the classifier decided", function()
      local r = result()
      local lib = loadIntoLib({
        emit.domainChunk("Consumable", 1, r)
      })
      local checked = 0
      for setName, members in pairs(r.sets) do
        for id, value in pairs(members) do
          assert.are.equal(value, lib:ItemInSet(id, setName), ("%s / item %d disagrees"):format(setName, id))
          checked = checked + 1
        end
      end
      return assert.is_true(checked > 0)
    end)
    it("iterates each set with the same membership", function()
      local r = result()
      local lib = loadIntoLib({
        emit.domainChunk("Consumable", 1, r)
      })
      for setName, members in pairs(r.sets) do
        local seen = { }
        for id, value in lib:IterateSet(setName) do
          seen[id] = value
        end
        assert.are.same(members, seen, setName)
      end
    end)
    it("reports nothing for an item that was never classified", function()
      local lib = loadIntoLib({
        emit.domainChunk("Consumable", 1, result())
      })
      return assert.is_nil(lib:ItemInSet(90009, "Consumable.Buff.Agility.Flask"))
    end)
    return it("carries the manifest through", function()
      local lib = loadIntoLib({
        emit.manifestChunk({
          build = "1.60.1.70790",
          classified = 8
        }),
        emit.domainChunk("Consumable", 1, result())
      })
      local m = lib:Manifest()
      assert.are.equal("1.60.1.70790", m.build)
      assert.are.equal(8, m.classified)
      return assert.are.equal(1, m.domains.Consumable.revision)
    end)
  end)
  return describe("dataXml", function()
    it("preserves the caller's order so the manifest loads first", function()
      local xml = emit.dataXml({
        "manifest.lua",
        "Consumable.lua"
      })
      local manifestAt = xml:find("manifest.lua", 1, true)
      local domainAt = xml:find("Consumable.lua", 1, true)
      return assert.is_true(manifestAt < domainAt)
    end)
    return it("lists every file as a Script include", function()
      local xml = emit.dataXml({
        "a.lua",
        "b.lua"
      })
      assert.is_truthy(xml:find('<Script file="a.lua"/>', 1, true))
      return assert.is_truthy(xml:find('<Script file="b.lua"/>', 1, true))
    end)
  end)
end)
