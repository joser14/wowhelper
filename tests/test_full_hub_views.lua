-- Full review (hub, guides, quests): the round 6 hub pages and buttons. Each new button reaches its helper's
-- handler with the right word, and a button that changes a setting (a gathering layer switch, the spell math
-- tooltip line) runs once per click: closing and reopening the hub, which redraws the page, must not run it
-- again (before the fix every reopen flipped the gathering layer back).
local base = ADDON_PATH
local timers, frames, handled = {}, {}, {}
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
    function r:LockHighlight() self.locked = true end
    function r:UnlockHighlight() self.locked = false end
    function r:CreateFontString() local fs = newRegion("font"); ALLFONTS[#ALLFONTS + 1] = fs; return fs end
    function r:CreateTexture() return newRegion("texture") end
    function r:GetFontString() return nil end
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
UIParent = newRegion("Frame"); Minimap = newRegion("Frame")
UISpecialFrames = {}
SlashCmdList = {}
GetTime = function() return 1000 end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function() end }
issecretvalue = function() return false end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
InCombatLockdown = function() return false end
UnitLevel = function() return 10 end
UnitXP = function() return 100 end
UnitXPMax = function() return 1000 end
UnitName = function() return "Tester" end
GetXPExhaustion = function() return 0 end
GetMoney = function() return 100 end
local realPrint = print
print = function() error("print used") end

-- Helper commands: record what they were asked and answer with one line naming it.
local calls = {}
local function helper(key, source)
    SlashCmdList[key] = function(arg)
        calls[#calls + 1] = key .. ":" .. tostring(arg)
        ForeverHub_Receive(source, source .. " says [" .. tostring(arg) .. "]")
    end
end
for key, source in pairs({ LEGACYPOINTS = "Legacy", SPELLMATH = "SpellMath", AGGROWATCH = "AggroWatch", EVENTS = "Events", NODES = "Nodes", MAPPINS = "MapPins", GOLDGOAL = "GoldGoal", ITEMFINDER = "ItemFinder", PROFESSIONGUIDE = "ProfessionGuide", GOLDGUIDE = "GoldGuide",
    DUNGEONS = "Dungeons", REPWATCH = "RepWatch", WEAPONSKILLWATCH = "WeaponSkillWatch", BUILDS = "Builds", SPELLREADY = "SpellReady",
    RAREWATCH = "RareWatch", LANDMARKS = "Landmarks", QUESTMOBS = "QuestMobs" }) do
    helper(key, source)
end
-- Window toggles answer nothing.
local windows = {}
SlashCmdList.LEVELLOG = function(arg) calls[#calls + 1] = "LEVELLOG:" .. arg; if arg == "window" then windows.levellog = not windows.levellog else ForeverHub_Receive("LevelLog", "log [" .. arg .. "]") end end
SlashCmdList.FOREVERHELPER = function(arg) calls[#calls + 1] = "FOREVERHELPER:" .. arg; if arg == "window" then windows.fh = not windows.fh else ForeverHub_Receive("ForeverHelper", "chars [" .. arg .. "]") end end
ForeverSkillProfessions = function() return { { name = "Tailoring" }, { name = "First Aid" } } end

local hub
do
    local n = #frames
    assert(loadfile(base .. "/ForeverHub/ForeverHub.lua"))("ForeverHub", {})
    hub = frames[n + 1]
end
hub.scripts.OnEvent(hub, "PLAYER_LOGIN")
for _, fn in ipairs(timers) do fn() end
timers = {}

local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
local function button(text)
    for _, f in ipairs(frames) do
        if f.kind == "Button" and f.text == text and f.shown then return f end
    end
end
local function click(text)
    local b = button(text)
    check(b ~= nil, "no button '" .. text .. "'")
    if b then b.scripts.OnClick(b, "LeftButton") end
    return b
end
local function body()
    -- The page text is the font string whose text was set last by the page; find it by content.
    local best
    for _, fs in ipairs(ALLFONTS) do
        if fs.text:find("says [", 1, true) or fs.text:find("log [", 1, true) or fs.text:find("chars [", 1, true) or fs.text:find("Search your bags", 1, true) then
            best = fs
        end
    end
    return best and best.text or ""
end
local function open(label)
    calls = {}
    click(label)
end

ForeverHubFrame:Show()
local function last() return calls[#calls] end
local function count(word)
    local n = 0
    for _, c in ipairs(calls) do if c == word then n = n + 1 end end
    return n
end
local function reopen()
    ForeverHubFrame:Hide()
    ForeverHubFrame:Show()
end

-- 1. Every new page opens on its helper's handler.
open("Legacy"); check(last() == "LEGACYPOINTS:", "legacy page: " .. tostring(last()))
click("This zone"); check(last() == "LEGACYPOINTS:zone", "legacy zone")
click("Finished"); check(last() == "LEGACYPOINTS:done", "legacy done")
open("Spell math"); check(last() == "SPELLMATH:", "spell math page: " .. tostring(last()))
open("Aggro"); check(last() == "AGGROWATCH:", "aggro page: " .. tostring(last()))
open("Events"); check(last() == "EVENTS:", "events page")
click("Holidays"); check(last() == "EVENTS:holidays", "events holidays")
click("All turn-ins"); check(last() == "EVENTS:turnins", "events turn-ins")
open("Gathering"); check(last() == "NODES:", "gathering page")
click("All zones"); check(last() == "NODES:all", "gathering all")
open("Map pins"); click("My notes"); check(last() == "MAPPINS:notes", "map notes")
open("Gold guide"); click("Darkmoon"); check(last() == "GOLDGUIDE:darkmoon", "darkmoon view")
open("Level log"); click("Game statistics"); check(last() == "LEVELLOG:stats", "statistics view")
open("Characters"); check(last() == "FOREVERHELPER:chars", "characters default")
click("Cooldowns"); check(last() == "FOREVERHELPER:cooldowns", "cooldowns view")

-- 2. Viewing pages is safe to redraw: a reopen shows the same view again.
reopen(); check(last() == "FOREVERHELPER:cooldowns", "reopen redraws the chosen view: " .. tostring(last()))

-- 3. Switches run once per click, never again on a reopen.
open("Gathering")
click("Herbs on/off")
check(count("NODES:toggle herbs") == 1, "herbs toggled once")
check(body():find("Nodes says [toggle herbs]", 1, true), "the switch's answer is shown:\n" .. body())
reopen()
check(count("NODES:toggle herbs") == 1, "reopening the hub flipped the herb layer again: " .. count("NODES:toggle herbs"))
reopen()
check(count("NODES:toggle herbs") == 1, "second reopen: " .. count("NODES:toggle herbs"))
click("Ore on/off"); click("Fishing on/off")
reopen()
check(count("NODES:toggle ore") == 1 and count("NODES:toggle fishing") == 1, "ore/fishing toggled once each")
open("Spell math")
click("Tooltip line off")
check(count("SPELLMATH:tooltip off") == 1, "tooltip off once")
reopen()
check(count("SPELLMATH:tooltip off") == 1, "reopen re-ran tooltip off: " .. count("SPELLMATH:tooltip off"))

check(#handled == 0, "errors: " .. table.concat(handled, "\n"))
if #failures > 0 then
    realPrint("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do realPrint(" - " .. why) end
    os.exit(1)
end
realPrint("test_full_hub_views: all checks passed")