local dbc = dofile("tools/itemtable/sources/dbc.lua")
local base
base = function()
  return {
    item = {
      {
        ID = "1",
        ClassID = "0"
      }
    },
    itemSparse = {
      {
        ID = "1",
        Display_lang = "Thing"
      }
    },
    itemEffect = { },
    spell = {
      {
        ID = "500",
        Name_lang = "Granted Spell"
      },
      {
        ID = "501",
        Name_lang = "Other"
      }
    },
    spellEffect = { }
  }
end
local traits
traits = function(over)
  if over == nil then
    over = { }
  end
  local t = base()
  t.chrSpecialization = {
    {
      ID = "70",
      ClassID = "2",
      Name_lang = "Retribution",
      Role = "2",
      PrimaryStatPriority = "0"
    },
    {
      ID = "65",
      ClassID = "2",
      Name_lang = "Holy",
      Role = "1",
      PrimaryStatPriority = "2"
    }
  }
  t.traitTree = {
    {
      ID = "800"
    },
    {
      ID = "801"
    },
    {
      ID = "802"
    }
  }
  t.traitTreeLoadout = {
    {
      TraitTreeID = "800",
      ChrSpecializationID = "70"
    },
    {
      TraitTreeID = "801",
      ChrSpecializationID = "65"
    }
  }
  t.traitSubTree = {
    {
      ID = "900",
      TraitTreeID = "800"
    }
  }
  t.traitNode = {
    {
      ID = "1000",
      TraitTreeID = "800",
      Type = "0",
      MaxRanks = "1"
    },
    {
      ID = "1001",
      TraitTreeID = "800",
      Type = "2",
      MaxRanks = "3"
    }
  }
  t.traitNodeEntry = {
    {
      ID = "2000",
      TraitDefinitionID = "3000"
    },
    {
      ID = "2001",
      TraitDefinitionID = "3001"
    },
    {
      ID = "2002",
      TraitDefinitionID = "3002"
    }
  }
  t.traitNodeXEntry = {
    {
      TraitNodeID = "1000",
      TraitNodeEntryID = "2000"
    },
    {
      TraitNodeID = "1000",
      TraitNodeEntryID = "2001"
    },
    {
      TraitNodeID = "1001",
      TraitNodeEntryID = "2002"
    }
  }
  t.traitDefinition = {
    {
      ID = "3000",
      SpellID = "500"
    },
    {
      ID = "3001",
      SpellID = "501"
    },
    {
      ID = "3002",
      SpellID = "0"
    }
  }
  for k, v in pairs(over) do
    t[k] = v
  end
  return t
end
local convert
convert = function(over)
  return dbc.toModel(traits(over), {
    build = "1.60.1.70790"
  })
end
return describe("dbc trait conversion", function()
  describe("the trait tables are optional", function()
    it("converts an extraction with no trait tables at all", function()
      local doc = dbc.toModel(base(), {
        build = "1.60.1.70790"
      })
      assert.is_nil(doc.specs)
      assert.is_nil(doc.talentTrees)
      return assert.is_nil(doc.talentEntries)
    end)
    return it("declares every trait table optional, so extraction can lag", function()
      local byFile = { }
      local _list_0 = dbc.REQUIRED
      for _index_0 = 1, #_list_0 do
        local spec = _list_0[_index_0]
        byFile[spec.file] = spec
      end
      local _list_1 = {
        "ChrSpecialization.csv",
        "TraitTree.csv",
        "TraitNode.csv",
        "TraitNodeEntry.csv",
        "TraitDefinition.csv",
        "TraitSubTree.csv",
        "TraitNodeXTraitNodeEntry.csv",
        "TraitTreeLoadout.csv"
      }
      for _index_0 = 1, #_list_1 do
        local file = _list_1[_index_0]
        assert.is_not_nil(byFile[file], file)
        assert.is_true(byFile[file].optional, file)
      end
    end)
  end)
  describe("specs", function()
    it("names the class from its own id rather than guessing", function()
      local doc = convert()
      local byId = { }
      local _list_0 = doc.specs
      for _index_0 = 1, #_list_0 do
        local s = _list_0[_index_0]
        byId[s.specId] = s
      end
      assert.are.equal("PALADIN", byId[70].classFile)
      return assert.are.equal("Retribution", byId[70].name)
    end)
    it("decodes role and primary stat", function()
      local doc = convert()
      local byId = { }
      local _list_0 = doc.specs
      for _index_0 = 1, #_list_0 do
        local s = _list_0[_index_0]
        byId[s.specId] = s
      end
      assert.are.equal("DAMAGER", byId[70].role)
      assert.are.equal("STRENGTH", byId[70].primaryStat)
      assert.are.equal("HEALER", byId[65].role)
      return assert.are.equal("INTELLECT", byId[65].primaryStat)
    end)
    it("keeps an unknown class id VISIBLE instead of inventing a name", function()
      local doc = convert({
        chrSpecialization = {
          {
            ID = "70",
            ClassID = "99"
          }
        }
      })
      return assert.are.equal("Class99", doc.specs[1].classFile)
    end)
    return it("sorts specs by id, so the document is reproducible", function()
      local doc = convert()
      return assert.is_true(doc.specs[1].specId < doc.specs[2].specId)
    end)
  end)
  describe("trees", function()
    it("calls a tree a SPEC tree when a loadout loads it for a spec", function()
      local doc = convert()
      local byId = { }
      local _list_0 = doc.talentTrees
      for _index_0 = 1, #_list_0 do
        local t = _list_0[_index_0]
        byId[t.treeId] = t
      end
      assert.are.equal("spec", byId[800].kind)
      return assert.are.equal(70, byId[800].specId)
    end)
    it("calls a tree with no loadout a CLASS tree", function()
      local doc = convert()
      local byId = { }
      local _list_0 = doc.talentTrees
      for _index_0 = 1, #_list_0 do
        local t = _list_0[_index_0]
        byId[t.treeId] = t
      end
      assert.are.equal("class", byId[802].kind)
      return assert.is_nil(byId[802].specId)
    end)
    it("leaves a class tree's class ABSENT rather than guessed", function()
      local doc = convert()
      local byId = { }
      local _list_0 = doc.talentTrees
      for _index_0 = 1, #_list_0 do
        local t = _list_0[_index_0]
        byId[t.treeId] = t
      end
      return assert.is_nil(byId[802].classFile)
    end)
    return it("makes a subtree a HERO tree inheriting its parent's spec", function()
      local doc = convert()
      local byId = { }
      local _list_0 = doc.talentTrees
      for _index_0 = 1, #_list_0 do
        local t = _list_0[_index_0]
        byId[t.treeId] = t
      end
      assert.are.equal("hero", byId[900].kind)
      return assert.are.equal(70, byId[900].specId)
    end)
  end)
  describe("nodes", function()
    it("carries ranks through", function()
      local doc = convert()
      local byId = { }
      local _list_0 = doc.talentNodes
      for _index_0 = 1, #_list_0 do
        local n = _list_0[_index_0]
        byId[n.nodeId] = n
      end
      assert.are.equal(1, byId[1000].maxRanks)
      return assert.are.equal(3, byId[1001].maxRanks)
    end)
    it("defaults a missing rank count to one rather than nil", function()
      local doc = convert({
        traitNode = {
          {
            ID = "1000",
            TraitTreeID = "800"
          }
        }
      })
      return assert.are.equal(1, doc.talentNodes[1].maxRanks)
    end)
    return it("skips a node with no tree, which cannot be reached", function()
      local doc = convert({
        traitNode = {
          {
            ID = "1000"
          },
          {
            ID = "1001",
            TraitTreeID = "800"
          }
        }
      })
      assert.are.equal(1, #doc.talentNodes)
      return assert.are.equal(1001, doc.talentNodes[1].nodeId)
    end)
  end)
  describe("entries, and the many-to-many join", function()
    it("puts TWO entries on ONE node, which is what a choice node is", function()
      local doc = convert()
      local onNode
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = doc.talentEntries
        for _index_0 = 1, #_list_0 do
          local e = _list_0[_index_0]
          if e.nodeId == 1000 then
            _accum_0[_len_0] = e
            _len_0 = _len_0 + 1
          end
        end
        onNode = _accum_0
      end
      return assert.are.equal(2, #onNode)
    end)
    it("resolves an entry to the spell its definition grants", function()
      local doc = convert()
      local byId = { }
      local _list_0 = doc.talentEntries
      for _index_0 = 1, #_list_0 do
        local e = _list_0[_index_0]
        byId[e.entryId] = e
      end
      assert.are.equal(500, byId[2000].spellId)
      return assert.are.equal(501, byId[2001].spellId)
    end)
    it("leaves spellId nil when the definition grants nothing castable", function()
      local doc = convert()
      local byId = { }
      local _list_0 = doc.talentEntries
      for _index_0 = 1, #_list_0 do
        local e = _list_0[_index_0]
        byId[e.entryId] = e
      end
      assert.is_nil(byId[2002].spellId)
      return assert.are.equal(3002, byId[2002].definitionId)
    end)
    it("skips an entry attached to no node", function()
      local doc = convert({
        traitNodeXEntry = {
          {
            TraitNodeID = "1000",
            TraitNodeEntryID = "2000"
          }
        }
      })
      assert.are.equal(1, #doc.talentEntries)
      return assert.are.equal(2000, doc.talentEntries[1].entryId)
    end)
    it("survives a missing definition table, with no spells resolved", function()
      local t = traits()
      t.traitDefinition = nil
      local doc = dbc.toModel(t, {
        build = "1.60.1.70790"
      })
      assert.is_true(#doc.talentEntries > 0)
      local _list_0 = doc.talentEntries
      for _index_0 = 1, #_list_0 do
        local e = _list_0[_index_0]
        assert.is_nil(e.spellId)
      end
    end)
    return it("sorts entries by id, so the document is reproducible", function()
      local doc = convert()
      for i = 2, #doc.talentEntries do
        assert.is_true(doc.talentEntries[i - 1].entryId < doc.talentEntries[i].entryId)
      end
    end)
  end)
  return describe("the converted document is usable", function()
    it("validates", function()
      local validate = dofile("tools/itemtable/validate.lua")
      local ok, errors = validate.validate(convert())
      return assert.is_true(ok, table.concat((function()
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = (errors or { })
        for _index_0 = 1, #_list_0 do
          local e = _list_0[_index_0]
          _accum_0[_len_0] = e.message
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)(), "; "))
    end)
    return it("classifies through the Talent domain without special-casing", function()
      local classify = dofile("tools/itemtable/classify.lua")
      local talent = dofile("tools/itemtable/rules/talent.lua")
      local doc = convert()
      local result = classify.run(doc, talent.forDocument(doc))
      assert.are.equal(500, result.sets["Talent.Grants.Spell"][2000])
      assert.are.equal(2, result.sets["Talent.Node.Choice"][2000])
      return assert.are.same({ }, result.unclassified)
    end)
  end)
end)
