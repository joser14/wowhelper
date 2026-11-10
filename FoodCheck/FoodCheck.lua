local CLASS_CONSUMABLE, SUBCLASS_FOOD_DRINK = 0, 5
local OUTGROWN_LEVELS = 15

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("FoodCheck", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

-- Whether the item's tooltip says it restores health, mana, or both.
local function ReadRestores(link)
    local data = C_TooltipInfo and C_TooltipInfo.GetHyperlink(link)
    local health, mana = false, false
    for _, line in ipairs(data and data.lines or {}) do
        local text = Safe(line.leftText)
        if type(text) == "string" then
            -- A well-fed buff ("...become well fed and gain 3 Mana every 5 seconds") isn't what it restores.
            text = text:lower():gsub("if you spend.*$", ""):gsub("well fed.*$", "")
            if text:find("restores", 1, true) or text:find("use:", 1, true) then
                health = health or text:find("health", 1, true) ~= nil
                mana = mana or text:find("mana", 1, true) ~= nil
            end
        end
    end
    return health, mana
end

-- Food and drink in your bags, merged by item. Also returns whether any item hasn't loaded yet.
local function ReadBags()
    local items, byLink, pending = {}, {}, false
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        for slot = 1, Safe(C_Container.GetContainerNumSlots(bag)) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local link = info and Safe(info.hyperlink)
            if link then
                local name, _, _, _, minLevel, _, _, _, _, _, _, classID, subClassID = C_Item.GetItemInfo(link)
                name, minLevel, classID, subClassID = Safe(name), Safe(minLevel), Safe(classID), Safe(subClassID)
                if not name then
                    pending = true
                    local itemID = Safe(info.itemID)
                    if itemID then
                        C_Item.RequestLoadItemDataByID(itemID)
                    end
                elseif classID == CLASS_CONSUMABLE and subClassID == SUBCLASS_FOOD_DRINK then
                    local item = byLink[link]
                    if not item then
                        local health, mana = ReadRestores(link)
                        item = { link = link, level = minLevel or 1, count = 0, health = health, mana = mana }
                        byLink[link] = item
                        items[#items + 1] = item
                    end
                    item.count = item.count + (Safe(info.stackCount) or 1)
                end
            end
        end
    end
    return items, pending
end

-- The "Campfire Nearby" aura, spell 1283391 (from Tweaks Forever's Data\CampBenefits.lua, GPL-3.0-or-later,
-- Blizzard spell data; UNVERIFIED in game). Read only out of combat and when auras aren't secret.
local CAMPFIRE_NEARBY = 1283391
local function CampfireNearby()
    if InCombatLockdown and InCombatLockdown() then
        return false
    end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
        if not ok or Safe(secret) ~= false then
            return false
        end
    end
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then
        return false
    end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, CAMPFIRE_NEARBY)
    return ok and type(Safe(aura)) == "table"
end

local function BestFor(items, level, field)
    local best
    for _, item in ipairs(items) do
        -- Among equals, the smaller stack, since finishing it frees a bag slot.
        if item[field] and item.level <= level and (not best or item.level > best.level
            or (item.level == best.level and item.count < best.count)) then
            best = item
        end
    end
    return best
end

local function ShowCheck()
    local level = Safe(UnitLevel("player"))
    if not level then
        Print("The game didn't report your level.")
        return
    end
    local items, pending = ReadBags()
    local food, drink = BestFor(items, level, "health"), BestFor(items, level, "mana")
    Print(food and string.format("Best food: %s x%d", food.link, food.count) or "No usable food in your bags.")
    Print(drink and string.format("Best drink: %s x%d", drink.link, drink.count) or "No usable drink in your bags.")
    for _, item in ipairs(items) do
        if item.level > level then
            Print(string.format("Too high for now: %s (level %d)", item.link, item.level))
        elseif item.level > 1 and level - item.level >= OUTGROWN_LEVELS then
            Print(string.format("Outgrown: %s (level %d). Eat it first, or sell it.", item.link, item.level))
        elseif not (item.health or item.mana) then
            Print(string.format("Couldn't tell what %s restores.", item.link))
        end
    end
    if pending then
        Print("Some items are still loading; try again in a moment.")
    end
    if CampfireNearby() then
        Print("A campfire is nearby: you can cook here.")
    end
end

SLASH_FOODCHECK1 = "/food"
SlashCmdList.FOODCHECK = ShowCheck
