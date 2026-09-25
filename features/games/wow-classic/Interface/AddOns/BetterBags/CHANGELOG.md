# BetterBags

## [v0.5.4](https://github.com/Cidan/BetterBags/tree/v0.5.4) (2026-09-14)
[Full Changelog](https://github.com/Cidan/BetterBags/compare/v0.5.3...v0.5.4) [Previous Releases](https://github.com/Cidan/BetterBags/releases)

- fix: bank/warbank cross-merge + bag-bar highlight; repo/packaging cleanup (#1083)  
    * fix: stop bank/warbank cross-merge; keep bag-bar highlight in sync on X/ESC  
    Two independent bag-visibility bugs.  
    1) Cross bank-type virtual stacking (issue: "items merge across tabs and  
       across bank types" with Unmerge on Interactions off).  
       The virtual stack is keyed only by item.itemHash. On Retail the bank sweep  
       loads the Character Bank (BANK\_BAGS/base bank) and the Warbank  
       (ACCOUNT\_BANK\_BAGS) into one unified itemData and only partitions them into  
       tabs downstream, but Phase7\_ApplyVirtualStacks runs before that partition.  
       With no location component in the hash, an identical item in the Character  
       Bank and in the Warbank collided into one stack: only the root survived in  
       visibleItemsBySlotKey and the other physical pile vanished, so the item  
       appeared to merge across bank types/tabs.  
       Fix: items:GenerateItemHash appends a bank-scope discriminator ("W" when  
       const.ACCOUNT\_BANK\_BAGS[data.bagid], else ""). Character-Bank bags keep the  
       empty scope and still stack together; all Warbank tabs share "W" and still  
       stack together; the two groups can never share a hash. Guarded on  
       const.ACCOUNT\_BANK\_BAGS (Retail-only), so the backpack and non-retail hashes  
       are byte-for-byte unchanged. Scoping by bank type (not tab) is sufficient  
       because within a bank type an item's tab is a function of its category and  
       identical items share a category/tab.  
    2) Bag-bar button highlight stuck lit after closing via the "X" button or ESC.  
       addon:UpdateButtonHighlight was only called from addon.OnUpdate, i.e. only  
       when the backpack was toggled through addon:ToggleAllBags. The theme "X"  
       button calls frame.Owner:Hide directly, and ESC hides the frame widget  
       directly (UISpecialFrames), so neither cleared the Blizzard bag-bar  
       SlotHighlightTexture.  
       Fix: hook the backpack frame's own OnShow/OnHide in OnInitialize to call  
       UpdateButtonHighlight, so the highlight tracks every show/hide path (toggle,  
       X, ESC, direct Hide, fade OnFinished). Hooking our own insecure frame and  
       toggling an insecure texture is taint-free and idempotent with OnUpdate.  
    Tests: new "bank/warbank virtual stacking isolation" cases and a  
    "clears the bag-bar highlight when the backpack frame hides (X / ESC path)"  
    case; init/backpack-button mocks now expose a real bag frame. Full suite  
    946 passing, luacheck clean. Rules documented in virtual-stacks.md (§6) and  
    initialization.md (§6).  
    * chore: remove committed PR-draft junk and stop shipping dev files  
    - Delete 18 stray pr\_*/pr\_description*/pr\_message.txt PR-body drafts and the  
      leftover ask/plans/start/plan.md agent plan. None are referenced by code,  
      tests, or tooling, and all were being bundled into the packaged addon.  
    - Tighten .pkgmeta ignore so dev-only files no longer ship to users: add  
      .context, .vscode, docs, test.lua, .luacheckrc, .luacov, .luarc.json,  
      CLAUDE.md, GEMINI.md, AGENTS.md. test.lua in particular is a multi-thousand  
      line SavedVariables dump used only by the spec harness.  
    - Fix a stale ignore entry: the list had `.roo`, but the tracked file is  
      `.roomodes`; correct it so it actually excludes.  
    test.lua is retained in the repo (spec/debug\_dump\_harness\_spec.lua and  
    spec/bank\_tab\_category\_routing\_spec.lua dofile it) but no longer packaged.  
    Full suite still 946 passing.  