-- GoldGuide in the hub: after you type "all", the hub shows that list and then redraws the page's
-- default view (the best farms) below it, in the same frame. A number you then type must still pin
-- the farm that number names in the list you read, whichever list that was.
-- Run from the harness folder:  node run.js "<workspace root>" test_logic_hub_goldguide.lua
local base = ADDON_PATH
local out, failures = {}, {}
local function check(cond, why) if not cond then failures[#failures + 1] = why .. "\n  page was:\n  " .. table.concat(out, "\n  ") end end

ForeverHub_Receive = function(_, t) out[#out + 1] = t end
local frames = {}
CreateFrame = function()
    local f = {}
    f.RegisterEvent = function() end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
time = function() return 1000000 end
GetTime = function() return 500 end
GetRealmName = function() return "R" end
UnitFactionGroup = function() return "Alliance" end
local level = 12
UnitLevel = function() return level end

local MAPNAME = {}
assert(loadfile(base .. "/GoldGuide/Data.lua"))("GoldGuide", {})
for zone, ids in pairs(GoldGuideData.zones) do MAPNAME[ids[1]] = zone end
local waypoints = {}
C_Map = {
    CanSetUserWaypointOnMap = function(m) return MAPNAME[m] ~= nil end,
    GetMapInfo = function(m) if MAPNAME[m] then return { name = MAPNAME[m] } end end,
    SetUserWaypoint = function(p) waypoints[#waypoints + 1] = p; return true end,
}
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, x = x, y = y } end }

assert(loadfile(base .. "/GoldGuide/GoldGuide.lua"))("GoldGuide", {})
local gg = frames[#frames]
gg.fn(gg, "PLAYER_LOGIN")

-- What the hub does for one Enter in the box: run the command, then redraw the page's default view.
local function submit(text)
    out = {}
    SlashCmdList.GOLDGUIDE(text)
    local typed = out
    out = {}
    SlashCmdList.GOLDGUIDE("")
    local page = out
    out = {}
    for _, t in ipairs(typed) do out[#out + 1] = t end
    out[#out + 1] = "----- page redraw -----"
    for _, t in ipairs(page) do out[#out + 1] = t end
    return typed, page
end

local function numberOf(lines, zone)
    for _, t in ipairs(lines) do
        local n, name = t:match("|cffffd100(%d+)%.|r ([^|]+) |cff999999%- " .. zone)
        if n then return tonumber(n), name end
    end
end

-- Level 12: Felwood (level 50+) is only in the "all" list, never in the best list below it.
local typed = submit("all")
local n, name = numberOf(typed, "Felwood")
check(n and name, "a Felwood farm is numbered in the all list")
if n then
    local before = #waypoints
    local pinned = submit(tostring(n))
    local said = table.concat(pinned, "\n")
    check(said:find("Pinned " .. name, 1, true) ~= nil, "typing " .. n .. " pins '" .. tostring(name) .. "' from the all list, got: " .. said)
    check(#waypoints == before + 1 and MAPNAME[waypoints[#waypoints].uiMapID] == "Felwood", "the waypoint is in Felwood")
end

-- The best list keeps working: a number from it pins that farm.
local _, page = submit("tips")
local bn, bname = numberOf(page, "Darkshore")
check(bn and bname, "a Darkshore farm on the best list at 12")
if bn then
    local pinned = submit(tostring(bn))
    check(table.concat(pinned, "\n"):find("Pinned " .. bname, 1, true) ~= nil, "best-list number pins that farm")
    check(MAPNAME[waypoints[#waypoints].uiMapID] == "Darkshore", "waypoint in Darkshore")
end

if #failures > 0 then
    error(#failures .. " check(s) failed:\n\n" .. table.concat(failures, "\n\n"), 0)
end
print("ALL TESTS PASSED")
