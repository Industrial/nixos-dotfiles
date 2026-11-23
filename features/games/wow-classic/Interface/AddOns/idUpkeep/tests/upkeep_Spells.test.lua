local _list_0 = {
  "src.modules.automation.upkeep.Rules",
  "src.modules.automation.upkeep.classes.MAGE",
  "src.modules.automation.upkeep.classes.WARRIOR",
  "src.modules.automation.upkeep.Spells"
}
for _index_0 = 1, #_list_0 do
  local mod = _list_0[_index_0]
  require(mod)
end
local Spells = _G.idUpkeep_UpkeepSpells
local fakeLib
fakeLib = function(sets)
  return {
    IterateSet = function(self, set)
      local members = sets[set]
      if not (members) then
        return nil
      end
      return next, members
    end,
    SpellInSet = function(self, id, set)
      return (sets[set] or { })[id]
    end
  }
end
local ids
ids = function(list)
  local _accum_0 = { }
  local _len_0 = 1
  for _index_0 = 1, #list do
    local e = list[_index_0]
    _accum_0[_len_0] = e.spellId
    _len_0 = _len_0 + 1
  end
  return _accum_0
end
return describe("Upkeep.Spells", function()
  describe("the generated library", function()
    it("resolves a set from the library when it has data", function()
      local lib = fakeLib({
        ["Spell.Buff.Self"] = {
          [168] = 20,
          [7302] = 40
        }
      })
      local list, source = Spells.resolve("Spell.Buff.Self", "MAGE", {
        lib = lib
      })
      assert.are.equal("library", source)
      return assert.are.same({
        168,
        7302
      }, ids(list))
    end)
    it("carries the value the data recorded", function()
      local lib = fakeLib({
        ["Spell.Buff.Self"] = {
          [168] = 20
        }
      })
      local list = Spells.resolve("Spell.Buff.Self", "MAGE", {
        lib = lib
      })
      return assert.are.equal(20, list[1].value)
    end)
    it("defaults a valueless member to 1 rather than nil", function()
      local lib = fakeLib({
        ["Spell.Buff.Self"] = {
          [168] = true
        }
      })
      local list = Spells.resolve("Spell.Buff.Self", "MAGE", {
        lib = lib
      })
      return assert.are.equal(1, list[1].value)
    end)
    it("returns ids in a stable order", function()
      local lib = fakeLib({
        ["Spell.Buff.Self"] = {
          [7302] = 1,
          [168] = 1,
          [6117] = 1
        }
      })
      local list = Spells.fromLibrary("Spell.Buff.Self", lib)
      return assert.are.same({
        168,
        6117,
        7302
      }, ids(list))
    end)
    return it("survives a library whose IterateSet misbehaves", function()
      assert.are.same({ }, Spells.fromLibrary("Spell.Buff.Self", {
        IterateSet = function()
          return nil
        end
      }))
      assert.are.same({ }, Spells.fromLibrary("Spell.Buff.Self", {
        IterateSet = function()
          return error("boom")
        end
      }))
      return assert.are.same({ }, Spells.fromLibrary("Spell.Buff.Self", { }))
    end)
  end)
  describe("the class-table fallback", function()
    it("falls back when the library is loaded but has no data for the set", function()
      local list, source = Spells.resolve("Spell.Buff.Self", "MAGE", {
        lib = fakeLib({ })
      })
      assert.are.equal("class-table", source)
      return assert.is_true(#list > 0)
    end)
    it("falls back when the library is not loaded at all", function()
      local list, source = Spells.resolve("Spell.Buff.Self", "MAGE", {
        lib = false
      })
      assert.are.equal("class-table", source)
      return assert.is_true(#list > 0)
    end)
    it("reads the mage's armors as self buffs", function()
      local MAGE = _G.idUpkeep_UpkeepClassMAGE
      local list = Spells.fromClassRules("Spell.Buff.Self", "MAGE")
      local found = { }
      for _index_0 = 1, #list do
        local e = list[_index_0]
        found[e.spellId] = true
      end
      assert.is_true(found[MAGE.SPELL.FROST_ARMOR])
      return assert.is_true(found[MAGE.SPELL.MAGE_ARMOR])
    end)
    it("reads Arcane Intellect as a party buff, not a self buff", function()
      local MAGE = _G.idUpkeep_UpkeepClassMAGE
      local party = { }
      local _list_1 = Spells.fromClassRules("Spell.Buff.Party", "MAGE")
      for _index_0 = 1, #_list_1 do
        local e = _list_1[_index_0]
        party[e.spellId] = true
      end
      return assert.is_true(party[MAGE.SPELL.ARCANE_INTELLECT])
    end)
    it("excludes satisfiedBy ids, which are not castable by this character", function()
      local MAGE = _G.idUpkeep_UpkeepClassMAGE
      local party = { }
      local _list_1 = Spells.fromClassRules("Spell.Buff.Party", "MAGE")
      for _index_0 = 1, #_list_1 do
        local e = _list_1[_index_0]
        party[e.spellId] = true
      end
      return assert.is_nil(party[MAGE.SPELL.ARCANE_BRILLIANCE])
    end)
    it("reads the mage's conjures", function()
      local MAGE = _G.idUpkeep_UpkeepClassMAGE
      local conj = { }
      local _list_1 = Spells.fromClassRules("Spell.Conjure", "MAGE")
      for _index_0 = 1, #_list_1 do
        local e = _list_1[_index_0]
        conj[e.spellId] = true
      end
      assert.is_true(conj[MAGE.SPELL.CONJURE_WATER])
      return assert.is_true(conj[MAGE.SPELL.CONJURE_FOOD])
    end)
    it("gives fallback spells value 1, since class tables record no amounts", function()
      local _list_1 = Spells.fromClassRules("Spell.Buff.Self", "MAGE")
      for _index_0 = 1, #_list_1 do
        local e = _list_1[_index_0]
        assert.are.equal(1, e.value)
      end
    end)
    return it("deduplicates a spell listed by two rules", function()
      local seen, dupes = { }, 0
      local _list_1 = Spells.fromClassRules("Spell.Buff.Self", "MAGE")
      for _index_0 = 1, #_list_1 do
        local e = _list_1[_index_0]
        if seen[e.spellId] then
          dupes = dupes + 1
        end
        seen[e.spellId] = true
      end
      return assert.are.equal(0, dupes)
    end)
  end)
  describe("nothing to resolve", function()
    it("reports `none` for a class with no rules of that kind", function()
      local list, source = Spells.resolve("Spell.Buff.Party", "WARRIOR", {
        lib = fakeLib({ })
      })
      assert.are.same({ }, list)
      return assert.are.equal("none", source)
    end)
    it("says a fallback was possible, so installing data would help", function()
      local _, canFallBack
      _, _, canFallBack = Spells.resolve("Spell.Buff.Party", "WARRIOR", {
        lib = fakeLib({ })
      })
      return assert.is_true(canFallBack)
    end)
    it("reports `none` with NO fallback for a set the class tables never covered", function()
      local list, source, canFallBack = Spells.resolve("Spell.Heal.Direct", "PALADIN", {
        lib = fakeLib({ })
      })
      assert.are.same({ }, list)
      assert.are.equal("none", source)
      return assert.is_false(canFallBack)
    end)
    it("still prefers library data for a set with no fallback", function()
      local lib = fakeLib({
        ["Spell.Heal.Direct"] = {
          [635] = 300
        }
      })
      local list, source = Spells.resolve("Spell.Heal.Direct", "PALADIN", {
        lib = lib
      })
      assert.are.equal("library", source)
      return assert.are.same({
        635
      }, ids(list))
    end)
    it("knows which sets have a hand-written equivalent", function()
      assert.is_true(Spells.canFallBack("Spell.Buff.Self"))
      assert.is_true(Spells.canFallBack("Spell.Pet.Summon"))
      assert.is_false(Spells.canFallBack("Spell.Restore.Mana"))
      return assert.is_false(Spells.canFallBack("Spell.Nonsense"))
    end)
    return it("survives an unknown class without erroring", function()
      local list, source = Spells.resolve("Spell.Buff.Self", "DEMONHUNTER", {
        lib = fakeLib({ })
      })
      assert.are.same({ }, list)
      return assert.are.equal("none", source)
    end)
  end)
  describe("narrowing to what is castable now", function()
    local snap
    snap = function(known)
      local spells = { }
      for _index_0 = 1, #known do
        local id = known[_index_0]
        spells[id] = {
          known = true,
          name = ("Spell %d"):format(id)
        }
      end
      return {
        spells = spells
      }
    end
    it("keeps only spells the snapshot says are known", function()
      local list = {
        {
          spellId = 168,
          value = 1
        },
        {
          spellId = 6117,
          value = 1
        }
      }
      return assert.are.same({
        168
      }, ids(Spells.known(list, snap({
        168
      }))))
    end)
    it("drops a spell the snapshot has not resolved at all", function()
      local list = {
        {
          spellId = 168,
          value = 1
        }
      }
      return assert.are.same({ }, ids(Spells.known(list, snap({ }))))
    end)
    it("drops a known spell whose name has not arrived yet", function()
      local s = {
        spells = {
          [168] = {
            known = true
          }
        }
      }
      return assert.are.same({ }, Spells.known({
        {
          spellId = 168,
          value = 1
        }
      }, s))
    end)
    return it("returns nothing without a snapshot rather than erroring", function()
      return assert.are.same({ }, Spells.known({
        {
          spellId = 168
        }
      }, nil))
    end)
  end)
  describe("choosing between them", function()
    it("picks the highest value", function()
      local best = Spells.best({
        {
          spellId = 168,
          value = 20
        },
        {
          spellId = 7302,
          value = 40
        }
      })
      return assert.are.equal(7302, best.spellId)
    end)
    it("breaks a tie by the lower id, so the choice is stable", function()
      local best = Spells.best({
        {
          spellId = 7302,
          value = 20
        },
        {
          spellId = 168,
          value = 20
        }
      })
      return assert.are.equal(168, best.spellId)
    end)
    return it("returns nil for an empty list", function()
      assert.is_nil(Spells.best({ }))
      return assert.is_nil(Spells.best(nil))
    end)
  end)
  describe("the spec-filtered answer", function()
    local SELF = "Spell.Buff.Self"
    local DEVOTION = {
      specId = 93001,
      name = "Devotion"
    }
    local WRATH = {
      specId = 93002,
      name = "Wrath"
    }
    local specLib
    specLib = function()
      return fakeLib({
        ["Spell.Buff.Self"] = {
          [1001] = 5,
          [1002] = 5
        },
        ["Spell.Spec.PRIEST.Devotion.Buff.Self"] = {
          [1001] = 5,
          [1002] = 5
        },
        ["Spell.Spec.PRIEST.Wrath.Buff.Self"] = {
          [1001] = 5
        }
      })
    end
    it("names a spec set the way the generator names it", function()
      return assert.are.equal("Spell.Spec.PRIEST.Devotion.Buff.Self", Spells.specSetName(SELF, "PRIEST", "Devotion"))
    end)
    it("strips spaces, so a two-word spec is still one token", function()
      return assert.are.equal("Spell.Spec.PRIEST.HolyLight.Buff.Self", Spells.specSetName(SELF, "PRIEST", "Holy Light"))
    end)
    it("prefers the spec's own set over the class-wide one", function()
      local list, source = Spells.resolve(SELF, "PRIEST", {
        lib = specLib(),
        spec = WRATH
      })
      assert.are.equal("library-spec", source)
      return assert.are.same({
        1001
      }, ids(list))
    end)
    it("gives a different answer for the other spec of the SAME class", function()
      local a = Spells.resolve(SELF, "PRIEST", {
        lib = specLib(),
        spec = DEVOTION
      })
      local b = Spells.resolve(SELF, "PRIEST", {
        lib = specLib(),
        spec = WRATH
      })
      assert.are.same({
        1001,
        1002
      }, ids(a))
      return assert.are.same({
        1001
      }, ids(b))
    end)
    it("falls back to the class-wide set when the spec has none", function()
      local list, source = Spells.resolve(SELF, "PRIEST", {
        lib = specLib(),
        spec = {
          specId = 93003,
          name = "Unknown"
        }
      })
      assert.are.equal("library", source)
      return assert.are.same({
        1001,
        1002
      }, ids(list))
    end)
    it("uses the class-wide set when the client will not say the spec", function()
      local list, source = Spells.resolve(SELF, "PRIEST", {
        lib = specLib(),
        spec = false
      })
      assert.are.equal("library", source)
      return assert.are.same({
        1001,
        1002
      }, ids(list))
    end)
    it("NEVER filters a class-table answer by spec", function()
      local withData, source = Spells.resolve(SELF, "MAGE", {
        lib = fakeLib({ }),
        spec = WRATH
      })
      assert.are.equal("class-table", source)
      return assert.is_true(#withData > 0)
    end)
    it("reads the live spec when none is injected", function()
      local saved = {
        _G.GetSpecialization,
        _G.GetSpecializationInfo
      }
      _G.GetSpecialization = function()
        return 1
      end
      _G.GetSpecializationInfo = function()
        return 93002, "Wrath"
      end
      local list, source = Spells.resolve(SELF, "PRIEST", {
        lib = specLib()
      })
      _G.GetSpecialization, _G.GetSpecializationInfo = saved[1], saved[2]
      assert.are.equal("library-spec", source)
      return assert.are.same({
        1001
      }, ids(list))
    end)
    it("survives a client with no spec API", function()
      local saved = {
        _G.GetSpecialization,
        _G.GetSpecializationInfo
      }
      _G.GetSpecialization, _G.GetSpecializationInfo = nil, nil
      assert.is_nil(Spells.activeSpec())
      local _, source = Spells.resolve(SELF, "PRIEST", {
        lib = specLib()
      })
      _G.GetSpecialization, _G.GetSpecializationInfo = saved[1], saved[2]
      return assert.are.equal("library", source)
    end)
    return it("survives a spec API that errors or answers junk", function()
      local saved = {
        _G.GetSpecialization,
        _G.GetSpecializationInfo
      }
      _G.GetSpecialization = function()
        return error("boom")
      end
      assert.is_nil(Spells.activeSpec())
      _G.GetSpecialization = function()
        return 1
      end
      _G.GetSpecializationInfo = function()
        return 93002, 42
      end
      assert.is_nil(Spells.activeSpec())
      _G.GetSpecialization, _G.GetSpecializationInfo = saved[1], saved[2]
    end)
  end)
  return describe("the module boundary", function()
    it("publishes itself under the upkeep namespace", function()
      return assert.are.equal(Spells, _G.idUpkeep_UpkeepSpells)
    end)
    it("names the library it prefers", function()
      return assert.are.equal("idLibSpellTable-1.0", Spells.LIB_NAME)
    end)
    return it("does not need the real LibStub to answer", function()
      local saved = _G.LibStub
      _G.LibStub = nil
      assert.is_nil(Spells.lib())
      local list, source = Spells.resolve("Spell.Buff.Self", "MAGE")
      assert.are.equal("class-table", source)
      assert.is_true(#list > 0)
      _G.LibStub = saved
    end)
  end)
end)
