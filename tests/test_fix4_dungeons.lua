-- Review 4, suspicions 3 and 5 (Dungeons):
-- 3. Group Finder ranges read before the game had them are read again later in the session (every 30 s,
--    a bounded number of times), not left on Data.lua's ranges until the next login.
-- 5. While ItemAdvisor isn't ready (no character data yet, item stats still loading), "not an upgrade" isn't
--    stored as a final answer: the next look asks again.
-- Run:  node run.js "<workspace root>" test_fix4_dungeons.lua
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
local now = 100
GetTime = function() return now end
UnitName = function() return "Ana" end
GetRealmName = function() return "Realm" end
UnitLevel = function() return 20 end
UnitClass = function() return "Rogue", "ROGUE" end
UnitFactionGroup = function() return "Alliance" end
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end, GetLogIndexForQuestID = function() return nil end, IsComplete = function() return false end }

-- Group Finder: nothing loaded yet at login.
local ACT = {}
local calls = 0
C_LFGList = {
    GetActivityInfoTable = function(id) calls = calls + 1; return ACT[id] end,
    GetAvailableActivities = function() return {} end,
}
-- Items: all loaded; ItemAdvisor not ready at first.
C_Item = {
    GetItemCount = function() return 0 end,
    DoesItemExistByID = function() return true end,
    GetItemInfo = function(id) return "Item " .. id, "|cff1eff00|Hitem:" .. id .. "::::::::20:::::|h[Item " .. id .. "]|h|r" end,
    RequestLoadItemDataByID = function() end,
}
local ready, loading = false, false
ItemAdvisor_IsUpgrade = function(link)
    if not ready then
        return false   -- ItemAdvisor has no character data yet: false with no reason
    end
    if loading then
        return false, "Can't read the stats (still loading); compare it yourself"
    end
    local id = tonumber(link:match("item:(%d+)"))
    return id == 5191 or id == 2041, "Upgrade"
end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function() end }
local function flush() local n = 0 while #timers > 0 and n < 1000 do n = n + 1; table.remove(timers, 1)() end end

assert(loadfile(base .. "/Dungeons/Data.lua"))("Dungeons", {})
assert(loadfile(base .. "/Dungeons/Dungeons.lua"))("Dungeons", {})
local f = frames[1]
local function fire(ev, ...) f.fn(f, ev, ...) end
local function line(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return t end end return "" end
local function has(text) return line(text) ~= "" end
local function page(arg) out = {}; local ok, err = pcall(SlashCmdList.DUNGEONS, arg); if not ok then out[#out + 1] = "<<ERROR " .. tostring(err) .. ">>" end end
fire("PLAYER_LOGIN")

---------------------------------------------------------------------------- 3. ranges
page("dm")
check(not has("<<ERROR"), "no error")
check(not has("Group Finder: from level"), "nothing from the Group Finder yet")
-- The Group Finder data arrives a little later.
ACT[799] = { fullName = "Deadmines", minLevel = 10, minLevelSuggestion = 18, maxLevelSuggestion = 23 }
now = now + 5
local before = calls
page("dm")
check(calls == before, "not read again right away (" .. (calls - before) .. " calls)")
check(not has("Group Finder: from level"), "still the old read")
now = now + 30
page("dm")
check(has("Group Finder: from level 10, suggested 18-23"), "read again later in the session")
-- Dungeons the Group Finder never lists don't make it read forever.
for _ = 1, 30 do now = now + 31; page("dm") end
before = calls
for _ = 1, 5 do now = now + 31; page("dm") end
check(calls == before, "retries are bounded (" .. (calls - before) .. " calls after the limit)")
check(has("Group Finder: from level 10, suggested 18-23"), "a range once read is kept")
-- A new login starts over.
fire("PLAYER_LOGIN")
page("dm")
check(has("Group Finder: from level 10, suggested 18-23"), "read at the next login")

---------------------------------------------------------------------------- 5. upgrades
page("dm"); flush(); page("dm")
check(not line("Cruel Barb"):find("upgrade for you", 1, true), "ItemAdvisor not ready: no mark")
ready, loading = true, true
page("dm"); flush(); page("dm")
check(not line("Cruel Barb"):find("upgrade for you", 1, true), "stats still loading: no mark yet")
loading = false
page("dm"); flush(); page("dm")
check(line("Cruel Barb"):find("upgrade for you", 1, true), "asked again once ItemAdvisor is ready: " .. line("Cruel Barb"))
check(not line("Cape of the Brotherhood"):find("upgrade for you", 1, true), "a real 'no' is still no")

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_fix4_dungeons: all checks passed")
