-- Final review: every page or window a helper opens only by a typed word has a button in the hub window.
-- GoldGoal sources/sales, ItemFinder expiring, ProfessionGuide craft/shopping/<profession>, LevelLog's
-- window, ForeverHelper's window, QuestMobs' list window, and the other keyword views.
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
for key, source in pairs({ GOLDGOAL = "GoldGoal", ITEMFINDER = "ItemFinder", PROFESSIONGUIDE = "ProfessionGuide", GOLDGUIDE = "GoldGuide",
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

-- 1. Gold goal: Money sources and Auction sales buttons.
open("Gold goal")
check(body():find("GoldGoal says []", 1, true), "gold goal default page:\n" .. body())
click("Money sources")
check(calls[#calls] == "GOLDGOAL:sources", "sources asked: " .. tostring(calls[#calls]))
check(body():find("GoldGoal says [sources]", 1, true), "sources shown:\n" .. body())
check(button("Money sources").locked and not button("Goal").locked, "selected view lit")
click("Auction sales")
check(calls[#calls] == "GOLDGOAL:sales", "sales asked: " .. tostring(calls[#calls]))
-- A new page starts at its first view again.
open("Gold guide")
check(not button("Money sources"), "gold goal buttons gone on another page")
check(button("Best farms") and button("Best farms").locked, "default view lit")
click("All farms"); check(calls[#calls] == "GOLDGUIDE:all", "gold guide all")
click("Tips"); check(calls[#calls] == "GOLDGUIDE:tips", "gold guide tips")
open("Gold goal")
check(calls[#calls] == "GOLDGOAL:", "gold goal back to its default: " .. tostring(calls[#calls]))

-- 2. Find an item: mail expiry, and a search still works after it.
open("Find an item")
check(body():find("Search your bags", 1, true), "search page shows its hint first")
click("Mail expiry")
check(calls[#calls] == "ITEMFINDER:expiring", "expiring asked: " .. tostring(calls[#calls]))
check(body():find("ItemFinder says [expiring]", 1, true), "expiring shown")

-- 3. Profession guide: craft, shopping and one button per profession you have.
open("Profession guide")
click("Craft now"); check(calls[#calls] == "PROFESSIONGUIDE:craft", "craft asked")
click("Shopping list"); check(calls[#calls] == "PROFESSIONGUIDE:shopping", "shopping asked")
click("Tailoring"); check(calls[#calls] == "PROFESSIONGUIDE:tailoring", "tailoring guide asked: " .. tostring(calls[#calls]))
click("First Aid"); check(calls[#calls] == "PROFESSIONGUIDE:first aid", "first aid guide asked")

-- 4. Level log: its window opens from a button; the page stays.
open("Level log")
check(calls[#calls] == "LEVELLOG:all", "level log page")
click("Open window")
check(windows.levellog == true, "level log window opened")
check(body():find("log [all]", 1, true), "page still shown after the window opened:\n" .. body())

-- 5. Characters: ForeverHelper's own window.
open("Characters")
click("Own window")
check(windows.fh == true, "ForeverHelper window opened")
check(body():find("chars [chars]", 1, true), "characters page still shown")

-- 6. Quest mobs list window, Reputation session view, Weapon skills, Builds, Ready check, Rares, Dungeons, Places.
open("Quest mobs"); click("List window"); check(calls[#calls] == "QUESTMOBS:list", "quest mobs list")
open("Reputation")
check(calls[#calls] == "REPWATCH:all" and button("All factions").locked, "reputation default is all")
click("This session"); check(calls[#calls] == "REPWATCH:", "reputation session view: " .. tostring(calls[#calls]))
open("Weapon skills"); click("Equipped"); check(calls[#calls] == "WEAPONSKILLWATCH:", "equipped weapon skills")
open("Builds"); click("All goals"); check(calls[#calls] == "BUILDS:all", "builds all")
click("PvP"); check(calls[#calls] == "BUILDS:pvp", "builds pvp")
open("Ready check"); click("Ignored spells"); check(calls[#calls] == "SPELLREADY:ignored", "ignored spells")
open("Rares"); click("All rares"); check(calls[#calls] == "RAREWATCH:all", "all rares")
open("Dungeons"); click("All dungeons"); check(calls[#calls] == "DUNGEONS:all", "all dungeons")
open("Places"); click("Nearest repair"); check(calls[#calls] == "LANDMARKS:repair", "pin nearest repair")
check(body():find("Landmarks says [repair]", 1, true), "pin answer shown")

-- 7. Pages without views show no view buttons.
open("Home")
check(not button("Nearest repair") and not button("All dungeons"), "no view buttons on Home")

check(#handled == 0, "errors: " .. table.concat(handled, "\n"))
if #failures > 0 then
    realPrint("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do realPrint(" - " .. why) end
    os.exit(1)
end
realPrint("test_final_hub_views: all checks passed")
