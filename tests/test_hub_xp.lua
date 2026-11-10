-- ForeverHub side panel XP: warm-up before a time to level, finished-quest XP taken off the estimate,
-- "Turn in to level up", and the XP/gold session kept across /reload but not across a real login.
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

----- Real login: nothing earned yet.
boot(true, false)
assert(#handled == 0, "login clean: " .. table.concat(handled, "|"))
need("Next level time appears once you earn XP", "no XP yet")
assert(ForeverHubDB.session and ForeverHubDB.session.start == 1000 and ForeverHubDB.session.owner == "Me-R", "session saved with owner")
assert(ForeverHubDB.session.loginStamp == 1700000000, "login stamp saved")

----- a. Warm-up: XP earned, but under two minutes measured.
now = 1030; gain(100); tick()
need("warming up (90s)", "warm-up text")
never("Next level in", "no estimate while warming up")
now = 1130; tick()
-- 100 XP over 130 s; 800 to go -> 1040 s.
need("Next level in 17m", "estimate after warm-up")
never("warming up", "warm-up over")

----- b. Finished-quest XP comes off the estimate.
finished = { [11] = 300 }
now = 1135; tick()
need("+30% to turn in", "banked XP shown")
-- 500 still to earn at 100 XP per 135 s -> 675 s.
need("Next level in 11m", "estimate counts only XP not yet in finished quests")
finished = { [11] = 300, [12] = 500 }
now = 1141; tick()
need("Turn in to level up", "finished quests alone reach the next level")
never("Next level in", "no time when turning in is enough")
finished = {}
now = 1147; tick()
need("Next level in", "back to an estimate once turned in")

----- c. /reload keeps the session: no new warm-up, gold rate from the original start.
now = 1800; money = 40000
hub.scripts.OnEvent(hub, "PLAYER_LOGOUT")
assert(#ForeverHubDB.session.samples == 1, "sample saved")
boot(false, true)
-- 100 XP over 800 s, 800 to go -> 6400 s.
need("Next level in 1h 46m", "estimate survives /reload")
never("warming up", "no warm-up after /reload")
-- 30000 copper over 800 s -> 13g 50s an hour.
need("+13g 50s/hr", "gold rate survives /reload")
assert(ForeverHubDB.session.start == 1000, "start kept")

----- Another character's saved session is never picked up.
me = "Alt"
now = 1900
boot(false, true)
assert(ForeverHubDB.session.start == 1900 and ForeverHubDB.session.owner == "Alt-R", "other character starts fresh")
need("Next level time appears once you earn XP", "no samples for the alt")

----- A real login starts over.
me = "Me"
now = 2000; gain(50)
boot(true, false)
assert(ForeverHubDB.session.start == 2000 and #ForeverHubDB.session.samples == 0, "real login resets")
need("Next level time appears once you earn XP", "fresh after login")
never("/hr", "gold rate restarts after login")

----- Unreadable event arguments count as a login, not a reload.
now = 2010; gain(10)
boot(SECRET, SECRET)
assert(ForeverHubDB.session.start == 2010 and #ForeverHubDB.session.samples == 0, "secret args start fresh")

----- A clock that went backwards (game restarted) is not a reload.
ForeverHubDB.session.start = 99999
now = 2020
boot(false, true)
assert(ForeverHubDB.session.start == 2020, "future start ignored")

----- Saved samples are bounded.
for i = 1, 250 do now = now + 1; gain(1) end
assert(#ForeverHubDB.session.samples == 200, "samples capped: " .. #ForeverHubDB.session.samples)

----- Restart on the side panel starts measuring again.
local restart
for _, f in ipairs(frames) do if f.kind == "Button" and f.text == "Restart" then restart = f end end
assert(restart, "restart control on the panel")
restart.scripts.OnEnter(restart)
assert(tipLines[1] and tipLines[1]:find("after a break", 1, true), "restart explains itself")
now = now + 5
restart.scripts.OnClick(restart)
assert(ForeverHubDB.session.start == now and #ForeverHubDB.session.samples == 0, "restart clears the session")
need("Next level time appears once you earn XP", "restarted")
now = now + 10; gain(20); tick()
need("warming up (110s)", "restart warms up again")

----- A level-up while XP was hidden (an instance): the new bar size shows it even when the XP after
----- it is higher than the last reading. Before, only the difference (+50 here) was counted.
local before = xp
xpHidden = true
now = now + 5; gain(400)
xpHidden = false
maxXP, xp = 1200, before + 50
now = now + 5; hub.scripts.OnEvent(hub, "PLAYER_XP_UPDATE", "player")
local samples = ForeverHubDB.session.samples
assert(samples[#samples].amount == (1000 - before) + before + 50, "level-up counted whole: " .. tostring(samples[#samples].amount))

assert(#chat == 0, "no chat")
assert(#handled == 0, "no errors: " .. table.concat(handled, "|"))
print("ALL TESTS PASSED")
