-- Alchemy leveling path for World of Warcraft: Forever (Alliance).
-- Sources: https://www.wow-professions.com/forever/alchemy-leveling-guide
--          https://metabot.gg/en/wow-forever/professions/alchemy (Forever skill colors + reagents)
--          https://wow.gg/professions/forever/alchemy (learn skills, recipe vendors)
--          https://www.wow-professions.com/forever/npc/ulthir, .../npc/logannas, .../npc/maria-lumere
--          https://warcraft.wiki.gg/wiki/Minor_Arcane_Elixir, https://warcraft.wiki.gg/wiki/Draught_of_Detect_Undead
--          https://www.warcrafttavern.com/forever/guides/profession-trainers/ (trainer coords)
--          Item IDs checked on https://classicdb.ch/?item=<id> (wowhead blocked automated reads).
-- Craft counts: each point at skill s succeeds with chance (grey - s) / (grey - yellow), 1 while orange (Forever yellow/grey from metabot.gg). `crafts` is the mean plus 1.28 standard deviations, rounded up: enough about 9 times in 10. Forever's Working Overtime talent (+4% chance per rank) is not counted.
-- Healing potions moved to First Aid in Forever, so they are not used here.
-- Minor Arcane Elixir is Forever-only: itemID 247754, confirmed at https://www.wowhead.com/forever/item=247754. wow.gg lists it as a skill-10 trainer recipe while metabot/wiki say learned at 1;
-- the step note gives the fallback.
-- Draught of Detect Undead is the Forever name of Elixir of Detect Undead (item 9154) per warcraft.wiki.gg.
-- 225-300 is marked untested by wow-professions (beta data). Vendor coords for Logannas and Maria Lumere checked Nov 2026.
ProfessionGuideData = ProfessionGuideData or {}
ProfessionGuideData[171] = {
    name = "Alchemy",
    steps = {
        { from = 1, to = 10, craft = "Minor Arcane Elixir", itemID = 247754, crafts = 9, yellow = 10, grey = 15, makes = 1,
          mats = {
              { itemID = 2447, name = "Peacebloom", count = 1 },
              { itemID = 3371, name = "Empty Vial", count = 1, vendor = true },
          },
          learn = "auto",
          note = "Elixir of Minor Force (Silverleaf) works too. If you lack both, start Elixir of Minor Defense at 1." },
        { from = 10, to = 55, craft = "Elixir of Minor Defense", itemID = 5997, crafts = 45, yellow = 55, grey = 95, makes = 1,
          mats = {
              { itemID = 765, name = "Silverleaf", count = 1 },
              { itemID = 2447, name = "Peacebloom", count = 1 },
              { itemID = 3371, name = "Empty Vial", count = 1, vendor = true },
          },
          learn = "auto",
          note = "At 50 (and level 10) train Journeyman before you pass 75." },
        { from = 55, to = 65, craft = "Minor Mana Potion", itemID = 2455, crafts = 10, yellow = 65, grey = 105, makes = 1,
          mats = {
              { itemID = 785, name = "Mageroyal", count = 1 },
              { itemID = 2447, name = "Peacebloom", count = 1 },
              { itemID = 3371, name = "Empty Vial", count = 1, vendor = true },
          },
          learn = "trainer" },
        { from = 65, to = 90, craft = "Elixir of Minor Fortitude", itemID = 2458, crafts = 28, yellow = 80, grey = 120, makes = 1,
          mats = {
              { itemID = 2449, name = "Earthroot", count = 2 },
              { itemID = 2447, name = "Peacebloom", count = 1 },
              { itemID = 3371, name = "Empty Vial", count = 1, vendor = true },
          },
          learn = "trainer",
          note = "Yellow from 80, so the last 10 points take extra crafts." },
        { from = 90, to = 120, craft = "Elixir of Wisdom", itemID = 3383, crafts = 30, yellow = 120, grey = 160, makes = 1,
          mats = {
              { itemID = 785, name = "Mageroyal", count = 1 },
              { itemID = 2450, name = "Briarthorn", count = 2 },
              { itemID = 3371, name = "Empty Vial", count = 1, vendor = true },
          },
          learn = "trainer",
          note = "Learnable at 90 (wow.gg). If the trainer does not offer it yet, keep making Minor Fortitude." },
        { from = 120, to = 130, craft = "Lesser Mana Potion", itemID = 3385, crafts = 10, yellow = 145, grey = 185, makes = 1,
          mats = {
              { itemID = 785, name = "Mageroyal", count = 1 },
              { itemID = 3820, name = "Stranglekelp", count = 1 },
              { itemID = 3371, name = "Empty Vial", count = 1, vendor = true },
          },
          learn = "trainer",
          note = "At 125 (and level 20) train Expert with Ainethil in Darnassus." },
        { from = 130, to = 150, craft = "Fire Oil", itemID = 6371, crafts = 20, yellow = 150, grey = 170, makes = 2,
          mats = {
              { itemID = 6359, name = "Firefin Snapper", count = 2 },
              { itemID = 3371, name = "Empty Vial", count = 1, vendor = true },
          },
          learn = "trainer",
          note = "Keep 30 Fire Oil for the next step. Or keep making Lesser Mana Potions to 165 instead." },
        { from = 150, to = 165, craft = "Elixir of Firepower", itemID = 6373, crafts = 15, yellow = 165, grey = 205, makes = 1,
          mats = {
              { itemID = 6371, name = "Fire Oil", count = 2 },
              { itemID = 3356, name = "Kingsblood", count = 1 },
              { itemID = 3372, name = "Leaded Vial", count = 1, vendor = true },
          },
          learn = "trainer",
          note = "Fire Oil comes from the 130-150 step. Needs Expert (train at 125)." },
        { from = 165, to = 195, craft = "Mana Potion", itemID = 3827, crafts = 37, yellow = 180, grey = 220, makes = 1,
          mats = {
              { itemID = 3820, name = "Stranglekelp", count = 1 },
              { itemID = 3356, name = "Kingsblood", count = 1 },
              { itemID = 3372, name = "Leaded Vial", count = 1, vendor = true },
          },
          learn = "trainer",
          note = "Yellow from 180." },
        { from = 195, to = 225, craft = "Nature Protection Potion", itemID = 6052, crafts = 37, yellow = 210, grey = 250, makes = 1,
          mats = {
              { itemID = 3357, name = "Liferoot", count = 1 },
              { itemID = 3820, name = "Stranglekelp", count = 1 },
              { itemID = 3372, name = "Leaded Vial", count = 1, vendor = true },
          },
          learn = "vendor: Logannas, Feathermoon Stronghold, Feralas (Alliance)",
          note = "Recipe needs 190. Alchemist Pestlezugg (Gadgetzan) also sells it. At 200 (level 35) get Artisan." },
        { from = 225, to = 230, craft = "Nature Protection Potion", itemID = 6052, crafts = 13, yellow = 210, grey = 250, makes = 1,
          mats = {
              { itemID = 3357, name = "Liferoot", count = 1 },
              { itemID = 3820, name = "Stranglekelp", count = 1 },
              { itemID = 3372, name = "Leaded Vial", count = 1, vendor = true },
          },
          learn = "vendor: Logannas, Feathermoon Stronghold, Feralas (Alliance)",
          note = "Train Artisan first: Kylanna Windwhisper, Feathermoon Stronghold, Feralas." },
        { from = 230, to = 240, craft = "Greater Mana Potion", itemID = 6149, crafts = 20, yellow = 220, grey = 260, makes = 1,
          mats = {
              { itemID = 3358, name = "Khadgar's Whisker", count = 1 },
              { itemID = 3821, name = "Goldthorn", count = 1 },
              { itemID = 3372, name = "Leaded Vial", count = 1, vendor = true },
          },
          learn = "trainer",
          note = "Already yellow (green at 240)." },
        { from = 240, to = 265, craft = "Draught of Detect Undead", itemID = 9154, crafts = 37, yellow = 245, grey = 285, makes = 1,
          mats = {
              { itemID = 8836, name = "Arthas' Tears", count = 1 },
              { itemID = 8925, name = "Crystal Vial", count = 1, vendor = true },
          },
          learn = "trainer",
          note = "Classic name: Elixir of Detect Undead. Yellow from 245." },
        { from = 265, to = 290, craft = "Superior Mana Potion", itemID = 13443, crafts = 32, yellow = 275, grey = 315, makes = 1,
          mats = {
              { itemID = 8838, name = "Sungrass", count = 2 },
              { itemID = 8839, name = "Blindweed", count = 2 },
              { itemID = 8925, name = "Crystal Vial", count = 1, vendor = true },
          },
          learn = "vendor: Ulthir, Craftsmen's Terrace, Darnassus (Alliance)",
          note = "Recipe needs 260. Yellow from 275. Alt: Elixir of Shadow Power (3 Ghost Mushroom) from Maria Lumere." },
        { from = 290, to = 300, craft = "Superior Mana Potion", itemID = 13443, crafts = 26, yellow = 275, grey = 315, makes = 1,
          mats = {
              { itemID = 8838, name = "Sungrass", count = 2 },
              { itemID = 8839, name = "Blindweed", count = 2 },
              { itemID = 8925, name = "Crystal Vial", count = 1, vendor = true },
          },
          learn = "vendor: Ulthir, Craftsmen's Terrace, Darnassus (Alliance)",
          note = "Green from 295. Cheaper alt: Major Frenzy Potion (Merchant's Favor, Nina Surefire, Redridge)." },
    },
    trainers = {
        { rank = "Apprentice", name = "Milla Fairancora", where = "Craftsmen's Terrace, Darnassus",
          zone = "Darnassus", mapID = 1457, x = 0.554, y = 0.229 },
        { rank = "Apprentice", name = "Cyndra Kindwhisper", where = "Dolanaar, Teldrassil",
          zone = "Teldrassil", mapID = 1438, x = 0.576, y = 0.607 },
        { rank = "Journeyman", name = "Sylvanna Forestmoon", where = "Craftsmen's Terrace, Darnassus",
          zone = "Darnassus", mapID = 1457, x = 0.561, y = 0.243 },
        { rank = "Expert", name = "Ainethil", where = "Craftsmen's Terrace, Darnassus",
          zone = "Darnassus", mapID = 1457, x = 0.555, y = 0.231 },
        { rank = "Recipe vendor: Superior Mana Potion", name = "Ulthir", where = "Craftsmen's Terrace, Darnassus",
          zone = "Darnassus", mapID = 1457, x = 0.554, y = 0.232 },
        { rank = "Journeyman", name = "Kylanna", where = "Silverwind Refuge, Ashenvale",
          zone = "Ashenvale", mapID = 1440, x = 0.508, y = 0.671 },
        { rank = "Apprentice", name = "Tel'Athir", where = "Mage Quarter, Stormwind",
          zone = "Stormwind City", mapID = 1453, x = 0.555, y = 0.854 },
        { rank = "Journeyman", name = "Lilyssia Nightbreeze", where = "Mage Quarter, Stormwind",
          zone = "Stormwind City", mapID = 1453, x = 0.555, y = 0.854 },
        -- https://wow-forever.gg/db/npcs/1313-maria-lumere/ (55.8, 85.6)
        { rank = "Recipe vendor: Elixir of Shadow Power", name = "Maria Lumere", where = "Alchemy Needs, Mage Quarter, Stormwind",
          zone = "Stormwind City", mapID = 1453, x = 0.558, y = 0.856 },
        { rank = "Apprentice", name = "Alchemist Mallory", where = "Cottage north of Goldshire, Elwynn Forest",
          zone = "Elwynn Forest", mapID = 1429, x = 0.398, y = 0.484 },
        { rank = "Apprentice", name = "Vosur Brakthel", where = "Tinker Town, Ironforge",
          zone = "Ironforge", mapID = 1455, x = 0.670, y = 0.542 },
        { rank = "Journeyman", name = "Tally Berryfizz", where = "Tinker Town, Ironforge",
          zone = "Ironforge", mapID = 1455, x = 0.672, y = 0.542 },
        { rank = "Artisan", name = "Kylanna Windwhisper", where = "Feathermoon Stronghold, Feralas",
          zone = "Feralas", mapID = 1444, x = 0.326, y = 0.437 },
        -- https://wow-forever.gg/db/npcs/8157-logannas/ (32.7, 44.0; wowhead Classic vendor guide says 32.6, 42.8)
        { rank = "Recipe vendor: Nature Protection Potion", name = "Logannas", where = "Base of the treehouse, Feathermoon Stronghold",
          zone = "Feralas", mapID = 1444, x = 0.327, y = 0.440 },
    },
    notes = {
        "Apprentice Alchemy has no level requirement in Forever.",
        "Journeyman: skill 50, level 10. Expert: skill 125, level 20. Artisan: skill 200, level 35.",
        "Healing potions are First Aid recipes in Forever.",
        "Vials are sold by alchemy supply vendors (Ulthir in Darnassus, Maria Lumere in Stormwind).",
        "225-300 is based on beta data and may change.",
    },
}
