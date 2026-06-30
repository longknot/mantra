# Package Root

The `--package-root` flag adds external directories to the package search path
for `import` directives. Use it when your project depends on packages that live
outside the local `packages/` directory — for example, shared libraries installed
system-wide or vendored third-party code.

## Usage

```bash
mantra --package-root /opt/mantra-pkgs program.m
```

Two equivalent CLI forms:

```bash
mantra --package-root /opt/mantra-pkgs program.m   # space-separated
mantra --package-root=/opt/mantra-pkgs program.m   # compact form
```

The flag is **repeatable** — use it multiple times to add several search
roots. They are searched in the order they appear on the command line:

```bash
mantra \
  --package-root /opt/mantra-pkgs \
  --package-root ~/my-pkgs \
  program.m
```

### Duplicate Handling

If the same directory appears multiple times (after path expansion to an
absolute path), duplicates are silently ignored. Only the first occurrence
is kept:

```bash
# Only /opt/mantra-pkgs is registered once:
mantra --package-root /opt/mantra-pkgs --package-root /opt/mantra-pkgs program.m
```

### Path Normalization

Relative paths are expanded to absolute paths using the current working
directory. Backslashes in package paths are normalized to forward slashes.
The root must be an existing directory — validation happens at startup
before any source code is parsed.

## Scope: Import Only

`--package-root` affects **only** `import` directives. It has no effect on
`include` directives, which resolve paths relative to the current file's
directory or as absolute filesystem paths.

## Import Resolution Order

When you write `import acme/http`, Mantra searches for the package in this
order:

1. **Local `packages/` (upward walk)** — Starting from the entry file's
   directory, walks up the filesystem tree toward the root. At each level,
   checks `packages/acme/http.m` and `packages/acme/http/package.m`.
2. **Current working directory** — Checks
   `packages/acme/http.m` and `packages/acme/http/package.m` in the
   current directory.
3. **External roots** — Checks each `--package-root` path in command-line
   order. External roots are searched directly (not through a `packages/`
   subdirectory). For `--package-root /opt/mantra-pkgs`, Mantra checks:

   - `/opt/mantra-pkgs/acme/http.m`
   - `/opt/mantra-pkgs/acme/http/package.m`

The first file that exists wins. A visual summary:

```
Entry file: /home/user/project/src/main.m
import acme/http;

Search order:
  /home/user/project/src/packages/acme/http.m           (step 1)
  /home/user/project/src/packages/acme/http/package.m   (step 1)
  /home/user/project/packages/acme/http.m               (step 1)
  /home/user/project/packages/acme/http/package.m       (step 1)
  /home/user/packages/acme/http.m                       (step 1)
  /home/user/packages/acme/http/package.m               (step 1)
  /packages/acme/http.m                                 (step 1)
  /packages/acme/http/package.m                         (step 1)
  <cwd>/packages/acme/http.m                            (step 2)
  <cwd>/packages/acme/http/package.m                    (step 2)
  /opt/mantra-pkgs/acme/http.m                          (step 3)
  /opt/mantra-pkgs/acme/http/package.m                  (step 3)
```

## Entry File Resolution

For each candidate location, Mantra tries two entry files:

1. **`<package-path>.m`** — a single-file package (e.g., `acme/http.m`)
2. **`<package-path>/package.m`** — a directory-based package with a
   `package.m` entry point

The first file that exists is used.

## Package Declaration Requirement

Imported packages **must** declare their package name matching the import
path. For example, `import acme/http;` expects the file to start with:

```mantra
package acme/http;
```

A missing declaration raises:

```
Imported module missing package declaration: /path/to/acme/http/package.m
```

A mismatched declaration raises:

```
Imported module package mismatch: expected acme/http but found acme/utils in /path/to/acme/http/package.m
```

## Package Path Normalization

Package paths in `import` statements are normalized before resolution:

- Spaces are stripped
- Backslashes (`\`) are replaced with forward slashes (`/`)
- Leading and trailing slashes are removed
- Empty segments, `.`, and `..` are rejected

```bash
$ mantra --eval='import a/../b;' program.m
Invalid package path: a/../b
```

## Validation Errors

### Directory not found:

```bash
$ mantra --package-root /nonexistent program.m
Package root not found: /nonexistent
```

### Empty path:

```bash
$ mantra --package-root '' program.m
Invalid --package-root argument: missing path
```

### Missing value (flag is last argument):

```bash
$ mantra --package-root program.m
Missing value for --package-root
```

### Package not found:

When no candidate is found in any search location:

```
Package not found: acme/http (expected packages/acme/http.m, packages/acme/http/package.m, or a configured package root)
```

## Project-Local Packages Take Precedence

If a package exists both in your local `packages/` directory and in an
external root, the local copy always wins. External roots are only consulted
after all local `packages/` directories (including the upward walk and
current working directory) have been exhausted.

This means you can override a third-party package with a local version
simply by placing it in your project's `packages/` directory — no need to
remove or reorder `--package-root` entries.

## Cycle Detection

When resolving imports across external roots, the same cycle detection rules
apply as for local packages. A package that is already being loaded cannot
be loaded again, preventing infinite recursion:

```
Import cycle detected: acme/http -> acme/utils -> acme/http
```

Each package is loaded exactly once per session.

## Practical Example

A common workflow: installing shared packages in a central location and
referencing them from multiple projects.

```bash
# Create a shared package root:
mkdir -p /opt/mantra-pkgs/utils

# Write a package:
cat > /opt/mantra-pkgs/utils/package.m << 'EOF'
package utils;

. cat = [ a b => [ & a & b ] ];
EOF

# Use it from any project:
mantra --package-root /opt/mantra-pkgs program.m
```

```mantra
# program.m
package main;
import utils;

print { utils.cat [ 1 2 3 ] [ 4 5 6 ] [ 7 ] };
```

## Troubleshooting

### "Package not found" despite correct `--package-root`

- Verify the path exists: `ls /opt/mantra-pkgs/acme/http.m`
- Check the package declaration matches: `head -1 /opt/mantra-pkgs/acme/http/package.m`
- Remember external roots are searched directly — the file should be at
  `<root>/acme/http.m`, not `<root>/packages/acme/http.m`

### "Package mismatch" error

The `package` directive in the file must exactly match the import path.
`import acme/http;` requires `package acme/http;` — not
`package http;` or `package acme/http_client;`.

### Import works locally but not with `--package-root`

If the package is found in your local `packages/` but not from the external
root, verify that the external copy has the same directory structure and
package declaration as the local version.

## See Also

- [Common Options](common-options.md) — Overview of all runtime flags
- [Input Files and REPL](common-options/input-files-repl.md) — File input modes
- [Packages and Imports](../../data/namespaces-packages/packages-imports.md) — Package system overview
- [Import and Include Syntax](../../syntax/import-include-syntax.md) — Import and include directives
