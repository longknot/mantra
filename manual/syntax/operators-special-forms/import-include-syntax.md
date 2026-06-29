# Import and Include Syntax

Mantra supports two directives for bringing external source into the current
program at runtime:

- **`import`** — loads a named package, resolves its dependency chain, and
  injects the flattened source
- **`include`** — injects the literal source of a file by filesystem path

Both are processed at **runtime evaluation**. When their AST nodes execute, they
resolve source files, append the resolved contents to the program buffer, and
then delete themselves from the AST. The imported/included code becomes part of
the running program as if it had been written inline.

Additionally, during **compile-time**, the `module_loader` preprocessor resolves
import/include chains for files passed as arguments to the interpreter, so
multi-file programs load correctly before execution begins.

```mantra
import demo/core;
include "helpers.m";
```

## Import

The `import` directive loads a named package, walks its dependency chain, and
injects the resolved source. Package names are resolved via the directory tree
and optional external package roots.

### Syntax

```mantra
import <package_path>;
import <package_path>; // comment
import <package_path> <angle-bracket-form>;
```

- `<package_path>` — forward-slash-separated logical path (e.g., `demo/core/sub`)
  - Spaces are stripped from the path
  - Backslashes (`\`) are normalized to forward slashes (`/`)
  - Leading and trailing slashes are removed
  - Empty segments, `.`, and `..` are rejected as invalid
- The path can be bare or wrapped in angle brackets (`<demo/core>`)
- A trailing semicolon is optional
- A trailing comment after the semicolon is allowed

### Behavior

The full resolution pipeline:

1. **Tokenize and parse** — the tokenizer emits `TK_IMPORT`; the parser creates
   a `TImportNode` and parses the following expression as the package path.
2. **Normalize** — `NormalizeImportPath` strips spaces, converts backslashes,
   and trims leading/trailing slashes.
3. **Resolve entry file** — `ResolvePackageEntryFile` walks up the directory
   tree from the current file's directory, checking each `packages/`
   subdirectory for the entry file:
   - `packages/<package_path>.m` (e.g., `packages/demo/core.m`)
   - `packages/<package_path>/package.m` (e.g., `packages/demo/core/package.m`)
4. **Cycle detection** — before loading, the resolver checks
   `FLoadingPackages`. If the package is already in the current resolution
   chain, it raises `Import cycle detected: A -> B -> A`.
5. **Parse the module** — `ResolveFile` reads the entry file line by line:
   - Skips the `package` declaration line (validates it matches the expected
     package name)
   - Recursively resolves any nested `include` directives
   - Recursively resolves any nested `import` directives
   - Appends all other lines to the output buffer with source-file tracking
6. **Namespace switching** — the context pushes the package namespace,
   processes all lines, then pops back to the caller's namespace.
7. **Deduplication** — after loading, the package is added to `FLoadedPackages`.
   Subsequent imports of the same package are skipped entirely.
8. **Self-deletion** — the `TImportNode` deletes itself from the AST after
   injecting the source.

### Package Resolution Order

When you `import demo/core`, the loader searches in this order:

1. Starting from the current file's directory, walk up the tree looking for a
   `packages/` subdirectory at each level.
2. In each `packages/` found, try both entry file forms (`.m` and `/package.m`).
3. If the filesystem search fails, check external package roots configured via
   `--package-root`.
4. If nothing resolves, raise `Package not found: <path>`.

### External Package Roots

Use `--package-root` to add custom package search directories:

```bash
mantra --package-root=/opt/mylibs main.m
```

Each `--package-root` adds a directory whose `packages/` subdirectory will be
searched. Multiple `--package-root` flags are supported.

```mantra
# main.m
import acme/tools;
print { acme.tools.answer };
```

With `--package-root=/opt/mylibs`, the loader will find
`/opt/mylibs/packages/acme/tools/package.m`.

### Transitive Imports

Imports are transitive. If package `A` imports `B` and `B` imports `C`,
importing `A` loads `B` and `C` automatically. Each package is loaded only
once due to the deduplication check.

```mantra
# packages/demo/core/package.m
package demo/core;

import demo/core/alpha;
import demo/core/sub;

pa = demo.core.alpha.pa;
pb = demo.core.sub.beta.pb;
```

### Import Chain Example

```
packages/
  demo/
    core/
      package.m      ← declares "package demo/core;"
      alpha.m
      sub/
        package.m    ← declares "package demo/core/sub;"
        beta.m
```

```mantra
# main.m
import demo/core;
print { demo.core.pa demo.core.pb };
```

### Debugger Support

When the debugger is attached, `TImportNode` emits `dekImportEnter` before
resolving and `dekImportExit` after, with a `TDebuggerFrame` keyed to the
package path. Breakpoints can be set at import boundaries.

## Include

The `include` directive injects the literal source of another file by filesystem
path. Unlike `import`, it does not use package names or namespace switching.

### Syntax

```mantra
include "path/to/file.m";
include 'path/to/file.m';
include "file.m" // comment
```

- The path is wrapped in single or double quotes
- The path is resolved relative to the including file's directory
- Absolute paths (starting with `/` or a drive letter on Windows) are resolved
  directly
- A trailing semicolon and comment are allowed

### Behavior

1. **Parse** — `TIncludeNode` is created; the following expression is parsed as
   the include path.
2. **Resolve path** — `ResolveIncludePath`:
   - If the path has a drive letter or starts with `/`, it is absolute
   - Otherwise, it is resolved relative to the including file's directory
     (`BaseDir + IncludePath`)
3. **Recursive load** — `ResolveFile` reads the target file and:
   - Skips its `package` declaration (if any)
   - Recursively processes its own `include` and `import` directives
   - Appends all other lines to the output buffer
4. **Cycle detection** — `FLoadingFiles` tracks the current resolution chain.
   Re-including the same file within a chain raises `Import cycle detected`.
5. **Deduplication** — after loading, the file is added to `FLoadedFiles`.
   Subsequent includes of the same canonical path are skipped.
6. **Self-deletion** — the `TIncludeNode` deletes itself from the AST after
   injecting the source.

### Include vs Import

| | `include` | `import` |
|---|---|---|
| Resolution | filesystem path | logical package name |
| Search | relative to current file | directory tree + package roots |
| Package declaration | optional, skipped | required, validated |
| Namespace | no namespace switching | pushes/pops package namespace |
| Dedup key | canonical file path | normalized package name |
| Use case | inject raw source, templates, helpers | structured module dependencies |

### Include Example

```mantra
# constants.m
pi = 3.14159;
e = 2.71828;
```

```mantra
# main.m
package main;
include "constants.m";
print { pi + e };
```

### Include Once Behavior

When the same file is included through different paths, it is only injected
once. The deduplication uses the canonical (fully expanded) filesystem path:

```mantra
# main.m
package main;
include "a.m";   ← loads once.m
include "b.m";   ← also references once.m, skipped
```

```mantra
# a.m
package a;
include "once.m";
```

```mantra
# b.m
package b;
include "once.m";   ← deduped, not injected again
```

## Error Messages

| Error | Cause |
|---|---|
| `Package not found: <path>` | No entry file found in any `packages/` directory or package root |
| `Imported module missing package declaration: <path>` | An imported `.m` file has no `package` directive |
| `Imported module package mismatch: expected X but found Y in <path>` | The `package` declaration doesn't match the import path |
| `Import cycle detected: A -> B -> A` | A package or file transitively imports/includes itself |
| `Import file not found: <path>` | An `include` references a non-existent file |
| `Invalid package path: <path>` | The path contains empty segments, `.`, or `..` |

## Related

- [Assignment Syntax](./assignment-syntax.md) — variable binding and deep assignment
- [Rule Declaration Syntax](./rule-declaration-syntax.md) — `rule` keyword and callable bindings
- [Evaluation Scope](../evaluation/evaluation-scope.md) — `{ ... }` scope semantics
