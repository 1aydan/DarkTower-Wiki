﻿# Ability Event System

This project uses a **GAS-native modular event system** built around:

- `FGameplayEventData` (engine built-in) as the unified event payload
- `FDTGameplayEffectContext` as the custom effect context carrying project-level `ContextTags`
- nested gameplay tags like `Event.Damage.*` and `Event.Roll.*`
- optional delegates for local binding where convenient

The goal is:

- emit one generic event shape for combat, movement, death, procs, etc.
- let abilities react via **Gameplay Events**
- preserve source / target / causer / hit-result data through GAS
- support broad passive listening with nested tags

---

## 1. Core types

### `FGameplayEventData` (engine)

This is the primary event payload used everywhere. It carries:

- `EventTag` — the gameplay event tag
- `Instigator` — the actor that caused the event
- `Target` — the actor the event happened to
- `EventMagnitude` — numeric value (damage amount, etc.)
- `ContextHandle` — `FDTGameplayEffectContext` with extra project data
- `InstigatorTags` / `TargetTags` — tag snapshots
- `TargetData` — optional target data handle

**Extra project-level data** is accessed through the `ContextHandle`:

- **Causer**: `ContextHandle.Get()->GetEffectCauser()` — the specific actor/weapon that caused the event
- **ContextTags**: `FDTGameplayEffectContext::GetContextTags()` — damage type tags, ability tags, result flags
- **HitResult**: `ContextHandle.Get()->GetHitResult()` — impact location, bone, etc.

Convenience helpers (mirrors Epic's `UAbilitySystemBlueprintLibrary` pattern):
- `UDTAbilitySystemComponent::EffectContextGetContextTags(EffectContext)` — get project-level tags
- `UDTAbilitySystemComponent::EffectContextSetContextTags(EffectContext, Tags)` — set tags
- `UDTAbilitySystemComponent::EffectContextAppendContextTags(EffectContext, Tags)` — append tags
- `UDTAbilitySystemComponent::EffectContextSetAbility(EffectContext, Ability)` — stamp source ability

Engine-provided helpers (on `UAbilitySystemBlueprintLibrary`):
- `EffectContextGetEffectCauser(EffectContext)` — get the causer actor
- `EffectContextGetHitResult(EffectContext)` — get the hit result
- `EffectContextGetInstigatorActor(EffectContext)` — get the instigator

### `FDTGameplayEffectContext`
Defined in `Source/DarkTower/Public/AbilitySystem/Core/DTAbilitySystemTypes.h`

Extends `FGameplayEffectContext` with a `ContextTags` field (`FGameplayTagContainer`).

All `MakeEffectContext()` calls return this type (configured via `UDTAbilitySystemGlobals`).

Key accessors:
- `SetContextTags(Tags)` / `AppendContextTags(Tags)`
- `GetContextTags()` / `HasContextTags()`

The base class already provides: `GetInstigator()`, `GetEffectCauser()`, `GetHitResult()`, `GetAbility()`, `GetSourceObject()`.

### `UDTAbilitySystemGlobals`
Defined in `Source/DarkTower/Public/AbilitySystem/Core/DTAbilitySystemGlobals.h`

`AllocGameplayEffectContext()` is overridden so `MakeEffectContext()` returns `FDTGameplayEffectContext` for this project.

Configured in `Config/DefaultGame.ini` via:

- `AbilitySystemGlobalsClassName=/Script/DarkTower.DTAbilitySystemGlobals`

---

## 2. Event data layout

When an event is sent through `UDTAbilitySystemComponent::SendAbilityEvent(...)`:

- `FGameplayEventData.EventTag` — the event tag
- `FGameplayEventData.Instigator` — source actor
- `FGameplayEventData.Target` — target actor
- `FGameplayEventData.EventMagnitude` — numeric value
- `FGameplayEventData.ContextHandle` — `FDTGameplayEffectContext` containing:
  - `EffectCauser` (= Causer actor)
  - `HitResult`
  - `ContextTags` (project-level tags: damage type, ability tags, result flags)

---

## 3. How to emit events

## A. Emit a generic event from an ASC

Primary API:

- `UDTAbilitySystemComponent::SendAbilityEvent(const FGameplayTag& EventTag, const FGameplayEventData& Payload)`

Use `BuildAbilityEventPayload(...)` to construct the payload from individual fields.

Use this when you already have access to the ASC and want to send a gameplay event that abilities can react to.

### Example

Use a nested tag like:

- `Event.Damage.Dealt`
- `Event.Damage.Taken`
- `Event.Roll.Started`

Then build via `BuildAbilityEventPayload(EventTag, Instigator, Target, Causer, Magnitude, ContextTags, HitResult)`.

## B. Emit from `UDTAbilityCoreComponent`

Primary helper:

- `UDTAbilityCoreComponent::SendAbilityEvent(...)`

This broadcasts:

- local component delegate `OnAbilityEvent`
- ASC delegate `OnAbilityEvent`
- actual GAS gameplay event through the ASC

This is the preferred project-level place to emit actor-centric events like:

- damage taken
- damage dealt
- death
- kill

## C. Set context tags on a gameplay effect context

If the event is caused by a gameplay effect, set context tags on the context before applying the effect:

```cpp
FDTGameplayEffectContext* DTContext = UDTAbilitySystemComponent::GetDTEffectContextMutable(ContextHandle);
if (DTContext)
{
    DTContext->SetContextTags(DamageTags);
}
```

This is the preferred way to preserve provenance during:

- damage effects
- projectile effects
- status effects
- proc effects

### Existing examples

- direct damage helper in `Source/DarkTower/Private/Core/DTBlueprintLibrary.cpp`
- projectile effect application in `Source/DarkTower/Private/World/DTProjectile.cpp`

---

## 4. How to listen for events

## A. In gameplay abilities triggered by event

Use standard GAS event triggering / waiting.

Because tags are nested, an ability listening on:

- `Event.Damage`

can react to:

- `Event.Damage.Dealt`
- `Event.Damage.Dealt.Kill`
- `Event.Damage.Taken`
- `Event.Damage.Taken.Fatal`

The `FGameplayEventData` payload carries everything directly. Access extra data via helpers:

```cpp
// C++
FGameplayTagContainer ContextTags = UDTAbilitySystemComponent::EffectContextGetContextTags(EventData.ContextHandle);
AActor* Causer = EventData.ContextHandle.Get()->GetEffectCauser();
const FHitResult* HitResult = EventData.ContextHandle.Get()->GetHitResult();
```

In Blueprint, break the `Gameplay Event Data` to get the `Context Handle`, then use the `GetContextTags`, `GetEffectCauser`, `GetHitResult` nodes on it — same pattern as Epic's built-in helpers.

## B. Via delegates

You can still bind locally if you do not want to go through ability activation.

### Blueprint-assignable delegates

- `UDTAbilitySystemComponent::OnAbilityEvent`
- `UDTAbilityCoreComponent::OnAbilityEvent`

### C++ convenience delegates

- `UDTAbilityCoreComponent::OnDamageDealt`
- `UDTAbilityCoreComponent::OnKill`

Use delegates for:

- UI
- local FX/SFX
- lightweight observers
- debugging hooks

Use gameplay events for:

- passives
- reactive abilities
- event-triggered ability activation

---

## 5. Recommended tag conventions

Use the existing nested hierarchy in `Source/DarkTower/Public/Core/DTGameplayTags.h`.

Examples:

- `Event.Damage`
- `Event.Damage.Dealt`
- `Event.Damage.Dealt.Kill`
- `Event.Damage.Taken`
- `Event.Damage.Taken.Fatal`
- `Event.Roll`
- `Event.Roll.Started`
- `Event.Roll.Ended`
- `Event.Death`

### Recommendation

Emit the **most specific leaf tag**.

Let listeners subscribe to either:

- a broad parent tag for passive-wide reactions, or
- a specific leaf tag for narrow behavior

Example:

- a passive that cares about all damage can listen on `Event.Damage`
- a passive that only cares about lethal hits can listen on `Event.Damage.Taken.Fatal`

---

## 6. Existing event producers

## Damage path

Current source/target combat event emission lives in:

- `Source/DarkTower/Private/AbilitySystem/Attributes/DTAttributeSet.cpp`
- `Source/DarkTower/Private/AbilitySystem/Core/DTAbilityCoreComponent.cpp`
- `Source/DarkTower/Public/AbilitySystem/Core/DTAbilitySystemComponent.h`
- `Source/DarkTower/Public/AbilitySystem/Core/DTAbilitySystemTypes.h`

Damage now flows through a dedicated server-authoritative combat pipeline:

1. abilities/projectiles build an `FDTDamageContext`
2. `UDTCombatSubsystem::ResolveDamage(...)` snapshots tags, gathers runtime modifiers, and resolves `FDTDamageResult`
3. `Event.Damage.PreResolve` is broadcast to source and target ASCs before modifier resolution
4. source outgoing and target incoming modifiers registered on `UDTAbilitySystemComponent` are evaluated by phase and priority
5. built-in crit and mitigation run inside the centralized pipeline
6. `Event.Damage.Resolved` is broadcast with final damage before health is updated
7. `UDTCombatSubsystem::ApplyDamage(...)` writes the final value into `SetByCaller.Data.Attribute.Damage`
8. the existing damage GE applies the `Damage` meta attribute
9. final health subtraction happens in `UDTAttributeSet::HandleDamageAttribute(...)`
10. existing actor-centric post events continue firing:
    - `Event.Damage.Taken`
    - `Event.Damage.Taken.Fatal`
    - `Event.Damage.Dealt`
    - `Event.Damage.Dealt.Kill`
    - `Event.Death`

See `Docs/CombatPipeline.md` for authoring, registration, affix, and debugging guidance for the centralized combat pipeline.

### Damage payload

`FDTDamageContext` carries:

- `BaseDamage`
- `DamageType`
- `SourceActor` / `TargetActor` / `EffectCauser`
- `ContextTags`
- source / target / ability / weapon tag snapshots
- `HitResult`

`FDTDamageResult` carries:

- `FinalDamage`
- `PreMitigationDamage`
- `MitigatedDamage`
- `ResultTags`
- `AppliedModifiers` (`TArray<FDTCombatModifierRecord>`)
- `ProcRecords`
- cancellation state

Each modifier entry stores:

- `SourceTag`
- `Operation` (`AddFlat`, `IncreasedPct`, `MoreMultiplier`, `LessMultiplier`, `Override`, `Penetration`, `Reduction`)
- `Magnitude`
- `DamageBefore` / `DamageAfter`
- `DescriptionTag`

### Damage lifecycle tags

Pipeline lifecycle tags:

- `Event.Damage.PreResolve`
- `Event.Damage.Resolved`
- `Event.Damage.Post`

Use `Event.Damage.PreResolve` for "inspect before damage is finalized" behavior.
Use `Event.Damage.Resolved` for "react to resolved damage before health changes" behavior.
Use `Event.Damage.Post` for "react after health changes" behavior.

### Modifier registration API

`UDTAbilitySystemComponent` now exposes:

- `RegisterCombatModifierDefinition(Definition, SourceObject, EvaluationLevel)`
- `RegisterCombatModifierSpec(Spec)`
- `UnregisterCombatModifier(Handle)`
- `AppendCombatModifierSpecs(...)` for subsystem-side gathering

Notes:

- modifiers are stored on the ASC and sorted by phase, priority, and stable id during resolution
- source ASC modifiers are treated as **outgoing** modifiers
- target ASC modifiers are treated as **incoming** modifiers
- declarative modifiers use `UDTCombatModifierDefinition`
- unique mechanics use optional `UDTCombatModifierLogic` objects

---

### Modifier conditions

Modifier conditions are data-driven by default:

- `UDTCombatModifierDefinition::ContextTagQuery`
- `SourceTagQuery`
- `TargetTagQuery`
- `AbilityTagQuery`
- `WeaponTagQuery`

If a condition needs code, assign a `UDTCombatModifierLogic` object. Current built-in examples:

- `UDTCombatModifierLogic_Backstab` checks whether the source is inside the target's rear cone.
- `UDTCombatModifierLogic_TargetHealthRatio` checks the target's current health ratio.

Example: backstab passive (+30% more damage when attacking from behind)

```cpp
FDTCombatModifierSpec Spec;
Spec.Phase = EDTCombatModifierPhase::Outgoing;
Spec.Operation = EDTCombatModifierOp::MoreMultiplier;
Spec.Magnitude = 1.30f;
Spec.SourceTag = TAG_PASSIVE_BACKSTAB;
Spec.bAffectsOutgoingDamage = true;
Spec.bAffectsIncomingDamage = false;

BackstabHandle = ASC->RegisterCombatModifierSpec(Spec);

// OnRemoveAbility
ASC->UnregisterCombatModifier(BackstabHandle);
```

For designer-authored modifiers, prefer `UDTCombatModifierDefinition` and call:

```cpp
FDTCombatModifierHandle Handle = ASC->RegisterCombatModifierDefinition(Definition, SourceObject, EvaluationLevel);
```

For ability-specific bonuses, stamp a context tag when building `FDTDamageContext` or the effect context and gate the modifier with `ContextTagQuery`.

## Roll path

Current roll emission lives in:

- `Source/DarkTower/Private/AbilitySystem/Abilities/DTGameplayAbility_Dodge.cpp`

It emits:

- `Event.Roll.Started`
- `Event.Roll.Ended`

---

## 7. Recommended usage patterns

## Pattern 1: ability-triggered passive

Best for:

- on damage dealt/taken passives
- on roll passives
- on kill passives

Do:

1. listen on a nested gameplay tag
2. extract `FAbilityEventData`
3. branch using:
   - `Magnitude`
   - `ContextTags`
   - `bWasCritical`
   - `bWasFatal`
   - `bWasKill`
   - `Instigator` / `Target` / `Causer`

## Pattern 2: effect-driven combat logic

Best for:

- damage executions
- proc chains
- projectiles
- effects that must preserve cause/provenance

Do:

1. build `FGameplayEffectContextHandle`
2. stamp `FAbilityEventData` onto it
3. apply the effect
4. read it back from the context where needed

## Pattern 3: local observers

Best for:

- widgets
- logging
- temporary gameplay hooks
- animation/FX side reactions

Do:

- bind to `OnAbilityEvent` / `OnDamageDealt` / `OnKill`

---

## Pattern 4: C++ passive ability base class

Best for:

- persistent stat buffs (apply GEs on grant, remove on end)
- event-reactive passives (on damage, on kill, on crit)
- passives that need clean lifecycle (death → respawn)

### Class

`UDTGameplayAbility_Passive` in `Source/DarkTower/Public/AbilitySystem/Abilities/DTGameplayAbility_Passive.h`

### Key properties

| Property | Type | Description |
|---|---|---|
| `PassiveEffects` | `TArray<TSubclassOf<UGameplayEffect>>` | GEs applied to owner on activate, removed on end |
| `ListenEventTags` | `FGameplayTagContainer` | Event tags to listen for (nested matching) |
| `bReactivateOnRespawn` | `bool` (default `true`) | Re-activate after death/respawn cycle |

### Defaults set by the constructor

- `bActivateOnGranted = true`
- `ActivationGroup = Independent`
- `NetExecutionPolicy = ServerOnly`
- `ReplicationPolicy = ReplicateNo`
- `AbilityTags` includes `Ability.Type.Passive`
- `ActivationBlockedTags` includes `Status.Dead` (inherited from base)

### Blueprint hooks

- `OnPassiveActivated` — called after effects are applied
- `OnPassiveDeactivated` — called before effects are removed
- `OnPassiveEventReceived(EventTag, FGameplayEventData)` — called for matching events via the standard GAS event pipeline

### Event listening

Event listening uses the GAS-native `UAbilityTask_WaitGameplayEvent` tasks under the hood.
One task per `ListenEventTags` entry is created when the passive activates.
Tasks are automatically cleaned up when the ability ends.

The `OnPassiveEventReceived` callback receives the standard `FGameplayEventData` payload.
Use `TryExtractAbilityEventData(...)` to extract the project-level `FAbilityEventData` from it.

### Lifecycle

1. Ability is granted → `OnGiveAbility` → `bActivateOnGranted` triggers activation
2. `ActivateAbility` → applies `PassiveEffects`, binds to `OnAbilityEvent`, calls `OnPassiveActivated`
3. Runs indefinitely until removed or cancelled
4. On death (`Status.Dead` blocks activation) → `EndAbility` → removes effects, unbinds events, calls `OnPassiveDeactivated`
5. On respawn (`OnAvatarSet`) → re-activates if `bReactivateOnRespawn` is true
6. On ability removal → `OnRemoveAbility` safety net force-ends if still active

### Example: "+15% physical damage" passive

Recommended pattern for the new damage pipeline:

#### C++

1. Override `OnGiveAbility(...)`
2. Resolve `UDTAbilitySystemComponent* ASC = GetDTAbilitySystemComponentFromActorInfo()`
3. Register an outgoing `FDTCombatModifierSpec` and cache the returned `FDTCombatModifierHandle`
4. Gate the modifier with context/source/target tag queries on a `UDTCombatModifierDefinition`, or stamp matching context tags from the ability
5. Override `OnRemoveAbility(...)` and call `ASC->UnregisterCombatModifier(CachedHandle)`

#### Blueprint

1. Use a child of `UDTGameplayAbility_Passive`
2. In `OnAbilityAdded`, get the ASC and call `RegisterCombatModifierDefinition`
3. Set:
   - `SourceTag = Ability.Passive.YourPassiveName` (or another identifying tag)
   - `Operation = MoreMultiplier`
   - `Magnitude = 1.15`
   - `DescriptionTag = Ability.Passive.YourPassiveName.PhysicalBonus`
   - `bAffectsOutgoingDamage = true`
   - `bAffectsIncomingDamage = false`
4. Store the returned handle on the ability instance
5. In `OnAbilityRemoved`, call `UnregisterCombatModifier` with the stored handle

This pattern is better than applying a raw `PhysicalDamage` stat buff when the bonus is conditional or needs to layer only during a specific damage pass.

---

### Example: conditional / one-off damage bonuses

For bonuses that only apply in specific circumstances there are two approaches:

#### 1. Spatial / attribute conditions — use custom logic

Create a `UDTCombatModifierDefinition` and assign one of the custom logic objects:

- `UDTCombatModifierLogic_Backstab`
- `UDTCombatModifierLogic_TargetHealthRatio`

#### 2. Ability-specific / contextual bonuses — stamp a tag, use a tag query

When the condition is "this ability performed action X" (e.g. a lunge, a charged shot, an aerial attack):

1. Add a `Damage.Context.*` tag to the GE context in the ability before damage is applied
2. Gate the modifier with `UDTCombatModifierDefinition::ContextTagQuery`

This keeps the condition trivial (tag presence check) and lets the ability decide when to activate it, making it easy to compose multiple one-off bonuses cleanly.

### Example: "Heal 5% on critical hit" passive

1. Create a Blueprint child of `UDTGameplayAbility_Passive`
2. Set `ListenEventTags` to `Event.Damage.Dealt`
3. Override `OnPassiveEventReceived`
4. Call `GetAbilityEventDataFromGameplayEvent(EventData, OutAbilityEventData)`
5. Check `OutAbilityEventData.bWasCritical`
6. If true, apply a healing GE to self

---

## 8. Blueprint guidance

Preferred Blueprint extraction helpers:

- `GetAbilityEventDataFromGameplayEvent(...)`
- `GetAbilityEventDataFromTargetData(...)`
- `GetAbilityEventDataFromEffectContext(...)`

Blueprints should treat target data and effect context as the only supported rich payload carriers.

---

## 9. Do we still need the old payload object?

No.

The old `UDTAbilityEventPayloadObject` compatibility layer has been removed.

The supported transport is now:

- `FDTAbilityEventTargetData`
- `FDTGameplayEffectContext`
- base `FGameplayEventData` fields for lightweight fallback data only

That means there is no longer any supported path based on:

- `FGameplayEventData.OptionalObject`
- `GetAbilityEventPayloadObject(...)`

If you need the rich event payload, always extract it through:

- target data
- effect context
- or the shared helper wrappers that already try both in the right order

---

## 10. Summary

### Use this for new work

- emit events with `SendAbilityEvent(...)`
- transport payload with target data / effect context
- listen via nested gameplay tags
- extract via `TryExtractAbilityEventData(...)` or Blueprint helper wrappers
- build passives by subclassing `UDTGameplayAbility_Passive`
- use `RegisterCombatModifierDefinition(...)` / `UnregisterCombatModifier(...)` for passive-driven damage bonuses and reductions

### Use delegates for

- local/UI observers
- convenience hooks
- debugging

### Avoid

- trying to read event payloads from `OptionalObject`
- introducing UObject wrappers for gameplay-event payload transport
- scattering final damage math across individual passive abilities

---

## 11. Suggested next cleanup

Possible next follow-up items:

- add one small automated test for `TryExtractAbilityEventData(...)`
- add a convenience BP node for reading common booleans/tags from `FAbilityEventData`
- add broader automated tests for `UDTCombatSubsystem::ResolveDamage(...)` and modifier registration ordering
- reparent `GA_Passive_Base` Blueprint to `UDTGameplayAbility_Passive`
