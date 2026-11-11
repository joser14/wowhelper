# Final review: ForeverBags bundle

Scope (build.ps1): ItemAdvisor, BagCheck, ItemFinder, PriceMemory, FoodCheck, SupplyWatch, DurabilityWatch,
Tooltips, WindowBadges. Read against research\BRIEF.md. Tests: `tests\runall.ps1`, 0 failed after the fix.

## Fixed

### BUG (fixed): ItemFinder login stops on a saved entry that isn't a character record
- ItemFinder\ItemFinder.lua:715 (login pass over ItemFinderDB). The mail clean-up indexed `record.inbox`
  without checking that `record` is a table; the age check above it does check, and so does every other
  reader (Search, ExpiringMail, OwnRecord, Tooltips).
- Failure: a number or boolean value in ItemFinderDB (an old version, a hand edit, another addon) raised
  "attempt to index a number value" in PLAYER_LOGIN. The rest of the login step was skipped: no tooltip line,
  no bag or gear save until the next bag update, no mail-expiry pop-up.
- Fix: `if type(record) == "table" and ItemFinderDB[other] and (...)`.
- Test: tests\test_final_bags_itemfinder_login.lua (failed before, passes now).

## Checked, no defect found

- **ItemAdvisor, priest verdicts.** Ran a priest at level 30 (shadow and healer, with GearCurves loaded) and
  at 60 (healer) through the r4a mock: staff worn with a main-hand mace and an off-hand orb in bags (pair
  judged against the staff), wand vs wand and vs an empty ranged slot, healing vs spell damage robes,
  off-hand weapon, shield and mail (all "a priest can't wear this"), a one-hand dagger beside a staff. Every
  verdict matched the weights. Weapon types (1H mace, staff, dagger, wand) and armor (cloth) match class
  rules. Spell-scoped hit and crit count for both priest roles. Healing counts a third as damage for shadow;
  damage-only gear is worth nothing to a level-60 healer and is still listed fairly in the reasons.
- **ItemFinder mail expiry.** Expiry is stored as now + daysLeft per mail, expired entries are dropped at
  login and on every rebuild, money-only mails are capped at 50 per character, and inbox entries are bounded
  by the 50-mail, 16-attachment inbox. The warning appears once per login (delayed 8 s) and on top of
  searches; nothing takes, returns or deletes mail.
- **PriceMemory sell speed.** The fields used (auctionID, quantity, timeLeftSeconds, timeLeft band,
  containsOwnerItem, numOwnerItems, buyoutAmount, unitPrice) exist in AuctionHouseDocumentation. Snapshots are
  compared only when the list is complete (quantity sum equals the reported total), within 15 minutes, with
  own auctions and short-band auctions left out and relists matched. Snapshots live in memory only (30
  items, 500 rows). The saved speed resets after 7 days. Every PriceMemory_Get caller (Tooltips, GoldGuide,
  ProfessionGuide) checks `price` before using it, so speed-only records are safe.
- **Rules.**
  - No hooksecurefunc, HookScript, map pins, COMBAT_LOG or CallbackEvent registration, or print.
  - No sell, buy, equip, use or delete calls.
  - Blizzard frames are only read and anchored to. All badges are our own frames on our own overlays.
  - The only additions to Blizzard tables are SlashCmdList entries and TooltipDataProcessor post-calls,
    which every helper in the suite uses.
  - UIErrorsFrame writes in BagCheck, DurabilityWatch and SupplyWatch happen only without the hub: the known
    exception.
  - In combat, ItemAdvisor hides its bag marks and does not cache "Can't read" verdicts. WindowBadges builds
    its pool at login and releases its badges in combat.
- **SavedVariables.**
  - PriceMemory prunes items not seen in 30 days, 14 days of history and 20 suffixes per item.
  - ItemFinder drops characters not seen in 90 days and prunes names to the items held.
  - The other helpers keep only lists the player enters by hand (supplies, keep list, reminders).

## NIT (not changed)

- PriceMemory\PriceMemory.lua:667 Prune drops an entry that has a sell speed but no price (only possible when
  every listing was bid-only), so that speed restarts after a relog. Rare, and harmless.
- PriceMemory\PriceMemory.lua:549 When the realm entry has a speed but no price and an older flat entry
  exists, the flat entry wins and the speed isn't shown. Only affects pre-realm saves.
- DurabilityWatch\DurabilityWatch.lua:159 and SupplyWatch\SupplyWatch.lua:162 test an unwrapped return
  (CanMerchantRepair, GetInventoryItemLink) for truth. The project expects boolean tests of secrets to be
  allowed (perf_audit.md), and neither is a combat-secret value in practice.

## Open in-game checks (need the client)

1. ItemFinder: does MAIL_INBOX_UPDATE ever fire while the mailbox is closed? If it does,
   GetInboxNumItems reads 0 and the saved inbox would be wiped until the next visit. If that happens, add a
   MAIL_SHOW/MAIL_CLOSED guard.
2. ItemFinder: mail with items sent to your own character. Is it delivered at once on Forever, or after an
   hour? Reading the recipient's inbox clears the "incoming" guesses, so mail still on its way would drop out
   of counts until the next inbox read.
3. PriceMemory: is ItemSearchResultInfo.buyoutAmount per auction (assumed) or per unit?
   GetItemSearchResultsQuantity must equal the sum of row quantities, or item speeds are never recorded.
4. PriceMemory: on the AH, do COMMODITY/ITEM_SEARCH_RESULTS_UPDATED fire after your own purchase? If so,
   your own buy counts as a sale. That is acceptable, but worth knowing.

## Summary

The bags bundle is in good shape. One confirmed bug: ItemFinder's login step crashed on a stray non-table
saved entry, which skipped the tooltip registration and the first bag save. It is fixed and covered by a new
test. Priest upgrade verdicts, the round-5 mail-expiry warning and the auction sell-speed logic all held up on
review and in simulation. No rule breaks were found beyond the known UIErrorsFrame exception. Four behaviours
need confirmation in the game client; they are listed above and were not changed.
