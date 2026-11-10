-- Round 3 rank 7: BagCheck junk value skips locked, no-value, zero-price and refundable stacks and treats an
-- unloaded quality as pending; with full bags it hints "drop X (3c) to take Y (25s)" (never quest items, tools,
-- the hearthstone, epics, ...), honours a per-character keep list, and never deletes anything.
local base = ADDON_PATH
local SECRET = {}
issecretvalue = function(v) return v == SECRET end
local out, handled, frame = {}, {}, nil
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
CreateFrame = function()
    frame = { RegisterEvent = function() end, SetScript = function(self, _, fn) self.fn = fn end }
    return frame
end
SlashCmdList = {}
UnitName = function() return "T" end
GetRealmName = function() return "R" end
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
local slots, free, refund, quest = {}, 5, {}, {}
local deleted = false
DeleteCursorItem = function() deleted = true end
PickupContainerItem = function() deleted = true end
C_Container = {
    GetContainerNumSlots = function() return 16 end,
    GetContainerNumFreeSlots = function() return free, 0 end,
    GetContainerItemInfo = function(_, slot) return slots[slot] end,
    GetContainerItemPurchaseInfo = function(_, slot) return { refundSeconds = refund[slot] or 0 } end,
    GetContainerItemQuestInfo = function(_, slot) return { isQuestItem = quest[slot] or false, isActive = false } end,
    PickupContainerItem = function() deleted = true end,
}
-- id -> name, price, class, subclass, maxStack
local items = {
    [1] = { "Broken Fang", 3, 15, 0, 1 }, [2] = { "Rusty Knife", 40, 15, 0, 1 }, [3] = { "Free Junk", 0, 15, 0, 1 },
    [4] = { "Locked Junk", 25, 15, 0, 1 }, [5] = { "Refund Junk", 25, 15, 0, 1 },
    [10] = { "Linen Cloth", 1, 7, 0, 20 }, [11] = { "Quest Thing", 0, 12, 0, 1 }, [12] = { "Mining Pick", 5, 2, 14, 1 },
    [6948] = { "Hearthstone", 0, 15, 0, 1 }, [13] = { "Epic Sword", 1, 2, 7, 1 }, [14] = { "Old Pole", 1, 2, 20, 1 },
    [15] = { "Gray Wolf Pelt", 25, 7, 0, 10 }, [16] = { "Ruined Pelt", 2, 15, 0, 1 },
    [2901] = { "Mining Pick", 5, 2, 14, 1 }, [20] = { "Silver Ore", 2500, 7, 0, 20 }, [21] = { "Iron Bar", 2500, 7, 0, 20 },
}
C_Item = {
    GetItemInfo = function(id)
        local t = items[id]
        if not t then return nil end
        return t[1], nil, nil, nil, nil, nil, nil, t[5], nil, nil, t[2], t[3], t[4]
    end,
    RequestLoadItemDataByID = function() end,
}
local function item(id, q, n, extra)
    local info = { itemID = id, quality = q, stackCount = n or 1, hyperlink = "|Hitem:" .. id .. ":|h[" .. items[id][1] .. "]|h" }
    for k, v in pairs(extra or {}) do info[k] = v end
    return info
end

assert(loadfile(base .. "/BagCheck/BagCheck.lua"))("BagCheck", {})
local function fire(...) frame.fn(frame, ...) end
fire("PLAYER_LOGIN")
local function page(arg)
    out = {}
    SlashCmdList.BAGCHECK(arg or "")
    return table.concat(out, "\n")
end

-- 1. Junk: only sellable grey stacks count.
slots = {
    item(1, 0, 2),                     -- 6c
    item(2, 0, 1),                     -- 40c
    item(3, 0, 1),                     -- price 0: not junk value
    item(4, 0, 1, { isLocked = true }),
    item(5, 0, 1),                     -- refundable
    item(16, 0, 1, { hasNoValue = true }),
}
refund[5] = 3000
local p = page()
assert(p:find("3 junk item(s) worth 0g 0s 46c.", 1, true), "only sellable junk:\n" .. p)
-- A stack whose quality hasn't loaded makes the total "at least".
slots[7] = { itemID = 2, stackCount = 1 }
p = page()
assert(p:find("worth at least 0g 0s 46c", 1, true), "pending quality:\n" .. p)
print("1 ok")

-- 2. Nearly full: the three cheapest stacks you could drop, never quest items, tools, the hearthstone,
-- epics, fishing poles or quest-class items.
refund = {}
slots = {
    item(10, 1, 5),                    -- 5c
    item(1, 0, 1),                     -- 3c
    item(11, 1, 1),                    -- quest class
    item(12, 1, 1),                    -- quest item by the container's quest info
    item(6948, 1, 1),
    item(13, 4, 1),                    -- epic
    item(14, 1, 1),                    -- fishing pole
    item(2901, 1, 1),                  -- profession tool
    item(15, 1, 2),                    -- 50c
    item(20, 1, 1),                    -- 25s
}
quest[4] = true
free = 2
p = page()
assert(p:find("Cheapest to drop if you need room: Broken Fang (3c), Linen Cloth x5 (5c), Gray Wolf Pelt x2 (50c).", 1, true), "drop list:\n" .. p)
for _, never in ipairs({ "Quest Thing", "Mining Pick", "Hearthstone", "Epic Sword", "Old Pole" }) do
    assert(not p:find(never .. " (", 1, true), never .. " never suggested:\n" .. p)
end
print("2 ok")

-- 3. Keep list: typed in the page's box; kept items are never suggested, and "forget" undoes it.
p = page("keep broken fang")
assert(p:find("Broken Fang will never be suggested", 1, true), "keep confirmed:\n" .. p)
assert(p:find("Cheapest to drop if you need room: Linen Cloth x5 (5c)", 1, true), "kept item skipped:\n" .. p)
assert(p:find("Never suggested to drop: Broken Fang.", 1, true), "keep list shown:\n" .. p)
local key = next(BagCheckDB)
assert(BagCheckDB[key].keep[1] == true, "saved per character")
p = page("forget Broken Fang")
assert(p:find("Cheapest to drop if you need room: Broken Fang (3c)", 1, true), "forgotten:\n" .. p)
p = page("keep Nothing Like It")
assert(p:find("Couldn't find", 1, true), "unknown item:\n" .. p)
print("3 ok")

-- 4. Loot with full bags: "drop X to take Y" when the loot is worth more; quest items always.
free = 0
local loot = {}
GetNumLootItems = function() return #loot end
GetLootSlotLink = function(slot) return loot[slot] and loot[slot].link end
GetLootSlotInfo = function(slot) local l = loot[slot]; return "icon", l.name, l.n, nil, 1, false, l.quest end
loot = { { link = "|Hitem:21:|h[Iron Bar]|h", name = "Iron Bar", n = 1 } }
out = {}
fire("LOOT_OPENED")
p = table.concat(out, "\n")
assert(p:find("Bags full: drop Broken Fang (3c) to take Iron Bar (25s).", 1, true), "loot hint:\n" .. p)
-- Loot worth less than anything you'd drop: no hint.
loot = { { link = "|Hitem:16:|h[Ruined Pelt]|h", name = "Ruined Pelt", n = 1 } }
out = {}
fire("LOOT_OPENED")
assert(#out == 0, "no hint for cheaper loot: " .. table.concat(out, "\n"))
-- A quest item: always worth the space.
loot = { { link = "|Hitem:11:|h[Quest Thing]|h", name = "Quest Thing", n = 1, quest = true } }
out = {}
fire("LOOT_OPENED")
assert(table.concat(out, "\n"):find("to take Quest Thing (quest item)", 1, true), "quest loot: " .. table.concat(out, "\n"))
-- Loot that stacks onto what you carry needs no room.
loot = { { link = "|Hitem:15:|h[Gray Wolf Pelt]|h", name = "Gray Wolf Pelt", n = 3 } }
out = {}
fire("LOOT_OPENED")
assert(#out == 0, "stacks onto a carried stack: " .. table.concat(out, "\n"))
-- With room in the bags there's no hint at all.
free = 1
loot = { { link = "|Hitem:21:|h[Iron Bar]|h", name = "Iron Bar", n = 1 } }
out = {}
fire("LOOT_OPENED")
assert(#out == 0, "room left: no hint")
print("4 ok")

assert(not deleted, "never picks up or deletes anything")
assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
