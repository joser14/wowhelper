# Landmarks review (Landmarks\Landmarks.lua, Landmarks\Landmarks.toc)

Source of truth: `scratchpad\uisrc2` (generated API docs + a few FrameXML files). Line numbers refer to the current workspace file.
Harness: `scratchpad\harness\test_landmarks.lua` — **fails against the current file** (2 bugs below, both reproduced); passes against a copy with the two fixes applied (`scratchpad\review\fixed\Landmarks\Landmarks.lua`, not part of the workspace).

## Findings, most severe first

### 1. BUG — Landmarks.lua:203 — the page errors as soon as anything is remembered
`local place, yards = spot and Nearest(spot, entry.key)` — a Lua `and` expression yields one value, so `yards` is always nil. `YardsText(nil)` at :151 then raises `attempt to compare number with nil`. ForeverHub's `RunCommand` catches it under pcall, so the "Places" page shows only "Something went wrong here" (plus whatever a `/places repair` pin printed first) whenever the position is readable and at least one place exists — i.e. always, after the first vendor visit. Reproduced in the harness (12 of the page assertions fail with exactly this error).

Fix:
```lua
local place, yards
if spot then
    place, yards = Nearest(spot, entry.key)
end
```

### 2. BUG — Landmarks.lua:94 — merging by name collapses every mailbox (and every same-named NPC) into one record
`place.name == name or (Yards(...) or math.huge) < SAME_SPOT_YARDS` merges on name alone, with no distance check. `MAIL_SHOW` always records the name `"Mailbox"` (:261), so the second mailbox you open anywhere on the realm overwrites the first: only one mailbox is ever remembered, and "nearest mailbox" is just "last mailbox". The same happens for any two NPCs sharing a name, and for every NPC whose `UnitName("npc")` came back nil/secret and fell back to `"Vendor"`, `"Trainer"`, `"Banker"`, `"Innkeeper"`, `"Flight master"` (:116-118). Reproduced in the harness (second mailbox 400 yd away -> `count("mail") == 1`).

Dropping the name clause alone is not enough: inside instances `GetWorldPosFromMapPos` returns nothing (`MayReturnNothing`, MapDocumentation.lua:508), so `Yards` is nil and every visit to the same dungeon vendor would then add a new record. Use a map-fraction fallback:
```lua
local function SameSpot(spot, place)
    local yards = Yards(spot, place)
    if yards then
        return yards < SAME_SPOT_YARDS
    end
    -- No world position (instances): same map and about the same place on it.
    return place.mapID == spot.mapID and math.abs(place.x - spot.x) < 0.003 and math.abs(place.y - spot.y) < 0.003
end
-- in Remember():
if place.kind == kind and SameSpot(spot, place) then
```

### 3. RISK — Landmarks.lua:158-168 — "Pinned ..." is reported even when nothing was pinned
`C_Map.SetUserWaypoint` returns `wasSet` (MapDocumentation.lua:610) and `C_Map.CanSetUserWaypointOnMap(uiMapID)` exists (MapDocumentation.lua:11-23); `Pin` ignores both and returns true unconditionally, so for a map that refuses waypoints the page says "Pinned X" while the map shows nothing, and `C_SuperTrack.SetSuperTrackedUserWaypoint(true)` is still called.
```lua
if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(place.mapID) then
    return false
end
if not C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(place.mapID, place.x, place.y)) then
    return false
end
```
(The "Nearest %s ..." fallback line at :194 then does the right thing.)

### 4. NIT — Landmarks.lua:216 — "none on this continent" is also shown when the position is unreadable
When `Here()` returns nil (:198-199 already warns), every kind falls into the count branch and prints "N remembered, none on this continent", which is false — distances simply couldn't be computed. Print `"%d remembered"` when `spot` is nil and keep the continent wording only when `spot.continent` is set.

### 5. NIT — Landmarks.lua:276 — innkeeper detection is English-only and loose
`GossipOptionUIInfo` (GossipInfoDocumentation.lua:365-380) has `name` (string, non-nilable), `icon` (fileID), `flags` (number), `status`, `spellID`, `rewards`, `overrideIconID`, `orderIndex`; there is no field saying "this is the binder option" (the `GossipNpcOption.Binder` enum at GossipConstantsDocumentation.lua:18 is not surfaced in the option table). `name:find("home")` works for enUS ("Make this inn your home.") but not other locales, and matches any option containing "home". The binder option's icon is the well-known binder gossip icon (fileID 132052, `Interface/GossipFrame/BinderGossipIcon`); that constant is not in uisrc2 (no FrameXML for GossipFrame there), so treat it as an extra hint, not a replacement: `if Safe(option.icon) == 132052 or (type(name) == "string" and name:lower():find("home", 1, true)) then`. `flags` is an undocumented bitfield here; do not rely on it.

### 6. NIT — Landmarks.lua:162-164 — pinning replaces the player's own map pin and super-track
`SetUserWaypoint` overwrites an existing user waypoint and `SetSuperTrackedUserWaypoint(true)` takes over the super-tracked quest. It is UI state, not a gameplay action, and the player asked for it by typing, so it is within rule 1; consider checking `C_Map.HasUserWaypoint()` (MapDocumentation.lua:524) and saying "replaced your map pin" in the message.

### 7. NIT — Landmarks.lua:106-113 — prune sorts the whole list on every insert past the cap
Fine at 400 (O(n log n) per vendor visit), just noting it is the only non-trivial work; nothing runs on OnUpdate. SavedVariables are bounded per realm.

## Verification notes (the checklist from the task)

1. **Events**: all eight exist — PLAYER_LOGIN (SystemDocumentation.lua:153), MERCHANT_SHOW (MerchantFrameDocumentation.lua:112, no payload), MAIL_SHOW (MailInfoDocumentation.lua:139, no payload), TAXIMAP_OPENED (TaxiMapDocumentation.lua:76, payload `system`), TRAINER_SHOW (TrainerDocumentation.lua:63), BANKFRAME_OPENED (BankDocumentation.lua:398), CONFIRM_BINDER (UnitDocumentation.lua:3577, payload `areaName`), GOSSIP_SHOW (GossipInfoDocumentation.lua:277, payload `uiTextureKit`). The addon uses no payloads, so none of its assumptions can break. `HEARTHSTONE_BOUND` exists (UnitDocumentation.lua:3608, no payload) but fires only after a bind completes; CONFIRM_BINDER fires when the player clicks the option (even if they cancel), so it is the better of the two, and GOSSIP_SHOW is the only passive signal. A cleaner alternative to five separate window events is `PLAYER_INTERACTION_MANAGER_FRAME_SHOW` (PlayerInteractionManagerDocumentation.lua:113, payload `type` = `Enum.PlayerInteractionType`: Merchant 5, TaxiNode 6, Trainer 7, Banker 8, MailInfo 17, Binder 20) — optional. **UnitName("npc")**: documented (UnitDocumentation.lua:2489, `SecretWhenUnitNameIdentityRestricted`, hence Safe() is right). uisrc2 has no FrameXML for Merchant/Taxi/Trainer/Bank/Gossip frames, so validity of the `npc` token during those events cannot be confirmed from this reference set; it is the unit the player is interacting with and is valid while those windows are open, and MAIL_SHOW correctly does not use it (mailboxes are objects, not units). `C_GossipInfo.GetOptions()` returns `GossipOptionUIInfo[]` with `name` (GossipInfoDocumentation.lua:124-131, 365-380); see finding 5 for icon/flags.
2. **Map APIs**: `C_Map.GetWorldPosFromMapPos(uiMapID, vector2)` -> `continentID, worldPosition` (MapDocumentation.lua:506-521, `MayReturnNothing` — handled at :64). World units are yards by Blizzard convention (the docs do not state a unit); the axis orientation is irrelevant for distances. `C_Map.GetPlayerMapPosition` -> `vector2` with `Mixin = "Vector2DMixin"`, nilable (:437-451, handled at :53). `Vector2DMixin:GetXY`, `CreateVector2D` and `UiMapPoint.CreateFromCoordinates` are SharedXML and **not present in uisrc2**; the addon guards `CreateVector2D` (:62) and `UiMapPoint.CreateFromCoordinates` (:159) by existence, which is correct. `C_Map.SetUserWaypoint` (:599-612) and `C_SuperTrack.SetSuperTrackedUserWaypoint` (SuperTrackManagerDocumentation.lua:169) exist. `GetMerchantNumItems`, `GetMerchantItemID`, `CanMerchantRepair`, `IsTradeskillTrainer` are **not in the generated docs** (legacy FrameXML globals); all four are guarded by existence (:122, :254, :265). `GetSubZoneText`/`GetZoneText` are documented (ZoneScriptDocumentation.lua:43/52) and guarded (:73-74). `GetRealmName` documented (ConnectionDocumentation.lua:69), guarded (:238).
3. **Item info**: `C_Item.GetItemInfoInstant` returns itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID (ItemDocumentation.lua:671-677) — 6th/7th positions are correct; `MayReturnNothing` is handled (nil never equals 0). `Enum.ItemClass.Consumable = 0` (ItemConstantsDocumentation.lua:276) and `Enum.ItemConsumableSubclass.Fooddrink = 5` (:312) — the constants at :26 are right.
4. **Secret values**: every API read that is compared, used in arithmetic or concatenated goes through Safe(): mapID (:51), x/y (:57), continent/wx/wy (:66), zone texts (:73-74), UnitName (:117), merchant count/IDs/classIDs (:125-129), CanMerchantRepair (:254), IsTradeskillTrainer (:265), option.name (:275), realm (:238). The only pre-Safe use is the truthiness test `if continent and world` at :64, which does not compare or index. **Nil before login**: ShowPage (:171), the event handler (:244) and `Landmarks_Nearest` (:291) all return when `db` is nil — verified in the harness. **Bounded SV**: MAX_PLACES 400 per realm, enforced on insert (:106-113) — verified (433 -> 400, oldest dropped). **Dedupe**: see finding 2. **Output**: only `ForeverHub_Receive` (:38-43); no print/AddMessage anywhere; slash commands exist only as a secondary entry point, the hub page is the UI. **Rules**: read-only (no gameplay calls), no Blizzard frame manipulation, no hooks, no writes to Blizzard tables beyond the standard `SlashCmdList.LANDMARKS` registration.
5. **Harness**: `test_landmarks.lua` mocks C_Map/UiMapPoint/C_SuperTrack/merchant/trainer/gossip APIs, fires PLAYER_LOGIN, MERCHANT_SHOW (repair + food, then the same vendor 3 yd away, then a plain vendor, then a secret-named vendor), MAIL_SHOW x2, TAXIMAP_OPENED, TRAINER_SHOW x2, BANKFRAME_OPENED, CONFIRM_BINDER, GOSSIP_SHOW, then renders the page and pins. Assertions for the two bugs are left in with `-- BUG` comments; everything else (pre-login quiet, per-kind nearest, pin message + waypoint + super-track, unknown kind, other continent, unreadable position, MAX_PLACES prune) passes once those two lines are fixed.

## Summary
The addon is architecturally sound — read-only, hub-only output, every API read Safe()'d, every undocumented FrameXML global existence-guarded, SavedVariables capped — but it does not work as shipped: a one-line multiple-assignment slip at :203 makes the "Places" page error on every render once a single place is remembered, and the name-equality merge at :94 means only one mailbox (and one of any same-named or secret-named NPC) is ever kept. Both are two-line fixes and both are reproduced by `test_landmarks.lua`, which passes against a patched copy. The remaining items are a false "Pinned" message when a map refuses waypoints, a misleading "none on this continent" line when the position is unreadable, and an English-only innkeeper heuristic that could add the binder icon as a hint.
