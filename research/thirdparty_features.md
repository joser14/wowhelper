# Third-party addons: deep feature reverse-engineering (read-only pass 2)

**Folder:** `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\`
**Client:** WoW: Forever, interface 16001. It is a Classic-era world on a Midnight-based client: the combat log is closed to addons and many unit values are secret in combat.

**Scope of this file.** I cover VoidSweep, every VeritasUI_* module, QoL, Plater and AutoCompanion, each in full depth. RXPGuides and Auctionator are **covered separately** by dedicated workers. The appendix keeps only the Forever-specific facts about those two that turned up during this pass, so those workers can cross-check them.

**Method.**
- Read, Grep and Glob only. Nothing was run, loaded, copied, moved, changed or downloaded.
- VoidSweep (all 22 files, including CHANGELOG and README) and VeritasUI_PriorityRotation were read completely before they are moved out.
- No third-party code is reproduced here. Mechanisms are described in my own words, and `file:line` references are relative to each addon's folder.
- No seed or route data was extracted. Data is described by its structure only.

**Fit column**
- **Y**: fits the user's rules as is.
- **Y\***: fits with the change named.
- **N**: needs gameplay automation, writes persistent game settings, or hooks, hides or re-parents Blizzard frames.

**Size:** S is under a day, M is a few days, L is a week or more.

**"Ours" column:** the helper of ours that the feature would extend, "new" for a new helper, or "has it" where we already cover it.

---

## 1. VoidSweep (v0.2.21, GPL-3.0, "Vede" / bughatti)

Fully read: Core, CharSettings, Data, Scanner, Sightings, Layer, Spawns, Pins (+xml), Minimap, Poi, Route, Waypoint, MapButton, LayerUI, PresenceBox, Hop, VoidSync, WhisperNet, LayerNet, Seed, CHANGELOG, README.

Network parts (VoidSync, WhisperNet, LayerNet, PresenceBox, Hop) are described only for completeness. All of them are **N** for us: they share data with strangers, and Hop accepts invites and leaves the party automatically.

| # | Feature | What the player gets | How it works | Fit | Size | Ours |
|---|---|---|---|---|---|---|
| V1 | Live vignette scanner | Pins for rares, chests, world bosses and lore objects that are up right now | `C_VignetteInfo.GetVignettes`/`GetVignetteInfo`, re-read on VIGNETTES_UPDATED. Each is classified by **atlas substring**: loot/chest/treasure/cache/coffer/storage means chest; "kill", or objective type Defeat, means rare; a rare with `GetRecommendedGroupSize` of 5 or more means world boss; "loreobject" means lore. Dead vignettes are dropped. Position comes from `GetVignettePosition(guid, mapID)`. The file notes these reads are allowed while untainted, so they are not secret (`Scanner.lua:10-103`). | Y | S | has it (RareWatch reads VignetteKill/VignetteLoot only; the broader atlas list is worth copying) |
| V2 | Seed + learned + shared spot store | Known spawn spots before you have ever seen them | `learned[mapID][key]`, keyed by vignetteID (`v…`) or name (`n…`). Merge order: seed first (tagged `seed`), then learned records override position and name but keep the seed's completion references, then shared records fill gaps only. Each record is annotated **on a copy** with its latest sighting, so saved data is never changed. A classifier-version field wipes stale learned data (`Data.lua:20-250`). | Y | M | RareWatch |
| V3 | "Done" state | Looted chests disappear; rares are only dimmed | `C_QuestLog.IsQuestFlaggedCompleted(rec.questID)`. Rares and world bosses respawn, so they are never hidden, only dimmed (`Core.lua:69-71`, `Pins.lua:234-329`). | Y | S | RareWatch |
| V4 | Rare sightings from units (Forever has no rare vignettes) | "UP · seen 3 min ago" / "Killed 12 min ago" | Events: NAME_PLATE_UNIT_ADDED, PLAYER_TARGET_CHANGED, UPDATE_MOUSEOVER_UNIT, plus UNIT_HEALTH on the target for its death. The unit must be rare or rareelite and attackable, with a name that is not secret. Your position comes from `GetPlayerMapPosition` under pcall. The sighting is matched to a seed rare by name (lazy name index), choosing the **nearest** entry after projecting your child-map position (cave or town) onto the rare's map via `GetWorldPosFromMapPos`→`GetMapPosFromWorldPos`. It is rejected if more than 0.25 of the map away. "Up" lasts 300 s; a kill is kept for 7200 s (`Sightings.lua:23-156`). | Y | M | RareWatch (has unit sightings; lacks seed matching and an "up" TTL) |
| V5 | Layer inference | "Your layer: 6831-7" | Creature GUID `Creature-0-<server>-<map>-<shard>-<npcID>-<spawn>`: the `<server>-<shard>` pair is constant per layer. Gated on `RegionalUniqueNamesEnabled()` (Forever). Skips `UnitPlayerControlled` units and secret GUIDs. **One vote per GUID** (an older reading of the same GUID is replaced), up to 60 readings tagged with the zone, where zone = best map rolled up to Zone level. The answer is the plurality pair over the **last 180 s** for this zone and is trusted for 600 s. Readings are wiped on ZONE_CHANGED_NEW_AREA, PLAYER_ENTERING_WORLD and **group-membership change**, since a group invite is what moves layers. Nothing is saved (`Layer.lua:4-125`). | Y | S | RareWatch (see section 7) |
| V6 | Sightings tagged with layer | "Seen on another layer, not up for you" | Each sighting stores the layer; display compares it with `Compare(pair, zone)`. A kill on another layer never marks the rare dead on yours (`Sightings.lua:98-104,183`, `Pins.lua:143-145`). | Y | S | RareWatch |
| V7 | Delve treasure heat map | "Seen here on 7 of 10 visits" | Cells within radius 0.025 merge; the cell centre is a running mean. Each cell counts **once per visit**, with the per-run hit set kept per character so it survives /reload. A visit is a non-reload PLAYER_ENTERING_WORLD, counted once per map per run. An item seen in one cell is a fixed chest; in several cells it is random. Heat: confirmed (3+ visits) = 0.6+0.4×min(1,n/visits); unconfirmed = 0.12+0.1×(n−1) (`Spawns.lua:11-135`). | Y | M | new (gathering/chest heat map, fits ProfessionGuide/GoldGuide) |
| V8 | Treasures with no marker | Records bags and chests you open | Remembers the last UNIT_SPELLCAST_SENT whose name contains open, loot or search, matched by cast GUID to SUCCEEDED. On LOOT_OPENED within 4 s, `GetLootSourceInfo(1)` returns a GameObject GUID (corpses are ignored). The name comes from the last unit-less tooltip within 8 s, via **`GameTooltip:HookScript("OnShow")`** (`Spawns.lua:154-235`). | Y\* (replace the hook with a TooltipDataProcessor post-call for Object tooltips) | S | same as V7 |
| V9 | Proximity "cleared" for chests with no quest | Pins clear when you have been there | A 2.5 s ticker and VIGNETTES_UPDATED. A chest with no quest or criteria, not live now, with you within 22 yd (map world size from `C_Map.GetMapWorldSize`, fallback 0.012 of the map) is marked cleared for this character only. Quest-tracked chests are excluded because they vanished when flying past (`Data.lua:53-102`). | Y | S | Landmarks / RareWatch |
| V10 | World-boss area POIs zone-wide | World bosses and events with "Xm left" without being near | `C_AreaPoiInfo.GetAreaPOIForMap`/`GetAreaPOIInfo`/`GetAreaPOISecondsLeft`, filtered to world-boss atlases (`Poi.lua`). On Forever there are probably few or none; worth a probe. | Y | S | RareWatch |
| V11 | Pin assembly and de-dup | World map and minimap agree | De-dup key: spawnKey, else `q`+questID, else `v`+vignetteID, else name plus position rounded to 0.001. Priority = live +100, plus a per-kind rank (`Pins.lua:234-329`). | Y | S | any pin list |
| V12 | World-map pins | Dots by category; alpha and size encode up / killed / known / shared | `MapCanvasDataProviderMixin` with `SetScalingLimits`. **Combat rule:** never acquire or release pins in combat (protected mouse calls); only hide the old map's pins and redraw on PLAYER_REGEN_ENABLED. Refresh is debounced 0.4 s, with a re-check 2.5 s after VIGNETTES_UPDATED because completion flags arrive late (`Pins.lua:48-223`, `Core.lua:99-146`). | Y\* (data provider = sanctioned API but draws on Blizzard's map; the user decides) | M | Landmarks |
| V13 | Minimap pins without a canvas | Remembered spots on the minimap | offset = (pin − player) × map yards × ((minimap width/2) / `C_Minimap.GetViewRadius()`); y is negated; rotate by `GetPlayerFacing()` when the `rotateMinimap` CVar is on; draw only inside the circle. Positions update every frame; the list rebuilds every 1.5 s. Textures are parented to `Minimap` (`Minimap.lua:59-116`). | Y\* (own radar window instead of Minimap children) | M | new radar, or Landmarks |
| V14 | Cross-continent waypoint router | Click a far pin and get sent to the portal first | Portal table {map,x,y,toMap,faction,name}; world = `GetWorldPosFromMapPos` instance, walking up to 6 parents if needed; BFS over worlds filtered by faction → first hop. `C_Map.SetUserWaypoint` + `C_SuperTrack.SetSuperTrackedUserWaypoint(true)`; a 0.5 s ticker **clears within 20–30 yd using `C_Navigation.GetDistance()`**, only while ours is super-tracked. The next leg starts 1 s after ZONE_CHANGED_NEW_AREA. Ownership = `GetUserWaypointPositionForMap` still equals our coordinates. Also `hooksecurefunc(C_Map,"SetUserWaypoint")` (`Route.lua:33-217`, `Waypoint.lua`). | Y\* (drop the hook; the ownership compare is enough) | S–M | shared helper for Landmarks, DeathNotes, Dungeons, GoldGuide, RareWatch, QuestTracker, LevelGuide |
| V15 | Map-button filter menu with need/total counts | Per-category toggles showing "need 3 / 12" on this map | MenuUtil menu that stays open on toggle (`MenuResponse.Refresh`) (`MapButton.lua:28-60`) | Y\* (in our own window) | S | Landmarks |
| V16 | Layers window | Movable window: your layer, other layers, hop buttons | BackdropTemplate, saved position, Esc via UISpecialFrames (`LayerUI.lua`) | Y for the "your layer" part only | S | ForeverHub card |
| V17 | Per-character settings swap | Settings per character, new alt inherits the last | Swaps `chars["Name-Realm"]` into the live config on ADDON_LOADED and back on PLAYER_LOGOUT (`CharSettings.lua`) | Y | S | suite pattern |
| V18 | Players box / who-is-here / sync / hop / host | Crowd counts, shared sightings, layer hopping | Hidden channel with a daily rotating password, addon whispers to 8 random peers, auto accept/invite/leave (`VoidSync`, `WhisperNet`, `LayerNet`, `Hop`) | N | – | – |
| V19 | Slash `/vsw` | rare/chest/worldboss/lore toggles, completed, minimap, spawns, here, box, layer(s), hop, host, net, clear | Chat output (`Core.lua:161-264`) | Y\* (own UI) | – | – |

---

## 2. VeritasUI suite (v1.78.0, unknown author)

### 2a. VeritasUI_PriorityRotation: exactly how it decides the next spell

Fully read: Core.lua (decision path), Profiles.lua, plus the editor and settings as indexed by the sub-agent.

**There are no per-class priority lists.**
- `BuildDefaultProfile` returns an **empty** profile on Forever (`Profiles.lua:64-96`).
- On retail it seeds one entry, Blizzard's Single-Button Assistant spell (`C_AssistedCombat.GetActionSpell`). That API is unavailable on Forever (`IsAvailable` false, measured by the author, `Profiles.lua:79-81`).
- The player builds every list by hand in the editor: up to 10 entries, each a spell, macro or trinket.

**The decision is "blind".** By the author's own statement, the secure snippet cannot see cooldowns (`Core.lua:278-288`). It never reads cooldowns, usability, auras, power, health, range or combo points (grep: no `GetSpellCooldown`, `IsSpellUsable`, `UnitPower`, `UnitAura`, `IsSpellInRange` anywhere in the module). The algorithm:

1. **Compile, out of combat only** (queued with the combat queue if called in combat; 0.3 s debounce) (`Core.lua:313-522`).
   - Entry types:
     - A spell becomes `/cast [nochanneling] Name`, or `[combat, nochanneling]` when "Combat only" is ticked. The untagged entry acts as the opener.
     - A macro becomes its own body.
     - An item becomes `/use [nochanneling] item:ID`.
   - Optional "reacquire" prefix on spell steps: `/cleartarget [dead]` + `/targetenemy [noexists]`.
   - Stale spellIDs (`C_Spell.GetSpellInfo` returns nil) and deleted macros are skipped with a one-time warning.
   - **Placement: smooth weighted round-robin** (the nginx algorithm). Weight = frequency, 1–5. Cycle length = the sum of weights. Each slot, every entry gains its weight; the highest wins and pays back the total. Ties go to profile order. Adjacent duplicates are collapsed, including across the wrap-around. Result: a frequency-4 spell in a total of 10 is *attempted* every 2–3 presses.
   - Design rationale (`:278-294`): a not-ready attempt costs one key press (about 100 ms); a ready ability that waits costs seconds. So "priority" means "attempted more often".
2. **"After" links.** A follower spell can be tied to a **channelled** target spell.
   - Channel status is learned two ways. First, from the spell tooltip: lines 2–5 of `C_TooltipInfo.GetSpellByID` equal to `SPELL_CAST_CHANNELED`; secret text is not cached. Second, from the player's UNIT_SPELLCAST_CHANNEL_START spellID, skipped when secret (`Core.lua:793-864`).
   - The link compiles to a `[channeling:Target]` condition.
   - "Only after" followers are left out of the normal cycle.
3. **Runtime, inside a secure WrapScript on its own off-screen 1×1 SecureActionButton** (`Core.lua:135-245`).
   - Acts on key-up only (`useOnKeyDown=false`). The down/up parity bug is documented at `:157-170`.
   - On each press it runs `SecureCmdOptionParse("[channeling:X] 1")`, which is allowed in the restricted environment. While the target is channelling, every link on it is armed for 4 presses.
   - After the channel ends, presses alternate between an armed follower (round-robin across links) and the normal step. During that window the normal step **skips** steps that are link targets or followers.
   - Otherwise it writes the next compiled macrotext and advances `step % n + 1`.
   - The window is counted in presses because the restricted environment has no `GetTime`.
4. **How it copes with secret values.** It never reads any. The only runtime condition is the secure `[channeling]` conditional. The server rejecting a cast that is not ready does the rest. The only `issecretvalue` checks are on tooltip text and the channel spellID (`:812, :859`) and in `/pr diag` (`:1064-1219`), which reports whether `issecretvalue`, `C_Secrets` and `C_RestrictedActions` exist and which action slots return secret `GetActionInfo`.

Why it is **N** for us: it casts. The key is taken over with `SetOverrideBindingClick` on the bar slot holding "Attack", and it creates an "Attack" stub macro.

**Could a suggest-only version in our own frame work on this client?**

| Situation | What works | Why |
|---|---|---|
| Out of combat | **Yes, fully.** Lua can pick "the next spell": walk the user's priority list and return the first entry where `C_Spell.GetSpellCooldown` is off cooldown (ignoring the GCD), `C_Spell.IsSpellUsable` is true, and any aura or power condition holds. | Values are not secret out of combat. Useful for pre-pull checks and practice. |
| In combat, open world | **Partly; treat as unverified until probed.** RXP guards cooldown reads with `issecretvalue` (its `functions.lua:6388-6401`), Veritas reports that auras and power are secret when restricted, and Plater only uses **duration objects** for cooldowns on Midnight. So on Forever, Lua probably **cannot compare** cooldown or aura values in combat. | Midnight secret-value rules |
| In combat: the design that does work | A **"priority bar"**: the user's entries as a row of icons in priority order. Each icon gets a Cooldown widget fed by `C_Spell.GetSpellCooldownDuration(id)` → `SetCooldownFromDurationObject`. Usability is dimmed via `SetAlphaFromBoolean(C_Spell.IsSpellUsable(id))` or a desaturation curve. Range uses `SetAlphaFromBoolean(IsSpellInRange)`. The **widgets** evaluate the secrets; Lua never compares them (Plater's pattern). The player reads "leftmost bright icon = next". | Uses only display paths that accept secrets |
| In combat: single "next" icon | Possible only if the probe shows `GetSpellCooldown` is **not** secret on Forever in open world. Otherwise use a blind fallback: advance a pointer on each player `UNIT_SPELLCAST_SUCCEEDED` (spellID is secret only where casts are restricted) and track known cooldown lengths locally with `GetTime()` from the cast event. | Approximate |
| Procs and auras | Not available in combat if auras are secret (`C_Secrets.ShouldAurasBeSecret()`), and there is no combat log. | Limits "Overpower after dodge"-type rules |

**Probe before building**, out of and in combat on Forever. Use `/dump` of `issecretvalue(...)` on each of:
- `C_Spell.GetSpellCooldown(id).startTime`
- `C_Spell.IsSpellUsable(id)`
- `UnitPower("player")`
- `C_UnitAuras.GetAuraDataByIndex("player",1)`
- `C_Spell.IsSpellInRange(id,"target")`
- the spellID from player `UNIT_SPELLCAST_SUCCEEDED`

Display it as a new helper ("NextSpell" or "PriorityBar"). It is read-only: no secure buttons, no bindings, no macros. **Size M–L.** Reusable from Veritas: the editor UX (drag from `GetCursorInfo`, frequency spinner, "after" link, preview) and channel learning.

### 2b. VeritasUI_QualityOfLife

| # | Feature | What the player gets | How it works | Fit | Size | Ours |
|---|---|---|---|---|---|---|
| Q1 | Item level on icons | ilvl on bag, bank, character and merchant icons | Post-hooks `SetItemButtonQuality`/`MerchantFrame_Update`; ilvl from `GetItemInfo` return 4; `Item:ContinueOnItemLoad` with a **per-button token** so a recycled button never shows a stale number (`QualityOfLife.lua:861-1142`) | N; Y\* as a tooltip line | M | Tooltips |
| Q2 | Enchant / gem check | ✓/✗ per slot | `C_TooltipInfo.GetInventoryItem`, line **type 15** = permanent enchant; sockets via `GetItemNumSockets`/`GetItemGemID` (`:4206-4390`) | Y\* (own gear window) | M | ItemAdvisor |
| Q3 | Durability on the character sheet | % per slot | `GetInventoryItemDurability` + `GetInventoryAlertStatus` colours | Y\* | S | has it (DurabilityWatch) |
| Q4 | Stat → gear highlight | Which slots give stat X | `C_Item.GetItemStats` per slot; Forever stat list at CharacterStats.lua:52-104 | Y\* | S | ItemAdvisor |
| Q5 | Auto Equip + `/qol equipcheck` dry run | Equips upgrades | **Decision rules** (AutoEquip.lua:81-328): reject red tooltip text on either side; reject unbound BoE, trinkets, shirts, tabards, bags and profession tools (weapon subclass 14, fishing 20); **main stat by class, because `GetSpecializationInfo` reports the wrong stat on Forever**; "stat edge" = at least as good in every stat and better in one; never a lighter armour type; rank by ilvl, then quality, then armour (from stats or the tooltip "N Armor" line); rings replace the lower ring | N; Y\* as advice | L | ItemAdvisor (compare rules) |
| Q6 | Auto sell junk | – | Batches of 11 with `UseContainerItem`, paced by BAG_UPDATE_DELAYED, 0.5 s fallback, 5 s stuck detector | N | – | BagCheck shows junk value |
| Q7 | Auto repair (guild first) | – | `[noautorepair]` in guild info disables; `GetGuildBankWithdrawMoney()==-1` means unlimited; checks money first because RepairAllItems fails silently | N; Y\* as "repair cost / guild allowance" | S | DurabilityWatch |
| Q8 | Train All | – | Buys in descending index order | N | – | – |
| Q9 | Trainer copy window + "learnable now" button | Class-icon button when something is trainable; read-only trainer list with class and pet tabs | Captured on TRAINER_SHOW/UPDATE (general class trainers): name, type, icon, reqLevel, rank, cost, skill line, ability requirements **and tooltip lines** (`C_TooltipInfo.GetTrainerService`). Pet slot: `C_Trainer.GetTrainerType()==3`, costs in training points. Known spells from the `C_SpellBook` skill lines. Now/later split; pet uses `UnitLevel("pet")`. Re-read 1 s after PLAYER_LEVEL_UP; also SPELLS_CHANGED and PLAYER_MONEY. **Never save an empty list** (0 services right after a purchase) (`Trainer.lua:7-744`) | Y\* (drop the AddonCompartment re-anchoring; button in ForeverHub) | M | TrainerNotes |
| Q10 | Gossip, accept, turn-in and NPC rules (`/qol npc` decision log) | – | – | N | – | – |
| Q11 | Track latest reputation | – | `SetWatchedFactionByID` on FACTION_STANDING_CHANGED | N; Y\* "last faction gained" | S | RepWatch |
| Q12 | Clickable XP / rep bars | Click to open panels | Overlay parented to UIParent and only anchored to the bars; opens Character via a secure click on `CharacterMicroButton`, because opening it from addon code taints a secret health compare (`Journeys.lua:254-650`) | Y\* (ForeverHub buttons) | M | ForeverHub |
| Q13 | `/way` | Waypoint from coordinates; clears at 10 yd | Validates with `CanSetUserWaypointOnMap`; super-tracks; a 1 s ticker uses `C_Navigation.GetDistance` (`:284-322, 5455-5548`) | Y\* (coordinate box in our window) | S | Landmarks |
| Q14 | Map notes `/note` | Pins with icons on the world map | MapCanvas data provider + pin template; instance notes cleared on leaving; atlases checked with `C_Texture.GetAtlasInfo` (`:3326-3604`) | Y\* | M | Landmarks |
| Q15 | Tooltip "Target: X" | Who the unit targets | Unit post-call; unit from `UnitTokenFromGUID(data.guid)`; every read pcall'd and secret-checked (`:3907-3955`) | Y | S | Tooltips |
| Q16 | Tooltip mount owned | "Mount: collected / not" | Unit's helpful auras → `C_MountJournal.GetMountFromSpell` → `GetMountInfoByID` return 11 | Y (value on Forever unknown) | S | Tooltips |
| Q17 | Class / faction / guild-rank recolouring, guildmate highlight | – | Rewrites existing lines | Y\* (append instead) | S | Tooltips |
| Q18 | Accept guild invites, auto-accept res, skip cinematics, fill DELETE, open containers, unwrap collections | – | – | N; Y\* "openable items in bags" list (`ITEM_OPENABLE` match on `C_TooltipInfo.GetBagItem`) | S | BagCheck |
| Q19 | Online guild + friends list | Class-coloured list with level, zone, AFK/DND and notes | Polls micro-button hover at 10 Hz (no hooks); `C_GuildInfo.GuildRoster` at most every 10 s and never in combat; `C_FriendList` + `C_BattleNet` (`Social.lua:151-385`) | Y\* (ForeverHub button) | M | new "Social" card in ForeverHub |
| Q20 | AFK screen | – | Alpha 0 on UIParent, camera spin | N; Y\* own overlay | M | – |
| Q21 | Chat-link hover tooltips | Item tooltip when hovering a link in chat | EventRegistry `ChatFrame.OnHyperlinkEnter/Leave`, **no hooks** (`Chat.lua:61-95`) | Y | S | Tooltips |
| Q22 | Chat rewrites, history, timestamps | – | Message filters or AddMessage hooks | N; Y\* own chat-log window from CHAT_MSG events | M | – |
| Q23 | Whisper sound | Distinct whisper sound with cooldown | `MuteSoundFile(567421)` + own sound, 300 s cooldown | Y\* (changes sound state) | S | – |
| Q24 | Copy chat | Select chat text for Ctrl+C | `GetNumMessages`/`GetMessageInfo`, strip codes, `ScrollingEditBoxTemplate` (because `CopyToClipboard` is restricted) | Y\* | S–M | ForeverHub "copy" box |
| Q25 | M+ rating, DR, world quests, renown, vault, delves | – | Retail only (CharacterStats DR uses a binary search on the slope of `GetCombatRatingBonusForCombatRatingValue`; Forever converts at a flat rate) | n/a | – | – |

Slash commands: `/qol` (and subcommands ilvl, mappins, notes, npc, equipcheck, trainer, trainable), `/way`, `/note`, `/mapnote`. Defaults: `QualityOfLife.lua:101-261`. Options panel: `:4463-4898`.

### 2c. VeritasUI_ZoneQuests

| # | Feature | What the player gets | How it works | Fit | Size | Ours |
|---|---|---|---|---|---|---|
| Z1 | Zone-filtered quest tracking | Only this zone's quests in the tracker | **"Here" set** = best map + `GetMapChildrenInfo(map,nil,true)` descendants. Walk from the best map up through parents (stop at World or Cosmic) until `C_QuestLog.GetQuestsOnMap` returns entries, keeping only entries whose **own `.mapID` is in the here-set**; this rejects sibling zones whose art overlaps. Rejected alternatives: `GetQuestUiMapID` gives the hub map, not the objective; adding ancestors pulled in parent-zone quests. **Instances:** quest-log header equals the `GetInstanceInfo()` name or `GetRealZoneText()`. The super-tracked quest is always kept. Cached per zone, invalidated on QUEST_ACCEPTED. Debounced 0.3 s over ZONE_CHANGED*, QUEST_ACCEPTED, SUPER_TRACKING_CHANGED, QUEST_LOG_UPDATE (`ZoneQuests.lua:85-606`). Applying it adds and removes watches. | N as is; **Y\*** as a "This zone / Elsewhere" split in our own list | M | QuestTracker |
| Z2 | Restore original watches | – | Records the quests where `GetQuestWatchType(id)==nil` when switched on | n/a | – | – |
| Z3 | `/zq dumpquest <name>` | Every `C_QuestLog.GetInfo` field | Dev tool | Y\* (dev window) | S | !ErrorLog dev page |

Forever notes: `questClassification` is the only reliable type signal, value 4 is not "Meta" on Forever, and there are no campaign, legendary or daily quest kinds (`:221-236`).

### 2d. VeritasUI_Interface (only the information parts; the rest hides Blizzard frames)

| # | Feature | What the player gets | How it works | Fit | Size | Ours |
|---|---|---|---|---|---|---|
| I1 | "Resource not settled" | Mana or energy not full / rage not empty yet | `UnitPowerType`/`UnitPower`/`UnitPowerMax`; if secret, falls back to **timing of UNIT_POWER_FREQUENT** (whose powerType arg is plain) (`Interface.lua:627-699`) | Y\* (own indicator) | S | ReadyCheck / RestGuard |
| I2 | Hunter pet happiness | Pet unhappy warning | `C_PetInfo.GetPetHappiness()`: 1 Mad, 2 Neutral, 3 Happy (`:656-669`) | Y | S | ReadyCheck / FoodCheck |
| I3 | Expiring buffs + campfire | Buffs with 30 s or less left; "Campfire Nearby" | `C_UnitAuras.GetAuraDataByIndex(...,"HELPFUL")` on UNIT_AURA, skipping secret times; campfire = spell 1283391 (from wago, not measured) (`:1928-2004`) | Y | S | ReadyCheck / RestGuard |
| I4 | Gain detection for XP / rep / honor | Bars flash on gain | Compares `UnitXP`, `UnitLevel`, `C_Reputation.GetWatchedFactionData` on PLAYER_XP_UPDATE / UPDATE_FACTION (`:2195-2243`) | Y | S | has it (LevelLog/RepWatch) |
| I5 | Tracker sub-options: ready to turn in, quests with items | – | `QuestUtil.QuestShowsItemByIndex` | Y\* | S | QuestTracker |
| I6 | Mute spell fizzle | – | `MuteSoundFile` 569772-569776, reapplied each login | Y\* (sound state) | S | – |
| I7 | Fades and hides, banners, error-text filter, cancel transform auras | – | – | N | – | – |

### 2e. VeritasUI_AuctionHouse

| # | Feature | What the player gets | How it works | Fit | Size | Ours |
|---|---|---|---|---|---|---|
| A1 | Price DB | – | Keys: `p:<species>`, `i:<id>:<ilvl>` for gear, `i:<id>` otherwise. Record `{market, seen=unixDay, days[day]={min,max,qty}}`, 14-day retention per written item; records unseen for 30 days are pruned on scan day. `market` = last scan minimum. **No realm or faction key.** (`Database.lua:5-285`) | Y (improve: add realm+faction, use median of daily minimums) | S | PriceMemory |
| A2 | Browse full scan (default) | Whole AH in 10–15 s | Empty `SendBrowseQuery`, then `RequestMoreBrowseResults` until `HasFullBrowseResults`; waits for `IsThrottledMessageSystemReady`; reads BROWSE_RESULTS_UPDATED only when there are 500 results or fewer, plus ..._ADDED. **`minPrice` can be below the real cheapest listing (−7.7%, −41.8% observed)** (`Browse.lua:10-603`) | Y\* (user-clicked, own window) | M | PriceMemory / GoldGuide |
| A3 | Replicate scan (fallback) | – | Fails the first scan of most days; itemID at return 17, not 15; half the links are nil (`Replicate.lua`) | Y but browse is better | L | – |
| A4 | Live-search correction | Exact prices from your own searches | COMMODITY_SEARCH_RESULTS_UPDATED (min `unitPrice`) and ITEM_SEARCH_RESULTS_UPDATED (min `buyoutAmount`, **not** divided by quantity). Sends no queries (`LiveSearch.lua:151-267`) | Y | S | PriceMemory (best value) |
| A5 | Tooltip "Auction: … · N seen · X days old" | – | Item post-call; item from `TooltipUtil.GetDisplayedItem`, **validated against `data.id`** (recipe tooltips carry the taught item's link); bound items skipped via `C_Item.GetItemLocation(guid)` + `IsBound`; money via `MoneyFormatterUtil`/`GetMoneyString` (not `MoneyFrame_Update`, which crashes on secrets) | Y | S | has it (Tooltips) |
| A6 | Scan button, progress, 15-min floor | – | Journeys renown bar art + `SetTextureSliceMargins` | Y\* | M | PriceMemory |
| A7 | Sell strip | – | Hooks sell frames | N; Y\* own "sellable + price" list | S–M | GoldGuide |

There are no shopping lists, no deal-finding and no undercut logic in this module.

### 2f. VeritasUI_AdvancedOptions and Lib

| # | Feature | How it works | Fit | Size | Ours |
|---|---|---|---|---|---|
| O1 | Featured CVars (camera, nameplates, combat text `_v2`, action bars, targeting, tooltips, chat, graphics, accessibility) | Hides CVars missing on Forever via `GetCVarInfo(cvar)~=nil` | N to write; **Y** read-only "your CVars vs default" | M | !ErrorLog dev page |
| O2 | All-CVar browser | `C_Console.GetAllCommands` → `ConsoleGetAllCommands` → probe list; help text split into a value list | Y read-only | M | same |
| O3 | `/ao changed` / `/ao elvui` | CVars not at default | Y read-only | S | same |
| L1 | Blocked-action recorder `/vui taint` | ADDON_ACTION_FORBIDDEN/BLOCKED with count, first/last time, mouse focus, target and AH context | Y | S | has it (!ErrorLog logs these; add the context fields) |
| L2 | Copy settings between characters, managed panels, combat queue | Infrastructure | Y | S–M | suite |

Forever facts from comments:
- Missing CVars: `alwaysShowActionBars`, `reducedMotion`, `removeChatDelay`.
- `SetCVar` returns false silently for an unknown CVar.
- `hideHelptips` must be registered by the addon itself.

---

## 3. QoL (ollidiemaus, v0.2.0)

| # | Feature | What the player gets | How it works | Fit | Size | Ours |
|---|---|---|---|---|---|---|
| L1 | Sell junk (on by default) | – | MERCHANT_SHOW; Poor quality, has price, not locked; `RequestLoadItemDataByID` + **generation counter** + 1 s timeout; MERCHANT_CLOSED cancels; `C_MerchantFrame.SellAllJunkItems` (`Merchant.lua:27-113`) | N; Y\* junk-value pop-up | S | BagCheck |
| L2 | Auto repair with guild funds | – | budget = min(`GetGuildBankWithdrawMoney`, `GetGuildBankMoney`), −1 = unlimited | N; Y\* cost readout | S | DurabilityWatch |
| L3 | Quest auto accept / turn-in | – | Shift pauses; only takes a reward when there is one choice or none; NPC GUID loop guard | N | – | – |
| L4 | Faster auto-loot | – | – | N | – | – |
| L5 | Tooltip IDs (item, toy, spell, aura, NPC, quest, currency, achievement) | IDs on tooltips | One post-call per `Enum.TooltipDataType`, looked up **by name** so a type the client lacks is skipped; NPC ID = 6th GUID field (Creature/Vehicle only); `IsUsable` guard = not nil and not secret (`Tooltips.lua:14-27, 228-251`) | Y | S | Tooltips (check which types we cover) |
| L6 | Vendor sell price × stack | – | Stack via `tooltip.info.getterName`=="GetBagItem" + `getterArgs` → `GetContainerItemInfo().stackCount`; Shift shows stack total; it removes Blizzard's SellPrice line with `AddLinePreCall` | Y\* (append; skip when a SellPrice line exists, which our Tooltips already does) | – | has it |
| L7 | Hide micro menu, bags bar, chat buttons; sort on open; square minimap; viewport; bar growth; button borders; rings; click-cast; controller; following bars; trigger toggle; hide buff tooltip; class health bars | – | Reparenting or hooks | N | – | – |
| L8 | Druid mana bar in forms | Mana while in bear or cat | **Secret-safe:** `SetValue(UnitPower(...,MANA))` takes the secret directly; text via `SetFormattedText` + `AbbreviateLargeNumbers`; % via `UnitPowerPercent(…, CurveConstants.ScaleTo100)`; never and/or on a secret (`DruidManaBar.lua:58-162`) | Y\* (standalone movable bar) | S | ReadyCheck or new mini-bar |
| L9 | Spell rank upgrades | Rewrites bars to the highest rank | Detection: offered only if `C_ActionBar.IsHighestSpellRank` exists (used as a Forever detector); trigger LEARNED_SPELL_IN_SKILL_LINE; spellbook walk; **rank = first digits of `C_Spell.GetSpellSubtext`** (locale-free); group by `GetSpellName`; highest known via `GetSpellIDForSpellIdentifier(name)` + `IsSpellKnownOrInSpellBook`; slots found with `FindSpellActionButtons` and confirmed with `GetActionInfo`=="spell" (excludes macros); uncached spells retried 5× at 1 s (`RankUpgrades.lua:18-156`, `ClickCast.lua:90-96`) | N; **Y\*** rank audit | S | ReadyCheck (it already parses subtext; adopt `FindSpellActionButtons` and `GetSpellIDForSpellIdentifier`) |
| L10 | Class-coloured chat names | – | Sets CVar `chatClassColorOverride` | N (persistent setting) | – | – |
| L11 | `/rl` only if free | – | Checks `IsSecureCmd`, `hash_SlashCmdList`, and scans `_G` for `SLASH_*` == "/rl" | Y | S | ForeverHub |
| L12 | Mail bookmarks | – | Fills SendMailNameEditBox | N; Y\* alt list + copy box on MAIL_SHOW | S | ItemFinder |
| L13 | Alt roster with class | – | `characters["name-realm"]=classFile`; on Forever the key is **"First Surname-realm"** when `RegionalUniqueNamesEnabled()` (`SavedData.lua:37-57`) | Y | S | suite keying (section 7) |
| L14 | Dungeon/raid entrance and travel pins (boats, zeppelins, portals, tram) | Pins; hover shows destination; click jumps the map | Data: 56 entries {type, map, x,y 0–100, AreaTable `areas` → `C_Map.GetAreaInfo` names, `also`, `to`, `world` forever/classicEra, coordinate override}. MapCanvas data provider; pin size ÷ canvas scale; zone points projected to the continent via `GetMapRectOnMap`; Forever world detected by the existence of map 2521 (Zephras Isle) (`MapPins.lua:59-321`) | Y\* (data provider on Blizzard's map, or our own map window) | M | Dungeons / Landmarks |
| L15 | FPS and ping | – | 1 s ticker; `GetFramerate`, max of `GetNetStats` latencies, secret-checked; width measured with "999" to avoid jitter | Y\* (own frame) | S | ForeverHub status line |
| L16 | Hidden graphics CVars + `/qol probe` | – | 12 CVars with ranges measured on Forever; protected rows greyed in combat (`GetCVarInfo` isSecure) | N to write; Y read-only | M | dev page |
| L17 | Settings window and widget kit, option store (defaults stored as nil, wrong-type values ignored, versioned pcall migrations), combat-deferred keyed queue, Esc handling without UISpecialFrames, two-click "Sure?" confirm | Infrastructure | Y | S–M | suite infrastructure |

---

## 4. Plater (read-only information techniques only)

On Forever Plater runs its **Midnight branch** (builds 16001–19999). Combat-log features are dead there: spell capture, interrupt author, last-combat names.

| # | Feature | What the player gets | How it works | Fit | Size | Ours |
|---|---|---|---|---|---|---|
| P1 | Quest-mob detection with x/y | "This mob is for quest X, 3/8" | **Title cache** from the quest log (skipped in instances), rebuilt with a 1 s debounce on 9 quest events plus once 4.1 s after login. **Per unit:** a non-secret GUID → `C_TooltipInfo.GetHyperlink("unit:"..guid)` → keep lines of type QuestObjective/QuestTitle/QuestPlayer (stop if a line type is secret). A title line starts a block that ends at the `THREAT_TOOLTIP` line. Objectives are parsed as `(%d+)/(%d+)` or `(%d+%%)`. A quest mob = title matched **and** at least one objective unfinished. Open world only (`Plater.lua:11434-11692`) | Y | M | Tooltips line "Quest: X 3/8" + QuestTracker "nearby quest mobs" |
| P2 | Threat state | Aggro colour | `UnitThreatSituation("player",unit)`, 2 or more = tanking; your own value compared directly | Y | S | – |
| P3 | Cast bar | Cast name, interruptible, target | `UnitCastingInfo/ChannelInfo`; timing via `UnitCastingDuration` → `StatusBar:SetTimerDuration` (Lua never reads times); colours via `C_CurveUtil.EvaluateColorValueFromBoolean`; target via `UnitSpellTargetName`; "interrupted by" from the event's `interruptedBy` GUID | Y | M | – |
| P4 | Interrupt-ready spark | Whether your interrupt is up before the cast ends | Per-class interrupt list checked with `C_SpellBook.IsSpellKnown`; `GetSpellCooldownDuration`; a transparent StatusBar anchored to the cast fill with max = cast duration and value = remaining cooldown, so **geometry does the comparison** (`Plater_Interrupts.lua:249-527`) | Y | M | NextSpell idea |
| P5 | Execute range | – | Step colour curve + `UnitHealthPercent(unit,true,curve)` → alpha | Y | S | – |
| P6 | Health text | – | Secret numbers through `AbbreviateNumbers`/`format("%d%%")` straight into `SetText` | Y | S | – |
| P7 | Level and difficulty colour | – | `UnitLevel`, `C_PlayerInfo.GetContentDifficultyCreatureForPlayer`, `GetDifficultyColor` | Y | S | Tooltips / ZoneLevels |
| P8 | Classification and rare flash | – | `UnitClassification`; `/plater rare` = a 3 s ticker over plates + `FlashClientIcon` | Y | S | has it (RareWatch); `FlashClientIcon` worth adding |
| P9 | NPC colour / rename / notes DB | – | `npc_colors[npcID]`, `npcs_renamed`, auto `npc_cache[npcID]={name,zone}` | Y | S | Tooltips "your note" line |
| P10 | NPC name from ID with no unit | – | `C_TooltipInfo.GetHyperlink("unit:Creature-0-0-0-0-<id>")` line 1, retried every 0.25 s up to 10 times | Y | S | RareWatch / Dungeons |
| P11 | NPC subtitle and pet owner | "<Weapon Merchant>", owner name | Tooltip line 2 (shifted one line in colorblind mode; reject `UNIT_LEVEL_TEMPLATE`); owner via patterns from `UNITNAME_TITLE_PET/MINION/GUARDIAN` | Y | S | Landmarks (NPC role) |
| P12 | Range | – | LibRangeCheck; secret boolean → `SetAlphaFromBoolean` | Y | S | – |
| P13 | Target existence without touching secrets | – | `type(UnitGUID("target")) ~= "nil"` | Y | – | all |
| P14 | Auras under secrets | – | `C_UnitAuras.IsAuraFilteredOutByInstanceID` with filter strings (plain booleans); `GetUnitAuras` sorted by expiration; `GetAuraDuration` → `SetCooldownFromDurationObject`; dispel colour curve | Y | M | ReadyCheck (missing buffs in combat) |
| P15 | Tapped, friends, guild, surnames | – | `UnitIsTapDenied` and not player-controlled; FRIENDLIST_UPDATE cache; `UnitName` 2nd return = surname, joined with `CHARACTERNAME_SURNAME_SEPARATOR` | Y | S | Tooltips |
| P16 | Ghost auras (missing DoTs) | – | Disabled on Forever | n/a | – | – |

---

## 5. AutoCompanion (v6.6.24, retail-only TOC; likely not loading)

| # | Feature | How it works | Fit | Size | Ours |
|---|---|---|---|---|---|
| C1 | Time of day | `GetGameTime()` realm clock: 21–05 night, 06–09 morning, else day; nil in instances (`Seasons.lua:84-94`) | Y | S | ForeverHub |
| C2 | Holiday detection | `C_DateAndTime.GetCurrentCalendarTime` → `C_Calendar.GetMonthInfo(0)` gives the **month offset** (the player may have browsed the calendar); `GetNumDayEvents`/`GetDayEvent`, `calendarType=="HOLIDAY"`, match eventID (locale-free) or title; respects start/end on the first and last day; 0 events = not loaded yet; fallback fixed date table incl. Lunar Festival offsets; cached 30 s; `C_Calendar.OpenCalendar()` once (`Seasons.lua:111-170`) | Y | S | ForeverHub "events today" |
| C3 | Subzone "spots" + per-zone overrides | `GetSubZoneText`; subzone beats zone beats default | Y pattern | S | Landmarks |
| C4 | Pet stats, error capture (last 20 distinct), "baseline from previous session" before calling anything new | `seterrorhandler` chain; journal loads gradually so it waits a session | Y | S | has it (!ErrorLog); baseline idea for ItemFinder "new items" |
| C5 | Auto summon, re-randomize, sound muting | – | N | – | – |

---

## 6. Clever techniques for this client (from the addons covered here)

1. **Never branch on a secret; let a widget decide.** Use `SetValue(secret)`, `SetTimerDuration(durationObj)`, `SetCooldownFromDurationObject`, `SetAlphaFromBoolean(secretBool)`, `C_CurveUtil.EvaluateColorValueFromBoolean`, step colour curves passed to `UnitHealthPercent`/`UnitPowerPercent`, and `AbbreviateNumbers`/`format` into `SetText` (Plater, QoL DruidManaBar). Duration objects are new on every call, so always re-set them. This is the only way to show cooldowns, health or power in combat.
2. **Use event timing when the payload is secret.** UNIT_POWER_FREQUENT's powerType is plain even when the value is secret (Veritas Interface I1). A cast-event spellID is secret only where casts are restricted.
3. **Layer from GUIDs.** Take the `<server>-<shard>` plurality with one vote per GUID, a 180 s window, per-zone readings and 600 s trust. Reset on zone **and on group-membership change**, and skip `UnitPlayerControlled` units (VoidSweep `Layer.lua`).
4. **Rare matching.** Match name → seed list, choose the nearest after projecting your child-map position through world coordinates, and reject matches beyond a distance (VoidSweep `Sightings.lua:63-83`).
5. **Typed tooltip lines.** `C_TooltipInfo.*` lines carry a `type` (QuestObjective/QuestTitle/QuestPlayer, 15 = permanent enchant, SellPrice). Prefer types over text. Each call costs about 0.05–0.1 ms, so don't bulk-scan bags each frame (Plater P1, Veritas Q2).
6. **Zone membership for quests.** Use `GetQuestsOnMap` entries filtered by their own `.mapID` ∈ best map ∪ descendants, plus header == instance name for instance quests (ZoneQuests Z1).
7. **Waypoint hygiene.** Set and super-track the waypoint, clear it on arrival with `C_Navigation.GetDistance()`, and only clear it if `GetUserWaypointPositionForMap` still matches ours (VoidSweep Route, Veritas /way).
8. **Map pins in combat.** Never acquire or release pins in combat; hide them and rebuild on PLAYER_REGEN_ENABLED. Debounce bursty quest and vignette events; re-check 2.5 s later for late completion flags (VoidSweep).
9. **Client detection.** Forever can be detected by `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` (18; Veritas measured), by `RegionalUniqueNamesEnabled()`, by map 2521 existing, or by `C_ActionBar.IsHighestSpellRank` existing. QoL says WOW_PROJECT_ID was unreliable for it, so use two signals.
10. **Spec on Forever.** One spec per class, named after the class. `GetSpecializationInfo` returns the wrong main stat, so use a class → main-stat table (Veritas AutoEquip).
11. **Trainer.** Data is only available while the window is open. Return order is name, type, texture, reqLevel, subText (Veritas sourced this from the Forever branch of Blizzard_TrainerUI). The list includes future levels (119 services). It can briefly be empty after a purchase. `C_TooltipInfo.GetTrainerService(i)` lets you save tooltip text. Pet trainer = `C_Trainer.GetTrainerType()==3`.
12. **PLAYER_LEVEL_UP.** `UnitLevel` can still return the old level, so use the event argument or re-read after 1 s.
13. **`InCombatLockdown()`** can be false on the PLAYER_REGEN_DISABLED frame itself; re-check with `C_Timer.After(0)`.
14. **Async item data.** Request the item, then use a generation counter or a per-button token plus a timeout, so stale callbacks never paint (QoL L1, Veritas Q1).
15. **Calendar month offset** before reading day events (AutoCompanion C2).
16. **Copy text.** `CopyToClipboard` is restricted, so show a selected `ScrollingEditBoxTemplate` for Ctrl+C.
17. **Chat-link hover without hooks:** `EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkEnter", …)`.
18. **Midnight dropdown taint (WoWUIBugs #783):** call `root:SetMinimumWidth(n)` at the top of every Menu generator. This is relevant if we ever add dropdowns; the suite currently has none.

---

## 7. Where our helpers do worse, or could do better (specific)

1. **Character keys collide on Forever.** These helpers key per-character data as `UnitName("player")` (first return only) .. "-" .. realm:
   - ItemAdvisor `ItemAdvisor.lua:1301`
   - LevelLog `:70`
   - GoldGoal `:140`
   - ItemFinder `:190`
   - SupplyWatch `:201`
   - TrainerNotes `:286`
   - LevelGuide `:1703`
   - ForeverHelper `:275`

   Forever names are **first name + surname**, with regional unique names (`UnitName` 2nd return; QoL `SavedData.lua:46-57`, Plater P15, RXP joins both too). Two characters with the same first name on one realm would share data. Fix: one shared key function using `UnitGUID("player")`, which also survives renames and detects a re-created character, or name+surname+realm, plus a one-time migration of the old key.
2. **RareWatch layer guess** (`RareWatch.lua:9-10, 175-204`) compared with VoidSweep:
   - It uses a 10-sample ring with no time window, so readings from minutes ago still vote.
   - It does not reset on **group join or leave**, which is exactly when layers change.
   - It does not tag readings with the zone, so a sub-zone move in one area keeps old readings.

   Fix: store a time and zone per sample, use a ~180 s window, and reset on GROUP_ROSTER_UPDATE when `IsInGroup()` flips. Keep the existing "≥3 to change" hysteresis, which is good. Also tag each rare sighting with the layer and show "seen on another layer".
3. **RareWatch rare data.**
   - It only knows rares you have seen. There is no "known spawn spots" list and no "up" TTL; VoidSweep shows "UP" for 5 minutes, then known or killed.
   - The marker classifier only matches `VignetteKill`/`VignetteLoot`; VoidSweep's broader atlas words also catch chest, cache, coffer and loreobject.
   - It does not use `FlashClientIcon` for alt-tabbed players (Plater P8, RXP).
4. **No waypoint arrival clear anywhere in the suite.** Landmarks `:170-176`, DeathNotes `:182-188`, Dungeons `:206-216`, GoldGuide `:353-360`, QuestTracker `:391-394`, LevelGuide `:1301-1302` and RareWatch `:454-469` all set a user waypoint, but none uses `C_Navigation.GetDistance` to clear it on arrival or checks ownership before clearing. Several (LevelGuide, QuestTracker) also don't super-track. One small shared "SetOurWaypoint / clear on arrival / don't clobber the user's own pin" routine (VoidSweep Route, minus the hook) would fix all of them.
5. **TrainerNotes:**
   - The return-order risk noted in our earlier review (T1) is settled. Veritas sourced the Forever-branch Blizzard_TrainerUI: (name, type, texture, reqLevel, subText) is the live order, so the primary branch in `TrainerNotes.lua:164-170` is right. The fallback branch can stay.
   - Missing compared with Veritas: hunter **pet** trainer lists (type 3, training points), saving each service's tooltip text so the player can read what a spell does, and a "train now" cue in ForeverHub.
6. **ReadyCheck rank audit.** It already parses rank from `GetSpellSubtext` (`ReadyCheck.lua:189,229`). Adding `FindSpellActionButtons(oldRankID)` + `GetActionInfo`=="spell" would show **which bar slot** holds the old rank and skip macros, as QoL does. The highest known rank comes from `GetSpellIDForSpellIdentifier(name)`.
7. **QuestTracker zone grouping.** It has no `GetQuestsOnMap`/`GetMapChildrenInfo` zone-set logic (only LevelGuide calls `GetQuestsOnMap`, `LevelGuide.lua:211`). The ZoneQuests algorithm would give a correct "This zone" section, including instance quests matched by header.
8. **PriceMemory** (per Veritas and Auctionator findings):
   - Key prices by realm **and faction**.
   - Store daily low/high and use a median of daily minimums, not just the last price.
   - Treat browse `minPrice` as approximate and correct it from the player's own live searches (Veritas A4).
9. **!ErrorLog** already catches ADDON_ACTION_BLOCKED/FORBIDDEN. Veritas also records the context (mouse focus, target present, which Blizzard UI was open), first and last time, and a count. That is cheap and makes taint reports actionable.

---

## 8. Ranked "build next" (scope of this file: VoidSweep, VeritasUI, QoL, Plater, AutoCompanion)

| Rank | Feature | Source | Where | Size |
|---|---|---|---|---|
| 1 | RareWatch v2: layer guess with a time window and group-change reset, layer-tagged sightings, "UP for 5 min / killed N min ago", broader marker classes, FlashClientIcon | VoidSweep Layer + Sightings, Plater | RareWatch | M |
| 2 | Shared waypoint routine: super-track, auto-clear on arrival, ownership check, optional portal/boat first hop | VoidSweep Route, Veritas /way | small shared file used by 7 helpers | S–M |
| 3 | Quest-mob detection: tooltip line "Quest: X 3/8" and "nearby quest mobs" | Plater P1 | Tooltips + QuestTracker | M |
| 4 | "This zone / Elsewhere" quest split with instance-header matching | Veritas ZoneQuests | QuestTracker | M |
| 5 | Spell-rank audit naming the exact bar slot | QoL RankUpgrades | ReadyCheck | S |
| 6 | Pet happiness, expiring buffs, campfire nearby, mana not full | Veritas Interface I1–I3 | ReadyCheck / RestGuard | S |
| 7 | Trainer v2: pet trainer, saved spell tooltip text, "learnable now" hub cue | Veritas Trainer | TrainerNotes | S–M |
| 8 | Dungeon entrance and travel (boat, zeppelin, portal) pins with click-through, own data | QoL MapPins | Dungeons / Landmarks | M |
| 9 | Chest and lore spots: proximity "cleared", plus world-boss POIs if present | VoidSweep Data/Poi | Landmarks / RareWatch | S |
| 10 | Tooltip extras: unit "Target: X", chat-link hover, NPC subtitle/role, your NPC notes | Veritas Q15/Q21, Plater P9/P11 | Tooltips | S |
| 11 | Spawn/heat map ("seen here on 7 of 10 visits") for chests and gathering nodes | VoidSweep Spawns | new (or ProfessionGuide/GoldGuide) | M |
| 12 | Read-only priority bar (secret-safe icons with cooldown swipes); probe first | PriorityRotation editor + Plater widgets | new "NextSpell" | M–L |

Honourable mentions:
- Online guild/friends card in ForeverHub (Veritas Q19, M).
- Holiday/"events today" and time-of-day (AutoCompanion C2, S).
- Copy-chat box (S).
- Read-only CVar viewer for debugging (M).
- Character key fix (section 7.1). This is not a feature but should be done first.

---

## Appendix: Forever facts about RXPGuides and Auctionator found during this pass (for the dedicated workers to cross-check)

**RXPGuides**
- On Forever (`addon.game=="FOREVER"`), item upgrades and the AH upgrade scanner are switched off (`ItemUpgrades.lua:6-10`).
- Rare lists are empty for build 11508 and later (`DB/forever/rares.lua:8`).
- Proximity unit-scan is off, because `TargetUnit` is forbidden since 1.15.8 (`SettingsPanel.lua:22-32, 498-507`).
- Quest log size is 40 on Forever (`QuestLog.lua:26-27`).
- Spell 418460 fires UNIT_SPELLCAST_FAILED_QUIET on each resurrection (`functions.lua:2927`).
- Explored subzones are detected via UI_INFO_MESSAGE type 408 against an `ERR_ZONE_EXPLORED` pattern (`RXPGuides.lua:1838-1848`).
- Taxi data comes from `C_TaxiMap.GetAllTaxiNodes` on TAXIMAP_OPENED; node hash = floor(x·4096)+floor(y·4096)·4096 (`Timers.lua:189-293`).
- Exact level times come from TIME_PLAYED_MSG (`LevelingTracker.lua:228-298`).
- `CHAT_MSG_COMBAT_XP_GAIN` text can be secret.
- Calendar-based DMF detection (`functions.lua:6777-6855`).
- Drowning warning via `GetMirrorTimerProgress("BREATH")` (`Tips.lua:72-120`).
- Spirit-healer DB stores world coordinates with wx/wy swapped (`map.lua:1071-1091`).

**Auctionator**
- On Forever it loads the **ModernAH + Mainline** code (`Source\Constants\Main.lua:56-57`).
- Classic disenchant/mill/prospect tables and the random-suffix keys are not loaded, so disenchant tooltips are blank and suffix gear collapses to one key.
- The price DB is keyed by realm without faction.
- Daily `h`/`l`/`a` history is pruned to 21 days per written key.
- Two bugs: `GetMeanPrice` indexes string day keys numerically (`Database\Mixin.lua:219`), and the day number is computed once at file load (`:7`).
- Passive capture listens to browse results only when there are 500 or fewer (`IncrementalScan\Mixins\Frame.lua:31-46`).
- The vendor buy-price cache stores unlimited-stock items only (`CraftingInfo\Main.lua:7-28`).
