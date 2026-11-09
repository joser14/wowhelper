-- Extra ForeverHub checks: toasts, pop-up history, panel row tooltips, search, gold rate.
local base = ADDON_PATH
local chat, timers, frames, handled = {}, {}, {}, {}
ALLFONTS = {}
local function newRegion(kind, name)
    local r = { kind = kind, name = name, shown = true, scripts = {}, text = "", height = 0, points = {} }
    function r:SetText(t) self.text = t; if self.fs then self.fs.text = t end end
    function r:GetText() return self.text end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function r:Hide() self.shown = false end
    function r:SetShown(v) if v then self:Show() else self:Hide() end end
    function r:IsShown() return self.shown end
    function r:GetStringHeight() return self.strHeight or 14 end
    function r:SetHeight(h) self.height = h end
    function r:GetHeight() return self.height end
    function r:ClearAllPoints() self.points = {} end
    function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function r:GetPoint() return "CENTER", nil, "CENTER", 1, 2 end
    function r:RegisterEvent() end
    function r:CreateFontString() local fs = newRegion("font"); ALLFONTS[#ALLFONTS + 1] = fs; return fs end
    function r:CreateTexture() return newRegion("texture") end
    function r:GetFontString()
        if not self.fs then self.fs = newRegion("font"); self.fs.text = self.text end
        return self.fs
    end
    function r:IsTruncated() return self.truncated == true end
    -- Methods are capitalised; any other missing key is plain data and reads as nil, like a real frame.
    return setmetatable(r, { __index = function(_, k)
        if type(k) == "string" and k:match("^%u") then return function() end end
    end })
end
local tipLines = {}
CreateFrame = function(kind, name)
    local f = newRegion(kind, name)
    frames[#frames + 1] = f
    if name then _G[name] = f end
    -- The hub's own tooltip records what it shows.
    if kind == "GameTooltip" then
        f.shown = false
        function f:SetOwner() tipLines = {} end
        function f:AddLine(t) tipLines[#tipLines + 1] = t end
        function f:SetHyperlink(link) if link == "bad" then error("Unknown link type") end; tipLines[#tipLines + 1] = link end
    end
    return f
end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
UIParent = newRegion("Frame"); Minimap = newRegion("Frame")
-- Blizzard's shared tooltip must never be written to.
GameTooltip = setmetatable({}, { __index = function(_, k) error("GameTooltip." .. tostring(k) .. " used") end })
UISpecialFrames = {}
SlashCmdList = {}
local now, tick = 1000, nil
GetTime = function() return now end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function(_, fn) tick = fn end }
local SECRET = {}
issecretvalue = function(v) return v == SECRET end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
local bag = { { hyperlink = "|Hitem:1|h[Watermelon]|h" }, { hyperlink = "|Hitem:2|h[Water]|h" } }
C_Container = { GetContainerNumSlots = function() return #bag end, GetContainerItemInfo = function(_, i) return bag[i] end }
C_CVar = { SetCVar = function() end }
local money = SECRET
UnitLevel = function() return 10 end
UnitXP = function() return 100 end
UnitXPMax = function() return 1000 end
GetXPExhaustion = function() return 0 end
GetMoney = function() return money end

-- Fake helpers, registered before login so the hub wraps them like the real ones.
local calls = { ITEMADVISOR = 0, QUESTCHECK = 0 }
local supplyArg
SlashCmdList.ITEMADVISOR = function() calls.ITEMADVISOR = calls.ITEMADVISOR + 1; ForeverHub_Receive("ItemAdvisor", "advice") end
SlashCmdList.QUESTCHECK = function() calls.QUESTCHECK = calls.QUESTCHECK + 1; ForeverHub_Receive("QuestCheck", "quests page") end
SlashCmdList.SUPPLYWATCH = function(arg) if arg ~= "" then supplyArg = arg end; ForeverHub_Receive("SupplyWatch", "supplies page") end
SlashCmdList.ITEMFINDER = function(arg) if arg == "sword" then ForeverHub_Receive("ItemFinder", "Sword: bags") end end
local statusItems = {}
ForeverHubStatus = { QuestCheck = function() return statusItems end }

local hub
do
    local n = #frames
    assert(loadfile(base .. "/ForeverHub/ForeverHub.lua"))("ForeverHub", {})
    hub = frames[n + 1]
end

-- Bad input from a helper is ignored rather than breaking the hub.
assert(pcall(ForeverHub_Receive, "X", nil), "nil text ignored")
assert(pcall(ForeverHub_Receive, "X", SECRET), "secret text ignored")
assert(pcall(ForeverHub_Receive, nil, "no source"), "nil source accepted")
hub.scripts.OnEvent(hub, "PLAYER_LOGIN")
assert(#handled == 0, "login clean: " .. table.concat(handled, "|"))

local function shownToasts()
    local list = {}
    for _, f in ipairs(frames) do
        if f.message and f.shown then list[#list + 1] = f end
    end
    table.sort(list, function(a, b) return a.points[1][5] > b.points[1][5] end)
    return list
end

-- Several messages in one frame: the 4th reuses the oldest pop-up, and the old timer must not hide it.
for _, f in ipairs(frames) do if f.message then f:Hide() end end
timers = {}
for i = 1, 4 do ForeverHub_Receive("T", "toast " .. i) end
local list = shownToasts()
assert(#list == 3, "three pop-ups at most: " .. #list)
for _, fn in ipairs(timers) do fn() break end
local stillThere = false
for _, f in ipairs(shownToasts()) do if f.message.text == "toast 4" then stillThere = true end end
assert(stillThere, "newest pop-up keeps its full time")

-- Stacking uses real heights, oldest on top, and stays below the leveling guide.
for _, f in ipairs(frames) do if f.message then f:Hide() end end
now = now + 100
ForeverHub_Receive("T", "short")
now = now + 1
for _, f in ipairs(frames) do if f.message then f.message.strHeight = 60 end end
ForeverHub_Receive("T", "a much longer message that wraps onto several lines")
for _, f in ipairs(frames) do if f.message then f.message.strHeight = 14 end end
now = now + 1
ForeverHub_Receive("T", "third")
list = shownToasts()
assert(list[1].message.text == "short" and list[3].message.text == "third", "oldest on top")
assert(list[1].points[1][5] == -170, "first pop-up below the guide: " .. list[1].points[1][5])
assert(list[2].points[1][5] == -170 - list[1].height - 8, "second under the first")
assert(list[3].points[1][5] == -170 - list[1].height - 8 - list[2].height - 8, "tall pop-up doesn't cover the next: " .. list[3].points[1][5])

-- History counts repeats and says when.
for i = 1, 3 do ForeverHub_Receive("Rep", "same thing"); now = now + 1 end
now = now + 300
local nav = {}
for _, f in ipairs(frames) do if f.kind == "Button" and f.text ~= "" then nav[f.text] = f end end
ForeverHubFrame:Show()
nav["Pop-up history"].scripts.OnClick(nav["Pop-up history"])
local function fonts()
    local out = {}
    for _, fs in ipairs(ALLFONTS) do out[#out + 1] = tostring(fs.text) end
    return table.concat(out, "\n")
end
local function has(text) return fonts():find(text, 1, true) ~= nil end
assert(has("Rep:|r same thing  |cff999999(3 times)|r  |cff6666665m ago|r"), "repeats counted with age: " .. fonts())
local count = 0
for _, fs in ipairs(ALLFONTS) do if tostring(fs.text):find("(3 times)", 1, true) then count = select(2, tostring(fs.text):gsub("same thing", "")) end end
assert(count == 1, "one history line for a repeat")

-- Opening a page from a closed window draws only that page.
ForeverHubFrame:Hide()
nav["Bag advice"].scripts.OnClick(nav["Bag advice"])
calls.ITEMADVISOR, calls.QUESTCHECK = 0, 0
statusItems = { { text = "Turn in 1 quest", page = "Quests" } }
hub.scripts.OnEvent(hub, "QUEST_LOG_UPDATE"); tick()
local function row(text)
    for _, f in ipairs(frames) do
        if f.kind == "Button" and f.fullText and f.shown and f.text:find(text, 1, true) then return f end
    end
end
local r = row("Turn in")
r.scripts.OnClick(r)
assert(ForeverHubFrame.shown and calls.QUESTCHECK == 1, "quests page drawn once")
assert(calls.ITEMADVISOR == 0, "old page not redrawn on open: " .. calls.ITEMADVISOR)
-- Typed command with an argument still opens the window with its answer.
ForeverHubFrame:Hide(); calls.QUESTCHECK = 0
SlashCmdList.QUESTCHECK("full")
assert(ForeverHubFrame.shown and calls.QUESTCHECK == 2, "command and page: " .. calls.QUESTCHECK)

-- Panel rows: long lines show in full on hover; bad links don't break anything.
r.fs.truncated = true
r.scripts.OnEnter(r)
assert(tipLines[1] == "Turn in 1 quest", "full text on hover")
r.fs.truncated = false; tipLines = {}
r.scripts.OnEnter(r)
assert(#tipLines == 0, "no tooltip for a line that fits")
statusItems = { { text = "Bad link row", page = "Quests", link = "bad" } }
hub.scripts.OnEvent(hub, "BAG_UPDATE_DELAYED"); tick()
r = row("Bad link")
assert(pcall(r.scripts.OnEnter, r), "bad link is harmless")

-- More than fits: the last row lists the rest on hover and opens Details.
statusItems = {}
for i = 1, 12 do statusItems[i] = { text = "Thing " .. i, page = "Quests" } end
hub.scripts.OnEvent(hub, "BAG_UPDATE_DELAYED"); tick()
r = row("3 more")
assert(r, "overflow row")
tipLines = {}
r.scripts.OnEnter(r)
assert(#tipLines == 3 and tipLines[1] == "Thing 10" and tipLines[3] == "Thing 12", "hidden rows listed: " .. table.concat(tipLines, ","))
ForeverHubFrame:Hide()
r.scripts.OnClick(r)
assert(ForeverHubFrame.shown, "overflow row opens Details")

-- Search: no results says so.
local box
for _, f in ipairs(frames) do if f.kind == "EditBox" then box = f end end
nav["Find an item"].scripts.OnClick(nav["Find an item"])
box.scripts.OnEnterPressed({ GetText = function() return "zzz" end })
assert(has('Nothing found for "zzz"'), "empty search explained")
box.scripts.OnEnterPressed({ GetText = function() return "sword" end })
assert(has("Sword: bags"), "search results shown")

-- Supplies: an exact name beats an earlier partial match.
nav.Supplies.scripts.OnClick(nav.Supplies)
box.scripts.OnEnterPressed({ GetText = function() return "water 5" end })
assert(supplyArg == "add |Hitem:2|h[Water]|h 5", "exact name chosen: " .. tostring(supplyArg))
box.scripts.OnEnterPressed({ GetText = function() return "melon 5" end })
assert(supplyArg == "add |Hitem:1|h[Watermelon]|h 5", "partial still works: " .. tostring(supplyArg))

-- Gold: hidden at login, counted once readable, rate only after ten minutes.
money = 10000; tick()
assert(has("1g 0s") and not has("/hr"), "gold shown once readable: " .. fonts())
money = 20000; now = now + 120; tick()
assert(not has("/hr"), "no rate from a couple of minutes")
now = now + 600; tick()
assert(has("+5g 0s/hr"), "rate after ten minutes: " .. fonts())

assert(#chat == 0, "no chat")
assert(#handled == 0, "no errors: " .. table.concat(handled, "|"))
print("ALL TESTS PASSED")
