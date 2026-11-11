# Talent builds after the 10 November 2026 class tuning (checked 2026-11-11)

Scope: every build in `Builds\Data.lua` (9 classes; goals leveling, pvp, pvp2, tank, healer, dps, dps2) was compared
against Blizzard's notes and against the guides it came from, re-read on 2026-11-11. Data is regenerated with
`node research\builds\gen_data.js <repo root>` (the file comment comes from `research\builds\data_header.lua`, recreated
from the previous Data.lua header because the generator expects it). Summaries are in my own words.

## What Blizzard changed

Official source: "WoW: Forever Hotfixes - November 10, 2026" (Blizzard forum thread 2403040 / Blizzard news 24315281).
The thread's opening post collects 5, 6, 9 and 10 November; the 10 November section was posted on 11 November. Icy Veins'
news write-up of the same notes ("Class changes, profession improvements, AH deposit, gold buffs - WoW Forever hotfixes
November 10th") was used to cross-check the numbers. No hotfixes after 10 November were listed when
read on 2026-11-11.

Class changes on 10 Nov (talent-related in **bold**):
- Druid: Omen of Clarity works again after swapping specs. **Restoration: Nature's Swiftness also makes Wild Growth instant.**
- Hunter: pets had 150% health by mistake, now 115%. Arcane Shot costs 11% of base mana at every rank.
  **Beast Mastery: Summon Hawk costs 11% of base mana; hawks deal about 80% more melee damage.**
- Paladin: Redoubt can be tracked in the Cooldown Manager.
- Priest: Revelation enchant no longer procs from Vampiric Embrace healing. **Holy: Holy Nova unlearns when untalented.**
- Shaman: Maelstrom Weapon trackable in the Cooldown Manager; weapon imbues and weapon totems work together
  (Windfury Weapon + Windfury Totem). **Enhancement: Stormstrike 100% weapon damage (was 150%), 8 sec cooldown (was 6);
  Mental Dexterity 33/66/100% of Intellect as attack power (was 50/100/150%); Maelstrom Weapon 20% per stack at every rank,
  6/7/8/9/10 activations per minute by rank (was 4-20% by rank, 20 per minute).** Blizzard's note: the changes undo beta
  changes that pushed Enhancement to Spell Power/Intellect gear, to refocus it on Windfury before raids open.
- Warlock: Imp Firebolt ranks 1-4 hit harder; Imp, Voidwalker, Incubus, Succubus about +15% base health.
  **Affliction: Soul Siphon now 4/8/12% more Drain Life, Drain Soul and Wrack damage per Corruption, Siphon Life and Bane of
  Agony on the target, up to 36% (was per any Affliction spell). Wrack: 30% less damage and no longer raises your periodic
  damage; now a 6-second channel ticking each second during which Corruption, Siphon Life and Bane of Agony tick 100% faster.**
  Destruction: Bane of Havoc triggers the global cooldown.
- Warrior: **Arms: Sweeping Strikes no longer loses charges when no second target is hit.**

Earlier in the thread (context): Nov 6 Voidwalker +~40 health, Soul Siphon no longer lets Wrack boost itself, Bloom heals its
target, Arcane Blast lasts 18 sec; Nov 9 Arcane Concentration's chance split across the cast and each bolt, Feral Charge (Cat)
enters combat at once, Natural Instinct covers Lacerate and Pounce, Lightning Overload damage fixed, Power Infusion persists
on allies.

**No talent was renamed, moved or removed**, and no tree changed shape: every name in Data.lua still matches (below).

## Per class

| Class | What changed for us | Builds updated | Sources (date read 2026-11-11) |
|---|---|---|---|
| Warrior | Fix only (Sweeping Strikes charges). | none | IV arms leveling/fury/prot (2026-11-04), Method fury/prot (2026-11-04), Mobalytics warrior PvP (2026-11-07). Method warrior leveling re-dated 2026-11-10, still 34/15/2 (not our source). |
| Paladin | Cooldown Manager only. | none | IV ret leveling/holy/ret (2026-11-04), Method prot/ret (2026-11-09), holy (2026-11-04). |
| Hunter | Pet health cut, Summon Hawk buffed. Method's leveling guide (re-dated 2026-11-10) now takes **Trueshot Aura at 56 and Mortal Shots 4/5 (57-60)** instead of Mortal Shots 5/5. | **leveling** (last 5 points) | Method hunter leveling (2026-11-10, `data-talent` order decoded against Method's trait data); IV BM/MM (2026-11-04), Method MM (2026-11-05), WT links unchanged. |
| Rogue | Nothing on Nov 9-10. | none | Method leveling (2026-11-07), Mobalytics rogue PvP (shows 2026-11-04), IV combat (2026-11-04). |
| Priest | Fixes only. Mobalytics re-dated both priest guides to 2026-11-11; both 51-point paths read again and identical. | none | Mobalytics priest leveling + <Progress> shadow (2026-11-11), Leprestore (2026-11-05), rankedboost (2026-11-08), IV holy (2026-11-04). |
| Shaman | Enhancement nerfed (Stormstrike, Mental Dexterity, Maelstrom Weapon), imbues + totems stack. No guide has re-published an Enhancement talent build yet. | leveling and pve.dps **stats** (Strength now above Intellect; Spell Power dropped); summaries note the nerf. Points unchanged. | Blizzard dev note; Icy Veins news "free talent resets after class tuning" (2026-11-11: Enhancement gear moved from Int/SP to Str/AP); WT enhancement stat list; Method enh/ele talents (2026-11-09), Method leveling (2026-11-08), IV (2026-11-04). |
| Mage | Nothing on Nov 10 (Nov 9 Arcane Concentration/Flamestrike fixes). | none | WT mage-leveling and fire-mage links unchanged; rankedboost (2026-11-08); IV frost leveling (2026-11-09). Method mage leveling re-dated 2026-11-10 (18/0/33 Frost, not our source). |
| Warlock | Wrack reworked, Soul Siphon narrowed, demon health up. WT rebuilt both Affliction builds. | **leveling** 40/7/4 -> **41/7/3** (Wrack at 47, Siphon Life 37, ISB 3); **pve.dps** Wrack 33/0/18 -> **35/11/5** (Improved Bane of Agony 2, Demonic Embrace 5, Demonic Aegis 2, Fel Vitality 3, Demonic Sacrifice; ISB 5; no Bane/Ruin/Agonizing Flames). pvp/pvp2 unchanged. | WT warlock-leveling (text bands + calculator, page undated, links changed since 2026-11-09), WT affliction-warlock ("Last updated November 11, 2026"), both decoded in WT's own calculator (51/51 points accepted). Mobalytics Destruction PvP (re-dated 2026-11-11, same 7/7/37). |
| Druid | Resto Nature's Swiftness + Wild Growth; Omen of Clarity fix. | none | WT druid-leveling/feral/balance/resto links unchanged; IV and Method druid pages 2026-11-04; rankedboost (2026-11-08). |

All 40 point builds stay exact 51-point lists; `orderFrom` is unchanged ("source" for both rebuilt warlock builds: WT's
text bands for leveling, WT's calculator Talent Order for the raid build). `checked` is now 2026-11-11 on every build.

## Talent and tree names vs Forever's trait data

- Method's trait data (`ForeverTalentsData-1.60.1-2nov.json`) has **no `overrideName`** on any node, so the in-game talent
  name is the spell's name (which is what `Builds.lua` reads via `C_Traits.GetDefinitionInfo` + spell name).
- Every talent name in Data.lua (374 talent/tree pairs and all `keyTalents`) was compared with the names in the Icy Veins
  Forever talent calculators (which carry the trait spell IDs): **0 mismatches**, and every talent is in the tree the data says.
- Tree names: the data uses "Shadow Magic" (Priest), "Elemental Combat" (Shaman) and "Feral Combat" (Druid), as before.
  Method's data names the tabs "Shadow", "Elemental" and "Feral Combat". `Builds.lua` matches trees by their first word
  (`KnownTree`) and talents by name, so either spelling works; no change needed.

## Unconfirmed / to watch

- Enhancement Shaman talent points: no Method/Icy Veins/WT update yet. Mental Dexterity 3 and Maelstrom Weapon 5 are weaker
  now; recheck when guides re-publish.
- Affliction: Icy Veins (still 33/0/18 from Nov 4) and Method (Nov 4, "Wrack too weak") have not re-published; the new raid
  build rests on Warcraft Tavern alone, so its confidence is "medium" (was "high" when WT and IV agreed).
- WT's warlock-leveling page shows no date; the change was detected by its calculator links differing from 2026-11-09.
- Mobalytics' affliction-warlock-guide was updated 2026-11-11 but is not a source here (not re-read in full).
- Icy Veins stat-priority pages are still dated 2026-11-04 (Enhancement's still says Intellect first).
- `Builds\Builds.lua` (not in this change's scope) still prints "Blizzard announced class tuning for 2026-11-10, so these
  builds may change"; that line could now say the builds were rechecked after the tuning.
