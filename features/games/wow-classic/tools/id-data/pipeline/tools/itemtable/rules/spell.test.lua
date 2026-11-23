local classify = dofile("tools/itemtable/classify.lua")
local coverage = dofile("tools/itemtable/coverage.lua")
local spell = dofile("tools/itemtable/rules/spell.lua")
local consumable = dofile("tools/itemtable/rules/consumable.lua")
local fixtures
fixtures = function()
  return dofile("tools/itemtable/fixtures.lua")
end
local run
run = function(doc)
  doc = doc or fixtures()
  local rules = spell.forDocument(doc)
  return (classify.run(doc, rules)), rules, doc
end
return describe("itemtable spell domain", function()
  describe("scope", function()
    it("claims only spells some class can cast", function()
      local result, rules, doc = run()
      local castable = { }
      local _list_0 = doc.spellClass
      for _index_0 = 1, #_list_0 do
        local r = _list_0[_index_0]
        castable[r.spellId] = true
      end
      local _list_1 = doc.spells
      for _index_0 = 1, #_list_1 do
        local sp = _list_1[_index_0]
        assert.are.equal((castable[sp.id] == true), rules.scope(sp))
      end
    end)
    it("ignores the item-effect spells entirely", function()
      local result = run()
      local _list_0 = result.unclassified
      for _index_0 = 1, #_list_0 do
        local id = _list_0[_index_0]
        assert.is_true(id >= 92000, ("spell %d should be out of scope"):format(id))
      end
    end)
    return it("does not overlap the Consumable domain's entities", function()
      local _, doc
      _, _, doc = run()
      local _list_0 = doc.spells
      for _index_0 = 1, #_list_0 do
        local sp = _list_0[_index_0]
        assert.is_false(consumable.scope(sp))
      end
    end)
  end)
  describe("classification", function()
    it("classifies a lasting self aura as a self buff", function()
      return assert.are.equal(10, (run()).sets["Spell.Buff.Self"][92001])
    end)
    it("classifies a party aura separately", function()
      return assert.are.equal(12, (run()).sets["Spell.Buff.Party"][92002])
    end)
    it("classifies conjure, pet, heal and mana restore", function()
      local r = run()
      assert.are.equal(1, r.sets["Spell.Conjure"][92003])
      assert.are.equal(1, r.sets["Spell.Pet.Summon"][92004])
      assert.are.equal(300, r.sets["Spell.Heal.Direct"][92005])
      return assert.are.equal(400, r.sets["Spell.Restore.Mana"][92006])
    end)
    it("requires a real duration before calling an aura a buff", function()
      local doc = fixtures()
      local _list_0 = doc.spells
      for _index_0 = 1, #_list_0 do
        local sp = _list_0[_index_0]
        if sp.id == 92001 then
          sp.duration = 1000
        end
      end
      return assert.is_nil(((run(doc)).sets["Spell.Buff.Self"] or { })[92001])
    end)
    return it("reads the value from the effect rather than a hand-typed number", function()
      local doc = fixtures()
      local _list_0 = doc.spellEffects
      for _index_0 = 1, #_list_0 do
        local se = _list_0[_index_0]
        if se.spellId == 92001 then
          se.amount = 77
        end
      end
      return assert.are.equal(77, (run(doc)).sets["Spell.Buff.Self"][92001])
    end)
  end)
  describe("conjuring and targets", function()
    local withEffect = function(patch)
      local doc = fixtures()
      for _, se in ipairs(doc.spellEffects) do
        if se.spellId == 92001 then
          for k, v in pairs(patch) do se[k] = v end
        end
      end
      return run(doc)
    end
    it("splits conjure food from water by what the made item restores", function()
      local r = run()
      assert.is_not_nil(r.sets["Spell.Conjure.Water"][92003])
      return assert.is_nil((r.sets["Spell.Conjure.Food"] or { })[92003])
    end)
    it("calls a buff on everyone around the caster a raid buff", function()
      local r = withEffect({ target = "GROUP" })
      assert.are.equal(10, r.sets["Spell.Buff.Raid"][92001])
      return assert.is_nil((r.sets["Spell.Buff.Self"] or { })[92001])
    end)
    it("calls an area aura a self buff: it radiates from the caster", function()
      local r = withEffect({ effect = "APPLY_AREA_AURA_PARTY", target = "SELF" })
      return assert.are.equal(10, r.sets["Spell.Buff.Self"][92001])
    end)
    it("never calls a form, stance or stealth a buff", function()
      local r = withEffect({ auraType = "MOD_SHAPESHIFT" })
      return assert.is_nil((r.sets["Spell.Buff.Self"] or { })[92001])
    end)
    it("counts until-cancelled as lasting, but never a passive", function()
      local doc = fixtures()
      for _, sp in ipairs(doc.spells) do
        if sp.id == 92001 then sp.duration = -1 end
      end
      assert.are.equal(10, run(doc).sets["Spell.Buff.Self"][92001])
      for _, sp in ipairs(doc.spells) do
        if sp.id == 92001 then sp.passive = true end
      end
      return assert.is_nil((run(doc).sets["Spell.Buff.Self"] or { })[92001])
    end)
  end)
  describe("spec-filtered sets", function()
    it("emits one set per spec per family", function()
      local names = { }
      for name in pairs((run()).sets) do
        names[name] = true
      end
      assert.is_true(names["Spell.Spec.PRIEST.FIXTUREDevotion.Buff.Self"])
      return assert.is_true(names["Spell.Spec.PRIEST.FIXTUREWrath.Buff.Self"])
    end)
    it("keeps the class-wide sets as well", function()
      local r = run()
      return assert.is_not_nil(r.sets["Spell.Buff.Self"])
    end)
    it("reaches a spell through spellClass with no specId, for EVERY spec", function()
      local r = run()
      assert.are.equal(10, r.sets["Spell.Spec.PRIEST.FIXTUREDevotion.Buff.Self"][92001])
      return assert.are.equal(10, r.sets["Spell.Spec.PRIEST.FIXTUREWrath.Buff.Self"][92001])
    end)
    it("reaches a spell through a SPEC-specific spellClass row, for that spec alone", function()
      local r = run()
      assert.are.equal(400, r.sets["Spell.Spec.PRIEST.FIXTUREDevotion.Restore.Mana"][92006])
      return assert.is_nil((r.sets["Spell.Spec.PRIEST.FIXTUREWrath.Restore.Mana"] or { })[92006])
    end)
    it("reaches a spell through the TALENT join as well as spellClass", function()
      local doc = fixtures()
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = doc.spellClass
        for _index_0 = 1, #_list_0 do
          local r = _list_0[_index_0]
          if not (r.spellId == 92006 and r.specId) then
            _accum_0[_len_0] = r
            _len_0 = _len_0 + 1
          end
        end
        doc.spellClass = _accum_0
      end
      local r = run(doc)
      return assert.are.equal(400, r.sets["Spell.Spec.PRIEST.FIXTUREDevotion.Restore.Mana"][92006])
    end)
    it("does not reach a spell no source attributes to the spec", function()
      local r = run()
      return assert.is_nil((r.sets["Spell.Spec.PRIEST.FIXTUREDevotion.Pet.Summon"] or { })[92004])
    end)
    it("makes the two specs genuinely differ", function()
      local r = run()
      local a, b = { }, { }
      for name, members in pairs(r.sets) do
        local _continue_0 = false
        repeat
          if not (name:match("^Spell%.Spec%.PRIEST%.FIXTUREDevotion%.")) then
            _continue_0 = true
            break
          end
          for id in pairs(members) do
            a[id] = true
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      for name, members in pairs(r.sets) do
        local _continue_0 = false
        repeat
          if not (name:match("^Spell%.Spec%.PRIEST%.FIXTUREWrath%.")) then
            _continue_0 = true
            break
          end
          for id in pairs(members) do
            b[id] = true
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      local differing = 0
      for id in pairs(a) do
        if not b[id] then
          differing = differing + 1
        end
      end
      for id in pairs(b) do
        if not a[id] then
          differing = differing + 1
        end
      end
      return assert.is_true(differing > 0)
    end)
    it("emits no spec sets for a document with no specs", function()
      local doc = fixtures()
      doc.specs = nil
      local names = { }
      for name in pairs((run(doc)).sets) do
        names[name] = true
      end
      for name in pairs(names) do
        assert.is_nil(name:match("^Spell%.Spec%."))
      end
    end)
    return it("does not change the class-wide classification", function()
      local withSpecs = run()
      local doc = fixtures()
      doc.specs = nil
      local without = run(doc)
      assert.are.same(withSpecs.sets["Spell.Buff.Self"], without.sets["Spell.Buff.Self"])
      return assert.are.same(withSpecs.unclassified, without.unclassified)
    end)
  end)
  describe("the gate policy", function()
    it("ratchets rather than gating at zero", function()
      return assert.are.equal("ratchet", spell.gate)
    end)
    it("has no exclusion that matches everything", function()
      local _, rules, doc = run()
      local ctx = classify.context(doc)
      local _list_0 = rules.exclusions
      for _index_0 = 1, #_list_0 do
        local exclusion = _list_0[_index_0]
        local matched = 0
        local _list_1 = doc.spells
        for _index_1 = 1, #_list_1 do
          local sp = _list_1[_index_1]
          if rules.scope(sp) and exclusion.match(ctx, sp) then
            matched = matched + 1
          end
        end
        local inScope = 0
        local _list_2 = doc.spells
        for _index_1 = 1, #_list_2 do
          local sp = _list_2[_index_1]
          if rules.scope(sp) then
            inScope = inScope + 1
          end
        end
        assert.is_true(matched < inScope, ("exclusion %q matches every in-scope spell"):format(exclusion.reason))
      end
    end)
    it("still reports unclassified spells rather than hiding them", function()
      local doc = fixtures()
      doc.spells[#doc.spells + 1] = {
        id = 92100,
        name = "FIXTURE Fireball",
        duration = 0
      }
      doc.spellClass[#doc.spellClass + 1] = {
        spellId = 92100,
        classFile = "MAGE"
      }
      doc.spellEffects[#doc.spellEffects + 1] = {
        spellId = 92100,
        index = 1,
        auraType = "SCHOOL_DAMAGE",
        amount = 50
      }
      return assert.are.same({
        92100
      }, (run(doc)).unclassified)
    end)
    it("lets a ratchet domain pass the gate with unclassified entities", function()
      local doc = fixtures()
      doc.spells[#doc.spells + 1] = {
        id = 92100,
        name = "FIXTURE Fireball",
        duration = 0
      }
      doc.spellClass[#doc.spellClass + 1] = {
        spellId = 92100,
        classFile = "MAGE"
      }
      doc.spellEffects[#doc.spellEffects + 1] = {
        spellId = 92100,
        index = 1,
        auraType = "SCHOOL_DAMAGE"
      }
      local result, rules, d = run(doc)
      local ok = coverage.check({
        Spell = coverage.forDomain(result, d, rules)
      })
      return assert.is_true(ok)
    end)
    return it("but still fails that domain when unclassified GROWS", function()
      local result, rules, doc = run()
      local report = coverage.forDomain(result, doc, rules)
      report.unclassifiedCount = 5
      local ok, problems = coverage.check({
        Spell = report
      }, {
        domains = {
          Spell = {
            status = "active",
            classified = 6,
            unclassifiedCount = 0
          }
        }
      })
      assert.is_false(ok)
      return assert.is_truthy((table.concat(problems, " ")):find("unclassified rose", 1, true))
    end)
  end)
  return describe("engine generalization", function()
    it("classifies the collection the domain names", function()
      local doc = fixtures()
      return assert.are.equal(#doc.spells, #classify.entitiesOf(doc, spell.forDocument(doc)))
    end)
    it("defaults to items for a domain that names none", function()
      local doc = fixtures()
      return assert.are.equal(#doc.items, #classify.entitiesOf(doc, {
        scope = function()
          return true
        end
      }))
    end)
    return it("counts coverage over the same population it classified", function()
      local result, rules, doc = run()
      local report = coverage.forDomain(result, doc, rules)
      return assert.are.equal(report.inScope, report.classified + report.excluded + report.unclassifiedCount)
    end)
  end)
end)
