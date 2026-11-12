-- Round 5, Tooltips side: the wish-list line (Dungeons_IsWished) and #5 your own drop rates from corpses you
-- loot (LOOT_OPENED + GetLootSourceInfo, each corpse once, each item once per corpse, bounded, read only).
-- Run from the tests folder:  node run.js "<repo root>" test_r5f_tooltips.lua
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

-- 1. Wish list: nothing without Dungeons, then one line with the boss and dungeon, no duplicate on refresh.
hover(5191)
check(not has("wish list"), "no Dungeons: no line" .. show())
Dungeons_IsWished = function(item) if item == 5191 then return true, "The Deadmines", "Edwin VanCleef" end return false end
hover(5191)
check(has("On your wish list: Edwin VanCleef, The Deadmines"), "wish line" .. show())
hover(5191, true)
check(count("On your wish list") == 1, "no duplicate on refresh" .. show())
hover(2589)
check(not has("wish list"), "an item not wished" .. show())
off = true
hover(5191)
check(#tip.lines == 0, "hub Off: nothing at all" .. show())
off = false
Dungeons_IsWished = function() error("broken") end
hover(5191)
check(not has("wish list"), "a broken Dungeons answer adds nothing")
Dungeons_IsWished = nil

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
for i = 1, 9 do lootCorpse(97, i <= 3 and { 782 } or {}) end
hover(782)
check(not has("Your drops"), "9 corpses: not enough yet" .. show())
local k, n, enough = Tooltips_YourDrops(97, 782)
check(k == 3 and n == 9 and enough == false, "global read before enough: " .. tostring(k) .. "/" .. tostring(n))
local g10 = lootCorpse(97, { 782, 782 })   -- two stacks of the same item: once per corpse
hover(782)
check(has("Your drops: 40% (4/10) from Kobold Vermin"), "10 corpses: 4 of 10" .. show())
hover(782, true)
check(count("Your drops") == 1, "no duplicate on refresh" .. show())
-- The same corpse opened again (items left, or skinned later) adds nothing.
loot = { { LINK:format(782), g10, 1 }, { LINK:format(2318), g10, 1 } }
fire("LOOT_OPENED", false)
k, n = Tooltips_YourDrops(97, 782)
check(k == 4 and n == 10, "reopened corpse not counted again: " .. k .. "/" .. n)
check(Tooltips_YourDrops(97, 2318) == 0, "a second opening's item isn't added")
-- Loot right after your own cast (skinning, pick pocket, a chest) isn't a corpse's loot.
fire("UNIT_SPELLCAST_SUCCEEDED", "player")
lootCorpse(97, { 2318 })
check(Tooltips_YourDrops(97, 2318) == 0 and select(2, Tooltips_YourDrops(97, 782)) == 10, "loot after a cast skipped")
clock = clock + 5
-- Area loot: two corpses in one window, each counted.
spawn = spawn + 1
local a, b = guid(98, spawn), guid(98, spawn + 1)
spawn = spawn + 1
loot = { { LINK:format(500), a, 1, b, 1 }, { LINK:format(501), b, 1 } }
fire("LOOT_OPENED", false)
k, n = Tooltips_YourDrops(98, 500)
check(k == 2 and n == 2 and Tooltips_YourDrops(98, 501) == 1, "area loot: two corpses")
-- A secret GUID is skipped; a GameObject (chest, herb) isn't a creature.
local s = guid(99, 1)
secret[s] = true
loot = { { LINK:format(600), s, 1 }, { LINK:format(601), "GameObject-0-5000-0-111-1234-00000001", 1 } }
fire("LOOT_OPENED", false)
check(Tooltips_YourDrops(99) == nil, "secret GUID skipped")
-- A broken loot API doesn't break anything.
GetLootSourceInfo = function() error("no") end
loot = { { LINK:format(782), guid(97, 9999), 1 } }
fire("LOOT_OPENED", false)
check(select(2, Tooltips_YourDrops(97, 782)) == 10, "an erroring GetLootSourceInfo is skipped")
GetLootSourceInfo = function(slot) local s2 = loot[slot]; return table.unpack(s2, 2) end
-- The line switched off: nothing recorded and nothing shown.
TooltipsDB.yourdrops = false
lootCorpse(97, { 782 })
TooltipsDB.yourdrops = nil
check(select(2, Tooltips_YourDrops(97, 782)) == 10, "line off: not recorded")
-- Hub Off: nothing recorded.
off = true
lootCorpse(97, { 782 })
off = false
check(select(2, Tooltips_YourDrops(97, 782)) == 10, "hub Off: not recorded")
-- Item list read.
local items, total, ok10 = Tooltips_YourDrops(97)
check(type(items) == "table" and items[782] == 4 and total == 10 and ok10 == true, "item list read")

-- 3. Bounded: at most 300 creatures, 25 items per creature.
for i = 1, 30 do lootCorpse(97, { 10000 + i }) end
local store = TooltipsDB.looted
local itemCount = 0
for _ in pairs(store[97].items) do itemCount = itemCount + 1 end
check(itemCount <= 25, "items per creature bounded: " .. itemCount)
check(store[97].items[782] == 4, "the frequent quest item stays")
for npc = 2000, 2400 do lootCorpse(npc, {}) end
local creatures = 0
for _ in pairs(store) do creatures = creatures + 1 end
check(creatures <= 300, "creatures bounded: " .. creatures)
check(store[97] ~= nil, "the much-looted creature stays")
-- No chat output, nothing looted: the loot API is only read.
check(LootSlot == nil and AutoLootItem == nil, "nothing loots")

if #failures > 0 then error(table.concat(failures, "\n")) end
realPrint("test_r5f_tooltips: ok")
