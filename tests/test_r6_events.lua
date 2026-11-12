-- Round 6 #3 and #20: Events (holidays from the calendar, the Darkmoon Faire, turn-ins against your bags, a tooltip
-- line on turn-in items) and GoldGuide's Darkmoon money view. Read only: the calendar is never opened as a window,
-- its month and filters are never changed, nothing is turned in, nothing goes to chat.
-- Run from the harness folder:  node run.js "<workspace root>" test_r6_events.lua
local base = ADDON_PATH
local out, failures, frames, forbidden, timers = {}, {}, {}, {}, {}
local SECRET = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
issecretvalue = function(v) return v == SECRET end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
for _, name in ipairs({ "hooksecurefunc", "print", "ToggleCalendar", "Calendar_Toggle", "Calendar_Show", "CompleteQuest",
    "GetQuestReward", "SetCVar", "UseContainerItem" }) do
    _G[name] = function() forbidden[#forbidden + 1] = name end
end
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
GetTime = function() return 1000 end
time = function() return 2000000 end
local inCombat = false
InCombatLockdown = function() return inCombat end
UnitLevel = function() return 11 end
UnitClass = function() return "Priest", "PRIEST" end
GetRealmName = function() return "R" end
UnitFactionGroup = function() return "Alliance" end

local bags = { [5134] = 3, [2309] = 7, [19182] = 2 }
C_Item = {
    GetItemCount = function(id) return bags[id] or 0 end,
    GetItemInfo = function() return nil end,
}
local professions = { { name = "Leatherworking", rank = 60, skillLine = 165 }, { name = "Skinning", rank = 70, skillLine = 393 } }
GetProfessions = function() return 1, 2 end
GetProfessionInfo = function(i)
    local p = professions[i]
    return p.name, 0, p.rank, 300, 0, 0, p.skillLine
end

-- The calendar: the player left it on December, so offsets must count from there. November holds the Faire (9-16),
-- a player event (never shown) and a holiday whose title comes back secret.
local today = { year = 2026, month = 11, monthDay = 11, weekday = 4, hour = 12, minute = 0 }
C_DateAndTime = { GetCurrentCalendarTime = function() return today end }
local calls = { open = 0 }
local calendarLoaded = true
local function T(y, m, d) return { year = y, month = m, monthDay = d, hour = 0, minute = 0 } end
local byDay = {}   -- ["y-m-d"] = list of events
local function add(y, m, d, ev) local k = y .. "-" .. m .. "-" .. d; byDay[k] = byDay[k] or {}; table.insert(byDay[k], ev) end
local faire = { title = "Darkmoon Faire", calendarType = "HOLIDAY", startTime = T(2026, 11, 9), endTime = T(2026, 11, 16) }
for d = 9, 16 do add(2026, 11, d, faire) end
add(2026, 11, 12, { title = "Raid night", calendarType = "PLAYER", startTime = T(2026, 11, 12), endTime = T(2026, 11, 12) })
add(2026, 11, 14, { title = SECRET, calendarType = "HOLIDAY", startTime = T(2026, 11, 14), endTime = T(2026, 11, 14) })
local winter = { title = "Feast of Winter Veil", calendarType = "HOLIDAY", startTime = T(2026, 12, 4), endTime = T(2027, 1, 2) }
for d = 4, 31 do add(2026, 12, d, winter) end
local viewed = { month = 12, year = 2026 }
C_Calendar = {
    OpenCalendar = function() calls.open = calls.open + 1 end,
    GetMonthInfo = function(offset) assert(offset == 0); return { month = viewed.month, year = viewed.year, numDays = 31, firstWeekday = 3 } end,
    GetNumDayEvents = function(offset, d)
        if not calendarLoaded then return 0 end
        local m, y = viewed.month + offset, viewed.year
        while m < 1 do m, y = m + 12, y - 1 end
        while m > 12 do m, y = m - 12, y + 1 end
        local list = byDay[y .. "-" .. m .. "-" .. d]
        return list and #list or 0
    end,
    GetDayEvent = function(offset, d, i)
        local m, y = viewed.month + offset, viewed.year
        while m < 1 do m, y = m + 12, y - 1 end
        while m > 12 do m, y = m - 12, y + 1 end
        return byDay[y .. "-" .. m .. "-" .. d][i]
    end,
    SetMonth = function() forbidden[#forbidden + 1] = "SetMonth" end,
    SetAbsMonth = function() forbidden[#forbidden + 1] = "SetAbsMonth" end,
}
C_CVar = { GetCVar = function() return "1" end }

-- Tooltip data hook (Blizzard's official one, as Tooltips uses).
local postCalls = {}
Enum = { TooltipDataType = { Item = 0, Unit = 2 } }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) postCalls[#postCalls + 1] = { kind = kind, fn = fn } end }
local lines = {}
GameTooltip = { AddLine = function(_, text, r, g, b) lines[#lines + 1] = { text = text, r = r, g = g, b = b } end }
local otherTip = { AddLine = function() lines[#lines + 1] = { text = "WRONG" } end }

ForeverHubDB = { off = {} }
ForeverHub_IsOff = function(name) return ForeverHubDB.off[name] == true end

assert(loadfile(base .. "/Events/Data.lua"))("Events", {})
assert(loadfile(base .. "/Events/Events.lua"))("Events", {})
local ev = frames[#frames]
local function fire(e, ...) ev.fn(ev, e, ...) end
local function page(arg) out = {}; SlashCmdList.EVENTS(arg or ""); return table.concat(out, "\n") end

check(ev.registered.PLAYER_LOGIN and ev.registered.CALENDAR_UPDATE_EVENT_LIST, "events registered")
for e in pairs(ev.registered) do
    check(not e:find("COMBAT_LOG", 1, true), "no combat log event: " .. e)
end
check(SLASH_EVENTS1 == "/fhevents", "slash command")
check(page() == "", "nothing before login")

----- Login: the tooltip hook is added, and the calendar data is asked for a few seconds later (no window)
fire("PLAYER_LOGIN")
check(#postCalls == 1 and postCalls[1].kind == 0, "one item tooltip post-call")
check(calls.open == 0 and #timers == 1, "calendar request waits for the timer")
timers[1]()
check(calls.open == 1, "OpenCalendar asked once: " .. calls.open)
-- Before the server answers, every day reads empty: that's "no data yet", not "no holidays".
calendarLoaded = false
local early = page("holidays")
check(early:find("hasn't sent its data yet", 1, true), "waits for the data:\n" .. early)
check(calls.open == 1, "no second request within a few minutes")
calendarLoaded = true
fire("CALENDAR_UPDATE_EVENT_LIST")

----- The page
local text = page()
check(text:find("Darkmoon Faire|r is on in |cffffffffElwynn Forest near Goldshire|r until 16 November.", 1, true), "faire header:\n" .. text)
check(text:find("Monthly switch", 1, true) == nil and text:find("monthly switch", 1, true), "zone guessed from the alternation is said:\n" .. text)
check(text:find("Intelligence: answer 2, 2 (or 4, 1)", 1, true) and text:find("Spirit: answer 2, 1 (or 4, 2)", 1, true), "Sayge picks for a priest:\n" .. text)
check(text:find("Prize tickets in your bags: |cffffffff2|r", 1, true), "tickets held:\n" .. text)
check(text:find("Darkmoon Storage Box", 1, true) and not text:find("Minor Darkmoon Prize", 1, true), "prizes at level 11 only:\n" .. text)
check(text:find("Small Furry Paw|r x5 for 1 ticket (Yebb Neblegear, drops from cats in Darkshore and the Barrens): |cffffaa66you have 3 of 5|r", 1, true),
    "paws line:\n" .. text)
check(not text:find("Evil Bat Eye", 1, true) and not text:find("Vibrant Plume", 1, true), "high-level drops hidden at 11:\n" .. text)
check(text:find("Leatherworking|r|cff999999 (your skill 60)|r", 1, true), "leatherworking group with skill:\n" .. text)
check(text:find("Embossed Leather Boots|r x3 for 1 ticket (Chronos, Leatherworking, about skill 55): |cff33ff33you have 7 of 3: 2 turn-ins ready|r", 1, true),
    "boots line:\n" .. text)
check(not text:find("Toughened Leather Armor", 1, true), "skill 120 item hidden at skill 60:\n" .. text)
check(not text:find("Coarse Weightstone", 1, true), "no blacksmithing without the profession")
check(text:find("Now|r |cffffffffDarkmoon Faire|r until 16 November", 1, true), "faire in the holiday list:\n" .. text)
check(text:find("Feast of Winter Veil|r: 4 December to 2 January", 1, true), "upcoming holiday read from the next month:\n" .. text)
check(not text:find("Raid night", 1, true), "player events never shown")
local _, faireCount = text:gsub("Darkmoon Faire|r until", "")
check(faireCount == 1, "an event spanning many days is listed once")

text = page("turnins")
check(text:find("Every turn-in", 1, true) and text:find("Evil Bat Eye", 1, true) and text:find("Thorium Widget", 1, true), "all turn-ins view:\n" .. text)
text = page("holidays")
check(text:find("Feast of Winter Veil", 1, true) and not text:find("Sayge", 1, true), "holidays view")

----- Side panel
local panel = ForeverHubStatus.Events()
check(panel and panel[1].page == "Events" and panel[1].text:find("Elwynn Forest until 16 November, 2 turn-ins ready", 1, true),
    "panel line: " .. tostring(panel and panel[1].text))

----- Tooltip line
local hook = postCalls[1].fn
lines = {}
hook(GameTooltip, { id = 5134 })
check(#lines == 1 and lines[1].text == "Darkmoon Faire turn-in: 5 needed, you have 3 (1 ticket, Yebb Neblegear)", "tooltip line: " .. tostring(lines[1] and lines[1].text))
lines = {}
hook(GameTooltip, { id = 2309 })
check(#lines == 1 and lines[1].g == 1 and lines[1].text:find("3 needed, you have 7", 1, true), "enough: green line")
lines = {}
hook(GameTooltip, { id = 6948 })
hook(GameTooltip, { id = SECRET })
hook(otherTip, { id = 5134 })
hook(GameTooltip, nil)
check(#lines == 0, "no line for other items, secret IDs, other tooltips or no data")

----- Calendar not loaded yet: Forever's published dates; in combat no request is sent
calendarLoaded = false
fire("CALENDAR_UPDATE_EVENT_LIST")
inCombat = true
text = page()
check(text:find("Elwynn Forest near Goldshire|r until 16 November.", 1, true) and text:find("published schedule", 1, true), "published fallback:\n" .. text)
check(text:find("Holidays|r", 1, true) and text:find("  None.", 1, true), "empty calendar after its data came: none:\n" .. text)
check(calls.open == 1, "no calendar request in combat")
inCombat = false

-- After the Faire: nothing in 30 days, and the Darkmoon filter is reported (never changed).
today = { year = 2026, month = 11, monthDay = 20 }
C_CVar.GetCVar = function() return "0" end
text = page()
check(text:find("No Darkmoon Faire on your calendar in the next 30 days.", 1, true) and text:find("filter hides the Darkmoon Faire", 1, true),
    "no faire:\n" .. text)
check(ForeverHubStatus.Events() == nil, "no panel line without an active faire")

-- A Faire the calendar names in December: zone by the alternation (Mulgore).
calendarLoaded = true
local dmf2 = { title = "Darkmoon Faire", calendarType = "HOLIDAY", startTime = T(2026, 12, 7), endTime = T(2026, 12, 13) }
for d = 7, 13 do add(2026, 12, d, dmf2) end
fire("CALENDAR_UPDATE_EVENT_LIST")
local f = Events_Faire()
check(f and not f.active and f.zone == "Mulgore" and f.fromText == "7 December", "next faire in Mulgore: " .. tostring(f and f.zone))

----- Switched Off: no tooltip line, no panel, no faire, no calendar request; On again asks once
today = { year = 2026, month = 11, monthDay = 11 }
calendarLoaded = true
ForeverHubDB.off.Events = true
ForeverHubOnSwitch.Events(true)
lines = {}
hook(GameTooltip, { id = 5134 })
check(#lines == 0, "no tooltip line when Off")
check(ForeverHubStatus.Events() == nil and Events_Faire() == nil, "no panel or faire when Off")
local before = calls.open
ForeverHubDB.off.Events = nil
ForeverHubOnSwitch.Events(false)
check(calls.open == before + 1, "back On: one calendar request")
check(Events_Faire() ~= nil, "faire again when On")

----- GoldGuide: Darkmoon money view
PriceMemory_Get = function(id)
    if id == 5134 then return { price = 3000, seen = 2000000 - 3600 } end
    if id == 2309 then return { price = 25000, seen = 2000000 } end
end
PriceMemoryDB = {}
assert(loadfile(base .. "/GoldGuide/Data.lua"))("GoldGuide", {})
assert(loadfile(base .. "/GoldGuide/GoldGuide.lua"))("GoldGuide", {})
local gg = frames[#frames]
gg.fn(gg, "PLAYER_LOGIN")
out = {}
SlashCmdList.GOLDGUIDE("darkmoon")
text = table.concat(out, "\n")
check(text:find("Darkmoon Faire|r is on in Elwynn Forest until 16 November.", 1, true), "gold guide faire line:\n" .. text)
check(text:find("Embossed Leather Boots x7: AH 2g 50s each (today), 3 make 1 ticket", 1, true), "boots priced first:\n" .. text)
check(text:find("Small Furry Paw x3: AH 30s 0c each (today), 5 make 1 ticket", 1, true), "paws priced:\n" .. text)
check(text:find("Your professions make turn-ins", 1, true) and text:find("Embossed Leather Boots (Leatherworking, about skill 55)", 1, true),
    "profession turn-ins:\n" .. text)
check((text:find("Embossed Leather Boots x7", 1, true) or 0) < (text:find("Small Furry Paw x3", 1, true) or 0), "most money first")
out = {}
SlashCmdList.GOLDGUIDE("")
text = table.concat(out, "\n")
check(text:find("Darkmoon Faire:|r on in Elwynn Forest until 16 November", 1, true), "best page points at the faire:\n" .. text)

-- Without Events loaded, GoldGuide says so instead of erroring.
local saved = Events_TurnIns
Events_TurnIns = nil
out = {}
SlashCmdList.GOLDGUIDE("darkmoon")
check(table.concat(out, "\n"):find("need the Events helper", 1, true), "no Events: a plain note")
Events_TurnIns = saved

check(#forbidden == 0, "forbidden calls: " .. table.concat(forbidden, ", "))

if #failures > 0 then
    error(#failures .. " check(s) failed:\n\n" .. table.concat(failures, "\n\n"), 0)
end
io.write("ALL TESTS PASSED\n")
