local classify = dofile("tools/itemtable/classify.lua")
local coverage = dofile("tools/itemtable/coverage.lua")
local talent = dofile("tools/itemtable/rules/talent.lua")
local fixtures
fixtures = function()
  return dofile("tools/itemtable/fixtures.lua")
end
local run
run = function(doc)
  doc = doc or fixtures()
  local rules = talent.forDocument(doc)
  return (classify.run(doc, rules)), rules, doc
end
local DEVOTION, WRATH = 93001, 93002
local CLASS_TREE, DEVOTION_TREE, WRATH_TREE, HERO_TREE = 93100, 93101, 93102, 93103
return describe("itemtable talent domain", function()
  describe("scope", function()
    it("claims only entries that grant a castable spell", function()
      local result, rules, doc = run()
      local _list_0 = doc.talentEntries
      for _index_0 = 1, #_list_0 do
        local entry = _list_0[_index_0]
        local expected = entry.spellId ~= nil
        assert.are.equal(expected, rules.scope(entry), tostring(entry.entryId))
      end
    end)
    it("leaves a passive entry out of scope rather than excluding it", function()
      local result, _, doc = run()
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
      assert.is_true(#passive > 0)
      for _index_0 = 1, #passive do
        local e = passive[_index_0]
        assert.is_nil(result.excluded[e.entryId])
      end
      local _list_0 = result.unclassified
      for _index_0 = 1, #_list_0 do
        local id = _list_0[_index_0]
        for _index_1 = 1, #passive do
          local e = passive[_index_1]
          assert.are_not.equal(e.entryId, id)
        end
      end
    end)
    return it("ignores an entry whose spell is not in the document", function()
      local doc = fixtures()
      doc.talentEntries[1].spellId = 999999
      local _, rules = run(doc)
      return assert.is_false(rules.scope(doc.talentEntries[1]))
    end)
  end)
  describe("the identity of a talent", function()
    it("is keyed by entryId, not by id", function()
      local result = run()
      return assert.is_not_nil(result.sets["Talent.Grants.Spell"][93300])
    end)
    return it("makes the engine sort by that field", function()
      local doc = fixtures()
      local rules = talent.forDocument(doc)
      local identify = classify.identifierOf(rules)
      return assert.are.equal(93300, identify(doc.talentEntries[1]))
    end)
  end)
  describe("tree classification", function()
    it("separates class, spec and hero trees", function()
      local r = run()
      assert.is_not_nil(r.sets["Talent.Tree.Class"])
      assert.is_not_nil(r.sets["Talent.Tree.Spec"])
      return assert.is_not_nil(r.sets["Talent.Tree.Hero"])
    end)
    it("puts a class-tree entry in Tree.Class and nowhere else", function()
      local r = run()
      assert.is_not_nil(r.sets["Talent.Tree.Class"][93300])
      assert.is_nil(r.sets["Talent.Tree.Spec"][93300])
      return assert.is_nil((r.sets["Talent.Tree.Hero"] or { })[93300])
    end)
    return it("values a tree entry by how many points its node takes", function()
      local r = run()
      return assert.are.equal(3, r.sets["Talent.Tree.Spec"][93304])
    end)
  end)
  describe("node shapes", function()
    it("finds the choice node's entries by their SIBLINGS, not by a type string", function()
      local r = run()
      assert.are.equal(2, r.sets["Talent.Node.Choice"][93301])
      return assert.are.equal(2, r.sets["Talent.Node.Choice"][93302])
    end)
    it("does not call a lone entry a choice", function()
      local r = run()
      return assert.is_nil(r.sets["Talent.Node.Choice"][93300])
    end)
    return it("finds a multi-rank node and values it by its ranks", function()
      return assert.are.equal(3, (run()).sets["Talent.Node.MultiRank"][93304])
    end)
  end)
  describe("the spell join", function()
    it("values Grants.Spell with the spell id itself", function()
      local r = run()
      assert.are.equal(92001, r.sets["Talent.Grants.Spell"][93300])
      return assert.are.equal(92002, r.sets["Talent.Grants.Spell"][93301])
    end)
    return it("covers every in-scope entry", function()
      local r, rules, doc = run()
      local _list_0 = doc.talentEntries
      for _index_0 = 1, #_list_0 do
        local _continue_0 = false
        repeat
          local entry = _list_0[_index_0]
          if not (rules.scope(entry)) then
            _continue_0 = true
            break
          end
          assert.is_not_nil(r.sets["Talent.Grants.Spell"][entry.entryId], tostring(entry.entryId))
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
    end)
  end)
  describe("per-spec reachability", function()
    it("builds one set per spec, named from the data", function()
      local names = { }
      for name in pairs((run()).sets) do
        names[name] = true
      end
      assert.is_true(names["Talent.Spec.PRIEST.FIXTUREDevotion"])
      return assert.is_true(names["Talent.Spec.PRIEST.FIXTUREWrath"])
    end)
    it("gives a class-tree entry to EVERY spec of that class", function()
      local r = run()
      assert.are.equal(92001, r.sets["Talent.Spec.PRIEST.FIXTUREDevotion"][93300])
      return assert.are.equal(92001, r.sets["Talent.Spec.PRIEST.FIXTUREWrath"][93300])
    end)
    it("gives a spec-tree entry to that spec ALONE", function()
      local r = run()
      assert.are.equal(92006, r.sets["Talent.Spec.PRIEST.FIXTUREDevotion"][93303])
      assert.is_nil(r.sets["Talent.Spec.PRIEST.FIXTUREWrath"][93303])
      assert.are.equal(92004, r.sets["Talent.Spec.PRIEST.FIXTUREWrath"][93304])
      return assert.is_nil(r.sets["Talent.Spec.PRIEST.FIXTUREDevotion"][93304])
    end)
    it("gives a hero-tree entry only to the spec that owns it", function()
      local r = run()
      assert.are.equal(92003, r.sets["Talent.Spec.PRIEST.FIXTUREDevotion"][93305])
      return assert.is_nil(r.sets["Talent.Spec.PRIEST.FIXTUREWrath"][93305])
    end)
    return it("makes the two specs genuinely differ", function()
      local r = run()
      local a = r.sets["Talent.Spec.PRIEST.FIXTUREDevotion"]
      local b = r.sets["Talent.Spec.PRIEST.FIXTUREWrath"]
      local differing = 0
      for id in pairs(a) do
        if not (b[id]) then
          differing = differing + 1
        end
      end
      for id in pairs(b) do
        if not (a[id]) then
          differing = differing + 1
        end
      end
      return assert.is_true(differing > 0)
    end)
  end)
  describe("declared gaps", function()
    it("declares node position unsupported", function()
      local r = run()
      return assert.is_truthy(r.unsupported["Talent.Node.Position"]:find("row/column", 1, true))
    end)
    return it("declares loadout strings unsupported", function()
      local r = run()
      return assert.is_truthy(r.unsupported["Talent.Loadout.Default"]:find("client encoding", 1, true))
    end)
  end)
  describe("the gate", function()
    it("gates at zero, unlike the Spell domain", function()
      return assert.are.equal("zero", talent.gate)
    end)
    it("passes over the fixtures", function()
      local r, rules, doc = run()
      return assert.is_true(coverage.check({
        Talent = coverage.forDomain(r, doc, rules)
      }))
    end)
    it("EXCLUDES a spell-granting entry whose node is missing, with a reason", function()
      local doc = fixtures()
      doc.talentEntries[#doc.talentEntries + 1] = {
        entryId = 93399,
        nodeId = 93999,
        spellId = 92001
      }
      local r = run(doc)
      assert.is_truthy(r.excluded[93399])
      assert.is_truthy(r.excluded[93399]:find("tree or spec is missing", 1, true))
      return assert.is_nil((r.sets["Talent.Grants.Spell"] or { })[93399])
    end)
    it("excludes an entry whose tree is missing, with a reason", function()
      local doc = fixtures()
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = doc.talentTrees
        for _index_0 = 1, #_list_0 do
          local t = _list_0[_index_0]
          if t.treeId ~= CLASS_TREE then
            _accum_0[_len_0] = t
            _len_0 = _len_0 + 1
          end
        end
        doc.talentTrees = _accum_0
      end
      local r = run(doc)
      assert.is_truthy(r.excluded[93300])
      return assert.is_truthy(r.excluded[93300]:find("tree or spec is missing", 1, true))
    end)
    it("keeps the exclusion path REACHABLE", function()
      local _, rules = run()
      local ctx = classify.context(fixtures())
      local orphan = {
        entryId = 1,
        nodeId = 2,
        spellId = 3,
        __grantsSpell = true
      }
      for setName, rule in pairs(rules.sets) do
        local _continue_0 = false
        repeat
          if rule.unsupported then
            _continue_0 = true
            break
          end
          assert.is_nil(rule.predicate(ctx, orphan), ("set %q matches an entry with no tree, which disables every exclusion"):format(setName))
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
    end)
    it("reports `unclassified` as structurally empty, and says why", function()
      local r, rules, doc = run()
      local report = coverage.forDomain(r, doc, rules)
      assert.are.equal(0, report.unclassifiedCount)
      return assert.are.equal("zero", report.gate)
    end)
    return it("counts every in-scope entry exactly once across the buckets", function()
      local r, rules, doc = run()
      local report = coverage.forDomain(r, doc, rules)
      return assert.are.equal(report.inScope, report.classified + report.excluded + report.unclassifiedCount)
    end)
  end)
  return describe("a document with no talent data", function()
    return it("classifies nothing and does not error", function()
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
      local r, rules, d = run(doc)
      assert.are.same({ }, r.unclassified)
      return assert.is_true(coverage.check({
        Talent = coverage.forDomain(r, d, rules)
      }))
    end)
  end)
end)
