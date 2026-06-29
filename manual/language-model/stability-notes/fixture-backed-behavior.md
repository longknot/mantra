# Fixture-Backed Behavior

Fixture-backed behavior is the safest material to present as user-facing language
behavior. When the manual includes a code example that corresponds to a fixture in
`tests/cases/`, the expected output is stable and regression-tested.

## Fixture Shape

Each test fixture consists of:

- `tests/cases/<case>.in` — source code passed to the Mantra runtime.
- `tests/cases/<case>.out` — expected raw output the runtime should produce.
- `tests/cases/<case>.args` — optional CLI arguments (one per line).

### Example Fixture

A fixture for tilde-compute in an evaluation scope:

**`compute_scope_expression_add.in`**:
```mantra
{ ~ + 1 ( 2 ) }
```

**`compute_scope_expression_add.out`**:
```
+ 3
```

The `--raw` flag is used when running the test, so the `.out` file contains
the direct runtime output without any `OUTPUT:` prefix. If the runtime no
longer produces `+ 3`, the test suite fails. That is the mechanism that pins
behavior as stable.

## Running the Test Suite

```bash
# Build and run all fixtures
tests/run.sh

# Run without rebuilding
tests/run.sh --no-build

# Strict mode (exact output match; default normalizes whitespace)
tests/run.sh --strict

# Filter by fixture name
tests/run.sh --filter repeat

# Run tests in parallel
tests/run.sh --jobs 12
```

The runner feeds each `.in` file to `./bin/mantra --raw [args]`, captures the
raw stdout, and compares it against the `.out` file. By default, both expected
and actual output are normalized (whitespace collapsed, blank lines removed)
before comparison. In `--strict` mode, the comparison is exact — spaces and
blank lines matter.

## Current Fixture Coverage

441 regression fixtures cover these areas. The most heavily tested subsystems
are pattern matching (62 fixtures), inference (46), and indexing (23):

| Category | Count | Covers |
|---|---|---|
| matcher | 62 | Pattern matching, selection rules, match-any, full-match, guards |
| inference | 46 | `|=` queries, beam search, equivalence, bounded steps, witnesses |
| index | 23 | Array indexing, range lookups, matrix access, path queries |
| staged | 18 | Multi-stage repeat, staged evaluation sequences |
| debugger | 17 | Breakpoints, stepping, frame inspection, postmortem reports |
| repeat | 14 | `: n` bounded repeat, `: ...` fixpoint recurse |
| selection | 13 | `?` rewrite operator, pattern-based transformations |
| range | 13 | `..` range operator, stepped ranges, range semantics |
| subst | 11 | Variable substitution, tree cloning, `subst_transform` |
| imag | 10 | Imaginary number arithmetic |
| float | 9 | Floating-point operations |
| quaternion | 8 | Quaternion algebra and multiplication |
| package | 8 | `import`, `include`, package resolution |
| native | 8 | Native callable dispatch |
| render | 7 | Tree rendering and formatting |
| printf | 7 | Formatted output via `printf` |
| json | 7 | JSON encoding/decoding |
| head | 7 | Head-dispatch and opt-out |
| comparison | 7 | Relational operators (`<`, `>`, `=`, `<=`, `>=`, `!=`) |
| induction | 6 | Inductive proof patterns |
| trie | 5 | Trie data structure operations |
| scope | 5 | Scope frames, lexical evaluation scopes |
| pattern | 5 | Pattern matching variants |
| assignment | 5 | `=` assignment, deep assignment `:=`, tree-clone semantics |
| ... | 96+ | CLI, string, boolean, callable, concatenate, and more |

### Rewrite and Selection

- `=>` transform, `:=>` inline transform, `<=>` equivalence
- `?` selection rewrite, `:=?` inline selection
- `--` match-any (prefix, suffix, infix with backtracking)
- `^` full-match enforcement
- Rule definitions and head-dispatch
- Selection policies (`first`, `random`, `shrink`)
- State-selection mode (`$`)
- Substitution transforms (`subst_transform`)

**Example** (fixture: `matcher_selection_basic`):
```mantra
{ [ 1 2 3 ] ? 0 }
# Output: [ 1 2 3 ]
```
A selection with rule `0` matches nothing, so the input is returned unchanged.

### Repeat and Iteration
- `: n` bounded repeat (integer, variable, expression)
- `: ...` fixpoint recurse (bounded by MAX_FIXPOINT_STEPS)
- Staged repeat sequences (arrays, ranges, comma-separated)
- Stepped range repeats
- Nested repeat/compute interactions

### Compute and Arithmetic
- `` `...` `` compute scopes
- Integer and float operations (`+`, `-`, `*`, `/`)
- Comparisons (`=`, `<`, `>`, `<=`, `>=`, `!=`)
- Boolean operators (`and`, `or`, `xor`)
- Tilde (`~`) token compute
- Unary minus and division
- Trigonometric functions
- Variable tilde lookup compute

### Variables and Assignment

- `=` assignment with tree-clone semantics
- `lhs`/`rhs`/`all` subtree extraction
- Variable rebind and rule evaluation
- Unresolved variable passthrough
- Assignment evaluation post-RHS snapshot
- CLI `--set` variable predefinition

**Example** (fixture: `assignment_eval_post_rhs_snapshot`):
```mantra
x = [ 1 ];
print { { y = x } };
x = [ 2 ];
print { y };
# Output:
# y = [ 1 ]
# [ 1 ]
```
Reassigning `x` does not affect `y` — assignment clones the tree, so `y` retains
its original snapshot of `[ 1 ]`.

### Data and Tries
- Deep assignment (`:=`) with merge, overwrite, and replace modes
- `json_load`, `json_save`, `yaml_load`, `json_encode`
- `display` for JSON output
- Indexed trie assignment
- Flat-to-nested trie conversion
- Trie query utilities (`utils_make_trie`, `trie_dict_children`)

### Strings and Sequences
- `explode`/`implode` string/character conversion
- String escape handling (quotes, statement balance)
- Concatenation (`&`) for arrays, expressions, and strings

### Inference

- `|=` operator (one-step and multi-step queries)
- Bidirectional inference (`<=>`)
- Witness step printing

**Example** (fixture: `inference_bounded_zero_step_equal`):
```mantra
print { 1 => 1 |= [ 1 => 2 ] : 0 }
# Output: 1
```
A zero-step bounded inference query (`: 0`) checks immediate equality. Since
`1 => 1` does not unify with `1 => 2` without transformation, the result is
the left-hand side itself.

### Debugger
- Breakpoints (callable, source line, import/include files)
- Stepping (next, step, finish)
- Frame inspection and snapshot
- Postmortem dispatch error reports
- CLI debugger interaction

### Modules and Imports
- Package declarations and imports
- Include file handling
- Callable alias and qualified dispatch
- Internal non-bindable callables
- CLI eval expression append

### Scope and Meta
- Backtick nested repeat compute
- Fixed scope (`'...'`) and unfix meta (`\`)
- Scope prefix behavior

## When to Trust Fixture-Backed Behavior

When a manual section includes a code example with output that matches a fixture:

1. **The behavior is stable.** If it changes, the test suite will fail.
2. **The output is authoritative.** The `.out` file is the source of truth.
3. **Manual examples should match.** Any discrepancy between the manual and a
   fixture is a documentation bug, not a language ambiguity.

## Adding New Fixtures

When documenting new behavior or extending the manual:

1. Create `tests/cases/<case>.in` with the source code.
2. Create `tests/cases/<case>.out` with the expected output.
3. Add `tests/cases/<case>.args` if CLI flags are needed.
4. Run `tests/run.sh --filter <case>` to verify the fixture passes.
5. Reference the fixture from the manual section.

This turns design-note behavior into fixture-backed behavior and raises the
stability of the feature.

## Manual Writing Guidelines for Fixture-Backed Material

When writing about fixture-backed behavior:

- Use definitive language: *"the repeat operator clones..."*, *"selection rewrites..."*
- Do not add stability caveats — the fixture is the guarantee.
- Include the code example with its expected output, matching the fixture.
- No need to link to `tests/cases/` from the manual itself; the fixture is the
  implementation backing, not a user-facing concern.

## See Also

- [Stability Notes](../stability-notes.md) — Parent overview of stability classes
- [Design-Note Behavior](design-note-behavior.md) — The other stability class
- `tests/run.sh` — Test runner script
- `docs/FEATURES.md` — Current feature inventory
