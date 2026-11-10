-- Review 3b S4 (DurabilityWatch): while gear is at 25% or less, every side-panel refresh built 18 item
-- tooltips to read a repairCost field that this client's TooltipData docs don't have. Now the total is kept
-- until durability, gear or a merchant window changes, and the per-slot read stops for the session once a
-- pass over damaged gear finds no repairCost at all (the merchant's total still works).
local base = ADDON_PATH
local out, handled, frame = {}, {}, nil
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function() return false end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
CreateFrame = function()
    frame = { RegisterEvent = function() end, SetScript = function(self, _, fn) self.fn = fn end }
    return frame
end
SlashCmdList = {}
local dur = { [5] = { 10, 100 }, [7] = { 80, 100 } }
GetInventoryItemDurability = function(slot) local d = dur[slot]; if d then return d[1], d[2] end end
GetInventoryItemLink = function(_, slot) if dur[slot] then return "|Hitem:" .. slot .. "|h[Item]|h" end end
local reads, costs = 0, nil
C_TooltipInfo = { GetInventoryItem = function(_, slot)
    reads = reads + 1
    return { lines = {}, repairCost = costs and costs[slot] or nil }
end }
local merchantOpen = false
CanMerchantRepair = function() return merchantOpen end
GetRepairAllCost = function() return merchantOpen and 1234 or 0 end

-- 1. A client with per-item costs: read once, kept until something changes.
costs = { [5] = 300, [7] = 50 }
assert(loadfile(base .. "/DurabilityWatch/DurabilityWatch.lua"))("DurabilityWatch", {})
local function fire(...) frame.fn(frame, ...) end
local row = ForeverHubStatus.DurabilityWatch()[1]
assert(row.text:find("(3s 50c)", 1, true), "cost shown: " .. row.text)
assert(reads == 18, "one pass: " .. reads)
for _ = 1, 10 do ForeverHubStatus.DurabilityWatch() end
assert(reads == 18, "kept between refreshes: " .. reads)
costs[5] = 400
fire("UPDATE_INVENTORY_DURABILITY")
row = ForeverHubStatus.DurabilityWatch()[1]
assert(reads == 36 and row.text:find("(4s 50c)", 1, true), "read again after a durability change: " .. reads .. " " .. row.text)
fire("PLAYER_EQUIPMENT_CHANGED")
ForeverHubStatus.DurabilityWatch()
assert(reads == 54, "and after a gear change: " .. reads)
print("1 ok")

-- 2. A client without the field: one pass over damaged gear finds nothing, then no more tooltip reads;
-- the merchant's total still shows while a repair merchant is open.
costs = nil
reads = 0
assert(loadfile(base .. "/DurabilityWatch/DurabilityWatch.lua"))("DurabilityWatch", {})
row = ForeverHubStatus.DurabilityWatch()[1]
assert(not row.text:find("(", 1, true), "no cost known: " .. row.text)
assert(reads == 18, "one pass: " .. reads)
fire("UPDATE_INVENTORY_DURABILITY")
ForeverHubStatus.DurabilityWatch()
assert(reads == 18, "per-slot read given up: " .. reads)
merchantOpen = true
fire("MERCHANT_SHOW")
row = ForeverHubStatus.DurabilityWatch()[1]
assert(row.text:find("(12s 34c)", 1, true), "merchant total: " .. row.text)
merchantOpen = false
fire("MERCHANT_CLOSED")
row = ForeverHubStatus.DurabilityWatch()[1]
assert(not row.text:find("(", 1, true), "no stale merchant total after it closes: " .. row.text)
assert(reads == 18, "still no tooltip reads: " .. reads)
print("2 ok")

-- 3. Undamaged gear with no field doesn't give up (nothing to cost yet).
reads = 0
dur = { [5] = { 100, 100 } }
assert(loadfile(base .. "/DurabilityWatch/DurabilityWatch.lua"))("DurabilityWatch", {})
out = {}
SlashCmdList.DURABILITYWATCH()
dur = { [5] = { 10, 100 } }
costs = { [5] = 90 }
fire("UPDATE_INVENTORY_DURABILITY")
row = ForeverHubStatus.DurabilityWatch()[1]
assert(row.text:find("(90c)", 1, true), "still reads per slot: " .. row.text)
print("3 ok")

assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
