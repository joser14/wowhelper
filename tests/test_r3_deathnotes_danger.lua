-- Round 3 #9: DeathNotes warns before you die there: a zone well above your level, and an elite or
-- rare elite 2+ levels above you on target or mouseover. Rate-limited, once per mob, switchable.
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local SECRET = {}
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
local level = 12
local units = {}  -- unit token -> { name, guid, level, class, hostile, dead }
UnitName = function(unit) if unit == "player" then return "Juan" end return units[unit] and units[unit].name end
UnitGUID = function(unit) if unit == "player" then return "Player-1-ABC" end return units[unit] and units[unit].guid end
UnitLevel = function(unit) if unit == "player" then return level end return units[unit] and units[unit].level end
UnitExists = function(unit) return units[unit] ~= nil end
UnitCanAttack = function(_, unit) return units[unit] ~= nil and units[unit].hostile ~= false end
UnitIsDeadOrGhost = function(unit) return unit ~= "player" and units[unit] and units[unit].dead or false end
UnitClassification = function(unit) return units[unit] and units[unit].class end
UnitIsPlayer = function() return false end
UnitAffectingCombat = function() return false end
IsInInstance = function() return false end
GetRealmName = function() return "R" end
local clock, gametime = 50000, 1000
time = function() return clock end
GetTime = function() return gametime end
GetZoneText = function() return "Duskwood" end
GetSubZoneText = function() return "" end
geterrorhandler = function() return function(e) failures[#failures + 1] = "error handler: " .. tostring(e) end end
C_Timer = { NewTicker = function() end, After = function() end }
local here = 1431
local mapNames = { [1431] = "Duskwood", [1433] = "Redridge Mountains", [1418] = "Badlands", [1429] = "Elwynn Forest" }
local apiLevels = { [1431] = { 18, 30 }, [1433] = { 15, 25 }, [1418] = { 35, 45 } }
C_Map = {
    GetBestMapForUnit = function() return here end,
    GetMapInfo = function(id) return { name = mapNames[id], mapType = 3, parentMapID = 1415 } end,
    GetMapLevels = function(id) local l = apiLevels[id] if l then return l[1], l[2] end return 0, 0 end,
    GetPlayerMapPosition = function() return nil end,
}

local n = #frames
assert(loadfile(base .. "/DeathNotes/DeathNotes.lua"))("DeathNotes", {})
local f = frames[n + 1]
local function fire(ev, ...) clock = clock + 1; gametime = gametime + 1; f.fn(f, ev, ...) end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function dump() return "\n  output was:\n  " .. table.concat(out, "\n  ") end
local function check(cond, why) if not cond then failures[#failures + 1] = why .. dump() end end
local function need(text, why) check(has(text), why .. ": wanted '" .. text .. "'") end
local function none(why) check(#out == 0, why .. ": wanted no output") end
local function reset() out = {} end

check(f.registered.UPDATE_MOUSEOVER_UNIT, "listens for mouseover")
check(f.registered.ZONE_CHANGED_NEW_AREA, "listens for zone changes")
check(not f.registered.COMBAT_LOG_EVENT_UNFILTERED, "never the combat log")
fire("PLAYER_LOGIN")

----- Zone danger (ZoneLevels not loaded: DeathNotes reads the game's range itself)
reset(); fire("ZONE_CHANGED_NEW_AREA")
need("Careful: Duskwood is level 18-30", "zone 6 levels above")
reset(); here = 1429; fire("ZONE_CHANGED_NEW_AREA"); here = 1431; fire("ZONE_CHANGED_NEW_AREA")
none("same zone again soon: quiet")
level = 13; here = 1433
reset(); fire("ZONE_CHANGED_NEW_AREA")
none("Redridge 15-25 at 13 is only 2 above")
-- ZoneLevels loaded and on: it does the zone warning, DeathNotes stays quiet.
ForeverZoneLevels = function(id) if id == 1418 then return 35, 45, "Badlands" end end
ForeverHub_IsOff = function() return false end
here = 1418
reset(); fire("ZONE_CHANGED_NEW_AREA")
none("ZoneLevels covers the zone warning")
-- ZoneLevels switched off in the hub: DeathNotes warns, using its table.
ForeverHub_IsOff = function(name) return name == "ZoneLevels" end
apiLevels[1418] = nil
here = 1429; fire("ZONE_CHANGED_NEW_AREA"); here = 1418
reset(); fire("ZONE_CHANGED_NEW_AREA")
need("Careful: Badlands is level 35-45", "ZoneLevels off: DeathNotes warns")
ForeverHub_IsOff = nil

----- Elite danger
level = 12
units.mouseover = { name = "Defias Brute", guid = "Creature-0-1-2-3-100-A", level = 15, class = "elite" }
reset(); fire("UPDATE_MOUSEOVER_UNIT")
need("Careful: Defias Brute", "elite 3 above on mouseover")
need("elite", "says elite")
reset(); fire("UPDATE_MOUSEOVER_UNIT")
none("same mob: once")
units.mouseover = { name = "Defias Brute", guid = "Creature-0-1-2-3-100-B", level = 14, class = "elite" }
reset(); fire("UPDATE_MOUSEOVER_UNIT")
none("another one within the rate limit")
gametime = gametime + 60
reset(); fire("UPDATE_MOUSEOVER_UNIT")
need("Careful: Defias Brute", "after the rate limit, a new GUID warns")
gametime = gametime + 60
units.mouseover = { name = "Gnoll", guid = "Creature-0-1-2-3-101-A", level = 18, class = "normal" }
reset(); fire("UPDATE_MOUSEOVER_UNIT")
none("normal mobs don't warn")
units.mouseover = { name = "Ogre", guid = "Creature-0-1-2-3-102-A", level = 13, class = "elite" }
reset(); fire("UPDATE_MOUSEOVER_UNIT")
none("elite only 1 above")
units.mouseover = { name = "Ogre", guid = "Creature-0-1-2-3-102-B", level = SECRET, class = SECRET }
reset(); fire("UPDATE_MOUSEOVER_UNIT")
none("secret values: quiet, no error")
units.mouseover = { name = "Guard", guid = "Creature-0-1-2-3-103-A", level = 55, class = "elite", hostile = false }
reset(); fire("UPDATE_MOUSEOVER_UNIT")
none("friendly elites don't warn")
units.mouseover = { name = "Corpse", guid = "Creature-0-1-2-3-104-A", level = 20, class = "elite", dead = true }
reset(); fire("UPDATE_MOUSEOVER_UNIT")
none("dead ones don't warn")
units.mouseover = nil
units.target = { name = "Old Murk-Eye", guid = "Creature-0-1-2-3-105-A", level = 14, class = "rareelite" }
reset(); fire("PLAYER_TARGET_CHANGED")
need("Careful: Old Murk-Eye", "rare elite on target")
need("rare elite", "says rare elite")
gametime = gametime + 60
units.target = { name = "Big Skull", guid = "Creature-0-1-2-3-106-A", level = -1, class = "elite" }
reset(); fire("PLAYER_TARGET_CHANGED")
need("Careful: Big Skull", "skull elite")
gametime = gametime + 60
IsInInstance = function() return true end
units.target = { name = "Dungeon Elite", guid = "Creature-0-1-2-3-107-A", level = 20, class = "elite" }
reset(); fire("PLAYER_TARGET_CHANGED")
none("inside an instance every mob is elite: quiet")
IsInInstance = function() return false end

----- Switches (the hub's Options page)
local options = ForeverHubOptions and ForeverHubOptions.DeathNotes
check(options and type(options.rows) == "table" and #options.rows >= 2, "DeathNotes offers switches")
if options then
    for _, row in ipairs(options.rows) do
        check(row.get() == true, "on by default: " .. tostring(row.label))
        row.set(false)
        check(row.get() == false, "switches off: " .. tostring(row.label))
    end
    gametime = gametime + 60
    units.target = { name = "Another Elite", guid = "Creature-0-1-2-3-108-A", level = 20, class = "elite" }
    reset(); fire("PLAYER_TARGET_CHANGED")
    none("elite warning off")
    here = 1429; fire("ZONE_CHANGED_NEW_AREA"); gametime = gametime + 3600; here = 1431
    reset(); fire("ZONE_CHANGED_NEW_AREA")
    none("zone warning off")
    check(type(DeathNotesDB._options) == "table", "switches saved")
end

if #failures > 0 then
    error("FAILURES:\n" .. table.concat(failures, "\n"))
end
print("test_r3_deathnotes_danger: ok")
