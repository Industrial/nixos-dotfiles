local schema = dofile("tools/itemtable/schema.lua")
local validate = dofile("tools/itemtable/validate.lua")
local fixtures
fixtures = function()
  return dofile("tools/itemtable/fixtures.lua")
end
return describe("itemtable talent model", function()
  describe("the schema", function()
    it("advanced MINOR, not MAJOR", function()
      assert.are.equal(1, schema.SCHEMA_VERSION)
      return assert.is_true(schema.SCHEMA_MINOR >= 3)
    end)
    it("declares every talent collection optional", function()
      local _list_0 = {
        "specs",
        "talentTrees",
        "talentNodes",
        "talentEntries"
      }
      for _index_0 = 1, #_list_0 do
        local name = _list_0[_index_0]
        assert.is_true(schema.records[name].optional, name)
      end
    end)
    it("validates a document with no talent data at all", function()
      local doc = fixtures()
      local _list_0 = {
        "specs",
        "talentTrees",
        "talentNodes",
        "talentEntries"
      }
      for _index_0 = 1, #_list_0 do
        local name = _list_0[_index_0]
        doc[name] = nil
      end
      local ok, errors = validate.validate(doc)
      return assert.is_true(ok, table.concat((function()
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #errors do
          local e = errors[_index_0]
          _accum_0[_len_0] = e.message
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)(), "; "))
    end)
    it("keys specs, trees, nodes and entries by their own id", function()
      assert.are.equal("specId", schema.records.specs.key)
      assert.are.equal("treeId", schema.records.talentTrees.key)
      assert.are.equal("nodeId", schema.records.talentNodes.key)
      return assert.are.equal("entryId", schema.records.talentEntries.key)
    end)
    return it("does NOT model the player's current spec", function()
      for _, record in pairs(schema.records) do
        for fieldName in pairs(record.fields) do
          assert.is_nil((fieldName:match("^active")), fieldName)
          assert.is_nil((fieldName:match("^current")), fieldName)
        end
      end
    end)
  end)
  describe("referential integrity", function()
    local broken
    broken = function(mutate)
      local doc = fixtures()
      mutate(doc)
      local ok, errors = validate.validate(doc)
      return ok, table.concat((function()
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #errors do
          local e = errors[_index_0]
          _accum_0[_len_0] = ("%s: %s"):format(e.path, e.message)
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)(), " | ")
    end
    it("catches a tree pointing at a spec that does not exist", function()
      local ok, why = broken(function(doc)
        doc.talentTrees[2].specId = 99999
      end)
      assert.is_false(ok)
      return assert.is_truthy(why:find("unknown spec", 1, true))
    end)
    it("catches a node pointing at a tree that does not exist", function()
      local ok, why = broken(function(doc)
        doc.talentNodes[1].treeId = 99999
      end)
      assert.is_false(ok)
      return assert.is_truthy(why:find("unknown talent tree", 1, true))
    end)
    it("catches an entry pointing at a node that does not exist", function()
      local ok, why = broken(function(doc)
        doc.talentEntries[1].nodeId = 99999
      end)
      assert.is_false(ok)
      return assert.is_truthy(why:find("unknown talent node", 1, true))
    end)
    it("catches an entry pointing at a spell that does not exist", function()
      local ok, why = broken(function(doc)
        doc.talentEntries[1].spellId = 99999
      end)
      assert.is_false(ok)
      return assert.is_truthy(why:find("unknown spell", 1, true))
    end)
    it("catches a spellClass row naming a spec that does not exist", function()
      local ok, why = broken(function(doc)
        doc.spellClass[#doc.spellClass].specId = 99999
      end)
      assert.is_false(ok)
      return assert.is_truthy(why:find("unknown spec", 1, true))
    end)
    return it("accepts an entry that grants no spell", function()
      local doc = fixtures()
      doc.talentEntries[1].spellId = nil
      return assert.is_true((validate.validate(doc)))
    end)
  end)
  describe("the fixtures", function()
    it("cover one class with two specs", function()
      local doc = fixtures()
      local byClass = { }
      local _list_0 = doc.specs
      for _index_0 = 1, #_list_0 do
        local spec = _list_0[_index_0]
        local _update_0 = spec.classFile
        byClass[_update_0] = byClass[_update_0] or 0
        local _update_1 = spec.classFile
        byClass[_update_1] = byClass[_update_1] + 1
      end
      return assert.are.equal(2, byClass.PRIEST)
    end)
    it("cover a class tree, spec trees and a hero tree", function()
      local kinds = { }
      local _list_0 = fixtures().talentTrees
      for _index_0 = 1, #_list_0 do
        local t = _list_0[_index_0]
        kinds[t.kind] = (kinds[t.kind] or 0) + 1
      end
      assert.are.equal(1, kinds.class)
      assert.are.equal(2, kinds.spec)
      return assert.are.equal(1, kinds.hero)
    end)
    it("give the class tree no spec, and every spec tree one", function()
      local _list_0 = fixtures().talentTrees
      for _index_0 = 1, #_list_0 do
        local tree = _list_0[_index_0]
        if tree.kind == "class" then
          assert.is_nil(tree.specId)
          assert.is_string(tree.classFile)
        else
          assert.is_number(tree.specId, tree.kind)
        end
      end
    end)
    it("cover a choice node and a multi-rank node", function()
      local doc = fixtures()
      local byType = { }
      local _list_0 = doc.talentNodes
      for _index_0 = 1, #_list_0 do
        local n = _list_0[_index_0]
        byType[n.type] = (byType[n.type] or 0) + 1
      end
      assert.is_true((byType.choice or 0) > 0)
      assert.is_true((byType.tiered or 0) > 0)
      local ranked
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_1 = doc.talentNodes
        for _index_0 = 1, #_list_1 do
          local n = _list_1[_index_0]
          if (n.maxRanks or 1) > 1 then
            _accum_0[_len_0] = n
            _len_0 = _len_0 + 1
          end
        end
        ranked = _accum_0
      end
      return assert.is_true(#ranked > 0)
    end)
    it("give the choice node more than one entry on ONE node", function()
      local doc = fixtures()
      local choice = nil
      local _list_0 = doc.talentNodes
      for _index_0 = 1, #_list_0 do
        local n = _list_0[_index_0]
        if n.type == "choice" then
          choice = n
        end
      end
      assert.is_not_nil(choice)
      local entries
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_1 = doc.talentEntries
        for _index_0 = 1, #_list_1 do
          local e = _list_1[_index_0]
          if e.nodeId == choice.nodeId then
            _accum_0[_len_0] = e
            _len_0 = _len_0 + 1
          end
        end
        entries = _accum_0
      end
      return assert.is_true(#entries >= 2)
    end)
    it("include an entry that grants no castable spell", function()
      local doc = fixtures()
      local passive
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = doc.talentEntries
        for _index_0 = 1, #_list_0 do
          local e = _list_0[_index_0]
          if e.spellId == nil then
            _accum_0[_len_0] = e
            _len_0 = _len_0 + 1
          end
        end
        passive = _accum_0
      end
      return assert.is_true(#passive > 0)
    end)
    it("reach spells that actually exist in the spell fixtures", function()
      local doc = fixtures()
      local spellIds = { }
      local _list_0 = doc.spells
      for _index_0 = 1, #_list_0 do
        local sp = _list_0[_index_0]
        spellIds[sp.id] = true
      end
      local reached = 0
      local _list_1 = doc.talentEntries
      for _index_0 = 1, #_list_1 do
        local _continue_0 = false
        repeat
          local entry = _list_1[_index_0]
          if not (entry.spellId) then
            _continue_0 = true
            break
          end
          assert.is_true(spellIds[entry.spellId], tostring(entry.spellId))
          reached = reached + 1
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      return assert.is_true(reached > 0)
    end)
    it("make the two specs differ in what they reach", function()
      local doc = fixtures()
      local bySpec = { }
      local _list_0 = doc.spellClass
      for _index_0 = 1, #_list_0 do
        local _continue_0 = false
        repeat
          local row = _list_0[_index_0]
          if not (row.specId) then
            _continue_0 = true
            break
          end
          local _update_0 = row.specId
          bySpec[_update_0] = bySpec[_update_0] or { }
          bySpec[row.specId][row.spellId] = true
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      assert.is_not_nil(bySpec[93001])
      assert.is_not_nil(bySpec[93002])
      local onlyOne = 0
      for specId, spells in pairs(bySpec) do
        for spellId in pairs(spells) do
          local other = specId == 93001 and 93002 or 93001
          if not ((bySpec[other] or { })[spellId]) then
            onlyOne = onlyOne + 1
          end
        end
      end
      return assert.is_true(onlyOne > 0)
    end)
    return it("use the reserved 93000+ band for talent rows", function()
      local doc = fixtures()
      local _list_0 = doc.specs
      for _index_0 = 1, #_list_0 do
        local spec = _list_0[_index_0]
        assert.is_true(spec.specId >= 93000, tostring(spec.specId))
      end
      local _list_1 = doc.talentTrees
      for _index_0 = 1, #_list_1 do
        local tree = _list_1[_index_0]
        assert.is_true(tree.treeId >= 93000, tostring(tree.treeId))
      end
      local _list_2 = doc.talentNodes
      for _index_0 = 1, #_list_2 do
        local node = _list_2[_index_0]
        assert.is_true(node.nodeId >= 93000, tostring(node.nodeId))
      end
      local _list_3 = doc.talentEntries
      for _index_0 = 1, #_list_3 do
        local entry = _list_3[_index_0]
        assert.is_true(entry.entryId >= 93000, tostring(entry.entryId))
      end
    end)
  end)
  return describe("the JSON Schema form", function()
    return it("carries the talent collections through", function()
      local js = validate.toJsonSchema()
      local _list_0 = {
        "specs",
        "talentTrees",
        "talentNodes",
        "talentEntries"
      }
      for _index_0 = 1, #_list_0 do
        local name = _list_0[_index_0]
        assert.is_not_nil(js.properties[name], name)
      end
    end)
  end)
end)
