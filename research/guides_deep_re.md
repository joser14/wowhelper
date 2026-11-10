# Forever leveling-guide engines, reverse-engineered for LevelGuide

Date: 2026-11-09. Client: WoW Forever 1.60.1 (interface 16001). Read-only study of the quarantined copies under
`C:\Users\you\AppData\Local\Temp\claude\cb2f3a55e03b1ab7\c31d37c7-e117-4d9f-bde3-ec6d36fbc336\scratchpad\downloads\`
(paths below are relative to it). We ran, loaded, built and decoded nothing. All logic is written in our own words as
pseudologic. Line numbers are approximate (about ±5 lines). This builds on `forever_guides_survey.md` (breadth) and
`rxp_deep.md` (RestedXP) and does not repeat them.

Our project is GPL-3.0 (`LICENSE`, `NOTICE.md`). Code may be ported from GPL-3.0 and MIT sources with attribution.
Sources that are All Rights Reserved or carry no licence are reimplemented from the idea only.

## 0. Headline findings and corrections to the survey

1. **Polestar is the reference engine.** It has the deepest code and an open licence:
   - addon code is GPL-3.0-only;
   - `Polestar_Nav` is GPL-3.0-or-later;
   - forever-db tables are GPL-3.0, with CC BY 4.0 for its notes and steps.

   It recomputes progress from live state every evaluation. It places the player from the quest log, and its
   "while you're here" uses a detour cost in seconds. Its XP model and simulator have exact formulas, it routes
   walking with HPA* on a 4.17 yd grid, and its travel planner is a Dijkstra over flights, boats and hearth. Its
   offline route optimiser is a local search priced by an XP/time simulator, not TSP or annealing.
2. **Guidelime has no route optimiser.** The survey's hint is wrong: steps run strictly in guide order, and it has
   no TSP or nearest-objective ordering. The only nearest-choices are which spawn cluster to point at and which
   flight master to use. Guidelime is **All Rights Reserved** (every TOC, line 8), so we reuse ideas only.
3. **ForeverQuest is GPL-3.0, not ARR.** `ForeverQuest\COPYING` is the full GPL v3 text, and `ATTRIBUTION.md`
   credits Questie. The TOC has no licence field. The survey's §2.7 label is wrong.
4. **Leveldon has no licence for most of its code or its routes.** Only `Training.lua` is GPL-3.0, per README and
   `LICENSE-GPLv3.txt`, with the WhatsTraining MIT notice. Questdon, DonMap and the DonData engine are MIT. Parts of
   DonData's data are GPL-3.0 (CMaNGOS) or MIT (ATT). We reimplement Leveldon's ideas and do not copy them.
5. **Ding allows quests up to +2, not +1.** Its README says "no quest more than one level above", but the generator
   code allows quests up to +2 levels and mobs up to +1 (`G_Ding\tools\route_model.lua:44-50`).
6. **Only ForeverWisp uses `C_Navigation`, and it is ARR.** No GPL or MIT engine uses it. Polestar and Ding use
   `C_Map.SetUserWaypoint` + `C_SuperTrack` as an optional bridge only.
7. **No engine trusts an empty `C_QuestLine.GetAvailableQuestLines` result.** Polestar never calls it; it treats the
   open NPC window as the authority. DonData treats an empty list as "no answer". Our `ReadOffers`
   (`LevelGuide.lua:692-712`) uses it as a positive source, which is fine. It must never be used as a negative
   source (see item 3 of the build list).
8. **Polestar's shipped walking grids carry a permission caveat.** They are derived from "Leffe's navigation maps",
   whose permission was given to Polestar's maintainer. Ask before shipping them (section 10).

---

## 1. Polestar runtime engine (`G_Polestar\addon\Polestar`, GPL-3.0-only)

The core is `Core\Engine.lua`, about 10.9k lines in one file ("E:" below). Its private helpers live on an `Own`
table to dodge Lua's 200-local cap.

### 1.1 Design principle

Progress is never stored as an index. On every evaluation it is recomputed from the quest log, completed flags,
bags, level, zone and bind location (E:1-22).

SavedVariables hold only what cannot be re-read:
- player ticks and skips;
- latched results;
- `when` outcomes;
- lost-quest holds;
- talk/train/vendor interactions;
- discovered flight paths.

Losing the SVs costs preferences, never the place in the guide.

### 1.2 Choosing the step

```
computeCurrent():                                   -- E:3500
  if partyHold: keep the step
  for s in steps (in order):
    if not stepApplies(s): continue                 -- `only` class/race/faction AND `when` predicate (E:118)
    if skipped[s]: continue
    if holdsBefore(s): return the level-gated accept that holds a dungeon guide
    if jump(s): mark s..label-1 "jump"-skipped; continue   -- skipto
    if flightJudged(s): continue                    -- travel planner flies past it
    if not stepDone(s): return s
  return levelHold or end-of-guide

stepDone(s):                                        -- E:2990
  along step, or hearth-only step -> done
  unanswered `when group` -> wait
  every goal that "holds" (not a note, not optional, not a side-vendor next to real work), applies, and is not
  marked unavailable -> goalDone; or flightPassed
```

- **Viewing another step** (Prev/Next/click) sets a "pin" view and changes nothing (E:6986-7008). The pin follows
  forward as the viewed steps get done, and is released when it reaches the live step.
- **`when` predicates** (E:698-754):
  - level, with a fraction of the level;
  - money;
  - quest state: onquest, complete, turnedin, available;
  - has, upgrade;
  - place: zone, subzone, bound (names localised via `C_Map.GetAreaInfo`);
  - dungeon, done `<label>`, skill, cooldown, knows, group;
  - `neg` inverts any of them.
- **Latching** (`latchWhen`, E:821): once the route passes a step and the log has loaded, the `when` outcome is
  frozen. A step that held stays, and a failed one stays skipped. This stops steps flickering in and out when
  state changes later.
- **`skipto`** (E:3459): it never fires before the first `QUEST_LOG_UPDATE`, and never on a step the player chose
  to keep.
- **`along [until L]`** (E:916-1007): the route walks past these steps. While the live step is between them and
  label L, their open goals are listed under the live step. After L, goals of quests still in the log stay listed.
  `background` is the same thing for zone-wide slow collections. `loop` turns the step's gotos into a circuit of
  spots, at compile time.
- **Group quests**: `when group <q>` reads the per-character answer ("ask"/"do"/"skip"). The step waits for an
  answer only while the quest can actually be taken now (E:654-681).
- **Guide chaining** (`routeNext`, E:6444):
  1. a single `next` → take it;
  2. exactly one option left after the race/class filters and `nextWhen` → take it;
  3. otherwise the choice remembered per character;
  4. otherwise "recommended": not out-levelled first, then travel seconds in 60 s bands, then author order;
  5. otherwise ask the player (pros/cons card).

  During catch-up it prefers the option with the most quest work already done (E:6431).

### 1.3 Placement on load (catch-up)

`place()` (E:3258-3449) runs for 10 s after load, or until the first `QUEST_LOG_UPDATE`.

```
start  = first applicable, open, non-skipped step with started quest work (quest in the log)
         or a doable accept (no minLevel/pre gate, not new in a pack update)
anchor = scanning from the end: last step holding a done quest goal or an objective with progress,
         counting only quests the guide itself gives at or before that step
         (class/race-only goals and optional goals are not evidence)            -- anchorStep E:3062
for every step before max(start, anchor):
  pass it if all its open goals are:
    accepts gated by level/prereq       -> mark "unavailable" (reason) for the session
    soft goals (manual/latch/bag count) behind the anchor whose follow-up quest work is done or under way
    travel when the player already stands within HERE = 150 yd of the start step's work
  passed soft goals are written as check-offs (session-only if the guide was passed "for" the player)
optional (behavior.skipGrey): catchUp leaves out green accepts (qlvl < level-2) behind the anchor
  unless a still-worthwhile quest needs them (BFS over pre/preAll across chained guides, needsFrom E:209);
  at >= maxLevel+2, drop grey/green accepts that fewer than CHAIN_WORTH = 3 yellow+ quests need
```

### 1.4 Completion per goal kind (`goalDone`, E:2792-2953)

**General rules**
- A stored tick counts for every kind except `accept`. An accept is never satisfied by a tick.
- "Latchable" kinds are frozen once the route passes them (E:2384, `latchPassed` E:3524): goto, explore, die,
  sethome, hearth, fly, getfp, enter, buy, non-quest collect, money, destroy, wait, abandon.
- Bag counts are latched inside their own step, so spending the items does not reopen it (E:3548).

**Quest goals**

| Kind | Done when |
|---|---|
| accept | In the log, or turned in, or abandoned by the guide's own `abandon`, or held as a lost quest. |
| turnin | In the session `turnedIn` set (filled from `QUEST_TURNED_IN`, because the completed flag lags), or `IsQuestFlaggedCompleted`. Repeatables latch per hand-in. |
| complete | Turned in, or ready for turn-in (`ReadyForTurnIn` or `IsComplete`). |
| kill / interact / use / collect with a quest | Read from the objective line (see below). |
| kill / interact / use without a quest | Done once a later quest goal in the same step is done. |
| collect without a quest / buy | `GetItemCount >= count`. A starter item is done once its quest is taken. |

How the objective line is read (`objectiveLine` E:2472):
1. Strip the counts from every objective label.
2. Match the goal's localised target name against the labels: an exact match wins; otherwise the shortest label
   that contains the name.
3. If nothing matches, fall back to the compiled objective index. This survives reordered objectives.

Edge cases:
- If the quest is in the log but its objectives are not filled in yet, the answer is "not done" rather than a
  guess (E:2531).
- Event objectives of 0/0 are normalised to 1/1 (`Compat` :349).
- "Uses-only" items are counted in the bags.

**Travel goals**

| Kind | Done when |
|---|---|
| goto | The 0.5 s poll has seen the player inside `r` (default 8 yd, plus the spot radius). Also done when entering the goal's named subzone indoors after being seen outside (cave mouths, E:5909). Also done when a later goal in the step is done; trailing gotos are done when the next step's quest work is done. |
| fly | Landed within 30 yd of the landing node and off the taxi, or the zone/subzone name matches. |
| hearth / enter | Zone or subzone text equals the area name. |
| sethome | Bound inn matches. `sethome nearest` latches on `HEARTHSTONE_BOUND` with the NPC whose window was open or closed within 120 s. |
| getfp | Node recorded from the flight map, or name prefix match. |
| die | Alive within 40 yd of the spirit healer (`PLAYER_ALIVE`/`PLAYER_UNGHOST`). Only when deathskips are on, never in Hardcore. |

**NPC interactions**

| Kind | Done when |
|---|---|
| talk / train / vendor | Never read live, only latched while the step is live. vendor/taxi: when the window opens. talk: only when the player acts, via a post-hook on SelectOption/AcceptQuest/CompleteQuest/GetQuestReward or a `QUEST_ACCEPTED`/`TURNED_IN` within 2 s of the window closing. Opening a gossip window proves nothing. train: a spell learned while the trainer is open; `train class` also when the trainer lists no available service. |

**Character state**

| Kind | Done when |
|---|---|
| level N / N.frac / N+xp | Level reached; the step shows the XP still needed. `grind <npc>` points at the mob's spots. |
| skill, learn, craft, rep, cast, explore, money, wait, task, abandon, destroy | Read directly. `wait` counts down once the step's earlier goals are done. `task` is a manual tick. If the client lacks the API, the goal becomes a manual tick. |

**Timing and Forever quirks**
- Evaluation is coalesced to at most one every 0.1 s (E:73, 7262).
- Arrival is polled every 0.5 s, only while needed.
- `levelSeen` (from `PLAYER_LEVEL_UP`) overrides a lagging `UnitLevel`.
- Missing quest data: it requests it with `C_QuestLog.RequestLoadQuestByID`, and one `QUEST_DATA_LOAD_RESULT`
  triggers one redraw (`Core\Names.lua:347`). Names come from the client first, then the locale pack, then the
  English title.
- **Pack updates remap progress.** Step keys are djb2 hashes of step content, and ticks follow their steps by an
  LCS over the old and new key sequences (`matchSteps` E:4910-4967).
- Secret values go through `Compat.Readable`/`IsSecret` (`Compat.lua:42-51`). The XP chat text is never parsed.
- There is no combat log. Kills are counted only through objective lines. "Fighting here" comes from sampling
  `UnitAffectingCombat` in the poll.

### 1.5 Gossip availability and lost quests

- **`checkOffers`** (E:10895-11045) runs on `GOSSIP_SHOW`, `QUEST_GREETING` and `QUEST_DETAIL`. It reads the
  offered IDs, and counts active quests as offered too, because the window updates before the log.

  ```
  for each accept at this NPC in the current step that was NOT offered:
    if data explains it (level too low, missing prereq) -> mark "unavailable", unless that prereq is ready to hand in
    else -> do NOT skip; show "Not offered by X? report it" and keep the accept open
  ignore QUEST_DETAIL windows within LIST_WINDOW = 30 s of a list/turn-in at the same NPC
  clear marks on level-up or any turn-in
  an NPC's actual offer overrides a data prerequisite
  ```

  `GetAvailableQuestLines` is never called.
- **Lost quests** (`holdLost` E:6748): when the computed step moves backwards, look at the accepts between the new
  and old step whose quest left the log (the `QUEST_REMOVED` set). The outcome depends on `behavior.lostQuests`:
  - "ask": hold the accept as done, grey out its goals, and point the arrow back at the giver until the player
    answers "back" or "skip";
  - a failed quest that was then abandoned always goes "back".

  `SkipQuest` skips every goal of that quest and its follow-ups (`preBlocked`).

### 1.6 "While you're here" (E:8316-9700, `UI\WhileHere.lua`)

**Candidates** are goals of later steps on the player's current uiMap, indexed once per guide:
- kill/collect/interact/use: the quest is in the log, not failed, not ready, has work left, and its mobs are at most
  `level + 2`;
- ready turn-ins, other than the live step's;
- "take" accepts within the next 5 steps.

**Distance** is to the nearest spawn-spot centre. If a mob of the goal was "seen" in the last 5 s (nameplate added,
target or mouseover), the distance is capped at 30 yd.

**Turn-in detour cost**

```
extra_yd  = d(P,NPC) + d(NPC,W) - d(P,W)         (or 2*d(P,NPC) without a waypoint / other continent)
seconds   = extra_yd * 1.25 / 7                   (winding factor, run speed)
budget    = whileHereTurninSeconds (default 20, 0..60)
            * 2 if waiting for the route's own turn-in would lose XP (grey share drops, hereXpLoss E:8904)
            + credit: route walking saved when the NPC's later step is only ready turn-ins + accepts (drop < 10 s)
```

**When a line shows**
- Work goals: `d <= whileHereRadius` (default 180 yd, range 60-400). A check by the walking router must also pass:
  router seconds × 7 ≤ d × 1.6 + 20. Otherwise the line goes quiet for the rest of the zone stay.
- Turn-ins: the player is at the NPC (30 yd), or the route will not reach it in its next 2 steps, and `d <= 250`,
  and either (resting with `d <= 100`) or (detour ≤ budget). The NPC's height must be within 8 yd of the player's
  floor.
- Nothing shows on a boat, taxi or instance, while hearthing, during a timed quest or escort, or in combat.

**When a line goes away**
- It is cleared beyond min(radius × 1.67, 600) yd, or after 180 s out of reach. It can come back after 60 s.
- Dismiss mutes it for 120 s *and* until the player has moved 100 yd. A second dismiss mutes it for the zone stay.

**Display**
- At most 3 lines; at most 10 candidates measured, re-picked every 25 yd.
- Ranking: camps with few spawn places first, then nearest. A 30 yd hysteresis applies before lines swap.
- Distances are rounded to 5 yd. A chime plays at most every 5 s.

Spawn areas are `spots = {x,y,z,r,n,alt,lvl}` in yards, packed as text. Goals with identical spot strings share
one list.

### 1.7 Arrow, waypoint choice and camps

**Arrow** (`Nav\Arrow.lua:509-625`)
- The world position is sampled at 20 Hz.
- Damping works on the *map bearing*: `turn = diff × (1 − e^(−dt·12))`, capped at 3.5 rad/s × dt.
- Player facing is subtracted every frame, so camera turns act instantly while target changes swing smoothly.
- ETA uses the closing speed `v = Δd/Δt`, low-passed `cs += (v − cs)·min(1, 2dt)`. ETA = dist/cs, shown only when
  cs > 1.5 yd/s.
- Colour fades over the last 250 yd.

**Arrival** (`Nav\Nav.lua:375-433`)
- Default radius 8 yd. Area targets measure to the area's edge.
- Hysteresis: once arrived, the target un-arrives only beyond `r + max(5, r/2)`.
- Within max(2r, 20) yd, a floor mismatch blocks arrival and shows an up/down hint.
- Another continent shows the target zone's name instead of an arrow. Instance or taxi: hidden. No position:
  "nopos".

**Which goal gets the arrow** (`currentGoal` E:4338)
- Goals sharing an NPC, object or place form a group.
- With two or more open field goals, the nearest wins. It switches only if the new one is >25% *and* >40 yd
  nearer. It never switches in combat or within 5 s of work.

**Camps** (`Spots`, E:2140-2337)
- 40 yd hysteresis between camps.
- Area objectives use a visited circuit: a spot is visited inside its radius, left after 4 yd, and forgotten after
  300 s.
- Dwell: after 7 s standing within 10 yd with no progress and no fight, the arrow moves on.
- Spots more than 1 level above the player are skipped while lower ones exist.
- A fight is noted by *position* (16 entries, merged within 20 yd). It counts for every goal whose spots lie
  there, which effectively groups objectives that share ground.

**Vendor, trainer and farm candidates** (`pickFor` E:2001)
- Tiers: other continent, zone minimum level above L+10, away from the class home zone.
- The 8 nearest get real travel estimates; the rest are priced at 7 yd/s.
- Farm cost = need / (drop rate × kills per minute). Kills per minute by mob colour: grey 2.5, yellow−4..0 1.5,
  green 2.0, higher 1.0, scaled by min(1, spawns/8).

### 1.8 XP model (`Core\Levels.lua`, `QoL\XP.lua`)

Verified by reading `Levels.lua:79-120`.

**Formulas**

```
quest share(d = plevel - qlevel): d<=5 -> 1.0; 6 -> .8; 7 -> .6; 8 -> .4; 9 -> .2; d>=10 -> .1  (round half up)
greyLevel(L): L<=5 -> 0; L<=39 -> L - floor(L/10) - 5; L<=59 -> L - floor(L/5) - 1; else L - 9
zeroDiff(L): <=7:5, <=9:6, <=11:7, <=15:8, <=19:9, <=29:11, <=39:12, <=44:13, <=49:14, <=54:15, <=59:16, else 17
mobXP(L, M, elite): base = 5L + 45
   M >= L        -> base * (1 + 0.05*min(M-L, 4))
   M <= grey(L)  -> 0
   else          -> base * (1 - (L-M)/zeroDiff(L))
   rounded; x2 if elite
IsQuestTrivial: prefer C_QuestLog.GetTrivialRange() (trivial when L - q > range), else greyLevel
```

**Projection**
- `Levels.Run` (Levels:137) simulates the remaining entries in order, one kill at a time, so level-ups lower later
  gains.
- `ForGuide` (Levels:250) builds the entries:
  - each turn-in once, with its database XP and level;
  - kill goals at the mob's mid level;
  - loot goals as ceil(count / drop chance) kills of the best dropper;
  - quests already done are left out;
  - results are cached in up to 32 spans.
- Output: "this guide takes you to X".
- `Levels.Pace` compares the next `level` goal with the projection and reports:
  - the shortfall in levels, bars and XP;
  - the first quest that will still be 3 or more levels above the projected level.
- **Rested XP is not in the projection**, only displayed.

**XP pace** (`QoL\XP.lua`)
- XP/hour is a rolling rate over 900 s; it never divides by less than 60 s.
- Kills-to-level and quests-to-level average the last 20 kill gains and the last 10 quest gains.
- XP is split by source:
  - quest: the xpReward in the `QUEST_TURNED_IN` payload;
  - kill: a `CHAT_MSG_COMBAT_XP_GAIN` within 1 s of the gain (the text is not read);
  - everything else: "other".

**Turn-in now vs later** exists only as the XP-loss doubling of the while-here budget.

### 1.9 Forever-only content

- **Coordinates.** Goals carry `f="e"` (Era frame, bounds in `Polestar_Guides\MapFrames.lua`, maps 1411-1461) or
  no frame (live client frame, `C_Map.GetWorldPosFromMapPos`). `Compat.WorldToMap` falls back to bounds measured
  from corner samples (Compat:827-869).
- **Zephras Isle 2521** is its own continent 2991 (`Nav\TravelData.lua:410/425`). Skyborne trainers:
  `Core\ClassTrainers.lua:142-160`.
- **Riverglades 2548** has a hard-coded frame (TravelData:1107), crossings to Redridge, Badlands and Swamp of
  Sorrows (:1166-1168), and the Steamwheedle↔Powderfuse boat (:364).
- **Hyjal 2482 and Shen'dralas 2652** are "wild" zones with no crossing data; they are walked in a straight line.
- **Auberdine↔Stormwind Harbor boat**: TravelData:363/1029. Ride 59.8 s one way and 67.3 s the other; wait 134 s.
- **Zone level ranges**: `Maps\ZoneLevels.lua:52-54` (Hyjal 56-60, Zephras 2-10, Riverglades 37-57).
- **Darkspear 2524** has no special case; its data comes from the guides only.
- **"New in Forever"**: about 1,800 IDs in one fixed-width digit string (`Quests\NewQuestIds.lua`), searched by
  binary search.
- **Race masks** (`Quests\QuestDB.lua:396-440`): Skyborne is 2^32 (Alliance) and 2^33 (Horde), stored as
  `raceHigh` 1/2 because `bit.band` is 32-bit. A race not in the mask table is never excluded.

### 1.10 Automation and hooks (noted, not recommended)

**Automation**
- Auto accept and turn-in are **on by default** (`Core\Automation.lua:144-268`), plus:
  - accept-ahead from the next 5 steps (E:8764);
  - turn-ins of lines shown by while-you're-here (E:11129).
- QoL automation: sell and repair, buy, best reward, equip, train all, bind, gossip option, taxi on key, junk
  delete.

**Hooks**
- Engine: `hooksecurefunc` on SelectOption/AcceptQuest/CompleteQuest/GetQuestReward (E:10883-10890).
- Elsewhere: `TakeTaxiNode`, `StaticPopup_Show`, container `UpdateItems`, quest log and tracker update functions,
  gossip button `Setup`, `QuestInfo_Display`, GameTooltip scripts, Minimap `HookScript`, the GameMenu.

**Map**
- Frames are re-parented under `WorldMapFrame:GetCanvas()`, with no data provider and no `AcquirePin`.
- This is safer than a provider, but it is still a child of a Blizzard frame, and we keep our pins on our own
  overlay.

---

## 2. Polestar navigation, travel planner, forge compiler and forever-db

### 2.1 Walking data (`addon\Polestar_Nav`, GPL-3.0-or-later; packs `Polestar_Nav_EK` / `_Kalimdor`)

**Grid layout** (`Nav\Nav0.lua:1-66`, decoded in `Routing\PathGrid.lua:256-291`)
- One cluster = one ADT tile (533.33 yd) = 128×128 cells of 4.17 yd.
- Axes follow `UnitPosition`: x north, y west.

**Per-cluster fields**
- `grid`: `value*16 + flags`.
  - value: 0 blocked, 1 ground, 2 water.
  - flags 1/2 close the step to +x/+y (walls, cliff edges); flags 4/8 open diagonals.
  - Run-length coded.
- `height`: delta-coded in steps of 2 yd.
- `floor`: stacked surfaces (bridges, tunnels, a city over ruins), up to 31 per column, each with an 8-direction
  step mask.
- `class`: 0 normal, 1 road, 2 gentle slope, 3 steep, 4 indoor, 5 indoor city; plus bits for "inside an
  Alliance/Horde town".
- `zone`: uiMapID per 16×16 chunk.
- `area`: subzone.
- `arc`: one-way jumps and drops.
- `graph`: HPA* entrance nodes, with costs per faction baked into each edge.
- `hubs`: hostile towns as disks.

**Storage and loading**
- 16 KB zlib blocks stored as escaped strings, decoded with `C_EncodingUtil.DecompressString` (as data, never
  executed). If the API is missing, every map is dropped and the arrow points straight.
- Packs are LoadOnDemand per continent and load the first time a search needs them, never in combat.
- Decode cache 8 MB with LRU; decoded grids are dropped after 60 s idle.

**How the baker (offline, Rust `forge-navbuild`) treats terrain**
- Slopes up to 35° are gentle, up to 50° walkable, up to 60° steep; above 80° is a wall.
- Water deeper than 1.5 yd is swimming, which costs ×3.
- A fall is safe up to 14.57 yd.
- **What actually ships (format 5)** is condensed from Leffe's private maps (`forge nav pack --leffe`).

### 2.2 Path-finding at runtime (`Routing\Path.lua`, `PathGrid.lua`, `PathJobs.lua`)

```
snap start/goal to a node: search +-6 cells, minimise dist + 2*heightGap among surfaces within 10 yd of z
connect each end to its cluster's entrances (grid Dijkstra, cached)
abstract A* over entrance graph; heuristic octile*lower (admissible: cheapest class multiplier)
  cut off at 8x straight line + 2000 yd; lifts are extra vertices costing 175 yd (25 s)
refine each abstract hop with in-cluster A*
smooth: drop collinear points, then string-pull to the furthest visible point, where "visible" walks every
  crossed cell on the same floor and refuses a shortcut that is costlier per node, enters a hostile hub the path
  avoided, or swims where the path didn't
step cost = length * classMult * (20 inside a hostile hub) * zoneDanger(3 or 20)
```

**Class multipliers** (`Routing\Costs.lua`)

| Profile | normal | road | gentle | steep | indoor | city |
|---|---|---|---|---|---|---|
| balanced | 1 | 0.8 | 1.3 | 2.5 | 2 | 1 |

There are also "fastest" and "roads" profiles.

**Budget and caching**
- Coroutine with 3 ms per frame; the clock is checked every 64 expansions.
- Paused in combat.
- Finished paths are cached by key.

**Replanning** (`Nav\Walk.lua:185-192`)
- 25 yd off the path asks for a new path, at most every 2 s (every 10 s when more than 2000 yd remain).
- A failed search is retried after 15 s or 25 yd.
- A level-up drops all cached paths, because danger depends on level.

**Floor tracking**
- Forever gives no player z. The floor is guessed from `SurfacesAt` every 0.25 s once the player has moved 1 yd.

**Path follower** (`Nav\Follow.lua`)
- Aim at the furthest point within 35 yd of the player and 45 yd ahead along the path, inside a 20 yd corridor.
  Corners are cut by at most 10 yd.
- Off-path open ground is allowed up to 100 yd.

### 2.3 Travel planner (`Nav\Travel.lua`, data `Nav\TravelData.lua`)

**TravelData contents**
- taxi nodes `{id, continent, wx, wy, uiMap, x%, y%, factionMask, name}`;
- flight edges `(from, to, yards)`;
- transports `{a, b, ride ab/ba s, waitA/B, faction, kind}`;
- portals, inns, class teleports;
- zone crossings from Carbonite (GPL-3.0);
- timetables (period ms, stops).

**Sources**: Era TaxiNodes/TaxiPath tables, Forever's TaxiPathNode (Forever ships), TransportAnimation, and CMaNGOS
periods.

**Dijkstra over walk/flight/ride/hearth edges** (cap 1500 vertices, 20k pops, 40 ms)

```
walk    = straight * 1.25 / speed   (speed = GetUnitSpeed clamped 4..14, default 7); last leg re-measured by router
flight  = yards/30 + 2 s per hop; only known flight masters; +5 s to learn one on the start/target continent
boat    = timetable wait + ride when the phase is known, else mean wait + ride
hearth  = 15 + 120 s; used only if the trip takes >= 180 s without it AND it saves >= 120 s
teleport= cast + 10 s
faction filter by mask; danger: zone min level >= L+4 -> x3, > L+10 -> x20 (start/goal zones exempt)
replan after 30 s and 50 yd moved, or 90 yd from a dock
```

**Boat phase**: the loop period is fixed but the phase is unknown. It is learned by matching the player's position
while riding ("sightings", valid 6 h).

### 2.4 forge: guide compiler and route optimiser (`rust\`, docs `docs\forge\*.md`, `docs\GUIDE_FORMAT.md`)

**`.guide` text format**
- Header lines: `guide`, `title`, `levels a-b`, `zone`, `faction`, `race`, `class`, `next … when`,
  `coords era|live`.
- Indented `step` blocks hold goals (the kinds from section 1.4) and modifiers: `xN`, `quest Q.O`, `@x,y`, `npc`,
  `object`, `item`, `only`, `optional`, `group N`, `nearest`.
- Step lines: `tip`, `note`, `when`, `along until`, `skipto … when`, `label`, `loop`.

**Validation** (`forge-guide\src\validate.rs`)
- duplicate ids, `next` targets;
- a turn-in with no earlier accept;
- races or classes that can never take the quest;
- prerequisites, plausible levels, exclusive quests, required elite work, timed items, missing places.

**Spawn clustering into areas** (`forge-guide\src\cluster.rs:47-132`, constants in `resolve.rs:34-44`)

```
sort points; greedy leader assignment within 70 yd (centroid updated as points join); 2 Lloyd (k-means) passes
radius = max member distance, at least min_radius; sort clusters by size
<= 6 points: radius 70, min 15; more: radius = min(250, max(70, 2*median spacing)),
  min radius clamp(spacing, 40, 150) when spread > 250 yd
```

**Route ordering** (`docs\forge\routes.md:31-237`, `forge-sim\src\search.rs`)
1. Seed: the hand-written order.
2. **Edit descent**: each iteration tries every local edit and keeps the single best one if it saves at least
   10 s. It stops after 400 edits or when nothing helps.
   - Edits: move, fold, insert (giver within 500 yd), chain insert (up to 6), zone block, drop, drop trip,
     drop/gate grind, join (120 yd), stay later, stay split, ride.
   - Constraints: quest order, at most +100 yd of straight walk per edit, objectives never moved more than 2 levels
     under, quest log ≤ 38, no hearth on cooldown.
3. Optional "free search" adapted from Factoruide (MIT with permission): 24 seeded members over 2M tries, with
   ruin-and-recreate and same-place gathers.
4. Pricing a candidate: replay 80 steps from a snapshot, estimate the rest at equal XP, then replay the best
   exactly.
5. Extra passes:
   - worthwhile pickups: XP/min ≥ the route's XP/min at that level, or ≥ half when the detour is under 60 s;
   - hub pickups (≤ 3 min), camp gather (150 yd), camp revisit.

**Objective function**: hours to 60, with grinding seconds weighted ×2.5 and 600 s risk per extra group member.

**Simulator** (`docs\forge\model.md`, `forge-sim\src\xp.rs`, `params.rs`)
- XP: same mob and quest formulas as section 1.8.
- Accept window: level ≥ minLevel − 2 and ≥ questLevel − 7. Kill work on mobs more than 3 levels above makes the
  character grind up first.
- Kill time = (11 + 19·(L−1)/59) s × f × classFactor + travel between mobs. f is +10% per mob level above and
  −5% per level below (≥ 0.5). Elites take ×3.5 time for ×2 XP.
- Grinding gives 0.7 × the best XP/s among mobs at L..L+2.
- Fixed times: talk 6 s, object 8 s, escort 240 s, level-up 60 s, flight yards/30 + 20 s, hearth 10 s with the
  cooldown modelled.
- Rested is off by default.
- **Along credit**: walking within 150 yd of an open kill objective does 25% of it. Other kill objectives within
  200 yd are pooled by density ratio.
- Output per step: `{t, lvl before, q, pt}` plus hours to 30 and 60 and the peak quest log size.

### 2.5 forever-db (`forever-db\`, tables GPL-3.0; mechanic/step/note/schema CC BY 4.0)

**Tables**
- quest (5,287): level, min_level, race/class masks, side, xp, type, zone, repeatable;
- quest_start, quest_end;
- quest_objective (6,338);
- quest_prereq (3,811): all/any, breadcrumb;
- quest_reward;
- npc (13,239): levels, faction, rank;
- object, item, item_source;
- spawn (88,761): world yards, x north / y west, rounded to 0.5 yd; maps 0, 1, 2991 plus a few instances; none on
  2997 (Darkspear);
- ui_map (59);
- mechanic (3,401): group/elite 953, timed 53, escort 45, …;
- step (2,409): gotchas, places, confidence.

**World → map percent**

```
x% = 100 * (wy - left) / (right - left)
y% = 100 * (wx - top)  / (bottom - top)
```

Example (Elwynn): `top −7939.583, bottom −10254.166, left 1535.417, right −1935.417, ui_map 1429`.

**Forever zones**: 2482 → map 1, 2521 → 2991, 2524 → 2997 (no spawns), 2548 → map 0, 2652 → map 1.

**Corrections**: per-table JSON with `set`, `remove` and `addSpawns`. Each entry needs a source (recording,
in-game check, client, …) and is listed in `LEDGER.md`.

---

## 3. Leveldon (`G_Leveldon`; ideas only: no licence except `Training.lua`, which is GPL-3.0)

### 3.1 Route shape

- A route is one planned sequence per race and band (1-30, 30-50, 50-60), stored as Lua text and unpacked with
  `loadstring` + `pcall`.
- Class and dungeon **overlays** are spliced in by `seq`:
  - a number pair copies a range of base steps;
  - an inline table inserts a step;
  - per-index arrays override the planned level `el`, the planned time `t`, and `xp` (precomputed grey factor).
- Every step has `k` (kind), `q`, `lv`, `xp`, `m` (Classic uiMap), `x`/`y` in percent, `el` (fractional level
  after the step) and `t` (cumulative planned seconds).
- `*Lines` packs are alternative 1-30 routes through another start area of the same faction. They are not walking
  lines.

### 3.2 Step choice and re-planning (file `Leveldon.lua` unless noted)

```
login: Restore saved route index (first not-done within 60, or same StepKey within +-25) else StartIndex
       (first chapter whose hi > level); Update 2 s later
Advance: skip forward while StepDone or Outgrown (lv + 8 <= level, not in log, not class) or (first login only)
         a non-quest step whose chapter already shows later quest progress
  abandoned quest's do/turnin -> re-insert its accept before it (RetakeBefore 2232)
  accept too high -> move it to the route's next visit of that NPC/hub with planned el >= minLevel
                     (search 250 steps / 2 chapters); move its do/turnin after; once per level; else "left out"
FollowPlayer (3982): if the step sits for 600 s while the player accepts/turns in >= 2 distinct LATER route
  quests -> jump to the first of them; mark skipped-over steps done; move their still-in-log do/turnins behind
ClassNow: class quest of your class available now and within 400 steps -> pull its chain next to where you stand
FinishNearbyFirst (Fit.lua:518): step > 200 yd away while a `do` in the next 10 steps has an objective within
  120 yd -> do that first (once per step)
ReturnLeftOut: 1 s after level-up or turn-in -> re-insert left-out accepts now in level at the giver's next hub visit
Fit an extra quest (Fit.lua:113-190): on QUEST_ACCEPTED (+1 s): doAt = first step within 150 ahead that is
  within 250 yd of an objective point; turnAt = first step from there within 80 yd of the turn-in -> insert do
  after doAt and turnin after that hub; else "not on your route". Class quests go in now.
Hub ordering (1969-2079): exact Held-Karp over <= 7 NPC groups (NPCs within 10 yd = one group), constraints:
  same-quest order, accept after its prereq turn-ins; +60 yd for going in/out of a building; use the new order
  only if it saves > 5 yd
```

### 3.3 Completion and lag handling

**Per kind**
- accept: done, or in the log.
- do: done, or complete in the log. A turn-in of an unfinished quest is shown as "Do".
- turnin: the completed flag.
- train: `db.trained` is set on `TRAINER_SHOW` at a class trainer.
- fp: `TAXIMAP_OPENED` marks this fp step plus any within the next 4 steps and 400 yd.
- hearth: spell 8690 succeeded, or already within 150 yd of the hearth place.
- bind: bind location changed since the step started, or changed in the last 600 s while within 200 yd.
- sell: a merchant opened after the step started. A hub sell also passes if it is not worth it (see 3.4).
- die: `PLAYER_ALIVE` / `PLAYER_UNGHOST`.

**Blocked quests**: quests the server will not give pass. This is cached, and the cache is cleared on turn-in,
skill change or level-up.

**Lag handling**
- One update 0.3 s after a burst of events.
- 2 s after login.
- 1 s after an accept, because objective places arrive late.
- The arrow is re-aimed every 2 s for do/turnin steps.
- The window is redrawn only when its inputs change, or every 10 s.

**Kill detection**: an XP gain not attributable to a turn-in, while `UnitIsDead("target")`, counts as a kill of the
target's creature ID. This is only used by the recorder.

### 3.4 XP, money and misc.

- **Grey and level rules**
  - No grey formula at runtime; the XP values are precomputed offline.
  - Out-levelled means quest level + 8 ≤ player level.
  - Time to level = planned `t` at the next level minus planned `t` now.
- **Speedrun clock**: counts only active time. It goes idle after 120 s without movement, combat, casting, loot or
  any dialog.
- **Money**
  - Riding at 40 costs 120 g (100 g for paladin and warlock). Short of gold, the mount step is skipped and a
    reminder fires once the gold is there.
  - The trainer recommends only the important spells for the leading talent tree, with prices.
  - Profession learns and tool buys wait while they would eat into the next trainer budget.
- **Sell stops**
  - Planned at hubs. Worth it with ≤ 4 free slots, grey value ≥ 50 c from level 4, any item below 60%
    durability, or a hunter with fewer than 150 ammo.
  - Dynamic stops: within 220 yd, at most every 300 s, detour ≤ 80 yd.
- **Death skip**: only below level 10. Skipped when the next step is more than 300 yd from the spirit healer.
- **Timed quests**: a hand-kept table of quest ID → seconds, plus `C_QuestLog.GetTimeAllowed` at runtime. The
  quest's do/turnin goes right after its accept. While a timer runs, nothing else is inserted.
- **Group/elite quests**: a literal ID list (CMaNGOS quest type 1 plus ones seen on Forever). They are left out of
  the route.
- **Nameplate marks** are its own frames anchored above `C_NamePlate.GetNamePlateForUnit` plates, matched by
  creature ID from `UnitGUID`. Forbidden plates are skipped. `SetRaidTarget` is not allowed on Forever.

---

## 4. DonData / Questdon / DonMap (MIT code; data mixed, see section 10)

### 4.1 Forever client knowledge (`DonData\Engine`)

- **`RequestLoadQuestByID` → `QUEST_DATA_LOAD_RESULT(false)` is not "missing" on Forever** (`Exists.lua:38-43`).
  The server denies many real quests. Nothing is hidden on Forever.
  - Rate: 5 requests/s, 30 s timeout, queue of 400, each ID once per session.
  - Titles retry with back-off at 4, 8 and 16 s, up to 6 tries.
- **Server quest level scan** (`Levels.lua`)
  - Starts 60 s after login.
  - Every 0.5 s: request one ID, wait up to 5 s, read `C_QuestLog.GetQuestDifficultyLevel`, and keep the result
    only if it differs from the shipped level.
  - Never in combat.
  - Progress is saved account-wide and reset on a new client build or data version.
  - The minimum level cannot be asked.
  - Level priority: quest log, then `GetQuestDifficultyLevel`, then the kept level, then the shipped level.
- **`GetAvailableQuestLines`** (`Offers.lua:396-588`)
  - Call `RequestQuestLinesForMap(map)` first.
  - A listed quest is available. A quest of a known quest line that is not listed is "not yet". **An empty list
    is no answer.**
  - Skip entries with `inProgress`.
  - `startMapID` must be the map or a child of it.
  - `QUESTLINE_UPDATE` re-requests only maps whose last request is older than 2 s.
  - The cache is forgotten on accept, turn-in and level-up.
- **Gossip "not offered at level L"** (`Offers.lua:31-394`)
  - A dialog with any unreadable entry judges nothing.
  - Within 3 s of a turn-in at the same NPC, the dialog only confirms offers.
  - Otherwise, a data quest of that NPC that is not listed (not done, not in log, takeable by data, not trivial,
    exactly one giver) is marked `notOffered[q] = level`, together with the NPC and the position.
  - The mark is cleared when any of these happens:
    1. the player's level rises above the marked level;
    2. 30 minutes pass;
    3. there is a turn-in at that NPC, or within 100 yd, or of the quest's prerequisite;
    4. the quest is accepted;
    5. the quest is seen offered.
- **"Never here" memory** (`NotHere.lua`): account-wide. A quest is hidden only when not offered at 3 distinct
  levels, or once at or above its game level. Any offer voids the memory.
- **Three-corner map transform** (`Geo.lua:31-72`)

  ```
  once per map: c,(n0,w0)=World(0,0); (n1,w1)=World(1,0); (n2,w2)=World(0,1)  (same continent required)
  n = n0 + x(n1-n0) + y(n2-n0);  w = w0 + x(w1-w0) + y(w2-w0)
  verify the first real point against the client; > 0.5 yd off -> mark map nonlinear (always ask client)
  inverse: det = nx*wy - ny*wx; x = (dn*wy - ny*dw)/det; y = (nx*dw - dn*wx)/det
  bearing: north = tn - pn, east = -(tw - pw), atan2(east, north)
  ```

  DonMap converts `UnitPosition` with this inverse. It auto-detects the axis order against
  `GetPlayerMapPosition` and switches itself off on a mismatch (`DonMap\Geo.lua:119-155`).

### 4.2 Questdon

- **Path dots** (`Paths.lua`)
  - A 100×100 cell grid per zone, searched with 8-neighbour A*.
  - Costs: walked cell 0.35, open 1, rock 12.
  - Waypoints are reached at 20 yd. It replans at most every 1.5 s, or when the player is 3 cells off the way.
  - The grid data has no licence.
- **NPC walks**: patrol loops from CMaNGOS waypoints (GPL-3.0), shown only for relevant NPCs and mobs.
- **Chain graph** (`Chain.lua`): walk prerequisites backwards and follow-ups forwards. The layer is the deepest
  in-chain prerequisite + 1. Other sides, races and classes are excluded.
- **XP bar**: current XP, then XP of ready quests in the log (`GetQuestLogRewardXP`), then rested.
- **XP source split** (`XPCheck.lua:35-135`)
  - Lua patterns are built from the client's own `COMBATLOG_XPGAIN_*` / `EXHAUSTION*` globals.
  - A message that is not a usable string counts as a "secret" sample and is skipped.
  - Matching window: 1.5 s.
- **Crowd learning** over a public channel is noted only. We do not do it.

### 4.3 DonMap

- **Clustering**: screen-space greedy join to the first group whose running centroid is within N px.
- **Thinning**: spawns are cut to at most 80 points per objective on the world map and the nearest 100 on the
  minimap.
- **Not for us**: it uses `AddDataProvider`/`AcquirePin` and hides the game's quest POIs, the exact pattern behind
  our "blocked from an action" pop-up.

---

## 5. ForeverWisp (free part; All Rights Reserved, ideas only)

**Progress stores**: four per guide version — progress, auto, manual and deferred (each deferral carries a reason).
"Resolved" means done or deferred.

**Rule: deferral never becomes completion evidence.** A deferred step never satisfies a prerequisite and never
moves the anchor.

**Next-step priority**:
1. a detour;
2. a gathering loop;
3. **the step matching the NPC window that is open now**;
4. a nearby unlearned flight master;
5. the area-checklist neighbour;
6. otherwise Recovery (see below).

**Recovery** walks prerequisites backwards:
- unknown log state means "waiting";
- a missing prerequisite means "finish X first";
- a missing pickup is re-picked;
- a hand-in with open objectives goes to the objectives step;
- level-gated pickups fall back in order: stay in the same-zone outing, then pickup after the gate, then fieldwork,
  then work in the log, then same-map quests.

`PreserveVisit` stops jumps back across zones.

**Catch-up** picks an authored entry by level fit, then current map, then turn-in history, then quests in the log.
- It keeps prerequisites, class steps, accepted quests, unknown-state quests and the next guide's openers. It defers
  the rest with a "Catch-up:" reason.
- It never applies while any quest state is still unknown.

**EarlyVisits**: an authored block moves earlier when the player is within 250 yd of its anchor or talks to its
NPC, provided the player is at its minimum level.

**Native positions** (`NativeQuests`), cached 0.5 s:
- `GetNextWaypoint` for quests in the log; `RequestQuestLinesForMap` (at most every 10 s per map) +
  `GetAvailableQuestLines` for accepts; `GetQuestsOnMap` with isQuestStart.
- It walks up to 5 parent maps.
- While talking to the quest's NPC, the player's own position is used.

**Arrow**: exponential smoothing on the shortest arc with a 20/s rate. Arrival radius is min(authored or 20, 10)
with a 5 yd exit buffer.

**Waypoint lease**:
1. Check `CanSetUserWaypointOnMap`.
2. Yield if something else is super-tracked.
3. Snapshot the user's point.
4. Set the waypoint, read it back, and only then call `SetSuperTrackedUserWaypoint`.
5. Tag every write as expected. Any unexpected `USER_WAYPOINT_UPDATED` or `SUPER_TRACKING_CHANGED` means the lease
   is lost and Wisp yields.
6. On release, restore the user's snapshot only if the slot is clean.

**`C_Navigation.GetFrame`** is polled each render. While it is missing, Wisp waits up to 1 s, then falls back to its
arrow. It also hides `SuperTrackedFrame` with alpha 0 — a Blizzard frame write we do not copy.

**Positive evidence only**:
- flight paths come from `ERR_NEWTAXIPATH` credited to the NPC being spoken to; taxi node state 2 is not trusted
  on Forever;
- quest mobs come from native tooltip objective lines (`C_TooltipInfo.GetUnit`);
- an objective counter increase counts as "local spawn" evidence for 5 min or 350 yd.

**Forever quirk**: when every objective counter is full but no readiness API answers, the quest is not counted
complete, because Forever can reveal a later stage after a briefing.

**Automation and hooks** (on by default):
- auto accept, complete and reward;
- `hooksecurefunc` on `ShowUIPanel` and `StaticPopup_Show`;
- hides the objective tracker;
- abandons quests from the log review after a confirm.

---

## 6. Guidelime 6.018 + TUGs Forever (All Rights Reserved, ideas only)

**Step state** is a fixed-point loop that repeats until nothing changes (`CurrentGuide.lua:1023-1076`):
- completion;
- availability: an accept needs its prerequisites; complete and turn-in need the quest in the log or an earlier
  scheduled accept;
- activation: not done, not skipped, available, requirements met, and no earlier mandatory step still open.

Several steps can be active at once, and the current step is the first active non-optional one.

**Skipping** a quest's last step marks the quest SKIP, which makes all its later steps unavailable. The skip
tooltip lists the follow-ups this blocks.

**Completion**
- Quests: from the log and the completed set (fetched once, then refreshed 0.1 s after changes).
- `[XP]`: `+N` means at least N XP into the level, `-N` within N XP of the next level, `.f` a fraction of the level.
- goto: 6 yd, with 2× hysteresis.
- Semi-automatic steps:

  | Step | Done on |
  |---|---|
  | train | `TRAINER_SHOW` |
  | vendor / repair | `MERCHANT_SHOW` |
  | new flight path | `ERR_NEWTAXIPATH` |
  | set hearth | `HEARTHSTONE_BOUND` |
  | hearth | spell 8690 or 556 |
  | fly | `PLAYER_CONTROL_LOST`, then `UnitOnTaxi` checked after 1 s |

- When several quests need the same item, each counts done only when the bag holds enough for all of them.

**Spawn clustering** (`PositionTools.lua:20-112`)
- Seeds: furthest first.
- A point joins the nearest cluster within 170 yd, using a running mean.
- The cluster pointed at has the best score = count × 1000 / distance.
- Goto radius = cluster radius + 6.

**Forever specifics**
- `RegisterEvent` is wrapped with `C_EventUtils.IsEventValid` (Forever throws on unknown events).
- The flavor is Forever for builds 16000-19999.
- Zones are mapped by name for 2482, 2521, 2524, 2548 and 2652 (`Data\MapDB.lua:577-670`).
- Skyborne is race 95 (mask bits 31/32).

**TUGs Forever** is Guidelime bracket syntax, almost entirely by quest ID (about 5,200 quest tags against about 346
`[G]` gotos; coordinates come from Questie).
- Forever IDs: about 917 in the 90000-97999 range and 118 in the 98xxx range.
- Zephras Isle appears by name; Hyjal and Riverglades do not appear.
- Boats are plain text.
- It has no licence text.

**Automation and hooks**: auto accept, turn-in and reward; trainer buying; `TakeTaxiNode` hook; HBD-Pins (map data
provider).

---

## 7. Ding! (GPL-3.0, `G_Ding`)

### 7.1 Steps and resume

**Advance** (`Core\Engine.lua`): advance while `IsStepDone` or `LeftBehind`.

**Step filters**:
- race, class, faction;
- option toggles: hearth, deathskip, elite, vendor, train, fly, dungeon;
- `when`: done/notdone, log/notlog, ready, item/noitem, min/max level.

**`IsStepDone`**:
- Steps the game can't check (go, train, fly, hearth, sethearth) also need **positive evidence**: arrival, a service
  event, progress within the next 5 steps, or a later turn-in within the 10 s resume window.
- `pointlessTrip` skips travel to a place with nothing left to do.

**Level gates**:
- A quest too high for the player counts as handled and never blocks the guide.
- A grey quest is skipped only if the option is on, the quest is not in the log, and it is not a prerequisite of a
  later guide quest.

**Missing prerequisites**: the chain is walked up to 15 deep, and the arrow goes to the earliest missing link.

**Resume**:
- Restart from step 1 with a target of the last step.
- Below the target, pass steps unless a quest from the guide's past is still in the log with work left.
- A follow-up from the NPC you just turned in to (within 30 s) is not passed.

**Login**: wait for the first `QUEST_LOG_UPDATE` (at most 5 s); never place from an empty log.

**Guide changes**: a hash of quest actions detects regenerated guides, and per-step hashes carry manual marks across
versions.

**Along the way** (`Core\Along.lua`): log objectives other than the current step's. A row shows within 100 yd and
hides beyond 160 yd; at most 3 rows; checked every 2 s.

**Sticky targets**: low-priority arrow targets priced at 2d + 300.

### 7.2 Secret-safe objectives

`Compat.Plain` turns any secret value into nil. `GetObjectives` rebuilds fulfilled/required from the last "N/M" in
the objective text when the numbers are secret (`Core\Compat.lua:13-96`). Speed comes from positions, not from
`GetUnitSpeed`.

### 7.3 Arrow and travel

**Arrow**
- Ticks every 0.05 s and re-picks the target every 1 s.
- **Anti-flip**: switch only if the new target is under half the distance *and* at least 40 yd closer.
- Arrival 6 yd. Kill area: enter at 25 yd, leave at 40 yd.
- Inside a kill area it runs a farm loop: nearest-neighbour stops within 300 yd, merged every 25 yd, 3-12 stops.

**Travel Dijkstra** (`Core\Travel.lua:348-472`)
- Speeds: run 7 yd/s; mount 11 yd/s from level 40; walking ×1.2.
- Flights: 30 yd/s ×1.25, plus 15 s. An unknown flight master costs +60 s.
- Docks: ride time + mean wait.
- Hearth: 30 s + cooldown.
- A mode switch must save at least 20 s.
- A zone 4+ levels above the player costs up to ×2.5.
- Replans after 150 yd moved or 15 s.
- Learns real flight times through a `TakeTaxiNode` hook (not for us).

### 7.4 XP

**Offline model** (`tools\route_model.lua`)
- Quest XP: same shares as Polestar. With no figure, the fallback is 70 + 22L + 1.6L².
- Kill XP: same base as Polestar, counted at 90%.

**In game** (`Core\Grind.lua:11-171`)
- Each kill is stored as a ratio to a same-level kill; the median of the last 30 gives XP per kill.
- Rested correction: base = max(gained/2, gained − rested pool before).
- Kills left = ceil(max(missing − rested, missing/2) / perKill).
- Grind spot cost = (distance + onward/2 + 140·kills/share) × weight × risk.

### 7.5 Generator

`tools\route_solver.lua`, offline:
1. Seed with a greedy nearest-action tour, keeping the quest log under 18.
2. Simulated annealing with a fixed seed. Moves: move, swap, reverse, add/remove chain.
3. Objective: time to the section's max level, with any shortfall filled by grinding. A quest stays only if it beats
   the grind rate including its detour.
4. Caps: quests at most +2 levels, mobs at most +1.
5. Free-quest audit: a left-out quest goes back in if its XP per added second is at least 10× the section's pace
   and it adds at most 2 min.
6. Grouping within 100 yd (250 yd for objectives), ordered turn-in, accept, complete.

### 7.6 Format and automation

**Format**: `Ding.RegisterGuide{…}` tables with accept/turnin/complete/go/level/when/optional/sticky/elite/dungeon
and `why = {kind, quest, seconds, xp}`. The text import uses a non-executing table parser.

**Automation and hooks**: auto quest, rewards, sell and repair, taxi, talents; `TakeTaxiNode` hook.

---

## 8. ForeverQuest 0.22.0 (GPL-3.0 per `COPYING`)

**Auto destination** (`AutoTrack.lua:2-170`)
- Modes:

  | Mode | Ranks (lower wins) |
  |---|---|
  | nearest | everything 0 |
  | accepted | accepted-quest points 0, pickups 1 |
  | turnins | turn-ins 0, objectives 1, pickups 2 |

- Candidates are on the current map only. For each quest, the first source that gives a point wins:
  1. `GetNextWaypoint`; a point on another map skips the quest;
  2. `GetNextWaypointForMap`;
  3. a `GetQuestsOnMap` POI;
  4. saved notes;
  5. the database.
- Pickups come from `GetAvailableQuestLines` and database pins. Personal overrides are applied last.
- Cost is Euclidean world yards; points on another instance are excluded.
- Sort: rank, then distance, then quest ID.
- Keep the current target unless the new best has the same rank and is more than max(10 yd, 10%) closer.
- No re-pick in combat. Session skips are keyed by `id:map:kind:objective:x5:y5`.

**Clustering** (`Clusters.lua:3-48`): screen grid union-find with a 28 px radius over 3×3 neighbouring cells. The
badge sits at the centroid.

**Personal corrections** (`Corrections.lua:43-152`)
- Saved per character, keyed by destination.
- Each record stores the original point and a replacement taken from the player's position. A record with no
  replacement means "marked wrong".
- Corrections are re-applied after a data update.

**Secret-safe vector reader** (`Guidance.lua:9-19`): accepts both `GetXY` vectors and plain `{x,y}` tables (Forever
returns plain tables).

**Bug spotted**: its combat branch is nested inside the ADDON_LOADED branch, so it never runs (Core.lua:155-163).

**Automation and hooks**: auto accept, complete and reward; re-parents the objective tracker.

---

## 9. Questie / QuestieDB (Forever parts)

**Availability** (`QuestieDB.IsDoable`, `QuestieDB.lua:695-960`), checked in this order:
1. race
2. single prerequisite
3. class
4. reputation
5. skill
6. prerequisite group (negative IDs mean "any of")
7. parent
8. next in chain
9. exclusiveTo
10. breadcrumb
11. disabledBy
12. daily
13. dates

The level window uses `C_QuestLog.GetTrivialRange` on Forever (`QuestieCompat.lua:685-697`).

**No route ordering.** `GetNearestSpawn` (DistanceUtils) costs a point on another instance at 500000 + 100·d, for
tracker sorting only.

**Forever corrections** (`src\corrections\Forever`) are layered:
- base, then legacy, then generated, then traces, then authored;
- 674 authored quest fixes, 245 of them for 95000-99999 IDs.

**`data\Forever\conversion.json`** gives per-map scale and offset coefficients from 1.15.9 to 1.60.1:
- changed maps: Mulgore 1412, Eastern Plaguelands 1423, Redridge 1433, Stormwind 1453;
- added maps: 2482, 2521, 2665, 2524, 2548, 2652;
- area moves: 16591→2548, 16593→2521, 16606→2524, 16651→2652, 616→2482.

**Licence**: GPLv3 only for listed consenting contributors; otherwise "all rights reserved when in doubt". We treat
QuestieDB as a cross-check, not a source.

---

## 10. Licence map for reuse in our GPL-3.0 addon

| Source | Licence | Reuse |
|---|---|---|
| Polestar addon code (`addon\Polestar\**`) | GPL-3.0-**only** | Port with attribution. **Combined work becomes GPL-3.0-only.** Our `LICENSE` says "version 3" with no "or later", so it is compatible. Keep it that way, or avoid these files. |
| Polestar SPF-derived files (`Nav\Walk.lua`, `Journey.lua`, `Transit.lua`, `TravelData.lua` header, `Maps\RouteLines.lua`, …) and Carbonite crossings in TravelData | GPL-3.0-or-later (Cillian Berragan; Carbonite) | Port; keep the copyright headers and mark our changes (GPL §5). |
| `addon\Polestar_Nav` router (`Path.lua`, `PathGrid.lua`, `PathJobs.lua`, `Costs.lua`, `API.lua`) | GPL-3.0-or-later | Port; keep the SPF headers. |
| `Polestar_Nav_EK` / `_Kalimdor` format-5 packs, `Nav0/1.lua` contents, race `Legs.lua` | Labelled GPL-3.0-or-later but **derived from Leffe's private maps, "with permission" given to Polestar's maintainer** | **Do not ship until Leffe or Fitz confirms downstream reuse**, or rebuild from our own client with their tooling without `--leffe`. |
| `LICENSE-EXCEPTION.md` | §7 permission for third-party guide packs compiled by forge | Not relevant to us. |
| forever-db tables | GPL-3.0; mechanic/step/note/schemas CC BY 4.0; upstream EG Link CC BY 4.0, CMaNGOS GPL-3.0, VMaNGOS/Factoruide GPL-2.0+, ForeverTDB GPL-2.0, pfQuest MIT | Already credited in our `NOTICE.md`. **QuestieDB-derived facts inside it** are used "with the Questie maintainers' agreement" and are removable on request; Polestar itself notes Questie asks for its data to be treated as ARR. Keep the credit line and be ready to drop rows. |
| Polestar guide text (`Polestar_Guides*`) | GPL-3.0-only | Usable as a cross-check of quest order. Copying route text is allowed with attribution, but our routes stay our own authorship by preference. |
| Ding! code + DingDB | GPL-3.0 (DB from Questie/QuestieDB GPL grant + CMaNGOS) | Port with attribution. |
| ForeverQuest | GPL-3.0 (`COPYING`; Questie Classic files unmodified) | Port with attribution. |
| Questdon, DonMap, DonData engine | MIT ©2026 DonCoohd | Port; keep the MIT notice. |
| DonData `Walks.lua`, `Spawns.lua`, `Services.lua`, `Extra_Quests.lua` | GPL-3.0 (CMaNGOS, ForeverDB) | Usable data. |
| DonData `Paths.lua`, `Dungeon_*.lua`, `Quest_Hints.lua`, `Known_Facts.lua` | No licence | Do not copy. |
| `Client_Quests.lua` | Blizzard client data | Do not copy. |
| Leveldon (all but `Training.lua`) and all route packs | **No licence** | Ideas only. |
| Leveldon `Training.lua` | GPL-3.0 + WhatsTraining MIT notice | Usable. |
| Guidelime, TUGs Forever, ForeverWisp | All Rights Reserved / no grant | Ideas only, in our own words. Never copy. |
| Questie / QuestieDB | GPLv3 for consenting contributors only | Cross-check only. `QuestieDB\src\derived\RamerDouglasPeucker.lua` is MIT. |

---

## 11. Where LevelGuide stands (for the ranking)

From `LevelGuide\LevelGuide.lua`:
- Routes are title-keyed (`Routes.lua`), with `QuestIDs.lua` and `Prereqs.lua` beside them.
- **Next step**: a greedy nearest-neighbour `Route()` (733-780) over actionable steps within `ROUTE_WINDOW = 10`.
  - `Cost` = distance × (0.7 for a turn-in, 0.4 for a pickup) / (1 + 2·xp/maxXP), + 400 if trivial.
  - The current step is kept unless another is 1.3× closer.
- **Out-levelled**: a step 4 levels below the player counts as done (`OUTLEVELED = 4`). `HARD_LEVELS = 5`.
- **Arrow**: unsmoothed, with no ETA and `ARRIVED_YARDS = 12` with no hysteresis (2835-2902). Cross-zone shows only
  "other zone" plus our `ways` table and travel steps grouped by zone.
- **Offers**: `ReadOffers` uses `GetAvailableQuestLines` positively. `RecordOffers` reads gossip offers
  (1610-1660).
- **Progress**: frontier/LastProgress placement (1066-1103) and skip lists.
- **Missing**: no XP projection, no spawn camps, no while-you're-here cost model, no travel planner, no server
  quest levels.

---

## 12. Build this in LevelGuide (ranked)

Ranking = gain for a solo leveler ÷ (effort + risk on this client). Every item keeps to the owner's rules:
- read-only (no accept/turn-in/sell/abandon);
- our own frames;
- no Blizzard hooks or frame writes, no map data providers, no canvas children;
- no combat-log events;
- `Safe()` around every client value.

"Port" means copying the code with attribution under its licence. "Reimplement" means our own code from the
described logic.

### 1. Quest facts by ID, with spawn camps (offline generator + `QuestFacts.lua`)

**Algorithm**
1. Our own offline script (not run in game) reads forever-db JSONL: quest, quest_start, quest_end,
   quest_objective, quest_prereq, spawn, npc, ui_map, mechanic.
2. For each quest it emits: level, min_level, side, race mask (Skyborne in a separate high field), class mask,
   xp, giver and turn-in (kind, id, map, x%, y%), prereqs (all/any/breadcrumb), objectives (kind, target id,
   count), and flags (group/elite, timed seconds, escort).
3. Spawns are converted with the ui_map formula (§2.5) into the Classic uiMap where the point falls inside the
   frame.
4. Each objective's spawns are clustered into camps: leader assignment within 70 yd, then 2 k-means passes. The
   radius is the max member distance, with a minimum of 15 (or `min(250, max(70, 2·median spacing))` for big
   sets). Keep at most 6-8 camps per objective, as `{x, y, r, n, lvl}`.
5. `Routes.lua` steps gain an `id` field. Titles become display text only.

**Data**: forever-db 2026.11.1.

**Port**
- `rust\crates\forge-guide\src\cluster.rs` + `resolve.rs:34-44` (GPL-3.0-only) as an algorithm in our script.
- The frame formula from `forever-db\schema\ui_map.schema.json`.

**Size**: script about 400 lines. Output about 400-700 KB of Lua for 1-60 Alliance + Horde (estimate), loadable per
faction.

### 2. Recompute-from-state placement with an anchor (replace frontier/LastProgress)

**Algorithm** (after Polestar `place`/`anchorStep`, E:3062-3449, and Ding resume)
- Wait for the first `QUEST_LOG_UPDATE` (or 5-10 s). Never place from an empty log.
- `start` = the first applicable step with a quest in the log, or a doable accept (prereqs met, level met).
- `anchor` = the last step whose quest is turned in or has objective progress. Only quests our route gives at or
  before that step count; class-only and optional steps are not evidence.
- Pass the steps before max(start, anchor) only when their open goals are:
  - level- or prereq-gated accepts → shown "later";
  - soft steps (go, train, vendor) whose follow-up quest work is done;
  - travel while already within 150 yd of the start step's work.
- **Deferral never counts as completion** (Wisp rule): a passed or skipped accept never satisfies a prerequisite.
- Optional catch-up: drop green accepts behind the anchor unless a still-worthwhile quest needs them (BFS over
  prereqs).
- `when`-style gates latch once passed.

**Data**: item 1 (prereqs, IDs) and the completed set (`GetAllCompletedQuestIDs`).

**Port**: Polestar `anchorStep`, `place`, `catchUp`, `needsFrom` (GPL-3.0-only, E:209, 3062-3449), adapted to our
step table.

**Size**: about 250 lines.

### 3. Gossip is the authority on availability (fix the negative use of quest lines)

**Algorithm** (Polestar `checkOffers` + DonData `Offers`/`NotHere`)
- On `GOSSIP_SHOW` / `QUEST_GREETING`, read the offered and active quest IDs. If any entry is unreadable (secret),
  judge nothing.
- For each route accept at this NPC (by NPC id from `UnitGUID("npc")`, secret-guarded) that is not offered:
  - if the data explains it (level, prereq not yet turned in) → "later" with the reason;
  - else store `notOffered[q] = {level, npc, x, y, t}` per character and show "not offered here (report)". Never
    hide a quest the game lists.
- Ignore a dialog within 3 s of a turn-in at that NPC.
- Clear the mark on:
  - level above the stored level;
  - 30 min passed;
  - a turn-in at that NPC or within 100 yd, or of the quest's prereq;
  - the quest being accepted or offered.
- Account-wide "never here" only after 3 distinct levels, or once at or above the game level.
- `GetAvailableQuestLines`: only after `RequestQuestLinesForMap`. A listed quest means available; an **empty list
  means no answer**.

**Data**: item 1 givers.

**Port**: DonData `Engine\Offers.lua:31-394` and `NotHere.lua` (MIT); Polestar E:10895-11045 (GPL-3.0-only).

**Size**: about 250 lines.

### 4. XP model, route projection and XP-aware ordering

**Algorithm** (Polestar `Levels.lua`, formulas in §1.8)
- `share(d)`, `greyLevel(L)`, `zeroDiff(L)`, `mobXP(L, M, elite)`.
  - Trivial: prefer `C_QuestLog.GetTrivialRange`, else greyLevel.
  - Quest level: prefer the server level (item 9).
- **Projection**: simulate the remaining route in order:
  - turn-ins add `xp × share(L − q)`;
  - kill objectives add count × mobXP at the mob's mid level, one kill at a time so level-ups apply;
  - collect objectives use ceil(count/drop) kills when the drop rate is known.
- **Outputs**:
  - header "route ends ≈ L 23.4";
  - per-step planned level;
  - "short by N bars → grind at <camp>";
  - the first quest still ≥ 3 levels above the projected level ("hard").
- **"+N XP waiting"**: sum of `GetQuestLogRewardXP` for ready quests.
- **Replace `Cost`'s `XP_WEIGHT`**: cost = seconds(dist)/7 + action seconds; then order by XP per second where
  candidates tie on distance (keep `KEEP_RATIO`).
- **Turn-in now vs later**: if share(L_now − q) > share(L_at_planned_step − q), double the detour budget (Polestar
  `hereXpLoss`).

**Data**: item 1 (xp, quest level, npc levels; drop rates from item_source where present).

**Port**: `addon\Polestar\Core\Levels.lua` core about 150 lines (GPL-3.0-only), or `rust\crates\forge-sim\src\xp.rs`
as reference.

**Size**: about 200 lines plus UI.

### 5. "While you're here" with a seconds-based detour budget

**Algorithm** (§1.6)
- **Candidates**: later route steps on the current map:
  - work objectives of quests in the log (mobs ≤ L+2);
  - ready turn-ins not at the live step.
- **Work distance**: to the nearest camp centre, capped at 30 if a mob was seen on a nameplate, target or mouseover
  in the last 5 s.
- **Showing a line**
  - Work: d ≤ 180 (setting 60-400).
  - Turn-in: extra = d(P,N) + d(N,W) − d(P,W); seconds = extra × 1.25 / 7; show if ≤ 20 s (×2 when the XP share
    would drop), or at the NPC (30 yd), or resting with d ≤ 100.
- **Hiding a line**
  - Clear beyond 1.67 × radius (≤ 600), or after 180 s out of reach.
  - Dismiss → 120 s *and* 100 yd away; a second dismiss → for the zone stay.
- **Limits**: at most 3 lines and 10 candidates measured, re-picked every 25 yd. Camps with few spawn places come
  first, then nearest; 30 yd swap hysteresis.
- Pause in combat, on a taxi, in an instance, and during timed quests.

**Data**: item 1 camps.

**Port**: Polestar E:8316-9491 math (GPL-3.0-only); Ding `Core\Along.lua:81-198` (GPL-3.0, simpler 100/160 yd
version) as a first cut.

**Size**: about 250-350 lines. Replaces our "On the way" side rows.

### 6. Arrow quality: damping, ETA, arrival hysteresis, target hysteresis

**Algorithm**
- **Bearing damping**: `turn = diff × (1 − e^(−12·dt))`, capped at 3.5·dt rad. Damp on the map bearing; subtract
  facing every frame.
- **ETA**: closing speed EMA `cs += (Δd/Δt − cs)·min(1, 2dt)`; show when cs > 1.5 yd/s.
- **Arrival**: radius per kind (8 default; NPC 8; area = camp radius; flight landing 30). Un-arrive only beyond
  r + max(5, r/2). This replaces the flat `ARRIVED_YARDS = 12`.
- **Target switching among field goals**: only when the new target is >25% and >40 yd nearer (Polestar), or under
  half the distance and >40 yd nearer (Ding). Never in combat or within 5 s of objective progress.
- **Waypoint pin**: read back `GetUserWaypoint` before `SetSuperTrackedUserWaypoint`, and treat an unexpected
  `USER_WAYPOINT_UPDATED` as the player taking over (Wisp idea, reimplemented). Our `ForeverWaypoint_Set` already
  has most of this.

**Port**: `addon\Polestar\Nav\Arrow.lua:509-625` + `Nav\Nav.lua:361-433` (GPL-3.0-only; drop the 3D sprite sheet);
Ding `Engine.lua:1572-1614` (GPL-3.0).

**Size**: about 150 lines.

### 7. Travel planner over flights, boats, hearth and zone crossings (replace `ways`)

**Algorithm** (§2.3, after Polestar `Travel.lua:955-1000` and Ding `Travel.lua:348-472`)
- Vertices: player, target, known taxi nodes, docks, inn (hearth), zone-crossing points.
- Edge costs:
  - walk = straight × 1.25 / speed (speed from position deltas, default 7, mount ×1.6 at 40);
  - flight = yards/30 + 2 s per hop (known nodes only; +60 s to learn one on the way);
  - boat = mean wait + ride;
  - hearth (if off cooldown) = 15 + 120 s, used only if the trip is ≥ 180 s without it and saves ≥ 120 s;
  - zones with minimum level ≥ L+4 ×3, > L+10 ×20 (start and goal zones exempt).
- **Output**: a leg list ("Fly Auberdine → Stormwind ≈ 2:10", "Boat Auberdine → Stormwind Harbor, waits ≈ 2 min").
  The arrow points at the first leg's point. Replan after 30 s and 50 yd moved.
- **Known flight paths**: read `C_TaxiMap.GetAllTaxiNodes` while the flight map is open (we already record flights,
  `RecordFlights` 3308).
- **Option**: show `C_Navigation.GetNextWaypointForMap` text if available. No engine we may copy uses it, so treat
  it as an experiment.

**Data**: the taxi, flights, transports, inns and crossings tables from `addon\Polestar\Nav\TravelData.lua`, about
69 KB, to be trimmed to a loader format. It includes Auberdine↔Stormwind, Steamwheedle↔Powderfuse (Riverglades)
and Zephras Isle (continent 2991).

**Port**: TravelData (GPL-3.0-or-later header for the SPF parts, Carbonite GPL-3.0 crossings); the Dijkstra
reimplemented in our style, or Ding's `Travel.lua` (GPL-3.0) ported.

**Size**: about 300 lines + 40-70 KB data.

### 8. Spawn camps for work steps (multi-camp arrow, circuit, dwell)

**Algorithm** (Polestar `Spots`, E:2140-2337)
- Point at the nearest camp at or below L+1. Switch camps only when another is >40 yd closer.
- Area circuit: a camp is visited inside its radius, left after 4 yd, forgotten after 300 s.
- Dwell: 7 s within 10 yd with no objective progress and no combat → move on to the next camp.
- Fights are noted by position (merged within 20 yd). A camp where the player fought counts for every objective
  whose camps lie there, so shared-ground objectives are grouped naturally.
- Show the camp radius as a disc on our own map overlay.

**Data**: item 1 camps.

**Port**: Polestar E:2102-2337 and E:4592-4720 (GPL-3.0-only).

**Size**: about 300 lines. It replaces our hand-typed `pointMode` loops where data exists.

### 9. Server quest levels and trivial range

**Algorithm** (DonData `Levels.lua`)
- For route quests only (a few hundred, not the whole DB): queue `RequestLoadQuestByID`. Run one every 0.5 s,
  never in combat, starting 60 s after login.
- On `QUEST_DATA_LOAD_RESULT` (or after 5 s), read `GetQuestDifficultyLevel`. Store it only if it differs from item
  1, keyed by client build.
- **Never treat `success=false` as "quest missing".**
- Use it for colour, grey checks and the XP projection.

**Port**: `G_DonData\DonData\Engine\Levels.lua` (MIT, about 200 lines), trimmed.

**Size**: about 120 lines.

### 10. Lost, abandoned and skipped quests

**Algorithm**
- On `QUEST_REMOVED` without a turn-in, if the route had passed that quest's accept: hold it as "lost". Show a
  small card "Go back for X / Skip it". The arrow points at the giver until the player answers. A failed quest
  defaults to "back".
- Skipping a quest skips its follow-ups through the prereq graph. A skip-undo lasts 8-10 s; we have
  `SKIP_NOTICE_SECONDS = 10`.
- **Fit an extra quest** (Leveldon rule, reimplemented): when the player accepts a quest that is not on the route:
  - find the first upcoming step (within 150) that is within 250 yd of one of its camps, and insert a `do` after it;
  - then the first stop within 80 yd of its turn-in, and insert the turn-in after that hub;
  - else show "not on your route".

**Data**: item 1.

**Port**: Polestar `holdLost`/`SkipQuest`/`preBlocked` (GPL-3.0-only, E:6748, 10382). The fit logic is
reimplemented (Leveldon has no licence).

**Size**: about 200 lines.

### 11. Exact in-hub ordering

**Algorithm** (Leveldon idea, reimplemented)
- When the current hub has ≤ 7 NPC groups (NPCs within 10 yd form one group), solve the order exactly with
  Held-Karp DP over subsets (2^7·7² ≈ 6k operations).
- Constraints: a quest's steps keep their order; an accept comes after its prereq's turn-in.
- Add +60 yd for entering or leaving a building (indoor flag from the npc spawn, or a manual flag).
- Apply only if it saves more than 5 yd.
- Above 7 groups, keep our greedy nearest-neighbour.

**Data**: NPC points from item 1.

**Port**: none; our own code. A good fit next to `Route()`.

**Size**: about 100 lines.

### 12. Timed, group/elite and escort handling

**Algorithm**
- Timed quests (forever-db `mechanic` timed 53 rows, plus `C_QuestLog.GetTimeAllowed` at accept): the do/turnin goes
  directly after the accept, and nothing else is inserted while the timer runs. We have `PutTimedFirst`; give it
  data.
- Group/elite: a per-character answer "ask/do/skip" for each group quest. The default route leaves them out with a
  "group" tag; ask only when the quest can be taken now.
- Elite mobs (npc rank 1-3) get a ⚠ tag on the step.

**Data**: forever-db `mechanic` (CC BY 4.0, credit) and `npc.rank`.

**Port**: Polestar `groupAnswer`/`groupOpen` (E:654-681).

**Size**: about 100 lines.

### 13. Secret-safe objective reading and objective-line matching

**Algorithm**
- If numFulfilled/numRequired are secret, parse the last "N/M" in the objective text when the text itself is
  readable (Ding).
- Match the step's target name to the label with counts stripped: exact match, else the shortest containing label,
  else the index (Polestar).
- An unfilled objective list means "not known", not "done".
- With full counters but no readiness answer, do not call the quest complete (Wisp quirk).

**Port**: Ding `Core\Compat.lua:13-96` (GPL-3.0); Polestar E:2456-2574 (GPL-3.0-only).

**Size**: about 100 lines.

### 14. Route-key remap on route edits

**Algorithm**: hash each step's content to a key (djb2 over kind + id + place), store ticks and skips by key, and on
a `Routes.lua` change match the old and new key sequences by LCS so ticks follow their steps. Our
`MigrateKeys`/`RouteKeys` does this by title today.

**Port**: Polestar `Own.matchSteps` E:4910-4967 (GPL-3.0-only).

**Size**: about 60 lines.

### 15. Kills-to-level and pace

**Algorithm**
- Store kill XP as a ratio to `mobXP(L, L)`. The median of the last 30 gives XP per kill.
- Rested-aware: kills left = ceil(max(missing − rested, missing/2) / perKill).
- XP/hour over a rolling 900 s (minimum span 60 s).
- Split by source with the `QUEST_TURNED_IN` payload and the `CHAT_MSG_COMBAT_XP_GAIN` arrival time within 1 s
  (never parse secret text).

**Port**: Ding `Core\Grind.lua:11-171` (GPL-3.0); Polestar `QoL\XP.lua` (GPL-3.0-only).

**Size**: about 150 lines. Could live in our existing XP helper rather than LevelGuide.

### 16. Personal location corrections

**Algorithm**: right-click a step → "the NPC/spot is here". Store `{key, original point, player map/x/y}` per
character, prefer it over route data, re-apply it after data updates, and cap the count.

**Port**: ForeverQuest `Corrections.lua:43-152` (GPL-3.0).

**Size**: about 100 lines.

### 17. Projected-route choice card

**Algorithm**: at a branch (end of a zone), list each candidate next route with:
- projected hours (item 4's simulator with talk 6 s, object 8 s, kill time (11 + 19(L−1)/59) s, run 7 yd/s);
- quest count, XP, and "out-levelled" status.

Rank by not out-levelled, then travel time in 60 s bands, then author order. Remember the choice per character.

**Port**: Polestar `rankRoutes` (E:6358) + the forge-sim constants.

**Size**: about 150 lines + a small window.

### 18. Death-skip and riding-money hints

**Algorithm**
- Below level 10, if the next step is far from the current spot and within 300 yd of a spirit healer, show
  "faster: die and resurrect at the healer" (text only).
- From level 38: "Riding at 40: 120 g (paladin/warlock 100 g); you have X" from `GetMoney`. Verify the cost in game
  first.

**Port**: none (Leveldon idea).

**Size**: about 60 lines.

### 19. Baked walking legs and a path follower (stage 1 of real walking routes)

**Algorithm**: offline, bake one polyline per route leg (Douglas-Peucker at 4 yd, xy quantised to 0.5 yd). In game,
the Follow aim point is the furthest path point within 35 yd of the player and 45 yd ahead, inside a 20 yd corridor.

**Data**: legs need a walking grid to compute. Our options:
- Polestar's `Legs.lua` — **Leffe caveat**;
- recorded walks of our own (a recorder writing SavedVariables while the owner plays);
- SPF's own data (GPL-3.0-or-later).

**Port**: `addon\Polestar\Nav\Follow.lua` (GPL-3.0-only) and `Nav\Baked.lua` (decoder).

**Size**: about 400 lines + about 0.5 MB per race route.

### 20. Full HPA* walking router (stage 2, only after the licence question)

**Algorithm**: §2.2.

**Port**: `addon\Polestar_Nav\Routing\*` (GPL-3.0-or-later).

**Data**: about 38 MB on disk and 45-75 MB in memory with Polestar's packs. This is too heavy for a helper suite
and carries the Leffe caveat. It is better to cooperate with an installed Polestar_Nav or Shortest Path Forever
through a public API if they expose one.

**Size**: very large. Not recommended now.

### Not recommended

- Auto accept/turn-in/reward, accept-ahead, auto turn-in of while-here lines.
- Sell, repair, buy, train-all, bind, taxi or gossip clicks.
- Abandon buttons.
- Quest-function post-hooks for "talk" ticks (Polestar E:10883). Use the `QUEST_ACCEPTED`/`TURNED_IN`/window-close
  events only.
- `TakeTaxiNode` hooks to learn flight times. Measure from `PLAYER_CONTROL_LOST`/`GAINED` with `UnitOnTaxi`
  instead.
- Map data providers, `AcquirePin`, canvas children, hiding Blizzard's tracker or POIs or `SuperTrackedFrame`.
- Public-channel crowd learning.
- `COMBAT_LOG_EVENT_UNFILTERED`.

## 13. Summary

The strongest open engine is Polestar.
- **Approach**: progress is recomputed from live state, never stored. Placement uses an anchor taken from the
  quest log, and the open NPC window decides whether a quest is available. "While you're here" is priced in
  seconds of detour, and the arrow is damped with hysteresis.
- **Models**: an exact XP model (Levels.lua) and a Dijkstra travel planner fed by real taxi, boat and timetable
  data, including Forever's Auberdine–Stormwind and Riverglades boats.
- **Offline**: its route optimiser is a local-search descent priced by an XP/time simulator. Its forever-db gives
  us the IDs, prerequisites, camps and map frames our title-keyed routes lack.
- **Others**:
  - DonData (MIT) adds the most trustworthy rules for Forever's quirky APIs: server quest levels, no negative use
    of load failures or empty quest-line lists, and a "not offered here" memory with exact clearing rules.
  - Ding and ForeverQuest (both GPL-3.0) add secret-safe objective counts, anti-flip targeting, rested-aware
    kills-to-level and personal corrections.
  - Leveldon, Guidelime and ForeverWisp contribute ideas only (no licence or ARR): extra-quest fitting, exact
    in-hub ordering, "deferral is never completion evidence", the waypoint lease.
- **Order to build**: data (item 1) unlocks most of the list, so build it first. Then placement, gossip authority,
  the XP projection, while-you're-here and the arrow. Postpone walking-grid work until the Leffe permission
  question is answered.
