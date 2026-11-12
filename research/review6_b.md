# Review 6b: DeathNotes death recap (ef4f728) and Dungeons round 5 (0ae006b)

Scope: `DeathNotes/DeathNotes.lua` (C_DeathRecap read on timers after PLAYER_DEAD) and `Dungeons/Dungeons.lua`
(instance log, wish list, Group Finder listings, own window). Every finding below was read in the code; the
three BUGs were reproduced by failing tests first (`tests/test_cr6b_dungeons.lua`, `tests/test_cr6b_deathrecap.lua`)
and fixed. `tests/runall.ps1`: 0 failed.

## Fixed

### BUG 1: Dungeons, chain looting drops notable loot (LootClosed / CheckPending)
- Where: `Dungeons.lua`, `LootOpened` / `LootClosed` / `CheckPending` (round-5 block).
- Claim: the 1 s bag check after a loot window read `st.pending` at timer time, but the next corpse's
  `LOOT_OPENED` replaces `st.pending`, and the first timer then cleared it.
- Failure: loot corpse A (blue item), close, loot corpse B within a second (normal with several kills):
  A's item is never checked and B's pending list is wiped by A's timer, so neither reaches `run.loot`.
  Test: both items missing before the fix.
- Fix: `LootClosed` captures this window's pending list and run and passes them to its own timer closure;
  `st.lootRun` removed.

### BUG 2: Dungeons, "one more new dungeon reaches the cap" at two below the daily cap (CapState)
- Where: `CapState`, `day >= dayCap - 2`.
- Failure: 28 of 30 today (or 1 of 3) says "one more new dungeon reaches the cap"; it takes two.
- Fix: `day == dayCap - 1` (at or over the cap is already the `full` branch).

### BUG 3: DeathNotes, an old recap pinned on a new death when its timestamps are unreadable (ApplyRecap)
- Where: `DeathNotes.lua`, `ApplyRecap`.
- Claim: the "same recap read again" guard only works on the killing-blow timestamp; when the timestamps
  are secret (`ReadRecap` returns no stamp) nothing is remembered, so a later death whose recap is not
  ready yet (or never filled) gets the previous death's killer and hits.
- Fix: without a stamp, the recap is keyed by a fingerprint of its newest 5 hits (plain, already Safe'd
  values: source/spell/env/amount), stored in `db.lastRecap` like the timestamp. Cost: a genuinely new
  death with identical untimed hits keeps its target guess, which is the safe side.

## Checked, no bug
- Recap killer choice: newest timestamp, ties broken by later index; untimed falls back to the game's order
  (entry 1 = killing blow, as Blizzard's recap frame shows). Killer falls back to the next readable source.
- Secrets: every recap field goes through `Safe()` before compare, arithmetic or concat; `GetRecapEvents`
  and `HasRecapEvents` are pcall'd; the docs (DeathRecapDocumentation) show `recapID` nilable and no events.
- Timers: a second death replaces `pendingDeath`; old timers then try the new death, guarded by the
  last-recap key. Applied once: a successful apply clears `pendingDeath`, so the 3 s timer and the page do
  nothing. `Forget` and "forget all" clear the pending death. `pendingAt` uses GetTime (session only), fine.
- Bounded: deaths 200, hits 5 per death, names 40 chars, one `lastRecap`. Dungeons: runs 100, wish 150 per
  character, run loot 12, Group Finder snapshot 200 results and session-only.
- Entries per hour/day: account-wide over `DungeonsDB.runs`, `now - last < HOUR/DAY` where last is the
  leave time (or now while inside); `time()` for saved times, `GetTime()` only for the loot grace and the
  Group Finder age (both session-only).
- GUID copy: `Creature|Vehicle-0-server-instance-zoneUID-npc-spawn` parsed, zoneUID 0 ignored, secret GUIDs
  ignored; split/merge move the open visit correctly (r5d test covers both).
- Wish list: `Dungeons_IsWished` takes a number, a numeric string or a link (`item:(%d+)`); per character
  via ForeverCharacterKey.
- Group Finder: only `GetSearchResults` / `GetSearchResultInfo` / `GetActivityInfoTable` on
  LFG_LIST_SEARCH_RESULTS_RECEIVED; no Search/Apply/listing call; name and comment never read. Signatures
  match LFGListInfoDocumentation (`totalResultsFound, results`; `activityIDs`, `numMembers`, `age`,
  `isDelisted`, `hasSelf`).
- Events: every event Dungeons registers (PLAYER_LOGIN, QUEST_LOG_UPDATE, QUEST_TURNED_IN, ENCOUNTER_END,
  BOSS_KILL, UNIT_DIED, PARTY_KILL, PLAYER_TARGET_CHANGED, PLAYER_ENTERING_WORLD, ITEM_DATA_LOAD_RESULT,
  PLAYER_EQUIPMENT_CHANGED, PLAYER_LEVEL_UP, TRAIT_CONFIG_UPDATED, PLAYER_TALENT_UPDATE and the round-5
  ZONE_CHANGED_NEW_AREA, CHAT_MSG_COMBAT_XP_GAIN, PLAYER_XP_UPDATE, PLAYER_MONEY, PLAYER_DEAD, LOOT_OPENED,
  LOOT_CLOSED, UPDATE_MOUSEOVER_UNIT, NAME_PLATE_UNIT_ADDED, LFG_LIST_SEARCH_RESULTS_RECEIVED, PLAYER_LOGOUT)
  is documented in uisrc2 without `CallbackEvent = true` (the only CallbackEvents are COMBAT_LOG_*,
  ENCOUNTER_STATE_CHANGED, MINIMAP_PING, CLASS_TALENTS_SWITCH_*, TOOLTIP_SHOW_ITEM_COMPARISON). The events
  round 5 swallows (OWN) are not used by the older handler.
- Rules: no hooks, Blizzard frame writes, UISpecialFrames, map pins or chat output (all text goes through
  `Print` to the hub); window, tooltip and buttons are our own frames.

## NIT (not changed)
- `Dungeons.lua` Enter: a /reload or relog inside a dungeon counts as "went back in 1 time" (PLAYER_LOGOUT
  closes the visit, login re-enters within the window). Counts and stats are right.
- CHAT_MSG_COMBAT_XP_GAIN also fires for quest-turn-in XP, so "kills with XP" can include a quest inside.
- Gold looted only counts your own loot window; party money shares looted by others are missed. Group-loot
  rolls won after the window closes are not added to the run.
- CloseStale closes a crashed run at `seen`, which only updates on XP and zone checks, so its time inside
  and hour/day count may end early.
- Wishes whose item is no longer on a loot list still count toward the 150 and can't be removed (Toggle
  requires `R5.Source`).
- LFG_LIST_SEARCH_RESULTS_RECEIVED also fires for another addon's search; we only read, so no rule break.

## Suspicions needing the game
1. C_DeathRecap: does `GetRecapEvents()` with no recapID return the latest death, are entries killing blow
   first, are timestamps readable out of combat, and do the events survive release/resurrection?
2. Does `db.lastRecap` (a float timestamp) survive SavedVariables with full precision? If rounded, the
   stale-recap guard misses after a reload.
3. XP over a level-up: if PLAYER_LEVEL_UP arrives before PLAYER_XP_UPDATE while UnitXP still shows the old
   XP, `XPChanged` takes the level branch with the old XP (overcount) and then the XP drop as a second
   level-up, leaving `st.level` one ahead until the real level catches up (XP not counted meanwhile).
   Check the event order on a level-up inside a dungeon.
4. Creature GUIDs inside instances: readable (not secret) and the zoneUID differs per copy? Otherwise the
   re-entry window decides.
5. Group Finder activity `fullName`s on Forever (e.g. Scarlet Monastery wings) match our names/aliases.
6. Autoloot: is the bag count at LOOT_OPENED still the pre-loot count?

## Summary
Both commits keep the rules: no hooks, no Blizzard writes, no map pins, no CallbackEvent or combat log
registration, no automation, all output through the hub, all data bounded. Three real bugs were fixed with
tests first: notable loot lost when corpses are looted within a second of each other (Dungeons), a false
"one more reaches the cap" warning at two below the daily cap (Dungeons), and an old death recap applied to
a new death when its timestamps are secret (DeathNotes). The remaining open questions are about client
behaviour (recap API defaults and ordering, GUID readability, level-up event order) and need an in-game check.
