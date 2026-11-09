-- Blacksmithing leveling path for World of Warcraft: Forever (Alliance).
-- Sources: https://www.wow-professions.com/forever/blacksmithing-leveling-guide
--          https://metabot.gg/en/wow-forever/professions/blacksmithing (Forever skill colors + reagents)
--          https://www.wow-professions.com/forever/npc/magnus-frostwake
--          https://classicdb.ch/?npc=14567 (Derotain Mudsipper coords)
--          https://www.warcrafttavern.com/forever/guides/profession-trainers/ (trainer coords)
--          Item IDs checked on https://classicdb.ch/?item=<id> (wowhead blocked automated reads).
-- Craft counts: each point at skill s succeeds with chance (grey - s) / (grey - yellow), 1 while orange (Forever yellow/grey from metabot.gg). `crafts` is the mean plus 1.28 standard deviations, rounded up: enough about 9 times in 10. Forever's Working Overtime talent (+4% chance per rank) is not counted.
-- Differences from the wow-professions route, following metabot's Forever learn skills:
--   Runed Copper Belt is learned at 80 (not 75), so Runed Copper Gauntlets carry 67-80.
--   Patterned Bronze Bracers are learned at 120, so 95-120 uses Bronze Shortsword + Heavy Grinding Stone.
--   Mithril Coif (orange 205-225) replaces Heavy Mithril Gauntlet 205-210 / Steel Plate Helm / Breastplate.
-- Grinding-stone steps use crafts = max(safe count, stones needed later); the note says which.
-- Learn skills marked as estimates on metabot: Rough/Coarse/Heavy/Solid Grinding Stone, Runed Copper Gauntlets,
-- Bronze Warhammer, Green Iron Bracers, Golden Scale Bracers, Heavy Mithril Gauntlet, Mithril Coif, Dense stones,
-- Heavy Mithril Boots. 225-300 is untested by wow-professions (beta data); Imperial Plate quests may still need
-- Blacksmithing 265 as in Classic - the step notes give the Ebon Shiv / Ornate Thorium Handaxe fallback.
ProfessionGuideData = ProfessionGuideData or {}
ProfessionGuideData[164] = {
    name = "Blacksmithing",
    steps = {
        { from = 1, to = 25, craft = "Rough Sharpening Stone", itemID = 2862, crafts = 27, yellow = 15, grey = 55, makes = 1,
          mats = {
              { itemID = 2835, name = "Rough Stone", count = 1 },
          },
          learn = "auto",
          note = "Buy a Blacksmith Hammer from a trade supplies vendor; you need it from 67 on. Yellow from 15." },
        { from = 25, to = 50, craft = "Rough Grinding Stone", itemID = 3470, crafts = 28, yellow = 45, grey = 85, makes = 1,
          mats = {
              { itemID = 2835, name = "Rough Stone", count = 2 },
          },
          learn = "trainer",
          note = "About 26 crafts reach 50; make 28 for Runed Copper Gauntlets (14 x 2). Train Journeyman at 50." },
        { from = 50, to = 67, craft = "Coarse Grinding Stone", itemID = 3478, crafts = 58, yellow = 50, grey = 75, makes = 1,
          mats = {
              { itemID = 2836, name = "Coarse Stone", count = 2 },
          },
          learn = "trainer",
          note = "About 34 crafts reach 67. Make 58 in total for Patterned Bronze Bracers (29 x 2)." },
        { from = 67, to = 80, craft = "Runed Copper Gauntlets", itemID = 3472, crafts = 14, yellow = 75, grey = 115, makes = 1,
          mats = {
              { itemID = 2840, name = "Copper Bar", count = 8 },
              { itemID = 3470, name = "Rough Grinding Stone", count = 2 },
          },
          learn = "trainer",
          note = "Grinding stones from 25-50. Yellow from 75. Needs Journeyman. If the trainer offers Runed Copper Belt at 75, switch then." },
        { from = 80, to = 95, craft = "Runed Copper Belt", itemID = 2857, crafts = 18, yellow = 85, grey = 125, makes = 1,
          mats = {
              { itemID = 2840, name = "Copper Bar", count = 10 },
          },
          learn = "trainer",
          note = "Learned at 80 in Forever. Yellow from 85." },
        { from = 95, to = 100, craft = "Bronze Shortsword", itemID = 2850, crafts = 5, yellow = 125, grey = 155, makes = 1,
          mats = {
              { itemID = 2841, name = "Bronze Bar", count = 5 },
              { itemID = 2880, name = "Weak Flux", count = 4, vendor = true },
              { itemID = 2319, name = "Medium Leather", count = 2 },
          },
          learn = "trainer",
          note = "Weak Flux is sold by blacksmithing supply vendors next to the trainers." },
        { from = 100, to = 112, craft = "Heavy Grinding Stone", itemID = 3486, crafts = 40, yellow = 100, grey = 125, makes = 1,
          mats = {
              { itemID = 2838, name = "Heavy Stone", count = 3 },
          },
          learn = "trainer",
          note = "About 20 crafts reach 112. Make 40 for Golden Scale Bracers (180-195, 20 x 2)." },
        { from = 112, to = 120, craft = "Bronze Shortsword", itemID = 2850, crafts = 8, yellow = 125, grey = 155, makes = 1,
          mats = {
              { itemID = 2841, name = "Bronze Bar", count = 5 },
              { itemID = 2880, name = "Weak Flux", count = 4, vendor = true },
              { itemID = 2319, name = "Medium Leather", count = 2 },
          },
          learn = "trainer",
          note = "Still orange until 125." },
        { from = 120, to = 140, craft = "Patterned Bronze Bracers", itemID = 2868, crafts = 29, yellow = 125, grey = 155, makes = 1,
          mats = {
              { itemID = 2841, name = "Bronze Bar", count = 5 },
              { itemID = 3478, name = "Coarse Grinding Stone", count = 2 },
          },
          learn = "trainer",
          note = "Learned at 120 in Forever. Yellow from 125. Grinding stones from 50-67. Train Expert at 125 (level 20)." },
        { from = 140, to = 170, craft = "Bronze Warhammer", itemID = 7956, crafts = 39, yellow = 155, grey = 185, makes = 1,
          mats = {
              { itemID = 2841, name = "Bronze Bar", count = 8 },
              { itemID = 3466, name = "Strong Flux", count = 1, vendor = true },
              { itemID = 2319, name = "Medium Leather", count = 1 },
          },
          learn = "trainer",
          note = "Expert recipe (Bengus Deepforge, Ironforge). Yellow from 155." },
        { from = 170, to = 175, craft = "Green Iron Bracers", itemID = 3835, crafts = 10, yellow = 165, grey = 190, makes = 1,
          mats = {
              { itemID = 3575, name = "Iron Bar", count = 6 },
              { itemID = 2605, name = "Green Dye", count = 1, vendor = true },
          },
          learn = "trainer",
          note = "Green Dye: Bombus Finespindle (Ironforge) or other leatherworking/tailoring supply vendors." },
        { from = 175, to = 180, craft = "Solid Grinding Stone", itemID = 7966, crafts = 9, yellow = 175, grey = 185, makes = 1,
          mats = {
              { itemID = 7912, name = "Solid Stone", count = 4 },
          },
          learn = "trainer",
          note = "Already yellow (green at 180)." },
        { from = 180, to = 195, craft = "Golden Scale Bracers", itemID = 6040, crafts = 20, yellow = 185, grey = 210, makes = 1,
          mats = {
              { itemID = 3859, name = "Steel Bar", count = 5 },
              { itemID = 3486, name = "Heavy Grinding Stone", count = 2 },
          },
          learn = "trainer",
          note = "Grinding stones from 100-112. Steel Bar: Mining 165 smelts Iron Bar + Coal (Coal sold by BS vendors)." },
        { from = 195, to = 205, craft = "Heavy Mithril Gauntlet", itemID = 7919, crafts = 12, yellow = 200, grey = 220, makes = 1,
          mats = {
              { itemID = 3860, name = "Mithril Bar", count = 6 },
              { itemID = 4338, name = "Mageweave Cloth", count = 4 },
          },
          learn = "trainer",
          note = "Yellow from 200. At 200 (level 35) get Artisan from Brikk Keencraft, Booty Bay, before 225." },
        { from = 205, to = 225, craft = "Mithril Coif", itemID = 7931, crafts = 20, yellow = 225, grey = 245, makes = 1,
          mats = {
              { itemID = 3860, name = "Mithril Bar", count = 10 },
              { itemID = 4338, name = "Mageweave Cloth", count = 6 },
          },
          learn = "trainer",
          note = "Orange to 225. If not offered yet, use Heavy Mithril Gauntlet to 210 then Heavy Mithril Boots." },
        { from = 225, to = 230, craft = "Dense Sharpening Stone", itemID = 12404, crafts = 5, yellow = 230, grey = 235, makes = 1,
          mats = {
              { itemID = 12365, name = "Dense Stone", count = 1 },
          },
          learn = "trainer",
          note = "Needs Artisan. Heavy Mithril Boots also stay orange to 230." },
        { from = 230, to = 240, craft = "Heavy Mithril Boots", itemID = 7933, crafts = 17, yellow = 230, grey = 250, makes = 1,
          mats = {
              { itemID = 3860, name = "Mithril Bar", count = 14 },
              { itemID = 4304, name = "Thick Leather", count = 4 },
          },
          learn = "trainer",
          note = "Yellow 230-240. Meanwhile gather ~2000 Thorium Bars and Star Rubies for 240-300." },
        { from = 240, to = 245, craft = "Imperial Plate Belt", itemID = 12424, crafts = 5, yellow = 260, grey = 280, makes = 1,
          mats = {
              { itemID = 12359, name = "Thorium Bar", count = 22 },
              { itemID = 8170, name = "Rugged Leather", count = 6 },
              { itemID = 7909, name = "Aquamarine", count = 1 },
          },
          learn = "drop/quest: Derotain Mudsipper, Gadgetzan, Tanaris (quest, level 50, 20 Thorium Bar)",
          note = "Untested: quest may still need skill 265. Fallback: Ebon Shiv 240-255 (Magnus Frostwake, WPL)." },
        { from = 245, to = 270, craft = "Imperial Plate Bracers", itemID = 12425, crafts = 27, yellow = 265, grey = 285, makes = 1,
          mats = {
              { itemID = 12359, name = "Thorium Bar", count = 20 },
              { itemID = 7910, name = "Star Ruby", count = 1 },
          },
          learn = "drop/quest: Derotain Mudsipper, Gadgetzan, Tanaris (quest, 20 Thorium Bar)",
          note = "Yellow from 265. Fallback: Ornate Thorium Handaxe 255-270 (Magnus Frostwake, WPL)." },
        { from = 270, to = 290, craft = "Imperial Plate Boots", itemID = 12426, crafts = 20, yellow = 290, grey = 310, makes = 1,
          mats = {
              { itemID = 12359, name = "Thorium Bar", count = 34 },
              { itemID = 7910, name = "Star Ruby", count = 1 },
              { itemID = 7909, name = "Aquamarine", count = 1 },
          },
          learn = "drop/quest: Derotain Mudsipper, Gadgetzan, Tanaris (quest, 40 Thorium Bar)",
          note = "Orange 270-290. Imperial Plate Helm (34 Thorium, 2 Star Ruby) has the same range." },
        { from = 290, to = 300, craft = "Imperial Plate Leggings", itemID = 12429, crafts = 10, yellow = 300, grey = 320, makes = 1,
          mats = {
              { itemID = 12359, name = "Thorium Bar", count = 44 },
              { itemID = 7910, name = "Star Ruby", count = 2 },
          },
          learn = "drop/quest: Derotain Mudsipper, Gadgetzan, Tanaris (quest, 60 Thorium Bar)",
          note = "Learned at 280, orange to 300." },
    },
    trainers = {
        { rank = "Apprentice", name = "Delfrum Flintbeard", where = "Auberdine, Darkshore",
          zone = "Darkshore", mapID = 1439, x = 0.382, y = 0.410 },
        { rank = "Apprentice", name = "Dane Lindgren", where = "Dwarven District, Stormwind",
          zone = "Stormwind City", mapID = 1453, x = 0.638, y = 0.372 },
        { rank = "Journeyman", name = "Therum Deepforge", where = "Dwarven District, Stormwind",
          zone = "Stormwind City", mapID = 1453, x = 0.634, y = 0.370 },
        { rank = "Apprentice", name = "Groum Stonebeard", where = "The Great Forge, Ironforge",
          zone = "Ironforge", mapID = 1455, x = 0.522, y = 0.414 },
        { rank = "Journeyman", name = "Rotgath Stonebeard", where = "The Great Forge, Ironforge",
          zone = "Ironforge", mapID = 1455, x = 0.512, y = 0.432 },
        { rank = "Expert", name = "Bengus Deepforge", where = "The Great Forge, Ironforge",
          zone = "Ironforge", mapID = 1455, x = 0.516, y = 0.424 },
        { rank = "Journeyman", name = "Clarise Gnarltree", where = "Darkshire, Duskwood",
          zone = "Duskwood", mapID = 1431, x = 0.740, y = 0.481 },
        { rank = "Artisan", name = "Brikk Keencraft", where = "Booty Bay, Stranglethorn Vale",
          zone = "Stranglethorn Vale", mapID = 1434, x = 0.290, y = 0.755 },
        { rank = "Recipe quests: Imperial Plate", name = "Derotain Mudsipper", where = "Gadgetzan, Tanaris",
          zone = "Tanaris", mapID = 1446, x = 0.514, y = 0.287 },
        { rank = "Recipe vendor: Ebon Shiv, Ornate Thorium Handaxe", name = "Magnus Frostwake", where = "House in Caer Darrow (ghost: needs Spectral Essence)",
          zone = "Western Plaguelands", mapID = 1422, x = 0.68, y = 0.77 },
    },
    notes = {
        "Apprentice Blacksmithing has no level requirement in Forever.",
        "Journeyman: skill 50, level 10. Expert: skill 125, level 20. Artisan: skill 200, level 35.",
        "No Blacksmithing trainer in Darnassus: use Auberdine, Stormwind or Ironforge.",
        "Flux and Coal are sold by blacksmithing supply vendors.",
        "Imperial Plate quests (Gadgetzan) need level 50 and Thorium Bars: 20/20/40/60.",
        "Forever recipes turn grey earlier than Classic past 225. 225-300 is untested beta data.",
    },
}
