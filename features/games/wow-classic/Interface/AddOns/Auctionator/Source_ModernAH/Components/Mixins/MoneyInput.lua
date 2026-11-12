AuctionatorConfigMoneyInputMixin = {}

function AuctionatorConfigMoneyInputMixin:OnLoad()
  if self.labelText ~= nil then
    self.Label:SetText(self.labelText)
  end

  self.forceHide = (C_AuctionHouse.SupportsCopperValues and not C_AuctionHouse.SupportsCopperValues()) or (Auctionator.Constants.IsRetail and not Auctionator.Constants.IsForever)
  self:SetCopperHidden(false)

  self.MoneyInput.CopperBox:SetScript("OnEnter", function() self:OnEnter() end)
  self.MoneyInput.CopperBox:SetScript("OnLeave", function() self:OnLeave() end)
  self.MoneyInput.SilverBox:SetScript("OnEnter", function() self:OnEnter() end)
  self.MoneyInput.SilverBox:SetScript("OnLeave", function() self:OnLeave() end)
  self.MoneyInput.GoldBox:SetScript("OnEnter", function() self:OnEnter() end)
  self.MoneyInput.GoldBox:SetScript("OnLeave", function() self:OnLeave() end)

  self.MoneyInput.CopperBox:SetScript("OnEnterPressed", function()
    Auctionator.Components.ReportEnterPressed()
  end)
  self.MoneyInput.SilverBox:SetScript("OnEnterPressed", function()
    Auctionator.Components.ReportEnterPressed()
  end)
  self.MoneyInput.GoldBox:SetScript("OnEnterPressed", function()
    Auctionator.Components.ReportEnterPressed()
  end)
end

function AuctionatorConfigMoneyInputMixin:SetAmount(value)
  if self.MoneyInput.hideCopper then
    value = math.ceil(value / 100) * 100
  end
  self.MoneyInput:SetAmount(value)
  self.MoneyInput.GoldBox:SetCursorPosition(0)
  self.MoneyInput.SilverBox:SetCursorPosition(0)
end

function AuctionatorConfigMoneyInputMixin:Clear()
  self.MoneyInput:Clear()
end

function AuctionatorConfigMoneyInputMixin:GetAmount()
  local amount = self.MoneyInput:GetAmount()
  if self.MoneyInput.hideCopper then
    return math.ceil(amount / 100) * 100
  else
    return amount
  end
end

function AuctionatorConfigMoneyInputMixin:SetCopperHidden(state)
  self.MoneyInput.hideCopper = state or self.forceHide
	if state or self.forceHide then
		self.MoneyInput.CopperBox:Hide();
		self.MoneyInput.SilverBox:ClearAllPoints();
		self.MoneyInput.SilverBox:SetPoint("RIGHT", self.MoneyInput.CopperBox, "RIGHT");

		self.MoneyInput.GoldBox.nextEditBox = self.MoneyInput.SilverBox;
		self.MoneyInput.SilverBox.previousEditBox = self.MoneyInput.GoldBox;
		self.MoneyInput.SilverBox.nextEditBox = self.MoneyInput.nextEditBox;
	else
    self.MoneyInput.CopperBox:Show()
		self.MoneyInput.SilverBox:ClearAllPoints();
		self.MoneyInput.SilverBox:SetPoint("RIGHT", self.MoneyInput.CopperBox, "LEFT", -6, 0);

		self.MoneyInput.GoldBox.nextEditBox = self.MoneyInput.SilverBox;
		self.MoneyInput.SilverBox.previousEditBox = self.MoneyInput.GoldBox;
		self.MoneyInput.SilverBox.nextEditBox = self.MoneyInput.CopperBox;
		self.MoneyInput.CopperBox.previousEditBox = self.MoneyInput.GoldBox;
		self.MoneyInput.CopperBox.nextEditBox = self.MoneyInput.nextEditBox;
	end
  self:UpdateWidth(state or self.forceHide)
  self.MoneyInput:SetNextEditBox(self.next)
end

function AuctionatorConfigMoneyInputMixin:SetNextEditBox(editBox)
  self.next = editBox
  self.MoneyInput:SetNextEditBox(editBox)
end

function AuctionatorConfigMoneyInputMixin:UpdateWidth(state)
  if not state then
    self.MoneyInput:SetWidth(190)
  else
    self.MoneyInput:SetWidth(150)
  end
end
