# Review 4: round-4 changes (45cacdc..1236601), 2026-11-11

Scope: every file changed since 45cacdc except `Builds\` and `research\builds*`. Each change was traced through
its events, saved data, secret-value handling and API shapes (checked in uisrc2's generated docs), and against the
owner's rules. Only confirmed bugs were fixed, each with a failing test first. `tests\runall.ps1`: 0 failed.

## Confirmed and fixed

### B1 (BUG) Dungeons never registered the three upgrade-check events
- **Where:** `Dungeons\Dungeons.lua:1309` (before the fix). The three lines
  `pcall(events.RegisterEvent, events, "ITEM_DATA_LOAD_RESULT" / "PLAYER_EQUIPMENT_CHANGED" / "PLAYER_LEVEL_UP")`
  had been merged into the end of the comment above them (the line breaks and the `pcall` were lost), so they were
  comment text. The handler for all three existed, but the game never sent them.
- **Scenario:** open the Dungeons page with a loot item the client hasn't cached: `JudgeItem` requests it and marks
  it `waitingItems[id]`; `QueueItem` refuses anything in `waitingItems`, and only `ITEM_DATA_LOAD_RESULT` clears
  it, so that item is never judged for the rest of the session. Equip an item the page called an upgrade, or
  level up: `upgradeOf` is never reset, so "(upgrade for you)" and "N upgrades (...)" stay wrong until /reload.
  The existing test `test_r4b_dungeon_upgrades.lua` fired the events by hand, so it could not see this.
- **Fix:** the three `pcall(events.RegisterEvent, ...)` lines restored as code.
- **Test:** `tests\test_review4_dungeon_events.lua` delivers only registered events (as the game does): checks the
  three registrations, a late-loading item being counted, upgrades clearing after new gear and being rechecked
  after a level. Failed 5 checks before the fix, passes after.
- Note: `dist\ForeverGuides\Dungeons\Dungeons.lua` (build output) still has the old line until the next build.

### N1 (NIT, docs) NOTICE.md lacked credit lines for four idea sources named in code comments
Alts Forever (Waylaid Crate tooltip format, MIT), DungeonJournal (source ranking), Pawn (no coin for unscored
choices) and Baganator/Syndicator (keyring/equipped-bag/mail features). None of them is code or data we ship, so
nothing was a licence breach; one "Ideas only" line now names them. All ported code/data sources (What's Training
with its MIT text, FastLoot + cMaNGOS classic-db, Tweaks Forever, Firekeeper, Full Mana Forever, Glowing Bars,
XP Horizon, MobSpot, TomTom/Leatrix ideas) were already credited.

## Checked and found sound (no change)

- **Rules:** no new hooks (QuestMobs' unit line uses `TooltipDataProcessor.AddTooltipPostCall`, like Tooltips),
  no Blizzard frame or table writes (WindowBadges' discount badge is our pooled badge anchored to
  `ClassTrainerFrame`; MapPins' info line is a font string on our own UIParent overlay; the edge arrow is our own
  frame on `Minimap`, the accepted exception), no map canvas pins, no `COMBAT_LOG_*`/CallbackEvents (`UNIT_DIED`,
  `PARTY_KILL`, `ITEM_DATA_LOAD_RESULT`, `SPELL_DATA_LOAD_RESULT`, the `MAIL_*` events and
  `EQUIPMENT_SETS_CHANGED` are plain events in uisrc2), no automation, all new output goes to the hub
  (`ForeverHub_Receive`), none to chat.
- **LowWarn secrets:** the curve results go only into `edge:SetAlpha` / `drink:SetAlpha` inside a pcall; nothing
  compares, stores or prints them. `UnitHealthPercent(unit, usePredicted, curve)` and
  `UnitPowerPercent(unit, powerType, unmodified, curve)` match UnitDocumentation:1506/2838; `CreateCurve`,
  `AddPoint(x, y)`, `SetType` match the LuaCurveObject docs.
- **Saved-data growth:** ItemFinder `names` are pruned to items held; inbox/incoming mail entries expire after
  their days left / 30 days and are rebuilt at login; RareWatch watch list capped at 50; Dungeons learned NPCs and
  entrances are bounded by the boss/dungeon lists; LevelLog's XP curve is 59 numbers; TrainerNotes `tomes` is
  bounded by the tome list.
- **API shapes:** `GetInboxHeaderInfo` (7th daysLeft, 8th item count), `GetInboxItem`/`GetSendMailItem` (4th
  count), `MAIL_LOCK_SEND_ITEMS(attachSlot, itemLink)`, `GetContainerItemEquipmentSetInfo` (inSet, setList),
  `C_EquipmentSet.GetItemIDs` (table by slot), `Enum.BagIndex.Keyring = -1`, `C_SpellBook.IsSpellKnown(id, bank)`,
  `IsSpellInSpellBook(id, bank, includeOverrides)`, `C_LFGList.GetActivityInfoTable`; undocumented calls
  (`GetKeyRingSize`, `C_LFGList.GetAvailableActivities`) are pcall'd.
- **Item link suffix:** `ItemVariant` reads field 7 after `item:` (itemID, enchant, 4 gems, suffix): correct.
- **Per-frame cost:** ReadyCheck and TrainerNotes walk 2 skill lines per frame, at most every 5 s; TrainerNotes'
  known-spell refresh 40 IDs per frame; Dungeons' upgrade queue 5 items per frame; MapPins' edge arrow is placed
  only when the minimap state string (now including the target key) changes.
- **Helper interactions:** ReadyCheck reads `TrainerNotesData` at scan time (works in any load order) and only
  calls a bar spell an old rank when the higher known rank in the group has the same name; WindowBadges reads
  `TrainerNotesData.trainerFactions` defensively; Dungeons calls `ItemAdvisor_IsUpgrade` through pcall.

## Suspicions (not changed; each needs the in-game check named)

1. **RISK, LowWarn may stay hidden at the start of a fight** (`DeathNotes\LowWarn.lua:176-178`).
   `PLAYER_REGEN_DISABLED` is commonly dispatched before `InCombatLockdown()` turns true, so `ApplyNow` there
   hides the cue and it first appears on the next `UNIT_HEALTH`/`UNIT_POWER_UPDATE`. Harmless if any health or
   mana change follows quickly. *Check:* as a warrior or rogue (no mana events), drop under 35 % health, start a
   fight by attacking a mob, and see whether the red edge shows before you take the first hit. If not, call
   `ApplyNow` once more on `C_Timer.After(0, ...)` after `PLAYER_REGEN_DISABLED`.
2. **RISK, drink advice ignores drinks whose tooltip amount has decimals** (`FoodCheck\ManaFull.lua:106`).
   The pattern `restores (%d+) mana over (%d+) sec` fails on "Restores 1344.6 mana over 27 sec" (Classic-style
   decimals). *Check:* hover Moonberry Juice / Morning Glory Dew in game; if the amount has a decimal, widen the
   pattern to `([%d%.]+)`.
3. **RISK, Group Finder ranges read once, possibly too early** (`Dungeons\Dungeons.lua` `GameRange`).
   `ReadGameRanges` runs on the first use after login and stores `false` for every dungeon whose activity info
   isn't available yet; it is not retried until the next login. If the hub status asks before the Group Finder
   data is loaded, the session falls back to Data.lua ranges. *Check:* log in, open the Dungeons page at once and
   look for "Group Finder: from level ..." in a dungeon's details; if missing but present after /reload, retry
   ranges that came back `false` (e.g. after `LFG_LIST_AVAILABILITY_UPDATE` or once a minute).
4. **RISK, saved death spot cleared on release?** (`LevelGuide\LevelGuide.lua:5145`). The spot is cleared on
   `PLAYER_ALIVE` when `UnitIsGhost` is false; releasing your spirit fires `PLAYER_ALIVE` too. If `UnitIsGhost`
   still reads false during that event, the fallback is lost the moment you release. *Check:* die outdoors,
   release, then `/dump LevelGuideDB` (or watch the corpse arrow when the game's corpse position is missing).
5. **RISK, Dungeons caches "not an upgrade" while ItemAdvisor is still loading** (`Dungeons.lua` `JudgeItem`).
   `ItemAdvisor_IsUpgrade` returns false when ItemAdvisor has no character data or the equipped item's stats
   aren't loaded yet; Dungeons stores that as a final `false` until gear or level changes (now that B1 is fixed).
   *Check:* open the Dungeons page right after login; compare the upgrade counts with a second look after /reload.
6. **RISK, TrainerNotes rank chains built by the "needs exactly one earlier spell" rule** (`tools\gen_trainerdata.js:155-171`).
   A chain can link two different spells; TrainerNotes then treats knowing the later one as knowing the earlier one
   and hides it from "Ready to train" (ReadyCheck is protected by its same-name check, TrainerNotes is not).
   *Check:* on a few classes, compare the Trainer page's "Ready" list with the class trainer's green rows.
7. **RISK, warlock tome rows after a higher rank** (`TrainerNotes.lua` `TomeLines`). A tome counts as known only if
   `IsSpellKnown(spell, Pet)` is true for its own rank. If the pet spellbook reports only the top rank, every older
   tome at or below your level + 2 is listed again. *Check:* with an Imp that knows Firebolt rank 3, open the
   Trainer page and see whether the rank 2 tome is listed.
8. **RISK, minimap edge arrow art orientation** (`MapPins.lua` `Edge.Place`). The rotation assumes
   `Interface\MINIMAP\MiniMap-QuestArrow` points up when unrotated. *Check:* set `/way` 300 yd due east; the rim
   arrow should sit on the right edge pointing right.
9. **RISK, outgoing mail when `MAIL_LOCK_SEND_ITEMS` doesn't fire** (`ItemFinder.lua` event handler). If the game
   empties the attachments (`MAIL_SEND_INFO_UPDATE`) before `MAIL_SEND_SUCCESS` without a lock event, `outgoing`
   is overwritten with the empty list and the sent items are not credited to the receiving alt. *Check:* mail an
   item to your alt, then hover the item on the sender: it should show the alt's "mail" count.
10. **NIT, WindowBadges discount badge at any class trainer** (`WindowBadges.lua:650`). "10% off (Honored with
    Darnassus)" also shows at a Stormwind trainer, where the discount doesn't apply; the trainer's own faction isn't
    known. Consider wording it "10% off at Darnassus trainers".
11. **NIT, reward coin hidden for "your current item has stats I can't score"** (`ItemAdvisor.lua:2072`, matched
    by "can't score"): there the choice itself was scored; only the worn item wasn't.
12. **NIT, MapPins info line colour stale after a level-up** until the cursor moves to another cell (the zone cache
    key has no level). Also: `Info.Update` runs every frame while the world map is open (a `GetPlayerMapPosition`
    vector and a few string.formats per frame); a 0.1 s throttle would do.
13. **NIT, Succubus and Incubus share tome 16375** (`TrainerNotes\Data.lua:1776-1777`): a warlock with both
    summons sees the same tome twice.
14. **NIT, RareWatch watch list learns only the first NPC ID for a name**: a second NPC with the same name and a
    different ID no longer matches once the first ID is stored (MobSpot's behaviour, kept).

## Follow-up fixes (fix4, 2026-11-11)

Fixed from code, each with a `tests\test_fix4_*.lua` that failed first; `tests\runall.ps1`: 0 failed.

| # | Fix | Test |
|---|-----|------|
| 1 | LowWarn tracks combat from `PLAYER_REGEN_DISABLED/ENABLED` (seeded from `InCombatLockdown()` at login), so the cue shows at the start of a fight and hides at its end even if the lockdown flag lags. | `test_fix4_lowwarn` |
| 2 | ManaFull reads drink amounts with decimals and thousands commas ("1,344.6"). | `test_fix4_manafull` |
| 3 | Dungeons re-reads Group Finder ranges every 30 s while any came back empty, at most 10 times a session; a range once read is kept. | `test_fix4_dungeons` |
| 4 | LevelGuide: `PLAYER_ALIVE` clears the death spot only if, 1 s later, you are neither a ghost nor dead (and it's still the same spot); `PLAYER_UNGHOST` clears at once. No new top-level locals. | `test_fix4_deathspot` |
| 5 | Dungeons doesn't store "not an upgrade" when ItemAdvisor answers false with no reason (no character data) or "still loading"/"Can't read"; the next look asks again. | `test_fix4_dungeons` |
| 6 | TrainerNotes rank chains count a later rank only when it has the same spell name (a name still loading is trusted, as before). | `test_fix4_trainer` |
| 7 | Warlock tomes: a known tome covers older tomes of the same pet spell (by spell name); remembered per character. | `test_fix4_trainer` |
| 10 | WindowBadges compares this trainer's prices with TrainerNotesData's list prices: "10% off (Honored with X)" only when they show the discount, no badge at full prices, "10% off at X trainers" (gold) when it can't tell. | `test_fix4_wb` |
| 11 | ItemAdvisor's reward coin is no longer hidden by "your current item has stats I can't score". | `test_fix4_itemadvisor` |
| 12 | MapPins' info-line zone cache keys on your level too. | `test_fix4_mappins` |
| 13 | A tome shared by Succubus and Incubus is listed once. | `test_fix4_trainer` |
| 14 | RareWatch: a name entry keeps matching by name after learning an ID; extra IDs kept in `entry.ids` (max 10). New ID entries are `byID` and match only that NPC (older ID entries with a learned name also match by name). | `test_fix4_rarewatch` |

Perf audit NITs: hub stat lines only refreshed while the panel is shown (XP-sample pruning and gold start still run;
OnShow refreshes) (`test_fix4_hub`); FoodCheck coalesces your `UNIT_AURA` bursts into one check 0.5 s later
(`test_fix4_foodcheck`); WindowBadges' watcher OnUpdate runs only while a reward, merchant or trainer window is open
(`test_fix4_wb`); QuestMobs skips a plate whose answer is pending until its 2 s read window passes, instead of
re-running the unit checks every frame (`test_fix4_questmobs`); ItemAdvisor debounces `QUEST_LOG_UPDATE` (one walk
1 s after a burst) and rebuilds on demand before any verdict, so `test_itemadvisor_extra` passes unchanged
(`test_fix4_itemadvisor`).

Existing tests changed to the new behaviour: `test_windowbadges` (watcher off until a window opens),
`test_r4a_wb_trainer` (no prices to compare: "10% off at Ironforge trainers"), `test_r3b_supplies` (runs the
coalesced aura timer after each `UNIT_AURA`), `test_r4b_trainer_extras` (both Slam ranks named "Slam" in the mock).

Left alone (need the game): 8 (edge-arrow art orientation) and 9 (outgoing mail without `MAIL_LOCK_SEND_ITEMS`).
Still worth an in-game look: the trainer price comparison assumes TrainerNotesData's list prices match Forever's.

## Summary
One real bug: Dungeons' upgrade check never received its three events because their registration lines had been
folded into a comment, so uncached loot was never judged and upgrade marks went stale after new gear or a level;
fixed with a test that delivers only registered events. NOTICE.md gained one line for idea-only sources named in
code. The rest of round 4 holds up under the rules (no hooks, no Blizzard writes, no canvas pins, no combat-log or
CallbackEvents, no chat), passes secrets only where intended (LowWarn's SetAlpha), keeps saved data bounded and
spreads its heavier scans over frames. Fourteen suspicions are listed with the in-game check for each; the most
useful to check first are LowWarn at the start of a fight, decimals in drink tooltips, and the once-per-session
Group Finder range read.
