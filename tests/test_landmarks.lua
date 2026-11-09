-- Landmarks smoke test: remembers places from the windows you open, shows the nearest per kind,
-- pins one on request, merges repeat visits, and keeps the saved list bounded.
-- Run from the harness folder:  node run.js "<workspace root>" test_landmarks.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
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
local npc = "Bob"
UnitName = function(unit) if unit == "npc" then return npc end return "Me" end
GetRealmName = function() return "R" end
local clock = 50000
time = function() return clock end
GetZoneText = function() return "Elwynn Forest" end
GetSubZoneText = function() return "Goldshire" end

-- Map mocks: map 37 is on continent 13, map 57 on continent 12; world yards = map fraction * 10000.
local mapID, px, py = 37, 0.5, 0.5
local positionReadable = true
local CONTINENT = { [37] = 13, [57] = 12 }
local function vec(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
CreateVector2D = vec
local waypoints = {}
C_Map = {
    GetBestMapForUnit = function() return mapID end,
    GetPlayerMapPosition = function() if not positionReadable then return nil end return vec(px, py) end,
    GetWorldPosFromMapPos = function(id, v)
        local c = CONTINENT[id]
        if not c then return end
        return c, vec(math.floor(v.x * 10000 + 0.5), math.floor(v.y * 10000 + 0.5))
    end,
    SetUserWaypoint = function(p) waypoints[#waypoints + 1] = p; return true end,
}
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, x = x, y = y } end }
local supertracked
C_SuperTrack = { SetSuperTrackedUserWaypoint = function(b) supertracked = b end }

-- Merchant / trainer / gossip mocks.
local merchantItems, canRepair = {}, false
GetMerchantNumItems = function() return #merchantItems end
GetMerchantItemID = function(i) return merchantItems[i] end
CanMerchantRepair = function() return canRepair end
-- itemID -> { classID, subClassID }: 117 Tough Jerky (consumable/food), 2589 Linen Cloth (trade goods)
local ITEMS = { [117] = { 0, 5 }, [2589] = { 7, 5 } }
C_Item = { GetItemInfoInstant = function(id)
    local c = ITEMS[id]
    if not c then return end
    return id, "type", "subtype", "", 0, c[1], c[2]
end }
local tradeskill = false
IsTradeskillTrainer = function() return tradeskill end
local gossip = {}
C_GossipInfo = { GetOptions = function() return gossip end }

local function load(name)
    local n = #frames
    assert(loadfile(base .. "/" .. name .. "/" .. name .. ".lua"))(name, {})
    return frames[n + 1]
end
local function fire(f, ev, ...) clock = clock + 1; f.fn(f, ev, ...) end
local function at(x, y, m) px, py = x, y; if m then mapID = m end end
local function reset() out = {} end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function dump() return "\n  page was:\n  " .. table.concat(out, "\n  ") end
local function check(cond, why) if not cond then failures[#failures + 1] = why .. dump() end end
local function need(text, why) check(has(text), why .. ": wanted '" .. text .. "'") end
-- ForeverHub runs the page under pcall; do the same so one error doesn't hide the other checks.
local function page(arg)
    reset()
    local ok, err = pcall(SlashCmdList.LANDMARKS, arg)
    if not ok then out[#out + 1] = "<<ERROR: " .. tostring(err) .. ">>" end
    return ok
end
local function count(kind)
    local n = 0
    for _, p in ipairs(LandmarksDB.R.places) do if p.kind == kind then n = n + 1 end end
    return n
end

local lm = load("Landmarks")
for _, ev in ipairs({ "PLAYER_LOGIN", "MERCHANT_SHOW", "MAIL_SHOW", "TAXIMAP_OPENED", "TRAINER_SHOW", "BANKFRAME_OPENED", "CONFIRM_BINDER", "GOSSIP_SHOW" }) do
    assert(lm.registered[ev], "registers " .. ev)
end

----- Before login: quiet, no errors, nothing saved
assert(page("") and #out == 0, "page before login is quiet")
fire(lm, "MERCHANT_SHOW")
assert(LandmarksDB == nil, "events before login save nothing")

fire(lm, "PLAYER_LOGIN")
assert(LandmarksDB and LandmarksDB.R and LandmarksDB.R.places, "db per realm")
page("")
need("Nothing remembered yet", "empty page")
need("0 places remembered", "empty count")

----- A repairing food vendor at the inn
at(0.5, 0.5); npc = "Bob"; canRepair = true; merchantItems = { 2589, 117 }
fire(lm, "MERCHANT_SHOW")
assert(#LandmarksDB.R.places == 3, "vendor + repair + food = 3 records, got " .. #LandmarksDB.R.places)
assert(count("vendor") == 1 and count("repair") == 1 and count("food") == 1, "one of each kind")

----- Same vendor again, 3 yards over: merged, position refreshed
at(0.5003, 0.5)
fire(lm, "MERCHANT_SHOW")
assert(#LandmarksDB.R.places == 3, "a second visit to Bob doesn't add records, got " .. #LandmarksDB.R.places)
local bob
for _, p in ipairs(LandmarksDB.R.places) do if p.kind == "vendor" then bob = p end end
assert(bob.name == "Bob" and math.abs(bob.x - 0.5003) < 1e-9 and bob.continent == 13 and bob.wx and bob.seen == clock, "merged record refreshed")

----- A plain vendor 1000 yards east (no repair, no food)
at(0.6, 0.5); npc = "Alice"; canRepair = false; merchantItems = { 2589 }
fire(lm, "MERCHANT_SHOW")
assert(#LandmarksDB.R.places == 4 and count("vendor") == 2, "Alice is a new vendor only")

----- A secret NPC name falls back to the kind word, no error
at(0.9, 0.9); npc = SECRET
fire(lm, "MERCHANT_SHOW")
assert(count("vendor") == 3, "secret-named vendor still remembered under the fallback name")
local fallback
for _, p in ipairs(LandmarksDB.R.places) do if p.kind == "vendor" and math.abs(p.x - 0.9) < 1e-9 then fallback = p end end
assert(fallback and fallback.name == "Vendor", "fallback name used")
npc = "Bob"

----- Mailbox 100 yards from the inn, flight master 2000 yards east
at(0.51, 0.5)
fire(lm, "MAIL_SHOW")
at(0.7, 0.5); npc = "Gryphon Master Talonaxe"
fire(lm, "TAXIMAP_OPENED")
assert(count("mail") == 1 and count("flight") == 1, "mailbox and flight master saved")

----- A second mailbox 400 yards away must be its own record.
-- BUG (Landmarks.lua:94): Remember() merges on `place.name == name` regardless of distance, and every
-- mailbox is named "Mailbox", so only one mailbox is ever remembered per continent. The same happens to
-- any two NPCs that share a name, and to every secret-named NPC that fell back to "Vendor"/"Trainer".
at(0.55, 0.5)
fire(lm, "MAIL_SHOW")
check(count("mail") == 2, "BUG: a second mailbox 400 yd away was merged into the first (count=" .. count("mail") .. ")")

----- Class trainer, profession trainer, banker, innkeeper via CONFIRM_BINDER
at(0.52, 0.52); npc = "Marshal McBride"; tradeskill = false
fire(lm, "TRAINER_SHOW")
at(0.53, 0.53); npc = "Tomas"; tradeskill = true
fire(lm, "TRAINER_SHOW")
at(0.54, 0.54); npc = "Banker Olivia"
fire(lm, "BANKFRAME_OPENED")
at(0.5, 0.5); npc = "Innkeeper Farley"
fire(lm, "CONFIRM_BINDER", "Goldshire")
assert(count("trainer") == 1 and count("profession") == 1 and count("bank") == 1 and count("inn") == 1, "trainer/profession/bank/inn saved")

----- Innkeeper via gossip: only when an option mentions home
at(0.8, 0.8); npc = "Innkeeper Brianna"
gossip = { { name = "I'd like to browse your goods.", icon = 132060 } }
fire(lm, "GOSSIP_SHOW")
assert(count("inn") == 1, "a plain gossip menu isn't an inn")
gossip = { { name = "Make this inn your home.", icon = 132052 }, { name = SECRET } }
fire(lm, "GOSSIP_SHOW")
assert(count("inn") == 2, "gossip 'home' option marks an inn")
gossip = {}

----- The page from the inn: nearest per kind with distances
at(0.5, 0.5)
-- BUG (Landmarks.lua:203): `local place, yards = spot and Nearest(spot, entry.key)` — `and` truncates to one
-- value, so `yards` is always nil and YardsText(nil) raises "attempt to compare nil with number" the moment
-- anything is remembered. Every page render with a readable position fails under ForeverHub's pcall.
local ok = page("")
check(ok, "BUG: the page errors whenever a place is remembered and the position is readable")
need("|cffffd100Repair:|r Bob, Goldshire, Elwynn Forest |cff999999(3 yd)|r", "nearest repair")
need("|cffffd100Vendor:|r Bob, Goldshire, Elwynn Forest |cff999999(3 yd)|r", "nearest vendor is Bob, not Alice")
need("|cffffd100Food and drink:|r Bob,", "food vendor")
need("|cffffd100Mailbox:|r Mailbox, Goldshire, Elwynn Forest |cff999999(100 yd)|r", "nearest mailbox")
need("|cffffd100Flight master:|r Gryphon Master Talonaxe, Goldshire, Elwynn Forest |cff999999(2.0 k yd)|r", "flight master in k yd")
need("|cffffd100Innkeeper:|r Innkeeper Farley,", "innkeeper")
need("|cffffd100Class trainer:|r Marshal McBride,", "class trainer")
need("|cffffd100Profession trainer:|r Tomas,", "profession trainer")
need("|cffffd100Bank:|r Banker Olivia,", "bank")
check(not has("Nothing remembered yet"), "not empty")
check(not has("can't be read"), "position was readable")

----- Pinning the nearest repairer
page("repair")
need("Pinned Bob (Goldshire, Elwynn Forest), 3 yd away.", "pin message")
check(#waypoints == 1 and waypoints[1].uiMapID == 37 and math.abs(waypoints[1].x - 0.5003) < 1e-9, "waypoint set at Bob's spot")
check(supertracked == true, "waypoint super-tracked")
page("Flight master")
need("Pinned Gryphon Master Talonaxe", "pin by label")
check(#waypoints == 2, "second pin")

----- Unknown kind, and a kind with nothing on this continent
page("bogus")
need("I don't know a place called 'bogus'", "unknown kind")
check(#waypoints == 2, "no pin for an unknown kind")
at(0.5, 0.5, 57)
page("bank")
need("No bank remembered on this continent yet", "other continent has no bank")
need("|cffffd100Bank:|r 1 remembered, none on this continent", "count on another continent")
check(#waypoints == 2, "no pin across continents")
at(0.5, 0.5, 37)

----- Position unreadable: events are ignored, the page says so
positionReadable = false
local before = #LandmarksDB.R.places
at(0.3, 0.3); npc = "Ghost"
fire(lm, "MERCHANT_SHOW")
assert(#LandmarksDB.R.places == before, "no record without a position")
page("")
need("Where you are can't be read right now", "unreadable notice")
page("repair")
need("I can't read where you are right now.", "no pin without a position")
positionReadable = true

----- MAX_PLACES: the oldest records are pruned, the list stays at 400
local placesBefore = #LandmarksDB.R.places
canRepair = false; merchantItems = {}
for i = 1, 420 do
    npc = "V" .. i
    at(0.02 + (i % 20) * 0.045, 0.02 + math.floor(i / 20) * 0.045)
    fire(lm, "MERCHANT_SHOW")
end
assert(#LandmarksDB.R.places == 400, "capped at 400, got " .. #LandmarksDB.R.places)
local names = {}
for _, p in ipairs(LandmarksDB.R.places) do names[p.name] = true end
assert(names["V420"] and names["V21"], "newest kept")
assert(not names["Bob"], "the oldest records (Bob's) were pruned")
assert(names["Gryphon Master Talonaxe"] == nil, "all early visits older than the newest 400 went")
page("")
need("400 places remembered", "count line")

if #failures > 0 then
    error(#failures .. " check(s) failed:\n\n" .. table.concat(failures, "\n\n"), 0)
end
print("ALL TESTS PASSED")
