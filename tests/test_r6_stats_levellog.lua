-- Round 6 #16 (research\re_round6.md): LevelLog's Statistics tab, the game's own statistics read with the legacy
-- globals (GetStatisticsCategoryList, GetCategoryInfo, GetCategoryNumAchievements, GetAchievementInfo,
-- GetStatistic), all pcalled; kept per character (bounded), with account totals, a search, and a clear
-- message when the client has no such functions. Out of combat only; secret values skipped.
-- Run from the tests folder:  node run.js "<repo root>" test_r6_stats_levellog.lua
local base = ADDON_PATH
local out, frames, handled = {}, {}, {}
local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end

local function newRegion(kind, name, template)
    local r = { kind = kind, name = name, template = template, shown = true, scripts = {}, text = "", points = {} }
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function r:Hide() self.shown = false end
    function r:SetShown(v) if v then self:Show() else self:Hide() end end
    function r:IsShown() return self.shown end
    function r:GetStringHeight() return 14 end
    function r:SetChecked(v) self.checked = v end
    function r:GetChecked() return self.checked end
    function r:RegisterEvent() end
    function r:CreateFontString() return newRegion("font") end
    function r:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
    function r:ClearAllPoints() self.points = {} end
    function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
    return setmetatable(r, { __index = function(_, k)
        if type(k) == "string" and k:match("^%u") then return function() end end
    end })
end
CreateFrame = function(kind, name, parent, template)
    local f = newRegion(kind, name, template)
    frames[#frames + 1] = f
    return f
end
UIParent = newRegion("Frame")
SlashCmdList = {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
local SECRET = setmetatable({}, { __lt = function() error("compared a secret") end, __concat = function() error("concatenated a secret") end,
    __len = function() error("length of a secret") end })
issecretvalue = function(v) return v == SECRET end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end

local now = 1000
GetTime = function() return now end
time = function() return 1700000000 + now end
date = function() return "D" end
local timers, tick = {}, nil
C_Timer = { NewTicker = function(_, fn) tick = fn end, After = function(_, fn) timers[#timers + 1] = fn end }

UnitName = function(unit) if unit == "player" then return "Ann", "Leaf" end end
UnitGUID = function() return "Player-1-0001" end
GetRealmName = function() return "R" end
UnitLevel = function() return 11 end
UnitXP = function() return 0 end
UnitXPMax = function() return 8800 end
GetXPExhaustion = function() return 0 end
GetRealZoneText = function() return "Darkshore" end
IsInInstance = function() return false, "none" end
GetMoney = function() return 0 end
local lockdown = false
InCombatLockdown = function() return lockdown end

-- The game's statistics, as the legacy achievement API returns them.
local CATS = { [130] = { "Character", -1 }, [141] = { "Combat", 130 }, [133] = { "Quests", -1 } }
local STATS = {
    [130] = { { 328, "Total gold acquired" }, { 334, "Most gold ever owned" } },
    [141] = { { 1197, "Total kills" }, { 60, "Total deaths" } },
    [133] = { { 98, "Quests completed" }, { 99, "Quests abandoned" } },
}
local VALUES = { [328] = "12|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t 3|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t",
    [334] = "--", [1197] = "1,204", [60] = "7", [98] = "53", [99] = SECRET }
local calls = 0
GetStatisticsCategoryList = function() calls = calls + 1; return { 130, 141, 133 } end
GetCategoryInfo = function(id) local c = CATS[id]; if c then return c[1], c[2], 0 end end
GetCategoryNumAchievements = function(id) return #(STATS[id] or {}), 0, 0 end
GetAchievementInfo = function(cat, index) local s = STATS[cat] and STATS[cat][index]; if s then return s[1], s[2] end end
GetStatistic = function(id) return VALUES[id] end

-- Another character's reading, saved earlier.
LevelLogDB = {
    ["Player-1-0002"] = { charName = "Bea Stone", gameStats = { at = 1, list = {
        { id = 1197, c = "Character: Combat", n = "Total kills", v = "796" },
        { id = 328, c = "Character", n = "Total gold acquired", v = "1|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t" },
        { id = 77, c = "Travel", n = "Flight paths taken", v = "4" } } } },
}

assert(loadfile(base .. "/LevelLog/LevelLog.lua"))("LevelLog", {})
local events
for _, f in ipairs(frames) do if f.scripts.OnEvent then events = f end end
local function fire(ev, ...) events.scripts.OnEvent(events, ev, ...) end
local function page(arg) out = {}; local ok, err = pcall(SlashCmdList.LEVELLOG, arg); if not ok then out[#out + 1] = "<<ERROR " .. tostring(err) .. ">>" end end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return t end end end

fire("PLAYER_LOGIN")
local rec = LevelLogDB["Player-1-0001"]
check(rec and rec.gameStats == nil, "nothing read at login itself")
now = now + 2; tick()
check(rec.gameStats == nil, "not before 5 s")
check(#timers == 0, "no timer of its own")
now = now + 4; tick()
check(rec.gameStats and #rec.gameStats.list == 4, "read 5 s after login, zeros and secrets skipped: "
    .. tostring(rec.gameStats and #rec.gameStats.list))
local byId = {}
for _, s in ipairs(rec.gameStats.list) do byId[s.id] = s end
check(byId[1197] and byId[1197].c == "Character: Combat" and byId[1197].v == "1,204", "category names its parent")
check(not byId[334] and not byId[99], "-- and secret values left out")

-- The hub page: this character, the account total, and the other character's own statistic.
page("stats")
check(has("The game's statistics"), "page title")
check(has("Total kills: 1,204") and (has("Total kills: 1,204") or ""):find("all characters: 2000", 1, true), "kills total: " .. tostring(has("Total kills")))
check((has("Total gold acquired") or ""):find("all characters: 13g 3s 0c", 1, true), "money total: " .. tostring(has("Total gold acquired")))
check(has("Flight paths taken: -"), "another character's statistic shows")
check(has("2 characters"), "two characters counted")
-- A search narrows it and lists each character.
page("stats kills")
check(has("Total kills") and not has("Quests completed"), "search narrows")
check(has("Bea Stone: 796") and has("Ann Leaf: 1,204"), "each character's value under a narrow search")
page("stats nothinglikethis")
check(has("Nothing matches."), "no match said")

-- Re-read at most once a minute; in combat never.
local before = calls
page("stats")
check(calls == before, "not re-read within a minute")
now = now + 120
lockdown = true
page("stats")
check(calls == before, "not read in combat")
lockdown = false
fire("PLAYER_LOGOUT")
check(calls == before + 1, "read at logout")

-- Bounded: a huge category stops at 400 statistics.
STATS[133] = {}
for i = 1, 1000 do STATS[133][i] = { 5000 + i, "Stat " .. i }; VALUES[5000 + i] = tostring(i) end
fire("PLAYER_LOGOUT")
check(#rec.gameStats.list <= 400, "at most 400 kept: " .. #rec.gameStats.list)

-- The window's Statistics tab with its search box.
page("window")
local win, tab, search
for _, f in ipairs(frames) do
    if f.name == "LevelLogWindow" then win = f end
    if f.kind == "Button" and f.text == "Statistics" then tab = f end
    if f.kind == "EditBox" then search = f end
end
check(win and win.shown and tab and search, "window, tab and search box")
if tab and win and search then
    tab.scripts.OnClick(tab)
    local text = win.text.text
    check(text:find("Total kills", 1, true), "Statistics tab shows the stats")
    check(search.shown, "search box shown on the Statistics tab")
    search.text = "flight"
    search.scripts.OnTextChanged(search)
    text = win.text.text
    check(text:find("Flight paths taken", 1, true) and not text:find("Total kills", 1, true), "search box filters")
    search.text = SECRET
    local ok = pcall(search.scripts.OnTextChanged, search)
    check(ok, "secret search text ignored")
    for _, f in ipairs(frames) do if f.kind == "Button" and f.text == "Journey" then f.scripts.OnClick(f) end end
    check(not search.shown, "search box hidden on other tabs")
    ForeverHubOnSwitch.LevelLog(true)
    check(not win.shown, "hub Off hides the window")
    ForeverHubOnSwitch.LevelLog(false)
end

-- A client without the functions: a message, no error.
GetStatisticsCategoryList, GetStatistic = nil, nil
page("stats")
check(has("doesn't offer the game's Statistics") and has("GetStatisticsCategoryList"), "missing functions named")
check(not has("<<ERROR"), "no errors")
check(#handled == 0, "no handled errors: " .. table.concat(handled, " | "))

-- Static: no chat output, hooks or forbidden events.
local src = string.dump(assert(loadfile(base .. "/LevelLog/LevelLog.lua")))
for _, bad in ipairs({ "AddMessage", "hooksecurefunc", "SendChatMessage", "COMBAT_LOG", "UISpecialFrames" }) do
    check(not src:find(bad, 1, true), "source has no " .. bad)
end

if #failures > 0 then
    error("FAILURES (" .. #failures .. "):\n" .. table.concat(failures, "\n"))
end
print("test_r6_stats_levellog: all checks passed")
