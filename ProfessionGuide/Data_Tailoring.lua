-- Tailoring leveling path for World of Warcraft: Forever (Alliance).
-- Sources: https://www.wow-professions.com/forever/tailoring-leveling-guide
--          https://metabot.gg/en/wow-forever/professions/tailoring (Forever skill colors + reagents)
--          https://conquestcapped.com/guides/wow-forever/wow-forever-tailoring/ (live route, Runecloth Cuffs vendor)
--          https://www.wow-professions.com/forever/npc/qia, .../npc/darnall (Forever pattern skill levels)
--          https://www.warcrafttavern.com/forever/guides/profession-trainers/ (trainer coords)
--          Item IDs and vendor coords checked on https://classicdb.ch (wowhead blocked automated reads).
-- Craft counts: each point at skill s succeeds with chance (grey - s) / (grey - yellow), 1 while orange (Forever
-- yellow/grey from metabot.gg). `crafts` is the mean plus 1.28 standard deviations, rounded up: enough about 9 times
-- in 10. Forever's Working Overtime talent (+4% chance per rank) is not counted.
-- Bolt steps list the TOTAL bolts needed later in the path (more than the skill needs) - make them all then.
-- Learn skills that metabot marks as estimates: Linen Belt 35, Woolen Cape 65, Double-stitched Shoulders 95,
-- Gloves of Meditation 110, Crimson Silk Vest 155 (wow-professions and conquestcapped use it from 150),
-- Crimson Silk Pantaloons 165, Black Mageweave Gloves 180, Mageweave Bag 190, Runecloth Belt 210, Mooncloth Boots 270.
-- Runecloth Belt is yellow from 225 in Forever (Classic: orange). Runecloth Gloves pattern is learned at 230
-- in Forever (Qia). Bolts of Runecloth: wow-professions says no skill; metabot/conquestcapped show a few
-- points around 195-212 - not relied on here.
-- 250-300 is untested by wow-professions. Runecloth Cuffs (new Forever recipe, item 254123; pattern 254124 needs
-- Tailoring 250, sold in Mount Hyjal; mats 5 Bolt of Runecloth, Ironweb Spider Silk, Rune Thread - all confirmed at
-- https://www.wowhead.com/forever/item=254124) comes from Pexmit in Mount Hyjal per conquestcapped; its colors are 250/265/280/295 (grey 295), so the last
-- 10 points use Mooncloth Boots (trainer per metabot, learn 270 estimated).
ProfessionGuideData = ProfessionGuideData or {}
ProfessionGuideData[197] = {
    name = "Tailoring",
    steps = {
        { from = 1, to = 35, craft = "Bolt of Linen Cloth", itemID = 2996, crafts = 39, yellow = 25, grey = 50, makes = 1,
          mats = {
              { itemID = 2589, name = "Linen Cloth", count = 2 },
          },
          learn = "auto",
          note = "Yellow from 25. Keep 22 bolts for Linen Belts." },
        { from = 35, to = 55, craft = "Linen Belt", itemID = 7026, crafts = 22, yellow = 50, grey = 85, makes = 1,
          mats = {
              { itemID = 2996, name = "Bolt of Linen Cloth", count = 1 },
              { itemID = 2320, name = "Coarse Thread", count = 1, vendor = true },
          },
          learn = "trainer",
          note = "Bolts from 1-35. Yellow from 50. Train Journeyman at 50 (level 10)." },
        { from = 55, to = 75, craft = "Bolt of Woolen Cloth", itemID = 2997, crafts = 159, yellow = 70, grey = 85, makes = 1,
          mats = {
              { itemID = 2592, name = "Wool Cloth", count = 3 },
          },
          learn = "trainer",
          note = "~23 crafts reach 75 (yellow from 70). crafts = all 159 bolts needed for capes, shoulders and Gloves of Meditation." },
        { from = 75, to = 95, craft = "Woolen Cape", itemID = 2584, crafts = 28, yellow = 80, grey = 115, makes = 1,
          mats = {
              { itemID = 2997, name = "Bolt of Woolen Cloth", count = 1 },
              { itemID = 2321, name = "Fine Thread", count = 1, vendor = true },
          },
          learn = "trainer",
          note = "Yellow from 80." },
        { from = 95, to = 100, craft = "Double-stitched Woolen Shoulders", itemID = 4314, crafts = 5, yellow = 110, grey = 145, makes = 1,
          mats = {
              { itemID = 2997, name = "Bolt of Woolen Cloth", count = 3 },
              { itemID = 2321, name = "Fine Thread", count = 2, vendor = true },
          },
          learn = "trainer",
          note = "Orange to 110 if you prefer Wool over Silk bolts." },
        { from = 100, to = 120, craft = "Bolt of Silk Cloth", itemID = 4305, crafts = 188, yellow = 110, grey = 120, makes = 1,
          mats = {
              { itemID = 4306, name = "Silk Cloth", count = 4 },
          },
          learn = "trainer",
          note = "Yellow 110, grey 120: ~54 crafts reach 120. crafts = all 188 bolts needed for the Crimson Silk steps." },
        { from = 120, to = 140, craft = "Gloves of Meditation", itemID = 4318, crafts = 29, yellow = 125, grey = 155, makes = 1,
          mats = {
              { itemID = 2997, name = "Bolt of Woolen Cloth", count = 4 },
              { itemID = 2321, name = "Fine Thread", count = 3, vendor = true },
              { itemID = 3383, name = "Elixir of Wisdom", count = 1 },
          },
          learn = "trainer",
          note = "Yellow from 125. Elixir of Wisdom: Auction House or an alchemist. Train Expert at 125 (level 20)." },
        { from = 140, to = 150, craft = "Bolt of Mageweave", itemID = 4339, crafts = 190, yellow = 145, grey = 150, makes = 1,
          mats = {
              { itemID = 4338, name = "Mageweave Cloth", count = 5 },
          },
          learn = "trainer",
          note = "Yellow 145, grey 150: ~23 crafts reach 150. crafts = all 190 bolts needed for 190-225." },
        { from = 150, to = 170, craft = "Crimson Silk Vest", itemID = 7058, crafts = 20, yellow = 170, grey = 190, makes = 1,
          mats = {
              { itemID = 4305, name = "Bolt of Silk Cloth", count = 4 },
              { itemID = 2604, name = "Red Dye", count = 2, vendor = true },
              { itemID = 2321, name = "Fine Thread", count = 2, vendor = true },
          },
          learn = "trainer",
          note = "Expert recipe (Georgio Bolero, Stormwind). Orange to 170. Sources differ on learning it at 150 or 155: if the trainer doesn't list it yet, use any orange silk recipe you know until 155." },
        { from = 170, to = 190, craft = "Crimson Silk Pantaloons", itemID = 7062, crafts = 27, yellow = 180, grey = 200, makes = 1,
          mats = {
              { itemID = 4305, name = "Bolt of Silk Cloth", count = 4 },
              { itemID = 2604, name = "Red Dye", count = 2, vendor = true },
              { itemID = 4291, name = "Silken Thread", count = 2, vendor = true },
          },
          learn = "trainer",
          note = "Yellow from 180." },
        { from = 190, to = 210, craft = "Black Mageweave Gloves", itemID = 10003, crafts = 29, yellow = 195, grey = 225, makes = 1,
          mats = {
              { itemID = 4339, name = "Bolt of Mageweave", count = 2 },
              { itemID = 8343, name = "Heavy Silken Thread", count = 2, vendor = true },
          },
          learn = "trainer",
          note = "Yellow from 195, green at 210. At 200 (level 35) get Artisan from Timothy Worthington, Theramore." },
        { from = 210, to = 225, craft = "Mageweave Bag", itemID = 10050, crafts = 33, yellow = 205, grey = 235, makes = 1,
          mats = {
              { itemID = 4339, name = "Bolt of Mageweave", count = 4 },
              { itemID = 4291, name = "Silken Thread", count = 2, vendor = true },
          },
          learn = "trainer",
          note = "Yellow from 205. If the trainer offers Runecloth Belt at 210, it is orange to 225 (15 crafts)." },
        { from = 225, to = 240, craft = "Runecloth Belt", itemID = 13856, crafts = 24, yellow = 225, grey = 255, makes = 1,
          mats = {
              { itemID = 14048, name = "Bolt of Runecloth", count = 3 },
              { itemID = 14341, name = "Rune Thread", count = 1, vendor = true },
          },
          learn = "trainer",
          note = "Needs Artisan. Yellow 225-240. Bolt of Runecloth = 5 Runecloth (trainer recipe); 644 bolts for 225-300." },
        { from = 240, to = 250, craft = "Runecloth Gloves", itemID = 13863, crafts = 12, yellow = 245, grey = 275, makes = 1,
          mats = {
              { itemID = 14048, name = "Bolt of Runecloth", count = 4 },
              { itemID = 8170, name = "Rugged Leather", count = 4 },
              { itemID = 14341, name = "Rune Thread", count = 1, vendor = true },
          },
          learn = "vendor: Qia, Everlook, Winterspring",
          note = "Pattern needs 230, limited stock. Orange to 245, yellow to 260 (keep going to 260 if no Cuffs)." },
        { from = 250, to = 280, craft = "Runecloth Cuffs", itemID = 254123, crafts = 39, yellow = 265, grey = 295, makes = 1,
          mats = {
              { itemID = 14048, name = "Bolt of Runecloth", count = 5 },
              { itemID = 14227, name = "Ironweb Spider Silk", count = 1 },
              { itemID = 14341, name = "Rune Thread", count = 1, vendor = true },
          },
          learn = "vendor: Pexmit, Mount Hyjal (58.8, 41.8)",
          note = "New Forever pattern (skill 250). Orange to 265, yellow to 280. Untested route." },
        { from = 280, to = 290, craft = "Runecloth Cuffs", itemID = 254123, crafts = 43, yellow = 265, grey = 295, makes = 1,
          mats = {
              { itemID = 14048, name = "Bolt of Runecloth", count = 5 },
              { itemID = 14227, name = "Ironweb Spider Silk", count = 1 },
              { itemID = 14341, name = "Rune Thread", count = 1, vendor = true },
          },
          learn = "vendor: Pexmit, Mount Hyjal (58.8, 41.8)",
          note = "Low chance (grey at 295). World-drop Runecloth Shoulders / Wizardweave Turban (grey 305) also work." },
        { from = 290, to = 300, craft = "Mooncloth Boots", itemID = 15802, crafts = 19, yellow = 285, grey = 315, makes = 1,
          mats = {
              { itemID = 14048, name = "Bolt of Runecloth", count = 6 },
              { itemID = 14342, name = "Mooncloth", count = 4 },
              { itemID = 7971, name = "Black Pearl", count = 2 },
              { itemID = 14341, name = "Rune Thread", count = 1, vendor = true },
          },
          learn = "trainer",
          note = "Yellow from 285. Needs 76 Mooncloth (cooldown craft): buy it or make it (pattern from Qia)." },
    },
    trainers = {
        { rank = "Apprentice", name = "Trianna", where = "Craftsmen's Terrace, Darnassus",
          zone = "Darnassus", mapID = 1457, x = 0.636, y = 0.217 },
        { rank = "Journeyman", name = "Me'lynn", where = "Craftsmen's Terrace, Darnassus",
          zone = "Darnassus", mapID = 1457, x = 0.626, y = 0.226 },
        { rank = "Apprentice", name = "Grondal Moonbreeze", where = "Auberdine, Darkshore",
          zone = "Darkshore", mapID = 1439, x = 0.382, y = 0.406 },
        { rank = "Journeyman", name = "Sellandus", where = "Mage Quarter, Stormwind",
          zone = "Stormwind City", mapID = 1453, x = 0.523, y = 0.834 },
        { rank = "Expert", name = "Georgio Bolero", where = "Mage Quarter, Stormwind",
          zone = "Stormwind City", mapID = 1453, x = 0.533, y = 0.817 },
        { rank = "Apprentice/Expert", name = "Lawrence Schneider", where = "Mage Quarter, Stormwind",
          zone = "Stormwind City", mapID = 1453, x = 0.535, y = 0.818 },
        { rank = "Apprentice", name = "Uthrar Threx", where = "Ironforge",
          zone = "Ironforge", mapID = 1455, x = 0.439, y = 0.289 },
        { rank = "Journeyman", name = "Jormund Stonebrow", where = "Ironforge",
          zone = "Ironforge", mapID = 1455, x = 0.440, y = 0.304 },
        { rank = "Artisan", name = "Timothy Worthington", where = "Theramore Isle, Dustwallow Marsh",
          zone = "Dustwallow Marsh", mapID = 1445, x = 0.662, y = 0.516 },
        { rank = "Recipe vendor: Runecloth Gloves, Mooncloth", name = "Qia", where = "Bank, Everlook, Winterspring",
          zone = "Winterspring", mapID = 1452, x = 0.612, y = 0.372 },
        { rank = "Recipe vendor: Runecloth Robe, Cloak, Boots", name = "Darnall", where = "Nighthaven, Moonglade",
          zone = "Moonglade", mapID = 1450, x = 0.515, y = 0.333 },
    },
    notes = {
        "Apprentice Tailoring has no level requirement in Forever.",
        "Journeyman: skill 50, level 10. Expert: skill 125, level 20. Artisan: skill 200, level 35.",
        "Threads and dyes are sold by tailoring supply vendors near the trainers.",
        "Cloth drops from humanoids; Enchanting pairs well (disenchant your crafts).",
        "Forever recipes turn grey earlier than Classic past 225. 250-300 is untested.",
        "Runecloth Cuffs vendor is in Mount Hyjal (Forever zone).",
    },
}
