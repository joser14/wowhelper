-- The real Night Elf 11-21 plan as legs: Darkshore to ~15, the Stormwind/Ironforge/Loch Modan trip,
-- Darkshore 15-19, the Stormwind/Redridge trip, Darkshore 20-21, then Ashenvale. Priest stops on each leg.
-- ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.info[1415] = { mapID = 1415, name = "Eastern Kingdoms", mapType = 2, parentMapID = 947 }
for id, name in pairs({ [1453] = "Stormwind City", [1432] = "Loch Modan", [1455] = "Ironforge", [1426] = "Dun Morogh",
    [1433] = "Redridge Mountains", [1429] = "Elwynn Forest" }) do
    M.info[id] = { mapID = id, name = name, mapType = 3, parentMapID = 1415 }
end
M.load(ADDON_PATH)
local chain = LevelGuideRoutes.chains.NightElf
local function rows()
    local t = {}
    for _, b in ipairs(M.buttons) do if b.shown and b.step then t[#t + 1] = b.left.text end end
    return table.concat(t, "\n")
end
local function header() local f = M.font("Route:") return f and f.text or "" end
local function side(pattern)
    for _, b in ipairs(M.buttons) do
        if b.shown and b.step and b.step.side and b.left.text:find(pattern, 1, true) then return b end
    end
end

-- 1. The legs, in order, with level bands that hand over to each other.
local want = {
    { "Teldrassil" }, { "Darkshore", 11, 15 }, { "Stormwind, Ironforge and Loch Modan", 14, 16 }, { "Darkshore", 15, 19 },
    { "Stormwind and Redridge", 19, 20 }, { "Darkshore", 20, 21 }, { "Ashenvale" },
}
for i, w in ipairs(want) do
    local r = chain[i]
    assert(r and (r.name or r.zone) == w[1], "leg " .. i .. ": " .. tostring(r and (r.name or r.zone)))
    if w[2] then assert(r.leg and r.min == w[2] and r.max == w[3], "leg " .. i .. " band " .. r.min .. "-" .. r.max) end
end
local DA, TRIP, DB, RR, DC = chain[2], chain[3], chain[4], chain[5], chain[6]
-- Hearth bound in Auberdine at once; both trips end with the hearthstone home; the Darkshore legs that
-- leave end with the boat; each trip has a way from Darkshore (the pier).
local bound
for i = 1, 6 do if DA.steps[i].t == "home" and DA.steps[i].place == "Auberdine" then bound = true end end
assert(bound, "Auberdine bind in the first steps")
for _, leg in ipairs({ TRIP, RR }) do
    local last = leg.steps[#leg.steps]
    assert(last.t == "hearth" and last.place == "Auberdine", (leg.name) .. " ends with the hearth home")
    local fromDarkshore
    for _, way in ipairs(leg.ways or {}) do if way.from == "Darkshore" then fromDarkshore = way end end
    assert(fromDarkshore and fromDarkshore.x, leg.name .. ": a way from Darkshore")
end
for _, leg in ipairs({ DA, DB }) do
    local last = leg.steps[#leg.steps]
    assert(last.t == "zone" and last.reach == "Stormwind City" and last.x, "Darkshore leg ends with the boat")
end
-- Saved keys stay apart: no two steps share a key among the routes that share a key prefix.
for _, ch in pairs(LevelGuideRoutes.chains) do
    local seen = {}
    for _, route in ipairs(ch) do
        local prefix = route.key or route.zone
        seen[prefix] = seen[prefix] or {}
        local own = {}
        for _, step in ipairs(route.steps) do
            local who = step.t == "do" and tostring(step.obj or "") or (step.t == "go" or step.t == "zone" or step.t == "xp") and "" or tostring(step.npc or "")
            local base = table.concat({ step.t, tostring(step.q or step.text), tostring(step.part or ""), who }, "|")
            own[base] = true
        end
        for base in pairs(own) do
            if seen[prefix][base] and seen[prefix][base] ~= route then
                -- The same route twice in a chain doesn't happen; another route sharing the prefix must not repeat a step.
                error("shared key " .. prefix .. "|" .. base)
            end
            seen[prefix][base] = route
        end
    end
end
print("1 ok")

-- 2. Off the boat in Stormwind at 14, a priest: the trip leg; the level 14 visit is Brother Joshua there.
M.best, M.pos, M.level = 1453, { [1453] = { 0.3, 0.5 } }, 14
M.update()
print(rows())
assert(header():find("Stormwind, Ironforge and Loch Modan", 1, true), "trip leg: " .. header())
local t14 = side("Level 14 spells")
assert(t14 and t14.step.mapID == 1453, "Joshua for 14:\n" .. rows())
print("2 ok")

-- 3. In Loch Modan at 15: still the trip, its steps on the Loch Modan map.
M.best, M.pos, M.level = 1432, { [1432] = { 0.3, 0.7 } }, 15
M.update()
print(rows())
assert(header():find("Stormwind, Ironforge and Loch Modan", 1, true) and M.current.step.mapID == 1432, "Loch Modan: " .. rows())
print("3 ok")

-- 4. Hearthed home at 15 with the trip under way (Stormpike's Order in the log): Darkshore's second leg,
-- not the first leg's boat again.
M.log = { { questID = 1338, title = "Stormpike's Order" } }
M.best, M.pos, M.subzone = 1439, { [1439] = { 0.37, 0.44 } }, "Auberdine"
M.update()
print(rows())
assert(header():find("Route: Darkshore", 1, true) and not rows():find("Auberdine pier)", 1, true), "second Darkshore leg: " .. rows())
print("4 ok")

-- 5. In Stormwind at 19 off the second boat: the Redridge trip; level 18 spells with Joshua.
M.best, M.pos, M.level = 1453, { [1453] = { 0.3, 0.5 } }, 19
M.update()
print(rows())
assert(header():find("Stormwind and Redridge", 1, true), "Redridge trip: " .. header())
local t18 = side("Level 18 spells")
assert(t18 and t18.step.mapID == 1453, "Joshua for 18:\n" .. rows())
print("5 ok")

-- 6. Home in Darkshore at 20 with The Corruption Abroad: the last Darkshore leg, the hand-in and the
-- priest's trip to Darnassus.
M.log = { { questID = 3765, title = "The Corruption Abroad", ready = true } }
M.best, M.pos, M.level = 1439, { [1439] = { 0.38, 0.43 } }, 20
M.update()
print(rows())
assert(header():find("Route: Darkshore", 1, true) and rows():find("The Corruption Abroad", 1, true), "last leg: " .. rows())
M.log = {}
M.update()
assert(rows():find("Rut'theran", 1, true), "priest trip to Darnassus: " .. rows())
-- In Darnassus: Elune's Grace is placed on the city map.
M.best, M.pos, M.subzone = 1457, { [1457] = { 0.4, 0.8 } }, nil
M.update()
print(rows())
assert(M.current.left.text:find("Elune's Grace", 1, true) and M.current.step.mapID == 1457, "Elune's Grace in Darnassus: " .. rows())
M.class = "WARRIOR"; M.best, M.pos = 1439, { [1439] = { 0.38, 0.43 } }; M.update()
assert(not rows():find("Rut'theran", 1, true) and not rows():find("Elune's Grace", 1, true), "no priest trip for a warrior")
M.class = "PRIEST"
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
