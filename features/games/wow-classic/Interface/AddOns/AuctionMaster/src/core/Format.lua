local addonName, AM = ...

-- Size 0 makes the icon as high as the text, the x offset of 2 keeps it off the number.
local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"

-- Formats copper as gold, silver and copper with coin icons, e.g. "18[gold] 99[silver]".
-- To keep it short, silver is left out from 100 gold on and copper from 1 gold on. The
-- icons need no translation. With abbreviate, gold from 1000 on is shortened like AM.FormatCount
-- ("3.8k").
function AM.FormatMoney(copper, abbreviate)
  copper = math.floor(math.max(0, copper or 0))
  local gold = math.floor(copper / 10000)
  local silver = math.floor(copper / 100) % 100
  local rest = copper % 100

  local parts = {}
  if gold > 0 then
    parts[#parts + 1] = (abbreviate and AM.FormatCount(gold) or gold) .. GOLD_ICON
  end
  if silver > 0 and gold < 100 then
    parts[#parts + 1] = silver .. SILVER_ICON
  end
  if rest > 0 and gold < 1 then
    parts[#parts + 1] = rest .. COPPER_ICON
  end
  return #parts > 0 and table.concat(parts, " ") or "--"
end

-- Short count for large numbers: 950 stays, 160000 becomes "160k", 1250000 "1.2M". Only
-- the first decimal is kept and a trailing ".0" is dropped.
function AM.FormatCount(count)
  count = math.floor(count or 0)
  local value, suffix
  if count >= 1000000 then
    value, suffix = count / 1000000, "M"
  elseif count >= 1000 then
    value, suffix = count / 1000, "k"
  else
    return tostring(count)
  end
  local text = value >= 100 and tostring(math.floor(value)) or string.format("%.1f", value):gsub("%.0$", "")
  return text .. suffix
end
