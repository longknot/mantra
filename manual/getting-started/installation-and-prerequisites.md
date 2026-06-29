# Installation and Prerequisites

This page covers everything you need to install and configure before building
and running Mantra. It also covers the optional documentation toolchain for
building this manual.

---

## System Requirements

| Requirement | Minimum | Notes |
|---|---|---|
| Architecture | x86_64 | Build flags target `-Px86_64` |
| OS | Linux / macOS / WSL | POSIX-compatible environment required |
| Shell | `bash` or `zsh` | Used by `tests/run.sh` and build commands |
| Free Pascal Compiler | 3.0+ | 3.3.1 tested; install via package manager |
| Python 3 | 3.8+ | Optional — needed for MkDocs manual builds |

Mantra is implemented entirely in Free Pascal. No C compiler, linker, or
runtime dependency is required beyond what Free Pascal itself provides.

---

## Required: Free Pascal Compiler

The runtime is a single Free Pascal program. Install `fpc` through your
distribution's package manager:

### Debian / Ubuntu

```bash
sudo apt-get update
sudo apt-get install fpc
```

### Arch Linux

```bash
sudo pacman -S fpc
```

### Fedora

```bash
sudo dnf install fpc
```

### macOS (Homebrew)

```bash
brew install fpc
```

### Verify Installation

```bash
fpc -iV
```

This prints the compiler version (e.g., `3.3.1`). If the command is not found,
ensure the `fpc` binary is on your `PATH`.

---

## Required: POSIX Shell

The test runner (`tests/run.sh`) and build instructions use `bash` syntax
(`set -euo pipefail`, process substitution, arrays). Any POSIX-compatible
shell works, but `bash` is the tested and recommended choice.

### Verify Shell

```bash
bash --version
```

You should see version information. On most Linux distributions, `bash` is
installed by default. On macOS, it is also available at `/bin/bash`.

---

## Required: Standard Build Tools

The build process uses common Unix utilities to create directories and invoke
the compiler. These should be present on any standard development system:

| Tool | Used For |
|---|---|
| `mkdir` | Create `bin/` and `build/` output directories |
| `make` | Optional — not required by the build |

The compiler invocation does not depend on `make`, `cmake`, or similar build
systems. The single `fpc` command handles everything.

---

## Build Output

After a successful build, the compiled executable is at:

```text
bin/mantra
```

Intermediate `.ppu` unit files are placed under `build/`. Neither directory
needs to be committed to version control — both should be in `.gitignore`.

### Build Command

```bash
mkdir -p bin build
fpc mantra.lpr -FEbin -FUbuild -Fusrc -Px86_64 -Mobjfpc -S2cahi -O1 -gw3 -v0
```

The flags mean:

| Flag | Purpose |
|---|---|
| `-FEbin` | Place the compiled executable in `bin/` |
| `-FUbuild` | Place intermediate `.ppu` files in `build/` |
| `-Fusrc` | Search `src/` for unit files |
| `-Px86_64` | Target x86_64 architecture |
| `-Mobjfpc` | Use ObjFPC mode (required for VMT dispatch) |
| `-S2cahi` | Enable extended string/char handling |
| `-O1` | Optimization level 1 |
| `-gw3` | Full debug info (for debugger support) |
| `-v0` | Minimal compiler verbosity |

Free Pascal requires the output directories (`bin/` and `build/`) to exist
before compilation. The `mkdir -p` command ensures this.

For build details, see [Building the Runtime](getting-started/building-the-runtime.md).

---

## Verify the Installation

After building, confirm the runtime works:

### Help Output

```bash
./bin/mantra --help
```

You should see an ASCII art banner followed by the usage line and a complete
list of CLI flags.

### Quick Expression

```bash
echo '[ { 1 2 3 : 4 } ]' | ./bin/mantra
```

You should see diagnostic output sections including `INPUT:`, `OUTPUT:`, and
potentially `FORMATTED:`.

### Run the Test Suite

```bash
tests/run.sh
```

The test runner builds the runtime (if needed) and validates it against 370+
fixtures. All tests should pass on a fresh checkout.

Useful options:

```bash
tests/run.sh --no-build     # skip rebuild, just run tests
tests/run.sh --strict       # exact output match (no whitespace normalization)
tests/run.sh --filter repeat  # run only tests matching "repeat"
```

For fixture details, see [Test Fixture Guide](reference/test-fixture-guide.md).

---

## Optional: Documentation Toolchain

This manual is built with MkDocs. Install the dependencies from the repository
root:

```bash
python -m pip install -r requirements-docs.txt
```

The `requirements-docs.txt` file pins:

- `mkdocs>=1.6,<2`
- `mkdocs-material>=9.5,<10`

### Serve the Manual Locally

```bash
mkdocs serve
```

This starts a local development server. Open the printed URL in your browser
to preview the manual with live reload.

### Build Static HTML

```bash
mkdocs build
```

This generates a static site under `site/` suitable for deployment to GitHub
Pages or any static hosting service.

### MkDocs Configuration

The MkDocs configuration lives at `mkdocs.yml` in the repository root. It:

- Points `docs_dir` to `manual/`
- Uses the Material theme with a blue/amber palette
- Links the GitHub repository at `https://github.com/longknot/mantra`
- Defines the full navigation structure across all manual sections

---

## Package Library

The repository includes a package library under `packages/` with reusable
Mantra modules. These are not required to build the runtime but are available
for importing into your programs:

| Package | Contents |
|---|---|
| `math/` | Mathematical axioms, calculus, constants, vector operations |
| `parse/` | Parsing utilities |
| `proof/` | Proof rules and distributive/commutative laws |
| `sort/` | Merge sort implementation |
| `utils/` | String concatenation, trie, rewrite helpers, witness output |
| `vectors/` | Vector operations |
| `viz/` | Vega-Lite visualization output |

Packages are imported in Mantra source using the `import` keyword. For details,
see [Packages and Imports](data/namespaces-packages/packages-imports.md).

---

## Troubleshooting

### `fpc: command not found`

Free Pascal is not installed or not on your `PATH`. Install it via your
package manager (see above) and verify with `fpc -iV`.

### `Error: Can't find unit ...`

The `-Fusrc` flag tells the compiler to search `src/` for units. Ensure you
are running the build command from the repository root and that the `src/`
directory exists and is not empty.

### Build succeeds but `bin/mantra` crashes

Run the test suite to check for fixture failures:

```bash
tests/run.sh --strict
```

If specific tests fail, check the `tests/cases/` directory for the `.in` and
`.out` files of the failing fixture to compare expected vs actual output.

### `tests/run.sh` reports shell errors

Ensure you are using `bash` and not a minimal POSIX shell. Run:

```bash
bash tests/run.sh
```

to explicitly invoke bash.

### `mkdocs: command not found`

The documentation dependencies are not installed. Run:

```bash
python -m pip install -r requirements-docs.txt
```

from the repository root.

### Windows users

Mantra builds under WSL (Windows Subsystem for Linux). Install WSL with
Ubuntu or Debian, then follow the Linux installation steps above. Mantra
does not currently support native Windows builds — the runtime depends on
POSIX APIs (`BaseUnix`) and the test runner uses bash.

---

## Summary

| Component | Required | Install Command |
|---|---|---|
| Free Pascal (`fpc`) | Yes | `apt-get install fpc` / `pacman -S fpc` / `brew install fpc` |
| Bash shell | Yes | Pre-installed on most Linux; `/bin/bash` on macOS |
| Python 3 + pip | Optional (docs) | Pre-installed on most Linux; `brew install python` on macOS |
| MkDocs | Optional (docs) | `pip install -r requirements-docs.txt` |

The repository does not currently define a full package installation flow for
the runtime itself — you build the local checkout directly and run `bin/mantra`
from the repository.

For the next step, see [Building the Runtime](getting-started/building-the-runtime.md)
or proceed through the full walkthrough on [Getting Started](../getting-started.md).
