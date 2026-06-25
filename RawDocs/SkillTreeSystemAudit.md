# Skill Tree System — Audit & Improvement Plan

_Audit date: 2026-06-18. Covers the runtime component, data assets, in-game UI, and the editor authoring tooling._

This document captures known gaps and a phased improvement plan. Bugs already fixed in the
2026-06 component audit (passive GE stacking, client ability drag, OnRep, respec unslot, reload
duplication) are **not** repeated here.

## Architecture recap

- **Runtime**: `UDTSkillTreeComponent` (on `ADTPlayerState`) owns `TArray<FSkillTreeInstance>` (per-tree
  invested ranks + `PointsInvested`). Server-authoritative invest/respec via `Server_*` RPCs.
  `TreeInstances` is `ReplicatedUsing=OnRep_TreeInstances`.
- **Points**: derived, not stored — `GetTotalSkillPoints() = (HeroLevel-1) * SkillPointsPerLevel`.
  Available = total − sum of `PointsInvested` across trees (a single global pool shared by all trees).
- **Data**: `UDTSkillTreeData` (global list of trees + `SkillPointsPerLevel`) → `UDTSkillTreeDefinition`
  (per-tree: `GraphNodes`, `NodeLinks`, layout flags) → `UDTSkillTreeNodeDefinition` (per-node gameplay:
  tag, ranks, unlock threshold, prereqs, rewards). `FSkillTreeNode` wraps a node-definition ref + grid layout.
- **Gating** (in `CanInvestPoint`): available points > 0, below MaxRank, tree `PointsInvested` ≥ node
  `UnlockPointsRequired`, ALL `PrerequisiteNodeTags` invested, and (if any unlock-link parents exist) at
  least ONE invested.
- **Rewards** (`GrantNodeRewards`): passive GE (level = rank), single granted ability (Spec->Level = rank),
  ability set (granted at rank 1 only). Slotting to the bar is fully player-driven.
- **UI**: `UDTSkillsWidget` (tabbed scene) → `UDTSkillTreePanelWidget` (one tree, canvas-positioned nodes +
  connector lines in `NativePaint`) → `UDTSkillTreeNodeWidget` (per node; supports drag-to-bar of granted abilities).
- **Editor**: `FDTSkillTreeAssetEditor` + `SDTSkillTreeGraphEditor`. Center-origin grid; right-click
  add/remove nodes; "Auto Layout" (threshold rows, centered) and "Auto Link Nodes" (row heuristic).
  See [[skill-tree-center-origin-grid]].

## Findings

### P0 — Correctness (player-facing) — ✅ DONE (Phase A, 2026-06-18)

1. **Respec is free.** ✅ Fixed. Respec cost is now server-authoritative: `RespecCurrencyType` + `RespecCost`
   live on `UDTSkillTreeData`; `CanRespecTree` checks affordability and `RespecTree` spends via
   `UDTCurrencyComponent` on the server (client-passed cost removed entirely). Default cost 0 = free until a
   designer configures it.
2. **Multiplayer client UI doesn't refresh node state.** ✅ Fixed. Added `OnSkillTreeStateChanged`, broadcast
   from `OnRep_TreeInstances`; panels bind it and `RefreshTree()` so remote clients refresh node visuals.
3. **`LoadSaveData` trusts the save blind.** ✅ Partially fixed. Sanitize-on-load now drops ranks for nodes no
   longer in the definition and clamps ranks to current `MaxRank` before granting. _Still deferred:_ deeper
   prerequisite/threshold re-validation + refund of orphaned investment (heavier, ordering-sensitive).

### P1 — Robustness & authoring — ✅ DONE (Phase B, 2026-06-18)

4. **`TreeInstances` replicates to all clients**, not `COND_OwnerOnly`. ✅ Fixed (Phase A) — now
   `DOREPLIFETIME_CONDITION(..., COND_OwnerOnly)`.
5. **No node-to-node link editing in the editor.** ✅ Fixed. **Ctrl+drag** from one node to another in the
   editor creates an unlock link (drag onto an already-linked node removes it). Live preview line while
   dragging; `FDTSkillTreeAssetEditor::ToggleNodeLink`.
6. **Node assets have no `IsDataValid`; tree validator has no cycle detection.** ✅ Fixed. Added
   `UDTSkillTreeNodeDefinition::IsDataValid` (tag/ranks/reward sanity, set+MaxRank>1 warning) and unlock-link
   **cycle detection** in `UDTSkillTreeDefinition::IsDataValid`.
7. **Two parallel gating systems.** ✅ Addressed via cross-validation: the tree validator now warns when a
   node's `PrerequisiteNodeTags` reference a node absent from the tree, or aren't mirrored by an unlock link
   (so the graph view matches gameplay gating). _Not unified_ — both systems still exist, just cross-checked.
8. **Dead/unused data.** ✅ Removed dead `FSkillTreeNodeLayout`. `GridSpan` **kept** intentionally — it pairs
   with the planned keystone/featured-node feature (P2 #12); revisit when implementing that.

### P2 — Features

9. **Bonus skill points can't exist** — total is strictly level-derived; `EnsureSkillPointsForHeroLevel` is a
   no-op. No quest/item/shrine point grants. Add a stored bonus pool on top of the derived total.
10. **Full-tree respec only** — no single-node refund, no respec-cost scaling.
11. **Build loadouts** — save/swap multiple skill configs (pairs with weapon-set loadouts).
12. **Choice / mutually-exclusive nodes** and **keystone/notable featured nodes** — not representable today.
13. **Ability-set nodes don't scale with rank** (granted at rank 1 only). Validate against MaxRank>1 or
    support per-rank set leveling.

### P3 — Polish & quality

14. **Failure reasons** use raw `FText::FromString` with tag strings — not localized, not using node display names.
15. **Optimistic client prediction** (`CurrentNodeRank++` pre-confirmation) has no reconciliation.
16. **No automated tests** for invest→grant→save→load→respec.
17. **Minor perf** — editor `GetNodeGridPosition` is O(n²) per refresh; runtime lookups are linear scans.

## Phased plan

| Phase | Scope | Notes |
|------|-------|-------|
| ~~**A — Correctness**~~ ✅ | #1 charge currency on respec, #2 client refresh via OnRep, #3 sanitize-on-load, #4 `COND_OwnerOnly` | **Done 2026-06-18.** #3 prereq/threshold re-validation deferred. |
| ~~**B — Authoring**~~ ✅ | #5 drag-to-link, #6 node `IsDataValid` + cycle detection, #7 cross-validate prereqs↔links, #8 remove dead data / decide `GridSpan` | **Done 2026-06-18.** Gating systems cross-checked but not unified; `GridSpan` kept for keystone nodes. |
| **C — Features** | #9 bonus point pool, #10 single-node respec + cost scaling, #11 loadouts, #12 choice/keystone nodes | Larger; needs design decisions. |
| **D — Polish** | #14 localized/display-name reasons, #15 prediction reconcile, #16 tests, #17 caching | Incremental. |
