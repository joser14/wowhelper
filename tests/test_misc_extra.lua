-- Covers the fixes in ItemFinder, PriceMemory, RepWatch, ZoneLevels, LevelLog, RareWatch, !ErrorLog, ForeverHelper.
local base = ADDON_PATH
local out, frames = {}, {}
local SECRET = {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function(v) return v == SECRET end
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
UnitName = function() return "Me" end
GetRealmName = function() return "R" end
local now = 1000
GetTime = function() return now end
time = function() return 50000 end
date = function() return "2026-11-07 12:00:00" end
local function load(name)
    local n = #frames
    assert(loadfile(base .. "/" .. name .. "/" .. name .. ".lua"))(name, {})
    return frames[n + 1]
end
local function fire(f, ev, ...) f.fn(f, ev, ...) end
local function reset() out = {} end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function need(text, why) assert(has(text), why .. ": wanted '" .. text .. "' in:\n" .. table.concat(out, "\n")) end

----- ItemFinder: results sorted by item, then character
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
Enum = { BagIndex = {}, TooltipDataType = { Item = 0 } }
C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = function() end }
GetInventoryItemLink = function() end
local fi = load("ItemFinder")
fire(fi, "PLAYER_LOGIN")
ItemFinderDB["Zed-R"] = { bags = { ["Apple"] = 1 } }
ItemFinderDB["Abe-R"] = { bags = { ["Apple"] = 2 }, bank = { ["Apple Pie"] = 3 } }
reset(); SlashCmdList.ITEMFINDER("apple")
assert(out[1] == "Apple: Abe-R x2 (bags)" and out[2] == "Apple: Zed-R x1 (bags)" and out[3] == "Apple Pie: Abe-R x3 (bank)", "sorted:\n" .. table.concat(out, "\n"))
local many = {}
for i = 1, 35 do many[string.format("Thing %02d", i)] = 1 end
ItemFinderDB["Abe-R"].bags = many
reset(); SlashCmdList.ITEMFINDER("thing")
assert(out[1]:find("Thing 01", 1, true) and out[30]:find("Thing 30", 1, true), "first 30 in order")
need("and 5 more", "cap")

----- PriceMemory: cheapest of several same-ID results, missing AH API is quiet
local results, hook = {}, nil
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) hook = fn end }
TooltipUtil = { GetDisplayedItem = function() end }
local pm = load("PriceMemory")
fire(pm, "PLAYER_LOGIN")
C_AuctionHouse = nil
fire(pm, "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
C_AuctionHouse = { GetBrowseResults = function() return results end }
results = { { itemKey = { itemID = 5 }, minPrice = 900 }, { itemKey = { itemID = 5 }, minPrice = 300 }, { itemKey = { itemID = 5 }, minPrice = 600 },
    { itemKey = SECRET, minPrice = 1 } }
fire(pm, "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
assert(PriceMemoryDB[5].price == 300, "cheapest kept: " .. PriceMemoryDB[5].price)
results = { { itemKey = { itemID = 5 }, minPrice = 700 } }
fire(pm, "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
assert(PriceMemoryDB[5].price == 700, "a newer search still replaces the old price")

----- RepWatch: factions seen later still get tracked, and the "all" page shows gains
local factions = { { factionID = 1, name = "Stormwind", currentStanding = 100, reaction = 5, currentReactionThreshold = 0, nextReactionThreshold = 3000 } }
C_Reputation = {
    GetNumFactions = function() return #factions end,
    GetFactionDataByIndex = function(i) return factions[i] end,
}
local rw = load("RepWatch")
fire(rw, "PLAYER_ENTERING_WORLD")
-- A faction under a header that was collapsed at login appears later.
factions[2] = { factionID = 2, name = "Ironforge", currentStanding = 500, reaction = 5, currentReactionThreshold = 0, nextReactionThreshold = 3000 }
fire(rw, "BAG_UPDATE_DELAYED")
factions[1].currentStanding = 150
factions[2].currentStanding = 520
reset(); SlashCmdList.REPWATCH("")
need("Stormwind: +50 this session", "gain")
need("Ironforge: +20 this session", "late faction tracked")
reset(); SlashCmdList.REPWATCH("all")
need("Stormwind: Standing 150/3000, 2850 to the next standing (+50 this session)", "all page shows gain")
need("Ironforge: Standing 520/3000", "all page")
factions[1].currentStanding = SECRET
reset(); SlashCmdList.REPWATCH("all")
assert(not has("Stormwind"), "secret standing skipped")

----- ZoneLevels: a cave map without a range uses its zone's range and name
local maps = {
    [100] = { name = "Fargodeep Mine", mapType = 5, parentMapID = 37, levels = { 0, 0 } },
    [37] = { name = "Elwynn Forest", mapType = 3, parentMapID = 13, levels = { 30, 35 } },
    [13] = { name = "Eastern Kingdoms", mapType = 2, parentMapID = 947, levels = { 1, 60 } },
    [200] = { name = "Lonely", mapType = 3, parentMapID = 13, levels = { 0, 0 } },
}
local here = 100
UnitLevel = function() return 20 end
UIErrorsFrame = { AddMessage = function() end }
C_Map = {
    GetBestMapForUnit = function() return here end,
    GetMapInfo = function(id) return maps[id] end,
    GetMapLevels = function(id) return maps[id].levels[1], maps[id].levels[2], 0, 0 end,
}
Enum.UIMapType = { Zone = 3 }
local zl = load("ZoneLevels")
reset(); fire(zl, "ZONE_CHANGED_NEW_AREA")
need("Elwynn Forest is level 30-35", "climbed to the zone")
here = 37
reset(); fire(zl, "ZONE_CHANGED_NEW_AREA")
assert(#out == 0, "leaving the cave into the same zone doesn't warn again")
here = 200
reset(); SlashCmdList.ZONELEVELS("")
need("Lonely: the game has no level range", "a zone doesn't climb to its continent")
maps[100].mapType = SECRET; here = 100
reset(); SlashCmdList.ZONELEVELS("")
need("Fargodeep Mine: the game has no level range", "secret map type stops the climb")

----- LevelLog: the page before login is quiet, not an error
local ll = load("LevelLog")
reset(); SlashCmdList.LEVELLOG("all")
assert(#out == 0, "nothing before login")
UnitLevel = function() return 5 end
fire(ll, "PLAYER_LOGIN")
now = now + 600
reset(); SlashCmdList.LEVELLOG("all")
need("Level 5: 10m, 0 death(s)", "after login")

----- RareWatch: a rare that stays on the minimap doesn't alert again
SOUNDKIT = { RAID_WARNING = 1 }
local sounds = 0
PlaySound = function() sounds = sounds + 1 end
local markers = { a = { name = "Mother Fang", atlasName = "VignetteKill", onMinimap = true } }
C_VignetteInfo = {
    GetVignetteInfo = function(g) return markers[g] end,
    GetVignettes = function() local l = {}; for g in pairs(markers) do l[#l + 1] = g end; return l end,
}
local rare = load("RareWatch")
reset(); fire(rare, "VIGNETTES_UPDATED")
assert(#out == 1 and sounds == 1, "first sighting alerts")
now = now + 1000
fire(rare, "VIGNETTES_UPDATED")
fire(rare, "VIGNETTE_MINIMAP_UPDATED", "a", true)
assert(#out == 1 and sounds == 1, "still there, so no repeat")
fire(rare, "VIGNETTE_MINIMAP_UPDATED", "a", false)
now = now + 1000
fire(rare, "VIGNETTE_MINIMAP_UPDATED", "a", true)
assert(#out == 2, "back on the minimap long after counts as new")

----- !ErrorLog: early errors merge into a full saved list
local handler
geterrorhandler = function() return handler end
seterrorhandler = function(h) handler = h end
debugstack = function() return "stack" end
ErrorLogDB = { entries = {} }
for i = 1, 50 do ErrorLogDB.entries[i] = { kind = "Lua error", message = "old" .. i, count = 1, when = "" } end
local el = load("!ErrorLog")
handler("old50")
handler("brand new")
fire(el, "ADDON_LOADED", "!ErrorLog")
local list = ErrorLogDB.entries
assert(#list == 50, "still capped")
assert(list[#list].message == "brand new", "the new error is kept")
assert(list[1].message == "old2", "the oldest saved one made room")
local repeats = 0
for _, e in ipairs(list) do if e.message == "old50" then repeats = repeats + 1; assert(e.count == 2, "repeat counted") end end
assert(repeats == 1, "a repeat isn't saved twice")

print("ALL TESTS PASSED")
