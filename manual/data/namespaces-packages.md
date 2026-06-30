# Namespaces and Packages

Namespaces and packages organize names across larger Mantra programs. The system
provides four directives: `package`, `import`, `include`, and `global` — each
serving a distinct role in code composition and scoping.

## Quick Reference

| Directive | Purpose | Resolved by |
|---|---|---|
| `package name` | Declare current namespace | Runtime context |
| `import name` | Load a package by logical name | Package resolver |
| `include "file"` | Load a source file by path | File system |
| `global` | Mark assignments as global scope | Runtime context |

## Related Pages

- [Packages and Imports](namespaces-packages/packages-imports.md)
- [Include Files](namespaces-packages/include-files.md)
- [Import and Include Syntax](../syntax/operators-special-forms/import-include-syntax.md)

---

## How It Works

All four directives are processed at **runtime evaluation**. When executed, they:

1. Resolve source files or packages
2. Concatenate their contents into the current program
3. Delete themselves from the AST

Imported code becomes part of the running program as if it had been written inline.
During **compile-time**, the `module_loader` preprocessor also resolves import/include
chains for files passed as interpreter arguments.

---

## Package Declaration

`package` sets the current namespace and identifies the file for cycle detection.

### Syntax

```mantra
package name;
package <name>;
package name; // comment
```

Package names can be bare, inside angle brackets `<>`, or followed by a semicolon
with an optional trailing comment. Spaces are stripped; backslashes normalize to
forward slashes; leading/trailing slashes are removed.

### Behavior

- Sets `CurrentNamespace` on the runtime context
- When loaded via `import`, the loader verifies the declaration matches — mismatches raise an error
- After execution, the `package` node deletes itself from the AST

---

## Import: Package Resolution

`import` loads a package by logical name. The resolver searches upward from the
current file through the directory tree for a `packages/` directory, then looks
for either `packages/<name>.m` or `packages/<name>/package.m`.

```mantra
import math;           // looks for packages/math.m or packages/math/package.m
import demo/core;       // looks for packages/demo/core/package.m
```

Third-party collections can be added with repeatable package roots:

```bash
mantra --package-root /opt/mantra-packages program.m
```

Here `/opt/mantra-packages` directly contains logical paths, so
`import acme/http` resolves to `acme/http.m` or `acme/http/package.m` below that
root. Project-local `packages/` directories are searched first.

### Package Layout

A package can be a single file or a directory with a `package.m` entry point:

```
packages/
  math.m                  # Single-file package
  demo/
    core/
      package.m           # Directory-style package entry
      alpha.m
      sub/
        package.m
        beta.m
```

### Cycle Detection

The resolver tracks loading packages and files separately. Circular imports raise
an error with the full cycle path:

```
Import cycle detected: demo/core -> demo/core/sub -> demo/core
```

---

## Include: File Loading

`include` loads a source file by relative or absolute path. Unlike `import`, it
does not require a package declaration and does not trigger package resolution.

```mantra
include "util.m";        # Relative to entry file directory
include "../lib/math.m"; # Parent directory
```

Include paths support:
- Single or double quotes around the path
- Optional semicolon and trailing comment
- Absolute and relative paths
- De-duplication: included files are tracked; the same file is not loaded twice

---

## Namespaces and Qualified Names

When a package is declared, the `CurrentNamespace` tracks the scope. Callables
defined within a package are bound to that namespace. You can reference them
using dot-qualified names:

```mantra
package demo/core;

import demo/core/alpha;

# Access a variable from the alpha sub-package
pa = demo.core.alpha.pa;
```

Qualified names use dots (`.`) as separators, corresponding to slashes (`/`) in
package paths.

---

## Global Scope

`global` marks assignments as belonging to the global scope rather than the
current package namespace. This is useful for setting system-wide configuration
values:

```mantra
global mantra.inference.beam = 2;
```

---

## Runtime vs Compile-Time Resolution

The system has two resolution phases:

1. **Compile-time** — The `module_loader` preprocessor resolves all import/include
   chains when you pass a file to the interpreter. This builds the complete source
   tree before parsing begins.

2. **Runtime** — The `TPackageNode`, `TImportNode`, and `TIncludeNode` AST nodes
   execute during evaluation. They resolve additional imports/includes dynamically
   and append source chunks to the running program.

Both phases share the same cycle detection and de-duplication logic.

---

## Common Patterns

### Entry Point Pattern

Main files declare `package main` and import dependencies:

```mantra
package main;

import math;
include "helpers.m";

print { math.pi }
```

### Library Pattern

Library packages export definitions without side effects:

```mantra
# packages/math/pi/package.m
package math/pi;

. pi = 3.14159265;
```

### Transitive Include Pattern

Files can chain includes; the resolver handles de-duplication:

```mantra
# main.m
package main;
include "mid.m";
print { a b c };

# mid.m
package mid;
include "util.m";
. c = 3;

# util.m
package util;
. a = 1;
. b = 2;
```

Output: `1 2 3`

---

## Error Messages

| Error | Cause |
|---|---|
| `Package not found: X` | Resolver searched but found no matching package file |
| `Import cycle detected: A -> B -> A` | Two packages reference each other directly or indirectly |
| `Imported module missing package declaration` | An imported file has no `package` directive |
| `Imported module package mismatch: expected A but found B` | The imported file declares a different package name than expected |
