# Building the Runtime

Compile the Mantra runtime from source using the Free Pascal Compiler (`fpc`).
The build produces a single executable at `bin/mantra` with no external runtime
dependencies.

## Quick Build

From the repository root:

```bash
mkdir -p bin build
fpc mantra.lpr -FEbin -FUbuild -Fusrc -Px86_64 -Mobjfpc -S2cahi -O1 -gw3 -v0
```

Free Pascal requires the output directories (`bin/` and `build/`) to exist
before compilation begins.

## Build Command Reference

| Flag | Purpose |
|---|---|
| `-FEbin` | Place the compiled executable in `bin/` |
| `-FUbuild` | Place intermediate `.ppu` unit files in `build/` |
| `-Fusrc` | Search `src/` for source unit files |
| `-Fuvendor/*` | Search `vendor/` subdirectories for third-party units |
| `-Px86_64` | Target x86_64 architecture |
| `-Mobjfpc` | Use ObjFPC mode (required for VMT dispatch) |
| `-S2cahi` | Enable extended string/char handling |
| `-O1` | Optimization level 1 |
| `-gw3` | Full debug information (for debugger support) |
| `-v0` | Minimal compiler verbosity |

The test runner (`tests/run.sh`) uses `-Fuvendor/*` in addition to the flags
above to pick up third-party dependencies in `vendor/`. For a standalone build,
`-Fusrc` suffices since the main runtime has no external dependencies.

## What Gets Built

### `mantra.lpr` — Main Runtime

The entry point at `mantra.lpr` includes `mantra.inc` (compiler directives) and
links all units under `src/`:

- `exp_tokenizer.pas` — Tokenizer (source text to token stream)
- `mathparser.pas` — Parser (token stream to AST)
- `exp_trees.pas` — Core tree storage (`TTreeNode`, `TCustomTree`)
- `nodes.pas` — Node object hierarchy and VMT dispatch
- `context.pas` — Runtime variable context
- `matcher_ir.pas` — Structural pattern matcher and rewrite engine
- `inference.pas` — Inference / proof-search (`|=` operator)
- `formatters.pas` — Tree-to-string output formatting
- `debugger_*.pas` — Debugger subsystem (event recorder, CLI, postmortem)

The `RegisterObjects` procedure in `nodes.pas` populates the `VMT_TABLE` that
maps node IDs to their behavior classes — this is where Mantra's dispatch
system is wired together.

### Server Variants

Two additional entry points exist:

- `mantra_server.lpr` — MCP server implementation
- `mantra_mcp_server.lpr` — Alternative MCP server variant

These are compiled separately and are not part of the default build.

## Output

The compiled executable is written to `bin/mantra`. Intermediate `.ppu` unit
files are placed under `build/`. Neither directory should be committed to
version control.

### Verify the Build

Confirm the binary runs by printing the help screen:

```bash
mantra --help
```

You should see an ASCII art banner followed by a usage line and a list of CLI
flags. If this works, the build succeeded.

### Run a Quick Test

```bash
echo '[ { 1 2 3 : 4 } ]' | mantra
```

You should see diagnostic output sections including `INPUT:`, `OUTPUT:`, and
`FORMATTED:`.

## Build Variants

### Debug Build

The default flags include `-gw3` for full debug information. This is required
for the debugger subsystem (`--debugger`, `--debugger-cli`) to function.

### Release Build

To optimize for size and speed, remove the debug flag and increase optimization:

```bash
mkdir -p bin build
fpc mantra.lpr -FEbin -FUbuild -Fusrc -Px86_64 -Mobjfpc -S2cahi -O3 -v0
```

Note that without `-gw3`, the `--debugger` and `--debugger-cli` flags will
have reduced functionality.

### Cross-Architecture

To target a different architecture, change the `-P` flag:

```bash
fpc mantra.lpr -FEbin -FUbuild -Fusrc -Pi386 -Mobjfpc -S2cahi -O1 -gw3 -v0
```

## Rebuilding

You can rebuild by running the same command again. Free Pascal will
automatically recompile only units that have changed since the last build.

To do a full clean rebuild:

```bash
rm -rf bin build
mkdir -p bin build
fpc mantra.lpr -FEbin -FUbuild -Fusrc -Px86_64 -Mobjfpc -S2cahi -O1 -gw3 -v0
```

The test runner handles this automatically — `tests/run.sh` rebuilds before
running unless you pass `--no-build`.

## Troubleshooting

### `fpc: command not found`

Free Pascal is not installed or not on your `PATH`. Install it via your
package manager and verify with `fpc -iV`. See [Installation and
Prerequisites](installation-and-prerequisites.md) for instructions.

### `Error: Can't find unit ...`

The `-Fusrc` flag tells the compiler to search `src/` for units. Ensure you
are running the build command from the repository root and that the `src/`
directory exists and contains the source files.

### `Error: Can't find unit ... (vendor)`

Some units may live under `vendor/`. Add `-Fuvendor/*` to the build command or
run `tests/run.sh` which includes this flag automatically.

### Build Succeeds But `bin/mantra` Crashes

Run the test suite to check for fixture failures:

```bash
tests/run.sh --strict
```

Inspect failing fixtures in `tests/cases/` to compare expected vs. actual
output.

### `bin/mantra: not a regular file`

If you previously ran the build with a different `-FE` target, a stale binary
or directory may exist. Clean and rebuild:

```bash
rm -rf bin build
mkdir -p bin build
fpc mantra.lpr -FEbin -FUbuild -Fusrc -Px86_64 -Mobjfpc -S2cahi -O1 -gw3 -v0
```

## Related Pages

- [Installation and Prerequisites](installation-and-prerequisites.md) — Installing Free Pascal and dependencies
- [Getting Started](../getting-started.md) — Full walkthrough from build to first program
- [Command Line](reference/command-line.md) — Complete CLI flag reference
