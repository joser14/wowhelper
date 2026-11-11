-- Cross-addon review: Dungeons keeps ItemAdvisor's upgrade answers per item. They went stale when your
-- talents changed ItemAdvisor's role, and when the page was read in the second after a level-up while
-- UnitLevel still gave the old level. Both now forget the answers (the level-up again after 2 s).
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
UnitClass = function() return "Priest", "PRIEST" end
UnitFactionGroup = function() return "Alliance" end
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end, GetLogIndexForQuestID = function() return nil end, IsComplete = function() return false end }

C_Item = {
    GetItemCount = function() return 0 end,
    DoesItemExistByID = function() return true end,
    GetItemInfo = function(id) return "Item " .. id, "|cff1eff00|Hitem:" .. id .. "::::::::20:::::|h[Item " .. id .. "]|h|r" end,
    RequestLoadItemDataByID = function() end,
}
local role = "healer"
ItemAdvisor_IsUpgrade = function()
    return role == "healer", "reason"
end
local timers, later = {}, {}
C_Timer = { After = function(seconds, fn) if seconds and seconds > 0 then later[#later + 1] = fn else timers[#timers + 1] = fn end end, NewTicker = function() end }
local function flush()
    local n = 0
    while #timers > 0 and n < 1000 do
        n = n + 1
        table.remove(timers, 1)()
    end
end
local function settle()
    local due = later
    later = {}
    for _, fn in ipairs(due) do fn() end
end

assert(loadfile(base .. "/Dungeons/Data.lua"))("Dungeons", {})
assert(loadfile(base .. "/Dungeons/Dungeons.lua"))("Dungeons", {})
local f = frames[1]
local function fire(ev, ...) f.fn(f, ev, ...) end
local function line(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return t end end return "" end
local function page(arg) out = {}; local ok, err = pcall(SlashCmdList.DUNGEONS, arg); if not ok then out[#out + 1] = "<<ERROR " .. tostring(err) .. ">>" end end
local function look() page(""); flush(); page("") end
fire("PLAYER_LOGIN")

-- Registered only events that exist as plain events (never a CallbackEvent).
for _, name in ipairs({ "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED" }) do
    check(f.registered[name], "listens for " .. name)
end
check(not f.registered.COMBAT_LOG_EVENT_UNFILTERED, "no combat log")

look()
check(line("The Deadmines"):find("upgrade", 1, true), "healer role: upgrades counted: " .. line("The Deadmines"))

-- Talents move ItemAdvisor to another role: the answers are asked again.
role = "damage"
fire("TRAIT_CONFIG_UPDATED", 1)
look()
check(not line("The Deadmines"):find("upgrade", 1, true), "after a talent change the old answers are gone: " .. line("The Deadmines"))

-- A level-up: the page is read while ItemAdvisor still answers for the old level...
role = "damage"
fire("PLAYER_LEVEL_UP", 21)
look()
check(not line("The Deadmines"):find("upgrade", 1, true), "stale answer right after the level-up")
-- ...and once the new level shows, the answers are asked again.
role = "healer"
settle()
look()
check(line("The Deadmines"):find("upgrade", 1, true), "answers asked again after the level settles: " .. line("The Deadmines"))
check(line("<<ERROR") == "", "no errors")

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_xreview_ui_dungeons: all checks passed")
