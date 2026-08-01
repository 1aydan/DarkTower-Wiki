---
# Landing page: the sidebar would only hold "Home", so drop both rails and
# let the card grid use the full width.
hide:
  - navigation
  - toc
---

# Dark Tower — Game Wiki

The living reference for how Dark Tower's systems work. Two layers:

- **Design docs** — plain-English guides to each system and its tuning knobs. Start here.
- **Code Reference** — the C++ API, generated straight from the source comments, for when you need the exact class, attribute, or tag a system uses.

!!! tip "How this wiki stays current"
    Everything here is **generated** from the project. The design pages come from `Docs/*.md`; the code reference comes from the doc-comments in `Source/DarkTower`. Re-run the build (`build.ps1`) and both refresh. Nobody hand-maintains this site — edit the source, rebuild.

## Design systems

<div class="grid cards" markdown>

- :material-sword-cross: **[Combat Pipeline](design/CombatPipeline.md)**

    The centralized server-authoritative damage path — how a hit becomes damage.

- :material-flash: **[Ability Event System](design/AbilityEventSystem.md)**

    The event vocabulary abilities broadcast and react to (combos, triggers).

- :material-chart-line: **[Stat System](design/StatSystem.md)**

    Attributes, how they're defined, and how they feed combat.

- :material-treasure-chest: **[Loot & Combat Tuning](design/Loot_and_Combat_Tuning_Guide.md)**

    Designer's guide to loot scaling, rarity, affixes, item level — every knob.

- :material-script-text: **[Quest System](design/QuestSystem.md)**

    How quests are structured and driven.

- :material-file-tree: **[Skill Tree — Tooltip Authoring](design/SkillTreeTooltipAuthoring.md)**

    Authoring tooltips for skill-tree nodes.

- :material-clipboard-check: **[Skill Tree — System Audit](design/SkillTreeSystemAudit.md)**

    Findings and the phased plan for the skill-tree system.

- :material-console: **[Cheat Commands](design/CheatCommands.md)**

    Every console cheat and debug CVar, and how to run them in PIE.

</div>

## Code reference

The full C++ surface — classes, structs, gameplay tags, attribute sets, abilities — with cross-linked source.

[Open the Code Reference :material-arrow-right:](api/index.html){ .md-button .md-button--primary }

---

*Generated with [MkDocs Material](https://squidfunk.github.io/mkdocs-material/) (design docs) and [Doxygen](https://www.doxygen.nl/) (code reference).*
