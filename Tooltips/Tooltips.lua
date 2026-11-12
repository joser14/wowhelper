-- Adds a few lines of information to item and unit tooltips. It only appends lines through
-- Blizzard's tooltip post-call hook; it never shows, hides, moves, or clears a tooltip.

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


local SECONDS_PER_HOUR, SECONDS_PER_DAY = 3600, 86400
local QUEST_ITEM_CLASS = 12
local LABEL_R, LABEL_G, LABEL_B = 0.6, 0.6, 0.6
local VALUE_R, VALUE_G, VALUE_B = 1, 1, 1

-- The switchable lines, in the order the page lists them.
local LINES = {
    { name = "vendor", label = "Vendor price", default = true,
      about = "What a merchant pays for the item, and for the whole stack when the tooltip shows one." },
    { name = "auction", label = "Auction price", default = true,
      about = "The cheapest auction price you've seen on this realm and faction (from PriceMemory), and for the whole stack. Not shown on bound items; marked (old) after 10 days." },
    { name = "count", label = "Counts", default = true,
      about = "How many you have on every character, in bags, bank, and worn (from ItemFinder)." },
    { name = "profession", label = "Profession guide", default = true,
      about = "Which profession guide steps use the item as a material." },
    { name = "drop", label = "Dungeon drop", default = true,
      about = "Which dungeon boss drops the item, or which dungeon quest gives it (from the Dungeons guide)." },
    { name = "wish", label = "Wish list", default = true,
      about = "When the item is on your Dungeons wish list: which boss drops it, in which dungeon." },
    { name = "yourdrops", label = "Your drops", default = true,
      about = "How often the item dropped from corpses you looted yourself, once you've looted at least 10 of that creature. Only counts what you open; never loots anything." },
    { name = "questitem", label = "Quest item", default = true,
      about = "Which quest in your log still needs the item, with your count, unless the game already says so." },
    { name = "giver", label = "Quest giver", default = true,
      about = "Leveling guide quests a creature starts or takes back that you haven't done yet; (ready) when you can turn it in. Not shown inside dungeons." },
    { name = "forever", label = "New in Forever", default = true,
      about = "Tags quests Forever added (not in Classic or later Classic releases), on quest tooltips and on the quest giver lines." },
    { name = "upgrade", label = "Upgrade", default = false,
      about = "Upgrade for you, from ItemAdvisor, when ItemAdvisor isn't already showing its own verdict." },
    { name = "id", label = "Item ID and level", default = false,
      about = "The item's ID number and item level." },
    { name = "npc", label = "NPC ID", default = false,
      about = "The ID number of the creature under your mouse. Not shown inside dungeons." },
}
-- Round 6 #19, "New in Forever": forever-db marks no quest as new, so the quest ID decides. forever-db's IDs
-- 65593-84402 are later-Classic quests (Love is in the Air, Season of Discovery), nothing sits between 84403
-- and 86573, and Forever's own quests start at 86574. QuestCheck and QuestTracker use the same rule.
local FOREVER_FIRST_ID = 85000
local FOREVER_TEXT, FOREVER_TAG = "New in Forever", " |cffc58cff(new in Forever)|r"
local FOREVER_R, FOREVER_G, FOREVER_B = 0.77, 0.55, 1
local MAX_LIST = 3
local MORE_R, MORE_G, MORE_B = 0.6, 0.6, 0.6
local LINE_BY_NAME = {}
for _, line in ipairs(LINES) do
    LINE_BY_NAME[line.name] = line
end

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("Tooltips", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

-- Only choices you made are saved, so a line you never touched follows its default.
local function IsOn(name)
    local db = TooltipsDB
    if type(db) == "table" and type(db[name]) == "boolean" then
        return db[name]
    end
    return LINE_BY_NAME[name].default
end

----------------------------------------------------------------------------------------------------
-- Formatting

local function PlainMoney(copper)
    local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if gold > 0 then
        parts[#parts + 1] = "|cffffd700" .. gold .. "g|r"
    end
    if silver > 0 then
        parts[#parts + 1] = "|cffc7c7cf" .. silver .. "s|r"
    end
    if rest > 0 or #parts == 0 then
        parts[#parts + 1] = "|cffeda55f" .. rest .. "c|r"
    end
    return table.concat(parts, " ")
end

local function Money(copper)
    copper = math.floor(copper + 0.5)
    local format = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString
    if type(format) == "function" then
        local ok, text = pcall(format, copper)
        text = ok and Safe(text)
        if type(text) == "string" and text ~= "" then
            return text
        end
    end
    return PlainMoney(copper)
end

local function Age(seconds)
    if seconds < SECONDS_PER_HOUR then
        return "under an hour ago"
    elseif seconds < SECONDS_PER_DAY then
        return string.format("%dh ago", math.floor(seconds / SECONDS_PER_HOUR))
    end
    local days = math.floor(seconds / SECONDS_PER_DAY)
    return days == 1 and "1 day ago" or string.format("%d days ago", days)
end

local function AddPair(tooltip, label, value)
    tooltip:AddDoubleLine(label, value, LABEL_R, LABEL_G, LABEL_B, VALUE_R, VALUE_G, VALUE_B)
end

----------------------------------------------------------------------------------------------------
-- Item facts, looked up once per item ID

local itemCache = {}

local function ItemFacts(id)
    local facts = itemCache[id]
    if facts then
        return facts
    end
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if type(getInfo) ~= "function" then
        return nil
    end
    local ok, name, _, _, level, _, _, _, _, _, _, sellPrice, classID, _, bindType = pcall(getInfo, id)
    if not ok then
        return nil
    end
    name, level, sellPrice, classID, bindType = Safe(name), Safe(level), Safe(sellPrice), Safe(classID), Safe(bindType)
    -- An item the game hasn't loaded yet returns nothing; ask again next time instead of remembering that.
    if type(name) ~= "string" or name == "" then
        return nil
    end
    facts = {
        name = name,
        level = type(level) == "number" and level or nil,
        sellPrice = type(sellPrice) == "number" and sellPrice or nil,
        classID = type(classID) == "number" and classID or nil,
        bindType = type(bindType) == "number" and bindType or nil,
    }
    itemCache[id] = facts
    return facts
end

-- Where the game filled this tooltip from: the documented C_TooltipInfo getter name and its arguments
-- (read only). nil when the tooltip doesn't say.
local function Source(tooltip)
    local getInfo = tooltip.GetProcessingTooltipInfo or tooltip.GetPrimaryTooltipInfo
    local info = type(getInfo) == "function" and getInfo(tooltip)
    if type(info) ~= "table" or type(info.getterArgs) ~= "table" then
        return nil
    end
    return Safe(info.getterName), Safe(info.getterArgs[1]), Safe(info.getterArgs[2])
end

-- The n-th value a function returns, or nil when it is missing or fails.
local function Pick(position, fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local results = { pcall(fn, ...) }
    if not results[1] then
        return nil
    end
    return Safe(results[position + 1])
end

-- How many are in the slot this tooltip shows. Unknown sources give nil, and the stack part is left out.
-- Mail, trade and loot-roll counts come from the game's older global functions; they are only used
-- when they exist (they aren't in this client's API documentation).
local function StackCount(tooltip, data)
    local count = Safe(data.stackCount)
    if type(count) == "number" then
        return count
    end
    local getter, a, b = Source(tooltip)
    if not getter then
        return nil
    end
    if getter == "GetBagItem" and type(a) == "number" and type(b) == "number" and C_Container then
        local item = C_Container.GetContainerItemInfo(a, b)
        count = item and Safe(item.stackCount)
    elseif getter == "GetLootItem" and type(a) == "number" and GetLootSlotInfo then
        count = Safe(select(3, GetLootSlotInfo(a)))
    elseif getter == "GetInventoryItem" and type(a) == "string" and type(b) == "number" and GetInventoryItemCount then
        count = Safe(GetInventoryItemCount(a, b))
    elseif getter == "GetBuybackItem" and type(a) == "number" and GetBuybackItemInfo then
        count = Safe(select(4, GetBuybackItemInfo(a)))
    elseif getter == "GetMerchantItem" and type(a) == "number" and C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        -- How many one purchase gives you.
        local ok, item = pcall(C_MerchantFrame.GetItemInfo, a)
        item = ok and Safe(item)
        count = type(item) == "table" and Safe(item.stackCount) or nil
    elseif getter == "GetInboxItem" and type(a) == "number" then
        count = Pick(4, GetInboxItem, a, type(b) == "number" and b or 1)
    elseif getter == "GetSendMailItem" and type(a) == "number" then
        count = Pick(4, GetSendMailItem, a)
    elseif getter == "GetTradePlayerItem" and type(a) == "number" then
        count = Pick(3, GetTradePlayerItemInfo, a)
    elseif getter == "GetTradeTargetItem" and type(a) == "number" then
        count = Pick(3, GetTradeTargetItemInfo, a)
    elseif getter == "GetLootRollItem" and type(a) == "number" then
        count = Pick(3, GetLootRollItemInfo, a)
    end
    return type(count) == "number" and count > 0 and count or nil
end

-- Item binds that can never go on the auction house (Enum.ItemBind): on pickup, quest, account-bound.
local NEVER_TRADED = { [1] = true, [4] = true, [7] = true, [8] = true }

-- A copy that can't be auctioned: bind-on-pickup and quest items, a bag copy the game marks bound, or
-- something you're wearing. A bind-on-equip item still on the market is fine.
local function IsBound(tooltip, facts)
    if facts and facts.bindType and NEVER_TRADED[facts.bindType] then
        return true
    end
    local getter, a, b = Source(tooltip)
    if getter == "GetBagItem" and type(a) == "number" and type(b) == "number" and C_Container then
        local item = C_Container.GetContainerItemInfo(a, b)
        return type(item) == "table" and Safe(item.isBound) == true
    elseif getter == "GetInventoryItem" and a == "player" and type(b) == "number" then
        -- Equipment slots 1-19; worn gear is always bound.
        return b >= 1 and b <= 19
    elseif getter == "GetLootRollItem" and type(a) == "number" then
        return Pick(5, GetLootRollItemInfo, a) == true
    end
    return false
end

-- The game already printing a sell price on this tooltip, so ours would only repeat it.
local function GameShowsSellPrice(data)
    local sellType = Enum and Enum.TooltipDataLineType and Safe(Enum.TooltipDataLineType.SellPrice)
    local lines = Safe(data.lines)
    if type(sellType) ~= "number" or type(lines) ~= "table" then
        return false
    end
    for _, line in ipairs(lines) do
        if type(line) == "table" and Safe(line.type) == sellType then
            return true
        end
    end
    return false
end

-- PriceMemory and ItemFinder can add their own lines; this reads what's already on the tooltip so
-- the same fact isn't shown twice.
-- The left-hand text of every line already on the tooltip (secret ones left out).
local function ExistingTexts(tooltip)
    local texts = {}
    local name = tooltip.GetName and Safe(tooltip:GetName())
    local count = tooltip.NumLines and Safe(tooltip:NumLines())
    if type(name) ~= "string" or type(count) ~= "number" then
        return texts
    end
    for index = 1, count do
        local fontString = _G[name .. "TextLeft" .. index]
        local text = fontString and fontString.GetText and Safe(fontString:GetText())
        if type(text) == "string" then
            texts[#texts + 1] = text
        end
    end
    return texts
end

-- ItemAdvisor's own tooltip line reads "<VERDICT>: <reason>" (ItemAdvisor.lua OnTooltip).
local ITEMADVISOR_VERDICTS = { EQUIP = true, KEEP = true, SELL = true, AUCTION = true, DISENCHANT = true, CHECK = true, EQUIPPED = true }

local function LinesAlreadyThere(texts)
    local found = {}
    for _, text in ipairs(texts) do
        if text:find("^Auction, seen ") then
            found.auction = true
        elseif text:find("^Owned: ") then
            found.count = true
        else
            local verdict = text:match("^(%u+): ")
            if verdict and ITEMADVISOR_VERDICTS[verdict] then
                found.advisor = true
            end
        end
    end
    return found
end

local function MentionedIn(texts, title)
    for _, text in ipairs(texts) do
        if text:find(title, 1, true) then
            return true
        end
    end
    return false
end

----------------------------------------------------------------------------------------------------
-- The lines

local function AddVendorLine(tooltip, data, facts)
    local price = facts.sellPrice
    if not price or GameShowsSellPrice(data) then
        return
    end
    if price <= 0 then
        -- Quest items can't be sold either, but everyone knows that; saying so would be noise.
        if facts.classID ~= QUEST_ITEM_CLASS then
            tooltip:AddLine("No sell price", LABEL_R, LABEL_G, LABEL_B)
        end
        return
    end
    local text = Money(price)
    local count = StackCount(tooltip, data)
    if count and count > 1 then
        text = text .. "  |cff999999x" .. count .. ":|r " .. Money(price * count)
    end
    AddPair(tooltip, "Sells for", text)
end

-- Only used when PriceMemory isn't loaded: the same "Realm-Faction" key it files prices under.
local function ScopeKey()
    local realm = GetRealmName and Safe(GetRealmName())
    local faction = UnitFactionGroup and Safe(UnitFactionGroup("player"))
    if type(realm) == "string" and realm ~= "" and type(faction) == "string" and faction ~= "" then
        return realm .. "-" .. faction
    end
end

local function ValidPrice(entry)
    return type(entry) == "table" and type(entry.price) == "number" and entry.price > 0 and type(entry.seen) == "number"
end

local STALE_SECONDS = 10 * SECONDS_PER_DAY

-- { price, seen, legacy, stale } from PriceMemory's shared lookup, or read straight from its saved
-- data when that lookup isn't there.
local function AuctionRecord(id)
    if type(PriceMemory_Get) == "function" then
        local ok, record = pcall(PriceMemory_Get, id)
        if ok and type(record) == "table" and ValidPrice(record) then
            return record
        end
        return nil
    end
    local db = PriceMemoryDB
    if type(db) ~= "table" then
        return nil
    end
    local scope = ScopeKey()
    local prices = scope and db[scope]
    local entry = type(prices) == "table" and prices[id]
    local legacy = false
    -- Older saves sit directly under the item ID, with no realm or faction.
    if not ValidPrice(entry) then
        entry, legacy = db[id], true
    end
    if not ValidPrice(entry) then
        return nil
    end
    local now = time and Safe(time())
    local stale = type(now) == "number" and now - entry.seen > STALE_SECONDS
    return { price = entry.price, seen = entry.seen, legacy = legacy, stale = stale }
end

local function AddAuctionLine(tooltip, data, id, facts)
    -- A bound copy can't be sold there, so a price would only mislead.
    if IsBound(tooltip, facts) then
        return
    end
    local record = AuctionRecord(id)
    if not record then
        return
    end
    local now = time and Safe(time())
    local text = Money(record.price)
    if type(now) == "number" then
        text = text .. " |cff999999(" .. Age(math.max(now - record.seen, 0)) .. ")|r"
    end
    if record.legacy then
        text = text .. " |cff999999(older save)|r"
    end
    if record.stale then
        text = text .. " |cffff9933(old)|r"
    end
    local count = StackCount(tooltip, data)
    if count and count > 1 then
        text = text .. "  |cff999999x" .. count .. ":|r " .. Money(record.price * count)
    end
    AddPair(tooltip, "Auction", text)
end

-- ItemFinder saves the character's name in each record; older records only have the "Name-Realm" key.
local function ShortName(characterKey, record)
    if type(record) == "table" and type(record.charName) == "string" and record.charName ~= "" then
        return record.charName
    end
    return characterKey:match("^[^-]+") or characterKey
end

local function MyKey()
    return ForeverCharacterKey()
end

local function CountIn(places, name)
    local value = type(places) == "table" and places[name]
    return type(value) == "number" and value or 0
end

-- ItemFinder's places (round 4: records keyed by item ID under record.items) and their labels, in order.
-- Old records keyed by name (record.bags/bank/gear) are still read until ItemFinder rescans them.
local COUNT_PLACES = { { "bags", "bags", "bags" }, { "keys", "keyring" }, { "bank", "bank", "bank" }, { "gear", "worn", "gear" }, { "mail", "mail" } }

local function CountsOn(record, itemID, itemName)
    local counts, sum = {}, 0
    local items = type(record.items) == "table" and record.items or nil
    for _, place in ipairs(COUNT_PLACES) do
        local n = (items and CountIn(items[place[1]], itemID) or 0) + (place[3] and CountIn(record[place[3]], itemName) or 0)
        if n > 0 then
            counts[#counts + 1] = n .. " " .. place[2]
            sum = sum + n
        end
    end
    return counts, sum
end

local function AddCountLine(tooltip, itemName, itemID)
    local db = ItemFinderDB
    if type(db) ~= "table" then
        return
    end
    local myKey = MyKey()
    -- ItemFinder moves the record to the new key at login; until it has (or without it), the old key is ours.
    if db[myKey] == nil then
        myKey = ForeverCharacterLegacyKey()
    end
    local myFaction = Safe(UnitFactionGroup and UnitFactionGroup("player"))
    local total, mine, others = 0, nil, {}
    for key, record in pairs(db) do
        if type(key) == "string" and type(record) == "table" then
            local where, sum = CountsOn(record, itemID, itemName)
            if sum > 0 then
                total = total + sum
                if key == myKey then
                    mine = ShortName(key, record) .. " " .. table.concat(where, ", ")
                else
                    local text = ShortName(key, record) .. " " .. sum
                    -- Another faction's character can't hand it over directly: say so, dimmed.
                    if type(record.faction) == "string" and myFaction and record.faction ~= myFaction then
                        text = "|cff666666" .. text .. " (" .. record.faction .. ")|r|cff999999"
                    end
                    others[#others + 1] = { sort = ShortName(key, record), text = text }
                end
            end
        end
    end
    if total == 0 then
        return
    end
    table.sort(others, function(a, b) return a.sort < b.sort end)
    local parts = {}
    if mine then
        parts[1] = mine
    end
    for _, other in ipairs(others) do
        parts[#parts + 1] = other.text
    end
    AddPair(tooltip, "You have", total .. " |cff999999(" .. table.concat(parts, "; ") .. ")|r")
end

-- Round 4 R21: Forever's Waylaid Crates (items 248682-248713) list their bundles as "- 20 Soul Dust" lines under
-- "Use:" (format checked in game by Alts Forever, MIT; idea only). Each bundle gets the counts from ItemFinder on
-- the characters that can mail it to you (same realm and faction; old records without either count too).
local function IsCrate(id, facts)
    return (id >= 248682 and id <= 248713) or (facts and type(facts.name) == "string" and facts.name:find("^Waylaid ") ~= nil)
end

local function CountByName(record, name)
    local id
    for itemID, itemName in pairs(type(record.names) == "table" and record.names or {}) do
        if itemName == name then
            id = itemID
            break
        end
    end
    local _, sum = CountsOn(record, id, name)
    return sum
end

local function AddCrateLines(tooltip, data, id, facts)
    if not IsCrate(id, facts) or type(data.lines) ~= "table" or type(ItemFinderDB) ~= "table" then
        return
    end
    local myKey = MyKey()
    if ItemFinderDB[myKey] == nil then
        myKey = ForeverCharacterLegacyKey()
    end
    local myFaction = Safe(UnitFactionGroup and UnitFactionGroup("player"))
    local myRealm = Safe(GetRealmName and GetRealmName())
    local afterUse = false
    for _, line in ipairs(data.lines) do
        local text = type(line) == "table" and Safe(line.leftText)
        if type(text) == "string" then
            if text:find("^Use:") then
                afterUse = true
            end
            local need, material = text:match("^%s*%-%s*(%d+)%s+(.-)%s*$")
            need = tonumber(need)
            if afterUse and need and material ~= "" then
                local mine, others, total = nil, {}, 0
                for key, record in pairs(ItemFinderDB) do
                    local mailable = type(record) == "table"
                        and not (type(record.faction) == "string" and myFaction and record.faction ~= myFaction)
                        and not (type(record.realm) == "string" and myRealm and record.realm ~= myRealm)
                    local count = mailable and CountByName(record, material) or 0
                    if count > 0 then
                        total = total + count
                        if key == myKey then
                            mine = "you " .. count
                        else
                            others[#others + 1] = ShortName(key, record) .. " " .. count
                        end
                    end
                end
                table.sort(others)
                if mine then
                    table.insert(others, 1, mine)
                end
                local verdict, r, g, b
                if total == 0 then
                    verdict, r, g, b = "none", 0.6, 0.6, 0.6
                elseif total >= need then
                    verdict, r, g, b = table.concat(others, ", ") .. " - enough", 0.2, 1, 0.2
                else
                    verdict, r, g, b = table.concat(others, ", ") .. " - " .. (need - total) .. " short", 1, 0.6, 0.2
                end
                tooltip:AddLine(material .. " " .. need .. ": " .. verdict, r, g, b)
            end
        end
    end
end

-- Which profession guide steps use each item, worked out once per guide table.
local professionIndex, indexedGuide

local function StepRange(step, number)
    local low = Safe(step.from) or Safe(step.min) or Safe(step.start)
    local high = Safe(step.to) or Safe(step.max) or Safe(step.stop)
    if low and high then
        return low .. "-" .. high
    end
    local range = Safe(step.range) or Safe(step.skill)
    if range then
        return tostring(range)
    end
    return "#" .. number
end

local function BuildProfessionIndex(guide)
    local index = {}
    for key, profession in pairs(guide) do
        if type(profession) == "table" and type(profession.steps) == "table" then
            local title = Safe(profession.name) or Safe(profession.label) or Safe(profession.profession)
            if type(title) ~= "string" and type(key) == "number" and C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName then
                local ok, shown = pcall(C_TradeSkillUI.GetTradeSkillDisplayName, key)
                title = ok and Safe(shown) or nil
            end
            if type(title) ~= "string" or title == "" then
                title = type(key) == "string" and key or "Profession"
            end
            for number, step in ipairs(profession.steps) do
                if type(step) == "table" and type(step.mats) == "table" then
                    local size = #step.mats
                    for matKey, mat in pairs(step.mats) do
                        local id
                        if type(mat) == "table" then
                            id = Safe(mat.itemID) or Safe(mat.id)
                        elseif type(mat) == "number" then
                            -- A plain list holds item IDs; a keyed table maps item ID to amount.
                            id = (type(matKey) == "number" and matKey >= 1 and matKey <= size) and mat or matKey
                        end
                        if type(id) == "number" then
                            local uses = index[id] or {}
                            uses[title .. " guide step " .. StepRange(step, number)] = true
                            index[id] = uses
                        end
                    end
                end
            end
        end
    end
    -- Saved tables have no order; sort so the same item always reads the same.
    for id, uses in pairs(index) do
        local list = {}
        for text in pairs(uses) do
            list[#list + 1] = text
        end
        table.sort(list)
        index[id] = list
    end
    return index
end

local function AddProfessionLine(tooltip, id)
    local guide = ProfessionGuideData
    if type(guide) ~= "table" then
        return
    end
    if guide ~= indexedGuide or not professionIndex then
        indexedGuide = guide
        local ok, index = pcall(BuildProfessionIndex, guide)
        professionIndex = ok and index or {}
    end
    local uses = professionIndex[id]
    if not uses or #uses == 0 then
        return
    end
    local text = uses[1]
    if #uses == 2 then
        text = text .. ", " .. uses[2]
    elseif #uses > 2 then
        text = text .. ", " .. uses[2] .. string.format(" |cff999999+%d more|r", #uses - 2)
    end
    AddPair(tooltip, "Needed", text)
end

-- Dungeon drops: item ID -> { boss, dungeon, quest } from the Dungeons guide, worked out once per table.
-- Its loot entries are { itemID, name, boss, slot }; a boss text "quest: <title>" is a quest reward.
local dropIndex, indexedDungeons

local function BuildDropIndex(dungeons)
    local index = {}
    for _, dungeon in ipairs(dungeons) do
        local dungeonName = type(dungeon) == "table" and Safe(dungeon.name)
        if type(dungeonName) == "string" and type(dungeon.loot) == "table" then
            for _, entry in ipairs(dungeon.loot) do
                if type(entry) == "table" then
                    local id = Safe(entry[1]) or Safe(entry.itemID)
                    local boss = Safe(entry[3]) or Safe(entry.boss)
                    if type(id) == "number" and type(boss) == "string" and boss ~= "" then
                        local quest = boss:match("^quest:%s*(.+)$")
                        local list = index[id] or {}
                        local low, high = Safe(dungeon.minLevel), Safe(dungeon.maxLevel)
                        list[#list + 1] = {
                            boss = quest or boss, dungeon = dungeonName, quest = quest ~= nil,
                            trash = not quest and boss:lower():find("trash", 1, true) ~= nil,
                            horde = dungeon.horde == true,
                            low = type(low) == "number" and low or nil, high = type(high) == "number" and high or nil,
                        }
                        index[id] = list
                    end
                end
            end
        end
    end
    return index
end

local function AddDropLine(tooltip, id)
    local dungeons = DungeonsData
    if type(dungeons) ~= "table" then
        return
    end
    if dungeons ~= indexedDungeons or not dropIndex then
        indexedDungeons = dungeons
        local ok, index = pcall(BuildDropIndex, dungeons)
        dropIndex = ok and index or {}
    end
    local sources = dropIndex[id]
    if not sources or #sources == 0 then
        return
    end
    -- Round 4 R12 (ranking idea from DungeonJournal, no code): boss drop 1, trash 2, quest reward of your own
    -- faction 3 (DungeonsData's quests are Alliance's, Horde's in a dungeon marked horde), other quest 4; then the
    -- dungeon whose level range holds your level; then the guide's order.
    local level = Safe(UnitLevel and UnitLevel("player"))
    local horde = Safe(UnitFactionGroup and UnitFactionGroup("player")) == "Horde"
    local function Rank(source)
        if source.quest then
            return source.horde == horde and 3 or 4
        end
        return source.trash and 2 or 1
    end
    local function Fits(source)
        return type(level) == "number" and source.low and source.high and level >= source.low and level <= source.high and 0 or 1
    end
    local first, dungeons = nil, {}
    for _, source in ipairs(sources) do
        dungeons[source.dungeon] = true
        if not first or Rank(source) < Rank(first) or (Rank(source) == Rank(first) and Fits(source) < Fits(first)) then
            first = source
        end
    end
    local several = next(dungeons, next(dungeons)) ~= nil
    local more = ""
    if #sources > 1 then
        more = string.format(" |cff999999+%d more%s|r", #sources - 1, several and ", several dungeons" or "")
    end
    local range = first.low and first.high and string.format("lvl %d-%d", first.low, first.high) or nil
    if first.quest then
        AddPair(tooltip, "Quest reward", first.boss .. " (" .. first.dungeon .. (range and (", " .. range) or "") .. ")" .. more)
    else
        AddPair(tooltip, "Drops from", first.boss .. " in " .. first.dungeon .. (range and (" (" .. range .. ")") or "") .. more)
    end
end

-- Your quest log, read once after each QUEST_LOG_UPDATE (the next tooltip that needs it rebuilds it).
local questLog, questLogDirty = nil, true

local function ObjectiveName(text)
    text = text:gsub("%s*:%s*%d+%s*/%s*%d+%s*$", "")
    text = text:gsub("^%d+%s*/%s*%d+%s+", "")
    text = text:gsub("%s+$", ""):gsub("^%s+", "")
    return text
end

local function ReadQuestLog()
    local log = { byTitle = {}, objectives = {} }
    local api = C_QuestLog
    if type(api) ~= "table" or type(api.GetNumQuestLogEntries) ~= "function" or type(api.GetInfo) ~= "function" then
        return log
    end
    local ok, count = pcall(api.GetNumQuestLogEntries)
    count = ok and Safe(count)
    if type(count) ~= "number" then
        return log
    end
    for index = 1, math.min(count, 100) do
        local got, info = pcall(api.GetInfo, index)
        info = got and Safe(info)
        if type(info) == "table" and Safe(info.isHeader) ~= true then
            local title, questID = Safe(info.title), Safe(info.questID)
            if type(title) == "string" and title ~= "" then
                local complete = Safe(info.isComplete)
                if type(questID) == "number" and type(api.IsComplete) == "function" then
                    local done, value = pcall(api.IsComplete, questID)
                    if done and Safe(value) ~= nil then
                        complete = Safe(value)
                    end
                end
                log.byTitle[title] = { questID = questID, complete = complete == true or complete == 1 }
                if type(questID) == "number" and type(api.GetQuestObjectives) == "function" then
                    local fine, objectives = pcall(api.GetQuestObjectives, questID)
                    objectives = fine and Safe(objectives)
                    if type(objectives) == "table" then
                        for _, objective in ipairs(objectives) do
                            local text = type(objective) == "table" and Safe(objective.text)
                            if type(text) == "string" and text ~= "" then
                                local have, need = Safe(objective.numFulfilled), Safe(objective.numRequired)
                                if type(have) ~= "number" or type(need) ~= "number" then
                                    local a, b = text:match("(%d+)%s*/%s*(%d+)")
                                    have, need = tonumber(a), tonumber(b)
                                end
                                log.objectives[#log.objectives + 1] = {
                                    title = title,
                                    name = ObjectiveName(text):lower(),
                                    isItem = Safe(objective.type) == "item",
                                    finished = Safe(objective.finished) == true or (have and need and have >= need) or false,
                                    have = have, need = need,
                                }
                            end
                        end
                    end
                end
            end
        end
    end
    return log
end

local function QuestLog()
    if questLogDirty or not questLog then
        questLogDirty = false
        local ok, log = pcall(ReadQuestLog)
        questLog = ok and log or { byTitle = {}, objectives = {} }
    end
    return questLog
end

-- "+N more" under a capped list.
local function AddCapped(tooltip, rows)
    for index = 1, math.min(#rows, MAX_LIST) do
        local row = rows[index]
        tooltip:AddLine(row.text, row.r, row.g, row.b)
    end
    if #rows > MAX_LIST then
        tooltip:AddLine(string.format("+%d more", #rows - MAX_LIST), MORE_R, MORE_G, MORE_B)
    end
end

local function AddQuestItemLine(tooltip, itemName, texts)
    local name = itemName:lower()
    local rows, seen = {}, {}
    for _, objective in ipairs(QuestLog().objectives) do
        -- With a count stripped the name is exact ("Wolf Meat" isn't "Tender Wolf Meat"); only text with
        -- no count to strip is matched loosely (ItemAdvisor's rule too).
        local matches = objective.name == name
            or (objective.isItem and not objective.need and objective.name:find(name, 1, true) ~= nil)
        if matches and not objective.finished and not seen[objective.title] and not MentionedIn(texts, objective.title) then
            seen[objective.title] = true
            local text = "Needed for: " .. objective.title
            if objective.have and objective.need then
                text = text .. string.format(" (%d/%d)", objective.have, objective.need)
            end
            rows[#rows + 1] = { text = text, r = 1, g = 0.82, b = 0 }
        end
    end
    AddCapped(tooltip, rows)
end

local function AddUpgradeLine(tooltip, already)
    local check = ItemAdvisor_IsUpgrade
    if type(check) ~= "function" or already.advisor or not (TooltipUtil and TooltipUtil.GetDisplayedItem) then
        return
    end
    local _, link = TooltipUtil.GetDisplayedItem(tooltip)
    link = Safe(link)
    if type(link) ~= "string" then
        return
    end
    local ok, upgrade = pcall(check, link)
    if ok and Safe(upgrade) == true then
        tooltip:AddLine("Upgrade for you", 0.2, 1, 0.2)
    end
end

-- Quest givers from the leveling guide: cleaned NPC name -> steps, worked out once per route table.
-- A route's npc text can carry notes: "Shanda (in Aldrassil)", "Arbal, Grove of the Ancients",
-- "Buzzbox 323, near the bridge", "<Title>" - only the name before them is kept.
local giverIndex, indexedRoutes

local function CleanName(text)
    text = text:gsub("<[^>]*>", ""):gsub("%b()", "")
    -- Coordinates ("at 44.9, 35.6", "42.1,65.3") have decimals, unlike names such as "Buzzbox 323".
    text = text:gsub("%s+at%s+%d+%.%d+.*$", ""):gsub("%s+%d+%.%d+%s*,?%s*%d+%.%d+.*$", "")
    text = text:match("^[^,;]*") or ""
    text = text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    return text:lower()
end

local function BuildGiverIndex(routes)
    local index, seenRoute, seenStep = {}, {}, {}
    local chains = type(routes.chains) == "table" and routes.chains or {}
    for _, chain in pairs(chains) do
        if type(chain) == "table" then
            for _, route in ipairs(chain) do
                if type(route) == "table" and not seenRoute[route] and type(route.steps) == "table" then
                    seenRoute[route] = true
                    for _, step in ipairs(route.steps) do
                        local kind = type(step) == "table" and step.t
                        if (kind == "accept" or kind == "turnin") and type(step.q) == "string" and type(step.npc) == "string" then
                            local name = CleanName(step.npc)
                            local part = tonumber(step.part) or 1
                            local key = name .. "|" .. kind .. "|" .. step.q .. "|" .. part
                            if name ~= "" and not seenStep[key] then
                                seenStep[key] = true
                                local list = index[name] or {}
                                list[#list + 1] = { kind = kind, q = step.q, part = part }
                                index[name] = list
                            end
                        end
                    end
                end
            end
        end
    end
    return index
end

local function RealTitle(title)
    local data = LevelGuideQuestIDs
    local renamed = type(data) == "table" and type(data.renamed) == "table" and data.renamed[title]
    return type(renamed) == "string" and renamed or title
end

-- True only when the game says this part of the quest is done; unknown counts as not done
-- (or, with unknownIs, as that).
local function QuestIDOf(title, part)
    local data = LevelGuideQuestIDs
    local ids = type(data) == "table" and type(data.ids) == "table" and (data.ids[title] or data.ids[RealTitle(title)])
    local id = type(ids) == "table" and ids[part]
    return type(id) == "number" and id or nil
end

-- " (new in Forever)" after a guide quest whose ID says so, while that line is on.
local function ForeverTag(title, part)
    local id = IsOn("forever") and QuestIDOf(title, part)
    return id and id >= FOREVER_FIRST_ID and FOREVER_TAG or ""
end

local function QuestDone(title, part, unknownIs)
    local id = QuestIDOf(title, part)
    local check = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
    if type(id) ~= "number" or type(check) ~= "function" then
        return unknownIs == true
    end
    local ok, done = pcall(check, id)
    return ok and Safe(done) == true
end

-- Part 2 of a chain isn't offered until part 1 is done (when the IDs say so).
local function Offered(step)
    return step.part <= 1 or QuestDone(step.q, step.part - 1, true)
end

local function InLog(log, title)
    return log.byTitle[title] or log.byTitle[RealTitle(title)]
end

local function AddGiverLines(tooltip, unitName)
    local routes = LevelGuideRoutes
    if type(routes) ~= "table" then
        return
    end
    if routes ~= indexedRoutes or not giverIndex then
        indexedRoutes = routes
        local ok, index = pcall(BuildGiverIndex, routes)
        giverIndex = ok and index or {}
    end
    local steps = giverIndex[CleanName(unitName)]
    if not steps then
        return
    end
    local log = QuestLog()
    -- Ready turn-ins first, then turn-ins you hold, then new quests, then turn-ins for quests you don't hold.
    local buckets, shown = { {}, {}, {}, {} }, {}
    for _, step in ipairs(steps) do
        local key = step.kind .. "|" .. step.q
        if not shown[key] and not QuestDone(step.q, step.part) then
            local held = InLog(log, step.q)
            local tag = ForeverTag(step.q, step.part)
            if step.kind == "accept" then
                if not held and Offered(step) then
                    shown[key] = true
                    table.insert(buckets[3], { text = "Starts: " .. step.q .. tag, r = 1, g = 0.82, b = 0 })
                end
            else
                shown[key] = true
                if held and held.complete then
                    table.insert(buckets[1], { text = "Turn in: " .. step.q .. " |cff33ff33(ready)|r" .. tag, r = 1, g = 0.82, b = 0 })
                elseif held then
                    table.insert(buckets[2], { text = "Turn in: " .. step.q .. tag, r = 1, g = 0.82, b = 0 })
                else
                    table.insert(buckets[4], { text = "Turn in: " .. step.q .. tag, r = 0.7, g = 0.7, b = 0.7 })
                end
            end
        end
    end
    local rows = {}
    for _, bucket in ipairs(buckets) do
        for _, row in ipairs(bucket) do
            rows[#rows + 1] = row
        end
    end
    AddCapped(tooltip, rows)
end

-- Inside a dungeon or raid nearly every unit value is secret; unit lines stay out of there entirely.
-- An answer we can't read counts as inside.
local function InInstance()
    if type(IsInInstance) ~= "function" then
        return false
    end
    local ok, inside = pcall(IsInInstance)
    if not ok then
        return false
    end
    if issecretvalue and issecretvalue(inside) then
        return true
    end
    return inside == true or inside == 1
end

-- True when a line starting with prefix is already on the tooltip (another refresh, another helper).
local function AlreadyHas(texts, prefix)
    for _, text in ipairs(texts) do
        if text:sub(1, #prefix) == prefix then
            return true
        end
    end
    return false
end

-- Round 5 #7, Tooltips side: "On your wish list: <boss>, <dungeon>" from Dungeons_IsWished (Dungeons owns the list).
local WISH_PREFIX = "On your wish list"
local function AddWishLine(tooltip, id, texts)
    local check = Dungeons_IsWished
    if type(check) ~= "function" or AlreadyHas(texts, WISH_PREFIX) then
        return
    end
    local ok, wished, dungeon, boss = pcall(check, id)
    if not ok or Safe(wished) ~= true then
        return
    end
    local parts = {}
    for _, part in ipairs({ Safe(boss), Safe(dungeon) }) do
        if type(part) == "string" and part ~= "" then
            parts[#parts + 1] = part
        end
    end
    tooltip:AddLine(WISH_PREFIX .. (#parts > 0 and (": " .. table.concat(parts, ", ")) or ""), 1, 0.5, 1)
end

-- Round 5 #5: your own drop rates from corpses you looted (Bestiary Forever's method, GPL-3.0-or-later: each
-- corpse counted once, each item once per corpse, a rate only from YOUR_MIN corpses on). Saved in
-- TooltipsDB.looted[npcID] = { n = corpses, at = time, name = creature name, items = { [itemID] = corpses } },
-- at most MAX_CREATURES creatures and MAX_ITEMS items each. Corpses you never opened aren't counted.
local YOUR_MIN, MAX_CREATURES, MAX_ITEMS = 10, 300, 25
local YOUR_PREFIX = "Your drops: "
local yourIndex, yourIndexDirty = nil, true

local function PercentText(chance)
    if chance >= 10 then
        return string.format("%d%%", math.floor(chance + 0.5))
    end
    return string.format("%.1f%%", chance)
end

-- The saved creatures, checked; nil when there are none yet (or create to start the table).
local function LootStore(create)
    local db = TooltipsDB
    if type(db) ~= "table" then
        return nil
    end
    if type(db.looted) ~= "table" then
        if not create then
            return nil
        end
        db.looted = {}
    end
    return db.looted
end

-- item ID -> { { npc, k, n, name }, ... } for creatures looted YOUR_MIN times or more, best rate first.
local function YourIndex()
    if yourIndexDirty or not yourIndex then
        yourIndexDirty = false
        yourIndex = {}
        for npc, creature in pairs(LootStore() or {}) do
            local n = type(creature) == "table" and creature.n
            if type(npc) == "number" and type(n) == "number" and n >= YOUR_MIN and type(creature.items) == "table" then
                for item, k in pairs(creature.items) do
                    if type(item) == "number" and type(k) == "number" and k > 0 then
                        local list = yourIndex[item] or {}
                        list[#list + 1] = { npc = npc, k = math.min(k, n), n = n, name = type(creature.name) == "string" and creature.name or nil }
                        yourIndex[item] = list
                    end
                end
            end
        end
        for _, list in pairs(yourIndex) do
            table.sort(list, function(a, b)
                if a.k * b.n ~= b.k * a.n then
                    return a.k * b.n > b.k * a.n
                end
                return a.n > b.n
            end)
        end
    end
    return yourIndex
end

local function AddYourDropsLine(tooltip, id, texts)
    local list = YourIndex()[id]
    if not list or #list == 0 or AlreadyHas(texts, YOUR_PREFIX) then
        return
    end
    local best = list[1]
    local text = string.format("%s%s (%d/%d)", YOUR_PREFIX, PercentText(best.k / best.n * 100), best.k, best.n)
    if best.name then
        text = text .. " from " .. best.name
    end
    if #list > 1 then
        text = text .. string.format(" |cff999999+%d more|r", #list - 1)
    end
    tooltip:AddLine(text, 0.6, 0.8, 1)
end

-- For QuestMobs and other helpers. With an item: k, n, enough (n >= YOUR_MIN) for that creature and item.
-- Without one: a copy of { [itemID] = k }, n, enough. nil when nothing is saved or the line is switched off.
function Tooltips_YourDrops(npc, item)
    if not IsOn("yourdrops") or (ForeverHub_IsOff and ForeverHub_IsOff("Tooltips") == true) then
        return nil
    end
    local store = LootStore()
    local creature = store and type(npc) == "number" and store[npc]
    local n = type(creature) == "table" and creature.n
    if type(n) ~= "number" or n < 1 or type(creature.items) ~= "table" then
        return nil
    end
    if item == nil then
        local copy = {}
        for id, k in pairs(creature.items) do
            if type(id) == "number" and type(k) == "number" then
                copy[id] = math.min(k, n)
            end
        end
        return copy, n, n >= YOUR_MIN
    end
    local k = creature.items[item]
    return type(k) == "number" and math.min(k, n) or 0, n, n >= YOUR_MIN
end

local function ShownTooltip(tooltip)
    return tooltip ~= nil and (tooltip == GameTooltip or tooltip == ItemRefTooltip)
end

local function ItemBody(tooltip, data)
    if not ShownTooltip(tooltip) or type(data) ~= "table" then
        return
    end
    local id = Safe(data.id)
    if type(id) ~= "number" and TooltipUtil and TooltipUtil.GetDisplayedItem then
        local _, _, shownID = TooltipUtil.GetDisplayedItem(tooltip)
        id = Safe(shownID)
    end
    if type(id) ~= "number" then
        return
    end
    local facts = ItemFacts(id)
    local texts, already = {}, {}
    if IsOn("auction") or IsOn("count") or IsOn("questitem") or IsOn("upgrade") or IsOn("wish") or IsOn("yourdrops") then
        local ok, found = pcall(ExistingTexts, tooltip)
        texts = ok and found or texts
        local fine, flags = pcall(LinesAlreadyThere, texts)
        already = fine and flags or already
    end

    -- Each line on its own, so one helper's odd saved data can't take the other lines with it.
    if facts and IsOn("vendor") then
        pcall(AddVendorLine, tooltip, data, facts)
    end
    if IsOn("auction") and not already.auction then
        pcall(AddAuctionLine, tooltip, data, id, facts)
    end
    if facts and IsOn("count") and not already.count then
        pcall(AddCountLine, tooltip, facts.name, id)
    end
    if IsOn("count") then
        pcall(AddCrateLines, tooltip, data, id, facts)
    end
    if IsOn("profession") then
        pcall(AddProfessionLine, tooltip, id)
    end
    if IsOn("drop") then
        pcall(AddDropLine, tooltip, id)
    end
    if IsOn("wish") then
        pcall(AddWishLine, tooltip, id, texts)
    end
    if IsOn("yourdrops") then
        pcall(AddYourDropsLine, tooltip, id, texts)
    end
    if facts and IsOn("questitem") then
        pcall(AddQuestItemLine, tooltip, facts.name, texts)
    end
    if IsOn("upgrade") then
        pcall(AddUpgradeLine, tooltip, already)
    end
    if IsOn("id") then
        AddPair(tooltip, "Item ID", tostring(id))
        if facts and facts.level then
            AddPair(tooltip, "Item level", tostring(facts.level))
        end
    end
end

local function NpcID(guid)
    if type(guid) ~= "string" then
        return nil
    end
    local kind, id = guid:match("^(%a+)%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)")
    if kind == "Creature" or kind == "Vehicle" then
        return tonumber(id)
    end
end

local function UnitBody(tooltip, data)
    local wantID, wantGiver = IsOn("npc"), IsOn("giver")
    if not (wantID or wantGiver) or not ShownTooltip(tooltip) or type(data) ~= "table" or InInstance() then
        return
    end
    local unitName, unit
    if tooltip.GetUnit then
        unitName, unit = tooltip:GetUnit()
        unitName, unit = Safe(unitName), Safe(unit)
    end
    local guid = Safe(data.guid)
    if type(guid) ~= "string" and type(unit) == "string" and UnitGUID then
        guid = Safe(UnitGUID(unit))
    end
    local id = NpcID(guid)
    if wantID and id then
        AddPair(tooltip, "NPC ID", tostring(id))
    end
    -- Only creatures give quests: a player or pet that happens to share a name gets nothing.
    if wantGiver and id and type(unitName) == "string" and unitName ~= "" then
        pcall(AddGiverLines, tooltip, unitName)
    end
end

-- A tooltip error would repeat on every mouse-over, so problems here are swallowed.
-- Switched off on the hub's Manage page: add nothing at all.
local function SwitchedOff()
    return ForeverHub_IsOff and ForeverHub_IsOff("Tooltips") == true
end

local function OnItemTooltip(tooltip, data)
    if not SwitchedOff() then
        pcall(ItemBody, tooltip, data)
    end
end

local function OnUnitTooltip(tooltip, data)
    if not SwitchedOff() then
        pcall(UnitBody, tooltip, data)
    end
end

-- Quest tooltips (a quest link, a quest under the mouse): data.id is the quest ID.
local function QuestBody(tooltip, data)
    if not IsOn("forever") or not ShownTooltip(tooltip) or type(data) ~= "table" then
        return
    end
    local id = Safe(data.id)
    if type(id) == "number" and id >= FOREVER_FIRST_ID then
        tooltip:AddLine(FOREVER_TEXT, FOREVER_R, FOREVER_G, FOREVER_B)
    end
end

local function OnQuestTooltip(tooltip, data)
    if not SwitchedOff() then
        pcall(QuestBody, tooltip, data)
    end
end

----------------------------------------------------------------------------------------------------
-- Round 5 #5: counting the corpses you loot. Read only: it reads a loot window you opened (LOOT_OPENED) and
-- never loots, clicks or closes anything.

local RING_SIZE, MAX_LOOT_SLOTS, CAST_WINDOW = 1000, 60, 0.6
local seenCorpse, corpseRing, corpseAt = {}, {}, 0   -- this session's last RING_SIZE corpse GUIDs
local lastCastAt = nil   -- your last finished cast: skinning, pick pocketing and chests open loot after one

local function Clock()
    local now = GetTime and Safe(GetTime())
    return type(now) == "number" and now or nil
end

local function RememberCorpse(guid)
    corpseAt = corpseAt % RING_SIZE + 1
    local old = corpseRing[corpseAt]
    if old then
        seenCorpse[old] = nil
    end
    corpseRing[corpseAt] = guid
    seenCorpse[guid] = true
end

-- Smallest first by score; removes entries until at most cap are left (keep is never removed).
local function Trim(map, cap, score, keep)
    local keys = {}
    for key, value in pairs(map) do
        if key ~= keep then
            keys[#keys + 1] = { key = key, score = score(value) }
        end
    end
    local extra = #keys + (keep ~= nil and map[keep] ~= nil and 1 or 0) - cap
    if extra <= 0 then
        return
    end
    table.sort(keys, function(a, b)
        if a.score[1] ~= b.score[1] then
            return a.score[1] < b.score[1]
        end
        return a.score[2] < b.score[2]
    end)
    for index = 1, math.min(extra, #keys) do
        map[keys[index].key] = nil
    end
end

local function CreatureScore(creature)
    if type(creature) ~= "table" then
        return { -1, -1 }
    end
    return { type(creature.n) == "number" and creature.n or -1, type(creature.at) == "number" and creature.at or 0 }
end

local function ItemScore(k)
    return { type(k) == "number" and k or -1, 0 }
end

-- The unit token for a GUID when it's your target or mouse-over (for its name), else nil.
local function UnitFor(guid)
    if type(UnitGUID) ~= "function" then
        return nil
    end
    for _, unit in ipairs({ "target", "mouseover" }) do
        local ok, found = pcall(UnitGUID, unit)
        if ok and Safe(found) == guid then
            return unit
        end
    end
end

local function Pack(...)
    return { n = select("#", ...), ... }
end

local function ReadLoot()
    if SwitchedOff() or not IsOn("yourdrops") then
        return
    end
    if type(GetNumLootItems) ~= "function" or type(GetLootSourceInfo) ~= "function" then
        return
    end
    local now = Clock()
    if lastCastAt and now and now - lastCastAt < CAST_WINDOW then
        return   -- skinning, mining, pick pocketing or a chest: not a corpse's own loot
    end
    local ok, count = pcall(GetNumLootItems)
    count = ok and Safe(count)
    if type(count) ~= "number" or count < 1 then
        return
    end
    local corpses, order = {}, {}
    for slot = 1, math.min(count, MAX_LOOT_SLOTS) do
        local itemID
        if type(GetLootSlotLink) == "function" then
            local fine, link = pcall(GetLootSlotLink, slot)
            link = fine and Safe(link)
            itemID = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
        end
        local sources = Pack(pcall(GetLootSourceInfo, slot))
        if sources[1] == true then
            -- guid, quantity, guid, quantity, ... (several corpses when looting an area)
            for index = 2, sources.n, 2 do
                local guid = Safe(sources[index])   -- a secret GUID is skipped
                local npc = NpcID(guid)
                if npc then
                    local corpse = corpses[guid]
                    if corpse == nil then
                        -- Counted on its first opening only: a corpse opened again (items left, or skinned
                        -- later) adds nothing.
                        corpse = not seenCorpse[guid] and { npc = npc, items = {} } or false
                        corpses[guid] = corpse
                        order[#order + 1] = guid
                    end
                    if corpse and itemID then
                        corpse.items[itemID] = true
                    end
                end
            end
        end
    end
    if #order == 0 then
        return
    end
    local store = LootStore(true)
    local stamp = time and Safe(time())
    for _, guid in ipairs(order) do
        local corpse = corpses[guid]
        if corpse then
            RememberCorpse(guid)
            local creature = store[corpse.npc]
            if type(creature) ~= "table" or type(creature.n) ~= "number" or type(creature.items) ~= "table" then
                creature = { n = 0, items = {} }
                store[corpse.npc] = creature
                Trim(store, MAX_CREATURES, CreatureScore, corpse.npc)
            end
            creature.n = creature.n + 1
            creature.at = type(stamp) == "number" and stamp or creature.at
            local unit = UnitFor(guid)
            local name = unit and UnitName and Safe(UnitName(unit))
            if type(name) == "string" and name ~= "" then
                creature.name = name
            end
            for item in pairs(corpse.items) do
                local isNew = creature.items[item] == nil
                creature.items[item] = (tonumber(creature.items[item]) or 0) + 1
                if isNew then
                    Trim(creature.items, MAX_ITEMS, ItemScore, item)
                end
            end
        end
    end
    yourIndexDirty = true
end

local function Register()
    local processor = TooltipDataProcessor
    local types = Enum and Enum.TooltipDataType
    if type(processor) ~= "table" or type(processor.AddTooltipPostCall) ~= "function" or type(types) ~= "table" then
        return false
    end
    local any = false
    if types.Item ~= nil then
        any = pcall(processor.AddTooltipPostCall, types.Item, OnItemTooltip) or any
    end
    if types.Unit ~= nil then
        any = pcall(processor.AddTooltipPostCall, types.Unit, OnUnitTooltip) or any
    end
    if types.Quest ~= nil then
        any = pcall(processor.AddTooltipPostCall, types.Quest, OnQuestTooltip) or any
    end
    return any
end

local registered = false

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("LOOT_OPENED")
-- Registered for "player" only, every UNIT_SPELLCAST_SUCCEEDED is your own cast, even when its unit token comes
-- secret (the event is SecretWhenUnitSpellCastRestricted); only the all-units fallback has to read the token.
local playerCastsOnly = events.RegisterUnitEvent and pcall(events.RegisterUnitEvent, events, "UNIT_SPELLCAST_SUCCEEDED", "player") or false
if not playerCastsOnly then
    pcall(events.RegisterEvent, events, "UNIT_SPELLCAST_SUCCEEDED")
end
events:SetScript("OnEvent", function(_, event, unit)
    if event == "QUEST_LOG_UPDATE" then
        -- Only marks the cache old; the next tooltip that needs the log reads it again.
        questLogDirty = true
        return
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if playerCastsOnly or Safe(unit) == "player" then
            lastCastAt = Clock()
        end
        return
    elseif event == "LOOT_OPENED" then
        pcall(ReadLoot)
        return
    end
    if type(TooltipsDB) ~= "table" then
        TooltipsDB = {}
    end
    if not registered then
        registered = Register()
    end
end)

----------------------------------------------------------------------------------------------------
-- Page

local function NameList()
    local names = {}
    for _, line in ipairs(LINES) do
        names[#names + 1] = line.name
    end
    return table.concat(names, ", ")
end

local function ShowPage()
    if not registered then
        Print("|cffff9933This game version doesn't offer the tooltip hook, so no lines are added.|r")
    end
    Print("Extra lines on item, creature and quest tooltips. They only add information.")
    Print(" ")
    for _, line in ipairs(LINES) do
        local state = IsOn(line.name) and "|cff33ff33on |r" or "|cff999999off|r"
        Print(string.format("%s  |cffffffff%s|r |cff999999(%s)|r - %s", state, line.label, line.name, line.about))
    end
    Print(" ")
    Print("|cff999999The auction and count lines stay out of the way while PriceMemory or ItemFinder already shows the same thing on a tooltip. A vendor price the game shows itself isn't repeated, nor a quest the tooltip already names, nor an upgrade ItemAdvisor already rates.|r")
    Print("|cff999999Type: off vendor   Or: on id   Or: toggle npc|r")
end

SLASH_TOOLTIPS1 = "/fhtips"
SlashCmdList.TOOLTIPS = function(message)
    local text = type(message) == "string" and message:lower():match("^%s*(.-)%s*$") or ""
    if text == "" then
        ShowPage()
        return
    end
    local verb, name = text:match("^(%a+)%s+(%a+)$")
    if not verb then
        verb, name = "toggle", text
    end
    local line = LINE_BY_NAME[name]
    if not line or not (verb == "on" or verb == "off" or verb == "toggle") then
        Print("Type on, off, or toggle and a line name: " .. NameList() .. ".")
        return
    end
    if type(TooltipsDB) ~= "table" then
        TooltipsDB = {}
    end
    local value
    if verb == "toggle" then
        value = not IsOn(name)
    else
        value = verb == "on"
    end
    TooltipsDB[name] = value
    Print(string.format("%s is now %s.", line.label, value and "|cff33ff33on|r" or "|cff999999off|r"))
end
