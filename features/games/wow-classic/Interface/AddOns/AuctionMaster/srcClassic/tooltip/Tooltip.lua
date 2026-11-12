local addonName, AM = ...

-- On the Classic client, TooltipDataProcessor registers without error but never
-- actually fires (confirmed by testing), so item tooltips need feeding via the older
-- OnTooltipSetItem hook instead. This is the only file in the addon that uses it - every
-- other client keeps using TooltipDataProcessor exclusively (see src/tooltip/Tooltip.lua).
GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
  local _, itemLink = tooltip:GetItem()
  local itemId = itemLink and C_Item.GetItemInfoInstant(itemLink)
  if itemId then
    AM.Tooltip.Dispatch(tooltip, itemId, itemLink)
  end
end)
