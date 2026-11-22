# Forever Dungeon Journal 2.0.32 — Scarlet Monastery tracker

Includes all 2.0.31 Dire Maul, Pusillin, critter and popup fixes. This update adds Scarlet Monastery trash recognition. Restart WoW after installation.

## What changed

- Added 21 wing-specific trash signatures across Graveyard, Library, Armory and Cathedral. Detection accepts the listed NPC ID, exact English name, or a localized name learned from that ID. Matches are restricted to the Scarlet Monastery instance (map 189); outdoor kills cannot choose a wing.
- Four shared trash types can count as legitimate kills, but never choose or change a wing by themselves.
- For a fresh tracker, the recorder no longer treats the Scarlet resolver's uncertain last-selected/default wing as proof. When a shared mob dies first and no reliable wing is known, the tracker records the kill under generic Scarlet Monastery. The first unique mob resolves the wing without losing that first kill's timestamp.
- Existing room/map/door detection remains available. A specific kill can correct a wrong provisional wing. Once confirmed by a specific kill, shared mobs and generic room fallback do not change it.
- Existing boss identification, duplicate-event merging, critter filtering, and run-resume behavior are retained. The new detection is for the tracker/run log; it does not change the journal's manual map-wing selection or rewrite learned door locations.

## Exact new wing-specific mob list

### Scarlet Monastery: Graveyard

| NPC ID | Mob |
| --- | --- |
| 4283 | Scarlet Sentry |
| 4293 | Scarlet Scryer |
| 4306 | Scarlet Torturer |
| 4308 | Unfettered Spirit |
| 6426 | Anguished Dead |
| 6427 | Haunting Phantasm |

### Scarlet Monastery: Library

| NPC ID | Mob |
| --- | --- |
| 4287 | Scarlet Gallant |
| 4288 | Scarlet Beastmaster |
| 4291 | Scarlet Diviner |
| 4296 | Scarlet Adept |
| 4304 | Scarlet Tracking Hound |

### Scarlet Monastery: Armory

| NPC ID | Mob |
| --- | --- |
| 4286 | Scarlet Soldier |
| 4289 | Scarlet Evoker |
| 4290 | Scarlet Guardsman |
| 4292 | Scarlet Protector |
| 4297 | Scarlet Conjuror |

### Scarlet Monastery: Cathedral

| NPC ID | Mob |
| --- | --- |
| 4294 | Scarlet Sorcerer |
| 4300 | Scarlet Wizard |
| 4301 | Scarlet Centurion |
| 4302 | Scarlet Champion |
| 4303 | Scarlet Abbot |

## Shared mobs — count kills, do not choose a wing

| NPC ID | Mob | Shared wings |
| --- | --- | --- |
| 4295 | Scarlet Myrmidon | Armory / Cathedral |
| 4298 | Scarlet Defender | Armory / Cathedral |
| 4299 | Scarlet Chaplain | Library / Cathedral |
| 4540 | Scarlet Monk | Library / Cathedral |

No name-prefix inference is used. Other unlisted or renamed mobs still need the existing observed-creature/XP evidence to count, and do not independently identify a wing.

## Verify in-game

Use fresh runs for first-kill tests, with tracker display enabled.

1. Graveyard: kill a Scarlet Sentry, Scryer or Torturer first. Expect Graveyard and its boss list.
2. Library: kill a Beastmaster, Tracking Hound or Gallant first. Expect Library.
3. Armory: kill a Soldier or Conjuror first. Expect Armory.
4. Cathedral: kill a Sorcerer, Wizard or Centurion first. Expect Cathedral.
5. Shared first kill: if the room/door cannot identify the wing, a Myrmidon or Defender alone should not guess Armory or Cathedral. Kill a unique mob next; the title/boss list should resolve while the timer retains the earlier real kill.
6. In confirmed Armory, killing Defenders/Myrmidons must not switch to Cathedral. In confirmed Cathedral, Monks/Chaplains must not switch to Library.
7. Kill a critter first: no new run. Kill mobs outdoors: no dungeon run.
8. Move through rooms after confirmation: the tracker should retain the confirmed wing.
9. If a listed mob fails, target it and use `/dj rlog`; record its NPC ID, name and candidate wing. `/dj where` reports the existing room/map/door detection.

These are Classic-reference NPC IDs and wing assignments, with exact-name fallbacks for Forever. Live Forever testing is still needed, especially if its mobs were renamed, renumbered, or moved between wings. Existing saved runs are not retroactively cleaned up. This update does not redesign the existing ambiguous same-map run-resume behavior; fresh runs give the clearest first-kill test.

## Checks completed

All 27 previous event scenarios and 10 additional Scarlet scenarios passed. Every one of the 54 total wing-specific NPC IDs was tested; all 21 new Scarlet exact-name matches and the four shared IDs were checked independently. Actual Dire Maul boss data, Herod identification, and Pusillin timer behavior passed. All 66 Lua files compile under Lua 5.1. These are simulated checks, not a live dungeon test.

## Files changed since 2.0.31

- `Data/RunLogWings.lua`: Scarlet-specific and shared trash data.
- `Systems/RunLog.lua`: shared-trash eligibility and ignoring uncertain Scarlet fallback for new detection.
- `ForeverDungeonJournal.toc`: version 2.0.32.
- `SCARLET-TRACKER-FIX.md`: this checklist. `TRACKER-WING-FIX.md` remains the historical 2.0.31 change list.

## Sources

Wing membership was cross-checked against the [original BradyGames Scarlet Monastery guide](https://ptgmedia.pearsoncmg.com/imprint_downloads/brady/wow/scarlet_monastery/scarlet_monastery_lr.pdf) and the [Scarlet Monastery mob roster](https://warcraft.wiki.gg/wiki/Scarlet_Monastery_mobs). IDs were checked against this [NPC ID reference](https://gist.github.com/Macumbafeh/c92a97c287d6aece05b61f51959b8dcb). Shared mob types were deliberately excluded from wing selection.
