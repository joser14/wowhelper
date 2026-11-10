local TOO_HIGH_BY = 3
local MAX_LEVEL = 60
local NOTE_SECONDS = 8

local lastWarned

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

-- Our own level ranges, for when the game has none: on Forever C_Map.GetMapLevels is reported to
-- answer nothing (research\re_round3.md 3.1). Keyed by the Classic-era uiMapIDs Forever uses, plus the
-- Forever-only zones. Ranges are the usual Classic quest ranges written by us; Forever zones from our
-- research (Zephras Isle 3-12, Riverglades 36-44, Shen'dralas 38-45, Mount Hyjal at 60).
-- Cities, battlegrounds and Moonglade have no range on purpose.
local ZONES = {
    [1411] = { 1, 10, "Durotar" }, [1412] = { 1, 10, "Mulgore" }, [1413] = { 10, 25, "The Barrens" },
    [1416] = { 30, 40, "Alterac Mountains" }, [1417] = { 30, 40, "Arathi Highlands" }, [1418] = { 35, 45, "Badlands" },
    [1419] = { 45, 55, "Blasted Lands" }, [1420] = { 1, 10, "Tirisfal Glades" }, [1421] = { 10, 20, "Silverpine Forest" },
    [1422] = { 51, 58, "Western Plaguelands" }, [1423] = { 53, 60, "Eastern Plaguelands" },
    [1424] = { 20, 30, "Hillsbrad Foothills" }, [1425] = { 40, 50, "The Hinterlands" }, [1426] = { 1, 10, "Dun Morogh" },
    [1427] = { 43, 50, "Searing Gorge" }, [1428] = { 50, 58, "Burning Steppes" }, [1429] = { 1, 10, "Elwynn Forest" },
    [1430] = { 55, 60, "Deadwind Pass" }, [1431] = { 18, 30, "Duskwood" }, [1432] = { 10, 20, "Loch Modan" },
    [1433] = { 15, 25, "Redridge Mountains" }, [1434] = { 30, 45, "Stranglethorn Vale" },
    [1435] = { 35, 45, "Swamp of Sorrows" }, [1436] = { 10, 20, "Westfall" }, [1437] = { 20, 30, "Wetlands" },
    [1438] = { 1, 10, "Teldrassil" }, [1439] = { 10, 20, "Darkshore" }, [1440] = { 18, 30, "Ashenvale" },
    [1441] = { 25, 35, "Thousand Needles" }, [1442] = { 15, 27, "Stonetalon Mountains" }, [1443] = { 30, 40, "Desolace" },
    [1444] = { 40, 50, "Feralas" }, [1445] = { 35, 45, "Dustwallow Marsh" }, [1446] = { 40, 50, "Tanaris" },
    [1447] = { 45, 55, "Azshara" }, [1448] = { 48, 55, "Felwood" }, [1449] = { 48, 55, "Un'Goro Crater" },
    [1451] = { 55, 60, "Silithus" }, [1452] = { 55, 60, "Winterspring" },
    -- Forever-only zones.
    [2521] = { 3, 12, "Zephras Isle" }, [2665] = { 3, 12, "Zephras Isle" }, [2548] = { 36, 44, "Riverglades" },
    [2652] = { 38, 45, "Shen'dralas" }, [2482] = { 58, 60, "Mount Hyjal" },
}
local BY_NAME = {}
for _, zone in pairs(ZONES) do
    BY_NAME[zone[3]:lower()] = zone
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("ZoneLevels", text)
    end
end

-- Without the hub, the warning goes into a small frame of our own near the top of the screen, which
-- hides itself after a few seconds. Never the game's error frame.
local note, noteText, noteToken = nil, nil, 0
local function ShowNote(text)
    if not CreateFrame then
        return
    end
    if not note then
        note = CreateFrame("Frame", "ZoneLevelsNote", UIParent)
        if note.SetSize then
            note:SetSize(520, 30)
            note:SetPoint("TOP", UIParent, "TOP", 0, -150)
            note:SetFrameStrata("HIGH")
        end
        noteText = note:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        if noteText.SetPoint then
            noteText:SetPoint("CENTER")
            noteText:SetTextColor(1, 0.5, 0.2)
        end
    end
    noteText:SetText(text)
    note:Show()
    noteToken = noteToken + 1
    local token = noteToken
    if C_Timer and C_Timer.After then
        C_Timer.After(NOTE_SECONDS, function()
            if token == noteToken then
                note:Hide()
            end
        end)
    end
end

local function ReadLevels(mapID, name)
    local low, high
    if C_Map and C_Map.GetMapLevels then
        local ok, a, b = pcall(C_Map.GetMapLevels, mapID)
        if ok then
            low, high = Safe(a), Safe(b)
        end
    end
    -- A range of 0 or the whole game means the map has no level set; then our table.
    if type(low) == "number" and type(high) == "number" and low > 0 and not (low <= 1 and high >= MAX_LEVEL) then
        return low, high
    end
    local zone = ZONES[mapID] or (type(name) == "string" and BY_NAME[name:lower()])
    if zone then
        return zone[1], zone[2]
    end
    return nil
end

local function MapInfo(mapID)
    local ok, info = pcall(C_Map.GetMapInfo, mapID)
    return ok and type(info) == "table" and info or nil
end

-- Zone name, minimum and maximum level for a map. Levels are nil when neither the game nor our table
-- has a range. Caves and small areas get their own map, often without a range, so the zone around
-- them is used; continents and wider have no useful range, so the climb stops there.
local function ZoneFor(mapID)
    if not mapID then
        return nil
    end
    local info = MapInfo(mapID)
    local name = info and Safe(info.name) or (ZONES[mapID] and ZONES[mapID][3]) or "This zone"
    local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
    for _ = 1, 4 do
        local here = info and Safe(info.name)
        local low, high = ReadLevels(mapID, here)
        if low then
            return here or (ZONES[mapID] and ZONES[mapID][3]) or name, low, high
        end
        local mapType = info and Safe(info.mapType)
        local parent = info and Safe(info.parentMapID)
        if not (type(mapType) == "number" and mapType > zoneType and type(parent) == "number" and parent > 0) then
            break
        end
        mapID, info = parent, MapInfo(parent)
    end
    return name
end

local function ReadZone()
    return ZoneFor(Safe(C_Map.GetBestMapForUnit("player")))
end

-- For other helpers (DeathNotes, travel): minimum level, maximum level and zone name of a map, or nil.
function ForeverZoneLevels(mapID)
    local ok, name, low, high = pcall(ZoneFor, tonumber(mapID))
    if ok and low then
        return low, high, name
    end
    return nil
end

local function CheckZone()
    local name, low, high = ReadZone()
    local level = Safe(UnitLevel("player"))
    if low and type(level) == "number" and low - level >= TOO_HIGH_BY then
        if lastWarned ~= name then
            local text = string.format("%s is level %d-%d and you're level %d. Careful!", name, low, high, level)
            if ForeverHub_Receive then
                Print(text)
            else
                ShowNote(text)
            end
        end
        lastWarned = name
    else
        lastWarned = nil
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:SetScript("OnEvent", CheckZone)

SLASH_ZONELEVELS1 = "/zl"
SlashCmdList.ZONELEVELS = function()
    local name, low, high = ReadZone()
    if not name then
        Print("The game didn't report where you are.")
    elseif low then
        Print(string.format("%s: level %d-%d", name, low, high))
    else
        Print(name .. ": the game has no level range for this zone.")
    end
end
