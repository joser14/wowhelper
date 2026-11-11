# Final review: ForeverCharacter and ForeverWorld

Scope (build.ps1:38-41): ForeverCharacter = TalentNudge, Builds, TrainerNotes, WeaponSkillWatch, RestGuard, LevelLog,
RepWatch, ReadyCheck. ForeverWorld = Landmarks, DeathNotes (with BreathWatch, LowWarn), RareWatch, MapPins (with Way).
Reviewed against research\BRIEF.md and the API docs in uisrc2. Date: 2026-11-11.

## Result

No BUG or RULE findings were confirmed, so no addon file was changed. This review adds one test:

- `tests\test_final_world_secrets.lua` loads all 12 helpers together in combat (`InCombatLockdown()` true) with every
  unit, XP, money, zone, map, position, reputation, item, skill, talent and aura reading secret. It fires every registered
  event with secret arguments over three rounds, runs every ticker, timer and OnUpdate, and draws every page
  (`"", "all", "1", "window"`), side-panel line, LevelLog page and the Builds talent-panel text. Then it ends the fight.
  It fails on any error, any chat output, `hooksecurefunc`, automation calls, `AddDataProvider`/`AcquirePin` on
  the world map, any CallbackEvent registration, or `SlashCmdList`/`UISpecialFrames` being replaced or written. It
  also checks that it is not passing vacuously (more than 60 events registered, the login tickers started, all 13
  pages present, saved data created). It passes on the current code.

## Rule checks (all clean)

| Rule | How it was checked | Result |
|---|---|---|
| No COMBAT_LOG_* / CallbackEvent registration | Every `CallbackEvent = true` event in uisrc2 (12 of them) cross-checked against every event-name string in the 12 folders; plus the new test traps `RegisterEvent`/`RegisterUnitEvent` | None registered. DeathNotes.lua:772 keeps the warning comment |
| Every unguarded `RegisterEvent` names a real event | All literal event names checked against the 1816 `LiteralName`s in the API docs | All exist |
| No map canvas pins | grep `AddDataProvider`/`AcquirePin`; the test traps both on WorldMapFrame | MapPins draws its own frames on a UIParent overlay and only reads WorldMapFrame (`IsShown`, `GetMapID`, strata/level, `ScrollContainer.Child` rect) |
| No hooks or writes to Blizzard tables/frames | grep `hooksecurefunc`, `HookScript`, `_G[...] =`, Blizzard frame names | None. Builds reads `_G[name]` talent windows (IsShown, rect) only; RepWatch reads `FACTION_STANDING_LABEL<n>`; LevelLog does not use UISpecialFrames (LevelLog.lua:1421) |
| No `SlashCmdList = SlashCmdList or {}` | grep | None |
| No chat output | grep `print(`/`AddMessage`/`DEFAULT_CHAT_FRAME`; every `Print` goes only to `ForeverHub_Receive` | Clean; the test fails on any chat line |
| No automation | grep for cast/target/train/buy/use calls | None. RareWatch never targets (RareWatch.lua:539); RepWatch only counts turn-ins |
| Secret values | Read every new code path; the test runs all of them with secrets | All arithmetic/compare/concat goes through `Safe()`/`Number()`/`Text()`. LowWarn passes the curve results from `UnitHealthPercent`/`UnitPowerPercent` straight into `SetAlpha` and nothing else (LowWarn.lua:126-135) |
| Combat safety | Our frames only; the minimap pins and edge arrow are children of Minimap (the accepted exception); frames are created at load or out of combat (Builds.lua:1050, MapPins.lua:1209) | Clean |
| SavedVariables bounded | Read every writer | See below |

SavedVariables bounds: BuildsDB (one goal per character), TrainerNotesDB (fixed lists), LevelLogDB (per character: one
entry per level 1-60, journey 1000 (LevelLog.lua:568), days 60, zone times 120, seen places 300, window settings;
`journeyOld` adds one small count table per calendar month), LevelLogXPCurve (59 levels), RepWatchDB (keyed by the fixed
TURNINS lists and faction IDs), ReadyCheckDB (ignored list from fixed data), LandmarksDB (400 places per realm, flight
points and times keyed by real taxi nodes), DeathNotesDB (200 deaths per realm), RareWatchDB (300 rares, watch list 50,
10 extra IDs per watch entry), MapPinsDB (layer switches).

## Focus areas, verified by reading the code paths

- **Builds, talents through C_Traits** (Builds.lua:299-442). The code handles both layouts: three tree IDs, or one tree
  whose sub-trees are named. `KnownTree` matches on the first word, so the game's "Shadow Magic" / "Elemental Combat"
  and the data's spec words "Shadow" / "Elemental" both resolve. `DefaultRole` tries both the spec word and the build's
  main point tree (Builds.lua:526-541). Rows are counted per tree from node heights, and `RowOpen` uses them. Covered
  by test_builds.lua:404-430 and test_logic_char_builds.lua:77+.
- **Builds talent-window panel** (Builds.lua:843-1070). It is our own Button on UIParent, placed by reading the
  window's rect, and never anchored or parented to Blizzard frames. The 0.25 s watcher hides the panel when the window
  closes and marks it dirty, so it redraws on reopen. It is created only out of combat. Long text is trimmed but keeps
  the footer.
- **LevelLog journey / stats / ETA** (LevelLog.lua:564-1290). The quest-vs-kill split handles either event order:
  `pendingQuest` / `lastGain` and `DropRecentKills(0.5)` with `KILL_WAIT` 1.5 s. Level-up handling copes with
  UnitLevel lagging (`before`/`after`). The pace is a weighted median with a 2x outlier cut. `XPTo` sums the rest of
  the bar plus the full bars between. The ETA date is `Now() + hours / perDay * 86400`. All caps hold (covered by
  test_r5a_levellog.lua section 8).
- **RepWatch turn-ins** (RepWatch.lua:141-356). A turn-in is matched only when QUEST_TURNED_IN, a bag drop in whole
  turn-ins and a gain with that faction all fall within 5 s, in any order. `Resolve` runs on each of the three events.
  Stale drops and gains are rejected by the time check.
- **DeathNotes / LowWarn** (LowWarn.lua). The `UnitHealthPercent(unit, usePredicted, curve)` and
  `UnitPowerPercent(unit, powerType, unmodified, curve)` argument orders match UnitDocumentation.lua:1506/2838. The
  curve calls match LuaCurveObjectAPIDocumentation. Combat state comes from the regen events. A refused call switches
  the cue off for the session.
- **MapPins overlay and edge arrow** (MapPins.lua:792-1431). Pin positions are the canvas rect plus x/y times its
  size, kept inside the visible scroll rect, divided by the overlay scale. Relayout happens only when the rounded
  geometry changes, and it is reset on reassign. The edge arrow's rotation `atan2(-x, y)` points the up-facing art
  at the target (east gives -90 degrees). The rotating-minimap transform puts the facing direction up.

## NIT (not changed)

1. LevelLog.lua:902-903: the comment says the current level "blends in up to 40 % once you've played it two hours",
   but the code `min(0.4, seconds / 60 / 120)` (LevelLog.lua:943) reaches 40 % at 48 minutes. The code matches the
   spec (research\re_round5.md:307, `min(0.4, minutesThisLevel/120)`), so only the comment is loose.
2. RepWatch.lua:345-351: BAG_UPDATE_DELAYED falls through to `TakeBaseline()`, which reads every faction (and every
   collapsed one by ID) on each bag update. This is cheap but unnecessary; `return` after `Resolve()` would avoid it.
3. LevelLog.lua:1441-1442: opening the window draws it twice (the OnShow script plus the explicit `RefreshWindow()`).
4. LevelLog.lua:723-724: if the journal starts inside a dungeon, that dungeon is only remembered, so the next one is
   not marked "first dungeon in this log".
5. Way.lua:99-106: `/way clear` clears only a pin the shared waypoint is watching. A pin set where arrival can't be
   measured (no continent position) gets "No pin of ours to clear."
6. MapPins.lua:812-815: the overlay sits one strata above the map (DIALOG over a HIGH map), so our pins draw over a
   StaticPopup that overlaps the map. By design (tooltips stay on top).

## Needs the game (left unfixed)

1. Builds: Forever's talent window frame name. The panel relies on the known names plus discovery of top-level
   `...Talent...Frame` globals parented to UIParent (Builds.lua:925-942). Check that the panel appears beside the
   window and never stays up with the window closed. Also check whether `node.activeRank` includes unapplied (staged)
   points, since TalentNudge's count excludes them.
2. LowWarn: that `UnitHealthPercent`/`UnitPowerPercent` accept the curve on 1.60.1 and return 0-1 (the curve's x
   axis), so that the red edge shows under 35 % health and the drink under 20 % mana.
3. MapPins: pins line up with map points at every zoom and pan, and in the maximized map. The edge-arrow direction
   should be checked with the rotating minimap on and off. Clicking a pin in combat should set the map pin with no
   pop-up.
4. RepWatch: the item IDs and rep values of the turn-ins (marked NOT VERIFIED in the file), and the event order on a
   real turn-in. Also check whether Minion's Scourgestone turn-ins stop giving reputation at Honored, as in Classic.
   If so, its "turn-ins to the next standing" line would be wrong past Honored.
5. LevelLog: the AFK rule (180 s with no movement, XP, money, combat or quest event) against real play, and whether
   `IsPlayerMoving` and `UnitOnTaxi` are readable in combat.
6. RestGuard: the camp spell IDs (marked UNVERIFIED).
7. DeathNotes: whether the hostile target (or the last one within 15 s) names the real killer often enough.

## Summary

ForeverCharacter and ForeverWorld pass the final review with no confirmed bugs or rule breaks. No CallbackEvent or
COMBAT_LOG registration remains, which was the cause of the 2026-11-09 "ForeverWorld blocked" pop-up. There are no map
canvas pins, hooks, Blizzard table writes, chat output or automation. Secret values are guarded everywhere, and LowWarn
puts its secret curve results only into SetAlpha. Every SavedVariable is capped. The new
`tests\test_final_world_secrets.lua` checks all of this together under combat secrets and passes. What remains is
listed above: six NITs, and in-game checks of the talent window's name, the LowWarn curve scale, map pin alignment,
the turn-in data and a few heuristics.
