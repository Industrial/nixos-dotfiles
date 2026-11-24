local dbc = dofile("tools/itemtable/sources/dbc.lua")
local validate = dofile("tools/itemtable/validate.lua")
local tables
tables = function()
  return {
    item = {
      {
        ID = "101",
        ClassID = "0",
        SubclassID = "3"
      },
      {
        ID = "102",
        ClassID = "7",
        SubclassID = "1"
      },
      {
        ID = "103",
        ClassID = "0",
        SubclassID = "1"
      }
    },
    itemSparse = {
      {
        ID = "101",
        Display_lang = "Flask of Agility",
        OverallQualityID = "4",
        ItemLevel = "60",
        Stackable = "5"
      },
      {
        ID = "102",
        Display_lang = "Iron Bar",
        OverallQualityID = "1",
        ItemLevel = "20",
        Stackable = "20"
      }
    },
    spell = {
      {
        ID = "9001",
        Name_lang = "Flask of Agility"
      }
    },
    itemEffect = {
      {
        ParentItemID = "101",
        SpellID = "9001",
        TriggerType = "0",
        Charges = "1"
      }
    },
    spellEffect = {
      {
        SpellID = "9001",
        EffectIndex = "0",
        EffectAura = "APPLY_AURA",
        EffectBasePoints = "25",
        EffectMiscValue_0 = "3"
      }
    }
  }
end
describe("itemtable dbc source", function()
  describe("parseCsv", function()
    it("keys rows by header name", function()
      local rows = dbc.parseCsv("ID,Name\n1,Alpha\n2,Beta\n")
      assert.are.equal(2, #rows)
      assert.are.equal("Alpha", rows[1].Name)
      return assert.are.equal("2", rows[2].ID)
    end)
    it("honours quoted fields containing commas", function()
      local rows = dbc.parseCsv('ID,Name\n1,"Bread, Sliced"\n')
      return assert.are.equal("Bread, Sliced", rows[1].Name)
    end)
    it("honours doubled quotes inside a quoted field", function()
      local rows = dbc.parseCsv('ID,Name\n1,"The ""Big"" One"\n')
      return assert.are.equal('The "Big" One', rows[1].Name)
    end)
    it("skips blank lines", function()
      local rows = dbc.parseCsv("ID,Name\n\n1,Alpha\n\n")
      return assert.are.equal(1, #rows)
    end)
    return it("returns no header for empty text", function()
      local rows, header = dbc.parseCsv("")
      assert.are.same({ }, rows)
      return assert.is_nil(header)
    end)
  end)
  describe("toModel", function()
    it("produces a document the model validator accepts", function()
      local doc = dbc.toModel(tables(), {
        build = "1.60.1.70790"
      })
      local ok, errors = validate.validate(doc)
      assert.are.same({ }, (function()
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #errors do
          local e = errors[_index_0]
          _accum_0[_len_0] = e.path
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)())
      return assert.is_true(ok)
    end)
    it("names item classes from the ItemClass id", function()
      local doc = dbc.toModel(tables())
      local byId = { }
      local _list_0 = doc.items
      for _index_0 = 1, #_list_0 do
        local it = _list_0[_index_0]
        byId[it.id] = it
      end
      assert.are.equal("Consumable", byId[101].class)
      return assert.are.equal("Trade Goods", byId[102].class)
    end)
    it("keeps an unknown class id visible rather than calling it Unknown", function()
      local t = tables()
      t.item[1].ClassID = "99"
      local doc = dbc.toModel(t)
      return assert.are.equal("Class99", doc.items[1].class)
    end)
    it("drops an Item row with no ItemSparse row", function()
      local doc = dbc.toModel(tables())
      local ids
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = doc.items
        for _index_0 = 1, #_list_0 do
          local it = _list_0[_index_0]
          _accum_0[_len_0] = it.id
          _len_0 = _len_0 + 1
        end
        ids = _accum_0
      end
      return assert.are.same({
        101,
        102
      }, ids)
    end)
    it("converts the 0-based DBC effect index to the 1-based model", function()
      local doc = dbc.toModel(tables())
      return assert.are.equal(1, doc.spellEffects[1].index)
    end)
    it("maps the trigger type", function()
      local t = tables()
      t.itemEffect[1].TriggerType = "1"
      return assert.are.equal("equip", dbc.toModel(t).itemEffects[1].trigger)
    end)
    it("defaults an unknown trigger type to use", function()
      local t = tables()
      t.itemEffect[1].TriggerType = "77"
      return assert.are.equal("use", dbc.toModel(t).itemEffects[1].trigger)
    end)
    it("drops an effect whose item was not extracted", function()
      local t = tables()
      t.itemEffect[#t.itemEffect + 1] = {
        ParentItemID = "999",
        SpellID = "9001"
      }
      local doc = dbc.toModel(t)
      assert.are.equal(1, #doc.itemEffects)
      return assert.is_true((validate.validate(doc)))
    end)
    it("drops an effect whose spell was not extracted", function()
      local t = tables()
      t.itemEffect[#t.itemEffect + 1] = {
        ParentItemID = "102",
        SpellID = "7777"
      }
      return assert.are.equal(1, #dbc.toModel(t).itemEffects)
    end)
    it("names a spell with an empty Name_lang rather than emitting an empty string", function()
      local t = tables()
      t.spell[1].Name_lang = ""
      return assert.are.equal("Spell9001", dbc.toModel(t).spells[1].name)
    end)
    it("orders items and spells by id for determinism", function()
      local t = tables()
      t.item = {
        t.item[2],
        t.item[1],
        t.item[3]
      }
      local doc = dbc.toModel(t)
      return assert.are.same({
        101,
        102
      }, (function()
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = doc.items
        for _index_0 = 1, #_list_0 do
          local it = _list_0[_index_0]
          _accum_0[_len_0] = it.id
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)())
    end)
    it("marks the document as coming from the dbc source", function()
      return assert.are.equal("dbc", dbc.toModel(tables()).source)
    end)
    return it("handles entirely empty tables", function()
      local doc = dbc.toModel({ })
      assert.are.same({ }, doc.items)
      return assert.is_true((validate.validate(doc)))
    end)
  end)
  return describe("loadDir", function()
    it("reports every missing file at once", function()
      local loaded, reason = dbc.loadDir("/nonexistent-extract-dir")
      assert.is_nil(loaded)
      local _list_0 = dbc.REQUIRED
      for _index_0 = 1, #_list_0 do
        local _continue_0 = false
        repeat
          local spec = _list_0[_index_0]
          if spec.optional then
            _continue_0 = true
            break
          end
          assert.is_truthy(reason:find(spec.file, 1, true))
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
    end)
    return it("reports a missing required column", function()
      local dir = os.tmpname()
      os.remove(dir)
      os.execute("mkdir -p '" .. dir .. "'")
      local _list_0 = dbc.REQUIRED
      for _index_0 = 1, #_list_0 do
        local spec = _list_0[_index_0]
        local fh = io.open(dir .. "/" .. spec.file, "w")
        fh:write("WrongColumn\n1\n")
        fh:close()
      end
      local loaded, reason = dbc.loadDir(dir)
      os.execute("rm -rf '" .. dir .. "'")
      assert.is_nil(loaded)
      return assert.is_truthy(reason:find("has no column", 1, true))
    end)
  end)
end)
local periodicTables
periodicTables = function()
  local t = tables()
  t.spell[#t.spell + 1] = {
    ID = "9002",
    Name_lang = "Shadow Blight"
  }
  t.spell[#t.spell + 1] = {
    ID = "9003",
    Name_lang = "Venom Sting"
  }
  t.spell[#t.spell + 1] = {
    ID = "9004",
    Name_lang = "Renewing Light"
  }
  t.spellMisc = {
    {
      SpellID = "9002",
      DurationIndex = "21",
      SchoolMask = "32"
    },
    {
      SpellID = "9003",
      DurationIndex = "22",
      SchoolMask = "8"
    },
    {
      SpellID = "9004",
      DurationIndex = "22",
      SchoolMask = "2"
    }
  }
  t.spellDuration = {
    {
      ID = "21",
      Duration = "18000"
    },
    {
      ID = "22",
      Duration = "15000"
    }
  }
  t.spellEffect = {
    {
      SpellID = "9002",
      EffectIndex = "0",
      EffectAura = "3",
      EffectAuraPeriod = "3000",
      EffectBasePoints = "60",
      EffectBonusCoefficient = "0.156"
    },
    {
      SpellID = "9003",
      EffectIndex = "0",
      EffectAura = "PERIODIC_DAMAGE",
      EffectAuraPeriod = "3000",
      EffectBasePoints = "20",
      BonusCoefficientFromAP = "0.08"
    },
    {
      SpellID = "9004",
      EffectIndex = "0",
      EffectAura = "PERIODIC_HEAL",
      EffectAuraPeriod = "3000",
      EffectBasePoints = "80"
    }
  }
  return t
end
local periodicFor
periodicFor = function(doc, spellId)
  if not (spellId) then
    error("periodicFor needs a spellId")
  end
  local _accum_0 = { }
  local _len_0 = 1
  local _list_0 = (doc.spellPeriodic or { })
  for _index_0 = 1, #_list_0 do
    local r = _list_0[_index_0]
    if r.spellId == spellId then
      _accum_0[_len_0] = r
      _len_0 = _len_0 + 1
    end
  end
  return _accum_0
end
describe("itemtable dbc periodic damage", function()
  describe("isPeriodicDamage", function()
    it("accepts the raw integer aura id", function()
      assert.is_true(dbc.isPeriodicDamage("3"))
      return assert.is_true(dbc.isPeriodicDamage(3))
    end)
    it("accepts a resolved enum name, with or without the SPELL_AURA_ prefix", function()
      assert.is_true(dbc.isPeriodicDamage("PERIODIC_DAMAGE"))
      return assert.is_true(dbc.isPeriodicDamage("SPELL_AURA_PERIODIC_DAMAGE"))
    end)
    it("rejects periodic healing, which has the same mechanical shape", function()
      return assert.is_false(dbc.isPeriodicDamage("PERIODIC_HEAL"))
    end)
    it("rejects the percent-of-max variant, which the model cannot express", function()
      assert.is_false(dbc.isPeriodicDamage("89"))
      return assert.is_false(dbc.isPeriodicDamage("PERIODIC_DAMAGE_PERCENT"))
    end)
    return it("rejects nothing-at-all", function()
      assert.is_false(dbc.isPeriodicDamage(nil))
      return assert.is_false(dbc.isPeriodicDamage(""))
    end)
  end)
  describe("schoolOf", function()
    it("names a mask with exactly one bit set", function()
      assert.are.equal("SHADOW", dbc.schoolOf(32))
      return assert.are.equal("FIRE", dbc.schoolOf(4))
    end)
    it("returns nil for a multi-school mask rather than guessing one", function()
      return assert.is_nil(dbc.schoolOf(36))
    end)
    return it("returns nil for an absent or zero mask", function()
      assert.is_nil(dbc.schoolOf(nil))
      return assert.is_nil(dbc.schoolOf(0))
    end)
  end)
  describe("duration", function()
    it("resolves through SpellMisc.DurationIndex -> SpellDuration.Duration", function()
      local byId = { }
      local _list_0 = (dbc.toModel(periodicTables())).spells
      for _index_0 = 1, #_list_0 do
        local s = _list_0[_index_0]
        byId[s.id] = s
      end
      assert.are.equal(18000, byId[9002].duration)
      return assert.are.equal(15000, byId[9003].duration)
    end)
    it("leaves duration absent when SpellMisc was not extracted", function()
      local byId = { }
      local _list_0 = (dbc.toModel(tables())).spells
      for _index_0 = 1, #_list_0 do
        local s = _list_0[_index_0]
        byId[s.id] = s
      end
      return assert.is_nil(byId[9001].duration)
    end)
    it("treats DurationIndex 0 as no duration, not as a dangling reference", function()
      local t = periodicTables()
      t.spellMisc[1].DurationIndex = "0"
      local _doc, notes = dbc.toModel(t)
      return assert.are.same({ }, notes)
    end)
    return it("reports a dangling DurationIndex instead of defaulting it", function()
      local t = periodicTables()
      t.spellMisc[1].DurationIndex = "999"
      local doc, notes = dbc.toModel(t)
      assert.are.equal(1, #notes)
      assert.is_truthy(notes[1]:find("999", 1, true))
      local byId = { }
      local _list_0 = doc.spells
      for _index_0 = 1, #_list_0 do
        local s = _list_0[_index_0]
        byId[s.id] = s
      end
      return assert.is_nil(byId[9002].duration, "a dangling index must not become a duration")
    end)
  end)
  return describe("spellPeriodic", function()
    it("builds a row from a raw integer EffectAura", function()
      local doc = dbc.toModel(periodicTables())
      local row = periodicFor(doc, 9002)
      assert.are.equal(1, #row)
      assert.are.equal(3000, row[1].period)
      return assert.are.equal(60, row[1].baseAmount)
    end)
    it("builds a row from a resolved-name EffectAura", function()
      local doc = dbc.toModel(periodicTables())
      local row = periodicFor(doc, 9003)
      assert.are.equal(1, #row)
      return assert.are.equal(20, row[1].baseAmount)
    end)
    it("keeps the two scaling coefficients apart", function()
      local doc = dbc.toModel(periodicTables())
      local sp = periodicFor(doc, 9002)[1]
      local ap = periodicFor(doc, 9003)[1]
      assert.are.equal(0.156, sp.coefficient)
      assert.is_nil(sp.apCoefficient)
      assert.are.equal(0.08, ap.apCoefficient)
      return assert.is_nil(ap.coefficient)
    end)
    it("names the school from the spell's own mask", function()
      local doc = dbc.toModel(periodicTables())
      assert.are.equal("SHADOW", periodicFor(doc, 9002)[1].school)
      return assert.are.equal("NATURE", periodicFor(doc, 9003)[1].school)
    end)
    it("EXCLUDES a periodic heal", function()
      local doc = dbc.toModel(periodicTables())
      return assert.are.same({ }, periodicFor(doc, 9004))
    end)
    it("converts the 0-based DBC effect index to the 1-based model", function()
      local doc = dbc.toModel(periodicTables())
      local row = periodicFor(doc, 9002)
      return assert.are.equal(1, row[1].index)
    end)
    it("reports a periodic effect with no period instead of inventing one", function()
      local t = periodicTables()
      t.spellEffect[1].EffectAuraPeriod = nil
      local doc, notes = dbc.toModel(t)
      assert.are.same({ }, periodicFor(doc, 9002))
      assert.are.equal(1, #notes)
      return assert.is_truthy(notes[1]:find("EffectAuraPeriod", 1, true))
    end)
    it("reports a periodic effect with no base points", function()
      local t = periodicTables()
      t.spellEffect[1].EffectBasePoints = nil
      local doc, notes = dbc.toModel(t)
      assert.are.same({ }, periodicFor(doc, 9002))
      return assert.is_truthy(notes[1]:find("EffectBasePoints", 1, true))
    end)
    it("drops an effect whose spell was not extracted", function()
      local t = periodicTables()
      t.spellEffect[1].SpellID = "99999"
      local doc = dbc.toModel(t)
      assert.are.same({ }, periodicFor(doc, 99999))
      return assert.are.equal(1, #periodicFor(doc, 9003))
    end)
    it("omits the collection entirely when SpellMisc was not extracted", function()
      return assert.is_nil((dbc.toModel(tables())).spellPeriodic)
    end)
    it("orders rows by spell then effect index, for determinism", function()
      local t = periodicTables()
      t.spellEffect[#t.spellEffect + 1] = {
        SpellID = "9002",
        EffectIndex = "1",
        EffectAura = "3",
        EffectAuraPeriod = "4000",
        EffectBasePoints = "10"
      }
      t.spellEffect = {
        t.spellEffect[4],
        t.spellEffect[2],
        t.spellEffect[1],
        t.spellEffect[3]
      }
      local doc = dbc.toModel(t)
      local keys
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = doc.spellPeriodic
        for _index_0 = 1, #_list_0 do
          local r = _list_0[_index_0]
          _accum_0[_len_0] = ("%d.%d"):format(r.spellId, r.index)
          _len_0 = _len_0 + 1
        end
        keys = _accum_0
      end
      return assert.are.same({
        "9002.1",
        "9002.2",
        "9003.1"
      }, keys)
    end)
    it("produces a document the validator accepts", function()
      local doc = dbc.toModel(periodicTables())
      local ok, errors = validate.validate(doc)
      assert.are.same({ }, (function()
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #errors do
          local e = errors[_index_0]
          _accum_0[_len_0] = e.path
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)())
      return assert.is_true(ok)
    end)
    return it("treats SpellMisc and SpellDuration as optional in loadDir", function()
      local _list_0 = dbc.REQUIRED
      for _index_0 = 1, #_list_0 do
        local spec = _list_0[_index_0]
        if spec.file == "SpellMisc.csv" or spec.file == "SpellDuration.csv" then
          assert.is_true(spec.optional, spec.file .. " must be optional")
        end
      end
    end)
  end)
end)
local spellTables
spellTables = function()
  local t = tables()
  t.skillLineAbility = {
    {
      Spell = "9001",
      SkillLine = "8"
    },
    {
      Spell = "9001",
      SkillLine = "56"
    },
    {
      Spell = "9001",
      SkillLine = "777"
    }
  }
  t.spellLevels = {
    {
      SpellID = "9001",
      BaseLevel = "14"
    }
  }
  t.spellReagents = {
    {
      SpellID = "9001",
      Reagent_0 = "102",
      ReagentCount_0 = "2"
    }
  }
  return t
end
return describe("itemtable dbc spell tables", function()
  it("maps skill lines to class tokens", function()
    local doc = dbc.toModel(spellTables())
    local classes
    do
      local _accum_0 = { }
      local _len_0 = 1
      local _list_0 = doc.spellClass
      for _index_0 = 1, #_list_0 do
        local r = _list_0[_index_0]
        _accum_0[_len_0] = r.classFile
        _len_0 = _len_0 + 1
      end
      classes = _accum_0
    end
    return assert.are.same({
      "MAGE",
      "PRIEST"
    }, classes)
  end)
  it("drops an unrecognised skill line rather than inventing a class", function()
    local doc = dbc.toModel(spellTables())
    return assert.are.equal(2, #doc.spellClass)
  end)
  it("does not duplicate a spell/class pair", function()
    local t = spellTables()
    t.skillLineAbility[#t.skillLineAbility + 1] = {
      Spell = "9001",
      SkillLine = "8"
    }
    return assert.are.equal(2, #(dbc.toModel(t)).spellClass)
  end)
  it("records the learn level", function()
    return assert.are.equal(14, (dbc.toModel(spellTables())).spellLevels[1].learnLevel)
  end)
  it("records reagents with counts", function()
    local r = (dbc.toModel(spellTables())).spellReagents[1]
    assert.are.equal(102, r.itemId)
    return assert.are.equal(2, r.count)
  end)
  it("drops a reagent pointing at an item that was not extracted", function()
    local t = spellTables()
    t.spellReagents[1].Reagent_0 = "99999"
    return assert.are.same({ }, (dbc.toModel(t)).spellReagents)
  end)
  it("produces a document the validator accepts", function()
    local ok, errors = validate.validate(dbc.toModel(spellTables()))
    assert.are.same({ }, (function()
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #errors do
        local e = errors[_index_0]
        _accum_0[_len_0] = e.path
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end)())
    return assert.is_true(ok)
  end)
  it("omits the spell collections entirely for an item-only extraction", function()
    local doc = dbc.toModel(tables())
    assert.is_nil(doc.spellClass)
    return assert.is_true((validate.validate(doc)))
  end)
  return it("treats the spell CSVs as optional in loadDir", function()
    local _list_0 = dbc.REQUIRED
    for _index_0 = 1, #_list_0 do
      local spec = _list_0[_index_0]
      if spec.file == "SkillLineAbility.csv" or spec.file == "SpellLevels.csv" then
        assert.is_true(spec.optional == true, spec.file .. " must be optional")
      end
    end
  end)
end)
