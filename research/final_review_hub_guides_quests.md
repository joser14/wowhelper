# Final review: !ForeverHub, ForeverGuides, ForeverQuests (LevelGuide excluded)

Scope: !ErrorLog, ForeverHub (+Extras, Bindings), ForeverHelper, ProfessionCap, ProfessionGuide, GoldGoal,
GoldGuide, Dungeons, QuestTracker, QuestCheck, ZoneLevels, QuestMobs, AutoQuest.
Tests: `tests\test_final_hub_views.lua`, `tests\test_final_hub_fixes.lua` (both failed before the fixes).
`tests\runall.ps1`: 0 failed.

## Fixed (confirmed in code, failing test first where the harness can show it)

1. **BUG — ProfessionGuide.lua (scanner OnEvent).** The 2-second scan throttle dropped events. TRADE_SKILL_SHOW often comes
   before the recipe list is filled, so the scan found nothing. The TRADE_SKILL_LIST_UPDATE that followed within 2 s was then
   thrown away, and a second profession window opened within 2 s was never read either.
   - Fix: an event inside the wait now schedules a single later read (C_Timer.After).
   - Test: `test_final_hub_fixes` A.
2. **BUG — ProfessionGuide.lua `CraftableNow`.** Once any one profession window had been read, the `craft` page stopped using
   guide steps for every profession, so professions never opened listed nothing.
   - Fix: the guide-step fallback now runs per crafting profession whose window hasn't been read. The hint names those
     professions.
   - Test: B.
3. **BUG — AutoQuest.lua `OnGreeting`.** In the old greeting window, a finished *repeatable* quest was opened for you. Its
   progress page was then left open, because the turn-in correctly refuses repeatables. The gossip path already skipped them.
   - Fix: skip quests where `C_QuestLog.IsRepeatableQuest` is true.
   - Test: C, with a positive control.
4. **BUG (minor) — ForeverHelper.lua `SaveCharacter`.** When the rested value was secret, `Safe(GetXPExhaustion()) or 0` saved 0
   over the real value.
   - Fix: a secret read now keeps the last value.
   - Test: D.
5. **RISK — QuestMobs.lua.** One refused `SetPoint` on a nameplate set `anchorRestricted` for the rest of the session. Markers
   stayed off until a /reload.
   - Fix: the flag is reset and plates are re-read on PLAYER_ENTERING_WORLD.
   - Not testable outside the game.
6. **NIT — Dungeons.lua `JudgeItem`.** `exists == false` compared a pcall result without `Safe()`.
   - Fix: `Safe(exists) == false`.

## UI-only: hub buttons for every page or window that opened only by typing

ForeverHub.lua has a new `VIEWS` table. It adds a row of buttons above the page. Each button runs the helper's own command
word through the hub's `RunCommand`. Views replace the page text. Actions (window toggles, map pins) leave the selected view as
it is. Page hints no longer list words that now have buttons.

| Page | Buttons (word sent) |
|---|---|
| Profession guide | Overview, Craft now (`craft`), Shopping list (`shopping`), one per profession you have (full guide; from `ForeverSkillProfessions`) |
| Gold goal | Goal, Money sources (`sources`), Auction sales (`sales`) |
| Gold guide | Best farms, All farms (`all`), Tips (`tips`) |
| Dungeons | For your level, All dungeons (`all`) |
| Quest mobs | List window (`list`, toggles QuestMobs' list window) |
| Find an item | Mail expiry (`expiring`) |
| Builds | Your build, All goals, Leveling, PvP, Tank, Healer, Damage |
| Weapon skills | All skills (`all`), Equipped (`""`, before only typed) |
| Reputation | All factions (`all`), This session (`""`, before only typed) |
| Level log | Open window (`window` → LevelLog_OpenWindow, i.e. `/levellog`'s window) |
| Ready check | Checks, Ignored spells (`ignored`) |
| Places | Nearest repair, Vendor, Inn, Flight, Mailbox, Bank, Trainer (pin the nearest) |
| Rares | Recent, All rares (`all`) |
| Characters | Own window (`window`, ForeverHelper's window with rates and to-dos) |

**Global open functions added to addons:** none. Every page already ran through the hub's `RunCommand`, and LevelLog's window
opens through its own `window` word.

Still typed, because these need free text: item and NPC names, numbers, amounts, a class name, and settings words such as
AutoQuest `accept off`. The AutoQuest switches are also in the hub's Options canvas.

## Not fixed: needs the game or an owner decision

- **RISK — QuestTracker.lua `ToggleFocus` / `OpenQuest`.** `C_SuperTrack.SetSuperTrackedQuestID` is called from our click.
  That fires SUPER_TRACKING_CHANGED, which the objective tracker handles with `MarkDirty`. If the event is sent synchronously,
  the tracker's next update could run tainted, which is the MawBuffs `GetAuraDataByIndex` error in the brief.
  - In-game check: click quests in our tracker, enter combat with a scenario/aura, then watch the error log.
  - If confirmed: keep focus in our own state only.
- **RULE (known, documented) — QuestTracker.lua `ObjectiveTrackerFrame:SetAlpha(0)`.** This is frame manipulation, chosen
  deliberately because Hide/Show taint. It has an opt-out (`keepBlizzard`). The invisible tracker still takes clicks.
  - Owner decision.
- **RISK — GoldGoal.lua repair detection.** If UPDATE_INVENTORY_DURABILITY arrives before PLAYER_MONEY, the repair is booked as
  a vendor purchase. Buying gear and equipping it within 2 s is booked as a repair.
  - The event order needs an in-game check.
- **NIT — QuestTracker tooltip.** It says "Right-click: track it", but both clicks super-track; nothing adds a quest watch.
- **Known exception, unchanged:** UIErrorsFrame:AddMessage fallbacks in ProfessionCap and QuestCheck. They run only without the
  hub, as recorded in STATUS.md.
- **Known, unchanged:** `UISpecialFrames` inserts (hub, ForeverHelper). `C_CVar.SetCVar` narration off, which the owner asked
  for and which runs out of combat only.
- **NIT:** ForeverHelper's help line "/fh - show or hide the window" is wrong under the hub. The new "Own window" button covers it.
- **NIT:** GoldGoal `sessionSeconds` is never read. A session that crosses midnight is booked to the later day.
- **NIT:** QuestMobs reads nameplates while markers are off.

## Rule checks

- **Hooks of Blizzard functions:** none. The only HookScript is on the hub's own panel.
- **Writes to Blizzard tables:** only the standard SlashCmdList/UISpecialFrames registrations, plus the items noted above.
- **Map canvas pins:** none (no AddDataProvider or AcquirePin).
- **COMBAT_LOG / CallbackEvent registrations:** none. Every registered event was checked against uisrc2.
- **Chat output:** none. Everything goes through ForeverHub_Receive.
- **Secret values:** every value used in arithmetic or comparisons goes through Safe/Call, apart from item 6, now fixed.
- **Combat:** QuestTracker's layout and its secure item buttons change only out of combat. The hub skips side-panel rows in combat.
- **Automation:** none outside AutoQuest. The Hearthstone button and the QuestTracker item buttons are click-only secure buttons.
- **AutoQuest:**
  - acts only on GOSSIP_SHOW, QUEST_GREETING, QUEST_DETAIL, QUEST_PROGRESS and QUEST_COMPLETE, so only in windows the player opened;
  - skips area-trigger quests, quests shared by players, and auto-accept quests;
  - pauses while Shift (or the chosen key) is held, and in combat;
  - never picks between several rewards (choices > 1 is left to you);
  - skips repeatables (now on every path) and quests that ask for gold;
  - can be switched off per action (accept, turn-in) or as a whole on the Manage page.
