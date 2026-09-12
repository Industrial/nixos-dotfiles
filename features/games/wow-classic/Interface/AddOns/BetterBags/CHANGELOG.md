# BetterBags

## [v0.4.10](https://github.com/Cidan/BetterBags/tree/v0.4.10) (2026-07-03)
[Full Changelog](https://github.com/Cidan/BetterBags/compare/v0.4.9...v0.4.10) [Previous Releases](https://github.com/Cidan/BetterBags/releases)

- fix(views): bypass custom group-filtering when bank slots panel is active (#988)  
    * fix(views): bypass custom group-filtering when bank slots panel is active  
    - What changed: Modified views/gridview.lua to skip custom section/category group-filtering when the bank slots panel is active (bag.kind == const.BAG\_KIND.BANK and database:GetShowBankTabs() is true).  
    - Why: When the bank slots panel is active, custom BetterBags group tabs at the bottom are hidden, but custom group-filtering remained active. This filtered out all categories that did not belong to the hidden active group, hiding most items from the view and leaving the player with no way to change the group.  
    - Tests: Added a comprehensive unit test file spec/views/gridview\_spec.lua to reproduce and verify the fix. Also updated spec/views/bagview\_spec.lua to ensure its stubs are compatible when running the spec suite in bulk.  
    * Revert "fix(views): bypass custom group-filtering when bank slots panel is active"  
    * fix(views): bypass custom group-filtering when bank slots panel is active  
    - What changed: Modified views/gridview.lua to skip custom section/category group-filtering when the bank slots panel is active (bag.kind == const.BAG\_KIND.BANK and database:GetShowBankTabs() is true).  
    - Why: When the bank slots panel is active on Retail, custom BetterBags group tabs at the bottom are hidden, but custom group-filtering remained active. This filtered out all categories/items that did not belong to the hidden active custom group, causing different/wrong/missing items to be shown in different tabs and leaving the player with no way to change the active group.  
    - Tests: Added a clean, isolated unit test file spec/views/gridview\_spec.lua to reproduce and verify the fix.  
    * test(views): resolve global test state pollution and module stub collisions  
    - Fix global test state pollution and duplicate module registration errors by updating 'ResetModuleStub' in 'spec/helpers/addon\_loader.lua' to safely reset 'loadedModules[filePath]' and making 'filePath' optional.  
    - Update 'spec/views/bagview\_spec.lua' to align SectionFrame's mock prototype with gridview\_spec, preventing views.lua GetOrCreateSection from crashing on a nil SetTitle call when run in bulk.  
    - Prepend LoadBetterBagsModule calls with ResetModuleStub across spec files (bankslots\_spec, money\_spec, section\_spec, groups\_spec, movementflow\_spec, sort\_spec, themes\_spec) to guarantee clean reloading and isolate mock mutations.  
    - Convert themes\_spec's 'after\_each' reset logic to 'teardown' to avoid prematurely wiping the real Themes module from the addon during active tests.  
    - Verify 100% of the test suite (865 successes) passes without regressions.  
- fix: count free bank slots per selected Blizzard tab in Retail (#987)  
    - Restrict free slot counting to the currently selected bank/warbank tab (blizzardBankTab) in items:UpdateFreeSlots when Show Bank Tabs is enabled on Retail WoW.  
    - Previously, UpdateFreeSlots summed free slots across all character bank bags or all warbank bags irrespective of the selected tab, resulting in identical free slot counts displayed across all tabs.  
    - Added comprehensive unit tests in spec/items\_spec.lua to verify the slot-filtering behavior, ensuring it is restricted on Retail and falls back to normal sum/classic behavior when appropriate.  
    - Confirmed passing tests under Lua 5.1 and verified code quality using luacheck.  
- fix(items): defensively handle secret and incomplete client-side items (Issue #984)  
    - Add defensive fallbacks and guards across items module entry points to handle nil/incomplete return values from WoW APIs (GetItemInfo, GetDetailedItemLevelInfo, etc.)  
    - Safely populate defaults for itemInfo, containerInfo, questInfo, and transmogInfo to prevent lua index/nil errors.  
    - Ensure items:GetCategory and items:GenerateItemHash fall back gracefully without indexing or formatting crashes.  
    - Add robust unit tests in spec/items\_spec.lua validating no crashes and proper fallback state under mock nil WoW API environments.  
- fix: restore group tabs on slots panel close if groups are enabled (#985)  
    On fresh load, early GenerateGroupTabs pre-hides the group tabs. When the slot panel is shown immediately after, it captures self.tabsWereShown = false. When toggling 'Show Bags' off, OnClose sees false and never shows them again.  
    This fix introduces a database-driven fallback check in bankslots.lua, bagslots.lua, and era/bagslots.lua so that when closing the slots panel, if self.tabsWereShown is false but groups are enabled, the group tabs frame is correctly restored.  
    We also added a TDD unit test to verify this fallback behavior.  