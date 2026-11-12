# Cross-addon review: how the helpers work together, from the player's side

Scope: the hub's new view-button row, the hub's Options and Manage switches, default window positions,
data one helper reads from another, shared tooltips and sounds. The four per-area reviews
(`final_review_*.md`) are not repeated here.

Tests: `tests\test_xreview_ui_hub.lua`, `tests\test_xreview_ui_tracker.lua`, `tests\test_xreview_ui_dungeons.lua`.
Each one failed before its fix and passes after it. `tests\test_final_hub_views.lua` and
`tests\test_r5a_levellog.lua` were updated for the new behaviour. `tests\runall.ps1`: 0 failed.

## Fixed (ranked)

1. **BUG: QuestTracker.lua `PlaceDefault`. Our tracker sat on top of Blizzard's.**
   - Since 02ff8e4, Blizzard's tracker stays visible by default. Both trackers default to the right edge,
     just under the minimap, so our panel covered Blizzard's tracker and its quest-item buttons.
   - Fix: when Blizzard's tracker is shown, not clear, and its edges overlap our default spot, the panel
     sits 8 px to the left of it.
   - The tracker's edges are only read, through `pcall` and `Safe`, and nothing is written to it. An
     unreadable or secret edge, a hidden tracker, a tracker moved elsewhere in Edit Mode, a clear tracker
     (right-click) or a dragged position all keep the old behaviour.
2. **BUG: ForeverHub.lua `ViewClicked`. The Level log window couldn't be closed from the hub.**
   - The Level log page opens LevelLog's window too ("open with the page", on by default).
   - Clicking "Open window" toggled the window off. Because the toggle returned no text, the hub then ran
     the page again, and that reopened the window. The button could open the window but never close it.
   - Fix: an action button that returns no text leaves the page as it is. The button is renamed
     "Show or hide window".
3. **BUG: LevelLog window covered the Level log page.**
   - The window is 480 px wide at CENTER +260, and the hub window is 680 px wide at CENTER. Both are HIGH
     strata, so the window opened over most of the page text it came with.
   - On a 16:9 screen there is no room to put both side by side.
   - Fix: "Open this window with the hub's Level log page" is now off by default. Existing saves are moved
     over once (`pageDefault2`). The page's button opens the window, and the page text says where it is.
4. **BUG: two sounds for one finished quest. Hub alert chime and QuestTracker's "Quest complete".**
   - QuestTracker plays "Quest complete" 0.5 s after the log update. Its next layout then sends
     "Ready to turn in: ...", and the hub answers with the whisper chime.
   - In combat, the pop-up waits until combat ends, so the chime came a second time, later.
   - Fix (ForeverHubExtras.lua `AlertKind`): while QuestTracker is loaded and its "Quest complete" sound
     is on, the quest pop-up counts as playing its own sound, the same way RareWatch does. The taskbar flash
     stays. The switch is read from `QuestTrackerDB.sounds.complete.on` only, so no new global is added.
5. **UX: hub view buttons showed for addons that aren't loaded.**
   - Example: ForeverGuides disabled. Gold goal still showed "Money sources" and "Auction sales", and
     Places showed seven pin buttons. Each one only answered "This addon isn't turned on."
   - Fix: `ViewsFor` returns no buttons when the page's command isn't registered. The page still says the
     addon is off.
6. **CLUTTER: ForeverHelper's window sat on the quest trackers.**
   - Its default spot is RIGHT -20, +100 (320 x 138), on the right edge between about 215 and 355 px from
     the top. Both trackers and our panel start there (under a minimap that ends near 230). It was shown by
     default and repeats the hub side panel's XP and gold rates.
   - Fix: a new install with the hub starts with the window closed. Saves that had it open keep it open,
     and without the hub it still opens.
   - The to-dos were only visible in that window. The Characters page now lists them, so "add Buy bags"
     shows up where you typed it. "Own window" opens the window.
7. **BUG (stale cache): Dungeons → ItemAdvisor upgrade answers.**
   - Dungeons kept each item's "upgrade?" answer until your gear or level changed.
   - ItemAdvisor's role follows your talents (TRAIT_CONFIG_UPDATED, PLAYER_TALENT_UPDATE,
     CHARACTER_POINTS_CHANGED), so after a talent change the dungeon list kept the old role's upgrades.
   - Right after a level-up, UnitLevel can still return the old level. Answers read in that second were
     kept too.
   - Fix: Dungeons listens for the same three talent events (checked in uisrc2: plain events, not
     CallbackEvents) and forgets its answers again 2 s after a level-up or talent change.

## Checked, no change needed

- **Every view button reaches a real handler**, and each handler handles its word:
  - GoldGoal: sources, sales
  - GoldGuide: all, tips
  - Dungeons: all
  - ProfessionGuide: craft, shopping, and a profession name through `FindGuide`
  - QuestMobs: `list` (toggle)
  - ItemFinder: expiring
  - Builds: all and the goal words
  - WeaponSkillWatch and RepWatch: "" and all
  - SpellReady: ignored
  - Landmarks: the seven kinds
  - RareWatch: all
  - ForeverHelper and LevelLog: window

  Every answer goes through `ForeverHub_Receive`, which the hub captures. There is no chat output on these
  paths. The UIErrorsFrame fallbacks run only without the hub, as already recorded.
- **Hub Options rows persist and change behaviour:**
  - Alert sound and flash: `ForeverHubDB.alerts`, read in `OnPopup`.
  - AutoQuest Accept, Turn in and Gray: `AutoQuestDB`, read by `Option()` on every path.
  - DeathNotes Zone danger and Elite danger: `DeathNotesDB._options`. Nothing iterates DeathNotesDB's
    realms, so the `_options` key is safe.
  - Helper Off: `ForeverHubDB.off`.
- **Tooltips:**
  - ItemAdvisor (registered at PLAYER_LOGIN, loads before Tooltips in ForeverBags) adds its verdict
    first. Tooltips sees it and leaves out "Upgrade for you".
  - ItemFinder's "Owned:" line and PriceMemory's price line are added only when Tooltips isn't there, so
    Tooltips' own lines never repeat them.
  - QuestMobs adds unit lines (drop chances); Tooltips adds NPC ID and quest-giver lines. They don't overlap.
  - Every post-call is registered once (QuestMobs and Tooltips are guarded; the others register at
    PLAYER_LOGIN only), and TooltipDataProcessor rebuilds the tooltip on refresh, so no line is added twice.
- **Shared data with the other addon missing:**
  - Tooltips reads `ItemFinderDB`, `PriceMemory_Get`, `ItemAdvisor_IsUpgrade`, `LevelGuideRoutes` and
    `LevelGuideQuestIDs`. Each read is type-checked and inside pcall.
  - QuestTracker reads `LevelGuideQuestFacts` lazily, at call time, so the addons' load order doesn't
    matter. It returns nil without LevelGuide.
  - The hub reads `LevelLog_KillsToLevel` and `LevelLog_ToSixty` behind a type check and an Off check.
- **LevelGuide arrival sound vs QuestTracker sounds:**
  - The arrival sound is off by default and plays once per arrival edge. QuestTracker's sounds play when
    the log changes.
  - They only meet if you are standing at the turn-in NPC when the quest completes (see the in-game checks).

## Not fixed (owner decision or needs the game)

- **DONE (owner decision, 11 November 2026): Off on the Manage page now hides a helper's own frames.**
  - Before, Off hid only pages, side panel lines and pop-ups, so QuestTracker, QuestMobs, ItemAdvisor,
    WindowBadges, ZoneLevels, LevelLog and ForeverHelper kept their own frames on screen.
  - The hub now calls `ForeverHubOnSwitch[name](off)` right after a switch (no reload). Each of these
    helpers registers there and also reads `ForeverHub_IsOff` at login. Without the hub nothing changes.
    - QuestTracker: panel hidden, no quest sounds, no reads, Blizzard's tracker left alone. Its panel holds
      secure item buttons, so a switch in combat waits for PLAYER_REGEN_ENABLED. Back On: same spot and fold.
      If you had made Blizzard's tracker clear (right-click), Off doesn't write to Blizzard's frame to undo
      that: it stays clear until the next /reload, when it shows again.
    - QuestMobs: markers, list window and drop-chance tooltip lines gone, no tooltip reads.
    - ItemAdvisor: overlay hidden (bag badges, reward marks), no tooltip line, nothing painted.
      `ItemAdvisor_IsUpgrade` still answers other helpers.
    - WindowBadges: overlay hidden, no badges placed.
    - ZoneLevels: no warning, and its note (only used without the hub) hides.
    - LevelLog and ForeverHelper: window hidden and can't be opened. A window you had open comes back On;
      ForeverHelper saves your choice, not the forced hide.
  - The Manage page, its switch tooltip and the Options page say so.
  - Test: `tests\test_off_hides_frames.lua`.
- **DONE: QuestMobs list window position.** The old default (TOPRIGHT -260, -220) overlapped our tracker by
  about 34 px. Until you drag it, the window now opens just left of our tracker panel, level with its top
  (the spot is copied, not anchored: the panel holds secure buttons). Without a shown tracker, or no room
  left of it, it goes to TOPRIGHT -300, -220. A dragged spot is kept.
- **NIT: Dungeons doesn't see a role picked by hand on ItemAdvisor's page.** ItemAdvisor has no event or
  public counter for that. The answers refresh on the next gear, level or talent change.
- **NIT: Profession view buttons need `ForeverSkillProfessions`** (ProfessionCap or GoldGuide).
  ProfessionGuide's own `ReadProfessions` isn't public, so if both addons are missing there are no
  per-profession buttons. Typing a profession still works.

## In-game checks

1. Log in with Blizzard's tracker visible and one quest watched. Our panel should sit just left of
   Blizzard's tracker, with no overlap. Right-click our header (make Blizzard's tracker clear) and our panel
   should move back under the minimap.
2. Hub > Level log. The window should not open by itself. "Show or hide window" should open it and close it.
3. Finish a quest: you should hear one sound (QuestTracker's) and see one pop-up. Switch QuestTracker's
   "Quest complete" sound off, finish another quest, and the hub's chime should play.
4. Disable ForeverGuides and reload. Gold goal, Gold guide, Dungeons and Profession guide should show no
   view buttons.
5. New character with no ForeverHelper save: the ForeverHelper window should start closed. On the
   Characters page, type `add Test` and the to-do should appear on the page.
6. Spend a talent point that changes ItemAdvisor's role, then open Dungeons: the upgrade counts should follow.
7. Manage page, switch QuestTracker Off: the panel goes at once. On: it's back where it was. Switch it Off
   during a fight: it goes when the fight ends, with no "blocked" message.
8. Switch QuestMobs, ItemAdvisor (open your bags) and WindowBadges (at a vendor) Off and On: markers, bag
   coins and arrows, and badges go and come back without a /reload.
9. Open the Level log window and ForeverHelper's window, switch each helper Off and On: the window closes and
   reopens. Close one, switch Off and On: it stays closed.
10. QuestMobs `list on` with Blizzard's tracker visible: the list window sits left of our tracker, not on it.

## Summary

The new button row reaches a real handler on every page and writes nothing to chat. Two problems came from
helpers working together.
- **Level log page:** its window could not be closed from the hub, and it opened over the page.
- **Defaults after "Blizzard's tracker visible":** our tracker sat on Blizzard's, ForeverHelper's window
  sat on both trackers, and a finished quest played two sounds.

Smaller issues: buttons for addons that aren't loaded, and stale Dungeons upgrade answers after talent
changes and level-ups. All seven are fixed and covered by tests. Nothing writes to Blizzard frames, hooks
anything, registers combat-log or CallbackEvent events, prints to chat or automates anything.

The owner's decision on Off is now built: a helper switched Off on the Manage page hides its own frames too,
and shows them again when switched On, without a reload.
