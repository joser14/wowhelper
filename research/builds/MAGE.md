# Mage builds, WoW Forever 1.60.1 (second pass, read 2026-11-09)

Data: `research\builds\MAGE.lua` (replaces `BuildsData.MAGE`). All three builds are full 51-point ordered lists,
validated against the tree. Splits are Arcane/Fire/Frost. Decoding method: see `DRUID.md` (same WT / Icy Veins /
rankedboost formats).

## Tree (1.60.1, tier gate in points)
Arcane: Wand Specialization 2, Improved Channeling 5, Arcane Resilience 3 (0) · Arcane Subtlety 2, Magic Absorption 2,
Arcane Concentration 5, Missile Barrage 2 (5) · Arcane Geometry 2, Arcane Impact 3, Arcane Blast 1 (10) · Arcane Shielding 2,
Improved Counterspell 2, Arcane Meditation 3, Arcane Wrath 1 (15) · Presence of Mind 1, Arcane Mind 5 (20) ·
Arcane Instability 3 (25) · Arcane Power (30).
Fire: Incineration 5, Accelerant 5 (0) · Ignite 5, Flame Throwing 2, Impact 3 (5) · Burning Soul 3, Improved Flamestrike 3,
Pyroblast 1, Improved Fire Blast 2 (10) · Improved Scorch 3, Improved Fire Ward 2, Heating Up 1, Master of Elements 3 (15) ·
Critical Mass 3, Blast Wave 1 (20) · Fire Power 3 (25) · Combustion (30).
Frost: Frost Warding 2, Improved Frostbolt 5, Precision 3 (0) · Ice Shards 5, Frostbite 3, Improved Frost Nova 2, Permafrost 3 (5) ·
Frost Channeling 3, Improved Blizzard 3, Ice Lance 1 (10) · Arctic Reach 2, Ice Block 1, Shatter 3 (15) ·
Improved Cone of Cold 3, Cold Snap 1, Fingers of Frost 2 (20) · Winter's Chill 5 (25) · Ice Barrier (30).
Note: Precision (hit) sits in Frost tier 1 in Forever, so every build takes 2-3 points there.

## Builds chosen

| Slot | Build | Split | Order | Confidence | Why |
|---|---|---|---|---|---|
| leveling | WT Frost (7 Arcane first) | 13/5/33 | exact (WT link) | high | WT calls Frost the default/fastest; IV and Kargoz (Mobalytics) also level Frost. |
| pvp | rankedboost Frost PvP | 17/0/34 | mine | low | Only published Forever mage PvP point map; Frost rated S (seemeta). |
| pve.dps | WT Fire | 18/31/2 | exact, one fix | medium | Method and WT both lead with Fire; IV's Fire/Arcane variant is close. |

WT Frost leveling, as decoded: Improved Channeling 5, Missile Barrage 2 (10-16) -> Improved Frostbolt 5, Precision 2,
Frostbite 3, Ice Lance (27), Ice Shards 4, Ice Block (32), Shatter 3, Ice Shards, Fingers of Frost 2, Cold Snap,
Improved Cone of Cold 2, Winter's Chill 5 (42-46), Ice Barrier (47) -> Precision, Arcane Concentration 5,
Improved Cone of Cold, Incineration 5, Arcane Impact. (WT's milestone table lists earliest-possible levels, e.g.
Ice Barrier "40", which only holds if you skip the 7 Arcane points.)

Fix applied to the WT Fire link: as linked, Combustion is clicked when only 29 Fire points are spent, so WT's own
calculator drops it and shows 50 points; the guide text names Master of Elements 1 and Combustion, so the .lua puts
Master of Elements before Combustion. Arcane in that link is Improved Channeling 5, Arcane Concentration 5,
Arcane Impact 3, Missile Barrage 2, Arcane Meditation 3; Frost is Precision 2 (WT: drop to 2/3 to afford full Arcane Meditation).

## Other exact builds found
- **WT Arcane leveling** 32/16/3: Improved Channeling 5, Missile Barrage 2, Arcane Concentration 3, Arcane Blast, Arcane Concentration 2,
  Arcane Impact 2, Arcane Wrath, Arcane Meditation 3, Precision 3 (Frost), Arcane Impact, Presence of Mind, Arcane Mind 5,
  Arcane Instability 3, Arcane Subtlety, Arcane Power, Arcane Subtlety; Incineration 5, Accelerant 5, Improved Fire Blast, Ignite 5.
  (WT: best for solo open world.)
- **WT Fire leveling** 13/35/3: Precision 3, Accelerant 5, Ignite 5, Pyroblast, Burning Soul 3, Incineration 5, Heating Up,
  Critical Mass 3, Improved Fire Blast 2, Fire Power 3, Improved Scorch 3, Combustion; Improved Channeling 5, Missile Barrage 2,
  Arcane Concentration 5, Master of Elements 3, Arcane Subtlety.
- **WT Arcane raid** 31/17/3: Arcane to Arcane Power (Improved Channeling 5, Missile Barrage 2, Arcane Concentration 5, Arcane Blast,
  Arcane Subtlety 1, Arcane Wrath, Arcane Meditation 3, Arcane Impact 3, Presence of Mind, Arcane Mind 5, Arcane Instability 3);
  Precision 3; Accelerant 5, Incineration 5, Ignite 5, Pyroblast, Heating Up. Its link order also trips tier gates (Arcane Wrath clicked at 14 points).
- **WT Frostfire Bolt** 0/29/22: Fire Incineration 5, Accelerant 5, Ignite 5, Pyroblast, Heating Up, Improved Fire Blast 2, Improved Scorch 3,
  Critical Mass 3, Fire Power 3, Master of Elements 1; Frost Precision 3, Frost Warding 2, Ice Shards 5, Ice Lance, Frost Channeling 3,
  Frostbite 2, Ice Block, Shatter 3, Fingers of Frost 2.
- **WT Frost/Arcane raid** 18/2/31: Frost Precision 3, Improved Frostbolt 5, Frostbite 3, Ice Shards 5, Ice Lance, Ice Block, Shatter 3,
  Cold Snap, Fingers of Frost 2, Frost Channeling 3, Arctic Reach 2, Winter's Chill 1, Ice Barrier; Arcane Improved Channeling 5,
  Missile Barrage 2, Arcane Concentration 5, Arcane Impact 3, Arcane Meditation 3; Incineration 2.
- **WT Winter's Chill / Cone of Cold** 18/0/33: Frost incl. Improved Cone of Cold 3, Winter's Chill 5, Ice Barrier; Arcane to Arcane Meditation.
- **IV** (all Nov 4, 2026): Deep Frost 9/0/42; Cone of Cold raiding (Arcane Meditation or Incineration variants); Frostfire Bolt 0/29/22
  (same ranks as WT's except Frostbite 1 + Improved Frost Nova 1); Fire/Arcane 16/32/3; Arcane/Fire 32/16/3; leveling builds for all three
  specs with exact order (IV frost leveling: Precision 2, Wand Specialization 2, Improved Channeling 3, Missile Barrage 2, Improved Frostbolt 3,
  Frostbite 3, Improved Frostbolt 2, Ice Lance, Ice Shards 4, Shatter 3, ...).

## Disagreements
- Leveling spec: WT text says Frost is fastest/safest, but describes Arcane as best for solo open world; Frost kept.
- Raid spec: Method "Fire (Fireball/Arcane)" best; WT gives no ranking; IV puts Deep Frost first on its builds page. Fire kept (2 sources).
- Stats: IV Fire/Frost Hit (to 17%) > Spell Power > Crit > Int > Spirit/MP5; Method Hit > SD > Crit > Haste > Pen > Int > Spirit;
  WT lists SD > Crit > Int > Haste (says "until 60"). Consensus: **Hit to 17% first, then Spell Damage, Crit**.

## Sources (read 2026-11-09)
- https://www.warcrafttavern.com/forever/guides/mage-leveling/ , /fire-mage/ , /frost-mage/ , /arcane-mage/
- https://www.icy-veins.com/wow-forever/frost-mage-leveling , /fire-mage-leveling , /arcane-mage-leveling ,
  /frost-mage-ranged-dps-pve-spec-builds-talents , /fire-mage-ranged-dps-pve-spec-builds-talents ,
  /arcane-mage-ranged-dps-pve-spec-builds-talents , /fire-mage-ranged-dps-pve-stat-priority , /frost-mage-ranged-dps-pve-stat-priority (all 2026-11-04)
- https://rankedboost.com/world-of-warcraft/forever/build/mage/#build=auth-mage-frost-pvp
- https://www.method.gg/wow-forever/class-guides/fire-mage (2026-11-09; first pass)
- Not found: a human-written Forever mage PvP guide (Mobalytics PvP hub has none for mage; IV PvP tier lists TBD).

## Recheck 2026-11-11 (after the 2026-11-10 tuning)
no mage change on Nov 10; Nov 9 fixed Flamestrike ground ticks eating Clearcasting and split Arcane Concentration's chance across the cast and each Arcane Missiles bolt (it was 10% on the cast and on each bolt). Warcraft Tavern mage-leveling and fire-mage calculator links are unchanged; rankedboost mage PvP updated 2026-11-08; Icy Veins frost leveling re-dated 2026-11-09 (before the tuning). Method's mage leveling guide was re-dated 2026-11-10 (18/0/33 Frost, not used here). All builds kept.
