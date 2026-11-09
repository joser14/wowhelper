# Auctionator v343: feature reverse-engineering for the Forever suite

Scope: a read-only pass over `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\Auctionator`. I listed all 697 files (about 330 .lua). I read the toc, every manifest-relevant flavor folder header, all of `Source\` core (Database, Variables, Config, Tooltips, API v1, CraftingInfo, PostingHistory, Groups, Shopping, Search, SlashCmd), all of `Source_ModernAH\` scanning, selling, cancelling, buying and data-provider logic, `Source_Mainline\` (CraftingInfo, Enchant, Initialize), `Source_Forever\`, the relevant `Source_Classic\` files for comparison, and `Locales\enUS.lua` as the feature index. Nothing was run, copied or modified. No code is reproduced here: mechanisms are described in my own words, and no data tables were extracted. I did not touch the WTF folder (saved-data size was skipped, as the brief allows).

Note: the addon folder contains `AGENTS.md`, which objects to AI tools using the repository as reference. The user saw this objection and told the coordinator to proceed with a reverse-engineering at feature level only. This report keeps to that.

---

## 0. Which code path Forever actually runs

**Verdict: the modern `C_AuctionHouse` path (`Source_ModernAH` + `Source_Mainline` + `Source_Forever`). The legacy Browse/QueryAuctionItems path (`Source_LegacyAH`) is not loaded.**

Evidence:

1. **Toc load tags** (`Auctionator.toc`, lines 28-51):
   - `Libs_ModernAH`, `Imports_ModernAH`, `Assets_ModernAH`, `Source_ModernAH` load only for game types `cata, mists, mainline`.
   - `Source_Mainline` loads for `mainline`. `Source_Classic` loads for `classic`.
   - `Source_LegacyAH`, `Source_Vanilla`, `Data_Vanilla\Suffixes.lua` and the TaintLess patch load for `vanilla, tbc, wrath`.
   - `Source_Forever\Constants.lua` loads with *Allow camelot* and *Exclude classic, standard*. So the Forever client reports the game type "camelot", and the authors expect it not to also match `classic`.
2. **Code that only runs on Forever lives exclusively in the modern/mainline folders.** `IsForever` checks appear in `Source_ModernAH\Tabs\Selling\Mixins\SaleItem.lua`, `Source_ModernAH\Selling\ItemPrice.lua`, `Source_ModernAH\Tabs\Buying\Commodity\Mixins\Main.lua`, `Source_ModernAH\Config\Mixins\SellingAllItems.lua` and `Source_Mainline\CraftingInfo\Professions.lua`. `Source_LegacyAH` has none. Shipping Forever branches in files that never load on Forever would make no sense, so camelot is treated as part of the `mainline` family.
3. **Flavor constants** (`Source\Constants\Main.lua`):
   - `IsRetail` is true for `WOW_PROJECT_MAINLINE` *or* `WOW_PROJECT_CAMELOT` (commented as a temporary fix).
   - `IsForever` is "build between 16000 and 19999".
   - `IsLegacyAH` is true only for `WOW_PROJECT_CLASSIC` or when `IsUsingLegacyAuctionClient()` exists and returns true.
   - `Libs_ModernAH\LibAHTab` also accepts `WOW_PROJECT_CAMELOT`.
4. **Blizzard UI dump** (`scratchpad\uisrc2`, 647 files, almost all API documentation). It contains no `WOW_PROJECT_*` constants, no `AllowLoadGameType` docs and no `IsUsingLegacyAuctionClient`, so the tag mapping can't be proven from it directly. What it does show supports the verdict:
   - Camelot is a mainline-family flavor: `LootConstants_Mainline` defines `LootConsts_Camelot`, and there is `QuestLogConstsMainlineCamelot` and `LevelConstsExposed_Camelot`.
   - `C_AuctionHouse` is documented with `Environment = "All"`, including `GetBrowseResults` and `ReplicateItems`.
   - The documented events include all the modern AH events and no legacy `AUCTION_ITEM_LIST_UPDATE`.

   This agrees with PriceMemory already working via `C_AuctionHouse.GetBrowseResults`.

**What Forever therefore gets:**
- Modern tabs (Shopping, Selling, Cancelling, Auctionator/Info) added to `AuctionHouseFrame` via LibAHTab.
- Commodity and item search screens.
- `REPLICATE` full scan and "summary" browse full scan.
- The mainline Professions-frame crafting info.
- The mainline disenchant table, which covers only Warlords of Draenor and later, so **no disenchant value on Forever**. The classic Prospect/Mill/Disenchant code in `Source_Classic` never loads.
- Forever-specific constants: auction durations 2/8/24 h instead of 12/24/48.

---

## 1. Feature inventory

Legend:
- **Read-only equivalent?** Y = can be done fully read-only. Y* = needs changes (e.g. passive reading of player-made searches only). N = needs sending queries, posting, buying, cancelling, or hooking Blizzard frames.
- **Size:** S = under ~80 lines, M = ~80-300 lines, L = more than 300 lines.

### 1.1 Price database (core of everything)

**Storage.** Saved variable `AUCTIONATOR_PRICE_DATABASE`, account-wide. Top level holds `__dbversion` (currently 8) plus one entry per *AH scope key*.

**Scope key** (`Source_ModernAH\Variables\Main.lua`):
- If `RegionalUniqueNamesEnabled()` is true, the key is the realm **ruleset** name. It is chosen from `C_GameRules.IsGameRuleActive` checks in this order: RP+PvP first, then PvP, then RP, then Hardcore, else PvE. The v343 changelog line is exactly about splitting out RP-PvP. This is very likely the Forever case: region-wide realms whose AH is shared per ruleset.
- Otherwise it takes `GetAutoCompleteRealms()`, sorts it, and uses the first name, so every connected realm shares one bucket. With no connections it falls back to `GetNormalizedRealmName()`.
- **Faction is never part of the key.** The modern AH is treated as cross-faction.
- On first use of a new key, it migrates data stored under the un-normalized realm name or under any connected realm's name.

**Per-realm storage format.** To keep login parsing cheap, only the current realm's table is kept as a live table. Other realms are serialized to CBOR strings (one realm per login tick), using `C_EncodingUtil.SerializeCBOR` when present, else LibCBOR. On `PLAYER_LOGOUT` the current realm is serialized as well.

**Per-item record** (`Source\Database\Mixin.lua`), four fields keyed by item:
- `m`: the last seen minimum unit price, which is what the tooltips show.
- `h`: per day, the *highest* minimum seen that day.
- `l`: per day, the *lowest* minimum seen that day. To save memory this is only stored when it differs from `h`.
- `a`: per day, the *highest available quantity* seen that day.

Days are counted as integers since 2020-01-01, stored as string keys so the data is valid JSON. Each write prunes days older than `price_history_days` (default 21).

**Item keys** (`Source\Utilities\DBKeyFromLink.lua`, `Source_ModernAH\Utilities\DBKeyFromBrowseResult.lua`):
- Plain item ID as a string.
- `p:<speciesID>` for caged battle pets.
- For gear at item level 168 or higher, a primary key `g:<itemID>:<ilvl>` with the plain ID as fallback.

Every lookup takes the *first* key in a list that has a price, so the specific key wins and the generic key is the fallback. On the legacy path, gear with a random suffix gets `gr:<itemID>:<suffix name>`, using the suffix tables in `Data_Vanilla`/`Data_Cata`. **On Forever (modern path) suffixes are ignored entirely**, and classic item levels never reach 168. Every key is therefore the bare item ID, and all "of the Bear/Eagle/..." variants collapse into one minimum. PriceMemory does the same.

**Aggregation on scan** (`ProcessScan`):
- Results are grouped by key.
- The minimum unit price across all rows becomes the day's sample.
- The sum of available quantity becomes the day's `a`.
- Work is done in batches of about 350 keys per frame on a 0-second ticker, so the client doesn't hitch.

**Derived values:**
- *Price*: the latest minimum, `m`.
- *Age*: days since the newest `h` day.
- *Mean*: the average over the last N days (default 21) of each day's low, falling back to the high. The fallback is broken because it looks the day up with a number while days are stored as strings. Days with a single observation (only `h` stored) are therefore *skipped*, and the "mean" is really the mean of the volatile days only. Worth knowing; don't copy it.
- *History list*: newest first, each row with date, low, high and available quantity.
- *IsAuctionDataExact*: whether the item ID itself has a price, as opposed to only a fallback key.

**Read-only equivalent for PriceMemory:** Y (M). See section 3.

### 1.2 How prices get into the database

| Source | Mechanism | Sends queries? | Read-only for us |
|---|---|---|---|
| **Incremental (passive)** `IncrementalScan\Mixins\Frame.lua` | Always registered for `AUCTION_HOUSE_BROWSE_RESULTS_UPDATED` / `_ADDED`. UPDATED re-reads `GetBrowseResults()`, but only when the list holds 500 or fewer entries (the summary batch size), because UPDATED also fires on later price refreshes of a single item. ADDED uses the event payload (only the new rows). Rows with `totalQuantity` 0 are skipped. Each row's `minPrice` and `totalQuantity` go into the day aggregation. **This captures every browse search, including the player's own Blizzard-UI searches.** | No (passive part) | **Y**. PriceMemory already does this. |
| **Summary full scan** (same file) | Sends an empty-string browse query and keeps calling `RequestMoreBrowseResults` until `HasFullBrowseResults`. Fires on a button or autoscan; the interval defaults to 15 min and autoscan is off by default. Progress is estimated against the database size. | Yes | N (we never send). Passive piggyback is already covered by the row above. |
| **Replicate full scan** `FullScan\Mixins\Frame.lua` | Calls `C_AuctionHouse.ReplicateItems()` with a 15-minute cooldown tracked in saved state. Waits for `REPLICATE_ITEM_LIST_UPDATE`, then walks `GetNumReplicateItems()` in batches of 250 every 10 ms. Each auction gives `GetReplicateItemInfo` (count, buyout and the "has all info" flag), `GetReplicateItemLink` and `GetReplicateItemTimeLeft`. Items with missing data are loaded via `C_Item.RequestLoadItemDataByID` + `ITEM_DATA_LOAD_RESULT` and retried every 0.4 s; IDs that don't exist are dropped. Unit price is buyout divided by count. A 2-second safety timer finishes the scan if some items never load. Closing the AH aborts it. | Yes | N to start. **Y\*** to *read*: if the player starts a full scan (e.g. with Auctionator's button), a passive listener on `REPLICATE_ITEM_LIST_UPDATE` could read the same replicate list without sending anything. This is optional and depends on Auctionator being installed. M. |
| **Selling-tab search** `SaleItem.lua` | When an item is chosen to sell it sends `SendSearchQuery`, or `SendSellSearchQuery` for gear, with the item level zeroed. On the commodity result it saves the first row's `unitPrice`; on the item result it saves the first row's `buyoutAmount` (or bid). | Yes (Auctionator sends) | **Y\***. The same `COMMODITY_SEARCH_RESULTS_UPDATED` / `ITEM_SEARCH_RESULTS_UPDATED` events fire when the *player* clicks a browse row in the Blizzard UI or uses the Blizzard sell frame, so we can read `GetCommoditySearchResultInfo(itemID, 1)` / `GetItemSearchResultInfo(itemKey, 1)` passively. **PriceMemory misses this source entirely.** S-M. |
| **Own post** `SaleItem.lua` PostItem | After posting, if nothing was listed or the new price is below the previous lowest, it stores the posted unit price as the new minimum. | It posts | Y\*: observe `AUCTION_HOUSE_AUCTION_CREATED` after a *player* post, or skip this. Low value. S. |
| **Vendor price cache** `Source\CraftingInfo\Main.lua` | On `PLAYER_INTERACTION_MANAGER_FRAME_SHOW` for a merchant (skipped on tournament realms), it walks the merchant items. For items with unlimited stock (`numAvailable == -1`) and a non-zero price it stores price divided by stack size in `AUCTIONATOR_VENDOR_PRICE_CACHE`, and deletes the entry when the item is no longer sold that way. Used by crafting cost as "vendor price beats AH price". | No | **Y** (S). Very useful for GoldGuide crafting cost (thread, vials, flux, dyes). |

### 1.3 Tooltip lines (`Source\Tooltips\Main.lua`, `Hooks.lua`)

**Wiring.** On clients with `TooltipDataProcessor`, one post-call is registered on `Enum.TooltipDataType.Item`. It only acts on `GameTooltip`, `GameTooltipTooltip`, `ItemRefTooltip`, or tooltips named with the `NotGameTooltip*` / `RSMap*` conventions. It skips forbidden tooltips and those whose info has `excludeLines`. It then reads `tooltip.info` (or `processingInfo`), takes `getterName`, swaps the leading "Get" for "Set", and dispatches to a per-source handler table with `getterArgs`.

This is the key technique: **the getter name and args tell you exactly where the item came from, so the stack count can be recovered.**

**Handlers cover:**
- bag slot (count via `C_Item.GetStackCount` on an ItemLocation)
- merchant item and buyback (stack from merchant info)
- inventory/bank slots
- guild bank
- loot slot and loot roll
- quest reward and quest-log reward/choice
- send-mail and inbox attachments
- trade (player and target side)
- old `SetAuctionItem`
- `SetItemKey` (AH browse rows, using `C_TooltipInfo.GetItemKey` to get a link, with a fix-up because recipe keys can return the crafted item's link)
- `SetItemByID`, `SetItemByGUID`, `SetHyperlink`
- tradeskill reagent/result (classic and Dragonflight-style)

Outside the post-call, they `hooksecurefunc` `InboxFrameItem_OnEnter` for multi-attachment mail totals, `BattlePetToolTip_Show` for caged pets, and some `Professions` tooltip builders.

**Lines (each togglable):**
- **Vendor**: shown when the item is vendorable (sell price above 0, not an artifact, and not legendary unless it is a reagent). The value is `sellPrice × count` when stack display is active. On non-retail clients it clears Blizzard's money line first.
- **Auction**: the first-key price × count, or "unknown". **Suppressed for bound items**: bind type other than none, on-equip or on-use, or account-bound-until-equip.
- **Auction Mean** (default off): N-day mean × count.
- **Auction Age** (default off): "N days", or "unknown" when there is a price but no history.
- **Disenchant** (default off): the expected value is the sum, over the possible materials for the item's expansion and quality, of the probability of each drop amount × amount × the material's AH price. Shown as "unknown" when it is disenchantable but a material price is missing. **On Forever this never produces a value**, because the table is mainline (WoD+).
  - Classic, which doesn't load on Forever: a table keyed by class, quality and item-level band. Lesser essences are priced at the lower of their own price and a third of the greater essence. Shift shows a per-material breakdown.
- **Prospect / Mill**: classic only, not loaded on Forever.
- **Stack math**: by default values are multiplied by the stack count only while Shift is held. An inverted option makes the stack total the default view.
- **Mail multi-attachment**: hovering an inbox row with more than one attachment lists every attachment with its own lines plus "Total N items" and the summed auction value.
- **Pet cage**: the `p:<species>` price via a small lib that adds lines to `BattlePetTooltip`.

**For us:** Y for everything except the inbox-row hook and pet-tooltip hook (those are hooks: N, or Y\* if we only handle the per-attachment item tooltip, which does go through the post-call). The stack and getter technique and the bound-item suppression are S changes to our `Tooltips.lua`. Disenchant needs our own Forever-era disenchant table (M, data authored ourselves).

### 1.4 Shopping tab and shopping lists

**Search string format.** A single string of semicolon-separated fields, in order:
- search text (wrapped in quotes means exact match)
- category key
- min/max item level
- min/max required level
- min/max crafted level
- min/max price in gold
- quality
- tier (crafting quality)
- expansion
- quantity

It can be parsed to and from a table (`SplitAdvancedSearch` / `ReconstituteAdvancedSearch`) and prettified into a bracketed summary plus a tooltip breakdown.

**Search execution** (modern path):
- Sends a browse query with the text, level range, quality filter, class filters and sort (by name, then price descending), and keeps requesting more results.
- Every returned row goes through post-filters before it is shown: item level, exact name (via `GetItemKeyInfo`), crafted level, price, tier, expansion. A small tracker counts outstanding async filters per row.
- Results show min price, name, item level, owned flag and available quantity.
- Optional "missing terms" rows show 0 available.
- Results can be exported to CSV in a copy box.
- On Forever, the item dialog hides the Tier/Expansion controls.

**Lists.** `AUCTIONATOR_SHOPPING_LISTS` is an array of `{name, items = {search strings}, isTemporary}`, sorted case-insensitively. Temporary lists are pruned at login. Lists can be created, renamed, deleted, made permanent, reordered by drag, and searched all at once; auto-search on select is on by default.

**Recents.** `AUCTIONATOR_RECENT_SEARCHES`, most recent first, deduplicated, capped at 30.

**Import/export:**
- Current format: one line per list, `name^item^item`.
- Old format: `*name` followed by one item per line.
- TSM group strings `i:123,p:456`: resolved to names asynchronously in batches of 250, then saved to a temporary list.
- "Whisper to" export also exists.

**Link-to-search.** A `hooksecurefunc` on `ChatFrameUtil.InsertLink` / `ChatEdit_InsertLink`: shift-clicking an item while the Shopping tab is visible runs an exact search.

**Public API** (`Auctionator.API.v1`): `MultiSearch`, `MultiSearchExact`, `MultiSearchAdvanced`, `CreateShoppingList`, `GetShoppingListItems`, `Delete`/`AlterShoppingListItem`, `Convert{To,From}SearchString`, `GetAuctionPriceBy{ItemID,ItemLink}`, `GetAuctionAgeBy*`, `IsAuctionDataExactBy*`, `GetVendorPriceBy*`, and `RegisterForDBUpdate` (fires after incremental processing or a full scan).

**For us:**
- **Y** for a *shopping list UI* that only stores wanted items and target prices, then shows "last seen price / age / below target?" from PriceMemory (M, new helper or part of GoldGuide).
- **N** for running the searches.
- **Y\*** for highlighting list items when the *player's* own browse results include them (S on top of PriceMemory).

### 1.5 Selling tab

**Bag view and groups:**
- `AUCTIONATOR_SELLING_GROUPS` holds `{Version, CustomGroups = [{name, type, list of item links, hidden}], HiddenItems}`. Favourites is always group 1.
- Default groups are generated per item class. On Forever the vanilla class list is used, and bag IDs are 0-5.
- A bag cache (`Source\Groups\BagCache.lua`) rebuilds on `BAG_UPDATE` (throttled through OnUpdate) only while a consumer has it switched on.
- It groups slots by a composite key of item ID, name, item level, quality and auctionable flag. "Auctionable" comes from `C_AuctionHouse.IsSellItemValid`. On classic it is instead: not bound, full durability, and consumables at full charges.
- Each slot waits on item data with cancellable continuables.

**Price selection:**
1. The database price for the item's keys is used at once.
2. Otherwise, gear with no price uses an optional vendor multiplier: `sellPrice × multiplier + deposit` (default multiplier 0, meaning off).
3. A search then runs.
   - **Commodity:** take the first row. If that row contains the player's own auction (owner "player"), keep its price (don't undercut yourself). Otherwise apply the undercut rule.
   - **Item:** take the first row that matches the selected matching rule (id+level+suffix by default, or id only, name only, or id+level). If it already contains the player's auction, keep its buyout. Otherwise apply the undercut rule.
   - **Undercut rule:** either a percentage (default 0%, i.e. match the price) or a fixed copper amount. Clamped to at least 1 silver on retail and at least 1 copper on Forever.
4. Price normalisation: retail rounds up to whole silver. **Forever does no rounding.** One side effect: a percentage undercut can produce fractional copper on Forever, since it isn't floored.

**Safety checks before posting:**
- *Below vendor*: confirm if `vendor × qty` is more than `price × qty × 0.95`.
- *Unusually low*: for commodities, walk the results until 20% of the total quantity (capped at 5000 units) is reached. The unit price there sets the threshold: 30%-70% of it, scaling from 70% at 1g down to 30% at higher prices. Posting at or below the threshold asks for confirmation.

**Other selling features:**
- Default quantity per item class (gear and pets 1, everything else max).
- Deposit via `CalculateCommodityDeposit` / `CalculateItemDeposit`.
- Duration labels relabeled to 2/8/24 h on Forever.
- Post / skip / previous keybinds via `SetOverrideBinding`.
- Optional auto-advance to the next bag item.
- Reselect the last item on reopen.
- Chat log of posts.
- Current / Realm history / Your history sub-tabs.
- Item locking while selected.

**For us:** N for posting. **Y** for an *advisory* pane in our own window: "suggested price = latest seen min (or own if you're lowest) minus your undercut; vendor beats AH; looks unusually low". This works from PriceMemory and any player-made search results (M). The low-price threshold curve and the below-vendor check are pure functions (S each) and directly reusable in GoldGuide.

### 1.6 Posting history ("Your History")

`AUCTIONATOR_POSTING_HISTORY` maps each key to a list of `{price, quantity, bidPrice, time}`.
- Fed by Auctionator's internal `AuctionCreated` event, so only posts made through Auctionator are recorded.
- Entries on the same day at the same price are merged by summing quantities.
- Each key keeps the last 10 entries (configurable).
- Bid price is dropped on the legacy path.

**For us:** Y\* (S-M). Listen to `AUCTION_HOUSE_AUCTION_CREATED` after the *player* posts. Price and quantity then need to come from `OWNED_AUCTIONS_UPDATED` / `GetOwnedAuctionInfo` the next time the player views their auctions; the event carries only the auctionID. Useful to GoldGuide as "what you usually list at".

### 1.7 Cancelling tab and undercut scan

- **Listing:** `QueryOwnedAuctions` with sorting. The rows come from `GetNumOwnedAuctions` / `GetOwnedAuctionInfo`, with item names resolved through the item-key loader.
- **What is shown:** status 0 rows are active; status 1 rows are sold and pending delivery. The tab shows "Total on sale" (Σ price × qty over active rows) and "(pending)" (Σ over sold rows). Rows with a bidder sort first, ordered by bid.
- **Refresh triggers:** `AUCTION_CANCELED`, `OWNED_AUCTIONS_UPDATED`, `AUCTION_HOUSE_NEW_BID_RECEIVED`.
- **Undercut scan:** walks the owned auctions one at a time. It skips sold auctions, bid-only auctions, auctions with a bidder, WoW Tokens and (optionally) gear/pets, and reuses results per item key. For each item it searches and counts the quantity listed ahead of the player's first auction. The auction counts as undercut when that quantity is above the "items ahead" allowance (default 0). Undercut auctions are queued and cancelled one per keypress (SPACE by default) or `/atr cu`.

**For us:**
- N for the search and the cancel.
- **Y** for a read-only "My auctions" summary: on `OWNED_AUCTIONS_UPDATED`, which fires when the *player* opens the Blizzard Auctions tab, read every owned auction and show active count/value, sold-pending gold and soonest expiry in our window (S-M, GoldGuide).
- **Y\*** for "possibly undercut": compare each owned unit price with the latest PriceMemory minimum for that item and flag a lower price that is not the player's own (S). This is passive and approximate.

### 1.8 Buying

- **Commodities:** shows the result rows; the player types a quantity. The unit price is the weighted average of the cheapest rows, rounded up to whole silver (whole copper on Forever).
  - A wide-range warning appears when the most expensive selected row is at least 50% above the cheapest.
  - It then runs `StartCommoditiesPurchase` → `COMMODITY_PRICE_UPDATED`, compares the quoted price to the expected price (with a "price increased" prefix), then shows a final confirmation or a type-the-quantity-again dialog.
- **Items:** a list of single auctions with buy dialogs.
- The tooltip helper also computes a *median unit* (price at half of the selected quantity), though it is unused.

**For us:** N for buying. **Y** for the pure math: given the player's own commodity search results, "cost to buy N" = cumulative sum of row quantity × price, plus the spread warning. This is a nice GoldGuide or shopping-list read-out (S).

### 1.9 Crafting info (Professions frame, `Source_Mainline\CraftingInfo`)

Adds a frame under `ProfessionsFrame.CraftingPage.SchematicForm`. The customer-orders page is skipped on Forever.

- **Cost:**
  - For each reagent slot, the allocated reagents are costed at their unit price.
  - Unit price per item is the vendor-cache price if known, else the AH price.
  - Any mandatory quantity still unallocated is costed at the cheapest priced option.
- **Profit:** `floor((AH price of output × number made × 0.95 − cost) / 100) × 100`, i.e. rounded down to whole silver.
  - Enchanting recipes map to an output item through a spell→item table and add the vellum vendor price.
  - Classic (not loaded) uses the same formula without the silver rounding.
- **Warnings appended:**
  - "not exact item" when the price came only from a fallback key
  - "no price data" when there is no age
  - "at least 10 days old" when age is over 10 days
- **Reagent search button:** builds exact search terms for the output and each basic reagent (quantity × craft count) and opens them as a temporary shopping list. This sends queries, so N for us.
- **Objective-tracker button:** the same for all tracked recipes, summing quantities.
- **Refresh:** registers for database updates and re-renders.

**For us:** Y (M). A read-only "craft cost / profit" panel in GoldGuide or ProfessionCap, using `C_TradeSkillUI` read APIs on `TRADE_SKILL_SHOW` and our prices. The 5% cut, the vendor-before-AH rule and the three warnings are exactly the right model. It must be our own frame, not attached to `ProfessionsFrame`, or parented without hooks if that is allowed.

### 1.10 Config and other

- **Options UI:** Basic, Shopping, Selling (all items, shortcuts, quantities), Cancelling, Tooltips, Profile (per-character config copy), Advanced (no price DB).
- **Default tab:** configurable.
- **Small tabs:** option for crowded AH tab bars.
- **Debug:** a DBKey line on tooltips when debug is on.
- **Slash commands** (`/atr`): post, cancelundercut, reset db/timer/config (debug only), nopricedb, config get/set, version, help.
- **Addon-message prefix:** registers an "Auctionator" prefix for whisper export.
- **Splash screen:** version gating.

### 1.11 Forever-specific code (all of it)

1. `Source_Forever\Constants.lua`: durations Short/Medium/Long = 2/8/24 h. Labels only; the internal values stay 12/24/48 and map to the API's duration 1/2/3.
2. `Source_ModernAH\Config\Mixins\SellingAllItems.lua`: rewrites the duration radio labels 12→2, 24→8, 48→24.
3. `SaleItem.lua` price normalisation: no silver rounding and no 1-silver floor on Forever.
4. `Selling\ItemPrice.lua`: undercut result floored at 1 copper on Forever. It also references an undefined `IsClassic` flag, which is harmless.
5. `Buying\Commodity\Mixins\Main.lua`: unit price rounded up to the copper, not the silver.
6. `Source\Tabs\Shopping\Mixins\Item.lua`: Tier/Expansion search fields hidden on Forever.
7. `Source_Mainline\CraftingInfo\Professions.lua`: no crafting frame on the customer-orders page.
8. `Source\Groups\Constants.lua`: Forever uses bag IDs 0-5 and the vanilla item-class group list.
9. `Source\Constants\Main.lua`: `IsForever` by build range; `IsRetail` includes CAMELOT, which is why the retail disenchant table applies and DE shows nothing.
10. `Source_ModernAH\Variables\Main.lua` (v343): ruleset-segmented DB key when regional unique names are on.

---

## 2. Feature → our suite mapping

| Auctionator feature | Read-only? | Our helper | Size |
|---|---|---|---|
| Daily price history (min/max/available) with pruning | Y | PriceMemory | M |
| Item/commodity search-result capture (player clicks a row) | Y\* | PriceMemory | S-M |
| Ruleset / connected-realm DB key | Y | PriceMemory (+ shared accessor) | S |
| Store `totalQuantity` | Y | PriceMemory | S |
| Use the ADDED payload; 500-row UPDATED guard | Y | PriceMemory | S |
| Vendor *buy* price cache (merchant, unlimited stock, price/stack) | Y | PriceMemory or new small table | S |
| Stack-aware auction line; getter-based stack count for more sources | Y | Tooltips | S |
| Hide auction line for bound items | Y | Tooltips | S |
| Auction age in days / "unknown" | Y | Tooltips (already shows age) | done |
| Mean / median over N days | Y | Tooltips + PriceMemory | S after history |
| Disenchant expected value (Forever-era table) | Y | Tooltips (+ new data file) | M |
| Mail attachments total | Y\* (per-attachment only; no inbox hook) | Tooltips | S |
| Shopping list UI (targets, last-seen, below-target flags) | Y\* | GoldGuide or new "Wishlist" | M |
| Selling advisor (suggested price, below-vendor, too-low threshold) | Y (advisory) | GoldGuide / BagCheck | M |
| My-auctions summary (on sale, pending gold, expiring) | Y\* | GoldGuide | S-M |
| "Possibly undercut" flag vs latest minimum | Y\* | GoldGuide | S |
| Posting history (player posts) | Y\* | PriceMemory / GoldGuide | S-M |
| Craft cost / profit with warnings | Y | GoldGuide or ProfessionCap | M |
| Commodity "cost to buy N" from player's own results | Y\* | GoldGuide | S |
| Bag value at AH vs vendor | Y | BagCheck (+ ItemFinder IDs) | S-M |
| Full scans (replicate/summary), searches, posting, buying, cancelling, undercut scan | N | — | — |
| Passive read of a player-started replicate scan | Y\* (optional) | PriceMemory | M |
| Link-click → search, inbox/pet/profession hooks | N (hooks) | — | — |

---

## 3. PriceMemory comparison (file:line refs are to our code)

### What PriceMemory does today

`PriceMemory\PriceMemory.lua`:
- **:85-88** listens to `AUCTION_HOUSE_BROWSE_RESULTS_UPDATED` and `_ADDED`.
- **:47-63** on *either* event re-reads all of `GetBrowseResults()`. It keeps the cheapest `minPrice` per item ID within that read and **overwrites** `prices[id] = {price, seen}`.
- **:26-32** scope key is `GetRealmName()` + `-` + player faction.
- **:93-108** prunes entries older than 30 days at login.
- **:65-83** adds one tooltip line, "Auction, seen <age>: <price> each", on GameTooltip/ItemRefTooltip.

`Tooltips\Tooltips.lua`:
- **:218-250** re-implements the same scope key and adds "Auction <price> (<age>)", per unit only.
- **:132-155** recovers stack count for bag/loot/inventory/buyback only.
- **:213** only the vendor line uses the stack.

### Data sources and events Auctionator reads that PriceMemory misses

1. **`COMMODITY_SEARCH_RESULTS_UPDATED` (itemID)** → `GetCommoditySearchResultInfo(itemID, i)`. Gives exact unit prices per price row, quantity per row and owner flags. Fires when the player clicks a commodity in Blizzard's browse list or puts one in the sell frame. Gives *depth* (how many units at each price), which browse data can't.
2. **`ITEM_SEARCH_RESULTS_UPDATED` (itemKey)** → `GetItemSearchResultInfo(itemKey, i)`. Per-auction buyout/bid, itemKey including **itemSuffix** and level, itemLink and timeLeft. This is the only place where random-suffix variants come apart with their own prices.
3. **Browse `totalQuantity`**: read by Auctionator, ignored by PriceMemory (`:54-61` keeps only `minPrice`).
4. **Owned auctions**: `OWNED_AUCTIONS_UPDATED` → `GetOwnedAuctionInfo` (status active/sold, buyout/bid, quantity, timeLeftSeconds, bidder).
5. **Own posts**: Auctionator stores its own posted price as a new low. The read-only analogue is `AUCTION_HOUSE_AUCTION_CREATED`.
6. **Replicate list**: only when the player starts one; optional.
7. **Vendor buy prices**: merchant scan, not an AH source, but they complete cost calculations.
8. **AH mail (sold/expired)**: *Auctionator does not read mail for prices either*. It only prices mail attachments on tooltips. If we want "sold for" history, it is a new idea (inbox `GetInboxInvoiceInfo` is read-only) and has no Auctionator precedent.

### Realm/faction keys

- **Auctionator:** connected-realm root (sorted first auto-complete realm), or the **ruleset name** (`PvE`/`PvP`/`RP`/`RPPvP`/`HC`) when `RegionalUniqueNamesEnabled()`. **No faction.** It migrates old keys automatically.
- **PriceMemory (`:26-32`):** the realm name as shown, plus the player's faction.
- **Risks:**
  - (a) If Forever uses regional unique names, as v343 strongly suggests, characters on different "realms" of the same ruleset share one AH, but PriceMemory splits them.
  - (b) Connected realms are split the same way.
  - (c) If the Forever AH is cross-faction, as Auctionator assumes, the faction split halves the data. The faction split *would* be correct for classic-style faction AHs, and wrong for the neutral goblin AH either way.
  - The APIs Auctionator uses (`RegionalUniqueNamesEnabled`, `C_GameRules.IsGameRuleActive`, `GetAutoCompleteRealms`) are all present in the Forever API dump. `Enum.GameRule` member names weren't in the dump: verify them in game.
- **Recommendation:** build the key as Auctionator does (ruleset, connected root or realm), and add faction only if an in-game check shows faction AHs. Check: the same commodity searched on an Alliance and a Horde alt within minutes gives different lists. Keep reading old keys as a fallback, as `:76-79` already does for flat entries.

### Item keys with suffixes and item levels

Auctionator on the modern path uses the bare item ID (ilvl keys only at 168+). On Forever this is effectively identical to PriceMemory's item-ID key, including collapsing suffix variants to the cheapest (`:57`). Auctionator's lookup pattern is a list of keys, most specific first, falling back to generic. Copy that pattern if we add `id:suffix` entries from item-search results. The tooltip then tries the suffix key parsed from the hovered link before the bare ID. Verify in game that the link's suffix field equals `itemKey.itemSuffix` on Forever; I can't confirm this from the files.

### How Auctionator estimates "market" price

It doesn't do anything clever. "Price" is the **most recent minimum unit price**. "Mean" is a simple N-day average of daily lows, and it has the key-type bug described in 1.1. The day high/low/available history is shown only as a table. Its only robustness logic is the selling-side **low-price threshold**: the price at 20% cumulative depth, times 0.3-0.7. So PriceMemory can match it with history and beat it with a median.

### Ranked improvements

1. **Keep a per-day history instead of overwriting** (`PriceMemory.lua:60`). M.
   - Store a day index (days since a fixed epoch), the day's lowest minimum, the day's highest minimum and the max `totalQuantity`, plus `last` and `seen` for compatibility with Tooltips.
   - Prune days older than 21-30 days on write, so the current login pruning at `:93-108` becomes per item.
   - This unlocks age in days, trend and median, and fixes a single odd cheap listing permanently replacing a normal price.
   - Avoid Auctionator's mean bug by storing both fields for every day.
2. **Capture item/commodity search results** (new events next to `:87-88`). S-M.
   - On `COMMODITY_SEARCH_RESULTS_UPDATED`, record row 1's `unitPrice` and Σ quantity, and optionally the price at 20% depth as a robust "market".
   - On `ITEM_SEARCH_RESULTS_UPDATED`, record row 1's buyout per item ID, and per `id:suffix` when the suffix is non-zero.
   - Purely passive: these only fire after a search the player (or the Blizzard UI) made.
3. **Fix the scope key** (`:26-32`; duplicated at `Tooltips.lua:218-224`). S.
   - Use the ruleset / connected-root logic from section 3.
   - Expose one global accessor, e.g. a PriceMemory "get price" function returning price, ageDays, available, low/median and isOlderSave.
   - Make Tooltips and GoldGuide use only that accessor, never `PriceMemoryDB` directly (`Tooltips.lua:231`). Also migrate the old keys on first use.
4. **Handle events precisely** (`:113-115`). S.
   - On ADDED, process only the payload (the added rows).
   - On UPDATED, re-read only when the list is at most one batch (Auctionator uses 500), because UPDATED also fires for later single-item price refreshes.
   - Skip rows with `totalQuantity == 0`.
5. **Save `totalQuantity`.** S. Lets tooltips/GoldGuide say "thin market (3 listed)" and weight confidence.
6. **Add a vendor buy-price cache.** S. On merchant show, store price/stack for unlimited-stock items, and remove the entry when the item is no longer sold that way. GoldGuide craft cost should prefer vendor over AH, as Auctionator does.
7. **Confidence flags for consumers.** S. Return "exact vs fallback" (suffix-specific vs generic ID), age in days, and "stale > 10 days" (Auctionator's profit-warning cutoff). GoldGuide should display these next to any profit figure.
8. **Owned-auction summary** (passive on `OWNED_AUCTIONS_UPDATED`). S-M. Gives GoldGuide "gold on the AH", "sold, awaiting mail" and "expiring soon".
9. **Optional robust market value.** S once 1+2 exist. Median of the last 7 daily lows, and/or the 20%-depth commodity price. Flag a current minimum below 30-70% of it (Auctionator's sliding threshold) as "suspiciously cheap".
10. **Optional: passive replicate read.** M. Only if the player runs a replicate scan via another addon. Low priority.

### Tooltips / GoldGuide usage of prices (specific)

- **`Tooltips.lua:249`**: multiply the auction value by the stack count (reuse `StackCount` from `:132`) and show "each" plus "xN: total", as the vendor line does at `:213`.
  - Extend `StackCount` (`:144-153`) with the getters Auctionator handles: `GetMerchantItem`, `GetGuildBankItem`, `GetInboxItem`, `GetSendMailItem`, `GetTradePlayerItem`/`GetTradeTargetItem`, `GetQuestItem`/`GetQuestLogItem`, `GetLootRollItem`.
  - Same mechanism: read `info.getterName`/`getterArgs` and call the matching read-only count API.
- **`Tooltips.lua:230-250`**: skip the auction line when the item is bound (bind type not none/equip/use), as Auctionator does. Currently a soulbound quest reward could show a stale price for an unrelated listing.
- **`Tooltips.lua:218-228`**: replace the duplicate scope logic with the PriceMemory accessor (improvement 3).
- **`PriceMemory.lua:65-83` vs `Tooltips.lua:174-193`**: two auction lines can still appear when PriceMemory's own line is enabled and Tooltips' de-duplication misses localisation or format changes. Prefer one owner: PriceMemory provides data only, and Tooltips draws the line.
- **GoldGuide** (being written):
  - Value AH sales at price × 0.95, after the AH cut.
  - Compare against vendor × count (the below-vendor rule).
  - Mark a price missing or older than 10 days as a warning, not a number.
  - For crafting, cost = Σ (vendor price if cached else AH price) × quantity; profit = output AH × number made × 0.95 − cost.
  - Use "available" to avoid recommending crafting into a flooded market.
- **BagCheck / ItemFinder**:
  - A "bag worth" read-out: per slot, use the higher of vendor and AH × 0.95, skipping bound items.
  - Needs item IDs. ItemFinder currently stores counts by *name* (`ItemFinder.lua:30-41`); storing the ID alongside would let Tooltips/GoldGuide join counts with prices without name lookups.

---

## 4. Notable techniques worth borrowing (all read-only-compatible)

1. **Stack count from tooltip processing info.** Map `info.getterName` ("GetX" → "SetX") plus `getterArgs` to a per-source handler that knows how to read the count. This covers bags, merchant, buyback, mail, trade, loot, quests and guild bank without any hook.
2. **Most-specific-first key list with generic fallback**, plus an "exact" flag for consumers.
3. **Day-bucketed min/max/available history** with string day keys, pruning on write, and storing low only when it differs from high.
4. **Batch-size guard on browse UPDATED** (500), so later single-item refreshes aren't mistaken for a new search.
5. **Item-data loading pattern.** Request data for the item ID, wait for `ITEM_DATA_LOAD_RESULT`, re-request every 0.4 s, and give up after 2 s so one bad ID can't stall the whole job.
6. **Chunked processing on a 0-second ticker** (250-500 items per frame) for any big table walk, e.g. ItemFinder or bag valuation.
7. **CBOR-serialise other realms' data** (`C_EncodingUtil.SerializeCBOR` exists on this client) to keep SavedVariables parse time low. Only worth it if PriceMemoryDB grows large.
8. **Pricing heuristics:**
   - 5% AH cut.
   - Below-vendor check.
   - Sliding "too low" threshold: 70% of the reference at 1g, falling to 30% for expensive items, with the reference taken at 20% depth.
   - Commodity "cost to buy N" walk and a spread warning at ≥50%.
   - Profit rounded down to the silver, with age/exact/missing warnings.
9. **Merchant price cache**: unlimited-stock items only, price divided by stack size, entry removed when no longer sold that way, skipped on tournament realms.
10. **Connected-realm / ruleset scope key** that migrates old keys on first use.

## 5. Things Auctionator does that we must not copy

These are outside our rules:
- sending browse, search or replicate queries
- `QueryOwnedAuctions`
- posting, buying, cancelling, `LockItem`
- `SetOverrideBinding` keybinds
- `hooksecurefunc` on `InsertLink`, `ContainerFrameItemButton_OnClick`, `HandleModifiedItemClick`, `InboxFrameItem_OnEnter`, `BattlePetToolTip_Show` and `Professions` builders
- parenting frames into `AuctionHouseFrame` / `ProfessionsFrame` and clicking Blizzard tabs
- clearing Blizzard's money line on tooltips
