local ADDON_NAME = ...
local MAX_ENTRIES = 50
local MAX_STACK_LENGTH = 1200

-- Errors can happen before saved data loads, so they start in this table and move over.
local entries = {}
local recording = false

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("ErrorLog", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function Record(kind, message, stack)
    message = Safe(message)
    if type(message) ~= "string" then
        message = "(the game hid this error's text)"
    end
    for _, entry in ipairs(entries) do
        if entry.message == message then
            entry.count = entry.count + 1
            return
        end
    end
    -- A full list drops its oldest error, so a new problem is never the one lost.
    if #entries >= MAX_ENTRIES then
        table.remove(entries, 1)
    end
    stack = Safe(stack)
    entries[#entries + 1] = {
        kind = kind, message = message, count = 1, when = date and date("%Y-%m-%d %H:%M:%S") or "",
        stack = type(stack) == "string" and stack:sub(1, MAX_STACK_LENGTH) or nil,
    }
    if ForeverHub_Receive then
        Print("Caught an error. It's on the Errors page.")
    end
end

local function Capture(kind, message, stack)
    if recording then
        return
    end
    recording = true
    pcall(Record, kind, message, stack)
    recording = false
end

-- Blizzard's own handler still runs after this, so the game shows errors as usual.
if seterrorhandler and geterrorhandler then
    local previous = geterrorhandler()
    seterrorhandler(function(message, ...)
        Capture("Lua error", message, debugstack and debugstack(3))
        if previous then
            return previous(message, ...)
        end
    end)
end

local function ShowEntries()
    if #entries == 0 then
        Print("No errors saved.")
        return
    end
    for index, entry in ipairs(entries) do
        Print(string.format("%d. [%s] x%d %s", index, entry.when, entry.count, entry.message))
    end
    Print("Enter a number for details, or clear to empty the list.")
end

local function ShowEntry(index)
    local entry = entries[index]
    if not entry then
        Print("No error with that number.")
        return
    end
    Print(string.format("%s, %s, seen %d time(s):", entry.kind, entry.when, entry.count))
    Print(entry.message)
    if entry.stack then
        Print(entry.stack)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
-- These events aren't in Blizzard's docs for every build, so a missing one must not stop the addon.
for _, name in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "LUA_WARNING" }) do
    pcall(events.RegisterEvent, events, name)
end
events:SetScript("OnEvent", function(_, event, first, second)
    if event == "ADDON_LOADED" then
        if first == ADDON_NAME then
            ErrorLogDB = ErrorLogDB or {}
            -- Older saves can lack a count or time (or hold junk), which would break counting and the Errors page.
            local saved = {}
            for _, old in ipairs(type(ErrorLogDB.entries) == "table" and ErrorLogDB.entries or {}) do
                if type(old) == "table" then
                    old.count = tonumber(old.count) or 1
                    old.when = type(old.when) == "string" and old.when or ""
                    old.kind = type(old.kind) == "string" and old.kind or "Lua error"
                    old.message = type(old.message) == "string" and old.message or "(the game hid this error's text)"
                    saved[#saved + 1] = old
                end
            end
            -- Same rules as Record: a repeat adds to its saved count, and a full list drops its oldest.
            for _, entry in ipairs(entries) do
                local match
                for _, old in ipairs(saved) do
                    if old.message == entry.message then
                        match = old
                        break
                    end
                end
                if match then
                    match.count = match.count + entry.count
                else
                    if #saved >= MAX_ENTRIES then
                        table.remove(saved, 1)
                    end
                    saved[#saved + 1] = entry
                end
            end
            entries = saved
            ErrorLogDB.entries = entries
        end
    elseif event == "LUA_WARNING" then
        -- Forever's LUA_WARNING carries only the text (Blizzard reads `local warningMessage = ...`).
        -- Older clients sent (warnType, text), so a non-text first argument falls back to the second.
        local text = Safe(first)
        Capture("Lua warning", type(text) == "string" and text or second)
    else
        Capture("Blocked action", tostring(Safe(first)) .. " tried to use " .. tostring(Safe(second)))
    end
end)

SLASH_ERRORLOG1 = "/errs"
SlashCmdList.ERRORLOG = function(message)
    local command = message:match("^%s*(%S*)"):lower()
    if command == "" then
        ShowEntries()
    elseif command == "clear" then
        for index = #entries, 1, -1 do
            entries[index] = nil
        end
        Print("List cleared.")
    elseif tonumber(command) then
        ShowEntry(tonumber(command))
    else
        Print("/errs - list saved errors, /errs <number> - details, /errs clear - empty the list")
    end
end
