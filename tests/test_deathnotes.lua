-- DeathNotes smoke test: records a death with its killer and spot, warns when you walk back,
-- warns once per approach, stops warning once outleveled, pins and forgets by number.
-- Run from the harness folder:  node run.js "<workspace root>" test_deathnotes.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local SECRET = {}
local foe
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
UnitName = function(unit) if unit == "player" then return "Juan" elseif unit == "target" then return foe end end
UnitGUID = function() return "Player-1-ABC" end
local level = 12
UnitLevel = function() return level end
local dead = false
UnitIsDeadOrGhost = function() return dead end
GetRealmName = function() return "R" end
local clock, gametime = 50000, 1000
time = function() return clock end
GetTime = function() return gametime end
GetZoneText = function() return "Elwynn Forest" end
GetSubZoneText = function() return "Goldshire" end
geterrorhandler = function() return function(e) failures[#failures + 1] = "error handler: " .. tostring(e) end end

local tickers = {}
C_Timer = { NewTicker = function(_, fn) tickers[#tickers + 1] = fn end }

local mapID, px, py = 37, 0.5, 0.5
local CONTINENT = { [37] = 13, [57] = 12 }
local function vec(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
CreateVector2D = vec
local waypoints = {}
C_Map = {
    GetBestMapForUnit = function() return mapID end,
    GetPlayerMapPosition = function() return vec(px, py) end,
    GetWorldPosFromMapPos = function(id, v)
        local c = CONTINENT[id]
        if not c then return end
        return c, vec(math.floor(v.x * 10000 + 0.5), math.floor(v.y * 10000 + 0.5))
    end,
    SetUserWaypoint = function(p) waypoints[#waypoints + 1] = p; return true end,
}
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, x = x, y = y } end }
C_SuperTrack = { SetSuperTrackedUserWaypoint = function() end }

-- The killer comes from your hostile target (the combat log is closed on Forever).
UnitExists = function(u) return u == "target" and foe ~= nil end
UnitCanAttack = function() return true end

local n = #frames
assert(loadfile(base .. "/DeathNotes/DeathNotes.lua"))("DeathNotes", {})
local f = frames[n + 1]
assert(not f.registered.COMBAT_LOG_EVENT_UNFILTERED, "never registers the combat log: Forever forbids it (blocked-action pop-up)")
local function fire(ev) clock = clock + 1; gametime = gametime + 1; f.fn(f, ev) end
local function tick() for _, t in ipairs(tickers) do t() end end
local function at(x, y, m) px, py = x, y; if m then mapID = m end end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function dump() return "\n  output was:\n  " .. table.concat(out, "\n  ") end
local function check(cond, why) if not cond then failures[#failures + 1] = why .. dump() end end
local function need(text, why) check(has(text), why .. ": wanted '" .. text .. "'") end
local function page(arg)
    out = {}
    local ok, err = pcall(SlashCmdList.DEATHNOTES, arg)
    if not ok then out[#out + 1] = "<<ERROR: " .. tostring(err) .. ">>" end
end

fire("PLAYER_LOGIN")
check(#tickers == 1, "a ticker is started at login")

-- Empty page.
page("")
need("No deaths remembered", "empty page")

-- A wolf hits us, then we die.
foe = "Young Wolf"
out = {}
fire("PLAYER_DEAD")
need("Noted: died at level 12", "death noted")
need("to Young Wolf", "killer named")
check(DeathNotesDB.R.deaths[1].wx == 5000, "world position saved")

-- No hostile target: no killer.
foe = nil
at(0.7, 0.7)
out = {}
fire("PLAYER_DEAD")
need("Noted: died at level 12 in Goldshire, Elwynn Forest.", "death without a known killer has no 'to'")

-- Page lists newest first with distances; number 2 is the wolf death.
page("")
need("1.|r Level 12", "first line is latest death")
need("killed by Young Wolf", "wolf death listed")
need("2 death(s) remembered", "count")
check(not has("Repeat offenders"), "no repeat offenders with one killer each")

-- Walk away, come back: warn once, not twice; after leaving far and returning, warn again.
dead = false
at(0.9, 0.9)
out = {}
tick()
check(#out == 0, "no warning far away")
at(0.503, 0.503)  -- ~42 yd from the wolf death
tick()
need("Careful: you died near here at level 12 to Young Wolf", "warning when back at the spot")
out = {}
tick()
check(#out == 0, "no repeat warning while staying")
check(ForeverHubStatus.DeathNotes() ~= nil, "status row while near")
at(0.52, 0.52)  -- ~283 yd away, clears the spot
tick()
check(ForeverHubStatus.DeathNotes() == nil, "status row gone when away")
at(0.5, 0.5)
out = {}
tick()
need("Careful", "warns again on a fresh approach")

-- Outleveled spots stay quiet.
level = 17
at(0.9, 0.9); tick()
at(0.5, 0.5); out = {}; tick()
check(#out == 0, "no warning once 5 levels above")
level = 12

-- Pin by number, forget by number, forget all.
page("2")
need("Pinned death 2", "pin")
check(waypoints[#waypoints] and waypoints[#waypoints].uiMapID == 37 and waypoints[#waypoints].x == 0.5, "pin at wolf spot")
page("9")
need("no death with that number", "bad number")
page("forget 1")
need("Forgot death 1", "forget one")
check(#DeathNotesDB.R.deaths == 1 and DeathNotesDB.R.deaths[1].killer == "Young Wolf", "the right death was removed")
page("forget all")
need("Forgot 1 death", "forget all")
need("No deaths remembered", "empty after forget all")

-- Repeat offenders.
foe = "Defias Thug"
for _ = 1, 2 do fire("PLAYER_DEAD") end
foe = nil
page("")
need("Repeat offenders: Defias Thug x2", "repeat offenders")

-- No combat log: the hostile target at death names the killer.
gametime = gametime + 30
foe = "x"
local realUnitName = UnitName
UnitName = function(u) if u == "target" then return "Murloc Raider" end return realUnitName(u) end
out = {}
fire("PLAYER_DEAD")
need("to Murloc Raider", "target used as the killer when no recent hit")
UnitName = function(u) if u == "target" then return SECRET end return realUnitName(u) end
out = {}
fire("PLAYER_DEAD")
check(not has(" to "), "secret target name is left out")
UnitName = realUnitName

-- Dead, the game may stop calling the target attackable: the hostile target seen just before counts.
foe = "Gnoll Brute"
fire("PLAYER_TARGET_CHANGED")
UnitCanAttack = function() return false end
out = {}
fire("PLAYER_DEAD")
need("to Gnoll Brute", "last hostile target remembered for the death")
out = {}
gametime = gametime + 60
fire("PLAYER_DEAD")
check(not has(" to "), "an old foe is not blamed for a later death")
UnitCanAttack = function() return true end
foe = nil

-- Dying ends combat a moment before PLAYER_DEAD: the foe must survive that.
foe = "Moonkin Oracle"
fire("PLAYER_REGEN_DISABLED")
UnitCanAttack = function() return false end
fire("PLAYER_REGEN_ENABLED")
out = {}
fire("PLAYER_DEAD")
need("to Moonkin Oracle", "foe kept when combat ends just before death")
-- A fight that ended long before a fall is not blamed.
foe = "Moonkin Oracle"
UnitCanAttack = function() return true end
fire("PLAYER_REGEN_DISABLED")
fire("PLAYER_REGEN_ENABLED")
gametime = gametime + 10
UnitCanAttack = function() return false end
out = {}
fire("PLAYER_DEAD")
check(not has(" to "), "an ended fight is not blamed for a later death")
UnitCanAttack = function() return true end
foe = nil

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_deathnotes: all checks passed")
