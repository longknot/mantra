# Include Files

The `include` directive loads source code from an external file and injects it into
the current program. The included file is parsed, its statements are appended to
the AST, and the include node deletes itself after execution.

## Syntax

```mantra
include "path/to/file.m"
```

- The path is a string argument (double or single quoted) passed to the `include`
  keyword (`TK_INCLUDE`).
- After normalization (trailing quotes stripped, whitespace trimmed), the path is
  resolved relative to the entry file's directory.
- The `include` node parses the path expression via `ParseExpression`, moves it
  to the LHS child, and marks its `Meta` with `TK_DOT`.

## Path Resolution

The resolver determines the absolute filesystem path in three ways:

### Absolute paths

If the path starts with a drive letter (e.g. `C:\`) or a root delimiter (`/`),
it is expanded directly with no relative lookup:

```mantra
include "/usr/local/mantra/helpers.m"
```

### Relative paths

Relative paths are resolved against the **entry file's directory** — the directory
containing the file passed to the interpreter on the command line or read from
stdin's current working directory. The include is resolved via `ResolveIncludePath`
which joins the base directory and the include path:

```
Entry file:  /project/main.m
Include:     include "util.m"
Resolved:    /project/util.m
```

### Include chain propagation

When an included file itself contains `include` directives, those nested includes
are resolved relative to the **including file's** directory, not the original
entry file. This allows modular directory structures where each file references
its local neighbors:

```
main.m          -> include "lib/helpers.m"
lib/helpers.m   -> include "lib/math.m"    (relative to lib/)
```

## Execution

The `TIncludeNode.Execute` method follows this sequence:

1. **Normalize** the directive argument value (strip quotes and whitespace).
2. **Resolve** the path to source segments via
   `ResolveIncludeDirectiveSegments(path, current_namespace)`.
3. **Append** each resolved source segment's text to the AST via
   `AppendSourceChunk`, preserving file path and line number metadata.
4. **Delete** itself from the AST.

If a debugger is attached, `dekImportEnter` and `dekImportExit` events are
emitted with a `TDebuggerFrame` of kind `dfkImport`.

## De-duplication

The module resolver maintains a global `FLoadedFiles` list. Before loading a file,
it checks whether the canonical (expanded) path is already in the list. If the
file was previously loaded — whether by a direct include or transitively through
another included file — the second include is silently skipped.

This means a file is loaded **at most once** per program run:

```
main.m:  include "a.m"
main.m:  include "b.m"
a.m:     include "once.m"    (loads once.m)
b.m:     include "once.m"    (skipped — already loaded)
```

Test evidence (`import_mvp_include_once`): `main_once.m` includes `a.m` and `b.m`,
both of which include `once.m`. The `{ 42 }` in `once.m` executes once, producing
the single output `42`.

## Cycle Detection

The resolver tracks files currently being loaded in `FLoadingFiles`. If an include
chain references a file that is already in the loading stack (but not yet
completed), a cycle is detected and an exception is raised:

```
Import cycle detected: path/to/a.m -> path/to/b.m -> path/to/a.m
```

This prevents infinite recursion in circular include chains.

## Included File Format

An included file is a standard Mantra source file. It may contain:

- A `package` declaration (optional for includes; required for imports)
- Variable assignments, rules, callables, and any valid Mantra statements
- Further `include` or `import` directives

When the file is scanned, `package` directives encountered within it are filtered
out of the output during the module loader phase — the including file's namespace
is preserved.

## Source Segments

The resolver returns source content as an array of `TResolvedSourceSegment`
records, each carrying:

- `Text` — the source text of the segment
- `FilePath` — the canonical path of the source file
- `StartLine` — the starting line number within that file

Segments are grouped by file and continuity: consecutive lines from the same
file form one segment; gaps or file boundaries start new segments. This
preserves accurate source location information for error reporting and
debugging.

## Comparison: Include vs Import

| Aspect | `include` | `import` |
|---|---|---|
| Resolution | Filesystem path | Logical package name |
| Path format | `"file.m"` (quoted string) | `math` (bare identifier) or `<math>` (angle brackets) |
| Namespace | No namespace enforcement | Requires matching `package` declaration |
| De-dup key | Canonical filesystem path | Normalized package name |
| Use case | Direct file composition | Package-level reuse |

### When to use `include`

- Including utility files with helper definitions
- Composing programs from local source files
- Sharing code between files in the same project

### When to use `import`

- Loading shared packages from `packages/` directories
- When namespace isolation is required
- When package version matching matters

## Errors

### File not found

```
Import file not found: /absolute/path/to/file.m
```

The path must resolve to an existing file. Relative paths that don't exist
relative to the entry file's directory will fail.

### Include cycle

```
Import cycle detected: a.m -> b.m -> a.m
```

The file being included is already in the current loading stack.

## Debugger Support

Include directives emit debugger events:

- `dekImportEnter` — before loading the file
- `dekImportExit` — after all segments are appended

Breakpoints can be set on included files using the `--break-source` flag with
a wildcard path pattern:

```bash
mantra --debugger-cli --break-source="*helpers.m:3" main.m
```

## See Also

- [Import and Include Syntax](../../syntax/operators-special-forms/import-include-syntax.md) —
  directive syntax overview
- [Packages and Imports](packages-imports.md) — package-level imports
