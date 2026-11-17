Added an ElvUI theme for BetterBags Next, multi-tier and per-category item sorting, real-category gear sets, Gamepad UI support, and Warbank deposit improvements.

## New

- **ElvUI theme for BetterBags Next**: A new ElvUI theme for BetterBags Next uses ElvUI's art and follows your ElvUI colors, fonts, font sizes, bag text fonts, quest colors, icon crop, and Thin Borders outlines, updating live as you change ElvUI settings (Thin Borders needs a reload).
- **Multi-tier item sorting and new sort keys**: Each bag's Layout tab Order section now has Item Order, Then By, and And Then By dropdowns with sort options including Equipment Slot, Item Type, Expansion, Count, Sell Price (Stack), and Sell Price (Each). Existing saved sort orders migrate automatically.
- **Per-category item sorting**: The Categories settings page now includes an Item Order tab where you can enable Own Item Order and pick up to three sort tiers for any category. Per-category sort orders are also included when exporting and importing categories.
- **Upgrade Track item sort order** (Retail and WoW: Forever only): Added an Upgrade Track option to Item Order dropdowns that groups gear by its upgrade track, highest track first, then by current item level, instead of mixing tracks with overlapping item levels.
- **Gamepad UI support in bag windows** (WoW: Forever only): With Blizzard's Gamepad UI on, navigate backpack, bank, and Next vendor or guild bank windows with the d-pad, switch focus with triggers, use A, X, B, and the radial menu, and see button legends. Switch between mouse and gamepad anytime; focus and cursor position return after combat.
- **Dim backpack items refused by the guild bank** (Retail and WoW: Forever only): While the guild bank is open, backpack items that cannot be deposited into it are dimmed in both bag designs, matching how items refused by the Warbank or Auction House are shown.
- **Warbank deposit options in bank menu and settings**: When a Warbank is available, the classic bank's left-click menu now has Deposit All Warbound Items and Include tradeable reagents. Both designs also gain an Include Tradeable Reagents toggle in a new Warbank section on the Bank settings page's General tab.
- **Buyback tab flashes on vendor sales in Next**: Selling items while BetterBags Next's vendor panel is open now pulses the Buyback tab with your theme's glow so it is easier to spot where sold items can be recovered.

## Improved

- **Gear sets behave like regular categories**: Each Equipment Manager set is now a real category in your order, so manual categories and rules above it can take its items. Sets keep settings across renames, clear them when deleted, and support colors, Hide In, Used In, Ignored Items, and Own Item Order.
- **BetterBags Next vendor works with TradeSkillMaster**: BetterBags Next's vendor and TradeSkillMaster's vendor window now take turns instead of opening together. A new TradeSkillMaster button in Next's vendor header switches to TSM's window, and TSM's WoW UI button returns to Next's vendor.
- **Clearer side tabs in Default, Ember, and Quiet themes**: Unselected side tabs in BetterBags Next's Default, Ember, and Quiet themes now use a solid fill, a border edge, and higher-contrast text across all panels, with a highlighted border on the selected tab.
- **Sort Bank no longer deposits reagents**: Clicking Sort Bank in the classic bank now only sorts your bank items instead of silently depositing reagents into your character bank.

## Fixed

- **Deposit All Warbound Items warns before ending refunds**: Using Deposit All Warbound Items in either bag design now checks for refundable warbound items in your bags and asks for confirmation before depositing them and removing their refund timers.
- **Empty group hint clipped in classic bags**: The hint shown in an empty group's tab in classic bags is no longer clipped on the left or overlapping Free Space.
- **Papercraft margin note mirrored on left-side panels**: On BetterBags Next's Papercraft theme, the handwritten margin note on the bank, vendor, and guild bank panels now reads the right way round and sits at the same distance from the inner edge as on the backpack.
- **Specialized bag slot icons hidden on Papercraft**: Empty slot icons for reagent bags, quivers, and profession bags now tint using the theme's color so they are clearly visible on Papercraft's light paper slots instead of blending in.
- **Quest icons lingering on Classic bag slots** (Classic only): Theme quest icons and Masque quest marks on Classic item buttons no longer remain stuck on empty slots, subsequent items, or after switching to a theme without quest art.
- **Search maxlevel filter on upgrade track gear**: The maxlevel search keyword now finds the fully upgraded item level of upgrade-track gear instead of reading 0.
