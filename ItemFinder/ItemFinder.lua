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


-- Round 4 (research\re_round4.md R14): records are keyed by item ID, so renamed or translated items still
-- match. Each character's record holds
--   items = { bags = {[id] = n}, bank = ..., gear = ..., keys = ..., mail = ... }, names = {[id] = name},
--   inbox = { {id, count, expires} }, incoming = { {id, count, expires} } (mail you sent it), faction, realm,
--   scanTime.
-- Older records keyed by name (bags/bank/gear = {[name] = n}) stay readable until the first rescan of that place.
-- Mail is read without hooks: the inbox on MAIL_INBOX_UPDATE, outgoing attachments on MAIL_SEND_INFO_UPDATE and
-- MAIL_LOCK_SEND_ITEMS, committed on MAIL_SEND_SUCCESS (MailInfoDocumentation:102-133). Idea from Baganator/
-- Syndicator (feature level only, no code); they hook SendMail, which we don't.
local FIRST_GEAR_SLOT, LAST_GEAR_SLOT = 1, 19
local MAX_RESULTS = 30
local MAIL_DAYS = 30
local DAY = 86400
-- Round 5 (research\re_round5.md #14): mail that expires within this long is warned about, once per login as
-- a pop-up and at the top of every search. Expired mail is returned or deleted by the game, so it matters.
local EXPIRY_WARN = 3 * DAY
local LOGIN_WARN_DELAY = 8       -- seconds after login, so the hub window is ready for the pop-up
local MAX_MONEY_MAIL = 50        -- mails with money kept per character (for the warning only)
local EXPIRING_COMMAND = "expiring"
-- Places in the order searches and tooltips list them, with their labels.
local PLACES = { "bags", "keys", "bank", "gear", "mail" }
local PLACE_LABEL = { bags = "bags", keys = "keyring", bank = "bank", gear = "worn", mail = "mail" }
-- Old records used these name-keyed fields.
local LEGACY = { bags = "bags", bank = "bank", gear = "gear" }

local charData
local bankOpen = false
local myKey
local warnedThisLogin = false

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

-- Calls a game function that may not exist on this client; its first return values, made safe.
local unpackValues = unpack or table.unpack
local function Pack(...)
    return { n = select("#", ...), ... }
end
local function Call(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local result = Pack(pcall(fn, ...))
    if not result[1] then
        return nil
    end
    for i = 2, result.n do
        result[i] = Safe(result[i])
    end
    return unpackValues(result, 2, math.max(result.n, 2))
end

local function IDOf(link)
    return type(link) == "string" and tonumber(link:match("item:(%-?%d+)")) or nil
end

-- A link can have an empty name until the game has loaded that item.
local function NameOf(link)
    local name = type(link) == "string" and link:match("%[(.-)%]")
    if name and name ~= "" then
        return name
    end
end

local function Items(record)
    if type(record.items) ~= "table" then
        record.items = {}
    end
    if type(record.names) ~= "table" then
        record.names = {}
    end
    return record.items
end

local function Add(counts, names, link, count)
    local id = IDOf(link)
    if not id then
        return
    end
    counts[id] = (counts[id] or 0) + (count or 1)
    local name = NameOf(link)
    if name then
        names[id] = name
    end
end

-- Keeps only the names of items the record still holds, so names never grow without bound.
local function PruneNames(record)
    local keep = {}
    for _, place in ipairs(PLACES) do
        for id in pairs(record.items[place] or {}) do
            keep[id] = record.names[id]
        end
    end
    record.names = keep
end

local function ScanContainers(list, names)
    local counts = {}
    for _, bag in ipairs(list) do
        for slot = 1, Safe(C_Container.GetContainerNumSlots(bag)) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local link = info and Safe(info.hyperlink)
            if link then
                Add(counts, names, link, Safe(info.stackCount) or 1)
            end
        end
    end
    return counts
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

-- The keyring is Enum.BagIndex.Keyring (-1, BagIndexConstantsDocumentation). Its size comes from the
-- undocumented GetKeyRingSize, since the generic slot count may not report it.
local function ScanKeyring(names)
    local keyring = Enum and Enum.BagIndex and Enum.BagIndex.Keyring
    if type(keyring) ~= "number" then
        return {}
    end
    local size = Call(GetKeyRingSize)
    if type(size) ~= "number" then
        size = Call(C_Container.GetContainerNumSlots, keyring)
    end
    local counts = {}
    for slot = 1, type(size) == "number" and size or 0 do
        local info = Call(C_Container.GetContainerItemInfo, keyring, slot)
        local link = type(info) == "table" and Safe(info.hyperlink)
        if link then
            Add(counts, names, link, Safe(info.stackCount) or 1)
        end
    end
    return counts
end

local function SaveBags()
    if not charData then
        return
    end
    local items = Items(charData)
    items.bags = ScanContainers(BagList(), charData.names)
    items.keys = ScanKeyring(charData.names)
    charData.bags = nil
    charData.scanTime = time()
    PruneNames(charData)
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
        Items(charData).bank = ScanContainers(list, charData.names)
        charData.bank = nil
        PruneNames(charData)
    end
end

local function SaveGear()
    if not charData then
        return
    end
    local gear = {}
    local names = Items(charData) and charData.names
    for slot = FIRST_GEAR_SLOT, LAST_GEAR_SLOT do
        Add(gear, names, Safe(GetInventoryItemLink("player", slot)))
    end
    -- Equipped bags sit in inventory slots of their own (C_Container.ContainerIDToInventoryID).
    for bag = 1, NUM_BAG_SLOTS or 4 do
        local slot = Call(C_Container.ContainerIDToInventoryID, bag)
        if type(slot) == "number" then
            Add(gear, names, Safe(GetInventoryItemLink("player", slot)))
        end
    end
    charData.items.gear = gear
    charData.gear = nil
    PruneNames(charData)
end

-- Mail ------------------------------------------------------------------------------------------------

-- items.mail = inbox + mail sent to this character, without what has expired.
local function RebuildMail(record)
    local now = time()
    local counts = {}
    for _, field in ipairs({ "inbox", "incoming" }) do
        local list = record[field]
        if type(list) == "table" then
            for index = #list, 1, -1 do
                local entry = list[index]
                if type(entry) ~= "table" or type(entry.expires) ~= "number" or entry.expires <= now then
                    table.remove(list, index)
                else
                    counts[entry.id] = (counts[entry.id] or 0) + entry.count
                end
            end
            if #list == 0 then
                record[field] = nil
            end
        end
    end
    -- Mail holding only money: kept for the expiry warning, not counted as items.
    local money = record.mailMoney
    if type(money) == "table" then
        for index = #money, 1, -1 do
            local entry = money[index]
            if type(entry) ~= "table" or type(entry.expires) ~= "number" or entry.expires <= now or type(entry.money) ~= "number" then
                table.remove(money, index)
            end
        end
        if #money == 0 then
            record.mailMoney = nil
        end
    elseif money ~= nil then
        record.mailMoney = nil
    end
    Items(record).mail = counts
    PruneNames(record)
end

local function AttachmentCount(fn, ...)
    local _, _, _, count = Call(fn, ...)
    return type(count) == "number" and count or 1
end

local function SaveInbox()
    if not charData then
        return
    end
    local total = Call(GetInboxNumItems)
    if type(total) ~= "number" then
        return
    end
    local now, inbox, moneyMail = time(), {}, {}
    local names = Items(charData) and charData.names
    for index = 1, total do
        local _, _, _, _, money, _, daysLeft, hasItem = Call(GetInboxHeaderInfo, index)
        if type(money) == "number" and money > 0 and type(daysLeft) == "number" and #moneyMail < MAX_MONEY_MAIL then
            moneyMail[#moneyMail + 1] = { money = money, expires = now + daysLeft * DAY }
        end
        if hasItem and type(daysLeft) == "number" then
            for attachment = 1, ATTACHMENTS_MAX_RECEIVE or 16 do
                local link = Call(GetInboxItemLink, index, attachment)
                local id = IDOf(link)
                if id then
                    local count = AttachmentCount(GetInboxItem, index, attachment)
                    inbox[#inbox + 1] = { id = id, count = count, expires = now + daysLeft * DAY }
                    names[id] = NameOf(link) or names[id]
                end
            end
        end
    end
    charData.inbox = #inbox > 0 and inbox or nil
    charData.mailMoney = #moneyMail > 0 and moneyMail or nil
    -- Everything sent here is in the inbox now (or was taken out), so the guesses from sending are done.
    charData.incoming = nil
    RebuildMail(charData)
end

-- What is attached to the mail being written: { [slot] = { id, count, name } }.
local outgoing, sending = {}, nil

local function ReadAttachments()
    local found = {}
    for slot = 1, ATTACHMENTS_MAX_SEND or 12 do
        local link = Call(GetSendMailItemLink, slot)
        local id = IDOf(link)
        if id then
            found[slot] = { id = id, count = AttachmentCount(GetSendMailItem, slot), name = NameOf(link) }
        end
    end
    return found
end

-- The name typed in the mail window's "To:" box, read only (never changed).
local function Recipient()
    local box = SendMailNameEditBox
    local text = type(box) == "table" and Call(box.GetText, box)
    if type(text) == "string" and text ~= "" then
        return text
    end
end

-- Your character called "name" (first name, optionally "-Realm") on this realm, if exactly one matches.
local function OwnRecord(name)
    if type(name) ~= "string" then
        return nil
    end
    local first, realm = name:match("^%s*([^%-%s]+)%-?(%S*)")
    if not first then
        return nil
    end
    first = first:lower()
    local myRealm = Call(GetRealmName)
    if realm ~= "" and myRealm and realm:gsub("%s", ""):lower() ~= myRealm:gsub("%s", ""):lower() then
        return nil
    end
    local found
    for key, record in pairs(ItemFinderDB) do
        local recordFirst = type(record) == "table" and type(record.charName) == "string" and record.charName:match("^(%S+)")
        if key ~= myKey and recordFirst and recordFirst:lower() == first
            and (record.realm == nil or record.realm == myRealm) then
            if found then
                return nil -- two of yours share the first name: don't guess
            end
            found = record
        end
    end
    return found
end

local function CommitSend()
    local attached = sending and sending.items or outgoing
    local to = OwnRecord((sending and sending.to) or Recipient())
    sending, outgoing = nil, {}
    if not to then
        return
    end
    local expires = time() + MAIL_DAYS * DAY
    Items(to)
    for _, item in pairs(attached) do
        to.incoming = to.incoming or {}
        to.incoming[#to.incoming + 1] = { id = item.id, count = item.count, expires = expires }
        to.names[item.id] = item.name or to.names[item.id]
    end
    RebuildMail(to)
end

-- Search and tooltip ----------------------------------------------------------------------------------

-- The name saved in the record; older records only have the "Name-Realm" key to go by
-- (shown whole, or just the name part when short is set).
local function DisplayName(key, data, short)
    if type(data) == "table" and type(data.charName) == "string" and data.charName ~= "" then
        return data.charName
    end
    key = tostring(key)
    return short and key:match("^[^-]+") or key
end

-- Mail expiry ------------------------------------------------------------------------------------------

local function LeftText(seconds)
    if seconds < 3600 then
        return "in under an hour"
    elseif seconds < DAY then
        local hours = math.floor(seconds / 3600)
        return string.format("in %d hour%s", hours, hours == 1 and "" or "s")
    end
    local days = math.floor(seconds / DAY)
    return string.format("in %d day%s", days, days == 1 and "" or "s")
end

local function MoneyText(copper)
    local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if gold > 0 then
        return string.format("%dg %ds", gold, silver)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, rest)
    end
    return string.format("%dc", rest)
end

-- Every character's stored mail that expires within `within` seconds (nil = any), soonest first:
-- { { name, items = n, money = copper, soonest = expires } }. Read from what was saved when each mailbox
-- was last opened (and mail you sent to your own characters).
local function ExpiringMail(within)
    local now = time()
    local list = {}
    for key, record in pairs(ItemFinderDB or {}) do
        if type(record) == "table" then
            local entry = { name = DisplayName(key, record), items = 0, money = 0 }
            local function consider(expires)
                if type(expires) == "number" and expires > now and (not within or expires - now <= within) then
                    entry.soonest = math.min(entry.soonest or expires, expires)
                    return true
                end
            end
            for _, field in ipairs({ "inbox", "incoming" }) do
                for _, mail in ipairs(type(record[field]) == "table" and record[field] or {}) do
                    if type(mail) == "table" and consider(mail.expires) then
                        entry.items = entry.items + (tonumber(mail.count) or 1)
                    end
                end
            end
            for _, mail in ipairs(type(record.mailMoney) == "table" and record.mailMoney or {}) do
                if type(mail) == "table" and type(mail.money) == "number" and consider(mail.expires) then
                    entry.money = entry.money + mail.money
                end
            end
            if entry.soonest then
                list[#list + 1] = entry
            end
        end
    end
    table.sort(list, function(a, b)
        if a.soonest ~= b.soonest then
            return a.soonest < b.soonest
        end
        return a.name < b.name
    end)
    return list, now
end

local function ExpiringEntryText(entry, now)
    local parts = {}
    if entry.items > 0 then
        parts[#parts + 1] = string.format("%d item%s", entry.items, entry.items == 1 and "" or "s")
    end
    if entry.money > 0 then
        parts[#parts + 1] = MoneyText(entry.money)
    end
    return string.format("%s: %s, first %s", entry.name, table.concat(parts, " and "), LeftText(entry.soonest - now))
end

-- One line about mail running out in the next three days, or nil.
local function ExpiryWarning()
    local list, now = ExpiringMail(EXPIRY_WARN)
    if #list == 0 then
        return nil
    end
    local parts = {}
    for _, entry in ipairs(list) do
        parts[#parts + 1] = ExpiringEntryText(entry, now)
    end
    return "|cffff9933Mail expiring soon|r: " .. table.concat(parts, "; ") .. ". Take it out before it's returned or lost."
end

local function ShowExpiring()
    local list, now = ExpiringMail(nil)
    if #list == 0 then
        Print("No mail stored for any of your characters. Mail is read when you open each character's mailbox.")
        return
    end
    Print("|cffffd100Mail by character, soonest to expire first|r")
    for _, entry in ipairs(list) do
        local warn = entry.soonest - now <= EXPIRY_WARN and "|cffff9933" or ""
        Print(warn .. ExpiringEntryText(entry, now) .. (warn ~= "" and "|r" or ""))
    end
    Print("|cff999999As of the last time each mailbox was opened; mail taken out on another computer may still be listed.|r")
end

-- Counts of one item on a record, by ID (or by name in an old record). Returns { [place] = n }.
local function CountsOn(record, id, name)
    local counts = {}
    local items = type(record.items) == "table" and record.items or {}
    for _, place in ipairs(PLACES) do
        local byID = type(items[place]) == "table" and id and items[place][id]
        local legacy = LEGACY[place] and type(record[LEGACY[place]]) == "table" and name and record[LEGACY[place]][name]
        local n = (type(byID) == "number" and byID or 0) + (type(legacy) == "number" and legacy or 0)
        if n > 0 then
            counts[place] = n
        end
    end
    return counts
end

local function Search(term)
    -- "#2589", "2589" or a shift-clicked link searches by item ID; anything else by part of the name.
    local wantID = IDOf(term) or tonumber(term:match("^#?(%d+)$"))
    local needle = term:lower()
    local matches = {}
    local function report(character, place, name, count)
        matches[#matches + 1] = { name = name, character = character, count = count, place = PLACE_LABEL[place] or place }
    end
    for key, data in pairs(ItemFinderDB) do
        if type(data) == "table" then
            local character = DisplayName(key, data)
            local names = type(data.names) == "table" and data.names or {}
            for _, place in ipairs(PLACES) do
                local byID = type(data.items) == "table" and data.items[place]
                for id, count in pairs(type(byID) == "table" and byID or {}) do
                    local name = names[id] or ("item " .. id)
                    if (wantID and id == wantID) or (not wantID and name:lower():find(needle, 1, true)) then
                        report(character, place, name, count)
                    end
                end
                local legacy = LEGACY[place] and data[LEGACY[place]]
                for name, count in pairs(type(legacy) == "table" and legacy or {}) do
                    if not wantID and type(name) == "string" and name:lower():find(needle, 1, true) then
                        report(character, place, name, count)
                    end
                end
            end
        end
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
    -- The search page is ItemFinder's window, so mail about to expire is shown on top of every search.
    local warning = ExpiryWarning()
    if warning then
        Print(warning .. " |cff999999Type: " .. EXPIRING_COMMAND .. "|r")
    end
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

local function OwnedElsewhereText(id, name)
    local mine = ItemFinderDB[myKey]
    local parts = {}
    local elsewhere = false
    if mine then
        local counts = CountsOn(mine, id, name)
        for _, place in ipairs(PLACES) do
            if counts[place] and place ~= "gear" then
                parts[#parts + 1] = PLACE_LABEL[place] .. " " .. counts[place]
                elsewhere = elsewhere or place ~= "bags"
            end
        end
    end
    local others = {}
    for character, data in pairs(ItemFinderDB) do
        if character ~= myKey and type(data) == "table" then
            local count = 0
            for _, n in pairs(CountsOn(data, id, name)) do
                count = count + n
            end
            if count > 0 then
                others[#others + 1] = DisplayName(character, data, true) .. " " .. count
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
    local name, link, id = TooltipUtil.GetDisplayedItem(tooltip)
    name, link, id = Safe(name), Safe(link), Safe(id)
    id = type(id) == "number" and id or IDOf(link)
    local text = (id or (type(name) == "string" and name ~= "")) and OwnedElsewhereText(id, type(name) == "string" and name or nil)
    if text then
        tooltip:AddLine("Owned: " .. text, 0.6, 0.8, 1)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
-- Listed as unverified on Forever, so a missing event must not stop the addon.
for _, name in ipairs({ "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "MAIL_SHOW", "MAIL_CLOSED",
    "MAIL_INBOX_UPDATE", "MAIL_SEND_INFO_UPDATE", "MAIL_LOCK_SEND_ITEMS", "MAIL_SEND_SUCCESS", "MAIL_FAILED" }) do
    pcall(events.RegisterEvent, events, name)
end
events:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "PLAYER_LOGIN" then
        ItemFinderDB = ItemFinderDB or {}
        local key = ForeverCharacterAdopt(ItemFinderDB)
        ItemFinderDB[key] = ItemFinderDB[key] or {}
        charData = ForeverCharacterStamp(ItemFinderDB[key])
        myKey = key
        charData.faction = Call(UnitFactionGroup, "player") or charData.faction
        charData.realm = Call(GetRealmName) or charData.realm
        -- Characters not seen for three months are most likely deleted; keep their names out of tooltips.
        charData.lastSeen = time()
        local cutoff = time() - 90 * DAY
        for other, record in pairs(ItemFinderDB) do
            if other ~= key and type(record) == "table" then
                if type(record.lastSeen) ~= "number" then
                    record.lastSeen = time()
                elseif record.lastSeen < cutoff then
                    ItemFinderDB[other] = nil
                end
            end
            -- Mail that has expired since is gone (returned or deleted). A saved entry that isn't a
            -- character record is skipped, as every other reader of ItemFinderDB does.
            if type(record) == "table" and ItemFinderDB[other] and (record.inbox or record.incoming or record.mailMoney) then
                RebuildMail(record)
            end
        end
        -- The Tooltips helper shows counts on every character (and can switch them off); only add our own line without it.
        if not (SlashCmdList and SlashCmdList.TOOLTIPS) and TooltipDataProcessor and TooltipUtil and Enum and Enum.TooltipDataType then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltip)
        end
        SaveBags()
        SaveGear()
        -- One pop-up per login when any character's mail runs out within three days.
        if not warnedThisLogin then
            warnedThisLogin = true
            local function warn()
                local text = ExpiryWarning()
                if text then
                    Print(text .. " Details on the Find an item page: type " .. EXPIRING_COMMAND .. ".")
                end
            end
            if C_Timer and C_Timer.After then
                C_Timer.After(LOGIN_WARN_DELAY, warn)
            else
                warn()
            end
        end
        return
    end
    if not charData then
        return
    end
    if event == "BAG_UPDATE_DELAYED" then
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
    elseif event == "PLAYERBANKSLOTS_CHANGED" then
        SaveBank()
    elseif event == "MAIL_INBOX_UPDATE" then
        SaveInbox()
    elseif event == "MAIL_SHOW" or event == "MAIL_CLOSED" then
        outgoing, sending = {}, nil
    elseif event == "MAIL_SEND_INFO_UPDATE" then
        -- The game empties the attachments just before MAIL_SEND_SUCCESS; keep the last full list.
        local found = ReadAttachments()
        if next(found) or not sending then
            outgoing = found
        end
    elseif event == "MAIL_LOCK_SEND_ITEMS" then
        -- Sending has started: the attachments and the "To:" name as they are now.
        if not sending then
            sending = { items = ReadAttachments(), to = Recipient() }
        end
        local slot, link = Safe(arg1), Safe(arg2)
        local id = IDOf(link)
        if type(slot) == "number" and id and not sending.items[slot] then
            sending.items[slot] = { id = id, count = AttachmentCount(GetSendMailItem, slot), name = NameOf(link) }
        end
    elseif event == "MAIL_FAILED" then
        -- Nothing was sent; a retry starts again from the lock or the next attachment change.
        sending, outgoing = nil, {}
    elseif event == "MAIL_SEND_SUCCESS" then
        CommitSend()
    end
end)

SLASH_ITEMFINDER1 = "/find"
SlashCmdList.ITEMFINDER = function(message)
    local term = message:match("^%s*(.-)%s*$")
    if not charData then
        return
    end
    if term == "" then
        Print("Use /find <part of an item name, an item ID, or a shift-clicked item>. Bank items appear after you've opened that character's bank, mail after you've opened its mailbox. Type " .. EXPIRING_COMMAND .. " to see when each character's mail runs out.")
        local warning = ExpiryWarning()
        if warning then
            Print(warning)
        end
    elseif term:lower() == EXPIRING_COMMAND then
        ShowExpiring()
    else
        Search(term)
    end
end
