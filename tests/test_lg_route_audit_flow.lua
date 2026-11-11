-- The guide on the Night Elf 20-30 plan (Routes.lua ASHENVALE_FIRST / STONETALON / WETLANDS_FIRST / DUSKWOOD /
-- ASHENVALE_LATER / WETLANDS_LATER): which route it follows where, for a priest.
-- ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
local DONE = {}
LevelGuideDB = { characters = { ["Juan-R"] = { done = DONE, skips = {}, visited = {} } } }
M.info[1440] = { mapID = 1440, name = "Ashenvale", mapType = 3, parentMapID = 1414 }
M.info[1442] = { mapID = 1442, name = "Stonetalon Mountains", mapType = 3, parentMapID = 1414 }
M.rects[1440] = { 6000, 8000, 6000, 4000 }
M.rects[1442] = { 2000, 9000, 4000, 4000 }
-- Every quest the chain hands in up to (not including) route `upto`, as the saved counts LevelGuide keeps; what
-- it has taken and not handed in by then is in the log.
local function DoneBefore(upto)
    for k in pairs(DONE) do DONE[k] = nil end
    local chain = LevelGuideRoutes.chains.NightElf
    local taken = {}
    for i = 1, upto - 1 do
        for _, step in ipairs(chain[i].steps) do
            if step.q and (not step.cls or step.cls == "PRIEST") then
                if step.t == "turnin" then
                    DONE[step.q] = math.max(DONE[step.q] or 0, tonumber(step.part) or 1)
                elseif step.t == "accept" then
                    taken[step.q] = math.max(taken[step.q] or 0, tonumber(step.part) or 1)
                end
            end
        end
    end
    M.flagged, M.log = {}, {}
    M.done(DONE)
    for title, part in pairs(taken) do
        if (DONE[title] or 0) < part then
            local ids = LevelGuideQuestIDs.ids[title]
            M.log[#M.log + 1] = { questID = ids and ids[part] or 0, title = title }
        end
    end
end
M.load(ADDON_PATH, function() DoneBefore(7) M.log = {} end)
local function header() local f = M.font("Route:") return f and f.text or "" end
local function rows()
    local t = {}
    for _, b in ipairs(M.buttons) do if b.shown and b.step then t[#t + 1] = b.left.text end end
    return table.concat(t, "\n")
end

-- 1. Off the Darkshore road at 21 with the two escorts done: Ashenvale's first pass, Aynasha's hand-in at
-- Maestra's Post among the first stops.
M.log = { { questID = 5713, title = "One Shot. One Kill.", ready = true }, { questID = 945, title = "Therylune's Escape", ready = true } }
M.best, M.pos, M.level = 1440, { [1440] = { 0.262, 0.40 } }, 21
M.update()
print(header() .. "\n" .. rows())
assert(header():find("Route: Ashenvale", 1, true) and not header():find("second visit", 1, true), "first pass: " .. header())
assert(rows():find("One Shot. One Kill.", 1, true), "Onaeya's hand-in:\n" .. rows())
M.log = {}
print("1 ok")

-- 2. The first pass done at 23 in Astranaar: on to Stonetalon (its Astranaar pick-ups first), not the
-- second pass and not a boat.
DoneBefore(8)
M.best, M.pos, M.level = 1440, { [1440] = { 0.35, 0.49 } }, 23
M.update()
print(header() .. "\n" .. rows())
assert(header():find("Route: Stonetalon Mountains", 1, true), "Stonetalon next: " .. header())
assert(rows():find("Journey to Stonetalon Peak", 1, true) or rows():find("On Guard in Stonetalon", 1, true), "Astranaar pick-ups:\n" .. rows())
print("2 ok")

-- 3. Back in Astranaar at 27 with Stonetalon, Wetlands and Duskwood done: the second pass.
DoneBefore(11)
M.best, M.pos, M.level = 1440, { [1440] = { 0.35, 0.49 } }, 27
M.update()
print(header() .. "\n" .. rows())
assert(header():find("Ashenvale, second visit", 1, true), "second pass: " .. header())
assert(rows():find("Kayneth Stillwind", 1, true), "Kayneth first:\n" .. rows())
print("3 ok")

-- 4. Off the boat in Menethil at 28 with Ashenvale done: Wetlands' second visit, its Menethil pick-ups.
M.info[1437] = { mapID = 1437, name = "Wetlands", mapType = 3, parentMapID = 1415 }
M.info[1415] = { mapID = 1415, name = "Eastern Kingdoms", mapType = 2, parentMapID = 947 }
M.rects[1437] = { 0, 0, 4000, 4000 }
DoneBefore(12)
M.best, M.pos, M.level = 1437, { [1437] = { 0.10, 0.59 } }, 28
M.update()
print(header() .. "\n" .. rows())
assert(header():find("Wetlands, second visit", 1, true), "Wetlands second visit: " .. header())
assert(rows():find("The Cursed Crew", 1, true), "Fitzsimmons' pick-up:\n" .. rows())
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
