# AuctionMaster API

Read-only access to AuctionMaster's auction data for other addons.

## Quick start

Add AuctionMaster to the optional dependencies in your `.toc`, so that it loads before your addon:

```
## OptionalDeps: AuctionMaster
```

```lua
local API = AuctionMaster and AuctionMaster.API
local price = API and API.GetMarketPrice(itemId)  -- copper, or nil if unknown
```

If AuctionMaster is not installed, `price` is `nil` and nothing breaks. If your addon cannot work without it, use `## Dependencies: AuctionMaster` instead and skip the check. The rest of this page is detail.

## Compatibility

Functions are only added, never changed or removed. A function marked "Added in" is missing in older AuctionMaster versions, so check that it exists before calling it: `if API.GetSomething then ... end`. All other functions can be called without a check.

## Functions

All functions only read and are cheap enough to call while drawing: they never scan, open windows, print to chat or change stored data.

* `item` is an item ID (a number, or a string of digits), an item link or an item string such as `"item:41599"`. Equipment and battle pets are priced per item level or species, so pass a link or item string for them: an item ID alone gives `nil`.
* `nil` means unknown. AuctionMaster never returns a stale default, an estimate or a made-up `0`. A missing value is better than a wrong one.

### `GetLowestPrice(item)`
The lowest buyout price per unit in the latest scan or search, in copper (a positive integer), or `nil` when unknown. It reflects one moment: how old that moment is, `GetDataAge` tells.

### `GetMarketPrice(item)`
The typical price for the item over time, in copper (a positive integer), or `nil` when unknown. It is a statistic built from many scans, not a single auction, so it changes slowly and does not depend on how recent the latest scan is.

### `GetDataAge(item)`
The age of the latest data for the item, in seconds (a number), or `nil` when unknown. It applies to `GetLowestPrice` and `GetAvailableQuantity`, not to `GetMarketPrice`. Use it to decide whether the lowest price is fresh enough for you.

### `GetAvailableQuantity(item)`
How many units of the item are for sale with a buyout price in the latest scan or search: the sum of the sizes of all stacks, not the number of auctions (two stacks of 20 are 40). A non-negative integer, or `nil` when unknown. An item the latest data does not list is unknown, not `0`.

### `AddDataChangeListener(listener)`
Calls `listener()` with no arguments once a scan or search has finished storing its results, not once per auction. Returns `true` when added, or `false` when AuctionMaster refuses it because it already has too many listeners (a protection against faulty addons adding them endlessly). Adding a function that is already a listener has no effect and returns `true`. 
