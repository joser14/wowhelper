-- SpellMath: for each rank you know of your heals and damage spells, the amount, mana cost and cast time,
-- and from those the heal or damage per mana and per second. Marks the rank that gives the most per mana,
-- and old ranks that are now worse on both counts. Shown on its hub page and, optionally, as one line on
-- spell tooltips.
-- Read-only: it never casts, never targets, never touches your action bars or Blizzard's frames.
-- Everything is read out of combat (spell text and stats can be hidden in combat) and kept until the next
-- out-of-combat read; the tooltip line only reads that cache.
-- Ideas from Spellwise (no licence: ideas only, no code). The cast-time and global-cooldown arithmetic is
-- plain game maths.
local SOURCE = "SpellMath"
local GCD = 1.5               -- an instant still costs the global cooldown
local MAX_IDS = 600           -- spell IDs looked at per read, at most
local IDS_PER_STEP = 40       -- spread over frames, this many per frame
local READ_EVERY = 5          -- at most one read per this many seconds, however many events arrive
local LOAD_RETRY_LIMIT = 3

-- Used when TrainerNotes' Forever spell list isn't loaded: the priest ranks that heal or deal damage.
local FALLBACK = {
    PRIEST = {
        2050, 2052, 2053,                                            -- Lesser Heal
        2054, 2055, 6063, 6064,                                      -- Heal
        2060, 10963, 10964, 10965,                                   -- Greater Heal
        2061, 9472, 9473, 9474, 10915, 10916, 10917,                 -- Flash Heal
        139, 6074, 6075, 6076, 6077, 6078, 10927, 10928, 10929,      -- Renew
        17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901,  -- Power Word: Shield
        585, 591, 598, 984, 1004, 6060, 10933, 10934,                -- Smite
        589, 594, 970, 992, 2767, 10892, 10893, 10894,               -- Shadow Word: Pain
        8092, 8102, 8103, 8104, 8105, 8106, 10945, 10946, 10947,     -- Mind Blast
        14914, 15262, 15263, 15264, 15265, 15266, 15267, 15261,      -- Holy Fire
        15407, 17311, 17312, 17313, 17314, 18807,                    -- Mind Flay
    },
}

local db
-- families: list of { name, kind, ranks = { entries } }; byID: spellID -> entry. Rebuilt by each read.
local cache = { families = {}, byID = {}, readAt = nil, bonusHeal = nil, bonusDamage = nil }
local inCombat = false
local dirty = true
local reading, pending = false, false
local lastRead
local waitingSpells, loadRetries = {}, 0

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, result = pcall(fn, ...)
    return ok and Safe(result) or nil
end

-- The hub page captures these lines; with no hub there's nowhere to show them, so nothing goes to chat.
local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive(SOURCE, text)
    end
end

local function DB()
    if not db then
        SpellMathDB = type(SpellMathDB) == "table" and SpellMathDB or {}
        -- Only one setting is kept: whether spell tooltips get the extra line.
        if type(SpellMathDB.tooltip) ~= "boolean" then
            SpellMathDB.tooltip = true
        end
        for key in pairs(SpellMathDB) do
            if key ~= "tooltip" then
                SpellMathDB[key] = nil
            end
        end
        db = SpellMathDB
    end
    return db
end

local function IsOff()
    if type(ForeverHub_IsOff) ~= "function" then
        return false
    end
    local ok, off = pcall(ForeverHub_IsOff, SOURCE)
    return ok and off == true
end

local function InCombat()
    if InCombatLockdown then
        local value = SafeCall(InCombatLockdown)
        if value ~= nil then
            return value and true or false
        end
    end
    return inCombat
end

local function PlayerClass()
    if not UnitClass then
        return nil
    end
    local ok, _, file = pcall(UnitClass, "player")
    return ok and Safe(file) or nil
end

local function Now()
    local now = GetTime and SafeCall(GetTime)
    return type(now) == "number" and now or nil
end

------------------------------------------------------------------------------------------------ reading a spell

local function Number(text)
    return tonumber((tostring(text):gsub(",", "")))
end

-- A single number right after one of these words is the amount ("absorbing 44 damage", "heals you for 50").
local SINGLE = { "absorbing (%d+)", "absorbs (%d+)", "for (%d+)", "causing (%d+)", "causes (%d+)", "inflicts (%d+)",
    "inflicting (%d+)", "deals (%d+)", "dealing (%d+)" }

-- The spell's own tooltip text into { kind = "heal"/"damage", direct, over, duration, total }, or nil when
-- it states no heal or damage amount. Examples it reads:
--   "Heal your target for 47 to 58."                                       direct 52.5
--   "Heals the target of 45 damage over 15 sec."                           45 over 15 s
--   "... causes 84 to 104 Fire damage and an additional 30 Fire damage over 10 sec."   both
--   "... absorbing 44 damage. Lasts 30 sec."                               direct 44
local function Parse(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end
    text = text:gsub("(%d),(%d%d%d)", "%1%2")
    local lower = text:lower()
    -- Melee strikes add to your weapon; finishing moves list one amount per combo point. Neither is one number.
    if lower:find("weapon damage", 1, true) or lower:find("combo point", 1, true) then
        return nil
    end
    local kind
    if lower:find("heal", 1, true) or lower:find("absorb", 1, true) then
        kind = "heal"
    elseif lower:find("damage", 1, true) then
        kind = "damage"
    else
        return nil
    end
    local overAt, _, over, _, duration = text:find("(%d+)([^%d%.]-)over (%d+) sec")
    over, duration = over and Number(over), duration and Number(duration)
    local direct = 0
    local rangeAt, _, low, high = text:find("(%d+) to (%d+)")
    if rangeAt and (not overAt or rangeAt < overAt) then
        direct = (Number(low) + Number(high)) / 2
    else
        local best
        for _, pattern in ipairs(SINGLE) do
            local at, stop, value = lower:find(pattern)
            if at and (not overAt or stop < overAt) and (not best or at < best.at) then
                local after = lower:sub(stop + 1, stop + 5)
                -- "by 40%", "for 5 sec" and "for 30 min" are not amounts.
                if not (after:match("^%s*%%") or after:match("^%s*sec") or after:match("^%s*min")) then
                    best = { at = at, value = Number(value) }
                end
            end
        end
        direct = best and best.value or 0
    end
    local total = direct + (over or 0)
    if total <= 0 then
        return nil
    end
    return { kind = kind, direct = direct, over = over, duration = duration, total = total }
end

local function RequestLoad(id)
    waitingSpells[id] = true
    if C_Spell and C_Spell.RequestLoadSpellData then
        pcall(C_Spell.RequestLoadSpellData, id)
    end
end

-- Mana (or the class's own power) for one cast: the mana entry if the spell costs mana, else the first.
local POWER_NAMES = { [0] = "mana", [1] = "rage", [2] = "focus", [3] = "energy" }
local function Cost(id)
    local costs = C_Spell and SafeCall(C_Spell.GetSpellPowerCost, id)
    if type(costs) ~= "table" then
        return nil
    end
    local pick
    for _, entry in ipairs(costs) do
        if type(entry) == "table" then
            local kind, cost = Safe(entry.type), Safe(entry.cost)
            if type(cost) == "number" and cost > 0 then
                if kind == 0 then
                    pick = { cost = cost, power = "mana" }
                    break
                end
                pick = pick or { cost = cost, power = POWER_NAMES[kind] or "power" }
            end
        end
    end
    return pick
end

-- One known spell rank, or nil (not a heal or damage spell, or not readable now).
local function ReadSpell(id)
    local name = SafeCall(C_Spell.GetSpellName, id)
    if type(name) ~= "string" or name == "" then
        RequestLoad(id)
        return nil
    end
    local text = SafeCall(C_Spell.GetSpellDescription, id)
    if type(text) ~= "string" or text == "" then
        RequestLoad(id)
        return nil
    end
    local parsed = Parse(text)
    if not parsed then
        return nil
    end
    local info = SafeCall(C_Spell.GetSpellInfo, id)
    local castMs = type(info) == "table" and Safe(info.castTime) or nil
    local cast = type(castMs) == "number" and castMs > 0 and castMs / 1000 or 0
    -- Per second: the time a cast takes you (an instant costs the global cooldown). A heal or damage over
    -- time with nothing up front counts its whole duration (a channel's too).
    local seconds
    if parsed.direct > 0 then
        seconds = math.max(cast, GCD)
    else
        seconds = math.max(cast, parsed.duration or 0, GCD)
    end
    local cost = Cost(id)
    local subtext = SafeCall(C_Spell.GetSpellSubtext, id)
    local rank = type(subtext) == "string" and subtext:match("(%d+)")
    rank = rank and Number(rank) or nil
    return {
        id = id, name = name, rank = rank, kind = parsed.kind, direct = parsed.direct, over = parsed.over,
        duration = parsed.duration, total = parsed.total, cast = cast, seconds = seconds,
        cost = cost and cost.cost, power = cost and cost.power or "mana",
        perCost = cost and parsed.total / cost.cost or nil, perSecond = parsed.total / seconds,
    }
end

------------------------------------------------------------------------------------------------ which spells

local function KnowsID(id)
    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    if C_SpellBook and C_SpellBook.IsSpellKnown and SafeCall(C_SpellBook.IsSpellKnown, id, bank) == true then
        return true
    end
    return SafeCall(IsPlayerSpell, id) == true or SafeCall(IsSpellKnown, id) == true
end

-- Every spell ID worth a look: your spellbook (some clients list only the top rank there), then every rank
-- in TrainerNotes' Forever spell list for your class (lower ranks too), else the fallback list.
-- Returns the IDs and, for each, whether the spellbook already says you know it.
local function Candidates()
    local ids, inBook, count = {}, {}, 0
    local function Add(id, book)
        if type(id) ~= "number" or id <= 0 then
            return
        end
        if book then
            inBook[id] = true
        end
        if ids[id] == nil and count < MAX_IDS then
            count = count + 1
            ids[id] = count
        end
    end
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        local spellType = (Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell) or 1
        for line = 1, SafeCall(C_SpellBook.GetNumSpellBookSkillLines) or 0 do
            local info = SafeCall(C_SpellBook.GetSpellBookSkillLineInfo, line)
            local offset = type(info) == "table" and Safe(info.itemIndexOffset)
            local items = type(info) == "table" and Safe(info.numSpellBookItems)
            if type(offset) == "number" and type(items) == "number" then
                for slot = offset + 1, offset + items do
                    local item = SafeCall(C_SpellBook.GetSpellBookItemInfo, slot, bank)
                    if type(item) == "table" and Safe(item.itemType) == spellType and not Safe(item.isOffSpec) then
                        Add(Safe(item.spellID) or Safe(item.actionID), true)
                    end
                end
            end
        end
    end
    local class = PlayerClass()
    local data = type(TrainerNotesData) == "table" and type(TrainerNotesData.classes) == "table"
        and TrainerNotesData.classes[class or ""]
    if type(data) == "table" then
        for _, group in ipairs(type(data.ranks) == "table" and data.ranks or {}) do
            for _, id in ipairs(group) do
                Add(id)
            end
        end
        for _, entry in ipairs(type(data.spells) == "table" and data.spells or {}) do
            if type(entry) == "table" then
                Add(entry[2])
                -- A rank 1 you start with (Smite, Lesser Heal) is only named as what the next rank needs.
                for _, need in ipairs(type(entry.req) == "table" and entry.req or {}) do
                    Add(need)
                end
            end
        end
    else
        for _, id in ipairs(FALLBACK[class or ""] or {}) do
            Add(id)
        end
    end
    local list = {}
    for id, order in pairs(ids) do
        list[order] = id
    end
    return list, inBook
end

------------------------------------------------------------------------------------------------ the maths

local function RankLabel(entry)
    return entry.rank and ("Rank " .. entry.rank) or entry.name
end

-- Groups the read ranks by spell name, sorts them, and marks the best per mana and the outclassed ones.
local function Finish(entries)
    local byName, families, byID = {}, {}, {}
    for _, entry in ipairs(entries) do
        local family = byName[entry.name]
        if not family then
            family = { name = entry.name, kind = entry.kind, ranks = {} }
            byName[entry.name] = family
            families[#families + 1] = family
        end
        family.ranks[#family.ranks + 1] = entry
        byID[entry.id] = entry
    end
    for _, family in ipairs(families) do
        local ranks = family.ranks
        table.sort(ranks, function(a, b)
            if a.rank and b.rank and a.rank ~= b.rank then
                return a.rank < b.rank
            end
            return a.total < b.total
        end)
        -- Ranks the game shows without a number get their place in the list.
        local numbered = true
        for _, entry in ipairs(ranks) do
            numbered = numbered and entry.rank ~= nil
        end
        if not numbered and #ranks > 1 then
            for index, entry in ipairs(ranks) do
                entry.rank = index
            end
        end
        if #ranks > 1 then
            local best
            for _, entry in ipairs(ranks) do
                if entry.perCost and (not best or entry.perCost > best.perCost) then
                    best = entry
                end
            end
            if best then
                best.bestPerCost = true
            end
            for _, entry in ipairs(ranks) do
                for _, other in ipairs(ranks) do
                    if other ~= entry and entry.perCost and other.perCost and other.perCost > entry.perCost
                        and other.perSecond > entry.perSecond then
                        -- The highest such rank is the one to name.
                        if not entry.beatenBy or (other.rank or 0) > (entry.beatenBy.rank or 0) then
                            entry.beatenBy = other
                        end
                    end
                end
            end
        end
    end
    table.sort(families, function(a, b)
        if a.kind ~= b.kind then
            return a.kind == "heal"
        end
        return a.name < b.name
    end)
    cache.families, cache.byID = families, byID
    cache.readAt = Now()
    -- Gear's +healing and +spell damage, as numbers to show beside the table (schools 2-7: holy to arcane).
    cache.bonusHeal = SafeCall(GetSpellBonusHealing)
    local damage
    for school = 2, 7 do
        local value = SafeCall(GetSpellBonusDamage, school)
        if type(value) == "number" and (not damage or value > damage) then
            damage = value
        end
    end
    cache.bonusDamage = damage
end

local Schedule

-- One read, spread over frames. Combat starting part-way drops it; it runs again when combat ends.
local function Read()
    if reading then
        pending = true
        return
    end
    if InCombat() or IsOff() or not (C_Spell and C_Spell.GetSpellDescription) then
        dirty = true
        return
    end
    reading, dirty, lastRead = true, false, Now()
    waitingSpells = {}
    local ids, inBook = Candidates()
    local entries, index = {}, 1
    local function Step()
        if InCombat() or IsOff() then
            reading, dirty = false, true
            return
        end
        for _ = 1, IDS_PER_STEP do
            local id = ids[index]
            if not id then
                reading = false
                Finish(entries)
                if pending then
                    pending = false
                    Schedule(READ_EVERY)
                elseif next(waitingSpells) and loadRetries < LOAD_RETRY_LIMIT then
                    -- Some spell text hadn't loaded; SPELL_DATA_LOAD_RESULT usually brings it first.
                    loadRetries = loadRetries + 1
                    Schedule(3)
                end
                return
            end
            index = index + 1
            if inBook[id] or KnowsID(id) then
                local entry = ReadSpell(id)
                if entry then
                    entries[#entries + 1] = entry
                end
            end
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(0, Step)
        else
            Step()
        end
    end
    Step()
end

local scheduled = false
-- Throttle: one read per READ_EVERY seconds, however many events ask.
function Schedule(delay)
    if scheduled then
        return
    end
    if not (C_Timer and C_Timer.After) then
        return Read()
    end
    local now = Now()
    if now and lastRead and now - lastRead < READ_EVERY then
        delay = math.max(delay or 0, READ_EVERY - (now - lastRead))
    end
    scheduled = true
    C_Timer.After(delay or 0, function()
        scheduled = false
        Read()
    end)
end

------------------------------------------------------------------------------------------------ the page

local function Round(value)
    if value >= 100 then
        return string.format("%d", math.floor(value + 0.5))
    elseif value >= 10 then
        return string.format("%.1f", value)
    end
    return string.format("%.2f", value)
end

local function Amount(entry)
    local parts = {}
    if entry.direct > 0 then
        parts[#parts + 1] = Round(entry.direct)
    end
    if entry.over then
        parts[#parts + 1] = string.format("%s over %d s", Round(entry.over), math.floor(entry.duration or 0))
    end
    return table.concat(parts, " + ")
end

local function CastText(entry)
    if entry.cast > 0 then
        return string.format("%s s cast", Round(entry.cast))
    end
    return "instant"
end

local function RankLine(entry)
    local word = entry.kind == "heal" and "heal" or "damage"
    local cost = entry.cost and string.format("%d %s", math.floor(entry.cost + 0.5), entry.power) or "no cost"
    local rates = {}
    if entry.perCost then
        rates[#rates + 1] = string.format("%s %s per %s", Round(entry.perCost), word, entry.power)
    end
    rates[#rates + 1] = string.format("%s per second", Round(entry.perSecond))
    local line = string.format("  %s: %s %s, %s, %s. %s.", RankLabel(entry), Amount(entry), word, cost, CastText(entry),
        table.concat(rates, ", "))
    if entry.beatenBy then
        return "|cff999999" .. line .. " Worse on both than " .. RankLabel(entry.beatenBy) .. ".|r"
    elseif entry.bestPerCost then
        return line .. " |cff66ff66Most per " .. entry.power .. ".|r"
    end
    return line
end

local function ShowPage()
    if not InCombat() and not IsOff() then
        -- Fresh numbers when you look (gear may have changed); the page shows the last read meanwhile.
        Schedule(0)
    end
    Print("|cffffd100Your spells, rank by rank|r")
    if #cache.families == 0 then
        if InCombat() or not cache.readAt then
            Print("  Worked out out of combat. Open this page again in a moment.")
        else
            Print("  None of the spells you know states a heal or damage amount yet.")
        end
    end
    for _, family in ipairs(cache.families) do
        Print(string.format("|cff88bbee%s|r (%s)", family.name, family.kind == "heal" and "heals" or "damage"))
        for index = #family.ranks, 1, -1 do
            Print(RankLine(family.ranks[index]))
        end
    end
    if next(waitingSpells) then
        Print("  |cff999999Some spells are still loading; this page updates when they arrive.|r")
    end
    Print("|cffffd100How to read it|r")
    Print("  Amounts come from each spell's own tooltip text. Per mana: the amount divided by the mana it costs. "
        .. "Per second: the amount divided by the cast time (an instant counts the 1.5 s global cooldown); "
        .. "a heal or damage over time with nothing up front counts its whole duration.")
    Print("  |cff66ff66Most per mana|r is the rank that stretches your mana furthest. A gray rank is worse on "
        .. "both counts than a higher one you know: it has no use left.")
    if type(cache.bonusHeal) == "number" or type(cache.bonusDamage) == "number" then
        Print(string.format("  From your gear: +%d healing, +%d spell damage (read out of combat). "
            .. "Whether the spell text already counts it is checked in game.",
            math.floor(cache.bonusHeal or 0), math.floor(cache.bonusDamage or 0)))
    end
    if InCombat() then
        Print("  |cff999999In combat: these are the numbers from before the fight.|r")
    end
    Print(DB().tooltip and "  Spell tooltips show a Spell math line. Type: tooltip off"
        or "  The Spell math line on spell tooltips is off. Type: tooltip on")
end

local function HandleSlash(message)
    message = type(message) == "string" and message:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""
    if message == "" then
        ShowPage()
    elseif message == "tooltip off" or message == "tooltip on" then
        DB().tooltip = message == "tooltip on"
        Print(DB().tooltip and "Spell tooltips show the Spell math line again." or "Spell tooltips no longer show the Spell math line.")
    else
        Print("Type: tooltip off   Or: tooltip on")
    end
end

------------------------------------------------------------------------------------------------ tooltip

-- Only the cache: nothing is asked of the game here, so it's the same in combat.
local function TooltipText(id)
    local entry = cache.byID[id]
    if not entry then
        return nil
    end
    local word = entry.kind == "heal" and "heal" or "damage"
    local text
    if entry.perCost then
        text = string.format("Spell math: %s %s per %s, %s per second", Round(entry.perCost), word, entry.power, Round(entry.perSecond))
    else
        text = string.format("Spell math: %s %s per second", Round(entry.perSecond), word)
    end
    if entry.beatenBy then
        return text .. " (" .. RankLabel(entry.beatenBy) .. " is better on both)", 0.6, 0.6, 0.6
    elseif entry.bestPerCost then
        return text .. " (most per " .. entry.power .. ")", 0.4, 1, 0.4
    end
    return text, 0.6, 0.8, 1
end

local function OnSpellTooltip(tooltip, data)
    if IsOff() or not DB().tooltip then
        return
    end
    pcall(function()
        data = Safe(data)
        local id = type(data) == "table" and Safe(data.id)
        if type(id) ~= "number" then
            return
        end
        local text, r, g, b = TooltipText(id)
        if text then
            tooltip:AddLine(text, r, g, b)
        end
    end)
end

if type(TooltipDataProcessor) == "table" and type(TooltipDataProcessor.AddTooltipPostCall) == "function"
    and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Spell ~= nil then
    pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Spell, OnSpellTooltip)
end

------------------------------------------------------------------------------------------------ events

local events = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE",
    "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED", "SPELL_TEXT_UPDATE", "SPELL_DATA_LOAD_RESULT",
}) do
    -- An event this client lacks mustn't stop loading.
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, arg)
    if event == "PLAYER_LOGIN" then
        DB()
        Schedule(3)
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        if dirty then
            Schedule(1)
        end
    elseif event == "SPELL_DATA_LOAD_RESULT" or event == "SPELL_TEXT_UPDATE" then
        -- Only spells this helper asked for.
        local id = Safe(arg)
        if id and waitingSpells[id] then
            waitingSpells[id] = nil
            -- Counted with the retries (not reset): a spell whose text stays empty while this event keeps
            -- coming back would otherwise be re-read every few seconds for good.
            if loadRetries < LOAD_RETRY_LIMIT then
                loadRetries = loadRetries + 1
                Schedule(1)
            end
        end
    elseif InCombat() then
        dirty = true
    else
        loadRetries = 0 -- something really changed (new spell, level, gear): loading may be retried again
        Schedule(2)
    end
end)

SLASH_SPELLMATH1 = "/spellmath"
SlashCmdList.SPELLMATH = function(message)
    HandleSlash(message)
end

-- Switched On again on the hub's Manage page: read fresh. Off: the page and tooltip line go quiet.
ForeverHubOnSwitch = ForeverHubOnSwitch or {}
ForeverHubOnSwitch.SpellMath = function(off)
    if not off then
        Schedule(0)
    end
end
