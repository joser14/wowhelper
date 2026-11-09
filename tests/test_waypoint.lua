-- Shared waypoint: a pin set through ForeverWaypoint_Set is cleared on arrival (within 15 yd), a pin the
-- player placed or moved is never cleared, and the watcher stops when there is nothing to watch.
-- Run from the harness folder:  node run.js "<workspace root>" test_waypoint.lua
local base = ADDON_PATH
local SECRET = {}
local out, frames, failures = {}, {}, {}
issecretvalue = function(v) return v == SECRET end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
CreateFrame = function()
    local f = { registered = {}, scripts = {}, shown = true }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, s, fn) self.scripts[s] = fn end
    f.Show = function(self) self.shown = true end
    f.Hide = function(self) self.shown = false end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
UnitName = function(unit) if unit == "npc" then return "Bob" end if unit == "player" then return "Me" end end
GetRealmName = function() return "R" end
time = function() return 50000 end
GetZoneText = function() return "Elwynn Forest" end
GetSubZoneText = function() return "Goldshire" end
GetMerchantNumItems = function() return 0 end
GetMerchantItemID = function() end
CanMerchantRepair = function() return true end

-- Map 37 is on continent 13 (world yards = map fraction * 10000); map 99 has no world positions;
-- map 12 is the continent map that also contains map 37's spot.
local function vec(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
CreateVector2D = vec
local mapID, px, py, readable = 37, 0.5, 0.5, true
local pin, clears, sets = nil, 0, 0
C_Map = {
    GetBestMapForUnit = function() return mapID end,
    GetPlayerMapPosition = function() if not readable then return nil end return vec(px, py) end,
    GetWorldPosFromMapPos = function(id, v)
        if id ~= 37 then return end
        return 13, vec(v.x * 10000, v.y * 10000)
    end,
    CanSetUserWaypointOnMap = function(id) return id == 37 or id == 99 end,
    SetUserWaypoint = function(p) sets = sets + 1; pin = { uiMapID = p.uiMapID, position = vec(p.x, p.y) }; return true end,
    HasUserWaypoint = function() return pin ~= nil end,
    GetUserWaypoint = function() return pin end,
    GetUserWaypointPositionForMap = function(id) if pin and pin.uiMapID == id then return pin.position end end,
    ClearUserWaypoint = function() clears = clears + 1; pin = nil end,
}
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, x = x, y = y } end }
local supertracked
C_SuperTrack = { SetSuperTrackedUserWaypoint = function(b) supertracked = b end }

local function check(cond, why) if not cond then failures[#failures + 1] = why end end
local function load(name)
    local n = #frames
    assert(loadfile(base .. "/" .. name .. "/" .. name .. ".lua"))(name, {})
    return frames[n + 1]
end
local function fire(f, ev, ...) f.scripts.OnEvent(f, ev, ...) end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
-- The watcher is the one frame with an OnUpdate script.
local function watcher()
    for _, f in ipairs(frames) do if f.scripts.OnUpdate then return f end end
end
local function tick(delta)
    local w = watcher()
    if w then w.scripts.OnUpdate(w, delta or 0.5) end
end

----- Landmarks pins through the shared routine
local lm = load("Landmarks")
check(type(ForeverWaypoint_Set) == "function", "shared routine defined")
local shared = ForeverWaypoint_Set
fire(lm, "PLAYER_LOGIN")
fire(lm, "MERCHANT_SHOW") -- Bob repairs, at 0.5, 0.5
px, py = 0.6, 0.5 -- 1000 yd away
out = {}
SlashCmdList.LANDMARKS("repair")
check(has("Pinned Bob"), "Landmarks page pinned Bob:\n" .. table.concat(out, "\n"))
check(sets == 1 and pin and pin.uiMapID == 37 and supertracked == true, "game pin set and super-tracked")
check(watcher() ~= nil and ForeverWaypoint_Active() ~= nil, "watcher running while our pin is active")

----- Far away: nothing happens; ticks under 0.5 s don't even check
tick(0.5)
check(pin ~= nil and clears == 0, "far away: pin stays")
px, py = 0.5005, 0.5 -- 5 yd away
tick(0.2)
check(pin ~= nil and clears == 0, "a check waits for 0.5 s")
tick(0.3)
check(pin == nil and clears == 1, "within 15 yd: cleared")
check(watcher() == nil and ForeverWaypoint_Active() == nil, "watcher stops after arrival")

----- 20 yd away is not arrival
check(ForeverWaypoint_Set(37, 0.5, 0.5, "test"), "set directly")
px, py = 0.502, 0.5
tick()
check(pin ~= nil and clears == 1, "20 yd: not arrived")
px, py = 0.5014, 0.5
tick()
check(pin == nil and clears == 2, "14 yd: arrived")

----- The player's own pin is never cleared
ForeverWaypoint_Set(37, 0.7, 0.7, "ours")
px, py = 0.9, 0.9
tick()
-- The player now places their own pin (a different spot) through the game's map.
pin = { uiMapID = 37, position = vec(0.3, 0.3) }
px, py = 0.3, 0.3 -- standing on the player's pin
tick()
check(pin ~= nil and clears == 2, "the player's own pin is left alone")
check(watcher() == nil, "watcher stops once the pin isn't ours")
-- Even standing on our old spot later changes nothing.
px, py = 0.7, 0.7
tick()
check(pin ~= nil and clears == 2, "still not cleared")

----- The player removed our pin: watcher just stops
ForeverWaypoint_Set(37, 0.4, 0.4, "ours")
pin = nil
tick()
check(watcher() == nil and clears == 2, "removed by the player: stop, no clear")

----- Position unreadable (instance, secret): keep the pin, keep watching
ForeverWaypoint_Set(37, 0.4, 0.4, "ours")
readable = false
px, py = 0.4, 0.4
tick()
check(pin ~= nil and watcher() ~= nil, "unreadable position: pin kept, still watching")
readable = true
mapID = 99 -- a map without world positions
tick()
check(pin ~= nil and watcher() ~= nil, "no world position here: pin kept")
mapID = 37
tick()
check(pin == nil and clears == 3, "readable again and on the spot: cleared")

----- Secret values never count as ours or as a distance
ForeverWaypoint_Set(37, 0.4, 0.4, "ours")
local realGet = C_Map.GetUserWaypoint
local realFor = C_Map.GetUserWaypointPositionForMap
C_Map.GetUserWaypoint = function() return { uiMapID = SECRET, position = vec(SECRET, SECRET) } end
C_Map.GetUserWaypointPositionForMap = function() return SECRET end
tick()
check(pin ~= nil and clears == 3 and watcher() == nil, "unreadable pin: treated as not ours, never cleared")
C_Map.GetUserWaypoint, C_Map.GetUserWaypointPositionForMap = realGet, realFor

----- The game keeps the pin on another map: ownership checked by position on our map
ForeverWaypoint_Set(37, 0.4, 0.4, "ours")
pin.uiMapID = 12 -- stored on the continent map
C_Map.GetUserWaypointPositionForMap = function(id) if id == 37 and pin then return vec(0.4, 0.4) end end
px, py = 0.4, 0.4
tick()
check(pin == nil and clears == 4, "matched through the position on our map, then cleared")
C_Map.GetUserWaypointPositionForMap = realFor

----- A map without world positions: pin set, nothing watched
local ok = ForeverWaypoint_Set(99, 0.5, 0.5, "no world")
check(ok == true and pin and pin.uiMapID == 99, "pin set on a map without world positions")
check(watcher() == nil and ForeverWaypoint_Active() == nil, "nothing to watch there")

----- Refusals
local refused, why = ForeverWaypoint_Set(55, 0.5, 0.5, "x")
check(refused == false and why == "map", "map that refuses pins")
C_Map.SetUserWaypoint = function() return false end
refused, why = ForeverWaypoint_Set(37, 0.5, 0.5, "x")
check(refused == false and why == "refused", "game refused the pin")
check(watcher() == nil, "no watcher for a refused pin")

----- Every helper shares the same routine (first definition wins)
load("DeathNotes")
load("RareWatch")
check(ForeverWaypoint_Set == shared, "later helpers reuse the same routine")

if #failures > 0 then
    error("FAILURES:\n" .. table.concat(failures, "\n"))
end
print("ALL TESTS PASSED")
