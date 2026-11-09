-- Data sanity sweep over the Night Elf chain (order matters) and every route (local checks).
-- ADDON_PATH = LevelGuide folder.
local base = ADDON_PATH
local src = {}
do -- line numbers: re-read Routes.lua with tagging helpers
    local text = ROUTES_TEXT
    local n = 0
    for line in (text .. "\n"):gmatch("(.-)\n") do n = n + 1 src[n] = line end
end
assert(loadfile(base .. "/QuestIDs.lua"))("LevelGuide", {})
assert(loadfile(base .. "/Prereqs.lua"))("LevelGuide", {})
assert(loadfile(base .. "/Routes.lua"))("LevelGuide", {})
-- find each step's line: walk the source in order, matching t/q per route
local function lineOf(route, idx)
    return route._lines and route._lines[idx] or "?"
end
do
    local tags = { accept = "A", ["do"] = "D", turnin = "T", go = "G" }
    local zoneStart = {}
    for i, l in ipairs(src) do
        local z = l:match('^local [%w_]+ = { zone = "(.-)"')
        if z then zoneStart[z] = i end
    end
    local seen = {}
    for _, chain in pairs(LevelGuideRoutes.chains) do
        for _, route in ipairs(chain) do
            if not seen[route] then
                seen[route] = true
                route._lines = {}
                local li = zoneStart[route.zone]
                for idx, s in ipairs(route.steps) do
                    while li and li <= #src do
                        li = li + 1
                        local l = src[li] or ""
                        if l:match("^%s*" .. tags[s.t] .. "%(") then route._lines[idx] = li break end
                    end
                end
            end
        end
    end
end
local ITEMISH = { "drop", "item", "object", "poster", "<", "loot", "chest", "book", "page", "wanted", "starts", "from a", "sign", "letter", "corpse", "tablet", "note" }
local function itemish(text)
    text = (text or ""):lower()
    for _, w in ipairs(ITEMISH) do if text:find(w, 1, true) then return true end end
    return false
end
local ZONES = { "Teldrassil", "Darkshore", "Ashenvale", "Wetlands", "Duskwood", "Hillsbrad", "Arathi", "Desolace",
    "Stranglethorn", "Booty Bay", "Tanaris", "Gadgetzan", "Feralas", "Hinterlands", "Un'Goro", "Felwood", "Burning Steppes",
    "Western Plaguelands", "Eastern Plaguelands", "Winterspring", "Silithus", "Stormwind", "Ironforge", "Darnassus",
    "Moonglade", "Menethil", "Southshore", "Thelsamar", "Loch Modan", "Dun Morogh", "Redridge", "Elwynn", "Westfall",
    "Azshara", "Stonetalon", "Thousand Needles", "Dustwallow", "Theramore", "Badlands", "Searing Gorge", "Swamp of Sorrows",
    "Blasted Lands", "Alterac", "Silverpine", "Barrens", "Everlook", "Auberdine", "Astranaar", "Rut'theran", "Lakeshire",
    "Darkshire", "Refuge Pointe", "Chillwind", "Light's Hope", "Cenarion Hold", "Marshal's Refuge", "Aerie Peak", "Thalanaar",
    "Feathermoon", "Nijel's", "Morgan's Vigil", "Talonbranch", "Kargath", "Sentinel Hill" }
local OWN = { -- towns inside each route's zone
    Teldrassil = { "Darnassus", "Rut'theran", "Teldrassil" }, Darkshore = { "Auberdine", "Darkshore" },
    Ashenvale = { "Astranaar", "Ashenvale" }, Wetlands = { "Menethil", "Wetlands" }, Duskwood = { "Darkshire", "Duskwood" },
    ["Hillsbrad Foothills"] = { "Southshore", "Hillsbrad", "Alterac" }, ["Arathi Highlands"] = { "Refuge Pointe", "Arathi" },
    Desolace = { "Nijel's", "Desolace" }, ["Stranglethorn Vale"] = { "Booty Bay", "Stranglethorn" }, Tanaris = { "Gadgetzan", "Tanaris" },
    Feralas = { "Feathermoon", "Feralas" }, ["The Hinterlands"] = { "Aerie Peak", "Hinterlands" }, ["Un'Goro Crater"] = { "Marshal's Refuge", "Un'Goro" },
    Felwood = { "Talonbranch", "Felwood" }, ["Burning Steppes"] = { "Morgan's Vigil", "Burning Steppes" },
    ["Western Plaguelands"] = { "Chillwind", "Western Plaguelands" }, ["Eastern Plaguelands"] = { "Light's Hope", "Eastern Plaguelands" },
    Winterspring = { "Everlook", "Winterspring" }, Silithus = { "Cenarion Hold", "Silithus" },
    ["Dun Morogh"] = { "Dun Morogh", "Ironforge" }, ["Loch Modan"] = { "Thelsamar", "Loch Modan" },
}
local out = {}
local function report(kind, route, idx, s, msg)
    out[#out + 1] = string.format("%-9s %-20s L%-5s %s %-34s %s", kind, route.zone, tostring(lineOf(route, idx)), s.t:sub(1, 1):upper(),
        tostring(s.q or s.text):sub(1, 34), msg or "")
end
-- local checks on every route
local seen = {}
for _, chain in pairs(LevelGuideRoutes.chains) do
    for _, route in ipairs(chain) do
        if not seen[route] then
            seen[route] = true
            local prev
            for idx, s in ipairs(route.steps) do
                if type(s.x) ~= "number" or type(s.y) ~= "number" or s.x <= 0 or s.x >= 100 or s.y <= 0 or s.y >= 100 then
                    report("COORD", route, idx, s, tostring(s.x) .. "," .. tostring(s.y))
                end
                if s.lvl and s.lvl > route.max + 3 then report("LVL>MAX+3", route, idx, s, s.lvl .. " > " .. route.max) end
                if prev and prev.t == s.t and prev.q == s.q and prev.text == s.text and prev.part == s.part and prev.x == s.x and prev.y == s.y then
                    report("DUP", route, idx, s, "same as previous step")
                end
                local text = (s.npc or "") .. " " .. (s.note or "") .. " " .. (s.text or "")
                for _, z in ipairs(ZONES) do
                    if text:find(z, 1, true) then
                        local own = false
                        for _, o in ipairs(OWN[route.zone] or {}) do if z == o or o:find(z, 1, true) or z:find(o, 1, true) then own = true end end
                        if not own and z ~= "Darnassus" then
                            report("ZONE?", route, idx, s, "mentions " .. z .. ": " .. text:sub(1, 70))
                            break
                        end
                    end
                end
                prev = s
            end
        end
    end
end
-- order checks along the Night Elf chain
local chain = LevelGuideRoutes.chains.NightElf
local accepted, turned = {}, {}
local order = {}
for _, route in ipairs(chain) do
    for idx, s in ipairs(route.steps) do order[#order + 1] = { route = route, idx = idx, s = s } end
end
for pos, e in ipairs(order) do
    local s = e.s
    local key = s.q and (s.q .. "#" .. (s.part or 1))
    if s.t == "accept" then
        accepted[key] = pos
    elseif s.t == "turnin" then
        if not accepted[key] then
            -- accepted later?
            local later
            for p2 = pos + 1, #order do
                local o = order[p2].s
                if o.t == "accept" and o.q == s.q and (o.part or 1) == (s.part or 1) then later = order[p2] break end
            end
            if later then
                report("T<A", e.route, e.idx, s, "accepted later at " .. later.route.zone .. " L" .. tostring(lineOf(later.route, later.idx)))
            elseif not itemish(s.npc) then
                report("T-noA", e.route, e.idx, s, "no pick-up anywhere in chain; to " .. tostring(s.npc):sub(1, 50))
            end
        end
        turned[key] = pos
    end
end
for pos, e in ipairs(order) do
    local s = e.s
    if s.t == "accept" then
        local key = s.q .. "#" .. (s.part or 1)
        local found = false
        for p2 = pos + 1, #order do
            local o = order[p2].s
            if o.t == "turnin" and o.q == s.q and (o.part or 1) == (s.part or 1) then found = true break end
        end
        if not found then report("A-noT", e.route, e.idx, s, "from " .. tostring(s.npc):sub(1, 60)) end
    end
end
for _, l in ipairs(out) do print(l) end
print(#out .. " findings")
