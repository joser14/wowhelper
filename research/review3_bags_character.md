# Review 3b: bags and character helpers (2026-11-10)

This round re-read these 22 helpers end to end and traced what each does in game:

- **Bags:** ItemAdvisor, BagCheck, ItemFinder, PriceMemory, FoodCheck, SupplyWatch, DurabilityWatch,
  Tooltips, WindowBadges.
- **Character:** TalentNudge, Builds, TrainerNotes, WeaponSkillWatch, RestGuard, LevelLog, RepWatch,
  ReadyCheck (SpellReady).
- **Professions, gold and dungeons:** ProfessionCap, ProfessionGuide, GoldGoal, GoldGuide, Dungeons.

It focused on what changed since `review_2026-11-10.md`:

- ItemAdvisor: spell power, Waylaid Crates;
- LevelLog: quest XP vs kill XP;
- Builds: trait reading and the talent-window panel;
- ProfessionGuide, ProfessionCap, GoldGuide: the skill-line fallback;
- GoldGuide: skill filters, pinning;
- RestGuard: the cooldown guard.

Findings from earlier reviews aren't repeated here.

**How it was checked:**

- API shapes were checked against the client's API docs in `uisrc2`.
- Every event name registered in these 22 folders exists in the client docs. An unknown event throws on
  Forever. The one doubtful event, `LEARNED_SPELL_IN_TAB`, is registered inside `pcall`.
- None of them registers a `CallbackEvent`. None uses a hook or `hooksecurefunc`.
- None calls a gameplay function: no buying, selling, equipping, training, casting, talent learning or repairing.
- None prints to chat. The only output outside the hub is the `UIErrorsFrame` fallback when the hub is
  missing, which is already noted.

## Confirmed and fixed

Each fix has a test in `tests\test_review3b_*.lua` that fails on the old code and passes on the new.

| # | Helper | What was wrong | Fix | Test |
|---|---|---|---|---|
| 1 | Builds (`Builds.lua` 236-258, 351, 411, 456) | **Trees were named after the class.** See below. | See below. | `test_review3b_builds_tabs.lua` |
| 2 | ItemAdvisor (`ItemAdvisor.lua` 2082-2090) | **A level-up left an old verdict in the bags.** See below. | See below. | `test_review3b_itemadvisor_levelup.lua` |
| 3 | ItemAdvisor (`ItemAdvisor.lua` 288-298) | **An Elemental shaman was scored as Enhancement.** See below. | See below. | `test_review3b_itemadvisor_tabs.lua` |

### 1. Builds: trees named after the class

**What was wrong.** Builds took tree names from the game: `GetTalentTabInfo`, then
`C_SpecializationInfo.GetSpecializationInfo`. On Forever:

- the first is gone;
- the second has one spec per class, named after the class (`thirdparty_features.md` 6.10).

So when the trait tree doesn't name its parts, the columns came out as "Warrior", "Tree 2" and "Tree 3". That had
two effects:

- The panel said "(Warrior, row 1)" for an Arms talent.
- At 60 with no saved goal, "the dungeon/raid build whose tree you have most points in" never matched a tree. A
  Protection warrior was given the Fury raid build.

**Fix.**

- There's now a class tree table (`CLASS_TREES`, the same names as `Data.lua`).
- A name from the game is kept only when it's one of your class's trees. "Shadow" also counts as "Shadow Magic".
- Otherwise the tree is named from the class table by position.

`test_logic_char_builds.lua` 2 and 3 now expect "Fury" instead of "Tree 2".

### 2. ItemAdvisor: a level-up left an old verdict in the bags

**What was wrong.** On Forever, `UnitLevel` can still return the old level for about a second after
`PLAYER_LEVEL_UP` (`thirdparty_features.md` 6.12). The hub's bag scan runs every second and judged the bags with
the old level, then kept that verdict. So an item you could now wear stayed "KEEP: Upgrade at level 20": no
arrow and no Equip row, until a bag or gear change.

**Fix.** On `PLAYER_LEVEL_UP`, verdicts are forgotten at once and again 2 seconds later.

### 3. ItemAdvisor: an Elemental shaman was scored as Enhancement

**What was wrong.** The role-from-talents table knew "Elemental" and "Shadow". The 1.60.1 game data names those
trees "Elemental Combat" and "Shadow Magic" (`research\builds\SHAMAN.md`, `PRIEST.md`). So with tree names read
from the game (sub-trees, tree titles or the old tab API):

- an Elemental shaman kept the class default, Enhancement melee weights;
- a priest who respecced from Holy to Shadow stayed a healer.

**Fix.** Both spellings are in `TAB_PROFILES`.

## Suspicions (not fixed: each needs an in-game check)

| # | Helper | Suspicion | In-game check |
|---|---|---|---|
| S1 | LevelLog 239-242 | **Quest XP at a level-up.** `QUEST_TURNED_IN`'s XP is counted to `UnitLevel` at that moment, and never split across the two levels as the bar XP is. If the level already reads as the new one, `min(questXP, xp)` caps it and the total quest share is undercounted. Otherwise the old level is over-credited. Event order and level staleness (fact 6.12) decide which. | Turn in a quest that levels you. On the Level log page, check both levels' quest %; the total should match a hand count. If it's off, keep the quest XP pending and split it in `TrackXP` like the bar. |
| S2 | Builds `ComputeStatus` | **Stale level at 60.** On the ding to 60, the hub can compute the row with the old level (fact 6.12) and cache it until the next talent event. | Ding 60 with a point unspent and watch the side-panel row for a few seconds. |
| S3 | Builds `DiscoverTalentWindows` | **Wrong window picked.** It adopts any top-level `*Talent*Frame` parented to UIParent. A frame like that which is always shown would keep the panel up. | `/dump BuildsTalentPanel:IsShown()` with the talent window closed. It should be false. |
| S4 | DurabilityWatch `RepairCost` | **Cost per second, and maybe no answer.** It builds 18 `C_TooltipInfo.GetInventoryItem` tooltips every second while gear is at 25% or less. `repairCost` isn't in this client's API docs, so it may always fall through to the merchant. | Away from a vendor with damaged gear, see whether "Repair ... (cost)" shows. If it never does, skip the per-slot read. |
| S5 | ItemAdvisor `CanDisenchant` | **Enchanters not recognised.** If `GetProfessionInfo` reports modern skill-line IDs (29xx, fact 18), Enchanting (333) isn't found, and green gear never shows DISENCHANT unless the Disenchant spell is known. | Enchanter: `/dump select(7, GetProfessionInfo(GetProfessions()))`. |
| S6 | ReadyCheck reagents | **Reagent Economy perk ignored.** With the perk, class spells need no reagents, but low-reagent rows still show. | With the perk, check whether a mage with Arcane Brilliance and no powder still gets a Reagent row. |
| S7 | WindowBadges vs ItemAdvisor | **Two "Best" marks.** The two pick the best reward differently: WindowBadges ranks "fills an empty slot" first; ItemAdvisor uses the score gain. With WindowBadges' reward badge switched on (it's off by default), both can mark different rewards. | Switch on `reward` and take a reward with an empty-slot choice. |
| S8 | Weapon types (ItemAdvisor) | **Druid polearms, rogue axes.** Druid polearms at 20 and rogue one-hand axes match fact 14, which is still unverified; the tooltip's red line covers any mistake. | At a weapon master, check a druid's Polearms and a rogue's One-Handed Axes. |
| S9 | RepWatch `TakeBaseline` | **First gain lost.** If the faction list is empty at login and the first `UPDATE_FACTION` comes from a rep gain, that gain becomes part of the baseline. | Log in and kill a rep mob at once; the session gain should include it. |

## Checked and found right

| Helper | What was checked |
|---|---|
| ItemAdvisor | **Scoring:** slots, two-handers against main hand plus off hand, off-hand DPS scale, dual-wield targets, pairs against a worn two-hander. **Restrictions:** class armor and weapon tables, level requirement ("Upgrade at level N"), red tooltip lines. **Spell power:** sp, dmg and heal never double-count; spell power counts as a loss. **Other:** Waylaid Crate range, money (per-unit price times stack), verdict cache invalidation. **Load and growth:** bag scan spread over frames, caches capped at 2000. |
| LevelLog | **Bar XP:** split at a level-up, hidden XP caught up later. **Data:** old saves, events before login. |
| RestGuard | Rested math (5% per 8 h, cap 150%); the cooldown guard (`C_Container.GetItemCooldown` exists and can return nothing). |
| Builds | **Talents:** row gate (5 points per row), leveling-to-raid switch at 60. **Panel:** our own frame on UIParent, placed by reading the window's position, nothing set on Blizzard frames. **Unspent points:** the trait currency excludes staged points. |
| TalentNudge | Unspent points from the trait currency, excluding staged points. |
| TrainerNotes, WindowBadges | Both return orders of `GetTrainerServiceInfo`, matching the Forever order (fact 6.11). An empty list after a purchase is ignored. |
| PriceMemory | **Reading:** browse, commodity and item reads, all per unit. **Data:** suffix cap, 30-day pruning of auction and vendor prices. |
| Tooltips, GoldGuide | Read PriceMemory's per-unit price and multiply it by the stack; the 5% auction cut. |
| ItemFinder | Bank tab enum: `CharacterBankTab_1-9` are 6-14 in this client, and account tabs are skipped. |
| Saved data | Bounded everywhere: LevelLog (60 levels), Dungeons kills (per boss), TrainerNotes (per trainer list), ItemFinder (90-day prune), RepWatch (per character). |
| OnUpdate watchers | Throttled to 0.25-0.5 s, and they hide our own frames only. |

## Summary

**Three bugs fixed, each with a failing-first test.**

- **Builds** named talent trees after the class, which broke the level-60 default build and the panel's tree
  labels.
- **ItemAdvisor** kept verdicts judged with the old level after a ding.
- **ItemAdvisor** missed the game's own "Elemental Combat" and "Shadow Magic" tree names, so Elemental shamans
  kept melee weights.

**Rule safety:** nothing found. Every registered event exists in the client, there are no callback events,
hooks, automation, chat output or Blizzard writes, and all secret-sensitive reads go through `Safe()`.

**Nine suspicions** are listed above, each with an in-game check. The most likely to matter is S1, LevelLog's
quest-XP split at a level-up.

**Tests:** `tests\runall.ps1` reports 0 failed.
