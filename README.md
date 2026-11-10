# wowhelper

A suite of helper addons for **World of Warcraft: Forever** (client 1.60.1, interface 16001), built for a solo
leveling player. Everything is gathered in one window, the **Forever Hub**, with a small side panel that only shows
what needs doing right now.

The helpers **only show information**, with one exception you can switch off: **AutoQuest** accepts quests and turns
in finished ones, but only inside a quest giver's window you opened yourself (hold Shift to pause; it never picks
between several rewards, pays gold, acts in combat or takes quests shared by players). Nothing else plays for you:
no auto-selling, auto-buying, auto-equipping, auto-training, targeting, moving or casting.

> Status: early. Every helper is covered by automated tests, but the suite has only just been installed in game.
> Expect rough edges, and check the hub's **Errors** page if something looks wrong.

## What's in it

The 30-odd helpers are installed as six addons:

| Addon | Helpers | What you get |
|---|---|---|
| **Forever Hub** | ForeverHub, ForeverHelper, ErrorLog | The main window: a Home page explaining every helper, a Manage page to switch helpers or whole addons on and off, a side panel (XP and gold rates, time to level, XP waiting in finished quests), pop-up history, an error log, keybindings, an entry in the minimap's addon menu, an Options page, alerts and a hearthstone button. |
| **Forever Guides** | LevelGuide, ProfessionGuide, ProfessionCap, GoldGuide, GoldGoal, Dungeons | A step-by-step leveling route with an arrow, built from Forever quest data (Alliance only for now, see below); profession guides from 1 to 300 for all 12 professions; gold farms for your level and professions; a riding or custom gold goal; a guide to the 35 dungeons, Forever's new ones included. |
| **Forever Quests** | QuestTracker, QuestCheck, ZoneLevels, QuestMobs, AutoQuest | A cleaner quest tracker, quest log checks, zone level warnings, markers with progress (like 3/8) beside enemies you still need, and quests accepted and turned in for you at NPCs you talk to (hold Shift to pause). |
| **Forever Bags** | ItemAdvisor, BagCheck, ItemFinder, PriceMemory, FoodCheck, SupplyWatch, DurabilityWatch, Tooltips, WindowBadges | Equip, keep, sell or auction advice on every item; item search across all your characters; auction prices remembered from your own searches; extra tooltip lines (vendor price, last auction price, how many you own, where it drops, which quest needs it); badges on vendor, trainer and quest-reward windows; food, supplies and repair warnings. |
| **Forever Character** | Builds, TalentNudge, TrainerNotes, ReadyCheck, WeaponSkillWatch, RestGuard, LevelLog, RepWatch | Talent builds for all nine classes (leveling, PvP, tank, healer, damage) with the next talent to take; old spell ranks on your bars and missing buffs; trainer reminders; weapon skill, rested XP, level times and reputation. |
| **Forever World** | Landmarks, MapPins, DeathNotes, RareWatch | Remembers vendors, inns, flight masters, mailboxes, banks and trainers you visit and finds the nearest; pins on the world map and minimap; remembers where you died and warns when you walk back; rare sightings and a layer estimate. |

### Leveling routes: who they cover

The leveling routes are **Alliance only** for now:

| Race | Route |
|---|---|
| Night Elf | Teldrassil 1-12, then Darkshore with the Loch Modan and Redridge trips, on to 60. |
| Dwarf, Gnome | Dun Morogh from 6, then Loch Modan, on to 60. |
| Human | Westfall from 10, on to 60. |
| Skyborne | Pointed to Zephras Isle for levels 1-13. At about 13, the arrow points at the isle's zeppelin to Dalaran; from there you take the Skyborne Portal to Stormwind and Bolvar sends you to Westfall. After that you follow the Human route. |

- Below a route's first level, the guide names the zones to level in.
- Horde characters, Horde Skyborne included, get no route or zone plan, rather than directions into Alliance zones.
- The quest tracker, the quest-log helpers and every other helper work for both factions.

## Install

1. Close World of Warcraft.
2. In PowerShell, from this folder:

   ```powershell
   .\build.ps1 -Install
   ```

   This assembles the six addons into `dist\` and copies them into `_forever_\Interface\AddOns`. It also:
   - moves any old one-folder-per-helper installs into a dated backup folder next to AddOns, so nothing loads twice;
   - carries each old helper's saved settings into the new addon's saved file, once.
3. Start the game, and open the hub from its minimap button, the minimap's addon menu, or a keybinding
   (Key Bindings > AddOns > Forever Hub).

`.\build.ps1` on its own only builds into `dist\`, without installing.

**Roll back:** close the game, delete the six `Forever*` folders from AddOns, and move the backed-up folders back.

## How it's built

- **Read-only, by design.** The test suite fails if any helper calls a buy, sell, train, choose-reward or targeting
  function. The single exception is AutoQuest, which may call the quest window's accept, complete and reward
  functions (`tests\test_autoquest.lua` checks its rules, and that no other helper calls them).
- **Safe with Blizzard's interface.** Helpers use Blizzard's official extension points: tooltip lines, minimap
  markers, the Settings panel, the addon menu and keybindings. They never replace or rewrite Blizzard's frames,
  functions or global tables, which is what causes "action blocked" (taint) errors.
- **World-map pins are our own frames.** They are drawn over the map, not added to Blizzard's map pin system:
  Blizzard's map code makes protected calls on every pin in that system, so in combat the game blocked it and blamed
  the addon. `research\taint_audit.md` records the audit of every helper for this kind of problem.
- **Built for Forever's client.** Forever runs on a modern client with Midnight-era addon rules. The combat log is
  closed to addons, and many values are hidden during combat or in instances, so every value a helper reads from
  the game goes through a check.
- **Forever's map numbers are the Classic ones** (Teldrassil 1438, Elwynn Forest 1429). Map lookups also check the
  map's name.
- **One source folder per helper.** Each folder in this repo is one helper with its own `.toc`. `build.ps1` groups
  them into the six installed addons; each helper stays its own Lua file, so they don't share local variables.

## Develop and test

The tests run outside the game, with Node.js and [fengari](https://github.com/fengari-lua/fengari) (Lua in
JavaScript) standing in for the game:

```powershell
cd tests
npm install
.\runall.ps1
```

`runall.ps1` runs every test and exits non-zero if any fails. To run one test:
`node run.js "<path to this repo>" test_builds.lua` (a few tests take a single file or folder instead of the repo
root; `runall.ps1` lists which). `validate.lua` and `syntaxcheck.lua` are helpers for checking a single route or Lua file.

`STATUS.md` has the current state of the work: what's done, what still needs checking in game, and what's next.

## Research and sources

Everything under `research\` is our own write-up: guide data, reviews of popular Forever addons, build research, and
the gaps we filled. Third-party addons were only studied, never copied: findings are described in our own words, and
no outside code is included here.

RestedXP was studied most closely:
- `research\rxp_deep.md` covers its engine and features.
- `research\rxp_forever_guides.md` covers its free Forever 1-20 guides: the Night Elf route, Skyborne and the gap
  table against LevelGuide.

Both were checked against RestedXP v4.11.35 (8 November 2026), its latest release. The package was downloaded into
a quarantine folder outside this repo and scanned for malware. It was read only: never run or installed.

Data sources include:

- **Quests and routes:** wow4ever.quest / Questie's Forever data, foreverchanges.pro, and Classic wikis for ordinary
  mob spots. Each route's header says which.
- **Professions:** Warcraft Tavern's Forever trainer list, metabot.gg's Forever recipe data, wow-professions.com, and
  classicdb.ch for item IDs.
- **Dungeons:** Warcraft Tavern's Forever dungeon guides and foreverchanges.pro.
- **Talent builds:** Warcraft Tavern, Icy Veins, Method, Mobalytics and RankedBoost Forever guides. Builds are listed
  as talent choices with a short summary in our own words, and each build records its source and the date it was
  checked.
- **Gold farms:** Wowhead Classic item and NPC pages, and Forever gold guides.

Forever launched in November 2026 and is still changing. Blizzard announced class tuning for 10 November 2026, so
builds and some data may need refreshing after patches.

## License

wowhelper is free software under the **GNU General Public License v3.0** (see [LICENSE](LICENSE)). You may use, copy, change and share it, as long as anything you publish from it stays under the same licence. The leveling guide's quest data comes from the GPL-3.0 Forever quest database (forever-db, from the Polestar project) and other open sources; [NOTICE.md](NOTICE.md) credits them all.

