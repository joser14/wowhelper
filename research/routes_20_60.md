# Alliance 20-60 routes for WoW: Forever (Night Elf priest first)

Research only. Nothing in the addon was changed. This file covers four things: the zone order, a stop list for each zone that is missing, side steps, and a list of differences from the current `LevelGuide/Routes.lua`.

## How this was checked

**Main source: the Forever QuestieDB copy (read as text, never run).** The copy is in the quarantined downloads folder: `QuestieDB/data/Forever/forever{Quest,Npc,Object,Item}DB.lua`.

- The corrections were merged in the order Questie applies them:
  1. `corrections/Forever/legacy/classic*Fixes.lua`
  2. `generated/foreverBase*.lua`
  3. `forever*Fixes.lua`
- A small Python reader parsed the files as Lua literals and wrote the result to the scratchpad. It took the quest IDs, givers and enders, required and quest levels, races and classes, prerequisites, and NPC spawn coordinates from that data.
- The merged data has 4,244 quests, 920 of them added by the Forever delta file.
- Coordinates for "do" steps are the median of all spawns of the mob or object in that zone. They show where to go, not an exact point.

**Verification tags used in this file:**
- **V**: verified against the Forever QuestieDB data. Quest ID, giver/ender name and coordinates match it.
- **W**: taken from the web only:
  - foreverchanges.pro quest lists and quest pages
  - wow4ever.quest
  - wowhead.com/forever
  - warcraft.wiki.gg
  - timesaver.gg
- **U**: unverified. Treat as a placeholder and check in game.

**Coordinates are percent of the zone's own map.**
- For quests that leave the zone, the other zone is named, the way the routes' `On(zone, step)` does.
- Stormwind numbers are on the modern Stormwind map that Forever uses. Example: Bolvar is at 80.2, 38.4, which matches the existing routes.

**Redridge warning.** Forever's data puts Lakeshire about 5 points west of the Classic wowhead numbers.
- Magistrate Solomon is at 24.9, 44.5 in Forever data, 29.9, 44.5 on Classic wowhead.
- The Lakeshire flight master is at 25.5, 59.4 in Forever data, 30.6, 59.4 on Classic wowhead.
- Use the Forever numbers, but check one in game before trusting the whole zone.

**Riverglades is not in Questie yet.** None of its roughly 170 quests has a giver or coordinates in the Forever QuestieDB copy, and wowhead/forever and foreverchanges list no giver coordinates either. Its section therefore lists hubs and quest IDs/levels (W) and leaves giver coordinates as U.

**New steps must be wrapped in `New(...)`.** The header of `Routes.lua` explains why.

---

## 1. Zone order 20-60

### 1.1 Night Elf (the main user: priest)

| Levels | Zone | Hub (hearth) | Flight paths to take | Travel and notes |
|---|---|---|---|---|
| 20-24 | Ashenvale (existing route) | Astranaar | Astranaar (Daelyshia 34.4, 48.0) | Train at 20 in Darnassus first (see 3.1). From Auberdine, take the boat to Rut'theran, then the portal into Darnassus. |
| 24-27 (optional) | **Stonetalon Mountains** (new, section 2.1) | Stonetalon Peak (Innkeeper Faralia 35.8, 5.7) | Stonetalon Peak (Teloren 36.4, 7.2) | Ride south-west out of Ashenvale. Saves you doing the low Ashenvale grind quests. |
| 24-30 | Ashenvale (rest) → Wetlands → Duskwood (existing) | Menethil, then Darkshire | Menethil (Shellei Brondir 9.5, 59.7), Darkshire (Felicia Maline 77.5, 44.3), Lakeshire (Ariena Stormfeather 25.5, 59.4) on the walk from Darkshire | Boat Auberdine → Menethil. Train at 22, 24, 26, 28 in Darnassus or Ironforge. Ironforge is reached from Menethil via the Loch Modan road, Thelsamar FP (Thorgrum Borrelson 33.9, 51.0), then a flight. |
| 28-33 | Hillsbrad (existing) and **Alterac Mountains** (new, section 2.11) | Southshore | Southshore (Darla Harris 49.3, 52.3) | Optional Forever dungeons: City of Dalaran (28-35) and Excavation Site: Wetlands (26-33). |
| 30-40 | Arathi, Desolace, Stranglethorn (existing) | Refuge Pointe / Nijel's Point / Booty Bay | Refuge Pointe (Cedrik Prose 45.7, 46.1), Nijel's Point (Baritanas Skyriver 64.7, 10.5), Booty Bay (Gyll 27.5, 77.8) | Booty Bay ↔ Ratchet boat. Desolace is reached from Stonetalon on foot, or by flying to Nijel's Point once you know it. |
| 34-40 | **Dustwallow Marsh** (new, section 2.5) | Theramore (Innkeeper Janene 66.6, 45.2) | Theramore (Baldruc 67.5, 51.3) | Boat Menethil → Theramore. Hand in Fiora Longears (1132, needs level 30). Hearth Theramore. |
| 36-40 (optional) | **Swamp of Sorrows** (new, 2.7) | none (no Alliance flight master in the data) | Nethergarde Keep (Alexandra Constantine, Blasted Lands 65.5, 24.3) | On foot from Duskwood (Deadwind Pass) or from Lakeshire through Redridge Pass. |
| 38-46 | **Riverglades** (Forever, 2.14) | Farholde Keep | Farholde Keep (Gretchen Mayberry 60.6, 81.4, V) | Enter from the new fork off the Redridge → Burning Steppes road, or take the Steamwheedle Port (Tanaris) ship to Powderfuse Port (W). Krol'dok Stronghold, 40-47. |
| 38-44 (optional) | **Badlands** (new, 2.6) | none | no Alliance flight master in the data. Nearest are Thelsamar (Loch Modan) and Lakeshire. | Uldaman (41-51) quests start here. |
| 40-45 (optional) | Shen'dralas / Valley of Bones (Forever, inside Desolace, section 2.15) | Nijel's Point | none | Choose Gelkis or Magram reputation. Takes many grinds; skip if short on time. |
| 42-50 | Feralas, Tanaris, Hinterlands (existing) | Feathermoon / Gadgetzan / Aerie Peak | Thalanaar (Thyssiana 89.5, 45.9), Feathermoon (Fyldren Moonfeather 30.2, 43.2), Gadgetzan (Bera Stonehammer 51.0, 29.3), Aerie Peak (Guthrum Thunderfist 11.1, 46.1) | **Thousand Needles / Shimmering Flats** (2.10) is grey by now. Do only the Brassbolts/Pozzik chains if you pass through. |
| 45-50 (optional) | **Searing Gorge** (2.8) | none | Thorium Point (Lanie Reed 37.9, 30.9) | Fly to Morgan's Vigil (Borgus Stoutarm, Burning Steppes 84.3, 68.3), walk west through Blackrock Mountain, and take the Thorium Point flight path. |
| 46-52 (optional) | **Azshara** (2.9) | none | Talrendis Point (Jarrodenus 11.9, 77.6) | Walk east from Ashenvale (Forest Song). The priest class chain 8254-8257 runs here at 50. |
| 48-56 | Un'Goro, Felwood, Burning Steppes (existing) | Marshal's Refuge / Talonbranch Glade / Morgan's Vigil | Marshal's Refuge (Gryfe 45.2, 5.8), Talonbranch (Mishellena 62.5, 24.2), Morgan's Vigil | |
| 50-55 (optional) | **Blasted Lands** (2.12) | none | Nethergarde Keep 65.5, 24.3 | Buff quests (Bloodmage Drazial/Lynnore). The Fallen Hero chain runs to 60. |
| 55-60 | Western/Eastern Plaguelands, Winterspring, Silithus (existing) | Chillwind / Light's Hope / Everlook / Cenarion Hold | Chillwind (Bibilfaz 42.9, 85.1), Light's Hope (Khaelyn 71.8, 49.6), Everlook (Maethrya 62.3, 36.6), Cenarion Hold (Cloud Skydancer 50.6, 34.5), Moonglade (Silva Fil'naveth 44.1, 45.2) | **Mount Hyjal** (Forever, 56-60, 102 quests, W) is an alternative. The data has flight masters there (Fayran Elthas 68.6, 44.0; Bluebell 55.0, 82.8) but no quest givers (U). |

### 1.2 Where Human, Dwarf and Gnome differ

**Human**
- The current chain starts at Wetlands at 20 and has nothing for 1-20.
- Add these routes:
  - Elwynn 1-10 (out of scope here)
  - **Westfall 10-18** (2.3)
  - **Redridge 17-25** (2.2)
- Then: Duskwood (Darkshire) 22-30, Wetlands, Ashenvale or Hillsbrad.
- Humans reach Ashenvale this way: tram or flight to Ironforge, then Menethil, then the boat to Auberdine.
- Elune's Grace is Night Elf only. Human priests have their own race quests:
  - Divine Grace at 10 (94773-94779, Forever)
  - Arcane Feedback at 20 (5676-5678)

**Dwarf and Gnome**
- After Loch Modan they come down to Wetlands at about 20 (current chain).
- **Redridge (2.2) 20-25** suits them too:
  - Fly Thelsamar → Ironforge, take the tram to Stormwind, fly to Lakeshire.
- **Badlands (2.6)** is the natural 38-44 stop for them. It starts from Loch Modan: Find Agmond (738), and the Uldaman chain from Ironforge.
- Race quests:
  - Dwarf priests: A Lack of Fear (5641/5645/5647) at 20, Ironforge.
  - Gnome priests: Forever's Confounding Flash (94817...) at 10 and Contingency Plan (94818-94820) at 20, both with High Priestess Mims, Ironforge 24.8, 10.0.

### 1.3 Boats, trams and other travel legs

| Leg | Notes |
|---|---|
| Rut'theran (Teldrassil) ↔ Auberdine | Classic boat |
| Auberdine ↔ Menethil Harbor | Main way for a Night Elf to reach the Eastern Kingdoms |
| Menethil ↔ Theramore | Dustwallow access |
| Booty Bay ↔ Ratchet | Needed for the Scythe of Elune chain (1039-1041) and the Pozzik chain |
| Feathermoon ferry | From the Forgotten Coast in Feralas |
| Deeprun Tram, Ironforge ↔ Stormwind | |
| **Steamwheedle Port (Tanaris) ↔ Powderfuse Port (Riverglades)** | Forever; W, timesaver.gg / wow4ever |
| Zephras Isle skycutter → Dalaran | Skyborne starting race only (94946, V) |

### 1.4 Optional dungeons on the way

Levels are from our own `Dungeons/Data.lua` and foreverchanges.

| Levels | Dungeons |
|---|---|
| 20s | The Stockade and Blackfathom Deeps (24-32; Gravestone Scepter wand from 1200) |
| 26-35 | **Excavation Site: Wetlands** (26-33, Forever) and **City of Dalaran** (28-35, Forever) |
| 29-38 | Gnomeregan, RFK |
| 34-45 | SM |
| 35-47 | **The Drowned City** (35-42, Forever, Stranglethorn) and **Krol'dok Stronghold** (40-47, Riverglades) |
| 41-55 | Uldaman, ZF, Maraudon, then **Alcaz Prison** (48-55, Forever, Dustwallow) |
| 50-60 | ST, BRD, then **Blackmaw Hold** (55-60, Azshara) and **Shaper's Terrace** (58-60, Un'Goro) |

---

## 2. Stop lists for the missing zones

The stops are written as calls to the route helpers.
- `lvl` is the character level at which the route does the step.
- The comment holds the quest ID, the quest's required/quest level and the tag.
- `On("Zone", ...)` marks a step on another zone's map.
- Every new step should be wrapped in `New(...)`.

### 2.1 Stonetalon Mountains (Night Elf side trip, 24-27)

Prerequisites from Ashenvale:
- Journey to Stonetalon Peak (1056) needs nothing.
- Pridewings of Stonetalon (1134) needs The Zoram Strand (1008) turned in. The Ashenvale route does that at line 823.

```lua
-- Astranaar (Ashenvale map)
On("Ashenvale", A("Journey to Stonetalon Peak", "Faldreas Goeth'Shael", 35.8, 49.1, 24)),   -- 1056 req18/q18 V
On("Ashenvale", A("Pridewings of Stonetalon", "Shindrell Swiftfire", 34.7, 48.8, 24)),      -- 1134 req18/q21 V, needs 1008
-- Stonetalon Peak
FP("Stonetalon Peak", "Teloren", 36.4, 7.2, 24),                                            -- V (node name assumed "Stonetalon Peak", U)
Home("Stonetalon Peak", "Innkeeper Faralia", 35.8, 5.7, 24),                                -- optional, V
T("Journey to Stonetalon Peak", "Keeper Albagorm", 37.1, 8.1, 24),                          -- 1056 V
A("Reclaiming the Charred Vale", "Keeper Albagorm", 37.1, 8.1, 24, 1),                      -- 1057 req20/q27 V
-- Sun Rock road (Pridewing wyverns), Forever supply quest
A("Stonetalon Supply Run", "Night Elf Courier (gives the supply bag)", 48.6, 39.8, 24),     -- 86574 req20/q24 V (Forever, gives item 277915)
D("Pridewings of Stonetalon", "12 Pridewing Venom Sacs from Pridewing wyverns", 52.9, 43.2, 25),  -- V spawn median
D("Stonetalon Supply Run", "6 Stonetalon Supplies from Pridewing Wyverns (same spot)", 52.9, 43.2, 25),
-- Windshear Crag (Kaela/Gaxim camp)
A("On Guard in Stonetalon", "Kaela Shadowspear", 59.9, 66.8, 25),                           -- 1085 req17/q21 V
T("On Guard in Stonetalon", "Gaxim Rustfizzle", 59.5, 67.2, 25),
A("A Gnome's Respite", "Gaxim Rustfizzle", 59.5, 67.2, 25),                                 -- 1071 req17/q21 V
A("Super Reaper 6000", "Ziz Fizziks", 59.0, 62.6, 25),                                      -- 1093 req16/q21 V
A("Gerenzo's Orders", "Piznik (mining in the Windshear Mine mouth)", 71.9, 60.0, 25),       -- 1090 req17/q22 V (protect Piznik while he mines)
D("A Gnome's Respite", "10 Venture Co. Loggers + 10 Deforesters", 66.4, 52.3, 25),
D("Super Reaper 6000", "Blueprints from Venture Co. Operators", 68.5, 51.9, 25),
D("Gerenzo's Orders", "Defend Piznik until the ore is mined", 71.9, 60.0, 26),
T("Gerenzo's Orders", "Piznik", 71.9, 60.0, 26, 1),
A("Gerenzo's Orders", "Piznik", 71.9, 60.0, 26, 2),                                         -- 1092 V
T("Gerenzo's Orders", "Ziz Fizziks", 59.0, 62.6, 26, 2),
T("Super Reaper 6000", "Ziz Fizziks", 59.0, 62.6, 26),                                      -- 1094 Further Instructions goes to Ratchet: skip
T("A Gnome's Respite", "Gaxim Rustfizzle", 59.5, 67.2, 26),
A("A Scroll from Mauren", "Gaxim Rustfizzle (ends in Stormwind; take it only if a Stormwind trip is planned)", 59.5, 67.2, 26),  -- 1075 V
-- Charred Vale
D("Reclaiming the Charred Vale", "7 each: Bloodfury Harpies 32.8,60.8, Ambushers 30.8,61.6, Slayers 30.2,69.6, Roguefeathers 34.7,68.9", 32.8, 60.8, 26, 1),
T("Reclaiming the Charred Vale", "Keeper Albagorm", 37.1, 8.1, 27, 1),
A("Reclaiming the Charred Vale", "Keeper Albagorm (ends at Falfindel, Thalanaar, Feralas 89.6,46.6: keep for the 40s)", 37.1, 8.1, 27, 2),  -- 1059 V
T("Stonetalon Supply Run", "Innkeeper Faralia", 35.8, 5.7, 27),
G("Fly to Astranaar", 36.4, 7.2, 27, "Turn in Pridewings of Stonetalon to Shindrell Swiftfire (Ashenvale 34.7,48.8)"),
On("Ashenvale", T("Pridewings of Stonetalon", "Shindrell Swiftfire", 34.7, 48.8, 27)),
```

Left out of Stonetalon, with reasons:
- **Covert Ops - Alpha/Beta (1079/1080)** needs both Special Delivery for Gaxim (1077, a Stormwind leg) and Ineptitude + Chemicals = Fun (1074, an Ironforge alchemy turn-in). Kaela's Update (1091), Enraged Spirits (1083) and Wounded Ancients (1084) come after them. Route the whole chain only if a city leg is planned.
- **Retrieval for Mauren (1078, Stormwind)** gives the Spellcrafter Wand (ilvl 26). It is a good priest wand if the Stormwind leg is done.
- **Forever object trail** in the Stonetalon part, all V: Stepping Stones 79192, then Scramble 79980 (Pocket Litter 40.8, 52.6), then Wet Job 79974 (Mound of Dirt 39.6, 49.8). It continues to Loch Modan (Carved Figurine 49.5, 12.9) and Eagle's Fist 79975 (level 32, both factions). It starts in Westfall (Burned-Out Remains 37.4, 50.7) and the Barrens, so it is not useful for a Night Elf.

### 2.2 Redridge Mountains (Human/Dwarf/Gnome 17-25; Night Elf optional on the walk to Lakeshire FP)

All IDs, givers and coordinates are V (Forever data, so on the Forever Redridge map).

```lua
-- Three Corners road from Elwynn
A("Encroaching Gnolls", "Guard Parker (patrols the road)", 10.4, 71.3, 17),                 -- 244 req11/q16
T("Encroaching Gnolls", "Deputy Feldon", 25.6, 60.0, 17),
A("Assessing the Threat", "Deputy Feldon", 25.6, 60.0, 17),                                 -- 246
A("Show of Force", "Deputy Feldon", 25.6, 60.0, 17),                                        -- 98407 req11/q17 (Forever changed; 5 Spiked Collars from Redridge Thrashers, spot U)
FP("Lakeshire", "Ariena Stormfeather", 25.5, 59.4, 17),
Home("Lakeshire", "Innkeeper Brianna", 21.9, 44.8, 17),
-- Lakeshire pick-ups
A("Selling Fish", "Dockmaster Baren", 22.6, 47.4, 17),                                      -- 127 req16/q21
A("The Lost Tools", "Foreman Oslow", 27.1, 48.6, 17),                                       -- 125 req15/q16
A("Redridge Goulash", "Chef Breanna", 17.6, 43.8, 17),                                      -- 92 req15/q18
A("A Free Lunch", "Darcy (inn)", 21.5, 44.3, 17),                                           -- 129 req12/q15
A("Hilary's Necklace", "Shawn", 24.2, 53.6, 17),                                            -- 3741 req12/q15
A("Solomon's Law", "Bailiff Conacher (town hall)", 24.6, 44.3, 17),                         -- 91 req17/q23
A("Messenger to Stormwind", "Magistrate Solomon (optional city chain 120/121/143/144/145)", 24.9, 44.5, 17), -- 120
A("A Baying of Gnolls", "Verner Osgood", 25.9, 47.3, 17),                                   -- 124 (needs 119; see note)
D("Hilary's Necklace", "Glinting Mud in the lake shallows south of the bridge", 23.7, 54.2, 18),
D("The Lost Tools", "Sunken Chest at the bottom of Lake Everstill", 36.4, 54.7, 18),
D("Selling Fish", "10 Spotted Sunfish from murlocs on the east lake shore", 45.2, 59.3, 18),
D("Redridge Goulash", "Condor meat 49.7,58.2, spider meat 45.3,47.7, Great Goretusk snouts 23.2,60.5", 45.3, 47.7, 19),
D("Assessing the Threat", "10 Redridge Mongrels 24.5,71.7 and 6 Poachers 27.2,82.3", 24.5, 71.7, 19),
T("A Free Lunch", "Guard Parker", 10.4, 71.3, 19),  A("Visit the Herbalist", "Guard Parker", 10.4, 71.3, 19), -- 129 -> 130
T("Assessing the Threat", "Deputy Feldon", 25.6, 60.0, 19),
T("Visit the Herbalist", "Martie Jainrose", 16.8, 46.3, 19),  A("Delivering Daffodils", "Martie Jainrose", 16.8, 46.3, 19), -- 131
A("An Unwelcome Guest", "Martie Jainrose", 16.8, 46.3, 19),                                 -- 34 req18/q24
T("Delivering Daffodils", "Darcy", 21.5, 44.3, 19),
T("Hilary's Necklace", "Hilary", 24.1, 53.6, 19),
T("The Lost Tools", "Foreman Oslow", 27.1, 48.6, 19),  A("The Everstill Bridge", "Foreman Oslow", 27.1, 48.6, 19), -- 89 (Forever changed)
T("Selling Fish", "Dockmaster Baren", 22.6, 47.4, 20),  A("Murloc Poachers", "Dockmaster Baren", 22.6, 47.4, 20),  -- 150 req20
T("Redridge Goulash", "Chef Breanna", 17.6, 43.8, 20),
A("Blackrock Menace", "Marshal Marris", 28.4, 49.0, 20),                                    -- 20 req18/q21
A("Blackrock Blockade", "Marshal Marris", 28.4, 49.0, 20),                                  -- 98387 req18/q21 (Forever; needed with 20 for 19 and 115)
A("WANTED: Gath'Ilzogg", "Wanted poster by the town hall", 24.5, 46.2, 20),                -- 169
A("WANTED: Lieutenant Fangore", "Wanted poster", 21.7, 46.4, 20),                           -- 180
A("WANTED: Incinerator Gar'im", "Wanted poster", 24.3, 46.2, 20),                           -- 95999 (Forever changed; spot U)
A("Blackrock Bounty", "Guard Howe", 26.4, 57.9, 20),                                        -- 128 req20
-- North: gnolls
D("A Baying of Gnolls", "10 Redridge Brutes 19.0,35.0 and 8 Mystics 23.2,28.6 (also Iron Pikes/Rivets for The Everstill Bridge)", 19.0, 35.0, 20),
D("An Unwelcome Guest", "Kill Bellygrub (boar) for his tusk", 10.6, 49.3, 21),
D("Murloc Poachers", "8 Murloc Fins on the east shore", 45.2, 59.3, 21),
T("The Everstill Bridge", "Foreman Oslow", 27.1, 48.6, 21),  A("Alther's Mill", "Foreman Oslow", 27.1, 48.6, 21), -- 98386 (Forever)
D("Alther's Mill", "12 Greater Tarantulas and 6 Tarantula Eggs at Alther's Mill", 48.3, 40.8, 21),
-- East: Blackrock orcs
D("Blackrock Menace", "10 Battleworn Axes and the Blockade items from Blackrock orcs at Render's Camp/Stonewatch area", 59.3, 53.3, 22),
T("Blackrock Menace", "Marshal Marris", 28.4, 49.0, 22),  T("Blackrock Blockade", "Marshal Marris", 28.4, 49.0, 22),
A("Tharil'zun", "Marshal Marris", 28.4, 49.0, 22),  A("Shadow Magic", "Marshal Marris", 28.4, 49.0, 22),  -- 19, 115 (need 20 + 98387)
D("Shadow Magic", "3 Midnight Orbs from Blackrock Shadowcasters", 63.1, 54.8, 23),
D("WANTED: Gath'Ilzogg", "Stonewatch Keep", 64.5, 55.8, 23),
D("Tharil'zun", "Tharil'zun's Head", 64.4, 59.4, 24),
D("Solomon's Law", "10 Shadowhide Pendants from Shadowhide gnolls east of Stonewatch", 73.7, 47.5, 24),
D("WANTED: Lieutenant Fangore", "Fangore's Paw", 75.1, 37.1, 24),
A("Missing In Action", "Corporal Keeshan (escort, in the north cave)", 23.3, 12.6, 24),   -- 219 req19/q25
D("Blackrock Bounty", "15 Blackrock Champions in the north", 24.5, 11.5, 24),
T("Missing In Action", "Marshal Marris", 28.4, 49.0, 25),
-- turn-ins 25: Tharil'zun, Shadow Magic, Blackrock Bounty, Solomon's Law, Gath'Ilzogg, Fangore, An Unwelcome Guest, Murloc Poachers, Alther's Mill
```

Notes for Redridge:
- **Verner Osgood's chain** (V): The Price of Shoes 118 goes to Smith Argus in Goldshire (Elwynn 41.7, 65.5). Return to Verner 119 comes back. Then Underbelly Scales 122 (whelps 37.5, 68.6), A Baying of Gnolls 124 and Howling in the Hills 126 (Yowler 22.6, 21.4).
  - A Baying of Gnolls needs Return to Verner (119). A Human coming from Goldshire can carry The Price of Shoes the other way first.
- **Morganth chain** (V):
  - A Watchful Eye 94 starts with Theocritus in Elwynn (65.2, 69.7, req 20).
  - Use the Glyph at the Old Lion Statue (Redridge 79.4, 46.8).
  - Looking Further 248 follows.
  - Morganth 249 (level 27): kill Morganth at about 75.0, 49.5 on the Redridge map.
- **What Comes Around... (386)**, Guard Berton 21.2, 46.6: the target is in the Stockade, so it is a dungeon quest.
- **Songblade Search (95772, Forever)**, Dorin Songblade 25.8, 46.4: it sends you into the Excavation Site: Wetlands dungeon (24-31).
- **Onyxia attunement passes through here at 48+** (V): The True Masters (4183) runs from Helendis Riverhorn (Burning Steppes) to Solomon, then 4184 to Bolvar, 4186 back to Solomon, and 4223 to Marshal Maxwell.

### 2.3 Westfall (Human 10-18) and Elwynn 20+

These IDs and positions are V. The route is short because Westfall is below 20.

```lua
FP("Sentinel Hill", "Thor", 56.5, 52.6, 10),  Home("Sentinel Hill", "Innkeeper Heather", 52.9, 53.7, 10),
A("The People's Militia", "Gryan Stoutmantle", 56.3, 47.5, 10, 1),                          -- 12 -> 13 -> 14
A("Patrolling Westfall", "Captain Danuvin", 56.4, 47.6, 10),                                -- 102
A("Red Leather Bandanas", "Scout Galiaan", 54.0, 53.0, 10),                                 -- 153
A("Testing the Wells", "Alba Fairmoon", 52.5, 53.1, 10),  A("Murloc Gills", "Alba Fairmoon", 52.5, 53.1, 10), -- 92742, 92744 Forever
A("The Killing Fields", "Farmer Saldean", 56.0, 31.2, 11),  A("Goretusk Liver Pie", "Salma Saldean", 56.4, 30.5, 11), -- 9, 22
A("Harvesting the Harvesters", "Ozwin Ironsprocket", 51.5, 32.2, 11),                       -- 92909 Forever
A("Westfall Stew", "Verna Furlbrow", 59.9, 19.4, 11),  A("Poor Old Blanchy", "Verna Furlbrow", 59.9, 19.4, 11), -- 36, 151
A("The Forgotten Heirloom", "Farmer Furlbrow", 60.0, 19.4, 11),                             -- 64
D("The People's Militia", "Defias Trappers 46.4,34.6 / Smugglers 45.8,26.4", 46.4, 34.6, 12, 1),
D("The Killing Fields", "20 Harvest Watchers", 45.6, 35.1, 12),
D("The Forgotten Heirloom", "Furlbrow's Wardrobe in the Molsen farm", 49.3, 19.3, 12),
D("Westfall Stew", "Vulture meat, Murloc eyes (coast 32.4,28.2), Goretusk snouts, Okra", 46.4, 42.5, 13),
D("Patrolling Westfall", "Gnoll Paws from Riverpaw gnolls", 48.2, 64.7, 14),
D("The People's Militia", "Pillagers 38.8,66.4 / Looters 38.6,58.0 (part 2), Highwaymen 47.5,79.0 etc. (part 3)", 38.8, 66.4, 15, 2),
A("The Coast Isn't Clear", "Captain Grayson (lighthouse)", 30.0, 86.0, 15),  A("Keeper of the Flame", "Captain Grayson", 30.0, 86.0, 15), -- 152, 103
A("The Coastal Menace", "Captain Grayson", 30.0, 86.0, 15),                                 -- 104 -> Torchlight Wand (ilvl 21) for priests
D("The Coastal Menace", "Old Murk-Eye on the south coast", 29.3, 76.0, 17),
```

- Turn-ins and the Defias Brotherhood chain: 65 → Wiley in Lakeshire, 132, 135 (Stormwind), 141, 142, 155, then 166 (Deadmines).
- After that the route continues to Redridge (2.2).
- The Forever Alba Fairmoon chain (92745 → 92753/92819) ends in the Deadmines.

### 2.4 Hillsbrad addition: City of Dalaran (Forever)

The City of Dalaran sits on the Alterac Mountains map. Its NPCs are at x 11-22, y 56-78 (V):
- Innkeeper Isirami Fairwind 12.2, 66.4
- Wand vendor Abra Cadabra 12.0, 70.2
- Mage trainer Jessa Weaver 17.6, 69.4
- Druid trainer Alfina Nightgaze 11.8, 56.4

The data shows no priest trainer there.

```lua
-- after An Alarming Request (92432, already in Hillsbrad route) is turned in to the Image of Archmage Modera (Silverpine 68.5,45.3):
On("Silverpine Forest", A("Friend of the Kirin Tor", "Image of Archmage Modera", 68.5, 45.3, 30)), -- 92459 req24/q33 V
On("Alterac Mountains", T("Friend of the Kirin Tor", "Archmage Celindra (City of Dalaran)", 14.2, 60.0, 30)),
On("Alterac Mountains", A("Past Due", "Magus Olvek (City of Dalaran)", 9.6, 62.6, 34)),    -- 96800 req30/q38 V; book is in Scarlet Monastery (dungeon)
```

### 2.5 Dustwallow Marsh (34-40, Theramore)

All V unless noted.

```lua
-- Before leaving Menethil (Wetlands map), pick up the Theramore breadcrumbs:
On("Wetlands", A("Fiora Longears", "Red Jack Flint", 10.0, 58.0, 30)),                     -- 1132 req30 (the Wetlands route takes it at 20: wrong, see diff)
On("Wetlands", A("James Hyal", "Vincent Hyal (needs 1301 from Connor Rivers, Stormwind 51.1,95.5)", 10.8, 60.4, 34)), -- 1302 req30
-- Theramore
FP("Theramore", "Baldruc", 67.5, 51.3, 34),
Home("Theramore", "Innkeeper Janene", 66.6, 45.2, 34),
T("Fiora Longears", "Fiora Longears (docks)", 66.5, 45.1, 34),
A("Highperch Venom", "Fiora Longears (wyverns are in Thousand Needles 11.8,37.1: skip unless going there)", 66.5, 45.1, 34), -- 1135
A("They Call Him Smiling Jim", "Guard Byron", 66.2, 46.1, 34),                             -- 1282
T("They Call Him Smiling Jim", "Captain Garran Vimes (top of Foothold Citadel)", 68.2, 48.6, 34),
T("James Hyal", "Clerk Lendry", 67.9, 48.2, 34),
A("Mudrock Soup and Bugs", "Morgan Stern", 66.3, 45.5, 34),                                 -- 1204 req33/q38
-- North road: Shady Rest Inn (west), Swamplight Manor
A("Suspicious Hoofprints", "Hoofprints at the Shady Rest Inn", 29.7, 47.6, 35),            -- 1284 (needs 1282 or 1302)
A("Lieutenant Paval Reethe", "Theramore Guard Badge (ground, Shady Rest)", 29.8, 48.2, 35),-- 1252
A("The Black Shield", "Black Shield (Shady Rest)", 29.6, 48.6, 35),                         -- 1253
A("Hungry!", "Mudcrush Durtfeet (friendly ogre)", 35.1, 38.3, 35),                          -- 1177 req32/q36
A("Soothing Spices", "\"Swamp Eye\" Jarl (Swamplight Manor)", 55.4, 26.3, 35),             -- 1218 (3 Soothing Spices: vendor item, buy beforehand)
A("The Orc Report", "Loose Dirt by Jarl's house", 55.4, 25.9, 35),                          -- 1219
A("Stinky's Escape", "\"Stinky\" Ignatz (escort)", 46.9, 17.5, 36),                        -- 1222
D("Stinky's Escape", "Escort Stinky to the Bogbean leaves", 48.9, 24.6, 36),
D("Hungry!", "12 Mirefin Heads from murlocs on the north coast", 58.4, 15.2, 36),
T("Soothing Spices", "\"Swamp Eye\" Jarl", 55.4, 26.3, 36),  A("Jarl Needs Eyes", "\"Swamp Eye\" Jarl", 55.4, 26.3, 36), -- 1206
D("Jarl Needs Eyes", "40 Unpopped Darkmist Eyes from Darkmist spiders", 32.3, 22.3, 37),
D("Mudrock Soup and Bugs", "8 Forked Mudrock Tongues from Mudrock tortoises", 59.4, 41.8, 37),
T("Hungry!", "Mudcrush Durtfeet", 35.1, 38.3, 37),
T("Jarl Needs Eyes", "\"Swamp Eye\" Jarl", 55.4, 26.3, 37),
-- Back to Theramore
T("The Orc Report", "Theramore Lieutenant", 66.7, 48.7, 38),  A("Captain Vimes", "Theramore Lieutenant", 66.7, 48.7, 38), -- 1220
T("Captain Vimes", "Captain Garran Vimes", 68.2, 48.6, 38),
T("Suspicious Hoofprints", "Captain Garran Vimes", 68.2, 48.6, 38),
T("Lieutenant Paval Reethe", "Captain Garran Vimes", 68.2, 48.6, 38, 1),  A("Lieutenant Paval Reethe", "Captain Garran Vimes", 68.2, 48.6, 38, 2), -- 1259
T("The Black Shield", "Captain Garran Vimes", 68.2, 48.6, 38, 1),  A("The Black Shield", "Captain Garran Vimes", 68.2, 48.6, 38, 2), -- 1319
T("The Black Shield", "Caz Twosprocket", 64.8, 50.4, 38, 2),  A("The Black Shield", "Caz Twosprocket", 64.8, 50.4, 38, 3),          -- 1320
T("The Black Shield", "Captain Garran Vimes", 68.2, 48.6, 38, 3),
T("Lieutenant Paval Reethe", "Adjutant Tesoran", 68.0, 48.1, 38, 2),  A("Daelin's Men", "Adjutant Tesoran", 68.0, 48.1, 38),        -- 1285
T("Daelin's Men", "Captain Garran Vimes", 68.2, 48.6, 38),  A("The Deserters", "Captain Garran Vimes", 68.2, 48.6, 38, 1),           -- 1286
T("Stinky's Escape", "Morgan Stern", 66.3, 45.5, 38),
T("Mudrock Soup and Bugs", "Morgan Stern", 66.3, 45.5, 38),  A("... and Bugs", "Morgan Stern", 66.3, 45.5, 38),                    -- 1258 (Silt Crawlers on the coast, spot U)
T("The Deserters", "Balos Jacken (deserters' camp, west marsh)", 36.1, 54.3, 39, 1),  A("The Deserters", "Balos Jacken", 36.1, 54.3, 39, 2), -- 1287
T("The Deserters", "Captain Garran Vimes", 68.2, 48.6, 40, 2),
```

Optional in Dustwallow:
- **The Missing Diplomat (Stormwind/Duskwood/Wetlands chain, 28-38)**, V:
  - It starts at 1241 with Bishop DeLavey and runs through 1242-1250 in Stormwind, Duskwood and Menethil.
  - 1264: Mikhail sends you to Commander Samaul 68.0, 48.7.
  - 1265: explore Sentry Point 59.9, 40.9, then go to Tervosh 66.4, 49.3.
  - 1266/1324: Private Hendel 45.2, 24.6.
  - 1267: Jaina 66.3, 49.0.
- **Nat Pagle** 58.6, 60.1: fishing quest 6607.
- **Triage** (6624), Doctor Gustaf VanHowzen 67.8, 49.0: First Aid 225, which unlocks Heavy Runecloth Bandage training.
- **Shadowshard Fragments** (7070): Maraudon.
- **Tabetha** 46.1, 57.1: mage and warlock class quests only.
- **Alcaz Prison** (Forever dungeon, 48-55): Alcaz Island at about 75, 15.

### 2.6 Badlands (38-44, Dwarf/Gnome natural, optional for Night Elf)

All V. There is no Alliance flight master in the Forever data. Ride in from Loch Modan (Thelsamar FP) through the south gate.

```lua
On("Loch Modan", A("Find Agmond", "Prospector Ironband", 65.9, 65.6, 38)),                 -- 738 req30/q38
A("Mirages", "Sigrun Ironhew (Hammertoe's Dig Site)", 53.8, 43.3, 38),                     -- 718 req35
A("A Dwarf and His Tools", "Prospector Ryedol", 53.4, 43.4, 38),                            -- 719 req35
A("Pearl Diving", "Rigglefuzz", 42.4, 52.9, 38),                                            -- 705 (Blue Pearls come from coastal clams outside the Badlands: carry, spot U) -> Flash Wand
A("Power Stones", "Rigglefuzz", 42.4, 52.9, 38),                                            -- 2418
A("Barbecued Buzzard Wings", "Rigglefuzz", 42.4, 52.9, 38),                                 -- 703 req33
A("Study of the Elements: Rock", "Lotwil Veriatus", 25.9, 44.9, 38, 1),                     -- 710 -> 711 -> 712
D("Study of the Elements: Rock", "10 Small Stone Shards from Lesser Rock Elementals", 19.2, 43.1, 38, 1),
D("Barbecued Buzzard Wings", "4 Buzzard Wings", 33.4, 60.0, 39),
D("Find Agmond", "Battered Dwarven Skeleton", 50.9, 62.4, 39),
T("Find Agmond", "Battered Dwarven Skeleton", 50.9, 62.4, 39),  A("Murdaloc", "Battered Dwarven Skeleton", 50.9, 62.4, 39), -- 739
D("Murdaloc", "Murdaloc 49.6,66.3 and 12 Stonevault Bonesnappers", 50.9, 68.8, 40),
D("Mirages", "Excavation Supply Crate", 66.6, 22.0, 40),
D("A Dwarf and His Tools", "Ryedol's Lucky Pick from Shadowforge Tunnelers", 43.2, 30.6, 40),
A("A Sign of Hope", "Crumpled Map (Hammertoe's Dig Site)", 53.0, 33.9, 40),                 -- 720
D("Power Stones", "Dentrium/An'Alleum Power Stones from Shadowforge dwarves at Angor Fortress", 48.0, 12.2, 40),
T("Mirages", "Sigrun Ironhew", 53.8, 43.3, 41),  A("Scrounging", "Sigrun Ironhew", 53.8, 43.3, 41), -- 733
T("A Dwarf and His Tools", "Prospector Ryedol", 53.4, 43.4, 41),
T("A Sign of Hope", "Prospector Ryedol", 53.4, 43.4, 41),  A("A Sign of Hope", "Prospector Ryedol (Hammertoe is inside Uldaman)", 53.4, 43.4, 41, 2), -- 721
A("Tremors of the Earth", "Garek", 61.9, 54.3, 41),                                         -- 732 req40 (needs 718)
D("Scrounging", "7 Scrap Metal from Dustbelcher ogres (south-west)", 9.9, 76.0, 41),
D("Tremors of the Earth", "Sign of the Earth from Boss Tho'grun", 12.6, 75.5, 41),
D("Study of the Elements: Rock", "3 Large Stone Slabs", 40.7, 77.7, 42, 2),
T("Study of the Elements: Rock", "Lotwil Veriatus", 25.9, 44.9, 42, 2),
-- turn in Power Stones, Buzzard Wings (Rigglefuzz), Scrounging (Sigrun), Tremors part 1 (Garek), Murdaloc -> Ironband (Loch Modan)
```

Optional in the Badlands:
- **Theldurin the Lost** 51.4, 76.9:
  - Solution to Doom 709: tablet 39.3, 18.8, then to Ironforge.
  - The Lost Fragments 692: comes after Theldurin the Lost 687, from the Arathi Myzrael chain. Enraged Rock Elementals at 54.4, 83.8.
- **Lotwil's other chain**: Coolant Heads Prevail 713 → Gyro... What? 714 → Liquid Stone 715.
- **This Is Going to Be Hard** 734/777/778: Fam'retor Guardian, 26.0, 45.8.
- **Fiery Blaze Enchantments** 706: drake heart at 81.2, 47.9.
- **Martek the Exiled** 42.2, 52.7: Indurium 1108 needs 1106 from the Shimmering Flats.

### 2.7 Swamp of Sorrows (36-40, optional)

Questie gives `requiredRaces = 0` for the Harborage (Magtoor) quests, which means both factions. On Classic these were usable by Alliance too, but **check that Magtoor is friendly in game** (U). foreverchanges lists no side for them.

```lua
A("This Light of Mine", "Father Tuttle (escort to the Harborage)", 22.0, 50.6, 36),       -- 93585 req30/q34 Alliance, Forever NEW, V
A("My Little Friends", "Amaryllis Webb", 25.1, 54.1, 36),                                   -- 93176 req25/q35 Forever NEW (both), V
A("Encroaching Wildlife", "Watcher Biggs", 26.7, 59.8, 36),                                 -- 1396 req30/q37 Alliance
D("Encroaching Wildlife", "8 Young Sawtooth Crocolisks 30.4,40.9, 10 Sorrow Spinners 28.3,45.9, 10 Swamp Jaguars 35.3,43.0", 30.4, 40.9, 37),
D("This Light of Mine", "Escort Father Tuttle to the Harborage", 26.0, 31.4, 37),
A("Draenethyst Crystals", "Magtoor (Harborage)", 26.0, 31.4, 37),                          -- 1389 (faction U)
T("Encroaching Wildlife", "Watcher Biggs", 26.7, 59.8, 37),  A("The Lost Caravan", "Watcher Biggs", 26.7, 59.8, 37), -- 1421
A("Galen's Escape", "Galen Goodward (escort, north)", 65.5, 18.2, 38),                     -- 1393
D("The Lost Caravan", "Caravan Chest in Fallow Sanctuary", 64.5, 18.3, 38),
D("Draenethyst Crystals", "6 Draenethyst Crystals around Fallow Sanctuary", 62.1, 22.9, 38),
D("Galen's Escape", "Escort Galen, then open Galen's Strongbox", 47.8, 39.8, 38),
T("The Lost Caravan", "Watcher Biggs", 26.7, 59.8, 39),  A("Driftwood", "Watcher Biggs", 26.7, 59.8, 39), -- 1398
D("Driftwood", "8 Sundried Driftwood on the east coast", 90.3, 54.6, 40),
T("Driftwood", "Watcher Biggs", 26.7, 59.8, 40),  A("Deliver the Shipment", "Watcher Biggs (to Nethergarde)", 26.7, 59.8, 40), -- 1425 -> Blasted Lands 66.5,21.4
```

Other Swamp of Sorrows quests:
- **Forever "New" with no giver in the data** (W/U):
  - Blood of My Blood 93429 (Lost Ones in Fallow Sanctuary)
  - Taking the Bait Back 93430 (Pelluk's lure)
  - The Visiting Mage 93464
  - Deliver the Second Shipment 94929 (Alliance, 38, W only)
- **Item-started**: Noboru the Cudgel (1392) drops from Noboru (item 6196) and is handed to Magtoor.
- **Cortello's Riddle** (624, item 4056, from a Stranglethorn drop): its scroll is at 22.9, 48.2. It continues to Dustwallow and the Hinterlands and rewards the Explorer's Knapsack (bag).

### 2.8 Searing Gorge (45-50, optional)

All V.

```lua
FP("Thorium Point", "Lanie Reed", 37.9, 30.9, 45),
A("WANTED: Overseer Maltorius", "Wanted/Missing/Lost & Found board", 37.6, 26.5, 45),     -- 7701
A("STOLEN: Smithing Tuyere and Lookout's Spyglass", "same board", 37.6, 26.5, 45),         -- 7728
A("JOB OPPORTUNITY: Culling the Competition", "same board", 37.6, 26.5, 45),               -- 7729
A("What the Flux?", "Master Smith Burninate", 38.8, 28.5, 45),                              -- 7722
A("Curse These Fat Fingers", "Hansel Heavyhands", 38.6, 27.8, 45),                          -- 7723
A("Fiery Menace!", "Hansel Heavyhands", 38.6, 27.8, 45),                                    -- 7724
A("Incendosaurs? Whateverosaur is More Like It", "Hansel Heavyhands", 38.6, 27.8, 45),     -- 7727
A("Divine Retribution", "Kalaran Windblade", 39.1, 39.0, 45),                               -- 3441 -> 3442 ... (long chain, Thorium Plated Daggers need Blacksmithing: optional)
A("Prayer to Elune", "Zamael Lunthistle (cave)", 29.6, 26.3, 46),                           -- 3377 -> 3378 to Astarii Starseeker, Darnassus 38.3,81.0 (Night Elf flavour)
A("Suntara Stones", "Dorius Stonetender (escort)", 63.9, 61.0, 46),                         -- 3367 -> Singed Letter 74.5,19.3 -> 3368 Ironforge
A("Caught!", "Wooden Outhouse", 65.6, 62.2, 46),                                            -- 4449 (8 Dark Iron Geologists + 15 Silk Cloth)
A("Shadoweaver", "Nilith Lokrav", 41.0, 75.0, 46),                                          -- 3379 -> 3385 -> 3402 (Gadgetzan)
D("Curse These Fat Fingers", "20 Heavy War Golems", 40.5, 45.9, 46),
D("JOB OPPORTUNITY: Culling the Competition", "15 Taskmasters + 15 Slavers in the Cauldron", 42.7, 39.6, 47),
D("STOLEN: Smithing Tuyere and Lookout's Spyglass", "Tuyere from Dark Iron Steamsmiths 40.0,49.6, Spyglass from Lookouts 42.7,58.6", 40.0, 49.6, 47),
D("What the Flux?", "Secret Plans: Fiery Flux in the Slag Pit", 40.5, 35.7, 47),
D("WANTED: Overseer Maltorius", "Slag Pit", 40.8, 35.9, 48),
D("Incendosaurs? Whateverosaur is More Like It", "20 Incendosaurs in the Slag Pit lava", 49.5, 26.5, 48),
D("Fiery Menace!", "20 Greater Lava Spiders", 28.6, 61.9, 48),
D("Caught!", "8 Dark Iron Geologists", 63.8, 59.4, 48),
D("Shadoweaver", "5 Shadowsilk Poachers", 59.6, 25.3, 49),
-- turn-ins at Thorium Point; Caught! -> Ledger from Tanaris (4450, Krinkle Goodsteel, Gadgetzan 51.5,28.8) rewards the Charged Lightning Rod wand (ilvl 46)
```

### 2.9 Azshara (46-52, optional; the priest class chain at 50)

All V.

```lua
FP("Talrendis Point", "Jarrodenus", 11.9, 77.6, 46),
A("Spiritual Unrest", "Loh'atu", 11.4, 78.2, 46),                                           -- 5535
A("A Land Filled with Hatred", "Loh'atu", 11.4, 78.2, 46),                                  -- 5536
D("Spiritual Unrest", "6 Highborne Apparitions + 6 Lichlings", 16.6, 70.7, 46),
D("A Land Filled with Hatred", "Haldarr satyrs", 20.4, 61.8, 47),
T("Spiritual Unrest", "Loh'atu", 11.4, 78.2, 47),  T("A Land Filled with Hatred", "Loh'atu", 11.4, 78.2, 47),
A("Kim'jael Indeed!", "Kim'jael", 53.5, 21.8, 48),                                          -- 3601 -> 5534
D("Kim'jael Indeed!", "Kim'jael's Equipment boxes in the Thalassian Base Camp", 58.2, 28.4, 48),
T("Kim'jael Indeed!", "Kim'jael", 53.5, 21.8, 49),  A("Kim'jael's \"Missing\" Equipment", "Kim'jael", 53.5, 21.8, 49),
D("Kim'jael's \"Missing\" Equipment", "Some Rune from Spitelash naga at Ruins of Eldarath", 46.7, 55.8, 50),
-- Priest only (class filter Priest), start in a capital:
On("Ironforge", A("Cenarion Aid", "High Priest Rohan (or Brother Joshua, Stormwind 49.5,45.2)", 24.7, 8.2, 50)), -- 8254 req50/q52 class=Priest
T("Cenarion Aid", "Ogtinc (cliff top NE of Ruins of Eldarath)", 42.4, 42.6, 50),  A("Of Coursers We Know", "Ogtinc", 42.4, 42.6, 50), -- 8255
D("Of Coursers We Know", "4 Healthy Courser Glands from Mosshoof Coursers", 52.8, 67.8, 50),
T("Of Coursers We Know", "Ogtinc", 42.4, 42.6, 51),  A("The Ichor of Undeath", "Ogtinc (Ichor drops in Western Plaguelands / Scholomance area undead, U)", 42.4, 42.6, 51), -- 8256
-- 8257 Blood of Morphaz: kill Morphaz in Sunken Temple, hand in to Greta Mosshoof (Felwood 51.2,82.1) -> Woestave (wand, ilvl 52)
```

Other Azshara quests:
- **Arcane Runes** (3449, from Tymor in Ironforge after Passing the Burden 3448). The runes are at:
  - Beth'Amara 36.9, 53.2
  - Jin'yael 39.6, 50.2
  - Markri 39.4, 55.5
  - Sael'hai 42.4, 64.2

  Then signal Pilot Xiggs at 77.8, 91.4 and return to Tymor (3461).
- **Loramus chain** (3141 → 3508-3511 → 3602 → 3621): it starts from the Fallen Hero chain (Swamp/Blasted Lands, 2744). Hetaera is at 56.7, 44.8 and the Azsharite at 54.9, 84.0. It ends in the 60-level Razelikh fight.
- **Hydraxian Waterlords** (Duke Hydraxis 79.3, 73.7): the Molten Core attunement path starts at 55 (6804, 6805).

### 2.10 Thousand Needles / Shimmering Flats (28-35, optional)

All V.
- Reach it from Thalanaar (Feralas FP 89.5, 45.9) going east, or from Tanaris going north.
- For an Alliance player coming from the north it is out of the way. Do it only as a detour when a Feralas or Tanaris trip is planned.

```lua
On("Ironforge", A("The Brassbolts Brothers", "Pilot Longbeard", 72.7, 94.0, 28)),          -- 1179 req28
T("The Brassbolts Brothers", "Wizzle Brassbolts", 78.1, 77.1, 30),
A("Hardened Shells", "Wizzle Brassbolts", 78.1, 77.1, 30),                                  -- 1105
A("Salt Flat Venom", "Fizzle Brassbolts", 78.1, 77.1, 30),                                  -- 1104
A("Rocket Car Parts", "Kravel Koalbeard", 77.8, 77.3, 30),                                  -- 1110
A("Hemet Nesingwary", "Kravel Koalbeard (crate to Nesingwary, STV 35.7,10.8)", 77.8, 77.3, 30), -- 5762
A("A Bump in the Road", "Trackmaster Zherin", 81.6, 78.0, 30),                              -- 1175
A("Load Lightening", "Pozzik", 80.2, 75.9, 30),                                             -- 1176
D("Rocket Car Parts", "30 Rocket Car Parts lying on the flats", 77.3, 68.7, 30),
D("Salt Flat Venom", "Scorpids", 76.1, 67.9, 31),
D("Hardened Shells", "Sparkleshell tortoises", 81.5, 61.1, 31),
D("Load Lightening", "Vultures", 80.0, 69.8, 31),
D("A Bump in the Road", "Saltstone basilisks 75.4,59.5 / 79.3,76.2 / 77.8,88.4", 79.3, 76.2, 32),
-- turn-ins; then Martek the Exiled (1106 -> Badlands), Encrusted Tail Fins (1107), Goblin Sponsorship (1178...) as wanted
```

- Highperch Venom (1135, from Theramore): wyverns at Highperch, 11.8, 37.1.
- Pristine Pesterhide Pelts (98155, Forever): from Kristy Grant, Thalanaar 89.4, 46.0.

### 2.11 Alterac Mountains (30-40, done from Southshore)

All V. The quests are given and handed in at Southshore (Hillsbrad map).

```lua
On("Hillsbrad Foothills", A("Crushridge Bounty", "Marshal Redpath", 49.5, 58.7, 31)),        -- 500 req30
On("Hillsbrad Foothills", A("Syndicate Assassins", "Magistrate Henry Maleb", 48.1, 59.1, 31)), -- 505 req26
D("Syndicate Assassins", "12 Syndicate Footpads + 8 Thieves", 57.7, 68.0, 31),
A("Foreboding Plans", "Syndicate Documents (Strahnbrad)", 58.3, 67.9, 32),                  -- 510 (and Encrypted Letter 511 from the same documents)
A("Encrypted Letter", "Syndicate Documents", 58.3, 67.9, 32),
D("Crushridge Bounty", "9 Dirty Knucklebones from Crushridge ogres", 45.6, 48.0, 33),
On("Hillsbrad Foothills", T("Crushridge Bounty", "Marshal Redpath", 49.5, 58.7, 34)),
On("Hillsbrad Foothills", A("Crushridge Warmongers", "Marshal Redpath", 49.5, 58.7, 34)),  -- 504 -> Burning Sliver (wand, ilvl 40)
On("Hillsbrad Foothills", T("Foreboding Plans", "Magistrate Henry Maleb", 48.1, 59.1, 34)),
On("Hillsbrad Foothills", A("Noble Deaths", "Magistrate Henry Maleb", 48.1, 59.1, 34)),     -- 512
On("Hillsbrad Foothills", T("Encrypted Letter", "Loremaster Dibbs", 50.6, 57.1, 34)),
D("Noble Deaths", "7 Alterac Signet Rings from Syndicate at Lordamere internment / Ruins of Alterac", 55.7, 27.8, 37),
D("Crushridge Warmongers", "15 Crushridge Warmongers", 36.3, 53.8, 38),
-- Letter to Stormpike (514) -> Ironforge; Further Mysteries (525) -> Dark Council 537 (Argus Shadow Mages 58.7,40.6; Nagaz 39.2,14.3)
-- Assassin's Contract 522 (item 3668 from a Shadowy Assassin) -> Baron's Demise 523 (Baron Vardus 56.3,26.7)
```

### 2.12 Blasted Lands (45-55)

All V. Nethergarde Keep is the hub: flight master Alexandra Constantine 65.5, 24.3, food Bernie Heisten 63.5, 17.0.

```lua
FP("Nethergarde Keep", "Alexandra Constantine", 65.5, 24.3, 47),
T("Deliver the Shipment", "Quartermaster Lungertz", 66.5, 21.4, 47),                        -- 1425 from the Swamp
-- Buff quests (repeatable once the first is done). Givers at the Dreadmaul road camp:
A("Snickerfang Jowls", "Bloodmage Drazial", 50.5, 14.2, 47),                                -- 2581 -> 2582 repeat
A("A Boar's Vitality", "Bloodmage Drazial", 50.5, 14.2, 47),                                -- 2583 -> 2584
A("The Decisive Striker", "Bloodmage Drazial", 50.5, 14.2, 47),                             -- 2585 -> 2586
A("The Basilisk's Bite", "Bloodmage Lynnore", 50.6, 14.3, 47),                              -- 2601 -> 2602 (Infallible Mind: Int buff, best for a priest)
A("Vulture's Vigor", "Bloodmage Lynnore", 50.6, 14.3, 47),                                  -- 2603 -> 2604 (Spiritual Domination: Spirit/Stamina)
A("To Serve Kum'isha", "Kum'isha the Collector", 52.0, 35.6, 47),                           -- 2521 (rare Flawless Draenethyst Sphere)
A("Everything Counts In Large Amounts", "Kum'isha the Collector", 52.0, 35.6, 47),          -- 3501 -> 3502 repeat
D("Snickerfang Jowls", "Jowls 48.6,35.6, Boar Lungs 51.4,38.4, Scorpok Pincers 48.6,23.8, Basilisk Brains 48.5,29.1, Vulture Gizzards 56.2,36.1", 48.6, 35.6, 48),
-- turn in at 50.5,14.2 / 50.6,14.3; Kum'isha takes Imperfect Draenethyst Fragments from any Dreadmaul
```

Other Blasted Lands chains:
- **Petty Squabbles** (2783, from Ambassador Ardalan 67.6, 19.3, req 50) leads to the Fallen Hero of the Horde (Swamp 34.3, 66.1), then A Tale of Sorrow 2801, The Stones That Bind Us 2681 and so on.
- **Thadius Grimshade** (Hinterlands Altar of Zul chain, 2990-2993) is at 66.9, 19.5.
- **Ragnar Thunderbrew** (4128) starts at Enohar Thunderbrew 63.6, 20.6 and goes to Kharanos.

### 2.13 Wetlands additions (Forever Excavation Site, 24-31)

These belong to the Excavation Site: Wetlands dungeon (26-33). They are not routed today.

All V:
- Seeking Caitlin 95737: Llana, Astranaar 35.0, 48.5 → Caitlin Grassman, Menethil 11.9, 58.8.
- Lost in the Thicket Things 95647 and Heartwoven 95809: Caitlin Grassman.
- Highland Hides 98815: James Halloran, Menethil 8.6, 55.7.
- Horrors in the Highland 95646: Rethiel the Greenwarden 56.4, 40.4.
- Prehistoric Prism 98824: Prospector Whelgar 38.8, 52.4 → High Explorer Magellas, Ironforge 69.9, 18.6.
- Lost Relic Carry 95810: item 270865.
- Songblade Search / Fallen in the Fen 95772/95795: Dorin Songblade, Redridge 25.8, 46.4.

Use them as dungeon-optional `G` notes.

### 2.14 Riverglades (Forever, 36-47)

Facts from the Forever data (V):
- Flight master Gretchen Mayberry at Farholde Keep, 60.6, 81.4.
- Farholde vendors:
  - Martha Wellsworth 64.2, 84.0
  - Cassandra Wheeler (food and drink) 64.6, 82.8
  - Marla Bell (reagents) 62.2, 86.0
  - Alphonse Dumas (blacksmith) 64.4, 82.0
- Powderfuse Port (goblin, neutral) NPCs:
  - Grizzek 76.6, 53.2
  - Gilliwigs and Krix 79.2, 54.6
  - Melbin Powderfuse 77.6, 50.8
- The wiki lists an inn at Farholde, but the innkeeper's name and position are not in the data (U).

Facts from the web (W):
- Alliance hub: Farholde Keep, the Brotherhood of the Horse.
- Horde hub: Rog'mar, about 59.6, 45.1.
- Enemy areas:
  - Sunnyglade (centre-west, Twilight's Hammer)
  - Twilight's Shroud (west)
  - Bolder'ok (ogres, north)
  - Krol'dok Stronghold, a dungeon whose entrance is about 37.5, 37.5 per our `Dungeons/Data.lua`
- Ways in:
  - The Redridge fork toward the Burning Steppes
  - The Badlands, north of Twilight's Shroud
  - Swimming north from the Swamp of Sorrows
  - The ship from Tanaris

**Alliance and neutral quests** (ID, level, tags) from foreverchanges.pro/quests/riverglades. Givers and coordinates are U for every quest below. Brotherhood of the Horse reputation is 100 per quest (W, quest 94999).

| Lvl | Quests |
|---|---|
| 36 | Eyes for the Watchman 94999 (Eleanor's ranch → Watcher Fredericks, Southern Watch), Frazzlespark's Crate 95059 |
| 37 | Love Thy Neighbor 95330, Southern Watch Gnoll Report 95148, Stuff 'Em and Stick 'Em 95156, The Lost Scout 95147 |
| 38 | A Feast for Buzzards 95983, Apple of My Eye 95561, Bats in the Belfry 95603, Coyote Huntin' 94617, Curious Trinkets 94881, Drink Up! 95957, Fit for a Princess 95913, Foal Play 94615, Foreman's Plight 95943, Freshwater Fiends 94614, From Seed to Sprout 94843, Gaseous Gold 96063 (n), Gnoll Infestation 94678, Goes Down Smooth 95988, Hats Off 94923, High Stakes 96009, In Memoriam 95615, Keeping the Light On 95613, My Kingdom for a Horse 94613, Not My Circus 95982 (n), Out in the Field 95329, Rescue Roundup 94992, Stepped Out 95961, Stolen Saws 94931, The Sharpest of Blades 95184, Unsavory Plant Food 94842, Wheeler's Fleeing Steeds 94618 |
| 39 | A Few Furs for Friz 94928, A Fur Trade 94925, Helping Hands 94861, Hunting the Hunters 94924, If a Tree Falls, and No One Hears... 94857, Preventative Measures 95064, Rog'mar Supplies 95426, Song of the Strider 95984, The Big Payback 95326 (n), The Rog'mar Situation 95066 |
| 40 | A Taste of the Sea 95121 (n), Abominable Magics 95642, All That's Left 94858, All's Well That Ends Well 95327 (n), Biting the Hand 94961/94963 (n), Clerical Quarantine 96083, Coming to Collect 95312 (n), Consolation Prize 95472 (n), Doctor's Orderly 96082, Field Marshal's Log 94885, Get the Goods 95322 (n), I Know a Guy 95295 (n), Indiscriminate Purge 95643, Rock 'em and Sock 'em 96067 (n), Saving Sunnyglade 94877, Scraps of Knowledge 94879, Shipping and Handling 95296/95383 (n), Snargl's Snout 94679 (ELITE), Something's in the Water 96084, Tazzik's Dues 95321 (n), We've Been Robbed! 95325 (n), What We Lost 94829, Wound Dressings 96081 |
| 41 | An Unsettling Discovery 94884, Cut Off the Heads 95562 (ELITE), From Port to Port 95219, Her World 95975, King of the Wild Plains 95986 (ELITE), Saltwater Savages 95118 (n) |
| 42 | Clear 'em Out 95792 (n), It Takes Guts 95261 (n), Proof of Profit 95934 (n), Smuggler's Bargain 95294 (n), Smuggler's Special 95293 (n), Terrors From the Deep 95260 (n), The Monster Surfaces 95267 (n), Upstream Contamination 96085 (ELITE), WANTED: Blademaster Kaijo 95912 (ELITE), WANTED: Ghostmaw 95991 (ELITE), WANTED: Old Rot-Chum 95120 (n, ELITE), WANTED: Trapclaw 95254 (n) |
| 43 | A Miner Problem 96015, Hail the Dragonslayer 95935 (ELITE), In Need of Relief 96125, Smuggler's Paradise 95288 (n), Unfriendly Competition 95119 (n) |
| 44 | A Blast Ye Scurvy Dogs! 95123 (n), A Small Favor 94907, An Ogre's Captive 96126, Carving a Path 94889, Dunston Checks Out 94927, No Soldier Left Behind 94888, See Ya, Scallywags! 95165 (n), The Western Front 94886, Unchecked Expansion 95122 (n) |
| 45 | Admiral Lamora 95124 (n), Drop the Hammer 94926 (ELITE), The Twilight Threat 94894 |
| 46 | Bring Me His Head 94890 (ELITE), News to Farholde 94891 |
| 47 | Delivering Closure 94893, Dying Wish 94892, Saving Marshal Ryan 94887 |

(n) = neutral, mostly Powderfuse Port goblin quests.

**Suggested shape until the givers are known** (U):
1. Arrive at 37-38 (the earliest Alliance quests are 36).
2. Take the Farholde FP and pick up the ranch/Southern Watch quests (36-37).
3. Do the Brotherhood horse-ranch block (38).
4. Do the Sunnyglade/Clerical Quarantine block (40).
5. Do the Powderfuse Port neutral smuggler line (40-44).
6. Do The Western Front / Marshal Ryan arc (44-47).
7. Run Krol'dok at 42-44.

A Riverglades route should be built from an in-game Questie Forever export or wowhead/forever NPC pages once they carry coordinates.

Also listed under Riverglades on foreverchanges, but not in Riverglades: Remember That I Love You 95161 (Duskwood/Stormwind orphan line, level 22, item-started 92415). See 3.4.

### 2.15 Shen'dralas / Valley of Bones (Forever, Desolace 38-45)

All V. Coordinates are on the Shen'dralas map unless Desolace is named.

**Gelkis side**
- Valley of Bones 93034: Uthek the Wise, Desolace 36.2, 79.2 → Nerlokh 21.2, 23.2.
- Then, all with Nerlokh:
  - Ravaging Ravagers 93035
  - Outing Outcasts 93037
  - Facing the Truth 93041
  - Saving Our Own 93058
  - Bone Burying 93062
  - Checking Things Out 93122
  - Going Home 93125
  - Khan Jehn 93128 (ends with Uthek)

**Magram side**
- Valley of Bones 92841: Warug, Desolace 75.0, 68.2 → Orgrul 35.7, 12.5.
- Then, with Orgrul:
  - Mountain of Bones 92844
  - Outcast Necromancers 92846
  - Corrupting Tears, Proof of Concept, No Mercy for the Weak, Bone Raising
- Bristleback Retreat 93066 and Long-Term Solutions / Threat of Starvation: Hagiak 58.8, 53.8.

Every quest needs standing with that clan, and the existing Desolace route already does the Gelkis line (Buying Friendship: Gelkis 93227). The route should pick one side only, and only if Desolace runs past 38.

---

## 3. Side steps worth adding

### 3.1 Priest training (where, and what matters)

**Trainers** (V coordinates):
- Darnassus, Temple of the Moon:
  - Priestess Alathea 39.5, 81.2
  - Astarii Starseeker 38.3, 81.0
  - Jandria 37.9, 82.7
  - Lariia 40.4, 88.7
- Stormwind Cathedral:
  - High Priestess Laurena 49.5, 44.6
  - Brother Joshua 49.5, 45.2
  - Brother Benjamin 52.3, 47.6
  - Nara Meideros 35.7, 63.2
- Ironforge, Mystic Ward:
  - High Priest Rohan 24.7, 8.2
  - Theodrus Frostbeard 24.1, 8.4
  - Braenna Flintcrag 24.4, 9.2
  - Toldren Deepiron 25.2, 10.8
  - High Priestess Mims (Gnome) 24.8, 10.0

**When to train.** New ranks come at every even level. The steps worth putting in the route, with the Vanilla table spell IDs that the `Train` helper can watch (from the WhatsTraining Vanilla priest table, which Forever is assumed to follow; U for Forever changes):

| Level | Spells (IDs) | Notes |
|---|---|---|
| 20 | Flash Heal 2061, Holy Fire 14914, Mind Soothe 453, Shackle Undead 9484, Renew r3 6075, Heal 2054 at 16 / 2055 at 22 | Night Elf: Elune's Grace by quest, 5672 (V, Priestess Alathea, Darnassus 39.5, 81.2, req 20, Night Elf only). Train at Darnassus right after Darkshore. |
| 18-58 | Starshards ranks 19296 (18), 19299 (26), 19302 (34), 19303 (42), 19304 (50), 19305 (58) | Night Elf racial; rank 1 comes from Stars of Elune 5627 at 10. |
| 24 | Mana Burn 8129, PW:Fortitude r3 1245 | |
| 30 | Prayer of Healing 596, Mind Control 605, Shadow Protection 976, Mind Blast r5 8105 at 34 | |
| 32 | Abolish Disease 552 | |
| 34 | Levitate 1706 | |
| 40 | Greater Heal 2060 | The biggest single upgrade. Plan a capital visit at 40. |
| 48, 60 | PW:Fortitude 10937 (48), 10938 (60) | |

Practical trip plan for a Night Elf:
- **20**: Darnassus, coming off Darkshore.
- **22-30**: Ironforge, from Menethil or Southshore by flight (Gryth Thurden 55.5, 47.7).
- **30-50**: Stormwind or Ironforge. Theramore has no priest trainer in the data, only Paladin and Warrior trainers.
- **Above 50**: Stormwind or Ironforge between Burning Steppes/Plaguelands trips.

### 3.2 Wands (the priest's main early damage)

**Vendors** (V):
- Ardwyn Cailen, Stormwind 52.9, 74.8
- Harick Boulderdrum, Ironforge 23.1, 15.9
- Abra Cadabra, City of Dalaran (Alterac map 12.0, 70.2), Forever

Vendor wands:

| Item | Name | Required level |
|---|---|---|
| 5208 | Smoldering Wand | 15 |
| 5209 | Gloom Wand | 16 |
| 5210 | Burning Wand | 20 |
| 5211 | Dusk Wand | 20 |
| 5236 | Combustible Wand | 29 |
| 5347 | Pestilent Wand | 30 |
| 5238 | Pitchwood Wand | 40 |
| 5239 | Blackbone Wand | 41 |

- **AH-buy-for-later**: the enchanter wands Greater Magic Wand 11288 (about level 13) and Greater Mystic Wand 11290 (level 30) are cheap and good.
- Darnassus has no wand vendor in the data.

**Quest reward wands on or near the route.** Each is one of several reward choices; the item-to-quest link is V from the Forever item data (questRewards).

| Wand (ilvl) | Quest (ID, quest level) | Where | In our routes? |
|---|---|---|---|
| Torchlight Wand (21) | The Coastal Menace (104, 20) | Westfall | no (Human route) |
| Sable Wand (22) | Underground Assault (2040, 20) | Dun Morogh / Gnomeregan | no |
| Sizzle Stick (23) | Deviate Eradication (1487, 21) | Wailing Caverns | no |
| Spellcrafter Wand (26) | Retrieval for Mauren (1078, 26) | Stormwind / Stonetalon | no |
| Gravestone Scepter (29) | Blackfathom Villainy (1200, 27) | BFD | no |
| Excavation Rod (30) | Ormer's Revenge (296, 29) | Wetlands | yes |
| Consecrated Wand (30) | Worgen in the Woods (223, 31) | Duskwood | yes |
| **Moonbeam Wand (30)** | Answered Questions (1044, 30) | Night Elf chain: The Howling Vale (Ashenvale) → Velinde Starsong 1037 → Velinde's Effects 1038 (Darnassus) → The Barrens Port 1039 → Passage to Booty Bay 1040 → The Caravan Road 1041 → The Carevin Family 1042 → The Scythe of Elune 1043 (Duskwood) → back to Thyn'tel Bladeweaver, Darnassus 61.8, 39.2 | no: **recommended addition** |
| Captain Rackmore's Tiller (36) | Claim Rackmore's Treasure! (6161, 36) | Desolace | yes |
| Flash Wand (37) | Pearl Diving (705, 37) | Badlands | no |
| Kodo Brander (38) | Gizelton Caravan (5943, 38) | Desolace | yes |
| Fizzle's Zippy Lighter (38) | News for Fizzle (1137, 38) | Badlands / Thousand Needles | no |
| Rod of Sorrow (39) | WANTED: Otto and Falconcrest (685, 40, ELITE) | Arathi | yes |
| Gnomish Zapper (40) | Sunken Treasure (666, 40) | Arathi | yes |
| Burning Sliver (40) | Crushridge Warmongers (504, 40) | Alterac | no |
| Goblin Igniter (40) | Venture Company Mining (600, 41) | Stranglethorn | yes |
| Charged Lightning Rod (46) | Ledger from Tanaris (4450, 46) | Searing Gorge → Gadgetzan | no |
| Cairnstone Sliver (50) | The Morrow Stone (2942, 50) | Uldaman | no |
| Woestave (52) | Blood of Morphaz (8257, 52, Priest) | Azshara → ST | no |
| Smokey's Fireshooter (60) | When Smokey Sings, I Get Violent (6041, 58) | EPL | yes |
| Stormrager (62) | Order Must Be Restored (6187, 60) | Stormwind → EPL | no |
| Wand of Biting Cold (63) | Korrak / Hero of the Stormpike | Alterac Valley | no |

### 3.3 Bags, food and water

**Quest-reward bags** (V):
- Gunnysack of the Night Watch (1729), from The Night Watch 58 in Duskwood. Already routed.
- Ooze-covered Bag (3352), from Digging Through the Ooze 470 in Wetlands. Check whether it is routed.
- Thawpelt Sack (9587), from The Platinum Discs 2439 (Uldaman → Ironforge).
- Explorer's Knapsack (11324), from Cortello's Riddle 626 (Swamp → Dustwallow → Hinterlands).
- Demon Hide Sack (10959), from You Are Rakh'likh, Demon 3628 (60).

**Bag vendors** (V):
- Yldan, Darnassus 65.3, 53.0
- Alyssa Griffith, Stormwind 71.7, 62.2
- Pithwick, Ironforge 38.0, 74.7

Buy cheap 10-slot bags, or **AH-buy-for-later** Linen/Woolen 6-8 slot bags in the 20s and Mageweave 12-slot bags in the 30s.

**Water for a mana class.** Food/drink vendors at the new hubs (V):
- Bernie Heisten, Nethergarde 63.5, 17.0
- Cassandra Wheeler, Farholde 64.6, 82.8
- Riznek (drink), Shimmering Flats 80.5, 76.5
- Bartender Wental, Lakeshire 21.6, 43.9
- Innkeepers sell water too.

Suggested water tiers:
- 25: Melon Juice
- 35: Sweet Nectar
- 45: Moonberry Juice
- 55: Morning Glory Dew

The tier levels are from Classic and U for Forever. A `G` note at each new hub is enough.

### 3.4 Items to keep for later quests (quest-starting drops)

All V. Item → quest ID [required level]. Use `Item(itemID, 1, name, ...)` collect steps where the drop is reliable.

- 2794 An Old History Book → 337 [20], Duskwood undead. Ends in the Stormwind library.
- 4433 Waterlogged Envelope → 637 Sully Balloo's Letter [25]. Hillsbrad/Arathi chain.
- 4614 Pendant of Myzrael → 635 Crystal in the Mountains [30]. Rare world drop. Arathi.
- 3668 Assassin's Contract → 522 [30], from the Shadowy Assassin in Alterac.
- 6196 Noboru's Cudgel → 1392 [29], Swamp.
- 9326 Grime-Encrusted Ring → 2945 [28], Dark Iron Agent in Gnomeregan.
- 4056 Cortello's Riddle → 624 [35]. Bag reward.
- 8623 / 8704 / 8705 OOX Distress Beacons → 351 (Tanaris) / 485 (Hinterlands) / 2766 (Feralas) [40-43]. All three are needed for the Gnome mechanical chicken pet chain. Already in the routes as item starts.
- 9250 Ship Schedule → 2876 [40], Tanaris pirates.
- 11463 Undelivered Parcel → 4281 Thalanaar Delivery [40].
- 11818 Grimesilt Outhouse Key → 4451 [43], Searing Gorge.
- 10000 Margol's Horn → 3181 [40], Searing Gorge.
- 11116 A Mangled Journal → 3884 Williden's Journal [48], Un'Goro devilsaurs.
- 11668 Flute of Xavaric → 939 [49], Felwood.
- 13140 Blood Red Key → 5202 A Strange Red Key [49], Felwood.
- 12771 Empty Firewater Flask → 5083 [52], Winterspring.
- 12842 Crudely-written Log → 5123 The Final Piece [52], High Chief Winterfall.
- 20741 / 20742 Deadwood / Winterfall Ritual Totems → 8470 / 8471 (Timbermaw reputation).
- 18950 Chambermaid Pillaclencher's Pillow → 7704 [45], BRD.
- Forever:
  - Ira's Dagger 96137 (item 281143) and Merrick's Bow 96138 (281142), Duskwood [18].
  - Remember That I Love You 92415 (items 251270/251520) [15], which leads to Orphan Matron Nightingale (Stormwind 56.3, 54.0) and then 95161 to Avette Fellwood (Duskwood 73.0, 44.4).
  - Lost Relic Carry 95810 (item 270865), Excavation Site.

Also worth keeping: **Silk Cloth ×15** for Caught! (4449, Searing Gorge), and **3 Soothing Spices** for Jarl (1218; vendor item, U which vendor).

### 3.5 Class quests for priests in 20-60

All V.
- **10**: Stars of Elune (5627, Night Elf, Starshards) and the Returning Home variants 5628-5633. Human: Divine Grace (94773-94779, Forever).
- **20**: Elune's Grace (5672-5675, Night Elf). Arcane Feedback (5676-5678, Human). A Lack of Fear (5641/5645/5647, Dwarf). Contingency Plan (94818-94820, Gnome, Forever; giver data incomplete).
  - Add one `A` + `T` pair at Priestess Alathea, Darnassus 39.5, 81.2, filtered to Night Elf priests, right after the 20 training step.
- **50-52**: Cenarion Aid → Of Coursers We Know → The Ichor of Undeath → Blood of Morphaz (8254-8257). Woestave wand.
- **54+**: Holy Bologna (7504, Dire Maul book).
- **60**: Eris Havenfire: A Warning 7621 / The Balance of Light and Shadow 7622 (Benediction staff).
- **60**: Al'tabim's Eye of Zuldazar (8049-8052, ZG).
- **58-60**: Devout set upgrades with Deliana (Ironforge 43.5, 52.6).

### 3.6 Reputation and attunement steps that matter for leveling

**Leveling access**
- **Timbermaw Hold (Felwood/Winterspring)**: you must not be Hostile to walk the tunnel to Winterspring. Kill Deadwood furbolgs and turn in the Deadwood/Winterfall ritual totems and Feathers.
- **Brotherhood of the Horse (Riverglades, Forever)**: 100 reputation per quest (W). Rewards unknown (U).
- **Gelkis or Magram (Desolace/Shen'dralas, Forever)**: the reputation gates the whole Valley of Bones line. Choose one.
- **Darnassus**: reputation for the Night Elf mount. The mount level on Forever is "unconfirmed 40" per wow4ever (W).
- **Argent Dawn**: Argent Dawn Commission and Scourgestones in the Plaguelands (already routed).
- **Cenarion Circle**: Silithus (routed).

**Attunements on the way**
- **Onyxia (Alliance)**: Dragonkin Menace 4182 (Helendis Riverhorn, Burning Steppes 85.8, 69.0, req 48) → The True Masters 4183 (Lakeshire) → 4184 (Bolvar) → 4185 → 4186 (Lakeshire) → 4223 (Marshal Maxwell, Burning Steppes 84.7, 69.0), and on to UBRS. Cheap at 50-55 while the route is in the Burning Steppes.
- **Molten Core**: Attunement to the Core (7848), Lothos Riftwaker, Blackrock Mountain (Searing Gorge map 32.1, 94.7), req 55.
- **Hydraxian Waterlords**: Duke Hydraxis, Azshara 79.3, 73.7 (6804/6805 at 55+).
- **Uldaman entry chain** (Badlands Hammertoe 721/722) and **The Platinum Discs** (bag) if Uldaman is run.

---

## 4. Diff list against the current `LevelGuide/Routes.lua`

Every `A`/`T` step in the 20-60 routes was checked by script against the Forever data. Of 400+ such steps, 64 drew a remark; the real issues are below, most important first.

### 4.1 Wrong data in the current routes

1. **Arathi: quest titles are wrong** (Routes.lua 1320, 1321, 1375, 1376).
   - The route uses "Wanted! Marez Cowl" and "Wanted! Otto and Falconcrest".
   - The Forever titles are **"WANTED: Marez Cowl" (684)** and **"WANTED: Otto and Falconcrest" (685)**. Both are tagged changed by Forever, with giver Wanted Board 46.0, 47.8 and ender Captain Nials 45.8, 47.6.
   - Matching by title fails, so these four steps can never auto-complete. Fix the titles, and the QuestIDs entries if they are keyed by title.
2. **Wetlands: Fiora Longears is accepted at 20** (line 935).
   - Quest 1132 has **required level 30**, so the giver offers nothing at 20.
   - Move the pick-up to the 30+ Menethil visit, or drop it into the Dustwallow route (2.5).
3. **Wetlands: "Crocs of the Sky" (lines 933/1010, ID 98072 in the notes)** is not in the Forever QuestieDB (no ID 98072, no title match).
   - It was taken from foreverchanges. Keep it marked unverified, and check that it still exists.
4. **Stranglethorn: "Anything of Value" (lines 1645/1685)** has no title or ID match in the Forever data. Unverified, same treatment as 3.
5. **Stranglethorn: Private Thorsen** (Jungle Secrets 215, Supplies to Private Thorsen 198; lines 1563/1631).
   - The route has 38.0, 3.4. The Forever data has his spawn at **40.3, 8.4**.
   - He patrols a path, so use the data's spawn point, or add a `Path`.
6. **Desolace caravan coordinates** (lines 1486, 1495). The data places:
   - Cork Gizelton (Bodyguard for Hire 5821) at **66.5, 37.5**, near Kormek's Hut.
   - Rigger Gizelton (Gizelton Caravan 5943) at **45.4, 75.3**.

   The route's 66.8, 58.1 and 66.7, 58.6 are mid-patrol points. The caravan moves, so the start point should be the parked spot. Check in game which end the caravan waits at for each quest (U).
7. **PLAN line 2844**: "Riverglades ... opens at 33".
   - The lowest Alliance Riverglades quest is level 36 (Eyes for the Watchman 94999, required 36, per foreverchanges).
   - The only level-22 entry on that list is the Duskwood/Stormwind orphan quest.
   - Change it to 36, and the 36-41 band's hub to Farholde Keep.
8. **Item-started quests modelled as `A` from an NPC or object.** They pass in game, but they cannot be auto-checked against a giver. Turning them into `Item(itemID, 1, ...)` collect steps plus `A` would let the guide show progress. All IDs V:

   | Quest | Line | Item |
   |---|---|---|
   | Ship Schedules | 1824 | 9250 |
   | Thalanaar Delivery | 1966 | 11463 |
   | Find OOX-09/HL! | 2074 | 8704 |
   | Williden's Journal | 2139 | 11116 |
   | Flute of Xavaric | 2287 | 11668 |
   | A Strange Red Key | 2310 | 13140 |
   | Winterfall Firewater | 2680 | 12771 |
   | The Final Piece | 2724 | 12842 |
   | Gleaming Crescent Necklace (Ashenvale) | 896 | Gleaming Crescent Pendant (98027) |

9. **Forever "New" quests with no giver in Questie**: they can only be checked from foreverchanges.
   - Trying Times 98246, Crimson Crate Delivery 98240 (Wetlands)
   - The Shamed Lieutenant 98219 (Hillsbrad)
   - Vahlarriel's Vengeance 97284 (Desolace)
   - The Cook in the Cage 97047, Where's the Key? 97329, Zimmix's Great Escape 97331 (Stranglethorn)

   Their givers and coordinates in our routes are U.
10. Remarks checked and found correct, not bugs:
    - "Hints of a New Plague?": Quae and Kinelory stand together at 60.2, 53.9.
    - "Sunken Treasure": part 1 is given by Professor Phizzlethorpe and handed to Doctor Draxlegauge; the route has this right.
    - "Return the Statuette": part 2, 98189, has no giver data.
    - The Duskwood Sven leg and the Winterspring Deadwood Cauldron: these steps are on other maps by design.

### 4.2 Missing zones (no route exists)

| Zone | Route name | Levels | Section |
|---|---|---|---|
| Stonetalon Mountains | STONETALON | 24-27 | 2.1 |
| Redridge Mountains | REDRIDGE | 17-25 | 2.2 |
| Westfall | WESTFALL | 10-18, Human | 2.3 |
| Elwynn Forest | — | 1-10, Human | not researched here |
| Dustwallow Marsh | DUSTWALLOW | 34-40 | 2.5 |
| Badlands | BADLANDS | 38-44 | 2.6 |
| Swamp of Sorrows | SWAMP | 36-40 | 2.7 |
| Searing Gorge | SEARING | 45-50 | 2.8 |
| Azshara | AZSHARA | 46-52 | 2.9 |
| Thousand Needles / Shimmering Flats | NEEDLES | 28-35, optional | 2.10 |
| Alterac Mountains | — | 31-38 | best folded into HILLSBRAD as `On("Alterac Mountains", ...)` steps (2.11) |
| Blasted Lands | BLASTED | 47-55 | 2.12 |
| Riverglades | RIVERGLADES | 36-47 | 2.14, needs giver data first |
| Shen'dralas | — | 38-45 | optional, 2.15 |
| Mount Hyjal | — | 56-60, Forever, 102 quests | no giver data yet (U) |

foreverchanges also names **Gilneas** as a new zone. It has no quests or level range listed yet.

Suggested chains, keeping min-level order as the guide requires:

```
NightElf = { TELDRASSIL, DARKSHORE, ASHENVALE, STONETALON, WETLANDS, DUSKWOOD, HILLSBRAD, ARATHI, DESOLACE, STRANGLETHORN,
             DUSTWALLOW, SWAMP, RIVERGLADES, BADLANDS, FERALAS, TANARIS, HINTERLANDS, SEARING, AZSHARA, BLASTED,
             UNGORO, FELWOOD, BURNING_STEPPES, WESTERN_PLAGUELANDS, EASTERN_PLAGUELANDS, WINTERSPRING, SILITHUS }
Human    = { (ELWYNN), WESTFALL, REDRIDGE, DUSKWOOD, WETLANDS, ASHENVALE, HILLSBRAD, ... same tail ... }
Dwarf/Gnome = { DUN_MOROGH, LOCH_MODAN, REDRIDGE(optional), WETLANDS, DUSKWOOD, ASHENVALE, HILLSBRAD, ARATHI, DESOLACE,
             STRANGLETHORN, DUSTWALLOW, BADLANDS, RIVERGLADES, ... same tail ... }
```

routes.md F-14 already notes that Burning Steppes (min 50) sits ahead of Un'Goro (min 48) in some chains; keep the tail in min-level order.

### 4.3 Forever quests on existing routes that are not routed yet

All V.
- **Ashenvale**:
  - Seeking Caitlin 95737 (Llana 35.0, 48.5): breadcrumb to the Excavation Site.
  - The Velinde/Scythe of Elune line 1037-1044: Moonbeam Wand. Velinde Starsong needs The Howling Vale 1022, which the route turns in at line 903.
- **Wetlands**: the Excavation Site quests listed in 2.13.
- **Duskwood**:
  - Remember That I Love You 92415/95161 (Forever, item-started)
  - Ira's Dagger 96137 and Merrick's Bow 96138 (item-started, now with item IDs 281143 / 281142)
- **Hillsbrad**:
  - Friend of the Kirin Tor 92459, which follows An Alarming Request 92432 (already routed)
  - Past Due 96800 (Dalaran, SM)
- **Desolace**: the Shen'dralas Magram/Gelkis lines (2.15).
- **Swamp of Sorrows** (if routed): This Light of Mine 93585, My Little Friends 93176.

### 4.4 Quests Forever changed

These are tagged "changed" in the Forever delta; check their text when routing.
- Redridge: Show of Force 98407, The Everstill Bridge 89 (now leads to Alther's Mill 98386), Tharil'zun 19 and Shadow Magic 115 (now need Blackrock Menace 20 **and** Blackrock Blockade 98387), the WANTED posters 169/180/95999.
- Stonetalon: Covert Ops Alpha/Beta 1079/1080, Scramble/Wet Job 79980/79974.
- Thousand Needles: Report Back to Fizzlebub 1122.
- Arathi: WANTED quests 684/685.
- Westfall: Poor Old Blanchy 151 and the Alba Fairmoon/Ozwin quests (92742-92911).

No quest in the zones researched here was found removed. Every Classic quest checked in these zones is still in the Forever data. Forever also adds the Craftsman's Writ profession hand-ins, which belong in a profession helper, not the leveling route.

---

## Sources

- Forever QuestieDB (read as text): `downloads/QuestieDB/data/Forever/*.lua`, `src/corrections/Forever/**` (legacy, generated, authored), `src/corrections/enum/{zones,expansions}.lua`.
- WhatsTraining `Classes/Vanilla/Priest.lua` (training table, read as data).
- Our own `Dungeons/Data.lua` (Forever dungeon level ranges and entrances).
- foreverchanges.pro: `/`, `/quests`, `/quests/riverglades`, `/quests/mount-hyjal`, `/quests/shendralas`, `/quests/swamp-of-sorrows`, `/quest/94999`.
- wow4ever.quest: `/en/zones/riverglades`, `/en/articles/guia-subida-30-40-wow-forever`.
- wowhead.com/forever/quest=94999.
- warcraft.wiki.gg/wiki/Farholde_Keep.
- timesaver.gg Riverglades zone guide.
