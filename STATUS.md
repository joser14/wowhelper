# Forever addon suite: status (2026-11-09)

Start here when resuming.

## Installed
- Installed 2026-11-09 as six addons: !ForeverHub, ForeverGuides, ForeverQuests, ForeverBags, ForeverCharacter, ForeverWorld.
  Latest install includes the taint fix (MapPins overlay frames, SlashCmdList rewrite removed, combat-safe Options/CVar/tracker alpha).
- Backups from the first install: old per-helper folders in `_forever_\Interface\AddOns_ForeverBackup_20261109_083113`,
  full WTF copy in `_forever_\WTF_Backup_20261109`. VoidSweep and VeritasUI_PriorityRotation were moved (user approved) to
  `_forever_\Interface\AddOns_Removed_20261109`.
- Roll back: close WoW, delete the six bundle folders, move the backup folders back.
- Tests: all 41 pass (`tests\runall.ps1`, after `npm install` in tests). Old tests that checked for chat output and
  replaced window layouts, and one-off data-migration scripts, were removed on 2026-11-09 (see git history).

## Rules the suite follows
- Line in the sand: nothing that breaks Blizzard's ToS (no automation: no auto sell/buy/accept/turn-in/equip/train/cast) and nothing that causes taint errors.
- NEVER use the world-map canvas pin pool (WorldMapFrame:AddDataProvider / AcquirePin): it caused "ForeverWorld has been blocked from an action" (UNKNOWN()) in game on 2026-11-09. MapPins draws its own overlay frames.
- Never assign Blizzard globals or tables (e.g. `SlashCmdList = SlashCmdList or {}`); only add our own keys. See research/taint_audit.md.
- Fine: tooltip lines (TooltipDataProcessor), our frames on the minimap, our own badges anchored over Blizzard buttons, Settings panel (registered out of combat), addon compartment, keybindings, cosmetic alpha on Blizzard's quest tracker.
- Never replace/hook/rewrite Blizzard functions, never call protected functions.
- UI in our own windows (ForeverHub pages, side panel, pop-ups). No chat output.
- Third-party code: download only into a quarantine folder after a malware check, never run or install it; describe reverse-engineering in our own words, copy no code.
- Forever uses Classic-era uiMapIDs (Teldrassil 1438, Darnassus 1457, Elwynn 1429, Stormwind 1453). Resolve maps by name where possible.
- Forever's combat log is closed to addons; many values are secret in combat/instances: Safe() everything.

## Layout
- One folder per helper (source + .toc). `tests/` = Node + fengari harness. `research/` = research reports and build data
  (`research/builds/gen_data.js` regenerates `Builds/Data.lua` from `research/builds/<CLASS>.lua`).
- `build.ps1` assembles the six addons into `dist/`; `.\build.ps1 -Install` (WoW closed) also installs them, moving any
  old per-helper folders to a dated backup and carrying their saved data over once.

## In-game checks still needed
- Fight with the world map open and closed: no "blocked from an action" pop-up, no new Blocked action line on the Errors page.
- Map pins line up when the map is zoomed, panned, windowed and maximised; hover and click work; gamepad mode has no errors.
- /reload in combat, leave combat: Forever Hub page appears in Options.
- QuestTracker quest-item button in combat: click, fold, drag. QuestMobs markers on nameplates in combat.
- /reload: no Lua errors, hub opens on Home, Manage switches work.
- Minimap pin direction with minimap rotation on and off.
- PriceMemory: same item on Alliance and Horde AH; if identical, drop faction from ScopeKey().
- Flight points known count matches the flight map; repair cost shows away from a vendor.
- Dungeons: approximate entrances (SM, ST, Scholo, Strat, Ruins of Lordaeron, RFD, Maraudon).
- LevelGuide: arrow and steps in Teldrassil/Darkshore; skips survive /reload; GetBindLocation names; Caylais/Shaussiy coords approx.

## Follow-ups
- Re-run the builds research after Blizzard's 2026-11-10 class tuning.
- Tooltips: quest giver "Turn in" lines for quests you don't hold are noisy at busy NPCs; consider showing only held turn-ins.

## Research reports (research/)
taint_audit.md, builds_forever.md, builds/, gaps_filled.md, curseforge_forever.md, thirdparty.md, thirdparty_features.md,
rxp_deep.md, auctionator_deep.md, popular_quests_maps.md, popular_items_spells.md, popular_qol_routes.md, routes.md,
landmarks.md, levelguide_questtracker.md, itemadvisor_hub_helper.md, small_addons.md, BRIEF.md (brief for review workers).
