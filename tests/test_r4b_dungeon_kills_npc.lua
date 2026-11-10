-- Round 4 item 10: Dungeons counts boss kills by NPC ID from UNIT_DIED and PARTY_KILL (plain events,
-- not CallbackEvents; GUIDs read through Safe()), learns a boss's NPC ID from your target inside its
-- dungeon, and learns "approx" entrances from where you were just before entering.
-- Run:  node run.js "<workspace root>" test_r4b_dungeon_kills_npc.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local SECRET = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why .. "\n  output was:\n  " .. table.concat(out, "\n  ") end end
SlashCmdList = {}
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e)
        if e:find("^COMBAT_LOG") then failures[#failures + 1] = "registered " .. e end
        self.registered[e] = true
    end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function(v) return v == SECRET end
local now = 100
GetTime = function() return now end
time = function() return 1000 end
UnitName = function(unit) if unit == "target" then return TARGET_NAME end return "Ana" end
GetRealmName = function() return "Realm" end
UnitLevel = function() return 30 end
UnitClass = function() return "Mage", "MAGE" end
UnitFactionGroup = function() return "Alliance" end
UnitGUID = function(unit) if unit == "target" then return TARGET_GUID end return "Player-1-ABC" end
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end, GetLogIndexForQuestID = function() return nil end, IsComplete = function() return false end }
C_Item = { GetItemCount = function() return 0 end }
local inInstance, instanceName = true, "The Deadmines"
IsInInstance = function() return inInstance, inInstance and "party" or "none" end
GetInstanceInfo = function() return instanceName, "party" end
local tickers = {}
C_Timer = { After = function(_, fn) fn() end, NewTicker = function(_, fn) tickers[#tickers + 1] = fn; return { Cancel = function() end } end }
local mapNames = { [1420] = "Tirisfal Glades", [1436] = "Westfall" }
local playerMap, px, py = 1420, 0.634, 0.674
C_Map = {
    GetMapInfo = function(id) return mapNames[id] and { name = mapNames[id] } end,
    GetBestMapForUnit = function() return playerMap end,
    GetPlayerMapPosition = function() return { x = px, y = py } end,
}

assert(loadfile(base .. "/Dungeons/Data.lua"))("Dungeons", {})
assert(loadfile(base .. "/Dungeons/Dungeons.lua"))("Dungeons", {})
local f = frames[1]
local function fire(ev, ...) f.fn(f, ev, ...) end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function page(arg) out = {}; local ok, err = pcall(SlashCmdList.DUNGEONS, arg); if not ok then out[#out + 1] = "<<ERROR " .. tostring(err) .. ">>" end end
local TICK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t"
local function guid(npc) return "Creature-0-4170-36-1234-" .. npc .. "-00001A2B3C" end

check(f.registered.UNIT_DIED and f.registered.PARTY_KILL, "UNIT_DIED and PARTY_KILL registered")
fire("PLAYER_LOGIN")

-- A boss dies: counted once even though both events report it.
fire("UNIT_DIED", guid(639))
fire("PARTY_KILL", "Player-1-ABC", guid(639))
page("dm")
check(has(TICK .. " |cff33ff33Edwin VanCleef|r|cff999999 killed|r"), "kill by NPC ID")
check(not has("killed (2 times)"), "UNIT_DIED + PARTY_KILL = one kill")
-- ENCOUNTER_END for the same boss right after doesn't add another.
fire("BOSS_KILL", 1, "Edwin VanCleef")
page("dm")
check(not has("killed (2 times)"), "shared dedupe with BOSS_KILL")
-- PARTY_KILL alone counts too (a later run).
now = now + 3600
fire("PARTY_KILL", "Player-1-ABC", guid(644))
page("dm")
check(has(TICK .. " |cff33ff33Rhahk'Zor"), "PARTY_KILL target")

-- Ordinary mobs, players, secrets and garbage: nothing, no error.
local ok = pcall(function()
    fire("UNIT_DIED", guid(1))
    fire("UNIT_DIED", "Player-1-XYZ")
    fire("UNIT_DIED", SECRET)
    fire("PARTY_KILL", SECRET, SECRET)
    fire("UNIT_DIED")
    fire("UNIT_DIED", "nonsense")
end)
check(ok, "no error on odd payloads")

-- Learning: Cinder has no ID in our data. Target it inside Shaper's Terrace, then it dies.
instanceName = "Shaper's Terrace"
TARGET_NAME, TARGET_GUID = "Cinder", guid(262999)
fire("PLAYER_TARGET_CHANGED")
fire("UNIT_DIED", guid(262999))
page("shaper")
check(has(TICK .. " |cff33ff33Cinder"), "learned NPC ID counts the kill")
check(DungeonsDB.learnedNpcs and DungeonsDB.learnedNpcs[262999], "learned ID saved")
-- A same-named mob outside that dungeon teaches nothing.
instanceName = "The Deadmines"
TARGET_NAME, TARGET_GUID = "Snowtalon", guid(263000)
fire("PLAYER_TARGET_CHANGED")
check(not DungeonsDB.learnedNpcs[263000], "only bosses of the dungeon you're in")
-- Secret target values teach nothing and don't error.
TARGET_NAME, TARGET_GUID = SECRET, SECRET
ok = pcall(fire, "PLAYER_TARGET_CHANGED")
check(ok, "secret target")

-- Outdoors no kill is counted from these events (bosses live in dungeons).
inInstance = false
now = now + 3600
fire("UNIT_DIED", guid(646))
page("dm")
check(not has(TICK .. " |cff33ff33Mr. Smite"), "no kill outdoors")

-- Entrances: Ruins of Lordaeron's is "approx". Walk up outside, then enter.
for _, t in ipairs(tickers) do t() end
inInstance, instanceName = true, "Ruins of Lordaeron"
fire("PLAYER_ENTERING_WORLD")
page("ruins")
check(has("Tirisfal Glades 63.4, 67.4"), "learned entrance shown")
check(has("learned"), "says it was learned")
check(DungeonsDB.entrances and DungeonsDB.entrances.ruins, "saved")
-- A dungeon with a checked entrance keeps it.
inInstance = false
playerMap, px, py = 1436, 0.10, 0.10
for _, t in ipairs(tickers) do t() end
inInstance, instanceName = true, "The Deadmines"
fire("PLAYER_ENTERING_WORLD")
check(not (DungeonsDB.entrances.dm), "checked entrances aren't overwritten")
-- A stale sample (long ago) or another zone's sample isn't used.
inInstance = false
playerMap, px, py = 1436, 0.5, 0.5
for _, t in ipairs(tickers) do t() end
now = now + 600
inInstance, instanceName = true, "Scarlet Monastery Graveyard"
fire("PLAYER_ENTERING_WORLD")
check(not DungeonsDB.entrances["sm graveyard"], "stale or wrong-zone sample ignored")

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_r4b_dungeon_kills_npc: all checks passed")
