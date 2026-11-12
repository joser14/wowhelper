# Full review: ForeverWorld (logic and code)

Scope: Landmarks, DeathNotes (with BreathWatch, LowWarn), RareWatch, MapPins (with Way), and the new AggroWatch,
Events and Nodes. Checked against research\BRIEF.md and the API docs in uisrc2 (client 1.60.1, interface 16001).
Earlier reviews (final_review_character_world.md, review6_*.md) are not repeated. Landmarks and RareWatch haven't
changed since the final review; DeathNotes changed only in the death recap (review 6b). Date: 2026-11-11.

## Fixed

### RISK (fixed): AggroWatch range reads had no combat guard of their own (AggroWatch.lua:137-180)

- **Claim.** `C_Item.IsItemInRange` and `CheckInteractDistance` were guarded only by the check at the top of
  `Scan()`. `InRange()` and the exported global `AggroWatch_Measure` called them without any combat check.
- **Failure.** Anything that calls `AggroWatch_Measure` in combat reads ranges on a hostile unit, and so does any
  future caller. On modern clients that read is restricted for hostile units in combat (Retail 10.0.2 behaviour), and
  can raise the "blocked from an action" pop-up. It also happened when `InCombatLockdown()` couldn't be read: `Read()`
  returned nil, and `InCombat()` then treated an unknown state as out of combat.
- **Fix.** Added `RangeAllowed()`, which is called right before every `CheckInteractDistance` and every
  `IsItemInRange`. It lets a read through only when the `fighting` flag is clear, `InCombatLockdown()` answers exactly
  `false`, and `UnitAffectingCombat("player")` answers exactly `false`. Anything else (true, an error, a secret, a
  missing API) refuses the read, and the check returns nil.
- **Test.** `tests\test_full_world_aggro_guard.lua`. It failed before the fix with 7 range calls each under lockdown,
  under a player combat flag, and with an unreadable lockdown. It passes after.

**API docs.** In uisrc2, `IsItemInRange` (ItemDocumentation) and `CheckInteractDistance` (PlayerScriptDocumentation)
carry only `SecretArguments = "AllowedWhenUntainted"`. Neither has `HasRestrictions`, `IsProtectedFunction` or
`SecretWhenInCombat`. So the docs don't encode the combat restriction. The guard is defensive, and the restriction
itself has to be confirmed in game.

**Event ordering.** No read can happen in combat on the scan path either:
- `Scan()` checks `InCombat()` live on every tick, through `InCombatLockdown()` and `UnitAffectingCombat("player")`, not only through the cached flag.
- `PLAYER_REGEN_DISABLED` sets `fighting` and removes the OnUpdate in the same handler. Lockdown begins only after that event has been dispatched.
- One scan runs in a single Lua execution, so the combat state can't change in the middle of it.
- A pull by your own spell starts combat only when it lands, and that fires `PLAYER_REGEN_DISABLED` before the next OnUpdate.
- After a /reload in combat, `fighting` is seeded from `InCombatLockdown()` at login.

## Checked, no bug

- **AggroWatch maths.**
  - Radius: 20 ± the level difference, clamped 5-45, with "??" = +10.
  - Grey levels: the Classic `GetGrayLevel` table.
  - Band midpoint less the radius gives the gap; `high <= radius` means you're inside.
  - Nameplate tokens come only from `NAME_PLATE_UNIT_ADDED/REMOVED`, read through `Safe()`, and are bounded at 40. They're re-seeded on `PLAYER_ENTERING_WORLD`.
  - Throttle: one scan every 0.25 s, at most 20 units, and a single read for a unit past 40 yd. Scans build no tables.
  - The scan stops by itself when nothing is in view, and the hub's Off switch hides the line and stops the scan.
- **Events.**
  - `C_Calendar.OpenCalendar` is called only from `RequestCalendar()`, which checks `IsOff()`, then `InCombatLockdown()`, then a 300 s throttle. It runs from the login timer (5 s), the page, and the hub switching it back On (the hub writes `off` before it notifies).
  - Reads: `GetMonthInfo(0)`, `GetNumDayEvents(offset, day)` and `GetDayEvent(offset, day, index)` all match the docs, and `CalendarDayEvent.calendarType`/`startTime`/`endTime` exist. Offsets count from the month the calendar is viewing, and that month is never changed.
  - Dates: `DayNumber` uses the civil-from-days formula, and leap years are handled. An ongoing holiday is caught from today's events.
  - Faire location: from the title if it names the place, else alternating monthly from Elwynn in Nov 2026, else the published 9-16 Nov 2026 entry.
  - Tooltip line and side-panel line both stop when Off.
- **Nodes.**
  - `UNIT_SPELLCAST_SENT`/`SUCCEEDED` payload positions match the docs (target 2nd, spellID 4th/3rd). Registering for the player only avoids reading a secret unit token.
  - Spells are matched by Classic ID, else by localized name.
  - Position must be plain, inside 0-1, and not 0,0.
  - Fishing is kept only when `LOOT_OPENED` follows within 35 s.
  - Merging uses `C_Map.GetMapWorldSize` (it exists) at 15 yd.
  - Bounds: 40 spots per kind per map and 40 maps. The oldest is evicted, and the data is cleaned at login.
  - The layers go to MapPins through `MapPins_RegisterLayer`, so they're our overlay frames. The version stamp is polled once a second.
  - Off empties the layer at once (`records` returns nothing, and MapPins checks `IsOff("Nodes")`).
- **MapPins notes.**
  - All notes UI is made at load, as children of our UIParent overlay (hidden with the map, MapPins Off or the layer data gone). `HideWorld` closes the dialog and panel, and clears edit-box focus.
  - Text is cleaned (one line, no `|`, 60 letters). Notes are capped at 200, and malformed saved notes are dropped at login.
  - A waypoint is set only from a click on a note row.
- **MapPins edge arrow.** It's a child of Minimap, hidden with the minimap pins and when MapPins is Off. Its rotation, `atan2(-x, y)`, is correct for art that points up. Its `ways` table is replaced only when the target changes.
- **MapPins exploration.** Sampling runs only out of combat with the layer on (review 6c). `Retarget` makes a table only when the target changes.
- **DeathNotes recap.** `C_DeathRecap.GetRecapEvents/HasRecapEvents(recapID)` take a nilable `recapID` in the docs, so calling them with no argument is valid. Every field goes through `Safe()`. 5 hits and 40 letters are kept per death. `lastRecap` stops an old recap from being applied to a new death.
- **Rules.**
  - Every registered event in the 7 folders was checked against uisrc2: all exist, and none has `CallbackEvent = true`.
  - No `AddDataProvider`/`AcquirePin`, no `hooksecurefunc`, and no `print`/`AddMessage`; every `Print` goes to `ForeverHub_Receive`.
  - No targeting, casting, tracking or CVar writes. Waypoints are set only from clicks.
  - No Blizzard frame writes. Events' tooltip line uses `TooltipDataProcessor.AddTooltipPostCall`, the pattern Tooltips already uses.

## NIT (not changed)

- **Nodes.lua:535.** `IsFishingLoot` isn't in uisrc2, neither in the docs nor in Blizzard code. Without it, any loot window within 35 s of a fishing cast keeps the spot, a bag-opened clam included. The spot kept is still where you fished. `LOOT_OPENED`'s second payload, `isFromItem`, could skip bag loot.
- **Events.lua:597.** If you're in combat 5 s after login, the calendar request is skipped and isn't retried until the page opens or the hub switches Events On again.
- **AggroWatch.** Target and mouseover can be the same unit as a nameplate and get range-checked twice in one scan. That costs extra reads only.

## Needs the game

1. AggroWatch: out of combat, `C_Item.IsItemInRange(item, "nameplateN")` on a hostile mob returns true or false (not nil or refused), with no "blocked" pop-up. The line hides at once on a pull.
2. MapPins notes bar: the bar sits 8 px in from the visible map's bottom-right corner, one strata above the map. The Mainline map puts its quest-log side-panel toggle at the canvas container's bottom-right corner. If Forever's map shows it there, the "Notes" button covers it, and the bar should move about 40 px left. uisrc2 has no WorldMapFrame source, so this can't be checked here.
3. Events: what the Faire's calendar title says (whether it names Elwynn or Mulgore), `calendarType == "HOLIDAY"` for it, and the real dates against Data.lua's 9-16 Nov 2026.
4. Nodes: the herb and mining casts fire `UNIT_SPELLCAST_SUCCEEDED` with the listed IDs or names, the SENT target is the node's name, and whether `IsFishingLoot` exists.
5. DeathNotes: `GetRecapEvents()` with no ID returns the latest death, and its field names (`sourceName`, `spellName`, `amount`, `timestamp`, `environmentalType`).

## Summary

The seven ForeverWorld helpers keep to the rules:
- no canvas pins
- no CallbackEvent or COMBAT_LOG registration
- no hooks, chat output or automation
- bounded saved data
- Off switches that hide everything

One RISK was fixed. AggroWatch's hostile-unit range reads now each sit behind their own strict combat guard, so neither the global `AggroWatch_Measure` nor an unreadable combat state can make a range read in combat. A failing-first test covers it. Three NITs are noted. Five items need checking in game, the most important being the notes bar against the map's own bottom-right button.
