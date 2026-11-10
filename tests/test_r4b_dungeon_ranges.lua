-- Round 4 item 4: Dungeons takes level ranges from the game's Group Finder
-- (C_LFGList.GetActivityInfoTable, by activity ID or found by name), shows "(game: a-b)" where it
-- differs from our list and uses it to decide what suits you; an ID whose name doesn't match is
-- ignored. Plus the data audit: boss NPC IDs and the Drowned City boss list.
-- Run:  node run.js "<workspace root>" test_r4b_dungeon_ranges.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local SECRET = {}
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
issecretvalue = function(v) return v == SECRET end
local level = 24
GetTime = function() return 100 end
UnitName = function() return "Ana" end
GetRealmName = function() return "Realm" end
UnitLevel = function() return level end
UnitClass = function() return "Mage", "MAGE" end
UnitFactionGroup = function() return "Alliance" end
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end, GetLogIndexForQuestID = function() return nil end, IsComplete = function() return false end }
C_Item = { GetItemCount = function() return 0 end }

local ACT = {
    [799] = { fullName = "Deadmines", minLevel = 10, minLevelSuggestion = 18, maxLevelSuggestion = 23 },
    [1984] = { fullName = "Something Else Entirely", minLevel = 10, minLevelSuggestion = 40, maxLevelSuggestion = 45 },
    [5000] = { fullName = "Uldaman", minLevel = 30, minLevelSuggestion = 38, maxLevelSuggestion = 48 },
    [800] = { fullName = "Shadowfang Keep", minLevel = SECRET, minLevelSuggestion = SECRET, maxLevelSuggestion = SECRET },
}
local calls = 0
C_LFGList = {
    GetActivityInfoTable = function(id) calls = calls + 1; if id == 801 then error("boom") end return ACT[id] end,
    GetAvailableActivities = function() return { 5000, 1984 } end,
}

assert(loadfile(base .. "/Dungeons/Data.lua"))("Dungeons", {})
assert(loadfile(base .. "/Dungeons/Dungeons.lua"))("Dungeons", {})
local f = frames[1]
local function fire(ev, ...) f.fn(f, ev, ...) end
local function line(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return t end end return "" end
local function has(text) return line(text) ~= "" end
local function page(arg) out = {}; local ok, err = pcall(SlashCmdList.DUNGEONS, arg); if not ok then out[#out + 1] = "<<ERROR " .. tostring(err) .. ">>" end end
fire("PLAYER_LOGIN")

page("all")
check(not has("<<ERROR"), "no error")
check(line("The Deadmines"):find("(game: 18-23)", 1, true), "Deadmines game range shown: " .. line("The Deadmines"))
check(line("Uldaman"):find("(game: 38-48)", 1, true), "Uldaman found by name: " .. line("Uldaman"))
check(not line("Hall of Thanes"):find("game:", 1, true), "an ID whose name doesn't match is ignored: " .. line("Hall of Thanes"))
check(not line("Shadowfang Keep"):find("game:", 1, true), "secret range ignored")
check(not line("Blackfathom Deeps"):find("game:", 1, true), "erroring call ignored")

-- At 24 our list (17-26) would offer the Deadmines; the game says 18-23.
page("")
check(not has("The Deadmines"), "game range decides what suits you")
level = 20
page("")
check(has("The Deadmines"), "in the game's range at 20")

-- Details show the Group Finder numbers.
page("dm")
check(has("Group Finder: from level 10, suggested 18-23"), "detail line")

-- A range the same as ours isn't repeated.
ACT[799].minLevelSuggestion, ACT[799].maxLevelSuggestion = 17, 26
fire("PLAYER_LOGIN")
page("all")
check(not line("The Deadmines"):find("game:", 1, true), "same range not repeated after a fresh read")
local before = calls
page("all"); page("all")
check(calls == before, "ranges cached within a session (" .. (calls - before) .. " extra calls)")

-- Data audit: NPC IDs for bosses, Drowned City list.
local function dungeon(short) for _, d in ipairs(DungeonsData) do if d.short == short then return d end end end
local dm = dungeon("dm")
check(dm.npcs and dm.npcs["Edwin VanCleef"] == 639, "VanCleef's NPC ID")
local withIDs, total = 0, 0
for _, d in ipairs(DungeonsData) do
    for _, boss in ipairs(d.bosses or {}) do
        total = total + 1
        if d.npcs and type(d.npcs[boss]) == "number" then withIDs = withIDs + 1 end
    end
    for name in pairs(d.npcs or {}) do
        local listed = false
        for _, boss in ipairs(d.bosses or {}) do if boss == name then listed = true end end
        check(listed, d.name .. ": NPC ID for a boss not on the list: " .. name)
    end
end
check(withIDs >= total - 4, string.format("most bosses have an NPC ID (%d of %d)", withIDs, total))
local drowned = dungeon("drowned")
local names = table.concat(drowned.bosses, ",")
check(not names:find("Zin'aka", 1, true), "Zin'aka (an old name for Var'Taka) dropped")
check(names:find("Min'loth the Serpent", 1, true) and drowned.npcs["Min'loth the Serpent"] == 260274, "Min'loth added with its ID")
check(dungeon("dm").activity == 799 and dungeon("thanes").activity == 1984, "activity IDs in the data")

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_r4b_dungeon_ranges: all checks passed")
