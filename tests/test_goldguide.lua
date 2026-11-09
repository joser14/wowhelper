-- GoldGuide smoke test: data validation, the "best for you" page (level, professions, PriceMemory prices,
-- bag values), pinning by number, "all", "tips", the hub status row and its cache, and missing APIs.
-- Run from the harness folder:  node run.js "<workspace root>" test_goldguide.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local SECRET = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why .. "\n  page was:\n  " .. table.concat(out, "\n  ") end end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function need(text, why) check(has(text), why .. ": wanted '" .. text .. "'") end
local function needNot(text, why) check(not has(text), why .. ": did not want '" .. text .. "'") end

ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function(v) return v == SECRET end
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
local clock = 1000000
time = function() return clock end
local gtime = 500
GetTime = function() return gtime end
GetRealmName = function() return "R" end
UnitFactionGroup = function() return "Alliance" end
local level = 1
UnitLevel = function() return level end

----- Data validation (Data.lua alone, before the engine loads)
assert(loadfile(base .. "/GoldGuide/Data.lua"))("GoldGuide", {})
local D = GoldGuideData
assert(type(D) == "table" and type(D.farms) == "table" and type(D.methods) == "table", "GoldGuideData shape")
local KNOWN_PROF = { [186] = true, [182] = true, [393] = true, [356] = true }
local covered, profCount, seenNames = {}, {}, {}
for i, f in ipairs(D.farms) do
    local id = "farm " .. i .. " (" .. tostring(f.name) .. ")"
    assert(type(f.name) == "string" and f.name ~= "", id .. ": name")
    assert(not seenNames[f.name], id .. ": duplicate name"); seenNames[f.name] = true
    assert(type(f.zone) == "string" and D.zones[f.zone], id .. ": zone in zones table")
    assert(type(f.mapID) == "number" and f.mapID == D.zones[f.zone][1], id .. ": mapID set")
    assert(type(f.minLevel) == "number" and type(f.maxLevel) == "number", id .. ": levels are numbers")
    assert(f.minLevel >= 10 and f.maxLevel <= 60 and f.minLevel <= f.maxLevel, id .. ": levels in 10..60")
    assert(type(f.x) == "number" and f.x > 0 and f.x < 1 and type(f.y) == "number" and f.y > 0 and f.y < 1, id .. ": x/y in 0..1")
    assert(type(f.why) == "string" and f.why ~= "", id .. ": why")
    assert(f.profession == nil or KNOWN_PROF[f.profession], id .. ": profession is a known skill line")
    assert(type(f.drops) == "table" and #f.drops > 0, id .. ": has drops")
    for _, d in ipairs(f.drops) do
        assert(type(d.itemID) == "number" and d.itemID > 0 and math.floor(d.itemID) == d.itemID, id .. ": drop itemID")
        assert(type(d.name) == "string" and d.name ~= "", id .. ": drop name")
    end
    for l = f.minLevel, f.maxLevel do covered[l] = (covered[l] or 0) + 1 end
    if f.profession then profCount[f.profession] = (profCount[f.profession] or 0) + 1 end
end
for l = 10, 60 do assert((covered[l] or 0) >= 2, "level " .. l .. " has at least two farms, got " .. tostring(covered[l])) end
assert((profCount[186] or 0) >= 5 and (profCount[182] or 0) >= 5 and (profCount[393] or 0) >= 5 and (profCount[356] or 0) >= 1, "gathering routes per profession")
for zone, ids in pairs(D.zones) do
    assert(type(ids) == "table" and #ids >= 1, zone .. ": map ids")
    for _, m in ipairs(ids) do assert(type(m) == "number", zone .. ": numeric map id") end
end
for i, m in ipairs(D.methods) do
    assert(type(m.title) == "string" and type(m.text) == "string" and type(m.minLevel) == "number" and m.minLevel >= 1 and m.minLevel <= 60, "method " .. i)
end
assert(#D.methods >= 10, "enough tips")

----- Engine before login: no APIs at all yet, nothing errors
local nFrames = #frames
assert(loadfile(base .. "/GoldGuide/GoldGuide.lua"))("GoldGuide", {})
local gg = frames[nFrames + 1]
assert(gg and gg.registered.PLAYER_LOGIN and gg.registered.BAG_UPDATE_DELAYED, "events registered")
assert(SLASH_GOLDGUIDE1 == "/goldguide" and SlashCmdList.GOLDGUIDE, "slash command")
assert(ForeverHubStatus and ForeverHubStatus.GoldGuide, "status function")

local function page(arg)
    out = {}
    local ok, err = pcall(SlashCmdList.GOLDGUIDE, arg)
    if not ok then out[#out + 1] = "<<ERROR: " .. tostring(err) .. ">>" end
    check(ok, "page '" .. tostring(arg) .. "' errored")
    return ok
end
local function status()
    local ok, r = pcall(ForeverHubStatus.GoldGuide)
    check(ok, "status errored: " .. tostring(r))
    return r
end

page("")
check(#out == 0, "page before login is quiet")
check(status() == nil, "status before login is nil")

-- Login with no container/item/map/profession APIs at all.
gg.fn(gg, "PLAYER_LOGIN")
level = 12
page("")
need("Best for you now", "page works without bag APIs")
need("The game didn't report your bags.", "no bag API notice")
page("1")
need("Couldn't pin it on this map.", "no map API: no pin, shows coordinates")
page("all")
page("tips")
check(status() == nil, "status nil without PriceMemoryDB")

----- Now the full game API
-- Bags: bag 0 has 4 slots.
local bags = { [0] = {} }
local ITEMS = {
    [2589] = { "Linen Cloth", 13 },
    [4306] = { "Silk Cloth", 150 },
    [3356] = { "Kingsblood", 20 },
    [9999] = { "Grey Thing", 500 },
    [7777] = { "Bound Ring", 1000 },
}
local loaded = { [2589] = true, [4306] = true, [3356] = true, [9999] = true, [7777] = true }
local requested = {}
NUM_BAG_SLOTS = 4
C_Container = {
    GetContainerNumSlots = function(bag) return bags[bag] and 4 or 0 end,
    GetContainerItemInfo = function(bag, slot) return bags[bag] and bags[bag][slot] end,
}
local scans = 0
C_Item = {
    GetItemInfo = function(id)
        if bags.countScans then scans = scans + 1 end
        local it = ITEMS[id]
        if not it or not loaded[id] then return nil end
        return it[1], nil, 1, 1, 1, "", "", 20, "", 0, it[2]
    end,
    RequestLoadItemDataByID = function(id) requested[id] = true end,
}
bags[0][1] = { itemID = 2589, stackCount = 20, quality = 1 }
bags[0][2] = { itemID = 4306, stackCount = 20, quality = 1 }
bags[0][3] = { itemID = 9999, stackCount = 1, quality = 0 }
bags[0][4] = { itemID = 3356, stackCount = 10, quality = 1 }

local profs = {}
GetProfessions = function() return profs[1], profs[2], profs[3], profs[4], profs[5] end
local PROF_INFO = { [1] = { "Herbalism", 182 }, [2] = { "Skinning", 393 }, [3] = { "Cooking", 185 }, [4] = { "Mining", 186 } }
GetProfessionInfo = function(i) local p = PROF_INFO[i]; return p[1], 0, 100, 150, 0, 0, p[2] end

local waypoints, supertracked = {}, nil
local MAPNAME = { [62] = "Darkshore", [52] = "Westfall", [48] = "Loch Modan", [50] = "Northern Stranglethorn", [224] = "Stranglethorn Vale" }
C_Map = {
    CanSetUserWaypointOnMap = function(m) return MAPNAME[m] ~= nil end,
    GetMapInfo = function(m) if MAPNAME[m] then return { name = MAPNAME[m] } end end,
    SetUserWaypoint = function(p) waypoints[#waypoints + 1] = p; return true end,
}
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, x = x, y = y } end }
C_SuperTrack = { SetSuperTrackedUserWaypoint = function(b) supertracked = b end }

----- Level 12, no professions, no PriceMemory
page("")
need("Best for you now", "header")
need("(level 12)", "level shown")
need("Writhing Highborne at Ameth'Aran for Linen", "Darkshore linen farm for level 12")
need("Defias in Moonbrook for Linen", "Westfall linen farm")
need("Drops: Linen Cloth", "drops listed")
needNot("last AH price", "no prices without PriceMemory")
need("Tips for your level", "tips header")
need("Your bags", "bags header")
-- 20*13 + 20*150 + 500 + 10*20 = 260 + 3000 + 500 + 200 = 3960 = 39s 60c
need("sells to a vendor for 39s 60c", "vendor value of bags")
need("once PriceMemory has seen", "no PriceMemory notice")
need("Gold goal page", "points to Gold goal page")
check(#out >= 8, "page has content")

----- Professions get priority: herbalist + skinner at 24
level = 24
profs = { 1, 2, 3 }
page("")
local first = out[2] or ""
check(first:find("[Herbalism]", 1, true) or first:find("[Skinning]", 1, true), "first farm is for a profession you have: " .. first)
needNot("you don't have it", "gathering routes you lack aren't shown when the list is full")
need("[Herbalism]", "herb route shown")

----- PriceMemory prices: realm-faction scope, one legacy flat entry, garbage entries ignored
PriceMemoryDB = {
    ["R-Alliance"] = {
        [2589] = { price = 40, seen = clock - 3 * 86400 },            -- Linen: 40c > 13c vendor
        [4306] = { price = 1000, seen = clock - 100 },               -- Silk: 10s each
        [3356] = "garbage",
        [9999] = { price = 100, seen = clock },                      -- below vendor: not listed
    },
    [3356] = { price = 2000, seen = clock - 2 * 86400 },              -- Kingsblood, older flat save
    ["Other-Horde"] = { [2592] = { price = 99999, seen = clock } },
}
level = 12; profs = {}
page("")
need("Linen Cloth (last AH price 40c (3 days ago))", "AH price on a farm drop")
need("Worth more at the auction house", "auction section")
-- Silk: 20 * (1000-150) = 17000 gain; Kingsblood 10*(2000-20)=19800; Linen 20*(40-13)=540
need("Kingsblood x10: AH 2g 0s vs vendor 2s 0c", "kingsblood line from older save")
need("older save", "older save marked")
need("Silk Cloth x20: AH 2g 0s vs vendor 30s 0c", "silk line")
need("Linen Cloth x20: AH 8s 0c vs vendor 2s 60c", "linen line")
needNot("Grey Thing x", "items below vendor price not suggested")
local iK, iS, iL
for i, t in ipairs(out) do
    if t:find("Kingsblood x10", 1, true) then iK = i end
    if t:find("Silk Cloth x20", 1, true) then iS = i end
    if t:find("Linen Cloth x20", 1, true) then iL = i end
end
check(iK and iS and iL and iK < iS and iS < iL, "sorted by gain")

----- Bound items aren't suggested; items still loading are reported and requested
bags[0][3] = { itemID = 7777, stackCount = 1, quality = 3, isBound = true }
PriceMemoryDB["R-Alliance"][7777] = { price = 99999, seen = clock }
loaded[4306] = nil
page("")
needNot("Bound Ring", "bound items aren't auction suggestions")
need("1 item(s) are still loading", "loading notice")
check(requested[4306], "load requested for the missing item")
loaded[4306] = true

----- Secret values don't break the scan
bags[0][2] = { itemID = SECRET, stackCount = 5 }
page("")
need("Your bags", "secret item id skipped")
bags[0][2] = { itemID = 4306, stackCount = 20, quality = 1 }

----- Pinning by number from the last list
level = 12; profs = {}
page("")
local pinned
for _, t in ipairs(out) do
    local n, name = t:match("|cffffd100(%d+)%.|r ([^|]+) |cff999999%- Darkshore")
    if n and not pinned then pinned = { tonumber(n), name } end
end
check(pinned, "a Darkshore farm is listed at 12")
if pinned then
    page(tostring(pinned[1]))
    need("Pinned " .. pinned[2], "pin message")
    local w = waypoints[#waypoints]
    check(w and w.uiMapID == 62 and w.x > 0 and w.x < 1, "waypoint on Darkshore map 62")
    check(supertracked == true, "supertracked")
end
page("99")
need("There's no farm number 99", "bad number")

----- Stranglethorn: map 50 is Northern Stranglethorn on Mainline, so the pin goes to 224 by name
page("all")
need("Levels 10-19", "band header")
need("Levels 50-60", "last band")
local stvNumber
for _, t in ipairs(out) do
    local n = t:match("|cffffd100(%d+)%.|r [^|]+ |cff999999%- Stranglethorn Vale")
    if n and not stvNumber then stvNumber = tonumber(n) end
end
check(stvNumber, "an STV farm in the all list")
local countAll = 0
for _, t in ipairs(out) do if t:match("^|cffffd100%d+%.|r") then countAll = countAll + 1 end end
check(countAll == #D.farms, "all lists every farm: " .. countAll .. " of " .. #D.farms)
if stvNumber then
    local before = #waypoints
    page(tostring(stvNumber))
    need("Pinned", "stv pinned")
    check(#waypoints == before + 1 and waypoints[#waypoints].uiMapID == 224, "STV pinned on the map named Stranglethorn Vale")
end
-- A zone the game knows no map for: no pin, coordinates instead.
local felwood
page("all")
for _, t in ipairs(out) do
    local n = t:match("|cffffd100(%d+)%.|r [^|]+ |cff999999%- Felwood")
    if n and not felwood then felwood = tonumber(n) end
end
local before = #waypoints
page(tostring(felwood))
need("Couldn't pin it on this map.", "no matching map: coordinates")
check(#waypoints == before, "no waypoint set")

----- Tips page
page("tips")
check(#out == #D.methods, "every tip listed")
need("Free Action Potion", "recipe tip")

----- Unknown word
page("bogus")
need("Type a farm's number", "help line")
need("Best for you now", "still shows the page")

----- Level 60 and level 5
level = 60
page("")
need("(level 60)", "level 60")
need("Runecloth", "runecloth at 60")
level = 5
page("")
need("No farm in this guide fits your level yet", "below 10")
level = SECRET
page("")
need("Your level can't be read", "secret level")
level = 30

----- Hub status: count of items worth >= 1g more, cached
-- Kingsblood gain 19800 (>=1g), Silk 17000 (>=1g), Linen 540 (no)
gtime = 1000
gg.fn(gg, "BAG_UPDATE_DELAYED")
local r = status()
check(type(r) == "table" and r[1] and r[1].text == "|cffeecc55AH|r 2 items worth more at auction" and r[1].page == "Gold guide", "status row: " .. tostring(r and r[1] and r[1].text))
-- Bag change marks the cache stale, but within 5s the cached answer is reused.
bags[0][4] = nil
gg.fn(gg, "BAG_UPDATE_DELAYED")
gtime = 1002
bags.countScans = true; scans = 0
r = status()
check(scans == 0, "no rescan within 5 seconds")
check(r and r[1].text:find("2 items", 1, true), "cached count")
gtime = 1010
r = status()
check(scans > 0, "rescanned after the bags changed")
check(r and r[1].text == "|cffeecc55AH|r 1 item worth more at auction", "one item after Kingsblood left: " .. tostring(r and r[1] and r[1].text))
-- No change: no rescan even after a long time.
scans = 0; gtime = 2000
status()
check(scans == 0, "no rescan without a bag change")
bags.countScans = nil
-- Nothing worth it: nil
PriceMemoryDB = {}
gg.fn(gg, "BAG_UPDATE_DELAYED"); gtime = 3000
check(status() == nil, "status nil when nothing is worth more")

----- PriceMemory never written
local snapshot = {}
PriceMemoryDB = { ["R-Alliance"] = { [2589] = { price = 40, seen = clock } } }
page(""); page("all"); status()
local n = 0
for k in pairs(PriceMemoryDB) do n = n + 1 end
for k in pairs(PriceMemoryDB["R-Alliance"]) do n = n + 1 end
check(n == 2, "PriceMemoryDB untouched")

if #failures > 0 then
    error(#failures .. " check(s) failed:\n\n" .. table.concat(failures, "\n\n"), 0)
end
print("ALL TESTS PASSED (" .. #D.farms .. " farms, " .. #D.methods .. " tips)")
