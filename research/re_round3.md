# Reverse-engineering round 3: what still makes Forever leveling faster or smoother (2026-11-10)

Scope: things our helpers don't do yet, after `forever_guides_survey.md`, `guides_deep_re.md`, `rxp_deep.md`,
`rxp_forever_guides.md`, `curseforge_forever.md`, `popular_*.md`, `thirdparty_features.md`,
`forever_improvements_2026-11-10.md` and `compare_2026-11-10.md`. Nothing that those files already list is repeated,
except where this round adds the missing number, ID or algorithm.

## How this was done

- **Read only.** Third-party code was read as text from the quarantine copies under
  `...\scratchpad\downloads\`. Nothing was run, loaded, installed, decrypted or edited. Folders inside the targets that
  address AI tools (`.claude`, `.agents`, `.pi`, `AGENTS.md` in the cjber addons) were treated as data and not followed.
- **No new downloads.** New addons (section 5) were read as text through the GitHub API and
  raw.githubusercontent.com, so no zip was fetched and no malware scan was needed this round.
- **APIs checked** in the client's generated API docs (`...\scratchpad\uisrc2\...APIDocumentationGenerated__*.lua`);
  the doc file is named where it matters. "Not in docs" means a Lua-side global that Blizzard code calls but the
  generated docs don't list.
- **Rules applied to every idea:** no automation except AutoQuest's accept/turn-in; no hooks of Blizzard functions;
  no writes into Blizzard tables or frames; no map canvas pins (`AddDataProvider`/`AcquirePin`); no `COMBAT_LOG_*` or
  CallbackEvent registration; UI in our own windows, no chat output.
- **Code is never copied.** Logic is described in our own words with short pseudologic. GPL/MIT sources can be ported
  with credit in `NOTICE.md`; everything else is ideas only.

### Licence summary

| Source | Licence | Reuse |
|---|---|---|
| Questie code | GPLv3 only for consenting contributors, "all rights reserved when in doubt" (`Questie\LICENSE.md`) | Ideas and cross-check only |
| QuestieDB data (Forever corrections, drop rates, traces) | Same terms; data partly Wowhead-scraped | Cross-check only, never ship |
| RXPGuides (code and DB tables) | **CC BY-NC-SA 4.0** (`LICENSE`), not GPL-compatible | Ideas only, no numbers or tables |
| Shortest Path Forever, Tweaks Forever, SkillUp Forever | GPL-3.0-or-later (LICENSE + THIRD_PARTY.md) | Portable with credit. SPF route timetable derived from CMaNGOS classic-db (GPL-3.0) and Blizzard DB2; flight times from InFlight (MIT); zone ranges from warcraft.wiki.gg (CC BY-SA) |
| Zone Info: Forever | No licence | Ideas only |
| OneForAll - Forever | GPL-3.0-or-later | Portable. Inside it: Gear Judge stat curves **MIT** (Supersharpie), Skyborne ley-line spots **MIT** (tr0tsky), zone crossings **GPL-3** (Carbonite), flight masters from QuestieDB (avoid) |
| ForeverPlus | All Rights Reserved | Ideas only |
| GearQuest Forever | No licence | Ideas only |
| HandyNotes_WoWForever | No licence | Facts (NPC IDs) only after checking them ourselves |
| MacQuest/SpeedLevel, Quest Triage, VoidQuest, Flow | GPL-3.0 | Portable with credit |
| QuestTargetHelper, Trailwarden, Auxy Recap, QuestBeacon | MIT | Portable with credit |
| Level Time | Apache-2.0 | Portable with credit (keep NOTICE) |
| RutaMisiones, QuestWorth | No licence | Ideas only |

---

## 1. Questie (Forever build) and QuestieDB, code level

Paths: Q = `downloads\Questie`, DB = `downloads\QuestieDB`, F = `DB\src\corrections\Forever`.

### 1.1 Objective tracking
- **Objectives** (`Q\Database\QuestieDB.lua:1620-1814`): DB slots become typed objectives (monster, object, item,
  reputation, kill-credit list, spell via source item). `triggerEnd` becomes an "event" objective at its coordinates;
  required source items become extra objectives.
- **Matching to the log** (`QuestieQuest.lua:1438-1517`): by index against `C_QuestLog.GetQuestObjectives`
  (QuestLogDocumentation).
- **Spawns per objective** (`QuestieQuestPrivates.lua`): monsters = spawns + patrol waypoints (none for rares);
  kill-credit = every ID in the list; items = each source's spawns (`npcDrops` loot icon, `objectDrops` object icon,
  `vendors` friendly only).
- **Drop rates** (`dropDB.lua:126-174`): manual fix > cmangos > Wowhead; on Forever both come from one table
  (2,032 items, 19,182 NPC→rate pairs). Shown as `[N%]` on the NPC tooltip's objective line.
- **"Done"** (`QuestieQuest.lua:1520-1557`):
  ```
  if row.numFulfilled == row.numRequired == 1 and not row.finished then treat as 0/1   -- Forever type-14 rows
  done = (needed > 0 and have == needed) or (row.finished and (needed == 0 or nil))
  ```
  A done objective drops its map icons but keeps its tooltip entry. Quest complete = client says so, or all mapped
  objectives done, the quest isn't sequenced and no client row is unfinished.
- **Type-14 (criteria-tree) objectives** are only detected; `CRITERIA_UPDATE` (AchievementInfoDocumentation) just
  schedules a log rescan.
- **Tracker "nearest"** (`DistanceUtils.lua:18-55,113-147`): complete → nearest finisher, else min distance over
  unfinished objective spawns; another instance costs 500000 + 100·d; sort = same continent, distance, level;
  re-sorted on a 5 s ticker only when the player has moved.

### 1.2 Tooltip quest lines
- Lookup keyed `m_<npc>`, `o_<object>`, `i_<item>` → `"<questID> <objIndex>"` (`Tooltip.lua:63-103`). NPC ID from the
  GUID's 6th field; objects by name, filtered to spawns in the player's zone or parent when ambiguous (`:306-338`).
- Content: nothing in groups over 6; "starts / finishes" titles sorted by level; objectives of active quests only,
  finished ones recoloured not hidden; drop rate appended.
- Secrets: Unit post-call returns at once inside a Forever instance or when the GUID is secret; Object post-call needs
  primary tooltip data and a non-secret title.
- **Rules:** the `TooltipDataProcessor` post-call part is allowed; its `GameTooltip:HookScript` calls and AceComm
  party sync are not.

### 1.3 Map and minimap icon logic (ideas for our MapPins overlay)
- **Icon choice** (`QuestieLib.lua:885-904`): event → PvP → required level above you (grey) → repeatable → trivial
  (`player - level > trivialRange`, grey) → available. Turn-ins use the same order with "complete" icons.
- **Declutter** (`AvailableQuests.lua:217-296,743-866`; `QuestieQuest.lua:1034-1077,1132-1368`):
  - starters: skip a spawn within 28 zone-% (x weighted ×1.5) of one already placed; at most 30 icons per quest;
    hostile starters skipped; dungeon starters drawn at the entrance; patrolling NPCs at their first waypoint;
  - objectives: centre = zone centre (single-zone objective) or nearest starter/finisher; sort spawns by distance from
    it, cap 1500, skip one within 2 % of an already placed spawn on the same map.
- **Minimap fade** (`QuestieMap.lua:217-328,742-784`, 0.1 s coroutine, 50 icons per tick): fully visible inside
  200 yd, linear fade from 200 to 300 yd, half alpha when sitting on the player, 0.3 for de-emphasised quests.
- **Draw order**: turn-ins above pickups above objectives (frame level 2016 + type rank).
- **Rules:** Questie draws through HereBeDragons-Pins, i.e. `AddDataProvider`/`AcquirePin` (forbidden). Only the
  selection, spacing and fade rules are useful to us.

### 1.4 Availability, in detail
- **Level window** (`IsLevelRequirementFulfilled.lua:21-75`): upper bound is always your level (no "+N" option);
  lower = player − `C_QuestLog.GetTrivialRange()` (QuestLogDocumentation). Scaling quests use max(player, min level).
  A child passes if its parent is active. Cached, cleared on level-up.
- **Race/class masks** (`QuestiePlayer.lua:30-40,86-96`): `mask % (2*flag) >= flag` on doubles, exact for the
  Skyborne bits 2^32/2^33. Our `QuestLookup.lua:35-36,214-241` already does the same.
- **Prerequisites** (`QuestieDB.lua:643-690,810-822`):
  ```
  if preSingle: ok = any(preSingle, completed)            -- OR
  else: ok = all(preGroup, q -> completed(q) or any(exclusiveTo(q), completed))  -- AND, partner substitutes
        (negative ID = that exact quest, no substitute)
  being in the log never counts
  ```
- **Exclusions**: exclusiveTo completed or in log → hide; nextQuestInChain completed or in log → hide;
  disabledByQuest in log → hide.
- **Breadcrumbs** (`:880-907`): hide a breadcrumb once its target is completed or in the log; hide the target **while**
  a breadcrumb is in the log. (Its "abandon the target" option and chat warning break our rules.)
- **Reputation** (`QuestieReputation.lua:156-202`): min = value ≥ required, max = value < required; undiscovered
  faction = 0 (or −36000 if it starts hostile). It calls `ExpandFactionHeader(0)`, which changes the player's UI:
  avoid. Use `C_Reputation.GetFactionDataByID` (ReputationInfoDocumentation).
- **Skills**: `C_SkillInfo` rank ≥ required (SkillInfoDocumentation).
- **Holidays**: hard-coded date windows vs `C_DateAndTime.GetCurrentCalendarTime`; Darkmoon never active on Forever.
  It writes `calendarShowDarkmoon` and calls `C_Calendar.SetMonth`: avoid.
- Globals Questie uses that are **not in uisrc2 docs**: `GetQuestGreenRange`, `IsPlayerSpell`, `IsSpellKnown`,
  `HaveQuestData`, `GetQuestID`, global `IsQuestFlaggedCompleted`, `GetQuestLogRewardXP` (the last exists; Blizzard
  code calls it). Prefer `C_QuestLog.*` and `C_SpellBook.IsSpellKnown`.

### 1.5 Quest-starting item drops
Item field `startQuest` (Forever copy `F\legacy\itemStartFixes.lua`). On the map the item starter is expanded to its
dropping NPCs/objects and drawn with a "mob drop" available icon; NPC tooltips say "starts (via drop)"; the item's own
tooltip looks up `startQuest`. **Ours:** `LevelGuide\QuestDB.lua` encodes item givers (`i<id>`) but has no item →
drop-source data, so we can't place them.

### 1.6 Forever corrections layer
- Layers: raw → legacy → generated Wowhead base (960 quests, 3,535 NPCs, 8,261 items) → player traces (759 quests,
  1,593 NPCs) → authored (586 quest fixes, 243 in 95000-99999; NPC 265, object 114, item 47) → dynamic.
- Most-fixed fields: `preQuestSingle` 319, `objectives` 221, `nextQuestInChain` 154, `requiredRaces` 147,
  `exclusiveTo` 124, `requiredSkill` 90, `requiredSpell` 80, `requiredLevel` 62.
- **Forever facts to verify in game / on Wowhead Forever (cross-check list, not data to ship):**
  - quest 93928 "Of Mice and Milk" is blacklisted on Forever but is still in our `QuestDB.lua:3364`;
  - Shayla (NPC 2155) moved to about 40.5, 50.7 (ours 42.2, 51.3 at `QuestDB.lua:4216`);
  - Guard Parker 464 and Falfindel 4048 no longer patrol;
  - new prerequisite 98387 "Blackrock Blockade" gates 19 and 115; 98323 gates 291;
  - "Sign Me Up!" 95816/95819 are item-started and need 9000 reputation;
  - Camping 101 chains use `requiredSkill` plus 6-7-way `exclusiveTo`.
- **What our data lacks against it:** `exclusiveTo` (e.g. 324↔526, the six 95998 variants), AND-group completeness
  (19, 115, 291), reputation/skill gates, `nextQuestInChain`, `disabledBy`, blacklist status, patrol paths, item drop
  sources. Race masks match. Questie has 261 more 9xxxx quests than ours; ours has 65 Classic-range quests it lacks.

### 1.7 Leveling-speed features
- **Quest XP before accepting** (`QuestieXP.lua:59-106`): a game-mechanic formula, fine to re-implement:
  ```
  xp = baseXP * clamp(2*(questLevel - playerLevel) + 20, 1, 10) / 10
  round to 5/10/25/50 by size; × buffs (Forever sleeping bag "Well-Rested" spell 429959: +1% per stack),
  buffs ignored in combat or instances
  ```
  The per-quest base-XP table is QuestieDB data (not shippable); our `LevelGuide\QuestXP.lua` (forever-db) can feed it.
- **Journey "quests by zone"**: done / available / unobtainable per zone.

---

## 2. Shortest Path, Tweaks, SkillUp and Zone Info (Forever)

Versions are unchanged since `popular_qol_routes.md` (SPF 1.24.1, Tweaks 2.4.2, SkillUp 1.1.6, Zone Info 1.10.0).
New here is detail on parts that report didn't open.

### 2.1 SPF boat, zeppelin and tram timetable (GPL-3.0-or-later)
- **Data** (`Data\Routes.lua`): 13 routes from TaxiPathNode (build 1.60.1.70862), CMaNGOS transport model at 30 yd/s
  with 1 yd/s² acceleration, periods stretched onto CMaNGOS's sniffed periods; new Forever routes are estimates.
  Per route: period (247-486 s), stops `{dock, arrive, depart}` (about 60 s dwell), path frames.
- **Arithmetic** (`Transport\Model.lua`):
  ```
  phase = (GetServerTime() - epoch) mod P
  Visit(stop, phase): stay = (depart-arrive) mod P; since = (phase-arrive) mod P
     if since < stay: docked, leaves in stay-since
     else: arrives in (arrive-phase) mod P, leaves in that + stay
  RideTime(a,b) = (b.arrive - a.depart) mod P
  ```
- **Learning the epoch** (`Transport\Observer.lua`, `Model.lua:81-165`): while not on a taxi and moving ≥ 12 yd/s,
  project the player onto the route's path segments (within 40 yd) to get a phase; offsets `(now - phase) mod P` are
  clustered (±4 s); the largest cluster spanning ≥ 30 s with ≥ 10 samples gives the epoch. A route wins only with
  1.25× the runner-up's support. Anchors kept per realm for 6 h.
- **Use**: planner wait is exact when anchored, else P/2 and marked "estimated"; within 120 yd of a dock: "Boat to X
  arrives in 0:30"; on board: "Arriving at Y in 0:20".
- **APIs:** `GetServerTime` (SystemTimeDocumentation), `UnitPosition`, `UnitOnTaxi` (UnitDocumentation),
  `canaccessvalue` (FrameScriptDocumentation). **Rules:** maths fine; its chat print, addon-message sharing and map
  canvas route lines are not.
- **Ours:** `LevelGuide\Travel.lua:113-149` uses a fixed wait/ride per link.

### 2.2 SPF hazards (`Journey\Hazards.lua`)
- Zone whose minimum level ≥ yours + 4 costs ×4 (option); hostile town = enemy flight master with no own-faction
  flight master within 400 yd, a 150 yd circle costing ×6; hostile capital ×6; start/end zones exempt.
- Segment cost = 1 + (share inside town circles)×5 + (share inside avoided zones)×(factor−1), zone lookups cached on a
  64 yd grid; displayed time stays real.
- Per-leg notes from 32 yd samples: "Hostile town: Crossroads", "Crosses Duskwood (18-30)", "Avoids STV (30-45)".
- Replans on `PLAYER_LEVEL_UP` using the event's level (UnitLevel lags).
- **Ours:** `TravelPlan.lua:15-16` weights high zones; no hostile towns, no leg notes, no faction on flight masters.

### 2.3 SPF corpse run (`Journey\Corpse.lua`)
`C_DeathInfo.GetCorpseMapPosition` on the player's map, climbing parents to the continent. The corpse appears a moment
after release with no event, so after `PLAYER_DEAD/ALIVE/UNGHOST/ENTERING_WORLD/ZONE_CHANGED_NEW_AREA` it re-reads every
1 s up to 10 times; ETA = yards / live run speed. **Ours:** `LevelGuide.lua` `CorpseTarget` climbs two parents only,
no retry loop, no ETA.

### 2.4 SPF nearby services (`UI\Nearby.lua`, `Data\Services.lua`)
- Vendor groups by item class/subclass: arrows 6/2, bullets 6/3, bags 1, trade 7, reagents 5 or 15/1, gear 2/4.
- **Food and drink by item ID:** items whose use-spell has aura MOD_REGEN (84) = food, MOD_POWER_REGEN (85) = drink,
  one trigger-spell hop; language-independent, includes Forever items. Generated from Blizzard DB2 (GPL file).
- Ranking: nearest few by straight line, then cheapest by journey time, computed on click.
- **Ours:** Landmarks kinds are repair/vendor/food/inn/mail/bank from visited places, straight-line nearest;
  FoodCheck matches tooltip "restores" text (`FoodCheck.lua:18-27`), which is English-only.

### 2.5 Tweaks campsites: the missing spell IDs (GPL-3.0-or-later, Blizzard data)
| Spell | Meaning |
|---|---|
| 1229741 | Camp Benefits (1 h) |
| 1283391 | Campfire Nearby |
| 1229451 | Camp Tent rested boost ("after 30 s resting near the tent", once per hour) |
| 1230587 / 1230172 / 1230653 / 1230124 / 1230098 / 1229513 / 1230164 / 1229519 / 1229718 | Mana Well / Sharpening Wheel / Enchanted Lute / First Aid Kit / Fish Bowl / Incense Candle / Lodestone / Camp Chair / Faction Banner |
| 1307227 / 1307252 / 1307237 | Basic / Journeyman / Expert campfire placement (objects 529161 / 630660 / 650137) |

- Remaining time = `expirationTime - GetTime()`; read only when `not InCombatLockdown() and not
  C_Secrets.ShouldAurasBeSecret()` (SecretPredicateAPIDocumentation). The server scales aura values by level, so show
  live `points`.
- Campfire position remembered from your own `UNIT_SPELLCAST_SUCCEEDED` of a placement spell or the Camp Benefits aura
  appearing; direction = one of 8 sectors from `atan2 - GetPlayerFacing()`, within 120 yd.
- This answers the open "[unverified] spell IDs" in `forever_improvements_2026-11-10.md` item 4 (still confirm in game).
- **Rules:** its tooltip post-call and `UIErrorsFrame:AddMessage` are frame writes; our version stays in our window.

### 2.6 Smaller Tweaks items
- **Junk value** (`Bags\Junk.lua:66-93`): skip locked, `hasNoValue`, price 0 and refundable stacks
  (`C_Container.GetContainerItemPurchaseInfo(...).refundSeconds > 0`); `quality == nil` = info pending. BagCheck
  (`BagCheck.lua:46-66`) checks none of these.
- **Rare alerts:** same as RareWatch except a rescan of nameplates and vignettes on `PLAYER_REGEN_ENABLED`.
- **Pull warning** (groups only): `UnitThreatSituation("player","target") == 1` warn once; low value solo.
- **Zone ranges:** wiki ranges plus Zephras Isle 3-12, Riverglades 36-44; `C_Map.GetMapLevels` wins when it answers.

### 2.7 Zone Info: Forever
Nothing beyond `popular_quests_maps.md`; per-zone `minFish` and transport text are hand-kept (no licence).

---

## 3. OneForAll, ForeverPlus, GearQuest, HandyNotes_WoWForever

Same versions as before (OFA 6.2.1, ForeverPlus 1.0.7, GearQuest 1.1.1, HandyNotes WoW Forever v3).

### 3.1 Our ZoneLevels probably shows nothing on Forever
OFA's `Data\ZoneLevels.lua` header states `C_Map.GetMapLevels` is empty on Forever (Tweaks also ships a fallback).
Our `ZoneLevels\ZoneLevels.lua:21` reads only that API, so the "too high by 3" warning likely never fires. Separately,
`ZoneLevels.lua:61` writes to `UIErrorsFrame` when the hub isn't loaded: a Blizzard-frame write against rule 3.
Check first: `/dump C_Map.GetMapLevels(1438)`.

### 3.2 Leveling stat curves (OFA Gear Planner; weights are Gear Judge, MIT)
- Per class/spec a level-60 set plus a named curve of `{level, weights}` keyframes for 1-59 (Leveling, Leveling_Tank,
  Leveling_Healer, Leveling_Caster…). Ratings are weighted per 1 % (hit 10, crit 14, dodge 12, parry 20…).
- Score: interpolate the curve at your level (clamped, values < 0.02 dropped); Forever has one hit and one crit
  rating, so each counts at the higher of melee/spell weight; spell power at the higher of damage/healing; off-hand
  DPS ×0.5; weapon speed × a speed weight. Rings/trinkets compare against the weaker worn one; a two-hander against
  main + off hand.
- Shape: crit/hit weights rise steeply with level; Stamina, hp5 and Spirit peak mid-levels.
- **Ours:** `ItemAdvisor.lua:212-250` fixed profiles, one ×1.5 Stamina/Armor leveling bias.

### 3.3 GearQuest per-slot "hunts" (ideas only)
Rows `{item, slot, minLevel, maxLevel, rank, spec, faction}`; scores generated offline (stamina/health ×3 and
armour/int/spirit ×2 while leveling, × armour-class multiplier); items missing on Forever dropped by a tooltip audit.
Ranking: wearable at your level → curated rank, else score, else `(ilvl − worn ilvl)×10 + source bonus (quest 2;
boss/vendor/profession 1) − 500 for a lower armour type unless +8 ilvl`; top 3 per slot.

### 3.4 Bags-full helper (OFA `QoL.lua:2425-2472`, GPL)
Candidates = cheapest stacks (price × count) in normal bags, never: quest items
(`C_Container.GetContainerItemQuestInfo`), profession tools, hearthstone, fishing poles (2/20), library books,
recipes (9), quest-class (12), set items, epic+, locked or unsellable. Loot side: quest items and unsellable loot
always worth taking. (OFA's destroy click is automation; we would only hint.)

### 3.5 Camping and rested XP
Camp Tent (LW 20, Light Leather ×5), Tanning Rack and Sewing Machine give up to 5 % of a level as rested XP; the
boost leaves a one-hour lockout ("Boosted Rest", spell 1229451 per ForeverPlus/Tweaks; confirm the aura name in game).
Engineering Reagent Bot (20) sells reagents, Repair Bot (140) repairs: field resupply. APIs: `GetRestState`,
`GetXPExhaustion` (PlayerScriptDocumentation), `UPDATE_EXHAUSTION`, `PLAYER_UPDATE_RESTING` (UnitDocumentation).

### 3.6 Consumable reminders (OFA GPL, ForeverPlus ARR idea)
Player ticks which buffs to keep (Well Fed, elixirs, scrolls; oils/stones/poisons via `GetWeaponEnchantInfo`); keyed by
spell/item ID because Forever renamed items; warn at N minutes left, after login for buffs that ran out offline;
snooze until the buff returns; an aura hidden in combat counts as "unknown", never "gone".

### 3.7 Ammo rule (ForeverPlus, idea)
Hunters only; count every ammo the equipped weapon fires; warn once per restock, re-arm above threshold; stay quiet a
few seconds after entering the world while bags arrive.

### 3.8 Forever rares (HandyNotes_WoWForever, no licence: facts only after our own check)
Zephras Isle (2521): 7 rares with NPC IDs, coordinates and loot (Mystmane, Den'dralass, Fernfeather, Slydris, The Lost
One, Tel'daeor the Stormspeaker, Galemender Delanea). Mount Hyjal (2482): Pexmit (266901), six recipes. Riverglades and
Shen'dralas empty. No completion or respawn data. RareWatch ships no rare table today.

### 3.9 OFA spot data (MIT / GPL)
About 110 Alliance ley-line spots (Skyborne, MIT); zone crossing points `{map, x, y, target map}` (Carbonite GPL-3);
40 library books with quest ID, item ID, zone, coordinates (OFA's own, GPL) and a 120 yd nearby alert by world distance.

### 3.10 Facts
`UnitQuestTrivialLevelRange(unit)` exists (UnitDocumentation) and can double-check our grey level. `IsPlayerSpell`,
`GetQuestDifficultyColor`, `GetCreatureDifficultyColor` are not in the docs: use `C_SpellBook.IsSpellKnown` and our own
colour maths. Mail can't cross rulesets (`C_GameRules.GetCurrentGameModeRecordID`).

---

## 4. RestedXP free engine, beyond the guide (CC BY-NC-SA: ideas only)

### 4.1 What is switched off on Forever
- **ItemUpgrades is off** (`ItemUpgrades.lua:6` returns unless Classic/TBC/Cata); `DB\forever\StatWeights.lua` is a
  copy of Classic's and unused. So RXP shows no upgrade EP on Forever; the quest-reward pick only marks best sell price.
- **Rares are off** (`DB\forever\rares.lua:7-10`), raid markers off, `.xpto60` code is Classic 55-60 leftovers.
- Forever DB files are Classic copies except `db.lua` (Zephras Isle 2521, Hall of Thanes "HOT" 16919) and
  `quest.lua` `questCompleteItems` (quest → item you must **use** to finish it, e.g. Call of Earth → Earth Sapta).

### 4.2 Item scoring (inert on Forever, still useful as ideas)
- Weights per class/spec **per level bracket** (1-9, 10-19 … 50-60), rebuilt on `PLAYER_LEVEL_UP`.
- Item filter: required level ≤ player + 5. Stats from `GetItemStats` plus tooltip text up to the set line (set
  bonuses ignored). Weapons: item total + DPS×weight + speed×per-slot weight; one-handers scored for both hands.
- Rings/trinkets: compared against both worn items, best ratio reported. Empty slot valued as ratio 10 in the reward
  pick. No unique handling.
- **AH scan** uses `QueryAuctionItems`, which is not in the uisrc2 docs; only `C_AuctionHouse.SendBrowseQuery` exists
  (AuctionHouseDocumentation). "Best per gold" pick per slot = (score × ratio) ÷ price.

### 4.3 Inventory manager
Junk = (soul shards over a cap) or (not hearthstone) and (discard list says so, else grey). Cheapest-to-drop formula
`(stackMax + count) × price / 2` is odd; use true value. Its delete-on-full and sell flows are automation (forbidden).
Read-only extra: `C_MerchantFrame.GetNumJunkItems()` (MerchantFrameDocumentation) counts what Blizzard treats as junk.

### 4.4 Level tracker
XP/h per finished level only; no time-to-level, no rested use. Split repair from `/played` maths. Its kill count is
added to mob XP by mistake (`LevelingTracker.lua:663-671`); don't copy. `/played` silencing replaces a Blizzard
function (forbidden).

### 4.5 Tips and targeting
Tips: drowning (no fatigue; we already cover both), low-HP emergency glows **on Blizzard buttons** (forbidden), dangerous
mobs (`MaxLevel ≥ player − 1` normal / `− 3` elite). Targeting matches nameplate **names** against the step's mob list;
QuestMobs' tooltip-objective approach is already better.

### 4.6 Other
- **Dungeon recommender** (`SettingsPanel.lua:4436-4519`): score = travel×0.7 + quest XP×1.2 + class loot×1.4 over
  0-3 ratings; recommend above 7. Hidden on Forever.
- Buy-amount maths: shortfall = wanted − owned, capped by vendor stock and by gold ÷ (cost ÷ bundle size). We'd show
  it, never buy.
- No pet-happiness, poison or reagent helpers.

---

## 5. New Forever addons since the last survey (GitHub/CurseForge, read as text)

Queries: GitHub repo search sorted by update (`forever wow addon pushed:>2026-11-08`, `forever leveling/xp/grind/quest
created:>2026-11-01`, `forever rested/rare/elite/boat/mob/route`, `topic:wow-forever`), cfwidget slugs, WebSearch,
foreverchanges.pro, mein-mmo, zockify, Blizzard forum thread 2403040, Kami-Labs. **Failed:** GitHub code search (401,
needs auth), reddit.com (blocked), cfwidget 404 for several guessed slugs, playnews.gg 403. About 150 newer
`wow-forever` repos were not listed (results truncated).

| Addon | Licence | What matters for leveling | Rules |
|---|---|---|---|
| **MacQuest / SpeedLevel** (Methodologist), Horde 1-60 beta | GPL-3.0 | Offline route builder with explicit maths (below), grind-spot ranking, death-skip and hearth maths, terrain A* arrow | Map pins via `AddDataProvider` and auto reward pick break ours; maths is fine |
| **Quest Triage** (tamuir) 0.5.3 | GPL-3.0 | "Best next step" cost model, slow-spot detection, denser-spot suggestion, fight check | Hooks a Blizzard mixin, HBD pins, auto-sell: ideas only in practice |
| **QuestTargetHelper** (BlakeDevGroup) | MIT | In-game probe facts (below) | Writes onto Blizzard nameplates |
| **Trailwarden** (CodeByNiko) 1.7.2 | MIT | Pickup ≤ +2 levels, observed-kill grind suggestion, cave-entrance waypoints (Fel Rock, Shadowthread Cave, Ban'ethil Barrow Den) | Mostly fine |
| **RutaMisiones** (VoltorDev) | none | Cheapest-insertion planner; 14 s per mob, 24 s per object, flat 6 min per boat | Ideas only |
| **VoidQuest** (bughatti) | GPL-3.0 | Nearest-quest follow with hysteresis, grey quests "keep / safe to abandon" | Nameplate writes, addon comms |
| **Level Time** (Noobygames) | Apache-2.0 | XP/h overall and last 15 min, rested share, kills/quests left | "Near deaths" reads health (secret on Forever) |
| **Auxy Recap** (Auxilias) | MIT | Per-level recap vs previous level | Fine |
| **QuestWorth** (Mhtsos901) 2.0.0 | none | Quest score = 0.40 reward (in kills of 5L+45) + 0.30 chain + 0.15 class fit + 0.15 hub density | Ideas only |
| **QuestBeacon** (LEDRGB) | MIT | Nearest unfinished objective spawn; reached at 6 yd (object) / 20 yd (mob), then suppressed 5 min | Nameplate glow |
| Flow, Questify | GPL-3.0 | Route arrows | Heavy automation |
| Forever Leveling Guide (CurseForge, 35k downloads), 4Ever Leveling (7.6k; "Campfire Buffs" catalogue of 38 camp kits) | not stated | Source not read | n/a |

### 5.1 MacQuest maths (GPL-3.0; `tools\build_route.py`, `tools\tricks.py`, `Pathing.lua`)
```
mobXP(L, M):  base = 5L + 45
   M > L:  base * (1 + 0.05 * min(M-L, 4))
   M <= L: base * (1 - (L-M)/zeroDiff(L))     zeroDiff: <=7:5 <=9:6 <=11:7 <=15:8 <=19:9 <=29:11 <=39:12 <=44:13 <=49:14 <=54:15 else 16
killTime(L, M) = 14 * (1 + 0.15*(M-L)) + 6  seconds
grind spot: non-elite mobs L-4..L+1 in 4 yd cells (neighbours count 0.5); density = min(1, n/14)
   xph = mobXP/killTime * density * 3600; with travel: xph * 1200/(1200 + travelSeconds)
drop a quest when its XP/h < 0.65 * nearby grind XP/h
   questRate = (questXP*levelFactor + kills*mobXP*0.6) / seconds
death-skip (L <= 20): cost = 45 s + 21 s per level above 10 (res sickness) + walk from graveyard;
   take it only if it saves >= 75 s (L<=10) or >= 135 s (11-20)
hearth: cooldown 3600 s, cast 30 s, needs to save >= 180 s; a zone change counts 420 s
arrow: A* on a 96x96 grid per map, cell costs ground 1, rough 1.35, blocked 60; cells you've walked cost 0.6
```

### 5.2 Quest Triage rules (GPL-3.0; `Core.lua`)
```
slow spot: window = min(time in area, 900 s), no verdict before 300 s; slow if objectiveGains*240 < window
denser spot: suggest an area within 2000 yd whose spawn density >= max(1.5*here, here+3)
fight check: skull/boss leave; elite group; +3 very risky; +2 risky; +1 tougher; rare yellow; "drink first" if mana < 60%
two deaths on a quest at your level -> move it to Later; quests > +2 levels -> Later until level-2
repair: urgent at 0%, reminder 1-24%, below 50% before a quest 2+ levels above you
hearth tip: at an inn (60 yd) while bound > 1000 yd away
```

### 5.3 Probe facts (QuestTargetHelper `Docs\ProbeFindings.md`, build 70790, third-party measurement)
- Registering `COMBAT_LOG_EVENT_UNFILTERED` → ADDON_ACTION_FORBIDDEN (matches our rule).
- **`UNIT_COMBAT` amounts are secret in combat**: settles fact 19's conflict in favour of the API docs.
- `UnitHealth`/`UnitHealthMax` secret everywhere; `UnitGUID`, `UnitName`, `UnitCanAttack` plain in combat.
- `C_QuestLog.UnitIsRelatedToActiveQuest` works in combat; `C_TooltipInfo.GetUnit` quest lines plain (type 17 title,
  8 objective). In dungeons nameplates, names, tooltips and IDs are hidden.

### 5.4 New game facts (9-10 November hotfixes)
Respawn changes (Ivar the Foul faster, Ferocitas faster, Malduko Cloudcrush slower); Young Diemetradons at 51-52; quest
items for Croaky's Head, Elmpaw's Head and The Monster Surfaces now shared with the party; Lonebrow's Journal moved and
respawns faster; no mounting in Stratholme; fewer players per layer in busy zones. No change to rested XP, boats,
hearth or Legacy. Sources: https://us.forums.blizzard.com/en/wow/t/2403040 ,
https://mein-mmo.de/en/wow-forever-hotfixes-from-november-10-2026-patch-notes-with-adjustments-for-classes-and-dungeons,1595768/ ,
https://foreverchanges.pro/patch-notes . MacQuest notes QuestieDB has no Riverglades data yet and ~870 new quests lack
XP figures.

---

## 6. Ranked improvements for our helpers

Ranked by leveling gain for a solo Alliance player ÷ (effort + risk). Size: S < 1 day, M a few days, L a week+.
All are read-only, in our own frames, no hooks, no canvas pins, no combat-log events, `Safe()` on every client value.

### 1. ZoneLevels: fallback zone ranges, and drop the UIErrorsFrame write (S)
- **Why:** `C_Map.GetMapLevels` is reported empty on Forever (OFA, Tweaks); ours reads only it (`ZoneLevels.lua:21`),
  so the warning likely never fires. `:61` writes into `UIErrorsFrame` (rule 3).
- **Algorithm:** `low, high = API(mapID)`; if nil, look up our own table by Classic 14xx ID (and name), then the parent
  map. Add Zephras Isle 2521 (3-12), Riverglades 2548 (36-44), Mount Hyjal 2482 (60). Replace `:61` with a hub alert
  or our own small frame.
- **Data:** Classic ranges are common knowledge; Tweaks' table is GPL (wiki ranges are CC BY-SA, so write our own).
- **Feeds:** DeathNotes zone-danger warning (#9), TravelPlan's high-zone weighting.

### 2. LevelGuide: exclusive groups, breadcrumbs and Forever data audit (M)
- **Why:** `QuestLookup.lua` has no exclusivity, so `BuildRoute` can pool both 324 and 526, or all six 95998 variants;
  breadcrumbs are treated as "never needed" (`QuestLookup.lua:421`); 93928 (blacklisted on Forever) is still routed.
- **Algorithm:**
  ```
  hidden(q) = any(exclusive(q), p -> done(p) or inLog(p)) or done/inLog(nextInChain(q)) or inLog(disabledBy(q))
  AND-group entry e satisfied if done(e) or any(exclusive(e), done)
  breadcrumb b: drop once target done or in log; target pickup waits while b is in the log (never abandon)
  ```
  Plus an offline `tools\` audit script comparing `QuestDB.lua`/`Prereqs.lua` with a local QuestieDB checkout and
  printing differences to verify by hand (19/115/291 AND groups, 98387, 98323, Shayla, 93928, 261 missing 9xxxx).
- **Data:** an `x` (exclusive) and `rep`/`skill` field in our forever-db generator; QuestieDB used only to find gaps.
- **APIs:** `C_QuestLog.IsQuestFlaggedCompleted`, `C_Reputation.GetFactionDataByID`, `C_SkillInfo` (all in docs);
  never `ExpandFactionHeader`.

### 3. ForeverHub/LevelLog/RestGuard: kills to level, rested in kills, mob XP on target (S)
- **Algorithm:**
  ```
  killXP samples = LevelLog's kill deltas (rested part removed via GetXPExhaustion before/after)
  killsLeft = ceil(max(0, xpToLevel - restedBonusLeft) / median(last 10 killXP))   -- rested doubles kills
  restedKills = GetXPExhaustion() / median(killXP)  -> "Rested covers ~38 kills (~25 min)"
  target line: mobXP(L, UnitLevel("target"), elite) from Planner (5L+45 base, zeroDiff table) when not secret
  ```
  Active clock (stops 180 s after the last move/fight/XP) from XPForever (MIT) already proposed; reuse it here.
- **APIs:** `UnitXP`, `UnitXPMax`, `GetXPExhaustion` (PlayerScriptDocumentation), `UPDATE_EXHAUSTION`,
  `UnitClassification`, `UnitLevel` (UnitDocumentation).
- **Source:** MacQuest (GPL-3.0) maths, our `LevelGuide\Planner.lua` (Polestar, GPL-3.0-only), Level Time idea.

### 4. RestGuard + FoodCheck: camp and tent block with the now-known spell IDs (S)
- **Algorithm:** out of combat and when `C_Secrets.ShouldAurasBeSecret()` is false, read
  `C_UnitAuras.GetPlayerAuraBySpellID` for 1229741 (Camp Benefits, time left), 1283391 (campfire nearby) and 1229451
  (tent boost: "Tent rest ready" or "again in mm:ss"). Remember the campfire from your own `UNIT_SPELLCAST_SUCCEEDED`
  of 1307227/1307252/1307237 and show "Campfire 40 yd behind you" (8 sectors from `GetPlayerFacing`). Show
  `GetRestState()` factor.
- **Data:** Tweaks `Data\CampBenefits.lua` (GPL-3.0-or-later, Blizzard spell data). Confirm IDs in game.
- **Rule note:** no tooltip post-call or UIErrorsFrame line; our side panel only.

### 5. LevelGuide travel: real boat departures (M; L for mid-route fitting)
- **Algorithm:** ship per route period P and stop offsets (from SPF `Data\Routes.lua`, GPL-3.0-or-later, credit
  CMaNGOS). Learn the epoch simply: near a dock's boarding point, not on taxi, then ≥ 12 yd/s for ≥ 10 s moving away
  → `epoch = now - stop.depart`; landing (speed < 2 yd/s within 40 yd of the next dock) → `epoch = now - next.arrive`;
  average when within 8 s. Store `{epoch, seen=GetServerTime()}` per realm, expire 6 h. Planner uses `Visit()` when
  anchored, else P/2 marked "~". Within 120 yd of a dock, our window: "Boat to Rut'theran: docked, leaves 0:42, then
  6:30".
- **Replaces:** fixed wait/ride in `Travel.lua:113-149`.

### 6. ItemAdvisor: weights that follow your level (M)
- **Algorithm:** per class/role keyframe curves `{level, weights}` interpolated at your level; ratings per 1 %; one hit
  and one crit at the higher of melee/spell weight; spell power at the higher of damage/healing; optional weapon speed
  weight; rings/trinkets name **which** worn item they replace (the weaker); rebuild on `PLAYER_LEVEL_UP` and talent
  change. Keep our role detection.
- **Data:** Sharpie's Gear Judge (Forever Edition) 3.2.13, MIT, taken from its own source with credit.
- **APIs:** `C_Item.GetItemStats` (ItemDocumentation), `C_TooltipInfo.GetItemByID`.

### 7. BagCheck: "bags full, drop this" hint and correct junk value (S)
- **Algorithm:** junk value skips locked, `hasNoValue`, price 0, refundable (`GetContainerItemPurchaseInfo`) stacks;
  `quality == nil` = pending. On ≤ N free slots or `LOOT_OPENED` with full bags: list the 3 cheapest stacks
  (price × count) excluding quest items (`GetContainerItemQuestInfo`), tools, hearthstone, fishing poles, books,
  recipes, quest-class, set and epic+; if loot is worth more: "Drop X (3s) to take Y (25s)". Per-character never-suggest
  list edited in our window. Never deletes.
- **Source:** OFA (GPL) and Tweaks (GPL) rules; RXP's discard-list idea.

### 8. FoodCheck/SupplyWatch/Landmarks: food by ID, vendor kinds, consumable reminders (S then M)
- **S:** food/drink by item ID (SPF `Services.lua`, GPL, derived from Blizzard data) instead of English tooltip text;
  class/subclass as fallback. Hunter-only ammo warning, quiet 5 s after entering the world, "about N minutes of fighting
  left" from ammo used per combat minute.
- **S:** at `MERCHANT_SHOW` record what the merchant sells by group (arrows 6/2, bullets 6/3, bags 1, reagents 5,
  food/drink by ID) → new Landmarks kinds; SupplyWatch says "Nearest arrow vendor: X, ~2 min" (TravelPlan seconds).
- **M:** opt-in consumable reminders (Well Fed, elixirs, scrolls, weapon oils via `GetWeaponEnchantInfo`), keyed by
  ID, warn at 3 min or when gone, after login for ones that expired offline, hidden-in-combat counts as unknown.

### 9. DeathNotes: danger before you die there (S)
- **Algorithm:** on entering a zone more than 3 levels above your level (needs #1), one alert; on mouseover or a new
  nameplate of an elite/rare-elite ≥ 2 levels above you, warn once per GUID; Quest Triage's fight table for wording
  (+1 tougher, +2 risky, +3 very risky, elite = group). Health is secret, so no health reads.
- **APIs:** `UnitClassification`, `UnitLevel`, `UnitGUID` (plain in combat per probe), `NAME_PLATE_UNIT_ADDED`,
  `UPDATE_MOUSEOVER_UNIT`.

### 10. LevelGuide: corpse run and death-skip hint (S)
- **Corpse:** climb parents to the continent, re-read `GetCorpseMapPosition` every 1 s up to 10 times after death/zone
  events, show "~1:10 to corpse" from yards / run speed; nearest spirit healer from `C_DeathInfo.GetGraveyardsForMap`
  (DeathInfoDocumentation) when released.
- **Death-skip hint (≤ 20):** when the next step is far and the nearest graveyard is near it, show "Dying here saves
  ~N s" only if saving ≥ 75 s (≤ 10) / 135 s (11-20) after 45 s + 21 s per level above 10 sickness + graveyard walk.
  Information only. Source: MacQuest maths (GPL-3.0).

### 11. LevelGuide: XP for unaccepted quests and a grind-vs-quest check (M)
- **Algorithm:** pickups get `xp = baseXP * clamp(2*(qLevel - L) + 20, 1, 10)/10` (rounded) from our `QuestXP.lua`, so
  `X.XPPerSecond` stops scoring pickups as 0 (`LevelGuide.lua:2101-2106`). Flag a step "slow" when its XP/s is below
  0.65 × the kill XP/s LevelLog measures for you here. Slow-spot card after 300 s in a work area with
  `gains*240 < window` (Quest Triage).

### 12. QuestTracker/LevelGuide: type-14 progress guard and proximity sort (S/M)
- 1/1 with `finished = false` counts as 0/1 (`QuestTracker.lua:119-122`, `LevelGuide.lua` `X.CheckProgress`).
- Proximity sort: nearest unfinished objective camp (QuestDB camps) or ender if complete; same continent first;
  re-sort every 5 s only when moved.

### 13. MapPins: declutter, fade, objective camps (S/M)
- Spacing (skip within ~2 % of a placed pin on the same map), per-quest cap, draw order turn-in > pickup > objective,
  minimap fade 200-300 yd and half alpha on the player. Then an objective-camps layer for unfinished rows only, removed
  when `finished`. All on our own overlay.

### 14. RareWatch: Forever rares and after-combat rescan (S/M)
- Rescan nameplates and vignettes on `PLAYER_REGEN_ENABLED`.
- A small table of the 8 Forever rares (NPC ID, map, spawn points, loot) **verified by us** in game or on Wowhead
  Forever; respawn estimate = median gap between our own sightings on the layer; pins via MapPins.

### 15. Tooltips: giver lines by NPC ID, item-objective lines (S/M)
- Match QuestDB `n<id>` givers/enders against the parsed NPC ID (`Tooltips.lua:998`) instead of the name
  (`:1003-1004`). Item post-call: "Needed: <quest> 3/8" while that objective is unfinished.

### 16. Skyborne extras, library books, zone exits (S/M)
- Ley-line spots for Skyborne on MapPins and a "nearest ley line" waypoint (tr0tsky data, MIT).
- Library books nearby alert within 120 yd (OFA data, GPL; check the EPL points).
- "Nearest way to <next route zone>" from zone-crossing points (Carbonite via OFA, GPL-3).

### 17. LevelGuide: hostile-town avoidance and leg notes (S)
`faction` on Travel.lua flight masters; walk yards inside a hostile town circle ×6; notes "Crosses Duskwood (18-30)",
"Avoids STV". Replan on `PLAYER_LEVEL_UP` with the event's level. Source: SPF Hazards (GPL).

### 18. LevelLog: per-level XP/h, zone and rested share, best-run deltas (S)
XP/h per level = level XP ÷ level seconds; XP per `C_Map.GetBestMapForUnit` at each delta; rested share from
`GetXPExhaustion` drops; green/red delta against your fastest character (no `/played` silencing).

### Not taken
Map canvas pins (HBD, MacQuest, Quest Triage), tooltip and mixin hooks, nameplate writes (QuestTargetHelper, VoidQuest,
QuestBeacon), addon-message sharing (SPF timetables, VoidQuest), chat output, auto-sell/equip/reward pick, breadcrumb
auto-abandon, Darkmoon/calendar writes, `ExpandFactionHeader`, Wowhead drop rates and patrol paths as shipped data,
RXP numbers or tables (CC BY-NC-SA), anything from ForeverPlus, GearQuest, Zone Info, HandyNotes_WoWForever and
unlicensed addons beyond ideas.

## Summary

The biggest remaining wins are small. ZoneLevels very likely shows nothing on Forever and writes into a Blizzard
frame (#1). The route still lacks exclusive-group and breadcrumb rules, and carries at least one quest Forever removed
(#2). The hub doesn't yet turn XP into kills or rested XP into kills (#3). The camp/tent spell IDs that blocked the "XP
boosters" block are now known (#4). Real boat departures can come from GPL data with a simple anchor (#5), and
level-scaled stat weights are available under MIT (#6). RestedXP's item upgrades are switched off on Forever, so
ItemAdvisor has no competitor there. No new code was downloaded this round. Licences: RestedXP is CC BY-NC-SA (ideas
only); Questie/QuestieDB data is cross-check only; SPF, Tweaks, OneForAll, MacQuest and Quest Triage are GPL; Gear
Judge weights, ley-line spots, QuestTargetHelper and Trailwarden are MIT.
