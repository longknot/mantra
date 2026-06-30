# Packages and Imports

`import` loads a package by logical name. The resolver searches the directory tree
for a `packages/` directory and resolves the target to either a single file or a
directory entry point.

## Syntax

```mantra
import package/path;
import <package/path>;
import package/path; // comment
```

- Package paths are bare identifiers separated by `/`, optionally wrapped in `<>`,
  optionally followed by `;` and a trailing comment
- Spaces are stripped; backslashes normalize to forward slashes
- Leading and trailing slashes are removed

## Package Resolution

The resolver searches **upward** from the entry file through the directory tree
for a `packages/` directory. Inside `packages/` it looks for:

1. `packages/<path>.m` — single-file package
2. `packages/<path>/package.m` — directory-style package

```
packages/
  math.m                # Single-file: import math
  math/
    package.m           # Directory entry: import math
    constants.m
    calculus/
      package.m         # Sub-package: import math/calculus
```

### Resolution Steps

1. Normalize the package path (strip spaces, `/` separators, trim slashes)
2. Starting from the entry file's directory, search upward for `packages/`
3. Try `packages/<normalized_path>.m` — if found, load it
4. Try `packages/<normalized_path>/package.m` — if found, load it
5. Search configured package roots in command-line order
6. If no candidate is found, raise `Package not found: <path>`

### External Package Roots

Use the repeatable `--package-root PATH` option to add third-party package
collections:

```bash
mantra \
  --package-root /opt/mantra-packages \
  --package-root ./vendor/mantra \
  app.m
```

A package root is the directory that directly contains logical package paths. It
is not a project directory containing another `packages/` directory.

For `import acme/http`, the root `/opt/mantra-packages` is searched for:

```text
/opt/mantra-packages/acme/http.m
/opt/mantra-packages/acme/http/package.m
```

Project-local `packages/` directories take precedence over configured roots.
Configured roots are then searched in the order supplied, and the first match
wins. Transitive imports use the same configured roots.

Relative root paths are resolved against the process working directory. Roots
must exist when execution starts. Package paths containing empty, `.` or `..`
segments are rejected.

## Runtime Behavior

`TImportNode.Execute` is called during evaluation. It:

1. Calls `NormalizeImportPath` on the directive argument
2. Calls `ResolveImportDirectiveSegments` to resolve the package
3. Appends resolved source chunks to the running program
4. Deletes itself from the AST

The resolved source is returned as segments with file paths and line numbers,
preserving source location information for debugging.

### Package Loading

When a package is loaded, `ResolvePackage` in the module loader:

1. Checks if the package is already in `FLoadedPackages` — if so, skip (deduplication)
2. Checks if the package is currently in `FLoadingPackages` — if so, raise cycle error
3. Adds the package to `FLoadingPackages`
4. Resolves the entry file via `ResolvePackageEntryFile`
5. Calls `ResolveFile` with `RequirePackageMatch = True`

### File Resolution

`ResolveFile` processes each line of a module:

- `package` directives are parsed and verified
- `include` directives trigger `ResolveFile` recursively
- `import` directives trigger `ResolvePackage` recursively
- All other lines are appended to the output with source file/line tracking
- After processing, the file is moved from `FLoadingFiles` to `FLoadedFiles`

### Package Verification

When `RequirePackageMatch` is true, `ResolveFile` enforces:

1. The file must contain a `package` declaration
2. The declared package must match the expected package name

Mismatches raise: `Imported module package mismatch: expected X but found Y in <path>`

## Deduplication

Packages are loaded only once per program. The `FLoadedPackages` list tracks
canonicalized package names. Subsequent imports of the same package are silently
skipped. Similarly, `FLoadedFiles` ensures individual files are never loaded twice.

## Cycle Detection

The resolver maintains separate stacks for packages (`FLoadingPackages`) and files
(`FLoadingFiles`). If a package or file is encountered that is already being loaded,
a cycle error is raised with the full chain:

```
Import cycle detected: demo/core -> demo/core/sub -> demo/core
```

## Namespace Switching

When a package is imported, its code executes in the imported package's namespace.
After the import completes, the resolver emits `package <caller>;` to restore the
caller's namespace.

```mantra
package main;
import demo/core;    # demo/core code runs as demo/core, then returns to main
```

## Worked Examples

### Built-in Package

```mantra
package main;
import math;
{ math.pi }
```

Expected `OUTPUT`:

```text
+ 3.14150943396226
```

### Sub-Package

```mantra
package main;
import demo/core;
demo.core.alpha.pa = 42;
{ demo.core.alpha.pa }
```

### Recursive Import

A package can import other packages. Sub-packages are resolved from the same
`packages/` root:

```
packages/
  demo/
    core/
      package.m
      alpha.m
      sub/
        package.m
        beta.m
```

```mantra
# packages/demo/core/package.m
package demo/core;
import demo/core/sub;
```

### Local Setting

```mantra
package main;
import demo/beam;
global demo.beam.prove = 1;
{ demo.beam.prove }
```

Expected `OUTPUT`:

```text
1
```

## Compile-Time Resolution

When you pass a `.m` file to the interpreter, `module_loader` resolves the full
import/include chain before parsing. `ResolveModuleSource` resolves the entry file
and all its transitive imports. Runtime `import` nodes and compile-time resolution
share the same `FLoadedFiles` and `FLoadedPackages` deduplication lists.

## Import vs Include

| | `import` | `include` |
|---|---|---|
| Resolves by | Logical package name | File path |
| Requires `package` | Yes | No |
| Deduplication | By package name | By file path |
| Verification | Package name must match | None |
| Directory search | Upward for `packages/` | Relative to entry file |

## Error Messages

| Error | Cause |
|---|---|
| `Package not found: X` | No matching package file was found locally or in configured roots |
| `Import cycle detected: A -> B -> A` | Circular import chain |
| `Imported module missing package declaration` | No `package` directive |
| `Imported module package mismatch: expected A but found B` | Wrong package name |
| `Import file not found: <path>` | Include path does not exist |
