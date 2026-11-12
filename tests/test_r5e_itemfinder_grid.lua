-- Round 5 #18 (research\re_round5.md): ItemFinder's bag view, a Bagnon-style icon grid of any character's bags,
-- keyring, bank, worn items and mail from ItemFinder's saved data. Our own window, made on first open; read-only:
-- icons show a tooltip on hover and have no click handler. Bagnon/Baganator ideas only.
-- Run from the tests folder:  node run.js "<repo root>" test_r5e_itemfinder_grid.lua
local out, failures, forbidden, frames = {}, {}, {}, {}
local realPrint = print
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
issecretvalue = function() return false end
ForeverHub_Receive = function(_, text) out[#out + 1] = text end
for _, name in ipairs({ "hooksecurefunc", "UseContainerItem", "PickupContainerItem", "DeleteCursorItem", "EquipItemByName",
    "SplitContainerItem", "PickupItem", "UseItemByName", "print" }) do
    _G[name] = function() forbidden[#forbidden + 1] = name end
end
UISpecialFrames = setmetatable({}, { __newindex = function() forbidden[#forbidden + 1] = "UISpecialFrames written" end })

-- A generic frame: the methods the tests look at are recorded, anything else is a no-op.
local function newObject(kind, parent)
    local o = { kind = kind, parent = parent, shown = true, scripts = {}, events = {}, alpha = 1 }
    function o:RegisterEvent(e) self.events[e] = true end
    function o:SetScript(s, fn) self.scripts[s] = fn; self.fn = s == "OnEvent" and fn or self.fn end
    function o:Show() self.shown = true end
    function o:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
    function o:IsShown() return self.shown end
    function o:SetAlpha(a) self.alpha = a end
    function o:SetText(t) self.text = t end
    function o:GetText() return self.text end
    function o:SetPoint(...) self.point = { ... } end
    function o:SetHeight(h) self.height = h end
    function o:SetVerticalScroll(v) self.vscroll = v end
    function o:CreateTexture()
        local t = newObject("Texture", self)
        function t:SetTexture(f) self.file = f end
        function t:SetColorTexture(r, g, b) self.colour = { r, g, b } end
        function t:SetDesaturated(d) self.desaturated = d end
        return t
    end
    function o:CreateFontString() return newObject("FontString", self) end
    function o:SetOwner(owner) self.owner = owner; self.lines = {}; self.itemID = nil end
    function o:SetItemByID(id) self.itemID = id end
    function o:AddLine(t) self.lines[#self.lines + 1] = t end
    return setmetatable(o, { __index = function(_, k) if type(k) == "string" and k:match("^%u") then return function() end end end })
end
CreateFrame = function(kind, name, parent, template)
    local f = newObject(kind, parent)
    f.name, f.template = name, template
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
UIParent = newObject("UIParent")
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function runTimers() local list = timers; timers = {}; for _, fn in ipairs(list) do fn() end end
SlashCmdList = {}
local clock = 1000000
time = function() return clock end
UnitName = function(u) if u == "player" then return "Juan", "Rivera" end end
UnitGUID = function(u) if u == "player" then return "Player-1-0001" end end
GetRealmName = function() return "R" end
UnitFactionGroup = function() return "Alliance" end
Enum = { BagIndex = { Backpack = 0 } }
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
local bag = {}
C_Container = {
    GetContainerNumSlots = function(b) return b == 0 and #bag or 0 end,
    GetContainerItemInfo = function(b, s) local it = b == 0 and bag[s]; if it then return { hyperlink = it.link, stackCount = it.count } end end,
    UseContainerItem = function() forbidden[#forbidden + 1] = "C_Container.UseContainerItem" end,
    PickupContainerItem = function() forbidden[#forbidden + 1] = "C_Container.PickupContainerItem" end,
}
GetInventoryItemLink = function() end
local function link(id, name) return "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. name .. "]|h|r" end
-- Item cache: Hearthstone common, Linen Cloth common, a green sword, a grey item, one not loaded yet.
local QUALITY = { [6948] = 1, [2589] = 1, [15211] = 2, [3300] = 0 }
local ICON = { [6948] = 134414, [2589] = 132889, [15211] = 135274, [3300] = 133718 }
C_Item = {
    GetItemIconByID = function(id) return ICON[id] end,
    GetItemQualityByID = function(id) return QUALITY[id] end,
    GetItemNameByID = function(id) if id == 9999 then return nil end end,
    GetItemQualityColor = function(q) if q == 2 then return 0.12, 1, 0 end return 1, 1, 1 end,
}

bag = { { link = link(6948, "Hearthstone"), count = 1 }, { link = link(2589, "Linen Cloth"), count = 12 },
    { link = link(2589, "Linen Cloth"), count = 20 }, { link = link(15211, "Militant Shortsword"), count = 1 },
    { link = link(3300, "Rabbit's Foot"), count = 3 } }
-- An alt seen earlier: bank and mail saved, plus an old name-keyed bags table.
ItemFinderDB = {
    ["Player-1-0002"] = { charName = "Alt Two", charGUID = "Player-1-0002", lastSeen = clock, scanTime = clock - 3 * 86400,
        items = { bank = { [2589] = 40, [9999] = 2 }, mail = { [2770] = 5 } }, names = { [2589] = "Linen Cloth", [2770] = "Copper Ore" },
        bags = { ["Old Thing"] = 1 } },
}
assert(loadfile(ADDON_PATH .. "/ItemFinder/ItemFinder.lua"))("ItemFinder", {})
local ev = frames[#frames]
local loadFrames = #frames
local function fire(e, ...) local ok, err = pcall(ev.fn, ev, e, ...); check(ok, e .. ": " .. tostring(err)) end
fire("PLAYER_LOGIN")
check(#frames == loadFrames, "no window made before it's opened")
check(ev.events.GET_ITEM_INFO_RECEIVED, "follows items the game loads later")

----- Open: this character first
out = {}
SlashCmdList.ITEMFINDER("bags")
local view = ItemFinderBagView
check(view and view.shown, "the bag view opened in its own window")
check(#out == 0, "nothing printed: it's a window")
check(type(ItemFinder_ShowBags) == "function", "a function the hub can call")
local function visibleIcons()
    local list = {}
    for _, f in ipairs(frames) do
        if f.kind == "Frame" and f.entry and f.shown then list[#list + 1] = f end
    end
    return list
end
local icons = visibleIcons()
check(#icons == 4, "one icon per kind of item: " .. #icons)
local byID = {}
for _, icon in ipairs(icons) do byID[icon.entry.id] = icon end
check(byID[2589] and byID[2589].Count.text == "32", "stacks of one item add up: " .. tostring(byID[2589] and byID[2589].Count.text))
check(byID[6948] and byID[6948].Count.text == "", "no count on a single item")
check(byID[15211] and byID[15211].Border.colour[1] == 0.12, "quality-coloured border for the green")
check(byID[6948] and byID[6948].Texture.file == 134414, "the item's icon")
-- Sorted by quality first: the green sword leads its section.
check(icons[1].entry.id == 15211, "best quality first: " .. tostring(icons[1].entry.id))
for _, icon in ipairs(icons) do
    check(not icon.scripts.OnClick and not icon.scripts.OnMouseDown and not icon.scripts.OnMouseUp and not icon.scripts.OnReceiveDrag
        and not icon.scripts.OnDragStart, "icons have no click handlers")
end
check(view.template == "BackdropTemplate" or view.template == nil, "a plain frame of our own")
check(ItemFinderBagView and true, "named in our own namespace")

----- Tooltip on hover, nothing else
local sword = byID[15211]
sword.scripts.OnEnter(sword)
local tip = ItemFinderTooltip
check(tip and tip.itemID == 15211 and tip.owner == sword, "hover shows the item's tooltip")
check(tip and table.concat(tip.lines, "|"):find("Juan Rivera: 1 (Bags)", 1, true), "who has it and where: " .. table.concat(tip and tip.lines or {}, "|"))
sword.scripts.OnLeave(sword)
check(not tip.shown, "tooltip hides")

----- Search dims what doesn't match
local search
for _, f in ipairs(frames) do if f.kind == "EditBox" then search = f end end
search.text = "linen"
search.scripts.OnTextChanged(search)
check(byID[2589].alpha == 1 and byID[6948].alpha < 1, "non-matches dimmed")
search.text = "#6948"
search.scripts.OnTextChanged(search)
check(byID[6948].alpha == 1 and byID[2589].alpha < 1, "search by item ID")
search.text = ""
search.scripts.OnTextChanged(search)
check(byID[2589].alpha == 1 and byID[6948].alpha == 1, "cleared")

----- Another character: bank, mail, an item not loaded yet, an old name-keyed entry
local nextButton
for _, f in ipairs(frames) do if f.kind == "Button" and f.text == ">" then nextButton = f end end
nextButton.scripts.OnClick(nextButton)
icons = visibleIcons()
byID = {}
for _, icon in ipairs(icons) do byID[icon.entry.id] = icon end
check(#icons == 3 and byID[2589] and byID[9999] and byID[2770], "alt's bank and mail: " .. #icons)
check(byID[2770].place == "mail", "mail in its own section")
check(byID[9999].Texture.file == "Interface\\Icons\\INV_Misc_QuestionMark", "unknown icon while the item loads")
local content = byID[2770].parent
check(content, "icons sit on our scroll content")
fire("BAG_UPDATE_DELAYED")
check(#timers >= 1, "a data change lays out again a moment later")
runTimers()
-- Character by name
ItemFinder_ShowBags("alt")
icons = visibleIcons()
check(#icons == 3, "opened on the named character")
-- Toggle closed
ItemFinder_ShowBags()
check(not view.shown, "toggles closed")

----- Bags change while open on this character
ItemFinder_ShowBags()
check(view.shown and #visibleIcons() == 4, "back on this character")
bag[#bag + 1] = { link = link(2770, "Copper Ore"), count = 7 }
fire("BAG_UPDATE_DELAYED")
runTimers()
check(#visibleIcons() == 5, "new item shows after the bag update")
-- Many items: the pool is bounded.
bag = {}
for i = 1, 700 do bag[i] = { link = link(20000 + i, "Thing " .. i), count = 1 } end
fire("BAG_UPDATE_DELAYED")
runTimers()
check(#visibleIcons() <= 600, "icon pool bounded: " .. #visibleIcons())

check(#forbidden == 0, "forbidden calls: " .. table.concat(forbidden, ", "))
if #failures > 0 then
    realPrint("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do realPrint(" - " .. why) end
    os.exit(1)
end
realPrint("test_r5e_itemfinder_grid: all checks passed")
