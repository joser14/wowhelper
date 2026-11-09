-- WindowBadges: quest reward, merchant and trainer badges; toggles; hidden buttons; combat; missing
-- frames and APIs; secret values. Fails if any Blizzard frame is shown, hidden, hooked, reparented,
-- clicked or written to, or if any buy/sell/choose/train API is called.
-- Run from the harness folder:  node run.js "<workspace root>" test_windowbadges.lua
local base = ADDON_PATH
local failures, violations, handled, out, timers = {}, {}, {}, {}, {}
local SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })
local combat = false

local function check(cond, why)
    if not cond then failures[#failures + 1] = why end
end
local function violate(what) violations[#violations + 1] = what end

issecretvalue = function(v) return v == SECRET end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
InCombatLockdown = function() return combat end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function flush()
    local guard = 0
    while #timers > 0 and guard < 100 do
        guard = guard + 1
        table.remove(timers, 1)()
    end
end

-- Forbidden game actions: calling any of these fails the test.
for _, name in ipairs({ "BuyMerchantItem", "BuybackItem", "PickupMerchantItem", "RepairAllItems", "BuyTrainerService",
    "SelectTrainerService", "SetTrainerServiceTypeFilter", "GetQuestReward", "CompleteQuest", "AcceptQuest",
    "QuestInfoItem_OnClick", "UseContainerItem", "PickupContainerItem", "hooksecurefunc", "CastSpellByName", "RunMacroText" }) do
    _G[name] = function() violate("called " .. name) end
end
C_Container = { UseContainerItem = function() violate("called C_Container.UseContainerItem") end,
    PickupContainerItem = function() violate("called C_Container.PickupContainerItem") end }

----------------------------------------------------------------------------------------------------
-- Blizzard frames: read-only proxies. Reads of fields and Is*/Get* methods are fine; anything that
-- changes them is a violation.
local stateOf = setmetatable({}, { __mode = "k" })
local FORBIDDEN = { Hide = true, Show = true, SetShown = true, SetScript = true, HookScript = true, SetParent = true,
    Click = true, SetPoint = true, ClearAllPoints = true, SetAlpha = true, CreateTexture = true, CreateFontString = true,
    SetID = true, Enable = true, Disable = true, SetAttribute = true, RegisterEvent = true, SetFrameLevel = true }
local function blizz(name, fields)
    local st = { name = name, visible = true, id = 0, top = 100, bottom = 80, fields = fields or {} }
    local proxy = {}
    local methods = {
        IsVisible = function() return st.visible end,
        IsShown = function() return st.visible end,
        GetID = function() return st.id end,
        GetName = function() return name end,
        GetTop = function() return st.top end,
        GetBottom = function() return st.bottom end,
    }
    if st.fields.elementData ~= nil or fields and fields.withElementData then
        methods.GetElementData = function() return st.elementData end
    end
    setmetatable(proxy, {
        __index = function(_, k)
            if methods[k] then return methods[k] end
            if FORBIDDEN[k] then return function() violate(name .. ":" .. k .. "()") end end
            return st.fields[k]
        end,
        __newindex = function(_, k) violate("wrote " .. name .. "." .. tostring(k)) end,
    })
    stateOf[proxy] = st
    return proxy
end
local function S(proxy) return stateOf[proxy] end

----------------------------------------------------------------------------------------------------
-- Our own frames.
local created, createdInCombat = {}, 0
local function region(kind)
    local r = { kind = kind, shown = true, points = {} }
    function r:SetPoint(p, target, rp, x, y) self.points[#self.points + 1] = { p, target, rp, x, y }; self.target = target end
    function r:ClearAllPoints() self.points = {}; self.target = nil end
    function r:SetAllPoints() end
    function r:SetSize(w, h) self.w, self.h = w, h end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetShown(v) self.shown = v and true or false end
    function r:IsShown() return self.shown end
    function r:SetText(t) self.text = t end
    function r:GetStringWidth() return #(self.text or "") * 5 end
    function r:SetTextColor() end
    function r:SetAtlas(a) self.atlas, self.texture = a, nil; return true end
    function r:SetTexture(t) self.texture, self.atlas = t, nil end
    function r:SetColorTexture() end
    function r:SetVertexColor() end
    return r
end
local overlay, events
CreateFrame = function(kind, name, parent)
    if combat then createdInCombat = createdInCombat + 1 end
    local f = region("frame")
    f.parent = parent
    function f:SetFrameStrata(s) self.strata = s end
    function f:SetFrameLevel() end
    function f:SetScript(s, fn) self.scripts = self.scripts or {}; self.scripts[s] = fn end
    function f:RegisterEvent(e) self.events = self.events or {}; self.events[e] = true end
    function f:CreateTexture() local t = region("texture"); self.kids = self.kids or {}; self.kids[#self.kids + 1] = t; return t end
    function f:CreateFontString() local t = region("text"); self.kids = self.kids or {}; self.kids[#self.kids + 1] = t; return t end
    created[#created + 1] = f
    if name == "WindowBadgesOverlay" then overlay = f end
    if not parent then events = f end
    return f
end
UIParent = blizz("UIParent")

-- Badges currently shown on a Blizzard button, as "text|texture" strings.
local function badgesOn(target)
    local list = {}
    for _, f in ipairs(created) do
        if f.parent == overlay and f.shown and f.target == target then
            local icon, text
            for _, kid in ipairs(f.kids or {}) do
                if kid.kind == "text" then text = kid.text end
                if kid.kind == "texture" and kid.shown and (kid.atlas or kid.texture) then
                    icon = kid.atlas or kid.texture
                end
            end
            list[#list + 1] = (text or "") .. "|" .. tostring(icon)
        end
    end
    return list
end
local function badgeHas(target, needle)
    for _, b in ipairs(badgesOn(target)) do
        if b:find(needle, 1, true) then return true end
    end
    return false
end
local function countShown()
    local n = 0
    for _, f in ipairs(created) do
        if f.parent == overlay and f.shown then n = n + 1 end
    end
    return n
end

----------------------------------------------------------------------------------------------------
-- Items and ItemAdvisor.
local items = {}
local function def(id, name, price, classID)
    local link = "|cffffffff|Hitem:" .. id .. "::::|h[" .. name .. "]|h|r"
    items[link] = { name = name, price = price, classID = classID or 4 }
    return link
end
C_Item = {
    GetItemInfo = function(link)
        local i = items[link]
        if not i or i.unloaded then return nil end
        return i.name, link, 2, 10, 1, "Armor", "Mail", 1, "INVTYPE_CHEST", 1, i.price, i.classID, 1, 0
    end,
    GetItemInfoInstant = function(link)
        local i = items[link]
        if not i then return nil end
        return tonumber(link:match("item:(%d+)")), "t", "s", "", 1, i.classID, 0
    end,
    RequestLoadItemDataByID = function(id) end,
}
local upgrades = {}
ItemAdvisor_IsUpgrade = function(link)
    local u = upgrades[link]
    if u then return true, u end
    return false, "Not an upgrade"
end

local helm = def(100, "Helm", 500)
local boots = def(101, "Boots", 9000)
local ring = def(102, "Ring", 300)
local cloth = def(103, "Cloth", 50, 7)
local recipeKnown = def(104, "Recipe: Known", 100, 9)
local recipeNew = def(105, "Recipe: New", 100, 9)
local sword = def(106, "Sword", 2000, 2)

----------------------------------------------------------------------------------------------------
-- Quest window.
local choices = {}
GetNumQuestChoices = function() return #choices end
GetQuestItemLink = function(kind, i) check(kind == "choice", "asks for choice links"); return choices[i] end
GetQuestItemInfo = function(kind, i) return "name", "tex", 1 end
GetQuestItemInfoLootType = function() return 0 end
local rewardButtons = {}
for i = 1, 4 do
    local b = blizz("QuestInfoRewardsFrameQuestInfoItem" .. i, { type = "choice", objectType = "item" })
    S(b).id = i
    rewardButtons[i] = b
end
-- A fixed reward button that must never be marked.
local fixed = blizz("QuestInfoRewardsFrameQuestInfoItem5", { type = "reward", objectType = "item" })
S(fixed).id = 1
rewardButtons[5] = fixed
QuestInfoRewardsFrame = blizz("QuestInfoRewardsFrame", { RewardButtons = rewardButtons })
QuestFrame = blizz("QuestFrame")

-- Merchant window.
local merchant = {}
MERCHANT_ITEMS_PER_PAGE = 10
MerchantFrame = blizz("MerchantFrame", { selectedTab = 1, page = 1 })
local merchantButtons = {}
for i = 1, 10 do
    merchantButtons[i] = blizz("MerchantItem" .. i .. "ItemButton")
    _G["MerchantItem" .. i .. "ItemButton"] = merchantButtons[i]
end
GetMerchantNumItems = function() return #merchant end
GetMerchantItemLink = function(i) return merchant[i] end
ITEM_SPELL_KNOWN = "Already known"
local knownRecipes = { [recipeKnown] = true }
C_TooltipInfo = {
    GetMerchantItem = function(i)
        local link = merchant[i]
        local lines = { { leftText = items[link] and items[link].name or "?" }, { leftText = "Requires Tailoring (50)" } }
        if knownRecipes[link] then lines[#lines + 1] = { leftText = "Already known", leftColor = { r = 1, g = 0.1, b = 0.1 } } end
        return { lines = lines }
    end,
}
local function setMerchantPage()
    local page = MerchantFrame.page
    for i = 1, 10 do
        local index = (page - 1) * 10 + i
        S(merchantButtons[i]).visible = index <= #merchant
        S(merchantButtons[i]).id = index
    end
end

-- Trainer window (Forever: ScrollBox with element data).
local services = {}
Enum = { TrainerType = { General = 0, Tradeskills = 2 }, SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 } }
local trainerType = 0
C_Trainer = { GetTrainerType = function() return trainerType end }
GetNumTrainerServices = function() return #services end
GetTrainerServiceInfo = function(i)
    local s = services[i]
    if not s then return nil end
    return s[1], s[2], s[3], false
end
local rows = {}
local box = blizz("ClassTrainerFrame.ScrollBox", { GetFrames = function() return rows end })
S(box).top, S(box).bottom = 400, 100
ClassTrainerFrame = blizz("ClassTrainerFrame", { ScrollBox = box })
local function setRows(indices)
    for i = #rows, 1, -1 do rows[i] = nil end
    for n, index in ipairs(indices) do
        local row = blizz("TrainerRow" .. n, { withElementData = true })
        S(row).elementData = { skillIndex = index }
        S(row).top, S(row).bottom = 400 - (n - 1) * 40, 400 - n * 40
        rows[n] = row
    end
end
-- Spellbook and bars.
local spellNames = { [1] = "Fireball", [2] = "Frost Armor", [3] = "Arcane Intellect", [4] = "Polymorph" }
local book = { 1, 2, 3, 4 }
local bars = { [1] = 1, [2] = 2 }
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #book } end,
    GetSpellBookItemInfo = function(slot) local id = book[slot]; return id and { itemType = 1, name = spellNames[id], spellID = id } end,
}
GetActionInfo = function(slot) if bars[slot] then return "spell", bars[slot] end end
C_Spell = { GetSpellName = function(id) return spellNames[id] end }

----------------------------------------------------------------------------------------------------
-- Load and log in.
SlashCmdList = {}
local blizzGlobals = { "QuestInfoRewardsFrame", "QuestFrame", "MerchantFrame", "ClassTrainerFrame", "UIParent" }
local before = {}
for _, g in ipairs(blizzGlobals) do before[g] = _G[g] end

assert(loadfile(base .. "/WindowBadges/WindowBadges.lua"))("WindowBadges", {})
check(overlay ~= nil and overlay.strata == "HIGH" and overlay.parent == UIParent, "overlay is ours, on UIParent, HIGH strata")
check(events and events.events and events.events.QUEST_COMPLETE and events.events.MERCHANT_SHOW and events.events.TRAINER_SHOW, "events registered")
local function fire(event, ...)
    local fn = events.scripts and events.scripts.OnEvent
    local ok, err = pcall(fn, events, event, ...)
    check(ok, event .. " must not error: " .. tostring(err))
    flush()
end
local function watch()
    local ok, err = pcall(overlay.scripts.OnUpdate, overlay, 1)
    check(ok, "watcher must not error: " .. tostring(err))
    flush()
end
local function page(arg)
    out = {}
    local ok, err = pcall(SlashCmdList.WINDOWBADGES, arg)
    check(ok, "page must not error: " .. tostring(err))
end
local function has(list, text) for _, t in ipairs(list) do if tostring(t):find(text, 1, true) then return true end end return false end

fire("QUEST_COMPLETE") -- before login: nothing happens, nothing breaks
local poolBefore = #created
fire("PLAYER_LOGIN")
check(type(WindowBadgesDB) == "table", "DB created")
check(#created - poolBefore >= 40, "badge pool made at login (" .. (#created - poolBefore) .. " frames)")
check(overlay.scripts and overlay.scripts.OnUpdate, "watcher runs on our overlay")

-- The quest-reward badges start off, since ItemAdvisor already marks rewards; toggling turns them on.
out = {}
SlashCmdList.WINDOWBADGES("toggle reward")
check(has(out, "now |cff33ff33on"), "reward badge starts off, so toggle turns it on")
SlashCmdList.WINDOWBADGES("on gold")
check(WindowBadgesDB.reward == true and WindowBadgesDB.gold == true, "both reward badges switched on for the checks below")
local poolSize = #created

----------------------------------------------------------------------------------------------------
-- 1. Quest rewards.
choices = { helm, boots, ring }
upgrades = { [helm] = "Upgrade for warrior (+5, 3%)", [ring] = "Upgrade for warrior (+12, 8%)" }
fire("QUEST_COMPLETE")
check(badgeHas(rewardButtons[3], "Best"), "biggest upgrade gets Best")
check(not badgeHas(rewardButtons[1], "Best"), "smaller upgrade doesn't get Best")
check(badgeHas(rewardButtons[2], "Most gold"), "highest vendor value gets Most gold")
check(#badgesOn(fixed) == 0, "fixed (non-choice) reward never marked")
-- Best and most gold on the same item: just Best.
choices = { helm, boots }
upgrades = { [boots] = "Upgrade for warrior (fills an empty slot)" }
fire("QUEST_DETAIL")
check(badgeHas(rewardButtons[2], "Best") and not badgeHas(rewardButtons[2], "Most gold"), "same item: only Best")
check(#badgesOn(rewardButtons[1]) == 0, "other reward unmarked")
-- No ItemAdvisor: Most gold only.
local savedIA = ItemAdvisor_IsUpgrade
ItemAdvisor_IsUpgrade = nil
choices = { helm, boots, ring }
fire("QUEST_COMPLETE")
check(badgeHas(rewardButtons[2], "Most gold") and countShown() == 1, "without ItemAdvisor only Most gold shows")
page("")
check(has(out, "ItemAdvisor isn't loaded"), "page says ItemAdvisor is missing")
ItemAdvisor_IsUpgrade = savedIA
-- Tied vendor values: no coin.
local helm2 = def(110, "Helm2", 500)
choices = { helm, helm2 }
upgrades = {}
fire("QUEST_COMPLETE")
check(countShown() == 0, "tie in value: no Most gold, no Best")
-- One choice: nothing to choose.
choices = { boots }
fire("QUEST_COMPLETE")
check(countShown() == 0, "single choice: no badges")
-- Item still loading, then arrives.
choices = { helm, boots }
items[boots].unloaded = true
fire("QUEST_COMPLETE")
check(countShown() == 0, "loading reward: no badge yet")
items[boots].unloaded = nil
fire("GET_ITEM_INFO_RECEIVED", 101)
check(badgeHas(rewardButtons[2], "Most gold"), "repaints when the item arrives")
-- Hidden button hides its badge.
S(rewardButtons[2]).visible = false
watch()
check(#badgesOn(rewardButtons[2]) == 0, "badge hides when its button is hidden")
S(rewardButtons[2]).visible = true
fire("QUEST_FINISHED")
check(countShown() == 0, "QUEST_FINISHED clears reward badges")
-- Secret values from the quest API.
GetNumQuestChoices = function() return SECRET end
fire("QUEST_COMPLETE")
check(countShown() == 0, "secret choice count: nothing")
GetNumQuestChoices = function() return 2 end
GetQuestItemLink = function() return SECRET end
fire("QUEST_COMPLETE")
check(countShown() == 0, "secret links: nothing")
GetQuestItemLink = function(_, i) return choices[i] end
GetNumQuestChoices = function() return #choices end
ItemAdvisor_IsUpgrade = function() return SECRET, SECRET end
fire("QUEST_COMPLETE")
check(badgeHas(rewardButtons[2], "Most gold") and not badgeHas(rewardButtons[2], "Best"), "secret verdict counts as no upgrade")
ItemAdvisor_IsUpgrade = function() error("boom") end
fire("QUEST_COMPLETE")
check(badgeHas(rewardButtons[2], "Most gold"), "ItemAdvisor erroring doesn't break the gold badge")
ItemAdvisor_IsUpgrade = savedIA
fire("QUEST_FINISHED")
-- Currency choices are skipped.
GetQuestItemInfoLootType = function(_, i) return i == 2 and 1 or 0 end
choices = { helm, boots, ring }
fire("QUEST_COMPLETE")
check(not badgeHas(rewardButtons[2], "Most gold") and badgeHas(rewardButtons[1], "Most gold"), "currency choice skipped")
GetQuestItemInfoLootType = function() return 0 end
fire("QUEST_FINISHED")

-- Toggles for rewards.
choices = { helm, boots, ring }
upgrades = { [ring] = "Upgrade (+12, 8%)" }
page("off reward")
check(WindowBadgesDB.reward == false, "off reward saved")
fire("QUEST_COMPLETE")
check(not badgeHas(rewardButtons[3], "Best") and badgeHas(rewardButtons[2], "Most gold"), "reward off: Best gone, gold stays")
page("off gold")
fire("QUEST_COMPLETE")
check(countShown() == 0, "both reward kinds off: nothing")
page("on reward"); page("on gold")
fire("QUEST_FINISHED")

----------------------------------------------------------------------------------------------------
-- 2. Merchant.
merchant = { cloth, sword, recipeKnown, recipeNew }
for i = 5, 13 do merchant[i] = def(200 + i, "Thing" .. i, 10) end
merchant[12] = def(300, "Shield", 100)
upgrades = { [sword] = "Upgrade (+3, 2%)", [merchant[12]] = "Upgrade (+9, 5%)" }
setMerchantPage()
fire("MERCHANT_SHOW")
check(badgeHas(merchantButtons[2], "bags-greenarrow"), "upgrade at vendor gets the green arrow")
check(#badgesOn(merchantButtons[1]) == 0, "non-upgrade unmarked")
check(badgeHas(merchantButtons[3], "ReadyCheck-Ready"), "known recipe gets a check")
check(#badgesOn(merchantButtons[4]) == 0, "unknown recipe unmarked")
check(not badgeHas(merchantButtons[2], "ReadyCheck"), "non-recipe never gets a known check")
-- Page flip: no event, the watcher notices.
MerchantFrame = blizz("MerchantFrame", { selectedTab = 1, page = 2 })
setMerchantPage()
watch()
check(badgeHas(merchantButtons[2], "bags-greenarrow"), "page 2: item 12 (slot 2) is an upgrade")
check(not badgeHas(merchantButtons[3], "ReadyCheck"), "page 2: no stale recipe check")
check(#badgesOn(merchantButtons[5]) == 0, "page 2: empty slot has nothing")
-- Buyback tab: nothing.
MerchantFrame = blizz("MerchantFrame", { selectedTab = 2, page = 1 })
watch()
check(countShown() == 0, "buyback tab: no badges")
MerchantFrame = blizz("MerchantFrame", { selectedTab = 1, page = 1 })
setMerchantPage()
watch()
check(badgeHas(merchantButtons[2], "bags-greenarrow"), "back on the buy tab")
-- Hidden button.
S(merchantButtons[2]).visible = false
watch()
check(#badgesOn(merchantButtons[2]) == 0, "hidden merchant button hides its badge")
S(merchantButtons[2]).visible = true
-- Toggles.
page("off merchant")
fire("MERCHANT_UPDATE")
check(not badgeHas(merchantButtons[2], "bags-greenarrow") and badgeHas(merchantButtons[3], "ReadyCheck"), "merchant off: arrows gone, checks stay")
page("off known")
fire("MERCHANT_UPDATE")
check(countShown() == 0, "both merchant kinds off: nothing")
page("on merchant"); page("on known")
-- Secrets and missing tooltip data.
GetMerchantItemLink = function(i) if i == 2 then return SECRET end return merchant[i] end
fire("MERCHANT_UPDATE")
check(#badgesOn(merchantButtons[2]) == 0 and badgeHas(merchantButtons[3], "ReadyCheck"), "secret link skipped, others fine")
GetMerchantItemLink = function(i) return merchant[i] end
local savedTip = C_TooltipInfo
C_TooltipInfo = nil
fire("MERCHANT_UPDATE")
check(badgeHas(merchantButtons[2], "bags-greenarrow") and not badgeHas(merchantButtons[3], "ReadyCheck"), "no tooltip API: no checks, arrows still")
C_TooltipInfo = { GetMerchantItem = function() return { lines = { { leftText = SECRET }, { leftText = SECRET } } } end }
fire("MERCHANT_UPDATE")
check(not badgeHas(merchantButtons[3], "ReadyCheck"), "secret tooltip lines: no check")
C_TooltipInfo = savedTip
fire("MERCHANT_CLOSED")
check(countShown() == 0, "MERCHANT_CLOSED clears merchant badges")

----------------------------------------------------------------------------------------------------
-- 3. Trainer.
services = {
    { "General", nil, "header" },
    { "Fireball", "Rank 3", "available" },      -- on bars -> On your bars
    { "Frost Nova", "Rank 1", "available" },    -- not known -> New
    { "Arcane Intellect", "Rank 2", "available" }, -- known, not on bars -> nothing
    { "Frost Armor", "Rank 2", "unavailable" }, -- on bars but not trainable yet -> nothing
    { "Polymorph", "Rank 1", "used" },
    { "Blink", "", "unavailable" },
}
setRows({ 1, 2, 3, 4, 5, 6, 7 })
fire("TRAINER_SHOW")
check(badgeHas(rows[2], "On your bars"), "higher rank of a spell on your bars")
check(badgeHas(rows[3], "New"), "new spell")
check(#badgesOn(rows[4]) == 0, "known spell not on bars: nothing")
check(#badgesOn(rows[5]) == 0, "unavailable: nothing")
check(#badgesOn(rows[1]) == 0 and #badgesOn(rows[6]) == 0 and #badgesOn(rows[7]) == 0, "header, used, unavailable: nothing")
-- Scrolling: rows recycled with other indices; the watcher repaints.
setRows({ 3, 2 })
watch()
check(badgeHas(rows[1], "New") and badgeHas(rows[2], "On your bars"), "recycled rows repainted after scroll")
-- A row scrolled half out of the list hides its badge.
S(rows[2]).bottom = 50
watch()
check(#badgesOn(rows[2]) == 0, "row outside the list: badge hidden")
S(rows[2]).bottom = 320
-- Other return order (name, type, _, level, rank) from TrainerNotes' notes.
GetTrainerServiceInfo = function(i)
    local s = services[i]
    if not s then return nil end
    return s[1], s[3], nil, 10, s[2]
end
fire("TRAINER_UPDATE")
check(badgeHas(rows[1], "New") and badgeHas(rows[2], "On your bars"), "alternate return order read")
-- Bars change: cache dropped.
bars = {}
fire("ACTIONBAR_SLOT_CHANGED")
check(not badgeHas(rows[2], "On your bars") and #badgesOn(rows[2]) == 0, "spell removed from bars: no badge (known spell)")
bars = { [1] = 1, [2] = 2 }
fire("ACTIONBAR_SLOT_CHANGED")
-- Toggle.
page("off trainer")
fire("TRAINER_UPDATE")
check(countShown() == 0, "trainer off: nothing")
page("on trainer")
-- Profession trainer: nothing.
trainerType = 2
fire("TRAINER_UPDATE")
check(countShown() == 0, "profession trainer: nothing")
trainerType = 0
-- Secret service info.
GetTrainerServiceInfo = function() return SECRET, SECRET, SECRET end
fire("TRAINER_UPDATE")
check(countShown() == 0, "secret service info: nothing")
GetTrainerServiceInfo = function(i) local s = services[i]; if s then return s[1], s[2], s[3] end end
-- Unreadable spellbook: no "New", "On your bars" still works.
local savedBook = C_SpellBook
C_SpellBook = nil
fire("SPELLS_CHANGED")
check(badgeHas(rows[2], "On your bars") and not badgeHas(rows[1], "New"), "no spellbook: no New guesses")
C_SpellBook = savedBook
fire("SPELLS_CHANGED")
-- Hidden trainer frame hides badges.
S(ClassTrainerFrame).visible = false
watch()
check(countShown() == 0, "trainer frame hidden: badges hidden")
S(ClassTrainerFrame).visible = true
fire("TRAINER_CLOSED")
-- Classic trainer list (ClassTrainerSkillN with IDs), no ScrollBox.
ClassTrainerFrame = blizz("ClassTrainerFrame")
for i = 1, 3 do
    local b = blizz("ClassTrainerSkill" .. i)
    S(b).id = i + 1
    _G["ClassTrainerSkill" .. i] = b
end
fire("TRAINER_SHOW")
check(badgeHas(ClassTrainerSkill1, "On your bars") and badgeHas(ClassTrainerSkill2, "New"), "Classic trainer rows")
fire("TRAINER_CLOSED")
check(countShown() == 0, "TRAINER_CLOSED clears")

----------------------------------------------------------------------------------------------------
-- Combat: badges hide, no frames are made, everything returns afterwards.
choices = { helm, boots, ring }
upgrades = { [ring] = "Upgrade (+12, 8%)" }
fire("QUEST_COMPLETE")
check(countShown() == 2, "reward badges before combat")
combat = true
fire("PLAYER_REGEN_DISABLED")
check(countShown() == 0, "combat hides badges")
fire("QUEST_COMPLETE")
watch()
check(countShown() == 0, "no painting in combat")
combat = false
fire("PLAYER_REGEN_ENABLED")
check(countShown() == 2, "badges back after combat")
check(createdInCombat == 0, "no frames created in combat")
check(#created == poolSize, "no frames created after login (pool only)")
fire("QUEST_FINISHED")

----------------------------------------------------------------------------------------------------
-- Missing frames and APIs.
QuestInfoRewardsFrame, QuestFrame, MerchantFrame, ClassTrainerFrame = nil, nil, nil, nil
for i = 1, 10 do _G["MerchantItem" .. i .. "ItemButton"] = nil end
for i = 1, 3 do _G["ClassTrainerSkill" .. i] = nil end
GetNumQuestChoices, GetQuestItemLink, GetQuestItemInfo, GetQuestItemInfoLootType = nil, nil, nil, nil
GetMerchantNumItems, GetMerchantItemLink, C_TooltipInfo = nil, nil, nil
C_Trainer, GetTrainerServiceInfo, C_SpellBook, GetActionInfo, C_Spell, C_Item = nil, nil, nil, nil, nil, nil
for _, e in ipairs({ "QUEST_COMPLETE", "MERCHANT_SHOW", "MERCHANT_UPDATE", "TRAINER_SHOW", "TRAINER_UPDATE", "GET_ITEM_INFO_RECEIVED", "BAG_UPDATE_DELAYED" }) do
    fire(e)
end
watch()
check(countShown() == 0, "missing frames: nothing shown")
check(#handled == 0, "no errors reported with missing frames/APIs:\n  " .. table.concat(handled, "\n  "))

-- Page.
page("")
check(has(out, "Best reward") and has(out, "Most gold") and has(out, "Vendor upgrades") and has(out, "Known recipes") and has(out, "Trainer spells"), "page lists every badge")
check(has(out, "Type: off reward"), "page shows the hint")
page("bogus")
check(has(out, "reward, gold, merchant, known, trainer"), "unknown name lists the choices")
page("toggle known")
check(WindowBadgesDB.known == false, "toggle works")
check(SLASH_WINDOWBADGES1 == "/windowbadges", "slash registered")

-- Blizzard globals untouched.
QuestInfoRewardsFrame, QuestFrame, MerchantFrame, ClassTrainerFrame = before.QuestInfoRewardsFrame, before.QuestFrame, nil, nil
check(UIParent == before.UIParent, "UIParent untouched")

for _, v in ipairs(violations) do failures[#failures + 1] = "RULE VIOLATION: " .. v end
if #failures > 0 then
    error(#failures .. " failure(s):\n" .. table.concat(failures, "\n"), 0)
end
print("test_windowbadges: all passed")
