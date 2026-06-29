# Package, Import, Include, and Global Directives

Mantra provides four directives for module management and namespace control:

- **`package`** — declares the module identity and namespace for a file
- **`import`** — loads a named package and injects its resolved source
- **`include`** — injects the literal source of a file by path
- **`global`** — escapes scope boundaries to write to global (or namespaced) variables

All four are recognized at the tokenizer level (`TK_PACKAGE`, `TK_IMPORT`, `TK_INCLUDE`, `TK_GLOBAL`) and produce AST nodes (`TPackageNode`, `TImportNode`, `TIncludeNode`, `TGlobalNode`).

## Package

The `package` directive declares the module identity of the current file. It must appear as the first directive in a module entry file.

```mantra
package demo/core;
```

### Syntax

```mantra
package <package_path>;
```

- `<package_path>` — a forward-slash-separated path (e.g., `demo/core/sub`)
  - Spaces are stripped
  - Backslashes are converted to forward slashes
  - Leading and trailing slashes are removed
  - Empty segments, `.`, and `..` are rejected as invalid

### Behavior

1. The parser creates a `TPackageNode` and parses the following expression as the package path.
2. At runtime, the module loader reads each line of a module file. The first line matching `package <path>;` is parsed and stored as `DeclaredPackage`.
3. When a module is loaded via `import`, the loader validates that the declared package matches the imported path (the `RequirePackageMatch` check). A mismatch raises an exception.
4. The package name becomes the **effective namespace** — the context switches to that namespace via `PushSettingNamespace`, and variable writes are qualified with it.
5. After the module finishes loading, the context pops back to the caller's namespace via `PopSettingNamespace`.

### Package Resolution

When you `import demo/core`, the module loader searches for the entry file using this resolution order:

1. Starting from the current directory, walk up the directory tree looking for a `packages/` subdirectory.
2. In each `packages/` directory found, try:
   - `packages/<package_path>.m` (e.g., `packages/demo/core.m`)
   - `packages/<package_path>/package.m` (e.g., `packages/demo/core/package.m`)
3. If the filesystem search fails, check any external package roots configured via `--package-root`.
4. If nothing resolves, raise `Package not found: <path>`.

### Example

```
packages/
  demo/
    core/
      package.m    ← declares "package demo/core;"
      alpha.m
      sub/
        package.m  ← declares "package demo/core/sub;"
        beta.m
```

```mantra
# packages/demo/core/package.m
package demo/core;

pa = 42;
```

```mantra
# main.m
import demo/core;
print { demo.core.pa }  → 42
```

### External Package Roots

Use `--package-root` to add custom package search directories:

```bash
mantra --package-root=tests/third_party_packages main.m
```

Each `--package-root` adds a directory whose `packages/` subdirectory will be searched. The path argument can also use the `--package-root=<path>` combined form.

```mantra
# main.m
package main;
import acme/tools;
print { acme.tools.answer };
```

With `--package-root=tests/third_party_packages`, the loader will find `tests/third_party_packages/acme/tools/package.m`.

## Import

The `import` directive loads a named package, resolves its source chain, and injects the resolved output.

### Syntax

```mantra
import <package_path>;
```

- `<package_path>` — a forward-slash-separated package path (same format as `package`)
- The path can be wrapped in angle brackets (`import <demo/core>;`) or written bare (`import demo/core;`)

### Behavior

The full resolution pipeline:

1. **Tokenize and parse** — the tokenizer emits `TK_IMPORT`; the parser creates a `TImportNode` and parses the following expression as the package path.
2. **Resolve entry file** — `ResolvePackageEntryFile` walks up the directory tree from the current file's directory, checking each `packages/` subdirectory for the entry file (`.m` or `/package.m`).
3. **Cycle detection** — before loading, the resolver checks `FLoadingPackages`. If the package is already in the current resolution chain, it raises `Import cycle detected`.
4. **Parse the module** — `ResolveFile` reads the entry file line by line:
   - Skips the `package` declaration line (validates it matches expected)
   - Recursively resolves any nested `include` directives
   - Recursively resolves any nested `import` directives
   - Appends all other lines to the output buffer with source file tracking
5. **Namespace switching** — the context pushes the package namespace, processes all lines, then pops back.
6. **Deduplication** — after loading, the package is added to `FLoadedPackages`. Subsequent imports of the same package are skipped.
7. **Caller restoration** — if there is a caller package, a `package <caller>;` line is injected to restore the caller's namespace.

### Import Chain Example

```
packages/
  demo/
    core/
      package.m    → imports demo/core/alpha, demo/core/sub
      alpha.m
      sub/
        package.m  → imports demo/core/sub/beta, demo/core/sub/inner
        beta.m
        inner.m
```

```mantra
# packages/demo/core/package.m
package demo/core;

import demo/core/alpha;
import demo/core/sub;

pa = demo.core.alpha.pa;
pb = demo.core.sub.beta.pb;
pc = demo.core.sub.deeper.gamma.pc;
```

When `import demo/core` is processed, the loader recursively resolves `demo/core/alpha`, `demo/core/sub`, `demo/core/sub/beta`, `demo/core/sub/inner`, etc., building a complete flattened output with source-file tracking.

### Transitive Imports

Imports are transitive. If `A` imports `B` and `B` imports `C`, importing `A` also loads `B` and `C`. Each package is only loaded once due to the deduplication check.

## Include

The `include` directive injects the literal source of another file by path.

### Syntax

```mantra
include "path/to/file.m";
```

- `path/to/file.m` — a file path wrapped in single or double quotes
- The path is resolved relative to the including file's directory
- Absolute paths (starting with `/` or a drive letter) are resolved directly

### Behavior

1. **Parse** — `TIncludeNode` is created; the following expression is parsed as the include path.
2. **Resolve path** — `ResolveIncludePath`:
   - If the path has a drive letter or starts with `/`, it is absolute
   - Otherwise, it is relative to the including file's directory (`BaseDir + IncludePath`)
3. **Recursive load** — `ResolveFile` reads the target file and:
   - Skips its `package` declaration (if any)
   - Recursively processes its own `include` and `import` directives
   - Appends all other lines to the output buffer
4. **Cycle detection** — `FLoadingFiles` tracks the current resolution chain. Re-including the same file within a chain raises `Import cycle detected`.
5. **Deduplication** — after loading, the file is added to `FLoadedFiles`. Subsequent includes of the same file are skipped.

### Include vs Import

| | `include` | `import` |
|---|---|---|
| Resolution | file path | package name |
| Search | relative to current file | directory tree + package roots |
| Package declaration | optional, skipped | required, validated |
| Namespace | no namespace switching | pushes/pops package namespace |
| Dedup | by file path | by package name |
| Use case | inject raw source, templates | structured module dependencies |

### Example

```mantra
# constants.m
pi = 3.14159;
e = 2.71828;
```

```mantra
# main.m
include "constants.m";
print { pi + e };
```

## Global

The `global` directive escapes scope boundaries to write directly to the global namespace.

### Syntax

```mantra
global <variable> = <value>;
```

or within a scope block:

```mantra
scope { x = 2, global main.result = x };
```

- `<variable>` — a variable name (optionally with a dotted namespace prefix like `main.result`)
- When used inside a `scope` block, the `global` keyword before an assignment tells the runtime to bypass the scope's local variable storage and write to the global context.

### Behavior

#### Outside Scope (Top-level)

A `global` declaration at the top level (`TGlobalNode`) enables the **global writes mode**:

1. The context calls `PushGlobalWrites`, incrementing the `FGlobalWriteDepth` counter.
2. While global writes are enabled, `QualifyWriteName` returns the bare variable name without prefixing the current package namespace.
3. The assignment is evaluated normally, but the variable is registered globally rather than under the package namespace.
4. After the statement, `PopGlobalWrites` decrements the counter.

Effect: variables written during a `global` block are not namespaced — they appear at the global level regardless of the current package context.

#### Inside Scope (Exact scope)

Within a `scope` block, `global` before an assignment forces the write to the global context:

1. The scope creates a local `TExactScopeFrame` for temporary variables.
2. When an assignment is prefixed with `global`, `PushGlobalWrites` is called before evaluation.
3. `TryAddScopedExactVariable` checks `GlobalWritesEnabled` — when true, it returns `false`, so the variable skips the local scope frame.
4. The assignment proceeds through the normal path, writing to the global context.
5. `PopGlobalWrites` restores the scope's local write behavior.

### Examples

```mantra
# Write to global from inside a scope
scope { x = 2, global main.result = x };
print { result }    → 2
print { x }         → x (not found in global; only in scope)
```

```mantra
# Global write with namespace prefix
scope { global main.result = 2 };
print { result }    → 2
```

```mantra
# Global dotted path
global dict.obj1.a = 1;
print { get "dict.obj1.a" }    → 1
```

## Combined Example

A full example showing all four directives working together:

```mantra
# packages/math/constants/package.m
package math/constants;

pi = 3.14159265358979;
e = 2.71828182845904;
golden_mean = 1.61803398874989;
```

```mantra
# main.m
package main;

import math/constants;

scope {
  local_radius = 5;
  global result = math.constants.pi * local_radius * local_radius;
}

print { result };
```

## Error Messages

| Error | Cause |
|---|---|
| `Package not found: <path>` | No entry file found in any `packages/` directory or package root |
| `Imported module missing package declaration: <path>` | An imported `.m` file has no `package` directive |
| `Imported module package mismatch: expected X but found Y in <path>` | The `package` declaration in the file doesn't match the import path |
| `Import cycle detected: A -> B -> A` | A package or file tries to import/include itself transitively |
| `Import file not found: <path>` | An `include` directive references a non-existent file |
| `Invalid package path: <path>` | The path contains empty segments, `.`, or `..` |

## Implementation Details

- **Parser**: `mathparser.pas` — `TK_PACKAGE`, `TK_IMPORT`, `TK_INCLUDE`, `TK_GLOBAL` tokens map to `TPackageNode`, `TImportNode`, `TIncludeNode`, `TGlobalNode` via `OBJ_*` constants
- **Module loader**: `module_loader.pas` — `TModuleResolver` handles resolution, deduplication, cycle detection, and source injection
- **Context**: `context.pas` — `PushGlobalWrites`/`PopGlobalWrites` control the global writes mode; `QualifyWriteName` decides namespace qualification
- **API**: The module loader exposes `ResolveModuleSource`, `ResolveImportDirectiveSource`, `ResolveIncludeDirectiveSource`, and segmented variants for external consumers
