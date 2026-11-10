-- Landmarks flight times: learned from your own flights (flight map node -> taxi -> landing at the nearest
-- known node), averaged over flights, shown at the flight master and on the page. Nothing is hooked.
local base = ADDON_PATH
local out, frames, handled = {}, {}, {}
local SECRET = {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function(v) return v == SECRET end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
CreateFrame = function()
    local f = {}
    f.RegisterEvent = function() end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
UnitName = function(unit) if unit == "npc" then return "Caylais Moonfeather" end return "Me" end
GetRealmName = function() return "R" end
time = function() return 50000 end
local now = 1000
GetTime = function() return now end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
GetZoneText = function() return "Darkshore" end
GetSubZoneText = function() return "Auberdine" end

-- Darkshore (1439) is on Kalimdor (1414, the flight map). Your spot on Kalimdor is `cont`.
local zone, cont = { 0.36, 0.45 }, { 0.40, 0.30 }
local function vec(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
CreateVector2D = vec
C_Map = {
    GetBestMapForUnit = function() return 1439 end,
    GetPlayerMapPosition = function(id) if id == 1414 then return vec(cont[1], cont[2]) end return vec(zone[1], zone[2]) end,
    GetWorldPosFromMapPos = function(_, v) return 1, vec(v.x * 10000, v.y * 10000) end,
}
GetTaxiMapID = function() return 1414 end
Enum = { FlightPathState = { Current = 0, Reachable = 1, Unreachable = 2 } }
C_TaxiMap = { GetAllTaxiNodes = function()
    return {
        { nodeID = 26, name = "Auberdine, Darkshore", state = 0, position = vec(0.40, 0.30) },
        { nodeID = 27, name = "Rut'theran Village, Teldrassil", state = 1, position = vec(0.42, 0.20) },
        { nodeID = 28, name = "Astranaar, Ashenvale", state = 1, position = vec(0.45, 0.45) },
    }
end }
local onTaxi = false
UnitOnTaxi = function() return onTaxi end

assert(loadfile(base .. "/Landmarks/Landmarks.lua"))("Landmarks", {})
local lm = frames[#frames]
local function fire(ev, ...) lm.fn(lm, ev, ...) end
fire("PLAYER_LOGIN")

-- One flight: map open at Auberdine, onto the taxi, land at Rut'theran 95 seconds later.
local function fly(to, seconds)
    cont = { 0.40, 0.30 }
    fire("TAXIMAP_OPENED")
    now = now + 3
    onTaxi = true
    fire("PLAYER_CONTROL_LOST")
    now = now + seconds
    onTaxi = false
    cont = to
    fire("PLAYER_CONTROL_GAINED")
end

-- 1. First flight: learned and said once.
fly({ 0.4201, 0.2003 }, 95)
assert(out[#out] == "Flight time learned: Auberdine to Rut'theran Village, 1m 35s.", "learned: " .. tostring(out[#out]))
-- 2. A second flight is averaged in, quietly.
out = {}
fly({ 0.42, 0.20 }, 105)
for _, line in ipairs(out) do assert(not line:find("learned", 1, true), "quiet the second time") end
assert(LandmarksDB.R.flightTimes["26>27"].seconds == 100 and LandmarksDB.R.flightTimes["26>27"].count == 2, "averaged")
-- 3. At the flight master: the known times from here.
out = {}
cont = { 0.40, 0.30 }
fire("TAXIMAP_OPENED")
assert(out[1] == "Flight times from here: Rut'theran Village 1m 40s.", "at the flight master: " .. tostring(out[1]))
-- 4. Landing far from any known node, or losing control without a taxi (a stun), records nothing.
fly({ 0.9, 0.9 }, 60)
onTaxi = false
fire("PLAYER_CONTROL_LOST"); now = now + 5; fire("PLAYER_CONTROL_GAINED")
local n = 0
for _ in pairs(LandmarksDB.R.flightTimes) do n = n + 1 end
assert(n == 1, "nothing else recorded: " .. n)
-- 5. The page lists times from the nearest flight master.
out = {}
SlashCmdList.LANDMARKS("")
local page = table.concat(out, "\n")
assert(page:find("Flight times from Auberdine:|r Rut'theran Village 1m 40s", 1, true), "page:\n" .. page)
assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
