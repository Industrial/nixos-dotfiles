-- Turns Forever's client tables (as fetch.sh downloads them) into the columns
-- idAutomation's item-table pipeline reads (tools/dbc/tables.conf).
--
--   lua normalize.lua <raw dir> <out dir>
--
-- Forever runs on the modern client, whose tables moved three things the
-- pipeline was written against:
--   ItemEffect.ParentItemID       -> a link table, ItemXItemEffect (ItemID, ItemEffectID)
--   Spell.Name_lang               -> its own table, SpellName (ID, Name_lang)
--   SpellEffect.EffectBasePoints  -> EffectBasePointsF (same value, as a float)
-- This is the "wrapper" tools/dbc/README.md asks for: the CSVs are joined by a
-- script, never hand-edited. Every other table is copied unchanged.
--
-- It also FLATTENS NEWLINES inside quoted fields (spell and item descriptions
-- have them). The pipeline's own parser splits on newlines before it reads
-- quotes, so a description with a line break would cut its row in two and
-- drop the rest of that row's columns -- an item silently missing.
local raw, out = arg[1], arg[2]
assert(raw and out, "usage: lua normalize.lua <raw dir> <out dir>")

-- RFC 4180: quoted fields may hold commas, doubled quotes and newlines.
local function parse(text)
  local rows, header, field, record, i, n = {}, nil, {}, {}, 1, #text
  local function endField() record[#record + 1] = table.concat(field); field = {} end
  local function endRecord()
    endField()
    if not (#record == 1 and record[1] == "") then
      if not header then
        header = record
      else
        local row = {}
        for k, name in ipairs(header) do row[name] = record[k] end
        rows[#rows + 1] = row
      end
    end
    record = {}
  end
  local quoted = false
  while i <= n do
    local c = text:sub(i, i)
    if quoted then
      if c == '"' then
        if text:sub(i + 1, i + 1) == '"' then field[#field + 1] = '"'; i = i + 1 else quoted = false end
      elseif c == "\n" or c == "\r" then
        field[#field + 1] = " "
      else
        field[#field + 1] = c
      end
    elseif c == '"' then quoted = true
    elseif c == "," then endField()
    elseif c == "\n" then endRecord()
    elseif c ~= "\r" then field[#field + 1] = c
    end
    i = i + 1
  end
  if #field > 0 or #record > 0 then endRecord() end
  return rows, header
end

local function read(name, optional)
  local fh = io.open(raw .. "/" .. name .. ".csv", "r")
  if not fh then
    if optional then return nil end
    error("missing " .. raw .. "/" .. name .. ".csv")
  end
  local text = fh:read("*a")
  fh:close()
  return parse(text)
end

local function cell(v)
  v = v == nil and "" or tostring(v)
  if v:find('[,"\n\r]') then v = '"' .. v:gsub('"', '""') .. '"' end
  return v
end

local function write(name, header, rows)
  local fh = assert(io.open(out .. "/" .. name .. ".csv", "w"))
  local line = {}
  for i, h in ipairs(header) do line[i] = cell(h) end
  fh:write(table.concat(line, ","), "\n")
  for _, row in ipairs(rows) do
    for i, h in ipairs(header) do line[i] = cell(row[h]) end
    fh:write(table.concat(line, ","), "\n")
  end
  fh:close()
  print(("%-26s %7d rows"):format(name, #rows))
end

-- Spell: the pipeline wants ID + Name_lang; names live in SpellName.
do
  local spells = read("Spell")
  local names = {}
  for _, r in ipairs(read("SpellName")) do names[r.ID] = r.Name_lang end
  local rows = {}
  for _, r in ipairs(spells) do rows[#rows + 1] = { ID = r.ID, Name_lang = names[r.ID] or "" } end
  write("Spell", { "ID", "Name_lang" }, rows)
end

-- ItemEffect: one row per (item, effect) link, with the item as ParentItemID.
-- The cooldown columns ride along: the cooldown-category work reads them.
do
  local effects = {}
  for _, r in ipairs(read("ItemEffect")) do effects[r.ID] = r end
  local rows = {}
  for _, link in ipairs(read("ItemXItemEffect")) do
    local e = effects[link.ItemEffectID]
    if e then
      rows[#rows + 1] = {
        ID = e.ID, ParentItemID = link.ItemID, SpellID = e.SpellID, TriggerType = e.TriggerType,
        Charges = e.Charges, CoolDownMSec = e.CoolDownMSec, CategoryCoolDownMSec = e.CategoryCoolDownMSec,
        SpellCategoryID = e.SpellCategoryID, LegacySlotIndex = e.LegacySlotIndex,
      }
    end
  end
  write("ItemEffect", { "ID", "ParentItemID", "SpellID", "TriggerType", "Charges", "CoolDownMSec",
                        "CategoryCoolDownMSec", "SpellCategoryID", "LegacySlotIndex" }, rows)
end

-- SpellEffect: every column kept, plus EffectBasePoints from EffectBasePointsF.
do
  local rows, header = read("SpellEffect")
  local cols = {}
  for i, h in ipairs(header) do cols[i] = h end
  cols[#cols + 1] = "EffectBasePoints"
  for _, r in ipairs(rows) do r.EffectBasePoints = r.EffectBasePointsF end
  write("SpellEffect", cols, rows)
end

-- Everything else, unchanged (optional tables only if this build has them).
for _, name in ipairs({ "Item", "ItemSparse", "SkillLineAbility", "SpellLevels", "SpellReagents", "SpellMisc",
                        "SpellDuration", "SpellItemEnchantment", "ChrSpecialization", "TraitTree", "TraitTreeLoadout", "TraitSubTree",
                        "TraitNode", "TraitNodeEntry", "TraitNodeXTraitNodeEntry", "TraitDefinition" }) do
  local rows, header = read(name, true)
  if rows then write(name, header, rows) end
end
