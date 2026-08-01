# Dark Tower — Loot & Combat Tuning Guide

A designer's guide to how loot scaling, rarity, affixes, item level —
what every knob does, and which ones are safe to tune vs. which reshape the whole game.

> **Where the knobs live**
> - **`DA_GlobalLootData`** (`Content/DarkTower/Inventory/_Shared/Data/`) — all loot scaling, rarity, affix-tier, and item-level values, plus the per-rarity table.
> - **Base Stat Tables** (per equipment type, referenced by `DA_GlobalLootData`; plus optional per-item tables on the item's DT Equipment Fragment) — each stat's Min/Max range.
> - **Affix Definitions** (`UDTAffixDefinition` assets) — each affix's Min/Max, weight, slot, level requirement.

---

## 1. The master dial: Floor → ItemPower

Almost everything scales off the dungeon **Floor**. Floor is first run through a soft cap so power
doesn't grow forever, producing **EffectiveFloor**:

```
EffectiveFloor = Floor                                         (if Floor ≤ GlobalFloorSoftCap)
               = SoftCap + (Floor − SoftCap) ^ GlobalFloorDR    (beyond the soft cap)
```

EffectiveFloor then drives **ItemPower** — a 0→1 "how strong should gear be here" value:

```
ItemPower = MinItemPower + (1 − MinItemPower) × (1 − EXP(−EffectiveFloor / GlobalItemPowerScalingRate))
```

| Knob | Default | What it does |
|---|---|---|
| `GlobalFloorSoftCap` | 200 | Floor where power growth starts slowing. Below it, power scales straight with floor. |
| `GlobalFloorDR` | 0.6 | How hard power is compressed past the soft cap. Lower = harder squeeze. |
| `GlobalItemPowerScalingRate` | 150 | How fast ItemPower climbs. Smaller = faster early power; larger = slower, longer climb. |
| `MinItemPower` | 0.01 | Power floor at Floor 1 — the baseline strength/variety of the weakest gear. Keep low for weak, uniform early gear; raise for stronger/more varied early gear (at the cost of a flatter early curve). |

**Feel:** ItemPower ≈ 0.02 at floor 1, ~0.5 at floor 100, ~0.74 at floor 200, and then **plateaus around ~0.82** even at floor 1000+.

> ⚠️ **Important consequence:** because ItemPower tops out near ~0.82, a normal item's base stats and
> affixes only ever reach ~82% of their table Max. **Author your stat/affix `Max` values as the
> "ultimate ceiling" the curve approaches, not the number you expect at end-game.** (Rarity can push
> base stats past Max — see §3.)

---

## 2. Base Stats (weapon damage, armor, etc.)

Each base stat rolls inside a window that grows with ItemPower. `MinStatScale` sets how *wide* that
window is — i.e. how much two same-floor items vary.

```
Ceiling   = StatMin + (StatMax − StatMin) × ItemPower
Floor     = StatMin + (StatMax − StatMin) × ItemPower × MinStatScale
RollFactor= random(0..1) ^ GlobalRollScalar
Value     = Floor + RollFactor × (Ceiling − Floor)
Value    ×= Rarity Stat Multiplier        (see §3)
```

| Knob | Where | Default | What it does |
|---|---|---|---|
| Stat `Min` / `Max` | Base Stat Tables | per stat | The stat's range. `Max` = the asymptotic ceiling (see §1 warning). |
| `RollBehavior` | Base Stat Tables | Scaled By Item Power | Per-stat scaling mode. **Scaled By Item Power** = the window above (floor + rarity scaled). **Full Range** = rolls the full `Min`–`Max` at any floor, ignoring ItemPower *and* the rarity stat multiplier — use for floor-independent stats like flask recharge speed, where `Max` is the literal best roll, not an asymptote. |
| `MinStatScale` | DA_GlobalLootData | 0.70 | **Variance control.** Higher = same-floor items roll closer together. 0.7 ≈ ~1.4× spread at depth; 0.5 ≈ ~1.9×; 0.03 ≈ ~10× (wild). |
| `GlobalRollScalar` | DA_GlobalLootData | 1.0 | Distribution shape inside the window. 1.0 = even. >1 biases low, <1 biases high. Applies to both roll behaviors. |

**Notes**
- Base-stat variance is *bounded by ItemPower*: at shallow floors the ceiling sits close to `Min`, so
  early rolls are naturally similar no matter what `MinStatScale` is. That's expected — early-game
  variety is meant to come from **rarity** and **affix tier jackpots**, not base-stat spread. The lever
  for *how strong/varied* the floor of the curve is, is `MinItemPower` (§1).
- A stat row with `Min ≥ Max` is treated as a config error: it logs a warning and rolls the Min.
- **Per-item stat tables:** an item's **DT Equipment Fragment** can list `ItemStatTables` — extra stat
  tables merged into (or, with `bIgnoreTypeStatTable`, replacing) the item type's global table. Use them
  for stats that only make sense on one item (health flask heal amount vs mana flask mana restore) instead
  of minting new equipment type tags. On a duplicate `StatTag`, the item's own row wins. `ForcedBaseStats`
  can force-roll stats from these tables too.

---

## 3. Rarity

Rarity is rolled per item from floor/budget-weighted odds, and affects three things: **base-stat
strength**, **affix count**, and **item value / item-level bonus**. Each rarity tier is a row in
`DA_GlobalLootData → LootRarityDataMap`.

### 3a. Rarity drop odds
```
Weight(rarity) = GlobalBaseRate × (1 + FinalLootBudget × GlobalWeightScalar)
```
Common's `GlobalWeightScalar` is **0**, so it stays a flat weight while the others grow with depth/bonus — making Common *relatively* rarer the deeper you go.

**Recommended starting values** (set these on each rarity row):

| Rarity | GlobalBaseRate | GlobalWeightScalar | StatMultiplier |
|---|---|---|---|
| Common | 1000 | 0 | 1.0 |
| Uncommon | 250 | 5 | 1.1 |
| Rare | 60 | 3.5 | 1.2 |
| Epic | 12 | 4 | 1.3 |
| Legendary | 2 | 1.75 | 1.4 |
| Artifact (Unique) | 0.25 | 1 | 1.4 |

> ⚠️ **If these are left at defaults (all base rate 1, scalar 0), every rarity is equally likely** —
> you'll get ~17% Legendaries. The game logs a warning at startup if it detects this. Always populate them.

### 3b. Rarity stat multiplier
`StatMultiplier` multiplies the rolled base-stat value (§2). It **can push a stat above its table Max**
(e.g. a Legendary's strength genuinely exceeds a Common's ceiling). Keep these gentle (1.0–1.5ish) — it
compounds with everything else.

### 3c. Other per-rarity fields
- **AffixConfig** (Min/Max Prefixes & Suffixes) — how *many* affixes each rarity rolls. This is rarity's
  biggest power lever; bigger gaps here = rarity matters more.
- **ItemLevelBonus** — flat item-level added (see §6).
- **ValueMultiplier** — vendor value multiplier (see §6).

---

## 4. Loot Quantity (bonus drops)

Higher floors / bonuses drop *more* items via "Loot Budget". This only applies to **loot-table drops**
(not scripted/guaranteed item drops).

```
LootBudget       = MinLoot + (1 − MinLoot) × (1 − EXP(−EffectiveFloor / LootBudgetScalingRate))
FinalLootBudget  = LootBudget × (1 + LootBonus)
ExtraLootRolls   = EffectiveFloor × FinalLootBudget × GlobalQuantityFactor   (capped at MaxExtraLootRolls)
```

The fractional part of `ExtraLootRolls` is a **chance**: 0.5 → 50% of a bonus drop; 1.5 → 1 guaranteed + 50% chance of a 2nd.

| Knob | Default | What it does |
|---|---|---|
| `GlobalQuantityFactor` | 0.02 | **Main quantity dial.** How many extra rolls each floor of budget grants. Raise for more drops. |
| `MinLoot` | 0.02 | Budget floor at floor 1. |
| `LootBudgetScalingRate` | 250 | How fast budget climbs with depth. Smaller = faster. |
| `MaxExtraLootRolls` | 20 | Hard safety cap on bonus drops. |
| `LootBonus` (per enemy/chest tier) | varies | Map/enemy/chest bonus that boosts both quantity *and* rarity. Set in the Enemy/Chest Tier maps. |

**Feel at 0.02:** ~20% bonus at floor 50, ~70% at floor 100, ~1 guaranteed at floor 150. Raise the factor if drops feel sparse.

---

## 5. Affixes / Passives (Tier 1–N)

Each affix rolls a **Tier** (luck) whose magnitude is then **scaled by floor** (power). High tiers are
always rare; the floor shifts the odds upward but never makes the top common. The magnitude maps onto the
affix's own Min/Max (Tier 1 ≈ Min, top Tier ≈ Max — minus the ItemPower ceiling from §1).

```
FloorPressure = clamp(EffectiveFloor / AffixTierFloorScale, 0, MaxFloorPressure)
Decay         = BaseTierDecay × (1 − FloorPressure)
weight(tier)  = EXP(−(tier − 1) × Decay)        ← higher tiers always rarer
TierFraction  = (rolledTier − 1) / (TierCount − 1)
Alpha         = ItemPower × TierFraction        ← floor scales the magnitude DOWN early
AffixValue    = Lerp(AffixMin, AffixMax, Alpha)
```

| Knob | Where | Default | What it does |
|---|---|---|---|
| `AffixTierCount` | DA_GlobalLootData | 10 | Number of tiers (the "/10" players see). |
| `BaseTierDecay` | DA_GlobalLootData | 0.9 | How rare high tiers are early. Higher = rarer top-tier rolls (bigger jackpots). |
| `AffixTierFloorScale` | DA_GlobalLootData | 300 | Over how many floors the odds shift toward high tiers. |
| `MaxFloorPressure` | DA_GlobalLootData | 0.8 | Cap on how flat the curve gets — keeps top tiers rare even deep. |
| Affix `Min` / `Max` | Affix Definition | per affix | The affix's value range across tiers 1→N. |
| Affix `Weight` | Affix Definition | 1 | How likely this affix is picked vs other affixes of its slot. |
| `RequiredItemLevel` | Affix Definition | 0 | Minimum item level before this affix can roll (good for gating powerful affixes to depth). |

**Design intent:** a low-floor item can still *occasionally* roll a high tier ("Tier 10!" wow), but its
**number** is floor-scaled, so it's the best item *for that floor* — not an end-game one-shot. Deeper
floors shift the odds up *and* scale the numbers up.

> Note: an affix using a **Scalable Float** value (curve) scales off item level instead of the tier roll,
> so it ignores the tier system. Use Min/Max ranges for affixes you want tiered.

---

## 6. Item Level, Required Level, Value

```
BaseItemLevel  = BaseItemLevel + EffectiveFloor × ItemLevelPerFloor + Rarity.ItemLevelBonus
FinalItemLevel = BaseItemLevel + (sum of rolled stat values) × StatContributionToItemLevel
RequiredLevel  = clamp( FinalItemLevel × ItemLevelToRequirementRatio, MinLevelRequirement, MaxCharacterLevel )
ItemValue      = FinalItemLevel × BaseValuePerItemLevel × Rarity.ValueMultiplier
```

| Knob | Default | What it does |
|---|---|---|
| `BaseItemLevel` | 1 | Item level at floor 0. |
| `ItemLevelPerFloor` | 3 | Item level gained per floor. |
| `StatContributionToItemLevel` | 0.1 | How much rolled stats add to item level (see caveat). |
| `ItemLevelToRequirementRatio` | 0.15 | Item level → required character level. |
| `MaxCharacterLevel` | 60 | Caps required level. |
| `BaseValuePerItemLevel` | 5 | Vendor value per item level. |

> ⚠️ **Known caveats (talk to engineering before relying on these):**
> - **Item level currently changes with the roll** (the stat-contribution term). Two same-floor items can
>   have different item levels based on how well they rolled. If you want item level to be a stable
>   "where it dropped" number, ask to drop the stat contribution.
> - **`RequiredLevel` is not yet enforced on equip**, and **`ItemValue` has no shop consumer yet** — they're
>   computed but currently cosmetic until those systems are wired.


## 6b. Armor & Damage Mitigation (combat)

Lives in **`DA_CombatGlobalData`** (`UDTCombatGlobalData`), consumed by `UDTCombatSubsystem::ApplyMitigation`.

Incoming non-true damage is mitigated by armor, then by resistance:

```
Armor          ×= 1 − clamp(PhysicalPenetration + MitigationPenetration, 0, 1)   ← pen eats armor first
ArmorReduction  = Armor^p / (Armor^p + K^p)        (K = ArmorConstant, p = ArmorExponent) ← independent of hit size
DamageResistance= clamp(Resistance + MitigationReduction, −10, 0.75)             ← capped % DR; negative amplifies
Damage         ×= (1 − ArmorReduction) × (1 − DamageResistance)
True damage bypasses all of the above.
```

| Knob | Default | What it does |
|---|---|---|
| `ArmorConstant` (K) | 2500 | **Armor needed for 50% mitigation** (true for any `p`). Lower = stronger armor. Curve approaches but never reaches 100% — no cap needed. |
| `ArmorExponent` (p) | 0.6 | **Curve skew.** `p = 1` is linear-in-EHP. `p < 1` front-loads it — early armor gives much more, late game diminishes faster. `p > 1` back-loads it. Shape only; the 50% point stays at K. |

**Feel at K = 2500, p = 0.6** (mitigation by armor): 100 → ~13%, 1k → ~37%, 2.5k → 50%, 10k → ~70%, 40k → ~84%. Mitigation does **not** depend on hit size — a given armor value reduces a 10-damage hit and a 10,000-damage hit by the same percentage. `DamageResistance` is a separate, capped (≤0.75) percentage stat that stacks multiplicatively on top.

> Note: `ArmorConstant` was previously `ArmorMitigationFactor` (a hit-size-scaled factor, default 8). The formula changed from `Armor/(Armor + factor×Damage)` to `Armor^p/(Armor^p + K^p)` to remove hit-size dependence and let the curve be front-loaded for early game. Any old serialized `ArmorMitigationFactor` value on the data asset is dropped and reverts to the new defaults.

---

## 7. Balance Levers — what to tune, what to leave alone

### 🟢 Tune freely (per-content / per-item knobs — low blast radius)
- **Base Stat `Min`/`Max`** per stat — the most direct power dial.
- **Affix `Min`/`Max`, `Weight`, `RequiredItemLevel`** — per-affix tuning and gating.
- **Per-rarity** `GlobalBaseRate`, `GlobalWeightScalar`, `StatMultiplier`, `AffixConfig`, `ValueMultiplier`, `ItemLevelBonus`.
- **`GlobalQuantityFactor`**, **`LootBonus`** (enemy/chest tiers) — drop quantity & rarity boosts.
- **`MinStatScale`** — base-stat variance (tightness). Great feel knob.
- **`BaseTierDecay`**, **`AffixTierFloorScale`** — affix-tier rarity & depth shift.

### 🟡 Tune carefully (global curve shape — affects the whole game)
- **`GlobalItemPowerScalingRate`**, **`GlobalFloorSoftCap`**, **`GlobalFloorDR`** — these reshape *every*
  item's power curve at once. Move in small steps and re-test across floors 1 / 100 / 200 / 1000.
- **`LootBudgetScalingRate`** — global drop-quantity ramp.
- **`ItemLevelPerFloor`**, **`StatContributionToItemLevel`**, **`ItemLevelToRequirementRatio`** — change item
  level / required level scaling globally (and see §6 caveats).

### 🔴 Avoid unless you mean it
- **`MaxFloorPressure`** near 1.0 — flattens the affix tier curve so **top tiers become common**. Keep ≤ ~0.85.
- **`MinItemPower`** large jumps (e.g. past ~0.15) — makes floor-1 gear strong and squashes the whole early curve. It's a deliberate early-power/variety dial (default 0.01 = intentionally weak early); nudge it, don't slam it.
- **`GlobalRollScalar`** far from 1.0 — heavily skews every base-stat roll; subtle and easy to misjudge.
- **Per-rarity `StatMultiplier`** much above ~1.5 — compounds with floor + tiers and can break scaling.

### Watch-outs / not-yet-finished
- **Populate the rarity table** (§3) — defaults give a broken uniform distribution.
- **ItemPower plateaus ~0.82** — set stat/affix `Max` as the asymptote, not the literal end-game value (§1).
- **Item level is roll-dependent**, and **RequiredLevel / ItemValue aren't consumed yet** (§6).

---

## 8. Quick recipes

| I want… | Do this |
|---|---|
| Higher floors to drop more items | Raise `GlobalQuantityFactor`. |
| Legendaries to feel rarer at depth | Lower the rarer tiers' `GlobalWeightScalar` (or raise Common's `GlobalBaseRate`). |
| Same-floor weapons to vary less | Raise `MinStatScale` (toward 0.8). |
| Early gear stronger / a bit more varied | Raise `MinItemPower` (couples power + variance; flattens the early curve). |
| Bigger affix "jackpots" early | Raise `BaseTierDecay` (rarer high tiers) — they hit less often but feel special. |
| High-tier affixes more common deep | Lower `AffixTierFloorScale` or raise `MaxFloorPressure` (carefully). |
| Rarity to matter more | Widen `AffixConfig` affix counts between tiers and/or raise `StatMultiplier` slightly. |
| Faster overall power growth | Lower `GlobalItemPowerScalingRate` (🟡 global). |
| Powerful affixes gated to deep floors | Set the affix's `RequiredItemLevel`. |
| A stat to roll its full range at any floor (e.g. flask recharge speed) | Set the stat row's `RollBehavior` to `Full Range`. |
| An item-specific stat pool (health vs mana flask) without new type tags | Add a stat table to the item's DT Equipment Fragment `ItemStatTables`. |

---

*Maintained alongside the loot/combat systems in `UDTLootSubsystem`, `UDTGlobalLootData`,
`UDTCombatSubsystem`, and `UDTCombatGlobalData`. If a number here disagrees with the data asset, the data
asset wins — update this doc.*
