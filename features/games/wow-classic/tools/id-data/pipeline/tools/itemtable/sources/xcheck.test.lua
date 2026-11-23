local xcheck = dofile("tools/itemtable/sources/xcheck.lua")
local model
model = function()
  return {
    schemaVersion = 1,
    build = "1.60.1.70790",
    source = "dbc",
    items = {
      {
        id = 101,
        name = "Flask of Agility",
        class = "Consumable",
        subclass = "Flask"
      },
      {
        id = 102,
        name = "Iron Bar",
        class = "Trade Goods",
        subclass = "Metal"
      }
    },
    spells = { },
    itemEffects = { },
    spellEffects = { }
  }
end
return describe("itemtable xcheck", function()
  describe("compare", function()
    it("agrees when the cross-check matches", function()
      local report = xcheck.compare(model(), {
        [101] = {
          name = "Flask of Agility",
          class = "Consumable",
          subclass = "Flask"
        }
      })
      assert.are.equal(1, report.checked)
      assert.are.equal(1, report.agreed)
      return assert.are.same({ }, report.discrepancies)
    end)
    it("reports a disagreeing field with both values", function()
      local report = xcheck.compare(model(), {
        [101] = {
          name = "Flask of Agility (Old)"
        }
      })
      assert.are.equal(1, #report.discrepancies)
      local d = report.discrepancies[1]
      assert.are.equal(101, d.itemId)
      assert.are.equal("name", d.field)
      assert.are.equal("Flask of Agility", d.ours)
      return assert.are.equal("Flask of Agility (Old)", d.theirs)
    end)
    it("counts an item as agreed only when no field disagrees", function()
      local report = xcheck.compare(model(), {
        [101] = {
          name = "Flask of Agility",
          class = "WRONG"
        }
      })
      assert.are.equal(1, report.checked)
      return assert.are.equal(0, report.agreed)
    end)
    it("ignores fields the cross-check has no opinion on", function()
      local report = xcheck.compare(model(), {
        [101] = {
          name = "Flask of Agility"
        }
      })
      assert.are.equal(1, report.agreed)
      return assert.are.same({ }, report.discrepancies)
    end)
    it("lists items the cross-check knows but we do not", function()
      local report = xcheck.compare(model(), {
        [999] = {
          name = "Mystery"
        }
      })
      assert.are.same({
        999
      }, report.missing)
      return assert.are.equal(0, report.checked)
    end)
    it("never mutates the model", function()
      local m = model()
      local before = m.items[1].name
      xcheck.compare(m, {
        [101] = {
          name = "Something Else"
        }
      })
      assert.are.equal(before, m.items[1].name)
      return assert.are.equal(2, #m.items)
    end)
    it("is deterministic in report ordering", function()
      local refs = {
        [102] = {
          name = "X"
        },
        [101] = {
          name = "Y"
        }
      }
      local first = xcheck.compare(model(), refs)
      local second = xcheck.compare(model(), refs)
      return assert.are.same((function()
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = first.discrepancies
        for _index_0 = 1, #_list_0 do
          local d = _list_0[_index_0]
          _accum_0[_len_0] = d.itemId
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)(), (function()
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = second.discrepancies
        for _index_0 = 1, #_list_0 do
          local d = _list_0[_index_0]
          _accum_0[_len_0] = d.itemId
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)())
    end)
    return it("tolerates junk input", function()
      assert.are.equal(0, xcheck.compare(nil, nil).checked)
      assert.are.equal(0, xcheck.compare(model(), "nope").checked)
      return assert.are.equal(0, xcheck.compare(model(), {
        [101] = "not a table"
      }).checked)
    end)
  end)
  describe("the questiedb adapter", function()
    return it("abstains with a reason instead of pretending to check", function()
      local data, reason = xcheck.adapters.questiedb({ })
      assert.is_nil(data)
      return assert.is_truthy(reason:find("codec", 1, true))
    end)
  end)
  describe("runAll", function()
    it("records an abstention without failing the run", function()
      local results = xcheck.runAll(model())
      local byName = { }
      for _index_0 = 1, #results do
        local r = results[_index_0]
        byName[r.name] = r
      end
      assert.is_truthy(byName.questiedb.abstained)
      return assert.is_nil(byName.questiedb.report)
    end)
    it("reports adapters in a stable order", function()
      xcheck.register("zz_fake", function()
        return {
          [101] = {
            name = "Flask of Agility"
          }
        }
      end)
      local names
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = xcheck.runAll(model())
        for _index_0 = 1, #_list_0 do
          local r = _list_0[_index_0]
          _accum_0[_len_0] = r.name
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
      assert.are.same(sorted, names)
      xcheck.adapters.zz_fake = nil
    end)
    return it("compares an adapter that does answer", function()
      xcheck.register("zz_fake", function()
        return {
          [101] = {
            name = "WRONG"
          }
        }
      end)
      local byName = { }
      local _list_0 = xcheck.runAll(model())
      for _index_0 = 1, #_list_0 do
        local r = _list_0[_index_0]
        byName[r.name] = r
      end
      assert.are.equal(1, #byName.zz_fake.report.discrepancies)
      xcheck.adapters.zz_fake = nil
    end)
  end)
  describe("format", function()
    return it("summarises counts and lists each discrepancy", function()
      local report = xcheck.compare(model(), {
        [101] = {
          name = "WRONG"
        }
      })
      local lines = xcheck.format("fake", report)
      assert.is_truthy(lines[1]:find("1 discrepancies", 1, true))
      return assert.is_truthy(lines[2]:find("item 101 name", 1, true))
    end)
  end)
  return describe("loadSnapshot", function()
    it("reads a cached snapshot table", function()
      local path = os.tmpname()
      local fh = io.open(path, "w")
      fh:write('return { [101] = { name = "Flask of Agility" } }\n')
      fh:close()
      local data, err = xcheck.loadSnapshot(path)
      os.remove(path)
      assert.is_nil(err)
      return assert.are.equal("Flask of Agility", data[101].name)
    end)
    return it("reports a missing snapshot rather than throwing", function()
      local data, err = xcheck.loadSnapshot("/nonexistent/snapshot.lua")
      assert.is_nil(data)
      return assert.is_truthy(err:find("cannot load", 1, true))
    end)
  end)
end)
