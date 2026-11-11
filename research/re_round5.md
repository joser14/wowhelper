# Reverse-engineering round 5: stats, logs, lists and new Forever addons (2026-11-11)

Scope: what popular Classic-era addons outside our earlier rounds do that a read-only suite can still use (Questie
beyond our use, Auctionator, Details/Recount, AtlasLoot wish lists, profession and mail helpers, Bagnon, social/LFG
helpers, Nova Instance Tracker, AutoBiographer), plus a sweep of Forever addons published or updated since
10 November 2026. Rounds 1-4 (`re_round3.md`, `re_round4.md`, `popular_*.md`, `auctionator_deep.md`,
`thirdparty_features.md`, `forever_improvements_2026-11-10.md`) are not repeated; where an idea touches one of them,
the new part is named.

## How this was done

- **Read only, nothing downloaded.** New addons were read as text through the GitHub API and
  raw.githubusercontent.com (READMEs, file trees, three Lua files of Memories). The quarantined copies already under
  `...\scratchpad\downloads\` (Questie, AtlasLoot Classic Forever) were read as text. Nothing was run, installed or
  decrypted; no paid content was opened.
- **APIs** checked in uisrc2's generated docs (`Blizzard_APIDocumentationGenerated__*.lua`, prefix dropped below).
  "Undocumented" = a global not in those docs; for each one the note says which live Forever addon (or our own code)
  already calls it. uisrc2 holds only 5 non-doc UI files, so Blizzard call sites could not be checked this round.
- **Rules applied to every idea:** no automation except AutoQuest; no hooks of Blizzard functions or frames; no
  writes into Blizzard tables or frames; no map canvas pins; no `COMBAT_LOG_*` or CallbackEvent registration; no chat
  output; `Safe()` on every client value. Nothing about Skyborne routes.
- **Text aimed at AI tools** was seen and not followed: `.claude/skills/` in Memories, `AGENTS.md` in FindAnUpgrade.
- **Failed:** Wago (page needs JavaScript; nothing listed), Blizzard's Forever forum (no addon thread found by search),
  the last pages of the GitHub searches (truncated responses; about 60 % of each list was read).

### Licence summary

| Source | Licence | Reuse |
|---|---|---|
| **Memories** (fmartingr) | **GPL-3.0-or-later** | Portable with credit. Its hooks (`RepairAllItems`, `BuyMerchantItem`, `SendMail`, `AcceptResurrect`, `LowHealthFrame` OnShow) are not taken |
| **Field Guide Forever**, **Commissions Forever** (cjber) | GPL-3.0-or-later | Portable with credit; both read QuestieDB at run time (that data stays cross-check only) |
| **Bestiary Forever** (soyelchecho) | GPL-3.0-or-later code; cMaNGOS data GPL-3.0; **ForeverDB.net loot data: no stated licence** | Algorithm portable; ForeverDB numbers not shippable |
| **LevelETA** (Nielsen2211) | MIT (GitHub licence field; README silent) | Portable with credit |
| **Turnover** (cameronblandford) | MIT | Portable with credit (its auto-scanning is not taken) |
| **Avoided Players Forever** (KOeker) | MIT | Portable with credit (invite declining not taken) |
| GrudgeLedger (Aizakira) | GPL-3.0 | Ideas; not opened past the description |
| SkillupHelper (ParogDev) | MIT per GitHub; README states none | Ideas only until a LICENSE file is confirmed |
| FindAnUpgrade (elithrar) | BSD-3-Clause | Not needed beyond ideas |
| ExplorersMap (LeuanNs) | None for the addon; bundles OpenMap reveal data (**MIT**) | Ideas; the OpenMap data itself is MIT |
| Nova Instance Tracker | All Rights Reserved (CurseForge page) | Ideas only |
| AutoBiographer (AaronV-T) | No licence (GitHub field null) | Ideas only |
| Questie (Sounds, Journey) | GPLv3 for consenting contributors, "all rights reserved when in doubt" | Ideas only (as in `re_round3.md`) |
| AtlasLoot Classic Forever (Favourites) | GPLv2-only | Ideas only (not combinable with our GPL-3.0) |
| Details!, Bagnon, Auctionator | No SPDX licence detected on GitHub | Ideas only; we use Blizzard's own `C_DamageMeter` instead of Details |

---

## 1. Forever addons published or updated since 10 November 2026

**Method.** GitHub repository search, anonymous, sorted by update: `topic:wow-forever pushed:>2026-11-09` (165 repos)
and `forever wow addon created:>2026-11-09` (119 repos); about 110 read. CurseForge's Forever filter (game version
88568) sorted by release date, page 1 (50 addons). WebSearch for news.

| Addon | Licence | What matters for us | Rules |
|---|---|---|---|
| **Memories** (+ Economy, Combat, Social, Gathering, Character modules) | GPL-3.0-or-later | AutoBiographer for Forever. Death killer from `C_DeathRecap`; dungeon visits from `GetInstanceInfo`; money attributed to sources by which window is open (details in §3) | Hooks Blizzard functions for repair/buy/train/mail; uploads to a website via a desktop app |
| **Field Guide Forever** | GPL-3.0-or-later | Kill journal: a kill counts when your target or a visible nameplate dies and nobody outside the group tagged it; rare counts when its vignette goes alive→dead; research ranks at 1/3/6/10 kills; zone completion % | Marks on target portrait and nameplates (not taken) |
| **Bestiary Forever** | GPL-3.0-or-later | Personal drop rates: each looted corpse counted once, each item once per corpse, "your" rate shown from 20 corpses, fallback order you → Forever-measured → cMaNGOS → you (<20) → "seen N" | ForeverDB data needs an API key and has no licence |
| **LevelETA** | MIT | ETA by calendar date; rate from the last 12 levels, recent ones weighted, outliers (AFK) dropped, current pace blended in at up to 40 %; activity split (fight / quest / travel / flying / town / AFK / dead) | Calls `/played` in the background (we don't) |
| **Commissions Forever** | GPL-3.0-or-later | Repeatable turn-ins (Argent Dawn, Cenarion, Thorium, Timbermaw, Morrowgrain): bag counts vs quest-log needs, turn-ins counted from `QUEST_TURNED_IN` | Draws into the Professions window |
| **Turnover** | MIT | Sell-speed estimate from repeated searches: a listing that disappears before it could expire counts as sold; lower bound; needs ≥ 10 min watched | Auto-scans the AH every minute and prints to chat (not taken) |
| **Avoided Players Forever** | MIT | Account-wide avoid list with reasons; Group Finder results outlined | Declines invites, writes into the social and LFG frames (not taken) |
| **ExplorersMap** | none (OpenMap data MIT) | Per-zone exploration progress and the nearest undiscovered area | Pins on Blizzard's map, chat line |
| **SkillupHelper** | MIT? | "Craftable now / keep for later / wasteful" from bags + bank; materials reserved for later steps | Needs TSM |
| Also seen (no new idea for us, or automation): TidyPack (bag groups; delete prompts), ForeverLootKey and SelectiveLoot (looting), CSCoder QuestIndicator (auto turn-in), ForeverFlip/goldwright/market-ledger/forever-market (AH data apps), PetScout/PetTraining (hunter), CheaperBuffs, FeelingPeckish (chat output), wow-stickyfilters (writes into merchant/trainer frames), EasyCraft, ultima-leveling-xp, QuestCompendiumForever (private prototype), Zyde_Forever, AggeHealBot, WorldSync (layer hop), guild tools | | | |

CurseForge page 1 adds nothing Forever-specific beyond earlier rounds; it confirms Details!, Nova Instance Tracker and
Bagnon ship Forever files (Details reads `C_DamageMeter`, so the client meter is live on Forever).

## 2. Popular Classic addons: what is left for us

### 2.1 Questie beyond what we use (ideas only)
- **Sounds** (`Modules\Sounds.lua:10-50`): three sounds, objective progress, objective complete, quest complete; the
  first two are debounced with one `C_Timer.After(delay)` flag each, and quest-complete cancels both pending sounds.
  We play no quest sounds today (grep: only BreathWatch, LevelGuide arrival, RareWatch, hub alerts).
- **My Journey** (`Modules\Journey\QuestieJourney.lua:235-296`, `History.lua:77-110`): a per-character list of
  `{Event = "Level" | "Quest" | "Note", Timestamp = time(), ...}`, quest entries with sub-events accept / complete /
  abandon, shown by year and month. **Quests by zone** and **by faction** (reputation rewards per faction) tabs.
  Nothing in our helpers keeps a dated timeline.

### 2.2 Auctionator (read-only parts not yet built)
Price memory, tooltip prices and vendor-vs-AH were built (PriceMemory, Tooltips, GoldGuide). Remaining: sell speed
(Turnover's method, §4 #13) and real sale prices from AH invoice mail (`auctionator_deep.md` §8 noted it as a new
idea without precedent; still unbuilt).

### 2.3 Details / Recount without the combat log: `C_DamageMeter`
The client's own meter (DamageMeterDocumentation) gives per-session totals without any combat-log event:
- `GetAvailableCombatSessions()` → `{sessionID, name, durationSeconds}`;
  `GetCombatSessionFromType(sessionType, type)` and `...FromID` → `combatSources[]` with `totalAmount`,
  `amountPerSecond`, `isLocalPlayer` (NeverSecret), `deathRecapID`, `classification`;
  `GetCombatSessionSourceFromType(sessionType, type, sourceGUID)` → `combatSpells[]` with `spellID`, `totalAmount`,
  `overkillAmount`, `isAvoidable`, `isDeadly`, per-target details.
- Enums (DamageMeterConstantsDocumentation): session Overall 0 / Current 1 / Expired 2; type DamageDone 0, Dps 1,
  HealingDone 2, Hps 3, Absorbs 4, Interrupts 5, Dispels 6, DamageTaken 7 (to 10).
- All session reads are **`SecretWhenInCombat`**: read after `PLAYER_REGEN_ENABLED`. Events
  `DAMAGE_METER_COMBAT_SESSION_UPDATED` (UniqueEvent), `DAMAGE_METER_CURRENT_SESSION_UPDATED`, `DAMAGE_METER_RESET`;
  none is a CallbackEvent. `IsDamageMeterAvailable()` → `isAvailable, failureReason`.
- **Never call `ResetAllCombatSessions`**: it clears the player's own Blizzard meter.

### 2.4 AtlasLoot favourites (wish lists; GPLv2-only, ideas only)
`Addons\Favourites.lua`: several named lists (per profile and account-wide), a note per item, an icon on item
tooltips (`:377-416`, done through a tooltip hook we would replace with a post-call), counts per instance/boss
(`:739-790`), "equipped or obsolete" check (`:899`), a main item per slot (`:1221-1255`), export/import strings
(`:1111-1128`). Sharing by addon message and `hooksecurefunc("SetItemRef")` (`:532`) are not for us.

### 2.5 Nova Instance Tracker (ARR, ideas only)
Lockouts across characters with time left on the 5-per-hour and 30-per-24-hours limits, timed from leaving; a new
copy vs re-entry of the same copy is told apart (SM wings); per-run stats: entry/exit time, time inside, mobs killed,
XP, XP per mob, gold looted, levels in/out, reputation; trade log; alt overview. Run summaries go to chat (not us).
**Forever's cap is unconfirmed**: Blizzard's support article lists Classic as 5/h + 30/day in one version and
10/h in another; NIT's Forever file still assumes 5/30. Make the cap a setting and check in game (§5).

### 2.6 AutoBiographer and Memories (stats)
AutoBiographer (no licence) tracks per-level and lifetime counters: kills per creature, deaths, quests, flights,
money by source (loot, quests, vendor, AH, mail), time per zone. **Memories (GPL)** does the same for Forever, and
three of its files were read:
- **Deaths** (`Record/Deaths.lua`): on `PLAYER_DEAD`, wait 1 s, drop it if the player is alive again; then
  `C_DeathRecap.HasRecapEvents()` / `GetRecapEvents()` (both in pcall), take the entry with the highest timestamp
  (later entry wins a tie) as the killer: name, spell, environment type, amount, NPC ID from the source GUID. A name
  learned outside instances from target/mouseover/nameplate overrides the recap name. The last recap timestamp is
  saved so a `/reload` doesn't count the death twice.
- **Dungeons** (`Record/Dungeons.lua`): `PLAYER_ENTERING_WORLD`/`ZONE_CHANGED_NEW_AREA` debounced 1 s; a visit is
  open while `IsInInstance` is party/raid and `GetInstanceInfo`'s instance ID is the same; a ghost outside keeps the
  visit open (corpse run); logout stamps the visit and the next login closes it. Stores time inside, deaths, boss
  kills, wipes, fastest kill. It does **not** tell a new copy of the same dungeon from a re-entry (instance ID is the
  map's, not the copy's).
- **Money** (`Memories_Economy/Money.lua`): `PLAYER_MONEY` delta; skipped when `GetMoney` is unreadable. Window labels
  from open/close events with grace periods: vendor, trainer, mail, auction (3 s), bank, trade (2 s), gossip,
  quest (1 s), flight (2 s); quest money within 5 s of `QUEST_TURNED_IN`. Fallback: gains = loot, losses = other.
  Repair, respec, purchases and mail are refined through hooks; we would replace those with event-only rules (§4 #4).

### 2.7 Bagnon / Baganator, mail, social, professions
- **Bagnon** (no licence): offline view of any character's bags and bank. ItemFinder has the data by item ID (round 4
  R14 built, incl. inbox) but only a text search; an icon grid is new (§4 #18).
- **Mail:** ItemFinder already stores inbox items with expiry (`ItemFinder.lua:341-348`); nothing warns before mail
  expires, and AH invoices are not read.
- **Social/LFG:** the online friends/guild card is already listed (`thirdparty_features.md` Q19). New here: who you
  grouped with before and your own notes (GrudgeLedger, Avoided Players), and Group Finder listings matched to your
  dungeons after you search yourself.
- **Professions:** ProfessionGuide already uses the 90th-percentile craft count (`ProfessionGuide.lua:307-321`) and
  counts the bank. SkillupHelper adds "materials reserved for a later step" (§4 #17).

---

## 3. Our helpers against these candidates

Folders (`Get-ChildItem`): !ErrorLog, AutoQuest, BagCheck, Builds, DeathNotes, Dungeons, DurabilityWatch, FoodCheck,
ForeverHelper, ForeverHub, GoldGoal, GoldGuide, ItemAdvisor, ItemFinder, Landmarks, LevelGuide, LevelLog, MapPins,
PriceMemory, ProfessionCap, ProfessionGuide, QuestCheck, QuestMobs, QuestTracker, RareWatch, ReadyCheck (SpellReady),
RepWatch, RestGuard, SupplyWatch, TalentNudge, Tooltips, TrainerNotes, WeaponSkillWatch, WindowBadges, ZoneLevels.

| Feature | Closest helper (toc note) | What it lacks |
|---|---|---|
| Killer of a death | DeathNotes ("remembers where you died, to what") | Killer is taken from your hostile target; no `C_DeathRecap` read (grep: none) |
| Fight summary | none | No `C_DamageMeter` use anywhere |
| Instance entries / runs | Dungeons (quests, kills by NPC ID, entrances) | No entry log, no per-hour count, no per-run stats |
| Money by source | GoldGoal (`PLAYER_MONEY`), ForeverHelper | Totals only; no source split |
| Personal drop rates | Tooltips (cMaNGOS rates, round 4 R1) | Nothing for Forever-new mobs; loot window read only by BagCheck for value |
| Quest sounds | QuestTracker | Silent |
| Wish list | Dungeons, ItemAdvisor, Tooltips | No user list (grep "wish": none) |
| LFG listings | Dungeons (activity ranges from `GetActivityInfoTable`, `Dungeons.lua:665-705`) | Search results never read |
| Timeline / lifetime stats | LevelLog (time, deaths, XP per level) | No dated events, kills per creature, time per zone, flights, money |
| Level ETA, activity split | ForeverHub side panel ("% of the way to 60", round 4 R9) | No calendar ETA, no split of time |
| Exploration | ZoneLevels, MapPins | No exploration progress |
| Grouped-with history | none | – |
| AH sell speed, invoices | PriceMemory | Daily lows/highs/amount listed only |
| Mail expiry | ItemFinder (stores expiry) | No warning |
| Alt bag view | ItemFinder (search) | No icon grid |

---

## 4. Ranked improvements

Ranked by gain for a level-11 solo priest (and later levels) ÷ (effort + risk). Size: S < 1 day, M a few days,
L a week+. All read-only, our own frames, no hooks, no canvas pins, no combat-log or CallbackEvents, no chat output.

### 1. DeathNotes: the real killer and the last hits from the death recap (S)
- **Algorithm:**
  ```
  PLAYER_DEAD: pending = {map, x, y, level, t}; C_Timer.After(1, read)
  read: if not UnitIsDeadOrGhost("player") then drop
        ok, has = pcall(C_DeathRecap.HasRecapEvents); ok, ev = pcall(C_DeathRecap.GetRecapEvents)
        last = entry with max Safe(timestamp) (ties: later index); skip if timestamp == db.lastRecap
        killer = Safe(sourceName), spell = Safe(spellName), env = Safe(environmentalType), hit = Safe(amount)
        npc = NpcID(Safe(sourceGUID)); a name DeathNotes learned from target/mouseover outside instances wins
        keep the last 5 hits for the death card ("Kobold Miner: Strike 38, 41, 35")
  fallback: today's target-based killer
  ```
- **APIs:** `C_DeathRecap.HasRecapEvents/GetRecapEvents` (DeathRecapDocumentation:11-60, `SecretArguments` only;
  **the event struct's fields are not documented** (`:80-84` empty): check names in game with `/dump`). Also
  `C_DamageMeter` sources carry a `deathRecapID` (NeverSecret) for later.
- **Source:** Memories `Record/Deaths.lua` (GPL-3.0-or-later, credit). Its revive hooks are not taken.

### 2. New "Fights" card (ForeverHub/LevelLog): Details-style summary from the client meter (M)
- **Algorithm:**
  ```
  PLAYER_REGEN_ENABLED -> C_Timer.After(0.5): if InCombatLockdown() or not IsDamageMeterAvailable() then return
  for type in {DamageDone, HealingDone, DamageTaken}:
      s = pcall(GetCombatSessionFromType, Current(1), type); me = source with isLocalPlayer
      read totalAmount, amountPerSecond through Safe()/canaccessvalue
  spells = GetCombatSessionSourceFromType(1, DamageDone, UnitGUID("player")).combatSpells -> top 3 by share
  card: "Last fight 34 s: 412 damage (12/s), 380 taken, 120 healed. Smite 45 %, Mind Blast 30 %"
  per level: median DPS, damage taken per fight, fights per death -> "Damage taken per fight up 40 % since level 10"
  ```
  DamageTaken spells with `isDeadly`/`isAvoidable` feed DeathNotes' advice line.
- **APIs:** DamageMeterDocumentation:11-126 (`SecretWhenInCombat` on every session read), constants in
  DamageMeterConstantsDocumentation. Never `ResetAllCombatSessions`. **In game:** `IsDamageMeterAvailable()` on
  Forever and its `failureReason`; whether "Current" still holds the fight just after combat or it moved to "Expired".

### 3. Dungeons: instance log, hourly/daily entries and per-run stats (M)
- **Algorithm:**
  ```
  PLAYER_ENTERING_WORLD / ZONE_CHANGED_NEW_AREA (debounce 1 s):
     inside = IsInInstance() == "party"; name, _, _, _, _, _, _, mapID = GetInstanceInfo()
     copy = zone UID field of the first creature GUID seen out of combat (target/mouseover/nameplate),
            Creature-0-server-instance-zoneUID-npc-spawn; nil until seen
     same run if mapID equal and (copy equal, or copy unknown and re-entered < 30 min after leaving)
     ghost outside keeps the run open (corpse run)
  entries = runs started in the last 3600 s / 86400 s, per account; "Next free entry in 12:30" when at the cap
  per run: time inside; XP gained (LevelLog deltas, levels crossed); kills (XP-giving kill events + PARTY_KILL by you);
           gold looted (money gains while a loot window is open); deaths; RepWatch delta; levels in/out
  ```
  Cap is a setting (default 5/h, 30/day) until settled in game. The page sits in the Dungeons window.
- **APIs:** `IsInInstance` (InstanceDocumentation:170), `GetInstanceInfo` (global; Dungeons already calls it,
  `Dungeons.lua:1155-1160`), `UnitGUID`, `PARTY_KILL` (Dungeons registers it in pcall, `:1305-1306`),
  `PLAYER_MONEY` (CurrencyInfoDocumentation:637), `LOOT_OPENED/LOOT_CLOSED` (LootDocumentation:220/189).
  **In game:** whether creature GUIDs are readable inside Forever instances (round 3 probe says IDs are hidden in
  dungeons; if so, fall back to the 30-minute rule) and Forever's real entry cap.
- **Source:** NIT (ARR) and Memories (GPL) ideas; our own logic.

### 4. GoldGoal: money by source, per level and per hour, without hooks (S/M)
- **Algorithm:**
  ```
  window = last of MERCHANT_SHOW/CLOSED, TRAINER_*, MAIL_SHOW/CLOSED, AUCTION_HOUSE_SHOW/CLOSED (+3 s),
           TAXIMAP_OPENED/CLOSED (+2 s), QUEST_FINISHED (+1 s), LOOT_OPENED/CLOSED, BANKFRAME_*
  PLAYER_MONEY: d = Safe(GetMoney()) - last; if nil keep last
     quest if a QUEST_TURNED_IN happened <= 5 s ago
     repair if window == vendor and d < 0 and the summed equipped durability rose between before/after
     else vendor (+ sell / - buy), trainer, flight, mail, auction, loot; else gain = "other gain", loss = "other"
  totals per level and per day; GoldGoal ETA uses net gold per active hour
  ```
- **APIs:** all events above are documented (MerchantFrame, Trainer, MailInfo, AuctionHouse, TaxiMap, QuestLog, Loot
  docs); `GetInventoryItemDurability` is undocumented but used by DurabilityWatch today.
- **Source:** Memories `Money.lua` window table (GPL); its hook-based refinements replaced by the durability rule.

### 5. Tooltips + QuestMobs: your own drop rates (M)
- **Algorithm:**
  ```
  LOOT_OPENED (not in combat): for slot = 1..GetNumLootItems():
      src = { pcall(GetLootSourceInfo, slot) } -> pairs (guid, quantity)
      for each guid: npc = NpcID(Safe(guid)); first time this guid is seen (ring of last 1000): corpses[npc] += 1
      item = GetLootSlotLink(slot) -> id; drops[npc][id] += 1 once per guid
  tooltip on a unit or an objective item: "You: 7 of 20 (35 %)" from 20 corpses, "(you, 9 so far)" below;
  Forever-new mobs (no cMaNGOS row, round 4 R1) get a rate this way; "kills left" uses it when cMaNGOS has none
  ```
  Bias note on the line: corpses that were never opened are not counted.
- **APIs:** `GetNumLootItems`, `GetLootSlotLink`, `GetLootSlotInfo` (undocumented; BagCheck uses them,
  `BagCheck.lua:217-232`), `GetLootSourceInfo` (undocumented; used live by Polestar Recorder `Finds.lua:579-595`,
  DonData `Learn.lua:639`, DungeonJournal `RPGMode.lua:2172`). Guard the GUID with `Safe()`.
- **Source:** Bestiary Forever (GPL-3.0-or-later) method; no ForeverDB numbers.

### 6. QuestTracker: quest sounds (S)
- **Algorithm:** on `QUEST_LOG_UPDATE`/`UNIT_QUEST_LOG_CHANGED("player")` compare each tracked quest's
  `C_QuestLog.GetQuestObjectives` `numFulfilled`/`finished` with the last snapshot (skip unreadable values; the
  1/1-not-finished guard from round 3 #12 applies); progress → one "progress" sound after 0.5 s, objective finished →
  "objective" sound, quest complete (`C_QuestLog.IsComplete`, QuestLogDocumentation:734) cancels both and plays "complete". Three toggles and a
  sound choice on the hub's settings page; nothing on login or `/reload` (first snapshot is silent).
- **APIs:** QuestLogDocumentation:477 (`GetQuestObjectives`), :1373 (`QUEST_LOG_UPDATE`), UnitDocumentation:4565;
  `PlaySound(SOUNDKIT.*)` in pcall as RareWatch does.
- **Source:** Questie `Sounds.lua` (idea only).

### 7. Dungeons + Tooltips + ItemAdvisor: wish list (M)
- **Algorithm:** a star on each Dungeons loot row and in ItemFinder results adds the item ID to a per-character
  list (optional note, optional "for slot"). Tooltip post-call: "On your wish list - Deadmines, Cookie". Dungeons rows
  show "★2" per dungeon/boss. An entry ticks itself "got it" when ItemFinder sees the ID in any place of that
  character, and turns grey "outgrown" when `ItemAdvisor_IsUpgrade` says no. Hub pop-up when a wish item is in an open
  loot window (`LOOT_OPENED` + `GetLootSlotLink`) or sold by the open merchant (`GetMerchantItemID`, undocumented,
  already used by Landmarks `:678`, SupplyWatch `:273`, PriceMemory `:327`). Never rolls, buys or equips.
- **APIs:** `TooltipDataProcessor.AddTooltipPostCall` (already used by Tooltips), `C_Item.GetItemInfoInstant`
  (ItemDocumentation:659).
- **Source:** AtlasLoot Favourites (ideas only).

### 8. LevelLog: dated journey timeline (S/M)
- **Algorithm:** per character append `{t = GetServerTime(), kind, id, level, map}` for: level up, quest accepted /
  turned in / abandoned (`QUEST_REMOVED` without a turn-in), death (with #1's killer), first visit to a zone
  (`ZONE_CHANGED_NEW_AREA` + `C_Map.GetBestMapForUnit`), new flight path (Landmarks), dungeon run (#3), profession rank
  step, a player note. View by day or by level in LevelLog's window. Cap 4,000 entries; older ones fold into monthly
  counts (owner rule 4, bounded SavedVariables).
- **APIs:** QuestLogDocumentation:1312/1385/1396, UnitDocumentation:3832, MapDocumentation:49/665,
  SystemTimeDocumentation:30.
- **Source:** Questie Journey and AutoBiographer (ideas only).

### 9. LevelLog: lifetime and per-level stats (S)
Counters only, shown as a "Stats" page: kills (and top 20 by NPC ID from `PARTY_KILL` where attacker is you, plus
Field Guide's rule: your target or a visible nameplate died and it wasn't tapped by others, `UnitIsTapDenied`, UnitDocumentation:2365), deaths
by killer (#1), quests, gold by source (#4), time per zone, time on taxis (`UnitOnTaxi`, UnitDocumentation:2570),
distance on foot (1 Hz `UnitPosition` deltas outside instances, jumps > 100 yd ignored), flights, loot by quality.
Source: AutoBiographer (ideas), Field Guide (GPL, kill rule).

### 10. ForeverHub/LevelLog: where your time goes, and a calendar ETA (S)
- **Algorithm:**
  ```
  every 1 s: state = dead (UnitIsDeadOrGhost) | flying (UnitOnTaxi) | fighting (between REGEN_DISABLED/ENABLED)
     | town (IsResting) | afk (no move, XP or money for 180 s) | questing (quest window, turn-in or objective
       change in the last 20 s) | travel (moved) ; add to level[state]
  rate = Σ w_k · xph_k over the last 12 levels, w_k = 0.85^k, levels with xph > 2 × median dropped;
        blend current-level pace at min(0.4, minutesThisLevel/120)
  hoursPerDay = median active hours of the last 7 play days
  "Level 20 about Sat 15 Nov (about 9 h of play at 1.6 h/day)"
  ```
  Extends round 4 R9 (built, "% of the way to 60"); no `RequestTimePlayed`.
- **APIs:** UnitDocumentation:1931/2570, PlayerScriptDocumentation:1471 (`IsResting`); `UnitIsAFK` is
  `SecretInChatMessagingLockdown` (UnitDocumentation:1778), so the 180 s rule is used instead.
- **Source:** LevelETA (MIT, credit).

### 11. MapPins + ZoneLevels: exploration progress and the nearest unexplored spot (M)
- **Algorithm:** `C_MapExplorationInfo.GetExploredMapTextures(mapID)` lists the overlays you have revealed; a shipped
  table of all overlays per Classic map (OpenMap reveal data, MIT, credit; keyed by `fileDataIDs` and offsets) gives
  the rest. Per zone "Teldrassil 14 of 18"; the nearest missing overlay's centre becomes a `/way`-style target on our
  overlay (not the canvas); refresh on `MAP_EXPLORATION_UPDATED`. Names via `GetExploredAreaIDsAtPosition` +
  `C_Map.GetAreaInfo` once discovered. Exploration XP and Legacy exploration challenges both benefit.
- **APIs:** MapExplorationDocumentation:11/27/49, MapDocumentation:34. **In game:** that Forever's Classic maps
  return the same overlay IDs as OpenMap's data.

### 12. Dungeons: Group Finder listings that fit you (S/M)
- **Algorithm:** only after **you** search in Blizzard's Group Finder: `LFG_LIST_SEARCH_RESULTS_RECEIVED` →
  `C_LFGList.GetSearchResults()` → for each `GetSearchResultInfo(id)` read `activityIDs`, `numMembers`, `age`,
  `isDelisted` (all plain fields); map activity IDs to our dungeons (`Dungeons.lua:665-705` table) and show in our
  Dungeons window: "Deadmines: 2 groups (3/5, 4/5). You have 4 quests and 1 wish item there". Never call
  `C_LFGList.Search` (`HasRestrictions`, LFGListInfoDocumentation:572) or apply/invite; never read the `name`/`comment`
  protected strings.
- **APIs:** LFGListInfoDocumentation:394 (`GetSearchResultInfo`, `SecretInChatMessagingLockdown`: pcall + Safe),
  :446, :812.

### 13. PriceMemory: sell speed from your own searches (S)
- **Algorithm:** keep the last result set per item (`auctionID`, `quantity`, `timeLeftSeconds` or band, price). When
  you search the same item again within 15 min, an auction missing now whose time left was longer than the gap counts
  as sold (same quantity reappearing at a new ID from the same price = relist, ignored). After ≥ 10 min of watched
  time: "≈ 6 sold per hour near 12s (lower bound)". No search is ever started by us.
- **APIs:** `C_AuctionHouse.GetItemSearchResultInfo` / `GetCommoditySearchResultInfo` (AuctionHouseDocumentation:374
  /240; structs :1620-1690 carry `auctionID` and `timeLeftSeconds`); events PriceMemory already registers
  (`PriceMemory.lua:507-512`).
- **Source:** Turnover (MIT) method, minus its auto-scans.

### 14. ItemFinder/GoldGoal: mail expiry warning and AH invoices (S)
- Hub pop-up at login when any character's stored inbox items expire within 3 days (expiry is already stored,
  `ItemFinder.lua:341-348`): "Alt: 2 items in the mail expire in 1 day".
- On `MAIL_INBOX_UPDATE`, `GetInboxInvoiceInfo(i)` (undocumented; check in game) for "seller" invoices → item, sale
  price, deposit, fee into PriceMemory as real sale prices and into #4 as "auction".
- **APIs:** MailInfoDocumentation:102; `GetInboxHeaderInfo` (undocumented, used by ItemFinder).

### 15. Tooltips + ForeverHub: grouped-with history and your own player notes (S/M)
Out of combat on `GROUP_ROSTER_UPDATE` (PartyInfoDocumentation:680) record party members' names with date, zone and
run (#3); player tooltip post-call: "Grouped 2× (Deadmines 12 Nov). Your note: great healer" or an "avoid" tag with
your reason. Optional mark on Group Finder rows is **not** done (frame writes); #12's list shows the tag instead.
Never ignores, declines or kicks. Names can be secret in instances: Safe, skip. Extends `thirdparty_features.md` Q19.
Source: Avoided Players (MIT), GrudgeLedger (GPL) ideas.

### 16. RepWatch: repeatable turn-in materials (S, matters from about level 50)
Per faction (Argent Dawn, Cenarion Circle, Thorium Brotherhood, Timbermaw): materials by item ID, bag + bank counts
from ItemFinder, rep per turn-in, "8 more turn-ins (40 Felwood herbs) to Honored". Turn-ins counted from
`QUEST_TURNED_IN`. Data our own (item IDs checked in game); Commissions Forever (GPL) as the checklist.

### 17. ProfessionGuide: craftable now, and materials kept for later steps (S)
From the cached recipes (forever_improvements #17), list what the carried materials make now; mark a recipe
"uses mats step N needs" when it would eat materials a later path step reserves, and show surplus mats with their
PriceMemory value. Source: SkillupHelper idea (licence unconfirmed). APIs: `C_TradeSkillUI.GetRecipeInfo`/
`GetRecipeSchematic` (TradeSkillUIDocumentation:639/753), `TRADE_SKILL_SHOW` (:1387).

### 18. ItemFinder: Bagnon-style icon grid of any character's bags and bank (M)
A grid per character/place from ItemFinder's ID store, quality borders, counts, the existing search as a filter
(dim non-matches), and "in the mail" as its own section. Read-only; our own window. APIs:
`C_Item.GetItemInfoInstant` (ItemDocumentation:659), `C_Item.GetItemIconByID` (:611). Source: Bagnon/Baganator (ideas
only).

### Not taken
Hooks used by Memories (repair, buy, train, mail, resurrect, LowHealthFrame), Turnover's AH auto-scan and chat lines,
NIT's chat/group run summaries and reset announcements, Avoided Players' invite declining and Group Finder frame
outlines, AtlasLoot's `SetItemRef` hook and list sharing, ExplorersMap's canvas pins and chat line, Field Guide's
portrait/nameplate marks, `C_DamageMeter.ResetAllCombatSessions`, `RequestTimePlayed`, `C_LFGList.Search`, loot or
auto-loot helpers (ForeverLootKey, SelectiveLoot), TidyPack's delete prompts, ForeverDB.net data, QuestieDB-derived
data.

## 5. In-game checks for this round
1. `/dump C_DamageMeter.IsDamageMeterAvailable()` and, after a fight, `/dump C_DamageMeter.GetAvailableCombatSessions()`.
2. Die once, then `/dump C_DeathRecap.GetRecapEvents()`: field names (timestamp, sourceName, spellName, amount,
   environmentalType, sourceGUID?).
3. Inside a dungeon, out of combat: is `UnitGUID("target")` readable (zone UID for #3)?
4. Forever's instance entry cap: count entries until "You have entered too many instances recently".
5. `GetLootSourceInfo(1)` on a corpse and on a skinned corpse (two GUIDs?).
6. `GetInboxInvoiceInfo` exists and returns the seller's invoices.
7. `C_MapExplorationInfo.GetExploredMapTextures(1438)` returns overlays matching OpenMap's Teldrassil data.
8. A Group Finder search result's `activityIDs` match the IDs in `Dungeons.lua`.

## Summary

The client gives three read-only sources earlier rounds didn't use: the death recap (`C_DeathRecap`), which names the
real killer instead of guessing from your target (#1); Blizzard's damage meter (`C_DamageMeter`), which allows a
Details-style fight summary after combat without the closed combat log (#2); and Group Finder search results, which
can be matched to your dungeons once you search (#12). Popular Classic addons point to logs and lists we lack: a Nova
Instance Tracker-style run log with hourly entry counts (#3), AutoBiographer/Memories money by source, timeline and
lifetime stats (#4, #8, #9), AtlasLoot-style wish lists (#7), Questie's quest sounds (#6), and personal drop rates
from looted corpses for Forever-new mobs (#5). Licences: Memories, Field Guide, Commissions and Bestiary are GPL-3.0
(portable with credit; Bestiary's ForeverDB data is not); LevelETA, Turnover and Avoided Players are MIT; NIT is All
Rights Reserved and AutoBiographer, Bagnon, Details and Auctionator have no detectable licence (ideas only); AtlasLoot
stays GPLv2-only. Nothing was downloaded or run. Forever's dungeon entry cap and the death-recap field names need an
in-game check before #1 and #3 are built.
