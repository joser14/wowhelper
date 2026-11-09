local LOW_FREE_SLOTS = 3
local POOR_QUALITY = 0

local warned = false

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("BagCheck", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function FormatMoney(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    return string.format("%dg %ds %dc", gold, silver, copper % 100)
end

local function LastBag()
    return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
end

-- Nil when a bag can't be read, so a hidden value never looks like a full bag.
local function FreeSlots()
    local total = 0
    for bag = 0, LastBag() do
        local free, bagType = C_Container.GetContainerNumFreeSlots(bag)
        if issecretvalue and (issecretvalue(free) or issecretvalue(bagType)) then
            return nil
        end
        -- Bag type 0 is a normal bag; profession bags only hold their own items.
        if Safe(bagType) == 0 then
            total = total + (Safe(free) or 0)
        end
    end
    return total
end

local function ScanJunk()
    local count, value, pending = 0, 0, false
    for bag = 0, LastBag() do
        for slot = 1, Safe(C_Container.GetContainerNumSlots(bag)) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local itemID = info and Safe(info.itemID)
            if itemID and Safe(info.quality) == POOR_QUALITY then
                local stack = Safe(info.stackCount) or 1
                count = count + stack
                local price = Safe((select(11, C_Item.GetItemInfo(itemID))))
                if price then
                    value = value + price * stack
                else
                    pending = true
                    C_Item.RequestLoadItemDataByID(itemID)
                end
            end
        end
    end
    return count, value, pending
end

local function ReportJunk()
    local count, value, pending = ScanJunk()
    if count > 0 then
        Print(string.format("%d junk item(s) worth %s%s.",
            count, pending and "at least " or "", FormatMoney(value)))
    end
    return count
end

local function BagsLoaded()
    return (Safe(C_Container.GetContainerNumSlots(0)) or 0) > 0
end

local function CheckSpace()
    if not BagsLoaded() then
        return
    end
    local free = FreeSlots()
    if not free then
        return
    end
    if free <= LOW_FREE_SLOTS and not warned then
        if not ForeverHub_Receive then UIErrorsFrame:AddMessage(string.format("Bags nearly full: %d free", free), 1, 0.8, 0.1) end
        Print(string.format("Bags nearly full: %d slot(s) free.", free))
    end
    warned = free <= LOW_FREE_SLOTS
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("MERCHANT_SHOW")
events:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
        -- ItemAdvisor's vendor pop-up already includes junk.
        if not (ForeverHubStatus and ForeverHubStatus.ItemAdvisor) then
            ReportJunk()
        end
    else
        CheckSpace()
    end
end)

SLASH_BAGCHECK1 = "/bagcheck"
SlashCmdList.BAGCHECK = function()
    local free = FreeSlots()
    Print(free and string.format("%d slot(s) free.", free) or "The game didn't report your bag space.")
    if ReportJunk() == 0 then
        Print("No junk in your bags.")
    end
end

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.BagCheck = function()
    local free = FreeSlots()
    if free and BagsLoaded() and free <= LOW_FREE_SLOTS then
        return { { text = string.format("|cffffcc33Bags|r only %d slot(s) free", free), page = "Bag space" } }
    end
end
