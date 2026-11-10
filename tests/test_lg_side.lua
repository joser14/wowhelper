-- Side steps beside the current step: "on the way" (sticky over the next few steps) and "for later"
-- (shopping at a vendor or the auction house, bags, keep an item, class trainer visits), all completed by
-- watching only. Plus class filters. ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
-- Read-only: none of these may ever be called.
for _, name in ipairs({ "BuyMerchantItem", "BuyTrainerService", "AcceptQuest", "CompleteQuest", "GetQuestReward",
    "TargetUnit", "CastSpellByName", "UseContainerItem", "PlaceAuctionBid", "SelectGossipOption" }) do
    _G[name] = function() error("forbidden call: " .. name) end
end
C_AuctionHouse = setmetatable({}, { __index = function(_, k) return function() error("forbidden C_AuctionHouse." .. k) end end })
C_Container.UseContainerItem = function() error("forbidden UseContainerItem") end
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.best, M.pos, M.level = 1438, { [1438] = { 0.5, 0.5 } }, 6
local function A(q, npc, x, y, lvl) return { t = "accept", q = q, npc = npc, x = x, y = y, lvl = lvl } end
local function D(q, note, x, y, lvl) return { t = "do", q = q, note = note, x = x, y = y, lvl = lvl } end
local function T(q, npc, x, y, lvl) return { t = "turnin", q = q, npc = npc, x = x, y = y, lvl = lvl } end
local R
M.load(ADDON_PATH, function()
    R = { zone = "Teldrassil", min = 1, max = 20, steps = {} }
    LevelGuideRoutes.chains.NightElf = { R }
    LevelGuideQuestIDs, LevelGuidePrereqs = { ids = {}, renamed = {} }, nil
end)
local function set(steps) R.steps = steps; M.update() end
local function rows()
    local t = {}
    for _, b in ipairs(M.buttons) do if b.shown and b.step then t[#t + 1] = b.left.text end end
    return table.concat(t, "\n")
end
local function sideRow(pattern)
    for _, b in ipairs(M.buttons) do
        if b.shown and b.step and b.step.side and b.left.text:find(pattern, 1, true) then return b end
    end
end

-- 1. Sticky "on the way": an objective of a quest you hold, over the next 2 steps.
local boars = D("Boar Hunt", "Kill 6 boars on the way", 52, 52, 5)
boars.obj, boars.side, boars.span = 1, "sticky", 2
M.log = { { questID = 10, title = "Boar Hunt" }, { questID = 11, title = "Far Away" } }
M.obj[10] = { { text = "Boars slain: 2/6", finished = false, numFulfilled = 2, numRequired = 6 } }
set({ boars, D("Far Away", "Go far", 60, 60, 5), T("Far Away", "Npc A", 61, 61, 5), A("Late", "Npc B", 70, 70, 5) })
print(rows())
local row = sideRow("Boar Hunt")
assert(row and row.left.text:find("On the way", 1, true), "sticky shown as on the way:\n" .. rows())
assert(not M.current.left.text:find("Boar Hunt", 1, true), "not the main step")
assert(tostring(row.step.detail):find("2/6", 1, true), "live progress: " .. tostring(row.step.detail))
-- Its covered steps done: gone (the quest's objective is still open, but it's no longer "on the way").
M.log = { { questID = 10, title = "Boar Hunt" } }
M.char.done["Far Away"] = 1
M.update()
assert(not sideRow("Boar Hunt"), "expired after its span:\n" .. rows())
-- Objective finished: gone too.
M.char.done["Far Away"] = nil
M.log = { { questID = 10, title = "Boar Hunt" }, { questID = 11, title = "Far Away" } }
M.update()
assert(sideRow("Boar Hunt"), "back while the span is open")
M.obj[10][1].finished, M.obj[10][1].numFulfilled = true, 6
M.update()
assert(not sideRow("Boar Hunt"), "objective done")
print("1 ok")

-- 2. For later: buy at the auction house / a vendor, bags, keep an item, by item counts and bag slots.
M.log = { { questID = 11, title = "Far Away" } }
local wand = { t = "buy", text = "Lesser Magic Wand", items = { 11287, 11288 }, count = 1, where = "ah", npc = "Auctioneer, Darnassus", side = "later", lvl = 5 }
local water = { t = "buy", text = "Ice Cold Milk", items = 1179, count = 10, where = "vendor", npc = "Innkeeper Keldamyr", x = 55.6, y = 59.8, side = "later", lvl = 5 }
local bags = { t = "bags", text = "Bags", slots = 40, npc = "Aldia", x = 55.6, y = 57.1, side = "later", lvl = 5 }
local keep = { t = "keep", text = "Strange Fruit", item = 5555, forQ = "Fruit Quest", side = "later", lvl = 5 }
set({ wand, water, bags, keep, D("Far Away", "Go far", 60, 60, 5), A("Fruit Quest", "Npc F", 65, 65, 5) })
print(rows())
assert(sideRow("Lesser Magic Wand") and sideRow("Lesser Magic Wand").left.text:find("For later", 1, true), "AH buy shown")
assert(sideRow("Lesser Magic Wand").step.detail:find("Auction House", 1, true), "says where: " .. tostring(sideRow("Lesser Magic Wand").step.detail))
assert(sideRow("Ice Cold Milk") and sideRow("Ice Cold Milk").step.detail:find("0/10", 1, true), "vendor buy with count")
assert(sideRow("Bags") and sideRow("Bags").step.detail:find("16/40", 1, true), "bag slots: " .. tostring(sideRow("Bags") and sideRow("Bags").step.detail))
assert(not sideRow("Strange Fruit"), "nothing to keep without the item")
M.items[5555] = 1
M.fire("BAG_UPDATE_DELAYED"); M.update(0.2)
assert(sideRow("Strange Fruit"), "keep it while held and its quest is ahead")
M.items[11288] = 1; M.items[1179] = 10
M.fire("BAG_UPDATE_DELAYED"); M.update(0.2)
assert(not sideRow("Lesser Magic Wand") and not sideRow("Ice Cold Milk"), "bought (any of the items):\n" .. rows())
M.items[1179] = 2; M.update()
assert(not sideRow("Ice Cold Milk"), "drinking it later doesn't bring it back")
M.slots = { [0] = 16, [1] = 6, [2] = 6, [3] = 6, [4] = 6 }
M.update()
assert(not sideRow("Bags"), "40 slots")
M.log = { { questID = 11, title = "Far Away" }, { questID = 12, title = "Fruit Quest" } }
M.update()
assert(not sideRow("Strange Fruit"), "its quest taken: no more reminder")
assert(M.current.step and not M.current.step.side, "side steps never become the main step")
print("2 ok")

-- 3. Vendor visit: done on MERCHANT_CLOSED with that vendor (NPC ID read from the GUID at MERCHANT_SHOW).
local visit = { t = "vendor", text = "Sell junk and repair", npcIDs = { 6736 }, npc = "Innkeeper Keldamyr", x = 55.6, y = 59.8, side = "later", lvl = 5 }
set({ visit, D("Far Away", "Go far", 60, 60, 5) })
assert(sideRow("Sell junk"), "vendor visit shown")
M.npcGUID = "Creature-0-1-2-3-9999-0000AAAA"
M.fire("MERCHANT_SHOW"); M.npcGUID = nil; M.fire("MERCHANT_CLOSED"); M.update(0.2)
assert(sideRow("Sell junk"), "another vendor doesn't count")
M.npcGUID = "Creature-0-1-2-3-6736-0000BBBB"
M.fire("MERCHANT_SHOW"); M.npcGUID = nil; M.fire("MERCHANT_CLOSED"); M.update(0.2)
assert(not sideRow("Sell junk"), "visited:\n" .. rows())
print("3 ok")

-- 4. Class trainer visits by level, and class filters.
local function trainer(level, spells) return { t = "trainer", text = "Level " .. level .. " training", atLevel = level, lvl = level, spells = spells, cls = "PRIEST", npc = "Laurna Morninglight", x = 55.6, y = 56.8, side = "later" } end
local warrior = A("Warrior Only", "Npc W", 52, 50, 6); warrior.cls = "WARRIOR"
local priest = A("Priest Only", "Npc P", 53, 50, 6); priest.cls = { "PRIEST", "MAGE" }
set({ trainer(4, { 589 }), trainer(6, { 17 }), trainer(8, { 139 }), warrior, priest, D("Far Away", "Go far", 60, 60, 5) })
print(rows())
assert(sideRow("Level 6 training") and not sideRow("Level 4 training") and not sideRow("Level 8 training"), "only the latest level you've reached:\n" .. rows())
assert(not rows():find("Warrior Only", 1, true) and rows():find("Priest Only", 1, true), "class filter:\n" .. rows())
M.spells[17] = true; M.update()
assert(not sideRow("Level 6 training"), "trained (spell known)")
M.level = 8; M.update()
assert(sideRow("Level 8 training"), "level 8")
M.trainerType = 2; M.fire("TRAINER_SHOW"); M.update(0.2)
assert(sideRow("Level 8 training"), "a profession trainer doesn't count")
M.trainerType = 0; M.fire("TRAINER_SHOW"); M.update(0.2)
assert(not sideRow("Level 8 training"), "class trainer visited at 8")
M.class = "WARRIOR"; M.update()
assert(rows():find("Warrior Only", 1, true) and not rows():find("Priest Only", 1, true), "class filter flips")
M.class = "PRIEST"
print("4 ok")

-- 5. Side rows can be clicked to put the arrow/map pin on them; the frame shows them below the next steps.
set({ water, D("Far Away", "Go far", 60, 60, 5) })
M.items[1179] = 0; M.char.marks = {}; M.update()
local r = sideRow("Ice Cold Milk")
assert(r, "shown again with fresh marks")
r.scripts.OnClick(r, "LeftButton")
assert(M.waypoint and math.abs(M.waypoint.x - 0.556) < 1e-9, "map pin on the vendor")
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
