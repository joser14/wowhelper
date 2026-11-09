# Popular QoL, routing and profession addons for WoW Forever: malware check and read-only review (group C)

Date: 2026-11-09. Addons: Leatrix Plus (Forever), Leatrix Maps, Shortest Path Forever, SkillUp Forever, ForeverPlus,
Tweaks Forever, OneForAll - Forever, Glowing Bars.

Method: download from the official source (repo linked on CurseForge, or the CurseForge/author file) into
`scratchpad\downloads\<Addon>`; malware check first (extension census, magic bytes, obfuscation, network use); then
read-only review. Everything below is in my own words; no code or data was copied into the suite.

Downloads log and per-addon findings are appended below as each addon is finished.

## Downloads and malware check

Root: `C:\Users\you\AppData\Local\Temp\claude\cb2f3a55e03b1ab7\c31d37c7-e117-4d9f-bde3-ec6d36fbc336\scratchpad\downloads\<Addon>`.
Git clones used `GIT_LFS_SKIP_SMUDGE=1`, hooks disabled, depth 1, no submodules. Zips from the CurseForge API download
link of the Forever file named on the project page. Nothing installed or executed.

| Addon | Source | File / commit | Size |
|---|---|---|---|
| Leatrix Plus | CurseForge file 9471872 (no public repo) | Leatrix_Plus-1.60.29-forever.zip, sha256 6358B721...6CC3 | 572,269 B |
| Leatrix Maps | CurseForge file 9467345 (no public repo) | Leatrix_Maps-1.60.28-forever.zip, sha256 C3225270...4B36 | 24,678,875 B |
| ForeverPlus | CurseForge file 9493145 (no repo; page links only donations) | ForeverPlus-1.0.7.zip, sha256 1B51118C...EF9 | 738,377 B |
| Shortest Path Forever | https://github.com/cjber/shortest-path-forever | e3a85fd (release 1.24.1, 2026-11-09) | 85.2 MB incl. .git |
| SkillUp Forever | https://github.com/cjber/skillup-forever | 2f67dedd (2026-11-09, page says v1.1.6) | 20.9 MB incl. .git |
| Tweaks Forever | https://github.com/cjber/tweaks-forever | 70c20a2 (2026-11-09, page says v2.4.2) | 31.6 MB incl. .git |
| OneForAll - Forever | https://github.com/smoergi/OneForAll_Forever | 96fd21c (6.2.1, 2026-11-08) | 68.9 MB incl. .git |
| Glowing Bars | https://github.com/vattiss/wowkit (monorepo) | 7f3ecab (release 2.8.2) | 5.5 MB incl. .git |

Checks: extension census; magic bytes of every file (MZ, PK, 7z, ELF, RAR, Mach-O, Lua bytecode, `#!`); Lua scan for
`loadstring/RunScript/setfenv/load(/string.dump`, escaped-byte strings, `string.char` chains, URLs, addon/chat messaging;
lines over 3,000 chars inspected.

Verdicts (all CLEAN, no folder deleted):
- **Leatrix Plus**: 8 Lua, 2 XML, 1 BLP. Only PK is the downloaded zip itself. URLs are Wowhead/armory links shown in
  copy boxes (user copies them). One `RunScript` with a fixed literal (opens Edit Mode). `SendChatMessage` only in
  user-triggered features (share map pin to a channel, a boss-orb callout). Long lines are NPC-ID lists. No obfuscation.
- **Leatrix Maps**: 5 Lua, 2 XML, 6 BLP (map overlay art, why the zip is 24 MB). Nothing flagged.
- **ForeverPlus**: 63 Lua, 1 TGA. Nothing flagged; `load(` hits are `Reload` names; URLs are comments and the project page.
- **Shortest Path / SkillUp / Tweaks** (same author, same layout): addon code is Lua listed in the TOC; `tools/` holds
  Python generators, shell scripts, a C++ test and TrinityCore patches used offline to bake nav data (dev only, not in
  the TOC, not run). `#!` hits are those scripts. Addon messaging only in `Core/PeerStats.lua` (opt-in leaderboard to
  guild/group). `loadstring` + empty `setfenv` sandbox is used to read QuestieDB's zone tables, which Questie stores as
  Lua source text: normal. Tweaks `tools/forever_tools/interface_paths.txt` is a zlib+base64 list of client file paths
  with a header saying so, used by a dev lint, not shipped in the TOC. Long lines in `Data/RoadEdges.lua` are numeric
  road graph data.
- **OneForAll**: 128 Lua, TGA/BLP art. Addon messages (guild recipe sharing, profile share by whisper, party dungeon
  quest share, version check), all wrapped in pcall, no chat spam. Long lines are dungeon map coordinates.
- **Glowing Bars**: repo holds TypeScript (TypeScriptToLua) source, docs, tests, CI; no Lua or binaries. No suspicious
  package scripts seen. The shipped Lua is built in CI, so the review is of the TS source.

AI notes: none of the eight asks AI tools not to use it. Glowing Bars' docs say openly that an AI writes most of its
code; the cjber repos carry `.claude/skills` release helpers. SkillUp and Tweaks locales are marked machine translated.

