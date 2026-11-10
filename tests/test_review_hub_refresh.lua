-- Review fixes: the side panel re-reads status lines that change without an event the hub hears,
-- and BagCheck's junk pop-up isn't silenced by an ItemAdvisor that is switched off.
local base = ADDON_PATH
local timers, frames, handled = {}, {}, {}
local function newRegion(kind, name)
    local r = { kind = kind, name = name, shown = true, scripts = {}, text = "", height = 0 }
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
    function r:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
    function r:CreateFontString() return newRegion("font") end
    function r:CreateTexture() return newRegion("texture") end
    function r:GetFontString() self.fs = self.fs or newRegion("font"); return self.fs end
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
local now = 1000
GetTime = function() return now end
local tick
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function(_, fn) tick = fn end }
issecretvalue = function() return false end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
local inCombat = false
InCombatLockdown = function() return inCombat end
UnitLevel = function() return 10 end
UnitXP = function() return 100 end
UnitXPMax = function() return 1000 end
UnitName = function() return "Tester" end
GetXPExhaustion = function() return 0 end
GetMoney = function() return 100 end

-- A status line that comes and goes with no event at all (like DeathNotes when you walk away).
local nearDeath = true
ForeverHubStatus = { DeathNotes = function()
    if nearDeath then return { { text = "Danger: you died here", page = "Deaths" } } end
end }

local hub
do
    local n = #frames
    assert(loadfile(base .. "/ForeverHub/ForeverHub.lua"))("ForeverHub", {})
    hub = frames[n + 1]
end
hub.scripts.OnEvent(hub, "PLAYER_LOGIN")
for _, fn in ipairs(timers) do fn() end
timers = {}

local function rowShown(text)
    for _, f in ipairs(frames) do
        if f.kind == "Button" and f.shown and rawget(f, "fullText") and tostring(f.text):find(text, 1, true) then return true end
    end
    return false
end

assert(rowShown("Danger: you died here"), "row at login")
nearDeath = false
now = now + 1; tick()
assert(rowShown("Danger: you died here"), "not re-read every second")
now = now + 5; tick()
assert(not rowShown("Danger: you died here"), "re-read after a few seconds without any event")
-- Never in combat, even when due.
nearDeath = true
inCombat = true
now = now + 10; tick()
assert(not rowShown("Danger: you died here"), "no refresh in combat")
inCombat = false
tick()
assert(rowShown("Danger: you died here"), "refreshed once combat is over")
-- An event still refreshes on the next tick.
nearDeath = false
now = now + 1
hub.scripts.OnEvent(hub, "BAG_UPDATE_DELAYED"); tick()
assert(not rowShown("Danger: you died here"), "event refresh still immediate")
assert(#handled == 0, "no errors: " .. table.concat(handled, "|"))

----- BagCheck: the junk pop-up at a vendor.
local toasts = {}
ForeverHub_Receive = function(_, t) toasts[#toasts + 1] = t end
local off = {}
ForeverHub_IsOff = function(name) return off[name] == true end
local bagFrame
CreateFrame = function()
    bagFrame = { RegisterEvent = function() end, SetScript = function(self, _, fn) self.fn = fn end }
    return bagFrame
end
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
C_Container = {
    GetContainerNumSlots = function() return 1 end,
    GetContainerNumFreeSlots = function() return 10, 0 end,
    GetContainerItemInfo = function() return { quality = 0, stackCount = 3, itemID = 7 } end,
}
C_Item = {
    GetItemInfo = function() return "n", nil, nil, nil, nil, nil, nil, nil, nil, nil, 5 end,
    RequestLoadItemDataByID = function() end,
}
ForeverHubStatus = { ItemAdvisor = function() end }
assert(loadfile(base .. "/BagCheck/BagCheck.lua"))("BagCheck", {})
local function junkToast()
    for _, t in ipairs(toasts) do if t:find("junk item", 1, true) then return true end end
    return false
end
bagFrame.fn(bagFrame, "MERCHANT_SHOW")
assert(not junkToast(), "ItemAdvisor on: its own vendor pop-up covers junk")
off.ItemAdvisor = true
bagFrame.fn(bagFrame, "MERCHANT_SHOW")
assert(junkToast(), "ItemAdvisor switched off: BagCheck reports the junk itself")

print("ALL TESTS PASSED")
