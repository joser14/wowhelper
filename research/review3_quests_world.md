# Review 3: quests and world helpers (2026-11-10)

**Scope.** These helpers were read end to end:
- AutoQuest, !ErrorLog, ForeverHub (ForeverHub.lua, ForeverHubExtras.lua), ForeverHelper, QuestTracker, QuestCheck,
  ZoneLevels and QuestMobs;
- Landmarks, DeathNotes (with BreathWatch.lua), RareWatch and MapPins (with Way.lua).

LevelGuide wasn't touched; another worker is editing it.

**How.** Earlier findings in `review_2026-11-10.md` and `taint_audit.md` aren't repeated here.
- Event payloads and APIs were checked in `uisrc2`: GossipQuestUIInfo, MIRROR_TIMER_*, QUEST_ACCEPTED,
  QUEST_DETAIL, GetMapLevels, GetAllTaxiNodes, GetVignettePosition and GetViewRadius.
- Each fix has a test that fails on the old code and passes on the new one.
- Full suite: `cd tests; .\runall.ps1` reports 0 failed.

## Confirmed and fixed

| # | Sev | File:line | What was wrong | Fix | Test |
|---|---|---|---|---|---|
| 1 | RULE | AutoQuest.lua:309 (OnDetail) | **A quest the game pushes by itself would be accepted.** OnDetail accepted any QUEST_DETAIL that had no player as the "npc" unit. A quest window opened by the game when you walk into an area (QuestIsFromAreaTrigger) passed that check. The owner's exception covers only windows the player opened. | Skip when `QuestIsFromAreaTrigger()` is true. The call goes through `Call()`, so a client without the function behaves as before. | `test_review3_autoquest.lua` 1 |
| 2 | BUG | AutoQuest.lua:321, 356 | The page credited quests to the wrong NPC. A quest started from an item read "Accepted X from \<last NPC you talked to\>". A finished quest completed from the tracker read "Turned in X to \<last NPC\>". The notes used the session's `lastNPC` instead of this window's giver. | The notes use the current `UnitName("npc")` and leave the name out when there's none. `lastNPC` is still used for "ignore" with no name. | `test_review3_autoquest.lua` 2, 3 |
| 3 | BUG | BreathWatch.lua:135 | **Drowning warnings stopped after the breath bar paused and resumed.** On `MIRROR_TIMER_PAUSE` with paused > 0, the timer was dropped. The resume (`MIRROR_TIMER_PAUSE` with 0, no new START; payload checked in UnitDocumentation) was ignored, so there was no warning for the rest of the dive. A timer that started paused was never watched. | A draining timer's warning state is kept in `draining` until STOP or a refill. A resume watches it again, and warnings already given aren't repeated. | `test_review3_breathwatch.lua` |
| 4 | BUG | RareWatch.lua:216 (PlayAlertSound) | **RareWatch played its raid-warning sound when it shouldn't.** This happened with RareWatch switched Off on the Manage page, whose text promises it "keeps running quietly". It also happened with the hub's Alerts > Sound off, whose text lists "a rare nearby". The hub already blocked the pop-up and the flash, but not RareWatch's own sound. | `SoundAllowed()` checks `ForeverHub_IsOff("RareWatch")` and `ForeverHubDB.alerts.sound == false`. Both are read only. Rares are still remembered. | `test_review3_rarewatch.lua` |

`tests\test_autoquest.lua` now lists `QuestIsFromAreaTrigger` as an optional global it may read.

## Rule checks, all clean

- **Hooks:** no hook of a Blizzard function. The only `HookScript` is on the hub's own panel.
- **Blizzard tables and globals:** no writes, apart from `UISpecialFrames` inserts (kept, see the earlier review) and
  our own `SlashCmdList` keys.
- **Map pins:** no canvas pins. MapPins uses its own overlay and minimap buttons, made at load.
- **Events:** no COMBAT_LOG or CallbackEvent registration. DeathNotes says so in a comment.
- **Chat:** no chat output. The fallbacks without the hub write to UIErrorsFrame only.
- **Accept and turn-in:** only AutoQuest calls AcceptQuest, CompleteQuest, GetQuestReward or Select*Quest. The
  sweep in `test_autoquest.lua` covers every other helper.
- **AutoQuest skip rules**, traced:
  - pause key, combat, the hub's Off switch and ignored NPCs, all through `Blocked()`;
  - gold, on both the progress and the reward page;
  - repeatable, daily or weekly: gossip `repeatable`/`frequency`, the greeting's `GetAvailableQuestInfo`, and on
    the window `C_QuestLog.IsRepeatableQuest`, `QuestIsDaily` and `QuestIsWeekly`;
  - gray: `isTrivial`, then `IsQuestTrivial`;
  - several rewards: more than 1 choice, or a secret count;
  - player-shared: `UnitIsPlayer("npc")` must be exactly false;
  - auto-accept quests and quests hidden by Blizzard's UI.
- **AutoQuest loops:** turn-ins come before pick-ups, and the 30 s per-quest `tried` table stops repeats.
- **AutoQuest gossip argument:** the gossip select passes the GossipQuestUIInfo `questID` (Nilable = false in the
  docs) and falls back to the list position only if the call errors.

## Suspicions (not changed): the in-game check that settles each

1. **DeathNotes.lua:637: is the killer lost when you die?**
   - `PLAYER_REGEN_ENABLED` clears `lastFoe`. If the game sends REGEN_ENABLED before `PLAYER_DEAD` when you die,
     the remembered foe is gone before `RecordDeath`.
   - The death then has a killer only if your target is still hostile at that moment, and the target memory was
     added for exactly the case where it isn't.
   - **Check:** die to a mob while targeting it, with something that logs event order (or watch whether the
     Deaths page shows "killed by").
   - If it doesn't, clear `lastFoe` on REGEN_ENABLED only once `UnitIsDeadOrGhost("player")` is false a moment
     later (`C_Timer.After(1, ...)`).
2. **Landmarks.lua:609 (EndFlight): is a flight never closed?**
   - EndFlight runs only on `PLAYER_CONTROL_GAINED` and returns early if `UnitOnTaxi` is still true.
   - If the taxi flag clears a moment after control comes back (the start side already allows for that), the
     flight is never closed. The page shows "In flight: ... so far" until a later control gain, which could then
     save a wrong time if you stand near a known flight master.
   - **Check:** fly once. "Flight time learned: A to B" should appear on landing, and the Places page should stop
     saying "In flight".
   - If it doesn't, retry EndFlight with `C_Timer.After(1, EndFlight)` when `OnTaxi()` is still true.
3. **Way.lua:35: does `/way <zone>` find every zone?**
   - Zone names come from `C_Map.GetMapChildrenInfo(947, Zone, true)`. Forever-only zones (Zephras Isle 2521,
     Riverglades 2548) may not sit under map 947.
   - **Check:** `/way Zephras 50 50` and `/way Riverglades 50 50`.
   - If either says "No zone or city called", add MapPins' `CLASSIC_ZONE` names as a fallback.
4. **AutoQuest player-shared detection:** this assumes the "npc" unit is the sharing player on a shared quest's
   detail page.
   - **Check:** have a party member share a quest. It must not be accepted.
   - If it is, also skip when `UnitInParty("npc")` or `UnitIsPlayer("questnpc")` is true. This was already on
     the STATUS list.
5. **RareWatch UNIT_HEALTH:** registered for every unit, though only the target's matters. The handler returns at
   once, so this is a performance NIT.
   - **Check:** none needed.
   - If it shows up in profiling, use `RegisterUnitEvent("UNIT_HEALTH", "target")`.

## NITs (not changed)

- MapPins.lua:1162: the "unknown layer" hint doesn't list `givers`, which `off givers` does accept.
- RareWatch/MapPins: while a rare's marker stays on the minimap, every VIGNETTES_UPDATED moves its `seen` stamp.
  MapPins' signature then changes every second and it rebuilds all layers once a second. That's cheap, but
  avoidable: stamp only when `seen` moves by 60 s or more.
- BreathWatch's alarm ignores the hub's Sound switch on purpose: it's a safety warning, and the Sound text doesn't
  list it.

## Summary

Four confirmed problems are fixed, each with a failing-first test:
- AutoQuest could accept a quest window the game opened by itself. It now leaves area-trigger quests alone.
- AutoQuest's page credited item-started quests and tracker turn-ins to the last NPC you talked to.
- BreathWatch went silent for the rest of a dive after the breath bar paused and resumed.
- RareWatch's own alarm ignored both the Manage page's Off switch and the hub's Sound switch.

The rest of the scope traced clean against the owner's rules. Five suspicions need a short in-game check: the
killer memory on death, flight landing, `/way` for Forever-only zones, party-shared quests and UNIT_HEALTH cost.
