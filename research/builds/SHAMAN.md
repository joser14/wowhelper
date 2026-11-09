# Shaman builds – second pass (researched 2026-11-09)

Data: `research\builds\SHAMAN.lua` (replaces `BuildsData.SHAMAN`). Alliance shamans are Dwarves only. All four builds
are exact 51-point orders from the source, validated against the 1.60.1 tree. Tree names follow the game data
(`"Elemental Combat"`, `"Enhancement"`, `"Restoration"`). Decoding method: see ROGUE.md.

| Slot | Build | Split (Ele/Enh/Resto) | Source (date) | Confidence |
|---|---|---|---|---|
| leveling | Enhancement leveling | 17/34/0 | Method shaman leveling (upd. 2026-11-08) | high |
| pvp | Elemental PvP / world | 33/7/11 | Icy Veins elemental spec-builds (2026-11-04) | medium |
| pve.healer | Restoration 0/10/41 | 0/10/41 | Icy Veins resto spec-builds (2026-11-04) | medium |
| pve.dps | Enhancement raid | 17/34/0 | Method enhancement talents (upd. 2026-11-09) | high |

## Why these
- **Leveling – Enhancement.** Method and Icy Veins are point-for-point identical to level 34 (Thundering Strikes 5,
  Mental Dexterity 3, Ancestral Knowledge, Shamanistic Focus 20, Elemental Weapons 3, Stormstrike 25, Improved Ghost
  Wolf 26-27, Flurry, Improved Stormstrike, Mental Quickness). Then Method takes Maelstrom Weapon and Rage of the
  Farseer at 40; Icy Veins detours into Restoration (Tidal Focus, Mindfulness) for mana and gets the capstone at 51.
  Picked Method (newer, capstone at 40). RankedBoost's leveling build is 0/43/8 (Toughness, Anticipation).
  Warcraft Tavern's shaman links are level-30 beta builds made on an older Enhancement tree (one talent position no
  longer exists), so they no longer decode cleanly.
- **PvE DPS – Enhancement 17/34/0.** Method "Recommended" and Icy Veins "Standard Endgame" have the same split and
  nearly the same points (Method: Ancestral Knowledge 5; Icy Veins: AK 3 + Improved Ghost Wolf 2). Method's
  "Extra Hit & Mana Regen" moves 8 points to Tidal Focus/Mindfulness; Icy Veins' solo/dungeon build is 17/26/8.
  RankedBoost is 8/33/10. Elemental raid builds (for reference): Method default 31/9/11 (Ele to Lightning Mastery,
  Resto Tidal Focus/Mindfulness/Totemic Focus/Water Shield, Thundering Strikes, AK), Icy Veins 31/4/16 (support, Mana
  Tide) and 32/8/11 (max throughput).
- **PvE Healer – Restoration 0/10/41.** Icy Veins (same build on its leveling page): Tidal Focus, Mindfulness,
  Improved Healing Wave 5, Water Shield 20, Mana Tide 25, Tidal Mastery, Nature's Swiftness 30, Healing Way, Purification,
  Riptide 40, Healing Focus 3, Ancestral Healing 3, Thundering Strikes 5, Restorative Totems 5, Ancestral Knowledge 5.
  RankedBoost 0/5/46 (Totemic Focus 5 instead of the Ancestral Knowledge points). Method has no Resto page; WT only a
  level-30 beta build.
- **PvP – Elemental.** The only Forever shaman PvP builds published are Elemental: Icy Veins "PvP / World / Leveling"
  33/7/11 (Earthbound, Eye of the Storm, Trial by Fire 2, Lightning Mastery; Resto Water Shield and Improved
  Reincarnation) and RankedBoost "Elemental Shaman PvP Build" 31/20/0 (Elemental Warding, Elemental Reach, Earth's Grasp,
  Guardian Totems, Toughness, Improved Ghost Wolf; ranks only). Seemeta rates Elemental A for PvP; Skycoach/ExitLag
  prefer Enhancement but publish no build. Changed the first-pass Enhancement PvP pick to Elemental for that reason; no
  pvp2.

## Stats
- Enhancement (Icy Veins, post-release buffs): **Weapon DPS > Hit > Expertise > Intellect > Strength ≈ Spell Power**;
  Crit and Agility are nice-to-have. Mental Dexterity converts Int to AP, so Int is now the best main stat.
  Method (first pass): Hit 8% (to 17%) > Str > Int > Crit = Agi > Spirit = MP5.
- Elemental (Icy Veins): **Spell Power > Hit (to 17%) > Crit > Intellect > MP5** (Method: Hit first).
- Restoration (Icy Veins): **Healing Power > Crit > Intellect > Spirit > MP5** (crit feeds Water Shield and Ancestral
  Healing; WT had Spirit 2nd).
- **ItemAdvisor:** enhancement profile – raise Intellect above Strength and add Weapon DPS as the top weight; IA's crit
  weight above Str no longer matches either source (crit is optional in IV). Healer profile for shamans: Crit is #2 in
  IV, above Int/Spirit, unlike priests (MP5/Spirit first) – a shared healer profile fits neither perfectly.

## Sources (read 2026-11-09)
- https://www.method.gg/wow-forever/wow-forever-shaman-leveling-guide-and-talents (2026-11-08)
- https://www.method.gg/wow-forever/class-guides/enhancement-shaman/talents, …/elemental-shaman/talents (2026-11-09)
- https://www.icy-veins.com/wow-forever/enhancement-shaman-melee-dps-pve-spec-builds-talents, elemental-…, restoration-…, *-leveling, *-pve-stat-priority (2026-11-04)
- https://rankedboost.com/world-of-warcraft/forever/build/shaman/ (game build 1.60.1.70862)
- https://www.warcrafttavern.com/forever/guides/shaman-leveling/, /enhancement-shaman/, /elemental-shaman/, /restoration-shaman/ (level-30 beta links)
- https://seemeta.com/en/wow-forever/pvp-tier-list (2026-11-08)
