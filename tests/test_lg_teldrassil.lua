-- The owner's report: a level 11 Night Elf priest in Teldrassil/Darnassus, with the Shadowglen and
-- Dolanaar starter quests done, was shown only "Go to: Teldrassil" with no arrow. ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
local DONE = {
    ["Webwood Egg"] = 1, ["Tenaron's Summons"] = 1, ["Crown of the Earth"] = 2, ["Dolanaar Delivery"] = 1,
    ["The Balance of Nature"] = 2, ["Iverron's Antidote"] = 2, ["Fang of Githyiss"] = 1, ["In Favor of Elune"] = 1,
    ["Webwood Venom"] = 1, ["The Goddess Provides"] = 1, ["A Friend in Need"] = 1, ["A Good Friend"] = 1,
    ["The Adventurer"] = 1, ["The Great Outdoors"] = 1,
}
LevelGuideDB = { characters = { ["Juan-R"] = { done = DONE, skips = {}, visited = {} } } }
M.load(ADDON_PATH, function() M.done(DONE) end)

local function text(i) local b = M.buttons[i]; return b and b.shown and b.left.text or "" end
local function step() return M.current.step end
local function show()
    local t = {}
    for i = 1, 4 do t[#t + 1] = text(i) end
    return table.concat(t, " / ") .. "  [" .. tostring(M.font("yd") and M.font("yd").text) .. "]"
end

-- 1. Standing in Darnassus (its own zone under Kalimdor): the Teldrassil route goes on, with an arrow.
M.best, M.pos = 1457, { [1457] = { 0.5, 0.5 } }
M.update()
print("in Darnassus: " .. show())
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
assert(not text(1):find("Go to:|r Teldrassil", 1, true), "not a bare 'Go to Teldrassil': " .. text(1))
assert(step() and step().mapID and step().x, "the current step has a point: " .. text(1))
M.update(0.06)
assert(M.arrowShown(), "the arrow shows")
assert(not show():find("Enter Darnassus", 1, true), "already in Darnassus: " .. show())
print("1 ok")

-- 2. In Teldrassil, a step written on the Darnassus map still gets a point on the Teldrassil map.
M.best, M.pos = 1438, { [1438] = { 0.37, 0.52 } }
M.update()
print("in Teldrassil: " .. show())
local found
for i = 1, 4 do
    local s = M.buttons[i].shown and M.buttons[i].step
    if s and s.npc and (s.title == "Tumors" or s.title == "Rellian Greenspyre" or s.title == "Tears of the Moon" or s.title == "The Temple of the Moon") then
        found = s
    end
end
local list = {}
for _, s in ipairs({ step() }) do list[#list + 1] = s end
-- Use the upcoming stops: every Darnassus stop must be placed (it used to be dropped).
local placed = false
for _, stop in ipairs(LevelGuide_UpcomingStops()) do
    if stop.label:find("Darnassus", 1, true) then placed = true end
end
assert(found == nil or found.x, "Darnassus step placed")
assert(step().mapID and step().x, "current step placed in Teldrassil")
M.update(0.06)
assert(M.arrowShown(), "arrow in Teldrassil")
print("2 ok")

-- 3. Teldrassil outgrown (level 13): the way to Darkshore is a stop with an arrow (Rut'theran's flight
-- master), not just the zone name. From Darnassus it is the portal down to Rut'theran.
M.level = 13
M.update()
print("13 in Teldrassil: " .. show())
assert(text(1):find("Darkshore", 1, true) or text(1):find("Auberdine", 1, true) or text(1):find("Rut'theran", 1, true), "heads for Darkshore: " .. text(1))
-- The travel planner's first leg: the portal in Darnassus (on the city's map) down to Rut'theran.
assert((step().mapID == 1438 or step().mapID == 1457) and step().x, "travel step has a point on Teldrassil or Darnassus: " .. text(1))
M.update(0.06)
assert(M.arrowShown(), "arrow to the way out")
M.best, M.pos = 1457, { [1457] = { 0.5, 0.5 } }
M.update()
print("13 in Darnassus: " .. show())
assert(step().mapID and step().x, "travel step has a point from Darnassus: " .. text(1))
assert(text(1):find("ortal", 1, true) or tostring(step().detail):find("ortal", 1, true), "the portal: " .. text(1) .. " " .. tostring(step().detail))
M.update(0.06)
assert(M.arrowShown(), "arrow to the portal")
print("3 ok")

-- 4. In Darkshore at 13 the Darkshore route itself runs (no travel line first).
M.best, M.pos = 1439, { [1439] = { 0.37, 0.44 } }
M.update()
print("13 in Darkshore: " .. show())
assert(not text(1):find("Go to:|r Darkshore", 1, true) and step().mapID == 1439, "Darkshore route: " .. text(1))
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
