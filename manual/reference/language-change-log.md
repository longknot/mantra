# Language Change Log

This page tracks user-facing language changes in Mantra. Entries are organized by
version/commit. Only changes that affect how users write programs or interpret
output are recorded here — implementation details and internal refactors belong
in the commit history.

## What Belongs Here

- New syntax, operators, keywords, or scope forms
- Changes to operator precedence, binding, or evaluation order
- Changes to runtime output format (formatters, printing, error messages)
- New compute capabilities (functions, number types, reductions)
- New debugger features (breakpoints, events, postmortem)
- New CLI flags that alter language semantics
- Migration notes for existing manual examples
- Behavioral fixes (e.g., output that changed between releases)

For implementation history, use repository commits and developer notes. This
page stays focused on changes that affect Mantra users.

---

## Unreleased

### Features

#### At-index lookup (`@`)

The `@` operator adds positional (index-based) lookup on arrays and expressions.
Given a sequence and a 1-based index, it returns the element at that position.

```mantra
print { [ a b c d e ] @ 3 }
```

Expected output:
```
c
```

Negative indices are supported for reverse lookup:

```mantra
print { [ a b c d e ] @ -1 }
```

Expected output:
```
e
```

Out-of-bounds indices return the original form unchanged. See the
[Range Syntax](../syntax/ranges.md) page for full details.

#### Inclusive range index lookup (`@ start .. end`)

Ranges can now be used directly with `@` to extract a subsequence. The result
includes both endpoints and reverses direction when `end < start`.

```mantra
print { [ a b c d e ] @ 4 .. 2 }
print { [ a b c ] @ 2 .. 2 }
print { ( a b c d ) @ 2 .. 3 }
```

Expected output:
```
[ d c b ]
[ b ]
( b c )
```

The result preserves the container type of the source — arrays yield arrays,
expressions yield expressions.

#### Staged sequence repeat drivers

The repeat operator (`:`) now supports sequence-driven expansion. When the
right-hand side is a sequence (range or array), each element drives one
repetition of the left-hand side, rather than cloning the same value.

```mantra
[ x ] : 1 .. 3
```

Expected output:
```
[ 1 ] [ 2 ] [ 3 ]
```

This is useful for generating parameterized expansions without explicit
loops. See the [Repeat Operator](../transformations/repeat-operator/staged-sequence-repeat.md)
page for details.

#### Fixed transforms (`\ =>`)

Fixed transforms prevent variable-shaped terms from becoming fresh matcher
bindings. The left-hand side of a fixed transform captures the resolved value
of variables at the time the rule is applied, not at the time the pattern is
matched.

```mantra
x = 1;
fixed = x \ => 2;

print { 1 ? [ fixed ] }
```

Expected output:
```
2
```

Fixed transforms also support aliasing via the `alias` keyword.

See the [Transform Examples](../reference/examples/transform-examples.md) page.

#### Integer arithmetic upgraded to 64-bit (Int64)

Integer arithmetic in compute scope now uses 64-bit (`Int64`) precision instead
of 32-bit. This prevents silent overflow on large intermediate results.

```mantra
` * 1000000 1000000 `
```

Expected output:
```
* 1000000000000
```

(Previously, this would overflow to a different value.)

#### Quaternion compute support

Compute scope now recognizes and reduces quaternion literals (expressions with
`i`, `j`, `k` components). Quaternion multiplication distributes terms and
buckets imaginary components.

```mantra
` * i j `
```

Expected output:
```
k
```

Quaternion inverse is supported for single-term values:

```mantra
` inv i `
```

Expected output:
```
- i
```

See the [Compute](../compute/index.md) section for full details.

#### Rule aliasing (`alias`)

Rules can now be aliased using the `alias` keyword. An alias refers to another
rule's body, enabling short-hand invocation:

```mantra
rule cat [
  cat X Y => [ lhs X lhs Y ]
];

alias combine = cat;

print { combine [ 1 ] [ 2 ] }
```

Expected output:
```
[ 1 2 ]
```

Aliases also work with callable dispatch — the aliased name is dispatched
to the original rule's rules.

#### Interactive REPL improvements

The REPL mode (`--interactive`) now supports:

- **Cursor navigation** — arrow keys to move within the current line
- **Input history** — up/down arrows to recall previous inputs
- **Prompt before first input** — the `> ` prompt now appears correctly
  before the first line instead of after

These changes make interactive exploration of Mantra programs significantly
more usable.

#### Inference: oriented rule views and witness tracking

The inference operator (`|=`) now records which rule direction (forward or
reverse) was used at each proof step. Witness traces include the orientation
(`=>` or `<=`) alongside the rule name and matched pattern.

#### Inference: bounded beam widening with provenance

Beam search during inference now tracks the provenance of each candidate —
which parent step and rule produced it. When the beam widens, the runtime
emits a `beam_widen` event visible via `--event-log`.

#### Inference: opt-in growth cost policy

An optional growth cost policy limits search expansion by penalizing steps
that produce larger intermediate trees. Enable via the
`mantra.inference.growth_cost` context variable.

#### Native function registry dispatch

Compute scope now supports a pluggable registry of native (built-in) functions.
Functions are indexed by name for O(1) lookup instead of linear scanning.

#### Structured JSON output encoding

Mantra can now encode structured outputs (trees with typed values) to JSON.
The `--json` flag produces machine-readable output suitable for programmatic
consumption.

#### CSV support

The `csv_load` node reads CSV data into nested array structures. Column
headers become keys; rows become array elements.

#### YAML loading (`yaml_load`)

The `yaml_load` node parses YAML documents into Mantra tree structures.
Nested YAML mappings become arrays; sequences become arrays.

#### Render and column profile support

The `render` keyword supports column-based output formatting with named
profiles controlling alignment, padding, and separator styles.

#### Printf-style formatting (`printf`)

The `printf` node supports C-style format strings with positional arguments:

```mantra
print { printf "Name: %s, Value: %d" "x" 42 }
```

Expected output:
```
Name: x, Value: 42
```

#### Make pair construct (`make_pair`)

The `make_pair` construct creates key-value pairs for trie queries and
structured data manipulation.

#### Trie builder and queries

The `make_trie` library function builds trie data structures from
sequences. Trie queries support deep wildcard matching, enumeration,
and index segment lookups.

#### Triple-dot transform (`==>>`)

The `==>>` operator performs recursive symbolic substitution — it replaces
all occurrences of a symbol, including those introduced by previous
replacements in the same expression.

#### Transparent grouping (`<< >>`)

Transparent grouping provides parse-level grouping without leaving a scope
node in the AST. Useful when a transform operand needs grouping but the
grouping wrapper should not survive in the output.

```mantra
ih = << + m : + n >> => << + n : + m >>;
print { + m : + n ? [ ih ] }
```

Expected output:
```
+ n : + m
```

#### Event log (`--event-log`)

The `--event-log` flag emits detailed matcher events to stdout, including:
- Rule probe attempts (matched/unmatched)
- Rewrites applied
- Variable bindings created
- State transitions during inference

This is useful for debugging complex selection or inference workflows.

#### Global variable support (`global` keyword)

The `global` keyword marks a variable as accessible across package
boundaries. Without `global`, variables are scoped to the importing
context.

#### Package-level namespace prefixes

Packages now automatically prefix their symbols with the package name
when imported. This prevents name collisions when multiple packages
export identically-named rules or callables.

### Bug fixes

#### Compute: stop retrying unresolved additive islands

Previously, quaternion imaginary multiplication would retry unresolved
additive groups indefinitely. The runtime now detects stable islands and
stops further attempts, preventing unnecessary processing.

#### Tilde look-up compute in repeat statements

Fixed a bug where `~` (meta compute) lookups inside repeat statements
would not resolve correctly, causing repeated evaluations to produce
stale results.

#### Fixed expressions promoted in LHS pattern evaluation

Fixed expressions (`\`) in the LHS of a transform rule are now properly
promoted to their evaluated form during pattern matching, ensuring
consistent behavior between fixed and variable-shaped terms.

#### REPL prompt flush

Fixed a bug where the REPL prompt did not appear before the first input
line, causing confusion in interactive sessions.

#### Witness rendering

Fixed rendering of inference witnesses — intermediate steps now display
correct rule names and matched patterns instead of raw IR.

#### Head dispatch depth limit

Head dispatch now has a hard depth limit of **128 levels**
(`MAX_HEAD_DISPATCH_STEPS`). Previously, self-referential callables
could exhaust the stack. When the limit is reached, the node is left
as-is and execution continues without error.

### Deprecated / Removed

#### Removed `==>>` for symbolic substitution in favor of `==> ==>>`

The `==>>` operator was replaced with `==>` for symbolic substitution.
The old `==>>` form was ambiguous and is no longer recognized.

### Migration Notes

- Programs using `==>>` should replace with `==>` for symbolic substitution.
- Programs relying on 32-bit integer overflow behavior will need adjustment;
  upgrade to explicit modulo operations if the old overflow behavior was
  intentional.
- Head dispatch depth was previously unlimited (bounded only by stack space);
  self-referential callables now produce the original node after 128 levels
  instead of crashing.
