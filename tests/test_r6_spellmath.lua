-- Round 6 #5: SpellMath. Each known rank's amount, mana and cast time from the spell's own text and C_Spell,
-- heal or damage per mana and per second, the rank with the most per mana, ranks worse on both counts,
-- lower ranks the spellbook doesn't list (from TrainerNotes' spell list), the tooltip line from the cache
-- (also in combat), nothing read in combat, secret values skipped, spell data loading, the hub switch,
-- the tooltip setting, bounded saved variables, its own globals only, and nothing cast or touched.
-- Run from the tests folder:  node run.js "<repo root>" test_r6_spellmath.lua
local base = ADDON_PATH
local realPrint = print
local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end

local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
issecretvalue = function(v) return v == SECRET end

local out, chat, frames, timers, postCalls = {}, {}, {}, {}, {}
local forbidden = {}
print = function(...) chat[#chat + 1] = table.concat({ ... }, " ") end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
CreateFrame = function()
    local f = { events = {} }
    f.RegisterEvent = function(self, e) self.events[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1, FutureSpell = 2 }, TooltipDataType = { Item = 0, Spell = 1, Unit = 2 } }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) postCalls[#postCalls + 1] = { kind = kind, fn = fn } end }
local now = 1000
GetTime = function() return now end
local combat = false
InCombatLockdown = function() return combat end
UnitClass = function() return "Priest", "PRIEST", 5 end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function flush()
    local guard = 0
    while #timers > 0 and guard < 1000 do
        guard = guard + 1
        table.remove(timers, 1)()
    end
end
-- Anything that would play for you, or touch bars or targets.
for _, name in ipairs({ "CastSpellByName", "CastSpellByID", "CastSpell", "TargetUnit", "AssistUnit", "PickupSpell",
    "PickupAction", "PlaceAction", "ClearCursor", "SetBinding", "SpellTargetUnit", "UseAction", "hooksecurefunc" }) do
    _G[name] = function() forbidden[#forbidden + 1] = name end
end
GetSpellBonusHealing = function() return 12 end
GetSpellBonusDamage = function(school) return school == 2 and 5 or 0 end

-- The spells: id -> { name, subtext, description, cost, cast ms }.
local SPELLS = {
    [2050] = { "Lesser Heal", "Rank 1", "Heal your target for 47 to 58.", 35, 1500 },
    [2052] = { "Lesser Heal", "Rank 2", "Heal your target for 71 to 85.", 45, 2000 },
    [2053] = { "Lesser Heal", "Rank 3", "Heal your target for 135 to 157.", 75, 2500 },
    [2054] = { "Heal", "Rank 1", "Heal your target for 295 to 341.", 155, 3000 },
    [2055] = { "Heal", "Rank 2", "Heal your target for 429 to 491.", 205, 3000 },   -- not learned
    [139] = { "Renew", "Rank 1", "Heals the target of 45 damage over 15 sec.", 30, 0 },
    [6074] = { "Renew", "Rank 2", "Heals the target of 100 damage over 15 sec.", 65, 0 },
    [585] = { "Smite", "Rank 1", "Smite an enemy for 13 to 17 Holy damage.", 20, 1500 },
    [591] = { "Smite", "Rank 2", "", 30, 2000 },   -- text not loaded yet
    [17] = { "Power Word: Shield", "Rank 1", "Draws on the soul of the party member to shield them, absorbing 44 damage. Lasts 30 sec. Once shielded, the target cannot be shielded again for 15 sec.", 45, 0 },
    [589] = { "Shadow Word: Pain", "Rank 1", "A word of darkness that causes 30 Shadow damage over 18 sec.", 25, 0 },
    [14914] = { "Holy Fire", "Rank 1", "Consumes the enemy in Holy flame that causes 84 to 104 Fire damage and an additional 30 Fire damage over 10 sec.", 85, 3500 },
    [1243] = { "Power Word: Fortitude", "Rank 1", "Power infuses the target increasing their Stamina by 3 for 30 min.", 60, 0 },
    [8092] = { "Mind Blast", "Rank 1", "Blasts the target for 42 to 46 Shadow damage, but causes a high amount of threat.", 50, 1500 },
    -- Not priest text, read the same way (any class): a heal over time with "for", a slow with a percentage,
    -- a thousands separator, and a strike that adds to the weapon.
    [99001] = { "Rejuvenation", "Rank 1", "Heals the target for 32 over 12 sec.", 25, 0 },
    [99002] = { "Frostbolt", "Rank 1", "Launches a bolt of frost at the enemy, causing 18 to 20 Frost damage and slowing movement speed by 40% for 5 sec.", 25, 1500 },
    [99003] = { "Greater Heal", "Rank 4", "A slow casting spell that heals a single target for 1,966 to 2,194.", 710, 3000 },
    [99004] = { "Sinister Strike", "Rank 1", "An instant strike that causes 3 damage in addition to your normal weapon damage.", 45, 0 },
    -- Text that is hidden: skipped, never an error.
    [99005] = { "Mind Flay", "Rank 1", SECRET, 45, 0 },
}
local book = { 2053, 2054, 6074, 591, 17, 589, 14914, 1243, 8092, 99001, 99002, 99003, 99004, 99005 }
local known = { [2050] = true, [2052] = true, [139] = true, [585] = true }
for _, id in ipairs(book) do known[id] = true end
local reads, loadsAsked = 0, {}
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { name = "Holy", itemIndexOffset = 0, numSpellBookItems = #book } end,
    GetSpellBookItemInfo = function(slot)
        local id = book[slot]
        return id and { itemType = 1, spellID = id, actionID = id, name = SPELLS[id][1], subName = SPELLS[id][2], isOffSpec = false }
    end,
    IsSpellKnown = function(id) return known[id] == true end,
}
C_Spell = {
    GetSpellName = function(id) return SPELLS[id] and SPELLS[id][1] end,
    GetSpellSubtext = function(id) return SPELLS[id] and SPELLS[id][2] end,
    GetSpellDescription = function(id) reads = reads + 1; return SPELLS[id] and SPELLS[id][3] end,
    GetSpellInfo = function(id) return SPELLS[id] and { name = SPELLS[id][1], castTime = SPELLS[id][5], spellID = id } end,
    GetSpellPowerCost = function(id) return SPELLS[id] and { { type = 0, name = "MANA", cost = SPELLS[id][4] } } end,
    RequestLoadSpellData = function(id) loadsAsked[id] = true end,
}

-- TrainerNotes' Forever spell list: the lower ranks (Lesser Heal 2050 and Smite 585 are only named as
-- what the next rank needs).
assert(loadfile(base .. "/TrainerNotes/Data.lua"))("ForeverCharacter", {})
check(type(TrainerNotesData) == "table", "TrainerNotes data loaded")

-- Saved settings with junk from somewhere: only the tooltip setting stays.
SpellMathDB = { tooltip = true, junk = { 1, 2, 3 }, families = {} }

local before = {}
for k in pairs(_G) do before[k] = true end
assert(loadfile(base .. "/SpellMath/SpellMath.lua"))("ForeverCharacter", {})
local f = frames[1]
local function fire(event, ...) f.fn(f, event, ...) end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function dump() return "\n  page was:\n  " .. table.concat(out, "\n  ") end
local function need(text, why) check(has(text), why .. ": wanted '" .. text .. "'" .. dump()) end
local function page(arg)
    out = {}
    local ok, err = pcall(SlashCmdList.SPELLMATH, arg or "")
    check(ok, "page runs: " .. tostring(err))
    flush()
    out = {}
    ok, err = pcall(SlashCmdList.SPELLMATH, arg or "")
    check(ok, "page runs: " .. tostring(err))
end
local tooltipFn
for _, call in ipairs(postCalls) do
    if call.kind == Enum.TooltipDataType.Spell then tooltipFn = call.fn end
end
local function tip(data)
    local lines = {}
    local tooltip = { AddLine = function(_, text, r, g, b) lines[#lines + 1] = { text = text, r = r, g = g, b = b } end }
    local ok, err = pcall(tooltipFn, tooltip, data)
    check(ok, "tooltip post call never errors: " .. tostring(err))
    return lines
end

------------------------------------------------------------------------------------------------ load
check(SLASH_SPELLMATH1 == "/spellmath" and type(SlashCmdList.SPELLMATH) == "function", "its own page command")
check(tooltipFn ~= nil, "a spell tooltip post call is registered")
check(#frames == 1, "one event frame, nothing on screen: " .. #frames)
for event in pairs(f.events) do
    check(not event:find("COMBAT_LOG", 1, true), "no combat log event: " .. event)
end
check(f.events.SPELLS_CHANGED and f.events.PLAYER_REGEN_ENABLED and f.events.SPELL_DATA_LOAD_RESULT, "events registered")
check(#tip({ id = 2053 }) == 0, "no tooltip line before anything is read")

------------------------------------------------------------------------------------------------ login read
fire("PLAYER_LOGIN")
flush()
check(SpellMathDB.tooltip == true and SpellMathDB.junk == nil and SpellMathDB.families == nil, "saved variables hold only the tooltip setting")
page()
need("Your spells, rank by rank", "page title")
need("Lesser Heal|r (heals)", "Lesser Heal listed")
need("Rank 3: 146 heal, 75 mana, 2.50 s cast. 1.95 heal per mana, 58.4 per second. |cff66ff66Most per mana.|r", "best rank by mana, with amount, cost, cast")
need("Rank 1: 52.5 heal, 35 mana, 1.50 s cast. 1.50 heal per mana, 35.0 per second. Worse on both than Rank 3.", "an outclassed rank found by its ID only (not in the spellbook)")
need("|cff999999  Rank 2: 78.0 heal", "rank 2 is gray too")
need("Heal|r (heals)", "Heal listed")
check(not has("429"), "a rank you haven't learned isn't listed")
need("Rank 1: 318 heal, 155 mana, 3.00 s cast. 2.05 heal per mana, 106 per second.", "Heal rank 1")
check(not has("Rank 1: 318 heal, 155 mana, 3.00 s cast. 2.05 heal per mana, 106 per second. |cff66ff66"), "a single rank isn't called the best")
need("Rank 2: 100 over 15 s heal, 65 mana, instant. 1.54 heal per mana, 6.67 per second. |cff66ff66Most per mana.|r", "a heal over time: per second over its duration")
need("Rank 1: 45.0 over 15 s heal, 30 mana, instant. 1.50 heal per mana, 3.00 per second. Worse on both than Rank 2.", "Renew rank 1 outclassed")
need("Rank 1: 44.0 heal, 45 mana, instant. 0.98 heal per mana, 29.3 per second.", "a shield's absorb, instant: the global cooldown")
need("Rank 1: 30.0 over 18 s damage, 25 mana, instant. 1.20 damage per mana, 1.67 per second.", "a damage over time")
need("Rank 1: 94.0 + 30.0 over 10 s damage, 85 mana, 3.50 s cast. 1.46 damage per mana, 35.4 per second.", "direct and over time together")
need("Rank 1: 44.0 damage, 50 mana, 1.50 s cast.", "Mind Blast")
need("Rank 1: 32.0 over 12 s heal, 25 mana, instant.", "'for N over M sec' is a heal over time, not a direct heal")
need("Rank 1: 19.0 damage, 25 mana, 1.50 s cast.", "a slow's percentage isn't an amount")
need("Rank 4: 2080 heal, 710 mana, 3.00 s cast.", "thousands separators")
check(not has("Sinister Strike"), "a strike that adds to the weapon isn't counted")
check(not has("Power Word: Fortitude"), "a buff with no heal or damage isn't listed")
check(not has("Mind Flay"), "a hidden description is skipped")
need("+12 healing, +5 spell damage", "gear bonuses shown")
need("Spell tooltips show a Spell math line", "tooltip setting shown")
-- Heals before damage on the page.
local healAt, damageAt
for i, t in ipairs(out) do
    if t:find("(heals)", 1, true) and not healAt then healAt = i end
    if t:find("(damage)", 1, true) and not damageAt then damageAt = i end
end
check(healAt and damageAt and healAt < damageAt, "heals first")

------------------------------------------------------------------------------------------------ spell data loading
check(loadsAsked[591], "Smite rank 2's text was asked for")
need("Rank 1: 15.0 damage, 20 mana, 1.50 s cast.", "Smite rank 1 (known by ID only)")
check(not has("28.0 damage"), "Smite rank 2 not shown before its text arrives")
need("Some spells are still loading", "the page says some spells are still loading")
SPELLS[591][3] = "Smite an enemy for 25 to 31 Holy damage."
fire("SPELL_DATA_LOAD_RESULT", 591, true)
now = now + 10
flush()
page()
need("Rank 2: 28.0 damage, 30 mana, 2.00 s cast.", "Smite rank 2 once its text arrives")
need("Smite|r (damage)", "Smite listed")

------------------------------------------------------------------------------------------------ tooltip
local lines = tip({ id = 2050 })
check(#lines == 1 and lines[1].text == "Spell math: 1.50 heal per mana, 35.0 per second (Rank 3 is better on both)",
    "tooltip line for an outclassed rank: " .. tostring(lines[1] and lines[1].text))
lines = tip({ id = 2053 })
check(#lines == 1 and lines[1].text == "Spell math: 1.95 heal per mana, 58.4 per second (most per mana)", "tooltip line for the best rank")
check(#tip({ id = 1243 }) == 0, "no line on a buff")
check(#tip({ id = SECRET }) == 0 and #tip(SECRET) == 0 and #tip(nil) == 0, "secret or missing tooltip data: no line, no error")

------------------------------------------------------------------------------------------------ combat
combat = true
fire("PLAYER_REGEN_DISABLED")
local readsBefore = reads
SPELLS[2053][3] = "Heal your target for 155 to 177."   -- new gear mid-fight
fire("SPELLS_CHANGED"); fire("PLAYER_EQUIPMENT_CHANGED", 5)
now = now + 10
flush()
page()
check(reads == readsBefore, "nothing read in combat (" .. (reads - readsBefore) .. " reads)")
need("Rank 3: 146 heal", "in combat the page shows the numbers from before the fight")
need("In combat: these are the numbers from before the fight", "and says so")
check(#tip({ id = 2053 }) == 1, "the tooltip line still works in combat, from the cache")
combat = false
fire("PLAYER_REGEN_ENABLED")
now = now + 10
flush()
check(reads > readsBefore, "read again after combat")
page()
need("Rank 3: 166 heal", "fresh numbers after combat")

-- Combat starting part-way through a read drops it; it runs again afterwards.
do
    local steps = {}
    C_Timer.After = function(_, fn) steps[#steps + 1] = fn end
    now = now + 10
    fire("SPELLS_CHANGED")
    if steps[1] then table.remove(steps, 1)() end    -- the read starts: first chunk
    combat = true
    local guard = 0
    while #steps > 0 and guard < 100 do guard = guard + 1; table.remove(steps, 1)() end
    C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
    readsBefore = reads
    combat = false
    fire("PLAYER_REGEN_ENABLED")
    now = now + 10
    flush()
    check(reads > readsBefore, "an interrupted read runs again after combat")
    page()
    need("Lesser Heal|r (heals)", "page complete after an interrupted read")
end

------------------------------------------------------------------------------------------------ tooltip setting
page("tooltip off")
check(SpellMathDB.tooltip == false, "tooltip off is saved")
check(#tip({ id = 2053 }) == 0, "tooltip off: no line")
page("")
need("Type: tooltip on", "the page says how to switch it back")
page("tooltip on")
check(#tip({ id = 2053 }) == 1, "tooltip on: line back")
page("nonsense")
need("Type: tooltip off", "help for unknown words")

------------------------------------------------------------------------------------------------ hub switch
do
    local off = true
    ForeverHub_IsOff = function(name) return name == "SpellMath" and off end
    check(#tip({ id = 2053 }) == 0, "switched Off: no tooltip line")
    readsBefore = reads
    now = now + 10
    fire("SPELLS_CHANGED"); flush()
    check(reads == readsBefore, "switched Off: nothing read")
    off = false
    check(type(ForeverHubOnSwitch) == "table" and type(ForeverHubOnSwitch.SpellMath) == "function", "registers its switch callback")
    now = now + 10
    ForeverHubOnSwitch.SpellMath(false); flush()
    check(reads > readsBefore, "switched On: read fresh")
    check(#tip({ id = 2053 }) == 1, "switched On: tooltip line back")
    ForeverHub_IsOff = nil
end

------------------------------------------------------------------------------------------------ no hub
do
    local receive = ForeverHub_Receive
    ForeverHub_Receive = nil
    SlashCmdList.SPELLMATH("")
    check(#chat == 0, "without the hub nothing goes to chat")
    ForeverHub_Receive = receive
end

------------------------------------------------------------------------------------------------ globals and source
do
    local allowed = { SpellMathDB = true, SLASH_SPELLMATH1 = true, ForeverHubOnSwitch = true }
    for k in pairs(_G) do
        if not before[k] and not allowed[k] and k ~= "ForeverHub_IsOff" then
            check(false, "new global outside SpellMath's names: " .. tostring(k))
        end
    end
    -- The compiled chunk's constants hold every global name and string it uses (comments aren't in it).
    local code = string.dump(assert(loadfile(base .. "/SpellMath/SpellMath.lua")))
    for _, word in ipairs({ "CastSpell", "TargetUnit", "PickupSpell", "PlaceAction", "UseAction", "hooksecurefunc",
        "COMBAT_LOG", "AddDataProvider", "AcquirePin", "AddMessage", "RegisterCallback", "DEFAULT_CHAT_FRAME" }) do
        check(not code:find(word, 1, true), "SpellMath.lua never uses " .. word)
    end
    -- A string constant is stored as its length + 1, then the bytes ("print": 6).
    check(code:find("\6Print", 1, true) and not code:find("\6print", 1, true), "SpellMath.lua never calls print")
end
check(#forbidden == 0, "nothing cast, targeted or put on a bar: " .. table.concat(forbidden, ", "))
check(#chat == 0, "nothing in chat: " .. tostring(chat[1]))

if #failures > 0 then
    realPrint("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do realPrint(" - " .. why) end
    os.exit(1)
end
realPrint("test_r6_spellmath: all checks passed")
