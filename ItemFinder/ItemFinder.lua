local FIRST_GEAR_SLOT, LAST_GEAR_SLOT = 1, 19
local MAX_RESULTS = 30

local charData
local bankOpen = false
local myKey

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("ItemFinder", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

-- A link can have an empty name until the game has loaded that item.
local function NameOf(link)
    local name = link:match("%[(.-)%]")
    if name ~= "" then
        return name
    end
end

local function ScanContainers(list)
    local items = {}
    for _, bag in ipairs(list) do
        for slot = 1, Safe(C_Container.GetContainerNumSlots(bag)) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local link = info and Safe(info.hyperlink)
            local name = link and NameOf(link)
            if name then
                items[name] = (items[name] or 0) + (Safe(info.stackCount) or 1)
            end
        end
    end
    return items
end

local function BagList()
    local list = {}
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        list[#list + 1] = bag
    end
    return list
end

-- Forever's bank bag IDs aren't documented for players, so use every personal bank entry the game lists.
local function BankList()
    local list = {}
    for name, bag in pairs(Enum and Enum.BagIndex or {}) do
        local lower = name:lower()
        -- Negative entries are placeholders (the tab-purchase slot), not containers.
        if type(bag) == "number" and bag >= 0 and lower:find("bank", 1, true) and not lower:find("account", 1, true) then
            list[#list + 1] = bag
        end
    end
    return list
end

local function SaveBags()
    if charData then
        charData.bags = ScanContainers(BagList())
    end
end

-- The bank can only be read while its window is open, and an unread one reports no slots.
local function SaveBank()
    if not (charData and bankOpen) then
        return
    end
    local slots = 0
    local list = BankList()
    for _, bag in ipairs(list) do
        slots = slots + (Safe(C_Container.GetContainerNumSlots(bag)) or 0)
    end
    if slots > 0 then
        charData.bank = ScanContainers(list)
    end
end

local function SaveGear()
    if not charData then
        return
    end
    local gear = {}
    for slot = FIRST_GEAR_SLOT, LAST_GEAR_SLOT do
        local link = Safe(GetInventoryItemLink("player", slot))
        local name = link and NameOf(link)
        if name then
            gear[name] = (gear[name] or 0) + 1
        end
    end
    charData.gear = gear
end

local function Search(term)
    local needle = term:lower()
    local matches = {}
    local function report(character, place, items)
        for name, count in pairs(items or {}) do
            if name:lower():find(needle, 1, true) then
                matches[#matches + 1] = { name = name, character = character, count = count, place = place }
            end
        end
    end
    for character, data in pairs(ItemFinderDB) do
        report(character, "bags", data.bags)
        report(character, "bank", data.bank)
        report(character, "worn", data.gear)
    end
    -- Saved data has no order, so sort to keep the same item's owners together and the cut-off stable.
    table.sort(matches, function(a, b)
        if a.name ~= b.name then
            return a.name < b.name
        elseif a.character ~= b.character then
            return a.character < b.character
        end
        return a.place < b.place
    end)
    for index = 1, math.min(#matches, MAX_RESULTS) do
        local match = matches[index]
        Print(string.format("%s: %s x%d (%s)", match.name, match.character, match.count, match.place))
    end
    if #matches == 0 then
        Print("Nothing found for \"" .. term .. "\".")
    elseif #matches > MAX_RESULTS then
        Print(string.format("...and %d more. Try a longer search.", #matches - MAX_RESULTS))
    end
end

local function OwnedElsewhereText(name)
    local mine = ItemFinderDB[myKey]
    local parts = {}
    local elsewhere = false
    if mine then
        if mine.bags and mine.bags[name] then
            parts[#parts + 1] = "bags " .. mine.bags[name]
        end
        if mine.bank and mine.bank[name] then
            parts[#parts + 1] = "bank " .. mine.bank[name]
            elsewhere = true
        end
    end
    local others = {}
    for character, data in pairs(ItemFinderDB) do
        if character ~= myKey then
            local count = ((data.bags and data.bags[name]) or 0) + ((data.bank and data.bank[name]) or 0) + ((data.gear and data.gear[name]) or 0)
            if count > 0 then
                others[#others + 1] = (character:match("^[^-]+") or character) .. " " .. count
                elsewhere = true
            end
        end
    end
    table.sort(others)
    for _, text in ipairs(others) do
        parts[#parts + 1] = text
    end
    -- Only your own bags is what you're already looking at, so it isn't worth a line.
    return elsewhere and table.concat(parts, ", ") or nil
end

local function OnTooltip(tooltip)
    if not charData or (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) then
        return
    end
    local name = Safe((TooltipUtil.GetDisplayedItem(tooltip)))
    local text = type(name) == "string" and name ~= "" and OwnedElsewhereText(name)
    if text then
        tooltip:AddLine("Owned: " .. text, 0.6, 0.8, 1)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
-- Listed as unverified on Forever, so a missing event must not stop the addon.
pcall(events.RegisterEvent, events, "BANKFRAME_OPENED")
pcall(events.RegisterEvent, events, "BANKFRAME_CLOSED")
pcall(events.RegisterEvent, events, "PLAYERBANKSLOTS_CHANGED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        ItemFinderDB = ItemFinderDB or {}
        local key = (Safe(UnitName("player")) or "Unknown") .. "-" .. (Safe(GetRealmName()) or "Unknown")
        ItemFinderDB[key] = ItemFinderDB[key] or {}
        charData = ItemFinderDB[key]
        myKey = key
        -- Characters not seen for three months are most likely deleted; keep their names out of tooltips.
        charData.lastSeen = time()
        local cutoff = time() - 90 * 86400
        for other, record in pairs(ItemFinderDB) do
            if other ~= key and type(record) == "table" then
                if type(record.lastSeen) ~= "number" then
                    record.lastSeen = time()
                elseif record.lastSeen < cutoff then
                    ItemFinderDB[other] = nil
                end
            end
        end
        -- The Tooltips helper shows counts on every character (and can switch them off); only add our own line without it.
        if not (SlashCmdList and SlashCmdList.TOOLTIPS) and TooltipDataProcessor and TooltipUtil and Enum and Enum.TooltipDataType then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltip)
        end
        SaveBags()
        SaveGear()
    elseif event == "BAG_UPDATE_DELAYED" then
        SaveBags()
        -- Worn items' names can be missing at login, so this also fills them in later.
        SaveGear()
        SaveBank()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        SaveGear()
    elseif event == "BANKFRAME_OPENED" then
        bankOpen = true
        SaveBank()
    elseif event == "BANKFRAME_CLOSED" then
        bankOpen = false
    else
        SaveBank()
    end
end)

SLASH_ITEMFINDER1 = "/find"
SlashCmdList.ITEMFINDER = function(message)
    local term = message:match("^%s*(.-)%s*$")
    if not charData then
        return
    end
    if term == "" then
        Print("Use /find <part of an item name>. Bank items appear after you've opened that character's bank.")
    else
        Search(term)
    end
end
