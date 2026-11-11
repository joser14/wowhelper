-- Round 5 #8-#10 (research\re_round5.md): LevelLog's dated journey (levels, first zone visits, dungeons,
-- deaths), lifetime and per-level stats (kills that gave XP, quests, gold, flights, zones), time split by
-- activity and a level ETA by date, all in LevelLog's own window. Saved data stays capped.
local base = ADDON_PATH
local out, chat, frames, handled = {}, {}, {}, {}
local function newRegion(kind, name, template)
    local r = { kind = kind, name = name, template = template, shown = true, scripts = {}, text = "", height = 0, points = {} }
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function r:Hide() self.shown = false end
    function r:SetShown(v) if v then self:Show() else self:Hide() end end
    function r:IsShown() return self.shown end
    function r:GetStringHeight() return 14 end
    function r:SetHeight(h) self.height = h end
    function r:SetChecked(v) self.checked = v end
    function r:GetChecked() return self.checked end
    function r:RegisterEvent() end
    function r:CreateFontString() return newRegion("font") end
    function r:CreateTexture() return newRegion("texture") end
    function r:GetPoint() return "CENTER", nil, "CENTER", 5, 6 end
    return setmetatable(r, { __index = function(_, k)
        if type(k) == "string" and k:match("^%u") then return function() end end
    end })
end
CreateFrame = function(kind, name, parent, template)
    local f = newRegion(kind, name, template)
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
UIParent = newRegion("Frame")
UISpecialFrames = {}
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
local say = print
print = function(...) chat[#chat + 1] = table.concat({ ... }, " ") end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
local SECRET = {}
issecretvalue = function(v) return v == SECRET end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end

local now, server = 1000, 86400 * 20000 + 3600 * 10
GetTime = function() return now end
GetServerTime = function() return server end
-- A plain date stand-in: one key per day, the day number in the rest.
date = function(fmt, t)
    local day = math.floor((t or server) / 86400)
    if fmt == "%Y-%m-%d" then return string.format("D%06d", day) end
    if fmt == "%Y-%m" then return string.format("M%04d", math.floor(day / 30)) end
    if fmt == "%H:%M" then return "12:00" end
    return "DAY" .. day
end
local tick
C_Timer = { NewTicker = function(_, fn) tick = fn end, After = function(_, fn) fn() end }

UnitName = function(unit) if unit == "player" then return "Ann" end end
GetRealmName = function() return "R" end
local level, xp, maxXP = 10, 0, 7600
UnitLevel = function() return level end
UnitXP = function() return xp end
UnitXPMax = function() return maxXP end
GetXPExhaustion = function() return 0 end
local zone, inside, kind = "Teldrassil", false, "none"
GetRealZoneText = function() return zone end
IsInInstance = function() return inside, kind end
local money = 1000
GetMoney = function() return money end
local dead, taxi, combat, moving, resting = false, false, false, false, false
UnitIsDeadOrGhost = function() return dead end
UnitOnTaxi = function() return taxi end
UnitAffectingCombat = function() return combat end
IsPlayerMoving = function() return moving end
IsResting = function() return resting end

assert(loadfile(base .. "/LevelLog/LevelLog.lua"))("LevelLog", {})
local ev = frames[#frames]
local function fire(...) ev.scripts.OnEvent(ev, ...) end
fire("PLAYER_LOGIN")
local rec = LevelLogDB["Ann-R"]
assert(rec, "own record")
local function step(seconds) for _ = 1, seconds do now = now + 1; server = server + 1; tick() end end

-- 1. The journal starts quietly in the zone you log in to.
assert(type(rec.journey) == "table" and #rec.journey == 1 and rec.journey[1].k == "start", "start entry")
assert(rec.journey[1].z == "Teldrassil" and rec.journey[1].l == 10, "start zone and level")
assert(rec.seen.zones.Teldrassil, "login zone remembered")
-- A new zone is a first visit; going back isn't.
zone = "Darkshore"; fire("ZONE_CHANGED_NEW_AREA")
zone = "Teldrassil"; fire("ZONE_CHANGED_NEW_AREA")
zone = "Darkshore"; fire("ZONE_CHANGED_NEW_AREA")
assert(#rec.journey == 2 and rec.journey[2].k == "zone" and rec.journey[2].z == "Darkshore", "one first visit")
-- Dungeons: the first one is marked.
zone, inside, kind = "The Deadmines", true, "party"; fire("PLAYER_ENTERING_WORLD")
zone = "Wailing Caverns"; fire("PLAYER_ENTERING_WORLD")
zone, inside, kind = "Darkshore", false, "none"; fire("PLAYER_ENTERING_WORLD")
assert(rec.journey[3].k == "dungeon" and rec.journey[3].first == true, "first dungeon")
assert(rec.journey[4].k == "dungeon" and rec.journey[4].first == nil, "second dungeon isn't first")
-- A secret zone name is skipped.
zone = SECRET; fire("ZONE_CHANGED_NEW_AREA"); zone = "Darkshore"
assert(#rec.journey == 4, "secret zone ignored")
-- Deaths go in the journey and the level.
fire("PLAYER_DEAD")
assert(rec.journey[5].k == "death" and rec.journey[5].z == "Darkshore" and rec[10].deaths == 1, "death")
say("1 ok")

-- 2. Kills: XP in combat counts once no turn-in claimed it; XP out of combat (exploring) doesn't.
fire("PLAYER_REGEN_DISABLED")
now = now + 1; xp = 100; fire("PLAYER_XP_UPDATE", "player")
step(2)
assert(rec.stats.kills == 1 and rec[10].kills == 1, "kill counted: " .. tostring(rec.stats.kills))
-- A turn-in right after a gain in combat: that gain was the reward.
now = now + 1; xp = 400; fire("PLAYER_XP_UPDATE", "player")
now = now + 0.2; fire("QUEST_TURNED_IN", 5, 300, 0)
step(2)
assert(rec.stats.kills == 1, "quest XP isn't a kill")
assert(rec.stats.quests == 1 and rec[10].quests == 1, "quest counted")
fire("PLAYER_REGEN_ENABLED")
step(4)
now = now + 1; xp = 450; fire("PLAYER_XP_UPDATE", "player")
step(2)
assert(rec.stats.kills == 1, "exploring XP isn't a kill")
-- Just after combat (within 3 s) still counts.
fire("PLAYER_REGEN_DISABLED"); fire("PLAYER_REGEN_ENABLED")
now = now + 1; xp = 550; fire("PLAYER_XP_UPDATE", "player")
step(2)
assert(rec.stats.kills == 2, "kill right after combat: " .. tostring(rec.stats.kills))
say("2 ok")

-- 3. Gold in and out; an unreadable reading waits for the next one.
money = 1500; fire("PLAYER_MONEY")
money = SECRET; fire("PLAYER_MONEY")
money = 1200; fire("PLAYER_MONEY")
assert(rec.stats.moneyIn == 500 and rec.stats.moneyOut == 300, "money: " .. tostring(rec.stats.moneyIn) .. "/" .. tostring(rec.stats.moneyOut))
say("3 ok")

-- 4. Time split by activity, per level and lifetime (after the turn-in above stops counting as questing).
step(25)
local act = rec[10].activity
local function snapshot() local t = {}; for k, v in pairs(act) do t[k] = v end; return t end
local function grew(before, key, seconds)
    local diff = (act[key] or 0) - (before[key] or 0)
    assert(math.abs(diff - seconds) < 1e-6, key .. " grew by " .. diff .. ", wanted " .. seconds)
end
local s = snapshot(); moving = true; step(5); grew(s, "travel", 5)
s = snapshot(); resting = true; step(3); grew(s, "town", 3)
s = snapshot(); moving, resting = false, false; combat = true; step(4); grew(s, "fight", 4); combat = false
s = snapshot(); fire("QUEST_DETAIL"); step(2); grew(s, "quest", 2)
s = snapshot(); taxi = true; step(6); grew(s, "flight", 6); taxi = false
assert(rec.stats.flights == 1 and rec[10].flights == 1, "one flight")
s = snapshot(); dead = true; step(2); grew(s, "dead", 2); dead = false
s = snapshot(); step(200); assert((act.afk or 0) - (s.afk or 0) > 0, "away after 3 min still")
-- A secret taxi reading isn't a flight.
taxi = SECRET; step(1); taxi = false
assert(rec.stats.flights == 1, "secret taxi not a flight")
-- A long gap (loading screen) counts 2 s at most.
s = snapshot(); moving = true; now = now + 60; tick(); moving = false
local total = 0; for k, v in pairs(act) do total = total + v - (s[k] or 0) end
assert(total <= 2 + 1e-6, "gap capped: " .. total)
assert(rec.stats.activity.travel >= 5 and (rec.stats.zones.Darkshore or 0) > 200, "lifetime split and zone time")
say("4 ok")

-- 5. Level up: a dated journey entry with how long the level took.
level, xp, maxXP = 11, 50, 8800
fire("PLAYER_XP_UPDATE", "player")
fire("PLAYER_LEVEL_UP", 11)
local last = rec.journey[#rec.journey]
assert(last.k == "level" and last.n == 11 and last.s and last.s > 0, "level entry")
say("5 ok")

-- 6. Pace and ETA: five finished levels at 3600 XP/h; 2 h a day over the last days.
for l = 5, 9 do rec[l] = { seconds = 3600, deaths = 0, xp = 3600 } end
rec[10] = { seconds = 7200, deaths = 0, xp = 7200, activity = { afk = 3600 } }   -- 7200 XP in 1 h of play
rec[11] = { seconds = 30, deaths = 0, xp = 50 }
local today = math.floor(server / 86400)
rec.days = {}
for d = 1, 3 do rec.days[string.format("D%06d", today - d)] = { s = 7200 } end
local rate, used = LevelLog_Pace()
-- Newest first: 10 (7200) is over twice the median (3600)? No: 2 x 3600 = 7200, kept. Weighted mean.
local w, sum, ws = 1, 0, 0
for _, v in ipairs({ 7200, 3600, 3600, 3600, 3600, 3600 }) do sum = sum + v * w; ws = ws + w; w = w * 0.85 end
assert(used == 6 and math.abs(rate - sum / ws) < 1e-6, "weighted pace: " .. tostring(rate) .. " used " .. tostring(used))
local hours, days = LevelLog_HoursPerDay()
assert(hours == 2 and days == 3, "2 h a day: " .. tostring(hours))
local eta = LevelLog_ETA(12)
assert(eta and math.abs(eta.hours - 8750 / rate) < 1e-9, "hours to 12")
assert(math.abs(eta.at - (server + eta.hours / 2 * 86400)) < 1e-6, "date at 2 h a day")
local text = LevelLog_ETAText(12)
assert(text:find("^Level 12 about DAY") and text:find("at 2.0 h a day", 1, true), "ETA text: " .. text)
-- A level far over the rest is left out of the pace.
rec[9].seconds = 360           -- 36000 XP/h: more than twice the median
local rate2, used2 = LevelLog_Pace()
assert(used2 == 5, "outlier dropped: " .. tostring(used2))
rec[9].seconds = 3600
-- Nothing at 60 or past it.
assert(LevelLog_ETA(61) == nil and LevelLog_ETA(11) == nil, "no ETA for 61 or the level you're on")
say("6 ok")

-- 7. The hub's Level log page: the page text; the window opens from the page's button (cross-addon
-- review: by default it no longer opens over the page by itself).
out = {}
SlashCmdList.LEVELLOG("all")
local page = table.concat(out, "\n")
assert(page:find("Level 12 about", 1, true), "ETA on the page:\n" .. page)
assert(page:find("LevelLog window", 1, true), "points to the window")
assert(not (LevelLogWindow and LevelLogWindow.shown), "the page alone doesn't open the window by default")
SlashCmdList.LEVELLOG("window")
local win = LevelLogWindow
assert(win and win.shown, "window opened from the page's button")
assert(win.auto.checked == false, "'open with the page' starts unticked")
assert(win.text.text:find("Reached level 11", 1, true) and win.text.text:find("First visit: Darkshore", 1, true), "journey:\n" .. win.text.text)
assert(win.text.text:find("Entered dungeon: The Deadmines", 1, true) and win.text.text:find("Died", 1, true), "dungeon and death")
-- By level.
local function button(label) for _, f in ipairs(frames) do if f.kind == "Button" and f.text == label then return f end end end
button("By level").scripts.OnClick()
assert(win.text.text:find("Level 10", 1, true), "grouped by level")
button("Stats").scripts.OnClick()
assert(win.text.text:find("Kills that gave XP: 2", 1, true) and win.text.text:find("Quests turned in: 1", 1, true), "stats:\n" .. win.text.text)
assert(win.text.text:find("Gold in: 5s 0c", 1, true) and win.text.text:find("Flights: 1", 1, true), "gold and flights")
assert(win.text.text:find("Level 10: 2h 0m, 0 deaths", 1, true), "per level")
assert(win.text.text:find("Darkshore", 1, true), "most time in")
button("Time and ETA").scripts.OnClick()
assert(win.text.text:find("Level 11 so far", 1, true) and win.text.text:find("Fighting", 1, true), "time split:\n" .. win.text.text)
assert(win.text.text:find("Level 15 about", 1, true) and win.text.text:find("Level 60 about", 1, true), "ETAs")
-- Ticked: the page opens it; unticked again: it doesn't.
win:Hide()
win.auto.checked = true; win.auto.scripts.OnClick(win.auto)
SlashCmdList.LEVELLOG("all")
assert(win.shown, "opens with the page when ticked")
win:Hide()
win.auto.checked = false; win.auto.scripts.OnClick(win.auto)
SlashCmdList.LEVELLOG("all")
assert(not win.shown, "stays closed when switched off")
SlashCmdList.LEVELLOG("window")
assert(win.shown, "window toggles open")
SlashCmdList.LEVELLOG("window")
assert(not win.shown, "and closed")
-- Without the hub, /levellog is the window.
ForeverHub_Receive = nil
SlashCmdList.LEVELLOG("")
assert(win.shown, "no hub: the window")
say("7 ok")

-- 8. Caps: the journey keeps the newest 1000 (older ones counted per month), the day log 60 days.
for i = 1, 1100 do
    server = server + 3600
    fire("PLAYER_DEAD")
end
assert(#rec.journey == 1000, "journey capped: " .. #rec.journey)
local folded = 0
for _, counts in pairs(rec.journeyOld) do for _, n in pairs(counts) do folded = folded + n end end
assert(folded > 0 and folded + 1000 >= 1100, "older entries counted: " .. folded)
for d = 1, 80 do server = server + 86400; now = now + 1; tick() end
local n = 0; for _ in pairs(rec.days) do n = n + 1 end
assert(n <= 60, "days capped: " .. n)
local z = 0; for _ in pairs(rec.stats.zones) do z = z + 1 end
assert(z <= 120, "zones capped")
say("8 ok")

assert(#chat == 0, "no chat: " .. tostring(chat[1]))
assert(#handled == 0, "no errors: " .. table.concat(handled, " | "))
say("ALL TESTS PASSED")
