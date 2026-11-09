-- Enchanting leveling path for World of Warcraft: Forever (Alliance).
-- Sources: https://www.wow-professions.com/forever/enchanting-leveling-guide
--          https://metabot.gg/en/wow-forever/professions/enchanting (Forever skill colors + reagents)
--          https://www.wow-professions.com/forever/npc/tilli-thistlefuzz
--          https://www.wow-professions.com/forever/npc/kania
--          https://warcraft.wiki.gg/wiki/Lorelae_Wintersong, https://warcraft.wiki.gg/wiki/Mythrin'dir (coords)
--          https://www.warcrafttavern.com/forever/guides/profession-trainers/ (trainer coords)
--          Item IDs checked on https://classicdb.ch/?item=<id> (wowhead blocked automated reads).
-- Craft counts: each point at skill s succeeds with chance (grey - s) / (grey - yellow), 1 while orange (Forever yellow/grey from metabot.gg). `crafts` is the mean plus 1.28 standard deviations, rounded up: enough about 9 times in 10. Forever's Working Overtime talent (+4% chance per rank) is not counted.
-- Differences from wow-professions: 1-80 uses Enchant Bracer - Minor Deflect (known at 1, orange to 80,
-- Lesser Magic Essence) instead of the Mote of Magic enchants; later steps use only orange ranges where possible
-- (Cloak - Greater Defense 210-225, Shield - Greater Stamina 265-290).
-- Mote of Magic (Forever-only vendor reagent; wow-professions gives item 247786, unverified) is kept out of mats.
-- Many metabot learn skills are estimates (Minor Stamina bracer, rods, Lesser Agility, Strength, 205-220 enchants).
-- Strange Dust is sold in limited supply by Enchanting Supplies vendors in Forever (Tilli Thistlefuzz, Kania).
-- 225-300 is untested by wow-professions (beta data). Vaean / Tilli Thistlefuzz / Kania coords are approximate.
ProfessionGuideData = ProfessionGuideData or {}
ProfessionGuideData[333] = {
    name = "Enchanting",
    steps = {
        { from = 1, to = 2, craft = "Runed Copper Rod", itemID = 6218, crafts = 1, yellow = 5, grey = 10, makes = 1,
          mats = {
              { itemID = 6217, name = "Copper Rod", count = 1, vendor = true },
          },
          learn = "auto",
          note = "Also needs 1 Mote of Magic (Enchanting Supplies vendor). Keep the rod in your bags for all enchants." },
        { from = 2, to = 80, craft = "Enchant Bracer - Minor Deflect", crafts = 78, yellow = 80, grey = 120,
          mats = {
              { itemID = 10938, name = "Lesser Magic Essence", count = 1 },
          },
          learn = "auto",
          note = "Orange to 80. Train Journeyman at 50 (level 10) before 75. Disenchant is in the Professions window." },
        { from = 80, to = 100, craft = "Enchant Bracer - Minor Stamina", crafts = 20, yellow = 100, grey = 140,
          mats = {
              { itemID = 10940, name = "Strange Dust", count = 2, vendor = true },
          },
          learn = "trainer",
          note = "Orange to 100. Strange Dust: Enchanting Supplies vendors (limited stock), disenchanting or AH." },
        { from = 100, to = 110, craft = "Enchant Cloak - Minor Protection", crafts = 10, yellow = 110, grey = 150,
          mats = {
              { itemID = 10940, name = "Strange Dust", count = 2, vendor = true },
          },
          learn = "trainer",
          note = "Orange to 110." },
        { from = 110, to = 111, craft = "Runed Silver Rod", itemID = 6339, crafts = 1, yellow = 130, grey = 170, makes = 1,
          mats = {
              { itemID = 6338, name = "Silver Rod", count = 1 },
              { itemID = 10940, name = "Strange Dust", count = 3, vendor = true },
              { itemID = 10938, name = "Lesser Magic Essence", count = 4 },
              { itemID = 1210, name = "Shadowgem", count = 1 },
          },
          learn = "trainer",
          note = "Silver Rod is made by Blacksmiths (AH). Needed for the next enchants." },
        { from = 111, to = 125, craft = "Enchant Cloak - Minor Protection", crafts = 21, yellow = 110, grey = 150,
          mats = {
              { itemID = 10940, name = "Strange Dust", count = 2, vendor = true },
          },
          learn = "trainer",
          note = "Yellow. Alt: 2H Weapon - Lesser Intellect (4 LME, orange to 130, formula Tilli Thistlefuzz, IF)." },
        { from = 125, to = 135, craft = "Enchant Boots - Minor Stamina", crafts = 10, yellow = 150, grey = 190,
          mats = {
              { itemID = 10940, name = "Strange Dust", count = 4, vendor = true },
          },
          learn = "trainer",
          note = "Orange to 150. Train Expert at 125 (level 20, 50s): Kitta Firewind, Tower of Azora, Elwynn." },
        { from = 135, to = 150, craft = "Enchant Bracer - Lesser Stamina", crafts = 15, yellow = 155, grey = 195,
          mats = {
              { itemID = 11083, name = "Soul Dust", count = 1 },
          },
          learn = "trainer",
          note = "Orange to 155. If not offered yet, keep making Boots - Minor Stamina to 150." },
        { from = 150, to = 151, craft = "Runed Golden Rod", itemID = 11130, crafts = 1, yellow = 175, grey = 215, makes = 1,
          mats = {
              { itemID = 11128, name = "Golden Rod", count = 1 },
              { itemID = 5500, name = "Iridescent Pearl", count = 1 },
              { itemID = 11082, name = "Greater Astral Essence", count = 1 },
              { itemID = 11083, name = "Soul Dust", count = 1 },
          },
          learn = "trainer",
          note = "Expert recipe. Golden Rod is made by Blacksmiths (AH)." },
        { from = 151, to = 160, craft = "Minor Mana Oil", itemID = 20745, crafts = 9, yellow = 160, grey = 180, makes = 1,
          mats = {
              { itemID = 11083, name = "Soul Dust", count = 1 },
              { itemID = 17034, name = "Maple Seed", count = 2, vendor = true },
              { itemID = 3372, name = "Leaded Vial", count = 1, vendor = true },
          },
          learn = "vendor: Vaean, Craftsmen's Terrace, Darnassus (also Tilli Thistlefuzz, Ironforge)",
          note = "Orange to 160. Buy the Lesser Wizard Oil formula too. Maple Seed: reagent vendors." },
        { from = 160, to = 180, craft = "Enchant Boots - Lesser Agility", crafts = 20, yellow = 180, grey = 220,
          mats = {
              { itemID = 11083, name = "Soul Dust", count = 1 },
          },
          learn = "trainer",
          note = "Orange to 180." },
        { from = 180, to = 200, craft = "Enchant Bracer - Strength", crafts = 20, yellow = 200, grey = 240,
          mats = {
              { itemID = 11137, name = "Vision Dust", count = 1 },
          },
          learn = "trainer",
          note = "Orange to 200. Artisan needs level 35: plan your Uldaman trip." },
        { from = 200, to = 201, craft = "Runed Truesilver Rod", itemID = 11145, crafts = 1, yellow = 220, grey = 260, makes = 1,
          mats = {
              { itemID = 11144, name = "Truesilver Rod", count = 1 },
              { itemID = 7971, name = "Black Pearl", count = 1 },
              { itemID = 11135, name = "Greater Mystic Essence", count = 1 },
              { itemID = 11137, name = "Vision Dust", count = 1 },
          },
          learn = "trainer",
          note = "Truesilver Rod is made by Blacksmiths (AH)." },
        { from = 201, to = 210, craft = "Lesser Wizard Oil", itemID = 20746, crafts = 9, yellow = 210, grey = 230, makes = 1,
          mats = {
              { itemID = 11137, name = "Vision Dust", count = 1 },
              { itemID = 17035, name = "Stranglethorn Seed", count = 2, vendor = true },
              { itemID = 3372, name = "Leaded Vial", count = 1, vendor = true },
          },
          learn = "vendor: Vaean, Craftsmen's Terrace, Darnassus (also Tilli Thistlefuzz, Ironforge)",
          note = "Orange to 210. Stranglethorn Seed: reagent vendors." },
        { from = 210, to = 225, craft = "Enchant Cloak - Greater Defense", crafts = 15, yellow = 225, grey = 265,
          mats = {
              { itemID = 11137, name = "Vision Dust", count = 1 },
          },
          learn = "trainer",
          note = "Orange to 225. Get Artisan from Annora in Uldaman before 225 (bring a group)." },
        { from = 225, to = 230, craft = "Enchant Gloves - Agility", crafts = 5, yellow = 230, grey = 270,
          mats = {
              { itemID = 11137, name = "Vision Dust", count = 1 },
          },
          learn = "trainer",
          note = "Expert recipe (Kitta Firewind). Orange to 230." },
        { from = 230, to = 235, craft = "Enchant Boots - Stamina", crafts = 5, yellow = 235, grey = 275,
          mats = {
              { itemID = 11137, name = "Vision Dust", count = 2 },
          },
          learn = "trainer",
          note = "Expert recipe. Orange to 235." },
        { from = 235, to = 250, craft = "Enchant Chest - Superior Stamina", crafts = 18, yellow = 240, grey = 280,
          mats = {
              { itemID = 11137, name = "Vision Dust", count = 3 },
          },
          learn = "trainer",
          note = "Orange to 240, yellow 240-250." },
        { from = 250, to = 265, craft = "Lesser Mana Oil", itemID = 20747, crafts = 17, yellow = 260, grey = 280, makes = 1,
          mats = {
              { itemID = 11176, name = "Dream Dust", count = 1 },
              { itemID = 8831, name = "Purple Lotus", count = 1 },
              { itemID = 8925, name = "Crystal Vial", count = 1, vendor = true },
          },
          learn = "vendor: Kania, Cenarion Hold inn (upstairs), Silithus",
          note = "Orange to 260. No Purple Lotus? Bracer - Greater Strength (Annora) is orange 240-260." },
        { from = 265, to = 290, craft = "Enchant Shield - Greater Stamina", crafts = 26, yellow = 285, grey = 325,
          mats = {
              { itemID = 11176, name = "Dream Dust", count = 6 },
          },
          learn = "vendor: Mythrin'dir, Darnassus",
          note = "Formula is bind on pickup. Orange to 285, then yellow (to 305)." },
        { from = 290, to = 291, craft = "Runed Arcanite Rod", itemID = 16207, crafts = 1, yellow = 310, grey = 350, makes = 1,
          mats = {
              { itemID = 16206, name = "Arcanite Rod", count = 1 },
              { itemID = 13926, name = "Golden Pearl", count = 1 },
              { itemID = 16204, name = "Illusion Dust", count = 10 },
              { itemID = 16203, name = "Greater Eternal Essence", count = 4 },
              { itemID = 14343, name = "Small Brilliant Shard", count = 4 },
              { itemID = 14344, name = "Large Brilliant Shard", count = 2 },
          },
          learn = "vendor: Lorelae Wintersong, Nighthaven, Moonglade",
          note = "Optional and costly. Skip it and do Shield - Greater Stamina to 300 (about 14 more) if you prefer." },
        { from = 291, to = 300, craft = "Enchant Cloak - Superior Defense", crafts = 9, yellow = 305, grey = 345,
          mats = {
              { itemID = 16204, name = "Illusion Dust", count = 8 },
          },
          learn = "vendor: Lorelae Wintersong, Nighthaven, Moonglade",
          note = "Orange to 305. Too pricey? Keep making Shield - Greater Stamina." },
    },
    trainers = {
        { rank = "Apprentice", name = "Lalina Summermoon", where = "Craftsmen's Terrace, Darnassus",
          zone = "Darnassus", mapID = 1457, x = 0.596, y = 0.124 },
        { rank = "Journeyman", name = "Taladan", where = "Craftsmen's Terrace, Darnassus",
          zone = "Darnassus", mapID = 1457, x = 0.586, y = 0.136 },
        { rank = "Apprentice", name = "Alanna Raveneye", where = "Oracle Glade, Teldrassil",
          zone = "Teldrassil", mapID = 1438, x = 0.368, y = 0.342 },
        { rank = "Recipe vendor: Minor Mana Oil, Lesser Wizard Oil", name = "Vaean", where = "Craftsmen's Terrace, Darnassus (coords approx.)",
          zone = "Darnassus", mapID = 1457, x = 0.585, y = 0.145 },
        { rank = "Recipe vendor: Shield - Greater Stamina", name = "Mythrin'dir", where = "Darnassus",
          zone = "Darnassus", mapID = 1457, x = 0.581, y = 0.342 },
        { rank = "Apprentice", name = "Betty Quin", where = "Mage Quarter, Stormwind",
          zone = "Stormwind City", mapID = 1453, x = 0.532, y = 0.740 },
        { rank = "Journeyman", name = "Lucan Cordell", where = "Mage Quarter, Stormwind",
          zone = "Stormwind City", mapID = 1453, x = 0.529, y = 0.743 },
        { rank = "Apprentice", name = "Thonys Pillarstone", where = "The Great Forge, Ironforge",
          zone = "Ironforge", mapID = 1455, x = 0.606, y = 0.448 },
        { rank = "Journeyman", name = "Gimble Thistlefuzz", where = "The Great Forge, Ironforge",
          zone = "Ironforge", mapID = 1455, x = 0.602, y = 0.456 },
        { rank = "Recipe vendor: oils, 2H Lesser Intellect", name = "Tilli Thistlefuzz", where = "The Great Forge, Ironforge (coords approx.)",
          zone = "Ironforge", mapID = 1455, x = 0.610, y = 0.448 },
        { rank = "Journeyman", name = "Xylinnia Starshine", where = "Feathermoon Stronghold, Feralas",
          zone = "Feralas", mapID = 1444, x = 0.316, y = 0.442 },
        { rank = "Expert", name = "Kitta Firewind", where = "Top of the Tower of Azora, Elwynn Forest",
          zone = "Elwynn Forest", mapID = 1429, x = 0.649, y = 0.707 },
        { rank = "Artisan", name = "Annora", where = "Inside Uldaman (pin = Badlands entrance); spawns after clearing her area",
          zone = "Badlands", mapID = 1418, x = 0.42, y = 0.13 },
        { rank = "Recipe vendor: Lesser Mana Oil", name = "Kania", where = "Cenarion Hold inn upstairs, Silithus (coords approx.)",
          zone = "Silithus", mapID = 1451, x = 0.520, y = 0.394 },
        { rank = "Recipe vendor: Runed Arcanite Rod, Cloak - Superior Defense", name = "Lorelae Wintersong", where = "Nighthaven, Moonglade",
          zone = "Moonglade", mapID = 1450, x = 0.482, y = 0.401 },
    },
    notes = {
        "Apprentice Enchanting has no level requirement in Forever.",
        "Journeyman: skill 50, level 10. Expert: skill 125, level 20, 50s. Artisan: skill 200, level 35.",
        "Disenchant is not in the spellbook: use it from the Enchanting Professions window.",
        "Enchants need the right Runed rod in your bags: copper, silver, golden, truesilver.",
        "Mote of Magic (Forever reagent) is only needed once, for the Runed Copper Rod.",
        "Artisan is only taught by Annora in Uldaman: learn all her recipes before leaving.",
        "225-300 is untested beta data.",
    },
}
