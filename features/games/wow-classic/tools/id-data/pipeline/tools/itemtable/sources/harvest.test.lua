local adapter = dofile("tools/itemtable/sources/harvest.lua")
local validate = dofile("tools/itemtable/validate.lua")
local sampleDb
sampleDb = function()
  return {
    meta = {
      build = "1.60.1.70790"
    },
    items = {
      [101] = {
        id = 101,
        name = "Flask of Agility",
        class = "Consumable",
        subclass = "Flask",
        quality = 4,
        ilvl = 60,
        stackable = 5,
        spellName = "Flask of Agility",
        spellId = 9001
      },
      [102] = {
        id = 102,
        name = "Iron Bar",
        class = "Trade Goods",
        subclass = "Metal",
        quality = 1,
        ilvl = 20,
        stackable = 20
      }
    }
  }
end
describe("itemtable harvest source", function()
  describe("toModel", function()
    it("produces a document the model validator accepts", function()
      local doc = adapter.toModel(sampleDb())
      local ok, errors = validate.validate(doc)
      assert.are.same({ }, (function()
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #errors do
          local e = errors[_index_0]
          _accum_0[_len_0] = e.path
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)())
      return assert.is_true(ok)
    end)
    it("carries the build through from the harvest meta", function()
      return assert.are.equal("1.60.1.70790", adapter.toModel(sampleDb()).build)
    end)
    it("lets an explicit build override the recorded one", function()
      return assert.are.equal("override", adapter.toModel(sampleDb(), {
        build = "override"
      }).build)
    end)
    it("falls back to unknown when the dump records no build", function()
      local db = sampleDb()
      db.meta = nil
      return assert.are.equal("unknown", adapter.toModel(db).build)
    end)
    it("marks the document as coming from the harvest source", function()
      return assert.are.equal("harvest", adapter.toModel(sampleDb()).source)
    end)
    it("emits one item per harvested record, ordered by id", function()
      local doc = adapter.toModel(sampleDb())
      return assert.are.same({
        101,
        102
      }, (function()
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = doc.items
        for _index_0 = 1, #_list_0 do
          local it = _list_0[_index_0]
          _accum_0[_len_0] = it.id
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)())
    end)
    it("emits an itemEffect and a spell only for items with a use spell", function()
      local doc = adapter.toModel(sampleDb())
      assert.are.equal(1, #doc.itemEffects)
      assert.are.equal(101, doc.itemEffects[1].itemId)
      assert.are.equal("use", doc.itemEffects[1].trigger)
      assert.are.equal(1, #doc.spells)
      return assert.are.equal(9001, doc.spells[1].id)
    end)
    it("does not duplicate a spell shared by two items", function()
      local db = sampleDb()
      db.items[103] = {
        id = 103,
        name = "Second Flask",
        class = "Consumable",
        spellName = "Flask of Agility",
        spellId = 9001
      }
      local doc = adapter.toModel(db)
      assert.are.equal(1, #doc.spells)
      return assert.are.equal(2, #doc.itemEffects)
    end)
    it("leaves spellEffects empty, because the client does not expose them", function()
      return assert.are.same({ }, adapter.toModel(sampleDb()).spellEffects)
    end)
    it("skips a record with no name rather than emitting a half-item", function()
      local db = sampleDb()
      db.items[104] = {
        id = 104,
        secret = true
      }
      local doc = adapter.toModel(db)
      assert.are.equal(2, #doc.items)
      local ok = validate.validate(doc)
      return assert.is_true(ok)
    end)
    it("is deterministic: the same dump yields the same ordering twice", function()
      local first = adapter.toModel(sampleDb())
      local second = adapter.toModel(sampleDb())
      return assert.are.same((function()
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = first.items
        for _index_0 = 1, #_list_0 do
          local it = _list_0[_index_0]
          _accum_0[_len_0] = it.id
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)(), (function()
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = second.items
        for _index_0 = 1, #_list_0 do
          local it = _list_0[_index_0]
          _accum_0[_len_0] = it.id
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)())
    end)
    return it("handles an empty dump", function()
      local doc = adapter.toModel({
        items = { }
      })
      assert.are.same({ }, doc.items)
      return assert.is_true((validate.validate(doc)))
    end)
  end)
  describe("secretCount", function()
    it("counts records the harvester flagged", function()
      local db = sampleDb()
      db.items[101].secret = true
      return assert.are.equal(1, adapter.secretCount(db))
    end)
    return it("is zero for a clean dump and for junk input", function()
      assert.are.equal(0, adapter.secretCount(sampleDb()))
      assert.are.equal(0, adapter.secretCount(nil))
      return assert.are.equal(0, adapter.secretCount({ }))
    end)
  end)
  return describe("loadDump", function()
    it("reads a SavedVariables file and returns the db table", function()
      local path = os.tmpname()
      local fh = io.open(path, "w")
      fh:write('idAutomation_HarvestDB = { items = { [7] = { id = 7, name = "X", class = "Consumable" } } }\n')
      fh:close()
      local db, err = adapter.loadDump(path)
      os.remove(path)
      assert.is_nil(err)
      return assert.are.equal("X", db.items[7].name)
    end)
    it("reports a file that defines no harvest db", function()
      local path = os.tmpname()
      local fh = io.open(path, "w")
      fh:write("somethingElse = 1\n")
      fh:close()
      local db, err = adapter.loadDump(path)
      os.remove(path)
      assert.is_nil(db)
      return assert.is_truthy(err:find("defines no", 1, true))
    end)
    return it("reports a missing file", function()
      local db, err = adapter.loadDump("/nonexistent/harvest.lua")
      assert.is_nil(db)
      return assert.is_truthy(err:find("cannot load", 1, true))
    end)
  end)
end)
return describe("itemtable harvest spell rows", function()
  local bookDb
  bookDb = function()
    local db = sampleDb()
    db.spellMeta = {
      classFile = "MAGE",
      level = 40
    }
    db.spells = {
      [92002] = {
        id = 92002,
        name = "Arcane Brilliance",
        classFile = "MAGE"
      },
      [92003] = {
        id = 92003,
        name = "Conjure Rations",
        classFile = "MAGE"
      }
    }
    return db
  end
  it("emits spellClass rows for the swept class only", function()
    local doc = adapter.toModel(bookDb())
    assert.are.equal(2, #doc.spellClass)
    local _list_0 = doc.spellClass
    for _index_0 = 1, #_list_0 do
      local row = _list_0[_index_0]
      assert.are.equal("MAGE", row.classFile)
    end
  end)
  it("adds the swept spells to the document", function()
    local doc = adapter.toModel(bookDb())
    local ids
    do
      local _accum_0 = { }
      local _len_0 = 1
      local _list_0 = doc.spells
      for _index_0 = 1, #_list_0 do
        local sp = _list_0[_index_0]
        _accum_0[_len_0] = sp.id
        _len_0 = _len_0 + 1
      end
      ids = _accum_0
    end
    return assert.is_truthy(ids[#ids] >= 92003)
  end)
  it("produces a document the validator accepts", function()
    local ok, errors = validate.validate(adapter.toModel(bookDb()))
    assert.are.same({ }, (function()
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #errors do
        local e = errors[_index_0]
        _accum_0[_len_0] = e.path
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end)())
    return assert.is_true(ok)
  end)
  it("emits nothing when the dump never recorded whose book it was", function()
    local db = bookDb()
    db.spellMeta = nil
    return assert.is_nil(adapter.toModel(db).spellClass)
  end)
  it("is deterministic in ordering", function()
    local a
    do
      local _accum_0 = { }
      local _len_0 = 1
      local _list_0 = adapter.toModel(bookDb()).spellClass
      for _index_0 = 1, #_list_0 do
        local r = _list_0[_index_0]
        _accum_0[_len_0] = r.spellId
        _len_0 = _len_0 + 1
      end
      a = _accum_0
    end
    local b
    do
      local _accum_0 = { }
      local _len_0 = 1
      local _list_0 = adapter.toModel(bookDb()).spellClass
      for _index_0 = 1, #_list_0 do
        local r = _list_0[_index_0]
        _accum_0[_len_0] = r.spellId
        _len_0 = _len_0 + 1
      end
      b = _accum_0
    end
    return assert.are.same(a, b)
  end)
  return describe("periodic damage", function()
    it("emits NO spellPeriodic collection, because it cannot measure a tick", function()
      local doc = adapter.toModel(bookDb())
      return assert.is_nil(doc.spellPeriodic, "the spellbook exposes no tick size; a row here would be invented")
    end)
    it("still corroborates that a periodic spell is castable by its class", function()
      local db = bookDb()
      db.spells[92007] = {
        id = 92007,
        name = "Shadow Blight",
        classFile = "MAGE"
      }
      local doc = adapter.toModel(db)
      local castable = { }
      local _list_0 = doc.spellClass
      for _index_0 = 1, #_list_0 do
        local row = _list_0[_index_0]
        castable[row.spellId] = row.classFile
      end
      return assert.are.equal("MAGE", castable[92007])
    end)
    it("declares its partiality by carrying no spell effects at all", function()
      local doc = adapter.toModel(bookDb())
      assert.are.same({ }, doc.spellEffects)
      return assert.is_nil(doc.spellPeriodic)
    end)
    return it("produces a validator-accepted document once a periodic spell is swept", function()
      local db = bookDb()
      db.spells[92007] = {
        id = 92007,
        name = "Shadow Blight",
        classFile = "MAGE"
      }
      local ok, errors = validate.validate(adapter.toModel(db))
      assert.are.same({ }, (function()
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #errors do
          local e = errors[_index_0]
          _accum_0[_len_0] = e.path
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)())
      return assert.is_true(ok)
    end)
  end)
end)
