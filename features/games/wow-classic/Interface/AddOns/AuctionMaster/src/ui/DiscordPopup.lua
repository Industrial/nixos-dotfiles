local addonName, AM = ...

local L = AM.L

-- The invitation to the Discord for bug reports and feature requests. The game cannot write to the clipboard, so
-- the popup shows the link selected in a text box for Ctrl+C (typing is undone). Opened by the link in the update
-- message (see AM.Changelog); the options page has the same box.
AM.DiscordPopup = {}
local DiscordPopup = AM.DiscordPopup

DiscordPopup.URL = "https://discord.gg/Bh6zGAKr2D"

local function GetBox(popup)
  return popup.GetEditBox and popup:GetEditBox() or popup.editBox or popup.EditBox
end

StaticPopupDialogs["AUCTIONMASTER_DISCORD"] = {
  text = "",
  button1 = CLOSE,
  hasEditBox = true,
  editBoxWidth = 260,
  OnShow = function(self)
    local box = GetBox(self)
    box:SetText(DiscordPopup.URL)
    box:HighlightText()
    box:SetFocus()
  end,
  EditBoxOnTextChanged = function(self)
    if self:GetText() ~= DiscordPopup.URL then
      self:SetText(DiscordPopup.URL)
      self:HighlightText()
    end
  end,
  EditBoxOnEnterPressed = function(self)
    self:GetParent():Hide()
  end,
  EditBoxOnEscapePressed = function(self)
    self:GetParent():Hide()
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
}

-- The language is only known once the saved variables are loaded (see AM.Locale).
AM.Locale.OnReady(function()
  StaticPopupDialogs["AUCTIONMASTER_DISCORD"].text = L["DISCORD_POPUP"]
end)

function DiscordPopup.Show()
  StaticPopup_Show("AUCTIONMASTER_DISCORD")
end
