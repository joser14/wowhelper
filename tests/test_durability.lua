-- DurabilityWatch: repair cost anywhere from equipped items' tooltip data, on its page and its side
-- panel row; the merchant's own total as the fallback.
local base = ADDON_PATH
local SECRET = {}
issecretvalue = function(v) return v == SECRET end
local out, chat = {}, {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
local frame
CreateFrame = function()
    frame = { RegisterEvent = function() end, SetScript = function(self, _, fn) self.fn = fn end }
    return frame
end
SlashCmdList = {}
local dur = { [1] = { 100, 100 }, [5] = { 100, 100 } }
GetInventoryItemDurability = function(slot) local d = dur[slot]; if d then return d[1], d[2] end end
GetInventoryItemLink = function(_, slot) if slot == 5 then return "|Hitem:10|h[Chest]|h" end end
local merchantOpen, merchantCost = false, 0
CanMerchantRepair = function() return merchantOpen end
GetRepairAllCost = function() return merchantCost, merchantCost > 0 end
-- slot -> tooltip data
local tips = {}
C_TooltipInfo = { GetInventoryItem = function(unit, slot)
    assert(unit == "player", "asks about the player")
    if tips[slot] == "error" then error("bad slot") end
    return tips[slot]
end }

assert(loadfile(base .. "/DurabilityWatch/DurabilityWatch.lua"))("DurabilityWatch", {})
local function page() out = {}; SlashCmdList.DURABILITYWATCH(""); return table.concat(out, "\n") end
local function row() local r = ForeverHubStatus.DurabilityWatch(); return r and r[1] end
-- The cost is kept until durability, gear or a merchant window changes (review 3b S4), as the game signals.
local function changed(event) frame.fn(frame, event or "UPDATE_INVENTORY_DURABILITY") end

----- Healthy gear: no row, the page says nothing needs repairing.
tips = { [1] = { repairCost = 0 }, [5] = { repairCost = 0 } }; changed()
assert(row() == nil, "no row when healthy")
assert(page():find("Nothing needs repairing", 1, true), "healthy page")

----- Damaged gear away from a merchant: cost summed from the tooltip data.
dur[5] = { 20, 100 }; dur[1] = { 60, 100 }
tips = { [1] = { repairCost = 4500 }, [5] = { repairCost = 12000 }, [2] = {} }; changed()
local text = page()
assert(text:find("Repairing everything costs 1g 65s 0c.", 1, true), "cost anywhere on the page: " .. text)
local r = row()
assert(r and r.text == "|cffff6633Repair|r gear at 20%  |cff999999(1g 65s)|r", "cost on the row: " .. tostring(r and r.text))
assert(r.page == "Repairs" and r.link == "|Hitem:10|h[Chest]|h", "row still opens Repairs with the link")

----- Older tooltip data shape: the cost inside the argument list.
tips = { [5] = { args = { { field = "type", intVal = 0 }, { field = "repairCost", intVal = 250 } } } }; changed()
assert(row().text:find("(2s 50c)", 1, true), "cost from args: " .. row().text)

----- Hidden or broken values are skipped, never added.
tips = { [1] = { repairCost = SECRET }, [5] = { repairCost = 900 }, [6] = "error", [7] = SECRET }; changed()
assert(row().text:find("(9s 0c)", 1, true), "secret and failing slots skipped: " .. row().text)

----- No tooltip data: the merchant's total while one is open, else a hint.
tips = {}; changed()
assert(row().text == "|cffff6633Repair|r gear at 20%", "no cost when unknown: " .. row().text)
text = page()
assert(text:find("once a repair merchant is open", 1, true), "hint when unknown: " .. text)
merchantOpen, merchantCost = true, 12345; changed("MERCHANT_SHOW")
assert(row().text:find("(1g 23s)", 1, true), "merchant fallback on the row: " .. row().text)
assert(page():find("costs 1g 23s 45c", 1, true), "merchant fallback on the page")
frame.fn(frame, "MERCHANT_SHOW")
assert(out[#out]:find("costs 1g 23s 45c", 1, true), "merchant pop-up still works")
merchantOpen = SECRET; changed("MERCHANT_CLOSED")
assert(row().text == "|cffff6633Repair|r gear at 20%", "hidden merchant state ignored")

----- No tooltip API at all: still works.
C_TooltipInfo = nil
merchantOpen = false
assert(pcall(row) and pcall(page), "no tooltip API is harmless")

assert(#chat == 0, "no chat")
print("ALL TESTS PASSED")
