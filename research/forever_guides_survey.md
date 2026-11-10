# Forever quest-guide and leveling-guide addons: survey for LevelGuide and the quest helpers

Date: 2026-11-09. Client: WoW Forever 1.60.1, interface 16001. Read-only research: nothing installed, loaded or run;
everything below is in our own words, no code or guide text copied. RestedXP is covered in `rxp_deep.md` and
`rxp_forever_guides.md` and is skipped here. Questie/QuestieDB, Forever Quest Pins, Forever Quest Tint, Zone Info,
HandyNotes (+ WoW Forever), TomTom are in `popular_quests_maps.md`; Shortest Path, Tweaks, ForeverPlus, OneForAll,
Leatrix are in `popular_qol_routes.md`; GearQuest in `popular_items_spells.md`. Those get one line each in section 2
with only what is new for this question.

## 0. What is new in this pass (headline)

1. **Polestar Guides** (0xFitz, GPL-3.0, 133K downloads in 26 days, updated 2026-11-08/10) is the most complete
   Forever guide engine and ships **forever-db**: an open Forever quest database (quests, givers, turn-ins,
   objectives, prerequisites, spawns, map frames) in JSONL, GPL-3.0 tables plus a CC BY 4.0 "how to do it" layer.
   This is the quest-fact source our routes have been missing (section 4).
2. **Questdon + DonData + DonMap + Leveldon** (DonCoohd, MIT code; data partly GPL-3.0) have the best-documented
   Forever *client* behaviour: which "is this quest available / does it exist / what level is it" answers can be
   trusted on the live server and which cannot.
3. **ForeverWisp** (All Rights Reserved; free 1-20, paid 20-60 packs locked to a BattleTag hash) shows two client
   techniques we do not use: the game's in-world navigation frame (`C_Navigation.GetFrame`) as the anchor for our
   own marker, and native quest destinations from the live map (`GetNextWaypoint`, `GetQuestsOnMap`,
   `GetAvailableQuestLines`) as the only position source.
4. **Guidelime 6.018** (max-ri) has a Forever TOC (`Guidelime-Camelot.toc`, requires Questie on Forever) and the
   **TUGs Forever** guide pack (All Rights Reserved, 4.2M project downloads, levels 12-30 written in beta).
5. **Ding!** (moust4ki, GPL-3.0, gamepad-first) is a smaller GitHub-only guide with its own DingDB; last commit
   2026-10-15 (pre-launch), so stale for launch data.
6. Not inspectable or not relevant: Zygor (paid subscription, Forever guides announced), UpQuest Forever (ARR,
   189 downloads, paid tier), GuiaForever / ForeverGuide (class/talent guides, no questing engine), Forever Quest
   Items (needs QuestieDB), Forever Dungeon Quests (MIT, hand-copied dungeon quest list), ClassicLevelingForever
   (moved to "ElmoLeveling"; XP/hr and kill stats), Forever Level Gains (level-up stat toast), Levelator (no
   CurseForge page found).

## 1. Downloads and malware check

New quarantine folders, each created empty, under
`C:\Users\you\AppData\Local\Temp\claude\cb2f3a55e03b1ab7\c31d37c7-e117-4d9f-bde3-ec6d36fbc336\scratchpad\downloads\`.
Zips were fetched from the CurseForge API download link of the Forever file named on each project page into
`_zips_guides\`, entries listed before extraction (no absolute or `..` paths, every zip starts `PK`), then expanded
into `G_<name>`. Git clones: depth 1, hooks off, LFS smudge off, no submodules.

| Folder | Source | Version | SHA-256 (zip) |
|---|---|---|---|
| G_Polestar | github.com/fitzforge/polestar (linked from CF) | commit bf66c4b, 2026-11-10 (0.3.5 line) | git; checkout of deep `rust/tests` paths failed (Windows path length), every addon, forever-db, guides and docs file is present |
| G_Leveldon | CF 1741614 / file 9449117 | 0.3.1-beta-forever | D9C3AE74...7700A |
| G_Questdon | CF 1723659 / file 9527036 | 1.5.6 | D73FA28E...81F45 |
| G_DonData | CF 1774402 / file 9527023 | 1.2.5 | 6CD5F377...8434E |
| G_DonMap | CF 1774431 / file 9490364 | 1.3.4 | 43DAEA60...33BA1 |
| G_ForeverWisp | CF 1698137 / file 9532843 | 1.8.0 (free part only) | D114E4E3...0AFD1 |
| G_ForeverQuest | CF 1708573 / file 9513178 | 0.22.0 | ED3B7DC6...AECC4 |
| G_Guidelime | CF 327139 / file 9532077 | 6.018 | 84D77D17...08126 |
| G_GuidelimeTUGs | CF 335816 / file 9533265 | GuideLime_TUGs_Forever (1.60.1) | A0B5E4AD...05F25 |
| G_Ding | github.com/moust4ki/DingGuideWoWForever | v1.8.1, fb0a06a, 2026-10-15 | git |

Checks run on every folder: extension census; first bytes of every file for MZ/ELF/PK/7z/RAR/gzip/Mach-O/Lua
bytecode/`#!`; Lua/XML/TOC grep for `loadstring`/`load(`/`RunScript`/`setfenv`/`string.dump`, runs of escaped
bytes, long `string.char` chains, `os.*`/`io.*`, URLs, addon/chat messaging and channel joins, quest/vendor
automation calls, Blizzard hooks and map data providers, CVar writes, combat-log events.

| Addon | Verdict | Notes |
|---|---|---|
| Polestar | **Clean (addon)**; large dev tree not run | Runtime is Lua/TOC/XML/TGA/TTF/OGG. Dev tooling only: Rust crates, Node scripts, 10 shell scripts, a Tauri desktop "Polestar Client" (installs addons, uploads opt-in Recorder sessions), a test-fixture zip, gzip golden files. `loadstring` appears only on the addon's own guide-step text, run with an empty environment (`setfenv(fn, {})`). The navigation packs (`Polestar_Nav_EK/_Kalimdor`) hold zlib-compressed binary walking grids as long strings, decoded with the client's `C_EncodingUtil.DecompressString` as data, never executed. Addon messages to party/guild for friend progress. No URL is fetched (WoW Lua cannot). |
| Leveldon | **Clean** | One `HookScript` on `GameTooltip` (fallback path), addon messages for opt-in step-timing sharing. Comments state it avoids the combat log on Forever. |
| Questdon | **Clean, but network-ish** | Joins a temporary public chat channel (QuestdonNet) and sends addon messages to share learned quest positions, levels and play times ("collect-only mode" exists). Uses `WorldMapFrame:AddDataProvider` + `AcquirePin` for path dots and NPC walks. |
| DonData | **Clean** | `loadstring` only on its own quest-text table string (lazy load). Escaped bytes are localized profession names. |
| DonMap | **Clean** | Map pins through a world-map data provider (`AcquirePin`); header claims no hooks. |
| ForeverWisp | **Clean (free part)** | A pure-Lua SHA-256 used to hash the BattleTag for paid-pack ownership (not obfuscation; we did not and will not look into paid packs). `hooksecurefunc` on `ShowUIPanel` and `StaticPopup_Show`; `HookScript` on `WorldMapFrame` Show/Hide; HBD-Pins (map data provider). |
| ForeverQuest | **Clean** | Two Python files are offline test/build tools (lupa), not run. Bundles Questie's Classic DB sources (GPL-3.0) plus a 7.9 MB generated index. Hides `ObjectiveTrackerFrame` (tracker replacement). |
| Guidelime | **Clean** | `loadstring` only inside CallbackHandler (standard library). Many URL strings are guide-site links in data. |
| TUGs Forever | **Clean** | Guide text only. |
| Ding | **Clean** | `loadstring` of its own zone table string; one `#!` test script (not run). |

No executables, no encoded blobs that are executed, no `os`/`io` use, no HTTP. Rule concerns are about automation,
hooks and map providers, listed per addon below.

## 2. Per-addon sections

### 2.1 Polestar Guides (0xFitz, GPL-3.0 with a guide-pack exception)

**What it does.** Full 1-60 routes for every race and both factions (race start guides incl. Skyborne on Zephras
Isle, then faction routes in 30-40/40-50/50-60 folders), plus class quests, professions, reputations, mounts, pets,
exploration and legacy challenges; quest/mob/item lookup ("Codex"), dungeon guides, rare alerts, gear advice,
XP/hour, travel planner, party sharing, gamepad mode, eight languages.

**Data.** Guides are authored as `.guide` text, compiled offline by a Rust tool ("forge") that orders quests by a
route search and simulator, and shipped as Lua packs. Quest facts come from forever-db (section 4); walking lines
are pre-baked per step; travel uses flight/boat/zeppelin/tram/portal timetables from client tables and
CMaNGOS; walking routes started from Shortest Path Forever (with permission).

**Step model.** A guide is a header (id, levels, zone, faction/race/class filters, `next` with choices and
pros/cons) and steps holding goals. Goal kinds: `goto` (with radius), `accept`, `turnin`, `complete`, `kill`
(tied to `quest Q.O`), `collect`, `interact`, `use`, `talk`, `train`, `vendor`, `buy`, `money`, `destroy`, `wait`,
`task` (manual tick), `sethome`, `hearth`, `getfp`, `fly`, `enter`, `die` (death-skip), `explore`, `level N` /
`level N.frac` / `level N+XP` with `grind <npc>`, `skill`, `learn`, `craft`, `rep`, `achieve`. Step modifiers:
`only <class/race/faction>`, `when <predicate>` (level, money, onquest, complete, turnedin, available, has item,
upgrade, zone/subzone, bound, dungeon chosen, done label, skill, cooldown, knows spell, group chosen), `along
until <label>` (goals done in passing, shown under later steps), `background` (zone-wide slow collections),
`skipto <label> when ...`, `loop` (search points in order), `optional`, `group N`.

**Completion.** Recomputed from live state every time (quest log, completed flags, bags, level, zone, bind
location); saved data only adds the player's ticks/skips and things that cannot be re-read (talk/train/vendor
interactions done during the step, discovered flight paths, quests a giver did not offer). On load it *places*
the player: first step with quest work they have started or can do now. A quest that leaves the log after the
route passed it triggers "go back for it / skip it" (`lostQuests`).

**"While you're here".** A quick objective of a later step whose spawn area is within N yards (default 180, range
60-400), and a ready turn-in whose NPC costs at most N seconds of extra walking (default 20 s), shown as one line
under the current step with a soft chime.

**Arrow and map.** Smoothly damped arrow with distance, ETA, near/far colour, arrival ring, "other continent:
target zone" fallback, tram fallback. Map and minimap pins are frames *parented to the map canvas*, but Polestar
adds no data provider, acquires no pin and calls no map method that writes; its MapCanvas module documents that
Forever's gamepad code walks the map's pins from secure code and blames any addon value it finds there. Minimap
pins use a 10 Hz watcher and a 30 Hz driver only while position/facing/zoom change; pins are indexed by
continent and a yard grid. Route trail dots are anchored at the destination so they stay put while walking.

**Quest helpers.** Quest lines on unit/item/object tooltips via `TooltipDataProcessor.AddTooltipPostCall`, quest
icons on objective-mob nameplates, bag marks on items a quest (in the log or ahead in the guide) still needs,
sell/delete guards, "New in Forever" mark from a generated list of 1,841 quest IDs absent from Classic data, XP
pace (session and 15-minute rate, time to level, kills/quests to level, per-level splits; kill vs quest vs other
XP split by `QUEST_TURNED_IN` xpReward and `CHAT_MSG_COMBAT_XP_GAIN` timing, never parsing the chat text), a guide
level target tick on the XP bar, route XP projection ("this guide takes you to level X") with the client's
grey-quest reduction.

**Forever facts it documents.** Forever's quest log and objective tracker already prefix quest titles with the
level (Camelot `QuestUtilsOverrides.GetQuestTitlePrefix`, called from Mainline `QuestMapFrame.lua:1629` in our
uisrc2); gossip, greeting and detail panels do not. Zephras Isle (2521, client map 2991), Darkspear Islands
(2524, map 2997), Riverglades (2548), Mount Hyjal (2482), Shen'dralas (2652) all have usable world frames in
forever-db's `ui_map` table (contrast with Questie's note that their native rectangles read as zero: worth a live
check of `C_Map.GetWorldPosFromMapPos` on 2521). Skyborne class trainers on Zephras Isle are listed with
coordinates. Forever's combat log is closed; kills are detected from the dead target instead.

**Rule conflicts.** Auto accept and auto turn-in are **on by default**; auto sell junk and auto repair on by
default; optional auto buy, train-all, reward pick, hearth bind, flight-map auto open. Post-hooks Blizzard's quest
log/tracker update functions and bag `UpdateItems` to write text and textures; tracking-menu entries; a step key
that targets mobs. Frames parented to Blizzard's map canvas and the XP bar. All of that is outside our rules; the
read-only parts (step model, completion rules, pace, tooltips through `TooltipDataProcessor`, own-frame pins) are
what we take.

### 2.2 Leveldon (+ DonData, DonMap; Questdon optional) (DonCoohd, MIT code)

**What it does.** One planned route per race (and per start-area choice), with a class overlay and an optional
dungeon overlay, levels 1-30 tested, 30-60 "preview". Route choice after the start zone lists hours, quests and
reputation per option. Speedrun line (your time vs plan, last level-ups, time to next level; clock stops after 2
idle minutes).

**How.** Routes are generated offline (route search, "Human 17.2 h, 231 quests") into a base table plus overlays
(`seq` of base step ranges with inserted class steps, per-step planned level and time, XP overrides where the grey
factor differs). Fit rules: quests outside the route are left alone; a quest you take yourself is fitted into
the route when its objectives lie near a later step and its turn-in at a later stop, else it says it costs extra
time; group/elite quests are left out (list from CMaNGOS quest type plus Forever ones seen in game); timed quests
are done right after accept; one fixed sell stop at each hub (skipped when nothing to sell, bags fine, gear fine);
trainer stops list only the main spells for your talents with prices, and money is budgeted so riding at 40
(120 g; 100 g for paladin/warlock) stays affordable; profession steps placed where money allows; below level 10 a
deliberate death where it beats walking.

**Markers.** Its own coloured marks drawn above the current step's NPC nameplate (gold accept, green turn-in, teal
trainer, orange vendor, violet flight master/innkeeper, red named mob), because Forever reserves `SetRaidTarget` to
Blizzard's UI. Bag frames on items a later quest needs.

**Rule conflicts.** Slash commands for most settings (window exists), opt-in sharing over addon messages, relies on
Questdon's auto accept when present (it tells Questdon which quests to leave alone).

### 2.3 Questdon (+ DonData, DonMap) (MIT)

**What it does.** Quest helper: available quests, objective mobs with all spawns, turn-ins on world map,
minimap and nameplates; quest list with compass and arrow; quest book (journal, zone and dungeon views, search,
chain graph); XP bar; auto accept/turn-in (skips breadcrumbs and gold-cost quests); junk selling, auto repair, fast
loot; crowd-sourced data.

**Forever client knowledge (the valuable part, all from DonData's engine comments):**
- `C_QuestLog.RequestLoadQuestByID` + `QUEST_DATA_LOAD_RESULT(success=false)` is **not** a "quest does not exist"
  signal on Forever live: the server answers false for many real quests it does not want to hand out right now
  (2,481 marked missing, including quests their characters had turned in). Turned off on Forever; kept on Era.
- `C_QuestLog.GetQuestDifficultyLevel(id)` after a load request returns the **server's** quest level even for
  quests not in the log; Forever levels differ from Classic data (example given: The Defias Brotherhood 14 in ATT,
  18 on the server). They scan all known IDs slowly (one at a time, never in combat) and keep only differences.
- `C_QuestLine.GetAvailableQuestLines(map)` after `RequestQuestLinesForMap`, refreshed on `QUESTLINE_UPDATE`: a
  listed quest is available; a quest of a known quest line that is not listed is "not yet"; an empty list is
  *no answer* (the API may not know Classic quests at all).
- What the NPC actually offers in `GOSSIP_SHOW` / `QUEST_GREETING` is ground truth: a quest the data calls
  available but the NPC did not list is "not offered at level L" for that character, cleared on level-up, on a
  turn-in at that NPC or nearby, or after a timeout. One dialog without it hides it once the character is at the
  game-shown quest level or above; below that, three different levels are needed. Never hide a quest the game
  itself lists.
- Map-to-world conversion: ask the client for three corners once per map and do the rest by arithmetic (checked
  against the client on the first real point), instead of two vector calls per point.

**XP.** Bar segments: current XP, XP of finished quests waiting in the log, rested. An XP-source check splits
gains into kill (with rested/group bonus from `CHAT_MSG_COMBAT_XP_GAIN` parsed with the client's own
`COMBATLOG_XPGAIN_*` format strings), quest (`QUEST_TURNED_IN`), exploration (`ERR_ZONE_EXPLORED_XP`), rested
growth.

**Rule conflicts.** Auto accept/turn-in, junk selling, auto repair, fast loot; joins a public channel; world-map
data providers (`AddDataProvider`/`AcquirePin`) and hiding the game's quest markers (DonMap API v4) - the exact
pattern that triggered our "blocked from an action" pop-up.

### 2.4 ForeverWisp (ARR; free 1-20 for all start areas, paid 20-60)

**What it does.** Guide panel with nearby objectives, arrow or in-world marker or WaypointUI, map pins and
"search area" shading, nameplate icons, talent plans, optional dungeon detours, gathering guides, party sharing,
quest-log review, catch-up.

**Techniques worth knowing.**
- Positions without a spawn database: for an accept step, `C_QuestLine.GetAvailableQuestLines(map)` (and
  `GetQuestsOnMap` with `isQuestStart`); for an in-log quest, `C_QuestLog.GetNextWaypoint(questID)` then
  `GetQuestsOnMap`; walks the player's map and up to 5 parents; caches 0.5 s; invalidates on `QUEST_POI_UPDATE`,
  `QUEST_LOG_UPDATE`, zone change. Marks such points "approximate".
- In-world marker: after `C_Map.SetUserWaypoint` + `C_SuperTrack.SetSuperTrackedUserWaypoint(true)`,
  `C_Navigation.GetFrame()` returns the game's navigation frame (may arrive a moment later); Wisp reads its screen
  position and draws its own card beside it. `C_Navigation.GetDistance()`, `GetTargetState()`,
  `HasValidScreenPosition()`, `WasClampedToScreen()` exist in our uisrc2 (`InGameNavigationDocumentation.lua`).
  Wisp also lowers the native artwork's alpha while its card shows (a write to a Blizzard frame).
- Waypoint etiquette: remembers the user's own waypoint and supertrack state and restores them.
- Search areas: a radius (or ellipse) per location drawn as a shaded disc, separate from the arrival radius.
- Catch-up: picks an authored entry point by level, then by real quest history and current work/location;
  "deferral never becomes completion evidence".
- Quest-log review: lists log quests the guide (and the next guides) no longer uses, with Keep/Abandon defaults
  (elite/group/dungeon/class/profession quests start at Keep); abandons only after confirmation.

**Rule conflicts.** Opt-in quest automation; `hooksecurefunc` on `ShowUIPanel` and `StaticPopup_Show`;
`HookScript` on `WorldMapFrame`; HBD-Pins (map data provider); paid content locked to a BattleTag hash (we did not
inspect paid packs).

### 2.5 Guidelime 6.018 + TUGs Forever

**What it does.** Generic guide viewer; guides are separate addons in Guidelime's bracket syntax (accept, turn-in,
complete, goto with coords, level, XP, train, hearth, fly, etc.). The Forever build needs Questie (it reads quest
positions and objectives from Questie's DB). It maps Forever zones 2482/2521/2524/2548/2652 by name, wraps
`RegisterEvent` with `C_EventUtils.IsEventValid` because Forever **throws on unknown events**, and detects the
flavor by interface 16000-19999.

**TUGs Forever.** All starting zones; 12-30 written in beta; 30-60 currently the Classic route; dungeon quests up
to Dalaran (Forever dungeon). All Rights Reserved: usable only as a cross-check of quest order, not as data.

**Rule conflicts.** Auto accept "Current" and skip cutscenes on by default; gossip auto-select; `hooksecurefunc`
on `TakeTaxiNode`; `HookScript` on `WorldMapFrame` OnUpdate and quest log; HBD-Pins.

### 2.6 Ding! (GPL-3.0, GitHub only)

Gamepad-first guide with offline-generated XP/hour routes (no quest more than one level above you), class and
dungeon packs, resume logic (finish quests already in the log, then skip completed steps), NPC directory, problem
reporter. DingDB (from Questie/QuestieDB, GPL-3.0, names in nine languages) via `LibDingDB`; Polestar's
`LibForeverData` answers in the same shapes. Automation (accept/turn-in/reward) and a `TakeTaxiNode` post-hook.
Last commit 2026-10-15, so launch-day quest changes are not in it.

### 2.7 ForeverQuest (ARR)

Quest tracker that hides Blizzard's tracker, clustered map markers, dotted minimap guidance, auto destination
(nearest / accepted first / turn-ins first), nearby quest discovery, armor reward preview with "confirm before
claim", opt-in automation. Data: Questie's **Classic** DB (3,772 quests), explicitly not verified for Forever.
One idea worth keeping: **personal location corrections** saved per character (player says "the giver is here").

### 2.8 Already studied, what matters for this question

- **Questie Forever / QuestieDB**: the upstream source most Forever guides use; Forever store with new zones and
  98xxx quests; incomplete for new content. Map pins through providers.
- **ForeverQuestPins**: quest starts on the world map; completed-quest set from `GetAllCompletedQuestIDs`.
- **ForeverQuestTint**: marks Forever-new quests; Polestar now has a generated 1,841-ID list for the same job.
- **HandyNotes_WoWForever**: points of interest only, no quests.
- **ShortestPathForever**: route planner; Polestar's walking router started from it.
- **ZoneInfoForever**: zone level ranges incl. Forever zones.
- **OneForAllForever / TweaksForever / ForeverPlus**: XP/hour, time to level, quest XP overlay; no route engine.
- **GearQuestForever**: leveling gear per slot with quest sources (gear, not routing).

## 3. What our LevelGuide and quest helpers lack, ranked

Ranking = value for a solo leveler on this client, weighted by how cheaply and safely we can build it read-only.
"Source" says where the facts come from. Every item uses our own frames, no hooks, no Blizzard frame writes, no
data providers.

| # | Gap (helper) | How to build it read-only on this client | Data source |
|---|---|---|---|
| 1 | **Quest facts by ID for every route step** (LevelGuide, Routes.lua, Prereqs.lua). Routes are keyed by title with hand-typed coords and research notes; prerequisites by title (see `levelguide_questtracker.md` #13, #14). | Offline script (ours, run outside the game) that reads forever-db JSONL and emits a compact Lua table: quest id -> level, min level, side, races/classes masks, giver (npc/object/item id), turn-in id, prereqs (all/any, breadcrumb), objectives, XP. Coordinates from `spawn` + `ui_map` (world yards -> map percent). Routes then reference IDs; titles become display only. Keep the credit block and GPL notice for the derived table. | forever-db `quest`, `quest_start`, `quest_end`, `quest_prereq`, `quest_objective`, `spawn`, `ui_map` |
| 2 | **Placement / catch-up from the quest log** (LevelGuide). We pick a route by level and zone and step through; a character who skipped around lands on the wrong step. | On login and on log changes, put the current step at the first step whose quest is in the log, ready, or available now (by #1's prereqs + completed set), passing what blocks earlier steps; never mark anything done from deferral. Keep player skips. | quest log, `GetAllCompletedQuestIDs`, #1 |
| 3 | **"While you're here" line** (LevelGuide). We show the current step only. | For later steps in the same zone: if the player is within ~180 yd of a kill/collect objective's spawn area (from #1 spawns, or the live `GetQuestsOnMap` point), or a ready turn-in NPC is a short detour, show one line under the step. Distances with our existing `MapScale` / world conversion. | #1 spawns, `C_QuestLog.GetQuestsOnMap`, `GetNextWaypoint` |
| 4 | **Server quest level** (QuestTracker, LevelGuide, QuestCheck). Our level/colour comes from route data; Forever changed many levels. | For quests we care about (route steps, offers), call `C_QuestLog.RequestLoadQuestByID`, then read `C_QuestLog.GetQuestDifficultyLevel` on `QUEST_DATA_LOAD_RESULT`; rate-limit (one in flight, not in combat), cache per client build. Do **not** treat `success=false` as "quest gone" on Forever. Colour by difficulty vs player level. Skip in the quest log/tracker: Forever already prefixes levels there. | client API (verified in uisrc2 `QuestLogDocumentation.lua`) |
| 5 | **"Not offered here" memory** (LevelGuide; replaces the risky absence-from-questlines logic, `levelguide_questtracker.md` #7). | On `GOSSIP_SHOW` / `QUEST_GREETING` read the offered quest IDs (we already read them, `LevelGuide.lua:1497-1510`). A route pick-up from that NPC that is not listed: mark "not offered at level L" per character, clear on level-up, turn-in at that NPC, or timeout; never hide a quest the game lists. An empty `GetAvailableQuestLines` result means "no answer", not "unavailable". | gossip/greeting events, NPC ID from `UnitGUID("npc")` (secret-guarded) |
| 6 | **XP waiting in the log and route projection** (LevelGuide header, QuestTracker). | Sum `GetQuestLogRewardXP` of ready quests -> "+N XP waiting" segment in our own bar; project route end level by summing #1's XP for remaining steps (apply the grey-quest reduction from player level vs quest level); show "this route takes you to ~L". Split live gains with `QUEST_TURNED_IN` (payload has xpReward) and `CHAT_MSG_COMBAT_XP_GAIN` timing, without parsing chat text (can be secret). | client API + #1 xp |
| 7 | **Horde, Skyborne and missing Alliance starts** (Routes.lua has Alliance only, no Coldridge/Elwynn/Westfall/Redridge for Humans, no Zephras Isle, no Riverglades route). | Author our own routes from #1 facts; use Polestar's open guides and TUGs only as a cross-check of order, never copied. Zephras Isle trainers and quest IDs (924xx/944xx) are in forever-db. | forever-db; cross-check Polestar guides (GPL) / TUGs (ARR, read only) |
| 8 | **Native quest destinations as fallback** (LevelGuide, QuestTracker). Partly there (`GetNextWaypoint`, `GetQuestsOnMap`). | Add `GetAvailableQuestLines` positions for accept steps, walk up to 5 parent maps, cache 0.5 s, invalidate on `QUEST_POI_UPDATE`; label such points "approximate". | client API |
| 9 | **Cross-zone travel hint from the game** (LevelGuide arrow). Our cross-zone case says "other zone" plus our `ways` table. | After setting our user waypoint and supertracking it, read `C_Navigation.GetNextWaypointForMap(currentMap)` (x, y, description such as a boat or portal) and `C_Navigation.GetDistance()`; show that text and point our arrow at that point. Read-only, no frame writes. Check `issecretvalue` (secret arguments are allowed only untainted). | client API (`InGameNavigationDocumentation.lua`) |
| 10 | **Bag marks for items a quest still needs** (QuestCheck / Tooltips). | Our own small overlay frames on top of bag buttons would mean reading Blizzard bag frames; safer: a tooltip line via `TooltipDataProcessor.AddTooltipPostCall(Item)` "Needed for <quest> (in log / ahead in guide)" plus a warning row in QuestCheck's window listing such items. | quest log objectives + #1 objectives |
| 11 | **Timed and group/elite quest flags** (LevelGuide). We order timed quests (`PutTimedFirst`) but have no data source. | From #1: `step` rows with timers ("gotcha"), `mechanic` rows `group/elite`; show a "group" tag and leave group quests out of the default route unless the player opts in. | forever-db `step`, `mechanic`, `quest.type` |
| 12 | **Route choice cards** (LevelGuide). We take the first route that fits the level. | At a branch, a small window listing the candidate zones with est. hours / quest count / total XP (from #1 + #6 projection); player picks; remember per character. | #1 + own estimates |
| 13 | **Search-area shading and step map dots** (MapPins). | Draw a translucent disc (radius from spawn spread in #1) on our UIParent overlay; keep pins out of Blizzard's canvas. | #1 spawns |
| 14 | **NPC marks over nameplates for the current step** (QuestMobs). | We already anchor our own marker next to nameplates; add the current step's giver/turn-in/trainer/vendor/flight master by NPC ID (secret-guarded GUID), with a colour per role. Never `SetRaidTarget` (Blizzard-only on Forever). | #1 NPC ids, `UnitGUID` |
| 15 | **Quest chain view** (QuestTracker or LevelGuide tooltip). | Build before/after graph from #1 prereqs; show "part 3 of 6, next: <title>" and branches; filter by race/class/side masks (keep bits above 2^31 for Skyborne). | forever-db `quest_prereq` |
| 16 | **Per-character location corrections** (LevelGuide). | Right-click a step -> "the NPC is here": store map+x+y per quest/NPC and prefer it over route data. Pure SavedVariables, capped. | player |
| 17 | **Quest-log review window** (QuestCheck). | List log quests the active route no longer uses, gray quests, group quests; show only (no abandon button calling `AbandonQuest`; the player abandons in the log). | quest log + route |
| 18 | **Riding money check at 38-40** (LevelGuide or GoldGoal). | Show "riding at 40 needs 120 g (100 g paladin/warlock in Forever per Leveldon); you have X" from `GetMoney`. Verify the cost in game first. | Leveldon note (unverified) |

Not recommended: auto accept/turn-in, auto sell/repair, train-all, auto reward, hiding the native tracker or quest
markers, map data providers, pins parented to the map canvas or XP bar, joining public channels, slash-only
features.

## 4. Downloadable Forever quest databases

| Database | What | Licence | Use for us |
|---|---|---|---|
| **forever-db** (in the Polestar repo, `forever-db/`; releases tagged `data-vYYYY.MM.N` with a zip and a sqlite file; `LibForeverData` as `lib-v*` releases) | Release 2026.11.1, client build 1.60.1.70532. 5,287 quests (97.8% of 5,408 known; 871 with IDs 90000+), 5,407 starts, 5,134 ends, 6,338 objectives, 3,811 prerequisite links (mode all/any, breadcrumb flag), 6,200 rewards, 13,239 NPCs, 10,437 objects, 88,761 spawns (world yards, x north / y west, per client map id), 59 `ui_map` frames (incl. 2482, 2521, 2524, 2548, 2652, 2665), 3,401 mechanics (object-click, group/elite...), 2,409 "how to" steps (timers, gotchas). Coverage stats and a changelog per release; corrections file with sources. | Tables GPL-3.0; own steps/notes/schemas CC BY 4.0 | **Best fit.** Facts for routes and prereqs (#1). Generate our table offline with our own script; keep attribution (NOTICE.md lists EG Link CC BY 4.0, CMaNGOS GPL-3.0, VMaNGOS/Factoruide GPL-2.0+, ForeverTDB GPL-2.0, QuestieDB, pfQuest MIT, client tables). Since our suite is not GPL-licensed as far as we know, decide the licence question before shipping derived data inside the addon; using it to check and correct our hand-made routes is fine either way. |
| QuestieDB Forever store | Quest/NPC/object/item for Forever (data seeded from Era, Forever quests added as researched) | No data licence stated; Questie moving to GPL-3.0 | Already cited in Prereqs.lua; forever-db includes its facts and adds others. |
| DonData (`Data/*.lua`) | Quests from All The Things (MIT) + extras, spawns, quest texts, NPC walks (CMaNGOS GPL-3.0), dungeon levels/entrances, services, learned facts | MIT code; ATT part MIT; walks GPL-3.0 | Second opinion on spawns and services; quest texts are game text, do not reuse. |
| DingDB / LibDingDB | Questie-derived, names in 9 languages | GPL-3.0 | Localised names only, if ever needed. |
| ForeverDB.net | Web database (trainers, vendors, Forever quests) | site says GPL-3.0 with attribution (per Leveldon) | Read as a web reference when checking single facts. |

## 5. APIs confirmed useful on this client (from these addons, checked in uisrc2)

- `C_QuestLog.GetNextWaypoint`, `GetNextWaypointForMap`, `GetQuestsOnMap`, `GetDistanceSqToQuest`,
  `GetQuestDifficultyLevel`, `RequestLoadQuestByID` + `QUEST_DATA_LOAD_RESULT(questID, success)`.
- `C_QuestLine.GetAvailableQuestLines`, `GetQuestLineQuests`, `RequestQuestLinesForMap`, `QUESTLINE_UPDATE`.
- `C_Navigation.GetFrame`, `GetDistance`, `GetNextWaypointForMap` (secret arguments allowed only untainted),
  `GetTargetState`, `HasValidScreenPosition`, `WasClampedToScreen`.
- `QUEST_TURNED_IN(questID, xpReward, moneyReward)`; `CHAT_MSG_COMBAT_XP_GAIN` (text may be secret; use timing,
  not parsing, or parse only when `issecretvalue` is false).
- `TooltipDataProcessor.AddTooltipPostCall` for Unit/Item/Object lines.
- `C_EventUtils.IsEventValid` before registering optional events (Forever throws on unknown names).
- `C_EncodingUtil.DecompressString` / `DecodeBase64` for compact shipped data (decode as data only).

## 6. Summary

Six real Forever guide engines exist now (RestedXP, Polestar, Leveldon, ForeverWisp, Guidelime+TUGs, Ding) plus
quest helpers (Questie, Questdon, ForeverQuest, FQP). All of them automate quest accept/turn-in to some degree
(Polestar and Guidelime by default), and most put pins into Blizzard's map through data providers or canvas
children; none of that fits our rules. What we can take is data and logic: forever-db gives us quest IDs, givers,
turn-ins, prerequisites, objectives, spawns and map frames for Forever under open licences, which fixes the
biggest weakness of our title-keyed, hand-typed routes; Questdon's notes tell us which client answers to trust
(server quest level yes, "load failed" no, empty quest-line lists no, gossip offers yes); Polestar shows the step
model, placement-from-log and "while you're here" logic; ForeverWisp shows how to use `C_Navigation` and native
quest points without any database. No malware was found; the network-like behaviour is limited to addon messages
and, in Questdon, a public data-sharing channel.
