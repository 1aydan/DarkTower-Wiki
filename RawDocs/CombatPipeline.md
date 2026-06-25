# Combat Pipeline

DarkTower damage is resolved through a centralized, server-authoritative combat pipeline. Abilities and projectiles submit explicit damage contexts; the combat subsystem gathers modifiers, resolves final damage, emits ability events, and then applies the existing GAS damage Gameplay Effect.

Use this system for new hit damage, conditional damage scaling, item affix damage bonuses, passive damage modifiers, support-style modifiers, and custom mechanics such as backstab or execute effects.

---

## Core Flow

Runtime damage flow:

1. Caller builds an `FDTDamageContext`.
2. `UDTCombatSubsystem::CalculateDamage(...)` snapshots tags, gathers modifiers, applies crit/mitigation/final math, and produces an `FDTDamageResult`.
3. `Event.Damage.PreResolve` is emitted before modifier resolution.
4. `Event.Damage.Resolved` is emitted after final damage is known, before health changes.
5. `UDTCombatSubsystem::ApplyDamage(...)` writes final damage into `SetByCaller.Data.Attribute.Damage`.
6. Existing `GE_Damage_Base` / `UDamageExecutionCalculation` / `UDTAttributeSet::HandleDamageAttribute(...)` pass the resolved damage into the `Damage` meta attribute, apply health, and emit the existing post-damage events.

For common Blueprint damage, call:

- `Deal Damage To Target`

For richer Blueprint damage, use Unreal's built-in `Make FDTDamageContext` struct node and pass it to:

- `Deal Damage With Context`

---

## Key Types

### `FDTDamageContext`

The request object. It contains:

- `SourceActor`
- `TargetActor`
- `EffectCauser`
- `SourceObject`
- `BaseDamage`
- `DamageType`
- `ContextTags`
- `AbilityTags`
- `WeaponTags`
- `HitResult`
- `bSkipBuiltInMitigation`

Most callers only need source, target, base damage, damage type, causer, hit result, and context tags. Source and target tag queries are evaluated from the source and target actors' current Ability System Component tags during resolution, not from caller-supplied context fields.

### `FDTDamageResult`

The resolved output. It contains:

- `BaseDamage`
- `PreMitigationDamage`
- `MitigatedDamage`
- `FinalDamage`
- `ResultTags`
- `AppliedModifiers`
- `ProcRecords`
- cancellation state

`ResultTags` are appended back into `FDTGameplayEffectContext`. The tag that marks subsystem-resolved damage is:

```cpp
DTGameplayTags::TAG_EFFECT_RESULT_COMBAT_RESOLVED
```

`UDamageExecutionCalculation` is now a pass-through for `SetByCaller.Data.Attribute.Damage`; crit, mitigation, and combat modifiers are expected to have already run in `UDTCombatSubsystem`.

Global combat tuning values live in `UDTCombatGlobalData`, referenced from `UDTGlobalData::CombatGlobalData`.

---

## Damage Events

The combat pipeline works with the existing ability event system.

New lifecycle events:

- `Event.Damage.PreResolve`
- `Event.Damage.Resolved`

Existing post-health events still fire:

- `Event.Damage.Taken`
- `Event.Damage.Taken.Fatal`
- `Event.Damage.Dealt`
- `Event.Damage.Dealt.Kill`
- `Event.Death`

Use `PreResolve` and `Resolved` for combat-pipeline observers and debugging. Use the existing dealt/taken/kill events for passives that react after health has changed.

---

## Authoring Declarative Modifiers

Create a `UDTCombatModifierDefinition` for designer-authored modifiers.

Important fields:

- `SourceTag`: identifies where the modifier came from.
- `DescriptionTag`: optional UI/debug identifier.
- `When To Apply`: which step of damage calculation the modifier runs in.
- `How To Change Damage`: how it changes the current damage value.
- `Magnitude`: scalable value.
- `Priority`: higher priority sorts first within a phase.
- `bAffectsOutgoingDamage`: source-side modifier.
- `bAffectsIncomingDamage`: target-side modifier.
- `ContextTagQuery`, `SourceTagQuery`, `TargetTagQuery`, `AbilityTagQuery`, `WeaponTagQuery`: declarative gates.
- `CustomLogic`: optional code hook for mechanics that cannot be expressed as tag queries.
- `AffixMagnitudeModifierID`: optional link to a rolled affix value.

### When To Apply

Modifier phases resolve in this order:

1. `Start Of Damage` (`Base`): changes the starting damage amount.
2. `Attacker Bonuses` (`Outgoing`): source-side bonuses before crit and defenses.
3. `Critical Hit` (`Crit`): critical-hit calculation and crit-specific changes.
4. `Target Reactions` (`Incoming`): target-owned reactions before armor and resistance.
5. `Armor And Resistance` (`Mitigation`): armor, resistance, penetration, and damage reduction.
6. `Final Damage` (`Final`): final adjustments before rounding.
7. `After Damage Effects` (`Proc`): post-resolution proc records or secondary effects.

Within each phase, modifiers sort by:

1. phase
2. descending priority
3. stable registration id

### How To Change Damage

- `Add Damage` (`AddFlat`): adds flat damage.
- `Add Percent Damage` (`IncreasedPct`): additive percentage bucket, flushed once per phase. Magnitude `50` means +50%.
- `Multiply Damage Up` (`MoreMultiplier`): multiplicative scaling. Magnitude `1.30` means 30% more damage.
- `Multiply Damage Down` (`LessMultiplier`): multiplicative reduction clamped to `0..1`. Magnitude `0.70` means 30% less damage.
- `Set Damage` (`Override`): sets damage directly.
- `Ignore Armor` (`Penetration`): contributes to armor penetration during mitigation. Magnitude `0.10` means ignore 10% of armor.
- `Add Damage Reduction` (`Reduction`): contributes to extra resistance during mitigation. Magnitude `0.10` means 10% less damage taken.

---

## Registering Modifiers In C++

Use the ASC as the runtime modifier owner.

```cpp
FDTCombatModifierSpec Spec;
Spec.Phase = EDTCombatModifierPhase::Outgoing;
Spec.Operation = EDTCombatModifierOp::MoreMultiplier;
Spec.Magnitude = 1.30f;
Spec.SourceTag = MyBackstabTag;
Spec.DescriptionTag = MyBackstabDescriptionTag;
Spec.Priority = 0;
Spec.bAffectsOutgoingDamage = true;
Spec.bAffectsIncomingDamage = false;

FDTCombatModifierHandle Handle = ASC->RegisterCombatModifierSpec(Spec);
```

Remove it when the owner is removed, unequipped, or deactivated:

```cpp
ASC->UnregisterCombatModifier(Handle);
```

For data assets:

```cpp
FDTCombatModifierHandle Handle =
    ASC->RegisterCombatModifierDefinition(ModifierDefinition, SourceObject, EvaluationLevel);
```

---

## Blueprint Workflows

### Blueprint Damage

Use this flow for simple single-target Blueprint damage:

1. provide the source actor, target actor, base damage, and damage type
2. optionally provide effect causer, context tags, hit result, damage effect, or effect context
3. `Deal Damage To Target`

`Deal Damage To Target` builds an `FDTDamageContext` and routes through the same combat pipeline as `Deal Damage With Context`.

Use this flow when a Blueprint needs full context control:

1. Unreal's built-in `Make FDTDamageContext` struct node
2. fill the source, target, base damage, damage type, and any optional tags
3. `Deal Damage With Context`

`FDTDamageContext` exposes:

- `SourceActor`
- `TargetActor`
- `BaseDamage`
- `DamageType`
- `EffectCauser`
- `SourceObject`
- `HitResult`
- `ContextTags`
- `AbilityTags`
- `WeaponTags`
- `bSkipBuiltInMitigation`

`Deal Damage With Context` resolves the context through `UDTCombatSubsystem`, applies the existing damage Gameplay Effect, and returns both:

- `OutEffectHandle`: the applied Gameplay Effect handle
- `OutDamageResult`: the resolved combat result, including final damage, result tags, applied modifiers, proc records, and cancellation state

Blueprint graphs should use `Deal Damage To Target` for simple hits, or build `FDTDamageContext` directly and call `Deal Damage With Context` when they need ability tags, weapon tags, source object, or mitigation overrides.

### Blueprint Modifier Registration

Blueprint passives can register data-asset modifiers with:

- `RegisterCombatModifierDefinition`
- `UnregisterCombatModifier`

Store the returned `FDTCombatModifierHandle` on the passive or owning object and unregister it when the passive ends, the buff expires, or the item is removed.

For item affixes, designers usually do not need Blueprint registration. Put modifier definitions in `UDTAffixDefinition::CombatModifiers`; equipment application registers and unregisters them automatically.

---

## Item Affixes

`UDTAffixDefinition` has an optional `CombatModifiers` array.

Use this for affixes that affect damage calculation but should not be permanent attributes.

Examples:

- `+50% increased damage with daggers`
- `30% more damage against poisoned targets`
- `fire damage penetrates 10% resistance`
- `+25% damage when hitting from behind`

Existing fields still work:

- `AffixGameplayEffect` remains for attributes such as max health, crit chance, armor, or resistance.
- `AffixAbilitySet` remains for granting abilities.
- `CombatModifiers` are registered when the equipment stats are applied and unregistered when the item is unequipped or deactivated.

If an affix roll should drive the combat modifier magnitude:

1. Add an entry to `UDTAffixDefinition::StatModifiers`.
2. Set its `ModifierID`, for example `DaggerDamageBonus`.
3. Set `UDTCombatModifierDefinition::AffixMagnitudeModifierID` to the same name.

At equip time, the rolled affix value overrides the modifier definition's default `Magnitude`.

---

## Common Examples

### Dagger Damage Bonus

Goal: 50% increased damage when using dagger-tagged attacks.

Definition setup:

- `When To Apply`: `Attacker Bonuses`
- `How To Change Damage`: `Add Percent Damage`
- `Magnitude`: `50`
- `bAffectsOutgoingDamage`: true
- `bAffectsIncomingDamage`: false
- `WeaponTagQuery`: requires the dagger weapon tag

Caller requirement:

- The ability or weapon code must add the dagger tag to `FDTDamageContext.WeaponTags`, or add an equivalent context tag used by the modifier query.

### Backstab

Goal: 30% more damage when source is behind target.

Definition setup:

- `When To Apply`: `Attacker Bonuses`
- `How To Change Damage`: `Multiply Damage Up`
- `Magnitude`: `1.30`
- `CustomLogic`: `UDTCombatModifierLogic_Backstab`
- `bAffectsOutgoingDamage`: true

`UDTCombatModifierLogic_Backstab` checks the source actor against the target actor's rear cone.

### Execute

Goal: 50% more damage when target is below 20% health.

Definition setup:

- `When To Apply`: `Attacker Bonuses`
- `How To Change Damage`: `Multiply Damage Up`
- `Magnitude`: `1.50`
- `CustomLogic`: `UDTCombatModifierLogic_TargetHealthRatio`
- `MaxRatio`: `0.20`
- `bAffectsOutgoingDamage`: true

### Fire Penetration

Goal: fire hits penetrate mitigation.

Definition setup:

- `When To Apply`: `Armor And Resistance`
- `How To Change Damage`: `Ignore Armor`
- `Magnitude`: `0.10`
- `ContextTagQuery`: requires the fire damage type tag
- `bAffectsOutgoingDamage`: true

### Ability-Specific Bonus

Goal: one ability deals bonus damage only on a charged hit.

Ability side:

```cpp
DamageContext.ContextTags.AddTag(TAG_DAMAGE_CONTEXT_CHARGED);
```

Modifier definition:

- `ContextTagQuery`: requires `Damage.Context.Charged`
- phase/op/magnitude as needed

This is preferred over adding special-case condition code to the ability.

---

## Built-In Crit And Mitigation

The pipeline currently handles:

- crits through `CritChance` and `CritDamage`
- armor mitigation
- generic `DamageResistance`
- physical penetration through `PhysicalPenetration`
- true damage bypass through `Damage.Type.True`

The armor formula is:

```cpp
ArmorReduction = Armor / (Armor + ArmorMitigationFactor * Damage)
Damage = Damage * (1.0f - ArmorReduction) * (1.0f - DamageResistance)
```

`ArmorMitigationFactor` is shown to designers as `Armor Damage Scale` on `Combat Tuning Data`. Higher values make armor less effective; lower values make armor stronger. If no combat global data asset is assigned yet, the subsystem falls back to the class default value.

Crit eligibility is tag-driven. If the damage GE has `Effect.Condition.CanCrit` as an asset tag, `ApplyDamage` merges that tag into the context before resolving. Direct `CalculateDamage` callers can opt in by adding `Effect.Condition.CanCrit` to `FDTDamageContext::ContextTags`.

---

## Writing New Damage Callers

For common target damage, use:

```text
Deal Damage To Target
```

Use the full context flow when a Blueprint ability needs to provide advanced context:

```text
Make FDTDamageContext -> Deal Damage With Context
```

Use the full context flow when a Blueprint ability needs to provide:

- `ContextTags`
- `AbilityTags`
- `WeaponTags`
- `bSkipBuiltInMitigation`

Blueprint examples:

- a dagger attack should pass a dagger tag through `WeaponTags`
- a charged attack should pass `Damage.Context.Charged` through `ContextTags`
- a spell should pass spell/source tags through `AbilityTags` or `ContextTags`

Use `UDTCombatSubsystem` directly in C++ when a caller needs richer context:

```cpp
UDTCombatSubsystem* CombatSubsystem = World->GetSubsystem<UDTCombatSubsystem>();

FDTDamageContext Context;
Context.SourceActor = SourceActor;
Context.TargetActor = TargetActor;
Context.EffectCauser = Projectile;
Context.BaseDamage = 50.0f;
Context.DamageType = DTGameplayTags::TAG_DAMAGE_TYPE_PHYSICAL;
Context.ContextTags.AddTag(MyContextTag);
Context.WeaponTags.AddTag(MyWeaponTag);
Context.HitResult = Hit;

FActiveGameplayEffectHandle Handle;
FDTDamageResult Result;
CombatSubsystem->ApplyDamage(Context, DamageEffectClass, Handle, &Result);
```

Only call this on authority. The subsystem rejects non-authority source actors.

---

## Debugging

Use:

- `LogDTCombat`
- `FDTDamageResult::AppliedModifiers`
- `FDTDamageResult::ResultTags`
- `Event.Damage.PreResolve`
- `Event.Damage.Resolved`

For a breakpoint-friendly path, start in:

- `UDTCombatSubsystem::ApplyDamage`
- `UDTCombatSubsystem::CalculateDamage`
- `UDTCombatSubsystem::ApplyModifierPhase`
- `UDamageExecutionCalculation::Execute_Implementation`
- `UDTAttributeSet::HandleDamageAttribute`

---

## Pitfalls

- Do not write final damage directly to `SetByCaller.Data.Attribute.Damage` for new code. Go through the combat subsystem.
- Do not apply `GE_Damage_Base` directly for new damage. Route damage through `UDTCombatSubsystem` so crit, mitigation, modifiers, and result tags are resolved before the damage Gameplay Effect is applied.
- Do not use combat modifiers for persistent attributes such as max health or armor. Use regular Gameplay Effects for those.
- Remove registered modifier handles when the source item/passive/buff is removed.
- Prefer tag queries for common conditions and custom logic only for conditions that truly need code.
- Keep modifiers data-driven when possible; avoid adding ability-local final damage math.

---

## Verification

Current compile check:

```text
Build.bat DarkTower Win64 Development -Project=DarkTower.uproject -WaitMutex -NoHotReload
```

Known limitation:

- The full editor target can be blocked if Live Coding is active in the running editor. Close the editor or disable Live Coding before compiling `DarkTowerEditor`.
