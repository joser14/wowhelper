-- Full review (bags): ItemFinder switched Off on the hub's Manage page. The owner's rule (test_off_hides_frames.lua,
-- research\xreview_ui.md) is that a helper switched Off hides its own frames and adds nothing; the round 5 bag view
-- (ItemFinderBagView) came later and stayed open, could still be opened, and the "Owned:" tooltip line (only used
-- without the Tooltips helper) kept coming. Saving bags, bank and mail goes on, as for every other helper.
-- Run from the tests folder:  node run.js "<repo root>" test_full_bags_itemfinder_off.lua
local out, failures, frames = {}, {}, {}
local realPrint = print
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
issecretvalue = function() return false end
ForeverHub_Receive = function(_, text) out[#out + 1] = text end
local off = false
ForeverHub_IsOff = function(name) return name == "ItemFinder" and off end
ForeverHubOnSwitch = {}

local function newObject(kind, parent)
    local o = { kind = kind, parent = parent, shown = true, scripts = {}, events = {}, lines = {} }
    function o:RegisterEvent(e) self.events[e] = true end
    function o:SetScript(s, fn) self.scripts[s] = fn; self.fn = s == "OnEvent" and fn or self.fn end
    function o:Show() self.shown = true end
    function o:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
    function o:IsShown() return self.shown end
    function o:SetText(t) self.text = t end
    function o:GetText() return self.text end
    function o:CreateTexture() return newObject("Texture", self) end
    function o:CreateFontString() return newObject("FontString", self) end
    function o:AddLine(t) self.lines[#self.lines + 1] = t end
    return setmetatable(o, { __index = function(_, k) if type(k) == "string" and k:match("^%u") then return function() end end end })
end
CreateFrame = function(kind, name, parent, template)
    local f = newObject(kind, parent)
    f.name, f.template = name, template
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
UIParent = newObject("UIParent")
GameTooltip = newObject("GameTooltip")
C_Timer = { After = function(_, fn) fn() end }
SlashCmdList = {}
local clock = 1000000
time = function() return clock end
UnitName = function(u) if u == "player" then return "Juan", "Rivera" end end
UnitGUID = function(u) if u == "player" then return "Player-1-0001" end end
GetRealmName = function() return "R" end
UnitFactionGroup = function() return "Alliance" end
Enum = { BagIndex = { Backpack = 0 }, TooltipDataType = { Item = 0 } }
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
C_Container = { GetContainerNumSlots = function() return 1 end,
    GetContainerItemInfo = function(b, s) if b == 0 and s == 1 then return { hyperlink = "|Hitem:2589::|h[Linen Cloth]|h", stackCount = 4 } end end }
GetInventoryItemLink = function() end
C_Item = { GetItemIconByID = function() return 1 end, GetItemQualityByID = function() return 1 end }
local postCall
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) postCall = fn end }
TooltipUtil = { GetDisplayedItem = function() return "Linen Cloth", "|Hitem:2589::|h[Linen Cloth]|h", 2589 end }
-- An alt holding the same item, so the tooltip line has something to say.
ItemFinderDB = { ["Player-1-0002"] = { charName = "Alt Two", lastSeen = clock, items = { bank = { [2589] = 40 } }, names = { [2589] = "Linen Cloth" } } }

assert(loadfile(ADDON_PATH .. "/ItemFinder/ItemFinder.lua"))("ItemFinder", {})
local ev
for _, f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev = f end end
ev.fn(ev, "PLAYER_LOGIN")

----- On: the bag view opens and the tooltip line is there
check(ItemFinder_ShowBags() == true and ItemFinderBagView.shown, "On: the bag view opens")
check(type(postCall) == "function", "without Tooltips, ItemFinder adds its own tooltip line")
GameTooltip.lines = {}
postCall(GameTooltip)
check(#GameTooltip.lines == 1 and GameTooltip.lines[1]:find("^Owned: "), "On: tooltip line: " .. table.concat(GameTooltip.lines, "|"))

----- Switched Off on the hub: the open window closes, can't be opened, no tooltip line
off = true
check(type(ForeverHubOnSwitch.ItemFinder) == "function", "ItemFinder follows the hub's Off switch")
if type(ForeverHubOnSwitch.ItemFinder) == "function" then ForeverHubOnSwitch.ItemFinder(true) end
check(not ItemFinderBagView.shown, "Off: the open bag view closes")
check(not ItemFinder_ShowBags() and not ItemFinderBagView.shown, "Off: the bag view doesn't open")
SlashCmdList.ITEMFINDER("bags")
check(not ItemFinderBagView.shown, "Off: /find bags doesn't open it either")
GameTooltip.lines = {}
postCall(GameTooltip)
check(#GameTooltip.lines == 0, "Off: no tooltip line: " .. table.concat(GameTooltip.lines, "|"))
-- Data is still saved while Off (as for every helper), so switching On shows current bags.
ev.fn(ev, "BAG_UPDATE_DELAYED")
check(ItemFinderDB["Player-1-0001"].items.bags[2589] == 4, "Off: bags still saved")

----- On again
off = false
if type(ForeverHubOnSwitch.ItemFinder) == "function" then ForeverHubOnSwitch.ItemFinder(false) end
check(ItemFinder_ShowBags() == true and ItemFinderBagView.shown, "On again: opens")
GameTooltip.lines = {}
postCall(GameTooltip)
check(#GameTooltip.lines == 1, "On again: tooltip line back")

if #failures > 0 then
    realPrint("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do realPrint(" - " .. why) end
    os.exit(1)
end
realPrint("test_full_bags_itemfinder_off: all checks passed")
