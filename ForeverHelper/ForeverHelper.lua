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

local WIDTH, ROW_HEIGHT, HEADER_HEIGHT = 320, 24, 104

local db, char, frame
local statLines, rows = {}, {}
local session = {}

-- Forever applies Midnight's secret values: tainted code errors on comparing or doing math with them.
local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("ForeverHelper", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function FormatMoney(copper)
    local sign = copper < 0 and "-" or ""
    copper = math.abs(math.floor(copper))
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    return string.format("%s%dg %ds %dc", sign, gold, silver, copper % 100)
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

local function FormatNumber(value)
    if value >= 1000 then
        return string.format("%.1fk", value / 1000)
    end
    return string.format("%d", math.floor(value))
end

-- No rate for the first ten minutes (the hub's panel waits as long): one sale or kill right after a
-- login or /reload would read as hundreds of gold or thousands of XP an hour.
local RATE_MIN_SECONDS = 600
local function PerHour(amount)
    local elapsed = GetTime() - session.start
    if elapsed < RATE_MIN_SECONDS then
        return nil
    end
    return amount * 3600 / elapsed
end

local function ResetSession()
    session.start = GetTime()
    -- Nil until the game gives a readable figure; otherwise the whole purse would count as earned.
    session.startMoney = Safe(GetMoney())
    session.xpGained = 0
    session.lastXP = Safe(UnitXP("player"))
    session.lastMax = Safe(UnitXPMax("player"))
end

local function TrackXP()
    local xp, max = Safe(UnitXP("player")), Safe(UnitXPMax("player"))
    if not xp or not max then
        return
    end
    if session.lastXP then
        -- A new level also shows as a new XP bar size (XP may have been unreadable at the level-up).
        if session.lastMax and (max ~= session.lastMax or xp < session.lastXP) then
            session.xpGained = session.xpGained + math.max(session.lastMax - session.lastXP, 0) + xp
        elseif xp >= session.lastXP then
            session.xpGained = session.xpGained + xp - session.lastXP
        end
    end
    session.lastXP, session.lastMax = xp, max
end

local function SaveCharacter()
    char.money = Safe(GetMoney()) or char.money
    char.level = Safe(UnitLevel("player")) or char.level
    -- nil means no rested XP; a hidden (secret) value keeps the last one read (final review).
    local rested = GetXPExhaustion()
    if not (issecretvalue and issecretvalue(rested)) then
        char.rested = rested or 0
    end
end

local function RefreshStats()
    local current = Safe(GetMoney())
    session.startMoney = session.startMoney or current
    statLines[1]:SetText("Session: " .. FormatDuration(GetTime() - session.start))
    if current and session.startMoney then
        local money = current - session.startMoney
        local rate = PerHour(money)
        statLines[2]:SetText(string.format("Gold: %s (%s%s)",
            FormatMoney(current), FormatMoney(money), rate and (", " .. FormatMoney(rate) .. "/hr") or ""))
    else
        statLines[2]:SetText("Gold: n/a")
    end

    local xp, max = session.lastXP, session.lastMax
    if not xp or not max or max == 0 then
        statLines[3]:SetText("XP: unavailable")
        statLines[4]:SetText("")
        return
    end
    local rested = Safe(GetXPExhaustion()) or 0
    statLines[3]:SetText(string.format("XP: %s / %s (%d%%), rested %s",
        FormatNumber(xp), FormatNumber(max), math.floor(xp * 100 / max), FormatNumber(rested)))

    local rate = PerHour(session.xpGained)
    if not rate then
        statLines[4]:SetText("Rate: shown after 10 minutes")
    elseif rate > 0 then
        statLines[4]:SetText(string.format("Rate: %s/hr, next level in %s",
            FormatNumber(rate), FormatDuration((max - xp) * 3600 / rate)))
    else
        statLines[4]:SetText("Rate: no XP gained yet")
    end
end

local function GetRow(index)
    if rows[index] then
        return rows[index]
    end
    local row = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    row:SetSize(22, 22)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -HEADER_HEIGHT - (index - 1) * ROW_HEIGHT)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", row, "RIGHT", 4, 0)
    row.label:SetWidth(WIDTH - 50)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row:SetScript("OnClick", function(self)
        char.tasks[self.index].done = self:GetChecked() and true or false
        frame.RefreshTasks()
    end)
    row.index = index
    rows[index] = row
    return row
end

local function RefreshTasks()
    for index, task in ipairs(char.tasks) do
        local row = GetRow(index)
        row:SetChecked(task.done)
        row.label:SetText(index .. ". " .. task.text)
        if task.done then
            row.label:SetTextColor(0.5, 0.5, 0.5)
        else
            row.label:SetTextColor(1, 1, 1)
        end
        row:Show()
    end
    for index = #char.tasks + 1, #rows do
        rows[index]:Hide()
    end
    frame.empty:SetShown(#char.tasks == 0)
    frame:SetHeight(HEADER_HEIGHT + math.max(#char.tasks, 1) * ROW_HEIGHT + 10)
end

local function BuildFrame()
    frame = CreateFrame("Frame", "ForeverHelperFrame", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEADER_HEIGHT + ROW_HEIGHT + 10)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.08, 0.9)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        db.position = { point, relativePoint, x, y }
    end)
    if db.position then
        local p = db.position
        frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        frame:SetPoint("RIGHT", UIParent, "RIGHT", -20, 100)
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
    title:SetText("ForeverHelper")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

    for index = 1, 4 do
        local line = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -14 - index * 16)
        line:SetWidth(WIDTH - 24)
        line:SetJustifyH("LEFT")
        line:SetWordWrap(false)
        statLines[index] = line
    end

    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.empty:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -HEADER_HEIGHT - 4)
    frame.empty:SetText("No tasks yet. Add one on the hub's Characters page.")

    frame.RefreshTasks = RefreshTasks
    frame:SetShown(db.shown)
    table.insert(UISpecialFrames, "ForeverHelperFrame")
end

-- Round 6 #15: profession cooldowns per character (idea common to Altoholic and Nova; our own code).
-- Read out of combat from the game's own cooldown of each spell (C_Spell.GetSpellCooldown, secret when
-- cooldowns are restricted) or item (C_Container.GetItemCooldown), saved as the clock time it ends. Only
-- read, never cast or used. A fixed list, so at most four entries per character.
local COOLDOWNS = {
    -- Every Classic transmute shares one cooldown: the first one known gives it.
    { key = "transmute", label = "Transmute", spells = { 17187, 11479, 11480, 17559, 17560, 17561, 17562, 17563, 17564, 17565, 17566 } },
    { key = "mooncloth", label = "Mooncloth", spells = { 18560 } },
    { key = "saltshaker", label = "Salt Shaker", item = 15846 },
    { key = "snowmaster", label = "Snowmaster 9000", item = 17716 },
}
-- Shorter than this is the global cooldown or a cast, not a profession cooldown.
local MIN_COOLDOWN = 60
local READY_CHECK_SECONDS = 30
local cooldownReadPending, lastReadyCheck = false, 0

local function CallSafe(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then
        return nil
    end
    return Safe(a), Safe(b), Safe(c)
end

local function Clock()
    return tonumber(CallSafe(time)) or 0
end

local function SpellKnown(id)
    local book = type(C_SpellBook) == "table" and C_SpellBook.IsSpellKnown
    for _, fn in ipairs({ book or false, IsPlayerSpell or false, IsSpellKnown or false }) do
        if fn and CallSafe(fn, id) == true then
            return true
        end
    end
    return false
end

-- start (GetTime clock) and duration, or nil when unreadable or secret.
local function SpellCooldown(id)
    local getter = type(C_Spell) == "table" and C_Spell.GetSpellCooldown
    if getter then
        local info = CallSafe(getter, id)
        if type(info) == "table" then
            return tonumber(Safe(info.startTime)), tonumber(Safe(info.duration))
        end
    end
    local start, duration = CallSafe(GetSpellCooldown, id)
    return tonumber(start), tonumber(duration)
end

local function ItemCooldown(id)
    local getter = type(C_Container) == "table" and C_Container.GetItemCooldown or GetItemCooldown
    local start, duration = CallSafe(getter, id)
    return tonumber(start), tonumber(duration)
end

local function ItemCount(id)
    local getter = type(C_Item) == "table" and C_Item.GetItemCount or GetItemCount
    return tonumber(CallSafe(getter, id)) or 0
end

local function InCombat()
    return CallSafe(InCombatLockdown) == true
end

-- Reads this character's profession cooldowns into its record.
local function ReadCooldowns()
    cooldownReadPending = false
    if not char or InCombat() then
        return
    end
    local now, clock = tonumber(CallSafe(GetTime)), Clock()
    if not now or clock == 0 then
        return
    end
    char.cooldowns = type(char.cooldowns) == "table" and char.cooldowns or {}
    for _, cd in ipairs(COOLDOWNS) do
        local have, start, duration = false, nil, nil
        if cd.spells then
            for _, id in ipairs(cd.spells) do
                local s, d = SpellCooldown(id)
                if SpellKnown(id) or (d and d > MIN_COOLDOWN) then
                    have = true
                    if s and d then
                        start, duration = s, d
                    end
                    if d and d > MIN_COOLDOWN then
                        break
                    end
                end
            end
        elseif ItemCount(cd.item) > 0 then
            have = true
            start, duration = ItemCooldown(cd.item)
        else
            -- The item is gone (sold, banked or deleted): its line goes too.
            char.cooldowns[cd.key] = nil
        end
        if have and start and duration then
            local entry = type(char.cooldowns[cd.key]) == "table" and char.cooldowns[cd.key] or {}
            local ends = 0
            if duration > MIN_COOLDOWN and start > 0 then
                ends = math.floor(clock + (start + duration - now) + 0.5)
            end
            if ends > clock then
                entry.ends, entry.told = ends, nil
            elseif (tonumber(entry.ends) or 0) > clock then
                -- Ready earlier than saved (a reset): ready now, and said once.
                entry.ends = clock
            else
                entry.ends = tonumber(entry.ends) or 0
            end
            char.cooldowns[cd.key] = entry
        end
    end
end

local function ReadCooldownsSoon()
    if cooldownReadPending then
        return
    end
    cooldownReadPending = true
    if C_Timer and C_Timer.After then
        C_Timer.After(2, ReadCooldowns)
    else
        ReadCooldowns()
    end
end

local function Left(seconds)
    seconds = math.max(0, math.floor(seconds))
    local days, hours, minutes = math.floor(seconds / 86400), math.floor(seconds / 3600) % 24, math.floor(seconds / 60) % 60
    if days > 0 then
        return string.format("%dd %dh", days, hours)
    elseif hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    end
    return string.format("%dm", math.max(minutes, 1))
end

-- "Mooncloth ready, Transmute in 5h 10m" for a saved character, or nil without any.
local function CooldownText(data, clock)
    local saved = type(data) == "table" and type(data.cooldowns) == "table" and data.cooldowns
    if not saved then
        return nil
    end
    local parts = {}
    for _, cd in ipairs(COOLDOWNS) do
        local entry = saved[cd.key]
        if type(entry) == "table" then
            local ends = tonumber(entry.ends) or 0
            if ends <= clock then
                parts[#parts + 1] = cd.label .. " |cff33ff33ready|r"
            else
                parts[#parts + 1] = cd.label .. " in " .. Left(ends - clock)
            end
        end
    end
    return #parts > 0 and table.concat(parts, ", ") or nil
end

-- A pop-up once when one of this character's cooldowns is ready (not while the hub has this helper Off).
local function CheckReady(force)
    local now = tonumber(CallSafe(GetTime)) or 0
    if not char or (not force and now - lastReadyCheck < READY_CHECK_SECONDS) then
        return
    end
    lastReadyCheck = now
    local saved = type(char.cooldowns) == "table" and char.cooldowns
    if not saved or (type(ForeverHub_IsOff) == "function" and ForeverHub_IsOff("ForeverHelper") == true) then
        return
    end
    local clock = Clock()
    for _, cd in ipairs(COOLDOWNS) do
        local entry = saved[cd.key]
        if type(entry) == "table" and not entry.told and (tonumber(entry.ends) or 0) > 0 and entry.ends <= clock then
            entry.told = true
            Print(cd.label .. " is ready on this character.")
        end
    end
end

local function SortedCharacters()
    local list = {}
    for key, data in pairs(db.characters) do
        if type(data) == "table" then
            local name = type(data.charName) == "string" and data.charName ~= "" and data.charName or tostring(key)
            list[#list + 1] = { name = name, data = data }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function ShowCooldowns()
    ReadCooldowns()
    local clock, any = Clock(), false
    Print("|cffffd100Profession cooldowns|r |cff999999(every character; read out of combat)|r")
    for _, row in ipairs(SortedCharacters()) do
        local text = CooldownText(row.data, clock)
        if text then
            any = true
            Print(row.name .. ": " .. text)
        end
    end
    if not any then
        Print("None seen yet. Transmutes, Mooncloth, the Salt Shaker and the Snowmaster 9000 show here once a"
            .. " character that has them logs in.")
    end
end

local function ShowCharacters()
    local rows, total = {}, 0
    for key, data in pairs(db.characters) do
        -- The saved name; older records only have their "Name-Realm" key.
        local name = type(data.charName) == "string" and data.charName ~= "" and data.charName or tostring(key)
        rows[#rows + 1] = { name = name, data = data }
        total = total + (data.money or 0)
    end
    table.sort(rows, function(a, b) return a.name < b.name end)
    local clock = Clock()
    for _, row in ipairs(rows) do
        local data = row.data
        Print(string.format("%s: level %d, %s, rested %s",
            row.name, data.level or 0, FormatMoney(data.money or 0), FormatNumber(data.rested or 0)))
        local cooldowns = CooldownText(data, clock)
        if cooldowns then
            Print("   |cff999999Cooldowns:|r " .. cooldowns)
        end
    end
    Print("Total gold: " .. FormatMoney(total))
    -- The to-dos you add on this page, so they show here too and not only in the window.
    local tasks = char and char.tasks or {}
    Print(" ")
    if #tasks == 0 then
        Print("|cff999999No to-dos for this character yet.|r")
    else
        Print("|cffffd100To-do for this character:|r")
        for index, task in ipairs(tasks) do
            Print(string.format("%d. %s%s", index, tostring(task.text), task.done and " |cff33ff33(done)|r" or ""))
        end
    end
end

local HELP = {
    "/fh - show or hide the window",
    "/fh add <task> - add a to-do for this character",
    "/fh remove <number> - remove a to-do",
    "/fh chars - list your characters and total gold",
    "/fh cooldowns - profession cooldowns on every character",
    "/fh reset - restart the session stats",
}

-- Switched Off on the hub's Manage page: the window hides and stays hidden; wantShown keeps whether you
-- had it open, for switching On again and for the save. Never Off without the hub.
local hubOff, wantShown = false, false
local function HubSaysOff()
    return type(ForeverHub_IsOff) == "function" and ForeverHub_IsOff("ForeverHelper") == true
end

local function ApplyHubSwitch()
    local off = HubSaysOff()
    if off == hubOff or not frame then
        return
    end
    hubOff = off
    if off then
        wantShown = frame:IsShown() and true or false
        frame:Hide()
    else
        frame:SetShown(wantShown)
        if wantShown and session.start then
            RefreshStats()
        end
    end
end

ForeverHubOnSwitch = ForeverHubOnSwitch or {}
ForeverHubOnSwitch.ForeverHelper = function()
    ApplyHubSwitch()
end

local function HandleSlash(message)
    local command, rest = message:match("^(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" or command == "window" then
        if hubOff then
            -- Off: the choice is kept for when it's switched On again.
            wantShown = not wantShown
        else
            frame:SetShown(not frame:IsShown())
        end
    elseif command == "add" and rest ~= "" then
        table.insert(char.tasks, { text = rest:gsub("|", "||"), done = false })
        RefreshTasks()
    elseif command == "remove" then
        local index = tonumber(rest)
        if index and char.tasks[index] then
            table.remove(char.tasks, index)
            RefreshTasks()
        else
            Print("No to-do with that number.")
        end
    elseif command == "chars" then
        SaveCharacter()
        ReadCooldowns()
        ShowCharacters()
    elseif command == "cooldowns" or command == "cd" then
        ShowCooldowns()
    elseif command == "reset" then
        ResetSession()
        RefreshStats()
        Print("Session stats restarted.")
    else
        for _, line in ipairs(HELP) do
            Print(line)
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        -- With the hub, a new install starts with the window closed (cross-addon review): its default spot at
        -- the right edge sits on the quest trackers, and the hub's side panel already shows these rates.
        -- The Characters page lists the to-dos and has an "Own window" button.
        ForeverHelperDB = ForeverHelperDB or { characters = {}, shown = ForeverHub_Receive == nil }
        db = ForeverHelperDB
        db.characters = db.characters or {}
        -- Older saves have no shown field; without this the window would hide at every login.
        if db.shown == nil then
            db.shown = true
        end
        BuildFrame()
        -- The hub's saved switches are read by now ("!ForeverHub" loads first).
        ApplyHubSwitch()
    elseif event == "PLAYER_LOGIN" then
        local key = ForeverCharacterAdopt(db.characters)
        db.characters[key] = db.characters[key] or { tasks = {} }
        char = ForeverCharacterStamp(db.characters[key])
        -- Older saves can have a character entry without a to-do list.
        char.tasks = char.tasks or {}
        SaveCharacter()
        ResetSession()
        RefreshStats()
        RefreshTasks()
        for _, name in ipairs({ "PLAYER_MONEY", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION" }) do
            events:RegisterEvent(name)
        end
        -- Profession cooldowns (round 6 #15): read a moment after login and after a cooldown changes.
        for _, name in ipairs({ "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "PLAYER_REGEN_ENABLED" }) do
            pcall(events.RegisterEvent, events, name)
        end
        ReadCooldownsSoon()
        C_Timer.NewTicker(1, function()
            if frame:IsShown() then
                RefreshStats()
            end
            CheckReady(false)
        end)
    elseif event == "PLAYER_LOGOUT" then
        -- Not saved here: the game can give wrong values while logging out, and the events above keep this current.
        if hubOff then
            db.shown = wantShown
        else
            db.shown = frame:IsShown()
        end
    elseif event == "PLAYER_LEVEL_UP" then
        char.level = Safe(arg1) or char.level
    elseif event == "PLAYER_XP_UPDATE" then
        TrackXP()
        SaveCharacter()
        RefreshStats()
    elseif event == "PLAYER_MONEY" or event == "UPDATE_EXHAUSTION" then
        SaveCharacter()
        RefreshStats()
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" or event == "PLAYER_REGEN_ENABLED" then
        if char then
            ReadCooldownsSoon()
        end
    end
end)

-- Registered up front so one bad reply at login can't leave the command missing.
SLASH_FOREVERHELPER1 = "/fh"
SLASH_FOREVERHELPER2 = "/foreverhelper"
SlashCmdList.FOREVERHELPER = function(message)
    if char then
        HandleSlash(message)
    end
end
