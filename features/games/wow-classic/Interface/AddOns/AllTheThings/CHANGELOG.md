# AllTheThings

## [5.4.16](https://github.com/ATTWoWAddon/AllTheThings/tree/5.4.16) (2026-11-21)
[Full Changelog](https://github.com/ATTWoWAddon/AllTheThings/compare/5.4.15...5.4.16) [Previous Releases](https://github.com/ATTWoWAddon/AllTheThings/releases)

- [DB] Mark Betrayed (3504) removed in Forever.  
    * Belgrom Rockmaul no longer offers Betrayed (3504) in Forever, and  
      Ag'tor Bloodfist's Betrayed (3505) can be taken without it: mark  
      3504 REMOVED\_1\_60\_1 and drop 3505's sourceQuest.  
    * Rebuilt the Forever DB.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Restore confirmed Forever dungeon loot.  
    * Blackrock Depths: restore 17 drops that were commented out until  
      confirmed and that Wowhead Forever now shows (Gerstahn, Roccor,  
      Gorosh, Fineous, Stilgiss, Verek, Secret Safe, Hurley, Phalanx,  
      Panzor, Emperor); drop the stray Wristguards of Renown on Phalanx.  
    * Add Backroom Bulwark (Phalanx) and Savage Gladiator Shoulders  
      (Grizzle), new in Forever.  
    * Restore Ace of Elementals (Hydrospawn, Lord Incendius) and Ace of  
      Warlords (King Gordok).  
    * Remove these items from the Missing DB.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Fix Forever's Eastern Plaguelands markers.  
    * Forever's Eastern Plaguelands map uses the Wrath art, but the  
      estimated exploration markers came from the Classic hit rects, so  
      they sat about 5 right and 6.5 down. Add Wrath's harvested points  
      for the 22 areas to ExplorationAreaPositionDB.  
    * Regenerate ExplorationPositions (build 1.60.1.71037) and rebuild  
      the Forever DB.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Fix Swamp of Sorrows quest data.  
    * Neeka Bloodscar (1418): Helgrum the Swift's coord was on the  
      Dustwallow Marsh map; now Swamp of Sorrows (Forever, SoD, Standard).  
    * Fel'zerul: coords were Brohann Caskbelly's Stormwind spot; now  
      47.9, 55.0 on Pool of Tears, The Atal'ai Exile and The Temple of  
      Atal'Hakkar (Forever, SoD, Standard).  
    * Lost in Transit: Courier's Shipment comes from the Mangled Corpse.  
    * Blood of My Blood (93429): available to both factions, Karana's  
      coord corrected.  
    * My Little Friends (93176): the Entomology Starter Kit's Bug  
      Catching Net and Field Guide are provided quest items.  
    * Rebuilt the compiled DBs (also covers the dungeon drops commit).  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Add new Forever dungeon drops.  
    * Maraudon: Putridus Wall (275864) from Lord Vyletongue.  
    * Gloves plans and patterns (251403-251407, 252867-252871,  
      252918-252921, 254096-254106): world drops with a shared  
      HANDS\_RECIPE\_BOSSES list (34 bosses in Uldaman, Zul'Farrak, Sunken  
      Temple, BRD and Maraudon); drop the lone copy on Atal'alarion.  
    * Stratholme: new drops for Fras Siabi, Malor the Zealous, Crimson  
      Hammersmith and Black Guard Swordsmith.  
    * Scholomance: new drops for Marduk Blackpool and Vectus.  
    * Dire Maul: Ring of Demonic Potency (Alzzin), Demon Howl Wristguards  
      and Libram of Binding (Immol'thar), and Pusillin's Demondash  
      Spaulders and Obsidian Bauble (unused until Forever).  
    * Mage scrolls 281015-281018 added to world drops.  
    * Remove the newly sourced items from the Missing DB.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Align the stat scroll comments.  
    * Pad the comments of Scroll of Intellect (955) and Scroll of  
      Strength (954) in Forever and SoD World Drops to match the others.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Limit the Northshire vendors to Alliance.  
    * Dermot Johns (190), Godric Rothgar (1213) and Janos Hammerknuckle  
      (78) are Stormwind vendors: add races = ALLIANCE\_ONLY (Forever, SoD,  
      Standard) so they stop showing for Horde.  
    * Rebuilt the compiled DBs.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Add Burning Gem to its quest objective.  
    * The Burning of Spirits (1435): Burning Gem (6436) is now a provider  
      of the Infused Burning Gem objective instead of a cost (Forever, SoD,  
      Standard), so the gem's tooltip shows its quest.  
    * Rebuilt the compiled DBs.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Add the stat scrolls to world drops.  
    - Scroll of Agility, Intellect, Protection, Spirit, Stamina and  
      Strength (I-IV) drop from creatures everywhere in Classic (Wowhead  
      Forever/Classic/TBC/Wrath), but were only listed as Comprehension  
      rewards or Inscription crafts: add them to a Consumables section of  
      World Drops in Forever, SoD and Standard. Standard's are  
      REMOVED\_4\_0\_3 (Cataclysm left a handful of droppers, retail none).  
    - Rebuilt every DB.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Add Flask of Oil to SoD and Standard world drops.  
    - Flask of Oil (814) had no source: SoD lists the Classic droppers  
      (plus SoD's Venture Co. Light Shredder); Standard keeps the droppers  
      shared by every version ungated and splits the rest by era (Classic  
      Venture Co. and XT robots before 4.0.3, the Cataclysm-era shredders,  
      Optimo and Proto-Striders after), per Wowhead Classic and retail.  
    - Rebuilt the Classic, SoD and retail DBs.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Add Flask of Oil to Forever's world drops.  
    - Flask of Oil (814) had no source: list it with the creatures Wowhead  
      Forever shows dropping it (Westfall harvest golems, Wetlands oozes,  
      Barrens and Stonetalon Venture Co., Deadmines goblins, the new  
      Excavation Site oozes and others) and their zones.  
    - Rebuilt the Forever DB.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Add the Cooked Crab Claw recipe drop in Westfall.  
    - Recipe: Cooked Crab Claw (2698) drops from creatures all over  
      Westfall in every version (Wowhead Forever, Classic and retail; a  
      Murloc Hunter drop in Forever): add it to Westfall's zone drops in  
      Forever and SoD, and ungate Standard's entry, which was Cata+ only.  
    - Rebuilt every DB.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Add Saltwater Murloc Eye droppers in Riverglades.  
    - A Taste of the Sea (95121): Saltwater Murloc Eye (268344) also drops  
      from the Murloc Hunter, Raider, Tidebringer and Tideskimmer, per  
      Wowhead Forever.  
    - Rebuilt the Forever DB.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Add Kzan Thornslash to the Valley of Trials.  
    - Kzan Thornslash (3159), the Valley of Trials weaponsmith, was  
      missing from every DB: add him to Durotar's vendors in Forever, SoD  
      and Standard (on the Valley of Trials map after Cataclysm), linking  
      the eight weapons Wowhead lists for him.  
    - Rebuilt every DB.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
    Co-authored-by: milotic <al0305@hotmail.com>  
- [DB] Move Terror of the Desert Skies to the Badlands.  
    - Terror of the Desert Skies (Hemet Nesingwary) (78830) moves from  
      the Stranglethorn Vale file to the Badlands next to its Primitive  
      Drawing version, since the hunt for Gharrik happens there; Hemet's  
      coord stays in Stranglethorn.  
    - It follows the Primitive Drawing version (78823).  
    - Rebuilt the Forever DB.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Open Terror of the Desert Skies to all classes.  
    - Terror of the Desert Skies (78830) from Hemet Nesingwary has no  
      class restriction in Forever (Wowhead Forever, and a Paladin  
      contributor report saw it offered); SoD's version is Hunter-only.  
    - Rebuilt the Forever DB.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Give Forever's new factions icons.  
    - Powderfuse (2827): coin, like the other goblin factions.  
    - Barkskin Burrow (2747): Barkskin's stoneclaw icon; Guardians of  
      Hyjal (2765) and Earthen Ring (2787): their tabards; Kirin Tor  
      (2740): the Kirin Tor reputation icon; Nightclaw Druids (2758):  
      cat form; Thorium Brotherhood (59): a thorium bar.  
    - Darkspear Raiders (2798) / Theramore Expeditionary Force (2799):  
      the Horde and Alliance PvP banners.  
    - Rebuilt the Forever DB.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Move the Uldaman quests into Uldaman (SoD, Std).  
    - Power Stones (2418), Uldaman Reagent Run [A] (17) / [H] (2202),  
      Reclaimed Treasures [A] (1360) / [H] (2342) and Solution to Doom  
      (709) move from the Badlands and Loch Modan files into Uldaman's  
      quests in SoD and Standard; the same-named pairs get [A]/[H] tags.  
    - Rebuilt the Classic Era, SoD, TBC, Wrath, Cata, Mists and retail  
      DBs.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Move more Uldaman quests into Uldaman (Forever).  
    - Reclaimed Treasures [A] (1360) / [H] (2342) and Solution to Doom  
      (709) move from the Badlands file into Uldaman's quests; the  
      same-named Reclaimed Treasures get [A]/[H] tags.  
    - Rebuilt the Forever DB (also drops the Unclaimed Baggage objects).  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Move the Uldaman quests into Uldaman in Forever.  
    - Power Stones (2418) and Uldaman Reagent Run [A] (17) / [H] (2202)  
      move from the Badlands and Loch Modan files into Uldaman's quests;  
      the same-named Reagent Runs and their follow-up references get  
      [A]/[H] tags.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Drop Unclaimed Baggage from Forever's Badlands.  
    - Unclaimed Baggage (9439) from Advisor Sarophas (17097) is a TBC  
      quest (Standard: ADDED\_2\_0\_1; no Wowhead Classic or Forever page),  
      and the Forever client has no name for it.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Fix the Mirage Mirror quest in the Badlands.  
    - Mirage Mirror (97821) is open to both factions and starts from the  
      Mirage Mirror (278744) dropped by the Malevolent Mirage (269756),  
      turned in to Dorgaron (Alliance) or Mus'hale (Horde); it rewards  
      the other Mirage Mirror (277844), which was wrongly its objective.  
    - List the starting item under Badlands zone drops with the  
      Malevolent Mirage's 23 spawn points from Wowhead Forever.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Rebuilt DBs to include updated localizations for the new Buy All button.  
- [Auctions] Add Buy All to the Appearances list.  
    - A Buy All row at the top of Appearances walks through each  
      uncollected, collectible appearance within the Maximum Price, finds  
      its cheapest buyout (checking every random-suffix variant) and  
      offers it in a confirmation popup showing the item and price  
      (Buyout / Skip / Stop); Escape skips the item. Bid-only auctions,  
      your own auctions and unaffordable ones are skipped, and closing  
      the Auction House stops the run.  
    - Bought rows get the saved check mark and are skipped on later runs.  
    - Works with both Auction House UIs: the Classic browse frame (name  
      search over every result page) and the modern C\_AuctionHouse one  
      that Forever uses (browse for the item keys, then an item search  
      sorted by price).  
    - Auction prices use the bid only when an auction has no buyout  
      (bid-only auctions used to show a price of 0), and the Classic scan  
      now keeps the cheapest auction of each item.  
    - Options that group several item types (Appearances) no longer lose  
      the earlier types' results when the list is rebuilt.  
    - New localization strings for the row, popup and chat messages.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Add a Robes set to Standard's Common Vendor Items.  
    - The seven robes (Plain Robe through Silver Dress Robes) form a new  
      Common Vendor Items set under Cloth; the seven robe vendors in the  
      capitals link it with sym instead of listing the robes.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Add a Robes set to SoD's Common Vendor Items.  
    - The seven robes (Plain Robe through Silver Dress Robes) form a new  
      Common Vendor Items set under Cloth; the seven robe vendors in the  
      capitals link it with sym instead of listing the robes.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Add a Robes set to Forever's Common Vendor Items.  
    - The seven robes (Plain Robe through Silver Dress Robes) form a new  
      Common Vendor Items set under Cloth.  
    - Theresa Moulaine and Wynne Larson (Stormwind), Maeva Snowbraid  
      (Ironforge), Anadyia (Darnassus), Lucille Castleton (Undercity),  
      Tagain (Thunder Bluff) and Tor'phan (Orgrimmar) link it with sym  
      instead of listing the robes.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Merge duplicate vendor sym fields in Forever.  
    - Four Forever vendors set `sym` twice, so the second table replaced  
      the first and dropped part of their stock: Lauren Newcomb (Woven,  
      Battered/Tanned Leather, Heavy Weave, shirts), an Undercity leather  
      vendor (Rough Leather), an Undercity shield vendor (its shields) and  
      a Thunder Bluff cloth vendor (all but Knitted).  
    - Each now has a single sym with every selector and item.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Add Blackmaw Hold's boss loot in Forever.  
    - Each of the seven Blackmaw Hold bosses (Withermaw, Impaan the  
      Imprisoner, Elder Shaman Bloodmane, Bonesnout the Unbroken, Varrox  
      Bleakhoof, Blackmaw Behemoth, Unbound Spirit) gets its three blue  
      drops (280056-280076) from Wowhead Forever.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Move Chemist Cuely's coord in Undercity.  
    - Seeping Corruption (3568) and its follow-ups: Chemist Cuely (8390)  
      stands around 48.8, 71.7 (contributor report, matches Wowhead  
      Forever and Classic), not 47.6, 73.0; Forever, SoD and Standard.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [Forever] Bump wago files to 1.60.1.71037  
- [DB] Fix the Supplies and Studies stone coords.  
    - Supplies and Studies (97663): the small Etched Stone (668003) has a  
      single spawn and the large one (668004) four, per Wowhead Forever;  
      drop the stray spots and add the missing 28.4, 61.4.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Drop Gyro... What? as a Forever 716 prerequisite.  
    - Stone Is Better than Cloth (716) only needs Study of the Elements:  
      Rock (3/3) (712); a contributor report saw it offered with Gyro...  
      What? (714) incomplete, matching SoD and Standard.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Add the mage Comprehension scrolls to Forever.  
    - New Comprehension section (expansion features/comprehension.lua):  
      the three Decipher Scroll tiers that turn a Comprehension Charm and  
      scroll words into mage scrolls, ported from SoD without its rune  
      Spell Notes and SoD phase gating.  
    - Sources Scroll of the Blade (217496) and the Narpas Sword (217497)  
      it makes from a Hypnotic Blade, as reported in #forever-reports.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Use Forever's T0.5 quests for H Paladin, A Shaman.  
    - Replace the TBC quests 10492-10499 with Forever's own versions:  
      Horde Paladin 97411-97414 (Mokvar) and Alliance Shaman 97447-97450  
      (Deliana), each offering the spec set choices from Wowhead Forever.  
    - Move 97411/97412 and 97447/97448 out of Orgrimmar and Ironforge into  
      the Tier 0.5 file; add Anthion's Parting Words (97413, 97449) and  
      Saving the Best for Last (97414, 97450).  
    - Split the classic Paladin [A] and Shaman [H] quests into their own  
      faction-only entries.  
    - Point the shared chain's sourceQuests and the Lord Valthalak Laid to  
      Rest achievement at the new IDs.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Add The Burning Beast chain to Forever.  
    - The Burning Beast (81900): started from the Weathered Etching  
      (441061) in Searing Gorge, open to every class in Forever; turned  
      in to Bloodmage Lynnore in the Blasted Lands.  
    - Chains That Bind (81917) and Brought to Heel (81919) follow from  
      Lynnore with Wowhead Forever's class lists; the SoD rune reward is  
      left out.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Add Buzzard Wing's missing droppers in Forever.  
    - Buzzard Wing (3404): list all 23 carrion birds Wowhead Forever  
      shows dropping it (buzzards, vultures, Dread Flyers, Rocs and the  
      rares) with maps for their 12 zones besides Tanaris, and drop the  
      description that only pointed at the Tanaris Rocs.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Fill Forever giver and customer TODOs from Wowhead.  
    - 25 Craftsman's Writs get their customer (cr) and coord.  
    - Quest givers and coords for An Epic Ride (Dwarf/Undead), Swift as  
      the Wind (Dwarf/Human/Troll/Tauren), An Earnest Proposition [A],  
      To Serve Kum'isha, Acts of Mercy, Manna-Enriched Horse Feed,  
      Scalebeard, and the Mount Hyjal quests Back to the Grind, Deeproar  
      Down, Mystic Mix, Shatter the Stonewatchers, Threading a Solution,  
      Water of Hyjal and Wood Remains.  
    - Nathanos Blightcaller's coord follows Wowhead Forever (22.2, 63.4).  
    - Titles added to the new giver/customer comments.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- Aqir Invasions: Move from 'Expansion Features' to 'Events'  
- [DB] Link the gunsmiths' guns in Standard.  
    - Blizrik Buckshot (8131), Cawind Trueaim (9548) and Wixxrak (11184)  
      link the guns (and Cawind's bows, Wixxrak's melee weapons) they sell  
      with sym; Wowhead Classic, Cata and retail list the same stock.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Link the gunsmiths' guns in SoD.  
    - Blizrik Buckshot (8131), Cawind Trueaim (9548) and Wixxrak (11184)  
      link the guns (and Cawind's bows, Wixxrak's melee weapons) they sell  
      with sym, as on Wowhead Classic.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Link the gunsmiths' guns in Forever.  
    - BKP 42 "Ultra" (3025) joins the Common Vendor Items guns.  
    - Blizrik Buckshot (8131, Gadgetzan) and Fizzix Boomshot (260566,  
      Riverglades) link BKP 2700 "Enforcer", BKP 42 "Ultra" and Large  
      Bore Blunderbuss with sym.  
    - Cawind Trueaim (9548, Feralas) links his guns, bows and quivers;  
      Wixxrak (11184, Winterspring) adds BKP 42 "Ultra".  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- Quests: Move 'The Promise of Tomorrow' storyline to the main Quel'Thalas header  
    - Aqir Invasions are a limited-time event that will end with the release of Patch 12.1.7  
- [DB] Add givers to the Sign Me Up! follow-ups.  
    - Karolek (95820): starts from Jornah (256388) in the Barrens per  
      Wowhead; Horde-only, leads to Orgrimmar.  
    - Rotgath Stonebeard (95817): starts from Elaine Compton (256391),  
      where Sign Me Up! [A] ends (Wowhead has no starter yet, mirrors the  
      Horde chain); Alliance-only, leads to Ironforge. Wowhead lists the  
      quest, so it no longer needs CREATED\_1\_60\_1.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Move the Sign Me Up! chain into Trade Logistics.  
    - Sign Me Up! [A] (95816) and [H] (95819) and their follow-ups  
      Rotgath Stonebeard (95817) and Karolek (95820) now sit under the  
      Trade Logistics QUESTS header next to the Supply Officers that sell  
      the Advertising License Applications, instead of in Redridge, the  
      Barrens, Ironforge and Orgrimmar.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Split the Sign Me Up! quests by faction.  
    - Sign Me Up! [A] (95816): Alliance-only, turned in to Elaine Compton  
      (256391) in Redridge; its Advertising License Application (270888)  
      is sold by Tamelyn Aldridge.  
    - Sign Me Up! [H] (95819): Horde-only, turned in to Jornah (256388)  
      in the Barrens; its application (270887) is sold by Gishah.  
    - Tag both and their follow-up references with [A]/[H].  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Open the Captured Servant of Azora to Horde.  
    - Captured Servant of Azora (3096) in Redridge Mountains is friendly  
      to both factions, so drop her ALLIANCE\_ONLY restriction in Forever,  
      SoD and Standard.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Make the Valor weapon quests Alliance-only.  
    - Grant's Shield (79362), Ira's Dagger (96137), Merrick's Bow (96138)  
      and Silvia's Sword (79363) are item-started Alliance quests turned  
      in to Sirra Von'Indi. Replace their aqd/hqd blocks with Sirra and  
      her coord, dropping the Horde copy from Bath'rah the Windwatcher  
      that SoD's old quests 79362/79363 left behind.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Rebuilt all DBs to strip out common vendor items from zone files, useless descriptions, and the new localization string for quests that are only offered while another quest is active.  
- [DB] Add the Pain Suppression rune puzzle to SoD.  
    - Apocryphal Epiphany (213143, Engrave Boots - Pain Suppression):  
      looted from the Remnant (424373) in the Scarlet Monastery Library  
      once the four Echoes are used at their statues.  
    - Graves and their Echoes: 424266 Graveyard Echo (SM Graveyard),  
      424267 Arathi Echo (Arathi Highlands), 424264 Theramore Echo  
      (Dustwallow Marsh), 424265 Swamp Echo (Swamp of Sorrows).  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Add the Scarlet Banner puzzle to Forever.  
    - Scarlet Banner (278030): looted from the Scarlet Banner object  
      (424373) in the Scarlet Monastery Library once the four Echoes are  
      used at their statues.  
    - Graves and their Echoes: 424266 Graveyard Echo (SM Graveyard),  
      424267 Arathi Echo (Arathi Highlands), 424264 Theramore Echo  
      (Dustwallow Marsh), 424265 Swamp Echo (Swamp of Sorrows).  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [Locale] Add zhCN labels and object names (#2786).  
    - Translate the Wrath Remix and Quest Mobs headers.  
    - Match the Simplify Zone Drops checkbox and tooltip to the existing header.  
    - Translate the Forever Craftsman's Writs header and its delivery instructions.  
    - Use the localized names for all three sealed writ tiers.  
    - Localize Scrolls objects 409496, 409711, 409717, 409731, 423897, and 423899.  
    Assisted-by: deepseek-v4.1-flash.  
- [DB] Link Standard's consumable quest rewards with sym.  
    - 75 quests: consumable rewards that have a source elsewhere  
      (crafted items, common vendor items, vendors, drops) now use sym  
      instead of a second i() entry.  
    - Skipped quests whose rewards sit inside preprocessor blocks, and  
      consumables only rewarded by quests (incl. Keg of Thunderbrew 1262,  
      which has no other source in the Classic flavours).  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Link SoD's consumable quest rewards with sym.  
    - 41 quests: consumable rewards that have a source elsewhere  
      (crafted items, common vendor items, vendors, drops) now use sym  
      instead of a second i() entry.  
    - Consumables only rewarded by quests are unchanged.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Link Forever's consumable quest rewards with sym.  
    - 75 quests: consumable rewards (potions, elixirs, food, drinks,  
      armor kits, bombs) that have a source elsewhere (crafted items,  
      common vendor items, vendors, drops) now use sym instead of a  
      second i() entry, so their tooltips only show the real source.  
    - Consumables only rewarded by quests are unchanged.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Drop the Southsea Lamp source description.  
    - Southsea Lamp (9359): remove the description that restates its  
      sources (Pirate's Footlocker, Captain's Chest, Cuergo's Hidden  
      Treasure) in Forever, SoD and Standard. ATT already lists each one.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Add the Egg-O-Matic coord to its quest.  
    - The Super Egg-O-Matic (2741): coord for its starter object, the  
      Egg-O-Matic (142071), in Forever, SoD and Standard.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [Quests] Notice quests offered during another quest.  
    - New quest field offeredDuring = <questID> (passed through by the  
      Parser and cached) for quests that are only offered while another  
      quest is in progress.  
    - Accepting that quest no longer warns that it "will prevent  
      collection" of the offered quest; it prints a notice with the  
      report sound instead (QUEST\_OFFERED\_DURING\_FORMAT), while the  
      offered quest is still available to the character. Its  
      lockCriteria still marks it as missed once the quest is completed.  
    - Oasis 97540 (Forever, Tanaris) is offered during Tooga's Quest 1560.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Add Brivelthwerp, the Thousand Needles ice cream vendor.  
    - Forever, SoD and Standard: Brivelthwerp 6496 <Ice Cream Vendor> at  
      the Mirage Raceway sells Tigule's Strawberry Ice Cream 7228, which  
      had no source yet (in-game 77.4, 76.9 for Forever; Wowhead 77.4,  
      77.0). Standard gates him like the other pre-Cataclysm Thousand  
      Needles vendors (REMOVED\_4\_0\_3).  
    - The Children's Week TODOs now only list the Sweet Treats and  
      Hallow's End Treats vendors that also sell it.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Add the Outland heavy armor vendor set.  
    - Common Vendor Items: Heavy Draenic Breastplate, Mag'hari Chain Vest,  
      Heavy Draenic Bracers, Worn Mag'hari Gauntlets, Aldor Heavy Belt and  
      Layered Bone Shield become a symselector set (ADDED\_2\_0\_1).  
    - Maktu, Bartleby Armorfist and Alexis Walker select it instead of  
      listing the pieces; Loolruna (also Accurate Slugs, Jagged Arrow) and  
      Mari Stonehand gain it, per Wowhead.  
    - Add Osrok the Immovable 19011 (Horde) and Sparik 19012 (Alliance)  
      <Armorsmith & Blacksmithing Supplies> in Nagrand, with the set and  
      their blacksmithing supplies, and Alorra 19517 <Armorer> in  
      Shadowmoon Valley.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Add Everlook's armor vendors in SoD and Standard.  
    - Blixxrak 11183 <Light Armor Merchant> selects the Embroidered and  
      Reinforced Leather sets; Nixxrak 11182 <Heavy Armor Merchant>  
      (Horde) selects Brigandine and Platemail plus Crested Heater Shield  
      and Ornate Buckler, matching Wowhead's sell lists and Forever.  
    - Standard: Nixxrak moves to 60.2, 50.2 after Cataclysm; Blixxrak's  
      post-Cataclysm coord is a TODO (none on Wowhead).  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- Talebound: Fix a few copy/paste mistakes  
    - Ref: fca5cb0a12ff0b97d2bf84a540acdd30174c28aa  
- [DB] Expand Standard's Common Vendor Items and links.  
    - Common Vendor Items: add Grunts Chain and Grunts Plate  
      (ADDED\_4\_0\_1), the six joke rings (Finger), the vendor drinks and  
      seven food sets with symselectors.  
    - Naros, Tumi, Fela and Jodan select the Grunts sets; both Qixdi  
      entries select the rings; the barmaids, Sarah Brady and the food  
      vendors select their drinks and sets. #if-gated and ADDED\_10\_0\_5  
      vendor lists stay as they are.  
    - Parts of the Swarm 1148 starts from qs = 5877; Cracked Silithid  
      Carapace is a Thousand Needles zone drop (REMOVED\_4\_0\_3).  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [SoD] Expand Common Vendor Items and vendor links.  
    - Common Vendor Items: add the vendor drinks and seven food sets  
      (Bread, Cheese, Drink, Fish, Fruit, Meat, Mushroom) with  
      symselectors.  
    - The barmaids select their drinks by itemID and the food vendors  
      select their set; Qixdi's rings lose the self-provider.  
    - Parts of the Swarm 1148 starts from qs = 5877; Cracked Silithid  
      Carapace is a Thousand Needles zone drop with the Silithid crs.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [Forever] Expand Common Vendor Items and vendor links.  
    - Common Vendor Items: add the six joke rings (Finger), the vendor  
      drinks, and seven food sets (Bread, Cheese, Drink, Fish, Fruit,  
      Meat, Mushroom) with symselectors.  
    - Link 86 vendors to what they sell per Wowhead Forever: whole food  
      and drink sets where they sell every tier, the rest by itemID; the  
      barmaids, Kaja and Mangorn drop their explicit copies.  
    - Add the Alterac jewelry vendors Debbi Moore 251999, Harold Winston  
      251975 and Tiffany Cartier 251976 (coords TODO for the last two).  
    - Parts of the Swarm 1148 starts from qs = 5877; Cracked Silithid  
      Carapace is a Thousand Needles zone drop with the Silithid crs.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- Talebound: Update cost of stuff in the store  
- PTR: Parse  
- [DB] Add Common Vendor Items and armor sets to Standard.  
    - New 02 - Outdoor Zones/0.3 - Common Vendor Items.lua in the Forever  
      and SoD style, sorted by filter: 74 items from the 18  
      n(COMMON\_VENDOR\_ITEMS) groups in the Classic, Wrath, Cataclysm and  
      Legion crafted items. Items added after Classic carry an ADDED\_*  
      timeline instead of #if blocks or applyclassicphase; only the  
      fishing poles' collectible flag stays behind #if AFTER 10.0.0.  
    - Drop the vendor coords/providers and the barmaid drink note; dyes  
      and threads shared by Leatherworking and Tailoring are listed once.  
    - Add the 28 vendor armor sets (Embroidered ... Platemail) under Cloth,  
      Leather, Mail and Plate with Forever's symselector values, and link  
      them from 64 armor vendors in 17 zone files instead of listing the  
      pieces. Every set item already had an ungated source, and each  
      vendor still lists the same items once the sets expand.  
    - Aldric Moore and Allison Potts (Stormwind, ADDED\_10\_0\_5 sharedData)  
      keep their item lists.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Add Synge to the Thousand Needles vendors.  
    - Synge 3053 <Gun Merchant> at the Mirage Raceway (80.4, 76.8) links  
      the BKP 2700 "Enforcer" and Large Bore Blunderbuss in SoD and  
      Standard.  
    - Standard: REMOVED\_4\_0\_3 with the sym in #if BEFORE 4.0.3, like the  
      other pre-Cata Thousand Needles vendors; the Cataclysm Synge is a  
      separate NPC (40888) who only gives quests.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [Forever] Add Synge to the Thousand Needles vendors.  
    - Synge 3053 <Gun Merchant> at the Mirage Raceway (80.4, 76.9) links  
      the BKP 2700 "Enforcer" and Large Bore Blunderbuss from Common Vendor  
      Items.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [Forever] Fix Kravel Koalbeard's coordinates.  
    - Kravel Koalbeard 4452 (Thousand Needles) stands at 77.8, 77.2: update  
      the coord on his 9 quests, including Rocket Car Parts 1110,  
      Wharfmaster Dizzywig 1111 and Hemet Nesingwary 5762.  
    - Drop the duplicate qg line on Delivery to the Gnomes 1114.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [SoD] Link vendor armor sets with SymSelector.  
    - Add the 28 vendor armor sets (Embroidered ... Platemail) to Common  
      Vendor Items under Cloth, Leather, Mail and Plate, with the same  
      contents and symselector values as Forever's.  
    - 47 armor vendors in the capitals, Elwynn, Loch Modan, Duskwood,  
      Redridge, Wetlands and Stranglethorn now select those sets instead  
      of listing the pieces; anything else they sell stays in groups or  
      their itemID list.  
    - Mirelle Tremayne keeps her partial Scalemail (no vest) as items.  
    - Each vendor still lists the same items once the sets expand.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [SoD] Add a Common Vendor Items section.  
    - New zones/common vendor items.lua in the same style as Forever's,  
      sorted by filter:  
      - Consumables: barmaid drinks, Ice Cold Milk, Refreshing Spring  
        Water, fishing lures and attractor.  
      - Profession Equipment: Blacksmith Hammer, Skinning Knife (both  
        collectible = false), Fishing Pole, Strong Fishing Pole.  
      - Reagents: vials, flux, coal, dyes, threads, salt, spices, rods,  
        wood, stocks, Bleach, Lesser Magic Essence, Strange Dust.  
    - Remove the 9 n(COMMON\_VENDOR\_ITEMS) groups from crafted items, with  
      their disabled vendor coords/providers and the barmaid provider.  
    - Dyes and threads shared by Leatherworking and Tailoring are listed  
      once.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [Forever] Flatten the Common Vendor Items consumables.  
    - Drop the Elly Langston / Barkeep Morag providers from the barmaid  
      drinks and list all 10 consumables as plain entries sorted by name.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [Forever] List vendor profession tools as equipment.  
    - Move Blacksmith Hammer 5956, Mining Pick 2901 and Skinning Knife 7005  
      from Weapons > Misc into Profession Equipment in Common Vendor Items,  
      and drop the now-empty Misc filter.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Drop the Skyguard rep farming group tip.  
    - Remove "Protip: Join a rep farming group." from the Sha'tari Skyguard  
      reputation tooltip; the Arakkoa, boss and Shadow Dust steps stay.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [Forever] Move crafted vendor items to Common Vendor Items.  
    - Move the 12 n(COMMON\_VENDOR\_ITEMS) groups from the Crafted Items  
      professions into zones/common vendor items.lua, sorted by filter:  
      - Bags: Apprentice's Herb Pouch, Mining Pack, Skinning Satchel.  
      - Consumables: barmaid drinks (keeping their providers), Ice Cold  
        Milk, Refreshing Spring Water, fishing lures and attractor.  
      - Profession Equipment: Fishing Pole, Strong Fishing Pole.  
      - Reagents: vials, flux, coal, dyes, threads, salt, spices, rods,  
        wood, stocks, Bleach, Simple Flour, Thick Logs, Chef's Knife.  
      - Weapons > Misc: Blacksmith Hammer, Skinning Knife.  
    - Dyes and threads shared by Leatherworking and Tailoring are listed  
      once; Forever-new vendor items keep ADDED\_1\_60\_1.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Drop the template pet tamer descriptions.  
    - Remove the "X's pets are level N of the following consecutive pet  
      classes" lineups (and the "Horde/Alliance only" line) from 36 pet  
      tamers in Kalimdor, Eastern Kingdoms, Outland, Northrend and the  
      Darkmoon Faire; races and petBattleLvl already carry that data.  
    - Grazzle the Great keeps only the note that Alliance players can  
      battle him once during 'Battle Pet Tamers: Kalimdor'.  
    - Environeer Bert keeps his scaling strategy.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Drop generic supplier and dungeon drop notes.  
    - Remove "Can be bought from X Suppliers, as well as some Trade vendors  
      around the world." from the Standard, SoD and shared profession  
      reagents (vials, threads, rods, salt, supplier headers), including  
      the commented-out copies.  
    - Forever: drop the MINING\_PICK\_DESCRIPTION string; Mining Pick 2901  
      is a plain entry again.  
    - Treshala's Pendant 5825 (Mortality Wanes, RFK) loses "Drops from any  
      creature in the Dungeon." and is listed in the RFK Zone Drops in  
      Standard (REMOVED\_4\_0\_3), SoD and Forever.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Clean up rare and catalyst descriptions.  
    - Move the Classic dungeon rares into n(RARES) headers in Standard,  
      SoD and Forever (Panzor, the LBRS Spirestones, Bannok Grimaxe,  
      Crystal Fang, Ghok Bashguud, Jed Runewatcher, Tsu'zee, Dark Iron  
      Ambassador, Meshlok, Earthcaller Halmgar, Blind Hunter, Deathsworn  
      Captain, Skul, Stonespine, Deviate Faerie Dragon, Sandarr  
      Dunereaver, Zerillis, Dustwraith, Doctor Theolen Krastinov).  
    - Miner Johnson joins the existing Deadmines RARES header.  
    - Drop "This is a Rare Creature and, as such, is not always present."  
      and the "/tar at the entrance" hint; other hints stay.  
    - Rares left with only groups list their drops directly.  
    - Kraulshaper Tukaar (always present since 10.1.7) stays in place and  
      only loses the generic fallback text.  
    - Remove the empty descriptions on the Revival Catalyst Console and  
      Primal Storms difficulty headers.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [SoD] Confirm the Treant's Bane and crossbow drops.  
    - Treant's Bane 228486 (Gordok Tribute) now has ADDED\_1\_15\_3, and the  
      old 18538 gets REMOVED\_1\_15\_3 (Wowhead Classic: 1/62 in SoD).  
    - Polished Ironwood Crossbow 234159 moves in with Emeriss's confirmed  
      drops (Wowhead Classic: 32/245 in SoD).  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Drop the "ping Crieve" notes in Forever and SoD.  
    - Forever: Boots of the Fiery Sands 21482 (AQ20).  
    - SoD copies: Boots of the Fiery Sands 21482, Chillpike 13148,  
      Detention Strap 13950.  
    - SoD versions with no recorded drops: Polished Ironwood Crossbow  
      234159, Lord Valthalak's Staff of Command 228682, Treant's Bane  
      228486, Coldstone Slippers 228703, Tattered Leather Hood 228704,  
      Malicious Axe 228030, Ebon Hilt of Marduk 227993, Boots of the  
      Shrieker 228043 (commented out).  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Drop the "ping Crieve" item descriptions.  
    - Remove the player-facing notes asking to contact Crieve if a removed  
      item drops: Boots of the Fiery Sands 21482 (AQ20), Incendic Bracers  
      11768 and Rockfist 11743 (BRD), Voone's Twitchbow 13175, Chillpike  
      13148 and Bonespike Shoulder 12588 (BRS), Darkshade Gloves 14543 and  
      Detention Strap 13950 (Scholomance), and Tolakesh, Horn of the Black  
      Ox 100966 (Siege of Niuzao Temple).  
    - The items keep their isBounty flags and timelines.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Use learnedAt for Dragonflight weekly quests.  
    - Dragon Isles profession weekly quests (Alchemy, Blacksmithing,  
      Enchanting, Engineering, Inscription, Jewelcrafting,  
      Leatherworking, Tailoring) said "Requires 25/45 Skill." in a  
      description.  
    - Replace the 70 descriptions with learnedAt = 25 / 45, so the skill  
      level shows on the profession's Requires tooltip line.  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Drop generic gathering and vendor descriptions.  
    * Same cleanup as Forever for the Classic crafted items in Standard  
      and Season of Discovery: 105 fishing, herb terrain and "Can be  
      bought from ... vendors around the world" descriptions  
    * Kept the Raw Nightfin Snapper and Raw Sunscale Salmon fishing hours  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [Forever] Drop generic gathering and vendor descriptions.  
    * 59 crafted item descriptions that gave no specific information:  
      fish and fishing pools ("Can be caught on the seaside"), herb node  
      terrain ("Usually found near trees") and "Can be bought from ...  
      vendors around the world"  
    * Kept the Raw Nightfin Snapper and Raw Sunscale Salmon fishing hours  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [Forever] Drop the Steam Tonk Controller note.  
    * Steam Tonk Controller (22728) no longer asks players to report it;  
      it's in the game (Darkmoon Faire vendor, per Crieve)  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Drop the joke herb and scroll descriptions.  
    * Blindweed and Liferoot no longer have their snarky herb hints  
      (Forever, Standard, Season of Discovery)  
    * The 8 Mage Scroll items (211780-211787, 211853-211855) lose their  
      quote descriptions; the Forever copies collapse to plain i()  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [DB] Drop descriptions that restate item data.  
    * Same cleanup as the Forever DB for the Classic world drops and  
      crafted items in Standard and Season of Discovery: creature  
      reagents, cloth, skinning scales/hides whose description only  
      repeated their crs/coords/maps  
    * Version-gated blocks are removed only when they held nothing but  
      such descriptions; ones that mix in data or extra notes stay  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
- [Forever] Drop descriptions that restate item data.  
    * 65 crafted item and world drop descriptions only repeated what the  
      item's crs/coords/maps already show (creature reagents, cloth,  
      skinning scales and hides, "drops from X in the given zones")  
    * Kept the ones with extra hints (Buzzard Wing and Giant Egg rocs,  
      Spider's Silk abundance) and all other descriptions  
    Assisted-by: claude-opus-5-5.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
