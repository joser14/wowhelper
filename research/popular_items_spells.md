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

