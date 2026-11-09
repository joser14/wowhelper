-- Dungeons: boss kills remembered per character from ENCOUNTER_END (success) and BOSS_KILL, shown on
-- the dungeon's page; finished quests ticked. Run:  node run.js "<workspace root>" test_dungeons_kills.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local SECRET = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why .. "\n  output was:\n  " .. table.concat(out, "\n  ") end end
SlashCmdList = {}
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e)
        if e == "BOSS_KILL" and REFUSE_BOSS_KILL then error("unknown event") end
        self.registered[e] = true
    end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function(v) return v == SECRET end
local now, player = 100, "Ana"
GetTime = function() return now end
UnitName = function() return player end
GetRealmName = function() return "Realm" end
UnitLevel = function() return 20 end
UnitClass = function() return "Mage", "MAGE" end
local completed = {}
C_QuestLog = {
    IsQuestFlaggedCompleted = function(id) return completed[id] == true end,
    GetLogIndexForQuestID = function() return nil end,
    IsComplete = function() return false end,
}
C_Item = { GetItemCount = function() return 0 end }

assert(loadfile(base .. "/Dungeons/Data.lua"))("Dungeons", {})
assert(loadfile(base .. "/Dungeons/Dungeons.lua"))("Dungeons", {})
local f = frames[1]
local function fire(ev, ...) f.fn(f, ev, ...) end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function need(text, why) check(has(text), why .. ": wanted '" .. text .. "'") end
local function page(arg)
    out = {}
    local ok, err = pcall(SlashCmdList.DUNGEONS, arg)
    if not ok then out[#out + 1] = "<<ERROR: " .. tostring(err) .. ">>" end
end
local TICK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t"

check(f.registered.ENCOUNTER_END and f.registered.BOSS_KILL, "kill events registered")
fire("PLAYER_LOGIN")

-- Nothing killed yet.
page("dm")
need("(none killed on this character yet)", "no kills yet")

-- A wipe doesn't count; a kill does, once even though both events report it.
fire("ENCOUNTER_END", 1, "Rhahk'Zor", 1, 5, 0)
page("dm")
need("(none killed on this character yet)", "a wipe isn't a kill")
fire("ENCOUNTER_END", 1, "Rhahk'Zor", 1, 5, 1)
fire("BOSS_KILL", 1, "Rhahk'Zor")
page("dm")
need("1/", "one boss killed")
need(TICK .. " |cff33ff33Rhahk'Zor|r|cff999999 killed|r", "killed boss ticked")
check(not has("Rhahk'Zor|r|cff999999 killed (2 times)"), "both events count one kill")
-- BOSS_KILL alone counts too, and a second run later is counted again; case and "The" don't matter.
now = now + 3600
fire("BOSS_KILL", 1, "rhahk'zor")
fire("BOSS_KILL", 2, "Edwin VanCleef")
page("dm")
need("killed (2 times)", "second run counted")
need(TICK .. " |cff33ff33Edwin VanCleef", "boss from BOSS_KILL")
check(DungeonsDB.kills["Ana-Realm"], "saved per character")

-- A name reported a little differently still matches ("Taragaman" vs "Taragaman the Hungerer").
fire("BOSS_KILL", 3, "Taragaman")
page("rfc")
need(TICK .. " |cff33ff33Taragaman the Hungerer", "partial name matches")

-- Another character has its own kills.
player = "Bob"
fire("PLAYER_LOGIN")
page("dm")
need("(none killed on this character yet)", "kills are per character")
player = "Ana"
fire("PLAYER_LOGIN")
page("dm")
need("Edwin VanCleef", "back to the first character")

-- Secret or missing payloads are ignored, never an error.
local before = DungeonsDB.kills["Ana-Realm"]["edwinvancleef"].count
local ok = pcall(function()
    fire("ENCOUNTER_END", SECRET, SECRET, SECRET, SECRET, SECRET)
    fire("ENCOUNTER_END", 9, "Edwin VanCleef", 1, 5, SECRET)
    fire("BOSS_KILL", SECRET, SECRET)
    fire("BOSS_KILL")
    fire("ENCOUNTER_END")
end)
check(ok, "secret payloads don't error")
check(DungeonsDB.kills["Ana-Realm"]["edwinvancleef"].count == before, "secret payloads record nothing")
-- No character name yet: nothing saved, no error.
UnitName = function() return SECRET end
player = nil
fire("PLAYER_LOGIN")
ok = pcall(fire, "BOSS_KILL", 5, "Mr. Smite")
check(ok, "kill before the name is known")
page("dm")
check(not has("<<ERROR"), "page without a character name")
UnitName = function() return "Ana" end
fire("PLAYER_LOGIN")

-- Finished quests carry a tick; a dungeon with every quest done gets one on its summary line.
completed[214] = true
page("dm")
need(TICK .. " |cff33ff33Done|r: Red Silk Bandanas", "done quest ticked")
for _, d in ipairs(DungeonsData) do
    if d.short == "dm" then
        for _, q in ipairs(d.quests) do completed[q.questIDs[#q.questIDs]] = true end
    end
end
page("all")
need(TICK .. " 7/7 done", "all quests done ticked on the summary")

-- Loading on a client that refuses BOSS_KILL still works.
REFUSE_BOSS_KILL = true
frames, SlashCmdList = {}, {}
ok = pcall(function() assert(loadfile(base .. "/Dungeons/Dungeons.lua"))("Dungeons", {}) end)
check(ok, "loads when an event is refused")
REFUSE_BOSS_KILL = nil

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_dungeons_kills: all checks passed")
