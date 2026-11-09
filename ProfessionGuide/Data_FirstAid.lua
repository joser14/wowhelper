-- First Aid leveling path for World of Warcraft: Forever (Alliance, Night Elf start).
-- Sources: https://www.wow-professions.com/forever/first-aid-leveling-guide (route, books, Triage)
--          https://metabot.gg/en/wow-forever/professions/first-aid (Forever skill colors + reagents)
--          https://www.wow-professions.com/forever/npc/<name> (Deneb Walker, Doctor VanHowzen coords)
--          https://www.warcrafttavern.com/forever/guides/profession-trainers/ (trainer coords)
--          Item IDs checked on https://classicdb.ch/?item=<id> (wowhead blocked automated reads).
-- Craft counts: each point at skill s succeeds with chance (grey - s) / (grey - yellow), 1 while orange (Forever yellow/grey from metabot.gg). `crafts` is the mean plus 1.28 standard deviations, rounded up: enough about 9 times in 10. Forever's Working Overtime talent (+4% chance per rank) is not counted.
-- metabot marks most bandage learn skills as estimates (always 15 below yellow). wow-professions and Classic
-- give the real learn skills (Heavy Linen 40, Wool 80, Heavy Wool 115, Silk 150, Heavy Mageweave 240,
-- Runecloth 260, Heavy Runecloth 290), so those are used; bandages at their learn skill are yellow.
-- wow-professions ends 275-300 with Major Healing Potion, but its manual has no known source (likely a drop);
-- this file uses the trainer bandages (Runecloth, Heavy Runecloth) instead. 225-300 untested on the beta.
-- Forever moved healing potions to First Aid; they are listed as alternatives in notes (they need herbs).
ProfessionGuideData = ProfessionGuideData or {}
ProfessionGuideData[129] = {
    name = "First Aid",
    steps = {
        { from = 1, to = 40, craft = "Linen Bandage", itemID = 1251, crafts = 43, yellow = 30, grey = 60, makes = 1,
          mats = {
              { itemID = 2589, name = "Linen Cloth", count = 1 },
          },
          learn = "auto",
          note = "Yellow from 30." },
        { from = 40, to = 80, craft = "Heavy Linen Bandage", itemID = 2581, crafts = 62, yellow = 50, grey = 100, makes = 1,
          mats = {
              { itemID = 2589, name = "Linen Cloth", count = 2 },
          },
          learn = "trainer",
          note = "Yellow from 50, green from 75. Train Journeyman at 50 (before 75)." },
        { from = 80, to = 115, craft = "Wool Bandage", itemID = 3530, crafts = 54, yellow = 80, grey = 150, makes = 1,
          mats = {
              { itemID = 2592, name = "Wool Cloth", count = 1 },
          },
          learn = "trainer",
          note = "Yellow the whole way." },
        { from = 115, to = 150, craft = "Heavy Wool Bandage", itemID = 3531, crafts = 54, yellow = 115, grey = 185, makes = 1,
          mats = {
              { itemID = 2592, name = "Wool Cloth", count = 2 },
          },
          learn = "trainer",
          note = "At 125 buy Expert First Aid - Under Wraps from Deneb Walker (Stromgarde, Arathi)." },
        { from = 150, to = 180, craft = "Silk Bandage", itemID = 6450, crafts = 47, yellow = 150, grey = 210, makes = 1,
          mats = {
              { itemID = 4306, name = "Silk Cloth", count = 1 },
          },
          learn = "trainer",
          note = "Last trainer recipe: learn it at 150. Yellow the whole way." },
        { from = 180, to = 210, craft = "Heavy Silk Bandage", itemID = 6451, crafts = 47, yellow = 180, grey = 240, makes = 1,
          mats = {
              { itemID = 4306, name = "Silk Cloth", count = 2 },
          },
          learn = "vendor: Deneb Walker, Stromgarde Keep, Arathi Highlands (Manual: Heavy Silk Bandage)",
          note = "Buy both manuals when you buy the Expert book." },
        { from = 210, to = 240, craft = "Mageweave Bandage", itemID = 8544, crafts = 47, yellow = 210, grey = 270, makes = 1,
          mats = {
              { itemID = 4338, name = "Mageweave Cloth", count = 1 },
          },
          learn = "vendor: Deneb Walker, Stromgarde Keep, Arathi Highlands (Manual: Mageweave Bandage)",
          note = "At 225 (level 35) do Triage for Doctor Gustaf VanHowzen, Theramore, to unlock Artisan." },
        { from = 240, to = 260, craft = "Heavy Mageweave Bandage", itemID = 8545, crafts = 28, yellow = 240, grey = 300, makes = 1,
          mats = {
              { itemID = 4338, name = "Mageweave Cloth", count = 2 },
          },
          learn = "trainer",
          note = "Taught by Doctor Gustaf VanHowzen, Theramore, after Triage." },
        { from = 260, to = 290, craft = "Runecloth Bandage", itemID = 14529, crafts = 47, yellow = 260, grey = 320, makes = 1,
          mats = {
              { itemID = 14047, name = "Runecloth", count = 1 },
          },
          learn = "trainer",
          note = "Taught by Doctor Gustaf VanHowzen, Theramore." },
        { from = 290, to = 300, craft = "Heavy Runecloth Bandage", itemID = 14530, crafts = 13, yellow = 290, grey = 350, makes = 1,
          mats = {
              { itemID = 14047, name = "Runecloth", count = 2 },
          },
          learn = "trainer",
          note = "Taught by Doctor Gustaf VanHowzen, Theramore. Alt: Major Healing Potion if you own the manual." },
    },
    trainers = {
        { rank = "Apprentice-Journeyman", name = "Dannelor", where = "Darnassus",
          zone = "Darnassus", mapID = 1457, x = 0.515, y = 0.137 },
        { rank = "Apprentice-Journeyman", name = "Byancie", where = "Dolanaar, Teldrassil",
          zone = "Teldrassil", mapID = 1438, x = 0.554, y = 0.569 },
        { rank = "Apprentice-Journeyman", name = "Shaina Fuller", where = "Cathedral Square, Stormwind",
          zone = "Stormwind City", mapID = 1453, x = 0.529, y = 0.449 },
        { rank = "Apprentice-Journeyman", name = "Nissa Firestone", where = "Ironforge",
          zone = "Ironforge", mapID = 1455, x = 0.548, y = 0.586 },
        { rank = "Apprentice-Journeyman", name = "Fremal Doohickey", where = "Menethil Harbor, Wetlands",
          zone = "Wetlands", mapID = 1437, x = 0.108, y = 0.611 },
        { rank = "Expert (book) + manuals", name = "Deneb Walker", where = "Stromgarde Keep, Arathi Highlands",
          zone = "Arathi Highlands", mapID = 1417, x = 0.271, y = 0.588 },
        { rank = "Artisan (quest: Triage) + recipes", name = "Doctor Gustaf VanHowzen", where = "Theramore Isle, Dustwallow Marsh",
          zone = "Dustwallow Marsh", mapID = 1445, x = 0.678, y = 0.490 },
    },
    notes = {
        "Apprentice: no level needed. Journeyman: trainer at 50.",
        "Expert: book Expert First Aid - Under Wraps (Deneb Walker, Arathi), skill 125, no level needed.",
        "Artisan: Triage quest (skill 225, level 35). Save 15 patients, critical ones first, turn in at 15.",
        "Cloth: ~167 Linen, ~162 Wool, ~141 Silk, ~103 Mageweave, ~73 Runecloth.",
        "Forever potions: Minor Healing (40: Peacebloom, Mild Spices, Empty Vial) yellow 55.",
        "Lesser Healing (70: Briarthorn, 2 Mild Spices, Empty Vial) orange to 85.",
        "Healing Potion (120: Bruiseweed, Hot Spices, Leaded Vial) orange to 135.",
        "Potions save cloth if you have herbs; Mild/Hot Spices from Cooking vendors, vials from Alchemy vendors.",
    },
}
