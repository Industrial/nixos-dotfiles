local classify = dofile("tools/itemtable/classify.lua")
local coverage = dofile("tools/itemtable/coverage.lua")
local tradeskill = dofile("tools/itemtable/rules/tradeskill.lua")
local consumable = dofile("tools/itemtable/rules/consumable.lua")
local fixtures
fixtures = function()
  return dofile("tools/itemtable/fixtures.lua")
end
local run
run = function(doc)
  doc = doc or fixtures()
  local rules = tradeskill.forDocument(doc)
  return (classify.run(doc, rules)), rules, doc
end
return describe("itemtable tradeskill domain", function()
  describe("generalization", function()
    it("runs through the unmodified classifier", function()
      local result = run()
      assert.is_table(result.sets)
      return assert.is_table(result.unclassified)
    end)
    it("derives its set list from the data, not from a fixed list", function()
      local result = run()
      assert.is_not_nil(result.sets["Tradeskill.Mat.BySubclass.Metal"])
      return assert.is_not_nil(result.sets["Tradeskill.Mat.BySubclass.Cloth"])
    end)
    it("gains a set when the data gains a subclass", function()
      local doc = fixtures()
      doc.items[#doc.items + 1] = {
        id = 90012,
        name = "FIXTURE Herb",
        class = "Trade Goods",
        subclass = "Herb"
      }
      return assert.is_not_nil((run(doc)).sets["Tradeskill.Mat.BySubclass.Herb"])
    end)
    return it("shares the coverage model with the Consumable domain", function()
      local result, rules, doc = run()
      local report = coverage.forDomain(result, doc, rules)
      return assert.are.equal(report.inScope, report.classified + report.excluded + report.unclassifiedCount)
    end)
  end)
  describe("scope", function()
    it("claims trade goods and nothing else", function()
      assert.is_true(tradeskill.scope({
        class = "Trade Goods"
      }))
      return assert.is_false(tradeskill.scope({
        class = "Consumable"
      }))
    end)
    return it("does not overlap the Consumable domain", function()
      local _list_0 = fixtures().items
      for _index_0 = 1, #_list_0 do
        local item = _list_0[_index_0]
        assert.is_false((tradeskill.scope(item) and consumable.scope(item)), ("item %d is claimed by both domains"):format(item.id))
      end
    end)
  end)
  describe("classification", function()
    it("groups an item under its own subclass", function()
      return assert.are.equal(1, (run()).sets["Tradeskill.Mat.BySubclass.Metal"][90009])
    end)
    it("does not place an item in another subclass's set", function()
      return assert.is_nil((run()).sets["Tradeskill.Mat.BySubclass.Cloth"][90009])
    end)
    it("excludes a trade good with no subclass, with a reason", function()
      local result = run()
      assert.is_string(result.excluded[90011])
      return assert.is_truthy(result.excluded[90011]:find("subclass", 1, true))
    end)
    return it("leaves nothing unclassified over the fixtures", function()
      return assert.are.same({ }, (run()).unclassified)
    end)
  end)
  describe("declared gaps", function()
    return it("declares ByProfession unsupported with its reason", function()
      local reason = (run()).unsupported["Tradeskill.Mat.ByProfession"]
      assert.is_string(reason)
      return assert.is_truthy(reason:find("SkillLine", 1, true))
    end)
  end)
  return describe("the ratchet", function()
    return it("enters coverage as an active domain", function()
      local result, rules, doc = run()
      local metrics = coverage.toMetrics({
        Tradeskill = coverage.forDomain(result, doc, rules)
      })
      assert.are.equal("active", metrics.domains.Tradeskill.status)
      return assert.are.equal(2, metrics.domains.Tradeskill.classified)
    end)
  end)
end)
