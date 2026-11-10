# wowhelper on WoW: Forever: improvements from current addons and Forever game changes (2026-11-10)

Scope: improvements worth building for a solo Alliance leveler on Forever (client 1.60.1, interface 16001). They
come from:
- addons that earlier research files did not cover;
- Forever game changes up to the 9 November hotfixes and the announced 10 November class tuning.

Everything here is read-only and UI-only, in line with the suite's rules. Nothing in the repo was edited.

## How this was done, and what couldn't be done

- **CurseForge could not be read directly.** www.curseforge.com and its internal API returned 403 (Cloudflare),
  api.curseforge.com needs a key, and no desktop browser was attached to this session. Instead:
  - Popularity and last-update dates for named projects come from the public cfwidget API
    (`https://api.cfwidget.com/wow/addons/<slug>`). Totals are "all-time downloads" as of today.
  - Kami-Labs' Forever directory (135 addons, "sorted by use", checked 20 Oct 2026) stood in for the
    popularity-sorted Forever list: https://kami-labs.fr/en/addons-wow-forever/
- **GitHub** was searched through its public API, sorted by stars and by update date
  (queries: "wow forever addon", "16001 addon", topic `wow-forever`). Most Forever addons publish their source there.
- **Wago Addons**: the page loads, but its search ignored the game-version filter without JavaScript. I could not
  get a Forever list from it.
- **WoWInterface**: a search for "forever" returned no addon entries.
- **Downloads and checks.** 22 addon repositories were downloaded as GitHub zips into
  `C:\Users\you\AppData\Local\Temp\opencode\quarantine\<name>\`. Windows Defender (`Start-MpScan -ScanType CustomScan`)
  scanned each zip, and again after extraction. It found nothing: `Get-MpThreatDetection` shows no detections
  in the last 3 hours, and the only entries in its history are from 22 October, unrelated.
- **Read, never run.** Code was only read: nothing was run, loaded or installed. Below, findings are described in
  my own words; no code or guide text is copied.
- **API docs.** Every API and event named in Section 3 was checked in the client's generated API documentation:
  `...\scratchpad\uisrc2\Interface__AddOns__Blizzard_APIDocumentationGenerated__*.lua`.
  - Some globals are not in those files; each is marked "(not in API docs)" where it appears.
    - Achievement globals such as `GetAchievementCriteriaInfo` and `GetCategoryList`.
    - `C_TradeSkillUI.GetAllRecipeIDs`, `GetLootSlotLink`, `GetProfessions` and `GetProfessionInfo`.
  - Working Forever addons do call some of them; that is cited where it applies.
- **Marks used below:**
  - **[unverified]**: I could not confirm the claim.
  - **[third-party measurement]**: another author measured it in game, not Blizzard.

---

## Section 1: addons studied

Popularity is CurseForge all-time downloads from cfwidget ("n/a" = cfwidget had no entry for the slug I tried).
Version is the newest one seen (repo changelog or CurseForge file). "Forever support" is the TOC interface line.

### 1.1 Legacy Forever (cjber)
- **Version:** 1.1.4 (2026-11-09). **Licence:** GPL-3.0-or-later. **Forever:** Forever only (16001). **Downloads:** 31.5k.
- **What it does that we don't:**
  - Lists the character's unfinished **Legacy challenges**: Forever's account-wide achievement-like goals that pay
    Legacy points.
  - Puts them on the world map by zone, with the zone's undiscovered areas shaded, and tracks the ones you pick.
  - Adds a "zone completion" percentage: explored areas, dungeons, flight paths and, optionally, quests.
  - Progress is read live from the achievement API. Points per challenge come from
    `C_Traits.GetTraitCurrencyForAchievement(4225, achievementID)`.
  - Known flight paths are taken only from a flight master's own list. Its code notes that on Forever, zone maps
    report every node as discovered.
- **Not for us:**
  - It opens Blizzard's Legacy panel through `ToggleLegacySystemUI` and `AchievementFrame_SelectAchievement`.
  - It writes into the objective tracker.
  - It shares flight-path totals over addon messages.

### 1.2 Adventure Guide Forever (cjber)
- **Version:** 1.4.4 (2026-11-10). **Licence:** GPL-3.0-or-later. **Forever:** Forever only. **Downloads:** n/a.
- **What it does that we don't:**
  - Reads each zone's quests as story "chapters" and offers "journeys": a zone story, nearby zones for your level,
    class quests, or "tidy your log".
  - When an objective camp's mobs are 3 or more levels above you, it switches to a lower camp.
  - Includes a hearth-set hint: bind at the inn nearest your next stop.
  - Ships a client-diff table generated from wago.tools DB2, build 70862 against Classic Era 1.15.9. It lists
    Forever-only quest IDs per zone map and the Forever-only zones with their level ranges and flight masters:
    - Riverglades: uiMapID 2548, levels 36-44, Farholde Keep flight master at 60.6, 81.6.
    - Zephras Isle: uiMapID 2521, levels 3-12.
- **Not for us:** quest data comes from QuestieDB at runtime, and the walking route is delegated to Shortest Path.

### 1.3 XPForever (Palanim)
- **Version:** 1.0.1. **Licence:** MIT. **Forever:** Forever only. **Downloads:** 3.9k.
- **What it does that we don't:**
  - **"Active clock" XP/hour:** time only counts while you move, fight or gain XP. It stops after 180 s idle, so
    breaks don't drag the rate down.
  - **Kills to level:**
    - Each XP gain is held for 0.5 s; if `QUEST_TURNED_IN` (payload `xpReward`) arrives meanwhile, the quest part is
      taken off.
    - The rest is counted as a kill, with the rested bonus removed.
    - It keeps the last 10 kills and works out the kills left, accounting for rested XP doubling them.
  - Quest XP from finished quests is shown on the bar.

### 1.4 Level Up Info (F0rty_tw0)
- **Version:** 0.1.7. **Licence:** MIT. **Forever:** 11509 / 16001 / 20506. **Downloads:** n/a.
- **What it does that we don't:** on level-up, a window lists stat gains and the spells you can now buy, with
  prices. It also covers **spells no trainer sells on Forever**:
  - Race-specific Priest spells learned from quests at 10 and 20: Divine Grace (Human), Chastise (Dwarf),
    Confounding Flash and Contingency Plan (Gnome), Starshards and Elune's Grace (Night Elf), and others.
  - Weapon masters by weapon skill, including Forever's extras: Druids can train Polearms and Rogues One-Handed Axes.

### 1.5 GnomeLevelUp (Captain_British)
- **Version:** 1.6.1. **Licence:** none stated (all rights reserved by default). **Forever:** 16001 + Retail.
  **Downloads:** 106k.
- **What it does that we don't:**
  - A built-in per-class Forever trainer catalogue: spell, rank, level, cost, and which rank replaces which. It can
    forecast trainer visits before you've ever opened a trainer.
  - The Warlock demon trainer's grimoires: pet spells by rank, level and cost, checked against the pet's spellbook.
- **Ideas only** (no licence).

### 1.6 LootTriage (Krelock)
- **Version:** 1.1.7. **Licence:** none (all rights reserved). **Forever:** 16001 + Retail. **Downloads:** 178k.
- **What it does that we don't:** when you loot with full bags, it compares each loot slot's value with your
  cheapest junk, and marks what's worth taking and what to delete first.
  - It reads `GetLootSlotInfo` / `GetLootSlotLink`.
  - It respects quest items (`C_Container.GetContainerItemQuestInfo`) and equipment sets.
- **Not for us:** it hooks bag buttons and sorts bags itself (`PickupContainerItem`).

### 1.7 CraftUpgrades (Krelock)
- **Version:** 1.3.2. **Licence:** none (all rights reserved). **Forever:** 16001. **Downloads:** n/a.
- **What it does that we don't:** lists the recipes you know whose crafted item beats what you wear, scored by role.
  It reads `C_TradeSkillUI.GetRecipeSchematic` and `GetRecipeInfo`.
- **Not for us:** it hooks the Professions window.

### 1.8 Books on Map (Forever) (Daeler)
- **Version:** 2.2.3. **Licence:** "All rights reserved". **Forever:** 16001 (+ Classic TOCs). **Downloads:** 259k.
- **What it does that we don't:** shows Forever's 38 **library books** on the world map and minimap, and ticks a book
  off when:
  - it is in your bags or bank (by item ID or name);
  - its turn-in quest is completed (`C_QuestLog.IsQuestFlaggedCompleted`).
- It also covers the 10-book and 20-book rewards and adds a tooltip line on book items.
- **Facts only.** The data is ARR; our own data would have to come from public pages (see Section 2).

### 1.9 UlDungeonCompanion (Knitresletta)
- **Version:** 0.16.1, **discontinued 2026-11-07**. **Licence:** none. **Forever:** 16001. **Downloads:** 0.2k.
- **What it does that we don't:**
  - Checks every quest it is about to show against the server, once: `C_QuestLog.RequestLoadQuestByID` →
    `QUEST_DATA_LOAD_RESULT`. A quest with no server data is hidden as removed; the server's title and level win.
  - Notes that the native map already draws some dungeon entrances (through `C_EncounterJournal`).
  - Takes entrance points from foreverdb.net, which reads them from the client.

### 1.10 Completao!! (LechuckThePirate)
- **Version:** 1.6.1. **Licence:** GPL-3.0. **Forever:** 16001 (+ Vanilla / TBC TOCs). **Downloads:** n/a.
- **What it does:** quest-chain trees for dungeons, zones, classes, professions and events, coloured by state, with a
  NEW tag for Forever content and a reward search by item type.

### 1.11 Questie Forever Fixes (xelblch)
- **Version:** 0.2.0. **Licence:** MIT. **Forever:** 16001. **Downloads:** n/a.
- **What it does:** fills in quest-chain prerequisites that QuestieDB lacks for Forever quests, for example Wild Eyes
  (91920) only after Return to Quinn (430).
  - A step A → B is applied only when A's turn-in NPC also starts B and A isn't a breadcrumb.
- **Relevant to us:** our `LevelGuide\Prereqs.lua` may have the same gaps.

### 1.12 FindAnUpgrade (elithrar)
- **Version:** 0.1.19. **Licence:** BSD-3-Clause; bundled ATT-derived data is MIT. **Forever:** 16001.
  **Downloads:** 0.8k.
- **What it does:**
  - A quest-reward browser filtered by slot, usability, zone and level.
  - New and modified Forever quests are coloured.
  - A Shortlist of saved quests.

### 1.13 Mapzeroth (tr0tsky)
- **Version:** 2.0.6-forever (dev branch read). **Licence:** none found. **Forever:** 16001 + Retail. **Downloads:** 211k.
- **What it does:** a route planner with a Forever POI dataset (inns, banks, auction houses, cities).
  - It saves the hearth spot per character on `HEARTHSTONE_BOUND`.
  - It records Skyborne ley-line sightings, but by sweeping the minimap's soft cursor for tooltips, which is not for
    us.

### 1.14 Forever Classmate (tomqwu)
- **Version:** 0.31.7. **Licence:** none in repo. **Forever:** 16001. **Downloads:** 6.6k.
- **What it does:** per-class upkeep bars: buffs, imbues, totems, seals, procs.
  - It knows Forever racials (Read Ley Line, Skysight, Eureka!, Elune's Light and others) and the 12 race-specific
    Priest spells.
  - Missing-buff warnings are confirmed out of combat, then dimmed in combat.
  - It uses the native percent-power API when exact power is restricted.

### 1.15 Blackthornes Tradeskills (Blackthornes)
- **Version:** 1.21.1-forever. **Licence:** "All rights reserved" (reuse explicitly forbidden). **Forever:** 16001.
  **Downloads:** 133k.
- **What it does:** profitable-craft finder, AH scanner and craft queue.
- **Of interest to us:** its `Docs/FOREVER_API_FINDINGS.md` holds in-game measurements. I use them only as facts,
  in Section 2.

### 1.16 Developer probes
- **forever-addon-kit** (Thunderz96): MIT, snapshot of 2026-09-24.
- **WoWF Probe** (Cyro19): v1.0.0, no licence.
- **Use:** platform facts only (Section 2): error cap, unknown-event throw, health and damage secrecy, SavedVariables
  history, `C_GameRules` presets.

### 1.17 Skimmed, nothing new for us
- **Pagle** (GPL-3.0, fishing journal): data derived from VMaNGOS.
- **VendorAlert** (MIT): auto-sell and auto-repair are automation. One idea kept: a sound when bags are ≥80% full and
  a known vendor is near.
- **Quest Planner** (no licence): ranks nearby quests by "XP that still counts".
- **Dungeon Quest Atlas Forever** (ARR).
- **Forged Forever Map Notes** (no licence): logs gathering nodes and recipe vendors.

### 1.18 Popular on CurseForge, not downloaded
Sources were not on GitHub. Their public descriptions only (pub):
- **Zonewise:** "where to go" map tints.
- **HiddenMaps:** 58k downloads, instance maps.
- **MapUtils:** 744k downloads, map overlays.
- **InFlight Taxi Timer.**
- **Nova Instance Tracker.**
- **ForeverMapNotes:** undiscovered flight paths, chests, class-filtered rares.
- **Delete Cheapest Item.**
- **Extended Vendor Forever.**

Most of these duplicate what the suite already has: flight times, travel pins, MapPins.

---

## Section 2: Forever game facts that affect our helpers

1. **Experience presets.**
   - At first login a player picks **Classic** or **Enhanced**. Classic turns **quest points of interest and
     objective blobs off by default**; Enhanced turns them on.
   - The API exposes it: `C_GameRules.GetForeverExperiencePreset()` → `Enum.ForeverExperiencePreset` (Classic = 0,
     Enhanced = 1), in GameRulesDocumentation.
   - Source: https://worldofwarcraft.blizzard.com/en-us/news/24315280
   - Which CVar the POI switch maps to is **[unverified]**.
2. **Legacy system.**
   - It is account-wide. Points come from challenges, which are achievements: a class reaching 25, 45 and 60,
     professions at 150, 225 and 300, dungeons, exploration and more.
   - Up to 16 points can be spent at launch, across three trees.
   - Client constants (LegacyConstantsDocumentation):
     - points currency `LEGACY_POINTS_TRAIT_CURRENCY_ID = 4225`;
     - reward-track faction 2802;
     - trees: Professions 1187, Adventure 1188, Progression 1189;
     - per-class default categories 15577-15585.
   - Sources:
     - https://www.wowhead.com/forever/guide/legacy-system-overview-rewards
     - https://www.wowhead.com/forever/news/how-do-legacy-points-work-in-wow-forever-383029
     - https://mobalytics.gg/wow-forever/guides/legacy-system-guide
   - When the panel unlocks is in doubt. One source says level 25 (forever-addon-kit README); Blizzard via Wowhead
     says "as soon as you earn your first point". **[unverified which]**
3. **Legacy perks that change what our helpers compute** (same sources as fact 2):
   - **Well Rested:** rested XP builds 4% faster and the cap is 4% higher, per rank (5 ranks).
   - **Talented:** talent points start at level 9 instead of 10, still 51 at most. Sources disagree on the ranks:
     Wowhead lists 5, Mobalytics 1, and Blizzard says "up to 5 levels lower". **[unverified]**
   - **Frequent Flier:** flights cost 50% less and fly 20% faster.
   - **Reagent Economy:** class spells need no vendor reagents.
   - **Gourmand:** food buffs last 33% longer per rank.
   - **Reinforce:** 8% less durability loss on death per rank.
   - **Diplomat:** reputation +2% per rank.
   - **Working Overtime:** skill-up chance +4% per rank.
   - **Bartering:** vendor prices −5% per rank (Mobalytics only).
   - **Performance Bonus:** chance of double Merchant's Favor.
4. **Camping.**
   - A quest around level 5 ("The Great Outdoors") introduces it.
   - Sitting at a campfire for about a minute gives **Camp Benefits** for 1 hour.
   - Leatherworking's **Camp Tent** (skill 20) gives **rested XP up to 5% of a level, once an hour**. Quest-giver
     fires always give it.
   - The Pouch of Violet Dust toy adds one hour; it was fixed on 9 November.
   - Sources:
     - https://www.wowhead.com/forever/guide/camping-overview-unlock-rewards
     - https://www.wow-professions.com/forever/camping-guide
     - https://www.wowhead.com/blue-tracker/topic/us/2403040
5. **Cozy Sleeping Bag** (item 211527).
   - Use it to rest for at least a minute: an experience bonus that stacks up to 3 times (≈3%), 1-hour cooldown.
   - The quest chain starts for the Alliance in Westfall, Alexston Farmstead, /way 37 50. Wowhead estimates about
     89 minutes.
   - Source: https://www.wowhead.com/forever/news/level-faster-with-your-cozy-sleeping-bag-in-wow-forever-383801
6. **XP food.**
   - Many new Forever cooking recipes give **+5% XP from kills** while Well Fed, alongside a stat.
   - Old Classic food does not. Quest XP is not affected.
   - Sources:
     - https://www.wowhead.com/forever/news/all-cooking-food-that-currently-gives-xp-buffs-in-wow-forever-382928
     - https://conquestcapped.com/guides/wow-forever/wow-forever-cooking/ ("35 of 44 new recipes")
   - The exact recipe list is **[unverified]**.
7. **Merchant's Favor** (currency 3402) and **Waylaid Crates**.
   - The crates are world drops from level 10, and also drop in dungeons since the 9 November hotfix.
   - Each crate is filled with **one** listed bundle, for example 20 Copper Ore *or* 20 Tin Ore, then turned in.
   - Alliance turn-in: **Marcy Baker, Three Corners, Redridge Mountains (/way 9.6, 70.9)**.
   - The first Shipping Label quest gives 660 XP and 2,000 reputation with the Azeroth Commerce Authority.
   - Craftsman's Writs give reputation, one per distinct order per day.
   - Crates trade on the AH until filled.
   - Sources:
     - https://www.wowhead.com/forever/guide/azeroth-commerce-authority-reputation-professions
     - https://www.wow-professions.com/forever/merchants-favor-durotar-supply-azeroth-commerce (crate IDs 248682-248713)
     - https://mythic-store.com/blog/how-to-farm-merchant-s-favor-in-wow-forever
8. **Library books.**
   - 38 collectible books, turned in at Garion Wendell, Stormwind Mage Quarter (37.6, 80.8).
   - 10 books: a choice of neck (now Uncommon). 20 books: a choice of ring (item level 35, no class restriction).
   - Sources: https://wow4ever.quest/en/library-books ; https://www.wowhead.com/news=383231
   - Caution: wow4ever's Eastern Plaguelands points, such as Light's Hope at 71.8, 48.2, match the mis-framed EPL map
     already noted in `research\gaps_filled.md`. Check every EPL book point. **[unverified]**
9. **Dungeon kill XP +50%** since 8 November.
   - The 9 November hotfixes also changed several dungeons:
     - Drowned City damage reduced by 30%, and its Deathless Marrow encounter nerfed.
     - Alcaz Prison's Zarla Ober now drops loot.
     - Shaper's Terrace loot fixed.
   - Sources: https://www.wowhead.com/blue-tracker/topic/us/2406595 ; https://www.wowhead.com/blue-tracker/topic/us/2403040
10. **10 November class tuning.**
    - Hunter pets and Voidwalkers are to be as durable as in Classic Era.
    - Affliction should cast its DoTs as well as channelling Wrack.
    - **Enhancement Shaman: Strength must beat Intellect and Spell Power.** Levelers should collect Strength and
      Attack Power gear.
    - Source: https://www.wowhead.com/blue-tracker/topic/us/class-tuning-incoming-november-10-2404092
    - The text of the 10 November hotfix post itself was **[not found yet]**.
11. **Downranking nerfed.** Ranks far below your level get less from spell power and trigger talent effects less often.
    Source: https://www.wowhead.com/news=383285
12. **Riverglades.**
    - Levels 36-44, uiMapID **2548** (wago.tools DB2 via Adventure Guide Forever's data).
    - Alliance hub Farholde Keep; flight master Gretchen Mayberry at 60.6, 81.6.
    - Way in: a fork off the Redridge road, through Blackrock Pass.
    - A boat runs from **Steamwheedle Port, Tanaris (68.6, 23.0) to Powderfuse Port**.
    - Over 150 new quests (Blizzard).
    - Source: https://www.wowhead.com/forever/guide/riverglades-zone-overview
13. **New ship routes:** Stormwind Harbor ↔ Auberdine, and Menethil ↔ Southshore ↔ Auberdine.
    Source: https://lfcarry.com/guides/wow-forever-new-zones (third party) **[unverified exact stops]**
14. **Spells not sold by class trainers.**
    - Race-specific Priest spells come from quests at 10 and 20. Example: Divine Grace, quest 94773, for Humans.
      Source: https://www.wowhead.com/forever/spell=1277370
    - Druids can train Polearms and Rogues One-Handed Axes. Source as cited by Level Up Info:
      https://www.warcrafttavern.com/forever/guides/weapon-trainers/ (not opened by me) **[unverified]**
    - Dual Specialization unlocks at level 40, per Blizzard's Druid deep dive:
      https://worldofwarcraft.blizzard.com/en-us/news/24301515
15. **Skyborne (Alliance): Read Ley Line.**
    - Health and mana regeneration +50% for 15 s.
    - Cast at a ley line, it also gives **Attuned** for 1 hour, which doubles the effect. Attuned persists through
      death and is removed on entering a raid.
    - Source: https://www.icy-veins.com/wow-forever/skyborne-race-guide
16. **Quests pay no gold at 60.** Blizzard says this is intentional, reported via Wowhead, not formally confirmed:
    https://www.wowhead.com/forever/news/quests-give-no-gold-at-level-60-in-wow-forever-intentional-change-according-to-383803
17. **Sell prices.** The vendor sell price from `C_Item.GetItemInfo` (11th return) can be the stale Classic value.
    The tooltip's SellPrice line is right; example: Greater Magic Wand shows 1c on the tooltip but 15s 35c from
    `GetItemInfo`. Source: Blackthornes `Docs/FOREVER_API_FINDINGS.md` (beta, Oct 2026). **[third-party measurement]**
18. **`GetProfessionInfo` may not exist.**
    - It was measured absent on beta build 69913; use `GetProfessionInfoBySkillLineID` or `GetBaseProfessionInfo`
      instead.
    - `GetAllProfessionTradeSkillLines` returns each profession twice, under a modern ID (29xx) and a legacy ID.
    - `C_TradeSkillUI.GetAllRecipeIDs` is empty unless a profession window is open.
    - A recipe's colour is in `GetRecipeInfo().relativeDifficulty` (0 = optimal … 3 = trivial).
    - Source: the same Blackthornes file. **[third-party measurement on a beta build; check on live]**
19. **Client behaviour** (forever-addon-kit README, measured on the beta):
    - Registering an event the client doesn't know **throws** and stops the file.
    - After 100 Lua errors in a session the client stops passing errors to handlers.
    - `ReloadUI()` is protected.
    - SavedVariables did not load until build 70009 (since fixed).
    - Two claims there disagree with the API docs:
      - **[conflict]** It says `UNIT_COMBAT` amounts are plain, but the docs mark `amount` as `SecretValue = true`.
      - **[conflict]** It says the Legacy panel unlocks at level 25 (see fact 2).
20. **Hearthstone cooldown: 60 minutes on Forever.** Reddit only. **[unverified]** RestGuard reads the live cooldown,
    so nothing depends on the number.
21. **Darkness.** Forever's lighting makes some zones dark at night. The **Night Watchman's Torch** (item 280612, from
    a Duskwood quest) gives light for 5 minutes and goes out on any combat action. Source:
    https://www.method.gg/wow-forever/how-to-get-a-torch-in-wow-forever-night-watchmans-torch

---

## Section 3: ranked improvements (25)

Ranked by value for a solo Alliance leveler, divided by effort. Size: S ≈ under a day, M ≈ a few days,
L ≈ a week or more.

1. **QuestMobs, QuestTracker, LevelGuide, ForeverHub: warn when the "Classic" experience preset hides quest POIs.**
   - **What:** at login, read the preset. If it is Classic, put one hub notice saying the map's quest markers and
     objective areas are off by default, which weakens QuestMobs and LevelGuide's "!" pickup, and where to turn them
     back on. While the game reports no POIs for a quest you hold, fall back to the route's own coordinates.
   - **Why:** `compare_2026-11-10.md` says QuestMobs "relies on the game's own map '!' and objective areas".
     Classic-preset players (veterans, the likely audience) will see those helpers do less, with no visible cause.
   - **APIs:**
     - `C_GameRules.GetForeverExperiencePreset()` and `Enum.ForeverExperiencePreset` (GameRulesDocumentation);
     - `C_QuestLog.GetQuestsOnMap`, `C_QuestLog.GetMapForQuestPOIs` (QuestLogDocumentation);
     - event `PLAYER_ENTERING_WORLD`.
   - **Open questions [unverified]:** which CVar or option the preset sets, and whether the POI functions still return
     data when the display is off. Test both presets in game.
   - **Size:** S. **Source:** Blizzard's starter guide (fact 1), API docs.

2. **ProfessionCap, ProfessionGuide, GoldGuide, ItemAdvisor: a profession reader that doesn't need `GetProfessionInfo`.**
   - **What:** today all four bail out quietly when `GetProfessions` or `GetProfessionInfo` is missing:
     `ProfessionCap.lua:40`, `ProfessionGuide.lua:228`, `GoldGuide.lua:248`, `ItemAdvisor.lua:375`. If those globals
     are absent on live, GoldGuide filters farms with "no professions" and ProfessionCap shows nothing. Add a fallback:
     - read `C_SkillInfo.GetSkillLineInfoByID` for the twelve Classic skill lines (164, 165, 171, 182, 186, 197, 202,
       333, 393, 129, 185, 356); the suite already does this for First Aid and Riding;
     - or use `C_TradeSkillUI.GetProfessionInfoBySkillLineID`;
     - drop duplicate modern and legacy IDs.
   - **Why:** a silent correctness gap in four helpers.
   - **APIs:** `C_TradeSkillUI.GetAllProfessionTradeSkillLines`, `GetProfessionInfoBySkillLineID`,
     `GetBaseProfessionInfo` (TradeSkillUIDocumentation); `C_SkillInfo.GetSkillLineInfoByID`; event
     `SKILL_LINES_CHANGED`.
   - **First step:** in game, `/dump GetProfessionInfo`. **[unverified on live]**
   - **Size:** S. **Source:** Blackthornes findings (fact 18).

3. **Tooltips, ItemAdvisor, BagCheck, WindowBadges, GoldGuide: take the vendor price from the tooltip line.**
   - **What:** get vendor value from `C_TooltipInfo.GetItemByID(id)` (or `GetBagItem`, `GetMerchantItem`), from the
     line whose type is `Enum.TooltipDataLineType.SellPrice`, rather than from `C_Item.GetItemInfo`'s 11th return.
     Cache it by item ID.
   - **Where the old return is used today:** `BagCheck.lua:55`, `GoldGuide.lua:333`, `WindowBadges.lua:190`,
     `Tooltips.lua:211`, `ItemAdvisor.lua:1157`.
   - **Why:** sell/keep advice and "junk worth" totals go wrong on items whose Forever price changed (fact 17).
   - **APIs:** `C_TooltipInfo.GetItemByID`, `GetMerchantItem`, `GetInventoryItem` (TooltipInfoDocumentation).
     Out of combat only, behind a time-budgeted cache.
   - **Size:** S. **Source:** Blackthornes findings. **[third-party measurement]**

4. **RestGuard, ReadyCheck, FoodCheck: an "XP boosters" block on the side panel.**
   - **What:** one line per Forever XP source, each with "have / active / ready in":
     - **Well Fed with an XP food:** detected from the item tooltip ("experience" in its effect text), and the buff
       read out of combat.
     - **Cozy Sleeping Bag:** owned, its cooldown, and stacks of the rest bonus.
     - **Camp Benefits:** active, and time left.
     - **Camp Tent rested:** whether the hourly rested gain is ready.
   - **FoodCheck:** when choosing food for your level, rank +5%-XP foods first.
   - **LevelGuide:** an optional "Cozy Sleeping Bag" detour step from Westfall 37, 50.
   - **Why:** these are Forever-only, cheap and stack with rested XP. Wowhead's calculator says the 3% bag alone saves
     about 162 kills from 50 to 60.
   - **APIs:**
     - `C_Container.GetItemCooldown`, `C_Item.GetItemCount` (ItemDocumentation);
     - `C_UnitAuras.GetPlayerAuraBySpellID` (UnitAuraDocumentation), only while
       `C_Secrets.ShouldAurasBeSecret()` is false (SecretPredicateAPIDocumentation);
     - `C_TooltipInfo.GetItemByID`;
     - events `UNIT_AURA` (player), `BAG_UPDATE_DELAYED`, `PLAYER_REGEN_ENABLED`.
   - **Open questions [unverified]:** the spell IDs for Camp Benefits, the sleeping-bag rest buff and the Well Fed XP
     buff. Learn them by name the first time they're seen out of combat.
   - **Size:** M. **Source:** facts 4-6.

5. **ForeverHelper (new "Legacy" page) and LevelLog: Legacy challenges and points.**
   - **What:** a hub page listing unfinished Legacy challenges.
     - Read them live from the achievement categories, starting at the class's `LEGACY_DEFAULT_CATEGORY_*` constant.
     - Group them into "this zone", "levels and skills" and "dungeons".
     - Show points per challenge, and progress such as "7/12 areas explored in Ashenvale".
     - LevelLog records the Legacy point earned when a class hits 25, 45 or 60.
   - **Why:** Legacy points buy account-wide leveling perks: Well Rested, Talented, Frequent Flier. Exploration and
     dungeon challenges line up with what a leveler does anyway.
   - **APIs:**
     - `GetCategoryList`, `GetCategoryNumAchievements`, `GetAchievementInfo`, `GetAchievementNumCriteria`,
       `GetAchievementCriteriaInfo` (not in API docs; Legacy Forever uses them on Forever);
     - `C_Traits.GetTraitCurrencyForAchievement(4225, id)` (SharedTraitsDocumentation);
     - `C_MapExplorationInfo.GetExploredMapTextures` (MapExplorationDocumentation);
     - events `CRITERIA_UPDATE`, `ACHIEVEMENT_EARNED` (AchievementInfoDocumentation) and `MAP_EXPLORATION_UPDATED`.
   - **Size:** M.
   - **Source:** Legacy Forever, GPL-3.0. That is compatible with our licence, but per the rules re-implement it, don't
     copy.

6. **Several helpers: Legacy perk awareness.**
   - **What:** read the player's ranks in the Legacy trees, then use them where they change a number:
     - **RestGuard:** Well Rested changes the fill time and the 150% cap;
     - **Landmarks:** Frequent Flier changes flight ETA and cost;
     - **SupplyWatch:** with Reagent Economy, don't nag about vendor reagents;
     - **FoodCheck / ReadyCheck:** Gourmand changes food-buff length;
     - **DurabilityWatch:** Reinforce changes the death durability estimate;
     - **RepWatch:** Diplomat changes "rep to next standing";
     - **ProfessionGuide:** Working Overtime changes crafts-per-point;
     - **Builds / TalentNudge:** Talented changes when points arrive (see #19).
   - **How:** `C_Traits.GetConfigIDByTreeID(1187|1188|1189)`, then `GetTreeNodes`, `GetNodeInfo` and
     `GetDefinitionInfo` to map node names to ranks. Builds already walks trait trees this way.
   - **Why:** several helpers show numbers that are wrong for anyone who has bought a perk.
   - **APIs:** `C_Traits.GetConfigIDByTreeID`, `GetTreeNodes`, `GetNodeInfo` (SharedTraitsDocumentation);
     `Constants.LegacyConsts` (LegacyConstantsDocumentation); events `TRAIT_CONFIG_UPDATED`, `PLAYER_ENTERING_WORLD`.
   - **Open question [unverified]:** whether the Legacy configs read the same way as class talents.
   - **Size:** M. **Source:** fact 3, Legacy Forever, forever-addon-kit.

7. **Tooltips, ItemAdvisor, BagCheck, GoldGuide, RepWatch, MapPins: Waylaid Crates and Merchant's Favor.**
   - **ItemAdvisor / BagCheck:** never advise vendoring a Waylaid Crate (item IDs 248682-248713).
   - **Tooltips:** on a crate, show "fill with: 20 Copper Ore (you have 34) / 20 Tin Ore (12)", where the bundles are
     our own table and the counts are live bag counts, plus where to turn it in.
   - **GoldGuide:** a "crates and favor" line, with Favor per filled crate and the AH price of the bundle from
     PriceMemory.
   - **RepWatch:** Azeroth Commerce Authority standing, and the currency from `C_CurrencyInfo.GetCurrencyInfo(3402)`.
   - **MapPins:** a static pin for Marcy Baker (Redridge 9.6, 70.9).
   - **LevelGuide:** a one-time optional step for the first Shipping Label (660 XP).
   - **Why:** a Forever-only economy that every leveler meets from level 10. Our sell advice currently treats crates
     as ordinary items.
   - **APIs:** `C_CurrencyInfo.GetCurrencyInfo` (CurrencyInfoDocumentation), `C_Item.GetItemCount`, the tooltip post
     call already used by Tooltips; events `CURRENCY_DISPLAY_UPDATE`, `BAG_UPDATE_DELAYED`.
   - **Size:** M. **Source:** fact 7.

8. **DeathNotes and LevelGuide: a spirit-healer arrow from the client's graveyard list.**
   - **What:** after you release, point the shared waypoint at the nearest graveyard, or at the corpse when you're a
     ghost. No position data of our own is needed, which is what `compare_2026-11-10.md` #8 assumed it would take.
   - **APIs:** `C_DeathInfo.GetGraveyardsForMap(uiMapID)` → `{name, position, graveyardID}`,
     `GetCorpseMapPosition` and `GetDeathReleasePosition` (DeathInfoDocumentation); events `PLAYER_DEAD`,
     `PLAYER_ALIVE`, `PLAYER_UNGHOST`, `CORPSE_IN_RANGE`.
   - **Open question [unverified]:** whether `GetGraveyardsForMap` returns entries on Forever's Classic-era maps.
   - **Size:** S. **Source:** API docs.

9. **Dungeons and MapPins: dungeon entrances from the client.**
   - **What:** fill the unconfirmed entrances listed in `gaps_filled.md` (Scarlet Monastery, Sunken Temple,
     Scholomance, Ruins of Lordaeron, Stratholme Service Gate, Maraudon). Read them from the map instead of keeping
     guessed coordinates. Use our data only where the call returns nothing.
   - **APIs:** `C_EncounterJournal.GetDungeonEntrancesForMap(uiMapID)` → `{position, name, journalInstanceID}`
     (EncounterJournalDocumentation).
   - **Open question [unverified]:** which maps answer. UlDungeonCompanion saw the native map draw some entrances
     itself, but a beta game rule `EncounterJournalDisabled=1` was also measured.
   - **Size:** S. **Source:** UlDungeonCompanion, API docs.

10. **LevelGuide, ZoneLevels, Dungeons, Landmarks: Riverglades and the new boats.**
    - **Data to add:**
      - uiMapID **2548** for Riverglades. `Dungeons\Data.lua:16` still says "no mapID", and `tests\test_mappins.lua`
        mocks 2521 as Riverglades, while 2521 is Zephras Isle.
      - Levels 36-44, Farholde Keep flight master (60.6, 81.6), the Redridge entrance.
      - The Tanaris boat (68.6, 23.0).
      - The new Stormwind Harbor ↔ Auberdine boat for Night Elves heading to Elwynn and Westfall.
      - ZoneLevels: fallback ranges for 2548 and 2521 when `C_Map.GetMapLevels` has none.
    - **Quest givers:** until Riverglades givers are known, let the route learn them, using our existing offer reading
      (`QUEST_DETAIL`, `GOSSIP_SHOW`) and saving NPC and position. Wowhead's Riverglades guide lists only the
      Bloodmaster's Ring quests.
    - **APIs:** `C_Map.GetMapInfo`, `C_Map.GetMapLevels`; the existing waypoint code.
    - **Size:** M. **Source:** facts 12-13; Adventure Guide Forever's DB2 table.

11. **LevelGuide and QuestCheck: check route quests against the Forever server.**
    - **What:** in the background, one request per frame, ask the server about each quest ID on the current and next
      route legs.
      - No data: mark the step "not on Forever" and skip it.
      - Different title or level: use the server's.
    - **Why:** our routes mix Classic facts with Forever's; this catches removed or changed quests without play-testing.
    - **APIs:** `C_QuestLog.RequestLoadQuestByID`, event `QUEST_DATA_LOAD_RESULT`, `C_QuestLog.GetTitleForQuestID`,
      `C_QuestLog.GetQuestDifficultyLevel` (QuestLogDocumentation).
    - **Size:** S. **Source:** UlDungeonCompanion.

12. **TrainerNotes: spells you learn somewhere other than your class trainer.**
    - **What:** per class and level, list:
      - the Priest race-quest spells at 10 and 20, with the quest and its giver;
      - Warlock grimoires from the demon trainer, checked against the pet's spells;
      - weapon skills by weapon master and city, with Forever's extras (Druid Polearms, Rogue One-Handed Axes).
    - Mark each as learned through `IsPlayerSpell` or the spellbook.
    - **Data:** ours, built from Wowhead Forever spell and quest pages. Level Up Info is MIT, so its list may be used as
      a lead; GnomeLevelUp is ideas only.
    - **APIs:** `IsPlayerSpell` / `C_SpellBook` (SpellBookDocumentation), `C_Spell.GetSpellInfo`; events
      `SPELLS_CHANGED`, `LEARNED_SPELL_IN_SKILL_LINE`, `PLAYER_LEVEL_UP`, `QUEST_TURNED_IN`.
    - **Size:** M. **Source:** Level Up Info (MIT), GnomeLevelUp; fact 14.

13. **WeaponSkillWatch: name the weapon master.**
    - **What:** when ItemAdvisor finds a better weapon of a type you haven't learned, say who teaches it, where, and
      the cost.
    - **APIs:** `C_SkillInfo.GetSkillLineInfoByID` (already used), plus a small static table. Size: S.
    - **Source:** Level Up Info (MIT).

14. **ForeverHub XP panel: idle-aware rate and kills to level.**
    - **What:**
      - Advance a separate "active" clock only while you move, fight or gain XP; stop it 180 s after the last
        activity. The panel today uses wall time and a manual "Restart rates" button (`ForeverHub.lua:1169`, `:1358`).
      - Add "≈ N kills to level": the median of recent kill XP with the rested bonus taken out, and the rested
        doubling applied to what's left. LevelLog already splits quest XP from kill XP using `QUEST_TURNED_IN`'s
        `xpReward`, so reuse that.
    - **APIs:** `UnitXP`, `UnitXPMax`, `GetXPExhaustion` (PlayerScriptDocumentation), `UnitAffectingCombat`, `IsPlayerMoving`;
      events `PLAYER_XP_UPDATE`, `QUEST_TURNED_IN`, `PLAYER_STARTED_MOVING`.
    - **Size:** S. **Source:** XPForever (MIT).

15. **BagCheck: full-bag loot triage (read-only) and a "vendor nearby" nudge.**
    - **What:** on `LOOT_OPENED` with no free slots:
      - our popup lists loot worth more than your cheapest junk;
      - names which bag item to drop first, skipping quest items (`C_Container.GetContainerItemQuestInfo`);
      - nothing is deleted or moved.
    - **Vendor nudge:** when bags pass 80% and Landmarks knows a vendor within about 200 yd, one hub alert.
    - **APIs:** `GetLootSlotInfo`, `GetLootSlotLink`, `GetLootSlotType` (not in API docs; used by LootTriage on Forever),
      `C_Container.GetContainerNumFreeSlots`; events `LOOT_OPENED`, `LOOT_SLOT_CLEARED`, `LOOT_CLOSED`.
    - **Size:** S-M. **Source:** LootTriage (ideas only), VendorAlert (MIT), Delete Cheapest Item (pub).
      This also closes the "cheapest junk to drop" gap in `compare_2026-11-10.md`.

16. **MapPins and Tooltips: library books.**
    - **What:**
      - Pins for the books you're missing, near your level band. The first 15 are in leveling zones.
      - A tooltip line on book items: "library book: missing / collected".
      - A hub note when you hold books to hand in at Garion Wendell.
    - **Done-state:** book in bags or bank, or its turn-in quest completed.
    - **Data:** our own table from wow4ever and Wowhead (fact 8). Do not copy Books on Map's ARR data. Fix the EPL
      frame first.
    - **APIs:** `C_Item.GetItemCount(id, true)`, `C_QuestLog.IsQuestFlaggedCompleted`; events `BAG_UPDATE_DELAYED`,
      `QUEST_TURNED_IN`.
    - **Size:** M. **Source:** Books on Map (ideas), fact 8.

17. **ProfessionGuide: read what you actually know when the profession window opens.**
    - **What:**
      - On `TRADE_SKILL_SHOW`, cache known recipe IDs, each one's `relativeDifficulty` (orange, yellow, green, grey)
        and its reagents. Mark guide steps "known / not yet learned".
      - Show the real colour instead of the guide's thresholds.
      - Add Forever's **camp items** per profession as optional steps, for example Camp Tent (LW 20), Tanning Rack
        (LW 125 since 6 Nov) and Repair Bot (Engineering 140).
    - **APIs:** `C_TradeSkillUI.GetAllRecipeIDs` (only while the window is open; not in API docs),
      `C_TradeSkillUI.GetRecipeInfo`, `C_TradeSkillUI.GetRecipeSchematic` (TradeSkillUIDocumentation); events
      `TRADE_SKILL_SHOW`, `TRADE_SKILL_LIST_UPDATE`.
    - **Size:** M. **Source:** Blackthornes findings, CraftUpgrades, Wowhead camping guide.

18. **ItemAdvisor and ProfessionGuide: craftable upgrades.**
    - **What:** from the cached recipes in #17, list outputs that score higher than your worn item in that slot, using
      ItemAdvisor's role weights, with missing reagents. Show it on our page, not in Blizzard's window.
    - **Why:** Merchant's Favor recipes are Bind on Pickup and meant to gear the crafter.
    - **APIs:** `C_TradeSkillUI.GetRecipeSchematic(...).outputItemID`, `C_Item.GetItemStats`; event
      `PLAYER_EQUIPMENT_CHANGED`.
    - **Size:** M. **Source:** CraftUpgrades (ideas only).

19. **Builds and TalentNudge: Forever's talent schedule.**
    - **(a) Talented:** key the "next talent" by points available rather than by level. Builds reads tree currency
      already (`Builds.lua:179`); `FIRST_TALENT_LEVEL = 10` at `Builds.lua:95` is wrong for a player with Talented.
    - **(b) Dual Specialization at 40:** offer to show the second build, for example leveling and dungeon.
    - **(c) 10 November tuning:**
      - Enhancement weights are fine already: Strength 2.2, AP 1, no spell power (`ItemAdvisor.lua:204`).
      - Re-check the Affliction build text for Wrack plus DoTs.
      - Note the Voidwalker and pet durability change.
    - **APIs:** `C_Traits.GetTreeCurrencyInfo` (already used). **Size:** S. **Source:** facts 3, 10, 14.

20. **ReadyCheck: Forever buffs and the downrank nerf.**
    - **What:**
      - Out of combat only, while `C_Secrets.ShouldAurasBeSecret()` is false, remind about Forever buffs:
        - **Attuned** for Alliance Skyborne: "cast Read Ley Line at a ley line";
        - Camp Benefits, if a fire is nearby, and the Well Fed XP buff (shared with #4);
        - the Night Watchman's Torch in dark zones (fact 21).
      - On the old-rank warnings, add the reason: low ranks now lose spell-power scaling and proc chance.
    - **Landmarks:** remember the places where you gained Attuned, so ley lines you've found can be pinned. No minimap
      tooltip sweeping.
    - **APIs:** `C_UnitAuras.GetPlayerAuraBySpellID`, `C_Secrets.ShouldAurasBeSecret`, `IsPlayerSpell(1259705)`
      (Read Ley Line); event `UNIT_AURA`.
    - **Size:** S. **Source:** facts 11, 15; Forever Classmate (ideas).

21. **Dungeons and LevelGuide: refresh for the November hotfixes and chain gaps.**
    - **Dungeons:**
      - kill XP is now +50%, so "worth running for XP" changes, especially for Hall of Thanes, Deadmines and the
        Drowned City;
      - crates and writs now drop inside;
      - the Drowned City is easier.
    - **LevelGuide `Prereqs.lua`:** check Forever chain links the way Questie Forever Fixes does: keep A → B only where
      A's turn-in NPC starts B. Wild Eyes 91920 after Return to Quinn 430 is a confirmed case.
    - **Size:** S. **Source:** fact 9; Questie Forever Fixes (MIT).

22. **ErrorLog: the client's 100-error cap and unknown events.**
    - **What:**
      - Count errors per session and warn at about 80: after 100 the client stops reporting them, so later errors
        would be invisible.
      - Suite-wide: wrap optional `RegisterEvent` calls in `C_EventUtils.IsEventValid`, since an unknown event throws
        on Forever. `popular_quests_maps.md` mentions this, but nothing implements it yet.
    - **Size:** S. **Source:** forever-addon-kit (MIT).

23. **ItemFinder: count the reagent bag, and don't trust `GetItemCount` for bags you wear.**
    - **What:** walk containers 0-4 plus `Enum.BagIndex.ReagentBag` when the client defines it. Measured on the beta,
      `C_Item.GetItemCount` counts an equipped bag as one of that bag. Bank tabs exist; there is no warbank.
    - **APIs:** `C_Container.GetContainerNumSlots`, `GetContainerItemInfo` (ContainerDocumentation).
    - **Size:** S. **Source:** Blackthornes findings. **[third-party measurement]**

24. **GoldGoal and Landmarks: Forever costs.**
    - **What:**
      - Apply Frequent Flier (−50% flight cost) and Bartering (−5% per rank on vendor items) to the mount and flight
        estimates, from the perk ranks in #6.
      - Note that quest turn-ins pay no gold at 60. That doesn't affect the riding goal, but it does affect a
        "gold per hour" forecast near 60.
    - **Size:** S. **Source:** facts 3, 16.

25. **AutoQuest: Forever turn-ins that spend things.**
    - **What:** add a per-type switch, default on to match current behaviour, for repeatable Forever turn-ins:
      - Shipping Label and A Sealed Crate, which spend a filled crate;
      - Craftsman's Writs, which hand over a crafted item and are limited to one per order per day;
      - library book turn-ins.
      With it, a player can stop AutoQuest from spending a crate or writ they meant to sell on the AH.
    - **APIs:** the existing `QUEST_DETAIL` / `QUEST_PROGRESS` handling, plus `GetQuestItemInfo("required")` to see
      what would be consumed (not in API docs; it is a long-standing quest-frame global).
    - **Size:** S. **Source:** fact 7.

### Every helper covered

| Helper | Items |
|---|---|
| ForeverHub | 1, 14 |
| ForeverHelper | 5 |
| ErrorLog | 22 |
| LevelGuide | 1, 4, 7, 8, 10, 11, 21 |
| ProfessionGuide | 2, 6, 17, 18 |
| ProfessionCap | 2 |
| GoldGuide | 2, 3, 7 |
| GoldGoal | 24 |
| Dungeons | 9, 10, 21 |
| QuestTracker | 1 |
| QuestCheck | 11 |
| ZoneLevels | 10 |
| QuestMobs | 1 |
| AutoQuest | 25 |
| ItemAdvisor | 2, 3, 7, 18 |
| BagCheck | 3, 7, 15 |
| ItemFinder | 23 |
| PriceMemory | 7 (feeds crate pricing) |
| FoodCheck | 4, 6 |
| SupplyWatch | 6 |
| DurabilityWatch | 6 |
| Tooltips | 3, 7, 16 |
| WindowBadges | 3 |
| Builds | 6, 19 |
| TalentNudge | 6, 19 |
| TrainerNotes | 12 |
| ReadyCheck | 4, 20 |
| WeaponSkillWatch | 13 |
| RestGuard | 4, 6 |
| LevelLog | 5, 14 |
| RepWatch | 6, 7 |
| Landmarks | 6, 10, 20, 24 |
| MapPins | 7, 9, 16 |
| DeathNotes | 8 |
| RareWatch | nothing Forever-specific found |

PriceMemory has no Forever gap: it already divides item rows by quantity and reads the commodity `unitPrice`.

For RareWatch, the only Forever changes found are respawn hotfixes (for example Ferocitas in Teldrassil). Nothing
suggests a code change.

### Already done or already proposed, so left out
These are not repeated from earlier research:
- `/way`, flight times, drowning warning: already in the repo (`MapPins\Way.lua`, Landmarks flight times,
  `DeathNotes\BreathWatch.lua`).
- Known flight paths read at the flight master: already in Landmarks and LevelGuide.
- Horde routes, Skyborne 1-13 steps, Questie-style givers, travel pins: in `compare_2026-11-10.md`.
- Merchant's Favor recipes as profession steps: `popular_qol_routes.md` #9; item 7 above extends it to crates and
  sell advice.

---

## Summary

- **Addons studied: 22.** All were downloaded to quarantine, scanned clean with Defender, and read but never run.
  - The most useful for us are Legacy Forever and Adventure Guide Forever (both GPL-3.0), XPForever and Level Up Info
    (both MIT), LootTriage and CraftUpgrades (ideas only), UlDungeonCompanion, and the Blackthornes and
    forever-addon-kit findings.
  - CurseForge's own pages couldn't be read (Cloudflare 403, no browser attached). Popularity comes from cfwidget and
    Kami-Labs instead.
- **Forever systems our helpers don't model yet:**
  - the Classic/Enhanced experience preset;
  - Legacy challenges and perks;
  - camping and Camp Tent rested XP;
  - the Cozy Sleeping Bag;
  - +5% XP foods;
  - Waylaid Crates and Merchant's Favor;
  - library books;
  - Riverglades (uiMapID 2548) and the new boats;
  - quest-taught racial Priest spells;
  - the +50% dungeon kill XP of 8 November.
- **Two possible correctness bugs to check in game first:**
  - `GetProfessionInfo` may be missing on Forever, which would silently blank ProfessionCap and GoldGuide's
    profession filter (item 2).
  - `GetItemInfo`'s sell price can be stale on Forever (item 3).
- **Cheapest high-value wins:**
  - the preset warning (1);
  - the profession fallback (2);
  - the tooltip sell price (3);
  - the client's graveyard and entrance lists (8, 9);
  - server checks for quests (11);
  - the idle-aware XP rate and kills to level (14).
- **Still unconfirmed:**
  - the text of the 10 November hotfix post;
  - the Legacy panel unlock level;
  - the number of Talented ranks;
  - the exact ship stops;
  - whether graveyard and entrance lists return data on Forever maps;
  - the spell IDs for the Camp, Sleeping Bag and Well Fed XP buffs;
  - the EPL book coordinates.
