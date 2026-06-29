# Contributing to Mantra

Mantra is experimental alpha software. Contributions are welcome, but language
syntax, runtime behavior, and internal APIs may change without compatibility
guarantees.

## Before Opening a Change

- Check whether the behavior is already covered by the manual or an existing
  test fixture.
- Keep changes focused. Separate language semantics, refactoring, and
  documentation changes where practical.
- For syntax or semantic changes, describe the intended behavior before the
  implementation details.
- Do not commit generated binaries, compiler output, editor state, or local
  debugging artifacts.

## Building

Mantra requires the Free Pascal Compiler and a POSIX shell.

```bash
mkdir -p bin build
fpc mantra.lpr -FEbin -FUbuild -Fusrc -Fu"vendor/*" \
  -Px86_64 -Mobjfpc -S2cahi -O1 -gw3 -v0
```

To build the runtime, HTTP server, and MCP server:

```bash
./build.sh --all
```

## Testing

Run the fixture suite:

```bash
tests/run.sh
```

After an existing build, use:

```bash
tests/run.sh --no-build
```

Additional smoke tests:

```bash
tests/server_smoke.sh --no-build
tests/mcp_smoke.sh --no-build
```

New language behavior and bug fixes should normally include a fixture under
`tests/cases`:

- `<name>.in` contains input passed to `bin/mantra`.
- `<name>.out` contains the expected `OUTPUT` line.
- `<name>.args`, when needed, contains command-line arguments for the fixture.

Prefer a small regression fixture over a large integration example. Run a
focused fixture with:

```bash
tests/run.sh --filter <name>
```

Run the strict suite before submitting broader runtime changes:

```bash
tests/run.sh --strict
```

## Reporting Bugs

A useful bug report includes:

- a minimal Mantra input that reproduces the problem;
- the actual and expected `OUTPUT`;
- the command and options used;
- operating system, architecture, and Free Pascal version;
- whether the problem occurs on the current default branch.

Crashes, hangs, incorrect rewrites, and inconsistent results from equivalent
inputs are particularly useful reports during alpha.

For security-sensitive reports, follow [SECURITY.md](SECURITY.md) instead of
opening a public issue.

## Proposing Language Changes

Language changes should explain:

- the user problem being solved;
- the proposed syntax and semantics;
- interactions with evaluation, rewriting, namespaces, scopes, and inference;
- compatibility or ambiguity risks;
- representative examples and expected output.

An implementation may still be declined if the semantics are not sufficiently
clear or if the feature expands the core language without a compelling need.

## Documentation

Update the relevant files under `manual/` when changing public behavior. Avoid
documenting planned behavior as if it were implemented.

## Pull Requests

Before submitting a pull request:

- ensure the relevant tests pass;
- add regression coverage where applicable;
- update public documentation for behavior changes;
- summarize known tradeoffs or remaining limitations;
- keep unrelated generated or formatting changes out of the diff.

