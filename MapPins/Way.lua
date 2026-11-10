-- /way: pins any spot by its map coordinates, the way guides and websites write them, through the shared
-- Forever waypoint (the game's own map pin, tracked, so its on-screen marker points there; cleared on arrival).
--   /way 45.2 58.5               a spot on the zone you're in
--   /way Darkshore 45.2 58.5     a spot on a zone or city by name ("dark" is enough when it's the only match)
--   /way 45.2, 58.5 Jai'vhanel   anything after the numbers is the pin's name
--   /way clear                   removes the pin it set
-- It only places a map pin, which you could do by hand: nothing else changes.

local SOURCE = "MapPins"
local ZONE_TYPE = 3   -- Enum.UIMapType.Zone; cities on Forever's Classic maps are zones too

local byName

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        ForeverHub_Receive(SOURCE, text)
    end
end

-- Every zone and city map by lower-case name, read once from the world map's own list.
local function MapsByName()
    if byName then
        return byName
    end
    local found = {}
    if C_Map and C_Map.GetMapChildrenInfo then
        local zoneType = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or ZONE_TYPE
        local ok, children = pcall(C_Map.GetMapChildrenInfo, 947, zoneType, true)
        for _, info in ipairs(ok and type(children) == "table" and children or {}) do
            local name, mapID = Safe(info.name), Safe(info.mapID)
            if type(name) == "string" and type(mapID) == "number" then
                found[name:lower()] = found[name:lower()] or mapID
            end
        end
    end
    -- Only keep a list that has something in it: it can be empty for a moment after a load.
    if next(found) then
        byName = found
    end
    return found
end

-- A map ID by name: exact, else the only name that starts with it. nil plus the candidates when unclear.
local function FindMap(text)
    local want = text:lower()
    local maps = MapsByName()
    if maps[want] then
        return maps[want]
    end
    local matches = {}
    for name, mapID in pairs(maps) do
        if name:sub(1, #want) == want then
            matches[#matches + 1] = { name = name, mapID = mapID }
        end
    end
    if #matches == 1 then
        return matches[1].mapID
    end
    table.sort(matches, function(a, b) return a.name < b.name end)
    return nil, matches
end

local function CurrentMap()
    return C_Map and C_Map.GetBestMapForUnit and Safe(C_Map.GetBestMapForUnit("player"))
end

local function MapName(mapID)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return info and Safe(info.name) or ("map " .. tostring(mapID))
end

-- zone text (may be empty), x, y (0-100) and the rest as a name, or nil when no two numbers are found.
local function Parse(text)
    -- Commas between numbers are what websites write ("45.2, 58.5").
    local cleaned = text:gsub("(%d),(%s*%d)", "%1 %2")
    local before, x, y, after = cleaned:match("^(.-)%s*(%d+%.?%d*)%s+(%d+%.?%d*)%s*(.*)$")
    if not x then
        return nil
    end
    return before, tonumber(x), tonumber(y), after
end

local function Help()
    Print("Pin a spot: /way 45.2 58.5 for this zone, or /way Darkshore 45.2 58.5. Add a name after the numbers. /way clear removes it.")
end

local function Way(message)
    local text = type(message) == "string" and message:match("^%s*(.-)%s*$") or ""
    if text == "" then
        return Help()
    end
    if text:lower() == "clear" then
        local active = ForeverWaypoint_Active and ForeverWaypoint_Active()
        if active and C_Map and C_Map.ClearUserWaypoint then
            pcall(C_Map.ClearUserWaypoint)
            Print("Map pin cleared.")
        else
            Print("No pin of ours to clear.")
        end
        return
    end
    local zone, x, y, label = Parse(text)
    if not x then
        return Help()
    end
    if x > 100 or y > 100 then
        Print("Coordinates go from 0 to 100, like 45.2 58.5.")
        return
    end
    local mapID
    if zone and zone ~= "" then
        local matches
        mapID, matches = FindMap(zone)
        if not mapID then
            if matches and #matches > 1 then
                local names = {}
                for index = 1, math.min(#matches, 5) do
                    names[index] = matches[index].name
                end
                Print("More than one map starts with \"" .. zone .. "\": " .. table.concat(names, ", ") .. ". Type more of the name.")
            else
                Print("No zone or city called \"" .. zone .. "\".")
            end
            return
        end
    else
        mapID = CurrentMap()
        if not mapID then
            Print("Where you are can't be read right now; add the zone name: /way Darkshore 45.2 58.5")
            return
        end
    end
    local name = label ~= "" and label or nil
    local ok, why = false, "api"
    if ForeverWaypoint_Set then
        ok, why = ForeverWaypoint_Set(mapID, x / 100, y / 100, name)
    end
    if ok then
        Print(string.format("Pinned %s%s %.1f, %.1f. The game's map pin and on-screen marker point there.",
            name and (name .. ", ") or "", MapName(mapID), x, y))
    elseif why == "map" then
        Print("The game doesn't allow a map pin on " .. MapName(mapID) .. " (instances and some cities).")
    else
        Print("The game refused the map pin.")
    end
end

SLASH_FOREVERWAY1 = "/way"
SLASH_FOREVERWAY2 = "/fway"
SlashCmdList.FOREVERWAY = Way

-- For tests and other helpers.
ForeverWay_Parse = Parse
