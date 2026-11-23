-- Runs the item-table pipeline (tools/id-data/pipeline) over normalized client tables and
-- writes the data modules into the idLib*Table addons (not into idAutomation).
--
--   cd tools/id-data/pipeline; lua generate.lua <csv dir> <build> <AddOns dir>
--
-- The same stages as `bin/itemtable emit`: CSV -> model (sources/dbc) ->
-- classify per domain (rules/*) -> coverage gate against idAutomation's
-- baseline -> emit. It fails closed: a failed gate emits nothing.
local csvDir, build, addons = arg[1], arg[2], arg[3]
assert(csvDir and build and addons, "usage: lua generate.lua <csv dir> <build> <AddOns dir>")

local function die(fmt, ...) io.stderr:write(fmt:format(...), "\n"); os.exit(1) end

local dbc = dofile("tools/itemtable/sources/dbc.lua")
local validate = dofile("tools/itemtable/validate.lua")
local classify = dofile("tools/itemtable/classify.lua")
local coverageLib = dofile("tools/itemtable/coverage.lua")
local emit = dofile("tools/itemtable/emit.lua")
local json = dofile("tools/itemtable/json.lua")

-- Kept in step with tools/itemtable/cli.moon (DOMAINS, RULES_MODULE, METRICS).
local DOMAINS = { "Consumable", "Tradeskill", "Spell", "Talent" }
local RULES_MODULE = {
  Consumable = "tools/itemtable/rules/consumable.lua",
  Tradeskill = "tools/itemtable/rules/tradeskill.lua",
  Spell = "tools/itemtable/rules/spell.lua",
  Talent = "tools/itemtable/rules/talent.lua",
}
local DATA_DIRS = {
  ["idLibItemTable-1.0"] = addons .. "/idLibItemTable/data",
  ["idLibSpellTable-1.0"] = addons .. "/idLibSpellTable/data",
  ["idLibTalentTable-1.0"] = addons .. "/idLibTalentTable/data",
}

local tables, err = dbc.loadDir(csvDir)
if not tables then die("dbc: %s", err) end
local doc, notes = dbc.toModel(tables, { build = build })
doc.source = "dbc"
print(("model: %d items, %d spells, %d item effects, %d spell effects"):format(
  #doc.items, #doc.spells, #doc.itemEffects, #doc.spellEffects))
if notes and #notes > 0 then print(("model notes: %d (first: %s)"):format(#notes, notes[1])) end

-- A talent whose spell the client does not ship (Forever 1.60.1.71037 has one:
-- TraitDefinition 134244 -> spell 22571, absent from Spell, SpellName, SpellMisc
-- and SpellEffect -- presumably delivered by a server hotfix). The validator
-- rejects the whole model for it, so it is dropped here and reported, the way
-- sources/dbc reports its own dangling references.
if doc.talentEntries then
  local known = {}
  for _, s in ipairs(doc.spells) do known[s.id] = true end
  local kept, dropped = {}, {}
  for _, e in ipairs(doc.talentEntries) do
    if e.spellId == nil or known[e.spellId] then kept[#kept + 1] = e else dropped[#dropped + 1] = e.spellId end
  end
  if #dropped > 0 then
    doc.talentEntries = kept
    print(("dropped %d talent entr%s whose spell the client lacks: %s"):format(
      #dropped, #dropped == 1 and "y" or "ies", table.concat(dropped, ", ")))
  end
end

local valid, problems = validate.validate(doc)
if not valid then
  io.stderr:write(("model invalid: %d problem(s)\n"):format(#problems))
  for i = 1, math.min(#problems, 10) do
    io.stderr:write(("  %s: %s\n"):format(problems[i].path, problems[i].message))
  end
  os.exit(1)
end

local results, coverage = {}, {}
for _, domain in ipairs(DOMAINS) do
  local mod = dofile(RULES_MODULE[domain])
  local rules = mod.forDocument and mod.forDocument(doc) or mod
  results[domain] = classify.run(doc, rules)
  coverage[domain] = coverageLib.forDomain(results[domain], doc, rules)
  local d = coverage[domain]
  if d.status == "active" then
    print(("%-10s %6d in scope, %6d classified, %5d excluded, %5d unclassified, %d unsupported sets"):format(
      domain, d.inScope, d.classified, d.excluded, d.unclassifiedCount, #d.unsupported))
  end
end

-- Same baseline read as cli.moon's baselineMetrics (advisory when missing).
local passed, gateProblems = coverageLib.check(coverage, json.decodeFile("quality/metrics/itemtable.json") or {})
if not passed then
  io.stderr:write("refusing to emit: coverage gate failed\n")
  for _, p in ipairs(gateProblems) do io.stderr:write("  " .. p .. "\n") end
  os.exit(1)
end
print("coverage gate PASSED")

local domains, setCount, classified = {}, 0, 0
for _, domain in ipairs(DOMAINS) do
  domains[domain] = { revision = 1, result = results[domain] }
  for _ in pairs(results[domain].sets) do setCount = setCount + 1 end
  classified = classified + coverage[domain].classified
end
local written, werr = emit.writeAll(DATA_DIRS, domains,
  { build = build, source = "dbc", sets = setCount, classified = classified })
if not written then die("%s", tostring(werr)) end
print(("emitted %d file(s): %s"):format(#written, table.concat(written, ", ")))
