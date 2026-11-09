-- Mining leveling path for World of Warcraft: Forever (Alliance, Night Elf start).
-- Sources: https://www.wow-professions.com/forever/mining-leveling-guide
--          https://www.warcrafttavern.com/forever/guides/profession-trainers/ (trainer coords)
-- Vein skill requirements are the Classic values (Forever guide uses the same: Tin 65, Silver 75, Iron 125,
-- Gold 155, Mithril 175, Truesilver 230, Small Thorium 245, Rich Thorium 275).
-- Smelting skill levels not given by the Forever guide (Iron, Steel, Mithril, Truesilver, Thorium, Dark Iron)
-- are Classic values. Zones past 175 follow standard Classic routes (Forever beta was capped at 30).
-- Zone order adapted for a Night Elf (Darkshore -> Ashenvale/Stonetalon/Wetlands -> Arathi/Desolace ...).
ProfessionGuideData = ProfessionGuideData or {}
ProfessionGuideData[186] = {
    name = "Mining",
    steps = {
        { from = 1, to = 65, gather = "Copper Vein",
          where = "Darkshore (cliffs and coast), Teldrassil, Elwynn Forest, Dun Morogh",
          note = "Needs a Mining Pick. Smelt Copper (skill 1) at the Auberdine forge for extra points." },
        { from = 65, to = 125, gather = "Tin Vein (65), Silver Vein (75), Copper Vein",
          where = "Ashenvale, Stonetalon Mountains, Wetlands (caves, best), Hillsbrad Foothills",
          note = "Train Journeyman at 50 (not at Teldrassil trainer). Smelt Tin/Bronze (65), Silver (75)." },
        { from = 125, to = 155, gather = "Iron Deposit (125), Tin Vein, Silver Vein",
          where = "Arathi Highlands, Desolace, Stonetalon Mountains, Hillsbrad Foothills",
          note = "Train Expert at 125 (level 20). Smelting Iron gives a few points to ~135." },
        { from = 155, to = 175, gather = "Gold Vein (155), Iron Deposit",
          where = "Arathi Highlands, Desolace, Badlands",
          note = "Smelt Gold (155) for points. Smelt Steel at 165 (Iron Bar + Coal from vendors)." },
        { from = 175, to = 230, gather = "Mithril Deposit (175), Gold Vein, Iron Deposit",
          where = "Badlands, The Hinterlands, Tanaris, Feralas",
          note = "Train Artisan at 200 before 225 (any trainer outside starting areas). Smelt Mithril (175)." },
        { from = 230, to = 245, gather = "Truesilver Deposit (230), Mithril Deposit",
          where = "The Hinterlands, Tanaris, Feralas, Un'Goro Crater",
          note = "Below 60, skip the Tanaris caves. Smelt Truesilver (230) for points." },
        { from = 245, to = 275, gather = "Small Thorium Vein (245), Mithril, Truesilver",
          where = "Un'Goro Crater, Felwood, Burning Steppes, Blasted Lands",
          note = "Alliance can't mine inside the Garrison Armory (Blasted Lands). Smelt Thorium at 250." },
        { from = 275, to = 300, gather = "Rich Thorium Vein (275), Small Thorium Vein",
          where = "Un'Goro Crater, Winterspring, Eastern Plaguelands, Burning Steppes",
          note = "Small Thorium turns green; target Rich Thorium for the last points." },
    },
    trainers = {
        { rank = "Apprentice (to 75)", name = "Fanorran Stilloak", where = "Shadowglen, Teldrassil",
          zone = "Teldrassil", mapID = 1438, x = 0.582, y = 0.413 },
        -- 38.2, 41: https://www.wowhead.com/forever/guide/professions/mining/overview-leveling. He shares the forge
        -- with Delfrum Flintbeard (38.2, 40.9, https://wow-forever.gg/db/npcs/6299-delfrum-flintbeard/), hence the same point.
        { rank = "All ranks", name = "Kurdram Stonehammer", where = "Auberdine, Darkshore",
          zone = "Darkshore", mapID = 1439, x = 0.382, y = 0.410 },
        { rank = "All ranks", name = "Gelman Stonehand", where = "Dwarven District, Stormwind",
          zone = "Stormwind City", mapID = 1453, x = 0.591, y = 0.377 },
        { rank = "All ranks", name = "Geofram Bouldertoe", where = "Ironforge",
          zone = "Ironforge", mapID = 1455, x = 0.503, y = 0.280 },
        { rank = "All ranks", name = "Yarr Hammerstone", where = "Kharanos, Dun Morogh",
          zone = "Dun Morogh", mapID = 1426, x = 0.500, y = 0.504 },
        { rank = "All ranks", name = "Brock Stoneseeker", where = "Thelsamar, Loch Modan",
          zone = "Loch Modan", mapID = 1432, x = 0.372, y = 0.469 },
        { rank = "All ranks", name = "Matt Johnson", where = "Darkshire, Duskwood",
          zone = "Duskwood", mapID = 1431, x = 0.740, y = 0.496 },
        { rank = "All ranks", name = "Pikkle", where = "Gadgetzan, Tanaris",
          zone = "Tanaris", mapID = 1446, x = 0.510, y = 0.280 },
    },
    notes = {
        "Journeyman: skill 50, level 10. Expert: skill 125, level 20. Artisan: skill 200, level 35.",
        "Starting-zone trainers (Shadowglen) only teach up to 75.",
        "Teldrassil has no forge: smelt in Auberdine or Darnassus (Warrior's Terrace).",
        "Smelting: Copper 1, Tin/Bronze 65, Silver 75, Iron ~125, Gold 155, Steel 165, Mithril 175, Truesilver 230, Thorium 250.",
        "Fast start: buy ore and smelt Copper to 65, Tin to 75, Bronze to ~105, Silver to ~120.",
        "Dark Iron (230) can only be smelted at the Black Forge in Blackrock Depths.",
        "Bonus: Mining glove enchants (+2/+5), Goblin Mining Helmet (+5), Miner's Cape (+2).",
    },
}
