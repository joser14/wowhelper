-- Round 6 #10 (built with SpellMath): ReadyCheck (SpellReady) checks the group's buffs, not just yours.
-- Who lacks your Fortitude, and a druid's or mage's buff when one is in the group; mana-only buffs skip
-- rage and energy users; you aren't asked twice about your own self-buff; offline members are left out;
-- a member whose auras are hidden is counted as unreadable, never as missing; nothing is read in combat
-- or while switched Off; raids; the side panel row; GROUP_ROSTER_UPDATE; nothing cast and nothing in chat.
-- Run from the tests folder:  node run.js "<repo root>" test_r6_spellmath_readycheck.lua
local base = ADDON_PATH
local realPrint = print
local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end

local SECRET = {}
issecretvalue = function(v) return v == SECRET end
local out, chat, frames, forbidden = {}, {}, {}, {}
print = function(...) chat[#chat + 1] = table.concat({ ... }, " ") end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1, FutureSpell = 2 } }
for _, name in ipairs({ "CastSpellByName", "CastSpellByID", "TargetUnit", "AssistUnit", "SpellTargetUnit", "UseAction", "PlaceAction" }) do
    _G[name] = function() forbidden[#forbidden + 1] = name end
end

local now = 1000
GetTime = function() return now end
local combat = false
InCombatLockdown = function() return combat end
IsResting = function() return false end

-- The group: unit -> { name, surname, class, power type, auras = { name = true }, online }.
local P = function(...) return ... end
local group
local function Reset()
    group = {
        player = { "Elune", "Starfall", "PRIEST", 0, { ["Power Word: Fortitude"] = true, ["Inner Fire"] = true } },
        party1 = { "Tank", nil, "WARRIOR", 1, { ["Power Word: Fortitude"] = true } },
        party2 = { "Rogue", nil, "ROGUE", 3, { ["Mark of the Wild"] = true } },
        party3 = { "Mage", nil, "MAGE", 0, { ["Prayer of Fortitude"] = true } },
        party4 = { "Leaf", "Oakhart", "DRUID", 0, { ["Gift of the Wild"] = true, ["Arcane Brilliance"] = true } },
    }
end
Reset()
local members, raid = 5, false
local offline, dead, secretUnit = {}, {}, nil
local reads = {}
GetNumGroupMembers = function() return members end
IsInRaid = function() return raid end
local function Unit(unit)
    if raid then
        local map = { raid1 = "player", raid2 = "party2", raid3 = "party4" }
        unit = map[unit] or unit
    end
    return group[unit], unit
end
UnitExists = function(unit) return Unit(unit) ~= nil end
UnitIsUnit = function(a, b) local _, ua = Unit(a); local _, ub = Unit(b); return ua == ub end
UnitIsConnected = function(unit) local _, u = Unit(unit); return not offline[u] end
UnitIsDeadOrGhost = function(unit) local _, u = Unit(unit); return dead[u] == true end
UnitName = function(unit) local g = Unit(unit); if g then return g[1], g[2] end end
UnitClass = function(unit) local g = Unit(unit); if g then return g[3], g[3] end end
UnitPowerType = function(unit) local g = Unit(unit); if g then return g[4] end end
C_UnitAuras = {
    GetAuraDataByIndex = function(unit, index)
        local g, u = Unit(unit)
        reads[u] = (reads[u] or 0) + 1
        if not g then return nil end
        local names = {}
        for name in pairs(g[5]) do names[#names + 1] = name end
        table.sort(names)
        if not names[index] then return nil end
        if secretUnit == u then return { name = SECRET, expirationTime = SECRET } end
        return { name = names[index], expirationTime = 0 }
    end,
}

local SPELLS = { [1243] = { "Power Word: Fortitude", "Rank 1" }, [588] = { "Inner Fire", "Rank 1" } }
local book = { 1243, 588 }
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { name = "Discipline", itemIndexOffset = 0, numSpellBookItems = #book } end,
    GetSpellBookItemInfo = function(slot)
        local id = book[slot]
        return id and { itemType = 1, spellID = id, actionID = id, name = SPELLS[id][1], subName = SPELLS[id][2], isOffSpec = false }
    end,
}
C_Spell = {
    GetSpellName = function(id) return SPELLS[id] and SPELLS[id][1] end,
    GetSpellSubtext = function(id) return SPELLS[id] and SPELLS[id][2] end,
}
GetActionInfo = function() return nil end
C_Item = { GetItemCount = function() return 10 end, GetItemInfoInstant = function() return nil end }
C_Container = { GetContainerNumSlots = function() return 16 end }
GetInventoryItemLink = function() return nil end

local timers, tickers = {}, {}
C_Timer = {
    After = function(_, fn) timers[#timers + 1] = fn end,
    NewTicker = function(_, fn) tickers[#tickers + 1] = fn end,
}
local function flush()
    local guard = 0
    while #timers > 0 and guard < 1000 do
        guard = guard + 1
        table.remove(timers, 1)()
    end
end

assert(loadfile(base .. "/ReadyCheck/ReadyCheck.lua"))("ForeverCharacter", {})
check(#frames == 1, "still one event frame")
local f = frames[1]
local function fire(event, ...) f.fn(f, event, ...) end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function dump() return "\n  page was:\n  " .. table.concat(out, "\n  ") end
local function need(text, why) check(has(text), why .. ": wanted '" .. text .. "'" .. dump()) end
local function page()
    out = {}
    local ok, err = pcall(SlashCmdList.SPELLREADY, "")
    if not ok then out[#out + 1] = "<<ERROR: " .. tostring(err) .. ">>" end
    check(ok, "page runs: " .. tostring(err))
end
local function statusText()
    local texts = {}
    for _, row in ipairs(ForeverHubStatus.SpellReady() or {}) do texts[#texts + 1] = row.text end
    return table.concat(texts, " | ")
end

check(f.registered.GROUP_ROSTER_UPDATE, "GROUP_ROSTER_UPDATE registered")
for event in pairs(f.registered) do
    check(not event:find("COMBAT_LOG", 1, true), "no combat log event: " .. event)
end

------------------------------------------------------------------------------------------------ a party
fire("PLAYER_LOGIN")
flush()
page()
need("Group buffs", "group section shown in a party")
need("Missing Fortitude: Rogue, Leaf.", "who lacks your Fortitude (a Prayer counts; you're covered by your own check)")
need("Missing Mark of the Wild (a druid's buff): you, Tank, Mage.", "a druid's buff, Gift counts")
need("Missing Arcane Intellect (a mage's buff): you, Mage.", "a mage's buff only for mana users")
check(not has("Divine Spirit") and not has("Shadow Protection"), "buffs you haven't learned aren't asked about")
check(not has("Oakhart"), "Forever's surname left off")
need("nothing is cast for you", "says nothing is cast")
check(not has("Everything looks ready"), "not 'ready' while someone lacks a buff")
local text = statusText()
check(text:find("|cff88bbeeGroup|r Missing Fortitude: Rogue, Leaf (+2)", 1, true), "side panel row: " .. text)

-- Everyone buffed.
group.party2[5]["Power Word: Fortitude"] = true
group.party4[5]["Power Word: Fortitude"] = true
group.player[5]["Mark of the Wild"] = true; group.party1[5]["Mark of the Wild"] = true; group.party3[5]["Mark of the Wild"] = true
group.player[5]["Arcane Intellect"] = true; group.party3[5]["Arcane Intellect"] = true
page()
need("Everyone has the group's buffs.", "all buffed")
check(not statusText():find("Group|r", 1, true), "no side panel row when all are buffed")
Reset()

------------------------------------------------------------------------------------------------ offline, dead, hidden
offline.party2 = true
dead.party4 = true
page()
need("Missing Mark of the Wild (a druid's buff): you, Tank, Mage.", "the others still checked")
check(not has("Missing Fortitude") and not has("Rogue") and not has("Leaf"), "offline and dead members aren't listed" .. dump())
offline, dead = {}, {}
secretUnit = "party2"
page()
check(not has("Rogue"), "hidden auras: never claimed missing")
need("isn't showing the buffs of 1 member(s)", "says one member can't be read")
need("Missing Fortitude: Leaf.", "the others are still checked")
secretUnit = nil

------------------------------------------------------------------------------------------------ combat
combat = true
fire("PLAYER_REGEN_DISABLED")
reads = {}
for _, tick in ipairs(tickers) do tick() end
fire("GROUP_ROSTER_UPDATE")
flush()
page()
check(not reads.party1 and not reads.party2 and not reads.party4, "no party aura read in combat")
need("Group buffs", "section still there")
need("Checked again when combat ends.", "says it waits for combat to end")
check(not statusText():find("Group|r", 1, true), "no group row in combat")
combat = false
fire("PLAYER_REGEN_ENABLED")
flush()
check(reads.party1 and reads.party1 > 0, "read again after combat")
check(statusText():find("Group|r Missing Fortitude", 1, true), "row back after combat")

------------------------------------------------------------------------------------------------ roster change, raid, solo
reads = {}
fire("GROUP_ROSTER_UPDATE")
flush()
check(reads.party2 and reads.party2 > 0, "GROUP_ROSTER_UPDATE checks the group again")

raid, members = true, 3
page()
need("Missing Fortitude: Rogue, Leaf.", "raid units read, you skipped as raid1")
check(not has("Tank"), "only the raid's members")
raid, members = false, 5

members = 1
page()
check(not has("Group buffs"), "solo: no group section")
check(not has("<<ERROR"), "no errors")
members = 5

------------------------------------------------------------------------------------------------ switched off
ForeverHub_IsOff = function(name) return name == "SpellReady" end
reads = {}
for _, tick in ipairs(tickers) do tick() end
fire("GROUP_ROSTER_UPDATE")
now = now + 30
flush()
check(not reads.party1 and not reads.party2, "switched Off: no group aura reads")
ForeverHub_IsOff = nil

check(#forbidden == 0, "nothing cast or targeted: " .. table.concat(forbidden, ", "))
check(#chat == 0, "nothing in chat: " .. tostring(chat[1]))

if #failures > 0 then
    realPrint("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do realPrint(" - " .. why) end
    os.exit(1)
end
realPrint("test_r6_spellmath_readycheck: all checks passed")
