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

local function PerHour(amount)
    -- The 60s floor keeps the first few seconds of a session from showing absurd rates.
    return amount * 3600 / math.max(GetTime() - session.start, 60)
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
        if xp >= session.lastXP then
            session.xpGained = session.xpGained + xp - session.lastXP
        else
            session.xpGained = session.xpGained + session.lastMax - session.lastXP + xp
        end
    end
    session.lastXP, session.lastMax = xp, max
end

local function SaveCharacter()
    char.money = Safe(GetMoney()) or char.money
    char.level = Safe(UnitLevel("player")) or char.level
    char.rested = Safe(GetXPExhaustion()) or 0
end

local function RefreshStats()
    local current = Safe(GetMoney())
    session.startMoney = session.startMoney or current
    statLines[1]:SetText("Session: " .. FormatDuration(GetTime() - session.start))
    if current and session.startMoney then
        local money = current - session.startMoney
        statLines[2]:SetText(string.format("Gold: %s (%s, %s/hr)",
            FormatMoney(current), FormatMoney(money), FormatMoney(PerHour(money))))
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
    if rate > 0 then
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

local function ShowCharacters()
    local names, total = {}, 0
    for name, data in pairs(db.characters) do
        names[#names + 1] = name
        total = total + (data.money or 0)
    end
    table.sort(names)
    for _, name in ipairs(names) do
        local data = db.characters[name]
        Print(string.format("%s: level %d, %s, rested %s",
            name, data.level or 0, FormatMoney(data.money or 0), FormatNumber(data.rested or 0)))
    end
    Print("Total gold: " .. FormatMoney(total))
end

local HELP = {
    "/fh - show or hide the window",
    "/fh add <task> - add a to-do for this character",
    "/fh remove <number> - remove a to-do",
    "/fh chars - list your characters and total gold",
    "/fh reset - restart the session stats",
}

local function HandleSlash(message)
    local command, rest = message:match("^(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" or command == "window" then
        frame:SetShown(not frame:IsShown())
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
        ShowCharacters()
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
        ForeverHelperDB = ForeverHelperDB or { characters = {}, shown = true }
        db = ForeverHelperDB
        db.characters = db.characters or {}
        -- Older saves have no shown field; without this the window would hide at every login.
        if db.shown == nil then
            db.shown = true
        end
        BuildFrame()
    elseif event == "PLAYER_LOGIN" then
        local key = (Safe(UnitName("player")) or "Unknown") .. "-" .. (Safe(GetRealmName()) or "Unknown")
        db.characters[key] = db.characters[key] or { tasks = {} }
        char = db.characters[key]
        -- Older saves can have a character entry without a to-do list.
        char.tasks = char.tasks or {}
        SaveCharacter()
        ResetSession()
        RefreshStats()
        RefreshTasks()
        for _, name in ipairs({ "PLAYER_MONEY", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION" }) do
            events:RegisterEvent(name)
        end
        C_Timer.NewTicker(1, function()
            if frame:IsShown() then
                RefreshStats()
            end
        end)
    elseif event == "PLAYER_LOGOUT" then
        -- Not saved here: the game can give wrong values while logging out, and the events above keep this current.
        db.shown = frame:IsShown()
    elseif event == "PLAYER_LEVEL_UP" then
        char.level = Safe(arg1) or char.level
    elseif event == "PLAYER_XP_UPDATE" then
        TrackXP()
        SaveCharacter()
        RefreshStats()
    elseif event == "PLAYER_MONEY" or event == "UPDATE_EXHAUSTION" then
        SaveCharacter()
        RefreshStats()
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
