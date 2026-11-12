# Review 6a: hub Off switch (eb2b0a0), hub buttons (1e8faa6), LevelLog Fights (ce49129)

Scope: the code these three commits added or changed in ForeverHub, ForeverHelper, QuestTracker, QuestMobs,
ItemAdvisor, WindowBadges, ZoneLevels and LevelLog. API claims checked against uisrc2
(`Blizzard_APIDocumentationGenerated__DamageMeterDocumentation.lua`, `...DamageMeterConstantsDocumentation.lua`).
Test: `tests\test_cr6a_tracker_off.lua` (written first, failed 5 checks, passes after the fix).

## Fixed

### 1. BUG: QuestTracker Off left Blizzard's tracker invisible (QuestTracker.lua, ApplyHubSwitch)
- Claim: a player who made Blizzard's tracker clear (right-click on our header, `db.keepBlizzard = false`) and
  then switches QuestTracker Off on the Manage page has no quest tracker on screen at all.
- Why: Off hides our panel and stops `OnTick`, but Blizzard's `ObjectiveTrackerFrame` stays at alpha 0, which only
  a /reload resets. (At login while Off it was fine: alpha starts at 1 and nothing clears it.)
- Fix: the Off branch sets `ObjectiveTrackerFrame:SetAlpha(1)` when `not db.keepBlizzard` (alpha only, the same
  write `ToggleBlizzardTracker` already makes, out of combat because the branch never runs in combat). On calls
  `WatchBlizzardTracker` again, which clears it. With `keepBlizzard` (the default) nothing is written.

### 2. BUG (minor): quest sounds kept playing after Off in combat (QuestTracker.lua, RunSoundScan)
- Claim: switched Off in combat, the panel rightly waits for PLAYER_REGEN_ENABLED (secure item buttons), but
  `hubOff` stays false until then, so objective/complete sounds still play for the rest of the fight.
- Fix: `RunSoundScan` also returns when `HubSaysOff()`; it drops `soundSnap`, so nothing from the Off period is
  played later. Test: no QuestTracker sound after an in-combat Off, panel hides on REGEN_ENABLED, nothing
  protected toggled in combat.

## Checked, no bug found

- Off then On state: ForeverHelper (`wantShown`, saved on logout while Off), LevelLog (`reopenWhenOn`), QuestTracker
  (position and fold kept, `readySeen`/`soundSnap` reset so nothing is announced late), QuestMobs (plates marked
  dirty, list window re-placed), ItemAdvisor and WindowBadges (overlay is shown by default and only hidden by the
  switch, so `not overlay:IsShown()` is a correct test) all restore the right state. A window you closed stays closed.
- Combat: only QuestTracker's panel holds secure children; it defers through `hubSwitchWaiting` and
  PLAYER_REGEN_ENABLED. QuestMobs markers/window, ItemAdvisor and WindowBadges overlays are plain frames.
  At login while Off, `panel:Hide()` runs before any item button exists, so a /reload in combat is safe.
- Login order: every bundle's toc has `OptionalDeps: !ForeverHub` (unbundled: `ForeverHub`), and
  `ForeverHub_IsOff` falls back to the `ForeverHubDB` global before the hub's PLAYER_LOGIN, so ForeverHelper's
  ADDON_LOADED read is correct. Without the hub every `HubSaysOff` is false. Helper names match `HELPERS`
  (WindowBadges registers under `SOURCE = "WindowBadges"`).
- Hub buttons (1e8faa6): Dungeons `log`/`wish`/`groups` reach `R5.Page` and print lines (page views);
  `window` toggles `R5.ToggleWindow` and is an `action`; ItemFinder `bags` reaches `ItemFinder_ShowBags` and is
  an `action`. `ViewClicked` never re-renders the page for an action (no reopen loop); action views can't become
  the default view.
- C_DamageMeter (ce49129): read 1 s after PLAYER_REGEN_ENABLED, skipped when `InCombatLockdown()`, retried twice
  when anything is secret. Every number, table and list passes `Safe()` before compare/arithmetic; FontStrings get
  only our stored plain numbers. Enum fallbacks match the docs (Current = 1, DamageDone 0, HealingDone 2,
  DamageTaken 7). DPS/HPS and session rates guard `duration > 0`; per-fight taken divides by `session.n > 0`.
  History capped at 20 (`Fights()` trims); `fights` is a string key in the character record and nothing iterates
  that record expecting only level numbers. No new event registration, no `ResetAllCombatSessions`.
- Rules: no Blizzard hooks, no map canvas pins, no COMBAT_LOG_* or CallbackEvent registration, no new chat output
  or automation in these commits. The only Blizzard write is the alpha above (existing, accepted pattern).

## NITs (not changed)

- LevelLog Fights: a fight with no readable duration adds its damage to the session total but no time, so the
  session "per second in combat" can read high. The duplicate check (same d/h/tk/s as the last fight) could in
  theory drop a genuinely identical second fight.
- LevelLog OnSwitch On: `window:Show()` already runs `RefreshWindow` through OnShow; the extra call is redundant.

## Needs the game

- Whether `GetCombatSessionFromType(Current, ...)` still holds the fight just ended 1 s after combat, or the
  newest-ID fallback is what works; whether the meter must be enabled in Edit Mode to track (`IsDamageMeterAvailable`).
- That `ObjectiveTrackerFrame:SetAlpha(1)` on Off brings Blizzard's tracker back without its own refresh.

## Summary

Two QuestTracker bugs in the Off switch were confirmed by a failing test and fixed: Off no longer leaves the
player with no tracker when Blizzard's was made clear, and Off in combat silences quest sounds at once while the
panel itself still waits for combat to end. The rest of the Off/On wiring, the new hub buttons and the
C_DamageMeter Fights card hold up on reading and in tests; the damage meter's session behaviour after combat
still needs an in-game check.
