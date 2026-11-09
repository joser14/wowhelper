# Popular quest and map addons for WoW: Forever (interface 16001) - malware check and read-only review

Date: 2026-11-09. Scope: Questie, Forever Quest Pins, Forever Quest Tint, Zone Info: Forever, HandyNotes +
HandyNotes: WoW Forever, TomTom. Compared against our LevelGuide, QuestTracker, QuestCheck, ZoneLevels, Landmarks.

Rules followed: downloads only into the session scratchpad (`scratchpad\downloads\<Addon>`), nothing installed or run,
malware check before reading code, findings in own words, no code or data copied.

## Downloads

All under `C:\Users\you\AppData\Local\Temp\claude\cb2f3a55e03b1ab7\c31d37c7-e117-4d9f-bde3-ec6d36fbc336\scratchpad\downloads\`.

| Folder | Source (linked from CurseForge page) | Method | Size on disk | Version / commit |
|---|---|---|---|---|
| Questie | https://github.com/Questie/Questie | git clone --depth 1 | 1557 files, 171.0 MB (incl. .git) | 26111d1, 2026-11-09 (v12.6.4, `Questie_Forever.toc` = Interface 16001) |
| QuestieDB | https://github.com/Questie/QuestieDB (Questie's OptionalDep, separate addon) | git clone --depth 1 | 673 files, 417.7 MB | c1b50fe, 2026-11-08 (v1.0.13 source mode) |
| ForeverQuestPins | https://github.com/TylerAkins/forever-quest-markers | git clone --depth 1 | 95 files, 2.2 MB | 4bec28e, 2026-11-08 (v0.4.2) |
| ForeverQuestTint | https://github.com/alexdia25/forever-quest-tint | git clone --depth 1 | 61 files, 5.6 MB | c8883cd, 2026-11-09 (0.7.3) |
| ZoneInfoForever | no repo; CurseForge file 9497936 -> `ZoneInfoForever-1.10.0.zip` (mediafilez.forgecdn.net/files/9497/936/) | zip + Expand-Archive | 56,321 bytes zip, 6 entries | 1.10.0, 2026-11-07 |
| HandyNotes | https://repos.curseforge.com/wow/handynotes (CurseForge "Source") | git clone --depth 1 | 69 files, 118 KB | 438a547, 2026-10-02 "Update for Forever" |
| HandyNotes_WoWForever | https://github.com/kemayo/wow-handynotes-forever (issues link on CF page) | git clone --depth 1 | 44 files, 47 KB | 05cf4e4, 2026-10-04 (v3-forever) |
| HandyNotes_handler | https://github.com/kemayo/wow-handynotes-handler (the plugin's git submodule `handler`) | git clone --depth 1 | 58 files, 387 KB | cc70e83, 2026-10-18 |
| TomTom | CurseForge file 9493883 -> `TomTom-v4.4.1-release.zip` (mediafilez.forgecdn.net/files/9493/883/) | zip + Expand-Archive | 11,790,690 bytes zip, 120 entries | v4.4.1, 2026-11-07, Forever flavor |
| TomTom_cfrepo_2021 | https://repos.curseforge.com/wow/tomtom (CF "Source" link) | git clone --depth 1 | 125 files, 7.2 MB | bc7ab3a, **2021-06-29** - stale, not used; the release zip was reviewed instead |

Zip entries were listed before extraction; no absolute or `..` paths.

## Malware check (done before reading any code)

Method: every file grouped by extension; unexpected extensions listed; first bytes of every file checked for MZ, PK,
7z, ELF, `#!`, RAR, gzip, Lua bytecode; Lua/XML/TOC grepped for loadstring/load, RunScript, string.char chains,
base64/hex/decimal-escape blobs, setfenv/getfenv, URLs, addon/chat message sends, and protected or CVar-writing calls.

| Addon | Verdict | Notes |
|---|---|---|
| Questie | **Clean** (dev binaries removed) | Runtime: Lua/XML/TOC + images only. Flagged dev-only items in `ExternalScripts(DONOTINCLUDEINRELEASE)\`: `BLPNG Converter.exe` (MZ, unsigned, 1,045,504 B, SHA-256 4E62068C...5F46) and `DBCDumper\out\DBC-dump-UnpackMe.7z` (70 MB, SHA-256 2B0B024F...23F0). Both are excluded from releases by folder name; neither is referenced by the TOC. Not run; **deleted** from the download as a precaution. Build/CI: build.py, changelog.py, upload-cf.sh, upload-wago.sh, validate-bundle.sh, .dockerfiles, 7 GitHub workflows, `cli\` Lua test harness (uses loadstring/setfenv to load files in tests) - normal. `loadstring` in runtime code only on the zone DB's own committed string data. Network: only AceComm addon messages (party quest sharing) and a version check; no URLs used at runtime. SetCVar: `instantQuestText` (option), `calendarShowDarkmoon` (holiday detection). `docs\wow-frame-dragging.md` is written *for* AI agents (not a ban). |
| QuestieDB | **Clean** (dev binaries removed) | Runtime: Lua data + loader. Flagged: `tools\lua-binary\lua.exe` (MZ, unsigned) and `tools\lua-binary\linux-x64\lua` (ELF); hashes match the repo's own SHA256SUMS; used by the generator scripts. Not run; **deleted**. 43 Python tools, generate.sh/.cmd, questiedb.ps1 - build tooling, not run. `loadstring` is used by design: data and locale files are committed Lua table text wrapped in long strings and compiled lazily on first read (a load-time/memory technique, not obfuscation). Long "hex" hits are a CBOR test fixture and a padded probe TOC. No runtime network. |
| ForeverQuestPins | **Clean** | 15 Lua, 1 XML, 4 TGA. Go tooling (cmd/fqp, internal/*) builds the DB from QuestieDB and checks the Battle.net version endpoint - dev only, not run. GitHub workflow pulls QuestieDB preview releases. Lua writes one CVar (`showInGameNavigation`, user option) and mirrors text into a CVar for copy-paste (see findings). No addon messages. |
| ForeverQuestTint | **Clean** | 4 Lua + TOCs + TGA. `logo\*.py` image generators and `.webp` screenshots - not run. `tests\harness.lua` defines its own load helper. Nothing network-related. |
| ZoneInfoForever | **Clean** | 2 Lua, 1 TOC, 1 TGA, 1 MD. No hits at all. |
| HandyNotes | **Clean** | 11 Lua, 1 XML, packager/luacheck config, CI yml. Only URLs are XML schema and locale comments. |
| HandyNotes_WoWForever + handler | **Clean** | 6 Lua (data) + 26 Lua handler; `bin\updateHandler.sh` dev script, not run. No network. |
| TomTom 4.4.1 | **Clean** | 52 Lua, 5 XML, TGA/BLP/MP3, `Images\Arrow.m2` (a 3D model asset for the arrow; not an executable format, no MZ/PK/ELF header). `modules\comm.lua` sends addon messages to party/raid/guild to share waypoints (user action). |

No addon contains a note asking AI tools not to use it.
