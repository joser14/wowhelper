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

local COPPER_PER_GOLD = 10000
local SKILL_RIDING = 762
local RANK_APPRENTICE, RANK_JOURNEYMAN = 75, 150
local MIN_ETA_SECONDS = 600
-- Far above anything a leveling character saves for; catches typos like an extra zero or three.
local MAX_GOAL_GOLD = 100000
-- Training plus mount, per Warcraft Tavern's Forever riding guide (checked at launch, Nov 2026).
local RIDING_GOALS = {
    apprentice = { name = "Apprentice Riding and a mount", short = "riding", gold = 120, level = 40 },
    journeyman = { name = "Journeyman Riding and a mount", short = "epic riding", gold = 1200, level = 60 },
}
-- These classes get riding and their mounts through class quests.
local QUEST_MOUNT_CLASSES = { PALADIN = true, WARLOCK = true }

local charData, startMoney, startTime
local reached = {}

-- Money by source (research\re_round5.md #4), worked out without hooks: when PLAYER_MONEY changes, the
-- source is the window that is open (or closed a moment ago). Window labels and grace periods follow the
-- idea in Memories' Money.lua (GPL-3.0-or-later, idea only, no code taken); its hook-based refinements are
-- replaced here by two event-only rules: a loss at a vendor while your gear's durability rises is a repair,
-- and a gain at the mailbox that equals an auction invoice's amount is an auction sale.
local DAY_SECONDS = 86400
local KEEP_DAYS = 14             -- days of money-by-source kept per character
local MAX_SALES = 30             -- auction invoices kept per character
local QUEST_SECONDS = 5          -- a gain this soon after QUEST_TURNED_IN is the quest's reward
local REPAIR_SECONDS = 2         -- durability rising this soon after a vendor loss makes it a repair
local MAIL_DAYS = 30             -- auction house mail stays this long
local RATE_MIN_SECONDS = 1800    -- played time needed before a 7-day rate is used
-- Window events: kind, and whether the window opens (true) or closes (false).
local WINDOW_EVENTS = {
    MERCHANT_SHOW = { "vendor", true }, MERCHANT_CLOSED = { "vendor", false },
    TRAINER_SHOW = { "trainer", true }, TRAINER_CLOSED = { "trainer", false },
    MAIL_SHOW = { "mail", true }, MAIL_CLOSED = { "mail", false },
    AUCTION_HOUSE_SHOW = { "auction", true }, AUCTION_HOUSE_CLOSED = { "auction", false },
    TAXIMAP_OPENED = { "flight", true }, TAXIMAP_CLOSED = { "flight", false },
    LOOT_OPENED = { "loot", true }, LOOT_CLOSED = { "loot", false },
    BANKFRAME_OPENED = { "bank", true }, BANKFRAME_CLOSED = { "bank", false },
    TRADE_SHOW = { "trade", true }, TRADE_CLOSED = { "trade", false },
}
-- Seconds a window still counts after it closed (the money can arrive just after, e.g. a flight).
local GRACE = { vendor = 1, trainer = 1, mail = 2, auction = 3, flight = 2, loot = 1, bank = 1, trade = 2 }
local SOURCE_LABEL = {
    quest = "Quests", loot = "Loot", vendorSell = "Sold to vendors", vendorBuy = "Bought from vendors",
    repair = "Repairs", trainer = "Training", flight = "Flights", mail = "Mail", auctionSale = "Auction sales",
    auction = "Auction house costs", bank = "Bank slots", trade = "Trades", otherGain = "Other gains",
    otherLoss = "Other costs",
}
local windows = {}               -- [kind] = { open = bool, at = GetTime() of the last open/close }
local lastMoney, lastTick, lastTurnIn
local durabilityBase, pendingBuy
local sessionSeconds = 0

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Number(value)
    value = Safe(value)
    return type(value) == "number" and value or nil
end

-- Calls a game function that may not exist on this client; all its return values, made safe.
local unpackValues = unpack or table.unpack
local function Call(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local result = { n = 0 }
    local function pack(ok, ...)
        result.ok, result.n = ok, select("#", ...)
        for i = 1, result.n do
            result[i] = Safe((select(i, ...)))
        end
    end
    pack(pcall(fn, ...))
    if not result.ok then
        return nil
    end
    return unpackValues(result, 1, result.n)
end

local function Now()
    return type(time) == "function" and Number(time()) or nil
end

local function Clock()
    return type(GetTime) == "function" and Number(GetTime()) or 0
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("GoldGoal", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function FormatGold(copper)
    return string.format("%dg %ds", math.floor(copper / COPPER_PER_GOLD), math.floor(copper / 100) % 100)
end

-- Signed and with copper, for small amounts such as a repair: "+1g 2s 3c", "-15s 0c".
local function FormatSigned(copper)
    local sign = copper < 0 and "-" or "+"
    copper = math.floor(math.abs(copper) + 0.5)
    local gold, silver, rest = math.floor(copper / COPPER_PER_GOLD), math.floor(copper / 100) % 100, copper % 100
    if gold > 0 then
        return string.format("%s%dg %ds", sign, gold, silver)
    elseif silver > 0 then
        return string.format("%s%ds %dc", sign, silver, rest)
    end
    return string.format("%s%dc", sign, rest)
end

local function AgoText(seconds)
    if seconds < 3600 then
        return "under an hour ago"
    elseif seconds < DAY_SECONDS then
        return string.format("%dh ago", math.floor(seconds / 3600))
    end
    return string.format("%dd ago", math.floor(seconds / DAY_SECONDS))
end

----- Money by source ------------------------------------------------------------------------------------

local function MoneyData()
    if type(charData.money) ~= "table" then
        charData.money = {}
    end
    local money = charData.money
    for _, field in ipairs({ "days", "levels", "total" }) do
        if type(money[field]) ~= "table" then
            money[field] = {}
        end
    end
    return money
end

-- Keeps the newest KEEP_DAYS days.
local function PruneDays(days, today)
    local keys = {}
    for day, value in pairs(days) do
        if type(day) ~= "number" or type(value) ~= "table" or (today and day <= today - KEEP_DAYS) then
            days[day] = nil
        else
            keys[#keys + 1] = day
        end
    end
    if #keys > KEEP_DAYS then
        table.sort(keys)
        for index = 1, #keys - KEEP_DAYS do
            days[keys[index]] = nil
        end
    end
end

local function Today()
    local now = Now()
    return now and math.floor(now / DAY_SECONDS) or nil
end

local function Bucket(parent, key)
    if key == nil then
        return nil
    end
    if type(parent[key]) ~= "table" then
        parent[key] = {}
    end
    return parent[key]
end

-- The tables an amount goes into: today, this level and all time.
local function Buckets()
    local money = MoneyData()
    local today = Today()
    local list = {}
    local day = Bucket(money.days, today)
    if day then
        list[#list + 1] = day
        PruneDays(money.days, today)
    end
    local level = Number(UnitLevel and UnitLevel("player"))
    local levelBucket = level and level >= 1 and level <= 100 and Bucket(money.levels, math.floor(level))
    if levelBucket then
        list[#list + 1] = levelBucket
    end
    list[#list + 1] = money.total
    return list
end

local function AddTo(buckets, source, amount)
    for _, bucket in ipairs(buckets) do
        bucket[source] = (type(bucket[source]) == "number" and bucket[source] or 0) + amount
    end
end

-- Played seconds go to today, so a 7-day rate can be worked out.
local function Tick()
    local clock = Clock()
    if lastTick and clock > lastTick then
        local elapsed = clock - lastTick
        sessionSeconds = sessionSeconds + elapsed
        if charData then
            local day = Bucket(MoneyData().days, Today())
            if day then
                day.secs = (type(day.secs) == "number" and day.secs or 0) + elapsed
            end
        end
    end
    lastTick = clock
end

-- Summed current durability of your worn gear, or nil when the game doesn't say.
local function DurabilitySum()
    local sum, any = 0, false
    for slot = 1, 19 do
        local current = Call(GetInventoryItemDurability, slot)
        if type(current) == "number" then
            sum, any = sum + current, true
        end
    end
    return any and sum or nil
end

-- The window the money most likely came from: the newest open one, else the newest that closed within
-- its grace period.
local function WindowSource(clock)
    local best, bestAt
    for kind, state in pairs(windows) do
        if state.open and (not bestAt or state.at > bestAt) then
            best, bestAt = kind, state.at
        end
    end
    if best then
        return best
    end
    for kind, state in pairs(windows) do
        if not state.open and clock - state.at <= (GRACE[kind] or 1) and (not bestAt or state.at > bestAt) then
            best, bestAt = kind, state.at
        end
    end
    return best
end

-- An auction invoice still waiting in the mail whose amount is exactly this gain.
local function ClaimSale(amount)
    for index = #(charData.sales or {}), 1, -1 do
        local sale = charData.sales[index]
        if type(sale) == "table" and not sale.taken and sale.net == amount then
            sale.taken = true
            return true
        end
    end
    return false
end

local function Classify(delta, clock)
    if delta > 0 and lastTurnIn and clock - lastTurnIn <= QUEST_SECONDS then
        return "quest"
    end
    local window = WindowSource(clock)
    if window == "vendor" then
        return delta > 0 and "vendorSell" or "vendorBuy"
    elseif window == "mail" then
        if delta > 0 and ClaimSale(delta) then
            return "auctionSale"
        end
        return "mail"
    elseif window then
        return window
    end
    return delta > 0 and "otherGain" or "otherLoss"
end

local function OnMoney()
    local money = Number(GetMoney and GetMoney())
    if not money then
        return -- unreadable now: keep the last amount, so the change is counted at the next readable one
    end
    if not lastMoney then
        lastMoney = money
        return
    end
    local delta = money - lastMoney
    lastMoney = money
    if delta == 0 then
        return
    end
    Tick()
    local clock = Clock()
    local source = Classify(delta, clock)
    local buckets = Buckets()
    if source == "vendorBuy" then
        local now = DurabilitySum()
        if now and durabilityBase and now > durabilityBase then
            source = "repair"
            durabilityBase = now
        else
            -- The durability update can come just after the money: keep it so it can be moved to repairs.
            pendingBuy = { amount = delta, at = clock, buckets = buckets }
        end
    end
    AddTo(buckets, source, delta)
end

local function OnDurability()
    local now = DurabilitySum()
    if pendingBuy and now and durabilityBase and now > durabilityBase and Clock() - pendingBuy.at <= REPAIR_SECONDS then
        AddTo(pendingBuy.buckets, "vendorBuy", -pendingBuy.amount)
        AddTo(pendingBuy.buckets, "repair", pendingBuy.amount)
    end
    pendingBuy = nil
    durabilityBase = now or durabilityBase
end

----- Auction invoices (seller mail from the auction house) -----------------------------------------------

-- GetInboxInvoiceInfo is not in this client's API documentation (listed for an in-game check); every call
-- is guarded. Reads only: no mail is opened, taken or deleted.
local function ReadInvoices()
    local total = Call(GetInboxNumItems)
    local now = Now()
    if type(total) ~= "number" or not now or type(GetInboxInvoiceInfo) ~= "function" then
        return
    end
    charData.sales = type(charData.sales) == "table" and charData.sales or {}
    local sales = charData.sales
    for index = 1, math.min(total, 100) do
        local invoiceType, itemName, _, bid, _, deposit, consignment, _, _, _, count = Call(GetInboxInvoiceInfo, index)
        local _, _, _, _, money, _, daysLeft = Call(GetInboxHeaderInfo, index)
        if invoiceType == "seller" and type(itemName) == "string" and itemName ~= "" and type(bid) == "number" then
            deposit = type(deposit) == "number" and deposit or 0
            consignment = type(consignment) == "number" and consignment or 0
            local net = (type(money) == "number" and money > 0) and money or (bid + deposit - consignment)
            -- When the mail arrived, from how long it has left; the same invoice read again lands within the hour.
            local arrived = type(daysLeft) == "number" and math.floor(now - (MAIL_DAYS - daysLeft) * DAY_SECONDS) or now
            local known = false
            for _, sale in ipairs(sales) do
                if type(sale) == "table" and sale.item == itemName and sale.price == bid and sale.cut == consignment
                    and type(sale.at) == "number" and math.abs(sale.at - arrived) < 3600 then
                    known = true
                    break
                end
            end
            if not known then
                sales[#sales + 1] = { item = itemName, count = type(count) == "number" and count or nil, price = bid,
                    deposit = deposit, cut = consignment, net = net, at = arrived }
            end
        end
    end
    table.sort(sales, function(a, b)
        return (type(a) == "table" and tonumber(a.at) or 0) < (type(b) == "table" and tonumber(b.at) or 0)
    end)
    while #sales > MAX_SALES do
        table.remove(sales, 1)
    end
end

----- Showing it ---------------------------------------------------------------------------------------

-- "Loot +50s 0c, Quests +1g 10s" for the biggest sources in a bucket; nil when it holds nothing.
local function SourcesText(bucket, limit)
    if type(bucket) ~= "table" then
        return nil
    end
    local list, net = {}, 0
    for source, label in pairs(SOURCE_LABEL) do
        local amount = bucket[source]
        if type(amount) == "number" and amount ~= 0 then
            list[#list + 1] = { label = label, amount = amount }
            net = net + amount
        end
    end
    if #list == 0 then
        return nil
    end
    table.sort(list, function(a, b)
        if math.abs(a.amount) ~= math.abs(b.amount) then
            return math.abs(a.amount) > math.abs(b.amount)
        end
        return a.label < b.label
    end)
    local parts = {}
    for index = 1, math.min(#list, limit or #list) do
        parts[#parts + 1] = list[index].label .. " " .. FormatSigned(list[index].amount)
    end
    if limit and #list > limit then
        parts[#parts + 1] = string.format("%d more", #list - limit)
    end
    return string.format("%s net. %s", FormatSigned(net), table.concat(parts, ", ")), net
end

-- Net copper and played seconds over the last n days (today included).
local function RecentRate(days)
    local today = Today()
    if not (charData and today) then
        return nil
    end
    local net, secs = 0, 0
    for day, bucket in pairs(MoneyData().days) do
        if type(day) == "number" and type(bucket) == "table" and day > today - days then
            for source in pairs(SOURCE_LABEL) do
                net = net + (type(bucket[source]) == "number" and bucket[source] or 0)
            end
            secs = secs + (type(bucket.secs) == "number" and bucket.secs or 0)
        end
    end
    return net, secs
end

local function ShowSourcesSummary()
    local money = MoneyData()
    local level = Number(UnitLevel and UnitLevel("player"))
    local today = Today()
    local dayText = today and SourcesText(money.days[today], 4)
    local levelText = level and SourcesText(money.levels[level], 4)
    if dayText then
        Print("|cffffd100Today|r " .. dayText)
    end
    if levelText then
        Print(string.format("|cffffd100Level %d|r %s", level, levelText))
    end
    local sales = type(charData.sales) == "table" and charData.sales or {}
    local latest = sales[#sales]
    if type(latest) == "table" and type(latest.net) == "number" then
        local count = latest.count and latest.count > 1 and (" x" .. latest.count) or ""
        Print(string.format("|cffffd100Last auction sale|r %s%s for %s%s", tostring(latest.item), count,
            FormatGold(latest.net), Now() and type(latest.at) == "number" and (", " .. AgoText(math.max(Now() - latest.at, 0))) or ""))
    end
    if dayText or levelText or latest then
        Print("|cff999999Type: sources   Or: sales|r")
    end
end

local function ShowSources()
    Tick()
    local money = MoneyData()
    local today = Today()
    local any = false
    local function line(title, bucket)
        local text = SourcesText(bucket)
        if text then
            any = true
            Print("|cffffd100" .. title .. "|r " .. text)
        end
    end
    if today then
        line("Today", money.days[today])
        line("Yesterday", money.days[today - 1])
        local week = {}
        for day, bucket in pairs(money.days) do
            if type(day) == "number" and type(bucket) == "table" and day > today - 7 then
                for source in pairs(SOURCE_LABEL) do
                    if type(bucket[source]) == "number" then
                        week[source] = (week[source] or 0) + bucket[source]
                    end
                end
            end
        end
        line("Last 7 days", week)
    end
    local level = Number(UnitLevel and UnitLevel("player"))
    if level then
        line("Level " .. level, money.levels[level])
        line("Level " .. (level - 1), money.levels[level - 1])
    end
    line("Since this was installed", money.total)
    local net, secs = RecentRate(7)
    if net and secs and secs >= RATE_MIN_SECONDS then
        Print(string.format("Over the last 7 days: %s per hour played (%.1f h played).", FormatSigned(net * 3600 / secs), secs / 3600))
    end
    if not any then
        Print("No money has come in or gone out since this was installed. Each change is sorted by the window you had open: vendor, trainer, mailbox, auction house, flight master, loot, bank or trade.")
    else
        Print("|cff999999Sorted by the window you had open when your money changed. A loss at a vendor while your gear's durability rose counts as a repair; money taken from an auction invoice counts as an auction sale.|r")
    end
end

local function ShowSales()
    local sales = type(charData.sales) == "table" and charData.sales or {}
    if #sales == 0 then
        Print("No auction sales seen yet. They appear after you open your mailbox while an auction house sale invoice is in it.")
        return
    end
    local now = Now()
    local total, cut = 0, 0
    for index = #sales, 1, -1 do
        local sale = sales[index]
        if type(sale) == "table" and type(sale.net) == "number" then
            total = total + sale.net
            cut = cut + (tonumber(sale.cut) or 0)
            local count = sale.count and sale.count > 1 and (" x" .. sale.count) or ""
            local ago = now and type(sale.at) == "number" and (", " .. AgoText(math.max(now - sale.at, 0))) or ""
            Print(string.format("%s%s: sold for %s, you get %s (cut %s)%s%s", tostring(sale.item), count,
                FormatGold(tonumber(sale.price) or 0), FormatGold(sale.net), FormatSigned(-(tonumber(sale.cut) or 0)):sub(2),
                ago, sale.taken and "" or " |cff999999(still in the mail)|r"))
        end
    end
    Print(string.format("|cffffd100%d sale(s):|r %s after the auction house's cut of %s.", #sales, FormatGold(total), FormatSigned(-cut):sub(2)))
end

local function RidingGoal()
    if QUEST_MOUNT_CLASSES[Safe(select(2, UnitClass("player")))] then
        return nil
    end
    local info = C_SkillInfo and Safe(C_SkillInfo.GetSkillLineInfoByID(SKILL_RIDING))
    local rank = type(info) == "table" and Safe(info.rank) or 0
    if rank >= RANK_JOURNEYMAN then
        return nil
    end
    return rank >= RANK_APPRENTICE and RIDING_GOALS.journeyman or RIDING_GOALS.apprentice
end

-- The goal being tracked: your own if you set one, otherwise the next riding step.
local function CurrentGoal()
    if charData and charData.goal then
        return charData.goal
    end
    return RidingGoal()
end

local function EtaText(short)
    local money = Safe(GetMoney())
    if not (money and startMoney) then
        return ""
    end
    local elapsed, earned = GetTime() - startTime, money - startMoney
    if elapsed >= MIN_ETA_SECONDS and earned > 0 then
        local hours = short / (earned / elapsed) / 3600
        return string.format(" About %.1f hour(s) at this session's rate.", hours)
    end
    -- Too little of this session yet: the net gold per hour played over the last 7 days.
    local net, secs = RecentRate(7)
    if net and secs and secs >= RATE_MIN_SECONDS and net > 0 then
        return string.format(" About %.1f hour(s) of play at your last 7 days' rate.", short / (net / secs) / 3600)
    end
    return ""
end

-- newLevel comes from PLAYER_LEVEL_UP, since UnitLevel can still report the old level then.
local function CheckGoal(newLevel)
    local goal = CurrentGoal()
    local money = Safe(GetMoney())
    local level = type(newLevel) == "number" and newLevel or Safe(UnitLevel("player"))
    if not (goal and money and level) then
        return
    end
    local ready = money >= goal.gold * COPPER_PER_GOLD and level >= (goal.level or 1)
    if ready and not reached[goal.name] then
        Print("You can afford " .. goal.name .. "!")
    end
    reached[goal.name] = ready
end

local function ShowGoal()
    local goal = CurrentGoal()
    if not goal then
        if QUEST_MOUNT_CLASSES[Safe(select(2, UnitClass("player")))] then
            Print("Your class gets riding and its mounts from class quests, so riding isn't tracked here.")
        end
        Print("No goal set. Enter gold and a name on the Gold goal page, such as 500 Bags.")
        ShowSourcesSummary()
        return
    end
    local money = Safe(GetMoney())
    if not money then
        Print("The game didn't report your gold.")
        ShowSourcesSummary()
        return
    end
    local cost = goal.gold * COPPER_PER_GOLD
    if money >= cost then
        Print(string.format("%s: you have %s of %dg. Enough!", goal.name, FormatGold(money), goal.gold))
    else
        Print(string.format("%s: you have %s of %dg, %s short.%s", goal.name, FormatGold(money), goal.gold, FormatGold(cost - money), EtaText(cost - money)))
    end
    local level = Safe(UnitLevel("player"))
    if goal.level and level and level < goal.level then
        Print(string.format("Requires level %d. You're level %d.", goal.level, level))
    end
    if not charData.goal then
        Print("Guides list 10% off when you're Honored with your home faction.")
    end
    ShowSourcesSummary()
end

local function HandleSlash(message)
    local command = message:match("^%s*(%S*)"):lower()
    -- Whole gold only, with or without a trailing g, so "500g" works and "1e9" or "2.5" don't.
    local gold = tonumber(command:match("^(%d+)g?$") or "")
    if command == "" then
        ShowGoal()
    elseif command == "clear" then
        charData.goal = nil
        Print("Your goal is cleared.")
    elseif command == "sources" or command == "money" then
        ShowSources()
    elseif command == "sales" or command == "auction" then
        ShowSales()
    elseif gold and gold > 0 and gold <= MAX_GOAL_GOLD then
        local name = message:match("^%s*%S+%s+(.-)%s*$")
        charData.goal = { name = (name and name ~= "") and name or "Gold goal", gold = gold }
        reached = {}
        ShowGoal()
        CheckGoal()
    else
        Print(string.format("Enter whole gold from 1 to %d and a name, such as 500 Bags. Or: clear, to go back to tracking riding. Or: sources   Or: sales", MAX_GOAL_GOLD))
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_MONEY")
events:RegisterEvent("PLAYER_LEVEL_UP")
-- All documented on this client (MerchantFrame, Trainer, MailInfo, AuctionHouse, TaxiMap, Loot, Bank, TradeInfo,
-- QuestLog and PaperDollInfo docs) and none is a CallbackEvent; guarded anyway so a missing one can't stop the rest.
for name in pairs(WINDOW_EVENTS) do
    pcall(events.RegisterEvent, events, name)
end
for _, name in ipairs({ "QUEST_TURNED_IN", "UPDATE_INVENTORY_DURABILITY", "MAIL_INBOX_UPDATE", "PLAYER_LOGOUT" }) do
    pcall(events.RegisterEvent, events, name)
end
events:SetScript("OnEvent", function(_, event, arg)
    if event == "PLAYER_LOGIN" then
        GoldGoalDB = GoldGoalDB or {}
        local key = ForeverCharacterAdopt(GoldGoalDB)
        GoldGoalDB[key] = GoldGoalDB[key] or {}
        charData = ForeverCharacterStamp(GoldGoalDB[key])
        startMoney, startTime = Safe(GetMoney()), GetTime()
        lastMoney, lastTick = startMoney, Clock()
        durabilityBase = DurabilitySum()
        local money = MoneyData()
        PruneDays(money.days, Today())
        for level, bucket in pairs(money.levels) do
            if type(level) ~= "number" or type(bucket) ~= "table" then
                money.levels[level] = nil
            end
        end
    end
    if not charData then
        return
    end
    local window = WINDOW_EVENTS[event]
    if window then
        windows[window[1]] = { open = window[2], at = Clock() }
        if event == "MERCHANT_SHOW" then
            durabilityBase = DurabilitySum() or durabilityBase
        end
        return
    elseif event == "PLAYER_MONEY" then
        pcall(OnMoney)
    elseif event == "QUEST_TURNED_IN" then
        lastTurnIn = Clock()
        return
    elseif event == "UPDATE_INVENTORY_DURABILITY" then
        pcall(OnDurability)
        return
    elseif event == "MAIL_INBOX_UPDATE" then
        pcall(ReadInvoices)
        return
    elseif event == "PLAYER_LOGOUT" then
        Tick()
        return
    elseif event == "PLAYER_LEVEL_UP" then
        Tick()
    end
    CheckGoal(event == "PLAYER_LEVEL_UP" and Safe(arg) or nil)
end)

SLASH_GOLDGOAL1 = "/goal"
SLASH_GOLDGOAL2 = "/goldgoal"
SlashCmdList.GOLDGOAL = function(message)
    if charData then
        HandleSlash(message)
    end
end

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.GoldGoal = function()
    local goal = charData and CurrentGoal()
    local money = Safe(GetMoney())
    if not (goal and money) then
        return nil
    end
    local level = Safe(UnitLevel("player"))
    if money >= goal.gold * COPPER_PER_GOLD and level and level >= (goal.level or 1) then
        return { { text = string.format("|cff33ff33Buy|r %s (%dg)", goal.short or goal.name, goal.gold), page = "Gold goal" } }
    end
    local percent = math.min(math.floor(money * 100 / (goal.gold * COPPER_PER_GOLD)), 100)
    return { { text = string.format("|cffeecc55Saving|r %d%% of %dg for %s", percent, goal.gold, goal.short or goal.name), page = "Gold goal" } }
end
