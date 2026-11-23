local coverage = dofile("tools/itemtable/coverage.lua")
local classify = dofile("tools/itemtable/classify.lua")
local rules = dofile("tools/itemtable/rules/consumable.lua")
local fixtures
fixtures = function()
  return dofile("tools/itemtable/fixtures.lua")
end
local report
report = function(doc)
  doc = doc or fixtures()
  return coverage.forDomain((classify.run(doc, rules)), doc, rules)
end
return describe("itemtable coverage", function()
  describe("forDomain", function()
    it("counts every in-scope item exactly once across the three buckets", function()
      local r = report()
      return assert.are.equal(r.inScope, r.classified + r.excluded + r.unclassifiedCount)
    end)
    it("counts only Consumable-class items as in scope", function()
      local doc = fixtures()
      local expected = 0
      local _list_0 = doc.items
      for _index_0 = 1, #_list_0 do
        local item = _list_0[_index_0]
        if item.class == "Consumable" then
          expected = expected + 1
        end
      end
      assert.are.equal(expected, report().inScope)
      return assert.is_true(expected < #doc.items, "fixtures must include an out-of-scope item")
    end)
    it("reports zero unclassified over the fixtures", function()
      local r = report()
      assert.are.equal(0, r.unclassifiedCount)
      return assert.are.same({ }, r.unclassified)
    end)
    it("does not double-count an item that is in two sets", function()
      local r = report()
      classify = dofile("tools/itemtable/classify.lua")
      rules = dofile("tools/itemtable/rules/consumable.lua")
      local result = classify.run(fixtures(), rules)
      local distinct, seen = 0, { }
      for _, members in pairs(result.sets) do
        for id in pairs(members) do
          if not (seen[id]) then
            seen[id] = true
            distinct = distinct + 1
          end
        end
      end
      assert.are.equal(distinct, r.classified)
      local multi = 0
      for id in pairs(seen) do
        local inSets = 0
        for _, members in pairs(result.sets) do
          if members[id] then
            inSets = inSets + 1
          end
        end
        if inSets > 1 then
          multi = multi + 1
        end
      end
      return assert.is_true(multi > 0, "fixtures must include an item in two sets")
    end)
    it("lists per-set member counts", function()
      return assert.are.equal(1, report().sets["Consumable.Buff.Agility.Flask"])
    end)
    it("lists unsupported sets with their reasons", function()
      local r = report()
      assert.is_true(#r.unsupported > 0)
      return assert.is_string(r.unsupportedReasons[r.unsupported[1]])
    end)
    return it("lists the exact unclassified ids, so the gate is actionable", function()
      local doc = fixtures()
      doc.items[#doc.items + 1] = {
        id = 90100,
        name = "FIXTURE Mystery",
        class = "Consumable",
        subclass = "Potion"
      }
      doc.spells[#doc.spells + 1] = {
        id = 91100,
        name = "FIXTURE Mystery",
        duration = 1
      }
      doc.itemEffects[#doc.itemEffects + 1] = {
        itemId = 90100,
        spellId = 91100,
        trigger = "use"
      }
      doc.spellEffects[#doc.spellEffects + 1] = {
        spellId = 91100,
        index = 1,
        auraType = "NEW_AURA"
      }
      return assert.are.same({
        90100
      }, report(doc).unclassified)
    end)
  end)
  describe("notStarted", function()
    return it("marks a domain exempt with a reason", function()
      local d = coverage.notStarted("Tradeskill rules not written yet")
      assert.are.equal("not-started", d.status)
      return assert.is_string(d.reason)
    end)
  end)
  describe("the release gate", function()
    it("passes when nothing is unclassified", function()
      local ok, problems = coverage.check({
        Consumable = report()
      })
      assert.are.same({ }, problems)
      return assert.is_true(ok)
    end)
    it("fails and names the offending ids when something is unclassified", function()
      local r = report()
      r.unclassified = {
        123,
        456
      }
      r.unclassifiedCount = 2
      local ok, problems = coverage.check({
        Consumable = r
      })
      assert.is_false(ok)
      assert.is_truthy(problems[1]:find("123", 1, true))
      return assert.is_truthy(problems[1]:find("456", 1, true))
    end)
    it("truncates a long id list but says how many were hidden", function()
      local r = report()
      do
        local _accum_0 = { }
        local _len_0 = 1
        for i = 1, 25 do
          _accum_0[_len_0] = i
          _len_0 = _len_0 + 1
        end
        r.unclassified = _accum_0
      end
      r.unclassifiedCount = 25
      local _, problems = coverage.check({
        Consumable = r
      })
      return assert.is_truthy(problems[1]:find("+15 more", 1, true))
    end)
    return it("exempts a not-started domain", function()
      local ok = coverage.check({
        Tradeskill = coverage.notStarted("later")
      })
      return assert.is_true(ok)
    end)
  end)
  describe("the ratchet", function()
    local baseline
    baseline = function(classified, unclassifiedCount)
      return {
        domains = {
          Consumable = {
            status = "active",
            classified = classified,
            unclassifiedCount = unclassifiedCount
          }
        }
      }
    end
    it("allows progress", function()
      local ok = coverage.check({
        Consumable = report()
      }, baseline(4, 0))
      return assert.is_true(ok)
    end)
    it("allows standing still", function()
      local ok = coverage.check({
        Consumable = report()
      }, baseline(8, 0))
      return assert.is_true(ok)
    end)
    it("fails when classified falls", function()
      local ok, problems = coverage.check({
        Consumable = report()
      }, baseline(99, 0))
      assert.is_false(ok)
      return assert.is_truthy(problems[1]:find("classified fell", 1, true))
    end)
    it("fails when unclassified rises", function()
      local r = report()
      r.unclassifiedCount = 3
      r.unclassified = {
        1,
        2,
        3
      }
      local ok, problems = coverage.check({
        Consumable = r
      }, baseline(8, 0))
      assert.is_false(ok)
      local joined = table.concat(problems, " | ")
      return assert.is_truthy(joined:find("unclassified rose", 1, true))
    end)
    it("ignores a baseline for a domain that is not active now", function()
      local ok = coverage.check({
        Consumable = coverage.notStarted("paused")
      }, baseline(99, 0))
      return assert.is_true(ok)
    end)
    return it("tolerates an absent baseline", function()
      assert.is_true((coverage.check({
        Consumable = report()
      })))
      return assert.is_true((coverage.check({
        Consumable = report()
      }, { })))
    end)
  end)
  return describe("toMetrics", function()
    it("trims the report to the ratchet fields and stays diff-reviewable", function()
      local m = coverage.toMetrics({
        Consumable = report()
      }, "1.60.1.70790")
      assert.are.equal("1.60.1.70790", m.build)
      local d = m.domains.Consumable
      assert.are.equal("active", d.status)
      assert.are.equal(report().classified, d.classified)
      assert.are.equal(0, d.unclassifiedCount)
      assert.is_number(d.sets)
      return assert.is_nil(d.unclassified)
    end)
    return it("records a not-started domain with its reason", function()
      local m = coverage.toMetrics({
        Tradeskill = coverage.notStarted("later")
      })
      assert.are.equal("not-started", m.domains.Tradeskill.status)
      return assert.are.equal("later", m.domains.Tradeskill.reason)
    end)
  end)
end)
