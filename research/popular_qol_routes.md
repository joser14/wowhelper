# Popular QoL, routing and profession addons for WoW Forever: malware check and read-only review (group C)

Date: 2026-11-09. Addons: Leatrix Plus (Forever), Leatrix Maps, Shortest Path Forever, SkillUp Forever, ForeverPlus,
Tweaks Forever, OneForAll - Forever, Glowing Bars.

Method: download from the official source (repo linked on CurseForge, or the CurseForge/author file) into
`scratchpad\downloads\<Addon>`; malware check first (extension census, magic bytes, obfuscation, network use); then
read-only review. Everything below is in my own words; no code or data was copied into the suite.

Downloads log and per-addon findings are appended below as each addon is finished.

## Downloads and malware check

Root: `C:\Users\you\AppData\Local\Temp\claude\cb2f3a55e03b1ab7\c31d37c7-e117-4d9f-bde3-ec6d36fbc336\scratchpad\downloads\<Addon>`.
Git clones used `GIT_LFS_SKIP_SMUDGE=1`, hooks disabled, depth 1, no submodules. Zips from the CurseForge API download
link of the Forever file named on the project page. Nothing installed or executed.

| Addon | Source | File / commit | Size |
|---|---|---|---|
| Leatrix Plus | CurseForge file 9471872 (no public repo) | Leatrix_Plus-1.60.29-forever.zip, sha256 6358B721...6CC3 | 572,269 B |
| Leatrix Maps | CurseForge file 9467345 (no public repo) | Leatrix_Maps-1.60.28-forever.zip, sha256 C3225270...4B36 | 24,678,875 B |
| ForeverPlus | CurseForge file 9493145 (no repo; page links only donations) | ForeverPlus-1.0.7.zip, sha256 1B51118C...EF9 | 738,377 B |
| Shortest Path Forever | https://github.com/cjber/shortest-path-forever | e3a85fd (release 1.24.1, 2026-11-09) | 85.2 MB incl. .git |
| SkillUp Forever | https://github.com/cjber/skillup-forever | 2f67dedd (2026-11-09, page says v1.1.6) | 20.9 MB incl. .git |
| Tweaks Forever | https://github.com/cjber/tweaks-forever | 70c20a2 (2026-11-09, page says v2.4.2) | 31.6 MB incl. .git |
| OneForAll - Forever | https://github.com/smoergi/OneForAll_Forever | 96fd21c (6.2.1, 2026-11-08) | 68.9 MB incl. .git |
| Glowing Bars | https://github.com/vattiss/wowkit (monorepo) | 7f3ecab (release 2.8.2) | 5.5 MB incl. .git |

Checks: extension census; magic bytes of every file (MZ, PK, 7z, ELF, RAR, Mach-O, Lua bytecode, `#!`); Lua scan for
`loadstring/RunScript/setfenv/load(/string.dump`, escaped-byte strings, `string.char` chains, URLs, addon/chat messaging;
lines over 3,000 chars inspected.

Verdicts (all CLEAN, no folder deleted):
- **Leatrix Plus**: 8 Lua, 2 XML, 1 BLP. Only PK is the downloaded zip itself. URLs are Wowhead/armory links shown in
  copy boxes (user copies them). One `RunScript` with a fixed literal (opens Edit Mode). `SendChatMessage` only in
  user-triggered features (share map pin to a channel, a boss-orb callout). Long lines are NPC-ID lists. No obfuscation.
- **Leatrix Maps**: 5 Lua, 2 XML, 6 BLP (map overlay art, why the zip is 24 MB). Nothing flagged.
- **ForeverPlus**: 63 Lua, 1 TGA. Nothing flagged; `load(` hits are `Reload` names; URLs are comments and the project page.
- **Shortest Path / SkillUp / Tweaks** (same author, same layout): addon code is Lua listed in the TOC; `tools/` holds
  Python generators, shell scripts, a C++ test and TrinityCore patches used offline to bake nav data (dev only, not in
  the TOC, not run). `#!` hits are those scripts. Addon messaging only in `Core/PeerStats.lua` (opt-in leaderboard to
  guild/group). `loadstring` + empty `setfenv` sandbox is used to read QuestieDB's zone tables, which Questie stores as
  Lua source text: normal. Tweaks `tools/forever_tools/interface_paths.txt` is a zlib+base64 list of client file paths
  with a header saying so, used by a dev lint, not shipped in the TOC. Long lines in `Data/RoadEdges.lua` are numeric
  road graph data.
- **OneForAll**: 128 Lua, TGA/BLP art. Addon messages (guild recipe sharing, profile share by whisper, party dungeon
  quest share, version check), all wrapped in pcall, no chat spam. Long lines are dungeon map coordinates.
- **Glowing Bars**: repo holds TypeScript (TypeScriptToLua) source, docs, tests, CI; no Lua or binaries. No suspicious
  package scripts seen. The shipped Lua is built in CI, so the review is of the TS source.

AI notes: none of the eight asks AI tools not to use it. Glowing Bars' docs say openly that an AI writes most of its
code; the cjber repos carry `.claude/skills` release helpers. SkillUp and Tweaks locales are marked machine translated.

## Shortest Path Forever (cjber, release 1.24.1)

**Features.** All information/navigation; nothing plays the game for you. Journey planner (walk, flight, boat,
zeppelin, lift, tram, portal, hearthstone/class teleports, party mage portals), live replanning as you move, route
drawn on world map, minimap and a direction arrow, steps listed in the objective tracker, boat/zeppelin departure
times at docks, flight-time countdown while flying, "nearby services" panel (vendors by what they sell, trainers,
innkeepers, from QuestieDB), corpse route when dead, opt-in group/guild leaderboard and timetable sharing over addon
messages, an API other addons use to request a destination (RestedXP, Guidelime, TomTom waypoints).
Blizzard-frame touches we would not copy: hooks on the flight master map buttons (draws the planned hop and locks a
button highlight), objective-tracker sections.

**Route model (Routing/Planner.lua).**
- Graph nodes: start, goal, every dock, every faction-eligible flight point, both ends of each public portal
  (area-trigger teleports such as the Deeprun Tram), and teleport landing spots (bind point, class teleports).
- Edges: flights from a baked list of directed taxi paths with seconds per path (93% measured durations from
  InFlight's data, the rest distance at 32 yd/s); boat/zeppelin rides from baked routes with a period and per-stop
  phase; portals with a fixed loading allowance (5 s); teleports from the start only, waiting until the cooldown is
  ready; walking between any two places on the same continent and "landmass" (bounding boxes split islands).
- Walking costs: a baked table of navmesh-searched yards between fixed places (Data/Walks.lua, two variants for water
  walking); otherwise the straight-line gap as an admissible lower bound, later refined by a real path search over a
  shipped collision grid (HPA* over map tiles plus an 8-yard grid, sliced across frames in coroutines). Run speed is
  read live (default 7 yd/s) and only rescales walking edges, so the topology is cached.
- Search: a time-dependent label-setting search with an A*-style heuristic. A reverse Dijkstra from the goal gives
  each node a lower bound (boats counted at half their period). Labels are kept per node per arrival mode (on foot,
  in flight, transit) so boarding costs and "no revisiting" stay correct; a binary heap pops labels by
  time + bound. Boat waits are exact when the route's phase is known, otherwise half a period and the leg is marked
  "estimated". A Hearthstone must save at least 20 s; a very long single walk loses to a ride within 10%.
- Flight boarding: 3 s added when you first board a flight; connecting flights only through known nodes.
- **Which flight paths you know:** only learned at a flight master. On TAXIMAP_OPENED the addon reads
  `C_TaxiMap.GetAllTaxiNodes(GetTaxiMapID())` and counts a node as known when `TaxiNodeGetType(slotIndex)` is not
  "NONE" (the same rule the stock taxi frame uses to draw a node). Forever-specific: the node's own `state` field
  says reachable even for undiscovered nodes, so it is not trusted. Known IDs are saved per character, never
  unlearned by absence, and the user can toggle a node by hand. Until a flight master is opened the planner walks.
- **ETA:** sum of leg durations; flights use a per-character measured time per directed path once flown
  (UnitOnTaxi start to end, outliers rejected), else the shipped seconds. In flight, remaining time comes from the
  player's projected progress along the path polyline. Boats: the "anchor" (server-time epoch of the route's phase
  0) is fitted from your own position samples while riding (boats move ~30 yd/s vs running 7) and optionally shared
  with group/guild; stale anchors expire.
- Bind point: `GetBindLocation()` gives only a name, so the landing position is learned the first time you hearth
  (first position jump after the cast), kept with that name.

**Secret values.** `canaccessvalue()` on facing, minimap radius, bind name, cooldown start/duration, spell cast
time; when hidden it keeps the last readable run speed and treats a teleport cooldown as unknown.

**Compared with ours.**
- Landmarks.lua:284-285 records the flight master's position on TAXIMAP_OPENED but not which flight points the
  character knows; Landmarks.lua:82-87 and :148-159 rank "nearest" by straight-line yards on one continent, so a
  vendor across a river or a mountain looks closest, and nothing estimates travel time.
- Landmarks has no flight network: "nearest inn" is never "fly to X then walk 80 yd".
- Landmarks' page is reached through `/places` (Landmarks.lua:308-310) and printed as text lines into the hub
  (:39-44), not a list with buttons.
- LevelGuide.lua:89-100 measures straight-line distance to the next step only; no "fly to" hints.

**Simpler version we could build (read-only).**
1. (S) In Landmarks, on TAXIMAP_OPENED also save the known flight points per character (node ID, name, map
   position) using the "slot type is not NONE" rule. Show a "Flight points known: n" list.
2. (M) "Travel estimate" for Landmarks' nearest place and LevelGuide's next step: compare (a) walk = straight yards /
   run speed x 1.3 detour factor, with (b) walk to nearest known flight point + flight + walk from the known flight
   point nearest the target. Flight seconds: learn them ourselves per directed pair by timing UnitOnTaxi on
   PLAYER_CONTROL_LOST/GAINED (start from straight distance / 32 yd/s until measured). A plain Dijkstra over known
   nodes is enough; boats and portals can wait. Display "~4 min: fly Ironforge -> Menethil, then 120 yd".
3. (S) Hearthstone option: if the hearth cooldown is ready and the bind inn (Landmarks already knows inns) is closer
   to the target, offer "Hearth (10 s cast), then ...".
4. (L, later) Boat timetables: only if we want them; the anchor fitting is the hard part.

## Tweaks Forever (cjber, v2.4.2)

**Automation (out of scope, noted only):** auto accept/turn-in, gossip skip, summons/resurrect/duel/invite
handling, auto repair (guild funds), sell junk and marked items, one-click gear groups, train-all button, fishing
double-click, camera zoom, Edit Mode window moving, nameplate restyle, tooltip restyle.

**Information features and how they work.**
- XP per hour on the experience bar tooltip (UI/XPRate.lua): PLAYER_XP_UPDATE gains in a 15-minute window, level-up
  wrap handled with the previous max; no rate for the first 5 minutes. Each gain is classified: XP within 2 s of a
  QUEST_TURNED_IN (whose payload carries the XP) is quest XP; XP in combat or within 3 s after
  PLAYER_REGEN_ENABLED is a kill. Medians of the last 10 kills and last 10 quests give "kills to level: about N" and
  "quests to level: about N" (median so a discovery or elite kill does not skew it).
- Quest XP on the experience bar (UI/QuestXPBar.lua): sums `GetQuestLogRewardXP` over the log, split into ready to
  hand in vs not yet done; draws two gold segments on an overlay frame laid over the bar (deferred while the bar is
  protected in combat); the tooltip says which level and % all quests in the log would reach, walking a
  built-in per-level XP table.
- Quest levels in the log, nearest quest first in the tracker with yards (QuestDistance), quest givers on minimap
  tooltips and quest progress on unit tooltips (both via QuestieDB), best-selling quest reward marked with a coin
  (sell price x count, waits for GET_ITEM_INFO_RECEIVED).
- "Future spells" in the spellbook from cached trainer rows (TRAINER_SHOW) plus baked class-spell data; pet trainer
  hint (abilities the pet has not learned).
- Rare alerts from nameplates and vignettes (VIGNETTES_UPDATED), chime played by file because Forever lacks the kit.
- Unspent talent glow: Forever's talents are a trait tree, so it reads the tree currency of the active config
  (`C_Traits` tree currency), not `GetNumUnspentTalents`.
- Campsites (Forever-only feature): tooltip on camp objects explains each camp benefit (baked from the Camp Benefits
  auras), announces a newly gained benefit, remembers the campfire's position for direction.
- Map: dungeon entrance icons and level ranges, zone level ranges, coordinates, unexplored-area tint.
- Error journal: its own SafeCall wrapper records this addon's errors, ADDON_ACTION_BLOCKED/FORBIDDEN and warnings
  into saved variables for a "report a bug" window that pre-fills a GitHub issue URL to copy.

**Forever-specific and Midnight techniques.** `ns.Readable(value)` returns nil unless `canaccessvalue(value)`; a lint
in tools/ forces every unit name/GUID read through it. Every tooltip hook first checks `IsForbidden()`.
`Data/ForeverQuests.lua` lists quest IDs that exist in Forever's QuestV2 table but not Classic Era's (quests new to
Forever), generated from wago.tools.

**Compared with ForeverHub.**
- ForeverHub.lua:957-959 estimates time to level from a 15-minute window like Tweaks, but has no warm-up period:
  `elapsed` is floored at 60 s (:942), so one quest turned in during the first minute gives a wildly short estimate.
- ForeverHub does not tell kills from quests (TrackXP, ForeverHub.lua:1326-1343), so it cannot say "about 23 kills"
  or "about 4 quests" to level.
- FinishedQuestXP (ForeverHub.lua:920-937) only counts finished quests; there is no "all quests in the log" total
  and no "this reaches level N, x%" line, and the time-to-level line (:959) ignores the XP already waiting in
  finished quests.
- Hub stats reset on every /reload (session.start set at :1367) because samples live only in memory.
- Our helpers test secrets with `issecretvalue` only; no `canaccessvalue` use anywhere in the suite. Both exist on
  this client (FrameScriptDocumentation). Keep `issecretvalue` but note `canaccessvalue` is the documented "may I
  use it" test.

## SkillUp Forever (cjber, v1.1.6)

**Features.** Information, plus UI changes to the Blizzard Professions window (widened list, extra columns, sorting)
that we would not copy. Skill-up chance, cost and colour bands per recipe row and tooltip; levelling routes per
profession (crafts, trainer visits, skill books, rank quests, fees, tools and stations); shopping list counted against
bags and bank; reagent tooltips saying how many your tracked routes need; trainer annotations (best recipe to learn);
gathering node skill on node tooltips (English only); "crafted gear" tab (newest craftable item per slot, no stat
weights); opt-in leaderboards via addon messages; Auctionator price integration.

**Skill-up chance formula (Core/Model.lua).** Thresholds per recipe are four numbers: orange starts, yellow starts,
green starts, grey starts. Chance at skill s:
- below orange: not learnable (nil); orange band: 100%; grey or above: 0%;
- yellow and green: (grey - s) / (grey - yellow), i.e. falls linearly from 100% at the start of yellow to 0 at grey;
- plus a Forever-only bonus: the Legacy professions talent "Working Overtime" adds 4 percentage points per rank (up
  to +20%), read from the Legacy trait tree with `C_Traits.GetConfigIDByTreeID` + `C_Traits.GetNodeInfo`
  (activeRank); orange stays 100%, grey stays 0.
- Data: bundled thresholds from the SkillLineAbility DB2 of build 1.60.1 (trivial skill values), and the live grey
  from `C_TradeSkillUI.GetRecipeInfo(recipeID).maxTrivialLevel` replaces the bundled grey whenever the window is open
  (the client gives no live yellow/green). `numSkillUps` (orange crafts that give 2+ points) comes live too.
- Crafts needed: not the average 1/p. It finds the fewest crafts that reach the target with 90% confidence, using a
  point-by-point probability table (chance changes at every skill point), and caps multi-point crafts at the grey.
- Cost per point: first craft at the recipe's net cost (reagents minus what the product sells for, never below zero),
  each extra craft at full reagent cost, plus a nominal 1 silver "time cost" per craft so a free recipe that is near
  grey does not look free. Reagent prices: price seen at a vendor (includes reputation discount) > Auctionator buyout
  (net of 5% cut) > bundled vendor prices; mats you gather are free or valued at market (option); sub-crafting
  recursion up to three levels when crafting a reagent is cheaper than buying it.

**Routes.** Built per character from known recipes plus trainer- and vendor-taught ones not yet learned (bundled
trainer data, prices replaced by what trainers/vendors were seen to charge); at each skill point it picks the
cheapest cost per point, ties broken by better chance, then by a product that is a buff usable at your level. Rank
caps: trainers, else Expert books (First Aid, Cooking), else Artisan quests (per faction, titles from QuestieDB).
Missing tools (from `C_TradeSkillUI.GetRecipeRequirements` Totem entries) join the shopping list; station names
(Anvil, Forge, Cooking Fire) are shown per step. Craftable counts from `C_TradeSkillUI.GetCraftableCount`.

**Forever-specific notes from the code.**
- Gathering-skilled professions are levelled by gathering; their few Forever recipes cannot carry a route.
- Skinning/gathering skill from a corpse is left as "?" because nobody has confirmed Forever kept Classic's rule.
- Forever's SavedVariables sometimes fail to load (they cite a Forever bug tracker issue), so defaults are always the
  base and saved values are merged over them.
- Under the gamepad interface, opening any Blizzard context menu from addon code taints the gamepad focus manager;
  they open no menu there.
- Secrets: `ns.Readable` uses `issecretvalue`; every tooltip hook checks `IsForbidden()` first.

**Compared with ProfessionGuide / ProfessionCap / GoldGuide.**
- ProfessionGuide/Data_Alchemy.lua:9-10 uses fixed rules of thumb (orange 1 craft per point, yellow ~1.5, green ~3)
  for `crafts`. The real expected crafts depend on where in yellow/green you are; for a 40-point yellow-to-grey span the
  first yellow point needs ~1 craft, the midpoint ~2, and the last point ~40 on average (chance 1/40). Steps like 65-90 (Data_Alchemy.lua:43-50) can be off either
  way, so the shopping list (mats x crafts) will be wrong.
- ProfessionGuide data is static and one faction (Data_Alchemy.lua:1); it cannot react to recipes you already know,
  a recipe you skipped, or the Legacy talent bonus.
- ProfessionCap.lua:3-7 hard-codes rank caps and level requirements; fine, but it never says "train now so you don't
  waste skill-ups" for books held in bags, and Artisan for secondaries is described generally (:90-91).
- GoldGuide prices only from PriceMemory's own AH searches and vendor value; SkillUp's "vendor price seen at the
  merchant beats bundled price" trick (it records merchant prices with reputation discount) is a cheap upgrade.

**Improvements (read-only, our own UI).**
1. (S) ProfessionGuide: compute `crafts` per step from thresholds with the linear chance formula instead of the
   1.5/3 rule; store the four thresholds per step and derive expected crafts (and a 90% "safe" count for the
   shopping list).
2. (S) Read the live grey with `C_TradeSkillUI.GetRecipeInfo(id).maxTrivialLevel` while the profession window is open
   (event TRADE_SKILL_LIST_UPDATE), and show "this recipe goes grey at N" in our panel.
3. (S) Add the Working Overtime bonus (Legacy professions trait tree) to the chance.
4. (M) "Next best recipe" in ProfessionGuide: among known recipes, the cheapest cost per skill point at your current
   skill (net of what the product sells for), so the guide adapts when the user deviates.
5. (M) Shopping list against bags + bank with "safe" counts (90% confidence) and vendor prices seen.
6. (S) ProfessionCap: flag missing tools (Blacksmith Hammer, Mining Pick, Skinning Knife...) using
   `C_TradeSkillUI.GetRecipeRequirements` when the window is open.

## ForeverPlus (Epicstrike, 1.0.7)

**License note.** "All rights reserved": reading and studying are allowed, but copying any part into another addon is
forbidden even with attribution (LICENSE section 3d). Ideas only from here; no structure, text or data.
No AI-use note.

**Automation (out of scope):** auto accept/turn-in, gossip skip, auto repair, sell greys, auto-buy reagents, poisons
and ammo, fast loot, duel/battleground declines, error-message filter, hide UI elements, chat window replacement.

**Information features and how they work.**
- Info bar cells: clock, zone, coordinates, hearthstone cooldown, gold (this character or all characters, scoped by
  realm, faction and Forever "ruleset" read from `C_GameRules.GetCurrentGameModeRecordID`), session gold change,
  bag space by bag kind, ammo, Merchant's Favor (currency 3402, Forever's own currency for Waylaid Crates) and
  Honor with "red at cap", durability with repair cost, XP/hour, time to level, latency, framerate with per-addon CPU
  share (`C_AddOnProfiler`), profession and item cooldowns across characters.
- XP/hour: one measurement per login stored in SavedVariables, so it survives /reload (PLAYER_ENTERING_WORLD's
  isInitialLogin decides login vs reload); level-ups no longer reset it (the old level's remaining XP is added);
  rate never computed over less than 60 s; a click on the cell restarts the session (after a break). Hides itself when
  XP cannot be gained: `IsXPUserDisabled()`, `C_GameRules.IsGameRuleActive(Enum.GameRule.ExperienceBarDisabled)`, or
  at the level cap.
- Repair cost anywhere: sums `repairCost` from `C_TooltipInfo.GetInventoryItem("player", slot)` for slots 1-18; no
  merchant needed and no tooltip is shown.
- Durability warning: lowest equipped piece at or under a threshold (default 20%), said once per low condition and
  re-armed only when every piece is above the threshold again (a partial repair does not re-arm).
- Buff bars (missing / expiring / better rank known but not used, e.g. Frost Armor while Ice Armor is trained /
  "handout": party members missing a buff you can give), weapon imbues and poisons, user-ticked consumables
  (elixirs, food) with countdowns, gathering tracking reminder, ammo low warning. Aura reads only out of combat; in
  combat it relies on UNIT_COMBAT (plain values for the player) and UNIT_AURA as a bare signal.
- Quest reward value: sell price written on each reward button in both the accept and turn-in windows; never picks.
- Free bag slots on the backpack; "track all quests in this zone" checkbox on quest-log headers.

**Midnight/Forever techniques.** Asks `C_Secrets.Should...BeSecret` predicates (unit aura index/instance, spell aura,
unit power, max health, casting, threat; `GetSpellAuraSecrecy`; `CanCompareUnitTokens`) before reading, instead of
reading and testing afterwards (all exist in this client's SecretPredicateAPIDocumentation). Keeps "refused" and
"absent" apart: an API that will not answer (nil) is not treated as "no such thing" (false). Probes (temporary
recorder modules) measured what the client answers in combat before features were built.

**Compared with ours.**
- DurabilityWatch.lua:60-65 and :70-75 show the repair cost only when a repair merchant opens; the hub panel line
  (DurabilityWatch.lua:93-98) has no cost. ForeverPlus reads it anywhere from tooltip data.
- DurabilityWatch.lua:51-57 already re-arms only when the lowest piece is back above 25%, the same rule as
  ForeverPlus; no change needed there.
- ForeverHub's XP session lives in memory and restarts on /reload (ForeverHub.lua:1367-1369); ForeverPlus keeps it in
  saved data and tells login from reload. ForeverHub also has no "restart measurement" button for after a break.
- ForeverHub's gold/hr (ForeverHub.lua:970-983) counts from login only and is per character; no account-wide gold
  total, no Merchant's Favor.
- ReadyCheck finds old ranks on bars and missing self-buffs (ReadyCheck.lua:1-2, 340-341) but not "you know a better
  buff line than the one you are wearing" (Frost Armor vs Ice Armor) or user-chosen consumables to keep up.
- Our helpers decide secrecy after reading (`Safe()` with `issecretvalue`); asking `C_Secrets` first is cleaner for
  aura reads in ReadyCheck/FoodCheck.

## Leatrix Plus (Forever build 1.60.29)

**Mostly automation and Blizzard-frame changes (out of scope):** quest/gossip automation, accept summons and
resurrection, sell junk, repair, block duels/invites/friend requests, invite from whispers, chat and minimap
restyling, hide UI elements, class-coloured frames, faster loot, max camera zoom, sound muting, easy item destroy,
train-all button, Edit Mode layout. All of these hook or modify Blizzard frames.

**Information features worth noting.**
- Flight times (opt-in): shipped per-faction tables (`Leatrix_Plus_Flight_Alliance/Horde.lua`) keyed by continent and
  by the chain of node map positions (`TaxiNodePosition` rounded to 2 decimals) for the whole multi-hop route, so a
  route with stops has its own time. While flying a progress bar shows destination, next stop and time left; a
  missing or off-by-15-s time opens a "report this flight" window to send to the author. **Forever-specific:** checks
  the Legacy perk "Frequent Flier" with `IsPlayerSpell(1225490)` and divides flight time by 1.2 (20% faster).
- Info cards / Wowhead links: shows IDs of the item, spell, quest, NPC under the cursor with a copyable Wowhead link
  (Forever paths under wowhead.com/forever).
- Durability status on the character frame (cost and %), tooltip guild rank and target.
- Forever quirks it codes around: the second name of a player is a surname, not a realm; realms are hidden; the
  armory does not list characters under level 10; one spec per class with three trees in one modern tree; Legacy
  challenges replace achievements; tooltip extras don't apply during instanced combat (secret units).

**Secret values.** A `Safe()` wrapper around realm/name reads; tooltip extras disabled in instanced combat.

**Compared with ours.** Nothing in our suite times flights. If we add travel estimates (Landmarks item 2 above),
Frequent Flier must be honoured, or measured times per character must be used (Shortest Path's approach), otherwise
estimates are 20% long for characters with the perk.

## Leatrix Maps (Forever build 1.60.28)

**Features (map display):** reveal unexplored areas (shipped overlay art, the reason the zip is 24 MB), zone level
ranges and minimum fishing skill per zone on the map title, icons for dungeons/raids (with level range), flight
points, boats/zeppelins/tram, portals, spirit healers, zone crossings, opposing-faction POIs, coordinates, dungeon
maps from the entrance, map scaling/moving. All are WorldMapFrame hooks and pins; no automation.

**Data notes.** Zone table has min/max level and minimum fishing skill per zone; icons table per uiMap with position,
type, faction and level range. Data is static; flight points are drawn whether known or not.

**Map IDs (important for our suite).** Leatrix Maps, Tweaks, Shortest Path and OneForAll all key their Forever data by
the Classic-era UiMap IDs (Durotar 1411 ... Teldrassil 1438, Darkshore 1439, Ashenvale 1440, Stormwind 1453,
Ironforge 1455). research/BRIEF.md:13 says Forever's map IDs are Mainline (Teldrassil 57 ...). GoldGuide/Data.lua:17-19
already stores both, and Dungeons/Dungeons.lua:13 maps between them, so the suite hedges; but every helper that
compares `C_Map.GetBestMapForUnit` with a stored ID should accept both or convert. Worth confirming in game with
one `/dump C_Map.GetBestMapForUnit("player")` in Teldrassil.

**Compared with ours.** Our ZoneLevels shows level ranges; fishing minimum skill per zone is a cheap add (S) for
ZoneLevels or GoldGuide's farm list.

## OneForAll - Forever (Smoergi, 6.2.1)

**Automation/frame changes (out of scope):** looting, repairs, junk selling, quest automation, bag management, UI
moving, chat tools, node sparkle via soft-target CVars (changes game settings), "update all low ranks" on bars
(places spells), Crafting List has a craft button.

**Information features and how they work.**
- Flight times (Flights.lua): computed from path lengths extracted from the client DB (TaxiPath/TaxiPathNode yards,
  summed over stops) divided by taxi speed, then corrected: each measured flight ("From>To" by node ID) is kept and
  used first, and the ratio measured/computed is kept as a global correction factor for routes not yet flown. Without
  path data: straight distance on the flight map at a learned pace, marked "about". Node IDs from
  `C_TaxiMap.GetAllTaxiNodes`, because node names are translated (a German-client bug taught them that). A 1 s
  ticker only while `UnitOnTaxi`.
- Professions: all recipes with sources (vendors with coordinates, drops, objects; generated from QuestieDB Forever
  and Wowhead Forever item pages), who knows a recipe (guild and other users via addon messages), nearest trainers,
  and **Merchant's Favor** recipes: Forever-only recipes (spell IDs ~1250000+, e.g. lesser/greater elixirs, Acolyte's
  smithing gear) bought with currency 3402, with required skill and reagents, plus a "Favor guide".
- Crafting list across characters: materials vs bags + bank + alts (same realm/faction), sub-crafts broken down when
  any of your characters knows the recipe, vendor-sold reagents marked; item tooltips say "N more needed".
- Quest marks on nameplates from `C_TooltipInfo.GetUnit` QuestObjective lines (kill vs loot by objective type); the
  data is secret inside instances, so nothing is shown there.
- Gear planner with stat weights per spec and level (leveling curves below 60), suggestions from dungeon loot, quest
  rewards, sets, rep rewards, crafted items; wishlist per character.
- Trainer "what can I learn next" from client data; training costs remembered when you visit a trainer.
- Library books (Forever collectible books) with locations, status and a nearby alert using world-coordinate distance;
  Skyborne Ley Line / Convergence spots; hunter pet families and abilities; dungeon maps, drop chances, quest chains,
  keys, attunements; talent planner with imports from two Forever talent sites.

**Compared with ours.**
- ProfessionGuide/GoldGuide do not know Merchant's Favor recipes or the currency at all; for Forever these are new
  recipes that can be part of a levelling path (Data_Alchemy.lua steps 55-300 use only Classic recipes).
- ProfessionGuide's shopping list (in progress) counts only this character; OneForAll counts bank and alts.
- Landmarks has no flight times at all; OneForAll's "path length / speed, corrected by a learned factor" is the
  simplest good-enough flight ETA, simpler than Shortest Path's planner.

## Glowing Bars (vattiss, 2.8.2; TypeScript compiled to Lua)

**What it does.** Glows on action-bar buttons (Blizzard's and Bartender/Dominos/ElvUI): missing self and party buffs,
paladin blessings and seals, weapon imbues/poisons/stones, gathering tracking off, low reagents, low stock of items you
add by ID, Well Fed missing, old ranks on bars, ready important cooldowns and procs in combat. Drawing on Blizzard
action buttons is outside our rules; the logic is the interesting part.

**Mechanisms.**
- A tick every 1 s out of combat, 0.5 s in combat, plus event-driven refreshes; few new tables per tick.
- Buff memory bridges combat secrecy: a buff seen or cast is trusted as up until its usual duration ends, since in
  combat the client may return no auras or auras with secret name/ID. A full list the client does show is believed.
  Cooldowns likewise: last readable cooldown remembered; a successful cast starts the base cooldown.
- Well Fed learning: the game does not say which Well Fed spell a food gives, so after you eat an item it watches for
  the next new Well Fed and links the two, per character.
- Party buffs only out of combat, members online/alive/in range; suggests the group version when enough members lack
  a buff and the reagent is in bags.
- Reagent need read from the spell tooltip's "Reagents:" line (English wording), so a reagent the client dropped never
  nags.
- "When" rules per reminder: always / in combat / out of combat / enemy targeted / in a town or inn (low reagents and
  stock only nag where you can buy).
- Forever detail: Shield Block has block charges on Forever.

**Compared with ours.**
- FoodCheck is only reachable via `/food` (FoodCheck.lua:103-104) and reports best food/drink; it does not track Well Fed
  or remind you to eat a buff food before a fight.
- SupplyWatch warns about stock at merchants (SupplyWatch.lua:110-111), good; Glowing Bars' "only nag in a town or inn"
  rule would suit SupplyWatch's hub status lines too.
- ReadyCheck skips buffs in combat (ReadyCheck.lua:340-341); the "remember what was seen/cast" trick would let it keep
  a correct status line through a fight without reading secret auras.

## Ranked improvements for our suite (read-only, own frames, no Blizzard hooks)

| # | Helper | Improvement | Size | Learned from |
|---|---|---|---|---|
| 1 | ForeverHub | XP panel: 5-minute warm-up (or 60 s floor is not enough, ForeverHub.lua:942); split kill vs quest XP (QUEST_TURNED_IN payload, combat window); "about N kills / N quests to level" from medians | S | Tweaks |
| 2 | ForeverHub | Quest XP: add "all quests in log" total and "reaches level N, x%" (needs a per-level XP table); subtract finished-quest XP from the time-to-level line (:959) | S | Tweaks |
| 3 | ForeverHub | Keep the XP/gold session in saved variables, restart only on real login (PLAYER_ENTERING_WORLD isInitialLogin), plus a "restart" button for breaks (:1367) | S | ForeverPlus |
| 4 | ProfessionGuide | Derive crafts per step from thresholds with the chance formula (grey-s)/(grey-yellow), and a 90%-safe count for the shopping list, instead of the 1.5/3 rule (Data_Alchemy.lua:9-10) | S | SkillUp |
| 5 | Landmarks | Save the character's known flight points at TAXIMAP_OPENED (slot type not NONE) next to the flight master record (Landmarks.lua:284-285) | S | Shortest Path |
| 6 | DurabilityWatch | Repair cost anywhere from `C_TooltipInfo.GetInventoryItem(...).repairCost`, shown on the hub status line (DurabilityWatch.lua:60-65, 93-98) | S | ForeverPlus |
| 7 | Landmarks + LevelGuide | Travel estimate: walk vs fly (known nodes, Dijkstra, measured per-pair flight times with path-length/speed fallback and learned correction factor, Frequent Flier 1.2x) vs hearth; "~4 min: fly X -> Y, then 120 yd" | M | Shortest Path, OneForAll, Leatrix Plus |
| 8 | ProfessionGuide | Live grey from `C_TradeSkillUI.GetRecipeInfo(id).maxTrivialLevel`, Working Overtime bonus (Legacy trait tree), and "next best known recipe" by cost per point net of product value | M | SkillUp |
| 9 | ProfessionGuide / GoldGuide | Merchant's Favor: show currency 3402 and the Forever-only Favor recipes as optional steps/targets | M | OneForAll, ForeverPlus |
| 10 | ReadyCheck / FoodCheck | Bridge combat secrecy with a "seen or cast" buff memory; ask `C_Secrets.Should...BeSecret` before reading auras; Well Fed learning; "better buff line known" (Frost vs Ice Armor) | M | Glowing Bars, ForeverPlus |

Also: verify Forever map IDs in game (Classic 14xx vs Mainline); every third-party Forever addon reviewed uses 14xx.

## Notable techniques

- Known flight points: `TaxiNodeGetType(slot) ~= "NONE"` at a flight master; the node `state` field lies on Forever.
- Flight ETA: measure per directed pair with UnitOnTaxi; fallback path yards / speed scaled by learned ratio;
  Frequent Flier perk (`IsPlayerSpell(1225490)`) = 20% faster.
- Bind point position is unknown to the API: learn it from the first position jump after a hearth.
- Secrets: `canaccessvalue` (Tweaks/Shortest Path), `C_Secrets` predicates (ForeverPlus), memory of last readable value
  (Glowing Bars, Shortest Path run speed); every tooltip hook checks `IsForbidden()`.
- Forever SavedVariables sometimes fail to load: always start from defaults and merge (SkillUp).
- Forever-only systems to know: Legacy trait trees (profession perk Working Overtime, Frequent Flier), Merchant's
  Favor currency 3402, campsites/camp benefits, library books, Skyborne ley lines, player surnames instead of realms,
  `C_GameRules` ruleset ID, Shield Block/Inner Fire charges.
