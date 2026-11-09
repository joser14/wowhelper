# Popular item / gear / spell addons — read-only review (group B)

Date: 2026-11-09. Client: WoW Forever (Classic-era rules on Midnight client, interface 16001, game version 1.60.1).
Method: download → malware scan (extensions, magic bytes, obfuscation/network grep) → read-only code reading.
All descriptions are in our own words; no code or data was copied into this repo.

## Downloads

All downloads live in `%TEMP%\claude\...\scratchpad\downloads\<AddonName>` (one fresh folder each, zips extracted to `x\`). Nothing installed, nothing executed.

| Addon | How | File / source | Size |
|---|---|---|---|
| Baganator | CurseForge zip (no public repo; the GitHub org/repo linked from the page wiki is gone/private) | `Baganator-846.zip` from https://edge.forgecdn.net/files/9512/960/Baganator-846.zip (project 914482, file 9512960) | 429,340 B zip, 1.3 MB extracted |
| Syndicator | CurseForge zip (same situation) | `Syndicator-290.zip` from https://edge.forgecdn.net/files/9511/150/Syndicator-290.zip (project 988370) | 107,588 B, 0.4 MB |
| Pawn | git clone (Source link on CurseForge) | https://github.com/VgerMods/Pawn (depth 1) | 4.3 MB checkout |
| What's Training? | git clone (Source link) | https://github.com/fusionpit/WhatsTraining (depth 1) | 2.3 MB checkout |
| Nova Spell Rank Checker | CurseForge zip (no source link) | `NovaSpellRankChecker-v1.63.zip`, https://edge.forgecdn.net/files/8948/193/NovaSpellRankChecker-v1.63.zip (project 696065) | 20,976 B, 0.1 MB |
| GearQuest Forever | CurseForge zip (no source link). Zip is 49 MB (< 100 MB limit) so it was downloaded; the 200-400 MB figure is in-game memory, not download size | `GearQuestForever-v1.1.1.zip`, https://edge.forgecdn.net/files/9521/445/GearQuestForever-v1.1.1.zip (project 1698950) | 51,784,455 B zip, 125.9 MB extracted |
| AtlasLoot Classic Forever | CurseForge zip (no source link; slug is `atlasloot-forever`, the `atlaslootclassic-forever` slug 404s) | `AtlasLoot-Classic-Forever-1.3.4-091126-16001.zip`, https://edge.forgecdn.net/files/9520/898/... (project 1422985) | 1,600,269 B, 5.7 MB |
| DungeonJournal (ForeverDungeonJournal) | CurseForge zip (no source link) | `ForeverDungeonJournal-1.7.4.zip`, https://edge.forgecdn.net/files/9518/674/... (project 1707971) | 47,240,201 B, 82.1 MB (mostly .tga art) |

Zip entries were listed before extraction: no `..`/absolute paths in any archive.

## Malware check summary

Scan script checked every file's extension, first bytes (MZ, PK, 7z, ELF, `#!`, RAR, Lua bytecode), and grepped .lua/.xml/.toc for loadstring/load/setfenv/getfenv, string.char, hex escapes, 300+ char base64-like runs, URLs, addon/chat messaging, macro APIs, debug/io/os.

| Addon | Verdict | Notes |
|---|---|---|
| Baganator | CLEAN | Only Lua/XML/TOC/MD/TGA/PNG + LICENSE. No signatures. URLs are a donate/discord string shown to the user. Contains an `AGENTS.md` asking AI tools not to use the repo as reference (see note below). License: All Rights Reserved. |
| Syndicator | CLEAN | Same profile; same `AGENTS.md` note; All Rights Reserved. |
| Pawn | CLEAN | `.github/workflows/package-addon.yml` (zip+sed TOC packaging, not run), FUNDING.yml. `getfenv` is in VgerCore's insecure-hook helper (benign). URLs are comments. |
| What's Training? | CLEAN | BigWigs packager CI workflow (not run), `.luacheckrc`, `changes.log`. Nothing else unusual. |
| Nova Spell Rank Checker | CLEAN | Bundles LibCustomGlow + LibStub; URL is a comment. |
| GearQuest Forever | CLEAN | 3 JSON data files (random-enchant tables, 1 MB), MP3 sounds, PNGs. One `string.char` is a printable-ASCII sanitiser for text, not decoding. URLs are a comment and a Discord invite string. No addon-channel messaging. |
| AtlasLoot Classic Forever | CLEAN | Stock Ace3/LibStub/CallbackHandler (the standard `loadstring` dispatcher), LibExtraTip `API.html` doc, `README.textile`. `getfenv(0)` at file heads is the usual AtlasLoot idiom. Sends a version string on its addon-message prefix to guild/party/raid. `loadString` in ItemDB is a variable name for module-on-demand loading. |
| DungeonJournal | CLEAN | 357 TGA images; version-check addon message (throttled, pcall'd). Discord link string. |

> Note on Baganator/Syndicator: both ship an `AGENTS.md` that tells AI tools not to use the repository as a reference and calls it a copyright violation. The user has already decided the review proceeds under strict own-words, no-code, no-data limits; per that decision the review of these two is kept to a feature/mechanism level only, and nothing from them should be copied or closely paraphrased into our suite.


---

## 1. Pawn (2.14.2, interface 120105 + 16001) — vs ItemAdvisor

**Verdict: CLEAN.** License CC BY-NC-ND 3.0 (no derivatives — ideas only).

### Features
- Item "value" per *scale* (a named stat-weight table) shown on every item tooltip; multiple scales can be visible at once (e.g. both a DPS and a tank scale), each with its own colour and a "+N% upgrade" line.
- Green upgrade arrow on Blizzard bag buttons; a full UI (Pawn window) to view/edit weights, compare two items side by side, see gems, import/export scales as text "scale tags".
- Auto-selects the scale for your spec; optional "upgrades by item level" mode.

### How it works
- **Stats source:** parses tooltip *text* line by line on a private hidden tooltip, using big per-locale regex tables (TooltipParsing.lua + Localization*). It does not trust `GetItemStats`. Forever has its own pattern overrides (combined haste, "reduces chance to be dodged or parried" expertise, spell-damage-without-healing lines) and a locale hack because Forever prints percentages with a period in de/es/pt.
- **Weights (Forever):** the "Classic" provider (curated by a community author) ships one table per class+spec, built as level-60 *raid* weights. Ratings are written as "percent weight × rating-per-percent", with Forever sharing Classic's per-percent constants (hit ≈9.4, crit 8.5, spell hit/crit 8, haste ≈8, expertise ≈2.3, dodge/parry ≈9.4, block ≈6.9, defense 1.5). Stamina is tiny for DPS scales (0.1), large only for tank scales.
- **Unusable items:** each scale can mark item-type "stats" (IsPlate, IsSword, IsOffHand, IsFrill, ...) as unusable; any unusable stat makes the item's value 0 for that scale. Armor type is gated by `PawnIsArmorBestTypeForPlayer` (cloth-only classes; mail only from level 40 for hunter/shaman; plate only from 40 for warrior/paladin). Off-hand weapons are excluded for classes whose scale marks IsOffHand unusable.
- **Speed baseline:** weapon speed can be weighted relative to a baseline speed; DPS is split into MeleeDps/RangedDps/MainHandDps/OffHandDps/OneHandDps/TwoHandDps so each slot can be weighted differently.
- **Normalisation:** optional — divides by the sum of weights so different scales give comparable numbers.
- **Upgrade logic (`PawnIsItemAnUpgrade`):** compares the item not with what you wear *now* but with a persistent per-character, per-scale **"best item ever seen" table per inventory type** (scanned from worn gear + every equipment set). Rings and 1H weapons keep a best *and* second-best entry; a new ring is compared against the second-best. Upgrade threshold is 0.5%. An empty second ring/weapon slot is reported as a big upgrade. When an item you owned is sold/destroyed (hooks on DeleteCursorItem / merchant pickups) the table is invalidated and rebuilt.
- **One-hand vs two-hand:** Pawn does **not** cross-compare: if you wield a 2H, 1H/off-hands are never upgrades, and vice versa. After the scan it solves which of four combos is best (1H+1H, 1H+off-hand, MH+1H, MH+off-hand) and stores that as the main/off-hand best.
- **Trinkets:** never scored for upgrades (explicitly skipped).
- **Throttling:** bag-arrow checks run through a *time-budget* throttle (about 2 frames' worth of CPU per quarter second); when the budget is spent it returns "unknown" and the caller retries on a 0-second timer. Item data is cached (LRU-ish, raised to 1000 during full scans).
- **Spec detection:** `GetSpecialization()` if present, else `GetPrimaryTalentTree()`; falls back to a default "newbie" spec per class.

### Midnight-client techniques
- Detects Forever by build number range (16000–20000) and treats it as a ranged-slot-era client.
- Forever character name key uses the character's "last name" (Forever names are unique across rulesets).
- Pawn **hooks heavily**: `hooksecurefunc` on GameTooltip setters, on `ContainerFrameMixin.UpdateItems` to show the arrow on Blizzard's own `UpgradeIcon`, and it **reparents** a paper-doll element on Forever because the character model covers it. All of that is outside our "no hooks / no Show/Hide of Blizzard frames" rules — we keep our overlay-frame + TooltipDataProcessor approach.

### ItemAdvisor comparison (cite: `ItemAdvisor/ItemAdvisor.lua`)
| Topic | Pawn | ItemAdvisor | Who's better |
|---|---|---|---|
| Stat read | Tooltip-text regex, per-locale | `C_Item.GetItemStats` + tooltip percent lines (`:350-395`, `:277-304`) | Ours is lighter and locale-safer; Pawn handles more odd wordings. Keep ours. |
| Weights | Level-60 raid weights per spec, editable, importable | Hard-coded leveling profiles (`:93-107`) | Ours fits leveling better (Stamina matters); Pawn's are user-editable. |
| Role pick | Automatic from talent tree, UI selector | First profile of class, change via `/ia role` slash only (`:874-889`, `:1305-1309`) | **Pawn** — ours needs a chat command (against the "UI not chat" preference) and never auto-detects. |
| Compare base | "Best ever owned" per slot, includes equipment sets | Currently worn only; equipment-set items simply KEEP (`:433-446`, `:650`) | Mixed. Ours is simpler and right for leveling; Pawn avoids nagging about items worse than a set piece. |
| Rings | Compare to weaker of two | Max gain across both slots (`:530-540`, `:577-622`) — equivalent | Tie. Ours also handles Unique-equipped spares (`:654`). |
| Trinkets | Skipped | Scored by stats, "No stats" → CHECK (`:721-724`) | Ours. |
| 2H vs 1H+OH | Never cross-compares | 2H vs MH + OH (OH dps at 0.5) (`:595-600`); 1H while wearing 2H → CHECK "half of a pair" (`:675-676`, `:715-716`) | **Ours for 2H→ dual**, but Pawn's 4-combo solver could let us suggest *a pair from the bags* instead of giving up. |
| Weapon speed | Weighted via speed baseline | Ignored (only DPS, `:397-405`) | Pawn (matters for slow 2H warriors/ret). |
| Unusable | Per-scale unusable types + level-gated armor | Class tables with unlock levels (`:118-141`) + red-tooltip check (`:463-483`) | Ours is more precise (it knows untrained skills via red text). |
| Multiple roles shown | Yes, one line per visible scale | Only active profile | Pawn. |
| Upgrade threshold | 0.5% | max(0.5 points, 3% of base) + "strictly better" rule (`:680-688`) | Ours is more conservative and explains trade-offs (gains/losses list) — better UX. |
| CPU | Time-budget throttle | Verdict cache (`:738-798`) + debounced repaint | Comparable; a budget throttle would protect us on big bag repaints. |

### Ranked improvements (ItemAdvisor)
1. **Auto-pick role from talents + a role dropdown in our own window** (no slash command). Count spent talent points per tab (`GetTalentTabInfo`) and map the heaviest tab to a profile; keep the user override. — **S**
2. **Pair finder for weapons:** when wearing a 2H, look for the best main-hand + off-hand (or shield) *pair in the bags* and compare the pair's total with the 2H; vice versa when dual-wielding. Replaces today's "compare it yourself" CHECK. — **M**
3. **Second-role line on tooltips** (e.g. tank verdict for a warrior who levels as DPS), opt-in. — **S**
4. **Weight editor window** (per profile sliders, reset to default, account-wide custom profiles). — **M**
5. **Weapon speed term** for 2H melee profiles (slow weapons favoured while leveling). — **S**
6. **Time-budget throttle** around bulk bag evaluation (return "pending", retry next frame). — **S**


---

## 2. What's Training? (TOC interface 20506, 16001, 11509) — vs TrainerNotes

**Verdict: CLEAN.** Packaging CI (BigWigs packager workflow) noted, not run.

### Features
- A tab/panel inside the spellbook listing every class spell by level with category headers: available now, missing requirement (previous rank or talent), next 2 levels, later, known, ignored; per-group total cost.
- Pet abilities (hunter beast training) and warlock demon tomes (with merchant highlighting), weapon skills with the trainers' zones and an optional waypoint (TomTom or a plugin provider via a small public API), class quest-reward spells (which quest, which zone, which races).
- Reputation-aware prices: lists the cheapest capital-city trainer for you given your standing.
- Ignore list per spell (e.g. ranks you'll never train), LibDataBroker/minimap launcher, rank comparison tooltip on Shift.
- On Forever it ships a separate, much larger UI (`Forever\*`: own spellbook-sized panel, gamepad support, a "train all" batch purchase at the trainer). The batch-purchase part is an action we would not copy (we stay read-only).

### How it knows spells, costs and levels
- **Static per-class data**, one file per class per game flavour (`Classes\Vanilla|TBC|Camelot\<Class>.lua`; "Camelot" is the Forever game type). Each level maps to a list of `{spell ID, copper cost, required previous-rank IDs, optional race/faction restriction, optional required talent ID}`. Only IDs and costs are stored; names, ranks and icons come from the client at run time (`C_Spell.RequestLoadSpellData` + `SPELL_DATA_LOAD_RESULT`, cached in Cache.lua).
- Data is filtered at load by race and faction (`RaceFilter`, `FactionFilter`), plus quest spells and tomes merged in.
- **Known detection:** a spell counts as known if `C_SpellBook.IsSpellInSpellBook` *or* `C_SpellBook.IsSpellKnown` says so, *or* a later member of an "override group" is known (so lower ranks that the game replaces in the book still count). Pet abilities are read from the beast-training craft window and remembered.
- **Categorisation** (`DataBuilder.lua`): known → known; ignored; requires talent not known → missing talent; level above you → next-level (within 2) or later; else check that all required previous ranks are known → available, otherwise missing requirements.
- **Refresh triggers:** `LEARNED_SPELL_IN_SKILL_LINE`, `PLAYER_LEVEL_UP`, `SKILL_LINES_CHANGED`, `PLAYER_EQUIPMENT_CHANGED`, and on Forever also `SPELLS_CHANGED` (cheaply: it only re-checks the small set of currently learnable IDs).
- **Pricing:** base cost from data; on Forever the discount is 10% at Honored+ with the city faction that trains that role (they note Forever tome vendors don't discount — a Forever quirk), plus a PvP-rank discount on Era only. Reputation via `C_Reputation.GetFactionDataByID` on Forever, the old API elsewhere.

### Forever / Midnight techniques worth noting
- **TOC game-type gating:** `[AllowLoadGameType camelot]` / `[ExcludeLoadGameType classic]` on files and even on `## SavedVariables` lines, and a `[Game]` path token to pick the data folder per flavour. Lets one package serve Era, TBC and Forever.
- Detects Forever by `GetBuildInfo()` interface ≥ 16000.
- Uses `C_SpellBook.*` with `Enum.SpellBookSpellBank.Player/Pet` (Midnight API) everywhere.
- The Forever UI's comments say it never parents to, anchors to, or changes native frames for its trainer panel; it also chose events over `hooksecurefunc` because hooks misbehaved with taint logging. (Older parts still hook the spellbook and merchant frames.)
- Stormwind coordinates on Forever are shifted because the map includes the Harbor — their weapon-trainer data accounts for it.

### TrainerNotes comparison (cite: `TrainerNotes/TrainerNotes.lua`)
| Topic | What's Training | TrainerNotes |
|---|---|---|
| Data source | Static class tables (IDs, cost, level, prerequisites) | Only what the trainer window showed on your last visit (`:142-194`). Before the first visit it knows nothing (`:241-243`). |
| Known check | Spellbook APIs + override groups | Bought = disappeared from the trainer list (`:60-105`); never checks the spellbook, so a spell learned elsewhere (quest, tome) or at another trainer can linger until revisit. |
| Prereqs | Required previous rank and talent from data | Asks the trainer (`GetTrainerServiceAbilityReq`, `:118-140`) — accurate but only while the window is open. |
| Look-ahead | Every level to 60 | Next 4 levels of what was *listed* (`:1`, `:198-219`); trainers usually list higher ranks, so this mostly works. |
| Cost | Rep-discounted per faction | Raw cost as shown (already discounted for the trainer you visited). |
| Weapon skills / quest spells / tomes / pet skills | Yes, with trainer locations | Not covered. |
| Output | Own panels | Hub page + `/trainer` slash printing lines (`:235-266`, `:308-313`) — chat-style output we want to retire. |

### Ranked improvements (TrainerNotes)
1. **Cross-check against the spellbook** on `LEARNED_SPELL_IN_SKILL_LINE`/`SPELLS_CHANGED`/login: drop stored entries whose spell is now known (needs the spell ID — store `GetTrainerServiceInfo`'s spell via `C_TooltipInfo.GetTrainerService(index)` or the service's spell link when reading the trainer). — **S**
2. **Own window** listing Ready / Next levels / Blocked with totals and a "can afford" bar; retire the `/trainer` chat print. — **M**
3. **Optional static per-class table for Forever** (spell ID, level, cost, previous-rank ID) so the list works before the first trainer visit and shows all 60 levels. Must be built from our own sources (in-game trainer reads, or our own data collection), not copied from WT. — **L**
4. **Weapon-skill trainer hints** (which weapon master teaches which skill, per faction) — complements WeaponSkillWatch. — **M**
5. **Reputation discount note:** show "10% cheaper at Honored with <city>" when the stored cost came from a trainer where you were below Honored. — **S**


---

## 3. Nova Spell Rank Checker (1.63, TOC 11509/16001/20506/40403) — vs ReadyCheck

**Verdict: CLEAN.** One 340-line Lua file + LibCustomGlow + LibStub.

### Features
- A "Check Hotbar Ranks" button on the spellbook. Clicking it scans your bars, makes every button holding a lower rank than you know *glow*, and prints one chat line per offender ("Bar N Slot M: <spell link> (Rank X) Not Max Rank"). Glows clear when the spellbook closes. No automatic scanning, no saved settings.

### How it works
- **Highest known rank:** walks spellbook skill lines (Forever: `C_SpellBook.GetNumSpellBookSkillLines` / `GetSpellBookSkillLineInfo` / `GetSpellBookItemName` with the Player bank; Classic: old tab API) and keeps the max number found in each spell's subtext per spell *name*.
- **Bars:** walks *button frames by global name* (default bars incl. MultiBar5-7; or Bartender4, ElvUI, Dominos button names), reads each button's action slot, `GetActionInfo`; for **macros** it resolves the macro's spell with `GetMacroSpell`. Each spell is loaded with `Spell:CreateFromSpellID(...):ContinueOnSpellLoad` before reading its subtext, then compares the rank number by name.
- **Forever specifics:** waits for `ADDON_LOADED` of `Blizzard_PlayerSpells` and parents the button to `PlayerSpellsFrame` (Midnight-style spellbook); toggles its own button visibility from a `HookScript("OnHide")` on that frame.
- Glow is drawn **on Blizzard/bar-addon buttons** via LibCustomGlow (adds textures/animations to those buttons) — not allowed under our rules.
- Minor logic slip: the "highest rank" comparison mixes `and`/`or` without parentheses, so a first-seen rank can be overwritten oddly; harmless in practice.

### ReadyCheck comparison (cite: `ReadyCheck/ReadyCheck.lua`)
| Topic | Nova | ReadyCheck |
|---|---|---|
| Trigger | Manual button | Automatic, event-driven with debounce and combat deferral (`:641-686`) |
| Spellbook read | Name + subtext | `GetSpellBookItemInfo`, skips off-spec, falls back to `C_Spell.GetSpellSubtext`, secret-value safe (`:169-198`) |
| Bar read | Button frames by name (UI-specific) | All `NUM_ACTION_SLOTS` by slot number (`:216-238`) — UI-agnostic, better |
| **Macros** | Resolved via `GetMacroSpell` | **Skipped** — `ActionSpell` returns nil for anything not `"spell"` (`:200-214`) |
| Location shown | "Bar N Slot M" + glow on the button | Raw slot number 1-120 (`:551`) — hard to map for the user, especially stance/form pages (73-120) |
| Async spell data | `ContinueOnSpellLoad` | Reads directly; a not-yet-loaded subtext gives `nil` rank and the slot is silently skipped |
| Ignore list | None | Yes (`:598-634`) |
| Output | Chat print + glow | Hub page / status rows; slash `/rcheck` (`:688`) |

### Ranked improvements (ReadyCheck)
1. **Check macros:** when `GetActionInfo` says `"macro"`, resolve with `GetMacroSpell(id)` and compare that spell's rank (skip macros that use explicit `(Rank N)` text if we want to respect deliberate downranks — or just list them as "macro"). — **S**
2. **Human-readable slot labels:** map slot ranges to "Action Bar 1 button 3", "Bottom Left 5", "Right Bar 2", and stance/form pages ("Battle Stance bar", "Cat Form bar") for warriors/druids/rogues. — **S**
3. **Request spell data before reading subtext** (`C_Spell.RequestLoadSpellData` / `Spell:ContinueOnSpellLoad`) and rescan on `SPELL_DATA_LOAD_RESULT`, so a cold login never misses an old rank. — **S**
4. **Optional highlight in our own overlay:** a click-through frame of our own placed over the offending button (anchor only, no textures created on Blizzard's button), shown while our ReadyCheck window is open. Same "anchor only" pattern ItemAdvisor already uses for bag badges. — **M**


---

## 4. GearQuest Forever (1.1.1, interface 16001 only) — "best gear for level per slot, with source"

**Verdict: CLEAN.** 49 MB zip / 126 MB unpacked: core addon + 9 load-on-demand class addons + a language pack. License: All Rights Reserved (ideas only).

### Features (from code + project page)
- Right-click a paper-doll slot → up to three ranked "hunts" (items) for your class/spec/level, each with source, quest chain, zone, NPC, vendor price, map pins and an arrow guide; tracker, toasts when a BiS piece drops, completed/removed tabs, a lookup across all 60 levels, a simulator for other class/spec/level/faction, custom specs with your own weights, enchant suggestions, gamepad support, a "GearQuest Index" score for your current gear.

### How the "best per slot per level" data is structured
- Built offline by the author's pipeline (Python/Node scripts referenced in headers) — the addon only ships generated Lua.
- **Two tables per class** to keep size down: an *item facts* table keyed by item ID (name, quality, item level, required level, `sourceType` = vendor / quest_reward / boss_drop / raid_trash / world_drop / profession / ..., human-readable instructions, zone, NPC, proc text), and a thin *picks* table of rows `{itemId, slot, minLevel, maxLevel, rank, spec, faction, score}`. The same item appears in many level bands, so facts are stored once and picks reference them (their note says this saved ~6×).
- Levels 1-9 in a separate per-class file; 10-60 model-generated; at exactly 60 the picks come from public Classic BiS guides (`origin="guide"`), and a newer item only displaces a guide pick if it beats it by 20%.
- **Random-suffix items** are ranked on their best roll; rows carry the suffix's client ID, the chance of that suffix, and the printable stat range. They stress matching suffixes by ID, never by name (thousands of property rows share ~45 names).
- **Class data is LoadOnDemand** (`## LoadOnDemand: 1`, one addon per class); only your class (or the simulated one) is loaded — still 200-400 MB RAM per their FAQ.

### How it scores
- Generated `ScoringWeights` per class/spec, plus a **leveling multiplier table**: below 60, stamina/health/hp5 weights ×3, armor/int/spirit/mp5/mana ×2 (survival and downtime first). A simpler `StatWeights` table has a `levelling_1_9` fallback profile.
- Proc value is added by the pipeline; an armour-class multiplier per spec; weapons ranked on DPS from the pipeline, not on these weights.
- Live comparison against what you wear is mostly by **item level delta** (×10) plus a small source bonus (quest > boss/vendor/profession), minus a large penalty for lower-tier armour unless it is clearly (8+ ilvl) better; rings/trinkets compare against the *weaker* equipped one; the hunter-can't-wear-mail-before-40 rule is enforced; 1H/2H conflicts are deliberately ignored for weapon slots.
- **Spec detection:** `GetPrimaryTalentTree` if present, else `GetTalentTabInfo` points per tab (tolerant of different return orders), else summing talent ranks; user can override.
- Tooltip lines via `TooltipDataProcessor.AddTooltipPostCall` (with an `OnTooltipSetItem` fallback for old clients). Paper-doll integration hooks `OnClick`/`OnEnter` on the character slot buttons and `CharacterFrame` show/hide — outside our rules.

### What our suite lacks / does worse
- ItemAdvisor only judges items **you already have** (bags/rewards). There is no "what should I go get for this slot at my level, and where" view. This is the single biggest functional gap vs GearQuest. (cite `ItemAdvisor/ItemAdvisor.lua:745-780`, evaluation is per owned link.)
- ItemAdvisor's profiles weight stamina moderately (e.g. warrior sta 1.6 vs str 2.2, `:94`); GearQuest's ×3 survival multiplier while leveling is much stronger. Worth a tunable "leveling survival" slider rather than a fixed choice.

### Ranked improvements
1. **"Next upgrades" window per slot** (ItemAdvisor or Dungeons): for each slot, list 2-3 known items within your level range that beat what you wear, with source (quest, dungeon boss, vendor). Source data: our own Dungeons loot table (already has itemID, boss, slot) + quest rewards we already track in LevelGuide/QuestTracker, scored with ItemAdvisor's own `Score()` via `C_Item.GetItemStats` on item IDs (load with `C_Item.RequestLoadItemDataByID`). — **L**
2. **Survival multiplier while leveling** (configurable) applied on top of profiles. — **S**
3. **Robust talent-based spec detection** (same as Pawn item 1 — one shared helper). — **S**
4. **Random-suffix awareness:** when an owned item has a suffix, show its stat range note ("this roll is low for its suffix") — optional, **M**.
5. **LoadOnDemand data split** for any big data we add later (per class / per faction modules). — **S** (architecture note)

---

## 5. AtlasLoot Classic Forever (1.3.4, interface 16001) — loot tables and BiS

**Verdict: CLEAN.** GPLv2. Fork of AtlasLootClassic; Ace3 libs.

### Features
- Browsable loot tables (dungeons, raids, world, factions, PvP, crafting, collections) in its own window; favourites lists; tooltips; a separate "BiS tooltip" addon; honor/arena calculator; currency row.
- **Forever content:** a dedicated `forever.lua` module adds the new Forever dungeons (e.g. Hall of Thanes, Ruins of Lordaeron, Excavation Site: Wetlands) with `LevelRange {minEnter, recMin, recMax}`, a "Forever Dungeons" content type, and per boss a list of `{position, itemID}` with a comment naming slot/armor. Uses `AllowLoadGameType`-free separate `*_Forever.toc` files for every module (Forever picks the `_Forever` TOC).

### How "best gear" is structured
- **Loot DB:** content → boss → difficulty → ordered `{index, itemID}` rows; item details come from the client at run time (`C_Item` + cache), so the data file stays small.
- **BiS lists = Favourites lists.** A list holds item IDs per slot; the addon marks entries as *equipped* (scans worn gear, every Blizzard equipment set, and Outfitter sets) or *obsolete*. Per-class/spec "BiS" files exist for the tooltip add-on (`AtlasBIStooltips\ClassDataBase\*.lua`), but in this build they **only register the class/spec header — no item rows are filled**, so the BiS tooltip currently shows nothing for Forever. The page's "pre-calculated BiS lists for every phase" claim is not backed by data in 1.3.4.
- BiS tooltip mechanics (when filled): item ID → set of `{class, spec, phase}` with a rank string; phase picked in a dropdown; optional "only my class"; lines added via `TooltipDataProcessor.AddTooltipPostCall` (fallback `OnTooltipSetItem` hook).

### What we can learn
- Our Dungeons data already has the same shape (dungeon → boss → `{itemID, name, boss, slot}`); AtlasLoot's `{minEnter, recMin, recMax}` triple is a nicer level model than a single range. — **S**
- "Mark equipped / in equipment set" on a loot list is cheap and useful (Dungeons loot rows: tick if you own/wear it, using ItemFinder's saved data). — **S**
- An "owned elsewhere" check across alts for a loot row (ItemFinder already stores counts). — **S**


---

## 6. Baganator (846) + Syndicator (290) — vs ItemFinder / Tooltips

**Verdict: both CLEAN.** Both ship `AGENTS.md` asking AI tools not to use the repository as a reference, and an All Rights Reserved license. Per the user's decision this review continues but stays at the level of *features and public-API facts*; no structure, code or wording from these two should be reproduced in our suite.

### Features (feature level only)
- **Syndicator** (data layer): records every character's bags, bank (incl. Forever's character bank tabs), keyring, reagent bag, equipped gear, mail (including outgoing mail to your own alts), currencies, guild bank and owned auctions; adds per-character counts to item and currency tooltips; offers a search language (keywords like item type, slot, binding, expansion, "junk", "upgrade") over all characters, plus an offline list window.
- **Baganator** (UI): replaces bag/bank windows with single-bag or category views, sorting, junk/unusable/upgrade markers (pluggable upgrade providers such as Pawn), transfers, skins.

### Forever facts we can use (public API / client behaviour, not their code)
- Forever detection by build number 16000–19999 (same as Pawn/WhatsTraining).
- On Forever the **character bank uses retail-style bank tab container IDs** (`Enum.BagIndex.CharacterBankTab_1..9`), there is **no account (warband) bank**, there **is a reagent bag** slot and a **keyring** (`Enum.BagIndex.Keyring`, size from `GetKeyRingSize()` because `C_Container.GetContainerNumSlots` doesn't report it). 5 bag slots.
- Profession-skill changes can change "unusable" status; Forever needs `SKILL_LINES_CHANGED`/`PLAYER_ENTERING_WORLD` to notice.
- Tooltip post-calls: `tooltip.processingInfo.getterName` tells which getter filled the tooltip (`GetHyperlink`, `GetItemKey`, `GetMerchantItem`, ...), useful to recover the right item link; `processingInfo.excludeLines` marks scans you should not decorate.

### Our helpers (cite `ItemFinder/ItemFinder.lua`, `Tooltips/Tooltips.lua`)
- ItemFinder stores counts **by item name** (`:23-43`), not item ID — breaks if the client language changes and merges different items that share a name; stores bags 0..NUM_TOTAL_EQUIPPED_BAG_SLOTS (`:45-51`) — **misses the keyring**; finds bank containers by scanning `Enum.BagIndex` names containing "bank" (`:53-64`) — works, but the explicit CharacterBankTab range is clearer; **no mail tracking** (items mailed to alts vanish from counts until opened); search is `/find` chat output (`:236`).
- Tooltips already uses `TooltipDataProcessor` + getter source (`:131-140`) and dedupes against other helpers' lines (`:231-252`) — on par.

### Ranked improvements
1. **Key ItemFinder by item ID** (keep name for display); migrate old saves. — **M**
2. **Add keyring** to bag scan (`Enum.BagIndex.Keyring` + `GetKeyRingSize()`). — **S**
3. **Mail tracking:** read inbox on `MAIL_INBOX_UPDATE` (attachments per mail via `GetInboxItem`/`GetInboxItemLink`), store as a "mail" place with expiry; no hooks needed for the inbox side. — **M**
4. **Search window** (own frame with edit box and results by character/place) to replace `/find` chat output. — **M**
5. **Simple filters in search** (slot, quality, bound, "upgrade" using ItemAdvisor's verdict). — **M**

---

## 7. DungeonJournal / ForeverDungeonJournal (1.7.4, interface 16001) — vs Dungeons

**Verdict: CLEAN.** 82 MB unpacked, mostly 357 TGA boss portraits / art. Sends a throttled version string on its own addon-message prefix (guild/party), nothing else networked.

### Features
- Own journal window: dungeon cards (filter to Forever-new dungeons), boss pages with loot, quests per dungeon (giver, objective, prerequisites, faction, class-only, rewards, chains, shareability), entrances and long-route travel help ("Show on Map" with drawn routes for confusing approaches), world-map markers/overlay, LFG shortcut, favourites, a loot filter (class-usable only, by stat), tooltip "source" line (boss/quest + dungeon) on any item in the journal, RPG Mode (dungeons stay locked until this character kills the final boss; progress bar for quests completed), character export, 10 languages.

### How it works (mechanisms)
- **Data:** a big table keyed by dungeon name → level, description, location, entrance, bosses, quests (with `id`, level, requires, pickup/turnin, faction, rewards/choices, notes), loot. Separate files for quest chains, quest maps (coordinates), reward items, quest updates, routes, shared loot.
- **Quest completion** via `C_QuestLog.IsQuestFlaggedCompleted` (old global fallback) to tick dungeons whose quests are all done.
- **Kill detection:** `ENCOUNTER_END`, `BOSS_KILL`, plus `UNIT_DIED`/`PARTY_KILL` GUIDs — their comment states Forever closes `COMBAT_LOG_EVENT*` to addons. (Important constraint for us too.)
- **Item ID learner:** Forever-new items are entered with ID 0 until known; the addon asks the client for item IDs *near* the dungeon's known new IDs (new items of one dungeon are numbered together) with `C_Item.RequestLoadItemDataByID`, paced by `C_Timer.After(0.25)`, matching by name; it also learns IDs from tooltips, loot windows, rolls, chat links, bags and gear; learned IDs persist in saved variables.
- Tooltip source line via `TooltipDataProcessor`; uses `issecretvalue` guards; opens Forever's LFG window (`LFGParentFrame`/`LFGBrowseFrame` via `LFGVanilla_ToggleFrame`/`ToggleGroupFinderFrame`). Several `HookScript`s on world map/LFG frames — outside our rules.

### Our Dungeons helper (work in progress, cite `Dungeons/Data.lua` header)
- Same data shape already (dungeon → bosses, quests `{title, questIDs, giver, where, level, min, note}`, loot `{itemID, name, boss, slot}`, entrance with mapID/x/y). Alliance-only today.

### Ranked improvements (Dungeons)
1. **"Item source" tooltip line** for any item in our Dungeons loot table ("Drops from <boss> — <dungeon>, lvl a-b") via `TooltipDataProcessor`, built from our own data. — **S**
2. **Quest done ticks** with `C_QuestLog.IsQuestFlaggedCompleted` for every quest ID we store; "all quests done" mark per dungeon. — **S**
3. **Boss kill memory** from `ENCOUNTER_END`/`BOSS_KILL` (no combat log on Forever) to show "killed on this character". — **S**
4. **Class-usable / stat filter** for the loot list, reusing ItemAdvisor's class tables (`ItemAdvisor/ItemAdvisor.lua:118-141`). — **S**
5. **Level triple** `{minEnter, recMin, recMax}` instead of a single range. — **S**
6. **Horde data** (quests/givers) — **M**
7. **Unknown-ID resolution:** for loot rows with no ID, try IDs adjacent to the dungeon's known new IDs and match by name (throttled), remembering hits. — **M**


---

## Overall top 10 (ranked by player value ÷ effort)

| # | Improvement | Helper | Size |
|---|---|---|---|
| 1 | Auto-detect role from talent points (`GetPrimaryTalentTree` → `GetTalentTabInfo` fallback) + role picker in our own window; drop the `/ia role` dependency | ItemAdvisor | S |
| 2 | Check macros on bars (`GetMacroSpell`) and show readable bar/button names (incl. stance/form pages) | ReadyCheck | S |
| 3 | Spellbook cross-check so trained/learned spells leave the list without a trainer revisit | TrainerNotes | S |
| 4 | Item-source tooltip line + quest-done ticks + boss-kill memory (ENCOUNTER_END/BOSS_KILL; combat log is closed on Forever) | Dungeons | S |
| 5 | Weapon pair finder (2H vs best MH+OH pair from bags, and vice versa) instead of "compare it yourself" | ItemAdvisor | M |
| 6 | Key ItemFinder by item ID, add keyring, then mail tracking | ItemFinder | M |
| 7 | "Next upgrades per slot" window: items in your level range from our Dungeons loot + tracked quest rewards, scored by ItemAdvisor, with source | ItemAdvisor + Dungeons | L |
| 8 | Leveling survival multiplier (stamina/armor) as a tunable, plus optional second-role tooltip line | ItemAdvisor | S |
| 9 | Own windows for TrainerNotes (Ready/Upcoming/Blocked + cost vs gold) and ItemFinder search; retire `/trainer` and `/find` chat output | TrainerNotes, ItemFinder | M |
| 10 | Request spell data before reading ranks (`C_Spell.RequestLoadSpellData`, `SPELL_DATA_LOAD_RESULT`) and time-budgeted bulk evaluation | ReadyCheck, ItemAdvisor | S |

## Notable techniques seen (all compatible with our rules unless marked)
- TOC `[AllowLoadGameType camelot]` / `[ExcludeLoadGameType classic]` and `[Game]` path token (Forever = "camelot"); separate `*_Forever.toc` files also work.
- Forever detection: interface/build 16000–19999.
- `LoadOnDemand` per-class data addons to keep memory down.
- Store item *facts* once and thin per-level *pick* rows referencing them.
- Random suffixes: match by suffix ID, not name.
- `tooltip.processingInfo.getterName/getterArgs` to know where a tooltip came from; `excludeLines` to skip scan tooltips.
- Time-budget throttle returning "unknown, retry" for expensive per-item work.
- Forever closes the combat log to addons; use `ENCOUNTER_END`, `BOSS_KILL`, `UNIT_DIED`/`PARTY_KILL`.
- Character bank on Forever = `Enum.BagIndex.CharacterBankTab_1..9`; keyring size via `GetKeyRingSize()`; reagent bag present.
- Not for us: Pawn/Nova/GearQuest hooks on Blizzard tooltips, bag buttons, paper doll and spellbook; glows drawn onto action buttons; WhatsTraining's batch "train all" purchases.
