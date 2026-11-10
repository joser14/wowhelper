# Review 3: LevelGuide (2026-11-10)

Scope: `LevelGuide\*.lua` (LevelGuide.lua, Planner.lua, TravelPlan.lua, Travel.lua, QuestLookup.lua), traced as they
run in game: event order, SavedVariables timing, secret values, units, caches, saved-data growth, per-frame cost,
feature interactions and rule safety. APIs checked in uisrc2 (`QuestLogDocumentation`: QUEST_ACCEPTED(questId),
QUEST_REMOVED(questID, wasReplayQuest), QUEST_TURNED_IN(questID, xpReward, moneyReward), QUEST_DATA_LOAD_RESULT(questID,
success); `SystemDocumentation`: UI_INFO_MESSAGE(errorType, message); `DeathInfoDocumentation`:
GetCorpseMapPosition(uiMapID) -> vector2, GetGraveyardsForMap(uiMapID) -> GraveyardMapInfo{position, name, ...}).
The handler's argument use matches all of these.

Rule safety: no hooks, no Blizzard table writes, no map canvas pins (MapPins draws from `LevelGuide_UpcomingStops`),
no COMBAT_LOG/CallbackEvent registration, no chat output, nothing accepted, bought, targeted or used. The only calls
with an effect are on the player's own click (`C_Map.SetUserWaypoint`, `C_SuperTrack.*`) and
`C_QuestLog.RequestLoadQuestByID` (data load, out of combat). Every client value read goes through `Safe()`.

## Confirmed and fixed (each with a failing test first)

1. **BUG — a running timed quest on another map lost its location** (`PutTimedFirst`). When the quest's step wasn't in
   the list (its objective on another map: only a "travel" trip for the zone was there), a bare step without map,
   goal or arrow was put on top, and stayed there until the timer ran out. Fix: `X.QuestSpot` fills its spot on your
   map (or the game's next leg there) and its goal for the travel planner. Test `tests\test_review3c_timed.lua`.
2. **BUG — "near the start" measured to the wrong place** (`X.NearStart`). A start step written "Name, Darnassus" uses
   Darnassus's own map, but its numbers were read on Teldrassil's map, so standing at those numbers on Teldrassil (about
   450 yd from the city) passed the move before it. Fix: measure to `PlacePoint`'s converted spot. Test
   `tests\test_review3c_nearstart.lua`.
3. **BUG — no arrow for a step on a neighbouring map reached on foot** (`X.ApplyTravel`). A step written `On("Stormwind
   City")` seen from Elwynn: the planner found "walk" and returned, leaving the step with no spot on your map, so the
   arrow was hidden ("other zone"). Fix: project the goal onto your map through Travel.lua's world frames
   (`P.TravelOnMap`). Test `tests\test_review3c_walkarrow.lua`.
4. **BUG — walking off a pier showed "On the boat to ..."** (`X.ApplyTravel`). Any move 40 yd from the dock started the
   ride hold, which then lasted wait + ride + 90 s, even on foot and even for the next step on your own map. Fix: a ride
   starts only when you leave the pier at 12 yd/s or more (position change over time); walking off clears the dock.
   Built with round-3 rank 5. Test `tests\test_lg_boats.lua` section 5 (and `test_lg_travel_guide.lua` 6 now
   advances time when boarding).

## Suspicions (not changed; how to check in game)

- **XP/h after a level-up** (`X.OnXP`): if `UnitLevel` still returns the old level when PLAYER_XP_UPDATE for the
  level-up arrives, the next gain is computed across the stale level and adds one huge gain to the 15-minute XP/h for
  15 minutes (the kill share is dropped by the ratio cap). Check: level up while watching "XP/h" on the plan line;
  if it jumps for 15 minutes, take the level from PLAYER_LEVEL_UP (now stored in `X.levelUpTo`) in `OnXP` as well.
- **Lost-quest card after a turn-in** (`X.ResolveRemoved`): it relies on QUEST_TURNED_IN coming before (or within the
  0.1 s rebuild delay of) QUEST_REMOVED. Check: turn in a route quest; no "You dropped ..." card must appear.
- **Corpse on the continent only**: the corpse search now climbs to the continent (it stopped after two parents), but a
  corpse that only the continent map reports gives a continent-scale arrow. Check: die near a zone border, release
  across it; the arrow and "Corpse N yd m:ss" must point at the body.
- **Nearest spirit healer** uses Travel.lua's 84 healers and `C_DeathInfo.GetGraveyardsForMap` when it lists any (it
  may be battleground-only). Check: dead, the "Spirit healer about N yd from your body" line against where you appear.
- **Death skip up to 20**: MacQuest's 21 s per level above 10 stands in for resurrection sickness; check the hint only
  shows when it really saves time.
- **Boat departures**: the timetable is Shortest Path Forever's model, not measured on Forever by us. Check: at
  Auberdine's pier after one boarding, "leaves in m:ss" against the boat; Southshore's three-stop ship (11167).
- **Hostile towns**: Horde flight-master spots from Blizzard's TaxiNodes via SPF; check that a walk in The Barrens
  no longer cuts through the Crossroads and that the "Careful: hostile ..." note shows.
- **Skyborne race token**: the ley line hint (rank 16) and the plan use the token "Skyborne" (Routes.lua's plan uses
  it too); check `/dump UnitRace("player")` on a Skyborne.
- **Per-frame cost**: fine. Rebuilds every 2 s (0.1 s after events); the arrow at 20 Hz; the server-level scan is one
  request per 0.5 s after 60 s. The route-choice card's travel plans are cached 30 s; quest-rule log sets are cached
  per rebuild (weak keys).
- **Saved data**: bounded (killXP 30, spots 200, not-offered marks 30 min, lost/extras a week, boat anchors 6 h per
  realm, server levels only where they differ from QuestDB). `charData.routeShapes` keeps one hash per route step.

## Round-3 items built (each with a failing test first)

| Rank | What | Files | Test |
|---|---|---|---|
| 2 | Quest rules: exclusive groups, next in chain, disabled by, removed, breadcrumbs (target waits while the breadcrumb is in your log; the breadcrumb goes once the target is done or held); an exclusive partner counts for an "all" prerequisite; generated routes keep one of a group. Groups are also worked out from forever-db itself ("one of" prerequisites with the same title and level), which finds the four "The Great Outdoors" variants. | `QuestRules.lua`, `LevelGuide.lua`, `QuestLookup.lua` | `test_lg_rules.lua` |
| 2 | Offline audit `node tools\audit_questie.js <QuestieDB> [--all]`: prints Questie's exclusive/prereq/next/disabled/breadcrumb/spot differences for route quests (465 leads today); never copies data. | `tools\audit_questie.js` | run by hand |
| 5 | Boat and zeppelin timetable (SPF, GPL) per link; unanchored wait = half a period ("~"), exact "leaves in m:ss" for 6 h after you see a departure or landing yourself; per realm in `LevelGuideDB.boats`. | `Boats.lua`, `TravelPlan.lua`, `LevelGuide.lua` | `test_lg_boats.lua` |
| 10 | Corpse ETA at run speed (also standing still), nearest spirit healer from your body, death skip up to 20 with MacQuest's seconds (GPL). | `TravelPlan.lua`, `LevelGuide.lua` | `test_lg_corpse.lua`, `test_lg_hints.lua` |
| 11 | XP for "!" quests not taken yet; "Slow (grinding is faster)" tag on pick-ups under 0.65 x the grind rate (MacQuest maths, GPL). | `Planner.lua`, `LevelGuide.lua` | `test_lg_xpoffers.lua` |
| 16 | Skyborne: nearest ley line within 400 yd (tr0tsky's spots, MIT, via OneForAll). Library books and zone exits not built (OFA's book list is its own GPL data but needs its EPL points checked; Carbonite crossings not read). | `SkyborneSpots.lua`, `LevelGuide.lua` | `test_lg_leylines.lua` |
| 17 | Hostile towns (Horde flight masters with no Alliance one within 400 yd, 150 yd circle, 6x cost, real time shown), plan notes "Careful: hostile X on the way" / "Crosses Duskwood (18-30)", replan on PLAYER_LEVEL_UP with the event's level. | `HostileTowns.lua`, `TravelPlan.lua`, `LevelGuide.lua` | `test_lg_hostile.lua` |

## Data leads from the QuestieDB audit, and how each was checked

None of these is shipped unless it was confirmed by something other than Questie.

| Lead | Check | Result |
|---|---|---|
| 93928 "Of Mice and Milk" blacklisted on Forever | Wowhead Forever page (no removal note); QuestieDB's own player traces list its giver and ender (players did it) | **Contradicted**: kept. In game: talk to the mouse in Westfall. |
| 98387 Blackrock Blockade gates 19 / 115 | Wowhead Forever: Tharil'zun's series lists Blackrock Menace (20), Alther's Mill (98386) and Blackrock Blockade (98387) before it | Already in `Prereqs.lua` (`all = { 20, 98387 }`); no change. Wowhead shows no series for 115: check in game that Shadow Magic waits for Blackrock Blockade. |
| 98323 Secure the Mountain (3) gates 291 The Reports | Wowhead lists only Frostmane Hold (287) before The Reports | **Unconfirmed**: not added. The Dun Morogh route does Secure the Mountain before The Reports anyway. In game: is The Reports offered with Frostmane Hold done and Secure the Mountain not? |
| Shayla (2155) at 40.5, 50.7 (ours 42.2, 51.3; route also 41.1, 50.9) | No independent source | **Unconfirmed**: in game, Ctrl+right-click the step to set your own spot if she stands elsewhere. |
| 324 The Lost Ingots / 526 Lightforge Ingots exclusive | Wowhead Forever shows both in one series, no exclusivity note | **Unconfirmed**: not added; the route already says "only if he offers it" and "not offered" marks cover it. |
| Four "The Great Outdoors" (95998, 96101, 96606, 96608) | forever-db: every Camping 101 quest takes "one of" them; same title, level and races | **Confirmed from forever-db's own structure** (derived at run time, no list shipped). |
| 40 other exclusive groups, 131 next-in-chain, 7 disabled-by, 26 prerequisite and 261 NPC-spot differences | Not checked one by one | Leads only: `node tools\audit_questie.js ...\QuestieDB` prints them for checking on Wowhead Forever or in game. |

## Summary

Four LevelGuide bugs were confirmed and fixed with tests: a timed quest on another map lost its location, the
near-start check measured to a city start's numbers on the wrong map, steps on a neighbouring map reached on foot had
no arrow, and walking off a pier was shown as riding the boat. Round-3 ranks 2, 5, 10, 11, 16 (ley lines only) and 17
are built with tests and credited (SPF, MacQuest, tr0tsky in NOTICE.md). Of the Questie leads, only the Great Outdoors
group was confirmed independently (from forever-db itself); 93928 is contradicted by Questie's own traces and stays;
98323, Shayla's spot and 324/526 need an in-game look. Nothing from QuestieDB is shipped.
