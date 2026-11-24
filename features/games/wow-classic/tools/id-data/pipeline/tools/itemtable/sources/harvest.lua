local M = { }
M.loadDump = function(path)
  local env = { }
  local chunk, err
  if setfenv then
    chunk, err = loadfile(path)
    if chunk then
      setfenv(chunk, env)
    end
  else
    chunk, err = loadfile(path, "t", env)
  end
  if not (chunk) then
    return nil, ("cannot load %s: %s"):format(path, tostring(err))
  end
  local ok, runErr = pcall(chunk)
  if not (ok) then
    return nil, ("error executing %s: %s"):format(path, tostring(runErr))
  end
  local db = env.idAutomation_HarvestDB
  if not (type(db) == "table") then
    return nil, ("%s defines no idAutomation_HarvestDB"):format(path)
  end
  return db
end
M.toModel = function(db, opts)
  if opts == nil then
    opts = { }
  end
  local doc = {
    schemaVersion = 1,
    build = opts.build or (db.meta and db.meta.build) or "unknown",
    source = "harvest",
    items = { },
    spells = { },
    itemEffects = { },
    spellEffects = { }
  }
  local ids
  do
    local _accum_0 = { }
    local _len_0 = 1
    for id in pairs(db.items or { }) do
      _accum_0[_len_0] = id
      _len_0 = _len_0 + 1
    end
    ids = _accum_0
  end
  table.sort(ids)
  local seenSpell = { }
  for _index_0 = 1, #ids do
    local _continue_0 = false
    repeat
      local id = ids[_index_0]
      local rec = db.items[id]
      if not (type(rec) == "table" and type(rec.name) == "string") then
        _continue_0 = true
        break
      end
      doc.items[#doc.items + 1] = {
        id = id,
        name = rec.name,
        class = rec.class or "Unknown",
        subclass = rec.subclass,
        quality = rec.quality,
        ilvl = rec.ilvl,
        stackable = rec.stackable
      }
      if rec.spellId and rec.spellName then
        if not (seenSpell[rec.spellId]) then
          seenSpell[rec.spellId] = true
          doc.spells[#doc.spells + 1] = {
            id = rec.spellId,
            name = rec.spellName
          }
        end
        doc.itemEffects[#doc.itemEffects + 1] = {
          itemId = id,
          spellId = rec.spellId,
          trigger = "use"
        }
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  table.sort(doc.spells, function(a, b)
    return a.id < b.id
  end)
  if type(db.spells) == "table" and type(db.spellMeta) == "table" and db.spellMeta.classFile then
    local classFile = db.spellMeta.classFile
    local spellIds
    do
      local _accum_0 = { }
      local _len_0 = 1
      for id in pairs(db.spells) do
        _accum_0[_len_0] = id
        _len_0 = _len_0 + 1
      end
      spellIds = _accum_0
    end
    table.sort(spellIds)
    local knownSpell = { }
    local _list_0 = doc.spells
    for _index_0 = 1, #_list_0 do
      local sp = _list_0[_index_0]
      knownSpell[sp.id] = true
    end
    doc.spellClass = { }
    for _index_0 = 1, #spellIds do
      local _continue_0 = false
      repeat
        local id = spellIds[_index_0]
        local rec = db.spells[id]
        if not (type(rec) == "table") then
          _continue_0 = true
          break
        end
        if not (knownSpell[id]) then
          knownSpell[id] = true
          doc.spells[#doc.spells + 1] = {
            id = id,
            name = rec.name or ("Spell%d"):format(id)
          }
        end
        doc.spellClass[#doc.spellClass + 1] = {
          spellId = id,
          classFile = classFile
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
  end
  if type(db.traitMeta) == "table" and db.traitMeta.specId then
    local meta = db.traitMeta
    doc.specs = {
      {
        specId = meta.specId,
        classFile = (type(db.spellMeta) == "table" and db.spellMeta.classFile) or "UNKNOWN",
        name = meta.specName or ("Spec%d"):format(meta.specId),
        role = meta.role,
        primaryStat = meta.primaryStat
      }
    }
    doc.talentTrees = { }
    local _list_0 = (meta.trees or { })
    for _index_0 = 1, #_list_0 do
      local treeId = _list_0[_index_0]
      doc.talentTrees[#doc.talentTrees + 1] = {
        treeId = treeId,
        specId = meta.specId,
        kind = "spec"
      }
    end
    table.sort(doc.talentTrees, function(a, b)
      return a.treeId < b.treeId
    end)
    if type(db.traitNodes) == "table" then
      doc.talentNodes = { }
      for nodeId, node in pairs(db.traitNodes) do
        local _continue_0 = false
        repeat
          if not (type(node) == "table" and node.treeId) then
            _continue_0 = true
            break
          end
          doc.talentNodes[#doc.talentNodes + 1] = {
            nodeId = nodeId,
            treeId = node.treeId,
            maxRanks = node.maxRanks or 1
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
    if type(db.traitEntries) == "table" then
      doc.talentEntries = { }
      for entryId, entry in pairs(db.traitEntries) do
        local _continue_0 = false
        repeat
          if not (type(entry) == "table" and entry.nodeId) then
            _continue_0 = true
            break
          end
          doc.talentEntries[#doc.talentEntries + 1] = {
            entryId = entryId,
            nodeId = entry.nodeId,
            spellId = entry.spellId,
            definitionId = entry.definitionId
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
  end
  return doc
end
M.traitLimits = function(db)
  local meta = (db or { }).traitMeta
  local seen = 0
  for _ in pairs((type(meta) == "table" and meta.seenSpecs or { })) do
    seen = seen + 1
  end
  return {
    specsSeen = seen,
    hasClassTree = false,
    activeSpecOnly = true,
    lastAttemptReadable = type(meta) == "table" and meta.lastAttempt and meta.lastAttempt.readable or false
  }
end
M.secretCount = function(db)
  local n = 0
  for _, rec in pairs((db or { }).items or { }) do
    if type(rec) == "table" and rec.secret then
      n = n + 1
    end
  end
  return n
end
return M
