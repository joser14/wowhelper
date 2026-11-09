-- Leatherworking leveling path for World of Warcraft: Forever (Alliance).
-- Sources: https://www.wow-professions.com/forever/leatherworking-leveling-guide
--          https://metabot.gg/en/wow-forever/professions/leatherworking (Forever skill colors + reagents)
--          https://www.wow-professions.com/forever/npc/leonard-porter, .../npc/jase-farlane (pattern skill levels)
--          https://www.warcrafttavern.com/forever/guides/profession-trainers/ (trainer coords)
--          Item IDs and vendor coords checked on https://classicdb.ch (wowhead blocked automated reads).
-- Craft counts: each point at skill s succeeds with chance (grey - s) / (grey - yellow), 1 while orange (Forever
-- yellow/grey from metabot.gg). `crafts` is the mean plus 1.28 standard deviations, rounded up: enough about 9 times
-- in 10. Forever's Working Overtime talent (+4% chance per rank) is not counted.
-- Route follows wow-professions' "Cured Heavy Hide" path with metabot colors. Learn skills that metabot marks
-- as estimates: Embossed Leather Gloves 50 (wow-professions: 45), Fine Leather Belt 65, Dark Leather Cloak 90,
-- Hillman's Leather Gloves 125 (wow-professions uses it from 120), Cured Heavy Hide 115, Barbaric Shoulders 150,
-- Guardian Gloves 165, Nightscape Headband 180, Nightscape Pants 205, Nightscape Boots 210.
-- Runic Leather Headband: Forever pattern (item 15756) needs 265 and is sold by Jase Farlane, Eastern Plaguelands,
-- confirmed at https://www.wowhead.com/forever/item=15756 (mats 14 Rugged Leather, 10 Runecloth, Rune Thread); metabot has no
-- colors for it, so 265/285/295/305 (yellow 285, grey 305 in the step) is assumed (Classic colors shifted like the other Rugged recipes).
-- 225-300 is untested by wow-professions (beta data).
ProfessionGuideData = ProfessionGuideData or {}
ProfessionGuideData[165] = {
    name = "Leatherworking",
    steps = {
        { from = 1, to = 45, craft = "Light Armor Kit", itemID = 2304, crafts = 53, yellow = 30, grey = 60, makes = 1,
          mats = {
              { itemID = 2318, name = "Light Leather", count = 1 },
          },
          learn = "auto",
          note = "Yellow from 30. Optional: Light Leather from 3 Ruined Leather Scraps (orange to 20)." },
        { from = 45, to = 75, craft = "Embossed Leather Gloves", itemID = 4239, crafts = 32, yellow = 70, grey = 100, makes = 1,
          mats = {
              { itemID = 2318, name = "Light Leather", count = 3 },
              { itemID = 2320, name = "Coarse Thread", count = 2, vendor = true },
          },
          learn = "trainer",
          note = "If not offered until 50, keep making Armor Kits. Yellow from 70. Train Journeyman at 50 (level 10)." },
        { from = 75, to = 100, craft = "Fine Leather Belt", itemID = 4246, crafts = 34, yellow = 85, grey = 115, makes = 1,
          mats = {
              { itemID = 2318, name = "Light Leather", count = 6 },
              { itemID = 2320, name = "Coarse Thread", count = 2, vendor = true },
          },
          learn = "trainer",
          note = "Yellow from 85." },
        { from = 100, to = 120, craft = "Dark Leather Cloak", itemID = 2316, crafts = 25, yellow = 110, grey = 135, makes = 1,
          mats = {
              { itemID = 2319, name = "Medium Leather", count = 8 },
              { itemID = 2321, name = "Fine Thread", count = 1, vendor = true },
              { itemID = 4340, name = "Gray Dye", count = 1, vendor = true },
          },
          learn = "trainer",
          note = "Yellow from 110." },
        { from = 120, to = 130, craft = "Hillman's Leather Gloves", itemID = 4247, crafts = 10, yellow = 145, grey = 170, makes = 1,
          mats = {
              { itemID = 2319, name = "Medium Leather", count = 14 },
              { itemID = 2321, name = "Fine Thread", count = 4, vendor = true },
          },
          learn = "trainer",
          note = "Orange to 145. Train Expert at 125 (Telonis, Darnassus, level 20)." },
        { from = 130, to = 140, craft = "Cured Heavy Hide", itemID = 4236, crafts = 47, yellow = 135, grey = 145, makes = 1,
          mats = {
              { itemID = 4235, name = "Heavy Hide", count = 1 },
              { itemID = 4289, name = "Salt", count = 3, vendor = true },
          },
          learn = "trainer",
          note = "~14 crafts reach 140 (yellow from 135). crafts = all 47 hides needed for Barbaric Shoulders and Guardian Gloves." },
        { from = 140, to = 155, craft = "Hillman's Leather Gloves", itemID = 4247, crafts = 20, yellow = 145, grey = 170, makes = 1,
          mats = {
              { itemID = 2319, name = "Medium Leather", count = 14 },
              { itemID = 2321, name = "Fine Thread", count = 4, vendor = true },
          },
          learn = "trainer",
          note = "Yellow from 145." },
        { from = 155, to = 170, craft = "Barbaric Shoulders", itemID = 5964, crafts = 15, yellow = 170, grey = 190, makes = 1,
          mats = {
              { itemID = 4234, name = "Heavy Leather", count = 8 },
              { itemID = 4236, name = "Cured Heavy Hide", count = 1 },
              { itemID = 2321, name = "Fine Thread", count = 2, vendor = true },
          },
          learn = "trainer",
          note = "Cured Heavy Hides from 130-140. Orange to 170." },
        { from = 170, to = 195, craft = "Guardian Gloves", itemID = 5966, crafts = 32, yellow = 185, grey = 205, makes = 1,
          mats = {
              { itemID = 4234, name = "Heavy Leather", count = 4 },
              { itemID = 4236, name = "Cured Heavy Hide", count = 1 },
              { itemID = 4291, name = "Silken Thread", count = 1, vendor = true },
          },
          learn = "trainer",
          note = "Yellow from 185." },
        { from = 195, to = 210, craft = "Nightscape Headband", itemID = 8176, crafts = 22, yellow = 200, grey = 220, makes = 1,
          mats = {
              { itemID = 4304, name = "Thick Leather", count = 5 },
              { itemID = 4291, name = "Silken Thread", count = 2, vendor = true },
          },
          learn = "trainer",
          note = "Yellow from 200. At 200 (level 35) get Artisan from Drakk Stonehand, Aerie Peak." },
        { from = 210, to = 225, craft = "Nightscape Pants", itemID = 8193, crafts = 15, yellow = 225, grey = 245, makes = 1,
          mats = {
              { itemID = 4304, name = "Thick Leather", count = 14 },
              { itemID = 4291, name = "Silken Thread", count = 4, vendor = true },
          },
          learn = "trainer",
          note = "Only Drakk Stonehand teaches it (not Telonis). Orange to 225." },
        { from = 225, to = 235, craft = "Nightscape Boots", itemID = 8197, crafts = 12, yellow = 230, grey = 250, makes = 1,
          mats = {
              { itemID = 4304, name = "Thick Leather", count = 16 },
              { itemID = 8343, name = "Heavy Silken Thread", count = 2, vendor = true },
          },
          learn = "trainer",
          note = "Needs Artisan. Yellow from 230." },
        { from = 235, to = 265, craft = "Wicked Leather Gauntlets", itemID = 15083, crafts = 37, yellow = 255, grey = 275, makes = 1,
          mats = {
              { itemID = 8170, name = "Rugged Leather", count = 8 },
              { itemID = 2325, name = "Black Dye", count = 1, vendor = true },
              { itemID = 14341, name = "Rune Thread", count = 1, vendor = true },
          },
          learn = "vendor: Leonard Porter, Chillwind Camp, Western Plaguelands",
          note = "Pattern needs 235. Orange to 255, yellow to 265." },
        { from = 265, to = 300, craft = "Runic Leather Headband", itemID = 15094, crafts = 53, yellow = 285, grey = 305, makes = 1,
          mats = {
              { itemID = 8170, name = "Rugged Leather", count = 14 },
              { itemID = 14047, name = "Runecloth", count = 10 },
              { itemID = 14341, name = "Rune Thread", count = 1, vendor = true },
          },
          learn = "vendor: Jase Farlane, Light's Hope Chapel, Eastern Plaguelands",
          note = "Pattern needs 265. Colors estimated: orange to 285, then yellow/green. Untested." },
    },
    trainers = {
        { rank = "Apprentice", name = "Darianna", where = "Craftsmen's Terrace, Darnassus",
          zone = "Darnassus", mapID = 1457, x = 0.646, y = 0.210 },
        { rank = "Journeyman", name = "Faldron", where = "Craftsmen's Terrace, Darnassus",
          zone = "Darnassus", mapID = 1457, x = 0.644, y = 0.216 },
        { rank = "Expert", name = "Telonis", where = "Craftsmen's Terrace, Darnassus",
          zone = "Darnassus", mapID = 1457, x = 0.646, y = 0.215 },
        { rank = "Apprentice", name = "Nadyia Maneweaver", where = "Road outside Darnassus, Teldrassil",
          zone = "Teldrassil", mapID = 1438, x = 0.419, y = 0.496 },
        { rank = "Journeyman", name = "Aayndia Floralwind", where = "Astranaar, Ashenvale",
          zone = "Ashenvale", mapID = 1440, x = 0.359, y = 0.521 },
        { rank = "Apprentice", name = "Randal Worth", where = "Old Town, Stormwind",
          zone = "Stormwind City", mapID = 1453, x = 0.719, y = 0.626 },
        { rank = "Journeyman", name = "Simon Tanner", where = "Old Town, Stormwind",
          zone = "Stormwind City", mapID = 1453, x = 0.719, y = 0.627 },
        { rank = "Apprentice", name = "Gretta Finespindle", where = "Ironforge",
          zone = "Ironforge", mapID = 1455, x = 0.396, y = 0.338 },
        { rank = "Journeyman", name = "Fimble Finespindle", where = "Ironforge",
          zone = "Ironforge", mapID = 1455, x = 0.398, y = 0.335 },
        { rank = "Artisan", name = "Drakk Stonehand", where = "Aerie Peak, The Hinterlands",
          zone = "The Hinterlands", mapID = 1425, x = 0.134, y = 0.434 },
        { rank = "Recipe vendor: Wicked Leather Gauntlets", name = "Leonard Porter", where = "Chillwind Camp, Western Plaguelands",
          zone = "Western Plaguelands", mapID = 1422, x = 0.431, y = 0.843 },
        { rank = "Recipe vendor: Runic Leather Headband", name = "Jase Farlane", where = "Light's Hope Chapel, Eastern Plaguelands",
          zone = "Eastern Plaguelands", mapID = 1423, x = 0.806, y = 0.576 },
    },
    notes = {
        "Apprentice Leatherworking has no level requirement in Forever.",
        "Journeyman: skill 50, level 10. Expert: skill 125, level 20. Artisan: skill 200, level 35.",
        "Thread, dye and salt are sold by leatherworking supply vendors near the trainers.",
        "You need 47 Heavy Hides (cured 130-140) for Barbaric Shoulders and Guardian Gloves.",
        "Buy all leather up to Thick before 200; you need level 35 for Artisan.",
        "Forever recipes turn grey earlier than Classic. 225-300 is untested beta data.",
    },
}
