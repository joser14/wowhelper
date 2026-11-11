# Final review: LevelGuide (11 November 2026)

Scope: every file in `LevelGuide\`. `LevelGuide.lua` was read in full. `Planner.lua` and `TravelPlan.lua` were read
in full, and the data and lookup files (`Routes.lua` helpers, `QuestLookup.lua` Fill) where `LevelGuide.lua` relies
on them. Context: an Alliance Night Elf priest, about level 11, on client 1.60.1 (interface 16001).

Each bug below was reproduced with a failing test before it was fixed:
`tests\test_final_lg_skips.lua` and `tests\test_final_lg_boats.lua`, both added to the LevelGuide map in
`tests\runall.ps1`. `runall.ps1` result: 0 failed.

## Fixed

### 1. BUG: "Skip it" could leave an empty undo entry (LevelGuide.lua `X.SkipQuest`)
- **What happened:** `X.SkipQuest` always pushed `{ keys = keys }` onto the undo list, even when every step was
  already skipped and `keys` was empty.
- **How to hit it:** skip a quest from the lost-quest card, take it again, then drop it again and pick "Skip it"
  a second time (the group-quest card's "Skip it" can do the same).
  - The header still said "Right-click here to undo", but the next right-click only removed the empty entry.
  - Nothing came back, and the undo for the real earlier skip was hidden behind that click.
- **Fix:**
  - `X.SkipQuest` only records an undo entry when it skipped something, and also returns how many keys it set.
  - `X.AnswerLost` and `X.AnswerGroup` only show the "Right-click here to undo" notice when something was skipped.

### 2. RISK fixed: a quest greeting with hidden counts marked every pick-up "not offered" (`ReadWindow`)
- **What happened:** the counts were read as `GetNumAvailableQuests and Safe(GetNumAvailableQuests()) or 0`. A
  secret count therefore became 0, and the window still counted as readable.
- **Effect:** `X.JudgeOffers` then marked every route pick-up from that NPC as "not offered at level N". Those
  pick-ups stayed hidden for 30 minutes or until a level-up.
- **Fix:** when either count exists but can't be read, the window judges nothing, as it already does for an
  unreadable gossip entry.

### 3. BUG: a boat departure time didn't count down (LevelGuide.lua `X.ApplyTravel`)
- **What happened:** standing still at a pier, `moved` is 0. That is truthy in Lua, so the 10-second replan
  rule never fired, and the plan was only rebuilt by the 30-second refresh.
- **Effect:** "Take the boat at ..., leaves in 0:50" kept showing the same time for up to 30 s. It could still
  read "leaves in 0:05" after the ship had left.
- **Fix:** while the shown leg has a known departure (`leg.anchored`), the way is worked out again on every
  rebuild (every 2 s). A plan is a small Dijkstra search, so this is cheap.

## Rule checks

| Check | Result |
|---|---|
| Hooks of Blizzard functions, writes to Blizzard tables, globals or frames | **Pass.** No `hooksecurefunc` or `HookScript` on Blizzard objects. Every frame is our own (`LevelGuideFrame`, the cards, the route list, `LevelGuideTooltip`). The shared `Forever*` globals are our own helpers. |
| Map canvas pins | **Pass.** No `AddDataProvider` or `AcquirePin`. `LevelGuide_UpcomingStops` and `LevelGuide_QuestGivers` only return data, and MapPins draws it. |
| `COMBAT_LOG_*` or CallbackEvent registration | **Pass.** The event list (line ~6070) has no CallbackEvents, and each event is checked with `C_EventUtils.IsEventValid` and registered in `pcall`. |
| Chat output | **Pass.** No `print` or `AddMessage`. The single message goes through `ForeverHub_Receive`, the hub's pop-up. |
| Automation | **Pass.** It never accepts, turns in, buys, trains or uses anything. `C_Map.SetUserWaypoint` and `C_SuperTrack.SetSuperTrackedQuestID` run only when you left-click a step. The shared waypoint clears only its own pin when you arrive. `RequestLoadQuestByID` and `RequestQuestLinesForMap` only ask for data, never in combat (`X.ScanTick`). |
| Secret values | **Pass**, apart from #2 (fixed). Every API value used in arithmetic, comparisons, string building or as a table key goes through `Safe()`: quest log info, objectives, positions, XP, money, cooldowns, gossip, taxi nodes, GUIDs and facing. |
| Combat | **Pass.** The work done in combat is limited to `SetText`, `SetPoint` and `Show` on our own frames, and creating plain frames. Nothing is protected or secure. The server-level scan and "While you're here" pause in combat. |
| Lua limits | **Pass.** The test harness (fengari, which enforces the same 200-local limit as `lparser`) loads the file. Measured on the main chunk: at most 179 active locals. Most upvalues in any function: 32 (`RouteSteps`), under Lua 5.1's limit of 60. Largest stack frame: 205, under the limit of 250. |
| UI only | **Pass.** There is no slash command. The route list opens from the header click or the List button. Skip is Shift+right-click and undo is right-click on the header. The spot card is Ctrl+right-click. The arrival sound is the "Snd" button. The cards have their own buttons. |
| SavedVariables growth | **Pass.** `killXP` is capped at 30 and `spots` at 200. `notOffered` is pruned at login (30 minutes). `lost` and `extras` are dropped after a week. `boats` entries are dropped after 6 hours. Everything else is bounded by the routes' steps or quests. |

## Not fixed (NIT or latent)
- **NIT, `X.AnswerLost(true)`:** "Go back" for a dropped quest from a route other than the active one (for example a
  Teldrassil quest dropped in Darkshore) clears the card but points nowhere. The pick-up isn't on the active route.
- **Latent, `X.CampPoint` and `PlacePoint`:** a camp point is already on the zone map, but `PlacePoint` still runs
  `CityToZone` on it when the step's note says ", Darnassus". Today no route step has both. The QuestDB camps for
  Sathrah's Sacrifice and Eyes of the Sentinels are on Darnassus's own map (1457), so no camp is picked for them.
- **NIT, comment:** the hints block comment says the death skip is "below level 10". The code, correctly, uses
  `P.DEATH.maxLevel` (20).

## Needs the game (left unfixed)
1. **Crossing continents by boat:** does `ZONE_CHANGED_NEW_AREA` fire mid-voyage, or after the loading screen?
   - If it does, `X.travelReplan` ends the "On the boat to ..." hold early, and the guide may show a leg from
     mid-sea.
   - Also check what `C_Map.GetBestMapForUnit` returns on the boat after the load.
2. **Riding check:** confirm that `C_SkillInfo.GetSkillLineInfoByID(762)` returns a table with `rank` on Forever.
3. **Quest greeting counts:** confirm that `GetNumAvailableQuests` and `GetNumActiveQuests` are never secret at an
   NPC. Fix #2 only matters if they are.
4. **Super-tracking:** confirm that `C_SuperTrack.SetSuperTrackedQuestID` from a step click (allowed while
   untainted) raises no taint report from the objective tracker.

## Summary
LevelGuide passes every rule check: no hooks, no map canvas pins, no CallbackEvents, no chat output and no
automation, and its game reads are secret-safe. The file still loads, with headroom under the local, upvalue and
stack limits of Lua 5.1. Three bugs were confirmed by failing tests and fixed:
- an empty undo entry after skipping a quest whose steps were already skipped;
- quest-greeting counts the game hides being read as "nothing offered";
- a boat departure time that froze for up to 30 s.

Four behaviours need checking in game, mainly the boat ride across continents.
