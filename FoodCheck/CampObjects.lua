-- Camp objects (research\re_round4.md R11): near a campfire, which of the profession camp objects could still
-- give you something, and which to skip because a class buff you already have doesn't stack with it.
-- Facts only, in our own table:
-- * buff spell IDs and base effects from Tweaks Forever's Data\CampBenefits.lua (GPL-3.0-or-later, generated
--   from Blizzard's client tables for build 1.60.1.70862; the server scales the numbers by level);
-- * "exclusive with" from Firekeeper's object catalogue (MIT, docs/SOURCES.md, quoting the item tooltips).
--   The group versions of the same buffs (Greater Blessing, Gift of the Wild, Prayer of ..., Arcane
--   Brilliance) are our addition. Buff names are matched in English: other client languages see no "skip"
--   lines (unverified in game).
-- Read only, never uses anything: auras are read out of combat and only when the game doesn't hide them.

local OBJECTS = {
    { aura = 1230587, name = "Mana Well", effect = "Restores 29 Mana every 5 seconds",
        exclusive = { "Blessing of Wisdom", "Greater Blessing of Wisdom" } },
    { aura = 1230172, name = "Sharpening Wheel", effect = "Strength increased by 34",
        exclusive = { "Strength of Earth" } },
    { aura = 1230653, name = "Enchanted Lute", effect = "Armor +308, all attributes +13, all resistances +22",
        exclusive = { "Mark of the Wild", "Gift of the Wild" } },
    { aura = 1230124, name = "First Aid Kit", effect = "Stamina increased by 56",
        exclusive = { "Power Word: Fortitude", "Prayer of Fortitude" } },
    { aura = 1230098, name = "Fish Bowl", effect = "All stats increased by 8%",
        exclusive = { "Blessing of Kings", "Greater Blessing of Kings" } },
    { aura = 1229513, name = "Incense Candle", effect = "Intellect increased by 25",
        exclusive = { "Arcane Intellect", "Arcane Brilliance" } },
    { aura = 1230164, name = "Lodestone", effect = "Melee Attack Power increased by 90",
        exclusive = { "Blessing of Might", "Greater Blessing of Might" } },
    { aura = 1229519, name = "Camp Chair", effect = "Critical strike chance with spells and attacks +2%",
        exclusive = { "Moonkin Aura" } },
    { aura = 1229718, name = "Faction Banner", effect = "Spirit increased by 32",
        exclusive = { "Divine Spirit", "Prayer of Spirit" } },
}
local CAMPFIRE_NEARBY = 1283391

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Readable()
    if InCombatLockdown and InCombatLockdown() then
        return false
    end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
        if not ok or Safe(secret) ~= false then
            return false
        end
    end
    return C_UnitAuras ~= nil
end

local function HasID(id)
    if not C_UnitAuras.GetPlayerAuraBySpellID then
        return false
    end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
    return ok and type(Safe(aura)) == "table"
end

local function HasName(name)
    if not C_UnitAuras.GetAuraDataBySpellName then
        return false
    end
    local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
    return ok and type(Safe(aura)) == "table"
end

-- Lines for FoodCheck's page, or nil when you're not at a camp or buffs can't be read now.
function FoodCheck_CampLines()
    if not (Readable() and HasID(CAMPFIRE_NEARBY)) then
        return nil
    end
    local lines = { "|cffffd100At this camp|r, if someone has put them up (camp objects last an hour):" }
    for _, object in ipairs(OBJECTS) do
        if not HasID(object.aura) then
            local covered
            for _, buff in ipairs(object.exclusive) do
                if HasName(buff) then
                    covered = buff
                    break
                end
            end
            if covered then
                lines[#lines + 1] = string.format("  |cff999999%s|r: skip, you have %s (they don't stack)", object.name, covered)
            else
                lines[#lines + 1] = string.format("  |cffffd100%s|r: %s", object.name, object.effect)
            end
        end
    end
    return lines
end
