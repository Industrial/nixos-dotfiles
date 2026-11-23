local M = { }
local REQUIRED = {
  {
    file = "Item.csv",
    key = "item",
    columns = {
      "ID"
    }
  },
  {
    file = "ItemSparse.csv",
    key = "itemSparse",
    columns = {
      "ID",
      "Display_lang"
    }
  },
  {
    file = "ItemEffect.csv",
    key = "itemEffect",
    columns = {
      "ParentItemID",
      "SpellID"
    }
  },
  {
    file = "Spell.csv",
    key = "spell",
    columns = {
      "ID"
    }
  },
  {
    file = "SpellEffect.csv",
    key = "spellEffect",
    columns = {
      "SpellID",
      "EffectIndex"
    }
  },
  {
    file = "SkillLineAbility.csv",
    key = "skillLineAbility",
    optional = true,
    columns = {
      "Spell",
      "SkillLine"
    }
  },
  {
    file = "SpellLevels.csv",
    key = "spellLevels",
    optional = true,
    columns = {
      "SpellID",
      "BaseLevel"
    }
  },
  {
    file = "SpellReagents.csv",
    key = "spellReagents",
    optional = true,
    columns = {
      "SpellID"
    }
  },
  {
    file = "SpellMisc.csv",
    key = "spellMisc",
    optional = true,
    columns = {
      "SpellID",
      "DurationIndex"
    }
  },
  {
    file = "SpellItemEnchantment.csv",
    key = "spellItemEnchantment",
    optional = true,
    columns = {
      "ID",
      "Name_lang"
    }
  },
  {
    file = "SpellDuration.csv",
    key = "spellDuration",
    optional = true,
    columns = {
      "ID",
      "Duration"
    }
  },
  {
    file = "ChrSpecialization.csv",
    key = "chrSpecialization",
    optional = true,
    columns = {
      "ID",
      "ClassID"
    }
  },
  {
    file = "TraitTree.csv",
    key = "traitTree",
    optional = true,
    columns = {
      "ID"
    }
  },
  {
    file = "TraitTreeLoadout.csv",
    key = "traitTreeLoadout",
    optional = true,
    columns = {
      "TraitTreeID",
      "ChrSpecializationID"
    }
  },
  {
    file = "TraitSubTree.csv",
    key = "traitSubTree",
    optional = true,
    columns = {
      "ID",
      "TraitTreeID"
    }
  },
  {
    file = "TraitNode.csv",
    key = "traitNode",
    optional = true,
    columns = {
      "ID",
      "TraitTreeID"
    }
  },
  {
    file = "TraitNodeEntry.csv",
    key = "traitNodeEntry",
    optional = true,
    columns = {
      "ID"
    }
  },
  {
    file = "TraitNodeXTraitNodeEntry.csv",
    key = "traitNodeXEntry",
    optional = true,
    columns = {
      "TraitNodeID",
      "TraitNodeEntryID"
    }
  },
  {
    file = "TraitDefinition.csv",
    key = "traitDefinition",
    optional = true,
    columns = {
      "ID"
    }
  }
}
M.REQUIRED = REQUIRED
local ITEM_CLASS = {
  [0] = "Consumable",
  [1] = "Container",
  [2] = "Weapon",
  [4] = "Armor",
  [5] = "Reagent",
  [6] = "Projectile",
  [7] = "Trade Goods",
  [9] = "Recipe",
  [11] = "Quiver",
  [12] = "Quest",
  [13] = "Key",
  [15] = "Miscellaneous",
  [16] = "Glyph"
}
M.ITEM_CLASS = ITEM_CLASS
local CHR_CLASS = {
  [1] = "WARRIOR",
  [2] = "PALADIN",
  [3] = "HUNTER",
  [4] = "ROGUE",
  [5] = "PRIEST",
  [6] = "DEATHKNIGHT",
  [7] = "SHAMAN",
  [8] = "MAGE",
  [9] = "WARLOCK",
  [10] = "MONK",
  [11] = "DRUID",
  [12] = "DEMONHUNTER",
  [13] = "EVOKER"
}
M.CHR_CLASS = CHR_CLASS
local CHR_ROLE = {
  [0] = "TANK",
  [1] = "HEALER",
  [2] = "DAMAGER",
  [3] = "DAMAGER"
}
M.CHR_ROLE = CHR_ROLE
local CHR_PRIMARY_STAT = {
  [0] = "STRENGTH",
  [1] = "AGILITY",
  [2] = "INTELLECT"
}
M.CHR_PRIMARY_STAT = CHR_PRIMARY_STAT
local TRIGGER = {
  [0] = "use",
  [1] = "equip",
  [2] = "proc"
}
M.TRIGGER = TRIGGER
local STAT = {
  [0] = "MANA",
  [1] = "HEALTH",
  [3] = "AGILITY",
  [4] = "STRENGTH",
  [5] = "INTELLECT",
  [6] = "SPIRIT",
  [7] = "STAMINA"
}
M.STAT = STAT
-- MOD_STAT (aura 29) and MOD_TOTAL_STAT_PERCENTAGE (137) number stats by the
-- UNIT-stat enum, not the item-stat one above: 0 Strength, 1 Agility,
-- 2 Stamina, 3 Intellect, 4 Spirit, -1 all of them. Reading an Elixir of
-- Agility (misc 1) through STAT made it a HEALTH elixir.
local UNIT_STAT = {
  [-1] = "ALL",
  [0] = "STRENGTH",
  [1] = "AGILITY",
  [2] = "STAMINA",
  [3] = "INTELLECT",
  [4] = "SPIRIT"
}
M.UNIT_STAT = UNIT_STAT
local UNIT_STAT_AURAS = { [29] = true, [137] = true }
local STAT_AURAS = {
  APPLY_AURA = true,
  MOD_STAT = true,
  MOD_TOTAL_STAT_PERCENTAGE = true
}
M.STAT_AURAS = STAT_AURAS
local AURA_PERIODIC_DAMAGE = 3
M.AURA_PERIODIC_DAMAGE = AURA_PERIODIC_DAMAGE
local PERIODIC_DAMAGE_AURAS = {
  [tostring(AURA_PERIODIC_DAMAGE)] = true,
  PERIODIC_DAMAGE = true,
  SPELL_AURA_PERIODIC_DAMAGE = true
}
M.PERIODIC_DAMAGE_AURAS = PERIODIC_DAMAGE_AURAS
-- FOREVER'S CLIENT TABLES CARRY NUMBERS. The rules speak names ("Food",
-- "PERIODIC_HEAL", "HEAL"), the vocabulary the fixtures were written in, so the
-- adapter names what it reads. Numbers are the client's own enums
-- (SpellAuraNames / SpellEffectNames / ItemSubClass for class 0).
--
-- A spell effect is named by its AURA when it has one, else by its EFFECT:
-- an instant potion is effect 10 (HEAL) with no aura, a drink is effect 6
-- (APPLY_AURA) carrying aura 85.
--
-- Food and drink in this client restore through MOD_REGEN (84) and
-- MOD_POWER_REGEN (85), not the PERIODIC_HEAL (8) / PERIODIC_ENERGIZE (24) the
-- fixtures model. They are the same thing to a player -- a restore over time
-- while seated -- so they carry the same names.
local AURA_NAME = {
  [3] = "PERIODIC_DAMAGE",
  [8] = "PERIODIC_HEAL",
  [13] = "MOD_DAMAGE_DONE",
  [22] = "MOD_RESISTANCE",
  [24] = "PERIODIC_ENERGIZE",
  [29] = "MOD_STAT",
  [84] = "PERIODIC_HEAL",
  [85] = "PERIODIC_ENERGIZE",
  [99] = "MOD_ATTACK_POWER",
  [124] = "MOD_RANGED_ATTACK_POWER",
  [137] = "MOD_TOTAL_STAT_PERCENTAGE",
  [161] = "MOD_HEALTH_REGEN_IN_COMBAT",
  [20] = "OBS_MOD_HEALTH",
  [21] = "OBS_MOD_POWER",
  [34] = "MOD_INCREASE_HEALTH",
  [69] = "SCHOOL_ABSORB"
}
M.AURA_NAME = AURA_NAME
local EFFECT_NAME = {
  [6] = "APPLY_AURA",
  [10] = "HEAL",
  [24] = "CREATE_ITEM",
  [28] = "SUMMON",
  [30] = "ENERGIZE",
  [54] = "ENCHANT_HELD_ITEM",
  [56] = "SUMMON"
}
M.EFFECT_NAME = EFFECT_NAME
-- ItemSubClass for class 0 (Consumable) in this client.
local CONSUMABLE_SUBCLASS = {
  [0] = "Explosives",
  [1] = "Potion",
  [2] = "Elixir",
  [3] = "Flask",
  [4] = "Scroll",
  [5] = "Food",
  [6] = "Item Enhancement",
  [7] = "Bandage",
  [8] = "Other"
}
M.CONSUMABLE_SUBCLASS = CONSUMABLE_SUBCLASS
--- The name a spell effect row goes by: its aura's, else its effect's, else
-- the raw value (an already-named CSV passes straight through).
M.effectName = function(row)
  local aura = tonumber(row.EffectAura)
  if aura and aura ~= 0 then
    return AURA_NAME[aura] or tostring(aura)
  end
  if row.EffectAura and row.EffectAura ~= "" and not aura then
    return row.EffectAura
  end
  local effect = tonumber(row.Effect)
  if effect and EFFECT_NAME[effect] then
    return EFFECT_NAME[effect]
  end
  return nil
end
M.isPeriodicDamage = function(aura)
  if not (aura ~= nil and aura ~= "") then
    return false
  end
  return PERIODIC_DAMAGE_AURAS[tostring(aura)] == true
end
local SCHOOL = {
  [1] = "PHYSICAL",
  [2] = "HOLY",
  [4] = "FIRE",
  [8] = "NATURE",
  [16] = "FROST",
  [32] = "SHADOW",
  [64] = "ARCANE"
}
M.SCHOOL = SCHOOL
M.schoolOf = function(mask)
  if not (mask and mask > 0) then
    return nil
  end
  return SCHOOL[mask]
end
local SKILL_LINE_CLASS = {
  [26] = "WARRIOR",
  [594] = "PALADIN",
  [50] = "HUNTER",
  [38] = "ROGUE",
  [56] = "PRIEST",
  [375] = "SHAMAN",
  [8] = "MAGE",
  [593] = "WARLOCK",
  [134] = "DRUID"
}
M.SKILL_LINE_CLASS = SKILL_LINE_CLASS
M.splitCsvLine = function(line)
  local fields = { }
  local i, n = 1, #line
  local current = { }
  local inQuotes = false
  while i <= n do
    local c = line:sub(i, i)
    if inQuotes then
      if c == '"' then
        if line:sub(i + 1, i + 1) == '"' then
          current[#current + 1] = '"'
          i = i + 1
        else
          inQuotes = false
        end
      else
        current[#current + 1] = c
      end
    elseif c == '"' then
      inQuotes = true
    elseif c == "," then
      fields[#fields + 1] = table.concat(current)
      current = { }
    else
      current[#current + 1] = c
    end
    i = i + 1
  end
  fields[#fields + 1] = table.concat(current)
  return fields
end
M.parseCsv = function(text)
  local rows, header = { }, nil
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    local _continue_0 = false
    repeat
      if line:match("^%s*$") then
        _continue_0 = true
        break
      end
      local fields = M.splitCsvLine(line)
      if not (header) then
        header = fields
        _continue_0 = true
        break
      end
      local row = { }
      for idx, name in ipairs(header) do
        row[name] = fields[idx]
      end
      rows[#rows + 1] = row
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return rows, header
end
local num
num = function(v)
  if v == nil or v == "" then
    return nil
  end
  return tonumber(v)
end
M.loadDir = function(dir)
  dir = dir:gsub("/$", "")
  local tables, problems = { }, { }
  for _index_0 = 1, #REQUIRED do
    local _continue_0 = false
    repeat
      local spec = REQUIRED[_index_0]
      local path = tostring(dir) .. "/" .. tostring(spec.file)
      local fh = io.open(path, "r")
      if not (fh) then
        if spec.optional then
          _continue_0 = true
          break
        end
        problems[#problems + 1] = "missing " .. tostring(spec.file)
        _continue_0 = true
        break
      end
      local text = fh:read("*a")
      fh:close()
      local rows, header = M.parseCsv(text)
      if not (header) then
        problems[#problems + 1] = tostring(spec.file) .. " is empty"
        _continue_0 = true
        break
      end
      local present = { }
      for _index_1 = 1, #header do
        local h = header[_index_1]
        present[h] = true
      end
      local _list_0 = spec.columns
      for _index_1 = 1, #_list_0 do
        local column = _list_0[_index_1]
        if not (present[column]) then
          problems[#problems + 1] = tostring(spec.file) .. " has no column " .. tostring(column)
        end
      end
      tables[spec.key] = rows
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  if #problems > 0 then
    return nil, table.concat(problems, "; ")
  end
  return tables
end
M.toModel = function(tables, opts)
  if opts == nil then
    opts = { }
  end
  local notes = { }
  local report
  report = function(fmt, ...)
    notes[#notes + 1] = fmt:format(...)
  end
  local doc = {
    schemaVersion = 1,
    build = opts.build or "unknown",
    source = "dbc",
    items = { },
    spells = { },
    itemEffects = { },
    spellEffects = { }
  }
  local sparse = { }
  local _list_0 = (tables.itemSparse or { })
  for _index_0 = 1, #_list_0 do
    local row = _list_0[_index_0]
    local id = num(row.ID)
    if id then
      sparse[id] = row
    end
  end
  local _list_1 = (tables.item or { })
  for _index_0 = 1, #_list_1 do
    local _continue_0 = false
    repeat
      local row = _list_1[_index_0]
      local id = num(row.ID)
      if not (id) then
        _continue_0 = true
        break
      end
      local s = sparse[id]
      if not (s and s.Display_lang and s.Display_lang ~= "") then
        _continue_0 = true
        break
      end
      local classId = num(row.ClassID) or -1
      doc.items[#doc.items + 1] = {
        id = id,
        name = s.Display_lang,
        class = ITEM_CLASS[classId] or ("Class%d"):format(classId),
        subclass = (classId == 0 and CONSUMABLE_SUBCLASS[num(row.SubclassID) or -1]) or ((row.SubclassID and row.SubclassID ~= "") and ("Subclass%s"):format(row.SubclassID) or nil),
        quality = num(s.OverallQualityID),
        ilvl = num(s.ItemLevel),
        stackable = num(s.Stackable)
      }
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  table.sort(doc.items, function(a, b)
    return a.id < b.id
  end)
  local known = { }
  local _list_2 = doc.items
  for _index_0 = 1, #_list_2 do
    local it = _list_2[_index_0]
    known[it.id] = true
  end
  local durationById, schoolById = { }, { }
  if tables.spellMisc then
    local byIndex = { }
    local _list_3 = (tables.spellDuration or { })
    for _index_0 = 1, #_list_3 do
      local row = _list_3[_index_0]
      local durationId = num(row.ID)
      if durationId then
        byIndex[durationId] = num(row.Duration)
      end
    end
    local _list_4 = tables.spellMisc
    for _index_0 = 1, #_list_4 do
      local _continue_0 = false
      repeat
        local row = _list_4[_index_0]
        local spellId = num(row.SpellID)
        if not (spellId) then
          _continue_0 = true
          break
        end
        schoolById[spellId] = M.schoolOf(num(row.SchoolMask))
        local durationIndex = num(row.DurationIndex)
        if not (durationIndex and durationIndex > 0) then
          _continue_0 = true
          break
        end
        local resolved = byIndex[durationIndex]
        if resolved == nil then
          report("SpellMisc: spell %d references unknown DurationIndex %d", spellId, durationIndex)
        else
          durationById[spellId] = resolved
        end
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
  end
  local _list_3 = (tables.spell or { })
  for _index_0 = 1, #_list_3 do
    local _continue_0 = false
    repeat
      local row = _list_3[_index_0]
      local id = num(row.ID)
      if not (id) then
        _continue_0 = true
        break
      end
      doc.spells[#doc.spells + 1] = {
        id = id,
        name = (row.Name_lang ~= "" and row.Name_lang) or ("Spell%d"):format(id),
        duration = durationById[id]
      }
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  table.sort(doc.spells, function(a, b)
    return a.id < b.id
  end)
  local spellKnown = { }
  local _list_4 = doc.spells
  for _index_0 = 1, #_list_4 do
    local sp = _list_4[_index_0]
    spellKnown[sp.id] = true
  end
  local _list_5 = (tables.itemEffect or { })
  for _index_0 = 1, #_list_5 do
    local _continue_0 = false
    repeat
      local row = _list_5[_index_0]
      local itemId, spellId = num(row.ParentItemID), num(row.SpellID)
      if not (itemId and spellId and known[itemId] and spellKnown[spellId]) then
        _continue_0 = true
        break
      end
      doc.itemEffects[#doc.itemEffects + 1] = {
        itemId = itemId,
        spellId = spellId,
        trigger = TRIGGER[num(row.TriggerType) or -1] or "use",
        charges = num(row.Charges)
      }
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  local _list_6 = (tables.spellEffect or { })
  -- WEAPON BUFFS. An ENCHANT_HELD_ITEM effect's misc value is the enchantment's
  -- id; its kind and strength live in SpellItemEnchantment, named by the client
  -- itself ("Sharpened +2", "Weighted +3", "Lesser Wizard Oil", "Minor Mana Oil").
  local enchants = { }
  for _, row in ipairs(tables.spellItemEnchantment or { }) do
    local id = num(row.ID)
    if id then enchants[id] = row end
  end
  local function enchantKind(name)
    name = name or ""
    if name:match("^Sharpened") then return "SHARPEN" end
    if name:match("^Weighted") then return "WEIGHT" end
    if name:match("Wizard Oil$") then return "WIZARD_OIL" end
    if name:match("Mana Oil$") then return "MANA_OIL" end
    return "OTHER"
  end
  -- One effect row, named and with its stat resolved.
  local function effectRecord(row, spellId, index)
    local aura = M.effectName(row)
    local misc = num(row.EffectMiscValue_0)
    local statType = (aura and STAT_AURAS[aura] and misc) and STAT[misc] or nil
    if UNIT_STAT_AURAS[num(row.EffectAura) or -1] and misc then
      statType = UNIT_STAT[misc]
    end
    -- Armor is a resistance in the client: MOD_RESISTANCE with the
    -- physical school (mask 1). Every other mask is a magic resistance.
    if aura == "MOD_RESISTANCE" and misc == 1 then
      statType = "ARMOR"
    end
    local amount, kind = num(row.EffectBasePoints), nil
    if aura == "ENCHANT_HELD_ITEM" and misc and enchants[misc] then
      kind = enchantKind(enchants[misc].Name_lang)
      -- The effect's own base points are the enchant's DURATION here; its
      -- strength is the enchantment's first effect value.
      amount = num(enchants[misc].EffectPointsMin_0) or amount
    end
    return {
      spellId = spellId,
      index = index,
      auraType = aura,
      statType = statType,
      amount = amount,
      miscValue = misc,
      enchantKind = kind
    }
  end
  -- FOLLOWING TRIGGERS. Forever's food is a spell that triggers others:
  -- "Nutritious Food" fires the classic "Food" spell (Effect 64, TRIGGER_SPELL)
  -- for the restore, and a "Well Fed" buff every tick (aura 227, a periodic
  -- trigger) for the stats. Read on their own, its effects say nothing a rule
  -- can match. So a trigger's target effects also count as effects of the
  -- triggering spell, one level deep, numbered from 101 so they never collide
  -- with the spell's own indexes.
  local TRIGGERS_EFFECT = { [64] = true, [142] = true }
  local TRIGGERS_AURA = { [23] = true, [226] = true, [227] = true, [42] = true }
  local effectsOf = { }
  for _, row in ipairs(_list_6) do
    local sid = num(row.SpellID)
    if sid then
      effectsOf[sid] = effectsOf[sid] or { }
      table.insert(effectsOf[sid], row)
    end
  end
  for _index_0 = 1, #_list_6 do
    local _continue_0 = false
    repeat
      local row = _list_6[_index_0]
      local spellId, index = num(row.SpellID), num(row.EffectIndex)
      if not (spellId and index and spellKnown[spellId]) then
        _continue_0 = true
        break
      end
      doc.spellEffects[#doc.spellEffects + 1] = effectRecord(row, spellId, index + 1)
      local trigger = num(row.EffectTriggerSpell)
      if trigger and trigger ~= 0 and trigger ~= spellId
         and (TRIGGERS_EFFECT[num(row.Effect) or -1] or TRIGGERS_AURA[num(row.EffectAura) or -1]) then
        -- One-shot triggers (the restore) land at 101+, periodic ones (the
        -- Well Fed stack) at 201+, so a rule can tell a drink's mana from a
        -- mana-regen Well Fed buff even though both are aura 85.
        local base = TRIGGERS_AURA[num(row.EffectAura) or -1] and 200 or 100
        for k, t in ipairs(effectsOf[trigger] or { }) do
          local rec = effectRecord(t, spellId, base + (index * 10) + k)
          if rec.auraType then
            doc.spellEffects[#doc.spellEffects + 1] = rec
          end
        end
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  if tables.skillLineAbility then
    doc.spellClass = { }
    local seen = { }
    local _list_7 = tables.skillLineAbility
    for _index_0 = 1, #_list_7 do
      local _continue_0 = false
      repeat
        local row = _list_7[_index_0]
        local spellId, line = num(row.Spell), num(row.SkillLine)
        if not (spellId and line and spellKnown[spellId]) then
          _continue_0 = true
          break
        end
        local classFile = SKILL_LINE_CLASS[line]
        if not (classFile) then
          _continue_0 = true
          break
        end
        local key = tostring(spellId) .. "/" .. tostring(classFile)
        if seen[key] then
          _continue_0 = true
          break
        end
        seen[key] = true
        doc.spellClass[#doc.spellClass + 1] = {
          spellId = spellId,
          classFile = classFile
        }
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    table.sort(doc.spellClass, function(a, b)
      if a.spellId ~= b.spellId then
        return a.spellId < b.spellId
      end
      return a.classFile < b.classFile
    end)
  end
  if tables.spellLevels then
    doc.spellLevels = { }
    local seenLevel = { }
    local _list_7 = tables.spellLevels
    for _index_0 = 1, #_list_7 do
      local _continue_0 = false
      repeat
        local row = _list_7[_index_0]
        local spellId, level = num(row.SpellID), num(row.BaseLevel)
        if not (spellId and level and spellKnown[spellId] and not seenLevel[spellId]) then
          _continue_0 = true
          break
        end
        seenLevel[spellId] = true
        doc.spellLevels[#doc.spellLevels + 1] = {
          spellId = spellId,
          learnLevel = level
        }
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    table.sort(doc.spellLevels, function(a, b)
      return a.spellId < b.spellId
    end)
  end
  if tables.spellReagents then
    doc.spellReagents = { }
    local _list_7 = tables.spellReagents
    for _index_0 = 1, #_list_7 do
      local _continue_0 = false
      repeat
        local row = _list_7[_index_0]
        local spellId = num(row.SpellID)
        if not (spellId and spellKnown[spellId]) then
          _continue_0 = true
          break
        end
        for n = 0, 7 do
          local _continue_1 = false
          repeat
            local itemId = num(row["Reagent_" .. tostring(n)])
            if not (itemId and itemId > 0 and known[itemId]) then
              _continue_1 = true
              break
            end
            doc.spellReagents[#doc.spellReagents + 1] = {
              spellId = spellId,
              itemId = itemId,
              count = num(row["ReagentCount_" .. tostring(n)]) or 1
            }
            _continue_1 = true
          until true
          if not _continue_1 then
            break
          end
        end
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    table.sort(doc.spellReagents, function(a, b)
      if a.spellId ~= b.spellId then
        return a.spellId < b.spellId
      end
      return a.itemId < b.itemId
    end)
  end
  if tables.chrSpecialization then
    doc.specs = { }
    local _list_7 = tables.chrSpecialization
    for _index_0 = 1, #_list_7 do
      local _continue_0 = false
      repeat
        local row = _list_7[_index_0]
        local specId, classId = num(row.ID), num(row.ClassID)
        if not (specId and classId) then
          _continue_0 = true
          break
        end
        doc.specs[#doc.specs + 1] = {
          specId = specId,
          classFile = CHR_CLASS[classId] or ("Class%d"):format(classId),
          name = row.Name_lang or ("Spec%d"):format(specId),
          role = CHR_ROLE[num(row.Role) or -1],
          primaryStat = CHR_PRIMARY_STAT[num(row.PrimaryStatPriority) or -1]
        }
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    table.sort(doc.specs, function(a, b)
      return a.specId < b.specId
    end)
  end
  if tables.traitTree then
    doc.talentTrees = { }
    local specOfTree, classOfSpec = { }, { }
    local _list_7 = (doc.specs or { })
    for _index_0 = 1, #_list_7 do
      local spec = _list_7[_index_0]
      classOfSpec[spec.specId] = spec.classFile
    end
    local _list_8 = (tables.traitTreeLoadout or { })
    for _index_0 = 1, #_list_8 do
      local _continue_0 = false
      repeat
        local row = _list_8[_index_0]
        local treeId, specId = num(row.TraitTreeID), num(row.ChrSpecializationID)
        if not (treeId and specId) then
          _continue_0 = true
          break
        end
        local _update_0 = treeId
        specOfTree[_update_0] = specOfTree[_update_0] or specId
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    local _list_9 = tables.traitTree
    for _index_0 = 1, #_list_9 do
      local _continue_0 = false
      repeat
        local row = _list_9[_index_0]
        local treeId = num(row.ID)
        if not (treeId) then
          _continue_0 = true
          break
        end
        local specId = specOfTree[treeId]
        doc.talentTrees[#doc.talentTrees + 1] = {
          treeId = treeId,
          specId = specId,
          kind = specId and "spec" or "class"
        }
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    local _list_10 = (tables.traitSubTree or { })
    for _index_0 = 1, #_list_10 do
      local _continue_0 = false
      repeat
        local row = _list_10[_index_0]
        local subId, parent = num(row.ID), num(row.TraitTreeID)
        if not (subId and parent) then
          _continue_0 = true
          break
        end
        doc.talentTrees[#doc.talentTrees + 1] = {
          treeId = subId,
          specId = specOfTree[parent],
          kind = "hero"
        }
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    table.sort(doc.talentTrees, function(a, b)
      return a.treeId < b.treeId
    end)
  end
  if tables.traitNode then
    doc.talentNodes = { }
    local _list_7 = tables.traitNode
    for _index_0 = 1, #_list_7 do
      local _continue_0 = false
      repeat
        local row = _list_7[_index_0]
        local nodeId, treeId = num(row.ID), num(row.TraitTreeID)
        if not (nodeId and treeId) then
          _continue_0 = true
          break
        end
        doc.talentNodes[#doc.talentNodes + 1] = {
          nodeId = nodeId,
          treeId = treeId,
          type = row.Type and ("Type%s"):format(row.Type or nil),
          maxRanks = num(row.MaxRanks) or 1
        }
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    table.sort(doc.talentNodes, function(a, b)
      return a.nodeId < b.nodeId
    end)
  end
  if tables.traitNodeEntry then
    doc.talentEntries = { }
    local spellOfDefinition = { }
    local _list_7 = (tables.traitDefinition or { })
    for _index_0 = 1, #_list_7 do
      local _continue_0 = false
      repeat
        local row = _list_7[_index_0]
        local defId, spellId = num(row.ID), num(row.SpellID)
        if not (defId and spellId and spellId > 0) then
          _continue_0 = true
          break
        end
        spellOfDefinition[defId] = spellId
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    local nodeOfEntry = { }
    local _list_8 = (tables.traitNodeXEntry or { })
    for _index_0 = 1, #_list_8 do
      local _continue_0 = false
      repeat
        local row = _list_8[_index_0]
        local nodeId, entryId = num(row.TraitNodeID), num(row.TraitNodeEntryID)
        if not (nodeId and entryId) then
          _continue_0 = true
          break
        end
        local _update_0 = entryId
        nodeOfEntry[_update_0] = nodeOfEntry[_update_0] or nodeId
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    local _list_9 = tables.traitNodeEntry
    for _index_0 = 1, #_list_9 do
      local _continue_0 = false
      repeat
        local row = _list_9[_index_0]
        local entryId = num(row.ID)
        if not (entryId) then
          _continue_0 = true
          break
        end
        local nodeId = nodeOfEntry[entryId]
        if not (nodeId) then
          _continue_0 = true
          break
        end
        local defId = num(row.TraitDefinitionID)
        doc.talentEntries[#doc.talentEntries + 1] = {
          entryId = entryId,
          nodeId = nodeId,
          spellId = defId and spellOfDefinition[defId] or nil,
          definitionId = defId
        }
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    table.sort(doc.talentEntries, function(a, b)
      return a.entryId < b.entryId
    end)
  end
  if tables.spellMisc then
    doc.spellPeriodic = { }
    local _list_7 = (tables.spellEffect or { })
    for _index_0 = 1, #_list_7 do
      local _continue_0 = false
      repeat
        local row = _list_7[_index_0]
        local spellId, index = num(row.SpellID), num(row.EffectIndex)
        if not (spellId and index and spellKnown[spellId]) then
          _continue_0 = true
          break
        end
        if not (M.isPeriodicDamage(row.EffectAura)) then
          _continue_0 = true
          break
        end
        local period = num(row.EffectAuraPeriod)
        local amount = num(row.EffectBasePoints)
        if not (period and period > 0) then
          report("SpellEffect: spell %d effect %d is periodic damage with no EffectAuraPeriod", spellId, index + 1)
          _continue_0 = true
          break
        end
        if not (amount) then
          report("SpellEffect: spell %d effect %d is periodic damage with no EffectBasePoints", spellId, index + 1)
          _continue_0 = true
          break
        end
        doc.spellPeriodic[#doc.spellPeriodic + 1] = {
          spellId = spellId,
          index = index + 1,
          period = period,
          baseAmount = amount,
          coefficient = num(row.EffectBonusCoefficient),
          apCoefficient = num(row.BonusCoefficientFromAP),
          school = schoolById[spellId]
        }
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    table.sort(doc.spellPeriodic, function(a, b)
      if a.spellId ~= b.spellId then
        return a.spellId < b.spellId
      end
      return a.index < b.index
    end)
  end
  return doc, notes
end
return M
