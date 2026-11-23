local Button = { }
local SECURE_ATTRS = {
  "type",
  "spell",
  "item",
  "unit",
  "target-slot",
  "macrotext"
}
Button.SECURE_ATTRS = SECURE_ATTRS
Button.macroText = function(step)
  if not (step) then
    return nil
  end
  local lines = { }
  if step.cancelForm then
    lines[#lines + 1] = "/cancelform"
  end
  if step.kind == "spell" and step.spell then
    if step.unit then
      lines[#lines + 1] = "/cast [@" .. tostring(step.unit) .. "] " .. tostring(step.spell)
    else
      lines[#lines + 1] = "/cast " .. tostring(step.spell)
    end
  elseif step.kind == "item" and step.item then
    lines[#lines + 1] = "/use item:" .. tostring(step.item)
    if step.targetSlot then
      lines[#lines + 1] = "/use " .. tostring(step.targetSlot)
    end
  elseif step.kind == "macro" and step.macrotext then
    lines[#lines + 1] = step.macrotext
  else
    return nil
  end
  return table.concat(lines, "\n")
end
Button.attrsFor = function(step)
  local attrs = { }
  if not (step) then
    return attrs
  end
  if step.cancelForm or step.kind == "macro" then
    local text = Button.macroText(step)
    if not (text) then
      return attrs
    end
    attrs.type = "macro"
    attrs.macrotext = text
    return attrs
  end
  if step.kind == "spell" and step.spell then
    attrs.type = "spell"
    attrs.spell = step.spell
    if step.unit then
      attrs.unit = step.unit
    end
  elseif step.kind == "item" and step.item then
    attrs.type = "item"
    attrs.item = "item:" .. tostring(step.item)
    if step.unit then
      attrs.unit = step.unit
    end
    if step.targetSlot then
      attrs["target-slot"] = step.targetSlot
    end
  end
  return attrs
end
Button.write = function(btn, suffix, step)
  if not (btn and btn.SetAttribute) then
    return false
  end
  local attrs = Button.attrsFor(step)
  for _index_0 = 1, #SECURE_ATTRS do
    local name = SECURE_ATTRS[_index_0]
    btn:SetAttribute(name .. (suffix or ""), nil)
  end
  for name, value in pairs(attrs) do
    btn:SetAttribute(name .. (suffix or ""), value)
  end
  return true
end
Button.writeAll = function(targets, step)
  local written = 0
  local _list_0 = (targets or { })
  for _index_0 = 1, #_list_0 do
    local target = _list_0[_index_0]
    local btn, suffix = target[1], target[2]
    if Button.write(btn, suffix, step) then
      written = written + 1
    end
  end
  return written
end
Button.isEmpty = function(step)
  local attrs = Button.attrsFor(step)
  return attrs.type == nil
end
_G.idUpkeep_UpkeepButton = Button
return Button
