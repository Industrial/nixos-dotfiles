local emit = dofile("tools/itemtable/emit.lua")
local classify = dofile("tools/itemtable/classify.lua")
local spell = dofile("tools/itemtable/rules/spell.lua")
local consumable = dofile("tools/itemtable/rules/consumable.lua")
local fixtures
fixtures = function()
  return dofile("tools/itemtable/fixtures.lua")
end
local spellResult
spellResult = function()
  local doc = fixtures()
  return classify.run(doc, spell.forDocument(doc))
end
local loadIntoLibs
loadIntoLibs = function(chunks)
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
  local itemLib = dofile("../../../Interface/AddOns/idLibItemTable/idLibItemTable.lua")
  local spellLib = dofile("../../../Interface/AddOns/idLibSpellTable/idLibSpellTable.lua")
  for _index_0 = 1, #chunks do
    local chunk = chunks[_index_0]
    assert(load or loadstring)(chunk)()
  end
  _G.LibStub = saved
  return itemLib, spellLib
end
return describe("itemtable spell emit", function()
  describe("library routing", function()
    it("sends the spell domain to LibSpellTable", function()
      return assert.are.equal("idLibSpellTable-1.0", emit.libraryFor("Spell"))
    end)
    it("sends item domains to LibItemTable", function()
      assert.are.equal("idLibItemTable-1.0", emit.libraryFor("Consumable"))
      return assert.are.equal("idLibItemTable-1.0", emit.libraryFor("Tradeskill"))
    end)
    it("defaults an unknown domain to LibItemTable rather than erroring", function()
      return assert.are.equal("idLibItemTable-1.0", emit.libraryFor("Enchant"))
    end)
    return it("names that library inside the chunk it generates", function()
      local chunk = emit.domainChunk("Spell", 1, spellResult())
      assert.is_truthy(chunk:find('LibStub("idLibSpellTable-1.0", true)', 1, true))
      return assert.is_nil(chunk:find("LibItemTable", 1, true))
    end)
  end)
  describe("round-trip through LibSpellTable", function()
    it("answers SpellInSet exactly as the classifier decided", function()
      local r = spellResult()
      local _, spellLib = loadIntoLibs({
        emit.domainChunk("Spell", 1, r)
      })
      local checked = 0
      for setName, members in pairs(r.sets) do
        for id, value in pairs(members) do
          assert.are.equal(value, spellLib:SpellInSet(id, setName), ("%s / spell %d disagrees"):format(setName, id))
          checked = checked + 1
        end
      end
      return assert.is_true(checked > 0)
    end)
    it("iterates each set with the same membership", function()
      local r = spellResult()
      local _, spellLib = loadIntoLibs({
        emit.domainChunk("Spell", 1, r)
      })
      for setName, members in pairs(r.sets) do
        local seen = { }
        for id, value in spellLib:IterateSet(setName) do
          seen[id] = value
        end
        assert.are.same(members, seen, setName)
      end
    end)
    return it("leaves the item library untouched by spell data", function()
      local itemLib = loadIntoLibs({
        emit.domainChunk("Spell", 1, spellResult())
      })
      return assert.are.same({ }, itemLib:Sets())
    end)
  end)
  describe("the DoT sets through the real library", function()
    local DOT_SETS = {
      "Spell.DoT.Amount",
      "Spell.DoT.Period",
      "Spell.DoT.Duration",
      "Spell.DoT.Coefficient",
      "Spell.DoT.ApCoefficient",
      "Spell.DoT.School"
    }
    it("answers the per-tick amount a predictor asks for", function()
      local _, spellLib = loadIntoLibs({
        emit.domainChunk("Spell", 1, spellResult())
      })
      assert.are.equal(60, spellLib:SpellInSet(92007, "Spell.DoT.Amount"))
      assert.are.equal(3000, spellLib:SpellInSet(92007, "Spell.DoT.Period"))
      return assert.are.equal(18000, spellLib:SpellInSet(92007, "Spell.DoT.Duration"))
    end)
    it("carries a fractional coefficient through the encoder intact", function()
      local _, spellLib = loadIntoLibs({
        emit.domainChunk("Spell", 1, spellResult())
      })
      assert.are.equal(0.156, spellLib:SpellInSet(92007, "Spell.DoT.Coefficient"))
      return assert.are.equal(0.08, spellLib:SpellInSet(92008, "Spell.DoT.ApCoefficient"))
    end)
    it("ships no DoT set with zero members", function()
      local r = spellResult()
      local _, spellLib = loadIntoLibs({
        emit.domainChunk("Spell", 1, r)
      })
      for _index_0 = 1, #DOT_SETS do
        local setName = DOT_SETS[_index_0]
        local count = 0
        for _id in spellLib:IterateSet(setName) do
          count = count + 1
        end
        assert.is_true(count > 0, setName .. " emitted with no members")
      end
    end)
    return it("decodes one DoT set without parsing the others", function()
      local _, spellLib = loadIntoLibs({
        emit.domainChunk("Spell", 1, spellResult())
      })
      local before = spellLib.parseCount
      spellLib:SpellInSet(92007, "Spell.DoT.Amount")
      assert.are.equal(before + 1, spellLib.parseCount)
      spellLib:SpellInSet(92008, "Spell.DoT.Amount")
      return assert.are.equal(before + 1, spellLib.parseCount)
    end)
  end)
  describe("the shipped data directories", function()
    local DATA_DIRS = {
      "Libs/idLibItemTable-1.0/data",
      "Libs/idLibSpellTable-1.0/data",
      "Libs/idLibTalentTable-1.0/data"
    }
    return it("contain no fixture-band ids", function()
      local offenders = { }
      for _index_0 = 1, #DATA_DIRS do
        local _continue_0 = false
        repeat
          local dir = DATA_DIRS[_index_0]
          local handle = io.popen(("ls %s/*.lua 2>/dev/null"):format(dir))
          if not (handle) then
            _continue_0 = true
            break
          end
          for path in handle:lines() do
            local _continue_1 = false
            repeat
              local fh = io.open(path, "r")
              if not (fh) then
                _continue_1 = true
                break
              end
              local text = fh:read("*a")
              fh:close()
              if text:find("%f[%d]9[0-9][0-9][0-9][0-9]%f[%D]") then
                offenders[#offenders + 1] = path
              end
              _continue_1 = true
            until true
            if not _continue_1 then
              break
            end
          end
          handle:close()
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      return assert.are.same({ }, offenders, "fixture ids found in shipped data: " .. table.concat(offenders, ", "))
    end)
  end)
  describe("two libraries, one pipeline", function()
    it("keeps each domain's sets in its own library", function()
      local doc = fixtures()
      local itemLib, spellLib = loadIntoLibs({
        emit.domainChunk("Consumable", 1, classify.run(doc, consumable)),
        emit.domainChunk("Spell", 1, classify.run(doc, spell.forDocument(doc)))
      })
      local itemSets, spellSets = itemLib:Sets(), spellLib:Sets()
      assert.is_true(#itemSets > 0)
      assert.is_true(#spellSets > 0)
      for _index_0 = 1, #itemSets do
        local name = itemSets[_index_0]
        assert.is_nil((name:match("^Spell%.")), ("%s leaked into the item library"):format(name))
      end
      for _index_0 = 1, #spellSets do
        local name = spellSets[_index_0]
        assert.is_truthy((name:match("^Spell%.")), ("%s is not a spell set"):format(name))
      end
    end)
    it("gives each library a manifest naming itself", function()
      local item = emit.manifestChunk({
        build = "1.60.1.70790"
      }, "idLibItemTable-1.0")
      local sp = emit.manifestChunk({
        build = "1.60.1.70790"
      }, "idLibSpellTable-1.0")
      assert.is_truthy(item:find('LibStub("idLibItemTable-1.0"', 1, true))
      return assert.is_truthy(sp:find('LibStub("idLibSpellTable-1.0"', 1, true))
    end)
    it("still records no wall clock, in either library's manifest", function()
      local sp = emit.manifestChunk({
        build = "1.60.1.70790"
      }, "idLibSpellTable-1.0")
      assert.is_nil(sp:find("generatedAt", 1, true))
      return assert.are.equal(sp, emit.manifestChunk({
        build = "1.60.1.70790"
      }, "idLibSpellTable-1.0"))
    end)
    return it("is byte-reproducible for the spell domain too", function()
      return assert.are.equal((emit.domainChunk("Spell", 1, spellResult())), (emit.domainChunk("Spell", 1, spellResult())))
    end)
  end)
  return describe("writeAll routing", function()
    local tmp
    tmp = function()
      return os.getenv("TMPDIR") or "/tmp"
    end
    before_each(function()
      return os.execute(("rm -rf %s/itemtable-emit-test && mkdir -p %s/itemtable-emit-test/item %s/itemtable-emit-test/spell"):format(tmp(), tmp(), tmp()))
    end)
    local dirs
    dirs = function()
      return {
        ["idLibItemTable-1.0"] = ("%s/itemtable-emit-test/item"):format(tmp()),
        ["idLibSpellTable-1.0"] = ("%s/itemtable-emit-test/spell"):format(tmp())
      }
    end
    local exists
    exists = function(path)
      local fh = io.open(path, "r")
      if not (fh) then
        return false
      end
      fh:close()
      return true
    end
    local read
    read = function(path)
      local fh = assert(io.open(path, "r"))
      local body = fh:read("*a")
      fh:close()
      return body
    end
    local payload
    payload = function()
      local doc = fixtures()
      return {
        Consumable = {
          revision = 1,
          result = classify.run(doc, consumable)
        },
        Spell = {
          revision = 1,
          result = classify.run(doc, spell.forDocument(doc))
        }
      }
    end
    it("writes each domain under its own library's directory", function()
      local d = dirs()
      local written = assert(emit.writeAll(d, payload(), {
        build = "1.60.1.70790"
      }))
      assert.is_true(exists(("%s/Consumable.lua"):format(d["idLibItemTable-1.0"])))
      assert.is_true(exists(("%s/Spell.lua"):format(d["idLibSpellTable-1.0"])))
      assert.is_false(exists(("%s/Spell.lua"):format(d["idLibItemTable-1.0"])))
      return assert.is_true(#written >= 4)
    end)
    it("gives each library its own manifest and include file", function()
      local d = dirs()
      emit.writeAll(d, payload(), {
        build = "1.60.1.70790"
      })
      for library, dir in pairs(d) do
        assert.is_true(exists(("%s/manifest.lua"):format(dir)))
        local xml = read(("%s/data.xml"):format(dir))
        assert.is_truthy(xml:find("manifest.lua", 1, true))
      end
    end)
    it("lists only that library's domains in its include file", function()
      local d = dirs()
      emit.writeAll(d, payload(), {
        build = "1.60.1.70790"
      })
      local itemXml = read(("%s/data.xml"):format(d["idLibItemTable-1.0"]))
      local spellXml = read(("%s/data.xml"):format(d["idLibSpellTable-1.0"]))
      assert.is_truthy(itemXml:find("Consumable.lua", 1, true))
      assert.is_nil(itemXml:find("Spell.lua", 1, true))
      assert.is_truthy(spellXml:find("Spell.lua", 1, true))
      return assert.is_nil(spellXml:find("Consumable.lua", 1, true))
    end)
    it("loads the manifest before any domain data", function()
      local d = dirs()
      emit.writeAll(d, payload(), {
        build = "1.60.1.70790"
      })
      local xml = read(("%s/data.xml"):format(d["idLibSpellTable-1.0"]))
      return assert.is_true((xml:find("manifest.lua", 1, true)) < (xml:find("Spell.lua", 1, true)))
    end)
    it("refuses rather than guessing when a library has no directory", function()
      local written, err = emit.writeAll({
        ["idLibItemTable-1.0"] = ("%s/itemtable-emit-test/item"):format(tmp())
      }, payload(), {
        build = "1.60.1.70790"
      })
      assert.is_nil(written)
      return assert.is_truthy(err:find("idLibSpellTable-1.0", 1, true))
    end)
    return it("still accepts a single directory for an item-only emit", function()
      local d = ("%s/itemtable-emit-test/item"):format(tmp())
      local doc = fixtures()
      local written = assert(emit.writeAll(d, {
        Consumable = {
          revision = 1,
          result = classify.run(doc, consumable)
        }
      }, {
        build = "1.60.1.70790"
      }))
      return assert.is_true(exists(("%s/Consumable.lua"):format(d)))
    end)
  end)
end)
