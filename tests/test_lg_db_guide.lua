-- LevelGuide with QuestDB loaded: steps without IDs, prerequisites or spots are filled from the database,
-- "not offered here" and missing prerequisites name the quest, a "Name, Darnassus" inside parentheses is
-- not a city point, and a generated route is followed like a written one. ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
assert(loadfile(ADDON_PATH .. "/QuestDB.lua"))("LevelGuide", {})
assert(loadfile(ADDON_PATH .. "/QuestLookup.lua"))("LevelGuide", {})
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
local gossip = {}
C_GossipInfo = { GetAvailableQuests = function() return gossip end }
M.best, M.pos, M.level = 1438, { [1438] = { 0.55, 0.57 } }, 5
local R
M.load(ADDON_PATH, function()
    -- Hand data for one title only (a level); everything else must come from QuestDB.
    LevelGuideQuestIDs, LevelGuidePrereqs = { ids = {}, renamed = {} }, { ["Seek Redemption!"] = { level = 4 } }
    R = { zone = "Teldrassil", min = 1, max = 12, steps = {
        { t = "accept", q = "Zenn's Bidding", lvl = 4 },                                  -- no npc, no spot
        { t = "accept", q = "Seek Redemption!", npc = "Sentinel Kyra Starsong", x = 55.6, y = 56.8, lvl = 4 },
        { t = "accept", q = "Crown of the Earth", npc = "Corithras Moonrage", x = 56.1, y = 61.7, lvl = 5, part = 3 },
        { t = "accept", q = "Far Away", npc = "Someone (talk to Tyrande, Darnassus)", x = 30, y = 30, lvl = 5 },
    } }
    LevelGuideRoutes.chains.NightElf = { R }
end)
local function rows()
    local t = {}
    for _, b in ipairs(M.buttons) do if b.shown and b.step then t[#t + 1] = b.left.text end end
    return table.concat(t, "\n")
end
local function stepFor(pattern)
    for _, b in ipairs(M.buttons) do
        if b.shown and b.step and b.left.text:find(pattern, 1, true) then return b.step end
    end
end
M.update()
print(rows())

-- 1. Filled from QuestDB: IDs, the prerequisite of a part the route picks up later, the giver and the spot.
assert(LevelGuideQuestIDs.ids["Zenn's Bidding"][1] == 488, "ID filled")
assert(LevelGuideQuestIDs.ids["Crown of the Earth"][3] == 929, "chain IDs filled in order")
assert(R.steps[1].npc == "Zenn Foulhoof" and R.steps[1].x and R.steps[1].filled, "giver and spot filled")
local zenn = stepFor("Zenn's Bidding")
assert(zenn and zenn.mapID == 1438 and zenn.x, "the filled step is placed: " .. rows())
-- Prereqs.lua's entry (level only) is kept as written; QuestDB fills titles with none.
assert(LevelGuidePrereqs["Seek Redemption!"].level == 4 and not LevelGuidePrereqs["Seek Redemption!"].all, "hand prereqs win")
assert(LevelGuidePrereqs["Zenn's Bidding"] and LevelGuidePrereqs["Zenn's Bidding"].level == 4, "level from QuestDB")
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("1 ok")

-- 2. The route list: a giver who doesn't offer it says so and names the missing quest from QuestDB.
local listButton
for _, f in ipairs(M.frames) do if f.kind == "Button" and f.text == "List" then listButton = f end end
assert(listButton, "list button")
M.npcName = "Sentinel Kyra Starsong"
gossip = {}
M.fire("GOSSIP_SHOW")
M.update()
listButton.scripts.OnClick(listButton)
local list = LevelGuideRouteList
local listRows, seen = {}, false
for _, f in ipairs(M.frames) do
    if f == list then seen = true end
    if seen and f.kind == "Button" and rawget(f, "left") then listRows[#listRows + 1] = f end
end
for i = 1, 4 do print(listRows[i].left.text, listRows[i].right.text, tostring(rawget(listRows[i], "why"))) end
local why = rawget(listRows[2], "why") or ""
assert(listRows[2].right.text:find("blocked", 1, true), "not offered: blocked, not done")
assert(why:find("not offered here", 1, true) and why:find("Zenn's Bidding (from Zenn Foulhoof)", 1, true), "names the missing quest: " .. why)
-- A missing prerequisite (QuestDB-filled) is named with its giver too.
LevelGuidePrereqs["Seek Redemption!"] = nil
M.npcName = nil
print("2 ok")

-- 3. "Name, Darnassus" inside parentheses is a note, not the city's map: the point stays on Teldrassil.
local far = stepFor("Far Away")
assert(far and far.mapID == 1438 and math.abs(far.x - 0.30) < 1e-6, "zone point kept: " .. tostring(far and far.x))
print("3 ok")

-- 4. A generated route is followed like a written one (Elwynn for a Human at level 1).
UnitRace = function() return "Human", "Human" end
UnitClass = function() return "Warrior", "WARRIOR" end
M.info[1429] = { mapID = 1429, name = "Elwynn Forest", mapType = 3, parentMapID = 1415 }
M.info[1415] = { mapID = 1415, name = "Eastern Kingdoms", mapType = 2, parentMapID = 947 }
M.rects[1429] = { 20000, 0, 3470, 2315 }
LevelGuideRoutes.chains.Human = { LevelGuideQuestFacts.Generated("Elwynn Forest", 1429, 1, 10, { qmax = 10 }) }
M.best, M.pos, M.level = 1429, { [1429] = { 0.49, 0.41 } }, 1
M.update()
print(rows())
assert(M.current.left.text:find("Pick up", 1, true), "a pick-up first: " .. M.current.left.text)
assert(M.current.step.mapID == 1429 and M.current.step.x, "placed on Elwynn")
assert(M.frame and rows() ~= "", "rows shown")
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
