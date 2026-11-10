-- Review 3b S1 and round 3 rank 18 (LevelLog).
-- S1: a quest that levels you used to count its whole reward to one level (whatever UnitLevel said at the
-- turn-in), while the bar XP was split. Now the reward is split the same way, in either event order.
-- Rank 18: XP per hour for each level, and each finished level's time against your fastest other character.
local base = ADDON_PATH
local out, frames, handled = {}, {}, {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function() return false end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
CreateFrame = function()
    local f = {}
    f.RegisterEvent = function() end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
local now = 1000
GetTime = function() return now end
local me = "Ann"
UnitName = function() return me end
GetRealmName = function() return "R" end
local xp, max, level = 900, 1000, 10
UnitXP = function() return xp end
UnitXPMax = function() return max end
UnitLevel = function() return level end

-- Another character who already levelled: level 10 took 40 min.
LevelLogDB = { ["Bob-R"] = { charName = "Bob", [10] = { seconds = 2400, deaths = 0 }, [11] = { seconds = 100, deaths = 0 } } }
assert(loadfile(base .. "/LevelLog/LevelLog.lua"))("LevelLog", {})
local f = frames[1]
local function fire(...) f.fn(f, ...) end
fire("PLAYER_LOGIN")
local levels = LevelLogDB["Ann-R"]
assert(levels, "own record")

-- 1. Turn-in first, UnitLevel still the old level: a 300 XP quest at 900/1000 -> 100 for 10, 200 for 11.
fire("QUEST_TURNED_IN", 7, 300, 0)
now = now + 0.1
xp, max = 200, 1200
fire("PLAYER_XP_UPDATE", "player")
assert(levels[10].questXP == 100, "old level gets what filled its bar: " .. tostring(levels[10].questXP))
assert(levels[11] and levels[11].questXP == 200, "new level gets the rest: " .. tostring(levels[11] and levels[11].questXP))
level = 11
fire("PLAYER_LEVEL_UP", 11)
print("1 ok")

-- 2. XP update first, then the turn-in (UnitLevel already new): same split.
now = now + 60
xp = 1100; fire("PLAYER_XP_UPDATE", "player")       -- 900 more from kills at 11
now = now + 30
xp, max = 50, 1400                                  -- a 150 XP quest: 100 for 11, 50 for 12
level = 12
fire("PLAYER_XP_UPDATE", "player")
now = now + 0.1
fire("QUEST_TURNED_IN", 8, 150, 0)
assert(levels[11].questXP == 300, "11: 200 + 100: " .. tostring(levels[11].questXP))
assert(levels[12] and levels[12].questXP == 50, "12: 50: " .. tostring(levels[12] and levels[12].questXP))
fire("PLAYER_LEVEL_UP", 12)
print("2 ok")

-- 3. A turn-in at the same level still counts whole; one whose XP never shows is kept at the current level.
now = now + 10
xp = 250; fire("PLAYER_XP_UPDATE", "player")        -- kills: 200
now = now + 5
fire("QUEST_TURNED_IN", 9, 100, 0)
now = now + 0.1
xp = 350; fire("PLAYER_XP_UPDATE", "player")
assert(levels[12].questXP == 150, "same-level quest: " .. tostring(levels[12].questXP))
now = now + 5
fire("QUEST_TURNED_IN", 10, 40, 0)
now = now + 10
xp = 400; fire("PLAYER_XP_UPDATE", "player")        -- too late to be that quest's
assert(levels[12].questXP == 190, "unmatched reward kept at the level: " .. tostring(levels[12].questXP))
print("3 ok")

-- 4. Pace: level 10 took 30 min of a 1000 XP bar -> 2.0k XP/h, 10 min faster than Bob's 40 min.
levels[10].seconds = 1800
LevelGuidePlanner = { LEVEL_XP = { [10] = 1000, [11] = 1200 } }
out = {}
SlashCmdList.LEVELLOG("all")
local page = table.concat(out, "\n")
assert(page:find("Level 10: 30m, 0 death(s); 2.0k XP/h", 1, true), "XP per hour:\n" .. page)
assert(page:find("10m faster than Bob", 1, true), "faster than your best other run:\n" .. page)
-- Slower: shown in red with their time.
levels[10].seconds = 3000
out = {}
SlashCmdList.LEVELLOG("all")
page = table.concat(out, "\n")
assert(page:find("10m slower than Bob (40m)", 1, true), "slower:\n" .. page)
-- Bob never finished level 11 here (no level 12 entry): no comparison for 11.
levels[11].seconds = 600
out = {}
SlashCmdList.LEVELLOG("all")
page = table.concat(out, "\n")
local line11 = page:match("Level 11:[^\n]*")
assert(line11 and line11:find("7.2k XP/h", 1, true) and not line11:find("than", 1, true), "level 11: " .. tostring(line11))
LevelGuidePlanner = nil
print("4 ok")

assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
