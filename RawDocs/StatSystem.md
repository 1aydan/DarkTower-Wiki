# Stat System

`StatSystem` is a server-authoritative stat backend used for player and world state.

It supports:

- numeric stats and boolean flags
- replication scopes for player stats (private vs public)
- transient/session and persistent save-slot policies
- condition-context helpers for higher systems (like quests)
- **unified subsystem bridge** — one API for both player and world stats

## 1. Core runtime pieces

- `UStatSubsystem` in `Plugins/StatSystem/Source/StatSystem/Public/Subsystems/StatSubsystem.h`
: world-level unified bridge for reading/writing stats and building condition contexts. Pass a `PlayerState*` to target player stats; pass `nullptr` for world stats.
- `UPlayerStatComponent` in `Plugins/StatSystem/Source/StatSystem/Public/Components/PlayerStatComponent.h`
: per-player stats on `ADTPlayerState`.
- `UWorldStatComponent` in `Plugins/StatSystem/Source/StatSystem/Public/Components/WorldStatComponent.h`
: shared/global stats on `ADTGameState`.
- `FStatSaveData` / `FStatSaveEntry` in `Plugins/StatSystem/Source/StatSystem/Public/Types/StatTypes.h`
: save payloads for persistent stats.

## 2. Replication and persistence model

### Replication scope (player stats)

- `EStatReplicationScope::PrivateOwnerOnly`: only owning player sees this replicated value.
- `EStatReplicationScope::PublicAllClients`: all clients see this replicated value.

### Persistence policy

- `EStatPersistencePolicy::TransientSession`: reset between sessions/runs.
- `EStatPersistencePolicy::PersistentSaveSlot`: eligible for save-game persistence.

### Typical ownership in DarkTower

- Player stats live on `ADTPlayerState::PlayerStatComponent`.
- World stats live on `ADTGameState::WorldStatComponent`.

## 3. C++ flow examples

## A. Awarding a player kill stat (unified subsystem API)

```cpp
#include "Subsystems/StatSubsystem.h"

void UMyCombatLogic::OnEnemyKilled(APlayerState* KillerPS)
{
    UStatSubsystem* Stats = GetWorld()->GetSubsystem<UStatSubsystem>();
    if (!Stats) return;

    const FGameplayTag KillsTag = FGameplayTag::RequestGameplayTag(TEXT("Stat.Kills.Total"));
    Stats->ModifyStat(KillsTag, EStatOperation::Add, 1.0, KillerPS,
        EStatReplicationScope::PrivateOwnerOnly,
        EStatPersistencePolicy::PersistentSaveSlot);
}
```

## B. Setting a world-level dungeon flag (unified subsystem API)

```cpp
#include "Subsystems/StatSubsystem.h"

void UMyDungeonFlow::MarkBossDefeated()
{
    UStatSubsystem* Stats = GetWorld()->GetSubsystem<UStatSubsystem>();
    if (!Stats) return;

    // nullptr PlayerState → routes to WorldStatComponent
    const FGameplayTag BossDownTag = FGameplayTag::RequestGameplayTag(TEXT("Stat.Dungeon.BossDefeated"));
    Stats->SetFlagStat(BossDownTag, true);
}
```

## C. Reading a stat (player-first fallback to world)

```cpp
#include "Subsystems/StatSubsystem.h"

double UMyUI::GetKillCount(const APlayerState* PS) const
{
    UStatSubsystem* Stats = GetWorld()->GetSubsystem<UStatSubsystem>();
    double Value = 0.0;
    if (Stats)
    {
        Stats->GetNumericStat(FGameplayTag::RequestGameplayTag(TEXT("Stat.Kills.Total")), Value, PS);
    }
    return Value;
}
```

## D. Direct component access (when you need delegates, save/load, etc.)

```cpp
#include "Subsystems/StatSubsystem.h"
#include "Components/PlayerStatComponent.h"

void UMyWidget::BindToPlayerStats(APlayerState* PS)
{
    UStatSubsystem* Stats = GetWorld()->GetSubsystem<UStatSubsystem>();
    if (UPlayerStatComponent* Comp = Stats ? Stats->GetPlayerStats(PS) : nullptr)
    {
        Comp->OnStatChanged.AddDynamic(this, &UMyWidget::HandleStatChanged);
    }
}
```

## E. Building a condition context for evaluation

```cpp
#include "Subsystems/StatSubsystem.h"
#include "Conditions/StatCondition.h"

bool UMyGateLogic::CanOpenForPlayer(APlayerState* PlayerState) const
{
    UStatSubsystem* Stats = GetWorld()->GetSubsystem<UStatSubsystem>();
    if (!Stats || !RequiredCondition) return false;

    FStatConditionContext Context;
    Stats->BuildContextForPlayer(PlayerState, Context);
    return Stats->EvaluateCondition(RequiredCondition, Context);
}
```

## 4. Blueprint flow examples

## A. Enemy death -> increment player kill count

1. In enemy/server death logic, get killer `PlayerState`.
2. Get `StatSubsystem` via `Get World Subsystem`.
3. Call `Modify Stat`:
: `StatTag = Stat.Kills.Total`
: `Operation = Add`
: `Value = 1`
: `PlayerState = KillerPS`
: `Scope = PrivateOwnerOnly`
: `PersistencePolicy = PersistentSaveSlot`

## B. Room clear -> set shared world flag

1. In dungeon room authority script:
2. Get `StatSubsystem` via `Get World Subsystem`.
3. Call `Set Flag Stat`:
: `StatTag = Stat.Dungeon.RoomCleared`
: `Enabled = true`
: `PlayerState = (leave empty / None for world stats)`

## C. UI reacts to stat updates

1. In widget setup (or controller), bind to `OnStatChanged` on `PlayerStatComponent`.
2. On delegate callback, compare incoming `StatTag`.
3. Update text/progress bars using `NewNumericValue` or `bFlagValue`.

## 5. Save/load in DarkTower

`ADTPlayerState` persists player stats via `GetPersistentSaveData()` / `LoadPersistentSaveData()` in `Source/DarkTower/Private/Core/DTPlayerState.cpp`.

World-stat reset behavior is handled in `ADTGameState::BeginPlay()` through `WorldStatComponent->ResetAllStats()` in `Source/DarkTower/Private/Core/DTGameState.cpp`.

## 6. Recommended usage patterns

- Write stats on authority (server).
- Use gameplay tags consistently under the `Stat.*` namespace.
- Prefer event-driven updates (combat, loot, room-complete events) over polling.
- Keep `PublicAllClients` limited to stats truly needed by everyone.
- Mark only long-lived progression values as `PersistentSaveSlot`.
