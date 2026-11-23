local _list_0 = {
  "src.modules.automation.upkeep.Rules",
  "src.modules.automation.upkeep.classes.MAGE",
  "src.modules.automation.upkeep.Engine"
}
for _index_0 = 1, #_list_0 do
  local mod = _list_0[_index_0]
  require(mod)
end
local Engine = _G.idUpkeep_UpkeepEngine
local Rules = _G.idUpkeep_UpkeepRules
local CONJURED, REAL = 7401, 7402
local snapshot
snapshot = function(food, water)
  return {
    class = "MAGE",
    level = 60,
    now = 1000,
    inInstance = false,
    inCombat = false,
    player = {
      healthPct = 30,
      manaPct = 30,
      usesMana = true
    },
    spells = { },
    items = { },
    itemInfo = { },
    units = {
      player = {
        exists = true,
        class = "MAGE",
        usesMana = true,
        auras = { }
      }
    },
    pet = {
      exists = false
    },
    weapon = {
      mh = {
        isWeapon = false
      },
      oh = {
        isWeapon = false
      }
    },
    consumables = { },
    foodBuffs = { },
    food = food or { },
    water = water or { },
    weaponItems = { },
    wellFed = {
      ids = { },
      names = {
        "Well Fed"
      }
    }
  }
end
local candidate
candidate = function(itemId, value, conjured, count)
  if count == nil then
    count = 20
  end
  return {
    itemId = itemId,
    value = value,
    count = count,
    conjured = conjured,
    usable = true
  }
end
local opts
opts = function()
  return {
    restThreshold = 80,
    includeParty = true,
    useConsumables = true,
    recent = { }
  }
end
local restStep
restStep = function(snap, label)
  local _list_1 = Engine.explain(snap, Rules.forClass("MAGE"), opts())
  for _index_0 = 1, #_list_1 do
    local _continue_0 = false
    repeat
      local entry = _list_1[_index_0]
      if not (entry.phase == "rest" and entry.label == label) then
        _continue_0 = true
        break
      end
      if entry.step then
        return entry.step
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return nil
end
return describe("Engine rest phase: conjured first", function()
  describe("eating", function()
    it("eats the CONJURED food even though the real food restores more", function()
      local snap = snapshot({
        candidate(REAL, 2000, false),
        candidate(CONJURED, 800, true)
      })
      local step = restStep(snap, "Eat")
      assert.is_not_nil(step)
      return assert.are.equal(CONJURED, step.item)
    end)
    it("eats the real food once the conjured is gone", function()
      local snap = snapshot({
        candidate(REAL, 2000, false)
      })
      return assert.are.equal(REAL, (restStep(snap, "Eat")).item)
    end)
    it("ignores a conjured stack that is empty", function()
      local snap = snapshot({
        candidate(REAL, 2000, false),
        candidate(CONJURED, 800, true, 0)
      })
      return assert.are.equal(REAL, (restStep(snap, "Eat")).item)
    end)
    it("ignores conjured food the client says is unusable", function()
      local list = {
        candidate(REAL, 2000, false),
        candidate(CONJURED, 800, true)
      }
      list[2].usable = false
      return assert.are.equal(REAL, (restStep(snapshot(list), "Eat")).item)
    end)
    it("ranks two conjured foods by restore amount", function()
      local snap = snapshot({
        candidate(7403, 800, true),
        candidate(7404, 1600, true)
      })
      return assert.are.equal(7404, (restStep(snap, "Eat")).item)
    end)
    it("ranks two real foods by restore amount", function()
      local snap = snapshot({
        candidate(7405, 800, false),
        candidate(7406, 1600, false)
      })
      return assert.are.equal(7406, (restStep(snap, "Eat")).item)
    end)
    return it("breaks a tie on the smaller stack, as it always did", function()
      local snap = snapshot({
        candidate(7407, 800, false, 20),
        candidate(7408, 800, false, 3)
      })
      return assert.are.equal(7408, (restStep(snap, "Eat")).item)
    end)
  end)
  describe("drinking", function()
    it("drinks the CONJURED water even though the real water restores more", function()
      local snap = snapshot({ }, {
        candidate(REAL, 2400, false),
        candidate(CONJURED, 900, true)
      })
      local step = restStep(snap, "Drink")
      assert.is_not_nil(step)
      return assert.are.equal(CONJURED, step.item)
    end)
    return it("drinks the real water once the conjured is gone", function()
      local snap = snapshot({ }, {
        candidate(REAL, 2400, false)
      })
      return assert.are.equal(REAL, (restStep(snap, "Drink")).item)
    end)
  end)
  return describe("what did not change", function()
    it("still skips eating when health is fine", function()
      local snap = snapshot({
        candidate(CONJURED, 800, true)
      })
      snap.player.healthPct = 100
      return assert.is_nil(restStep(snap, "Eat"))
    end)
    return it("still reports having no food rather than offering nothing silently", function()
      local lines = { }
      local _list_1 = Engine.explain(snapshot(), Rules.forClass("MAGE"), opts())
      for _index_0 = 1, #_list_1 do
        local entry = _list_1[_index_0]
        if entry.phase == "rest" and entry.label == "Eat" then
          lines[#lines + 1] = entry.reason
        end
      end
      return assert.is_truthy((table.concat(lines, " ")):find("no usable food", 1, true))
    end)
  end)
end)
