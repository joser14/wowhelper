-- Travel data (LevelGuide\Travel.lua, research\guides_deep_re.md 12.7): Alliance and neutral flight masters with
-- their map and spot, the flight connections, boats, the tram, the Darnassus portals and the Zephras Isle
-- zeppelin with docks and typical wait + ride, inns by bind name, zone levels and the map frames that turn a
-- map spot into world yards. ADDON_PATH = LevelGuide.
assert(loadfile(ADDON_PATH .. "/Travel.lua"))("LevelGuide", {})
local T = LevelGuideTravel
assert(type(T) == "table", "LevelGuideTravel")

local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

-- 1. Every map used has a frame { continent, left, right, top, bottom } and a name.
local function checkPoint(p, what)
    assert(type(p) == "table" and type(p.map) == "number" and type(p.x) == "number" and type(p.y) == "number", what .. ": point")
    assert(T.frames[p.map], what .. ": frame for map " .. p.map)
    assert(T.names[p.map], what .. ": name for map " .. p.map)
    assert(p.x >= 0 and p.x <= 100 and p.y >= 0 and p.y <= 100, what .. ": percent")
end
for id, f in pairs(T.frames) do
    assert(#f == 5 and f[2] ~= f[3] and f[4] ~= f[5], "frame " .. id)
end
print("1 ok")

-- 2. Flight masters: the ones the routes pass, each once, Alliance or neutral.
local byName = {}
for _, fp in ipairs(T.fp) do
    checkPoint(fp, fp.name)
    assert(not byName[fp.name], "one entry per flight master: " .. fp.name)
    assert(fp.side == "A" or fp.side == "N", fp.name .. ": side")
    byName[fp.name] = fp
end
for _, name in ipairs({ "Rut'theran Village", "Auberdine", "Astranaar", "Stormwind", "Ironforge", "Menethil Harbor",
    "Thelsamar", "Sentinel Hill", "Lakeshire", "Darkshire", "Southshore", "Theramore", "Gadgetzan", "Farholde Keep" }) do
    assert(byName[name], "flight master " .. name)
end
-- Spots from forever-db spawns (Vesprystus 58.4, 94.0 and Caylais Moonfeather 36.3, 45.6, as the routes have them).
assert(byName["Rut'theran Village"].map == 1438 and math.abs(byName["Rut'theran Village"].x - 58.4) < 0.3, "Vesprystus")
assert(byName["Auberdine"].map == 1439 and math.abs(byName["Auberdine"].y - 45.6) < 0.3, "Caylais")
print("2 ok: " .. #T.fp .. " flight masters")

-- 3. Connections between known names, no duplicates, every flight master reachable from another.
local seen, linked = {}, {}
for _, c in ipairs(T.flights) do
    local a, b = c[1], c[2]
    assert(byName[a] and byName[b] and a ~= b, "connection " .. tostring(a) .. " - " .. tostring(b))
    local key = a < b and (a .. "|" .. b) or (b .. "|" .. a)
    assert(not seen[key], "duplicate connection " .. key)
    seen[key] = true
    linked[a], linked[b] = true, true
    assert(T.frames[byName[a].map][1] == T.frames[byName[b].map][1], "flights stay on one continent: " .. key)
end
for name in pairs(byName) do assert(linked[name], "connected: " .. name) end
print("3 ok: " .. #T.flights .. " connections")

-- 4. Boats, tram, portals, zeppelin: two ends with a spot each, typical wait and ride in seconds.
local kinds, ids = {}, {}
for _, link in ipairs(T.links) do
    assert(link.id and not ids[link.id], "link id " .. tostring(link.id))
    ids[link.id] = true
    assert(link.kind == "boat" or link.kind == "tram" or link.kind == "portal" or link.kind == "zeppelin", link.id .. ": kind")
    checkPoint(link.a, link.id .. " a")
    checkPoint(link.b, link.id .. " b")
    assert(link.a.name and link.b.name, link.id .. ": dock names")
    assert(type(link.ride) == "number" and link.ride > 0 and type(link.wait) == "number" and link.wait >= 0, link.id .. ": times")
    kinds[link.kind] = (kinds[link.kind] or 0) + 1
end
for _, id in ipairs({ "boat-auberdine-stormwind", "boat-auberdine-ruttheran", "boat-menethil-theramore", "boat-menethil-auberdine",
    "boat-bootybay-ratchet", "boat-tanaris-riverglades", "tram", "portal-darnassus-ruttheran", "portal-ruttheran-darnassus",
    "zeppelin-zephras-dalaran" }) do
    assert(ids[id], "link " .. id)
end
print(string.format("4 ok: %d boats, %d tram, %d portals, %d zeppelin", kinds.boat or 0, kinds.tram or 0, kinds.portal or 0, kinds.zeppelin or 0))

-- 5. Inns by the names GetBindLocation gives, zone levels, islands.
local inns = 0
for _, inn in ipairs(T.inns) do
    checkPoint(inn, "inn " .. tostring(inn.names and inn.names[1]))
    assert(type(inn.names) == "table" and #inn.names > 0, "inn names")
    inns = inns + 1
end
local function innNamed(name)
    for _, inn in ipairs(T.inns) do for _, n in ipairs(inn.names) do if n == name then return inn end end end
end
assert(innNamed("Auberdine") and innNamed("Dolanaar") and innNamed("Stormwind City") and innNamed("Thelsamar"), "inns by bind name")
assert(T.levels[1438][1] == 1 and T.levels[1440][1] >= 18 and T.levels[1453] == nil, "zone levels")
assert(T.Region(1438, 58.4, 94.0) ~= T.Region(1438, 55.6, 59.8), "Rut'theran is below the tree, apart from its top")
assert(T.Region(1457, 50, 50) == T.Region(1438, 55.6, 59.8), "Darnassus is on the tree's top")
assert(T.Region(1439, 36, 45) ~= T.Region(1438, 55.6, 59.8), "Teldrassil is an island")
assert(T.Region(1440, 34, 48) == T.Region(1439, 36, 45), "Ashenvale and Darkshore are joined")
assert(T.Region(1453, 50, 50) ~= T.Region(1439, 36, 45), "another continent")
print(string.format("5 ok: %d inns, %d zones with levels", inns, count(T.levels)))
print("ALL TESTS PASSED")
