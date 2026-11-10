# Forever addon suite: status (2026-11-09)

Start here when resuming.

## Installed
- Installed 2026-11-09 as six addons: !ForeverHub, ForeverGuides, ForeverQuests, ForeverBags, ForeverCharacter, ForeverWorld.
  Latest install includes the taint fix (MapPins overlay frames, SlashCmdList rewrite removed, combat-safe Options/CVar/tracker alpha).
- Backups from the first install: old per-helper folders in `_forever_\Interface\AddOns_ForeverBackup_20261109_083113`,
  full WTF copy in `_forever_\WTF_Backup_20261109`. VoidSweep and VeritasUI_PriorityRotation were moved (user approved) to
  `_forever_\Interface\AddOns_Removed_20261109`.
- Roll back: close WoW, delete the six bundle folders, move the backup folders back.
- Tests: all pass (`tests\runall.ps1`, after `npm install` in tests). Old tests that checked for chat output and
  replaced window layouts, and one-off data-migration scripts, were removed on 2026-11-09 (see git history).
- 2026-11-09, later:
  - LevelGuide routes and the zone plan are Alliance only (`LevelGuideRoutes.faction`). Before this, Horde
    characters and Skyborne were sent to Teldrassil, Dun Morogh or Elwynn.
  - Skyborne now get a Zephras Isle plan entry for 1-13, the zeppelin way to Westfall, and the Human chain after
    that (`tests\test_lg_faction.lua`).
  - RestGuard no longer errors when the hearthstone cooldown API is missing.
  - RestedXP v4.11.35 was re-checked. The correction to the Skyborne exit is in `research\rxp_forever_guides.md` 6.1.

- 2026-11-10: full review of every helper (`research\review_2026-11-10.md`). 19 bugs were fixed, with new or
  extended tests:
  - `test_itemadvisor_spellpower.lua`, `test_hub_xp.lua`, `test_tooltips.lua`, `test_rarewatch.lua`,
    `test_landmarks.lua`.
  - The comparison with other addons is in `research\compare_2026-11-10.md`, with a ranked "build next" list.

- 2026-11-10, later:
  - Second review round fixed 12 more bugs in Builds, ReadyCheck, ProfessionGuide, GoldGuide and Dungeons.
  - New features, each with a test:
    - quest givers on the map (`LevelGuide_QuestGivers` plus a MapPins "givers" layer; `test_lg_givers.lua`,
      `test_mappins.lua`);
    - drowning/fatigue warning (`DeathNotes\BreathWatch.lua`, `test_breathwatch.lua`);
    - XP from quests vs kills (LevelLog, `test_levellog_xp.lua`);
    - flight times (Landmarks, `test_flighttimes.lua`);
    - `/way` (`MapPins\Way.lua`, `test_way.lua`).
  - **LevelGuide.lua is at Lua's 200-local limit in its main chunk.** New code there must go in a `do` block and
    keep its state in one table, as `LevelGuide_QuestGivers` does.
  - `research\builds\gen_data.js` can't run: it reads `research\builds\data_header.lua`, which was never
    committed. `Builds\Data.lua` was edited by hand to match `research\builds\WARLOCK.lua`.

- 2026-11-10, evening:
  - LevelGuide review: 12 fixes (`research\review_2026-11-10.md` third round).
  - Forever research: 22 more addons studied, 21 Forever facts and 25 ranked improvements
    (`research\forever_improvements_2026-11-10.md`). Built from it:
    - a Classic-preset notice (QuestCheck);
    - a profession fallback by skill line (ProfessionCap, ProfessionGuide, GoldGuide, ItemAdvisor);
    - Waylaid Crates never sold (ItemAdvisor);
    - Riverglades 2548 and Zephras Isle 2521 map IDs (Dungeons, MapPins);
    - the error-cap warning (ErrorLog).
  - Next from that list: an XP boosters block (camp, sleeping bag, XP food), Legacy challenges and perks, vendor
    price from the tooltip, spirit-healer arrow and dungeon entrances from the client, server checks of route
    quests, library books.

- 2026-11-10, night: LevelGuide engine, items 2-6 and 8-10 of `research\guides_deep_re.md` section 12, one
  commit and one `tests\test_lg_*.lua` each:
  - placement from the quest log (anchor = last real progress; holding a quest isn't progress) — `test_lg_place`;
  - the giver's window decides availability ("not offered at level L", saved, with clearing rules) — `test_lg_offers`;
  - XP model ported from Polestar (`LevelGuide\Planner.lua`, GPL-3.0-only, NOTICE.md), "Route ends at about
    level X", "+N XP waiting", "Hard (level Q)" tag, XP per second in ordering — `test_lg_xp`. Quest XP data:
    `LevelGuide\QuestXP.lua` from `tools\gen_questxp.js`;
  - "While you're here" lines (20 s detour budget, 180 yd work, dismiss) — `test_lg_here`;
  - arrow damping, ETA, per-kind arrival with hysteresis, no target flip-flop — `test_lg_arrow`;
  - spawn-camp arrow for work steps (circuit, 7 s dwell) — `test_lg_camps`;
  - slow scan of server quest levels — `test_lg_levels`;
  - lost-quest card (go back / skip with follow-ups) and fitting quests taken off the route — `test_lg_lost`.
  - Not built: item 7 (travel planner). It needs our own taxi/boat/crossing table; Polestar's TravelData and
    walking data were not copied.

## Rules the suite follows
- Line in the sand: nothing that breaks Blizzard's ToS (no automation: no auto sell/buy/equip/train/cast) and nothing that causes taint errors.
  Exception asked for by the owner (2026-11-09): AutoQuest accepts and turns in quests, only in a quest window the player opened
  (Shift pauses; never with several rewards, gold, combat, player-shared quests). No other helper may call AcceptQuest/CompleteQuest/GetQuestReward.
- NEVER use the world-map canvas pin pool (WorldMapFrame:AddDataProvider / AcquirePin): it caused "ForeverWorld has been blocked from an action" (UNKNOWN()) in game on 2026-11-09. MapPins draws its own overlay frames.
- NEVER register COMBAT_LOG_EVENT_UNFILTERED or other CallbackEvent events, even in pcall: ADDON_ACTION_FORBIDDEN pop-up. DeathNotes did this on every load; that was the real cause of the ForeverWorld pop-up (removed 2026-11-09, evening). The killer is now taken from your hostile target.
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
- After the 2026-11-10 fixes:
  - ItemAdvisor in a dungeon should say it can't read worn gear rather than "fills an empty slot", if gear links
    are hidden there.
  - Three trainers on Craftsmen's Terrace should be three Landmarks entries.
  - MapPins switched off and on in the hub should bring minimap pins back at once.
- Forever facts to settle in game (from the research):
  - `/dump GetProfessionInfo`: if it's nil, the new skill-line fallback is what reads your professions.
  - Does `C_Item.GetItemInfo`'s vendor price match the tooltip's? If not, take it from the tooltip.
  - Does the Classic preset really hide quest markers (QuestCheck now says so once)?
- New features (2026-11-10), not yet seen in game:
  - Quest-giver "!" and "?" icons: check the atlases QuestNormal/QuestTurnin exist, else the gossip icons show.
  - Flight times: the flight map's node positions are on the continent map (GetTaxiMapID), and landing within
    0.02 of a node is recognised.
  - The drowning warning fires under water, with the sound.
  - `/way` doesn't clash with another addon's `/way` (TomTom); `/fway` always works.
  - LevelLog's quest XP comes from QUEST_TURNED_IN's xpReward.
- LevelGuide engine (2026-11-10, night), not yet seen in game:
  - Gossip and greeting windows: offered quest IDs read (C_GossipInfo questID; GetAvailableQuestInfo's 5th
    return, GetActiveQuestID), so "not offered" marks only land on quests really missing.
  - The server level scan (60 s after login): RequestLoadQuestByID / GetQuestDifficultyLevel work outside
    combat with no error; LevelGuideDB.serverLevels stays small.
  - The arrow's swing and ETA feel right at 20 Hz; camps from QuestDB line up with real spawns.
  - Abandon a route quest: the card appears under the guide; Skip it / undo with a header right-click.
  - "Route ends at about level X" is close to where a zone's route really leaves you.
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
- AutoQuest: gossip NPC with a finished and a new quest (C_GossipInfo.SelectActiveQuest/SelectAvailableQuest get the questID;
  if nothing happens the client wants the list position); old-style greeting NPC; reward with no choice (GetQuestReward
  with no argument); Shift pauses; a quest shared by a party member is not accepted; gray quests are skipped.

## Follow-ups
- Horde routes and plan: RestedXP's free Forever guides cover Horde 1-22 (Durotar, Mulgore, Tirisfal, Barrens,
  Silverpine) and could be a fact source, as the Alliance ones were.
- Skyborne 1-13 on Zephras Isle has no step-by-step route yet, only the plan. Check in game that the zeppelin spot
  (65.8, 83.4) and the map name "Zephras Isle" match.
- Re-run the builds research after Blizzard's 2026-11-10 class tuning.
- Tooltips: quest giver "Turn in" lines for quests you don't hold are noisy at busy NPCs; consider showing only held turn-ins.

## Research reports (research/)
taint_audit.md, builds_forever.md, builds/, gaps_filled.md, curseforge_forever.md, thirdparty.md, thirdparty_features.md,
rxp_deep.md, auctionator_deep.md, popular_quests_maps.md, popular_items_spells.md, popular_qol_routes.md, routes.md,
landmarks.md, levelguide_questtracker.md, itemadvisor_hub_helper.md, small_addons.md, BRIEF.md (brief for review workers).
