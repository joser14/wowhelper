-- Round 4 item 22: Dungeons says how many of a dungeon's loot rows would be upgrades for you, asking
-- ItemAdvisor's public ItemAdvisor_IsUpgrade(link), checked a few items per frame; items still
-- loading are requested and counted once they arrive; gear changes recheck.
-- Run:  node run.js "<workspace root>" test_r4b_dungeon_upgrades.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local function check(cond, why) if not cond then failures[#failures + 1] = why .. "\n  output was:\n  " .. table.concat(out, "\n  ") end end
SlashCmdList = {}
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function() return false end
GetTime = function() return 100 end
UnitName = function() return "Ana" end
GetRealmName = function() return "Realm" end
UnitLevel = function() return 20 end
UnitClass = function() return "Rogue", "ROGUE" end
UnitFactionGroup = function() return "Alliance" end
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end, GetLogIndexForQuestID = function() return nil end, IsComplete = function() return false end }

local loaded = { [5191] = true, [5193] = true, [5192] = true, [2041] = true }
local requested, evaluated = {}, 0
C_Item = {
    GetItemCount = function() return 0 end,
    DoesItemExistByID = function(id) return id ~= 5443 end,
    GetItemInfo = function(id) if loaded[id] then return "Item " .. id, "|cff1eff00|Hitem:" .. id .. "::::::::20:::::|h[Item " .. id .. "]|h|r" end end,
    RequestLoadItemDataByID = function(id) requested[id] = true end,
}
local upgrades = { [5191] = true, [2041] = true, [5193] = false, [5192] = true }
ItemAdvisor_IsUpgrade = function(link)
    evaluated = evaluated + 1
    local id = tonumber(link:match("item:(%d+)"))
    return upgrades[id] == true, "reason"
end
local timers, perFrame, maxPerFrame = {}, 0, 0
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function() end }
local function flush()
    local n = 0
    while #timers > 0 and n < 1000 do
        n = n + 1
        local fn = table.remove(timers, 1)
        local before = evaluated
        fn()
        if evaluated - before > maxPerFrame then maxPerFrame = evaluated - before end
    end
end

assert(loadfile(base .. "/Dungeons/Data.lua"))("Dungeons", {})
assert(loadfile(base .. "/Dungeons/Dungeons.lua"))("Dungeons", {})
local f = frames[1]
local function fire(ev, ...) f.fn(f, ev, ...) end
local function line(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return t end end return "" end
local function page(arg) out = {}; local ok, err = pcall(SlashCmdList.DUNGEONS, arg); if not ok then out[#out + 1] = "<<ERROR " .. tostring(err) .. ">>" end end
fire("PLAYER_LOGIN")

-- First look starts the check; it runs over several frames.
page("")
check(line("The Deadmines") ~= "", "Deadmines suits level 20")
flush()
check(maxPerFrame <= 5, "at most 5 items per frame, saw " .. maxPerFrame)
check(requested[7230] and requested[2042], "unloaded items requested")
check(not requested[5443], "items that don't exist are skipped")
page("")
check(line("The Deadmines"):find("3 upgrades (one-hand, chest, one-hand)", 1, true) or line("The Deadmines"):find("3 upgrades", 1, true),
    "count on the list line: " .. line("The Deadmines"))
-- Details mark each upgrade.
page("dm")
check(line("Cruel Barb"):find("upgrade for you", 1, true), "Cruel Barb marked: " .. line("Cruel Barb"))
check(not line("Cape of the Brotherhood"):find("upgrade for you", 1, true), "not an upgrade: no mark")

-- An item arrives: rechecked and counted.
loaded[7230] = true
upgrades[7230] = true
fire("ITEM_DATA_LOAD_RESULT", 7230, true)
flush()
page("")
check(line("The Deadmines"):find("4 upgrades", 1, true), "loaded item counted: " .. line("The Deadmines"))

-- New gear: everything is rechecked.
upgrades[5191], upgrades[5192], upgrades[2041], upgrades[7230] = false, false, false, false
fire("PLAYER_EQUIPMENT_CHANGED", 16)
page("")
flush()
page("")
check(not line("The Deadmines"):find("upgrade", 1, true), "after new gear no upgrades: " .. line("The Deadmines"))

-- Without ItemAdvisor: nothing about upgrades, no error.
ItemAdvisor_IsUpgrade = nil
fire("PLAYER_EQUIPMENT_CHANGED", 16)
page(""); flush(); page("")
check(not line("The Deadmines"):find("upgrade", 1, true) and line("<<ERROR") == "", "no ItemAdvisor: no upgrade text")

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_r4b_dungeon_upgrades: all checks passed")
