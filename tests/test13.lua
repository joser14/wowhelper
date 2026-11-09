local base = ADDON_PATH
local toasts, sounds = {}, 0
ForeverHub_Receive = function(_, t) toasts[#toasts + 1] = t end
issecretvalue = function() return false end
local eventFrame
CreateFrame = function()
    eventFrame = { RegisterEvent = function() end, SetScript = function(self, _, fn) self.fn = fn end }
    return eventFrame
end
SlashCmdList = {}
UnitName = function() return "Lean" end
GetRealmName = function() return "R" end
local now = 1000
GetTime = function() return now end
local function load(name)
    assert(loadfile(base .. "/" .. name .. "/" .. name .. ".lua"))(name, {})
    return eventFrame
end

----- RareWatch
SOUNDKIT = { RAID_WARNING = 1 }
PlaySound = function() sounds = sounds + 1 end
local markers = {}
C_VignetteInfo = {
    GetVignetteInfo = function(g) return markers[g] end,
    GetVignettes = function() local l = {}; for g in pairs(markers) do l[#l + 1] = g end; return l end,
}
local rw = load("RareWatch")
rw.fn(rw, "PLAYER_ENTERING_WORLD")
assert(#ForeverHubStatus.RareWatch() == 0, "nothing yet")
markers.a = { name = "Old Vicejaw", atlasName = "VignetteKillElite", onMinimap = true }
rw.fn(rw, "VIGNETTE_MINIMAP_UPDATED", "a", true)
assert(#toasts == 1 and toasts[1]:find("Old Vicejaw", 1, true) and sounds == 1, "rare pop-up and sound")
assert(ForeverHubStatus.RareWatch()[1].text:find("Rare|r Old Vicejaw", 1, true), "hub row")
-- The same rare doesn't repeat, even under a new marker.
markers.b = { name = "Old Vicejaw", atlasName = "VignetteKill", onMinimap = true }
rw.fn(rw, "VIGNETTES_UPDATED")
assert(#toasts == 1 and sounds == 1, "no repeat")
now = now + 400
markers.b = nil
markers.a = nil
rw.fn(rw, "VIGNETTES_UPDATED")
assert(#ForeverHubStatus.RareWatch() == 0, "gone from the minimap, gone from the hub")
markers.c = { name = "Old Vicejaw", atlasName = "VignetteKill", onMinimap = true }
rw.fn(rw, "VIGNETTE_MINIMAP_UPDATED", "c", true)
assert(#toasts == 2, "respawn later announces again")
-- Dead rares and left-behind markers clear.
markers.c.isDead = true
rw.fn(rw, "VIGNETTES_UPDATED")
assert(#ForeverHubStatus.RareWatch() == 0, "dead clears")
markers.c = nil
-- Treasure gets a row but no pop-up. Other markers are ignored.
toasts = {}
markers.t = { name = "Battered Chest", atlasName = "VignetteLoot", onMinimap = true }
markers.e = { name = "An Event", atlasName = "VignetteEvent", onMinimap = true }
rw.fn(rw, "VIGNETTES_UPDATED")
assert(#toasts == 0, "treasure is quiet")
local rows = ForeverHubStatus.RareWatch()
assert(#rows == 1 and rows[1].text:find("Treasure|r Battered Chest", 1, true), "treasure row")
rw.fn(rw, "VIGNETTE_MINIMAP_UPDATED", "t", false)
assert(#ForeverHubStatus.RareWatch() == 0, "off the minimap clears")
-- Hidden values and missing API don't break it.
issecretvalue = function() return true end
rw.fn(rw, "VIGNETTES_UPDATED")
rw.fn(rw, "VIGNETTE_MINIMAP_UPDATED", "t", true)
issecretvalue = function() return false end
C_VignetteInfo = nil
rw.fn(rw, "VIGNETTES_UPDATED")

----- ItemFinder tooltip
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = function() end }
GetInventoryItemLink = function() end
ItemFinderDB = {
    ["Alt-R"] = { bags = { ["Linen Cloth"] = 5 }, bank = { ["Linen Cloth"] = 2 }, gear = {} },
    ["Lean-R"] = { bank = { ["Linen Cloth"] = 3, ["Apple"] = 1 } },
}
local hook
Enum = { TooltipDataType = { Item = 0 } }
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) hook = fn end }
local hovered, lines
TooltipUtil = { GetDisplayedItem = function() return hovered end }
GameTooltip = { AddLine = function(_, t) lines[#lines + 1] = t end }
ItemRefTooltip = GameTooltip
local fi = load("ItemFinder")
fi.fn(fi, "PLAYER_LOGIN")
local function ask(name) hovered, lines = name, {}; hook(GameTooltip); return lines[1] end
ItemFinderDB["Lean-R"].bags = { ["Linen Cloth"] = 4, ["Water"] = 2 }
ItemFinderDB["Lean-R"].bank = { ["Linen Cloth"] = 3, ["Apple"] = 1 }
assert(ask("Linen Cloth") == "Owned: bags 4, bank 3, Alt 7", "counts: " .. tostring(lines[1]))
assert(ask("Apple") == "Owned: bank 1", "bank only")
assert(ask("Water") == nil, "only your bags isn't worth a line")
assert(ask("Nothing") == nil, "unowned")
print("ALL TESTS PASSED")
