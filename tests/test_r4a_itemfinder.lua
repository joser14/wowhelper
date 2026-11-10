-- Round 4 R14 (the "item 12" ItemFinder entry of the brief): ItemFinder keys by item ID, adds the keyring and
-- equipped bags, the inbox (with expiry), and mail you send to your own characters without any hook: attachments
-- are read on MAIL_LOCK_SEND_ITEMS / MAIL_SEND_INFO_UPDATE and committed on MAIL_SEND_SUCCESS (MailInfoDocumentation).
-- Old name-keyed records are kept until the first rescan; faction and scan time are stored per character.
local out, handled, frames = {}, {}, {}
issecretvalue = function() return false end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
ForeverHub_Receive = function(_, text) out[#out + 1] = text end
local realPrint, forbidden = print, {}
for _, name in ipairs({ "hooksecurefunc", "SendMail", "TakeInboxItem", "AutoLootMailItem", "ReturnInboxItem", "DeleteInboxItem", "print" }) do
    _G[name] = function() forbidden[#forbidden + 1] = name end
end
CreateFrame = function()
    local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(_, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
local clock = 1000000
time = function() return clock end
local me = { name = "Juan", guid = "Player-1-0001", faction = "Alliance" }
UnitName = function(u) if u == "player" then return me.name end end
UnitGUID = function(u) if u == "player" then return me.guid end end
GetRealmName = function() return "R" end
UnitFactionGroup = function() return me.faction end
Enum = { BagIndex = { Keyring = -1, Backpack = 0, Bag_1 = 1, ReagentBag = 5, CharacterBankTab_1 = 6 } }
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
NUM_BAG_SLOTS = 4

local function link(id, name) return "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. name .. "]|h|r" end
local LINEN, KEY, BAG, SWORD, ORE = link(2589, "Linen Cloth"), link(5396, "Key to Searing Gorge"), link(4496, "Small Brown Pouch"), link(9999, "Big Sword"), link(2770, "Copper Ore")
local containers = { [0] = { { LINEN, 5 }, { LINEN, 3 } }, [-1] = { { KEY, 1 } }, [6] = { { LINEN, 7 } } }
local bankOpen = false
C_Container = {
    GetContainerNumSlots = function(bag)
        if bag == 6 and not bankOpen then return 0 end
        return containers[bag] and 16 or 0
    end,
    GetContainerItemInfo = function(bag, slot)
        local entry = containers[bag] and containers[bag][slot]
        return entry and { hyperlink = entry[1], stackCount = entry[2] } or nil
    end,
    ContainerIDToInventoryID = function(bag) return 19 + bag end,
}
GetKeyRingSize = function() return 4 end
local worn = { [16] = SWORD, [20] = BAG }
GetInventoryItemLink = function(_, slot) return worn[slot] end

-- Mail (classic globals, guarded in the addon).
local inbox = {}
GetInboxNumItems = function() return #inbox end
GetInboxHeaderInfo = function(i) local m = inbox[i]; return nil, nil, "Sender", "Subject", 0, 0, m.days, true end
GetInboxItem = function(i, a) local it = inbox[i].items[a]; if it then return "n", it.id, nil, it.count end end
GetInboxItemLink = function(i, a) local it = inbox[i].items[a]; return it and it.link end
ATTACHMENTS_MAX_RECEIVE, ATTACHMENTS_MAX_SEND = 16, 12
local sending = {}
GetSendMailItem = function(a) local it = sending[a]; if it then return "n", it.id, nil, it.count end end
GetSendMailItemLink = function(a) return sending[a] and sending[a].link end
local recipient = ""
SendMailNameEditBox = { GetText = function() return recipient end }

assert(loadfile(ADDON_PATH .. "/ItemFinder/ItemFinder.lua"))("ItemFinder", {})
local ev = frames[#frames]
local function fire(e, ...) local ok, err = pcall(ev.fn, ev, e, ...); assert(ok, e .. ": " .. tostring(err)) end
local function find(term) out = {}; SlashCmdList.ITEMFINDER(term); return table.concat(out, "\n") end

-- An old name-keyed record for an alt, and an old one for this character.
ItemFinderDB = {
    ["Player-1-0002"] = { charName = "Alt Two", charGUID = "Player-1-0002", bags = { ["Linen Cloth"] = 4 }, lastSeen = clock },
    ["Player-1-0001"] = { charName = "Juan", charGUID = "Player-1-0001", bags = { ["Linen Cloth"] = 99 }, bank = { ["Linen Cloth"] = 2 }, lastSeen = clock },
}
fire("PLAYER_LOGIN")
local mine = ItemFinderDB["Player-1-0001"]

-- 1. By item ID, with keyring and equipped bags; the old bag record is replaced by the rescan, bank names kept.
assert(mine.items and mine.items.bags[2589] == 8, "bags by ID: " .. tostring(mine.items and mine.items.bags[2589]))
assert(mine.names[2589] == "Linen Cloth", "names remembered by ID")
assert(mine.items.keys[5396] == 1, "keyring counted")
assert(mine.items.gear[9999] == 1 and mine.items.gear[4496] == 1, "worn gear and equipped bags counted")
assert(mine.bags == nil, "old name-keyed bags dropped after the rescan")
assert(mine.bank and mine.bank["Linen Cloth"] == 2, "old bank names kept until the bank is opened")
assert(mine.faction == "Alliance" and mine.scanTime == clock, "faction and scan time stored")
local text = find("linen")
assert(text:find("Linen Cloth: Juan x8 (bags)", 1, true), text)
assert(text:find("Linen Cloth: Juan x2 (bank)", 1, true), "old bank record still found: " .. text)
assert(text:find("Linen Cloth: Alt Two x4 (bags)", 1, true), "alt's old record still found: " .. text)
text = find("key to")
assert(text:find("(keyring)", 1, true), text)
-- Search by an item link (shift-click) or ID finds the item even when names differ.
text = find(link(2589, "Renamed Cloth"))
assert(text:find("Juan x8 (bags)", 1, true), "search by link uses the ID: " .. text)
text = find("#5396")
assert(text:find("Juan x1 (keyring)", 1, true), "search by #ID: " .. text)

-- 2. Opening the bank replaces the old bank names with IDs.
bankOpen = true
fire("BANKFRAME_OPENED")
assert(mine.items.bank[2589] == 7 and mine.bank == nil, "bank by ID")

-- 3. Inbox: counted with expiry, gone when expired.
inbox = { { days = 2, items = { { id = 2770, count = 10, link = ORE } } }, { days = 29.5, items = { { id = 2589, count = 1, link = LINEN } } } }
fire("MAIL_SHOW")
fire("MAIL_INBOX_UPDATE")
assert(mine.items.mail[2770] == 10 and mine.items.mail[2589] == 1, "inbox counted")
text = find("copper")
assert(text:find("Copper Ore: Juan x10 (mail)", 1, true), text)
clock = clock + 3 * 86400
fire("PLAYER_LOGIN")
assert(mine.items.mail[2770] == nil and mine.items.mail[2589] == 1, "expired mail dropped at login")

-- 4. Sending to your own alt: committed only on success, to the alt's record, with a 30-day expiry.
recipient = "Alt"
sending = { [1] = { id = 2770, count = 5, link = ORE } }
fire("MAIL_SEND_INFO_UPDATE")
fire("MAIL_LOCK_SEND_ITEMS", 1, ORE)
sending = {}
fire("MAIL_SEND_INFO_UPDATE") -- the game clears the attachments before the success event
fire("MAIL_SEND_SUCCESS")
local alt = ItemFinderDB["Player-1-0002"]
assert(alt.items and alt.items.mail[2770] == 5, "mail to the alt counted on the alt")
assert(alt.incoming and alt.incoming[1].expires == clock + 30 * 86400, "30-day expiry")
-- A failed send adds nothing.
sending = { [1] = { id = 2589, count = 2, link = LINEN } }
fire("MAIL_SEND_INFO_UPDATE")
fire("MAIL_LOCK_SEND_ITEMS", 1, LINEN)
fire("MAIL_FAILED")
fire("MAIL_SEND_SUCCESS")
assert(alt.items.mail[2589] == nil, "failed send not counted")
-- Mail to someone who isn't one of yours isn't tracked.
recipient = "Stranger"
sending = { [1] = { id = 2589, count = 2, link = LINEN } }
fire("MAIL_SEND_INFO_UPDATE")
fire("MAIL_SEND_SUCCESS")
local records = 0; for _ in pairs(ItemFinderDB) do records = records + 1 end
assert(records == 2 and alt.items.mail[2589] == nil, "nothing recorded for a stranger")

-- 5. The alt logs in and opens its mailbox: the inbox scan replaces the guess from the send.
me = { name = "Alt", guid = "Player-1-0002", faction = "Alliance" }
worn, containers, bankOpen = {}, { [0] = {} }, false
fire("PLAYER_LOGIN")
inbox = { { days = 30, items = { { id = 2770, count = 5, link = ORE } } } }
fire("MAIL_SHOW")
fire("MAIL_INBOX_UPDATE")
assert(alt.items.mail[2770] == 5 and (alt.incoming == nil or #alt.incoming == 0), "inbox scan replaces incoming")

assert(#forbidden == 0, "forbidden calls: " .. table.concat(forbidden, ", "))
assert(#handled == 0, "errors: " .. table.concat(handled, "\n"))
realPrint("test_r4a_itemfinder: ok")
