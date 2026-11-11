-- WindowBadges: small badges on Blizzard's quest reward, merchant and trainer windows.
-- Read-only. Every badge is this addon's own frame on its own overlay (parented to UIParent,
-- strata HIGH) and only anchored with SetPoint to Blizzard's buttons. Nothing here clicks,
-- chooses a reward, buys, sells or trains; Blizzard's frames are never shown, hidden, hooked,
-- reparented or written to, and no hooksecurefunc is used: events plus a light OnUpdate watcher
-- on our own overlay cover page flips and list scrolling.
local SOURCE = "WindowBadges"

local WATCH_INTERVAL, REPAINT_DELAY = 0.25, 0.1
local RETRY_DELAYS = { 0.5, 2 }
local POOL_SIZE = 48
local ICON_SIZE = 14
local CLASSIC_TRAINER_ROWS = 20
local MERCHANT_PAGE_SIZE = 10
local RECIPE_CLASS = 9
local LOOT_TYPE_CURRENCY = 1

local ARROW_ATLAS = "bags-greenarrow"
local ARROW_FALLBACK = "Interface\\Buttons\\UI-MicroStream-Green"
local COIN_TEXTURE = "Interface\\MoneyFrame\\UI-GoldIcon"
local CHECK_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-Ready"
local BOOK_TEXTURE = "Interface\\Icons\\INV_Misc_Book_09"

-- Each kind of badge, in the order the page lists them. All start on.
local KINDS = {
    { name = "reward", label = "Best reward", about = "a green arrow and \"Best\" on the quest reward that is the biggest upgrade for you (needs ItemAdvisor)" },
    { name = "gold", label = "Most gold", about = "a coin and \"Most gold\" on the quest reward that sells for the most, when it isn't already the best one" },
    { name = "merchant", label = "Vendor upgrades", about = "a green arrow on vendor items that are an upgrade for you (needs ItemAdvisor); nothing on the buyback tab" },
    { name = "known", label = "Known recipes", about = "a check on vendor recipes the game says you already know" },
    { name = "trainer", label = "Trainer spells", about = "\"On your bars\" on a higher rank of a spell you use, \"New\" on a spell you don't have yet, and whether your reputation gives 10% off (with TrainerNotes)" },
}
local KIND_BY_NAME = {}
for _, kind in ipairs(KINDS) do
    KIND_BY_NAME[kind.name] = kind
end

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

-- Calls fn and returns its first value, made safe; nil when fn is missing or fails.
local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, result = pcall(fn, ...)
    return ok and Safe(result) or nil
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive(SOURCE, text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function Report(step, ...)
    local ok, err = pcall(step, ...)
    if not ok and geterrorhandler then
        geterrorhandler()(err)
    end
end

-- ItemAdvisor already marks the best quest reward with its own glow and coin, so ours start off to
-- avoid showing the same advice twice. The player can still turn them on from the page.
local OFF_BY_DEFAULT = { reward = true, gold = true }

local function IsOn(name)
    local saved = type(WindowBadgesDB) == "table" and WindowBadgesDB[name]
    if saved == true or saved == false then
        return saved
    end
    return not OFF_BY_DEFAULT[name]
end

local function InCombat()
    return InCombatLockdown and SafeCall(InCombatLockdown) and true or false
end

-- Visible on screen, asked of a Blizzard frame without changing it.
local function Visible(frame)
    return type(frame) == "table" and type(frame.IsVisible) == "function" and SafeCall(frame.IsVisible, frame) and true or false
end

----------------------------------------------------------------------------------------------------
-- Badge pool: made once at login, so nothing is ever created while in combat.

local overlay = CreateFrame("Frame", "WindowBadgesOverlay", UIParent)
overlay:SetFrameStrata("HIGH")
overlay:SetFrameLevel(100)
overlay:SetAllPoints(UIParent)

local pool = {}

local function NewBadge()
    local badge = CreateFrame("Frame", nil, overlay)
    badge:SetSize(ICON_SIZE, ICON_SIZE)
    badge.back = badge:CreateTexture(nil, "BACKGROUND")
    badge.back:SetAllPoints(badge)
    badge.back:SetColorTexture(0, 0, 0, 0.6)
    badge.icon = badge:CreateTexture(nil, "OVERLAY")
    badge.icon:SetSize(ICON_SIZE, ICON_SIZE)
    badge.icon:SetPoint("LEFT", badge, "LEFT", 0, 0)
    badge.text = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badge.text:SetPoint("LEFT", badge.icon, "RIGHT", 1, 0)
    badge:Hide()
    return badge
end

local function BuildPool()
    for i = #pool + 1, POOL_SIZE do
        pool[i] = NewBadge()
    end
end

local function ReleaseWindow(window)
    for _, badge in ipairs(pool) do
        if badge.window == window then
            badge.window, badge.target, badge.clip = nil, nil, nil
            badge:ClearAllPoints()
            badge:Hide()
        end
    end
end

local function ReleaseAll()
    for _, window in ipairs({ "reward", "merchant", "trainer" }) do
        ReleaseWindow(window)
    end
end

-- style: { atlas | texture, text, color = { r, g, b } }. Returns false when the pool is used up.
local function Place(window, target, style, point, relativePoint, x, y, clip)
    local badge
    for _, candidate in ipairs(pool) do
        if not candidate.window then
            badge = candidate
            break
        end
    end
    if not badge then
        return false
    end
    badge.window, badge.target, badge.clip = window, target, clip
    local hasIcon = false
    if style.atlas and badge.icon:SetAtlas(style.atlas) ~= false then
        hasIcon = true
    elseif style.texture or style.atlas then
        -- A client without the bag arrow atlas gets a plain green arrow texture instead.
        badge.icon:SetTexture(style.texture or ARROW_FALLBACK)
        hasIcon = true
    end
    badge.icon:SetShown(hasIcon)
    local color = style.color or { 1, 1, 1 }
    badge.text:SetText(style.text or "")
    badge.text:SetTextColor(color[1], color[2], color[3])
    local textWidth = style.text and (tonumber(badge.text:GetStringWidth()) or 0) + 3 or 0
    badge:SetSize((hasIcon and ICON_SIZE or 0) + textWidth, ICON_SIZE)
    badge:ClearAllPoints()
    badge:SetPoint(point, target, relativePoint, x, y)
    badge:Show()
    return true
end

----------------------------------------------------------------------------------------------------
-- Item loading

local pendingItems = {}

local function ItemID(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

local function RequestItem(link)
    local id = ItemID(link)
    if id and C_Item and C_Item.RequestLoadItemDataByID then
        pendingItems[id] = true
        pcall(C_Item.RequestLoadItemDataByID, id)
    end
end

local function ItemInfo(link)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if type(getInfo) ~= "function" then
        return nil
    end
    local ok, name, _, _, _, _, _, _, _, _, _, sellPrice, classID = pcall(getInfo, link)
    if not ok or not Safe(name) then
        return nil
    end
    return { sellPrice = tonumber(Safe(sellPrice)) or 0, classID = Safe(classID) }
end

-- ItemAdvisor's verdict: true and its reason when the item is an upgrade for you; nil without ItemAdvisor.
local function Upgrade(link)
    if type(ItemAdvisor_IsUpgrade) ~= "function" then
        return nil
    end
    local ok, isUpgrade, reason = pcall(ItemAdvisor_IsUpgrade, link)
    if not ok then
        return false
    end
    return Safe(isUpgrade) == true, Safe(reason)
end

-- How big an upgrade is, from ItemAdvisor's reason ("Upgrade for warrior (+12, 8%)").
local function UpgradeSize(reason)
    if type(reason) ~= "string" then
        return 0
    end
    if reason:find("empty slot", 1, true) then
        return 1000000
    end
    return tonumber(reason:match("%(%+(%d+)")) or 0
end

----------------------------------------------------------------------------------------------------
-- Quest reward window

local rewardOpen = false

-- Choice reward buttons by choice index. Blizzard's reward pool (QuestInfoRewardsFrame.RewardButtons,
-- buttons named QuestInfoRewardsFrameQuestInfoItemN) on both the Vanilla and Mainline quest frames.
local function RewardButtons()
    local buttons = {}
    local rewards = QuestInfoRewardsFrame
    local list = type(rewards) == "table" and type(rewards.RewardButtons) == "table" and rewards.RewardButtons or nil
    if not list then
        list = {}
        for i = 1, 16 do
            local button = _G["QuestInfoRewardsFrameQuestInfoItem" .. i] or _G["QuestInfoItem" .. i]
            if button then
                list[#list + 1] = button
            end
        end
    end
    for _, button in ipairs(list) do
        if type(button) == "table" and Safe(button.type) == "choice" and Safe(button.objectType) ~= "currency" and Visible(button) then
            local index = SafeCall(button.GetID, button)
            if type(index) == "number" then
                buttons[index] = button
            end
        end
    end
    return buttons
end

local function ReadChoices()
    local choices, pending = {}, false
    for index = 1, SafeCall(GetNumQuestChoices) or 0 do
        local isCurrency = SafeCall(GetQuestItemInfoLootType, "choice", index) == LOOT_TYPE_CURRENCY
        local link = not isCurrency and SafeCall(GetQuestItemLink, "choice", index) or nil
        local info = type(link) == "string" and ItemInfo(link) or nil
        if link and not info then
            pending = true
            RequestItem(link)
        elseif info then
            local count = 1
            if type(GetQuestItemInfo) == "function" then
                local ok, _, _, amount = pcall(GetQuestItemInfo, "choice", index)
                count = ok and tonumber(Safe(amount)) or 1
            end
            local isUpgrade, reason = Upgrade(link)
            -- ItemAdvisor couldn't score it (no stats, or stats it can't weigh: on-use trinkets and the like).
            local unscored = not isUpgrade and type(reason) == "string"
                and (reason:find("can't score", 1, true) or reason:find("No stats", 1, true)) and true or false
            choices[#choices + 1] = {
                index = index, link = link, value = info.sellPrice * math.max(count, 1),
                upgrade = isUpgrade, size = isUpgrade and UpgradeSize(reason) or 0, unscored = unscored,
            }
        end
    end
    return choices, pending
end

local function PaintReward()
    ReleaseWindow("reward")
    if not rewardOpen or not (IsOn("reward") or IsOn("gold")) then
        return
    end
    if QuestFrame and not Visible(QuestFrame) then
        return
    end
    local choices = ReadChoices()
    if #choices < 2 then
        return
    end
    local best, richest, tied, unscored
    for _, choice in ipairs(choices) do
        if choice.upgrade and (not best or choice.size > best.size) then
            best = choice
        end
        if choice.value > 0 and (not richest or choice.value > richest.value) then
            richest, tied = choice, false
        elseif richest and choice.value == richest.value then
            tied = true
        end
        unscored = unscored or choice.unscored
    end
    -- Round 4 R15 (idea from Pawn): with a choice nobody could score, "Most gold" would be a bad hint.
    if tied or unscored or richest == best then
        richest = nil
    end
    local buttons = RewardButtons()
    if best and IsOn("reward") and buttons[best.index] then
        Place("reward", buttons[best.index], { atlas = ARROW_ATLAS, text = "Best", color = { 0.2, 1, 0.2 } },
            "TOPRIGHT", "TOPRIGHT", -2, -2)
    end
    if richest and IsOn("gold") and buttons[richest.index] then
        Place("reward", buttons[richest.index], { texture = COIN_TEXTURE, text = "Most gold", color = { 1, 0.82, 0 } },
            "BOTTOMRIGHT", "BOTTOMRIGHT", -2, 2)
    end
end

----------------------------------------------------------------------------------------------------
-- Merchant window: MerchantItem1..10 with MerchantItemNItemButton (Vanilla and Mainline MerchantFrame.lua).

local merchantOpen = false
local knownCache = {}

local function KnownText()
    return type(ITEM_SPELL_KNOWN) == "string" and ITEM_SPELL_KNOWN or "Already known"
end

local function IsRecipe(link)
    if C_Item and C_Item.GetItemInfoInstant then
        local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, link)
        if ok and Safe(classID) ~= nil then
            return Safe(classID) == RECIPE_CLASS
        end
    end
    local info = ItemInfo(link)
    return info and info.classID == RECIPE_CLASS or false
end

-- The game's own tooltip says "Already known" for a recipe you have learned.
local function AlreadyKnown(index, link)
    if knownCache[link] ~= nil then
        return knownCache[link]
    end
    if not (C_TooltipInfo and (C_TooltipInfo.GetMerchantItem or C_TooltipInfo.GetHyperlink)) then
        return false
    end
    local data = C_TooltipInfo.GetMerchantItem and SafeCall(C_TooltipInfo.GetMerchantItem, index)
    if type(data) ~= "table" then
        data = SafeCall(C_TooltipInfo.GetHyperlink, link)
    end
    local lines = type(data) == "table" and Safe(data.lines)
    if type(lines) ~= "table" or #lines < 2 then
        return false -- Not loaded yet: say nothing and don't remember it.
    end
    local wanted, known = KnownText(), false
    for _, line in ipairs(lines) do
        if type(line) == "table" and Safe(line.leftText) == wanted then
            known = true
            break
        end
    end
    knownCache[link] = known
    return known
end

local function MerchantSignature()
    local frame = MerchantFrame
    if not Visible(frame) then
        return "closed"
    end
    return tostring(Safe(frame.selectedTab)) .. ":" .. tostring(Safe(frame.page)) .. ":" .. tostring(SafeCall(GetMerchantNumItems))
end

local function PaintMerchant()
    ReleaseWindow("merchant")
    if not merchantOpen or not (IsOn("merchant") or IsOn("known")) then
        return
    end
    local frame = MerchantFrame
    if not Visible(frame) then
        return
    end
    local tab = Safe(frame.selectedTab)
    if tab ~= nil and tab ~= 1 then
        return -- Buyback tab: nothing to advise on.
    end
    local perPage = tonumber(Safe(MERCHANT_ITEMS_PER_PAGE)) or MERCHANT_PAGE_SIZE
    local page = tonumber(Safe(frame.page))
    -- When the count can't be read, a shown button is enough (an empty index just gives no link).
    local count = tonumber(SafeCall(GetMerchantNumItems))
    for i = 1, perPage do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if Visible(button) then
            local index = page and ((page - 1) * perPage + i) or SafeCall(button.GetID, button)
            local inRange = type(index) == "number" and index >= 1 and (not count or index <= count)
            local link = inRange and SafeCall(GetMerchantItemLink, index) or nil
            if type(link) == "string" then
                if not ItemInfo(link) then
                    RequestItem(link)
                end
                if IsOn("merchant") and Upgrade(link) then
                    Place("merchant", button, { atlas = ARROW_ATLAS }, "TOPLEFT", "TOPLEFT", 0, 0)
                end
                if IsOn("known") and IsRecipe(link) and AlreadyKnown(index, link) then
                    Place("merchant", button, { texture = CHECK_TEXTURE }, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0)
                end
            end
        end
    end
end

----------------------------------------------------------------------------------------------------
-- Trainer window. Forever's ClassTrainerFrame lists services in ClassTrainerFrame.ScrollBox, whose
-- rows carry { skillIndex } as element data; the older Classic list is ClassTrainerSkill1..N with
-- the service index as the button's ID. Both are read, never changed.

local trainerOpen = false
local spells -- { known = { [lowername] = true } or nil, onBars = { [lowername] = true } }

local function IsClassTrainer()
    if C_Trainer and C_Trainer.GetTrainerType and Enum and Enum.TrainerType and Enum.TrainerType.General ~= nil then
        return SafeCall(C_Trainer.GetTrainerType) == Enum.TrainerType.General
    end
    return not SafeCall(IsTradeskillTrainer)
end

local function Remember(list, name)
    name = Safe(name)
    if type(name) == "string" and name ~= "" then
        list[name:lower()] = true
    end
end

-- Spell names in your spellbook, or nil when it can't be read.
local function ScanSpellBook()
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local list, read = {}, false
        local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        local spellType = (Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell) or 1
        for line = 1, SafeCall(C_SpellBook.GetNumSpellBookSkillLines) or 0 do
            local info = SafeCall(C_SpellBook.GetSpellBookSkillLineInfo, line)
            local offset = type(info) == "table" and Safe(info.itemIndexOffset)
            local count = type(info) == "table" and Safe(info.numSpellBookItems)
            if type(offset) == "number" and type(count) == "number" then
                read = true
                for slot = offset + 1, offset + count do
                    local item = SafeCall(C_SpellBook.GetSpellBookItemInfo, slot, bank)
                    if type(item) == "table" and Safe(item.itemType) == spellType then
                        Remember(list, item.name)
                    end
                end
            end
        end
        return read and list or nil
    end
    if GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
        local list, read = {}, false
        for tab = 1, SafeCall(GetNumSpellTabs) or 0 do
            local ok, _, _, offset, count = pcall(GetSpellTabInfo, tab)
            offset, count = ok and Safe(offset), ok and Safe(count)
            if type(offset) == "number" and type(count) == "number" then
                read = true
                for slot = offset + 1, offset + count do
                    Remember(list, SafeCall(GetSpellBookItemName, slot, BOOKTYPE_SPELL or "spell"))
                end
            end
        end
        return read and list or nil
    end
    return nil
end

-- The spell ID in an action slot, as ReadyCheck reads it: nil for empty slots, macros and items.
local function ActionSpell(slot)
    if GetActionInfo then
        local ok, kind, id = pcall(GetActionInfo, slot)
        if ok and Safe(kind) == "spell" and type(Safe(id)) == "number" then
            return Safe(id)
        end
        return nil
    end
    if C_ActionBar and SafeCall(C_ActionBar.HasAction, slot) then
        local id = SafeCall(C_ActionBar.GetSpell, slot)
        return type(id) == "number" and id > 0 and id or nil
    end
    return nil
end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then
        return SafeCall(C_Spell.GetSpellName, id)
    end
    return SafeCall(GetSpellInfo, id)
end

local function Spells()
    if spells then
        return spells
    end
    local onBars = {}
    for slot = 1, 180 do
        local id = ActionSpell(slot)
        if id then
            Remember(onBars, SpellName(id))
        end
    end
    spells = { known = ScanSpellBook(), onBars = onBars }
    return spells
end

-- Name and type of a service, reading either return order, as TrainerNotes does.
local function ReadService(index)
    if type(GetTrainerServiceInfo) ~= "function" then
        return nil
    end
    local ok, r1, r2, r3 = pcall(GetTrainerServiceInfo, index)
    if not ok then
        return nil
    end
    local name, serviceType = Safe(r1), Safe(r2)
    local third = Safe(r3)
    if third == "available" or third == "unavailable" or third == "used" or third == "header" then
        serviceType = third
    end
    if type(name) ~= "string" or name == "" then
        return nil
    end
    return name, serviceType
end

local function ElementIndex(button)
    if type(button.GetElementData) ~= "function" then
        return nil
    end
    local data = SafeCall(button.GetElementData, button)
    if type(data) ~= "table" then
        return nil
    end
    if type(data.data) == "table" then
        data = data.data
    end
    local index = Safe(data.skillIndex)
    return type(index) == "number" and index or nil
end

-- Visible rows as { button, index }, plus the list frame that clips them (nil on Classic).
local function TrainerRows()
    local rows = {}
    local frame = ClassTrainerFrame
    if not Visible(frame) then
        return rows
    end
    local box = frame.ScrollBox
    if type(box) == "table" then
        local frames = type(box.GetFrames) == "function" and SafeCall(box.GetFrames, box) or nil
        if type(frames) ~= "table" and type(box.ForEachFrame) == "function" then
            frames = {}
            pcall(box.ForEachFrame, box, function(button) frames[#frames + 1] = button end)
        end
        for _, button in ipairs(frames or {}) do
            local index = type(button) == "table" and Visible(button) and ElementIndex(button)
            if index then
                rows[#rows + 1] = { button = button, index = index }
            end
        end
        return rows, box
    end
    for i = 1, CLASSIC_TRAINER_ROWS do
        local button = _G["ClassTrainerSkill" .. i]
        if Visible(button) then
            local index = SafeCall(button.GetID, button)
            if type(index) == "number" and index > 0 then
                rows[#rows + 1] = { button = button, index = index }
            end
        end
    end
    return rows
end

-- A recycled row scrolled partly out of the list is still "visible"; its badge would float outside.
local function InsideList(button, box)
    if not box then
        return true
    end
    local top, bottom = SafeCall(button.GetTop, button), SafeCall(button.GetBottom, button)
    local boxTop, boxBottom = SafeCall(box.GetTop, box), SafeCall(box.GetBottom, box)
    if not (top and bottom and boxTop and boxBottom) then
        return true
    end
    return top <= boxTop + 2 and bottom >= boxBottom - 2
end

local function TrainerSignature()
    if not Visible(ClassTrainerFrame) then
        return "closed"
    end
    local rows, box = TrainerRows()
    local parts = {}
    for _, row in ipairs(rows) do
        parts[#parts + 1] = row.index .. (InsideList(row.button, box) and "" or "x")
    end
    return table.concat(parts, ",")
end

-- Round 4 R16: Honored or better with a faction whose trainers teach your class takes 10 % off (What's Training's
-- Forever pricing, MIT, via TrainerNotesData.trainerFactions when TrainerNotes is loaded). Returns the badge text:
-- "10% off (Honored with X)", or "10% off at Honored with Y" naming the closest faction; nil when unknown.
local HONORED = 6

-- Review 4, note 10: the trainer's own faction isn't known, so its prices tell. Each service the list
-- (TrainerNotesData.classes) knows by name and rank is compared with its list price: 10 % under it means the
-- discount applies at this trainer, the list price means it doesn't. Returns "on", "off", or nil (can't tell).
local function DiscountHere()
    local data = type(TrainerNotesData) == "table" and type(TrainerNotesData.classes) == "table" and TrainerNotesData.classes
    local class
    if data and type(UnitClass) == "function" then
        local ok, _, file = pcall(UnitClass, "player")
        class = ok and Safe(file) or nil
    end
    local rows = type(class) == "string" and type(data[class]) == "table" and data[class].spells
    local count = type(rows) == "table" and type(GetTrainerServiceInfo) == "function" and type(GetTrainerServiceCost) == "function"
        and SafeCall(GetNumTrainerServices)
    if type(count) ~= "number" or count <= 0 or not (C_Spell and C_Spell.GetSpellName) then
        return nil
    end
    local listPrice = {}
    for _, row in ipairs(rows) do
        local name = type(row) == "table" and SafeCall(C_Spell.GetSpellName, row[2])
        local rank = name and SafeCall(C_Spell.GetSpellSubtext, row[2])
        if type(name) == "string" and type(row[3]) == "number" and row[3] > 0 then
            listPrice[name:lower() .. "|" .. (type(rank) == "string" and rank:lower() or "")] = row[3]
        end
    end
    local on, off = false, false
    for index = 1, math.min(count, 300) do
        local ok, r1, r2, r3, _, r5 = pcall(GetTrainerServiceInfo, index)
        local name, rank = ok and Safe(r1), ok and Safe(r5)
        local third = ok and Safe(r3)
        if third == "available" or third == "unavailable" or third == "used" or third == "header" then
            rank = Safe(r2)
        end
        local list = type(name) == "string" and listPrice[name:lower() .. "|" .. (type(rank) == "string" and rank:lower() or "")]
        local cost = list and tonumber(SafeCall(GetTrainerServiceCost, index))
        if cost and cost > 0 then
            if cost == list then
                off = true
            elseif cost == math.floor((list * 90 + 50) / 100) then
                on = true
            end
        end
    end
    if on ~= off then
        return on and "on" or "off"
    end
    return nil
end

local function DiscountText()
    local data = type(TrainerNotesData) == "table" and type(TrainerNotesData.trainerFactions) == "table" and TrainerNotesData.trainerFactions
    local class
    if type(UnitClass) == "function" then
        local ok, _, file = pcall(UnitClass, "player")
        class = ok and Safe(file) or nil
    end
    local side = SafeCall(UnitFactionGroup, "player")
    local ids = data and type(class) == "string" and type(data[class]) == "table" and type(side) == "string" and data[class][side]
    if type(ids) ~= "table" or not (C_Reputation and C_Reputation.GetFactionDataByID) then
        return nil
    end
    local honored, closest, closestStanding
    for _, id in ipairs(ids) do
        local info = SafeCall(C_Reputation.GetFactionDataByID, id)
        local reaction = type(info) == "table" and Safe(info.reaction)
        local name = type(info) == "table" and Safe(info.name)
        if type(reaction) == "number" and type(name) == "string" and name ~= "" then
            if reaction >= HONORED then
                honored = honored and (honored .. ", " .. name) or name
            else
                local standing = tonumber(Safe(info.currentStanding)) or 0
                if not closest or standing > closestStanding then
                    closest, closestStanding = name, standing
                end
            end
        end
    end
    if honored then
        -- Only claimed here when this trainer's prices show it; at full prices it doesn't apply here.
        local here = DiscountHere()
        if here == "on" then
            return "10% off (Honored with " .. honored .. ")", true
        elseif here == "off" then
            return nil
        end
        return "10% off at " .. honored .. " trainers", "maybe"
    elseif closest then
        return "10% off at Honored with " .. closest, false
    end
end

local function PaintTrainer()
    ReleaseWindow("trainer")
    if not trainerOpen or not IsOn("trainer") or not IsClassTrainer() then
        return
    end
    local discount, on = DiscountText()
    if discount and Visible(ClassTrainerFrame) then
        local color = (on == "maybe" and { 1, 0.82, 0 }) or (on and { 0.2, 1, 0.2 }) or { 0.7, 0.7, 0.7 }
        Place("trainer", ClassTrainerFrame, { texture = COIN_TEXTURE, text = discount, color = color },
            "TOPRIGHT", "TOPRIGHT", -30, -28)
    end
    local rows, box = TrainerRows()
    if #rows == 0 then
        return
    end
    local known = Spells()
    for _, row in ipairs(rows) do
        local name, serviceType = ReadService(row.index)
        if name and serviceType == "available" and InsideList(row.button, box) then
            local key = name:lower()
            if known.onBars[key] then
                Place("trainer", row.button, { texture = BOOK_TEXTURE, text = "On your bars", color = { 1, 0.82, 0 } },
                    "BOTTOMRIGHT", "BOTTOMRIGHT", -8, 4, box)
            elseif known.known and not known.known[key] then
                Place("trainer", row.button, { atlas = ARROW_ATLAS, text = "New", color = { 0.2, 1, 0.2 } },
                    "BOTTOMRIGHT", "BOTTOMRIGHT", -8, 4, box)
            end
        end
    end
end

----------------------------------------------------------------------------------------------------
-- Repaint scheduling and the watcher

local repaintScheduled, repaintAfterCombat = false, false
local signatures = {}

local function RunRepaint()
    repaintScheduled = false
    if InCombat() then
        ReleaseAll()
        repaintAfterCombat = true
        return
    end
    Report(PaintReward)
    Report(PaintMerchant)
    Report(PaintTrainer)
    signatures.merchant = MerchantSignature()
    signatures.trainer = TrainerSignature()
end

local function ScheduleRepaint()
    if repaintScheduled then
        return
    end
    repaintScheduled = true
    if C_Timer and C_Timer.After then
        C_Timer.After(REPAINT_DELAY, RunRepaint)
    else
        RunRepaint()
    end
end

local function ScheduleRetries()
    ScheduleRepaint()
    if C_Timer and C_Timer.After then
        for _, delay in ipairs(RETRY_DELAYS) do
            C_Timer.After(delay, ScheduleRepaint)
        end
    end
end

-- A few times a second while a window is open: hide badges whose button went away (our frames only),
-- and repaint when the merchant flips a page or the trainer list scrolls (no event for either).
local sinceWatch = 0
local function Watch(_, elapsed)
    sinceWatch = sinceWatch + (tonumber(elapsed) or 0)
    if sinceWatch < WATCH_INTERVAL then
        return
    end
    sinceWatch = 0
    for _, badge in ipairs(pool) do
        if badge.window and (not Visible(badge.target) or not InsideList(badge.target, badge.clip)) then
            badge:Hide()
        end
    end
    if InCombat() then
        return
    end
    if merchantOpen and MerchantSignature() ~= signatures.merchant then
        ScheduleRepaint()
    end
    if trainerOpen and TrainerSignature() ~= signatures.trainer then
        ScheduleRepaint()
    end
end

----------------------------------------------------------------------------------------------------
-- Events

local events = CreateFrame("Frame")
local EVENTS = {
    "PLAYER_LOGIN", "QUEST_DETAIL", "QUEST_COMPLETE", "QUEST_FINISHED",
    "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED",
    "TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED", "TRAINER_SERVICE_INFO_NAME_UPDATE",
    "GET_ITEM_INFO_RECEIVED", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP",
    "ACTIONBAR_SLOT_CHANGED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
}
for _, name in ipairs(EVENTS) do
    -- An event this client doesn't know would stop the rest from registering.
    pcall(events.RegisterEvent, events, name)
end

local loggedIn, poolPending = false, false
local function AnyOpen()
    return rewardOpen or merchantOpen or trainerOpen
end

-- Perf audit 11: the watcher runs only while a reward, merchant or trainer window is open.
local watcherOn
local function SetWatching()
    local want = AnyOpen() and true or false
    if want ~= watcherOn then
        watcherOn, sinceWatch = want, 0
        overlay:SetScript("OnUpdate", want and Watch or nil)
    end
end

local function OnEvent(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        if type(WindowBadgesDB) ~= "table" then
            WindowBadgesDB = {}
        end
        -- A reload in combat waits for combat to end before making the badges.
        if InCombat() then
            poolPending = true
        else
            BuildPool()
        end
        loggedIn = true
        SetWatching()
        return
    end
    if not loggedIn then
        return
    end
    if event == "QUEST_DETAIL" or event == "QUEST_COMPLETE" then
        rewardOpen = true
        ScheduleRetries()
    elseif event == "QUEST_FINISHED" then
        rewardOpen = false
        ReleaseWindow("reward")
    elseif event == "MERCHANT_SHOW" then
        merchantOpen, knownCache = true, {}
        ScheduleRetries()
    elseif event == "MERCHANT_CLOSED" then
        merchantOpen = false
        ReleaseWindow("merchant")
    elseif event == "TRAINER_SHOW" then
        trainerOpen, spells = true, nil
        ScheduleRetries()
    elseif event == "TRAINER_CLOSED" then
        trainerOpen = false
        ReleaseWindow("trainer")
    elseif event == "PLAYER_REGEN_DISABLED" then
        ReleaseAll()
        repaintAfterCombat = AnyOpen()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if poolPending then
            poolPending = false
            BuildPool()
        end
        if repaintAfterCombat then
            repaintAfterCombat = false
            ScheduleRepaint()
        end
    elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_SKILL_LINE" then
        spells = nil
        if trainerOpen then
            ScheduleRepaint()
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local id = Safe(arg1)
        if id and pendingItems[id] then
            pendingItems[id] = nil
            knownCache = {}
            if AnyOpen() then
                ScheduleRepaint()
            end
        end
    elseif AnyOpen() then
        -- Gear, bags or level changed (upgrades may differ), or the merchant/trainer list updated.
        if event == "MERCHANT_UPDATE" then
            knownCache = {}
        end
        ScheduleRepaint()
    end
end
events:SetScript("OnEvent", function(...)
    Report(OnEvent, ...)
    if loggedIn then
        Report(SetWatching)
    end
end)

----------------------------------------------------------------------------------------------------
-- Page

local function NameList()
    local names = {}
    for _, kind in ipairs(KINDS) do
        names[#names + 1] = kind.name
    end
    return table.concat(names, ", ")
end

local function ShowPage()
    Print("Small badges on the quest reward, vendor and trainer windows. They only show advice: nothing is clicked, chosen, bought, sold or trained for you.")
    Print(" ")
    for _, kind in ipairs(KINDS) do
        local state = IsOn(kind.name) and "|cff33ff33on |r" or "|cff999999off|r"
        Print(string.format("%s  |cffffffff%s|r |cff999999(%s)|r - %s", state, kind.label, kind.name, kind.about))
    end
    Print(" ")
    if type(ItemAdvisor_IsUpgrade) ~= "function" then
        Print("|cffff9933ItemAdvisor isn't loaded, so the Best reward and vendor upgrade badges can't show.|r")
    end
    Print("|cff999999Badges hide while you're in combat and come back after.|r")
    Print("|cff999999Type: off reward   Or: on merchant   Or: off trainer|r")
end

SLASH_WINDOWBADGES1 = "/windowbadges"
SLASH_WINDOWBADGES2 = "/fhbadges"
SlashCmdList.WINDOWBADGES = function(message)
    local text = type(message) == "string" and message:lower():match("^%s*(.-)%s*$") or ""
    if text == "" then
        ShowPage()
        return
    end
    local verb, name = text:match("^(%a+)%s+(%a+)$")
    if not verb then
        verb, name = "toggle", text
    end
    local kind = KIND_BY_NAME[name]
    if not kind or not (verb == "on" or verb == "off" or verb == "toggle") then
        Print("Type on, off, or toggle and a badge name: " .. NameList() .. ".")
        return
    end
    if type(WindowBadgesDB) ~= "table" then
        WindowBadgesDB = {}
    end
    local value
    if verb == "toggle" then
        value = not IsOn(name)
    else
        value = verb == "on"
    end
    WindowBadgesDB[name] = value
    Print(string.format("%s is now %s.", kind.label, value and "|cff33ff33on|r" or "|cff999999off|r"))
    if loggedIn then
        ScheduleRepaint()
    end
end
