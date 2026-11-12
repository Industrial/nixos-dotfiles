local addonName, AM = ...

-- Generated from changelog.src.md by tools/changelog.js, do not edit.
AM.ChangelogMarkdown = [====[
# Changelog

## 11.6.3

- Full scan: Stops waiting sooner when the auction house does not answer, and starts again by itself as soon as the server allows it
- Bags: Fixed a potential tainting issue when clicking bag items

## 11.6.2

- Full scan: Fixed the scan occasionally not finishing when the auction house is opened for the first time after logging in

## 11.6.1

- Item tooltips: Recipes in the Sell tab show the market data of the recipe, not of the item it makes

## 11.6.0

- Auctions tab: Undercut auctions are marked right in the list of the game and listed first, and your auctions are checked as soon as you open the tab

## 11.5.7

- Item tooltips: New option to hide the disenchant materials

## 11.5.6

- Auctions tab: Cancel auctions with one click, you only get asked if cancelling costs gold
- Auctions tab: Fixed your auctions showing "In front" although others at the same price were listed before yours

## 11.5.5

- Professions: Skill Recommendations no longer overlap the craftable count in the recipe list

## 11.5.4

- Professions: New Skill Recommendations list shows the cheapest recipes to level up at a glance, with a hint what to do with the result

## 11.5.3

- Other addons: Can now show AuctionMaster's prices and quantities (addon authors: see `API.md` in the addon folder)

## 11.5.2

- WoW Forever is supported again. It was disabled in the releases after 11.3.2, as it could not be tested since the beta ended

## 11.5.1

- Side panels: Now look like the auction house itself

## 11.5.0

- Buy tab: New Bargains tab beside the auction search. Create bargain filters for specific items or for whole groups of items, such as a category or quality, and find the cheap deals after a full scan

## 11.4.1

- Auctions tab: Your auctions are sorted by undercut status, the worst on top
- Auctions tab: The scan button is now called "Scan Auctions"

## 11.4.0

- Auctions Tab: Added a side panel listing your active auctions with time remaining, undercut severity colors (configurable in Sell options), and quick-cancel buttons
- Tooltip Settings: Added an option for market data tooltips to show full, compact or no data
- Item Tooltips: Market value and minimum price now display for the full stack; hold 'Alt' to view single-item pricing
- Collapsible Panels: The side panels on the Buy, Sell, and Recipes tabs can now be reopened via a button in the title bar
- Scan Indicators: Active scans now display a moving light and "Scanning..." text in the title bar, toggleable via "Emphasized scan visualization"
- EllesmereUI Support: The logo ring, side panels and objective tracker are now compatible with EllesmereUI and similar visual overhauls
- Special Thanks: A huge thank you to MessajahSWE for the extensive and constructive feedback that directly shaped many of the improvements in this update
- Prices: Equipment is now priced per item level and battle pets per species, so a level 6 and a level 74 bow no longer share one price. Earlier market data of equipment and pets starts over

## 11.3.2

- Shopping list: crafted items are removed from the list

## 11.3.1

- Objective tracker: hover an item of the shopping list to see where it is (bags, bank and mail)
- Objective tracker: an icon in front of a missing item shows whether it is cheapest at the auction house or at a vendor
- Shopping list: items bought at the auction house count as soon as they are bought, and items you mail to a crafter as soon as they are sent

## 11.3.0

- Disenchanting: AuctionMaster learns what your disenchants yield; tooltips of uncommon items on WoW Forever show the materials, their chance and value, more qualities will follow
- Sell tab: advises "Disenchant" for gear whose materials are worth more, if one of your characters can disenchant

## 11.2.1

- Sell tab: fixed an occasional error when posting an item

## 11.2.0

- Sell tab: your bag items slide out beside the auction house with their value after the auction house fee and a hint to sell, vendor or keep them; a click selects the item for sale
- Sell tab: items you never want to sell can be ignored with a right click and are then hidden; the filter menu has a "Show ignored items" option to bring them back

## 11.1.0

- Shopping list: completely revamped - instead of a separate window it is now built natively into WoW's own interface, in the auction house, the profession windows and the objective tracker
- Objective tracker: the shopping list is shown in the game's objective tracker
- Buy tab: the shopping list now slides out beside the auction house while the Buy tab is shown, with a button to search the next missing ingredient
- Profession window: the recipes of your shopping list that belong to the open profession are pinned on top of the recipe list under a "Shopping List" category
- Minimap button: removed, as it only opened the separate shopping list window, which no longer exists

## 11.0.1

- Recipes tab: New button next to the character filter of the recipes list: a window to ignore single professions or whole characters
- Shopping list: Deleted characters can be removed with the × in the crafter menu of the shopping list, which deletes their list and recorded recipes
- Professions: A profession a character has dropped is forgotten automatically the next time that character logs in

## 11.0.0

- New AuctionMaster tab, integrated into the auction house. It presents a list of all recipes your characters know, which you can filter by different criteria to find the most lucrative recipes.
- Recipes tab: new "Filters" menu with the options "Hide losses" and "Hide rarely listed" (items that are only seldom offered in the auction house, so there is probably no market for them)
- Shopping list: one list per crafter instead of custom lists. A recipe lands on the list of the character that crafts it
- Shopping list: shows what the missing ingredients cost at the auction house, the expected profit, and has buttons to clear the list and to search the next missing ingredient in the auction house
- Shopping list: a click on a recipe name shows only its ingredients (the icon still searches it in the auction house), a badge with the recipe name removes the filter again
- Shopping list: new options choose whether adding a recipe opens the shopping list window, separately for the profession window and the auction house
- Searching or selling an item in the auction house now updates its auction count, lowest price and market price right away, without waiting for the next full scan
- Ingredients are priced at their lowest auction price while the latest scan or search is recent (60 minutes by default), else at the market price. This time and the threshold of the "Frequent" recipe filter are set on the "Market price" options page

## 10.3.1

- Reagents that one of your characters can craft are priced by their recipe when that is cheaper than buying them
- After an update, a short message in the chat tells what is new, with a link that opens the full changelog (also `/am changelog`)
- WoW Forever: adjusted the profession window to Blizzard's new "Recipe lists" placement

## 10.3.0

- Recipe pages of the profession window show the crafting cost, the market value (auction price minus the 5% cut, or the vendor price if higher) and the profit per craft. 

## 10.2.2

- Market price now uses percentiles for different item categories, with lower default values, so extremely overpriced listings are ignored
- The percentiles for market prices can be configured in the new "Market price" options section
- Fixed compatibility issue with MinimapButtonButton

## 10.2.1

- Removed the undercut feature: auctions of the same price are sold last added first, so undercutting by a copper is pointless

## 10.2.0

- Shopping lists in a window of their own (`/am list`): add recipes with the new button in the profession window, their reagents are summed up and compared with what you carry. Create several lists (named after their first recipe, or rename them with the button next to the selector) and switch between them with the selector
- Minimap button that toggles the shopping list; drag it to move it around the minimap
- Options panel (AddOns settings, or the cogwheel in the auction house) with an "Appearance" section to hide the minimap button

## 10.1.2

- Scanned prices are now stored per faction (existing data is kept for the current character's faction)
- Merchant prices are remembered while visiting merchants, as groundwork for crafting cost estimates
- Item tooltips show the merchant price of items sold by merchants, multiplied by the quantity of a stack
- Tooltips of recipe ingredients in the profession window show auction and merchant prices, multiplied by the quantity the recipe needs

## 10.1.1

- Double-clicking an auction in the sell tab opens the buy tab for that item, with the quantity preselected up to that auction

## 10.1.0

- Selecting an auction in the sell tab now undercuts its price by one copper instead of matching it (hold Alt to use the same price)

## 10.0.2

- Updated for Mists of Pandaria Classic
- Added scan progress message to AuctionMaster logo

## 10.0.1

- Updated for Retail / Midnight

## 10.0.0

- First iteration of AuctionMaster rewrite for the new AuctionHouse API
- Scanning auctions when opening the AuctionHouse
- Displaying current low prices and market value in item tooltip
- Added legacy AuctionMaster portrait logo to the auction house, with animation
- Market value uses a time-weighted average that persists across scans
]====]

-- Chat message per version and language (enUS is the fallback).
AM.ChangelogAnnounce = {
  ["11.6.3"] = { silent = true },
  ["11.6.2"] = { silent = true },
  ["11.6.1"] = { silent = true },
  ["11.6.0"] = { enUS = "Auctions tab reworked, undercut auctions are marked right in the game's list", deDE = "Auktionen-Tab überarbeitet, unterbotene Auktionen direkt in der Liste markiert" },
  ["11.5.7"] = { silent = true },
  ["11.5.6"] = { silent = true },
  ["11.5.5"] = { silent = true },
  ["11.5.4"] = { enUS = "Skill Recommendations in your profession windows: Find the cheapest recipes to level", deDE = "Skill-Empfehlungen in den Berufsfenstern: Die günstigsten Rezepte zum Leveln finden" },
  ["11.5.3"] = { silent = true },
  ["11.5.2"] = { silent = true },
  ["11.5.1"] = { silent = true },
  ["11.5.0"] = { enUS = "New Bargains tab: Easily find cheap items and deals", deDE = "Neuer Schnäppchen-Reiter: Einfach günstige Gegenstände und Angebote finden" },
  ["11.4.1"] = { silent = true },
  ["11.4.0"] = { enUS = "New Undercut Scanner: Find and cancel undercut listings in the Auctions tab", deDE = "Neuer Unterbietungs-Scanner: Unterbotene Auktionen im Reiter Auktionen finden und abbrechen" },
  ["11.3.2"] = { enUS = "Crafted recipes leave the shopping list", deDE = "Hergestellte Rezepte verschwinden von der Einkaufsliste" },
}
