-- Review 6b (DeathNotes recap): a recap whose timestamps can't be read (secret) is still recognised
-- when it comes back for a later death, so an old killer is never pinned on a new death.
-- Run from the harness folder:  node run.js "<workspace root>" test_cr6b_deathrecap.lua
local base = ADDON_PATH
local failures = {}
local SECRET = setmetatable({}, {
    __eq = function() error("compared a secret") end, __lt = function() error("compared a secret") end,
    __le = function() error("compared a secret") end, __concat = function() error("joined a secret") end,
    __add = function() error("arithmetic on a secret") end, __sub = function() error("arithmetic on a secret") end,
})
local function check(cond, why) if not cond then failures[#failures + 1] = why end end

local out, timers, frames, foe = {}, {}, {}, nil
local gametime, clock = 1000, 50000
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function(v) return rawequal(v, SECRET) end
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
UnitLevel = function() return 12 end
UnitIsDeadOrGhost = function() return false end
UnitExists = function(u) return u == "target" and foe ~= nil end
UnitCanAttack = function() return true end
GetRealmName = function() return "R" end
time = function() return clock end
GetTime = function() return gametime end
GetZoneText = function() return "Elwynn Forest" end
GetSubZoneText = function() return "Goldshire" end
geterrorhandler = function() return function(e) failures[#failures + 1] = "error handler: " .. tostring(e) end end
C_Timer = { NewTicker = function() end, After = function(_, fn) timers[#timers + 1] = fn end }
C_Map = { GetBestMapForUnit = function() return 37 end, GetPlayerMapPosition = function() return nil end }
local recap = {}
C_DeathRecap = { HasRecapEvents = function() return #recap > 0 end, GetRecapEvents = function() return recap end }
DeathNotesDB = nil
assert(loadfile(base .. "/DeathNotes/DeathNotes.lua"))("DeathNotes", {})
local f = frames[#frames]
local function fire(ev) clock = clock + 1; gametime = gametime + 1; f.fn(f, ev) end
local function runTimers()
    local list = timers
    timers = {}
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn)
        if not ok then failures[#failures + 1] = "timer error: " .. tostring(err) end
    end
end
fire("PLAYER_LOGIN")

-- First death: secret timestamps, the recap is applied.
recap = {
    { timestamp = SECRET, sourceName = "Defias Pillager", spellName = "Fireball", amount = 30 },
    { timestamp = SECRET, sourceName = "Defias Pillager", spellName = "Fireball", amount = 25 },
}
foe = "Defias Thug"
fire("PLAYER_DEAD")
runTimers()
local deaths = DeathNotesDB.R.deaths
check(deaths[1].killer == "Defias Pillager" and deaths[1].recap == true, "first death gets its recap")

-- Second death: the game still gives the same (old) recap: the new death keeps its own guess.
foe = "Murloc Raider"
fire("PLAYER_DEAD")
runTimers()
check(deaths[2].killer == "Murloc Raider" and deaths[2].recap == nil,
    "an old untimed recap is not applied to a new death; got " .. tostring(deaths[2].killer))

-- A new recap (different hits) for a third death is applied.
recap = { { timestamp = SECRET, sourceName = "Hogger", spellName = "Bash", amount = 50 } }
foe = nil
fire("PLAYER_DEAD")
runTimers()
check(deaths[3].killer == "Hogger" and deaths[3].recap == true, "a new untimed recap is applied")

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_cr6b_deathrecap: all checks passed")
