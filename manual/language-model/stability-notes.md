# Stability Notes

Mantra is an experimental language. Its runtime, matcher, inference engine, and
tooling are actively evolving. This page explains how the manual distinguishes
between behavior you can rely on and behavior that is still being shaped.

## Why This Matters

Not every language feature in Mantra has the same maturity. Some operators have
hundreds of regression fixtures pinning their behavior down. Others are described
in design notes but have not yet settled into a final form. Without knowing the
difference, you cannot know when a manual example reflects a stable guarantee and
when it reflects a current working direction that may change.

## Stability Classes

The manual recognizes two stability classes for language behavior:

| Class | Basis | What It Means |
|---|---|---|
| **Fixture-backed** | Covered by `tests/cases/` regression tests | Stable language behavior. The fixture pins the expected output. If the runtime deviates, the test suite fails. This is the authoritative source of truth. |
| **Design-note** | Described in `docs/` but not yet pinned by fixtures | Current implementation direction. The behavior works now, but the manual cannot guarantee it will not change. Treat it as informative, not contractual. |

A third implicit class exists but is not treated as manual material:

| Class | Basis | What It Means |
|---|---|---|
| **Purely speculative** | Design notes exploring alternatives with no implementation | Not presented in the manual. Reference-only in `docs/`. |

### How to Tell Which Class a Feature Belongs To

- If the manual section includes a code example that corresponds to a fixture in
  `tests/cases/`, it is **fixture-backed**.
- If the manual section describes behavior without a corresponding fixture and
  references a design note in `docs/`, it is **design-note** behavior.
- Design-note behavior will be signalled with language like *"the current
  behavior is"* rather than *"the language defines"*.

## Fixture-Backed Behavior

441 regression fixtures currently cover the core rewrite, selection, inference,
compute, and data subsystems. Fixture-backed material is the safest to treat as
language specification.

Read more: [Fixture-Backed Behavior](fixture-backed-behavior.md)

## Design-Note Behavior

Design notes in `docs/` describe intended behavior, architectural decisions, and
open research questions. They are the primary source of truth for features not yet
covered by fixtures. When the manual draws on design-note behavior, it does so
with explicit caveats.

Read more: [Design-Note Behavior](design-note-behavior.md)

## The Stability Lifecycle

Features move through stages from research to stabilization. A feature's position
in this lifecycle determines how the manual treats it:

```
Research Note → Implementation Plan → Working Implementation → Fixture-Backed → Stabilized
```

| Stage | Manual Treatment |
|---|---|
| Research Note | Not in the manual; reference only |
| Implementation Plan | Not in the manual; link from related topics |
| Working Implementation | In the manual with design-note caveats |
| Fixture-Backed | In the manual as stable behavior |
| Stabilized | In the manual as standard language behavior |

As fixtures are added and behavior is confirmed, manual sections are updated to
remove caveats and present the behavior as stable.

## What Is Currently Strong (Fixture-Backed)

Based on the breadth of fixture coverage, these areas are the most mature:

- **Rewrite and selection** — `=>`, `<=>`, `?`, `:=?` operators, pattern matching,
  `--` match-any, `^` full-match, rule definitions, and head-dispatch.
- **Repeat and iteration** — `: n` bounded repeat, `: ...` fixpoint recurse,
  staged repeat sequences, range-driven iteration.
- **Compute scopes** — `` `...` `` arithmetic evaluation, integer and float
  operations, comparisons, boolean operators, trigonometric functions.
- **Variables and assignment** — `=` assignment with tree-clone semantics,
  `lhs`/`rhs`/`all` subtree selectors, CLI `--set` predefinition.
- **Concatenation** — `&` operator for arrays, expressions, and strings.
- **Trie and data operations** — `get`, deep assignment (`:=`),
  `json_load`/`yaml_load`/`json_encode`, indexed path writes.
- **String operations** — `explode`/`implode`, escape handling.
- **Inference basics** — `|=` operator, one-step and bounded multi-step queries,
  witness capture.
- **Debugger** — breakpoints (callable, source, inference), stepping, postmortem
  reports, frame inspection.
- **Modules and imports** — `package`, `import`, `include` directives with
  de-duplication.
- **CLI flags** — `--raw`, `--debug`, `--eval`, `--show-tokens`, `--backtracking`,
  `--no-guards`.

## What Is Still Evolving (Design-Note Dominant)

These areas are working but may change as their design matures:

- **Scope frames** — The `scope { ... }` MVP for exact lexical locals is implemented,
  but dotted local paths, dynamic setting overrides, and merged child/query
  semantics are still being designed.
- **Scope privacy and dynamic settings** — Package-level visibility rules and
  dynamic configuration settings are under active development.
- **Inference completeness** — Inference works but is sensitive to operand
  representation. Thunk normalization, candidate collection, and beam search
  quality are improving.
- **Namespace and package metadata** — Import aliases, export declarations,
  manifests, and dependency metadata are still open.
- **Trie/object authoring surface** — A canonical object model with uniform
  materialization rules is not yet finalized.
- **Debugger explainability** — Watchpoints, "why did this rule not match?"
  diagnostics, and richer frontier explanations are planned.
- **Performance instrumentation** — Built-in counters for rewrite/inference runs
  and matcher profiling are not yet implemented.

## How the Manual Uses This Information

- **Fixture-backed examples** are presented without caveats. The example's output
  matches a real fixture in `tests/cases/`.
- **Design-note examples** carry a note explaining that the behavior is current
  direction and may evolve. The note links to the relevant design note in `docs/`.
- **Language choices** — For fixture-backed behavior, the manual uses definitive
  language (*"the selection operator rewrites..."*). For design-note behavior, it
  uses qualified language (*"the current behavior is..."*, *"at this time..."*).

## What You Can Trust

You can trust the manual for:

1. Fixture-backed behavior — if a fixture exists, the output is stable.
2. Structural contracts — how operators consume and produce tree nodes.
3. Operator precedence and parsing rules — these are defined by the parser and
   pinned by fixtures.

You should treat with caution:

1. Design-note behavior — it works now but is not guaranteed stable.
2. Experimental CLI flags — flags like `--debugger` and `--no-head-dispatch` are
   functional but may change their interface.
3. Package conventions — import paths, naming conventions, and export rules are
   still being formalized.

## When in Doubt

If you are unsure whether a feature is stable:

1. Check `tests/cases/` for a fixture matching the behavior.
2. If a fixture exists, the behavior is stable.
3. If no fixture exists but a design note in `docs/` describes it, the behavior is
   working but may change.
4. If neither exists, the feature is speculative and not in the manual.

## See Also

- [Fixture-Backed Behavior](fixture-backed-behavior.md) — Stability class backed by regression tests
- [Design-Note Behavior](design-note-behavior.md) — Stability class backed by design documentation
- [Language Model Overview](index.md) — Parent section
- `docs/current-state-and-open-gaps.md` — Full repository health assessment
- `docs/FEATURES.md` — Current feature inventory
- `tests/run.sh` — Fixture test runner
