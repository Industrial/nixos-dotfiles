# Bartender4

## [4.19.2](https://github.com/Nevcairiel/Bartender4/tree/4.19.2) (2026-11-18)
[Full Changelog](https://github.com/Nevcairiel/Bartender4/compare/4.19.1...4.19.2) [Previous Releases](https://github.com/Nevcairiel/Bartender4/releases)

- Fix the quest XP of the XP bar in a few edge cases  
    The rested XP is shown up to the end of the bar on clients which show it  
    when it reaches beyond the level, a quest which was turned in is forgotten  
    even while the XP bar is not shown, the level up animation is reset when it  
    was interrupted, and nothing is done at all while the quest XP is disabled.  
