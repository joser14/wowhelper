# Taint / blocked-action audit (2026-11-09)

Scope: every helper folder except `MapPins\` (fixed separately). Static review plus grep for data providers,
pin/frame pools, ScrollBox, Settings, AddonCompartment, EventRegistry/Menu/EditMode, hooks, writes to Blizzard
frames/tables/globals, secure templates, protected calls, combat-only APIs and secret values. API facts checked
in `uisrc2` (SuperTrackManager, Map, ForbiddenAspectConstants, SimpleScriptRegion*, FrameAPINamePlate docs).

Installed error log (`!ForeverHub.lua`, ErrorLogDB): the only entries blaming our suite are
`ForeverWorld tried to use UNKNOWN()` (MapPins, being fixed elsewhere), the old QuestTracker aura taint (fixed
earlier) and an old ItemAdvisor nil index (2026-11-04). The rest come from VeritasUI and RXPGuides.

Risk scale: **real** (will or did cause a block/taint), **possible** (can happen in an edge case), **fine**.

## Fixed in this pass

| # | File:line | Risk | Finding | Fix |
|---|---|---|---|---|
| 1 | RareWatch.lua:749, QuestMobs.lua:733, Builds.lua:744 | real | `SlashCmdList = SlashCmdList or {}` re-assigned Blizzard's global from addon code, tainting the variable Blizzard's chat-command code reads. | Lines deleted by the lead. Grep confirms no other assignment to `SlashCmdList`, `UISpecialFrames`, `StaticPopupDialogs`, `UIPanelWindows`, `Settings`, `EventRegistry` or `hash_*` remains in helper code. **`dist\` still has the old lines: rebuild.** |
| 2 | ForeverHub\ForeverHubExtras.lua:356 (RegisterSettings) | possible | The Options page was registered at PLAYER_LOGIN even when that was a /reload in combat, so Blizzard's Settings code would meet our category during lockdown. | Registration waits for PLAYER_REGEN_ENABLED when in combat (`settingsPending`). The canvas stays our own parentless frame with only UIPanelButtonTemplate buttons, no OnCommit/OnDefault/OnRefresh, no proxy settings, no `Settings.OpenToCategory`. |
| 3 | ForeverHub\ForeverHub.lua:1611 (Start) | possible | `C_CVar.SetCVar("accessibilityScreenNarrationEnabled")` ran at PLAYER_LOGIN even in combat; some CVars are refused to addons in lockdown and the game blames the addon. | `NarrationOff()` defers to PLAYER_REGEN_ENABLED in combat. |
| 4 | QuestTracker\QuestTracker.lua:1230 (OnTick) | possible | `ObjectiveTrackerFrame:GetAlpha()` was compared without `Safe()`; a secret alpha would error every second (OnTick isn't pcall'd). | `Safe()` around the read. SetAlpha stays (accepted cosmetic). It runs no Blizzard Lua and isn't a restricted method in combat. |

Regression tests: `tests\test_hub_extras2.lua` section 8 covers combat login: no Settings registration and no CVar
write until combat ends, then each exactly once. `tests\test_tracker_extra.lua` (end) covers tracker cleared
with SetAlpha only and a secret alpha left alone, in and out of combat. Full suite: same results as the baseline,
except test_mappins, which now passes (the other worker's change). 11 old failures unchanged.

## Reviewed, left as is

### ForeverHub / ForeverHubExtras
- Hearthstone `SecureActionButtonTemplate` (Extras:451-496): created, attributes set, shown/hidden and moved only out
  of combat (`hearthPending` queue). It's anchored to UIParent with absolute numbers, not to the side panel, so the
  panel stays unprotected. **fine**
- `panel:HookScript` (Extras:508) is on the hub's own panel. **fine**
- AddonCompartment funcs (toc + Extras:94-113): toggle our own frame and use our own tooltip. **fine**
- Bindings.xml: calls our functions only, which show our frames or set a user waypoint. **fine**
- `table.insert(UISpecialFrames, "ForeverHubFrame")` (ForeverHub:990), also ForeverHelper:293: the supported
  pattern. Blizzard runs CloseAllWindows through securecall before ClearTarget on Escape. **fine**
- WrapCommands (ForeverHub:1558): wraps only our own `SlashCmdList` keys (test_hub_nav checks that READYCHECK
  isn't wrapped). **fine**
- Minimap button parented to `Minimap` (ForeverHub:1385): plain button with no secure children. **fine**
- ButtonFrameTemplate hub window and UIPanelScrollFrameTemplate: our own frames. **fine**

### QuestTracker
- Secure item buttons (830-898) are children of `QuestTrackerPanel` and anchored to rows, so the panel and rows
  count as protected in combat. Every Show/Hide/SetPoint/SetHeight/SetAttribute on them is behind
  `InCombat()`: Layout, ApplyCollapse, PlaceDefault, collapse, drag start, fold. Drag ends on PLAYER_REGEN_DISABLED.
  In combat only text, texture visibility, bar width, vertex colour and `CooldownFrame_Set` run. **fine**
  (test11/test_tracker_extra/test_review_fixes_c guard this.)
- `C_SuperTrack.SetSuperTrackedQuestID` in ToggleFocus (731) has no combat guard. It's a C API (SuperTrackManager
  docs: no restriction, only "SecretArguments = AllowedWhenUntainted"), and Blizzard handles the event
  untainted. **fine**
- `ShowQuestComplete` (761): the same C call Blizzard's tracker makes. **fine**
- No QuestMapFrame_*/OpenQuestLog calls (the earlier aura-taint cause), and no hooks on the tracker. **fine**

### ItemAdvisor / WindowBadges
- Badges and marks are textures or frames on our own full-screen overlays (`ItemAdvisorOverlay`, `WindowBadgesOverlay`,
  mouse off), anchored to Blizzard bag/reward/merchant/trainer buttons. That anchoring makes our frames depend on
  theirs, never the other way. Nothing is created on, hooked, or written into Blizzard frames. The old bag
  `HookScript("OnShow")` is gone (an OnUpdate watcher replaced it). Painting happens only out of combat, and
  badges hide on PLAYER_REGEN_DISABLED. **fine**
- WindowBadges reads `ClassTrainerFrame.ScrollBox` through `GetFrames`/`ForEachFrame`/`GetElementData`. These are
  read-only Blizzard getters that do no lazy writes. No element initializer or data provider is ours. **fine**

### QuestMobs
- Marker frames are anchored to `C_NamePlate.GetNamePlateForUnit` plates with `pcall(SetPoint)`. The plate is never
  changed, nothing runs in instances, and a refused anchor falls back to the list window. Markers have no scripts,
  so the "UntrustedLayoutScriptExecution" forbidden aspect (it propagates to frames anchored to the plate)
  doesn't matter. **possible**: needs an in-game check in combat.

### Tooltips / PriceMemory / ItemFinder / ItemAdvisor tooltips
- `TooltipDataProcessor.AddTooltipPostCall` runs through Blizzard's `securecallfunction` (visible in the VeritasUI stack
  in the log). Only AddLine/AddDoubleLine are used, no money frames, and nothing is written into the tooltip
  table. Unit lines are skipped in instances, and reads go through Safe(). **fine**

### !ErrorLog
- `seterrorhandler` wrapper (!ErrorLog:58): our function runs whenever Blizzard code calls `geterrorhandler()(err)`.
  That's the same approach as BugGrabber, and it's needed to log errors. It records only and passes on to the
  previous handler. **possible** (low): if a "tainted by !ErrorLog/!ForeverHub" message ever appears, this is
  the place to look.

### Others (ForeverWorld: DeathNotes, Landmarks, RareWatch; Guides; Character; Bags)
- Only the shared ForeverWaypoint block calls the map: `C_Map.SetUserWaypoint`, `C_SuperTrack.SetSuperTrackedUserWaypoint`
  and `ClearUserWaypoint`. These are C APIs with no combat restriction in the docs, wrapped in pcall, with a
  plain watcher frame. **fine**
- No protected calls anywhere (CastSpell*, UseItem*, TargetUnit, ClearTarget, Pickup*, Buy/Sell, Accept/Complete
  quest, RunMacro, SetBinding, OpenToCategory, Show/HideUIPanel): grep is empty.
- No EventRegistry/CallbackRegistry, Menu/UIDropDownMenu, EditMode, ScrollBox data providers, frame pools,
  SetPassThroughButtons/SetPropagate*, EnableKeyboard/OnKey scripts. EnableMouse is used only on our own windows.
- `UIErrorsFrame:AddMessage` fallbacks (BagCheck, QuestCheck, ...) run only without the hub. AddMessage is a C method. **fine**
- Other global writes are our own names (SavedVariables, `ForeverCharacter*`, `ForeverHubStatus`, `*Data`).
  Uppercase hits like `ITEM_MOD_*` and class names are fields in local table constructors.

## Needs an in-game check
1. /reload in combat, then leave combat: the "Forever Hub" page appears in Options > AddOns, narration stays off,
   and no blocked-action entry appears.
2. Open Options (Esc > Options > AddOns > Forever Hub) during combat. No "blocked" message should appear.
3. Fight with QuestTracker showing a quest item. Click the item, fold, drag: there should be no block, and layout
   changes wait for combat to end.
4. Fight a quest mob with nameplates on (QuestMobs markers). Check for no "QuestMobs" blocked action or error.
5. After the MapPins fix and a rebuild of `dist\`, check the Errors page for any new "Blocked action" line.

## Summary
Apart from MapPins (handled separately), the suite's one real taint source in this pass was the
`SlashCmdList = SlashCmdList or {}` re-assignment in three addons, which the lead removed. It is still present
in `dist\`, so rebuild. Three smaller combat-time risks are fixed and covered by tests: Settings registration
and the narration CVar now wait for the end of combat, and QuestTracker's tracker-alpha read is
secret-safe. Secure buttons (hearth, quest items) are already handled carefully. The overlay badges and
nameplate markers only anchor our frames to Blizzard's. The remaining "possible" items are QuestMobs nameplate
anchoring and !ErrorLog's error handler. Both are standard patterns and need only an in-game check.
