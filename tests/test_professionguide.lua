-- ProfessionGuide smoke test: validates all twelve data files, then drives the page (overview, full
-- guide by name, shopping list, trainer pins), the hub status row, secret values and missing APIs.
-- Run from the harness folder:  node run.js "<workspace root>" test_professionguide.lua
local base = ADDON_PATH .. "/ProfessionGuide/"
local out, failures = {}, {}
local SECRET = {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function(v) return v == SECRET end
-- The addon must never print to chat.
local realPrint = print
print = function(...) failures[#failures + 1] = "printed to chat: " .. table.concat({ ... }, " ") end
CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function() end }
end
SlashCmdList = {}

local function reset() out = {} end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function dump() return "\n  page was:\n  " .. table.concat(out, "\n  ") end
local function check(cond, why) if not cond then failures[#failures + 1] = why .. dump() end end
local function need(text, why) check(has(text), why .. ": wanted '" .. text .. "'") end
local function page(arg)
    reset()
    local ok, err = pcall(SlashCmdList.PROFESSIONGUIDE, arg)
    if not ok then out[#out + 1] = "<<ERROR: " .. tostring(err) .. ">>" end
    check(ok, "page '" .. tostring(arg) .. "' errored")
    return ok
end

----- Load in TOC order, with no game APIs at all (as if before login)
-- Same order as ProfessionGuide.toc (the harness has no io library to read it).
local files = { "Data_Alchemy.lua", "Data_Blacksmithing.lua", "Data_Enchanting.lua", "Data_Engineering.lua",
    "Data_Leatherworking.lua", "Data_Tailoring.lua", "Data_Mining.lua", "Data_Herbalism.lua", "Data_Skinning.lua",
    "Data_Cooking.lua", "Data_FirstAid.lua", "Data_Fishing.lua", "ProfessionGuide.lua" }
for _, name in ipairs(files) do
    assert(loadfile(base .. name))("ProfessionGuide", {})
end
assert(SLASH_PROFESSIONGUIDE1 == "/profguide" and SlashCmdList.PROFESSIONGUIDE, "slash registered")
assert(ForeverHubStatus and ForeverHubStatus.ProfessionGuide, "hub status registered")

----- Data validation
local EXPECT = { [171] = "Alchemy", [164] = "Blacksmithing", [333] = "Enchanting", [202] = "Engineering",
    [165] = "Leatherworking", [197] = "Tailoring", [186] = "Mining", [182] = "Herbalism", [393] = "Skinning",
    [185] = "Cooking", [129] = "First Aid", [356] = "Fishing" }
local GATHERING = { [186] = true, [182] = true, [393] = true, [356] = true }
local function SafeCrafts(from, to, yellow, grey)
    local mean, var = 0, 0
    for s = from, to - 1 do
        local p = s < yellow and 1 or (grey - s) / (grey - yellow)
        if p <= 0 then return nil end
        p = math.min(p, 1)
        mean = mean + 1 / p
        var = var + (1 - p) / (p * p)
    end
    return math.ceil(mean + 1.2816 * math.sqrt(var) - 1e-9)
end
local dataProblems = {}
local function bad(line, why) dataProblems[#dataProblems + 1] = (EXPECT[line] or tostring(line)) .. ": " .. why end
local stepCount = 0
for line, name in pairs(EXPECT) do
    local guide = ProfessionGuideData[line]
    if not guide then
        bad(line, "missing")
    else
        if guide.name ~= name then bad(line, "name is " .. tostring(guide.name)) end
        local expectFrom = 1
        for i, step in ipairs(guide.steps or {}) do
            stepCount = stepCount + 1
            local where = string.format("step %d (%s-%s)", i, tostring(step.from), tostring(step.to))
            if step.from ~= expectFrom then bad(line, where .. " should start at " .. expectFrom) end
            if not (type(step.from) == "number" and type(step.to) == "number" and step.from < step.to) then bad(line, where .. " from < to") end
            expectFrom = step.to
            if GATHERING[line] then
                if type(step.gather) ~= "string" or type(step.where) ~= "string" then bad(line, where .. " needs gather and where") end
            else
                if type(step.craft) ~= "string" then bad(line, where .. " needs craft") end
                if type(step.crafts) ~= "number" or step.crafts < step.to - step.from or step.crafts % 1 ~= 0 then
                    bad(line, where .. " crafts " .. tostring(step.crafts) .. " below the points it covers")
                end
                if type(step.learn) ~= "string" then bad(line, where .. " needs learn") end
                if step.yellow or step.grey then
                    local safe = type(step.yellow) == "number" and type(step.grey) == "number" and SafeCrafts(step.from, step.to, step.yellow, step.grey)
                    if not safe then
                        bad(line, where .. " runs into grey (yellow " .. tostring(step.yellow) .. ", grey " .. tostring(step.grey) .. ")")
                    elseif step.crafts < safe then
                        bad(line, where .. " crafts " .. step.crafts .. " < 90%-safe " .. safe)
                    end
                end
                if type(step.mats) ~= "table" or #step.mats == 0 then bad(line, where .. " has no mats") end
                for _, mat in ipairs(step.mats or {}) do
                    if type(mat.itemID) ~= "number" or mat.itemID <= 0 or mat.itemID % 1 ~= 0 then bad(line, where .. " mat " .. tostring(mat.name) .. " itemID") end
                    if type(mat.count) ~= "number" or mat.count <= 0 then bad(line, where .. " mat " .. tostring(mat.name) .. " count") end
                    if type(mat.name) ~= "string" then bad(line, where .. " mat name") end
                end
            end
        end
        if expectFrom ~= 300 then bad(line, "path ends at " .. tostring(expectFrom) .. ", not 300") end
        if type(guide.trainers) ~= "table" or #guide.trainers == 0 then bad(line, "no trainers") end
        for i, t in ipairs(guide.trainers or {}) do
            local where = "trainer " .. i .. " (" .. tostring(t.name) .. ")"
            if type(t.mapID) ~= "number" or t.mapID < 1400 or t.mapID > 1460 then bad(line, where .. " mapID " .. tostring(t.mapID) .. " is not a Classic-era zone map") end
            if type(t.x) ~= "number" or t.x <= 0 or t.x >= 1 or type(t.y) ~= "number" or t.y <= 0 or t.y >= 1 then bad(line, where .. " x/y out of range") end
            for _, field in ipairs({ "rank", "name", "where", "zone" }) do
                if type(t[field]) ~= "string" then bad(line, where .. " needs " .. field) end
            end
        end
        if type(guide.notes) ~= "table" then bad(line, "notes missing") end
    end
end
for line in pairs(ProfessionGuideData) do
    if not EXPECT[line] then bad(line, "unexpected skill line") end
end
if #dataProblems > 0 then
    failures[#failures + 1] = "DATA:\n  " .. table.concat(dataProblems, "\n  ")
end

----- No APIs yet: the page and status still work, quietly
page("")
need("You haven't learned a profession yet.", "no-API overview")
need("Herbalism + Alchemy", "pair suggestion")
check(ForeverHubStatus.ProfessionGuide() == nil, "no status row without professions")
page("shopping")
need("You haven't learned a profession yet.", "no-API shopping")
page("trainer alchemy")
need("Milla Fairancora", "no map API: describes the first listed trainer")
check(not has("<<ERROR"), "no error without map API")

----- Game mocks
local professions = {}       -- position -> { name, rank, maxRank, skillLine }
GetProfessions = function()
    return professions[1] and 1, professions[2] and 2, professions[3] and 3, professions[4] and 4, professions[5] and 5
end
GetProfessionInfo = function(index)
    local p = professions[index]
    return p.name, 0, p.rank, p.maxRank, 0, 0, p.skillLine
end
local firstAid = { name = "First Aid", rank = 0, maxRank = 0 }
C_SkillInfo = { GetSkillLineInfoByID = function(id) if id == 129 then return firstAid end end }
local bags = {}
-- Shopping counts the bank too (nothing bought twice); crafting only what's in your bags (bankOnly by id).
local bankOnly = {}
C_Item = { GetItemCount = function(id, bank)
    if bank then return (bags[id] or 0) + (bankOnly[id] or 0) end
    return bags[id] or 0
end }
local locale = "enUS"
GetLocale = function() return locale end

local MAPS = {   -- Classic-era numbers: name, continent, world offset
    [1457] = { "Darnassus", 1414, 0, 0 }, [1438] = { "Teldrassil", 1414, 0, 0 }, [1439] = { "Darkshore", 1414, 500, 1000 },
    [1440] = { "Ashenvale", 1414, 500, 2000 }, [1444] = { "Feralas", 1414, 0, 6000 }, [1446] = { "Tanaris", 1414, 2000, 7000 },
    [1445] = { "Dustwallow Marsh", 1414, 2000, 4000 }, [1450] = { "Moonglade", 1414, 1000, 0 }, [1451] = { "Silithus", 1414, 0, 8000 },
    [1452] = { "Winterspring", 1414, 2000, 0 },
    [1453] = { "Stormwind City", 1415, 0, 5000 }, [1455] = { "Ironforge", 1415, 1000, 3000 }, [1429] = { "Elwynn Forest", 1415, 0, 5500 },
    [1426] = { "Dun Morogh", 1415, 900, 3000 }, [1434] = { "Stranglethorn Vale", 1415, 0, 8000 }, [1437] = { "Wetlands", 1415, 1000, 2000 },
}
local function vec(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
CreateVector2D = vec
local playerMap, px, py = 1457, 0.5, 0.5
local waypoints, supertracked = {}, nil
C_Map = {
    GetMapInfo = function(id) local m = MAPS[id]; if m then return { mapID = id, name = m[1] } end end,
    GetMapChildrenInfo = function(continent)
        local list = {}
        for id, m in pairs(MAPS) do if m[2] == continent then list[#list + 1] = { mapID = id, name = m[1] } end end
        return list
    end,
    GetBestMapForUnit = function() return playerMap end,
    GetPlayerMapPosition = function() return vec(px, py) end,
    GetWorldPosFromMapPos = function(id, v)
        local m = MAPS[id]
        if not m then return end
        return m[2], vec(m[3] + v.x * 1000, m[4] + v.y * 1000)
    end,
    CanSetUserWaypointOnMap = function(id) return MAPS[id] ~= nil end,
    SetUserWaypoint = function(p) waypoints[#waypoints + 1] = p; return true end,
}
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, x = x, y = y } end }
C_SuperTrack = { SetSuperTrackedUserWaypoint = function(b) supertracked = b end }

----- Still no professions: suggestion page
page("")
need("Good pairs while leveling", "suggestion with APIs present")

----- Alchemy 63/150 with some herbs, Herbalism 80/150, First Aid 40/75
professions[1] = { name = "Alchemy", rank = 12, maxRank = 150, skillLine = 171 }
professions[2] = { name = "Herbalism", rank = 80, maxRank = 150, skillLine = 182 }
firstAid.rank, firstAid.maxRank = 40, 75
local alchemy = ProfessionGuideData[171]
local step, stepIndex
for i, s in ipairs(alchemy.steps) do if 12 >= s.from and 12 < s.to then step, stepIndex = s, i end end
local expectLeft
if step.yellow and step.grey then
    local whole = SafeCrafts(step.from, step.to, step.yellow, step.grey)
    expectLeft = SafeCrafts(12, step.to, step.yellow, step.grey) + math.max(step.crafts - whole, 0)
else
    expectLeft = math.ceil(step.crafts * (step.to - 12) / (step.to - step.from))
end
local firstMat = step.mats[1]
bags[firstMat.itemID] = 5
page("")
need("|cffffd100Alchemy|r 12/150", "alchemy header")
need(string.format("Now: craft %s x%d until %d", step.craft, expectLeft, step.to), "current alchemy step with crafts left")
need(string.format("%s|r 5/%d, need %d more", firstMat.name, firstMat.count * expectLeft, firstMat.count * expectLeft - 5), "mat owned vs needed")
need("Next: " .. alchemy.steps[stepIndex + 1].from .. "-", "next step preview")
need("|cffffd100Herbalism|r 80/150", "herbalism header")
need("Now: gather ", "gathering step")
need("Where: ", "gathering zones")
need("|cffffd100First Aid|r 40/75", "first aid read from C_SkillInfo")
need("Type a profession for its full guide", "hint line")

----- Hub status: nothing until a craft's mats are all owned
check(ForeverHubStatus.ProfessionGuide() == nil, "no row while mats are missing")
for _, mat in ipairs(step.mats) do bags[mat.itemID] = mat.count * 3 end
local rows = ForeverHubStatus.ProfessionGuide()
check(type(rows) == "table" and #rows == 1 and rows[1].page == "Profession guide"
    and rows[1].text == string.format("|cff88bbeeCraft|r %s x3 (mats ready)", step.craft), "status row with 3 crafts ready")
-- Capped at the rank's maximum: no point nagging to craft (ProfessionCap tells you to train).
professions[1].rank, professions[1].maxRank = 75, 75
local cappedRows = ForeverHubStatus.ProfessionGuide()
check(cappedRows == nil or not cappedRows[1].text:find(step.craft, 1, true) or step.to <= 75, "no craft row while capped")
professions[1].rank, professions[1].maxRank = 12, 150

----- Shopping list: current steps only, minus what you own, vendor marked
for _, mat in ipairs(step.mats) do bags[mat.itemID] = 0 end
bags[firstMat.itemID] = 5
page("shopping")
need("Shopping list", "shopping header")
need(string.format("%d %s", firstMat.count * expectLeft - 5, firstMat.name), "owned subtracted")
for _, mat in ipairs(step.mats) do
    if mat.vendor then need(mat.name .. " |cffffd100(vendor)|r", "vendor mat marked") end
end
page("LIST")
need("Shopping list", "list alias, any case")

----- Full guide by name and prefix
page("alch")
need("|cffffd100Alchemy guide|r (you: 12)", "guide by prefix with your skill")
need("|cff66dd66> |r" .. step.from .. "-" .. step.to, "current step marked")
need("Trainers|r |cff999999(type: trainer alchemy)|r", "trainer hint")
need("Notes", "notes shown")
page("First Aid")
need("|cffffd100First Aid guide|r (you: 40)", "two-word name")
page("firstaid")
need("First Aid guide", "squashed name")
page("  SKINNING ")
need("Skinning guide", "trimmed, case-insensitive")
page("leather")
need("Leatherworking guide", "prefix")
page("bogus")
need("No guide called 'bogus'", "unknown name")
for _, name in pairs(EXPECT) do
    page(name)
    need(name .. " guide", "every guide renders")
end

----- Trainer pins: nearest on your continent, by Classic map number with a name check
playerMap, px, py = 1457, 0.55, 0.23   -- Craftsmen's Terrace, Darnassus
page("trainer alchemy")
need("Pinned ", "pinned an alchemy trainer")
check(#waypoints == 1 and waypoints[1].uiMapID == 1457, "pinned on the Darnassus map")
check(supertracked == true, "super-tracked")
page("trainer alchemy artisan")
need("Pinned Kylanna Windwhisper", "rank filter picks the Artisan trainer")
check(#waypoints > 0 and waypoints[#waypoints].uiMapID == 1444, "Feralas map")
playerMap, px, py = 1453, 0.5, 0.5     -- Stormwind
page("trainer tailoring")
local last = waypoints[#waypoints]
check(last and MAPS[last.uiMapID] and MAPS[last.uiMapID][2] == 1415, "from Stormwind, the nearest tailoring trainer is in the Eastern Kingdoms")
page("trainer")
need("Which profession?", "trainer without a profession")
page("trainer zzz")
need("Which profession?", "unknown profession")

-- A wrong number is fixed by the zone name; an unknown zone on an English client is never pinned.
local fake = { rank = "Test", name = "Wrong Number", where = "somewhere", zone = "Darnassus", mapID = 1440, x = 0.5, y = 0.5 }
local lost = { rank = "Lost", name = "Nowhere Man", where = "nowhere", zone = "Atlantis", mapID = 1457, x = 0.5, y = 0.5 }
table.insert(ProfessionGuideData[356].trainers, 1, fake)
local before = #waypoints
page("trainer fishing test")
check(#waypoints == before + 1 and waypoints[#waypoints].uiMapID == 1457, "wrong number resolved by zone name")
ProfessionGuideData[356].trainers = { lost }
before = #waypoints
page("trainer fishing")
check(#waypoints == before, "unknown zone never pinned on an English client")
need("The map pin couldn't be placed", "falls back to describing the place")
need("50.0, 50.0", "coordinates given instead")

----- Secret values and a finished path
professions[1] = { name = SECRET, rank = SECRET, maxRank = 150, skillLine = 171 }
professions[2] = { name = "Mining", rank = 300, maxRank = 300, skillLine = 186 }
firstAid.rank = SECRET
page("")
need("|cffffd100Mining|r 300/300", "mining shown")
need("Path complete", "finished path")
check(not has("Alchemy"), "secret profession skipped")
check(not has("First Aid"), "secret First Aid skipped")
check(ForeverHubStatus.ProfessionGuide() == nil, "no row from secrets")

----- A profession found by name when its skill line is hidden
professions[1] = { name = "Cooking", rank = 10, maxRank = 75, skillLine = SECRET }
page("")
need("|cffffd100Cooking|r 10/75", "cooking by name")
need("Now: craft ", "cooking step")

print = realPrint
if #failures > 0 then
    error(#failures .. " check(s) failed:\n\n" .. table.concat(failures, "\n\n"), 0)
end
print(string.format("ALL TESTS PASSED (%d steps validated)", stepCount))
