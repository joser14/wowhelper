local base = ADDON_PATH
local chat, errors, frames = {}, {}, {}
local SECRET = {}
local function reset() chat, errors = {}, {} end
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
UIErrorsFrame = { AddMessage = function(_, t) errors[#errors + 1] = t end }
SlashCmdList = {}
issecretvalue = function(v) return v == SECRET end
UnitName = function() return "Tester" end
GetRealmName = function() return "Realm" end
local level, clock = 20, 100000
UnitLevel = function() return level end
time = function() return clock end
date = function() return "2026-11-04 17:00:00" end
local function load(name)
    local n = #frames
    assert(loadfile(base .. "/" .. name .. "/" .. name .. ".lua"))(name, {})
    return frames[n + 1]
end
local function fire(f, ev, ...) assert(f.registered[ev], "not registered: " .. ev); f.fn(f, ev, ...) end
local function saw(text) for _, t in ipairs(chat) do if t:find(text, 1, true) then return true end end return false end
local function need(text, why) assert(saw(text), why .. ": wanted '" .. text .. "' in:\n" .. table.concat(chat, "\n")) end
local function never(text, why) assert(not saw(text), why .. ": did not want '" .. text .. "' in:\n" .. table.concat(chat, "\n")) end

-- ErrorLog
local blizzardSaw, handler = {}, nil
handler = function(m) blizzardSaw[#blizzardSaw + 1] = m end
geterrorhandler = function() return handler end
seterrorhandler = function(h) handler = h end
debugstack = function() return "stack line" end
local el = load("!ErrorLog")
assert(SlashCmdList.ERRORLOG, "slash registered")
handler("early error")
assert(blizzardSaw[1] == "early error", "Blizzard's handler still runs")
fire(el, "ADDON_LOADED", "SomeOtherAddon")
assert(ErrorLogDB == nil, "waits for its own load")
fire(el, "ADDON_LOADED", "!ErrorLog")
assert(ErrorLogDB.entries[1].message == "early error", "errors before load are kept")
reset(); handler("early error")
assert(#chat == 0, "repeat doesn't spam")
assert(ErrorLogDB.entries[1].count == 2, "repeat counted")
handler("second")
need("Caught an error", "new error noticed")
handler(SECRET)
assert(ErrorLogDB.entries[3].message:find("hid", 1, true), "secret text replaced")
assert(blizzardSaw[#blizzardSaw] == SECRET, "secret still reaches Blizzard")
fire(el, "ADDON_ACTION_BLOCKED", "Bad", "Spell()")
need("Caught", "blocked")
assert(ErrorLogDB.entries[4].message == "Bad tried to use Spell()", "blocked text")
fire(el, "LUA_WARNING", 0, "warned")
assert(ErrorLogDB.entries[5].message == "warned", "warning")
reset(); SlashCmdList.ERRORLOG("")
need("1. [2026-11-04 17:00:00] x2 early error", "list")
reset(); SlashCmdList.ERRORLOG("1")
need("stack line", "details")
SlashCmdList.ERRORLOG("99")
need("No error with that number", "bad number")
SlashCmdList.ERRORLOG("clear")
assert(#ErrorLogDB.entries == 0, "clears saved list")
for i = 1, 60 do handler("e" .. i) end
assert(#ErrorLogDB.entries == 50, "capped")
SlashCmdList.ERRORLOG("clear")
reset(); SlashCmdList.ERRORLOG(""); need("No errors", "empty")
SlashCmdList.ERRORLOG("help")

-- TrainerNotes
reset()
local services = {}
GetNumTrainerServices = function() return #services end
GetTrainerServiceInfo = function(i) local s = services[i]; return s[1], s[2], 0, s[3], s[4] end
GetTrainerServiceCost = function(i) return services[i][5], false end
local tr = load("TrainerNotes")
SlashCmdList.TRAINERNOTES("")
assert(#chat == 0, "nothing before login")
fire(tr, "PLAYER_LOGIN")
SlashCmdList.TRAINERNOTES("")
need("Open your trainer", "no data")
services = { { "Class", "header", 0, nil, 0 },
    { "Rend", "available", 18, "Rank 2", 1500 },
    { "Cleave", "unavailable", 22, "Rank 1", 20000 },
    { "Far", "unavailable", 40, "Rank 1", 90000 },
    { "Old", "used", 4, "Rank 1", 10 } }
fire(tr, "TRAINER_SHOW")
reset(); SlashCmdList.TRAINERNOTES("")
need("Ready to train, 0g 15s 0c in total", "ready total")
need("Level 18: Rend (Rank 2), 0g 15s 0c", "ready line")
need("Coming within 4 levels, 2g 0s 0c", "upcoming total")
need("Level 22: Cleave (Rank 1)", "upcoming line")
never("Far", "too far ahead")
never("Old", "already learned")
never("Class", "header")
assert(TrainerNotesDB["Tester-Realm"].services["Rend|Rank 2"].cost == 1500, "saved")
reset(); fire(tr, "PLAYER_LEVEL_UP", 22)
need("2 thing(s) to train, 2g 15s 0c", "level-up reminder uses the new level")
services[2][2] = "used"; fire(tr, "TRAINER_UPDATE")
reset(); SlashCmdList.TRAINERNOTES("")
never("Rend", "bought is removed")
services = { { "Cleave", "used", 22, "Rank 1", 20000 }, { "Far", "used", 40, "Rank 1", 90000 } }
fire(tr, "TRAINER_UPDATE")
TrainerNotesDB["Tester-Realm"].services["Later|"] = { name = "Later", level = 50, cost = 1 }
reset(); SlashCmdList.TRAINERNOTES("")
need("Nothing new to train", "none ready")
reset(); fire(tr, "PLAYER_LEVEL_UP", 21)
assert(#chat == 0, "quiet with nothing ready")
services = { { SECRET, "available", 1, "", 5 } }
fire(tr, "TRAINER_UPDATE")

-- ZoneLevels
reset()
local mapID, low, high = 12, 30, 40
C_Map = {
    GetBestMapForUnit = function() return mapID end,
    GetMapInfo = function() return { name = "Duskwood" } end,
    GetMapLevels = function() return low, high, 0, 0 end,
}
local zl = load("ZoneLevels")
fire(zl, "ZONE_CHANGED_NEW_AREA")
need("Duskwood is level 30-40 and you're level 20. Careful!", "warn")
reset(); fire(zl, "PLAYER_ENTERING_WORLD")
assert(#chat == 0, "warns once per zone")
level = 28; fire(zl, "ZONE_CHANGED_NEW_AREA")
assert(#chat == 0, "2 below isn't too high")
level = 20; low, high = 1, 60
reset(); fire(zl, "ZONE_CHANGED_NEW_AREA")
assert(#chat == 0, "1-60 means no range")
SlashCmdList.ZONELEVELS("")
need("no level range", "slash without range")
low, high = 0, 0
reset(); SlashCmdList.ZONELEVELS("")
need("no level range", "zero")
low, high = 10, 20
reset(); SlashCmdList.ZONELEVELS("")
need("Duskwood: level 10-20", "slash")
mapID = nil
reset(); SlashCmdList.ZONELEVELS("")
need("didn't report", "no map")
fire(zl, "ZONE_CHANGED_NEW_AREA")

-- ItemFinder
reset()
local bags, equip = { [0] = {} }, {}
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
Enum = { BagIndex = { Backpack = 0, CharacterBankTab_1 = 6, AccountBankTab_1 = 15, Characterbanktab = -2 }, TooltipDataType = { Item = 0 } }
C_Container = {
    GetContainerNumSlots = function(b) return #(bags[b] or {}) end,
    GetContainerItemInfo = function(b, i) return bags[b][i] end,
}
GetInventoryItemLink = function(_, s) return equip[s] end
local fi = load("ItemFinder")
bags[0] = { { hyperlink = "|Hitem:1|h[Linen Cloth]|h", stackCount = 5 }, { hyperlink = "|Hitem:1|h[Linen Cloth]|h", stackCount = 2 }, false }
equip[1] = "|Hitem:2|h[Iron Helm]|h"
fire(fi, "PLAYER_LOGIN")
SlashCmdList.ITEMFINDER("linen")
need("Linen Cloth: Tester-Realm x7 (bags)", "case-insensitive, stacks merged")
reset(); SlashCmdList.ITEMFINDER("helm")
need("Iron Helm: Tester-Realm x1 (worn)", "gear")
bags[6] = { { hyperlink = "|Hitem:3|h[Silk]|h", stackCount = 9 } }
bags[15] = { { hyperlink = "|Hitem:4|h[Shared]|h", stackCount = 1 } }
fire(fi, "BANKFRAME_OPENED")
reset(); SlashCmdList.ITEMFINDER("silk")
need("Silk: Tester-Realm x9 (bank)", "bank")
reset(); SlashCmdList.ITEMFINDER("shared")
need("Nothing found", "account bank not counted")
ItemFinderDB["Alt-Realm"] = { bags = { ["Linen Cloth"] = 3 } }
reset(); SlashCmdList.ITEMFINDER("linen")
need("Alt-Realm x3", "other characters")
bags[0] = {}; fire(fi, "BAG_UPDATE_DELAYED")
reset(); SlashCmdList.ITEMFINDER("linen")
never("Tester-Realm", "bags refreshed")
equip[1] = nil; fire(fi, "PLAYER_EQUIPMENT_CHANGED")
reset(); SlashCmdList.ITEMFINDER("helm"); need("Nothing found", "gear refreshed")
equip[1] = "|Hitem:2|h[]|h"; fire(fi, "PLAYER_EQUIPMENT_CHANGED")
assert(next(ItemFinderDB["Tester-Realm"].gear) == nil, "empty names aren't saved, as seen on the live client")
equip[1] = "|Hitem:2|h[Iron Helm]|h"; fire(fi, "BAG_UPDATE_DELAYED")
reset(); SlashCmdList.ITEMFINDER("helm"); need("Iron Helm: Tester-Realm x1 (worn)", "worn names fill in later")
equip[1] = nil; fire(fi, "PLAYER_EQUIPMENT_CHANGED")
reset(); SlashCmdList.ITEMFINDER("  "); need("Use /find", "help")
local many = {}
for i = 1, 40 do many["Thing " .. i] = 1 end
ItemFinderDB["Alt-Realm"].bags = many
reset(); SlashCmdList.ITEMFINDER("thing"); need("and 10 more", "capped")

-- PriceMemory
reset()
local results, hook, hovered = {}, nil, nil
C_AuctionHouse = { GetBrowseResults = function() return results end }
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) hook = fn end }
TooltipUtil = { GetDisplayedItem = function() return "n", "l", hovered end }
local lines = {}
GameTooltip = { AddLine = function(_, t) lines[#lines + 1] = t end }
ItemRefTooltip = GameTooltip
local pm = load("PriceMemory")
fire(pm, "PLAYER_LOGIN")
results = { { itemKey = { itemID = 2589 }, minPrice = 12345, totalQuantity = 4 }, { itemKey = { itemID = 7 }, minPrice = SECRET }, { itemKey = { itemID = 8 }, minPrice = 0 } }
fire(pm, "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
assert(PriceMemoryDB[2589].price == 12345, "saved")
assert(not PriceMemoryDB[7] and not PriceMemoryDB[8], "bad prices skipped")
hovered = 2589; hook(GameTooltip)
assert(lines[1]:find("seen under an hour ago: 1g 23s 45c each", 1, true), lines[1])
clock = clock + 7200; lines = {}; hook(GameTooltip)
assert(lines[1]:find("2h ago", 1, true), lines[1])
clock = clock + 172800; lines = {}; hook(GameTooltip)
assert(lines[1]:find("2d ago", 1, true), lines[1])
hovered = 99; lines = {}; hook(GameTooltip)
assert(#lines == 0, "unknown item quiet")
hovered = SECRET; hook(GameTooltip)
assert(#lines == 0, "secret quiet")
hovered = 2589; hook({ AddLine = function() error("must ignore other tooltips") end })
results = { { itemKey = { itemID = 2589 }, minPrice = 1 } }
fire(pm, "AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
assert(PriceMemoryDB[2589].price == 1, "latest price wins")

print("ALL TESTS PASSED")
