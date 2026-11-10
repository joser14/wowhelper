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

local ADDON_NAME = ...
local RECENT_LEVELS = 10

local levels, currentLevel, lastMark

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("LevelLog", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function FormatDuration(seconds)
    seconds = math.floor(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor(seconds / 60) % 60
    if hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    end
    return string.format("%dm", minutes)
end

local function Entry(level)
    local entry = type(levels[level]) == "table" and levels[level] or {}
    entry.seconds = tonumber(entry.seconds) or 0
    entry.deaths = tonumber(entry.deaths) or 0
    levels[level] = entry
    return entry
end

local function BankTime()
    local now = GetTime()
    local entry = Entry(currentLevel)
    entry.seconds = entry.seconds + now - lastMark
    lastMark = now
end

local function ShowLog(showAll)
    BankTime()
    local first = showAll and 1 or math.max(1, currentLevel - RECENT_LEVELS + 1)
    local totalSeconds, totalDeaths = 0, 0
    for level = 1, currentLevel do
        local entry = levels[level]
        if type(entry) == "table" then
            -- Older saves may lack a field; count it as nothing rather than stop the whole page.
            local seconds, deaths = tonumber(entry.seconds) or 0, tonumber(entry.deaths) or 0
            totalSeconds = totalSeconds + seconds
            totalDeaths = totalDeaths + deaths
            if level >= first then
                Print(string.format("Level %d: %s, %d death(s)", level, FormatDuration(seconds), deaths))
            end
        end
    end
    Print(string.format("Total logged: %s, %d death(s)", FormatDuration(totalSeconds), totalDeaths))
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("PLAYER_DEAD")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        LevelLogDB = LevelLogDB or {}
        local key = ForeverCharacterAdopt(LevelLogDB)
        LevelLogDB[key] = LevelLogDB[key] or {}
        levels = ForeverCharacterStamp(LevelLogDB[key])
        currentLevel = Safe(UnitLevel("player")) or 1
        lastMark = GetTime()
    elseif not levels then
        -- Saved data isn't set up until PLAYER_LOGIN.
        return
    elseif event == "PLAYER_LEVEL_UP" then
        BankTime()
        Print(string.format("Level %d took %s.", currentLevel, FormatDuration(levels[currentLevel].seconds)))
        currentLevel = Safe(arg1) or currentLevel + 1
    elseif event == "PLAYER_DEAD" then
        local entry = Entry(currentLevel)
        entry.deaths = entry.deaths + 1
    elseif event == "PLAYER_LOGOUT" then
        BankTime()
    end
end)

SLASH_LEVELLOG1 = "/levellog"
SlashCmdList.LEVELLOG = function(message)
    -- Saved data isn't ready until login, and the hub can open this page before then.
    if not levels then
        return
    end
    ShowLog(message:lower():match("^%s*all") ~= nil)
end
