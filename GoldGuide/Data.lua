-- GoldGuide data: farming spots and money tips for a solo Alliance player leveling 10-60.
--
-- Sources (read as text, Nov 2026):
--   Wowhead Classic item pages ("Dropped by" / "Skinned from" tables) for which mobs drop what and how often,
--   Wowhead Classic NPC and object pages for where those mobs, ore veins and herbs spawn (the densest cluster
--   of spawns is used as the spot), Wowhead Classic "Sold by" tables for the limited-supply recipes,
--   warcraft.wiki.gg for fishing spots, mein-mmo.de and icy-veins.com WoW Forever news for Forever notes.
-- Coordinates are fractions of the zone's own map, taken from the Classic zone maps.
-- Levels are the mob levels on Wowhead, widened by a few levels for a comfortable solo kill.

local MINING, HERBALISM, SKINNING, FISHING = 186, 182, 393, 356

-- Classic-era uiMapIDs first (confirmed: Forever uses them, e.g. Teldrassil 1438), then the Mainline IDs
-- as a fallback in case a later client changes. The page pins on the first one the game accepts whose
-- name matches the zone.
local ZONES = {
    ["Teldrassil"] = { 1438, 57 },
    ["Darkshore"] = { 1439, 62 },
    ["Ashenvale"] = { 1440, 63 },
    ["Elwynn Forest"] = { 1429, 37 },
    ["Westfall"] = { 1436, 52 },
    ["Loch Modan"] = { 1432, 48 },
    ["Redridge Mountains"] = { 1433, 49 },
    ["Duskwood"] = { 1431, 47 },
    ["Wetlands"] = { 1437, 56 },
    ["Arathi Highlands"] = { 1417, 14 },
    ["Hillsbrad Foothills"] = { 1424, 25 },
    ["Stranglethorn Vale"] = { 1434, 50, 224 },
    ["Desolace"] = { 1443, 66 },
    ["Stonetalon Mountains"] = { 1442, 65 },
    ["Thousand Needles"] = { 1441, 64 },
    ["Tanaris"] = { 1446, 71 },
    ["Feralas"] = { 1444, 69 },
    ["Dustwallow Marsh"] = { 1445, 70 },
    ["The Hinterlands"] = { 1425, 26 },
    ["Searing Gorge"] = { 1427, 32 },
    ["Badlands"] = { 1418, 15 },
    ["Swamp of Sorrows"] = { 1435, 51 },
    ["Blasted Lands"] = { 1419, 17 },
    ["Azshara"] = { 1447, 76 },
    ["Felwood"] = { 1448, 77 },
    ["Un'Goro Crater"] = { 1449, 78 },
    ["Winterspring"] = { 1452, 83 },
    ["Silithus"] = { 1451, 81 },
    ["Burning Steppes"] = { 1428, 36 },
    ["Western Plaguelands"] = { 1422, 22 },
    ["Eastern Plaguelands"] = { 1423, 23 },
}

-- Items, so each drop is written once.
local I = {
    linen = { 2589, "Linen Cloth" }, wool = { 2592, "Wool Cloth" }, silk = { 4306, "Silk Cloth" },
    mageweave = { 4338, "Mageweave Cloth" }, runecloth = { 14047, "Runecloth" }, felcloth = { 14256, "Felcloth" },
    copper = { 2770, "Copper Ore" }, tin = { 2771, "Tin Ore" }, silver = { 2775, "Silver Ore" },
    iron = { 2772, "Iron Ore" }, gold = { 2776, "Gold Ore" }, mithril = { 3858, "Mithril Ore" },
    truesilver = { 7911, "Truesilver Ore" }, thorium = { 10620, "Thorium Ore" },
    briarthorn = { 2450, "Briarthorn" }, bruiseweed = { 2453, "Bruiseweed" }, steelbloom = { 3355, "Wild Steelbloom" },
    kingsblood = { 3356, "Kingsblood" }, liferoot = { 3357, "Liferoot" }, khadgar = { 3358, "Khadgar's Whisker" },
    fadeleaf = { 3818, "Fadeleaf" }, goldthorn = { 3821, "Goldthorn" }, sungrass = { 8838, "Sungrass" },
    lotus = { 8831, "Purple Lotus" }, gromsblood = { 8846, "Gromsblood" }, dreamfoil = { 13463, "Dreamfoil" },
    sansam = { 13464, "Golden Sansam" }, silversage = { 13465, "Mountain Silversage" },
    plaguebloom = { 13466, "Plaguebloom" }, icecap = { 13467, "Icecap" }, blacklotus = { 13468, "Black Lotus" },
    lightLeather = { 2318, "Light Leather" }, mediumLeather = { 2319, "Medium Leather" },
    heavyLeather = { 4234, "Heavy Leather" }, thickLeather = { 4304, "Thick Leather" },
    ruggedLeather = { 8170, "Rugged Leather" }, devilsaur = { 15417, "Devilsaur Leather" },
    turtleScale = { 8167, "Turtle Scale" },
    earth = { 7067, "Elemental Earth" }, fire = { 7068, "Elemental Fire" }, air = { 7069, "Elemental Air" },
    water = { 7070, "Elemental Water" }, heartOfFire = { 7077, "Heart of Fire" }, globeOfWater = { 7079, "Globe of Water" },
    essenceOfWater = { 7080, "Essence of Water" }, breathOfWind = { 7081, "Breath of Wind" },
    essenceOfAir = { 7082, "Essence of Air" },
    blackmouth = { 6358, "Oily Blackmouth" }, firefin = { 6359, "Firefin Snapper" }, eel = { 13422, "Stonescale Eel" },
}

local farms = {}
local function F(minLevel, maxLevel, name, zone, x, y, drops, why, profession)
    local list = {}
    for index, item in ipairs(drops) do
        list[index] = { itemID = item[1], name = item[2] }
    end
    farms[#farms + 1] = {
        minLevel = minLevel, maxLevel = maxLevel, name = name, zone = zone,
        mapID = ZONES[zone] and ZONES[zone][1], x = x / 100, y = y / 100,
        drops = list, why = why, profession = profession,
    }
end

----- Cloth: humanoids drop it to everyone, no profession needed.
F(10, 14, "Writhing Highborne at Ameth'Aran for Linen", "Darkshore", 42.5, 61.1, { I.linen },
    "Level 11-12 ghosts in the ruins, close to Auberdine. Over half of them drop Linen.")
F(12, 17, "Defias in Moonbrook for Linen", "Westfall", 43.9, 68.8, { I.linen },
    "Defias Looters and Pillagers (13-15) pack Moonbrook; about two in three drop Linen.")
F(12, 17, "Stonesplinter troggs for Linen", "Loch Modan", 31.3, 85.3, { I.linen },
    "Stonesplinter Valley in the south is full of level 13-16 troggs and they drop Linen often.")
F(19, 23, "Mosshide gnolls for Wool", "Wetlands", 62.2, 69.3, { I.wool },
    "Level 20-22 gnolls in the southeast; about half drop Wool. Medium leather nearby if you skin.")
F(19, 24, "Syndicate at Durnholde Keep for Wool", "Hillsbrad Foothills", 78.5, 42.9, { I.wool },
    "Syndicate Watchmen, Rogues and Shadow Mages (20-22) around the keep. Mind Horde players in this zone.")
F(22, 26, "Thistlefur furbolgs for Wool", "Ashenvale", 36.7, 35.7, { I.wool },
    "Thistlefur Village, level 23-24 furbolgs, close to Astranaar. Close to home for a Night Elf.")
F(23, 27, "Blackrock orcs for Wool", "Redridge Mountains", 29.0, 12.1, { I.wool },
    "Blackrock Champions (24-25) in northern Redridge drop Wool about half the time.")
F(24, 28, "Defias Night Blades for Wool", "Duskwood", 49.1, 77.1, { I.wool },
    "Level 25-26 Defias in south Duskwood; about half drop Wool.")
F(26, 30, "Bleakheart satyrs at Satyrnaar for Silk", "Ashenvale", 81.2, 50.0, { I.silk, I.wool },
    "Level 27-28 satyrs in eastern Ashenvale; the first Silk Cloth spot for a Night Elf.")
F(29, 33, "Dabyrie's Farmstead for Silk", "Arathi Highlands", 55.5, 38.8, { I.silk },
    "Dabyrie Laborers (30-31) in a tight farm northeast of Refuge Pointe; about 60% drop Silk.")
F(32, 37, "Magram centaurs for Silk", "Desolace", 70.1, 75.8, { I.silk },
    "Magram Stormers (34-35) and friends at the Magram village; about half drop Silk.")
F(34, 38, "Shadowforge dwarves for Silk", "Badlands", 46.3, 10.9, { I.silk },
    "Shadowforge Surveyors (35-36) in northern Badlands; Silk and Iron veins nearby.")
F(35, 39, "Lost Ones for Silk", "Swamp of Sorrows", 63.8, 21.1, { I.silk },
    "Lost One Muckdwellers (36-37) in the northeast; about two in three drop Silk.")
F(36, 40, "Drywhisker kobolds for Silk", "Arathi Highlands", 84.7, 32.2, { I.silk },
    "Drywhisker Gorge in the east, level 37-38 kobolds.")
F(41, 45, "Gordunni ogres for Mageweave", "Feralas", 76.8, 32.6, { I.mageweave },
    "Gordunni Brutes and Warlocks (42-44) in northeast Feralas; about half drop Mageweave.")
F(44, 48, "Highborne ghosts for Mageweave", "Azshara", 16.0, 70.7, { I.mageweave },
    "Highborne Apparitions and Lichlings (45-47) in western Azshara; about three in four drop Mageweave.")
F(45, 49, "Dunemaul ogres for Mageweave", "Tanaris", 40.1, 54.3, { I.mageweave },
    "Dunemaul Compound, level 46-48 ogres. Nearly three in four drop Mageweave.")
F(45, 49, "Dark Iron dwarves for Mageweave", "Searing Gorge", 52.1, 57.3, { I.mageweave },
    "Dark Iron Lookouts, Steamsmiths and Slavers (45-48) all over the gorge.")
F(47, 51, "Deadwood furbolgs for Mageweave", "Felwood", 48.0, 90.5, { I.mageweave },
    "Deadwood Village in the far south of Felwood, level 48-50. Their feathers also start Timbermaw reputation.")
F(49, 54, "Jadefire satyrs for Mageweave and Felcloth", "Felwood", 41.1, 84.9, { I.mageweave, I.felcloth },
    "Jadefire Glen (50-54). Mageweave from most kills and Felcloth from about one in thirteen; Felcloth sells high.")
F(50, 54, "Firegut ogres for Runecloth", "Burning Steppes", 78.1, 43.4, { I.runecloth },
    "Dreadmaul Rock area, level 50-51 ogres; about two in three drop Runecloth. Thorium veins around too.")
F(52, 56, "Dreadmaul ogres for Runecloth", "Blasted Lands", 47.8, 40.4, { I.runecloth },
    "Level 53-55 ogres in central Blasted Lands; about two in three drop Runecloth.")
F(55, 60, "Mossflayer trolls for Runecloth", "Eastern Plaguelands", 70.4, 17.2, { I.runecloth },
    "Zul'Mashar in the northeast, level 57-59 trolls; about three in four drop Runecloth.")
F(57, 60, "Twilight cultists for Runecloth", "Silithus", 39.2, 44.5, { I.runecloth },
    "Twilight Avengers and Geolords (58-60) at the Twilight camps; Runecloth from half the kills.")

----- Elementals: their motes and essences sell to crafters.
F(36, 40, "Rock Elementals for Elemental Earth", "Badlands", 20.4, 44.4, { I.earth },
    "Lesser Rock Elementals (37-39) in western Badlands; more Rock Elementals (39-40) in the south at 42, 79.")
F(37, 41, "Elemental exiles for Elemental Fire and Earth", "Arathi Highlands", 25.7, 30.5, { I.fire, I.earth, I.water, I.air },
    "Level 38-39. Burning Exiles (fire) here; Rumbling Exiles (earth) at 36, 58; Cresting Exiles (water) at 67, 30; Thundering Exiles (air) at 52, 51. About one in ten drop their element.")
F(35, 39, "Lesser Water Elementals for Elemental Water", "Stranglethorn Vale", 21.0, 22.9, { I.water },
    "Level 36-37 water elementals in western Stranglethorn; about one in eleven drops Elemental Water.")
F(46, 50, "Sea Elementals for Elemental Water", "Feralas", 46.9, 50.8, { I.water, I.globeOfWater },
    "Sea Elementals and Sea Sprays (47-49) along the river through central Feralas.")
F(50, 54, "Entropic Beasts for Elemental Fire", "Felwood", 43.0, 40.2, { I.fire, I.heartOfFire },
    "Shatter Scar Vale in central Felwood, level 51-52.")
F(52, 56, "Toxic Horrors for Essence of Water", "Felwood", 49.6, 24.7, { I.essenceOfWater, I.globeOfWater, I.water },
    "Level 53-54 in northern Felwood. The best-known Essence of Water spot (about one in eighteen).")
F(53, 57, "Fire elementals for Heart of Fire", "Un'Goro Crater", 48.6, 49.7, { I.fire, I.heartOfFire },
    "Living Blazes and Scorching Elementals (53-55) on Fire Plume Ridge in the middle of the crater.")
F(53, 58, "Blighted Surges for Essence of Water", "Eastern Plaguelands", 61.8, 80.0, { I.essenceOfWater, I.globeOfWater },
    "Water elementals (54-56) in Lake Mereldar in the south of the zone.")
F(55, 60, "Dust Stormers for Essence of Air", "Silithus", 20.0, 26.2, { I.essenceOfAir, I.breathOfWind, I.air },
    "Level 55-57 in northwest Silithus; the main Essence of Air farm (about one in twenty-five).")

----- Mining (186). Spots are the densest cluster of veins; loop the zone from there.
F(10, 20, "Copper in Loch Modan", "Loch Modan", 34.6, 84.5, { I.copper },
    "Lots of Copper veins along the hills, thickest near Stonesplinter Valley. Darkshore's cliffs have Copper too.", MINING)
F(18, 28, "Tin in Ashenvale", "Ashenvale", 38.5, 35.6, { I.tin, I.silver },
    "The most Tin veins of any zone, close to home. Thickest in the northwest near Thistlefur Village.", MINING)
F(20, 30, "Tin in the Wetlands", "Wetlands", 50.4, 61.0, { I.tin, I.silver },
    "Tin and the odd Silver vein along the ridges of central Wetlands.", MINING)
F(30, 40, "Iron in the Arathi Highlands", "Arathi Highlands", 59.6, 76.2, { I.iron, I.gold },
    "The most Iron deposits of any zone, plus Gold. Loop the hills.", MINING)
F(32, 42, "Iron in Stranglethorn", "Stranglethorn Vale", 41.4, 42.3, { I.iron, I.gold },
    "Iron and Gold along the central hills.", MINING)
F(40, 50, "Mithril in the Hinterlands", "The Hinterlands", 57.9, 42.7, { I.mithril, I.truesilver },
    "The most Mithril deposits of any zone, with Truesilver.", MINING)
F(43, 50, "Mithril in Tanaris", "Tanaris", 54.7, 74.0, { I.mithril, I.truesilver },
    "Mithril thickest in southern Tanaris; sell in Gadgetzan.", MINING)
F(45, 52, "Mithril in Searing Gorge", "Searing Gorge", 46.0, 43.9, { I.mithril, I.truesilver },
    "Mithril, Truesilver and Iron together.", MINING)
F(50, 58, "Thorium in Un'Goro Crater", "Un'Goro Crater", 66.6, 15.5, { I.thorium },
    "Small Thorium veins (skill 230) along the crater walls; ride the edge of the bowl in a loop.", MINING)
F(54, 60, "Rich Thorium in Winterspring", "Winterspring", 57.9, 83.6, { I.thorium },
    "The most Rich Thorium veins (skill 255), thickest in the south of the zone.", MINING)
F(54, 60, "Thorium in Burning Steppes", "Burning Steppes", 79.8, 43.0, { I.thorium },
    "Small Thorium veins, thickest around Dreadmaul Rock in the east.", MINING)

----- Herbalism (182).
F(16, 26, "Bruiseweed and Briarthorn in Ashenvale", "Ashenvale", 54.8, 63.7, { I.bruiseweed, I.briarthorn, I.kingsblood },
    "Bruiseweed thickest southeast of Astranaar; Kingsblood around 45, 63.", HERBALISM)
F(22, 32, "Kingsblood and Liferoot in the Wetlands", "Wetlands", 59.9, 35.2, { I.kingsblood, I.liferoot },
    "Kingsblood in the northeast; Liferoot along the rivers in the west (39, 31).", HERBALISM)
F(24, 34, "Kingsblood in Hillsbrad", "Hillsbrad Foothills", 30.0, 57.3, { I.kingsblood, I.steelbloom },
    "Kingsblood around the hills west of Southshore.", HERBALISM)
F(32, 42, "Goldthorn, Kingsblood and Khadgar's Whisker in Stranglethorn", "Stranglethorn Vale", 42.9, 40.1, { I.goldthorn, I.kingsblood, I.khadgar, I.liferoot },
    "The most Goldthorn and Kingsblood of any zone. Khadgar's Whisker thickest in the north (37, 14).", HERBALISM)
F(32, 40, "Fadeleaf and Khadgar's Whisker in Arathi", "Arathi Highlands", 66.2, 67.8, { I.khadgar, I.fadeleaf, I.goldthorn },
    "Khadgar's Whisker thickest in the southeast; Goldthorn in the northwest.", HERBALISM)
F(35, 44, "Liferoot and Fadeleaf in Dustwallow", "Dustwallow Marsh", 43.3, 51.0, { I.liferoot, I.fadeleaf, I.goldthorn },
    "The most Liferoot and Fadeleaf of any zone, all through the central marsh. Theramore is the nearest town.", HERBALISM)
F(42, 50, "Sungrass and Purple Lotus in Feralas", "Feralas", 57.4, 54.4, { I.sungrass, I.lotus, I.goldthorn },
    "The most Sungrass of any zone; Purple Lotus thick at 60, 69.", HERBALISM)
F(44, 52, "Purple Lotus and Sungrass in the Hinterlands", "The Hinterlands", 63.2, 71.6, { I.lotus, I.sungrass },
    "Purple Lotus packed in the southeast; Sungrass in the west (36, 58).", HERBALISM)
F(50, 56, "Gromsblood in the Blasted Lands", "Blasted Lands", 45.1, 36.5, { I.gromsblood },
    "The most Gromsblood of any zone, in the middle of the Blasted Lands.", HERBALISM)
F(50, 58, "Dreamfoil and Golden Sansam in Un'Goro", "Un'Goro Crater", 51.0, 49.3, { I.dreamfoil, I.sansam, I.silversage },
    "All three late herbs grow here; ride a loop of the crater. Black Lotus is rare luck.", HERBALISM)
F(52, 60, "Dreamfoil and Golden Sansam in Azshara", "Azshara", 51.6, 80.5, { I.dreamfoil, I.sansam, I.lotus },
    "The most Dreamfoil and Golden Sansam of any zone, thickest in the south.", HERBALISM)
F(54, 60, "Plaguebloom in the Plaguelands", "Eastern Plaguelands", 72.7, 64.5, { I.plaguebloom, I.dreamfoil, I.silversage },
    "Plaguebloom grows in the Plaguelands; Eastern has the most.", HERBALISM)
F(55, 60, "Icecap and Silversage in Winterspring", "Winterspring", 38.7, 40.7, { I.icecap, I.silversage },
    "Icecap grows only here; Mountain Silversage on the same hills.", HERBALISM)

----- Skinning (393).
F(11, 16, "Thistle Bears for Light Leather", "Darkshore", 50.7, 28.7, { I.lightLeather },
    "Rabid Thistle Bears (13-14) everywhere in north Darkshore, the most-skinned bears in the zone.", SKINNING)
F(13, 17, "Crocolisks for Light Leather", "Loch Modan", 56.5, 38.3, { I.lightLeather },
    "Loch Crocolisks (14-15) around the lake.", SKINNING)
F(15, 19, "Great Goretusks for Light Leather", "Redridge Mountains", 28.4, 77.6, { I.lightLeather },
    "Level 16-17 boars all over southwest Redridge.", SKINNING)
F(21, 28, "Wetlands raptors for Medium Leather", "Wetlands", 34.2, 47.7, { I.mediumLeather },
    "Mottled Raptors (22-23) and Razormaws (26-27) west of the road.", SKINNING)
F(27, 31, "Nightbane worgs for Medium Leather", "Duskwood", 64.1, 74.1, { I.mediumLeather },
    "Nightbane Dark Runners (28-29) in southeast Duskwood; about three in four give Medium Leather.", SKINNING)
F(29, 33, "Highland Striders for Medium Leather", "Arathi Highlands", 61.9, 42.8, { I.mediumLeather },
    "Hundreds of level 30-31 striders across Arathi.", SKINNING)
F(30, 34, "Young tigers for Medium Leather", "Stranglethorn Vale", 35.1, 11.7, { I.mediumLeather },
    "Young Stranglethorn Tigers (30-31) by Nesingwary's camp; a quest wants them too.", SKINNING)
F(37, 41, "Crag Coyotes for Heavy Leather", "Badlands", 31.0, 70.2, { I.heavyLeather },
    "Elder Crag Coyotes (39-40) all over the Badlands; about three in four give Heavy Leather.", SKINNING)
F(38, 43, "Jungle Stalkers and gorillas for Heavy Leather", "Stranglethorn Vale", 31.8, 40.5, { I.heavyLeather },
    "Jungle Stalkers (40-41) here; Elder Mistvale Gorillas (40-41) at 33, 64. The most-skinned Heavy Leather mobs.", SKINNING)
F(41, 45, "Steeljaw Snappers for Thick Leather and Turtle Scale", "Tanaris", 66.8, 22.3, { I.thickLeather, I.turtleScale },
    "Level 42-43 turtles on the northeast coast; half give Turtle Scale, which sells well.", SKINNING)
F(46, 50, "Silvermane wolves for Thick Leather", "The Hinterlands", 69.4, 59.1, { I.thickLeather },
    "Silvermane Stalkers (47-48) in the eastern Hinterlands.", SKINNING)
F(47, 51, "Saltwater Snapjaws for Turtle Scale", "The Hinterlands", 76.9, 68.4, { I.thickLeather, I.turtleScale },
    "Level 49-50 turtles on the southeast coast; the top Turtle Scale spot.", SKINNING)
F(46, 50, "Incendosaurs for Thick Leather", "Searing Gorge", 47.7, 26.2, { I.thickLeather },
    "Level 47-49 lizards in the north of the gorge; about three in four give Thick Leather.", SKINNING)
F(51, 55, "Pterrordax for Rugged Leather", "Un'Goro Crater", 36.2, 41.3, { I.ruggedLeather, I.thickLeather },
    "Frenzied Pterrordax (52-54) in western Un'Goro.", SKINNING)
F(55, 60, "Devilsaurs for Devilsaur Leather", "Un'Goro Crater", 67.9, 29.1, { I.devilsaur },
    "Elite (54-56) and they roam. Every skin is Devilsaur Leather, among the best-paying leathers. Hunters and careful solo players only.", SKINNING)
F(52, 57, "Plaguebats for Rugged Leather", "Eastern Plaguelands", 33.4, 71.8, { I.ruggedLeather, I.thickLeather },
    "Hundreds of level 53-55 bats in southwest Eastern Plaguelands.", SKINNING)
F(54, 60, "Yetis and bears for Rugged Leather", "Winterspring", 67.4, 41.9, { I.ruggedLeather, I.thickLeather },
    "Ice Thistle Yetis (55-57) here; Elder Shardtooth bears (57-58) at 59, 23.", SKINNING)

----- Fishing (356).
F(15, 35, "Oily Blackmouth off Auberdine", "Darkshore", 36.0, 46.0, { I.blackmouth },
    "Fish the coast and Oily Blackmouth schools near Auberdine. Needs fishing 55; alchemists buy it for Blackmouth Oil.", FISHING)
F(45, 60, "Stonescale Eels on the Tanaris coast", "Tanaris", 69.0, 33.0, { I.eel },
    "Eel schools along the Tanaris coast; best at night. Needs about fishing 180 plus a lure. Used in Stonescale Oil.", FISHING)

-- General money tips. minLevel: the level they start to matter.
local methods = {
    { minLevel = 1, title = "Sell every grey", text = "Grey items exist only to be sold to a vendor. Loot everything and sell greys at every vendor stop." },
    { minLevel = 1, title = "No token in Forever", text = "Forever has no WoW Token, so every copper is earned in game. Start saving from day one." },
    { minLevel = 5, title = "Take two gathering professions", text = "Skinning plus Herbalism or Mining costs almost nothing and turns every kill and route into gold. Raw materials sell well early in a new realm." },
    { minLevel = 8, title = "Train only what you use", text = "Skip spell ranks you won't cast, like buffs you refresh rarely. Training is the biggest early expense." },
    { minLevel = 10, title = "Choose quest rewards for money", text = "When no reward is an upgrade, take the one with the highest vendor price." },
    { minLevel = 10, title = "Sell cloth at the auction house", text = "Linen, Wool and Silk sell for more at auction than at a vendor. Keep a stack if you use First Aid; bandages save food money." },
    { minLevel = 12, title = "Check the auction before you vendor", text = "Greens and trade goods often sell for far more at auction. PriceMemory shows the last price you saw on each tooltip, and this page lists bag items worth more there." },
    { minLevel = 15, title = "Post smart", text = "A listing costs a deposit you lose if it doesn't sell, and the auction house keeps a cut of each sale. Price just under the lowest current listing." },
    { minLevel = 20, title = "Don't buy what you can loot", text = "Eat the meat you loot and cook it; buy food and water only when you must. Repair only at real breakpoints, not after every pull." },
    { minLevel = 20, title = "Free Action Potion recipe", text = "Ulthir (Darnassus) sells Recipe: Free Action Potion, limited supply, about 18s. It often sells for more at auction." },
    { minLevel = 20, title = "Enchant Bracer - Deflection formula", text = "Mythrin'dir (Darnassus) sells Formula: Enchant Bracer - Deflection, limited supply, about 50-60s. Enchanters often pay more at auction." },
    { minLevel = 30, title = "Black Swashbuckler's Shirt pattern", text = "Narkk in Booty Bay sells Pattern: Black Swashbuckler's Shirt, limited supply, about 15s. Tailors buy it at auction." },
    { minLevel = 35, title = "Shadow Oil recipe", text = "Vendor-Tron 1000 in Desolace sells Recipe: Shadow Oil, limited supply, about 15s." },
    { minLevel = 40, title = "Riding at 40", text = "Apprentice riding and a mount cost about 120g. Track it on the Gold goal page." },
    { minLevel = 40, title = "Elemental motes", text = "Elemental Earth, Fire, Water and Air are wanted by blacksmiths, engineers and alchemists. See the elemental farms on this page." },
    { minLevel = 40, title = "Elixir of Superior Defense recipe", text = "Soolie Berryfizz in Ironforge sells Recipe: Elixir of Superior Defense, limited supply, about 1g 30s." },
    { minLevel = 45, title = "Ghost Dye recipe", text = "Logannas at Feathermoon Stronghold (Feralas) sells Recipe: Ghost Dye, limited supply, about 90s." },
    { minLevel = 45, title = "Sell unbound blues", text = "Blue and purple items that bind on equip sell to other players for far more than a vendor pays. Don't equip one you mean to sell." },
    { minLevel = 50, title = "Runecloth is always wanted", text = "Tailors and reputation turn-ins both use Runecloth, so it rarely sits unsold." },
    { minLevel = 55, title = "Runecloth Bag pattern", text = "Qia in Everlook (Winterspring) sells Pattern: Runecloth Bag, limited supply, about 1g 20s." },
    { minLevel = 58, title = "Epic riding at 60", text = "Journeyman riding and an epic mount cost about 1200g. Gold you farm at 55-60 goes furthest toward it." },
}

GoldGuideData = { farms = farms, methods = methods, zones = ZONES }
