-- Round 4 item 19 (research\re_round4.md R20, after MobSpot by Archydude, MIT): RareWatch's own watch list.
-- Add an NPC by name or NPC ID on the page; a name match stores the NPC ID, so the entry still matches when the
-- name changes (another client language, a renamed Forever mob). Nameplates, target, mouseover and minimap
-- markers are checked (markers with their distance); any classification counts, players never. No TargetUnit.
local base = ADDON_PATH
local frames, out, sounds = {}, {}, 0
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
local SECRET = {}
local hiding = false
issecretvalue = function(v) return v == SECRET end
GetRealmName = function() return "R" end
local clock = 100000
time = function() return clock end
GetTime = function() return clock end
GetZoneText = function() return "Elwynn Forest" end
GetSubZoneText = function() return "" end
SOUNDKIT = { RAID_WARNING = 1 }
PlaySound = function() sounds = sounds + 1 end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
local function vec(x, y) return { GetXY = function() return x, y end } end
CreateVector2D = vec
C_Map = {
    GetBestMapForUnit = function() return 1429 end,
    GetMapInfo = function() return { name = "Elwynn Forest" } end,
    GetPlayerMapPosition = function() return vec(0.5, 0.5) end,
    GetWorldPosFromMapPos = function(_, v) local x, y = v:GetXY(); return 0, vec(x * 1000, y * 1000) end,
}
local units = {}
local function hide(v) if hiding then return SECRET end return v end
UnitExists = function(u) return units[u] ~= nil end
UnitGUID = function(u) return units[u] and hide(units[u].guid) end
UnitClassification = function(u) return units[u] and hide(units[u].class or "normal") end
UnitName = function(u) return units[u] and hide(units[u].name) end
UnitLevel = function(u) return units[u] and hide(units[u].level or 5) end
UnitIsDead = function() return false end
UnitIsPlayer = function(u) return units[u] and units[u].player or false end
local markers = {}
C_VignetteInfo = {
    GetVignettes = function() local list = {} for guid in pairs(markers) do list[#list + 1] = guid end return list end,
    GetVignetteInfo = function(guid) local m = markers[guid] if m then
        return { name = hide(m.name), atlasName = m.atlas or "VignetteKill", onMinimap = true, objectGUID = hide(m.guid) } end end,
    GetVignettePosition = function(guid) local m = markers[guid] if m then return vec(m.x, m.y) end end,
}
TargetUnit = function() error("TargetUnit must never be used") end

assert(loadfile(base .. "/RareWatch/RareWatch.lua"))("RareWatch", {})
local f = frames[1]
local function fire(ev, ...) f.fn(f, ev, ...) end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function need(text, why) assert(has(text), why .. ": wanted '" .. text .. "' in:\n" .. table.concat(out, "\n")) end
local function page(arg) out = {}; SlashCmdList.RAREWATCH(arg) end
fire("PLAYER_LOGIN")

-- 1. Add by name on the page; it's account-wide and listed.
page("watch Mottled Boar")
need("Watching Mottled Boar", "added")
assert(RareWatchDB.watch and RareWatchDB.watch[1].name == "Mottled Boar" and not RareWatchDB.watch[1].id, "saved by name")
page("")
need("Watch list:|r Mottled Boar", "listed on the page")
print("1 ok")

-- 2. A normal mob with that name on your mouseover: alert, and its NPC ID is learned.
units.mouseover = { guid = "Creature-0-1-0-12-3098-0000000001", name = "Mottled Boar", level = 3 }
out = {}
fire("UPDATE_MOUSEOVER_UNIT")
need("Watched: Mottled Boar (3), near you", "name match alerts")
assert(sounds == 1, "with the sound")
assert(RareWatchDB.watch[1].id == 3098, "NPC ID learned: " .. tostring(RareWatchDB.watch[1].id))
-- Not again right away.
out = {}
fire("UPDATE_MOUSEOVER_UNIT")
assert(#out == 0, "no repeat at once")
print("2 ok")

-- 3. Another name (a translated client, a renamed mob): matched by the learned NPC ID.
clock = clock + 700
units.mouseover = { guid = "Creature-0-1-0-12-3098-0000000002", name = "Jabali moteado", level = 3 }
out = {}
fire("UPDATE_MOUSEOVER_UNIT")
need("Watched: Jabali moteado", "matched by ID")
-- A player with the name never matches; hidden values never match.
units.mouseover = { guid = "Player-1-0000000A", name = "Mottled Boar", player = true }
clock = clock + 700
out = {}
fire("UPDATE_MOUSEOVER_UNIT")
assert(#out == 0, "players never")
hiding = true
units.mouseover = { guid = "Creature-0-1-0-12-3098-0000000003", name = "Mottled Boar" }
out = {}
fire("UPDATE_MOUSEOVER_UNIT")
assert(#out == 0, "nothing while hidden")
hiding = false
units.mouseover = nil
print("3 ok")

-- 4. Add by NPC ID; a minimap marker for it alerts with its distance and the name is learned.
page("watch 1234")
need("Watching NPC 1234", "added by ID")
markers.v9 = { name = "Old Murk-Eye", atlas = "VignetteEvent", guid = "Creature-0-1-0-12-1234-0000000009", x = 0.6, y = 0.5 }
out = {}
fire("VIGNETTES_UPDATED")
need("Watched: Old Murk-Eye on your minimap, about 100 yd", "marker alert with distance")
local entry
for _, e in ipairs(RareWatchDB.watch) do if e.id == 1234 then entry = e end end
assert(entry and entry.name == "Old Murk-Eye", "name learned")
out = {}
fire("VIGNETTES_UPDATED")
assert(#out == 0, "the same marker alerts once")
markers.v9 = nil
print("4 ok")

-- 5. Remove by name (any case) or ID; bad input explains itself.
page("unwatch mottled boar")
need("Stopped watching Mottled Boar", "removed by name")
page("unwatch 1234")
need("Stopped watching Old Murk-Eye", "removed by ID")
assert(#RareWatchDB.watch == 0, "empty")
page("unwatch nobody")
need("Not on your watch list", "unknown")
-- The list is bounded.
for i = 1, 60 do page("watch Mob " .. i) end
assert(#RareWatchDB.watch == 50, "at most 50: " .. #RareWatchDB.watch)
need("watch list is full", "says so")
print("ALL TESTS PASSED")
