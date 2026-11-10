-- Round 3 rank 3: the hub side panel shows "~N kills" next to the time to level and the kills the rested
-- pool covers, from LevelLog_KillsToLevel; nothing when LevelLog is missing or fails. (Mocks from test_hub_xp.)
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
local tipLines = {}
CreateFrame = function(kind, name)
    local f = newRegion(kind, name)
    frames[#frames + 1] = f
    if name then _G[name] = f end
    if kind == "GameTooltip" then
        f.shown = false
        function f:SetOwner() tipLines = {} end
        function f:AddLine(t) tipLines[#tipLines + 1] = t end
    end
    return f
end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
UIParent = newRegion("Frame"); Minimap = newRegion("Frame")
GameTooltip = setmetatable({}, { __index = function(_, k) error("GameTooltip." .. tostring(k) .. " used") end })
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
local me = "Me"
UnitName = function(unit) if unit == "player" then return me end end
GetRealmName = function() return "R" end
local xp, money = 100, 10000
UnitLevel = function() return 10 end
local maxXP, xpHidden = 1000, false
UnitXP = function() if xpHidden then return SECRET end return xp end
UnitXPMax = function() return maxXP end
GetXPExhaustion = function() return 0 end
GetMoney = function() return money end
-- Finished quests: questID -> reward XP.
local finished = {}
C_QuestLog = {
    GetNumQuestLogEntries = function() local n = 0; for _ in pairs(finished) do n = n + 1 end; return n end,
    GetInfo = function(index)
        local i = 0
        for id in pairs(finished) do i = i + 1; if i == index then return { questID = id, isHeader = false } end end
    end,
    IsComplete = function(id) return finished[id] ~= nil end,
}
GetQuestLogRewardXP = function(id) return finished[id] end

local hub
-- Loads the hub as the game does after a login or a /reload: fresh code, same saved data.
local function boot(isInitialLogin, isReloadingUi)
    ALLFONTS = {}
    local n = #frames
    assert(loadfile(base .. "/ForeverHub/ForeverHub.lua"))("ForeverHub", {})
    hub = frames[n + 1]
    hub.scripts.OnEvent(hub, "PLAYER_LOGIN")
    hub.scripts.OnEvent(hub, "PLAYER_ENTERING_WORLD", isInitialLogin, isReloadingUi)
    tick()
end
local function fonts()
    local out = {}
    for _, fs in ipairs(ALLFONTS) do out[#out + 1] = tostring(fs.text) end
    return table.concat(out, "\n")
end
local function has(text) return fonts():find(text, 1, true) ~= nil end
local function need(text, why) assert(has(text), why .. ": wanted '" .. text .. "' in:\n" .. fonts()) end
local function never(text, why) assert(not has(text), why .. ": did not want '" .. text .. "' in:\n" .. fonts()) end
local function gain(amount) xp = xp + amount; hub.scripts.OnEvent(hub, "PLAYER_XP_UPDATE", "player") end


----- No LevelLog: the panel is as before.
boot(true, false)
need("Next level time appears once you earn XP", "no LevelLog")
never("kills", "no kill counts without LevelLog")

----- With LevelLog's estimate: before any XP this session, the kills replace the waiting text.
LevelLog_KillsToLevel = function() return 12, 4, 75 end
GetXPExhaustion = function() return 300 end
tick()
need("About 12 kills to level", "kills shown before a rate exists")
need("Rested 30% of this level (~4 kills)", "rested pool in kills")
----- After warm-up the time to level carries the kill count.
now = 1030; gain(100); now = 1200; tick()
need("Next level in", "estimate")
need("~12 kills", "kills next to the time")
----- An error or nil from LevelLog never breaks the panel.
LevelLog_KillsToLevel = function() error("boom") end
tick()
never("kills", "no kill count on error")
LevelLog_KillsToLevel = function() return nil end
tick()
never("kills", "no kill count when unknown")
assert(#chat == 0, "no chat")
assert(#handled == 0, "no errors: " .. table.concat(handled, "|"))
print("ALL TESTS PASSED")