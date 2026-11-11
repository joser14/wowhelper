-- Perf audit 8 (ForeverHub): the side panel's stat lines aren't formatted every second while the panel is
-- hidden; showing it refreshes them at once. Mocks copied from test_r4c_tosixty.lua.
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
-- A. Panel shown: the stat lines are refreshed every second.
local panel = ForeverHubPanel
assert(panel and panel.shown, "side panel shown")
local reads = 0
local realToSixty = LevelLog_ToSixty
LevelLog_ToSixty = function(...) reads = reads + 1; return realToSixty(...) end
tick()
assert(reads == 1, "refreshed while shown: " .. reads)
-- B. Panel hidden: the ticker doesn't format lines nobody sees.
panel:Hide()
reads = 0
for _ = 1, 5 do now = now + 1; tick() end
assert(reads == 0, "no refresh while hidden: " .. reads)
-- C. Shown again: up to date at once, not a second later.
level, xp = 11, 100
panel:Show()
assert(reads == 1, "refreshed on show: " .. reads)
need("Level 11", "fresh level line on show")
assert(#handled == 0, "no errors: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
