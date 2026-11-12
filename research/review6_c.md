# Review 6c: MapPins exploration, ItemFinder bag view, Tooltips drop rates and wish line, QuestMobs rates

Commits reviewed: 1970e4a (MapPins exploration grid and pin; ItemFinder bag view) and 9161d28 (Tooltips wish-list
line and your own drop rates; QuestMobs reading Tooltips_YourDrops). Checked against research\BRIEF.md and the API
docs in uisrc2. Date: 2026-11-11.

## Fixed (failing test first)

### 1. BUG: exploration sampling ran with the "explore" layer off, and with MapPins Off on the hub
- MapPins\MapPins.lua `Explore.Retarget` (called every second out of combat) requested a sample of your zone
  before checking `Explore.On()`, and `Explore.Step` never checked it, so every zone you entered was sampled
  (1024 cells, about 1,300 API calls and one new table per call) even with the layer off or MapPins switched Off.
  The world map's info line then still showed "Explored about N%", because `Explore.LineFor` only checked the
  switch before requesting, not before returning a label.
- Scenario: `/mappins off explore`, or MapPins Off on the hub. Entering Teldrassil still made 676 calls, and
  MAP_EXPLORATION_UPDATED made 676 more.
- Fix: `Explore.Step` returns while the layer is off, and the queue waits. `Retarget` requests only when on, and
  `LineFor` returns nil when off. MAP_EXPLORATION_UPDATED still queues the zone, which costs nothing while off,
  so a zone sampled earlier is refreshed when you switch the layer back on.
- Test: tests\test_cr6c_mappins_explore_off.lua.

### 2. RISK: a secret unit token on UNIT_SPELLCAST_SUCCEEDED let skinning or pick-pocket loot count as a corpse
- Tooltips\Tooltips.lua OnEvent: `if Safe(unit) == "player"`. UnitDocumentation marks UNIT_SPELLCAST_SUCCEEDED
  `SecretWhenUnitSpellCastRestricted = true`. When the token comes secret, `Safe` returns nil, so the cast isn't
  noted. The next LOOT_OPENED (pick pocket, or skinning someone else's kill) is then counted as a corpse with
  those items. For pick pocket, the creature's GUID is also put in `seenCorpse`, so its real corpse loot is
  ignored later.
- Fix: the event is registered with `RegisterUnitEvent(..., "player")`, so every event is your own cast. A
  `playerCastsOnly` flag skips the token check, and only the all-units fallback still reads the token.
- Test: tests\test_cr6c_tooltips_secretcast.lua.

## Checked and fine
- **Rules.**
  - No hooks. The only registration is TooltipDataProcessor.AddTooltipPostCall.
  - No writes to Blizzard frames or tables.
  - The explore pin is a Button on MapPins' own UIParent overlay (`Add` → `SOURCES.explore`), never the canvas pool.
  - `SetUserWaypoint` is reached only from `WorldPinClick` and the minimap pin's OnClick.
  - LOOT_OPENED, UNIT_SPELLCAST_SUCCEEDED and MAP_EXPLORATION_UPDATED are documented events, all
    `SynchronousEvent`, none `CallbackEvent`.
  - No COMBAT_LOG_*.
  - No chat output: new text goes through Print → ForeverHub_Receive.
  - Nothing loots: `LootSlot`/`AutoLootItem` are never called.
- **Exploration.**
  - Sampling happens out of combat only, at 128 cells per 0.1 s tick, and only while a zone is queued.
  - Land is cached per session.
  - The nearest-spot loop reuses one vector and makes no tables unless the target changes.
  - Progress is (land - open) / land, with landCount > 0 checked.
  - Edge neighbours read nil outside the grid, which is safe.
  - Walked cells are bounded at 64 per zone and 80 zones.
  - Secret area IDs are skipped.
- **Bag view.**
  - Icons cover all five places from `items[place]`, with legacy name-keyed counts in the header.
  - Character switching wraps both ways and clamps when nobody is saved.
  - The search dims through `ApplyFilter` and survives a character switch.
  - Icons are pooled (600 at most), headers are pooled, and unused icons are hidden with their `entry` cleared.
  - Icons are plain Frames with OnEnter/OnLeave only, and the tooltip is our own `ItemFinderTooltip`.
  - Refresh runs on open and debounced at 0.3 s on data events, never per frame.
- **Drop rates.**
  - Each corpse is counted once: `corpses[guid]` per window plus a 1000-GUID session ring.
  - Each item counts once per corpse (a set).
  - AoE loot reads every (guid, qty) pair from index 2.
  - GameObject, Item, Player and Pet GUIDs are filtered by `NpcID`, which parses
    `Creature-0-server-instance-zone-npcID-spawn`.
  - Caps: 300 creatures (the lowest n is evicted, then the oldest) and 25 items per creature (the lowest k).
    The entry being added is kept.
  - No divide-by-zero: the tooltip needs n >= 10, QuestMobs checks n >= 1, and the own-rate path checks k > 0.
  - Duplicate lines are prevented by a prefix check on the existing tooltip text.
- **Wish line.**
  - Nothing appears when `Dungeons_IsWished` is nil or errors, when Tooltips is Off on the hub, or when the line
    is switched off.

## Suspicions that need the game (not changed)
- MapPins: `GetMapInfoAtPosition(continent, x, y)` is assumed to return the zone, not a micro-map, city or
  dungeon map inside it. If it returns deeper maps, those cells count as not land. Check the "Explored about N%"
  line in Elwynn (with Stormwind City) and in Teldrassil (with Darnassus).
- MapPins: an area's overlay texture can be larger than the spot where it is discovered. A cell can stay
  "unexplored" until the 3 s dwell sets it aside, and set-aside cells then count as explored in the share.
- Tooltips: the 0.6 s cast window assumes LOOT_OPENED arrives right after SPELL_GO for skinning and pick pocket.
  With high latency, a skinning window could slip through. That corpse is usually already in `seenCorpse`, so
  the risk only applies to corpses looted by someone else.
- Tooltips: with autoloot, the counts depend on the slots still being readable during LOOT_OPENED.

## NITs (not changed)
- Tooltips: `seenCorpse` is session-only. A corpse partly looted, then /reload, then reopened is counted again.
- Tooltips: a corpse skipped because of the cast window isn't remembered. If it is reopened later, it counts with
  only the items left on it.
- Tooltips: the wish line still shows when Dungeons itself is Off on the hub. This matches the existing "drop"
  line, which also reads Dungeons data without checking that switch.
- Tooltips `PercentText`: a value from 9.95 to 9.99 prints "10.0%".
- QuestMobs `DropFor`: on a mob the classic table doesn't know, every objective row calls
  `Tooltips_YourDrops(npc)`, which copies up to 25 entries per call. That is small churn per unit tooltip.
- MapPins `Retarget`: the switch hysteresis compares the new spot's distance, with the x4 coastal penalty, to the
  current target's distance without it, so a coastal target is stickier than intended.
- ItemFinder: the bag view isn't closed by Escape. Adding it to `UISpecialFrames` would mean writing to a Blizzard
  table, so leaving it out is correct under the rules.

## Summary
Two issues were confirmed and fixed with failing tests first:
- MapPins sampled exploration, and showed its info-line label, even with the explore layer or MapPins switched
  off.
- Tooltips missed your own cast when UNIT_SPELLCAST_SUCCEEDED's unit token is secret, so pick-pocket or skinning
  loot could be counted as a corpse.

No rule breaks were found. There are no hooks, no canvas pins, no CallbackEvent or COMBAT_LOG registrations, no
chat output and no automation; waypoints are set only on the player's click. The bag view is read-only and
pooled. The drop-rate counting handles AoE loot, secret GUIDs, caps and zero counts correctly. The remaining
items are checks to make in game and minor notes. The full suite passes (0 failed).
