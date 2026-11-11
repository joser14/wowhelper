# Performance and robustness audit, 11 November 2026

Scope: every helper folder (source folders, not `dist\`). Checked: OnUpdate handlers and tickers, per-event work,
per-frame garbage, unthrottled BAG_UPDATE / UNIT_AURA / QUEST_LOG_UPDATE / unit-event handlers, nil guards on C_*
calls, secret values, combat and taint risks, SavedVariables growth and UIErrorsFrame writes.

Not edited (other workers): `LevelGuide\Routes.lua`, `QuestIDs.lua`, `Prereqs.lua`, `QuestRules.lua`, `Builds\`.
Findings there are listed with the fix to apply later.

Severity: BUG (wrong behaviour/error), RULE (owner rule), RISK (likely to cost or error on this client), NIT (minor).
Status: **FIXED** in this pass, or **OPEN** with the reason.

## Findings, most severe first

### 1. MapPins: world-map overlay made garbage every frame while the map was open (RISK, FIXED)
- `MapPins\MapPins.lua:981` `LayoutWorld` and `:1069` `Info.Update` run from the driver's OnUpdate on **every
  frame** while the world map is shown (`:1441`, the "between checks" branch).
- `LayoutWorld` built a 9-float `string.format` key every frame just to see that nothing moved; `Info.Update` built
  a fresh `parts` table every frame. With the map open at 60 fps that is 120 short-lived objects a second, and the
  collector runs while the player is looking at the map.
- Fix: the rectangle is compared as nine rounded numbers kept in `worldGeo` (same precision as the old
  `%.2f`/`%.4f` string; `worldGeometry` is now the "laid out" flag, cleared in the same places as before), and
  `Info.parts` is one table emptied and reused. Output is unchanged; the tests in `test_mappins.lua`,
  `test_r3_mappins.lua` and `test_r4c_mappins.lua` still pass.
- Left: `Info.Zone` (`:1036`) still builds its cache-key string and the coordinate strings per frame while the
  cursor is over the map. That is the visible text and is cheap; throttling it would make the cursor readout lag.

### 2. MapPins: minimap update allocated two tables ten times a second (NIT, FIXED)
- `MapPins\MapPins.lua:1374` and `:1395` (`UpdateMinimap`, 10 Hz for the whole session) built a throw-away
  `{ mapID, x, y }` record for your position and a 7-entry table for `table.concat` on every tick.
- Fix: both are scratch tables (`miniScratch.here`, `miniScratch.state`) refilled each tick; `here.world` is
  reset so `WorldOf` still recomputes your position every time. Same state key, same pins.

### 3. ItemAdvisor: bag watcher built a list four times a second, forever (NIT, FIXED)
- `ItemAdvisor\ItemAdvisor.lua:2152` `WatchFrames` runs every 0.25 s from login to logout and called
  `BagFrames()` (`:1906`), which allocates a new list (plus an empty `{}` when the container list is missing) on
  each call.
- Fix: `WatchBagFrame` (`:2144`) walks `ContainerFrameContainer.ContainerFrames` and `ContainerFrameCombinedBags`
  directly, with the same "repaint once when a bag window opens" rule. `BagFrames()` is kept for the repaint path,
  which runs only on demand. A shared list was rejected because `ScheduleRepaint` can run a repaint (and so
  `BagFrames`) inside the loop. Covered by `tests\test_perf_watch.lua`.

### 4. RareWatch: UNIT_HEALTH registered for every unit (RISK, FIXED)
- `RareWatch\RareWatch.lua:956` registered `UNIT_HEALTH` with `RegisterEvent`, so the handler ran for every
  nameplate, party member and pet on every hit, only to drop all but `"target"`. In a busy fight that is dozens of
  calls a second, each doing a `Safe()` and a compare.
- Fix: `RegisterUnitEvent("UNIT_HEALTH", "target")` (in pcall), with the old `RegisterEvent` as fallback on a
  client without `RegisterUnitEvent`. The handler is unchanged. Covered by `tests\test_perf_watch.lua`.

### 5. ItemAdvisor: full quest-log walk on every QUEST_LOG_UPDATE (RISK, OPEN)
- `ItemAdvisor\ItemAdvisor.lua:2296` calls `RebuildQuestItems` (`:484`) synchronously for every
  `QUEST_LOG_UPDATE`. That event fires for each kill and loot; each call walks the whole log, calls
  `GetQuestObjectives` per quest and allocates a new `questItems` list and an entry per item objective.
- Fix (not applied): set a dirty flag and rebuild at most once a second (or on the next tooltip / repaint that
  reads `questItems`). Left open because `tests\test_itemadvisor_extra.lua:101-115` expects the tooltip to change
  immediately after the event, so the change needs a lazy read in `QuestNeeding` and a test update, which is a
  behaviour change beyond this pass.

### 6. LevelGuide: arrow refresh builds strings 20 times a second (NIT, OPEN)
- `LevelGuide\LevelGuide.lua:5213` `UpdateArrow` runs every `K.ARROW_SECONDS = 0.05` (`:276`) from the guide's
  OnUpdate (`:5860`). Each run concatenates a target key (`:5244`), formats the yards/ETA text and calls
  `yardsText:SetText` (`:5297`) even when the text is the same, plus `Rebuild` of the whole route every 2 s.
- Fix (not applied): cache the last target fields and the last yards text and skip the concat / `SetText` when
  unchanged. Left open: `LevelGuide.lua` is at the 200-local limit and is being reworked by other workers; this is
  steady but small garbage (two strings per tick).
- Also `:6196` runs `X.CheckProgress` (`:2556`, a full quest-log and objective walk) on every QUEST_LOG_UPDATE.
  It allocates via `X.Objectives`; a 0.5 s debounce would be enough. Open for the same reason.

### 7. Builds: talent-panel watcher (NIT, OPEN, `Builds\` is off limits)
- `Builds\Builds.lua:1035` is an OnUpdate for the whole session (4 Hz) that loops the talent window names and calls
  `IsShown` in pcall. While a talent window is open, `PlacePanel` (`:969`) creates two closures per tick
  (`SafeCall(function() ... end)` at `:971-972`) and `:1019` one more on redraw.
- Fix: hoist those closures to file level (or read `UIParent:GetEffectiveScale()` through `pcall(UIParent.GetEffectiveScale, UIParent)`),
  and stop the OnUpdate when no talent window has been discovered. `DiscoverTalentWindows` (`:927`) walks all of
  `_G` on every ADDON_LOADED whose name contains "Talent": fine (rare), but it could stop after the first hit.

### 8. ForeverHub: side-panel stats refreshed every second while the panel is hidden (NIT, OPEN)
- `ForeverHub\ForeverHub.lua:1650` `OnTick` (ticker at `:1711`) always runs `RefreshStats` (`:1174`), which formats
  five lines and calls `LevelLog_KillsToLevel` and `LevelLog_ToSixty` (`:1152`) even when the panel is hidden.
  Rows are already skipped when hidden.
- Fix (not applied): `if panel and panel:IsShown() then Attempt(RefreshStats) end` plus a refresh in the panel's
  OnShow. Left open: the panel has no OnShow refresh today, so the change would show stale lines for up to a second
  after opening; needs a small UI change and a test.
- `:1450` the minimap-button drag OnUpdate is cleared only by OnDragStop. If the button is hidden mid-drag the
  OnUpdate keeps writing `db.angle` every frame until the next drag. NIT; fix: also clear it in OnHide.
- `:1081` `SaveSession` copies up to 200 sample tables on every XP gain (a kill). Small; could copy only on
  logout/reload, since PLAYER_LOGOUT already saves.

### 9. QuestMobs: per-frame tick (NIT, OPEN, by design)
- `QuestMobs\QuestMobs.lua:834` runs `Tick` (`:666`) every frame. With no nameplates it is a few comparisons.
  With nameplates whose result is pending (log changed, `READ_EVERY` not passed), `Allowed` (`:378`) re-runs its 4
  unit API calls per plate per frame until the cached result is 2 s old. Reads are capped at 3 per frame, and the
  cache (`MAX_CACHE` 200) is cleared when full. Acceptable; a 0.1 s gate on `Tick` would cut it further.

### 10. FoodCheck: UNIT_AURA handled without throttle (NIT, OPEN)
- `FoodCheck\FoodCheck.lua:369/393` correctly listens for the player only, then runs `CheckReminders` (`:274`) on
  every aura change. Each reminder does a `FindBuff` that may scan 40 buffs. With no reminders it returns at once,
  and `AurasReadable` makes it cheap in combat. A 0.5 s coalesce (like ReadyCheck's `Schedule`) would be safe.

### 11. WindowBadges: watcher runs when no window is open (NIT, OPEN)
- `WindowBadges\WindowBadges.lua:718` (`Watch`, set at `:773`) runs a few times a second for the whole session and
  walks the badge pool even when no merchant, trainer or reward window is open. Cheap (no allocation unless a window
  is open). Could clear the OnUpdate on `*_CLOSED` when nothing is open and set it again on `*_SHOW`.

### 12. Other tickers that never stop (NIT, OK)
All are cheap and gated; listed for completeness:
`ForeverHelper\ForeverHelper.lua:388` (1 s, only when its window is shown), `QuestTracker\QuestTracker.lua:1522`
(1 s, `OnTick` `:1333`), `Dungeons\Dungeons.lua:1358` (2 s, returns unless outdoors on a zone with an approximate
entrance), `ReadyCheck` / `FoodCheck` / `DeathNotes` / `ManaFull` / `BreathWatch` (5-30 s). `DeathNotes\LowWarn.lua:151`
is a one-shot OnUpdate that removes itself. ReadyCheck's `Schedule` (`:747`) makes one closure per scheduled run
(`:753`): negligible.

### 13. Rule notes seen during the audit (not performance)
- `QuestTracker\QuestTracker.lua:1339` sets `ObjectiveTrackerFrame:SetAlpha(0)` every second when Blizzard's
  tracker is visible. This writes to a Blizzard frame (owner rule 3), but it is a documented decision
  (`:1393-1398`: SetAlpha runs none of Blizzard's Lua, unlike Hide/Show) and has its own toggle. Not changed.
- `ForeverHub\ForeverHubExtras.lua:499` creates a `SecureActionButtonTemplate` hearth button; `SyncHearth` (`:515`)
  never creates, moves or shows it in combat (deferred to PLAYER_REGEN_ENABLED). OK.
- No helper registers `COMBAT_LOG_*` or any other `CallbackEvent = true` event (checked against every event doc in
  the client's API documentation: the 12 such events are the CLASS_TALENTS_SWITCH_*, COMBAT_LOG_*,
  ENCOUNTER_STATE_CHANGED, MINIMAP_PING and TOOLTIP_SHOW_ITEM_COMPARISON). Dungeons' `ENCOUNTER_END`,
  `BOSS_KILL`, `UNIT_DIED` and `PARTY_KILL` are ordinary events, and their payloads go through `Safe()`.
- No map canvas pins, no `hooksecurefunc`. The one `HookScript` (`ForeverHubExtras.lua:552`) is on the hub's own
  panel.

## Secret values and nil guards
Every unwrapped game read found by a sweep of `UnitHealth/Power/Level/XP/Money/GUID/Name`, `GetXPExhaustion`,
`GetInventoryItemDurability/Link`, `GetUnitSpeed` and the zone-text calls is either passed through `Safe()` on the
next line or tested with `issecretvalue` before use (`DurabilityWatch:30/92`, `LevelLog:156`, `RestGuard:33`,
`LevelGuide:5636`, `QuestMobs:397`, `RareWatch:710`). One truthiness test remains:
- `SupplyWatch\SupplyWatch.lua:162` tests `GetInventoryItemLink("player", AMMO_SLOT)` for truth without `Safe()`.
  A boolean test of a secret value is expected to be allowed, and the count after it is wrapped. NIT; wrap it in
  `Safe()` to match the rest.

The C_* functions used without an existence check (`C_QuestLog.IsQuestTrivial`, `ReadyForTurnIn`,
`GetQuestObjectives`, `GetTitleForQuestID`, `C_Map.GetMapInfoAtPosition`, `C_Minimap.GetViewRadius`,
`C_UnitAuras.GetBuffDataByIndex` and others) all exist in this client's API documentation, and their nil returns
are guarded (`or {}`, `type(x) == "table"`, `if position`).

## SavedVariables growth
All bounded: ErrorLog 50 entries, ForeverHub alerts 100 and session samples 200, DeathNotes 200 deaths, Landmarks
400 places (flight times are per node pair, bounded by the nodes you visit), RareWatch 300 rares, AutoQuest 12
recent / 100 ignored, PriceMemory 30-day expiry and 20 suffixes per item, LevelGuide spots 200 and `serverLevels`
reset per client build, QuestTracker `accepted` pruned at login, Dungeons `learnedNpcs` only for names matching a
known boss. Per-character tables (LevelGuide `done`/`marks`/`skips`, TrainerNotes `services`, ItemFinder bags)
are bounded by the game's own content. ForeverHelper's to-do list grows only by the player's own entries.
In-memory caches: `Tooltips.lua:200` `itemCache` keeps one small table per item ID hovered this session (bounded by
the items you see; NIT), QuestMobs clears its cache at 200, ItemAdvisor's verdict cache is capped at 2000.

## UIErrorsFrame writes
Exactly the five known ones, each only when the hub isn't loaded: `BagCheck.lua:271`, `DurabilityWatch.lua:54`,
`ProfessionCap.lua:138`, `QuestCheck.lua:61`, `SupplyWatch.lua:222`. Left as they are. No `print` or
`DEFAULT_CHAT_FRAME` writes in any helper.

## Summary
No error-level problems were found: no unbounded SavedVariables, no restricted events, no OnUpdate left running by
mistake, and the known UIErrorsFrame writes are the only ones. The real costs were per-frame garbage on the open
world map (MapPins), a session-long 4 Hz list allocation (ItemAdvisor) and an all-units UNIT_HEALTH registration
(RareWatch); those are fixed without changing what the player sees, with `tests\test_perf_watch.lua` added. The
largest remaining costs are synchronous quest-log walks on every QUEST_LOG_UPDATE (ItemAdvisor, LevelGuide) and
LevelGuide's 20 Hz arrow strings; each needs a small behaviour or test change, or touches files other workers are
editing, so they are left open with the fix described.
