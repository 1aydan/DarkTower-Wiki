# Quest System

`QuestSystem` is a data-driven, server-authoritative quest runtime built on top of `StatSystem` contexts.

It supports:

- player-scoped and shared-scoped quests
- data-asset definitions with instanced conditions/objectives/rewards
- stat-driven objective progression (via `StatSystem` updates)
- per-scope save/load (`FQuestSaveData`)

## 1. Core runtime pieces

- `UQuestSubsystem` in `Plugins/QuestSystem/Source/QuestSystem/Public/Subsystems/QuestSubsystem.h`
: quest lifecycle API (`Accept`, `Complete`, `Fail`, `TurnIn`).
- `UQuestDefinition` in `Plugins/QuestSystem/Source/QuestSystem/Public/Data/QuestDefinition.h`
: data asset with conditions, objectives, and rewards.
- `UQuestObjective` and built-ins in `Plugins/QuestSystem/Source/QuestSystem/Public/Objectives/QuestObjective.h`
: objective behavior (`Counter`, `StatThreshold`).
- `UQuestCondition` and built-ins in `Plugins/QuestSystem/Source/QuestSystem/Public/Conditions/QuestCondition.h`
: activation/completion/fail checks.
- `UQuestReward` and `UQuestReward_StatMutation` in `Plugins/QuestSystem/Source/QuestSystem/Public/Rewards/QuestReward.h`.
- `FQuestSaveEntry` and related enums in `Plugins/QuestSystem/Source/QuestSystem/Public/Types/QuestTypes.h`.

## 2. Scope and persistence

- `EQuestScope::Player`: per-player quests (saved in DarkTower player save flow).
- `EQuestScope::Shared`: session-level shared quests.

Runtime detail:

- shared quests are forced to `TransientSession` on registration in `UQuestSubsystem::RegisterQuestDefinition`.

DarkTower integration:

- player quest save/load is wired in `Source/DarkTower/Private/Core/DTPlayerState.cpp`.
- shared transient reset is done at game-state start via `ADTGameState::ResetTransientSharedQuests()` in `Source/DarkTower/Private/Core/DTGameState.cpp`.

## 3. Quest lifecycle

1. Register a definition: `RegisterQuestDefinition(UQuestDefinition*)`.
2. Start a quest:
: player scope via `AcceptQuest(QuestTag, PlayerState)`
: shared scope via `StartSharedQuest(QuestTag, bBypassConditions)`
3. Update relevant player/world stats through `StatSystem`.
4. Subsystem updates objective progress and checks fail/completion.
5. Rewards with `GrantMode == OnCompletion` are granted on completion.
6. For `GrantMode == OnTurnIn`, call `TurnInQuest(QuestTag, PlayerState)` after completion.

Query helpers:

- `GetActiveQuests(PlayerState)` — all active quest tags (player + shared).
- `GetQuestsInState(State, PlayerState)` — all quests in a given state.
- `GetAllTrackedQuests(PlayerState)` — full save entries.
- `GetObjectiveProgress(QuestTag, ObjectiveId, OutProgress, PlayerState)` — single objective.

Delegates for UI/feedback:

- `OnQuestStateChanged`
- `OnQuestObjectiveProgress`

## 4. C++ flow examples

## A. Player quest from NPC interaction

```cpp
#include "Subsystems/QuestSubsystem.h"
#include "GameFramework/PlayerState.h"

void UMyNpcInteractLogic::OfferQuest(APlayerState* InteractingPlayer)
{
    if (!InteractingPlayer)
    {
        return;
    }

    UWorld* World = InteractingPlayer->GetWorld();
    UQuestSubsystem* QuestSubsystem = World ? World->GetSubsystem<UQuestSubsystem>() : nullptr;
    if (!QuestSubsystem)
    {
        return;
    }

    const FGameplayTag QuestTag = FGameplayTag::RequestGameplayTag(TEXT("Quest.Main.FindRelic"));
    QuestSubsystem->AcceptQuest(QuestTag, InteractingPlayer);
}
```

## B. Progress objective from combat stat update

```cpp
#include "Subsystems/QuestSubsystem.h"
#include "Subsystems/StatSubsystem.h"

void UMyCombatQuestBridge::NotifyEnemyKilled(APlayerState* KillerPS, AActor* Victim)
{
    static_cast<void>(Victim);

    UWorld* World = KillerPS ? KillerPS->GetWorld() : nullptr;
    UStatSubsystem* StatSubsystem = World ? World->GetSubsystem<UStatSubsystem>() : nullptr;
    if (!StatSubsystem)
    {
        return;
    }

    const FGameplayTag KillStatTag = FGameplayTag::RequestGameplayTag(TEXT("Stat.Enemies.Killed"));
    StatSubsystem->AddPlayerStat(KillerPS, KillStatTag, 1.0);
}
```

## C. Shared quest progression from world stat

```cpp
#include "Core/DTGameState.h"
#include "Subsystems/StatSubsystem.h"

void UMyRoomFlow::StartSurviveEvent(ADTGameState* GS)
{
    if (!GS)
    {
        return;
    }

    const FGameplayTag SharedQuestTag = FGameplayTag::RequestGameplayTag(TEXT("Quest.Shared.Room.SurviveWave"));
    GS->StartSharedQuest(SharedQuestTag, true);
}

void UMyRoomFlow::TickSurviveProgress(ADTGameState* GS, int32 SurvivePoints)
{
    if (!GS)
    {
        return;
    }

    UWorld* World = GS->GetWorld();
    UStatSubsystem* StatSubsystem = World ? World->GetSubsystem<UStatSubsystem>() : nullptr;
    if (!StatSubsystem)
    {
        return;
    }

    const FGameplayTag SurviveStatTag = FGameplayTag::RequestGameplayTag(TEXT("Stat.World.Room.SurvivePoints"));
    StatSubsystem->AddWorldStat(SurviveStatTag, static_cast<double>(SurvivePoints));
}

void UMyRoomFlow::EndSurviveEvent(ADTGameState* GS, bool bSucceeded)
{
    if (!GS)
    {
        return;
    }

    const FGameplayTag SharedQuestTag = FGameplayTag::RequestGameplayTag(TEXT("Quest.Shared.Room.SurviveWave"));
    if (bSucceeded)
    {
        GS->CompleteSharedQuest(SharedQuestTag, true);
    }
    else
    {
        GS->FailSharedQuest(SharedQuestTag);
    }
}
```

## 5. Blueprint flow examples

## A. Personal quest: kill 10 enemies

Authoring:

1. Create `QuestDefinition` data asset.
2. Set:
: `QuestTag = Quest.Side.Kill10`
: `Scope = Player`
: `PersistencePolicy = PersistentSaveSlot`
3. Add base objective and add `Quest Stat Threshold Condition` in `CompletionConditions`:
: `StatTag = Stat.Enemies.Killed`
: `MinValue = 10`
: `Source = PlayerOnly` (or preferred source)

Runtime flow:

1. NPC interaction calls `Accept Quest` with player `PlayerState`.
2. Enemy death logic increments `Stat.Enemies.Killed` by `1`.
3. Quest subsystem reevaluates active quests on stat change.
4. Bind UI to `OnQuestObjectiveProgress` for live progress display.

## B. Shared quest: survive room for all players

Authoring:

1. Create `QuestDefinition` data asset.
2. Set:
: `QuestTag = Quest.Shared.Room.SurviveWave`
: `Scope = Shared`
: `PersistencePolicy` can be left as-is (shared is runtime transient)
3. Add base objective and add `Quest Stat Threshold Condition` in `CompletionConditions`:
: `StatTag = Stat.World.Room.SurvivePoints`
: `MinValue = <target points>`
: `Source = WorldOnly`

Runtime flow in room blueprint (authority path):

1. Get `GameState` -> cast `ADTGameState`.
2. On room start: call `Start Shared Quest`.
3. During encounter: increment world stat `Stat.World.Room.SurvivePoints`.
4. On success/failure: call `Complete Shared Quest` or `Fail Shared Quest`.

## 6. Save/load flows

Player quests:

- Save: `QuestSubsystem->BuildSaveData(EQuestScope::Player, true)`
- Load: `QuestSubsystem->LoadSaveData(CachedPlayerQuestData, true, EQuestScope::Player)`

Shared quests:

- intentionally session-only and reset by `ADTGameState` at begin play.

## 7. Operational guidance

- Keep quest progression stat-driven and mutate stats at gameplay source points.
- Use gameplay tags as stable contract keys across quest defs and stat producers.
- For stat-driven objectives/conditions, use clear source (`PlayerOnly`, `WorldOnly`, etc.).
- Prefer handling shared quest orchestration from `ADTGameState` to keep authority and dungeon flow centralized.
