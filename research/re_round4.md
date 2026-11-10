# Reverse-engineering round 4: loot, bags, gear, spells, maps, bars and new Forever addons (2026-11-10)

Scope: what our helpers can still learn from AtlasLoot Classic Forever, DungeonJournal, Baganator/Syndicator, Pawn,
GearQuest Forever, What's Training, Nova Spell Rank Checker, TomTom, Leatrix Plus/Maps and Glowing Bars, plus a new
sweep of Forever addons published since round 3. Earlier rounds (`popular_items_spells.md`, `popular_quests_maps.md`,
`popular_qol_routes.md`, `re_round3.md`, `forever_improvements_2026-11-10.md`) covered these at feature level; this
round goes to the logic, the data and the numbers, and checks each idea against what is already built. Nothing those
files already list is repeated unless this round adds the missing algorithm, number or correction.

## How this was done

- **Read only.** Quarantined copies under `...\scratchpad\downloads\` were read as text. Nothing was run, loaded,
  installed, built, decrypted or edited. Glowing Bars is a TypeScript/pnpm monorepo; no npm/pnpm command was run.
- **No new downloads.** New addons (section 7) were read as text through the GitHub API (repo search, file trees) and
  raw.githubusercontent.com, held in memory only. No zip was fetched, so no malware scan was needed this round.
  Paid content (Levelator beyond level 30) was not opened.
- **APIs** were checked in uisrc2's generated docs (`Blizzard_APIDocumentationGenerated__*.lua`; the prefix is dropped
  below). "Undocumented" means a global that Blizzard code or a live Forever addon calls but the docs don't list.
- **Rules applied to every idea:** no automation except AutoQuest's accept/turn-in (so no auto reward pick, train-all,
  auto-loot or auto-sell); no hooks of Blizzard functions (`hooksecurefunc`, `HookScript` on Blizzard frames); no
  writes into Blizzard tables or frames (no glows or textures created on Blizzard buttons, no OnUpdate replacement);
  no map canvas pins (`AddDataProvider`/`AcquirePin`); no `COMBAT_LOG_*` or CallbackEvent registration; no chat output.
- **Code is never copied.** Logic is in our own words with short pseudologic. GPL-3.0/MIT sources can be ported with
  credit in `NOTICE.md`; everything else is ideas only.
- **Text aimed at AI tools** was found and not followed: `AGENTS.md` in Baganator and Syndicator (asks AI tools not to
  use the repo as a reference; the owner had already decided to keep those two at feature level only, which this
  round does), `.agents/`, `.pi/`, `AGENTS.md` in the cjber repos, `.claude/` and `CLAUDE.md` in Firekeeper,
  `CLAUDE.md` in Full Mana Forever, `AGENTS.md` in Forever Quest Probe.

### Licence summary

| Source | Licence | Reuse |
|---|---|---|
| **What's Training** | **MIT** (`LICENSE:1`) | Code and data reusable with credit. **Corrects `popular_items_spells.md` §2 item 3**, which said WT data must not be copied. |
| AtlasLoot Classic Forever | GPLv2 text, no "or later" anywhere | **GPLv2-only: not combinable with our GPL-3.0.** Facts (IDs, boss names) only after our own check. |
| DungeonJournal (ForeverDungeonJournal 1.7.4) | No licence file | Facts only, re-verified by us |
| Baganator 846, Syndicator 290 | All Rights Reserved + AGENTS.md | Feature level and public-API facts only |
| Pawn 2.14.2 | CC BY-NC-ND 3.0 | Ideas only |
| GearQuest Forever 1.1.1 | None (ARR); data scraped from Wowhead | Ideas only |
| Nova Spell Rank Checker 1.63 | None (ARR); bundled LibCustomGlow MIT | Ideas only |
| TomTom 4.4.1 | All Rights Reserved. HereBeDragons: BSD. "Modern" arrow art: CC BY-NC 4.0. Classic arrow model: non-commercial | Ideas only; HBD reusable with credit; do not bundle the art |
| Leatrix Plus 1.60.29, Leatrix Maps 1.60.28 | No licence | Ideas only |
| **Glowing Bars** (vattiss) | **MIT** | Reusable with credit |
| **FastLoot** (ca33u) drop table | **GPL-3.0**; table generated from **cMaNGOS classic-db (GPL-3.0)** | **Shippable with credit** (first legal drop-rate source we have) |
| **LevelBiS Forever** (huffy-it) | GPL-3.0; item stats from Forever client tables; item *sources* from QuestieDB | Stats/approach usable; QuestieDB-derived sources: cross-check only (same caveat as `re_round3.md`) |
| XP Horizon (thejvfdev) | GPL-3.0-or-later | Portable with credit |
| Firekeeper, Full Mana Forever, Alts Forever, MobSpot, Chainlog, Forever Wayfinder, QuestDropRates | MIT | Portable with credit (Chainlog, Wayfinder and QuestDropRates bundle no data: they read QuestieDB at run time) |
| Legacy Forever, Adventure Guide Forever (cjber) | GPL-3.0-or-later; data from Forever client tables via wago.tools | Already studied in `forever_improvements_2026-11-10.md`; new details in §7 |

---

## 1. AtlasLoot Classic Forever and DungeonJournal vs Dungeons and Tooltips

### 1.1 AtlasLoot Classic Forever 1.3.4
- **What actually loads on Forever:** `AtlasLootClassic_DungeonsAndRaids_Forever.toc` loads `data.lua`, `data-tbc.lua`
  and `droprate.lua`; the separate `forever.lua` is a stale, emptier copy that is not loaded. Forever tables are at
  `data.lua:7523-7812`, each with `LevelRange {minEnter, recMin, recMax}` and per-boss `{position, itemID}` rows.
- **Data defects:** Ruins of Lordaeron's range `{10,13,18}` is a copy of Hall of Thanes (`data.lua:7568`); Krol'dok,
  Alcaz, Blackmaw and Shaper's Terrace have no loot; The Drowned City has 2 items (`:7740-7759`).
- **Item-source tooltip** uses a precomputed Classic DB (`AtlasLootClassic_Data\source.lua`) that holds **no item ID ≥
  260000**, so it names no source for any new Forever item. Classic dungeons use Classic Era ranges via
  `ReturnForGameVersion` (`AtlasLoot.lua:106`): don't use them for Forever.
- **Against ours** (`Dungeons\Data.lua`): Hall of Thanes 12 rows vs our 7; Ruins 20 + 2 Classic vs 7 (it adds a
  "Lordaeron Captain" boss we lack, `Data.lua:61`); Excavation Site 9 vs 6 (ours has Highland Horror, it doesn't);
  Dalaran 24 vs 7; Drowned City 2 vs 0 (it spells the first boss "Zun'Alai"; ours and DungeonJournal "Zul'Alai").
- **Name conflicts** on Forever items: 271207 is "Wispcloth Leggings" in AtlasLoot, "Rotmender's Leggings" in ours
  and DungeonJournal; 271214 "Frostbane Treads" vs "Rotmender's Treads". Forever renames items: check the client (#R12).
- **Rules:** tooltip falls back to `OnTooltipSetItem` hooks (not for us). Malware: version string on addon prefix
  `ATLASLOOT_F_MSG` (`AtlasLoot.lua:86,177-210`); `loadstring` only inside stock Ace3/CallbackHandler.

### 1.2 DungeonJournal 1.7.4
- **Level ranges disagree with ours on 15 of 35 dungeons** (theirs / ours): Stockade 24-32 / 25-29; Dalaran 28-33 /
  28-35; SM Armory 34-42 / 36-44; SM Cathedral 36-45 / 38-46; Uldaman 38-48 / 41-51; Zul'Farrak 43-50 / 44-54;
  Drowned City 35-40 / 35-42; Krol'dok 40-45 / 40-47; Alcaz 48-53 / 48-55; Sunken Temple 49-56 / 50-60; Maraudon
  45-52 / 46-55; DM East 55-60 / 54-60; DM West and North 57-60 / 56-60; UBRS 55-60 / 59-60. The game can settle these
  (#R4).
- **Bosses** (each with an `npcID`): Krol'dok 6 (ours 1, `Data.lua:386`), Alcaz 5 (ours 1), Blackmaw 8 (ours 1),
  Shaper's Terrace 8 (ours 4, two of which, Cinder and Snowtalon, it lacks), Drowned City 6 (adds Deathless Marrow,
  Gill, Min'loth; ours has Zin'aka, it doesn't). Loot rows: Krol'dok 19, Alcaz 14, Blackmaw 14 (all without ID),
  Shaper's 21; ours are empty for all four. Quests: 341 IDs, 210 not in ours (both factions); Drowned City 11 vs 0.
- **Entrances:** Ruins 63.4, 67.4 on 1420 (ours "approx" 62.0, 72.0); SM 82.6, 33.8 (ours approx 84.0, 30.0);
  Dalaran on Alterac Mountains 1416 at 8.5, 59.3 (ours Silverpine 69.3, 45.6). None for the four Forever-only
  dungeons above.
- **Item-source index** (`Systems\ItemSource.lua:39-119`), our words:
  ```
  for each boss loot item: offer(id, boss, rank 1; trash rank 2)
  for each quest reward/start/required item: offer(id, quest, rank 3 own faction or both, else 4)
  keep the lowest rank; IDs in shared loot -> "Shared loot - several dungeons"
  ```
- **Item-ID learner** (`Systems\ItemIdLearner.lua`): for rows with ID 0, probe IDs within ±60 of the dungeon's known
  new IDs, 40 per 0.25 s, `C_Item.DoesItemExistByID` (ItemDocumentation:146) then `RequestLoadItemDataByID` (:1710),
  `ITEM_DATA_LOAD_RESULT` (:1857), match by lower-cased `GetItemNameByID` (:846); also learns from loot, rolls, chat,
  bags and tooltips. (Already proposed in `popular_items_spells.md` §7 #7.)
- **Kill detection** (`Systems\RPGMode.lua:798-887`): `ENCOUNTER_END`, `BOSS_KILL`, plus `UNIT_DIED(guid)`
  (UnitDocumentation:4226) and `PARTY_KILL(attacker, target)` (:3726), and dead target/mouseover/nameplate checks;
  NPC ID from the GUID maps to a boss. Both events are not CallbackEvents but are `SecretWhenUnitIdentityRestricted`:
  read through `Safe()`. Its comment (`:818-821`) says some Forever bosses are known by name only or have a different
  live NPC ID, so learning IDs in game matters.
- **Group Finder activity IDs** (`Systems\LFGButton.lua:52-87`): RFC 798, WC 796, DM 799, SFK 800, BFD 801, Gnomer 803,
  RFK 804, SM GY 805, Library 829, Armory 827, Cathedral 828, RFD 806, Excavation 1981, Ruins 1982, Dalaran 1983, Hall
  of Thanes 1984. `C_LFGList.GetActivityInfoTable(id)` gives `minLevel`, `minLevelSuggestion`, `maxLevelSuggestion`,
  `fullName`, `mapID` (LFGListInfoDocumentation:184-199, 873-899; `AllowedWhenUntainted`). `GetAvailableActivities`
  is undocumented.
- **Rules:** `hooksecurefunc` on `WorldMapFrame.OnMapChanged` and `TakeTaxiNode` (`MapMarkers.lua:1316,2746`),
  GameTooltip `HookScript` (`ItemSource.lua:269-277`), LFG window driving and dropdown relabelling: not for us.
  Malware: throttled version broadcast on prefix `DJournalVer` every 10 s (`Systems\VersionCheck.lua:14-191`), prints
  to chat, watches `ADDON_ACTION_BLOCKED/FORBIDDEN` for diagnostics. No binaries besides art.
- **Already built in ours:** quest ticks (`Dungeons.lua:333-419`), `ENCOUNTER_END`/`BOSS_KILL` kills (`:886-905`),
  "you have it" and wear notes (`:678-722`), the drop line in Tooltips (`Tooltips.lua:619-662`).

## 2. Baganator and Syndicator vs ItemFinder, BagCheck and Tooltips (feature level only)

- **Places tracked:** bags incl. reagent bag and keyring; bank (on Forever the character bank tabs
  `Enum.BagIndex.CharacterBankTab_1..9` = 6..14, no bank bag slots, no warband bank); equipped gear and equipped bags;
  mail (inbox and outgoing mail to own characters); guild bank; auctions; currencies. Keyed per character and realm,
  filterable by connected realm and faction.
- **Forever facts:** detection by build 16000-19999; max bag size 42; 5 bag slots; mail expiry 30 days; keyring size
  from `GetKeyRingSize()` (undocumented) because the generic slot count doesn't report it; `Enum.BagIndex` Keyring −1,
  ReagentBag 5 (BagIndexConstantsDocumentation:27-41); `C_Bank.ShouldUsePlayerBagsInBank` (BankDocumentation:322).
- **Capture:** bag-update events, bank only while open; gear on `PLAYER_EQUIPMENT_CHANGED`; inbox on
  `MAIL_INBOX_UPDATE`; **outgoing mail via `hooksecurefunc` on SendMail/ReturnInboxItem** (breaks our rules; the
  hook-free version is #R14).
- **Search semantics** (ideas): space = AND, `|` = OR, `!`/`~` = NOT, `#word` forces a keyword; `>N`/`<N` item level;
  `Ng/s/c` value; keywords for binding, type, junk, upgrade, usable, my class, unique, quest, locked, refundable.
- **Junk rule** on Forever: Poor quality with a sell price, unless a junk plugin decides; BagCheck already matches
  (`BagCheck.lua:94-123`). Upgrade/junk/sort plugins answer true/false/nil-while-loading and refresh on equipment
  change and `PLAYER_LEVEL_UP`; our `ItemAdvisor_IsUpgrade` (`ItemAdvisor.lua:2283`) can play that role.
- **Ours:** ItemFinder still keys by **name** (`ItemFinder.lua:112-131`), scans `0..NUM_TOTAL_EQUIPPED_BAG_SLOTS` only
  (no keyring, `:134-140`), gear slots 1-19 only (equipped bags not counted, `:176-189`), no mail, no faction, text
  search (`:201-235`); Tooltips counts by name too (`Tooltips.lua:487-529`). No addon-message or chat sends found in
  either third-party addon.

## 3. Pawn and GearQuest Forever vs ItemAdvisor and WindowBadges

### 3.1 Pawn, beyond the earlier review
- **Forever rating constants** reuse Classic/TBC level-60 numbers (`ClassicHawsJon.lua:27-40`: hit 9.379 per 1 %,
  crit 8.5, haste 8.03, expertise 2.345, dodge/parry 9.44, block 6.9, defense 1.5). They are not Forever measurements.
  Ours (`ItemAdvisor.lua:192`) come from wowsims/forever and match the in-game "4 rating = 0.4 %" note (`:610`).
  **Keep ours.** Pawn's Forever scales are level-60 raid weights with Stamina 0.1 for DPS: useless for leveling.
- **Forever-only tooltip wordings** (game text, so facts): expertise "Equip: Reduces chance to be Dodged or Parried by
  N%." (`Localization.lua:557`); haste "Increases your attack speed by N%", "...attack speed and casting speed by N%",
  "Increases your casting speed by N%" (`:576-577,677`); combined hit/crit "...with all spells and attacks"
  (`:522,594`); es/pt/fr/ko/ru/zh have Forever-only overrides (`Localization.es.lua:971-986`). LevelBiS Forever's
  pipeline confirms from the client tables that Forever items carry only the generic hit/crit/haste stat types
  (31/32/36), never melee/ranged/spell variants.
- **Gap in our parser (verified):** `ParsePercentLine` (`ItemAdvisor.lua:513-540`) needs the label to reduce to
  hit/crit/haste/expertise/dodge/parry/block (`:193-196`). "your attack speed" reduces to "speed" because "attack" is a
  filler word (`:201`), so the line is dropped silently (not even marked unknown); "reduces chance to be dodged…"
  matches no pattern. No test covers either (`tests\test_itemadvisor_review.lua:146-151`,
  `test_itemadvisor_extra.lua:78`). Fix: #R2.
- **Best-ever-owned table** (`Pawn.lua:3984-4039`): best and second-best per inventory type per scale, from worn gear
  (no shirt, no trinkets) and every equipment-set item; second copy only if adjacent in the scan (`:3963-3979`);
  shields/held-in-off-hand merged into "off hand", robes into chest (`:3936-3939`); upgrade if `value > best × 1.005`
  (`:3760`); an empty second ring slot is always a "big upgrade" (`:3757`).
- **Weapon combo solver** (`:4066-4145`): max of best1H+second1H, best1H+bestOH, bestMH+best1H, bestMH+bestOH, gated
  by the scale's `IsOffHand`; 2H and 1H never compared (`:3618-3624`). Our pair finder (`ItemAdvisor.lua:1125-1185`)
  already does more.
- **Quest reward pick** (`PawnFindInterestingItems`, `:4267-4302`): usable upgrade → "upgrade" mark, which suppresses
  the vendor mark; **if any choice is a trinket, no vendor mark at all**; else highest *unit* sell price. Works in the
  quest log as well as at turn-in. Ours uses price × count (better for stacks) but shows the coin even when a choice
  can't be scored (#R15).
- **Random suffixes:** `PawnUnenchantItemLink` strips enchants and gems but keeps the suffix ID.
- **Rules:** `hooksecurefunc("QuestInfo_Display")` (`PawnUI.lua:2911`) and textures created on Blizzard reward buttons
  (`:2598`): not for us. Clean otherwise (`getfenv` only in VgerCore's hook helper).

### 3.2 GearQuest Forever 1.1.1
- **Leveling multipliers** (`_generated\ScoringWeights.generated.lua:7-17`): Stamina/health/hp5 ×3, armour/int/
  spirit/mp5/mana ×2 while level ≤ 60, i.e. always, even at 60 (its own header, `:3`); levels 1-9 use a shared
  profile (`Compare.lua:112-114`).
- **Armour-class multiplier** (`Compare.lua:165-201`, data `StatWeights.generated.lua:918+`): score × factor for a
  lower armour type, e.g. feral cloth 0.55, bear cloth 0.3, hunter cloth 0.85; hunters and warlocks exempt. Odd rules
  we should not copy: hunter/warlock Stamina weight forced to 0 (`:240-242`); hunter AP = max(AP, RAP) (`:236-238`).
- **Live rank** (`:565-592`): `(ilvl − worn)×10 + source (quest 2; boss/raid trash/vendor/profession 1) − 500 for a
  lower armour type unless ilvl ≥ preferred max + 8`. Stats: pipeline score, else `GetItemStats` merged with
  `C_Item.GetItemStats` taking the max per stat (`:397-435`), else tooltip (`:437-510`).
- **Random suffixes** (`:251-327`): `max` = Σ top value × weight; `expected` = Σ midpoint × weight × chance/100
  (default 10 %). Data header (`Data.Warrior.generated.lua:12-17,34-42`): match suffixes by client suffix ID, never by
  name (2,012 property rows share 45 names).
- **Quest rewards** are tied to quests only by prose ("Reward from the quest '…'"), no quest ID; a `questFaction`
  table gives faction-exclusive rewards.
- **Audit facts:** 9,579 hunt item IDs "ok" on Wowhead Forever, **1,414 missing (≈13 %)** and dropped; 2,985 IDs
  "New in Forever". Our own audit can use `C_Item.DoesItemExistByID` (ItemDocumentation:146).
- Clean: URLs only as a comment and a Discord string (`Log.lua:11558`), no network, binaries only art and MP3.

### 3.3 Ours
Already built: level curves, talent-based role, pair finder (`:1125-1185`), naming the ring/trinket replaced
(`:1290-1296`), reward glow and coin (`:2005-2047`). Missing: the Forever wordings, and a **suffix-safe equipment-set
check**: `InEquipmentSet` compares base item ID only (`:836-849`), so "X of the Monkey" is called KEEP when the set
holds "X of the Owl" (`:1218-1220`) (#R8). WindowBadges' trainer badges ("On your bars", "New", `:600-620`) have no
price or reputation hint.

## 4. What's Training and Nova Spell Rank Checker vs TrainerNotes and ReadyCheck

### 4.1 What's Training: the Forever ("Camelot") data, measured
Parsed `Classes\Camelot\*.lua` against `Classes\Vanilla\*.lua` (`id=…, cost=…` entries):

| Class | Forever rows | New IDs | Removed | Level moved | Cost changed | Forever base total |
|---|---|---|---|---|---|---|
| Druid | 184 | 17 | 13 | 1 | 150 | 206.1g |
| Hunter | 169 | 21 | 6 | 0 | 112 | 222.6g |
| Mage | 173 | 16 | 1 | 0 | 131 | 223.2g |
| Paladin | 147 | 21 | 10 | 3 | 113 | 206.4g |
| Priest | 203 | 32 | 6 | 0 | 130 | 210.9g |
| Rogue | 112 | 8 | 2 | 0 | 84 | 221.9g |
| Shaman | 165 | 13 | 6 | 2 | 117 | 207.2g |
| Warlock | 147 | 16 | 6 | 0 | 120 | 191.4g (Vanilla 137.5g) |
| Warrior | 101 | 3 | 0 | 1 | 83 | 204.8g |
| **Total** | **1,401** | **147** | **50** | **7** | **1,040** | |

Totals include faction/race-only rows and talent-gated ranks (111 Forever rows carry `requiredTalentId`, 93 in
Vanilla). Median per-rank cost ratio Forever/Vanilla: 1.00 at levels 10 and 20, 0.86 at 30 and 50, 0.94 at 60.

- **Level moves:** Shred 5221 22→20; Holy Shield 20927/20928 50→40 and 60→50; Righteous Fury 25780 16→10; Mana Tide
  17354/17359 48→38 and 58→48; Berserker Rage 18499 32→30.
- **Trainable without the talent on Forever:** Aimed Shot 19434 at 20, Divine Spirit 14752 at 30, Blessing of Kings
  20217 and Consecration 26573 at 20. **Cat Form 768 is no longer a trainer row.**
- New IDs in 1.2M-1.33M (warrior 1240193 starts the Slam rank list, `Warrior.lua:15`); Forever races 95/96 in quest
  spells; Incubus 713 as a warlock demon; Forever trainer factions 2740 (Alliance) and 2787 (Horde)
  (`TrainerFactions.lua:15-16`); rogues gain 1H Axes, shamans 2H Axes and 2H Maces (`Camelot\WeaponSkills.lua:3-5`;
  our `WEAPON_TYPES` already has them, `ItemAdvisor.lua:331,333`); Stormwind map coordinates shift because the map
  includes the Harbor (`:7-10`).
- **Pricing** (`Pricing.lua:54-56,90`): `pct = reaction ≥ 6 (Honored) and 10 or 0; price = floor((cost×(100−pct)+50)/100)`;
  demon tomes are never discounted on Forever (`TrainerFactions.lua:22-24`).
- **Known check** (`Utils.lua:340-359`): `IsSpellInSpellBook(id, Player, false) or IsSpellKnown(id, Player) or any later
  rank in the group is known` (SpellBookDocumentation:720,738).
- **Categories** (`DataBuilder.lua:99-137`), in order: known; ignored; talent missing; level too high (≤ L+2 = "next");
  all required IDs known → available, else "missing requirements". On `SPELLS_CHANGED` only learnable IDs are rechecked
  (`:140-145`, `WhatsTraining.lua:208`). 48 Forever class-quest spells with races, level, area and quest IDs
  (`Camelot\QuestSpells.lua:3`).
- **Rules:** train-all `BuyTrainerService` loop (`Forever\Trainer.lua:154`), `CastSpellByID` to open Beast Training
  (`Utils.lua:337`), spellbook `hooksecurefunc` (`WhatsTrainingUI.lua:223,258,274`), `SetParent(PlayerSpellsFrame)`
  (`Forever\SpellBook.lua:445`), `print` (`Trainer.lua:117`): none of that is taken. Clean: no addon messages, no
  loadstring.

### 4.2 Nova Spell Rank Checker
Highest rank per spell **name** from spellbook subtext digits (`NovaSpellRankChecker.lua:105-133`); line `:109` mixes
`and`/`or` without brackets, so a first rank of 0 compares nil (an error, not just a slip). Bars by button names,
macros via `GetMacroSpell`, `ContinueOnSpellLoad` (`:158-178`). Glows on Blizzard buttons, `print`, `HookScript` on
the spellbook frames (`:22,77`). **Nothing to take:** ReadyCheck already covers macros (`ReadyCheck.lua:252-295`),
readable slot labels (`:238-248`) and spell-data loading (`:175-189`).

### 4.3 Ours
TrainerNotes knows only what a trainer listed (`:231-283`) and already drops spells the spellbook knows (`:302-354`);
no static data, reputation, quest spells or tomes. ReadyCheck compares ranks by name and subtext (`:297-321`), which
breaks where Forever renumbers ranks (Slam from 1240193) or replaces a rank (WT notes Seal of Righteousness rank 1 is
replaced when Judgement is learned, `Camelot\Paladin.lua:12`).

## 5. TomTom, Leatrix Plus and Leatrix Maps vs MapPins, Way, LevelGuide arrow and Landmarks

### 5.1 TomTom 4.4.1 (and the 2021 repo)
- **Forever support:** toc 16001 (`TomTom.toc:1`); HereBeDragons detects Forever as `WOW_PROJECT_CAMELOT`
  (`HereBeDragons-2.0.lua:19`), no coordinate transforms (`:102-103`), Forever world-map extents (`:253-255`);
  positions from `UnitPosition("player")` (`:663`; UnitDocumentation:2714, `SecretArguments` only; nil in instances
  handled). Player map is the library's if it agrees with `C_Map.GetBestMapForUnit`, else
  `C_Map.GetPlayerMapPosition` (`core/position.lua:30-47`). Gamepad mode via
  `C_InputInterfaceStyle.GetCurrentStyle()` (`:20-26`).
- **Arrow maths** (same in 2021 `TomTom_CrazyArrow.lua:210-264` and 4.4.1), our words:
  ```
  rel  = bearing(world vector) - GetPlayerFacing()
  cell = floor(rel/2π × 108 + 0.5) % 108      -- 9×12 sprite sheet
  perc = |π - |rel|| / π                       -- 1 ahead, 0 behind
  colour = 3-stop gradient bad→middle→good by perc; perc > 0.98 → "exact" colour
  dist ≤ arrival → "down" sprite
  every 1 s: v = (lastDist - dist)/dt, averaged over 2 samples; ETA = dist / v, else "***"
  ```
  Defaults: arrival 15 yd, clear 10 yd (arrival forced ≥ clear, `waypoints.lua:388-408`), set-closest on, corpse arrow
  on, yards/metres by locale (`core/settings.lua:57-98`); distance bands on a separate 10 Hz ticker
  (`core/distance.lua:24-113`).
- **Corpse** (`modules/corpse.lua:117-139`): at `PLAYER_DEAD` store the player's own map position (not in instances),
  then poll `C_DeathInfo.GetCorpseMapPosition` (DeathInfoDocumentation:11) every 0.5 s, falling back to the stored
  spot.
- **Quest follow** (`modules/poi.lua:194-246`): `C_QuestLog.GetNextWaypoint` / `GetNextWaypointText`
  (QuestLogDocumentation:251/287) with a loop guard (a user waypoint within 5 yd of the quest point is a copy).
- **Rules:** HBD-Pins data providers, coordinate frame inside the WorldMapFrame header, click catcher with
  `SetPassThroughButtons` (protected, SimpleScriptRegionAPIDocumentation:665), chat output, globals. 4.4.1 validates
  incoming addon-message waypoints (`comm.lua:93-100`); 2021 did not (`TomTom.lua:705-722`).
- **Ours** already has damped bearing, smoothed ETA, arrival hysteresis, corpse arrow with run-speed ETA, cross-map
  projection (`LevelGuide\Planner.lua:186-239`, `LevelGuide.lua:5090-5226`). Gaps: two colours only (`:5219-5224`);
  no stored death spot (`CorpseTarget`, `:5090-5117`, relies on the API although `PLAYER_DEAD` is registered,
  `:5945`).

### 5.2 Leatrix Plus and Leatrix Maps (no licence)
- **Action-button state** (`Leatrix_Plus.lua:4037-4212`): if any value is secret, leave it; else `usable ? (inRange ==
  false ? range : normal) : notEnoughMana ? mana : unusable`; "#"-macros via `IsSpellUsable(GetMacroSpell)`. Drawn via
  `hooksecurefunc("ActionButton_Update*")` and `SetVertexColor` on Blizzard icons: the logic is useful, the drawing is
  forbidden for us.
- **Durability** (`:8370-8465`): Σ `GetInventoryItemDurability` over 10 slots, bands 80/60/40/20 %, written into
  PaperDollFrame and `GameTooltipTextLeft*` (frame writes).
- **CVar writes** (settings changes, flagged): WeatherDensity, camera distance, Sound_*, ffx*, gamma, autoLootDefault,
  nameplateShowEnemies; a developer command sets `addonCombatRestrictionsForced`, `addonMapRestrictionsForced`,
  `addonChatRestrictionsForced`, `addonPvPMatchRestrictionsForced` to 1, forcing secret-value restrictions outside
  combat (not in uisrc2; useful for **our testing by hand**, #R18).
- **Leatrix Maps zone levels** (`Leatrix_Maps.lua:3854-3995`): zone under cursor = `C_Map.GetMapInfoAtPosition`
  (MapDocumentation:328); colour = difficulty of min if below range, of (max−2) if above, else orange; label
  "Name (min-max)" plus "Fishing: N". Installed by replacing a Blizzard label's OnUpdate (`:3997-4000`) and 13
  `hooksecurefunc`s: not our pattern. Its Forever ranges differ from our `ZoneLevels.lua:35-36`: Zephras Isle 1-12 /
  3-12, Riverglades 35-45 / 36-44, Shen'dralas 35-45 / 38-45, Hyjal 60 / 58-60 (check in game). Map coordinates via
  Blizzard's own CVars `worldMapShowPlayerCoords`/`worldMapShowCursorCoords` (`:3425-3429`; a settings change).

## 6. Glowing Bars (MIT) and action-bar highlights on this client

- **Build:** TypeScript only; no compiled `GlowingBars.lua` in the repo (TypeScriptToLua output not committed). Toc
  16001, `AllowLoadGameType: camelot`.
- **Old ranks** (`outdated-ranks.service.ts:43-63`): per spell ID on the bars (not macros), highest learned rank per
  name; cached until bars or spells change.
- **Slot of a button** (`action-bars.service.ts:351-357`): `GetPagedID()` → `CalculateAction()` → `button.action` →
  `GetAttribute("action")`. Forever quirks (`docs/forever-quirks.md`): bear form pages the main bar to 97-108 (#10);
  gamepad bars keep stale spells in slots ≥ 195 (#16); `IsVisible()` can return a secret boolean (#17); a full
  spellbook walk during the `SPELLS_CHANGED` storm froze the client at quest turn-in (#6/#7).
- **Procs** (`glow-cues.service.ts:85-90`, `glow-cues.constants.ts:59-73`): `C_Spell.IsSpellUsable`
  (SpellDocumentation:980) for Execute, Victory Rush, Hammer of Wrath, Riposte, Counterattack, Mongoose Bite; "free"
  or "instant" (`GetSpellPowerCost`, cast time) for Arcane Missiles and Shadow Bolt procs.
- **Warrior stance procs** (`stance-procs.service.ts:36-61`): Overpower usable while combo points > 0 (Forever gives a
  combo point when the target dodges); Revenge for 5 s after `UNIT_COMBAT` BLOCK/DODGE/PARRY (`UNIT_COMBAT` is not a
  CallbackEvent; only `amount` is secret, UnitDocumentation:4171).
- **Range:** `C_ActionBar.IsActionInRange`. **Cooldown memory** (`cooldown-tracker.service.ts:33-84`): remember length
  (> 1.51 s) and end time when readable; on own cast `endsAt = now + max(base, lastSeen)`; ignore a readable "ready"
  for 1 s after casting.
- **Secret values without reading them** (`value-curves.service.ts:18-50`, `defensive-execute.service.ts:50-68`):
  ```
  curve = C_CurveUtil.CreateCurve(); Linear; points (0,1) (t-0.02,1) (t,0) (1,0)
  alpha = UnitHealthPercent("target", true, curve)   -- secret; never compared
  glow:SetAlpha(alpha)
  ```
  Backed by the docs: `UnitHealthPercent` "can be scaled via a curve" (UnitDocumentation:1506; also
  `UnitPowerPercent`), `C_CurveUtil.CreateCurve` (CurveUtilDocumentation:21), and `SetAlpha`, `SetVertexColor`,
  `StatusBar:SetValue`, `FontString:SetText` accept secret arguments (SimpleRegionAPIDocumentation:123,191,
  SimpleStatusBarAPIDocumentation:355, SimpleFontStringAPIDocumentation:664). This is the one documented way to show
  in-combat health/mana state on our own frames.
- **Weapon buff:** `C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot).remainingTimeMs` (PaperDollInfoDocumentation:226,
  491; explicitly milliseconds), combined with `C_Item.GetWeaponEnchantInfo` and tooltip text.
- **Not used / secret status:** `GetActionCount` is undocumented; the documented `C_ActionBar.GetActionUseCount`/
  `GetActionDisplayCount` are `SecretWhenCooldownsRestricted`, as are `GetActionCooldown`, `GetSpellCooldown`,
  `GetSpellCastCount`. `IsUsableAction` (ActionBarFrameDocumentation:919), `IsActionInRange` (:624) and
  `IsSpellOverlayed` (SpellActivationOverlayDocumentation:11) have no secret flags (guard anyway).
  `ACTION_USABLE_CHANGED`, `ACTION_RANGE_CHECK_UPDATE`, `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` are not CallbackEvents.
  `C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Combat)` and
  `ADDON_RESTRICTION_STATE_CHANGED` (RestrictedActionsDocumentation) tell when restrictions are on; the function
  "always returns false during dispatch" of that event, so re-check a frame later.
- **Drawing:** glows are children of the Blizzard button (incl. its own `ActionButtonSpellAlertTemplate`,
  `glow.service.ts:308-357`): forbidden for us. Its gamepad path anchors a UIParent frame with SetPoint (allowed) but
  adds `HookScript("OnShow"/"OnHide")` on the Blizzard button (`:257-268`): forbidden. Prints to chat
  (`notice.service.ts:96-98`). Malware: no install/postinstall scripts; its dev scripts would clone `Gethe/wow-ui-source`
  and copy into AddOns if run (`scripts/fetch-wow-ui-source.ts:21`, `deploy.ts`); nothing was run; no git hooks.

## 7. New Forever addons since round 3 (sweep)

**Method.** GitHub repository search without sign-in, sorted by update: `topic:wow-forever` (382 repos), `forever addon
wow created:>2026-11-08` (87), `"wow forever" in:description,readme created:>2026-11-08` (323), `forever in:name
language:Lua created:>2026-11-06` (140). 635 unique repos were listed (the anonymous rate limit stopped a few pages);
255 matched leveling/item/map keywords and are not named in any earlier research file. Fifteen were opened (file
trees, README, licence, key Lua files as text). WebSearch for new CurseForge Forever addons found roundups only;
**Levelator** (gear upgrades, free 1-30, paid after) was not opened. **Failed:** GitHub code search (needs sign-in),
the last search pages (rate limit).

| Addon | Licence | What matters for us | Rules |
|---|---|---|---|
| **FastLoot** (ca33u) | GPL-3.0; `Data\DropData.lua` from **cMaNGOS classic-db (GPL-3.0)** | `[npcID] = "itemID:chance%[q];…"`, `q` = drops only while on the quest. A legal, shippable drop-rate table (Classic NPCs only; Forever-new mobs absent) | Instant loot and roll panel are automation/UI we don't take |
| **LevelBiS Forever** (huffy-it), WIP | GPL-3.0 | Item DB (≈2.9 MB, 3 level bands) with stats from the Forever client tables (build 1.60.1.70862), `alvl` (level you can reach it), sources from QuestieDB v1.0.10. Provisional weights (no published Forever scales); talent tree → spec via `C_Traits` orderIndex. Confirms one hit/crit/haste stat type on Forever items | Sources part inherits QuestieDB's "all rights reserved when in doubt" note: don't ship it |
| **XP Horizon** (thejvfdev) | GPL-3.0-or-later | XP-to-60 bar and ETA; Classic XP-per-level curve (4,084,700 total) **replaced per level by `UnitXPMax` seen on any character of the account**, so the curve self-corrects if Forever's differs | `HookScript` on the XP bar, `RequestTimePlayed` (prints in chat) |
| **Full Mana Forever** (KesaObscura) | MIT | In-game facts (`Regen.lua:1-6`): regen is continuous (no 2 s ticks); a mana-costing cast drops regen to the "casting" rate for 5 s (0 base, 50 % Spirit Tap, 100 % Innervate); own casts and costs readable in combat; `GetPowerRegen` (PlayerScriptDocumentation:860) readable out of combat, **secret in combat**. "Normal" regen = lowest regen per 30 s over the last 5 min out of combat; Resurrection Sickness 15007 or ≥ 50 % base Int/Spirit cut excluded; Read Leyline 1259705 raises regen 30 s (15 min at a ley line) | Lights up items on bars (not taken) |
| **Firekeeper** (Brattlof) | MIT | Camp-object catalogue (36 objects: item IDs, tiers, verbatim effects) and **"exclusive with"** buffs, e.g. Mana Well ↔ Blessing of Wisdom, Sharpening Wheel (Strength, not AP) ↔ Strength of Earth Totem, Enchanted Lute ↔ Mark of the Wild (`docs/SOURCES.md`, from Wowhead's Forever JSON, 2026-09-20) | Group sync by addon messages (not taken) |
| **Alts Forever** (KadmaiDev) | MIT | Waylaid Crate tooltip lists its bundles as "- 20 Soul Dust" lines under "Use:" (item 248689, checked in game 2026-10-12); grid of materials × characters, green when the account has enough; only mailable characters counted | Fine (tooltip lines) |
| **MobSpot** (Archydude) | MIT | Watch list by NPC ID with name fallback, **learns the NPC ID when a name matches** so renamed/translated mobs still match; nameplates + target/mouseover/focus once a second plus vignettes with real distance. In-game fact: **Forever refuses `TargetUnit` from addons before looking for the unit**, so the old "blocked = nearby" rare trick tells nothing | Skull marker on nameplates (not taken) |
| **Chainlog** (ca33u) | MIT | Dungeon quest chains with prerequisites and follow-ups, statuses, "abandon warning: which steps close and where to re-take it". Reads QuestieDB at run time (no data) | TomTom/game waypoint only |
| **Forever Wayfinder** (cbuntingde) | MIT | Vendor kind from the NPC's sub-name by keyword, profession supplies before armour words ("Leatherworking Supplies" before "leather") (`Data.lua`) | HandyNotes pins (canvas) |
| **QuestDropRates** (chadrien) | MIT | Questie drop rates on unit tooltips | `loadstring` on QuestieDB data strings (benign but executes another addon's data); data not shippable |
| **Legacy Forever** (cjber), new details | GPL-3.0-or-later | Legacy points = currency **4225**; challenges = achievements listed by `GetCategoryList`/`GetCategoryNumAchievements`/`GetAchievementInfo` (undocumented, live on Forever), criteria by ID not index; `CRITERIA_UPDATE` (AchievementInfoDocumentation:145), `MAP_EXPLORATION_UPDATED` (MapExplorationDocumentation:49), `C_Traits.GetTraitCurrencyForAchievement` (SharedTraitsDocumentation:454) | Writes into the objective tracker; **shares flight-path totals with guild/group by default** (addon messages) |
| **Forever Quest Probe** (TylerAkins) | GPL-3.0 | Measured on build 69977: no `WorldMapFrame:EnumeratePins`, no `QuestPOIGetIconInfo`, no `C_TaskQuest.GetQuestsForPlayerByMapID`, no `C_QuestLog.IsQuestReadyForTurnIn`; quest objective/turn-in coordinates are not exposed: navigation needs our own DB (as we do) | Fine |
| Others seen, not opened (mostly automation, guild, UI or AI tools): Wellbrock, ItemFlow, Train-All-Forever, one-key-interact, ZEUS, NextMob (targets for you), obvi-training (Train button), ForeverFlow, Mentor, voidlayer (layer hop), awesome-house, Everloot (AGPL code; data from client tables and the CC BY-SA wiki dump) | | | Automation ones break rule 1 |

---

## 8. Ranked improvements for our helpers

Ranked by leveling/playing gain for a solo player ÷ (effort + risk). Size: S < 1 day, M a few days, L a week+. None is
built today and none repeats `re_round3.md` §6 or `popular_*.md` lists, except where noted as the missing detail. All
read-only, in our own frames, no hooks, no canvas pins, no combat-log or CallbackEvents, `Safe()` on every value.

### R1. QuestMobs + Tooltips: quest-item drop rates and "kills left" (S/M)
- **Data:** FastLoot's `DropData.lua` format, regenerated by our own `tools\gen_drops.js` straight from cMaNGOS
  classic-db (GPL-3.0; credit cMaNGOS and FastLoot in `NOTICE.md`), filtered to items that are quest objectives in our
  `LevelGuide\QuestDB.lua` (keeps it small).
- **Algorithm:**
  ```
  on tooltip unit (TooltipDataProcessor post-call): npc = NpcID(Safe(UnitGUID))
  for each unfinished item objective (have/need) of an active quest:
      p = rate[npc][item]; if p: line "Kobold Candle 35%  (~6 kills for 2 more)"
      killsLeft = ceil((need - have) / (p/100))
  QuestMobs: rank objective mobs by rate; LevelGuide "About N kills" uses the same number
  ```
  `q` flag = rate only while the quest is held (always true here). Forever-new mobs: no line, never a guess.
- **APIs:** `C_QuestLog.GetQuestObjectives` (QuestLogDocumentation), `UnitGUID` (plain in combat per round-3 probe).

### R2. ItemAdvisor: Forever expertise and haste percent lines (S)
- **Algorithm:**
  ```
  "^reduces%s+chance%s+to%s+be%s+dodged%s+or%s+parried%s+by%s+([%d%.]+)%%" -> expertise (attack)
  label "speed" (attack speed) -> haste (attack); "casting speed" -> haste (spell);
  "attack speed and casting speed" -> haste (any)
  ```
  Keep "tooltip only fills stats GetItemStats didn't return" (`:627`); add tests with the exact game strings; check
  with `/ia` raw stats whether `GetItemStats` already returns these keys.
- **Source:** game text (Pawn only pointed at it).

### R3. TrainerNotes: the full Forever spell list, 1-60, before any trainer visit (M)
- **Data:** What's Training `Classes\Camelot\<Class>.lua` (**MIT**, credit fusionpit): `{level → {id, cost, req, talent,
  race/faction}}` plus rank groups, generated into `TrainerNotes\Data.lua` by a tools script.
- **Algorithm:**
  ```
  known(id) = IsSpellKnown(id) or IsSpellInSpellBook(id, Player, false) or known(later rank in group)
  status = known | talent (talent not known) | ready (level ≤ L and req known) | blocked | next (≤ L+2) | later
  page: Ready (sum) / Next 2 levels (sum, "set aside Xg for level L+2") / Talent-gated / Later
  names: C_Spell.GetSpellName after RequestLoadSpellData + SPELL_DATA_LOAD_RESULT
  recheck ready IDs only on SPELLS_CHANGED, spread over frames (see R13)
  ```
  Live trainer reads stay the override for cost. Never buys.
- **APIs:** SpellBookDocumentation:720,738; SpellDocumentation:869,1012,1120.

### R4. Dungeons: level ranges from the game, then a data audit (S)
- **Algorithm:**
  ```
  id = ACT[name] (activity IDs above) or match GetActivityInfoTable(id).fullName
  info = pcall(C_LFGList.GetActivityInfoTable, id)
  if info and minLevelSuggestion > 0: range = {enter=minLevel, lo=minLevelSuggestion, hi=maxLevelSuggestion}
  else Data.lua
  show "(game: a-b)" when it differs; Suits() (Dungeons.lua:644) = L ≥ lo-2 and L ≤ hi
  ```
  Then audit by hand (foreverchanges.pro, Wowhead Forever) the 15 range conflicts, the thin Forever dungeons (Krol'dok,
  Alcaz, Blackmaw, Shaper's, Drowned City bosses and loot), Lordaeron Captain, Highland Horror, Zin'aka/Min'loth,
  Cinder/Snowtalon, and add `npcID` per boss. DungeonJournal/AtlasLoot as a checklist only.
- **APIs:** LFGListInfoDocumentation:184. Activity IDs to confirm in game.

### R5. LevelGuide: stored death spot, resurrect timer, arrow colour and arrival ping (S)
- **Algorithm:**
  ```
  PLAYER_DEAD and not IsInInstance(): save {map, x, y} per character
  CorpseTarget(): API position if non-nil and not (0,0), else the saved spot; clear on PLAYER_UNGHOST/ALIVE
  within arrival radius: "Resurrect in N s" from GetCorpseRecoveryDelay() (PlayerScriptDocumentation:351)
  colour: p = 1 - |wrapped|/π; c = lerp3(red, yellow, green, p); p > 0.98 -> exact colour
  optional PlaySound once on the false->true edge of P.Arrived (Planner.lua:226-239)
  ```
- **Source:** TomTom ideas (ARR), trivial maths; replaces `LevelGuide.lua:5219-5224` colours.

### R6. ReadyCheck: old-rank check by spell ID (S)
- **Data:** WT rank groups (`overriddenGroups`, MIT), e.g. `Camelot\Warrior.lua:4-24`.
- **Algorithm:** `g, i = group(barSpellID); best = max k with IsSpellKnown(g[k]); flag if i < best`; spells in no group
  fall back to today's name/subtext check. Handles renumbered ranks (Slam from 1240193) and locale-free.

### R7. DeathNotes: in-combat low-health and low-mana cue that never reads a secret (S, verify in game)
- **Algorithm:**
  ```
  once: curveHP = CreateCurve(Linear; (0,1) (0.33,1) (0.35,0) (1,0)); curveMana similar at 20 %
  OnEvent UNIT_HEALTH/UNIT_POWER_UPDATE (player), throttled:
      redEdge:SetAlpha(UnitHealthPercent("player", true, curveHP))      -- secret passed straight through
      drinkIcon:SetAlpha(UnitPowerPercent("player", Enum.PowerType.Mana, false, curveMana))
  ```
  Our own frames only; no comparison or arithmetic on the result.
- **Source:** Glowing Bars `value-curves.service.ts` (MIT). **APIs:** UnitDocumentation:1506 (and `UnitPowerPercent`),
  CurveUtilDocumentation:21, SimpleRegionAPIDocumentation:123. Check the curve argument works on 1.60.1.

### R8. ItemAdvisor: equipment-set check that respects random suffixes (S, correctness)
- Bag items: `C_Container.GetContainerItemEquipmentSetInfo(bag, slot)` (ContainerDocumentation:158). Other links:
  compare full links from `C_EquipmentSet.GetItemLocations` (EquipmentManagerDocumentation:184) instead of
  `GetItemIDs` (:168). Fixes "X of the Monkey" kept because the set holds "X of the Owl" (`ItemAdvisor.lua:836-849`).

### R9. ForeverHub/LevelLog: XP to 60 with a learned Forever XP curve (S)
- **Algorithm:**
  ```
  account-wide: curve[L] = Safe(UnitXPMax("player")) whenever seen at level L (overwrites the Classic default)
  total = Σ curve[1..59]; done = Σ curve[1..L-1] + UnitXP
  "38.7 % of the way to 60 - about 41 h at your recent XP/h" (active-clock XP/h, not /played)
  ```
  No `RequestTimePlayed` (it prints to chat); no XP-bar hook: the hub's side panel shows it.
- **Source:** XP Horizon (GPL-3.0-or-later, credit). **APIs:** UnitDocumentation:3489 (`UnitXPMax`).

### R10. Dungeons: kills by NPC ID and learned entrances (S)
- **Kills:** on `UNIT_DIED(guid)` or `PARTY_KILL(_, guid)`: `npc = NpcID(Safe(guid))`; `bossByNpc[npc]` → `RecordKill`
  (reuse the 30 s dedupe, `Dungeons.lua:461`). Learn NPC IDs: target name matches a boss of the current instance
  (`GetInstanceInfo`, InstanceDocumentation:103) → store its NPC ID. Covers bosses that never fire `ENCOUNTER_END`.
- **Entrances:** while outdoors in a dungeon's zone with an "approx" entrance, sample `{map,x,y}` every 2 s; when
  `IsInInstance` (InstanceDocumentation:170) turns true, save the last sample; pin it instead (8 "approx" rows,
  `Data.lua:60,286,302,329,367,480,651,672`).

### R11. RestGuard/FoodCheck: camp objects you can use, and what they overlap with (S)
- **Data:** our own table of the 36 camp objects (item ID, tier, effect at your level, "exclusive with" buff), facts
  checked against Firekeeper's catalogue (MIT) and Tweaks' spell IDs (`re_round3.md` §2.5).
- **Algorithm:** near a camp (aura 1283391), list objects nobody placed; hide those whose buff is already covered by an
  exclusive one you have ("Mana Well: you already have Blessing of Wisdom"). Aura reads only out of combat and when
  `C_Secrets.ShouldAurasBeSecret()` is false; `C_UnitAuras.GetPlayerAuraBySpellID` (UnitAuraDocumentation:397).

### R12. Dungeons + Tooltips: client item names and a better source line (S)
- `RequestLoadItemDataByID` each loot row; on `ITEM_DATA_LOAD_RESULT` compare `GetItemNameByID` with ours, show the
  client's name and flag differences on a check page (catches 271207/271214, gives the player's language).
- Source line: rank boss drop > trash > quest (own faction); with several dungeons prefer the one containing your level;
  append "(lvl a-b)"; "several dungeons" for shared loot. Ranking idea from DungeonJournal (idea only), data ours.

### R13. ReadyCheck/TrainerNotes: spellbook walks spread over frames (S)
Glowing Bars reports a full spellbook walk during the `SPELLS_CHANGED` storm froze the client at quest turn-in.
`ScanSpellBook` (`ReadyCheck.lua:192-221`) still walks every line in one frame after its 2 s debounce: walk 2 skill
lines per `C_Timer.After(0)` step and rebuild at most every 5 s.

### R14. ItemFinder: item IDs, keyring, equipped bags, then mail without hooks (M)
- `places[place][itemID] = count`, `names[itemID]`; keyring via `Enum.BagIndex.Keyring` sized by pcall
  `GetKeyRingSize` (undocumented) else `GetContainerNumSlots(-1)`; equipped bags via
  `C_Container.ContainerIDToInventoryID`; keep name records until the first rescan; Tooltips counts by ID.
- Mail: inbox on `MAIL_INBOX_UPDATE` with expiry = now + daysLeft; outgoing: snapshot attachments on
  `MAIL_SEND_INFO_UPDATE`, add on `MAIL_SEND_SUCCESS` (MailInfoDocumentation:126/133) with 30-day expiry; drop on expiry
  or when the receiver's inbox scan sees it. Store faction and scan time; Tooltips dims other-faction characters.
- Extends `popular_items_spells.md` §6 #1-3 with the hook-free outgoing-mail method.

### R15. ItemAdvisor reward marks: no "sells for most" coin when a choice can't be scored (S)
If any choice returns CHECK "No stats" / "Has stats I can't score" (on-use trinkets and similar), hide the coin and the
gold suggestion in `RefreshRewardMarks` (`:2019-2045`). Keep price × count. Idea from Pawn (`Pawn.lua:4281-4283`).

### R16. TrainerNotes + WindowBadges: reputation discount, class-quest spells, demon tomes (S each)
- Discount: for the class's trainer factions (WT `TrainerFactions.lua`, MIT) `pct = reaction ≥ 6 and 10 or 0`
  (`C_Reputation.GetFactionDataByID`, ReputationInfoDocumentation:48/348); trainer badge "10 % off at Honored with
  <name from the game>"; tomes never discounted.
- Quest spells: WT `Camelot\QuestSpells.lua` (48 rows, MIT) joined to our QuestDB (1665, 1719, 94003 present):
  "Defensive Stance, Taunt, Sunder Armor: quest 'Bartleby's Mug' (lvl 10)" until known.
- Tomes: WT `Camelot\WarlockTomes.lua` (MIT); unknown tomes ≤ L+2 per demon via `IsSpellKnown(id, Pet)`; "New" badge
  at a known tome merchant.

### R17. FoodCheck: "mana full in N s" and drink advice that respects the five-second rule (S)
- **Algorithm:** out of combat only: `regen = Safe(GetPowerRegen())`; `normal` = lowest regen per 30 s bucket over the
  last 5 min out of combat, skipping Resurrection Sickness 15007; `fullIn = (max − cur)/regen`; if `fullIn` > the drink
  time of your best drink (food/drink by ID, `re_round3.md` #8) say "Drink: full in 18 s instead of 64 s". In combat
  show nothing (regen is secret).
- **Source:** Full Mana Forever facts (MIT). **API:** PlayerScriptDocumentation:860.

### R18. Test guide: force restrictions while in town (S, docs)
Add to the in-game check list: `/console addonCombatRestrictionsForced 1` (and Map/Chat variants) to reproduce combat
secrecy in a safe place, then back to 0; the player types it, no addon writes it. In code, gate aura/cooldown reads
with `C_RestrictedActions.IsAddOnRestrictionActive` and re-check a frame after `ADDON_RESTRICTION_STATE_CHANGED`.

### R19. MapPins: world-map info line and minimap edge arrow (S/M)
- Info line on our UIParent overlay: cursor `cx = (GetCursorPosition()/scale − canvasLeft)/canvasWidth` (and y), shown
  only inside 0-1 and not in gamepad mode; zone under cursor by `C_Map.GetMapInfoAtPosition` with ZoneLevels' range,
  coloured below/in/above; player coordinates. Data ours (settle the four range differences in §5.2 in game).
- Edge arrow: when the guide target or `/way` point is beyond the minimap radius, one pin at the rim rotated by
  `atan2(-east, north) − facing` (with `rotateMinimap`), instead of hiding it (`MapPins.lua:1206-1208`). Note our
  minimap pins are children of `Minimap` (`:1095`), the accepted exception in STATUS.md.

### R20. RareWatch: watch list by NPC ID that learns from names (S)
User-editable list in our window; match by NPC ID, else by name, and store the NPC ID on the first name match
(MobSpot, MIT); vignette distance from `C_VignetteInfo.GetVignettes`/`GetVignetteInfo` (VignetteInfoDocumentation:58,
91). Do not use the `TargetUnit` trick (refused on Forever).

### R21. ItemFinder/ItemAdvisor: Waylaid Crate fill grid (S)
On a Waylaid Crate tooltip (item 248689 family), parse the "- N Material" lines under "Use:", look up counts across your
mailable characters from ItemFinder, and add "Soul Dust 20: you 12, Alt 9 → enough". Idea and in-game format from Alts
Forever (MIT). Complements the "never sell crates" rule already built.

### R22. Dungeons + ItemAdvisor: upgrades per dungeon (M), then per slot (L)
For dungeons in your band, check each loot ID (`DoesItemExistByID`, then load) with `ItemAdvisor_IsUpgrade`, spread
over frames: "Deadmines: 3 upgrades (legs, wrist, 1H)". Later a per-slot "next upgrades" view could use item stats
generated from the Forever client tables the way LevelBiS Forever does (GPL-3.0), but not its QuestieDB-derived
sources.

### Not taken
Glows or textures on Blizzard action/reward buttons (Nova, Glowing Bars, Pawn), every `hooksecurefunc`/`HookScript` on
Blizzard frames (Pawn, WT, DungeonJournal, Leatrix, TomTom, XP Horizon), Leatrix's OnUpdate replacement and CVar
writes, TomTom/HBD canvas pins and click catcher, train-all and `CastSpellByID` (WT, Train-All-Forever, obvi-training),
auto-loot and auto-sell (FastLoot, ItemFlow, Wellbrock), targeting helpers (NextMob, TargetFinder), addon-message
sharing (AtlasLoot, DungeonJournal, TomTom, Legacy Forever, Firekeeper), Syndicator's SendMail hooks, Pawn's TBC
rating constants, GearQuest's ×3 Stamina at 60 and zero Stamina for hunters/warlocks, any table from AtlasLoot
(GPLv2-only), DungeonJournal, Baganator/Syndicator, Pawn, GearQuest, Nova, TomTom or Leatrix, and QuestieDB-derived data
(LevelBiS sources, QuestDropRates, Chainlog, Wayfinder).

## Summary

Three findings stand out. First, a legal drop-rate source now exists: FastLoot's table comes from cMaNGOS classic-db
under GPL-3.0, so quest-item drop chances and "kills left" can ship (R1), which Questie's data never allowed. Second,
What's Training is MIT, not "ideas only" as recorded earlier, and its Forever data (1,401 trainer rows, 147 new IDs,
moved levels, talent-free spells, Forever factions) can give TrainerNotes a full 1-60 list and ReadyCheck an ID-based
rank check (R3, R6, R16). Third, the client documents a way to show secret health and mana without reading them, by
passing curve results to `SetAlpha` on our own frames (Glowing Bars, MIT; R7). Smaller correctness fixes: ItemAdvisor
drops Forever's haste and expertise percent lines (R2) and treats random-suffix variants as set items (R8). Dungeons
disagrees with DungeonJournal on 15 level ranges, which the game's Group Finder data can settle (R4). Licences:
WT, Glowing Bars, Firekeeper, Full Mana, Alts Forever, MobSpot, Chainlog, Wayfinder are MIT; FastLoot (cMaNGOS data),
LevelBiS, XP Horizon and Legacy Forever are GPL-3.0; AtlasLoot is GPLv2-only (no code); TomTom is ARR (HereBeDragons
BSD); Leatrix, DungeonJournal, GearQuest and Nova have no licence; Pawn is CC BY-NC-ND; Baganator/Syndicator are ARR.
Malware: nothing new downloaded; the quarantined copies are clean (only addon-message version broadcasts in AtlasLoot,
DungeonJournal and TomTom; Glowing Bars' dev scripts would clone a repo if run; QuestDropRates `loadstring`s
QuestieDB's data strings).
