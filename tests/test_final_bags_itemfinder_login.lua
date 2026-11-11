-- Final review (bags): ItemFinder's login pass over saved characters must survive a saved entry that isn't a
-- character record (a number or boolean left by an old version or a hand-edited file). Every other reader of
-- ItemFinderDB already skips such entries; the mail clean-up at login indexed it and stopped the login step,
-- so the tooltip line was never registered and bags were never saved.
-- Run from the harness folder:  node run.js "<workspace root>" test_final_bags_itemfinder_login.lua
local failures, frames = {}, {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
issecretvalue = function() return false end
ForeverHub_Receive = function() end
CreateFrame = function()
    local f = {}
    function f:RegisterEvent() end
    function f:SetScript(_, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
C_Timer = { After = function() end }
SlashCmdList = {}
time = function() return 1000000 end
UnitName = function(u) if u == "player" then return "Juan" end end
UnitGUID = function(u) if u == "player" then return "Player-1-0001" end end
GetRealmName = function() return "R" end
UnitFactionGroup = function() return "Alliance" end
Enum = { BagIndex = { Backpack = 0 }, TooltipDataType = { Item = 0 } }
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
local bagScans = 0
C_Container = { GetContainerNumSlots = function() bagScans = bagScans + 1; return 0 end, GetContainerItemInfo = function() end }
GetInventoryItemLink = function() end
local registered = false
TooltipDataProcessor = { AddTooltipPostCall = function() registered = true end }
TooltipUtil = { GetDisplayedItem = function() end }

ItemFinderDB = { stray = 42, flag = true, ["Player-1-0002"] = { charName = "Alt", lastSeen = 1000000 } }
assert(loadfile(ADDON_PATH .. "/ItemFinder/ItemFinder.lua"))("ItemFinder", {})
local ev = frames[#frames]
local ok, err = pcall(ev.fn, ev, "PLAYER_LOGIN")
check(ok, "login survives non-record entries: " .. tostring(err))
check(registered, "the tooltip line is registered")
check(bagScans > 0, "bags are saved at login")
check(type(ItemFinderDB["Player-1-0001"]) == "table", "this character's record exists")

if #failures > 0 then
    error(table.concat(failures, "\n"))
end
print("test_final_bags_itemfinder_login: all passed")
