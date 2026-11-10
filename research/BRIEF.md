# Review brief: World of Warcraft: Forever addons

Workspace (read here, do NOT edit any file in it):
C:\Users\you\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\scratch-workspaces\c73d4152-ec25-4579-8c12-afe6c58434bb\b2b91152-4cd0-4fba-ac18-3c0d7474a45f\scratch-2026-11-04-2c8855

Blizzard UI source for this client (read-only reference, grep it to verify APIs exist and their return values):
C:\Users\you\AppData\Local\Temp\claude\cb2f3a55e03b1ab7\c31d37c7-e117-4d9f-bde3-ec6d36fbc336\scratchpad\uisrc2

## The client
- "World of Warcraft: Forever", client 1.60.1, interface 16001. It is a Classic-era world running on a Mainline/Midnight-based client.
- Many API returns are "secret values" in combat or when tainted: comparing or doing arithmetic on them errors. Addons wrap reads in a Safe() helper that uses issecretvalue/canaccessvalue. Check that every value used in arithmetic/comparison/concat goes through Safe() or is otherwise known safe.
- Taint: an addon must never Hide/Show/Update Blizzard frames, hook Blizzard functions (hooksecurefunc included unless clearly safe), call protected functions, or write into Blizzard tables/globals. The error log shows: "GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by 'QuestTracker'" with a stack through Blizzard_ObjectiveTracker -> Blizzard_MawBuffs. Find how QuestTracker taints the objective tracker's execution path.
- NEVER put addon pins into Blizzard's map canvas (WorldMapFrame:AddDataProvider, map:AcquirePin). Blizzard's map code makes protected calls on every pin in that pool; in combat the game blocks it and blames our addon ("ForeverWorld has been blocked from an action only available to the Blizzard UI", logged as "tried to use UNKNOWN()", seen in game 2026-11-09). Draw map pins as our own frames over the map instead. In general, avoid any "official" API that pulls our frames or functions into Blizzard's secure code paths.
- NEVER register COMBAT_LOG_EVENT_UNFILTERED or any event whose API doc says `CallbackEvent = true` (COMBAT_LOG_*, MINIMAP_PING, ENCOUNTER_STATE_CHANGED, CLASS_TALENTS_SWITCH_*, TOOLTIP_SHOW_ITEM_COMPARISON), not even inside pcall: the game raises ADDON_ACTION_FORBIDDEN and shows the "blocked from an action" Disable/Ignore pop-up. This, in DeathNotes, was the actual cause of the ForeverWorld pop-up on 2026-11-09.
- Map IDs are the Classic-era ones (Teldrassil 1438, Darkshore 1439, Ashenvale 1440, Darnassus 1457, Elwynn 1429, Stormwind City 1453, Kalimdor 1414, Eastern Kingdoms 1415). An earlier version of this brief said Mainline (57, 62, ...); that was wrong. Confirmed on 2026-11-09 from Zone Info: Forever, Shortest Path Forever and RestedXP's Forever database. Resolve maps by name where possible.

## The owner's rules (violations are findings)
1. Read-only: never automate sell, buy, equip, accept, turn-in, repair, abandon, or any gameplay action.
2. UI only: windows, panels, tooltips, pop-ups. No slash commands as the only way to use a feature, no chat-frame output (print/DEFAULT_CHAT_FRAME:AddMessage) except maybe a single load message.
3. No Blizzard frame manipulation, no hooks of Blizzard functions, no writes into Blizzard tables.
4. Each addon must be clean on load and over time: no nil indexing, no leaks of OnUpdate work every frame, no unbounded SavedVariables growth.

## What to report
Write your findings to the file named in your task, as Markdown. For each finding:
- Severity: BUG (wrong behavior/error), RULE (breaks an owner rule), RISK (likely to error on this client, e.g. secret value or missing API), NIT (minor).
- File:line, the claim in one sentence, the concrete failure scenario, and the fix you recommend (code snippet welcome).
Verify before reporting: read the actual code path, check the API exists in uisrc2 when you claim it does/doesn't. No speculative findings. Ranked most severe first. End with a one-paragraph summary.
Do not edit any addon file. Do not download or run third-party code; web pages may be read as text only.
