# Test Fixture Guide

Fixture tests are the preferred way to keep Mantra programs and manual examples
aligned with actual runtime behavior. Every 440+ test cases in `tests/cases/`
are small, runnable programs that verify output against expected results.

This guide covers the fixture format, the test runner, naming conventions,
common patterns, and workflows for developing and maintaining fixtures.

## Fixture Files

A test fixture lives in `tests/cases/` and consists of one or more files sharing
the same base name:

| File | Required | Purpose |
|---|---|---|
| `<case>.in` | Yes | Mantra source code passed to `mantra` via stdin |
| `<case>.out` | Yes | Expected raw output (what `mantra --raw` produces) |
| `<case>.args` | No | Optional CLI arguments (one per line) |

The `.in` file contains the Mantra program to execute. The `.out` file contains
the expected output. The optional `.args` file supplies CLI flags to customize
the runtime (e.g., `--debug`, `--set`, `--debugger-cli`).

### Execution model

When the test runner executes a case, it runs:

```bash
printf '%s\n' "$input_text" | ./bin/mantra --raw "${case_args[@]}"
```

The `--raw` flag is **always** added automatically — it produces unformatted
`TreeValue` output suitable for exact comparison. Any arguments from `.args`
are appended after `--raw`.

## Concrete Examples

### Basic fixture (no args)

**`tests/cases/assignment_lookup_compute.in`**
```mantra
x = [ + 1 2 3 ]
`x`
```

**`tests/cases/assignment_lookup_compute.out`**
```
x = [ + 1 + 2 + 3 ]
[ + 6 ]
```

This fixture tests variable assignment and compute evaluation. Two lines of
output: the assignment echoes, then the computed result is printed.

### Fixture with `.args` (debug mode)

**`tests/cases/boolean_and_compute.in`**
```mantra
{ ~ and 1 2 3 }
```

**`tests/cases/boolean_and_compute.out`**
```
1
```

**`tests/cases/boolean_and_compute.args`**
```
--debug
```

The `.args` file enables `--debug`, which prints every statement output.
The fixture verifies that boolean `and` compute over `1 2 3` yields `1`.

### Nested repeat and compute

**`tests/cases/backtick_nested_repeat_compute.in`**
```mantra
{ [ `+ 1 + 2 + 3` : 2 ] : 3 }
```

**`tests/cases/backtick_nested_repeat_compute.out`**
```
[ + 6 + 6 ] [ + 6 + 6 ] [ + 6 + 6 ]
```

This tests nested repeat (`:`) with compute scopes. The inner repeat clones
the computed expression 2 times; the outer repeat clones the result 3 times.

### Debugger fixture

**`tests/cases/debugger_break_source_line.in`**
```
reason
breakpoints
bt
quit
```

**`tests/cases/debugger_break_source_line.out`**
```
Debugger paused: breakpoint
Breakpoint hit: source 3
Pause reason: breakpoint
Breakpoints:
  [0] source 3
Debugger Stack:
  #0 statement | { ping b }
```

**`tests/cases/debugger_break_source_line.args`**
```
--debugger-cli --break-source=3 tests/modules/debugger_breakpoint_two_statements.m
```

Debugger fixtures are special — the `.in` file contains debugger CLI commands
(sent as stdin), and `.args` specifies the target file path and breakpoints.
The input file (`tests/modules/debugger_breakpoint_two_statements.m`) is the
actual Mantra source under test.

## Naming Conventions

Fixture names use snake_case and follow a consistent pattern:

```
<category>_<feature>_<variant>.in
```

| Category | Examples |
|---|---|
| `assignment` | `assignment_store`, `assignment_lookup_compute` |
| `backtick` | `backtick_nested_repeat_compute` |
| `boolean` | `boolean_and_compute`, `boolean_or_compute` |
| `callable` | `callable_alias_dispatch_basic` |
| `cli` | `cli_set_integer_lookup`, `cli_eval_expr_append` |
| `comparison` | `comparison_equals_true`, `comparison_less_true` |
| `compute` | `compute_scope_expression_add` |
| `concatenate` | `concatenate_array_infix` |
| `debugger` | `debugger_break_callable`, `debugger_step_next` |
| `head_dispatch` | `head_dispatch_select_query` |
| `inference` | `inference_beam_depth_one`, `inference_proof_simple` |
| `selection` | `selection_basic`, `selection_full_match` |
| `transform` | `transform_inline_basic` |
| `viz` | `viz_sin_range`, `viz_invalid_value_break` |

The suffix describes the specific behavior being tested:
- `_basic` — simplest case
- `_compute` — involves `~` compute evaluation
- `_nested` — nested scopes or operators
- `_fail` / `_invalid` — expected error behavior
- `_qualified` — namespaced/qualified access

## Running Tests

Run all 441 fixtures:

```bash
tests/run.sh
```

This builds the binary, then runs all tests in parallel (up to 12 jobs).

```
[build] Compiling mantra...
[pass] assignment_store
[pass] assignment_lookup_compute
...
Summary: 441/441 passed
```

Exit codes: `0` = all pass, `1` = any failed, `2` = argument error or no matches.

### Filter and strict mode

Use `--filter <pattern>` to run a subset (substring match on case name):

```bash
tests/run.sh --filter boolean       # All boolean tests
tests/run.sh --filter debugger      # All debugger tests
```

Use `--strict` for exact output comparison (no whitespace normalization):

```bash
tests/run.sh --strict --filter viz
```

Use `--no-build` to skip recompilation during development:

```bash
tests/run.sh --filter my_new_test --no-build
```

Use `--jobs N` to control parallelism:

```bash
tests/run.sh --jobs 4    # 4 parallel jobs
tests/run.sh --jobs 1    # Serial execution
```

See also: [Filter and Strict Mode](test-fixture-guide/filter-strict.md) for
details on normalization, parallel execution, and fail output.

## Developing New Fixtures

### Workflow

1. **Write the Mantra program** in `tests/cases/<case>.in`.
2. **Run it manually** to capture the actual output:

   ```bash
   ./bin/mantra --raw < tests/cases/<case>.in
   ```

3. **Create `tests/cases/<case>.out`** with the captured output.
4. **Add `.args` if needed** (e.g., `--debug`, `--set`).
5. **Verify the fixture passes**:

   ```bash
   tests/run.sh --filter <case> --no-build
   ```

6. **Run the full suite** to ensure no regressions:

   ```bash
   tests/run.sh --no-build
   ```

### Capturing output for new fixtures

When creating a new fixture, run the program manually to see the raw output:

```bash
# Simple case
echo '{ ~ + 1 2 3 }' | ./bin/mantra --raw

# With args
echo '{ ~ + 1 2 3 }' | ./bin/mantra --raw --debug
```

Copy the output exactly into the `.out` file. Remember that `--raw` is always
added by the test runner, so the output should match what `--raw` produces.

### Multi-line output

Fixtures can produce multiple lines of output. Each line appears on a separate
line in the `.out` file:

```
# Example .out with two output lines
x = [ + 1 + 2 + 3 ]
[ + 6 ]
```

### Fixtures with imports

Some fixtures import packages or include files. The `.in` file contains the
full program including `import` or `include` statements:

```mantra
# tests/cases/viz_sin_range.in
import viz;

k = 0.2;
step = 0.2;

{ viz.line_range "chart" ( -k .. k by step ) ( sin x ) };
{ assign_path "chart.width" 640 };
{ assign_path "chart.height" 400 };
{ viz.show "chart" }
```

The imported packages are resolved from `packages/` at runtime.

## Whitespace Normalization

By default, the test runner normalizes whitespace before comparison:

1. Strip carriage returns (`\r`).
2. Collapse all whitespace runs (spaces, tabs, newlines) into single spaces.
3. Strip leading/trailing spaces from each line.
4. Remove blank lines.

This means fixtures are resilient to formatting differences. If you need exact
whitespace matching, use `--strict`.

## Fixtures and the Manual

Fixture tests serve a dual purpose: they verify runtime behavior AND they
provide tested examples for the user manual. When writing manual pages:

1. Source examples from real test fixtures in `tests/cases/`.
2. Reference the fixture file in comments:

   ```mantra
   # tests/cases/compute_scope_expression_add.in
   ` + 1 2 3 `
   ```

3. If you add a new example to the manual, consider adding a corresponding
   fixture to keep it tied to the actual runtime.

See also: [Fixture-Backed Behavior](../language-model/stability-notes/fixture-backed-behavior.md).

## Common Patterns

### Testing with `--set` (predefined variables)

Use an `.args` file with `--set` to predefine variables:

```text
# <case>.args
--set n=5
--set rules='[ x => x + 1 ]'
```

```mantra
# <case>.in
print { n }
```

### Testing inference with beam width

```text
# <case>.args
--beam-width=2
--congruence-budget=10
```

### Testing event logging

```text
# <case>.args
--event-log
```

or with specific log levels:

```text
# <case>.args
--event-log=diag,json
```

### Testing with file input (debugger)

```text
# <case>.args
--debugger-cli --break-source=3 tests/modules/debugger_breakpoint_two_statements.m
```

## Troubleshooting

### Fixture passes alone but fails in the full suite

Check for shared state. Fixtures should be self-contained — each runs in a
fresh process. If a test depends on a previous test's output, it's flaky.

### Whitespace-related failures

If a test fails with `--strict` but passes normally, the difference is likely
whitespace. Run without `--strict` to confirm:

```bash
tests/run.sh --filter failing_case --no-build
```

### Missing `.out` file

The runner skips cases where `.out` is missing, printing `[skip]`. Ensure both
`.in` and `.out` exist before running.

### Build errors

If the binary hasn't been built, the runner compiles it automatically. Use
`--no-build` only when you're certain the binary is current. To rebuild:

```bash
tests/run.sh
```

## Args Files

For detailed coverage of `.args` files — format, all supported flags, debugger
configurations, and complete examples — see [Args Files](test-fixture-guide/args-files.md).

## Filter and Strict Mode

For detailed coverage of `--filter`, `--strict`, `--no-build`, `--jobs`, exit
codes, and common workflows — see [Filter and Strict Mode](test-fixture-guide/filter-strict.md).
