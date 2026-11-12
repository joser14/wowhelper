# Forever addon suite: status (2026-11-11)

Start here when resuming.

## Installed
- Six addons: !ForeverHub, ForeverGuides, ForeverQuests, ForeverBags, ForeverCharacter, ForeverWorld (first installed
  2026-11-09).
- Backups from the first install: old per-helper folders in `_forever_\Interface\AddOns_ForeverBackup_20261109_083113`,
  full WTF copy in `_forever_\WTF_Backup_20261109`. VoidSweep and VeritasUI_PriorityRotation were moved (user approved) to
  `_forever_\Interface\AddOns_Removed_20261109`.
- Roll back: close WoW, delete the six bundle folders, move the backup folders back.
- Tests: all pass (`tests\runall.ps1`, after `npm install` in tests).
- `dist\` is build output: rebuild (`.\build.ps1`, then `-Install` with WoW closed) before testing in game, or the
  game runs older code than the checks below assume.

## In-game checklist

One list, in the order you'll naturally run into things. Each line says what to do and what correct looks like.
**(important)** marks checks about "blocked from an action" pop-ups, taint or Lua errors: do those first. If
something looks wrong, open the hub's **Errors** page and note what it says.

### Right after login
1. **(important)** Log in, then type /reload. Correct: no Lua error pop-up, no "has been blocked from an action"
   pop-up, the hub opens on Home and the Manage page switches work.
2. **(important)** Open the hub's Errors page after a few minutes logged in (out of combat). Correct: no
   "Blocked action" line and no LevelGuide error (its quest-level scan starts 60 s after login).
3. With one quest watched and Blizzard's quest tracker showing, look at the right edge. Correct: our tracker panel
   sits just left of Blizzard's, not on top of it. Right-click our tracker's header (Blizzard's tracker goes clear):
   our panel moves back under the minimap.
4. Hub > Level log page. Correct: the Level log window does not open by itself; "Show or hide window" opens it, and
   clicking it again closes it.
5. Hub > Characters page: type `add Test`. Correct: the to-do shows on the page. On a brand-new character the
   ForeverHelper window starts closed.
6. Hub > Manage page: switch QuestTracker Off. Correct: our tracker panel disappears at once; On brings it back in
   the same spot and fold.
7. Open the Level log window and ForeverHelper's window, then switch each helper Off and On on the Manage page.
   Correct: the window closes, then reopens. Close one first, switch Off and On: it stays closed.
8. Manage page: switch MapPins Off and On. Correct: the minimap pins come back at once, without a /reload.
9. Turn ForeverGuides off in the AddOns list and /reload (turn it back on afterwards). Correct: the Gold goal, Gold
   guide, Dungeons and Profession guide pages show no row of view buttons.
10. Hub side panel, line 5: "N % of the way to 60 - about N h at this pace". Correct: a small percentage at level 11
    that rises after each level. (If it looks off, `/dump LevelLogXPCurve` and compare with the Classic XP table.)
11. Hub > Profession guide page. Correct: your professions and skill levels are listed (if they are, the reading
    works whichever way the game reports them).
12. If any character has mail that runs out within 3 days: Correct: one pop-up about it about 8 s after login, not
    more, and the same mail at the top of Find an item > Mail expiry.
13. If you use the game's Classic preset: Correct: QuestCheck's notice appears once, and quest "!" marks over NPCs
    really are hidden (if they aren't, the notice is wrong).
14. Press N to open the talent window. Correct: our build panel appears beside it and goes away when you close the
    window. Put a point in a talent without confirming it: the panel and the hub's "unspent points" line should agree
    on whether it counts.

### In town (Darnassus, Rut'theran, Dolanaar, Auberdine: trainer, AH, mail, bank, inn)
15. **(important)** Esc > Options > AddOns > Forever Hub. Correct: the page is there and opens with no "blocked"
    message.
16. Craftsmen's Terrace in Darnassus. Correct: its three trainers are three separate entries on the hub's Places page.
17. Priest trainer. Correct: WindowBadges shows "10% off (Honored with Darnassus)" only when the trainer's prices
    really are lower; no discount badge at full prices.
18. Talk to an innkeeper or bind your hearthstone. Correct: the guide's "set your hearthstone" step ticks off, and the
    travel plan starts from that inn (this checks that the game's inn names match ours).
19. Hover any item you could sell. Correct: our sell-price line matches the game's own "Sell price" in the tooltip.
20. With damaged gear, stand away from a vendor. Correct: a "Repair ... (cost)" line shows. Then repair at a vendor
    and open Gold goal > Money sources: the cost is booked as a repair, not a vendor purchase. Buying a piece of gear
    and equipping it at once should not count as a repair.
21. Sell junk, pay for a flight, loot some coin, then Gold goal > Money sources. Correct: each amount sits under
    the right source (vendor, flight, loot).
22. Mail an item to an alt, then hover that item on the sender. Correct: the tooltip shows the alt's "mail" count.
    Also note whether mail to your own alts arrives at once or after an hour.
23. Open the mailbox after one of your auctions sells. Correct: Gold goal > Auction sales lists it with price, cut
    and age.
24. Auction house: search the same item twice, about 10 minutes apart. Correct: a sell-speed line appears on its
    tooltip. If it never appears for any item, tell me (the game may count prices per item, not per auction). Also
    buy one item and search again: note whether your own purchase shows up as a sale.
25. Visit the bank, then type `/find bags`. Correct: a grid window of your bags, bank, keyring, worn gear and mail
    opens; hovering an icon shows its tooltip; < and > switch characters; the search box dims non-matches.
26. Open a profession window (and a second one within 2 seconds). Correct: Profession guide > Craft now lists what
    your bags can make for both professions.
27. Spend a talent point that changes your role (for example into Shadow), then open the Dungeons page. Correct: the
    "upgrades" counts change to match.
28. Switch QuestMobs, ItemAdvisor (with your bags open) and WindowBadges (at a vendor) Off and On on the Manage page.
    Correct: markers, bag coins and arrows, and vendor badges go away and come back without a /reload.
29. Open the Group Finder and search for dungeons. Correct: the Dungeons window's Groups tab lists the groups,
    matched to the right dungeons.
30. Dungeons window: tick an item on the Wish list. Correct: a star shows on that dungeon's line and the item shows
    on the hub page's "wish" list.

### While questing in Teldrassil and Darkshore
31. **(important)** Fight a few mobs with the world map open, then with it closed. Correct: no "blocked from an
    action" pop-up and no new "Blocked action" line on the Errors page.
32. **(important)** Click a quest in our tracker (to focus it) and left-click a guide step, then fight. Correct: no
    error on the Errors page afterwards (this is the objective-tracker taint we worry about).
33. **(important)** In a fight, click a map pin of ours. Correct: it sets the map pin, with no pop-up.
34. World map: zoom, pan, windowed and maximised. Correct: our pins stay on their spots; hover shows a tooltip; click
    works. In gamepad mode there are no errors.
35. World map info line. Correct: it stays inside the map at every map size, shows the zone under the cursor with its
    level range and coordinates, and "Explored about N% (K areas)". The colour updates after a level-up.
36. Turn on the map's "explore" layer and walk to its pin. Correct: the area reveals, the percentage goes up and the
    pin moves to the next unexplored spot.
37. World map with quest givers shown. Correct: "!" and "?" look like normal quest icons, not speech bubbles.
38. Map pins "Also here" and "on camps" lines. Correct: they name the right things nearby.
39. Follow the guide through Teldrassil and Darkshore. Correct: the arrow points the right way and doesn't swing
    wildly, the yards and time to go look right, and kill camps line up with where mobs really are. Skips survive a
    /reload. Caylais and Shaussiy are only roughly placed: note their real spots.
40. Talk to quest givers (both chat-menu NPCs and plain "greeting" ones). Correct: the guide only marks a quest "not
    offered" when the NPC really doesn't offer it.
41. Abandon a route quest. Correct: a card appears under the guide; "Skip it" works and a right-click on the guide's
    header undoes it. Turning in a route quest normally must NOT show a "You dropped ..." card.
42. Look at the three guide cards (lost quest, group quest, route choice). Correct: they sit neatly under the guide.
    Darkshore's elite quests should ask "do it / skip it".
43. Guide plan line. Correct: "Route ends at about level X" is close to where you really leave the zone, and "About N
    kills to level" is close to the kills it really takes.
44. Level up while watching "XP/h" on the guide's plan line. Correct: it doesn't jump to a huge number for the next
    15 minutes.
45. Turn in a quest that levels you, then open the Level log page. Correct: the quest XP split between the two levels
    adds up to what the quest gave.
46. Level log page and window. Correct: XP from quests and from kills is split sensibly, the journey shows your
    levels, new zones and deaths by day, and the time split doesn't call active play "away".
47. Finish a quest. Correct: one sound (QuestTracker's "Quest complete") and one pop-up. Switch that sound off
    ("Snd" in our tracker's header), finish another: now the hub's chime plays.
48. A quest with a "1/1" objective that isn't finished yet. Correct: our tracker shows 0/1.
49. Open QuestMobs' list window. Correct: it sits left of our tracker, not on it.
50. Enter a zone above your level (for example Ashenvale's high parts from Darkshore). Correct: a "Careful" pop-up;
    near elites, the elite warning.
51. Kill a rare, or let one show up. Correct: the rare alert comes after the fight, not during it. Type
    `watch <rare name>` on the Rares page: once you've seen it, its marker shows the distance.
52. Swim under water until your breath runs low. Correct: the drowning warning appears, with its sound.
53. Type `/way 50 50`, and `/way` a spot about 300 yards due east. Correct: with TomTom installed `/way` doesn't clash
    (`/fway` always works); the minimap rim arrow sits on the right edge pointing right, also with minimap rotation
    on and with a square minimap. Our minimap pins point the right way with rotation on and off.
54. Type `/way Zephras 50 50` and `/way Riverglades 50 50`. Correct: both set a pin; "No zone or city called ..."
    means the zone list needs a fallback.
55. Talk to quest NPCs with AutoQuest on: one with a finished and a new quest, an old-style greeting NPC, a reward
    with no choice, a gray quest. Correct: it accepts and turns in, skips gray quests, does nothing while you hold
    Shift, and never picks between several rewards.
56. In a party, have someone share a quest with you. Correct: AutoQuest does NOT accept it.
57. Log in and turn in a quest at once. Correct: the Reputation page's "this session" gain includes that first
    Darnassus gain.
58. Loot quest rewards and drops. Correct: ItemAdvisor's verdicts look sensible at your level. If you switch on
    WindowBadges' reward badge, it and ItemAdvisor should not mark two different rewards "best".
59. Loot with full bags. Correct: the bags-full hint appears.
60. Eat buff food. Correct: FoodCheck sees "Well Fed". Set up a camp (Camping quests): FoodCheck's camp lines and the
    campfire direction are right, and RestGuard counts the camp's rested bonus.
61. Drink after a fight. Correct: "Mana full in N s" is about right, and hovering a drink gives sensible advice.

### In combat and on death
62. **(important)** Fight with a quest item showing in our tracker: click the item, fold the tracker, try to drag it.
    Correct: no "blocked" pop-up; layout changes wait until the fight ends.
63. **(important)** Fight quest mobs with nameplates on. Correct: QuestMobs' markers show on the nameplates, with no
    "blocked" message or error.
64. **(important)** Type /reload during a fight, then leave combat. Correct: the Forever Hub page appears in Options,
    narration stays off, and no "Blocked action" line is added.
65. **(important)** Switch QuestTracker Off on the Manage page during a fight. Correct: it disappears when the fight
    ends, with no "blocked" message.
66. **(important)** Drop under 35 % health and under 20 % mana in a fight. Correct: a red screen edge and a drink icon
    appear, from the start of the fight, with no error on the Errors page.
67. Die to a mob. Correct: within a few seconds the Deaths page names the real killer and shows the last hits.
68. Release your spirit. Correct: the guide's arrow points at your body straight away, "Corpse N yd m:ss" is about
    right (also when you release across a zone border), "Spirit healer about N yd from your body" matches where you
    appear, and "Resurrect in N s" at the body matches the game's wait. The arrow turns red, yellow, green as you
    near it; with "Snd" on, the arrival sound plays once.
69. Below level 20, the guide may suggest dying to skip a walk. Correct: it only does so when that really saves time.
70. Optional, for a future fight summary: after a fight, `/dump C_DamageMeter.IsDamageMeterAvailable()` and note the
    answer. For future drop rates: with a corpse's loot window open, `/dump GetLootSourceInfo(1)` (and once on a
    skinned corpse).

### On a boat or a flight
71. Take a flight. Correct: the guide shows "Flying to X" with no arrow; on landing "Flight time learned: A to B"
    appears and the Places page stops saying "In flight". The known flight points count matches the flight map.
72. Wait at Auberdine's pier after taking the boat once. Correct: "leaves in m:ss" counts down and matches the real
    boat.
73. Ride the boat (Rut'theran to Auberdine, later to Stormwind). Correct: "On the boat to X" holds from leaving the
    pier until you land, and after a loading screen the guide doesn't show a leg starting mid-sea.
74. Check the dock spots on the map: Auberdine's piers (Rut'theran boat 33.2, 40.0; Stormwind boat 30.7, 41.0;
    Menethil boat 32.4, 43.8), Rut'theran dock 54.9, 96.9 and the Darnassus portal 55.9, 89.4. Correct: the guide's
    boat steps point at them.

### In a dungeon
75. Enter a dungeon. Correct: the Dungeons window's Runs tab starts a run and records time inside, XP kills, XP, gold,
    deaths and notable loot. Leave and come back within 30 min: same run. Reset and re-enter: a new run.
76. If the game ever says "You have entered too many instances recently", note how many entries it took in that hour
    (and day). Correct: the instance log's cap setting should match.
77. Wish-list an item and see it drop. Correct: a pop-up when it's in the loot window and a mark on the loot line.
78. Hover a reward or drop inside the dungeon. Correct: if the game hides your worn gear there, ItemAdvisor says it
    can't read it, never "fills an empty slot".

### Later levels (20+)
79. Visit the approximate dungeon entrances (Wailing Caverns, Blackfathom Deeps, and later SM, RFD, Maraudon, ST,
    Scholomance, Stratholme, Ruins of Lordaeron). Correct: the Dungeons pin sits at the real entrance.
80. Ashenvale, Stonetalon, Wetlands, Duskwood, Hillsbrad: Correct: the ZoneLevels ranges look right (four differ from
    Leatrix Maps), and each zone's "Route ends at about level X" holds.
81. A walk through The Barrens. Correct: the guide routes around the Crossroads and shows "Careful: hostile ...".
82. Boats and spots further out: Stormwind Harbor 22.5, 56.0, the tram (Stormwind 66.0, 34.0 / Ironforge 76.8, 51.2),
    Menethil piers 4.6, 57.0 / 5.0, 63.5, Theramore 71.6, 56.4, Powderfuse Port 79.0, 53.0, Dalaran 14.0, 66.0.
    Also: do Southshore's boats go to Menethil and Auberdine, what are Farholde Keep's flight links, and does
    Stormwind's inn read as "Stormwind City" or "Trade District"? Wait times are estimates.
83. From level 38: the guide's riding-money hint. At 40 learn riding: the guide sees it, and the cost (120 g) is right.
84. Reputation turn-ins (Timbermaw, Argent Dawn, Thorium, Cenarion, Runecloth). Correct: the counts and rep values
    on the Reputation page match the game. Note whether Scourgestones stop giving rep at Honored.
85. Ding 60 with a talent point unspent. Correct: the side panel's Builds row updates within a few seconds.
86. With a shaman in your group: Correct: FoodCheck recognises Strength of Earth and Blessing of Wisdom by name.
87. Alts (other races, classes, factions), when you play them:
    - Skyborne: the race reads as "Skyborne", the Zephras Isle zeppelin spot (65.8, 83.4) and the map name match, and
      the ley line hint works.
    - Human/Dwarf routes: Shadow Magic waits for Blackrock Blockade; The Reports with Frostmane Hold done but not
      Secure the Mountain; Shayla's real spot; Lightforge Ingots after The Lost Ingots (are 324/526 either-or?);
      "Of Mice and Milk" in Westfall exists.
    - Paladin and warlock: the class-quest wording for riding.
    - Enchanter: green gear shows DISENCHANT.
    - Mage with the Reagent Economy perk: no "reagent" row for Arcane Brilliance.
    - Druid Polearms at 20 and rogue One-Handed Axes at a weapon master match ItemAdvisor.
    - Hunter: the ammo slot is read. Rogue or shaman: weapon-enchant time left reads right.
    - Warlock with an Imp: the Trainer page's tome list is sensible.
    - Horde: the same item on the Alliance and Horde AH; if prices are shared, PriceMemory can stop splitting by
      faction.

Notes:
- BagCheck, DurabilityWatch, ProfessionCap, QuestCheck and SupplyWatch still write to UIErrorsFrame, but only when the
  hub isn't loaded (it always is in the installed bundles).
- Sources for the list: research\review4.md, perf_audit.md, final_review_*.md, xreview_*.md, re_round5.md,
  review3_*.md, re_round4.md, taint_audit.md and the commits since 2026-11-10. Dropped as already fixed in code:
  review4 suspicions 1-7 and 10-14, final_review_bags check 1 (inbox wiped with the mailbox closed),
  review3_quests_world 1 (killer lost on death, now from the death recap) and 5 (UNIT_HEALTH), re_round5 checks 2
  (death-recap fields, now built) and 7 (explored textures, not used by the built feature).

## Rules the suite follows
- Line in the sand: nothing that breaks Blizzard's ToS (no automation: no auto sell/buy/equip/train/cast) and nothing that causes taint errors.
  Exception asked for by the owner (2026-11-09): AutoQuest accepts and turns in quests, only in a quest window the player opened
  (Shift pauses; never with several rewards, gold, combat, player-shared quests). No other helper may call AcceptQuest/CompleteQuest/GetQuestReward.
- NEVER use the world-map canvas pin pool (WorldMapFrame:AddDataProvider / AcquirePin): it caused "ForeverWorld has been blocked from an action" (UNKNOWN()) in game on 2026-11-09. MapPins draws its own overlay frames.
- NEVER register COMBAT_LOG_EVENT_UNFILTERED or other CallbackEvent events, even in pcall: ADDON_ACTION_FORBIDDEN pop-up. DeathNotes did this on every load; that was the real cause of the ForeverWorld pop-up (removed 2026-11-09, evening). The killer now comes from the game's death recap (C_DeathRecap), with your hostile target as the fallback.
- Never assign Blizzard globals or tables (e.g. `SlashCmdList = SlashCmdList or {}`); only add our own keys. See research/taint_audit.md.
- Fine: tooltip lines (TooltipDataProcessor), our frames on the minimap, our own badges anchored over Blizzard buttons, Settings panel (registered out of combat), addon compartment, keybindings, cosmetic alpha on Blizzard's quest tracker (now only when the player right-clicks to make it clear).
- Never replace/hook/rewrite Blizzard functions, never call protected functions.
- UI in our own windows (ForeverHub pages, side panel, pop-ups). No chat output. A helper switched Off on the Manage page hides its own frames too.
- Third-party code: download only into a quarantine folder after a malware check, never run or install it; describe reverse-engineering in our own words, copy no code.
- Forever uses Classic-era uiMapIDs (Teldrassil 1438, Darnassus 1457, Elwynn 1429, Stormwind 1453). Resolve maps by name where possible.
- Forever's combat log is closed to addons; many values are secret in combat/instances: Safe() everything.
- **LevelGuide.lua and ItemAdvisor.lua are at Lua's 200-local limit in their main chunks.** New code there must go in a
  `do` block and keep its state in one table, as `LevelGuide_QuestGivers` does.

## Layout
- One folder per helper (source + .toc). `tests/` = Node + fengari harness. `research/` = research reports and build data
  (`research/builds/gen_data.js` regenerates `Builds/Data.lua` from `research/builds/<CLASS>.lua`).
- `build.ps1` assembles the six addons into `dist/`; `.\build.ps1 -Install` (WoW closed) also installs them, moving any
  old per-helper folders to a dated backup and carrying their saved data over once. Before building it checks that
  every helper is in one bundle, every .lua is in its .toc, every .toc says Interface 16001 and no saved variable is
  declared twice.

## Follow-ups
- Horde routes and plan: RestedXP's free Forever guides cover Horde 1-22 (Durotar, Mulgore, Tirisfal, Barrens,
  Silverpine) and could be a fact source, as the Alliance ones were.
- Skyborne 1-13 on Zephras Isle has no step-by-step route yet, only the plan.
- Tooltips: quest giver "Turn in" lines for quests you don't hold are noisy at busy NPCs; consider showing only held turn-ins.
- Open performance items (research\perf_audit.md): LevelGuide's 20 Hz arrow strings and its quest-log walk on every
  QUEST_LOG_UPDATE; Builds' talent-panel watcher closures.
- Not built from research\re_round5.md: fight summary from C_DamageMeter (#2), personal drop rates (#5).

## Research reports (research/)
taint_audit.md, builds_forever.md, builds/, gaps_filled.md, curseforge_forever.md, thirdparty.md, thirdparty_features.md,
rxp_deep.md, auctionator_deep.md, popular_quests_maps.md, popular_items_spells.md, popular_qol_routes.md, routes.md,
landmarks.md, levelguide_questtracker.md, itemadvisor_hub_helper.md, small_addons.md, BRIEF.md (brief for review workers).
Since 2026-11-10: review_2026-11-10.md, compare_2026-11-10.md, forever_improvements_2026-11-10.md, guides_deep_re.md,
review3_*.md, re_round3.md, re_round4.md, re_round5.md, review4.md, perf_audit.md, builds_tuning_2026-11-10.md,
final_review_*.md, xreview_ui.md, xreview_packaging.md.

<details>
<summary>Older notes</summary>

- 2026-11-09: installed as six bundles with the taint fix (MapPins overlay frames, SlashCmdList rewrite removed,
  combat-safe Options/CVar/tracker alpha). Old tests that checked for chat output and replaced window layouts, and
  one-off data-migration scripts, were removed (see git history).
- 2026-11-09, later: LevelGuide routes and the zone plan are Alliance only (`LevelGuideRoutes.faction`); Skyborne get
  a Zephras Isle plan entry for 1-13, the zeppelin to Westfall and the Human chain (`tests\test_lg_faction.lua`);
  RestGuard no longer errors without the hearthstone cooldown API; RestedXP v4.11.35 re-checked
  (`research\rxp_forever_guides.md` 6.1).
- 2026-11-10: full review of every helper (`research\review_2026-11-10.md`), 19 bugs fixed; comparison with other
  addons in `research\compare_2026-11-10.md`. Second round: 12 more fixes; quest givers on the map, drowning/fatigue
  warning, quest vs kill XP, flight times, `/way`. Third round: 12 LevelGuide fixes; Forever research
  (`forever_improvements_2026-11-10.md`) gave the Classic-preset notice, profession fallback by skill line, Waylaid
  Crates never sold, Riverglades/Zephras map IDs, the error-cap warning.
- 2026-11-10, night: LevelGuide engine items 2-18 of `research\guides_deep_re.md` section 12 (placement from the
  quest log, offers from the giver's window, Polestar XP model, "While you're here", arrow damping, spawn camps,
  server level scan, lost-quest card, travel planner `Travel.lua`/`TravelPlan.lua`, hub order, group/elite cards,
  secret-safe objective counts, step remapping, kills to level, personal spots, route forks, death-skip and riding
  hints). Items 19-20 (walking router) not built.
- 2026-11-10/11: round 3 and round 4 features and reviews (review3_*.md, re_round4.md); review 4 and its follow-up
  fixes; perf audit; builds rechecked after the 10 Nov class tuning (`gen_data.js` runs again).
- 2026-11-11: round 5 (re_round5.md): money by source, AH invoices, mail expiry, sell speed, rep turn-ins, craft now,
  quest sounds, LevelLog journey/stats/ETA, exploration progress, bag view, instance log, wish list, Group Finder
  listings, death recap. Night Elf route 1-30 audited against QuestDB. Final reviews per bundle, cross-addon UI and
  packaging reviews. Blizzard's quest tracker stays visible by default; ItemFinder saves the inbox only while the
  mailbox is open; Off on the Manage page hides a helper's own frames.

</details>
