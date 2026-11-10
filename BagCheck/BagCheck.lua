local LOW_FREE_SLOTS = 3
local POOR_QUALITY, EPIC_QUALITY = 0, 4
local HEARTHSTONE = 6948
local CLASS_WEAPON, SUBCLASS_FISHING_POLE, CLASS_RECIPE, CLASS_QUEST = 2, 20, 9, 12
local DROP_CHOICES = 3
-- Profession tools you need to carry (never suggested): mining pick, skinning knife, blacksmith hammer,
-- arclight spanner, gyromatic micro-adjustor, enchanting rods, philosopher's stone, flint and tinder.
local TOOLS = {
    [2901] = true, [7005] = true, [5956] = true, [6219] = true, [10498] = true, [6218] = true, [6339] = true,
    [11130] = true, [11145] = true, [16207] = true, [9149] = true, [4471] = true,
}

local warned = false
local db -- this character's settings: { keep = { [itemID] = true } }

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

-- "1g 2s", "3s", "25c".
local function ShortMoney(copper)
    copper = math.floor(copper)
    local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if gold > 0 then
        return silver > 0 and string.format("%dg %ds", gold, silver) or string.format("%dg", gold)
    elseif silver > 0 then
        return string.format("%ds", silver)
    end
    return string.format("%dc", rest)
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

local function NormalBag(bag)
    local _, bagType = C_Container.GetContainerNumFreeSlots(bag)
    return Safe(bagType) == 0
end

-- A stack bought back for a refund is still yours to return, so it isn't junk or something to drop.
local function Refundable(bag, slot)
    if not (C_Container.GetContainerItemPurchaseInfo) then
        return false
    end
    local ok, info = pcall(C_Container.GetContainerItemPurchaseInfo, bag, slot, false)
    local seconds = ok and type(info) == "table" and Safe(info.refundSeconds)
    return type(seconds) == "number" and seconds > 0
end

local function IsQuestItem(bag, slot)
    if not C_Container.GetContainerItemQuestInfo then
        return false
    end
    local ok, info = pcall(C_Container.GetContainerItemQuestInfo, bag, slot)
    if not ok or type(info) ~= "table" then
        return false
    end
    return Safe(info.isQuestItem) == true or Safe(info.questID) ~= nil
end

-- Junk (grey) you can sell: locked, no-value, refundable and zero-price stacks are skipped. Items whose
-- quality or price hasn't loaded are counted and marked pending (the total is then "at least").
-- After Tweaks Forever's junk rules (Bags\Junk.lua, GPL-3.0-or-later), in our own code.
local function ScanJunk()
    local count, value, pending = 0, 0, false
    for bag = 0, LastBag() do
        for slot = 1, Safe(C_Container.GetContainerNumSlots(bag)) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local itemID = info and Safe(info.itemID)
            if itemID and not Safe(info.isLocked) and not Safe(info.hasNoValue) then
                local quality = Safe(info.quality)
                if quality == nil then
                    -- Still loading: unknown, never assumed junk or not.
                    pending = true
                    C_Item.RequestLoadItemDataByID(itemID)
                elseif quality == POOR_QUALITY and not Refundable(bag, slot) then
                    local stack = Safe(info.stackCount) or 1
                    local price = Safe((select(11, C_Item.GetItemInfo(itemID))))
                    if price == nil then
                        count = count + stack
                        pending = true
                        C_Item.RequestLoadItemDataByID(itemID)
                    elseif type(price) == "number" and price > 0 then
                        count = count + stack
                        value = value + price * stack
                    end
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

-- ---- What to drop when bags are full (research\re_round3.md rank 7) -----------------------------------------
-- The cheapest stacks (vendor price x count) in normal bags, never: quest items, profession tools, the
-- hearthstone, fishing poles, recipes, quest-class items, books (readable), set items, epic or better, locked,
-- refundable or unsellable stacks, nor anything on your keep list. Rules after OneForAll - Forever's
-- bags-full helper (QoL.lua, GPL-3.0-or-later), in our own code. Only a hint: nothing is ever deleted.
local function DropCandidates()
    local list = {}
    for bag = 0, LastBag() do
        if NormalBag(bag) then
            for slot = 1, Safe(C_Container.GetContainerNumSlots(bag)) or 0 do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                local itemID = info and Safe(info.itemID)
                local quality = info and Safe(info.quality)
                if itemID and quality and quality < EPIC_QUALITY and itemID ~= HEARTHSTONE and not TOOLS[itemID]
                    and not (db and db.keep[itemID]) and not Safe(info.isLocked) and not Safe(info.hasNoValue)
                    and not Safe(info.isReadable) then
                    local name, _, _, _, _, _, _, _, _, _, price, classID, subClassID, _, _, setID = C_Item.GetItemInfo(itemID)
                    name, price, classID, subClassID, setID = Safe(name), Safe(price), Safe(classID), Safe(subClassID), Safe(setID)
                    local skip = not name or type(price) ~= "number" or price <= 0
                        or classID == CLASS_RECIPE or classID == CLASS_QUEST
                        or (classID == CLASS_WEAPON and subClassID == SUBCLASS_FISHING_POLE)
                        or (type(setID) == "number" and setID > 0)
                    if not skip and not IsQuestItem(bag, slot) and not Refundable(bag, slot) then
                        local stack = Safe(info.stackCount) or 1
                        list[#list + 1] = { itemID = itemID, name = name, link = Safe(info.hyperlink), count = stack, value = price * stack }
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.value ~= b.value then
            return a.value < b.value
        end
        return a.itemID < b.itemID
    end)
    return list
end

local function CandidateText(entry)
    local count = entry.count > 1 and (" x" .. entry.count) or ""
    return string.format("%s%s (%s)", entry.name, count, ShortMoney(entry.value))
end

-- "Cheapest to drop if you need room: A (3c), B x4 (12c)", or nil.
local function DropLine()
    local list = DropCandidates()
    if #list == 0 then
        return nil
    end
    local parts = {}
    for index = 1, math.min(DROP_CHOICES, #list) do
        parts[#parts + 1] = CandidateText(list[index])
    end
    return "Cheapest to drop if you need room: " .. table.concat(parts, ", ") .. "."
end

-- Whether a looted item would stack onto one you carry, so it needs no free slot.
local function FitsInStack(itemID, count)
    local maxStack = Safe((select(8, C_Item.GetItemInfo(itemID))))
    if type(maxStack) ~= "number" or maxStack <= 1 then
        return false
    end
    for bag = 0, LastBag() do
        for slot = 1, Safe(C_Container.GetContainerNumSlots(bag)) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and Safe(info.itemID) == itemID and (Safe(info.stackCount) or maxStack) + count <= maxStack then
                return true
            end
        end
    end
    return false
end

-- With full bags at a loot window: the best item you can't take, and the cheapest stack you could drop
-- for it. Quest items are always worth taking. One hint per loot window, never any action.
local function LootHint()
    if not (GetNumLootItems and GetLootSlotLink) then
        return
    end
    local free = FreeSlots()
    if free == nil or free > 0 then
        return
    end
    local best
    for slot = 1, Safe(GetNumLootItems()) or 0 do
        local okLink, link = pcall(GetLootSlotLink, slot)
        link = okLink and Safe(link)
        local itemID = type(link) == "string" and tonumber(link:match("item:(%d+)"))
        if itemID then
            local quantity, isQuestItem
            if GetLootSlotInfo then
                local ok, _, _, q, _, _, _, quest = pcall(GetLootSlotInfo, slot)
                quantity, isQuestItem = ok and Safe(q), ok and Safe(quest)
            end
            quantity = type(quantity) == "number" and quantity > 0 and quantity or 1
            local name, _, _, _, _, _, _, _, _, _, price = C_Item.GetItemInfo(itemID)
            name, price = Safe(name), Safe(price)
            if name and not FitsInStack(itemID, quantity) then
                local value = (type(price) == "number" and price or 0) * quantity
                local entry = { name = name, value = value, quest = isQuestItem == true, count = quantity }
                if not best or (entry.quest and not best.quest) or (entry.quest == best.quest and value > best.value) then
                    best = entry
                end
            end
        end
    end
    if not best then
        return
    end
    local drop = DropCandidates()[1]
    if not drop then
        Print(string.format("Bags full: no room for %s, and nothing cheap to make room with.", best.name))
        return
    end
    if best.quest then
        Print(string.format("Bags full: drop %s to take %s (quest item).", CandidateText(drop), best.name))
    elseif best.value > drop.value then
        Print(string.format("Bags full: drop %s to take %s.", CandidateText(drop), CandidateText(best)))
    end
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

-- Your keep list: "keep <name>" / "forget <name>", matched against what's in your bags.
local function FindBagItem(text)
    local needle = text:lower()
    local partial
    for bag = 0, LastBag() do
        for slot = 1, Safe(C_Container.GetContainerNumSlots(bag)) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local link = info and Safe(info.hyperlink)
            local itemID = info and Safe(info.itemID)
            local name = type(link) == "string" and link:match("%[(.-)%]")
            if name and itemID then
                if name:lower() == needle then
                    return itemID, name
                elseif not partial and name:lower():find(needle, 1, true) then
                    partial = { itemID, name }
                end
            end
        end
    end
    if partial then
        return partial[1], partial[2]
    end
end

local function SetupDB()
    BagCheckDB = type(BagCheckDB) == "table" and BagCheckDB or {}
    local key = (ForeverCharacterKey and ForeverCharacterKey())
        or ((Safe(UnitName("player")) or "Unknown") .. "-" .. (Safe(GetRealmName()) or "Unknown"))
    BagCheckDB[key] = type(BagCheckDB[key]) == "table" and BagCheckDB[key] or {}
    db = BagCheckDB[key]
    db.keep = type(db.keep) == "table" and db.keep or {}
end

local function KeepCommand(verb, rest)
    if not db then
        return
    end
    local itemID, name = FindBagItem(rest)
    if not itemID then
        Print(string.format("Couldn't find \"%s\" in your bags.", rest))
        return
    end
    db.keep[itemID] = verb == "keep" or nil
    Print(verb == "keep" and string.format("%s will never be suggested to drop.", name)
        or string.format("%s can be suggested to drop again.", name))
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("LOOT_OPENED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        SetupDB()
    elseif event == "MERCHANT_SHOW" then
        -- ItemAdvisor's vendor pop-up already includes junk, unless it's switched off on the hub's Manage page.
        local advisorOff = ForeverHub_IsOff and ForeverHub_IsOff("ItemAdvisor")
        if advisorOff or not (ForeverHubStatus and ForeverHubStatus.ItemAdvisor) then
            ReportJunk()
        end
    elseif event == "LOOT_OPENED" then
        LootHint()
    else
        CheckSpace()
    end
end)

SLASH_BAGCHECK1 = "/bagcheck"
SlashCmdList.BAGCHECK = function(message)
    local verb, rest = (message or ""):match("^%s*(%a+)%s+(.-)%s*$")
    verb = verb and verb:lower()
    if (verb == "keep" or verb == "forget") and rest ~= "" then
        KeepCommand(verb, rest)
    end
    local free = FreeSlots()
    Print(free and string.format("%d slot(s) free.", free) or "The game didn't report your bag space.")
    if ReportJunk() == 0 then
        Print("No junk in your bags.")
    end
    local drop = free and free <= LOW_FREE_SLOTS and DropLine()
    if drop then
        Print(drop)
    end
    if db and next(db.keep) then
        local names = {}
        for itemID in pairs(db.keep) do
            names[#names + 1] = Safe((C_Item.GetItemInfo(itemID))) or ("item " .. itemID)
        end
        table.sort(names)
        Print("Never suggested to drop: " .. table.concat(names, ", ") .. ".")
    end
end

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.BagCheck = function()
    local free = FreeSlots()
    if free and BagsLoaded() and free <= LOW_FREE_SLOTS then
        return { { text = string.format("|cffffcc33Bags|r only %d slot(s) free", free), page = "Bag space" } }
    end
end
