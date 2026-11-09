-- Review fixes: ErrorLog warning text and old saves, RepWatch collapsed headers, PriceMemory realm/faction, ForeverHelper shown.
local base = ADDON_PATH
local out, frames = {}, {}
local SECRET = {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function(v) return v == SECRET end
local function newFrame()
    local f = { registered = {}, scripts = {}, shownFlag = true }
    setmetatable(f, { __index = function() return function() end end })
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, k, fn) self.scripts[k] = fn; if k == "OnEvent" then self.fn = fn end end
    f.SetShown = function(self, v) self.shownFlag = v and true or false end
    f.IsShown = function(self) return self.shownFlag end
    f.CreateFontString = function() return newFrame() end
    return f
end
CreateFrame = function() local f = newFrame(); frames[#frames + 1] = f; return f end
UIParent = newFrame()
UISpecialFrames = {}
SlashCmdList = {}
C_Timer = { NewTicker = function() end }
GetTime = function() return 1000 end
GetMoney = function() return 0 end
UnitXP = function() return 0 end
UnitXPMax = function() return 100 end
GetXPExhaustion = function() return 0 end
UnitName = function() return "Me" end
UnitLevel = function() return 10 end
local realm, faction = "R", "Alliance"
GetRealmName = function() return realm end
UnitFactionGroup = function() return faction, faction end
local clock = 50000
time = function() return clock end
date = function() return "2026-11-07 12:00:00" end
local function load(name)
    local n = #frames
    assert(loadfile(base .. "/" .. name .. "/" .. name .. ".lua"))(name, {})
    return frames[n + 1]
end
local function fire(f, ev, ...) assert(f.registered[ev], "not registered: " .. ev); f.fn(f, ev, ...) end
local function reset() out = {} end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function need(text, why) assert(has(text), why .. ": wanted '" .. text .. "' in:\n" .. table.concat(out, "\n")) end

----- 1 and 2. !ErrorLog: Forever's warning text is the first argument; old saved entries are normalized.
local handler
geterrorhandler = function() return handler end
seterrorhandler = function(h) handler = h end
debugstack = function() return "stack" end
ErrorLogDB = { entries = { { kind = "Lua error", message = "old one" }, "junk", { message = "no kind", count = "3" } } }
local el = load("!ErrorLog")
fire(el, "ADDON_LOADED", "!ErrorLog")
local list = ErrorLogDB.entries
assert(#list == 2, "junk entry dropped")
assert(list[1].count == 1 and list[1].when == "", "missing count and time filled in")
assert(list[2].count == 3 and list[2].kind == "Lua error", "numeric-text count kept, kind filled in")
handler("old one")
assert(list[1].count == 2, "repeat of an old entry counts up")
reset(); SlashCmdList.ERRORLOG("")
need("1. [] x2 old one", "Errors page shows old entries")
reset(); SlashCmdList.ERRORLOG("2")
need("Lua error, , seen 3 time(s):", "details of an old entry")
fire(el, "LUA_WARNING", "Forever warning text")
assert(list[3].kind == "Lua warning" and list[3].message == "Forever warning text", "first argument is the warning: " .. tostring(list[3].message))
fire(el, "LUA_WARNING", SECRET)
assert(list[4].message:find("hid", 1, true), "secret warning text hidden")

----- 3. RepWatch: a faction under a collapsed header keeps its login starting point.
local all = {
    [1] = { factionID = 1, name = "Stormwind", currentStanding = 100, reaction = 5, currentReactionThreshold = 0, nextReactionThreshold = 3000 },
    [2] = { factionID = 2, name = "Ironforge", currentStanding = 500, reaction = 5, currentReactionThreshold = 0, nextReactionThreshold = 3000 },
}
local visible = { 1 }
local byIDCalls = 0
C_Reputation = {
    GetNumFactions = function() return #visible end,
    GetFactionDataByIndex = function(i) return all[visible[i]] end,
    GetFactionDataByID = function(id) byIDCalls = byIDCalls + 1; return all[id] end,
}
RepWatchDB = { seen = { [2] = true } } -- Ironforge was seen on an earlier login
local rw = load("RepWatch")
fire(rw, "ADDON_LOADED", "RepWatch")
fire(rw, "PLAYER_ENTERING_WORLD")
assert(byIDCalls > 0, "remembered faction read by ID")
all[2].currentStanding = 560 -- gained while its header stays collapsed
all[1].currentStanding = 130
reset(); SlashCmdList.REPWATCH("")
need("Stormwind: +30 this session", "visible faction")
need("Ironforge: +60 this session", "collapsed faction's full gain")
visible = { 1, 2 } -- header opened later: no double listing, gain unchanged
reset(); SlashCmdList.REPWATCH("all")
local count = 0
for _, t in ipairs(out) do if t:find("Ironforge", 1, true) then count = count + 1 end end
assert(count == 1, "listed once")
need("(+60 this session)", "still the full gain")
assert(RepWatchDB.seen[1] and RepWatchDB.seen[2], "seen factions saved")
all[2] = SECRET
visible = { 1 }
reset(); SlashCmdList.REPWATCH("all")
assert(not has("Ironforge"), "secret data skipped")

----- 4. PriceMemory: prices are kept per realm and faction; old flat entries are marked.
local results, hook, hovered = {}, nil, nil
C_AuctionHouse = { GetBrowseResults = function() return results end }
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) hook = fn end }
TooltipUtil = { GetDisplayedItem = function() return "n", "l", hovered end }
Enum = { TooltipDataType = { Item = 0 } }
local lines = {}
GameTooltip = { AddLine = function(_, t) lines[#lines + 1] = t end }
ItemRefTooltip = GameTooltip
PriceMemoryDB = { [9] = { price = 500, seen = clock } } -- older flat save
local pm = load("PriceMemory")
fire(pm, "PLAYER_LOGIN")
results = { { itemKey = { itemID = 5 }, minPrice = 300 } }
fire(pm, "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
assert(PriceMemoryDB["R-Alliance"][5].price == 300, "saved under realm and faction")
assert(PriceMemoryDB[5] == nil, "not saved flat")
hovered = 5; lines = {}; hook(GameTooltip)
assert(lines[1] and lines[1]:find("0g 3s 0c each", 1, true) and not lines[1]:find("older", 1, true), tostring(lines[1]))
faction = "Horde"; lines = {}; hook(GameTooltip)
assert(#lines == 0, "the other faction's price isn't shown")
realm, faction = "Other", "Alliance"; lines = {}; hook(GameTooltip)
assert(#lines == 0, "another realm's price isn't shown")
results = { { itemKey = { itemID = 5 }, minPrice = 900 } }
fire(pm, "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
assert(PriceMemoryDB["Other-Alliance"][5].price == 900 and PriceMemoryDB["R-Alliance"][5].price == 300, "kept apart")
hovered = 9; lines = {}; hook(GameTooltip)
assert(lines[1] and lines[1]:find("older save", 1, true), "flat entry marked: " .. tostring(lines[1]))
realm = SECRET; hovered = 9; lines = {}; hook(GameTooltip)
assert(lines[1] and not lines[1]:find("older save", 1, true), "unknown realm falls back to flat data unmarked")

----- 5. ForeverHelper: an older save without `shown` keeps the window open.
ForeverHelperDB = { characters = {} }
local fh = load("ForeverHelper")
fire(fh, "ADDON_LOADED", "ForeverHelper")
assert(ForeverHelperDB.shown == true, "shown defaulted")
local function window()
    for i = #frames, 1, -1 do if rawget(frames[i], "empty") then return frames[i] end end
end
assert(window() and window():IsShown(), "window visible at login")
ForeverHelperDB = { characters = {}, shown = false }
local fh2 = load("ForeverHelper")
fire(fh2, "ADDON_LOADED", "ForeverHelper")
assert(ForeverHelperDB.shown == false and not window():IsShown(), "a saved hidden window stays hidden")

print("ALL TESTS PASSED")
