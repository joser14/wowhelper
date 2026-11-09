# Paladin builds, WoW Forever 1.60.1 (second pass, researched 2026-11-09)

Data: `research\builds\PALADIN.lua` (replaces `BuildsData.PALADIN`). All builds are full 51-point `points` lists.
Decoding method (Icy Veins / Method.gg / Warcraft Tavern calculator strings): see `WARRIOR.md`, first section.
Tree split below is Holy/Protection/Retribution.

| Goal | Build | H/P/R | Source (date) | Order | Confidence |
|---|---|---|---|---|---|
| leveling | Deep Retribution | 18/0/33 | Icy Veins retribution-paladin-leveling (upd. 2026-11-04) | exact, author's | high |
| pvp | Holy (PvE build used for PvP) | 31/8/12 | Icy Veins holy-paladin-healer-pve-spec-builds-talents (2026-11-04) | author's | low |
| pvp2 | Retribution Unsealed Wrath | 12/8/31 | Icy Veins ret spec-builds (2026-11-04) = Method ret talents (2026-11-09) | author's (IV) | low |
| pve.healer | Holy Light's Vigil | 31/5/15 | Method holy-paladin/talents (2026-11-04) | exact, author's | high |
| pve.tank | Deep Prot + Sacred Arbiter | 0/35/16 | Method protection-paladin/talents "Standard Prot: Sacred Arbiter" (2026-11-09) | exact, author's | high |
| pve.dps | Deep Ret Unsealed Wrath | 12/8/31 | Icy Veins + Method (identical point totals) | author's (IV) | high |

## Leveling – Retribution (Icy Veins)
10-14 Deflection, 15-16 Improved Judgement, 17-19 Conviction, 20-21 Pursuit of Justice, 22 Seal of Command,
23-24 Sanctified Judgement, 25 Sacred Arbiter, 26-28 Two-Handed Weapon Spec, 29 Sanctified Judgement 3,
30-32 Vengeance, 33 Repentance, 34 Vindication, 35-39 Champion of the Light, 40 Unsealed Wrath; 41-45 Divine
Strength, 46-47 Reverence, 48-50 Improved Seals, 51-52 Holy Conduit, 53-54 Improved Seals 5, 55-56 Purifying
Power, 57-58 Divine Precision, 59-60 Vindication 3.
- Method's paladin leveling page (updated 2026-11-09) shows two partial paths: Ret to Vengeance by 42 with Holy
  Divine Strength/Improved Seals at 22-31 (33 points), and a Ret-then-Protection tank path to Shieldsworn at 52
  (43 points). Both start with Benediction / Sanctified Judgement / Improved Judgement / Pursuit of Justice
  instead of Deflection. Kept Icy Veins because it is the only full 51-point leveling order.
- Holy and Protection leveling orders also exist on Icy Veins (holy-paladin-leveling 34 Holy / 12 Ret / 5 Prot;
  protection-paladin-leveling 35 Prot / 16 Ret) – decoded, not used.

## PvP
No Forever paladin PvP guide with talents exists in any source I could read (Mobalytics paladin PvP URLs 404;
Warcraft Tavern has no PvP pages; Icy Veins only PvE/leveling). Kept the PvP slots with honest "low":
- **Holy**: Icy Veins Holy build (Holy 31 incl. Purifying Power 2 and Holy Conduit 1, Ret Benediction 5,
  Improved Judgement 2, Conviction 3, Pursuit of Justice 2, Prot Divine Intellect 5, Sacred Duty 2, Guardian's
  Favor 1). Chosen over Method's Holy for PvP because its off-tree points include Guardian's Favor and Sacred Duty
  (shorter cooldowns). Icy Veins' text says PvP players may prefer Unyielding Faith in Retribution.
  Tier lists (seemeta 2026-11-08, Kargoz) rank Holy the strongest paladin PvP spec.
- **Retribution**: the consensus Unsealed Wrath DPS build (skycoach 2026-11-06 rates Ret top for PvP burst).

## PvE Healer – Holy (Method; Icy Veins near-identical)
Holy: Spiritual Focus 5, Reverence 2, Healing Light 3, Illumination 5, Divine Favor, Infusion of Light 2, Holy
Conduit 2, Oath of Light, Holy Shock, Boundless Light 2, Purifying Power 1, Holy Power 5, Light's Vigil;
Prot Divine Intellect 5; Ret Benediction 5, Improved Judgement 2, Conviction 3, Sanctified Judgement 3, Pursuit of Justice 2.
Icy Veins: same 31-point Holy core (Holy Conduit 1 / Purifying Power 2) and spends 6 points on Sacred Duty /
Guardian's Favor / extra Prot instead of Sanctified Judgement. Both say Conviction (crit) and Benediction matter.

## PvE Tank – Protection (Method; Icy Veins same Protection tree)
Protection 35: Redoubt 5, Sacred Duty 2, Precision 3, Templar's Bulwark, Toughness 3, Shield Specialization 2,
Anticipation 5, Improved Righteous Fury 3, Swift Judgement, Holy Shield, Reckoning 5, Iron Creed 3, Shieldsworn.
Retribution 16: Deflection 5, Sanctified Judgement 3, Conviction 3, Improved Judgement 2, Pursuit of Justice 2, Sacred Arbiter.
- Icy Veins Deep Protection: identical 35 Protection points, Retribution with Benediction 5 instead of Deflection.
- Method variants (decoded): "Improved Seals" (31 Prot / Holy Divine Strength 5 + Improved Seals 5 / Ret 10),
  "Improved Seals and Pursuit of Justice", "Shock Prot" (Holy Shock, 22/21/8). Icy Veins variant: Deep Holy tank
  (28 Prot / 23 Holy) for geared players.

## PvE DPS – Retribution Unsealed Wrath (Icy Veins = Method)
Ret 31: Benediction 5, Improved Judgement 2, Conviction 3, Sanctified Judgement 3, Seal of Command, Pursuit of
Justice 2, Two-Handed Weapon Spec 3, Sacred Arbiter, Unyielding Faith 1, Vengeance 3, Repentance, Champion of the
Light 5, Unsealed Wrath; Prot Divine Intellect 5, Precision 3; Holy Divine Strength 5, Improved Seals 5, Holy Conduit 2.
Point totals match exactly between Icy Veins (2026-11-04) and Method "Deep Retribution DPS" (2026-11-09); used Icy
Veins' order (Ret first, valid). Alternative: Shockadin / Holy Shock DPS (Icy Veins 30 Ret / 21 Holy; Method 28/23).

## Stats (for ItemAdvisor)
- Retribution (Unsealed Wrath), Icy Veins: **Weapon Damage > Hit 8% > Expertise 6.5% > Strength > Spell Power**.
  Method: Hit > Expertise > Spell Power > Str = AP > Int > Crit. Both rank Spell Power close to Strength – IA's
  retribution profile (dmg 0.5 vs str 2.2) undervalues it. Shockadin builds want Spell Power first.
  Weapon speed: Seal of Command builds want slow 2H, Seal of Righteousness builds fast.
- Holy: Icy Veins **Healing > Int > Spirit > MP5 > Crit**; Method Healing > Int > Crit > MP5 > Spirit > Haste.
  They disagree on Crit vs Spirit; data uses Method's (Illumination refunds mana on crits). IA's equal spirit/int is
  closer to Icy Veins.
- Protection: Icy Veins **Stamina > Defense (to 440) > Spell Power > Intellect > Strength**; Method Defense 440 >
  Sta > Hit > Expertise > SP > Block > Crit. Both put Spell Power in the top five – the shared IA tank profile has
  no spell-power weight.

## Gaps / risks
- PvP builds are not published; confidence low.
- Class tuning announced for 2026-11-10 (Warcraft Tavern blue-post feed).
