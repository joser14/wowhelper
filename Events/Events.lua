-- Events: holidays from the game's calendar, and the Darkmoon Faire: where it is, until when, and what each
-- turn-in needs and pays at your level, counted against your bags. Adds a line to turn-in items' tooltips.
-- Read only: it reads the calendar data (C_Calendar), your bags and your level. It never opens the calendar
-- window, never changes the calendar's month or filters, and never turns anything in.
-- C_Calendar.OpenCalendar() only asks the server for this month's calendar data (Blizzard's own calendar calls
-- it when it opens); it isn't a protected function. We call it at most once every few minutes, never in combat.

local LOOKAHEAD_DAYS = 30
local MAX_HOLIDAYS = 20
local REQUEST_SECONDS = 300     -- at most one calendar request this often
local LOGIN_DELAY = 5
local GOLD, GRAY, GREEN, ORANGE, WHITE = "|cffffd100", "|cff999999", "|cff33ff33", "|cffffaa66", "|cffffffff"
local MONTHS = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October",
    "November", "December" }

local loggedIn = false
local lastRequest = nil
local cache = nil               -- { key = today's day number, holidays = {...}, faire = {...} | false }
local calendarSeen = false      -- the server has sent calendar data at least once (CALENDAR_UPDATE_EVENT_LIST)

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("Events", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function IsOff()
    return ForeverHub_IsOff and ForeverHub_IsOff("Events") == true
end

local function Data()
    return type(EventsData) == "table" and EventsData or { turnins = {}, prizes = {}, sayge = {}, saygeFor = {}, zones = {}, known = {} }
end

local function Call(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b = pcall(fn, ...)
    if not ok then
        return nil
    end
    return Safe(a), Safe(b)
end

----- Dates

local function IsLeap(year)
    return (year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0
end

local function DaysInMonth(year, month)
    local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if month == 2 and IsLeap(year) then
        return 29
    end
    return days[month] or 30
end

-- Days since a fixed point, so two dates can be compared and subtracted.
local function DayNumber(year, month, day)
    local y = month <= 2 and year - 1 or year
    local era = math.floor(y / 400)
    local yoe = y - era * 400
    local m = month > 2 and month - 3 or month + 9
    local doy = math.floor((153 * m + 2) / 5) + day - 1
    local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
    return era * 146097 + doe
end

local function AddDays(year, month, day, add)
    day = day + add
    while day > DaysInMonth(year, month) do
        day = day - DaysInMonth(year, month)
        month = month + 1
        if month > 12 then
            month, year = 1, year + 1
        end
    end
    return year, month, day
end

-- A CalendarTime table as plain numbers, or nil when any part can't be read.
local function Plain(time)
    if type(time) ~= "table" or Safe(time) == nil then
        return nil
    end
    local year, month, day = Safe(time.year), Safe(time.month), Safe(time.monthDay)
    if type(year) == "number" and type(month) == "number" and type(day) == "number" then
        return { year, month, day }
    end
end

-- Today's server date { year, month, day }, or the computer's date when the game doesn't say.
local function Today()
    if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
        local now = Plain((Call(C_DateAndTime.GetCurrentCalendarTime)))
        if now then
            return now
        end
    end
    if date then
        local ok, t = pcall(date, "*t")
        if ok and type(t) == "table" and t.year then
            return { t.year, t.month, t.day }
        end
    end
end

local function DateText(d)
    return string.format("%d %s", d[3], MONTHS[d[2]] or "?")
end

local function Number(d)
    return DayNumber(d[1], d[2], d[3])
end

----- Calendar (read only)

-- Asks the server for calendar data. Never in combat, never while switched off, at most every few minutes.
local function RequestCalendar(force)
    if IsOff() or not (C_Calendar and C_Calendar.OpenCalendar) then
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        return false
    end
    local now = GetTime and Safe(GetTime()) or 0
    if not force and lastRequest and now - lastRequest < REQUEST_SECONDS then
        return false
    end
    lastRequest = now
    return (pcall(C_Calendar.OpenCalendar))
end

-- The month the calendar is set to now (the player may have browsed it); our offsets count from there.
-- We never change it.
local function ViewedMonth()
    if not (C_Calendar and C_Calendar.GetMonthInfo) then
        return nil
    end
    local info = Call(C_Calendar.GetMonthInfo, 0)
    local month, year = type(info) == "table" and Safe(info.month), type(info) == "table" and Safe(info.year)
    if type(month) == "number" and type(year) == "number" then
        return year, month
    end
end

local function IsDarkmoon(title, kind)
    return (type(title) == "string" and title:lower():find("darkmoon", 1, true) ~= nil)
        or (type(kind) == "string" and kind:upper():find("DARKMOON", 1, true) ~= nil)
end

-- Holidays (only holidays: never player, guild or community events) from today for LOOKAHEAD_DAYS days.
local function ReadHolidays(today)
    local list, seen = {}, {}
    local viewYear, viewMonth = ViewedMonth()
    if not (viewYear and C_Calendar.GetNumDayEvents and C_Calendar.GetDayEvent) then
        return list, false
    end
    local readable = false
    for add = 0, LOOKAHEAD_DAYS do
        local y, m, d = AddDays(today[1], today[2], today[3], add)
        local offset = (y * 12 + m) - (viewYear * 12 + viewMonth)
        local count = Call(C_Calendar.GetNumDayEvents, offset, d)
        if type(count) == "number" then
            readable = true
            for index = 1, math.min(count, 50) do
                local event = Call(C_Calendar.GetDayEvent, offset, d, index)
                if type(event) == "table" then
                    local title, kind = Safe(event.title), Safe(event.calendarType)
                    local from, to = Plain(event.startTime), Plain(event.endTime)
                    if type(title) == "string" and title ~= "" and type(kind) == "string" and kind:upper():find("HOLIDAY", 1, true) then
                        from = from or { y, m, d }
                        to = to or { y, m, d }
                        local key = title .. "|" .. Number(from)
                        if not seen[key] and #list < MAX_HOLIDAYS then
                            seen[key] = true
                            list[#list + 1] = { title = title, from = from, to = to, darkmoon = IsDarkmoon(title, kind) }
                        end
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if Number(a.from) ~= Number(b.from) then
            return Number(a.from) < Number(b.from)
        end
        return a.title < b.title
    end)
    return list, readable
end

-- Elwynn or Mulgore: from the event's title if it says, else by the monthly alternation since Forever's first Faire.
local function FaireZone(title, from)
    if type(title) == "string" then
        local lower = title:lower()
        if lower:find("elwynn", 1, true) then
            return "Elwynn", false
        elseif lower:find("mulgore", 1, true) then
            return "Mulgore", false
        end
    end
    local first = Data().firstMonth
    if not (first and from) then
        return nil, true
    end
    local months = (from[1] * 12 + from[2]) - (first[1] * 12 + first[2])
    local other = first[3] == "Elwynn" and "Mulgore" or "Elwynn"
    return (months % 2 == 0) and first[3] or other, true
end

-- Whether the player's calendar filter hides the Darkmoon Faire (read only; we never change it).
local function DarkmoonHidden()
    local get = (C_CVar and C_CVar.GetCVar) or GetCVar
    local value = Call(get, "calendarShowDarkmoon")
    return value == "0"
end

local function Rebuild()
    local today = Today()
    if not today then
        cache = { key = -1, holidays = {}, faire = false, readable = false }
        return cache
    end
    local holidays, readable = ReadHolidays(today)
    local todayNumber = Number(today)
    local faire = false
    for _, holiday in ipairs(holidays) do
        if holiday.darkmoon and Number(holiday.to) >= todayNumber then
            local zone, guessed = FaireZone(holiday.title, holiday.from)
            faire = { from = holiday.from, to = holiday.to, zone = zone, guessedZone = guessed, source = "calendar",
                active = Number(holiday.from) <= todayNumber }
            break
        end
    end
    if not faire then
        -- The calendar didn't list it (not loaded yet, or the Darkmoon filter is off): Forever's published dates.
        for _, known in ipairs(Data().known or {}) do
            if Number(known.to) >= todayNumber and Number(known.from) - todayNumber <= LOOKAHEAD_DAYS then
                faire = { from = known.from, to = known.to, zone = known.zone, guessedZone = false, source = "published",
                    active = Number(known.from) <= todayNumber }
                break
            end
        end
    end
    -- Before the server answers, every day reads as empty: that isn't "no holidays".
    readable = readable and (calendarSeen or #holidays > 0)
    cache = { key = todayNumber, holidays = holidays, faire = faire, readable = readable, today = today }
    return cache
end

local function State()
    local today = Today()
    if not cache or not today or cache.key ~= Number(today) or cache.dirty then
        Rebuild()
    end
    return cache
end

----- Your character and bags

local function PlayerLevel()
    local level = UnitLevel and Safe(UnitLevel("player"))
    return type(level) == "number" and level > 0 and level or nil
end

local function PlayerClass()
    if not UnitClass then
        return nil
    end
    local _, class = Call(UnitClass, "player")
    return type(class) == "string" and class or nil
end

-- Count in your bags (not the bank: you hand in from your bags).
local function BagCount(itemID)
    if not (C_Item and C_Item.GetItemCount) then
        return 0
    end
    local count = Call(C_Item.GetItemCount, itemID)
    return type(count) == "number" and count or 0
end

local function ItemName(entry)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local name = getInfo and Call(getInfo, entry.item)
    return type(name) == "string" and name or entry.name
end

-- { [profession name] = skill } for Blacksmithing, Leatherworking and Engineering.
local function CraftSkills()
    local have, byLine = {}, {}
    for name, line in pairs(Data().skillLines or {}) do
        byLine[line] = name
    end
    if GetProfessions and GetProfessionInfo then
        local slots = { pcall(GetProfessions) }
        if slots[1] then
            for position = 2, 6 do
                local index = Safe(slots[position])
                if index then
                    local ok, name, _, rank, _, _, _, skillLine = pcall(GetProfessionInfo, index)
                    name, rank, skillLine = ok and Safe(name), ok and Safe(rank), ok and Safe(skillLine)
                    local craft = byLine[skillLine] or ((Data().skillLines or {})[name] and name)
                    if craft and type(rank) == "number" then
                        have[craft] = rank
                    end
                end
            end
        end
    elseif type(ForeverSkillProfessions) == "function" then
        local ok, list = pcall(ForeverSkillProfessions)
        for _, entry in ipairs(ok and type(list) == "table" and list or {}) do
            local craft = byLine[entry.skillLine]
            if craft then
                have[craft] = entry.rank
            end
        end
    end
    return have
end

-- Turn-ins worth showing now: beast drops near your level, crafted ones near your skill, and any you hold.
local function TurnInsForYou(level, skills)
    local list = {}
    for _, entry in ipairs(Data().turnins or {}) do
        local held = BagCount(entry.item)
        local fits
        if entry.group == "beast" then
            fits = level and level + 5 >= entry.minLevel and level <= entry.maxLevel + 5
        else
            local skill = skills[entry.group]
            fits = type(skill) == "number" and skill + 25 >= entry.skill
        end
        if fits or held > 0 then
            list[#list + 1] = { entry = entry, held = held }
        end
    end
    return list
end

local function TurnInLine(row)
    local entry, held = row.entry, row.held
    local need = entry.count
    local state
    if held >= need then
        local times = math.floor(held / need)
        state = string.format("%syou have %d of %d: %d turn-in%s ready|r", GREEN, held, need, times, times == 1 and "" or "s")
    elseif held > 0 then
        state = string.format("%syou have %d of %d|r", ORANGE, held, need)
    else
        state = string.format("%syou have 0 of %d|r", GRAY, need)
    end
    local pays = string.format("%d ticket%s", entry.tickets, entry.tickets == 1 and "" or "s")
    local source = entry.group == "beast" and (entry.from and (", drops from " .. entry.from) or "")
        or string.format(", %s, about skill %d", entry.group, entry.skill)
    return string.format("  %s%s|r x%d for %s (%s%s): %s", WHITE, ItemName(entry), need, pays, entry.npc, source, state)
end

----- Exported for GoldGuide and tests

-- The turn-in table (read only), whether or not Events is switched on.
function Events_TurnIns()
    return Data().turnins or {}
end

-- The turn-in entry for an item, or nil.
function Events_TurnInFor(itemID)
    for _, entry in ipairs(Data().turnins or {}) do
        if entry.item == itemID then
            return entry
        end
    end
end

-- The next or current Darkmoon Faire: { active, zone, where, from, to, fromText, toText, source }, or nil when
-- none is known in the next 30 days or Events is switched off.
function Events_Faire()
    if IsOff() then
        return nil
    end
    local faire = State().faire
    if not faire then
        return nil
    end
    local zone = (Data().zones or {})[faire.zone or ""] or {}
    return { active = faire.active, zone = zone.name or faire.zone, where = zone.where, from = faire.from, to = faire.to,
        fromText = DateText(faire.from), toText = DateText(faire.to), source = faire.source, guessedZone = faire.guessedZone }
end

----- Page

local function FaireHeader(faire)
    if not faire then
        Print(GOLD .. "Darkmoon Faire|r")
        Print("No Darkmoon Faire on your calendar in the next 30 days.")
        if DarkmoonHidden() then
            Print(GRAY .. "Your calendar's filter hides the Darkmoon Faire (Calendar > Filter); Events doesn't change it.|r")
        end
        return
    end
    local where = faire.zone and (faire.zone .. (faire.where and (" " .. faire.where) or "")) or "a place the calendar doesn't name"
    if faire.active then
        Print(string.format("%sDarkmoon Faire|r is on in %s%s|r until %s.", GOLD, WHITE, where, faire.toText))
    else
        Print(string.format("%sNext Darkmoon Faire|r: %s%s|r, %s to %s.", GOLD, WHITE, where, faire.fromText, faire.toText))
    end
    if faire.source == "published" then
        Print(GRAY .. "Dates from Forever's published schedule: the calendar hasn't listed the Faire yet.|r")
    elseif faire.guessedZone then
        Print(GRAY .. "Place from the Faire's monthly switch between Elwynn Forest and Mulgore.|r")
    end
end

local function ShowSayge()
    local data = Data()
    local class = PlayerClass()
    local picks = class and data.saygeFor and data.saygeFor[class]
    local parts = {}
    for _, buff in ipairs(picks or {}) do
        for _, fortune in ipairs(data.sayge or {}) do
            if fortune.buff == buff then
                parts[#parts + 1] = string.format("%s: answer %s", buff, fortune.answers)
            end
        end
    end
    local text = "Sayge's fortune: a free two-hour buff. Talk to Sayge and answer his questions."
    if #parts > 0 then
        text = text .. " For you: " .. table.concat(parts, "; ") .. "."
    end
    Print(text)
end

local function ShowPrizes(level)
    local tickets = BagCount(Data().TICKET)
    local parts = {}
    for _, prize in ipairs(Data().prizes or {}) do
        if not level or prize.level <= level then
            parts[#parts + 1] = string.format("%s (%d)", prize.name, prize.tickets)
        end
    end
    Print(string.format("Prize tickets in your bags: %s%d|r. Gelvas Grimegate trades them for prizes.", WHITE, tickets))
    if #parts > 0 then
        Print(GRAY .. "At your level: " .. table.concat(parts, ", ") .. ".|r")
    end
end

local function ShowTurnIns(all)
    local level = PlayerLevel()
    local skills = CraftSkills()
    local rows
    if all then
        rows = {}
        for _, entry in ipairs(Data().turnins or {}) do
            rows[#rows + 1] = { entry = entry, held = BagCount(entry.item) }
        end
    else
        rows = TurnInsForYou(level, skills)
    end
    Print(" ")
    Print(GOLD .. (all and "Every turn-in" or "Turn-ins for you") .. "|r" .. (level and not all and (GRAY .. " (level " .. level .. ")|r") or ""))
    if #rows == 0 then
        Print("None fit your level or professions yet. Small Furry Paws (cats in Darkshore and the Barrens) are the first, from about level 10.")
        return
    end
    local group
    for _, row in ipairs(rows) do
        local name = row.entry.group == "beast" and "Beast drops (anyone)" or row.entry.group
        if name ~= group then
            group = name
            local skill = skills[row.entry.group]
            Print(ORANGE .. name .. "|r" .. (type(skill) == "number" and (GRAY .. " (your skill " .. skill .. ")|r") or ""))
        end
        Print(TurnInLine(row))
    end
    Print(GRAY .. "Each turn-in also gives Darkmoon Faire reputation. The cheaper ones stop once that reputation rises; the 20-ticket ones never stop.|r")
end

local function ShowHolidays(onlyUpcoming)
    local state = State()
    Print(" ")
    Print(GOLD .. "Holidays|r " .. GRAY .. "(next 30 days, from the game's calendar)|r")
    if not state.readable then
        Print(GRAY .. "The calendar hasn't sent its data yet. Open this page again in a moment.|r")
        RequestCalendar(false)
        return
    end
    local todayNumber = state.key
    local shown = 0
    for _, holiday in ipairs(state.holidays) do
        local now = Number(holiday.from) <= todayNumber and Number(holiday.to) >= todayNumber
        if not (onlyUpcoming and now) then
            shown = shown + 1
            if now then
                Print(string.format("  %sNow|r %s%s|r until %s", GREEN, WHITE, holiday.title, DateText(holiday.to)))
            else
                Print(string.format("  %s%s|r: %s to %s", WHITE, holiday.title, DateText(holiday.from), DateText(holiday.to)))
            end
        end
    end
    if shown == 0 then
        Print("  None.")
    end
end

local function ShowPage(arg)
    if not loggedIn then
        return
    end
    local want = type(arg) == "string" and arg:lower():match("^%s*(.-)%s*$") or ""
    if not (cache and cache.readable) then
        RequestCalendar(false)
    end
    if want == "upcoming" or want == "holidays" then
        ShowHolidays(false)
        return
    elseif want == "turnins" or want == "all" then
        FaireHeader(Events_Faire())
        ShowTurnIns(true)
        return
    elseif want ~= "" then
        Print("Type: holidays, or: turnins.")
    end
    local faire = Events_Faire()
    FaireHeader(faire)
    if faire then
        ShowSayge()
        ShowPrizes(PlayerLevel())
        ShowTurnIns(false)
    end
    ShowHolidays(false)
end

----- Tooltip line on turn-in items (Blizzard's tooltip data hook, as Tooltips uses; no Blizzard function is hooked)

local function TooltipLine(tooltip, data)
    if IsOff() or type(data) ~= "table" then
        return
    end
    if not (tooltip ~= nil and (tooltip == GameTooltip or tooltip == ItemRefTooltip)) then
        return
    end
    local id = Safe(data.id)
    if type(id) ~= "number" then
        return
    end
    local entry = Events_TurnInFor(id)
    if not entry then
        return
    end
    local held = BagCount(id)
    local text = string.format("Darkmoon Faire turn-in: %d needed, you have %d (%d ticket%s, %s)", entry.count, held,
        entry.tickets, entry.tickets == 1 and "" or "s", entry.npc)
    if held >= entry.count then
        tooltip:AddLine(text, 0.2, 1, 0.2)
    else
        tooltip:AddLine(text, 0.8, 0.6, 1)
    end
end

local function OnItemTooltip(tooltip, data)
    pcall(TooltipLine, tooltip, data)
end

local registered = false
local function RegisterTooltip()
    local processor = TooltipDataProcessor
    local types = Enum and Enum.TooltipDataType
    if type(processor) ~= "table" or type(processor.AddTooltipPostCall) ~= "function" or type(types) ~= "table" or types.Item == nil then
        return false
    end
    return (pcall(processor.AddTooltipPostCall, types.Item, OnItemTooltip))
end

----- Events

if CreateFrame then
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGIN" then
            loggedIn = true
            if not registered then
                registered = RegisterTooltip()
            end
            if C_Timer and C_Timer.After then
                C_Timer.After(LOGIN_DELAY, function()
                    RequestCalendar(true)
                end)
            else
                RequestCalendar(true)
            end
        elseif event == "CALENDAR_UPDATE_EVENT_LIST" then
            calendarSeen = true
            if cache then
                cache.dirty = true
            end
        end
    end)
end

-- Switched Off on the hub: no calendar requests, no tooltip lines, no panel line (the hub hides the page).
-- Back On: read the calendar again.
ForeverHubOnSwitch = ForeverHubOnSwitch or {}
ForeverHubOnSwitch.Events = function(off)
    cache = nil
    if not off and loggedIn then
        RequestCalendar(true)
    end
end

SLASH_EVENTS1 = "/fhevents"
SlashCmdList.EVENTS = ShowPage

-- Side panel: the Faire while it's on, with how many turn-ins you could hand in now.
ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.Events = function()
    if not loggedIn or IsOff() then
        return nil
    end
    local faire = Events_Faire()
    if not (faire and faire.active) then
        return nil
    end
    local ready = 0
    for _, entry in ipairs(Data().turnins or {}) do
        ready = ready + math.floor(BagCount(entry.item) / entry.count)
    end
    local text = string.format("%sDarkmoon Faire|r %s until %s", GOLD, faire.zone or "on", faire.toText)
    if ready > 0 then
        text = text .. string.format(", %d turn-in%s ready", ready, ready == 1 and "" or "s")
    end
    return { { text = text, page = "Events" } }
end
