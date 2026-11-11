-- Review 4, note 14 (RareWatch): a watch-list entry added by name keeps matching that name after it learned an
-- NPC ID, so a second NPC with the same name and another ID is caught too (its ID is learned as well, at most
-- 10 extra). An entry added by NPC ID matches only that NPC. Mocks copied from test_r4c_rarewatch_watch.lua.
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
-- 1. Added by name: the first NPC ID is learned, and a second NPC with the same name still matches.
page("watch Mottled Boar")
units.mouseover = { guid = "Creature-0-1-0-12-3098-0000000001", name = "Mottled Boar", level = 3 }
out = {}
fire("UPDATE_MOUSEOVER_UNIT")
need("Watched: Mottled Boar (3), near you", "first NPC")
local entry = RareWatchDB.watch[1]
assert(entry.id == 3098, "first ID learned: " .. tostring(entry.id))
clock = clock + 700
units.mouseover = { guid = "Creature-0-1-0-12-1984-0000000002", name = "Mottled Boar", level = 5 }
out = {}
fire("UPDATE_MOUSEOVER_UNIT")
need("Watched: Mottled Boar (5), near you", "a second NPC with the same name and another ID")
assert(entry.id == 3098, "the first ID stays")
local found = false
for _, id in ipairs(entry.ids or {}) do if id == 1984 then found = true end end
assert(found, "the second ID is learned too")
-- Both IDs keep matching under another name (another client language).
clock = clock + 700
units.mouseover = { guid = "Creature-0-1-0-12-1984-0000000003", name = "Jabali moteado", level = 5 }
out = {}
fire("UPDATE_MOUSEOVER_UNIT")
need("Watched: Jabali moteado", "second ID matched under another name")
print("1 ok")

-- 2. Added by NPC ID: only that NPC, even after its name is learned.
page("watch 1234")
clock = clock + 700
units.mouseover = { guid = "Creature-0-1-0-12-1234-0000000004", name = "Old Murk-Eye", level = 20 }
out = {}
fire("UPDATE_MOUSEOVER_UNIT")
need("Watched: Old Murk-Eye", "by ID")
clock = clock + 700
units.mouseover = { guid = "Creature-0-1-0-12-5555-0000000005", name = "Old Murk-Eye", level = 20 }
out = {}
fire("UPDATE_MOUSEOVER_UNIT")
assert(not has("Watched"), "an ID entry doesn't match another NPC by name: " .. table.concat(out, "\n"))
print("2 ok")

-- 3. The learned IDs are bounded.
for i = 1, 30 do
    clock = clock + 700
    units.mouseover = { guid = "Creature-0-1-0-12-" .. (6000 + i) .. "-0000000006", name = "Mottled Boar", level = 3 }
    fire("UPDATE_MOUSEOVER_UNIT")
end
assert(#(entry.ids or {}) <= 10, "at most 10 extra IDs: " .. #(entry.ids or {}))
print("ALL TESTS PASSED")
