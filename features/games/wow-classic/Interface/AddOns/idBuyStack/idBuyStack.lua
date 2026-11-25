-- Shift-click a vendor item to buy a full stack (as many as you can afford) instead of opening the split box. Items sold in batches (e.g. 200 arrows) keep the default.
hooksecurefunc("MerchantItemButton_OnModifiedClick",function(self,button)
  if button~="LeftButton"or not IsShiftKeyDown()or ChatEdit_GetActiveWindow()or MerchantFrame.selectedTab~=1 then return end
  local id=self:GetID()
  local _,_,price,batch,available=GetMerchantItemInfo(id)
  if batch~=1 then return end
  local n=GetMerchantItemMaxStack(id)
  if price>0 then n=math.min(n,math.floor(GetMoney()/price))end
  if available>=0 then n=math.min(n,available)end
  StackSplitFrame:Hide()
  if n>0 then BuyMerchantItem(id,n)end
end)
