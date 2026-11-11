-- Round 5 #4 and #14: GoldGoal sorts money changes by the window that was open (no hooks), tells repairs from
-- purchases by durability, reads auction invoices from the inbox (read only) and shows them on its page.
-- Run from the harness folder:  node run.js "<workspace root>" test_r5b_goldgoal.lua
local base = ADDON_PATH
local SECRET = {}
local DAY = 86400
local out, failures, forbidden = {}, {}, {}
local realPrint = print
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
issecretvalue = function(v) return v == SECRET end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
for _, name in ipairs({ "hooksecurefunc", "TakeInboxMoney", "TakeInboxItem", "AutoLootMailItem", "DeleteInboxItem",
    "ReturnInboxItem", "RepairAllItems", "BuyMerchantItem", "print" }) do
    _G[name] = function() forbidden[#forbidden + 1] = name end
end
local frame
CreateFrame = function()
    frame = { registered = {} }
    frame.RegisterEvent = function(self, e) self.registered[e] = true end
    frame.SetScript = function(self, _, fn) self.fn = fn end
    return frame
end
SlashCmdList = {}
UnitName = function() return "Ann" end
UnitGUID = function() return "Player-1-0001" end
GetRealmName = function() return "R" end
UnitClass = function() return "Priest", "PRIEST" end
local level = 11
UnitLevel = function() return level end
C_SkillInfo = { GetSkillLineInfoByID = function() return nil end }
local clock, now = 1000, 100 * DAY + 3600
GetTime = function() return clock end
time = function() return now end
local money = 10000
GetMoney = function() return money end
local durability = { [1] = 50 }
GetInventoryItemDurability = function(slot) local d = durability[slot]; if d then return d, 100 end end

-- Inbox (read-only globals).
local inbox = {}
GetInboxNumItems = function() return #inbox end
GetInboxHeaderInfo = function(i) local m = inbox[i]; return nil, nil, "Auction House", "Sold", m.money, 0, m.days, false end
GetInboxInvoiceInfo = function(i)
    local v = inbox[i].invoice
    if v then return v.kind, v.item, "Buyer", v.bid, v.bid + 500, v.deposit, v.cut, 0, 0, 0, v.count end
end

assert(loadfile(base .. "/GoldGoal/GoldGoal.lua"))("GoldGoal", {})
local f = frame
for _, e in ipairs({ "PLAYER_MONEY", "MERCHANT_SHOW", "MERCHANT_CLOSED", "MAIL_SHOW", "MAIL_INBOX_UPDATE", "TAXIMAP_CLOSED",
    "LOOT_OPENED", "QUEST_TURNED_IN", "UPDATE_INVENTORY_DURABILITY", "AUCTION_HOUSE_SHOW", "TRAINER_SHOW", "TRADE_SHOW" }) do
    check(f.registered[e], "registers " .. e)
end
for e in pairs(f.registered) do
    check(not e:find("^COMBAT_LOG"), "no combat log event: " .. e)
end
local function fire(event, ...) f.fn(f, event, ...) end
local function pay(delta) money = money + delta; fire("PLAYER_MONEY") end
local function page(arg) out = {}; SlashCmdList.GOLDGOAL(arg); return table.concat(out, "\n") end
fire("PLAYER_LOGIN")
local rec = GoldGoalDB["Player-1-0001"]
local today = math.floor(now / DAY)
local function day() return rec.money.days[math.floor(now / DAY)] or {} end

----- Vendor: sales, purchases, and repairs told apart by durability
fire("MERCHANT_SHOW")
pay(500)
check(day().vendorSell == 500, "sold to a vendor")
pay(-200)                                   -- the money first ...
clock = clock + 0.5
durability[1] = 60
fire("UPDATE_INVENTORY_DURABILITY")         -- ... then the durability rises: a repair
check(day().repair == -200 and (day().vendorBuy or 0) == 0, "money then durability: repair, got repair " .. tostring(day().repair) .. " buy " .. tostring(day().vendorBuy))
durability[1] = 70                          -- durability first, then the money
pay(-100)
check(day().repair == -300, "durability then money: repair")
pay(-40)                                    -- a plain purchase
clock = clock + 3
fire("UPDATE_INVENTORY_DURABILITY")
check(day().vendorBuy == -40 and day().repair == -300, "a purchase stays a purchase")
fire("MERCHANT_CLOSED")
clock = clock + 0.5
pay(50)
check(day().vendorSell == 550, "money just after closing still counts for the vendor")
clock = clock + 5
pay(30)
check(day().otherGain == 30, "nothing open: other gain")

----- Flight, quest, loot, trainer, auction house, trade
fire("TAXIMAP_OPENED"); fire("TAXIMAP_CLOSED")
clock = clock + 1
pay(-80)
check(day().flight == -80, "flight paid just after the map closed")
clock = clock + 10
fire("QUEST_TURNED_IN", 123, 400, 1000)
clock = clock + 1
pay(1000)
check(day().quest == 1000, "quest reward")
clock = clock + 10
fire("LOOT_OPENED"); pay(25); fire("LOOT_CLOSED")
check(day().loot == 25, "looted money")
clock = clock + 10
fire("TRAINER_SHOW"); pay(-300); fire("TRAINER_CLOSED")
check(day().trainer == -300, "training")
clock = clock + 10
fire("AUCTION_HOUSE_SHOW"); pay(-150)
check(day().auction == -150, "auction house deposit")
fire("AUCTION_HOUSE_CLOSED")
clock = clock + 10
fire("TRADE_SHOW"); pay(700); fire("TRADE_CLOSED")
check(day().trade == 700, "trade")

----- Invoices: read once, matched to the money taken from the mail
clock = clock + 10
inbox = {
    { money = 1900, days = 29.5, invoice = { kind = "seller", item = "Linen Cloth", bid = 2000, deposit = 100, cut = 200, count = 20 } },
    { money = 500, days = 10 },
    { money = 0, days = 29, invoice = { kind = "buyer", item = "Wool Cloth", bid = 900, deposit = 0, cut = 0, count = 1 } },
}
fire("MAIL_SHOW")
fire("MAIL_INBOX_UPDATE")
check(rec.sales and #rec.sales == 1, "one seller invoice saved, buyer invoices skipped")
local sale = rec.sales and rec.sales[1] or {}
check(sale.item == "Linen Cloth" and sale.price == 2000 and sale.cut == 200 and sale.net == 1900 and sale.count == 20, "invoice fields")
check(sale.at and math.abs(sale.at - (now - 0.5 * DAY)) < 2, "arrival worked out from days left")
now, clock = now + 60, clock + 60
inbox[1].days = 29.5 - 60 / DAY
fire("MAIL_INBOX_UPDATE")
check(#rec.sales == 1, "the same invoice read again isn't added twice")
pay(1900)
check(day().auctionSale == 1900 and rec.sales[1].taken, "money matching the invoice is an auction sale")
pay(500)
check(day().mail == 500, "other mail money")
pay(-30)
check(day().mail == 470, "postage at the mailbox")
fire("MAIL_CLOSED")

----- Unreadable money: skipped, then counted once readable again
clock = clock + 10
local real = GetMoney
GetMoney = function() return SECRET end
money = money + 60
fire("PLAYER_MONEY")
GetMoney = real
fire("PLAYER_MONEY")
check(day().otherGain == 90, "the hidden change is counted at the next readable one")
fire("PLAYER_MONEY", SECRET)

----- Level buckets and totals
check(rec.money.levels[11] and rec.money.levels[11].quest == 1000, "level bucket")
level = 12
fire("PLAYER_LEVEL_UP", 12)
pay(5)
check(rec.money.levels[12] and rec.money.levels[12].otherGain == 5, "next level's bucket")
check(rec.money.total.quest == 1000 and rec.money.total.repair == -300, "all-time totals")

----- The page
local text = page("")
check(text:find("Today", 1, true) and text:find("Quests +10s 0c", 1, true), "goal page shows today's sources:\n" .. text)
check(text:find("Last auction sale", 1, true) and text:find("Linen Cloth x20", 1, true), "goal page shows the last sale:\n" .. text)
text = page("sources")
check(text:find("Repairs -3s 0c", 1, true) and text:find("Flights -80c", 1, true) and text:find("Auction sales +19s 0c", 1, true), "sources page:\n" .. text)
check(text:find("Since this was installed", 1, true), "all-time line")
text = page("sales")
check(text:find("Linen Cloth x20: sold for 0g 20s, you get 0g 19s (cut 2s 0c)", 1, true), "sales page:\n" .. text)
text = page("2.5 Bags")
check(text:find("Enter whole gold", 1, true), "bad goal still refused")

----- Played time and the 7-day rate in the ETA
fire("PLAYER_LOGOUT")
check((day().secs or 0) > 0, "played seconds saved per day")

----- Bounds: 14 days, 30 sales
for i = 1, 20 do
    now = now + DAY
    pay(1)
end
local n = 0
for _ in pairs(rec.money.days) do n = n + 1 end
check(n <= 14, "days kept to 14, got " .. n)
inbox = {}
for i = 1, 40 do
    inbox[i] = { money = 100 + i, days = 30 - i / 10, invoice = { kind = "seller", item = "Item " .. i, bid = 100 + i, deposit = 0, cut = 0, count = 1 } }
end
fire("MAIL_INBOX_UPDATE")
check(#rec.sales == 30, "sales kept to 30, got " .. #rec.sales)
check(rec.sales[#rec.sales].item == "Item 1", "newest kept last")

----- Missing invoice API: quiet
GetInboxInvoiceInfo = nil
fire("MAIL_INBOX_UPDATE")
GetInboxInvoiceInfo = function() error("boom") end
fire("MAIL_INBOX_UPDATE")
GetInventoryItemDurability = nil
fire("MERCHANT_SHOW"); pay(-10); fire("UPDATE_INVENTORY_DURABILITY")

check(#forbidden == 0, "forbidden calls: " .. table.concat(forbidden, ", "))
if #failures > 0 then
    realPrint("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do realPrint(" - " .. why) end
    os.exit(1)
end
realPrint("test_r5b_goldgoal: all checks passed")
