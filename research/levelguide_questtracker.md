# Review: LevelGuide\LevelGuide.lua and QuestTracker\QuestTracker.lua

Client: WoW Forever 1.60.1 (interface 16001, Mainline/Midnight-based). Both files read completely; Routes.lua,
QuestIDs.lua and Prereqs.lua read as far as needed to understand the fields (step = `{t, q, npc|note|text, x, y,
lvl, part}`; route = `{zone, min, max, steps}`; `LevelGuideQuestIDs.ids[title] = {id, id, ...}` where list position =
chain part, last worker block wins; `LevelGuidePrereqs[title] = {level=, all={ids}, any={ids}}`).

Verification source: the uisrc2 dump. Note that the dump holds only Blizzard_APIDocumentationGenerated,
Blizzard_FrameXML/SecureTemplates.lua, Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua and three
Blizzard_ObjectiveTracker files (Shared, Quest, Bonus). The tracker container (Blizzard_ObjectiveTracker.lua),
ScenarioObjectiveTracker, MawBuffs, UIParent.lua and WorldMapFrame are not in it; where a claim depends on those I
say so.

Severity key: BUG = wrong behaviour/error, RULE = breaks an owner rule, RISK = likely to error on this client,
NIT = minor. Ranked most severe first.

---

## 1. RULE / BUG — QuestTracker.lua:558-561 `OpenQuest` runs Blizzard quest-log Lua under addon taint; this is the verified path to the MawBuffs error

**Claim.** Right-clicking a quest row calls `QuestMapFrame_OpenToQuestDetails(questID)` (QuestTracker.lua:560), a
Blizzard Lua function. Everything it does runs with QuestTracker's taint, and one of the values it writes is read by
the Blizzard objective tracker on every update.

**Verified chain (all in uisrc2):**

1. QuestTracker.lua:560 → `QuestMapFrame_OpenToQuestDetails(questID)` (QuestMapFrame.lua:1179).
2. :1180 `QuestMapFrame:SetDisplayMode(...)`, :1181 `OpenQuestLog()` → :2182 `ShowUIPanel(WorldMapFrame)` (UIParent
   panel management, not in dump) → :2183 `QuestMapFrame_Open()` → `QuestMapFrame_Show()` → `QuestMapFrame_UpdateAll()`.
3. :1182 `QuestMapFrame_ShowQuestDetails(questID)` (:1044) → :1046 `C_QuestLog.SetSelectedQuest`, **:1048
   `detailsFrame.questID = questID`** (tainted write into a Blizzard table), :1049 `SetFocusedQuestID`, :1050-1051
   `QuestInfo_Display(...)` twice, :1101 `WorldMapFrame:SetMapID(mapID)` (re-enters ShowQuestDetails), etc.
4. Blizzard_QuestObjectiveTracker.lua:296, inside `QuestObjectiveTrackerMixin:UpdateSingle` which runs for every
   tracked quest on every tracker update:
   `local shouldShowWaypoint = isSuperTracked or (questID == QuestMapFrame_GetFocusedQuestID());`
   → QuestMapFrame.lua:943-945 `return QuestMapFrame.DetailsFrame.questID;` — the value written under taint in step 3.
5. Reading a tainted value taints the rest of that tracker update. The container updates all modules in one pass, so
   the Scenario module's MawBuffs block then calls `C_UnitAuras.GetAuraDataByIndex` while tainted →
   "Auras cannot be accessed when secret while tainted by 'QuestTracker'", stack Blizzard_ObjectiveTracker →
   ScenarioObjectiveTracker → MawBuffs. That is exactly the logged stack.

The tainted `DetailsFrame.questID` persists until Blizzard code clears it securely
(`QuestMapFrame_CloseQuestDetails`, :1119, runs on map hide/back button), so every tracker update while the map is
open after a right-click is tainted, and so is anything else `QuestInfo_Display`/`SetMapID` cached under taint
(QuestCache entries created in that call, `WorldMapFrame.focusedQuestID`, map data providers). This also fits the
author's own comment at :1086-1091: the Hide/Show vector was removed, but this Lua vector remained.

Other calls checked and cleared as taint sources: `C_SuperTrack.SetSuperTrackedQuestID` (:554), `C_Map.SetUserWaypoint`
and `C_SuperTrack.SetSuperTrackedUserWaypoint` (:380-382), `ShowQuestComplete` (:579), `C_QuestLog.RequestLoadQuestByID`,
`C_Item.RequestLoadItemDataByID` are C APIs; `SUPER_TRACKING_CHANGED` is not flagged `SynchronousEvent` in
SuperTrackManagerDocumentation.lua:195-197 (compare `USER_WAYPOINT_UPDATED`, MapDocumentation.lua:637-638, which is
synchronous but is not an event the Quest module registers, Blizzard_QuestObjectiveTracker.lua:3). `CooldownFrame_Set`
(:959) and `UiMapPoint.CreateFromCoordinates` (:380) are Blizzard Lua but only touch the addon's own frame / a new
table. LevelGuide calls none of the QuestMapFrame functions.

**Fix (keeps a right-click that opens the quest log, loses "open to this quest's details"):**

Option A, cleanest: drop the Blizzard Lua call. The addon's own tooltip already shows objectives, rewards and the
turn-in text; the quest log is one key press (L) away.

```lua
local function OpenQuest(questID)
    -- Never call QuestMapFrame_* / OpenQuestLog from here: Blizzard_QuestObjectiveTracker reads
    -- QuestMapFrame.DetailsFrame.questID on every update, and a value written under our taint
    -- taints the whole tracker pass (MawBuffs aura error).
    if not InCombat() and C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        C_SuperTrack.SetSuperTrackedQuestID(questID)   -- C API; the map/log highlight follows it
    end
end
```

Option B, if opening the log is wanted: make the quest rows `SecureActionButtonTemplate` buttons (like the item
buttons already are) with `type2 = "macro"` and `macrotext2 = "/click QuestLogMicroButton"`; a macro run from a
secure button executes Blizzard's micro-button click securely. Attributes may only be set out of combat (Layout
already runs out of combat only). This opens the log, not the quest's detail page; combine with
`C_SuperTrack.SetSuperTrackedQuestID` to highlight the quest.

To confirm in game before/after: `/console taintLog 2`, reproduce, read Logs\taint.log — it names the first tainted
read in the tracker update.

## 2. RULE — QuestTracker.lua:1097, 1103, 1114: hooks a Blizzard frame script and changes a Blizzard frame

**Claim.** `ObjectiveTrackerFrame:HookScript("OnShow", HideBlizzardTracker)` (:1103) is a hook on a Blizzard frame,
and `tracker:SetAlpha(0)` / `SetAlpha(1)` (:1097, :1114) manipulate a Blizzard frame. Owner rule 3 forbids both.
`HookScript` is a post-hook that runs after Blizzard's handler and only calls `SetAlpha`, so it is not the taint
source of finding 1; it is still a rule violation and a footgun (any future code in that hook runs on the tracker's
OnShow path under taint).

**Fix that keeps the "hide Blizzard's tracker" toggle without a hook:** poll from the ticker the addon already runs.

```lua
-- in OnTick(), before Attempt(UpdateLive):
if ObjectiveTrackerFrame and not db.keepBlizzard and ObjectiveTrackerFrame:GetAlpha() > 0 then
    ObjectiveTrackerFrame:SetAlpha(0)
end
```

and delete `WatchBlizzardTracker`'s `HookScript` line. If the owner wants rule 3 read strictly, remove the alpha change
too and let the user shrink the tracker in Edit Mode; the addon then only offers its own panel.

## 3. RULE (low) — QuestTracker.lua uses the shared `GameTooltip`

Lines 491-531 (`QuestTooltip`), 534-548 (`SectionTooltip`), 590-593, 636-638, 658-667 (item buttons), 1165-1174
(header). The brief asks that tooltips use the addon's own tooltip frame; LevelGuide does (LevelGuide.lua:1158-1164
`Tip()`), QuestTracker does not. Writing lines into GameTooltip from addon code is routine in the ecosystem and not the
cause of finding 1, but it is the one remaining write into a Blizzard frame once finding 2 is fixed.

**Fix.** Copy LevelGuide's pattern: `CreateFrame("GameTooltip", "QuestTrackerTooltip", UIParent, "GameTooltipTemplate")`
once and use it everywhere GameTooltip is used. `SetHyperlink` (:661) works on it too.

## 4. BUG — LevelGuide.lua:913-916 marks a quest giver "busy" for every undone step with an NPC, including pick-ups and invisible pick-ups

**Claim.** In `RouteSteps`, after classifying any not-done step, `busyNpcs[NpcKey(step.npc)] = true` runs whether the
step is a turn-in or a pick-up and whether or not it was shown. `RouteStepActionable` (:705-707) then refuses every
later pick-up from that NPC.

**Scenario.** Teldrassil steps 76-77 (Routes.lua): `A("The Emerald Dreamcatcher", "Tallonkai Swiftroot")` then
`A("Twisted Hatred", "Tallonkai Swiftroot")`. Standing at Tallonkai with neither quest, step 76 is actionable → ready
→ Tallonkai busy → step 77 is not actionable and, being an accept, not shown at all. The guide shows one pick-up per
NPC at a hub, contradicting the "sweep the hub" intent (PICKUP_BIAS comment, :8-9). Worse: a pick-up that is not
actionable because of level (`step.lvl > level + 1`) still marks its NPC busy, hiding that NPC's other, available
quests until the player levels.

**Fix.** Only turn-ins (and `StillOwed` turn-ins, which already do this at :917-924) should block a giver:

```lua
local npc = step.t == "turnin" and NpcKey(step.npc) or nil
if npc then busyNpcs[npc] = true end
```

## 5. BUG — LevelGuide.lua:719-745 `Gone`/`StillOwed`: a quest the player never obtained can block an NPC's later pick-ups with no visible step to skip

**Claim.** `StillOwed` treats a turn-in as owed when the quest is not in the log, not flagged complete and its accept
step is not `Gone`. `Gone` returns false for any quest with IDs (:723-725). The owed turn-in's NPC becomes busy
(:917-924) and all later pick-ups from that NPC are hidden (finding 4 path). Neither the owed turn-in (RouteStepDone
true, :635-637) nor the blocked pick-ups are shown, so there is nothing to right-click to skip.

**Scenario.** Routes.lua:53-56: `A("Fang of Githyiss", "<item drop>")`, `T("Fang of Githyiss", "Gilshalan Windwalker")`,
`A("Tenaron's Summons", "Gilshalan Windwalker")`. A player who never got the Fang drop (QuestIDs: 97236, HasIDs true
→ never Gone) has "Fang of Githyiss" owed → Gilshalan busy → "Tenaron's Summons" never shown. The window moves on to
`A("Crown of the Earth", "Tenaron Stormgrip")`, which Tenaron will not offer (Prereqs.lua:480 needs 920 = Tenaron's
Summons) → after talking, `offersByNpc` marks it done → the route silently skips the whole Crown of the Earth chain
start until level 9 (OUTLEVELED). Recovery needs the player to guess that a hidden drop quest is the cause.

**Fix.** The owner already ships Prereqs.lua; use it instead of the NPC heuristic. In `RouteSteps`, delete the
`StillOwed` branch and the `busyNpcs` parameter, and let `PrereqsMet` (already called in `RouteStepDone`:606) be the
only gate. If the heuristic is kept, at least exclude accept steps whose giver is not an NPC (npc text containing
"drops", "(object" or "poster"), and show an owed turn-in as a dimmed "Still owed: X (skip if you never took it)" row
so it can be right-clicked.

## 6. BUG — LevelGuide.lua:827-840, 851-864, 939: route selection sticks to the previous zone, and the fallback branch drops everything in the current zone (scenario e)

**Claim.** `FindRoute` returns the first route in `chains[race]` with `level <= max`, `level >= min - 2` and any step
not `RouteStepDone`. A step is done by level only when `level >= step.lvl + 4` (:616). So the Teldrassil route (max 12)
is "active" at level 11-12 whenever any step with `lvl >= 8` is undone, including pick-ups the player chose not to do.
When the player is in Darkshore, `ZoneMap("Teldrassil")` is nil, so the :851-864 branch runs: it shows "Go to:
Teldrassil" plus up to three written steps and never reads the log or the map for the zone the player is standing in.

**Trace (e): level 11, arriving in Darkshore, three Teldrassil turn-ins (route T steps, lvl 9-11) still in the log.**
`FindRoute`: Teldrassil qualifies (11 <= 12, 11 >= -1); the three T steps are not done (entry held, not turned in) →
Teldrassil returned. `ZoneMap` nil → list = `{travel "Teldrassil" / "Your route continues there"}` then the first
three undone steps in written order that are not non-actionable pick-ups. These are not necessarily the three
turn-ins; e.g. `A("Bounty: Gnarlpine Furbolg", lvl 9)` if never taken is actionable (entry nil, turnedIn 0, lvl 9 <=
12) and listed first. The arrow is hidden and the yards text says "other zone" (:1309). Nothing from Darkshore (the
log's Darkshore quests, the Auberdine "!" offers) appears, and no Darkshore route step appears, until level 13 for
lvl-9 steps / level 15 for lvl-11 steps, or until the player right-clicks each remaining Teldrassil step one by one
(each click only reveals the next). Separately, once the Darkshore route does become active, the three Teldrassil
turn-ins disappear from the guide entirely: `RouteSteps` only uses `here` from `ReadQuests(zoneMap)` (:939) and
ignores the `away` list, so quests whose waypoint is on another map are not shown at all in route mode.

**Fix.**
- In `FindRoute`, if a route whose `zone == ZoneName(current zone map)` exists and `level >= route.min`, prefer it;
  otherwise keep the current order.
- In the zoneMap-nil branch (:851-864), still build the local pool: call `ReadQuests(PlayerPosition())` and
  `ReadOffers(...)` and route them, and keep the "Go to <zone>" entry as a waiting step with its count.
- In route mode, append `TravelSteps(away)` from `ReadQuests(zoneMap)` to `waiting` so held quests from other zones
  are not lost.

## 7. RISK — LevelGuide.lua:600-604 treats absence from `C_QuestLine.GetAvailableQuestLines` as proof a pick-up is unavailable

**Claim.** `MapOffers` returns a set when the zone map lists at least one available quest line; `RouteStepDone` then
marks any pick-up not in that set as done (:603). `C_QuestLine.GetAvailableQuestLines` exists
(QuestLineInfoDocumentation.lua:11-24, fields :135-158), but it reports quest lines, i.e. quests Blizzard's map data
knows as "!" markers. On a Classic-era world running on this client there is no guarantee every standalone 1-60 quest
is in that data; if it lists even one quest for Teldrassil, every other pick-up in the route is silently marked done
until the player happens to talk to the giver (which only sets `offersByNpc`, which does not undo this rule).

**Fix.** Use the map as positive evidence only:

```lua
local onMap = MapOffers(route.zone)
if onMap and OfferedOnMap(onMap, step.q) then
    -- offered right now: fall through, do not consult offersByNpc / prereqs
elseif offers and not (offers[step.q] or offers[RealTitle(step.q)]) then
    return true
elseif not PrereqsMet(step.q, level) then
    return true
end
```

## 8. BUG — LevelGuide.lua:926-948 "extras" re-add pick-ups the route deliberately hid

**Claim.** `known` only contains ids/titles of steps that were shown. Pick-ups hidden as not actionable (busy giver,
under-level, not offered) or deliberately left for a later hub are not in `known`, so if the map lists them as
available (`ReadOffers(zoneMap)`) they come back as "Pick up" extras and are routed by distance with PICKUP_BIAS 0.4,
sending the player to a giver the route just decided to wait on.

**Fix.** Seed `known` with every accept step's title (and ids via `LevelGuideQuestIDs.ids`) for the active route,
not only the shown ones; let extras be only what the route does not know at all.

## 9. BUG (minor) — LevelGuide.lua:1013-1046 `PutTimedFirst` ignores skips and hidden entries; warnings never reset

**Claim.** It iterates the whole log, including `db.skipped` ids and `isHidden` entries, and inserts a synthetic step
when none is in the list. Right-click skip on a timed or failed step sets `db.skipped[id]` (:1151-1153), `ReadQuests`
honours it, but `PutTimedFirst` re-inserts it on the next rebuild, so the skip visibly does nothing. `timedWarned` and
`lowWarned` are never cleared on `QUEST_REMOVED`, so a timed quest abandoned after failing and re-accepted gets no
sound the second time.

**Trace (c): timed quest running, then failed.** Running: `TimerEnds` (`GetTimeAllowed` returns totalTime,
elapsedTime, QuestLogDocumentation.lua:635-649) gives `ends`; the matching turn-in/work step is pulled out of the list
(or synthesised), gets `timerEnds`, the detail prefix "Timed, don't stop on the way." and is put first; RAID_WARNING
plays once; `Render` and `UpdateArrow` (:1246, :1294-1300) show the countdown every 0.05 s and warn again at 60 s.
Failed: `C_QuestLog.IsFailed` true → `kind = "work"`, detail "Failed. Abandon it in your quest log, then pick it up
again", coordinates cleared (no arrow), still first. Correct, apart from the skip and re-warn points above.

**Fix.** Add `and not db.skipped[id] and not Safe(info.isHidden)` to the :1017 condition; clear `timedWarned[questID]`
and `lowWarned[questID]` in the `QUEST_REMOVED` handler (:1492).

## 10. RISK — LevelGuide.lua:1443 unguarded `SetAtlas("Navigation-Tracked-Arrow")`

**Claim.** `Build` is wrapped in `Attempt`, so if this atlas is missing on the Forever client `SetAtlas` raises, `Build`
aborts before `frame:SetScript("OnUpdate", ...)` (:1462) and the guide is a static empty box for the session with one
error. QuestTracker guards its atlases with `C_Texture.GetAtlasInfo` (QuestTracker.lua:49-57); LevelGuide does not.

**Fix.** `if C_Texture.GetAtlasInfo("Navigation-Tracked-Arrow") then arrow:SetAtlas(...) else arrow:SetTexture("Interface\\MINIMAP\\MiniMap-QuestArrow") end`.

## 11. NIT — QuestTracker.lua:578-579 "Left-click: complete it"

`ShowQuestComplete(questID)` is a C API that opens the completion dialog; Blizzard's tracker does the same
(Blizzard_QuestObjectiveTracker.lua:64-66) and the player still presses Complete. Not an automation, but the tooltip
text (:526) and label "Click to complete" (:206) read as one. Rename to "open the completion window". Auto-complete
quests are rare on a Classic-era world anyway.

## 12. NIT — Secret-value coverage: two un-wrapped vector reads

Every C_*/Unit*/Get* return used in arithmetic, comparison, concat or format was checked:

- QuestTracker: :91-92, 108-113, 129-132, 141-147, 155-157, 190/194, 208/212, 220-257, 272-273, 286-305, 338, 352-355,
  387, 392, 460, 481, 515-516, 554, 791, 890-896, 953-964, 996-1003, 1201-1203, 1233 — all through `Safe()` or built
  from Safe'd values.
- LevelGuide: :102-119, 122-128, 133, 137-141, 149, 154, 167-171, 186, 192-194, 209-213, 221-253, 274-277, 371-376,
  396-405, 442, 503, 558-559, 656-681, 756-758, 781-786, 829, 986, 1014-1028, 1050, 1228-1229, 1324, 1479, 1495 — all
  wrapped.

Not wrapped: QuestTracker.lua:349 `px, py = position:GetXY()` from `C_Map.GetPlayerMapPosition`, used at :358 in
arithmetic (LevelGuide wraps the same call at :119 and :128); QuestTracker.lua:327-328 and LevelGuide.lua:73-75
`GetXY()` on `C_Map.GetWorldPosFromMapPos` results. The API docs mark `SecretReturns` only on unit health/cast
functions (UnitDocumentation.lua:37, 56, 512, 814, 1271, 1288, 1304, 1490, 1509, 1528, 1702, 2637, 2768, 3150, 3168);
none of the quest, map or XP functions used here carry it, so this is consistency, not a live risk. Wrap for parity.

## 13. NIT — LevelGuide.lua:362-391 `LogByTitle` collisions

Two log entries with the same title (possible with Forever's renamed/duplicated quests) leave only the later one in
`byTitle` (:374). A quest id listed under two titles in QuestIDs gets `part` from whichever `pairs` visits last
(:383-389), nondeterministic between sessions. Low impact; worth a one-line guard (`if not entry.part then`).

## 14. NIT — LevelGuide.lua:518-541, 606 prerequisites are keyed by title, and "not yet eligible" is reported as "done"

`PrereqsMet(step.q, level)` applies the part-1 record to every part of a chain (harmless for `all`, since earlier parts
imply it, but `need.level` for part 1 is applied to part 8). `RouteStepDone` returns true when prereqs are unmet, so an
under-level pick-up counts as done for `FindRoute`; with nothing else undone the route is considered finished and the
guide falls back to plan mode until the level is reached. Consider a third state ("waiting") instead of done.

## 15. NIT — LevelGuide.lua:752-762 `CityMap` caches a miss forever

If `C_Map.GetMapChildrenInfo(zoneMap, nil, true)` (MapDocumentation.lua:198-...) returns no "Darnassus" on the first
call, `cityMaps[key] = false` stays for the session and every Darnassus step loses its position. Retry on the next
`ZONE_CHANGED_NEW_AREA` or cache only hits.

**Trace (d): a step whose npc says ", Darnassus" when GetMapChildrenInfo returns the city.** `RouteDisplay` (:818-823)
→ `CityToZone(57, step, x/100, y/100)`; `text:find(", Darnassus", 1, true)` matches "Rellian Greenspyre, Darnassus
(Cenarion Enclave)" (Routes.lua:136) and the D-step note at :199, and correctly does not match "by the Darnassus road"
(:227) or the G texts (:135, :187, :228, which use `note`/`text` without ", Darnassus"). `CityMap` finds mapID 89;
`GetWorldPosFromMapPos(89, (x,y))` → `(continent, world)`; `GetMapPosFromWorldPos(continent, world, 57)` returns
`(uiMapID, mapPos)` and the code takes the second value (:783) → Teldrassil-map coordinates, cached per step. The step
is shown with `mapID = 57`, so `PositionOn(57)` and `Distance`/`Offset` use the Teldrassil scale and the arrow works
inside the city (the player's position on map 57 is available while inside 89, a child of 57). Correct. If conversion
fails the step is shown without coordinates (not actionable, so a pick-up is hidden and a turn-in/do goes to
`waiting`), which is the documented fallback (:795-796).

## 16. NIT — LevelGuide.lua:806, 808 `"From " .. step.npc` with no nil guard

A route step authored without an npc raises in `RouteDisplay`; `Attempt(Rebuild)` catches it, but it recurs every 2 s
(error spam) and the guide stops updating. Use `tostring(step.npc or "?")`.

## 17. NIT — QuestTracker.lua:1053-1062 and 1013-1024: duplicated work each refresh

`Refresh` → `Layout` → `BuildSections` + `ReadOffers`, then `Order(quests)` → `BuildSections` + `ReadOffers` again;
every 3 s the ticker also does a full `ReadQuests()` + `Order()` to compare strings even when no event fired. Cheap at
a Classic quest-log size, but `Order` could be computed from the sections `Layout` already built.

## 18. NIT — LevelGuide.lua:1355-1365 `dirty` rebuilds are not rate-limited

`QUEST_LOG_UPDATE` (and the other 15 events) set `dirty`, so a burst (looting in combat, zoning) rebuilds the route,
reads `GetAvailableQuestLines`, `GetQuestsOnMap` and every quest's objectives on consecutive frames. The 2-second
periodic rebuild and 0.05 s arrow update are correctly throttled. Add a minimum gap (e.g. 0.25 s) before honouring
`dirty`.

## 19. NIT — QuestTracker.lua:1036-1049 combat race on secure item buttons

`InCombat()` is tested at the top of the tick; if combat starts while `Layout` is still running (it is one Lua call,
so only a PLAYER_REGEN_DISABLED delivered inside the same frame before the tick can do this) the `SetPoint`/
`SetAttribute` on a `SecureActionButtonTemplate` button is blocked with an error. Vanishingly rare; the existing
`layoutWaiting` design is right. Wrap `PlaceItemButton` in `if not InCombatLockdown()` for belt and braces.

---

## Scenario traces not covered above

**(a) Holding part 3 of an 8-part chain whose parts 1-2 are flagged complete** ("Crown of the Earth", QuestIDs.lua:681
has 8 ids; the last block wins in the merge at QuestIDs.lua:731-744).
`LogByTitle`: `entry.part = 3`. `TurnedIn` = max(charData.done, flagged 2) = 2. For `A/D/T` part 1 and 2:
`turnedIn >= part` → done. `A(part 3)`: `HeldPart` matches → `entry ~= nil and turnedIn == 2` → done. `D(part 3)`:
not done until `entry.ready`; actionable (`entry` and not ready) → shown as "Do: Crown of the Earth" with
`step.note .. ". Now: " .. FirstUnfinished`. `T(part 3)`: not done, actionable only when ready → waiting. `A(part 4)`:
`HeldPart` nil (3 ~= 4), `turnedIn 2 >= 4` false → not done, not actionable (turnedIn ~= 3) → hidden. Frontier = index
of `A(part 3)`, so earlier `go` steps and ID-less pick-ups are done. Result: correct. If the flags were missing, :626-628
`turnedIn = max(turnedIn, held.part - 1)` gives the same answer. If the title has no IDs, every part's `HeldPart`
matches and the guide would show the part-1 "Do" step for a part-3 quest — documented limitation, data-dependent.

**(b) A quest picked up from an NPC the route lists 40 steps later** (e.g. "Zenn's Bidding", Routes.lua:66, picked up
while at step 5). `A("Zenn's Bidding")`: `entry` held, `turnedIn 0 == part - 1` → done (not shown). Its `D` step
(:101) is past `ROUTE_WINDOW`; if ten visible steps come first it is not shown by the route, so it is not in `known`,
and `ReadQuests(zoneMap)` adds it as an extra "Do" step placed at its `GetQuestsOnMap` point and routed by distance.
When the window later reaches the `D` step, `known[id]` prevents a duplicate. When ready, the extra becomes a "Turn in"
at its waypoint, and the route's `T` (:104) shows once reached. Side effects: `LastProgress` becomes 66, so every `go`
step before index 66 counts as done (none exist in Teldrassil before :135, so harmless here, but wrong in zones with
early `G` steps); `Frontier` is unaffected as long as an earlier pick-up is also held. Result: acceptable.

---

## Event handling (item 4)

- Every registered event exists in this client's docs: QUEST_LOG_UPDATE (QuestLogDocumentation.lua:1373),
  QUEST_WATCH_LIST_CHANGED (:1408), QUEST_ACCEPTED (:1312, payload `questId` only — QuestTracker.lua:1237 and
  LevelGuide.lua:1491 read it as the first arg, correct), QUEST_REMOVED (:1385), QUEST_TURNED_IN (:1396),
  QUEST_DATA_LOAD_RESULT (:1338), QUEST_POI_UPDATE (:1379), QUESTLINE_UPDATE (:1430), QUEST_COMPLETE (:1332),
  QUEST_DETAIL (:1349), QUEST_GREETING / QUEST_PROGRESS (QuestOfferDocumentation.lua:85, 97), GOSSIP_SHOW
  (GossipInfoDocumentation.lua:277), ZONE_CHANGED / ZONE_CHANGED_NEW_AREA (MapDocumentation.lua:653, 665),
  PLAYER_LEVEL_UP / PLAYER_XP_UPDATE (UnitDocumentation.lua:3832, 3998), PLAYER_EQUIPMENT_CHANGED
  (PaperDollInfoDocumentation.lua:386), GET_ITEM_INFO_RECEIVED (ItemDocumentation.lua:1815), SUPER_TRACKING_CHANGED
  (SuperTrackManagerDocumentation.lua:195), PLAYER_LOGIN / PLAYER_REGEN_*. LevelGuide pcall's registration (:1471);
  QuestTracker does not need to since all exist.
- Legacy globals used (`GetQuestLogSpecialItemInfo`, `GetQuestLogSpecialItemCooldown`, `IsQuestLogSpecialItemInRange`,
  `GetQuestLogCompletionText`, `GetQuestLogRewardXP`, `GetQuestLogRewardMoney`, `GetNumQuestLogRewards`,
  `GetQuestLogRewardInfo`, `HaveQuestRewardData`) are all used by Blizzard_ObjectiveTracker in the dump
  (ObjectiveTrackerShared.lua:53-147, BonusObjectiveTracker.lua:167-658), so they exist. `GetNumQuestLogChoices`,
  `GetQuestLogChoiceInfo`, `GetAvailableTitle`, `GetNumAvailableQuests`, `GetTitleText` are not in the dump; the code
  guards each with an existence check, which is the right pattern.
- OnUpdate/ticker throttling: QuestTracker uses a 1 Hz `C_Timer.NewTicker`; LevelGuide's OnUpdate does work only at
  0.05 s / 2 s (see finding 18 for the `dirty` burst).
- SavedVariables are bounded: QuestTracker `db.zones` (one boolean per zone/subzone name), `db.accepted` (pruned at
  Start :1200-1207 and on QUEST_REMOVED :1239-1240), `db.position`, `db.collapsed`, `db.keepBlizzard`; LevelGuide
  `db.skipped` (cleared on QUEST_REMOVED, which also fires on turn-in), `db.characters[name-realm]` with `done`
  (one counter per title), `skips` and `visited` (one key per route step). Nothing grows per session.
- Right-click skip (LevelGuide :1207-1213, :1147-1155) stores a route key or quest id; header right-click (:1409-1415)
  clears both. Correct except finding 9 (timed quests). QuestTracker has no skip; its header right-click toggles the
  Blizzard tracker (finding 2).
- No chat output and no slash commands in either addon (grep for `print(`, `AddMessage`, `SLASH_`, `SlashCmdList`:
  none). `Notify` (QuestTracker.lua:59-63) goes to ForeverHub if present. `PlaySound` is fine.

## UI (item 5)

- Both addons create their frames with `CreateFrame(..., UIParent, ...)`; rows/buttons are children of the addon panel.
  QuestTracker's `PlaceDefault` (:994-1010) only reads MinimapCluster geometry and anchors to UIParent, as the comment
  says. Nothing is parented or anchored into a Blizzard frame.
- Blizzard frames touched: `ObjectiveTrackerFrame` (finding 2) and `GameTooltip` (finding 3) in QuestTracker;
  none in LevelGuide (own `LevelGuideTooltip`).
- Secure item buttons: created from `SecureActionButtonTemplate` (SecureTemplates.lua in the dump), attributes and
  anchors set only from `Layout`, which runs out of combat; combat updates only change textures/text (`UpdateLive`,
  `UpdateTextOnly`). Correct, see finding 19 for the edge.

---

## Summary

The logged taint error has a concrete, verifiable cause: QuestTracker's right-click handler calls the Blizzard Lua
function `QuestMapFrame_OpenToQuestDetails`, which writes `QuestMapFrame.DetailsFrame.questID` under the addon's taint,
and `Blizzard_QuestObjectiveTracker.lua:296` reads that field on every tracker update, tainting the pass in which the
Scenario module's MawBuffs code reads auras. Replacing that call with the C API `C_SuperTrack.SetSuperTrackedQuestID`
(or a secure `/click QuestLogMicroButton` button) removes it; the OnShow hook and alpha change on
`ObjectiveTrackerFrame` and the use of `GameTooltip` are the remaining rule-3 items. LevelGuide's engine is largely
sound (chain parts, frontier, timed quests and Darnassus conversion trace correctly), but three route-logic rules are
over-eager: the per-NPC "busy" heuristic hides sibling pick-ups and can deadlock on never-obtained drop quests, route
selection pins the player to the previous zone with no local information, and absence from the map's quest-line list
is taken as proof a quest is unavailable. Secret-value handling is thorough in both files; all registered events and
APIs exist on this client; SavedVariables are bounded and there is no chat output.
