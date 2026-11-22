# DungeonJournal architecture

Version 1.3.0 is an internal structural refactor. Player-facing behavior is intentionally unchanged.

## Core
- `Core/Bootstrap.lua`: shared addon namespace, SavedVariables, shared constants.
- `Core/Journal.lua`: runtime controller and journal UI behavior.

## Data
- `Data/Dungeons.lua`: dungeon, quest, boss and loot definitions.
- `Data/Bosses.lua`: verified boss levels and static portrait/display overrides.
- `Data/QuestMaps.lua`: quest map coordinates.
- `Data/QuestChains.lua`: prerequisite chains and prerequisite quest details.
- `Data/QuestRewards.lua`: quest XP, money and reward fallbacks.

## Systems
- `Systems/MapMarkers.lua`: world-map marker lifecycle and map-opening behavior.

## UI data
- `UI/ThemeData.lua`: dungeon themes and artwork configuration.
- `UI/ItemComparisonData.lua`: equipment slot/stat-comparison configuration.

## Maintenance rule
Shared facts should have one source of truth. Corrections to NPC locations, rewards, boss levels, chains or coordinates belong in the appropriate data module rather than duplicated inside runtime UI code.

Localization is intentionally not included in this refactor.


## Localization
Static interface strings live in `Localization/Localization.lua`. The initial languages are English and German. Runtime test commands: `/dj lang de`, `/dj lang en`, `/dj lang auto`. Quest/dungeon source data is intentionally not translated yet.
