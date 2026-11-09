local ADDON_NAME = ...
local baseline
-- Faction IDs met on this character, saved so the next login can read them even under a collapsed header.
local seen = {}

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("RepWatch", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

-- One faction's data as a plain entry, or nil for plain headers and unreadable data.
local function ReadFaction(data)
    data = Safe(data)
    if type(data) ~= "table" or (Safe(data.isHeader) and not Safe(data.isHeaderWithRep)) then
        return nil
    end
    local id, name, standing = Safe(data.factionID), Safe(data.name), Safe(data.currentStanding)
    if id and name and standing then
        return {
            id = id, name = name, standing = standing, reaction = Safe(data.reaction),
            floor = Safe(data.currentReactionThreshold), ceiling = Safe(data.nextReactionThreshold),
        }
    end
end

-- Readable factions with a standing. The list skips groups collapsed in the Reputation window, so factions
-- met before are also read by ID, which works whatever is collapsed.
local function ReadFactions()
    local list, listed = {}, {}
    for index = 1, Safe(C_Reputation.GetNumFactions()) or 0 do
        local faction = ReadFaction(C_Reputation.GetFactionDataByIndex(index))
        if faction and not listed[faction.id] then
            listed[faction.id] = true
            seen[faction.id] = true
            list[#list + 1] = faction
        end
    end
    if C_Reputation.GetFactionDataByID then
        local hidden = {}
        for id in pairs(seen) do
            if not listed[id] then
                hidden[#hidden + 1] = id
            end
        end
        table.sort(hidden)
        for _, id in ipairs(hidden) do
            local faction = ReadFaction(C_Reputation.GetFactionDataByID(id))
            if faction then
                list[#list + 1] = faction
            end
        end
    end
    return list
end

-- The list can still be empty just after login, so this keeps adding factions it hasn't seen yet.
-- Known ones keep their starting point.
local function TakeBaseline()
    for _, faction in ipairs(ReadFactions()) do
        baseline = baseline or {}
        if not baseline[faction.id] then
            baseline[faction.id] = faction.standing
        end
    end
end

local function StandingName(reaction)
    return reaction and _G["FACTION_STANDING_LABEL" .. reaction] or nil
end

local function ProgressText(faction)
    local label = StandingName(faction.reaction) or "Standing"
    if faction.floor and faction.ceiling and faction.ceiling > faction.floor then
        local nextLabel = StandingName(faction.reaction and faction.reaction + 1)
        local left = faction.ceiling - faction.standing
        return string.format("%s %d/%d, %d to %s", label, faction.standing - faction.floor, faction.ceiling - faction.floor, left, nextLabel or "the next standing")
    end
    return label
end

local function ShowGains()
    TakeBaseline()
    local shown = false
    for _, faction in ipairs(ReadFactions()) do
        -- A faction first met this session starts at its current standing, so its first gain isn't known.
        local start = baseline and baseline[faction.id]
        if start and faction.standing ~= start then
            shown = true
            Print(string.format("%s: %+d this session. %s", faction.name, faction.standing - start, ProgressText(faction)))
        end
    end
    if not shown then
        Print("No reputation gained this session yet.")
    end
end

-- The hub's Reputation page runs this one, so it carries the session gains too.
local function ShowAll()
    TakeBaseline()
    local factions = ReadFactions()
    for _, faction in ipairs(factions) do
        local start = baseline and baseline[faction.id]
        local gain = start and faction.standing ~= start and string.format(" (%+d this session)", faction.standing - start) or ""
        Print(faction.name .. ": " .. ProgressText(faction) .. gain)
    end
    if #factions == 0 then
        Print("No factions to show yet.")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UPDATE_FACTION")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON_NAME then
            RepWatchDB = type(RepWatchDB) == "table" and RepWatchDB or {}
            local saved = type(RepWatchDB.seen) == "table" and RepWatchDB.seen or {}
            for id in pairs(seen) do
                saved[id] = true
            end
            seen = saved
            RepWatchDB.seen = seen
        end
        return
    end
    TakeBaseline()
end)

SLASH_REPWATCH1 = "/rep"
SlashCmdList.REPWATCH = function(message)
    if message:lower():match("^%s*all%s*$") then
        ShowAll()
    else
        ShowGains()
    end
end
