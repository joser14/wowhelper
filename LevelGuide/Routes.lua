-- Our own leveling routes for WoW Forever. Quest order and coordinates were put together from Forever
-- guide sites (wowhandbook.com routes, urgametips.com NPC tables, games.gg), checked against each other.
-- Coordinates are percent of the zone's own map. "part" counts turn-ins of quests that share a title.
-- Anything wrong can be skipped in game with a right-click.

-- A few research notes landed where the part number goes; a text there is a note, not a part.
local function A(q, npc, x, y, lvl, part) if type(part) ~= "number" then part = nil end return { t = "accept", q = q, npc = npc, x = x, y = y, lvl = lvl, part = part } end
local function D(q, note, x, y, lvl, part) if type(part) ~= "number" then part = nil end return { t = "do", q = q, note = note, x = x, y = y, lvl = lvl, part = part } end
local function T(q, npc, x, y, lvl, part) if type(part) ~= "number" then part = nil end return { t = "turnin", q = q, npc = npc, x = x, y = y, lvl = lvl, part = part } end
local function G(text, x, y, lvl, note) return { t = "go", text = text, x = x, y = y, lvl = lvl, note = note } end
-- A step that happens on another zone's map (its x, y are that map's, e.g. the Duskwood route's Sven leg in
-- Stormwind City and Wetlands). The guide puts it on the map only while you're in that zone, instead of
-- plotting the same numbers on this route's map (LevelGuide.lua RouteDisplay).
local function On(zone, step) step.map = zone return step end

-- Teldrassil (Night Elf 1-12) for WoW: Forever 1.60.x.
-- Sources: wow4ever.quest (Questie Forever data, client 1.60.1.70790), wowhead.com/forever quest text,
-- foreverchanges.pro zone list, bindonforever.com Teldrassil route (coordinates).
-- Coordinates are Teldrassil map percentages, except steps whose NPC text says "Darnassus":
-- those use the Darnassus city map. Class quests (sigils, Garments of the Moon, etc.) are left out.
-- Left out: "Eyes of the Sentinels" (Forever, Darnassus city only, giver not recorded),
-- "Return to Nessa" (turned in after you reach Darkshore).
local TELDRASSIL = { zone = "Teldrassil", min = 1, max = 12, steps = {
    -- Shadowglen
    A("The Balance of Nature", "Conservator Ilthalaine", 58.7, 44.3, 1, 1),
    A("The Woodland Protector", "Melithar Staghelm", 59.9, 42.5, 1, 1),
    T("The Woodland Protector", "Tarindrella", 57.8, 45.0, 1, 1),
    A("The Woodland Protector", "Tarindrella", 57.8, 45.0, 1, 2),
    A("Nature's Call", "Tarindrella", 57.8, 45.0, 1),
    D("The Balance of Nature", "Kill 7 Young Nightsabers and 4 Young Thistle Boars", 61.6, 43.7, 1, 1),
    T("The Balance of Nature", "Conservator Ilthalaine", 58.7, 44.3, 2, 1),
    A("The Balance of Nature", "Conservator Ilthalaine", 58.7, 44.3, 2, 2),
    A("The Goddess Provides", "Shanda (in Aldrassil)", 59.2, 40.5, 2),
    D("The Goddess Provides", "Cast Elune's Light and Shadowmeld once each", 59.2, 40.5, 2),
    T("The Goddess Provides", "Shanda (in Aldrassil)", 59.2, 40.5, 2),
    A("A Good Friend", "Dirania Silvershine", 60.9, 42.0, 2),
    D("The Balance of Nature", "Kill 7 Mangy Nightsabers and 7 Thistle Boars north of Aldrassil", 61.0, 35.6, 2, 2),
    T("A Good Friend", "Iverron (by the cave to the north)", 54.6, 33.0, 3),
    A("A Friend in Need", "Iverron", 54.6, 33.0, 3),
    T("A Friend in Need", "Dirania Silvershine", 60.9, 42.0, 3),
    A("Iverron's Antidote", "Dirania Silvershine", 60.9, 42.0, 3, 1),
    T("The Balance of Nature", "Conservator Ilthalaine", 58.7, 44.3, 3, 2),
    A("Webwood Venom", "Gilshalan Windwalker (in Aldrassil)", 57.9, 41.7, 3),
    D("Iverron's Antidote", "4 Moonpetal Lilies at the ponds and 1 Webwood Ichor from the spiders", 58.4, 36.4, 3, 1),
    D("Webwood Venom", "10 Webwood Venom Sacs from spiders outside Shadowthread Cave", 57.0, 27.5, 4),
    D("Iverron's Antidote", "7 Hyacinth Mushrooms west of Aldrassil", 54.5, 43.9, 4, 1),
    D("The Woodland Protector", "8 Fel Moss from grells and grellkin", 54.6, 43.9, 4, 2),
    D("Nature's Call", "4 Gnarlpine Totems in the abandoned Gnarlpine camps on the west edge of the glen", 54.5, 43.8, 4),
    T("The Woodland Protector", "Tarindrella", 57.8, 45.0, 4, 2),
    T("Nature's Call", "Tarindrella", 57.8, 45.0, 4),
    T("Iverron's Antidote", "Dirania Silvershine", 60.9, 42.0, 4, 1),
    T("Webwood Venom", "Gilshalan Windwalker", 57.9, 41.7, 4),
    A("Webwood Egg", "Gilshalan Windwalker", 57.9, 41.7, 4),
    A("Iverron's Antidote", "Dirania Silvershine (TIMED 5 min: go straight to Iverron)", 60.9, 42.0, 4, 2),
    T("Iverron's Antidote", "Iverron (timed delivery)", 54.6, 33.0, 4, 2),
    D("Webwood Egg", "Webwood Egg at the back of Shadowthread Cave", 56.5, 26.5, 5),
    A("Fang of Githyiss", "Fang of Githyiss (drops from Githyiss the Vile at the back of the cave)", 56.5, 26.5, 5),
    T("Webwood Egg", "Gilshalan Windwalker", 57.9, 41.7, 5),
    T("Fang of Githyiss", "Gilshalan Windwalker", 57.9, 41.7, 5),
    A("Tenaron's Summons", "Gilshalan Windwalker", 57.9, 41.7, 5),
    T("Tenaron's Summons", "Tenaron Stormgrip (top of Aldrassil)", 59.1, 39.4, 5),
    A("Crown of the Earth", "Tenaron Stormgrip", 59.1, 39.4, 5, 1),
    D("Crown of the Earth", "Fill the Crystal Phial at the Shadowglen moonwell", 60.0, 33.0, 5, 1),
    T("Crown of the Earth", "Tenaron Stormgrip", 59.1, 39.4, 5, 1),
    A("Crown of the Earth", "Tenaron Stormgrip", 59.1, 39.4, 5, 2),
    A("The Adventurer", "Lost Journal (object, top of Aldrassil)", 59.1, 39.5, 5),
    A("Dolanaar Delivery", "Porthannius (on the road out)", 61.2, 47.6, 5),

    -- Dolanaar
    A("Zenn's Bidding", "Zenn Foulhoof", 60.4, 56.2, 5),
    T("The Adventurer", "Lyreena Duskblade", 57.6, 56.6, 5),
    A("The Great Outdoors", "Lyreena Duskblade", 57.6, 56.6, 5),
    D("The Great Outdoors", "Sit by Lyreena's Basic Campfire until you get Boosted Rest", 57.5, 56.5, 5),
    T("The Great Outdoors", "Lyreena Duskblade", 57.6, 56.6, 5),
    A("Camping 101: Cooking", "Lyreena Duskblade", 57.6, 56.6, 5),
    A("Camping 101: Skinning", "Lyreena Duskblade (optional: skinners only, needs Skinning 20)", 57.6, 56.6, 5),
    A("A Troubling Breeze", "Athridas Bearmantle", 55.9, 57.4, 5),
    A("Denalan's Earth", "Syral Bladeleaf", 56.1, 57.7, 5),
    A("The Sisterhood of Elune", "Laurna Morninglight", 55.5, 56.8, 5),
    A("The Emerald Dreamcatcher", "Tallonkai Swiftroot", 55.5, 56.9, 5),
    A("Twisted Hatred", "Tallonkai Swiftroot", 55.5, 56.9, 5, 1),
    A("Soft Saber Pelts", "Aldia (trader)", 55.6, 57.1, 5),
    T("Dolanaar Delivery", "Innkeeper Keldamyr", 55.7, 59.8, 5),
    A("The Lost Runner", "Sentinel Kyra Starsong", 56.0, 59.5, 5),
    T("Crown of the Earth", "Corithras Moonrage", 56.2, 61.6, 5, 2),
    A("Crown of the Earth", "Corithras Moonrage", 56.2, 61.6, 5, 3),
    T("Camping 101: Cooking", "Zarrin (cooking trainer)", 57.1, 61.3, 5),
    A("Recipe of the Kaldorei", "Zarrin", 57.1, 61.3, 5),

    -- Lake Al'Ameth
    T("Denalan's Earth", "Denalan, Lake Al'Ameth", 60.8, 68.5, 6),
    A("Timberling Seeds", "Denalan", 60.8, 68.5, 6),
    A("Timberling Sprouts", "Denalan", 60.8, 68.5, 6),
    D("Timberling Seeds", "8 Timberling Seeds from Timberlings around the lake", 59.1, 70.4, 6),
    D("Timberling Sprouts", "12 Timberling Sprouts on the ground around the lake", 59.2, 70.8, 6),
    T("Timberling Seeds", "Denalan", 60.8, 68.5, 7),
    T("Timberling Sprouts", "Denalan", 60.8, 68.5, 7),
    A("Rellian Greenspyre", "Denalan", 60.8, 68.5, 7),

    -- Starbreeze Village
    D("The Emerald Dreamcatcher", "Tallonkai's Dresser in the house in Starbreeze", 68.0, 59.5, 7),
    T("A Troubling Breeze", "Gaerolas Talvethren, Starbreeze", 66.3, 58.7, 7),
    A("Gnarlpine Corruption", "Gaerolas Talvethren", 66.3, 58.7, 7),
    D("Crown of the Earth", "Fill the Jade Phial at the Starbreeze moonwell", 63.5, 58.0, 7, 3),
    D("Zenn's Bidding", "3 Nightsaber Fangs, 3 Strigid Owl Feathers, 3 Webwood Spider Silk", 62.4, 62.6, 7),
    D("Soft Saber Pelts", "6 Soft Nightsaber Pelts from nightsabers", 62.2, 59.8, 7),
    D("Recipe of the Kaldorei", "7 Small Spider Legs from Webwood spiders", 61.0, 58.0, 7),
    T("Zenn's Bidding", "Zenn Foulhoof", 60.4, 56.3, 7),
    T("Gnarlpine Corruption", "Athridas Bearmantle", 55.9, 57.4, 7),
    A("The Relics of Wakening", "Athridas Bearmantle", 55.9, 57.4, 7),
    A("Seek Redemption!", "Syral Bladeleaf", 56.1, 57.7, 7),
    T("The Emerald Dreamcatcher", "Tallonkai Swiftroot", 55.5, 56.9, 7),
    A("Ferocitas the Dream Eater", "Tallonkai Swiftroot", 55.5, 56.9, 7),
    T("Soft Saber Pelts", "Aldia", 55.6, 57.1, 7),
    T("Recipe of the Kaldorei", "Zarrin", 57.1, 61.3, 7),
    D("Ferocitas the Dream Eater", "Kill 7 Gnarlpine Mystics and Ferocitas for the Missing Jewel", 68.8, 53.8, 8),
    D("Seek Redemption!", "3 Fel Cones by the trees", 65.8, 52.2, 8),
    T("Seek Redemption!", "Zenn Foulhoof", 60.5, 56.3, 8),

    -- Fel Rock and back to Dolanaar
    D("Twisted Hatred", "Kill Lord Melenas inside Fel Rock (entrance 54.4, 51.2) for his head", 52.0, 49.2, 8, 1),
    T("Crown of the Earth", "Corithras Moonrage", 56.2, 61.7, 8, 3),
    A("Crown of the Earth", "Corithras Moonrage", 56.2, 61.7, 8, 4),
    T("Twisted Hatred", "Tallonkai Swiftroot", 55.5, 56.9, 8, 1),
    T("Ferocitas the Dream Eater", "Tallonkai Swiftroot", 55.5, 56.9, 8),
    A("The Road to Darnassus", "Moon Priestess Amara (patrols the road)", 55.3, 58.4, 8),

    -- Pools of Arlithrien
    D("Crown of the Earth", "Fill the Tourmaline Phial at the Pools of Arlithrien moonwell", 42.5, 67.0, 8, 4),
    A("The Glowing Fruit", "Strange Fruited Plant (object)", 42.7, 76.1, 8),
    T("Crown of the Earth", "Corithras Moonrage", 56.2, 61.7, 9, 4),
    A("Crown of the Earth", "Corithras Moonrage", 56.2, 61.7, 9, 5),

    -- The road to Darnassus
    D("The Road to Darnassus", "Kill 6 Gnarlpine Ambushers along the road", 46.4, 53.8, 9),
    A("Bounty: Gnarlpine Furbolg", "Sentinel Shayla Nightbreeze (on the road)", 41.1, 50.9, 9),
    D("Bounty: Gnarlpine Furbolg", "15 Gnarlpine Fangs from Gnarlpine furbolgs (road, Ban'ethil, Starbreeze); finish later in the Barrow Den", 46.4, 53.3, 9),
    T("Camping 101: Skinning", "Radnaal Maneweaver (optional: on the road to Darnassus, needs Skinning 20)", 42.0, 50.0, 9),
    G("Enter Darnassus", 36.5, 52.5, 9, "Follow the road west into the city"),
    T("Rellian Greenspyre", "Rellian Greenspyre, Darnassus (Cenarion Enclave)", 38.2, 21.6, 9),
    A("Tumors", "Rellian Greenspyre, Darnassus", 38.2, 21.6, 9),
    T("The Sisterhood of Elune", "Sister Aquinne, Darnassus", 28.9, 45.8, 9),
    A("The Temple of the Moon", "Sister Aquinne, Darnassus", 28.9, 45.8, 9),
    T("The Temple of the Moon", "Priestess A'moora, Darnassus (Temple of the Moon)", 36.6, 85.9, 9),
    A("Tears of the Moon", "Priestess A'moora, Darnassus", 36.6, 85.9, 9),

    -- The Oracle Glade, first pass
    T("The Lost Runner", "Sentinel Eralya Leafshadow (on the road to the Oracle Glade)", 37.6, 36.8, 9),
    A("Not Dead Yet", "Sentinel Eralya Leafshadow", 37.6, 36.8, 9),
    A("The Enchanted Glade", "Sentinel Arynia Cloudsbreak", 38.3, 34.4, 9),
    D("Crown of the Earth", "Fill the Amethyst Phial at the Oracle Glade moonwell", 38.5, 34.0, 9, 5),
    A("The Shimmering Frond", "Strange Fronded Plant (object)", 34.7, 29.0, 9),
    A("Mist", "Mist (ESCORT: lead the cub to Arynia at the moonwell)", 31.5, 31.6, 9),
    T("Mist", "Sentinel Arynia Cloudsbreak", 38.3, 34.4, 9),
    A("The Moss-twined Heart", "Moss-twined Heart (drops from Blackmoss the Fetid, rare; skip if too strong)", 44.0, 30.2, 9),
    T("The Road to Darnassus", "Moon Priestess Amara", 55.0, 58.5, 10),
    T("Crown of the Earth", "Corithras Moonrage", 56.2, 61.7, 10, 5),
    A("Crown of the Earth", "Corithras Moonrage", 56.2, 61.7, 10, 6),
    T("Not Dead Yet", "Byancie", 55.3, 56.8, 10),
    A("The Great Tree Provides", "Byancie", 55.3, 56.8, 10),
    D("The Great Tree Provides", "Buy an Empty Vial (Narret Shadowgrove) and Refreshing Spring Water (Innkeeper Keldamyr)", 55.5, 57.0, 10),

    -- Lake Al'Ameth again
    T("The Glowing Fruit", "Denalan", 60.9, 68.4, 10),
    T("The Shimmering Frond", "Denalan", 60.9, 68.4, 10),
    T("The Moss-twined Heart", "Denalan", 60.9, 68.4, 10),
    A("Planting the Heart", "Denalan", 60.9, 68.4, 10),
    T("Planting the Heart", "Denalan's Planter (object next to Denalan)", 60.8, 68.6, 10),
    A("The Sprouted Fronds", "Sprouted Frond (by Denalan's planter)", 60.8, 68.6, 10),
    T("The Sprouted Fronds", "Denalan", 60.8, 68.5, 10),
    D("The Great Tree Provides", "6 Dewy Lasher Fronds from lashers around the lake", 60.7, 68.9, 10),
    T("The Great Tree Provides", "Byancie", 55.3, 56.8, 10),
    A("Easing Suffering", "Byancie", 55.3, 56.8, 10),
    A("Twisted Hatred", "Tallonkai Swiftroot", 55.5, 56.9, 10, 2),

    -- The Cleft and the Oracle Glade, second pass
    D("Twisted Hatred", "Kill 8 Befouled Webwoods and Xethorr the Wicked (elite, small cave at 51.4, 44.2) for Mature Fel Moss; group up", 49.8, 42.5, 10, 2),
    T("Easing Suffering", "Sentinel Eralya Leafshadow", 37.6, 36.8, 11),
    D("Tumors", "5 Mossy Tumors from Timberling Mire Beasts and Elder Timberlings", 41.0, 31.0, 11),
    D("Tears of the Moon", "Kill Lady Sathrah for her Silvery Spinnerets (she has several spawn points)", 39.5, 25.5, 11),
    D("The Enchanted Glade", "6 Bloodfeather Belts from the harpies", 33.5, 29.9, 11),
    T("The Enchanted Glade", "Sentinel Arynia Cloudsbreak", 38.3, 34.4, 11),
    A("Darkness in the Glade", "Sentinel Arynia Cloudsbreak", 38.3, 34.4, 11),
    D("Darkness in the Glade", "Amulets from Hatescreech, Windmistress Gaedress and Witchmother Arysa in the harpy nests", 35.0, 38.5, 11),
    T("Darkness in the Glade", "Sentinel Arynia Cloudsbreak", 38.3, 34.4, 11),
    A("The Oracle Tree", "Sentinel Arynia Cloudsbreak", 38.3, 34.4, 11),
    T("The Oracle Tree", "Oracle Tree Bark (object under the Oracle Tree)", 37.0, 34.1, 11),
    A("Teldrassil", "Oracle Tree Bark (object under the Oracle Tree)", 37.0, 34.1, 11),

    -- Darnassus
    G("Enter Darnassus", 36.5, 52.5, 11, "Darnassus uses its own map from here"),
    T("Crown of the Earth", "Arch Druid Fandral Staghelm, Darnassus (Cenarion Enclave)", 34.8, 9.3, 11, 6),
    A("Crown of the Earth", "Arch Druid Fandral Staghelm, Darnassus", 34.8, 9.3, 11, 7),
    T("Teldrassil", "Arch Druid Fandral Staghelm, Darnassus", 34.8, 9.3, 11),
    T("Tumors", "Rellian Greenspyre, Darnassus", 38.2, 21.6, 11),
    A("Return to Denalan", "Rellian Greenspyre, Darnassus", 38.2, 21.6, 11),
    A("Nessa Shadowsong", "Mydrannul, Darnassus (Tradesmen's Terrace)", 70.7, 45.4, 11),
    T("Crown of the Earth", "Lariia, Darnassus (Temple of the Moon)", 40.4, 88.7, 11, 7),
    A("Crown of the Earth", "Lariia, Darnassus", 40.4, 88.7, 11, 8),
    T("Crown of the Earth", "Tyrande Whisperwind, Darnassus (upper Temple of the Moon)", 39.1, 81.6, 11, 8),
    T("Tears of the Moon", "Priestess A'moora, Darnassus", 36.6, 85.9, 11),
    A("Sathrah's Sacrifice", "Priestess A'moora, Darnassus", 36.6, 85.9, 11),
    D("Sathrah's Sacrifice", "Place the Silvery Spinnerets at the fountain inside the Temple, Darnassus", 38.5, 86.0, 11),
    T("Sathrah's Sacrifice", "Priestess A'moora, Darnassus", 36.6, 85.9, 11),

    -- Back to Lake Al'Ameth
    T("Return to Denalan", "Denalan", 60.8, 68.4, 11),
    A("Oakenscowl", "Denalan", 60.8, 68.4, 11),
    D("Oakenscowl", "Kill Oakenscowl (elite) in the cave southwest of the lake for the Gargantuan Tumor", 53.0, 74.5, 11),
    T("Oakenscowl", "Denalan", 60.9, 68.4, 11),
    T("Twisted Hatred", "Tallonkai Swiftroot", 55.5, 56.9, 11, 2),

    -- Ban'ethil Barrow Den
    G("Ban'ethil Barrow Den, through the hollow tree", 44.9, 61.5, 11, "Lots of furbolgs: finish the Gnarlpine Fangs here"),
    A("The Sleeping Druid", "Oben Rageclaw (in the den)", 44.9, 61.5, 11),
    D("The Relics of Wakening", "Four relic chests in the den (Black Feather Quill, Rune of Nesting, Sapphire of Sky, Raven Claw Talisman)", 44.0, 61.0, 11),
    D("The Sleeping Druid", "Shaman Voodoo Charm from Gnarlpine Shamans", 44.8, 59.8, 11),
    T("The Sleeping Druid", "Oben Rageclaw", 44.9, 61.5, 11),
    A("Druid of the Claw", "Oben Rageclaw", 44.9, 61.5, 11),
    D("Druid of the Claw", "Kill Rageclaw, then use the Voodoo Charm on his body", 45.2, 58.5, 11),
    T("Druid of the Claw", "Oben Rageclaw", 44.9, 61.5, 11),
    A("Escaping Ban'ethil", "Sentinel Lynessa Duskblossom (ESCORT: keep her close)", 44.7, 58.9, 11),
    D("Escaping Ban'ethil", "Escort Lynessa out of the Barrow Den", 43.7, 61.2, 11),
    T("Escaping Ban'ethil", "Sentinel Kyra Starsong, Dolanaar", 56.1, 59.5, 12),
    T("The Relics of Wakening", "Athridas Bearmantle", 55.9, 57.3, 12),
    A("Ursal the Mauler", "Athridas Bearmantle", 55.9, 57.3, 12),
    D("Ursal the Mauler", "Kill Ursal in Gnarlpine Hold (about 20 furbolgs around him)", 39.2, 80.0, 12),
    T("Ursal the Mauler", "Athridas Bearmantle", 55.9, 57.4, 12),

    -- Out through Darnassus to Rut'theran Village
    T("Bounty: Gnarlpine Furbolg", "Sentinel Shayla Nightbreeze (by the Darnassus road)", 38.3, 54.4, 12),
    G("Darnassus: take the purple portal on the west side down to Rut'theran Village", 36.5, 52.5, 12),
    T("Nessa Shadowsong", "Nessa Shadowsong, Rut'theran Village", 56.3, 92.3, 12),
    A("The Bounty of Teldrassil", "Nessa Shadowsong", 56.3, 92.3, 12),
    T("The Bounty of Teldrassil", "Vesprystus (flight master)", 58.4, 94.0, 12),
    A("Flight to Auberdine", "Vesprystus", 58.4, 94.0, 12),
    G("Fly to Auberdine, Darkshore", 58.4, 93.9, 12, "Vesprystus, the flight master"),
} }

-- Darkshore (WoW Forever 1.60.x), Night Elf path from Teldrassil.
-- Sources: wow4ever.quest (Questie Forever data, client 1.60.1.70790), wowhead.com/forever quest text,
-- sageguide.net 11-19 Darkshore (Forever-aware route). Approximate coordinates are marked "approx" in notes.
-- Beached Sea Creature / Beached Sea Turtle parts are numbered in the order this route turns them in.
local DARKSHORE = { zone = "Darkshore", min = 11, max = 20, steps = {
    -- Auberdine arrival
    T("Flight to Auberdine", "Laird", 36.8, 44.3, 11),
    A("Buzzbox 827", "Wizbang Cranktoggle (upstairs in the inn)", 37.0, 44.1, 11),
    A("Washed Ashore", "Gwennyth Bly'Leggonde", 36.6, 45.6, 11, 1),
    A("The Family and the Fishing Pole", "Gubber Blump, on the dock", 36.1, 44.9, 11),
    A("For Love Eternal", "Cerellean Whiteclaw, on the dock", 35.7, 43.7, 11),
    A("WANTED: Jai'vhanel", "WANTED: Jai'vhanel (poster outside the inn)", 37.2, 44.2, 11),
    A("Plagued Lands", "Tharnariun Treetender", 38.8, 43.4, 11),
    A("How Big a Threat?", "Terenthis", 39.4, 43.5, 11, 1),
    A("Bashal'Aran", "Thundris Windweaver", 37.4, 40.1, 11, 1),
    A("Tools of the Highborne", "Thundris Windweaver", 37.4, 40.1, 11),
    -- Beach and bear hills south of town
    D("Buzzbox 827", "6 Crawler Legs from Pygmy Tide Crawlers and Young Reef Crawlers on the beach", 36.0, 48.5, 11),
    D("Washed Ashore", "Sea Creature Bones from the beached sea creature just south of Auberdine", 36.4, 50.9, 11, 1),
    D("Plagued Lands", "Use Tharnariun's Hope on a Rabid Thistle Bear and lead it back", 39.0, 50.5, 12),
    D("How Big a Threat?", "Find the corrupt furbolg camp southeast of town", 39.4, 53.4, 12, 1),
    D("The Family and the Fishing Pole", "Fish 6 Darkshore Grouper off the docks (buy a pole from Gubber)", 36.1, 45.4, 12),
    T("Buzzbox 827", "Buzzbox 827, on the beach south of the docks", 36.6, 46.3, 12),
    A("Buzzbox 411", "Buzzbox 827", 36.6, 46.3, 12),
    T("Washed Ashore", "Gwennyth Bly'Leggonde", 36.6, 45.6, 12, 1),
    A("Washed Ashore", "Gwennyth Bly'Leggonde", 36.6, 45.6, 12, 2),
    D("Washed Ashore", "Sea Turtle Remains from the Skeletal Sea Turtle in the water west of the docks", 31.8, 46.3, 12, 2),
    T("Washed Ashore", "Gwennyth Bly'Leggonde", 36.6, 45.6, 12, 2),
    T("The Family and the Fishing Pole", "Gubber Blump", 36.1, 44.9, 12),
    T("Plagued Lands", "Tharnariun Treetender", 38.8, 43.4, 12),
    A("Cleansing of the Infected", "Tharnariun Treetender", 38.8, 43.4, 12),
    T("How Big a Threat?", "Terenthis", 39.4, 43.5, 12, 1),
    A("How Big a Threat?", "Terenthis", 39.4, 43.5, 12, 2),
    A("Thundris Windweaver", "Terenthis", 39.4, 43.5, 12),
    T("Thundris Windweaver", "Thundris Windweaver", 37.4, 40.1, 12),
    A("The Cliffspring River", "Thundris Windweaver", 37.4, 40.1, 12),
    A("Cave Mushrooms", "Barithras Moonshade", 37.3, 43.6, 12),
    A("The Red Crystal", "Sentinel Glynda Nal'Shea", 37.7, 43.4, 12),
    -- Bashal'Aran
    T("Bashal'Aran", "Asterion", 44.2, 36.3, 12, 1),
    A("Bashal'Aran", "Asterion", 44.2, 36.3, 12, 2),
    D("Bashal'Aran", "8 Grell Earrings from Wild Grells and Vile Sprites", 44.6, 36.6, 12, 2),
    T("Bashal'Aran", "Asterion", 44.2, 36.3, 13, 2),
    A("Bashal'Aran", "Asterion", 44.2, 36.3, 13, 3),
    D("Bashal'Aran", "Ancient Moonstone Seal from Deth'ryll Satyrs", 45.5, 36.5, 13, 3),
    T("Bashal'Aran", "Asterion", 44.2, 36.3, 13, 3),
    A("Bashal'Aran", "Asterion", 44.2, 36.3, 13, 4),
    -- Red crystal, Blackwood camp, Ameth'Aran
    D("The Red Crystal", "Find the large red crystal on the eastern mountain wall", 47.3, 48.7, 13),
    D("How Big a Threat?", "Kill 8 Blackwood Pathfinders and 5 Blackwood Windtalkers", 39.6, 54.4, 13, 2),
    D("Cleansing of the Infected", "Kill 20 Rabid Thistle Bears (keep going all over the hills)", 39.0, 52.0, 13),
    A("The Fall of Ameth'Aran", "Sentinel Tysha Moonblade", 40.3, 59.7, 13),
    D("The Fall of Ameth'Aran", "Read The Lay of Ameth'Aran (43, 59) and The Fall of Ameth'Aran (42.5, 63)", 42.5, 63.0, 13),
    D("Bashal'Aran", "Destroy the Moonstone Seal at the Ancient Flame", 42.5, 62.0, 13, 4),
    D("Tools of the Highborne", "7 Highborne Relics from the ghosts in the ruins", 42.0, 61.0, 13),
    D("For Love Eternal", "Kill Anaya Dawnrunner for her pendant", 42.0, 60.5, 13),
    D("WANTED: Jai'vhanel", "Kill the black owl Jai'vhanel north of the ruins by the mountains for her feather (approx)", 43.5, 56.5, 13),
    T("The Fall of Ameth'Aran", "Sentinel Tysha Moonblade", 40.3, 59.7, 14),
    -- Auberdine
    T("How Big a Threat?", "Terenthis", 39.4, 43.5, 14, 2),
    A("A Lost Master", "Terenthis", 39.4, 43.5, 14, 1),
    T("Cleansing of the Infected", "Tharnariun Treetender", 38.8, 43.4, 14),
    A("Tharnariun's Hope", "Tharnariun Treetender", 38.8, 43.4, 14),
    T("Tools of the Highborne", "Thundris Windweaver", 37.4, 40.1, 14),
    T("For Love Eternal", "Cerellean Whiteclaw", 35.7, 43.7, 14),
    T("WANTED: Jai'vhanel", "Sentinel Glynda Nal'Shea", 37.7, 43.4, 14),
    T("The Red Crystal", "Sentinel Glynda Nal'Shea", 37.7, 43.4, 14),
    A("As Water Cascades", "Sentinel Glynda Nal'Shea", 37.7, 43.4, 14),
    D("As Water Cascades", "Fill the Empty Water Tube at the Auberdine moonwell (approx)", 37.8, 43.8, 14),
    A("The Tower of Althalaxx", "Sentinel Elissa Starbreeze", 39.0, 43.5, 14, 1),
    A("Deep Ocean, Vast Sea", "Gorbold Steelhand", 38.1, 41.2, 14),
    -- North coast, Cliffspring, the tower
    D("Deep Ocean, Vast Sea", "Silver Dawning's Lockbox (wreck at 38, 29) and Mist Veil's Lockbox (wreck at 39.5, 27.5)", 38.2, 28.8, 14),
    D("Buzzbox 411", "3 Thresher Eyes from Darkshore Threshers in the deep water", 40.0, 27.0, 14),
    T("Buzzbox 411", "Buzzbox 411, on the shore", 42.0, 28.6, 14),
    A("Buzzbox 323", "Buzzbox 411", 42.0, 28.6, 14),
    A("Beached Sea Creature", "Beached Sea Creature (click the bones)", 41.9, 31.5, 14, 1),
    T("Bashal'Aran", "Asterion", 44.2, 36.3, 14, 4),
    A("Beached Sea Turtle", "Beached Sea Turtle (click the remains)", 44.2, 20.6, 15, 1),
    D("Buzzbox 323", "6 Moonstalker Fangs from Moonstalker Runts and Moonstalkers", 46.0, 26.0, 15),
    D("The Cliffspring River", "Use the Empty Sampling Tube at the base of the first waterfall, by the bridge", 50.7, 25.5, 15),
    A("Beached Sea Turtle", "Beached Sea Turtle (click the remains)", 53.1, 18.1, 15, 2),
    T("The Tower of Althalaxx", "Balthule Shadowstrike", 55.0, 24.9, 15, 1),
    A("The Tower of Althalaxx", "Balthule Shadowstrike", 55.0, 24.9, 15, 2),
    D("The Tower of Althalaxx", "4 Worn Parchments from Dark Strand Fanatics", 55.8, 25.9, 15, 2),
    T("The Tower of Althalaxx", "Balthule Shadowstrike", 55.0, 24.9, 16, 2),
    A("The Tower of Althalaxx", "Balthule Shadowstrike (letter for Delgren at Maestra's Post, Ashenvale)", 55.0, 24.9, 16, 3),
    T("Buzzbox 323", "Buzzbox 323, near the bridge", 51.3, 24.6, 16),
    A("Buzzbox 525", "Buzzbox 323", 51.3, 24.6, 16),
    D("Cave Mushrooms", "5 Scaber Stalks and the Death Cap in the Cliffspring Falls cave", 55.0, 33.3, 16),
    T("As Water Cascades", "Mysterious Red Crystal", 47.3, 48.7, 16),
    A("The Fragments Within", "Mysterious Red Crystal", 47.3, 48.7, 16),
    -- Auberdine
    T("The Fragments Within", "Sentinel Glynda Nal'Shea", 37.7, 43.4, 16),
    T("Deep Ocean, Vast Sea", "Gorbold Steelhand", 38.1, 41.2, 16),
    T("The Cliffspring River", "Thundris Windweaver", 37.4, 40.1, 16),
    A("The Blackwood Corrupted", "Thundris Windweaver", 37.4, 40.1, 16),
    D("The Blackwood Corrupted", "Fill the Empty Cleansing Bowl at the Auberdine moonwell (approx)", 37.8, 43.8, 16),
    T("Cave Mushrooms", "Barithras Moonshade", 37.3, 43.6, 16),
    A("Onu", "Barithras Moonshade", 37.3, 43.6, 16),
    T("Beached Sea Creature", "Gwennyth Bly'Leggonde", 36.6, 45.6, 16, 1),
    T("Beached Sea Turtle", "Gwennyth Bly'Leggonde", 36.6, 45.6, 16, 1),
    T("Beached Sea Turtle", "Gwennyth Bly'Leggonde", 36.6, 45.6, 16, 2),
    A("The Absent Minded Prospector", "Archaeologist Hollee", 37.4, 41.8, 16, 1),
    A("WANTED: Murkdeep!", "WANTED: Murkdeep! (poster outside the inn)", 37.2, 44.2, 16),
    A("Fruit of the Sea", "Gubber Blump", 36.1, 44.9, 16),
    -- South coast, Remtravel, Grove of the Ancients, the Master's Glaive
    A("Beached Sea Turtle", "Beached Sea Turtle (click the remains)", 37.1, 62.2, 16, 3),
    A("Beached Sea Creature", "Beached Sea Creature (click the bones)", 36.0, 70.9, 16, 2),
    D("Fruit of the Sea", "6 Fine Crab Chunks from Reef Crawlers along the coast", 35.5, 73.2, 16),
    D("Buzzbox 525", "4 Grizzled Scalps from Grizzled Thistle Bears (approx)", 41.0, 70.0, 17),
    D("WANTED: Murkdeep!", "Clear the waves at the murloc camp; Murkdeep comes last (group)", 36.4, 76.5, 17),
    A("Beached Sea Creature", "Beached Sea Creature (click the bones)", 32.7, 80.8, 17, 3),
    A("Beached Sea Turtle", "Beached Sea Turtle (click the remains)", 31.7, 83.7, 17, 4),
    A("Beached Sea Turtle", "Beached Sea Turtle (click the remains)", 31.2, 85.6, 17, 5),
    A("Beached Sea Creature", "Beached Sea Creature (click the bones)", 31.3, 87.4, 17, 4),
    T("The Absent Minded Prospector", "Prospector Remtravel", 35.7, 83.7, 17, 1),
    A("The Absent Minded Prospector", "Prospector Remtravel (ESCORT)", 35.7, 83.7, 17, 2),
    D("The Absent Minded Prospector", "Protect Remtravel while he searches for the fossil", 35.7, 83.7, 17, 2),
    T("Onu", "Onu, Grove of the Ancients", 43.5, 76.3, 17),
    A("The Master's Glaive", "Onu", 43.5, 76.3, 17),
    A("Swelling Forces", "Arbal, Grove of the Ancients (coords approx)", 43.7, 76.5, 17),
    D("The Master's Glaive", "Go into the Master's Glaive and use the Phial of Scrying to make the Scrying Bowl", 38.5, 86.1, 17),
    T("The Master's Glaive", "Scrying Bowl", 38.5, 86.1, 17),
    A("The Twilight Camp", "Scrying Bowl", 38.5, 86.1, 17),
    T("The Twilight Camp", "Twilight Tome", 38.5, 86.0, 17),
    A("Return to Onu", "Twilight Tome", 38.5, 86.0, 17),
    A("It's All Fun and Games Until...", "Twilight Tome", 38.5, 86.0, 17),
    D("It's All Fun and Games Until...", "Peerless Eye from Twilight Disciples and Thugs at the Glaive", 38.5, 85.0, 17),
    A("Therylune's Escape", "Therylune (ESCORT, turn in at the Shrine of Aessina in Ashenvale)", 38.6, 87.3, 17),
    D("Therylune's Escape", "Escort Therylune out of the Twilight camp", 38.6, 87.3, 17),
    D("A Lost Master", "5 Fine Moonstalker Pelts from Moonstalker Sires and Matriarchs (approx)", 40.5, 80.0, 17, 1),
    T("Buzzbox 525", "Buzzbox 525", 41.4, 80.6, 18),
    T("Return to Onu", "Onu", 43.5, 76.3, 18),
    A("Mathystra Relics", "Onu", 43.5, 76.3, 18),
    -- Auberdine (hearth)
    T("WANTED: Murkdeep!", "Sentinel Glynda Nal'Shea", 37.7, 43.4, 18),
    T("Fruit of the Sea", "Gubber Blump", 36.1, 44.9, 18),
    T("The Absent Minded Prospector", "Archaeologist Hollee", 37.4, 41.8, 18, 2),
    T("A Lost Master", "Terenthis", 39.4, 43.5, 18, 1),
    A("A Lost Master", "Terenthis", 39.4, 43.5, 18, 2),
    T("It's All Fun and Games Until...", "Thundris Windweaver", 37.4, 40.1, 18),
    T("Beached Sea Creature", "Gwennyth Bly'Leggonde", 36.6, 45.6, 18, 2),
    T("Beached Sea Creature", "Gwennyth Bly'Leggonde", 36.6, 45.6, 18, 3),
    T("Beached Sea Creature", "Gwennyth Bly'Leggonde", 36.6, 45.6, 18, 4),
    T("Beached Sea Turtle", "Gwennyth Bly'Leggonde", 36.6, 45.6, 18, 3),
    T("Beached Sea Turtle", "Gwennyth Bly'Leggonde", 36.6, 45.6, 18, 4),
    T("Beached Sea Turtle", "Gwennyth Bly'Leggonde", 36.6, 45.6, 18, 5),
    A("Holy Diver", "Gwennyth Bly'Leggonde", 36.6, 45.6, 18),
    -- Blackwood camps, Den Mother, Gelkak, Ruins of Mathystra
    D("The Blackwood Corrupted", "Grain (50.6, 35.0), nut (51.8, 33.6) and fruit (52.9, 33.4) samples, then use the bowl at the bonfire and kill Xabraxxis for the Talisman", 52.4, 33.6, 18),
    D("Tharnariun's Hope", "Kill the Den Mother in the cave (kill her cubs first)", 51.8, 37.0, 18),
    A("Gyromast's Retrieval", "Gelkak Gyromast", 56.7, 13.5, 18),
    D("Gyromast's Retrieval", "Key pieces: bottom from Reef Crawlers, middle from Greymist murlocs, top from Giant Foreststriders (approx)", 55.0, 17.0, 18),
    T("Gyromast's Retrieval", "Gelkak Gyromast", 56.7, 13.5, 19),
    A("Gyromast's Revenge", "Gelkak Gyromast (ESCORT, it turns hostile at Gelkak; group)", 56.7, 13.5, 19),
    D("Gyromast's Revenge", "Talk to the Threshwackonator 4100 to the south and lead it back, then kill it (approx)", 53.6, 18.0, 19),
    T("Gyromast's Revenge", "Gelkak Gyromast", 56.7, 13.5, 19),
    D("Mathystra Relics", "6 Mathystra Relics in the Ruins of Mathystra", 58.5, 21.0, 19),
    D("Swelling Forces", "Kill 12 Stormscale Myrmidons, 8 Sorceresses and 6 Warriors at Mathystra", 58.6, 23.0, 19),
    D("Holy Diver", "Kill a Stormscale Beastmistress in the water by Mathystra for the Rod of Deep Dominion (approx)", 56.0, 18.0, 19),
    A("Baron Marinous", "Clouded Water Globe (ELITE 21, group: 20 Mathystral Amulet Fragments make the amulet, use it at the Fathom Stone)", 59.2, 22.6, 20),
    -- Auberdine
    T("The Blackwood Corrupted", "Thundris Windweaver", 37.4, 40.1, 20),
    T("Tharnariun's Hope", "Tharnariun Treetender", 38.8, 43.4, 20),
    T("Holy Diver", "Gwennyth Bly'Leggonde", 36.6, 45.6, 20),
    -- Grove of the Ancients and Volcor
    T("Mathystra Relics", "Onu", 43.5, 76.3, 20),
    T("Baron Marinous", "Onu", 43.5, 76.3, 20),
    T("Swelling Forces", "Arbal (coords approx)", 43.7, 76.5, 20),
    T("A Lost Master", "Volcor, in the furbolg cave", 45.0, 85.3, 20, 2),
    A("Escape Through Stealth", "Volcor (or take Escape Through Force, an ESCORT, if you are melee)", 45.0, 85.3, 20),
    D("Escape Through Stealth", "Follow Volcor out of the cave", 45.0, 85.3, 20),
    T("Escape Through Stealth", "Terenthis, Auberdine (hearth)", 39.4, 43.5, 20),
    A("Trek to Ashenvale", "Sentinel Selarin", 39.3, 43.5, 20),
    -- South to Ashenvale with the escorts
    A("The Sleeper Has Awakened", "Kerlonian Evershade (ESCORT, ends at Maestra's Post, Ashenvale)", 44.4, 76.4, 20),
    D("The Sleeper Has Awakened", "Horn of Awakening from Kerlonian's Chest beside him; blow it when he falls asleep", 44.4, 76.4, 20),
    A("One Shot. One Kill.", "Sentinel Aynasha (ESCORT, turn in at Maestra's Post, Ashenvale)", 45.9, 90.3, 20),
    D("One Shot. One Kill.", "Protect Aynasha from the furbolg waves", 45.9, 90.3, 20),
    G("Lead Kerlonian south down the road to Maestra's Post, Ashenvale", 44.0, 95.0, 20, "Liladris Moonriver, Delgren, Onaeya and Therysil are in Ashenvale"),
} }

-- Dun Morogh (Alliance) for WoW: Forever. Starts at level 6 after Coldridge Valley (Coldridge 1-5 is a separate route).
-- Sources: https://wow4ever.quest/en/quests/<slug> and /en/npcs/<slug> (Questie Forever data: IDs, givers, coords, min levels, "First you need");
-- https://foreverchanges.pro/quests/dun-morogh (66-quest Forever list, New/Changed/Elite tags) and /quest/<id> (givers and coords of the Forever-new quests,
-- whose wow4ever pages have no giver data); warcraft.wiki.gg only for Classic mob/cave positions (Vagash, Old Icebeard, Shimmer Ridge, Ironband's Compound).
-- Forever NEW quests routed: Grund and Gozwin, Flintfire's Shipment, Secure the Mountain (3), Dawn in the Mountains, Finding Warmth, Rime's Wrath (2),
-- Treacherous Cold, Frosthowl, Never Saddle on Quality, Stolen Blasting Powder (2), A Visitor to Dun Morogh, Farsen's Watch, Nip 'Em in the Bud, Underground Map.
-- Forever CHANGED: Tools for Steelgrill. ELITE: Protecting the Herd (Vagash), Tundra MacGrann's Stolen Stash (Old Icebeard's cave).
-- Part numbers: "Senir's Observations" 1-2 = 282, 420 (part 1 is the Coldridge leg, Grelin -> Thalos; this route turns in part 2 to Senir);
-- "Secure the Mountain" 1-3 = 98322, 98319, 98323; "Rime's Wrath" 1-2 = 99160, 99161; "Stolen Blasting Powder" 1-2 = 95213 (item start), 95214.
-- (Rime's Wrath and Stolen Blasting Powder: two separate Alliance quests each with the same title and different objectives, both obtained by
-- the player, not race variants; wowhead forever shows no series, so they are routed as parts 1-2 in walking order.)
-- Old Ironforge Incursion 96393 (level 16, follows Underground Map) left out: above this zone's band.
-- Left out: The Quarry's Smith 95217 (class-limited Warrior/Paladin/Shaman, needs 12 Copper Bars: profession quest); Rejold's New Brew 415 (breadcrumb
-- duplicate of Shimmer Stout); Data Hoarders 95041 (accepted and turned in in Ironforge, noted in the Ironforge G step); Distracting Jarven 308 /
-- Guarded Thunderbrew Barrel 403 (object flavour, no reward); The Treaty of Understanding 98423 and Old Ironforge Incursion 96393 (level 16, Hall of Thanes);
-- Search for Incendicite / Stonegear's Search (level 20+); Coldridge Valley quests (level 1-5 route); ram/mechanostrider exchanges (level 60).
-- Cross-zone: The Reports 291 (accepted from Senir, turned in to Senator Barin Redstone in Ironforge: G step); Stout to Kadrell 414 (accepted at the east
-- gate, turned in to Mountaineer Kadrell in Loch Modan: final G step).
local DUN_MOROGH = { zone = "Dun Morogh", min = 6, max = 13, steps = {
    -- Out of Coldridge Pass: Grund's camp south-west of Kharanos
    A("Grund and Gozwin", "Grund Drokda", 28.6, 67.5, 6),
    D("Grund and Gozwin", "Find Grund and Gozwin's camp in the hills to the north-west, loot Gozwin's Mechanic's Log and kill the Snow Leopard Prowler", 26.0, 63.0, 6),
    T("Grund and Gozwin", "Grund Drokda", 28.6, 67.5, 6),

    -- Kharanos
    T("Senir's Observations", "Senir Whitebeard, Kharanos", 46.7, 53.8, 6, 2),
    A("Secure the Mountain", "Senir Whitebeard", 46.7, 53.8, 6, 1),
    T("Supplies to Tannok", "Tannok Frosthammer (inn)", 47.2, 52.2, 6),
    A("Dawn in the Mountains", "Maxan Anvol (inn)", 47.3, 52.2, 6),
    A("Beer Basted Boar Ribs", "Ragnar Thunderbrew (buy a Rhapsody Malt from Innkeeper Belm)", 46.8, 52.4, 6),
    A("Tools for Steelgrill", "Tharek Blackstone", 46.0, 51.7, 6),
    A("Flintfire's Shipment", "Tognus Flintfire", 45.2, 52.0, 6),

    -- Steelgrill's Depot
    T("Tools for Steelgrill", "Beldin Steelgrill", 50.4, 49.1, 6),
    A("Stocking Jetsteam", "Pilot Bellowfiz", 49.4, 48.4, 6),
    A("The Grizzled Den", "Pilot Stonegear", 49.6, 48.6, 6),
    A("Ammo for Rumbleshot", "Loslor Rudge", 50.1, 49.4, 6),

    -- Fields south of Kharanos
    D("Stocking Jetsteam", "4 Chunks of Boar Meat from Crag Boars and 2 Thick Bear Furs from Young Black Bears in the snow fields south and south-west of Kharanos", 45.5, 56.0, 6),
    D("Beer Basted Boar Ribs", "6 Crag Boar Ribs from the same Crag Boars", 46.0, 57.0, 6),
    D("Ammo for Rumbleshot", "Pick up Rumbleshot's Ammo from the crate by the wrecked wagon", 44.1, 57.0, 7),
    T("Secure the Mountain", "Mountaineer Gretchen", 44.0, 57.0, 7, 1),
    A("Secure the Mountain", "Mountaineer Gretchen", 44.0, 57.0, 7, 2),
    T("Ammo for Rumbleshot", "Hegnar Rumbleshot", 40.7, 65.1, 7),

    -- The Grizzled Den
    D("The Grizzled Den", "8 Wendigo Manes from the Wendigos in the Grizzled Den", 40.8, 47.5, 7),
    D("Flintfire's Shipment", "Loot 8 Flintfire's Shipment crates dropped by the miners inside the den", 41.0, 47.0, 7),
    D("Secure the Mountain", "Find Mountaineer Cornelius inside the Grizzled Den and talk to him", 41.2, 46.8, 7, 2),
    T("Secure the Mountain", "Mountaineer Gretchen", 44.0, 57.0, 8, 2),
    A("Secure the Mountain", "Mountaineer Gretchen", 44.0, 57.0, 8, 3),

    -- Back in Kharanos and the depot
    T("Secure the Mountain", "Senir Whitebeard", 46.7, 53.8, 8, 3),
    A("Frostmane Hold", "Senir Whitebeard", 46.7, 53.8, 8),
    T("Beer Basted Boar Ribs", "Ragnar Thunderbrew", 46.8, 52.4, 8),
    T("Flintfire's Shipment", "Tognus Flintfire", 45.2, 52.0, 8),
    A("Operation Recombobulation", "Razzle Sprysprocket", 45.9, 49.4, 8),
    T("Stocking Jetsteam", "Pilot Bellowfiz", 49.4, 48.4, 8),
    A("Evershine", "Pilot Bellowfiz", 49.4, 48.4, 8),
    T("The Grizzled Den", "Pilot Stonegear", 49.6, 48.6, 8),

    -- Misty Pine Refuge (east of the depot)
    T("Dawn in the Mountains", "Father Gavin, Misty Pine Refuge", 57.7, 44.8, 8),
    A("Finding Warmth", "Father Gavin", 57.7, 44.8, 8),
    A("Rime's Wrath", "Father Gavin", 57.7, 44.8, 8, 1),
    A("Treacherous Cold", "Father Gavin", 57.7, 44.8, 8),
    D("Rime's Wrath", "Kill 10 Minor Ice Elementals around the frozen lake and the rockslide west of the refuge", 55.1, 45.4, 8, 1),
    D("Finding Warmth", "Pick up 14 Mostly Dry Firewood lying in the snow around the refuge", 56.5, 45.0, 8),
    D("Treacherous Cold", "Loot Stoneanvil's, Sunhammer's and Coalbeard's Rifles from the fallen mountaineers in the avalanche snow near the refuge", 56.0, 43.5, 9),
    T("Rime's Wrath", "Father Gavin", 57.7, 44.8, 9, 1),
    A("Rime's Wrath", "Father Gavin", 57.7, 44.8, 9, 2),
    D("Rime's Wrath", "Kill Avala, the large ice elemental near the rockslide, and loot Avala's Core", 55.0, 44.5, 9, 2),
    T("Rime's Wrath", "Father Gavin", 57.7, 44.8, 9, 2),
    T("Finding Warmth", "Father Gavin", 57.7, 44.8, 9),
    T("Treacherous Cold", "Father Gavin", 57.7, 44.8, 9),

    -- Brewnall Village (west)
    T("Evershine", "Rejold Barleybrew, Brewnall", 30.2, 45.7, 9),
    A("A Favor for Evershine", "Rejold Barleybrew", 30.2, 45.7, 9),
    A("The Perfect Stout", "Rejold Barleybrew", 30.2, 45.7, 9),
    A("Bitter Rivals", "Marleth Barleybrew", 30.2, 45.5, 9),
    A("Frosthowl", "Gretta Ganter", 31.5, 44.7, 9),
    D("A Favor for Evershine", "6 Ice Claw Bears, 8 Elder Crag Boars and 8 Snow Leopards around Brewnall and Iceflow Lake (keep killing them along the whole western loop)", 33.0, 47.0, 9),

    -- Gnomeregan, Shimmer Ridge and Frostmane Hold
    D("Operation Recombobulation", "8 Restabilization Cogs and 8 Gyromechanic Gears from the Leper Gnomes outside Gnomeregan", 27.6, 36.4, 9),
    D("The Perfect Stout", "6 Shimmerweed from the Shimmerweed Baskets in the Frostmane camp on Shimmer Ridge", 41.8, 35.3, 9),
    D("Frostmane Hold", "Go deep into Frostmane Hold (explore it) and kill 5 Frostmane Headhunters", 23.0, 52.0, 10),

    -- Tundra MacGrann and Old Icebeard's cave
    A("Tundra MacGrann's Stolen Stash", "Tundra MacGrann (ELITE cave)", 34.6, 51.6, 10),
    D("Tundra MacGrann's Stolen Stash", "Open MacGrann's Meat Locker in Old Icebeard's cave; Old Icebeard is ELITE, group or sneak past him", 38.5, 53.9, 10),
    T("Tundra MacGrann's Stolen Stash", "Tundra MacGrann", 34.6, 51.6, 10),
    D("Frosthowl", "Kill Frosthowl, the wendigo deep in the Grizzled Den, and loot the Sack of Fish", 41.5, 46.5, 10),

    -- Kharanos: distillery basement, Senir
    T("Bitter Rivals", "Unguarded Thunder Ale Barrel (Thunderbrew Distillery basement)", 47.7, 52.7, 10),
    A("Return to Marleth", "Unguarded Thunder Ale Barrel (object)", 47.7, 52.7, 10),
    T("Operation Recombobulation", "Razzle Sprysprocket", 45.9, 49.4, 10),
    T("Frostmane Hold", "Senir Whitebeard", 46.7, 53.8, 10),
    A("The Reports", "Senir Whitebeard (turn-in is in Ironforge)", 46.7, 53.8, 10),

    -- Brewnall Village again
    T("Return to Marleth", "Marleth Barleybrew", 30.2, 45.5, 10),
    T("Frosthowl", "Gretta Ganter", 31.5, 44.7, 10),
    T("A Favor for Evershine", "Rejold Barleybrew", 30.2, 45.7, 10),
    A("Return to Bellowfiz", "Rejold Barleybrew", 30.2, 45.7, 10),
    T("The Perfect Stout", "Rejold Barleybrew", 30.2, 45.7, 10),
    A("Shimmer Stout", "Rejold Barleybrew (turn-in at the east gate)", 30.2, 45.7, 10),

    -- Steelgrill's Depot and Ironforge
    T("Return to Bellowfiz", "Pilot Bellowfiz", 49.4, 48.4, 10),
    A("A Visitor to Dun Morogh", "Beldin Steelgrill", 50.4, 49.1, 10),
    G("Ironforge gate", 52.8, 36.0, 10, "In Ironforge turn in The Reports to Senator Barin Redstone (39.5, 57.5); optional: Data Hoarders from Jemma Quikswitch in Tinker Town (68.2, 44.6): 7 Gnomeregan Archival Data in the snow outside Gnomeregan"),

    -- Amberstill Ranch
    A("Never Saddle on Quality", "Rudra Amberstill", 63.1, 49.9, 10),
    A("Protecting the Herd", "Rudra Amberstill (ELITE Vagash, done at 12)", 63.1, 49.9, 10),
    D("Never Saddle on Quality", "6 Pristine Leopard Pelts from the big Snow Leopards east of the ranch, toward Helm's Bed Lake", 70.0, 49.0, 11),

    -- Gol'Bolar Quarry
    A("Those Blasted Troggs!", "Foreman Stonebrow", 69.1, 56.3, 11),
    A("The Public Servant", "Senator Mehr Stonehallow", 68.7, 56.0, 11),
    D("Those Blasted Troggs!", "6 Rockjaw Skullthumpers in and east of the quarry", 69.7, 57.1, 11),
    D("The Public Servant", "10 Rockjaw Bonesnappers in the quarry", 70.7, 56.6, 11),
    A("Stolen Blasting Powder", "Empty Powder Keg (item, drops from the Rockjaw troggs east of the quarry)", 68.1, 56.2, 11, 1),
    T("Stolen Blasting Powder", "Quarrymaster Thesten", 69.0, 54.8, 11, 1),
    A("Stolen Blasting Powder", "Quarrymaster Thesten", 69.0, 54.8, 11, 2),
    D("Stolen Blasting Powder", "16 Stolen Blasting Powder from Rockjaw Backbreakers, Skullthumpers and Ambushers just east of the quarry", 68.5, 55.0, 11, 2),
    T("Stolen Blasting Powder", "Quarrymaster Thesten", 69.0, 54.8, 11, 2),
    T("Those Blasted Troggs!", "Foreman Stonebrow", 69.1, 56.3, 11),
    T("The Public Servant", "Senator Mehr Stonehallow", 68.7, 56.0, 11),

    -- Farsen's camp above the quarry
    D("A Visitor to Dun Morogh", "Investigate the campsite on the hill overlooking the quarry (Earthseer Farsen)", 64.9, 58.4, 11),
    T("A Visitor to Dun Morogh", "Earthseer Farsen", 64.9, 58.4, 11),
    A("Farsen's Watch", "Earthseer Farsen", 64.9, 58.4, 11),
    D("Farsen's Watch", "Use Farsen's Farsight (quest item) at the camp", 64.9, 58.4, 11),
    T("Farsen's Watch", "Earthseer Farsen", 64.9, 58.4, 11),
    A("Nip 'Em in the Bud", "Earthseer Farsen", 64.9, 58.4, 11),

    -- Ironband's Compound (south of Helm's Bed Lake)
    D("Nip 'Em in the Bud", "Kill 10 Dark Iron Spies at Ironband's Compound", 77.5, 61.0, 12),
    A("Underground Map", "Dark Iron Map (item, drops from the Dark Iron dwarves at Ironband's Compound)", 77.5, 61.0, 12),
    T("Nip 'Em in the Bud", "Earthseer Farsen", 64.9, 58.4, 12),
    T("Underground Map", "Earthseer Farsen", 64.9, 58.4, 12),

    -- Amberstill Ranch: Vagash
    T("Never Saddle on Quality", "Rudra Amberstill", 63.1, 49.9, 12),
    D("Protecting the Herd", "Kill Vagash on the overlook just west of the ranch and loot the Fang of Vagash (ELITE, group)", 62.3, 46.9, 12),
    T("Protecting the Herd", "Rudra Amberstill", 63.1, 49.9, 12),

    -- North Gate: the lost pilot
    A("The Lost Pilot", "Pilot Hammerfoot", 83.9, 39.2, 12),
    D("The Lost Pilot", "Find Pilot Hildelve's body (A Dwarven Corpse) north-west of the North Gate outpost", 79.7, 36.2, 12),
    T("The Lost Pilot", "A Dwarven Corpse", 79.7, 36.2, 12),
    A("A Pilot's Revenge", "A Dwarven Corpse", 79.7, 36.2, 12),
    D("A Pilot's Revenge", "Kill Mangeclaw, the bear roaming near the body", 78.3, 37.8, 13),
    T("A Pilot's Revenge", "Pilot Hammerfoot", 83.9, 39.2, 13),

    -- East gate to Loch Modan
    T("Shimmer Stout", "Mountaineer Barleybrew (east gate)", 86.3, 48.8, 13),
    A("Stout to Kadrell", "Mountaineer Barleybrew (turn-in in Loch Modan)", 86.3, 48.8, 13),
    G("Loch Modan, through the east gate", 87.5, 48.8, 13, "Turn in Stout to Kadrell to Mountaineer Kadrell on the Thelsamar road (Loch Modan 34.2, 47.8)"),
} }

-- Loch Modan (Alliance) for WoW: Forever.
-- Sources: https://wow4ever.quest/en/quests/<slug> and /en/npcs/<slug> (Questie Forever 1.60.1 data: IDs, min levels, givers, coords, "First you need");
-- https://foreverchanges.pro/quests/loch-modan (48-quest Forever list, New/Changed/Elite tags) and /quest/<id> (New quests' givers/coords);
-- https://www.wowhead.com/forever/quest=<id> (A Dark Threat Looms series order, objectives); warcraft.wiki.gg only for mob/object
-- locations (Grawmug, Ol' Sooty, Berserk Trogg, Bingles' items) - mob-area coordinates of D steps are approximate.
-- Part numbers: "In Defense of the King's Lands" 1-4 = 224, 237, 263, 217 (all four are the southern guard tower chain: Cobbleflint, Gravelgaw, Wallbang, Rugelfuss);
--   "Vyrin's Revenge" 1-2 = 271, 531 (ELITE in Forever); "A Dark Threat Looms" 1-7 = 250, 199, 161, 274, 278, 280, 283 - this route does parts 1-3 only
--   (part 3 = 161 is turned in to Ashlan Stonesmirk in Dun Modr, Wetlands; parts 4-7 come back to Hinderweir and are not routed).
-- Forever NEW quests routed: Snowbound (86667), Silver of the Waves (86614), Banner of the Fallen (86585), Twisting the Knife (86758).
-- Left out: Excavation Tools (86613, item-started, source unknown), Stonesplinter Trogg Disguise (912, no giver data), Stormpike's Delivery (353, starts in Stormwind),
--   Find Bingles (2039, starts in Ironforge - optional pick-up noted in the Ironforge leg), Ingredients for the Forge (86776, lvl 30), Eagle's Fist (79975, lvl 32 both-faction chain),
--   Badlands Reagent Run I/II, Proof of Deed (lvl 39-48), A Dark Threat Looms parts 4-7.
-- Cross-zone: Stout to Kadrell (414) is accepted in Dun Morogh (Mountaineer Barleybrew) and turned in here; Ride to Ironforge / Gryth Thurden / Return to Brock,
--   Report to Ironforge / Powder to Ironband are the Ironforge leg (G steps); Stormpike's Order ends in Stormwind (Furen Longbeard); A Dark Threat Looms part 3 ends in Wetlands.
local LOCH_MODAN = { zone = "Loch Modan", min = 10, max = 20, steps = {
    -- Thelsamar (arriving from Dun Morogh through South Gate Pass)
    T("Stout to Kadrell", "Mountaineer Kadrell", 34.2, 47.8, 10),
    A("Rat Catching", "Mountaineer Kadrell", 34.2, 47.8, 10),
    A("Mountaineer Stormpike's Task", "Mountaineer Kadrell", 34.2, 47.8, 10),
    A("Thelsamar Blood Sausages", "Vidra Hearthstove (inn)", 34.8, 49.3, 10),
    A("Honor Students", "Brock Stoneseeker", 37.0, 47.8, 10),
    A("Snowbound", "Grenhild Darktalon (NEW; gives a Ceramic Jar)", 36.5, 48.3, 10),
    T("Honor Students", "Thorgrum Borrelson (flight master)", 33.9, 51.0, 10),
    A("Ride to Ironforge", "Thorgrum Borrelson (turned in in Ironforge later)", 33.9, 51.0, 10),

    -- South: the hills, South Gate Pass and Stonesplinter Valley (first trip)
    D("Thelsamar Blood Sausages", "Kill Black Bears, Mountain Boars and Forest Lurkers in the hills south of Thelsamar: 3 Bear Meat, 3 Boar Intestines, 3 Spider Ichor", 29.0, 58.0, 11),
    D("Snowbound", "Scoop snow into the Ceramic Jar at the tunnel entrance of South Gate Pass (west exit to Dun Morogh)", 20.5, 73.0, 11),
    A("In Defense of the King's Lands", "Mountaineer Cobbleflint (southern guard tower)", 22.1, 73.1, 11, 1),
    A("The Trogg Threat", "Captain Rugelfuss", 23.2, 73.7, 11),
    D("In Defense of the King's Lands", "Kill 10 Stonesplinter Troggs and 10 Stonesplinter Scouts at the mouth of Stonesplinter Valley", 31.5, 72.1, 12, 1),
    D("The Trogg Threat", "Loot 8 Trogg Stone Teeth from the Stonesplinter troggs", 31.5, 72.1, 12),
    T("The Trogg Threat", "Captain Rugelfuss", 23.2, 73.7, 12),
    T("In Defense of the King's Lands", "Mountaineer Cobbleflint", 22.1, 73.1, 12, 1),
    A("In Defense of the King's Lands", "Mountaineer Gravelgaw (inside the tower)", 23.5, 76.4, 12, 2),
    D("In Defense of the King's Lands", "Kill 10 Stonesplinter Skullthumpers and 10 Stonesplinter Seers deeper in Stonesplinter Valley", 34.0, 78.0, 13, 2),
    T("In Defense of the King's Lands", "Mountaineer Gravelgaw", 23.5, 76.4, 13, 2),
    T("Thelsamar Blood Sausages", "Vidra Hearthstove", 34.8, 49.3, 13),

    -- North: Algaz Station, Silver Stream Mine and the north-west shore
    T("Mountaineer Stormpike's Task", "Mountaineer Stormpike (Algaz Station)", 24.8, 18.4, 13),
    A("Filthy Paws", "Mountaineer Stormpike", 24.8, 18.4, 13),
    A("Stormpike's Order", "Mountaineer Stormpike (turn-in is Furen Longbeard, Stormwind)", 24.8, 18.4, 13),
    D("Filthy Paws", "Open 4 Miners' Gear crates inside Silver Stream Mine", 35.6, 23.5, 13),
    D("Rat Catching", "Kill Tunnel Rat kobolds in and around Silver Stream Mine for 12 Tunnel Rat Ears", 35.6, 23.5, 13),
    T("Filthy Paws", "Mountaineer Stormpike", 24.8, 18.4, 14),
    T("Snowbound", "Norric Lochthane (house on the north-west shore of the Loch)", 41.9, 19.0, 14),
    A("Silver of the Waves", "Discarded Fishing Toolbox (NEW; object in the lake wreckage west shore, may also sit at 45.6,43.4 / 48.9,54.2)", 48.0, 39.7, 14),
    T("Silver of the Waves", "Khara Deepwater (dock below Thelsamar)", 40.4, 39.4, 14),
    T("Rat Catching", "Mountaineer Kadrell", 34.2, 47.8, 14),
    A("Ironband's Excavation", "Jern Hornhelm", 37.2, 47.4, 14),

    -- East: Ironband's Excavation Site (first visit)
    T("Ironband's Excavation", "Magmar Fellhew", 64.9, 66.7, 14),
    A("Gathering Idols", "Magmar Fellhew", 64.9, 66.7, 14),
    D("Gathering Idols", "Kill Berserk and Stonesplinter troggs around the excavation for 8 Carved Stone Idols (keep any Excavation Tools that drop: NEW quest for Fellhew)", 67.0, 63.5, 15),
    T("Gathering Idols", "Magmar Fellhew", 64.9, 66.7, 15),
    A("Excavation Progress Report", "Prospector Ironband", 65.9, 65.6, 15),

    -- Thelsamar and the Ironforge round trip (gryphon from Thorgrum Borrelson)
    T("Excavation Progress Report", "Jern Hornhelm", 37.2, 47.4, 15),
    A("Report to Ironforge", "Jern Hornhelm", 37.2, 47.4, 15),
    G("Fly to Ironforge from Thorgrum Borrelson (buy the ride: Ride to Ironforge)", 33.9, 51.0, 15, "Ironforge: turn in Ride to Ironforge and take Gryth Thurden from Golnir Bouldertoe (51.5, 26.3, Deeprun Tram side)"),
    G("Ironforge: Hall of Explorers", 33.9, 51.0, 15, "Turn in Report to Ironforge and take Powder to Ironband from Prospector Stormpike (74.6, 11.7, Hall of Explorers). Optional: Find Bingles from Gnoarn (69.2, 50.5, Tinker Town)"),
    G("Ironforge: Gryth Thurden and fly back to Thelsamar", 33.9, 51.0, 15, "Turn in Gryth Thurden and take Return to Brock from Gryth Thurden (55.5, 47.7, flight master), then fly to Thelsamar"),
    T("Return to Brock", "Brock Stoneseeker", 37.0, 47.8, 15),
    T("Powder to Ironband", "Jern Hornhelm", 37.2, 47.4, 15),
    A("Resupplying the Excavation", "Jern Hornhelm", 37.2, 47.4, 15),
    A("Mercenaries", "Magistrate Bluntnose (ELITE ogres, group)", 34.6, 44.5, 15),

    -- South: Stonesplinter Valley (second trip: the tower's last two parts and Ylva's banner)
    A("In Defense of the King's Lands", "Mountaineer Wallbang (inside the tower)", 23.5, 74.5, 15, 3),
    D("In Defense of the King's Lands", "Kill 10 Stonesplinter Shamans and 10 Stonesplinter Bonesnappers in the back of Stonesplinter Valley", 36.3, 89.5, 16, 3),
    T("In Defense of the King's Lands", "Mountaineer Wallbang", 23.5, 74.5, 16, 3),
    A("In Defense of the King's Lands", "Captain Rugelfuss", 23.2, 73.7, 16, 4),
    A("Banner of the Fallen", "Mountaineer Ylva (NEW; her body, deep in Stonesplinter Valley)", 31.8, 86.4, 16),
    D("Banner of the Fallen", "Raise the Banner of Ironforge next to Ylva's body, kill Headsplitter when he comes", 32.1, 87.1, 16),
    D("In Defense of the King's Lands", "Kill Grawmug and his guards Gnasher and Brawler in the innermost trogg cave of Stonesplinter Valley", 34.7, 90.6, 16, 4),
    T("In Defense of the King's Lands", "Captain Rugelfuss", 23.2, 73.7, 16, 4),
    T("Banner of the Fallen", "Captain Rugelfuss", 23.2, 73.7, 16),

    -- The ambushed caravan on the south-east road and the escort to the excavation
    T("Resupplying the Excavation", "Huldar", 52.2, 69.3, 16),
    A("After the Ambush", "Huldar", 52.2, 69.3, 16),
    T("After the Ambush", "Miran", 52.2, 69.4, 16),
    A("Protecting the Shipment", "Miran (ESCORT)", 52.2, 69.4, 16),
    D("Protecting the Shipment", "Escort Miran and his cart along the road east to Ironband's Excavation Site (ESCORT, Dark Iron ambush)", 58.0, 67.0, 16),
    T("Protecting the Shipment", "Prospector Ironband", 65.9, 65.6, 17),

    -- Farstrider Lodge
    A("Crocolisk Hunting", "Marek Ironheart", 81.8, 61.7, 17),
    A("Twisting the Knife", "Marek Ironheart (NEW)", 81.8, 61.7, 17),
    A("A Hunter's Boast", "Daryl the Youngling (TIMED, start when ready)", 83.5, 65.5, 17),
    D("A Hunter's Boast", "Kill 6 Mountain Buzzards in the hills south-west of the lodge (TIMED 15 min)", 76.8, 70.5, 17),
    T("A Hunter's Boast", "Daryl the Youngling", 83.5, 65.5, 17),
    A("A Hunter's Challenge", "Daryl the Youngling (TIMED, start when ready)", 83.5, 65.5, 17),
    D("Crocolisk Hunting", "Kill Loch Crocolisks along the shore of the Loch: 5 Crocolisk Meat and 6 Crocolisk Skins", 56.1, 39.3, 17),
    D("Twisting the Knife", "Find and kill the crocolisk Daggerfang hunting along the edge of the Loch, loot Marek's Croc-Hunting Knife", 58.0, 45.0, 17),
    D("A Hunter's Challenge", "Kill 5 Elder Mountain Boars in the hills east of the Loch (TIMED 12 min)", 65.4, 39.6, 17),
    T("A Hunter's Challenge", "Daryl the Youngling", 83.5, 65.5, 18),
    A("Vyrin's Revenge", "Vyrin Swiftwind (ELITE bear, group)", 81.7, 64.1, 18, 1),
    D("Vyrin's Revenge", "Kill Ol' Sooty in his cave south-west of Thelsamar (ELITE, group)", 37.9, 63.4, 18, 1),
    T("Vyrin's Revenge", "Daryl the Youngling", 83.5, 65.5, 18, 1),
    A("Vyrin's Revenge", "Daryl the Youngling (bring Ol' Sooty's head to Vyrin)", 83.5, 65.5, 18, 2),
    T("Vyrin's Revenge", "Vyrin Swiftwind", 81.7, 64.1, 18, 2),
    T("Crocolisk Hunting", "Marek Ironheart", 81.8, 61.7, 18),
    T("Twisting the Knife", "Marek Ironheart", 81.8, 61.7, 18),

    -- East shore and back to Thelsamar
    A("Bingles' Missing Supplies", "Bingles Blastenheimer (east shore; also turn in Find Bingles if you took it)", 63.6, 47.9, 18),
    A("WANTED: Chok'sul", "WANTED poster (Thelsamar; ELITE ogre, group)", 37.3, 46.5, 18),

    -- North: Stonewrought Dam, Bingles' tools and the Mo'grosh Stronghold
    A("A Dark Threat Looms", "Chief Engineer Hinderweir VII (Stonewrought Dam)", 46.0, 13.6, 18, 1),
    D("A Dark Threat Looms", "Search near the eastern ramp of the dam for the Suspicious Barrel", 56.0, 13.2, 18, 1),
    T("A Dark Threat Looms", "Suspicious Barrel", 56.0, 13.2, 18, 1),
    A("A Dark Threat Looms", "Suspicious Barrel", 56.0, 13.2, 18, 2),
    T("A Dark Threat Looms", "Chief Engineer Hinderweir VII", 46.0, 13.6, 19, 2),
    A("A Dark Threat Looms", "Chief Engineer Hinderweir VII (turn-in is Ashlan Stonesmirk, Dun Modr, Wetlands)", 46.0, 13.6, 19, 3),
    D("Bingles' Missing Supplies", "Pick up Bingles' Screwdriver (48,20), Hammer (51,24), Blastencapper (54,26) and Wrench (48,30) on the north shore of the Loch", 51.0, 24.0, 19),
    D("Mercenaries", "Kill 4 Mo'grosh Ogres, 4 Mo'grosh Brutes and 4 Mo'grosh Enforcers at the Mo'grosh Stronghold (ELITE, group)", 69.3, 25.5, 19),
    D("WANTED: Chok'sul", "Kill Chok'sul in the cave at the back of the Mo'grosh Stronghold and take his head (ELITE, group)", 79.6, 14.7, 19),
    T("Bingles' Missing Supplies", "Bingles Blastenheimer", 63.6, 47.9, 19),
    T("Mercenaries", "Magistrate Bluntnose", 34.6, 44.5, 20),
    T("WANTED: Chok'sul", "Magistrate Bluntnose", 34.6, 44.5, 20),
    A("Report to Mountaineer Rockgar", "Mountaineer Kadrell", 34.2, 47.8, 20),
    T("Report to Mountaineer Rockgar", "Mountaineer Rockgar (Algaz Station, north road)", 25.4, 10.4, 20),
    G("Dun Algaz tunnel to the Wetlands", 25.4, 10.4, 20, "Open quests to finish elsewhere: A Dark Threat Looms part 3 (Ashlan Stonesmirk, Dun Modr, Wetlands), Stormpike's Order (Furen Longbeard, Stormwind)"),
} }

-- Zones researched by worker sessions from Forever guide sites; each keeps its own source list.

-- Sources: https://wowhandbook.com/zones/kalimdor/ashenvale/ ; https://games.gg/world-of-warcraft/guides/wow-forever-ashenvale-leveling-guide/ ; https://wowforever.wiki.fextralife.com/Ashenvale
-- Ashenvale (Alliance) for WoW: Forever.
-- Sources: https://wow4ever.quest/en/npcs/<npc> and /en/quests/<slug> (Questie Forever data: givers, coords, min levels, "First you need");
-- https://foreverchanges.pro/quests/ashenvale (82-quest Forever list, New/Changed tags) and /quest/<id>;
-- https://www.wowhead.com/forever/quest=<id> (chain series and objectives); https://wow4ever.quest/en/articles/guia-subida-20-30-wow-forever
-- Part numbers: "The Tower of Althalaxx" 3-6 = 967, 970, 973, 1140 (1-2 are in Darkshore); "Raene's Cleansing" 1-11 = 991, 1023, 1024, 1026, 1027, 1028, 1055, 1029, 1030, 1045, 1046.
local ASHENVALE = { zone = "Ashenvale", min = 20, max = 30, steps = {
    -- Maestra's Post (arriving from Darkshore)
    G("Maestra's Post", 26.2, 38.7, 20, "Arrive from Darkshore with Kerlonian and Balthule's letter"),
    T("The Sleeper Has Awakened", "Liladris Moonriver", 27.3, 35.6, 20),
    T("The Tower of Althalaxx", "Delgren the Purifier", 26.2, 38.7, 20, 3),
    A("The Tower of Althalaxx", "Delgren the Purifier", 26.2, 38.7, 20, 4),
    A("Bathran's Hair", "Orendil Broadleaf", 26.4, 38.6, 20),
    D("Bathran's Hair", "Loot 5 Bathran's Hair from the plant bundles around Bathran's Haunt", 31.0, 22.5, 20),
    D("The Tower of Althalaxx", "Kill Dark Strand cultists at the Ruins of Ordil'Aran for the Glowing Soul Gem", 31.5, 29.3, 21, 4),
    T("Bathran's Hair", "Orendil Broadleaf", 26.4, 38.6, 21),
    A("Orendil's Cure", "Orendil Broadleaf", 26.4, 38.6, 21),
    T("The Tower of Althalaxx", "Delgren the Purifier", 26.2, 38.7, 21, 4),
    A("The Tower of Althalaxx", "Delgren the Purifier", 26.2, 38.7, 21, 5),

    -- Astranaar
    G("Astranaar flight path", 34.4, 48.0, 21, "Grab the flight path"),
    T("Trek to Ashenvale", "Raene Wolfrunner", 36.6, 49.6, 21),
    A("Raene's Cleansing", "Raene Wolfrunner", 36.6, 49.6, 21, 1),
    A("Culling the Threat", "Raene Wolfrunner", 36.6, 49.6, 21),
    T("Orendil's Cure", "Pelturas Whitemoon", 37.4, 51.8, 21),
    A("Elune's Tear", "Pelturas Whitemoon", 37.4, 51.8, 21),
    A("The Zoram Strand", "Shindrell Swiftfire", 34.7, 48.8, 21),

    -- Iris Lake, then the south-west
    D("Elune's Tear", "Pick up Elune's Tear on the isle in Iris Lake", 46.4, 46.4, 22),
    T("Elune's Tear", "Pelturas Whitemoon", 37.4, 51.8, 22),
    A("The Ruins of Stardust", "Pelturas Whitemoon", 37.4, 51.8, 22),
    D("The Ruins of Stardust", "Collect 5 Handfuls of Stardust in the Ruins of Stardust", 33.3, 67.7, 22),
    D("The Tower of Althalaxx", "Kill Ilkrud Magthrull at the Fire Scar Shrine for his tome", 25.3, 60.7, 23, 5),

    -- Lake Falathim and the Zoram Strand
    T("Raene's Cleansing", "Teronis' Corpse", 20.3, 42.3, 23, 1),
    A("Raene's Cleansing", "Teronis' Corpse", 20.3, 42.3, 23, 2),
    D("Raene's Cleansing", "Kill murlocs at Lake Falathim for the Glowing Gem", 20.6, 42.2, 23, 2),
    A("The Ancient Statuette", "Talen", 14.8, 31.3, 23),
    D("The Zoram Strand", "Kill Wrathtail naga along the Zoram Strand for 20 Wrathtail Heads", 14.0, 26.0, 23),
    D("The Ancient Statuette", "Find the Ancient Statuette on the strand", 14.2, 20.6, 23),
    T("The Ancient Statuette", "Talen", 14.8, 31.3, 24),
    A("Ruuzel", "Talen", 14.8, 31.3, 24),
    D("Ruuzel", "Kill Ruuzel on the isle at the northern edge of the Zoram Strand for the Ring of Zoram", 7.0, 13.5, 24),
    T("Ruuzel", "Talen", 14.8, 31.3, 24),

    -- Back to Maestra's Post
    T("The Tower of Althalaxx", "Delgren the Purifier", 26.2, 38.7, 24, 5),
    A("The Tower of Althalaxx", "Delgren the Purifier", 26.2, 38.7, 24, 6),
    A("Supplies to Auberdine", "Feero Ironhand (ESCORT)", 26.2, 38.9, 24),
    D("Supplies to Auberdine", "Escort Feero Ironhand along the road through three ambushes", 28.5, 30.0, 24),
    T("Supplies to Auberdine", "Delgren the Purifier", 26.2, 38.7, 24),

    -- Astranaar turn-ins and Thistlefur
    T("Raene's Cleansing", "Raene Wolfrunner", 36.6, 49.6, 24, 2),
    A("Raene's Cleansing", "Raene Wolfrunner", 36.6, 49.6, 24, 3),
    A("An Aggressive Defense", "Raene Wolfrunner", 36.6, 49.6, 24),
    T("The Zoram Strand", "Shindrell Swiftfire", 34.7, 48.8, 24),
    A("Kayneth Stillwind", "Shindrell Swiftfire", 34.7, 48.8, 24),
    T("The Ruins of Stardust", "Pelturas Whitemoon", 37.4, 51.8, 24),
    A("Fallen Sky Lake", "Pelturas Whitemoon", 37.4, 51.8, 24),
    D("Culling the Threat", "Kill Dal Bloodclaw in Thistlefur Village for his skull", 38.5, 34.5, 25),
    T("Culling the Threat", "Raene Wolfrunner", 36.6, 49.6, 25),

    -- Shrine of Aessina pick-ups
    A("The Howling Vale", "Sentinel Melyria Frostshadow", 22.2, 53.0, 25),
    A("Vile Satyr! Dryads in Danger!", "Illiyana", 21.7, 53.3, 26),

    -- Foulweald and Silverwind Refuge
    D("An Aggressive Defense", "Kill a Foulweald Den Watcher, 2 Ursas, 10 Totemics and 12 Warriors", 50.0, 59.9, 26),
    A("Elemental Bracers", "Sentinel Velene Starstrike", 49.8, 67.2, 26),
    D("Elemental Bracers", "Kill Befouled Water Elementals in Mystral Lake for 5 Intact Elemental Bracers, then use the Divining Scroll", 47.5, 69.5, 26),
    T("Elemental Bracers", "Sentinel Velene Starstrike", 49.8, 67.2, 26),
    A("Mage Summoner", "Sentinel Velene Starstrike", 49.8, 67.2, 26),
    D("Mage Summoner", "Kill Sarilus Foulborne near Mystral Lake for his head", 48.5, 72.0, 26),
    T("Mage Summoner", "Sentinel Velene Starstrike", 49.8, 67.2, 26),

    -- Moonwell and the Howling Vale
    T("Raene's Cleansing", "Shael'dryn", 53.5, 46.2, 26, 3),
    A("Raene's Cleansing", "Shael'dryn", 53.5, 46.2, 26, 4),
    D("The Howling Vale", "Study the Tome of Mel'Thandris at the ruined shrine in the Howling Vale", 50.7, 39.2, 26),
    D("Raene's Cleansing", "Loot the Wooden Key from the treants north-east of the moonwell", 57.0, 37.0, 26, 4),
    D("Raene's Cleansing", "Open the chest in the glade near the Felwood border for the Iron Shaft", 54.4, 35.4, 26, 4),
    T("Raene's Cleansing", "Shael'dryn", 53.5, 46.2, 26, 4),
    A("Raene's Cleansing", "Shael'dryn", 53.5, 46.2, 26, 5),

    -- Night Run and Forest Song
    D("The Tower of Althalaxx", "Free the Highborne soul in Night Run", 67.5, 53.0, 27, 6),
    G("Forest Song", 85.2, 44.7, 27),
    T("Kayneth Stillwind", "Kayneth Stillwind", 85.2, 44.7, 27),
    A("Forsaken Diseases", "Kayneth Stillwind", 85.2, 44.7, 27),
    A("Vengeful Trail", "Maseara Autumnmoon", 81.0, 50.2, 27),
    T("Vile Satyr! Dryads in Danger!", "Anilia", 78.3, 44.8, 27),
    A("The Branch of Cenarius", "Anilia", 78.3, 44.8, 27),
    D("Vengeful Trail", "Search Satyrnaar, west of Forest Song, for signs of Kurothel", 79.5, 48.5, 27),
    D("The Tower of Althalaxx", "Free the Highborne soul in Satyrnaar", 79.5, 48.5, 27, 6),
    T("Vengeful Trail", "Maseara Autumnmoon", 81.0, 50.2, 27),
    A("Shared Fury", "Maseara Autumnmoon", 81.0, 50.2, 27),
    D("The Branch of Cenarius", "Kill Geltharis in Xavian for the Branch of Cenarius", 78.0, 42.4, 28),
    D("Shared Fury", "Kill 5 each of Xavian Rogues, Felsworn, Betrayers and Hellcallers", 76.5, 41.5, 28),
    T("Shared Fury", "Maseara Autumnmoon", 81.0, 50.2, 28),

    -- Dor'danil Barrow Den
    D("Forsaken Diseases", "Take the Bottle of Disease from the Forsaken camp", 75.3, 71.8, 28),
    D("Raene's Cleansing", "Find the Iron Pommel in the Dor'danil Barrow Den", 75.9, 73.5, 28, 5),
    T("Forsaken Diseases", "Kayneth Stillwind", 85.2, 44.7, 28),
    A("Insane Druids", "Kayneth Stillwind", 85.2, 44.7, 28),
    D("Insane Druids", "Kill Taneel Darkwood, Uthil Mooncall and Mavoris Cloudsbreak in the Dor'danil Barrow Den", 76.0, 73.0, 29),
    T("Insane Druids", "Kayneth Stillwind", 85.2, 44.7, 29),

    -- Back west: rebuilding Dartol's Rod
    T("Raene's Cleansing", "Shael'dryn", 53.5, 46.2, 29, 5),
    A("Raene's Cleansing", "Shael'dryn", 53.5, 46.2, 29, 6),
    T("Raene's Cleansing", "Hidden Shrine", 56.4, 49.2, 29, 6),
    A("Raene's Cleansing", "Hidden Shrine", 56.4, 49.2, 29, 7),
    T("Raene's Cleansing", "Shael'dryn", 53.5, 46.2, 29, 7),
    A("Raene's Cleansing", "Shael'dryn", 53.5, 46.2, 29, 8),
    T("Raene's Cleansing", "Raene Wolfrunner", 36.6, 49.6, 29, 8),
    T("An Aggressive Defense", "Raene Wolfrunner", 36.6, 49.6, 29),
    A("Raene's Cleansing", "Raene Wolfrunner", 36.6, 49.6, 29, 9),

    -- South-east loop: Silverwind, Krolg, Fallen Sky Lake, the orcs
    A("Slowing the Orc Advance", "Shandrina", 49.4, 67.0, 29),
    T("Raene's Cleansing", "Krolg", 50.8, 75.1, 29, 9),
    A("Raene's Cleansing", "Krolg", 50.8, 75.1, 29, 10),
    D("Raene's Cleansing", "Kill 4 Bloodtooth Guards and Ran Bloodtooth for his skull", 54.7, 79.7, 29, 10),
    T("Raene's Cleansing", "Krolg", 50.8, 75.1, 30, 10),
    A("Raene's Cleansing", "Krolg", 50.8, 75.1, 30, 11),
    D("Fallen Sky Lake", "Kill a Shadethicket Oracle at Fallen Sky Lake for the Fallen Moonstone", 66.7, 82.2, 30),
    D("Slowing the Orc Advance", "Kill orc scouts and grunts around the orc camp in eastern Ashenvale for 6 Jagged Orcish Swords and 4 Curved Orcish Daggers", 72.0, 66.0, 30),
    A("Gleaming Crescent Necklace", "Gleaming Crescent Pendant", 63.0, 71.5, 30),
    T("Slowing the Orc Advance", "Shandrina", 49.4, 67.0, 30),

    -- Astranaar, Shrine of Aessina, Maestra's Post
    T("Raene's Cleansing", "Raene Wolfrunner", 36.6, 49.6, 30, 11),
    T("Fallen Sky Lake", "Pelturas Whitemoon", 37.4, 51.8, 30),
    T("Gleaming Crescent Necklace", "Maliynn", 36.6, 49.8, 30),
    T("The Howling Vale", "Sentinel Melyria Frostshadow", 22.2, 53.0, 30),
    T("The Branch of Cenarius", "Illiyana", 21.7, 53.3, 30),
    T("The Tower of Althalaxx", "Delgren the Purifier", 26.2, 38.7, 30, 6),
} }

-- Sources: https://wowhandbook.com/zones/eastern-kingdoms/wetlands/ https://urgametips.com/wow-forever/zones/wetlands/ https://games.gg/world-of-warcraft/guides/wow-forever-wetlands-leveling-guide/ https://wowforever.wiki.fextralife.com/Wetlands
-- Wetlands (Alliance) for WoW: Forever.
-- Sources: https://wow4ever.quest/en/quests/<slug> and /en/npcs/<slug> (Questie Forever data: ids, min levels, givers, coords, "First you need"/"Then comes");
-- https://foreverchanges.pro/quests/wetlands (65-quest Forever list, New/Changed/Elite tags) and /quest/<id> (givers+coords of the Forever-new quests);
-- https://www.wowhead.com/forever/quest=<id> (series boxes, objectives). Mob/objective spots not given by Forever sources (crocolisks, murlocs,
-- Mosshide, Fen Creepers, Angerfang, raptors, Lost Fleet, Thelgen Rock, Crimson Whelps) come from the Classic layout (warcraft.wiki.gg) and are marked "(Classic spot)" in the notes file.
-- Part numbers: "In Search of The Excavation Team" 1-2 = 305, 306; "Return the Statuette" 1-2 = 286, 98189; "Ormer's Revenge" 1-3 = 294, 295, 296.
-- Forever NEW quests routed: Spoils of War 98197, Crocs of the Sky 98072, Crimson Crate Delivery 98240, Razormaw Needling 98245, Trying Times 98246,
-- This Land Was Their Land 98230, From the Ashes 98221, Old Habits 98223, Alchemical Hazards 98282, Return the Statuette 98189, A Friend of the Family 98190.
-- Left out: Lightforge Ingots / The Lost Ingots / Seeking Wisdom (Duskwood's Sven chain, routed there); Bloom of the Heavens 98208/98209 (wowhead race list has no
-- Humans: dwarf/night elf/gnome only); A Lack of Virtue 98459 (starts in Hillsbrad), Unrequited Love 98461 (starts in Darkshore), The Algaz Gauntlet 455 /
-- Report to Mountaineer Rockgar 468 (start in Loch Modan), MacKreel's Moonshine 647 (Arathi -> Hillsbrad), Plea To The Alliance 634 (Arathi owns),
-- James Hyal 1302 (needs 1301 from Stormwind, min 30); all Elite/dungeon quests (Thandol Span 631-633, The Dark Iron War 303, A Grim Task 304,
-- Defeat Nek'rosh 474, Carnage, Death to the Dragonmaw, Forced Disarmament, Understanding Our Present, Gleaning Our Future, Stopping the Cycle,
-- Bring Back a Bang, Spark of Freedom, Accessories/Hearts/Sentiments of the Lost) kept only as G notes.
-- Cross-zone: Fiora Longears 1132 (turn-in Theramore, Dustwallow Marsh), Cleansing the Eye 293 (Archbishop Benedictus, Stormwind 50.3,45.5),
-- A Friend of the Family 98190 (Highlord Bolvar Fordragon, Stormwind 80.0,38.5; part 2 98191 is accepted and turned in inside Stormwind) are accepted here and left open.
local WETLANDS = { zone = "Wetlands", min = 20, max = 30, steps = {
    -- Menethil Harbor: first pickups
    G("Menethil Harbor flight path", 9.5, 59.7, 20, "Grab the flight path and set your hearth at the Deepwater Tavern"),
    A("The Greenwarden", "First Mate Fitzsimmons", 10.9, 59.6, 20),
    A("Digging Through the Ooze", "Sida", 11.8, 58.0, 20),
    A("Claws from the Deep", "Karl Boran", 8.3, 58.6, 20),
    A("Spoils of War", "Valstag Ironjaw", 10.1, 56.9, 20),
    A("Young Crocolisk Skins", "James Halloran", 8.6, 55.7, 20),
    A("Crocs of the Sky", "James Halloran (whelps are far east on the Green Belt, done later)", 8.6, 55.7, 20),
    A("Alchemical Hazards", "Caitlin Grassman", 11.9, 58.8, 20),
    A("Fiora Longears", "Red Jack Flint (turn-in is in Theramore: take the boat when you leave the zone)", 10.0, 58.0, 20),

    -- Around the harbor
    D("Spoils of War", "Loot 6 Khaz Modan Timber and 30 Khaz Modan Iron from the harbor waters (watch the crocolisks and murlocs underwater)", 11.5, 53.5, 20),
    D("Young Crocolisk Skins", "Kill Young Crocolisks in the marsh east of town for 4 Young Crocolisk Skins", 13.3, 54.7, 20),
    T("Spoils of War", "Valstag Ironjaw", 10.1, 56.9, 21),
    T("Young Crocolisk Skins", "James Halloran", 8.6, 55.7, 21),
    A("Apprentice's Duties", "James Halloran", 8.6, 55.7, 21),
    A("In Search of The Excavation Team", "Tarrel Rockweaver", 11.5, 52.2, 21, 1),

    -- Bluegill Marsh (north coast)
    D("Claws from the Deep", "Kill 12 Bluegill Murlocs and Gobbler along the coast north of town, loot Gobbler's Head", 15.2, 41.5, 21),
    T("Claws from the Deep", "Karl Boran", 8.3, 58.6, 22),
    A("Reclaiming Goods", "Karl Boran", 8.3, 58.6, 22),
    A("The Third Fleet", "First Mate Fitzsimmons (needs 1 Flagon of Mead, sold by the innkeeper upstairs)", 10.9, 59.6, 22),
    T("The Third Fleet", "First Mate Fitzsimmons", 10.9, 59.6, 22),
    A("The Cursed Crew", "First Mate Fitzsimmons (Lost Fleet, done at 28)", 10.9, 59.6, 22),
    T("Reclaiming Goods", "Damaged Crate (murloc camp)", 13.5, 41.4, 22),
    A("The Search Continues", "Damaged Crate", 13.5, 41.4, 22),
    T("The Search Continues", "Sealed Barrel (murloc camp)", 13.6, 38.2, 22),
    A("Search More Hovels", "Sealed Barrel", 13.6, 38.2, 22),
    T("Search More Hovels", "Half-buried Barrel (murloc hovels)", 13.9, 34.8, 22),
    A("Return the Statuette", "Half-buried Barrel", 13.9, 34.8, 22, 1),
    D("Apprentice's Duties", "Kill Giant Crocolisks along the coast north of the murloc hovels for 6 Giant Crocolisk Skins", 15.3, 29.2, 22),

    -- Back in Menethil
    T("Return the Statuette", "Karl Boran", 8.3, 58.6, 23, 1),
    A("Return the Statuette", "Karl Boran", 8.3, 58.6, 23, 2),
    T("Return the Statuette", "Captain Stoutfist (Menethil Keep)", 9.9, 57.5, 23, 2),
    T("Apprentice's Duties", "James Halloran", 8.6, 55.7, 23),
    A("Report to Captain Stoutfist", "Valstag Ironjaw", 10.1, 56.9, 23),
    T("Report to Captain Stoutfist", "Captain Stoutfist", 9.9, 57.5, 23),
    A("War Banners", "Captain Stoutfist", 9.9, 57.5, 23),
    A("From the Ashes", "Captain Stoutfist", 9.9, 57.5, 23),
    A("This Land Was Their Land", "Captain Stoutfist", 9.9, 57.5, 23),

    -- Whelgar's Excavation Site
    T("In Search of The Excavation Team", "Merrin Rockweaver", 38.9, 52.3, 23, 1),
    A("In Search of The Excavation Team", "Merrin Rockweaver", 38.9, 52.3, 23, 2),
    A("Ormer's Revenge", "Ormer Ironbraid", 38.2, 50.9, 23, 1),
    D("Ormer's Revenge", "Kill 10 Mottled Screechers and 10 Mottled Raptors west and north-west of the dig site", 30.2, 44.1, 23, 1),
    T("Ormer's Revenge", "Ormer Ironbraid", 38.2, 50.9, 24, 1),
    A("Ormer's Revenge", "Ormer Ironbraid", 38.2, 50.9, 24, 2),
    D("Ormer's Revenge", "Kill 10 Mottled Scytheclaws and 10 Mottled Razormaws around the dig site and the ridge west of it", 35.0, 49.0, 24, 2),
    T("Ormer's Revenge", "Ormer Ironbraid", 38.2, 50.9, 25, 2),
    A("Ormer's Revenge", "Ormer Ironbraid (Sarltooth is level 29: done later)", 38.2, 50.9, 25, 3),

    -- Thelgen Rock and the Green Belt crossroads
    D("Alchemical Hazards", "Kill Leech Stalkers in the Thelgen Rock cave for 1 Unruptured Stalker Gland", 48.5, 60.5, 25),
    A("Daily Delivery", "Einar Stonegrip", 49.9, 39.4, 25),
    T("This Land Was Their Land", "Howin Kindfeather", 49.4, 42.1, 25),
    A("Trying Times", "Howin Kindfeather (eggs at Raptor Ridge, done later)", 49.4, 42.1, 25),
    T("The Greenwarden", "Rethiel the Greenwarden", 56.4, 40.4, 25),
    A("Tramping Paws", "Rethiel the Greenwarden", 56.4, 40.4, 25),
    A("Old Habits", "Tattered Spellbook (ground item south of the Green Belt, Dragonmaw area)", 53.5, 54.5, 25),
    D("Tramping Paws", "Kill 15 Mosshide Gnolls and 10 Mosshide Mongrels in Mosshide Fen south-east of the Greenwarden", 58.5, 56.0, 25),
    T("Tramping Paws", "Rethiel the Greenwarden", 56.4, 40.4, 26),
    A("Fire Taboo", "Rethiel the Greenwarden", 56.4, 40.4, 26),
    D("Fire Taboo", "Loot 9 Crude Flint from Mosshide gnolls (Mystics, Brutes, Trappers) in Mosshide Fen", 57.5, 52.0, 26),
    T("Fire Taboo", "Rethiel the Greenwarden", 56.4, 40.4, 26),
    A("Blisters on the Land", "Rethiel the Greenwarden", 56.4, 40.4, 26),
    D("Blisters on the Land", "Kill 8 Fen Creepers around the Green Belt pools", 54.0, 41.4, 26),
    D("Crocs of the Sky", "Kill Crimson Whelps east along the Green Belt for 10 Pristine Crimson Scales", 62.0, 42.0, 26),
    T("Blisters on the Land", "Rethiel the Greenwarden", 56.4, 40.4, 27),

    -- Angerfang Encampment and Ironbeard's Tomb
    D("War Banners", "Kill Dragonmaw orcs in the Angerfang Encampment for 8 Dragonmaw War Banners", 41.5, 46.0, 27),
    D("From the Ashes", "Destroy the 4 Attack Plans (Menethil Harbor, Thelsamar, Southshore, Ironforge) in the Angerfang Encampment", 43.0, 45.0, 27),
    D("Digging Through the Ooze", "Kill the oozes at Ironbeard's Tomb until one drops Sida's Bag", 45.0, 24.3, 27),
    G("Hearth to Menethil Harbor", 10.6, 55.3, 27),

    -- Menethil turn-ins
    -- Part 2 (306, Merrin's note) is turned in to Tarrel Rockweaver (wowhead classic quest=306); it had no turn-in step.
    T("In Search of The Excavation Team", "Tarrel Rockweaver", 11.5, 52.2, 27, 2),
    T("Daily Delivery", "James Halloran", 8.6, 55.7, 27),
    T("Crocs of the Sky", "James Halloran", 8.6, 55.7, 27),
    A("Crimson Crate Delivery", "James Halloran", 8.6, 55.7, 27),
    T("Alchemical Hazards", "Caitlin Grassman", 11.9, 58.8, 27),
    T("Digging Through the Ooze", "Sida", 11.8, 58.0, 27),
    T("Old Habits", "Captain Stoutfist", 9.9, 57.5, 27),
    T("War Banners", "Captain Stoutfist", 9.9, 57.5, 27),
    T("From the Ashes", "Captain Stoutfist", 9.9, 57.5, 27),
    A("Nek'rosh's Gambit", "Captain Stoutfist", 9.9, 57.5, 27),
    A("Fall of Dun Modr", "Harlo Barnaby", 10.8, 55.9, 27),

    -- The Lost Fleet (two short trips from town)
    D("The Cursed Crew", "Kill 13 Cursed Sailors and 5 Cursed Marines on the wrecks of the Lost Fleet, then First Mate Snellig for Snellig's Snuffbox", 15.0, 30.0, 28),
    T("The Cursed Crew", "First Mate Fitzsimmons", 10.9, 59.6, 28),
    A("Lifting the Curse", "First Mate Fitzsimmons", 10.9, 59.6, 28),
    D("Lifting the Curse", "Kill Captain Halyndor on the northern wreck of the Lost Fleet for the Intrepid Strongbox Key", 14.5, 24.5, 28),
    T("Lifting the Curse", "Intrepid's Locked Strongbox (underwater in the wreck)", 14.4, 24.0, 28),
    A("The Eye of Paleth", "Intrepid's Locked Strongbox", 14.4, 24.0, 28),

    -- Back east: Sarltooth, catapults, Dun Modr, Raptor Ridge
    A("Uncovering the Past", "Prospector Whelgar", 38.8, 52.4, 28),
    D("Uncovering the Past", "Pick up the Ados, Modr, Golm and Neru fragments lying around the dig site", 36.5, 50.0, 28),
    D("Ormer's Revenge", "Kill Sarltooth (level 29, wanders west of the dig site) for Sarltooth's Talon", 33.3, 51.5, 28, 3),
    T("Ormer's Revenge", "Ormer Ironbraid", 38.2, 50.9, 28, 3),
    T("Uncovering the Past", "Prospector Whelgar", 38.8, 52.4, 28),
    D("Nek'rosh's Gambit", "Destroy the Dragonmaw Catapults on the hill east of the Angerfang Encampment (use the quest item on them)", 47.5, 47.0, 29),
    T("Nek'rosh's Gambit", "Dragonmaw Catapult (object)", 47.5, 47.0, 29),
    T("Crimson Crate Delivery", "Howin Kindfeather", 49.4, 42.1, 29),
    A("Razormaw Needling", "Howin Kindfeather", 49.4, 42.1, 29),
    T("Fall of Dun Modr", "Longbraid the Grim", 49.8, 18.3, 29),
    G("Dun Modr (Thandol Span)", 49.8, 18.3, 29, "Optional ELITE chain at 28+: Rhag Garmason here offers The Thandol Span (631-633) and Longbraid offers A Grim Task (304); skip solo"),
    D("Trying Times", "Pick up 12 Perfect Razormaw Eggs from the nests at Raptor Ridge (Razormaws attack when you loot)", 68.5, 30.0, 29),
    D("Razormaw Needling", "Kill Razormaws at Raptor Ridge for 10 Razormaw Incisors", 67.0, 31.5, 29),
    T("Trying Times", "Howin Kindfeather", 49.4, 42.1, 30),
    T("Razormaw Needling", "Howin Kindfeather", 49.4, 42.1, 30),
    G("Hearth to Menethil Harbor", 10.6, 55.3, 30),

    -- Final Menethil visit
    T("The Eye of Paleth", "Glorin Steelbrow", 10.6, 60.6, 30),
    A("Cleansing the Eye", "Glorin Steelbrow (turn-in: Archbishop Benedictus, Stormwind Cathedral)", 10.6, 60.6, 30),
    A("A Friend of the Family", "Captain Stoutfist (turn-in: Highlord Bolvar Fordragon, Stormwind Keep)", 9.9, 57.5, 30),
    G("Menethil Harbor docks", 7.0, 57.0, 30, "Cleansing the Eye -> Archbishop Benedictus (Stormwind 50.3,45.5); A Friend of the Family -> Bolvar (Stormwind 80.0,38.5), then part 2 to Lord Grayson Shadowbreaker (48.5,50.1); Fiora Longears -> boat to Theramore (66.5,45.1). Next zone: Duskwood / Hillsbrad"),
} }

-- Sources: https://wowhandbook.com/zones/eastern-kingdoms/duskwood/ https://urgametips.com/wow-forever/zones/duskwood/ https://urgametips.com/wow-forever/zones/duskwood/map/ https://urgametips.com/wow-forever/quest-guides/the-totem-of-infliction-fangs-fingers-spider-venom/ https://urgametips.com/wow-forever/quest-guides/deliveries-to-sven-supplies/ https://urgametips.com/wow-forever/quest-guides/bride-of-the-embalmer-eliza-grave/ https://urgametips.com/wow-forever/quest-guides/the-weathered-grave-sirra-darkshire/ https://games.gg/world-of-warcraft/guides/wow-forever-duskwood-guide/ https://wowforever.wiki.fextralife.com/Duskwood
-- Duskwood (Alliance) for WoW: Forever.
-- Sources: https://wow4ever.quest/en/quests/<slug> and /en/npcs/<slug> (Questie Forever data: ids, min levels, givers, coords, "First you need");
-- https://foreverchanges.pro/quests/duskwood (86-quest Forever list, New/Elite tags) and /quest/<id>; https://www.wowhead.com/forever/quest=<id> (series, objectives);
-- https://wow4ever.quest/en/articles/guia-subida-20-30-wow-forever (mob/object coords); warcraft.wiki.gg only for mob spots wow4ever is silent on (Bluegill Raider, Pygmy spiders, Dark Runners, Insane Ghoul).
-- Part numbers: "The Night Watch" 1-3 = 56, 57, 58; "Look to the Stars" 1-4 = 174, 175, 177, 181; "Worgen in the Woods" 1-4 = 173, 221, 222, 223.
-- Forever "New": The Valor Family (96139) routed; Ira's Dagger (96137), Merrick's Bow (96138), The Valor Family (98447) left out (item-started / unplaced in Questie).
-- Left out: The Legend of Stalvan 66-98 (13 parts bouncing Darkshire<->Stormwind/Elwynn/Westfall/Redridge); Seasoned Wolf Kabobs 90 (cooking quest); An Old History Book 337 (drop, ends in Stormwind library);
-- Morgan Ladimore / Mor'Ladim / A Daughter's Love / The Daughter Who Lived (level 35 chain after The Weathered Grave); Supplies for Nethergarde 1395 (level 45); Horde quests.
-- Cross-zone: "Messenger to Darkshire" (145) accepted in Redridge, turned in here. The Sven chain leg (Seeking Wisdom -> Morbent Fel) runs through Stormwind City and Menethil Harbor (Wetlands):
-- those steps carry STORMWIND / WETLANDS map coordinates (exception granted by the task) and name the zone in the NPC text.
local DUSKWOOD = { zone = "Duskwood", min = 20, max = 31, steps = {
    -- Darkshire arrival (20)
    T("Messenger to Darkshire", "Lord Ello Ebonlocke (Darkshire town hall)", 71.9, 46.4, 20),
    G("Darkshire flight path", 77.6, 44.4, 20, "Learn the flight path from Felicia Maline; set your hearth at the Scarlet Raven inn"),
    A("The Night Watch", "Commander Althea Ebonlocke", 73.5, 46.8, 20, 1),
    A("The Totem of Infliction", "Madame Eva", 75.8, 45.3, 20),
    A("The Hermit", "Elaine Carevin", 75.3, 48.8, 20),
    A("Deliveries to Sven", "Elaine Carevin", 75.3, 48.8, 20),
    A("Raven Hill", "Elaine Carevin", 75.3, 48.8, 20),
    A("The Valor Family", "Sirra Von'Indi (Forever NEW)", 72.6, 47.6, 20),
    A("Look to the Stars", "Viktori Prism'Antras (needs a Bronze Tube: engineer-made or AH)", 79.8, 48.0, 20, 1),
    D("The Night Watch", "Kill 8 Skeletal Warriors and 6 Skeletal Mages in Tranquil Gardens Cemetery (mages deeper in, 79.3, 70.5)", 78.0, 67.0, 20, 1),
    T("The Night Watch", "Commander Althea Ebonlocke", 73.5, 46.8, 21, 1),
    A("The Night Watch", "Commander Althea Ebonlocke", 73.5, 46.8, 21, 2),

    -- First trip west: Raven Hill, Abercrombie, Sven's camp (21-22)
    A("Eight-Legged Menaces", "Watcher Dodds (road west of Darkshire)", 45.1, 67.0, 21),
    T("Raven Hill", "Jitters", 18.4, 56.4, 21),
    A("Jitters' Growling Gut", "Jitters", 18.4, 56.4, 21),
    D("The Valor Family", "Search the Raven Hill ruins for the Raven Hill Tome (Questie has no object pin yet; look through the houses)", 18.4, 56.4, 21),
    T("The Hermit", "Abercrombie (shack north of Raven Hill Cemetery)", 28.1, 31.5, 21),
    A("Supplies from Darkshire", "Abercrombie", 28.1, 31.5, 21),
    T("Deliveries to Sven", "Sven Yorgen (Sven's Camp, west border)", 7.8, 34.1, 21),
    A("Sven's Revenge", "Sven Yorgen", 7.8, 34.1, 21),
    A("Wolves at Our Heels", "Lars", 7.7, 33.2, 21),
    D("Wolves at Our Heels", "Kill 12 Starving Dire Wolves and 8 Rabid Dire Wolves in the woods around Sven's Camp and along the river east of it", 14.0, 31.0, 21),
    D("Eight-Legged Menaces", "Kill 15 Pygmy Venom Web Spiders along the Hushed Bank west and south of Sven's Camp (6.1, 38.2)", 8.0, 40.0, 22),
    T("Wolves at Our Heels", "Lars", 7.7, 33.2, 22),
    D("Sven's Revenge", "Dig up the Mound of loose dirt behind the old stump at Yorgen Farmstead", 49.9, 77.7, 22),
    T("Sven's Revenge", "Mound of loose dirt (stump at Yorgen Farmstead)", 49.9, 77.7, 22),
    A("Sven's Camp", "Mound of loose dirt (stump at Yorgen Farmstead)", 49.9, 77.7, 22),
    T("Eight-Legged Menaces", "Watcher Dodds", 45.1, 67.0, 22),

    -- Back in Darkshire: Eva, Grual, Viktori, Blind Mary (22-23)
    T("Supplies from Darkshire", "Madame Eva", 75.8, 45.3, 22),
    A("Ghost Hair Thread", "Madame Eva", 75.8, 45.3, 22),
    T("Jitters' Growling Gut", "Chef Grual (Scarlet Raven inn)", 73.8, 43.5, 22),
    A("Dusky Crab Cakes", "Chef Grual", 73.8, 43.5, 22),
    T("The Valor Family", "Sirra Von'Indi", 72.6, 47.6, 22),
    T("Look to the Stars", "Viktori Prism'Antras (hand in the Bronze Tube)", 79.8, 48.0, 22, 1),
    A("Look to the Stars", "Viktori Prism'Antras", 79.8, 48.0, 22, 2),
    T("Ghost Hair Thread", "Blind Mary (house south-east of Darkshire)", 82.0, 59.1, 23),
    A("Return the Comb", "Blind Mary", 82.0, 59.1, 23),
    T("Look to the Stars", "Blind Mary", 82.0, 59.1, 23, 2),
    A("Look to the Stars", "Blind Mary", 82.0, 59.1, 23, 3),
    D("Look to the Stars", "Kill the Insane Ghoul in Tranquil Gardens Cemetery for Blind Mary's Looking Glass", 80.9, 72.0, 23, 3),
    T("Return the Comb", "Madame Eva", 75.8, 45.3, 23),
    A("Deliver the Thread", "Madame Eva", 75.8, 45.3, 23),
    T("Look to the Stars", "Viktori Prism'Antras", 79.8, 48.0, 23, 3),
    A("Look to the Stars", "Viktori Prism'Antras (Zzarc'Vul's monocle, done later at the southern ogre mound)", 79.8, 48.0, 23, 4),

    -- Second trip west: Sven, Abercrombie, Raven Hill Cemetery (23-25)
    T("Sven's Camp", "Sven Yorgen", 7.8, 34.1, 23),
    A("The Shadowy Figure", "Sven Yorgen", 7.8, 34.1, 23),
    D("Dusky Crab Cakes", "Collect 6 Gooey Spider Legs from the Venom Web spiders along the Hushed Bank", 8.0, 40.0, 23),
    T("Deliver the Thread", "Abercrombie", 28.1, 31.5, 24),
    A("Zombie Juice", "Abercrombie", 28.1, 31.5, 24),
    D("The Totem of Infliction", "Collect 10 Ghoul Fangs from Flesh Eaters in Raven Hill Cemetery", 23.3, 32.9, 24),
    D("The Totem of Infliction", "Collect 5 Vials of Spider Venom from Carrion Recluses in Raven Hill Cemetery", 23.6, 36.6, 24),
    D("The Night Watch", "Kill 15 Skeletal Fiends (20.1, 44.8) and 15 Skeletal Horrors in the southern half of Raven Hill Cemetery", 21.6, 48.3, 25, 2),
    D("The Totem of Infliction", "Collect 10 Skeleton Fingers from the Skeletal Horrors", 21.6, 48.2, 25),

    -- Darkshire: Shadowy Figure chain, Zombie Juice, worgen (25-27)
    T("The Shadowy Figure", "Madame Eva", 75.8, 45.3, 25),
    A("The Shadowy Search Continues", "Madame Eva", 75.8, 45.3, 25),
    T("The Totem of Infliction", "Madame Eva", 75.8, 45.3, 25),
    T("The Shadowy Search Continues", "Clerk Daltry (town hall)", 72.5, 46.9, 25),
    A("Inquire at the Inn", "Clerk Daltry", 72.5, 46.9, 25),
    T("Inquire at the Inn", "Tavernkeep Smitts (Scarlet Raven inn)", 73.8, 44.5, 25),
    A("Finding the Shadowy Figure", "Tavernkeep Smitts", 73.8, 44.5, 25),
    T("Zombie Juice", "Tavernkeep Smitts", 73.8, 44.5, 25),
    A("Gather Rot Blossoms", "Tavernkeep Smitts", 73.8, 44.5, 25),
    T("Dusky Crab Cakes", "Chef Grual", 73.8, 43.5, 25),
    A("Return to Jitters", "Chef Grual", 73.8, 43.5, 25),
    T("The Night Watch", "Commander Althea Ebonlocke", 73.5, 46.8, 25, 2),
    A("The Night Watch", "Commander Althea Ebonlocke", 73.5, 46.8, 25, 3),
    A("Worgen in the Woods", "Calor", 75.8, 47.6, 25, 1),
    D("Gather Rot Blossoms", "Gather 8 Rot Blossoms (ground plants) in Tranquil Gardens Cemetery", 80.6, 59.2, 25),
    T("Gather Rot Blossoms", "Tavernkeep Smitts", 73.8, 44.5, 26),
    A("Juice Delivery", "Tavernkeep Smitts", 73.8, 44.5, 26),
    D("Worgen in the Woods", "Kill 6 Nightbane Shadow Weavers in the woods west of Darkshire", 65.0, 45.8, 26, 1),
    T("Worgen in the Woods", "Calor", 75.8, 47.6, 26, 1),
    A("Worgen in the Woods", "Calor", 75.8, 47.6, 26, 2),
    D("Worgen in the Woods", "Kill 12 Nightbane Dark Runners in the woods south-west of Darkshire, toward Roland's Doom", 61.0, 75.0, 26, 2),
    T("Worgen in the Woods", "Calor", 75.8, 47.6, 27, 2),
    A("Worgen in the Woods", "Calor", 75.8, 47.6, 27, 3),

    -- Third trip west: Jitters, Sven, Abercrombie, Raven Hill, ogre mound (27-29)
    T("Return to Jitters", "Jitters", 18.4, 56.4, 27),
    T("Finding the Shadowy Figure", "Jitters", 18.4, 56.4, 27),
    A("Return to Sven", "Jitters", 18.4, 56.4, 27),
    T("Return to Sven", "Sven Yorgen", 7.8, 34.1, 27),
    A("Proving Your Worth", "Sven Yorgen", 7.8, 34.1, 27),
    D("Proving Your Worth", "Kill 15 Skeletal Raiders, 3 Skeletal Healers and 3 Skeletal Warders on the hill north of Raven Hill Cemetery", 16.0, 34.5, 28),
    T("Proving Your Worth", "Sven Yorgen", 7.8, 34.1, 28),
    A("Seeking Wisdom", "Sven Yorgen (turn-in is Bishop Farthing in Stormwind, done at the end)", 7.8, 34.1, 28),
    T("Juice Delivery", "Abercrombie", 28.1, 31.5, 28),
    A("Ghoulish Effigy", "Abercrombie", 28.1, 31.5, 28),
    D("Ghoulish Effigy", "Collect 7 Ghoul Ribs from ghouls in Raven Hill Cemetery", 24.2, 33.2, 28),
    D("The Night Watch", "Kill 20 Plague Spreaders in and around the eastern mausoleum of Raven Hill Cemetery", 26.3, 34.2, 28, 3),
    T("Ghoulish Effigy", "Abercrombie", 28.1, 31.5, 29),
    A("Ogre Thieves", "Abercrombie", 28.1, 31.5, 29),
    G("A Weathered Grave (hill north-west of the cemetery)", 17.7, 29.1, 29, "Click the grave: starts The Weathered Grave (level 35 chain, only this first step is routed)"),
    A("The Weathered Grave", "A Weathered Grave (object)", 17.7, 29.1, 29),
    D("Ogre Thieves", "Pick up Abercrombie's Crate on the ground outside the cave mouth of the Vul'Gol Ogre Mound", 33.4, 76.3, 29),
    D("Look to the Stars", "Kill Zzarc'Vul inside the Vul'Gol Ogre Mound for the Ogre's Monocle", 37.0, 81.5, 29, 4),
    T("Ogre Thieves", "Abercrombie", 28.1, 31.5, 29),
    A("Note to the Mayor", "Abercrombie", 28.1, 31.5, 29),

    -- Darkshire wrap-up: town hall chain, worgen, Bride of the Embalmer (29-31)
    T("The Night Watch", "Commander Althea Ebonlocke", 73.5, 46.8, 29, 3),
    T("The Weathered Grave", "Sirra Von'Indi (town hall; skip her level-35 follow-up Morgan Ladimore)", 72.6, 47.6, 29),
    T("Note to the Mayor", "Lord Ello Ebonlocke", 71.9, 46.4, 29),
    A("Translate Abercrombie's Note", "Lord Ello Ebonlocke", 71.9, 46.4, 29),
    T("Translate Abercrombie's Note", "Sirra Von'Indi", 72.6, 47.6, 29),
    A("Wait for Sirra to Finish", "Sirra Von'Indi", 72.6, 47.6, 29),
    T("Wait for Sirra to Finish", "Sirra Von'Indi (wait a moment, talk again)", 72.6, 47.6, 29),
    A("Translation to Ello", "Sirra Von'Indi", 72.6, 47.6, 29),
    T("Translation to Ello", "Lord Ello Ebonlocke", 71.9, 46.4, 30),
    A("Bride of the Embalmer", "Lord Ello Ebonlocke (ELITE)", 71.9, 46.4, 30),
    T("Look to the Stars", "Viktori Prism'Antras", 79.8, 48.0, 30, 4),
    D("Worgen in the Woods", "Kill 8 Nightbane Vile Fangs and 8 Nightbane Tainted Ones around Roland's Doom in the south-east", 73.0, 75.0, 30, 3),
    T("Worgen in the Woods", "Calor", 75.8, 47.6, 30, 3),
    A("Worgen in the Woods", "Calor", 75.8, 47.6, 30, 4),
    T("Worgen in the Woods", "Jonathan Carevin", 75.3, 49.0, 30, 4),
    D("Bride of the Embalmer", "ELITE, group: dig Eliza's grave behind Abercrombie's shack, kill Eliza for the Embalmer's Heart", 28.8, 31.0, 31),
    T("Bride of the Embalmer", "Lord Ello Ebonlocke", 71.9, 46.4, 31),

    -- Sven chain leg: Stormwind -> Menethil Harbor (Wetlands) -> Stormwind -> Sven (31). Coordinates below are STORMWIND / WETLANDS map coords. Wrapped in On(): the guide plots them only while you're on that map.
    G("Fly to Stormwind City for the Sven chain (Darkshire flight master)", 77.6, 44.4, 31, "Seeking Wisdom goes to Bishop Farthing in the Cathedral of Light; then The Doomed Fleet sends you to Menethil Harbor"),
    On("Stormwind City", T("Seeking Wisdom", "Bishop Farthing (Cathedral of Light, Stormwind City)", 49.9, 46.0, 31)),
    On("Stormwind City", A("The Doomed Fleet", "Bishop Farthing (Cathedral of Light, Stormwind City)", 49.9, 46.0, 31)),
    G("Fly to Menethil Harbor (Wetlands) for the Sven chain", 77.6, 44.4, 31, "From Stormwind fly on to Menethil Harbor; Glorin Steelbrow stands by the lighthouse path west of the docks"),
    On("Wetlands", T("The Doomed Fleet", "Glorin Steelbrow (Menethil Harbor, Wetlands)", 10.6, 60.6, 31)),
    On("Wetlands", A("Lightforge Iron", "Glorin Steelbrow (Menethil Harbor, Wetlands)", 10.6, 60.6, 31)),
    On("Wetlands", D("Lightforge Iron", "Swim to the wreck of the Flying Osprey south-west of Menethil (Wetlands) and open the Waterlogged Chest", 12.1, 64.2, 31)),
    On("Wetlands", T("Lightforge Iron", "Waterlogged Chest (Flying Osprey wreck, Wetlands)", 12.1, 64.2, 31)),
    On("Wetlands", A("The Lost Ingots", "Waterlogged Chest (Flying Osprey wreck, Wetlands)", 12.1, 64.2, 31)),
    On("Wetlands", D("The Lost Ingots", "Collect 5 Lightforge Ingots from Bluegill Raiders (murlocs, lvl 28-29) around the wrecks off the Wetlands coast", 8.0, 68.0, 31)),
    On("Wetlands", T("The Lost Ingots", "Glorin Steelbrow (Menethil Harbor, Wetlands)", 10.6, 60.6, 31)),
    On("Wetlands", A("Lightforge Ingots", "Glorin Steelbrow (Menethil Harbor, Wetlands; only if he offers it: 5 more ingots)", 10.6, 60.6, 31)),
    On("Wetlands", D("Lightforge Ingots", "Collect 5 more Lightforge Ingots from Bluegill Raiders at the wrecks (Wetlands)", 8.0, 68.0, 31)),
    On("Wetlands", T("Lightforge Ingots", "Glorin Steelbrow (Menethil Harbor, Wetlands)", 10.6, 60.6, 31)),
    On("Wetlands", A("Blessed Arm", "Glorin Steelbrow (Menethil Harbor, Wetlands)", 10.6, 60.6, 31)),
    On("Wetlands", G("Fly back to Stormwind City (Menethil flight master)", 9.5, 59.7, 31, "Blessed Arm goes to Grimand Elmore in the Dwarven District")),
    On("Stormwind City", T("Blessed Arm", "Grimand Elmore (Dwarven District, Stormwind City)", 59.7, 33.8, 31)),
    On("Stormwind City", A("Armed and Ready", "Grimand Elmore (Dwarven District, Stormwind City)", 59.7, 33.8, 31)),
    G("Fly to Darkshire and ride to Sven's Camp", 77.6, 44.4, 31, "Bring Morbent's Bane to Sven Yorgen"),
    T("Armed and Ready", "Sven Yorgen", 7.8, 34.1, 31),
    A("Morbent Fel", "Sven Yorgen (ELITE, group)", 7.8, 34.1, 31),
    D("Morbent Fel", "ELITE, group: use Morbent's Bane on Morbent Fel in the house on the hill (Forlorn Rowe) north of Raven Hill Cemetery, then kill him", 16.9, 33.4, 31),
    T("Morbent Fel", "Sven Yorgen", 7.8, 34.1, 31),
} }

-- Sources: https://wowhandbook.com/zones/eastern-kingdoms/hillsbrad-foothills/ https://urgametips.com/wow-forever/zones/hillsbrad-foothills/ https://urgametips.com/wow-forever/quest-guides/ (individual quest pages) https://games.gg/world-of-warcraft/guides/wow-forever-hillsbrad-foothills-leveling-guide/ https://wowforever.wiki.fextralife.com/Hillsbrad+Foothills
-- Hillsbrad Foothills (Alliance) for WoW: Forever.
-- Sources: https://wow4ever.quest/en/quests/<slug> and /en/npcs/<slug> (Questie Forever data: ids, min levels, givers, coords, "First you need"/"Then comes");
-- https://foreverchanges.pro/quests/hillsbrad-foothills and /quests/alterac-mountains (Forever lists, New tags) and /quest/<id> (givers of the New quests);
-- https://www.wowhead.com/forever/quest=<id> (series/objective text). Mob positions: warcraft.wiki.gg (Classic) + the current route, Forever sources have no mob pages.
-- Forever New quests used: Brewer's Trade (98071), Hillsbrad's Hoard (98059), Talk of the Town (98463), An Alarming Request (92432); The Shamed Lieutenant (98219) is turned in here.
-- Part numbers: "Farren's Proof" 1-3 = 559, 560, 561 (three Forever quests sharing the title). "Hints of a New Plague?" part 1 = 659 (Arathi owns the list).
-- Left out: Crushridge Bounty/Warmongers (36-40), Preserving Knowledge/Return to Milton (38), Further Mysteries + Stormpike chain (Ironforge), Assassin's Contract/Baron's Demise/Dark Council (38-40),
--   Strahnbrad Mystery (36, drop-started), Heart of Disruption/Friend of the Kirin Tor (Silverpine/Dalaran), all Horde quests.
-- Cross-zone: Reassignment -> Stormwind; Letter to Stormpike -> Ironforge; Hints of a New Plague? 1 -> Quae (Arathi); Talk of the Town -> Booty Bay; An Alarming Request -> Image of Archmage Modera (Silverpine, Lordamere Lake);
--   Southshore, The Shamed Lieutenant (Stormwind) and MacKreel's Moonshine (Foggy MacKreel, south Arathi) are accepted elsewhere and only turned in here.
local HILLSBRAD = { zone = "Hillsbrad Foothills", min = 28, max = 32, steps = {
    -- Arrival in Southshore (boat/flight from Menethil, or the road from Arathi)
    G("Southshore flight path (Darla Harris)", 49.4, 52.1, 28, "Get the flight path"),
    G("Southshore inn (Innkeeper Anderson)", 51.0, 58.8, 28, "Set your hearthstone here"),
    T("Southshore", "Loremaster Dibbs", 50.6, 57.1, 28),
    T("The Shamed Lieutenant", "Lieutenant Farren Orinelle", 51.5, 58.4, 28),
    T("MacKreel's Moonshine", "Brewmeister Bilger", 52.1, 58.7, 28),
    -- Southshore pick-ups (level 28 set)
    A("Down the Coast", "Lieutenant Farren Orinelle", 51.5, 58.4, 28),
    A("Brewer's Trade", "Brewmeister Bilger (Forever NEW)", 52.1, 58.7, 28),
    A("Soothing Turtle Bisque", "Chef Jessen", 51.9, 58.7, 28),
    A("Talk of the Town", "Barkeep Kelly (Forever NEW, ends in Booty Bay)", 51.5, 58.7, 28),
    A("Syndicate Assassins", "Magistrate Henry Maleb", 48.1, 59.1, 28),
    A("Hillsbrad's Hoard", "Captain McManus (Forever NEW, north-west of town)", 46.4, 50.2, 28),

    -- Western Strand murlocs
    D("Down the Coast", "Kill 10 Torn Fin Tidehunters and 10 Torn Fin Oracles along the Western Strand", 48.6, 64.4, 28),
    T("Down the Coast", "Lieutenant Farren Orinelle", 51.5, 58.4, 29),
    A("Farren's Proof", "Lieutenant Farren Orinelle", 51.5, 58.4, 29, 1),
    D("Farren's Proof", "Loot 10 Murloc Heads from Torn Fin murlocs on the Western Strand", 48.6, 65.0, 29, 1),
    -- Hillsbrad Fields (west, then north along the road)
    D("Hillsbrad's Hoard", "Walk into Hillsbrad's town hall and place the Sealed Company Request on the bookkeeping table (friendly town, no fighting)", 31.5, 45.0, 29),
    T("Hillsbrad's Hoard", "Captain McManus", 46.4, 50.2, 29),
    -- Back in Southshore: the Farren chain
    T("Farren's Proof", "Lieutenant Farren Orinelle", 51.5, 58.4, 29, 1),
    A("Farren's Proof", "Lieutenant Farren Orinelle", 51.5, 58.4, 29, 2),
    T("Farren's Proof", "Marshal Redpath", 49.5, 58.7, 29, 2),
    A("Farren's Proof", "Marshal Redpath", 49.5, 58.7, 29, 3),
    T("Farren's Proof", "Lieutenant Farren Orinelle", 51.5, 58.4, 29, 3),
    A("Stormwind Ho!", "Lieutenant Farren Orinelle", 51.5, 58.4, 29),

    -- East: the river turtles, the Eastern Strand naga and Dun Garok
    D("Soothing Turtle Bisque", "Loot 10 Turtle Meat from Snapjaws in the river east of Southshore", 55.9, 57.1, 29),
    D("Stormwind Ho!", "Kill 10 Daggerspine Shorehunters and 10 Daggerspine Sirens on the Eastern Strand", 55.5, 64.5, 30),
    D("Brewer's Trade", "Enter the Dun Garok fort (friendly dwarves) and set the Case of Fallrook Varietal by the fireplace at the bottom; take the Sack of Homebrew Hops", 70.5, 79.5, 30),
    -- Back in Southshore
    G("Southshore trade goods (Micha Yance)", 51.3, 58.3, 30, "Buy Soothing Spices for the bisque from the trade-goods vendor"),
    T("Soothing Turtle Bisque", "Chef Jessen", 51.9, 58.7, 30),
    T("Brewer's Trade", "Brewmeister Bilger", 52.1, 58.7, 30),
    T("Stormwind Ho!", "Lieutenant Farren Orinelle", 51.5, 58.4, 30),
    A("Reassignment", "Lieutenant Farren Orinelle (ends in Stormwind Keep)", 51.5, 58.4, 30),
    -- Level 30 pick-ups
    A("Hints of a New Plague?", "Phin Odelic (ends at Go'Shek Farm, Arathi)", 50.4, 59.0, 30, 1),
    A("An Alarming Request", "Emissary Jacques (Forever NEW, ends at Lordamere Lake, Silverpine)", 48.4, 60.0, 30),
    A("Costly Menace", "Darren Malvew (stables)", 52.4, 56.0, 30),
    A("Bartolo's Yeti Fur Cloak", "Bartolo Ginsetti (needs Bolt of Wool, Hillman's Cloak, Fine Thread)", 49.4, 55.5, 30),

    -- North: Darrow Hill yetis, then the Alterac Mountains
    D("Bartolo's Yeti Fur Cloak", "Loot 10 Yeti Fur from the yetis in the Darrow Hill caverns", 44.5, 29.5, 30),
    G("Road north into the Alterac Mountains", 47.4, 5.4, 31, "Lions roam the southern Alterac hills; the Syndicate camps are at Corrahn's Dagger, Sofera's Naze and Gallows' Corner"),
    D("Costly Menace", "Kill 8 Mountain Lions and 10 Hulking Mountain Lions in the hills north-west of Hillsbrad Fields", 38.8, 24.6, 31),
    D("Syndicate Assassins", "Kill 12 Syndicate Footpads and 8 Syndicate Thieves at the Syndicate camps (Alterac Mountains); keep the Syndicate Documents drops: Foreboding Plans and Encrypted Letter", 47.4, 5.4, 31),
    -- Back to Southshore
    G("Return to Southshore", 49.9, 56.4, 32),
    T("Bartolo's Yeti Fur Cloak", "Bartolo Ginsetti", 49.4, 55.5, 32),
    T("Costly Menace", "Darren Malvew", 52.4, 56.0, 32),
    T("Encrypted Letter", "Loremaster Dibbs", 50.6, 57.1, 32),
    A("Letter to Stormpike", "Loremaster Dibbs (ends in Ironforge)", 50.6, 57.1, 32),
    T("Syndicate Assassins", "Magistrate Henry Maleb", 48.1, 59.1, 32),
    T("Foreboding Plans", "Magistrate Henry Maleb", 48.1, 59.1, 32),
    A("Noble Deaths", "Magistrate Henry Maleb", 48.1, 59.1, 32),
    -- Second Alterac trip for the signet rings
    D("Noble Deaths", "Loot 7 Alterac Signet Rings from Syndicate Enforcers, Spies, Saboteurs, Assassins, Wizards and Sentries (Alterac Mountains)", 47.4, 5.4, 32),
    T("Noble Deaths", "Magistrate Henry Maleb", 48.1, 59.1, 32),
    G("Southshore flight path", 49.4, 52.1, 32, "Out-of-zone turn-ins: Reassignment (Major Samuelson, Stormwind Keep), Letter to Stormpike (Prospector Stormpike, Ironforge), Hints of a New Plague? (Quae, Go'Shek Farm, Arathi), Talk of the Town (Nixxrax Fillamug, Booty Bay), An Alarming Request (Image of Archmage Modera, Lordamere Lake shore, Silverpine)"),
} }

-- Sources: https://wowhandbook.com/zones/eastern-kingdoms/arathi-highlands/ ; https://urgametips.com/wow-forever/zones/arathi-highlands/ (and its linked quest-guides pages) ; https://wowforever.wiki.fextralife.com/Arathi+Highlands ; https://wow4ever.quest/en/npcs (NPC pages) and https://wow4ever.quest/en/quests (quest pages)
-- Arathi Highlands (Alliance) for WoW: Forever.
-- Sources: https://wow4ever.quest/en/quests/<slug> and /en/npcs/<slug> (Questie Forever data: ids, min levels, givers, coords, "First you need");
-- https://foreverchanges.pro/quests/arathi-highlands (53-quest Forever list, New/Changed/Elite tags) and /quest/<id> (chain boxes, drop sources);
-- https://wow4ever.quest/en/articles/guia-subida-30-40-wow-forever (Questie-computed Alliance route: objective coordinates for mobs/objects);
-- warcraft.wiki.gg (Northfold Manor, Syndicate Prowler, Marez Cowl, Daggerspine Raider, Drowned Reef wrecks) only where Forever sources gave no coordinates.
-- Part numbers: "Hints of a New Plague?" 1-5 = 659, 657, 658, 660, 661 (part 1 accepted in Hillsbrad, part 5 turned in at Southshore);
-- "Malin's Request" 1-2 = 690, 697 (part 1 accepted in Stormwind, part 2 turned in at Stormwind);
-- "Sunken Treasure" 1-5 = 665, 666, 668, 669, 670 (parts 1-4 here; part 4 is turned in and part 5 accepted/turned in via Booty Bay).
-- Elite (Forever "Elite" tag, group): Stromgarde Badges, Wanted! Marez Cowl, Wanted! Otto and Falconcrest, Trelane's Defenses,
-- An Apprentice's Enchantment, Attack on the Tower, Malin's Request (part 2), Breaking the Keystone (foreverchanges.pro Elite tags).
-- Forever "New" quests not routed (Questie/wow4ever has no giver or coordinates for them): Dutiful Steps (92872, Alliance, 38),
-- Ground to Keep (92867, elite, 39), Anyone Can Cook (79624, 40). Left out: Crystal in the Mountains (635, starts from the world-drop
-- Pendant of Myzrael: G note instead), Legends of the Earth <NYI> (636), Death From Below (667, lvl 44, needs Sunken Treasure part 5),
-- Theldurin the Lost (687, accepted in Ironforge), Summoning the Princess (656, lvl 50), all Horde quests.
-- Cross-zone: Plea To The Alliance (Wetlands) and Malin's Request part 1 (Stormwind) are turned in here; Hints of a New Plague? part 1 is
-- accepted in Hillsbrad; Malin's Request part 2 -> Stormwind, Sunken Treasure part 4 -> Booty Bay, Hints part 5 -> Southshore,
-- Myzrael's Allies -> Ironforge (closing G note).
local ARATHI = { zone = "Arathi Highlands", min = 30, max = 40, steps = {
    -- Refuge Pointe (arriving from the Wetlands over Thandol Span)
    G("Refuge Pointe flight path", 45.8, 46.1, 30, "Get the flight path and set your hearthstone at Refuge Pointe"),
    T("Plea To The Alliance", "Captain Nials", 45.8, 47.6, 30),
    T("Malin's Request", "Skuerto", 46.6, 47.0, 30, 1),
    A("Northfold Manor", "Captain Nials", 45.8, 47.6, 30),
    A("Wanted! Marez Cowl", "Wanted Board (ELITE, group)", 46.0, 47.8, 30),
    A("Wanted! Otto and Falconcrest", "Wanted Board (ELITE, group)", 46.0, 47.8, 30),
    A("Worth Its Weight in Gold", "Apprentice Kryten", 46.2, 47.8, 30),

    -- Northfold Manor (north-west)
    D("Northfold Manor", "Kill 10 Syndicate Highwaymen around Northfold Manor", 32.5, 26.3, 30),
    D("Northfold Manor", "Kill 6 Syndicate Mercenaries in and around the manor", 33.7, 29.8, 31),
    T("Northfold Manor", "Captain Nials", 45.8, 47.6, 31),
    A("Stromgarde Badges", "Captain Nials (ELITE, group)", 45.8, 47.6, 31),

    -- Shards of Myzrael and Drywhisker Gorge (north-east)
    G("Shards of Myzrael", 62.5, 33.7, 31, "If you looted a Pendant of Myzrael (world drop), use it and turn in Crystal in the Mountains here"),
    A("The Princess Trapped", "Shards of Myzrael (crystal cluster)", 62.5, 33.7, 31),
    D("The Princess Trapped", "Collect 12 Motes of Myzrael from Drywhisker kobolds in Drywhisker Gorge and its cave", 82.6, 34.0, 32),
    T("The Princess Trapped", "Iridescent Shards (deep in the Drywhisker cave)", 84.3, 30.9, 33),
    A("Stones of Binding", "Iridescent Shards", 84.3, 30.9, 33),
    D("Stones of Binding", "Cresting Key: kill Cresting Exiles at the Circle of East Binding", 66.7, 29.7, 33),

    -- Witherbark Village (south-east)
    D("Worth Its Weight in Gold", "4 Witherbark Medicine Pouches from Witherbark Witch Doctors north of the village", 69.2, 68.3, 34),
    D("Worth Its Weight in Gold", "10 Witherbark Tusks and 1 Shadow Hunter Knife from Witherbark trolls; Shadow Hunters are in the cave south of the village", 67.7, 78.3, 34),

    -- Go'Shek Farm: Quae and Kinelory
    T("Hints of a New Plague?", "Quae", 60.2, 53.9, 34, 1),
    A("Hints of a New Plague?", "Quae", 60.2, 53.9, 34, 2),
    T("Hints of a New Plague?", "Kinelory", 60.2, 53.9, 34, 2),
    A("Hints of a New Plague?", "Quae", 60.2, 53.9, 34, 3),
    D("Hints of a New Plague?", "Kill the Forsaken Courier (walks with 4 Forsaken Bodyguards from the small house south of Go'Shek Farm toward Hillsbrad) and loot the Sealed Folder. Location approximate: start at the house and follow the road west", 52.5, 61.5, 34, 3),
    T("Hints of a New Plague?", "Quae", 60.2, 53.9, 35, 3),
    A("Hints of a New Plague?", "Kinelory (ESCORT)", 60.2, 53.9, 35, 4),
    D("Hints of a New Plague?", "Escort Kinelory into Go'Shek Farm; she loots the farmhouse and walks back to Quae (ESCORT)", 60.2, 53.9, 35, 4),
    T("Hints of a New Plague?", "Quae", 60.2, 53.9, 35, 4),
    A("Hints of a New Plague?", "Quae (turn in to Phin Odelic in Southshore later)", 60.2, 53.9, 35, 5),

    -- Back to Refuge Pointe via the Circle of Outer Binding
    D("Stones of Binding", "Thundering Key: kill Thundering Exiles at the Circle of Outer Binding", 52.0, 50.7, 35),
    T("Worth Its Weight in Gold", "Apprentice Kryten", 46.2, 47.8, 35),
    A("Wand over Fist", "Skuerto", 46.6, 47.0, 35),

    -- Boulderfist Hall (south)
    D("Wand over Fist", "Boulderfist Hall, the larger cave: kill Kor'gresh Coldrage for Trelane's Wand of Invocation", 54.8, 81.9, 36),
    T("Wand over Fist", "Skuerto", 46.6, 47.0, 36),
    A("Trelane's Defenses", "Skuerto (ELITE, group)", 46.6, 47.0, 36),

    -- Circle of West Binding, then Stromgarde Keep (first trip)
    D("Stones of Binding", "Burning Key: kill Burning Exiles at the Circle of West Binding", 25.6, 30.4, 36),
    D("Stromgarde Badges", "Stromgarde Keep, Syndicate quarter (first left inside the gate): 7 Stromgarde Badges from Syndicate Prowlers, Conjurors and Magi (ELITE, group)", 29.6, 63.0, 37),
    D("Wanted! Marez Cowl", "Stromgarde Keep: Marez Cowl stands behind the house at the dead end of the Syndicate quarter, near a well (also spawns at 29,62); loot Marez's Head (ELITE, group)", 27.0, 64.0, 37),
    D("Wanted! Otto and Falconcrest", "Stromgarde Keep: straight down the main road to the inner keep at the back, upper floor; loot Otto's Head and Falconcrest's Head (ELITE, group)", 26.1, 65.6, 38),
    D("Trelane's Defenses", "Stromgarde Keep, ogre quarter (right before the ramp, then left): Azure Agate from Boulderfist Shamans (ELITE, group)", 20.0, 67.4, 38),
    T("Stones of Binding", "Stone of Inner Binding (opens; Thenan spawns)", 36.2, 57.4, 38),
    A("Breaking the Keystone", "Stone of Inner Binding (ELITE, group)", 36.2, 57.4, 38),

    -- Refuge Pointe turn-ins
    T("Stromgarde Badges", "Captain Nials", 45.8, 47.6, 38),
    T("Wanted! Marez Cowl", "Captain Nials", 45.8, 47.6, 38),
    T("Wanted! Otto and Falconcrest", "Captain Nials", 45.8, 47.6, 38),
    T("Trelane's Defenses", "Apprentice Kryten", 46.2, 47.8, 38),
    A("An Apprentice's Enchantment", "Apprentice Kryten (ELITE, group)", 46.2, 47.8, 38),
    T("An Apprentice's Enchantment", "Skuerto", 46.6, 47.0, 38),
    A("Attack on the Tower", "Skuerto (ELITE, group)", 46.6, 47.0, 38),

    -- Tower of Arathor, then Faldir's Cove (second south-west trip)
    D("Attack on the Tower", "Tower of Arathor in Stromgarde Keep: open the Footlocker (Trelane's Phylactery), Lockbox (Trelane's Orb) and Chest (Trelane's Ember Agate); each spawns an ogre shaman and a brute (ELITE, group)", 18.2, 68.1, 39),
    A("Land Ho!", "Lolo the Lookout", 31.8, 82.7, 39),
    T("Land Ho!", "Shakes O'Breen", 32.3, 81.4, 39),
    A("Deep Sea Salvage", "First Mate Nilzlix", 32.8, 81.5, 39),
    A("Drowned Sorrows", "Captain Steelgut", 34.0, 80.8, 39),
    A("Sunken Treasure", "Professor Phizzlethorpe (ESCORT)", 33.9, 80.5, 39, 1),
    D("Sunken Treasure", "Escort Professor Phizzlethorpe up the hill to the cave above Faldir's Cove and back (ESCORT)", 33.9, 80.5, 39, 1),
    T("Sunken Treasure", "Doctor Draxlegauge", 33.9, 80.5, 39, 1),
    A("Sunken Treasure", "Doctor Draxlegauge (gives Goggles of Gem Hunting)", 33.9, 80.5, 39, 2),
    D("Drowned Sorrows", "Kill 10 Daggerspine Raiders and 3 Daggerspine Sorceresses in the sea off Faldir's Cove", 21.9, 86.1, 40),
    D("Deep Sea Salvage", "Drowned Reef wrecks: Maiden's Folly Charts and Log (16.4, 87.1), Spirit of Silverpine Charts and Log (13.9, 87.7); Questie places all four at 23.4, 85.1", 16.4, 87.1, 40),
    D("Sunken Treasure", "Wear the Goggles of Gem Hunting and collect 10 Elven Gems (Calcified Elven Gems) on the sea floor around the wrecks", 23.4, 85.1, 40, 2),
    T("Drowned Sorrows", "Captain Steelgut", 34.0, 80.8, 40),
    T("Deep Sea Salvage", "First Mate Nilzlix", 32.8, 81.5, 40),
    T("Sunken Treasure", "Doctor Draxlegauge", 33.9, 80.5, 40, 2),
    A("Sunken Treasure", "Doctor Draxlegauge", 33.9, 80.5, 40, 3),
    T("Sunken Treasure", "Shakes O'Breen", 32.3, 81.4, 40, 3),
    A("Sunken Treasure", "Shakes O'Breen (turn in to Fleet Master Seahorn in Booty Bay later)", 32.3, 81.4, 40, 4),

    -- Fozruk and the Keystone on the way back
    D("Breaking the Keystone", "Kill Fozruk for the Rod of Order; the stone giant patrols the main road between Thoradin's Wall, Refuge Pointe and Hammerfall (ELITE, group)", 67.7, 37.6, 40),
    T("Breaking the Keystone", "Keystone (next to the Stone of Inner Binding)", 36.1, 58.1, 40),
    A("Myzrael's Allies", "Keystone (turn in to Gerrig Bonegrip, Forlorn Cavern, Ironforge)", 36.1, 58.1, 40),

    -- Refuge Pointe: last turn-in and leaving the zone
    T("Attack on the Tower", "Skuerto", 46.6, 47.0, 40),
    A("Malin's Request", "Skuerto (ELITE, group; turn in to Archmage Malin, Stormwind)", 46.6, 47.0, 40, 2),
    G("Refuge Pointe flight path", 45.8, 46.1, 40, "Leave the zone: Malin's Request to Archmage Malin (Stormwind, Mage Quarter 50.5, 87.5); Sunken Treasure to Fleet Master Seahorn (Booty Bay 27.2, 77.0; he gives part 5 back to Shakes O'Breen); Hints of a New Plague? to Phin Odelic (Southshore 50.4, 59.0); Myzrael's Allies to Gerrig Bonegrip (Ironforge 50.8, 5.6)"),
} }

-- Sources: https://wowhandbook.com/zones/kalimdor/desolace/ ; https://games.gg/world-of-warcraft/guides/wow-forever-desolace-leveling-guide/ ; https://wow4ever.quest/en/npcs (NPC pages) and https://wow4ever.quest/en/quests (quest pages) ; https://www.wowhead.com/forever/quest=1454 ; https://warcraft.wiki.gg/wiki/Desolace_questing_guide (cross-check)
-- Desolace (Alliance) for WoW: Forever.
-- Sources: https://wow4ever.quest/en/quests/<slug> and /en/npcs/<slug> (Questie Forever data: IDs, min levels, givers, coords, "First you need"/"Then comes");
-- https://foreverchanges.pro/quests/desolace and /quest/<id> (Forever list with New/Changed tags, New-quest givers and chain lists);
-- https://wow4ever.quest/en/articles/guia-subida-30-40-wow-forever (QuestieDB objective coordinates); warcraft.wiki.gg only for a few
-- objective spots (Burning Blade Seer 55.2,30.1; ghost-magnet spot 63.7,91.8; Valley of Bones; key/satchel drop mobs). wowhead/forever was unreachable (403).
-- Part numbers: "Reagents for Reclaimers Inc." 1-4 = 1458, 1459, 1466, 1467; "The Karnitol Shipwreck" 1-4 = 1454, 1455, 1456, 1457;
-- "Vahlarriel's Search" 1-3 = 1437, 1465, 1438; "Down the Scarlet Path" 1-2 = 261, 1052.
-- Forever NEW quests used: Vahlarriel's Vengeance 97284, Carved Centaur Totems 93224, Buying Friendship: Gelkis 93227.
-- Forever CHANGED (foreverchanges.pro, no route effect): Bodyguard for Hire 5821 (rename note only), Gizelton Caravan 5943 (extra reward
-- Farseer's Forgotten Shield), The Karnitol Shipwreck part 4 1457 (2250 XP instead of 1500).
-- Left out (Forever NEW, past Ongeku or lvl 38-43): Valley of Bones 93034, Ravaging Ravagers 93035, Facing the Truth 93041, A Cleansing Cry 93044,
-- Test Your Theory 93045, Khan Jehn 93128/93196 (Saving Our Own chain, lvl 42), Notes on Draenethyst 93465 (needs The Visiting Mage 93464, lvl 40).
-- Left out: Brutal Politics/Assault on the Kolkar/Broken Tears/Gizmo for Warug/Khan Shaka/A Conqueror's Crown (Magram side, conflicts with the
-- Gelkis path and Strange Alliance); Stealing Supplies/Ongeku/Khan Jehn/Khan Hratha and the new Gelkis chain 93034-93045 (Ongeku needs a
-- Draenethyst Shard from the Swamp of Sorrows; left as a G note); I Need a Tailor/Leather Technique/Mysterious Mysticism/Big, No, MASSIVE Iron
-- Axes/A New Need for Shadow Protection (crafted-item reputation hand-ins); Economic Warfare/Buying Friendship: Magram (Magram or repeatable);
-- Khan Hratha 96222 (lvl 42 elite); Horde quests; Cherry for Your Thoughts?/Highway Robbery/No Honor Among Thieves/On the Lam (lvl 40, giver unknown).
-- Cross-zone: "Reclaimers' Business in Desolace" is accepted in Ironforge (Roetten Stonehammer) and only turned in here; Reagents part 4,
-- Karnitol part 4 (Roetten Stonehammer, Ironforge) and Down the Scarlet Path part 2 (Raleigh the Devout, Southshore) are accepted here and end elsewhere.
local DESOLACE = { zone = "Desolace", min = 30, max = 40, steps = {
    -- Nijel's Point
    G("Nijel's Point flight path", 64.7, 10.4, 30, "Grab the flight path; inn and hearth with Innkeeper Lyshaerya next to it"),
    T("Reclaimers' Business in Desolace", "Kreldig Ungor", 66.2, 9.6, 30),
    A("Reagents for Reclaimers Inc.", "Kreldig Ungor", 66.2, 9.6, 30, 1),
    A("The Karnitol Shipwreck", "Kreldig Ungor", 66.2, 9.6, 30, 1),
    A("Vahlarriel's Search", "Vahlarriel Demonslayer", 66.4, 11.8, 30, 1),
    A("Vahlarriel's Vengeance", "Vahlarriel Demonslayer (Forever NEW)", 66.4, 11.8, 30),
    A("Centaur Bounty", "Corporal Melkins", 66.7, 10.9, 30),
    A("Strange Alliance", "Captain Pentigast (needs Gelkis Friendly later)", 66.7, 10.9, 30),
    A("Carved Centaur Totems", "Captain Pentigast (Forever NEW)", 66.7, 10.9, 30),

    -- Sargeron (east of Nijel's Point)
    D("Reagents for Reclaimers Inc.", "Kill Hatefury satyrs in the Sargeron ruins for 10 Hatefury Claws and 10 Hatefury Horns", 75.9, 18.7, 31, 1),
    T("Reagents for Reclaimers Inc.", "Kreldig Ungor", 66.2, 9.6, 32, 1),
    A("Reagents for Reclaimers Inc.", "Kreldig Ungor", 66.2, 9.6, 32, 2),

    -- Malem wagon and Thunder Axe Fortress
    T("Vahlarriel's Search", "Malem Chest (the Malems' wagon north of Thunder Axe Fortress)", 56.5, 17.8, 32, 1),
    A("Vahlarriel's Search", "Malem Chest", 56.5, 17.8, 32, 2),
    T("Vahlarriel's Search", "Vahlarriel Demonslayer", 66.4, 11.8, 32, 2),
    A("Vahlarriel's Search", "Vahlarriel Demonslayer", 66.4, 11.8, 32, 3),
    D("Vahlarriel's Vengeance", "Thunder Axe Fortress: kill 4 Burning Blade Augurs, 4 Reavers, 4 Adepts and 4 Felsworn", 54.9, 27.6, 32),
    T("Vahlarriel's Search", "Dalinda Malem (inside Thunder Axe Fortress)", 54.9, 26.1, 33, 3),
    A("Search for Tyranis", "Dalinda Malem", 54.9, 26.1, 33),
    D("Search for Tyranis", "Kill Tyranis Malem (level 36) in the fortress for the Malem Pendant; pull him alone", 53.0, 29.1, 33),
    T("Search for Tyranis", "Dalinda Malem", 54.9, 26.1, 33),
    A("Return to Vahlarriel", "Dalinda Malem (ESCORT)", 54.9, 26.1, 33),
    D("Return to Vahlarriel", "Escort Dalinda Malem out of Thunder Axe Fortress (ESCORT)", 54.9, 26.1, 33),
    T("Return to Vahlarriel", "Vahlarriel Demonslayer", 66.4, 11.8, 33),
    T("Vahlarriel's Vengeance", "Vahlarriel Demonslayer", 66.4, 11.8, 33),

    -- Ethel Rethor and the north-west coast
    A("Sceptre of Light", "Azore Aldamort (tower in Ethel Rethor)", 38.9, 27.2, 33),
    T("The Karnitol Shipwreck", "Karnitol's Chest (shore below Ethel Rethor)", 36.1, 30.4, 33, 1),
    A("The Karnitol Shipwreck", "Karnitol's Chest", 36.1, 30.4, 33, 2),
    A("Claim Rackmore's Treasure!", "Rackmore's Log (next to the chest)", 36.1, 30.4, 33),
    D("Claim Rackmore's Treasure!", "Kill Drysnap Pincers/Crawlers on the shore south-west of the lighthouse for Rackmore's Silver Key", 34.0, 37.0, 34),
    D("Claim Rackmore's Treasure!", "Kill Slitherblade naga along Sar'theris Strand for Rackmore's Golden Key", 33.5, 21.0, 34),
    D("Sceptre of Light", "Thunder Axe Fortress: kill the Burning Blade Seer (level 33) for the Sceptre of Light", 55.2, 30.1, 34),
    T("Sceptre of Light", "Azore Aldamort", 38.9, 27.2, 34),
    A("Book of the Ancients", "Azore Aldamort", 38.9, 27.2, 34),
    D("Book of the Ancients", "Swim to Ranazjar Isle and kill Lord Kragaru (level 38) for the Book of the Ancients", 29.5, 8.0, 34),
    T("Claim Rackmore's Treasure!", "Rackmore's Chest on Ranazjar Isle (both keys)", 30.0, 8.7, 34),
    T("Book of the Ancients", "Azore Aldamort", 38.9, 27.2, 35),
    T("The Karnitol Shipwreck", "Kreldig Ungor", 66.2, 9.6, 35, 2),
    A("The Karnitol Shipwreck", "Kreldig Ungor", 66.2, 9.6, 35, 3),

    -- South to Kormek's Hut, Kolkar Village and the caravan
    D("Reagents for Reclaimers Inc.", "Kill Scorpashi scorpids in the hills south of Sargeron for 7 Scorpashi Venom", 70.2, 29.3, 35, 2),
    A("Bone Collector", "Bibbly F'utzbuckle (Kormek's Hut)", 62.3, 39.0, 35),
    D("Centaur Bounty", "Kolkar Village: collect 15 Centaur Ears from any centaur", 69.1, 46.5, 35),
    D("Carved Centaur Totems", "Kolkar Village: loot 5 Carved Centaur Totems from centaur of any clan", 69.1, 46.5, 35),
    A("Bodyguard for Hire", "Cork Gizelton (caravan on the road north of Kolkar Village; it also parks at Kormek's Hut 60.4,38.1) (ESCORT)", 66.8, 58.1, 36),
    D("Bodyguard for Hire", "Escort the Gizelton Caravan past Kolkar Village to Scrabblescrew's Camp (ESCORT)", 60.9, 61.9, 36),
    T("Bodyguard for Hire", "Smeed Scrabblescrew", 60.9, 61.9, 36),
    A("Kodo Roundup", "Smeed Scrabblescrew", 60.9, 61.9, 36),
    D("Kodo Roundup", "Kodo Graveyard: use the Kodo Kombobulator on Aged/Ancient Kodos and walk 5 Tamed Kodos back to Smeed", 52.0, 59.0, 36),
    D("Reagents for Reclaimers Inc.", "Kodo Graveyard: skin/loot 3 Aged Kodo Hides from Aged Kodos", 52.0, 59.0, 36, 2),
    D("Bone Collector", "Kodo Graveyard: collect 10 Kodo Bones from the bone piles", 51.5, 59.6, 36),
    A("Ghost-o-plasm Round Up", "Hornizz Brimbuzzle (south-west of the Kodo Graveyard)", 47.8, 61.8, 36),
    T("Kodo Roundup", "Smeed Scrabblescrew", 60.9, 61.9, 36),
    A("Gizelton Caravan", "Rigger Gizelton (caravan at Scrabblescrew's Camp / Kormek's Hut) (ESCORT)", 66.7, 58.6, 37),
    D("Gizelton Caravan", "Escort the Gizelton Caravan south through Mannoroc Coven and back to Scrabblescrew's Camp (ESCORT)", 60.9, 61.9, 37),
    T("Gizelton Caravan", "Smeed Scrabblescrew", 60.9, 61.9, 37),

    -- Back to Nijel's Point (via Kormek's Hut)
    T("Bone Collector", "Bibbly F'utzbuckle (Kormek's Hut)", 62.3, 39.0, 37),
    T("Reagents for Reclaimers Inc.", "Kreldig Ungor", 66.2, 9.6, 37, 2),
    A("Reagents for Reclaimers Inc.", "Kreldig Ungor", 66.2, 9.6, 37, 3),
    T("Centaur Bounty", "Corporal Melkins", 66.7, 10.9, 37),
    T("Carved Centaur Totems", "Captain Pentigast", 66.7, 10.9, 37),
    A("Buying Friendship: Gelkis", "Captain Pentigast (Forever NEW, gives the Totem Tote)", 66.7, 10.9, 37),
    A("Down the Scarlet Path", "Brother Anton", 66.5, 7.9, 37, 1),

    -- Mannoroc Coven and the Valley of Bones
    D("Reagents for Reclaimers Inc.", "Mannoroc Coven: 10 Felhound Brains (Mana Eaters/Felhounds) and 10 Nether Wings (Nether Maidens)", 51.2, 77.2, 38, 3),
    D("Reagents for Reclaimers Inc.", "Southern Mannoroc Coven: 10 Doomwarder Blood from Doomwarders", 51.6, 83.8, 38, 3),
    D("Down the Scarlet Path", "Valley of Bones: destroy 30 Undead Ravagers", 63.5, 88.5, 38, 1),
    D("Ghost-o-plasm Round Up", "Drop the Crate of Ghost Magnets between the two Dead Goliaths at the south end of the valley, kill the Magrami Spectres for 8 Ghost-o-plasm", 63.7, 91.8, 38),

    -- Gelkis Village
    T("Buying Friendship: Gelkis", "Molkar, Gelkis Quartermaster (south end of Gelkis Village)", 35.7, 92.2, 39),
    G("Gelkis Village: Strange Alliance needs Friendly with the Gelkis", 36.2, 79.2, 39, "The Totem Tote gives a big boost; if still short, kill Magram centaur east of Scrabblescrew's Camp (Magram Village 72,68). Never kill Gelkis"),
    T("Strange Alliance", "Uthek the Wise", 36.2, 79.2, 39),
    A("Raid on the Kolkar", "Uthek the Wise", 36.2, 79.2, 39),

    -- Valley of Spears escort, then the Kolkar
    A("Get Me Out of Here!", "Melizza Brimbuzzle (Valley of Spears, by the big horn) (ESCORT)", 34.0, 53.5, 39),
    D("Get Me Out of Here!", "Escort Melizza Brimbuzzle east out of the Valley of Spears to Hornizz (ESCORT)", 47.8, 61.8, 39),
    T("Get Me Out of Here!", "Hornizz Brimbuzzle", 47.8, 61.8, 39),
    T("Ghost-o-plasm Round Up", "Hornizz Brimbuzzle", 47.8, 61.8, 39),
    D("Raid on the Kolkar", "Kolkar Village: loot 10 Crude Charms from Kolkar centaur", 71.7, 45.6, 39),
    T("Raid on the Kolkar", "Uthek the Wise", 36.2, 79.2, 40),
    G("Gelkis chain continues (optional)", 36.2, 79.2, 40, "Stealing Supplies (6 Crudely Dried Meat, Magram Village) then Ongeku needs a Draenethyst Shard from Ongeku in the Swamp of Sorrows; Khan Jehn, Valley of Bones 93034 and Khan Hratha (lvl 42 ELITE) follow"),

    -- Sar'theris Strand for the satchel, then leave from Nijel's Point
    D("The Karnitol Shipwreck", "Sar'theris Strand: kill Slitherblade Sea Witches and Tidehunters for Karnitol's Satchel", 33.5, 21.0, 40, 3),
    T("The Karnitol Shipwreck", "Kreldig Ungor", 66.2, 9.6, 40, 3),
    A("The Karnitol Shipwreck", "Kreldig Ungor (deliver to Roetten Stonehammer, Ironforge)", 66.2, 9.6, 40, 4),
    T("Reagents for Reclaimers Inc.", "Kreldig Ungor", 66.2, 9.6, 40, 3),
    A("Reagents for Reclaimers Inc.", "Kreldig Ungor (Leftwitch's Package to Roetten Stonehammer, Ironforge)", 66.2, 9.6, 40, 4),
    T("Down the Scarlet Path", "Brother Anton", 66.5, 7.9, 40, 1),
    A("Down the Scarlet Path", "Brother Anton (letter to Raleigh the Devout, Southshore)", 66.5, 7.9, 40, 2),
    G("Nijel's Point flight path", 64.7, 10.4, 40, "Leave Desolace: Karnitol's Satchel and Leftwitch's Package go to Roetten Stonehammer in Ironforge (70.0,21.3); Brother Anton's letter to Raleigh the Devout in Southshore, Hillsbrad (51.5,58.4)"),
} }

-- Sources: https://wowhandbook.com/zones/eastern-kingdoms/stranglethorn-vale/ , https://games.gg/world-of-warcraft/guides/wow-forever-stranglethorn-vale-leveling-guide/ , https://wowforever.wiki.fextralife.com/Stranglethorn+Vale , https://wow4ever.quest/en/npcs (QuestieDB Forever data: givers, objects, coords) ; Classic-only locations (Forever sources silent): https://warcraft.wiki.gg/wiki/Kurzen%27s_Mystery , https://warcraft.wiki.gg/wiki/Raptor_Mastery_(3) , https://warcraft.wiki.gg/wiki/Bhag%27thera , https://warcraft.wiki.gg/wiki/The_Curse_of_the_Tides , https://warcraft.wiki.gg/wiki/A_Meal_Served_Cold
-- Stranglethorn Vale (Alliance) for WoW: Forever.
-- Sources: https://wow4ever.quest/en/quests/<slug> and /en/npcs/<npc> (Questie Forever data: ids, givers, coords, min levels, "First you need");
-- https://foreverchanges.pro/quests/stranglethorn-vale (163-quest Forever list, New/Changed/Elite tags) and /quest/<id> (New quests: givers/coords);
-- https://www.wowhead.com/forever/quest=<id> (objectives). Classic wiki (warcraft.wiki.gg) only where Forever sources are silent:
-- Kurzen's Mystery tablet spots, "Pretty Boy" Duncan (beach north of the Booty Bay gate), Altar of the Tides, Colonel Kurzen (Stockpile cave),
-- Tethis / King Bangalash / Bhag'thera / Sin'Dall, Maury/Jon-Jon/Chucky (Ruins of Jubuwal/Aboraz): those coordinates are approximate.
-- Part numbers: "The Bloodsail Buccaneers" 1-5 = 595, 597, 599, 604, 608; "Tiger Mastery" 1-4 = 185, 186, 187, 188;
-- "Panther Mastery" 1-4 = 190, 191, 192, 193; "Raptor Mastery" 1-4 = 194, 195, 196, 197; "Sunken Treasure" 4-5 = 669, 670 (Arathi owns 1-5).
-- Forever NEW quests used: The Cook in the Cage (97047), Where's the Key? (97329), Zimmix's Great Escape (97331), Anything of Value (97328);
-- Talk of the Town (98463, accepted in Hillsbrad) is turned in here.
-- Elite in Forever (marked "ELITE, group"): Colonel Kurzen, Panther Mastery 4, Raptor Mastery 4, Big Game Hunter, The Curse of the Tides.
-- Left out: Mai'Zoth (46 elite), Excelsior (elite), Cracking Maury's Foot (elite, key source unverified), Stranglethorn Fever 348/349
-- (two-ID chain whose parts interleave: 348 must be held while 349 is turned in, which the part engine cannot express), Fool's Stout
-- (needs an Ironforge chain), Reduce, Reuse, Reconcile (giver location unverified), Returning to Port (giver/turn-in coords unverified),
-- Partial Mystical Notes / Message in a Bottle / Cortello's Riddle / The Captain's Chest chain / An OOX of Your Own (random item drops),
-- Whiskey Slim's Lost Grog, Akiris by the Bundle 623 (Theramore), A Meal Served Cold (Stormwind) and Pearl Diving (Badlands) belong to other routes.
-- Cross-zone: Talk of the Town (from Hillsbrad) and Sunken Treasure 4 (from Arathi) are turned in here; Magical Analysis is turned in to
-- Archmage Ansirem Runeweaver in Dalaran (Alterac Mountains) between visits 2 and 3 and Ansirem's Key is accepted there;
-- Sunken Treasure 5 -> Shakes O'Breen (Arathi); Stoley's Debt and Tran'rek -> Tanaris.
local STRANGLETHORN = { zone = "Stranglethorn Vale", min = 30, max = 45, steps = {
    -- Visit 1 (30-35): Rebel Camp and the Kurzen Compound
    G("Rebel Camp, walk south from Duskwood", 38.0, 3.0, 30, "Buy 4 Lesser Bloodstone Ore at the AH beforehand for Favor for Krazek"),
    A("Jungle Secrets", "Private Thorsen", 38.0, 3.4, 30),
    T("Jungle Secrets", "Lieutenant Doren", 38.0, 3.0, 30),
    A("Bookie Herod", "Lieutenant Doren", 38.0, 3.0, 30),
    A("The Second Rebellion", "Sergeant Yohwa", 38.0, 3.3, 30),
    A("Bad Medicine", "Sergeant Yohwa", 38.0, 3.3, 30),
    A("The Cook in the Cage", "Wendel Mathers (caged in the Kurzen Compound)", 44.3, 8.0, 31),
    D("The Second Rebellion", "Kill 15 Kurzen Jungle Fighters", 43.6, 9.7, 31),
    D("Bad Medicine", "Loot 7 Jungle Remedy from Kurzen troops", 43.7, 9.5, 31),
    D("Bad Medicine", "Venom Fern Extract from a Kurzen supplies crate", 44.1, 9.5, 31),
    T("Bookie Herod", "Bookie Herod's Records (object, hut on the compound's west side)", 43.7, 9.4, 31),
    A("The Hidden Key", "Bookie Herod's Records (object)", 43.7, 9.4, 31),
    D("The Cook in the Cage", "Find the Compound Cage Key and a Kurzen Fighter's Uniform inside the Kurzen Compound", 44.0, 9.0, 31),
    T("The Cook in the Cage", "Wendel Mathers", 44.2, 8.0, 32),
    T("The Hidden Key", "Bookie Herod's Strongbox (object, east side of the compound by the cave mouth)", 49.6, 7.6, 32),
    A("The Spy Revealed!", "Bookie Herod's Strongbox (object)", 49.6, 7.6, 32),
    T("The Second Rebellion", "Sergeant Yohwa", 38.0, 3.3, 32),
    T("Bad Medicine", "Sergeant Yohwa", 38.0, 3.3, 32),
    T("The Spy Revealed!", "Lieutenant Doren", 38.0, 3.0, 32),
    A("Patrol Schedules", "Lieutenant Doren", 38.0, 3.0, 32),
    T("Patrol Schedules", "Corporal Sethman", 37.7, 3.4, 32),
    A("Report to Doren", "Corporal Sethman", 37.7, 3.4, 32),
    T("Report to Doren", "Lieutenant Doren", 38.0, 3.0, 32),
    A("Krazek's Cookery", "Corporal Kaleb (min level 32)", 37.7, 3.3, 32),

    -- Nesingwary's Expedition
    G("Nesingwary's Expedition, south over the river bridge then west", 35.7, 10.8, 32),
    A("Welcome to the Jungle", "Barnil Stonepot", 35.7, 10.5, 32),
    T("Welcome to the Jungle", "Hemet Nesingwary", 35.7, 10.8, 32),
    A("Tiger Mastery", "Ajeck Rouack", 35.6, 10.6, 32, 1),
    A("Panther Mastery", "Sir S. J. Erlgadin", 35.5, 10.6, 32, 1),
    A("Raptor Mastery", "Hemet Nesingwary", 35.7, 10.8, 32, 1),
    A("The Green Hills of Stranglethorn", "Barnil Stonepot", 35.7, 10.5, 32),
    A("Chapter I", "Barnil Stonepot (pages 1, 4, 6, 8)", 35.7, 10.5, 32),
    A("Chapter II", "Barnil Stonepot (pages 10, 11, 14, 16)", 35.7, 10.5, 32),
    A("Chapter III", "Barnil Stonepot (pages 18, 20, 21, 24)", 35.7, 10.5, 32),
    A("Chapter IV", "Barnil Stonepot (pages 25, 26, 27)", 35.7, 10.5, 32),
    D("Tiger Mastery", "Kill 10 Young Stranglethorn Tigers", 35.6, 12.1, 32, 1),
    D("Panther Mastery", "Kill 10 Young Panthers", 36.6, 13.8, 32, 1),
    T("Tiger Mastery", "Ajeck Rouack", 35.6, 10.6, 33, 1),
    T("Panther Mastery", "Sir S. J. Erlgadin", 35.5, 10.6, 33, 1),
    A("Tiger Mastery", "Ajeck Rouack", 35.6, 10.6, 33, 2),
    A("Panther Mastery", "Sir S. J. Erlgadin", 35.5, 10.6, 33, 2),
    D("Tiger Mastery", "Kill 10 Stranglethorn Tigers", 30.8, 16.1, 33, 2),
    D("Panther Mastery", "Kill 10 Panthers", 30.4, 8.8, 33, 2),
    D("Raptor Mastery", "Kill 10 Stranglethorn Raptors", 27.8, 14.3, 33, 1),
    T("Tiger Mastery", "Ajeck Rouack", 35.6, 10.6, 34, 2),
    T("Panther Mastery", "Sir S. J. Erlgadin", 35.5, 10.6, 34, 2),
    T("Raptor Mastery", "Hemet Nesingwary", 35.7, 10.8, 34, 1),

    -- Booty Bay pick-ups
    G("Booty Bay flight path (Alliance)", 27.5, 77.7, 34, "Walk the road south or fly; set your hearth at the Salty Sailor Tavern"),
    T("Talk of the Town", "Nixxrax Fillamug (Salty Sailor Tavern; quest from Hillsbrad)", 27.1, 77.3, 34),
    T("Krazek's Cookery", "Krazek", 26.9, 77.2, 34),
    A("Favor for Krazek", "Krazek (needs 4 Lesser Bloodstone Ore)", 26.9, 77.2, 34),
    T("Favor for Krazek", "Krazek", 26.9, 77.2, 34),
    A("Return to Corporal Kaleb", "Krazek", 26.9, 77.2, 34),
    A("Supplies to Private Thorsen", "Krazek", 26.9, 77.2, 34),
    A("Investigate the Camp", "Krazek", 26.9, 77.2, 34),
    A("The Haunted Isle", "Krazek", 26.9, 77.2, 34),
    T("The Haunted Isle", "Baron Revilgaz (top floor of the inn)", 27.2, 76.9, 34),
    A("The Stone of the Tides", "Baron Revilgaz", 27.2, 76.9, 34),
    A("Supply and Demand", "Drizzlik", 28.3, 77.6, 34),
    A("Singing Blue Shards", "Crank Fizzlebub", 27.1, 77.2, 34),
    A("Bloodscalp Ears", "Kebok", 27.0, 77.1, 34),
    A("Hostile Takeover", "Kebok", 27.0, 77.1, 34),
    D("Singing Blue Shards", "Collect 10 Singing Crystal Shards from Crystal Spine Basilisks", 39.1, 52.0, 34),
    D("Investigate the Camp", "Walk among the hunters' tents at Nesingwary's Expedition", 35.7, 10.8, 35),
    D("Supply and Demand", "Collect 2 Large River Crocolisk Skins in the river", 39.9, 11.5, 35),
    T("Supplies to Private Thorsen", "Private Thorsen", 38.0, 3.4, 35),
    T("Return to Corporal Kaleb", "Corporal Kaleb", 37.7, 3.3, 35),

    -- Visit 2 (35-40): Kurzen again, Nesingwary tier 2-3, Zul'Kunda
    A("Kurzen's Mystery", "Brother Nimetz", 37.8, 3.6, 35),
    A("Special Forces", "Sergeant Yohwa", 38.0, 3.3, 35),
    D("Special Forces", "Kill 6 Kurzen Headshrinkers", 46.3, 7.0, 35),
    D("Special Forces", "Kill 10 Kurzen Commandoes", 46.5, 6.9, 36),
    D("Chapter I", "Green Hills pages 1, 4, 6, 8 drop at random from STV mobs (or buy them on the AH)", 44.7, 11.0, 36),
    T("Special Forces", "Lieutenant Doren", 38.0, 3.0, 36),
    G("Nesingwary's Expedition", 35.7, 10.8, 36),
    A("Tiger Mastery", "Ajeck Rouack", 35.6, 10.6, 36, 3),
    A("Raptor Mastery", "Hemet Nesingwary", 35.7, 10.8, 36, 2),
    A("Panther Mastery", "Sir S. J. Erlgadin", 35.5, 10.6, 36, 3),
    A("Anything of Value", "Thoroughly Scavenged Supplies (object)", 31.5, 12.8, 36),
    D("Tiger Mastery", "Kill 10 Elder Stranglethorn Tigers", 31.3, 16.6, 36, 3),
    D("Raptor Mastery", "Kill 10 Lashtail Raptors", 32.0, 20.7, 37, 2),
    D("Kurzen's Mystery", "Tablet 'Moon Over the Vale', NW corner of the Bal'lal Ruins", 29.0, 19.0, 37),
    D("Bloodscalp Ears", "Collect 15 Bloodscalp Ears from the coastal trolls", 29.8, 21.6, 37),
    D("Kurzen's Mystery", "Tablet 'Gri'lek the Wanderer', underwater on the Vile Reef's outer wall", 24.0, 22.0, 37),
    D("The Stone of the Tides", "Find the haunted island off the Vile Reef", 21.0, 22.8, 37),
    A("Where's the Key?", "Zimmix Sputterspark (Ruins of Zul'Kunda)", 23.4, 12.7, 37),
    D("Kurzen's Mystery", "Tablet 'Fall of Gurubashi', Zul'Kunda main compound on the plateau", 22.0, 12.0, 37),
    D("Kurzen's Mystery", "Tablet 'The Emperor's Tomb', Zul'Kunda NW room by the pool", 24.0, 9.0, 37),
    D("Where's the Key?", "Take the Primitive Key from the Zul'Kunda trolls", 22.5, 11.5, 37),
    D("Anything of Value", "Recover 8 Stolen Shipments in the Ruins of Zul'Kunda", 22.5, 11.0, 37),
    T("Where's the Key?", "Zimmix Sputterspark", 23.4, 12.7, 38),
    A("Zimmix's Great Escape", "Zimmix Sputterspark (ESCORT)", 23.4, 12.7, 38),
    D("Zimmix's Great Escape", "Escort Zimmix Sputterspark out of the Ruins of Zul'Kunda (ESCORT); report to Wharfmaster Lozgil later", 23.4, 12.7, 38),
    T("Tiger Mastery", "Ajeck Rouack", 35.6, 10.6, 38, 3),
    T("Raptor Mastery", "Hemet Nesingwary", 35.7, 10.8, 38, 2),
    A("Tiger Mastery", "Ajeck Rouack", 35.6, 10.6, 38, 4),
    A("Raptor Mastery", "Hemet Nesingwary", 35.7, 10.8, 38, 3),
    D("Tiger Mastery", "Kill Sin'Dall on the hilltop and take his paw", 31.5, 15.5, 38, 4),
    T("Tiger Mastery", "Ajeck Rouack", 35.6, 10.6, 38, 4),
    D("Panther Mastery", "Kill 10 Shadowmaw Panthers", 48.1, 20.2, 38, 3),
    D("Hostile Takeover", "Loot 8 Tumbled Crystals at the Venture Co. camp on Lake Nazferiti", 47.7, 19.0, 38),
    D("Chapter II", "Green Hills pages 10, 11, 14, 16 drop at random from STV mobs (or buy them on the AH)", 44.7, 11.0, 38),
    T("Kurzen's Mystery", "Brother Nimetz", 37.8, 3.6, 38),
    A("Troll Witchery", "Brother Nimetz", 37.8, 3.6, 38),
    T("Panther Mastery", "Sir S. J. Erlgadin", 35.5, 10.6, 38, 3),
    A("Panther Mastery", "Sir S. J. Erlgadin", 35.5, 10.6, 38, 4),

    -- Booty Bay, the haunted isle and the crocolisks
    G("Booty Bay flight path (Alliance)", 27.5, 77.7, 39),
    T("Investigate the Camp", "Krazek", 26.9, 77.2, 39),
    T("The Stone of the Tides", "Baron Revilgaz", 27.2, 76.9, 39),
    A("Water Elementals", "Baron Revilgaz", 27.2, 76.9, 39),
    T("Singing Blue Shards", "Crank Fizzlebub", 27.1, 77.2, 39),
    A("Venture Company Mining", "Crank Fizzlebub", 27.1, 77.2, 39),
    T("Bloodscalp Ears", "Kebok", 27.0, 77.1, 39),
    T("Hostile Takeover", "Kebok", 27.0, 77.1, 39),
    T("Supply and Demand", "Drizzlik", 28.3, 77.6, 39),
    A("Some Assembly Required", "Drizzlik", 28.3, 77.6, 39),
    T("Anything of Value", "Wharfmaster Lozgil (docks)", 26.3, 73.5, 39),
    T("Zimmix's Great Escape", "Wharfmaster Lozgil (docks)", 26.3, 73.5, 39),
    D("Some Assembly Required", "Collect 5 Snapjaw Crocolisk Skins", 37.9, 32.6, 39),
    D("Water Elementals", "Collect 6 Water Elemental Bracers on the haunted island", 21.5, 24.7, 39),
    T("Water Elementals", "Baron Revilgaz", 27.2, 76.9, 40),
    A("Magical Analysis", "Baron Revilgaz (turn in to Ansirem in Dalaran, Alterac Mountains)", 27.2, 76.9, 40),
    T("Some Assembly Required", "Drizzlik", 28.3, 77.6, 40),
    G("Booty Bay flight path: leave the zone for now", 27.5, 77.7, 40, "Take Magical Analysis to Archmage Ansirem Runeweaver in Dalaran (Alterac Mountains 18.8, 78.5, via Southshore) while you level in Hillsbrad/Arathi; accept Ansirem's Key there and bring it back to Catelyn the Blade"),

    -- Visit 3 (41-45): Bloodsail Buccaneers, Duncan, the jungle's south half, Nesingwary finale
    G("Booty Bay flight path (Alliance)", 27.5, 77.7, 41, "Back with Ansirem's Key (Alterac) and Sunken Treasure (Arathi)"),
    T("Ansirem's Key", "Catelyn the Blade (Salty Sailor Tavern; quest from Ansirem, Alterac)", 27.3, 77.5, 41),
    A("\"Pretty Boy\" Duncan", "Catelyn the Blade", 27.3, 77.5, 41),
    T("Sunken Treasure", "Fleet Master Seahorn (quest from Shakes O'Breen, Arathi)", 27.2, 77.0, 41, 4),
    A("Sunken Treasure", "Fleet Master Seahorn (turn in to Shakes O'Breen, Arathi)", 27.2, 77.0, 41, 5),
    A("The Bloodsail Buccaneers", "First Mate Crazz", 28.1, 76.2, 41, 1),
    A("Scaring Shaky", "\"Sea Wolf\" MacKinley", 27.8, 77.1, 41),
    A("Skullsplitter Tusks", "Kebok", 27.0, 77.1, 41),
    A("Zanzil's Secret", "Crank Fizzlebub", 27.1, 77.2, 41),
    A("Akiris by the Bundle", "Privateer Bloads", 26.8, 76.4, 41),
    T("The Bloodsail Buccaneers", "Bloodsail Correspondence (cove north of Booty Bay)", 27.3, 69.5, 41, 1),
    A("The Bloodsail Buccaneers", "Bloodsail Correspondence (object)", 27.3, 69.5, 41, 2),
    D("\"Pretty Boy\" Duncan", "Kill \"Pretty Boy\" Duncan on the beach north of the Booty Bay gate and take Catelyn's Blade", 27.0, 69.8, 41),
    D("Akiris by the Bundle", "Collect 10 Bundles of Akiris Reed along the shore", 28.2, 64.4, 41),
    D("Scaring Shaky", "Collect 5 Mistvale Giblets from Mistvale gorillas", 30.9, 66.7, 42),
    T("\"Pretty Boy\" Duncan", "Catelyn the Blade", 27.3, 77.5, 42),
    A("The Curse of the Tides", "Catelyn the Blade (ELITE, group)", 27.3, 77.5, 42),
    T("The Bloodsail Buccaneers", "First Mate Crazz", 28.1, 76.2, 42, 2),
    A("The Bloodsail Buccaneers", "First Mate Crazz", 28.1, 76.2, 42, 3),
    T("The Bloodsail Buccaneers", "Fleet Master Seahorn", 27.2, 77.0, 42, 3),
    A("The Bloodsail Buccaneers", "Fleet Master Seahorn", 27.2, 77.0, 42, 4),
    A("Keep An Eye Out", "Dizzy One-Eye", 28.6, 75.9, 42),
    A("Up to Snuff", "Deeg", 26.9, 77.3, 42),
    T("Akiris by the Bundle", "Privateer Bloads", 26.8, 76.4, 42),
    T("Scaring Shaky", "\"Shaky\" Phillipe (on the docks)", 26.9, 73.6, 42),
    A("Return to MacKinley", "\"Shaky\" Phillipe (on the docks)", 26.9, 73.6, 42),
    T("Return to MacKinley", "\"Sea Wolf\" MacKinley", 27.8, 77.1, 42),
    A("Voodoo Dues", "\"Sea Wolf\" MacKinley", 27.8, 77.1, 42),
    A("Stoley's Debt", "\"Sea Wolf\" MacKinley (turn in to Stoley, Tanaris)", 27.8, 77.1, 42),
    A("Tran'rek", "Krazek (turn in to Tran'rek, Gadgetzan, Tanaris)", 26.9, 77.2, 42),
    D("The Bloodsail Buccaneers", "Kill 10 Bloodsail Swashbucklers; loot the Bloodsail Charts and Bloodsail Orders in the Wild Shore camps", 27.7, 83.1, 42, 4),
    D("Keep An Eye Out", "Loot Dizzy's Eye from the Bloodsails", 29.6, 80.9, 43),
    D("Up to Snuff", "Collect 15 Snuff from any Bloodsail", 28.2, 82.4, 43),
    D("Chapter III", "Green Hills pages 18, 20, 21, 24 drop at random from STV mobs (or buy them on the AH)", 32.5, 81.6, 43),
    T("The Bloodsail Buccaneers", "Fleet Master Seahorn", 27.2, 77.0, 43, 4),
    T("Keep An Eye Out", "Dizzy One-Eye", 28.6, 75.9, 43),
    T("Up to Snuff", "Deeg", 26.9, 77.3, 43),

    -- North through the jungle
    D("Voodoo Dues", "Kill Maury \"Club Foot\" Wilkins, Jon-Jon the Crow and Chucky \"Ten Thumbs\" (Ruins of Jubuwal/Aboraz) for the foot, spyglass and ring", 34.9, 51.8, 43),
    D("Venture Company Mining", "Collect 10 Singing Blue Crystals at the Crystalvein Mine", 36.5, 57.1, 43),
    D("Zanzil's Secret", "Collect 12 Zanzil's Mixture in Zanzil's village", 38.7, 59.8, 43),
    D("Raptor Mastery", "Kill 10 Jungle Stalkers north and west of Gurubashi Arena", 32.0, 40.0, 43, 3),
    D("Skullsplitter Tusks", "Collect 18 Skullsplitter Tusks", 45.6, 41.6, 44),
    D("Troll Witchery", "Collect 4 Skullsplitter Fetishes", 42.5, 33.3, 44),
    D("Chapter IV", "Green Hills pages 25, 26, 27 drop at random from STV mobs (or buy them on the AH)", 42.5, 33.3, 44),
    D("Panther Mastery", "Kill Bhag'thera north of the Mosh'Ogg Ogre Mound for his fang (alt spawn 47, 28) (ELITE, group)", 49.0, 23.0, 44, 4),
    T("Troll Witchery", "Brother Nimetz", 37.8, 3.6, 44),
    A("Colonel Kurzen", "Lieutenant Doren (ELITE, group)", 38.0, 3.0, 44),
    D("Colonel Kurzen", "Kill 6 Kurzen Elites, 4 Kurzen Subchiefs and Colonel Kurzen in the Stockpile cave for his head (ELITE, group)", 49.6, 7.6, 44),
    T("Colonel Kurzen", "Lieutenant Doren", 38.0, 3.0, 44),
    G("Nesingwary's Expedition", 35.7, 10.8, 44),
    T("Panther Mastery", "Sir S. J. Erlgadin", 35.5, 10.6, 44, 4),
    T("Raptor Mastery", "Hemet Nesingwary", 35.7, 10.8, 44, 3),
    A("Raptor Mastery", "Hemet Nesingwary (ELITE, group)", 35.7, 10.8, 44, 4),
    T("Chapter I", "Barnil Stonepot", 35.7, 10.5, 44),
    T("Chapter II", "Barnil Stonepot", 35.7, 10.5, 44),
    T("Chapter III", "Barnil Stonepot", 35.7, 10.5, 44),
    T("Chapter IV", "Barnil Stonepot", 35.7, 10.5, 44),
    T("The Green Hills of Stranglethorn", "Barnil Stonepot", 35.7, 10.5, 44),
    D("Raptor Mastery", "Kill Tethis north of Gurubashi Arena for his talon (ELITE, group)", 31.5, 42.0, 45, 4),
    T("Raptor Mastery", "Hemet Nesingwary", 35.7, 10.8, 45, 4),
    A("Big Game Hunter", "Hemet Nesingwary (ELITE, group)", 35.7, 10.8, 45),
    D("Big Game Hunter", "Kill King Bangalash on the hill west of the road, north of Gurubashi Arena (ELITE, group)", 38.2, 35.6, 45),
    T("Big Game Hunter", "Hemet Nesingwary", 35.7, 10.8, 45),
    D("The Curse of the Tides", "Destroy the Altar of the Tides with Catelyn's Blade, kill Gazban, take the Stone of the Tides (ELITE, group)", 25.0, 23.6, 45),

    -- Booty Bay wrap-up
    G("Booty Bay flight path (Alliance)", 27.5, 77.7, 45),
    T("The Curse of the Tides", "Baron Revilgaz", 27.2, 76.9, 45),
    T("Voodoo Dues", "\"Sea Wolf\" MacKinley", 27.8, 77.1, 45),
    T("Venture Company Mining", "Crank Fizzlebub", 27.1, 77.2, 45),
    T("Zanzil's Secret", "Crank Fizzlebub", 27.1, 77.2, 45),
    T("Skullsplitter Tusks", "Kebok", 27.0, 77.1, 45),
    A("The Bloodsail Buccaneers", "Fleet Master Seahorn", 27.2, 77.0, 45, 5),
    D("The Bloodsail Buccaneers", "Kill Captain Keelhaul, Captain Stillwater and Fleet Master Firallon on the Bloodsail ships (group recommended)", 32.9, 88.2, 45, 5),
    T("The Bloodsail Buccaneers", "Fleet Master Seahorn", 27.2, 77.0, 45, 5),
    G("Booty Bay flight path: leave Stranglethorn", 27.5, 77.7, 45, "Stoley's Debt and Tran'rek go to Tanaris; Sunken Treasure part 5 goes to Shakes O'Breen (Faldir's Cove, Arathi Highlands)"),
} }

-- Sources: https://wowhandbook.com/zones/kalimdor/tanaris/ , https://wow4ever.quest/en/npcs (per-NPC pages, QuestieDB Forever data) , https://wowpedia.fandom.com/wiki/WANTED:_Caliph_Scorpidsting
-- Tanaris (Alliance) for WoW: Forever.
-- Sources: https://wow4ever.quest/en/quests/<slug> and /en/npcs/<slug> (Questie Forever data: ids, min levels, givers, coords, "First you need");
-- https://foreverchanges.pro/quests/tanaris (Forever list, Elite/Changed tags; no New quests in the band) and /quest/2781;
-- https://www.wowhead.com/forever/quest=<id> (series boxes, objectives); objective-area coordinates (mob camps, Scrimshank's gear 55.9,71.2,
-- Gahz'ridian concentrations 53,46 / 48,67 / 41,73, Dunemaul Compound 41,57) from warcraft.wiki.gg and the previous route file because
-- wow4ever has no pages for those mobs/objects (Classic-era positions; Forever is "same as Classic" for all these quests).
-- Part numbers: "Insect Part Analysis" 1-2 = 110, 113.
-- Left out: The Stone Watcher 2954 (ELITE, needs "Seeing What Happens" from the Uldaman chain, giver has no coords on record);
-- Find/Rescue OOX-17/TN! 351/648 (starts from a random beacon drop, escort ends in Booty Bay); The Super Egg-O-Matic 2741/8893 and the
-- egg quests 2747-2750 (lvl 60, need a Feralas Hippogryph Egg); Bungle in the Jungle 4496 (lvl 53, Un'Goro items); Water Pouch Bounty 1878
-- (repeatable variant); Sprinkle's Secret Ingredient 2641 / Delivery for Marin 2661 / Noggenfogger Elixir 2662 (Hinterlands owns 2641;
-- the two follow-ups need it turned in first); The Prophecy of Mosh'aru and later Yeh'kinya quests (Zul'Farrak); Into the Depths /
-- Secret of the Circle (Sunken Temple dungeon); Horde quests (Slake That Thirst, Another Power Source?, Into the Field, Tanaris Field
-- Sampling, Rise of the Silithid 32).
-- Cross-zone: Stoley's Debt 2872 (MacKinley, Booty Bay) and Tran'rek 2864 (Krazek, Booty Bay) are only turned in here; The Sunken
-- Temple 3445 is accepted in Feralas and turned in here; Deliver to MacKinley -> Booty Bay; Rise of the Silithid -> Darnassus;
-- Handle With Care -> Rut'theran Village; Screecher Spirits objective is in Feralas; Super Sticky objective is in Un'Goro Crater;
-- The Stone Circle objective is in Ratchet (The Barrens).
local TANARIS = { zone = "Tanaris", min = 43, max = 50, steps = {
    -- Gadgetzan (arrival from Thousand Needles / Feralas)
    G("Gadgetzan flight path", 51.0, 29.3, 43, "Get the flight path; Gadgetzan is neutral, the Wastewander and Southsea quests are shared by both factions"),
    T("Tran'rek", "Tran'rek (only if you carry Krazek's quest from Booty Bay)", 51.6, 26.8, 43),
    A("Wastewander Justice", "Chief Engineer Bilgewhizzle", 52.5, 28.5, 43),
    A("Water Pouch Bounty", "Spigot Operator Luglunket", 52.5, 28.4, 43),
    A("WANTED: Caliph Scorpidsting", "Wanted Poster (Gadgetzan, by the inn)", 51.8, 27.0, 43),
    A("Gadgetzan Water Survey", "Senior Surveyor Fizzledowser", 50.2, 27.5, 43),

    -- Sandsorrow Watch (short trip west)
    D("Gadgetzan Water Survey", "Use the Untapped Dowsing Widget at the small pool by Sandsorrow Watch, west of Gadgetzan", 39.0, 29.2, 43),
    T("Gadgetzan Water Survey", "Senior Surveyor Fizzledowser", 50.2, 27.5, 43),
    A("Noxious Lair Investigation", "Senior Surveyor Fizzledowser", 50.2, 27.5, 43),

    -- Wastewander camps east of Gadgetzan (Waterspring Field / Wavestrider Beach)
    D("Wastewander Justice", "Kill 10 Wastewander Bandits and Wastewander Thieves at the camps east of Gadgetzan", 63.8, 29.1, 43),
    D("Water Pouch Bounty", "Loot 5 Wastewander Water Pouches from the same Wastewander bandits", 63.9, 29.1, 44),

    -- Steamwheedle Port
    G("Steamwheedle Port", 67.1, 24.0, 44, "Quest hub on the north-east coast"),
    T("Stoley's Debt", "Stoley (only if you carry MacKinley's quest from Booty Bay)", 67.1, 24.0, 44),
    A("Stoley's Shipment", "Stoley", 67.1, 24.0, 44),
    A("Southsea Shakedown", "Security Chief Bilgewhizzle", 67.1, 23.9, 44),
    A("WANTED: Andre Firebeard", "Wanted Poster (Steamwheedle Port)", 66.8, 22.3, 44),
    A("Pirate Hats Ahoy!", "Haughty Modiste", 66.6, 22.3, 44),
    A("Screecher Spirits", "Yeh'kinya (objective is in Feralas)", 67.0, 22.4, 44),

    -- Lost Rigger Cove (south-east coast)
    D("Southsea Shakedown", "Kill 10 Southsea Pirates, 10 Freebooters, 10 Dock Workers and 10 Swashbucklers in Lost Rigger Cove", 72.2, 46.0, 44),
    D("Pirate Hats Ahoy!", "Loot 20 Southsea Pirate Hats from the pirates in Lost Rigger Cove", 72.2, 46.0, 44),
    A("Ship Schedules", "Ship Schedule (drops from the Southsea pirates in Lost Rigger Cove)", 72.2, 46.0, 45),
    D("Stoley's Shipment", "Loot Stoley's Shipment from the crates on the docks of Lost Rigger Cove", 72.1, 46.7, 45),
    D("WANTED: Andre Firebeard", "Kill Andre Firebeard at the pirate camp in Lost Rigger Cove and take his head", 73.4, 47.1, 45),

    -- Back to Steamwheedle Port
    T("Stoley's Shipment", "Stoley", 67.1, 24.0, 45),
    A("Deliver to MacKinley", "Stoley (turn in to MacKinley in Booty Bay later)", 67.1, 24.0, 45),
    T("Southsea Shakedown", "Security Chief Bilgewhizzle", 67.1, 23.9, 45),
    T("WANTED: Andre Firebeard", "Security Chief Bilgewhizzle", 67.1, 23.9, 45),
    T("Ship Schedules", "Security Chief Bilgewhizzle", 67.1, 23.9, 45),
    T("Pirate Hats Ahoy!", "Haughty Modiste", 66.6, 22.3, 45),

    -- Gadgetzan again, then the southern Wastewander camps (Noonshade Ruins)
    T("Wastewander Justice", "Chief Engineer Bilgewhizzle", 52.5, 28.5, 45),
    T("Water Pouch Bounty", "Spigot Operator Luglunket", 52.5, 28.4, 45),
    A("More Wastewander Justice", "Chief Engineer Bilgewhizzle", 52.5, 28.5, 45),
    D("More Wastewander Justice", "Kill 10 Wastewander Shadow Mages, 8 Rogues and 6 Assassins at the camps south-east of Gadgetzan", 58.9, 35.9, 45),
    D("WANTED: Caliph Scorpidsting", "Kill Caliph Scorpidsting (roams the Wastewander camps around Noonshade Ruins) and take his head", 61.8, 38.2, 46),
    T("More Wastewander Justice", "Chief Engineer Bilgewhizzle", 52.5, 28.5, 46),
    T("WANTED: Caliph Scorpidsting", "Chief Engineer Bilgewhizzle", 52.5, 28.5, 46),
    A("The Dunemaul Compound", "Andi Lynn", 52.8, 27.4, 46),
    A("Thistleshrub Valley", "Tran'rek", 51.6, 26.8, 46),
    A("The Thirsty Goblin", "Marin Noggenfogger", 51.8, 28.7, 46),

    -- Marvon's camp (Broken Pillar) and the south-west loop
    A("Gahz'ridian", "Marvon Rivetseeker", 52.7, 45.9, 46),
    D("Gahz'ridian", "Pick up Gahz'ridian Ornaments around Marvon's camp and all over the south of Tanaris (30 needed, keep collecting on the loop)", 53.0, 46.0, 46),
    D("Noxious Lair Investigation", "Kill Centipaar insects at the Noxious Lair for 5 Centipaar Insect Parts", 35.1, 48.4, 46),
    D("The Dunemaul Compound", "Kill 10 Dunemaul Brutes and 10 Dunemaul Enforcers in the Dunemaul Compound", 42.7, 53.1, 47),
    D("The Dunemaul Compound", "Kill Gor'marok the Ravager in the cave at the back of the Dunemaul Compound", 41.5, 57.8, 47),
    D("Thistleshrub Valley", "Kill 8 Gnarled Thistleshrubs and 8 Thistleshrub Rootshapers in Thistleshrub Valley", 29.3, 62.4, 47),
    D("The Thirsty Goblin", "Kill Thistleshrub Dew Collectors in Thistleshrub Valley for the Laden Dew Gland", 28.2, 62.9, 48),

    -- Tooga: long escort back across the desert to Steamwheedle Port
    A("Tooga's Quest", "Tooga (ESCORT, TIMED 30 min, slow; wanders south of Thistleshrub Valley near the crashed zeppelin)", 31.8, 74.2, 48),
    D("Tooga's Quest", "Escort Tooga (ESCORT, TIMED) across Tanaris to Torta south of Steamwheedle Port; stay on foot, he is slow", 31.8, 74.2, 48),
    T("Tooga's Quest", "Torta", 66.6, 25.7, 48),
    T("Screecher Spirits", "Yeh'kinya (only once you have the 3 screecher spirits from Feralas)", 67.0, 22.4, 48),

    -- Gadgetzan turn-ins and the Fizzledowser chain
    T("Noxious Lair Investigation", "Alchemist Pestlezugg", 50.9, 27.0, 48),
    T("The Dunemaul Compound", "Andi Lynn", 52.8, 27.4, 48),
    T("Thistleshrub Valley", "Tran'rek", 51.6, 26.8, 48),
    T("The Thirsty Goblin", "Marin Noggenfogger", 51.8, 28.7, 48),
    A("In Good Taste", "Marin Noggenfogger", 51.8, 28.7, 48),
    T("In Good Taste", "Sprinkle", 51.1, 26.9, 48),
    A("The Scrimshank Redemption", "Senior Surveyor Fizzledowser", 50.2, 27.5, 48),

    -- The Gaping Chasm (south-east), finish Gahz'ridian on the way
    D("The Scrimshank Redemption", "Enter the silithid hive in the Gaping Chasm and loot Scrimshank's Surveying Gear (north-west lobe of the big room; keep right from the north entrance)", 55.9, 71.2, 49),
    D("Gahz'ridian", "Finish the 30 Gahz'ridian Ornaments around the Gaping Chasm and the Valley of the Watchers", 48.0, 67.0, 49),
    T("Gahz'ridian", "Marvon Rivetseeker", 52.7, 45.9, 49),

    -- Gadgetzan: Scrimshank, the Insect Part Analysis shuttle, and the quests that leave the zone
    T("The Scrimshank Redemption", "Senior Surveyor Fizzledowser", 50.2, 27.5, 49),
    A("Insect Part Analysis", "Senior Surveyor Fizzledowser", 50.2, 27.5, 49, 1),
    T("Insect Part Analysis", "Alchemist Pestlezugg", 50.9, 27.0, 49, 1),
    A("Insect Part Analysis", "Alchemist Pestlezugg", 50.9, 27.0, 49, 2),
    T("Insect Part Analysis", "Senior Surveyor Fizzledowser", 50.2, 27.5, 49, 2),
    A("Rise of the Silithid", "Senior Surveyor Fizzledowser (turn in to Gracina Spiritmight in Darnassus)", 50.2, 27.5, 49),
    A("Handle With Care", "Curgle Cranklehop (turn in to Erelas Ambersky in Rut'theran Village, Teldrassil)", 52.4, 26.9, 50),
    A("Super Sticky", "Tran'rek (12 Super Sticky Tar from the tar-pit beasts in northern Un'Goro Crater)", 51.6, 26.8, 50),

    -- Optional: Marvon and the Sunken Temple chain (only if you accepted The Sunken Temple from Angelas Moonbreeze in Feralas)
    T("The Sunken Temple", "Marvon Rivetseeker (only if you carry it from Feralas)", 52.7, 45.9, 50),
    A("The Stone Circle", "Marvon Rivetseeker (objective is in Ratchet)", 52.7, 45.9, 50),
    G("Gadgetzan flight path", 51.0, 29.3, 50, "Leaving Tanaris: Deliver to MacKinley -> Booty Bay; Rise of the Silithid -> Darnassus; Handle With Care -> Rut'theran Village; Super Sticky -> Un'Goro tar pits; The Stone Circle -> loot it in Marvon's workshop in Ratchet and bring it back to Marvon"),
} }

-- Sources: https://wowhandbook.com/zones/kalimdor/feralas/ , https://wow4ever.quest/en/npcs (per-NPC pages, QuestieDB Forever data) , https://games.gg/world-of-warcraft/guides/wow-forever-feralas-leveling-guide/
-- Feralas (Alliance) for WoW: Forever.
-- Sources: https://wow4ever.quest/en/quests/<slug> and /en/npcs/<slug> (Questie Forever data: IDs, min levels, givers, coords, "First you need");
-- https://foreverchanges.pro/quests/feralas (81-quest Forever list, Changed/Elite tags; no quest tagged New);
-- https://www.wowhead.com/forever/quest=<id> (series boxes for 3130/2869/2870/2871, 2766/2767, 4281);
-- warcraft.wiki.gg only for mob/objective spots (Ruins of Isildien, Feral Scar Vale, Rage Scar Hold, Isle of Dread, Forgotten Coast dock).
-- Part numbers: "Against the Hatecrest" 1-2 = 3130, 2869 (both carry this title in Forever; 1 = Shandris' report to Latronicus, 2 = naga scales);
--               "The Missing Courier" 1-2 = 4124, 4125; "Doling Justice" 1-2 = 2970, 2972 (part 2 = ring to Tyrande, Darnassus, accepted only).
-- Left out: Morrowgrain chain (Jonespyre's Request 3788, The Mystery of Morrowgrain 3791, Morrowgrain to Feathermoon 3792: need Morrowgrain Research from Darnassus);
--   Feralas: A History 2940 / The Borrower 2941 / The Super Snapper FX 2944 (ELITE) / Return to Troyas 2943 / The Stave of Equinex 2879 / The Morrow Stone 2942
--   (whole chain runs through Teldrassil, Tanaris and the Hinterlands; only its first quest "In Search of Knowledge" is accepted here);
--   Find OOX-22/FE! 2766 / Rescue OOX-22/FE! 2767 (random Distress Beacon drop, ends in Booty Bay); Pristine Yeti Hide 7735 (random drop at Rage Scar Hold, see note);
--   The Videre Elixir 3909/4041 (Winterspring chain, 47+); Again With the Zapped Giants 7725 / Refuel for the Zapping 7726 (level 55); To the Top 3567 (not a Feralas quest);
--   A Short Incubation 3842, The Newest Member of the Family 3843, Food for Baby 4297, Becoming a Parent 4298 (Thousand Needles / Hinterlands legs of the orphan chain); all Horde quests.
-- Cross-zone: The Sunken Temple 3445 -> Marvon Rivetseeker, Tanaris (52.7, 45.9); Rise of the Silithid 4267 -> Gracina Spiritmight, Darnassus (41.8, 85.6);
--   Doling Justice part 2 (2972) -> Tyrande Whisperwind, Darnassus (39.1, 81.6); In Search of Knowledge 2939 -> Daryn Lightwind, Rut'theran Village, Teldrassil (55.4, 92.2);
--   An Orphan Looking For a Home 3841 -> Quentin, Thousand Needles (78.3, 74.7).
-- Feralas (Alliance) for WoW: Forever.
-- Sources: https://wow4ever.quest/en/quests/<slug> and /en/npcs/<slug> (Questie Forever data: IDs, min levels, givers, coords, "First you need");
-- https://foreverchanges.pro/quests/feralas (81-quest Forever list, Changed/Elite tags; no quest tagged New);
-- https://www.wowhead.com/forever/quest=<id> (series boxes for 3130/2869/2870/2871, 2766/2767, 4281);
-- warcraft.wiki.gg only for mob/objective spots (Ruins of Isildien, Feral Scar Vale, Rage Scar Hold, Isle of Dread, Forgotten Coast dock).
-- Part numbers: "Against the Hatecrest" 1-2 = 3130, 2869 (both carry this title in Forever; 1 = Shandris' report to Latronicus, 2 = naga scales);
--               "The Missing Courier" 1-2 = 4124, 4125; "Doling Justice" 1-2 = 2970, 2972 (part 2 = ring to Tyrande, Darnassus, accepted only).
-- Left out: Morrowgrain chain (Jonespyre's Request 3788, The Mystery of Morrowgrain 3791, Morrowgrain to Feathermoon 3792: need Morrowgrain Research from Darnassus);
--   Feralas: A History 2940 / The Borrower 2941 / The Super Snapper FX 2944 (ELITE) / Return to Troyas 2943 / The Stave of Equinex 2879 / The Morrow Stone 2942
--   (whole chain runs through Teldrassil, Tanaris and the Hinterlands; only its first quest "In Search of Knowledge" is accepted here);
--   Find OOX-22/FE! 2766 / Rescue OOX-22/FE! 2767 (random Distress Beacon drop, ends in Booty Bay); Pristine Yeti Hide 7735 (random drop at Rage Scar Hold, see note);
--   The Videre Elixir 3909/4041 (Winterspring chain, 47+); Again With the Zapped Giants 7725 / Refuel for the Zapping 7726 (level 55); To the Top 3567 (not a Feralas quest);
--   A Short Incubation 3842, The Newest Member of the Family 3843, Food for Baby 4297, Becoming a Parent 4298 (Thousand Needles / Hinterlands legs of the orphan chain); all Horde quests.
-- Cross-zone: The Sunken Temple 3445 -> Marvon Rivetseeker, Tanaris (52.7, 45.9); Rise of the Silithid 4267 -> Gracina Spiritmight, Darnassus (41.8, 85.6);
--   Doling Justice part 2 (2972) -> Tyrande Whisperwind, Darnassus (39.1, 81.6); In Search of Knowledge 2939 -> Daryn Lightwind, Rut'theran Village, Teldrassil (55.4, 92.2);
--   An Orphan Looking For a Home 3841 -> Quentin, Thousand Needles (78.3, 74.7).
local FERALAS = { zone = "Feralas", min = 42, max = 50, steps = {
    -- Feathermoon Stronghold (arrive by boat from Auberdine/Theramore or on foot from Desolace, then ferry)
    G("Feathermoon Stronghold flight path", 30.2, 43.3, 42, "Get the flight path; set your hearthstone at the inn"),
    A("The Ruins of Solarsal", "Shandris Feathermoon", 30.3, 46.2, 42),
    A("The Missing Courier", "Latronicus Moonspear", 30.4, 46.2, 42, 1),
    A("The High Wilderness", "Angelas Moonbreeze", 31.8, 45.6, 42),
    A("The Mark of Quality", "Pratt McGrubben", 30.6, 42.7, 42),
    T("The Missing Courier", "Ginro Hearthkindle", 31.9, 45.1, 42, 1),
    A("The Missing Courier", "Ginro Hearthkindle", 31.9, 45.1, 42, 2),

    -- Ruins of Solarsal (south-west of the stronghold, same island)
    D("The Ruins of Solarsal", "Walk into the Ruins of Solarsal and look over the naga presence there (Forever 'Changed' quest); the gazebo completes it", 26.3, 52.3, 42),
    T("The Ruins of Solarsal", "Solarsal Gazebo", 26.3, 52.3, 42),
    A("Return to Feathermoon Stronghold", "Solarsal Gazebo", 26.3, 52.3, 42),
    T("Return to Feathermoon Stronghold", "Shandris Feathermoon", 30.3, 46.2, 42),
    A("Against the Hatecrest", "Shandris Feathermoon", 30.3, 46.2, 42, 1),
    T("Against the Hatecrest", "Latronicus Moonspear", 30.4, 46.2, 42, 1),
    A("Against the Hatecrest", "Latronicus Moonspear", 30.4, 46.2, 42, 2),
    D("Against the Hatecrest", "Kill Hatecrest naga around the Ruins of Solarsal for 10 Hatecrest Naga Scales", 28.8, 50.8, 43, 2),
    T("Against the Hatecrest", "Latronicus Moonspear", 30.4, 46.2, 43, 2),
    A("Against Lord Shalzaru", "Latronicus Moonspear", 30.4, 46.2, 43),

    -- Ferry to the Forgotten Coast, the courier's boat
    G("Ferry to the Forgotten Coast dock", 43.0, 43.0, 43, "Take the Feathermoon ferry to the mainland dock, then follow the shore south"),
    T("The Missing Courier", "Wrecked Row Boat", 45.4, 65.0, 43, 2),
    A("Boat Wreckage", "Wrecked Row Boat", 45.4, 65.0, 43),
    G("Ferry back to Feathermoon Stronghold", 43.0, 43.0, 43, "Back to the dock and over to the island"),
    T("Boat Wreckage", "Ginro Hearthkindle", 31.9, 45.1, 43),
    A("The Knife Revealed", "Ginro Hearthkindle", 31.9, 45.1, 43),
    T("The Knife Revealed", "Quintis Jonespyre", 32.5, 43.8, 43),
    A("Psychometric Reading", "Quintis Jonespyre", 32.5, 43.8, 43),
    T("Psychometric Reading", "Ginro Hearthkindle", 31.9, 45.1, 43),
    A("The Woodpaw Gnolls", "Ginro Hearthkindle", 31.9, 45.1, 43),

    -- Mainland sweep: Isildien, Feral Scar Vale, Woodpaw camps
    G("Ferry to the Forgotten Coast, then east along the road", 43.0, 43.0, 44, "Head south-east to the Ruins of Isildien"),
    D("The High Wilderness", "Kill 8 Gordunni Warlocks, 8 Gordunni Brutes and 8 Gordunni Shamans in the Ruins of Isildien", 58.4, 66.6, 44),
    D("The Mark of Quality", "Kill Feral Scar Yetis in Feral Scar Vale for 10 Thick Yeti Hides", 56.0, 58.5, 45),
    D("The Woodpaw Gnolls", "Work through the Woodpaw gnoll camps east of Feral Scar to the courier's backpacks in the southern camp", 73.3, 56.3, 45),
    T("The Woodpaw Gnolls", "Large Leather Backpacks", 73.3, 56.3, 45),
    A("Thalanaar Delivery", "Large Leather Backpacks", 73.3, 56.3, 45),
    A("The Writhing Deep", "Large Leather Backpacks", 73.3, 56.3, 45),

    -- The Writhing Deep (south of the Woodpaw camps)
    D("The Writhing Deep", "Enter the Writhing Deep hive and find the Zukk'ash Pod holding Raschal", 72.1, 63.7, 46),
    T("The Writhing Deep", "Zukk'ash Pod", 72.1, 63.7, 46),
    A("Freed from the Hive", "Zukk'ash Pod", 72.1, 63.7, 46),
    D("Freed from the Hive", "Free Raschal from the Zukk'ash pod (open it; Zukk'ash Stingers and Wasps nearby)", 72.1, 63.7, 46),

    -- Grimtotem camp north of Camp Mojache (Horde town: stay on the north road)
    A("Freedom for All Creatures", "Kindal Moonweaver", 65.9, 45.6, 46),
    D("Freedom for All Creatures", "Follow Kindal into the Grimtotem camp and open the Sprite Darter pen; at least 6 Sprite Darters and Kindal must survive", 66.8, 46.2, 46),
    T("Freedom for All Creatures", "Kindal Moonweaver", 65.9, 45.6, 46),
    A("Doling Justice", "Jer'kai Moonweaver", 66.0, 45.6, 46, 1),
    D("Doling Justice", "Kill 12 Grimtotem Naturalists, 10 Grimtotem Raiders and 6 Grimtotem Shamans in the camp", 66.6, 46.2, 47, 1),
    T("Doling Justice", "Jer'kai Moonweaver", 66.0, 45.6, 47, 1),
    A("Doling Justice", "Jer'kai Moonweaver (ring to Tyrande, Darnassus)", 66.0, 45.6, 47, 2),
    A("An Orphan Looking For a Home", "Kindal Moonweaver (egg to Quentin, Thousand Needles)", 65.9, 45.6, 47),

    -- Thalanaar
    G("Thalanaar flight path", 89.4, 45.9, 47, "Get the flight path. Optional: Quentin for the orphan egg is in Thousand Needles (78.3, 74.7), then on to the Hinterlands"),
    T("Thalanaar Delivery", "Falfindel Waywarder", 89.6, 46.6, 47),

    -- Back at Feathermoon Stronghold
    G("Fly to Feathermoon Stronghold", 30.2, 43.3, 47),
    T("Freed from the Hive", "Ginro Hearthkindle", 31.9, 45.1, 47),
    A("A Hero's Welcome", "Ginro Hearthkindle", 31.9, 45.1, 47),
    T("A Hero's Welcome", "Shandris Feathermoon", 30.3, 46.2, 47),
    -- "Rise of the Silithid" (4267, Shandris -> Darnassus) left out: Tanaris has a different quest with the same title (162).
    T("The High Wilderness", "Angelas Moonbreeze", 31.8, 45.6, 47),
    A("The Sunken Temple", "Angelas Moonbreeze (find Marvon Rivetseeker, Tanaris)", 31.8, 45.6, 47),
    A("In Search of Knowledge", "Troyas Moonbreeze (talk to Daryn Lightwind, Rut'theran Village)", 31.8, 45.5, 47),
    T("The Mark of Quality", "Pratt McGrubben", 30.6, 42.7, 47),
    A("Improved Quality", "Pratt McGrubben", 30.6, 42.7, 47),

    -- Isle of Dread (swim south from the stronghold island)
    D("Against Lord Shalzaru", "Kill Lord Shalzaru (lvl 47) in his cave on the Isle of Dread and loot the Mysterious Relic", 28.5, 70.5, 47),
    T("Against Lord Shalzaru", "Latronicus Moonspear", 30.4, 46.2, 48),
    A("Delivering the Relic", "Latronicus Moonspear", 30.4, 46.2, 48),
    T("Delivering the Relic", "Vestia Moonspear", 30.1, 45.1, 48),

    -- Forgotten Coast: Zorbin's giants and elementals
    G("Ferry to the Forgotten Coast dock", 43.0, 43.0, 48, "Zorbin Fandazzle stands beside the mainland dock"),
    A("Zapped Giants", "Zorbin Fandazzle", 44.8, 43.4, 48),
    A("Fuel for the Zapping", "Zorbin Fandazzle", 44.8, 43.4, 48),
    D("Zapped Giants", "Zap giants with Zorbin's Ultra-Shrinker along the Forgotten Coast and loot 15 Miniaturization Residue", 44.3, 46.6, 48),
    D("Fuel for the Zapping", "Kill Sea Elementals and Sea Sprays along the Forgotten Coast for 10 Water Elemental Cores", 45.0, 46.3, 48),
    T("Zapped Giants", "Zorbin Fandazzle", 44.8, 43.4, 48),
    T("Fuel for the Zapping", "Zorbin Fandazzle", 44.8, 43.4, 48),

    -- Rage Scar Hold, then the Twin Colossals and Shay
    D("Improved Quality", "Kill Rage Scar Yetis in Rage Scar Hold (north-east of the dock, south of the Twin Colossals) for 10 Rage Scar Yeti Hides", 53.7, 31.9, 49),
    A("The Giant Guardian", "Rockbiter", 42.4, 22.0, 49),
    T("The Giant Guardian", "Shay Leafrunner", 38.2, 10.3, 49),
    A("Wandering Shay", "Shay Leafrunner (ESCORT)", 38.2, 10.3, 49),
    D("Wandering Shay", "Take Shay's Bell from the chest beside her and escort her south to Rockbiter, ringing the bell when she wanders (ESCORT)", 38.2, 10.3, 49),
    T("Wandering Shay", "Rockbiter", 42.4, 22.0, 49),

    -- Finish at Feathermoon Stronghold
    G("Fly to Feathermoon Stronghold", 30.2, 43.3, 50),
    T("Improved Quality", "Pratt McGrubben", 30.6, 42.7, 50),
    G("Feathermoon Stronghold", 30.2, 43.3, 50, "Leaving Feralas: The Sunken Temple -> Marvon Rivetseeker, Tanaris (52.7, 45.9); Rise of the Silithid and Doling Justice (ring) -> Darnassus; In Search of Knowledge -> Daryn Lightwind, Rut'theran Village"),
} }

-- Sources: https://wowhandbook.com/zones/eastern-kingdoms/the-hinterlands/ ; https://games.gg/world-of-warcraft/guides/wow-forever-hinterlands-leveling/ ; https://wowforever.wiki.fextralife.com/The+Hinterlands ; https://legacy-wow.com/?p=3515 ; https://legacy-wow.com/vanilla-1-60-alliance-leveling-guide/levels-47-48/ ; https://warcraft.wiki.gg/wiki/Hinterlands_quests ; https://warcraft.wiki.gg/wiki/Jintha%27Alor ; https://wow4ever.quest/en/npcs
-- The Hinterlands (Alliance) for WoW: Forever.
-- Sources: https://wow4ever.quest/en/quests/<slug> and /en/npcs/<slug> (Questie Forever data: ids, min levels, givers, coords, "First you need"/"Then comes");
-- https://foreverchanges.pro/quests/the-hinterlands (45-quest Forever list, Elite/Changed tags) and /quest/2994, /quest/2993, /quest/2881;
-- https://www.wowhead.com/forever/quest=485, =836, =2994 (series boxes, objectives); objective-area coordinates (cages, Skulk Rock, Altar of Zul,
-- Valorwind Lake, beach bottles, Gammerita, feathers, Jintha'Alor) are NOT on the Forever sources: taken from the previous route / Classic-era guides
-- (legacy-wow 47-48, games.gg Forever Hinterlands guide, warcraft.wiki.gg) and marked as unverified in hinterlands_notes.md.
-- Part numbers: "Cortello's Riddle" 1-3 = 624, 625, 626 (parts 1-2 happen in Swamp of Sorrows / Dustwallow Marsh; only part 3 is turned in here).
-- Forever "Changed": Saving Sharpbeak (level 53 -> 51, XP 7900 -> 7350). Forever "Elite": Return to the Hinterlands (speak-to only), Saving Sharpbeak. No "New" Alliance quests in this zone.
-- Left out: Troll Necklace Bounty 2881 (repeatable 390-XP follow-up of 2880); The Ancient Egg 4787 (Tanaris chain, Yeh'kinya; egg is looted at Jintha'Alor, see Saving Sharpbeak note);
-- all Horde Revantusk/Shadra quests; Into The Temple of Atal'Hakkar / Jammal'an (Sunken Temple dungeon, pick-up kept as optional).
-- Cross-zone: "To The Hinterlands" (Brohann Caskbelly, Stormwind) and "The Newest Member of the Family" (Quentin, Thousand Needles, timed egg) are only turned in here;
-- "Thadius Grimshade" ends in the Blasted Lands (66.9, 19.5) and the chain comes back via Nekrum's Medallion (Zul'Farrak) and The Divination (Blasted Lands) to "Return to the Hinterlands";
-- "Rhapsody's Kalimdor Kocktail" needs Tanaris/Feralas items; "Rhapsody's Tale" ends at Brohann Caskbelly in Stormwind; "Rescue OOX-09/HL!" ends at Oglethorpe Obnoticus in Booty Bay;
-- "Favored of Elune?", "Sprinkle's Secret Ingredient", "The Super Snapper FX", "Whiskey Slim's Lost Grog", "Cortello's Riddle" are D/T-only legs of other zones' quests.
local HINTERLANDS = { zone = "The Hinterlands", min = 43, max = 51, steps = {
    -- Aerie Peak (arrive from Arathi / the Wetlands flight)
    G("Aerie Peak flight path", 11.1, 46.1, 43, "Learn the flight path; Wildhammer Keep is up the ramp"),
    T("To The Hinterlands", "Falstad Wildhammer", 11.8, 46.8, 43),
    A("Gryphon Master Talonaxe", "Falstad Wildhammer", 11.8, 46.8, 43),
    T("Gryphon Master Talonaxe", "Gryphon Master Talonaxe (aviary cave above the flight path)", 9.8, 44.5, 43),
    A("Rhapsody Shindigger", "Gryphon Master Talonaxe", 9.8, 44.5, 43),
    A("Witherbark Cages", "Gryphon Master Talonaxe", 9.8, 44.5, 43),
    A("Troll Necklace Bounty", "Fraggar Thundermantle (inn)", 14.8, 44.6, 43),
    A("Skulk Rock Clean-up", "Fraggar Thundermantle (inn)", 14.8, 44.6, 43),
    G("Wildhammer Keep inn", 14.8, 44.6, 43, "Set your hearthstone here"),
    T("The Newest Member of the Family", "Agnar Beastamer (only if you carry the Sprite Darter egg from Thousand Needles/Feralas, TIMED 1h)", 14.2, 43.6, 43),
    A("Food for Baby", "Agnar Beastamer (needs The Newest Member of the Family done)", 14.2, 43.6, 43),

    -- Road east: Shindigger's Camp and the Witherbark villages
    D("Favored of Elune?", "Pick up Wildkin Feathers (ground objects, 15 total) in the owlbeast woods north of the road as you go east", 24.0, 46.0, 43),
    T("Rhapsody Shindigger", "Rhapsody Shindigger (Shindigger's Camp)", 26.9, 48.6, 44),
    A("Rhapsody's Kalimdor Kocktail", "Rhapsody Shindigger (3 Roc Gizzards - Tanaris, 3 Groddoc Livers + 3 Ironfur Livers - Feralas)", 26.9, 48.6, 44),
    D("Witherbark Cages", "Check the First and Second Witherbark Cage at Zun'watha (south-west village)", 23.3, 58.8, 44),
    D("Troll Necklace Bounty", "Kill Witherbark trolls at Zun'watha for Troll Tribal Necklaces (5 needed)", 23.3, 58.8, 44),
    D("Witherbark Cages", "Check the Third Witherbark Cage at Hiri'watha", 32.0, 57.3, 44),
    D("Troll Necklace Bounty", "Finish 5 Troll Tribal Necklaces on the Witherbark at Hiri'watha", 32.0, 57.3, 45),
    D("Favored of Elune?", "Finish 15 Wildkin Feathers (ground objects) in the owlbeast hills south of the road", 38.0, 60.0, 45),
    D("Sprinkle's Secret Ingredient", "Loot the Violet Tragan underwater in Valorwind Lake, just south of the road", 40.0, 60.0, 45),

    -- North-east: the river, Skulk Rock and OOX-09/HL
    D("Food for Baby", "Kill stealthed Silvermane Stalkers (5 Silvermane Stalker Flanks) in the woods along the road and river east of Agol'watha", 52.4, 56.8, 45),
    D("Skulk Rock Clean-up", "Kill 10 Green Sludges along the river west of Skulk Rock", 46.0, 42.0, 45),
    D("Skulk Rock Clean-up", "Kill 10 Jade Oozes at Skulk Rock", 56.0, 41.0, 46),
    A("Find OOX-09/HL!", "OOX-09/HL Distress Beacon (only if the beacon dropped from a Hinterlands troll; use the item at the robot)", 49.4, 37.7, 46),
    T("Find OOX-09/HL!", "Homing Robot OOX-09/HL (islet in the lake at the head of the river)", 49.4, 37.7, 46),
    A("Rescue OOX-09/HL!", "Homing Robot OOX-09/HL (ESCORT)", 49.4, 37.7, 46),
    D("Rescue OOX-09/HL!", "Escort OOX-09/HL east to the shoreline beyond Overlook Cliff (ESCORT; two ambushes of 3 trolls/owlbeasts, stealthed wolves); turn in later in Booty Bay", 78.0, 61.0, 46),

    -- East coast: Overlook Cliffs waterfall, Gammerita, the beach
    G("Overlook Cliffs waterfall", 81.0, 46.0, 46, "Dive into the pool below the waterfall"),
    T("Cortello's Riddle", "Cortello's Treasure (underwater chest; only if you carry part 3 from the Musty Scroll in Dustwallow Marsh)", 80.8, 46.8, 46, 3),
    D("The Super Snapper FX", "Use the Super Snapper FX on Gammerita, the turtle patrolling the shore south of the Overlook Cliffs toward Revantusk Village", 80.4, 58.2, 46),
    D("Whiskey Slim's Lost Grog", "Collect 12 Pupellyverbos Port bottles washed up along the southern beach; stay clear of Revantusk Village guards", 73.0, 92.0, 46),

    -- Hearth to Aerie Peak and turn in
    G("Hearth to Aerie Peak", 14.8, 44.6, 46, "Use your hearthstone"),
    T("Skulk Rock Clean-up", "Fraggar Thundermantle", 14.8, 44.6, 47),
    T("Troll Necklace Bounty", "Fraggar Thundermantle (extra necklaces: repeatable bounty, 390 XP each)", 14.8, 44.6, 47),
    T("Food for Baby", "Agnar Beastamer", 14.2, 43.6, 47),
    A("Becoming a Parent", "Agnar Beastamer", 14.2, 43.6, 47),
    T("Becoming a Parent", "Agnar Beastamer", 14.2, 43.6, 47),
    T("Witherbark Cages", "Gryphon Master Talonaxe", 9.8, 44.5, 47),
    A("The Altar of Zul", "Gryphon Master Talonaxe", 9.8, 44.5, 47),

    -- South: the Altar of Zul and the Atal'ai Exile
    D("The Altar of Zul", "Run to the top of the Altar of Zul (completes on arrival); avoid elite Morta'gya the Keeper", 48.9, 68.7, 47),
    A("Jammal'an the Prophet", "Atal'ai Exile (optional: Sunken Temple dungeon quest, level 53, turned in back here)", 33.8, 75.2, 47),
    G("Hearth to Aerie Peak", 14.8, 44.6, 47, "Use your hearthstone"),
    T("The Altar of Zul", "Gryphon Master Talonaxe", 9.8, 44.5, 47),
    A("Thadius Grimshade", "Gryphon Master Talonaxe (ends in the Blasted Lands)", 9.8, 44.5, 47),
    G("Aerie Peak flight path", 11.1, 46.1, 47, "Leave: Thadius Grimshade in the Blasted Lands (66.9, 19.5), then Nekrum's Medallion (Zul'Farrak) and The Divination; Rescue OOX-09/HL! ends at Oglethorpe in Booty Bay"),

    -- Return at 50 with "Return to the Hinterlands" from Thadius Grimshade
    T("Return to the Hinterlands", "Gryphon Master Talonaxe (Forever tags it ELITE; speak-to only)", 9.8, 44.5, 50),
    A("Saving Sharpbeak", "Gryphon Master Talonaxe (ELITE, group)", 9.8, 44.5, 50),
    T("Rhapsody's Kalimdor Kocktail", "Rhapsody Shindigger (only with the gizzards and livers from Tanaris/Feralas)", 26.9, 48.6, 50),
    A("Rhapsody's Tale", "Rhapsody Shindigger (ends at Brohann Caskbelly, Stormwind)", 26.9, 48.6, 50),
    D("Saving Sharpbeak", "ELITE, group: fight to the top of Jintha'Alor, kill Vile Priestess Hexx for Hexx's Key, then open Sharpbeak's Cage through the north exit of the pit (not the cave behind Hexx). The Ancient Egg (Tanaris) is looted here too", 59.5, 78.3, 50),
    T("Saving Sharpbeak", "Gryphon Master Talonaxe", 9.8, 44.5, 51),
    G("Aerie Peak flight path", 11.1, 46.1, 51, "Done here: Rhapsody's Tale to Brohann Caskbelly in Stormwind (leads to the Sunken Temple), Jammal'an the Prophet back to the Atal'ai Exile after the dungeon"),
} }

-- Sources: https://wowhandbook.com/zones/kalimdor/ungoro-crater/ ; https://wow4ever.quest/en/npcs (NPC pages: linken, j-d-collie, torwa-pathfinder, muigin, spraggle-frock, krakle, karna-remtravel) ; https://github.com/Ludovicus-Maior/WoW-Pro-Guides/tree/main/WoWPro_Leveling/Forever/Alliance (50_55_Alliance.lua, 55_60_Alliance.lua) ; https://warcraft.wiki.gg/wiki/It%27s_a_Secret_to_Everybody ; https://warcraft.wiki.gg/wiki/Linken%27s_Sword
-- Un'Goro Crater (Alliance) for WoW: Forever.
-- Sources: https://wow4ever.quest/en/quests/<slug> and /en/npcs/<slug> (Questie Forever data 1.60.1: IDs, min levels, givers, coords, "First you need");
-- https://foreverchanges.pro/quests/ungoro-crater (51-quest Forever list, Changed/Elite tags) and /quest/<id> (3883, 3881, 3962, 5150, 9063);
-- warcraft.wiki.gg (objective spots only: Crate of Foodstuffs 68.5,36.6; Research Equipment 38.5,66; Threshadon carcass; Slithering Scar hatchery 49,85;
-- Fire Plume hot spot 48.3,43.3; Blazerunner 49.2,49.0; Ornate Chest 50.2,50; Frenzied Pterrordax 21,39; Terror Run bones; Flat Un'Goro Rock 79.8,49.8). Forever "New": none in this zone.
-- Forever "Changed": Alien Ecology 3883 (5,100 XP instead of 3,050) and Expedition Salvation 3881 (5,250 XP instead of 4,200); Forever "Elite": It's Dangerous to Go Alone 3962.
-- Part numbers: "It's a Secret to Everybody" 1-3 = 3844, 3845, 3908 (part 3 turned in to Donova Snowden, Winterspring); "Chasing A-Me 01" 1-3 = 4243, 4244, 4245.
-- Left out: Haze of Evil 4143 + Bloodpetal Sprouts 4144 (Sunken Temple dungeon chain after A Visit to Gregan); Crystal Charge/Force/Restore/Spire/Ward/Yield 4381-4386 (pylon repeatables);
-- Torwa Pathfinder 9063 / Bloodpetal Poison 9052 / Toxic Test / A Better Ingredient 9053 (Druid class chain); Larion and Muigin 4145, Marvon's Workshop 4147, Bloodpetal Zapper 4148 (Horde);
-- Volcanic Activity 4502 (starts and ends at Liv Rizzlefix, Ratchet); The Videre Elixir 3909, Meet at the Grave 3912, A Grave Situation 3913 (Winterspring/Tanaris legs of the Linken chain).
-- Cross-zone: It's a Secret to Everybody 3 and The New Springs end at Donova Snowden (Winterspring); A Visit to Gregan ends at Gregan Brewspewer (Feralas 45.1,25.6);
-- Linken's Memory ends at Eridan Bluewind (Felwood 51.4,81.5); Linken's Sword (picked up at A Conspicuous Gravestone, Tanaris) and Aquementas (Felwood) are only turned in here.
local UNGORO = { zone = "Un'Goro Crater", min = 48, max = 56, steps = {
    -- South-east entrance (down the ramp from Tanaris)
    G("Torwa Pathfinder at the bottom of the Tanaris ramp", 71.6, 76.0, 48, "Loot every Power Crystal (red, blue, green, yellow) you pass; you need 7 of each later"),
    A("The Apes of Un'Goro", "Torwa Pathfinder", 71.6, 76.0, 48),
    A("The Fare of Lar'korwi", "Torwa Pathfinder", 71.6, 76.0, 48),
    A("It's a Secret to Everybody", "A Wrecked Raft (in the pond)", 63.0, 68.6, 48, 1),
    T("It's a Secret to Everybody", "A Small Pack", 63.1, 69.1, 48, 1),
    A("It's a Secret to Everybody", "A Small Pack", 63.1, 69.1, 48, 2),
    D("The Fare of Lar'korwi", "Loot a Piece of Threshadon Carcass from the Fresh Threshadon Carcass", 68.7, 56.7, 48),
    T("The Fare of Lar'korwi", "Torwa Pathfinder", 71.6, 76.0, 48),
    A("The Scent of Lar'korwi", "Torwa Pathfinder", 71.6, 76.0, 48),
    D("The Scent of Lar'korwi", "Walk up to the ravasaur nests west of Torwa; kill the Lar'korwi's Mates that spawn for 2 Ravasaur Pheromone Glands", 66.5, 74.0, 48),
    T("The Scent of Lar'korwi", "Torwa Pathfinder", 71.6, 76.0, 49),
    A("Williden's Journal", "A Mangled Journal (random drop from Un'Goro beasts, keep killing on the way)", 65.8, 71.1, 49),

    -- North along the east side to Marshal's Refuge
    G("Marshal's Refuge flight path (Gryfe)", 45.2, 5.8, 49, "Grab the flight path"),
    T("It's a Secret to Everybody", "Linken", 44.7, 8.1, 49, 2),
    A("It's a Secret to Everybody", "Linken (part 3 is turned in to Donova Snowden, Winterspring)", 44.7, 8.1, 49, 3),
    T("Williden's Journal", "Williden Marshal", 44.0, 7.1, 49),
    A("Expedition Salvation", "Williden Marshal", 44.0, 7.1, 49),
    A("Alien Ecology", "Hol'anyee Marshal", 43.9, 7.2, 49),
    A("Dadanga is Hungry!", "Dadanga (the kodo)", 43.6, 7.2, 49),
    A("Roll the Bones", "Spark Nilminer", 43.5, 7.4, 49),
    A("Beware of Pterrordax", "Beware of Pterrordax (sign)", 43.5, 8.4, 49),
    A("Muigin and Larion", "Muigin", 42.9, 9.6, 49),
    A("Shizzle's Flyer", "Shizzle", 44.2, 11.6, 49),
    A("Crystals of Power", "J.D. Collie (in the cave)", 41.9, 2.7, 49),
    A("Chasing A-Me 01", "Karna Remtravel", 46.4, 13.4, 49, 1),

    -- North-east loop: Northern Pylon crystals, Fungal Rock gorillas, A-Me 01
    D("Crystals of Power", "Loot 7 Red, 7 Blue, 7 Green and 7 Yellow Power Crystals (glowing crystals around the pylons and all over the crater)", 56.5, 12.5, 49),
    D("Dadanga is Hungry!", "Open the big green Bloodpetal Sprout plants for 15 Bloodpetal Sprouts", 58.0, 18.0, 49),
    D("The Apes of Un'Goro", "Kill gorillas in Fungal Rock for 2 Un'Goro Gorilla, 2 Un'Goro Stomper and 2 Un'Goro Thunderer Pelts", 64.5, 15.5, 50),
    T("Chasing A-Me 01", "A-Me 01 (by the pool outside Fungal Rock)", 67.7, 16.8, 50, 1),
    A("Chasing A-Me 01", "A-Me 01", 67.7, 16.8, 50, 2),
    D("Chasing A-Me 01", "Give A-Me 01 a Mithril Casing (Engineering-made; bring one from the Auction House)", 67.7, 16.8, 50, 2),
    T("Chasing A-Me 01", "A-Me 01", 67.7, 16.8, 50, 2),
    A("Chasing A-Me 01", "A-Me 01 (ESCORT)", 67.7, 16.8, 50, 3),
    D("Chasing A-Me 01", "Escort A-Me 01 west to Karna Remtravel at Marshal's Refuge (ESCORT)", 46.4, 13.4, 50, 3),
    T("Chasing A-Me 01", "Karna Remtravel", 46.4, 13.4, 51, 3),

    -- Marshal's Refuge, second visit
    T("Crystals of Power", "J.D. Collie", 41.9, 2.7, 51),
    A("The Northern Pylon", "J.D. Collie", 41.9, 2.7, 51),
    A("The Eastern Pylon", "J.D. Collie", 41.9, 2.7, 51),
    A("The Western Pylon", "J.D. Collie", 41.9, 2.7, 51),
    T("Dadanga is Hungry!", "Dadanga", 43.6, 7.2, 51),
    A("Lost!", "Spraggle Frock (gives Spraggle's Canteen)", 43.6, 8.5, 51),

    -- Big clockwise loop: north pylon, east side, Torwa, south, west
    D("The Northern Pylon", "Examine the Northern Crystal Pylon (if you carry Super Sticky from Tanaris, kill tar beasts in the Lakkari Tar Pits (north-central crater) for 12 Super Sticky Tar)", 56.5, 12.5, 51),
    D("Muigin and Larion", "Kill Bloodpetal Lashers, Flayers and Threshers along the east side for 15 Bloodpetals", 60.0, 30.0, 51),
    D("Expedition Salvation", "Loot the Crate of Foodstuffs on the east edge", 68.5, 36.6, 51),
    D("The Eastern Pylon", "Examine the Eastern Crystal Pylon", 77.2, 50.0, 52),
    T("The Apes of Un'Goro", "Torwa Pathfinder", 71.6, 76.0, 52),
    A("The Mighty U'cha", "Torwa Pathfinder", 71.6, 76.0, 52),
    A("The Bait for Lar'korwi", "Torwa Pathfinder (gives Torwa's Pouch)", 71.6, 76.0, 52),
    D("Shizzle's Flyer", "Kill Diemetradons in the Marshlands for 8 Webbed Diemetradon Scales", 57.2, 80.4, 52),
    D("Alien Ecology", "Enter the Slithering Scar (50,81) and use the Scraping Vial in the middle of a hatchery chamber with hanging larvae", 49.0, 85.0, 52),
    D("Roll the Bones", "Loot Dinosaur Bones on the ground around the threshadon corpse at the south end of Terror Run (stegodons and diemetradons drop them too) - 8 needed", 36.0, 72.0, 52),
    D("Expedition Salvation", "Loot the Research Equipment", 38.5, 66.0, 52),
    D("The Western Pylon", "Examine the Western Crystal Pylon", 23.9, 59.2, 52),
    A("Finding the Source", "Krakle (gives Krakle's Thermometer)", 30.9, 50.4, 52),
    D("Beware of Pterrordax", "Kill 15 Frenzied Pterrordax in the west and 10 Pterrordax in the Screaming Reaches (north-west)", 21.0, 39.0, 53),
    D("Shizzle's Flyer", "Kill Pterrordax in the Screaming Reaches for 8 Webbed Pterrordax Scales", 25.0, 32.0, 53),
    D("Finding the Source", "Use the Thermometer at the hot spots around Fire Plume Ridge; the hottest one is on the north side of the ridge", 48.3, 43.3, 53),
    T("Lost!", "Ringo", 51.9, 49.9, 53),
    A("A Little Help From My Friends", "Ringo (ESCORT)", 51.9, 49.9, 53),
    D("A Little Help From My Friends", "Escort Ringo north to Spraggle Frock; slap him when he is weak, use Spraggle's Canteen when he faints (ESCORT)", 43.6, 8.5, 53),

    -- Marshal's Refuge turn-ins
    T("A Little Help From My Friends", "Spraggle Frock", 43.6, 8.5, 54),
    T("Beware of Pterrordax", "Spraggle Frock", 43.6, 8.5, 54),
    T("Shizzle's Flyer", "Shizzle", 44.2, 11.6, 54),
    T("Muigin and Larion", "Muigin", 42.9, 9.6, 54),
    A("A Visit to Gregan", "Muigin (turn in to Gregan Brewspewer, Feralas 45.1,25.6)", 42.9, 9.6, 54),
    T("Expedition Salvation", "Williden Marshal", 44.0, 7.1, 54),
    T("Alien Ecology", "Hol'anyee Marshal", 43.9, 7.2, 54),
    T("Roll the Bones", "Spark Nilminer", 43.5, 7.4, 54),
    T("The Northern Pylon", "J.D. Collie", 41.9, 2.7, 54),
    T("The Eastern Pylon", "J.D. Collie", 41.9, 2.7, 54),
    T("The Western Pylon", "J.D. Collie", 41.9, 2.7, 54),
    A("Making Sense of It", "J.D. Collie", 41.9, 2.7, 54),
    T("Making Sense of It", "J.D. Collie (talk to him again after a moment)", 41.9, 2.7, 54),

    -- Final loop: U'cha, Lar'korwi, Torwa, Krakle
    D("The Mighty U'cha", "Kill U'cha (level 55) at the back of Fungal Rock and loot U'cha's Pelt", 68.0, 12.0, 55),
    D("The Bait for Lar'korwi", "At the Flat Un'Goro Rock behind the Eastern Pylon use the Preserved Threshadon Meat, then the Pheromone Mixture; kill Lar'korwi and loot his head", 79.8, 49.8, 55),
    T("The Bait for Lar'korwi", "Torwa Pathfinder", 71.6, 76.0, 56),
    T("The Mighty U'cha", "Torwa Pathfinder", 71.6, 76.0, 56),
    T("Finding the Source", "Krakle", 30.9, 50.4, 56),
    A("The New Springs", "Krakle (turn in to Donova Snowden, Winterspring 31.3,45.2)", 30.9, 50.4, 56),
    G("Marshal's Refuge flight path", 45.2, 5.8, 56, "Fly out: Winterspring for It's a Secret to Everybody 3 and The New Springs (Donova Snowden 31.3,45.2), Feralas for A Visit to Gregan (Gregan Brewspewer 45.1,25.6). Donova's The Videre Elixir -> Gregan (Feralas) -> Meet at the Grave (Gaeriyan, Tanaris 53.9,23.3) -> A Grave Situation -> Linken's Sword from A Conspicuous Gravestone (Tanaris 53.8,29.1); bring the sword back here"),

    -- Return trip, Linken's finale (Linken's Sword from the Tanaris gravestone; then Felwood for Silver Heart / Aquementas)
    T("Linken's Sword", "Linken (sword from A Conspicuous Gravestone, Tanaris)", 44.7, 8.1, 56),
    A("A Gnome's Assistance", "Linken", 44.7, 8.1, 56),
    T("A Gnome's Assistance", "J.D. Collie", 41.9, 2.7, 56),
    A("Linken's Memory", "J.D. Collie (turn in to Eridan Bluewind, Felwood 51.4,81.5)", 41.9, 2.7, 56),
    G("Marshal's Refuge flight path", 45.2, 5.8, 56, "Fly to Felwood (Talonbranch Glade): turn in Linken's Memory to Eridan Bluewind (51.4,81.5), do Silver Heart (11 Silvery Claws, Irontree Heart), accept Aquementas and fly back to Marshal's Refuge"),
    T("Aquementas", "J.D. Collie (from Eridan Bluewind, Felwood)", 41.9, 2.7, 56),
    A("Linken's Adventure", "J.D. Collie", 41.9, 2.7, 56),
    T("Linken's Adventure", "Linken", 44.7, 8.1, 56),
    A("It's Dangerous to Go Alone", "Linken (ELITE, group)", 44.7, 8.1, 56),
    D("It's Dangerous to Go Alone", "At the top of Fire Plume Ridge use the Silver Totem of Aquementas on Blazerunner, kill him (ELITE, group), then loot the Golden Flame from the Ornate Chest at the back of his cave (50.2,50.0)", 49.2, 49.0, 56),
    T("It's Dangerous to Go Alone", "Linken", 44.7, 8.1, 56),
} }

-- Sources: https://wowhandbook.com/zones/kalimdor/felwood/ ; https://wowforever.wiki.fextralife.com/Felwood ; https://wow4ever.quest/en/npcs (NPC pages: eridan-bluewind, greta-mosshoof, arathandris-silversky, grazle, nafien, jessir-moonbow, taronn-redfeather, kernda) ; https://github.com/Ludovicus-Maior/WoW-Pro-Guides/tree/main/WoWPro_Leveling/Forever/Alliance (50_55_Alliance.lua, 55_60_Alliance.lua)
-- Felwood (Alliance) for WoW: Forever.
-- Sources: https://wow4ever.quest/en/npcs/<npc> (grazle, nafien, eridan-bluewind, greta-mosshoof, arathandris-silversky, jessir-moonbow, taronn-redfeather, arei, captured-arkonarin)
-- and https://wow4ever.quest/en/quests/<slug> (Questie Forever data: IDs, min levels, givers, coords, "First you need");
-- https://foreverchanges.pro/quests/felwood (91-row Forever list, New/Changed/Elite tags) and /quest/<id> (6131, 4084, 8481, 8484);
-- https://www.wowhead.com/forever/quest=5158 (chain series); mob/object locations (Deadwood villages, Jadefire Glen/Run, Jaedenar
-- moonwell, Shatter Scar Vale, Shadow Hold braziers, Rakaiah, Fel'dan, Arei) from the Classic data of the previous route and
-- warcraft.wiki.gg (wow4ever has no pages for ordinary mobs/objects and no coords for Arei).
-- Part numbers: none (no repeated titles).
-- Forever "New": "Timbermaw Ally" 6131 exists as a second copy with no giver (orphan) -> only Grazle's 8460 is used.
-- Forever "Elite": "Verifying the Corruption" 5156. Forever "Changed": "Silver Heart" 4084 (level 54 instead of 55).
-- Left out: "Feathers for Grazle"/"Feathers for Nafien" (repeatable reputation turn-ins), "Deadwood Ritual Totem" (drop, needs
-- Timbermaw Neutral, Kernda inside the Hold), "Runecloth"/"Sacred Cloth" (Timbermaw cloth turn-ins), "Salve via ..." (repeatable
-- Cenarion turn-ins), "The Brokering of Peace"/"The Root of All Evil" (lvl 60, Timbermaw Exalted), "To Winterspring!" 5249
-- (Winterspring owns), Horde quests (Corrupted Sabers, Well of Corruption, Wild Guardians, A Husband's Last Battle, 4102 etc.),
-- Corrupted plant quests (object-started, repeatable salve use).
-- Cross-zone: "Linken's Memory" (Un'Goro, J.D. Collie) is turned in here; "Seeking Spiritual Aid" is turned in to Islen Waterseer
-- (The Barrens 65.8,43.8) who gives "Cleansed Water Returns to Felwood"; "Felbound Ancients" needs Blessed Water from the Temple of
-- the Moon in Darnassus; "Speak to Salfa" ends in Winterspring (Salfa 27.7,34.5); "Ancient Spirit" ends in Ashenvale (Kayneth
-- Stillwind 85.2,44.7); "Aquementas" ends in Un'Goro (J.D. Collie 41.9,2.7).
local FELWOOD = { zone = "Felwood", min = 48, max = 56, steps = {
    -- Emerald Sanctuary (enter from Ashenvale by the south road)
    G("Emerald Sanctuary", 51.2, 82.1, 48, "Alliance quest hub in southern Felwood; take the road north from Ashenvale"),
    A("Cleansing Felwood", "Arathandris Silversky", 54.1, 86.8, 48),
    A("Timbermaw Ally", "Grazle", 50.9, 85.0, 48),
    A("Forces of Jaedenar", "Greta Mosshoof", 51.2, 82.1, 48),
    A("Verifying the Corruption", "Taronn Redfeather (ELITE mobs, group)", 50.9, 81.6, 48),
    D("Timbermaw Ally", "Kill 6 Deadwood Warriors, 6 Pathfinders and 6 Gardeners at Deadwood Village (SW of the Sanctuary)", 48.1, 92.9, 48),
    T("Timbermaw Ally", "Grazle", 50.9, 85.0, 49),
    A("Speak to Nafien", "Grazle", 50.9, 85.0, 49),
    A("The Corruption of the Jadefire", "Eridan Bluewind", 51.4, 81.5, 49),

    -- Jadefire Glen and Jaedenar (west)
    D("The Corruption of the Jadefire", "Kill 11 Jadefire Felsworn, 9 Shadowstalkers, 9 Rogues and Xavathras in Jadefire Glen", 32.0, 67.0, 49),
    D("Forces of Jaedenar", "Kill 4 Jaedenar Hounds, 4 Guardsmen, 6 Adepts and 6 Cultists in Jaedenar", 35.0, 60.0, 50),
    T("Forces of Jaedenar", "Greta Mosshoof", 51.2, 82.1, 50),
    A("Collection of the Corrupt Water", "Greta Mosshoof (Empty Canteen)", 51.2, 82.1, 50),
    T("The Corruption of the Jadefire", "Eridan Bluewind", 51.4, 81.5, 50),
    A("Further Corruption", "Eridan Bluewind", 51.4, 81.5, 50),
    D("Collection of the Corrupt Water", "Fill the Empty Canteen at the corrupted Moon Well in the middle of Jaedenar", 35.2, 59.7, 51),
    D("Verifying the Corruption", "Kill 2 Entropic Beasts and 2 Entropic Horrors in Shatter Scar Vale (ELITE, group; avoid the Infernal Sentries)", 41.0, 42.0, 51),

    -- North: Talonbranch Glade, Timbermaw Hold, Irontree Woods, Jadefire Run
    G("Talonbranch Glade flight path", 62.5, 24.2, 51, "Get the flight path from Mishellena"),
    T("Speak to Nafien", "Nafien", 64.8, 8.1, 51),
    A("Deadwood of the North", "Nafien", 64.8, 8.1, 51),
    D("Deadwood of the North", "Kill 6 Deadwood Den Watchers, 6 Avengers and 6 Shamans at Felpaw Village", 63.7, 6.0, 52),
    T("Deadwood of the North", "Nafien", 64.8, 8.1, 52),
    A("Speak to Salfa", "Nafien (turn in to Salfa in Winterspring, through Timbermaw Hold)", 64.8, 8.1, 52),
    D("Cleansing Felwood", "Loot 15 Blood Amber from Warpwood treants and Irontree stompers/wanderers (Felpaw area and Irontree Woods)", 55.5, 16.8, 52),
    G("Jadefire Run", 43.0, 21.0, 52, "Satyr camp in the north-west"),
    D("Further Corruption", "Kill Xavaric at the back of Jadefire Run (drops the Flute of Xavaric)", 39.0, 22.0, 52),
    A("Flute of Xavaric", "Flute of Xavaric (item dropped by Xavaric)", 39.0, 22.0, 52),
    D("Flute of Xavaric", "Loot 5 Jadefire Felbind samples from the Jadefire satyrs of Jadefire Run", 39.3, 21.4, 53),
    D("Further Corruption", "Kill 8 Jadefire Hellcallers, 8 Betrayers and 8 Tricksters in Jadefire Run", 39.3, 21.4, 53),

    -- Back south to the Sanctuary (fly Talonbranch -> walk, or ride the road)
    T("Collection of the Corrupt Water", "Greta Mosshoof", 51.2, 82.1, 53),
    A("Seeking Spiritual Aid", "Greta Mosshoof (turn in to Islen Waterseer, The Barrens)", 51.2, 82.1, 53),
    T("Verifying the Corruption", "Taronn Redfeather", 50.9, 81.6, 53),
    T("Further Corruption", "Eridan Bluewind", 51.4, 81.5, 53),
    T("Flute of Xavaric", "Eridan Bluewind", 51.4, 81.5, 53),
    A("Felbound Ancients", "Eridan Bluewind (Eridan's Vial, fill it in Darnassus)", 51.4, 81.5, 53),
    T("Cleansing Felwood", "Arathandris Silversky", 54.1, 86.8, 53),
    T("Linken's Memory", "Eridan Bluewind", 51.4, 81.5, 53),
    A("Silver Heart", "Eridan Bluewind", 51.4, 81.5, 53),
    G("Emerald Sanctuary: trip to Darnassus and the Barrens", 51.2, 82.1, 53, "Fill Eridan's Vial with Blessed Water at the Temple of the Moon in Darnassus; then in the Barrens turn in Seeking Spiritual Aid to Islen Waterseer (65.8, 43.8, south of Ratchet) and accept Cleansed Water Returns to Felwood; come back here"),
    T("Felbound Ancients", "Eridan Bluewind", 51.4, 81.5, 54),
    A("Purified!", "Eridan Bluewind", 51.4, 81.5, 54),
    T("Purified!", "Eridan Bluewind", 51.4, 81.5, 54),
    T("Cleansed Water Returns to Felwood", "Greta Mosshoof", 51.2, 82.1, 54),
    A("Dousing the Flames of Protection", "Greta Mosshoof (Purified Moon Well Water)", 51.2, 82.1, 54),

    -- Shadow Hold (the cave under Jaedenar)
    G("Shadow Hold entrance, Jaedenar", 35.4, 58.6, 54, "Kill Jaedenar cultists and adepts until a Blood Red Key drops"),
    A("A Strange Red Key", "Blood Red Key (item dropped by Jaedenar cultists in Shadow Hold)", 35.4, 58.6, 54),
    D("Dousing the Flames of Protection", "Douse the Brazier of Pain with the Purified Moon Well Water", 36.3, 56.3, 54),
    D("Dousing the Flames of Protection", "Douse the Brazier of Hatred", 36.5, 55.2, 54),
    T("A Strange Red Key", "Captured Arko'narin", 36.2, 55.5, 54),
    A("Rescue From Jaedenar", "Captured Arko'narin (ESCORT)", 36.2, 55.5, 54),
    D("Rescue From Jaedenar", "Escort Arko'narin to her gear and out of Shadow Hold (ESCORT)", 35.4, 58.9, 54),
    D("Dousing the Flames of Protection", "Douse the Brazier of Suffering (deeper level)", 36.7, 53.3, 54),
    D("Dousing the Flames of Protection", "Douse the Brazier of Malice (deeper level)", 37.7, 52.7, 54),
    T("Dousing the Flames of Protection", "Greta Mosshoof", 51.2, 82.1, 55),
    A("A Final Blow", "Greta Mosshoof (group recommended)", 51.2, 82.1, 55),
    T("Rescue From Jaedenar", "Jessir Moonbow", 51.4, 82.0, 55),
    A("Retribution of the Light", "Jessir Moonbow", 51.4, 82.0, 55),
    D("Retribution of the Light", "Kill the succubus Rakaiah in the lower part of Shadow Hold", 38.4, 50.5, 55),
    T("Retribution of the Light", "Remains of Trey Lightforge (object, Shadow Hold)", 38.5, 50.4, 55),
    A("The Remains of Trey Lightforge", "Remains of Trey Lightforge (object, Shadow Hold)", 38.5, 50.4, 55),
    D("A Final Blow", "Kill Moora, Salia and Shadow Lord Fel'dan at the bottom of Shadow Hold for his head (ELITE, group)", 38.8, 46.9, 55),
    T("A Final Blow", "Greta Mosshoof", 51.2, 82.1, 56),
    T("The Remains of Trey Lightforge", "Jessir Moonbow", 51.4, 82.0, 56),

    -- Irontree Woods (north again), then Timbermaw Hold on to Winterspring
    D("Silver Heart", "Loot 11 Silvery Claws from Angerclaw bears (Maulers, Grizzlies) and Mongress in northern Felwood", 46.4, 23.4, 56),
    D("Silver Heart", "Loot the Irontree Heart from Irontree Stompers and Wanderers in Irontree Woods", 49.1, 28.9, 56),
    A("Ancient Spirit", "Arei (ESCORT; ends with Kayneth Stillwind in Ashenvale)", 49.0, 31.0, 56),
    D("Ancient Spirit", "Escort Arei through Irontree Woods until he is safe (ESCORT)", 49.4, 14.5, 56),
    T("Silver Heart", "Eridan Bluewind", 51.4, 81.5, 56),
    A("Aquementas", "Eridan Bluewind (turn in to J.D. Collie in Un'Goro Crater)", 51.4, 81.5, 56),
    G("Timbermaw Hold entrance (Nafien)", 64.8, 8.1, 56, "Go through Timbermaw Hold to Winterspring: turn in Speak to Salfa to Salfa (27.7, 34.5). Later: Ancient Spirit to Kayneth Stillwind at Forest Song, Ashenvale (85.2, 44.7); Aquementas to J.D. Collie in Un'Goro (41.9, 2.7)"),
} }

-- Sources: https://wowhandbook.com/zones/eastern-kingdoms/burning-steppes/ , https://games.gg/world-of-warcraft/guides/wow-forever-burning-steppes-leveling-guide/ , https://wowforever.wiki.fextralife.com/Burning+Steppes , https://www.warcrafttavern.com/wotlk/guides/alliance-leveling-53-54/ , https://warcraft.wiki.gg/wiki/Dragonkin_Menace
-- Burning Steppes (Alliance) for WoW: Forever.
-- Sources: https://wow4ever.quest/en/quests/<slug> and /en/npcs/<slug> (Questie Forever data: IDs, min levels, givers, coords, "First you need"/"Then comes":
-- oralius, helendis-riverhorn, marshal-maxwell, tinkee-steamboil, maxwort-uberglint, mathredis-firestar, cyrus-therepentous, franclorn-forgewright);
-- https://foreverchanges.pro/quests/burning-steppes (24-quest Forever list, Elite/Changed/Dungeon tags); https://www.wowhead.com/forever/quest=4182 (series box).
-- Objective coordinates: wow4ever has no pages for the mobs/objects of this zone (404), so they come from warcraft.wiki.gg (Tablet of the Seven 53,41;
-- Gor'tesh 39.7,52.8; Black Broodling 72.3,53.1; Blackrock Worg 38.2,57.6; Firegut ogres 80.3,46.0) and the current route (Dreadmaul Rock camps, Soft Dirt Mound).
-- Part numbers: "The True Masters" 1-6 = 4183, 4184, 4185, 4186, 4223, 4224 (this route accepts part 1 only; 2-4 are Lakeshire/Stormwind, 5-6 end here at Marshal Maxwell 84.7, 69.0).
-- Forever "New" quests: none in this zone (Librams and A Taste of Flame are "Changed"). "Dragonkin Menace" is tagged Elite in Forever.
-- Left out: Krom'Grul 3822, The Rise of the Machines 4061 (Horde); A Taste of Flame 4022/4023/4024 (needs the Searing Gorge "Trinkets" chain / Kalaran Windblade's molt, part 3 is BRD);
-- Libram of Rumination/Constitution/Tenacity/Resilience/Voracity 4463/4481/4482/4483/4484 (item + 30g turn-ins at Mathredis Firestar, no leveling value);
-- The True Masters parts 2-6 (Stormwind round trip; G note); Leonid Barthalomew 5522 (lvl 60 dungeon). Dungeon quests only as G notes: The Good Stuff 4286, The Heart of the Mountain 4123,
-- Dark Iron Legacy 3801/3802 (BRD), Put Her Down 4701 (Blackrock Spire, min 55), The Smoldering Ruins of Thaurissan 3701/3702 (accepted and turned in in Ironforge, relics are here).
-- Cross-zone: "Felnok Steelspring" 4808 (accepted here, turned in to Felnok Steelspring in Everlook, Winterspring 61.6, 38.6); "The True Masters" part 1 (turned in to Magistrate Solomon, Lakeshire, Redridge 24.9, 44.5).
local BURNING_STEPPES = { zone = "Burning Steppes", min = 50, max = 55, steps = {
    -- Morgan's Vigil (arrive from Lakeshire through Blackrock Pass)
    G("Morgan's Vigil flight path", 84.4, 68.3, 50, "Ride north from Lakeshire through Blackrock Pass; learn the flight path from Borgus Stoutarm"),
    A("Extinguish the Firegut", "Oralius", 84.6, 68.7, 50),
    A("FIFTY! YEP!", "Oralius", 84.6, 68.7, 50),
    A("Dragonkin Menace", "Helendis Riverhorn (ELITE in Forever)", 85.8, 69.0, 50),

    -- Dreadmaul Rock (north of the Vigil)
    D("Extinguish the Firegut", "Kill 7 Firegut Ogres on the south slope of Dreadmaul Rock", 83.8, 53.6, 50),
    D("Extinguish the Firegut", "Kill 15 Firegut Ogre-Mages around the ogre mounds", 83.5, 52.2, 51),
    D("Extinguish the Firegut", "Kill 7 Firegut Brutes higher up the rock", 82.4, 48.2, 51),
    T("Extinguish the Firegut", "Oralius", 84.6, 68.7, 52),
    A("Gor'tesh the Brute Lord", "Oralius", 84.6, 68.7, 52),

    -- Flame Crest (goblin hub, both factions; Horde flight point)
    G("Flame Crest", 65.6, 24.2, 52, "Ride north-west along the road; Alliance can use the goblin quest givers (the Horde flight master and guards are hostile-neutral)"),
    A("Broodling Essence", "Tinkee Steamboil (gives the Draco-Incarcinatrix 900)", 65.2, 24.0, 52),
    A("Tablet of the Seven", "Maxwort Uberglint", 65.2, 23.9, 52),

    -- Terror Wing Path and the Ruins of Thaurissan
    D("Broodling Essence", "Use the Draco-Incarcinatrix 900 on Black Broodlings before killing them, loot 8 Broodling Essence (Terror Wing Path)", 72.3, 53.1, 52),
    D("Dragonkin Menace", "Kill 15 Black Broodlings, 10 Black Dragonspawn, 4 Black Wyrmkin and 1 Black Drake in Terror Wing Path (ELITE, group; drakes patrol the valley)", 76.9, 62.1, 53),
    D("Tablet of the Seven", "Read the Tablet of the Seven below the dwarf statue in the Ruins of Thaurissan (Dark Iron camp) for the Tablet Transcript", 53.0, 41.0, 53),
    T("Tablet of the Seven", "Maxwort Uberglint", 65.2, 23.9, 53),
    T("Broodling Essence", "Tinkee Steamboil", 65.2, 24.0, 53),
    A("Felnok Steelspring", "Tinkee Steamboil (turn in to Felnok Steelspring, Everlook, Winterspring)", 65.2, 24.0, 53),
    G("Ruins of Thaurissan relics", 53.0, 41.0, 53, "If you took The Smoldering Ruins of Thaurissan (3701) from Royal Historian Archesonus in Ironforge, touch the Thaurissan Relics scattered around the ruins now"),

    -- Blackrock Stronghold and the Pillar of Ash (west)
    D("FIFTY! YEP!", "Kill Blackrock orcs and Blackrock Worgs around Blackrock Stronghold and the Pillar of Ash for 50 Blackrock Medallions", 39.3, 55.6, 54),
    D("Gor'tesh the Brute Lord", "Kill Gor'tesh (lvl 54) south of Blackrock Stronghold and take his Lopped Off Head", 39.7, 52.8, 54),
    D("FIFTY! YEP!", "Finish the 50 medallions on the Blackrock Worgs and orcs at the Pillar of Ash", 38.2, 57.6, 55),
    G("Blackrock Mountain", 29.0, 28.9, 55, "Optional dungeon quests: Dark Iron Legacy 3801/3802 from the ghost Franclorn Forgewright on the chain inside the mountain (BRD), The Good Stuff 4286 (Oralius, BRD), The Heart of the Mountain 4123 (Maxwort, BRD), Put Her Down 4701 (Helendis, Blackrock Spire, min 55)"),

    -- Back to Morgan's Vigil
    G("Morgan's Vigil", 84.6, 68.7, 55, "Long ride east along the road (or hearth)"),
    T("Gor'tesh the Brute Lord", "Oralius", 84.6, 68.7, 55),
    A("Ogre Head On A Stick = Party", "Oralius", 84.6, 68.7, 55),
    T("FIFTY! YEP!", "Oralius", 84.6, 68.7, 55),
    T("Dragonkin Menace", "Helendis Riverhorn", 85.8, 69.0, 55),
    A("The True Masters", "Helendis Riverhorn (letter for Magistrate Solomon, Lakeshire)", 85.8, 69.0, 55, 1),
    D("Ogre Head On A Stick = Party", "Climb Dreadmaul Rock and plant Gor'tesh's Lopped Off Head in the Soft Dirt Mound at the top", 81.0, 46.8, 55),
    T("Ogre Head On A Stick = Party", "Oralius", 84.6, 68.7, 55),
    G("Morgan's Vigil flight path", 84.4, 68.3, 55, "Turn in The True Masters to Magistrate Solomon in Lakeshire (parts 2-6 go Stormwind -> Lakeshire -> Marshal Maxwell here); turn in Felnok Steelspring to Felnok Steelspring in Everlook, Winterspring"),
} }

-- Sources: https://wowhandbook.com/zones/eastern-kingdoms/western-plaguelands/ https://games.gg/world-of-warcraft/guides/wow-forever-western-plaguelands-leveling-guide/ https://wowforever.wiki.fextralife.com/Western+Plaguelands https://wow4ever.quest/en/npcs https://warcraft.wiki.gg/wiki/Locked_Away
-- Western Plaguelands (Alliance) for WoW: Forever.
-- Sources: https://wow4ever.quest/en/quests/<slug> and /en/npcs/<slug> (Questie Forever data: IDs, min levels, givers, coords, "First you need"/"Then comes");
-- https://foreverchanges.pro/quests/western-plaguelands (zone list, Changed/Elite tags) and /quest/5223, /quest/5226, /quest/5538, /quest/6025;
-- https://www.wowhead.com/forever/quest=<id> (series boxes: 5903->5904->6389, 6004->6023->6025, 5021->5022, 5237 Alliance);
-- warcraft.wiki.gg quest pages for objective details (Annals book in Andorhal town hall, silos = blue towers, charm half from the Jabbering Ghoul).
-- Objective coordinates not given by any Forever source are kept from the previous route (see westernplaguelands_notes.md).
-- Part numbers: "Return to Chillwind Camp" 1-4 = 5217, 5220, 5223, 5226; "A Plague Upon Thee" 1-3 = 5903, 5904, 6389 (chain, not variants);
-- "Locked Away" 1-2 = 5059, 5060; "The Wildlife Suffers Too" 1-2 = 4984, 4985; "Unfinished Business" 1-3 = 6004, 6023, 6025;
-- "Better Late Than Never" 1-2 = 5021, 5022; "Argent Dawn Commission" 1 = 5401 (part 2 = 5503 is EPL's Duke quest).
-- Forever "New": none in this zone. Forever "Changed": Return to Chillwind Camp #3 (2800 xp) and #4 (renamed), Mold Rhymes With... (costs 15g). Elite: Unfinished Business #3.
-- Left out: paladin chain (Chillwind Point/Dispelling Evil/Inert Scourgestones/Forging the Mightstone); Good Luck Charm/Two Halves Become One (need the Stormwind leg);
-- repeatable Scourgestone and Cauldron reagent quests; Scholomance/60 quests (Barov Family Fortune, The Last Barov, Alas Andorhal, Araj's Scarab...); Horde variants.
-- Cross-zone: entry needs "A Call to Arms: The Plaguelands!" (5066/5090/5091) from the capital; Little Pamela and Brother Carlin end in EPL; Better Late Than Never #2 ends in
-- Stormwind; Glyphed Oaken Branch ends in Darnassus; Mold Rhymes With... ends in Tanaris; Auntie Marlene (EPL-owned) is turned in here after the Darrowshire trip.
local WESTERN_PLAGUELANDS = { zone = "Western Plaguelands", min = 51, max = 58, steps = {
    -- Chillwind Camp (arriving from the capital with A Call to Arms)
    G("Chillwind Camp flight path (Bibilfaz Featherwhistle)", 42.9, 85.1, 51, "Take 'A Call to Arms: The Plaguelands!' from your capital's Argent Dawn officer before coming: Crier Goodman (Stormwind 56.4,74.1), Courier Hammerfall (Ironforge 55.9,81.4) or Herald Moonstalker (Darnassus 47.8,82.0). Grab the flight path"),
    T("A Call to Arms: The Plaguelands!", "Commander Ashlam Valorfist", 42.7, 84.0, 51),
    A("Clear the Way", "Commander Ashlam Valorfist", 42.7, 84.0, 51),
    A("Argent Dawn Commission", "Argent Officer Pureheart", 43.0, 83.5, 51),
    T("Argent Dawn Commission", "Argent Officer Pureheart", 43.0, 83.5, 51),
    A("A Plague Upon Thee", "Nathaniel Dumah (termite mounds are in Eastern Plaguelands, fill the jar later)", 43.4, 84.8, 51, 1),

    -- Sorrow Hill
    A("Little Pamela", "Marlene Redpath (turn in to Pamela Redpath, Darrowshire, EPL)", 49.2, 78.6, 51),
    D("Clear the Way", "Kill 10 Skeletal Flayers and 10 Slavering Ghouls on Sorrow Hill", 49.4, 77.1, 51),
    T("Clear the Way", "Commander Ashlam Valorfist", 42.7, 84.0, 52),
    A("All Along the Watchtowers", "Commander Ashlam Valorfist", 42.7, 84.0, 52),
    A("The Scourge Cauldrons", "Commander Ashlam Valorfist", 42.7, 84.0, 52),
    T("The Scourge Cauldrons", "High Priestess MacDonnell", 43.0, 84.5, 52),
    A("Target: Felstone Field", "High Priestess MacDonnell", 43.0, 84.5, 52),

    -- Felstone Field
    A("Better Late Than Never", "Janice Felstone (ghost in the farmhouse)", 38.4, 54.0, 52, 1),
    T("Better Late Than Never", "Janice's Parcel (by the dead horse behind the barn)", 38.7, 55.2, 52, 1),
    A("Better Late Than Never", "Janice's Parcel (turn in to Royal Factor Bathrilor, Stormwind City Hall)", 38.7, 55.2, 52, 2),
    D("Target: Felstone Field", "Kill Cauldron Lord Bilemaw (53) for the Felstone Field Cauldron Key, then fill the Empty Felstone Field Bottle at the cauldron", 36.9, 57.4, 52),
    T("Target: Felstone Field", "Scourge Cauldron", 37.2, 56.8, 52),
    A("Return to Chillwind Camp", "Scourge Cauldron", 37.2, 56.8, 52, 1),

    -- Ruins of Andorhal (west side): Chromie and the towers
    D("All Along the Watchtowers", "Stand in the doorway of each of the four Andorhal watchtowers and use the Beacon Torch (towers at the town's corners; this is the north-west one)", 40.0, 71.6, 53),
    A("A Matter of Time", "Chromie (Andorhal inn)", 39.5, 66.8, 53),
    D("A Matter of Time", "Use the Temporal Displacer next to a blue-glowing silo at the edge of Andorhal and kill 10 Temporal Parasites", 45.1, 62.3, 53),
    T("A Matter of Time", "Chromie", 39.5, 66.8, 53),
    A("Counting Out Time", "Chromie", 39.5, 66.8, 53),
    D("Counting Out Time", "Open lockboxes in the rubble of Andorhal for 5 Andorhal Watches", 40.3, 66.5, 53),
    T("Counting Out Time", "Chromie", 39.5, 66.8, 53),

    -- Chillwind Camp
    T("Return to Chillwind Camp", "High Priestess MacDonnell", 43.0, 84.5, 53, 1),
    A("Target: Dalson's Tears", "High Priestess MacDonnell", 43.0, 84.5, 53),
    T("All Along the Watchtowers", "Commander Ashlam Valorfist", 42.7, 84.0, 53),

    -- Dalson's Tears
    A("Mrs. Dalson's Diary", "Mrs. Dalson's Diary (book in the farmhouse)", 47.8, 50.7, 54),
    T("Mrs. Dalson's Diary", "Outhouse (behind the farmhouse)", 48.1, 49.6, 54),
    A("Locked Away", "Outhouse", 48.1, 49.6, 54, 1),
    D("Locked Away", "Kill the Wandering Skeleton (Mrs. Dalson) around the farm for the Dalson Outhouse Key", 48.1, 49.6, 54, 1),
    T("Locked Away", "Outhouse (releases Farmer Dalson, a ghoul: kill him and keep the Cabinet Key)", 48.1, 49.6, 54, 1),
    A("Locked Away", "Locked Cabinet (in the farmhouse)", 47.4, 49.6, 54, 2),
    D("Locked Away", "Loot the Dalson Cabinet Key from Farmer Dalson (the ghoul from the outhouse)", 48.1, 49.6, 54, 2),
    T("Locked Away", "Locked Cabinet", 47.4, 49.6, 54, 2),
    D("Target: Dalson's Tears", "Kill Cauldron Lord Malvinious for the cauldron key and fill the Empty Dalson's Tears Bottle", 46.1, 52.6, 54),
    T("Target: Dalson's Tears", "Scourge Cauldron", 46.2, 51.9, 54),
    A("Return to Chillwind Camp", "Scourge Cauldron", 46.2, 51.9, 54, 2),

    -- The Writhing Haunt
    A("The Wildlife Suffers Too", "Mulgris Deepriver", 53.7, 64.7, 54, 1),
    D("The Wildlife Suffers Too", "Kill 8 Diseased Wolves in the fields around the Writhing Haunt", 51.1, 64.3, 54, 1),
    T("The Wildlife Suffers Too", "Mulgris Deepriver", 53.7, 64.7, 55, 1),
    A("The Wildlife Suffers Too", "Mulgris Deepriver", 53.7, 64.7, 55, 2),
    D("The Wildlife Suffers Too", "Kill 8 Diseased Grizzlies east and north of the Writhing Haunt", 55.2, 64.5, 55, 2),
    T("The Wildlife Suffers Too", "Mulgris Deepriver", 53.7, 64.7, 55, 2),
    A("Glyphed Oaken Branch", "Mulgris Deepriver (turn in to Mathrengyl Bearwalker, Darnassus)", 53.7, 64.7, 55),

    -- Chillwind Camp (level 55 pick-ups)
    T("Return to Chillwind Camp", "High Priestess MacDonnell", 43.0, 84.5, 55, 2),
    A("Target: Writhing Haunt", "High Priestess MacDonnell", 43.0, 84.5, 55),
    A("Scholomance", "Commander Ashlam Valorfist", 42.7, 84.0, 55),
    T("Scholomance", "Alchemist Arbington", 42.7, 83.8, 55),
    A("Skeletal Fragments", "Alchemist Arbington", 42.7, 83.8, 55),

    -- Andorhal east side, Writhing Haunt cauldron, then Darrowshire
    D("Skeletal Fragments", "Collect 15 Skeletal Fragments from skeletons in Andorhal", 44.5, 68.7, 55),
    D("Target: Writhing Haunt", "Kill Cauldron Lord Razarch for the cauldron key and fill the Empty Writhing Haunt Bottle", 52.9, 66.1, 55),
    T("Target: Writhing Haunt", "Scourge Cauldron", 53.0, 65.6, 55),
    A("Return to Chillwind Camp", "Scourge Cauldron", 53.0, 65.6, 55, 3),
    G("Thondroril River bridge, road to Eastern Plaguelands", 68.0, 73.0, 55, "Darrowshire (EPL 31,78): turn in Little Pamela to Pamela Redpath, do Pamela's Doll, take Uncle Carlin and Auntie Marlene. Fill the Empty Termite Jar (100 Plagueland Termites) at EPL termite mounds for A Plague Upon Thee, then come back"),

    -- Back in WPL: Marlene, Chromie's history quests
    T("Auntie Marlene", "Marlene Redpath", 49.2, 78.6, 56),
    A("A Strange Historian", "Marlene Redpath", 49.2, 78.6, 56),
    D("A Strange Historian", "Loot Joseph's Wedding Ring from Joseph Redpath's grave on Sorrow Hill", 49.7, 76.8, 56),
    T("A Strange Historian", "Chromie", 39.5, 66.8, 56),
    A("The Annals of Darrowshire", "Chromie", 39.5, 66.8, 56),
    D("The Annals of Darrowshire", "Find the Annals of Darrowshire in Andorhal's town hall (one-colour pages, faint X on the spine; the other books are trapped Musty Tomes)", 43.4, 68.8, 56),
    T("The Annals of Darrowshire", "Chromie", 39.5, 66.8, 56),
    A("Brother Carlin", "Chromie (turn in to Carlin Redpath, Light's Hope Chapel, EPL)", 39.5, 66.8, 56),

    -- Chillwind Camp
    T("Return to Chillwind Camp", "High Priestess MacDonnell", 43.0, 84.5, 56, 3),
    A("Target: Gahrron's Withering", "High Priestess MacDonnell", 43.0, 84.5, 56),
    T("Skeletal Fragments", "Alchemist Arbington", 42.7, 83.8, 56),
    A("Mold Rhymes With...", "Alchemist Arbington (bring 15g; turn in to Krinkle Goodsteel, Gadgetzan, Tanaris)", 42.7, 83.8, 56),
    T("A Plague Upon Thee", "Nathaniel Dumah", 43.4, 84.8, 56, 1),
    A("A Plague Upon Thee", "Nathaniel Dumah (barrel goes to Northridge Lumber Camp)", 43.4, 84.8, 56, 2),

    -- Gahrron's Withering
    D("Target: Gahrron's Withering", "Kill Cauldron Lord Soulwrath (58) for the cauldron key and fill the Empty Gahrron's Withering Bottle", 62.2, 59.1, 57),
    T("Target: Gahrron's Withering", "Scourge Cauldron", 62.5, 58.5, 57),
    A("Return to Chillwind Camp", "Scourge Cauldron", 62.5, 58.5, 57, 4),

    -- Northridge Lumber Camp and Hearthglen
    T("A Plague Upon Thee", "Termite Barrel (centre of Northridge Lumber Camp)", 48.3, 32.0, 57, 2),
    A("A Plague Upon Thee", "Termite Barrel", 48.3, 32.0, 57, 3),
    A("Unfinished Business", "Kirsta Deepshadow", 51.9, 28.1, 57, 1),
    D("Unfinished Business", "Kill 2 Scarlet Medics, 2 Scarlet Hunters, 2 Scarlet Magi and 2 Scarlet Knights at the Scarlet camp by the small bulwark south of Kirsta", 51.8, 44.8, 57, 1),
    T("Unfinished Business", "Kirsta Deepshadow", 51.9, 28.1, 57, 1),
    A("Unfinished Business", "Kirsta Deepshadow", 51.9, 28.1, 57, 2),
    D("Unfinished Business", "Kill Huntsman Radley (56) along Hearthglen Pass", 57.8, 36.1, 57, 2),
    D("Unfinished Business", "Kill Cavalier Durgen (57) along Hearthglen Pass", 55.2, 23.6, 57, 2),
    T("Unfinished Business", "Kirsta Deepshadow", 51.9, 28.1, 58, 2),
    A("Unfinished Business", "Kirsta Deepshadow", 51.9, 28.1, 58, 3),
    D("Unfinished Business", "ELITE, group: enter Hearthglen and climb to a high vantage point overlooking the town", 45.8, 18.3, 58, 3),
    T("Unfinished Business", "Kirsta Deepshadow", 51.9, 28.1, 58, 3),

    -- Chillwind Camp: wrap up
    T("Return to Chillwind Camp", "High Priestess MacDonnell", 43.0, 84.5, 58, 4),
    A("Mission Accomplished!", "Commander Ashlam Valorfist", 42.7, 84.0, 58),
    T("Mission Accomplished!", "Commander Ashlam Valorfist", 42.7, 84.0, 58),
    T("A Plague Upon Thee", "Nathaniel Dumah", 43.4, 84.8, 58, 3),
    G("Chillwind Camp flight path", 42.9, 85.1, 58, "Fly to Eastern Plaguelands carrying Brother Carlin (Carlin Redpath, Light's Hope). Later: Better Late Than Never to Stormwind, Glyphed Oaken Branch to Darnassus, Mold Rhymes With... to Tanaris. Optional Scholomance group quests from Weldon Barov and Alchemist Arbington here"),
} }

-- Sources: https://wowhandbook.com/zones/eastern-kingdoms/eastern-plaguelands/ https://wow4ever.quest/en/npcs https://games.gg/world-of-warcraft/guides/wow-forever-eastern-plaguelands/ https://wowforever.wiki.fextralife.com/Eastern+Plaguelands https://warcraft.wiki.gg/wiki/Redemption_(Classic)
-- Eastern Plaguelands (Alliance) for WoW: Forever.
-- Sources: https://wow4ever.quest/en/npcs/<npc> (tirion-fordring, caretaker-alen, betina-bigglezink, augustus-the-touched, carlin-redpath,
-- pamela-redpath, duke-nicholas-zverenhoff, marlene-redpath, chromie) and /en/quests/<slug> (Questie Forever data: IDs, min levels, givers, coords, "First you need");
-- https://foreverchanges.pro/quests/eastern-plaguelands (112-quest Forever list, Elite/Dungeon/Raid tags);
-- https://www.wowhead.com/forever/quest=<id> (series boxes, objective text); warcraft.wiki.gg for object/mob spots only
-- (Horgus' Skull 46,44; Shattered Sword of Marduk 49,59; Loose Dirt Mound 24.7,79.7; Symbol of Lost Honor 66,29; Augustus' Receipt Book 14.2,26.5).
-- Part numbers: "Argent Dawn Commission" part 2 = 5503 (part 1 = 5401 is WPL's; WPL owns the list).
-- New Forever quests: none in this route (Forever adds no new leveling quests to EPL; new content is level-60 Naxxramas/Argent Dawn writs).
-- Left out: Heroes of Darrowshire 5168 (ELITE, objectives in Hearthglen/Gahrron's Withering in WPL); Corruptor's/Invader's Scourgestones (elite/boss drops,
-- repeatable rep turn-ins); Fragments of the Past 5246/5247 + Tormented By the Past 5248 (Alliance Highborne chain: needs Winterspring's Troubled Spirits,
-- sends you to Azshara and back to Winterspring); That's Asking A Lot / When Smokey Sings (engineering mats, elite); Marauders of Darrowshire / Return to
-- Chromie / The Battle of Darrowshire / Hidden Treasures (level 60 raid-event chain); Hameya's Plea 6024 (level 60, starts from the Torn Scroll object: G note);
-- Plagued Hatchlings / Healthy Dragon Scale (Scholomance: G note); Lord Maxwell Tyrosus / The Argent Hold / Menethil's Gift / The Eastern Plagues (elite 60).
-- Cross-zone: "Auntie Marlene" is turned in to Marlene Redpath in Western Plaguelands (WPL route: A Strange Historian -> Annals -> Brother Carlin);
-- "Brother Carlin" and "Little Pamela" are accepted in WPL and turned in here; "Of Love and Family" ends at Artist Renfray in WPL (Caer Darrow).
local EASTERN_PLAGUELANDS = { zone = "Eastern Plaguelands", min = 55, max = 60, steps = {
    -- Darrowshire (arrive from Western Plaguelands with Little Pamela)
    G("Darrowshire", 31.1, 78.0, 55, "Cross the Thondroril River from WPL and follow the southern road to the ruined village"),
    T("Little Pamela", "Pamela Redpath", 31.1, 78.0, 55),
    A("Pamela's Doll", "Pamela Redpath", 31.1, 78.0, 55),
    D("Pamela's Doll", "Collect Pamela's Doll's Head, Left Side and Right Side from the ruined houses of Darrowshire (one piece per house)", 33.1, 79.5, 55),
    T("Pamela's Doll", "Pamela Redpath", 31.1, 78.0, 55),
    A("Uncle Carlin", "Pamela Redpath", 31.1, 78.0, 55),
    A("Auntie Marlene", "Pamela Redpath", 31.1, 78.0, 55),
    G("Road west to Western Plaguelands", 9.5, 66.0, 55, "Go back to Marlene Redpath (WPL 49.2, 78.6): turn in Auntie Marlene, then A Strange Historian, The Annals of Darrowshire and Brother Carlin with Chromie (WPL route). Come back with Brother Carlin and Uncle Carlin in the log."),

    -- Tirion Fordring at the Thondroril River, then Terrordale
    A("Demon Dogs", "Tirion Fordring", 5.2, 35.6, 56),
    A("Blood Tinged Skies", "Tirion Fordring", 5.2, 35.6, 56),
    A("Carrion Grubbage", "Tirion Fordring", 5.2, 35.6, 56),
    D("Demon Dogs", "Kill 20 Plaguehound Runts, 5 Plaguehounds and 5 Frenzied Plaguehounds along the river and the western Plaguewood edge", 6.4, 45.3, 56),
    A("Augustus' Receipt Book", "Augustus the Touched (Terrordale)", 11.4, 26.4, 56),
    D("Augustus' Receipt Book", "Loot Augustus' Receipt Book on the second floor of the Terrordale inn", 14.2, 26.5, 56),
    T("Augustus' Receipt Book", "Augustus the Touched", 11.4, 26.4, 56),

    -- Across the middle of the zone to Light's Hope Chapel
    D("Blood Tinged Skies", "Kill 30 Plaguebats in the central Plaguelands on the way east", 38.0, 55.0, 56),
    G("Light's Hope Chapel flight path", 71.7, 49.6, 56, "Alliance gryphon master Khaelyn Steelwing beside the chapel"),
    T("Uncle Carlin", "Carlin Redpath", 71.7, 50.0, 56),
    T("Brother Carlin", "Carlin Redpath", 71.7, 50.0, 56),
    A("Defenders of Darrowshire", "Carlin Redpath", 71.7, 50.0, 56),
    A("Villains of Darrowshire", "Carlin Redpath", 71.7, 50.0, 56),
    A("Zaeldarr the Outcast", "Caretaker Alen", 69.9, 53.7, 56),
    A("Argent Dawn Commission", "Duke Nicholas Zverenhoff", 71.6, 50.1, 56, 2),
    T("Argent Dawn Commission", "Duke Nicholas Zverenhoff", 71.6, 50.1, 56, 2),
    A("Minion's Scourgestones", "Duke Nicholas Zverenhoff (wear the Argent Dawn Commission trinket)", 71.6, 50.1, 56),

    -- Blackwood Lake, the Infectis Scar and Corin's Crossing
    D("Villains of Darrowshire", "Loot the Skull of Horgus from Horgus' Skull at the bottom of Blackwood Lake", 46.0, 44.0, 57),
    D("Villains of Darrowshire", "Loot the Shattered Sword of Marduk at the bottom of the Infectis Scar gorge west of Corin's Crossing", 49.0, 59.0, 57),
    D("Defenders of Darrowshire", "Kill Cannibal/Gibbering Ghouls and Diseased Flayers in Corin's Crossing to free 15 Darrowshire Spirits (talk to each spirit)", 52.5, 66.0, 57),
    D("Minion's Scourgestones", "Collect 20 Minion's Scourgestones from the Scourge of Corin's Crossing while wearing the Commission", 52.5, 66.0, 57),
    T("Villains of Darrowshire", "Carlin Redpath", 71.7, 50.0, 57),
    T("Defenders of Darrowshire", "Carlin Redpath", 71.7, 50.0, 57),
    T("Minion's Scourgestones", "Duke Nicholas Zverenhoff", 71.6, 50.1, 57),

    -- Back west: carrion worms, Tirion, the Undercroft
    D("Carrion Grubbage", "Kill Carrion Grubs and Carrion Devourers in the western and central Plaguelands for 15 Slabs of Carrion Worm Meat", 25.0, 60.0, 57),
    T("Demon Dogs", "Tirion Fordring", 5.2, 35.6, 57),
    T("Blood Tinged Skies", "Tirion Fordring", 5.2, 35.6, 57),
    T("Carrion Grubbage", "Tirion Fordring", 5.2, 35.6, 57),
    A("Redemption", "Tirion Fordring", 5.2, 35.6, 57),
    T("Redemption", "Tirion Fordring", 5.2, 35.6, 57),
    A("Of Forgotten Memories", "Tirion Fordring", 5.2, 35.6, 57),
    D("Of Forgotten Memories", "Search the Loose Dirt Mound at Tirion's false grave in the Undercroft; kill Mercutio Filthgorger and his Crypt Robbers for Taelan's Hammer", 24.7, 79.7, 58),
    D("Zaeldarr the Outcast", "Kill Zaeldarr the Outcast in the Undercroft for Zaeldarr's Head", 23.1, 72.6, 58),
    G("The Undercroft", 24.0, 78.0, 58, "Optional: the Torn Scroll object here starts Hameya's Plea (level 60): kill Infiltrator Hameya in Zul'Mashar, use his key on the Mound of Dirt behind the Undercroft"),
    T("Of Forgotten Memories", "Tirion Fordring", 5.2, 35.6, 58),
    A("Of Lost Honor", "Tirion Fordring", 5.2, 35.6, 58),

    -- Northdale, then Light's Hope Chapel
    D("Of Lost Honor", "Pick up the Symbol of Lost Honor from the ground in Northdale, north-east of the zone", 66.0, 29.0, 58),
    T("Zaeldarr the Outcast", "Caretaker Alen", 69.9, 53.7, 58),
    G("Light's Hope Chapel", 71.7, 49.9, 58, "Optional: Betina Bigglezink gives Plagued Hatchlings (Scholomance, group); Smokey LaRue (70.9, 48.4) has the engineering-materials quest That's Asking A Lot"),

    -- Tirion once more, then to Caer Darrow in Western Plaguelands
    T("Of Lost Honor", "Tirion Fordring", 5.2, 35.6, 59),
    A("Of Love and Family", "Tirion Fordring", 5.2, 35.6, 59),
    G("Road west to Western Plaguelands", 9.5, 66.0, 59, "Of Love and Family: search Caer Darrow (WPL island) for the painting, then turn in to Artist Renfray (WPL 65.8, 75.4)"),
    G("Stratholme (Plaguewood)", 26.1, 10.4, 60, "Group up for Stratholme and Scholomance at level 60"),
} }

-- Sources: https://wowhandbook.com/zones/kalimdor/winterspring/ ; https://wow4ever.quest/en/npcs (NPC + quest pages, QuestieDB Forever data) ; https://wowforever.wiki.fextralife.com/Winterspring ; https://warcraft.wiki.gg/wiki/Winterspring_quests
-- Winterspring (Alliance) for WoW: Forever.
-- Sources: https://wow4ever.quest/en/quests/<slug> and /en/npcs/<slug> (Questie Forever data: ids, min levels, givers, coords, "First you need");
-- https://foreverchanges.pro/quests/winterspring (58-quest Forever list, Elite/Changed tags; none marked New) and /quest/<id> (chains, objectives);
-- warcraft.wiki.gg (mob/objective locations only: Timbermaw Post, Winterfall Village, Lake Kel'Theril fragments, Darkwhisper Gorge, Owl Wing Thicket).
-- Part numbers: "Are We There, Yeti?" 1-3 = 3783, 977, 5163; "Enraged Wildkin" 1-4 = 6604, 4861, 4863, 4864.
-- Forever "Changed": Toxic Horrors (XP only). Elite: High Chief Winterfall.
-- Left out: Remorseful Highborne/The Crystal of Zin-Malor (need EPL's Tormented By the Past, done after Aurora Skycaller); Rivern Frostwind's repeatable
-- Wintersaber rep quests (Frostsaber Provisions, Winterfall Intrusion, Rampaging Giants); Luck Be With You/Cache of Mau'ari/E'ko quests (need Horde-only
-- A Little Luck in Forever); Storm Shadowhoof chain (Horde); A Yeti of Your Own, Lorax's Tale, Fiery Plate Gauntlets, Malyfous quests (profession/raid);
-- Winterfall Ritual Totem (random drop, turn-in inside Timbermaw Hold); Making Amends (repeatable); Meet at the Grave (follows the Feralas Videre leg).
-- Cross-zone: Speak to Salfa, The New Springs, It's a Secret to Everybody 3, To Winterspring!, Felnok Steelspring are accepted elsewhere and only turned in here;
-- Moontouched Wildkin / Find Ranshalla are Erelas Ambersky's (Rut'theran Village, Teldrassil); The Everlook Report ends at Chillwind Camp (WPL), Duke Nicholas
-- Zverenhoff and Sister Pamela end in EPL, Troubled Spirits of Kel'Theril ends at Aurora Skycaller (EPL), Return to Tinkee ends in Burning Steppes, Are We There, Yeti? 3 needs Sprinkle (Tanaris) and Quixxil (Un'Goro) scared before Umi takes it back,
-- The Videre Elixir continues with Gregan Brewspewer (Feralas), Falling to Corruption/Mystery Goo/Toxic Horrors/Words of the High Chief have their
-- objectives or turn-ins in Felwood (through Timbermaw Hold), Guardians of the Altar ends at Erelas Ambersky (Teldrassil).
local WINTERSPRING = { zone = "Winterspring", min = 55, max = 60, steps = {
    -- Arrival from Felwood through Timbermaw Hold: Salfa and Donova Snowden (first pass)
    G("Timbermaw Hold exit into Winterspring", 27.9, 34.5, 55, "Walk through Timbermaw Hold from Felwood; Salfa stands just outside the tunnel"),
    T("Speak to Salfa", "Salfa", 27.7, 34.5, 55),
    A("Winterfall Activity", "Salfa", 27.7, 34.5, 55),
    T("The New Springs", "Donova Snowden (Frostfire Hot Springs)", 31.3, 45.2, 55),
    T("It's a Secret to Everybody", "Donova Snowden", 31.3, 45.2, 55, 3),
    A("The Videre Elixir", "Donova Snowden (continues with Gregan Brewspewer, Feralas 45.1, 25.6)", 31.3, 45.2, 55),
    A("Strange Sources", "Donova Snowden", 31.3, 45.2, 55),

    -- Starfall Village and Lake Kel'Theril
    G("Starfall Village", 52.0, 30.4, 55, "Follow the road east past the hot springs"),
    T("To Winterspring!", "Wynd Nightchaser", 52.0, 30.4, 55),
    A("The Ruins of Kel'Theril", "Wynd Nightchaser", 52.0, 30.4, 55),
    T("The Ruins of Kel'Theril", "Jaron Stoneshaper", 52.1, 30.4, 55),
    A("Troubled Spirits of Kel'Theril", "Jaron Stoneshaper (keep Jaron's Pick)", 52.1, 30.4, 55),
    D("Moontouched Wildkin", "If you carry Erelas Ambersky's quest: 10 Moontouched Feathers from the owlbeasts around Starfall and Lake Kel'Theril", 49.5, 40.8, 56),
    D("Troubled Spirits of Kel'Theril", "Use Jaron's Pick on the First Relic Fragment in the ice of Lake Kel'Theril", 53.4, 42.0, 56),
    D("Troubled Spirits of Kel'Theril", "Second Relic Fragment", 55.6, 42.3, 56),
    D("Troubled Spirits of Kel'Theril", "Third Relic Fragment", 54.6, 44.2, 56),
    D("Troubled Spirits of Kel'Theril", "Fourth Relic Fragment (turn-in is Aurora Skycaller, Eastern Plaguelands 46.5, 16.0)", 56.4, 43.6, 56),

    -- Everlook
    G("Everlook flight master", 62.3, 36.6, 56, "Take the flight path and set your hearthstone at the inn"),
    A("The Everlook Report", "Gregor Greystone (ends at Chillwind Camp, WPL)", 61.4, 39.0, 56),
    A("Duke Nicholas Zverenhoff", "Gregor Greystone (ends at Light's Hope Chapel, EPL)", 61.4, 39.0, 56),
    T("Felnok Steelspring", "Felnok Steelspring", 61.6, 38.6, 56),
    A("Chillwind Horns", "Felnok Steelspring", 61.6, 38.6, 56),
    A("Are We There, Yeti?", "Umi Rumplesnicker", 60.9, 37.6, 56, 1),
    A("Enraged Wildkin", "Harlo Wigglesworth", 61.1, 38.4, 56, 1),
    A("Sister Pamela", "Jessica Redpath (ends at Pamela Redpath, Darrowshire, EPL)", 61.3, 39.0, 56),
    A("Trouble in Winterspring!", "Meggi Peppinrocker", 60.7, 38.2, 56),
    D("Chillwind Horns", "Kill Chillwind Chimaeras south of Everlook for 8 Uncracked Chillwind Horns", 61.2, 41.7, 56),
    D("Are We There, Yeti?", "Ice Thistle Hills east of Everlook: kill Ice Thistle Yetis for 10 Thick Yeti Fur", 65.3, 39.6, 56, 1),
    T("Chillwind Horns", "Felnok Steelspring", 61.6, 38.6, 57),
    A("Return to Tinkee", "Felnok Steelspring (ends at Tinkee Steamboil, Burning Steppes 65.2, 24.0)", 61.6, 38.6, 57),
    T("Are We There, Yeti?", "Umi Rumplesnicker", 60.9, 37.6, 57, 1),
    A("Are We There, Yeti?", "Umi Rumplesnicker", 60.9, 37.6, 57, 2),
    D("Are We There, Yeti?", "Kill Ice Thistle Matriarchs and Patriarchs in the yeti caves for 2 Pristine Yeti Horns", 64.7, 40.6, 57, 2),
    T("Are We There, Yeti?", "Umi Rumplesnicker", 60.9, 37.6, 57, 2),
    A("Are We There, Yeti?", "Umi Rumplesnicker", 60.9, 37.6, 57, 3),
    D("Are We There, Yeti?", "Use Umi's Mechanical Yeti on Legacki by the Everlook inn (Sprinkle in Gadgetzan, Tanaris and Quixxil in Marshal's Refuge, Un'Goro are the other two targets; turn-in at Umi after the zone)", 61.5, 38.6, 57, 3),

    -- Winterfall Village (north-east of Everlook)
    D("Winterfall Activity", "Winterfall Village: kill 8 Winterfall Shaman and 8 Winterfall Den Watchers (shamans heal, kill them first)", 67.1, 36.2, 57),
    D("Winterfall Activity", "Kill 8 Winterfall Ursa; loot Winterfall Spirit Beads (keep 5) and the Empty Firewater Flask", 66.7, 37.1, 57),
    A("Winterfall Firewater", "Empty Firewater Flask (drops from any Winterfall furbolg; right-click it to accept)", 66.9, 36.6, 57),

    -- Back west: Donova Snowden, Timbermaw Post, Salfa
    G("Donova Snowden at the Frostfire Hot Springs", 31.3, 45.2, 57, "Fly or ride back west along the road"),
    T("Trouble in Winterspring!", "Donova Snowden", 31.3, 45.2, 57),
    A("Threat of the Winterfall", "Donova Snowden", 31.3, 45.2, 57),
    T("Winterfall Firewater", "Donova Snowden", 31.3, 45.2, 57),
    A("Falling to Corruption", "Donova Snowden", 31.3, 45.2, 57),
    D("Threat of the Winterfall", "Timbermaw Post north of the hot springs: kill 8 Winterfall Pathfinders and 8 Winterfall Den Watchers", 29.5, 35.0, 57),
    D("Threat of the Winterfall", "Kill 8 Winterfall Totemics in the same camp", 30.6, 35.9, 58),
    T("Winterfall Activity", "Salfa", 27.7, 34.5, 58),
    A("Beads for Salfa", "Salfa (REPEATABLE)", 27.7, 34.5, 58),
    D("Beads for Salfa", "Hand in 5 Winterfall Spirit Beads (loot more from the Winterfall furbolgs at Timbermaw Post if needed)", 29.5, 35.0, 58),
    T("Beads for Salfa", "Salfa", 27.7, 34.5, 58),
    G("Through Timbermaw Hold to Felwood", 27.9, 34.5, 58, "Deadwood Cauldron in the Deadwood furbolg camp (Felwood 60.2, 5.8): turn in Falling to Corruption, take Mystery Goo"),
    T("Falling to Corruption", "Deadwood Cauldron (Felwood 60.2, 5.8, through Timbermaw Hold)", 27.9, 34.5, 58),
    A("Mystery Goo", "Deadwood Cauldron (Felwood 60.2, 5.8)", 27.9, 34.5, 58),
    T("Threat of the Winterfall", "Donova Snowden", 31.3, 45.2, 58),
    T("Mystery Goo", "Donova Snowden", 31.3, 45.2, 58),
    A("Toxic Horrors", "Donova Snowden", 31.3, 45.2, 58),
    G("Through Timbermaw Hold to Felwood", 27.9, 34.5, 58, "Kill Toxic Horrors (water elementals in Irontree Woods, Felwood ~50, 20) for 3 Toxic Horror Droplets, then come back"),
    T("Toxic Horrors", "Donova Snowden", 31.3, 45.2, 58),
    A("Winterfall Runners", "Donova Snowden", 31.3, 45.2, 58),
    D("Winterfall Runners", "Kill the Winterfall Runners on the road east of the Timbermaw Hold exit (they walk from Felwood to Winterfall Village) and loot the Winterfall Crate", 28.5, 34.4, 58),
    T("Winterfall Runners", "Donova Snowden", 31.3, 45.2, 58),
    A("High Chief Winterfall", "Donova Snowden (ELITE)", 31.3, 45.2, 58),

    -- Starfall Village, then the south: Owl Wing Thicket and Darkwhisper Gorge
    T("Enraged Wildkin", "Jaron Stoneshaper", 52.1, 30.4, 58, 1),
    A("Enraged Wildkin", "Jaron Stoneshaper", 52.1, 30.4, 58, 2),
    G("Everlook flight master", 62.3, 36.6, 59, "If you carry Moontouched Wildkin: fly to Rut'theran Village, turn it in to Erelas Ambersky, take Find Ranshalla, come back"),
    T("Enraged Wildkin", "Damaged Crate (Owl Wing Thicket)", 59.0, 59.8, 59, 2),
    A("Enraged Wildkin", "Damaged Crate", 59.0, 59.8, 59, 3),
    T("Enraged Wildkin", "Jaron's Wagon", 61.4, 60.7, 59, 3),
    A("Enraged Wildkin", "Jaron's Wagon", 61.4, 60.7, 59, 4),
    D("Enraged Wildkin", "Pick up Jaron's Supplies from the crates half-buried in the snow by the wagon", 61.4, 60.7, 59, 4),
    D("Enraged Wildkin", "Kill Berserk Owlbeasts in Owl Wing Thicket until the Blue-feathered Amulet drops", 59.4, 59.8, 59, 4),
    T("Find Ranshalla", "Ranshalla", 63.1, 59.5, 59),
    A("Guardians of the Altar", "Ranshalla (ESCORT; ends at Erelas Ambersky, Rut'theran Village)", 63.1, 59.5, 59),
    D("Guardians of the Altar", "Escort Ranshalla to the Altar of Elune and protect her while she lights the torches (ESCORT)", 63.1, 59.5, 59),
    D("Strange Sources", "Ride to the far south and discover Darkwhisper Gorge (level 60 elite demons inside; just reach the entrance)", 61.0, 77.0, 59),

    -- High Chief Winterfall, then the final Donova turn-ins
    D("High Chief Winterfall", "Winterfall Village, cave at the back: kill High Chief Winterfall (ELITE, group) and loot the Crudely-written Log", 67.9, 38.6, 59),
    A("The Final Piece", "Crudely-written Log (drops from High Chief Winterfall; right-click to accept)", 67.9, 38.6, 59),
    G("Donova Snowden at the Frostfire Hot Springs", 31.3, 45.2, 59, "Fly to Everlook if needed, then ride west"),
    T("Enraged Wildkin", "Jaron Stoneshaper (Starfall Village, on the way)", 52.1, 30.4, 60, 4),
    T("Strange Sources", "Donova Snowden", 31.3, 45.2, 60),
    T("High Chief Winterfall", "Donova Snowden", 31.3, 45.2, 60),
    T("The Final Piece", "Donova Snowden", 31.3, 45.2, 60),
    A("Words of the High Chief", "Donova Snowden (ends at Kelek Skykeeper, Felwood 51.1, 81.8)", 31.3, 45.2, 60),
    G("Through Timbermaw Hold to Felwood", 27.9, 34.5, 60, "Words of the High Chief: Kelek Skykeeper at Emerald Sanctuary (Felwood 51.1, 81.8). Then: Troubled Spirits to Aurora Skycaller and the Duke/Sister Pamela in EPL, The Everlook Report to Chillwind Camp (WPL), Return to Tinkee in Burning Steppes, Guardians of the Altar to Erelas Ambersky (Rut'theran), The Videre Elixir with Gregan Brewspewer (Feralas), Are We There, Yeti? 3: scare Sprinkle (Gadgetzan) and Quixxil (Marshal's Refuge), then back to Umi Rumplesnicker in Everlook"),
} }

-- Sources: https://wowhandbook.com/zones/kalimdor/silithus/ ; https://wow4ever.quest/en/npcs (NPC + quest pages, QuestieDB Forever data) ; https://wowforever.wiki.fextralife.com/Silithus ; https://games.gg/world-of-warcraft/guides/traces-of-silithyst-in-wow-forever/ ; https://warcraft.wiki.gg/wiki/Silithus_quests
-- Silithus (Alliance) for WoW: Forever.
-- Sources: https://wow4ever.quest/en/quests/<slug> and /en/npcs/<slug> (Questie Forever data: givers, coords, min levels, "First you need"; its index stops at quest level 59, so
-- every level-60 quest below comes from https://foreverchanges.pro/quest/<id>, which lists the same giver coords); https://foreverchanges.pro/quests/silithus (119-quest Forever list,
-- Elite/Changed/PvP tags); https://www.wowhead.com/forever/quest=<id> (chain series: 8284 -> 8285 -> 8279 -> 8287; 9415 -> 9419);
-- objective areas (mobs, camps, Noggle's Satchel 44.6,91.3) from warcraft.wiki.gg subzone/quest pages because the Forever sources list no mob coordinates.
-- Level-60 quests (wow4ever's quest index holds no level-60 quests at all, so they are also missing from its NPC pages): The Twilight Lexicon 8279 and
-- A Terrible Purpose 8287 are given by Hermit Ortell 67.2,69.8 per foreverchanges.pro/quest/8279 and /8287 (min level 54, unchanged), chain 8284->8285->8279->8287 per wowhead.
-- Part numbers: none (no repeated titles).
-- Forever "Changed": "Report to Marshal Bluewall" and "Scouring the Desert" (min level 1 instead of 53/55; Scouring is the Silithyst PvP objective, it flags you for PvP).
-- Forever "Elite": "Wanted - Deathclasp, Terror of the Sands" (level 59 elite scorpid in the southern mountains, same cave as Noggle's Satchel).
-- Left out: Taking Back Silithus 8275 (accepted in Ironforge, only turned in to Proudhorn; not a prerequisite of Securing the Supply Lines); Kitchen Assistance 8317 (Cooking 285);
-- Encrypted Twilight Texts 8319 (repeatable reputation quest); every level-60 Cenarion Circle / AQ-gate quest (Dearest Natalia, Glyph Chasing, Breaking the Code, Twilight Battle Orders,
-- Dukes/Lords of the Council, Field Duty, Target: Hive..., Scout Reports, Templar summons, Abyssal..., Armaments of War, Battlegear, What Tomorrow Brings/Anachronos, Secrets of the Colossus,
-- Bang a Gong!, A Humble Offering, Brann Bronzebeard's Lost Letter): elite, raid, rep-gated or world-event; see the optional G notes.
-- Cross-zone: "Wasteland" 1124 is accepted from Rabine Saturna in Moonglade (turn-in only here); "Umber, Archivist" 6844 is accepted here and turned in to Umber in Nighthaven, Moonglade (G note at the end).
local SILITHUS = { zone = "Silithus", min = 55, max = 60, steps = {
    -- Cenarion Hold (arrive by flight or through Un'Goro's western exit)
    G("Cenarion Hold flight path", 50.7, 34.6, 55, "Grab the flight path at the north gate of Cenarion Hold"),
    A("Report to Marshal Bluewall", "Rifleman Torrig (north gate)", 50.7, 34.7, 55),
    A("Securing the Supply Lines", "Windcaller Proudhorn", 51.1, 38.3, 55),
    A("Deadly Desert Venom", "Beetix Ficklespragg", 51.6, 38.6, 55),
    A("Desert Recipe", "Calandrath (inn)", 51.9, 39.2, 55),
    A("The Twilight Mystery", "Geologist Larksbane", 49.7, 37.5, 55),

    -- North and north-east of the hold, then east to Valor's Rest
    D("Securing the Supply Lines", "Kill 15 Dredge Strikers on the sands north of Cenarion Hold", 51.4, 30.0, 55),
    D("Deadly Desert Venom", "Kill Stonelash Scorpids (8 Stonelash Scorpid Stingers) and Sand Skitterers (8 Sand Skitterer Fangs) in the north-east", 58.0, 28.0, 55),
    D("Deadly Desert Venom", "Finish the Sand Skitterer Fangs between here and Valor's Rest", 66.0, 22.0, 56),
    T("Wasteland", "Layo Starstrike (Valor's Rest graveyard; quest from Rabine Saturna, Moonglade)", 81.9, 18.9, 56),
    A("The Spirits of Southwind", "Layo Starstrike", 81.9, 18.9, 56),
    D("The Spirits of Southwind", "Southwind Village: kill 8 Tortured Druids and 8 Tortured Sentinels in the ruins south-west of Valor's Rest", 65.0, 47.0, 56),
    D("The Spirits of Southwind", "Finish the Tortured Druids and Sentinels in the rest of Southwind Village", 62.0, 50.0, 56),
    T("The Spirits of Southwind", "Layo Starstrike", 81.9, 18.9, 56),
    A("Hive in the Tower", "Layo Starstrike", 81.9, 18.9, 56),
    D("Hive in the Tower", "Southwind Village tower with the wasps circling it: kill the 3 Hive'Ashi Drones at the entrance, open the Hive'Ashi Pod at the base and kill the 2 Hive'Ashi Ambushers it spawns for the Encrusted Silithid Object (the pod at the top only holds Silithid Goo)", 60.2, 52.4, 57),
    T("Hive in the Tower", "Layo Starstrike", 81.9, 18.9, 57),
    A("Umber, Archivist", "Layo Starstrike (turn in to Umber, Nighthaven, Moonglade)", 81.9, 18.9, 57),

    -- Back to Cenarion Hold
    G("Back to Cenarion Hold", 50.7, 34.6, 57, "Ride back west along the road"),
    T("Securing the Supply Lines", "Windcaller Proudhorn", 51.1, 38.3, 57),
    A("Stepping Up Security", "Windcaller Proudhorn", 51.1, 38.3, 57),
    T("Deadly Desert Venom", "Beetix Ficklespragg", 51.6, 38.6, 57),
    A("Noggle's Last Hope", "Beetix Ficklespragg", 51.6, 38.6, 57),
    A("Secret Communication", "Bor Wildmane", 48.6, 37.8, 57),

    -- The north-west: Crystal Vale, Twilight Base Camp, Hive'Zora camp
    D("The Twilight Mystery", "Crystal Vale / Ravaged Twilight Camp in the north-west: pick up 8 glowing blue Twilight Tablet Fragments from the ground (Whirling Invader elementals roam here)", 30.0, 13.0, 57),
    D("Secret Communication", "Twilight Base Camp west of the hold: kill Twilight Avengers, Geolords and Stonecallers for 10 Encrypted Twilight Texts (about 25% drop)", 42.0, 41.0, 57),
    T("Desert Recipe", "Sandy Cookbook (sandy book on a crate at the south edge of Twilight Base Camp)", 37.9, 45.3, 57),
    A("Sharing the Knowledge", "Sandy Cookbook", 37.9, 45.3, 57),
    D("Stepping Up Security", "Kill 20 Dredge Crushers on the sands between Twilight Base Camp and the Alliance camp", 40.0, 50.0, 57),
    T("Report to Marshal Bluewall", "Marshal Bluewall (Alliance camp near Hive'Zora)", 33.3, 51.1, 58),
    A("Scouring the Desert", "Marshal Bluewall (PvP: carrying Silithyst flags you)", 33.3, 51.1, 58),
    D("Scouring the Desert", "Pick up Silithyst at a red geyser or mound near Hive'Zora (not mounted) and carry it to the Alliance Silithyst Extractor at the camp; skip this step if you do not want the PvP flag", 33.3, 51.1, 58),
    T("Scouring the Desert", "Marshal Bluewall", 33.3, 51.1, 58),

    -- The south, then back to the hold
    D("Noggle's Last Hope", "South of the hold: Stonelash Pincers for 3 Stonelash Pincer Stingers", 45.0, 62.0, 58),
    D("Noggle's Last Hope", "Further south, west of Hive'Regal: Stonelash Flayers (3 Stonelash Flayer Stingers) and Rock Stalkers (3 Rock Stalker Fangs)", 49.0, 67.0, 58),
    G("Back to Cenarion Hold", 50.7, 34.6, 58, "Ride north back to the hold"),
    T("The Twilight Mystery", "Geologist Larksbane", 49.7, 37.5, 58),
    A("The Deserter", "Geologist Larksbane", 49.7, 37.5, 58),
    T("Secret Communication", "Bor Wildmane", 48.6, 37.8, 58),
    T("Sharing the Knowledge", "Calandrath (inn)", 51.9, 39.2, 58),
    T("Stepping Up Security", "Windcaller Proudhorn", 51.1, 38.3, 58),
    T("Noggle's Last Hope", "Beetix Ficklespragg", 51.6, 38.6, 58),
    A("Noggle's Lost Satchel", "Noggle Ficklespragg", 51.6, 38.5, 58),
    A("Wanted - Deathclasp, Terror of the Sands", "Wanted Poster: Deathclasp (ELITE, group)", 51.4, 38.3, 58),

    -- Southern mountains and Ortell's Hideout
    D("Noggle's Lost Satchel", "Cave in the southern mountains behind Bronzebeard Encampment: pick up Noggle's Satchel (guarded by Deathclasp)", 44.6, 91.3, 59),
    D("Wanted - Deathclasp, Terror of the Sands", "Kill Deathclasp (level 59 ELITE scorpid, group) in the same cave for Deathclasp's Pincer", 44.6, 91.0, 59),
    T("The Deserter", "Hermit Ortell (cave at Ortell's Hideout, south-east)", 67.2, 69.8, 59),
    A("The Twilight Lexicon", "Hermit Ortell", 67.2, 69.8, 59),

    -- The three Twilight camps (chapters + 20 more Encrypted Twilight Texts)
    D("The Twilight Lexicon", "Twilight Outpost (far south-west, north-west of the Scarab Wall): kill Twilight Keeper Exeter for Twilight Lexicon - Chapter 2", 16.1, 86.4, 59),
    D("The Twilight Lexicon", "Twilight Post (north-west, west of the wind stones): kill Twilight Keeper Mayna for Twilight Lexicon - Chapter 1", 26.4, 36.6, 59),
    D("The Twilight Lexicon", "Twilight Base Camp: kill Twilight Keeper Havunth for Twilight Lexicon - Chapter 3", 40.9, 42.2, 59),
    G("Twilight Base Camp", 42.0, 41.0, 59, "Farm 20 Encrypted Twilight Texts from the cultists here before going back to Ortell (True Believers and Still Believing need 10 each)"),
    T("The Twilight Lexicon", "Hermit Ortell", 67.2, 69.8, 59),
    A("True Believers", "Hermit Ortell", 67.2, 69.8, 59),
    D("True Believers", "Hand in 10 Encrypted Twilight Texts (farm more at the Twilight camps in the west if short)", 67.2, 69.8, 59),
    T("True Believers", "Hermit Ortell", 67.2, 69.8, 59),
    A("Still Believing", "Hermit Ortell", 67.2, 69.8, 59),
    D("Still Believing", "Hand in 10 more Encrypted Twilight Texts", 67.2, 69.8, 59),
    T("Still Believing", "Hermit Ortell", 67.2, 69.8, 60),
    A("A Terrible Purpose", "Hermit Ortell", 67.2, 69.8, 60),

    -- Cenarion Hold at 60
    G("Back to Cenarion Hold", 50.7, 34.6, 60, "Ride north-west back to the hold"),
    T("Noggle's Lost Satchel", "Noggle Ficklespragg", 51.6, 38.5, 60),
    T("Wanted - Deathclasp, Terror of the Sands", "Vish Kozus, Captain of the Guard (north gate)", 50.8, 33.6, 60),
    T("A Terrible Purpose", "Commander Mar'alith (keep)", 49.2, 34.2, 60),
    A("Twilight Geolords", "Huum Wildmane", 48.6, 37.9, 60),
    D("Twilight Geolords", "Kill 10 Twilight Geolords at Twilight Base Camp (more at Twilight Post and Twilight Outpost)", 42.0, 41.0, 60),
    T("Twilight Geolords", "Huum Wildmane", 48.6, 37.9, 60),
    A("Vyral the Vile", "Huum Wildmane", 48.6, 37.9, 60),
    D("Vyral the Vile", "Twilight's Run, the cave at the foot of Staghelm Point in the north-east: kill Vyral the Vile (level 60, Twilight Overlord escorts) for Vyral's Signet Ring", 70.1, 16.2, 60),
    T("Vyral the Vile", "Huum Wildmane", 48.6, 37.9, 60),
    G("Cenarion Hold flight master", 50.7, 34.6, 60, "Fly to Moonglade (Nighthaven) and turn in Umber, Archivist to Umber at 44.9, 35.6. Optional at 60: Commander Mar'alith's Dearest Natalia chain, Field Duty and the Cenarion Circle rep quests (elite/group); Baristolth's What Tomorrow Brings starts the AQ gate chain (raid)"),
} }

-- Where to level at every stage, for when no detailed route covers you yet.
local PLAN = {
    { min = 1, max = 11, zones = { "Teldrassil", "Dun Morogh", "Elwynn Forest" }, hub = "Your starting zone" },
    { min = 11, max = 16, zones = { "Darkshore", "Loch Modan", "Westfall" }, hub = "Auberdine, Thelsamar or Sentinel Hill", note = "Hall of Thanes (13-18) is under Ironforge" },
    { min = 16, max = 21, zones = { "Darkshore", "Westfall", "Redridge Mountains", "Loch Modan" }, hub = "Auberdine, Sentinel Hill or Lakeshire", note = "Wailing Caverns and The Deadmines suit 17-24" },
    { min = 21, max = 26, zones = { "Ashenvale", "Wetlands", "Duskwood" }, hub = "Astranaar, Menethil Harbor or Darkshire", note = "Shadowfang Keep suits 22-30" },
    { min = 26, max = 31, zones = { "Duskwood", "Hillsbrad Foothills", "Wetlands" }, hub = "Darkshire, Southshore or Menethil Harbor", note = "Blackfathom Deeps and The Stockade suit 24-32" },
    { min = 31, max = 36, zones = { "Stranglethorn Vale", "Arathi Highlands", "Desolace" }, hub = "Booty Bay, Refuge Pointe or Nijel's Point", note = "Riverglades, new in Forever, opens at 33" },
    { min = 36, max = 41, zones = { "Riverglades", "Stranglethorn Vale", "Dustwallow Marsh" }, hub = "Powderfuse Port, Farholde Keep or Theramore", note = "Scarlet Monastery suits 34-45" },
    { min = 41, max = 46, zones = { "Riverglades", "Tanaris", "Feralas" }, hub = "Gadgetzan, Thalanaar or Feathermoon", note = "Uldaman suits 41-51" },
    { min = 46, max = 51, zones = { "Tanaris", "Feralas", "The Hinterlands" }, hub = "Gadgetzan or Aerie Peak", note = "Zul'Farrak and Maraudon suit 44-55" },
    { min = 51, max = 56, zones = { "Un'Goro Crater", "Felwood", "Burning Steppes" }, hub = "Marshal's Refuge, Talonbranch Glade or Morgan's Vigil", note = "Blackrock Depths suits 52-60" },
    { min = 56, max = 61, zones = { "Western Plaguelands", "Eastern Plaguelands", "Winterspring", "Silithus" }, hub = "Chillwind Camp, Light's Hope Chapel, Everlook or Cenarion Hold",
      -- The XP-flow audit leaves the last level or two short of quests; the guide's "Reach level" line quotes this.
      note = "Blackrock Depths, Lower Blackrock Spire, Scholomance and Stratholme suit 55-60" },
}

LevelGuideRoutes = {
    chains = {
        -- Ordered by route min: the guide takes the first route that fits your level.
        NightElf = { TELDRASSIL, DARKSHORE, ASHENVALE, WETLANDS, DUSKWOOD, HILLSBRAD, ARATHI, DESOLACE, STRANGLETHORN, FERALAS, TANARIS, HINTERLANDS, UNGORO, FELWOOD, BURNING_STEPPES, WESTERN_PLAGUELANDS, EASTERN_PLAGUELANDS, WINTERSPRING, SILITHUS },
        Gnome = { DUN_MOROGH, LOCH_MODAN, WETLANDS, DUSKWOOD, ASHENVALE, HILLSBRAD, ARATHI, DESOLACE, STRANGLETHORN, FERALAS, HINTERLANDS, TANARIS, UNGORO, FELWOOD, BURNING_STEPPES, WESTERN_PLAGUELANDS, EASTERN_PLAGUELANDS, WINTERSPRING, SILITHUS },
        Dwarf = { DUN_MOROGH, LOCH_MODAN, WETLANDS, DUSKWOOD, ASHENVALE, HILLSBRAD, ARATHI, DESOLACE, STRANGLETHORN, FERALAS, HINTERLANDS, TANARIS, UNGORO, FELWOOD, BURNING_STEPPES, WESTERN_PLAGUELANDS, EASTERN_PLAGUELANDS, WINTERSPRING, SILITHUS },
        Human = { WETLANDS, DUSKWOOD, ASHENVALE, HILLSBRAD, ARATHI, DESOLACE, STRANGLETHORN, FERALAS, HINTERLANDS, TANARIS, UNGORO, FELWOOD, BURNING_STEPPES, WESTERN_PLAGUELANDS, EASTERN_PLAGUELANDS, WINTERSPRING, SILITHUS },
    },
    plan = PLAN,
}
