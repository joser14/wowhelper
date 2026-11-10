-- Round 3 rank 4: camp and tent awareness in RestGuard (and a campfire line in FoodCheck). Auras are read by
-- spell ID only out of combat and when auras aren't secret; your own campfire placement is remembered and
-- pointed to (8 directions from your facing, within 120 yd).
local base = ADDON_PATH
local out, frames, handled = {}, {}, {}
local SECRET = {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function(v) return v == SECRET end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
CreateFrame = function()
    local f = {}
    f.RegisterEvent = function() end
    f.RegisterUnitEvent = function(self, e, u) self.unitEvent = { e, u } end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
local now = 1000
GetTime = function() return now end
UnitLevel = function() return 20 end
UnitXPMax = function() return 1000 end
GetXPExhaustion = function() return 0 end
GetBindLocation = function() return "Goldshire" end
IsResting = function() return false end
C_Item = { GetItemCount = function() return 1 end }
C_Container = {}
local combat, secret = false, false
InCombatLockdown = function() return combat end
C_Secrets = { ShouldAurasBeSecret = function() return secret end }
local auras, asked = {}, {}
C_UnitAuras = { GetPlayerAuraBySpellID = function(id) asked[#asked + 1] = id; return auras[id] end }
local px, py, facing = 100, 200, 0
UnitPosition = function() return px, py, 0, 0 end
GetPlayerFacing = function() return facing end
GetRestState = function() return 1, "Rested", 2 end

assert(loadfile(base .. "/RestGuard/RestGuard.lua"))("RestGuard", {})
local f = frames[1]
assert(f.unitEvent and f.unitEvent[1] == "UNIT_SPELLCAST_SUCCEEDED" and f.unitEvent[2] == "player", "own casts only")
local function page()
    out = {}
    SlashCmdList.RESTGUARD()
    return table.concat(out, "\n")
end

-- 1. No camp: no camp lines, no side-panel row; the rest state is named.
local p = page()
assert(p:find("Rest state: Rested (200% XP from kills)", 1, true), "rest state:\n" .. p)
assert(not p:find("Camp", 1, true) and not p:find("Tent", 1, true), "no camp lines away from camps:\n" .. p)
assert(ForeverHubStatus.RestGuard() == nil, "no row away from camps")
print("1 ok")

-- 2. In camp: benefits with time left, campfire nearby, tent boost ready.
auras[1229741] = { expirationTime = now + 42 * 60 }
auras[1283391] = { expirationTime = 0 }
p = page()
assert(p:find("Camp benefits: 42 min left", 1, true), "benefits:\n" .. p)
assert(p:find("campfire is nearby", 1, true), "campfire:\n" .. p)
assert(p:find("Tent rest boost ready", 1, true), "tent ready:\n" .. p)
local row = ForeverHubStatus.RestGuard()
assert(row and row[1].text:find("42 min left", 1, true) and row[1].text:find("Tent rest boost ready", 1, true), "row: " .. tostring(row and row[1].text))
print("2 ok")

-- 3. Tent used: the lockout's time left.
auras[1229451] = { expirationTime = now + 37 * 60 + 5 }
p = page()
assert(p:find("Tent rest boost used; again in 38 min", 1, true), "tent lockout:\n" .. p)
print("3 ok")

-- 4. In combat or with secret auras nothing is read at all.
combat = true
asked = {}
p = page()
assert(#asked == 0, "no aura reads in combat")
assert(p:find("can't be read in combat", 1, true), "says why:\n" .. p)
combat, secret = false, true
asked = {}
page()
assert(#asked == 0, "no aura reads while auras are secret")
C_Secrets.ShouldAurasBeSecret = function() return SECRET end
page()
assert(#asked == 0, "a secret answer counts as secret")
C_Secrets.ShouldAurasBeSecret = function() return secret end
secret = false
print("4 ok")

-- 5. Your own campfire is remembered and pointed to. Facing north (0): a fire 40 yd south is behind you;
-- facing west (pi/2) a fire to the north is to your right.
auras = {}
px, py = 100, 200
f.fn(f, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 1307252)
px = 140
p = page()
assert(p:find("Your campfire: 40 yd behind you", 1, true), "behind:\n" .. p)
px = 60; facing = math.pi / 2
p = page()
assert(p:find("Your campfire: 40 yd to your right", 1, true), "right:\n" .. p)
-- Ahead-left: fire to the north-west while facing north.
px, py, facing = 70, 170, 0
p = page()
assert(p:find("ahead and to the left", 1, true), "ahead-left:\n" .. p)
-- Too far, or an hour later: forgotten.
px = 300
assert(not page():find("Your campfire", 1, true), "out of range")
px = 120; now = now + 3601
assert(not page():find("Your campfire", 1, true), "an hour later")
-- Someone else's spell (or a secret one) changes nothing.
f.fn(f, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", SECRET)
f.fn(f, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 133)
assert(not page():find("Your campfire", 1, true), "other spells ignored")
print("5 ok")

-- 6. FoodCheck says when a campfire lets you cook, under the same guards.
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
C_Container = { GetContainerNumSlots = function() return 0 end }
auras = { [1283391] = { expirationTime = 0 } }
assert(loadfile(base .. "/FoodCheck/FoodCheck.lua"))("FoodCheck", {})
out = {}
SlashCmdList.FOODCHECK()
p = table.concat(out, "\n")
assert(p:find("campfire is nearby", 1, true), "FoodCheck campfire line:\n" .. p)
combat = true; out = {}
SlashCmdList.FOODCHECK()
assert(not table.concat(out, "\n"):find("campfire", 1, true), "not in combat")
print("6 ok")

assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
