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
                local itemID = Safe(info.itemID)
                local known = itemID and FoodCheckIDs and (FoodCheckIDs.food[itemID] or FoodCheckIDs.drink[itemID])
                if not name then
                    pending = true
                    if itemID then
                        C_Item.RequestLoadItemDataByID(itemID)
                    end
                elseif known or (classID == CLASS_CONSUMABLE and subClassID == SUBCLASS_FOOD_DRINK) then
                    local item = byLink[link]
                    if not item then
                        -- By item ID (any client language); the tooltip's English text only for items the list lacks.
                        local health, mana
                        if known then
                            health, mana = FoodCheckIDs.food[itemID] == true, FoodCheckIDs.drink[itemID] == true
                        else
                            health, mana = ReadRestores(link)
                        end
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
        -- The camp objects you could still use, and which ones a class buff of yours makes pointless.
        for _, line in ipairs(FoodCheck_CampLines and FoodCheck_CampLines() or {}) do
            Print(line)
        end
    end
end

-- The best drink in your bags for your level (for ManaFull.lua): its link and count, or nil.
function FoodCheck_BestDrink()
    local level = Safe(UnitLevel("player"))
    if not level then
        return nil
    end
    local drink = BestFor((ReadBags()), level, "mana")
    if drink then
        return drink.link, drink.count
    end
end

-- ---- Buff reminders (research\re_round3.md rank 8, opt-in) -------------------------------------------------
-- Buffs you ask to keep up (Well Fed, an elixir, a scroll) and a weapon oil, stone or poison. Each is watched by
-- spell ID (or its name, so any "Well Fed" counts), out of combat and only while auras aren't secret: a buff
-- that can't be read is "unknown", never "gone". One pop-up when it's under 3 minutes and one when it's gone
-- (also after login, for one that ran out while you were away); it re-arms once the buff is back.
local REMIND_SECONDS, CHECK_SECONDS = 180, 20
local MAIN_HAND = 0
local db -- this character's settings: { reminders = { { id, name } or { weapon = true } } }
local states = {} -- reminder key -> "ok" / "low" / "gone"
local ready = false -- set a few seconds after login, once auras and the weapon have loaded

local function AurasReadable()
    if InCombatLockdown and InCombatLockdown() then
        return false
    end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
        return ok and Safe(secret) == false
    end
    return true
end

-- Your helpful aura by spell ID or name: the aura table, false if you don't have it, nil when unreadable.
local function FindBuff(id, name)
    if not (AurasReadable() and C_UnitAuras) then
        return nil
    end
    local aura
    if id and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, found = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
        if not ok then
            return nil
        end
        aura = Safe(found)
    end
    if not aura and name and C_UnitAuras.GetAuraDataBySpellName then
        local ok, found = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
        if not ok then
            return nil
        end
        aura = Safe(found)
    end
    -- The name as typed may differ in case: look through your buffs.
    if not aura and name and C_UnitAuras.GetBuffDataByIndex then
        local wanted = name:lower()
        for index = 1, 40 do
            local ok, found = pcall(C_UnitAuras.GetBuffDataByIndex, "player", index)
            found = ok and Safe(found)
            if type(found) ~= "table" then
                break
            end
            local foundName = Safe(found.name)
            if type(foundName) == "string" and foundName:lower() == wanted then
                aura = found
                break
            end
        end
    end
    return type(aura) == "table" and aura or false
end

-- Seconds left on a temporary main-hand enchant (oil, stone, poison): a number, false if none, nil if unknown.
-- C_Item.GetWeaponEnchantInfo's timeLeft is taken to be in milliseconds like the old API (UNVERIFIED in game).
local function WeaponSecondsLeft()
    if not AurasReadable() then
        return nil
    end
    if C_Item and C_Item.GetWeaponEnchantInfo then
        local ok, list = pcall(C_Item.GetWeaponEnchantInfo, MAIN_HAND)
        if not ok or type(list) ~= "table" then
            return nil
        end
        for _, enchant in ipairs(list) do
            local has, left = Safe(enchant.hasEnchant), Safe(enchant.timeLeft)
            if has and type(left) == "number" and left > 0 then
                return left / 1000
            end
        end
        return false
    elseif GetWeaponEnchantInfo then
        local ok, has, expires = pcall(GetWeaponEnchantInfo)
        has, expires = ok and Safe(has), ok and Safe(expires)
        if not ok then
            return nil
        end
        return has and type(expires) == "number" and expires / 1000 or false
    end
    return nil
end

local function ReminderKey(entry)
    return entry.weapon and "weapon" or tostring(entry.id or entry.name)
end

local function ReminderLabel(entry)
    return entry.weapon and "Weapon oil or stone" or entry.name or ("spell " .. tostring(entry.id))
end

-- "ok", "low" (with seconds left), "gone", or nil when it can't be read now.
local function ReminderState(entry)
    local left
    if entry.weapon then
        left = WeaponSecondsLeft()
    else
        local aura = FindBuff(entry.id, entry.name)
        if aura == nil then
            return nil
        elseif aura then
            local expires = Safe(aura.expirationTime)
            left = type(expires) == "number" and expires > 0 and (expires - GetTime()) or math.huge
        else
            left = false
        end
    end
    if left == nil then
        return nil
    elseif left == false or left <= 0 then
        return "gone"
    elseif left <= REMIND_SECONDS then
        return "low", left
    end
    return "ok", left
end

local function CheckReminders()
    if not (db and ready) then
        return
    end
    for _, entry in ipairs(db.reminders) do
        local key = ReminderKey(entry)
        local state, left = ReminderState(entry)
        local before = states[key]
        if state and state ~= before then
            if state == "low" and before ~= "gone" then
                Print(string.format("%s runs out in %d min.", ReminderLabel(entry), math.max(math.ceil(left / 60), 1)))
            elseif state == "gone" then
                Print(before == nil and string.format("%s ran out while you were away.", ReminderLabel(entry))
                    or string.format("%s is gone.", ReminderLabel(entry)))
            end
            states[key] = state
        end
    end
end

local function ReminderCommand(verb, rest)
    local lower = rest:lower()
    if verb == "remind" then
        if lower == "weapon" or lower == "oil" then
            for _, entry in ipairs(db.reminders) do
                if entry.weapon then
                    Print("Already watching your weapon oil or stone.")
                    return
                end
            end
            db.reminders[#db.reminders + 1] = { weapon = true }
            states.weapon = ReminderState(db.reminders[#db.reminders])
            Print("Watching your weapon oil or stone.")
            return
        end
        local aura = FindBuff(nil, rest)
        if aura == nil then
            Print("Buffs can't be read right now; try again out of combat.")
            return
        elseif not aura then
            Print(string.format("You don't have \"%s\" on you. Type the buff's name while it's active.", rest))
            return
        end
        local id, name = Safe(aura.spellId), Safe(aura.name) or rest
        for _, entry in ipairs(db.reminders) do
            if (id and entry.id == id) or (entry.name and entry.name:lower() == tostring(name):lower()) then
                Print("Already watching " .. name .. ".")
                return
            end
        end
        db.reminders[#db.reminders + 1] = { id = id, name = name }
        states[ReminderKey(db.reminders[#db.reminders])] = ReminderState(db.reminders[#db.reminders])
        Print("Watching " .. name .. ".")
        return
    end
    for index, entry in ipairs(db.reminders) do
        if (entry.weapon and (lower == "weapon" or lower == "oil")) or (entry.name and entry.name:lower() == lower) then
            table.remove(db.reminders, index)
            states[ReminderKey(entry)] = nil
            Print("Stopped watching " .. ReminderLabel(entry) .. ".")
            return
        end
    end
    Print(string.format("Not watching \"%s\".", rest))
end

local function ShowReminders()
    if not db or #db.reminders == 0 then
        Print("|cff999999Buff reminders: none. Type remind <buff you have now> or remind weapon.|r")
        return
    end
    for _, entry in ipairs(db.reminders) do
        local state, left = ReminderState(entry)
        local text = state == nil and "can't be read now" or state == "gone" and "gone"
            or (left == math.huge and "on") or string.format("%d min left", math.ceil(left / 60))
        Print(string.format("Reminder: %s, %s", ReminderLabel(entry), text))
    end
end

SLASH_FOODCHECK1 = "/food"
SlashCmdList.FOODCHECK = function(message)
    local verb, rest = (message or ""):match("^%s*(%a+)%s+(.-)%s*$")
    verb = verb and verb:lower()
    if db and (verb == "remind" or verb == "stop") and rest ~= "" then
        ReminderCommand(verb, rest)
    end
    ShowCheck()
    ShowReminders()
end

-- (Loaded without a frame API in some tests: then only the page works.)
local events = CreateFrame and CreateFrame("Frame") or { RegisterEvent = function() end, SetScript = function() end }
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
if events.RegisterUnitEvent then
    events:RegisterUnitEvent("UNIT_AURA", "player")
else
    events:RegisterEvent("UNIT_AURA")
end
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        FoodCheckDB = type(FoodCheckDB) == "table" and FoodCheckDB or {}
        local key = (ForeverCharacterKey and ForeverCharacterKey())
            or ((Safe(UnitName("player")) or "Unknown") .. "-" .. (Safe(GetRealmName()) or "Unknown"))
        FoodCheckDB[key] = type(FoodCheckDB[key]) == "table" and FoodCheckDB[key] or {}
        db = FoodCheckDB[key]
        db.reminders = type(db.reminders) == "table" and db.reminders or {}
        -- A few seconds after login, so auras and the weapon have loaded; then every 20 s for time left.
        if C_Timer and C_Timer.After then
            C_Timer.After(5, function()
                ready = true
                CheckReminders()
            end)
        else
            ready = true
        end
        if C_Timer and C_Timer.NewTicker then
            C_Timer.NewTicker(CHECK_SECONDS, CheckReminders)
        end
    elseif event == "UNIT_AURA" and Safe(unit) ~= "player" then
        return
    else
        CheckReminders()
    end
end)