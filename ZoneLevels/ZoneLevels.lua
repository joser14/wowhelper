local TOO_HIGH_BY = 3
local MAX_LEVEL = 60

local lastWarned

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("ZoneLevels", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function ReadLevels(mapID)
    local low, high = C_Map.GetMapLevels(mapID)
    low, high = Safe(low), Safe(high)
    -- A range of 0 or the whole game means the map has no level set.
    if not (low and high and low > 0) or (low <= 1 and high >= MAX_LEVEL) then
        return nil
    end
    return low, high
end

-- Returns zone name, minimum and maximum level. Levels are nil if the game has no real range for it.
local function ReadZone()
    local mapID = Safe(C_Map.GetBestMapForUnit("player"))
    if not mapID then
        return nil
    end
    local info = C_Map.GetMapInfo(mapID)
    local name = info and Safe(info.name) or "This zone"
    -- Caves and small areas get their own map, often without a range, so fall back to the zone around them.
    -- Continents and wider have no useful range, so the climb stops there.
    local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
    for _ = 1, 4 do
        local low, high = ReadLevels(mapID)
        if low then
            return info and Safe(info.name) or name, low, high
        end
        local mapType = info and Safe(info.mapType)
        local parent = info and Safe(info.parentMapID)
        if not (mapType and mapType > zoneType and parent and parent > 0) then
            break
        end
        mapID, info = parent, C_Map.GetMapInfo(parent)
    end
    return name
end

local function CheckZone()
    local name, low, high = ReadZone()
    local level = Safe(UnitLevel("player"))
    if low and level and low - level >= TOO_HIGH_BY then
        if lastWarned ~= name then
            if not ForeverHub_Receive then UIErrorsFrame:AddMessage(string.format("%s is level %d-%d", name, low, high), 1, 0.5, 0.2) end
            Print(string.format("%s is level %d-%d and you're level %d. Careful!", name, low, high, level))
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
