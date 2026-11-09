-- Cooking leveling path for World of Warcraft: Forever (Alliance, Night Elf start).
-- Sources: https://www.warcrafttavern.com/forever/guides/cooking-leveling/ (route, rank requirements)
--          https://www.wow-professions.com/forever/cooking-leveling-guide (alternatives, recipe vendors)
--          https://metabot.gg/en/wow-forever/professions/cooking (Forever skill colors + reagents)
--          https://www.wow-professions.com/forever/npc/<name> (vendor coords from the TomTom pins)
--          https://www.warcrafttavern.com/forever/guides/profession-trainers/ (trainer coords)
--          Item IDs checked on https://classicdb.ch/?item=<id> (wowhead blocked automated reads).
-- Craft counts: each point at skill s succeeds with chance (grey - s) / (grey - yellow), 1 while orange (Forever yellow/grey from metabot.gg). `crafts` is the mean plus 1.28 standard deviations, rounded up: enough about 9 times in 10. Forever's Working Overtime talent (+4% chance per rank) is not counted.
-- Forever skill colors match Classic for every recipe used here (e.g. Brilliant Smallfish 1/45/65/85).
-- Fish-based route: all raw fish come from Fishing (or the Auction House), so level Fishing alongside.
-- 225-300 is marked untested by wow-professions (beta data). Filet of Redgill stays orange to 265, so the
-- 225-250 / 250-300 split could also be 225-265 / 265-300.
ProfessionGuideData = ProfessionGuideData or {}
ProfessionGuideData[185] = {
    name = "Cooking",
    steps = {
        { from = 1, to = 50, craft = "Brilliant Smallfish", itemID = 6290, crafts = 50, yellow = 45, grey = 85, makes = 1,
          mats = {
              { itemID = 6291, name = "Raw Brilliant Smallfish", count = 1 },
          },
          learn = "vendor: Nyoma, Dolanaar, Teldrassil (or Catherine Leland, Stormwind; Tharynn Bouden, Goldshire)",
          note = "Slitherskin Mackerel (Nessa Shadowsong, Rut'theran) has the same colors. Train Journeyman at 50." },
        { from = 50, to = 100, craft = "Longjaw Mud Snapper", itemID = 4592, crafts = 53, yellow = 90, grey = 130, makes = 1,
          mats = {
              { itemID = 6289, name = "Raw Longjaw Mud Snapper", count = 1 },
          },
          learn = "vendor: Nyoma, Dolanaar, Teldrassil (or Tansy Puddlefizz, Ironforge)",
          note = "Yellow from 90. Rainbow Fin Albacore (Nessa Shadowsong or Heldan Galesong) works the same." },
        { from = 100, to = 150, craft = "Bristle Whisker Catfish", itemID = 4593, crafts = 53, yellow = 140, grey = 180, makes = 1,
          mats = {
              { itemID = 6308, name = "Raw Bristle Whisker Catfish", count = 1 },
          },
          learn = "vendor: Catherine Leland, Canals, Stormwind City",
          note = "Yellow from 140. At 125 (level 20) buy the Expert Cookbook from Shandrina, Ashenvale." },
        { from = 150, to = 175, craft = "Curiously Tasty Omelet", itemID = 3665, crafts = 26, yellow = 170, grey = 210, makes = 1,
          mats = {
              { itemID = 3685, name = "Raptor Egg", count = 1 },
              { itemID = 2692, name = "Hot Spices", count = 1, vendor = true },
          },
          learn = "vendor: Kendor Kabonka, Pig and Whistle (upstairs), Old Town, Stormwind City",
          note = "Yellow from 170. Raptor Eggs drop from raptors in Wetlands, Arathi and Stranglethorn." },
        { from = 175, to = 225, craft = "Mithril Head Trout", itemID = 8364, crafts = 53, yellow = 215, grey = 255, makes = 1,
          mats = {
              { itemID = 8365, name = "Raw Mithril Head Trout", count = 1 },
          },
          learn = "vendor: Heldan Galesong, south of Auberdine, Darkshore (or Tansy Puddlefizz, Ironforge)",
          note = "Yellow from 215. Heldan stands in tall grass on a hill above the shore." },
        { from = 225, to = 250, craft = "Filet of Redgill", itemID = 13930, crafts = 25, yellow = 265, grey = 305, makes = 1,
          mats = {
              { itemID = 13758, name = "Raw Redgill", count = 1 },
          },
          learn = "vendor: Kelsey Yance, Booty Bay, Stranglethorn Vale",
          note = "Needs Artisan: Clamlette Surprise quest (level 35, skill 225), Dirge Quikcleave, Gadgetzan." },
        { from = 250, to = 300, craft = "Poached Sunscale Salmon", itemID = 13932, crafts = 53, yellow = 290, grey = 330, makes = 1,
          mats = {
              { itemID = 13760, name = "Raw Sunscale Salmon", count = 1 },
          },
          learn = "vendor: Gikkix, Steamwheedle Port, Tanaris",
          note = "Yellow from 290. Nightfin Soup (Gikkix) has the same colors." },
    },
    trainers = {
        { rank = "Apprentice-Journeyman", name = "Alegorn", where = "Darnassus",
          zone = "Darnassus", mapID = 1457, x = 0.489, y = 0.213 },
        { rank = "Apprentice-Journeyman", name = "Zarrin", where = "Dolanaar, Teldrassil",
          zone = "Teldrassil", mapID = 1438, x = 0.571, y = 0.612 },
        { rank = "Recipe vendor: Brilliant Smallfish, Longjaw Mud Snapper", name = "Nyoma", where = "Dolanaar, Teldrassil",
          zone = "Teldrassil", mapID = 1438, x = 0.572, y = 0.612 },
        { rank = "Recipe vendor: Slitherskin Mackerel, Rainbow Fin Albacore", name = "Nessa Shadowsong",
          where = "Rut'theran Village, Teldrassil", zone = "Teldrassil", mapID = 1438, x = 0.562, y = 0.924 },
        { rank = "Recipe vendor: Mithril Head Trout, Rainbow Fin Albacore", name = "Heldan Galesong",
          where = "Twilight Shore, south of Auberdine, Darkshore", zone = "Darkshore", mapID = 1439, x = 0.370, y = 0.563 },
        { rank = "Apprentice-Journeyman", name = "Stephen Ryback", where = "Old Town, Stormwind",
          zone = "Stormwind City", mapID = 1453, x = 0.783, y = 0.531 },
        { rank = "Recipe vendor: Bristle Whisker Catfish, Brilliant Smallfish", name = "Catherine Leland",
          where = "Canals, Stormwind", zone = "Stormwind City", mapID = 1453, x = 0.550, y = 0.696 },
        { rank = "Recipe vendor: Curiously Tasty Omelet", name = "Kendor Kabonka",
          where = "Pig and Whistle (upstairs), Old Town, Stormwind", zone = "Stormwind City", mapID = 1453, x = 0.773, y = 0.529 },
        { rank = "Apprentice-Journeyman", name = "Tomas", where = "Goldshire, Elwynn Forest",
          zone = "Elwynn Forest", mapID = 1429, x = 0.443, y = 0.660 },
        { rank = "Recipe vendor: Brilliant Smallfish, Longjaw Mud Snapper", name = "Tharynn Bouden",
          where = "Goldshire, Elwynn Forest", zone = "Elwynn Forest", mapID = 1429, x = 0.419, y = 0.671 },
        { rank = "Apprentice-Journeyman", name = "Daryl Riknussun", where = "Ironforge",
          zone = "Ironforge", mapID = 1455, x = 0.604, y = 0.381 },
        { rank = "Recipe vendor: Longjaw Mud Snapper, Mithril Head Trout", name = "Tansy Puddlefizz",
          where = "The Forlorn Cavern, Ironforge", zone = "Ironforge", mapID = 1455, x = 0.479, y = 0.056 },
        { rank = "Expert (Expert Cookbook)", name = "Shandrina", where = "Mystral Lake (Silverwind Refuge), Ashenvale",
          zone = "Ashenvale", mapID = 1440, x = 0.495, y = 0.671 },
        { rank = "Recipe vendor: Filet of Redgill", name = "Kelsey Yance", where = "Booty Bay, Stranglethorn Vale",
          zone = "Stranglethorn Vale", mapID = 1434, x = 0.282, y = 0.744 },
        { rank = "Artisan (quest: Clamlette Surprise)", name = "Dirge Quikcleave", where = "Gadgetzan inn, Tanaris",
          zone = "Tanaris", mapID = 1446, x = 0.526, y = 0.281 },
        { rank = "Recipe vendor: Poached Sunscale Salmon, Nightfin Soup", name = "Gikkix",
          where = "Steamwheedle Port, Tanaris", zone = "Tanaris", mapID = 1446, x = 0.667, y = 0.222 },
    },
    notes = {
        "Apprentice: no level needed. Journeyman: trainer at 50 (learn before 75).",
        "Expert: Expert Cookbook from Shandrina (Ashenvale), skill 125, level 20.",
        "Artisan: quest Clamlette Surprise, skill 225, level 35. Start with I Know A Guy... (Daryl Riknussun, Ironforge).",
        "Bring 12 Giant Egg, 10 Zesty Clam Meat, 20 Alterac Swiss to Dirge Quikcleave in Gadgetzan.",
        "Forever: cook on a campfire from the Basic Campfire Kit (Simple Wood + Flint and Tinder from vendors).",
        "Spices are sold by Cooking Supply vendors near every trainer.",
        "Night Elf meat options: Kaldorei Spider Kabob (quest from Zarrin), Smoked Bear Meat, Boiled Clams.",
        "All raw fish here are caught while leveling Fishing; buy extra on the Auction House if short.",
    },
}
