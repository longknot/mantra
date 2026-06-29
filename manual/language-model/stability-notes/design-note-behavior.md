# Design-Note Behavior

The Mantra project maintains a large body of design notes in `docs/` — 60+
markdown files that describe intended behavior, architectural alternatives,
implementation plans, and open research questions. These notes are **not** the
user manual, but they heavily influence what the user manual can and cannot say.

## What Are Design Notes?

Design notes live in `docs/` and fall into several categories:

### Implemented but Unstabilized

Behavior that already works but may still change. These notes document the
current direction without guaranteeing backward compatibility.

| Design Note | Topic |
|---|---|
| [scope-privacy-and-dynamic-settings.md](../../docs/scope-privacy-and-dynamic-settings.md) | Scope-frame model, package privacy, dynamic settings |
| [local-scope-frame-model.md](../../docs/local-scope-frame-model.md) | Exact-local scope MVP and future phases |
| [at-index-and-iterator-binding.md](../../docs/at-index-and-iterator-binding.md) | `@` index and iterator binding semantics |
| [beam-search.md](../../docs/beam-search.md) | Inference beam search configuration |

### Architectural Alternatives

Explorations of different implementation approaches where the final choice is not
yet fixed.

| Design Note | Topic |
|---|---|
| [dedicated-runtime-pipeline.md](../../docs/dedicated-runtime-pipeline.md) | Pipeline architecture options |
| [dedicated-runtime-versus-alternatives.md](../../docs/dedicated-runtime-versus-alternatives.md) | Runtime model trade-offs |
| [trie-deep-copy-assignment-alternatives.md](../../docs/trie-deep-copy-assignment-alternatives.md) | Deep copy vs reference semantics |

### Open Research

Behavior under active investigation. May or may not be implemented.

| Design Note | Topic |
|---|---|
| [cross-cutting-semantic-contracts.md](../../docs/cross-cutting-semantic-contracts.md) | Shared semantic rules across subsystems |
| [inference-search-space-shortcomings.md](../../docs/inference-search-space-shortcomings.md) | Inference completeness gaps |
| [inference-thunk-normalization-change-request.md](../../docs/inference-thunk-normalization-change-request.md) | Operand normalization for inference |

### Feature Snapshots

Summaries of current capabilities without detailed design argumentation.

| Design Note | Topic |
|---|---|
| [FEATURES.md](../../docs/FEATURES.md) | Current feature inventory |
| [ARCHITECTURE.md](../../docs/ARCHITECTURE.md) | High-level pipeline overview |
| [current-state-and-open-gaps.md](../../docs/current-state-and-open-gaps.md) | Repository health assessment |

## How Design Notes Relate to Fixture-Backed Behavior

The manual distinguishes two stability classes:

1. **Fixture-backed behavior** — covered by `tests/cases/` regression tests.
   Presented as stable language behavior. See [Fixture-Backed Behavior](fixture-backed-behavior.md).

2. **Design-note behavior** — described in `docs/` but not yet pinned by
   fixtures. Presented as current direction with explicit caveats.

When both exist for the same feature, the fixture is the authority for what the
manual describes as "the behavior." The design note provides context for
**why** the behavior is that way and what might change.

## Manual Treatment Guidelines

### Identify Design-Note Behavior Explicitly

When a manual section draws on design-note behavior:

- State that the behavior is based on current implementation direction
- Use language like "the current behavior is" rather than "the language requires"
- Avoid words that imply permanence: *defined*, *guaranteed*, *will be*
- Prefer: *currently*, *presently*, *at this time*, *under development*

### Link to Source Design Notes

Always point to the relevant design note when:

- the implementation details matter for understanding
- the behavior is known to be experimental
- there are acknowledged alternatives still under consideration
- the design note contains examples not yet replicated in fixtures

### Avoid Presenting Design Direction as Stable

Do not write manual content that makes design-note behavior sound like a
finished language feature. Instead:

- Add a stability callout or note when the section relies on design-note
  behavior rather than fixture-backed behavior
- Mention the design note as the source of truth for implementation details
- Signal when behavior may change in future versions

### When to Include Design-Note Behavior in the Manual

Include it when:

- the behavior is demonstrably working (it can be tried in the runtime)
- the user gains practical understanding from knowing about it
- there is no fixture yet but the feature is actively used

Defer it when:

- the behavior is purely speculative with no implementation
- the design note is exploring alternatives with no current preference
- including it would mislead the user into treating it as stable

## Design Note Lifecycle

Design notes move through stages over time:

```
Research Note → Implementation Plan → Working Implementation → Fixture-Backed → Stabilized
```

A design note's position in this lifecycle determines how the manual treats it:

| Stage | Manual Treatment |
|---|---|
| Research Note | Not in the manual; reference only |
| Implementation Plan | Not in the manual; link from related topics |
| Working Implementation | In the manual with design-note caveats |
| Fixture-Backed | In the manual as stable behavior |
| Stabilized | In the manual as standard language behavior |

## Practical Example

**Before (too strong):**
```
The scope-frame model resolves names by checking local scope first,
then package scope, then global scope.
```

**After (appropriate for design-note behavior):**
```
Currently, names resolve by checking local scope first, then package
scope, then global scope. This resolution order is based on the
scope-frame model described in
[local-scope-frame-model.md](../../docs/local-scope-frame-model.md)
and may evolve as the scope model matures.
```

## Current Design Notes Inventory

The `docs/` directory contains design notes across these areas:

- **Language fundamentals**: `ARCHITECTURE.md`, `NODES.md`, `FEATURES.md`,
  `REPEAT.md`, `SELECTIONS.md`, `TRANSFORMS.md`, `VARIABLES.md`
- **Inference and proofs**: `inference-search-space-shortcomings.md`,
  `inference-thunk-normalization-change-request.md`, `beam-search.md`,
  `proofs.md`, `witnesses.md`, `proof-recommended-steps.md`
- **Scope and namespaces**: `local-scope-frame-model.md`,
  `scope-privacy-and-dynamic-settings.md`, `local-variables-revisited.md`,
  `local-variables-and-context.md`, `locals-syntax-note.md`
- **Data and trie**: `trie-queries-brainstorming.md`, `trie-builder-via-variable-subtree.md`,
  `trie-deep-copy-assignment-alternatives.md`, `key-value-design.md`
- **Debugger and tooling**: `mantra-debugger.md`, `debugger-user-manual.md`
- **Semantic contracts**: `cross-cutting-semantic-contracts.md`,
  `head-dispatch.md`, `extending-selector-logic.md`
- **Project direction**: `current-state-and-open-gaps.md`, `mantra-directions.md`,
  `RECOMMENDATIONS.md`, `SUGGESTIONS.md`
- **Quaternions and complex math**: `complex-quaternion-multiplication-architecture.md`,
  `quaternion-multiplication-mvp-design.md`, `quaternion-distribution-design-note.md`
- **Runtime and performance**: `dedicated-runtime-pipeline.md`,
  `dedicated-runtime-versus-alternatives.md`

For a complete list, see the `docs/` directory in the repository.

## See Also

- [Stability Notes](../stability-notes.md) — Parent overview of stability classes
- [Fixture-Backed Behavior](fixture-backed-behavior.md) — The other stability class
- `docs/current-state-and-open-gaps.md` — Repository health and gap analysis
- `docs/mantra-directions.md` — Future language directions
