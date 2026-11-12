# Full review: ForeverBags bundle (logic and code)

Scope: ItemAdvisor, BagCheck, ItemFinder, PriceMemory, FoodCheck, SupplyWatch, DurabilityWatch, Tooltips,
WindowBadges. Read against research\BRIEF.md. Earlier reviews (final_review_bags.md, review*.md) are not repeated.
Most attention went to what changed since final_review_bags.md: ItemAdvisor_Judge and the hub Off switch,
Tooltips' wish-list, your-drops and "New in Forever" lines, ItemFinder's bag view, and PriceMemory's sell speed.
Tests: `cd tests; .\runall.ps1`, 0 failed after the fix.

## Fixed

### BUG (fixed): ItemFinder ignored the hub's Off switch (bag view and tooltip line)
- ItemFinder\ItemFinder.lua `ItemFinder_ShowBags`, `OnTooltip`; no `ForeverHubOnSwitch.ItemFinder`.
- The owner's rule (test_off_hides_frames.lua, xreview_ui.md) is that a helper switched Off on the Manage page
  hides its own frames and adds nothing, without a reload. The round 5 bag view (ItemFinderBagView) came after
  that change and never asked ForeverHub_IsOff.
- Failure: with the bag view open, switching ItemFinder Off left the window on screen; `/find bags` still opened
  it; and without the Tooltips helper, ItemFinder's own "Owned: ..." tooltip line kept appearing while Off.
- Fix: a `SwitchedOff()` check in `OnTooltip` and `ItemFinder_ShowBags` (returns false), and
  `ForeverHubOnSwitch.ItemFinder` closes an open bag view. Saving bags, bank and mail goes on while Off, as for
  every other helper, so switching On shows current data.
- Test: tests\test_full_bags_itemfinder_off.lua (6 failures before, passes now).

## Checked, no defect found

- **ItemAdvisor, priest.** Weapon types (1H mace, staff, dagger, wand) and cloth only match Classic priest rules.
  Shadow is the default role until 5 talent points (a level 11 priest has fewer), with Leveling curves from
  GearCurves. Wand DPS uses the wand weight, healing counts a third as damage for shadow, spell power counts for
  both roles. Off switch: tooltip line and overlay stop, `ItemAdvisor_IsUpgrade`/`_Judge` stay available to other
  helpers (documented).
- **ItemAdvisor_Judge.** Evaluates `"item:<id>"` with inBags/isBound unset, so a quest reward is never called a
  spare copy. Returns nil (ask again) for "still loading" and "Can't read" (combat, hidden worn gear), and those
  answers are not cached. `upgrade` is true for EQUIP and for "Upgrade at level N" (KEEP); `gain`/`percent`
  parse "(+N)" and "(+N, P%)" from all three EQUIP wordings, nil for "fills an empty slot" and "better or equal".
  A future-level 1H beside a worn staff falls back to "compare the pair yourself" (WearableNow is false), so it
  is not counted as an upgrade. Class-forbidden armor gives a NotNeeded verdict (upgrade false).
- **Tooltips, duplicates.** Every line is added from TooltipDataProcessor post-calls (Item, Unit, Quest; Quest is
  `Enum.TooltipDataType.Quest = 23` in TooltipInfoSharedDocumentation). A refresh rebuilds the tooltip from
  scratch, and the wish-list and your-drops lines also check the lines already there. Only GameTooltip and
  ItemRefTooltip get lines, so ItemFinderTooltip and QuestTrackerTooltip (which writes its own "New in Forever"
  line with SetText, not a quest data tooltip) never get a second copy. The Darkmoon "turn-in" line is in
  Events, not Tooltips (out of scope).
- **Tooltips, your drops.** Each corpse counts once per session (1000-GUID ring), each item once per corpse,
  secret GUIDs and non-creature sources (chests, nodes, containers) are skipped, a loot window within 0.6 s of
  your own cast (skinning, pick pocket, opening) is skipped. Saved data is capped at 300 creatures x 25 items,
  trimmed by fewest corpses. The index is rebuilt once per loot, not per tooltip.
- **Tooltips, New in Forever.** Quest ID >= 10000, same rule as QuestCheck and QuestTracker; tag and quest line
  follow the "forever" switch.
- **ItemFinder bag view.** Own frames only, hover-only icons, pool capped at 600, layout on open and 0.3 s after
  data changes (never per frame), search is plain-text. Mail: inbox saved only while the mailbox is open, money
  mail capped at 50, expired entries dropped.
- **PriceMemory sell speed.** Only full lists are compared (row quantities sum to the reported total, own rows
  included in the sum but not compared), within 15 minutes; a missing auction counts only if its least time left
  beat the gap; relists matched by quantity and price; partial commodity buys counted. Watched time is the sum of
  gaps between consecutive full lists, so repeated refreshes are not double counted. Snapshots are memory only
  (30 lists, 500 rows).
- **Rules.**
  - No hooksecurefunc, HookScript, map pins, COMBAT_LOG or CallbackEvent registration (UNIT_SPELLCAST_SUCCEEDED
    and LOOT_OPENED are plain events), print or AddMessage to chat.
  - No sell, buy, equip, use, loot, take-mail, delete or move calls.
  - Blizzard frames are only read; writes go to SlashCmdList and TooltipDataProcessor post-calls only.
  - UIErrorsFrame in BagCheck, DurabilityWatch and SupplyWatch only without the hub (known exception).
  - Values used in arithmetic or comparisons pass through Safe()/Number() (Tooltips, ItemFinder, PriceMemory,
    ItemAdvisor, DurabilityWatch, ManaFull). Bag marks hide in combat; no protected frame is touched.

## NIT (not changed)

- Tooltips "Your drops": a quest-only drop is counted over every corpse you opened, including those looted before
  you had the quest, so its rate (and QuestMobs' "kills left" from it) reads low. Counting per quest state would
  need the quest log at loot time; left as is.
- ItemAdvisor\ItemAdvisor.lua:1483 and 2461: the "loading" test is a plain substring of the reason, and the
  reason "Needed for <quest title>" includes the title. A quest titled with "loading" in it would never be cached
  and `ItemAdvisor_Judge` would keep returning nil for items that quest needs. No such Forever quest is known.
- PriceMemory's sell-speed tooltip line has no switch of its own and also shows with the Tooltips "auction"
  line off (by design: "Tooltips has no sell-speed line").

## Open in-game checks (need the client)

1. Tooltips "Your drops" with auto loot on: are all slots still readable (GetLootSlotLink) when LOOT_OPENED
   reaches us, or has the client already taken some? If items are gone, the corpse is counted without them and
   rates read low; reading on LOOT_READY (documented in LootDocumentation) would then be the fix.
2. PriceMemory: does a commodity result row keep its auctionID between two searches of the same item, and are
   rows grouped by price (CommoditySearchResultInfo has owners/totalNumberOfOwners)? If IDs change per search,
   missing rows are matched as relists only when quantity and price both match, and a partly bought row with a
   new ID would count as fully sold.
3. Recipe tooltips: does the Item post-call fire a second time for the crafted item on the same tooltip? If so,
   Tooltips adds a second block of lines (for the product) under the recipe's.
4. Still open from final_review_bags.md: MAIL_INBOX_UPDATE with the mailbox closed (now guarded), self-mail
   delivery delay, buyoutAmount per auction, own purchases firing the search-updated events.

## Summary

The bags bundle holds up well. One confirmed bug: ItemFinder's round 5 bag view and its own tooltip line did
not follow the hub's Off switch, unlike every other helper with frames; it now closes and stays closed while Off,
covered by a new test. ItemAdvisor's priest verdicts and the new ItemAdvisor_Judge, Tooltips' wish-list,
your-drops and "New in Forever" lines (no duplicates on refresh), ItemFinder's bag view and mail, and
PriceMemory's sell speed all checked out on reading and against the existing tests. No rule breaks beyond the
known UIErrorsFrame exception. Three behaviours need the game client to confirm (auto loot timing, commodity
auction IDs, recipe tooltips).
