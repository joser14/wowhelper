-- Events data: the Darkmoon Faire's turn-ins, prizes and Sayge's fortunes, plus Forever's published Faire dates.
--
-- Turn-in item IDs, counts and quest IDs: Darkmoon Turn-ins by Felipe M. (fmartingr/wow-addon-darkmoon-turn-ins,
-- DarkmoonTurnIns/Data.lua, MIT, "Copyright (c) 2026 Felipe M."), which took them from Wowhead's Classic quest
-- pages. Credited in NOTICE.md.
-- Tickets per turn-in and Sayge's answer orders: Warcraft Tavern's Classic Darkmoon Faire guide (facts, own words).
-- Turn-in NPCs and prize levels: warcraft.wiki.gg quest and Darkmoon Faire Prize Ticket pages.
-- "skill" (crafted turn-ins) and "minLevel"/"maxLevel" (beast drops) are rough guides of our own, only used to
-- pick what to show at your level; they never decide anything for you.

EventsData = {
    TICKET = 19182, -- Darkmoon Faire Prize Ticket

    -- group: beast (anyone can farm these) or the profession that crafts the item.
    turnins = {
        { item = 5134, name = "Small Furry Paw", count = 5, tickets = 1, tier = 1, group = "beast", npc = "Yebb Neblegear",
            quests = { 7899 }, minLevel = 10, maxLevel = 20, from = "cats in Darkshore and the Barrens" },
        { item = 11407, name = "Torn Bear Pelt", count = 5, tickets = 4, tier = 2, group = "beast", npc = "Yebb Neblegear",
            quests = { 7900 }, minLevel = 18, maxLevel = 30, from = "bears" },
        { item = 4582, name = "Soft Bushy Tail", count = 5, tickets = 8, tier = 3, group = "beast", npc = "Yebb Neblegear",
            quests = { 7901 }, minLevel = 25, maxLevel = 38, from = "beasts" },
        { item = 5117, name = "Vibrant Plume", count = 5, tickets = 12, tier = 4, group = "beast", npc = "Yebb Neblegear",
            quests = { 7902 }, minLevel = 35, maxLevel = 48, from = "birds" },
        { item = 11404, name = "Evil Bat Eye", count = 10, tickets = 20, tier = 5, group = "beast", npc = "Yebb Neblegear",
            quests = { 7903, 7943 }, minLevel = 45, maxLevel = 60, from = "bats" },
        { item = 19933, name = "Glowing Scorpid Blood", count = 10, tickets = 20, tier = 5, group = "beast", npc = "Yebb Neblegear",
            quests = { 8222, 8223 }, minLevel = 50, maxLevel = 60, from = "scorpids" },

        { item = 3240, name = "Coarse Weightstone", count = 10, tickets = 1, tier = 1, group = "Blacksmithing", npc = "Kerri Hicks",
            quests = { 7889 }, skill = 65 },
        { item = 3486, name = "Heavy Grinding Stone", count = 7, tickets = 4, tier = 2, group = "Blacksmithing", npc = "Kerri Hicks",
            quests = { 7890 }, skill = 125 },
        { item = 3835, name = "Green Iron Bracers", count = 3, tickets = 8, tier = 3, group = "Blacksmithing", npc = "Kerri Hicks",
            quests = { 7891 }, skill = 165 },
        { item = 7945, name = "Big Black Mace", count = 1, tickets = 12, tier = 4, group = "Blacksmithing", npc = "Kerri Hicks",
            quests = { 7892 }, skill = 205 },
        { item = 12644, name = "Dense Grinding Stone", count = 8, tickets = 20, tier = 5, group = "Blacksmithing", npc = "Kerri Hicks",
            quests = { 7893, 7939 }, skill = 250 },

        { item = 4363, name = "Copper Modulator", count = 5, tickets = 1, tier = 1, group = "Engineering", npc = "Rinling",
            quests = { 7894 }, skill = 65 },
        { item = 4375, name = "Whirring Bronze Gizmo", count = 7, tickets = 4, tier = 2, group = "Engineering", npc = "Rinling",
            quests = { 7895 }, skill = 125 },
        { item = 9313, name = "Green Firework", count = 36, tickets = 8, tier = 3, group = "Engineering", npc = "Rinling",
            quests = { 7896 }, skill = 150 },
        { item = 11590, name = "Mechanical Repair Kit", count = 6, tickets = 12, tier = 4, group = "Engineering", npc = "Rinling",
            quests = { 7897 }, skill = 200 },
        { item = 15994, name = "Thorium Widget", count = 6, tickets = 20, tier = 5, group = "Engineering", npc = "Rinling",
            quests = { 7898, 7942 }, skill = 260 },

        { item = 2309, name = "Embossed Leather Boots", count = 3, tickets = 1, tier = 1, group = "Leatherworking", npc = "Chronos",
            quests = { 7881 }, skill = 55 },
        { item = 2314, name = "Toughened Leather Armor", count = 3, tickets = 4, tier = 2, group = "Leatherworking", npc = "Chronos",
            quests = { 7882 }, skill = 120 },
        { item = 5739, name = "Barbaric Harness", count = 3, tickets = 8, tier = 3, group = "Leatherworking", npc = "Chronos",
            quests = { 7883 }, skill = 190 },
        { item = 8185, name = "Turtle Scale Leggings", count = 1, tickets = 12, tier = 4, group = "Leatherworking", npc = "Chronos",
            quests = { 7884 }, skill = 205 },
        { item = 15564, name = "Rugged Armor Kit", count = 8, tickets = 20, tier = 5, group = "Leatherworking", npc = "Chronos",
            quests = { 7885, 7941 }, skill = 250 },
    },

    -- Profession skill lines, for the crafted turn-ins.
    skillLines = { Blacksmithing = 164, Leatherworking = 165, Engineering = 202 },

    -- Prizes from Gelvas Grimegate: tickets and the level you need.
    prizes = {
        { name = "Darkmoon Flower (off-hand)", tickets = 5, level = 6 },
        { name = "Darkmoon Storage Box (14-slot bag)", tickets = 50, level = 6 },
        { name = "Minor Darkmoon Prize (level 21-25 gear or a 10-slot bag)", tickets = 5, level = 15 },
        { name = "Last Month's Mutton (main hand)", tickets = 10, level = 25 },
        { name = "Lesser Darkmoon Prize (level 31-35 gear or a 12-slot bag)", tickets = 12, level = 30 },
        { name = "Greater Darkmoon Prize (level 46-50 gear)", tickets = 40, level = 45 },
        { name = "Last Year's Mutton", tickets = 50, level = 45 },
    },

    -- Sayge's fortune: a free two-hour buff. The answers to give, in order.
    sayge = {
        { buff = "Damage", answers = "1, 1" },
        { buff = "Resistance", answers = "1, 2 (or 2, 3)" },
        { buff = "Armor", answers = "1, 3 (or 4, 3)" },
        { buff = "Spirit", answers = "2, 1 (or 4, 2)" },
        { buff = "Intelligence", answers = "2, 2 (or 4, 1)" },
        { buff = "Stamina", answers = "3, 1" },
        { buff = "Strength", answers = "3, 2" },
        { buff = "Agility", answers = "3, 3" },
    },
    -- The buffs worth taking first, by class (leveling).
    saygeFor = {
        PRIEST = { "Intelligence", "Spirit" }, MAGE = { "Intelligence", "Spirit" }, WARLOCK = { "Damage", "Stamina" },
        DRUID = { "Intelligence", "Agility" }, SHAMAN = { "Damage", "Intelligence" }, PALADIN = { "Damage", "Strength" },
        WARRIOR = { "Damage", "Strength" }, ROGUE = { "Damage", "Agility" }, HUNTER = { "Damage", "Agility" },
    },

    zones = {
        Elwynn = { name = "Elwynn Forest", where = "near Goldshire" },
        Mulgore = { name = "Mulgore", where = "near Thunder Bluff" },
    },
    -- Forever's first Faire (Warcraft Tavern, mein-mmo): Elwynn Forest, 9 to 16 November 2026. Later Faires
    -- alternate between Elwynn and Mulgore each month. Only used when the calendar can't be read.
    known = {
        { from = { 2026, 11, 9 }, to = { 2026, 11, 16 }, zone = "Elwynn" },
    },
    firstMonth = { 2026, 11, "Elwynn" },
}
