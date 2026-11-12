# Full review: LevelGuide (11 November 2026)

Scope: all of `LevelGuide\`, hardest on the code added since `research\final_review_levelguide.md`:
`Ahead.lua`, `QuestRewards.lua`, `X.AheadQuests` and the "Upgrade ahead" row in `LevelGuide.lua`, and how they
use `ItemAdvisor_Judge`. The Night Elf route 1-30, the death spot, boats and skip/undo were checked again.
Context: an Alliance Night Elf priest, about level 11, client 1.60.1 (interface 16001).

Each bug below was reproduced with a failing test before it was fixed: `tests\test_full_lg_ahead.lua`, added to
the LevelGuide map in `tests\runall.ps1`. `runall.ps1` result: 0 failed.

## Fixed

### 1. BUG: a hand-in the guide passes was still an "Upgrade ahead" (LevelGuide.lua `X.AheadQuests`)
- **What happened:** `X.AheadQuests` took every turn-in from the first shown step on, without the guide's own
  "4+ levels below you counts as done" rule (`Outleveled`).
- **Effect:** "Upgrade ahead: <item> from <quest> (step N)" could name a quest the guide skips past, and the
  route list shows that step as done.
- **Fix:** turn-ins with `Outleveled(step, level)` are left out.

### 2. BUG: a hand-in whose pick-up you skipped was still an "Upgrade ahead" (`X.AheadQuests`)
- **What happened:** only the turn-in step's own skip was checked. Shift+right-clicking the pick-up skips only
  that step, so the turn-in stayed in the list.
- **Effect:** the guide line and ItemAdvisor's Bag advice page promised a reward from a quest you chose not to do.
- **Fix:** a turn-in is left out when you don't hold the quest and its pick-up on the route (same title and
  part) is skipped or passed by level.

### 3. BUG: the upgrade line went blank when ItemAdvisor couldn't read your worn gear (Ahead.lua `A.Update`)
- **What happened:** `ItemAdvisor_Judge` returns nil both for an item still loading and for "Can't read your worn
  gear right now (combat or instance)". `A.Update` only kept the last list in combat (its own check), so with
  hidden gear outside combat (an instance, per ItemAdvisor) every reward came back nil and the list was replaced
  by an empty one.
- **Effect:** "Upgrade ahead" disappeared, and the window said "Reading the rewards' stats...".
- **Fix:** when no reward at all could be judged, the last list stays (less any quest no longer ahead); it is
  still asked again a second later.

### 4. BUG: "Upgrade ahead" stayed after the route ended (`X.AheadQuests`)
- **What happened:** with no active route (past the last route's levels, or no route for the zone) the function
  returned before calling `A.Update`.
- **Effect:** the last route's upgrade stayed on the guide, and on ItemAdvisor's Bag advice page, until reload.
- **Fix:** with no route, `A.Update` gets an empty list.

## Checked, no change
- **Night Elf route 1-30 data.** `test_lg_route_audit.lua` already walks the chain for a priest (prerequisites,
  levels, log size, nothing taken twice). This review added a scratch audit of every pick-up and hand-in NPC and
  spot against QuestDB, with Darnassus steps placed on the city map:
  - every spot is within 3 map-% of a QuestDB spawn of its giver or ender;
  - the 4 name differences are all QuestDB listing another giver of the same quest (Seek Redemption!,
    Teldrassil from the Oracle Tree Bark, the Jai'vhanel poster) or another spawn of the same object (Silver of
    the Waves);
  - no work or pick-up comes after its own hand-in.
- **Death spot** (`X.DeathEvent`, `X.ClearIfAlive`, `X.SavedCorpse`): saved outdoors only, cleared on
  PLAYER_UNGHOST, or on PLAYER_ALIVE once you're neither a ghost nor dead a second later. It is used only while
  a ghost and only when the game gives no corpse position.
- **Boats** (`P.BoatTimes`, `P.BoatLearn`, the "On the boat" hold): the wait, the ride and the epoch arithmetic
  are consistent with Boats.lua's arrive/depart times, including a stay that wraps past the loop's start.
- **Skip and undo:** `SkipStep`, `X.SkipQuest` (with follow-ups), `UndoSkip` and `UndoAllSkips` keep
  `skipHistory` and the saved skips in step. Nothing caches the skip tables, so replacing them in
  `UndoAllSkips` is safe.
- **ItemAdvisor_Judge interaction:** it is called in `pcall`, its nil means "ask again", and only `upgrade`,
  `gain`, `percent`, `level` and `reason` are read. The guide's list goes to other helpers as copies.

## Rule checks

| Check | Result |
|---|---|
| Hooks of Blizzard functions, writes to Blizzard frames, tables or globals | **Pass.** No `hooksecurefunc` or `HookScript`. Ahead.lua makes only its own `LevelGuideAheadFrame` and `LevelGuideAheadTooltip`, and only on the first click. |
| Map canvas pins | **Pass.** No `AddDataProvider` or `AcquirePin`. |
| `COMBAT_LOG_*` or CallbackEvent registration | **Pass.** Each of the 29 events was checked against the uisrc2 API documentation: all exist and none has `CallbackEvent = true`. Ahead.lua registers no events. |
| Chat output | **Pass.** No `print` or `AddMessage`. |
| Automation | **Pass.** `C_Map.SetUserWaypoint` and `C_SuperTrack.SetSuperTrackedQuestID` run only from a step click. Ahead.lua only reads; it never accepts, chooses or equips anything. |
| Secret values | **Pass.** In Ahead.lua, `UnitAffectingCombat` and `C_Item.GetItemInfo` go through `Safe()`, and so does the new `UnitLevel` read in `X.AheadQuests`. |
| Combat | **Pass.** Ahead.lua doesn't judge in combat. The row and window are plain frames and our own tooltip. |
| Lua limits | **Pass.** No new main-chunk locals (the changes are inside `X.AheadQuests` and `A.Update`). The harness loads the file (`test14.lua` and every LevelGuide test). |
| Performance | **Pass.** At most 25 quests are judged, every 5 s (every 1 s while items load), and ItemAdvisor caches its verdicts. |

## Not fixed (NIT)
- **NIT, `LevelGuide.lua` `Build`:** a right-click on the "Upgrade ahead" row also opens or closes the window. It
  has the same `OnClick` for both buttons, so nothing goes wrong.
- **NIT, `Ahead.lua`:** `QuestRewards.lua` doesn't say which rewards are a choice. A quest that gives two items
  shows only the one with the bigger gain.
- **Not a LevelGuide file:** `dist\ForeverGuides\LevelGuide\` is a packaged copy, and it doesn't have these fixes
  until the package is built again.

## Needs the game (left unfixed)
1. **Worn gear in instances:** confirm that `GetInventoryItemLink("player", slot)` is secret in a dungeon, as
   ItemAdvisor assumes. Fix #3 keeps the line either way.
2. **Crossing continents by boat:** still open from the final review. Does `ZONE_CHANGED_NEW_AREA` end the "On the
   boat to ..." hold early?
3. **Reward data:** spot-check a few ATT rewards against the quest window on Forever (for example Mist and
   Gnarlpine Corruption). The tooltip already warns that some Forever rewards changed.
4. **PLAYER_ALIVE after a release:** confirm that one second later `UnitIsGhost` reads true, so the death spot
   isn't cleared.

## Summary
LevelGuide passes every rule check: no hooks, no map canvas pins, no CallbackEvents, no chat output and no
automation, and the new code is secret-safe and inactive in combat. The Night Elf route 1-30 matches QuestDB's
givers, enders and spots. Four bugs in the new "Upgrade ahead" feature were confirmed with failing tests and
fixed:
- passed hand-ins were listed;
- hand-ins of skipped pick-ups were listed;
- the line went blank while ItemAdvisor couldn't read worn gear;
- a stale upgrade stayed after the route ended.
