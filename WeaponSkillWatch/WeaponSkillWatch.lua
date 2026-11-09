local LOW_BEHIND = 15
local WATCHED_SLOTS = { [16] = "main hand", [17] = "off hand", [18] = "ranged" }
local CLASS_WEAPON = 2

-- Weapon subclass ID = skill line ID, from Blizzard's Forever SkillsFrame.
local SKILL_BY_SUBCLASS = {
    [0] = 44, [1] = 172, [2] = 45, [3] = 46, [4] = 54, [5] = 160, [6] = 229, [7] = 43,
    [8] = 55, [10] = 136, [13] = 162, [15] = 173, [16] = 176, [18] = 226, [19] = 228,
}

local warned = {}

-- These classes cast rather than swing, so a low staff or dagger skill changes nothing. Their wand skill still matters.
local CASTER_CLASSES = { MAGE = true, PRIEST = true, WARLOCK = true }
local RANGED_SLOT = 18

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("WeaponSkillWatch", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function SlotMatters(slot)
    return slot == RANGED_SLOT or not CASTER_CLASSES[Safe(select(2, UnitClass("player")))]
end

-- Returns the skill line for the weapon in a slot, or nil if the slot holds no weapon.
local function SlotSkillLine(slot)
    local link = Safe(GetInventoryItemLink("player", slot))
    if not link then
        return nil
    end
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(link)
    if Safe(classID) ~= CLASS_WEAPON then
        return nil
    end
    local subClass = Safe(subClassID)
    return subClass and SKILL_BY_SUBCLASS[subClass]
end

-- Returns name, rank, maxRank, or nil if the character doesn't have this skill.
local function ReadSkill(line)
    local info = Safe(C_SkillInfo.GetSkillLineInfoByID(line))
    if type(info) ~= "table" then
        return nil
    end
    local name, rank, maxRank = Safe(info.name), Safe(info.rank), Safe(info.maxRank)
    if not (name and rank and maxRank) then
        return nil
    end
    return name, rank, maxRank
end

local function CheckEquipped()
    local active = {}
    for slot, label in pairs(WATCHED_SLOTS) do
        local line = SlotMatters(slot) and SlotSkillLine(slot)
        -- Two weapons of one skill (dual-wielded swords) warn once.
        if line and not active[line] then
            local name, rank, maxRank = ReadSkill(line)
            if name and maxRank - rank >= LOW_BEHIND then
                active[line] = true
                if not warned[line] then
                    -- Glancing blows only happen to melee swings, so ranged weapons and wands just miss.
                    local effect = slot == RANGED_SLOT and "more misses" or "more misses and glancing blows"
                    Print(string.format("%s is only %d/%d (%s). Expect %s until it catches up.",
                        name, rank, maxRank, label, effect))
                end
            end
        end
    end
    warned = active
end

local function ShowEquipped()
    local shown = false
    for slot = 16, 18 do
        local line = SlotSkillLine(slot)
        if line then
            local name, rank, maxRank = ReadSkill(line)
            if name then
                shown = true
                Print(string.format("%s: %s %d/%d", WATCHED_SLOTS[slot], name, rank, maxRank))
            else
                shown = true
                Print(WATCHED_SLOTS[slot] .. ": no skill data for this weapon; you may need to train it.")
            end
        end
    end
    if not shown then
        Print("No weapon equipped.")
    end
end

local function ShowAll()
    local rows = {}
    for _, line in pairs(SKILL_BY_SUBCLASS) do
        local name, rank, maxRank = ReadSkill(line)
        if name then
            rows[#rows + 1] = { name = name, rank = rank, maxRank = maxRank }
        end
    end
    table.sort(rows, function(a, b)
        return a.name < b.name
    end)
    for _, row in ipairs(rows) do
        Print(string.format("%s %d/%d", row.name, row.rank, row.maxRank))
    end
    if #rows == 0 then
        Print("No weapon skills found.")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("SKILL_LINES_CHANGED")
events:SetScript("OnEvent", function(_, event, slot)
    slot = Safe(slot)
    if event ~= "PLAYER_EQUIPMENT_CHANGED" or (slot and WATCHED_SLOTS[slot]) then
        CheckEquipped()
    end
end)

SLASH_WEAPONSKILLWATCH1 = "/wsw"
SlashCmdList.WEAPONSKILLWATCH = function(message)
    if message:lower():match("^%s*all%s*$") then
        ShowAll()
    else
        ShowEquipped()
    end
end

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.WeaponSkillWatch = function()
    local items, listed = {}, {}
    for slot = 16, 18 do
        local line = SlotMatters(slot) and SlotSkillLine(slot)
        local name, rank, maxRank
        -- Two swords share one skill, so it gets one row.
        if line and not listed[line] then
            listed[line] = true
            name, rank, maxRank = ReadSkill(line)
        end
        if name and maxRank - rank >= LOW_BEHIND then
            items[#items + 1] = { text = string.format("|cffddaa55Low skill|r %s %d/%d", name, rank, maxRank), page = "Weapon skills" }
        end
    end
    return items
end
