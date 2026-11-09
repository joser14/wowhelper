# RXPGuides v4.11.35 — deep read-only reverse-engineering (for the Forever suite)

Scope: `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\RXPGuides` (1,405 files; ~1,100 are guide/locale/library data). Read only with Read/Grep/Glob and PowerShell listing/counting. Nothing was run, copied, changed or downloaded. No route content is reproduced here; premium-guide decryption was not attempted (only the mechanism is named in one line). Descriptions are in my own words; short identifiers/API names are quoted where they matter.

Compared against our `LevelGuide\LevelGuide.lua` (1,732 lines) plus `Routes.lua`, `QuestIDs.lua`, `Prereqs.lua`, and skimmed headers of the other suite helpers.

**Reading depth (honest):**
- Fully or near-fully read: `GuideLoader.lua`; the engine half of `functions.lua` (1–4,830, plus 4,845–5,060, 5,961–6,250, 7,391–7,460); `map.lua` (arrow/waypoints/pins); the core loop, step logic, quest automation and progress code in `RXPGuides.lua`; the step activation/completion and element-binding code in `GuideWindow.lua`; `Timers.lua`, `HSBatching.lua`, `Tips.lua`, `libs\compatibility.lua`; most of `LevelingTracker.lua`, `ItemUpgrades.lua` (scoring and AH analysis), `QuestLog.lua` (first 500 lines), `InventoryManager.lua` (junk logic), and `Targeting.lua` (scan logic).
- Read the relevant sections only: `SettingsPanel.lua` (defaults table, chat command, Guide Routing and Tips panels, plus a full extraction of option keys used anywhere), `DB\questDB.lua`, `DB\forever\db.lua`, and the structure of every `DB\forever\*.lua` file.
- Skimmed by function index only: `Talents.lua`, `Communications.lua`, `UI\V2\*` (Core, GuideConfigurator strings), `ActiveItemFrame.lua`, `CptStadicsVendorTreasures.lua`.
- Not read: `Themes.lua`, `Help.lua` and the locale files beyond what grep surfaced.

---

## 0. Load-time facts that matter for Forever

- The TOC lists `16001` among its interface versions. The per-flavor XML uses `[AllowLoadGameType camelot]` for Forever: `DB/forever.xml`, `Guides/GuideList-forever.xml`, Talents, ItemUpgrades and VendorTreasures.
- `RXPGuides.lua:204-207` sets `addon.game = "FOREVER"` when the client build is between 16000 and 20000, with max level 60.
  - Guides tagged `#forever` or `#classic` are both treated as compatible (`GuideLoader.lua:1171`).
  - On real Classic, `#forever`-only guides are demoted to the "unused" list (`lowPrio "*group"`).
- **Forever character names are first plus last name.** RXP builds `addon.player.name` from both returns of `UnitName("player")` (`RXPGuides.lua:253-256`).
  - Our `LevelGuide.lua:1690` keys characters by the first return only. That is fine unless two characters on one realm share a first name.
- **The Forever default quest-log size is 40** (`questLogSize` default; `SettingsPanel.lua:171`, `QuestLog.lua:26-27`). Our QuestCheck already reads `C_QuestLog.GetMaxNumQuestsCanAccept()`.
- Loading is time-sliced. RXP mentions "Lua scripts have a maximum run time of 200ms (HC only)" (`RXPGuides.lua:1352`) and spreads guide parsing over frames (`LoadEmbeddedGuides(start,25,…)`).
- Shipped Forever content (`Guides\GuideList-forever.xml`):
  - Speedrun "RestedXP Forever Guide (A/H)" covering 1–20/22, for every race start including **Skyborne / Zephras Isle**.
  - Mage AoE variants.
  - "Forever Dungeon Guide (A/H)" overlays. They are built with `#include` of the open-world guide plus `.enabledungeon RFC`-style toggles.
  - The Classic "Survival Guide" (hardcore) files and Attunements.
  - No Forever guides above roughly 22. Premium/imported guides arrive via the importer.

---

## 1. Full feature inventory (by area)

### 1.1 Slash commands and keybinds
- `/rxp`, `/rxpg` and `/rxpguides` (AceConsole, `SettingsPanel.lua:103-125, 310-312`) take these arguments:
  - `import`: guide importer
  - `debug`: toggle debug
  - `splits`: toggle the level-splits frame
  - `show`, `hide`, `toggle`: show or hide the addon
  - `bug` / `feedback`: bug report form
  - `preview`: frame previews
  - `help`
  - anything else opens settings
- Keybinds (`Bindings.xml`) are CLICK bindings:
  - "delete junk" button
  - 4 active-item buttons
  - 4 friendly-target buttons
  - 4 enemy-target buttons

### 1.2 Option keys (complete list from a code scan; defaults from `SettingsPanel.lua:127-257`)
- **Guide window / look:**
  - `windowScale` 1, `guideFontSize` 9, `anchorOrientation` "top", `lockFrames`, `hideGuideWindow`, `hideCompletedSteps`, `hideInRaid`
  - `frameHeight`, `framePositions`, `frameSizes`
  - `activeTheme` "RXP Blue", `customTheme`, `enableThemeLiveReload`
  - text colours `textEnemyColor/Friendly/Loot/Warn/Pick/Buy`
  - `showEnabled`, `standbyMode`
  - `enableMinimapButton`, `enableWorldMapButton`
  - V2 UI: `enableV2Interface` (false), `enableV2MenuTheme`, `activeStepsV2RenderQuestName`, `v2GuideWindowExpandedHeight`
- **Arrow / map:**
  - `disableArrow`, `arrowScale` 1, `arrowText` 9
  - `disableMapPins`, `numMapPins` 7, `worldMapPinScale`, `worldMapPinBackgroundOpacity` .35, `distanceBetweenPins`, `hideMiniMapPins`, `mapCircle`
  - `showTreasures`, `showRares`, `ignoreDuplicateRares`, `showDangerousMobsMap`
  - `enableVendorTreasure`, `vendorTreasurePinScale`
- **Routing:**
  - `enableXpStepSkipping` (true), `enableAutomaticXpRate` (true), `xprate` 1
  - `hardcore`, `season`, `phase` 6
  - `enableGroupQuests`, `soloSelfFound`
  - `dungeons{}`, `enableDungeons`, `professions`
  - `loremasterMode`, `northrendLM`, `chromieTime`
  - `disableAutoSkip`, `showUnusedGuides`, `loadAllGuides`, `preLoadData`, `multibox`, `enableBetaFeatures`
  - quest-prio: `questPrio`, `questPrioIndex`, `skipQuest`
  - TBC-only: `tbcStart`, `tbcTurnInOrder`, `tbcWBF`
- **Automation** (all of these are things we must NOT copy):
  - `enableQuestAutomation`, `enableGossipAutomation`, `enableFPAutomation`, `enableBindAutomation` (all default true)
  - `enableTrainerAutomation`
  - `enableQuestRewardAutomation`, `enableQuestChoiceAutomation`
  - `autoSellJunk`, `autoDiscardItems`
  - `rightClickJunk`, `rightClickMod`, `maxSoulShards`
  - `enableHSbatch`, `batchSize`
  - `gnomeTele`, `goblinTele`, `portalTele`
  - `createFollowMacro`, `macroAnnounced`
- **Targeting:**
  - `enableTargetAutomation`, `enableTargetMacro`, `enableMaxNameplateDistance` (writes the `nameplateMaxDistance` CVar)
  - `enableFriendlyTargeting/EnemyTargeting`, marking toggles, `enableTargetFrame`, `activeTargetScale`
  - `showTargetingOnProximity`, `scanForRares`, `notifyOnRares`
  - `soundOnFind` 3175, `soundOnFindChannel`, `flashOnFind`, `enableTargetingFlash`, `notifyOnTargetUpdates`, `hideActiveTargetsBackground`
- **Tips:**
  - `enableTips`, `enableTipsFrame`
  - drowning: `enableDrowningWarning`, `…Sound`, `drowningThreshold` .2, `enableDrowningScreenFlash`
  - emergency: `enableEmergencyActions`, `emergencyThreshold` .2, `enableEmergencyIconAnimations`, `enableEmergencyScreenFlash`
  - `showDangerousUnitscan`
- **Item upgrades:**
  - `enableItemUpgrades`, `itemUpgradeSpec`, `enableTotalEP`, `disableUpgradeTooltip`
  - `enableQuestChoiceRecommendation`, `enableQuestChoiceGoldRecommendation`
  - `enableItemUpgradesAH`
- **Talents:** `enableTalentGuides`, `previewTalents`, `hightlightTalentPlan`, `upcomingTalentCount` 5.
- **Tracker / comms:**
  - `enableTracker`, `enablelevelSplits`, `levelSplitsHistory` 10, `levelSplitsFontSize`, `levelSplitsOpacity`, `hideSplitsBackground`
  - `compareTotalTimeSplit`, `compareNextLevelSplit`, `openTrackerReportOnCharOpen`, `enableLevelingReportInspections`
  - level-up announce solo/group/guild
  - `enableFly/Collect/CompleteStepAnnouncements`, `announcements`
  - `shareQuests`, `shareActiveSteps`, `enableV2ActivePartyStepsFrame` and its scale/autosize/background
  - `checkVersions`, `alwaysSendBranded`
- **Misc:**
  - `enableInventoryManager`, `showJunkIcon`
  - `activeItemsScale`, `activeItemHideBG`, `disableItemWindow`
  - `showFlightTimers` (true)
  - `updateFrequency` 75 ms, `enableAddonIncompatibilityCheck`, `ignoreQuestieConflicts`, `debugQuestImport`

### 1.3 Modules
| Module | What it does | Automation? |
|---|---|---|
| Guide engine (`GuideLoader`, `functions`, `RXPGuides`, `GuideWindow`) | Parses the guide DSL, keeps the active step(s), evaluates elements on events, auto-advances | Yes: accept/turn-in/reward/gossip/FP/bind/trainer/buy |
| Map/arrow (`map.lua`) | HBD world pins, minimap pins, lines and loops on the world map, a waypoint arrow, corpse/spirit-healer arrow | No (hooks WorldMapFrame) |
| QuestLog (`QuestLog.lua`) | RXP button in the Classic quest log (which guides pick up / turn in this quest); orphaned-quest finder plus bulk abandon; "Item used in guide" tooltip | Abandon is a user-confirmed button |
| ActiveItemFrame | Secure buttons for active-step items/spells/macros (quest items, hearthstone) | User clicks secure buttons |
| InventoryManager | Junk detection, cheapest-junk delete when bags are full, vendor sell, quiver sort, soul-shard cap, auto-open containers, bag-addon adapters | Yes |
| ItemUpgrades | Stat-weight EP tooltips, upgrade ratio against equipped, quest reward pick, AH upgrade scanner | Tooltip/AH scan is info; reward pick is automation |
| Talents | Talent guides (`.talent tab,row,col,rank`), draws the plan on the Blizzard talent frame, preview/learn | Learns talents |
| LevelingTracker | Per-level time, quest vs mob XP by zone, solo vs group, deaths, XP/hr, splits window with comparison/export | Silences /played chat by replacing a global |
| Timers / HSBatching | LibCandyBar timers; flight timers; hearthstone "batching" bind trick | HS batching changes the `maxfps` CVar and confirms the bind |
| Tips | Drowning warning, low-HP "emergency" highlight of potion/racial on action bars, dangerous-mob/patrol map lines | Info (but draws on Blizzard bars) |
| Targeting | Target macro, follow macro, raid markers, active target frame, unitscan proximity by probing protected `TargetUnit` | Yes, plus a forbidden-action probe |
| Communications | Party addon comms (version, current step, quest share), level-up chat announcements, bug report | Sends chat |
| VendorTreasures | Map pins of vendors selling limited-supply items (Cpt. Stadics data, CC-BY-NC) | Info |
| questDB (`DB\questDB.lua`) | "Quest Priority / Preparation guide / Turn-in route" quest-log optimizer for TBC/boost prep guides (not used by Forever guides) | Info/config |
| UI v2 | New guide window, guide configurator wizard (Speedrun/Survival/Dungeon/Open-world/Endgame/Gold Assistant, dungeon selection), importer, active party steps frame | — |

---

## 2. Guide engine deep-dive

### 2.1 Guide file format
- Each guide is a Lua file that calls `RXPGuides.RegisterGuide([[ … ]])` with a text DSL. The file returns early on wrong faction, and when a localized copy exists for the client locale.
- **Header lines** (before the first `step`) are `#key value`; the first wins.
  - Seen in Forever files: `#forever`, `#disabledungeons`, `#name`, `#displayname`, `#version`, `#group`, `#subgroup`, `#groupid`, `#defaultfor <filter>`, `#next <name[;name2…]>` (optionally `group\name`), `#hardcore`/`#softcore`.
  - Also supported: `#groupweight`, `#subweight`, `#groupdisplayname`, `#title`, `#theme`, `#loop`, `#standalone`, `#internal`, `#chapter`, `#xprate`, `#season`, `#phase`, `#OnClick`, `#disablecaching`.
  - A bare `<< filter` line sets `enabledFor` for the whole guide.
  - A `+` prefix on the group marks a farm (Gold Assistant) guide.
  - `key = funcName` assigns the return value of a function.
- **Step lines** start with `step`, optionally followed by `<< filter`.
- **Per-line suffix `<< filter`**: the line is dropped unless the filter matches (`GuideLoader.lua:36-103, 991-995`).
  - Filter grammar:
    - `/` means OR between alternatives.
    - A space means AND.
    - `!` negates.
    - `( … )` groups.
  - Tokens can be:
    - a class (`Warrior`, `DK`)
    - a race (`Undead` is mapped to `Scourge`)
    - a faction
    - a number, meaning player level ≥ N
    - the game (`FOREVER`, `CLASSIC`, `SOD`, `DF`)
    - `Male`/`Female`
    - the locale
    - a custom predicate
  - Results are cached per string.
- **Element lines:**
  - `.tag args, comma, separated >> display text`: element; the text after `>>` replaces the auto text. `.target/.mob/.unitscan` split on `;`; `.link/.clicknext` take the whole rest.
  - `#steptag value`: step attribute.
  - `+text`: a manual objective with a tick box that the user checks.
  - `*text`: text only, no tooltip.
  - `>>text` alone: a text-only element.
- **Colour tokens** such as `|cRXP_FRIENDLY_…|r` and `|cRXP_ENEMY_…|r` are replaced with theme colours. `npc:Name:ID` and `Name::ID` are swapped for the localized NPC name, fetched through a hidden tooltip `unit:Creature-0-0-0-0-ID` hyperlink (`functions.lua:891-946`).
- **Coordinates:**
  - Forever guides mostly use **world coordinates**: `.goto 1411/1,-4251.46,-607.35`, meaning uiMapID/continent-instance, worldX, worldY.
  - These are converted to zone percent with HereBeDragons `GetZoneCoordinatesFromWorld` (`functions.lua:1923-1943`).
  - The classic form `zoneName,x,y` is also accepted. `addon.mapId` maps zone names to uiMapIDs, and `mapConversion` re-projects old city maps.
- **Stable step identity:** `step.stepId = linenumber + guideId`, where `guideId` is an Adler-32 of the guide key (`GuideLoader.lua:1192, 1207`). Saved progress uses `{step, stepId}`, so it survives reordering (`RXPGuides.lua:1412-1468`, `GuideWindow.lua:1908-1916`).
- **Tag frequencies** across all Forever guides (8,603 steps):
  - `.goto` 13,884
  - `.target` 4,545
  - `.accept` 2,441
  - `.turnin` 2,320
  - `.complete` 2,102
  - `.mob` 2,098
  - `.collect` 1,095
  - `.train` 804
  - `.itemStat` 795
  - `.xp` 755
  - `.isOnQuest` 695
  - `.itemcount` 687
  - `.use` 528
  - `.money` 437
  - `.vendor` 387
  - `.isQuestComplete` 360
  - `.zoneskip` 354
  - `.trainer` 268
  - `.skill` 257
  - `.isQuestTurnedIn` 257
  - `.waypoint` 256
  - `.subzoneskip` 246
  - `.isQuestAvailable` 167
  - `.fly` 130
  - `.fp` 73
  - `.hs` 82
  - `.deathskip` 82
  - `.home` 53
  - `.bindlocation` 62
  - `.dungeon` 67
  - …
  - Step tags: `#completewith` 2,341, `#optional` 1,403, `#label` 1,240, `#loop` 417, `#requires` 378, `#sticky` 221, `#softcore` 156, `#hardcore` 94, `#season` 89, `#ah` 71, `#ssf` 33, `#xprate` 32, `#include` 27.
  - The most common filters are class names and races.

### 2.2 Step/element vocabulary (every `addon.functions.*`)
Every tag function has two modes:
- called with a string: parse, and return an element table.
- called with an element frame: runtime update, triggered by the events in `addon.functions.events[tag]`, by the element's own `element.event`, or by the pseudo-events `WindowUpdate` and `TaskUpdate`.

The binding happens in `GuideWindow.lua:267-300`: each element frame registers its events and calls the function with `(frame, event, …)`.

**Quest tags**
- `.accept id[,flags,reqTurnIn]`
  - Complete when `IsOnQuest(id)` or turned in.
  - A 2-second "recent accept" grace covers server lag.
  - Flag 1 disables auto-accept. Flag 2 auto-completes if the given quest is not turned in.
  - With Questie loaded it shows missing prerequisites.
- `.daily` / `.acceptmultiple ids…` and `.dailyturnin` / `.turninmultiple ids…`: multi-quest versions.
- `.turnin id[,rewardIndex,flags]`
  - Complete when `IsQuestFlaggedCompleted`, with a 5-second "recent turn-in" grace, or on a `QUEST_TURNED_IN` match.
  - A negative id means "skip if not in the log"; a negative id with a reward value means "skip if not complete".
  - A reward index above 0 is the hard-coded reward pick.
  - Flag bit 1 disables auto turn-in.
- `.complete id,objIndex[,objMax,flags]`
  - Per-objective progress text from the quest log leaderboards.
  - Complete when the objective is finished, or `numFulfilled ≥ objMax`, or the quest is complete or turned in.
  - Flag 1 makes it text-only: if already complete, the **whole step is skipped**.
  - A negative id means skip if the quest is missing.
  - Objectives are cached in `RXPCData.questObjectivesCache`. Quests without objectives get a synthetic "Objective Complete" event objective; progress bars become 0–100.
- `.abandon`, `.disablequestautomation ids`, `.addquestitem item,quest`, `.questitemcount`, `.convertquest`, `.mirrorquest` (alternate IDs for one quest), `.acceptmap`, `.isQuestOffered` (gossip lists it).
- Conditional guards (skip the step when false): `.isOnQuest`, `.isNotOnQuest`, `.isQuestComplete`, `.isQuestNotComplete`, `.isQuestTurnedIn [account]`, `.isQuestAvailable`, `.questcount N[*] ids` (count of on/turned-in), `.skipOnQuest`, `.requires quest ids` (questDB).

**Movement / map tags**
- `.goto zone,x,y[,radius[,optional]]`
  - Draws an arrow and a map pin.
  - A positive radius makes the waypoint a real objective, completed within that many yards.
  - A radius of 0 makes it a "low priority" chain point. A negative radius makes it "dynamic": the arrow goes to the nearest of the set.
  - `optional` with a positive radius hides the pin.
  - World coordinates are accepted.
- `.groundgoto` / `.flygoto` apply only if you can or can't fly.
- `.waypoint zone,x,y,radius[,lowPrio|callback,events…]`: arrow without a pin. A negative radius makes it persistent and dynamic. A callback can change the priority.
- `.questwaypoint` / `.questgoto zone,x,y,radius,qid,objIndex,objMax`: hidden once an objective count is reached.
- `.wpradius zone,x,y,r`: activation radius for the previous waypoint, which is only shown within r of a reference point.
- `.pin` (pin without arrow), `.ingamewaypoint` (sets the Blizzard user waypoint plus supertrack).
- `.line zone,x1,y1,…` (patrol or route polyline), `.loop range,zone,pts…` (a grind circuit; the arrow cycles to the next or previous point).
- `.zone mapID|name` (complete on arrival), `.zoneskip map[+map][,flag]` and `.subzone` / `.subzoneskip areaID` (skip by location), `.explore area,zone`, `.areapoiexists`.
- `.treasure`, `.rare` (pins; a rare can complete from achievement criteria).

**Travel / hearth tags**
- `.hs`: complete on `UNIT_SPELLCAST_SUCCEEDED` of hearthstone spell 8690 (or Astral Recall 556). It also puts the hearthstone (item 6948) in the item bar.
- `.hsbatching`
- `.home [areaID]`: complete on `HEARTHSTONE_BOUND` or when `GetBindLocation()` equals the area name. Auto-picks the binder gossip and **auto-confirms the bind**.
- `.bindlocation areaID[,flag]`: skips the step if your hearth is or isn't there.
- `.fp name`
  - Complete when the node is known (`RXPCData.flightPaths`), or on `UI_INFO_MESSAGE ERR_NEWTAXIPATH`.
  - The zone is mapped to a node via `FPbyZone`, or the nearest FP by world position (`taxiPos`).
  - Auto-selects the taxi gossip.
- `.fly name`: picks the taxi gossip and **calls `TakeTaxiNode`**. Complete on `UnitOnTaxi` or `PLAYER_CONTROL_LOST`. Announces the ETA.
- `.deathskip`: the spirit-healer arrow; **auto-accepts the resurrection-sickness confirmation**. Marks the step softcore-only.
- `.hastyhearth`, `.flyable`, `.noflyable`, `.vehicle`, `.exitvehicle`.

**Item / character tags**
- `.collect itemId[,qty,questId,objFlags,flags,…]`. Flag bits:
  - 1: text only
  - 2: subtract the objective counts given in `objFlags` (bitmask of objectives)
  - 4: complete when the masked objectives are finished
  - 8: include the bank
  - 16: don't complete on turn-in
  - 32: subtract by profession skill
  - 64: requirement becomes 0 if you have none
  - Counts bags plus equipped plus toys, and parses `CHAT_MSG_LOOT` for quest items.
- `.collectmultiple`
- `.destroy item` (marks it as junk), `.itemcount ids,[<>=]N` (skip guard), `.itemStat slot,STAT|QUALITY|LEVEL,[<>]v` (skip guard on worn gear), `.equip`, `.use items` / `.usespell` / `.macro` (item, spell or macro bar), `.openitem`, `.bankdeposit`, `.bankwithdraw`, `.retrieveitem`.
- `.buy`, `.buyAll`, `.buyUntilBroke` (**auto-buy**), `.vendor [npcId]` (complete on `MERCHANT_CLOSED` from that NPC).
- `.trainer [npcId]` (complete on `TRAINER_CLOSED`), `.train spellId[,flags]` (complete or skip via `IsPlayerSpell`; also feeds the **auto-trainer**), `.istrained ids` (skip if any is known), `.spellmissing id`.
- `.skill name,[<]N[,skip]` / `.maxskill`, `.money [<>]gold[,networth]` (skip guard), `.reputation`, `.cooldown`, `.aura`, `.cast [unit,]+ids` (complete on cast success), `.tame`, `.stable`, `.petfamily`, `.engrave`, `.tradeskill`, `.mountcount`.

**Level / XP tags**
- `.xp L[+xp|.frac|-xp][,skip,label]`
  - Without the skip arg it is a "grind until" objective:
    - `L` alone means reach level L.
    - `L.f` means a fraction f into level L.
    - `L+N` means N XP into level L.
    - `L-N` means N XP short of level L.
  - With the skip arg it is a gate: if met, the step is skipped (`<L` reverses it).
  - With a label it **jumps** to that labeled step.
  - Progress shows as `(x/y)` (`functions.lua:3319-3441`).
- `.maxlevel L[,label]`: skip, or jump, when your level is above L.
- `.xpto60` / `.xpcheck` (Forever DB): an "XP still needed to 60 versus XP banked in completed quests" readout, and an auto-switch of guide.

**Targets and UI tags**
- `.target`, `.mob` and `.unitscan` take name or ID lists (`+` makes them conditional on the parent objective). They feed the macro, target frame, markers and proximity scan.
- `.link url`, `.clicknext guide`, `.timer`, `.countdown`, `.logout`, `.emote`, `.openmap`, `.disablecheckbox`, `.hideifcomplete`, `.showwhiledead`, `.label`, `.noop`.

**Content-gating tags**
- `.dungeon X`, `.enabledungeon X` (per-guide dungeon overrides), `.profession`, `.group`, `.solo`, `.pvp`/`.pve`, `.dmf`/`.nodmf`/`.holiday`, `.spec`/`.dualspec`, `.choose`, `.scrap`, `.chromietime`, `.skyriding`, achievement tags, currency tags, scenario tags, daily-hub tags, `.beta`, `.multibox` and related.

**Step `#` attributes**
- `#completewith next|label`: the step is "sticky" and stays active until the target step is passed.
- `#sticky`: stays active until its own elements complete. Its skip is remembered in `RXPCData.stepSkip`.
- `#requires label`: only activates after that step.
- `#label`, `#optional` (shown dimmed, never blocks), `#loop` (a waypoint loop; waypoints reset when done), `#include group\name[@from-to]` (splices another guide's steps).
- Filters:
  - `#hardcore`/`#softcore`
  - `#hardcoreserver`/`#softcoreserver` (`C_GameRules.IsHardcoreActive`)
  - `#season`, `#era`, `#som`
  - `#phase`
  - `#xprate <1.5`
  - `#ah`/`#ssf`
  - `#group`/`#solo`
  - `#dungeon`/`#dungeonskip`
  - `#profession`/`#professionskip`
  - `#fresh`/`#veteran`
  - `#questguide`/`#speedrunguide`
  - `#beta`
  - `#maxlevel`
  - `#level N`: the step activates only at level ≥ N.
- Display: `#title`, `#arrowtext`, `#tip` (floating tip window), `#track qid` (supertrack), `#hidewindow`, `#ignorecorpse`, `#map`, `#qremove`, `#stop`.

### 2.3 How a step is decided complete; how the guide advances
- `addon.SetStep(n)` (`GuideWindow.lua:755-975`) builds the active set:
  - Every earlier `#sticky` step that is not yet skipped, whose `#requires` is fulfilled and whose `level ≥ step.level`.
  - The current step, unless it is already completed or blocked by `#requires`.
  - Its `#tip` window.
  - If nothing is active, it moves to n+1, or loads `#next` at the end.
- `UpdateStepCompletion` (`GuideWindow.lua:677-753`) runs when anything sets `addon.updateSteps`.
  - A step is complete when **every element is `completed`, `skip` (the user ticked it) or `textOnly`**, or when its `#completewith` target has been passed.
  - A completed sticky step is recorded in `stepSkip`. A completed current step sets `loadNextStep`, and the ticker moves to n+1.
  - "Skip" guards (`isOnQuest`, `xp` with a skip arg, `zoneskip`, `itemcount`, `money`, `bindlocation`, …) set `step.completed = true` directly.
  - `addon.nextStep = labelIndex` jumps (used by `.xp`/`.maxlevel` with a label).
- **Out-of-order handling** is mostly author-driven:
  - Steps behind the pointer are never re-evaluated except stickies.
  - Steps ahead complete instantly as you reach them: `.accept` completes if the quest is already in the log or turned in, `.turnin` if flagged, `.complete` if turned in.
  - Authors add guard tags so a step skips when its quest is missing or done.
  - `disableAutoSkip` turns those guards off.
- **Level gating:**
  - Steps can carry `#level`.
  - `.xp` defines grind targets.
  - With `enableXpStepSkipping`, `.xp …,skip` and `.maxlevel` skip steps you have outleveled. `LevelCheck` hides whole steps or guides above `#maxlevel`.
  - Guides and steps can also depend on `#xprate` (the detected XP buff rate).
- **Choosing the next guide:**
  - `#next a;b;c`: the first one that is `IsGuideActive` wins.
  - That check covers season, phase, XP rate, account freshness, level, loremaster and beta, plus hardcore/softcore consistency (`functions.lua:3858-3967`, `GuideWindow.lua:2412-2428`).
  - At level 1 the start guide is the group's `#defaultfor` guide that applies to your race (`GuideLoader.lua:966-975`).
  - Otherwise the user picks in the menu or the V2 configurator wizard.
- **Quest progress:**
  - `GetQuestObjectives` reads leaderboards. A step at least 4 away from the current one uses the SavedVariables cache.
  - Quest names come from Questie when present, then the log, then `C_QuestLog.GetTitleForQuestID`/`GetQuestInfo` after `HaveQuestData`.
  - Server requests are throttled to 3 per 1.5 s, with a 3-second wait per ID (`functions.lua:586-747`).
  - Inactive steps refresh at most 3 per 16 ticks (`RXPGuides.lua:2418-2444`).
- **IDs versus names:** IDs drive everything; text is only display (`*quest*` is replaced by the fetched title). `questConversion` remaps IDs per game, and `mirrorID` lists alternate IDs.
- **Prerequisites:** only through Questie (`db:IsDoable`, `GetRequiredQuests`) as an informative "Missing pre-requisites" tooltip with a red X icon. It never auto-skips (that code is commented out).
- **Item collection:** item counts (bags, bank, equipped, toys) against a required amount, adjusted by quest objective counts or skill. Loot chat marks quest items.
- **Known flight paths:**
  - On every `TAXIMAP_OPENED`, `C_TaxiMap.GetAllTaxiNodes(mapID)` records each node whose state isn't `Unreachable` into `RXPCData.flightPaths[nodeID]=name` (`Timers.lua:189-214`).
  - Discovery also comes from the `ERR_NEWTAXIPATH` UI message mapped by zone or nearest node.
  - Flight time comes from the static `FPDB[faction][src][dest]` seconds. Multi-hop routes are summed per leg, using `TaxiNodePosition` hashes and `GetNumRoutes`/`TaxiGetDestX/Y`.
  - Shown as a candybar timer and a tooltip line on taxi buttons (via a hook).
- **Hearthstone:** `GetBindLocation()` compared with `C_Map.GetAreaInfo(areaID)`; `HEARTHSTONE_BOUND`; `UNIT_SPELLCAST_SUCCEEDED` 8690.

### 2.4 Arrow and waypoint chain (`map.lua`)
- **Which waypoints exist** (`generatePins`, 601-737):
  - Elements with coordinates from the active steps, then the following steps until `numMapPins` is reached.
  - Each gets a `wpHash` (coordinates plus step plus element order).
  - Waypoints already reached are remembered per step in `RXPCData.completedWaypoints`, so a reload doesn't send you back.
- **Arrow target** (`updateArrowData`, 1023-1146):
  - The first waypoint in the active list that is not low priority, not reached, and whose parent objective is not done.
  - Otherwise the first low-priority waypoint.
  - If dead (ghost), it goes to the **corpse** (`C_DeathInfo.GetCorpseMapPosition`). On `.deathskip` steps it goes to the **nearest spirit healer** from `SpiritHealerWorld` (world coordinates per continent).
  - `#loop` steps reset their waypoints when all are reached.
- **Each tick** (`UpdateGotoSteps`, 1222-1473):
  - Player world position comes from `HBD:GetPlayerWorldPosition`.
  - If the target is on another continent the arrow shows "~" and chat prints a notice once.
  - The arrow is hidden in instances.
  - Waypoints with a radius are marked reached inside that radius. Quest waypoints also require the objective count to have gone up.
  - "Dynamic" sets keep only the nearest one active.
  - `.loop` circuits pick the next or previous point by which is closer and enforce a max-distance reset.
- **Drawing** (`DrawArrow`, 102-170):
  - `HBD:GetWorldVector` gives angle and distance; the texture is rotated by angle minus `GetPlayerFacing()`, only when the change is above π/64.
  - The label shows the step's `#arrowtext` or title, then the step number and distance in yards.

### 2.5 Comparison with our LevelGuide.lua: what we lack or do worse
Our model differs. We build the route live (`BuildSteps`, `LevelGuide.lua:1203-1243`):
- A hand-written per-zone route (A/D/T/G, `Routes.lua`) is merged with the quest log and the map's "!" offers.
- It is reordered inside a 10-step window by nearest-neighbour cost, with turn-in/pick-up/XP biases (`Route`/`Cost`, 286-340; window 1005-1066).
- Pick-ups are gated by Prereqs.lua, map offers and remembered NPC offers (591-718).

That is **more adaptive than RXP's linear pointer** for out-of-order play. RXP's advantage is the expressiveness of its steps:

| Point | RXP | Ours (file:line) | Gap |
|---|---|---|---|
| Quest identity | Numeric ID on every element; title only for display | Matched by **title** (`LogByTitle` 364-395, `InLog` 425), IDs only where `QuestIDs.lua` lists them; chains use "part" counting from the turn-in count (`TurnedIn` 434-452, `HeldPart` 455-461) | Renamed or duplicate titles and part counting are fragile. `charData.done` counts by title, so a quest done on another route with the same title confuses it |
| Step identity / progress | `stepId` = line + guide hash; progress saved by stepId | Skips and visits keyed `zone#index` (`RouteKey` 414-416) | **Inserting a step in Routes.lua shifts every later key**, so saved skips and visits land on the wrong steps |
| Objective granularity | `.complete id,obj[,max]`: separate steps per objective, each with its own location | "do" is done only when the whole quest is ready (640-642); the detail shows the first unfinished objective (138-145) | Can't route "kill 5 here, then the item there" as two stops, or "do 8 of 10, finish later" |
| Waypoints | Many per step; radius objectives, low-priority chains, dynamic nearest, persistent, loops; reached state persisted | One x,y per step; "go" visited within 12 yd (`ARRIVED_YARDS` 7; 1519-1526) | No paths around cliffs, no grind circuits, no "nearest spawn of N" |
| Coordinates | World coords via HBD; any sub-map | Map percent; only a hard-coded Darnassus city→zone conversion (`CityToZone` 760-812) | Other cities, caves and buildings need hand fixes |
| XP gates | `.xp` grind-to-X% / XP-into-level; skip/jump if outleveled; `.maxlevel` | Fixed `OUTLEVELED=4` (16, 618) and `LevelBlocker`/`LevelStep` "needs level N" (879-958) | No authored "grind to 40% of 11 before leaving", no per-step outlevel threshold |
| Class/race/faction | `<<` filters per line and step; separate guides per race/class | Route chosen by race (`FindRoute` 899-902); class quests explicitly left out (Routes.lua header) | No class quests or class trainer stops |
| Utility steps | `.hs`, `.home`, `.fp`, `.fly`, `.train`, `.trainer`, `.vendor`, `.zone`, `.collect`, `.money`, `.bindlocation` with read-only completion detection | Chores only as one "Also:" line from other helpers (`ChoresText` 1245-1261, `CHORES` 27) | The route can't say "set hearth here", "grab the FP", "hearth now", "fly to X", "train at 10" in order |
| Conditional guards | `isOnQuest`, `isQuestTurnedIn`, `itemcount`, `zoneskip`, … skip whole steps | Implicit in `RouteStepDone` (591-644) | Can't express "only if you looted the item-start quest" |
| Sticky / parallel | `#completewith`/`#sticky`: e.g. "kill boars while doing the next 3 steps" | Single current step plus 3 next rows (`MAX_NEXT` 4) | No "do X on the way" overlay |
| Server lag | 5 s turn-in / 2 s accept grace | `QUEST_TURNED_IN` increments `done` (1707-1714) and IDs via flagged-completed | We already handle the turn-in; we could flicker after accept before the log updates |
| Prereqs | Questie-only tooltip | `Prereqs.lua` + map offers + NPC offer memory (520-543, 579-611, 655-696) | **Ours is better.** But we don't show *which* prereq is missing |
| Guide chaining | `#next a;b` with filters; `#defaultfor` | `FindRoute` by race and level range, "stuck here" logic (899-933) | **Ours is better** for mid-level pickup. No class-specific route branches |
| Skip UX | Tick boxes per element; right-click "Go to step"; full scrollable step list; sticky skips persisted | Shift+right-click skip with undo stack (1302-1347, 1399-1411) | No full route view, no "jump here", no per-element manual tick (`+` manual objectives) |
| Map pins | Next N steps on world map and minimap, merged when close | Only a user waypoint plus supertrack on click (`MarkStep` 1283-1300) | No overview of upcoming stops |
| Ghost | Corpse arrow / nearest spirit healer | Arrow keeps pointing at the step | Small but valuable |
| Wrong continent / instance | "~" plus notice; hidden in instances | Arrow hidden when not on the step's map (1512-1516); travel shows "other zone" | Fine |
| Turn-in level-up / XP banked | Only special `.xpto60` | `MarkLevelUp` (1140-1155), "+N% ready to turn in" (1157-1165, 1429-1432) | **Ours is better** |
| Timed quests | — | `PutTimedFirst` (1168-1201) with warnings | **Ours is better** |

### 2.6 Ranked LevelGuide improvements (read-only, own frames)
1. **(S) Stable step keys.** Replace `zone#index` with an explicit `id` field per route step, or a hash of `t|q|part|npc`. Migrate saved `skips`/`visited` once. This is a correctness fix: today any edit to Routes.lua re-maps old skips (`LevelGuide.lua:414-416, 593, 1313`).
2. **(M engine, L data) Quest IDs as the primary key.** Store `id=` on every A/D/T step (QuestIDs.lua already holds many). Drive `InLog`/`HeldPart`/`TurnedIn` by ID: `C_QuestLog.IsOnQuest`, `IsQuestFlaggedCompleted`, `GetLogIndexForQuestID`. Keep the title only for display. Removes "part" counting and rename tables, and fixes cross-route title collisions. Add RXP-style 2 s accept / 5 s turn-in grace caches.
3. **(S) Objective-level "do" steps.** An optional `obj=` (index) and `max=` on D steps. Done when `GetQuestObjectives(id)[obj].finished` or `numFulfilled ≥ max`. This lets a route split one quest into several stops and reorder them.
4. **(M) Multi-waypoint steps.** Allow `pts={{x,y,r},…}` with:
   - a mode of `path` (in order), `nearest` (dynamic), or `loop` (grind circuit, next/prev by distance);
   - auto-advance within the radius;
   - reached points persisted per step key.
   Our arrow already computes yards; it only needs the active point.
5. **(M) Utility step kinds with passive completion.** None of these click anything:
   - `home` (done when `GetBindLocation()` equals the name, or `HEARTHSTONE_BOUND`)
   - `fp` (done when `C_TaxiMap.GetAllTaxiNodes` on `TAXIMAP_OPENED` shows the node not Unreachable, or `UI_INFO_MESSAGE` `ERR_NEWTAXIPATH`)
   - `hearth` (`UNIT_SPELLCAST_SUCCEEDED` 8690)
   - `fly` (`UnitOnTaxi`/`PLAYER_CONTROL_LOST` after `TAXIMAP_OPENED`)
   - `train` (`IsPlayerSpell` of listed IDs, or a TrainerNotes summary)
   - `vendor`/`trainer` (`MERCHANT_CLOSED`/`TRAINER_CLOSED` with an NPC ID from `UnitGUID("npc")`)
   - `zone` (map ID reached)
   - `collect` (`C_Item.GetItemCount` ≥ N)
6. **(S) XP-gate steps.** `X(level, frac|+xp|-xp, note)`: "grind to 40% into 11 here", shown with live `(cur/target)`. Plus a per-step `outlevel=` override for `OUTLEVELED`, and "skip if level ≥ L". Both reuse `UnitXP`/`UnitXPMax` (already Safe-wrapped).
7. **(S engine, M data) Filters and guards on steps.** `cls=`, `race=`, `faction=`, `ifOnQuest=`, `ifDone=`, `ifItem=`, `ifNotZone=` evaluated in `RouteStepDone`. This unlocks class-quest stops (Warrior/Paladin/Hunter pet, etc.), which Routes.lua currently omits.
8. **(S) Ghost arrow and missing-prereq names.**
   - When `UnitIsGhost("player")`, point at `C_DeathInfo.GetCorpseMapPosition(map)` (Safe-wrapped).
   - In the pick-up tooltip, list the unmet Prereqs.lua quests by title (we already have IDs).
   - Optionally add a static spirit-healer table later.
9. **(M) Route list window.** A scrollable view of the active route with done/skipped/pending states, from ForeverHub or the header. Click to make a step current (a "focus" override), Shift-click to skip or unskip. Also a user tick-box for authored manual objectives (`+text`-style notes).
10. **(M) World-coordinate support plus our own map pins.**
    - Store optional world coordinates or a `map=` sub-map ID per step, converted generically with `C_Map.GetWorldPosFromMapPos`/`GetMapPosFromWorldPos`. This removes the special Darnassus case.
    - Render the next 5–7 stops as **our own** pins: a `WorldMapFrame:AddDataProvider` with our pin template, which is a provider registration rather than a hook, plus minimap-style text in our window. Check that this is acceptable under the "no hooks" rule before shipping.
    - Optional sticky overlays (an RXP `#completewith`-style "on the way: kill boars") belong here or in #7.

---

## 3. Non-guide features worth rebuilding read-only

| # | Feature (RXP source) | How RXP does it | Read-only rebuild on Forever | Feasibility / risk | Our helper | Size |
|---|---|---|---|---|---|---|
| 1 | **Level splits + XP-source report** (`LevelingTracker.lua`) | Per level it stores quest XP by zone and quest from `QUEST_TURNED_IN` xpReward, mob XP by zone from `CHAT_MSG_COMBAT_XP_GAIN` (lines starting "You" excluded), group XP, deaths, and start/finish `/played` times via `RequestTimePlayed`. Its report shows time per level, quests vs killing %, solo vs group %, zone %, XP/hr and deaths. The splits window compares each level and the total against a saved run (green/red deltas) and can export | Same data into LevelLog. Session XP/hr from `PLAYER_XP_UPDATE` deltas over `GetTime()`, and ETA to ding = remaining / rate. Compare against your best character | `CHAT_MSG_COMBAT_XP_GAIN` text may be secret; RXP checks `IsSecretValue(text)`. If secret, fall back to `PLAYER_XP_UPDATE` minus quest XP. `RequestTimePlayed` prints to chat; RXP silences it by **replacing `ChatFrame_DisplayTimePlayed`**, which is not allowed for us. Use session timers plus one login request | LevelLog | M |
| 2 | **Flight-path tracker + flight ETA** (`Timers.lua`, `functions.lua` `.fp`) | `TAXIMAP_OPENED` → `C_TaxiMap.GetAllTaxiNodes(mapID)` (`Enum.FlightPathState`) records known nodes; `FPDB` static seconds; per-leg summing | Record known nodes per character. Show "FPs not yet learned in this zone/continent" and "nearest unknown FP". Learn flight times ourselves: `TakeTaxiNode` can't be hooked, so stamp the time on `PLAYER_CONTROL_LOST` while `UnitOnTaxi` and record destination on `PLAYER_CONTROL_GAINED` | Fully read-only. We need our own node-name→map table, or learn it from the taxi map | Landmarks (flight masters) | M |
| 3 | **Dangerous mobs / elite patrols** (`Tips.lua` + `DB\forever\dangerousMobs.lua`) | Per faction→zone→mob: Min/MaxLevel, classification, movement (patrol/idle), notes, plus `.line` patrol paths / `.mob` names. Shown only while the mob's MaxLevel ≥ your level − (1 normal / 3 elite). Draws lines on the map; can add to the unitscan list | Our own static table of dangerous NPCs (elites, patrols, runners) with patrol points. Show in a zone panel or our pins. On `NAME_PLATE_UNIT_ADDED`/target/mouseover, if the NPC ID from `UnitGUID` matches, flash our own frame and play a sound. Drop entries as you outlevel them | Names/GUIDs can be secret in combat (`issecretvalue` guards). Data entry is the cost | DeathNotes / RareWatch | M (L with data) |
| 4 | **Drowning / breath warning** (`Tips.lua:72-115`) | `MIRROR_TIMER_START("BREATH")` with rate < 0 starts tracking; polls `GetMirrorTimerProgress("BREATH")`; warns below a threshold with screen flash, sound and `FlashClientIcon` | Same, flashing **our** frame (or a full-screen overlay of our own) plus a sound. Also cover the `EXHAUSTION` fatigue timer | Not secret; trivial | New "DangerWatch" or RestGuard | S |
| 5 | **Quest reward recommendation** (`RXPGuides.lua:880-1033`) | On `QUEST_COMPLETE`, for each choice: EP comparison against worn gear (best ratio, and 10× when filling an empty slot) and best sell price; icons drawn on the Blizzard reward buttons; optional auto-pick | Same evaluation with ItemAdvisor's score, shown in **our** small popup near the screen edge ("Best upgrade: #2 (+14 EP); best vendor: #3 (1s 20c)"). Add a TooltipDataProcessor line when hovering a reward | `GetQuestItemLink("choice",i)`, `GetQuestItemInfo` are fine. Must not touch Blizzard reward frames | ItemAdvisor | S |
| 6 | **"Item used in quest/route" tooltip + orphaned quests** (`QuestLog.lua:373-415`, 454-496) | TooltipDataProcessor item post-call: if the item ID is a route quest item, list the guide(s). Orphans: simulate the guide's expected log; log quests not in it are "orphaned" | Tooltip line: "Needed for <quest> (LevelGuide step)" from route plus quest objectives. A QuestCheck/QuestTracker section "not on your route / gray": the user abandons them manually | Read-only; TooltipDataProcessor allowed | QuestCheck, QuestTracker, ItemAdvisor | S |
| 7 | **Hearthstone bind awareness** (`.home`/`.bindlocation`/`.hs`) | `GetBindLocation()`, `HEARTHSTONE_BOUND`, `UNIT_SPELLCAST_SUCCEEDED` 8690 | Show "Hearth: <inn>" plus hearthstone cooldown (`C_Container.GetItemCooldown(6948)`) in ForeverHub. Remind "your hearth is in X, the route's next hub is Y; bind here?" when you talk to an innkeeper (`GOSSIP_SHOW` with an innkeeper NPC ID) | Trivial and safe | RestGuard / Landmarks | S |
| 8 | **Trainer spell schedule** (`DB\forever\spells.lua` `defaultSpellList[race/class][level]`) | Per-level lists of spells to buy; used for auto-training | Static per-class/level table ("at 10: X, Y; cost") plus `IsPlayerSpell` → "N new spells waiting" before you visit a trainer. TrainerNotes already reads the trainer window, and this adds a forecast | Data needed for Forever (it has new spells/runes?); read-only | TrainerNotes / TalentNudge | M |
| 9 | **Flight-timer bar + "current step" ETA** | LibCandyBar bars | Our own status bar in ForeverHub while on a taxi (from #2) | — | Landmarks | S |
| 10 | **Low-HP emergency hint** (`Tips.lua:122-143`) | Below 20% HP, highlights potion/healthstone/racial **on Blizzard action bars** | Our own frame: "You have: Healing Potion ×3, Bandage" | `UnitHealth` is secret in combat on this client; RXP just bails when secret. Low value here | ReadyCheck/SpellReady | S (low value) |
| 11 | **Vendor treasures pins** (`CptStadicsVendorTreasures.lua`) | Static list of limited-supply vendor items (gear/potions) per zone and NPC, as map pins | Our pins or a zone list, "rare vendor item nearby" | Data licence is CC-BY-NC; would need our own data | Landmarks | M |
| 12 | **Junk value / bag-full hint** (InventoryManager) | Grays plus a user discard list; cheapest stack = (stackMax+count)·price/2 | Show "cheapest junk to drop" in BagCheck; never delete | Read-only | BagCheck | S |
| 13 | **AH upgrade scan** (ItemUpgrades.AH) | `QueryAuctionItems` for usable greens in L−5..L per category; best ratio per slot and best "EP per copper" (budget) | Only on the user's button press inside our own frame. It is an AH query, not gameplay automation. Note the Midnight-era AH API may differ on Forever | Medium risk/API uncertainty | PriceMemory / ItemAdvisor | L |
| 14 | **Group XP share** (Communications) | Tallies XP gained while grouped per party member | Not needed | — | — | — |

---

## 4. Techniques for this client (Forever, interface 16001, Midnight API)

- **Secret values:**
  - A thin `IsSecretValue = issecretvalue and issecretvalue(v)` wrapper (`libs\compatibility.lua:3-5`).
  - `GetUnitName` returns nil for a secret name (`:7-13`), and RXP aliases `UnitName` to it in functions.lua/LevelingTracker.
  - Aura reads are skipped entirely when `C_Secrets.ShouldAurasBeSecret()` (`functions.lua:48-82`, `SettingsPanel.lua:3738`).
  - Health, cooldown start/duration (`functions.lua:6388-6400`), raid marker index (`Targeting.lua:532`), XP chat text (`LevelingTracker.lua:203`) and NPC tooltip names (`functions.lua:906`) are all checked.
  - Our `Safe()` pattern is equivalent; keep applying it to every API return.
- **API shims:** local aliases with C_ first and the global as fallback:
  - `C_AddOns.LoadAddOn`, `C_Item.GetItemInfo/GetItemStats/GetItemCount`, `C_Spell.*`, `C_SpellBook.IsSpellKnown`, `C_Container.*`
  - `C_MerchantFrame.GetItemInfo`, whose table return is unpacked (`functions.lua:24-32`)
  - `C_Reputation.GetFactionDataByID` wrapped as `GetFactionInfoByID`
  - `C_GossipInfo` option and quest selection by ID
  - `C_EncodingUtil` base64/compress, falling back to LibDeflate
  - `C_PlayerInteractionManager` instead of `ConfirmBinder`/`AcceptXPLoss`
  - **`C_EventUtils.IsEventValid(name)`** gates optional events such as `UNIT_QUEST_LOG_CHANGED`, `STOP_MOVIE` and `GOSSIP_CONFIRM` (`functions.lua:108-218`). Our pcall around `RegisterEvent` (`LevelGuide.lua:1677-1683`) does the same job.
- **Flavor detection:**
  - `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` marks Forever (`functions.lua:259`, `RXPGuides.lua:585`).
  - Build number 16000–19999 maps to "FOREVER".
  - `C_GameRules.IsHardcoreActive()` for HC realms.
  - `C_Seasons` for seasons.
- **Forever specifics found in code:**
  - First plus last names.
  - Quest log size 40.
  - Forever trainers reorder after each purchase, so RXP buys back-to-front (`RXPGuides.lua:629-635`).
  - On Forever, pet trainers share the trainer frame; RXP detects them by the trainer title equalling the pet's name.
  - The resurrection debuff "Chill of the Grave" (spell 418460) fires through `UNIT_SPELLCAST_FAILED_QUIET` (comment, `functions.lua:2927`).
  - Raid markers can't be set automatically on Forever (`Targeting.lua:56, 530`).
  - **Since 1.15.8 `TargetUnit` fires `ADDON_ACTION_FORBIDDEN` on execution**, so RXP's rare/unitscan proximity probing is disabled on Forever (`DB\forever\rares.lua:7-10`).
  - **Classic talent guides are inert on Forever**: every `classic-*.lua` returns unless `addon.game == "CLASSIC"`. Forever uses trait-currency talents (our TalentNudge reads `C_ClassTalents`/`C_Traits`), so RXP's `GetTalentInfo`/`LearnTalent` model doesn't fit here.
- **Map coordinates:**
  - HereBeDragons-2.0 world coordinates (instance plus world X/Y) for everything: pins, distance, arrow angle (`GetWorldVector`), cross-zone and continent checks.
  - Guides author world coordinates directly as `mapID/instance,wx,wy`.
  - `C_Map.GetWorldPosFromMapPos(zone, Vector(0,0))` detects the instance a map belongs to.
  - Linear coefficient transforms re-project old Stormwind/EPL coordinates (`map.lua:1475-1514`).
  - We already derive yards from `GetWorldPosFromMapPos` corners (`LevelGuide.lua:65-87`), the same idea without the library. Generalizing to world coordinates would fix sub-maps.
- **Taxi nodes:**
  - `C_TaxiMap.GetAllTaxiNodes(mapID)` with `nodeID`, `slotIndex`, `state` (`Enum.FlightPathState.Current/Reachable/Unreachable`).
  - Nodes are hashed by `TaxiNodePosition(slot)` so taxi-map indices map to node IDs.
  - Hops come from `GetNumRoutes(index)` + `TaxiGetDestX/Y(index,hop)`.
- **Quest data loading:**
  - `HaveQuestData(id)` (C_QuestLog) before reading titles and objectives.
  - At most 3 requests per 1.5 s.
  - Objective text that starts with a space or is empty counts as "not loaded"; retry.
  - `QUEST_DATA_LOAD_RESULT` refreshes.
- **NPC names:** a hidden-tooltip `SetHyperlink("unit:Creature-0-0-0-0-<id>")` read of line 1, cached, with a secret guard. For us, `C_TooltipInfo.GetHyperlink` gives the same without touching GameTooltip.
- **Performance:**
  - A single ticker (default 75 ms, ×1.5 on HC) round-robins work across cycles: arrow/goto every 4th tick, map/automation, tasks, inactive-quest refresh every 16th, text every 32nd.
  - Frame-time budgets during guide parsing.
  - A `ScheduleTask` debounce map keyed by function. Comparable to our dirty-flag debounce (`LevelGuide.lua:45-47, 1560-1571`).
- **Things RXP does that our rules forbid (so we copy nothing of them):**
  - `hooksecurefunc` on WorldMapFrame, TaxiNodeOnButtonEnter, TakeTaxiNode, UseContainerItem, UseAction, QuestLog_SetSelection.
  - `HookScript` on GameTooltip, PlayerTalentFrame, StaticPopups and bag frames.
  - Replacing `ChatFrame_DisplayTimePlayed`.
  - `UIParent:UnregisterEvent("ADDON_ACTION_FORBIDDEN")` and hiding StaticPopups.
  - CVar writes (`nameplateMaxDistance`, `maxfps`, `scriptErrors`, `previewTalents`).
  - Creating and editing macros, `SetRaidTarget`.
  - `TargetUnit` probing.
  - All quest/gossip/taxi/bind/trainer/merchant/delete automation.

---

## 5. Short answers to "what's worth taking"

- **Engine:** stable step IDs; quest IDs everywhere; objective-level steps; waypoint paths/loops; utility step kinds with passive detection; XP gates; class filters and guards; ghost arrow; route list view; our own map pins.
- **Side features:** level splits + XP-source report; FP tracker + flight ETA; dangerous-mob warnings; drowning/fatigue alert; quest-reward recommendation popup; "needed for quest" tooltip and orphan list; hearth bind panel; trainer forecast.
- **Techniques:** `IsEventValid`-gated events, secret guards on names/auras/health/cooldowns, world-coordinate math, `C_TaxiMap` node state, throttled `HaveQuestData`, ticker round-robin.
