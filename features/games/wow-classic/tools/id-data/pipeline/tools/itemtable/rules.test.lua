local rules = dofile("tools/itemtable/rules/consumable.lua")
local spellRules = dofile("tools/itemtable/rules/spell.lua")
local talentRules = dofile("tools/itemtable/rules/talent.lua")
local talentFixtures
talentFixtures = function()
  return dofile("tools/itemtable/fixtures.lua")
end
local RULE_FILES = {
  "tools/itemtable/rules/consumable.lua",
  "tools/itemtable/rules/spell.lua",
  "tools/itemtable/rules/talent.lua"
}
local referencedSets
referencedSets = function(prefixes)
  if prefixes == nil then
    prefixes = "Consumable|Tradeskill"
  end
  local cmd = ([[grep -rhE '^[^-]*"(%s)[A-Za-z0-9. -]*"' ../../../Interface/AddOns/idUpkeep/ --include='*.lua' --exclude-dir=tests --exclude-dir=Libs 2>/dev/null | grep -oE '"(%s)[A-Za-z0-9. -]*"']]):format(prefixes, prefixes)
  local handle = io.popen(cmd)
  if not (handle) then
    return nil
  end
  local seen = { }
  for line in handle:lines() do
    local _continue_0 = false
    repeat
      local name = line:gsub('"', '')
      if name == "Consumables" then
        _continue_0 = true
        break
      end
      if name == "Spells" then
        _continue_0 = true
        break
      end
      if not (name:find("%.")) then
        _continue_0 = true
        break
      end
      seen[name] = true
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  handle:close()
  return seen
end
describe("itemtable rules", function()
  describe("coverage of what the addon asks for", function()
    it("has a rule for every set name referenced by idUpkeep", function()
      local referenced = referencedSets()
      assert.is_not_nil(referenced, "could not scan idUpkeep for set names")
      local missing = { }
      for name in pairs(referenced) do
        if not (rules.sets[name]) then
          missing[#missing + 1] = name
        end
      end
      table.sort(missing)
      return assert.are.same({ }, missing, "these set names are used by idUpkeep but have no rule: " .. table.concat(missing, ", "))
    end)
    it("found a non-trivial number of set names to check", function()
      local count = 0
      for _ in pairs(referencedSets()) do
        count = count + 1
      end
      return assert.is_true(count >= 30, "expected the idUpkeep scan to find the ~40 known sets, got " .. count)
    end)
    it("has a rule for every TALENT set name referenced by idUpkeep", function()
      local referenced = referencedSets("Talent")
      assert.is_not_nil(referenced, "could not scan idUpkeep for talent set names")
      local talentSets = talentRules.setsFor(talentFixtures())
      local missing = { }
      for name in pairs(referenced) do
        local _continue_0 = false
        repeat
          if talentSets[name] then
            _continue_0 = true
            break
          end
          if name:match("^Talent%.Spec%.") and name:find("%.") then
            _continue_0 = true
            break
          end
          missing[#missing + 1] = name
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      table.sort(missing)
      return assert.are.same({ }, missing, "these talent set names are used by idUpkeep but have no rule: " .. table.concat(missing, ", "))
    end)
    it("has a rule for every SPELL set name referenced by idUpkeep", function()
      local referenced = referencedSets("Spell")
      assert.is_not_nil(referenced, "could not scan idUpkeep for spell set names")
      local missing = { }
      for name in pairs(referenced) do
        local _continue_0 = false
        repeat
          if spellRules.sets[name] then
            _continue_0 = true
            break
          end
          if name:match("^Spell%.Spec%.") then
            _continue_0 = true
            break
          end
          missing[#missing + 1] = name
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      table.sort(missing)
      return assert.are.same({ }, missing, "these spell set names are used by idUpkeep but have no rule: " .. table.concat(missing, ", "))
    end)
    it("found the spell sets the buttons rely on", function()
      local referenced = referencedSets("Spell")
      local count = 0
      for _ in pairs(referenced) do
        count = count + 1
      end
      return assert.is_true(count >= 3, "expected the idUpkeep scan to find the spell sets, got " .. count)
    end)
    return it("defines every rule as either a predicate or a declared gap", function()
      local bad = { }
      local talentSets = talentRules.setsFor(talentFixtures())
      local _list_0 = {
        rules.sets,
        spellRules.sets,
        talentSets
      }
      for _index_0 = 1, #_list_0 do
        local table_ = _list_0[_index_0]
        for name, rule in pairs(table_) do
          local ok = type(rule.predicate) == "function" or type(rule.unsupported) == "string"
          if not (ok) then
            bad[#bad + 1] = name
          end
        end
      end
      table.sort(bad)
      return assert.are.same({ }, bad)
    end)
  end)
  describe("no hand-written item lists", function()
    return it("contains no literal item id in any rule file", function()
      local offenders = { }
      for _index_0 = 1, #RULE_FILES do
        local path = RULE_FILES[_index_0]
        local fh = io.open(path, "r")
        assert.is_not_nil(fh, "cannot open " .. path)
        local lineNo = 0
        for line in fh:lines() do
          lineNo = lineNo + 1
          local code = line:gsub("%-%-.*$", "")
          local isNamedConstant = code:match("^%s*local%s+[A-Z][A-Z0-9_]*%s*=") or code:match("^%s*[A-Z][A-Z0-9_]*%s*=" or code:match("^%s*M%.[A-Z][A-Z0-9_]*%s*="))
          if not isNamedConstant and code:find("%f[%d]%d%d%d%d+%f[%D]") then
            offenders[#offenders + 1] = ("%s:%d"):format(path, lineNo)
          end
        end
        fh:close()
      end
      return assert.are.same({ }, offenders, "literal item ids found: " .. table.concat(offenders, ", "))
    end)
  end)
  describe("overrides", function()
    it("is empty", function()
      return assert.are.same({ }, rules.overrides)
    end)
    return it("would require a reason on every entry", function()
      for id, entry in pairs(rules.overrides) do
        assert.is_string(entry.reason, ("override for %s has no reason"):format(tostring(id)))
      end
    end)
  end)
  describe("scope", function()
    return it("claims only Consumable-class items", function()
      assert.is_true(rules.scope({
        class = "Consumable"
      }))
      assert.is_false(rules.scope({
        class = "Trade Goods"
      }))
      return assert.is_false(rules.scope({
        class = "Weapon"
      }))
    end)
  end)
  return describe("exclusions", function()
    return it("each carry a reason and a matcher", function()
      assert.is_true(#rules.exclusions > 0)
      local _list_0 = rules.exclusions
      for _index_0 = 1, #_list_0 do
        local exclusion = _list_0[_index_0]
        assert.is_string(exclusion.reason)
        assert.are.equal("function", type(exclusion.match))
      end
    end)
  end)
end)
local classify = dofile("tools/itemtable/classify.lua")
local dbcSource = dofile("tools/itemtable/sources/dbc.lua")
local DOT_SETS = {
  "Spell.DoT.Amount",
  "Spell.DoT.Period",
  "Spell.DoT.Duration",
  "Spell.DoT.Coefficient",
  "Spell.DoT.ApCoefficient",
  "Spell.DoT.School"
}
local dotSets
dotSets = function(doc)
  if doc == nil then
    doc = dofile("tools/itemtable/fixtures.lua")
  end
  return (classify.run(doc, spellRules.forDocument(doc))).sets
end
return describe("itemtable spell DoT rules", function()
  it("declares all six sets, because one number per entry needs six of them", function()
    local sets = dotSets()
    for _index_0 = 1, #DOT_SETS do
      local name = DOT_SETS[_index_0]
      assert.is_not_nil(sets[name], name .. " is missing")
    end
  end)
  it("sums the per-tick amount across a spell's periodic rows", function()
    assert.are.equal(42, dotSets()["Spell.DoT.Amount"][92011])
    return assert.are.equal(60, dotSets()["Spell.DoT.Amount"][92007])
  end)
  it("sums the spell-power coefficient the same way", function()
    return assert.are.equal(0.11, dotSets()["Spell.DoT.Coefficient"][92011])
  end)
  it("keeps the spell-power and attack-power coefficients apart", function()
    local sets = dotSets()
    assert.are.equal(0.156, sets["Spell.DoT.Coefficient"][92007])
    assert.are.equal(0, sets["Spell.DoT.ApCoefficient"][92007])
    assert.are.equal(0.08, sets["Spell.DoT.ApCoefficient"][92008])
    return assert.are.equal(0, sets["Spell.DoT.Coefficient"][92008])
  end)
  it("publishes a zero coefficient rather than withholding the entry", function()
    local sets = dotSets()
    assert.is_not_nil(sets["Spell.DoT.ApCoefficient"][92007])
    return assert.is_not_nil(sets["Spell.DoT.Coefficient"][92008])
  end)
  it("does not assume a fixed tick interval", function()
    local sets = dotSets()
    assert.are.equal(3000, sets["Spell.DoT.Period"][92007])
    return assert.are.equal(4000, sets["Spell.DoT.Period"][92009])
  end)
  it("takes duration from the aura's own duration, not from a periodic row", function()
    return assert.are.equal(18000, dotSets()["Spell.DoT.Duration"][92007])
  end)
  it("publishes the school as the client's own mask", function()
    local sets = dotSets()
    assert.are.equal(32, sets["Spell.DoT.School"][92007])
    assert.are.equal(8, sets["Spell.DoT.School"][92008])
    return assert.are.equal(4, sets["Spell.DoT.School"][92009])
  end)
  it("agrees with the DBC adapter about school masks, in both directions", function()
    for mask, name in pairs(dbcSource.SCHOOL) do
      assert.are.equal(mask, spellRules.SCHOOL_MASK[name], ("SCHOOL_MASK[%s] disagrees with dbc.SCHOOL[%d]"):format(name, mask))
    end
    for name, mask in pairs(spellRules.SCHOOL_MASK) do
      assert.are.equal(name, dbcSource.SCHOOL[mask])
    end
  end)
  it("leaves the periodic HEAL out of every DoT set", function()
    local sets = dotSets()
    for _index_0 = 1, #DOT_SETS do
      local name = DOT_SETS[_index_0]
      assert.is_nil(sets[name][92010], name .. " must not contain the periodic heal")
    end
  end)
  describe("an incomplete descriptor", function()
    it("matches no set when the aura has no duration", function()
      local doc = dofile("tools/itemtable/fixtures.lua")
      local _list_0 = doc.spells
      for _index_0 = 1, #_list_0 do
        local spell = _list_0[_index_0]
        if spell.id == 92007 then
          spell.duration = nil
        end
      end
      local sets = dotSets(doc)
      for _index_0 = 1, #DOT_SETS do
        local name = DOT_SETS[_index_0]
        assert.is_nil(sets[name][92007], name .. " should have declined")
      end
    end)
    it("matches no set when the rows disagree about the tick interval", function()
      local doc = dofile("tools/itemtable/fixtures.lua")
      local _list_0 = doc.spellPeriodic
      for _index_0 = 1, #_list_0 do
        local row = _list_0[_index_0]
        if row.spellId == 92011 and row.index == 2 then
          row.period = 5000
        end
      end
      local sets = dotSets(doc)
      for _index_0 = 1, #DOT_SETS do
        local name = DOT_SETS[_index_0]
        assert.is_nil(sets[name][92011], name .. " should decline rather than sum amounts that tick at different rates")
      end
    end)
    return it("makes such a spell visible as unclassified rather than silently absent", function()
      local doc = dofile("tools/itemtable/fixtures.lua")
      local _list_0 = doc.spells
      for _index_0 = 1, #_list_0 do
        local spell = _list_0[_index_0]
        if spell.id == 92007 then
          spell.duration = nil
        end
      end
      local result = classify.run(doc, spellRules.forDocument(doc))
      return assert.is_true((#(function()
        local _accum_0 = { }
        local _len_0 = 1
        local _list_1 = result.unclassified
        for _index_0 = 1, #_list_1 do
          local id = _list_1[_index_0]
          if id == 92007 then
            _accum_0[_len_0] = id
            _len_0 = _len_0 + 1
          end
        end
        return _accum_0
      end)()) == 1, "an incomplete DoT must be listed, not quietly dropped")
    end)
  end)
  return it("contains no literal spell id, same rule as the item side", function()
    local fh = assert(io.open("tools/itemtable/rules/spell.lua", "r"))
    local offenders = { }
    local lineNo = 0
    for line in fh:lines() do
      lineNo = lineNo + 1
      local code = line:gsub("%-%-.*$", "")
      local isNamedConstant = code:match("^%s*local%s+[A-Z][A-Z0-9_]*%s*=") or code:match("^%s*[A-Z][A-Z0-9_]*%s*=" or code:match("^%s*M%.[A-Z][A-Z0-9_]*%s*="))
      if not isNamedConstant and code:find("%f[%d]%d%d%d%d+%f[%D]") then
        offenders[#offenders + 1] = tostring(lineNo)
      end
    end
    fh:close()
    return assert.are.same({ }, offenders)
  end)
end)
