-- SpellReady (folder ReadyCheck): old spell ranks on your bars, missing self-buffs and low class
-- reagents. Read-only: it never casts, never touches your bars or Blizzard's frames.
-- The slash key is SPELLREADY because Blizzard's own /readycheck already uses SlashCmdList.READYCHECK.
local SOURCE = "SpellReady"
local NUM_ACTION_SLOTS = 180
local LOW_SECONDS = 60
local TOAST_REPEAT_SECONDS = 300
local LOW_REAGENT = 3
local CHECK_EVERY = 15

-- Self-maintained buffs per class. spells: what you cast (best first); auras: what counts as up
-- (defaults to spells). weapon: a temporary weapon enchant on that inventory slot instead of an aura.
local BUFFS = {
    DRUID = {
        { spells = { "Mark of the Wild" }, auras = { "Mark of the Wild", "Gift of the Wild" } },
        { spells = { "Thorns" } },
    },
    MAGE = {
        { spells = { "Arcane Intellect" }, auras = { "Arcane Intellect", "Arcane Brilliance" } },
        { spells = { "Ice Armor", "Frost Armor", "Mage Armor" } },
    },
    PRIEST = {
        { spells = { "Power Word: Fortitude" }, auras = { "Power Word: Fortitude", "Prayer of Fortitude" } },
        { spells = { "Inner Fire" } },
    },
    WARLOCK = {
        { spells = { "Demon Armor", "Demon Skin" } },
    },
    PALADIN = {
        { label = "A Blessing", spells = { "Blessing of Might", "Blessing of Wisdom", "Blessing of Kings", "Blessing of Salvation", "Blessing of Light", "Blessing of Sanctuary" },
          auras = { "Blessing of Might", "Blessing of Wisdom", "Blessing of Kings", "Blessing of Salvation", "Blessing of Light", "Blessing of Sanctuary",
                    "Greater Blessing of Might", "Greater Blessing of Wisdom", "Greater Blessing of Kings", "Greater Blessing of Salvation", "Greater Blessing of Light", "Greater Blessing of Sanctuary" } },
        { label = "A Paladin aura", spells = { "Devotion Aura", "Retribution Aura", "Concentration Aura", "Sanctity Aura", "Shadow Resistance Aura", "Frost Resistance Aura", "Fire Resistance Aura" } },
    },
    HUNTER = {
        { label = "An Aspect", spells = { "Aspect of the Hawk", "Aspect of the Monkey", "Aspect of the Cheetah", "Aspect of the Pack", "Aspect of the Wild", "Aspect of the Beast" } },
        { spells = { "Trueshot Aura" } },
    },
    SHAMAN = {
        { spells = { "Lightning Shield" } },
        { label = "Weapon imbue", weapon = 16, spells = { "Windfury Weapon", "Flametongue Weapon", "Frostbrand Weapon", "Rockbiter Weapon" } },
    },
    ROGUE = {
        { label = "Main-hand poison", weapon = 16, spells = { "Poisons", "Instant Poison", "Deadly Poison", "Crippling Poison", "Mind-numbing Poison", "Wound Poison" } },
        { label = "Off-hand poison", weapon = 17, spells = { "Poisons", "Instant Poison", "Deadly Poison", "Crippling Poison", "Mind-numbing Poison", "Wound Poison" } },
    },
    -- Warriors: Battle Shout only matters in combat, so nothing to remind about.
}

-- Class reagents, only for spells you have on your bars (onlyKnown: passive spells that never sit on a bar).
-- byRank picks the reagent by the rank you use. prefixes match spell families like "Teleport: Darnassus".
local REAGENTS = {
    MAGE = {
        { item = 17031, name = "Rune of Teleportation", prefixes = { "Teleport: " } },
        { item = 17032, name = "Rune of Portals", prefixes = { "Portal: " } },
        { item = 17020, name = "Arcane Powder", spells = { "Arcane Brilliance" } },
        { item = 17056, name = "Light Feather", spells = { "Slow Fall" } },
    },
    PRIEST = {
        { spells = { "Prayer of Fortitude" }, byRank = { { 17028, "Holy Candle" }, { 17029, "Sacred Candle" } } },
        { item = 17029, name = "Sacred Candle", spells = { "Prayer of Shadow Protection", "Prayer of Spirit" } },
        { item = 17056, name = "Light Feather", spells = { "Levitate" } },
    },
    DRUID = {
        { spells = { "Rebirth" }, byRank = { { 17034, "Maple Seed" }, { 17035, "Stranglethorn Seed" }, { 17036, "Ashwood Seed" }, { 17037, "Hornbeam Seed" }, { 17038, "Ironwood Seed" } } },
        { spells = { "Gift of the Wild" }, byRank = { { 17021, "Wild Berries" }, { 17026, "Wild Thornroot" } } },
    },
    PALADIN = {
        { item = 17033, name = "Symbol of Divinity", spells = { "Divine Intervention" } },
        { item = 21177, name = "Symbol of Kings", prefixes = { "Greater Blessing of " } },
    },
    SHAMAN = {
        { item = 17030, name = "Ankh", spells = { "Reincarnation" }, onlyKnown = true },
        { item = 17058, name = "Fish Oil", spells = { "Water Walking" } },
        { item = 17057, name = "Shiny Fish Scales", spells = { "Water Breathing" } },
    },
    WARLOCK = {
        { item = 6265, name = "Soul Shard", spells = { "Summon Voidwalker", "Summon Succubus", "Summon Felhunter", "Ritual of Summoning", "Shadowburn", "Soul Fire" },
          prefixes = { "Create Healthstone", "Create Soulstone", "Create Spellstone", "Create Firestone" } },
    },
    ROGUE = {
        { item = 5140, name = "Flash Powder", spells = { "Vanish" } },
        { item = 5530, name = "Blinding Powder", spells = { "Blind" } },
    },
}

local db
local known = {}      -- lower name -> { name, rank } from the spellbook
local onBars = {}     -- lower name -> { name, rank } highest rank found on the bars
local cache = { ranks = {}, buffs = {}, buffsChecked = false, reagents = {} }
local lastMissing, lastToast = {}, {}
local pending, deferred = {}, {}
local inCombat = false

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive(SOURCE, text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, result = pcall(fn, ...)
    return ok and Safe(result) or nil
end

local function DB()
    if not db then
        ReadyCheckDB = type(ReadyCheckDB) == "table" and ReadyCheckDB or {}
        ReadyCheckDB.ignored = type(ReadyCheckDB.ignored) == "table" and ReadyCheckDB.ignored or {}
        db = ReadyCheckDB
    end
    return db
end

local function InCombat()
    if InCombatLockdown then
        local value = SafeCall(InCombatLockdown)
        if value ~= nil then
            return value and true or false
        end
    end
    return inCombat
end

local function PlayerClass()
    if not UnitClass then
        return nil
    end
    local ok, _, file = pcall(UnitClass, "player")
    return ok and Safe(file) or nil
end

local function RankOf(subtext)
    if type(subtext) ~= "string" then
        return nil
    end
    return tonumber(subtext:match("(%d+)"))
end

local function Remember(list, name, rank)
    if type(name) ~= "string" or name == "" then
        return
    end
    local key = name:lower()
    local entry = list[key]
    if not entry then
        list[key] = { name = name, rank = rank }
    elseif rank and rank > (entry.rank or 0) then
        entry.rank = rank
    end
end

local function Knows(name)
    return known[name:lower()] ~= nil
end

-- Spells this addon asked the game to load; SPELL_DATA_LOAD_RESULT for one of them rescans.
local waitingSpells = {}
local SPELL_RETRY_DELAY, SPELL_RETRY_LIMIT = 3, 3
local spellRetries = 0

-- True when the spell's name and rank can be read now. Otherwise asks the game to load it
-- (C_Spell.RequestLoadSpellData; the answer is SPELL_DATA_LOAD_RESULT) and returns false.
local function SpellLoaded(id)
    if not (C_Spell and C_Spell.IsSpellDataCached) then
        return true
    end
    local ok, cached = pcall(C_Spell.IsSpellDataCached, id)
    -- A hidden or failed answer can't be waited on; read what's there.
    if not ok or Safe(cached) == nil or Safe(cached) then
        return true
    end
    waitingSpells[id] = true
    if C_Spell.RequestLoadSpellData then
        pcall(C_Spell.RequestLoadSpellData, id)
    end
    return false
end

-- Every spell you know, with the highest rank seen. Some clients list only the top rank: that's all we need.
local function ScanSpellBook()
    local list = {}
    if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then
        return list
    end
    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    local spellType = (Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell) or 1
    for line = 1, SafeCall(C_SpellBook.GetNumSpellBookSkillLines) or 0 do
        local info = SafeCall(C_SpellBook.GetSpellBookSkillLineInfo, line)
        if type(info) == "table" then
            -- A skill line's name (such as Poisons) also counts as something you know.
            Remember(list, Safe(info.name), nil)
            local offset, count = Safe(info.itemIndexOffset), Safe(info.numSpellBookItems)
            if type(offset) == "number" and type(count) == "number" then
                for slot = offset + 1, offset + count do
                    local item = SafeCall(C_SpellBook.GetSpellBookItemInfo, slot, bank)
                    if type(item) == "table" and Safe(item.itemType) == spellType and not Safe(item.isOffSpec) then
                        local subName = Safe(item.subName)
                        local id = Safe(item.spellID) or Safe(item.actionID)
                        if (type(subName) ~= "string" or subName == "") and id and C_Spell and SpellLoaded(id) then
                            subName = SafeCall(C_Spell.GetSpellSubtext, id)
                        end
                        Remember(list, Safe(item.name), RankOf(subName))
                    end
                end
            end
        end
    end
    return list
end

-- Readable names for action slots, by blocks of 12. Slots 73-120 are the pages the main bar
-- switches to in a stance or form (bonus bars 1-4), named per class where the page is well known.
local BAR_BLOCKS = {
    [1] = "Action bar 1", [2] = "Action bar 1 (page 2)", [3] = "Right bar", [4] = "Right bar 2",
    [5] = "Bottom right bar", [6] = "Bottom left bar", [11] = "Special bar (possess or vehicle)",
    [13] = "Action bar 6", [14] = "Action bar 7", [15] = "Action bar 8",
}
local FORM_BARS = {
    WARRIOR = { "Battle Stance bar", "Defensive Stance bar", "Berserker Stance bar" },
    DRUID = { "Cat Form bar", nil, "Bear Form bar", "Moonkin Form bar" },
    ROGUE = { "Stealth bar" },
    PRIEST = { "Shadowform bar" },
}

-- "Action bar 1, button 3", "Bottom left bar, button 5", "Battle Stance bar, button 2".
local function SlotLabel(slot)
    local block = math.floor((slot - 1) / 12) + 1
    local button = (slot - 1) % 12 + 1
    local bar = BAR_BLOCKS[block]
    if not bar and block >= 7 and block <= 10 then
        local forms = FORM_BARS[PlayerClass() or ""]
        bar = forms and forms[block - 6] or ("Stance or form bar " .. (block - 6))
    end
    bar = bar or string.format("Bar slots %d-%d", (block - 1) * 12 + 1, block * 12)
    return string.format("%s, button %d", bar, button)
end

-- A macro's spell: what the slot reports when it's a "spell" macro, else GetMacroSpell on the
-- macro's index, else C_ActionBar.GetSpell for the slot. Also returns the macro's name.
local function MacroSpell(slot, id, subType)
    local name = C_ActionBar and SafeCall(C_ActionBar.GetActionText, slot) or SafeCall(GetActionText, slot)
    name = type(name) == "string" and name ~= "" and name or nil
    local spell
    if subType == "spell" and type(id) == "number" then
        spell = id
    end
    if not spell and type(id) == "number" then
        spell = SafeCall(GetMacroSpell, id)
        if not name and C_Macro then
            name = SafeCall(C_Macro.GetMacroName, id)
        end
    end
    if type(spell) ~= "number" and C_ActionBar then
        spell = SafeCall(C_ActionBar.GetSpell, slot)
    end
    if type(spell) == "number" and spell > 0 then
        return spell, type(name) == "string" and name or "a macro"
    end
    return nil
end

-- The spell ID in an action slot (and the macro's name when a macro holds it), or nil for empty
-- slots, items and anything unreadable.
local function ActionSpell(slot)
    if GetActionInfo then
        local ok, kind, id, subType = pcall(GetActionInfo, slot)
        if not ok then
            return nil
        end
        kind, id, subType = Safe(kind), Safe(id), Safe(subType)
        if kind == "spell" and type(id) == "number" then
            return id
        elseif kind == "macro" then
            return MacroSpell(slot, id, subType)
        end
        return nil
    end
    if C_ActionBar and SafeCall(C_ActionBar.HasAction, slot) then
        local id = SafeCall(C_ActionBar.GetSpell, slot)
        return type(id) == "number" and id > 0 and id or nil
    end
    return nil
end

local function ScanRanks()
    -- Whatever is still unloaded is asked for again below.
    waitingSpells = {}
    known = ScanSpellBook()
    onBars = {}
    local ranks = {}
    local ignored = DB().ignored
    if not C_Spell then
        cache.ranks = ranks
        return
    end
    for slot = 1, NUM_ACTION_SLOTS do
        local id, macro = ActionSpell(slot)
        local name = id and SpellLoaded(id) and SafeCall(C_Spell.GetSpellName, id)
        if type(name) == "string" and name ~= "" then
            local rank = RankOf(SafeCall(C_Spell.GetSpellSubtext, id))
            Remember(onBars, name, rank)
            local best = known[name:lower()]
            if rank and best and best.rank and best.rank > rank and not ignored[name:lower()] then
                ranks[#ranks + 1] = { name = name, slot = slot, rank = rank, best = best.rank, macro = macro }
            end
        end
    end
    cache.ranks = ranks
end

-- Whether the inventory slot holds a weapon that can take a poison or imbue.
local function HasWeapon(slot)
    local link = GetInventoryItemLink and Safe(GetInventoryItemLink("player", slot))
    if not link then
        return false
    end
    if slot == 16 then
        return true
    end
    if not (C_Item and C_Item.GetItemInfoInstant) then
        return false
    end
    local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, link)
    return ok and Safe(classID) == 2
end

-- Returns present (true/false, or nil when it can't be told) and seconds left (nil = unknown/long).
local function WeaponEnchant(slot)
    if GetWeaponEnchantInfo then
        local ok, hasMain, mainLeft, _, _, hasOff, offLeft = pcall(GetWeaponEnchantInfo)
        if not ok then
            return nil
        end
        local has, left = hasMain, mainLeft
        if slot == 17 then
            has, left = hasOff, offLeft
        end
        if issecretvalue and issecretvalue(has) then
            return nil
        end
        if not has then
            return false
        end
        left = Safe(left)
        -- The old call reports milliseconds.
        return true, type(left) == "number" and left > 0 and left / 1000 or nil
    end
    if C_Item and C_Item.GetWeaponEnchantInfo then
        local weaponSlot = Enum and Enum.WeaponSlot and (slot == 17 and Enum.WeaponSlot.OffHand or Enum.WeaponSlot.MainHand) or (slot == 17 and 1 or 0)
        local list = SafeCall(C_Item.GetWeaponEnchantInfo, weaponSlot)
        if type(list) ~= "table" then
            return nil
        end
        for _, enchant in ipairs(list) do
            local kind = type(enchant) == "table" and Safe(enchant.enchantType)
            -- Temporary (2) or Imbue (3); the time left's unit isn't documented, so it isn't used.
            if kind and Safe(enchant.hasEnchant) and (kind == 2 or kind == 3) then
                return true, nil
            end
        end
        return false
    end
    return nil
end

-- Your own helpful auras by name with seconds left (math.huge for no end), or nil if unreadable.
local function ReadAuras()
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
        return nil
    end
    local now = Safe(GetTime()) or 0
    local auras = {}
    local ok = pcall(function()
        for index = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
            if aura == nil then
                break
            end
            if Safe(aura) == nil or Safe(aura.name) == nil then
                error("hidden")
            end
            local expires = Safe(aura.expirationTime)
            local left = (type(expires) == "number" and expires > 0) and (expires - now) or math.huge
            auras[aura.name] = math.max(auras[aura.name] or 0, left)
        end
    end)
    return ok and auras or nil
end

-- Names of the spells in a buff entry that you know, best first.
local function KnownSpells(entry)
    local names = {}
    for _, spell in ipairs(entry.spells) do
        if Knows(spell) then
            names[#names + 1] = spell
        end
    end
    return names
end

local function BuffLabel(entry, names)
    if entry.label then
        return entry.label
    end
    if #names > 1 then
        return names[1] .. " or " .. names[2]
    end
    return names[1]
end

-- Fills cache.buffs with what's missing or running low. Not checked in combat, while dead, or
-- when your auras can't be read: then nothing is claimed missing.
local function ComputeBuffs()
    cache.buffs, cache.buffsChecked, cache.buffsWhy = {}, false, nil
    if InCombat() then
        cache.buffsWhy = "combat"
        return
    end
    if UnitIsDeadOrGhost and Safe(UnitIsDeadOrGhost("player")) then
        cache.buffsWhy = "dead"
        return
    end
    local entries = BUFFS[PlayerClass() or ""]
    if not entries then
        cache.buffsChecked = true
        return
    end
    local auras
    for _, entry in ipairs(entries) do
        local names = KnownSpells(entry)
        if #names > 0 then
            local present, left
            if entry.weapon then
                if HasWeapon(entry.weapon) then
                    present, left = WeaponEnchant(entry.weapon)
                else
                    present = true
                end
            else
                auras = auras or ReadAuras()
                if not auras then
                    cache.buffs, cache.buffsWhy = {}, "unreadable"
                    return
                end
                present = false
                for _, auraName in ipairs(entry.auras or entry.spells) do
                    if auras[auraName] then
                        present = true
                        left = math.max(left or 0, auras[auraName])
                    end
                end
            end
            if present == false then
                cache.buffs[#cache.buffs + 1] = { label = BuffLabel(entry, names) }
            elseif present and left and left < LOW_SECONDS then
                cache.buffs[#cache.buffs + 1] = { label = BuffLabel(entry, names), left = math.max(math.floor(left), 0) }
            end
        end
    end
    cache.buffsChecked = true
end

local function Resting()
    return IsResting and Safe(IsResting()) and true or false
end

-- One pop-up for buffs that just went missing, at most once per 5 minutes per buff, never in towns.
local function NotifyBuffs()
    if not cache.buffsChecked then
        return
    end
    if Resting() then
        -- Leaving town with a buff still missing reminds you again (throttle permitting).
        lastMissing = {}
        return
    end
    local now = Safe(GetTime()) or 0
    local current, fresh = {}, {}
    for _, buff in ipairs(cache.buffs) do
        -- "Running low" and "gone" are separate news, but the 5-minute limit per buff covers both.
        local state = buff.label .. (buff.left and "|low" or "|missing")
        current[state] = true
        if not lastMissing[state] and (not lastToast[buff.label] or now - lastToast[buff.label] >= TOAST_REPEAT_SECONDS) then
            lastToast[buff.label] = now
            fresh[#fresh + 1] = buff.left and string.format("%s runs out in %d s", buff.label, buff.left) or (buff.label .. " is missing")
        end
    end
    lastMissing = current
    if #fresh > 0 then
        Print("Before you pull: " .. table.concat(fresh, ", ") .. ".")
    end
end

local function SpellsUsingReagent(reagent)
    local found, rank = {}, nil
    local function consider(entry)
        found[#found + 1] = entry.name
        if entry.rank and entry.rank > (rank or 0) then
            rank = entry.rank
        end
    end
    local pool = reagent.onlyKnown and known or onBars
    for _, spell in ipairs(reagent.spells or {}) do
        local entry = pool[spell:lower()]
        if entry then
            consider(entry)
        end
    end
    for _, prefix in ipairs(reagent.prefixes or {}) do
        local lowPrefix = prefix:lower()
        for key, entry in pairs(pool) do
            if key:sub(1, #lowPrefix) == lowPrefix then
                consider(entry)
            end
        end
    end
    table.sort(found)
    return found, rank
end

local function BagsLoaded()
    if not (C_Container and C_Container.GetContainerNumSlots) then
        return true
    end
    return (SafeCall(C_Container.GetContainerNumSlots, 0) or 0) > 0
end

local function ComputeReagents()
    local list = {}
    local reagents = REAGENTS[PlayerClass() or ""]
    if reagents and BagsLoaded() and C_Item and C_Item.GetItemCount then
        local seen = {}
        for _, reagent in ipairs(reagents) do
            local spells, rank = SpellsUsingReagent(reagent)
            if #spells > 0 then
                local item, name = reagent.item, reagent.name
                if reagent.byRank then
                    local pick = reagent.byRank[math.min(rank or 1, #reagent.byRank)]
                    item, name = pick[1], pick[2]
                end
                local count = SafeCall(C_Item.GetItemCount, item)
                if type(count) == "number" and count < LOW_REAGENT and not seen[item] then
                    seen[item] = true
                    list[#list + 1] = { name = name, count = count, spells = spells }
                end
            end
        end
    end
    cache.reagents = list
    cache.reagentSpells = reagents ~= nil
end

local RUNNERS = {
    ranks = function()
        ScanRanks()
        ComputeReagents()
        ComputeBuffs()
        NotifyBuffs()
    end,
    buffs = function()
        ComputeBuffs()
        NotifyBuffs()
    end,
    reagents = ComputeReagents,
    -- Spell data arrived (or a retry): ranks and reagents again, without buff pop-ups.
    rescan = function()
        ScanRanks()
        ComputeReagents()
    end,
}

local Schedule

-- Some spells on your bars hadn't loaded: look again a little later, a few times at most. The count
-- resets when the game reports a spell loaded, so this never loops.
local function RetryWaiting()
    if next(waitingSpells) and spellRetries < SPELL_RETRY_LIMIT then
        spellRetries = spellRetries + 1
        Schedule("rescan", SPELL_RETRY_DELAY)
    end
end

local function Run(what)
    pending[what] = nil
    if not DB() then
        return
    end
    -- Nothing is worked out in combat; it all runs again when combat ends.
    if InCombat() then
        deferred[what] = true
        return
    end
    RUNNERS[what]()
    if what == "ranks" or what == "rescan" then
        RetryWaiting()
    end
end

-- Throttle: one run per kind per delay, however many events arrive meanwhile.
function Schedule(what, delay)
    if pending[what] then
        return
    end
    pending[what] = true
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, function() Run(what) end)
    else
        Run(what)
    end
end

local function JoinNames(names, limit)
    if #names <= limit then
        return table.concat(names, ", ")
    end
    local shown = {}
    for index = 1, limit do
        shown[index] = names[index]
    end
    return table.concat(shown, ", ") .. string.format(" and %d more", #names - limit)
end

local function ShowPage()
    -- Read fresh when you look; no pop-ups from here.
    if not InCombat() then
        ScanRanks()
        ComputeReagents()
        RetryWaiting()
    end
    -- In combat this only notes that buffs wait until combat ends.
    ComputeBuffs()
    local problems = #cache.ranks + #cache.reagents + (cache.buffsChecked and #cache.buffs or 0)
    if problems == 0 and cache.buffsChecked then
        Print("|cff66ff66Everything looks ready.|r")
    end

    Print("|cffffd100Old ranks on your bars|r")
    if #cache.ranks == 0 then
        Print("  None. Every spell on your bars is the best rank you know.")
    end
    for _, entry in ipairs(cache.ranks) do
        local where = SlotLabel(entry.slot)
        if entry.macro then
            where = string.format("%s (in macro \"%s\")", where, entry.macro)
        end
        Print(string.format("  %s on %s is Rank %d; you know Rank %d.", entry.name, where, entry.rank, entry.best))
    end
    if next(waitingSpells) then
        Print("  |cff999999Some spells on your bars are still loading; this list updates when they arrive.|r")
    end
    local ignoredCount = 0
    for _ in pairs(DB().ignored) do
        ignoredCount = ignoredCount + 1
    end
    if ignoredCount > 0 then
        Print(string.format("  |cff999999%d spell(s) ignored on purpose. Type ignored to see them.|r", ignoredCount))
    end

    Print("|cff88bbeeMissing buffs|r")
    if cache.buffsWhy == "combat" then
        Print("  Checked again when combat ends.")
    elseif cache.buffsWhy == "dead" then
        Print("  Checked again once you're alive.")
    elseif cache.buffsWhy == "unreadable" then
        Print("  The game isn't showing your buffs right now.")
    elseif not BUFFS[PlayerClass() or ""] then
        Print("  Nothing to keep up for your class.")
    elseif #cache.buffs == 0 then
        Print("  All your buffs are up.")
    else
        for _, buff in ipairs(cache.buffs) do
            Print(buff.left and string.format("  %s runs out in %d s.", buff.label, buff.left) or ("  " .. buff.label .. " is missing."))
        end
        if Resting() then
            Print("  |cff999999No pop-ups in towns and inns.|r")
        end
    end

    Print("|cff66ccddReagents|r")
    if #cache.reagents == 0 then
        Print(cache.reagentSpells and "  Enough for the spells on your bars." or "  Your class spells need no reagents.")
    else
        for _, reagent in ipairs(cache.reagents) do
            Print(string.format("  %s: %d left (for %s).", reagent.name, reagent.count, JoinNames(reagent.spells, 2)))
        end
        Print("  To be warned before you run out, set a target on the Supplies page.")
    end
end

-- Accepts a plain name, [Name] or a spell link.
local function CleanName(text)
    text = text:match("%[(.-)%]") or text
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function HandleSlash(message)
    message = type(message) == "string" and message or ""
    local command, rest = message:match("^(%S*)%s*(.-)%s*$")
    command = (command or ""):lower()
    local ignored = DB().ignored
    if command == "" then
        ShowPage()
    elseif command == "ignore" or command == "unignore" then
        local name = CleanName(rest or "")
        if name == "" then
            Print("Type a spell name, such as: " .. command .. " Frostbolt")
            return
        end
        local key = name:lower()
        if command == "ignore" then
            local entry = known[key] or onBars[key]
            ignored[key] = entry and entry.name or name
            Print(string.format("Ignoring %s: lower ranks of it on your bars won't be mentioned.", ignored[key]))
        elseif ignored[key] then
            Print(string.format("%s is checked again.", ignored[key]))
            ignored[key] = nil
        else
            Print(string.format("%s wasn't ignored.", name))
        end
        if not InCombat() then
            ScanRanks()
        end
    elseif command == "ignored" then
        local names = {}
        for _, name in pairs(ignored) do
            names[#names + 1] = name
        end
        table.sort(names)
        if #names == 0 then
            Print("Nothing ignored. Type ignore and a spell name to stop checking its rank.")
        else
            Print("Ranks not checked: " .. table.concat(names, ", ") .. ".")
        end
    else
        Print("Type: ignore Frostbolt   Or: unignore Frostbolt   Or: ignored")
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
    "ACTIONBAR_SLOT_CHANGED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "LEARNED_SPELL_IN_TAB",
    "PLAYER_LEVEL_UP", "SPELL_TEXT_UPDATE", "UNIT_AURA", "UNIT_INVENTORY_CHANGED",
    "PLAYER_UPDATE_RESTING", "BAG_UPDATE_DELAYED",
    -- The answer to C_Spell.RequestLoadSpellData, and macro edits (a macro can now cast another spell).
    "SPELL_DATA_LOAD_RESULT", "UPDATE_MACROS",
}) do
    -- An event this client doesn't have (LEARNED_SPELL_IN_TAB is gone from newer ones) mustn't stop loading.
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        DB()
        if C_Timer and C_Timer.NewTicker then
            -- Buffs tick down without any event; look again now and then, out of combat only.
            C_Timer.NewTicker(CHECK_EVERY, function()
                if not InCombat() then
                    Schedule("buffs", 0)
                end
            end)
        end
        Schedule("ranks", 2)
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "SPELL_DATA_LOAD_RESULT" then
        -- Only spells this addon asked for; payload is (spellID, success).
        local id = Safe(unit)
        if id and waitingSpells[id] then
            waitingSpells[id] = nil
            spellRetries = 0
            Schedule("rescan", 0.5)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        if deferred.ranks or deferred.rescan then
            deferred = {}
            Schedule("ranks", 1)
        else
            deferred = {}
            Schedule("reagents", 1)
            Schedule("buffs", 1)
        end
    elseif event == "UNIT_AURA" or event == "UNIT_INVENTORY_CHANGED" then
        if Safe(unit) == "player" and not InCombat() then
            Schedule("buffs", 1)
        end
    elseif event == "PLAYER_UPDATE_RESTING" then
        Schedule("buffs", 1)
    elseif event == "BAG_UPDATE_DELAYED" then
        Schedule("reagents", 1)
    else
        Schedule("ranks", 2)
    end
end)

SLASH_SPELLREADY1 = "/rcheck"
SlashCmdList.SPELLREADY = function(message)
    HandleSlash(message)
end

-- Rows come from what the events last worked out; nothing heavy here.
ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.SpellReady = function()
    if not db then
        return nil
    end
    local rows = {}
    if #cache.ranks > 0 then
        local names, seen = {}, {}
        for _, entry in ipairs(cache.ranks) do
            if not seen[entry.name] then
                seen[entry.name] = true
                names[#names + 1] = entry.name
            end
        end
        local text = #names == 1 and (names[1] .. " on your bars is old") or string.format("%s and %d more on your bars are old", names[1], #names - 1)
        rows[#rows + 1] = { text = "|cffffd100Rank|r " .. text, page = "Ready check" }
    end
    if cache.buffsChecked and #cache.buffs > 0 and not InCombat() and not Resting() then
        local first = cache.buffs[1]
        local text = first.left and (first.label .. " runs out soon") or (first.label .. " is missing")
        if #cache.buffs > 1 then
            text = text .. string.format(" (+%d)", #cache.buffs - 1)
        end
        rows[#rows + 1] = { text = "|cff88bbeeBuff|r " .. text, page = "Ready check" }
    end
    if #rows < 2 and #cache.reagents > 0 then
        local first = cache.reagents[1]
        rows[#rows + 1] = { text = string.format("|cff66ccddReagent|r %s: %d left", first.name, first.count), page = "Ready check" }
    end
    return rows
end
