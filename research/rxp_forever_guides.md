# RestedXP's free Forever 1-20 guides: how they work, the Night Elf priest route, and what LevelGuide needs

This builds on `research/rxp_deep.md`, which already covers RXP's engine in general: the tag list, the ticker, saved progress and the non-guide features. This file covers:

- how the **free Forever 1-20 Alliance guides** (`Guides/forever/*.lua`) actually use that engine;
- the exact runtime rule behind every tag they use, traced in `functions.lua`, `GuideWindow.lua`, `GuideLoader.lua` and `map.lua`;
- the Night Elf route a level ~11 priest would follow from Dolanaar to level 20;
- what our `LevelGuide` (`LevelGuide.lua`, `Routes.lua`) would need to behave the same way.

**Method.**
- The source was read only, never run.
- Step and tag counts come from a small parser over the guide files.
- Forever guides store **world** coordinates (`map/instance, worldA, worldB`). To give zone percentages, I fitted a linear transform per map:
  - The fit uses two sources: the guide's own zone-percent comments, and the same NPC's percent position in RXP's Classic guides.
  - It reproduces the comment pairs to within 0.0–0.2 percentage points on every map (Redridge is the worst at 0.2).
  - Coordinates below are zone-map percent (x, y) unless marked otherwise.
- Quest, NPC and item names, IDs, coordinates and levels are game facts. Every instruction is written in our own words.

---

## 1. How a Forever guide step is built and evaluated

### 1.1 Guide headers in the Forever files

| Header | Use in the Forever guides |
|---|---|
| `#forever` | The guide loads only when the game flavour is Forever. Every free guide also has a Classic twin. |
| `#disabledungeons` | Present in every free "Speedrun Guide 1-20" guide. Dungeon-only branches are switched off. The dungeon versions are a separate group (see 1.8). |
| `#season 0,1` | Era/SoM only. The Night Elf 1-10 file also has `<< sod` display names that never apply on Forever. |
| `#group` / `#subgroup` / `#name` / `#displayname` | Group "RestedXP Forever Guide (A)", subgroup "Speedrun Guide 1-20". The display name can differ by race: the 14-16 Darkshore guide is shown as "11-16 Darkshore/Loch Modan" to Night Elves. |
| `#defaultfor` | The race whose level-1 start picks this guide (`NightElf` for Shadowglen). |
| `#next a;b` | The next guide when this one ends. The first candidate that applies to the player wins (filters, level, XP rate). |
| `#include Group\Guide[@labelA-labelB]` | Splices another guide's steps in place, all of them or a label range. |

**Free Alliance guides on Forever.** The 1-20 chain for a Night Elf, in order:

1. `1-6 Shadowglen`
2. `6-11 Teldrassil`
3. `14-16 Darkshore`, shown to Night Elves as "11-16 Darkshore/Loch Modan". For Night Elves it `#include`s the whole `15-16 Loch Modan` guide in the middle.
4. `16-19 Darkshore`
5. `19-20 Redridge`. This is the non-Hunter path. Hunters go to `19-21 Darkshore/Ashenvale` instead.
6. `20-21 Darkshore/Ashenvale`

`20-21 Darkshore/Ashenvale` names `21-23 …` as its next guide, but **that guide is not in the free repository**. The free guides end at 21.

### 1.2 Lines and filters

- **`step << filter`** is a parse-time filter. When it fails, the step is not loaded at all.
  - The filter is a list of alternatives separated by `/`. Inside one alternative, all space-separated tokens must hold, and `!` negates a token.
  - Tokens are class, race, faction, game or season names.
  - Example: "NightElf !Hunter/Druid/Warrior" means "a Night Elf who isn't a Hunter, or any Druid, or any Warrior".
- **`element << filter`** does the same for one line inside a step.
- **`>>text`** adds a free text line to the step.
- **`+text`** is a **manual objective**. It has a tick box the player checks, and it blocks the step until ticked.
- **`*text`** is a plain note.
- `|cRXP_FRIENDLY_…|r` / `|cRXP_ENEMY_…|r` / `|cRXP_WARN_…|r` / `|cRXP_BUY_…|r` / `|cRXP_LOOT_…|r` are colour tokens. `Name::npcID` lets the name be localized.

**Filter counts in these two files.**

| Filter | NE 1-10 file | 11-20 file |
|---|---|---|
| Unfiltered steps | most | most |
| `Hunter` | 39 | 21 |
| `Warrior` | 26 | 11 |
| `Druid` | 25 | 54 |
| `Priest` | 23 | 5 |
| `Rogue` | 20 | 29 |
| `Druid/Priest` | 11 | — |
| `NightElf` / `!NightElf` | — | 18 / 19 |
| `NightElf`-combined filters (`Druid NightElf`, `NightElf Hunter`, …) | — | ≈ 60 |

The 11-20 file serves every Alliance race, so a large share of its steps are race forks (`NightElf`, `!NightElf`, `Skyborne`, `Dwarf Hunter`, …).

### 1.3 Tag frequencies in the two guides that matter here

These counts exclude commented-out lines. The whole-Forever counts are in `rxp_deep.md` §2.1.

| Tag | NE 1-10 (360 steps) | 11-20 (939 steps) |
|---|---|---|
| `>>` text | 426 | 1062 |
| `.goto` | 360 | 1381 |
| `.target` / `.mob` | 205 / 116 | 464 / 278 |
| `.accept` / `.turnin` / `.complete` | 106 / 111 / 114 | 281 / 251 / 196 |
| `.collect` | 48 | 135 |
| `.isOnQuest` / `.isQuestComplete` / `.isQuestTurnedIn` / `.isNotOnQuest` / `.isQuestNotComplete` / `.isQuestAvailable` | 22 / 9 / 4 / 3 / 3 / 0 | 110 / 48 / 48 / 0 / 0 / 9 |
| `.itemcount` / `.itemStat` / `.money` / `.skill` | 34 / 30 / 13 / 9 | 89 / 29 / 11 / 47 |
| `.zoneskip` / `.subzoneskip` / `.zone` / `.subzone` | 2 / 2 / 4 / 0 | 88 / 17 / 24 / 13 |
| `.xp` | 25 | 45 |
| `.use` / `.usespell` / `.macro` / `.cast` | 32 / 0 / 0 / 2 | 36 / 12 / 4 / 22 |
| `+` manual objectives | 25 | 23 |
| `.trainer` / `.train` / `.vendor` | 24 / 16 / 17 | 41 / 31 / 21 |
| `.hs` / `.home` / `.bindlocation` / `.fp` / `.fly` | 4 / 1 / 0 / 0 / 1 | 12 / 6 / 6 / 11 / 20 |
| `.deathskip` | 8 | 4 |
| `.waypoint` / `.line` | 0 / 2 | 67 / 2 |
| `.disablecheckbox` / `.abandon` / `.destroy` | 7 / 3 / 0 | 18 / 9 / 9 |
| `.timer` / `.cooldown` / `.aura` / `.unitscan` / `.link` | 0 / 0 / 0 / 4 / 2 | 12 / 11 / 8 / 11 / 15 |
| `.group` / `.solo` / `.bronzetube` / `.equip` / `.gossipoption` / `.skipgossip(id)` / `.maxlevel` / `.bankdeposit` | — | 4 / 2 / 4 / 3 / 1 / 5 / 1 / 1 |
| `#completewith` | 89 | 252 |
| `#optional` | 29 | 271 |
| `#label` / `#requires` | 39 / 17 | 171 / 39 |
| `#sticky` | 19 | 31 |
| `#loop` | 4 | 28 |
| `#softcore` / `#hardcore` | 9 / 7 | 4 / 3 |
| `#ah` / `#ssf` | 3 / 2 | 13 / 6 |
| `#xprate` / `#level` / `#map` / `#include` / `#hidewindow` | 4 / 3 / 0 / 0 / 0 | 0 / 0 / 2 / 1 / 1 |

### 1.4 The step lifecycle (exact rules)

This section explains what "current", "sticky" and "active" mean, and when each changes. Source: `GuideWindow.lua` `SetStep` and `UpdateStepCompletion`, plus the guide-load pass at about line 1974.

**At load time:**
- A step with **no elements** becomes `optional`.
- A step with **`#completewith X`** automatically becomes **sticky**. The two step tags are therefore one concept with two ways of ending.
- A step with `#requires L`, where L is a sticky with no `#completewith`, rewires L: L gains `#completewith` pointing at this step. So "B requires sticky A" also means "A disappears once the pointer passes B".
- Labels map to step indexes. `next` means index + 1.

**The pointer.**
- The guide keeps one index `n`, the current step. It only ever moves forward, except when the user clicks a step.
- When `n` lands on a sticky step, the pointer immediately moves to `n + 1`. **A sticky is never "the current step".** It turns on once the pointer has passed it.

**The active set, rebuilt each time the pointer moves.** The set is built in this order:
1. **Every earlier sticky step** (index < n) that meets all of these:
   - it is not yet finished;
   - its `#requires` target is no longer active;
   - the player's level is at least the step's `#level`.
   These go in index order, so older stickies come first.
2. **The current step**, unless one of these holds:
   - It is already complete. Then the pointer moves on.
   - Its level gate is unmet.
   - Its `#requires` target is still active. This wait only holds while something else is showing. With an empty active set, the requirement is ignored.
3. If the set is empty, the pointer moves to `n + 1`. At the end of the guide it loads `#next`.

**Completion check** (`UpdateStepCompletion`, run whenever any element reports a change). An active step counts as complete when either of these holds:
- every element is completed, ticked by the user, or text-only;
- or it has `#completewith T` and T has been passed:
  - if T is an ordinary step: the pointer is beyond T;
  - if T is itself a sticky: T is finished.

What happens next depends on the step:
- A completed **sticky** is recorded as finished and drops out of the active set. The pointer does not move.
- A completed **current step** sets "load next step", and the ticker moves the pointer to `n + 1`.

**Guards.** Elements such as `isOnQuest`, `itemcount`, `money` and `zoneskip` (see 1.5) do not complete an element. They mark the **whole step** complete. The same rule then applies: a sticky is dropped, a current step is passed.

**What the step tags do.**
- **`#optional`**: the step is hidden from the scrollable step list, but runs normally when active. In practice optional steps always carry a guard, so they appear only when they apply.
- **`#hidewindow`**: the step is never drawn, but its logic and coordinates still run. It is used for invisible arrow loops.
- **`#softcore` / `#hardcore`**: kept only when the hardcore setting matches.
  - On a normal Forever realm, the softcore branch applies: the deliberate deaths with `.deathskip`.
  - Any step containing `.deathskip` is softcore automatically.
- **`#ah` / `#ssf`**: kept according to the "solo self-found" setting. By default `#ah` steps show and `#ssf` steps are hidden.
- **`#xprate <1.99`**: only below a detected XP-buff rate of 1.99.
- **`#level N`**: activates at level N or above.
- **`#loop`**: when every waypoint in the step has been reached, they all reset. The step then becomes an endless circuit until its objective completes.
- **`.group` / `.solo`**: show or hide by the "group quests" setting. `.group` also adds a warning line.

**Consequence: three things are on screen at once.**
1. The current step.
2. Every older sticky still running. These are the "while you're out there" tasks.
3. The upcoming steps, shown dimmed in the list.

**This is how the guides express parallel work.** Example from Teldrassil:
- One sticky collects 7 Small Spider Legs `#completewith` the step labelled "spiderLegs".
- Five ordinary steps then run underneath it: turn-ins, a phial, travel.
- When the pointer passes "spiderLegs", the sticky vanishes whether or not it finished. A later step picks up any remainder.

### 1.5 Every tag used, traced to its runtime rule

Columns:
- **Kind**: **O** = an objective that must complete; **T** = text-only, never blocks; **G** = a guard that can skip the whole step.
- **Completes when** names the event, API and condition.

Elements are evaluated only when their own events fire, at step activation, or on the window refresh. Almost every element does nothing while its step is not active.

| Tag (args used) | Kind | Completes / skips when | Player sees | Notes for us |
|---|---|---|---|---|
| `.accept id` | O | Complete when the quest is in the log or already turned in (`IsOnQuest`, `IsQuestFlaggedCompleted`). Re-checked on `QUEST_ACCEPTED`/`TURNED_IN`/`REMOVED`. On `QUEST_REMOVED` of that ID it becomes incomplete again. | "Accept X" with a tick box | An already-held quest completes the line the moment the step activates, so skipping ahead is free. RXP also auto-accepts; **we never do**. A Questie-backed "missing prerequisites" tooltip appears only when Questie is loaded. |
| `.turnin id[,reward]` | O | Complete on `QUEST_TURNED_IN` of that ID, or `IsQuestFlaggedCompleted` while active. **A positive ID never auto-skips when you lack the quest.** A negative ID skips if it's not in the log (used once: `-97914` Expanding Horizons). | "Turn in X" | The guides protect optional turn-ins with guards (`isOnQuest`, `isQuestComplete`). Without them a missing quest would block the step until ticked by hand. `reward` is RXP's reward pick; ignore it. |
| `.complete id,obj` | O (T with flag 1) | Complete when that objective is `finished` in `GetQuestObjectives`, or the quest is turned in. The quest being "ready" is not enough unless the objective is finished. Re-read on `QUEST_LOG_UPDATE`. | "Nightsaber Fang 2/3" (live) | One line per objective. Several `.complete` lines for different objectives sit in one step. |
| `.collect item[,qty,quest,objMask,flags,skill]` | O | Complete when the bag count (plus equipped items, plus toys) ≥ qty, **or** the given quest is complete or turned in. `objMask` 0 means "done if you hold the quest". **Flag 0x20 + skill name** makes the required count = qty minus the current skill level. | "Small Egg: 4/10" | Two forms appear in this route. "7 Small Spider Legs for quest 4161, collected before you have that quest". And "Small Eggs needed = 10 − your Cooking". |
| `.goto map/inst,a,b` (no radius) | arrow | Never "completes". It is a pointer that belongs to the **previous objective in the same step** (see 1.6), or to the whole step if it comes first. | Arrow + map pin | The default. Hidden once its objective completes. |
| `.goto …,R` (R > 0, no 5th arg) | O | Complete when within R yards (world distance). | "Go to …" | A travel objective, e.g. "travel to the Pools of Arlithrien". |
| `.goto …,R,0` (R > 0, any 5th arg) | T | **Path point**: no pin, marked reached within R yards, and the arrow moves on. | Arrow only | Chains of these build a route. The last point usually has no radius. |
| `.goto …,0` | T | Pin only, no arrow. | Pin | Marks areas for stickies without stealing the arrow. |
| `.goto …,0,0` | T | **Low-priority** arrow target: used only when nothing else wants the arrow. | Arrow if idle | Most sticky "kill these on the way" steps use this. |
| `.goto …,-R` | T | **Dynamic**: of all such points, the arrow takes the nearest. | Arrow | Not used in this route. |
| `.waypoint map/inst,a,b,R,0` | T | Like a path point but never pinned. With `0` it is low priority. | Arrow only | Used for the long beach and grind loops. |
| `.line zone,…` | T | Draws a polyline on the map, used for patrols (Moon Priestess Amara, Mountaineer Kadrell). | Map line | |
| `.xp L` / `L.f` / `L+N` / `L-N` | O | Complete when level > L. Or, at level L: XP ≥ f·max, or XP ≥ N. For `L-N`: level ≥ L, or at L−1 XP ≥ max − N. Checked on `PLAYER_XP_UPDATE`/`LEVEL_UP`. | "Grind until 870 xp off 10 (5630/6500)" | The text shows live (cur/target) at the right level. |
| `.xp L,1` / `.xp <L,1` | G | `L,1`: skip the step when the level rule is met. `<L,1`: skip when it is **not** met, i.e. below L. Needs the "XP step skipping" setting, which is on by default; `<` works regardless. | — | **Quirk**: `>L` isn't parsed as an operator. `.xp >10,1` behaves exactly like `.xp 10,1`, "skip at level ≥ 10". The guides use `>` 14 times, apparently meaning "above 10". |
| `.isOnQuest ids` / `.isNotOnQuest` | G | Keep the step only while on (or not on) any of the quests. Otherwise skip. | — | Re-checked live, so a sticky ends by itself when its quest leaves the log. |
| `.isQuestComplete id` / `.isQuestNotComplete` | G | Keep only while the quest is in the log **and** ready to turn in (or not). | — | Guards for optional turn-ins. |
| `.isQuestTurnedIn ids` / `.isQuestAvailable ids` | G | Keep only if any of them is turned in / **not** turned in. | — | `isQuestAvailable` reads as "only if you haven't done it". |
| `.itemcount ids,[<>=]N` | G | Keep only while the count matches. `N` alone means ≥ N; `<N` means fewer than N. | — | "Eat the eggs" exists only while you hold eggs. "Buy a wand" exists only while you hold none. |
| `.itemStat slot,STAT,<v` | G | Keep only while the worn item in that slot has STAT < v (DPS, `QUALITY`, `LEVEL`). Otherwise skip. | — | "Buy this bow only if your current one is worse." Slots: 16 main hand, 17 off hand, 18 ranged, 15 back. |
| `.money <g` | G | Skip if your money is below g gold. g is in gold, so 0.0285 = 2s85c. | — | "Buy it only if you can afford it." |
| `.skill name,N[,1]` / `.skill name,<N,1` | O / G | Without 1: an objective to reach N. With 1: skip when skill ≥ N. With `<N,1`: skip when skill < N. | "Herbalism 9/15" | `.skill cooking,<1,1` means "only if you know Cooking". `.skill cooking,50,1` means "only until Cooking 50". |
| `.cooldown item,6948,>0,1` / `<0,1` | G | `>`: skip while the hearthstone has more than ~2 s of cooldown left. `<`: skip when it is ready. | — | Always used as a pair: "hearth if ready" plus "otherwise walk back". |
| `.zoneskip Map[,1]` / `.subzoneskip areaID[,1]` | G | Skip when you are in that zone or sub-zone. With 1: when you are **not** there. | — | "Take the boat to Stormwind" disappears once you're in any of the listed zones. Sub-zone 442 is Auberdine. |
| `.bindlocation areaID[,1]` | G | Skip when your hearth is already there (or, with 1, isn't). | — | Pairs with `.home` so a second visit doesn't ask again. |
| `.zone Map` / `.subzone areaID` | O | Complete when `C_Map.GetBestMapForUnit` equals the map, or the sub-zone text matches. | "Travel to Darnassus" | |
| `.home [areaID]` | O | Complete on `HEARTHSTONE_BOUND`, or when `GetBindLocation()` equals the area name. | "Set your hearthstone to …" | RXP auto-picks the innkeeper gossip and auto-confirms the bind. **We never do.** |
| `.hs` | O | Complete on the player's `UNIT_SPELLCAST_SUCCEEDED` of hearthstone spell 8690 (or Astral Recall 556). | "Hearth to …" plus the hearthstone on the item bar | |
| `.fp Name` | O | Complete when the node is known: the taxi map was opened, or the `ERR_NEWTAXIPATH` message fired in a zone that has that node. | "Get the X flight path" | RXP auto-opens the taxi gossip. |
| `.fly Name` | O | Complete when `UnitOnTaxi`, or on `PLAYER_CONTROL_LOST` right after the flight starts. | "Fly to X" | RXP **calls `TakeTaxiNode`** itself. That is excluded for us. |
| `.deathskip` | O | Complete when the Spirit Healer interaction window opens (Forever: `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`). | "Die and respawn at the spirit healer" | The step is softcore-only. While a ghost, the arrow points at the nearest spirit healer from `SpiritHealerWorld` (1.6). RXP auto-accepts the resurrection-sickness prompt. Excluded for us. |
| `.vendor [npcID]` | O | Complete on `MERCHANT_CLOSED`. With an ID, only if that NPC's window was the one open (`MERCHANT_SHOW` remembers the NPC). | "Vendor trash / buy X" | It only means "you visited". What to buy is in `.collect` lines and text. |
| `.trainer [npcID]` | O | Complete on `TRAINER_CLOSED`, with the same NPC rule. | "Train your class spells" | |
| `.train spellID[,1]` | O / G | Complete when `IsPlayerSpell(id)`. Flag 1 turns it into "skip the step if you already know it". | "Train Staves" | |
| `.use item` / `.usespell` / `.macro` | T | Puts the item, spell or macro on RXP's floating button bar. | Button | **Secure buttons**; we would only show names. |
| `.cast spellID` | O | Complete on `UNIT_SPELLCAST_SUCCEEDED` of that spell. | "Cast X" | |
| `.target` / `.mob` / `.unitscan` | T | Feed RXP's target macro and nameplate markers. `+Name` ties the mob to the preceding objective, so it is dropped once that objective is done. | Mob names in the step | Proximity scanning is disabled on Forever 1.15.8+ (`DB/forever/rares.lua`). |
| `.disablecheckbox` | T | Makes the **previous objective** text-only: shown with progress, but it no longer blocks the step. | — | Used for "work on this but don't wait for it". |
| `+text` | O | A manual tick box. | Tick box | "Equip the bow", "cook eggs until 10", "bind your interact key". |
| `.abandon id` | O | Complete when the quest is no longer in the log. | "Abandon X" | Used to drop quests the route won't finish. |
| `.destroy item` | T | Marks the item as junk for RXP's bag tools. | "Delete X" | Quest leftovers (Phial of Scrying, Gyromast's Key, Blackwood samples). |
| `.timer s,label` | T | Starts a countdown bar when the parent objective completes. | Bar | Role-play waits (Onu 11.5 s, Xabraxxis 17 s, flight ETA). |
| `.aura` / `.equip` / `.gossipoption` / `.skipgossip(id)` / `.bronzetube` / `.bankdeposit` / `.link` | mixed | `.equip` completes when the item is worn. `.bronzetube` skips when you hold enough Bronze Tubes for "Look to the Stars". `.link` shows a URL. The gossip tags only automate dialogue (excluded for us). | — | |
| `.maxlevel L` | G | Skip when the player's level is above L. | — | Used once. |

### 1.6 What the arrow points at (`map.lua` `updateArrowData` / `UpdateGotoSteps`)

1. **Ghost first.**
   - If the player is a ghost and an active step has `.deathskip`, the arrow goes to the **nearest spirit healer**: the shortest world distance in `SpiritHealerWorld[continent]`.
   - Otherwise a ghost's arrow goes to the **corpse** (`C_DeathInfo.GetCorpseMapPosition`).
2. **Candidate list.**
   - Every coordinate element of the **active steps**, in active-set order: older stickies first, then the current step.
   - Points already reached are dropped. They are saved per step, so a reload remembers them.
   - Points whose owning objective is completed or ticked are dropped.
3. **Choice.** The arrow takes the **first** candidate that:
   - is not low priority;
   - has the arrow flag (a plain `.goto` or a path point);
   - is not reached;
   - and whose owner is unfinished.

   Only when none qualifies does it take the first low-priority point.

   **Why sticky coordinates are low priority.** Because stickies come first in the list, a sticky with a plain `.goto` would steal the arrow from the current step. So every "on the way" sticky in these guides uses pin-only `,0` or low-priority `,0,0` / `.waypoint …,0` coordinates.
4. **Reaching.**
   - Every tick, each point that has a radius is tested against the world distance. Inside the radius it is marked reached, and the next candidate takes the arrow.
   - Path points (`R,0`) step along a road this way.
   - Points with no radius are never "reached". The arrow stays on them until their objective completes.
5. **`#loop`.** When every point of a looping step is reached, all are reset and the circuit starts again.
6. **Other cases.**
   - A target on another continent shows a "wrong continent" state.
   - Inside instances the arrow is hidden.
   - `#map` overrides the map used for display.

**Which objective owns a coordinate.** When parsed, a coordinate attaches to the **most recent objective line above it in the same step**: an accept, turn-in, `.complete`, `.collect`, `+manual` and so on. The first coordinate in a step has no owner and lives as long as the step.

So a step written as "objective A, its coordinates, objective B, its coordinates" points the arrow at A's area until A is done, then at B's area.

The Teldrassil "kill nightsabers / owls / spiders" steps rely on this. Each animal type's patrol points follow that animal's `.complete` line.

### 1.7 Out-of-order play and catching up

**RXP is linear.** It catches up because every step re-checks itself when it becomes current:
- an accept the player already holds completes at once;
- a turn-in already done completes at once;
- guards skip steps that no longer apply (quest gone, item present, level passed, zone wrong).

A step the player skipped past is never re-checked, unless it is a sticky that is still running. That is why the guides repeat important steps later, sometimes three times, each copy guarded so only one shows. Examples:
- "Zenn's Bidding turn-in" appears at three points in Teldrassil.
- "Soft Saber Pelts" is offered optionally four times and finally abandoned.

### 1.8 Dungeon toggles

- The free Speedrun guides carry `#disabledungeons`.
- RXP ships a parallel group, "RestedXP Forever Dungeon Guide (A)" (`Guides/forever/dungeon/Alliance-11-20.lua`). It `#include`s label ranges of the speedrun guides and adds dungeon legs:
  - `11-16 Darkshore/Loch Modan`: includes Darkshore up to the Night Elf exit label, then Loch Modan from the boat to the Ironforge exit. It also sets the hearth to **Ironforge** instead of Auberdine.
  - `17-18 Hall of Thanes` (shown to Night Elves as 16-17). The Forever dungeon under Ironforge. Quests:
    - The Restless Dead 96394 (Afadra Dunwall, Ironforge 32.7,47.7);
    - Important Heirlooms 96403 (Thom Filch, Ironforge 32.2,44.4);
    - An Ancient Grudge 96395 (inside);
    - The Treaty of Understanding 98423 and Old Ironforge Incursion 96393, turned in to King Magni.
  - `18-19 Ruins of Lordaeron`. A Forever dungeon reached from Southshore; all its quests are picked up inside. The leg includes getting the Wetlands and Southshore flight paths.
  - `19-20 Deadmines` (shown to Night Elves as 18-20 Deadmines/Redridge).
  - `20-21 Darkshore/Ashenvale`, with `.dungeon BFD` toggles.
- Dungeon codes appear in `DB/forever/db.lua` (`HOT` 16919, `ROL` 153, `KS` 17780, Krol'dok Stronghold).

---

## 2. Side-step patterns, with concrete examples

### 2.1 Buying: vendor or auction house, what, when, why

| When / where | What | Vendor or AH | Why (our reading) |
|---|---|---|---|
| Shadowglen, priest only. Dellylah, Teldrassil 59.6,40.7 | 15 Refreshing Spring Water, after selling trash | Vendor | A caster's downtime is mana. Buying early avoids a trip back. |
| Dolanaar, priest only. Innkeeper Keldamyr 55.7,59.8, same visit as the hearth bind | Up to 10 Ice Cold Milk | Vendor | Next tier of water for levels 5-10. |
| Dolanaar. Nyoma 57.2,61.2, only if you know Cooking (`skill cooking,<1,1` guard) | 5 Mild Spices | Vendor | Cook the Small Eggs from owls into **Herb Baked Eggs**. In Forever, eating one gives **+5% XP from kills for 15 min**. A sticky reminder ("re-eat when it expires") runs while you hold eggs (`itemcount 6888`). |
| Dolanaar. Narret Shadowgrove 55.3,57.1 | 1 Empty Vial | Vendor | Needed for the Forever quest "The Great Tree Provides" (99050). Buy it before leaving. |
| Darnassus. Vaean 58.6,14.7, then Lalina Summermoon 58.8,12.7. Priest, optional | Lesser Magic Essence (limited stock), Copper Rod, 9 Mote of Magic (Forever item 247786), 9 Simple Wood | Vendor | Learn Enchanting, make a Runed Copper Rod, then practice wands to skill 10. Learn and craft the **Lesser Magic Wand**. Only shown while you have **no wand** equipped or in bags (`itemStat 18 DPS<11.12`, `itemcount 11287,<1`). |
| Darnassus AH, 56.2,54.0 (two auctioneers, nearest wins). Priest/Druid, `#ah` | 1 Minor Wizard Oil, 20 Smoked Sagefish, any wand upgrade | AH | Large damage gain at low level. The fish is regenerating food. Skipped in solo-self-found mode. |
| Darnassus AH, end of Teldrassil, `#ah` | 5 Strider Meat, 6 Darkshore Grouper | AH | **Instant turn-ins in Darkshore**: Easy Strider Living (2178) and The Family and the Fishing Pole (1141). Saves farming. |
| Darnassus. Ilyenia Moonfire 57.6,46.7. Priest/Hunter/Warrior | Train **Staves** | Weapon master | Opens staff quest rewards and vendor staves. |
| Auberdine. Dalmond 37.5,40.5, `#optional` sticky | Small Brown Pouch or Brown Leather Satchel; ammo for Hunters | Vendor | First real bag space. |
| Auberdine. Gorbold Steelhand 38.1,41.2. Night Elf | 1 **Shiny Bauble** and 3 **Nightcrawlers** | Vendor | Held for "Fishin' Time" (95065), an instant accept-and-turn-in with Gilbert Gray at the Stormwind harbour after the boat. |
| Auberdine. Gorbold, while Cooking < 50 and you hold eggs | Mild Spices, one per Small Egg | Vendor | Cook Herb Baked Eggs (campfire at 37.5,41.7, or on the boat). The guide wants **Cooking 50 for a Duskwood quest** later. |
| Auberdine. Dalmond, before the boat | 1 Flint and Tinder, 1 Simple Wood | Vendor | Make a campfire on the dock and cook while waiting for the boat. |
| Auberdine. Laird / Allyndia 36.8,44.2, after the south-coast loop | Food and water | Vendor | Restock before the Blackwood furbolg camps. |
| Stormwind. Ardwyn Cailen 42.9,65.1. Priest/Warlock | **Burning Wand** if it beats yours | Vendor | Advice: take a non-shadow wand because later mobs resist shadow. |
| Stormwind. Billibub Cogspinner 55.2,7.0 | **Bronze Tube** (limited stock) | Vendor | Held for Duskwood's "Look to the Stars". `.bronzetube` hides the step once you have one. |
| Stormwind AH. Auctioneer Jaxon 53.6,59.8, `#ah` | 5 Tough Condor Meat, 5 Crisp Spider Meat | AH | For "Redridge Goulash" (92): only the boar snouts then need farming. |
| Ironforge AH 25.8,75.5, priest/druid `#ah` | Wizard Oil, Sagefish, wand upgrades | AH | A second chance after the Loch Modan leg. |

**Buy-guard patterns used throughout:**
- Afford it: `.money <price`.
- Only if it's an upgrade: `.itemStat slot,DPS,<value`.
- Only if missing: `.itemcount id,<1`.
- Only with the right profession: `.skill …`.

### 2.2 Items to keep for later, and items to delete

**Keep:**
- **Small Spider Legs** (7): looted in Teldrassil long before "Recipe of the Kaldorei" is accepted. A sticky collects them from the start.
- **Small Eggs**: for Cooking. Moonkin in Darkshore drop them; the collect count adjusts to Cooking skill.
- **Darkshore Grouper / Strider Meat**: from the AH or a kill sticky, for the 2178/1141 turn-ins.
- **Severed Voodoo Claws**: if you have them, use them on Lord Melenas to cut his damage.
- **Sprouted Fronds**: the reward from The Sprouted Fronds. An instant heal that doesn't share the potion cooldown.
- **Book: The Powers Below**: drops at the Master's Glaive and starts quest 968. Use it when looted.
- **Enchanted Moonstalker Cloak**: equip it if better, but **keep your old cloak**, because a later turn-in takes this one.
- **Draught of Water Breathing**: from the Threshwackonator quest, for underwater quests later. That is why Gyromast's Revenge is worth trying.
- **Shiny Bauble + Nightcrawlers** (Fishin' Time), **Bronze Tube** ("Look to the Stars"), and the cooking supplies listed above.

**Delete when done** (`.destroy`):
- Phial of Scrying, after The Master's Glaive;
- Gyromast's Key;
- the Blackwood Grain/Nut/Fruit samples, after The Blackwood Corrupted.

**Abandon:**
- Zenn's Bidding, if unfinished when leaving Dolanaar;
- Soft Saber Pelts, when leaving Teldrassil ("you won't return");
- The Moss-twined Heart ("you never get to turn it in");
- Bashal'Aran part 2, if you can't finish it;
- For Love Eternal, if Anaya never showed;
- Gyromast's Revenge;
- Underground Assault, Oh Brother… and Collecting Memories at the start of 20-21. These are Stormwind pick-ups the free route never completes.

### 2.3 Training stops (priest path)

| Where | Level | What |
|---|---|---|
| Laurna Morninglight, Dolanaar 55.6,56.7 | 5-6 | Turn in In Favor of Elune (5622). Accept **Garments of the Moon** (5621). Train. |
| Sentinel Shaya, Teldrassil 57.2,63.5 | 6 | Priest-only: cast Lesser Heal (rank 2) and Power Word: Fortitude on her (5621 objective). |
| Laurna again | 6-8 | Turn in Garments of the Moon. Train. Train again at 8 (step guarded with `xp <8,1`). |
| Laurna, Dolanaar | 10 | Train the level-10 spells before leaving Dolanaar. |
| Priestess Alathea, Darnassus 40.0,80.0 | 10 | **Stars of Elune** (5627): accept and turn in on the spot. |
| Ilyenia Moonfire, Darnassus | 10-11 | Staves. |
| Brother Joshua, Stormwind Cathedral 38.6,26.8 | ~14 and ~19 | Class spells, both times through Stormwind. |
| High Priest Rohan, Ironforge 23.2,7.2 | ~16 | Class spells at the end of the Loch Modan leg. |

**A quirk:** the Ironforge stop on the Loch Modan leg also has an **unfiltered** "train class spells at Bilban Tosslespanner" step. Bilban is the Ironforge **warrior** trainer, so a priest sees a pointless trainer step there. This looks like a guide bug.

### 2.4 Hearth, flights, boats, deaths

**Hearth binds:**
- Dolanaar on arrival, at Keldamyr, together with the Dolanaar Delivery turn-in.
- Auberdine at once on landing in Darkshore, at Innkeeper Shaussiy 37.0,44.1. Guarded with `.bindlocation 442`.
- The hearth then stays in Auberdine up to level 21. In the dungeon variant it moves to Ironforge.
- Redridge sets Lakeshire only for Druids, who can teleport.

**Hearth uses:**
- Darnassus → Dolanaar, after the Darnassus errands at level 10.
- Red Crystal → Auberdine. This is cooldown-paired: hearth if ready, otherwise walk.
- Ironforge → Auberdine at the end of Loch Modan. **This is the return ticket for the whole Eastern Kingdoms detour**, which is why Auberdine is bound first thing.
- Gyromast/Blackwood → Auberdine.
- At the start of 20-21.

**Deliberate deaths** (`.deathskip`, softcore realms only):
- In Teldrassil, after the Oracle Glade, to respawn in Darnassus. Warriors are excluded; the author notes a Forever resurrection-sickness issue.
- At the Dolanaar graveyard.
- At the Thelsamar graveyard by jumping off the Loch Modan lodge.
- On hardcore realms the twin step walks instead.

**Flights and transport:**
- Rut'theran (Vesprystus) → Auberdine. The Flight to Auberdine quest chain ends there.
- **Forever's Auberdine ↔ Stormwind boat** (dock at Darkshore 30.7,41.0, arriving at the Stormwind harbour 8.4,29.2) replaces the Classic Menethil boat on the Alliance route. Shamans still take the Menethil boat.
- Deeprun Tram from Stormwind to Ironforge, with "Deeprun Rat Roundup" done in the tram.
- Ironforge FP, Thelsamar FP, fly Thelsamar → Ironforge.
- Night Elves have no Stormwind FP at 19. They pick it up at Dungar Longdrink, walk Elwynn to Redridge, and pick up the Lakeshire FP. They then fly Redridge ↔ Stormwind for the messenger and Goldshire errand.

### 2.5 Grind gates (`.xp`) on this route, and why they sit there

| Where | Gate | Why |
|---|---|---|
| Oracle Glade, Druid/Priest | 870 XP short of 10 | Arrive in Darnassus with the turn-ins (Teldrassil, Tumors, Tears of the Moon) pushing you to 10 for the trainer. |
| Back in Dolanaar before the last turn-ins | 850 XP short of 10 (non-Hunter); 1,475 short if Soft Saber Pelts is still completable | The same idea: the stacked turn-ins land the level. |
| Darkshore beach loop, Night Elf | 2,500 short of 13 (≈ 6,300/8,800 into 12) | Reach about 72% of 12 on the crawlers and bears before the first Auberdine turn-in wave. Then Bashal'Aran and the 13-14 quests are green rather than orange. |
| Bashal'Aran, optional | level 13 | Same reason, before the Red Crystal climb. |
| Loch Modan, optional | 2,360 short of 16 | Finish the Loch with 16 almost done. The Ironforge turn-in and training then happen at 16. |
| Blackwood camp | level 18 (non-Hunter); 18.75 (Hunter) | The south-to-north 18-19 quests (Gyromast, Mathystra) need 18. The camp is a hyperspawn, so this is the efficient grind spot. |
| Redridge murloc/gnoll area | 7,687 short of 20 | Bank the Redridge turn-ins first; they then carry you to 20. |
| Redridge end | level 20 | Final grind before 20-21. |

**Pattern:** a gate sits **just before a cluster of turn-ins** or **just before a harder quest hub**. The gate is placed at the most efficient mob spot near that point.

---

## 3. The Night Elf priest route from ~11 (after Dolanaar) to 20

Assume the player has done the Shadowglen and Dolanaar starter quests and is about level 11. Because RXP re-checks every step as it is reached, the 6-11 Teldrassil guide fast-forwards to the first thing still undone:
- accepts already held tick themselves;
- level gates of `<8` and "≥10" skip;
- turn-ins already done tick.

What remains is the part below. Each "phase" is one region visit. Within a phase the order is the guide's. Coordinates are zone percent on the named map.

### Phase A: Oracle Glade wrap-up (Teldrassil, level 10-11)

The priest shares the Druid branch: the harpies are done before Darnassus, not after.

| # | Stop | NPC / object, coords | Side tasks / reasoning |
|---|---|---|---|
| A1 | Turn in **The Lost Runner** (99046); accept **Not Dead Yet** (99047) | Sentinel Eralya Leafshadow, Teldrassil 37.6,36.8 | Forever-new chain. The path there uses a radius-50 "travel to the Oracle Glade" objective. |
| A2 | Accept **The Enchanted Glade** (937) | Sentinel Arynia Cloudsbreak 38.3,34.4 | |
| A3 | Fill the Amethyst Phial (Crown of the Earth 7383) | Oracle Glade moonwell 38.4,34.0 | The phial is put on the item bar. |
| A4 | Sticky: 6 Bloodfeather Belts from harpies (937) | Harpy nests 33.6,29.8 | Runs alongside A5-A6. Warning: the Matriarchs heal and cast Lightning Bolt. |
| A5 | Accept **Mist** (938) → escort the cub back | Mist 31.5,31.6 → Arynia 38.3,34.4 | **Timed** (10 min): the turn-in is the very next step. |
| A6 | Turn in Enchanted Glade; accept **Darkness in the Glade** (98392) | Arynia | |
| A7 | Kill three named harpies for amulets | Hatescreech 35.0,39.2; Windmistress Gaedress 33.6,35.6; Witchmother Arysa 34.8,28.6 | One `.complete` per objective, each with its own coordinate. |
| A8 | Accept **The Shimmering Frond** (931) | Strange Fronded Plant 34.6,28.8 | Item-start object on the way. |
| A9 | Turn in Darkness; accept **The Oracle Tree** (98398) → turn in; accept **Teldrassil** (940) | Arynia; Oracle Tree Bark 37.0,34.1 | |
| A10 | **XP gate**: 870 short of 10 | harpy area | See 2.5. Already passed at 11. |
| A11 | Deliberate death → Darnassus spirit healer (softcore); hardcore walks | — | Faster than the road. |

### Phase B: Darnassus errands (level 10-11)

| # | Stop | NPC, Darnassus coords | Side tasks / reasoning |
|---|---|---|---|
| B1 | Wand path (optional; only with no wand) | Vaean 58.6,14.7 → Lalina Summermoon 58.8,12.7 | See 2.1. Chain: train Enchanting → buy mats → Runed Copper Rod → practice wands to 10 → learn and craft the Lesser Magic Wand → equip. |
| B2 | AH: Wizard Oil, 20 Sagefish, wand upgrade (`#ah`, only with no wand) | Auctioneers ≈56,54 | |
| B3 | Turn in **Rellian Greenspyre** (922); accept **Tumors** (923) | Rellian Greenspyre 38.2,21.6 | |
| B4 | Turn in **Teldrassil** (940); accept **Grove of the Ancients** (952) | Arch Druid Fandral Staghelm 34.8,9.2 | Optional for Druid/Priest Night Elves. Skipped at level ≥ 10 by the `>`-quirk, so the turn-in happens in Phase D. Grove of the Ancients is carried to Onu in Darkshore (phase G). |
| B5 | Accept **Eyes of the Sentinels** (98067) | Sentinel Dalia Sunblade 40.6,89.6 | Forever-new. Its four "use the Lunar Pendant here" objectives are done later in the city (D5). |
| B6 | Accept **Tears of the Moon** (2518) | Priestess A'moora 36.7,85.9 (upstairs) | |
| B7 | **Stars of Elune** (5627): accept and turn in | Priestess Alathea 40.0,80.0 | Priest only. |
| B8 | Hearth → Dolanaar | — | The Dolanaar bind pays off here. |

### Phase C: Dolanaar loose ends (level 10-11)

Mostly guarded. A finished starter player sees only what is still open.

| # | Stop | Coords (Teldrassil) | Notes |
|---|---|---|---|
| C1 | Turn in **Not Dead Yet**; accept **The Great Tree Provides** (99050) | Byancie 55.3,56.8 | Forever-new. |
| C2 | Buy the Empty Vial | Narret Shadowgrove 55.3,57.1 | For 99050. |
| C3 | Turn in Twisted Hatred (932) and Ferocitas (2459) if done | Tallonkai Swiftroot 55.6,56.9 | |
| C4 | Zenn's Bidding / Seek Redemption leftovers (488/489) | Zenn Foulhoof 60.5,56.3; Fel Cones at 58.1,55.4 / 58.8,55.5 / 59.0,56.1 (a `#loop`) | Abandon 488 if unfinished. |
| C5 | Turn in Crown of the Earth (7383); accept the next part (935) | Corithras Moonrage 56.1,61.7 | |
| C6 | Kill Lasher Sproutlings on the way (sticky) for Dewy Lasher Fronds (99050) | lake 61.2,66.3 (path loop) | |
| C7 | Turn in The Shimmering Frond, The Glowing Fruit and the Moss-twined chain if held; The Sprouted Fronds | Denalan 60.9,68.5; planter 60.8,68.6 | |
| C8 | **XP gate** 850 short of 10 | — | Passed at 11. |
| C9 | Buy 1 Refreshing Spring Water (99050) | Keldamyr 55.6,59.8 | Shown only while on 99050. |
| C10 | Turn in The Great Tree Provides; accept **Easing Suffering** (99073) | Byancie | Uses the `.xp >10,1` guard. **As written it is skipped at level 10+**, so a level-11 player gets no Byancie step from this guide. Our version must not copy that. |
| C11 | Train | Laurna 55.6,56.7 | |
| C12 | Turn in **The Road to Darnassus** (487) | Moon Priestess Amara, patrols the road around 50.2,53.8 (map line) | |
| C13 | Abandon Soft Saber Pelts (optional) | — | |

### Phase D: West Teldrassil, Darnassus, out (level 11)

| # | Stop | Coords | Notes |
|---|---|---|---|
| D1 | 5 Mossy Tumors (923) | Timberlings, Teldrassil 41.7,41.8 | |
| D2 | Lady Sathrah for Silvery Spinnerets (2518) | Teldrassil 39.0,25.5, a looping search | Several spawn points. |
| D3 | Second pass at the Glade for anyone who skipped A: accept 937; harpies (sticky); Mist; Darkness; Oracle Tree | as A | All guarded; a priest who did A sees none of it. |
| D4 | Turn in **Easing Suffering** (99073) | Eralya 37.6,36.8 | Only if on it. |
| D5 | Death-skip or walk to Darnassus. Use the **Lunar Pendant** at four places for Eyes of the Sentinels | Darnassus: Gates 87.8,35.7 (obj 4); Inn 66.0,16.6 (obj 3); Cenarion Enclave entrance 34.0,15.4 (obj 1); Bank 41.4,43.3 (obj 2) | Forever-new. Each objective has its own coordinate. |
| D6 | Accept **Nessa Shadowsong** (6344) | Mydrannul, Darnassus 70.7,45.4 | Breadcrumb to Rut'theran. |
| D7 | Abandon The Moss-twined Heart | — | |
| D8 | Turn in **Teldrassil** (940), accept 952; turn in **Crown of the Earth** (935) | Fandral 34.8,9.2 | |
| D9 | Turn in Tumors (923) | Rellian 38.2,21.6 | |
| D10 | Turn in **Eyes of the Sentinels** (98067) | Dalia 40.6,89.6 | |
| D11 | Turn in Tears of the Moon; accept **Sathrah's Sacrifice** (2520); use it at the fountain; turn in | A'moora 36.7,85.9; fountain 39.7,85.8 | |
| D12 | AH (`#ah`): Strider Meat ×5, Darkshore Grouper ×6, Wizard Oil, Sagefish, wand | ≈56,54 | **Buy-for-later**: instant Darkshore turn-ins. |
| D13 | Train Staves | Ilyenia Moonfire 57.6,46.7 | |
| D14 | Portal to Rut'theran | Darnassus 28.5,39.9 | |
| D15 | Turn in Nessa Shadowsong; accept **The Bounty of Teldrassil** (6341) | Nessa, Teldrassil 56.3,92.4 | |
| D16 | Turn in 6341; accept **Flight to Auberdine** (6342); **fly to Darkshore** | Vesprystus 58.4,94.0 | |

### Phase E: Auberdine arrival and the beach (Darkshore, level 11-13)

| # | Stop | Coords (Darkshore) | Side tasks / reasoning |
|---|---|---|---|
| E1 | Accept **Washed Ashore** (3524) | Gwennyth Bly'Leggonde 36.6,45.6 | First NPC off the flight. |
| E2 | Turn in Flight to Auberdine | Laird 36.8,44.3 | |
| E3 | Accept **Buzzbox 827** (983) | Wizbang Cranktoggle, upstairs 37.0,44.1 | |
| E4 | **Bind hearth to Auberdine** | Innkeeper Shaussiy 37.0,44.1 | The whole 11-21 plan relies on this bind. |
| E5 | Accept Plagued Lands (2118), How Big a Threat? (984), WANTED: Jai'vhanel (98025, poster 37.2,44.2) | Tharnariun 38.8,43.4; Terenthis 39.4,43.5 | Cave Mushrooms and The Red Crystal are **held back** for Night Elves until ~12 (`xp <12` guard), so they appear later. |
| E6 | The Family and the Fishing Pole (1141): accept and turn in at once **if you bought 6 Grouper** (`#ah`); accept Fruit of the Sea (1138) | Gubber Blump 36.1,44.9 | AH payoff. |
| E7 | Sticky loop: 6 Crawler Legs (983) | beach loop from 36.1,44.8 south to ≈35.3,55 | Low-priority waypoints so the arrow stays free. |
| E8 | Sea Creature Bones (3524) | 36.4,50.9 | |
| E9 | Sticky: use Tharnariun's Hope on a Rabid Thistle Bear (2118) | bear loop ≈38.2,52.8 | Warning: a wasted trap means a trip back. |
| E10 | Find the corrupt furbolg camp (984) | 38.9,53.6 | |
| E11 | **XP gate** 2,500 short of 13, on the beach loop | | See 2.5. |
| E12 | Turn in Buzzbox 827 → accept Buzzbox 411 (1001) | Buzzbox on the beach 36.6,46.2 | |
| E13 | Turn in Washed Ashore → accept part 2 (4681); accept **For Love Eternal** (963) | Gwennyth; Cerellean Whiteclaw 35.7,43.7 | |
| E14 | Sea Turtle Remains (4681) | 31.8,46.3 (swim) | |
| E15 | Turn in Washed Ashore 2 | Gwennyth | |
| E16 | Accept **Cave Mushrooms** (947) and **The Red Crystal** (4811) | Barithras 37.3,43.6; Glynda 37.7,43.4 | Now ~12-13. |
| E17 | Turn in Plagued Lands → Cleansing of the Infected (2138); turn in How Big a Threat? → part 2 (985) + Thundris Windweaver (4761) | Tharnariun; Terenthis | |
| E18 | Easy Strider Living (2178): instant if you hold 5 Strider Meat **and** Cooking ≥ 10 | Alanndarian Nightsong 37.7,40.7 | |
| E19 | Turn in 4761; accept **The Cliffspring River** (4762), **Bashal'Aran** (954), **Tools of the Highborne** (958) | Thundris 37.4,40.1 | |

### Phase F: North coast, Bashal'Aran, Red Crystal (level 12-14)

| # | Stop | Coords | Notes |
|---|---|---|---|
| F1 | Sticky: 3 Thresher Eyes (1001), deep water | ≈35.4,35.8 → 40.2,28.8 loop | |
| F2 | Optional: Deep Ocean, Vast Sea lockboxes | wrecks 38.2,28.7 and 39.6,27.5 | For Night Elf priests these are taken later (after F11). The guide suggests binding an "interact" key to loot from outside the hull. |
| F3 | Accept **Beached Sea Creature** (4723) | 41.9,31.3 | |
| F4 | Turn in Buzzbox 411 → accept Buzzbox 323 (1002) | 42.0,28.6 | |
| F5 | Sticky: Moonstalker Fangs (1002), Strider Meat, Small Eggs from Moonkin (only while Cooking < 10, count = 10 − Cooking) | ≈44.2,33.7 | |
| F6 | Bashal'Aran 1 → 2: 8 Grell Earrings → 3: Ancient Moonstone Seal → accept part 4 (957) | Asterion 44.2,36.3; grells loop 44.5,36.6; satyrs loop 45.4,36.5 | The satyrs don't respawn dynamically. Abandon part 2 if it can't be finished. |
| F7 | Optional: grind to 13 | grell loop | |
| F8 | Locate the **Mysterious Red Crystal** (4811) | 47.3,48.7 | A climb. Warning: two leashed pairs of Raging Moonkins. |
| F9 | Hearth to Auberdine if ready, otherwise walk | — | Cooldown pair. |
| F10 | Turn in Red Crystal → accept **As Water Cascades** (4812); fill the tube at the moonwell | Glynda 37.7,43.4; moonwell 37.8,44.0 | |
| F11 | Back to the crystal: turn in 4812 → accept **The Fragments Within** (4813) → turn in at Glynda | crystal 47.3,48.7; Glynda | Night Elf non-Hunters do this whole chain early, combined with the Moonkin egg sticky. |
| F12 | Turn in Deep Ocean, Vast Sea if complete | Gorbold 38.1,41.2 | |

### Phase G: Ameth'Aran and the furbolgs (level 13-15)

| # | Stop | Coords | Notes |
|---|---|---|---|
| G1 | Optional loop: 8 Blackwood Pathfinders + 5 Windtalkers (985) | 39.9,54.7 | |
| G2 | Sticky: kill 20 Rabid Thistle Bears (2138) | hills | Warning: Rabies halves regeneration for 10 minutes. |
| G3 | Accept **Beached Sea Turtle** (4722) | 37.1,62.2 | |
| G4 | Accept **The Fall of Ameth'Aran** (953) | Sentinel Tysha Moonblade 40.3,59.7 | |
| G5 | Sticky: **Anaya Dawnrunner** (963). Four spawns: 42.0,58.9 / 43.2,59.7 / 43.1,62.4 / 42.5,60.7 | | Low-priority waypoint circuit plus unitscan. |
| G6 | Sticky: 7 Highborne Relics (958) | ≈42.7,57.4 loop | |
| G7 | Read the Fall tablet, destroy the seal at the Ancient Flame (957), read the Lay tablet | 42.7,63.1; 42.4,61.8; 43.3,58.7 | |
| G8 | Kill **Jai'vhanel** (98025) | 45.2,58.5 | Forever-new. |
| G9 | Turn in 953 | Tysha | |
| G10 | Blackwood loop (985) | 39.9,54.7 | |
| G11 | Auberdine round (returning to Auberdine). Turn-in clusters by NPC: | | |
| | • Gwennyth: Beached Turtle, Beached Creature | | |
| | • Gubber: Fruit of the Sea | | |
| | • Glynda: Jai'vhanel; Red Crystal and As Water Cascades for anyone who skipped F | | |
| | • Tharnariun: Cleansing → accept Tharnariun's Hope (2139) | | |
| | • Terenthis: How Big a Threat? 2 → accept A Lost Master (986) | | |
| | • Sentinel Elissa Starbreeze upstairs 39.0,43.6: accept The Tower of Althalaxx (965) | | |
| | • **Gorbold**: buy Shiny Bauble + 3 Nightcrawlers; accept Deep Ocean (982) | | |
| | • Campfire: cook eggs to Cooking 10+ | | |
| | • Thundris: turn in **Tools of the Highborne** → accept **Expanding Horizons** (97914, Forever, Night Elf only) | | |
| | • Cerellean: For Love Eternal | | |

### Phase H: Eastern Kingdoms detour, the included "15-16 Loch Modan" (level 14-16)

The 14-16 Darkshore guide splices in the whole Loch Modan guide here for Night Elves.

**Why now:**
- Darkshore's remaining quests are 16-19.
- Forever's boat makes Stormwind one hop away.
- Expanding Horizons gives a free turn-in there.
- Loch Modan's 10-16 quests (a hyperspawn trogg camp, rats, crocs) are efficient XP.
- Ironforge has both trainer and AH, and the Auberdine hearth brings you straight back.

| # | Stop | Coords | Notes |
|---|---|---|---|
| H1 | Take the boat to Stormwind | Darkshore dock 30.7,41.0 | Cook eggs while waiting. |
| H2 | **Fishin' Time** (95065): accept and turn in at once | Gilbert Gray, Stormwind harbour 8.4,29.2 | Uses the items bought at Gorbold. Forever-new. |
| H3 | Train | Brother Joshua 38.6,26.8 | |
| H4 | Turn in **Expanding Horizons** (97914); accept **Making Do** (97926) | Baros Alexston 49.2,30.3 | The turn-in uses the negative-ID form, so it is skipped if not held. Making Do is not followed further in the free guides. |
| H5 | Deeprun Tram: **Deeprun Rat Roundup** (6661) with Monty: accept, catch 5 rats with the flute, turn in | tram, Ironforge side | |
| H6 | Ironforge: accept **Find Bingles** (2039) | Gnoarn 69.2,50.6 | |
| H7 | Ironforge FP | Gryth Thurden 55.5,47.7 | |
| H8 | Dun Morogh: **Protecting the Herd** (314): kite Vagash to the mountaineer | Rudra Amberstill, Dun Morogh 63.1,49.9 | Elite. Let the NPC tank; you need half the damage. |
| H9 | Enter Loch Modan via the South Gate Pass. Accept **In Defense of the King's Lands** (224) and **The Trogg Threat** (267) | Cobbleflint 22.1,73.1; Rugelfuss (bunker top) 23.2,73.7 | |
| H10 | Troggs: 10 + 10 kills and 8 teeth | 26.7,56.9 (hyperspawn: stand still) | |
| H11 | Accept **Rat Catching** (416) and **Mountaineer Stormpike's Task** (1339) | Kadrell, patrols Thelsamar 36.8,46.2 | Abandon Stormpike's Order if held, to unlock the 550-XP task. |
| H12 | Thelsamar FP | Thorgrum Borrelson 33.9,51.0 | |
| H13 | Sticky: Bear Meat, Boar Intestines, Spider Ichor (418) | | Keep boar meat for Cooking. |
| H14 | Turn in 267 and 224 | bunker | |
| H15 | Turn in 1339 → accept **Filthy Paws** (307); 4 Miners' Gear in the Silver Stream Mine; 12 Tunnel Rat Ears | Stormpike 24.8,18.4; mine 35.9,22.5 | |
| H16 | Turn in 307 → Stormpike's Order (1338) | Stormpike | Carried to Furen Longbeard in Stormwind (Redridge leg). |
| H17 | Thelsamar: Blood Sausages (418) accept and turn in; accept **Ironband's Excavation** (436); turn in Rat Catching | Vidra 34.8,49.3; Jern 37.2,47.4 | |
| H18 | **Silver of the Waves** (86614): fishing toolbox on the lake floor (random spot) | ≈48,40 | Forever-new. |
| H19 | Turn in 436; accept **Excavation Progress Report** (298) | Magmar 64.9,66.7; Ironband 65.9,65.6 | |
| H20 | **A Hunter's Boast** (257): 6 buzzards in 15 min → turn in. **Crocolisk Hunting** (385) + **Twisting the Knife** (86758, Daggerfang). **Find Bingles** turn-in | Daryl 83.5,65.4; Marek 81.8,61.7; Bingles 63.6,47.9; croc island ≈54.7,38.2 | 86758 is Forever-new. |
| H21 | Optional **A Hunter's Challenge** (258); optional grind 2,360 short of 16 | | |
| H22 | Die to the mobs below the lodge → Thelsamar spirit healer | | Free travel. |
| H23 | Turn in 298 → accept **Report to Ironforge** (301); turn in Silver of the Waves | Jern 37.2,47.4; Khara Deepwater 39.6,39.6 | |
| H24 | Fly to Ironforge; turn in 301 | Prospector Stormpike, Ironforge 74.6,11.7 | |
| H25 | Train | High Priest Rohan 23.2,7.2 | |
| H26 | AH (`#ah`): oil, fish, wand | Ironforge AH 25.8,75.5 | |
| H27 | **Hearth to Auberdine** | | |

### Phase I: Darkshore north, Cliffspring (level 15-16)

This picks up after the include.

| # | Stop | Coords | Notes |
|---|---|---|---|
| I1 | Accept Fruit of the Sea (1138) if not yet | Gubber 36.1,44.9 | |
| I2 | Deep Ocean lockboxes | 38.2,28.7; 39.6,27.5 | |
| I3 | Beached Sea Creature (4723) | 41.9,31.3 | |
| I4 | Turn in As Water Cascades → The Fragments Within | crystal 47.3,48.7 | Only if not done in F. |
| I5 | Turn in Bashal'Aran 4 (957) | Asterion 44.2,36.3 | |
| I6 | Accept **Beached Sea Turtle** (4725) | 44.2,20.6 | |
| I7 | Reef Crawlers for Fine Crab Chunks (1138) | 45-50, 20-24 | Optional now. Some are level 17. |
| I8 | Cliffspring River sample (4762) | 50.8,25.5 | |
| I9 | Turn in Buzzbox 323 → accept Buzzbox 525 (1003) | 51.3,24.6 | |
| I10 | Foreststriders for Strider Meat (2178) | loop ≈53.6,26.1 | |
| I11 | Cave Mushrooms: 5 Scaber Stalks and a Death Cap (947) | Cliffspring cave, entrance 55.1,33.6; Death Cap ≈55.4,36.3 | Stay on the upper level. The guide mentions an optional logout trick to get out of the cave fast. |
| I12 | Auberdine round. Turn-in clusters by NPC: | | |
| | • Thundris: Cliffspring → accept **The Blackwood Corrupted** (4763) | | |
| | • Alanndarian: Easy Strider Living | | |
| | • Gorbold: Deep Ocean | | |
| | • Tharnariun: Cleansing → Tharnariun's Hope | | |
| | • Glynda: The Fragments Within | | |
| | • Moonwell: fill the Cleansing Bowl | | |
| | • Barithras: Cave Mushrooms → accept **Onu** (948) | | |
| | • Poster: **WANTED: Murkdeep!** (4740) | | |
| | • Gubber: Fruit of the Sea | | |
| | • Gwennyth: Beached Creature and Turtle | | |

### Phase J: "16-19 Darkshore", south and north (level 16-19)

| # | Stop | Coords | Notes |
|---|---|---|---|
| J1 | Anaya again, if still needed (solo or group variants) | 42-43, 59-62 | |
| J2 | 20 Rabid Thistle Bears if unfinished | southern loop | |
| J3 | Turn in **Grove of the Ancients** (952, Night Elf) and **Onu** (948); accept **The Master's Glaive** (944) | Onu 43.6,76.3 | |
| J4 | Sticky: Fine Moonstalker Pelts (986); Grizzled Scalps (1003) | Grizzled bears ≈40-43, 80-86 | |
| J5 | Master's Glaive: discover it; place the Phial of Scrying; turn in at the bowl; accept **The Twilight Camp** (949) → turn in at the tome; accept **Return to Onu** (950) and **It's All Fun and Games Until…** (98042, Forever) | 38.5,86.1 | The Phial is placed with a ground-target macro. |
| J6 | Sticky: Peerless Eye (98042) and Book: The Powers Below from the Twilight cultists | 39.2,85.3 loop | |
| J7 | Optional escort **Therylune's Escape** (945) | 38.7,87.3 | Ends in Ashenvale. |
| J8 | Delete the Phial. Turn in Buzzbox 525 | 41.4,80.6 | |
| J9 | Turn in Return to Onu; accept **Mathystra Relics** (951) | Onu (11.5 s role-play timer) | |
| J10 | Use the Book to start **The Powers Below** (968) | | |
| J11 | Beached Turtle (4731) and Creature (4730, 4728) pick-ups down the coast | 31.7,83.7; 32.6,80.7; 36.0,70.8 | |
| J12 | **Murkdeep**: clear the camp, start the waves at the bonfire | 36.6,76.5 | Three waves, Murkdeep last. |
| J13 | Back to Auberdine. Turn-in clusters by NPC: | | |
| | • For Love Eternal (or abandon it) | | |
| | • Gwennyth: 4728, 4730, 4731 | | |
| | • Gubber: Fruit of the Sea | | |
| | • **Restock food and water** at Laird / Allyndia | | |
| | • Glynda: Murkdeep | | |
| | • Thundris: Fun and Games | | |
| | • Tharnariun: Cleansing → Tharnariun's Hope | | |
| J14 | Blackwood stores: grain 50.7,34.9 → nut 51.8,33.5 → fruit 52.9,33.4. Each spawns two furbolgs. Then the bowl at the bonfire 52.4,33.6 summons **Xabraxxis** | | Chained stickies with `#requires`. 17 s role-play timer. |
| J15 | Den Mother (2139) | 51.5,38.3 | |
| J16 | **XP gate: level 18** at the camp | 52.6,33.6 | |
| J17 | Moonstalker Fangs loop; turn in Buzzbox 323 → 525 if still pending | 51.3,24.6 | |
| J18 | Tower of Althalaxx 1 → 2: 4 Worn Parchments → 3 | Balthule Shadowstrike 55.0,24.9; Dark Strand Fanatics ≈56,26 | |
| J19 | Mathystra Relics ×6 | 57.1,22.0 → 60.3,21.8 | |
| J20 | **Gyromast's Retrieval** (2098). Key pieces: middle from Greymist murlocs (≈54.9,12.2); bottom from crabs (≈55.6,17.0 → 51.3,22.0); top from **Giant Foreststriders** (61.2-61.5, 9-15) | Gelkak Gyromast 56.7,13.5 | Also sticky: Moonstalker Sires and Matriarchs in the far north (61.4,9.4 → 62.4,7.7) for the pelts. |
| J21 | **Gyromast's Revenge** (2078): start the Threshwackonator escort, then kill it at Gelkak | robot 55.8,18.3 | Hard. The reward is the Draught of Water Breathing. Abandon if it fails. |
| J22 | Accept Beached Turtle (4727) | 53.1,18.1 | |
| J23 | Hearth to Auberdine (if ready). Turn-in clusters by NPC: | | |
| | • Gwennyth: 4727 | | |
| | • Gubber: Fruit of the Sea | | |
| | • Thundris: **The Blackwood Corrupted**; delete the samples | | |
| | • Tharnariun's Hope | | |
| | • Terenthis: A Lost Master → part 2 (993) | | |
| | • Equip the Enchanted Moonstalker Cloak, but keep the old cloak | | |
| J24 | Buy Flint and Tinder + Simple Wood (Dalmond) and Mild Spices (Gorbold); cook on the dock; take the **boat to Stormwind** | dock 30.7,41.0 | |

### Phase K: "19-20 Redridge" (level 19-20)

| # | Stop | Coords | Notes |
|---|---|---|---|
| K1 | Stormwind errands: | | |
| | • Accept **Philmor's Favor** (97220, Forever) | Manifest Clerk Philmor 14.0,5.6 | |
| | • Burning Wand | Ardwyn Cailen 42.9,65.1 | |
| | • Train | Brother Joshua | |
| | • Turn in **Stormpike's Order** (1338) | Furen Longbeard 58.1,16.5 | |
| | • Accept Underground Assault (2040) | Shoni 55.5,12.5 | |
| | • Bronze Tube | Billibub 55.2,7.0 | |
| | • Accept Oh Brother… (167) and Collecting Memories (168) | Wilder Thistlenettle 65.5,21.1 | |
| | • AH meats | Jaxon 53.6,59.8 | |
| | • **Gatehouse Goods** (97222): use the shipment upstairs at the gate | Elaine Trias 60.5,63.2 | |
| | • Stormwind FP | Dungar Longdrink 66.7,61.8 | |
| K2 | Walk Elwynn → Redridge. Accept **Encroaching Gnolls** (244) | Guard Parker, Redridge 16.6,70.3 | |
| K3 | Lakeshire pick-ups: | | |
| | • Turn in 244; accept Assessing the Threat (246) and **Show of Force** (98407, Forever) | Deputy Feldon 31.2,59.6 | |
| | • Redridge FP | Ariena Stormfeather 31.1,59.0 | |
| | • Blackrock Menace (20) and **Blackrock Blockade** (98387, Forever) | Marshal Marris 33.5,49.0 | |
| | • The Lost Tools (125) | Foreman Oslow 32.1,48.6 | |
| | • The Price of Shoes (118) | Verner Osgood 30.9,47.3 | |
| | • **WANTED: Incinerator Gar'im** (95999, Forever) | poster 29.3,46.2 | |
| | • Messenger to Stormwind (120) | Magistrate Solomon 29.9,44.6 | |
| | • Selling Fish (127) | Dockmaster Baren 27.7,47.4 | |
| | • A Free Lunch (129) | Darcy, walks the inn 26.7,44.5 | |
| | • Redridge Goulash (92) | Chef Breanna 22.6,43.9 | |
| | • Hilary's Necklace (3741) | Shawn 29.6,53.4 | |
| K4 | Hilary's Necklace in the lake (several spawns); Oslow's Toolbox in the Sunken Chest | lake ≈28,56; chest 41.6,54.6 | |
| K5 | Sticky: Great Goretusk Snouts | | |
| K6 | A Free Lunch → Visit the Herbalist (130) | Parker | |
| K7 | Gnolls: Mongrels, Poachers, Spiked Collars | ≈16,62 | |
| K8 | Tarantulas | 20.1,72.6 | |
| K9 | Murlocs for Selling Fish and Murloc Poachers | 49.6,69.4 | Hyperspawn. |
| K10 | Condors | 62.1,76.4 | |
| K11 | Gar'im in his cave; Blackrock axes, supplies and weapons | Gar'im ≈78.8,85.5; orc camp ≈74.7,78.4 | |
| K12 | **XP gate** 7,687 short of 20 | murlocs | |
| K13 | Lakeshire turn-in sweep. Then Martie Jainrose 21.9,46.3 and Darcy (Delivering Daffodils, 131); Hilary 29.5,53.4 | | |
| K14 | **XP gate: level 20** | murlocs | |
| K15 | Fly to Stormwind: | | |
| | • Turn in the SW pick-ups if complete | | |
| | • Accept **The Corruption Abroad** (3765) | Argos Nightwhisper 21.4,55.8 | |
| | • Train | Brother Joshua | |
| | • Messenger to Stormwind part 2 | General Marcus Jonathan 63.9,75.4 | |
| | • Price of Shoes → Return to Verner | Smith Argus, Goldshire (Elwynn 41.7,65.6) | |
| | • A Watchful Eye | Theocritus, Tower of Azora (Elwynn 65.2,69.7) | |
| | • Fly back to Redridge | | |
| K16 | Final Redridge turn-ins: | | |
| | • Return to Verner; accept A Baying of Gnolls (124) and Underbelly Scales (122) | Verner | |
| | • Messenger 121 | Solomon | |
| | • Hilary, Baren, Goulash, Daffodils | | |
| | • Whelps (≈37.6,73.1) and Brutes/Mystics with Iron Pikes and Rivets (≈20.9,36.5) | | |
| | • Turn in at Verner and Oslow | | |
| | • Cook boar meat towards Cooking 50 | | |

### Phase L: "20-21 Darkshore/Ashenvale" (level 20-21)

- **Hearth to Auberdine** (the hearth is still bound there).
- Abandon the three Stormwind dungeon quests.
- Turn in **The Corruption Abroad** at Gershala Nightwhisper 38.3,43.0.
- Re-accept Murkdeep, Onu and Absent Minded Prospector if missed.
- Then the south: the Remtravel escort; Kerlonian Evershade, "The Sleeper Has Awakened", 20-minute timer, with the Horn of Awakening; Volcor ("A Lost Master" part 2).
- From there into Ashenvale. The free guides stop at 21.

### Priest-only content on this route

- Shadowglen water.
- In Favor of Elune / Garments of the Moon (heal and fortify Sentinel Shaya).
- Milk.
- Trainer visits at 6, 8, 10, ~14, ~16, ~19 and ~20.
- Stars of Elune.
- The Enchanting wand path.
- Staves.
- Wizard Oil and Sagefish AH buys (three chances: Darnassus, Ironforge, and the Darnassus end-of-Teldrassil list).
- The Burning Wand.
- Shared with Druids, the early Oracle Glade order before Darnassus.

---

## 4. Gap table: RXP behaviour vs our LevelGuide

**Our model.**
- Per-zone routes in `Routes.lua`. Step kinds:
  - A accept, D do, T turn-in, G go, `On(zone)` other-map steps;
  - Home, FP, Zone, Item, Train, XP gates;
  - modifiers Obj, Path, Outlevel, New.
- The engine (`LevelGuide.lua`):
  - picks the race's chain (`FindRoute`);
  - reorders a 10-step window by distance (`ROUTE_WINDOW`);
  - shows the current step plus 3 next (`MAX_NEXT`);
  - points the arrow at the current step (or a picked focus step), the corpse when dead, and the path points of `Path` in order;
  - honours accept and turn-in grace timers and saved stable keys.
- Data use of the utility kinds is thin. Count of uses in `Routes.lua`:

| Kind | Uses |
|---|---|
| Home | 3 |
| FP | 3 |
| Zone | 1 |
| Item | 1 |
| Train | 1 |
| XP | 1 |
| Obj | 5 |
| Path | 2 |

**Not for us.** Anything that acts in the game is out under our read-only rule:
- auto accept or turn-in;
- gossip picking, bind or resurrection confirm;
- `TakeTaxiNode`;
- secure item buttons;
- auto-buy;
- target macros.

These are not listed as gaps.

| RXP behaviour | Ours | Status | Concrete change needed |
|---|---|---|---|
| Accept / turn-in / per-objective work | A/T/D by title + IDs; `Obj()` | **have** | — |
| Turn-in that skips when the quest is missing | `RouteStepDone` treats a missing quest as done | **have** (ours is safer than RXP's positive-ID behaviour) | — |
| Item-gated collect before the quest exists ("7 spider legs for 4161") | `Item(id,n)` = have-n, remembered | **partial** | Add a `forQuest` field: done when count ≥ n **or** that quest is complete/turned in. Add a `minusSkill` field (Cooking) so the need shrinks with skill. |
| Path points with arrival radius | `Path(points)`; arrival at 12 yd advances | **have** (fixed radius) | Optional per-point radius. |
| Loop circuit (`#loop`) | — | **missing** | `Loop(points, step)`: when the last point is reached, wrap to the first until the step is done. Add a "nearest of set" mode for spawn points (Anaya, Lady Sathrah, Murkdeep, toolbox). |
| Pin-only / low-priority coordinates | — | **missing** | A per-coordinate priority: `main` (arrow), `low` (arrow only when idle), `pin` (MapPins only). |
| Sticky "on the way" tasks with an end point (`#completewith`) | Next 3 rows; distance reorder | **missing** | A new step modifier `While(untilKey, step)`. Shown in an "On the way" block under the current step from when it's reached until the route passes `untilKey` or it completes. Never takes the arrow, except as low priority. Data: spider legs, crawler legs, bears, fangs, eggs, cultists, snouts. |
| Step-to-step requirement (`#requires`) | Prereqs.lua for quests | **partial** | A `after=key` field: the step waits until the step with that stable key is done or skipped. Needed for the Blackwood grain → nut → fruit → Xabraxxis chain. |
| Grind-to-X gates | `XP(level, frac)` | **have** (one form) | Accept "N xp short of level L" and "N xp into level L". Convert to a fraction at runtime with `UnitXPMax`. Show (cur/target). Add the gates from 2.5 to the data. |
| Skip-if-level guards | `Outlevel(n)`, `OUTLEVELED=4` | **partial** | `minLvl` / `maxLvl` fields on any step: hide below, auto-skip at or above. Use a real "above" comparison, not RXP's `>` quirk. |
| Class / race filters | Route by race only; class quests left out | **missing** | `cls=` and `race=` fields (lists, with negation). Filter in `RouteStepDone` / `BuildSteps`. Then add priest data: Garments of the Moon, Stars of Elune, trainer stops. |
| Hearth bind | `Home()` | **have** | Add the Auberdine and Dolanaar binds as data, already present. Add Lakeshire for Druids if class filters come. |
| Use hearthstone | — | **missing** | `Hearth(place)`: done on the player's `UNIT_SPELLCAST_SUCCEEDED` with spell 8690 (Safe-wrapped), or on arrival in `place`. When the hearthstone cooldown (`C_Container.GetItemCooldown(6948)`) is above ~0, show the paired "walk to X" text instead. |
| Fly | G steps only | **missing** | `Fly(dest)`: done when `UnitOnTaxi("player")` turns true while the step is current, or on `PLAYER_CONTROL_LOST` then arrival in the destination zone. Never click. |
| Boat / tram / portal legs | G or Zone steps | **partial** | `Travel(kind, toZone, x,y)`: done on arrival in `toZone` (`ZONE_CHANGED_NEW_AREA`). Data: Auberdine → Stormwind boat, Deeprun Tram, Darnassus portal. |
| FP discovery | `FP()` via taxi map / new-FP message | **have** | Data: Ironforge, Thelsamar, Stormwind, Lakeshire for the NE route. |
| Vendor visit / buy list | Chores line from SupplyWatch/BagCheck | **missing** in route | `Buy(npc, x,y, items={ {id,n,why} }, guard)`: done on `MERCHANT_CLOSED` with that NPC's ID (from `UnitGUID("npc")` at `MERCHANT_SHOW`), or when all items are present. Guards: `ifMoney ≥`, `ifNoUpgrade` (compare worn DPS via `C_Item.GetItemStats` / ItemAdvisor), `ifMissing`. AH variants are marked `ah=true` and hidden by a "no AH" setting. |
| Trainer visit | TrainerNotes chore | **partial** | `Trainer(npc,x,y,lvl)`: done on `TRAINER_CLOSED` from that NPC, or when TrainerNotes says nothing is affordable. Class-filtered. |
| Guards (`isOnQuest`, `isQuestComplete`, `isQuestTurnedIn`, `itemcount`, `zoneskip`, `bindlocation`, `skill`) | Implicit for quest steps only | **partial** | Generic `when={…}` on any step: `onQuest`, `questReady`, `turnedIn`, `notTurnedIn`, `hasItem`, `lacksItem`, `skillAtLeast`, `skillBelow`, `notInZone`, `hearthNot`. Evaluate live while the step is visible. A false guard hides the step; it doesn't "complete" it. |
| Manual tick objectives (`+text`) | Shift-right-click skip | **partial** | `Note(text, x,y)` with a tick box in our window, for "equip the bow", "bind interact key", "cook to 10". |
| Abandon / delete reminders | — | **missing** | `Abandon(q, why)`: done when the quest is no longer in the log. `Delete(item)`: done when the bag count is 0. Both are text plus completion, never acting. |
| Deliberate deaths / spirit-healer arrow | Corpse arrow when ghost | **partial** | A `Shortcut` text step ("dying here respawns you in X") shown only on non-hardcore realms (`C_GameRules.IsHardcoreActive`). Optional static spirit-healer table for the ghost arrow (RXP has world positions per continent in `DB/forever/SpiritHealerDB.lua`; we would need our own data). |
| Timed quests / role-play waits | `PutTimedFirst` | **have** (timed) / **missing** (RP timers) | Optional `wait=seconds` note on a step. |
| Dungeon variant (Hall of Thanes, Ruins of Lordaeron, Deadmines) | PLAN notes + Dungeons helper | **partial** | A per-character "dungeons on/off" choice that swaps in dungeon legs as separate routes. |
| Cross-zone legs (Night Elf Loch Modan detour, Redridge, Stormwind errands) | Chain by zone; `On(zone)` single steps | **missing** | Allow a chain entry to be a **leg** route with its own min/max that is entered by a Travel step. For example, NightElf = {TELDRASSIL, DARKSHORE_A (11-15), EK_DETOUR (Stormwind → IF → Loch Modan → IF, 14-16), DARKSHORE_B (16-19), REDRIDGE_NE (19-20), DARKSHORE_C/ASHENVALE}. `FindRoute` must then follow the leg order rather than "zone you stand in first" while a leg is unfinished. |
| Human 1-20 and Skyborne routes | Human chain starts at Wetlands 20; no Skyborne chain | **missing** | Add ELWYNN, WESTFALL and REDRIDGE routes. Add `Skyborne = {ZEPHRAS_ISLE, …}` (uiMapID 2521, zone-percent data available from the RXP Skyborne guide as a fact source). |
| World coordinates / sub-maps | Percent per map + `On()` | **partial** | Store `map=` per step everywhere. World-coordinate support is optional. The per-map linear transform described in the method note at the top shows conversion is exact. |
| Dangerous mobs / elites on the way | DeathNotes, RareWatch | **partial** | A `Warn(text)` field on steps (Raging Moonkin pairs, Bloodfeather Matriarchs, Threshwackonator, Rabies). The RXP `dangerousMobs.lua` for Forever is a Classic copy (it even lists Outland zones), so write our own. |
| Item to keep or bring later | — | **missing** | A `Keep(item, forQuest)` note that ItemAdvisor/BagCheck can read, so "don't sell" shows on the tooltip. |

### Route-data corrections found while comparing (`Routes.lua` vs RXP coordinates)

| Step in our data | Ours | RXP | Action |
|---|---|---|---|
| Teldrassil "Tumors" (Mossy Tumors) | 41.0,31.0 | **41.7,41.8** | Check in game; RXP is likely right. |
| Teldrassil "Seek Redemption!" Fel Cones | 65.8,52.2 | **58.1-59.0, 55.4-56.1**, by Zenn near Dolanaar (three fixed spots) | Fix. Make it a `Path` of three points. |
| Teldrassil "Recipe of the Kaldorei" legs | 61.0,58.0 | spiders around the Pools, ≈44.7,70.5, while doing Arlithrien | Consider moving. |
| Teldrassil "Darkness in the Glade" | one point 35.0,38.5 | three bosses 35.0,39.2 / 33.6,35.6 / 34.8,28.6 | Make three `Obj` steps, or a `Path`. |
| Teldrassil "Eyes of the Sentinels" | left out (giver unknown) | Sentinel Dalia Sunblade, Darnassus 40.6,89.6; four pendant spots (see D5) | **Add.** |
| Darkshore "Buzzbox 525" Grizzled Scalps | 41.0,70.0 (approx) | **≈40-43, 80-86** | Fix. |
| Darkshore "WANTED: Jai'vhanel" | 43.5,56.5 (approx) | **45.2,58.5** | Fix. |
| Darkshore "Gyromast's Revenge" robot | 53.6,18.0 (approx) | **55.8,18.3** | Fix. |
| Darkshore "Gyromast's Retrieval" pieces | one point 55.0,17.0 | murlocs ≈54.9,12.2; crabs ≈55.6,17.0; Giant Foreststriders ≈61.3,9-15 | Split into three `Obj` steps. |
| Darkshore "A Lost Master" pelts | 40.5,80.0 | south sires near the Glaive **and** the north Matriarchs ≈61.4,9.4 | Note both. |
| Darkshore "The Blackwood Corrupted" moonwell | 37.8,43.8 | 37.8,44.1 | Fine. |

Most other Darkshore and Teldrassil coordinates in our data match RXP within 0.5.

---

## 5. Rules for LevelGuide to reproduce RXP's behaviour (pseudologic, our design)

These rules fit our adaptive model. We keep distance reordering and the Prereqs.lua logic, and add RXP's expressiveness.

### 5.1 Step record

```
step = {
  key           -- stable id (already have: New/since)
  kind          -- accept | do | turnin | go | home | fp | zone | item | train | xp
                --  + new: hearth | fly | travel | buy | trainer | note | abandon | delete
  quest/obj     -- as now
  map, x, y     -- as now; map optional
  pts, mode     -- points; mode = path | loop | nearest
  prio          -- main | low | pin            (default main)
  lvl, minLvl, maxLvl, outlevel
  cls, race     -- lists, "!" = not
  when          -- guard table (see 5.4)
  whileUntil    -- key of the step that ends this "on the way" task
  after         -- key of a step that must be done first
  ah            -- true = only when the player uses the AH
  forQuest, minusSkill  -- for item steps
  note, warn, wait
}
```

### 5.2 Which steps exist for this character

1. Drop a step if `cls` or `race` doesn't match. Same rule as RXP: alternatives separated by `/`, all tokens in one alternative must hold, `!` negates.
2. Drop a step if `ah` and the player chose "no auction house".
3. Drop a "shortcut death" step on a hardcore realm.
4. Hide the step (keep it, don't skip it) if the level is below `minLvl`.
5. Count it as done:
   - if the level is at least `maxLvl`;
   - or at least `lvl + (outlevel or 4)`.

### 5.3 Current step and "on the way" block

```
frontier = first route step (in route order) that is not done and not skipped
current  = the best of the next ROUTE_WINDOW not-done steps (existing distance/XP scoring),
           but never a step whose `after` step is not done,
           and never a `whileUntil` step (those are never "current")
onTheWay = every `whileUntil` step S with:
             S's position <= frontier position   (we've reached it)
             and the step keyed S.whileUntil is not yet done
             and S itself is not done
             and S's guards pass
           shown as a compact block under the current step, in route order
```

**When an `onTheWay` task leaves the block.** It leaves when it completes, or when its `whileUntil` step is done. In the second case it leaves without being marked done. A later ordinary step for the same quest then picks up the rest; that is RXP's "repeat it later" pattern.

### 5.4 Guards: hide, don't complete

`when` is evaluated each refresh while the step is in the window. All of its conditions must hold. If one fails, the step is **not shown and not counted as done**: if the guard turns true later, the step reappears. RXP instead marks the step done and never looks back. Hiding is better for our out-of-order model.

| Guard | True when |
|---|---|
| `onQuest=id` | the quest is in the log |
| `questReady=id` | in the log and complete (`C_QuestLog.IsComplete`) |
| `turnedIn=id` | `C_QuestLog.IsQuestFlaggedCompleted` |
| `notTurnedIn=id` | not flagged completed |
| `hasItem={id,n}` | `C_Item.GetItemCount(id) >= n` |
| `lacksItem={id,n}` | `C_Item.GetItemCount(id) < n` |
| `skillAtLeast={name,n}` / `skillBelow={name,n}` | from the profession lines (ProfessionCap already reads them) |
| `money=g` | `GetMoney() >= g` copper |
| `wornBelow={slot,stat,v}` | the worn item's stat is below v (ItemAdvisor already scores items) |
| `notInZone=name` | not standing in that zone or sub-zone |
| `hearthNot=place` | `GetBindLocation()` differs |
| `hearthReady` / `hearthNotReady` | the hearthstone cooldown is ≈0 / is above 0 |

### 5.5 When each kind is done (passive; never act)

| Kind | Done when |
|---|---|
| `accept` | Quest in the log or turned in (as now, with the 2 s grace). |
| `turnin` | Turned in (as now, with the 5 s grace). A missing quest counts as done (as now). |
| `do` | Quest ready, or the listed objectives finished (as now). |
| `item` | `count >= n`; or `forQuest` is complete or turned in. The need is `n − skill(minusSkill)`, floored at 0. If the need is 0, the step is done. |
| `xp` | One of: level > L; level == L and fraction ≥ frac; or the forms "N into L" or "N short of L" converted with `UnitXPMax`. |
| `home` | Bound there (as now). |
| `fp` | Node known (as now). |
| `hearth` | `UNIT_SPELLCAST_SUCCEEDED` for the player with spell 8690 while the step is current or on the way, **or** arrival in the destination zone. |
| `fly` | `UnitOnTaxi("player")` became true while the step is current, or arrival in the destination. |
| `travel` | In the destination zone. |
| `buy` | `MERCHANT_CLOSED` after `MERCHANT_SHOW` with the step's NPC ID, **or** every listed item present. |
| `trainer` | `TRAINER_CLOSED` from that NPC, or (TrainerNotes) nothing new is affordable or learnable. |
| `train` | `IsPlayerSpell` (as now). |
| `note` | The player ticks it (saved per key). |
| `abandon` | The quest is not in the log. |
| `delete` | The item count is 0. |
| `go` | Arrived (as now). For `pts`: the last point reached in `path` mode; never in `loop` mode (a loop ends with its owner quest's objective). |

### 5.6 Arrow choice

1. If dead (ghost): point at the corpse (have). On non-hardcore realms, if the current step is a "shortcut death", optionally point at the nearest spirit healer instead. That needs our own table.
2. If a focus step is set: point at it (have).
3. Point at the current step's active point:
   - `path`: the next unreached point.
   - `loop`: the next point, wrapping to the first.
   - `nearest`: the closest point of the set that hasn't been visited since the last wrap.
4. If the current step has no coordinates, use the first `onTheWay` step whose prio is `main` or `low`. Steps with prio `pin` never take the arrow.
5. Points are reached within their own radius (default 12 yd). The reached state is saved per step key (have, for paths).

### 5.7 Hearth and flight decisions shown as text

**When the route's next step is in another zone and far away:**
- If the hearth is bound to that zone's hub and its cooldown is 0: show "Hearth to X".
- Else, if both flight-path nodes are known: show "Fly to X". FlightKnown already exists.
- Else: show the walking or boat route from the Travel step.

**After a Home step is done**, the route may rely on the hearth later. RXP sets the Auberdine bind first, for the Loch Modan return. If the player re-binds elsewhere, show a one-line warning: "Your hearth isn't Auberdine; the route expects it".

### 5.8 XP-gate placement rule (for authoring)

Put an XP gate immediately before a cluster of turn-ins, or before a hub whose quests would otherwise be orange. Set it so that the cluster's total XP (Questie data / QuestIDs) lands the next level.

The existing "+N% ready to turn in" banked-XP readout can compute that gap live. Then "grind to frac" can be suggested automatically even without a gate in the data.

---

## 6. Forever-specific content in RXP

### 6.1 New zone: Zephras Isle (Skyborne)

- **Yes, covered.** `Guides/forever/RestedXP-Skyborne.lua` has `1-9 Zephras Isle` and `9-13 Zephras Isle` for both factions. They are the `#defaultfor Skyborne` start (781 steps).
- Coordinates are zone percent on **uiMapID 2521**, the only map RXP knows by that name (`DB/forever/db.lua` mapId).
- Hubs:
  - **Thendal Village** (area 16635), hearth;
  - **Shen'dar Village** (area 16624), hearth and "Welcome to Shen'dar Village" (93461 Alliance / 92514 Horde);
  - **Valanaar**, hearth;
  - Thendal Grove (16622) and Thendal Cave (16673).
- Quests start at 92460 "Coming of Age" and include ley-line objectives.
- **Exits:**
  - Alliance: boat to Darkshore. Then `13-15 Westfall` for non-Hunters, `14-16 Darkshore` for Hunters.
  - Horde: Silverpine or Barrens.
- Skyborne also gets race forks in the 11-20 guide, e.g. "Journey to Sentinel Hill" 98021 and the Druid "Great Windborne Cat Spirit" 98341/98404/98738.
- A dungeon variant of the Skyborne guide exists too.

### 6.2 New and changed quests on the Alliance 1-20 path

**Forever-only IDs** seen in the Night Elf and 11-20 files:
- **Teldrassil:**
  - The Adventurer 96630, The Great Outdoors 96606, Camping 101: Cooking 96634, Soft Saber Pelts 87288;
  - Nature's Call 97977, The Goddess Provides 97979, Fang of Githyiss 97236;
  - The Lost Runner 99046, Not Dead Yet 99047, The Great Tree Provides 99050, Easing Suffering 99073;
  - Darkness in the Glade 98392, The Oracle Tree 98398, Eyes of the Sentinels 98067.
- **Darkshore:** WANTED: Jai'vhanel 98025, It's All Fun and Games Until… 98042, Expanding Horizons 97914 (Night Elf).
- **Stormwind:** Making Do 97926, Fishin' Time 95065, Philmor's Favor 97220, Gatehouse Goods 97222.
- **Loch Modan:** Silver of the Waves 86614, Twisting the Knife 86758.
- **Redridge:** WANTED: Incinerator Gar'im 95999, Blackrock Blockade 98387, Show of Force 98407.
- **Druid:** The Great Cat Spirit chain 98393-98397, 98731.
- **Other files:** Westfall/Human quests such as Testing the Wells 92742, Murloc Gills 92744, Harvesting the Harvesters 92909.

**Forever mechanics the guides rely on:**
- the **Boosted Rest** campfire buff (The Great Outdoors);
- **Herb Baked Eggs** giving +5% kill XP;
- the **Auberdine–Stormwind boat**;
- Forever items: Mote of Magic 247786, Lunar Pendant 279378, Gatehouse Shipment 277198;
- the resurrection-sickness spell 418460 on Forever (`.deathskip` note);
- the new dungeons **Hall of Thanes**, **Ruins of Lordaeron** and **Krol'dok Stronghold** (dungeon group).

### 6.3 `DB/forever` data

| File | Content | Forever-specific? |
|---|---|---|
| `flightData.lua` | `FPDB[faction][node] = {name, [dest]=seconds}` | **No**: Classic node list only, no Zephras nodes and no new Forever nodes. Used for flight ETAs and to map "Get the X flight path" to a node. |
| `db.lua` | `mapId` (Classic uiMapIDs 1411-1459, plus **"Zephras Isle" = 2521**); `FPbyZone`; `taxiPos`; profession and mount IDs; emergency items/spells; `dungeonStats` with weights (loot, quest XP, travel) per dungeon including **HOT** (Hall of Thanes, 16919), **ROL** (Ruins of Lordaeron, 153), **KS** (Krol'dok, 17780) | Partly: the map ID and the three dungeons. |
| `SpiritHealerDB.lua` | `SpiritHealerWorld[continent] = {wx, wy, name}` for the ghost/deathskip arrow | Classic list; **no Zephras entries**. |
| `quest.lua` | `skipPreReq`, `questConversion` (empty), `questCompleteItems` (quest → item to put on the bar, e.g. Crown of the Earth phials) | Mostly Classic IDs. |
| `spells.lua` | Per race/class/level spell lists for auto-training (cooking, first aid, riding at 40) | Classic-era lists, gated on Forever. |
| `rares.lua` | Rare names per zone | **Disabled** on client 1.15.8+ (`TargetUnit` is now forbidden), so it's inert on current Forever. |
| `dangerousMobs.lua` | Per zone: level range, elite/normal, patrol, note, map line/pin | Classic copy; even includes Outland zones. Darkshore and Teldrassil entries match this route's warnings (Lord Melenas, Bloodfeather Matriarch, Threshwackonator, Xabraxxis, Raging Reef Crawler, Greymist Oracle, Moonstalker Matriarch). |
| `StatWeights.lua` | Item stat weights per class/spec for upgrade scoring | Generic. |

**Bottom line.**
- The **guides** cover Forever's new 1-20 content thoroughly: Zephras Isle, the new quests and dungeons, the boat route, the egg buff.
- The **DB** files are mostly Classic data with a Forever gate. The only new data are Zephras's map ID and three dungeon codes.
- For our helpers, the guides are the useful fact source for new-content NPCs, objectives and coordinates. The DB files add little.
