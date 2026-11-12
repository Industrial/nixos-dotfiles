local addonName, AM = ...

-- Our own events, so that a module announces that something changed without knowing who shows it (an
-- addon-internal list of listeners, nothing to do with the game's events or its EventRegistry).
-- Listeners run in the order they registered, which is the load order of the files in the .toc: a listener
-- that prepares data (RecipeList) is registered by a file that loads before the ones that redraw (the windows).
--   "PRICES_CHANGED"  the prices or the settings behind them changed (ItemStore: a scan, a search, a reset, a setting)
--   "ITEM_SEARCHED"   the auctions of one item were read from a search and stored (ItemSearch), arguments: itemDbKey (what was stored), itemId (of the item searched)
--   "ITEM_SEARCH_EMPTY"  a search of one item came back complete without any auction (ItemSearch), argument: itemId; nothing was stored
--   "SELL_FILTER_CHANGED"  an item was ignored or no longer ignored in the Sell tab, or the filter for them changed (SellSettings)
--   "SCAN_CHANGED"    the full scan of the auction house started or ended (Scan)
--   "SELL_SCAN_CHANGED" the scan of the items to sell started, advanced or ended (SellScan)
--   "OWN_AUCTIONS_CHANGED"  the player's own auctions changed, or a search told what is ahead of them (OwnAuctions)
--   "CRAFTERS_CHANGED"  who crafts what changed (ProfessionScanner: a scan, a dropped profession, a character or
--                     profession ignored, a character deleted)
--   "BARGAINS_CHANGED"  a bargain rule changed, or a scan or a search found bargains (Bargains)
--   "BARGAIN_SCAN_CHANGED"  the search of the bargain items started, advanced or ended (BargainScan)
--   "MAIN_WINDOW_VISIBILITY"  our window in the auction house was shown or hidden (MainWindow), so the views
--                     of the game know whether they are covered
AM.Events = {}
local Events = AM.Events

local listeners = {}

function Events.Register(name, listener)
  listeners[name] = listeners[name] or {}
  table.insert(listeners[name], listener)
end

function Events.Fire(name, ...)
  if AM.DebugLog.IsEnabled() then
    AM.DebugLog.Log("event", "%s %s", name, AM.DebugLog.DescribeAll(...))
  end
  for _, listener in ipairs(listeners[name] or {}) do
    -- One failing listener is reported but does not keep the others from running.
    xpcall(listener, geterrorhandler(), ...)
  end
end
