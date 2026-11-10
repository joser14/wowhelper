-- /way (MapPins\Way.lua): pins a spot on the zone you're in or a zone by name, through the shared Forever
-- waypoint; names after the numbers; website commas; unclear or unknown names; clear; bad numbers.
local base = ADDON_PATH
local out, handled = {}, {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function() return false end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
SlashCmdList = {}
local pins, cleared = {}, 0
local active
ForeverWaypoint_Set = function(mapID, x, y, label)
    if mapID == 1457 then return false, "map" end
    pins[#pins + 1] = { mapID = mapID, x = x, y = y, label = label }
    active = pins[#pins]
    return true
end
ForeverWaypoint_Active = function() return active end
local maps = {
    { mapID = 1439, name = "Darkshore" }, { mapID = 1438, name = "Teldrassil" }, { mapID = 1457, name = "Darnassus" },
    { mapID = 1440, name = "Ashenvale" }, { mapID = 1429, name = "Elwynn Forest" },
}
local here = 1438
C_Map = {
    GetMapChildrenInfo = function() return maps end,
    GetBestMapForUnit = function() return here end,
    GetMapInfo = function(id) for _, m in ipairs(maps) do if m.mapID == id then return m end end end,
    ClearUserWaypoint = function() cleared = cleared + 1; active = nil end,
}
Enum = { UIMapType = { Zone = 3 } }

assert(loadfile(base .. "/MapPins/Way.lua"))("MapPins", {})
local way = SlashCmdList.FOREVERWAY
assert(way and SLASH_FOREVERWAY1 == "/way", "/way registered")
local function last() return out[#out] or "" end

-- 1. Your own zone.
way("45.2 58.5")
assert(pins[1].mapID == 1438 and math.abs(pins[1].x - 0.452) < 1e-9 and math.abs(pins[1].y - 0.585) < 1e-9, "here")
assert(last():find("Pinned Teldrassil 45.2, 58.5", 1, true), last())
-- 2. A zone by name, website commas, a name for the pin.
way("Darkshore 45.2, 58.5 Jai'vhanel")
assert(pins[2].mapID == 1439 and pins[2].label == "Jai'vhanel", "named zone and label")
assert(last():find("Pinned Jai'vhanel, Darkshore 45.2, 58.5", 1, true), last())
-- 3. Start of a name is enough when only one fits; two fits ask for more; unknown says so.
way("elw 40 60")
assert(pins[3].mapID == 1429, "prefix")
way("Da 10 10")
assert(last():find("More than one map starts with", 1, true) and #pins == 3, "unclear: " .. last())
way("Narnia 10 10")
assert(last():find("No zone or city called", 1, true), last())
-- 4. A map the game won't pin; numbers out of range; no numbers.
way("Darnassus 40 50")
assert(last():find("doesn't allow a map pin on Darnassus", 1, true), last())
way("150 20")
assert(last():find("0 to 100", 1, true), last())
way("hello")
assert(last():find("Pin a spot", 1, true), last())
-- 5. Clear.
way("clear")
assert(cleared == 1 and last() == "Map pin cleared.", last())
way("clear")
assert(last() == "No pin of ours to clear.", last())
assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
