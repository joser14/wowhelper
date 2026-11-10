-- Dungeons smoke test: data validation, the level page, details with quest states and loot marks,
-- name/number lookup, pinning (including the by-name map lookup), "all", the side panel status,
-- secret values, and loading with no game APIs at all.
-- Run from the harness folder:  node run.js "<workspace root>" test_dungeons.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local SECRET = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why .. "\n  output was:\n  " .. table.concat(out, "\n  ") end end

-- 1. Loading with nothing but SlashCmdList and CreateFrame must not error, and prints nothing.
SlashCmdList = {}
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
assert(loadfile(base .. "/Dungeons/Data.lua"))("Dungeons", {})
assert(loadfile(base .. "/Dungeons/Dungeons.lua"))("Dungeons", {})
do
    local ok, err = pcall(SlashCmdList.DUNGEONS, "")
    check(ok, "bare page without APIs: " .. tostring(err))
    for _, arg in ipairs({ "3", "wc", "pin 3", "all", "nonsense", "pin" }) do
        ok, err = pcall(SlashCmdList.DUNGEONS, arg)
        check(ok, "page '" .. arg .. "' without APIs: " .. tostring(err))
    end
    ok, err = pcall(ForeverHubStatus.Dungeons)
    check(ok, "status without APIs: " .. tostring(err))
    ok, err = pcall(frames[#frames].fn, frames[#frames], "PLAYER_LOGIN")
    check(ok, "login event without APIs: " .. tostring(err))
end

-- 2. Data validation.
local D = DungeonsData
check(type(D) == "table" and #D >= 30, "DungeonsData has the dungeons")
local shorts, mapsUsed = {}, {}
local function isNum(v) return type(v) == "number" and v == math.floor(v) and v > 0 end
for i, d in ipairs(D) do
    local tag = "dungeon " .. i .. " (" .. tostring(d.name) .. ")"
    check(type(d.name) == "string" and d.name ~= "", tag .. ": name")
    check(type(d.short) == "string" and d.short == d.short:lower() and d.short ~= "", tag .. ": short lower-case")
    check(not shorts[d.short], tag .. ": short '" .. tostring(d.short) .. "' unique")
    shorts[d.short] = true
    check(isNum(d.minLevel) and isNum(d.maxLevel) and d.minLevel <= d.maxLevel and d.maxLevel <= 60 and d.minLevel >= 10, tag .. ": levels")
    if i > 1 then check(d.minLevel >= D[i - 1].minLevel, tag .. ": sorted by minLevel") end
    check(type(d.zone) == "string", tag .. ": zone")
    local e = d.entrance
    check(type(e) == "table", tag .. ": entrance")
    if e then
        check(type(e.x) == "number" and e.x > 0 and e.x < 1 and type(e.y) == "number" and e.y > 0 and e.y < 1, tag .. ": entrance x/y in 0..1")
        check(type(e.zone) == "string", tag .. ": entrance zone name")
        check(e.mapID == nil or isNum(e.mapID), tag .. ": mapID is a number")
        check(e.mapID ~= nil or d.forever, tag .. ": only Forever-only zones may lack a mapID")
        if e.mapID then mapsUsed[e.mapID] = e.zone end
    end
    check(type(d.bosses) == "table" and #d.bosses >= 1, tag .. ": bosses")
    check(type(d.quests) == "table" and type(d.loot) == "table", tag .. ": quests and loot tables")
    for qi, q in ipairs(d.quests) do
        local qt = tag .. " quest " .. qi
        check(type(q.title) == "string" and type(q.giver) == "string" and type(q.where) == "string", qt .. ": title/giver/where")
        check(type(q.questIDs) == "table" and #q.questIDs >= 1, qt .. ": questIDs")
        for _, id in ipairs(q.questIDs or {}) do check(isNum(id), qt .. ": quest ID is a number") end
        check(isNum(q.level) and q.level <= 60, qt .. ": level")
        check(q.min == nil or (isNum(q.min) and q.min <= q.level), qt .. ": min <= level")
    end
    for li, item in ipairs(d.loot) do
        check(isNum(item[1]) and type(item[2]) == "string" and type(item[4]) == "string", tag .. " loot " .. li .. ": id/name/slot")
    end
end
-- One zone name per map number.
local zoneByMap = {}
for _, d in ipairs(D) do
    local e = d.entrance
    if e and e.mapID then
        check(zoneByMap[e.mapID] == nil or zoneByMap[e.mapID] == e.zone, d.name .. ": map " .. e.mapID .. " has one zone name")
        zoneByMap[e.mapID] = e.zone
    end
end
for _, name in ipairs({ "Wailing Caverns", "The Deadmines", "Shadowfang Keep", "Blackfathom Deeps", "The Stockade", "Gnomeregan",
    "Razorfen Kraul", "Razorfen Downs", "Uldaman", "Zul'Farrak", "Maraudon", "Sunken Temple", "Blackrock Depths",
    "Lower Blackrock Spire", "Upper Blackrock Spire", "Scholomance", "Ragefire Chasm", "Dire Maul East", "Dire Maul West",
    "Dire Maul North", "Scarlet Monastery Graveyard", "Scarlet Monastery Library", "Scarlet Monastery Armory",
    "Scarlet Monastery Cathedral", "Stratholme Main Gate", "Stratholme Service Gate" }) do
    local found = false
    for _, d in ipairs(D) do if d.name == name then found = true end end
    check(found, "dungeon present: " .. name)
end

-- 3. A full game world.
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function(v) return v == SECRET end
local level = 20
UnitLevel = function() return level end
UnitClass = function() return "Druid", "DRUID" end
UnitFactionGroup = function() return "Alliance" end
local completed, inlog, complete = {}, {}, {}
C_QuestLog = {
    IsQuestFlaggedCompleted = function(id) return completed[id] == true end,
    GetLogIndexForQuestID = function(id) return inlog[id] end,
    IsComplete = function(id) return complete[id] == true end,
}
local owned = {}
C_Item = { GetItemCount = function(id) return owned[id] or 0 end }
-- Map names as a Forever client might report them: 10 is "Northern Barrens", the single Barrens is 1413.
local mapNames = { [52] = "Westfall", [63] = "Ashenvale", [10] = "Northern Barrens", [1413] = "The Barrens", [18] = "Tirisfal Glades" }
local waypoints, canPin = {}, true
C_Map = {
    GetMapInfo = function(id) return mapNames[id] and { mapID = id, name = mapNames[id] } or nil end,
    GetMapChildrenInfo = function(c)
        if c == 12 then return { { mapID = 9999, name = "Riverglades" } } end
        return {}
    end,
    CanSetUserWaypointOnMap = function() return canPin end,
    SetUserWaypoint = function(p) waypoints[#waypoints + 1] = p; return true end,
}
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, x = x, y = y } end }
local tracked = false
C_SuperTrack = { SetSuperTrackedUserWaypoint = function(v) tracked = v end }

frames, SlashCmdList, ForeverHubStatus = {}, {}, nil
assert(loadfile(base .. "/Dungeons/Dungeons.lua"))("Dungeons", {})
local f = frames[1]
check(f and f.registered.PLAYER_LOGIN and f.registered.QUEST_LOG_UPDATE, "events registered")
f.fn(f, "PLAYER_LOGIN")

local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function need(text, why) check(has(text), why .. ": wanted '" .. text .. "'") end
local function page(arg)
    out = {}
    local ok, err = pcall(SlashCmdList.DUNGEONS, arg)
    if not ok then out[#out + 1] = "<<ERROR: " .. tostring(err) .. ">>" end
    check(ok, "page '" .. tostring(arg) .. "' runs")
end
local function indexOf(short) for i, d in ipairs(D) do if d.short == short then return i end end end

-- Level page at 20.
completed[214] = true          -- Red Silk Bandanas done
inlog[166] = 3                 -- The Defias Brotherhood in log
page("")
need("Dungeons for level 20", "header")
need("The Deadmines", "Deadmines suits level 20")
need("Wailing Caverns", "WC suits level 20")
check(not has("Zul'Farrak"), "ZF not shown at 20")
need("1/7 done", "deadmines counts done")
need("1 in your log", "deadmines counts in log")
need("Coming up:", "coming up line")
need("Blackfathom Deeps", "BFD is coming up (24-2 = 22 > 20)")
check(SlashCmdList.DUNGEONS and SLASH_DUNGEONS1 == "/dungeons", "slash command")

-- Details by short, number and prefix.
owned[5191] = 1
page("dm")
need(indexOf("dm") .. ". The Deadmines", "details by short")
need("Done|r: Red Silk Bandanas", "done quest marked")
need("In your log|r: The Defias Brotherhood", "log quest marked")
need("Not started: Underground Assault", "open quest marked")
need("Cruel Barb", "loot listed")
need("(you have it)", "owned item marked")
need("Chausses of Westfall", "mail item listed")
need("(your class can't wear mail)", "druid can't wear the mail chausses")
page(tostring(indexOf("wc")))
need("Wailing Caverns", "details by number")
need("Entrance:|r The Barrens 46.0, 36.3", "entrance text")
need("pin " .. indexOf("wc"), "pin hint")
page("deadm")
need("The Deadmines", "prefix lookup of name without 'The'")
page("sm")
need("Which one?", "ambiguous prefix asks which")
page("sm armory")
need("Scarlet Monastery Armory", "two-word short")
page("zzz")
need("I don't know a dungeon called 'zzz'", "unknown name")
page("99")
need("I don't know a dungeon", "bad number")

-- Pinning: Westfall by its own number; Barrens through the Classic number; Riverglades by name.
page("pin dm")
need("Pinned the entrance to The Deadmines", "pin by short")
check(waypoints[#waypoints].uiMapID == 52 and math.abs(waypoints[#waypoints].x - 0.426) < 1e-9, "pinned on Westfall")
check(tracked == true, "supertracked")
page("pin " .. indexOf("wc"))
check(waypoints[#waypoints].uiMapID == 1413, "Barrens resolved to the map named The Barrens: " .. tostring(waypoints[#waypoints].uiMapID))
page("pin kroldok")
check(waypoints[#waypoints].uiMapID == 9999, "Riverglades found by name")
canPin = false
local before = #waypoints
page("pin bfd")
need("Can't pin that from here", "refused pin explained")
need("Ashenvale 14.5, 14.6", "refused pin still gives the coordinates")
check(#waypoints == before, "no waypoint when the map refuses")
canPin = true
page("pin")
need("Type pin and a number", "bare pin")

-- Higher level: armor marks and "all".
level = 45
page("ulda")
need("(your class can't wear mail)", "druid can't wear mail")
check(not has("(your class can't wear leather)"), "druid wears leather")
UnitClass = function() return "Hunter", "HUNTER" end
level = 30
page("ulda")
need("(mail from level 40)", "hunter mail from 40")
need("(level 38)", "quest level shown")
level = 20
page("all")
need("Every dungeon", "all header")
check(#out == #D + 1, "one line per dungeon in all: " .. #out)

-- Too low for a quest.
completed[214] = nil
level = 13
page("dm")
need("From level 14|r: Red Silk Bandanas", "too-low quest shows its level")

-- Status: nothing ready, then a ready quest after a log update.
check(ForeverHubStatus.Dungeons() == nil, "no status row by default")
inlog[2040], complete[2040] = 5, true
check(ForeverHubStatus.Dungeons() == nil, "status cached until the log changes")
f.fn(f, "QUEST_LOG_UPDATE")
local rows = ForeverHubStatus.Dungeons()
check(rows and rows[1] and rows[1].text:find("Underground Assault", 1, true) and rows[1].page == "Dungeons", "status row for a ready quest")

-- Secret values never leak or break the page.
UnitLevel = function() return SECRET end
C_QuestLog.IsQuestFlaggedCompleted = function() return SECRET end
C_QuestLog.GetLogIndexForQuestID = function() return SECRET end
C_Item.GetItemCount = function() return SECRET end
UnitClass = function() return SECRET, SECRET end
page("")
-- Review 2026-11-10: a hidden level isn't level 1; the page says it can't be read.
need("Your level can't be read right now", "secret level is said, not taken as 1")
page("dm")
check(not has("<<ERROR"), "details with secret values")

-- No hub: silent.
ForeverHub_Receive = nil
local printed = false
local realPrint = print
print = function() printed = true end
pcall(SlashCmdList.DUNGEONS, "")
print = realPrint
check(not printed, "nothing printed to chat without the hub")

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_dungeons: all checks passed (" .. #D .. " dungeons)")
