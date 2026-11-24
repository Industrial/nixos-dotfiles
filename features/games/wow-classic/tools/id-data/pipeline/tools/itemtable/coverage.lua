local M = { }
M.forDomain = function(result, doc, rules)
  local classified, classifiedIds = 0, { }
  for _, members in pairs(result.sets) do
    for id in pairs(members) do
      if not (classifiedIds[id]) then
        classifiedIds[id] = true
        classified = classified + 1
      end
    end
  end
  local excluded = 0
  for _ in pairs(result.excluded) do
    excluded = excluded + 1
  end
  local unclassified
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = result.unclassified
    for _index_0 = 1, #_list_0 do
      local id = _list_0[_index_0]
      _accum_0[_len_0] = id
      _len_0 = _len_0 + 1
    end
    unclassified = _accum_0
  end
  table.sort(unclassified)
  local classifyLib = dofile("tools/itemtable/classify.lua")
  local inScope = 0
  local _list_0 = classifyLib.entitiesOf(doc, rules)
  for _index_0 = 1, #_list_0 do
    local entity = _list_0[_index_0]
    if rules.scope(entity) then
      inScope = inScope + 1
    end
  end
  local sets = { }
  for setName, members in pairs(result.sets) do
    local count = 0
    for _ in pairs(members) do
      count = count + 1
    end
    sets[setName] = count
  end
  local unsupported
  do
    local _accum_0 = { }
    local _len_0 = 1
    for name in pairs(result.unsupported) do
      _accum_0[_len_0] = name
      _len_0 = _len_0 + 1
    end
    unsupported = _accum_0
  end
  table.sort(unsupported)
  return {
    status = "active",
    gate = rules.gate or "zero",
    inScope = inScope,
    classified = classified,
    excluded = excluded,
    unclassifiedCount = #unclassified,
    unclassified = unclassified,
    sets = sets,
    unsupported = unsupported,
    unsupportedReasons = result.unsupported
  }
end
M.notStarted = function(reason)
  return {
    status = "not-started",
    reason = reason
  }
end
M.check = function(coverage, baseline)
  if baseline == nil then
    baseline = { }
  end
  local problems = { }
  for domain, report in pairs(coverage) do
    local _continue_0 = false
    repeat
      if not (report.status == "active") then
        _continue_0 = true
        break
      end
      if report.unclassifiedCount > 0 and (report.gate or "zero") == "zero" then
        local shown = { }
        for i = 1, math.min(10, #report.unclassified) do
          shown[i] = tostring(report.unclassified[i])
        end
        local more = #report.unclassified > 10 and (" (+%d more)"):format(#report.unclassified - 10) or ""
        problems[#problems + 1] = ("%s: %d unclassified item(s): %s%s"):format(domain, report.unclassifiedCount, table.concat(shown, ", "), more)
      end
      local prior = (baseline.domains or { })[domain]
      if not (prior and prior.status == "active") then
        _continue_0 = true
        break
      end
      if report.classified < prior.classified then
        problems[#problems + 1] = ("%s: classified fell %d -> %d"):format(domain, prior.classified, report.classified)
      end
      if report.unclassifiedCount > (prior.unclassifiedCount or 0) then
        problems[#problems + 1] = ("%s: unclassified rose %d -> %d"):format(domain, prior.unclassifiedCount or 0, report.unclassifiedCount)
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return #problems == 0, problems
end
M.toMetrics = function(coverage, build)
  local domains = { }
  for domain, report in pairs(coverage) do
    if report.status == "active" then
      local setCount = 0
      for _ in pairs(report.sets) do
        setCount = setCount + 1
      end
      domains[domain] = {
        status = "active",
        inScope = report.inScope,
        classified = report.classified,
        excluded = report.excluded,
        unclassifiedCount = report.unclassifiedCount,
        gate = report.gate or "zero",
        sets = setCount,
        unsupported = #report.unsupported
      }
    else
      domains[domain] = {
        status = report.status,
        reason = report.reason
      }
    end
  end
  return {
    build = build or "unknown",
    domains = domains
  }
end
return M
