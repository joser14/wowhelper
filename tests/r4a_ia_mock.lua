-- Shared harness for the round-4 ItemAdvisor tests (test_r4a_ia_*.lua). Not a test itself: runall only runs
-- test*.lua. Built from test_itemadvisor_review.lua's mocks, plus equipment sets, bag slots and quest rewards.
-- Usage: local M = dofile(ADDON_PATH .. "/tests/r4a_ia_mock.lua"); M.load("WARRIOR")
local M = { items = {}, stats = {}, tips = {}, equipped = {}, bag = {}, toasts = {}, handled = {}, timers = {} }
M.sets = {}      -- [setID] = { [slot] = itemID }
M.setSlots = {}  -- ["bag:slot"] = true when that bag slot is in a set
M.rewards = {}   -- { { link = ..., count = n } } for the open quest window

function M.def(id, t, suffix)
    local link = "|Hitem:" .. id .. "::::::" .. (suffix or "") .. ":::|h[" .. t.name .. "]|h"
    M.items[link], M.stats[link], M.tips[link] = t, t.stats, t.tip
    return link
end

local function newRegion()
    local r = { shown = true, scripts = {} }
    function r:Hide() self.shown = false end
    function r:Show() self.shown = true end
    function r:SetShown(v) self.shown = v and true or false end
    function r:IsShown() return self.shown end
    function r:IsVisible() return self.shown end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:CreateTexture() return newRegion() end
    function r:CreateFontString() return newRegion() end
    return setmetatable(r, { __index = function() return function() end end })
end
M.newRegion = newRegion
M.allFrames = {}
CreateFrame = function(_, name) local f = newRegion(); M.allFrames[#M.allFrames + 1] = f; if name then _G[name] = f end; return f end
SlashCmdList = {}
Enum = { TooltipDataType = { Item = 0 } }
local tipLines = {}
GameTooltip = { AddLine = function(_, text) tipLines[#tipLines + 1] = text end, GetProcessingTooltipInfo = function() end }
ItemRefTooltip = {}
local shownLink
TooltipUtil = { GetDisplayedItem = function() return "n", shownLink end }
local postCall
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) postCall = fn end }
issecretvalue = function() return false end
M.class = "WARRIOR"
UnitClass = function() return M.class, M.class end
UnitName = function() return "T" end
GetRealmName = function() return "R" end
M.level = 30
UnitLevel = function() return M.level end
InCombatLockdown = function() return false end
GetInventoryItemLink = function(_, slot) return M.equipped[slot] end
geterrorhandler = function() return function(e) M.handled[#M.handled + 1] = tostring(e) end end
ForeverHub_Receive = function(_, text) M.toasts[#M.toasts + 1] = text end
C_Timer = { After = function(_, fn) M.timers[#M.timers + 1] = fn end }
function M.flush()
    local guard = 0
    while #M.timers > 0 and guard < 200 do
        guard = guard + 1
        table.remove(M.timers, 1)()
    end
end
C_Item = {
    GetItemInfo = function(link)
        local t = M.items[link]
        if not t then return nil end
        return t.name, link, t.q or 2, 20, t.minLevel or 1, "", "", 1, t.loc or "", 0, t.price or 0, t.c or 4, t.s or 0, t.bind or 2
    end,
    GetItemStats = function(link) return M.stats[link] end,
    RequestLoadItemDataByID = function() end,
}
C_TooltipInfo = { GetHyperlink = function(link)
    local lines = { { leftText = "name" } }
    for _, text in ipairs(M.tips[link] or {}) do lines[#lines + 1] = { leftText = text } end
    return { lines = lines }
end }
C_QuestLog = { GetNumQuestLogEntries = function() return 0 end }
C_Container = {
    GetContainerNumSlots = function(b) return b == 0 and 8 or 0 end,
    GetContainerItemInfo = function(b, slot)
        local link = b == 0 and M.bag[slot]
        return link and { hyperlink = link, isBound = false, stackCount = 1 } or nil
    end,
    GetContainerItemEquipmentSetInfo = function(b, slot)
        if M.setSlots[b .. ":" .. slot] then return true, "Main" end
        return false, ""
    end,
}
C_EquipmentSet = {
    GetEquipmentSetIDs = function() local ids = {}; for id in pairs(M.sets) do ids[#ids + 1] = id end; return ids end,
    GetItemIDs = function(id) return M.sets[id] end,
}
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0

-- Quest reward window.
GetNumQuestChoices = function() return #M.rewards end
GetQuestItemLink = function(_, i) return M.rewards[i] and M.rewards[i].link end
GetQuestItemInfo = function(_, i) local r = M.rewards[i]; return r and M.items[r.link].name, 0, r and r.count or 1 end
M.rewardButtons = {}
for i = 1, 6 do
    local b = newRegion()
    b.type = "choice"
    b.GetID = function() return i end
    M.rewardButtons[i] = b
end
QuestInfoRewardsFrame = { RewardButtons = M.rewardButtons }

local events
function M.load(class)
    M.class = class or M.class
    assert(loadfile(ADDON_PATH .. "/ItemAdvisor/ItemAdvisor.lua"))("ItemAdvisor", {})
    for _, f in ipairs(M.allFrames) do if f.scripts.OnEvent and f ~= ItemAdvisorOverlay then events = f end end
    M.event("PLAYER_LOGIN")
end
function M.event(...) events.scripts.OnEvent(events, ...) end
function M.login(class) M.class = class; M.event("PLAYER_LOGIN") end

function M.ask(link)
    tipLines, shownLink = {}, link
    postCall(GameTooltip)
    return tipLines[1] or ""
end
function M.want(link, text, why)
    local got = M.ask(link)
    assert(got:find(text, 1, true), why .. ": wanted '" .. text .. "', got: " .. got)
end
function M.wantNot(link, text, why)
    local got = M.ask(link)
    assert(not got:find(text, 1, true), why .. ": got: " .. got)
end
function M.slash(text)
    M.toasts = {}
    SlashCmdList.ITEMADVISOR(text)
    return table.concat(M.toasts, "\n")
end

-- The reward marks ItemAdvisor drew: { [choiceIndex] = { best = bool, coin = bool } } for shown marks.
function M.rewardMarks()
    local out = {}
    for _, f in ipairs(M.allFrames) do
        local button = rawget(f, "button")
        if button and rawget(f, "coin") and f.shown then
            out[button:GetID()] = { best = f.glow.shown, coin = f.coin.shown }
        end
    end
    return out
end

return M
