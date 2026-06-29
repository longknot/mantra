# Getting Started

This page walks you through building Mantra from source, running your first
program, and validating that everything works. By the end, you will have a
working runtime, understand the basic input/output cycle, and know where to go
next.

---

## Prerequisites

- Free Pascal Compiler (`fpc`)
- A POSIX-compatible shell such as `bash` or `zsh`
- MkDocs, if you want to preview this manual locally

For installation details, see [Installation and Prerequisites](getting-started/installation-and-prerequisites.md).

---

## Step 1: Build the Runtime

From the repository root, create the output directories and compile:

```bash
mkdir -p bin build
fpc mantra.lpr -FEbin -FUbuild -Fusrc -Px86_64 -Mobjfpc -S2cahi -O1 -gw3 -v0
```

Free Pascal requires `bin/` and `build/` to exist before compilation. The
compiled executable lands at `bin/mantra`.

For more on the build process, see [Building the Runtime](getting-started/building-the-runtime.md).

### Verify the Build

Confirm the binary runs by printing the help screen:

```bash
./bin/mantra --help
```

You should see an ASCII art banner followed by a usage line and a list of CLI
flags. If this works, the build succeeded.

---

## Step 2: Your First Program

The quickest way to run Mantra is to pipe source through standard input:

```bash
echo '[ { 1 2 3 : 4 } ]' | ./bin/mantra
```

This expression creates a list containing an evaluation scope. The `:` (repeat)
operator inside the scope expands `1 2 3` four times. The runtime prints
diagnostic sections in the output:

- `INPUT:` — the source text the runtime received
- `OUTPUT:` — the primary result (used by fixture tests)
- `FORMATTED:` — formatted tree output when available

For a full breakdown of the output sections, see [Reading Runtime Output](getting-started/reading-runtime-output.md).

### Compute Example

Backtick scopes trigger arithmetic reduction. Wrap the full program in single
quotes so the shell does not interpret the backticks:

```bash
echo '`[ + 1 2 3 ] : 3`' | ./bin/mantra
```

The compute scope reduces `+ 1 2 3` to `6`, then the repeat operator clones the
result three times. The expected `OUTPUT` is:

```text
[ + 6 ] [ + 6 ] [ + 6 ]
```

### Variable Assignment

Mantra supports variable binding and tree substitution:

```bash
echo 'x = [ + 1 2 3 ]' | ./bin/mantra
```

The variable `x` is bound to the tree `[ + 1 2 3 ]`. The expected `OUTPUT` is:

```text
x = [ + 1 2 3 ]
```

---

## Step 3: Run Programs from a File

For anything beyond one-liners, write your program to a file:

```bash
cat > hello.m << 'EOF'
x = [ + 1 2 3 ]
`x`
EOF
```

Then run it:

```bash
./bin/mantra hello.m
```

The expected `OUTPUT` has two lines:

```text
x = [ + 1 + 2 + 3 ]
[ + 6 ]
```

The first line is the assignment statement output. The second line is the
compute scope that substitutes `x` and reduces the arithmetic.

---

## Step 4: Interactive Mode

Mantra includes a REPL for exploring expressions interactively:

```bash
./bin/mantra --interactive
```

Type expressions and press Enter to evaluate them. The REPL processes input
incrementally — each line is parsed, executed, and printed before accepting the
next one. This is useful for testing small changes without writing files or
shell pipelines.

---

## Step 5: Run the Test Suite

The test suite validates your build against 370+ fixtures. Run it from the
repository root:

```bash
tests/run.sh
```

Useful options:

```bash
tests/run.sh --no-build   # skip rebuild, just run tests
tests/run.sh --strict     # require exact output match
tests/run.sh --filter repeat  # run only tests matching "repeat"
```

### How Fixtures Work

Each test fixture in `tests/cases/` has three optional files:

- `<name>.in` — input source passed to `./bin/mantra`
- `<name>.out` — expected `OUTPUT` lines for comparison
- `<name>.args` — optional CLI arguments (one per line)

The test runner feeds the `.in` content to the runtime, captures the `OUTPUT:`
section, and compares it against `.out`. A mismatch means the fixture failed.

For full details, see [Test Fixture Guide](reference/test-fixture-guide.md).

---

## Useful CLI Flags

These flags are the most common for everyday use:

| Flag | What It Does |
|---|---|
| `--interactive`, `-i` | Start REPL mode |
| `--debug`, `-d` | Print every statement output |
| `--raw` | Print unformatted tree output |
| `--show-input` | Prefix input lines with `>` |
| `--show-tokens` | Show tokenizer output during compile |
| `--eval`, `-e` | Evaluate output before printing |
| `--eval=EXPR` | Append and run: `print { EXPR }` |
| `--set NAME=EXPR` | Predefine a variable (repeatable) |

For the complete CLI reference, see [Command Line](reference/command-line.md).

---

## Preview the Manual

This manual is built with MkDocs. Install the dependencies and start the
server:

```bash
python -m pip install -r requirements-docs.txt
mkdocs serve
```

Then open the local URL printed by MkDocs in your browser. To build static
HTML instead:

```bash
mkdocs build
```

---

## What to Know After This Page

| Topic | Where to Go |
|---|---|
| What Mantra is and what it aims for | [What Mantra Is](getting-started/what-mantra-is.md) |
| Details on building the runtime | [Building the Runtime](getting-started/building-the-runtime.md) |
| Running programs (stdin, files, shell quoting) | [Running Programs](getting-started/running-programs.md) |
| Understanding runtime output sections | [Reading Runtime Output](getting-started/reading-runtime-output.md) |
| Programs as tree structures | [Language Model](language-model/index.md) |
| Language syntax reference | [Syntax](syntax/index.md) |
| Rewrite and transformation operators | [Transformations and Repeat](transformations/index.md) |
| Arithmetic and compute scopes | [Compute and Operators](compute/index.md) |
| Runnable examples with expected output | [Examples](reference/examples.md) |

The getting-started section is intentionally operational. It should answer:

- what command builds the local runtime
- how a user passes source to `bin/mantra`
- which output line matters for examples
- which shell quoting rules keep examples reproducible
- where to go next for deeper topics
