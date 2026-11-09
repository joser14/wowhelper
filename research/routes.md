# LevelGuide data review: Routes.lua, QuestIDs.lua, Prereqs.lua

Scope: the three data files, read against how `LevelGuide.lua` consumes them (title + `part` matching, `TurnedIn()` counting `IsQuestFlaggedCompleted` over `QuestIDs.ids[title]` in list order, `LogByTitle()` setting `entry.part` = position of the held quest ID in that list, `PrereqsMet()` marking a pick-up *done* (hidden) while its prerequisites are unmet, `RouteStepActionable()` showing a pick-up only when `TurnedIn == part - 1`, `OUTLEVELED = 4`, `FindRoute()` taking the first chain route with `level >= min - 2`).

Method: a Lua-literal parser + checker in Node (`parse.js`, `check.js`, raw output in `check.txt`, all next to this file) for the structural and cross-file checks; web text for content (foreverchanges.pro zone lists, wow4ever.quest quest/NPC pages = Questie Forever data for client 1.60.1.70790, wowhead classic/forever series pages). About 70 NPC pages and 20 quest pages were read; every route NPC coordinate checked matched the Forever data within 0.2 except the two listed in F-27.

Counts: 21 routes, 1732 steps, 560 QuestIDs titles, 449 Prereqs titles.

Severity totals: BUG 15, RISK 6, NIT 10 (no RULE findings: data files contain no gameplay automation or UI).

---

## Findings, most severe first

### F-1 BUG  "The Tower of Althalaxx" has two part numberings and the merged ID list kills the Ashenvale chain
Routes.lua:305-322 (Darkshore, parts 1-3 = 965, 966, 967) vs Routes.lua:532-668 (Ashenvale, parts 1-4 = 967, 970, 973, 1140); QuestIDs.lua:153, :562, :582, :641 define the title four times and the merge loop (QuestIDs.lua:739-746) keeps the last one, `{ 965, 966, 967 }` (zz_v2_darkshore).
Scenario: a Night Elf finishes Darkshore (965-967 flagged). In Ashenvale `TurnedIn("The Tower of Althalaxx")` = 3, so `A(... part 2)` at L538 is `turnedIn >= part` -> **done/hidden**, likewise T#2, A#3, T#3; A#4 (L577) is shown while Delgren does not offer it (970/973 undone) and is then marked done by the offers check. The 970 -> 973 -> 1140 chain never appears.
Fix: one global numbering. QuestIDs: a single `["The Tower of Althalaxx"] = { 965, 966, 967, 970, 973, 1140 }` (delete the other three); Ashenvale steps become parts 3 (T at L537), 4 (L538-544), 5 (L545-576), 6 (L577-668). Add a load-time check in QuestIDs.lua that errors (or at least records) when a title is defined twice with a different list; the same silent override also hits "Hints of a New Plague?" (F-2) and "Crown of the Earth" (harmless, last list is the complete one).

### F-2 BUG  "Hints of a New Plague?" prerequisite is itself, and the route/IDs miss one chain quest
Prereqs.lua:169 `["Hints of a New Plague?"] = { all = { 659 }, level = 30 }` while 659 *is* the part-1 quest the route picks up at Routes.lua:907 (Phin Odelic). `PrereqsMet` can never be true before 659 is done, so `RouteStepDone` returns true for that pick-up for ever; the Arathi part-2 pick-up (L975) needs `TurnedIn == 1`, so the whole chain is dead in the guide.
Also: Forever (wow4ever) has five quests: 659 Phin -> Quae, **657 Quae -> Kinelory ("Speak to Kinelory")**, 658 Quae courier, 660 Kinelory escort, 661 Quae -> Phin. The route has 4 parts and skips 657; QuestIDs.lua:128 lists five IDs in the wrong order and QuestIDs.lua:183 overrides it with four. Without 657 Kinelory will not offer 660, and the guide marks A#3 (L978) done when she offers nothing.
Fix: Prereqs.lua:169 -> `{ level = 30 }` (the chain's own order is handled by parts); QuestIDs: one entry `{ 659, 657, 658, 660, 661 }`; Routes.lua: after L974 insert `A("Hints of a New Plague?", "Quae", 60.2, 53.9, 34, 2)` and `T("Hints of a New Plague?", "Kinelory", 60.2, 53.8, 34, 2)`, renumber the existing parts 2/3/4 to 3/4/5 (L975-981, L1021 note).

### F-3 BUG  Western Plaguelands opening is gated on a city quest the route never mentions, and the cauldron chain is accepted out of order
Routes.lua:1716-1720. Prereqs.lua:383 `Clear the Way` needs any of 5066/5090/5091 = "A Call to Arms: The Plaguelands!" (Stormwind/Ironforge/Darnassus; wowhead classic 5092 "Requires Any", wow4ever confirms); `All Along the Watchtowers` and `The Scourge Cauldrons` need 5092 (Clear the Way) done (wow4ever: "First you need: Clear the Way"). The route picks all three up at arrival and turns Scourge Cauldrons in at L1719 before Clear the Way is done at L1727.
Scenario: a player arriving at Chillwind without the city quest sees no pick-ups at all (all three hidden by `PrereqsMet`), the route window fills with `go`/`do` steps for quests they cannot hold, and Target: Felstone Field (L1720) is never offered.
Fix: add `G("Take 'A Call to Arms: The Plaguelands!' in your capital before coming", ...)` or an `A(...)` for it on the capital map; move L1717-1720 (A Watchtowers, A/T Scourge Cauldrons, A Target: Felstone Field) to just after L1727.

### F-4 BUG  "A Strange Historian" (WPL) requires "Auntie Marlene" from Eastern Plaguelands, which every chain does later
Routes.lua:1723 vs 1810. wow4ever: A Strange Historian (5153) "First you need: Auntie Marlene" (5152, Pamela Redpath, EPL); Prereqs.lua agrees (the checker reports "not in any route" because Auntie Marlene is only *accepted*, L1810, never turned in). All four chains order WPL (51-58) before EPL (53-61).
Scenario: L1723 hidden; the Chromie block L1734-1745 (Annals of Darrowshire, A Matter of Time, Brother Carlin, Counting Out Time) has no held quest so every step is "done"; `T("Brother Carlin")` at L1813 is dead too. The player loses ~5 quests and 10k XP without any hint.
Fix: start EPL with the Darrowshire/Pamela block (L1805-1810 plus `T("Auntie Marlene", "Marlene Redpath", 49.2, 78.6, ...)`), then A Strange Historian and the Chromie block, or move Marlene's quests into a "Return to WPL" segment of the EPL route.

### F-5 BUG  Loch Modan: "Resupplying the Excavation" needs an Ironforge round trip that the route never does
Routes.lua:477 vs 499/514. wow4ever: Resupplying the Excavation (273) "First you need: Powder to Ironband" (302); the Classic/Forever chain is Excavation Progress Report (Ironband -> Jern, L499/L514) -> Report to Ironforge (Jern) -> Powder to Ironband (Ironforge -> Jern) -> Resupplying -> After the Ambush -> Protecting the Shipment. Prereqs.lua:36 has `all = { 302 }` but 302 is not in QuestIDs.
Scenario: L477 hidden at arrival; L494-498 (Huldar/Miran/Ironband escort) are "done" with nothing held, so the whole excavation block is skipped and Excavation Progress Report is picked up at L499 only because the player walks past.
Fix: after L514 add `A("Report to Ironforge", "Jern Hornhelm", 37.2, 47.4, 18)`, a `G("Ironforge ...")`, `T/A("Powder to Ironband", ...)`, `T("Powder to Ironband", "Jern Hornhelm", ...)`, then move L477 + L494-498 after it; add 302/"Powder to Ironband" and "Report to Ironforge" to QuestIDs.

### F-6 BUG  Wetlands: Lightforge Ingots / The Lost Ingots belong to Duskwood's Sven chain; wrong giver, wrong order, unreachable at that level
Routes.lua:729, 760, 763-766. wow4ever/wowhead: these are steps 11-12 of Sven's Revenge (Seeking Wisdom -> The Doomed Fleet -> Lightforge Iron -> **The Lost Ingots (324, given by the Waterlogged Chest at 12.1, 64.2)** -> **Lightforge Ingots (526, needs The Lost Ingots)** -> Blessed Arm -> Armed and Ready -> Morbent Fel). Glorin Steelbrow gives Lightforge Iron, Blessed Arm, Lightforge Ingots, Cleansing the Eye, never The Lost Ingots. Prereqs.lua:74/80 encode the right order (526 needs 324, 324 needs 321 = The Doomed Fleet); the route has it backwards and sits in Wetlands at 24-29 while Seeking Wisdom is only *accepted* in Duskwood (L865) and never turned in.
Scenario: both pick-ups hidden for the whole Wetlands route; the `D` at L760 sends players to the Lost Fleet with nothing to loot.
Fix: delete L729, 760, 763-766 from Wetlands; in Duskwood after L865 add `T("Seeking Wisdom", "Glorin Steelbrow (Menethil Harbor, Wetlands)")`, then The Doomed Fleet, Lightforge Iron (Flying Osprey wreck), `A("The Lost Ingots", "Waterlogged Chest", 12.1, 64.2, 29)`, Lightforge Ingots, Blessed Arm, Armed and Ready (Sven), Morbent Fel (elite). Add 321/322/323/325 to QuestIDs.

### F-7 BUG  Wetlands: "Lifting the Curse" is turned in at the Intrepid's strongbox, and is accepted before its prerequisite
Routes.lua:756, 759, 762. wow4ever: Lifting the Curse (290) "Turn in to: Intrepid's Locked Strongbox, Wetlands (14.4, 24.0)", previous quest The Cursed Crew (289), next The Eye of Paleth (-> Glorin, then Cleansing the Eye). The route turns it in to Fitzsimmons (L762) and accepts it together with The Cursed Crew (L755-756) although Prereqs.lua:79 says it needs 289, so it is hidden while the route is at the Lost Fleet (L758-759) and only appears after L761.
Fix: move L756 after L761; change L762 to `T("Lifting the Curse", "Intrepid's Locked Strongbox (underwater)", 14.4, 24.0, 29)` followed by `A("The Eye of Paleth", ...)`, `T("The Eye of Paleth", "Glorin Steelbrow", 10.6, 60.6, 29)`; the Lost Fleet visit then needs to come after the Fitzsimmons turn-in (or be split in two).

### F-8 BUG  Wetlands: "War Banners" needs "Report to Captain Stoutfist", missing from the route
Routes.lua:726; Prereqs.lua:72 `all = { 473 }`; wow4ever: Report to Captain Stoutfist (473) is given by **Valstag Ironjaw (10.1, 56.9)**, min level 23, "Then comes: War Banners". 473 is not in QuestIDs.
Scenario: War Banners hidden; Nek'rosh's Gambit (L754) and its `D` (L768) never happen.
Fix: before L726 add `A("Report to Captain Stoutfist", "Valstag Ironjaw", 10.1, 56.9, 24)` and `T("Report to Captain Stoutfist", "Captain Stoutfist", 9.9, 57.5, 24)`; add `["Report to Captain Stoutfist"] = { 473 }`.

### F-9 BUG  Tanaris: the Fizzledowser chain is accepted all at once and its objectives are placed before the turn-ins
Routes.lua:1291-1293, 1321-1331. wow4ever: Noxious Lair Investigation (82) "First you need: Gadgetzan Water Survey"; The Scrimshank Redemption (10) needs Noxious Lair Investigation (Prereqs.lua agrees). The route does `D(Noxious)` at L1322 and `D(Scrimshank)` at L1328 before the previous quests are turned in at L1329-1331, so the player visits the Noxious Lair and Scrimshank's camp without the quests and must go back twice.
Fix: L1321 (survey) -> Gadgetzan `T` Water Survey + `A` Noxious -> Noxious Lair `D` -> `T` Pestlezugg + `A/T` Insect Part Analysis -> `A` Scrimshank -> southern `D` -> `T`. Drop the early accepts at L1292-1293.

### F-10 BUG  Stranglethorn Vale: two pick-ups precede the quests they require
Routes.lua:1232 "Voodoo Dues" needs Return to MacKinley (L1270; wow4ever and Prereqs.lua), its `D` at L1246 (Maury, Jon-Jon, and Chucky's Huge Ring, which the note omits) is wasted. Routes.lua:1171 "Troll Witchery" needs Kurzen's Mystery (Prereqs.lua), turned in at L1205 *after* Troll Witchery's own turn-in at L1204.
Fix: move L1232 and L1246 after L1270 (Mistvale/Gurubashi are on the way back north); swap L1204/L1205 and move L1171 after L1205 or keep it with a `do` placed after the Kurzen's Mystery turn-in.

### F-11 BUG  Winterspring: Salfa/Donova pick-ups are ordered before their prerequisites
Routes.lua:1861 "Beads for Salfa" needs Winterfall Activity turned in (L1914); L1866 "Threat of the Winterfall" needs Trouble in Winterspring! (Meggi, Everlook, L1887 -> Donova L1915). Both confirmed on wow4ever. The first Winterfall camp visit (L1867-1870) therefore happens with neither quest held.
Fix: Starfall/Everlook first (L1874-1887), Winterfall Village for Winterfall Activity (L1898-1899) -> Salfa `T` -> Beads; Donova: `T` Trouble in Winterspring! then `A` Threat of the Winterfall, then the Pathfinder/Totemic kills.

### F-12 BUG  Feralas: part 1 of "Against the Hatecrest" is a different quest, and two pick-ups precede their prerequisites
Routes.lua:1355-1357. In Forever/Questie the Shandris -> Latronicus step is **"Report to Latronicus Moonspear" (3130)** and it needs Return to Feathermoon Stronghold (L1365); "Against the Hatecrest" is the single quest 2869 from Latronicus. QuestIDs.lua:285 `{ 3130, 2869 }` makes the ID mapping work, but `offersByNpc` compares *titles*, so after talking to Shandris the pick-up is marked done ("she doesn't offer it") and the naga-scale `D` at L1362 runs before the quest is held. Routes.lua:1391 "Doling Justice" needs Freedom for All Creatures turned in (L1394) while its `D` is at L1393.
Fix: rename L1355-1356 to "Report to Latronicus Moonspear" (own QuestIDs entry `{ 3130 }`, Against the Hatecrest -> `{ 2869 }`), move them after L1365; move L1391/1393 after L1394.

### F-13 BUG  Duskwood: Sven's Revenge has no turn-in step and Ghoulish Effigy is accepted before Juice Delivery
Routes.lua:793-798: Sven's Revenge is completed at the stump object, which the route never shows (`A("Sven's Camp")` at L798 is hidden by Prereqs.lua:93 until 95 is flagged). Routes.lua:825-826: Ghoulish Effigy (wow4ever "First you need: Juice Delivery") is picked up two trips before Juice Delivery is turned in (L866); the ghoul-rib `D` at L826 is wasted.
Fix: insert `T("Sven's Revenge", "Stump at Yorgen Farmstead", 50.0, 77.8, 22)` before L798; move L825-826 after L866 (ghouls at 26.9, 34.3 are next to Abercrombie anyway).

### F-14 BUG  Chain order: Burning Steppes (min 50) is listed before Un'Goro (min 48) for Gnome/Dwarf/Human
Routes.lua:2014-2016. `FindRoute` takes the first route with `level >= min - 2`, so at 48-49 these races are sent to Burning Steppes (50-58) while Un'Goro (48-56) waits behind it; the Night Elf chain has the natural order.
Fix: swap `BURNING_STEPPES` and `UNGORO` in the three chains (or raise BS `min` to 51).

### F-15 BUG  Darkshore: later parts of "Beached Sea Turtle/Creature" are accepted before earlier parts are turned in
Routes.lua:317, 348-351 (rebuilt zone, but the engine model is the issue). These are independent quests sharing a title; the route numbers them 1-5 in the order the player should find them, but `RouteStepActionable` shows A#n only when `TurnedIn == n-1`, and `LogByTitle` assigns `entry.part` from the ID list, so a player who loots them in another order holds "part 3" while the route waits on part 2: the pick-up stays hidden and the matching turn-in reads `HeldPart == nil` -> done.
Fix: give each beached quest its own title suffix in the route and IDs (e.g. "Beached Sea Turtle (Twin Shores)"), or special-case non-chain shared titles so parts are not required to be sequential.

### F-16 RISK  Forever "Changed"/"Elite"/"New" quests on the non-rebuilt routes
From foreverchanges.pro zone lists (Forever 1.60.1) compared with the route titles. Every route title exists in Forever (the only title missing from QuestIDs is "The Bloodsail Buccaneers", excluded on purpose at QuestIDs.lua:736, although Forever lists exactly the route's 5 parts, so the exclusion looks obsolete). Risk = the route's `do` notes/levels were written from Classic and may no longer match:

| Zone | Changed (objectives may differ) | Elite in Forever (route has no group note) | New IDs / structure |
|---|---|---|---|
| Dun Morogh | Tools for Steelgrill | Protecting the Herd (kill Vagash, lvl 12; route L454 has no do/turn-in) | Rime's Wrath x2, Stolen Blasting Powder x2 (ids OK), Dawn in the Mountains, Frosthowl, Never Saddle on Quality, Quarry's Smith, Farsen's Watch are Forever-new; Father Gavin / Earthseer Farsen pages 404 on wow4ever (coords unverified) |
| Loch Modan | In Defense of the King's Lands (one of 4), Mercenaries (now Elite) | Mercenaries | - |
| Wetlands | In Search of The Excavation Team, Blisters on the Land, Uncovering the Past, War Banners, Ormer's Revenge #3 | Thandol Span chain | Return the Statuette has a 2nd quest (98189) and A Friend of the Family 2 (98190/98191): route has 1 part each (ids list 2 -> holding the second makes `entry.part` 2 vs route part 1); Crimson Crate Delivery (98240) is Forever-new with no giver in Questie data: "Howin Kindfeather" (L704) unverifiable (NPC page 404); Spoils of War is new (98197, ids OK) |
| Duskwood | Look to the Stars x4 (route 3 parts), Bride of the Embalmer | Bride of the Embalmer, Morbent Fel | The Weathered Grave chain is level 35 (route starts it at 29, fine as min level) |
| Hillsbrad | Farren's Proof (one part), Hints of a New Plague? #5 | - | An Alarming Request is Forever ID 92432 in Alterac; giver "Emissary Jacques" unverified (404) |
| Arathi | Stromgarde Badges, Wanted! Marez Cowl, Wanted! Otto and Falconcrest | those three + Malin's Request, Trelane's Defenses, An Apprentice's Enchantment, Attack on the Tower | Sunken Treasure has 5 quests (665,666,668,669,670); ids list 4, route 4 parts (5th is Booty Bay) OK |
| Desolace | Bodyguard for Hire, Gizelton Caravan, The Karnitol Shipwreck #4 | - | Down the Scarlet Path #2 goes to Raleigh in Southshore (route L1084 turns in to Anton only, fine for part 1) |
| STV | Colonel Kurzen, Stranglethorn Fever, Scaring Shaky, Venture Company Mining, Big Game Hunter | Colonel Kurzen, Big Game Hunter, Curse of the Tides, Panther/Raptor Mastery final | - |
| Tanaris | - | The Stone Watcher | - |
| Feralas | The Ruins of Solarsal | The Super Snapper FX | - |
| Hinterlands | Saving Sharpbeak | Saving Sharpbeak, Return to the Hinterlands | - |
| Un'Goro | Alien Ecology, Expedition Salvation | It's Dangerous to Go Alone | - |
| Felwood | Silver Heart, Beads for Salfa | Verifying the Corruption | Timbermaw Ally exists as 6131 (new) and 8460; ids only `{ 8460 }` |
| Burning Steppes | - | Dragonkin Menace | Helendis Riverhorn at 85.8, 69.0 (route 84.0, 68.0) |
| WPL | Return to Chillwind Camp #2 and #4, Mold Rhymes With... | Unfinished Business #3 | Argent Dawn Commission exists twice (Pureheart, Duke); ids `{ 5401 }` only |
| EPL | - | A Strange Historian (56) | Hameya's Plea is level 60 |
| Winterspring | Toxic Horrors | High Chief Winterfall | - |
| Silithus | Report to Marshal Bluewall, Scouring the Desert (PvP) | Wanted - Deathclasp | The Twilight Lexicon and A Terrible Purpose are level 60 in Forever and are **not** on Hermit Ortell's Forever NPC page (he gives True Believers, Still Believing); route L1983/L1989 givers unverified |

Spot-checked `do` notes that still read Classic but are probably fine: Zanzil's Secret, Skullsplitter Tusks, Kurzen's Mystery tablets (route cites Classic wiki for locations since Forever sources are silent).

### F-17 RISK  QuestIDs lists with more IDs than route parts where the extra ID may be an alternative, not a later part
QuestIDs.lua: Return the Statuette `{ 286, 98189 }`, Rime's Wrath `{ 99160, 99161 }`, Stolen Blasting Powder `{ 95213, 95214 }`, Messenger to Darkshire `{ 145, 146 }`, Doling Justice `{ 2970, 2972 }`, The Smoldering Ruins of Thaurissan `{ 3701, 3702 }`, Dark Iron Legacy `{ 3801, 3802 }`, A Plague Upon Thee `{ 5903, 5904, 6389 }` (3 Alliance versions). The route has one part for each. If the second ID is a race/class/faction *variant* of the same step (likely for Rime's Wrath, Stolen Blasting Powder, Messenger to Darkshire, Doling Justice, A Plague Upon Thee), then `LogByTitle` gives the held quest `part = 2`, `HeldPart` returns nil for the route's part-1 steps, the pick-up is re-shown while held and the turn-in is marked done. Where the second ID is a real later part (Senir's Observations, In Defense of the King's Lands, A Dark Threat Looms, The True Masters, Cortello's Riddle, Look To The Stars) the extra IDs are harmless.
Fix: for variants keep only the ID the Alliance player can get, or make `LogByTitle` ignore `position` when the list is marked `variants = true`.

### F-18 RISK  Prerequisite levels above the written pick-up level hide 16 pick-ups at the route's own level
Checker list (`Prereqs.level` > step `lvl`): Darkshore L248 (11 vs 12); Wetlands L680 (20 vs 21), L681 Fall of Dun Modr (20 vs **25**); Hillsbrad L907, L910, L912 (28 vs 30), L911 (28 vs 29); Desolace L1033 Down the Scarlet Path (30 vs 34); STV L1110 Krazek's Cookery (30 vs 32); Tanaris L1294-1296 (43 vs 44/45); Un'Goro L1524 Lost! (49 vs 50); WPL L1736 (52 vs 53), L1749/L1751 Scholomance, Skeletal Fragments (53 vs 55). Not wrong per se (the engine waits), but the `do`/`turnin` steps that follow are reached first and silently count as done (`entry == nil`), so e.g. Fall of Dun Modr is turned in at L717 at level 24 by a route that cannot have picked it up before 25.
Fix: move those pick-ups to a later visit, or lower `Prereqs.level` where wow4ever's "minimum level" is lower than the file says (Fall of Dun Modr min 25 is correct in Forever).

### F-19 RISK  Prereqs reference IDs that no QuestIDs title owns
Prereqs.lua: 302 (Powder to Ironband), 473 (Report to Captain Stoutfist), 321 (The Doomed Fleet), 610 ("Pretty Boy" Duncan), 5066/5090/5091 (A Call to Arms). `QuestDone()` still works via `IsQuestFlaggedCompleted`, but the `charData.done` fallback (pre-Forever flags, quests done while the API is secret) never can, and the guide cannot name the missing quest to the player. Add them to QuestIDs (see F-3, F-5, F-6, F-8).

### F-20 RISK  Out-of-zone legs implied but not written
Duskwood L865 "Seeking Wisdom" (turn-in Glorin, Wetlands) has no turn-in anywhere; Felwood L1632 "Seeking Spiritual Aid" -> L1643 "Cleansed Water Returns to Felwood" skips the Moonglade/Darnassus leg; Dun Morogh has 10 pick-ups (L423-465) with no `do`/`turnin` at all (Beer Basted Boar Ribs, Stocking Jetsteam, Bitter Rivals, Frosthowl, Never Saddle on Quality, Protecting the Herd, Quarry's Smith, Stolen Blasting Powder, Farsen's Watch, The Lost Pilot); Hinterlands L1446, L1480, L1483, Un'Goro L1513/L1530/L1559/L1569, Felwood L1622/L1674, BS L1698/L1701/L1707, WPL L1769/L1772/L1778/L1795, EPL L1852-1853, WS L1865/L1873/L1880-1881/L1886/L1928/L1931 are pick-ups whose completion lives in another route or nowhere. The engine tolerates it (a held quest with no steps costs nothing), but 60 accept-without-turnin steps (full list in check.txt) mean the "done" counters for those titles come only from `IsQuestFlaggedCompleted`. Low risk; worth a `note` field on each so the display can say where it ends (the `A()` helper has no `note` slot, see F-23).

### F-21 RISK  Same NPC, order conflict with in-game prerequisites
Besides F-2/F-6/F-11: Raene Wolfrunner (Ashenvale L585 "An Aggressive Defense" needs Raene's Cleansing **part 1** = 991, picked up at L550, so this one is fine; the checker flags it only because 991 is in the title's list). No other same-NPC conflicts were found; the busyNpcs rule (LevelGuide.lua:698-712) will however hide every later pick-up from Kreldig Ungor / Captain Stoutfist / Donova Snowden while any earlier quest of theirs is still open, which the routes rely on by accepting their quests in pairs.

### F-22 NIT  Route level ranges and level order
Tanaris `min = 40` but steps run 43-51 and `max = 50` (L1347-1348 are lvl 51 -> `OUTLEVELED` never clears them but `FindRoute` drops the route at 51); Hinterlands `min = 40`, steps 43-51; EPL `min = 53`, steps 55-60; Feralas `min = 40`, steps 42-50. Loch Modan L503-509 drop to 15-16 after lvl 18 steps, so at level 20 (`OUTLEVELED = 4`) the Farstrider Lodge block is marked done before the player gets there. Set `min` to the first step's level and keep `lvl` non-decreasing.

### F-23 NIT  Notes written into the `part` argument are silently dropped
Routes.lua:727 (`A("The Third Fleet", ..., 24, "Needs Dwarven Honeymead ...")`), 991-993, 1011 (`D(..., "Location approximate ...")`). `A()`/`D()` nil a non-number `part`, so the text is lost. Give `A()` a `note` field (`RouteDisplay` already prefers `step.npc` then `step.note`) and append these to the `note` argument of `D()`.

### F-24 NIT  Plan zones without routes and gaps at the start of chains
Routes.lua:1998-2008 name Elwynn Forest, Westfall, Redridge Mountains, Riverglades and Dustwallow Marsh, none of which has a route (intended as travel hubs; `PlanStep` only offers them). Humans have no route before 20 (chain starts with WETLANDS) and Dwarves/Gnomes none before 6 (DUN_MOROGH `min = 6`), so levels 1-5/1-19 see only the plan line.

### F-25 NIT  QuestIDs titles defined in several parts with different lists
QuestIDs.lua: "Hints of a New Plague?" (lines 128/183), "The Tower of Althalaxx" (153/562/582/641), "Crown of the Earth" (teldrassil_darkshore vs zz_v2_teldrassil). Only the last survives; add a merge-time conflict check. Also unused: "On Guard in Stonetalon", and "Timberling Seed" (kept only as the `renamed` source; 918 appears under both "Timberling Seed" and "Timberling Seeds").

### F-26 NIT  Two parts of "Argent Dawn Commission" share one ID
Routes.lua:1721 (Pureheart, WPL) and L1817 (Duke, EPL) are different Forever quests; QuestIDs.lua:291 `{ 5401 }` covers one. Whichever is not 5401 is matched by title only; after the first is done the second pick-up is `turnedIn >= 1` -> done, which is acceptable only if the player wants one commission.

### F-27 NIT  NPC coordinates that differ from Forever data
Mountaineer Kadrell: route 32.6, 49.7 (L475-476, 492, 521) vs wow4ever 34.2, 47.8. Helendis Riverhorn: route 84.0, 68.0 (L1682, 1706-1707) vs 85.8, 69.0. All other checked NPCs (about 70 across Wetlands, Duskwood, Hillsbrad, Arathi, Desolace, STV, Tanaris, Feralas, Hinterlands, Un'Goro, Felwood, Burning Steppes, WPL, EPL, Winterspring, Silithus, Dun Morogh, Loch Modan) match to 0.2. Wrong givers: F-6 (The Lost Ingots), F-7 (Lifting the Curse turn-in), F-12 (Against the Hatecrest #1 title).

### F-28 NIT  Hillsbrad "Noble Deaths" accepted before "Foreboding Plans"
Routes.lua:909 vs 945; wow4ever: Noble Deaths (512) "First you need: Foreboding Plans" (a Syndicate drop). Hidden on the first Southshore visit; the signet-ring `D` at L937 therefore runs without the quest. Move L909 after L945 and the ring kills to a second Alterac trip, or note that Foreboding Plans drops in Hillsbrad first.

### F-29 NIT  Structural checker results that are intentional (recorded so they are not re-reported)
Turn-ins with no accept in the same route: 39 (check.txt), all either cross-zone (Flight to Auberdine, Trek to Ashenvale, The Sleeper Has Awakened, The Sunken Temple, Linken's Memory, Aquementas, The New Springs, It's a Secret to Everybody #3, Speak to Salfa, Felnok Steelspring, Little Pamela, Brother Carlin) or from items/capitals (Senir's Observations, Supplies to Tannok, Messenger to Darkshire, Southshore, Plea To The Alliance, Reclaimers' Business, Stoley's Debt, To The Hinterlands, Linken's Sword, Winterfall Firewater, Mystery Goo, The Final Piece, Find Ranshalla, Wasteland...). `do` without accept: Chapter I-IV (page drops), Keep An Eye Out, Up to Snuff, Venture Company Mining, A Meal Served Cold, Pearl Diving, Favored of Elune?, Sprinkle's Secret Ingredient, The Super Snapper FX, Whiskey Slim's Lost Grog, Smoldering Ruins, Hameya's Plea, Moontouched Wildkin: all noted in the step text. No duplicate accepts, no duplicate turn-ins, no nil or out-of-range coordinates, every step has a numeric `lvl`.

### F-30 NIT  QuestIDs part counts vs route parts (informational)
Counts differ for 16 titles (check.txt "QuestIDs part count != route parts"); all are "more IDs than parts" and covered by F-1 (Tower), F-2 (Hints), F-17 (possible variants) or are true longer chains the route only starts.

---

## Summary
The data is structurally clean (no bad coordinates, levels or duplicate steps, every title has IDs) and the NPC coordinates for the Classic-era zones agree with Forever's Questie data almost everywhere. The real problems are in chain logic: (1) the merged QuestIDs lists silently overwrite each other and, for "The Tower of Althalaxx", break the Ashenvale chain, (2) a self-referential prerequisite and a missing chain quest kill "Hints of a New Plague?", and (3) about a dozen routes accept quests before their in-game prerequisite is done (WPL Chillwind opening, A Strange Historian, Resupplying the Excavation, Wetlands Lightforge/Lost Ingots and Lifting the Curse, War Banners, Tanaris Fizzledowser chain, STV Voodoo Dues/Troll Witchery, Winterspring Salfa/Donova, Feralas, Duskwood), which the engine turns into hidden pick-ups plus wasted `do` steps. Forever-wise, every route quest still exists, but roughly 30 of them are tagged Changed or Elite and a handful of Forever-new second parts (Return the Statuette, A Friend of the Family, Timbermaw Ally, Argent Dawn Commission, An Alarming Request, Crimson Crate Delivery) are either unrepresented or only half-represented in QuestIDs; the chain-order fixes above are more valuable than re-verifying those notes.
