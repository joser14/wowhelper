# Full review: ForeverCharacter (logic and code)

Scope: TalentNudge, Builds, TrainerNotes, WeaponSkillWatch, RestGuard, LevelLog, RepWatch, ReadyCheck, Legacy (new),
SpellMath (new). Hardest look at the code added since `research\final_review_character_world.md` (commit ea2be59):
Legacy, SpellMath, ReadyCheck's group buffs, LevelLog's Fights and Statistics tabs, plus Builds' C_Traits reading.
Checked against research\BRIEF.md and the API docs in uisrc2. Date: 2026-11-11.

## Fixed

### 1. BUG: ReadyCheck asked for an offline member's class buff (ReadyCheck.lua, ComputeParty)
- Claim: another class's group buff ("Arcane Intellect (a mage's buff)", "Mark of the Wild (a druid's buff)") was
  asked about whenever a member of that class was in the group, even when that member was offline.
- Failure: a mage disconnects; every mana user in the party, you included, shows "Missing Arcane Intellect (a mage's
  buff)" on the page and the side panel, although nobody can cast it. The offline mage was already left out of the
  list of people checked, but still put MAGE in `present`.
- Fix: a class counts as present only for you or a member whose `UnitIsConnected` isn't false. A dead member still
  counts (they will be back up), as test_r6_spellmath_readycheck.lua expects.
- Test: `tests\test_full_char_readycheck_offline.lua` (failed 2 checks before the fix, passes after).

## Rule checks (all clean)

| Rule | How it was checked | Result |
|---|---|---|
| No COMBAT_LOG_* / CallbackEvent registration | Every quoted UPPER_CASE string in the 10 folders cross-checked against the 12 `CallbackEvent = true` events in uisrc2 | None. New events (RECEIVED_ACHIEVEMENT_LIST, CRITERIA_UPDATE, ACHIEVEMENT_EARNED, MAP_EXPLORATION_UPDATED, TRAIT_CONFIG_UPDATED, SPELL_TEXT_UPDATE, SPELL_DATA_LOAD_RESULT, GROUP_ROSTER_UPDATE, PLAYER_EQUIPMENT_CHANGED) all exist and are plain events. LEARNED_SPELL_IN_TAB isn't in this client's docs; ReadyCheck registers it inside pcall, so it only fails quietly |
| No hooks or writes to Blizzard frames/tables | grep `hooksecurefunc`, `HookScript`, `_G[..] =`, `UISpecialFrames`, `RegisterCallback`, `EventRegistry` | None. SpellMath's spell-tooltip line uses `TooltipDataProcessor.AddTooltipPostCall` (pcall'd), like Tooltips, ItemAdvisor and QuestMobs |
| No map canvas pins | grep `AddDataProvider` / `AcquirePin` | None |
| No chat output | grep `print(` / `AddMessage` / `DEFAULT_CHAT_FRAME` | Clean; every `Print` goes to `ForeverHub_Receive` and is dropped without the hub |
| No automation | grep cast/target/train/use calls | None. ReadyCheck says "nothing is cast for you"; SpellMath only reads |
| Secret values | Read every new path | Legacy: `Num`/`Str` on every return. SpellMath: `SafeCall`/`Safe` on every field, tooltip uses only the cache. ReadyCheck: `ReadAuras` runs in pcall and treats a secret aura (or a refused call) as an unreadable unit, never as missing. LevelLog Fights: every meter number through `Number()`/`Safe()`; `isLocalPlayer` is NeverSecret. Statistics: `Call()` Safe()s every return |
| Reads only out of combat | Read the paths | Legacy `Refresh` returns in combat; SpellMath `Read`/`Step` stop in combat and rerun after; ReadyCheck `ComputeBuffs`/`ComputeParty` and the ticker skip combat; Fights capture checks `InCombatLockdown` 1 s after REGEN_ENABLED; Statistics snapshot returns false in combat |
| Hub Off hides everything | Read the paths, hub filters | Hub drops pages, side panel rows and pop-ups of an Off helper. Legacy also unregisters its events and drops its list; SpellMath stops reading and drops the tooltip line; ReadyCheck skips the group read; LevelLog hides its window (recording goes on, as designed) |
| Divide by zero | SpellMath, Legacy, Fights | SpellMath: per-mana only when cost > 0, per-second divides by at least the 1.5 s GCD. Legacy `Fraction` checks need > 0. Fights `Rate` checks seconds > 0; per-fight divides by `session.n > 0` |
| SavedVariables bounded | Read the writers | SpellMathDB keeps only `tooltip`. LevelLog: 20 fights, 400 statistics (80-char strings) per character. Legacy saves nothing |

## Focus areas, verified

- **Legacy.** Constants match LegacyConstantsDocumentation (currency 4225, trees 1187-1189, class categories
  15577-15585). `GetTraitCurrencyForAchievement(currency, id)` and `GetTreeCurrencyInfo(config, tree, false)` match
  SharedTraitsDocumentation; `spentInTree` is a nilable field there, and the code falls back to `spent`.
  Achievement globals are used with the right return orders (description is GetAchievementInfo's 8th value;
  criteria: text, type, completed, quantity, required). Other classes' challenges are found by walking each
  category's parents and are counted, not listed. Grouping is by category title, sorted; inside a group by progress.
- **SpellMath.** The parser handles ranges, "N over M sec", direct + over time, absorbs, thousands separators and
  "by 40 %"/"for 5 sec"; every priest heal and damage text up to 60 reads right (checked by hand: Lesser Heal, Heal,
  Greater Heal, Flash Heal, Renew, PW:S, Prayer of Healing, Smite, SW:P, Mind Blast, Holy Fire, Mind Flay,
  Starshards). Channels and HoT/DoT count their duration. Best-per-mana and "worse on both" marks are right.
- **ReadyCheck group buffs.** Aura reads only out of combat, secret auras count as unreadable. Fixed #1.
- **LevelLog Fights / Statistics.** DamageMeterType values match the enum (DamageDone 0, HealingDone 2,
  DamageTaken 7); session type Current = 1. `ResetAllCombatSessions` is never called.
- **Builds C_Traits.** Uses `activeRank` before `currentRank` (staged points not counted, consistent with
  TalentNudge's `excludeStagedChanges = true`); hidden and zero-rank nodes skipped; one-tree layouts split by the two
  widest x gaps. No change.

## NIT (not changed)

1. SpellMath.lua:140: a damage spell whose text also mentions healing is filed as a heal. Holy Nova (talent) reads
   as a 31.5 "heal" (its damage), Devouring Plague (Undead) as a heal. Not on this character's path.
2. SpellMath.lua:155-166: "N damage each second for 3 sec" (Arcane Missiles) and "N damage every 1 sec"
   (Hurricane) read only one tick, at the GCD. Priest texts all use "over N sec", so priests aren't affected.
3. SpellMath.lua:338-343: the rank sort mixes rank numbers and totals. If only some ranks of a spell have a
   "Rank N" subtext, the order function is inconsistent (Lua may raise "invalid order function"). Needs a family
   with partly missing subtexts.
4. SpellMath.lua:353-373 and the page text: "worse on both than a higher one" can in theory name a lower rank.
5. Legacy.lua:307-324: CRITERIA_UPDATE fires on most kills and quest steps, so while the side panel is open the
   list is rebuilt every 10 s, walking every category's parents (up to 400 x 12 GetCategoryInfo calls) plus the
   criteria. Cache the category set per session if it shows up as a hitch.
6. Legacy.lua:291-293: categories with the same title under different parents share one group heading.
7. LevelLog.lua:1378-1380: a fight is captured 1 s after it ends; if the next pull starts within that second
   (chain pulling), the earlier fight is never recorded (the meter is secret in combat and only "Current" or the
   newest session is read later). Session totals then undercount. Could note the newest session ID at
   REGEN_ENABLED and read it by ID later.
8. LevelLog.lua:1588: a money statistic of 1,000 gold or more ("1,234|T...GoldIcon") would be read as 234 gold if
   the client inserts thousands separators.

## Needs the game (left unfixed)

1. SpellMath: whether a known spell has an empty description. ReadSpell then asks `RequestLoadSpellData` on every
   read, and if the game answers with SPELL_DATA_LOAD_RESULT each time, the 5-second read repeats for good and the
   page always says "Some spells are still loading". Check that the line goes away a few seconds after login.
2. SpellMath: whether the spell text already includes +healing/+spell damage from gear, whether
   `GetSpellSubtext` gives "Rank N", and whether `IsSpellKnown` is true for lower ranks the spellbook hides.
3. Legacy: that the achievement globals exist on 1.60.1, that `GetCategoryList` includes the Legacy categories,
   and that `GetTraitCurrencyForAchievement(4225, id)` is above zero for Legacy challenges. Also that
   `GetConfigIDByTreeID(1188)` returns a config for the account-wide Legacy trees.
4. ReadyCheck: whether a party member far away (other zone) still reports auras. If the list comes back empty
   rather than refused, that member is shown as missing every buff.
5. LevelLog Fights: that "Current" still holds the fight 1 s after combat ends, and the numbers match Blizzard's
   meter. Statistics: that GetStatisticsCategoryList/GetStatistic exist and how money values are formatted.
6. Builds: whether a Legacy perk such as "Talented" grants free talent ranks that `activeRank` counts as spent.

## Summary

ForeverCharacter is in good shape. One logic bug was confirmed and fixed: ReadyCheck asked for an offline member's
class buff (a disconnected mage made every mana user "missing Arcane Intellect"). The new test
`tests\test_full_char_readycheck_offline.lua` failed first and passes now. There is no CallbackEvent or COMBAT_LOG
registration, no hook, map pin, chat output or automation. Every secret value is guarded. Legacy, SpellMath, the
group-buff check and the Fights and Statistics tabs read only out of combat, and the hub's Off switch silences
each of them. Eight NITs remain (parser edge cases for other classes, a Legacy rebuild cost, chain-pull fights) and
six in-game checks, listed above.
