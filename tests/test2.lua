local base = ADDON_PATH
local frames, chat, errors = {}, {}, {}
local SECRET = {}
local s = {
    now = 1000, dur = { [1] = { 50, 100 }, [5] = { 80, 100 } }, repair = 12345, canRepair = true,
    bags = { [0] = { free = 10, type = 0, slots = {} }, [1] = { free = 5, type = 512, slots = {} } },
    prices = { [100] = 150, [200] = 25 }, level = 5,
}

local function newFrame()
    local f = { scripts = {} }
    f.SetScript = function(self, k, fn) self.scripts[k] = fn end
    f.RegisterEvent = function() end
    frames[#frames + 1] = f
    return f
end
CreateFrame = newFrame
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
UIErrorsFrame = { AddMessage = function(_, t) errors[#errors + 1] = t end }
SlashCmdList = {}
issecretvalue = function(v) return v == SECRET end
GetTime = function() return s.now end
GetRealmName = function() return "Realm" end
UnitName = function() return "Tester" end
UnitLevel = function() return s.level end
GetInventoryItemDurability = function(slot) local d = s.dur[slot]; if d then return d[1], d[2] end end
GetRepairAllCost = function() return s.repair, true end
CanMerchantRepair = function() return s.canRepair end
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 1
C_Container = {
    GetContainerNumFreeSlots = function(b) return s.bags[b].free, s.bags[b].type end,
    GetContainerNumSlots = function(b) return math.max(#s.bags[b].slots, 1) end,
    GetContainerItemInfo = function(b, i) local v = s.bags[b].slots[i]; if v ~= false then return v end end,
}
local requested = {}
C_Item = {
    GetItemInfo = function(id) return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, s.prices[id] end,
    RequestLoadItemDataByID = function(id) requested[id] = true end,
}

local function load(name)
    local before = #frames
    assert(loadfile(base .. "/" .. name .. "/" .. name .. ".lua"))(name, {})
    return frames[before + 1]
end
local function fire(f, ev, ...) f.scripts.OnEvent(f, ev, ...) end
local function last() return chat[#chat] end
local function saw(list, text) for _, t in ipairs(list) do if t:find(text, 1, true) then return true end end return false end
local function need(list, text, why) assert(saw(list, text), why .. ": wanted '" .. text .. "' in:\n" .. table.concat(list, "\n")) end

-- DurabilityWatch
local dw = load("DurabilityWatch")
fire(dw, "PLAYER_ENTERING_WORLD")
assert(#errors == 0, "no warning when healthy")
s.dur[1] = { 20, 100 }
fire(dw, "UPDATE_INVENTORY_DURABILITY")
need(errors, "Gear is low: 20%", "low warning")
local n = #errors
s.dur[1] = { 19, 100 }
fire(dw, "UPDATE_INVENTORY_DURABILITY")
assert(#errors == n, "does not repeat warning in same tier")
s.dur[1] = { 0, 100 }
fire(dw, "UPDATE_INVENTORY_DURABILITY")
need(errors, "An item is broken!", "broken warning")
s.dur[1] = { 100, 100 }; s.dur[5] = { 100, 100 }
fire(dw, "UPDATE_INVENTORY_DURABILITY")
s.dur[1] = { 10, 100 }
fire(dw, "UPDATE_INVENTORY_DURABILITY")
assert(#errors == n + 2, "warns again after repair")
-- Helpers no longer write to chat; their lines go to the hub window, so capture them there.
ForeverHub_Receive = function(_, t) chat[#chat + 1] = t end
fire(dw, "MERCHANT_SHOW")
need(chat, "costs 1g 23s 45c", "repair cost")
SlashCmdList.DURABILITYWATCH("")
need(chat, "most damaged item is at 10%", "slash")
s.dur[1] = { SECRET, SECRET }; s.dur[5] = nil
fire(dw, "UPDATE_INVENTORY_DURABILITY")
SlashCmdList.DURABILITYWATCH("")
need(chat, "No durability data", "secret durability ignored")

-- BagCheck
chat, errors = {}, {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
UIErrorsFrame = { AddMessage = function(_, t) errors[#errors + 1] = t end }
local bc = load("BagCheck")
fire(bc, "PLAYER_ENTERING_WORLD")
-- Warnings now go to the hub (captured into chat above), not Blizzard's error line.
local function fullWarnings()
    local n = 0
    for _, t in ipairs(chat) do if t:find("Bags nearly full", 1, true) then n = n + 1 end end
    return n
end
assert(fullWarnings() == 0 and #errors == 0, "no warning with free slots; profession bag not counted")
s.bags[0].free = 2
fire(bc, "BAG_UPDATE_DELAYED")
need(chat, "Bags nearly full: 2 slot(s) free", "profession bag slots excluded")
fire(bc, "BAG_UPDATE_DELAYED")
assert(fullWarnings() == 1, "warns once")
s.bags[0].slots = {
    { quality = 0, stackCount = 2, itemID = 100 },
    false,
    { quality = 4, stackCount = 1, itemID = 200 },
}
fire(bc, "MERCHANT_SHOW")
need(chat, "2 junk item(s) worth 0g 3s 0c", "junk value excludes good items")
s.bags[0].slots[2] = { quality = 0, stackCount = 1, itemID = 300 }
fire(bc, "MERCHANT_SHOW")
need(chat, "3 junk item(s) worth at least 0g 3s 0c", "uncached price flagged")
assert(requested[300], "requests uncached item")
s.bags[0].slots = {}
SlashCmdList.BAGCHECK("")
need(chat, "No junk in your bags", "empty junk")

-- LevelLog
chat = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
local ll = load("LevelLog")
fire(ll, "PLAYER_LOGIN")
s.now = s.now + 600
fire(ll, "PLAYER_DEAD")
fire(ll, "PLAYER_LEVEL_UP", 6)
need(chat, "Level 5 took 10m", "level time")
s.now = s.now + 3900
SlashCmdList.LEVELLOG("")
need(chat, "Level 6: 1h 5m, 0 death(s)", "current level time")
need(chat, "Level 5: 10m, 1 death(s)", "deaths per level")
need(chat, "Total logged: 1h 15m, 1 death(s)", "totals")
s.now = s.now + 60
fire(ll, "PLAYER_LOGOUT")
assert(math.floor(LevelLogDB["Tester-Realm"][6].seconds) == 3960, "logout saves time")
SlashCmdList.LEVELLOG("all")

print("ALL TESTS PASSED")
