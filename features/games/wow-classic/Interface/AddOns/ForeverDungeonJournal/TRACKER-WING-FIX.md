# Forever Dungeon Journal 2.0.31 — wing detection and critter fix

Built 10 November 2026. Includes the previous larger tracker-close popup text and tighter spacing.

## Exact behavior changes

1. A death is checked before creating a run. Critters observed through your target, mouseover, nameplates, or party/raid targets are excluded from kills and cannot start a run. Player-controlled pets and the existing excluded creature categories are also rejected.
2. An unseen, unidentified death is no longer enough to start or add a kill. The recorder needs an observed attackable, non-critter creature, a recognized wing-specific mob/boss, a successful boss event, or a positive mob-XP message. This deliberately favors missing an unidentifiable kill over starting on an unidentified critter. At level 60, unlisted trash that is never observed and supplies no XP may be skipped.
3. Eligible UNIT_DIED reports can now start the first run; previously that path required an already-active run. Target observations are retained before the run starts, including name-only observations when Forever hides GUIDs. Party/raid target changes are monitored too.
4. The first recognized Dire Maul trash kill selects East, West, or North immediately. Matching uses the NPC ID, the exact English name, or a localized name previously observed for a listed ID. There is no broad “all trees” or “all ogres” guess.
5. Opening the gossip conversation with Pusillin starts an East run and its timer if no kill has started it already. Selecting Pusillin as a target does not start it. Repeated conversations do not reset it. This requires your own client to receive Pusillin's GOSSIP_SHOW event and expose his NPC ID or recognizable name; another party member talking is not itself a start signal for your client.
6. Talking does not mark Pusillin dead, award XP, or create a fake trash kill. A later first trash kill does not replace the conversation start time.
7. A run whose wing was unresolved can be corrected after its first trash kill, preserving the real kill timestamps and rebuilding boss classifications.
8. Once a wing is confirmed by a recognized kill/conversation, room-name changes cannot overwrite it. Killing a signature mob/boss in a different wing closes the previous wing's log and starts a separate run for that wing. The previous run's kills stay in its log.
9. Seeing an old corpse cannot start a fresh run or switch the current run into another wing.
10. Leaving and re-entering still resumes an eligible open run. A Pusillin-only run is retained for this purpose. A different creature instance-copy ID still starts a fresh run.
11. Existing journal boss data is also used to correct wings for Scarlet Monastery, Blackrock Spire, and Stratholme, scoped to their instance maps. No new trash mappings were added for those three complexes. Shared/ambiguous boss matches do not choose a wing.
12. `/dj rlog` now prints the target's candidate wing and whether its death has sufficient evidence to count. This helps diagnose Forever-specific IDs/names.

Existing saved historical kills are not deleted or retroactively rewritten by installing this update. Existing rare-sighting, player-death and Need-roll run creation behavior is unchanged. This change addresses kill-triggered starts and adds Pusillin gossip.

## Exact Dire Maul trash signatures

These are Classic-reference IDs with exact-name fallbacks, not a claim that all 33 IDs have been verified live in Forever. Newly renamed/replaced mobs need an in-game check. Unknown/shared mobs never guess a wing, though an observed eligible trash kill can still start a run using the existing location detection.

### Dire Maul: East

| NPC ID | Mob |
| --- | --- |
| 13022 | Whip Lasher |
| 13276 | Wildspawn Imp |
| 11461 | Warpwood Guardian |
| 11462 | Warpwood Treant |
| 11464 | Warpwood Tangler |
| 11465 | Warpwood Stomper |
| 13021 | Warpwood Crusher |
| 13196 | Phase Lasher |
| 13197 | Fel Lash |
| 11451 | Wildspawn Satyr |
| 11452 | Wildspawn Rogue |
| 11453 | Wildspawn Trickster |
| 11454 | Wildspawn Betrayer |
| 11455 | Wildspawn Felsworn |
| 11456 | Wildspawn Shadowstalker |
| 11457 | Wildspawn Hellcaller |

### Dire Maul: West

| NPC ID | Mob |
| --- | --- |
| 11458 | Petrified Treant |
| 11459 | Ironbark Protector |
| 11469 | Eldreth Seether |
| 11470 | Eldreth Sorcerer |
| 11471 | Eldreth Apparition |
| 11472 | Eldreth Spirit |
| 11473 | Eldreth Spectre |
| 11475 | Eldreth Phantasm |
| 11480 | Arcane Aberration |
| 11483 | Mana Remnant |
| 11484 | Residual Monstrosity |

### Dire Maul: North

| NPC ID | Mob |
| --- | --- |
| 11441 | Gordok Brute |
| 11444 | Gordok Mage-Lord |
| 11445 | Gordok Captain |
| 11448 | Gordok Warlock |
| 11450 | Gordok Reaver |
| 13036 | Gordok Mastiff |

## In-game verification checklist

Use a fresh dungeon copy/run for start tests, and enable the tracker for your group (or enable solo tracking if testing alone). Restart WoW before testing so the new data file in the addon manifest is loaded.

- East: kill a rat/critter before fighting trash. No new tracker/run should appear.
- East: kill a Whip Lasher without talking to Pusillin first. The tracker should start as **Dire Maul: East**, with East bosses and a timer starting at the kill.
- East: on another fresh run, talk to Pusillin before killing anything. The tracker should start as **Dire Maul: East**; Pusillin should still be alive in the boss list. Wait, then kill trash: elapsed time must not reset.
- East: target Pusillin without opening his dialogue. This alone should not start a run.
- East: kill Wildspawn Imps/Pusillin. Trash and Pusillin should be recorded once each despite duplicate death events.
- West: first kill a Petrified Treant or Arcane Aberration. Expect **Dire Maul: West**.
- North: first kill a Gordok Brute, Mage-Lord or Mastiff. Expect **Dire Maul: North**.
- Move between rooms in a confirmed wing. Its title and boss list should remain stable.
- If continuing from West into North in the same instance, kill a listed North mob. Expect a separate North log, with the West log preserved.
- Leave and re-enter the same copy. Expect the same open run. Reset and enter a new copy; the first eligible kill should create a new run.
- If a listed mob fails to identify the wing, target it and use `/dj rlog`; provide the printed NPC ID/name/map context and the expected wing.

## Validation completed

27 simulated event scenarios passed, plus independent checks of all 33 trash signatures, actual Dire Maul boss-data integration, and the displayed timer preserving Pusillin's conversation start. All 66 Lua files compile under Lua 5.1. ZIP integrity and installed-file equality are checked during packaging/install. These checks do not substitute for a live Forever dungeon test.

## Files changed

- `Data/RunLogWings.lua` — new shared wing signature table and instance-map groups.
- `Systems/RunLog.lua` — eligibility checks, pre-run observations, wing resolution, Pusillin gossip, and debug output.
- `Systems/RunLogUI.lua` — timer reads the optional conversation-start timestamp.
- `ForeverDungeonJournal.toc` — version 2.0.31 and loads the new data file before the recorder.
- `TRACKER-WING-FIX.md` — this exact change list and verification checklist.

## Reference material and confidence

- [Dire Maul East guide](https://www.icy-veins.com/wow-classic/dire-maul-east-dungeon-guide) and [Pusillin route](https://www.warcrafttavern.com/wow-classic/guides/dire-maul-east) for East encounters and the conversation sequence.
- [Dire Maul West guide](https://www.icy-veins.com/wow-classic/dire-maul-west-dungeon-guide) and [West pylon enemies](https://www.warcrafttavern.com/forever/guides/dire-maul-west) for West trash families.
- [Dire Maul North guide](https://www.icy-veins.com/wow-classic/dire-maul-north-dungeon-guide) for North encounters and Gordok trash.
- [Classic NPC ID reference](https://gist.github.com/Macumbafeh/c92a97c287d6aece05b61f51959b8dcb), [Whip Lasher](https://classicdb.ch/?npc=13022), [Gordok Reaver](https://classicdb.ch/?npc=11450), and [Phase Lasher observations](https://us.forums.blizzard.com/en/wow/t/phase-lasher-and-whip-lasher-arent-immune-to-the-correct-schools-of-magic-also-dont-change-phase-or-immunities/402779) for reference IDs. Only the default Phase Lasher ID is listed; other forms can match by exact name.

The screenshot also directly shows Whip Lasher and Wildspawn Imp in the Pusillin area. Live Forever verification of the remaining signatures is still needed.
