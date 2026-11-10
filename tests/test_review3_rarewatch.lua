-- Review 3 (2026-11-10), RareWatch: its own raid-warning sound respects the hub.
--  * RareWatch switched Off on the Manage page ("keeps running quietly"): no sound.
--  * The hub's Alerts > Sound switched off (its text names "a rare nearby"): no sound.
-- The rare is still remembered in both cases.
-- Run from the harness folder:  node run.js "<workspace root>" test_review3_rarewatch.lua
local base = ADDON_PATH
local frames = {}
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
issecretvalue = function() return false end
GetRealmName = function() return "R" end
local clock = 100000
time = function() return clock end
GetTime = function() return clock end
GetZoneText = function() return "Elwynn Forest" end
GetSubZoneText = function() return "" end
local sounds = 0
SOUNDKIT = { RAID_WARNING = 1 }
PlaySound = function() sounds = sounds + 1 end
local off = false
ForeverHub_IsOff = function(name) return off and name == "RareWatch" end
ForeverHub_Receive = function() end
ForeverHubDB = {}
C_Map = {}

local units = {}
UnitExists = function(u) return units[u] ~= nil end
UnitGUID = function(u) return units[u] and units[u].guid end
UnitClassification = function(u) return units[u] and units[u].class or "normal" end
UnitName = function(u) return units[u] and units[u].name end
UnitLevel = function(u) return units[u] and units[u].level end
UnitIsDead = function() return false end
UnitIsPlayer = function() return false end

assert(loadfile(base .. "/RareWatch/RareWatch.lua"))("RareWatch", {})
local f = frames[1]
local function fire(ev, ...) f.fn(f, ev, ...) end
fire("PLAYER_LOGIN")

local npc = 100
local function seeRare()
    npc = npc + 1
    clock = clock + 1000   -- past the repeat wait
    units.target = { guid = string.format("Creature-0-1-0-12-%d-0000000001", npc), class = "rare", name = "Rare " .. npc, level = 10 }
    fire("PLAYER_TARGET_CHANGED")
end

seeRare()
assert(sounds == 1, "control: a rare plays the sound")

off = true
seeRare()
assert(sounds == 1, "RareWatch switched off: no sound")
off = false

ForeverHubDB.alerts = { sound = false }
seeRare()
assert(sounds == 1, "hub sound alerts off: no sound")
ForeverHubDB.alerts = { sound = true }
seeRare()
assert(sounds == 2, "hub sound alerts on: sound")

local remembered = 0
for _ in pairs(RareWatchDB.R.rares) do remembered = remembered + 1 end
assert(remembered == 4, "every rare still remembered: " .. remembered)

print("ALL TESTS PASSED")
