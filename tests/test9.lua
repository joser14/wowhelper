local base = ADDON_PATH
local chat, timers, frames, errorsShown, handled = {}, {}, {}, {}, {}
ALLFONTS = {}
local function newRegion(kind, name)
    local r = { kind = kind, name = name, shown = true, scripts = {}, text = "" }
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function r:Hide() self.shown = false end
    function r:SetShown(v) if v then self:Show() else self:Hide() end end
    function r:IsShown() return self.shown end
    function r:GetStringHeight() return 14 end
    function r:GetHeight() return 100 end
    function r:GetVerticalScroll() return self.scrollPos or 0 end
    function r:SetVerticalScroll(v) self.scrollPos = v end
    r.registered = {}
    function r:RegisterEvent(e) self.registered[e] = true end
    function r:CreateFontString() local fs = newRegion("font"); ALLFONTS[#ALLFONTS + 1] = fs; return fs end
    function r:CreateTexture() return newRegion("texture") end
    function r:GetPoint() return "CENTER", nil, "CENTER", 1, 2 end
    return setmetatable(r, { __index = function(t, k)
        if k == "page" or k == "link" then return nil end
        return function() end
    end })
end
CreateFrame = function(kind, name)
    local f = newRegion(kind, name)
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
UIErrorsFrame = { AddMessage = function(_, t) errorsShown[#errorsShown + 1] = t end }
UIParent = newRegion("Frame"); Minimap = newRegion("Frame"); GameTooltip = newRegion("Frame")
UISpecialFrames = {}
SlashCmdList = {}
local now, tick = 1000, nil
GetTime = function() return now end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function(_, fn) tick = fn end }
issecretvalue = function() return false end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
local log = { { questID = 1, title = "Done", level = 2, suggestedGroup = 0 } }
C_QuestLog = {
    GetNumQuestLogEntries = function() return #log, 23 end, GetMaxNumQuestsCanAccept = function() return 25 end,
    GetInfo = function(i) return log[i] end, IsComplete = function(id) return id == 1 end,
    ReadyForTurnIn = function() return false end, IsQuestTrivial = function() return false end,
}
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
local bag = { { hyperlink = "|Hitem:159|h[Refreshing Spring Water]|h" } }
C_Container = { GetContainerNumSlots = function() return #bag end, GetContainerItemInfo = function(_, i) return bag[i] end,
    GetContainerNumFreeSlots = function() return 2, 0 end }
C_Item = { GetItemCount = function() return 1 end }
C_CVar = { SetCVar = function(n, v) if n == "accessibilityScreenNarrationEnabled" then NARRATION = v end end }
UnitName = function() return "T" end
GetRealmName = function() return "R" end
UnitUsesAmmo = function() return false end
local level, xp, money, rested = 5, 500, 12345, 200
UnitLevel = function() return level end
UnitXP = function() return xp end
UnitXPMax = function() return 1000 end
GetXPExhaustion = function() return rested end
GetMoney = function() return money end

local function load(name)
    local n = #frames
    assert(loadfile(base .. "/" .. name .. "/" .. name .. ".lua"))(name, {})
    return frames[n + 1]
end
local qc = load("QuestCheck")
local sw = load("SupplyWatch")
local bc = load("BagCheck")
local hub = load("ForeverHub")
assert(ForeverHub_Receive, "hub sets its receiver at load")
ForeverHub_Receive("Early", "before login")
assert(#chat == 0, "early message held, not in chat")
sw.scripts.OnEvent(sw, "PLAYER_LOGIN")
hub.scripts.OnEvent(hub, "PLAYER_LOGIN")

local function fonts()
    local out = {}
    for _, fs in ipairs(ALLFONTS) do out[#out + 1] = tostring(fs.text) end
    return table.concat(out, "\n")
end
local function has(text) return fonts():find(text, 1, true) ~= nil end
local function rowTexts()
    local out = {}
    for _, f in ipairs(frames) do
        if f.kind == "Button" and f.shown and rawget(f, "page") then out[#out + 1] = f.text end
    end
    return table.concat(out, "\n")
end
local function row(text)
    for _, f in ipairs(frames) do
        if f.kind == "Button" and rawget(f, "page") and f.text:find(text, 1, true) then return f end
    end
end
assert(has("before login"), "held message shown as a pop-up after login")
assert(NARRATION == "0", "narration off")
assert(ForeverHubPanel.shown, "panel opens on its own")
assert(not ForeverHubFrame.shown, "details window stays out of the way")
for _, name in ipairs(UISpecialFrames) do assert(name ~= "ForeverHubPanel", "Esc and the game's window closing don't hide the panel") end
assert(has("Level 5  |cffffd10050%|r"), "level and progress: " .. fonts())
assert(has("Rested 20%"), "rested")
assert(has("1g 23s"), "gold")

-- The panel lists what needs doing, and only that.
assert(rowTexts():find("Turn in", 1, true), "turn-ins listed: " .. rowTexts())
assert(rowTexts():find("Quest log", 1, true), "log full listed")
assert(rowTexts():find("Bags", 1, true), "bags listed")
-- Clicking a line opens its details.
local line = row("Turn in")
line.scripts.OnClick(line)
assert(ForeverHubFrame.shown, "row opens details")
assert(has("23/25 quests"), "right page")
ForeverHubFrame:Hide()
-- Fixed problems leave the panel, and it refreshes by itself.
C_Container.GetContainerNumFreeSlots = function() return 20, 0 end
bc.scripts.OnEvent(bc, "BAG_UPDATE_DELAYED")
hub.scripts.OnEvent(hub, "BAG_UPDATE_DELAYED")
tick()
assert(not rowTexts():find("Bags", 1, true), "bags row gone: " .. rowTexts())
-- Rates fill in as you play.
now = now + 1800; xp = 750
hub.scripts.OnEvent(hub, "PLAYER_XP_UPDATE"); money = 22345; tick()
assert(has("Next level in 15m"), "eta uses the last 15 minutes: " .. fonts())
now = now + 1000; tick()
assert(has("appears once you earn XP"), "old XP stops counting: " .. fonts())
now = now + 100; xp = 800
hub.scripts.OnEvent(hub, "PLAYER_XP_UPDATE"); tick()
assert(has("/hr"), "gold rate")
-- Combat: no scanning until it ends.
InCombatLockdown = function() return true end
local calls = 0
local realQuest = ForeverHubStatus.QuestCheck
ForeverHubStatus.QuestCheck = function() calls = calls + 1; return realQuest() end
hub.scripts.OnEvent(hub, "BAG_UPDATE_DELAYED"); tick()
assert(calls == 0, "skipped in combat")
InCombatLockdown = function() return false end
hub.scripts.OnEvent(hub, "PLAYER_REGEN_ENABLED"); tick()
assert(calls == 1, "catches up after combat")
ForeverHubStatus.QuestCheck = function() error("boom") end
hub.scripts.OnEvent(hub, "BAG_UPDATE_DELAYED"); tick()
assert(#handled >= 1, "a broken addon is reported, not fatal")
ForeverHubStatus.QuestCheck = realQuest

-- Warnings are pop-ups, not chat.
local before = #chat
qc.scripts.OnEvent(qc, "QUEST_LOG_UPDATE")
assert(#chat == before and #errorsShown == 0, "nothing in chat")
assert(has("Quest log nearly full"), "pop-up shown")
local n = #timers
ForeverHub_Receive("X", "same"); ForeverHub_Receive("X", "same")
assert(#timers == n + 1, "repeat suppressed")
for i = 1, 6 do ForeverHub_Receive("Y", "msg " .. i); now = now + 1 end
assert(has("msg 6"), "newest shown")

-- Typed commands open pages, including hidden ones.
SlashCmdList.QUESTCHECK("")
assert(ForeverHubFrame.shown and has("23/25 quests"), "command opens window")
assert(#chat == 0, "never in chat: " .. table.concat(chat, "|"))
SlashCmdList.FOREVERHUB(""); assert(not ForeverHubPanel.shown, "toggle off")
SlashCmdList.FOREVERHUB(""); assert(ForeverHubPanel.shown, "toggle on")

-- Sidebar.
local nav = {}
for _, f in ipairs(frames) do if f.kind == "Button" and f.text ~= "" and not rawget(f, "page") then nav[f.text] = f end end
assert(nav["Bag advice"] and nav.Errors and nav["Find an item"], "sidebar built")
assert(not nav.Repairs and not nav.Zone, "hidden pages take no sidebar space")
nav.Errors.scripts.OnClick(nav.Errors)
assert(has("isn't turned on"), "page for an addon that's off")
nav["Pop-up history"].scripts.OnClick(nav["Pop-up history"])
assert(has("X:"), "history")
local box
for _, f in ipairs(frames) do if f.kind == "EditBox" then box = f end end
nav.Supplies.scripts.OnClick(nav.Supplies)
box.scripts.OnEnterPressed({ GetText = function() return "water 20" end })
assert(SupplyWatchDB["T-R"].items[1].id == 159, "added from bag name")
tick()
assert(rowTexts():find("Buy", 1, true), "low supply on panel: " .. rowTexts())
box.scripts.OnEnterPressed({ GetText = function() return "nonsense 5" end })
assert(has("Couldn't find"), "unknown item explained")
box.scripts.OnEnterPressed({ GetText = function() return "justwords" end })
assert(has("Type an item name"), "bad format explained")
box.scripts.OnEnterPressed({ GetText = function() return "remove 1" end })
assert(#SupplyWatchDB["T-R"].items == 0, "remove passes through")
assert(#chat == 0, "still no chat: " .. table.concat(chat, "|"))
print("ALL TESTS PASSED")
