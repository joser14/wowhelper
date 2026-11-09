# wowhelper

A suite of helper addons for **World of Warcraft: Forever** (client 1.60.1, interface 16001), built for a solo
leveling player. Everything is gathered in one window, the **Forever Hub**, with a small side panel that only shows
what needs doing right now.

The helpers **only show information**. They never play for you: no auto-selling, auto-buying, auto-accepting or
turning in quests, auto-equipping, auto-training or casting. That keeps them within Blizzard's terms of service.

> Status: early. Every helper is covered by automated tests, but the suite has only just been installed in game.
> Expect rough edges, and check the hub's **Errors** page if something looks wrong.

## What's in it

The 30-odd helpers are installed as six addons:

| Addon | Helpers | What you get |
|---|---|---|
| **Forever Hub** | ForeverHub, ForeverHelper, ErrorLog | The main window: a Home page explaining every helper, a Manage page to switch helpers or whole addons on and off, a side panel (XP and gold rates, time to level, XP waiting in finished quests), pop-up history, an error log, keybindings, an entry in the minimap's addon menu, an Options page, alerts and a hearthstone button. |
| **Forever Guides** | LevelGuide, ProfessionGuide, ProfessionCap, GoldGuide, GoldGoal, Dungeons | A step-by-step leveling route with an arrow, built from Forever quest data; profession guides from 1 to 300 for all 12 professions; gold farms for your level and professions; a riding or custom gold goal; a guide to the 35 dungeons, Forever's new ones included. |
| **Forever Quests** | QuestTracker, QuestCheck, ZoneLevels, QuestMobs | A cleaner quest tracker, quest log checks, zone level warnings, and markers with progress (like 3/8) beside enemies you still need. |
| **Forever Bags** | ItemAdvisor, BagCheck, ItemFinder, PriceMemory, FoodCheck, SupplyWatch, DurabilityWatch, Tooltips, WindowBadges | Equip, keep, sell or auction advice on every item; item search across all your characters; auction prices remembered from your own searches; extra tooltip lines (vendor price, last auction price, how many you own, where it drops, which quest needs it); badges on vendor, trainer and quest-reward windows; food, supplies and repair warnings. |
| **Forever Character** | Builds, TalentNudge, TrainerNotes, ReadyCheck, WeaponSkillWatch, RestGuard, LevelLog, RepWatch | Talent builds for all nine classes (leveling, PvP, tank, healer, damage) with the next talent to take; old spell ranks on your bars and missing buffs; trainer reminders; weapon skill, rested XP, level times and reputation. |
| **Forever World** | Landmarks, MapPins, DeathNotes, RareWatch | Remembers vendors, inns, flight masters, mailboxes, banks and trainers you visit and finds the nearest; pins on the world map and minimap; remembers where you died and warns when you walk back; rare sightings and a layer estimate. |

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
  function.
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
