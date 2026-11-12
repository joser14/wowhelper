# Reverse-engineering round 6: areas the suite doesn't cover yet (2026-11-11)

## How this was done

- **Read first:** README.md, research\BRIEF.md, STATUS.md (follow-ups), and the ranked lists and "Not taken" lists
  of `re_round3.md`, `re_round4.md`, `re_round5.md`, so nothing here repeats an idea that was built or rejected there.
  Where an item was proposed before but never built, it says so.
- **What exists:** 35 helper folders in 6 bundles (toc Notes read): !ErrorLog, AutoQuest, BagCheck, Builds,
  DeathNotes, Dungeons, DurabilityWatch, FoodCheck, ForeverHelper, ForeverHub, GoldGoal, GoldGuide, ItemAdvisor,
  ItemFinder, Landmarks, LevelGuide, LevelLog, MapPins, PriceMemory, ProfessionCap, ProfessionGuide, QuestCheck,
  QuestMobs, QuestTracker, RareWatch, ReadyCheck, RepWatch, RestGuard, SupplyWatch, TalentNudge, Tooltips,
  TrainerNotes, WeaponSkillWatch, WindowBadges, ZoneLevels.
- **Coverage grep** over the helpers' Lua: no achievement, calendar, gathering-node, party-aura, pet-happiness,
  aggro-range, spell-efficiency or loot-roll code exists. ReadyCheck checks only your own buffs (Fortitude etc.).
- **Survey:**
  - GitHub API, anonymous: `topic:wow-forever pushed:>2026-11-10`, `forever wow addon created:>2026-11-10`,
    `"wow forever" in:description,readme created:>2026-11-10`. 318 unique repos listed, about 30 opened (README,
    licence, file tree; a few source files as text).
  - CurseForge, Forever game version (88568), sorted by downloads, pages 1-2 (the 100 most-downloaded Forever
    addons) and individual pages for licences.
  - WebSearch for Forever news (Darkmoon Faire dates) and Classic Era/Anniversary "best addons" lists.
- **Nothing was downloaded to disk and nothing was run.** Repos were read as text through the GitHub API. No
  personal data went into any search.
- **APIs checked** in the client's generated API docs (`...\scratchpad\uisrc2\...APIDocumentationGenerated__*.lua`).
  Undocumented legacy globals (achievement globals, `GetStatistic`, `IsFishingLoot`, `GetLootSourceInfo`,
  `GetSavedInstanceInfo`) are marked **check in game**. Every event named below was checked to not be a
  `CallbackEvent`.

### Licence summary

| Source | Licence | Use |
|---|---|---|
| Legacy Forever (cjber) | GPL-3.0 | Port with credit (not its objective-tracker writes) |
| Pagle (fishing, timemir) | GPL-3.0-or-later | Port with credit |
| Olfato (aggro warning) | GPL-3.0; bundles LibRangeCheck-3.0 (MIT) | Port with credit |
| Deathlog (aaronma37), incl. its 1M-death database | GPL-3.0; README also says the database may be used "for any purpose" | Data and code with credit |
| ALL THE THINGS (ATT) | **MIT**; ships a `db/Camelot` folder (Camelot = Forever, as in What's Training) | Data with credit |
| FindAnUpgrade | BSD-3-Clause code; its reward catalogue mixes ATT (MIT) with forevervsclassic.com fields it says carry no redistribution licence | Code/ideas yes; take reward data from ATT directly |
| Darkmoon Turn-ins, LoreCompletion (fmartingr) | MIT | Data/code with credit |
| VoidBounty | MIT | Ideas/code with credit (not its sharing) |
| RollFrames, Buffsmith, ForeverQuiver, PetScout, Account Statistics, Bestiary Forever | GPL-3.0 | Port with credit |
| Spellwise, NodeSight, CraftUpgrades, VeinKeeper, ThreatClassic2, Capping, tomqwu classmate | no licence | Ideas only |
| GatherMate2, LifeTimeStats, StatsPro, Do-You-Need-It | NOASSERTION (custom/ARR) | Ideas only |
| Attune, Better Fishing | All Rights Reserved (CurseForge) | Ideas only |

---

## Ranked list

Ranked by what it gives a solo Night Elf priest leveling now (about level 11) and later, divided by effort and risk.
Size: S < 1 day, M a few days, L a week or more.

## A. New helpers

### 1. Legacy: Forever's Legacy challenges and points (M) — new helper "Legacy" (Forever Character)

- **What the player gets:** a hub page listing unfinished Legacy challenges grouped by type (exploration, dungeons,
  levels, professions), each with progress (3/7), the points it pays and where to do it. A side-panel line when a
  challenge is close ("Explore Darkshore: 2 areas left, +1 Legacy point"). Points earned so far and the next perk
  they can buy (Well Rested, Talented, Frequent Flier). Legacy points are account-wide and speed up every later
  character, so this is the most Forever-specific gap left.
- **Status:** proposed as #5 in `forever_improvements_2026-11-10.md`, never built (no achievement call anywhere in
  the helpers).
- **APIs:** `GetCategoryList`, `GetCategoryNumAchievements`, `GetAchievementInfo`, `GetAchievementNumCriteria`,
  `GetAchievementCriteriaInfo` / `...ByID` (legacy globals, not in uisrc2; live on Forever according to Legacy
  Forever: **check in game**); `C_Traits.GetTraitCurrencyForAchievement(4225, id)` and `C_Traits.GetTraitCurrencyInfo`
  (SharedTraitsDocumentation); events `CRITERIA_UPDATE`, `ACHIEVEMENT_EARNED` (AchievementInfoDocumentation),
  `MAP_EXPLORATION_UPDATED` (MapExplorationDocumentation). Exploration areas left from
  `C_MapExplorationInfo.GetExploredMapTextures`, which MapPins already reads.
- **Licence:** Legacy Forever is GPL-3.0: criteria by ID rather than index and the category walk can be ported with
  credit. Its objective-tracker writes and addon-message sharing are not taken.
- **In-game checks:** the category list contains the Legacy categories; criteria quantities are readable out of
  combat; `GetTraitCurrencyForAchievement` returns the points per challenge.

### 2. AggroWatch: "you're about to pull" warning (M) — new helper (Forever World)

- **What the player gets:** out of combat, a small marker under your character with the nearest hostile mob that will
  notice you: yellow at 5-10 yards from its aggro radius, orange under 5, red inside it, plus the mob's radius on
  its tooltip ("Aggro radius about 18 yd"). It helps a cloth healer avoid double pulls while questing, and does
  nothing else.
- **How:** aggro radius by the Classic rule: 20 yd at equal level, minus 1 yd per level you're above it (minimum 5),
  plus 1 per level it's above you (maximum 45). Distance comes in roughly 5-yard bands from range checks on
  nameplate units. Only red/orange (hostile) mobs not already in combat are counted.
- **APIs:** `NAME_PLATE_UNIT_ADDED`/`REMOVED` (NamePlateManagerDocumentation, not CallbackEvents),
  `C_NamePlate.GetNamePlates`, `UnitReaction`, `UnitAffectingCombat`, `UnitLevel`, `UnitClassification`;
  range from `C_Item.IsItemInRange` (ItemDocumentation), `C_Spell.IsSpellInRange` (SpellDocumentation) and
  `CheckInteractDistance` (PlayerScriptDocumentation). All run only while you're out of combat (`InCombatLockdown()`
  / `PLAYER_REGEN_DISABLED` stops the scan). Throttle to 4-5 Hz.
- **Rules:** read-only, no targeting. We must **not** raise the nameplate distance CVar the way Olfato does; the page
  just says "turn on enemy nameplates (V) for this".
- **Licence:** Olfato GPL-3.0 (formula and approach), LibRangeCheck-3.0 MIT (range item/spell tables). Port with
  credit.
- **In-game checks:** `C_Item.IsItemInRange` on a hostile nameplate unit out of combat isn't refused; no "blocked"
  pop-up; the warning hides at once on entering combat.

### 3. Darkmoon Faire and holidays (S/M) — new helper "Events" (Forever Hub page + Tooltips lines)

- **What the player gets:** "Darkmoon Faire is in Elwynn Forest until 16 November" on the side panel while it runs,
  with what is worth doing at your level: Sayge's fortune buff, the turn-in items you already hold (with counts
  against what each quest needs) and the tickets they pay. A list of upcoming holidays for the next 30 days.
  Tooltip line on turn-in items: "Darkmoon Faire turn-in: 5 needed, you have 3".
- **Why now:** Forever's first Darkmoon Faire opened on 9 November 2026 in Elwynn Forest; it runs 7 days from the
  first or second Monday of each month and alternates with Mulgore (Warcraft Tavern, mein-mmo).
- **APIs:** `C_Calendar.OpenCalendar` (asks the server for calendar data; no UI is opened),
  `C_Calendar.GetNumDayEvents`, `C_Calendar.GetDayEvent`, `C_Calendar.GetHolidayInfo` (CalendarDocumentation),
  `CALENDAR_UPDATE_EVENT_LIST`, `C_DateAndTime.GetCurrentCalendarTime`; `C_Item.GetItemCount`; tooltip lines through
  `TooltipDataProcessor.AddTooltipPostCall` as Tooltips already does.
- **Licence:** Darkmoon Turn-ins (MIT) has the turn-in table with sources; reuse with credit. Its glow on Blizzard
  bag buttons is not taken.
- **In-game checks:** `OpenCalendar` from an addon causes no taint; holiday titles and end dates come back for
  November; the Faire's location (Elwynn/Mulgore) can be read from the event's texture or title, otherwise use the
  published alternation.

### 4. Nodes: herb, ore and fishing spots you've used (M) — new helper (Forever World, draws on MapPins' overlay)

- **What the player gets:** every herb, vein and fishing pool you gather from is remembered with its spots on our own
  world-map and minimap overlay (never Blizzard's pin pool), coloured by how long since you took it ("likely back").
  A "nearest node you can gather" line, red when your skill is too low. A route summary per zone: nodes found,
  gathers per hour.
- **How:** on `UNIT_SPELLCAST_SUCCEEDED` for the player's gathering spells (Herb Gathering, Mining, Fishing), take
  the node name from the matching `UNIT_SPELLCAST_SENT` target (ConditionalSecret: read out of combat only, through
  Safe()), position from `C_Map.GetBestMapForUnit` + `C_Map.GetPlayerMapPosition`; merge spots within a few yards.
  Optional seed data: gameobject spawns from cMaNGOS classic-db (GPL-3.0, the same source FastLoot's drop table
  uses) converted by a tools script, so zones you haven't visited still show known spots.
- **APIs:** `UNIT_SPELLCAST_SENT`, `UNIT_SPELLCAST_SUCCEEDED` (UnitDocumentation; secret when spell casts are
  restricted), `C_Minimap.GetNumTrackingTypes`/`GetTrackingInfo` (only to say "Find Herbs is off"; never set
  tracking), `C_Map.*`, `LOOT_OPENED` + `GetLootSourceInfo` for the node GUID (**check in game**).
- **Licence:** GatherMate2 (NOASSERTION), VeinKeeper and NodeSight (no licence), Attune-style ARR: ideas only. Seed
  data only from GPL classic-db.
- **Not taken:** NodeSight's automatic switching between Find Herbs and Find Minerals (casts/changes tracking for
  you), its sparkle CVars, AlwaysTracking's re-enable.
- **In-game checks:** `UNIT_SPELLCAST_SENT`'s target is the node name out of combat; the gathering spell IDs on
  Forever; whether the loot source GUID is a GameObject GUID.

### 5. SpellMath: what each priest spell rank gives per mana (S/M) — new helper (Forever Character)

- **What the player gets:** extra lines on spell tooltips (spellbook, action bars): heal per mana, heal per second,
  for DoTs and HoTs the tick total; a "Ranks" page with every rank you know of Lesser Heal, Heal, Renew, Power Word:
  Shield, Smite, Shadow Word: Pain side by side (mana, amount with your +healing, per mana, per second) and the
  Classic penalty on ranks learned below level 20. It's a reference you read out of combat. It never picks a rank
  or a target.
- **APIs:** `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, ...)`;
  `C_Spell.GetSpellDescription`, `C_Spell.GetSpellPowerCost`, `C_Spell.GetSpellInfo` (cast time)
  (SpellDocumentation); `GetSpellBonusHealing`, `GetSpellBonusDamage` (PlayerScriptDocumentation, **secret when
  stats are restricted**: cache the last value read out of combat and label it). Numbers parsed from the
  description through Safe().
- **Licence:** Spellwise has no licence: ideas only. Coefficients (cast time / 3.5, the level-20 penalty) are public
  game formulas.
- **Borderline?** No: it's static tooltip information, like Pawn values on items. It doesn't react to combat state.
- **In-game checks:** description numbers include gear (Spellwise says they do on Forever); Forever's tuning of
  priest coefficients (10 November tuning, see `builds_tuning_2026-11-10.md`).

### 6. Fishing journal (M) — new helper "Fishing" (Forever Guides, next to ProfessionGuide)

- **What the player gets:** catches per zone and per hour, which fish you still haven't caught in each water, the
  skill each zone needs before fish stop getting away, rare and quest catches (Darkshore Grouper for "The Family and
  the Fishing Pole" is already in the route), and which catches cook into the food FoodCheck recommends.
- **APIs:** `UNIT_SPELLCAST_CHANNEL_START`/`STOP` for the Fishing spell, `LOOT_OPENED` + `IsFishingLoot`
  (**check in game**), `GetLootSlotLink`, `C_Map.GetBestMapForUnit`, `GetSubZoneText`; skill from the paths
  ProfessionGuide already uses.
- **Licence:** Pagle is GPL-3.0-or-later (journal, per-zone tables, "how it works" logic): port with credit. Better
  Fishing (ARR) is one-key casting and is not taken.
- **In-game checks:** `IsFishingLoot` exists; zone minimum fishing skills on Forever match Classic.

### 7. EnemyWatch: enemy players near you (S/M) — new helper (Forever World)

- **What the player gets:** on PvP-flagged ground, a small box "2 Horde nearby: Rogue 24, Hunter 22", a sound when
  someone who killed you before shows up again, and a "danger here" count for the zone over the last 15 minutes.
  Matters from Ashenvale/Stonetalon (about 18+); quiet in Teldrassil.
- **APIs:** `NAME_PLATE_UNIT_ADDED`, `PLAYER_TARGET_CHANGED`, `UPDATE_MOUSEOVER_UNIT`; `UnitIsPlayer`, `UnitIsEnemy`,
  `UnitLevel`, `UnitClass`, `UnitName`, `UnitIsPVP` (UnitDocumentation; secret when unit identity is restricted:
  skip instances and battlegrounds); killers from `C_DeathRecap.GetRecapEvents` as DeathNotes already reads.
- **Licence:** VoidBounty MIT. Not taken: sharing sightings with other players by addon message, chat lines.
- **In-game checks:** enemy player names and levels on nameplates are readable in the open world; PvP flag state.

### 8. Pet care for hunters (S/M) — new helper (Forever Character; hunters only)

- **What the player gets:** pet happiness and loyalty, a warning before the pet turns unhappy, which food in your bags
  this pet will eat (and which it won't), training points left, and on beast tooltips the family, attack speed and
  abilities a tame would teach. Nothing for priests, but every class gets something from the suite.
- **APIs:** `GetPetHappiness`, `GetPetLoyalty`, `GetPetFoodTypes`, `CanPetEatItem`, `GetPetTrainingPoints`
  (PetInfoDocumentation), `UNIT_PET`, `PET_UI_UPDATE`; tooltips by post-call.
- **Licence:** PetScout and ForeverQuiver GPL-3.0; PetTraining and HunterGod no licence (ideas).
- **Not taken:** `PetAbandon`, feeding for you.
- **In-game checks:** happiness reads on Forever (the trait-based client may have changed hunter pets).

### 9. Attunements and keys (S/M) — new helper or a Dungeons page (Forever Guides)

- **What the player gets:** for later levels, each attunement chain (Onyxia, Molten Core, Blackwing Lair, UBRS) and
  key (Scarlet Key, Workshop Key, Shadowforge Key, Mallet of Zul'Farrak, Crescent Key, Key to the City) with done /
  next step / where, across all your characters.
- **APIs:** `C_QuestLog.IsQuestFlaggedCompleted`, `C_QuestLog.GetAllCompletedQuestIDs` (QuestLogDocumentation),
  `C_Item.GetItemCount` and the keyring as ItemFinder already reads it.
- **Licence:** Attune is All Rights Reserved: ideas only. Chain facts from forever-db (GPL) and ATT's Camelot data
  (MIT).
- **In-game checks:** Forever's attunement quest IDs match Classic (spot-check at 55+). Low priority for level 11.

## B. Big upgrades to existing helpers

### 10. ReadyCheck: party buffs, not just yours (S)

- **What the player gets:** in a group and out of combat, "Missing Fortitude: Tank, Rogue" (and Divine Spirit,
  Shadow Protection once learned; Mark of the Wild, Arcane Intellect, Blessings for other classes), shown on the
  side panel before a pull. Today ReadyCheck only checks your own buffs.
- **APIs:** `GetNumGroupMembers`, `UnitExists("partyN")`, `UnitIsConnected`, `UnitIsDeadOrGhost`,
  `C_UnitAuras.GetAuraDataByIndex("partyN", i, "HELPFUL")` (UnitAuraDocumentation; secret when auras are restricted:
  only out of combat and outside restricted instances, through Safe()), `UnitInRange` (check in game), `UNIT_AURA`
  and `GROUP_ROSTER_UPDATE`.
- **Licence:** Buffsmith GPL-3.0 (ideas). Its click-to-cast bar is not taken: we name who lacks what, you cast.
- **In-game checks:** party aura reads in a dungeon out of combat aren't secret.

### 11. DeathNotes + Tooltips + MapPins: community danger from 1M Classic Era deaths (M/L)

- **What the player gets:** on a creature's tooltip, "Killed 412 hardcore players at levels 10-14"; on the zone page,
  the five deadliest mobs for your level band; an optional heat layer on our map overlay showing where players
  your level died most. Turns "remembers where *you* died" into "warns before you go somewhere that kills people".
- **How:** a tools script (like `gen_questdb.js`) reduces Deathlog's database to counts per NPC ID per 5-level band
  and per zone grid cell (map ID, 5 % squares). Ship only the reduced table. Classic NPC IDs and zones match
  Forever's world; Forever-new mobs are absent.
- **APIs:** existing tooltip post-call; `UnitGUID` for the NPC ID (Safe()); MapPins overlay textures.
- **Licence:** Deathlog GPL-3.0, and its README invites use of the database for any purpose. Credit in NOTICE.md.
  Its death alerts, `/who` lookups and channel broadcasts are not taken.
- **In-game checks:** none beyond the tooltip; check the reduced table's size (keep it under about 1 MB).

### 12. ItemAdvisor + LevelGuide: quest-reward upgrades ahead on your route (M)

- **What the player gets:** "Upgrade ahead: *Quest X* (level 14, Darkshore) rewards *Item Y*, +12 % over your
  chest" on the guide step and a list on ItemAdvisor's page, scored with ItemAdvisor's own weights. Also "keep this
  item, a better one comes at 16" so you don't buy what a quest gives.
- **Data:** quest reward items from ATT's `db/Camelot` (MIT), converted by a tools script and joined to our forever-db
  quest IDs. FindAnUpgrade (BSD-3) shows the approach works on Forever; take ranking ideas from it, not its
  catalogue (which mixes in fields from a site with no redistribution licence).
- **APIs:** none new; `C_Item.GetItemInfo`/`GetItemStats` (already used), `C_QuestLog.IsQuestFlaggedCompleted`.
- **In-game checks:** a sample of rewards against the quest window (rewards were changed on some Forever quests).

### 13. QuestCheck: quests done per zone (S/M)

- **What the player gets:** per zone, "Darkshore 34/61 quests done", the ones you've skipped, Forever-new quests
  tagged, and a "zones you can still finish at your level" list. Pairs with Legacy challenges (#1).
- **APIs:** `C_QuestLog.GetAllCompletedQuestIDs` (QuestLogDocumentation) once per login, then
  `QUEST_TURNED_IN`; zone and race/class filters from our GPL forever-db QuestDB.
- **Licence:** LoreCompletion MIT (counting rules: skip repeatables, race/class filter, chains shown together).
  It reads QuestieDB at run time; we use our own data.
- **In-game checks:** `GetAllCompletedQuestIDs` returns the full list on Forever.

### 14. ProfessionGuide + ItemAdvisor: gear you can craft that beats what you wear (S/M)

- **What the player gets:** with the profession window open, an "Upgrades you can make" list in our own panel next
  to it (tailoring robes and gloves for a priest), scored by ItemAdvisor, with missing materials.
- **APIs:** `C_TradeSkillUI.GetRecipeInfo`, `GetRecipeOutputItemData`, `GetRecipeSchematic`
  (TradeSkillUIDocumentation); `TRADE_SKILL_LIST_UPDATE`; recipe list: `C_TradeSkillUI.GetAllRecipeIDs` is **not
  documented** in uisrc2, so use what ProfessionGuide already reads, or check in game.
- **Licence:** CraftUpgrades has no licence: ideas only. Unlike it, we never add rows to Blizzard's crafting window.
- **In-game checks:** recipe output item IDs are readable for Classic-era recipes on Forever.

### 15. ForeverHelper: profession cooldowns across your characters (S)

- **What the player gets:** on the Characters page, "Mooncloth ready", "Salt Shaker in 2 h", "Transmute: Arcanite
  ready" per character, with a pop-up when one is ready on the character you're on.
- **APIs:** `C_Spell.GetSpellCooldown` on the cooldown spells (SpellDocumentation; secret when cooldowns are
  restricted: read out of combat), `C_Container.GetItemCooldown` for the Salt Shaker; saved per character with the
  end time. `C_TradeSkillUI.GetRecipeCooldown` is not documented.
- **Licence:** idea common to Altoholic/Nova (no code).
- **In-game checks:** Forever kept these cooldowns (some Legacy profession perks may change them).

### 16. LevelLog: the game's own Statistics, across characters (S)

- **What the player gets:** a Statistics page fed by the game's counters (creatures killed, quests completed, deaths
  by type, flights taken, gold looted), per character and account totals, with a search. Complements our own
  lifetime stats (round 5 #9) with numbers the game kept from before the addon was installed.
- **APIs:** `GetStatisticsCategoryList`, `GetCategoryNumAchievements`, `GetAchievementInfo`, `GetStatistic`
  (legacy globals, **check in game**); snapshot at login/logout as Account Statistics does.
- **Licence:** Account Statistics GPL-3.0 (port with credit); LifeTimeStats NOASSERTION (ideas).
- **In-game checks:** the Statistics categories exist on Forever's client.

### 17. MapPins: your own notes on the map (S)

- **What the player gets:** "Add a note here" (at your position) or a typed `zone x y text` on the Map pins page;
  the note shows as our own pin on the world map and minimap, with its text on hover. HandyNotes-style, without
  clicking on Blizzard's map.
- **APIs:** existing overlay; `C_Map.GetBestMapForUnit`, `C_Map.GetPlayerMapPosition`.
- **Licence:** idea only (HandyNotes). No click-catcher over the world map (round 4 "Not taken").

### 18. Dungeons: group loot log per run (S)

- **What the player gets:** after a dungeon, who won what and with which roll, kept with the run in Dungeons' run log;
  your own wish-list items that dropped are highlighted.
- **APIs:** `C_LootHistory.GetAllEncounterInfos`, `GetSortedDropsForEncounter`, `GetSortedInfoForDrop`, events
  `LOOT_HISTORY_UPDATE_DROP`/`_ENCOUNTER` (LootHistoryDocumentation, not CallbackEvents); `START_LOOT_ROLL`.
  Read only after the roll is decided.
- **Licence:** RollFrames GPL-3.0 (ideas). Its Need/Greed/Pass buttons and hiding Blizzard's roll pop-ups are not
  taken.
- **In-game checks:** `C_LootHistory` fills on Forever's group loot (Classic rules).

### 19. QuestTracker + Tooltips: "New in Forever" tag on quests (S)

- **What the player gets:** a small tag on quests that only Forever has (or that Forever changed), in the tracker and
  on quest-giver tooltips, so you notice new content.
- **Data:** forever-db (GPL) and ATT's Camelot data (MIT) list Forever-only quest IDs; LoreCompletion's "ID 10000+"
  rule is only a fallback.
- **Licence:** Forever Quest Tint idea (CurseForge, licence not checked: idea only).

### 20. GoldGuide + Events: Darkmoon and holiday money (S)

- **What the player gets:** in GoldGuide, "During the Faire: sell X turn-in materials on the auction house" from
  PriceMemory's prices, and which of your professions' items are Faire turn-ins.
- **APIs:** as #3 plus PriceMemory's stored prices. Builds on #3; listed separately because it can wait.

---

## C. Considered and rejected

| Idea (source) | Why not |
|---|---|
| One-key or double-click fishing (Better Fishing, wow-fishing-forever) | Casting through bindings; the bot version breaks the ToS outright |
| Auto-switch Find Herbs / Find Minerals, keep tracking on (NodeSight, AlwaysTracking) | Casts or changes tracking for you |
| Node sparkles and nameplate distance (NodeSight, Olfato, Forever Loot Sparkles) | Change game CVars |
| GTFO-style "you're standing in fire" | Needs in-combat aura or damage reads that are secret on this client, or encounter events that are CallbackEvents |
| Boss timers (DBM, BigWigs, LittleWigs) | Need the closed combat log or `ENCOUNTER_STATE_CHANGED` (CallbackEvent) |
| Threat meter (ThreatClassic2) | `UnitDetailedThreatSituation` is secret when threat values are restricted (in combat), no licence; revisit only if a display-only design works in game |
| Click-heal or dispel panels (Decursive, Salve, Clique, HealBot, VuhDo, AggeHealBot) | Secure unit frames and click casting; replaces protected Blizzard frames |
| Buff bars you click (Buffsmith), Quick-Process, RightClickPickLock, lockmenu, Speedster | Cast spells or use items for you |
| Rotation helpers (forever-one-button, flow-wow, MaxDps, RotationGuide) | Decide for the player in combat |
| New spell ranks onto bars (fresh-ranks) | Writes the player's action bars |
| Swing timer (`C_SwingTimer`, documented) | Allowed, but useless to a priest; revisit for melee alts |
| Battleground timers (Capping, FlagCarriers) | No licence; later levels; check Forever's battleground setup first |
| Nameplate and unit-frame replacements (Plater, Threat Plates, Sigil, combo-point plates) | Replace protected Blizzard frames |
| Quest voice-over packs (Spoken, Chronicle) | Large audio packs, licensing, off our scope |
| Map replacements (EndlessMap, D2Map, SimpleMap, OpenMap) | Rewrite or move Blizzard's map |
| Auto screenshots (DingCam, Paparazzi) | Outside "information only"; trivial for players to do themselves |
| Sharing with friends or guild (FriendsSync, VoidBounty sightings, guild tools, Deathlog broadcasts) | Addon messages; data leaves the player's machine |
| Layer hopping (WorldSync, voidlayer) | Acts on group invites for you |
| AH flipping and scan bots (ForeverFlip, goldwright, forever-market) | Automated scans; desktop apps |
| Loot triage with delete prompts (LootTriage), auto loot (SelectiveLoot, LootFliter) | Deletes or loots for you |
| Mage trade fills (WaterboyReimagined, ButtonsForever) | Trade-window automation |
| Full collections tracker (ATT) | Huge; Classic-era collections are few. ATT's MIT data is used for #12/#19 instead |
| Skyborne routes | Excluded by the brief |

## D. In-game checks for this round

1. `/dump GetCategoryList()` and `/dump GetAchievementInfo(<a Legacy id>)`; `C_Traits.GetTraitCurrencyForAchievement(4225, id)` (#1).
2. Out of combat, with enemy nameplates on: `C_Item.IsItemInRange(<item>, "nameplate1")` returns a boolean and no
   "blocked" pop-up appears (#2).
3. `C_Calendar.OpenCalendar()`, then `C_Calendar.GetNumDayEvents(0, <today>)` lists the Darkmoon Faire (#3, #20).
4. Gather a herb: `UNIT_SPELLCAST_SENT`'s target is the herb's name; note the spell ID (#4).
5. `IsFishingLoot()` exists and is true on a fishing loot window (#6).
6. In Ashenvale: an enemy player's name and level read from a nameplate (#7).
7. On a hunter alt: `GetPetHappiness()` returns a value (#8).
8. In a dungeon group, out of combat: `C_UnitAuras.GetAuraDataByIndex("party1", 1, "HELPFUL")` isn't secret (#10).
9. `#C_QuestLog.GetAllCompletedQuestIDs()` is the size you expect (#13).
10. `GetStatistic(<id>)` returns a value; the Statistics categories exist (#16).
11. After a group roll: `C_LootHistory.GetAllEncounterInfos()` is filled (#18).

## Summary

The suite now covers leveling, quests, bags, gear, maps and deaths well. What's left is mostly whole areas: Forever's
own Legacy challenges (#1, the biggest Forever-specific gap, proposed earlier but never built), out-of-combat pull
safety (#2), the calendar and the Darkmoon Faire that opened on 9 November (#3), gathering spots (#4), spell
efficiency per rank for a healer (#5), fishing (#6), world PvP awareness (#7), and class or late-game areas (hunter
pets #8, attunements #9). The biggest upgrades are party buffs in ReadyCheck (#10), a community danger layer from
Deathlog's GPL death database (#11), and quest-reward upgrades from ATT's MIT Forever data (#12). Two licence
findings matter for data: ATT is MIT and ships a Forever (`Camelot`) database, and Deathlog's GPL database is offered
for any use. GatherMate2, Attune, Better Fishing, Spellwise and ThreatClassic2 are ideas only. Everything listed
here is read-only, uses no hooks or Blizzard frame writes, no map pin pool and no CallbackEvent.
