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

