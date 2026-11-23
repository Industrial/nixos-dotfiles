local classify = dofile("tools/itemtable/classify.lua")
local rules = dofile("tools/itemtable/rules/consumable.lua")
local fixtures
fixtures = function()
  return dofile("tools/itemtable/fixtures.lua")
end
local run
run = function()
  return classify.run(fixtures(), rules)
end
return describe("itemtable classifier", function()
  describe("the release gate", function()
    it("leaves nothing unclassified over the fixtures", function()
      return assert.are.same({ }, run().unclassified)
    end)
    it("puts every in-scope fixture in at least one set", function()
      local result = run()
      local placed = { }
      for _, members in pairs(result.sets) do
        for id in pairs(members) do
          placed[id] = true
        end
      end
      local _list_0 = fixtures().items
      for _index_0 = 1, #_list_0 do
        local _continue_0 = false
        repeat
          local item = _list_0[_index_0]
          if not (rules.scope(item)) then
            _continue_0 = true
            break
          end
          assert.is_true(placed[item.id] == true, ("item %d landed in no set"):format(item.id))
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
    end)
    return it("ignores out-of-scope items entirely rather than calling them excluded", function()
      local result = run()
      assert.is_nil(result.excluded[90009])
      local _list_0 = result.unclassified
      for _index_0 = 1, #_list_0 do
        local id = _list_0[_index_0]
        assert.are_not.equal(90009, id)
      end
    end)
  end)
  describe("flask vs elixir, decided by duration not by name", function()
    it("classifies the 2h agility consumable as a flask", function()
      return assert.are.equal(25, run().sets["Consumable.Buff.Agility.Flask"][90001])
    end)
    it("classifies the 1h agility consumable as a self elixir", function()
      return assert.are.equal(18, run().sets["Consumable.Buff.Agility.Self"][90002])
    end)
    it("keeps the two mutually exclusive", function()
      local result = run()
      assert.is_nil(result.sets["Consumable.Buff.Agility.Flask"][90002])
      return assert.is_nil(result.sets["Consumable.Buff.Agility.Self"][90001])
    end)
    it("reads the value from the spell effect rather than a hand-typed number", function()
      local doc = fixtures()
      local _list_0 = doc.spellEffects
      for _index_0 = 1, #_list_0 do
        local se = _list_0[_index_0]
        if se.spellId == 91001 then
          se.amount = 99
        end
      end
      return assert.are.equal(99, classify.run(doc, rules).sets["Consumable.Buff.Agility.Flask"][90001])
    end)
    return it("follows a duration change across the threshold", function()
      local doc = fixtures()
      local _list_0 = doc.spells
      for _index_0 = 1, #_list_0 do
        local sp = _list_0[_index_0]
        if sp.id == 91001 then
          sp.duration = 60000
        end
      end
      local result = classify.run(doc, rules)
      assert.is_nil((result.sets["Consumable.Buff.Agility.Flask"] or { })[90001])
      return assert.are.equal(25, result.sets["Consumable.Buff.Agility.Self"][90001])
    end)
  end)
  describe("other families", function()
    it("classifies the guardian elixir by its armor aura", function()
      return assert.are.equal(450, run().sets["Consumable.Buff.Armor.Self"][90003])
    end)
    it("classifies well-fed food by its stat aura", function()
      return assert.are.equal(6, run().sets["Consumable.Food.Buff.Stamina"][90004])
    end)
    it("separates conjured from basic water by name", function()
      local result = run()
      assert.are.equal(1800, result.sets["Consumable.Water.Conjured"][90005])
      assert.are.equal(1200, result.sets["Consumable.Water.Basic"][90006])
      return assert.is_nil(result.sets["Consumable.Water.Basic"][90005])
    end)
    it("puts conjured instant restores in the stone sets, never the potion sets", function()
      local result = run()
      assert.are.equal(500, result.sets["Consumable.Cooldown.Stone.Health.Warlock"][90015])
      assert.are.equal(400, result.sets["Consumable.Cooldown.Stone.Mana.Mana Stone"][90016])
      assert.is_nil(result.sets["Consumable.Cooldown.Stone.Health.Warlock"][90012])
      return assert.is_nil((result.sets["Consumable.Potion.Recovery.Healing.Basic"] or { })[90015])
    end)
    it("puts a non-potion on the potion cooldown in the cooldown set", function()
      local result = run()
      assert.are.equal(500, result.sets["Consumable.Cooldown.Potion.Health.Basic"][90017])
      assert.is_nil(result.sets["Consumable.Cooldown.Potion.Health.Basic"][90012])
      return assert.is_nil(result.sets["Consumable.Cooldown.Potion.Health.Basic"][90015])
    end)
    it("counts an 'Other' item on food's cooldown group as food", function()
      local doc = fixtures()
      local foodSpell = nil
      local _list_0 = doc.itemEffects
      for _index_0 = 1, #_list_0 do
        local fx = _list_0[_index_0]
        if fx.itemId == 90004 or fx.itemId == 90006 then
          fx.cooldownCategory = 11
        end
        if fx.itemId == 90004 then
          foodSpell = fx.spellId
        end
      end
      doc.items[#doc.items + 1] = { id = 90102, name = "FIXTURE Old Fish", class = "Consumable", subclass = "Other" }
      doc.items[#doc.items + 1] = { id = 90103, name = "FIXTURE Balm", class = "Consumable", subclass = "Other" }
      doc.itemEffects[#doc.itemEffects + 1] = { itemId = 90102, spellId = foodSpell, trigger = "use", cooldownCategory = 11 }
      doc.itemEffects[#doc.itemEffects + 1] = { itemId = 90103, spellId = 91017, trigger = "use", cooldownCategory = 1153 }
      doc.spells[#doc.spells + 1] = { id = 91017, name = "FIXTURE Balm", duration = 10000 }
      doc.spellEffects[#doc.spellEffects + 1] = { spellId = 91017, index = 1, auraType = "PERIODIC_HEAL", amount = 50 }
      local result = classify.run(doc, rules)
      assert.is_not_nil(result.sets["Consumable.Food.Edible.Basic.Non-Conjured"][90102])
      return assert.is_nil(result.sets["Consumable.Food.Edible.Basic.Non-Conjured"][90103])
    end)
    return it("discriminates weapon enchant families by miscValue", function()
      local result = run()
      assert.are.equal(8, result.sets["Consumable.Weapon Buff.Stone.Sharpening Stone"][90007])
      assert.are.equal(24, result.sets["Consumable.Weapon Buff.Oil.Wizard"][90008])
      return assert.is_nil((result.sets["Consumable.Weapon Buff.Stone.Weight Stone"] or { })[90008])
    end)
  end)
  describe("out-of-scope kinds", function()
    -- One consumable with a single use effect; returns the classify result.
    local withItem = function(subclass, effect, duration, extra)
      local doc = fixtures()
      local item = { id = 90200, name = "FIXTURE Probe", class = "Consumable", subclass = subclass }
      for k, v in pairs(extra or { }) do item[k] = v end
      doc.items[#doc.items + 1] = item
      doc.spells[#doc.spells + 1] = { id = 91200, name = "FIXTURE Probe", duration = duration }
      doc.itemEffects[#doc.itemEffects + 1] = { itemId = 90200, spellId = 91200, trigger = "use" }
      effect.spellId, effect.index = 91200, 1
      doc.spellEffects[#doc.spellEffects + 1] = effect
      return classify.run(doc, rules)
    end
    it("excludes a Spirit elixir by kind", function()
      local r = withItem("Elixir", { auraType = "MOD_STAT", statType = "SPIRIT", amount = 8 }, 3600000)
      return assert.is_truthy((r.excluded[90200] or ""):find("Spirit", 1, true))
    end)
    it("excludes a 15-second combat potion: shorter than a buff", function()
      local r = withItem("Potion", { auraType = "MOD_ATTACK_POWER", amount = 40 }, 15000)
      assert.is_nil((r.sets["Consumable.Buff.Attack Power.Self"] or { })[90200])
      return assert.is_truthy((r.excluded[90200] or ""):find("combat potions", 1, true))
    end)
    it("excludes a percentage restore", function()
      local r = withItem("Food", { auraType = "OBS_MOD_HEALTH", amount = 2 }, 30000)
      return assert.is_truthy((r.excluded[90200] or ""):find("percentage", 1, true))
    end)
    it("excludes an instant restore that is no potion or stone (Whipper Root)", function()
      local r = withItem("Food", { auraType = "HEAL", amount = 900 }, 0)
      return assert.is_truthy((r.excluded[90200] or ""):find("no food, drink", 1, true))
    end)
    return it("keeps an Agility elixir in its set, never excluded", function()
      local r = withItem("Elixir", { auraType = "MOD_STAT", statType = "AGILITY", amount = 8 }, 3600000)
      assert.are.equal(8, r.sets["Consumable.Buff.Agility.Self"][90200])
      return assert.is_nil(r.excluded[90200])
    end)
  end)
  describe("unclassified and excluded", function()
    it("flags a consumable with an unrecognised aura as unclassified", function()
      local doc = fixtures()
      doc.items[#doc.items + 1] = {
        id = 90100,
        name = "FIXTURE Mystery Potion",
        class = "Consumable",
        subclass = "Potion"
      }
      doc.spells[#doc.spells + 1] = {
        id = 91100,
        name = "FIXTURE Mystery",
        duration = 1000
      }
      doc.itemEffects[#doc.itemEffects + 1] = {
        itemId = 90100,
        spellId = 91100,
        trigger = "use"
      }
      doc.spellEffects[#doc.spellEffects + 1] = {
        spellId = 91100,
        index = 1,
        auraType = "SOMETHING_NEW",
        amount = 5
      }
      return assert.are.same({
        90100
      }, classify.run(doc, rules).unclassified)
    end)
    return it("excludes a consumable with no use effect, with a reason", function()
      local doc = fixtures()
      doc.items[#doc.items + 1] = {
        id = 90101,
        name = "FIXTURE Inert Thing",
        class = "Consumable"
      }
      local result = classify.run(doc, rules)
      assert.is_string(result.excluded[90101])
      return assert.are.same({ }, result.unclassified)
    end)
  end)
  describe("unsupported sets", function()
    return it("reports each unsupported set with its reason instead of evaluating it", function()
      local result = run()
      assert.is_string(result.unsupported["Consumable.Buff.Agility.Target"])
      assert.is_truthy(result.unsupported["Consumable.Buff.Agility.Target"]:find("targeting", 1, true))
      return assert.is_nil(result.sets["Consumable.Buff.Agility.Target"])
    end)
  end)
  describe("overrides", function()
    it("are empty in a healthy tree", function()
      return assert.are.same({ }, rules.overrides)
    end)
    return it("win over predicates when present", function()
      local patched = {
        scope = rules.scope,
        sets = rules.sets,
        exclusions = rules.exclusions
      }
      patched.overrides = {
        [90001] = {
          sets = {
            "Consumable.Water.Basic"
          },
          value = 7,
          reason = "fixture"
        }
      }
      local result = classify.run(fixtures(), patched)
      assert.are.equal(7, result.sets["Consumable.Water.Basic"][90001])
      return assert.is_nil((result.sets["Consumable.Buff.Agility.Flask"] or { })[90001])
    end)
  end)
  describe("encodeSet", function()
    it("emits LPT-shaped pairs ordered by id", function()
      return assert.are.equal("1:5,7:9", classify.encodeSet({
        [7] = 9,
        [1] = 5
      }))
    end)
    it("omits a value of 1, matching LPT's bare-id form", function()
      return assert.are.equal("3", classify.encodeSet({
        [3] = 1
      }))
    end)
    return it("is empty for an empty set", function()
      assert.are.equal("", classify.encodeSet({ }))
      return assert.are.equal("", classify.encodeSet(nil))
    end)
  end)
  return describe("determinism", function()
    return it("produces identical encoded sets across runs", function()
      local a, b = run(), run()
      for setName, members in pairs(a.sets) do
        assert.are.equal(classify.encodeSet(members), classify.encodeSet(b.sets[setName]))
      end
    end)
  end)
end)
