# Cross-review: the suite as it ships (build.ps1, bundles, .toc files, globals, slash commands, events)

Date: 11 November 2026. Scope: what `.\build.ps1` (no `-Install`) puts in `dist\`, read as one installed suite.
The four per-area final reviews (`final_review_*.md`) are not repeated here.

Method:
- Ran `.\build.ps1` and listed `dist\`: six bundles, 73 `.lua` files, six `.toc` files and one `Bindings.xml`.
- Compiled every shipped file with fengari and walked the bytecode of every function (`GETTABUP`/`SETTABUP` on
  `_ENV`, with keys from `LOADK` for files over 256 constants): every global read and write, every field written
  into a global table, upvalue and register counts, and every string constant.
- Checked every name the suite writes against the Blizzard UI source (`uisrc2`, 647 files): no overlap.
- Pulled the 12 `CallbackEvent = true` events from the API docs in `uisrc2` and searched every shipped string.

## Findings

### 1. NIT (fixed): build.ps1 could ship an incomplete suite without a word
`build.ps1` built only the helpers named in `$Bundles` and copied only the files each `.toc` lists. Nothing checked
the other direction:
- a helper folder with a `.toc` that is in no bundle was silently left out of `dist\`;
- a `.lua` in a helper folder that its `.toc` doesn't list was silently not shipped. The tests load files by their
  own lists, so such a file passes every test and then never loads in game;
- two helpers declaring the same saved variable (they would overwrite each other's data) or a `.toc` with an
  Interface other than 16001 went unnoticed.

Today none of these happens (all 35 helper folders are in exactly one bundle, every `.lua` is listed, the 29
saved variables are unique, every `.toc` says 16001), so nothing was broken; the build just wouldn't have told us.

Fix: `Test-Helpers` in `build.ps1` runs before the build and stops it with a list of every problem. Exercised on a
scratch copy of the repo: a stray `Stray.lua`, a new `NewHelper\NewHelper.toc` outside the bundles, a `.toc`
listing a missing file, Interface 11507 and a second `BuildsDB` were each reported; the real repo builds as before.

### 2. NIT (not changed): bundle .toc files drop the helpers' OptionalDeps
Helper `.toc` files name cross-helper dependencies (GoldGuide on PriceMemory, Tooltips on ProfessionGuide,
Dungeons and LevelGuide, WindowBadges on TrainerNotes, MapPins on LevelGuide, GoldGuide, Dungeons and ZoneLevels).
The bundles only say `OptionalDeps: !ForeverHub`, so the game loads them alphabetically: Bags, Character, Guides,
Quests, World. Tooltips (Bags) and WindowBadges (Bags) therefore load before the helpers they read.

Verified harmless: of the 29 cross-bundle global reads, none runs at file load (all are inside functions), and
none is cached at load: Tooltips re-indexes when `ProfessionGuideData`/`LevelGuideRoutes` change, WindowBadges
reads `TrainerNotesData` per scan, ItemFinder decides about its tooltip line at PLAYER_LOGIN (after every addon
has loaded). Within each bundle the order is right: no file reads, at load, a global that a later file defines.
Adding cross-bundle OptionalDeps would make a cycle (Bags needs Guides for Tooltips, Guides needs Bags for
GoldGuide), so it's left as is. Anyone adding a load-time cross-bundle read must keep it lazy.

### 3. NIT (not changed): `/way` is also TomTom's command
`SLASH_FOREVERWAY1 = "/way"` (MapPins\Way.lua:155). If a player also installs TomTom, whichever loads last owns
`/way`; `/fway` stays ours. By design (README documents `/way`); noted only.

## Checked and clean

| Check | Result |
|---|---|
| Every folder with a `.toc` is in a bundle | All 35, each in exactly one. |
| Every `.lua` listed, data before code | All 73 listed; no file reads at load a global defined by a later file of its bundle (data files `Data*.lua`, `QuestIDs`, `FoodIDs`, `GearCurves`, `Drops` come first). |
| Nothing test-only ships | `dist\` holds only `.lua`, `.toc` and the hub's `Bindings.xml`; no tests, research, tools or BOMs. |
| Interface | 16001 in all 35 helper `.toc` files and all six bundles. |
| SavedVariables | 29 names, all unique, all declared; every `...DB` global the code writes is declared. Per-character ones stay per-character in the bundles. |
| Bundle headers | Hub keeps IconTexture and the three AddonCompartment functions, which ForeverHubExtras.lua defines. Bindings.xml calls only `ForeverHub_*` functions that exist, and guards each. |
| Hub sections | `SECTIONS`/`HELPERS` in ForeverHub.lua match `$Bundles` exactly (helper to bundle). |
| Globals | 300 global writes, all in their helper's namespace (folder or file name, `Forever*`, `SLASH_*`, `BINDING_*`); no missing `local`. Globals written by more than one helper are only the shared `Forever*` helpers, each a byte-identical copy guarded by `X = X or ...` / `if not X then`. |
| Blizzard globals | No suite name exists in the Blizzard source; no field writes into Blizzard tables (only `SlashCmdList` under our own keys, and the hub's `table.insert(UISpecialFrames, ...)` for its two windows). No `_G[...] =`, `rawset(_G)`, `setfenv`. |
| Slash commands | 33 keys and 43 command strings, all unique; no `SlashCmdList = SlashCmdList or {}` anywhere. |
| Restricted events | None of the 12 CallbackEvents (COMBAT_LOG_*, MINIMAP_PING, ENCOUNTER_STATE_CHANGED, TOOLTIP_SHOW_ITEM_COMPARISON, CLASS_TALENTS_SWITCH_*) appears as a string in any shipped file; the one hit is a comment in DeathNotes.lua. Loops that register events iterate literal lists. |
| Combat | Secure templates only in QuestTracker (item buttons, placed and shown only out of combat) and the hub's hearth button (created, moved and shown only out of combat, anchored to UIParent). No other protected calls; `SetSuperTrackedQuestID` is not restricted (docs: SecretArguments only). |
| Lua 5.1 | The tests run on Lua 5.3, the game on 5.1. No 5.3-only operators or library calls (`table.unpack` only as `unpack or table.unpack`), no `goto`. Most upvalues in one function: 37 (5.1 allows 60); most registers: 209 (250). |
| Paths | No `Interface\AddOns\<Helper>\...` asset paths, which would break inside a bundle. |

## Test

`tests\test_xreview_pack_globals.lua` reads all 73 shipped files as compiled code (nothing runs) and fails on: a
global outside the helper's namespace (a missing `local`), a write into a table that isn't ours, a non-shared
global with two owners, a duplicate slash key or command, a CallbackEvent name, a 5.3-only operator, more than 60
upvalues or 250 registers in a function. A built-in probe proves each check fires. Full suite: 0 failed.

## Summary

The suite ships cleanly: every helper and file is in its bundle in a working order, the `.toc` headers and saved
variables are right, there are no global leaks or clashes, no Blizzard writes, no restricted events and nothing
that the game's Lua 5.1 would reject. The one change is a guard in `build.ps1` so a helper or file left out of the
bundles, a clashing saved variable or a wrong Interface stops the build instead of shipping silently, plus a test
that keeps the globals, slash commands, events and Lua 5.1 limits checked from now on.
