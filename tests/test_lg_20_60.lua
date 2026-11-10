-- 20-60 route data: the fixes from research\routes_20_60.md section 4, the missing zones wired into the
-- chains and the plan, and the side steps (priest training, buys, keeps, flight paths, hearths).
-- ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.info[1442] = { mapID = 1442, name = "Stonetalon Mountains", mapType = 3, parentMapID = 1414 }
M.load(ADDON_PATH)
local chains, ids, pre = LevelGuideRoutes.chains, LevelGuideQuestIDs.ids, LevelGuidePrereqs
local routes, all = {}, {}
for _, chain in pairs(chains) do
    for _, route in ipairs(chain) do
        if not all[route] then
            all[route] = true
            routes[#routes + 1] = route
        end
    end
end
local function steps(pred)
    local found = {}
    for _, route in ipairs(routes) do
        for _, s in ipairs(route.steps) do
            if pred(s, route) then found[#found + 1] = { step = s, route = route } end
        end
    end
    return found
end
local function byQ(t, q) return steps(function(s) return s.t == t and s.q == q end) end

-- 1. Section 4.1 fixes.
assert(#steps(function(s) return s.q and s.q:find("^Wanted!") end) == 0, "no 'Wanted!' titles left")
for title, id in pairs({ ["WANTED: Marez Cowl"] = 684, ["WANTED: Otto and Falconcrest"] = 685 }) do
    assert(#byQ("accept", title) == 1 and #byQ("turnin", title) == 1, "Arathi " .. title)
    assert(ids[title] and ids[title][1] == id, "IDs keyed by the Forever title: " .. title)
end
local fiora = byQ("accept", "Fiora Longears")
assert(#fiora >= 1, "Fiora Longears kept")
for _, f in ipairs(fiora) do assert(f.step.lvl >= 30, "Fiora Longears at 30+, not " .. f.step.lvl) end
assert(pre["Fiora Longears"] and pre["Fiora Longears"].level == 30, "Fiora needs level 30")
for _, title in ipairs({ "Crocs of the Sky", "Anything of Value" }) do
    -- Unverified in Forever's data: no quest ID (it could be someone else's) and the pick-up says so.
    assert(ids[title] == nil, "no unverified ID for " .. title)
    for _, f in ipairs(byQ("accept", title)) do assert(f.step.npc:find("unverified", 1, true), title .. " marked") end
end
for _, t in ipairs({ "accept", "turnin" }) do
    for _, f in ipairs(byQ(t, "Supplies to Private Thorsen")) do
        if f.step.npc:find("Thorsen", 1, true) then assert(f.step.x == 40.3 and f.step.y == 8.4, "Thorsen spawn") end
    end
end
assert(byQ("accept", "Jungle Secrets")[1].step.x == 40.3, "Jungle Secrets from Thorsen's spawn")
assert(byQ("accept", "Bodyguard for Hire")[1].step.x == 66.5 and byQ("accept", "Bodyguard for Hire")[1].step.y == 37.5, "Cork Gizelton")
assert(byQ("accept", "Gizelton Caravan")[1].step.x == 45.4 and byQ("accept", "Gizelton Caravan")[1].step.y == 75.3, "Rigger Gizelton")
for _, band in ipairs(LevelGuideRoutes.plan) do
    assert(not (band.note or ""):find("opens at 33", 1, true), "Riverglades opens at 36")
    for _, z in ipairs(band.zones) do
        if z == "Riverglades" then assert(band.min >= 36, "Riverglades from 36") end
    end
    if band.min == 36 then assert(band.hub:find("Farholde Keep", 1, true) and not band.hub:find("Powderfuse", 1, true), "36-41 hub") end
end
-- Item-started quests: an Item or Keep step for the starting drop.
for item, title in pairs({ [9250] = "Ship Schedules", [11463] = "Thalanaar Delivery", [8704] = "Find OOX-09/HL!",
    [11116] = "Williden's Journal", [11668] = "Flute of Xavaric", [13140] = "A Strange Red Key",
    [12771] = "Winterfall Firewater", [12842] = "The Final Piece" }) do
    local keep = steps(function(s) return s.t == "keep" and s.item == item and s.forQ == title end)
    local collect = steps(function(s) return s.t == "item" and s.item == item end)
    assert(#keep >= 1 and #collect >= 1, "item start " .. title)
end
print("1 ok")

-- 2. The missing zones, in min-level order in every chain; Riverglades has no stop list yet.
local zones = {}
for _, route in ipairs(routes) do zones[route.zone] = route end
for _, z in ipairs({ "Stonetalon Mountains", "Redridge Mountains", "Westfall", "Dustwallow Marsh", "Badlands", "Swamp of Sorrows",
    "Searing Gorge", "Azshara", "Thousand Needles", "Blasted Lands" }) do
    assert(zones[z] and #zones[z].steps >= 10, "route for " .. z)
end
-- Riverglades is a generated route (QuestDB.lua); forever-db has no quests for it yet, so it has no steps.
assert(zones["Riverglades"] and zones["Riverglades"].generated and #zones["Riverglades"].steps == 0, "Riverglades waits for giver data")
for race, chain in pairs(chains) do
    for i = 2, #chain do
        -- An optional side trip (Stonetalon after Ashenvale) may sit up to 4 levels early.
        assert(chain[i].min >= chain[i - 1].min - 4, race .. ": ordered by min at " .. (chain[i].name or chain[i].zone))
    end
end
local function inChain(race, zone)
    for _, r in ipairs(chains[race]) do if r.zone == zone then return true end end
end
for _, z in ipairs({ "Stonetalon Mountains", "Dustwallow Marsh", "Swamp of Sorrows", "Badlands", "Searing Gorge", "Azshara",
    "Blasted Lands", "Thousand Needles" }) do
    assert(inChain("NightElf", z), "Night Elf chain has " .. z)
end
assert(inChain("Human", "Westfall") and inChain("Human", "Redridge Mountains"), "Human 10-25")
assert(inChain("Dwarf", "Badlands") and inChain("Gnome", "Redridge Mountains"), "Dwarf/Gnome")
local planned = {}
for _, band in ipairs(LevelGuideRoutes.plan) do for _, z in ipairs(band.zones) do planned[z] = true end end
for _, z in ipairs({ "Stonetalon Mountains", "Dustwallow Marsh", "Badlands", "Swamp of Sorrows", "Searing Gorge", "Azshara", "Blasted Lands" }) do
    assert(planned[z], "plan names " .. z)
end
-- Alterac/Dalaran add-ons fold into Hillsbrad; Wetlands Excavation and Shen'dralas are optional notes.
assert(#steps(function(s, r) return r.zone == "Hillsbrad Foothills" and s.map == "Alterac Mountains" end) >= 3, "Alterac in Hillsbrad")
assert(#byQ("accept", "Friend of the Kirin Tor") == 1, "Dalaran")
assert(#steps(function(s, r) return r.zone == "Wetlands" and ((s.note or "") .. (s.npc or "")):find("Excavation Site", 1, true) end) >= 1, "Excavation notes")
assert(#steps(function(s, r) return r.zone == "Desolace" and (s.map == "Shen'dralas" or (s.npc or s.note or ""):find("Valley of Bones", 1, true)) end) >= 1, "Valley of Bones")
print("2 ok")

-- 3. Side steps across 20-60.
local trainers = {}
for _, f in ipairs(steps(function(s) return s.t == "trainer" and s.cls == "PRIEST" end)) do trainers[f.step.atLevel] = true end
for level = 20, 60, 2 do assert(trainers[level], "priest training at " .. level) end
local fps = {}
for _, f in ipairs(steps(function(s) return s.t == "fp" end)) do fps[f.step.place] = true end
for _, place in ipairs({ "Astranaar", "Stonetalon Peak", "Menethil Harbor", "Theramore", "Thorium Point", "Talrendis Point",
    "Nethergarde Keep", "Lakeshire", "Sentinel Hill", "Southshore", "Refuge Pointe", "Gadgetzan" }) do
    assert(fps[place], "flight path " .. place)
end
assert(#steps(function(s) return s.t == "home" and s.place == "Theramore" end) == 1, "Theramore hearth")
assert(#steps(function(s) return s.t == "buy" and (s.text or ""):find("Wand", 1, true) ~= nil and s.lvl >= 25 end) >= 3, "wand buys 20-60")
assert(#steps(function(s) return s.t == "bags" and s.lvl >= 20 end) >= 2, "bag space 20-60")
assert(#steps(function(s)
    local text = s.text or ""
    return s.t == "buy" and s.lvl >= 25 and (text:find("Juice", 1, true) or text:find("Nectar", 1, true) or text:find("Dew", 1, true)) ~= nil
end) >= 3, "water tiers")
assert(#steps(function(s) return s.t == "keep" and s.lvl >= 20 end) >= 12, "keeps for quest-starting drops")
assert(#byQ("accept", "Velinde Starsong") == 1 and #byQ("turnin", "The Carevin Family") == 1, "Moonbeam Wand chain")
print("3 ok")

-- 4. Night Elf priest at 25 in Stonetalon: the Stonetalon route runs there.
M.best, M.pos, M.level = 1442, { [1442] = { 0.37, 0.08 } }, 25
M.update()
assert(M.font("Route: Stonetalon Mountains"), "Stonetalon route")
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
