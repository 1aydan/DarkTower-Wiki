# Skill Tree Tooltip Authoring

This document shows the expected designer setup for skill tree node tooltip descriptions that use authored placeholders and automatic current-to-next upgrade previews.

## Example Setup

Example authored sentence:

`Lashes a wave of fire that deals {DamagePct} of melee damage.`

Recommended example node data in `UDTSkillTreeNodeDefinition`:

### Skill Tree Node | Meta

- `NodeName`: `Flame Lash`
- `Description`: `Lashes a wave of fire that deals {DamagePct} of melee damage.`

### Skill Tree Node | Progression

- `MaxRank`: `5`

### Skill Tree Node | Tooltip

Add one `TooltipValues` entry:

- `Placeholder`: `DamagePct`
- `DisplayLabel`: `Melee Damage`
- `Operation`: `Multiply`
- `ValueSource`: `Range`
- `MinValue`: `1.20`
- `MaxValue`: `2.00`
- `bShowSign`: `false`
- `DecimalPlaces`: `0`

## What This Displays

With the current formatter, `Multiply` values are displayed as delta percentages using this rule:

`(RawValue - 1.0) * 100`

That means the example above displays like this:

- Rank 0 preview: `Lashes a wave of fire that deals 20% of melee damage.`
- Rank 1 current: `Lashes a wave of fire that deals 20% of melee damage.`
- Rank 1 primary comparison: `Lashes a wave of fire that deals 20% -> 40% of melee damage.`
- Rank 5 max: `Lashes a wave of fire that deals 100% of melee damage.`

Because `MaxRank` is `5`, the values lerp evenly across ranks:

- Rank 1: `20%`
- Rank 2: `40%`
- Rank 3: `60%`
- Rank 4: `80%`
- Rank 5: `100%`

## Important Authoring Notes

- Designers only author one placeholder token in the description, for example `{DamagePct}`.
- The tooltip system now builds the default upgrade preview automatically as `CurrentValue -> NextValue` when the node already has at least one rank and another rank is available.
- If `Placeholder` is left empty, the formatter falls back to `Value_0`, `Value_1`, and so on.
- `DisplayLabel` is optional and is intended for tooltip side rows or per-value displays.
- `ValueSource` controls whether the tooltip value uses a plain min/max range or a GAS-style `FScalableFloat`.

## Curve Table Setup

If you want to drive the tooltip value directly from a curve table row, switch the tooltip value source to scalable float:

- `Placeholder`: `DamagePct`
- `DisplayLabel`: `Melee Damage`
- `Operation`: `Multiply`
- `ValueSource`: `Scalable Float`
- `ScalableValue.Value`: optional fallback constant
- `ScalableValue.Curve.RowName`: your row name, for example `FlameLashDamagePct`
- `ScalableValue.Curve.CurveTable`: your skill tooltip curve table asset

When `ValueSource` is `Scalable Float`, skill node tooltip evaluation uses the node rank with GAS-style aggregation semantics based on `Operation`.

- `Add`: sums each invested rank's value
- `Multiply`: adds each invested rank's multiplier delta on top of `1.0`
- `Override`: uses the latest rank's value

For example, if the curve table row returns a flat `10` at every level and `Operation` is `Add`:

- Rank 1 total: `10`
- Rank 2 total: `20`
- Rank 3 total: `30`
- Rank 4 total: `40`
- Rank 5 total: `50`

If instead the curve table row returns:

- Level 1: `1.20`
- Level 2: `1.40`
- Level 3: `1.60`
- Level 4: `1.80`
- Level 5: `2.00`

Then the primary tooltip preview becomes:

- Rank 1 to 2: `Lashes a wave of fire that deals 20% -> 40% of melee damage.`
- Rank 5: `Lashes a wave of fire that deals 100% of melee damage.`

## If You Want `120% -> 140%` Instead

The current `Multiply` formatting is meant for delta-style percentages like `20%`, not total multiplier displays like `120%`.

So for the exact phrase `deals X% of melee damage`:

- Current behavior supports `20% -> 40%` style output.
- If design wants `120% -> 140%` style output, the formatter needs an additional display mode for total multiplier percentages.

## Quick Reference

For the exact example discussed, use:

- `Description`: `Lashes a wave of fire that deals {DamagePct} of melee damage.`
- `TooltipValues[0].Placeholder`: `DamagePct`
- `TooltipValues[0].Operation`: `Multiply`
- `TooltipValues[0].MinValue`: `1.20`
- `TooltipValues[0].MaxValue`: `2.00`
