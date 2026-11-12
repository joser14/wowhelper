-- Review 6b (Dungeons round 5): loot from corpses looted one after another within a second is all kept
-- in the run (the pending bag check of one loot window is not lost to the next), and the "one more new
-- dungeon reaches the cap" warning only shows when one more really does.
-- Run from the tests folder:  node run.js "<repo root>" test_cr6b_dungeons.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local function check(cond, why) if not cond then failures[#failures + 1] = why .. "\n  output was:\n  " .. table.concat(out, "\n  ") end end

local function NewFrame(kind, name)
    local f = { kind = kind, name = name, registered = {}, scripts = {}, shown = true, text = "" }
    function f:RegisterEvent(e) self.registered[e] = true end
    function f:SetScript(what, fn) self.scripts[what] = fn; if what == "OnEvent" then self.fn = fn end end
    function f:IsShown() return self.shown end
    return setmetatable(f, { __index = function() return function() end end })
end
CreateFrame = function(kind, name)
    local f = NewFrame(kind, name)
    frames[#frames + 1] = f
    return f
end
UIParent = NewFrame("Frame", "UIParent")
SlashCmdList = {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function() return false end

local now, mono = 1000000, 500
time = function() return now end
GetTime = function() return mono end
date = function(_, t) return "day " .. tostring(t) end
UnitName = function() return "Ana", "Moon" end
UnitGUID = function(unit) return unit == "player" and "Player-1-0001" or nil end
GetRealmName = function() return "Realm" end
UnitLevel = function() return 18 end
UnitXP = function() return 1000 end
UnitXPMax = function() return 9000 end
GetMoney = function() return 5000 end
UnitClass = function() return "Priest", "PRIEST" end
UnitFactionGroup = function() return "Alliance" end
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end, GetLogIndexForQuestID = function() return nil end, IsComplete = function() return false end }
local bags = {}
C_Item = {
    GetItemCount = function(id) return bags[id] or 0 end,
    GetItemInfo = function(id)
        local n = tonumber(id) or tonumber(tostring(id):match("item:(%d+)"))
        return "Item " .. tostring(n), "|Hitem:" .. tostring(n) .. "|h[Item " .. tostring(n) .. "]|h", 3
    end,
}
local inside, instanceName, instanceID = false, nil, nil
IsInInstance = function() return inside, inside and "party" or "none" end
GetInstanceInfo = function() return instanceName or "Elwynn Forest", inside and "party" or "none", 1, "Normal", 5, 0, false, instanceID or 0 end
local lootLinks = {}
GetNumLootItems = function() return #lootLinks end
GetLootSlotLink = function(slot) return lootLinks[slot] end

local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function() end }
local function flush()
    local n = 0
    while #timers > 0 and n < 1000 do
        n = n + 1
        table.remove(timers, 1)()
    end
end

assert(loadfile(base .. "/Dungeons/Data.lua"))("Dungeons", {})
assert(loadfile(base .. "/Dungeons/Dungeons.lua"))("Dungeons", {})
local f = frames[1]
local function fire(ev, ...) f.fn(f, ev, ...) end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return t end end return nil end
local function page(arg) out = {}; local ok, err = pcall(SlashCmdList.DUNGEONS, arg); if not ok then out[#out + 1] = "<<ERROR " .. tostring(err) .. ">>" end; flush() end
local function enter(name, id) inside, instanceName, instanceID = true, name, id; fire("PLAYER_ENTERING_WORLD"); flush() end
local function leave() inside, instanceName, instanceID = false, nil, nil; fire("PLAYER_ENTERING_WORLD"); flush() end

fire("PLAYER_LOGIN")
flush()

-- 1. Two corpses looted within a second (the first window's 1 s bag check still waiting): both items kept.
enter("The Deadmines", 36)
local run = DungeonsDB.runs[1]
lootLinks = { "|Hitem:7001::::|h[Blue One]|h" }
fire("LOOT_OPENED", false, false)
bags[7001] = 1
fire("LOOT_CLOSED")
-- The 1 s timer has not run yet: the next corpse.
lootLinks = { "|Hitem:7002::::|h[Blue Two]|h" }
fire("LOOT_OPENED", false, false)
bags[7002] = 1
fire("LOOT_CLOSED")
flush()
local got = {}
for _, id in ipairs(run.loot or {}) do got[id] = true end
check(got[7001], "first corpse's item kept when the next corpse is looted within a second")
check(got[7002], "second corpse's item kept")
leave()

-- 2. "One more reaches the cap" only when one more does: 1 of 3 today is not near.
page("cap 5 3")
now = now + 90000   -- the Deadmines run no longer counts for today
out = {}
enter("Shadowfang Keep", 33)
check(not has("one more new dungeon reaches the cap"), "1 of 3 today: no 'one more' warning: " .. tostring(has("Dungeon entries")))
leave()
now = now + 4000
out = {}
enter("Wailing Caverns", 43)
check(has("one more new dungeon reaches the cap"), "2 of 3 today: warned")
leave()
check(not has("<<ERROR"), "no errors")

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_cr6b_dungeons: all checks passed")
