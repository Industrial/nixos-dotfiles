local addonName, AM = ...
local L = AM.L

local LOGO = "|TInterface\\AddOns\\" .. addonName .. "\\assets\\logo:14|t"

local BIND_ON_PICKUP = 1
local QUEST_ITEM = 4

-- Whether the item could be put on the auction house. This is false for items that are
-- bound to the player or that can never be traded, and unknown (false) while the item
-- data is not loaded yet.
local function IsSellable(itemId, location)
  local bindType = select(14, C_Item.GetItemInfo(itemId))
  if not bindType or bindType == BIND_ON_PICKUP or bindType == QUEST_ITEM then
    return false
  end
  if location and C_Item.IsBound and C_Item.IsBound(location) then
    return false
  end
  return true
end

-- How much of the market data the tooltip shows, chosen in the options (global object "settings"): "full" (the
-- default, stored as nil), "compact" (two lines) or "off".
AM.Tooltip.MARKET_MODES = { "full", "compact", "off" }

function AM.Tooltip.GetMarketMode()
  return AM.Database.GetGlobalObject("settings").marketTooltip or "full"
end

function AM.Tooltip.SetMarketMode(mode)
  AM.Database.GetGlobalObject("settings").marketTooltip = mode ~= "full" and mode or nil
end

-- Which prices the tooltip shows (global object "settings"): "stack" (the default, stored as nil) for the whole
-- stack, "single" for a single item. Holding Alt shows the other kind.
AM.Tooltip.PRICE_MODES = { "stack", "single" }

function AM.Tooltip.GetPriceMode()
  return AM.Database.GetGlobalObject("settings").priceTooltip or "stack"
end

function AM.Tooltip.SetPriceMode(mode)
  AM.Database.GetGlobalObject("settings").priceTooltip = mode ~= "stack" and mode or nil
end

-- Nothing is known of an item before the first full scan (unless it was searched): the tooltip says so, instead of
-- "No auctions found", which would be a guess.
local function HasFullScan()
  return AM.Scan.GetLastSuccess() ~= nil
end

local function AddPriceLine(tooltip, label, price, labelColor)
  AM.Tooltip.AddDoubleLine(tooltip, label, AM.FormatMoney(price, true), labelColor or HIGHLIGHT_FONT_COLOR,
    HIGHLIGHT_FONT_COLOR)
end

-- The price at which a merchant sells the item: what a merchant was seen charging, or else
-- the derived price of the known vendor items.
local function GetVendorPrice(itemId)
  return AM.MerchantScanner.GetPrice(itemId) or AM.VendorItems.GetPrice(itemId)
end

AM.Tooltip.AddItemCallback(function(tooltip, itemId, location, count, itemDbKey)
  local mode = AM.Tooltip.GetMarketMode()
  if mode == "off" then
    return
  end
  -- Without a key (the item data is not loaded yet, or the item stands for any level) nothing is known about the
  -- auctions, which is not the same as no auctions: only the vendor price is shown then.
  local listed, listedCount
  if itemDbKey then
    listed, listedCount = AM.ItemStore.Get(itemDbKey)
  end
  local stackCount = count or (location and C_Item.GetStackCount(location)) or 1
  local vendorPrice = GetVendorPrice(itemId)
  -- Market and lowest price are for the whole stack or for a single item (see GetPriceMode); Alt shows the other.
  local byStack = stackCount > 1 and IsAltKeyDown() == (AM.Tooltip.GetPriceMode() == "single")
  local multiplier = byStack and stackCount or 1

  local function AddVendorLine()
    if not vendorPrice then
      return
    end
    if stackCount > 1 then
      AddPriceLine(tooltip, L["TOOLTIP_VENDOR_STACK"]:format(stackCount), vendorPrice * stackCount)
    else
      AddPriceLine(tooltip, L["TOOLTIP_VENDOR"], vendorPrice)
    end
  end

  -- The market price outlives the listings (stale ones are pruned on load), so it is shown whenever
  -- it is known, even if the item is not listed right now.
  local marketPrice = itemDbKey and AM.ItemStore.GetMarketPrice(itemDbKey)
  local marketValue = marketPrice and marketPrice.price

  if (listed or marketValue) and mode == "compact" then
    -- One line: logo, count, lowest price and market value.
    local details = {}
    if listed then
      details[#details + 1] = L["TOOLTIP_MIN_SHORT"]:format(AM.FormatMoney(listed * multiplier, true))
    end
    if marketValue then
      details[#details + 1] = L["TOOLTIP_MARKET_SHORT"]:format(AM.FormatMoney(marketValue * multiplier, true))
    end
    local text = table.concat(details, ", ")
    if listed then
      text = L["TOOLTIP_LISTED"]:format(AM.FormatCount(listedCount)) .. ": " .. text
    else
      text = L["TOOLTIP_NO_AUCTIONS"] .. ", " .. text
    end
    -- No wrapping: the tooltip widens to the line instead of breaking it.
    GameTooltip_AddHighlightLine(tooltip, LOGO .. " " .. text, false)
  elseif listed or marketValue then
    GameTooltip_AddColoredDoubleLine(tooltip, LOGO .. " " .. L["TOOLTIP_TITLE"],
      listed and L["TOOLTIP_LISTED"]:format(AM.FormatCount(listedCount)) or L["TOOLTIP_NO_AUCTIONS"],
      NORMAL_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
    AddVendorLine()
    if marketValue then
      AddPriceLine(tooltip, L["TOOLTIP_MARKET_VALUE_DAYS"], marketValue * multiplier)
    end
    if listed then
      AddPriceLine(tooltip, L["TOOLTIP_MIN_PRICE_SCAN"], listed * multiplier)
    end
  elseif itemDbKey and IsSellable(itemId, location) then
    GameTooltip_AddHighlightLine(tooltip, LOGO .. "  " .. (HasFullScan() and L["TOOLTIP_NO_AUCTIONS"] or L["TOOLTIP_NO_SCAN"]))
    AddVendorLine()
  elseif vendorPrice then
    GameTooltip_AddColoredLine(tooltip, LOGO .. " " .. L["TOOLTIP_TITLE"], NORMAL_FONT_COLOR)
    AddVendorLine()
  end
end)

-- Battle pets have a tooltip of their own that only takes plain lines; the double lines of the full mode are built by
-- AM.Tooltip.AddPetDoubleLine. The mode (full or compact) is the same as for items; a pet is always a single
-- item, so no stack prices. The auction house adds its own lines below ours.
AM.Tooltip.AddPetCallback(function(tooltip, itemDbKey)
  local mode = AM.Tooltip.GetMarketMode()
  if mode == "off" or not itemDbKey then
    return
  end
  local listed, listedCount = AM.ItemStore.Get(itemDbKey)
  local marketPrice = AM.ItemStore.GetMarketPrice(itemDbKey)
  local marketValue = marketPrice and marketPrice.price
  local function Add(text, color)
    color = color or HIGHLIGHT_FONT_COLOR
    tooltip:AddLine(text, color.r, color.g, color.b)
  end
  if not listed and not marketValue and not HasFullScan() then
    Add(LOGO .. " " .. L["TOOLTIP_NO_SCAN"])
    return
  end
  local listedText = listed and L["TOOLTIP_LISTED"]:format(AM.FormatCount(listedCount)) or L["TOOLTIP_NO_AUCTIONS"]

  if mode == "compact" then
    local details = {}
    if listed then
      details[#details + 1] = L["TOOLTIP_MIN_SHORT"]:format(AM.FormatMoney(listed, true))
    end
    if marketValue then
      details[#details + 1] = L["TOOLTIP_MARKET_SHORT"]:format(AM.FormatMoney(marketValue, true))
    end
    Add(LOGO .. " " .. listedText .. (#details > 0 and ": " .. table.concat(details, ", ") or ""))
    return
  end
  AM.Tooltip.AddPetDoubleLine(tooltip, LOGO .. " " .. L["TOOLTIP_TITLE"], listedText, NORMAL_FONT_COLOR,
    HIGHLIGHT_FONT_COLOR)
  if marketValue then
    AM.Tooltip.AddPetDoubleLine(tooltip, L["TOOLTIP_MARKET_VALUE_DAYS"], AM.FormatMoney(marketValue, true),
      HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
  end
  if listed then
    AM.Tooltip.AddPetDoubleLine(tooltip, L["TOOLTIP_MIN_PRICE_SCAN"], AM.FormatMoney(listed, true),
      HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
  end
end)

-- Pressing or releasing Alt switches between stack and single item prices, so redraw the open tooltip.
local altWatcher = CreateFrame("Frame")
altWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
altWatcher:SetScript("OnEvent", function(_, key)
  if (key == "LALT" or key == "RALT") and GameTooltip:IsShown() and GameTooltip.RefreshData then
    GameTooltip:RefreshData()
  end
end)
