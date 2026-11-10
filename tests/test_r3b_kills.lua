-- Round 3 rank 3: kill XP measured by LevelLog with the rested bonus taken off, "about N kills to level",
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
local function kill(gain, restedAfter)
    now = now + 10
    xp = xp + gain
    if restedAfter then rested = restedAfter end
    fire("PLAYER_XP_UPDATE", "player")
end

-- 1. Under three kills there's no estimate.
kill(100); kill(100)
assert(LevelLog_KillsToLevel() == nil, "no estimate from two kills")
print("1 ok")

-- 2. Three plain kills of 100: 700 to go -> 7 kills.
kill(100)
local kills, restedKills, perKill = LevelLog_KillsToLevel()
assert(perKill == 100 and kills == 7 and restedKills == 0, "700 to go at 100 a kill: " .. tostring(kills) .. "/" .. tostring(perKill))
print("2 ok")

-- 3. Rested kills: 200 XP each while the pool drops by 100. The bonus is taken off the sample. The pool
-- can drop before or after the XP update (UPDATE_EXHAUSTION first).
rested = 500; fire("UPDATE_EXHAUSTION")
kill(200, 400)
rested = 300; fire("UPDATE_EXHAUSTION")
kill(200)
local list = LevelLogDB[next(LevelLogDB)].killSamples
assert(list[#list].xp == 100 and list[#list - 1].xp == 100, "rested bonus taken off: " .. list[#list].xp .. ", " .. list[#list - 1].xp)
-- xp 700, 300 to go, pool 300: rested kills pay double -> 150 XP worth of kills at 200 = 2 kills.
kills, restedKills = LevelLog_KillsToLevel()
assert(kills == 2 and restedKills == 3, "rested kills count double: " .. kills .. ", covers " .. restedKills)
print("3 ok")

-- 4. XP out of combat (exploring) isn't a kill; a quest turned in during a fight is taken back.
fighting = false
local count = #list
now = now + 30
kill(55)
assert(#list == count, "exploration XP isn't a kill")
fighting = true
kill(400)
fire("QUEST_TURNED_IN", 5, 400, 0)
assert(#list == count, "a turn-in's XP isn't a kill")
-- The last kill's XP right after combat ends still counts.
fighting = false
fire("PLAYER_REGEN_ENABLED")
now = now + 1; xp = xp + 100; fire("PLAYER_XP_UPDATE", "player")
assert(#list == count + 1, "XP just after combat counts as a kill")
print("4 ok")

-- 5. Samples are bounded and saved.
fighting = true
for _ = 1, 30 do kill(1) end
assert(#list == 10, "only the last 10 kills are kept: " .. #list)
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
-- Ten fresh kills of 100; 800 to go with 300 rested -> max(500, 400) / 100 = 5 kills.
rested = 300
for _ = 1, 10 do kill(100) end
max = xp + 800
out = {}
SlashCmdList.LEVELLOG("all")
local page = table.concat(out, "\n")
assert(page:find("About 5 kill(s) to level (a kill ~100 XP", 1, true), "page line:\n" .. page)
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
