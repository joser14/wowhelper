-- LevelLog: XP split between quests and kills/exploring per level, counted from the XP bar and the
-- turn-in reward; a level-up splits the gain between the two levels; hidden XP is caught up later.
local base = ADDON_PATH
local out, frames, handled = {}, {}, {}
local SECRET = {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function(v) return v == SECRET end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
CreateFrame = function()
    local f = {}
    f.RegisterEvent = function() end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
UnitName = function() return "Me" end
GetRealmName = function() return "R" end
GetTime = function() return 1000 end
local xp, max, level = 0, 1000, 10
local hidden = false
UnitXP = function() if hidden then return SECRET end return xp end
UnitXPMax = function() return max end
UnitLevel = function() return level end

assert(loadfile(base .. "/LevelLog/LevelLog.lua"))("LevelLog", {})
local f = frames[1]
local function fire(...) f.fn(f, ...) end
fire("PLAYER_LOGIN")
local key = next(LevelLogDB)
local levels = LevelLogDB[key]

-- 1. Kills: 300 XP. A quest worth 200: the bar goes up 200 and the turn-in says 200.
xp = 300; fire("PLAYER_XP_UPDATE", "player")
fire("QUEST_TURNED_IN", 11, 200, 0)
xp = 500; fire("PLAYER_XP_UPDATE", "player")
assert(levels[10].xp == 500 and levels[10].questXP == 200, "level 10: 500 total, 200 quest")
print("1 ok")

-- 2. A level-up while XP was hidden, the game still saying level 10: 500 left of level 10 go to 10,
-- the 150 on the new bar go to 11.
hidden = true; xp = 900; fire("PLAYER_XP_UPDATE", "player")
hidden = false; xp, max = 150, 1200
fire("PLAYER_XP_UPDATE", "player")
assert(levels[10].xp == 1000, "level 10 total is its whole bar: " .. tostring(levels[10].xp))
assert(levels[11] and levels[11].xp == 150, "the rest counts for 11: " .. tostring(levels[11] and levels[11].xp))
level = 11; fire("PLAYER_LEVEL_UP", 11)
print("2 ok")

-- 3. The page shows the split per level and in total.
out = {}
SlashCmdList.LEVELLOG("all")
local page = table.concat(out, "\n")
assert(page:find("Level 10: .-XP 20%% quests, 80%% kills and exploring"), "level 10 split:\n" .. page)
assert(page:find("XP so far: 17% quests", 1, true), "total split:\n" .. page)
-- An old save without XP fields still shows, without a split.
levels[9] = { seconds = 60, deaths = 0 }
out = {}
SlashCmdList.LEVELLOG("all")
page = table.concat(out, "\n")
assert(page:find("Level 9: 1m, 0 death(s)\n", 1, true), "old entry, no split:\n" .. page)
assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
