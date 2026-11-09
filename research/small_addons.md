# Review: the 18 small helper addons

Scope: !ErrorLog, BagCheck, DurabilityWatch, FoodCheck, GoldGoal, ItemFinder, LevelLog, PriceMemory, ProfessionCap, QuestCheck, RareWatch, RepWatch, RestGuard, SupplyWatch, TalentNudge, TrainerNotes, WeaponSkillWatch, ZoneLevels. Every .lua and .toc was read in full. API names, return shapes, enum values and event names were checked against the generated API docs in `uisrc2` (647 files, almost all `Blizzard_APIDocumentationGenerated`; the only FrameXML sources there are SecureTemplates, three ObjectiveTracker files and QuestMapFrame, so FrameXML-era globals cannot be verified from this corpus and are listed as such below).

How these addons work (matters for the owner's rules): none of them builds a window. Each sends text through `ForeverHub_Receive(source, text)` and registers a `SlashCmdList` handler; ForeverHub (`ForeverHub.lua:739-751`) wraps those handlers so that typing the command opens the hub page, and the hub renders a page by calling the handler under `pcall` with `capture` set (`ForeverHub.lua:101-115`). Alert-style items are exposed through `ForeverHubStatus.<Name>()`. So, with ForeverHub loaded, every feature is a window page, toast or tooltip line. Without it, every addon falls back to chat and to slash commands only.

Severity counts: BUG 0, RULE 1 (cross-cutting, affects all 18), RISK 4, NIT 13.

---

## Cross-cutting

### X1. RULE: chat fallback and slash-only operation whenever ForeverHub is absent
- Files: every `Print()` helper, e.g. `BagCheck.lua:13-18`, `DurabilityWatch.lua:13-18`, `FoodCheck.lua:11-16`, `GoldGoal.lua:25-30`, `ItemFinder.lua:15-20`, `LevelLog.lua:13-18`, `ProfessionCap.lua:30-35`, `QuestCheck.lua:12-17`, `RepWatch.lua:13-18`, `RestGuard.lua:15-20`, `SupplyWatch.lua:15-20`, `TalentNudge.lua:10-15`, `TrainerNotes.lua:12-17`, `WeaponSkillWatch.lua:24-29`, `ZoneLevels.lua:13-18`, `!ErrorLog.lua:16-21`. (RareWatch `RareWatch.lua:15-21` falls back to UIErrorsFrame instead, which is fine.)
- Claim: `if ForeverHub_Receive then ... end; DEFAULT_CHAT_FRAME:AddMessage(...)` means that if ForeverHub is disabled, missing, or errors out of loading, every one of these addons prints to chat on every event and the only way to use a feature is its slash command, which breaks owner rule 2.
- Scenario: user disables ForeverHub in the addon list to debug something; BagCheck then prints "Bags nearly full" to chat on every BAG_UPDATE_DELAYED while bags are full (once per state change thanks to `warned`), FoodCheck/RestGuard/LevelLog/RepWatch become slash-only, PriceMemory and ItemFinder still work through tooltips.
- Fix: declare the relationship and make the fallback silent for page-type output:
  ```
  ## OptionalDeps: ForeverHub      (or ## Dependencies: ForeverHub if the hub is required)
  ```
  ```lua
  local function Print(text)
      if ForeverHub_Receive then return ForeverHub_Receive("BagCheck", text) end
      -- no hub: nothing to show in a window, stay quiet
  end
  ```
  For the few alert-type lines (bags full, gear broken, zone too high, rare nearby) the existing `UIErrorsFrame:AddMessage` path is already UI, so keep that.

### X2. NIT: `UIErrorsFrame:AddMessage` fallback
- Files: `BagCheck.lua:90`, `DurabilityWatch.lua:54`, `ProfessionCap.lua:106`, `QuestCheck.lua:61`, `RareWatch.lua:19`, `SupplyWatch.lua:61`, `ZoneLevels.lua:61`.
- Claim: calling `AddMessage` on UIErrorsFrame is Blizzard's intended addon entry point for on-screen notices; it is a widget method, not a Lua function hook, and it does not taint Blizzard tables. Listed only so the owner knows it was considered against rule 3. No change needed; it only runs when `ForeverHub_Receive` is nil.

### X3. INFO: APIs that cannot be verified from `uisrc2`
These are FrameXML-era globals that the generated docs do not cover. They exist on retail Mainline clients, and the addons mostly guard them with a nil check; the ones called unguarded are marked.
- `GetInventoryItemLink` (DurabilityWatch, ItemFinder, SupplyWatch, WeaponSkillWatch; unguarded, universally present).
- `GetInventoryItemDurability` (`DurabilityWatch.lua:30`, unguarded), `GetRepairAllCost` (`:61`, unguarded), `CanMerchantRepair` (`:73`, unguarded).
- `GetProfessions`, `GetProfessionInfo` (`ProfessionCap.lua:39,44`, unguarded; see P1).
- `GetInventoryItemCount` (`SupplyWatch.lua:31`, unguarded), `GetMerchantNumItems`/`GetMerchantItemID` (`:89-90`, guarded), `INVSLOT_AMMO`/`INVSLOT_RANGED` (defaulted).
- `GetNumTrainerServices`, `GetTrainerServiceInfo`, `GetTrainerServiceCost` (`TrainerNotes.lua:146,162,175`, unguarded), `GetTrainerServiceTypeFilter`, `GetTrainerServiceNumAbilityReq`, `GetTrainerServiceAbilityReq`, `GetTrainerServiceSkillReq`, `IsTradeskillTrainer` (guarded).
- `TooltipDataProcessor.AddTooltipPostCall`, `TooltipUtil.GetDisplayedItem` (ItemFinder, PriceMemory; registration guarded).
- `seterrorhandler`/`geterrorhandler`, `debugstack`, `date` (!ErrorLog; guarded).
- `GetUnspentTalentPoints`, `UnitCharacterPoints` (Classic-only; TalentNudge wraps them in `SafeCall` with a `type(fn) == "function"` check, so a missing global is harmless).
- `NUM_TOTAL_EQUIPPED_BAG_SLOTS` (BagCheck, FoodCheck, ItemFinder; defaulted to `NUM_BAG_SLOTS or 4`; an extra empty bag index only yields 0 slots).
- `SOUNDKIT.RAID_WARNING` (RareWatch; guarded and pcall'd).

Everything else was found in the docs with matching shapes: `C_Container.GetContainerNumSlots/GetContainerNumFreeSlots/GetContainerItemInfo/GetItemCooldown`, `ContainerItemInfo.{itemID,quality,stackCount,hyperlink}`, `C_Item.GetItemInfo` (sellPrice is return 11, classID 12, subclassID 13), `C_Item.GetItemInfoInstant` (classID 6, subClassID 7), `C_Item.GetItemCount`, `C_Item.RequestLoadItemDataByID`, `C_TooltipInfo.GetHyperlink`, `C_SkillInfo.GetSkillLineInfoByID` -> `SkillLineAttributes.{name,rank,maxRank}`, `C_QuestLog.GetNumQuestLogEntries` (numShownEntries, numQuests), `GetMaxNumQuestsCanAccept`, `GetInfo` -> `QuestInfo.{isHeader,isHidden,isTask,suggestedGroup,level,title,questID}`, `IsComplete`, `ReadyForTurnIn`, `IsQuestTrivial`, `C_VignetteInfo.GetVignettes/GetVignetteInfo` -> `VignetteInfo.{name,isDead,onMinimap,atlasName}`, `C_Reputation.GetNumFactions/GetFactionDataByIndex/GetFactionDataByID` -> `FactionData.{factionID,name,currentStanding,reaction,currentReactionThreshold,nextReactionThreshold,isHeader,isHeaderWithRep}`, `C_AuctionHouse.GetBrowseResults` -> `BrowseResultInfo.{itemKey.itemID,minPrice}`, `C_ClassTalents.GetActiveConfigID`, `C_Traits.GetConfigInfo` -> `treeIDs`, `C_Traits.GetTreeCurrencyInfo(configID, treeID, excludeStagedChanges)` -> `{traitCurrencyID,quantity}`, `C_Trainer.GetTrainerType`, `Enum.TrainerType.General = 0`, `C_Map.GetMapLevels` (MayReturnNothing), `GetBestMapForUnit`, `GetMapInfo`, `Enum.UIMapType.Zone = 3`, `Enum.BagIndex`, `Enum.TooltipDataType.Item = 0`, `Enum.ItemQuality.Poor = 0`, `UnitXPMax`, `GetXPExhaustion` (Nilable), `IsResting`, `GetBindLocation`, `UnitUsesAmmo`, `UnitClass` (only `className` is ConditionalSecret; the addons use return 2, `classFilename`), `UnitLevel`, `GetMoney`, `GetRealmName`, `UnitFactionGroup`, `UnitGUID`, `issecretvalue`, `canaccessvalue`.

Events: all registered events exist in the docs: ADDON_LOADED, PLAYER_LOGIN, PLAYER_LOGOUT, PLAYER_ENTERING_WORLD, PLAYER_CAMPING, PLAYER_DEAD, PLAYER_LEVEL_UP (payload 1 = level), PLAYER_MONEY, PLAYER_EQUIPMENT_CHANGED (payload 1 = slot), UPDATE_INVENTORY_DURABILITY, BAG_UPDATE_DELAYED, MERCHANT_SHOW, QUEST_LOG_UPDATE, SKILL_LINES_CHANGED, ZONE_CHANGED_NEW_AREA, VIGNETTES_UPDATED, VIGNETTE_MINIMAP_UPDATED (guid, onMinimap), AUCTION_HOUSE_BROWSE_RESULTS_UPDATED/ADDED, PLAYER_TALENT_UPDATE, TRAIT_CONFIG_UPDATED, TRAIT_CONFIG_LIST_UPDATED, TRAIT_TREE_CURRENCY_INFO_UPDATED, TRAINER_SHOW/UPDATE/CLOSED, TRAINER_SERVICE_INFO_NAME_UPDATE, BANKFRAME_OPENED/CLOSED, PLAYERBANKSLOTS_CHANGED (the last three plus ADDON_ACTION_BLOCKED/FORBIDDEN and LUA_WARNING are additionally pcall'd). No `RegisterEvent` can throw on this client.

Also checked and clean across all 18: no `OnUpdate` scripts, no `hooksecurefunc`/`HookScript`, no `Hide/Show` of Blizzard frames, no protected calls (no sell/buy/repair/use/accept/abandon), no writes into Blizzard tables other than the sanctioned `SLASH_*`/`SlashCmdList.*` registration, no frames created so no position to save. All .toc files use `## Interface: 16001`, list their single file, and declare a SavedVariables entry for every persisted global (`ErrorLogDB`, `GoldGoalDB`, `ItemFinderDB`, `LevelLogDB`, `PriceMemoryDB`, `RepWatchDB` as per-character, `SupplyWatchDB`, `TrainerNotesDB`). `ForeverHubStatus` is a shared runtime table, not persisted, so correctly undeclared.

---

## !ErrorLog

Verdict on the specific asks: it chains Blizzard's handler (`!ErrorLog.lua:58-66`: `previous = geterrorhandler()`, wrapper calls `previous(message, ...)`), so nothing is swallowed; entries are bounded (`MAX_ENTRIES = 50`, stacks cut at 1200 chars, duplicates counted not appended, oldest dropped first); errors before ADDON_LOADED are buffered locally and merged into the SavedVariables with the same bounds (`:99-133`); the three uncertain events are pcall'd (`:95-97`); `Record` is itself pcall'd and reentrancy-guarded (`:48-55`); `LUA_WARNING` is read as the single `warningText` payload the docs specify (`:134-138`) with a fallback for the older two-argument form.

### E1. NIT: Blizzard's handler now runs from an insecure caller
- `!ErrorLog.lua:60-65`.
- Claim: the replacement handler is addon code, so when it calls `previous(...)` Blizzard's `_ERRORMESSAGE`/`HandleLuaError` executes tainted. That is what every error-grabbing addon (BugGrabber etc.) does and it only affects the ScriptErrorsFrame path, which is not secure, so it is acceptable; recorded so the owner knows rule 3 was weighed.
- Fix: none needed. If the owner wants zero interaction with Blizzard's handler, listen only to the events and drop `seterrorhandler`, at the cost of not capturing ordinary Lua errors.

### E2. NIT: a new error produces a chat line when the hub is absent
- `!ErrorLog.lua:43-45`.
- Claim: `Print("Caught an error. It's on the Errors page.")` goes to chat without ForeverHub (X1), and the message references a page that does not exist in that case.
- Fix: covered by X1; guard the line with `if ForeverHub_Receive then`.

### E3. NIT: capture silently stops if another addon installs its own handler later
- `!ErrorLog.lua:58`.
- Claim: `seterrorhandler` is called once at file load (the `!` prefix makes it load first); any later `seterrorhandler` by another addon that does not chain replaces it. Not a bug, just a known limit.
- Fix: optionally re-assert on PLAYER_LOGIN: `if geterrorhandler() ~= ourHandler then previous = geterrorhandler(); seterrorhandler(ourHandler) end`.

---

## BagCheck

No BUG/RISK found. Verified: `GetContainerNumFreeSlots` returns `(numFreeSlots, bagFamily)` and the Blizzard pattern is `bagFamily == 0` for ordinary bags, which `FreeSlots()` follows (`BagCheck.lua:34-41`); a secret return aborts the scan with nil rather than a false "0 free" (`:35-37`); `info.quality` is Nilable and `Safe(nil) == 0` is false, so unknown quality is not junk (`:52`); `select(11, GetItemInfo())` is `sellPrice` (`:55`) with a `RequestLoadItemDataByID` retry. `warned` resets when free slots rise again (`:93`).

### B1. NIT: `MERCHANT_SHOW` junk report depends on `ForeverHubStatus.ItemAdvisor`
- `BagCheck.lua:103`.
- Claim: the check for ItemAdvisor's presence relies on load order only in that ItemAdvisor registers `ForeverHubStatus.ItemAdvisor` at its file load; since MERCHANT_SHOW fires long after all addons load, this is fine. No change.

---

## DurabilityWatch

No BUG/RISK found. Durability loop covers slots 1-18 and skips slots without durability (nil returns); percent only computed when `maximum > 0` (`DurabilityWatch.lua:32`); `warnedTier` only escalates and resets after repair (`:51-57`). `GetRepairAllCost`, `CanMerchantRepair`, `GetInventoryItemDurability` cannot be verified from uisrc2 (X3) and are called unguarded; they are standard Mainline globals.

---

## FoodCheck

No BUG/RISK found. `C_Item.GetItemInfo` destructuring picks positions 1, 5, 12, 13 = name, minLevel, classID, subclassID, which matches the docs (`FoodCheck.lua:43`). Tooltip lines are read via `C_TooltipInfo.GetHyperlink` with `line.leftText` through `Safe()` (`:19-33`). Hub page "Food and drink" renders it; slash is only the hub hook.

### F1. NIT: `RequestLoadItemDataByID(0)` when the item ID is secret
- `FoodCheck.lua:47`: `C_Item.RequestLoadItemDataByID(Safe(info.itemID) or 0)`.
- Claim: passing 0 is a pointless request for a non-item.
- Fix: `local id = Safe(info.itemID); if id then C_Item.RequestLoadItemDataByID(id) end`.

---

## GoldGoal

No BUG/RISK found. SavedVariables declared and keyed per character; `charData` is set at PLAYER_LOGIN (SavedVariables are available from ADDON_LOADED, so this is safe) and every entry point checks it (`GoldGoal.lua:145,153,160`). `PLAYER_LEVEL_UP` payload 1 is the new level and is `Safe()`d (`:146`). `UnitClass` return 2 (`classFilename`) is not ConditionalSecret.

### G1. NIT: skill table indexed without `Safe()` on the table itself
- `GoldGoal.lua:40-41`: `local info = C_SkillInfo.GetSkillLineInfoByID(SKILL_RIDING); local rank = info and Safe(info.rank) or 0`.
- Claim: ProfessionCap (`:54`) and WeaponSkillWatch (`:51`) wrap the returned table in `Safe()` and `type(info) == "table"` before indexing; GoldGoal does not. The docs do not mark `SkillLineAttributes` as secret, so this is a consistency nit, not an expected error.
- Fix: `local info = C_SkillInfo and Safe(C_SkillInfo.GetSkillLineInfoByID(SKILL_RIDING)); local rank = type(info) == "table" and Safe(info.rank) or 0`.

---

## ItemFinder

No BUG/RULE found. Tooltip integration uses `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ...)`, the sanctioned post-call API, and only adds a line to GameTooltip/ItemRefTooltip (`ItemFinder.lua:167-176`), which rule 2 explicitly allows. Bank bags are discovered from `Enum.BagIndex` names containing "bank" but not "account" (`:54-63`), which on this client yields `Characterbanktab` (-2) and `CharacterBankTab_1..9` (6-14); Keyring is excluded. The SavedVariables payload is item-name -> count per container, bounded by inventory size.

### I1. RISK (low): account-wide `ItemFinderDB` never forgets characters
- `ItemFinder.lua:188-191`.
- Claim: every character ever logged in keeps a `bags`/`bank`/`gear` record forever; deleted or renamed characters are never pruned, and `Search()` iterates all of them on every query and `OwnedElsewhereText()` on every item tooltip.
- Scenario: a player who rerolls often ends up with dozens of stale records; tooltips show "Owned: OldToon 3" for characters that no longer exist, and the search output fills with them.
- Fix: store `lastSeen = time()` per character at PLAYER_LOGIN and drop entries older than, say, 90 days; or add a "forget character" command on the Find page.

### I2. NIT: `Characterbanktab` (-2) is scanned as a container
- `ItemFinder.lua:56-61`.
- Claim: `Enum.BagIndex.Characterbanktab = -2` matches the "bank" filter; it is the tab-purchase pseudo-container and will report 0 slots. Harmless, only extra calls.
- Fix: skip `bag < 0`.

---

## LevelLog

No BUG/RISK found. Time is banked on PLAYER_LEVEL_UP, PLAYER_LOGOUT and each page render (`LevelLog.lua:35-40`), SavedVariables are per character and bounded by level (<= 60 entries). `levels[currentLevel]` at `:74` exists because `BankTime()` just created it. Slash/page guards `levels` for calls before login (`:87`).

### L1. NIT: `Entry()` does not back-fill fields from older saves
- `LevelLog.lua:30-33`.
- Claim: `levels[level] = levels[level] or {...}` only defaults a missing entry; a saved entry lacking `deaths` or `seconds` (hand-edited or from a future field rename) would make `entry.deaths + 1` / `entry.seconds + ...` error. The current code always writes both fields, so this is hardening, not an observed failure.
- Fix: `local e = levels[level] or {}; e.seconds = e.seconds or 0; e.deaths = e.deaths or 0; levels[level] = e; return e`.

---

## PriceMemory

No BUG/RULE found. It only reads `C_AuctionHouse.GetBrowseResults()` on the two browse events, never sends queries. `minPrice` is BigUInteger (a Lua number) and the `> 0` comparison is on a `Safe()`d value (`PriceMemory.lua:56-58`). Tooltip line via the sanctioned post-call.

### PM1. RISK (low): `PriceMemoryDB` grows without bound and is never pruned by age
- `PriceMemory.lua:54-62`, `.toc:5` (`## SavedVariables: PriceMemoryDB`, account-wide).
- Claim: every item ID ever seen in a browse result is kept forever, per realm-faction, plus the legacy flat entries under numeric keys at the root. Nothing is deleted.
- Scenario: a player who browses the AH daily on two factions accumulates one record per distinct item per side; the data is small per entry (two numbers) so it will not hit the SavedVariables size limit on a Classic-era item pool, but stale prices from months ago keep showing with "seen 120d ago".
- Fix: at PLAYER_LOGIN, drop entries whose `seen` is older than N days:
  ```lua
  local cutoff = time() - 30 * 86400
  for scope, prices in pairs(PriceMemoryDB) do
      if type(prices) == "table" then
          for id, e in pairs(prices) do
              if type(e) == "table" and (tonumber(e.seen) or 0) < cutoff then prices[id] = nil end
          end
      end
  end
  ```

---

## ProfessionCap

### P1. RISK (low): `GetProfessions()` / `GetProfessionInfo()` called with no existence check
- `ProfessionCap.lua:39,44`, run on PLAYER_LOGIN, SKILL_LINES_CHANGED, PLAYER_LEVEL_UP and the Professions page.
- Claim: these FrameXML-era globals are not in the generated docs (X3). If either is absent on this client the addon errors on PLAYER_LOGIN ("attempt to call a nil value"). The author's comment at `:9` ("GetProfessions has no First Aid position") suggests it was observed working, so this is unverifiable rather than likely wrong. The return order used (name, texture, rank, maxRank, numAbilities, spellOffset, skillLine) matches Mainline's `GetProfessionInfo`.
- Fix: `if not (GetProfessions and GetProfessionInfo) then return list end` at the top of `ReadProfessions()`; if the globals turn out to be missing, `C_SkillInfo.GetSkillLineInfoByID` (already used for First Aid) can be looped over the known profession skill-line IDs instead.

Otherwise clean: `CheckCaps(_, _, eventLevel)` correctly reads the PLAYER_LEVEL_UP level as arg1 of the (self, event, arg1) handler; `warned` is keyed by name+cap+level-state and rebuilt each pass so a cap warns once per state (`:96-112`).

---

## QuestCheck

No findings beyond X1. `GetNumQuestLogEntries` returns `(numShownEntries, numQuests)`; the index loop uses return 1 and the "used" count return 2, matching the docs (`QuestCheck.lua:21,32`). All `QuestInfo` fields read exist. `CheckLog` runs two cheap calls per QUEST_LOG_UPDATE. No quest action is ever called.

---

## RareWatch

No findings beyond X2. `VIGNETTE_MINIMAP_UPDATED` payload `(vignetteGUID, onMinimap)` is handled (`RareWatch.lua:88-98`); `VignetteInfo.{name,isDead,onMinimap,atlasName}` all exist; `GetVignettes()` returns a table and is `or {}`-guarded; `PlaySound` is pcall'd; repeat alerts are throttled to 300 s per name and only on first sighting of a GUID. `announced`/`active` are session tables bounded by rares seen.

---

## RepWatch

### R1. NIT: `BAG_UPDATE_DELAYED` used as the trigger to re-baseline reputations
- `RepWatch.lua:123,137`.
- Claim: bag changes have nothing to do with reputation; the intent (keep adding factions that appear after login) is better served by `UPDATE_FACTION`, which exists on this client (`PaperDollInfoDocumentation.lua`). Each bag update currently walks every faction plus a `GetFactionDataByID` per remembered-but-collapsed faction.
- Fix: replace `events:RegisterEvent("BAG_UPDATE_DELAYED")` with `events:RegisterEvent("UPDATE_FACTION")`.

Otherwise clean: ADDON_LOADED used for the per-character `RepWatchDB.seen` (declared `SavedVariablesPerCharacter`), `seen` is bounded by faction IDs, headers without rep skipped via `isHeaderWithRep`, threshold arithmetic only on `Safe()`d values with nil checks (`:82-85`), `FACTION_STANDING_LABEL<n>` is read, not written.

---

## RestGuard

No findings beyond X1. `GetXPExhaustion` is Nilable and additionally secret-checked (`RestGuard.lua:33-37`); `C_Container.GetItemCooldown` exists and `MayReturnNothing` is handled by the `start and duration` check (`:55-59`); `C_Item.GetItemCount` guarded; PLAYER_CAMPING exists and the warning goes to the hub toast.

---

## SupplyWatch

No BUG/RISK found. `GetItemInfoInstant` positions 6/7 = classID/subClassID match the docs (`SupplyWatch.lua:80,101`). `charData` is assigned on PLAYER_LOGIN and checked before every use, including `ForeverHubStatus.SupplyWatch` (`:225`). The "add" command expects an item link; ForeverHub's Supplies page converts the typed name to a link before calling it (`ForeverHub.lua:257-258`, `SupplyCommand`), so the hub hint "Water 20" works. Watched list is user-bounded.

### S1. NIT: old `charData.items` entries are not validated at login
- `SupplyWatch.lua:205-206`.
- Claim: `items` is accepted as-is; an entry missing `min` or `id` (older format or hand edit) makes `supply.count < supply.min` at `:58` error on the first BAG_UPDATE_DELAYED. Current code always writes both, so hardening only.
- Fix: in the PLAYER_LOGIN branch, drop entries where `type(item.id) ~= "number" or type(item.min) ~= "number"`.

---

## TalentNudge

No findings. This is the model for handling uncertain APIs: `C_ClassTalents.GetActiveConfigID`, `C_Traits.GetConfigInfo`, `C_Traits.GetTreeCurrencyInfo` (all present, with the documented `treeIDs` and `{traitCurrencyID, quantity}` shapes) and the Classic-only `GetUnspentTalentPoints`/`UnitCharacterPoints` are all wrapped in `SafeCall` which checks `type(fn) == "function"`, pcalls, and `Safe()`s the result (`TalentNudge.lua:17-23`). Events all exist. It announces only when the count rises (`:66-69`).

---

## TrainerNotes

### T1. RISK: `GetTrainerServiceInfo` return order cannot be verified and differs from the FrameXML signature
- `TrainerNotes.lua:162-163`: `local name, serviceType, _, level, subText = GetTrainerServiceInfo(index)`; `:171`: `level = math.max(level or 1, 1)`.
- Claim: Blizzard_TrainerUI on both Mainline and Classic clients reads this API as `serviceName, serviceSubText, serviceType, isExpanded = GetTrainerServiceInfo(i)` and gets the level from `GetTrainerServiceLevelReq(i)`. The addon assumes a 5-return `(name, serviceType, ?, level, subText)` form. The Forever TrainerUI source is not in uisrc2 (0 hits for any `GetTrainerService*`), so I cannot say which is right; the author's comment at `:107-108` refers to "Blizzard's TrainerUI", so they may have read Forever's.
- Scenario if the FrameXML order applies: `serviceType` holds the rank text, `level` holds the boolean `isExpanded`, and `math.max(true, 1)` raises "bad argument #1 to 'max' (number expected, got boolean)" on every TRAINER_SHOW/TRAINER_UPDATE, so nothing is ever saved and the Trainer page stays empty. This would have been obvious in testing, which is why it is RISK not BUG.
- Fix: make the read defensive regardless of which order is live:
  ```lua
  local r1, r2, r3, r4, r5 = GetTrainerServiceInfo(index)
  local name = Safe(r1)
  local serviceType, subText, level
  if type(Safe(r3)) == "string" and (r3 == "available" or r3 == "unavailable" or r3 == "used" or r3 == "header") then
      subText, serviceType = Safe(r2), r3                     -- FrameXML order
      level = GetTrainerServiceLevelReq and Safe(GetTrainerServiceLevelReq(index))
  else
      serviceType, level, subText = Safe(r2), Safe(r4), Safe(r5)   -- order assumed today
  end
  level = type(level) == "number" and math.max(level, 1) or 1
  ```
  Or simply confirm in game with `/dump GetTrainerServiceInfo(1)` at a class trainer and keep whichever branch is correct.

### T2. NIT: `TotalCost` assumes every saved service has a numeric `cost`
- `TrainerNotes.lua:211-217`, data written at `:175` (always a number) but migrated records from "older versions" (`:279`) are only filtered by `level`.
- Claim: an old record without `cost` makes `total + service.cost` error when the Trainer page or `ReportLevelUp` runs.
- Fix: `total = total + (tonumber(service.cost) or 0)`, and in the PLAYER_LOGIN migration also drop records where `type(service.name) ~= "string"`.

Otherwise clean: `GetNumTrainerServices`/`GetTrainerServiceCost` are called unguarded (X3) while the rest are guarded; `openTrainer` is read once per window from `UnitGUID("npc")`; purchase detection never buys anything; SavedVariables are per character and bounded by the trainer lists.

---

## WeaponSkillWatch

No findings. `C_SkillInfo.GetSkillLineInfoByID` return wrapped in `Safe()` and type-checked (`WeaponSkillWatch.lua:51-52`); `GetItemInfoInstant` positions correct; `PLAYER_EQUIPMENT_CHANGED` payload 1 is the slot and is `Safe()`d before indexing `WATCHED_SLOTS` (`:127-128`); `UnitClass` return 2 is not secret. `warned` is rebuilt per pass so a low skill warns once until it recovers.

---

## ZoneLevels

No findings beyond X1/X2. `C_Map.GetMapLevels` is `MayReturnNothing`; `Safe(nil)` -> nil -> `ReadLevels` returns nil (`ZoneLevels.lua:21-27`). `Enum.UIMapType.Zone = 3` matches, and the parent climb stops at Zone or above (`:40-52`). `lastWarned` is cleared when leaving a dangerous zone so re-entry warns again (`:60-67`).

---

## Summary

The 18 helpers are in good shape against the brief: no BUG was found, nothing performs a gameplay action, nothing hooks or hides Blizzard frames, no OnUpdate is used, every registered event exists on this client (and the uncertain ones are pcall'd), every documented C_ API call matches the uisrc2 shapes, and every persisted global is declared in its .toc with bounded growth except the two account-wide caches (PriceMemoryDB, ItemFinderDB) that never prune. The one owner-rule issue is structural rather than per-addon: each helper is only "UI only" because ForeverHub exists; with the hub absent or disabled they all revert to chat output and slash commands, so the dependency should be declared and the chat fallback removed. The one item worth checking in game is TrainerNotes' assumed `GetTrainerServiceInfo` return order, which cannot be confirmed from the docs on hand and would error on trainer open if the FrameXML order applies; ProfessionCap's unguarded `GetProfessions` is the same class of unverifiable global. The remaining items are small hardening nits (RepWatch's odd BAG_UPDATE_DELAYED trigger, GoldGoal's unwrapped skill table, FoodCheck's `RequestLoadItemDataByID(0)`, and defaulting fields when reading older saves).
