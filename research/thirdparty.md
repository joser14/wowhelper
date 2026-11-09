# Third-party addon review (WoW Forever, interface 16001)

Scope: `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\` — Auctionator, AutoCompanion, Plater, QoL, RXPGuides, VeritasUI_* (7 folders), VoidSweep. Read-only review (Grep/Glob/Read plus PowerShell listing/magic-byte reads). Nothing was run, moved, changed or downloaded. No web research was done in this pass, so "known public" comes from the files themselves (TOC IDs, licence, changelog links) and general knowledge.

## 0. Whole-tree file safety scan (all 13 folders)

- **No executables or scripts outside Lua.** Extension inventory: .lua, .xml, .toc, .tga, .blp, .png, .ogg, .ttf, .otf, .md, .txt, plus harmless dev files: Plater `cspell.json`, `stylua.toml`, `config.ld`, `ldoc.css`, `README.textile`, `COPYING(.LESSER)`, LICENSE files, a git-style `Plater\Plater` text file, and RXPGuides `Textures\DarkMode\CLASS_ICONS.psd` (Photoshop magic `8BPS`). No .exe/.dll/.bat/.cmd/.ps1/.vbs/.js/.scr/.jar anywhere.
- **Magic-byte check of every file:** no PE (`MZ`), ZIP (`PK`) or ELF headers hidden behind any extension. Every extensionless file is plain text (LICENSE/COPYING).
- No hidden or system-attribute files.
- **Obfuscation:** none in the unknown addons (no `loadstring`, `RunScript`, `string.char` chains or long base64 blobs). Hits in known addons are expected:
  - Plater `Plater.lua:13372/13424/13637/13767` and `Plater_ScriptingPanels.lua:1781`: `loadstring`. This is Plater's user-script system. `Plater.lua:13118-13122` blocks `RunScript`/`loadstring` inside those scripts.
  - `Plater_ScriptLibrary.lua:114,561`: encoded built-in script imports.
  - RXPGuides `GuideLoader.lua:422`: RC4-style decode for its encrypted premium guides.
  - RXPGuides `DB\questDB.lua:1156`: `loadstring("return "..str)` under `setfenv(t,{})`, i.e. sandboxed data parsing.

## 1-4. Per-addon findings

### Auctionator — SAFE (well-known public)
- TOC: Title Auctionator, Author plusmouse/Borjamacare, Version 343, Interface includes 16001, X-Website curseforge.com/wow/addons/auctionator.
- Comms: only `C_ChatInfo.RegisterAddonMessagePrefix("Auctionator")` (`Source\Initialize\Main.lua:13`). The whisper export at `Source\Tabs\Shopping\Mixins\ExportFrame.lua:118,121` is commented out.
- Behavior: AH full scan into a price DB, tooltip prices, shopping lists, a selling tab, posting history and a vendor price cache. Buying and posting need your clicks (Blizzard requires a hardware event). It changes the AH UI with tabs, which is the normal pattern.
- Overlap: **PriceMemory**, which it far exceeds with full scans and tooltip prices.

### Plater — SAFE, heavy UI replacement (well-known public)
- TOC: Plater-v663-Forever (`Plater_Camelot.toc`, Interface 16001), CurseForge 100547, Wago kRNLep6o.
- Comms: script/profile sharing to party/raid and an NPC-colour share (`Plater_Comms.lua:107,110,1004,1067`; `Plater_ImportExport.lua:547,550`). These run only on export or share actions. `Plater.lua:2425` reads the BNet friend list. That is used to colour friends' nameplates; nothing is sent.
- Behavior: replaces Blizzard nameplates and lets you import Lua scripts. Imported scripts from strangers are the real risk vector. Expect taint/perf issues on a new client.
- Overlap: none.

### RXPGuides (RestedXP) — SAFE source, but heavy AUTOMATION options (well-known public)
- TOC: v4.11.35, Author RestedXP, CurseForge 486246, Interface includes 16001. Ships `Guides\forever\*` leveling routes.
- Automation (settings-controlled):
  - auto accept/turn-in (`RXPGuides.lua:1186,1199`)
  - auto-pick quest reward by sell value (`:1026,1030`)
  - auto train (`:639,679`; `functions.lua:7223`)
  - auto take flight path (`functions.lua:2885`)
  - auto gossip select (`functions.lua:342,5878…`)
  - auto buy (`functions.lua:5667`)
  - delete-junk keybind with `DeleteCursorItem` and `SetBinding` (`InventoryManager.lua:584,656-658`)
  - creates/edits target and follow macros (`Targeting.lua:190,255,284-303`)
- Chat: level-up announcements to PARTY/GUILD/EMOTE if enabled (`Communications.lua:30-35`). Party comms for group sync (`:342,819`).
- `DB\questDB.lua:1764-1819`: whispers GM dot-commands (`.additem`, `.q c`, `.go xy`) **to yourself**. This is a developer test helper, gated to a PTR build at `:1753`. Harmless.
- Overlap: **LevelGuide** (direct competitor), QuestCheck/QuestTracker, ItemAdvisor (`ItemUpgrades.lua` stat weights), LevelLog (`LevelingTracker.lua`), TalentNudge (`Talents.lua`), BagCheck (`InventoryManager.lua`).

### QoL ("Quality of Life", ollidiemaus) — AUTOMATION, otherwise clean
- TOC: v0.2.0, CurseForge 1733916, GitHub ollidiemaus/qol (CHANGELOG). Small and new (changelog dated 2026-11-08). The author also publishes Auto Potion, AutoSetup and Wayscribe; `UI\InfoPage.lua:40-52` cross-promotes them with CurseForge links (benign).
- Automation:
  - **sell junk is ON by default** (`Core\Options.lua:13`; `Features\Merchant.lua:62`)
  - auto repair, optionally from guild funds (`Merchant.lua:137-151`, off by default)
  - auto accept/turn-in (`Features\Quests.lua:116,128,137`, off)
  - instant loot (`FasterAutoLoot.lua:27`, off)
  - auto bag sort (`SortOnOpen`, off)
  - rewrites action-bar spells to the highest rank (`RankUpgrades.lua`, off)
  - click-casting and action rings (`ClickCast.lua`, `Ring*.lua`): secure bindings, not casting on its own
- Changes Blizzard UI: hides micro menu, bags bar, chat buttons; square minimap; viewport; class-coloured bars. These are taint-prone hooks.
- No comms.
- Overlap: BagCheck/DurabilityWatch (sell/repair), Landmarks (map travel pins), ItemFinder/GoldGoal (mail bookmarks track characters).

### AutoCompanion (Lege Salvesen) — AUTOMATION (cosmetic), probably not loading
- TOC: v6.6.24, Interface 120000-120107 **only, no 16001**. On Forever it shows as out of date and loads only with "load out-of-date". CurseForge link in `UI_Options.lua:956`.
- Behavior: auto-summons and re-randomizes vanity pets (`Core.lua:722` `C_PetJournal.SummonPetByGUID`). Hooks `SummonRandomPet` (`Core.lua:1459`).
- `Main.lua` refuses to run on Russian-locale clients by reading locale CVars. That is a political stance, not a risk.
- No comms or obfuscation. Overlap: none.

### VeritasUI suite (Lib, AdvancedOptions, AuctionHouse, Interface, PriorityRotation, QualityOfLife, ZoneQuests) — UNKNOWN author "NQV4X0QN", v1.78.0
- Not a recognizable public addon: no website, CurseForge or Wago ID.
- The comments read like a private, AI-assisted project built for an "owner". Examples: "owner's request, 2026-11-04", "~/.agents/skills/veritasui/references/…" (`ZoneQuests.lua:17`), and "MEASURED, owner's PC" (`Replicate.lua`).
- No malware signals. No comms anywhere in the suite. No obfuscation. No URLs.
- It is very invasive of Blizzard frames: many `hooksecurefunc` hooks and frame hides (`Interface.lua` header admits "almost entirely via hooksecurefunc"). It also writes CVars from the AdvancedOptions browser.

#### VeritasUI_PriorityRotation — AUTOMATION / ToS gray: a one-button rotation that casts, not suggests
- `Core.lua:135-149` creates an invisible 1×1 px `SecureActionButtonTemplate` (`type=macro`) parked off-screen.
- `Core.lua:197-245` is a secure `WrapScript` that rewrites `macrotext` to the next `/cast` step on every key press, GSE-style.
- `Core.lua:772` `SetOverrideBindingClick` points your key at it. It also scans and overrides an action-bar button (`ScanAndOverrideBarButton`).
- One cast still needs one key press, so it is not a bot. But it decides and casts for you, which breaks the user's read-only rule.

#### VeritasUI_QualityOfLife — AUTOMATION, several ON by default
- On by default:
  - `autoSellJunk=true` and `autoRepair=true` (`QualityOfLife.lua:102-103`; sells at `:489`, repairs with guild funds first at `:629-646`)
  - `autoAcceptRes=true` (`:168`; `Automation.lua:43`)
- Off by default:
  - auto accept/turn-in quests (`QualityOfLife.lua:3796-3804`)
  - accept guild invites (`Automation.lua:74`)
  - auto open containers (`Automation.lua:219`)
  - **auto equip upgrades** (`AutoEquip.lua:383` `C_Item.EquipItemByName`)
  - Train All (`QualityOfLife.lua:3864`)
  - skip cinematics, and auto-fill "DELETE" in the item-delete confirmation (`:3631`)
- Also: "Remember Chat History" saves chat, including whispers, to disk in SavedVariables (privacy note only).
- Social online lists read the BNet friend list (`Social.lua:202-205`), read-only.

#### Other VeritasUI modules
- **VeritasUI_Interface:** fades and hides Blizzard frames via secure hooks. Taint risk; no automation.
- **VeritasUI_ZoneQuests:** adds and removes quest watches per zone (`ZoneQuests.lua:311,321,365,367`). It changes your tracker state, but this is UI only.
- **VeritasUI_AuctionHouse:** price DB from ReplicateItems or browse scans, tooltip price, and a Sell-tab strip. The strip forwards your own clicks to Blizzard buttons (`SellStrip.lua` header).
- **VeritasUI_AdvancedOptions:** a hidden-CVar browser. The CVars it writes persist account-wide. `ElvUIChanges.lua` and `EllesmereUIChanges.lua` are data about other suites.

#### Overlaps
- ItemAdvisor (item levels, auto equip), DurabilityWatch/BagCheck (repair/sell), PriceMemory (AH DB), QuestTracker/QuestCheck (ZoneQuests), TrainerNotes (Trainer.lua), Landmarks (map notes, `/way`), RepWatch (track latest reputation).

### VoidSweep ("Vede", v0.2.21, GPL-3.0) — RISK (network + ToS gray + automation)
- Public-ish: README links github.com/bughatti/voidsweep, CurseForge member bughatti, voidscout.io, tinkerline.io and a Discord invite (`README.md:99`). It is part of a "Void addon family" (VoidGather, VoidQuest).

**Network, ON by default** (`Core.lua:62` `sync = true`):
- Joins a hidden chat channel and removes it from your chat tabs (`VoidSync.lua:120-127`).
- On Forever, it addon-whispers your rare sightings to up to 8 random strangers (FANOUT, `VoidSync.lua:53,151-152`). The payload includes mapID, x/y and your layer, plus zone catch-up requests (`VoidSync.lua:145-149`, `Sightings.lua` header `SN:2`).
- Strangers can therefore learn where you are and when.
- Inbound messages are validated, as the security model at `VoidSync.lua:9-20` describes. They are never executed.

**Moderation evasion — the main red flag:**
- `WhisperNet.lua:273-298` generates a new channel name and password every UTC day from a hard-coded salt (`VoidSync.lua:49` `DAILY_SALT 69621`).
- The comment says it is built this way so "neither is written in the files as text" and so that "a ban… lasts one day at most".
- It also leaves older banned channels (`VoidSync.lua:48,107-108`).
- This is deliberate obscuring of the channel, written in response to channel bans on 2026-11-08. It is not malware, but it is ToS-adjacent.

**Layer hopping — automation, ToS gray:**
- `Layer.lua` infers your layer from NPC GUIDs.
- `Hop.lua` asks another VoidSweep user to invite you (`:170`). It then **auto-accepts that invite and hides the popup** (`Hop.lua:284-288`), checks whether your layer changed, and **auto-leaves the party** (`:64`).
- As host (opt-in, `/vsw host`), it **auto-invites strangers** (`Hop.lua:238`).
- Rare popups offer hops (`Hop.lua:305-320`). Layer-abuse for rares has been actioned in Classic before.

**Read-only parts (fine):** vignette scanner, nameplate/target rare detection, learned spots, the delve spawn heat map, and portal-aware waypoint routing.

**Overlap:** RareWatch (direct), Landmarks (waypoints).

## 5. Features worth rebuilding (read-only, UI-only, no Blizzard frame hooks)

Ranked by value for this user. Each describes the approach, not their code.

1. **Rare tracker by sighting** (VoidSweep `Sightings.lua`). Poll or listen to `NAME_PLATE_UNIT_ADDED`, `PLAYER_TARGET_CHANGED` and `UPDATE_MOUSEOVER_UNIT`. Check `UnitClassification(unit)` for "rare"/"rareelite", read the NPC ID from the 6th field of `UnitGUID`, and listen for its death via `UNIT_HEALTH` or `UnitIsDead`. Store "seen up at t / killed at t" per NPC and show it in your own window plus your own map pins, with a static seed table of spawn coords. Keep it local, with no network. This upgrades **RareWatch**.
2. **Layer indicator** (VoidSweep `Layer.lua`). Parse `Creature-0-<server>-<map>-<shard>-<npcID>-…` from nameplate, target and mouseover GUIDs. Take the most common `<server>-<shard>` pair among nearby NPCs as "your layer", skipping player pets. Reset on `ZONE_CHANGED_NEW_AREA` or `GROUP_ROSTER_UPDATE`. Show it as a small label in ForeverHub. Display only; no hopping.
3. **Read-only trainer preview** (VeritasUI `Trainer.lua`). On `TRAINER_SHOW`/`TRAINER_UPDATE`, copy `GetNumTrainerServices`/`GetTrainerServiceInfo` (name, type, reqLevel, rank text), `GetTrainerServiceCost` and the ability requirements into SavedVariables. Later, a minimap-adjacent button or ForeverHub panel lists "learnable now / coming at level N" and the total cost, with no Train buttons. This upgrades **TrainerNotes** and **TalentNudge**.
4. **Dungeon entrances and travel pins on the world map** (QoL `MapPins.lua`). A static table of dungeon entrances, boats, zeppelins, portals and the tram per uiMapID, drawn by your own `MapCanvas` data provider (`WorldMapFrame:AddDataProvider` with your own pin template). Hover shows the destination; clicking calls `SetMapID` to the destination map. This fits **Landmarks**/**ZoneLevels**.
5. **Zone-filtered quest view** (VeritasUI `ZoneQuests`). Use `C_Map.GetBestMapForUnit("player")` plus `C_QuestLog.GetQuestsOnMap` and `GetInfo` to split your log into "this zone" and "elsewhere". Display it in **QuestTracker**'s own frame rather than adding or removing Blizzard quest watches.
6. **Tooltip IDs and vendor sell price** (QoL `Tooltips.lua`). Use `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item/Unit/Spell, fn)` to append the item ID, NPC ID (from the GUID) or spell ID, and `select(11, C_Item.GetItemInfo(id))` × stack for the sell price. This is an additive post-call, the sanctioned extension point, not a frame hook. It can also show your **PriceMemory** price.
7. **Delve/area spawn heat map, adapted as a "where I found X" heat map** (VoidSweep `Spawns.lua`). Record (map, x, y) on loot or gather events, cluster into grid cells, and count once per visit. Pin brightness = hits/visits ("here 7 of 10 visits"). Useful for gathering nodes or chest spots in your own map overlay.
8. **Portal-aware waypoint router** (VoidSweep `Route.lua`). A table of permanent portals and boats between continents (instance maps) and a breadth-first search over "worlds". If the target is on another continent, pin the first portal with `C_Map.SetUserWaypoint`, then advance on `ZONE_CHANGED_NEW_AREA`. Clear the pin when within N yards using `C_Map.GetPlayerMapPosition`. Good for **Landmarks** and **LevelGuide**'s arrow.
9. **Upgrade check report, without auto-equip** (VeritasUI `AutoEquip.lua` decision logic, RXP `ItemUpgrades.lua` weights). For each bag item: `C_Item.IsEquippableItem`; red tooltip lines via `C_TooltipInfo.GetBagItem` mean unusable; compare item level and stats (`C_Item.GetItemStats`) against the worn slot (`GetInventoryItemLink`); treat a heavier armor type as better; show the main stat by class. Output is a badge or list only. This sharpens **ItemAdvisor**.
10. **Mail bookmarks / alt registry** (QoL `MailBookmarks.lua`). Record each character's name and class on `PLAYER_LOGIN` into account-wide SavedVariables. Show them as a list in your own window to copy the name. If you skip writing into Blizzard's To box, it stays fully read-only. Feeds **ItemFinder**/**GoldGoal**.

## Bottom line
- **Safe:** Auctionator, Plater.
- **Automation by settings** (well-known): RXPGuides.
- **Automation, some on by default:** QoL (sell junk), VeritasUI_QualityOfLife (sell junk, repair, accept res).
- **Casts for you:** VeritasUI_PriorityRotation.
- **UI-only but taint-heavy:** VeritasUI_Interface, ZoneQuests, AdvancedOptions, AuctionHouse, Lib.
- **Cosmetic automation, likely not loading:** AutoCompanion.
- **Risk:** VoidSweep (default-on location sharing with strangers, a channel built to dodge bans, and auto invite/accept/leave layer hopping).
- **No malware indicators** in any folder.
