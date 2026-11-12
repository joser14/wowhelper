-- Review 6c: on this client UNIT_SPELLCAST_SUCCEEDED's payload can be secret ("SecretWhenUnitSpellCastRestricted"
-- in UnitDocumentation). Registered with RegisterUnitEvent for "player", every such event is the player's own cast,
-- so a secret unit token must still mark the cast; otherwise skinning or pick-pocket loot right after it is
-- counted as a corpse. Harness copied from test_r5f_tooltips.lua.
-- Run from the tests folder:  node run.js "<repo root>" test_cr6c_tooltips_secretcast.lua
local realPrint = print
local frames, failures = {}, {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
local secret = {}
issecretvalue = function(v) return secret[v] == true end
ForeverHub_Receive = function() end
local off = false
ForeverHub_IsOff = function(name) return name == "Tooltips" and off end
print = function() failures[#failures + 1] = "print called" end
hooksecurefunc = function() failures[#failures + 1] = "hooksecurefunc called" end
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.RegisterUnitEvent = function(self, e, u) self.registered[e] = u end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
UnitName = function(u) if u == "player" then return "Juan" end if u == "mouseover" then return "Kobold Vermin" end end
GetRealmName = function() return "R" end
UnitFactionGroup = function() return "Alliance" end
UnitLevel = function() return 10 end
time = function() return 1000000 end
local clock = 100
GetTime = function() return clock end
local callbacks = {}
Enum = { TooltipDataType = { Item = 0, Unit = 2 }, TooltipDataLineType = { SellPrice = 11 } }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) callbacks[kind] = fn end }
TooltipUtil = { GetDisplayedItem = function() return nil end }
local tip = { lines = {} }
GameTooltip = tip
ItemRefTooltip = { lines = {} }
function tip:AddLine(t) self.lines[#self.lines + 1] = t end
function tip:AddDoubleLine(l, r) self.lines[#self.lines + 1] = l .. " = " .. r end
function tip:GetName() return "GameTooltip" end
function tip:NumLines() return #self.lines end
-- The tooltip's own lines as the game's font strings, so the duplicate check can read them.
setmetatable(_G, { __index = function(_, key)
    local index = type(key) == "string" and tonumber(key:match("^GameTooltipTextLeft(%d+)$"))
    if index and tip.lines[index] then
        return { GetText = function() return tip.lines[index] end }
    end
end })
C_Item = { GetItemInfo = function(id) return "Item " .. id, "link", 1, 5, 1, "t", "s", 20, "", 1, 0, 7, 0, 0 end }
C_Container = { GetContainerItemInfo = function() end }

local function has(text) for _, t in ipairs(tip.lines) do if tostring(t):find(text, 1, true) then return true end end return false end
local function count(text) local c = 0 for _, t in ipairs(tip.lines) do if tostring(t):find(text, 1, true) then c = c + 1 end end return c end
local function show() return "\n  " .. table.concat(tip.lines, "\n  ") end
local function hover(id, keep)
    if not keep then tip.lines = {} end
    local ok, err = pcall(callbacks[0], tip, { id = id })
    check(ok, tostring(err))
end

assert(loadfile(ADDON_PATH .. "/Tooltips/Tooltips.lua"))("Tooltips", {})
local ev = frames[#frames]
local function fire(e, ...) ev.fn(ev, e, ...) end
fire("PLAYER_LOGIN")
check(ev.registered.LOOT_OPENED, "LOOT_OPENED registered")
check(ev.registered.UNIT_SPELLCAST_SUCCEEDED == "player", "spellcasts: the player's only")
for e in pairs(ev.registered) do check(not e:find("^COMBAT_LOG"), "no combat log event") end
-- 2. Your drops: looting corpses (Creature GUIDs from GetLootSourceInfo).
local loot = {}   -- slot -> { link, guid, qty, guid, qty, ... }
GetNumLootItems = function() return #loot end
GetLootSlotLink = function(slot) return loot[slot] and loot[slot][1] end
GetLootSourceInfo = function(slot) local s = loot[slot]; return table.unpack(s, 2) end
local LINK = "|cffffffff|Hitem:%d::::::::10:::::|h[x]|h|r"
local mouseover
UnitGUID = function(u) if u == "mouseover" then return mouseover end end
local function guid(npc, spawn) return string.format("Creature-0-5000-0-111-%d-%08X", npc, spawn) end
local spawn = 0
local function lootCorpse(npc, items, opts)
    spawn = spawn + 1
    local g = guid(npc, spawn)
    mouseover = g
    loot = {}
    loot[1] = { nil, g, 1 }   -- money
    for _, id in ipairs(items) do loot[#loot + 1] = { LINK:format(id), g, 1 } end
    fire("LOOT_OPENED", false)
    return g
end

-- A plain corpse is counted.
lootCorpse(97, { 782 })
local k, n = Tooltips_YourDrops(97, 782)
check(k == 1 and n == 1, "a corpse counted: " .. tostring(k) .. "/" .. tostring(n))
clock = clock + 5
-- Your cast with a secret unit token (restricted), then loot (pick pocket / skinning): not a corpse.
local SECRET_UNIT = setmetatable({}, { __tostring = function() return "secret" end })
secret[SECRET_UNIT] = true
fire("UNIT_SPELLCAST_SUCCEEDED", SECRET_UNIT)
lootCorpse(97, { 2318 })
k, n = Tooltips_YourDrops(97, 2318)
check(k == 0 and n == 1, "loot right after a cast with a secret unit token is skipped: " .. tostring(k) .. "/" .. tostring(n))
clock = clock + 5
lootCorpse(97, {})
k, n = Tooltips_YourDrops(97, 782)
check(n == 2, "later corpses still counted: " .. tostring(n))

if #failures > 0 then error(table.concat(failures, "\n")) end
realPrint("test_cr6c_tooltips_secretcast: ok")