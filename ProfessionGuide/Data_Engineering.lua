-- Engineering leveling path for World of Warcraft: Forever (Alliance).
-- Sources: https://www.wow-professions.com/forever/engineering-leveling-guide
--          https://metabot.gg/en/wow-forever/professions/engineering (Forever skill colors + reagents)
--          https://www.wow-professions.com/forever/npc/gearcutter-cogspinner
--          https://www.wow-professions.com/forever/npc/xizzer-fizzbolt
--          https://warcraft.wiki.gg/wiki/Xizzer_Fizzbolt (coords)
--          https://www.warcrafttavern.com/forever/guides/profession-trainers/ (trainer coords)
--          Item IDs checked on https://classicdb.ch/?item=<id> (wowhead blocked automated reads).
-- Craft counts: each point at skill s succeeds with chance (grey - s) / (grey - yellow), 1 while orange (Forever yellow/grey from metabot.gg). `crafts` is the mean plus 1.28 standard deviations, rounded up: enough about 9 times in 10. Forever's Working Overtime talent (+4% chance per rank) is not counted.
-- Route follows wow-professions. Intermediate-part steps use crafts = max(safe count, stock needed) and list extra
-- crafts (beyond what the skill needs) to stock parts used later (bolts, powders, tubes, gizmos, casings).
-- metabot learn skills for most recipes are estimates (yellow minus 5); the Classic learn skills
-- (e.g. Copper Bolts 30, Spanner 50, Rough Copper Bomb 30, Explosive Sheep 150) are what the route assumes.
-- "makes" values follow metabot (Rough Copper Bomb 2, Coarse Dynamite 2, Silver Contact 5, Hi-Explosive Bomb 4).
-- 225-300 is untested by wow-professions (beta data). Gearcutter Cogspinner coords checked Nov 2026 (Classic guide).
ProfessionGuideData = ProfessionGuideData or {}
ProfessionGuideData[202] = {
    name = "Engineering",
    steps = {
        { from = 1, to = 30, craft = "Rough Blasting Powder", itemID = 4357, crafts = 66, yellow = 20, grey = 40, makes = 1,
          mats = {
              { itemID = 2835, name = "Rough Stone", count = 1 },
          },
          learn = "auto",
          note = "Buy a Blacksmith Hammer first. About 36 crafts reach 30 (yellow from 20); make 66 for Rough Copper Bombs (51-75)." },
        { from = 30, to = 50, craft = "Handful of Copper Bolts", itemID = 4359, crafts = 33, yellow = 45, grey = 60, makes = 1,
          mats = {
              { itemID = 2840, name = "Copper Bar", count = 1 },
          },
          learn = "trainer",
          note = "About 23 crafts reach 50 (yellow from 45). Make 33 for Rough Copper Bombs." },
        { from = 50, to = 51, craft = "Arclight Spanner", itemID = 6219, crafts = 1, yellow = 70, grey = 90, makes = 1,
          mats = {
              { itemID = 2840, name = "Copper Bar", count = 6 },
          },
          learn = "trainer",
          note = "Keep the spanner: later recipes need it. Train Journeyman now (skill 50, level 10)." },
        { from = 51, to = 75, craft = "Rough Copper Bomb", itemID = 4360, crafts = 33, yellow = 60, grey = 90, makes = 2,
          mats = {
              { itemID = 2840, name = "Copper Bar", count = 1 },
              { itemID = 4359, name = "Handful of Copper Bolts", count = 1 },
              { itemID = 4357, name = "Rough Blasting Powder", count = 2 },
              { itemID = 2589, name = "Linen Cloth", count = 1 },
          },
          learn = "trainer",
          note = "Bolts and powder from 1-50. Orange to 60, yellow 60-75." },
        { from = 75, to = 90, craft = "Coarse Blasting Powder", itemID = 4364, crafts = 60, yellow = 85, grey = 95, makes = 1,
          mats = {
              { itemID = 2836, name = "Coarse Stone", count = 1 },
          },
          learn = "trainer",
          note = "About 19 crafts reach 90 (yellow from 85). Make 60 for Coarse Dynamite." },
        { from = 90, to = 100, craft = "Coarse Dynamite", itemID = 4365, crafts = 20, yellow = 90, grey = 105, makes = 2,
          mats = {
              { itemID = 4364, name = "Coarse Blasting Powder", count = 3 },
              { itemID = 2589, name = "Linen Cloth", count = 1 },
          },
          learn = "trainer",
          note = "Powder from 75-90. Yellow to 98, then green." },
        { from = 100, to = 105, craft = "Silver Contact", itemID = 4404, crafts = 5, yellow = 110, grey = 140, makes = 5,
          mats = {
              { itemID = 2842, name = "Silver Bar", count = 1 },
          },
          learn = "trainer",
          note = "Orange to 110. Alternative: Flying Tiger Goggles (6 Light Leather, 2 Tigerseye)." },
        { from = 105, to = 125, craft = "Bronze Tube", itemID = 4371, crafts = 39, yellow = 105, grey = 155, makes = 1,
          mats = {
              { itemID = 2841, name = "Bronze Bar", count = 2 },
              { itemID = 2880, name = "Weak Flux", count = 1, vendor = true },
          },
          learn = "trainer",
          note = "Yellow. About 29 crafts reach 125; make 39 to keep 10 for Standard Scope. Train Expert at 125 (level 20, 50s)." },
        { from = 125, to = 135, craft = "Standard Scope", itemID = 4406, crafts = 10, yellow = 135, grey = 160, makes = 1,
          mats = {
              { itemID = 4371, name = "Bronze Tube", count = 1 },
              { itemID = 1206, name = "Moss Agate", count = 1 },
          },
          learn = "trainer",
          note = "Tubes from 105-125. Orange to 135. No Moss Agate? Make Heavy Blasting Powder (yellow 125-135) instead." },
        { from = 135, to = 140, craft = "Heavy Blasting Powder", itemID = 4377, crafts = 30, yellow = 125, grey = 145, makes = 1,
          mats = {
              { itemID = 2838, name = "Heavy Stone", count = 1 },
          },
          learn = "trainer",
          note = "Green here: about 19 crafts reach 140. Make 30, needed for Explosive Sheep (160-175)." },
        { from = 140, to = 150, craft = "Whirring Bronze Gizmo", itemID = 4375, crafts = 21, yellow = 125, grey = 175, makes = 1,
          mats = {
              { itemID = 2841, name = "Bronze Bar", count = 2 },
              { itemID = 2592, name = "Wool Cloth", count = 1 },
          },
          learn = "trainer",
          note = "Yellow. Keep 15 for Explosive Sheep. You need Expert before passing 150." },
        { from = 150, to = 160, craft = "Bronze Framework", itemID = 4382, crafts = 15, yellow = 145, grey = 195, makes = 1,
          mats = {
              { itemID = 2841, name = "Bronze Bar", count = 2 },
              { itemID = 2319, name = "Medium Leather", count = 1 },
              { itemID = 2592, name = "Wool Cloth", count = 1 },
          },
          learn = "trainer",
          note = "Yellow. Keep all 15 for Explosive Sheep." },
        { from = 160, to = 175, craft = "Explosive Sheep", itemID = 4384, crafts = 15, yellow = 175, grey = 200, makes = 1,
          mats = {
              { itemID = 4382, name = "Bronze Framework", count = 1 },
              { itemID = 4375, name = "Whirring Bronze Gizmo", count = 1 },
              { itemID = 4377, name = "Heavy Blasting Powder", count = 2 },
              { itemID = 2592, name = "Wool Cloth", count = 2 },
          },
          learn = "trainer",
          note = "Parts from 135-160. Orange to 175. Keep 5 sheep if you plan Goblin Engineering." },
        { from = 175, to = 194, craft = "Solid Blasting Powder", itemID = 10505, crafts = 70, yellow = 175, grey = 195, makes = 1,
          mats = {
              { itemID = 7912, name = "Solid Stone", count = 2 },
          },
          learn = "trainer",
          note = "Yellow to 185, then green. Keep 60: 22 for triggers, 38 for Hi-Explosive Bombs." },
        { from = 194, to = 195, craft = "Gyromatic Micro-Adjustor", itemID = 10498, crafts = 4, yellow = 175, grey = 215, makes = 1,
          mats = {
              { itemID = 3859, name = "Steel Bar", count = 4 },
          },
          learn = "trainer",
          note = "Yellow. Keep one: it is a tool for later recipes." },
        { from = 195, to = 200, craft = "Mithril Tube", itemID = 10559, crafts = 6, yellow = 195, grey = 235, makes = 1,
          mats = {
              { itemID = 3860, name = "Mithril Bar", count = 3 },
          },
          learn = "trainer",
          note = "Yellow. Keep the 6 tubes for Gnomish Engineering. At 200 (level 35) train Artisan: Buzzek Bracketswing, Gadgetzan." },
        { from = 200, to = 215, craft = "Unstable Trigger", itemID = 10560, crafts = 22, yellow = 200, grey = 240, makes = 1,
          mats = {
              { itemID = 3860, name = "Mithril Bar", count = 1 },
              { itemID = 4338, name = "Mageweave Cloth", count = 1 },
              { itemID = 10505, name = "Solid Blasting Powder", count = 1 },
          },
          learn = "trainer",
          note = "Powder from 175-194. Yellow. Keep 19 triggers for Hi-Explosive Bombs." },
        { from = 215, to = 238, craft = "Mithril Casing", itemID = 10561, crafts = 40, yellow = 215, grey = 255, makes = 1,
          mats = {
              { itemID = 3860, name = "Mithril Bar", count = 3 },
          },
          learn = "trainer",
          note = "Yellow to 235, then green. Keep 38 for Hi-Explosive Bombs. Needs Artisan before 225." },
        { from = 238, to = 250, craft = "Hi-Explosive Bomb", itemID = 10562, crafts = 19, yellow = 235, grey = 275, makes = 4,
          mats = {
              { itemID = 10561, name = "Mithril Casing", count = 2 },
              { itemID = 10560, name = "Unstable Trigger", count = 1 },
              { itemID = 10505, name = "Solid Blasting Powder", count = 2 },
          },
          learn = "trainer",
          note = "Parts from 175-238. Yellow to 255." },
        { from = 250, to = 260, craft = "Dense Blasting Powder", itemID = 15992, crafts = 44, yellow = 250, grey = 260, makes = 1,
          mats = {
              { itemID = 12365, name = "Dense Stone", count = 2 },
          },
          learn = "trainer",
          note = "Yellow 250-255, green after: slow (88 Dense Stone). Hi-Explosive Bombs (yellow to 255) are an option." },
        { from = 260, to = 285, craft = "Thorium Widget", itemID = 15994, crafts = 27, yellow = 280, grey = 300, makes = 1,
          mats = {
              { itemID = 12359, name = "Thorium Bar", count = 3 },
              { itemID = 14047, name = "Runecloth", count = 1 },
          },
          learn = "vendor: Gearcutter Cogspinner, Tinker Town, Ironforge",
          note = "Orange to 280, yellow 280-290." },
        { from = 285, to = 300, craft = "Thorium Tube", itemID = 16000, crafts = 17, yellow = 295, grey = 315, makes = 1,
          mats = {
              { itemID = 12359, name = "Thorium Bar", count = 6 },
          },
          learn = "vendor: Xizzer Fizzbolt, Everlook, Winterspring",
          note = "Schematic is bind on pickup in Forever: buy it on this character. Orange to 295, then yellow." },
    },
    trainers = {
        { rank = "Apprentice", name = "Jenna Lemkenilli", where = "Auberdine, Darkshore",
          zone = "Darkshore", mapID = 1439, x = 0.381, y = 0.410 },
        { rank = "Apprentice", name = "Sprite Jumpsprocket", where = "Dwarven District, Stormwind",
          zone = "Stormwind City", mapID = 1453, x = 0.620, y = 0.307 },
        { rank = "Journeyman", name = "Lilliam Sparkspindle", where = "Dwarven District, Stormwind",
          zone = "Stormwind City", mapID = 1453, x = 0.620, y = 0.306 },
        { rank = "Apprentice", name = "Jemma Quikswitch", where = "Tinker Town, Ironforge",
          zone = "Ironforge", mapID = 1455, x = 0.680, y = 0.445 },
        { rank = "Journeyman", name = "Trixie Quikswitch", where = "Tinker Town, Ironforge",
          zone = "Ironforge", mapID = 1455, x = 0.682, y = 0.442 },
        { rank = "Expert", name = "Springspindle Fizzlegear", where = "Tinker Town, Ironforge",
          zone = "Ironforge", mapID = 1455, x = 0.688, y = 0.452 },
        { rank = "Apprentice", name = "Bronk Guzzlegear", where = "Steelgrill's Depot, Kharanos, Dun Morogh",
          zone = "Dun Morogh", mapID = 1426, x = 0.503, y = 0.504 },
        { rank = "Journeyman", name = "Finbus Geargrind", where = "Darkshire, Duskwood",
          zone = "Duskwood", mapID = 1431, x = 0.775, y = 0.486 },
        { rank = "Artisan", name = "Buzzek Bracketswing", where = "Gadgetzan, Tanaris (outside the inn)",
          zone = "Tanaris", mapID = 1446, x = 0.522, y = 0.276 },
        -- https://www.wowhead.com/classic/guide/engineering-vendor-recipes-wow-classic (/way 68.2, 44.2)
        { rank = "Recipe vendor: Thorium Widget", name = "Gearcutter Cogspinner", where = "Tinker Town, Ironforge",
          zone = "Ironforge", mapID = 1455, x = 0.682, y = 0.442 },
        { rank = "Recipe vendor: Thorium Tube", name = "Xizzer Fizzbolt", where = "Everlook, Winterspring (first building on the right)",
          zone = "Winterspring", mapID = 1452, x = 0.610, y = 0.390 },
    },
    notes = {
        "Apprentice Engineering has no level requirement in Forever.",
        "Journeyman: skill 50, level 10. Expert: skill 125, level 20, 50s. Artisan: skill 200, level 35.",
        "No Engineering trainer in Darnassus: use Auberdine, Stormwind or Ironforge.",
        "Most recipes need a Blacksmith Hammer (trade supplies vendors). Keep the Arclight Spanner and Gyromatic Micro-Adjustor.",
        "Weak Flux is sold by engineering/blacksmithing supply vendors.",
        "Specialize at 200 (level 30): Gnomish or Goblin. Keep 6 Mithril Tubes (Gnomish) or 5 Explosive Sheep (Goblin).",
        "Forever: no Gnome +15 racial; specialization makes devices fail 20% less often.",
        "225-300 is untested beta data.",
    },
}
