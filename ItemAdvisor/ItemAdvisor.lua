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

local ADDON_NAME = ...

local CLASS_CONSUMABLE, CLASS_WEAPON, CLASS_ARMOR, CLASS_QUEST = 0, 2, 4, 12
local BIND_ON_EQUIP, BIND_QUEST = 2, 4
local WEAPON_WAND = 19
local MAIN_HAND, OFF_HAND = 16, 17
local OFF_HAND_DPS_SCALE = 0.5
local MIN_GAIN, CLOSE_CALL_PERCENT = 0.5, 3
local QUALITY_POOR, QUALITY_UNCOMMON = 0, 2
local OUTGROWN_LEVELS = 15
local SPELL_DUAL_WIELD, SPELL_DISENCHANT = 674, 13262
local SKILL_ENCHANTING = 333

-- Key names from ZwykValues' Forever stat reader; unsuffixed forms are added below.
local STAT_KEYS = {
    ITEM_MOD_STRENGTH_SHORT = "str", ITEM_MOD_AGILITY_SHORT = "agi", ITEM_MOD_STAMINA_SHORT = "sta",
    ITEM_MOD_INTELLECT_SHORT = "int", ITEM_MOD_SPIRIT_SHORT = "spi",
    RESISTANCE0_NAME = "armor", ITEM_MOD_ARMOR_SHORT = "armor",
    ITEM_MOD_EXTRA_ARMOR_SHORT = "armor", ITEM_MOD_BONUS_ARMOR_SHORT = "armor",
    ITEM_MOD_ATTACK_POWER_SHORT = "ap", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "rap",
    ITEM_MOD_FERAL_ATTACK_POWER_SHORT = "feralap",
    ITEM_MOD_SPELL_POWER_SHORT = "sp", ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "dmg", ITEM_MOD_SPELL_HEALING_DONE_SHORT = "heal",
    ITEM_MOD_MANA_REGENERATION_SHORT = "mp5", ITEM_MOD_MANA_REGEN_SHORT = "mp5", ITEM_MOD_POWER_REGEN0_SHORT = "mp5",
    ITEM_MOD_HEALTH_REGENERATION_SHORT = "hp5", ITEM_MOD_HEALTH_REGEN_SHORT = "hp5",
    ITEM_MOD_HIT_RATING_SHORT = "hit", ITEM_MOD_HIT_MELEE_RATING_SHORT = "hit",
    ITEM_MOD_HIT_RANGED_RATING_SHORT = "hit", ITEM_MOD_HIT_SPELL_RATING_SHORT = "hit",
    ITEM_MOD_CRIT_RATING_SHORT = "crit", ITEM_MOD_CRIT_MELEE_RATING_SHORT = "crit",
    ITEM_MOD_CRIT_RANGED_RATING_SHORT = "crit", ITEM_MOD_MELEE_CRIT_RATING_SHORT = "crit",
    ITEM_MOD_RANGED_CRIT_RATING_SHORT = "crit", ITEM_MOD_CRIT_SPELL_RATING_SHORT = "crit",
    ITEM_MOD_SPELL_CRIT_RATING_SHORT = "crit",
    ITEM_MOD_HASTE_RATING_SHORT = "haste", ITEM_MOD_HASTE_MELEE_RATING_SHORT = "haste",
    ITEM_MOD_HASTE_RANGED_RATING_SHORT = "haste", ITEM_MOD_HASTE_SPELL_RATING_SHORT = "haste",
    ITEM_MOD_EXPERTISE_RATING_SHORT = "exp", ITEM_MOD_DODGE_RATING_SHORT = "dodge",
    ITEM_MOD_PARRY_RATING_SHORT = "parry", ITEM_MOD_BLOCK_RATING_SHORT = "block",
    ITEM_MOD_BLOCK_VALUE_SHORT = "blockvalue", ITEM_MOD_BLOCK_VALUE_BONUS_SHORT = "blockvalue",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "defense",
    ITEM_MOD_DEFENSE_RATING_SHORT = "defense",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "dps", DPS = "dps",
    ITEM_MOD_ARCANE_DAMAGE_SHORT = "school", ITEM_MOD_FIRE_DAMAGE_SHORT = "school", ITEM_MOD_NATURE_DAMAGE_SHORT = "school",
    ITEM_MOD_FROST_DAMAGE_SHORT = "school", ITEM_MOD_SHADOW_DAMAGE_SHORT = "school", ITEM_MOD_HOLY_DAMAGE_SHORT = "school",
    ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT = "school", ITEM_MOD_FIRE_DAMAGE_DONE_SHORT = "school",
    ITEM_MOD_NATURE_DAMAGE_DONE_SHORT = "school", ITEM_MOD_FROST_DAMAGE_DONE_SHORT = "school",
    ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT = "school", ITEM_MOD_HOLY_DAMAGE_DONE_SHORT = "school",
}
do
    local aliases = {}
    for key, stat in pairs(STAT_KEYS) do
        aliases[(key:gsub("_SHORT$", ""))] = stat
    end
    for key, stat in pairs(aliases) do
        STAT_KEYS[key] = stat
    end
end

local IGNORED_KEYS = {
    RESISTANCE1_NAME = true, RESISTANCE2_NAME = true, RESISTANCE3_NAME = true,
    RESISTANCE4_NAME = true, RESISTANCE5_NAME = true, RESISTANCE6_NAME = true,
    ITEM_MOD_SPELL_PENETRATION_SHORT = true, ITEM_MOD_HEALTH_SHORT = true, ITEM_MOD_MANA_SHORT = true,
    ITEM_MOD_INDESTRUCTIBLE_SHORT = true,
    ITEM_MOD_ARCANE_RESISTANCE_SHORT = true, ITEM_MOD_FIRE_RESISTANCE_SHORT = true, ITEM_MOD_NATURE_RESISTANCE_SHORT = true,
    ITEM_MOD_FROST_RESISTANCE_SHORT = true, ITEM_MOD_SHADOW_RESISTANCE_SHORT = true,
    ITEM_MOD_HERBALISM_SHORT = true, ITEM_MOD_MINING_SHORT = true, ITEM_MOD_SKINNING_SHORT = true,
    ITEM_MOD_FISHING_SHORT = true, ITEM_MOD_ALCHEMY_SHORT = true, ITEM_MOD_BLACKSMITHING_SHORT = true,
    ITEM_MOD_ENCHANTING_SHORT = true, ITEM_MOD_ENGINEERING_SHORT = true, ITEM_MOD_LEATHERWORKING_SHORT = true,
    ITEM_MOD_TAILORING_SHORT = true, ITEM_MOD_COOKING_SHORT = true, ITEM_MOD_FIRST_AID_SHORT = true,
}
do
    local aliases = {}
    for key in pairs(IGNORED_KEYS) do
        aliases[(key:gsub("_SHORT$", ""))] = true
    end
    for key in pairs(aliases) do
        IGNORED_KEYS[key] = true
    end
end

-- The weights below are per rating point, as in the sim. Rating per 1% at level 60, from wowsims/forever.
local RATING_PER_PERCENT = { crit = 14, hit = 10, haste = 10, exp = 10, dodge = 12, parry = 15, block = 5 }
local PERCENT_LABELS = {
    hit = "hit", crit = "crit", ["critical strike"] = "crit", ["critical hit"] = "crit", ["critically hit"] = "crit",
    haste = "haste", expertise = "exp", dodge = "dodge", parry = "parry", block = "block",
}
-- Words a stat line can add around its label. Anything else, such as "gain" in a proc, makes it not a stat line.
local PERCENT_FILLER = {
    your = true, the = true, a = true, an = true, chance = true, to = true, get = true, inflict = true, with = true, of = true,
    all = true, ["and"] = true, melee = true, ranged = true, physical = true, spell = true, spells = true,
    attack = true, attacks = true, shield = true,
}
local MAX_LEVEL, MIN_PERCENT_LEVEL = 60, 10

-- Leveling estimates. Physical profiles use attack power = 1 and casters use spell damage = 1.
-- Warrior and hunter ratios start from wowsims/forever level-60 EP, then lean toward survival per leveling guides.
--
-- 2026-11-09 pass against the Forever guides (research\builds_forever.md "ItemAdvisor weights vs sources" and the
-- stat sections of research\builds\<CLASS>.md: Icy Veins, Method, Warcraft Tavern). A weight moved only where
-- the sources agree on the order; where they disagree the old value stays and the comment says so.
-- Per 1% the weights compare as weight x RATING_PER_PERCENT (hit/exp 10, crit 14 rating per 1%).
local PROFILES = {
    -- Fury/Arms: IV and Method both put Hit first (WARRIOR.md): hit 2 -> 5.5 (55 per 1%, above exp 50 and crit 42).
    -- Expertise kept at 5: IV ranks it right after Hit, Method doesn't list it.
    warrior = { str = 2.2, ap = 1, sta = 1.6, agi = 1.2, spi = 0.8, armor = 0.05, crit = 3, hit = 5.5, haste = 2.6, exp = 5, melee = 19 },
    -- Unchanged: Expertise above Hit matches IV; Method has them equal (ROGUE.md).
    rogue = { agi = 2.4, str = 1.1, ap = 1, sta = 1.2, armor = 0.05, crit = 3, hit = 3.5, haste = 2.5, exp = 5, melee = 15 },
    -- Careful Aim turns Intellect into attack power: int 1 -> 2 (HUNTER.md, builds_forever.md). Method says
    -- Agility = Intellect, IV doesn't rank Intellect, so it stays below Agility. IV's Hit-before-Crit has no
    -- second source: hit kept.
    hunter = { agi = 4.5, rap = 1, ap = 0.75, sta = 1.5, int = 2, str = 0.3, armor = 0.05, crit = 3.9, hit = 1.3, haste = 2.5, exp = 1, ranged = 9 },
    survival = { agi = 4.5, rap = 1, ap = 1, sta = 1.5, int = 1, str = 0.8, armor = 0.05, crit = 3.9, hit = 1.3, haste = 2.5, exp = 2.8, melee = 7, ranged = 5 },
    -- Cat (DRUID.md): Forever feral scales with weapon damage and IV/Method rank Weapon DPS first: melee 0 -> 14.
    -- Hit > Expertise > Crit in IV and WT: hit 2 -> 4.5, exp 2 -> 4 (45/40 per 1%, crit 35). Str vs Agi
    -- disagree (Method Str, IV Agi): kept.
    feral = { str = 2, feralap = 1, ap = 1, agi = 1.5, sta = 1.5, int = 0.3, spi = 0.2, armor = 0.1, crit = 2.5, hit = 4.5, exp = 4, melee = 14 },
    -- IV and Method both put Hit at the top and Crit below Str/Int (SHAMAN.md): hit 3 -> 4.5, crit 3 -> 2.
    -- Int vs Str disagree (IV Int, Method Str): kept.
    enhancement = { str = 2.2, ap = 1, int = 1, agi = 0.8, sta = 1, dmg = 0.3, armor = 0.05, crit = 2, hit = 4.5, exp = 3, melee = 19 },
    -- IV and Method: Hit > Expertise > Str ~ Spell Power, Crit last (PALADIN.md): hit 3 -> 4.5, exp 2.5 -> 3.5,
    -- dmg 0.5 -> 2 (just under Str: IV has Str first, Method SP first), crit 3 -> 2.
    retribution = { str = 2.2, ap = 1, int = 0.8, agi = 0.8, sta = 1, dmg = 2, armor = 0.05, crit = 2, hit = 4.5, exp = 3.5, melee = 19 },
    -- Shared by warrior, paladin and druid tanks; per-class changes are in CLASS_PROFILE_OVERRIDES below.
    -- Warrior tanks: IV and Method both rank Agility above Strength and Defense low; not changed (shared profile).
    tank = { sta = 2, armor = 0.15, str = 1.5, agi = 1.2, ap = 0.7, defense = 1.5, dodge = 2, parry = 2, block = 1.5, blockvalue = 0.5, hit = 1.5, exp = 2, crit = 1, melee = 8 },
    -- Casters: Hit (to 17%) first, then Spell Damage, then Crit (MAGE.md, WARLOCK.md: IV and Method; WT puts
    -- Crit before Hit but its sims value them about equal). hit 1 -> 1.2 (mage), 0.9 -> 1.2 (warlock).
    -- Spell Penetration ranks above Int for Method/IV but is still ignored (IGNORED_KEYS).
    mage = { dmg = 1, school = 0.6, int = 0.6, sta = 0.4, spi = 0.25, armor = 0.01, crit = 0.8, hit = 1.2, haste = 0.7, mp5 = 0.6, wand = 3 },
    warlock = { dmg = 1, school = 0.6, hit = 1.2, int = 0.4, sta = 0.5, spi = 0.15, armor = 0.01, crit = 0.5, haste = 0.2, mp5 = 0.4, wand = 3 },
    -- Shadow (PRIEST.md, IV and Method): Hit > Spell Damage > Crit > ... > Spirit. spi 1.1 -> 0.3, hit 0.5 -> 1.2,
    -- crit 0.4 -> 0.6. Leveling guides (Mobalytics) still rank Spirit second for Spirit Tap; not modeled.
    shadow = { spi = 0.3, dmg = 1, school = 0.6, int = 0.5, sta = 0.4, armor = 0.01, hit = 1.2, crit = 0.6, haste = 0.3, mp5 = 0.5, wand = 3 },
    -- Elemental shaman / Balance druid: IV puts Spell Power before Hit, Method Hit first (SHAMAN.md); no
    -- Balance list was found. Kept.
    caster = { dmg = 1, school = 0.6, int = 0.6, spi = 0.3, sta = 0.4, armor = 0.02, crit = 0.7, hit = 0.8, haste = 0.6, mp5 = 0.4, wand = 2 },
    -- Priest healer (PRIEST.md: IV Healing > MP5 > Spirit > Int > Crit; builds_forever.md WT Healing > Int > MP5 >
    -- Spirit > Crit): Healing first, MP5 high, Crit last already hold. Kept; other classes override below.
    healer = { heal = 1, int = 0.7, spi = 0.7, mp5 = 1, sta = 0.3, armor = 0.02, crit = 0.5, haste = 0.6, wand = 1 },
}

-- A role's weights for one class, where that class's guides differ from the shared role. Keys are profile, then
-- class; anything not listed uses PROFILES.
local CLASS_PROFILE_OVERRIDES = {
    healer = {
        -- Holy paladin (PALADIN.md): IV and Method both rank Healing > Int > ... with MP5 4th: int 0.7 -> 0.9.
        -- Crit vs Spirit disagree (Method Crit 3rd, IV Spirit 3rd): both kept.
        PALADIN = { heal = 1, int = 0.9, spi = 0.7, mp5 = 1, sta = 0.3, armor = 0.02, crit = 0.5, haste = 0.6, wand = 1 },
        -- Resto shaman (SHAMAN.md): IV Healing > Crit > Int > Spirit > MP5, WT Healing > Spirit > Int > Crit; both
        -- leave MP5 last or out: mp5 1 -> 0.6. Crit's place disagrees: kept at 0.5.
        SHAMAN = { heal = 1, int = 0.7, spi = 0.7, mp5 = 0.6, sta = 0.3, armor = 0.02, crit = 0.5, haste = 0.6, wand = 1 },
        -- Resto druid (DRUID.md): IV Healing > Int > Spirit > MP5 > Crit, WT Healing > Spirit > Haste > Crit > Int.
        -- They disagree on Int vs Spirit, so the shared healer weights are kept (no override).
    },
    tank = {
        -- Protection paladin (PALADIN.md): IV and Method both put Spell Power in the top five: dmg 0 -> 1.
        PALADIN = { sta = 2, armor = 0.15, str = 1.5, agi = 1.2, ap = 0.7, defense = 1.5, dodge = 2, parry = 2, block = 1.5, blockvalue = 0.5, hit = 1.5, exp = 2, crit = 1, melee = 8, dmg = 1 },
        -- Bear (DRUID.md): IV, WT and Method all rank Armor among the top three (bear form multiplies it):
        -- armor 0.15 -> 0.3; feral attack power counts like attack power (feralap 0.7). Defense vs Dodge vs
        -- Stamina order disagrees: kept.
        DRUID = { sta = 2, armor = 0.3, str = 1.5, agi = 1.2, ap = 0.7, feralap = 0.7, defense = 1.5, dodge = 2, parry = 2, block = 1.5, blockvalue = 0.5, hit = 1.5, exp = 2, crit = 1, melee = 8 },
    },
}

local function ProfileWeights(profile, class)
    local byClass = CLASS_PROFILE_OVERRIDES[profile]
    return byClass and class and byClass[class] or PROFILES[profile]
end
local SPELL_PROFILES = { mage = true, warlock = true, shadow = true, caster = true, healer = true }
local CAN_LEARN_DUAL_WIELD = { WARRIOR = true, ROGUE = true, HUNTER = true, SHAMAN = true }

local CLASS_PROFILES = {
    WARRIOR = { "warrior", "tank" }, PALADIN = { "retribution", "healer", "tank" }, HUNTER = { "hunter", "survival" },
    ROGUE = { "rogue" }, PRIEST = { "shadow", "healer" }, SHAMAN = { "enhancement", "caster", "healer" },
    MAGE = { "mage" }, WARLOCK = { "warlock" }, DRUID = { "feral", "caster", "healer", "tank" },
}

-- Talent tab names (lower case, as the talent window shows them) and the role each one suggests.
-- A tab not listed here, or a class with one role, leaves the role as it is.
local TAB_PROFILES = {
    WARRIOR = { arms = "warrior", fury = "warrior", protection = "tank" },
    PALADIN = { holy = "healer", protection = "tank", retribution = "retribution" },
    HUNTER = { ["beast mastery"] = "hunter", marksmanship = "hunter", survival = "survival" },
    PRIEST = { discipline = "healer", holy = "healer", shadow = "shadow" },
    SHAMAN = { elemental = "caster", enhancement = "enhancement", restoration = "healer" },
    DRUID = { balance = "caster", ["feral combat"] = "feral", feral = "feral", restoration = "healer" },
}
-- The talent window's tabs left to right, for a trait tree that doesn't name its parts.
local TAB_ORDER = {
    WARRIOR = { "Arms", "Fury", "Protection" },
    PALADIN = { "Holy", "Protection", "Retribution" },
    HUNTER = { "Beast Mastery", "Marksmanship", "Survival" },
    PRIEST = { "Discipline", "Holy", "Shadow" },
    SHAMAN = { "Elemental", "Enhancement", "Restoration" },
    DRUID = { "Balance", "Feral Combat", "Restoration" },
}
-- Fewer points than this says little about where a character is heading.
local MIN_TALENT_POINTS = 5

-- Leveling bias: below the level cap, staying alive matters more than raw damage, so these stats
-- count this many times their usual weight. Switched on or off from the Bag advice page.
local LEVELING_BONUS = { sta = 1.5, armor = 1.5 }

-- From game files of build 1.60.1.70790 via Everloot's extraction: subclass ID = level it unlocks.
local ARMOR_TYPES = {
    WARRIOR = { [1] = 1, [2] = 1, [3] = 1, [4] = 40, [6] = 1 },
    PALADIN = { [1] = 1, [2] = 1, [3] = 1, [4] = 40, [6] = 1 },
    HUNTER = { [1] = 1, [2] = 1, [3] = 40 },
    ROGUE = { [1] = 1, [2] = 1 },
    PRIEST = { [1] = 1 },
    SHAMAN = { [1] = 1, [2] = 1, [3] = 40, [6] = 1 },
    MAGE = { [1] = 1 },
    WARLOCK = { [1] = 1 },
    DRUID = { [1] = 1, [2] = 1 },
}
local WEAPON_TYPES = {
    WARRIOR = { [0] = 1, [1] = 1, [2] = 1, [3] = 1, [4] = 1, [5] = 1, [6] = 20, [7] = 1, [8] = 1, [10] = 1, [13] = 1, [15] = 1, [16] = 1, [18] = 1 },
    PALADIN = { [0] = 1, [1] = 1, [4] = 1, [5] = 1, [6] = 20, [7] = 1, [8] = 1 },
    HUNTER = { [0] = 1, [1] = 1, [2] = 1, [3] = 1, [6] = 20, [7] = 1, [8] = 1, [10] = 1, [13] = 1, [15] = 1, [16] = 1, [18] = 1 },
    ROGUE = { [0] = 1, [2] = 1, [3] = 1, [4] = 1, [7] = 1, [13] = 1, [15] = 1, [16] = 1, [18] = 1 },
    PRIEST = { [4] = 1, [10] = 1, [15] = 1, [19] = 1 },
    SHAMAN = { [0] = 1, [1] = 1, [4] = 1, [5] = 1, [10] = 1, [13] = 1, [15] = 1 },
    MAGE = { [7] = 1, [10] = 1, [15] = 1, [19] = 1 },
    WARLOCK = { [7] = 1, [10] = 1, [15] = 1, [19] = 1 },
    DRUID = { [4] = 1, [5] = 1, [6] = 20, [10] = 1, [13] = 1, [15] = 1 },
}
local RESTRICTED_ARMOR = { [1] = true, [2] = true, [3] = true, [4] = true, [6] = true }
local UNRESTRICTED_WEAPON = { [14] = true, [20] = true }

local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { MAIN_HAND }, INVTYPE_WEAPONMAINHAND = { MAIN_HAND }, INVTYPE_2HWEAPON = { MAIN_HAND },
    INVTYPE_SHIELD = { OFF_HAND }, INVTYPE_WEAPONOFFHAND = { OFF_HAND }, INVTYPE_HOLDABLE = { OFF_HAND },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
}
local RANGED_SLOTS = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }

local OTHER_ITEMS = {
    [1] = "Bag: equip it if it's bigger",
    [5] = "Reagent: keep if you use it",
    [7] = "Crafting material: keep if a profession needs it, otherwise auction",
    [9] = "Recipe: learn it, or auction or vendor it",
}

local COLORS = {
    EQUIP = { 0.2, 1, 0.2 }, KEEP = { 0.4, 0.8, 1 }, SELL = { 1, 0.6, 0.2 }, AUCTION = { 1, 0.85, 0.2 },
    DISENCHANT = { 0.8, 0.5, 1 }, CHECK = { 0.8, 0.8, 0.8 }, EQUIPPED = { 0.7, 0.7, 0.7 },
}

local charData, playerClass
local ScheduleRepaint -- Defined with the bag marks below; the role command needs it too.
local questItems = {}
local percentCache, percentCount = {}, 0

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("ItemAdvisor", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function FormatMoney(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    return string.format("%dg %ds %dc", gold, silver, copper % 100)
end

-- IsPlayerSpell only exists on Forever while Blizzard's deprecation fallbacks are switched on.
local function KnowsSpell(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return Safe(C_SpellBook.IsSpellKnown(spellID)) and true or false
    end
    return IsPlayerSpell and Safe(IsPlayerSpell(spellID)) and true or false
end

-- One guide says Disenchant isn't in Forever's spellbook, so the Enchanting skill counts too.
local function CanDisenchant()
    if KnowsSpell(SPELL_DISENCHANT) then
        return true
    end
    if not (GetProfessions and GetProfessionInfo) then
        return false
    end
    local first, second = GetProfessions()
    for _, index in ipairs({ first or false, second or false }) do
        if index and Safe(select(7, GetProfessionInfo(index))) == SKILL_ENCHANTING then
            return true
        end
    end
    return false
end

local function CanDualWieldNow()
    if CanDualWield then
        return Safe(CanDualWield()) and true or false
    end
    return KnowsSpell(SPELL_DUAL_WIELD)
end

-- Items this addon asked the game to load. Other addons and the auction house load items too, and
-- a repaint for each of those would be wasted work.
local pendingItems = {}
-- The game usually answers a load request with GET_ITEM_INFO_RECEIVED; if it stays quiet, look again
-- a few times on a timer. The count only resets when an item does arrive, so this can't loop forever.
local ITEM_RETRY_DELAY, ITEM_RETRY_LIMIT = 2, 3
local itemRetries, itemRetryScheduled = 0, false

local function RetryPendingItems()
    itemRetryScheduled = false
    if next(pendingItems) and charData and ScheduleRepaint then
        ScheduleRepaint()
    end
end

local function RequestItem(link)
    local id = tonumber(link:match("item:(%d+)"))
    if id then
        pendingItems[id] = true
        C_Item.RequestLoadItemDataByID(id)
        if not itemRetryScheduled and itemRetries < ITEM_RETRY_LIMIT and C_Timer and C_Timer.After then
            itemRetryScheduled, itemRetries = true, itemRetries + 1
            C_Timer.After(ITEM_RETRY_DELAY, RetryPendingItems)
        end
    end
end

-- Worn gear, read safely: in combat the game may hide these.
local function WornLink(slot)
    return Safe(GetInventoryItemLink("player", slot))
end

-- Objectives give no item ID, only text with the count on either side ("Wolf Meat: 2/8" or "2/8 Wolf Meat").
-- Stripping the count lets "Wolf Meat" match exactly instead of also matching "Tender Wolf Meat".
local function ObjectiveItemName(text)
    local name = text:match("^%d+%s*/%s*%d+%s+(.-)%s*$") or text:match("^(.-)%s*:%s*%d+%s*/%s*%d+")
    return name and name ~= "" and name or nil
end

local function RebuildQuestItems()
    questItems = {}
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then
        return
    end
    local entries = C_QuestLog.GetNumQuestLogEntries()
    for index = 1, Safe(entries) or 0 do
        local info = C_QuestLog.GetInfo(index)
        local questID = info and not Safe(info.isHeader) and Safe(info.questID)
        if questID then
            for _, objective in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
                local text = Safe(objective.text)
                if Safe(objective.type) == "item" and type(text) == "string" then
                    questItems[#questItems + 1] = { text = text, item = ObjectiveItemName(text), title = Safe(info.title) or "a quest" }
                end
            end
        end
    end
end

local function QuestNeeding(name)
    for _, entry in ipairs(questItems) do
        -- Text without a count is matched loosely, since there's nothing to strip.
        if entry.item == name or (not entry.item and entry.text:find(name, 1, true)) then
            return entry.title
        end
    end
end

-- Returns stat, percent, scope for a complete stat line such as "+1% Critical Strike Chance"
-- or "Equip: Improves your chance to hit by 1%." Anchoring skips procs, on-use effects and set bonuses.
local function ParsePercentLine(text)
    text = text:lower():gsub("^equip:%s*", ""):gsub("%.$", "")
    local label, amount = text:match("^increases%s+(.+)%s+by%s+([%d%.]+)%%$")
    if not label then label, amount = text:match("^improves%s+(.+)%s+by%s+([%d%.]+)%%$") end
    if not label then amount, label = text:match("^%+?([%d%.]+)%%%s+(.+)$") end
    if not label then label, amount = text:match("^(.-)%s*%+([%d%.]+)%%$") end
    amount = tonumber(amount)
    if not label or not amount then
        return nil
    end
    local words = {}
    for word in label:gmatch("%S+") do
        if not PERCENT_FILLER[word] then
            words[#words + 1] = word
        end
    end
    local stat = PERCENT_LABELS[table.concat(words, " ")]
    if not stat then
        return nil
    end
    local spell = label:find("spell", 1, true)
    local attack = label:find("melee", 1, true) or label:find("ranged", 1, true) or label:find("attack", 1, true)
    -- Vanilla's unqualified wording ("your chance to hit") is physical; spells always say so.
    if spell and attack then
        return stat, amount, "any"
    end
    return stat, amount, spell and "spell" or "attack"
end

-- Hit, crit and haste keys can be spell-only or physical-only; the plain rating keys count for everyone.
local SCOPED_STATS = { hit = true, crit = true, haste = true }
local function KeyScope(key, stat)
    if not SCOPED_STATS[stat] then
        return "any"
    end
    if key:find("SPELL", 1, true) then
        return "spell"
    end
    if key:find("MELEE", 1, true) or key:find("RANGED", 1, true) then
        return "attack"
    end
    return "any"
end

-- Percent stats shown on the item's tooltip, or nil if the tooltip can't be read yet.
local function ReadPercents(link)
    if percentCache[link] then
        return percentCache[link]
    end
    local data = C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(link)
    local lines = data and data.lines
    if not lines or #lines < 2 then
        return nil
    end
    local percents = {}
    for _, line in ipairs(lines) do
        local text = Safe(line.leftText)
        if type(text) == "string" then
            local stat, amount, scope = ParsePercentLine(text)
            if stat then
                percents[#percents + 1] = { stat = stat, amount = amount, scope = scope }
            end
        end
    end
    percentCount = (percentCount or 0) + 1
    if percentCount > 2000 then
        -- Every item ever hovered would otherwise stay here for the whole session.
        percentCache, percentCount = {}, 1
    end
    percentCache[link] = percents
    return percents
end

local function ReadStats(link)
    local stats = C_Item.GetItemStats(link)
    local percents = ReadPercents(link)
    -- A cold read can come back empty, so empty means "not loaded" until the item's name has loaded.
    -- After that, empty really means no stats (an on-use trinket, a PvP insignia), which scores 0.
    if (not stats or next(stats) == nil) and not (percents and #percents > 0) then
        if not C_Item.GetItemInfo(link) then
            RequestItem(link)
            return nil
        end
        -- The third value says the item has no stats at all.
        return {}, false, true
    end
    local read, unknown = {}, false
    local isSpell = charData and SPELL_PROFILES[charData.profile] and true or false
    local level = Safe(UnitLevel("player")) or MAX_LEVEL
    local levelScale = math.min(math.max(level, MIN_PERCENT_LEVEL), MAX_LEVEL) / MAX_LEVEL
    local fromGame = {}
    for key, amount in pairs(stats or {}) do
        key, amount = Safe(key), Safe(amount)
        local stat = key and STAT_KEYS[key]
        if stat and amount then
            -- Forever reports these as ratings (4 hit shows as 0.4%), which is what the weights use.
            -- A percent is worth about 1% more damage, and damage grows with level.
            local value = RATING_PER_PERCENT[stat] and amount * levelScale or amount
            local scope = KeyScope(key, stat)
            if scope == "any" or (scope == "spell") == isSpell then
                -- The client can report one stat under several aliases; count it once.
                read[stat] = math.max(read[stat] or 0, value)
                -- Only a stat counted here is known; a spell-crit key says nothing about melee crit.
                fromGame[stat] = true
            end
        elseif not (key and IGNORED_KEYS[key]) then
            unknown = true
        end
    end
    -- The tooltip only fills in stats the game's list left out.
    for _, percent in ipairs(percents or {}) do
        local applies = percent.scope == "any" or (percent.scope == "spell") == isSpell
        if applies and not fromGame[percent.stat] then
            local points = percent.amount * RATING_PER_PERCENT[percent.stat] * levelScale
            read[percent.stat] = (read[percent.stat] or 0) + points
        end
    end
    return read, unknown
end

local function DpsWeight(weights, equipLoc, subClassID)
    if subClassID == WEAPON_WAND then
        return weights.wand or 0
    end
    if RANGED_SLOTS[equipLoc] then
        return weights.ranged or 0
    end
    return weights.melee or 0
end

-- Whether the leveling bias applies now: on unless switched off, and only below the level cap.
local function LevelingBiasActive()
    local level = Safe(UnitLevel("player"))
    return charData.levelingBias ~= false and type(level) == "number" and level < MAX_LEVEL
end

-- The role's stat weights, with Stamina and Armor raised while the leveling bias applies.
local biasedWeights = {}
local function Weights()
    local base = ProfileWeights(charData.profile, playerClass)
    if not LevelingBiasActive() then
        return base
    end
    local cacheKey = charData.profile .. "/" .. tostring(playerClass)
    local weights = biasedWeights[cacheKey]
    if not weights then
        weights = {}
        for stat, weight in pairs(base) do
            weights[stat] = weight * (LEVELING_BONUS[stat] or 1)
        end
        biasedWeights[cacheKey] = weights
    end
    return weights
end

local function Score(link, dpsScale)
    local name, _, _, _, _, _, _, _, equipLoc, _, _, _, subClassID = C_Item.GetItemInfo(link)
    if not name then
        RequestItem(link)
        return nil
    end
    local read, unknown = ReadStats(link)
    if not read then
        return nil
    end
    local weights = Weights()
    local total = 0
    for stat, amount in pairs(read) do
        if stat == "dps" then
            total = total + DpsWeight(weights, equipLoc, subClassID) * amount * (dpsScale or 1)
        elseif stat ~= "dmg" and stat ~= "heal" and stat ~= "sp" then
            total = total + (weights[stat] or 0) * amount
        end
    end
    -- Spell power is both damage and healing, so it can't add to either alias.
    -- Forever's bonus healing also grants a third of its value as spell damage.
    local damage = math.max(read.sp or 0, read.dmg or (read.heal and read.heal / 3) or 0)
    local healing = math.max(read.sp or 0, read.heal or 0)
    return total + (weights.dmg or 0) * damage + (weights.heal or 0) * healing, unknown
end

local function InEquipmentSet(link)
    if not C_EquipmentSet then
        return false
    end
    local id = tonumber(link:match("item:(%d+)"))
    for _, setID in ipairs(C_EquipmentSet.GetEquipmentSetIDs() or {}) do
        for _, itemID in pairs(C_EquipmentSet.GetItemIDs(setID) or {}) do
            if itemID == id then
                return true
            end
        end
    end
    return false
end

-- Level this class can use the item at, or nil if it never can.
local function UseLevel(classID, subClassID, equipLoc)
    if classID == CLASS_ARMOR then
        if equipLoc == "INVTYPE_CLOAK" or not RESTRICTED_ARMOR[subClassID] then
            return 1
        end
        return ARMOR_TYPES[playerClass][subClassID]
    end
    if UNRESTRICTED_WEAPON[subClassID] then
        return 1
    end
    return WEAPON_TYPES[playerClass][subClassID]
end

-- Red tooltip text is the game's own "you can't use this", which also catches untrained weapon skills.
local function HasRedLine(link)
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then
        return false
    end
    local data = C_TooltipInfo.GetHyperlink(link)
    -- "Classes: Paladin" in red is a different story from an untrained weapon skill.
    local classPrefix = (ITEM_CLASSES_ALLOWED or "Classes: %s"):gsub("%%s.*$", "")
    for _, line in ipairs(data and data.lines or {}) do
        for _, color in ipairs({ line.leftColor or false, line.rightColor or false }) do
            local r, g, b = color and Safe(color.r), color and Safe(color.g), color and Safe(color.b)
            if r and g and b and r > 0.9 and g < 0.3 and b < 0.3 then
                local text = Safe(line.leftText)
                if type(text) == "string" and classPrefix ~= "" and text:find(classPrefix, 1, true) == 1 then
                    return true, "class"
                end
                return true
            end
        end
    end
    return false
end

-- "Unique" or "Unique-Equipped" on the tooltip: you can't wear two.
local function IsUnique(link)
    local data = C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(link)
    local markers = { ITEM_UNIQUE or "Unique", ITEM_UNIQUE_EQUIPPABLE or "Unique-Equipped" }
    for _, line in ipairs(data and data.lines or {}) do
        local text = Safe(line.leftText)
        if type(text) == "string" then
            for _, marker in ipairs(markers) do
                if text:sub(1, #marker) == marker then
                    return true
                end
            end
        end
    end
    return false
end

local function IsWorn(link)
    local id = link:match("item:(%d+)")
    if not id then
        return false
    end
    for slot = 1, 19 do
        local worn = WornLink(slot)
        if worn and worn:match("item:(%d+)") == id then
            return true
        end
    end
    return false
end

local function MainHandIsTwoHanded()
    local mainHand = WornLink(MAIN_HAND)
    return mainHand and select(9, C_Item.GetItemInfo(mainHand)) == "INVTYPE_2HWEAPON" or false
end

local function SlotScore(slot, scale)
    local link = WornLink(slot)
    if not link then
        return 0, false, true
    end
    local score, unknown = Score(link, scale)
    return score, unknown, false
end

local function SlotTargets(equipLoc, classID, slots)
    local targets = {}
    for _, slot in ipairs(slots) do
        local isOffWeapon = slot == OFF_HAND and classID == CLASS_WEAPON
        targets[#targets + 1] = { slot = slot, scale = isOffWeapon and OFF_HAND_DPS_SCALE or 1 }
    end
    if equipLoc == "INVTYPE_WEAPON" and CanDualWieldNow() then
        targets[#targets + 1] = { slot = OFF_HAND, scale = OFF_HAND_DPS_SCALE }
    end
    return targets
end

local STAT_ORDER = {
    { "dps", "DPS" }, { "armor", "Armor" }, { "str", "Strength" }, { "agi", "Agility" }, { "sta", "Stamina" }, { "int", "Intellect" },
    { "spi", "Spirit" }, { "ap", "Attack Power" }, { "rap", "Ranged AP" }, { "feralap", "Feral AP" }, { "sp", "Spell Power" },
    { "dmg", "Spell Damage" }, { "school", "School Damage" }, { "heal", "Healing" }, { "mp5", "MP5" }, { "hit", "Hit" }, { "crit", "Crit" },
    { "haste", "Haste" }, { "exp", "Expertise" }, { "defense", "Defense" }, { "dodge", "Dodge" }, { "parry", "Parry" }, { "block", "Block" },
    { "blockvalue", "Block Value" },
}

local function FormatChange(amount, label)
    local shown = amount == math.floor(amount) and string.format("%.0f", math.abs(amount)) or string.format("%.1f", math.abs(amount))
    return (amount > 0 and "+" or "-") .. shown .. " " .. label
end

-- What changes for your role if you swap: stats you gain and lose, or nil if either item can't be read.
-- Stats your role doesn't use are left out, but armor and weapon damage always count.
local function StatChanges(link, wornLink)
    local new, newUnknown = ReadStats(link)
    local worn, wornUnknown = ReadStats(wornLink)
    if not new or not worn or newUnknown or wornUnknown then
        return nil
    end
    local weights = Weights()
    local gains, losses = {}, {}
    for _, entry in ipairs(STAT_ORDER) do
        local stat, label = entry[1], entry[2]
        local difference = (new[stat] or 0) - (worn[stat] or 0)
        if difference ~= 0 and ((weights[stat] or 0) > 0 or stat == "armor" or stat == "dps") then
            local list = difference > 0 and gains or losses
            list[#list + 1] = FormatChange(difference, label)
        end
    end
    return gains, losses
end

-- Best gain across the slots this item could fill; nil if any equipped data hasn't loaded.
local function BestGain(link, equipLoc, classID, slots)
    local best
    local comparedTo
    for _, target in ipairs(SlotTargets(equipLoc, classID, slots)) do
        local wornLink = WornLink(target.slot)
        local mainHand = WornLink(MAIN_HAND)
        local mainIsTwoHanded = mainHand and select(9, C_Item.GetItemInfo(mainHand)) == "INVTYPE_2HWEAPON"
        -- A two-hander replacing two items, or an off-hand beside a two-hander, can't be compared one to one.
        local replacesOneItem = wornLink and not (target.slot == OFF_HAND and mainIsTwoHanded)
            and not (equipLoc == "INVTYPE_2HWEAPON" and WornLink(OFF_HAND))
        local score = Score(link, target.scale)
        if not score then
            return nil
        end
        local base, unknown, isEmpty = SlotScore(target.slot, target.scale)
        if not base then
            return nil
        end
        if equipLoc == "INVTYPE_2HWEAPON" then
            local offBase, offUnknown, offEmpty = SlotScore(OFF_HAND, OFF_HAND_DPS_SCALE)
            if not offBase then
                return nil
            end
            base, unknown, isEmpty = base + offBase, unknown or offUnknown, isEmpty and offEmpty
        elseif target.slot == OFF_HAND and isEmpty then
            -- A two-hander occupies the off hand, so an "empty" slot is not a free upgrade.
            local mainHand = WornLink(MAIN_HAND)
            if mainHand and select(9, C_Item.GetItemInfo(mainHand)) == "INVTYPE_2HWEAPON" then
                base, unknown = SlotScore(MAIN_HAND, 1)
                if not base then
                    return nil
                end
                isEmpty = false
            end
        end
        local gain = score - base
        if not best or gain > best.gain then
            best = { gain = gain, base = base, unknown = unknown, isEmpty = isEmpty }
            comparedTo = replacesOneItem and wornLink or nil
        end
    end
    if best and comparedTo then
        best.gains, best.losses = StatChanges(link, comparedTo)
    end
    return best
end

local function NotNeeded(reason, classID, quality, sellPrice, bindType, isBound)
    local isGear = classID == CLASS_WEAPON or classID == CLASS_ARMOR
    local canDisenchant = isGear and quality >= QUALITY_UNCOMMON and CanDisenchant()
    local vendor = sellPrice > 0 and ("vendor for " .. FormatMoney(sellPrice)) or "no vendor value"
    if bindType == BIND_ON_EQUIP and quality >= QUALITY_UNCOMMON and not isBound then
        return "AUCTION", reason .. ". Auction if unbound, " .. (canDisenchant and "disenchant, or " or "or ") .. vendor
    end
    if canDisenchant then
        return "DISENCHANT", reason .. ". Disenchant, or " .. vendor
    end
    if sellPrice > 0 then
        return "SELL", reason .. ", " .. vendor
    end
    return "KEEP", reason .. ", " .. vendor
end

-- Weapon pairs. While you wear a two-hander, a one-hander or off-hand alone is only half of a
-- replacement, so it is judged together with the best partner for the other hand in your bags.
local MAIN_HAND_LOCS = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true }
local OFF_HAND_LOCS = { INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }
-- Bag items that could go in each hand; read once and forgotten whenever verdicts are (see ForgetVerdicts).
local bagHands

-- True when you could wear this now: your class can use its type, you have the level, and the game
-- shows no red "can't use" line. Returns the item's slot type and class as well.
local function WearableNow(link)
    local name, _, _, _, minLevel, _, _, _, equipLoc, _, _, classID, subClassID = C_Item.GetItemInfo(link)
    if not name then
        RequestItem(link)
        return false
    end
    if not (classID == CLASS_WEAPON or classID == CLASS_ARMOR) then
        return false
    end
    local useLevel = UseLevel(classID, subClassID, equipLoc)
    local level = Safe(UnitLevel("player"))
    if not useLevel or not level or math.max(minLevel or 1, useLevel) > level or HasRedLine(link) then
        return false
    end
    return true, equipLoc, classID
end

local function BagHands()
    if bagHands then
        return bagHands
    end
    bagHands = { main = {}, off = {} }
    local dual = CanDualWieldNow()
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        for slot = 1, Safe(C_Container.GetContainerNumSlots(bag)) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local link = info and Safe(info.hyperlink)
            local wearable, equipLoc, classID = false, nil, nil
            if link then
                wearable, equipLoc, classID = WearableNow(link)
            end
            if wearable then
                if MAIN_HAND_LOCS[equipLoc] then
                    bagHands.main[#bagHands.main + 1] = link
                end
                -- Off-hand weapons and one-handers in the off hand both need Dual Wield.
                local offWeapon = equipLoc == "INVTYPE_WEAPONOFFHAND" or equipLoc == "INVTYPE_WEAPON"
                if (OFF_HAND_LOCS[equipLoc] and not offWeapon) or (offWeapon and dual) then
                    bagHands.off[#bagHands.off + 1] = { link = link, isWeapon = classID == CLASS_WEAPON }
                end
            end
        end
    end
    return bagHands
end

-- Score of a main-hand and off-hand pair, and whether either has stats that can't be scored.
local function PairScore(main, off, offIsWeapon)
    local mainScore, mainUnknown = Score(main, 1)
    local offScore, offUnknown = Score(off, offIsWeapon and OFF_HAND_DPS_SCALE or 1)
    if not (mainScore and offScore) then
        return nil
    end
    return mainScore + offScore, mainUnknown or offUnknown
end

-- The best pair this item can make with another item from your bags: partner link, pair score,
-- unknown flag. nil when no bag item fits the other hand. A bag item skips its own copy once.
local function BestPartner(link, equipLoc, classID, inBags)
    local hands = BagHands()
    local best
    local function consider(main, off, offIsWeapon, partner)
        local score, unknown = PairScore(main, off, offIsWeapon)
        if score and (not best or score > best.score) then
            best = { partner = partner, score = score, unknown = unknown }
        end
    end
    local function skipSelf(candidate, skipped)
        if inBags and not skipped and candidate == link then
            return true
        end
        return false
    end
    if MAIN_HAND_LOCS[equipLoc] then
        local skipped = false
        for _, off in ipairs(hands.off) do
            if skipSelf(off.link, skipped) then
                skipped = true
            else
                consider(link, off.link, off.isWeapon, off.link)
            end
        end
    end
    -- An off-hand item, or a one-hander you'd carry in the off hand.
    local canGoOff = OFF_HAND_LOCS[equipLoc] or (equipLoc == "INVTYPE_WEAPON" and CanDualWieldNow())
    if canGoOff then
        local skipped = false
        for _, main in ipairs(hands.main) do
            if skipSelf(main, skipped) then
                skipped = true
            else
                consider(main, link, classID == CLASS_WEAPON, main)
            end
        end
    end
    if best then
        return best.partner, best.score, best.unknown
    end
end

-- Verdict for half of a pair against a worn two-hander, or nil to fall back to "compare it yourself".
local function JudgePair(link, equipLoc, classID, inBags)
    local partner, pairScore, pairUnknown = BestPartner(link, equipLoc, classID, inBags)
    if not partner then
        return nil
    end
    local wornScore, wornUnknown = SlotScore(MAIN_HAND, 1)
    if not wornScore or pairUnknown or wornUnknown or not WearableNow(link) then
        return nil
    end
    local gain = pairScore - wornScore
    local margin = math.max(MIN_GAIN, wornScore * CLOSE_CALL_PERCENT / 100)
    if gain >= margin then
        return "EQUIP", string.format("Upgrade for %s together with %s from your bags: the pair beats your two-hander (+%d, %d%%)",
            charData.profile, partner, math.floor(gain), math.floor(gain * 100 / math.max(wornScore, 1)))
    end
    -- Never a sell: the pair might still suit you, and that's your call.
    return "CHECK", "You wear a two-hander; even paired with " .. partner .. " from your bags, it scores lower"
end

local function EvaluateGear(link, equipLoc, classID, subClassID, minLevel, quality, sellPrice, bindType, isBound, inBags)
    local slots = SLOTS[equipLoc]
    -- A copy in your bags has the same link as the one you're wearing, but it's a spare.
    if not inBags then
        for _, target in ipairs(SlotTargets(equipLoc, classID, slots)) do
            if WornLink(target.slot) == link then
                return "EQUIPPED", "You're wearing this"
            end
        end
    end
    if InEquipmentSet(link) then
        return "KEEP", "In one of your equipment sets"
    end
    -- Equipping a second unique copy is impossible, and swapping it for the worn one changes nothing.
    if IsWorn(link) and IsUnique(link) then
        return NotNeeded("Spare copy; it's unique and you already wear one", classID, quality, sellPrice, bindType, isBound)
    end

    local useLevel = UseLevel(classID, subClassID, equipLoc)
    if not useLevel then
        return NotNeeded(string.format("A %s can't wear this", (Safe((UnitClass("player"))) or "character"):lower()), classID, quality, sellPrice, bindType, isBound)
    end
    if equipLoc == "INVTYPE_WEAPONOFFHAND" and not CanDualWieldNow() then
        if CAN_LEARN_DUAL_WIELD[playerClass] then
            return "CHECK", "You can't dual wield yet; keep it only if you'll learn soon"
        end
        return NotNeeded("Your class can't dual wield", classID, quality, sellPrice, bindType, isBound)
    end

    local _, unknown = Score(link)
    local best = BestGain(link, equipLoc, classID, slots)
    if not best then
        return "CHECK", "Can't read the stats (still loading); compare it yourself"
    end
    -- A one-hander or off-hand beside a worn two-hander is only half of a replacement.
    local halfOfPair = equipLoc ~= "INVTYPE_2HWEAPON" and (slots[1] == MAIN_HAND or slots[1] == OFF_HAND)
        and MainHandIsTwoHanded()
    local noStats = select(3, ReadStats(link))

    local gain = best.gain
    local margin = math.max(MIN_GAIN, best.base * CLOSE_CALL_PERCENT / 100)
    local gains, losses = best.gains or {}, best.losses or {}
    -- Better in something you care about and worse in nothing, so weights can't get this wrong.
    local strictlyBetter = #gains > 0 and #losses == 0
    local changes = table.concat(gains, ", ")
    if #losses > 0 then
        changes = (changes ~= "" and changes .. ", " or "") .. table.concat(losses, ", ")
    end
    if gain >= margin or (best.isEmpty and gain >= 0) or strictlyBetter then
        if best.unknown then
            return "CHECK", "Looks better, but your current item has stats I can't score"
        end
        local needLevel = math.max(minLevel or 1, useLevel)
        local level = Safe(UnitLevel("player"))
        if level and needLevel > level then
            return "KEEP", string.format("Upgrade at level %d (+%d)", needLevel, math.floor(gain))
        end
        local red, why = HasRedLine(link)
        if red and why == "class" then
            return NotNeeded("For another class", classID, quality, sellPrice, bindType, isBound)
        elseif red then
            return "CHECK", "Looks better, but the game says you can't use it yet; you may need to train it"
        end
        local amount
        if best.isEmpty then
            amount = "fills an empty slot"
        elseif gain < margin then
            amount = "better or equal in every stat"
        else
            amount = string.format("+%d, %d%%", math.floor(gain), math.floor(gain * 100 / math.max(best.base, 1)))
        end
        local action = charData.profile
        local suffix = changes ~= "" and (": " .. changes) or ""
        return "EQUIP", string.format("Upgrade for %s (%s)%s", action, amount, suffix)
    end
    if halfOfPair then
        local pairVerdict, pairReason = JudgePair(link, equipLoc, classID, inBags)
        if pairVerdict then
            return pairVerdict, pairReason
        end
        return "CHECK", "You wear a two-hander; this is only half of a replacement, so compare the pair yourself"
    end
    if unknown then
        return "CHECK", "Has stats I can't score; compare it yourself"
    end
    -- An item with no stats at all is usually worth it for its effect (on-use trinket, insignia).
    if noStats then
        return "CHECK", "No stats to score; judge its effect yourself"
    end
    -- A trade-off is your call, so never say sell if it beats the worn item in anything you use.
    if #gains > 0 then
        return "CHECK", "Close call: " .. changes
    end
    if gain > 0 then
        return "CHECK", "Close call; pick whichever you prefer"
    end
    local reason = changes ~= "" and ("Not an upgrade (" .. changes .. ")") or "Not an upgrade"
    return NotNeeded(reason, classID, quality, sellPrice, bindType, isBound)
end

-- Verdicts are remembered until something that could change them happens (bags, gear, level, quests,
-- role, or an item finishing loading): the hub asks every second and the tooltip asks while you hover.
local verdictCache, verdictCount = {}, 0
local VERDICT_CACHE_LIMIT = 2000
-- The last finished bag scan, and a counter that tells a scan running over several frames that
-- something changed under it (see ScanBagsSpread).
local lastScan, scanStale, scanGeneration = nil, true, 0

local function ForgetVerdicts()
    verdictCache, verdictCount = {}, 0
    bagHands = nil
    scanStale, scanGeneration = true, scanGeneration + 1
end

local function EvaluateNow(link, isBound, inBags)
    local name, _, quality, _, minLevel, _, _, _, equipLoc, _, sellPrice, classID, subClassID, bindType = C_Item.GetItemInfo(link)
    if not name then
        RequestItem(link)
        return "CHECK", "Item data is still loading; hover again"
    end
    sellPrice = sellPrice or 0
    if classID == CLASS_QUEST or bindType == BIND_QUEST then
        return "KEEP", "Quest item"
    end
    local questTitle = QuestNeeding(name)
    if questTitle then
        return "KEEP", "Needed for " .. questTitle
    end
    -- Gray gear goes through the gear rules, since it can beat an empty slot at low level.
    if (classID == CLASS_WEAPON or classID == CLASS_ARMOR) and SLOTS[equipLoc] then
        return EvaluateGear(link, equipLoc, classID, subClassID, minLevel, quality, sellPrice, bindType, isBound, inBags)
    end
    if quality == QUALITY_POOR then
        if sellPrice > 0 then
            return "SELL", "Junk, vendor for " .. FormatMoney(sellPrice)
        end
        return "KEEP", "Junk with no vendor value"
    end
    if classID == CLASS_CONSUMABLE then
        local level = Safe(UnitLevel("player"))
        if level and minLevel and minLevel > 1 and level - minLevel >= OUTGROWN_LEVELS then
            return "CHECK", "Outgrown consumable; use it up or sell it"
        end
        return "KEEP", "Consumable: use it or keep it"
    end
    if OTHER_ITEMS[classID] then
        return "KEEP", OTHER_ITEMS[classID]
    end
    return "CHECK", "No rule for this item; your call"
end

local function Evaluate(link, isBound, inBags)
    local key = link .. (isBound and "|b" or "|") .. (inBags and "i" or "")
    local cached = verdictCache[key]
    if cached then
        return cached[1], cached[2]
    end
    local verdict, reason = EvaluateNow(link, isBound, inBags)
    -- An answer that depends on data still loading isn't worth keeping.
    if not (reason:find("loading", 1, true) or reason:find("Can't read", 1, true)) then
        if verdictCount >= VERDICT_CACHE_LIMIT then
            ForgetVerdicts()
        end
        verdictCache[key] = { verdict, reason }
        verdictCount = verdictCount + 1
    end
    return verdict, reason
end

-- A bag scan in progress or finished: verdict lists, total vendor value, and the upgrades.
local function NewScan()
    return { results = { EQUIP = {}, DISENCHANT = {}, AUCTION = {}, KEEP = {}, CHECK = {}, SELL = {} }, sellTotal = 0, upgrades = {} }
end

-- Every bag slot as { bag, slot }, so a scan can be split into pieces.
local function BagSlots()
    local slots = {}
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        for slot = 1, Safe(C_Container.GetContainerNumSlots(bag)) or 0 do
            slots[#slots + 1] = { bag, slot }
        end
    end
    return slots
end

local function ScanSlot(scan, bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    local link = info and Safe(info.hyperlink)
    if not link then
        return
    end
    local verdict, reason = Evaluate(link, Safe(info.isBound), true)
    local bucket = scan.results[verdict]
    if bucket then
        bucket[#bucket + 1] = link .. ": " .. reason
        if verdict == "EQUIP" then
            scan.upgrades[#scan.upgrades + 1] = link
        end
        if verdict == "SELL" then
            local price = select(11, C_Item.GetItemInfo(link)) or 0
            scan.sellTotal = scan.sellTotal + price * (Safe(info.stackCount) or 1)
        end
    end
end

-- The whole scan at once; used when you open the page and are waiting for the answer anyway.
local function ScanBags()
    local scan = NewScan()
    for _, entry in ipairs(BagSlots()) do
        ScanSlot(scan, entry[1], entry[2])
    end
    lastScan, scanStale = scan, false
    return scan.results, scan.sellTotal, scan.upgrades
end

-- Role: picked from your talents unless you chose one on the page ----------------------------------

local function ClassHasProfile(name)
    for _, profile in ipairs(CLASS_PROFILES[playerClass]) do
        if profile == name then
            return true
        end
    end
    return false
end

-- Points per talent tab as { name, points }, or nil when the game gives no way to tell.
-- Forever keeps talents as a trait tree (C_ClassTalents / C_Traits, documented in the client's API
-- docs): each purchased node counts its ranks toward the tab it belongs to. Fields used, all in
-- SharedTraitsDocumentation: TraitConfigInfo.treeIDs, TraitNodeInfo.ranksPurchased/subTreeID/posX,
-- TraitSubTreeInfo.name, TraitTreeInfo.titleText.
local function TraitTabs()
    if not (C_ClassTalents and C_Traits and C_Traits.GetConfigInfo and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo) then
        return nil
    end
    local function call(fn, ...)
        if type(fn) ~= "function" then
            return nil
        end
        local ok, result = pcall(fn, ...)
        return ok and Safe(result) or nil
    end
    local configID = call(C_ClassTalents.GetActiveConfigID)
    local config = configID and call(C_Traits.GetConfigInfo, configID)
    local treeIDs = type(config) == "table" and Safe(config.treeIDs)
    if type(treeIDs) ~= "table" then
        return nil
    end
    -- The three tabs can be sub-trees of one tree (subTreeID on each node), separate tree IDs, or one
    -- tree with the tabs side by side. Each purchased node is grouped by whichever of these applies.
    local tabOrder = TAB_ORDER[playerClass] or {}
    local points, order, names = {}, {}, {}
    local loose = {}   -- purchased nodes with no sub-tree in a single tree: { x, ranks }
    local function add(key, name, ranks)
        if not points[key] then
            order[#order + 1] = key
            names[key] = name
        end
        points[key] = (points[key] or 0) + ranks
    end
    for treeIndex, rawTree in ipairs(treeIDs) do
        local treeID = Safe(rawTree)
        local treeName
        if #treeIDs > 1 then
            local treeInfo = treeID and call(C_Traits.GetTreeInfo, configID, treeID)
            local title = type(treeInfo) == "table" and Safe(treeInfo.titleText)
            if type(title) == "string" and TAB_PROFILES[playerClass] and TAB_PROFILES[playerClass][title:lower()] then
                treeName = title
            elseif #treeIDs == #tabOrder then
                treeName = tabOrder[treeIndex]
            end
        end
        local nodes = treeID and call(C_Traits.GetTreeNodes, treeID)
        for _, nodeID in ipairs(type(nodes) == "table" and nodes or {}) do
            local node = call(C_Traits.GetNodeInfo, configID, Safe(nodeID))
            local ranks = type(node) == "table" and Safe(node.ranksPurchased)
            local subTree = type(node) == "table" and Safe(node.subTreeID)
            if type(ranks) == "number" and ranks > 0 then
                if subTree then
                    add("sub" .. tostring(subTree), nil, ranks)
                    names["sub" .. tostring(subTree)] = subTree
                elseif treeName then
                    add("tree" .. treeIndex, treeName, ranks)
                elseif #treeIDs == 1 then
                    loose[#loose + 1] = { x = Safe(node.posX), ranks = ranks }
                end
            end
        end
    end
    -- One tree holding all three tabs: split it into three columns, left to right, in tab order.
    -- Unpurchased nodes still count for the column edges, so the width is read from every node.
    if #loose > 0 and #tabOrder > 0 then
        local minX, maxX = math.huge, -math.huge
        local nodes = call(C_Traits.GetTreeNodes, Safe(treeIDs[1]))
        for _, nodeID in ipairs(type(nodes) == "table" and nodes or {}) do
            local node = call(C_Traits.GetNodeInfo, configID, Safe(nodeID))
            local x = type(node) == "table" and Safe(node.posX)
            if type(x) == "number" then
                minX, maxX = math.min(minX, x), math.max(maxX, x)
            end
        end
        if maxX > minX then
            for _, node in ipairs(loose) do
                if type(node.x) == "number" then
                    local column = math.min(#tabOrder, math.floor((node.x - minX) / (maxX - minX) * #tabOrder) + 1)
                    add("col" .. column, tabOrder[column], node.ranks)
                end
            end
        end
    end
    local tabs = {}
    for _, key in ipairs(order) do
        local name = names[key]
        if type(name) == "number" then
            local info = call(C_Traits.GetSubTreeInfo, configID, name)
            name = type(info) == "table" and Safe(info.name)
        end
        if type(name) == "string" and name ~= "" then
            tabs[#tabs + 1] = { name = name, points = points[key] }
        end
    end
    return #tabs > 0 and tabs or nil
end

-- The older talent API, where a client still has it. Not in this client's API docs, so it is only a
-- fallback and two return layouts are accepted: (name, icon, points) and (id, name, description, icon, points).
local function LegacyTabs()
    if type(GetTalentTabInfo) ~= "function" then
        return nil
    end
    local count = 3
    if type(GetNumTalentTabs) == "function" then
        local ok, value = pcall(GetNumTalentTabs)
        count = ok and type(Safe(value)) == "number" and Safe(value) or count
    end
    local tabs = {}
    for index = 1, math.min(count, 5) do
        local ok, r1, r2, r3, _, r5 = pcall(GetTalentTabInfo, index)
        r1, r2, r3, r5 = Safe(r1), Safe(r2), Safe(r3), Safe(r5)
        local name, points
        if ok and type(r1) == "string" then
            name, points = r1, r3
        elseif ok and type(r2) == "string" then
            name, points = r2, r5
        end
        if name and type(points) == "number" then
            tabs[#tabs + 1] = { name = name, points = points }
        end
    end
    return #tabs > 0 and tabs or nil
end

-- The role your talents point to: profile, tab name, points. nil if unreadable, too few points,
-- a tie, or a tab this addon doesn't know.
local function TalentProfile()
    local known = TAB_PROFILES[playerClass]
    if not known then
        return nil
    end
    local tabs = TraitTabs() or LegacyTabs()
    local best, tied
    for _, tab in ipairs(tabs or {}) do
        if not best or tab.points > best.points then
            best, tied = tab, false
        elseif tab.points == best.points then
            tied = true
        end
    end
    if not best or tied or best.points < MIN_TALENT_POINTS then
        return nil
    end
    local profile = known[best.name:lower()]
    if profile and ClassHasProfile(profile) then
        return profile, best.name, best.points
    end
end

-- Follows your talents unless you picked a role yourself. Returns true if the role changed.
local function UpdateAutoRole()
    if not charData or charData.roleChosen then
        return false
    end
    local profile, tab, points = TalentProfile()
    charData.roleFrom = profile and string.format("%d points in %s", points, tab) or nil
    if profile and profile ~= charData.profile then
        charData.profile = profile
        ScheduleRepaint()
        return true
    end
    return false
end

local function ShowSettings()
    local roleText
    if charData.roleChosen then
        roleText = "you chose it. Type role auto to follow your talents again."
    elseif charData.roleFrom then
        roleText = "picked from your talents (" .. charData.roleFrom .. ")."
    elseif TAB_PROFILES[playerClass] then
        roleText = "the class default; your talents don't point anywhere clear yet."
    else
        roleText = "your class has one role."
    end
    Print(string.format("|cffffd100Role:|r %s, %s", charData.profile, roleText))
    if #CLASS_PROFILES[playerClass] > 1 then
        Print("  To choose another, type: role " .. table.concat(CLASS_PROFILES[playerClass], ", role "))
    end
    local state = charData.levelingBias == false and "off" or "on"
    Print(string.format("|cffffd100Leveling bias:|r %s. Below level %d, Stamina and Armor count 50%% more, because staying alive matters most while leveling.%s",
        state, MAX_LEVEL, LevelingBiasActive() and "" or " (Not in use right now.)"))
    Print("  Type: leveling " .. (state == "on" and "off" or "on"))
end

local function ShowScan()
    ShowSettings()
    local results, sellTotal
    if lastScan and not scanStale then
        results, sellTotal = lastScan.results, lastScan.sellTotal
    else
        results, sellTotal = ScanBags()
    end
    for _, verdict in ipairs({ "EQUIP", "SELL", "AUCTION", "DISENCHANT", "CHECK" }) do
        for _, line in ipairs(results[verdict]) do
            local color = COLORS[verdict]
            Print(string.format("|cff%02x%02x%02x%s|r %s", math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255), verdict, line))
        end
    end
    Print(string.format("%d to equip, %d to sell (%s), %d to auction, %d to disenchant, %d to check, %d to keep.",
        #results.EQUIP, #results.SELL, FormatMoney(sellTotal), #results.AUCTION, #results.DISENCHANT, #results.CHECK, #results.KEEP))
end

local function ShowRawStats(link)
    if not link or link == "" then
        Print("Use /ia stats and then shift-click an item.")
        return
    end
    local stats = C_Item.GetItemStats(link)
    local percents = ReadPercents(link) or {}
    if (not stats or next(stats) == nil) and #percents == 0 then
        RequestItem(link)
        Print("No stats yet; try again in a moment.")
        return
    end
    for key, amount in pairs(stats or {}) do
        key, amount = Safe(key), Safe(amount)
        if key and amount then
            local known = STAT_KEYS[key] and "" or (IGNORED_KEYS[key] and " (ignored)" or " (unknown)")
            Print(key .. " = " .. tostring(amount) .. known)
        else
            Print("A stat is hidden by the game (secret value).")
        end
    end
    for _, percent in ipairs(percents) do
        Print("Tooltip: " .. percent.amount .. "% " .. percent.stat .. " (" .. percent.scope .. ")")
    end
end

local function HandleSlash(message)
    -- The hub can ask before this addon's own login step has run.
    if not charData then
        return
    end
    local command, rest = message:match("^(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" then
        -- Talents may have changed since the last event; a cheap re-check before the page is drawn.
        UpdateAutoRole()
        ShowScan()
    elseif command == "role" and ClassHasProfile(rest:lower()) then
        charData.profile = rest:lower()
        -- Your choice wins over the talent guess until you type role auto.
        charData.roleChosen = true
        -- Weights changed, so the bag arrows and coins may be stale.
        ScheduleRepaint()
        Print("Role set to " .. charData.profile .. ".")
    elseif command == "role" and rest:lower() == "auto" then
        charData.roleChosen = false
        if not UpdateAutoRole() then
            ScheduleRepaint()
        end
        if charData.roleFrom then
            Print("Role follows your talents: " .. charData.profile .. " (" .. charData.roleFrom .. ").")
        else
            Print("Role follows your talents once they point somewhere clear; for now it stays " .. charData.profile .. ".")
        end
    elseif command == "leveling" or command == "levelling" then
        local want = rest:lower()
        if want == "on" or want == "off" then
            charData.levelingBias = want == "on"
            ScheduleRepaint()
        end
        Print(string.format("Leveling bias is %s: below level %d, Stamina and Armor count 50%% more. Type leveling on or leveling off.",
            charData.levelingBias == false and "off" or "on", MAX_LEVEL))
    elseif command == "role" then
        Print("Your role is " .. charData.profile .. ". Choose: " .. table.concat(CLASS_PROFILES[playerClass], ", ") .. ".")
    elseif command == "stats" then
        ShowRawStats(rest)
    else
        Print("/ia - check every item in your bags")
        Print("/ia role <name> - set what stats to favor (role auto follows your talents)")
        Print("/ia leveling on|off - extra weight on Stamina and Armor below level 60")
        Print("/ia stats <shift-click item> - show the raw stats the game reports")
        Print("Hover any item to see its recommendation.")
    end
end

-- The bag slot a tooltip shows, from Blizzard's own record of how it filled the tooltip (read only):
-- SetBagItem fills it with getterName "GetBagItem" and getterArgs { bag, slot }.
local function TooltipBagItem(tooltip, link)
    local getInfo = tooltip.GetProcessingTooltipInfo or tooltip.GetPrimaryTooltipInfo
    local info = type(getInfo) == "function" and getInfo(tooltip)
    if type(info) ~= "table" or Safe(info.getterName) ~= "GetBagItem" or type(info.getterArgs) ~= "table" then
        return nil
    end
    local bag, slot = Safe(info.getterArgs[1]), Safe(info.getterArgs[2])
    if type(bag) ~= "number" or type(slot) ~= "number" then
        return nil
    end
    local item = C_Container.GetContainerItemInfo(bag, slot)
    if item and Safe(item.hyperlink) == link then
        return item
    end
end

local function OnTooltip(tooltip)
    if not charData or (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) then
        return
    end
    local _, link = TooltipUtil.GetDisplayedItem(tooltip)
    link = Safe(link)
    if not link then
        return
    end
    -- A bag copy gets the same verdict as its bag badge, even when you wear an identical one.
    local bagItem = TooltipBagItem(tooltip, link)
    local verdict, reason
    if bagItem then
        verdict, reason = Evaluate(link, Safe(bagItem.isBound), true)
    else
        verdict, reason = Evaluate(link)
    end
    local color = COLORS[verdict]
    tooltip:AddLine(verdict .. ": " .. reason, color[1], color[2], color[3], true)
end

local function ShortMoney(copper)
    local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if gold > 0 then
        return string.format("%dg %ds", gold, silver)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, rest)
    end
    return string.format("%dc", rest)
end

-- Marks beside Blizzard's windows. Everything drawn lives on this addon's own overlay frame and is only
-- anchored to Blizzard's buttons: nothing is created on them, hooked, or written into their tables,
-- since any of that can break the secure UI on Forever.
local UPGRADE_ATLAS, COIN_TEXTURE = "bags-greenarrow", "Interface\\MoneyFrame\\UI-GoldIcon"
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local COIN_SIZE, REPAINT_DELAY, REWARD_RETRY_DELAY = 14, 0.1, 0.5
local WATCH_INTERVAL = 0.25
local bagBadges = setmetatable({}, { __mode = "k" })
local rewardMarks = setmetatable({}, { __mode = "k" })
local REWARD_WAIT_LIMIT, LOOT_TYPE_CURRENCY = 2, 1
local rewardWindowOpen, rewardToastPending, rewardWaitOver = false, false, false
local repaintScheduled, repaintAfterCombat = false, false

local overlay = CreateFrame("Frame", "ItemAdvisorOverlay", UIParent)
overlay:SetFrameStrata("HIGH")
overlay:SetFrameLevel(100)
overlay:SetAllPoints(UIParent)

local function Report(step, ...)
    local ok, err = pcall(step, ...)
    if not ok then
        geterrorhandler()(err)
    end
end

local function NewUpgradeArrow()
    local arrow = overlay:CreateTexture(nil, "OVERLAY")
    arrow:SetAtlas(UPGRADE_ATLAS, true)
    arrow:Hide()
    return arrow
end

local function NewCoin()
    local coin = overlay:CreateTexture(nil, "OVERLAY")
    coin:SetTexture(COIN_TEXTURE)
    coin:SetSize(COIN_SIZE, COIN_SIZE)
    coin:Hide()
    return coin
end

local function BadgesFor(button)
    local badges = bagBadges[button]
    if not badges then
        badges = { arrow = NewUpgradeArrow(), coin = NewCoin(), button = button }
        badges.arrow:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        badges.coin:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
        bagBadges[button] = badges
    end
    return badges
end

local function BagFrames()
    local list = {}
    local container = ContainerFrameContainer and ContainerFrameContainer.ContainerFrames
    for _, bagFrame in ipairs(type(container) == "table" and container or {}) do
        list[#list + 1] = bagFrame
    end
    if ContainerFrameCombinedBags then
        list[#list + 1] = ContainerFrameCombinedBags
    end
    return list
end

local function PaintBagButton(button)
    local verdict
    if button:IsVisible() then
        -- Read directly: Blizzard's own item lists fill caches that addon code must not be first to touch.
        local bagID = button.bagID or button:GetParent():GetID()
        local info = C_Container.GetContainerItemInfo(bagID, button:GetID())
        local link = info and Safe(info.hyperlink)
        if link then
            verdict = Evaluate(link, Safe(info.isBound), true)
        end
    end
    if verdict == "EQUIP" or verdict == "SELL" or bagBadges[button] then
        local badges = BadgesFor(button)
        badges.arrow:SetShown(verdict == "EQUIP")
        badges.coin:SetShown(verdict == "SELL")
    end
end

-- Only our own textures; hiding them is allowed in combat.
local function HideBagBadges()
    for _, badges in pairs(bagBadges) do
        badges.arrow:Hide()
        badges.coin:Hide()
    end
end

-- Buttons painted per frame: a first look at full bags evaluates every item, so it's spread out.
local PAINT_BUTTONS_PER_FRAME = 20
local paintGeneration = 0

local function PaintBags()
    if not charData then
        return
    end
    paintGeneration = paintGeneration + 1
    local generation = paintGeneration
    local buttons = {}
    for _, bagFrame in ipairs(BagFrames()) do
        if bagFrame:IsShown() and type(bagFrame.Items) == "table" then
            for _, button in ipairs(bagFrame.Items) do
                buttons[#buttons + 1] = button
            end
        end
    end
    local index = 1
    local function step()
        -- A newer repaint took over.
        if generation ~= paintGeneration then
            return
        end
        -- Bags can change in combat without a repaint, so a stale badge would point at the wrong slot.
        if InCombatLockdown and InCombatLockdown() then
            HideBagBadges()
            repaintAfterCombat = true
            return
        end
        local last = math.min(index + PAINT_BUTTONS_PER_FRAME - 1, #buttons)
        for i = index, last do
            PaintBagButton(buttons[i])
        end
        index = last + 1
        if index <= #buttons then
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function() Report(step) end)
            else
                step()
            end
        end
    end
    step()
end

local function RewardButton(index)
    local rewards = QuestInfoRewardsFrame
    for _, button in ipairs(rewards and type(rewards.RewardButtons) == "table" and rewards.RewardButtons or {}) do
        if button.type == "choice" and button:GetID() == index and button:IsShown() then
            return button
        end
    end
end

local function RewardMark(button)
    local mark = rewardMarks[button]
    if mark then
        return mark
    end
    local icon = button.Icon or button
    mark = CreateFrame("Frame", nil, overlay)
    mark:SetAllPoints(icon)
    mark.button = button
    mark.glow = mark:CreateTexture(nil, "OVERLAY")
    mark.glow:SetTexture(GLOW_TEXTURE)
    mark.glow:SetBlendMode("ADD")
    mark.glow:SetVertexColor(0.2, 1, 0.2)
    mark.glow:SetPoint("CENTER", icon, "CENTER", 0, 0)
    mark.glow:SetSize(70, 70)
    mark.label = mark:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    mark.label:SetPoint("TOP", icon, "TOP", 0, -2)
    mark.label:SetTextColor(0.2, 1, 0.2)
    mark.label:SetText("BEST")
    mark.coin = NewCoin()
    mark.coin:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 1, 1)
    rewardMarks[button] = mark
    return mark
end

local function HideRewardMarks()
    for _, mark in pairs(rewardMarks) do
        mark:Hide()
    end
end

-- Reads each reward you can choose. Returns the choices, and true if some item hasn't loaded yet.
local function ReadRewardChoices()
    local choices, pending = {}, false
    for index = 1, Safe(GetNumQuestChoices()) or 0 do
        local link = Safe(GetQuestItemLink("choice", index))
        local name, equipLoc, price, classID, _
        if link then
            name, _, _, _, _, _, _, _, equipLoc, _, price, classID = C_Item.GetItemInfo(link)
        end
        local isCurrency = GetQuestItemInfoLootType and Safe(GetQuestItemInfoLootType("choice", index)) == LOOT_TYPE_CURRENCY
        if isCurrency then
            -- Not an item, so there's nothing to compare or wait for.
        elseif not name then
            pending = true
            if link then
                RequestItem(link)
            end
        else
            local count = Safe(select(3, GetQuestItemInfo("choice", index))) or 1
            local verdict, reason = Evaluate(link)
            local choice = { index = index, link = link, verdict = verdict, reason = reason, value = (price or 0) * math.max(count, 1) }
            if verdict == "EQUIP" then
                local best = BestGain(link, equipLoc, classID, SLOTS[equipLoc])
                choice.gain = best and best.gain or 0
            elseif verdict == "CHECK" then
                pending = pending or reason:find("Can't read", 1, true) ~= nil
            end
            choices[#choices + 1] = choice
        end
    end
    return choices, pending
end

local function RefreshRewardMarks()
    HideRewardMarks()
    if not (rewardWindowOpen and charData) then
        return
    end
    local choices, pending = ReadRewardChoices()
    if #choices < 2 then
        return
    end
    local best, richest, tied
    for _, choice in ipairs(choices) do
        if choice.gain and (not best or choice.gain > best.gain) then
            best = choice
        end
        if choice.value > 0 and (not richest or choice.value > richest.value) then
            richest, tied = choice, false
        elseif richest and choice.value == richest.value then
            tied = true
        end
    end
    if tied then
        richest = nil
    end
    for _, choice in ipairs(choices) do
        local isBest, isRichest = choice == best, choice == richest
        local button = (isBest or isRichest) and RewardButton(choice.index)
        if button then
            local mark = RewardMark(button)
            mark.glow:SetShown(isBest)
            mark.label:SetShown(isBest)
            mark.coin:SetShown(isRichest)
            mark:Show()
        end
    end
    if rewardToastPending and (rewardWaitOver or not pending) then
        rewardToastPending = false
        if best then
            Print("Quest reward: take " .. best.link .. ". " .. best.reason)
        elseif richest then
            Print("Quest reward: no upgrades here. " .. richest.link .. " sells for the most (" .. ShortMoney(richest.value) .. ").")
        end
    end
end

local function RunRepaint()
    repaintScheduled = false
    Report(PaintBags)
    Report(RefreshRewardMarks)
end

function ScheduleRepaint()
    -- Whatever asked for a repaint may have changed the answers too.
    ForgetVerdicts()
    if not repaintScheduled then
        repaintScheduled = true
        C_Timer.After(REPAINT_DELAY, RunRepaint)
    end
end

-- Marks sit on this addon's overlay, so they don't vanish with the window they point at by themselves.
-- A few times a second: hide marks whose button is gone, and repaint when a bag window opens.
local bagShown = setmetatable({}, { __mode = "k" })
local sinceWatch = 0

local function WatchFrames(_, elapsed)
    sinceWatch = sinceWatch + elapsed
    if sinceWatch < WATCH_INTERVAL then
        return
    end
    sinceWatch = 0
    for button, badges in pairs(bagBadges) do
        if not button:IsVisible() then
            badges.arrow:Hide()
            badges.coin:Hide()
        end
    end
    for button, mark in pairs(rewardMarks) do
        if mark:IsShown() and not button:IsVisible() then
            mark:Hide()
        end
    end
    for _, bagFrame in ipairs(BagFrames()) do
        local shown = bagFrame:IsShown()
        if shown and not bagShown[bagFrame] then
            ScheduleRepaint()
        end
        bagShown[bagFrame] = shown
    end
end

local function WatchBagFrames()
    overlay:SetScript("OnUpdate", WatchFrames)
end

local function OpenRewardWindow(wantsToast)
    rewardWindowOpen, rewardToastPending = true, wantsToast
    -- Blizzard lays the reward buttons out after this event, and stats can load a moment after names.
    rewardWaitOver = false
    ScheduleRepaint()
    C_Timer.After(REWARD_RETRY_DELAY, ScheduleRepaint)
    -- An item whose stats never load shouldn't cost you the advice on the others.
    C_Timer.After(REWARD_WAIT_LIMIT, function()
        rewardWaitOver = true
        ScheduleRepaint()
    end)
end

-- Bag scan spread over frames, a few slots each, so full bags never cause a hitch. onDone (optional)
-- gets the finished scan. If verdicts are forgotten mid-way (bags or gear changed), it starts over.
local SCAN_SLOTS_PER_FRAME = 12
local scanRunning, scanWaiters = false, {}

local function ScanBagsSpread(onDone)
    if onDone then
        scanWaiters[#scanWaiters + 1] = onDone
    end
    if scanRunning then
        return
    end
    scanRunning = true
    local generation, index, scan = scanGeneration, 1, NewScan()
    local slots = {}
    local step
    -- Never leave the scan marked as running after an error, or it would never run again.
    local function guarded()
        local ok, err = pcall(step)
        if not ok then
            scanRunning = false
            geterrorhandler()(err)
        end
    end
    function step()
        if generation ~= scanGeneration then
            scanRunning = false
            return ScanBagsSpread()
        end
        local last = math.min(index + SCAN_SLOTS_PER_FRAME - 1, #slots)
        for i = index, last do
            ScanSlot(scan, slots[i][1], slots[i][2])
        end
        index = last + 1
        if index <= #slots then
            if C_Timer and C_Timer.After then
                C_Timer.After(0, guarded)
                return
            end
            return step()
        end
        scanRunning = false
        lastScan, scanStale = scan, false
        local waiters = scanWaiters
        scanWaiters = {}
        for _, waiter in ipairs(waiters) do
            Report(waiter, scan)
        end
    end
    local ok, err = pcall(function() slots = BagSlots() end)
    if not ok then
        scanRunning = false
        geterrorhandler()(err)
        return
    end
    guarded()
end

local function ShowVendorReminder()
    ScanBagsSpread(function(scan)
        if #scan.results.SELL > 0 then
            Print(string.format("Sell %d item(s) for %s. A coin marks each one in your bags.", #scan.results.SELL, ShortMoney(scan.sellTotal)))
        end
    end)
end

local events = CreateFrame("Frame")
for _, name in ipairs({ "PLAYER_LOGIN", "QUEST_LOG_UPDATE", "QUEST_DETAIL", "QUEST_COMPLETE", "QUEST_FINISHED", "MERCHANT_SHOW",
    "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_LEVEL_UP",
    -- Learning Dual Wield or Disenchant changes advice on off-hands and green gear.
    "LEARNED_SPELL_IN_SKILL_LINE" }) do
    events:RegisterEvent(name)
end
-- Talent changes can change the role. Registered one by one with pcall: a client without one of
-- these events must still load the addon.
local TALENT_EVENTS = { TRAIT_CONFIG_UPDATED = true, PLAYER_TALENT_UPDATE = true, CHARACTER_POINTS_CHANGED = true }
for name in pairs(TALENT_EVENTS) do
    pcall(events.RegisterEvent, events, name)
end
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "GET_ITEM_INFO_RECEIVED" then
        -- Only items this addon asked for; the game loads items for many other reasons.
        local id = Safe(arg1)
        if id and pendingItems[id] and charData then
            pendingItems[id] = nil
            itemRetries = 0
            ScheduleRepaint()
        end
        return
    end
    if TALENT_EVENTS[event] then
        if charData then
            Report(UpdateAutoRole)
        end
        return
    end
    if event == "QUEST_LOG_UPDATE" then
        RebuildQuestItems()
        -- Picking up or finishing a quest can change whether an item is safe to sell.
        if charData then
            ScheduleRepaint()
        end
        return
    end
    if event ~= "PLAYER_LOGIN" then
        if not charData then
            return
        end
        if event == "QUEST_DETAIL" or event == "QUEST_COMPLETE" then
            OpenRewardWindow(event == "QUEST_COMPLETE")
        elseif event == "QUEST_FINISHED" then
            rewardWindowOpen, rewardToastPending = false, false
            HideRewardMarks()
        elseif event == "MERCHANT_SHOW" then
            Report(ShowVendorReminder)
            ScheduleRepaint()
        elseif event == "PLAYER_REGEN_DISABLED" then
            HideBagBadges()
            repaintAfterCombat = true
        elseif event == "PLAYER_REGEN_ENABLED" then
            if repaintAfterCombat then
                repaintAfterCombat = false
                ScheduleRepaint()
            end
        else
            ScheduleRepaint()
        end
        return
    end
    ItemAdvisorDB = ItemAdvisorDB or {}
    ForgetVerdicts()
    playerClass = Safe(select(2, UnitClass("player"))) or "WARRIOR"
    -- A class these tables don't know would crash every lookup; warrior rules are the safest stand-in.
    if not (CLASS_PROFILES[playerClass] and ARMOR_TYPES[playerClass] and WEAPON_TYPES[playerClass]) then
        playerClass = "WARRIOR"
    end
    local key = ForeverCharacterAdopt(ItemAdvisorDB)
    local isNew = not ItemAdvisorDB[key]
    ItemAdvisorDB[key] = ItemAdvisorDB[key] or {}
    charData = ForeverCharacterStamp(ItemAdvisorDB[key])
    if not charData.profile or not ClassHasProfile(charData.profile) then
        charData.profile = CLASS_PROFILES[playerClass][1]
        charData.roleChosen = false
    elseif charData.roleChosen == nil then
        -- Saved before roles followed talents (nil, never false): a role other than the default was
        -- picked by hand, so keep it.
        charData.roleChosen = charData.profile ~= CLASS_PROFILES[playerClass][1]
    end
    Report(UpdateAutoRole)
    if isNew and #CLASS_PROFILES[playerClass] > 1 then
        Print("Using the " .. charData.profile .. " role. It follows your talents; choose another on the Bag advice page.")
    end
    RebuildQuestItems()
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltip)
    Report(WatchBagFrames)
end)

SLASH_ITEMADVISOR1 = "/ia"
SLASH_ITEMADVISOR2 = "/itemadvisor"
SlashCmdList.ITEMADVISOR = HandleSlash

-- Lets other helpers ask, such as the quest tracker asking about a quest's rewards.
function ItemAdvisor_IsUpgrade(link)
    link = Safe(link)
    -- Callers pass whatever the quest API gave them, which can be nil while a reward loads.
    if not charData or type(link) ~= "string" or not link:find("item:", 1, true) then
        return false
    end
    local verdict, reason = Evaluate(link)
    return verdict == "EQUIP", reason
end

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.ItemAdvisor = function()
    if not charData then
        return nil
    end
    -- The hub asks every second: answer from the last finished scan, and refresh it in the
    -- background (spread over frames) when something changed.
    if scanStale then
        ScanBagsSpread()
    end
    if not lastScan then
        return nil
    end
    local results, sellTotal, upgrades = lastScan.results, lastScan.sellTotal, lastScan.upgrades
    local items = {}
    for _, link in ipairs(upgrades) do
        items[#items + 1] = { text = "|cff33ff33Equip|r " .. link, page = "Bag advice", link = link }
    end
    if #results.SELL > 0 then
        items[#items + 1] = { text = string.format("|cffff9933Sell|r %d item(s) for %s", #results.SELL, ShortMoney(sellTotal)), page = "Bag advice" }
    end
    if #results.AUCTION > 0 then
        items[#items + 1] = { text = string.format("|cffffd933Auction|r %d item(s)", #results.AUCTION), page = "Bag advice" }
    end
    if #results.DISENCHANT > 0 then
        items[#items + 1] = { text = string.format("|cffcc80ffDisenchant|r %d item(s)", #results.DISENCHANT), page = "Bag advice" }
    end
    return items
end
