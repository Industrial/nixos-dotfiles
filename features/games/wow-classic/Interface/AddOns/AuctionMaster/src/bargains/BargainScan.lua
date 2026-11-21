local addonName, AM = ...

-- Searches the items of all active bargain rules one after the other (AM.SearchQueue), so the Bargains tab shows the
-- current state of each (the results are stored by AM.ItemSearch like any search, and Bargains remembers them). Data and
-- actions only, the button is in BargainsPanel.
AM.BargainScan = {}
local BargainScan = AM.BargainScan

local DUPLICATE_SECONDS = 5 -- see ItemSearch: an identical result within this time is not announced again

local queue = AM.SearchQueue.Create({
  log = "bargainscan",
  portrait = "bargains",
  event = "BARGAIN_SCAN_CHANGED",
  onNothingListed = function(itemId, started)
    AM.Bargains.OnNothingListed(itemId, started - DUPLICATE_SECONDS)
  end,
})

BargainScan.IsRunning = queue.IsRunning
-- Items searched so far and in all while a scan runs.
BargainScan.GetProgress = queue.GetProgress
BargainScan.Stop = queue.Stop

-- Starts searching the items of the active item rules.
function BargainScan.Start()
  local itemIds = {}
  for _, rule in ipairs(AM.Bargains.GetRules("item")) do
    if rule.active then
      itemIds[#itemIds + 1] = rule.itemId
    end
  end
  queue.Start(itemIds)
end
