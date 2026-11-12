-- Full review (ForeverCharacter): ReadyCheck's group buffs. A buff from another class is asked about only
-- when someone of that class can give it now: an offline mage can't cast Arcane Intellect, so nobody is
-- told they lack "a mage's buff". A dead druid still counts (they'll be back). Secret auras stay unreadable.
-- Run from the tests folder:  node run.js "<repo root>" test_full_char_readycheck_offline.lua
local base = ADDON_PATH
local realPrint = print
local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end

local SECRET = {}
issecretvalue = function(v) return v == SECRET end
local out, chat, frames = {}, {}, {}
print = function(...) chat[#chat + 1] = table.concat({ ... }, " ") end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
CreateFrame = function()
    local f = {}
    f.RegisterEvent = function() end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1, FutureSpell = 2 } }
GetTime = function() return 1000 end
InCombatLockdown = function() return false end
IsResting = function() return false end

-- unit -> { name, class, power type, auras }
local group = {
    player = { "Elune", "PRIEST", 0, { ["Power Word: Fortitude"] = true, ["Inner Fire"] = true } },
    party1 = { "Tank", "WARRIOR", 1, { ["Power Word: Fortitude"] = true } },
    party2 = { "Mage", "MAGE", 0, { ["Power Word: Fortitude"] = true } },
    party3 = { "Leaf", "DRUID", 0, { ["Power Word: Fortitude"] = true } },
}
local offline, dead = {}, {}
GetNumGroupMembers = function() return 4 end
IsInRaid = function() return false end
UnitExists = function(unit) return group[unit] ~= nil end
UnitIsUnit = function(a, b) return a == b end
UnitIsConnected = function(unit) return not offline[unit] end
UnitIsDeadOrGhost = function(unit) return dead[unit] == true end
UnitName = function(unit) return group[unit] and group[unit][1] end
UnitClass = function(unit) local g = group[unit]; if g then return g[2], g[2] end end
UnitPowerType = function(unit) return group[unit] and group[unit][3] end
C_UnitAuras = {
    GetAuraDataByIndex = function(unit, index)
        local g = group[unit]
        if not g then return nil end
        local names = {}
        for name in pairs(g[4]) do names[#names + 1] = name end
        table.sort(names)
        if not names[index] then return nil end
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
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function() end }
local function flush()
    local guard = 0
    while #timers > 0 and guard < 1000 do guard = guard + 1; table.remove(timers, 1)() end
end

assert(loadfile(base .. "/ReadyCheck/ReadyCheck.lua"))("ForeverCharacter", {})
local f = frames[1]
f.fn(f, "PLAYER_LOGIN")
flush()
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function dump() return "\n  page was:\n  " .. table.concat(out, "\n  ") end
local function page()
    out = {}
    local ok, err = pcall(SlashCmdList.SPELLREADY, "")
    check(ok, "page runs: " .. tostring(err))
end

-- Everyone online: the mage's and the druid's buffs are asked about.
page()
check(has("Missing Arcane Intellect (a mage's buff): you, Mage, Leaf."), "online mage: Arcane Intellect asked about" .. dump())
check(has("Missing Mark of the Wild (a druid's buff)"), "online druid: Mark of the Wild asked about" .. dump())

-- The mage goes offline: nobody in the group can give Arcane Intellect now.
offline.party2 = true
page()
check(not has("Arcane Intellect"), "an offline mage's buff isn't asked about" .. dump())
check(has("Missing Mark of the Wild (a druid's buff): you, Tank, Leaf."), "the druid's buff still is (offline mage left out)" .. dump())
offline = {}

-- A dead druid still counts: they'll be back up to buff.
dead.party3 = true
page()
check(has("Missing Mark of the Wild (a druid's buff): you, Tank, Mage."), "a dead druid's buff is still asked about" .. dump())
dead = {}

-- Every member offline but you: no other class's buffs at all.
offline.party1, offline.party2, offline.party3 = true, true, true
page()
check(not has("a mage's buff") and not has("a druid's buff"), "no other class online: none of their buffs" .. dump())
offline = {}

check(#chat == 0, "nothing in chat: " .. tostring(chat[1]))
if #failures > 0 then
    realPrint("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do realPrint(" - " .. why) end
    os.exit(1)
end
realPrint("test_full_char_readycheck_offline: all checks passed")
