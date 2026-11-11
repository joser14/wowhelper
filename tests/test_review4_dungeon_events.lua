-- Review 4, B1: Dungeons' upgrade check needs ITEM_DATA_LOAD_RESULT (items still loading), and
-- PLAYER_EQUIPMENT_CHANGED / PLAYER_LEVEL_UP (answers go stale with new gear or a level). The three
-- RegisterEvent lines had been merged into a comment, so the game never sent these events: an item
-- that wasn't cached stayed unjudged for the session, and "upgrade for you" stayed after equipping it.
-- Here only registered events are delivered, as in the game.
-- Run:  node run.js "<workspace root>" test_review4_dungeon_events.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
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
C_Item = {
    GetItemCount = function() return 0 end,
    DoesItemExistByID = function() return true end,
    GetItemInfo = function(id) if loaded[id] then return "Item " .. id, "|cff1eff00|Hitem:" .. id .. "::::::::20:::::|h[Item " .. id .. "]|h|r" end end,
    RequestLoadItemDataByID = function() end,
}
local upgrades = { [5191] = true }
ItemAdvisor_IsUpgrade = function(link)
    return upgrades[tonumber(link:match("item:(%d+)"))] == true, "reason"
end
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
-- The game only sends events a frame registered.
local function fire(ev, ...)
    if f.registered[ev] then
        f.fn(f, ev, ...)
    end
end
local function line(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return t end end return "" end
local function page(arg) out = {}; local ok, err = pcall(SlashCmdList.DUNGEONS, arg); if not ok then out[#out + 1] = "<<ERROR " .. tostring(err) .. ">>" end end

for _, name in ipairs({ "ITEM_DATA_LOAD_RESULT", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP" }) do
    check(f.registered[name], name .. " is registered")
end

fire("PLAYER_LOGIN")
page("")
flush()
page("")
check(line("The Deadmines"):find("1 upgrade", 1, true), "one upgrade first: " .. line("The Deadmines"))

-- An item the client hadn't loaded arrives: it is judged and counted.
loaded[7230], upgrades[7230] = true, true
fire("ITEM_DATA_LOAD_RESULT", 7230, true)
flush()
page("")
check(line("The Deadmines"):find("2 upgrades", 1, true), "loaded item counted: " .. line("The Deadmines"))

-- You equip them: no longer upgrades.
upgrades[5191], upgrades[7230] = false, false
fire("PLAYER_EQUIPMENT_CHANGED", 16)
page(""); flush(); page("")
check(not line("The Deadmines"):find("upgrade", 1, true), "after new gear no upgrades: " .. line("The Deadmines"))

-- A level later, something is an upgrade again.
upgrades[5193] = true
fire("PLAYER_LEVEL_UP", 21)
page(""); flush(); page("")
check(line("The Deadmines"):find("1 upgrade", 1, true), "rechecked after a level: " .. line("The Deadmines"))

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_review4_dungeon_events: all checks passed")
