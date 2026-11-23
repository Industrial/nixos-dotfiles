local M = { }
M.scope = function(item)
  return item.class == "Trade Goods"
end
local bySubclass
bySubclass = function(subclass)
  return function(ctx, item)
    if not (item.subclass == subclass) then
      return nil
    end
    return 1
  end
end
M.setsFor = function(doc)
  local seen = { }
  local _list_0 = (doc.items or { })
  for _index_0 = 1, #_list_0 do
    local _continue_0 = false
    repeat
      local item = _list_0[_index_0]
      if not (M.scope(item)) then
        _continue_0 = true
        break
      end
      if item.subclass then
        seen[item.subclass] = true
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  local sets = {
    ["Tradeskill.Mat.ByProfession"] = {
      unsupported = "needs recipe/SkillLine data the model does not carry"
    }
  }
  for subclass in pairs(seen) do
    sets[("Tradeskill.Mat.BySubclass.%s"):format(subclass)] = {
      predicate = bySubclass(subclass)
    }
  end
  return sets
end
M.exclusions = {
  {
    reason = "trade good with no subclass in the source data",
    match = function(ctx, item)
      return item.subclass == nil
    end
  }
}
M.overrides = { }
M.forDocument = function(doc)
  return {
    scope = M.scope,
    sets = M.setsFor(doc),
    exclusions = M.exclusions,
    overrides = M.overrides
  }
end
return M
