-- Shared Forever character identity (the same copy is in every helper that saves per-character data,
-- so each helper still works alone; whichever loads first defines it). On Forever a character has a
-- first name and a surname (UnitName's second return), so the first name alone is not unique.
-- Key = the player GUID ("Player-<server>-<id>"); when that can't be read, "First Surname-Realm".
do
    local function Plain(value)
        if value == nil or (issecretvalue and issecretvalue(value)) or type(value) ~= "string" or value == "" then
            return nil
        end
        return value
    end
    local function Call(fn, ...)
        if type(fn) ~= "function" then
            return nil
        end
        local ok, a, b = pcall(fn, ...)
        if not ok then
            return nil
        end
        return Plain(a), Plain(b)
    end
    -- "First Surname" on Forever, the plain name elsewhere; nil when unreadable.
    ForeverCharacterName = ForeverCharacterName or function()
        local name, surname = Call(UnitName, "player")
        if not name then
            return nil
        end
        if surname then
            return name .. " " .. surname
        end
        return name
    end
    ForeverCharacterGUID = ForeverCharacterGUID or function()
        local guid = Call(UnitGUID, "player")
        if guid and guid:match("^Player%-") then
            return guid
        end
    end
    -- The key older versions used: first name only, "-", realm.
    ForeverCharacterLegacyKey = ForeverCharacterLegacyKey or function()
        local name = Call(UnitName, "player")
        local realm = Call(GetRealmName)
        return (name or "Unknown") .. "-" .. (realm or "Unknown")
    end
    -- "First Surname-Realm": the key when the GUID can't be read.
    ForeverCharacterNameKey = ForeverCharacterNameKey or function()
        local realm = Call(GetRealmName)
        return (ForeverCharacterName() or "Unknown") .. "-" .. (realm or "Unknown")
    end
    ForeverCharacterKey = ForeverCharacterKey or function()
        return ForeverCharacterGUID() or ForeverCharacterNameKey()
    end
    -- Once per login: moves this character's record from an older key to the current one. Only when
    -- nothing is saved under the current key yet (two records are never merged), and never a record
    -- stamped with another character's GUID. The old key's record is moved, not copied, so a second
    -- character with the same first name starts fresh instead of sharing it. Returns the current key.
    -- oldKeys: optional list of this helper's own older key spellings (default: the legacy key).
    ForeverCharacterAdopt = ForeverCharacterAdopt or function(db, oldKeys)
        local key = ForeverCharacterKey()
        if type(db) ~= "table" or db[key] ~= nil then
            return key
        end
        local guid = ForeverCharacterGUID()
        local candidates = { ForeverCharacterNameKey() }
        for _, old in ipairs(oldKeys or { ForeverCharacterLegacyKey() }) do
            candidates[#candidates + 1] = old
        end
        for _, old in ipairs(candidates) do
            local record = old ~= key and db[old]
            if type(record) == "table" and (record.charGUID == nil or record.charGUID == guid) then
                db[key] = record
                db[old] = nil
                record.migratedFrom = old
                break
            end
        end
        return key
    end
    -- Writes who a record belongs to into it, so pages can show a name instead of parsing the key.
    ForeverCharacterStamp = ForeverCharacterStamp or function(record)
        if type(record) ~= "table" then
            return record
        end
        record.charName = ForeverCharacterName() or record.charName
        record.charGUID = ForeverCharacterGUID() or record.charGUID
        return record
    end
end

local DEFAULT_AMMO_MIN = 200
local AMMO_SLOT = INVSLOT_AMMO or 0
local CLASS_PROJECTILE = 6

local charData
local warned = {}

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("SupplyWatch", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

-- Returns count and whether ammo applies to this character at all.
local function AmmoCount()
    if not (UnitUsesAmmo and Safe(UnitUsesAmmo("player"))) then
        return nil
    end
    -- An empty ammo slot can still report a count, so check the slot first.
    if not GetInventoryItemLink("player", AMMO_SLOT) then
        return 0
    end
    return Safe(GetInventoryItemCount("player", AMMO_SLOT)) or 0
end

-- Every supply as { key, name, count, min }. The key is "ammo" or the item's ID.
local function ReadSupplies()
    local supplies = {}
    local ammo = AmmoCount()
    if ammo and charData.ammoMin > 0 then
        supplies[#supplies + 1] = { key = "ammo", name = "Ammo", count = ammo, min = charData.ammoMin }
    end
    for _, item in ipairs(charData.items) do
        supplies[#supplies + 1] = { key = item.id, name = item.name, count = Safe(C_Item.GetItemCount(item.id)) or 0, min = item.min }
    end
    return supplies
end

-- If bags haven't loaded yet every count reads 0, which would warn about everything.
local function BagsLoaded()
    return (Safe(C_Container.GetContainerNumSlots(0)) or 0) > 0
end

local function CheckSupplies()
    if not (charData and BagsLoaded()) then
        return
    end
    local active = {}
    for _, supply in ipairs(ReadSupplies()) do
        if supply.count < supply.min then
            active[supply.key] = true
            if not warned[supply.key] then
                if not ForeverHub_Receive then UIErrorsFrame:AddMessage(string.format("Low on %s: %d", supply.name, supply.count), 1, 0.8, 0.1) end
                Print(string.format("Low on %s: %d (you want %d).", supply.name, supply.count, supply.min))
            end
        end
    end
    warned = active
end

-- Guns fire bullets; bows and crossbows fire arrows (weapon subclass -> projectile subclass).
local RANGED_SLOT = INVSLOT_RANGED or 18
local CLASS_WEAPON = 2
local PROJECTILE_FOR_WEAPON = { [2] = 2, [18] = 2, [3] = 3 }

-- The projectile subclass the equipped ranged weapon fires, or nil if it can't be told.
local function WantedProjectile()
    local link = Safe(GetInventoryItemLink("player", RANGED_SLOT))
    if not link then
        return nil
    end
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(link)
    if Safe(classID) ~= CLASS_WEAPON then
        return nil
    end
    return PROJECTILE_FOR_WEAPON[Safe(subClassID) or -1]
end

-- Item IDs this vendor sells, or nil if its list couldn't be read.
local function MerchantItems()
    local count = GetMerchantNumItems and Safe(GetMerchantNumItems()) or 0
    if count == 0 or not GetMerchantItemID then
        return nil
    end
    local wanted = WantedProjectile()
    local sold = {}
    for index = 1, count do
        local id = Safe(GetMerchantItemID(index))
        if id then
            sold[id] = true
            -- Ammo counts only when it fits the ranged weapon; an empty or different ammo slot still needs some.
            -- If the weapon can't be read, any arrows or bullets count.
            local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(id)
            if Safe(classID) == CLASS_PROJECTILE and (not wanted or Safe(subClassID) == wanted) then
                sold.ammo = true
            end
        end
    end
    return sold
end

-- Only what this vendor sells, so every repair or junk stop isn't a shopping list.
-- If the vendor's list can't be read, everything short is mentioned as before.
local function ReportRestock()
    local sold = MerchantItems()
    for _, supply in ipairs(ReadSupplies()) do
        if supply.count < supply.min and (not sold or sold[supply.key]) then
            Print(string.format("Restock %s%s: you have %d, %d short.", supply.name, sold and " here" or "", supply.count, supply.min - supply.count))
        end
    end
end

local function ShowList()
    local supplies = ReadSupplies()
    local ammo = AmmoCount()
    if #supplies == 0 then
        Print("Nothing watched. Enter an item in your bags and how many you want on the Supplies page, such as Water 20.")
    end
    local index = 0
    for _, supply in ipairs(supplies) do
        if supply.key == "ammo" then
            Print(string.format("Ammo: %d/%d", supply.count, supply.min))
        else
            index = index + 1
            Print(string.format("%d. %s: %d/%d", index, supply.name, supply.count, supply.min))
        end
    end
    if ammo and charData.ammoMin == 0 then
        Print("Ammo warning is off.")
    end
end

local function HandleSlash(message)
    local command, rest = message:match("^(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" then
        ShowList()
    elseif command == "add" then
        local id, name, amount = rest:match("item:(%d+).-|h%[(.-)%]|h.-%s+(%d+)$")
        if not id then
            Print("Type an item in your bags and how many you want, such as Water 20.")
            return
        end
        id, amount = tonumber(id), tonumber(amount)
        for index, item in ipairs(charData.items) do
            if item.id == id then
                -- Wanting 0 can never warn, so it means stop watching.
                if amount == 0 then
                    table.remove(charData.items, index)
                    Print("Stopped watching " .. item.name .. ".")
                else
                    item.min = amount
                    Print(string.format("%s: now want %d.", name, amount))
                end
                CheckSupplies()
                return
            end
        end
        if amount == 0 then
            Print("Enter how many you want to keep; 0 doesn't watch anything.")
            return
        end
        table.insert(charData.items, { id = id, name = name, min = amount })
        Print(string.format("Watching %s: want %d.", name, amount))
        CheckSupplies()
    elseif command == "remove" then
        local item = charData.items[tonumber(rest) or 0]
        if item then
            table.remove(charData.items, tonumber(rest))
            Print("Stopped watching " .. item.name .. ".")
            CheckSupplies()
        else
            Print("No watched item with that number. The list shows each item's number.")
        end
    elseif command == "ammo" and tonumber(rest:match("^%d+$") or "") then
        charData.ammoMin = tonumber(rest)
        Print(charData.ammoMin > 0 and string.format("Ammo warning at %d.", charData.ammoMin) or "Ammo warning off.")
        CheckSupplies()
    else
        Print("On the Supplies page, type an item in your bags and how many you want, such as Water 20.")
        Print("Or: remove 1 to stop watching item 1, or ammo 400 to set the ammo warning (0 turns it off).")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("MERCHANT_SHOW")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        SupplyWatchDB = SupplyWatchDB or {}
        local key = ForeverCharacterAdopt(SupplyWatchDB)
        SupplyWatchDB[key] = SupplyWatchDB[key] or {}
        charData = ForeverCharacterStamp(SupplyWatchDB[key])
        -- Filled in one at a time so a partial or older record still works.
        charData.items = charData.items or {}
        charData.ammoMin = tonumber(charData.ammoMin) or DEFAULT_AMMO_MIN
    elseif event == "MERCHANT_SHOW" then
        if charData then
            ReportRestock()
        end
    else
        CheckSupplies()
    end
end)

SLASH_SUPPLYWATCH1 = "/supply"
SlashCmdList.SUPPLYWATCH = function(message)
    if charData then
        HandleSlash(message)
    end
end

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.SupplyWatch = function()
    if not charData then
        return nil
    end
    local items = {}
    for _, supply in ipairs(ReadSupplies()) do
        if supply.count < supply.min then
            -- Watched items carry a link so the panel can show their tooltip.
            local link = type(supply.key) == "number" and ("item:" .. supply.key) or nil
            items[#items + 1] = { text = string.format("|cff66ccddBuy|r %s (%d/%d)", supply.name, supply.count, supply.min), page = "Supplies", link = link }
        end
    end
    return items
end
