# Bartender4

## [4.19.0](https://github.com/Nevcairiel/Bartender4/tree/4.19.0) (2026-11-16)
[Full Changelog](https://github.com/Nevcairiel/Bartender4/compare/4.18.4.1...4.19.0) [Previous Releases](https://github.com/Nevcairiel/Bartender4/releases)

- Replace the Blizzard status tracking bars with a custom implementation  
    The module used to reparent Blizzard's StatusTrackingBarManager into a  
    Bartender bar and disable its edit mode behaviour. It now owns its manager  
    and both bar containers, and no longer touches the Blizzard manager, its  
    containers or the edit mode.  
    Only the leaf bar templates are still taken from Blizzard, since they hold  
    the per-client rules for experience, reputation, honor, artifact, azerite  
    and house favor.  
- Add the totem bar to the WoW Forever presets  
    The totem bar takes the place of the stance bar, as no class has both.  
    In the three bars stacked preset, which has no stance bar, it sits above  
    the action bars with the pet bar moved up above it.  
- Add key bindings and readable binding names for the totem bar  
    The buttons are listed in the key binding UI of WoW Forever through a  
    separate bindings file, and show the same names in LibKeyBound.  
    The totem buttons are numbered in the order they are shown in (earth,  
    fire, water, air), which differs from the order of the totem slots their  
    frame names are based on.  
- Remove the classic XP and Reputation bar modules  
    All classic clients have moved to the StatusTrackingBarManager, so the  
    MainMenuExpBar and ReputationWatchBar frames these modules wrapped no  
    longer exist on any client.  
- Replace the Blizzard totem bar with a fully custom implementation  
    The old module reparented the protected MultiCastActionBarFrame, which  
    EditMode repositions in combat, where it cannot be moved back.  
    The new bar is built from LibActionButton buttons for summon, the four  
    totems and recall, with secure flyouts to assign totems and to switch  
    between the summon spells. As a ButtonBar it supports padding, growth  
    direction, zoom and the other button options.  
    It is only loaded in WoW Forever for now. The settings of the old module  
    are reused, so the bar keeps its position.  
- Let bars report mouse over content outside of their overlay  
    A bar can implement IsMouseOverContent to count additional frames as  
    part of the bar for the mouse-over fade, eg. flyouts that extend beyond  
    the bar overlay.  
- Add a button margin and a fixed button count to the ButtonBar layout  
    button\_margin reserves space around every button for art that extends  
    beyond the button frame, so that the bar overlay covers it.  
    fixed\_button\_count sizes the bar for a set number of buttons instead of  
    the number of buttons currently shown, so a bar keeps its size while its  
    buttons come and go.  
    Both default to the previous behavior for all existing bars.  
- Implement a fully custom vehicle button  
    Stop reusing the vanilla button, as its encumbered with EditMode hooks  
    and can cause taint issues depending on how its anchored.  
    None of the vehicle functions are protected, so this button is a lot  
    simpler and avoids one source of bugs.  
