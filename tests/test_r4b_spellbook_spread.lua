-- Round 4 item 13: spellbook walks after SPELLS_CHANGED storms are spread over frames (at most 2
-- skill lines per frame) and ReadyCheck rebuilds at most every 5 s; opening the page still reads at
-- once. Covers ReadyCheck (SpellReady) and TrainerNotes.
-- Run:  node run.js "<workspace root>" test_r4b_spellbook_spread.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local function check(cond, why) if not cond then failures[#failures + 1] = why .. "\n  output was:\n  " .. table.concat(out, "\n  ") end end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function() return false end
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
Enum = { TrainerType = { General = 0 }, SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 } }
local now = 100
GetTime = function() return now end
InCombatLockdown = function() return false end
IsResting = function() return true end
UnitIsDeadOrGhost = function() return false end
UnitClass = function() return "Mage", "MAGE" end
UnitName = function() return "Tester" end
GetRealmName = function() return "Realm" end
UnitLevel = function() return 20 end
C_Item = { GetItemCount = function() return 10 end }
C_Container = { GetContainerNumSlots = function() return 16 end }
C_UnitAuras = { GetAuraDataByIndex = function() return nil end }

-- 9 skill lines of 1 spell each; line 9 holds Frostbolt rank 4.
local LINES = 9
local lineCalls = 0
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return LINES end,
    GetSpellBookSkillLineInfo = function(line) lineCalls = lineCalls + 1; return { name = "Line" .. line, itemIndexOffset = line - 1, numSpellBookItems = 1 } end,
    GetSpellBookItemInfo = function(slot)
        if slot == LINES then return { itemType = 1, spellID = 7322, name = "Frostbolt", subName = "Rank 4" } end
        return { itemType = 1, spellID = 1000 + slot, name = "Spell" .. slot, subName = "" }
    end,
}
C_Spell = {
    GetSpellName = function(id) if id == 116 then return "Frostbolt" end end,
    GetSpellSubtext = function(id) if id == 116 then return "Rank 1" end end,
}
GetActionInfo = function(slot) if slot == 1 then return "spell", 116, "spell" end end

-- Timers: record the delay; each run is one "frame".
local timers = {}
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end, NewTicker = function() end }
local maxPerFrame, delays = 0, {}
local function flush()
    local n = 0
    while #timers > 0 and n < 1000 do
        n = n + 1
        local t = table.remove(timers, 1)
        delays[#delays + 1] = t.delay
        lineCalls = 0
        t.fn()
        if lineCalls > maxPerFrame then maxPerFrame = lineCalls end
    end
end

assert(loadfile(base .. "/ReadyCheck/ReadyCheck.lua"))("ReadyCheck", {})
local rc = frames[#frames]
local function fireRC(ev, ...) rc.fn(rc, ev, ...) end

-- A storm of events: one walk, spread over frames.
fireRC("PLAYER_LOGIN")
for _ = 1, 20 do fireRC("SPELLS_CHANGED") end
flush()
check(maxPerFrame <= 2, "ReadyCheck reads at most 2 skill lines per frame, read " .. maxPerFrame)
local rows = ForeverHubStatus.SpellReady() or {}
check(rows[1] and rows[1].text:find("Frostbolt", 1, true), "the spread walk still finds the old rank")

-- Another change within 5 s waits until 5 s after the last walk.
now = now + 1
delays = {}
fireRC("SPELLS_CHANGED")
flush()
local waited = false
for _, d in ipairs(delays) do if d and d >= 3.9 then waited = true end end
check(waited, "rebuild at most every 5 s (delays seen: " .. table.concat(delays, ", ") .. ")")

-- Opening the page reads at once (one walk in this call).
out = {}
lineCalls = 0
SlashCmdList.SPELLREADY("")
check(lineCalls == LINES, "page reads the whole book now, read " .. lineCalls)
check(table.concat(out, "\n"):find("Frostbolt on Action bar 1, button 1 is Rank 1; you know Rank 4.", 1, true), "page result")

-- TrainerNotes: its spellbook check after SPELLS_CHANGED is spread the same way.
TrainerNotesDB = { ["Tester-Realm"] = { services = {
    ["Frostbolt|Rank 4"] = { name = "Frostbolt", rank = "Rank 4", level = 20, cost = 100 },
} } }
assert(loadfile(base .. "/TrainerNotes/TrainerNotes.lua"))("TrainerNotes", {})
local tn = frames[#frames]
tn.fn(tn, "PLAYER_LOGIN")
maxPerFrame = 0
for _ = 1, 10 do tn.fn(tn, "SPELLS_CHANGED") end
flush()
check(maxPerFrame <= 2, "TrainerNotes reads at most 2 skill lines per frame, read " .. maxPerFrame)
check(TrainerNotesDB["Tester-Realm"].services["Frostbolt|Rank 4"] == nil, "known rank still dropped after the spread walk")

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_r4b_spellbook_spread: all checks passed")
