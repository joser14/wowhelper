-- Round 3 #14: RareWatch rescans nameplates, target, mouseover and minimap markers once combat ends
-- (the game hides IDs and names in combat), and knows the verified Forever rares of Zephras Isle:
-- one is recognised by NPC ID even when its classification is hidden, and the page lists the known
-- rares of your zone you haven't seen yet.
local base = ADDON_PATH
local frames, out = {}, {}
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
local SECRET = {}
local hiding = false   -- combat: the game hides unit values
issecretvalue = function(v) return v == SECRET end
GetRealmName = function() return "R" end
local clock = 100000
time = function() return clock end
GetTime = function() return clock end
GetZoneText = function() return "Zephras Isle" end
GetSubZoneText = function() return "" end
SOUNDKIT = { RAID_WARNING = 1 }
PlaySound = function() end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
local here = 2521
C_Map = {
    GetBestMapForUnit = function() return here end,
    GetMapInfo = function(id) if id == 2521 or id == 2665 then return { name = "Zephras Isle" } end return { name = "Elwynn Forest" } end,
}

local units = {}
local function hide(v) if hiding then return SECRET end return v end
UnitExists = function(u) return units[u] ~= nil end
UnitGUID = function(u) return units[u] and hide(units[u].guid) end
UnitClassification = function(u) return units[u] and (units[u].classHidden and SECRET or hide(units[u].class or "normal")) end
UnitName = function(u) return units[u] and hide(units[u].name) end
UnitLevel = function(u) return units[u] and hide(units[u].level) end
UnitIsDead = function() return false end
UnitIsPlayer = function() return false end

local markers = {}
C_VignetteInfo = {
    GetVignettes = function() local list = {} for guid in pairs(markers) do list[#list + 1] = guid end return list end,
    GetVignetteInfo = function(guid) local m = markers[guid] if m then return { name = hide(m.name), atlasName = "VignetteKill", onMinimap = true } end end,
}

assert(loadfile(base .. "/RareWatch/RareWatch.lua"))("RareWatch", {})
local f = frames[1]
local function fire(ev, ...) f.fn(f, ev, ...) end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function need(text, why) assert(has(text), why .. ": wanted '" .. text .. "' in:\n" .. table.concat(out, "\n")) end
fire("PLAYER_LOGIN")
assert(f.registered.PLAYER_REGEN_ENABLED, "listens for the end of combat")

-- 1. In combat a nameplate rare is hidden; once combat ends it's picked up.
hiding = true
units.nameplate3 = { guid = "Creature-0-1-0-12-4242-0000000001", class = "rare", name = "Hidden Rare", level = 9 }
fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
assert(next(RareWatchDB.R.rares) == nil, "nothing readable in combat")
hiding = false
out = {}
fire("PLAYER_REGEN_ENABLED")
assert(RareWatchDB.R.rares[4242], "nameplate rare picked up after combat")
need("Rare: Hidden Rare", "alert after combat")

-- 2. A minimap marker whose name was hidden in combat alerts after combat.
hiding = true
markers.v1 = { name = "Marker Rare" }
fire("VIGNETTES_UPDATED")
hiding = false
out = {}
fire("PLAYER_REGEN_ENABLED")
need("Rare nearby: Marker Rare", "minimap markers re-read after combat")

-- 3. Verified Forever rare by NPC ID, classification hidden.
units.nameplate3 = nil
clock = clock + 1000
units.target = { guid = "Creature-0-1-0-12-255887-0000000002", classHidden = true, name = "Slydris", level = 6 }
out = {}
fire("PLAYER_TARGET_CHANGED")
assert(RareWatchDB.R.rares[255887], "a known Forever rare is recognised by NPC ID")
need("Rare: Slydris", "alerted")
assert(RareWatchDB.R.rares[255887].class == "rareelite", "class from the verified table")
units.target = nil

-- 4. The page lists known rares of this zone not seen yet.
out = {}
SlashCmdList.RAREWATCH("")
need("Known rares here", "known-rares section on Zephras Isle")
need("Mystmane", "an unseen known rare listed")
local slydrisLine
for _, t in ipairs(out) do if t:find("Known rares here", 1, true) then slydrisLine = t end end
here = 1429
out = {}
SlashCmdList.RAREWATCH("")
assert(not has("Known rares here"), "no known-rares section elsewhere")

-- 5. Public list for MapPins.
assert(type(RareWatch_KnownRares) == "function", "RareWatch_KnownRares for MapPins")
local list = RareWatch_KnownRares()
assert(#list == 7, "seven verified Zephras Isle rares: " .. #list)
for _, rare in ipairs(list) do
    assert(rare.mapID == 2521 and rare.x > 0 and rare.x < 1 and rare.y > 0 and rare.y < 1 and rare.name and rare.npcID, "fields")
end
print("test_r3_rarewatch: ok")
