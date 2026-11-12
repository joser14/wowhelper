# Full review: hub, guides, quests (round 6 code)

Scope: !ErrorLog, ForeverHub, ForeverHelper, ProfessionCap, ProfessionGuide, GoldGoal, GoldGuide, Dungeons,
QuestTracker, QuestCheck, ZoneLevels, QuestMobs, AutoQuest. Most attention went to the round 6 additions: the hub's new
pages and buttons, ForeverHelper's profession cooldowns, Dungeons' group loot, ProfessionGuide's craftable upgrades,
GoldGuide's Darkmoon view, QuestCheck's per-zone counts and the "New in Forever" tag. Findings already fixed in
`final_review_*`, `xreview_*` and `review*` are not repeated here.

Tests: `tests\test_full_hub_views.lua` and `tests\test_full_hub_forever_tag.lua`. Both failed before the fixes.
`tests\runall.ps1`: 0 failed.

## Fixed

1. **BUG: switch buttons ran again every time the hub reopened (ForeverHub.lua, `VIEWS`).**
   - Gathering's "Herbs on/off", "Ore on/off" and "Fishing on/off", and Spell math's "Tooltip line off/on", were
     *views*. The hub keeps the chosen view and runs it again on every redraw, and the window's OnShow redraws the page.
   - Failure: click "Herbs on/off" (herbs go off), close the hub with Esc, then open it again. The page runs
     `toggle herbs` again and the herbs come back on. Each reopen flips the layer.
   - The test counted 1, 2, 3 toggles over two reopens.
   - Fix: these buttons are now `action = true`, like Places' pin buttons. They run once per click, show their
     answer, and leave the page's view as it was.
2. **BUG (data rule): "New in Forever" also tagged quests from later Classic releases (QuestTracker.lua, QuestCheck.lua).**
   - forever-db has no "new" flag. Its quest IDs fall into three groups:
     - original Classic, up to 9665;
     - 65593-84402: Love is in the Air (65xxx), and Season of Discovery's library books and quests (78088-84402,
       for example "Nar'thalas Almanac" and "Terror of the Desert Skies");
     - Forever's own quests, from 86574: Darkshore "Holy Diver", Loch Modan "Banner of the Fallen", Stonetalon,
       Elwynn 917xx, Riverglades, Zephras, Camping 101 and Craftsman's Writs.
   - Nothing falls between 84403 and 86573, so the gap is clean in both forever-db 2026.11.1 and QuestDB.
   - The tag now starts at **85000**. In QuestDB this drops 66 quests: 2 Love is in the Air and 64 Season of
     Discovery quests. The test checks the gap against the real QuestDB.
   - **Not changed (outside this scope):** `Tooltips\Tooltips.lua:132` still uses 10000, and so does its
     option text at line 120. The Bags reviewer should make the same one-line change, or the tooltip and the tracker
     will disagree on those 66 quests.

## Checked, no bug found

- **Hub wiring.** Every new page key has a real handler: LEGACYPOINTS, SPELLMATH, AGGROWATCH, EVENTS and NODES. None of
  these keys collides with a Blizzard slash command (checked in uisrc2). Every new button's word is handled by its
  helper:
  - Legacy: zone, done
  - Events: holidays, turnins
  - Nodes: all, toggle herbs, toggle ore, toggle fishing
  - MapPins: notes
  - GoldGuide: darkmoon
  - LevelLog: stats
  - ForeverHelper: chars, cooldowns
  - Each VIEWS label matches a tab, and each page's default view matches its own word.
- **No reopen loop for LevelLog's window.** LevelLog's "all" opens its window with `LevelLog_OpenWindow(false)`, which
  never toggles it, and only when its option is ticked.
- **ForeverHelper cooldowns.**
  - Reads happen only out of combat, and secret values are skipped.
  - Saved data stays bounded: at most 4 entries per character.
  - At most one read is pending at a time.
  - The pop-up is shown once per cooldown, and never while the helper is Off.
  - Item lines are dropped when the item leaves your bags.
- **Dungeons group loot.**
  - The loot patterns built from LOOT_ITEM* are correct, including `%1$s` forms and `x%d` multiples.
  - Secret chat text is skipped.
  - Each run keeps at most 20 lines, and they carry over correctly when two runs merge.
  - CHAT_MSG_LOOT is not a CallbackEvent.
- **ProfessionGuide craftable upgrades.** Recipe and guide material shapes are handled, the GetItemInfo returns are read
  correctly, the sort is stable, and judging is capped at 300 items.
- **GoldGuide Darkmoon view.** Every helper it uses exists (AuctionPrice, ItemInfo, FormatAge, AH_CUT), and it reads the
  fields Events_Faire returns. It reads only.
- **QuestCheck per-zone counts.**
  - The record pattern matches QuestDB's 10-field format.
  - The race and class masks match LevelGuide's rule.
  - The three ways of reading completed quests are guarded, the index is built once, and nothing is saved.
- **AutoQuest limits.**
  - It acts only on GOSSIP_SHOW, QUEST_GREETING, QUEST_DETAIL, QUEST_PROGRESS and QUEST_COMPLETE. Area-trigger and
    auto-accept quests are skipped, and so are quests shared by players (`UnitIsPlayer("npc") ~= false`).
  - It pauses while the chosen key (Shift, Ctrl or Alt) is held, and in combat.
  - With more than one reward choice it leaves the window open (`choices > 1` returns). With exactly one reward it
    takes that reward. It skips quests that ask for gold and repeatable, daily or weekly quests.
  - It can be switched off as a whole (hub Manage, `ForeverHub_IsOff("AutoQuest")`), or per action
    (accept/turn-in, on the hub Options page or with `accept off`).

## Rule checks (whole scope)

- **Blizzard hooks or writes:** no new ones. The only HookScript calls are on the hub's own panel, and the
  SlashCmdList/UISpecialFrames registrations are the standard ones.
- **Map canvas:** no AddDataProvider or AcquirePin.
- **COMBAT_LOG / CallbackEvent:** every event string in scope was checked against the uisrc2 list of CallbackEvents
  (COMBAT_LOG_*, ENCOUNTER_STATE_CHANGED, MINIMAP_PING, CLASS_TALENTS_SWITCH_*, TOOLTIP_SHOW_ITEM_COMPARISON). None is
  registered. MAP_PING in QuestTracker is a sound kit name.
- **Chat output:** none. Every Print goes to ForeverHub_Receive. The known UIErrorsFrame fallbacks, used without the
  hub, are unchanged.
- **Automation:** quest window functions are called only in AutoQuest.
- **Secret values:** the new code reads through Safe, CallSafe or Plain before any arithmetic or comparison.
- **Combat taint:** no new secure-path calls.

## Needs the game

- **ForeverHelper cooldowns at login.** If `C_Spell.GetSpellCooldown` still returns 0 for a running transmute or
  Mooncloth 2 s after login, the "ready earlier than saved" branch marks it ready and a false "is ready" pop-up appears.
  The next SPELL_UPDATE_COOLDOWN corrects it.
  - Check: log in on a character with Mooncloth on cooldown.
- **AutoQuest pause.** The key is checked on each window event, not once per NPC. Hold Shift to open an NPC, let go,
  then click a quest: AutoQuest accepts it, or turns it in. To do the whole visit by hand you have to keep Shift held.
  - Latching the pause for the visit needs the real GOSSIP_CLOSED / QUEST_FINISHED order. Check that order in game
    before changing it.
- **Craft now page.** It judges up to 300 recipe outputs with ItemAdvisor each time the view is drawn, including when
  the hub reopens. Watch for a hitch with a large recipe list.
- **Group loot in instances.** Confirm that CHAT_MSG_LOOT text for other players isn't secret inside dungeons on
  Forever. If it is, "Who looted what" only lists your own loot.

## Nits (not changed)

- On "My notes" (Map pins), typing `delete note 1` shows the notes page twice: once as the command's answer and once
  as the redrawn view.
- QuestCheck's "Zones you can finish at your level" counts gray and chain-locked quests as open, so the list can be
  long at higher levels.
- Dungeons' "Who looted what" repeats your own loot when you're solo, because the "Loot:" line already lists it.
- GoldGuide's Darkmoon rows can show "vendor 0c".

## Summary

The round 6 code in this scope is careful: every new read is guarded, saved data is bounded, and no rule is broken. The
review found two bugs. First, the hub's switch buttons (gathering layers, spell math tooltip) were kept as views, so each
reopen of the hub ran them again and flipped the setting. They are now one-shot actions. Second, the "New in Forever"
tag also caught 66 quests from later Classic releases. forever-db's IDs leave a clean gap between those (up to 84402)
and Forever's own quests (from 86574), so QuestTracker and QuestCheck now tag 85000 and up. Tooltips needs the same
change from its reviewer.
