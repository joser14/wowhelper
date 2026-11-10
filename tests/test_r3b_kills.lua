-- Round 3 rank 3: LevelLog reads LevelGuide's kill XP (read-only) for "about N kills to level",
-- "rested covers about N kills", and the XP your target gives (LevelGuide's model when loaded, else a local
-- copy). Shown on the Level log page, the hub side panel and the Rested XP page.
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
local now = 1000
GetTime = function() return now end
local xp, max, level, rested, fighting = 0, 1000, 10, 0, true
UnitXP = function() return xp end
UnitXPMax = function() return max end
local target = nil
UnitLevel = function(unit) if unit == "target" then return target and target.level end return level end
UnitName = function(unit) if unit == "target" then return target and target.name end return "Me" end
GetRealmName = function() return "R" end
GetXPExhaustion = function() return rested end
UnitAffectingCombat = function() return fighting end
UnitExists = function(unit) return unit == "target" and target ~= nil end
UnitIsPlayer = function(unit) return unit == "player" or (target and target.player) or false end
UnitCanAttack = function() return target ~= nil and not target.friend end
UnitIsDead = function() return false end
UnitClassification = function() return target and target.class or "normal" end

assert(loadfile(base .. "/LevelLog/LevelLog.lua"))("LevelLog", {})
local f = frames[1]
local function fire(...) f.fn(f, ...) end
fire("PLAYER_LOGIN")
-- LevelGuide's per-character kill shares (a kill's own XP / a same-level mob's XP), read-only.
LevelGuideDB = { characters = {} }
local shares = {}
LevelGuideDB.characters[ForeverCharacterKey()] = { killXP = shares }
local function kill(gain)
    now = now + 10
    xp = xp + gain
    fire("PLAYER_XP_UPDATE", "player")
end

-- 1. No LevelGuide data, or under three kills: no estimate.
LevelGuideDB.characters[ForeverCharacterKey()] = nil
assert(LevelLog_KillsToLevel() == nil, "no LevelGuide data")
LevelGuideDB.characters[ForeverCharacterKey()] = { killXP = shares }
shares[1], shares[2] = 1, 1
assert(LevelLog_KillsToLevel() == nil, "no estimate from two kills")
print("1 ok")

-- 2. Three kills worth a same-level mob (95 XP at level 10); xp 0 of 1000 -> 11 kills.
shares[3] = 1
local kills, restedKills, perKill = LevelLog_KillsToLevel()
assert(perKill == 95 and kills == 11 and restedKills == 0, "1000 to go at 95 a kill: " .. tostring(kills) .. "/" .. tostring(perKill))
print("2 ok")

-- 3. Rested: 300 to go with 300 rested -> rested kills pay double: ceil(150 / 95) = 2; the pool covers 3.
xp = 700; rested = 300
kills, restedKills = LevelLog_KillsToLevel()
assert(kills == 2 and restedKills == 3, "rested kills count double: " .. kills .. ", covers " .. restedKills)
print("3 ok")

-- 4. LevelGuide's Median and KillsLeft are used when loaded; LevelLog never writes LevelGuide's data.
LevelGuidePlanner = { Median = function() return 2 end, KillsLeft = function() return 42 end }
kills, restedKills, perKill = LevelLog_KillsToLevel()
assert(kills == 42 and perKill == 190, "planner used: " .. kills .. "/" .. perKill)
LevelGuidePlanner = nil
kill(100)
fire("QUEST_TURNED_IN", 5, 400, 0)
assert(#shares == 3, "LevelGuide's list untouched")
print("4 ok")

-- 5. Odd entries in the saved list are skipped.
shares[4], shares[5] = "x", -1
assert(select(2, LevelLog_KillXP()) == 3, "only real shares counted")
xp, rested = 0, 0
print("5 ok")
-- 6. Target XP: one level above, plain -> 95 x 1.05 = 100; elite x2; grey gives nothing; friendly or
-- players give no line. With rested XP the rested figure doubles up to the pool.
rested = 0
target = { level = 11, name = "Kobold" }
local tx, trested, tname = LevelLog_TargetXP()
assert(tx == 100 and trested == 100 and tname == "Kobold", "level 11 mob at level 10: " .. tostring(tx))
target.class = "elite"
assert(LevelLog_TargetXP() == 200, "elite doubles")
target = { level = 4, name = "Rabbit" }
assert(LevelLog_TargetXP() == 0, "grey gives nothing")
target = { level = 10, name = "Guard", friend = true }
assert(LevelLog_TargetXP() == nil, "friendly: nothing")
target = { level = 10, name = "Bob", player = true }
assert(LevelLog_TargetXP() == nil, "player: nothing")
target = { level = 10, name = "Wolf" }
rested = 50
tx, trested = LevelLog_TargetXP()
assert(tx == 95 and trested == 145, "rested bonus up to the pool: " .. tostring(trested))
-- The skull level (-1) and secret levels give nothing.
target = { level = -1, name = "Boss" }
assert(LevelLog_TargetXP() == nil, "skull: nothing")
target = { level = SECRET, name = "Hidden" }
assert(LevelLog_TargetXP() == nil, "secret level: nothing")
-- LevelGuide's model wins when it's loaded.
LevelGuidePlanner = { MobXP = function() return 777 end }
target = { level = 11, name = "Kobold" }
assert(LevelLog_TargetXP() == 777, "LevelGuide's XP model used when loaded")
LevelGuidePlanner = nil
print("6 ok")

-- 7. The panel row and the page line.
local rows = ForeverHubStatus.LevelLog()
assert(rows and rows[1].text:find("Kobold", 1, true) and rows[1].text:find("~100 XP", 1, true), "panel row: " .. tostring(rows and rows[1].text))
target = { level = 4, name = "Rabbit" }
assert(ForeverHubStatus.LevelLog()[1].text:find("no XP", 1, true), "grey row")
target = nil
assert(ForeverHubStatus.LevelLog() == nil, "no target, no row")
-- Per kill 95 (three shares of 1), 300 rested -> the pool covers 3 kills.
rested = 300
out = {}
SlashCmdList.LEVELLOG("all")
local page = table.concat(out, "\n")
assert(page:find("A kill gives you about 95 XP", 1, true), "page line:\n" .. page)
assert(page:find("rested covers about", 1, true), "page rested line:\n" .. page)
print("7 ok")

-- 8. RestGuard's page names the kills the pool covers.
GetBindLocation = function() return "Goldshire" end
IsResting = function() return false end
C_Item = { GetItemCount = function() return 1 end }
C_Container = {}
out = {}
rested = 300
assert(loadfile(base .. "/RestGuard/RestGuard.lua"))("RestGuard", {})
SlashCmdList.RESTGUARD()
page = table.concat(out, "\n")
assert(page:find("Rested covers about 3 kill(s)", 1, true), "RestGuard kills line:\n" .. page)
print("8 ok")

assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
