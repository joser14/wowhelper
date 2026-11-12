-- Nodes: the herb, ore and fishing spots you have gathered from, as small icons on the world map and the
-- minimap (round 6 #4, research\re_round6.md). GatherMate2 was read for ideas only; this is our own code.
--
-- How a spot is found (reads only; nothing is cast, tracked, moved or clicked for you):
--   * UNIT_SPELLCAST_SUCCEEDED for "player" with a gathering spell (Herb Gathering, Mining, Fishing; matched by
--     spell ID, or else by the spell's name) and your map position at that moment (C_Map.GetBestMapForUnit +
--     C_Map.GetPlayerMapPosition). The node's name comes from the matching UNIT_SPELLCAST_SENT target
--     ("Peacebloom", "Copper Vein"); that is secret in combat, so it is read through Safe() and simply left out.
--   * Fishing is a channel: its success only starts the cast, so the spot is kept only when a fishing loot window
--     follows (LOOT_OPENED, IsFishingLoot() where the client has it) within FISH_SECONDS.
--   * A position that is secret, nil or 0,0 (instances, loading) is skipped.
-- Spots within MERGE_YARDS of one you already have (same kind, same map) are merged and counted. Bounded:
-- MAX_SPOTS per kind per map and MAX_ZONES maps; when full, the spot (or map) you used longest ago goes.
--
-- Drawing: Nodes owns no map frames. It hands its spots to MapPins (MapPins_RegisterLayer), which draws them as
-- its own overlay frames over the world map and its own minimap buttons, never in Blizzard's map canvas. Each
-- kind is its own layer, switched here (NodesDB.layers) or on the Map pins page. Never registers COMBAT_LOG_*.

local MERGE_YARDS = 15
local MERGE_FRACTION = 0.005    -- when the map's size in yards is unknown
local MAX_SPOTS = 40            -- per kind per map
local MAX_ZONES = 40
local NAME_SECONDS = 10         -- a SENT target belongs to the SUCCEEDED that follows within this
local FISH_SECONDS = 35         -- a fishing cast's loot window comes within this

local KINDS = {
    { key = "herb", layer = "herbs", label = "Herbs", noun = "Herb",
      icon = { file = "Interface\\Icons\\INV_Misc_Flower_02", size = 12 } },
    { key = "ore", layer = "ore", label = "Ore", noun = "Ore vein",
      icon = { file = "Interface\\Icons\\INV_Ore_Copper_01", size = 12 } },
    { key = "fish", layer = "fishing", label = "Fishing spots", noun = "Fishing spot",
      icon = { file = "Interface\\Icons\\INV_Misc_Fish_02", size = 12 } },
}
local KIND = {}
for _, kind in ipairs(KINDS) do
    KIND[kind.key] = kind
end

-- Classic-era gathering casts (Apprentice to Artisan). A spell not listed is matched by its name.
local GATHER_SPELLS = {
    [2366] = "herb", [2368] = "herb", [3570] = "herb", [11993] = "herb",
    [2575] = "ore", [2576] = "ore", [3564] = "ore", [10248] = "ore",
    [7620] = "fish", [7731] = "fish", [7732] = "fish", [18248] = "fish",
}
local NAME_FROM = { herb = 2366, ore = 2575, fish = 7620 }
local ENGLISH = { ["Herb Gathering"] = "herb", ["Mining"] = "ore", ["Fishing"] = "fish" }

local db
local version = 0               -- bumped on every change; MapPins looks at it once a second
local kindOf = {}               -- spellID -> kind or false (only spells you cast)
local byName                    -- localized gathering spell name -> kind, made on first need
local sizes = {}                -- mapID -> { width, height } in yards, or false
local records = setmetatable({}, { __mode = "k" })   -- saved spot -> its map pin record (rebuilt when it changes)
local sent = { kind = nil, name = nil, at = 0 }      -- the last gathering UNIT_SPELLCAST_SENT, reused
local fishing = { at = nil, mapID = nil, x = nil, y = nil }   -- a fishing cast waiting for its loot, reused

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Call(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b = pcall(fn, ...)
    if not ok then
        return nil
    end
    return Safe(a), Safe(b)
end

local function Text(value)
    value = Safe(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("Nodes", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function IsOff()
    return ForeverHub_IsOff and ForeverHub_IsOff("Nodes") and true or false
end

local function Now()
    return GetTime and Safe(GetTime()) or 0
end

local function Stamp()
    return time and Safe(time()) or 0
end

local function MapName(mapID)
    local info = C_Map and Call(C_Map.GetMapInfo, mapID)
    return type(info) == "table" and Text(info.name) or ("Map " .. tostring(mapID))
end

-- Refresh MapPins' drawing now (it would also notice within a second).
local function Changed()
    version = version + 1
    if type(MapPins_Refresh) == "function" then
        pcall(MapPins_Refresh)
    end
end

---------------------------------------------------------------------------- which cast

local function SpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        return Text((Call(C_Spell.GetSpellName, spellID)))
    end
    if GetSpellInfo then
        return Text((Call(GetSpellInfo, spellID)))
    end
end

-- "herb", "ore", "fish" or nil for one of your casts.
local function KindOfSpell(spellID)
    spellID = Safe(spellID)
    if type(spellID) ~= "number" then
        return nil
    end
    if GATHER_SPELLS[spellID] then
        return GATHER_SPELLS[spellID]
    end
    local known = kindOf[spellID]
    if known == nil then
        if not byName then
            byName = {}
            for name, kind in pairs(ENGLISH) do
                byName[name] = kind
            end
            for kind, id in pairs(NAME_FROM) do
                local name = SpellName(id)
                if name then
                    byName[name] = kind
                end
            end
        end
        local name = SpellName(spellID)
        known = name and byName[name] or false
        kindOf[spellID] = known
    end
    return known or nil
end

-- Your map and position now, or nil (instances, secret values, loading screens).
local function Position()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
        return nil
    end
    local mapID = Call(C_Map.GetBestMapForUnit, "player")
    if type(mapID) ~= "number" then
        return nil
    end
    local position = Call(C_Map.GetPlayerMapPosition, mapID, "player")
    if type(position) ~= "table" then
        return nil
    end
    local x, y = Safe(position.x), Safe(position.y)
    if type(x) ~= "number" and position.GetXY then
        x, y = Call(position.GetXY, position)
    end
    if type(x) ~= "number" or type(y) ~= "number" or x < 0 or x > 1 or y < 0 or y > 1 or (x == 0 and y == 0) then
        return nil
    end
    return mapID, x, y
end

---------------------------------------------------------------------------- saved spots

-- Width and height of a map in yards, or nil.
local function Size(mapID)
    if sizes[mapID] == nil then
        sizes[mapID] = false
        if C_Map and C_Map.GetMapWorldSize then
            local w, h = Call(C_Map.GetMapWorldSize, mapID)
            if type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
                sizes[mapID] = { w, h }
            end
        end
    end
    return sizes[mapID] or nil
end

-- True when two points of a map are within MERGE_YARDS.
function Nodes_Near(mapID, ax, ay, bx, by)
    local size = Size(mapID)
    if size then
        local dx, dy = (ax - bx) * size[1], (ay - by) * size[2]
        return dx * dx + dy * dy <= MERGE_YARDS * MERGE_YARDS
    end
    local dx, dy = (ax - bx) * 1.5, ay - by
    return dx * dx + dy * dy <= MERGE_FRACTION * MERGE_FRACTION
end

local function CountZones()
    local n, oldestID, oldest = 0, nil, nil
    for mapID, zone in pairs(db.zones) do
        n = n + 1
        local touched = type(zone) == "table" and tonumber(zone.touched) or 0
        if not oldest or touched < oldest then
            oldestID, oldest = mapID, touched
        end
    end
    return n, oldestID
end

-- Keeps a gathered spot. Returns the saved spot (new or merged), or nil.
function Nodes_Record(kind, mapID, x, y, name)
    if not (db and KIND[kind] and type(mapID) == "number" and type(x) == "number" and type(y) == "number") then
        return nil
    end
    local zone = db.zones[mapID]
    if type(zone) ~= "table" then
        local n, oldestID = CountZones()
        if n >= MAX_ZONES and oldestID then
            -- Full: the map you gathered on longest ago makes room.
            for _, spots in pairs(db.zones[oldestID]) do
                if type(spots) == "table" then
                    for _, spot in ipairs(spots) do
                        records[spot] = nil
                    end
                end
            end
            db.zones[oldestID] = nil
        end
        zone = {}
        db.zones[mapID] = zone
    end
    local spots = type(zone[kind]) == "table" and zone[kind] or {}
    zone[kind] = spots
    local now = Stamp()
    zone.touched = now
    for _, spot in ipairs(spots) do
        if Nodes_Near(mapID, x, y, spot.x, spot.y) then
            spot.n = (tonumber(spot.n) or 1) + 1
            spot.last = now
            spot.name = name or spot.name
            records[spot] = nil
            Changed()
            return spot
        end
    end
    if #spots >= MAX_SPOTS then
        local oldestIndex, oldest = 1, nil
        for index, spot in ipairs(spots) do
            local last = tonumber(spot.last) or 0
            if not oldest or last < oldest then
                oldestIndex, oldest = index, last
            end
        end
        records[spots[oldestIndex]] = nil
        table.remove(spots, oldestIndex)
    end
    local spot = { x = x, y = y, name = name, n = 1, last = now }
    spots[#spots + 1] = spot
    Changed()
    return spot
end

-- Saved data as read at login: malformed entries dropped, everything bounded.
local function Clean()
    db.layers = type(db.layers) == "table" and db.layers or {}
    db.zones = type(db.zones) == "table" and db.zones or {}
    local zones = 0
    for mapID, zone in pairs(db.zones) do
        if type(mapID) ~= "number" or type(zone) ~= "table" or zones >= MAX_ZONES then
            db.zones[mapID] = nil
        else
            zones = zones + 1
            for key, spots in pairs(zone) do
                if KIND[key] then
                    local kept = {}
                    for _, spot in ipairs(type(spots) == "table" and spots or {}) do
                        if type(spot) == "table" and type(spot.x) == "number" and type(spot.y) == "number"
                            and spot.x >= 0 and spot.x <= 1 and spot.y >= 0 and spot.y <= 1 and #kept < MAX_SPOTS then
                            spot.name = type(spot.name) == "string" and spot.name:sub(1, 60) or nil
                            kept[#kept + 1] = spot
                        end
                    end
                    zone[key] = kept
                elseif key ~= "touched" then
                    zone[key] = nil
                end
            end
        end
    end
end

---------------------------------------------------------------------------- layers on MapPins

local function Wanted(kind)
    return db ~= nil and db.layers[kind] ~= false
end

function Nodes_SetLayer(kind, on)
    if not (db and KIND[kind]) then
        return false
    end
    db.layers[kind] = on and true or false
    Changed()
    return true
end

local function When(seconds)
    if type(seconds) ~= "number" or seconds <= 0 or not date then
        return nil
    end
    return date("%Y-%m-%d %H:%M", seconds)
end

-- The map pin record of a saved spot: kept (and so is MapPins' world-position cache on it) until the spot changes.
local function RecordOf(kind, mapID, spot)
    local record = records[spot]
    if not record then
        local info = KIND[kind]
        local times = tonumber(spot.n) or 1
        local last = When(spot.last)
        record = {
            mapID = mapID, x = spot.x, y = spot.y, icon = info.icon,
            title = spot.name or info.noun,
            lines = { string.format("%s you gathered here %d time%s", info.noun, times, times == 1 and "" or "s"),
                last and ("Last: " .. last) or nil },
        }
        records[spot] = record
    end
    return record
end

local function Register()
    if type(MapPins_RegisterLayer) ~= "function" then
        return
    end
    for _, info in ipairs(KINDS) do
        local key = info.key
        MapPins_RegisterLayer({
            key = info.layer, label = info.label, helper = "Nodes", icon = info.icon, rank = 10,
            wanted = function() return Wanted(key) end,
            setWanted = function(on) Nodes_SetLayer(key, on) end,
            stamp = function() return version end,
            available = function() return db ~= nil end,
            records = function(add)
                if not db or IsOff() then
                    return
                end
                for mapID, zone in pairs(db.zones) do
                    local spots = type(zone) == "table" and zone[key]
                    if type(spots) == "table" then
                        for _, spot in ipairs(spots) do
                            add(RecordOf(key, mapID, spot))
                        end
                    end
                end
            end,
        })
    end
end

---------------------------------------------------------------------------- page

local function Counts(zone)
    local herb = type(zone) == "table" and type(zone.herb) == "table" and #zone.herb or 0
    local ore = type(zone) == "table" and type(zone.ore) == "table" and #zone.ore or 0
    local fish = type(zone) == "table" and type(zone.fish) == "table" and #zone.fish or 0
    return herb, ore, fish
end

-- The most-gathered names of one kind in a zone, for the page.
local function TopNames(spots)
    local count = {}
    for _, spot in ipairs(type(spots) == "table" and spots or {}) do
        if spot.name then
            count[spot.name] = (count[spot.name] or 0) + (tonumber(spot.n) or 1)
        end
    end
    local names = {}
    for name in pairs(count) do
        names[#names + 1] = name
    end
    table.sort(names, function(a, b)
        if count[a] ~= count[b] then
            return count[a] > count[b]
        end
        return a < b
    end)
    local parts = {}
    for index = 1, math.min(4, #names) do
        parts[index] = string.format("%s x%d", names[index], count[names[index]])
    end
    return table.concat(parts, ", ")
end

local function ShowPage(arg)
    if not db then
        return
    end
    local words = {}
    for word in (arg or ""):lower():gmatch("%S+") do
        words[#words + 1] = word
    end
    local verb, what = words[1], words[2]
    local aliases = { herb = "herb", herbs = "herb", ore = "ore", mining = "ore", fish = "fish", fishing = "fish" }
    if (verb == "on" or verb == "off" or verb == "toggle") and aliases[what or ""] then
        local kind = aliases[what]
        local on = verb == "on" or (verb == "toggle" and not Wanted(kind))
        Nodes_SetLayer(kind, on)
        Print(string.format("%s on your maps: %s.", KIND[kind].label, on and "on" or "off"))
    elseif verb and verb ~= "all" then
        Print("Type: off herbs   Or: on ore   Or: toggle fishing   Or: all")
    end
    Print("|cffffd100Gathering spots you've used|r |cff999999(drawn by Map pins on your world map and minimap)|r")
    local layers = {}
    for _, info in ipairs(KINDS) do
        layers[#layers + 1] = info.label .. ": " .. (Wanted(info.key) and "on" or "|cff999999off|r")
    end
    Print(table.concat(layers, "   "))
    if type(MapPins_RegisterLayer) ~= "function" then
        Print("|cffff6060MapPins isn't loaded, so nothing is drawn; spots are still remembered.|r")
    elseif ForeverHub_IsOff and ForeverHub_IsOff("MapPins") then
        Print("|cffff6060MapPins is switched off on the hub, so nothing is drawn.|r")
    end
    local here = Position()
    if verb == "all" then
        local ids = {}
        for mapID in pairs(db.zones) do
            ids[#ids + 1] = mapID
        end
        table.sort(ids, function(a, b) return MapName(a) < MapName(b) end)
        if #ids == 0 then
            Print("|cff999999Nothing yet. Gather an herb, mine a vein or catch a fish and the spot is kept.|r")
        end
        for _, mapID in ipairs(ids) do
            local herb, ore, fish = Counts(db.zones[mapID])
            Print(string.format("|cffffd100%s:|r %d herb, %d ore, %d fishing spot%s", MapName(mapID), herb, ore, fish,
                fish == 1 and "" or "s"))
        end
        return
    end
    if not here then
        Print("|cff999999Your position can't be read here. Type: all   for every zone.|r")
        return
    end
    local zone = db.zones[here]
    local herb, ore, fish = Counts(zone)
    Print(string.format("|cffffd100%s:|r %d herb, %d ore and %d fishing spot%s", MapName(here), herb, ore, fish,
        fish == 1 and "" or "s"))
    for _, info in ipairs(KINDS) do
        local names = zone and TopNames(zone[info.key]) or ""
        if names ~= "" then
            Print(string.format("  %s: %s", info.label, names))
        end
    end
    if herb + ore + fish == 0 then
        Print("|cff999999Nothing here yet. Gather an herb, mine a vein or catch a fish and the spot is kept.|r")
    end
end

SLASH_NODES1 = "/nodes"
SlashCmdList.NODES = ShowPage

---------------------------------------------------------------------------- events

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("LOOT_OPENED")
-- Registered for "player" only, every cast event is your own, even when its unit token is secret
-- (SecretWhenUnitSpellCastRestricted); only the all-units fallback has to read the token.
local playerOnly = events.RegisterUnitEvent
    and pcall(events.RegisterUnitEvent, events, "UNIT_SPELLCAST_SUCCEEDED", "player")
    and pcall(events.RegisterUnitEvent, events, "UNIT_SPELLCAST_SENT", "player") or false
if not playerOnly then
    pcall(events.RegisterEvent, events, "UNIT_SPELLCAST_SUCCEEDED")
    pcall(events.RegisterEvent, events, "UNIT_SPELLCAST_SENT")
end

local function Mine(unit)
    return playerOnly or Safe(unit) == "player"
end

events:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
    if event == "PLAYER_LOGIN" then
        NodesDB = type(NodesDB) == "table" and NodesDB or {}
        db = NodesDB
        Clean()
        Register()
        Changed()
        return
    end
    if not db or IsOff() then
        return
    end
    if event == "UNIT_SPELLCAST_SENT" then
        -- unit, target, castGUID, spellID
        local kind = Mine(a1) and KindOfSpell(a4)
        if kind then
            sent.kind, sent.name, sent.at = kind, Text(a2), Now()
            if sent.name then
                sent.name = sent.name:sub(1, 60)
            end
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- unit, castGUID, spellID
        local kind = Mine(a1) and KindOfSpell(a3)
        if not kind then
            return
        end
        local mapID, x, y = Position()
        if not mapID then
            return
        end
        local now = Now()
        if kind == "fish" then
            fishing.at, fishing.mapID, fishing.x, fishing.y = now, mapID, x, y
            return
        end
        local name = sent.kind == kind and now - (sent.at or 0) <= NAME_SECONDS and sent.name or nil
        sent.kind, sent.name = nil, nil
        Nodes_Record(kind, mapID, x, y, name)
    elseif event == "LOOT_OPENED" then
        if not fishing.at then
            return
        end
        local fresh = Now() - fishing.at <= FISH_SECONDS
        local fish = true
        if IsFishingLoot then
            fish = Call(IsFishingLoot) and true or false
        end
        if fresh and fish then
            Nodes_Record("fish", fishing.mapID, fishing.x, fishing.y, nil)
        end
        fishing.at, fishing.mapID, fishing.x, fishing.y = nil, nil, nil, nil
    end
end)

-- Switched Off on the hub: nothing is recorded and every spot leaves the maps at once; On brings them back.
ForeverHubOnSwitch = ForeverHubOnSwitch or {}
ForeverHubOnSwitch.Nodes = function()
    Changed()
end
