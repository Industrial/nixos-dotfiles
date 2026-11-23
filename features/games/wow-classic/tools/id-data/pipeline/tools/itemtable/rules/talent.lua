local M = { }
M.entities = function(doc)
  return doc.talentEntries or { }
end
M.scope = function(entry)
  return entry.__grantsSpell == true
end
M.annotate = function(doc)
  local specs, trees, nodes = { }, { }, { }
  local _list_0 = (doc.specs or { })
  for _index_0 = 1, #_list_0 do
    local row = _list_0[_index_0]
    specs[row.specId] = row
  end
  local _list_1 = (doc.talentTrees or { })
  for _index_0 = 1, #_list_1 do
    local row = _list_1[_index_0]
    trees[row.treeId] = row
  end
  local _list_2 = (doc.talentNodes or { })
  for _index_0 = 1, #_list_2 do
    local row = _list_2[_index_0]
    nodes[row.nodeId] = row
  end
  local spellIds = { }
  local _list_3 = (doc.spells or { })
  for _index_0 = 1, #_list_3 do
    local sp = _list_3[_index_0]
    spellIds[sp.id] = true
  end
  local entryCount = { }
  local _list_4 = (doc.talentEntries or { })
  for _index_0 = 1, #_list_4 do
    local entry = _list_4[_index_0]
    entryCount[entry.nodeId] = (entryCount[entry.nodeId] or 0) + 1
  end
  local _list_5 = (doc.talentEntries or { })
  for _index_0 = 1, #_list_5 do
    local entry = _list_5[_index_0]
    local node = entry.nodeId and nodes[entry.nodeId]
    local tree = node and node.treeId and trees[node.treeId]
    local spec = tree and tree.specId and specs[tree.specId]
    entry.__grantsSpell = (entry.spellId ~= nil and spellIds[entry.spellId] == true)
    entry.__node = node
    entry.__tree = tree
    entry.__spec = spec
    entry.__siblings = entryCount[entry.nodeId] or 1
    entry.__classFile = (tree and tree.classFile) or (spec and spec.classFile)
  end
  return doc
end
local byTreeKind
byTreeKind = function(kind)
  return function(ctx, entry)
    local tree = entry.__tree
    if not (tree and tree.kind == kind) then
      return nil
    end
    return math.max(1, (entry.__node and entry.__node.maxRanks or 1))
  end
end
local onChoiceNode
onChoiceNode = function(ctx, entry)
  if not ((entry.__siblings or 1) > 1) then
    return nil
  end
  return entry.__siblings
end
local onRankedNode
onRankedNode = function(ctx, entry)
  local ranks = entry.__node and entry.__node.maxRanks or 1
  if not (ranks > 1) then
    return nil
  end
  return ranks
end
local grantsSpell
grantsSpell = function(ctx, entry)
  if not (entry.__tree) then
    return nil
  end
  return entry.spellId
end
local unsupported
unsupported = function(reason)
  return {
    unsupported = reason
  }
end
local reachableBy
reachableBy = function(classFile, specId)
  return function(ctx, entry)
    if not (entry.__classFile == classFile) then
      return nil
    end
    local tree = entry.__tree
    if not (tree) then
      return nil
    end
    if tree.kind == "class" then
      return entry.spellId
    end
    if not (tree.specId == specId) then
      return nil
    end
    return entry.spellId
  end
end
M.setsFor = function(doc)
  local sets = {
    ["Talent.Tree.Class"] = {
      predicate = byTreeKind("class")
    },
    ["Talent.Tree.Spec"] = {
      predicate = byTreeKind("spec")
    },
    ["Talent.Tree.Hero"] = {
      predicate = byTreeKind("hero")
    },
    ["Talent.Node.Choice"] = {
      predicate = onChoiceNode
    },
    ["Talent.Node.MultiRank"] = {
      predicate = onRankedNode
    },
    ["Talent.Grants.Spell"] = {
      predicate = grantsSpell
    },
    ["Talent.Node.Position"] = unsupported("model has no node row/column/prerequisite data"),
    ["Talent.Loadout.Default"] = unsupported("loadout export strings are a client encoding, not game data")
  }
  local byClass = { }
  local _list_0 = (doc.specs or { })
  for _index_0 = 1, #_list_0 do
    local _continue_0 = false
    repeat
      local spec = _list_0[_index_0]
      if not (spec.classFile and spec.name) then
        _continue_0 = true
        break
      end
      local _update_0 = spec.classFile
      byClass[_update_0] = byClass[_update_0] or { }
      byClass[spec.classFile][#byClass[spec.classFile] + 1] = spec
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  for classFile, specs in pairs(byClass) do
    for _index_0 = 1, #specs do
      local spec = specs[_index_0]
      local name = ("Talent.Spec.%s.%s"):format(classFile, (spec.name:gsub("%s+", "")))
      sets[name] = {
        predicate = reachableBy(classFile, spec.specId)
      }
    end
  end
  return sets
end
M.exclusions = {
  {
    reason = "spell-granting entry whose tree or spec is missing from the data",
    match = function(ctx, entry)
      return entry.__tree == nil
    end
  }
}
M.gate = "zero"
M.overrides = { }
M.forDocument = function(doc)
  M.annotate(doc)
  return {
    entities = M.entities,
    idField = "entryId",
    scope = M.scope,
    sets = M.setsFor(doc),
    exclusions = M.exclusions,
    overrides = M.overrides,
    gate = M.gate
  }
end
return M
