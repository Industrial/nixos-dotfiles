local _, ns = ...

-- Every string the player sees. Other locales override keys in files of
-- their own; a missing key falls back to this one.
local L = setmetatable({}, { __index = function(t, k) return k end })
ns.L = L

L["EXT_NAME"] = "Auctionator"
L["EXT_DESC"] = "Auction prices on item rows, and your shopping lists."
L["PROVIDER_LABEL"] = "Shopping Lists"
L["CATEGORY"] = "Shopping List"
L["SETTINGS_HINT"] = "Prices from your last auction house scan, at the right of EasyFind's item rows. Type a list's name in EasyFind to find it."
L["DECORATOR_LABEL"] = "Auctionator price"

L["OPT_ROW_PRICE"] = "Price on item rows"
L["OPT_ROW_PRICE_TIP"] = "The last scanned auction price at the right of each item row."

L["PRICE_KIND"] = "Auction price"
L["PRICE_AGE_TODAY"] = "scanned today"
L["PRICE_AGE_ONE"] = "scanned yesterday"
L["PRICE_AGE_FMT"] = "scanned %d days ago"

L["CREATE_LIST"] = "Create shopping list"
L["CREATE_LIST_SUB"] = "Create a new shopping list"
L["HINT_CREATE"] = "Name a new list"

L["LIST_SUBTEXT_FMT"] = "Shopping list, %d items"
L["LIST_SUBTEXT_ONE"] = "Shopping list, 1 item"
L["LIST_SUBTEXT_EMPTY"] = "Shopping list, empty"
L["ITEM_SUBTEXT_FMT"] = "On the %s list"
L["TT_ON_LIST_FMT"] = "On your %s list"
L["TT_MORE_FMT"] = "and %d more"

L["TERM_QTY_FMT"] = "x%d"
L["TERM_TIER_FMT"] = "rank %d"
L["TERM_ILVL_FMT"] = "item level %s"
L["TERM_LEVEL_FMT"] = "level %s"
L["TERM_PRICE_FMT"] = "price %s"
L["TERM_CRAFTED_FMT"] = "crafted level %s"
L["RANGE_FMT"] = "%s-%s"
L["RANGE_MIN_FMT"] = "%s+"
L["RANGE_MAX_FMT"] = "up to %s"

L["HINT_SEARCH"] = "Search at the Auction House"
L["HINT_SHOW_LIST"] = "Open the list"
L["MENU_OPEN_LIST"] = "Open the list"
L["NOTE_CATEGORY"] = "Shopping lists"
L["HINT_LINK"] = "Link in chat"

L["MENU_ADD"] = "Add to shopping list"
L["ADD_TARGET"] = "Shopping list"
L["MENU_NEW_LIST"] = "New list..."
L["MENU_NEW_SHOPPING_LIST"] = "New shopping list"
L["MENU_REMOVE_FMT"] = "Remove from %s"
L["MENU_SEARCH"] = "Search at the Auction House"
L["MENU_FIND"] = "Find the item"
L["DIALOG_NEW_LIST"] = "Name the new shopping list"
L["DIALOG_CREATE"] = OKAY or "Okay"

L["ADDED_FMT"] = "%s added to the %s list."
L["ALREADY_FMT"] = "%s is already on the %s list."
L["REMOVED_FMT"] = "%s removed from the %s list."
L["NEED_AH"] = "Open the auction house, then search."
L["NEED_NOTES_FMT"] = "Your shopping lists in Notes need the %s: EasyFind 5.0.0 made Notes an addon of its own."
L["NOT_READY_LISTS"] = "Auctionator's shopping list functions are not available in this version, so shopping list search is off."
L["NOT_READY_PRICES"] = "Auctionator's price functions are not available in this version, so prices are off."
