# BetterBags

## [v0.5.14](https://github.com/Cidan/BetterBags/tree/v0.5.14) (2026-10-02)
[Full Changelog](https://github.com/Cidan/BetterBags/compare/v0.5.13...v0.5.14) [Previous Releases](https://github.com/Cidan/BetterBags/releases)

- Fix load crash on WoW: Forever 1.60.1 (70170): treat WOW\_PROJECT\_CAMELOT as retail (#1117)  
    WoW: Forever build 1.60.1 (70170) added  
    Blizzard\_ProjectConstants/Camelot/ProjectConstants.lua (loaded only on the camelot  
    game type), which sets WOW\_PROJECT\_CAMELOT = 18 and WOW\_PROJECT\_ID =  
    WOW\_PROJECT\_CAMELOT. Earlier builds reported WOW\_PROJECT\_MAINLINE.  
    core/constants.lua derived addon.isRetail from WOW\_PROJECT\_ID == WOW\_PROJECT\_MAINLINE  
    alone, so on 70170 isRetail went false and the Classic branch built const.BANK\_BAGS  
    with [Enum.BagIndex.Bank] as a key. Camelot's Enum.BagIndex is retail-shaped and has  
    no Bank member (Characterbanktab = -2, Keyring = -1), so the addon died at load with  
    "core/constants.lua:162: table index is nil".  
    Fix:  
    - addon.isRetail is now true for WOW\_PROJECT\_MAINLINE or the Camelot project. Every  
      other flavor gate in the addon reads addon.isRetail, so Forever is back on the  
      retail paths it ran before 70170.  
    - addon.isForever is now true from either the TOC flag set by core/forever.lua  
      (still the only signal on pre-70170 builds) or the Camelot project ID.  
    - The check is nil-guarded (WOW\_PROJECT\_CAMELOT ~= nil): WOW\_PROJECT\_CAMELOT only  
      exists on the camelot game type, and nil == nil would otherwise be true wherever  
      both globals are undefined (including the spec environment).  
    Tests (spec/core/constants\_spec.lua, "client flavor detection (WOW\_PROJECT\_ID)"):  
    the 70170 Camelot project with Camelot's real Enum.BagIndex loads without error and  
    resolves to retail + Forever with retail-shaped bank tables and no warbank; the  
    project ID alone sets Forever; pre-70170 (mainline + TOC flag) still works; live  
    retail and Classic Era detection are unchanged. The first two failed with the exact  
    reported "table index is nil" before the fix.  
    Also: add WOW\_PROJECT\_CAMELOT to .luacheckrc read globals, rewrite the detection  
    section of .claude/rules/camelot-forever.md (it said no project ID could identify  
    Forever, which 70170 made untrue), and update core/forever.lua and core/README.md.  