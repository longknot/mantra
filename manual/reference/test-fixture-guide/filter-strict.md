# Filter and Strict Mode

The test runner (`tests/run.sh`) supports several options for controlling which
tests execute, how strictly output is compared, and whether to rebuild the
binary first.

## Running All Tests

```bash
tests/run.sh
```

Runs all 400+ fixture cases. Builds the binary first, then executes tests in
parallel (up to 12 jobs). Prints `[pass]` or `[fail]` per case, followed by
a summary line:

```
Summary: 441/441 passed
```

Exit code is `0` when all tests pass, `1` when any fail, and `2` for argument
errors or no matching cases.

## Filter: Running a Subset of Tests

Use `--filter <pattern>` to run only cases whose filename contains `<pattern>`
as a substring. The pattern matches against the case name (filename without
the `.in` extension).

```bash
# Run only the "repeat" fixture
tests/run.sh --filter repeat

# Run all json-related fixtures
tests/run.sh --filter json

# Run a specific inference test
tests/run.sh --filter inference_beam
```

The filter performs a simple substring match — not a regex. Any case whose
name contains the pattern will be selected. If no cases match, the runner
prints `No test cases selected.` and exits with code `2`.

### Combining Filter with Other Options

```bash
# Run filtered tests without rebuilding
tests/run.sh --filter repeat --no-build

# Run filtered tests with strict comparison
tests/run.sh --filter json --strict
```

## Strict Mode: Exact Output Comparison

By default, the test runner **normalizes whitespace** before comparing output.
This makes fixtures resilient to formatting differences that don't affect
semantic correctness.

### Default (Non-Strict) Normalization

When `--strict` is **not** set, both the expected output (`.out`) and the
actual runtime output are processed through this normalization:

1. Strip carriage returns (`\r`).
2. Collapse all runs of whitespace (spaces, tabs, newlines) into single spaces.
3. Strip leading and trailing spaces from each line.
4. Remove blank lines.

This means that differences in indentation, extra blank lines, or tabs vs
spaces between the fixture and actual output will **not** cause a failure.

### Strict Mode

When `--strict` **is** set, only carriage returns are stripped. Everything
else — spaces, tabs, blank lines, indentation — must match exactly.

```bash
tests/run.sh --strict
```

### When to Use Strict Mode

Use `--strict` when:
- The fixture tests output formatting, alignment, or whitespace-sensitive
  rendering (e.g., `display` or visualization outputs).
- You want to catch unintended formatting regressions early.
- Debugging a test that passes normally but produces unexpected whitespace.

Use the default (non-strict) mode when:
- The fixture tests semantic correctness and formatting details are irrelevant.
- The output naturally varies in whitespace across platforms or compiler
  versions.

### Fail Output

When a test fails, the runner shows the input, expected output, and actual
output, each indented with four spaces:

```
[fail] some_case
  input:
    ` + 1 2 `
  expected OUTPUT line(s):
    + 3
  actual OUTPUT line(s):
    + 5
```

## Skip Build

Use `--no-build` to skip the compilation step when the binary is already
current:

```bash
tests/run.sh --no-build
```

By default, the runner compiles before every run:

```bash
fpc mantra.lpr -FEbin -FUbuild -Fusrc -Fuvendor/* -Px86_64 -Mobjfpc -S2cahi -O1 -gw3 -v0
```

Use `--no-build` during development when iterating on fixtures without
changing the source code to save build time.

## Parallel Execution

The test runner executes cases in parallel using GNU `parallel`. The default
is 12 concurrent jobs.

```bash
# Run with 4 parallel jobs
tests/run.sh --jobs 4

# Run serially (one at a time)
tests/run.sh --jobs 1
```

If GNU `parallel` is not installed, the runner falls back to serial execution
automatically. If you explicitly set `--jobs N` with `N > 1` and `parallel`
is missing, the runner exits with an error suggesting you install it or use
`--jobs 1`.

## Option Reference

| Option | Description |
|---|---|
| `--no-build` | Skip rebuilding the mantra binary |
| `--strict` | Compare output exactly (no whitespace normalization) |
| `--filter <name>` | Run only cases whose name contains `<name>` |
| `--jobs <N>` | Run up to N cases in parallel (default: 12) |
| `-h, --help` | Show usage help |

## Common Workflows

### Develop a new fixture

```bash
# 1. Create the fixture files
echo '` + 1 2 3 `' > tests/cases/my_test.in
echo '+ 6' > tests/cases/my_test.out

# 2. Run just your test
tests/run.sh --filter my_test --no-build

# 3. Once it passes, run the full suite
tests/run.sh --no-build
```

### Debug a failing test

```bash
# Run the failing test with verbose output
tests/run.sh --filter failing_case --no-build

# Check if it's a whitespace issue
tests/run.sh --filter failing_case --strict --no-build
```

### Run before committing

```bash
# Full build and test
tests/run.sh
```

## See Also

- [Test Fixture Guide](../test-fixture-guide.md) — Fixture format overview
- [Args Files](args-files.md) — CLI arguments in `.args` files
- [Command Line](../command-line.md) — Complete mantra CLI reference
