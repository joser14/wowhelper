# Review: ItemAdvisor, ForeverHub, ForeverHelper

Files reviewed in full:
- `ItemAdvisor\ItemAdvisor.lua` (1253 lines, v0.2.9)
- `ForeverHub\ForeverHub.lua` (851 lines, v0.1.4)
- `ForeverHelper\ForeverHelper.lua` (309 lines, v0.1.4)

APIs were checked against `scratchpad\uisrc2` (Blizzard_APIDocumentationGenerated) and `scratchpad\uisrc` (Mainline ContainerFrame.lua, QuestInfo.lua/.xml, QuestFrame.lua). Where a function is not in either (legacy globals such as `GetInventoryItemLink`, `GetProfessions`, `GetQuestItemInfoLootType`, SharedXML `TooltipUtil`/`TooltipDataProcessor`), that is stated and the finding is limited to what the code does with the value.

## The logged error (ItemAdvisor.lua:402, 2026-11-04)

"attempt to index field '?'" is Lua's message for `t[k].x` with a variable key `k`. In the current file the only expressions of that shape on the gear path are `ARMOR_TYPES[playerClass][subClassID]` (ItemAdvisor.lua:438) and `WEAPON_TYPES[playerClass][subClassID]` (:443), reached from `UseLevel` <- `EvaluateGear` <- `Evaluate` <- `ScanBags`/`OnTooltip`. They fail when `playerClass` is not a key of those tables (nil before login, or a class token the tables don't know). The current file already guards this at :1197-1201 (falls back to `"WARRIOR"`), and every hub entry point now checks `charData` first (`HandleSlash` :824, `ItemAdvisor_IsUpgrade` :1225, `ForeverHubStatus.ItemAdvisor` :1234). I could not reproduce the error on the current code.

The ForeverHub frames in the stack (old 131/162/318/641/666/690) correspond to today's `RunCommand` (:108 pcall) <- `RenderPage` (:166) <- `OnShow` (:311) / `OpenPage` (:373) <- the slash wrapper (:746). The call was inside `pcall`, and the hub re-raised through `geterrorhandler()` (:112), which is why it shows in the log; the hub itself kept working and showed "Something went wrong here" on the page. Failure isolation is correct. See findings 8 and 9 for the two gaps in it.

## Findings (most severe first)

### 1. RULE (medium) - ItemAdvisor hooks Blizzard bag frames and draws into Blizzard buttons
`ItemAdvisor.lua:1131` `bagFrame:HookScript("OnShow", ScheduleRepaint)` on every `ContainerFrameContainer.ContainerFrames[i]` and `ContainerFrameCombinedBags`. `:917`/`:924` `button:CreateTexture(...)` on Blizzard `ContainerFrameItemButton`s; `:1014-1016` `CreateFrame("Frame", nil, button)` + `SetFrameLevel` parented to `QuestInfoRewardsFrame.RewardButtons[i]`.
- Owner rule 3 says no hooks on Blizzard functions and no Blizzard frame manipulation. `HookScript` is a hook (post-hook, so it does not taint the original handler, but it is still a hook); adding regions/children to Blizzard frames changes their render tree. The file comment (:897) says "no hooks on Blizzard functions", which is literally true but not the spirit of the rule.
- Verified against `uisrc\...Mainline__ContainerFrame.lua:2339` (`ContainerFrameContainer.ContainerFrames`), `:564` (`self.Items`), `:1826/:1846` (`button.bagID or parent:GetID()` matches Blizzard's own `GetBagID`), and `uisrc\...Mainline__QuestInfo.xml:423/448` (`QuestInfoRewardsFrame`, `parentArray="RewardButtons"`), `QuestInfo.lua:781` (`type = "choice"`), `:530` (`SetID(index)` = choice index). The reads are correct; only the writes are the rule issue.
- Fix (stays read-only): parent the badges to an addon-owned frame and anchor them to the Blizzard button instead of creating them on it:
  ```lua
  local overlay = CreateFrame("Frame", nil, UIParent)  -- one per addon, strata "HIGH"
  local arrow = overlay:CreateTexture(nil, "OVERLAY")
  arrow:SetPoint("TOPLEFT", button, "TOPLEFT")        -- anchoring to a Blizzard frame is a read
  ```
  Replace `HookScript("OnShow")` with the existing 1 s poll pattern or with the events the addon already has (`BAG_UPDATE_DELAYED`) plus a check of `bagFrame:IsShown()` inside `PaintBags` (already there, :991). Badges on a hidden bag are harmless, so losing the OnShow trigger only costs a 0.1 s repaint on the next event.

### 2. RISK (medium) - Full bag evaluation runs far more often than needed (hub tick, repaint, and tooltip refresh)
- `ForeverHub.lua:433` calls `ForeverHubStatus.ItemAdvisor` (ItemAdvisor.lua:1233) on every dirty tick; it runs `ScanBags` (:748), i.e. `Evaluate` for every bag slot. `rowsDirty` is set by `BAG_UPDATE_DELAYED`, `PLAYER_MONEY`, `PLAYER_XP_UPDATE`, `QUEST_LOG_UPDATE`, `UPDATE_INVENTORY_DURABILITY` (ForeverHub.lua:828-842) and by every `ForeverHub_Receive` (:713), so while looting it is a full scan once per second (combat is skipped at :781).
- Each gear `Evaluate` does: `GetItemInfo` x~6, `C_Item.GetItemStats` x~8 (`Score` at :647, `BestGain` -> `Score`+`SlotScore`, `StatChanges` -> 2x `ReadStats`, `ReadStats` again at :655), `C_TooltipInfo.GetHyperlink` x2 uncached (`HasRedLine` :451, `IsUnique` :465; only `ReadPercents` is cached), and `InEquipmentSet` (:422) iterates all sets. Nothing is memoised per item.
- At the same time ItemAdvisor's own `ScheduleRepaint` (:1192) runs `PaintBags` + `RefreshRewardMarks` for the same events, and `GET_ITEM_INFO_RECEIVED` (:1157) triggers a repaint for *every* item the client loads (auction house browsing, chat links, other addons' requests), not only items this addon asked for.
- Hovering a bag item: Blizzard sets `self.UpdateTooltip = ContainerFrameItemButtonMixin.OnUpdate` (`uisrc\...ContainerFrame.lua:1655`), so GameTooltip re-runs `SetBagItem` on its update interval and `OnTooltip` (:866) re-runs the whole `Evaluate` each time while the mouse rests on an item.
- Fix: cache `Evaluate` results keyed by `link .. (isBound and "1" or "0")`, invalidate the cache on `BAG_UPDATE_DELAYED`, `PLAYER_EQUIPMENT_CHANGED`, `PLAYER_LEVEL_UP`, `LEARNED_SPELL_IN_SKILL_LINE`, `QUEST_LOG_UPDATE` and role change; have `ForeverHubStatus.ItemAdvisor` return the summary from the last scan instead of rescanning; track requested item IDs in `RequestItem` and only `ScheduleRepaint` on `GET_ITEM_INFO_RECEIVED` when the event's `itemID` is in that set:
  ```lua
  local pendingItems = {}
  local function RequestItem(link) local id = ...; if id then pendingItems[id] = true; C_Item.RequestLoadItemDataByID(id) end end
  -- OnEvent: elseif event == "GET_ITEM_INFO_RECEIVED" then if pendingItems[arg1] then pendingItems[arg1] = nil; ScheduleRepaint() end
  ```

### 3. RISK (low) - `GetInventoryItemLink` results are compared and pattern-matched without `Safe()`
`ItemAdvisor.lua:486-487` (`worn:match`), `:495-496`, `:559-564`, `:581-582`, `:623` (`GetInventoryItemLink(...) == link`). `GetInventoryItemLink` is not in `uisrc2` at all (legacy global), so whether Forever ever returns a secret here cannot be confirmed from the docs; every other game read in the file goes through `Safe()`, and this is the one that runs in combat (hovering a bag item in combat reaches `OnTooltip` -> `Evaluate` -> these lines; `PaintBags` skips combat at :985 but `OnTooltip` does not). A secret string in `worn:match(...)` or `==` errors.
- Fix: one wrapper and use it everywhere:
  ```lua
  local function WornLink(slot) return Safe(GetInventoryItemLink("player", slot)) end
  ```
  and in `OnTooltip` return early when `InCombatLockdown()` if you prefer not to evaluate in combat at all.

### 4. BUG (low) - A spell-only stat key hides the physical tooltip percent for the same stat (and vice versa)
`ItemAdvisor.lua:365` sets `fromGame[stat] = true` even when the key's scope was rejected at :361 (e.g. profile `warrior`, key `ITEM_MOD_CRIT_SPELL_RATING_SHORT` -> stat `crit`, scope `spell`). The tooltip pass at :371-377 then skips a "+1% chance to get a critical strike" line for `crit` because `fromGame.crit` is set, so the item scores no crit at all for a physical role.
- Fix: move `fromGame[stat] = true` inside the `if scope == "any" or ...` block.

### 5. BUG (low) - ForeverHelper session gold starts from 0 when `GetMoney()` is unreadable at login
`ForeverHelper.lua:56` `session.startMoney = Safe(GetMoney()) or 0`. If the value is secret/nil at `PLAYER_LOGIN`, every later `RefreshStats` (:84-88) reports the whole purse as "earned this session" and an enormous "/hr". `GetMoney` has no secret flag in `uisrc2\...PlayerScriptDocumentation.lua:642`, so this is only reachable if Forever hides it; ForeverHub already handles the same case correctly (ForeverHub.lua:410-413).
- Fix: leave `startMoney` nil and set it on the first readable value, as the hub does; show "Gold: n/a" until then.

### 6. BUG (low, memory) - `lastShown` in ForeverHub grows for the whole session
`ForeverHub.lua:51`, written at `:731` for every distinct message text, never pruned. Messages contain numbers and item links ("Sell 3 item(s) for 1g 2s", "Quest reward: take [link]..."), so nearly every message is a new key. Not SavedVariables, but it is the one unbounded table in the hub over a long session (`alerts` is capped at :721, `xpSamples` is windowed at :384).
- Fix: prune in `ForeverHub_Receive` before inserting:
  ```lua
  for key, when in pairs(lastShown) do if now - when >= REPEAT_SECONDS then lastShown[key] = nil end end
  ```

### 7. NIT (memory) - `percentCache` in ItemAdvisor is unbounded
`ItemAdvisor.lua:168/:331` caches a table per full item link (includes enchant/suffix/uniqueId) for every item ever evaluated, including tooltips for AH and chat links. Small per entry, but never cleared. Fix: cap it (clear when `count > 2000`) or key by `itemID .. ":" .. suffixID`.

### 8. RISK (low) - A status source that returns a non-table escapes the hub's per-addon pcall
`ForeverHub.lua:433-437`: the `pcall(source)` protects the call, but `ipairs(result or {})` runs outside it. A helper returning a string or number raises "bad argument #1 to 'ipairs'" out of `GatherStatus`, which `Attempt(RefreshRows)` (:783) catches, so the *entire* row refresh for every addon is lost until the next dirty event, defeating the per-addon isolation. Fix: `if ok and type(result) == "table" then ... elseif ok then --[[ignore]] elseif not quietStatus then geterrorhandler()(result) end`.

### 9. RISK (low) - `Start()` has unprotected steps after `Attempt(BuildPanel)`
`ForeverHub.lua:813` `OnTick()` and `:781` `panel:IsShown()` run without `Attempt`; if `BuildPanel` failed (its error is swallowed at :799), `OnTick` errors out of `Start`, `C_Timer.NewTicker` at :823 is never created and the hub is dead for the session with one logged error. Fix: `Attempt(OnTick)` at :813 and :821, and guard `panel and panel:IsShown()` in `OnTick`.

### 10. RULE (low) - ForeverHub overwrites other addons' entries in the global `SlashCmdList`
`ForeverHub.lua:748` `SlashCmdList[key] = wrappers[key]` for 18 keys. `SlashCmdList` is a Blizzard table, and this replaces other addons' handlers (a hook on other addons, not on Blizzard code). It works, re-wrap is idempotent (:742), and `RunCommand` keeps the original. Two side effects worth knowing: a helper that re-registers its command later than one frame after `PLAYER_LOGIN` (:818) is not re-wrapped until the next login, and `/fh` alone no longer toggles the ForeverHelper window (the wrapper opens the hub page instead; the page hint tells the user to type "window"). If the owner wants rule 3 kept literally, the alternative is for each helper to call `ForeverHub_Receive` directly (they already do) and leave `SlashCmdList` alone.

### 11. RULE (low) - ForeverHub changes a game CVar at every login
`ForeverHub.lua:791-793` `C_CVar.SetCVar("accessibilityScreenNarrationEnabled", "0")`. The comment says the owner asked for it, but it is a persistent settings write in an addon described as "only shows information", it re-applies every login, and it belongs in no hub feature. `SetCVar` exists (`uisrc2\...CVarDocumentation.lua:131`). Fix: remove, or gate it behind a `db.disableNarration` flag that defaults to nil.

### 12. RULE (low) - Chat output and slash-only features when the hub is absent
`ItemAdvisor.lua:181` and `ForeverHelper.lua:21` fall back to `DEFAULT_CHAT_FRAME:AddMessage` whenever `ForeverHub_Receive` is nil, and without the hub the only way to change the ItemAdvisor role (`/ia role`), see raw stats (`/ia stats`), or add/remove ForeverHelper tasks (`/fh add|remove`) is a slash command. With the hub loaded both addons comply (hub window input box, toasts). If the addons are meant to be usable standalone, the fallback should be a small frame, not chat; otherwise mark the hub as a hard dependency in the .toc (`## Dependencies: ForeverHub`) so the fallback path is never taken.

### 13. NIT - Misleading "train it" message for class-locked items
`ItemAdvisor.lua:675-676`: `HasRedLine` is the only class-restriction check (`UseLevel` :433 only knows armor/weapon proficiency), and the message says "you may need to train it". For a "Classes: Paladin" line this is wrong advice to a mage. Fix: look for `ITEM_CLASSES_ALLOWED` ("Classes: %s") in the red line text and say "for another class" in that case. Verdict (CHECK) is safe either way.

### 14. NIT - Hub window draws the Bag advice page (full scan) on every open
`ForeverHub.lua:370` selects `TABS[1]` = Bag advice, and `OnShow` (:307) renders it, so toggling the window runs ItemAdvisor's `ShowScan` each time. Fine functionally; combine with finding 2's cache to make it cheap.

## Checked and found correct

- Read-only: no `UseContainerItem`, `EquipItemByName`, `PickupContainerItem`, `SellCursorItem`, `BuyMerchantItem`, `RepairAllItems`, `AcceptQuest`, `GetQuestReward`, `CompleteQuest`, `hooksecurefunc` anywhere in the three files (grep). All three only read and draw.
- Item data loading: every `C_Item.GetItemInfo` nil result requests the item (`RequestItem` :222, `C_Item.RequestLoadItemDataByID` exists, `uisrc2\...ItemDocumentation.lua:1710`) and returns a loading verdict; `GET_ITEM_INFO_RECEIVED` and `ITEM_DATA_LOAD_RESULT` both exist (`:1815`, `:1857`); the addon uses the former. `ReadStats` (:340-346) correctly distinguishes "not loaded" from "no stats" by checking `GetItemInfo`. `GetItemStats` is `MayReturnNothing` (`:1006`) and is handled.
- `GetItemInfo` return positions used (3 quality, 5 minLevel, 9 equipLoc, 11 sellPrice, 12 classID, 13 subclassID, 14 bindType) match `uisrc2\...ItemDocumentation.lua:638-651`.
- Safe(): `UnitLevel`, `UnitXP/XPMax`, `GetMoney`, `GetXPExhaustion`, `UnitClass/UnitName/GetRealmName`, `GetNumQuestChoices`, `GetQuestItemLink/Info`, `C_QuestLog.GetInfo` fields, objective text/type, `ContainerItemInfo.hyperlink/isBound/stackCount`, tooltip `leftText`/colors, `GetProfessionInfo`, `IsSpellKnown`, `CanDualWield` are all wrapped before arithmetic, comparison or concatenation in all three files. Hub and helper arithmetic (`xp * 100 / maxXP`, `money - session.money`, `now - alert.time`) is on Safe'd or local values. `CanDualWield` exists on this client (`uisrc2\...PlayerScriptDocumentation.lua:46`); `C_SpellBook.IsSpellKnown` exists (`SpellBookDocumentation.lua:738`).
- Stat scoring: weapon DPS weight is chosen per slot/subclass (`DpsWeight` :381): wands use `wand`, ranged slots `ranged`, everything else `melee`; roles without a weight score 0 DPS for that weapon type, so a hunter's melee weapon or a mage's dagger is judged on stats only. Two-hander vs. main+off (`BestGain` :573-578), off-hand beside a worn two-hander (:579-588, then `halfOfPair` CHECK at :690), dual-wield off-hand target (`SlotTargets` :514), spare copies of a worn unique (:632) and empty slots (:666 `isEmpty and gain >= 0`) are handled. Items with no stats score 0 and get CHECK "No stats to score" (:697) unless they fill an empty slot. Spell power / damage / healing are reconciled once (:412-414). Armor proficiency table lookups return nil -> "can't wear" (:636-639). Class-locked items are caught by the red tooltip line (finding 13 is wording only).
- Equipped-item comparison reads `GetInventoryItemLink("player", slot)` for both candidate slots (rings/trinkets) and reports the best gain; "Can't read the stats" while either side is loading (:649).
- Hub discovery/aggregation: `ForeverHubStatus[name]` for a fixed `STATUS_ORDER` (:12) with `pcall` per source (:433), quiet during the first pass before helpers have logged in (:812-814) and re-run one frame later (:818); commands run through `pcall` with output capture (:101-115); UI build steps each in `Attempt` (:798-809). No `OnUpdate` scripts except the minimap drag (:605, removed on drag stop :614); one 1 s ticker (:823) that only refreshes rows when dirty and out of combat.
- SavedVariables: `ItemAdvisorDB[char].profile` only; `ForeverHubDB` = window/panel/minimap position; `ForeverHelperDB.characters[char]` = money/level/rested/tasks (tasks grow only by user action). None grow with play time. `bagBadges`/`rewardMarks` are weak-keyed on pooled Blizzard buttons (bounded).
- QuestInfo reward matching (`RewardButton` :999) uses `type == "choice"` and `GetID() == index`, which is what `QuestInfo.lua:781/:530` set; `GetQuestItemInfo` third return is the count (`QuestInfo.lua:525`); `GetQuestItemInfoLootType` is called by Blizzard at `QuestInfo.lua:787` so it exists here; ItemAdvisor guards it anyway (:1048).
- Events registered all exist in `uisrc2` (`LEARNED_SPELL_IN_SKILL_LINE`, `BAG_UPDATE_DELAYED`, `QUEST_FINISHED`, `UPDATE_EXHAUSTION`, `TRAIT_CONFIG_UPDATED`, `TRAINER_UPDATE`, `SKILL_LINES_CHANGED`, `UPDATE_INVENTORY_DURABILITY`, `PLAYER_EQUIPMENT_CHANGED`).

## Summary

Counts: BUG 3 (all low), RULE 4 (one medium, three low), RISK 4 (one medium, three low), NIT 3. The logged `ItemAdvisor.lua:402` error (`ARMOR_TYPES/WEAPON_TYPES[playerClass][...]` with an unknown class) is already fixed by the class fallback at :1197-1201 and the `charData` guards on every hub entry point, and ForeverHub's `pcall`-per-command and `pcall`-per-status design kept the hub alive through it. The remaining items that matter are: ItemAdvisor's badges and `HookScript` on Blizzard bag and quest-reward frames (owner rule 3), the cost of re-evaluating the whole bag on every hub tick, repaint, unfiltered `GET_ITEM_INFO_RECEIVED` and tooltip refresh (one results cache fixes all four), and un-`Safe()`d `GetInventoryItemLink` reads that run in combat from the tooltip. Everything else is small: a scope bookkeeping bug that can hide a crit percent, two unbounded session tables, a few spots where the hub's isolation is one `type()` check or one `Attempt` short, the login CVar write, and the chat/slash fallbacks that only matter when the hub is not loaded. All three addons are read-only and have no per-frame work.
