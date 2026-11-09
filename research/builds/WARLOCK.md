# Warlock builds, WoW Forever 1.60.1 (second pass, read 2026-11-09)

Data: `research\builds\WARLOCK.lua` (replaces `BuildsData.WARLOCK`). Leveling, pvp and pve.dps are full 51-point
ordered lists validated against the tree; pvp2 (Demonology Soul Link) stays steps-based because no point map exists.
Splits are Affliction/Demonology/Destruction. Decoding method: see `DRUID.md`.

## Tree (1.60.1, tier gate in points)
Affliction: Improved Life Tap 2, Suppression 5, Improved Corruption 5 (0) · Grim Reach 2, Soul Harvest 2, Improved Drains 3 (5) ·
Improved Bane of Agony 2, Fel Concentration 3, Amplify Curse 1, Pandemic 3 (10) · Malevolence 5, Nightfall 2, Curse of Exhaustion 1 (15) ·
Siphon Life 1, Soul Siphon 3 (20) · Shadow Mastery 5 (25) · Wrack (30).
Demonology: Improved Health Funnel 2, Improved Imp 3, Demonic Embrace 5, Unholy Power 5 (0) · Demonic Aegis 2, Improved Voidwalker 3,
Fel Vitality 3, Demonic Energies 2 (5) · Improved Sayaad 3, Demonic Sacrifice 1, Master Summoner 2 (10) · Decimation 2, Fel Domination 1,
Demonic Brand 3 (15) · Improved Felhunter 3, Soul Link 1, Demonic Knowledge 3 (20) · Master Demonologist 5 (25) · Demonic Pact (30).
Destruction: Destructive Reach 2, Improved Shadow Bolt 5, Bane 5 (0) · Molten Skin 5, Cataclysm 3, Aftermath 5 (5) · Ruin 5, Shadowburn 1 (10) ·
Intensity 3, Agonizing Flames 3, Conflagrate 1 (15) · Pyroclasm 2, Bane of Havoc 1, Fire and Brimstone 3 (20) · Shadow and Flame 5 (25) · Incinerate (30).
("Sayaad" is Forever's Succubus/Incubus demon; WT says it takes over tanking from the Voidwalker at 20.)

## Builds chosen

| Slot | Build | Split | Order | Confidence | Why |
|---|---|---|---|---|---|
| leveling | WT Affliction | 40/7/4 | exact (WT text bands) | high | WT recommends it, no respec; its calculator link has the same final ranks. |
| pvp | Mobalytics Destruction PvP (Saucy722) | 7/7/37 | mine | medium | Human-written Forever PvP guide (2026-11-06) with a full point map; rankedboost's Destruction PvP (0/13/38) agrees on the core. |
| pvp2 | Demonology Soul Link | steps | — | low | Rated S on two tier lists; no published Forever point map. |
| pve.dps | Affliction Wrack | 33/0/18 | WT link order | high | WT and Icy Veins publish **identical ranks**; WT says it is slightly ahead of SM/Ruin. |

Leveling order (WT text): 10-19 Improved Corruption 5, Suppression 5; 20-26 Unholy Power 5, Demonic Energies 2; 27-30 Improved Drains 3,
Amplify Curse; 31-40 Improved Bane of Agony 2, Improved Life Tap 2, Pandemic 3, Soul Siphon 3; 41-60 Malevolence 5, Shadow Mastery 5,
Siphon Life, Fel Concentration 3, Nightfall 2, Improved Shadow Bolt 4. The WT link itself is in tree order (Improved Life Tap first), so
the text bands were used for the order. Note this leveling build never takes Wrack; the raid build does.

Destruction PvP ranks (Mobalytics, matched positionally to the tree and to rankedboost): Affliction Improved Corruption 5, Grim Reach 2;
Demonology Demonic Embrace 5, Demonic Aegis 2; Destruction Destructive Reach 2, Bane 5, Molten Skin 3, Aftermath 5, Ruin 5, Shadowburn,
Intensity 3, Agonizing Flames 3, Conflagrate, Pyroclasm 2, Bane of Havoc, Shadow and Flame 5, Incinerate. The guide's options: move
Pyroclasm 2 to Fire and Brimstone; or Intensity 3->1 for Improved Drains/Amplify Curse/Molten Skin when you need to survive.
rankedboost's version: Demonology Demonic Embrace 5, Demonic Aegis 2, Fel Vitality 3, Improved Sayaad 3; Destruction Bane 5, Molten Skin 5,
Aftermath 5, Ruin 5, Shadowburn, Intensity 3, Agonizing Flames 3, Conflagrate, Pyroclasm 2, Fire and Brimstone 3, Shadow and Flame 5 (no Incinerate).

## Other exact builds found
- **WT Demonology leveling** 20/31/0 (link, tree order): Improved Life Tap 2, Suppression 5, Improved Corruption 5, Improved Drains 3,
  Pandemic 3, Malevolence 2; Demonic Embrace 1, Unholy Power 5, Fel Vitality 3, Demonic Energies 2, Improved Sayaad 3, Demonic Sacrifice,
  Master Summoner 2, Fel Domination, Demonic Brand 3, Soul Link, Demonic Knowledge 3, Master Demonologist 5, Demonic Pact.
  WT text: level Affliction to 27, respec into Demonology (Demonic Brand lets the Sayaad hold 2-3 mobs).
- **WT Destruction leveling** 17/3/31 (text bands): Bane 5, Cataclysm 3, Aftermath 2, Shadowburn (20), Aftermath 5, Ruin 1, Conflagrate (25),
  Ruin 3, Agonizing Flames 3, Bane of Havoc, Fire and Brimstone 3, Shadow and Flame 5, Incinerate (40); then Suppression 5, Improved Life Tap 2,
  Improved Corruption 5, Improved Imp 3, Amplify Curse, Pandemic 3, Malevolence 1.
- **WT Affliction SM/Ruin raid** 30/0/21 (Bane, Ruin, Improved Shadow Bolt filler; slightly behind Wrack).
- **WT Demonology raid** 2/31/18, Fire (sacrifice Sayaad, keep Imp) and Shadow variants, about 3% apart; Fire recommended.
- **WT Destruction raid** 14/4/33 Sayaad (best), Imp variant, and Demonic Sacrifice 7/11/33.
- **IV** (2026-11-04): Affliction leveling 40/11/0 order (Suppression 4, Improved Corruption 5, Grim Reach, Improved Bane of Agony 2,
  Pandemic 3, Nightfall 2, Malevolence 3, Siphon Life, Demonic Embrace 5, Demonic Aegis 2, Fel Vitality 3, Demonic Sacrifice, ...Wrack);
  Demonology leveling 20/31/0; Destruction leveling; Wrack raid (= WT); Demonic Pact Succubus 2/31/18; Demonic Sacrifice Destruction Fire 7/11/33.

## Disagreements
- Stat order: IV Affliction Hit (to 17%) > Spell Power > Crit > Haste > Int; WT Spell Power > Crit > Hit (17%) > Haste > Spell Pierce > Int > Spirit
  (WT sims: 1% Crit ~ 8.8 SP, 1% Hit ~ 8.6 SP, so they are close); Method Hit > SD > Shadow > Pen > Crit > Int > Haste.
  Used: Hit (to 17%) > Spell Damage/Shadow > Crit > Haste > Spell Penetration > Int. Hit 4% is enough vs same-level mobs/players.
- WT values Spell Pierce at ~1.6 SP per point (take it when it is on gear you would wear anyway).
- PvP spec: seemeta/skycoach rate Demonology Soul Link S; the only full PvP guide is Destruction (Mobalytics). Both kept (pvp/pvp2).

## Sources (read 2026-11-09)
- https://www.warcrafttavern.com/forever/guides/warlock-leveling/ , /affliction-warlock/ , /demonology-warlock/ , /destruction-warlock/
- https://www.icy-veins.com/wow-forever/affliction-warlock-leveling , /demonology-warlock-leveling , /destruction-warlock-leveling ,
  /affliction-warlock-ranged-dps-pve-spec-builds-talents , /demonology-warlock-ranged-dps-pve-spec-builds-talents ,
  /destruction-warlock-ranged-dps-pve-spec-builds-talents , /affliction-warlock-ranged-dps-pve-stat-priority (all 2026-11-04)
- https://mobalytics.gg/wow-forever/classes/destruction-warlock-pvp-guide (Saucy722, 2026-11-06)
- https://rankedboost.com/world-of-warcraft/forever/build/warlock/#build=auth-warlock-destruction-pvp
- PvP ratings: skycoach.gg (2026-11-06), seemeta.com (2026-11-08).
