local validate = dofile("tools/itemtable/validate.lua")
local schema = dofile("tools/itemtable/schema.lua")
local fixtures
fixtures = function()
  return dofile("tools/itemtable/fixtures.lua")
end
local errorAt
errorAt = function(errors, path)
  for _index_0 = 1, #errors do
    local e = errors[_index_0]
    if e.path == path then
      return e
    end
  end
  return nil
end
local paths
paths = function(errors)
  local out
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #errors do
      local e = errors[_index_0]
      _accum_0[_len_0] = e.path
      _len_0 = _len_0 + 1
    end
    out = _accum_0
  end
  table.sort(out)
  return out
end
return describe("itemtable model validation", function()
  describe("the golden fixtures", function()
    it("validate cleanly", function()
      local ok, errors = validate.validate(fixtures())
      assert.are.same({ }, paths(errors))
      return assert.is_true(ok)
    end)
    it("cover every decision boundary the classifier needs", function()
      local doc = fixtures()
      local byId = { }
      local _list_0 = doc.items
      for _index_0 = 1, #_list_0 do
        local item = _list_0[_index_0]
        byId[item.id] = item
      end
      assert.are.equal(14, #doc.items)
      assert.are.equal("Potion", byId[90012].subclass)
      assert.are.equal("Bandage", byId[90014].subclass)
      assert.are.equal("Trade Goods", byId[90009].class)
      assert.are.equal("Cloth", byId[90010].subclass)
      assert.is_nil(byId[90011].subclass)
      local withEffects = { }
      local _list_1 = doc.itemEffects
      for _index_0 = 1, #_list_1 do
        local fx = _list_1[_index_0]
        withEffects[fx.itemId] = true
      end
      return assert.is_nil(withEffects[90009], "the control item must have no use effect")
    end)
    return it("use the reserved 90000+ id band so they can never pass as real items", function()
      local _list_0 = fixtures().items
      for _index_0 = 1, #_list_0 do
        local item = _list_0[_index_0]
        assert.is_true(item.id >= 90000, ("fixture item %d is outside the reserved band"):format(item.id))
      end
    end)
  end)
  describe("document-level checks", function()
    it("rejects a non-table document", function()
      local ok, errors = validate.validate("nope")
      assert.is_false(ok)
      return assert.are.equal(1, #errors)
    end)
    it("reports each missing required document field by name", function()
      local _list_0 = {
        "build",
        "source"
      }
      for _index_0 = 1, #_list_0 do
        local missing = _list_0[_index_0]
        local doc = fixtures()
        doc[missing] = nil
        local ok, errors = validate.validate(doc)
        assert.is_false(ok)
        assert.is_not_nil(errorAt(errors, missing), ("expected an error at %q"):format(missing))
      end
    end)
    it("refuses a document from a different schema major", function()
      local doc = fixtures()
      doc.schemaVersion = schema.SCHEMA_VERSION + 1
      local ok, errors = validate.validate(doc)
      assert.is_false(ok)
      return assert.is_not_nil(errorAt(errors, "schemaVersion"))
    end)
    return it("reports a missing collection", function()
      local doc = fixtures()
      doc.spells = nil
      local ok, errors = validate.validate(doc)
      assert.is_false(ok)
      return assert.is_not_nil(errorAt(errors, "spells"))
    end)
  end)
  describe("record-level checks", function()
    it("reports a missing required field with a pointer path", function()
      local doc = fixtures()
      doc.items[2].name = nil
      local ok, errors = validate.validate(doc)
      assert.is_false(ok)
      return assert.are.equal("required field missing", errorAt(errors, "items[2].name").message)
    end)
    it("reports a wrong field type", function()
      local doc = fixtures()
      doc.items[1].id = "90001"
      local ok, errors = validate.validate(doc)
      assert.is_false(ok)
      return assert.is_not_nil(errorAt(errors, "items[1].id"))
    end)
    it("rejects a non-integer where an int is required", function()
      local doc = fixtures()
      doc.items[1].quality = 1.5
      local ok, errors = validate.validate(doc)
      assert.is_false(ok)
      return assert.is_not_nil(errorAt(errors, "items[1].quality"))
    end)
    it("rejects an unknown field rather than silently dropping it", function()
      local doc = fixtures()
      doc.items[1].bogus = true
      local ok, errors = validate.validate(doc)
      assert.is_false(ok)
      return assert.are.equal("unknown field", errorAt(errors, "items[1].bogus").message)
    end)
    return it("rejects a duplicate key", function()
      local doc = fixtures()
      doc.items[#doc.items + 1] = {
        id = 90001,
        name = "dupe",
        class = "Consumable"
      }
      local ok, errors = validate.validate(doc)
      assert.is_false(ok)
      return assert.is_not_nil(errorAt(errors, ("items[%d].id"):format(#doc.items)))
    end)
  end)
  describe("referential integrity", function()
    it("rejects an effect pointing at an unknown item", function()
      local doc = fixtures()
      doc.itemEffects[1].itemId = 12345
      local ok, errors = validate.validate(doc)
      assert.is_false(ok)
      return assert.is_not_nil(errorAt(errors, "itemEffects[1].itemId"))
    end)
    it("rejects an effect pointing at an unknown spell", function()
      local doc = fixtures()
      doc.itemEffects[1].spellId = 12345
      local ok, errors = validate.validate(doc)
      assert.is_false(ok)
      return assert.is_not_nil(errorAt(errors, "itemEffects[1].spellId"))
    end)
    return it("rejects a spell effect pointing at an unknown spell", function()
      local doc = fixtures()
      doc.spellEffects[1].spellId = 12345
      local ok, errors = validate.validate(doc)
      assert.is_false(ok)
      return assert.is_not_nil(errorAt(errors, "spellEffects[1].spellId"))
    end)
  end)
  describe("optional spell collections", function()
    it("accepts a document that predates them", function()
      local doc = fixtures()
      doc.spellClass = nil
      doc.spellLevels = nil
      doc.spellReagents = nil
      local ok, errors = validate.validate(doc)
      assert.are.same({ }, paths(errors))
      return assert.is_true(ok)
    end)
    it("did not bump MAJOR, because nothing was invalidated", function()
      assert.are.equal(1, schema.SCHEMA_VERSION)
      return assert.is_true(schema.SCHEMA_MINOR >= 2)
    end)
    it("still type-checks them when present", function()
      local doc = fixtures()
      doc.spellClass[1].classFile = 42
      local ok, errors = validate.validate(doc)
      assert.is_false(ok)
      return assert.is_not_nil(errorAt(errors, "spellClass[1].classFile"))
    end)
    it("requires spellId on each spell-side row", function()
      local doc = fixtures()
      doc.spellLevels[1].spellId = nil
      local ok, errors = validate.validate(doc)
      assert.is_false(ok)
      return assert.is_not_nil(errorAt(errors, "spellLevels[1].spellId"))
    end)
    it("rejects a spell-side row pointing at an unknown spell", function()
      local doc = fixtures()
      doc.spellClass[1].spellId = 55555
      local ok, errors = validate.validate(doc)
      assert.is_false(ok)
      return assert.is_not_nil(errorAt(errors, "spellClass[1].spellId"))
    end)
    it("rejects a reagent pointing at an unknown item", function()
      local doc = fixtures()
      doc.spellReagents[1].itemId = 55555
      local ok, errors = validate.validate(doc)
      assert.is_false(ok)
      return assert.is_not_nil(errorAt(errors, "spellReagents[1].itemId"))
    end)
    return it("allows one spell to be available to several classes", function()
      local shared
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = fixtures().spellClass
        for _index_0 = 1, #_list_0 do
          local r = _list_0[_index_0]
          if r.spellId == 92005 then
            _accum_0[_len_0] = r
            _len_0 = _len_0 + 1
          end
        end
        shared = _accum_0
      end
      return assert.are.equal(2, #shared)
    end)
  end)
  describe("optional periodic-damage collection", function()
    it("accepts a document that predates it", function()
      local doc = fixtures()
      doc.spellPeriodic = nil
      local ok, errors = validate.validate(doc)
      assert.are.same({ }, paths(errors))
      return assert.is_true(ok)
    end)
    it("did not bump MAJOR, because nothing was invalidated", function()
      assert.are.equal(1, schema.SCHEMA_VERSION)
      return assert.is_true(schema.SCHEMA_MINOR >= 4)
    end)
    it("requires the two fields a prediction cannot be made without", function()
      local _list_0 = {
        "period",
        "baseAmount"
      }
      for _index_0 = 1, #_list_0 do
        local required = _list_0[_index_0]
        local doc = fixtures()
        doc.spellPeriodic[1][required] = nil
        local ok, errors = validate.validate(doc)
        assert.is_false(ok, ("%s must be required"):format(required))
        assert.is_not_nil(errorAt(errors, "spellPeriodic[1]." .. tostring(required)), ("expected an error at spellPeriodic[1].%s"):format(required))
      end
    end)
    it("type-checks the coefficients", function()
      local doc = fixtures()
      doc.spellPeriodic[1].coefficient = "lots"
      local ok, errors = validate.validate(doc)
      assert.is_false(ok)
      return assert.is_not_nil(errorAt(errors, "spellPeriodic[1].coefficient"))
    end)
    it("rejects a row pointing at an unknown spell", function()
      local doc = fixtures()
      doc.spellPeriodic[1].spellId = 55555
      local ok, errors = validate.validate(doc)
      assert.is_false(ok)
      return assert.is_not_nil(errorAt(errors, "spellPeriodic[1].spellId"))
    end)
    it("holds no row for the periodic HEAL, which is the control", function()
      local healRows
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = fixtures().spellPeriodic
        for _index_0 = 1, #_list_0 do
          local r = _list_0[_index_0]
          if r.spellId == 92010 then
            _accum_0[_len_0] = r
            _len_0 = _len_0 + 1
          end
        end
        healRows = _accum_0
      end
      assert.are.same({ }, healRows, "92010 is a periodic heal; a row here would mean heals count as damage")
      local heal
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = fixtures().spellEffects
        for _index_0 = 1, #_list_0 do
          local e = _list_0[_index_0]
          if e.spellId == 92010 then
            _accum_0[_len_0] = e
            _len_0 = _len_0 + 1
          end
        end
        heal = _accum_0
      end
      assert.are.equal(1, #heal)
      return assert.are.equal("PERIODIC_HEAL", heal[1].auraType)
    end)
    it("allows several periodic effects on one spell, for summing", function()
      local rows
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = fixtures().spellPeriodic
        for _index_0 = 1, #_list_0 do
          local r = _list_0[_index_0]
          if r.spellId == 92011 then
            _accum_0[_len_0] = r
            _len_0 = _len_0 + 1
          end
        end
        rows = _accum_0
      end
      assert.are.equal(2, #rows)
      local total = 0
      for _index_0 = 1, #rows do
        local r = rows[_index_0]
        total = total + r.baseAmount
      end
      return assert.are.equal(42, total)
    end)
    it("covers the scaling boundaries a predictor has to tell apart", function()
      local byId = { }
      local _list_0 = fixtures().spellPeriodic
      for _index_0 = 1, #_list_0 do
        local row = _list_0[_index_0]
        local _update_0 = row.spellId
        byId[_update_0] = byId[_update_0] or { }
        byId[row.spellId][#byId[row.spellId] + 1] = row
      end
      assert.is_not_nil(byId[92007][1].coefficient)
      assert.is_nil(byId[92007][1].apCoefficient)
      assert.is_not_nil(byId[92008][1].apCoefficient)
      assert.is_nil(byId[92008][1].coefficient)
      return assert.are.equal(4000, byId[92009][1].period)
    end)
    return it("carries no duration, because spells.duration already does", function()
      assert.is_nil(schema.records.spellPeriodic.fields.duration, "duration belongs to the aura, in spells.duration -- not repeated here")
      local durations = { }
      local _list_0 = fixtures().spells
      for _index_0 = 1, #_list_0 do
        local s = _list_0[_index_0]
        durations[s.id] = s.duration
      end
      local _list_1 = fixtures().spellPeriodic
      for _index_0 = 1, #_list_1 do
        local row = _list_1[_index_0]
        local d = durations[row.spellId]
        assert.is_not_nil(d, ("spell %d has no duration"):format(row.spellId))
        assert.are.equal(0, d % row.period, ("spell %d: duration %d is not a whole number of %dms ticks"):format(row.spellId, d, row.period))
      end
    end)
  end)
  return describe("JSON Schema emission", function()
    return it("describes every collection and marks required fields", function()
      local js = validate.toJsonSchema()
      assert.are.equal("object", js.type)
      for recordName in pairs(schema.records) do
        assert.is_not_nil(js.properties[recordName], recordName .. " missing from JSON Schema")
        assert.are.equal("array", js.properties[recordName].type)
      end
      local itemProps = js.properties.items.items.properties
      assert.are.equal("integer", itemProps.id.type)
      return assert.are.equal("string", itemProps.name.type)
    end)
  end)
end)
