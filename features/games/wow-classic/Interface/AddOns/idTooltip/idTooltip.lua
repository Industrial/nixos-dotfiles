-- Tooltips at the cursor, and an "Item Level N" line on items. idAutomation's Tooltip module, without its options.
-- hooksecurefunc runs after Blizzard's anchor and never replaces it, so no tooltip is tainted.
hooksecurefunc("GameTooltip_SetDefaultAnchor",function(t,p)if t==GameTooltip then t:SetOwner(p,"ANCHOR_CURSOR_RIGHT",10,10)end end)
local function itemLevel(t)
  if not t.GetItem then return end
  local _,link=t:GetItem()
  local n=link and GetDetailedItemLevelInfo and GetDetailedItemLevelInfo(link)
  if n and n>0 then t:AddLine("Item Level "..n)t:Show()end
end
-- Forever/Mainline dropped OnTooltipSetItem; TooltipDataProcessor replaces it there. Classic Era keeps the script.
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,itemLevel)
else
  GameTooltip:HookScript("OnTooltipSetItem",itemLevel)
end
