# Hunter builds, WoW Forever 1.60.1 (second pass, researched 2026-11-09)

Data: `research\builds\HUNTER.lua` (replaces `BuildsData.HUNTER`). All builds are full 51-point `points` lists.
Decoding method (Icy Veins / Method.gg / Warcraft Tavern calculator strings): see `WARRIOR.md`, first section.
Tree split below is Beast Mastery/Marksmanship/Survival.

| Goal | Build | BM/MM/SV | Source (date) | Order | Confidence |
|---|---|---|---|---|---|
| leveling | Beast Mastery | 31/20/0 | Method hunter leveling guide (upd. 2026-11-08) | exact, author's | high |
| pvp | BM PvP / world | 31/3/17 | Icy Veins BM spec-builds, "PvP / World / Leveling" (2026-11-04) | author's, 1 point moved | medium |
| pvp2 | MM PvP / world | 18/33/0 | Icy Veins MM spec-builds, "PvP / World / Leveling" (2026-11-04) | totals exact, order re-sequenced by me | medium |
| pve.dps | MM Lone Wolf | 5/33/13 | Method marksmanship-hunter/talents (2026-11-05) | exact, author's | medium |

## Leveling – Beast Mastery (Method; Icy Veins agrees)
10-14 Deadly Aspects, 15-16 Focused Fire, 17-18 Improved Revive Pet, 19 Endurance Training, 20-21 Pathfinding,
22-24 Unleashed Fury, 25 Summon Hawk, 26 Bestial Swiftness, 27 Unleashed Fury 4, 28-29 Ferocity, 30 Intimidation,
31-32 Bestial Discipline, 33-35 Ferocity 5, 36-39 Frenzy 4, 40 Bestial Wrath; 41-45 Lethal Attacks, 46-50 Careful
Aim, 51-52 Rapid Killing, 53-55 Efficiency, 56-60 Mortal Shots.
- Icy Veins beast-mastery-hunter-leveling (2026-11-04) has the same Beast Mastery path to Bestial Wrath at 40
  (32 BM incl. Unleashed Fury 5/5), then Lethal Attacks, Careful Aim, Rapid Killing, Survival Improved Tracking 5,
  Improved Stings 2 (32/14/5). Picked Method because it is newer and ends with Mortal Shots, which both raid guides take.
- Icy Veins also publishes full MM (32/19/0) and Survival (0/17/34) leveling orders; Warcraft Tavern's hunter
  leveling page still has 21-point level-30 builds (BM/MM/SV), all consistent with the above starts.

## PvP
Icy Veins is the only source with explicit hunter PvP builds (its "PvP / World / Leveling" builds):
- **BM**: Beast Mastery 31 (Unleashed Fury 5, Ferocity 5, Intimidation, Bestial Discipline, Frenzy 3, Bestial
  Wrath, Pathfinding 2) + Survival Improved Tracking 5, Entrapment 5, Surefooted 3, Clever Traps 1, Survival
  Tactics 2, Deterrence + Marksmanship Hawk Eye 3. Survival Tactics was clicked one point before its tier opened;
  I moved Deterrence ahead of it (Survival Tactics 56-57, Hawk Eye 58-60).
- **MM**: Marksmanship 33 (Lethal Attacks 5, Careful Aim 5, Improved Stings 1, Rapid Killing 2, Mortal Shots 5,
  Trueshot Aura, Rapid Recuperation 2, Barrage 2, Ranged Weapon Spec 5, Sniper Shot, Scatter Shot, Hawk Eye 3) +
  Beast Mastery 18 (Deadly Aspects 5, Focused Fire 2, Improved Revive Pet 2, Endurance Training 1, Unleashed Fury 4,
  Summon Hawk, Bestial Swiftness, Pathfinding 2). The string was clicked with Hawk Eye last, which breaks the
  Marksmanship tier gates; I re-sequenced by hand: Hawk Eye 20-22, Mortal Shots 26-30, Sniper Shot 41, Scatter
  Shot 42, then Beast Mastery with Summon Hawk last (60). Totals unchanged.
- Tier lists (seemeta 2026-11-08) rate BM and MM equally (A) for PvP – kept BM as `pvp`, MM as `pvp2`.

## PvE DPS – Marksmanship Lone Wolf (Method)
Marksmanship 33: Lethal Attacks 5, Careful Aim 5, Lone Wolf, Hawk Eye 3, Rapid Killing 2, Trueshot Aura, Mortal
Shots 5, Rapid Recuperation 2, Barrage 3, Ranged Weapon Spec 5, Sniper Shot; Beast Mastery Deadly Aspects 5;
Survival Improved Tracking 5, Entrapment 5, Surefooted 3.
Sources agree on the core but not the last ~13 points:
- Icy Veins "Lone Wolf PvE" (5/41/5): same MM core + Lone Wolf, Hawk Eye, Efficiency 5, Improved Stings 3;
  Deadly Aspects 5 and Improved Tracking 5. Its text says Deadly Aspects and Improved Tracking are the only required
  off-tree talents; Surefooted is an early-gear hit option.
- Warcraft Tavern Marksmanship (5/46/0): Lone Wolf, Efficiency 5 and Improved Arcane Shot 5, Sniper Shot delayed to 44.
- Method also lists a Pet MM build (16 BM for Unleashed Fury / Summon Hawk); Icy Veins likewise.
- Which spec is best: Method's MM page calls MM the likely best endgame spec; Method/WT call BM the easiest and
  strong now. BM raid builds decoded for reference: Method BM 31/20/0 (Bestial Wrath + Lethal Attacks, Careful
  Aim, Hawk Eye, Rapid Killing, Trueshot Aura, Mortal Shots 4), Icy Veins BM 31/20/0, Warcraft Tavern 31/20/0 –
  three-way agreement, so BM would be a "high" alternative if the addon wants a second DPS entry.

## Stats (for ItemAdvisor)
- Icy Veins (BM and MM, identical): **Weapon Damage > Hit (8%) > Crit > Agility > Attack Power**.
- Method MM (first pass): Agility = Intellect (Careful Aim converts Intellect to attack power) > Strength.
- Both differ from IA's hunter profile: IA has int=1 vs agi=4.5 and no explicit hit-first priority. Weapon damage
  (ranged weapon DPS) should be the top weight for hunters per Icy Veins.

## Gaps / risks
- Survival raid builds (Icy Veins melee / weaving / ranged; Method weaving / full melee) decoded but not stored –
  the data shape has one dps slot.
- Class tuning announced for 2026-11-10 (Warcraft Tavern blue-post feed).
