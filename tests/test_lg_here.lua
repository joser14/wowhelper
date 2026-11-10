-- "While you're here" (research\guides_deep_re.md 1.6 and 12.5): later route turn-ins you could hand in on a
-- short detour (20 s, doubled when waiting costs XP; always at the NPC) and later work within 180 yd, at most
-- 3 lines, nothing in combat; a line can be dismissed (120 s and 100 yd; twice: for the zone stay).
-- ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.best, M.pos, M.level = 1438, { [1438] = { 0.5, 0.5 } }, 6
local R
M.load(ADDON_PATH, function()
    R = { zone = "Teldrassil", min = 1, max = 20, steps = {
        { t = "accept", q = "Q1", npc = "Giver A", x = 50, y = 50, lvl = 5 },
        { t = "do", q = "Q1", note = "Far work", x = 70, y = 70, lvl = 5 },
        { t = "go", text = "Go to the far glade", x = 90, y = 90, lvl = 5 },
        { t = "turnin", q = "Q2", npc = "Giver B", x = 50.4, y = 50.4, lvl = 5 },
        { t = "do", q = "Q3", note = "Near work", x = 51, y = 50, lvl = 5 },
        { t = "do", q = "Q4", note = "Too far work", x = 60, y = 50, lvl = 5 },
        { t = "turnin", q = "Q1", npc = "Giver A", x = 50, y = 50, lvl = 5 },
    } }
    LevelGuideRoutes.chains.NightElf = { R }
    LevelGuideQuestIDs = { ids = { Q1 = { 401 }, Q2 = { 402 }, Q3 = { 403 }, Q4 = { 404 } }, renamed = {} }
    LevelGuidePrereqs = {}
end)
local P = LevelGuidePlanner
local function here()
    local t = {}
    for _, b in ipairs(M.buttons) do
        if b.shown and b.step and b.left.text:find("While you're here", 1, true) then t[#t + 1] = b end
    end
    return t
end
local function hereText()
    local t = {}
    for _, b in ipairs(here()) do t[#t + 1] = b.left.text end
    return table.concat(t, "\n")
end
M.log = {
    { questID = 401, title = "Q1" },
    { questID = 402, title = "Q2", ready = true },
    { questID = 403, title = "Q3" },
    { questID = 404, title = "Q4" },
}
for id = 401, 404 do M.obj[id] = { { text = "x: 0/5", finished = false, numFulfilled = 0, numRequired = 5 } } end

-- 1. The arithmetic.
assert(math.abs(P.DetourSeconds(100, 300, 350) - 50 * 1.25 / 7) < 1e-9, "detour seconds")
assert(P.TurninShows(25, 999, false, false), "at the NPC")
assert(not P.TurninShows(300, 0, false, false), "beyond 250 yd")
assert(P.TurninShows(200, 19, false, false) and not P.TurninShows(200, 30, false, false), "20 s budget")
assert(P.TurninShows(200, 30, true, false), "doubled when waiting costs XP")
assert(P.TurninShows(90, 99, false, true), "resting within 100 yd")
print("1 ok")

-- 2. At the turn-in NPC (28 yd) and near later work (50 yd): both listed; far work (500 yd) is not.
M.update()
local text = hereText()
assert(text:find("Turn in:|r Q2", 1, true), "turn-in here: " .. text)
assert(text:find("Do:|r Q3", 1, true), "work within 180 yd: " .. text)
assert(not text:find("Q4", 1, true), "work 500 yd away: " .. text)
assert(not text:find("Q1", 1, true), "the current step isn't repeated: " .. text)
print("2 ok")

-- 3. A detour that costs more than 20 s hides the turn-in (one on the way shows).
M.pos[1438] = { 0.48, 0.48 }
M.update()
assert(hereText():find("Q2", 1, true), "on the way to the current step: " .. hereText())
M.pos[1438] = { 0.53, 0.47 }
M.update()
assert(not hereText():find("Q2", 1, true), "a 30 s detour: hidden: " .. hereText())
M.pos[1438] = { 0.5, 0.5 }
print("3 ok")

-- 4. Nothing in combat.
UnitAffectingCombat = function() return true end
M.update()
assert(#here() == 0, "paused in combat")
UnitAffectingCombat = function() return false end
print("4 ok")

-- 5. Dismiss: right-click mutes for 120 s and until you've moved 100 yd; a second dismiss for the zone stay.
M.update()
local row
for _, b in ipairs(here()) do if b.left.text:find("Q3", 1, true) then row = b end end
assert(row, "Q3 row")
row.scripts.OnClick(row, "RightButton")
M.update()
assert(not hereText():find("Q3", 1, true), "dismissed")
M.now = M.now + 200
M.update()
assert(not hereText():find("Q3", 1, true), "120 s passed but you haven't moved")
M.pos[1438] = { 0.5, 0.52 }
M.update()
assert(hereText():find("Q3", 1, true), "moved 100 yd and 120 s: back: " .. hereText())
for _, b in ipairs(here()) do if b.left.text:find("Q3", 1, true) then row = b end end
row.scripts.OnClick(row, "RightButton")
M.now = M.now + 500
M.pos[1438] = { 0.5, 0.5 }
M.update()
assert(not hereText():find("Q3", 1, true), "second dismiss: muted for the zone stay")
print("5 ok")

-- 6. At most 3 lines.
for i = 1, 4 do
    local id = 410 + i
    LevelGuideQuestIDs.ids["W" .. i] = { id }
    R.steps[#R.steps + 1] = { t = "do", q = "W" .. i, note = "w", x = 50 + i * 0.3, y = 50.5, lvl = 5 }
    M.log[#M.log + 1] = { questID = id, title = "W" .. i }
    M.obj[id] = { { text = "x: 0/5", finished = false, numFulfilled = 0, numRequired = 5 } }
end
M.update()
assert(#here() == 3, "three lines at most: " .. #here())
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
