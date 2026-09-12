Auctionator.Constants.MaxResultsPerPage = 50
Auctionator.Constants.ITEM_LEVEL_THRESHOLD = 0

Auctionator.Constants.AuctionItemInfo = {
  Buyout = 10,
  Quantity = 3,
  Owner = 14,
  ItemID = 17,
  Level = 6,
  MinBid = 8,
  BidAmount = 11,
  Bidder = 12,
  SaleStatus = 16,
}

Auctionator.Constants.PriceIncreaseWarningDuration = 5
Auctionator.Constants.PriceIncreaseWarningThreshold = 40

--FIXME: Added to correct Blizzard error
if CASTING_BAR_ALPHA_STEP == nil then
  CASTING_BAR_ALPHA_STEP = 0.05
end
