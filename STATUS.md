# Forever addon suite: status (2026-11-09)

Start here when resuming. Main branch = finished, tested work. Branch `wip-snapshot` = unfinished worker
edits at the moment this file was written (may not pass tests; review before merging anything from it).

## Rules the suite follows
- Line in the sand: nothing that breaks Blizzard's ToS (no automation: no auto sell/buy/accept/turn-in/equip/train/cast) and nothing that causes taint errors.
- Blizzard's official extension points are fine: tooltip lines (TooltipDataProcessor), world-map data providers and pins, our frames on the minimap, Settings panel, addon compartment, keybindings, our own badges anchored over Blizzard buttons, cosmetic alpha (QuestTracker makes Blizzard's tracker transparent).
- Never replace/hook/rewrite Blizzard functions, never write Blizzard tables, never call protected functions.
- UI in our own windows (ForeverHub pages, side panel, pop-ups). No chat output.
- Third-party code: may be downloaded only into a quarantine folder after a malware check, never run or installed; reverse-engineering is described in our own words, no code copied.
- Forever uses Classic-era uiMapIDs (Teldrassil 1438, Darnassus 1457, Elwynn 1429, Stormwind 1453). Resolve maps by name where possible.
- Forever's combat log is closed to addons; many values are secret in combat/instances: Safe() everything.

## Layout
- One folder per helper (source + .toc). `tests/` = Node + fengari harness (`node run.js "<repo root or file>" testX.lua`; needs `npm install fengari` in tests/). `research/` = all research reports.
- `build.ps1` assembles six installed addons into `dist/`: !ForeverHub, ForeverGuides, ForeverQuests, ForeverBags, ForeverCharacter, ForeverWorld.
  `.\build.ps1 -Install` (WoW closed) moves the old per-helper folders out of AddOns into a dated backup, merges each old helper's SavedVariables file into its bundle's file (only if the bundle file doesn't exist yet), and installs the six bundles.
- NOT INSTALLED YET: the game still has the older per-helper folders from before this session's work (plus Landmarks, DeathNotes installed early on). Nothing from this session has been tested in game.

## Done (on main, tests passing)
- DeathNotes (deaths, killer when readable, warns near old death spots), Landmarks (+ flight points known), RareWatch (sightings, layer estimate), ReadyCheck/SpellReady (old ranks on bars, missing buffs, reagents), Tooltips (vendor/AH price, counts, profession use, IDs), PriceMemory (14-day history, item/commodity listings, merchant prices, PriceMemory_Get), GoldGuide (76 farms, tips, bag value), Dungeons (35 incl. Forever's new ones), MapPins (world map + minimap pins), DurabilityWatch (repair cost anywhere).
- ForeverHub: Home + Manage pages, grouped foldable sidebar, per-helper and per-addon switches, XP warm-up, finished-quest XP, session survives /reload, Restart.
- LevelGuide: moves on / says needed level instead of going blank, cross-zone steps, missing turn-in.
- VoidSweep and VeritasUI_PriorityRotation moved out of AddOns to `_forever_\Interface\AddOns_Removed_20261109` (user approved).

## In progress when this was written (see wip-snapshot)
| Work | Folder(s) | Notes |
|---|---|---|
| Profession guide, 12 professions 1-300 | ProfessionGuide | told: Classic map IDs; skill-up chance formula |
| (done, on main) LevelGuide engine upgrades | LevelGuide | see commit; in-game checks: GetBindLocation names, taxi node states, Caylais/Shaussiy coords approx |
| Item/spell upgrades | ItemAdvisor, ReadyCheck, TrainerNotes, Dungeons | auto role from talents, leveling stamina bias, macros + readable bar names, spellbook check, boss kills |
| Tooltip extras | Tooltips | drops from boss, quest giver starts/turn-in, needed for quest |
| Window badges (new) | WindowBadges | best quest reward, vendor upgrades, trainer new/on-bars |
| Quest-mob markers (new) | QuestMobs | marker + progress next to quest mobs in the open world |
| Hub extras | ForeverHub | keybindings (Bindings.xml at bundle root â€” build.ps1 must copy it), addon-compartment entry (toc lines in build.ps1), Settings panel, taskbar flash/sound alerts, hearthstone button |

## Next steps after those land
1. Merge each finished worker's folder from wip (or redo from its brief), run its tests, commit.
2. Wire any new hub pages (WindowBadges "Window badges"/WINDOWBADGES, QuestMobs "Quest mobs"/QUESTMOBS) into ForeverHub TABS + HELPERS.
3. Update build.ps1 for Bindings.xml and AddonCompartment toc lines.
4. Fix character keys: eight helpers key saved data by first name + realm (ItemAdvisor, LevelLog, GoldGoal, ItemFinder, SupplyWatch, TrainerNotes, LevelGuide, ForeverHelper; Landmarks has CharacterKey()). Forever names are first + last, so use full name or GUID with a one-time migration.
5. Shared waypoint routine: clear our waypoint on arrival, never clear the player's own pin.
6. Run every test in tests/, then `.\build.ps1 -Install` with WoW closed, then in-game check list below.

## In-game checks needed
- /reload: no Lua errors (Errors page), hub opens on Home, sidebar groups, Manage switches.
- Map pins: open map in and out of combat, no "action blocked"; minimap pin direction with rotation on/off.
- PriceMemory: same item on Alliance and Horde AH â€” if identical, drop faction from ScopeKey().
- Flight points: "Flight points known" count matches the flight map.
- Repair cost shows away from a vendor.
- Dungeons: approximate entrances (SM, ST, Scholo, Strat, Ruins of Lordaeron, RFD, Maraudon).
- LevelGuide: arrow and steps in Teldrassil/Darkshore; skips survive /reload.

## Research reports (research/)
curseforge_forever.md, thirdparty.md, thirdparty_features.md, rxp_deep.md, auctionator_deep.md,
popular_quests_maps.md, popular_items_spells.md, popular_qol_routes.md, plus earlier review reports.

- Tooltips extras (drop, questitem, giver, upgrade) done. Follow-up: giver 'Turn in' lines for quests you don't hold are noisy at busy NPCs; consider showing only held turn-ins.

- WindowBadges done (merchant upgrades/known recipes, trainer New/On your bars, quest reward Best/Most gold). TODO: ItemAdvisor already marks quest rewards, so turn WindowBadges 'reward' and 'gold' off by default (WindowBadges.lua IsOn defaults, ~line 26) or remove ItemAdvisor's RewardMark. Hub page line was sent to the hub-extras worker.
- Still running at usage limit: ProfessionGuide, ItemAdvisor/ReadyCheck/TrainerNotes/Dungeons upgrades, hub extras (keybinds, addon menu, Settings, alerts, hearth button, Quest mobs + Window badges pages). Their latest edits are in wip-snapshot.
