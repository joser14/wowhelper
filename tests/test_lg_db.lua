-- QuestDB.lua (generated from forever-db by tools\gen_questdb.js) and QuestLookup.lua: decoding, titles to
-- IDs in chain order, prerequisites, spots and camps, filling what route steps lack, generated routes.
-- ADDON_PATH = LevelGuide.
assert(loadfile(ADDON_PATH .. "/QuestDB.lua"))("LevelGuide", {})
assert(loadfile(ADDON_PATH .. "/QuestLookup.lua"))("LevelGuide", {})
local F = LevelGuideQuestFacts
local function near(a, b, tol) return a and b and math.abs(a - b) <= (tol or 0.6) end

-- 1. Data shape: Alliance and neutral quests only, decoded lazily.
local count = 0
for _ in pairs(LevelGuideQuestDB.q) do count = count + 1 end
assert(count > 3000 and count < 4500, "quest count " .. count)
assert(LevelGuideQuestDB.version and LevelGuideQuestDB.maps[1438] == "Teldrassil" and LevelGuideQuestDB.maps[1457] == "Darnassus", "maps")
assert(F.Quest(2) == nil, "Horde-only quest 2 dropped")
local q = F.Quest(456)
assert(q and q.title == "The Balance of Nature" and q.min == 1 and q.level == 2, "456")
assert(q.givers[1].kind == "npc" and q.givers[1].id == 2079, "giver ref")
assert(#q.objectives == 2 and q.objectives[1].kind == "kill" and q.objectives[1].count == 7, "objectives")
local camp = q.objectives[1].spots[1]
assert(camp.map == 1438 and camp.x > 50 and camp.x < 70 and camp.r and camp.r >= 15 and camp.n and camp.n >= 1, "spawn camp with radius and count")
assert(#q.objectives[1].spots <= 6, "at most six camps")
print("1 ok")

-- 2. Places: givers on the Classic maps, Darnassus as its own map.
local map, x, y, name = F.GiverSpot(456)
assert(map == 1438 and near(x, 58.7) and near(y, 44.3) and name == "Conservator Ilthalaine", "Ilthalaine: " .. tostring(x) .. "," .. tostring(y))
map = F.GiverSpot(98046)
assert(map == 1457, "Fandral is on the Darnassus map: " .. tostring(map))
map, x, y = F.GiverSpot(783)
assert(map == 1429 and near(x, 48.2) and near(y, 42.9), "Deputy Willem, Elwynn")
local dx, dy = F.Project(1457, 50, 50, 1438)
assert(dx and dx > 20 and dx < 40 and dy > 45 and dy < 70, "Darnassus inside Teldrassil's frame: " .. tostring(dx) .. "," .. tostring(dy))
assert(F.Project(1438, 50, 50, 1429) == nil, "other continent")
print("2 ok")

-- 3. Titles to IDs in chain order, filtered by race and class.
local ids = F.IDsForTitle("The Balance of Nature", "NightElf", "PRIEST")
assert(ids and #ids == 2 and ids[1] == 456 and ids[2] == 457, "parts")
ids = F.IDsForTitle("Crown of the Earth", "NightElf")
assert(ids[1] == 921 and ids[2] == 928, "Crown of the Earth starts at 921")
assert(not F.Takes({ races = 8 }, "Human", nil) and F.Takes({ races = 8 }, "NightElf", nil), "race mask")
assert(not F.Takes({ races = 4294967296 }, "Human", nil) and F.Takes({ races = 4294967296 + 8 }, nil, nil), "Forever's race bit")
assert(F.Takes(F.Quest(5622), "NightElf", "PRIEST") and not F.Takes(F.Quest(5622), "NightElf", "WARRIOR"), "class mask")
print("3 ok")

-- 4. Prerequisites: breadcrumbs never needed; one-of-one is needed.
local need = F.Prereqs(457, "NightElf")
assert(need.all and need.all[1] == 456 and not need.any and need.level == 1, "457 needs 456")
need = F.Prereqs(33, "Human")
assert(not need.all and not need.any, "33's breadcrumb (5261) is not needed")
need = F.Prereqs(489, "NightElf")
assert(need.all[1] == 488 and need.level == 4, "Seek Redemption! needs Zenn's Bidding at 4")
print("4 ok")

-- 5. Fill: IDs, prerequisites, NPC names and spots only where the route has none; hand data wins.
LevelGuideQuestIDs = { ids = { ["Dolanaar Delivery"] = { 99999 } }, renamed = {} }
LevelGuidePrereqs = { ["Zenn's Bidding"] = { level = 3 } }
local R = { zone = "Teldrassil", min = 1, max = 12, steps = {
    { t = "accept", q = "Zenn's Bidding" },
    { t = "turnin", q = "Zenn's Bidding" },
    { t = "accept", q = "Seek Redemption!", npc = "Kyra", x = 10, y = 10, lvl = 4 },
    { t = "do", q = "The Balance of Nature" },
    { t = "accept", q = "Dolanaar Delivery", x = 61, y = 47 },
    { t = "turnin", q = "Crown of the Earth", part = 8 },
} }
local filled = F.Fill({ R }, "NightElf", "PRIEST")
assert(LevelGuideQuestIDs.ids["Zenn's Bidding"][1] == 488, "ID filled")
assert(LevelGuideQuestIDs.ids["Dolanaar Delivery"][1] == 99999, "hand IDs kept")
assert(LevelGuidePrereqs["Zenn's Bidding"].level == 3 and not LevelGuidePrereqs["Zenn's Bidding"].all, "hand prereqs kept")
assert(LevelGuidePrereqs["Seek Redemption!"].all[1] == 488, "prereq filled by ID")
local s = R.steps
assert(s[1].npc == "Zenn Foulhoof" and s[1].x and s[1].y and s[1].filled and not s[1].map, "giver name and spot filled")
assert(s[3].x == 10 and s[3].npc == "Kyra", "written spot and name kept")
assert(s[4].x and s[4].y, "objective spot for a do step")
assert(s[6].map == "Darnassus" and s[6].x, "a turn-in on another map gets that map: " .. tostring(s[6].map))
assert(filled.ids >= 3 and filled.places >= 3, "counts")
print("5 ok")

-- 6. Generated routes: accept before turn-in, solo quests only, spots on the zone's map.
local steps = F.BuildRoute(1429, 1, 10, "Human", "WARRIOR", "Elwynn Forest")
assert(#steps > 60, "Elwynn steps: " .. #steps)
local accepted = {}
for i, st in ipairs(steps) do
    assert(st.generated and st.x and st.y and st.x >= 0 and st.x <= 100 and st.y >= 0 and st.y <= 100, "step " .. i)
    local key = st.q .. "#" .. (st.part or 1)
    if st.t == "accept" then accepted[key] = i end
    if st.t == "turnin" then assert(accepted[key] and accepted[key] < i, "turn-in after accept: " .. key) end
    if st.t == "do" then assert(accepted[key], "do after accept: " .. key) end
end
assert(steps[1].t == "accept" and steps[1].lvl <= 2, "starts with a level 1 pick-up")
assert(#F.BuildRoute(2548, 30, 50, "Human", "WARRIOR", "Riverglades") == 0, "no Riverglades quests in forever-db 2026.11.1")
-- Excluded titles stay out.
local without = F.BuildRoute(1429, 1, 10, "Human", "WARRIOR", "Elwynn Forest", { ["A Threat Within#1"] = true })
for _, st in ipairs(without) do assert(st.q ~= "A Threat Within" or st.t ~= "accept", "excluded") end
print("6 ok")

-- 7. Routes.lua builds the generated routes lazily, into the right chains.
assert(loadfile(ADDON_PATH .. "/QuestIDs.lua"))("LevelGuide", {})
assert(loadfile(ADDON_PATH .. "/Prereqs.lua"))("LevelGuide", {})
assert(loadfile(ADDON_PATH .. "/Routes.lua"))("LevelGuide", {})
UnitRace = function() return "Human", "Human" end
UnitClass = function() return "Warrior", "WARRIOR" end
local human = LevelGuideRoutes.chains.Human
assert(human[1].generated and human[1].zone == "Elwynn Forest", "Elwynn first for Humans")
assert(rawget(human[1], "steps") == nil, "not built until read")
assert(#human[1].steps > 60 and rawget(human[1], "steps"), "built on first read")
local dwarf = LevelGuideRoutes.chains.Dwarf
assert(dwarf[1].generated and dwarf[1].zone == "Dun Morogh" and dwarf[1].max <= 6, "Coldridge first for Dwarves")
local river
for _, route in ipairs(human) do if route.zone == "Riverglades" then river = route end end
assert(river and river.generated and #river.steps == 0, "Riverglades: generated, empty until forever-db has its quests")
-- Coldridge leaves out what the hand-written Dun Morogh route picks up.
UnitRace = function() return "Dwarf", "Dwarf" end
local written = {}
for _, route in ipairs(dwarf) do
    if not route.generated then
        for _, st in ipairs(route.steps) do
            if st.t == "accept" and st.q then written[st.q .. "#" .. (st.part or 1)] = true end
        end
    end
end
assert(#dwarf[1].steps > 10, "Coldridge steps: " .. #dwarf[1].steps)
for _, st in ipairs(dwarf[1].steps) do
    assert(not (st.t == "accept" and written[st.q .. "#" .. (st.part or 1)]), "duplicate pick-up " .. st.q)
end
print("ALL TESTS PASSED")
