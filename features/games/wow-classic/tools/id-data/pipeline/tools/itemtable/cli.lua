local subcommand = arg[1]
local die
die = function(fmt, ...)
  io.stderr:write(fmt:format(...) .. "\n")
  return os.exit(1)
end
local commands = { }
commands.validate = function(path)
  path = path or "tools/itemtable/fixtures.lua"
  local validate = dofile("tools/itemtable/validate.lua")
  local ok, doc = pcall(dofile, path)
  if not (ok) then
    die("cannot load %s: %s", path, tostring(doc))
  end
  local valid, errors = validate.validate(doc)
  if valid then
    print(("%s: valid (%d items, %d spells, %d item effects, %d spell effects)"):format(path, #doc.items, #doc.spells, #doc.itemEffects, #doc.spellEffects))
    return 
  end
  io.stderr:write(("%s: %d problem(s)\n"):format(path, #errors))
  for _index_0 = 1, #errors do
    local e = errors[_index_0]
    io.stderr:write(("  %s: %s\n"):format((e.path ~= "" and e.path or "<document>"), e.message))
  end
  return os.exit(1)
end
commands.schema = function(outPath)
  local json = dofile("tools/itemtable/json.lua")
  local validate = dofile("tools/itemtable/validate.lua")
  local encoded = json.encode(validate.toJsonSchema(), true)
  if not (outPath) then
    print(encoded)
    return 
  end
  local fh, err = io.open(outPath, "w")
  if not (fh) then
    die("cannot write %s: %s", outPath, tostring(err))
  end
  fh:write(encoded, "\n")
  fh:close()
  return print(("wrote %s"):format(outPath))
end
local METRICS = "quality/metrics/itemtable.json"
local DOMAINS = {
  "Consumable",
  "Tradeskill",
  "Spell",
  "Talent"
}
local RULES_MODULE = {
  Consumable = "tools/itemtable/rules/consumable.lua",
  Tradeskill = "tools/itemtable/rules/tradeskill.lua",
  Spell = "tools/itemtable/rules/spell.lua",
  Talent = "tools/itemtable/rules/talent.lua"
}
local loadDoc
loadDoc = function(path)
  local ok, doc = pcall(dofile, path)
  if not (ok) then
    die("cannot load %s: %s", path, tostring(doc))
  end
  return doc
end
local classifyAll
classifyAll = function(doc)
  local classify = dofile("tools/itemtable/classify.lua")
  local coverageLib = dofile("tools/itemtable/coverage.lua")
  local results, coverage, rulesFor = { }, { }, { }
  for _index_0 = 1, #DOMAINS do
    local domain = DOMAINS[_index_0]
    local mod = dofile(RULES_MODULE[domain])
    local rules = mod.forDocument and mod.forDocument(doc) or mod
    rulesFor[domain] = rules
    results[domain] = classify.run(doc, rules)
    coverage[domain] = coverageLib.forDomain(results[domain], doc, rules)
  end
  return results, coverage, rulesFor
end
local baselineMetrics
baselineMetrics = function()
  return (dofile("tools/itemtable/json.lua")).decodeFile(METRICS) or { }
end
commands.check = function(path, flag)
  if path and path:sub(1, 2) == "--" then
    path, flag = flag, path
  end
  path = path or "tools/itemtable/fixtures.lua"
  local coverageLib = dofile("tools/itemtable/coverage.lua")
  local json = dofile("tools/itemtable/json.lua")
  local doc = loadDoc(path)
  local _, coverage = classifyAll(doc)
  local passed, problems = coverageLib.check(coverage, baselineMetrics())
  for _index_0 = 1, #DOMAINS do
    local _continue_0 = false
    repeat
      local domain = DOMAINS[_index_0]
      local d = coverage[domain]
      if not (d.status == "active") then
        _continue_0 = true
        break
      end
      print(("%s: %d in scope, %d classified, %d excluded, %d unclassified, %d unsupported sets"):format(domain, d.inScope, d.classified, d.excluded, d.unclassifiedCount, #d.unsupported))
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  if not (passed) then
    io.stderr:write("coverage gate FAILED\n")
    for _index_0 = 1, #problems do
      local p = problems[_index_0]
      io.stderr:write("  " .. p .. "\n")
    end
    os.exit(1)
  end
  if flag == "--write" then
    local metrics = coverageLib.toMetrics(coverage, doc.build)
    local out = io.open(METRICS, "w")
    if not (out) then
      die("cannot write %s", METRICS)
    end
    out:write(json.encode(metrics, true), "\n")
    out:close()
    print(("wrote %s"):format(METRICS))
  end
  return print("coverage gate PASSED")
end
local DATA_DIRS = {
  ["idLibItemTable-1.0"] = "Libs/idLibItemTable-1.0/data",
  ["idLibSpellTable-1.0"] = "Libs/idLibSpellTable-1.0/data",
  ["idLibTalentTable-1.0"] = "Libs/idLibTalentTable-1.0/data"
}
local DATA_DIR = DATA_DIRS["idLibItemTable-1.0"]
commands.emit = function(path)
  path = path or "tools/itemtable/fixtures.lua"
  local coverageLib = dofile("tools/itemtable/coverage.lua")
  local emit = dofile("tools/itemtable/emit.lua")
  local doc = loadDoc(path)
  local results, coverage = classifyAll(doc)
  local passed, problems = coverageLib.check(coverage, baselineMetrics())
  if not (passed) then
    io.stderr:write("refusing to emit: coverage gate failed\n")
    for _index_0 = 1, #problems do
      local p = problems[_index_0]
      io.stderr:write("  " .. p .. "\n")
    end
    os.exit(1)
  end
  local domains, setCount, classified = { }, 0, 0
  for _index_0 = 1, #DOMAINS do
    local domain = DOMAINS[_index_0]
    domains[domain] = {
      revision = 1,
      result = results[domain]
    }
    for _ in pairs(results[domain].sets) do
      setCount = setCount + 1
    end
    classified = classified + coverage[domain].classified
  end
  local written, err = emit.writeAll(DATA_DIRS, domains, {
    build = doc.build,
    source = doc.source,
    sets = setCount,
    classified = classified
  })
  if not (written) then
    die("%s", tostring(err))
  end
  return print(("emitted %d file(s): %s"):format(#written, table.concat(written, ", ")))
end
commands.diff = function(path)
  path = path or "tools/itemtable/fixtures.lua"
  local classify = dofile("tools/itemtable/classify.lua")
  local rules = dofile("tools/itemtable/rules/consumable.lua")
  local golden = dofile("tools/itemtable/golden_diff.lua")
  local ok, doc = pcall(dofile, path)
  if not (ok) then
    die("cannot load %s: %s", path, tostring(doc))
  end
  local fresh = (classify.run(doc, rules)).sets
  local committed = golden.loadCommitted(("%s/Consumable.lua"):format(DATA_DIR))
  local _list_0 = golden.format(golden.diff(committed, fresh))
  for _index_0 = 1, #_list_0 do
    local line = _list_0[_index_0]
    print(line)
  end
end
commands.regen = function(path)
  path = path or "tools/itemtable/fixtures.lua"
  local _list_0 = {
    "validate",
    "check",
    "diff",
    "emit"
  }
  for _index_0 = 1, #_list_0 do
    local stage = _list_0[_index_0]
    print(("== %s"):format(stage))
    commands[stage](path)
  end
  return print("== regeneration complete; put the diff above in the commit body")
end
if not (subcommand and commands[subcommand]) then
  io.stderr:write("usage: itemtable <validate|schema|check|emit|diff|regen> [args]\n")
  os.exit(2)
end
return commands[subcommand](arg[2], arg[3])
