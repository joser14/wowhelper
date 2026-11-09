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
events:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
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
    else
        Print("No durability data available.")
    end
end

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.DurabilityWatch = function()
    local lowest, slot = LowestPercent()
    if lowest and lowest <= LOW_PERCENT then
        -- The link lets the panel show which item it is on mouseover.
        return { { text = string.format("|cffff6633Repair|r gear at %d%%", lowest), page = "Repairs", link = SlotLink(slot) } }
    end
end
