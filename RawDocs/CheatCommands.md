# Cheat Commands

All DarkTower cheats live on `UDTCheatManager` (`Source/DarkTower/Public/Core/DTCheatManager.h`,
implementation in `Source/DarkTower/Private/Core/DTCheatManager.cpp`). They are plain `exec` functions,
so they are typed into the in-game console (`~`) during PIE or a development build. Section 10 covers the
project's custom console variables, which are declared in the systems they debug rather than on the cheat
manager.

## 1. Using the console

- Open the console with `~` in PIE or a Development/Debug build. Cheat managers are not created in
  Shipping builds, so none of these exist there.
- Almost every cheat is marked `BlueprintAuthorityOnly` and mutates server-authoritative state
  (inventory, quests, stats, dungeon settings). Run them on the server — standalone PIE or the
  listen-server host. From a client, route them through `ServerExec <Command> <Args>`.
- Arguments are space separated. Wrap any argument containing spaces in quotes:
  `SpawnLootByPhrase 0A1B... 1 "big crit stick"`.
- Enum arguments are typed by name (`ClearStats Player`, `ClearQuestData Shared true`).
  Booleans accept `true` / `false`.
- Output goes to `ClientMessage`, i.e. the console log on the calling player's screen.

### Autocomplete help text

The engine builds a console command's description **only from its parameter list** — C++ doc comments
never reach the console. Real help text lives in `[/Script/EngineSettings.ConsoleSettings]` in
`Config/DefaultInput.ini` as `ManualAutoCompleteList` entries.

**When you add, rename, or remove an exec cheat, update three places:** the header, the
`DefaultInput.ini` autocomplete list, and this document.

---

## 2. Player / combat

| Command | Arguments | Description |
| --- | --- | --- |
| `DamageSelf` | `Amount` (float, default `10`) | Applies true (unmitigated) damage to your own pawn through the combat subsystem. Amount must be > 0. |
| `God` | — | Toggles god mode. Adds/removes the `Status.God` loose tag; all incoming damage is ignored. |
| `DemiGod` | — | Toggles demi god mode (`Status.DemiGod` loose tag). Damage still lands in full — hit reacts, damage numbers and leech all behave normally — but a killing blow loops health back to max instead of dropping to zero. |
| `KillAllEnemies` | — | Applies lethal true damage to every `ADTEnemyCharacter` in the level and reports the kill count. |

```
DamageSelf 25
DemiGod
KillAllEnemies
```

---

## 3. Loot and inventory

Spawned items appear ~120 units in front of the player and 40 units up, owned by the calling player
(not shared with the rest of the party). Stackable item definitions spawn as a single stack of
`Quantity`; non-stackable definitions spawn `Quantity` separate actors.

| Command | Arguments | Description |
| --- | --- | --- |
| `SpawnLootByName` | `LootItemName` (asset name), `Quantity` (default `1`), `Seed` (default `0`) | Spawns a loot item looked up by `UDTItemDefinition` asset name. `Seed` of 0 rolls randomly. |
| `SpawnLootByID` | `LootItemID` (GUID), `Quantity`, `Seed` | Same, looked up by item definition GUID. |
| `SpawnLootByPhrase` | `LootItemID` (GUID), `Quantity`, `SeedPhrase` (string) | Hashes the phrase into the roll seed, so the same phrase always reproduces the same item. Empty phrase rolls randomly. |
| `SpawnLootAtFloor` | `LootItemID` (GUID), `Quantity`, `Floor` (default `1`), `Seed` | Spawns as if the item had dropped on the given dungeon floor, so floor scaling applies. |
| `SpawnLootWithAffix` | `LootItemID` (GUID), `AffixGuid` (GUID), `RollValue` (0–1, default `1`), `bClearAffixes` (default `false`) | Generates the item, then forces a specific affix on at the given normalized roll. `bClearAffixes` strips the naturally rolled affixes first so only the forced one remains. |
| `ClearInventory` | — | Removes every item from the player's inventory. |
| `ClearEquipment` | — | Unequips every equipment slot on the player. |
| `TestLootGen` | `Iterations` (int) | Runs the global loot table N times without spawning anything and logs performance, seed uniqueness, stat variation, affix distribution and rarity distribution. |
| `LogExtraLootRolls` | `Floor` (default `-1`), `LootBonus` (default `0`) | Logs how many extra loot rolls the loot budget grants, reported as "N guaranteed + P% chance of one more". `Floor -1` uses the current dungeon floor. Not authority-gated. |

```
SpawnLootByName ID_Sword_Rusted 3
SpawnLootByPhrase 0A1B2C3D4E5F60718293A4B5C6D7E8F9 1 "big crit stick"
SpawnLootAtFloor 0A1B2C3D4E5F60718293A4B5C6D7E8F9 1 25
SpawnLootWithAffix 0A1B2C3D4E5F60718293A4B5C6D7E8F9 4E5F6A7B8C9D0E1F2A3B4C5D6E7F8A9B 1.0 true
TestLootGen 500
LogExtraLootRolls 200 0.5
```

---

## 4. Dungeon and session

| Command | Arguments | Description |
| --- | --- | --- |
| `SetDungeonSettings` | `Floor` (int), `Seed` (int) | Overrides the dungeon floor and seed for this session on the game mode and pushes them to the game state. |
| `CompleteDungeon` | `bFail` (default `false`) | Marks the current floor complete (activating portals and broadcasting the floor-complete event). Pass `true` to trigger the run-failed flow instead. Requires `ADTGameplayGameMode` — i.e. a dungeon map. |
| `SaveGame` | — | Forces an immediate save of the current slot via `UDTSaveSubsystem`. |

```
SetDungeonSettings 3 12345
CompleteDungeon
CompleteDungeon true
```

---

## 5. Skill trees

| Command | Arguments | Description |
| --- | --- | --- |
| `RespecTree` | `TreeTagString` (full tag string) | Respecs one skill tree and refunds its invested points. |
| `RespecAllTrees` | — | Respecs every tree with invested points and reports the refunded total. |
| `PrintSkillTrees` | — | Prints available/total skill points, then per tree: points invested, nodes unlocked, and each invested node's rank. Not authority-gated. |

```
RespecTree SkillTree.Berserker
RespecAllTrees
PrintSkillTrees
```

---

## 6. Currency

| Command | Arguments | Description |
| --- | --- | --- |
| `AddCurrency` | `CurrencyTagString`, `Amount` (int64, default `100`), `bGiveToEveryone` (default `false`) | Grants currency to the local player, or to all players when `bGiveToEveryone` is true. Amount must be > 0. |
| `ClearCurrency` | `CurrencyTagString` | Zeroes out one currency balance for the local player. |
| `PrintCurrencies` | — | Prints every currency balance for the local player. Not authority-gated. |

```
AddCurrency Currency.Gold 1000
AddCurrency Currency.Gold 1000 true
ClearCurrency Currency.Gold
```

---

## 7. Hero progression

| Command | Arguments | Description |
| --- | --- | --- |
| `AddHeroXP` | `Amount` (int64, default `100`), `bGiveToEveryone` (default `false`) | Grants hero XP to the local player, or to all players. Reports the level transition and new XP totals. Amount must be > 0. |
| `ClearHeroProgression` | — | Resets hero level and XP back to zero. |
| `PrintHeroProgression` | — | Prints level, current XP, XP to next level and total XP. Not authority-gated. |

```
AddHeroXP 1000
AddHeroXP 1000 true
ClearHeroProgression
```

---

## 8. Quests

| Command | Arguments | Description |
| --- | --- | --- |
| `QuestAccept` | `QuestTagString` | Accepts a quest for the local player. |
| `QuestComplete` | `QuestTagString`, `bGrantRewards` (default `true`) | Completes a quest; `bGrantRewards` controls whether rewards are handed out as if it completed normally. |
| `QuestFail` | `QuestTagString` | Fails a quest. |
| `QuestAbandon` | `QuestTagString` | Abandons a quest. |
| `PrintQuest` | `QuestTagString` (optional) | Prints one quest's state plus objective count and reward-granted flag. With no tag, prints every tracked player quest. |
| `PrintAllQuests` | — | Prints all tracked quests (equivalent to `PrintQuest` with no tag). |
| `ClearQuestData` | `QuestSource` (`Player` \| `Shared`), `bTransientOnly` | Wipes quest data for one scope. `bTransientOnly true` resets only session quests; `false` also wipes persistent save data. |

```
QuestAccept Quest.Main.Intro
QuestComplete Quest.Main.Intro true
PrintQuest Quest.Main.Intro
ClearQuestData Player true
```

---

## 9. Stats

Player stats are owner-only replicated; both player and world stats are written with the
`PersistentSaveSlot` policy, so cheat-set values survive a save. See [StatSystem.md](StatSystem.md)
for the underlying model.

| Command | Arguments | Description |
| --- | --- | --- |
| `AddPlayerStat` | `StatTagString`, `Delta` (double, default `1`) | Adds to a numeric player stat and prints the new value. |
| `SetPlayerStat` | `StatTagString`, `Value` (double) | Sets a numeric player stat to an absolute value. |
| `PrintPlayerStat` | `StatTagString` | Prints one player stat if present. |
| `AddWorldStat` | `StatTagString`, `Delta` (double, default `1`) | Adds to a numeric world stat and prints the new value. |
| `SetWorldStat` | `StatTagString`, `Value` (double) | Sets a numeric world stat to an absolute value. |
| `PrintWorldStat` | `StatTagString` | Prints one world stat if present. |
| `PrintAllStats` | — | Dumps the full player and world stat debug strings. |
| `ClearStats` | `StatSource` (`Player` \| `World`) | Resets every stat on the chosen store. |

```
AddPlayerStat Stat.Kills 1
SetPlayerStat Stat.Kills 100
AddWorldStat Stat.World.Kills 1
ClearStats Player
```

---

## 10. Console variables

Separate from the cheat manager, DarkTower registers a handful of debug CVars. Set them from the same
console (`DT.Melee.DebugDraw 1`); type the name with no value to print the current value and help text.

Everything under `DT.*` is registered `ECVF_Cheat` and wrapped in `#if !UE_BUILD_SHIPPING`, so these do
not exist in a Shipping build. The debug draws happen wherever the code runs — AI and threat logic is
server-side, so run those on the server/host.

### `DT.*` — debug visualization

| CVar | Type / default | Description | Declared in |
| --- | --- | --- | --- |
| `DT.AI.DebugThreat` | int, `0` | AI threat tables (server only). `1` = draw each AI's threat table, current target and overtake distance. `2` = also log threat gains, taunts and target-switch decisions. | [DTThreatComponent.cpp:14](Source/DarkTower/Private/AI/DTThreatComponent.cpp:14) |
| `DT.Team.DebugQueries` | int, `0` | `UDTTeamSubsystem` queries. `1` = draw source, search radius and lines to matched actors. `2` = also log per-actor reject reasons in `PassesQueryFlags`. | [DTTeamSubsystem.cpp:11](Source/DarkTower/Private/Systems/DTTeamSubsystem.cpp:11) |
| `DT.Team.DebugActor` | string, `""` | Filters the above: only queries whose source actor name contains this substring are drawn/logged. Empty = all. | [DTTeamSubsystem.cpp:20](Source/DarkTower/Private/Systems/DTTeamSubsystem.cpp:20) |
| `DT.Interaction.DebugDraw` | bool, `false` | Draws interaction range plus best (green) / loser (yellow) / blocked-or-too-far (red) markers with priority labels. | [AbilityTask_GrantNearbyInteraction.cpp:20](Source/DarkTower/Private/AbilitySystem/Tasks/AbilityTask_GrantNearbyInteraction.cpp:20) |
| `DT.Interaction.DebugRange` | float, `750` | Absolute debug-draw scan radius in cm for the above. Candidates inside it but out of interact range draw red `[FAR]`. Clamped to at least the real interaction range. | [AbilityTask_GrantNearbyInteraction.cpp:26](Source/DarkTower/Private/AbilitySystem/Tasks/AbilityTask_GrantNearbyInteraction.cpp:26) |
| `DT.Melee.DebugDraw` | bool, `false` | Draws hitbox debug shapes for every melee hit event, overriding each notify's per-notify `bDebug` flag. | [DTGameplayAbility_Melee.cpp:26](Source/DarkTower/Private/AbilitySystem/Abilities/DTGameplayAbility_Melee.cpp:26) |

```
DT.AI.DebugThreat 2
DT.Team.DebugQueries 1
DT.Team.DebugActor Skeleton
DT.Melee.DebugDraw 1
```

### First-party plugin CVars

| CVar / command | Type / default | Description | Declared in |
| --- | --- | --- | --- |
| `DamageNumbers.Enabled` | bool, `true` | Master toggle for spawning damage numbers. | `Plugins/DamageNumbers/.../DamageNumberSubsystem.cpp` |
| `DamageNumbers.UseAbbreviation` | bool, `false` | `10,000` vs. abbreviated `10.00K`. | same |
| `DamageNumbers.Accumulate` | bool, `false` | Accumulate hits on the same target into one number instead of spawning a new one per hit. | same |
| `PSOForge.Start` | command | Starts a PSOForge capture pass in the current world (run in a cooked build with `-logPSO`). | `Plugins/PSOForge/.../PSOForgeModule.cpp` |
| `PSOForge.Stop` | command | Cancels a running capture pass. | same |
| `PSOForge.Status` | command | Logs the current capture state. | same |

The `DamageNumbers.*` CVars are `ECVF_Default` (they exist in Shipping) because `UDTSettingsLocal`
mirrors `UseAbbreviation` and `Accumulate` into them from the player-facing game settings. A console
override therefore lasts until the corresponding setting is next applied.

### Inherited Lyra CVars

`UDTSettingsShared` carries over Lyra's gamepad deadzone defaults: `gpad.DefaultLeftStickInnerDeadZone`
and `gpad.DefaultRightStickInnerDeadZone` (float, `0.25`) in
[DTSettingsShared.cpp:17](Source/DarkTower/Private/Settings/DTSettingsShared.cpp:17). These are defaults
for new settings objects, not live overrides.

---

## 11. Adding a new cheat

1. Declare the `exec` function in `DTCheatManager.h` with a doc comment covering usage and each
   parameter. Mark it `BlueprintAuthorityOnly` unless it is purely a read/print command.
2. Implement it in `DTCheatManager.cpp`. Follow the existing shape: bail early on a null
   `GetPlayerController()`, resolve tags through `ResolveTagFromString`, resolve the player state
   through `GetDTPlayerState`, and report every failure path with `ClientMessage` so the command is
   never silently a no-op.
3. Add a `ManualAutoCompleteList` entry under the matching section in `Config/DefaultInput.ini`.
4. Add a row to the matching table in this document.
