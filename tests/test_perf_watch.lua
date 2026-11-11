-- Perf audit (research\perf_audit.md) fixes that change how often work runs, checked for unchanged behaviour:
-- 1. ItemAdvisor's 4 Hz bag watcher walks the bag frames without building a list, and still repaints once
--    when a bag window opens (separate bags and combined bags), not again while it stays open.
-- 2. RareWatch hears UNIT_HEALTH for the target only (a unit event), with RegisterEvent kept as a fallback.
-- Run from the harness folder:  node run.js "<workspace root>" test_perf_watch.lua
local base = ADDON_PATH
local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end

---------------------------------------------------------------------------- 1. ItemAdvisor bag watcher
local timers, handled = {}, {}
local function newRegion()
    local r = { shown = true, scripts = {}, hooks = {} }
    function r:Hide() self.shown = false end
    function r:Show() self.shown = true end
    function r:SetShown(v) self.shown = v and true or false end
    function r:IsShown() return self.shown end
    function r:IsVisible() return self.shown end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:HookScript(s, f) self.hooks[s] = f end
    function r:CreateTexture() return newRegion() end
    function r:CreateFontString() return newRegion() end
    return setmetatable(r, { __index = function() return function() end end })
end
local allFrames = {}
CreateFrame = function(_, name) local f = newRegion(); allFrames[#allFrames + 1] = f; if name then _G[name] = f end; return f end
SlashCmdList = {}
Enum = { TooltipDataType = { Item = 0 } }
GameTooltip = { AddLine = function() end }
ItemRefTooltip = {}
TooltipDataProcessor = { AddTooltipPostCall = function() end }
issecretvalue = function() return false end
UnitClass = function() return "WARRIOR", "WARRIOR" end
UnitName = function() return "T" end
GetRealmName = function() return "R" end
UnitLevel = function() return 30 end
InCombatLockdown = function() return false end
GetInventoryItemLink = function() return nil end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
ForeverHub_Receive = function() end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function flush() while #timers > 0 do table.remove(timers, 1)() end end
C_Item = { GetItemInfo = function() return nil end, GetItemStats = function() return nil end, RequestLoadItemDataByID = function() end }
C_TooltipInfo = { GetHyperlink = function() return { lines = {} } end }
C_QuestLog = { GetNumQuestLogEntries = function() return 0 end }
C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = function() return nil end }
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0

local backpack, combined = newRegion(), newRegion()
backpack.Items, combined.Items = {}, {}
backpack.shown, combined.shown = false, false
ContainerFrameContainer = { ContainerFrames = { backpack } }
ContainerFrameCombinedBags = combined

assert(loadfile(base .. "/ItemAdvisor/ItemAdvisor.lua"))("ItemAdvisor", {})
local events
for _, f in ipairs(allFrames) do if f.scripts.OnEvent then events = f end end
events.scripts.OnEvent(events, "PLAYER_LOGIN")
flush()
local watch = ItemAdvisorOverlay and ItemAdvisorOverlay.scripts.OnUpdate
check(type(watch) == "function", "the overlay watches bag frames after login")
if watch then
    local function tick() watch(ItemAdvisorOverlay, 0.3) end
    tick(); flush()
    tick()
    check(#timers == 0, "no repaint while every bag is closed")
    backpack.shown = true
    tick()
    check(#timers == 1, "opening a bag schedules one repaint, got " .. #timers)
    flush()
    tick()
    check(#timers == 0, "no new repaint while the bag stays open")
    backpack.shown = false
    tick(); flush()
    combined.shown = true
    tick()
    check(#timers == 1, "opening the combined bags schedules one repaint, got " .. #timers)
    flush()
    -- The watcher ran a few times a second for the whole session; it must not stop on a missing container list.
    ContainerFrameContainer = nil
    local ok, err = pcall(tick)
    check(ok, "no bag container list: " .. tostring(err))
end
check(#handled == 0, "ItemAdvisor clean: " .. tostring(handled[1]))

---------------------------------------------------------------------------- 2. RareWatch UNIT_HEALTH
local function LoadRareWatch(withUnitEvents)
    local made = {}
    CreateFrame = function()
        local f = { registered = {}, unitEvents = {} }
        f.RegisterEvent = function(self, e) self.registered[e] = true end
        if withUnitEvents then
            f.RegisterUnitEvent = function(self, e, ...) self.unitEvents[e] = { ... } end
        end
        f.SetScript = function(self, _, fn) self.fn = fn end
        made[#made + 1] = f
        return f
    end
    SlashCmdList = {}
    ForeverHubStatus = {}
    assert(loadfile(base .. "/RareWatch/RareWatch.lua"))("RareWatch", {})
    for _, f in ipairs(made) do
        if f.registered.VIGNETTES_UPDATED then
            return f
        end
    end
end
local f = LoadRareWatch(true)
check(f ~= nil, "RareWatch event frame found")
if f then
    local units = f.unitEvents.UNIT_HEALTH
    check(units and units[1] == "target" and units[2] == nil, "UNIT_HEALTH is a unit event for the target only")
    check(not f.registered.UNIT_HEALTH, "UNIT_HEALTH not registered for every unit")
    check(f.registered.NAME_PLATE_UNIT_ADDED and f.registered.UPDATE_MOUSEOVER_UNIT, "other unit events still registered")
end
f = LoadRareWatch(false)
check(f and f.registered.UNIT_HEALTH, "fallback: RegisterEvent when the client has no RegisterUnitEvent")

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, failure in ipairs(failures) do
        print("  " .. failure)
    end
    error("test_perf_watch failed")
end
print("test_perf_watch: all checks passed")
