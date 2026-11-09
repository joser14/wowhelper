-- DeathNotes: remembers where you died, what killed you and at what level, and warns you when you
-- walk back into one of those spots while it can still hurt. Read-only: it listens for your death,
-- reads the combat log for the last thing that hit you, and reads your map position.

local MAX_DEATHS = 200
local WARN_YARDS = 80          -- how close to an old death spot before the warning
local CLEAR_YARDS = 160        -- how far away you have to get before the same spot can warn again
local OUTGROWN_LEVELS = 5      -- a spot stops warning once you're this many levels above the death
local CHECK_SECONDS = 2
local RECENT_ON_PAGE = 15
local LIST_PER_LINE = 1

local db
local playerGUID
local lastHit               -- the last thing that damaged you: { name, when }
local warned = {}           -- death entry -> true while you're still near it
local nearNow               -- the closest death spot you're currently being warned about

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("DeathNotes", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

-- Where you are: the map you're on, your place on it, and the same spot in world yards so
-- distances work across maps on one continent.
local function Here()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
        return nil
    end
    local mapID = Safe(C_Map.GetBestMapForUnit("player"))
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then
        return nil
    end
    local x, y = position:GetXY()
    x, y = Safe(x), Safe(y)
    if not (x and y) then
        return nil
    end
    local spot = { mapID = mapID, x = x, y = y }
    if C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local continent, world = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
        if continent and world then
            local wx, wy = world:GetXY()
            spot.continent, spot.wx, spot.wy = Safe(continent), Safe(wx), Safe(wy)
        end
    end
    return spot
end

local function PlaceName()
    local sub = GetSubZoneText and Safe(GetSubZoneText())
    local zone = GetZoneText and Safe(GetZoneText())
    if sub and sub ~= "" and sub ~= zone then
        return sub .. ", " .. (zone or "")
    end
    return zone or "somewhere"
end

local function Yards(spot, death)
    if spot and spot.continent and death.continent and spot.continent == death.continent and spot.wx and death.wx then
        return math.sqrt((spot.wx - death.wx) ^ 2 + (spot.wy - death.wy) ^ 2)
    end
    return nil
end

local function YardsText(yards)
    if yards >= 1000 then
        return string.format("%.1f k yd", yards / 1000)
    end
    return string.format("%d yd", math.floor(yards))
end

local function AgoText(when)
    local seconds = time() - (when or 0)
    if seconds < 60 then
        return "just now"
    elseif seconds < 3600 then
        return string.format("%d min ago", math.floor(seconds / 60))
    elseif seconds < 86400 then
        return string.format("%d h ago", math.floor(seconds / 3600))
    end
    return string.format("%d day(s) ago", math.floor(seconds / 86400))
end

local function MyLevel()
    return (UnitLevel and Safe(UnitLevel("player"))) or 1
end

-- A death spot still matters while you're not far above the level you died at there.
local function StillDangerous(death, level)
    return (tonumber(death.level) or 1) + OUTGROWN_LEVELS > level
end

-- The last creature or player that hit you. Hits older than a few seconds are forgotten, so a
-- fall or drowning after a fight isn't blamed on the fight.
local function Killer()
    if lastHit and lastHit.name and GetTime() - lastHit.when < 8 then
        return lastHit.name
    end
    return nil
end

local function NoteHit()
    if not (CombatLogGetCurrentEventInfo and playerGUID) then
        return
    end
    local _, subevent, _, _, sourceName, _, _, destGUID = CombatLogGetCurrentEventInfo()
    subevent, sourceName, destGUID = Safe(subevent), Safe(sourceName), Safe(destGUID)
    if type(subevent) ~= "string" or destGUID ~= playerGUID then
        return
    end
    if subevent:find("_DAMAGE", 1, true) or subevent == "ENVIRONMENTAL_DAMAGE" then
        local name = sourceName
        if subevent == "ENVIRONMENTAL_DAMAGE" then
            local kind = Safe((select(12, CombatLogGetCurrentEventInfo())))
            name = type(kind) == "string" and (kind:sub(1, 1):upper() .. kind:sub(2):lower()) or "the environment"
        end
        if type(name) == "string" and name ~= "" then
            lastHit = { name = name, when = GetTime() }
        end
    end
end

local function RecordDeath()
    if not db then
        return
    end
    local spot = Here() or {}
    local death = {
        when = time(), level = MyLevel(), who = (UnitName and Safe(UnitName("player"))) or "?",
        where = PlaceName(), killer = Killer(),
        mapID = spot.mapID, x = spot.x, y = spot.y, continent = spot.continent, wx = spot.wx, wy = spot.wy,
    }
    db.deaths[#db.deaths + 1] = death
    while #db.deaths > MAX_DEATHS do
        table.remove(db.deaths, 1)
    end
    -- You know you're here right now; the warning is for coming back later.
    warned[death] = true
    Print(string.format("Noted: died at level %d in %s%s.", death.level, death.where,
        death.killer and (" to " .. death.killer) or ""))
end

local function DeathLine(index, death, spot)
    local yards = Yards(spot, death)
    local parts = {
        string.format("|cffffd100%d.|r Level %d, %s", index, tonumber(death.level) or 0, death.where or "?"),
    }
    if death.killer then
        parts[#parts + 1] = "killed by " .. death.killer
    end
    if death.who and db.several then
        parts[#parts + 1] = "(" .. death.who .. ")"
    end
    local tail = "|cff999999" .. AgoText(death.when)
    if yards then
        tail = tail .. ", " .. YardsText(yards) .. " away"
    end
    return table.concat(parts, ", ") .. " " .. tail .. "|r"
end

-- Pins the spot on your map and screen, the same way the game's own map pin works.
local function Pin(death)
    if not (death and death.mapID and death.x and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
        return false
    end
    if C_Map.CanSetUserWaypointOnMap and not Safe(C_Map.CanSetUserWaypointOnMap(death.mapID)) then
        return false
    end
    local wasSet = C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(death.mapID, death.x, death.y))
    if Safe(wasSet) == false then
        return false
    end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
    return true
end

-- Newest first, so "1" is always your latest death.
local function Ordered()
    local list = {}
    for index = #db.deaths, 1, -1 do
        list[#list + 1] = db.deaths[index]
    end
    return list
end

local function Forget(death)
    for index, entry in ipairs(db.deaths) do
        if entry == death then
            table.remove(db.deaths, index)
            warned[entry] = nil
            return true
        end
    end
    return false
end

local function ShowPage(arg)
    if not db then
        return
    end
    local want = (arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local spot = Here()
    local list = Ordered()
    if want ~= "" then
        local forgetAll = want == "forget all" or want == "forget everything"
        local forgetIndex = tonumber(want:match("^forget%s+(%d+)$"))
        local pinIndex = tonumber(want:match("^(%d+)$"))
        if forgetAll then
            local count = #db.deaths
            db.deaths = {}
            warned = {}
            nearNow = nil
            Print(string.format("Forgot %d death(s).", count))
            list = {}
        elseif forgetIndex then
            local death = list[forgetIndex]
            if death and Forget(death) then
                Print(string.format("Forgot death %d (%s).", forgetIndex, death.where or "?"))
                list = Ordered()
            else
                Print("There's no death with that number.")
            end
        elseif pinIndex then
            local death = list[pinIndex]
            if not death then
                Print("There's no death with that number.")
            elseif not death.mapID then
                Print("That death has no map position saved, so it can't be pinned.")
            elseif Pin(death) then
                Print(string.format("Pinned death %d: %s.", pinIndex, death.where or "?"))
            else
                Print("That spot can't be pinned from this map.")
            end
        else
            Print("Type a number to pin that death on your map, or: forget 2, or: forget all.")
        end
    end
    if #list == 0 then
        Print("No deaths remembered. Long may that last.")
        return
    end
    local level = MyLevel()
    if nearNow and StillDangerous(nearNow, level) then
        Print(string.format("|cffff6633Careful:|r you died near here at level %d%s.", tonumber(nearNow.level) or 0,
            nearNow.killer and (" to " .. nearNow.killer) or ""))
    end
    if not spot then
        Print("|cff999999Where you are can't be read right now, so distances are left out.|r")
    end
    for index, death in ipairs(list) do
        if index > RECENT_ON_PAGE then
            Print(string.format("|cff999999...and %d older.|r", #list - RECENT_ON_PAGE))
            break
        end
        Print(DeathLine(index, death, spot))
    end
    -- Who dies to what, in one line, so a pattern is easy to spot.
    local byKiller, order = {}, {}
    for _, death in ipairs(list) do
        if death.killer then
            if not byKiller[death.killer] then
                byKiller[death.killer] = 0
                order[#order + 1] = death.killer
            end
            byKiller[death.killer] = byKiller[death.killer] + 1
        end
    end
    table.sort(order, function(a, b)
        return byKiller[a] > byKiller[b]
    end)
    local repeats = {}
    for _, killer in ipairs(order) do
        if byKiller[killer] >= 2 then
            repeats[#repeats + 1] = string.format("%s x%d", killer, byKiller[killer])
        end
    end
    if #repeats > 0 then
        Print("|cff999999Repeat offenders: " .. table.concat(repeats, ", ") .. "|r")
    end
    Print(string.format("|cff999999%d death(s) remembered.|r", #list))
end

-- Every couple of seconds: are you walking back into a spot that killed you?
local function CheckNearby()
    if not db or #db.deaths == 0 then
        return
    end
    if UnitIsDeadOrGhost and Safe(UnitIsDeadOrGhost("player")) then
        return
    end
    local spot = Here()
    if not spot then
        return
    end
    local level = MyLevel()
    local closest, closestYards
    for _, death in ipairs(db.deaths) do
        local yards = Yards(spot, death)
        if yards then
            if yards > CLEAR_YARDS then
                warned[death] = nil
            end
            if yards <= WARN_YARDS and StillDangerous(death, level) and (not closestYards or yards < closestYards) then
                closest, closestYards = death, yards
            end
        end
    end
    nearNow = closest
    if closest and not warned[closest] then
        warned[closest] = true
        Print(string.format("Careful: you died near here at level %d%s, %s.", tonumber(closest.level) or 0,
            closest.killer and (" to " .. closest.killer) or "", AgoText(closest.when)))
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        DeathNotesDB = DeathNotesDB or {}
        local realm = (GetRealmName and Safe(GetRealmName())) or "Unknown"
        DeathNotesDB[realm] = DeathNotesDB[realm] or { deaths = {} }
        db = DeathNotesDB[realm]
        db.deaths = db.deaths or {}
        playerGUID = UnitGUID and Safe(UnitGUID("player"))
        -- Names are shown on the page only once more than one character has died on this realm.
        local me = (UnitName and Safe(UnitName("player"))) or "?"
        for _, death in ipairs(db.deaths) do
            if death.who and death.who ~= me then
                db.several = true
            end
        end
        if C_Timer and C_Timer.NewTicker then
            C_Timer.NewTicker(CHECK_SECONDS, function()
                local ok, err = pcall(CheckNearby)
                if not ok and geterrorhandler then
                    geterrorhandler()(err)
                end
            end)
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        NoteHit()
    elseif event == "PLAYER_DEAD" then
        RecordDeath()
    end
end)

SLASH_DEATHNOTES1 = "/deaths"
SLASH_DEATHNOTES2 = "/deathnotes"
SlashCmdList.DEATHNOTES = ShowPage

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.DeathNotes = function()
    if nearNow and StillDangerous(nearNow, MyLevel()) then
        return { { text = string.format("|cffff6633Danger:|r you died here at level %d", tonumber(nearNow.level) or 0), page = "Deaths" } }
    end
end
