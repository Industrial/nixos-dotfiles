local diff = dofile("tools/itemtable/golden_diff.lua")
local committed
committed = function()
  return {
    ["Consumable.Buff.Agility.Flask"] = "101:25,102:30",
    ["Consumable.Water.Basic"] = "201"
  }
end
return describe("itemtable golden diff", function()
  describe("decodeSet", function()
    it("round-trips the emitted encoding", function()
      return assert.are.same({
        [101] = 25,
        [102] = 30
      }, diff.decodeSet("101:25,102:30"))
    end)
    it("treats a bare id as value 1, matching the emitter", function()
      return assert.are.same({
        [201] = 1
      }, diff.decodeSet("201"))
    end)
    return it("is empty for empty or junk input", function()
      assert.are.same({ }, diff.decodeSet(""))
      return assert.are.same({ }, diff.decodeSet(nil))
    end)
  end)
  describe("diff", function()
    it("reports no changes when the data is unchanged", function()
      local fresh = {
        ["Consumable.Buff.Agility.Flask"] = {
          [101] = 25,
          [102] = 30
        },
        ["Consumable.Water.Basic"] = {
          [201] = 1
        }
      }
      local report = diff.diff(committed(), fresh)
      assert.is_true(diff.isEmpty(report))
      return assert.are.same({
        "no changes"
      }, diff.format(report))
    end)
    it("reports an item the new build added", function()
      local fresh = {
        ["Consumable.Buff.Agility.Flask"] = {
          [101] = 25,
          [102] = 30,
          [103] = 40
        },
        ["Consumable.Water.Basic"] = {
          [201] = 1
        }
      }
      local report = diff.diff(committed(), fresh)
      return assert.are.same({
        103
      }, report.changes[1].added)
    end)
    it("reports an item that disappeared", function()
      local fresh = {
        ["Consumable.Buff.Agility.Flask"] = {
          [101] = 25
        },
        ["Consumable.Water.Basic"] = {
          [201] = 1
        }
      }
      return assert.are.same({
        102
      }, (diff.diff(committed(), fresh)).changes[1].removed)
    end)
    it("reports a value change with both sides", function()
      local fresh = {
        ["Consumable.Buff.Agility.Flask"] = {
          [101] = 25,
          [102] = 99
        },
        ["Consumable.Water.Basic"] = {
          [201] = 1
        }
      }
      local change = (diff.diff(committed(), fresh)).changes[1].changed[1]
      assert.are.equal(102, change.id)
      assert.are.equal(30, change.from)
      return assert.are.equal(99, change.to)
    end)
    it("reports a whole set appearing", function()
      local fresh = {
        ["Consumable.Buff.Agility.Flask"] = {
          [101] = 25,
          [102] = 30
        },
        ["Consumable.Water.Basic"] = {
          [201] = 1
        },
        ["Consumable.Buff.Strength.Flask"] = {
          [301] = 5
        }
      }
      return assert.are.same({
        "Consumable.Buff.Strength.Flask"
      }, (diff.diff(committed(), fresh)).addedSets)
    end)
    it("reports a whole set vanishing", function()
      local fresh = {
        ["Consumable.Buff.Agility.Flask"] = {
          [101] = 25,
          [102] = 30
        }
      }
      return assert.are.same({
        "Consumable.Water.Basic"
      }, (diff.diff(committed(), fresh)).removedSets)
    end)
    it("treats a first run with no committed data as all additions", function()
      local fresh = {
        ["Consumable.Water.Basic"] = {
          [201] = 1
        }
      }
      local report = diff.diff(nil, fresh)
      return assert.are.same({
        "Consumable.Water.Basic"
      }, report.addedSets)
    end)
    return it("is deterministic in ordering", function()
      local fresh = {
        ["Consumable.Buff.Agility.Flask"] = {
          [105] = 1,
          [103] = 1,
          [104] = 1
        },
        ["Consumable.Water.Basic"] = {
          [201] = 1
        }
      }
      local a = diff.format(diff.diff(committed(), fresh))
      local b = diff.format(diff.diff(committed(), fresh))
      assert.are.same(a, b)
      return assert.are.same({
        103,
        104,
        105
      }, (diff.diff(committed(), fresh)).changes[1].added)
    end)
  end)
  return describe("format", function()
    return it("renders counts and each change, ready for a commit body", function()
      local fresh = {
        ["Consumable.Buff.Agility.Flask"] = {
          [101] = 25,
          [103] = 7
        },
        ["Consumable.Water.Basic"] = {
          [201] = 1
        }
      }
      local lines = diff.format(diff.diff(committed(), fresh))
      local joined = table.concat(lines, "\n")
      assert.is_truthy(joined:find("+1", 1, true))
      assert.is_truthy(joined:find("-1", 1, true))
      assert.is_truthy(joined:find("+ 103", 1, true))
      return assert.is_truthy(joined:find("- 102", 1, true))
    end)
  end)
end)
