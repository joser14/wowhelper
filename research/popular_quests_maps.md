# Popular quest and map addons for WoW: Forever (interface 16001) - malware check and read-only review

Date: 2026-11-09. Scope: Questie, Forever Quest Pins, Forever Quest Tint, Zone Info: Forever, HandyNotes +
HandyNotes: WoW Forever, TomTom. Compared against our LevelGuide, QuestTracker, QuestCheck, ZoneLevels, Landmarks.

Rules followed: downloads only into the session scratchpad (`scratchpad\downloads\<Addon>`), nothing installed or run,
malware check before reading code, findings in own words, no code or data copied.

## Downloads

All under `C:\Users\you\AppData\Local\Temp\claude\cb2f3a55e03b1ab7\c31d37c7-e117-4d9f-bde3-ec6d36fbc336\scratchpad\downloads\`.

| Folder | Source (linked from CurseForge page) | Method | Size on disk | Version / commit |
|---|---|---|---|---|
| Questie | https://github.com/Questie/Questie | git clone --depth 1 | 1557 files, 171.0 MB (incl. .git) | 26111d1, 2026-11-09 (v12.6.4, `Questie_Forever.toc` = Interface 16001) |
| QuestieDB | https://github.com/Questie/QuestieDB (Questie's OptionalDep, separate addon) | git clone --depth 1 | 673 files, 417.7 MB | c1b50fe, 2026-11-08 (v1.0.13 source mode) |
| ForeverQuestPins | https://github.com/TylerAkins/forever-quest-markers | git clone --depth 1 | 95 files, 2.2 MB | 4bec28e, 2026-11-08 (v0.4.2) |
| ForeverQuestTint | https://github.com/alexdia25/forever-quest-tint | git clone --depth 1 | 61 files, 5.6 MB | c8883cd, 2026-11-09 (0.7.3) |
| ZoneInfoForever | no repo; CurseForge file 9497936 -> `ZoneInfoForever-1.10.0.zip` (mediafilez.forgecdn.net/files/9497/936/) | zip + Expand-Archive | 56,321 bytes zip, 6 entries | 1.10.0, 2026-11-07 |
| HandyNotes | https://repos.curseforge.com/wow/handynotes (CurseForge "Source") | git clone --depth 1 | 69 files, 118 KB | 438a547, 2026-10-02 "Update for Forever" |
| HandyNotes_WoWForever | https://github.com/kemayo/wow-handynotes-forever (issues link on CF page) | git clone --depth 1 | 44 files, 47 KB | 05cf4e4, 2026-10-04 (v3-forever) |
| HandyNotes_handler | https://github.com/kemayo/wow-handynotes-handler (the plugin's git submodule `handler`) | git clone --depth 1 | 58 files, 387 KB | cc70e83, 2026-10-18 |
| TomTom | CurseForge file 9493883 -> `TomTom-v4.4.1-release.zip` (mediafilez.forgecdn.net/files/9493/883/) | zip + Expand-Archive | 11,790,690 bytes zip, 120 entries | v4.4.1, 2026-11-07, Forever flavor |
| TomTom_cfrepo_2021 | https://repos.curseforge.com/wow/tomtom (CF "Source" link) | git clone --depth 1 | 125 files, 7.2 MB | bc7ab3a, **2021-06-29** - stale, not used; the release zip was reviewed instead |

Zip entries were listed before extraction; no absolute or `..` paths.

## Malware check (done before reading any code)

Method: every file grouped by extension; unexpected extensions listed; first bytes of every file checked for MZ, PK,
7z, ELF, `#!`, RAR, gzip, Lua bytecode; Lua/XML/TOC grepped for loadstring/load, RunScript, string.char chains,
base64/hex/decimal-escape blobs, setfenv/getfenv, URLs, addon/chat message sends, and protected or CVar-writing calls.

| Addon | Verdict | Notes |
|---|---|---|
| Questie | **Clean** (dev binaries removed) | Runtime: Lua/XML/TOC + images only. Flagged dev-only items in `ExternalScripts(DONOTINCLUDEINRELEASE)\`: `BLPNG Converter.exe` (MZ, unsigned, 1,045,504 B, SHA-256 4E62068C...5F46) and `DBCDumper\out\DBC-dump-UnpackMe.7z` (70 MB, SHA-256 2B0B024F...23F0). Both are excluded from releases by folder name; neither is referenced by the TOC. Not run; **deleted** from the download as a precaution. Build/CI: build.py, changelog.py, upload-cf.sh, upload-wago.sh, validate-bundle.sh, .dockerfiles, 7 GitHub workflows, `cli\` Lua test harness (uses loadstring/setfenv to load files in tests) - normal. `loadstring` in runtime code only on the zone DB's own committed string data. Network: only AceComm addon messages (party quest sharing) and a version check; no URLs used at runtime. SetCVar: `instantQuestText` (option), `calendarShowDarkmoon` (holiday detection). `docs\wow-frame-dragging.md` is written *for* AI agents (not a ban). |
| QuestieDB | **Clean** (dev binaries removed) | Runtime: Lua data + loader. Flagged: `tools\lua-binary\lua.exe` (MZ, unsigned) and `tools\lua-binary\linux-x64\lua` (ELF); hashes match the repo's own SHA256SUMS; used by the generator scripts. Not run; **deleted**. 43 Python tools, generate.sh/.cmd, questiedb.ps1 - build tooling, not run. `loadstring` is used by design: data and locale files are committed Lua table text wrapped in long strings and compiled lazily on first read (a load-time/memory technique, not obfuscation). Long "hex" hits are a CBOR test fixture and a padded probe TOC. No runtime network. |
| ForeverQuestPins | **Clean** | 15 Lua, 1 XML, 4 TGA. Go tooling (cmd/fqp, internal/*) builds the DB from QuestieDB and checks the Battle.net version endpoint - dev only, not run. GitHub workflow pulls QuestieDB preview releases. Lua writes one CVar (`showInGameNavigation`, user option) and registers its own CVar holding a plain `key=value;` backup of its settings (see findings). Builds a Wowhead URL string for a copy box only; no network. No addon messages. |
| ForeverQuestTint | **Clean** | 4 Lua + TOCs + TGA. `logo\*.py` image generators and `.webp` screenshots - not run. `tests\harness.lua` defines its own load helper. Nothing network-related. |
| ZoneInfoForever | **Clean** | 2 Lua, 1 TOC, 1 TGA, 1 MD. No hits at all. |
| HandyNotes | **Clean** | 11 Lua, 1 XML, packager/luacheck config, CI yml. Only URLs are XML schema and locale comments. |
| HandyNotes_WoWForever + handler | **Clean** | 6 Lua (data) + 26 Lua handler; `bin\updateHandler.sh` dev script, not run. No network. |
| TomTom 4.4.1 | **Clean** | 52 Lua, 5 XML, TGA/BLP/MP3, `Images\Arrow.m2` (a 3D model asset for the arrow; not an executable format, no MZ/PK/ELF header). `modules\comm.lua` sends addon messages to party/raid/guild to share waypoints (user action). |

No addon contains a note asking AI tools not to use it.

---

## Zone Info: Forever 1.10.0 (Vaniron)

**Features.** Hovering a zone on the world map adds, under the map's own zone-name label: a faction shield (Alliance,
Horde, contested, sanctuary), the level range colored by your level, minimum fishing skill, dungeons and raids with
their level brackets (Forever instances included), transport links (boats, zeppelins, tram, Forever's sky boats), and
optional herb and ore lists colored by your gathering skill. Options: a separate movable window docked to the map
instead of the label, a "current zone" panel near the minimap, hide in combat, per-line font size and color, Addon
Compartment entry, `/zif`, Settings panel, welcome window.

**How it works.**
- Data: one hand-written table keyed by uiMapID with min/max level, fishing, dungeon list (AreaTable IDs so names
  come from `C_Map.GetAreaInfo` in the client's language), transport text, faction, herb and ore item IDs. Forever
  zones are entries for Mount Hyjal (2482), Zephras Isle (2521), Riverglades (2548) and Shen'dralas (2652). Levels
  are not read from `C_Map.GetMapLevels`; the author keeps them by hand.
- Hover: it finds the world map's area-label data provider by walking `WorldMapFrame.dataProviders` for the one
  with a `Label`, then post-hooks that label's OnUpdate (and re-hooks if anything calls SetScript on it). On each
  tick it reads `map:GetNormalizedCursorPosition()` and `C_Map.GetMapInfoAtPosition`, throttled to 20 Hz and skipped
  when the cursor and map haven't changed.
- It creates its own font strings **on Blizzard's label frame**, and its separate window and map button are
  children of `WorldMapFrame` / its ScrollContainer.
- Skill colors: `C_SkillInfo.GetSkillLineInfoByID` / `C_TradeSkillUI.GetProfessionInfoBySkillLineID`; item names
  load lazily with `C_Item.RequestLoadItemDataByID` + ITEM_DATA_LOAD_RESULT.

**Writes into Blizzard frames:** yes - hook on the area label's OnUpdate and SetScript, extra font strings parented
to the label, own frames parented to WorldMapFrame.

**Midnight-client notes.** No secret-value handling at all (the values it reads are map metadata, not combat data).
Uses Addon Compartment TOC fields.

**Versus ours.**
- ZoneLevels only checks the zone you enter and only via `C_Map.GetMapLevels` (`ZoneLevels\ZoneLevels.lua:20-28`);
  if Forever returns no range for a zone (the author's hand table suggests the API is not relied on), we say nothing.
  No dungeon, fishing, transport or faction info; output only goes to the hub (`ZoneLevels.lua:13-18`).
- We have no world-map hover info at all.

**Ideas for us (read-only, own frames).**
1. (S) ZoneLevels fallback table: own uiMapID -> level range, dungeons, fishing minimum, for zones where
   `GetMapLevels` is empty; include the four Forever zones. Data from our own research (wowhead Forever / in-game).
2. (M) "Map companion" window: our own frame anchored *next to* the world map (SetPoint relative to it is reading
   its position, not changing it) that polls `WorldMapFrame:IsShown()` and `WorldMapFrame:GetMapID()` every 0.2 s and
   shows the displayed zone's info. For hover-level detail it may read `WorldMapFrame:GetNormalizedCursorPosition()`
   + `C_Map.GetMapInfoAtPosition` from our own OnUpdate - no hooks.

---

## Forever Quest Tint 0.7.3 (xanastar)

**Features.** Marks quests that were not in original Classic: teal gradient over the quest window parchment, an
infinity-sign marker before quest names in the log and Blizzard's tracker, optional Forever logo, recolored objective
lines, and a teal gradient over the yellow `!`/`?` map icons (Questie's and the game's own). Skins for DialogueUI,
Immersion, Storyline, Lorewalker, ClassicUI Forever, EllesmereUI. `/fqt`, preview mode.

**How it works.**
- "New to Forever" = quest ID **not** in a bundled sorted list of vanilla ID ranges (generated from Questie's Classic
  DB); lookup is a binary search over ranges, so no per-ID table. False positives possible (a vanilla quest missing
  from Questie's Classic data shows as new).
- Quest window: events QUEST_DETAIL/PROGRESS/COMPLETE/GREETING and HookScript on QuestFrame; overlays textures on the
  parchment regions. Log: hooks QuestMapFrame details. Tracker: scans region text and hooks `SetText` on tracker
  font strings to add the marker. Map icons: walks `WorldMapFrame:EnumeratePinsByTemplate` for the native
  `QuestOfferPinTemplate` (the `QuestNormal` atlas `!`) and `QuestPinTemplate`, hooks each pooled pin's OnAcquired,
  and lays a desaturated, vertex-colored copy of the atlas over it. For Questie it hooks Questie's internal
  `QuestieFrame` pool (`CreateIconFrame`) and each icon texture's SetVertexColor.

**Forever-specific finds.** Forever's world map has native quest-giver pins (`QuestOfferPinTemplate`) and quest
POI pins, so the game itself shows `!` offers (consistent with our C_QuestLine reads). Forever-new quest IDs are
mostly high (98xxx, e.g. 98189-98240 seen in our routes research).

**Writes into Blizzard frames:** almost everything it does - overlays on QuestFrame, QuestMapFrame, the tracker and
native map pins, plus many hooksecurefunc/HookScript.

**Versus ours.** QuestTracker and LevelGuide don't distinguish Forever-new quests at all (title/level only, e.g.
`QuestTracker\QuestTracker.lua:737-750` QuestRowText; `LevelGuide\LevelGuide.lua:1276` StepLine).

**Ideas for us.**
3. (S) "New in Forever" tag in our own tracker rows, LevelGuide step lines and our quest tooltips. Build our *own*
   vanilla-ID range list from QuestieDB's Classic quest IDs with a small script (facts, generated by us, with
   attribution), not their file; same binary-search-over-ranges idea.

---

## Forever Quest Pins 0.4.2 (Tyler Akins)

**Features.** Colored `!` markers on the world map for quests you can pick up (yellow normal, blue repeatable,
red-orange dungeon/raid incl. attunements, class-colored, copper for profession), stacked when they overlap, size
50-150 %, tooltips with level/name/giver, click to set a waypoint (Blizzard user waypoint by default or TomTom),
Shift-click to hide a pin per character, filters (low-level, repeatable, seasonal, AQ war effort), NPC unit
tooltips listing what that NPC starts or takes back, "Copy Wowhead URL" in the tracker's right-click menu,
optional auto-accept/turn-in, optional hide-tracker-in-combat, toggling Forever's native navigation marker.

**How it works.**
- Data: `Database\ForeverQuests.lua` (1 MB, generated by their Go tool from the QuestieDB Forever "preview" release,
  pinned by SHA-256 in `Metadata.lua`) - per quest: start map/x/y (0-100), giver NPC/object IDs, turn-in IDs,
  races/classes, skill, prerequisites split into AND list and OR list, flags; a `ByMap` index for drawing. A
  separate static instance-tag correction table backs up `C_QuestLog.GetQuestTagInfo`.
- Eligibility (`Eligibility.lua`): completed set = `GetQuestsCompleted()` + `C_QuestLog.GetAllCompletedQuestIDs()`
  merged once, treated as authoritative when loaded; per-ID `IsQuestFlaggedCompleted` only as fallback. Session
  overrides on QUEST_ACCEPTED / QUEST_TURNED_IN / QUEST_REMOVED because Forever's APIs lag behind those events.
  Race/class/faction/skill/holiday checks; unknown restriction keeps the pin ("conservative").
- Levels for quests you don't have: `C_QuestLog.GetQuestDifficultyLevel(questID)` works for unaccepted IDs on
  Forever; `C_QuestLog.RequestLoadQuestByID` + QUEST_DATA_LOAD_RESULT to fetch titles.
- Gossip learning: on GOSSIP_SHOW/QUEST_DETAIL it takes the NPC ID from `UnitGUID("npc")` (skipped if
  `issecretvalue`), your map position, and any offered quest IDs; quests missing a start coordinate get the
  position where you were offered them, and new starters are added to the NPC tooltip index.
- Pins: outside gamepad mode it takes pins from the world map's own pin pool with
  `WorldMapFrame:AcquirePin(<own template>)` (template mixes in `MapCanvasPinMixin`, frame level type
  `PIN_FRAME_LEVEL_AREA_POI`, fixed scale); in gamepad mode it uses plain Buttons parented to the map canvas and
  positions them itself. It overrides `GetCenter` on its own pins so Forever's native gamepad cursor doesn't scan
  them (that scan otherwise tainted a protected call on map close). It watches the map with
  `hooksecurefunc(WorldMapFrame, "Show"/"Hide"/"OnMapChanged"/"OnCanvasScaleChanged"/"SynchronizeDisplayState")`
  and an own OnUpdate for size changes - explicitly avoiding HookScript on WorldMapFrame.
- Waypoints (`Waypoints.lua`): `UiMapPoint.CreateFromCoordinates` + `C_Map.SetUserWaypoint` +
  `C_SuperTrack.SetSuperTrackedUserWaypoint`; after accepting it hands over with
  `C_SuperTrack.SetSuperTrackedQuestID`. TomTom gets `C_QuestLog.GetNextWaypoint` points. It only clears a Blizzard
  pin it set itself (compares the current user waypoint first).
- Forever's floating 3D navigation marker = CVar `showInGameNavigation` (user verified); their checkbox reads and
  writes it.
- NPC tooltips: GameTooltip HookScript OnTooltipSetUnit / hooksecurefunc SetUnit (we'd use TooltipDataProcessor).
- Settings robustness: settings kept in account SV, a per-character copy, legacy stores **and** a self-registered
  CVar (`C_CVar.RegisterCVar`) holding a `key=value;` string, each with a revision number; on load the newest wins.
  Reason given in code: Forever can drop SavedVariables (per-character ones especially). Hidden pins are stored in the
  account SV keyed by Name-Realm for the same reason.

**Forever-specific.** Object-started prerequisite quests (example in their comments: the Ravaged Caravan crate, 751,
gating 764/765) often never flag completed via `IsQuestFlaggedCompleted`; they treat such a source as satisfied
when it isn't in the log and its own prerequisites are met. QUEST_ACCEPTED arg order differs between clients (index,
id) vs (id) - they take whichever is a positive number. Some events aren't on every Forever build - registered in
pcall.

**Writes into Blizzard frames:** pins acquired from / parented to the world map canvas; hooksecurefunc on
WorldMapFrame methods, the tracker's header enter/leave and GameTooltip; Blizzard menu entry; CVar writes.

**Versus ours.**
- LevelGuide's prerequisite and turned-in checks use only `C_QuestLog.IsQuestFlaggedCompleted` per ID
  (`LevelGuide\LevelGuide.lua:441-449`, `504-518`): misses object-started quests and lags right after turn-in.
- Offers are recorded per NPC *name* and quest *title* (`LevelGuide.lua:657-696`, key from `NpcKey` at `56-58`),
  session-only; FQP keys by NPC ID from GUID and quest ID, and remembers where.
- Quest-start knowledge comes only from the game's `C_QuestLine.GetAvailableQuestLines`
  (`LevelGuide.lua:266-284`, `QuestTracker\QuestTracker.lua:346-388`) plus our hand routes; nothing for starts
  outside the current map, no level for unaccepted quests.
- Waypoint: we always overwrite the user's Blizzard pin (`LevelGuide.lua:1296-1313`, `QuestTracker.lua:390-398`,
  `Landmarks\Landmarks.lua:169-185`) without checking whether it's ours. Landmarks checks `CanSetUserWaypointOnMap`
  (good), the other two don't.

**Ideas for us.**
4. (S) One shared "is completed" helper: union of `GetQuestsCompleted()` and `C_QuestLog.GetAllCompletedQuestIDs()`
   cached, invalidated on QUEST_TURNED_IN, plus a session set filled from QUEST_TURNED_IN/QUEST_ACCEPTED, then
   `IsQuestFlaggedCompleted`. Use in LevelGuide `TurnedIn`/`QuestDone`.
5. (S) Waypoint etiquette: remember the UiMapPoint we set; only replace/clear the user's pin if the current
   `C_Map.GetUserWaypoint()` is ours or empty, else ask (button) first; check `C_Map.CanSetUserWaypointOnMap` in
   LevelGuide/QuestTracker too.
6. (S) Show quest level for unaccepted offers via `C_QuestLog.GetQuestDifficultyLevel` in QuestTracker's "Quests
   nearby" and LevelGuide pick-up steps, colored by difficulty.
7. (M) Key LevelGuide offer memory by NPC ID (`UnitGUID("npc")`, guarded with `issecretvalue`) and quest ID; save
   it (account SV, per character key) with the map position where seen.
8. (M) Forever's native 3D navigation marker: our MarkStep already super-tracks; a settings checkbox that reads
   (and, only on the user's click, writes) `showInGameNavigation` would surface it. Writing a CVar is a setting change,
   so only on explicit click.
9. (M) Settings resilience: a revision counter in our SVs; consider the CVar-mirror trick only for a few critical
   booleans (it is persistent config, so opt-in).
