-- WoW Forever compatibility shims.
-- Forever runs on the modern (Mainline 12.x) client, where several globals aux
-- relied on in Classic Era were moved into C_* namespaces. Module environments
-- (libs/package.lua) look names up here before _G, so the rest of aux can keep
-- calling the old names. Nothing in here is written to _G.

local _, addon_table = ...
local compat = addon_table.compat
local _G = _G

local function shim(name, replacement)
    if _G[name] == nil and replacement ~= nil then
        compat[name] = replacement
    end
end

shim('GetItemInfo', C_Item and C_Item.GetItemInfo)
shim('GetItemQualityColor', C_Item and C_Item.GetItemQualityColor)
shim('GetCoinTextureString', C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString)
shim('PlaySound', C_Sound and C_Sound.PlaySound)
shim('NumberFont_Normal_Med', _G.NumberFontNormal or _G.GameFontHighlightSmall)

if _G.GetMerchantItemInfo == nil and C_MerchantFrame and C_MerchantFrame.GetItemInfo then
    compat.GetMerchantItemInfo = function(index)
        local info = C_MerchantFrame.GetItemInfo(index)
        if info then
            return info.name, info.texture, info.price, info.stackCount, info.numAvailable, info.isPurchasable, info.isUsable, info.hasExtendedCost
        end
    end
end

-- The auction house UI is an AddOn that loads on demand. aux reads its category
-- table (AuctionCategories) and hides its frame, so make sure it is loaded when
-- the auction house opens.
compat.compat_load_auction_house_ui = function()
    local load = C_AddOns and C_AddOns.LoadAddOn or _G.LoadAddOn
    if not AuctionHouseFrame and load then
        load('Blizzard_AuctionHouseUI')
    end
end
