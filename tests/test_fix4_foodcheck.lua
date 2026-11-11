-- Perf audit 10 (FoodCheck): your own UNIT_AURA events are coalesced; a burst checks the reminders once,
-- half a second later, and a buff that runs out is still reported.
local base = ADDON_PATH
local out, frames, handled = {}, {}, {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
issecretvalue = function() return false end
CreateFrame = function()
    local f = {}
    f.RegisterEvent = function() end
    f.RegisterUnitEvent = function() end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
UnitName = function() return "Me" end
GetRealmName = function() return "R" end
UnitLevel = function() return 20 end
local now = 1000
GetTime = function() return now end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function() end }
local function flush() local n = 0 while #timers > 0 and n < 100 do n = n + 1; table.remove(timers, 1)() end end
InCombatLockdown = function() return false end
C_Secrets = { ShouldAurasBeSecret = function() return false end }
local reads, buff = 0, { name = "Arcane Intellect", expirationTime = 0 }
C_UnitAuras = {
    GetPlayerAuraBySpellID = function() return nil end,
    GetAuraDataBySpellName = function(_, name) reads = reads + 1; return buff and name == buff.name and buff or nil end,
    GetBuffDataByIndex = function() return nil end,
}
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = function() end }
for _, f in ipairs({ "FoodIDs", "CampObjects", "FoodCheck" }) do
    assert(loadfile(base .. "/FoodCheck/" .. f .. ".lua"))("FoodCheck", {})
end
local events = frames[#frames]
local function fire(...) events.fn(events, ...) end
fire("PLAYER_LOGIN")
flush()   -- the 5 s settle after login
SlashCmdList.FOODCHECK("remind Arcane Intellect")
flush()

-- A burst of 30 aura changes: one reminder check, after it.
reads = 0
for _ = 1, 30 do fire("UNIT_AURA", "player") end
assert(reads == 0, "no check per event: " .. reads)
flush()
assert(reads == 1, "one check for the burst: " .. reads)
-- The buff runs out: reported after the coalesced check.
out = {}
buff = nil
fire("UNIT_AURA", "player")
flush()
local said = table.concat(out, "\n")
assert(said:find("Arcane Intellect is gone", 1, true), "reported: " .. said)
-- Another unit's auras: ignored.
reads = 0
fire("UNIT_AURA", "target")
flush()
assert(reads == 0, "other units ignored")
assert(#handled == 0, "no errors: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
