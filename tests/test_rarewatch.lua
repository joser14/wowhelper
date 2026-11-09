-- RareWatch smoke test: rares seen by nameplate/target/mouseover/minimap are remembered per NPC ID,
-- alert once per 10 minutes, deaths are noted, the layer is guessed from NPC GUIDs and a change in the
-- same zone shows a hub row, the page lists/pins/forgets, secrets never error, the list is capped.
-- Run from the harness folder:  node run.js "<workspace root>" test_rarewatch.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local SECRET = {}
local hubOn = true
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
GetRealmName = function() return "R" end
local clock, gametime = 100000, 1000
time = function() return clock end
GetTime = function() return gametime end
GetZoneText = function() return "Elwynn Forest" end
GetSubZoneText = function() return "Goldshire" end
local sounds = 0
SOUNDKIT = { RAID_WARNING = 1 }
PlaySound = function() sounds = sounds + 1 end
local chat = 0
DEFAULT_CHAT_FRAME = { AddMessage = function() chat = chat + 1 end }

local mapID, px, py = 37, 0.5, 0.5
local CONTINENT = { [37] = 13 }
local function vec(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
CreateVector2D = vec
local waypoints, supertracked = {}, 0
C_Map = {
    GetBestMapForUnit = function() return mapID end,
    GetPlayerMapPosition = function() return vec(px, py) end,
    GetWorldPosFromMapPos = function(id, v)
        local c = CONTINENT[id]
        if not c then return end
        return c, vec(v.x * 10000, v.y * 10000)
    end,
    CanSetUserWaypointOnMap = function() return true end,
    SetUserWaypoint = function(p) waypoints[#waypoints + 1] = p end,
}
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, x = x, y = y } end }
C_SuperTrack = { SetSuperTrackedUserWaypoint = function(on) if on then supertracked = supertracked + 1 end end }

-- Units the game would show: token -> { guid, class, name, level, dead }
local units = {}
UnitExists = function(u) return units[u] ~= nil end
UnitGUID = function(u) return units[u] and units[u].guid end
UnitClassification = function(u) return units[u] and units[u].class or "normal" end
UnitName = function(u) return units[u] and units[u].name end
UnitLevel = function(u) return units[u] and units[u].level end
UnitIsDead = function(u) return units[u] and units[u].dead or false end
UnitIsPlayer = function(u) return units[u] and units[u].player or false end

local markers, positions = {}, {}
C_VignetteInfo = {
    GetVignetteInfo = function(g) return markers[g] end,
    GetVignettes = function() local l = {}; for g in pairs(markers) do l[#l + 1] = g end; return l end,
    GetVignettePosition = function(g, m) local p = positions[g]; if p and m == 37 then return vec(p[1], p[2]) end end,
}

local n = #frames
assert(loadfile(base .. "/RareWatch/RareWatch.lua"))("RareWatch", {})
local f = frames[n + 1]
local function fire(ev, ...) f.fn(f, ev, ...) end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function dump() return "\n  output was:\n  " .. table.concat(out, "\n  ") end
local function check(cond, why) if not cond then failures[#failures + 1] = why .. dump() end end
local function need(text, why) check(has(text), why .. ": wanted '" .. text .. "'") end
local function page(arg)
    out = {}
    local ok, err = pcall(SlashCmdList.RAREWATCH, arg)
    if not ok then out[#out + 1] = "<<ERROR: " .. tostring(err) .. ">>" end
end
local function guid(server, zone, npc, spawn) return string.format("Creature-0-%d-0-%d-%d-%08X", server, zone, npc, spawn) end
local function plate(token, u) units[token] = u; fire("NAME_PLATE_UNIT_ADDED", token) end
local function rows()
    local r = ForeverHubStatus.RareWatch()
    local layerRow
    for _, row in ipairs(r) do if row.text:find("Layer", 1, true) then layerRow = row end end
    return layerRow
end

for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "ZONE_CHANGED_NEW_AREA", "VIGNETTE_MINIMAP_UPDATED", "PLAYER_LOGIN" }) do
    check(f.registered[e], "registers " .. e)
end
check(SlashCmdList.RAREWATCH ~= nil, "page command registered")

-- Before login: quiet, no error.
page("")
check(#out == 0, "nothing before login")
plate("nameplate1", { guid = guid(5000, 111, 61, 1), class = "rare", name = "Mother Fang", level = 10 })
check(RareWatchDB == nil, "nothing saved before login")
units = {}

fire("PLAYER_LOGIN")
fire("ZONE_CHANGED_NEW_AREA")  -- the login zone change starts the layer guess fresh
page("")
need("Layer:|r unknown", "layer unknown before any NPC")
need("No rares remembered yet", "empty page")
need("estimate", "page explains the layer is an estimate")

-- Normal NPCs build the layer guess, and say nothing.
out = {}
for i = 1, 3 do plate("nameplate" .. i, { guid = guid(5000, 111, 300 + i, i), class = "normal", name = "Wolf", level = 5 }) end
check(#out == 0 and sounds == 0, "normal NPCs are quiet")
page("")
need("Layer:|r 5000-111", "layer from the common server/zone pair")
check(rows() == nil, "first guess isn't a change")

-- A rare on a nameplate: one alert with level and "near you"; your spot saved.
out = {}
plate("nameplate4", { guid = guid(5000, 111, 61, 77), class = "rare", name = "Mother Fang", level = 10 })
need("Rare: Mother Fang (level 10), near you.", "nameplate rare alert")
check(#out == 1 and sounds == 1, "one alert and one sound")
local rec = RareWatchDB.R.rares[61]
check(rec and rec.count == 1 and rec.wx == 5000 and rec.mapID == 37 and rec.where == "Goldshire, Elwynn Forest" and rec.exact == false, "record by NPC ID with your spot")

-- Mouseover and target of the same rare: no repeat, no extra sighting.
out = {}
units.mouseover = units.nameplate4; fire("UPDATE_MOUSEOVER_UNIT")
units.target = units.nameplate4; fire("PLAYER_TARGET_CHANGED")
check(#out == 0 and sounds == 1, "no repeat within 10 minutes")
check(rec.count == 1, "same sighting")

-- 10 minutes later: alerts again and counts again.
clock, gametime = clock + 601, gametime + 601
out = {}
fire("PLAYER_TARGET_CHANGED")
need("Rare: Mother Fang", "alerts again after 10 minutes")
check(rec.count == 2, "second sighting counted")

-- It dies while targeted: killed time noted, no alert. Seeing the corpse later doesn't move it.
units.target.dead = true
clock = clock + 5
out = {}
fire("UNIT_HEALTH", "target")
check(rec.killed == clock and #out == 0, "killed noted from health update")
local killedAt = clock
clock = clock + 30
units.mouseover = units.target; fire("UPDATE_MOUSEOVER_UNIT")
check(rec.killed == killedAt, "corpse seen again keeps the kill time")
units.target.dead = false

-- Elite with a skull level, and a world boss.
out = {}
plate("nameplate5", { guid = guid(5000, 111, 62, 5), class = "rareelite", name = "Gnasher", level = -1 })
need("Rare: Gnasher (level ?? elite), near you.", "skull elite")
plate("nameplate6", { guid = guid(5000, 111, 63, 6), class = "worldboss", name = "Azuregos", level = 63 })
need("(level 63 world boss)", "world boss")

-- Players and non-creatures are ignored; secret values neither error nor record.
out = {}
plate("nameplate7", { guid = "Player-1234-00ABCDEF", class = "rare", name = "Someone", level = 10, player = true })
plate("nameplate8", { guid = guid(5000, 111, 64, 8), class = SECRET, name = "Hidden", level = 10 })
plate("nameplate9", { guid = guid(5000, 111, 65, 9), class = "rare", name = SECRET, level = SECRET })
check(#out == 0, "nothing for players or secrets")
check(RareWatchDB.R.rares[64] == nil and RareWatchDB.R.rares[65] == nil, "secret rares not recorded")
local okSecret = pcall(fire, "NAME_PLATE_UNIT_ADDED", SECRET)
check(okSecret, "secret unit token ignored")

-- A minimap marker: the rare's own spot is known, so the alert gives distance and direction.
out = {}
markers.v1 = { name = "Old Vicejaw", atlasName = "VignetteKill", onMinimap = true, objectGUID = guid(5000, 111, 70, 10) }
positions.v1 = { 0.5085, 0.4915 }
fire("VIGNETTE_MINIMAP_UPDATED", "v1", true)
need("Rare nearby: Old Vicejaw, 120 yd north-east. Look for it on your minimap.", "marker alert with bearing")
local vic = RareWatchDB.R.rares[70]
check(vic and vic.exact == true and math.abs(vic.x - 0.5085) < 1e-9, "marker spot saved")
-- Seen up close a moment later: your spot doesn't overwrite the real one, and no second alert.
out = {}
plate("nameplate10", { guid = guid(5000, 111, 70, 10), class = "rare", name = "Old Vicejaw", level = 12 })
check(#out == 0, "no unit alert right after the marker alert")
check(vic.exact == true and vic.level == 12, "exact spot kept, level filled in")
-- The marker shows it dead.
clock = clock + 10
markers.v1.isDead = true
fire("VIGNETTES_UPDATED")
check(vic.killed == clock, "dead marker notes the kill")
markers.v1 = nil

-- A marker without a creature ID is kept by name, then merged once seen up close.
markers.v2 = { name = "Lone Raptor", atlasName = "VignetteKillElite", onMinimap = true, objectGUID = SECRET }
fire("VIGNETTE_MINIMAP_UPDATED", "v2", true)
check(RareWatchDB.R.rares["name:Lone Raptor"] ~= nil, "kept by name")
plate("nameplate11", { guid = guid(5000, 111, 71, 11), class = "rareelite", name = "Lone Raptor", level = 20 })
check(RareWatchDB.R.rares["name:Lone Raptor"] == nil and RareWatchDB.R.rares[71] and RareWatchDB.R.rares[71].count == 1, "merged into the NPC ID record")
markers.v2 = nil
fire("VIGNETTES_UPDATED")

-- Page: newest first, numbered, distance; old ones only on "all".
RareWatchDB.R.rares[99] = { name = "Ancient One", level = 30, seen = clock - 200000, count = 1, mapID = 37, x = 0.1, y = 0.1, continent = 13, wx = 1000, wy = 1000, where = "Far Away" }
px, py = 0.51, 0.5
page("")
need("Rares seen in the last day", "recent heading")
need("1.|r Lone Raptor (level 20 elite)", "newest first")
need("Mother Fang (level 10), Goldshire, Elwynn Forest", "older rare listed")
need("killed", "kill time shown")
need("2 sightings", "sighting count shown")
need("100 yd away", "distance from you")
check(not has("Ancient One"), "older than a day hidden")
need("6 rare(s) remembered. Type all", "count and hint")
page("all")
need("Every rare remembered", "all heading")
need("6.|r Ancient One", "all includes old ones, numbered after recent")

-- Pin by number.
page("6")
need("Pinned Ancient One: Far Away", "pin")
check(waypoints[#waypoints].uiMapID == 37 and waypoints[#waypoints].x == 0.1 and supertracked == 1, "waypoint set and tracked")
page("1")
need("(where you stood when you saw it)", "pin of your own spot says so")
page("42")
need("no rare with that number", "bad number")
C_Map.CanSetUserWaypointOnMap = function() return false end
page("6")
need("can't be pinned", "map refuses pins")
C_Map.CanSetUserWaypointOnMap = function() return true end
page("bogus")
need("Type a number to pin", "help line")

-- Layer change inside the same zone: needs 3 NPCs on the new layer.
for i = 1, 2 do plate("np" .. i, { guid = guid(5000, 222, 400 + i, 100 + i), class = "normal", name = "Boar", level = 6 }) end
check(rows() == nil, "two stray NPCs aren't a change")
-- The same NPC seen again doesn't count twice.
plate("np2", units.np2)
check(rows() == nil, "repeat GUIDs ignored")
plate("np3", { guid = guid(5000, 222, 403, 103), class = "normal", name = "Boar", level = 6 })
plate("np4", { guid = guid(5000, 222, 404, 104), class = "normal", name = "Boar", level = 6 })
plate("np5", { guid = guid(5000, 222, 405, 105), class = "normal", name = "Boar", level = 6 })
plate("np6", { guid = guid(5000, 222, 406, 106), class = "normal", name = "Boar", level = 6 })
local row = rows()
check(row and row.text == "|cff88bbeeLayer|r changed" and row.page == "Rares", "layer changed row")
page("")
need("Layer:|r 5000-222", "page shows the new layer")
need("Layer changed|r from 5000-111 to 5000-222", "page notes the change")
gametime = gametime + 301
check(rows() == nil, "change row fades")

-- A new zone starts over: no change row for the new zone's IDs.
fire("ZONE_CHANGED_NEW_AREA")
page("")
need("Layer:|r unknown", "reset on zone change")
for i = 1, 4 do plate("z" .. i, { guid = guid(5000, 333, 500 + i, 200 + i), class = "normal", name = "Kobold", level = 3 }) end
check(rows() == nil, "zone change isn't a layer change")

-- Secret GUIDs: unknown.
fire("ZONE_CHANGED_NEW_AREA")
units.target = { guid = SECRET, class = "rare", name = "X", level = 1 }
fire("PLAYER_TARGET_CHANGED")
page("")
need("Layer:|r unknown |cff999999(the game is hiding NPC IDs right now)", "secret GUIDs give unknown")

-- Cap at 300 by last seen.
for i = 1, 310 do
    clock = clock + 1
    plate("cap", { guid = guid(5000, 333, 1000 + i, 1000 + i), class = "rare", name = "Cap " .. i, level = 1 })
end
local count = 0
for _ in pairs(RareWatchDB.R.rares) do count = count + 1 end
check(count == 300, "capped at 300, got " .. count)
check(RareWatchDB.R.rares[99] == nil and RareWatchDB.R.rares[1310] ~= nil, "oldest dropped, newest kept")

-- Forget all.
page("forget all")
need("Forgot 300 rare(s).", "forget all")
need("No rares remembered yet", "empty after forget")
check(next(RareWatchDB.R.rares) == nil, "saved list emptied")

-- Without the hub: silent, no errors, no chat.
ForeverHub_Receive = nil
gametime = gametime + 1000
local okQuiet = pcall(plate, "q1", { guid = guid(5000, 333, 2000, 1), class = "rare", name = "Quiet One", level = 5 })
check(okQuiet and chat == 0, "silent without the hub")
local okPage = pcall(SlashCmdList.RAREWATCH, "")
check(okPage, "page without the hub is quiet")
ForeverHub_Receive = function(_, t) out[#out + 1] = t end

-- Saved data from an older shape loads.
RareWatchDB = { R = { rares = "junk" } }
fire("PLAYER_LOGIN")
check(type(RareWatchDB.R.rares) == "table", "bad saved data replaced")

-- Missing APIs: nothing errors.
C_Map, UnitGUID = nil, nil
local okMissing = pcall(function()
    fire("PLAYER_TARGET_CHANGED")
    SlashCmdList.RAREWATCH("")
    fire("VIGNETTES_UPDATED")
end)
check(okMissing, "missing APIs are fine")

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_rarewatch: all checks passed")
