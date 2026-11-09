# Data gaps filled (Nov 2026, read in the in-app browser)

How the pages were read: text only. One coordinate set (Caylais, below) was also read from Wowhead's map-pin data
with a page script, before the text-only rule was enforced. No other value comes from a script.

Sources that worked:
- wowhead.com/forever item pages (item IDs, mats, vendor zones) and Forever guides with `/way` text
- wowhead.com/classic vendor-recipe guides (`/way` per vendor, Classic maps)
- wow-forever.gg/db/npcs/<id> (Classic spawn coordinates as text, built from client 1.60.1 data). Its Eastern
  Plaguelands frame does not match the game's (Light's Hope NPCs show at ~71, 48 instead of ~81, 58). It also puts
  Ironforge and Darnassus NPCs on the Dun Morogh and Teldrassil maps. Every other zone checked matched Wowhead.

## Values changed

| File | Item | Old | New | Source |
|---|---|---|---|---|
| LevelGuide\Routes.lua | Caylais Moonfeather (FP) | 36.3, 45.6 "approx" | 36.4, 45.6 | https://wow-forever.gg/db/npcs/3841-caylais-moonfeather/ ; wowhead.com/forever/npc=3841 map pins (36.4,45.4 / 36.4,45.6) |
| LevelGuide\Routes.lua | Innkeeper Shaussiy (home) | 37.0, 44.1 "approx" | 37.1, 44.1 | https://wow-forever.gg/db/npcs/6737-innkeeper-shaussiy/ |
| Dungeons\Data.lua | Razorfen Downs entrance | 0.430, 0.950 (approx) | 0.490, 0.949 | Myriam Moonsinger stands at the door: https://wow-forever.gg/db/npcs/12866-myriam-moonsinger/ |
| Dungeons\Data.lua | Stratholme Main Gate | 0.270, 0.120 (approx) | 0.304, 0.145 (derived, about ±0.5) | https://wow-forever.gg/dungeons/stratholme/ (door 26.09, 10.44 in its frame). Converted using 3 NPCs whose coordinates are known in both frames: Smokey LaRue (/way 80 58), Egan (/way 14 33) from https://www.wowhead.com/forever/guide/stratholme-live-side-dungeon-overview-location-rewards, and Miranda Breechlock (81.6, 60.0) from the Wowhead Classic alchemy vendor guide |
| ProfessionGuide\Data_Alchemy.lua | Maria Lumere | 0.556, 0.856 | 0.558, 0.856 | https://wow-forever.gg/db/npcs/1313-maria-lumere/ |
| ProfessionGuide\Data_Alchemy.lua | Logannas | 0.330, 0.440 | 0.327, 0.440 | https://wow-forever.gg/db/npcs/8157-logannas/ (Wowhead Classic guide says 32.6, 42.8) |
| ProfessionGuide\Data_Alchemy.lua | Minor Arcane Elixir 247754 | unverified | confirmed | https://www.wowhead.com/forever/item=247754 |
| ProfessionGuide\Data_Engineering.lua | Gearcutter Cogspinner | 0.680, 0.430 | 0.682, 0.442 | https://www.wowhead.com/classic/guide/engineering-vendor-recipes-wow-classic |
| ProfessionGuide\Data_Enchanting.lua | Vaean | 0.585, 0.145 | 0.586, 0.144 | https://www.wowhead.com/classic/guide/enchanting-vendor-recipes-wow-classic |
| ProfessionGuide\Data_Enchanting.lua | Tilli Thistlefuzz | 0.610, 0.448 | 0.608, 0.442 | https://www.wowhead.com/classic/guide/tailoring-vendor-recipes-wow-classic (the enchanting guide says 59.8, 44.0) |
| ProfessionGuide\Data_Enchanting.lua | Kania | 0.520, 0.394 | 0.520, 0.397 | enchanting vendor guide above |
| ProfessionGuide\Data_Enchanting.lua | Mote of Magic 247786 | unverified, left out of mats | confirmed; added to Runed Copper Rod mats (1, vendor) | https://www.wowhead.com/forever/item=247786 |
| ProfessionGuide\Data_Tailoring.lua | Runecloth Cuffs itemID | none | 254123 (pattern 254124, Tailoring 250, sold in Mount Hyjal; mats match) | https://www.wowhead.com/forever/item=254124 |
| ProfessionGuide\Data_Leatherworking.lua | Jase Farlane / Runic Leather Headband | "not checked in Forever" | confirmed: pattern 15756, needs 265, sold by Jase Farlane (EPL); mats match | https://www.wowhead.com/forever/item=15756 |
| ProfessionGuide\Data_Mining.lua | Kurdram Stonehammer | flagged as a copy of Delfrum's point | confirmed 38.2, 41 (same forge as Delfrum, 38.2, 40.9); comment only | https://www.wowhead.com/forever/guide/professions/mining/overview-leveling ; https://wow-forever.gg/db/npcs/6299-delfrum-flintbeard/ |
| GoldGuide\Data.lua | Stonescale Eel farm | Tanaris 69.0, 33.0, "fishing ~180" | 67.0, 22.0 (Steamwheedle Port shore), "fishing 205, 300 to stop getaways"; renamed "Stonescale Eels off Steamwheedle Port" | https://www.wowhead.com/classic/guide/best-fishing-pools-farming-locations-classic-wow ; port /way 67 22 from https://www.wowhead.com/forever/guide/zulfarrak-dungeon-overview-location-rewards |
| GoldGuide\Data.lua | Oily Blackmouth farm | text "needs fishing 55" | coordinates unchanged (36, 46, Auberdine shore); text now says pools need no extra skill and 75 stops getaways | fishing guide above (Darkshore is listed as a top Blackmouth coast) |
| GoldGuide\Data.lua | Recipe tips (Ulthir, Mythrin'dir, Narkk, Vendor-Tron 1000, Soolie Berryfizz, Logannas, Qia) | no location | coordinates added to tip text: 55.8,24.6; 61.0,18.0; 28.2,74.4; 60.4,38.2; 66.6,54.8; 32.7,44.0; 61.2,37.2 | Wowhead Classic alchemy/enchanting/tailoring/cooking vendor-recipe guides; wowhead.com/classic/npc=12245 (Shadow Oil in Vendor-Tron's stock) |

Tests: runall.ps1 shows the same results as before (33 passing tests plus test_builds pass; the same 11 old tests fail).
LevelGuide validate_all: 0 problems in every zone.

## Still not confirmed

- **Dungeon entrances**: Scarlet Monastery (all four wings), Sunken Temple, Scholomance, Ruins of Lordaeron,
  Stratholme Service Gate and Maraudon are unchanged. Wowhead Forever guides show these only as map pins, with no
  text coordinates. wow-forever.gg gives world coordinates (SM 2892.2, -811.3; Sunken Temple -10170.1, -3996;
  RFD -4662.9, -2535.9) but no zone bounds to convert them. Its Sunken Temple zone point (77.3, 35.92) does not fit
  the Pool of Tears, so it was not used.
  Leads:
  - Scholomance: Magnus Frostwake, who stands "outside Scholomance", is at 68.0, 77.5.
  - Maraudon: Cavindra, at the entrance, is at 32.0, 63.7. Our point is 29.1, 62.5; it was not flagged, so it was left.
  - Scarlet Monastery: warcraft.wiki.gg puts the Grand Vestibule keyring at 83.9, 23.4 (Retail map).
- **Mythrin'dir mismatch**: ProfessionGuide\Data_Enchanting.lua has 58.1, 34.2 (from warcraft.wiki.gg), but the
  Wowhead Classic guide says 61.0, 18.0 (Craftsmen's Terrace). GoldGuide now uses 61.0, 18.0. The ProfessionGuide
  entry was not flagged, so it was not changed.
- **Ulthir**: ProfessionGuide has 55.4, 23.2; the Wowhead guide says 55.8, 24.6. Not changed.
- **Delfrum Flintbeard**: listed as "Apprentice". wow-forever.gg calls him a Journeyman Blacksmith (trainer).
- **Pexmit**: not confirmed as the Runecloth Cuffs vendor. Wowhead only says the pattern is sold in Mount Hyjal;
  the "Sold by" tab didn't load as text.
- **Approximate quest-area steps in LevelGuide\Routes.lua**: not touched. These are mob areas and objectives
  (Jai'vhanel, moonwell, Buzzbox 525, Arbal, Gyromast, Courier, STV ruins); no text source gives them.
- **Dungeons quest/item IDs**: the file has no comments saying any of them came from memory, so none were rechecked.
