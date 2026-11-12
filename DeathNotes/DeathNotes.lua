-- DeathNotes: remembers where you died, what killed you and at what level, and warns you when you
-- walk back into one of those spots while it can still hurt. Read-only: it listens for your death,
-- takes the killer and last hits from the game's death recap (C_DeathRecap), or your hostile target when
-- the recap is empty (the combat log is closed to addons), and reads your map position.

-- Shared Forever waypoint (the same copy is in every helper that pins places; whichever loads first
-- defines it, so all helpers share one remembered pin). Sets the game's own map pin and tracks it,
-- remembers the point, and clears it once you are within ARRIVE_YARDS of it. It only ever clears a
-- pin that is still exactly the one it set: a pin you placed or moved yourself is never touched.
-- Returns true when the pin was set; false and a reason ("api", "map", "refused") when not.
if not ForeverWaypoint_Set then
    local ARRIVE_YARDS, CHECK_SECONDS, SAME_SPOT = 15, 0.5, 0.0005
    local active, watcher, elapsed, watching = nil, nil, 0, false
    local function Plain(value)
        if value == nil or (issecretvalue and issecretvalue(value)) then
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
        return Plain(a), Plain(b)
    end
    local function XY(vector)
        if type(vector) ~= "table" then
            return nil
        end
        local x, y = Plain(vector.x), Plain(vector.y)
        if type(x) ~= "number" and type(vector.GetXY) == "function" then
            x, y = Call(vector.GetXY, vector)
        end
        if type(x) == "number" and type(y) == "number" then
            return x, y
        end
    end
    local function Vector(x, y)
        if CreateVector2D then
            return CreateVector2D(x, y)
        end
        return { x = x, y = y }
    end
    -- Continent and world yards of a map point, or nil where the client has no world positions.
    local function World(mapID, x, y)
        if not (C_Map and C_Map.GetWorldPosFromMapPos) then
            return nil
        end
        local continent, pos = Call(C_Map.GetWorldPosFromMapPos, mapID, Vector(x, y))
        local wx, wy = XY(pos)
        if continent and wx then
            return continent, wx, wy
        end
    end
    local function Near(ax, ay, bx, by)
        return math.abs(ax - bx) <= SAME_SPOT and math.abs(ay - by) <= SAME_SPOT
    end
    -- True only while the game's pin is still the one we set.
    local function StillOurs()
        if not (active and C_Map) then
            return false
        end
        if C_Map.HasUserWaypoint and Call(C_Map.HasUserWaypoint) == false then
            return false
        end
        local point = C_Map.GetUserWaypoint and Call(C_Map.GetUserWaypoint)
        if type(point) == "table" then
            local px, py = XY(point.position)
            if Plain(point.uiMapID) == active.mapID and px then
                return Near(px, py, active.x, active.y)
            end
        end
        -- The game may keep the pin on another map; ask where it is on ours.
        local pos = C_Map.GetUserWaypointPositionForMap and Call(C_Map.GetUserWaypointPositionForMap, active.mapID)
        local qx, qy = XY(pos)
        return qx ~= nil and Near(qx, qy, active.x, active.y)
    end
    local function Stop()
        active, watching = nil, false
        if watcher then
            watcher:SetScript("OnUpdate", nil)
            if watcher.Hide then
                watcher:Hide()
            end
        end
    end
    -- Yards from the player to our pin, or nil when it can't be measured here (instances, other continent).
    local function YardsAway()
        if not (active and active.continent and C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
            return nil
        end
        local mapID = Call(C_Map.GetBestMapForUnit, "player")
        if not mapID then
            return nil
        end
        local px, py = XY(Call(C_Map.GetPlayerMapPosition, mapID, "player"))
        if not px then
            return nil
        end
        local continent, wx, wy = World(mapID, px, py)
        if not continent or continent ~= active.continent then
            return nil
        end
        return math.sqrt((wx - active.wx) ^ 2 + (wy - active.wy) ^ 2)
    end
    local function Check()
        if not active then
            return Stop()
        end
        if not StillOurs() then
            -- Replaced or removed by the player (or another addon): forget it, never clear it.
            return Stop()
        end
        local yards = YardsAway()
        if yards and yards <= ARRIVE_YARDS then
            if C_Map.ClearUserWaypoint then
                pcall(C_Map.ClearUserWaypoint)
            end
            Stop()
        end
    end
    local function OnUpdate(_, delta)
        elapsed = elapsed + (tonumber(delta) or 0)
        if elapsed < CHECK_SECONDS then
            return
        end
        elapsed = 0
        local ok, err = pcall(Check)
        if not ok then
            Stop()
            if geterrorhandler then
                geterrorhandler()(err)
            end
        end
    end
    function ForeverWaypoint_Set(mapID, x, y, label)
        mapID, x, y = tonumber(mapID), tonumber(x), tonumber(y)
        if not (mapID and x and y and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
            return false, "api"
        end
        if C_Map.CanSetUserWaypointOnMap and not Call(C_Map.CanSetUserWaypointOnMap, mapID) then
            return false, "map"
        end
        local ok, wasSet = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(mapID, x, y))
        if not ok or Plain(wasSet) == false then
            return false, "refused"
        end
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
        end
        -- Only watch where arrival can be measured; elsewhere the pin simply stays, as before.
        local continent, wx, wy = World(mapID, x, y)
        Stop()
        if continent and CreateFrame then
            active = { mapID = mapID, x = x, y = y, label = label, continent = continent, wx = wx, wy = wy }
            elapsed, watching = 0, true
            watcher = watcher or CreateFrame("Frame")
            watcher:SetScript("OnUpdate", OnUpdate)
            if watcher.Show then
                watcher:Show()
            end
        end
        return true
    end
    -- The pin we set and are still watching, or nil (for pages and tests).
    function ForeverWaypoint_Active()
        return watching and active or nil
    end
end


-- Shared Forever character identity (the same copy is in every helper that saves per-character data,
-- so each helper still works alone; whichever loads first defines it). On Forever a character has a
-- first name and a surname (UnitName's second return), so the first name alone is not unique.
-- Key = the player GUID ("Player-<server>-<id>"); when that can't be read, "First Surname-Realm".
do
    local function Plain(value)
        if value == nil or (issecretvalue and issecretvalue(value)) or type(value) ~= "string" or value == "" then
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
        return Plain(a), Plain(b)
    end
    -- "First Surname" on Forever, the plain name elsewhere; nil when unreadable.
    ForeverCharacterName = ForeverCharacterName or function()
        local name, surname = Call(UnitName, "player")
        if not name then
            return nil
        end
        if surname then
            return name .. " " .. surname
        end
        return name
    end
    ForeverCharacterGUID = ForeverCharacterGUID or function()
        local guid = Call(UnitGUID, "player")
        if guid and guid:match("^Player%-") then
            return guid
        end
    end
    -- The key older versions used: first name only, "-", realm.
    ForeverCharacterLegacyKey = ForeverCharacterLegacyKey or function()
        local name = Call(UnitName, "player")
        local realm = Call(GetRealmName)
        return (name or "Unknown") .. "-" .. (realm or "Unknown")
    end
    -- "First Surname-Realm": the key when the GUID can't be read.
    ForeverCharacterNameKey = ForeverCharacterNameKey or function()
        local realm = Call(GetRealmName)
        return (ForeverCharacterName() or "Unknown") .. "-" .. (realm or "Unknown")
    end
    ForeverCharacterKey = ForeverCharacterKey or function()
        return ForeverCharacterGUID() or ForeverCharacterNameKey()
    end
    -- Once per login: moves this character's record from an older key to the current one. Only when
    -- nothing is saved under the current key yet (two records are never merged), and never a record
    -- stamped with another character's GUID. The old key's record is moved, not copied, so a second
    -- character with the same first name starts fresh instead of sharing it. Returns the current key.
    -- oldKeys: optional list of this helper's own older key spellings (default: the legacy key).
    ForeverCharacterAdopt = ForeverCharacterAdopt or function(db, oldKeys)
        local key = ForeverCharacterKey()
        if type(db) ~= "table" or db[key] ~= nil then
            return key
        end
        local guid = ForeverCharacterGUID()
        local candidates = { ForeverCharacterNameKey() }
        for _, old in ipairs(oldKeys or { ForeverCharacterLegacyKey() }) do
            candidates[#candidates + 1] = old
        end
        for _, old in ipairs(candidates) do
            local record = old ~= key and db[old]
            if type(record) == "table" and (record.charGUID == nil or record.charGUID == guid) then
                db[key] = record
                db[old] = nil
                record.migratedFrom = old
                break
            end
        end
        return key
    end
    -- Writes who a record belongs to into it, so pages can show a name instead of parsing the key.
    ForeverCharacterStamp = ForeverCharacterStamp or function(record)
        if type(record) ~= "table" then
            return record
        end
        record.charName = ForeverCharacterName() or record.charName
        record.charGUID = ForeverCharacterGUID() or record.charGUID
        return record
    end
end


local MAX_DEATHS = 200
local WARN_YARDS = 80          -- how close to an old death spot before the warning
local CLEAR_YARDS = 160        -- how far away you have to get before the same spot can warn again
local OUTGROWN_LEVELS = 5      -- a spot stops warning once you're this many levels above the death
local CHECK_SECONDS = 2
local RECENT_ON_PAGE = 15
local LIST_PER_LINE = 1

local db
local playerGUID
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

-- nil while the game hides your level.
local function MyLevel()
    return UnitLevel and Safe(UnitLevel("player")) or nil
end

-- A death spot still matters while you're not far above the level you died at there. With your level
-- hidden, nothing is called dangerous (else a level 60 would be warned about its level 5 deaths).
local function StillDangerous(death, level)
    return type(level) == "number" and (tonumber(death.level) or 1) + OUTGROWN_LEVELS > level
end

-- The combat log is closed to addons on Forever, so the enemy you were targeting is the best guess.
-- The game may hide the name during combat, and then the death is saved without one.
-- Once you are dead the game may stop calling your target attackable, so the last hostile target seen
-- while alive is also remembered for a few seconds.
local FOE_MEMORY_SECONDS = 15
local lastFoe

local function HostileTargetName()
    if UnitExists and UnitCanAttack and Safe(UnitExists("target")) and Safe(UnitCanAttack("player", "target")) then
        local name = UnitName and Safe(UnitName("target"))
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
    return nil
end

-- Only a foe you're fighting counts: one clicked from afar before a fall isn't the killer.
local function NoteFoe()
    local fighting = UnitAffectingCombat and Safe(UnitAffectingCombat("player"))
    if fighting == false then
        return
    end
    local name = HostileTargetName()
    if name and GetTime then
        lastFoe = { name = name, when = GetTime() }
    end
end

local function Killer()
    local name = HostileTargetName()
    if name then
        return name
    end
    if lastFoe and lastFoe.combatEnded and GetTime and GetTime() - lastFoe.combatEnded > 3 then
        lastFoe = nil
    end
    if lastFoe and GetTime and GetTime() - lastFoe.when <= FOE_MEMORY_SECONDS then
        return lastFoe.name
    end
    return nil
end

--------------------------------------------------------------------------------------------------
-- The game's own death recap (C_DeathRecap): the real killer and the last hits, when the client
-- gives them. It has no event of its own in this client's API docs, so it is read a moment after
-- PLAYER_DEAD (1 s and 3 s later) and again when the Deaths page opens shortly after a death.
-- Every field goes through Safe(): a secret value is treated as missing, never compared or joined.
-- Without the API, or with an empty recap, the target-based guess above stays. Idea after
-- Memories' Record/Deaths.lua (GPL-3.0-or-later); no code or hooks taken.
--------------------------------------------------------------------------------------------------
local RECAP_HITS = 5               -- last hits kept per death
local RECAP_TEXT = 40              -- longest name kept from the recap
local RECAP_RETRIES = { 1, 3 }     -- seconds after PLAYER_DEAD
local RECAP_PAGE_SECONDS = 300     -- the page still asks for the recap this long after a death
local SWING_SPELL_ID = 88163       -- DeathRecapConsts.SWING_DAMAGE_SPELL_ID
local ENVIRONMENT = {
    FALLING = "Falling", DROWNING = "Drowning", FATIGUE = "Fatigue", FIRE = "Fire", LAVA = "Lava", SLIME = "Slime",
}

local pendingDeath, pendingAt      -- the latest death still waiting for its recap (not saved)

local function RecapText(value)
    value = Safe(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end
    return value:sub(1, RECAP_TEXT)
end

local function RecapNumber(value)
    value = Safe(value)
    return type(value) == "number" and value or nil
end

-- One recap entry as plain values: who, what, how much, when. nil when nothing is readable.
local function RecapHit(entry, index)
    if type(entry) ~= "table" then
        return nil
    end
    local env = RecapText(entry.environmentalType)
    if env then
        env = ENVIRONMENT[env:upper()] or env
    end
    local spellID = RecapNumber(entry.spellId)
    local spell = RecapText(entry.spellName)
    if not spell and (spellID == SWING_SPELL_ID or RecapText(entry.event) == "SWING_DAMAGE") then
        spell = "Melee"
    end
    local amount = RecapNumber(entry.amount)
    local hit = {
        source = RecapText(entry.sourceName), spell = spell, env = env,
        amount = amount and amount >= 0 and math.floor(amount) or nil,
        t = RecapNumber(entry.timestamp), index = index,
    }
    if not (hit.source or hit.spell or hit.env or hit.amount) then
        return nil
    end
    return hit
end

-- The recap's hits, newest first (by timestamp; without one, the game's order, killing blow first).
local function ReadRecap()
    if not (C_DeathRecap and type(C_DeathRecap.GetRecapEvents) == "function") then
        return nil
    end
    if type(C_DeathRecap.HasRecapEvents) == "function" then
        local ok, has = pcall(C_DeathRecap.HasRecapEvents)
        if ok and Safe(has) == false then
            return nil
        end
    end
    local ok, list = pcall(C_DeathRecap.GetRecapEvents)
    list = ok and Safe(list) or nil
    if type(list) ~= "table" then
        return nil
    end
    local hits = {}
    local readOk = pcall(function()
        for index, entry in ipairs(list) do
            local hit = RecapHit(entry, index)
            if hit then
                hits[#hits + 1] = hit
            end
            if index >= 50 then
                break
            end
        end
    end)
    if not readOk or #hits == 0 then
        return nil
    end
    local timed = true
    for _, hit in ipairs(hits) do
        if not hit.t then
            timed = false
        end
    end
    table.sort(hits, function(a, b)
        if timed and a.t ~= b.t then
            return a.t > b.t
        end
        if timed then
            return a.index > b.index   -- same time: the later entry is the newer hit
        end
        return a.index < b.index
    end)
    return hits, timed and hits[1].t or nil
end

-- "Kobold Miner (Strike 38)", "Falling (120)", "Melee 41".
local function HitText(hit)
    local who = hit.env or hit.source
    local what = hit.env and nil or hit.spell
    local detail = what and (hit.amount and (what .. " " .. hit.amount) or what) or (hit.amount and tostring(hit.amount))
    if who and detail then
        return who .. " (" .. detail .. ")"
    end
    return who or detail or "?"
end

-- Writes the recap into a saved death. Returns true when the death got something from it.
local function ApplyRecap(death)
    if not (db and death) then
        return false
    end
    local hits, stamp = ReadRecap()
    if not hits then
        return false
    end
    -- The same recap read again (an older death's): leave this death on its guess.
    if stamp and db.lastRecap == stamp then
        return false
    end
    local last = hits[1]
    local killer = last.env or last.source
    if not killer then
        for _, hit in ipairs(hits) do
            killer = hit.env or hit.source
            if killer then
                break
            end
        end
    end
    local kept = {}
    for index = math.min(#hits, RECAP_HITS), 1, -1 do   -- oldest first, the killing blow last
        local hit = hits[index]
        kept[#kept + 1] = { source = hit.source, spell = hit.spell, env = hit.env, amount = hit.amount }
    end
    db.lastRecap = stamp
    if killer then
        if death.killer and death.killer ~= killer then
            death.guess = death.killer
        end
        death.killer = killer
    end
    death.blow = HitText(last)
    death.hits = kept
    death.recap = true
    return true
end

local function TryRecap()
    local death = pendingDeath
    if not death then
        return
    end
    local ok, got = pcall(ApplyRecap, death)
    if ok and got then
        pendingDeath, pendingAt = nil, nil
        Print(string.format("Death recap: killed by %s%s.", death.killer or "?",
            death.blow and death.blow ~= death.killer and (", last hit " .. death.blow) or ""))
    end
end

local function StartRecap(death)
    pendingDeath, pendingAt = nil, nil
    if not (death and C_DeathRecap and type(C_DeathRecap.GetRecapEvents) == "function") then
        return
    end
    pendingDeath, pendingAt = death, GetTime and GetTime() or nil
    if C_Timer and C_Timer.After then
        for _, seconds in ipairs(RECAP_RETRIES) do
            C_Timer.After(seconds, TryRecap)
        end
    else
        TryRecap()
    end
end

-- The Deaths page asks again for a recent death the timers couldn't fill.
local function RecapOnPage()
    if not pendingDeath then
        return
    end
    if pendingAt and GetTime and GetTime() - pendingAt > RECAP_PAGE_SECONDS then
        pendingDeath, pendingAt = nil, nil
        return
    end
    TryRecap()
end

-- "Last hits: Kobold Miner (Melee 38), Kobold Miner (Strike 41)" for the page, or nil.
local function HitsLine(death)
    if type(death.hits) ~= "table" or #death.hits == 0 then
        return nil
    end
    local parts = {}
    for index, hit in ipairs(death.hits) do
        if index > RECAP_HITS then
            break
        end
        if type(hit) == "table" then
            parts[#parts + 1] = HitText(hit)
        end
    end
    if #parts == 0 then
        return nil
    end
    return "|cff999999    Last hits: " .. table.concat(parts, ", ") .. "|r"
end

local function RecordDeath()
    if not db then
        return
    end
    local spot = Here() or {}
    local death = {
        when = time(), level = MyLevel(), who = ForeverCharacterName() or "?", whoKey = ForeverCharacterKey(),
        where = PlaceName(), killer = Killer(),
        mapID = spot.mapID, x = spot.x, y = spot.y, continent = spot.continent, wx = spot.wx, wy = spot.wy,
    }
    db.deaths[#db.deaths + 1] = death
    while #db.deaths > MAX_DEATHS do
        table.remove(db.deaths, 1)
    end
    -- You know you're here right now; the warning is for coming back later.
    warned[death] = true
    Print(string.format("Noted: died at level %s in %s%s.", tostring(death.level or "?"), death.where,
        death.killer and (" to " .. death.killer) or ""))
    return death
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
    return (ForeverWaypoint_Set(death.mapID, death.x, death.y, "Death"))
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
            if entry == pendingDeath then
                pendingDeath, pendingAt = nil, nil
            end
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
    RecapOnPage()
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
            pendingDeath, pendingAt = nil, nil
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
        local hits = index <= 3 and HitsLine(death)
        if hits then
            Print(hits)
        end
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

--------------------------------------------------------------------------------------------------
-- Danger before you die there: a zone well above your level, and an elite or rare elite 2+ levels
-- above you on your target or mouseover. Health is secret on Forever, so only level and
-- classification are read. Wording after Quest Triage's fight table (GPL-3.0, idea only).
--------------------------------------------------------------------------------------------------
local ZONE_TOO_HIGH_BY = 4          -- "well above": more than 3 levels
local ZONE_REPEAT_SECONDS = 900     -- the same zone warns again only after this
local ELITE_ABOVE = 2
local MOB_GAP_SECONDS = 20          -- at most one mob warning this often
local MOB_REPEAT_SECONDS = 600      -- the same mob (GUID) warns again only after this
local MAX_REMEMBERED = 100

local zoneWarned, mobWarned, mobCount, lastMobWarning = {}, {}, 0, nil

local function Options()
    local saved = type(DeathNotesDB) == "table" and DeathNotesDB._options
    return type(saved) == "table" and saved or nil
end

local function OptionOn(key)
    local saved = Options()
    return not (saved and saved[key] == false)
end

local function SetOption(key, on)
    if type(DeathNotesDB) ~= "table" then
        DeathNotesDB = {}
    end
    if type(DeathNotesDB._options) ~= "table" then
        DeathNotesDB._options = {}
    end
    DeathNotesDB._options[key] = on and true or false
end

local function Call(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then
        return nil
    end
    return Safe(a), Safe(b), Safe(c)
end

-- ZoneLevels does the zone warning itself while it's loaded and switched on.
local function ZoneLevelsWarns()
    if type(ForeverZoneLevels) ~= "function" then
        return false
    end
    return not (type(ForeverHub_IsOff) == "function" and ForeverHub_IsOff("ZoneLevels") == true)
end

local function ZoneRange(mapID)
    if type(ForeverZoneLevels) == "function" then
        local low, high, name = Call(ForeverZoneLevels, mapID)
        if type(low) == "number" and type(high) == "number" then
            return low, high, name
        end
    end
    if C_Map and C_Map.GetMapLevels then
        local low, high = Call(C_Map.GetMapLevels, mapID)
        if type(low) == "number" and type(high) == "number" and low > 0 and not (low <= 1 and high >= 60) then
            local info = C_Map.GetMapInfo and Call(C_Map.GetMapInfo, mapID)
            return low, high, type(info) == "table" and Safe(info.name) or nil
        end
    end
end

local function CheckZoneDanger()
    if not OptionOn("zoneDanger") or ZoneLevelsWarns() or not (C_Map and C_Map.GetBestMapForUnit) then
        return
    end
    local mapID = Call(C_Map.GetBestMapForUnit, "player")
    local level = MyLevel()
    if type(mapID) ~= "number" or type(level) ~= "number" then
        return
    end
    local low, high, name = ZoneRange(mapID)
    if not (low and low - level >= ZONE_TOO_HIGH_BY) then
        return
    end
    name = type(name) == "string" and name or (GetZoneText and Safe(GetZoneText())) or "This zone"
    local now = GetTime and GetTime() or 0
    if zoneWarned[name] and now - zoneWarned[name] < ZONE_REPEAT_SECONDS then
        return
    end
    zoneWarned[name] = now
    Print(string.format("Careful: %s is level %d-%d and you're level %d. Mobs here hit hard; stay on the roads.",
        name, low, high, level))
end

local function PruneMobs(now)
    if mobCount <= MAX_REMEMBERED then
        return
    end
    mobCount = 0
    for key, when in pairs(mobWarned) do
        if now - when >= MOB_REPEAT_SECONDS then
            mobWarned[key] = nil
        else
            mobCount = mobCount + 1
        end
    end
end

local DANGER_KINDS = { elite = "an elite", rareelite = "a rare elite", worldboss = "a boss" }

local function CheckUnitDanger(unit)
    if not OptionOn("eliteDanger") or not (UnitExists and UnitClassification and UnitLevel) then
        return
    end
    if IsInInstance and Call(IsInInstance) == true then
        return
    end
    if Call(UnitExists, unit) ~= true or Call(UnitCanAttack, "player", unit) ~= true then
        return
    end
    if UnitIsDeadOrGhost and Call(UnitIsDeadOrGhost, unit) ~= false then
        return
    end
    if UnitIsPlayer and Call(UnitIsPlayer, unit) ~= false then
        return
    end
    local kind = DANGER_KINDS[Call(UnitClassification, unit) or ""]
    local theirs, mine = Call(UnitLevel, unit), MyLevel()
    if not kind or type(theirs) ~= "number" or type(mine) ~= "number" then
        return
    end
    local skull = theirs <= 0
    local above = skull and 10 or theirs - mine
    if above < ELITE_ABOVE and kind ~= "a boss" then
        return
    end
    local name = Call(UnitName, unit)
    if type(name) ~= "string" or name == "" then
        return
    end
    local key = Call(UnitGUID, unit)
    key = type(key) == "string" and key or (name .. ":" .. tostring(theirs))
    local now = GetTime and GetTime() or 0
    if mobWarned[key] and now - mobWarned[key] < MOB_REPEAT_SECONDS then
        return
    end
    if lastMobWarning and now - lastMobWarning < MOB_GAP_SECONDS then
        return
    end
    lastMobWarning = now
    if not mobWarned[key] then
        mobCount = mobCount + 1
    end
    mobWarned[key] = now
    PruneMobs(now)
    local how = above >= 3 and "Very risky: bring a group or leave it." or "Risky: fight it only with help or at full health."
    local levelText = skull and "level ??" or string.format("level %d, %d above you", theirs, above)
    Print(string.format("Careful: %s is %s (%s). %s", name, kind, levelText, how))
end

-- The hub's Options page shows these as On/Off switches.
ForeverHubOptions = ForeverHubOptions or {}
ForeverHubOptions.DeathNotes = {
    title = "Death notes",
    rows = {
        { label = "Zone danger", about = "A pop-up when you enter a zone more than 3 levels above you (when ZoneLevels is off or missing).",
            get = function() return OptionOn("zoneDanger") end, set = function(on) SetOption("zoneDanger", on) end },
        { label = "Elite danger", about = "A pop-up when you target or point at an elite or rare elite 2 or more levels above you.",
            get = function() return OptionOn("eliteDanger") end, set = function(on) SetOption("eliteDanger", on) end },
    },
}

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
-- Never register COMBAT_LOG_EVENT_UNFILTERED: Forever (Midnight rules) forbids it, and even inside
-- pcall the attempt raises ADDON_ACTION_FORBIDDEN ("blocked from an action", logged as UNKNOWN()).
-- The killer is taken from the game's death recap (C_DeathRecap, read on timers after PLAYER_DEAD;
-- it has no event of its own here), else from your hostile target (see Killer).
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        DeathNotesDB = DeathNotesDB or {}
        local realm = (GetRealmName and Safe(GetRealmName())) or "Unknown"
        DeathNotesDB[realm] = DeathNotesDB[realm] or { deaths = {} }
        db = DeathNotesDB[realm]
        db.deaths = db.deaths or {}
        playerGUID = UnitGUID and Safe(UnitGUID("player"))
        -- Names are shown on the page only once more than one character has died on this realm.
        -- Newer deaths carry the shared character key; older ones only the first name.
        local myKey, firstName = ForeverCharacterKey(), (UnitName and Safe(UnitName("player"))) or "?"
        for _, death in ipairs(db.deaths) do
            local mine
            if death.whoKey then
                mine = death.whoKey == myKey
            else
                mine = death.who == nil or death.who == firstName or death.who == ForeverCharacterName()
            end
            if not mine then
                db.several = true
            end
        end
        if C_Timer and C_Timer.NewTicker then
            C_Timer.NewTicker(CHECK_SECONDS, function()
                if not (UnitIsDeadOrGhost and Safe(UnitIsDeadOrGhost("player"))) then
                    pcall(NoteFoe)
                end
                local ok, err = pcall(CheckNearby)
                if not ok and geterrorhandler then
                    geterrorhandler()(err)
                end
            end)
        end
    elseif event == "PLAYER_DEAD" then
        StartRecap(RecordDeath())
        lastFoe = nil
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        local ok, err = pcall(CheckZoneDanger)
        if not ok and geterrorhandler then
            geterrorhandler()(err)
        end
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        pcall(CheckUnitDanger, "mouseover")
    elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_REGEN_DISABLED" then
        NoteFoe()
        if event == "PLAYER_TARGET_CHANGED" then
            pcall(CheckUnitDanger, "target")
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- A fight that ended didn't kill you: a later fall or drowning isn't that foe's doing. Dying also
        -- ends combat, often just before PLAYER_DEAD, so the foe is kept for a few more seconds.
        if lastFoe and GetTime then
            lastFoe.combatEnded = GetTime()
        end
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
