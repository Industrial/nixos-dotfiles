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
    return it("discriminates weapon enchant families by miscValue", function()
      local result = run()
      assert.are.equal(8, result.sets["Consumable.Weapon Buff.Stone.Sharpening Stone"][90007])
      assert.are.equal(24, result.sets["Consumable.Weapon Buff.Oil.Wizard"][90008])
      return assert.is_nil((result.sets["Consumable.Weapon Buff.Stone.Weight Stone"] or { })[90008])
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
