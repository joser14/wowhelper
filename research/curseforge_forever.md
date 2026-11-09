# WoW Forever addon landscape on CurseForge (survey, 2026-11-09)

Read-only research: pages read as text, nothing downloaded.

## How CurseForge files Forever
- Forever is its own flavor: filter `gameVersionTypeId=88568`, game version string "1.60.1" (interface 16001).
- Browse: https://www.curseforge.com/wow/search?page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568
- Many authors ship a separate `-forever` file (Leatrix Plus, ThreatClassic2, Shortest Path).
- Kami-Labs keeps the most complete compatibility list: https://kami-labs.fr/en/addons-wow-forever/

## Platform limits that matter to us
Forever runs Midnight-era addon rules: `COMBAT_LOG_EVENT_UNFILTERED` is closed to addons, and health, power, auras, casts,
cooldowns, threat and names are secret values in restricted content and often in combat. Bags, merchant, quest log,
map, saved data and settings are unaffected. Damage meters read `C_DamageMeter`.
Source: https://wow-midnight-addon-template.vercel.app/midnight/

## Most used addons with Forever support

| Addon | Popularity | Purpose | Read-only rebuild? |
|---|---|---|---|
| Questie | 217M, #1 in the Forever filter | Quest givers, objectives and turn-ins on map, tracker, tooltips | Yes |
| Details! | 375M | Damage meter | Partial: only via C_DamageMeter |
| DBM / BigWigs | 641M / 209M | Boss timers | Partial or no (combat log) |
| Auctionator | 207M | AH prices in tooltips, shopping lists | Partial: tooltip prices yes, posting is player action |
| Bagnon / Baganator | 170M / 42M | Bags, cross-character search, counts in tooltips | Partial: counts and search yes |
| RareScanner / SilverDragon | 142M / 32M | Rare alerts | Yes |
| Leatrix Plus | 76M | QoL toolbox | Mostly automation, no |
| Leatrix Maps / OpenMap | 43M / 1.3M | Map overlays, zone levels, flight paths | Partial |
| TomTom | 93M | Waypoint arrow | Yes |
| Pawn | 131M | Upgrade arrows from stat weights | Yes |
| HandyNotes (+ WoW Forever plugin) | 62M | Map notes | Yes |
| RestedXP Guide | 30M | Leveling guide | Yes (display) |
| DungeonJournal | 5.6M | Dungeon bosses, loot, quests | Yes |
| AtlasLoot Classic Forever | 7.8M | Loot tables, BiS | Yes |
| What's Training? | 11.5M | Trainable spells and costs | Yes |
| GearQuest Forever | 1.5M in a month | Best leveling gear per slot with sources | Yes |
| Shortest Path Forever | 759K | Multi-modal route planner with ETA | Yes, large |
| SkillUp Forever | 991K | Profession skill-up chance, mats, routes | Yes |
| OneForAll Forever | 807K | Compendium: gear, dungeons, recipes, talents | Mostly |
| Forever Loot Sparkles | 715K | Sparkle on quest items and nodes via CVars | Changes settings |
| Glowing Bars | 548K | Missing buffs, old ranks, low reagents | Partial (out of combat) |
| Forever Quest Tint | 337K | Marks quests new to Forever | Yes |
| Nova Spell Rank Checker | 325K | Old ranks on bars | Yes |
| ForeverPlus | 109K | Info bar: XP/hr, time to level, gold, durability | Info half yes |
| Forever Quest Pins | 86K | Quest starts on the world map | Yes |
| Zone Info: Forever | 44K | Zone level, dungeons, fishing skill on map | Yes |
| Tweaks Forever | 10K | XP/hr, quest XP overlay, coords | Info half yes |
| WeakAuras | n/a | Not on Forever (secret values); ForeverAuras replaces it | No |

Not on Forever per Kami: official WeakAuras, Quartz, ClassicCastbars, OmniCC, Skada, Auctioneer, AdiBags, Postal,
SexyMap, pfQuest, Azeroth Auto Pilot.

## Read-only ideas for a solo leveler
1. Zone and POI info on the map (level range vs yours, dungeons, fishing skill).
2. XP analytics: XP/hour, time to level, XP waiting in finished quests. (Built into the hub panel.)
3. Quest-start pins and quest level tags.
4. Trainer and spell-rank advisor. (ReadyCheck covers ranks.)
5. Tooltip enrichment: vendor price, stack value, AH price, counts. (Tooltips helper.)
6. Leveling gear hunt list per slot with sources.
7. Dungeon and quest journal. (Dungeons helper.)
8. Out-of-combat buff and consumable reminders. (ReadyCheck.)

## Sources
CurseForge search and project pages under https://www.curseforge.com/wow/addons/ (questie, details, auctionator,
baganator, openmap, dungeonjournal, shortest-path-forever, gearquest-forever, forever-loot-sparkles, forever-quest-tint,
forever-quest-pins, tweaks-forever, foreverplus, oneforall-forever, glowing-bars, zone-info-forever,
nova-spell-rank-checker, whats-training, threatclassic2, vendor-price, handynotes-wow-forever), Kami-Labs directory,
gfinityesports.com Forever addon articles, mein-mmo.de Forever addons article, warcrafttavern.com Forever news,
allthings.how install guide.
