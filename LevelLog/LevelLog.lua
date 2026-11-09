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
        if entry then
            totalSeconds = totalSeconds + entry.seconds
            totalDeaths = totalDeaths + entry.deaths
            if level >= first then
                Print(string.format("Level %d: %s, %d death(s)", level, FormatDuration(entry.seconds), entry.deaths))
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
        local key = (Safe(UnitName("player")) or "Unknown") .. "-" .. (Safe(GetRealmName()) or "Unknown")
        LevelLogDB[key] = LevelLogDB[key] or {}
        levels = LevelLogDB[key]
        currentLevel = Safe(UnitLevel("player")) or 1
        lastMark = GetTime()
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
