-- Progress kept across route edits (research\guides_deep_re.md 12.14): the guide remembers each route's step
-- keys (as hashes, per character); when Routes.lua changes, the old and new key lists are matched (longest
-- common subsequence, then a changed step in place between two kept ones), and skips, visits, points, marks
-- and spot corrections follow their steps to the new keys. ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.best, M.pos, M.level = 1438, { [1438] = { 0.5, 0.5 } }, 6
local R
local function V1()
    return {
        { t = "accept", q = "Q1", npc = "Giver A", x = 50, y = 50, lvl = 5 },
        { t = "go", text = "Up the hill", x = 52, y = 52, lvl = 5 },
        { t = "turnin", q = "Q1", npc = "Giver A", x = 50, y = 50, lvl = 5 },
        { t = "accept", q = "Q2", npc = "Giver B", x = 40, y = 40, lvl = 5 },
        { t = "accept", q = "Q3", npc = "Giver C", x = 30, y = 30, lvl = 5 },
    }
end
M.load(ADDON_PATH, function()
    R = { zone = "Teldrassil", min = 1, max = 20, steps = V1() }
    LevelGuideRoutes.chains.NightElf = { R }
    LevelGuideQuestIDs = { ids = {}, renamed = {} }
    LevelGuidePrereqs = {}
end)
local function rows()
    local t = {}
    for _, b in ipairs(M.buttons) do if b.shown and b.step then t[#t + 1] = b.left.text end end
    return table.concat(t, "\n")
end
M.update()
local base = "Teldrassil|accept|Q2||Giver B"
M.char.skips[base] = true
M.char.visited["Teldrassil|go|Up the hill||"] = true
M.update()
assert(not rows():find("Q2", 1, true), "skipped before the edit: " .. rows())

-- The route is edited: a new first step, Q2's giver renamed (its key changes), Q3 kept.
R.steps = V1()
table.insert(R.steps, 1, { t = "accept", q = "Q0", npc = "Giver Z", x = 49, y = 49, lvl = 5 })
R.steps[5].npc = "Giver Bee"
M.update()
local moved = "Teldrassil|accept|Q2||Giver Bee"
assert(M.char.skips[moved] and M.char.skips[base] == nil, "the skip followed its step")
assert(M.char.visited["Teldrassil|go|Up the hill||"], "an unchanged key keeps its visit")
assert(not rows():find("Q2", 1, true), "still skipped after the edit: " .. rows())
assert(rows():find("Q0", 1, true), "the new step shows: " .. rows())
print("1 ok")

-- The planner's matcher on its own.
local P = LevelGuidePlanner
local map = P.MatchSteps({ 1, 2, 3, 4 }, { 9, 1, 2, 7, 4 })
assert(map[1] == 2 and map[2] == 3 and map[3] == 4 and map[4] == 5, "kept, and a changed step in place")
map = P.MatchSteps({ 1, 2, 3 }, { 1, 3 })
assert(map[1] == 1 and map[3] == 2 and map[2] == nil, "a removed step maps nowhere")
assert(P.KeyHash("abc") == P.KeyHash("abc") and P.KeyHash("abc") ~= P.KeyHash("abd"), "hash")
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
