local LOW_PERCENT = 25
local FIRST_SLOT, LAST_SLOT = 1, 18

local warnedTier = 0

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("DurabilityWatch", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function FormatMoney(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    return string.format("%dg %ds %dc", gold, silver, copper % 100)
end

-- The most damaged item's percent, and its slot so the item can be named.
local function LowestPercent()
    local lowest, lowestSlot
    for slot = FIRST_SLOT, LAST_SLOT do
        local current, maximum = GetInventoryItemDurability(slot)
        current, maximum = Safe(current), Safe(maximum)
        if current and maximum and maximum > 0 then
            local percent = math.floor(current * 100 / maximum)
            if not lowest or percent < lowest then
                lowest, lowestSlot = percent, slot
            end
        end
    end
    return lowest, lowestSlot
end

local function SlotLink(slot)
    return slot and GetInventoryItemLink and Safe(GetInventoryItemLink("player", slot))
end

local function CheckGear()
    local lowest = LowestPercent()
    if not lowest then
        return
    end
    local tier = (lowest == 0 and 2) or (lowest <= LOW_PERCENT and 1) or 0
    if tier > warnedTier then
        local text = tier == 2 and "An item is broken!" or string.format("Gear is low: %d%%", lowest)
        if not ForeverHub_Receive then UIErrorsFrame:AddMessage(text, 1, 0.3, 0.1) end
        Print(text)
    end
    warnedTier = tier
end

-- Short form for the side panel: "1g 23s", "23s 45c" or "45c".
local function ShortMoney(copper)
    local gold, silver = math.floor(copper / 10000), math.floor(copper / 100) % 100
    if gold > 0 then
        return string.format("%dg %ds", gold, silver)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, copper % 100)
    end
    return string.format("%dc", copper % 100)
end

-- One equipped item's repair cost from its tooltip data: the repairCost field, or the same value
-- in the older list-of-arguments form. nil when the client doesn't say.
local function SlotRepairCost(slot)
    local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
    data = ok and Safe(data)
    if type(data) ~= "table" then
        return nil
    end
    local cost = Safe(data.repairCost)
    if cost == nil and type(data.args) == "table" then
        for _, arg in ipairs(data.args) do
            if type(arg) == "table" and Safe(arg.field) == "repairCost" then
                cost = Safe(arg.intVal)
            end
        end
    end
    return type(cost) == "number" and cost >= 0 and cost or nil
end

-- Whether an equipped item is damaged (current below maximum durability).
local function SlotDamaged(slot)
    local current, maximum = GetInventoryItemDurability(slot)
    current, maximum = Safe(current), Safe(maximum)
    return current and maximum and maximum > 0 and current < maximum or false
end

-- Review 3b S4: the side panel asks for the cost on every refresh while gear is low, and each ask built 18
-- item tooltips. repairCost isn't in this client's TooltipData docs, so it may never be there. Now the total
-- is kept until durability, gear or a merchant window changes, and once a full pass over damaged gear finds
-- no repairCost at all, the per-slot read is skipped for the rest of the session (merchant total only).
local cachedCost, costDirty = nil, true
local perSlotWorks -- nil until known; false once the client showed it has no per-item repair cost

local function ComputeRepairCost()
    local total, any = 0, false
    if perSlotWorks ~= false and C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local damaged = false
        for slot = FIRST_SLOT, LAST_SLOT do
            local cost = SlotRepairCost(slot)
            if cost then
                total, any = total + cost, true
            end
            damaged = damaged or SlotDamaged(slot)
        end
        if any then
            perSlotWorks = true
        elseif damaged and perSlotWorks == nil then
            perSlotWorks = false
        end
    end
    if any and total > 0 then
        return total
    end
    local merchantCost = GetRepairAllCost and CanMerchantRepair and Safe(CanMerchantRepair()) and Safe((GetRepairAllCost()))
    if type(merchantCost) == "number" and merchantCost > 0 then
        return merchantCost
    end
    return any and total or nil
end

-- What repairing everything you wear costs, read anywhere. Falls back to the repair merchant's own
-- total while one is open. nil when neither can tell.
local function RepairCost()
    if costDirty then
        cachedCost, costDirty = ComputeRepairCost(), false
    end
    return cachedCost
end

local function ShowRepairCost()
    local cost = Safe((GetRepairAllCost()))
    if cost and cost > 0 then
        Print("Repairing everything costs " .. FormatMoney(cost) .. ".")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("MERCHANT_CLOSED")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:SetScript("OnEvent", function(_, event)
    -- Anything here can change the repair bill.
    costDirty = true
    if event == "MERCHANT_CLOSED" or event == "PLAYER_EQUIPMENT_CHANGED" then
        return
    elseif event == "MERCHANT_SHOW" then
        if CanMerchantRepair() then
            ShowRepairCost()
        end
    else
        CheckGear()
    end
end)

SLASH_DURABILITYWATCH1 = "/dur"
SlashCmdList.DURABILITYWATCH = function()
    local lowest, slot = LowestPercent()
    local link = SlotLink(slot)
    if lowest then
        Print(string.format("Your most damaged item is at %d%%%s.", lowest, link and ": " .. link or ""))
        local cost = RepairCost()
        if cost and cost > 0 then
            Print("Repairing everything costs " .. FormatMoney(cost) .. ".")
        elseif lowest >= 100 then
            Print("Nothing needs repairing.")
        else
            Print("|cff999999The repair cost shows here once a repair merchant is open.|r")
        end
    else
        Print("No durability data available.")
    end
end

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.DurabilityWatch = function()
    local lowest, slot = LowestPercent()
    if lowest and lowest <= LOW_PERCENT then
        -- The link lets the panel show which item it is on mouseover.
        local cost = RepairCost()
        local costText = cost and cost > 0 and string.format("  |cff999999(%s)|r", ShortMoney(cost)) or ""
        return { { text = string.format("|cffff6633Repair|r gear at %d%%%s", lowest, costText), page = "Repairs", link = SlotLink(slot) } }
    end
end
