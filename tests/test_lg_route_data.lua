-- The Night Elf route data with its side steps, for the owner's priest (level 11, starter quests done).
-- ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
local DONE = {
    ["Webwood Egg"] = 1, ["Tenaron's Summons"] = 1, ["Crown of the Earth"] = 2, ["Dolanaar Delivery"] = 1,
    ["The Balance of Nature"] = 2, ["Iverron's Antidote"] = 2, ["Fang of Githyiss"] = 1, ["In Favor of Elune"] = 1,
    ["Webwood Venom"] = 1, ["The Goddess Provides"] = 1, ["A Friend in Need"] = 1, ["A Good Friend"] = 1,
    ["The Adventurer"] = 1, ["The Great Outdoors"] = 1,
}
LevelGuideDB = { characters = { ["Juan-R"] = { done = DONE, skips = {}, visited = {} } } }
M.load(ADDON_PATH, function() M.done(DONE) end)
local function side(pattern)
    for _, b in ipairs(M.buttons) do
        if b.shown and b.step and b.step.side and b.left.text:find(pattern, 1, true) then return b end
    end
end
local function rows()
    local t = {}
    for _, b in ipairs(M.buttons) do if b.shown and b.step then t[#t + 1] = b.left.text end end
    return table.concat(t, "\n")
end

-- Every route step still loads with a known kind; side steps carry what their kind needs.
for _, route in ipairs(LevelGuideRoutes.chains.NightElf) do
    for index, s in ipairs(route.steps) do
        local where = route.zone .. " #" .. index
        if s.t == "buy" then assert(s.items and s.count and s.where, where .. " buy") end
        if s.t == "trainer" then assert(s.atLevel and s.cls and s.side == "later", where .. " trainer") end
        if s.side then assert(s.side == "sticky" or s.side == "later", where .. " side") end
        if s.side == "sticky" then assert(s.span and s.span > 0, where .. " span") end
    end
end

-- 1. Level 11 priest in Dolanaar: the level 10 training shows "for later" with Laurna's point.
M.best, M.pos, M.level = 1438, { [1438] = { 0.556, 0.57 } }, 11
M.update()
print(rows())
local train = side("Level 10 spells")
assert(train and train.step.mapID == 1438 and train.step.x, "trainer visit for later with a point:\n" .. rows())
M.spells[8092] = true; M.update()
assert(not side("Level 10 spells"), "Mind Blast known: done")
-- A warrior gets none of the priest stops.
M.class = "WARRIOR"; M.spells = {}; M.update()
assert(not side("Level 10 spells") and not rows():find("Returning Home", 1, true), "no priest stops for a warrior")
M.class = "PRIEST"
print("1 ok")

-- 2. In Darnassus: "Enter Darnassus" is done by being there, and the city's own steps (written on the
-- Darnassus map) are placed and get the arrow.
M.best, M.pos = 1457, { [1457] = { 0.45, 0.5 } }
M.update()
print(rows())
assert(not rows():find("Enter Darnassus", 1, true), "in the city already")
assert(M.current.step.mapID == 1438 and M.current.step.x, "current step placed: " .. M.current.left.text)
M.update(0.06)
assert(M.arrowShown(), "arrow in Darnassus")
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("2 ok")

-- 3. Darkshore at 12: bag space for later; Melon Juice waits for 13+; the trainer is in Darnassus.
M.best, M.pos, M.level = 1439, { [1439] = { 0.37, 0.44 } }, 12
M.update()
print(rows())
assert(side("Bag space"), "bags for later:\n" .. rows())
assert(side("Bag space").step.detail:find("16/40", 1, true), "bag slots shown")
assert(not side("Melon Juice"), "Melon Juice not yet")
M.level = 13; M.update()
assert(side("Melon Juice"), "Melon Juice from 13 (needs 15)")
M.level = 14; M.update()
local t14 = side("Level 14 spells")
assert(t14 and t14.step.mapID == 1439, "level 14 training, pointed toward Darnassus:\n" .. rows())
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
