-- The route-choice card (research\guides_deep_re.md 12.17): where the chain forks (two or more next routes
-- with work at your level, and none in the zone you stand in), a card lists each with its quests, XP and
-- about how long it takes; until you pick, the guide takes the best ranked (not out-levelled, then nearer
-- in 60 s bands, then the chain's order). Your pick is kept per character. ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.best, M.pos, M.level = 1438, { [1438] = { 0.5, 0.5 } }, 12
M.info[1440] = { mapID = 1440, name = "Ashenvale", mapType = 3, parentMapID = 1414 }
LevelGuideQuestXP = { q = { [901] = "900", [902] = "1100|12:8", [911] = "700" } }
M.load(ADDON_PATH, function()
    LevelGuideRoutes.chains.NightElf = {
        { zone = "Teldrassil", min = 1, max = 12, steps = {} },
        { zone = "Darkshore", min = 11, max = 20, steps = {
            { t = "accept", q = "Shore One", npc = "A", x = 36, y = 45, lvl = 11 },
            { t = "turnin", q = "Shore One", npc = "A", x = 36, y = 45, lvl = 11 },
        } },
        { zone = "Ashenvale", min = 11, max = 20, steps = {
            { t = "accept", q = "Ash One", npc = "B", x = 34, y = 48, lvl = 11 },
            { t = "accept", q = "Ash Two", npc = "B", x = 34, y = 48, lvl = 11 },
            { t = "do", q = "Ash Two", note = "Wolves", x = 40, y = 50, lvl = 11 },
            { t = "turnin", q = "Ash One", npc = "B", x = 34, y = 48, lvl = 11 },
            { t = "turnin", q = "Ash Two", npc = "B", x = 34, y = 48, lvl = 11 },
        } },
    }
    LevelGuideQuestIDs = { ids = { ["Shore One"] = { 911 }, ["Ash One"] = { 901 }, ["Ash Two"] = { 902 } }, renamed = {} }
    LevelGuidePrereqs = {}
end)
local function card() return LevelGuideRouteCard and LevelGuideRouteCard.shown and LevelGuideRouteCard end
local function header() local f = M.font("Route: ") return f and f.text or "" end
M.update()

-- 1. The card lists both, with what each holds.
assert(card(), "a card at the fork")
local text = LevelGuideRouteCard.message.text
local ash, shore
for i = 1, 3 do
    local b = _G["LevelGuideRouteChoice" .. i]
    if b and b.shown and b.label and b.label.text:find("Ashenvale", 1, true) then ash = b end
    if b and b.shown and b.label and b.label.text:find("Darkshore", 1, true) then shore = b end
end
assert(ash and shore, "both offered: " .. text)
assert(ash.label.text:find("2 quests", 1, true) and ash.label.text:find("2,000 XP", 1, true), "Ashenvale's numbers: " .. ash.label.text)
assert(shore.label.text:find("1 quest", 1, true), "Darkshore's numbers: " .. shore.label.text)
print("1 ok")

-- 2. Picking Ashenvale: kept per character, the guide follows it, the card goes.
ash.scripts.OnClick(ash)
M.update()
assert(header():find("Route: Ashenvale", 1, true), "following the pick: " .. header())
assert(not card(), "card gone")
local kept = 0
for _, v in pairs(M.char.routeChoice or {}) do kept = kept + 1; assert(v == "Ashenvale", "saved: " .. tostring(v)) end
assert(kept == 1, "one choice kept")
print("2 ok")

-- 3. The ranking on its own: out-levelled last, then nearer (60 s bands), then the chain's order.
local P = LevelGuidePlanner
local ranked = P.RankRoutes({
    { id = "a", order = 1, outleveled = true, travel = 10 },
    { id = "b", order = 2, travel = 400 },
    { id = "c", order = 3, travel = 130 },
    { id = "d", order = 4, travel = 170 },
})
assert(ranked[1].id == "c" and ranked[2].id == "d" and ranked[3].id == "b" and ranked[4].id == "a", "ranked: "
    .. ranked[1].id .. ranked[2].id .. ranked[3].id .. ranked[4].id)
-- Time: talking 6 s a stop, kills by level, running 7 yd/s.
local s = P.RouteSeconds({ stops = 4, kills = { { n = 8 } }, yards = 700, level = 12 })
assert(math.abs(s - (24 + 8 * (11 + 19 * 11 / 59) + 100)) < 0.01, "seconds: " .. s)
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
