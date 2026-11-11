-- Round 5 #14: ItemFinder warns about mail (items or money) that expires within three days on any character:
-- once per login as a pop-up, on top of every search, and on its "expiring" page. Nothing is taken from the mail.
-- Run from the harness folder:  node run.js "<workspace root>" test_r5b_itemfinder_mail.lua
local DAY = 86400
local out, failures, forbidden, frames = {}, {}, {}, {}
local realPrint = print
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
issecretvalue = function() return false end
geterrorhandler = function() return function(e) failures[#failures + 1] = "error: " .. tostring(e) end end
ForeverHub_Receive = function(_, text) out[#out + 1] = text end
for _, name in ipairs({ "hooksecurefunc", "TakeInboxItem", "TakeInboxMoney", "AutoLootMailItem", "ReturnInboxItem", "DeleteInboxItem", "print" }) do
    _G[name] = function() forbidden[#forbidden + 1] = name end
end
CreateFrame = function()
    local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(_, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
local timers = {}
C_Timer = { After = function(seconds, fn) timers[#timers + 1] = { seconds = seconds, fn = fn } end }
SlashCmdList = {}
local clock = 1000000
time = function() return clock end
UnitName = function(u) if u == "player" then return "Juan" end end
UnitGUID = function(u) if u == "player" then return "Player-1-0001" end end
GetRealmName = function() return "R" end
UnitFactionGroup = function() return "Alliance" end
Enum = { BagIndex = { Backpack = 0 } }
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = function() end }
GetInventoryItemLink = function() end

local function link(id, name) return "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. name .. "]|h|r" end
local inbox = {}
GetInboxNumItems = function() return #inbox end
GetInboxHeaderInfo = function(i) local m = inbox[i]; return nil, nil, "Sender", "Subject", m.money or 0, 0, m.days, m.items and #m.items > 0 end
GetInboxItem = function(i, a) local it = inbox[i].items and inbox[i].items[a]; if it then return "n", it.id, nil, it.count end end
GetInboxItemLink = function(i, a) local it = inbox[i].items and inbox[i].items[a]; return it and link(it.id, it.name) end
ATTACHMENTS_MAX_RECEIVE = 16

-- An alt whose mail was saved on an earlier login: 2 ore expiring in 1.5 days, cloth in 20 days.
ItemFinderDB = {
    ["Player-1-0002"] = { charName = "Alt Two", charGUID = "Player-1-0002", lastSeen = clock,
        items = { mail = { [2770] = 2, [2589] = 5 } }, names = { [2770] = "Copper Ore", [2589] = "Linen Cloth" },
        inbox = { { id = 2770, count = 2, expires = clock + 1.5 * DAY }, { id = 2589, count = 5, expires = clock + 20 * DAY } } },
}
assert(loadfile(ADDON_PATH .. "/ItemFinder/ItemFinder.lua"))("ItemFinder", {})
local ev = frames[#frames]
local function fire(e, ...) local ok, err = pcall(ev.fn, ev, e, ...); check(ok, e .. ": " .. tostring(err)) end
local function find(term) out = {}; SlashCmdList.ITEMFINDER(term); return table.concat(out, "\n") end

----- Login: one delayed pop-up
fire("PLAYER_LOGIN")
check(#out == 0, "nothing shown at once: the pop-up waits for the hub")
check(#timers == 1 and timers[1].seconds >= 5, "one delayed check")
timers[1].fn()
local popup = table.concat(out, "\n")
check(popup:find("Mail expiring soon", 1, true) and popup:find("Alt Two: 2 items, first in 1 day", 1, true), "pop-up names the alt: " .. popup)
check(not popup:find("Linen", 1, true), "mail with weeks left isn't in the warning")
out, timers = {}, {}
fire("PLAYER_LOGIN")
check(#timers == 0, "only once per login session")

----- This character's mailbox: money mail and items, both kept with their expiry
inbox = {
    { days = 0.25, money = 35000 },                                                     -- 3g 50s, 6 hours left
    { days = 2.5, items = { { id = 2589, count = 3, name = "Linen Cloth" } } },
    { days = 25, money = 100 },
}
fire("MAIL_SHOW")
fire("MAIL_INBOX_UPDATE")
local mine = ItemFinderDB["Player-1-0001"]
check(mine.mailMoney and #mine.mailMoney == 2, "money mail kept for the warning")
check(mine.items.mail[2589] == 3, "items still counted as before")

----- Every search starts with the warning
local text = find("linen")
check(text:find("Mail expiring soon", 1, true), "search shows the warning: " .. text)
check(text:find("Juan: 3 items and 3g 50s, first in 6 hours", 1, true), "own mail: items and money, soonest first: " .. text)
check(text:find("Linen Cloth: Juan x3 (mail)", 1, true), "search results still there")
local first = text:find("Juan:", 1, true)
local second = text:find("Alt Two:", 1, true)
check(first and second and first < second, "soonest first")

----- The expiring page lists all mail, soonest first
text = find("expiring")
check(text:find("Mail by character", 1, true), "page title: " .. text)
check(text:find("Alt Two: 7 items, first in 1 day", 1, true), "the alt's mail, all of it: " .. text)
check(text:find("Juan: 3 items and 3g 51s, first in 6 hours", 1, true), "own mail, all of it: " .. text)

----- Time passes: expired mail drops out, the warning goes when nothing is close
clock = clock + 3 * DAY
fire("PLAYER_LOGIN")
check(mine.mailMoney and #mine.mailMoney == 1 and mine.mailMoney[1].money == 100, "expired money mail dropped")
text = find("linen")
check(not text:find("Mail expiring soon", 1, true), "no warning when nothing runs out soon: " .. text)
text = find("")
check(text:find("expiring", 1, true), "the help line names the page")

----- Bound: money mail kept per character
inbox = {}
for i = 1, 80 do inbox[i] = { days = 10, money = i } end
fire("MAIL_INBOX_UPDATE")
check(#mine.mailMoney <= 50, "money mail bounded, got " .. #mine.mailMoney)

----- Garbage in saved data doesn't break the warning
ItemFinderDB["junk"] = { mailMoney = "x", inbox = { "y", { expires = "z" } } }
ItemFinderDB["Player-1-0002"].mailMoney = { { money = "a", expires = clock + DAY } }
text = find("ore")
check(type(text) == "string", "garbage tolerated")

check(#forbidden == 0, "forbidden calls: " .. table.concat(forbidden, ", "))
if #failures > 0 then
    realPrint("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do realPrint(" - " .. why) end
    os.exit(1)
end
realPrint("test_r5b_itemfinder_mail: all checks passed")
