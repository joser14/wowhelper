# Fight summary from C_DamageMeter: feasibility (round 5 #2)

Verdict: **feasible and clean**, so it was built (LevelLog window, "Fights" tab).

Sources (uisrc2): `Blizzard_APIDocumentationGenerated__DamageMeterDocumentation.lua`,
`...DamageMeterConstantsDocumentation.lua`, `...RestrictedActionsDocumentation.lua` / `...ConstantsDocumentation.lua`,
`...SimpleFontStringAPIDocumentation.lua`.

## The four conditions

| Condition | Finding |
|---|---|
| Readable after combat (PLAYER_REGEN_ENABLED) | `GetCombatSessionFromType`, `...FromID`, `...SourceFrom*` are `SecretWhenInCombat = true` (DamageMeterDocumentation:23, 41, 59, 79). The only addon restriction type is `Combat` ("the player is actively affecting combat", RestrictedActionsConstants:26). Out of combat the returns are plain. LevelLog reads 1 s after PLAYER_REGEN_ENABLED, skips the read when `InCombatLockdown()` is true, and retries twice (2 s apart) if anything is still secret. |
| No restricted or CallbackEvent registration | Nothing new is registered: only PLAYER_REGEN_ENABLED, already registered. The meter's own events (`DAMAGE_METER_COMBAT_SESSION_UPDATED`, `..._CURRENT_SESSION_UPDATED`, `DAMAGE_METER_RESET`) are `UniqueEvent`, not `CallbackEvent` (:133-154), but they aren't needed and aren't used. No COMBAT_LOG_* anywhere. |
| No secret arithmetic or comparison | Every number (`totalAmount`, `amountPerSecond`, `durationSeconds`, `sessionID`) and every table goes through `Safe()` (issecretvalue) first and is dropped when secret; the fight is then retried, then not recorded. `isLocalPlayer` is `NeverSecret` (:206) and is still checked through Safe. No secret value is ever passed to a FontString either: only our own stored plain numbers are shown. (SetText/SetFormattedText do accept secrets, `SecretArguments = "AllowedWhenTainted"`, SimpleFontStringAPIDocumentation:539-546, 664-671, but it isn't needed.) |
| No protected calls | No C_DamageMeter function is marked protected or restricted; `SecretArguments = "AllowedWhenUntainted"` only matters for secret arguments, and we pass plain constants (session type 1 = Current, meter types 0/2/7) or a plain session ID. `ResetAllCombatSessions` is never called (it would clear the player's own meter). |

## What is read
- `IsDamageMeterAvailable()` -> when false, nothing is recorded and the card shows `failureReason`.
- `GetCombatSessionFromType(Current, DamageDone / HealingDone / DamageTaken)`, own line by `isLocalPlayer`.
- If "Current" is already empty: the highest `sessionID` from `GetAvailableCombatSessions()` via `GetCombatSessionFromID`.
- Stored per character in `LevelLogDB[key].fights`, the newest 20 (older saves trimmed when read). Session totals
  (fights, time in combat, damage, healing, taken, per-second rates) are kept in memory since login.

## Hidden when Off
The card lives in LevelLog's window, which `ForeverHubOnSwitch.LevelLog` hides (and `LevelLog_OpenWindow` refuses to
open) when the hub switches LevelLog Off. Recording goes on, like the rest of LevelLog.

## In-game checks
1. `/dump C_DamageMeter.IsDamageMeterAvailable()` on Forever, and whether the meter must be switched on in Edit Mode
   for sessions to be tracked.
2. After a fight, `/dump C_DamageMeter.GetCombatSessionFromType(1, 0)`: does "Current" still hold the fight just
   ended (else the newest-ID fallback is used), and are the numbers plain 1 s after combat?
3. No "blocked from an action" pop-up and nothing in !ErrorLog after several fights, including in a dungeon.
