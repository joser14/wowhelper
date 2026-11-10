-- Round 4 item 9 (research\re_round4.md R9, after XP Horizon, GPL-3.0-or-later): "N % of the way to 60" and
-- "about N h at this pace" on the hub's side panel. LevelLog learns the XP each level needs from UnitXPMax,
-- account-wide (LevelLogXPCurve), over the Classic table; no /played (RequestTimePlayed prints to chat), no
-- XP-bar hook. The pace is the hub's recent XP per hour.
local base = ADDON_PATH
local chat, timers, frames, handled = {}, {}, {}, {}
ALLFONTS = {}
local function newRegion(kind, name)
    local r = { kind = kind, name = name, shown = true, scripts = {}, text = "", height = 0, points = {} }
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function r:Hide() self.shown = false end
    function r:SetShown(v) if v then self:Show() else self:Hide() end end
    function r:IsShown() return self.shown end
    function r:GetStringHeight() return 14 end
    function r:SetHeight(h) self.height = h end
    function r:GetHeight() return self.height end
    function r:ClearAllPoints() self.points = {} end
    function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function r:GetPoint() return "CENTER", nil, "CENTER", 1, 2 end
    function r:RegisterEvent() end
    function r:CreateFontString() local fs = newRegion("font"); ALLFONTS[#ALLFONTS + 1] = fs; return fs end
    function r:CreateTexture() return newRegion("texture") end
    return setmetatable(r, { __index = function(_, k)
        if type(k) == "string" and k:match("^%u") then return function() end end
    end })
end
CreateFrame = function(kind, name)
    local f = newRegion(kind, name)
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
UIParent = newRegion("Frame"); Minimap = newRegion("Frame")
UISpecialFrames = {}
SlashCmdList = {}
local now, tick = 1000, nil
GetTime = function() return now end
time = function() return 1700000000 end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function(_, fn) tick = fn end }
local SECRET = {}
issecretvalue = function(v) return v == SECRET end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = function() end }
C_CVar = { SetCVar = function() end }
UnitName = function(unit) if unit == "player" then return "Me" end end
GetRealmName = function() return "R" end
local level, xp, maxXP = 10, 0, 7600
UnitLevel = function() return level end
UnitXP = function() return xp end
UnitXPMax = function() return maxXP end
GetXPExhaustion = function() return 0 end
GetMoney = function() return 0 end
C_QuestLog = { GetNumQuestLogEntries = function() return 0 end, GetInfo = function() end, IsComplete = function() end }
GetQuestLogRewardXP = function() return 0 end

-- LevelLog first (as in the bundle), then the hub.
assert(loadfile(base .. "/LevelLog/LevelLog.lua"))("LevelLog", {})
local log = frames[#frames]
local function logFire(...) log.scripts.OnEvent(log, ...) end
local n = #frames
assert(loadfile(base .. "/ForeverHub/ForeverHub.lua"))("ForeverHub", {})
local hub = frames[n + 1]
logFire("PLAYER_LOGIN")
hub.scripts.OnEvent(hub, "PLAYER_LOGIN")
hub.scripts.OnEvent(hub, "PLAYER_ENTERING_WORLD", true, false)
local function fonts()
    local out = {}
    for _, fs in ipairs(ALLFONTS) do out[#out + 1] = tostring(fs.text) end
    return table.concat(out, "\n")
end
local function has(text) return fonts():find(text, 1, true) ~= nil end
local function need(text, why) assert(has(text), why .. ": wanted '" .. text .. "' in:\n" .. fonts()) end
local function never(text, why) assert(not has(text), why .. ": did not want '" .. text .. "' in:\n" .. fonts()) end

-- 1. The Classic curve: 4,084,700 XP from 1 to 60; at level 10 with 0 XP, 1-9 are done (27,600) = 0.7 %.
local frac, left, total = LevelLog_ToSixty()
assert(total == 4084700, "Classic total: " .. tostring(total))
assert(left == 4084700 - 27600 and math.abs(frac - 27600 / 4084700) < 1e-12, "done 1-9: " .. tostring(left))
tick()
need("0.7% of the way to 60", "side panel line")
print("1 ok")

-- 2. Learned: Forever's bar for a level (UnitXPMax) replaces the Classic number, account-wide. At a level-up
-- UnitLevel can still say the old level: the bar is learned for the new one.
assert(LevelLogXPCurve and LevelLogXPCurve[10] == 7600, "learned at login")
xp = 4000
logFire("PLAYER_XP_UPDATE", "player")
maxXP, xp = 9000, 100          -- level 11 on Forever needs 9000 (Classic 8800); UnitLevel still 10
logFire("PLAYER_XP_UPDATE", "player")
assert(LevelLogXPCurve[11] == 9000 and LevelLogXPCurve[10] == 7600, "learned for the new level")
level = 11
logFire("PLAYER_LEVEL_UP", 11)
frac, left, total = LevelLog_ToSixty()
assert(total == 4084700 + 200, "curve total moves with what was seen: " .. tostring(total))
assert(left == total - 35200 - 100, "your XP in the level counts: " .. tostring(left))
-- A hidden reading is never learned.
maxXP = SECRET
logFire("PLAYER_XP_UPDATE", "player")
assert(LevelLogXPCurve[11] == 9000, "secret not learned")
maxXP = 9000
print("2 ok")

-- 3. The time at this pace: once warmed up, from the hub's recent XP per hour.
local restart
for _, f in ipairs(frames) do if f.kind == "Button" and f.text == "Restart" then restart = f end end
now = 1100; restart.scripts.OnClick(restart)
now = 1130; xp = 200; hub.scripts.OnEvent(hub, "PLAYER_XP_UPDATE", "player"); tick()
never("at this pace", "no estimate while warming up")
need("of the way to 60", "the share shows while warming up")
now = 1300; xp = 300; hub.scripts.OnEvent(hub, "PLAYER_XP_UPDATE", "player"); tick()
-- 200 XP in 200 s -> 3600 XP/h; left = 4084900 - 35200 - 300 = 4049400 -> 1124 h 50 m.
need("about 1124h ", "time to 60 (1124 h 49-50 m)")
print("3 ok")

-- 4. At 60 there is nothing to show; LevelLog switched off in the hub: no line.
level, xp = 60, 0
frac, left = LevelLog_ToSixty()
assert(frac == 1 and left == 0, "done at 60")
tick()
never("of the way to 60", "nothing at 60")
assert(#chat == 0, "no chat")
assert(#handled == 0, "no errors: " .. table.concat(handled, "|"))
print("ALL TESTS PASSED")
